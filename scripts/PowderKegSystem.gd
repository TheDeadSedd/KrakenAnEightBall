@tool
extends Node
class_name PowderKegSystem

# Owns Powder Keg trigger-contact explosions, radial push falloff, and one-shot burst cleanup.
# Table.gd still owns collision response, the ball list, and the shot lifecycle.
const EXPLOSION_SPARK_COLOR := Color(1.0, 0.86, 0.38, 1.0)
const EXPLOSION_SMOKE_COLOR := Color(0.34, 0.24, 0.16, 0.72)
const EXPLOSION_GLOW_COLOR := Color(1.0, 0.62, 0.2, 1.0)

# Gameplay explosion tuning.
@export var explosion_radius := 165.0
@export var explosion_force := 245.0
@export_range(0.0, 1.0, 0.01) var min_force_ratio := 0.24

# Particle presentation tuning.
@export var particle_lifetime := 0.92
@export var particle_amount := 72
@export var explosion_particles_enabled := true

# Debug-only visual load toggles.
@export var reduced_particles_debug_enabled := false
@export var reduced_particle_lifetime := 0.45
@export var reduced_particle_amount := 24
@export var suppress_trails_after_explosion := false
@export var trail_suppression_duration := 0.75

var table
var exploded_ball_ids: Dictionary = {}
var active_particle_bursts := 0


func setup(table_ref) -> void:
	table = table_ref


func handle_collision(ball_a: Ball, ball_b: Ball) -> void:
	_try_explode_from_trigger_contact(ball_a, ball_b)
	_try_explode_from_trigger_contact(ball_b, ball_a)


func get_active_particle_burst_count() -> int:
	return active_particle_bursts


func _try_explode_from_trigger_contact(striker: Ball, target: Ball) -> void:
	if not _can_trigger_powder_keg(striker) or target == null or not target.is_powder_keg:
		return
	if not target.is_gameplay_active():
		return

	var powder_keg_id: int = target.get_instance_id()
	if exploded_ball_ids.has(powder_keg_id):
		return

	exploded_ball_ids[powder_keg_id] = true
	_explode_powder_keg(target)


func _can_trigger_powder_keg(striker: Ball) -> bool:
	if striker == null:
		return false
	if striker == table.cue_ball:
		return true
	return table.cannon_ball_system.can_trigger_powder_keg(striker)


func _explode_powder_keg(powder_keg: Ball) -> void:
	var explosion_center: Vector2 = powder_keg.global_position
	var impact_data: Dictionary = _push_nearby_balls(powder_keg, explosion_center)
	_request_table_impact_shake(explosion_center, impact_data)
	_spawn_explosion_particles(explosion_center)
	_remove_powder_keg(powder_keg)


func _push_nearby_balls(powder_keg: Ball, explosion_center: Vector2) -> Dictionary:
	var impact_data := {
		"affected_balls": 0,
		"cannon_balls": 0,
	}
	for child in table.balls.get_children():
		var other_ball := child as Ball
		if other_ball == null or other_ball == powder_keg or not other_ball.is_gameplay_active():
			continue

		var offset: Vector2 = other_ball.global_position - explosion_center
		var distance: float = offset.length()
		if distance > explosion_radius:
			continue

		var distance_ratio: float = 1.0 - clamp(distance / explosion_radius, 0.0, 1.0)
		var applied_ratio: float = lerp(min_force_ratio, 1.0, distance_ratio)
		var push_direction: Vector2 = _get_push_direction(powder_keg, other_ball, offset)
		var explosion_delta: Vector2 = push_direction * explosion_force * applied_ratio
		impact_data["affected_balls"] = int(impact_data["affected_balls"]) + 1
		if other_ball.is_cannon_ball:
			impact_data["cannon_balls"] = int(impact_data["cannon_balls"]) + 1
			other_ball.velocity = table.cannon_ball_system.get_powder_keg_launch_velocity(
				other_ball,
				other_ball.velocity,
				explosion_delta
			)
		else:
			other_ball.velocity += explosion_delta
		if suppress_trails_after_explosion:
			other_ball.suppress_trail_for(trail_suppression_duration)
		if _is_anomaly_scoring_target(other_ball):
			table.shot_event_system.record_anomaly_touch(other_ball)

	return impact_data


func _request_table_impact_shake(explosion_center: Vector2, impact_data: Dictionary) -> void:
	table.table_impact_shake_system.request_powder_keg_impact(
		explosion_center,
		int(impact_data["affected_balls"]),
		int(impact_data["cannon_balls"])
	)


func _get_push_direction(powder_keg: Ball, other_ball: Ball, offset: Vector2) -> Vector2:
	if offset.length_squared() > 0.001:
		return offset.normalized()
	if other_ball == table.cue_ball and table.cue_ball.velocity.length_squared() > 0.001:
		return table.cue_ball.velocity.normalized()

	var fallback: Vector2 = explosion_center_fallback(powder_keg)
	return fallback


func explosion_center_fallback(powder_keg: Ball) -> Vector2:
	var away_from_center: Vector2 = (powder_keg.global_position - table.playfield_rect.get_center()).normalized()
	if away_from_center.length_squared() > 0.001:
		return away_from_center
	return Vector2.RIGHT


func _is_anomaly_scoring_target(ball: Ball) -> bool:
	return ball != null and ball != table.cue_ball and ball.ball_type == Ball.BallType.OBJECT and not ball.is_powder_keg


func _remove_powder_keg(powder_keg: Ball) -> void:
	powder_keg.velocity = Vector2.ZERO
	powder_keg.gameplay_enabled = false
	powder_keg.visible = false
	powder_keg.queue_free()


func _spawn_explosion_particles(explosion_center: Vector2) -> void:
	if not explosion_particles_enabled:
		return

	var particles := GPUParticles2D.new()
	var effective_particle_lifetime: float = _get_effective_particle_lifetime()
	particles.global_position = explosion_center
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = effective_particle_lifetime
	particles.amount = _get_effective_particle_amount()
	particles.local_coords = false

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		EXPLOSION_GLOW_COLOR,
		EXPLOSION_SPARK_COLOR,
		EXPLOSION_SMOKE_COLOR,
		Color(0, 0, 0, 0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.24, 0.72, 1.0])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = gradient

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 14.0
	material.direction = Vector3.UP
	material.spread = 180.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 130.0
	material.initial_velocity_max = 260.0
	material.radial_accel_min = 24.0
	material.radial_accel_max = 68.0
	material.damping_min = 24.0
	material.damping_max = 52.0
	material.scale_min = 2.0
	material.scale_max = 4.0
	material.color_ramp = color_ramp
	particles.process_material = material

	table.add_child(particles)
	table.move_child(particles, table.balls.get_index())
	active_particle_bursts += 1
	particles.emitting = true

	var cleanup_timer: SceneTreeTimer = table.get_tree().create_timer(effective_particle_lifetime + 0.35, false)
	cleanup_timer.timeout.connect(func() -> void:
		active_particle_bursts = max(active_particle_bursts - 1, 0)
		if is_instance_valid(particles):
			particles.queue_free()
	)


func _get_effective_particle_lifetime() -> float:
	if reduced_particles_debug_enabled:
		return reduced_particle_lifetime
	return particle_lifetime


func _get_effective_particle_amount() -> int:
	if reduced_particles_debug_enabled:
		return reduced_particle_amount
	return particle_amount
