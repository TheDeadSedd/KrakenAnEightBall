@tool
extends Node
class_name TreasureBallSystem

# index:title Treasure Ball System
# index:category Mechanics / Anomaly Balls / Systems / Performance Concerns / In Progress
# index:status In Progress
# index:owner anomaly_ball_agent
# index:notes Stage 4 Treasure Ball identity, AimPreview corridor perception, committed hide target selection, threat-scaled hiding movement, and fleeing-leg visual reporting.

# Owns Treasure Ball tracking, perception state, hide target selection, and
# gentle self-steering. Perception is read from AimPreview's corridor snapshot.
const DEBUG_TARGET_LINE_COLOR := Color(0.30, 1.0, 0.82, 0.72)
const DEBUG_TARGET_MARKER_COLOR := Color(0.98, 0.84, 0.36, 0.82)
const DEBUG_FALLBACK_MARKER_COLOR := Color(0.42, 0.76, 1.0, 0.72)
const DEBUG_COVER_LINE_COLOR := Color(1.0, 0.92, 0.48, 0.56)

@export var debug_visual_enabled := false
@export var hiding_movement_enabled := true
@export var cover_search_lateral_radius := 92.0
@export var cover_max_distance_from_treasure := 220.0
@export var hide_behind_padding := 12.0
@export var fallback_flee_distance := 78.0
@export var hide_steering_acceleration := 900.0
@export var fallback_steering_acceleration := 800.0
@export var max_hiding_speed := 440.0
@export var hide_arrival_radius := 16.0
@export var hide_slow_radius := 72.0
@export var perception_corridor_radius := 54.0
@export var direct_aim_panic_lateral_distance := 8.0
@export var minimum_threat_strength := 0.15
@export var direct_aim_panic_multiplier := 4.25
@export var panic_debug_threshold := 0.72
@export var pocket_avoidance_buffer := 24.0
@export var aim_corridor_crossing_side_deadzone := 10.0
@export_range(0.0, 1.0, 0.01) var self_steer_collision_transfer_multiplier := 0.14
@export var self_steer_collision_impulse_cap := 26.0
@export var self_steer_collision_soft_time := 0.18
@export var self_scuttle_braking := 1500.0
@export var self_scuttle_min_speed := 3.0
@export var hide_target_commit_time := 0.75
@export var cover_switch_improvement_threshold := 40.0
@export var minimum_cover_distance_from_cue_origin := 80.0
@export var prefer_away_from_cue_weight := 2.35

var table
var treasure_balls: Array[Ball] = []
var seen_treasure_ball_ids: Dictionary = {}
var hide_targets_by_treasure_id: Dictionary = {}
var visibility_debug_entries: Array[Dictionary] = []
var last_target_switch_reason := "none"
var perception_checks_this_frame := 0
var perception_rebuilds_this_frame := 0
var hide_selection_checks_this_frame := 0
var steering_applications_this_frame := 0
var steering_cover_count_this_frame := 0
var steering_fallback_count_this_frame := 0
var steering_active_this_frame := false
var last_perception_epoch := -1
var self_steering_until_by_ball_id: Dictionary = {}
var self_scuttle_velocity_by_ball_id: Dictionary = {}


func setup(table_ref) -> void:
	table = table_ref


func reset_frame_stats() -> void:
	perception_checks_this_frame = 0
	perception_rebuilds_this_frame = 0
	hide_selection_checks_this_frame = 0
	steering_applications_this_frame = 0
	steering_cover_count_this_frame = 0
	steering_fallback_count_this_frame = 0
	steering_active_this_frame = false
	_prune_self_steering_collision_state()


func register_treasure_ball(ball: Ball) -> void:
	if ball == null or treasure_balls.has(ball):
		return

	treasure_balls.append(ball)


func try_apply_collision_response(ball_a: Ball, ball_b: Ball, normal: Vector2, impulse: Vector2) -> bool:
	if ball_a == null or ball_b == null:
		return false
	if ball_a.is_cannon_ball or ball_b.is_cannon_ball:
		return false
	if ball_a.is_treasure_ball and _is_self_steering_treasure_driving(ball_a, ball_b, normal):
		ball_a.velocity -= impulse
		ball_b.velocity += _get_soft_scuttle_impulse(impulse)
		return true
	if ball_b.is_treasure_ball and _is_self_steering_treasure_driving(ball_b, ball_a, -normal):
		ball_a.velocity -= _get_soft_scuttle_impulse(impulse)
		ball_b.velocity += impulse
		return true
	return false


func handle_aim_perception_snapshot(snapshot: Dictionary) -> void:
	var perception_epoch: int = int(snapshot.get("epoch", -1))
	if perception_epoch == last_perception_epoch:
		return

	last_perception_epoch = perception_epoch
	perception_rebuilds_this_frame += 1
	perception_checks_this_frame += int(snapshot.get("last_rebuild_checks", 0))
	visibility_debug_entries.clear()
	var debug_entries: Array = snapshot.get("visibility_debug_entries", []) as Array
	for debug_entry_value in debug_entries:
		visibility_debug_entries.append(debug_entry_value as Dictionary)
	var seen_ids: Array = snapshot.get("seen_treasure_ball_ids", []) as Array
	_update_seen_treasure_ids(seen_ids)
	_update_hide_targets(snapshot)
	if debug_visual_enabled and table != null:
		table.queue_redraw()


