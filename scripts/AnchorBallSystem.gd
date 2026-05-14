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

# Stopped object balls use a cheaper wake path so settled high-ball-count tables
# do not do full Anchor-vs-stationary work every physics substep.
@export var stationary_pull_update_interval := 0.18
@export var stationary_min_wake_speed := 5.0
@export var max_stationary_wake_impulse := 8.0
@export var stationary_wake_cooldown := 0.55
@export var stationary_wake_recheck_distance := 10.0

# Contact-loop guards.
@export var inner_dead_zone_radius := 28.0
@export var post_collision_pull_cooldown := 0.35

# Visual/debug controls.
@export_range(0.0, 1.0, 0.01) var visual_effect_strength := 1.0
@export var anchor_visuals_enabled := true
@export var max_visible_field_auras := 3
@export var debug_visual_enabled := false
# Official overlap rule: each target follows one strongest Anchor current per update.
@export var anchor_single_latch_per_target_enabled := true

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
var latch_candidate_counts_this_update: Dictionary = {}
var multi_latch_candidates_this_frame := 0
var single_latch_skipped_this_frame := 0
var max_anchors_affecting_same_ball_this_frame := 0
var multi_latch_target_ids_this_frame: Dictionary = {}
var post_collision_pull_cooldowns: Dictionary = {}
var stationary_wake_cooldowns: Dictionary = {}
var stationary_wake_positions: Dictionary = {}
var stationary_pull_accumulator := 0.0


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
	latch_candidate_counts_this_update.clear()
	multi_latch_candidates_this_frame = 0
	single_latch_skipped_this_frame = 0
	max_anchors_affecting_same_ball_this_frame = 0
	multi_latch_target_ids_this_frame.clear()


func update_pull(delta: float) -> void:
	if table == null:
		return

	_update_post_collision_pull_cooldowns(delta)
	_update_stationary_wake_cooldowns(delta)
	var anchor_balls: Array[Ball] = _get_active_anchor_balls()
	active_anchor_ball_count = anchor_balls.size()
	if debug_visual_enabled:
		table.queue_redraw()
	if anchor_balls.is_empty():
		return

	_apply_anchor_visual_settings(anchor_balls)

	if not enabled:
		return

	var target_groups: Dictionary = _get_pull_target_groups()
	var moving_targets: Array = target_groups["moving"]
	var stationary_targets: Array = target_groups["stationary"]
	var should_check_stationary_pull: bool = _should_check_stationary_pull(delta, not stationary_targets.is_empty())
	if moving_targets.is_empty() and not should_check_stationary_pull:
		return

	_begin_latch_candidate_update()
	if anchor_single_latch_per_target_enabled:
		if not moving_targets.is_empty():
			_apply_single_latch_anchor_pull_to_targets(anchor_balls, moving_targets, delta, false)
		if should_check_stationary_pull:
			_apply_single_latch_anchor_pull_to_targets(anchor_balls, stationary_targets, delta, true)
	else:
		for anchor_ball in anchor_balls:
			if not moving_targets.is_empty():
				_apply_anchor_pull_to_targets(anchor_ball, moving_targets, delta, false)
			if should_check_stationary_pull:
				_apply_anchor_pull_to_targets(anchor_ball, stationary_targets, delta, true)
	_finish_latch_candidate_update()


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
		"single_latch_enabled": anchor_single_latch_per_target_enabled,
		"multi_latch_candidates": multi_latch_candidates_this_frame,
		"single_latch_skipped": single_latch_skipped_this_frame,
		"max_anchors_affecting_same_ball": max_anchors_affecting_same_ball_this_frame,
		"targets_affected_by_multiple_anchors": multi_latch_target_ids_this_frame.size(),
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


func set_single_latch_per_target_enabled(enabled_value: bool) -> void:
	anchor_single_latch_per_target_enabled = enabled_value


func is_single_latch_per_target_enabled() -> bool:
	return anchor_single_latch_per_target_enabled


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


func _get_pull_target_groups() -> Dictionary:
	var moving_targets: Array[Ball] = []
	var stationary_targets: Array[Ball] = []
	for child in table.balls.get_children():
		var target_ball := child as Ball
		if not _is_pull_target_candidate(target_ball):
			continue

		if target_ball.is_moving():
			moving_targets.append(target_ball)
		else:
			stationary_targets.append(target_ball)

	return {
		"moving": moving_targets,
		"stationary": stationary_targets,
	}


func _should_check_stationary_pull(delta: float, has_stationary_targets: bool) -> bool:
	if not has_stationary_targets or stationary_ball_multiplier <= 0.0:
		stationary_pull_accumulator = 0.0
		return false
	if stationary_pull_update_interval <= 0.0:
		return true

	stationary_pull_accumulator += delta
	if stationary_pull_accumulator < stationary_pull_update_interval:
		return false

	stationary_pull_accumulator = 0.0
	return true


