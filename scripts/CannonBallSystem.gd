@tool
extends Node
class_name CannonBallSystem

# index:title Cannon Ball System
# index:category Mechanics / Anomaly Balls / Systems / Performance Concerns / In Progress
# index:status In Progress
# index:owner anomaly_ball_agent
# index:notes Cannon Ball anomaly system; owns heavy impulse modifiers, Powder Keg launch tuning, heavy-impact shake requests, and heat presence tuning.

# Owns Cannon Ball anomaly behavior. Table.gd still owns the main collision
# loop and asks this system to adjust only Cannon-involved ball impulses.
@export_range(0.0, 1.0, 0.01) var incoming_velocity_gain_multiplier := 0.17
@export_range(1.0, 2.0, 0.01) var outgoing_impact_multiplier := 1.35
@export_range(0.0, 1.0, 0.01) var cannon_velocity_retention_on_ball_hit := 0.90
@export var minimum_heavy_impact_speed := 80.0
@export_range(1.0, 3.0, 0.05) var powder_keg_explosion_impulse_multiplier := 1.75
@export var powder_keg_launch_speed_cap := 900.0
@export var cannon_impact_shake_enabled := true
@export var cannon_impact_shake_strength := 2.1
@export var cannon_impact_shake_speed_bonus := 1.3
@export var cannon_impact_shake_max_strength := 3.6
@export var cannon_impact_shake_cooldown := 0.16
@export var cannon_presence_visuals_enabled := true
@export var cannon_presence_speed_threshold := 120.0
@export var cannon_presence_short_trail_speed := 220.0
@export var cannon_presence_medium_trail_speed := 340.0
@export var cannon_presence_long_trail_speed := 460.0
@export var max_active_cannon_presence_effects := 5
@export var cannon_presence_impact_flash_strength := 0.45
@export var cannon_presence_impact_flash_duration := 0.22

var table
var collisions_this_frame := 0
var heavy_impacts_this_frame := 0
var _next_cannon_impact_shake_time_msec := 0


func setup(table_ref) -> void:
	table = table_ref


func reset_frame_stats() -> void:
	collisions_this_frame = 0
	heavy_impacts_this_frame = 0


func get_debug_snapshot() -> Dictionary:
	return {
		"active_cannon_balls": get_active_cannon_ball_count(),
		"collisions": collisions_this_frame,
		"heavy_impacts": heavy_impacts_this_frame,
	}


func get_active_cannon_ball_count() -> int:
	if table == null:
		return 0

	var cannon_ball_count := 0
	for child in table.balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_cannon_ball and ball.is_gameplay_active():
			cannon_ball_count += 1
	return cannon_ball_count


func update_presence_visuals() -> void:
	if table == null:
		return

	var candidates: Array[Dictionary] = []
	for child in table.balls.get_children():
		var ball := child as Ball
		if not _is_cannon_ball(ball):
			continue
		var speed: float = ball.velocity.length()
		if not cannon_presence_visuals_enabled or not ball.is_gameplay_active() or speed < cannon_presence_speed_threshold:
			ball.set_cannon_presence_visual(0.0, Vector2.ZERO)
			continue
		candidates.append({
			"ball": ball,
			"speed": speed,
		})

	candidates.sort_custom(_sort_cannon_presence_candidates_by_speed)
	var visible_count: int = mini(maxi(max_active_cannon_presence_effects, 0), candidates.size())
	for index in range(candidates.size()):
		var candidate: Dictionary = candidates[index]
		var ball := candidate["ball"] as Ball
		if ball == null:
			continue
		if index >= visible_count:
			ball.set_cannon_presence_visual(0.0, Vector2.ZERO)
			continue
		ball.set_cannon_presence_visual(
			_get_cannon_presence_tier(float(candidate["speed"])),
			ball.velocity.normalized()
		)


func can_trigger_powder_keg(ball: Ball) -> bool:
	return _is_cannon_ball(ball) and ball.is_gameplay_active()


func get_powder_keg_launch_velocity(
	cannon_ball: Ball,
	current_velocity: Vector2,
	base_explosion_delta: Vector2
) -> Vector2:
	if not _is_cannon_ball(cannon_ball):
		return current_velocity + base_explosion_delta

	var launch_velocity: Vector2 = current_velocity + base_explosion_delta * powder_keg_explosion_impulse_multiplier
	if powder_keg_launch_speed_cap > 0.0:
		launch_velocity = launch_velocity.limit_length(powder_keg_launch_speed_cap)
	return launch_velocity