func update_hiding(delta: float) -> void:
	if delta <= 0.0:
		return

	var active_scuttle_ids: Dictionary = {}
	if hiding_movement_enabled and not hide_targets_by_treasure_id.is_empty():
		for ball_id in hide_targets_by_treasure_id:
			var target_data: Dictionary = hide_targets_by_treasure_id[ball_id] as Dictionary
			var commit_remaining: float = max(float(target_data.get("commit_remaining", 0.0)) - delta, 0.0)
			target_data["commit_remaining"] = commit_remaining
			hide_targets_by_treasure_id[ball_id] = target_data

			var treasure_id := int(ball_id)
			if not seen_treasure_ball_ids.has(treasure_id):
				continue

			var treasure_ball: Ball = _get_active_treasure_ball_by_id(treasure_id)
			if treasure_ball == null:
				continue

			if _is_scuttle_target_active(treasure_ball, target_data):
				active_scuttle_ids[treasure_id] = true
				_mark_self_steering_collision_soft(treasure_ball)
			_apply_hiding_steer(treasure_ball, target_data, delta)

	_update_scuttle_velocity(delta, active_scuttle_ids)

	if steering_active_this_frame and debug_visual_enabled and table != null:
		table.queue_redraw()


func get_debug_snapshot() -> Dictionary:
	_prune_tracked_treasure_balls()
	var max_threat_strength := _get_max_threat_strength()
	var visibility_debug_entry: Dictionary = _get_primary_visibility_debug_entry()
	return {
		"active_treasure_balls": _get_active_treasure_ball_count(),
		"seen_treasure_balls": seen_treasure_ball_ids.size(),
		"hide_targets": hide_targets_by_treasure_id.size(),
		"hide_cover_found": _get_hide_cover_found_count(),
		"hide_target_found": not hide_targets_by_treasure_id.is_empty(),
		"hiding_movement_enabled": hiding_movement_enabled,
		"steering_active": steering_active_this_frame,
		"steering_applications": steering_applications_this_frame,
		"steering_cover_count": steering_cover_count_this_frame,
		"steering_fallback_count": steering_fallback_count_this_frame,
		"steering_mode": _get_steering_mode_text(),
		"max_threat_strength": max_threat_strength,
		"panic_active": max_threat_strength >= panic_debug_threshold,
		"visibility_reason": visibility_debug_entry.get("reason", "none"),
		"visibility_lateral_distance": float(visibility_debug_entry.get("lateral_distance", -1.0)),
		"visibility_distance_along_path": float(visibility_debug_entry.get("distance_along_path", -1.0)),
		"visibility_blocker_ball_id": int(visibility_debug_entry.get("blocker_ball_id", -1)),
		"visibility_blocker_lateral_distance": float(visibility_debug_entry.get("blocker_lateral_distance", -1.0)),
		"visibility_blocker_distance_along_path": float(visibility_debug_entry.get("blocker_distance_along_path", -1.0)),
		"target_cover_ball_id": _get_primary_target_cover_ball_id(),
		"target_distance": _get_primary_target_distance(),
		"target_commit_remaining": _get_primary_target_commit_remaining(),
		"target_switch_reason": last_target_switch_reason,
		"perception_checks": perception_checks_this_frame + hide_selection_checks_this_frame,
		"perception_epoch": last_perception_epoch,
		"perception_rebuilds": perception_rebuilds_this_frame,
	}


func set_debug_visual_enabled(enabled_value: bool) -> void:
	debug_visual_enabled = enabled_value
	if table != null:
		table.queue_redraw()


func is_debug_visual_enabled() -> bool:
	return debug_visual_enabled


func draw_debug(canvas: Node2D) -> void:
	if not debug_visual_enabled:
		return

	for ball_id in hide_targets_by_treasure_id:
		var target_data: Dictionary = hide_targets_by_treasure_id[ball_id] as Dictionary
		var treasure_ball: Ball = _get_active_treasure_ball_by_id(int(ball_id))
		var treasure_world_position: Vector2 = target_data["treasure_position"]
		if treasure_ball != null:
			treasure_world_position = treasure_ball.global_position
		var treasure_position: Vector2 = canvas.to_local(treasure_world_position)
		var hide_position: Vector2 = canvas.to_local(target_data["hide_position"])
		var marker_color: Color = DEBUG_TARGET_MARKER_COLOR if bool(target_data["cover_found"]) else DEBUG_FALLBACK_MARKER_COLOR
		canvas.draw_line(treasure_position, hide_position, DEBUG_TARGET_LINE_COLOR, 2.0)
		canvas.draw_circle(hide_position, 6.0, Color(marker_color.r, marker_color.g, marker_color.b, 0.18))
		canvas.draw_arc(hide_position, 8.0, 0.0, TAU, 24, marker_color, 2.0)

		if not bool(target_data["cover_found"]):
			continue

		var cover_position: Vector2 = canvas.to_local(target_data["cover_position"])
		canvas.draw_line(cover_position, hide_position, DEBUG_COVER_LINE_COLOR, 1.6)
		canvas.draw_circle(cover_position, 4.0, DEBUG_COVER_LINE_COLOR)


func _update_seen_treasure_ids(seen_ids: Array) -> void:
	_prune_tracked_treasure_balls()
	seen_treasure_ball_ids.clear()
	for seen_id in seen_ids:
		var ball_id: int = int(seen_id)
		if _has_active_treasure_ball_id(ball_id):
			seen_treasure_ball_ids[ball_id] = true