func _apply_anchor_pull_to_targets(
	anchor_ball: Ball,
	target_balls: Array,
	delta: float,
	is_stationary_batch: bool
) -> void:
	for target_value in target_balls:
		var target_ball := target_value as Ball
		_try_apply_anchor_pull(anchor_ball, target_ball, delta, is_stationary_batch)


func _apply_single_latch_anchor_pull_to_targets(
	anchor_balls: Array[Ball],
	target_balls: Array,
	delta: float,
	is_stationary_batch: bool
) -> void:
	for target_value in target_balls:
		var target_ball := target_value as Ball
		if target_ball == null:
			continue

		var best_candidate: Dictionary = {}
		var best_force := -1.0
		var best_distance := INF
		for anchor_ball in anchor_balls:
			var candidate: Dictionary = _get_anchor_pull_candidate(anchor_ball, target_ball, delta, is_stationary_batch)
			if candidate.is_empty():
				continue

			_record_latch_candidate(target_ball)
			var force_magnitude: float = float(candidate["force_magnitude"])
			var distance: float = float(candidate["distance"])
			if force_magnitude < best_force:
				continue
			if is_equal_approx(force_magnitude, best_force) and distance >= best_distance:
				continue

			best_force = force_magnitude
			best_distance = distance
			best_candidate = candidate

		if best_candidate.is_empty():
			continue

		var target_id: int = target_ball.get_instance_id()
		var latch_count: int = int(latch_candidate_counts_this_update.get(target_id, 0))
		single_latch_skipped_this_frame += max(latch_count - 1, 0)
		_apply_anchor_pull_candidate(best_candidate)


func _try_apply_anchor_pull(
	anchor_ball: Ball,
	target_ball: Ball,
	delta: float,
	is_stationary_batch: bool
) -> void:
	var candidate: Dictionary = _get_anchor_pull_candidate(anchor_ball, target_ball, delta, is_stationary_batch)
	if candidate.is_empty():
		return

	_record_latch_candidate(target_ball)
	_apply_anchor_pull_candidate(candidate)


func _get_anchor_pull_candidate(
	anchor_ball: Ball,
	target_ball: Ball,
	delta: float,
	is_stationary_batch: bool
) -> Dictionary:
	if not _is_pull_target(anchor_ball, target_ball):
		return {}

	var offset: Vector2 = anchor_ball.global_position - target_ball.global_position
	var distance_squared: float = offset.length_squared()
	var influence_radius_squared: float = influence_radius * influence_radius
	if distance_squared <= 0.000001 or distance_squared > influence_radius_squared:
		return {}

	var inner_dead_zone: float = _get_inner_dead_zone_radius(anchor_ball, target_ball)
	if distance_squared <= inner_dead_zone * inner_dead_zone:
		return {}
	if _is_pull_pair_on_cooldown(anchor_ball, target_ball):
		return {}

	var distance: float = sqrt(distance_squared)
	var motion_multiplier: float = _get_motion_multiplier(target_ball)
	if motion_multiplier <= 0.0:
		return {}

	var distance_ratio: float = 1.0 - clamp(distance / influence_radius, 0.0, 1.0)
	var pull_ratio: float = lerp(minimum_pull_strength, 1.0, distance_ratio * distance_ratio)
	var source_multiplier: float = _get_anchor_source_multiplier(anchor_ball)
	var force_magnitude: float = pull_strength * source_multiplier * pull_ratio * motion_multiplier

	nearest_distance_this_frame = min(nearest_distance_this_frame, distance)
	var pull_direction: Vector2 = offset / distance
	var velocity_delta: Vector2
	if is_stationary_batch:
		var wake_impulse: float = _get_stationary_wake_impulse(anchor_ball, target_ball, force_magnitude, delta)
		if wake_impulse <= 0.0:
			return {}
		velocity_delta = pull_direction * wake_impulse
	else:
		velocity_delta = pull_direction * force_magnitude * delta

	return {
		"anchor_ball": anchor_ball,
		"target_ball": target_ball,
		"offset": offset,
		"distance": distance,
		"pull_direction": pull_direction,
		"force_magnitude": force_magnitude,
		"pull_ratio": pull_ratio,
		"velocity_delta": velocity_delta,
		"is_stationary_batch": is_stationary_batch,
	}


func _apply_anchor_pull_candidate(candidate: Dictionary) -> void:
	var anchor_ball := candidate["anchor_ball"] as Ball
	var target_ball := candidate["target_ball"] as Ball
	if anchor_ball == null or target_ball == null:
		return

	var velocity_delta: Vector2 = candidate["velocity_delta"]
	var pull_direction: Vector2 = candidate["pull_direction"]
	var offset: Vector2 = candidate["offset"]
	target_ball.velocity += velocity_delta
	if bool(candidate["is_stationary_batch"]):
		_start_stationary_wake_cooldown(anchor_ball, target_ball)

	if target_ball.is_moving():
		target_ball.note_anchor_influence(float(candidate["pull_ratio"]), pull_direction)
	_record_force_application(anchor_ball, target_ball, offset, float(candidate["force_magnitude"]))


