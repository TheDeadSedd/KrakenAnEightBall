@tool
extends Node
class_name AnchorBallSystem

# Owns Anchor Ball's cursed-tide pull. Table.gd owns the physics loop and ball list.
const DEBUG_RADIUS_COLOR := Color(0.28, 0.72, 0.84, 0.26)
const DEBUG_RADIUS_EDGE_COLOR := Color(0.60, 0.96, 1.0, 0.82)
const DEBUG_VECTOR_COLOR := Color(0.82, 0.98, 1.0, 0.92)
const DEBUG_VECTOR_LENGTH_SCALE := 0.32
const DEBUG_VECTOR_MIN_LENGTH := 8.0
const DEBUG_VECTOR_MAX_LENGTH := 36.0
const STATIONARY_ANCHOR_PULL_MULTIPLIER := 0.5

# Gameplay pull tuning.
@export var enabled := true
@export var influence_radius := 230.0
@export var pull_strength := 400.0
@export_range(0.0, 1.0, 0.01) var minimum_pull_strength := 0.08
# Lets close settled balls barely wake without turning Anchor into a table-wide vacuum.
@export_range(0.0, 1.0, 0.01) var stationary_ball_multiplier := 0.20

# Contact-loop guards.
@export var inner_dead_zone_radius := 28.0
@export var post_collision_pull_cooldown := 0.35

# Visual/debug controls.
@export_range(0.0, 1.0, 0.01) var visual_effect_strength := 1.0
@export var anchor_visuals_enabled := true
@export var max_visible_field_auras := 3
@export var debug_visual_enabled := false

# Debug safety valve only. Normal play should support chaos by degrading visuals first.
@export var anchor_spawn_cap_enabled := false
@export var max_anchor_balls_on_table := 3

var table
var active_anchor_ball_count := 0
var force_applications_this_frame := 0
var total_force_this_frame := 0.0
var max_force_this_frame := 0.0
var nearest_distance_this_frame := INF
var affected_ball_ids: Dictionary = {}
var debug_pull_vectors: Dictionary = {}
var post_collision_pull_cooldowns: Dictionary = {}


func setup(table_ref) -> void:
	table = table_ref


func reset_frame_stats() -> void:
	active_anchor_ball_count = 0
	force_applications_this_frame = 0
	total_force_this_frame = 0.0
	max_force_this_frame = 0.0
	nearest_distance_this_frame = INF
	affected_ball_ids.clear()
	debug_pull_vectors.clear()


func update_pull(delta: float) -> void:
	if table == null:
		return

	_update_post_collision_pull_cooldowns(delta)
	var anchor_balls: Array[Ball] = _get_active_anchor_balls()
	active_anchor_ball_count = anchor_balls.size()
	if debug_visual_enabled:
		table.queue_redraw()
	if anchor_balls.is_empty():
		return

	_apply_anchor_visual_settings(anchor_balls)

	if not enabled:
		return

	for anchor_ball in anchor_balls:
		_apply_anchor_pull(anchor_ball, delta)


func finish_frame() -> void:
	_sync_anchor_influence_markers()


func handle_collision(ball_a: Ball, ball_b: Ball) -> void:
	_try_set_post_collision_cooldown(ball_a, ball_b)
	_try_set_post_collision_cooldown(ball_b, ball_a)


func get_debug_snapshot() -> Dictionary:
	var visual_counts: Dictionary = _get_anchor_visual_counts()
	return {
		"enabled": enabled,
		"active_anchor_balls": active_anchor_ball_count,
		"affected_balls": affected_ball_ids.size(),
		"force_applications": force_applications_this_frame,
		"avg_force": _get_average_force(),
		"max_force": max_force_this_frame,
		"nearest_distance": _get_nearest_distance_or_negative(),
		"influence_radius": influence_radius,
		"pull_strength": pull_strength,
		"visuals_enabled": anchor_visuals_enabled,
		"visual_nodes_active": visual_counts["visual_nodes_active"],
		"field_rings_drawn": visual_counts["field_rings_drawn"],
		"affected_markers_active": visual_counts["affected_markers_active"],
		"max_visible_field_auras": max_visible_field_auras,
		"spawn_cap_enabled": anchor_spawn_cap_enabled,
		"max_anchor_balls_on_table": max_anchor_balls_on_table,
	}


func set_anchor_visuals_enabled(enabled_value: bool) -> void:
	anchor_visuals_enabled = enabled_value
	if table == null:
		return

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball != null:
			ball.set_anchor_visuals_enabled(anchor_visuals_enabled)

	_apply_anchor_visual_settings(_get_active_anchor_balls())