func _update_hide_targets(snapshot: Dictionary) -> void:
	var seen_entries: Array = snapshot.get("seen_treasure_balls", []) as Array
	if seen_entries.is_empty():
		hide_targets_by_treasure_id.clear()
		last_target_switch_reason = "not_seen"
		return

	var path_points: Array = snapshot.get("aim_path_points", []) as Array
	var cover_candidates: Array = snapshot.get("cover_candidates", []) as Array
	var aim_direction: Vector2 = Vector2.ZERO
	if snapshot.has("aim_direction"):
		aim_direction = snapshot["aim_direction"]
	var aim_origin: Vector2 = _get_path_origin(path_points)
	if snapshot.has("aim_origin"):
		aim_origin = snapshot["aim_origin"]
	var kept_targets: Dictionary = {}
	last_target_switch_reason = "none"
	for seen_entry_value in seen_entries:
		var seen_entry: Dictionary = seen_entry_value as Dictionary
		var treasure_id: int = int(seen_entry.get("ball_id", -1))
		var treasure_ball: Ball = _get_active_treasure_ball_by_id(treasure_id)
		if treasure_ball == null:
			continue

		var target_data: Dictionary = _select_hide_target_for_treasure(
			treasure_ball,
			seen_entry,
			path_points,
			cover_candidates,
			aim_direction,
			aim_origin
		)
		var current_target: Dictionary = hide_targets_by_treasure_id.get(treasure_id, {}) as Dictionary
		var chosen_target: Dictionary = _choose_committed_hide_target(
			treasure_ball,
			current_target,
			target_data,
			seen_entry,
			cover_candidates,
			path_points,
			aim_origin
		)
		if not chosen_target.is_empty():
			kept_targets[treasure_id] = chosen_target

	hide_targets_by_treasure_id = kept_targets


func _select_hide_target_for_treasure(
	treasure_ball: Ball,
	seen_entry: Dictionary,
	path_points: Array,
	cover_candidates: Array,
	aim_direction: Vector2,
	aim_origin: Vector2
) -> Dictionary:
	var treasure_position: Vector2 = treasure_ball.global_position
	if seen_entry.has("position"):
		treasure_position = seen_entry["position"]
	var treasure_path_distance: float = float(seen_entry.get("distance_along_path", _get_path_total_distance(path_points)))
	var threat_strength: float = _get_threat_strength_from_seen_entry(seen_entry)
	var best_cover: Dictionary = _find_best_cover_ball(
		treasure_ball,
		treasure_position,
		treasure_path_distance,
		path_points,
		cover_candidates,
		aim_origin
	)
	if not best_cover.is_empty():
		var hide_position: Vector2 = _get_cover_hide_position(treasure_ball, best_cover)
		if best_cover.has("hide_position"):
			hide_position = best_cover["hide_position"]
		return {
			"treasure_position": treasure_position,
			"hide_position": hide_position,
			"cover_found": true,
			"mode": "cover",
			"threat_strength": threat_strength,
			"cover_position": best_cover["position"],
			"cover_ball_id": best_cover["ball_id"],
			"score": best_cover["score"],
			"commit_remaining": hide_target_commit_time,
			"switch_reason": "new_cover",
		}

	var fallback_position: Vector2 = _get_fallback_flee_position(treasure_position, path_points, aim_direction, treasure_ball.radius)
	return {
		"treasure_position": treasure_position,
		"hide_position": fallback_position,
		"cover_found": false,
		"mode": "fallback",
		"threat_strength": threat_strength,
		"cover_position": Vector2.ZERO,
		"cover_ball_id": -1,
		"score": INF,
		"commit_remaining": hide_target_commit_time,
		"switch_reason": "fallback",
	}


func _apply_hiding_steer(treasure_ball: Ball, target_data: Dictionary, delta: float) -> bool:
	var target_position: Vector2 = treasure_ball.global_position
	if target_data.has("hide_position"):
		target_position = target_data["hide_position"]
	var to_target: Vector2 = target_position - treasure_ball.global_position
	var distance_to_target: float = to_target.length()
	if distance_to_target <= hide_arrival_radius:
		return false

	var target_direction: Vector2 = to_target / distance_to_target
	var distance_factor: float = 1.0
	if hide_slow_radius > hide_arrival_radius:
		distance_factor = clamp(
			(distance_to_target - hide_arrival_radius) / (hide_slow_radius - hide_arrival_radius),
			0.25,
			1.0
		)

	var threat_strength: float = clamp(float(target_data.get("threat_strength", minimum_threat_strength)), minimum_threat_strength, 1.0)
	var threat_multiplier: float = lerp(1.0, direct_aim_panic_multiplier, threat_strength)
	var acceleration: float = hide_steering_acceleration if bool(target_data.get("cover_found", false)) else fallback_steering_acceleration
	acceleration *= threat_multiplier
	var current_speed_toward_target: float = treasure_ball.velocity.dot(target_direction)
	var threat_speed_cap: float = max_hiding_speed * threat_multiplier
	var available_steering_speed: float = max(threat_speed_cap * distance_factor - current_speed_toward_target, 0.0)
	if available_steering_speed <= 0.0:
		return false

	var steering_speed: float = min(acceleration * delta, available_steering_speed)
	if steering_speed <= 0.0:
		return false

	# Only cap Treasure's self-steering component; impacts/collisions can still dominate.
	var steering_delta: Vector2 = target_direction * steering_speed
	treasure_ball.velocity += steering_delta
	_add_scuttle_velocity(treasure_ball, steering_delta)
	_mark_self_steering_collision_soft(treasure_ball)
	var visual_direction: Vector2 = target_direction
	if treasure_ball.velocity.length_squared() > 0.001:
		visual_direction = treasure_ball.velocity
	treasure_ball.note_treasure_fleeing(threat_strength, visual_direction)
	steering_active_this_frame = true
	steering_applications_this_frame += 1
	if bool(target_data.get("cover_found", false)):
		steering_cover_count_this_frame += 1
	else:
		steering_fallback_count_this_frame += 1
	return true


func _is_scuttle_target_active(treasure_ball: Ball, target_data: Dictionary) -> bool:
	if treasure_ball == null:
		return false

	var target_position: Vector2 = treasure_ball.global_position
	if target_data.has("hide_position"):
		target_position = target_data["hide_position"]
	return treasure_ball.global_position.distance_to(target_position) > hide_arrival_radius