func _get_stationary_wake_impulse(
	anchor_ball: Ball,
	target_ball: Ball,
	force_magnitude: float,
	delta: float
) -> float:
	if _is_stationary_wake_pair_on_cooldown(anchor_ball, target_ball):
		return 0.0
	if not _has_stationary_wake_pair_changed(anchor_ball, target_ball):
		return 0.0

	var estimated_interval_impulse: float = force_magnitude * max(stationary_pull_update_interval, delta)
	var wake_speed: float = _get_stationary_wake_speed(target_ball, delta)
	if estimated_interval_impulse < wake_speed:
		return 0.0

	var capped_wake_speed: float = min(wake_speed, max_stationary_wake_impulse)
	if capped_wake_speed < target_ball.stop_threshold:
		return 0.0
	return capped_wake_speed


func _get_stationary_wake_speed(target_ball: Ball, delta: float) -> float:
	var friction_buffer: float = target_ball.rolling_friction * target_ball.crawl_speed_drag_multiplier * delta * 2.0
	return max(stationary_min_wake_speed, target_ball.stop_threshold + friction_buffer)


func _is_pull_target(anchor_ball: Ball, target_ball: Ball) -> bool:
	if target_ball == null or target_ball == anchor_ball:
		return false
	return _is_pull_target_candidate(target_ball)


func _is_pull_target_candidate(target_ball: Ball) -> bool:
	if target_ball == null:
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


func _begin_latch_candidate_update() -> void:
	latch_candidate_counts_this_update.clear()


func _record_latch_candidate(target_ball: Ball) -> void:
	if target_ball == null:
		return

	var target_id: int = target_ball.get_instance_id()
	latch_candidate_counts_this_update[target_id] = int(latch_candidate_counts_this_update.get(target_id, 0)) + 1


func _finish_latch_candidate_update() -> void:
	for target_id in latch_candidate_counts_this_update:
		var latch_count: int = int(latch_candidate_counts_this_update[target_id])
		max_anchors_affecting_same_ball_this_frame = max(max_anchors_affecting_same_ball_this_frame, latch_count)
		if latch_count <= 1:
			continue

		multi_latch_candidates_this_frame += latch_count - 1
		multi_latch_target_ids_this_frame[target_id] = true

	latch_candidate_counts_this_update.clear()


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


func _is_stationary_wake_pair_on_cooldown(anchor_ball: Ball, target_ball: Ball) -> bool:
	return stationary_wake_cooldowns.has(_get_pull_pair_key(anchor_ball, target_ball))


func _start_stationary_wake_cooldown(anchor_ball: Ball, target_ball: Ball) -> void:
	var pair_key: String = _get_pull_pair_key(anchor_ball, target_ball)
	stationary_wake_positions[pair_key] = {
		"anchor_position": anchor_ball.global_position,
		"target_position": target_ball.global_position,
	}
	if stationary_wake_cooldown <= 0.0:
		return
	stationary_wake_cooldowns[pair_key] = stationary_wake_cooldown


func _has_stationary_wake_pair_changed(anchor_ball: Ball, target_ball: Ball) -> bool:
	if stationary_wake_recheck_distance <= 0.0:
		return true

	var pair_key: String = _get_pull_pair_key(anchor_ball, target_ball)
	if not stationary_wake_positions.has(pair_key):
		return true

	var wake_position_data: Dictionary = stationary_wake_positions[pair_key]
	var anchor_position: Vector2 = wake_position_data.get("anchor_position", anchor_ball.global_position)
	var target_position: Vector2 = wake_position_data.get("target_position", target_ball.global_position)
	var recheck_distance_squared: float = stationary_wake_recheck_distance * stationary_wake_recheck_distance
	return (
		anchor_ball.global_position.distance_squared_to(anchor_position) >= recheck_distance_squared
		or target_ball.global_position.distance_squared_to(target_position) >= recheck_distance_squared
	)


func _update_post_collision_pull_cooldowns(delta: float) -> void:
	_update_cooldown_dictionary(post_collision_pull_cooldowns, delta)


func _update_stationary_wake_cooldowns(delta: float) -> void:
	_update_cooldown_dictionary(stationary_wake_cooldowns, delta)


func _update_cooldown_dictionary(cooldowns: Dictionary, delta: float) -> void:
	var expired_keys: Array[String] = []
	for pair_key in cooldowns.keys():
		var remaining_time: float = float(cooldowns[pair_key]) - delta
		if remaining_time <= 0.0:
			expired_keys.append(pair_key)
		else:
			cooldowns[pair_key] = remaining_time

	for pair_key in expired_keys:
		cooldowns.erase(pair_key)


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