func are_anchor_visuals_enabled() -> bool:
	return anchor_visuals_enabled


func can_spawn_anchor_ball() -> bool:
	if not anchor_spawn_cap_enabled:
		return true
	return get_current_anchor_ball_count() < max_anchor_balls_on_table


func get_current_anchor_ball_count() -> int:
	if table == null:
		return 0

	var anchor_ball_count := 0
	for child in table.balls.get_children():
		var ball := child as Ball
		if _is_anchor_field_source(ball):
			anchor_ball_count += 1
	return anchor_ball_count


func set_debug_visual_enabled(enabled_value: bool) -> void:
	debug_visual_enabled = enabled_value
	if table != null:
		table.queue_redraw()


func is_debug_visual_enabled() -> bool:
	return debug_visual_enabled


func draw_debug(canvas: Node2D) -> void:
	if not debug_visual_enabled or table == null:
		return

	for anchor_ball in _get_active_anchor_balls():
		var anchor_position: Vector2 = canvas.to_local(anchor_ball.global_position)
		canvas.draw_circle(anchor_position, influence_radius, DEBUG_RADIUS_COLOR)
		canvas.draw_arc(anchor_position, influence_radius, 0.0, TAU, 80, DEBUG_RADIUS_EDGE_COLOR, 2.0)

	for vector_entry in debug_pull_vectors.values():
		var vector_data: Dictionary = vector_entry
		var start_global_position: Vector2 = vector_data["start"]
		var end_global_position: Vector2 = vector_data["end"]
		var start_position: Vector2 = canvas.to_local(start_global_position)
		var end_position: Vector2 = canvas.to_local(end_global_position)
		canvas.draw_line(start_position, end_position, DEBUG_VECTOR_COLOR, 2.0)
		canvas.draw_circle(end_position, 2.8, DEBUG_VECTOR_COLOR)


func _get_active_anchor_balls() -> Array[Ball]:
	var anchor_balls: Array[Ball] = []
	for child in table.balls.get_children():
		var ball := child as Ball
		if _is_anchor_field_source(ball):
			anchor_balls.append(ball)
	return anchor_balls


func _is_anchor_field_source(ball: Ball) -> bool:
	# Stopped Anchors remain persistent field sources while they exist on the table.
	return ball != null and ball.is_anchor_ball and ball.is_gameplay_active()


func _apply_anchor_visual_settings(anchor_balls: Array[Ball]) -> void:
	var visible_field_count := 0
	var field_cap: int = maxi(max_visible_field_auras, 0)
	for anchor_ball in anchor_balls:
		anchor_ball.anchor_visual_effect_strength = visual_effect_strength
		anchor_ball.anchor_field_visual_radius = influence_radius
		anchor_ball.set_anchor_visuals_enabled(anchor_visuals_enabled)

		var show_field_visual: bool = (
			anchor_visuals_enabled
			and visible_field_count < field_cap
		)
		anchor_ball.set_anchor_field_visual_enabled(show_field_visual)
		if show_field_visual:
			visible_field_count += 1


func _get_anchor_visual_counts() -> Dictionary:
	var visual_nodes_active := 0
	var field_rings_drawn := 0
	var affected_markers_active := 0
	if table == null:
		return {
			"visual_nodes_active": visual_nodes_active,
			"field_rings_drawn": field_rings_drawn,
			"affected_markers_active": affected_markers_active,
		}

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.visible:
			continue

		visual_nodes_active += 1 if ball.is_anchor_visual_node_active() else 0
		field_rings_drawn += 1 if ball.is_anchor_field_visual_drawn() else 0
		affected_markers_active += 1 if ball.is_anchor_influence_marker_active() else 0

	return {
		"visual_nodes_active": visual_nodes_active,
		"field_rings_drawn": field_rings_drawn,
		"affected_markers_active": affected_markers_active,
	}


func _sync_anchor_influence_markers() -> void:
	if table == null:
		return

	# Markers live on Ball.gd, keyed by the ball instance instead of spawned as extra nodes.
	for child in table.balls.get_children():
		var ball := child as Ball
		if ball == null:
			continue

		if ball.is_anchor_ball or not anchor_visuals_enabled or not ball.visible or not ball.gameplay_enabled:
			ball.clear_anchor_influence_marker()
			continue

		if not affected_ball_ids.has(ball.get_instance_id()):
			ball.release_anchor_influence_marker()