func _choose_committed_hide_target(
	treasure_ball: Ball,
	current_target: Dictionary,
	new_target: Dictionary,
	seen_entry: Dictionary,
	cover_candidates: Array,
	path_points: Array,
	aim_origin: Vector2
) -> Dictionary:
	var current_reason: String = _get_current_target_invalid_reason(
		treasure_ball,
		current_target,
		seen_entry,
		cover_candidates,
		path_points,
		aim_origin
	)
	if current_reason == "none":
		current_target["treasure_position"] = seen_entry.get("position", treasure_ball.global_position)
		current_target["threat_strength"] = _get_threat_strength_from_seen_entry(seen_entry)
		var current_commit_remaining: float = float(current_target.get("commit_remaining", 0.0))
		if not _new_target_is_worth_switching(current_target, new_target):
			var keep_reason := "kept_committed" if current_commit_remaining > 0.0 and bool(current_target.get("cover_found", false)) else "kept_current"
			current_target["switch_reason"] = keep_reason
			last_target_switch_reason = keep_reason
			return current_target

	var chosen_target: Dictionary = new_target
	if chosen_target.is_empty():
		last_target_switch_reason = current_reason
		return {}

	if current_reason == "none":
		chosen_target["switch_reason"] = "switched_better"
		last_target_switch_reason = "switched_better"
	else:
		chosen_target["switch_reason"] = current_reason
		last_target_switch_reason = current_reason
	chosen_target["commit_remaining"] = hide_target_commit_time
	return chosen_target


func _get_current_target_invalid_reason(
	treasure_ball: Ball,
	current_target: Dictionary,
	seen_entry: Dictionary,
	cover_candidates: Array,
	path_points: Array,
	aim_origin: Vector2
) -> String:
	if current_target.is_empty():
		return "new_target"

	var target_position: Vector2 = treasure_ball.global_position
	if current_target.has("hide_position"):
		target_position = current_target["hide_position"]
	if treasure_ball.global_position.distance_to(target_position) <= hide_arrival_radius:
		return "reached_target"
	if not _is_hide_path_pocket_safe(treasure_ball.global_position, target_position, treasure_ball.radius):
		return "target_near_pocket"
	if _does_hide_path_cross_aim_corridor(treasure_ball.global_position, target_position, path_points):
		return "target_crosses_aim"

	if not bool(current_target.get("cover_found", false)):
		return "none"

	var cover_id: int = int(current_target.get("cover_ball_id", -1))
	var cover_ball: Ball = _get_gameplay_ball_by_id(cover_id)
	if cover_ball == null:
		return "cover_removed"

	var treasure_position: Vector2 = treasure_ball.global_position
	if seen_entry.has("position"):
		treasure_position = seen_entry["position"]
	if cover_ball.global_position.distance_to(treasure_position) > cover_max_distance_from_treasure:
		return "cover_too_far"

	var current_cover_candidate: Dictionary = _find_cover_candidate_by_id(cover_id, cover_candidates)
	if current_cover_candidate.is_empty():
		return "cover_outside_aim"

	var treasure_path_distance: float = float(seen_entry.get("distance_along_path", _get_path_total_distance(path_points)))
	var cover_path_distance: float = float(current_cover_candidate.get("distance_along_path", -1.0))
	if cover_path_distance <= 1.0 or cover_path_distance >= treasure_path_distance - treasure_ball.radius:
		return "cover_not_between"

	var hide_position: Vector2 = _get_cover_hide_position(treasure_ball, current_cover_candidate)
	if aim_origin.distance_to(hide_position) < aim_origin.distance_to(treasure_position):
		return "cover_pulls_toward_cue"
	if not _is_hide_path_pocket_safe(treasure_position, hide_position, treasure_ball.radius):
		return "target_near_pocket"
	if _does_hide_path_cross_aim_corridor(treasure_position, hide_position, path_points):
		return "target_crosses_aim"

	current_target["cover_position"] = cover_ball.global_position
	current_target["hide_position"] = hide_position
	current_target["score"] = _score_cover_candidate(
		treasure_ball,
		treasure_position,
		current_cover_candidate,
		hide_position,
		aim_origin
	)
	return "none"


func _new_target_is_worth_switching(current_target: Dictionary, new_target: Dictionary) -> bool:
	if new_target.is_empty():
		return false
	if bool(new_target.get("cover_found", false)) and not bool(current_target.get("cover_found", false)):
		return true
	if not bool(new_target.get("cover_found", false)) and bool(current_target.get("cover_found", false)):
		return false

	var current_score: float = float(current_target.get("score", INF))
	var new_score: float = float(new_target.get("score", INF))
	return new_score <= current_score - cover_switch_improvement_threshold


func _get_threat_strength_from_seen_entry(seen_entry: Dictionary) -> float:
	var lateral_distance: float = float(seen_entry.get("lateral_distance", perception_corridor_radius))
	var panic_span: float = max(perception_corridor_radius - direct_aim_panic_lateral_distance, 1.0)
	var raw_threat: float = 1.0 - clamp((lateral_distance - direct_aim_panic_lateral_distance) / panic_span, 0.0, 1.0)
	return clamp(max(minimum_threat_strength, raw_threat), 0.0, 1.0)