func try_apply_collision_response(ball_a: Ball, ball_b: Ball, normal: Vector2, impulse: Vector2) -> bool:
	if ball_a == null or ball_b == null:
		return false
	if ball_a.is_cannon_ball and _is_cannon_collision_partner(ball_b):
		_apply_cannon_collision(ball_a, ball_b, normal, -impulse, impulse)
		return true
	if ball_b.is_cannon_ball and _is_cannon_collision_partner(ball_a):
		_apply_cannon_collision(ball_b, ball_a, -normal, impulse, -impulse)
		return true
	return false


func _apply_cannon_collision(
	cannon_ball: Ball,
	other_ball: Ball,
	cannon_to_other_normal: Vector2,
	base_cannon_delta: Vector2,
	base_other_delta: Vector2
) -> void:
	collisions_this_frame += 1
	var cannon_pre_collision_velocity: Vector2 = cannon_ball.velocity
	if _is_cannon_driving_collision(cannon_ball, other_ball, cannon_to_other_normal):
		var impact_multiplier: float = _get_outgoing_impact_multiplier(cannon_ball)
		other_ball.velocity += base_other_delta * impact_multiplier
		var normal_cannon_velocity: Vector2 = cannon_pre_collision_velocity + base_cannon_delta
		cannon_ball.velocity = normal_cannon_velocity.lerp(
			cannon_pre_collision_velocity,
			cannon_velocity_retention_on_ball_hit
		)
		if impact_multiplier > 1.0:
			heavy_impacts_this_frame += 1
			_try_request_cannon_impact_feedback(cannon_ball, cannon_pre_collision_velocity, cannon_to_other_normal)
		return

	other_ball.velocity += base_other_delta
	cannon_ball.velocity += base_cannon_delta * incoming_velocity_gain_multiplier


func _is_cannon_driving_collision(cannon_ball: Ball, other_ball: Ball, cannon_to_other_normal: Vector2) -> bool:
	if cannon_to_other_normal.length_squared() <= 0.001:
		return false

	var cannon_speed_toward_other: float = cannon_ball.velocity.dot(cannon_to_other_normal)
	var other_speed_toward_cannon: float = other_ball.velocity.dot(cannon_to_other_normal)
	if cannon_speed_toward_other <= 0.0:
		return false
	return cannon_speed_toward_other > other_speed_toward_cannon


func _get_outgoing_impact_multiplier(cannon_ball: Ball) -> float:
	if cannon_ball.velocity.length() < minimum_heavy_impact_speed:
		return 1.0
	return outgoing_impact_multiplier


func _sort_cannon_presence_candidates_by_speed(candidate_a: Dictionary, candidate_b: Dictionary) -> bool:
	return float(candidate_a["speed"]) > float(candidate_b["speed"])


func _get_cannon_presence_tier(speed: float) -> float:
	if speed >= cannon_presence_long_trail_speed:
		return 4.0
	if speed >= cannon_presence_medium_trail_speed:
		return 3.0
	if speed >= cannon_presence_short_trail_speed:
		return 2.0
	if speed >= cannon_presence_speed_threshold:
		return 1.0
	return 0.0


func _try_request_cannon_impact_feedback(cannon_ball: Ball, cannon_velocity: Vector2, impact_normal: Vector2) -> void:
	if table == null:
		return

	var impact_speed: float = cannon_velocity.dot(impact_normal)
	if impact_speed < minimum_heavy_impact_speed:
		return

	if cannon_presence_visuals_enabled and cannon_ball != null:
		cannon_ball.add_cannon_presence_flash(
			cannon_presence_impact_flash_strength,
			cannon_presence_impact_flash_duration
		)

	if not cannon_impact_shake_enabled:
		return

	var current_time_msec: int = Time.get_ticks_msec()
	if current_time_msec < _next_cannon_impact_shake_time_msec:
		return

	_next_cannon_impact_shake_time_msec = current_time_msec + int(cannon_impact_shake_cooldown * 1000.0)
	var speed_ratio: float = clamp(impact_speed / max(minimum_heavy_impact_speed, 1.0) - 1.0, 0.0, 1.0)
	var shake_strength: float = clamp(
		cannon_impact_shake_strength + speed_ratio * cannon_impact_shake_speed_bonus,
		0.0,
		cannon_impact_shake_max_strength
	)
	var impact_direction: Vector2 = cannon_velocity.normalized()
	if impact_direction.length_squared() <= 0.001:
		impact_direction = impact_normal
	table.table_impact_shake_system.request_cannon_heavy_impact(impact_direction, shake_strength)


func _is_cannon_collision_partner(ball: Ball) -> bool:
	if ball == null or ball.is_cannon_ball:
		return false
	return not ball.is_wayfinder and not ball.is_powder_keg and not ball.is_anchor_ball


func _is_cannon_ball(ball: Ball) -> bool:
	return ball != null and ball.is_cannon_ball