func _apply_anchor_pull(anchor_ball: Ball, delta: float) -> void:
	for child in table.balls.get_children():
		var target_ball := child as Ball
		if not _is_pull_target(anchor_ball, target_ball):
			continue

		var offset: Vector2 = anchor_ball.global_position - target_ball.global_position
		var distance: float = offset.length()
		if distance <= 0.001 or distance > influence_radius:
			continue
		if distance <= _get_inner_dead_zone_radius(anchor_ball, target_ball):
			continue
		if _is_pull_pair_on_cooldown(anchor_ball, target_ball):
			continue

		nearest_distance_this_frame = min(nearest_distance_this_frame, distance)
		var motion_multiplier: float = _get_motion_multiplier(target_ball)
		if motion_multiplier <= 0.0:
			continue

		var distance_ratio: float = 1.0 - clamp(distance / influence_radius, 0.0, 1.0)
		var pull_ratio: float = lerp(minimum_pull_strength, 1.0, distance_ratio * distance_ratio)
		var source_multiplier: float = _get_anchor_source_multiplier(anchor_ball)
		var force_magnitude: float = pull_strength * source_multiplier * pull_ratio * motion_multiplier
		var pull_direction: Vector2 = offset.normalized()
		target_ball.velocity += pull_direction * force_magnitude * delta
		target_ball.note_anchor_influence(pull_ratio, pull_direction)
		_record_force_application(anchor_ball, target_ball, offset, force_magnitude)


func _is_pull_target(anchor_ball: Ball, target_ball: Ball) -> bool:
	if target_ball == null or target_ball == anchor_ball:
		return false
	if target_ball.is_anchor_ball:
		return false
	if not target_ball.is_gameplay_active():
		return false
	return target_ball.ball_type == Ball.BallType.OBJECT


func _get_motion_multiplier(target_ball: Ball) -> float:
	if target_ball.is_moving():
		return 1.0
	return stationary_ball_multiplier


func _get_anchor_source_multiplier(anchor_ball: Ball) -> float:
	if anchor_ball.is_moving():
		return 1.0
	return STATIONARY_ANCHOR_PULL_MULTIPLIER


func _get_inner_dead_zone_radius(anchor_ball: Ball, target_ball: Ball) -> float:
	return max(inner_dead_zone_radius, anchor_ball.radius + target_ball.radius)


func _try_set_post_collision_cooldown(anchor_ball: Ball, target_ball: Ball) -> void:
	if not _is_anchor_field_source(anchor_ball):
		return
	if not _is_pull_target(anchor_ball, target_ball):
		return

	post_collision_pull_cooldowns[_get_pull_pair_key(anchor_ball, target_ball)] = post_collision_pull_cooldown


func _is_pull_pair_on_cooldown(anchor_ball: Ball, target_ball: Ball) -> bool:
	return post_collision_pull_cooldowns.has(_get_pull_pair_key(anchor_ball, target_ball))


func _update_post_collision_pull_cooldowns(delta: float) -> void:
	var expired_keys: Array[String] = []
	for pair_key in post_collision_pull_cooldowns.keys():
		var remaining_time: float = float(post_collision_pull_cooldowns[pair_key]) - delta
		if remaining_time <= 0.0:
			expired_keys.append(pair_key)
		else:
			post_collision_pull_cooldowns[pair_key] = remaining_time

	for pair_key in expired_keys:
		post_collision_pull_cooldowns.erase(pair_key)


func _record_force_application(anchor_ball: Ball, target_ball: Ball, offset: Vector2, force_magnitude: float) -> void:
	affected_ball_ids[target_ball.get_instance_id()] = true
	force_applications_this_frame += 1
	total_force_this_frame += force_magnitude
	max_force_this_frame = max(max_force_this_frame, force_magnitude)

	if not debug_visual_enabled:
		return

	var pull_direction: Vector2 = offset.normalized()
	var vector_length: float = clamp(force_magnitude * DEBUG_VECTOR_LENGTH_SCALE, DEBUG_VECTOR_MIN_LENGTH, DEBUG_VECTOR_MAX_LENGTH)
	debug_pull_vectors[_get_pull_pair_key(anchor_ball, target_ball)] = {
		"start": target_ball.global_position,
		"end": target_ball.global_position + pull_direction * vector_length,
	}


func _get_pull_pair_key(anchor_ball: Ball, target_ball: Ball) -> String:
	return "%s:%s" % [anchor_ball.get_instance_id(), target_ball.get_instance_id()]


func _get_average_force() -> float:
	if force_applications_this_frame <= 0:
		return 0.0
	return total_force_this_frame / float(force_applications_this_frame)


func _get_nearest_distance_or_negative() -> float:
	if nearest_distance_this_frame == INF:
		return -1.0
	return nearest_distance_this_frame