func _find_best_cover_ball(
	treasure_ball: Ball,
	treasure_position: Vector2,
	treasure_path_distance: float,
	path_points: Array,
	cover_candidates: Array,
	aim_origin: Vector2
) -> Dictionary:
	if path_points.size() < 2:
		return {}

	var best_cover: Dictionary = {}
	var best_score := INF
	for candidate_value in cover_candidates:
		hide_selection_checks_this_frame += 1
		var candidate: Dictionary = candidate_value as Dictionary
		var candidate_id: int = int(candidate.get("ball_id", -1))
		if candidate_id == treasure_ball.get_instance_id():
			continue

		var candidate_position := Vector2.ZERO
		if candidate.has("position"):
			candidate_position = candidate["position"]
		var distance_from_treasure: float = candidate_position.distance_to(treasure_position)
		if distance_from_treasure > cover_max_distance_from_treasure:
			continue

		var distance_along_path: float = float(candidate.get("distance_along_path", -1.0))
		if distance_along_path <= 1.0 or distance_along_path >= treasure_path_distance - treasure_ball.radius:
			continue

		var lateral_distance: float = float(candidate.get("lateral_distance", INF))
		if lateral_distance > cover_search_lateral_radius:
			continue

		var cover_data: Dictionary = candidate.duplicate()
		if not cover_data.has("segment_direction"):
			cover_data["segment_direction"] = Vector2.RIGHT
		var hide_position: Vector2 = _get_cover_hide_position(treasure_ball, cover_data)
		if not _is_hide_path_pocket_safe(treasure_position, hide_position, treasure_ball.radius):
			continue
		if _does_hide_path_cross_aim_corridor(treasure_position, hide_position, path_points):
			continue
		var away_gain: float = aim_origin.distance_to(hide_position) - aim_origin.distance_to(treasure_position)
		var score: float = _score_cover_candidate(treasure_ball, treasure_position, cover_data, hide_position, aim_origin)
		if score >= best_score:
			continue

		best_score = score
		best_cover = cover_data
		best_cover["score"] = score
		best_cover["hide_position"] = hide_position
		best_cover["away_gain"] = away_gain

	return best_cover


func _get_cover_hide_position(treasure_ball: Ball, cover_data: Dictionary) -> Vector2:
	var cover_position := Vector2.ZERO
	if cover_data.has("position"):
		cover_position = cover_data["position"]
	var cover_radius: float = float(cover_data.get("radius", treasure_ball.radius))
	var path_direction := Vector2.RIGHT
	if cover_data.has("segment_direction"):
		path_direction = cover_data["segment_direction"]
	if path_direction.length_squared() <= 0.001:
		path_direction = Vector2.RIGHT

	var hide_distance: float = cover_radius + treasure_ball.radius + hide_behind_padding
	return _clamp_to_playfield(cover_position + path_direction.normalized() * hide_distance, treasure_ball.radius)


func _score_cover_candidate(
	treasure_ball: Ball,
	treasure_position: Vector2,
	cover_data: Dictionary,
	hide_position: Vector2,
	aim_origin: Vector2
) -> float:
	var lateral_distance: float = float(cover_data.get("lateral_distance", cover_search_lateral_radius))
	var cover_position := Vector2.ZERO
	if cover_data.has("position"):
		cover_position = cover_data["position"]
	var distance_from_treasure: float = cover_position.distance_to(treasure_position)
	var distance_along_path: float = float(cover_data.get("distance_along_path", 0.0))
	var away_gain: float = aim_origin.distance_to(hide_position) - aim_origin.distance_to(treasure_position)
	var pulls_toward_cue_penalty := 0.0
	if away_gain < 0.0:
		pulls_toward_cue_penalty = abs(away_gain) * prefer_away_from_cue_weight

	var blocks_corridor_bonus := 0.0
	if lateral_distance <= float(cover_data.get("radius", treasure_ball.radius)) + 4.0:
		blocks_corridor_bonus = 24.0

	var minimum_origin_penalty: float = max(minimum_cover_distance_from_cue_origin - distance_along_path, 0.0) * 0.8
	return (
		lateral_distance * 1.55
		+ distance_from_treasure * 0.28
		+ pulls_toward_cue_penalty
		+ minimum_origin_penalty
		- max(away_gain, 0.0) * prefer_away_from_cue_weight
		- blocks_corridor_bonus
	)


func _get_fallback_flee_position(
	treasure_position: Vector2,
	path_points: Array,
	aim_direction: Vector2,
	treasure_radius: float
) -> Vector2:
	var direction: Vector2 = aim_direction
	if direction.length_squared() <= 0.001 and path_points.size() >= 2:
		direction = path_points[path_points.size() - 1] - path_points[0]
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT

	var perpendicular: Vector2 = direction.normalized().orthogonal()
	var options: Array[Vector2] = [
		_clamp_to_playfield(treasure_position + perpendicular * fallback_flee_distance, treasure_radius),
		_clamp_to_playfield(treasure_position - perpendicular * fallback_flee_distance, treasure_radius),
		_clamp_to_playfield(treasure_position - direction.normalized() * fallback_flee_distance, treasure_radius),
	]
	var best_position: Vector2 = treasure_position
	var best_score := -1.0e20
	for option_value in options:
		var option: Vector2 = option_value
		if not _is_hide_path_pocket_safe(treasure_position, option, treasure_radius):
			continue
		if _does_hide_path_cross_aim_corridor(treasure_position, option, path_points):
			continue
		var score: float = treasure_position.distance_squared_to(option)
		if table != null:
			score += table.playfield_rect.get_center().distance_squared_to(option) * 0.001
		if score > best_score:
			best_score = score
			best_position = option

	if best_score > -1.0e20:
		return best_position

	for option_value in options:
		var option: Vector2 = option_value
		if not _is_hide_path_pocket_safe(treasure_position, option, treasure_radius):
			continue
		var score: float = treasure_position.distance_squared_to(option)
		if score > best_score:
			best_score = score
			best_position = option

	if best_score > -1.0e20:
		return best_position

	return _push_position_away_from_pockets(
		_clamp_to_playfield(treasure_position + perpendicular * fallback_flee_distance, treasure_radius),
		treasure_radius
	)


func _project_point_onto_path(point: Vector2, path_points: Array) -> Dictionary:
	var best_projection: Dictionary = {}
	var best_distance := INF
	var distance_before_segment := 0.0
	for point_index in range(path_points.size() - 1):
		var segment_start: Vector2 = path_points[point_index]
		var segment_end: Vector2 = path_points[point_index + 1]
		var segment: Vector2 = segment_end - segment_start
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			continue

		var segment_fraction: float = clamp((point - segment_start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var closest_point: Vector2 = segment_start + segment * segment_fraction
		var lateral_distance: float = point.distance_to(closest_point)
		if lateral_distance < best_distance:
			best_distance = lateral_distance
			best_projection = {
				"closest_point": closest_point,
				"lateral_distance": lateral_distance,
				"distance_along_path": distance_before_segment + segment_length * segment_fraction,
				"segment_direction": segment / segment_length,
			}

		distance_before_segment += segment_length

	return best_projection


func _get_path_total_distance(path_points: Array) -> float:
	var total_distance := 0.0
	for point_index in range(path_points.size() - 1):
		var start: Vector2 = path_points[point_index]
		var end: Vector2 = path_points[point_index + 1]
		total_distance += start.distance_to(end)
	return total_distance


func _get_path_origin(path_points: Array) -> Vector2:
	if path_points.is_empty():
		return Vector2.ZERO

	return path_points[0]


func _clamp_to_playfield(position: Vector2, inset: float) -> Vector2:
	if table == null or table.playfield_rect.size == Vector2.ZERO:
		return position

	var safe_rect: Rect2 = table.playfield_rect.grow(-inset)
	var safe_end: Vector2 = safe_rect.position + safe_rect.size
	return Vector2(
		clamp(position.x, safe_rect.position.x, safe_end.x),
		clamp(position.y, safe_rect.position.y, safe_end.y)
	)


func _is_hide_path_pocket_safe(start_position: Vector2, end_position: Vector2, ball_radius: float) -> bool:
	if not _is_position_pocket_safe(end_position, ball_radius):
		return false
	return not _does_segment_enter_pocket_buffer(start_position, end_position, ball_radius)


func _is_position_pocket_safe(position: Vector2, ball_radius: float) -> bool:
	if table == null or table.pocket_system == null:
		return true
	return not table.pocket_system.is_position_too_close_to_pocket(position, ball_radius, pocket_avoidance_buffer)


func _does_segment_enter_pocket_buffer(start_position: Vector2, end_position: Vector2, ball_radius: float) -> bool:
	if table == null or table.pocket_system == null:
		return false

	var segment: Vector2 = end_position - start_position
	var segment_length_sq: float = segment.length_squared()
	if segment_length_sq <= 0.001:
		return false

	var pocket_positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
	var pocket_radii: Array[float] = table.pocket_system.get_pocket_radii()
	var pocket_count: int = mini(pocket_positions.size(), pocket_radii.size())
	for pocket_index in range(pocket_count):
		var pocket_position: Vector2 = pocket_positions[pocket_index]
		var buffer_radius: float = pocket_radii[pocket_index] + ball_radius + pocket_avoidance_buffer
		var buffer_radius_sq: float = buffer_radius * buffer_radius
		var start_distance_sq: float = start_position.distance_squared_to(pocket_position)
		var end_distance_sq: float = end_position.distance_squared_to(pocket_position)
		if start_distance_sq <= buffer_radius_sq and end_distance_sq > start_distance_sq:
			continue

		var segment_fraction: float = clamp(
			(pocket_position - start_position).dot(segment) / segment_length_sq,
			0.0,
			1.0
		)
		var closest_point: Vector2 = start_position + segment * segment_fraction
		if closest_point.distance_squared_to(pocket_position) <= buffer_radius_sq:
			return true

	return false


func _push_position_away_from_pockets(position: Vector2, ball_radius: float) -> Vector2:
	if table == null or table.pocket_system == null:
		return _clamp_to_playfield(position, ball_radius)

	var adjusted_position: Vector2 = position
	var pocket_positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
	var pocket_radii: Array[float] = table.pocket_system.get_pocket_radii()
	var pocket_count: int = mini(pocket_positions.size(), pocket_radii.size())
	for pocket_index in range(pocket_count):
		var pocket_position: Vector2 = pocket_positions[pocket_index]
		var safe_distance: float = pocket_radii[pocket_index] + ball_radius + pocket_avoidance_buffer
		var from_pocket: Vector2 = adjusted_position - pocket_position
		if from_pocket.length() >= safe_distance:
			continue

		var push_direction: Vector2 = from_pocket.normalized()
		if push_direction.length_squared() <= 0.001 and table.playfield_rect.size != Vector2.ZERO:
			push_direction = (adjusted_position - table.playfield_rect.get_center()).normalized()
		if push_direction.length_squared() <= 0.001:
			push_direction = Vector2.RIGHT
		adjusted_position = pocket_position + push_direction * safe_distance

	return _clamp_to_playfield(adjusted_position, ball_radius)


func _does_hide_path_cross_aim_corridor(start_position: Vector2, end_position: Vector2, path_points: Array) -> bool:
	if path_points.size() < 2:
		return false

	var start_side: float = _get_point_side_of_aim_path(start_position, path_points)
	var end_side: float = _get_point_side_of_aim_path(end_position, path_points)
	var side_deadzone: float = max(aim_corridor_crossing_side_deadzone, 1.0)
	if absf(start_side) <= side_deadzone or absf(end_side) <= side_deadzone:
		return false

	return (
		(start_side < 0.0 and end_side > 0.0)
		or (start_side > 0.0 and end_side < 0.0)
	)


func _get_point_side_of_aim_path(point: Vector2, path_points: Array) -> float:
	var projection: Dictionary = _project_point_onto_path(point, path_points)
	if projection.is_empty():
		return 0.0

	var segment_direction: Vector2 = projection["segment_direction"]
	if segment_direction.length_squared() <= 0.001:
		return 0.0
	var closest_point: Vector2 = projection["closest_point"]
	return segment_direction.cross(point - closest_point)


func _mark_self_steering_collision_soft(treasure_ball: Ball) -> void:
	if treasure_ball == null or self_steer_collision_soft_time <= 0.0:
		return

	var expires_at_msec: int = Time.get_ticks_msec() + int(self_steer_collision_soft_time * 1000.0)
	self_steering_until_by_ball_id[treasure_ball.get_instance_id()] = expires_at_msec


func _add_scuttle_velocity(treasure_ball: Ball, steering_delta: Vector2) -> void:
	if treasure_ball == null or steering_delta.length_squared() <= 0.001:
		return

	var ball_id: int = treasure_ball.get_instance_id()
	var scuttle_velocity: Vector2 = _get_stored_scuttle_velocity(ball_id) + steering_delta
	self_scuttle_velocity_by_ball_id[ball_id] = _get_scuttle_velocity_aligned_to_ball(treasure_ball, scuttle_velocity)


func _update_scuttle_velocity(delta: float, active_scuttle_ids: Dictionary) -> void:
	if self_scuttle_velocity_by_ball_id.is_empty():
		return

	var kept_scuttle_velocity: Dictionary = {}
	for ball_id in self_scuttle_velocity_by_ball_id:
		var treasure_ball: Ball = _get_active_treasure_ball_by_id(int(ball_id))
		if treasure_ball == null:
			continue

		var stored_scuttle_velocity: Vector2 = self_scuttle_velocity_by_ball_id[ball_id]
		var scuttle_velocity: Vector2 = _get_scuttle_velocity_aligned_to_ball(
			treasure_ball,
			stored_scuttle_velocity
		)
		if scuttle_velocity.length() <= self_scuttle_min_speed:
			continue

		if not active_scuttle_ids.has(int(ball_id)):
			var previous_scuttle_velocity: Vector2 = scuttle_velocity
			scuttle_velocity = scuttle_velocity.move_toward(Vector2.ZERO, self_scuttle_braking * delta)
			treasure_ball.velocity -= previous_scuttle_velocity - scuttle_velocity

		scuttle_velocity = _get_scuttle_velocity_aligned_to_ball(treasure_ball, scuttle_velocity)
		if scuttle_velocity.length() > self_scuttle_min_speed:
			kept_scuttle_velocity[ball_id] = scuttle_velocity

	self_scuttle_velocity_by_ball_id = kept_scuttle_velocity


func _get_stored_scuttle_velocity(ball_id: int) -> Vector2:
	if not self_scuttle_velocity_by_ball_id.has(ball_id):
		return Vector2.ZERO
	var stored_scuttle_velocity: Vector2 = self_scuttle_velocity_by_ball_id[ball_id]
	return stored_scuttle_velocity


func _get_scuttle_velocity_aligned_to_ball(treasure_ball: Ball, scuttle_velocity: Vector2) -> Vector2:
	if treasure_ball == null or scuttle_velocity.length_squared() <= 0.001:
		return Vector2.ZERO
	if treasure_ball.velocity.length_squared() <= 0.001:
		return Vector2.ZERO

	var scuttle_direction: Vector2 = scuttle_velocity.normalized()
	var ball_speed_along_scuttle: float = treasure_ball.velocity.dot(scuttle_direction)
	if ball_speed_along_scuttle <= 0.0:
		return Vector2.ZERO
	return scuttle_direction * min(scuttle_velocity.length(), ball_speed_along_scuttle)


func _get_soft_scuttle_impulse(impulse: Vector2) -> Vector2:
	var soft_impulse: Vector2 = impulse * self_steer_collision_transfer_multiplier
	if self_steer_collision_impulse_cap > 0.0:
		soft_impulse = soft_impulse.limit_length(self_steer_collision_impulse_cap)
	return soft_impulse


func _is_self_steering_treasure_driving(treasure_ball: Ball, other_ball: Ball, treasure_to_other_normal: Vector2) -> bool:
	if not _is_self_steering_collision_soft_active(treasure_ball):
		return false
	if treasure_to_other_normal.length_squared() <= 0.001:
		return false

	var normal: Vector2 = treasure_to_other_normal.normalized()
	var scuttle_velocity: Vector2 = _get_scuttle_velocity_aligned_to_ball(
		treasure_ball,
		_get_stored_scuttle_velocity(treasure_ball.get_instance_id())
	)
	var treasure_speed_toward_other: float = max(scuttle_velocity.dot(normal), 0.0)
	var other_speed_toward_treasure: float = max(-other_ball.velocity.dot(normal), 0.0)
	return treasure_speed_toward_other > self_scuttle_min_speed and treasure_speed_toward_other > other_speed_toward_treasure


func _is_self_steering_collision_soft_active(treasure_ball: Ball) -> bool:
	if treasure_ball == null or not treasure_ball.is_treasure_ball:
		return false

	var ball_id: int = treasure_ball.get_instance_id()
	var expires_at_msec: int = int(self_steering_until_by_ball_id.get(ball_id, 0))
	if Time.get_ticks_msec() > expires_at_msec:
		self_steering_until_by_ball_id.erase(ball_id)
		return false
	return true


func _prune_self_steering_collision_state() -> void:
	if self_steering_until_by_ball_id.is_empty() and self_scuttle_velocity_by_ball_id.is_empty():
		return

	var current_time_msec: int = Time.get_ticks_msec()
	var kept_state: Dictionary = {}
	for ball_id in self_steering_until_by_ball_id:
		if int(self_steering_until_by_ball_id[ball_id]) <= current_time_msec:
			continue
		if _has_active_treasure_ball_id(int(ball_id)):
			kept_state[ball_id] = self_steering_until_by_ball_id[ball_id]
	self_steering_until_by_ball_id = kept_state

	var kept_scuttle_velocity: Dictionary = {}
	for ball_id in self_scuttle_velocity_by_ball_id:
		var treasure_ball: Ball = _get_active_treasure_ball_by_id(int(ball_id))
		if treasure_ball == null:
			continue

		var stored_scuttle_velocity: Vector2 = self_scuttle_velocity_by_ball_id[ball_id]
		var scuttle_velocity: Vector2 = _get_scuttle_velocity_aligned_to_ball(
			treasure_ball,
			stored_scuttle_velocity
		)
		if scuttle_velocity.length() > self_scuttle_min_speed:
			kept_scuttle_velocity[ball_id] = scuttle_velocity
	self_scuttle_velocity_by_ball_id = kept_scuttle_velocity


func _has_active_treasure_ball_id(ball_id: int) -> bool:
	return _get_active_treasure_ball_by_id(ball_id) != null


func _find_cover_candidate_by_id(cover_id: int, cover_candidates: Array) -> Dictionary:
	for candidate_value in cover_candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		if int(candidate.get("ball_id", -1)) == cover_id:
			return candidate

	return {}


func _get_gameplay_ball_by_id(ball_id: int) -> Ball:
	if table == null:
		return null

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball != null and is_instance_valid(ball) and ball.is_gameplay_active() and ball.get_instance_id() == ball_id:
			return ball

	return null


func _get_active_treasure_ball_by_id(ball_id: int) -> Ball:
	for ball in treasure_balls:
		if ball != null and is_instance_valid(ball) and ball.is_gameplay_active() and ball.get_instance_id() == ball_id:
			return ball
	return null


func _get_active_treasure_ball_count() -> int:
	var active_count := 0
	for ball in treasure_balls:
		if ball != null and is_instance_valid(ball) and ball.is_gameplay_active():
			active_count += 1
	return active_count


func _prune_tracked_treasure_balls() -> void:
	var kept_balls: Array[Ball] = []
	for ball in treasure_balls:
		if ball != null and is_instance_valid(ball) and ball.is_treasure_ball:
			kept_balls.append(ball)
	treasure_balls = kept_balls

	var kept_seen_ids: Dictionary = {}
	for ball_id in seen_treasure_ball_ids:
		if _has_active_treasure_ball_id(int(ball_id)):
			kept_seen_ids[ball_id] = true
	seen_treasure_ball_ids = kept_seen_ids

	var kept_hide_targets: Dictionary = {}
	for ball_id in hide_targets_by_treasure_id:
		if _has_active_treasure_ball_id(int(ball_id)):
			kept_hide_targets[ball_id] = hide_targets_by_treasure_id[ball_id]
	hide_targets_by_treasure_id = kept_hide_targets

	var kept_visibility_entries: Array[Dictionary] = []
	for entry_value in visibility_debug_entries:
		var entry: Dictionary = entry_value as Dictionary
		if _has_active_treasure_ball_id(int(entry.get("ball_id", -1))):
			kept_visibility_entries.append(entry)
	visibility_debug_entries = kept_visibility_entries


func _get_steering_mode_text() -> String:
	if not steering_active_this_frame:
		return "none"
	if steering_cover_count_this_frame > 0 and steering_fallback_count_this_frame > 0:
		return "mixed"
	if steering_cover_count_this_frame > 0:
		return "cover"
	return "fallback"


func _get_max_threat_strength() -> float:
	var max_threat := 0.0
	for target_entry in hide_targets_by_treasure_id.values():
		var target_data: Dictionary = target_entry as Dictionary
		max_threat = max(max_threat, float(target_data.get("threat_strength", 0.0)))
	return max_threat


func _get_primary_visibility_debug_entry() -> Dictionary:
	var best_entry: Dictionary = {}
	var best_score := INF
	for entry_value in visibility_debug_entries:
		var entry: Dictionary = entry_value as Dictionary
		var ball_id: int = int(entry.get("ball_id", -1))
		if not _has_active_treasure_ball_id(ball_id):
			continue

		var lateral_distance: float = float(entry.get("lateral_distance", INF))
		var path_distance: float = max(float(entry.get("distance_along_path", 0.0)), 0.0)
		var score: float = lateral_distance + path_distance * 0.001
		if score >= best_score:
			continue

		best_score = score
		best_entry = entry

	return best_entry


func _get_primary_target_entry() -> Dictionary:
	var best_entry: Dictionary = {}
	var best_score := INF
	for target_entry in hide_targets_by_treasure_id.values():
		var target_data: Dictionary = target_entry as Dictionary
		var target_distance: float = _get_target_distance(target_data)
		var score: float = target_distance + float(target_data.get("score", 0.0)) * 0.001
		if score >= best_score:
			continue

		best_score = score
		best_entry = target_data

	return best_entry


func _get_primary_target_cover_ball_id() -> int:
	var target_data: Dictionary = _get_primary_target_entry()
	return int(target_data.get("cover_ball_id", -1))


func _get_primary_target_distance() -> float:
	return _get_target_distance(_get_primary_target_entry())


func _get_primary_target_commit_remaining() -> float:
	var target_data: Dictionary = _get_primary_target_entry()
	return float(target_data.get("commit_remaining", -1.0))


func _get_target_distance(target_data: Dictionary) -> float:
	if target_data.is_empty():
		return -1.0

	var treasure_position := Vector2.ZERO
	if target_data.has("treasure_position"):
		treasure_position = target_data["treasure_position"]
	var hide_position: Vector2 = treasure_position
	if target_data.has("hide_position"):
		hide_position = target_data["hide_position"]
	return treasure_position.distance_to(hide_position)


func _get_hide_cover_found_count() -> int:
	var cover_count := 0
	for target_entry in hide_targets_by_treasure_id.values():
		var target_data: Dictionary = target_entry as Dictionary
		if bool(target_data.get("cover_found", false)):
			cover_count += 1
	return cover_count
