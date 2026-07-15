@tool
extends Node
class_name EmbezzlerSystem

# index:title Embezzler System
# index:category Mechanics / Anomaly Balls / Systems / In Progress
# index:status Prototype
# index:owner anomaly_ball_agent
# index:notes Embezzler identity, copied Doubloon storage, willingness, nervous hiding/repositioning, escape resolution, and capture cashout debug state.

# Owns the Embezzler's anomaly identity/state. It copies a share of positive
# Doubloons into itself, but never changes player score or BallDrop progress.
const MAX_ACTIVE_EMBEZZLERS := 1
const STATE_HIDING := "hiding"
const STATE_STALKING_TARGET := "stalking_target"
const STATE_AGITATED := "agitated"
const STATE_ESCAPE_COMMITTED := "escape_committed"
const STATE_POCKET_TEST_PENDING := "pocket_test_pending"
const STATE_PANIC_RETREAT := "panic_retreat"
const NO_TARGET_POCKET_INDEX := -1
const MAX_WILLINGNESS := 100.0
const PRESSURE_REASON_NONE := "none"
const PRESSURE_REASON_DIRECT_AIM := "direct aim"
const PRESSURE_REASON_NEAR_AIM := "near aim"
const PRESSURE_REASON_CALMING := "calming"

@export_range(0.0, 1.0, 0.01) var skim_rate := 0.20
@export var stored_value_full_willingness := 100.0
@export_range(0.0, 100.0, 1.0) var max_stored_value_baseline_willingness := 45.0
@export_range(0.0, 100.0, 1.0) var direct_aim_pressure_willingness := 48.0
@export_range(0.0, 100.0, 1.0) var near_aim_pressure_willingness := 22.0
@export_range(0.0, 100.0, 1.0) var aim_pressure_decay_per_second := 18.0
@export_range(0.0, 1.0, 0.01) var aim_pressure_linger_time := 0.24
@export var direct_aim_lateral_distance := 12.0
@export var near_aim_lateral_distance := 54.0
@export var hiding_movement_enabled := true
@export_range(0.0, 100.0, 1.0) var stalking_willingness_threshold := 35.0
@export_range(0.0, 100.0, 1.0) var agitated_willingness_threshold := 70.0
@export var cover_search_lateral_radius := 96.0
@export var cover_max_distance_from_embezzler := 230.0
@export var hide_behind_padding := 13.0
@export var fallback_flee_distance := 70.0
@export var passive_reposition_distance := 58.0
@export var pocket_avoidance_buffer := 28.0
@export var aim_corridor_crossing_side_deadzone := 10.0
@export var scuttle_steering_acceleration := 520.0
@export var max_scuttle_speed := 210.0
@export var agitated_speed_multiplier := 1.28
@export var hide_arrival_radius := 15.0
@export var hide_slow_radius := 70.0
@export var move_target_commit_time := 0.78
@export var target_switch_improvement_threshold := 34.0
@export_range(0.0, 1.0, 0.01) var self_steer_collision_transfer_multiplier := 0.12
@export var self_steer_collision_impulse_cap := 22.0
@export var self_steer_collision_soft_time := 0.18
@export var self_scuttle_braking := 1200.0
@export var self_scuttle_min_speed := 3.0
@export_range(0.0, 100.0, 1.0) var escape_roll_min_willingness := 48.0
@export_range(0.0, 1.0, 0.01) var escape_roll_min_chance := 0.08
@export_range(0.0, 1.0, 0.01) var escape_roll_max_chance := 0.62
@export var committed_escape_speed_multiplier := 1.62
@export var committed_pocket_stop_buffer := 18.0
@export var pocket_test_pending_distance := 8.0
@export_range(0.0, 100.0, 1.0) var pocket_roll_min_willingness := 35.0
@export_range(0.0, 1.0, 0.01) var pocket_roll_min_chance := 0.18
@export_range(0.0, 1.0, 0.01) var pocket_roll_max_chance := 0.78
@export var pocket_roll_cooldown_time := 0.9
@export var panic_retreat_duration := 1.15
@export var panic_retreat_distance := 96.0
@export_range(0.0, 100.0, 1.0) var failed_pocket_roll_pressure_drop := 16.0

var table
var embezzler_balls: Array = []
var stored_value_by_ball_id: Dictionary = {}
var skim_fraction_by_ball_id: Dictionary = {}
var target_pocket_index_by_ball_id: Dictionary = {}
var state_by_ball_id: Dictionary = {}
var aim_pressure_by_ball_id: Dictionary = {}
var aim_pressure_linger_by_ball_id: Dictionary = {}
var last_pressure_reason_by_ball_id: Dictionary = {}
var move_targets_by_ball_id: Dictionary = {}
var self_steering_until_by_ball_id: Dictionary = {}
var self_scuttle_velocity_by_ball_id: Dictionary = {}
var hide_committed_by_ball_id: Dictionary = {}
var escape_committed_by_ball_id: Dictionary = {}
var pocket_test_pending_by_ball_id: Dictionary = {}
var last_escape_roll_msec_by_ball_id: Dictionary = {}
var last_pocket_roll_msec_by_ball_id: Dictionary = {}
var panic_retreat_until_by_ball_id: Dictionary = {}
var resolved_capture_ball_ids: Dictionary = {}
var skimmed_total := 0
var pressure_events_count := 0
var last_perception_epoch := -1
var target_switches_total := 0
var blocked_target_attempts_total := 0
var scuttle_applications_this_frame := 0
var last_target_switch_reason := "none"
var last_blocked_target_reason := "none"
var escape_roll_attempts := 0
var escape_roll_successes := 0
var escape_roll_failures := 0
var last_escape_roll_chance := 0.0
var last_escape_roll_reason := "none"
var pocket_test_pending_total := 0
var pocket_roll_attempts := 0
var pocket_roll_successes := 0
var pocket_roll_failures := 0
var last_pocket_roll_chance := 0.0
var last_pocket_roll_result := "none"
var escaped_count := 0
var panic_retreats := 0
var last_escaped_stored_value := 0
var escaped_stored_value_total := 0
var captures_total := 0
var recovered_value_total := 0
var last_recovered_value := 0
var last_capture_pocket_index := NO_TARGET_POCKET_INDEX
var last_capture_pocket_name := "none"
var double_award_preventions := 0
var shot_decision_serial := 0
var last_shot_decision_serial_by_ball_id: Dictionary = {}
var debug_aim_mode_suppressed := false


func setup(table_ref) -> void:
	table = table_ref


func set_debug_aim_mode_suppressed(suppressed: bool) -> void:
	debug_aim_mode_suppressed = suppressed
	if not suppressed:
		return
	for embezzler_ball in embezzler_balls:
		if embezzler_ball != null and is_instance_valid(embezzler_ball):
			embezzler_ball.set_embezzler_visual_state(0.0, 0.0, 0.0)
	embezzler_balls.clear()
	stored_value_by_ball_id.clear()
	skim_fraction_by_ball_id.clear()
	target_pocket_index_by_ball_id.clear()
	state_by_ball_id.clear()
	aim_pressure_by_ball_id.clear()
	aim_pressure_linger_by_ball_id.clear()
	last_pressure_reason_by_ball_id.clear()
	move_targets_by_ball_id.clear()
	self_steering_until_by_ball_id.clear()
	self_scuttle_velocity_by_ball_id.clear()
	hide_committed_by_ball_id.clear()
	escape_committed_by_ball_id.clear()
	pocket_test_pending_by_ball_id.clear()
	last_escape_roll_msec_by_ball_id.clear()
	last_pocket_roll_msec_by_ball_id.clear()
	panic_retreat_until_by_ball_id.clear()
	last_shot_decision_serial_by_ball_id.clear()


func get_debug_aim_active_tracker_count() -> int:
	return embezzler_balls.size() + stored_value_by_ball_id.size()


func reset_frame_stats() -> void:
	scuttle_applications_this_frame = 0
	_prune_self_steering_collision_state()


func can_spawn_embezzler() -> bool:
	if debug_aim_mode_suppressed:
		return true
	_prune_tracked_embezzlers()
	return _get_active_embezzler_count() < MAX_ACTIVE_EMBEZZLERS


func register_embezzler_ball(ball: Ball) -> void:
	if debug_aim_mode_suppressed:
		return
	if ball == null or not is_instance_valid(ball):
		return

	_prune_tracked_embezzlers()
	if embezzler_balls.has(ball):
		return
	if _get_active_embezzler_count() >= MAX_ACTIVE_EMBEZZLERS:
		return

	embezzler_balls.append(ball)
	_initialize_embezzler_state(ball)


func handle_doubloons_awarded(amount: int, _new_total: int = 0) -> void:
	if debug_aim_mode_suppressed:
		return
	if amount <= 0:
		return

	_prune_tracked_embezzlers()
	if embezzler_balls.is_empty():
		return

	for embezzler_ball in embezzler_balls:
		if not _is_active_embezzler_ball(embezzler_ball):
			continue
		_copy_doubloons_into_embezzler(embezzler_ball, amount)


func handle_ball_captured(ball: Ball, sink_context: Dictionary) -> bool:
	if debug_aim_mode_suppressed:
		return false
	if ball == null:
		return false

	var ball_id: int = ball.get_instance_id()
	if resolved_capture_ball_ids.has(ball_id):
		double_award_preventions += 1
		return true
	if not ball.is_embezzler_ball:
		return false

	resolved_capture_ball_ids[ball_id] = true
	var recovered_value: int = int(stored_value_by_ball_id.get(ball_id, 0))
	last_recovered_value = recovered_value
	recovered_value_total += recovered_value
	captures_total += 1
	last_capture_pocket_index = _get_capture_pocket_index(sink_context)
	last_capture_pocket_name = _get_pocket_debug_name(last_capture_pocket_index)

	# Clear identity before emitting score signals so the recovered loot cannot
	# be skimmed back into the same Embezzler during the payout.
	_clear_embezzler_state_for_id(ball_id)
	embezzler_balls.erase(ball)
	ball.is_embezzler_ball = false

	if table != null and table.score_system != null and recovered_value > 0:
		table.score_system.award_embezzler_recovery(recovered_value, sink_context)
	if table != null:
		table.queue_spawn_reward_message(false, false, false, false, _get_capture_callout_text(recovered_value))

	ball.sink()
	ball.queue_free()
	return true


func handle_cue_control_regained() -> void:
	if debug_aim_mode_suppressed:
		return
	# Escape rolls are shot-start decisions now; cue-control regain only clears stale refs.
	_prune_tracked_embezzlers()


func handle_shot_started() -> void:
	if debug_aim_mode_suppressed:
		return
	_prune_tracked_embezzlers()
	if embezzler_balls.is_empty():
		return

	shot_decision_serial += 1
	for embezzler_ball in embezzler_balls:
		if not _is_active_embezzler_ball(embezzler_ball):
			continue
		_resolve_turn_escape_decision(embezzler_ball)


func try_apply_collision_response(ball_a: Ball, ball_b: Ball, normal: Vector2, impulse: Vector2) -> bool:
	if debug_aim_mode_suppressed:
		return false
	if ball_a == null or ball_b == null:
		return false
	if ball_a.is_cannon_ball or ball_b.is_cannon_ball:
		return false
	if ball_a.is_embezzler_ball and _is_self_steering_embezzler_driving(ball_a, ball_b, normal):
		var soft_impulse_to_other: Vector2 = _get_soft_scuttle_impulse(impulse)
		ball_a.velocity -= impulse
		ball_b.velocity += soft_impulse_to_other
		return true
	if ball_b.is_embezzler_ball and _is_self_steering_embezzler_driving(ball_b, ball_a, -normal):
		var soft_impulse_to_ball_a: Vector2 = _get_soft_scuttle_impulse(impulse)
		ball_a.velocity -= soft_impulse_to_ball_a
		ball_b.velocity += impulse
		return true
	return false


func handle_aim_perception_snapshot(snapshot: Dictionary) -> void:
	if debug_aim_mode_suppressed:
		return
	var perception_epoch: int = int(snapshot.get("epoch", -1))
	if perception_epoch == last_perception_epoch:
		return

	last_perception_epoch = perception_epoch
	_prune_tracked_embezzlers()
	if embezzler_balls.is_empty():
		return

	var pressured_ids: Dictionary = {}
	var path_points: Array = snapshot.get("aim_path_points", []) as Array
	var cover_candidates: Array = snapshot.get("cover_candidates", []) as Array
	var aim_direction: Vector2 = Vector2.ZERO
	if snapshot.has("aim_direction"):
		aim_direction = snapshot["aim_direction"]
	var aim_origin: Vector2 = _get_path_origin(path_points)
	if snapshot.has("aim_origin"):
		aim_origin = snapshot["aim_origin"]
	var seen_entries: Array = snapshot.get("seen_embezzler_balls", []) as Array
	for seen_entry_value in seen_entries:
		var seen_entry: Dictionary = seen_entry_value
		var ball_id: int = int(seen_entry.get("ball_id", -1))
		var embezzler_ball: Ball = _get_active_embezzler_ball_by_id(ball_id)
		if embezzler_ball == null:
			continue

		pressured_ids[ball_id] = true
		_apply_aim_pressure(ball_id, seen_entry)
		_update_state_for_ball_id(ball_id)
		if not _is_escape_routing_active(ball_id):
			_update_pressure_move_target(
				embezzler_ball,
				seen_entry,
				path_points,
				cover_candidates,
				aim_direction,
				aim_origin
			)
		_update_embezzler_visual(embezzler_ball)

	for embezzler_ball in embezzler_balls:
		if not _is_active_embezzler_ball(embezzler_ball):
			continue
		var ball_id: int = embezzler_ball.get_instance_id()
		if pressured_ids.has(ball_id):
			continue
		if float(aim_pressure_by_ball_id.get(ball_id, 0.0)) > 0.0:
			last_pressure_reason_by_ball_id[ball_id] = PRESSURE_REASON_CALMING


func update_willingness(delta: float) -> void:
	if debug_aim_mode_suppressed:
		return
	_prune_tracked_embezzlers()
	if embezzler_balls.is_empty():
		return

	for embezzler_ball in embezzler_balls:
		if not _is_active_embezzler_ball(embezzler_ball):
			continue

		var ball_id: int = embezzler_ball.get_instance_id()
		_update_aim_pressure_decay(ball_id, delta)
		_update_state_for_ball_id(ball_id)
		_update_embezzler_visual(embezzler_ball)


func update_repositioning(delta: float) -> void:
	if debug_aim_mode_suppressed:
		return
	if delta <= 0.0:
		return

	_prune_tracked_embezzlers()
	if embezzler_balls.is_empty():
		return

	var active_scuttle_ids: Dictionary = {}
	if hiding_movement_enabled:
		for embezzler_ball in embezzler_balls:
			if not _is_active_embezzler_ball(embezzler_ball):
				continue

			var ball_id: int = embezzler_ball.get_instance_id()
			if not _update_escape_commitment_state(embezzler_ball, delta):
				continue
			_update_state_for_ball_id(ball_id)
			_decay_move_target_commit(ball_id, delta)
			_ensure_passive_target(embezzler_ball)

			var target_data: Dictionary = _get_move_target_data(ball_id)
			if target_data.is_empty():
				continue

			if _is_scuttle_target_active(embezzler_ball, target_data):
				active_scuttle_ids[ball_id] = true
				_mark_self_steering_collision_soft(embezzler_ball)
			_apply_reposition_steer(embezzler_ball, target_data, delta)

	_update_scuttle_velocity(delta, active_scuttle_ids)


func is_prediction_self_motion_active(ball: Ball) -> bool:
	if ball == null or not is_instance_valid(ball) or not hiding_movement_enabled:
		return false
	return move_targets_by_ball_id.has(ball.get_instance_id())


func get_debug_snapshot() -> Dictionary:
	_prune_tracked_embezzlers()
	var primary_ball: Ball = _get_primary_embezzler_ball()
	var target_index: int = NO_TARGET_POCKET_INDEX
	var current_state: String = "none"
	var willingness: float = 0.0
	var baseline_willingness: float = 0.0
	var aim_pressure_willingness: float = 0.0
	var last_pressure_reason: String = PRESSURE_REASON_NONE
	var move_target: Vector2 = Vector2.ZERO
	var move_target_text: String = "none"
	var target_pocket_bias_amount: float = 0.0
	var escape_committed_active: bool = false
	var pocket_test_pending_active: bool = false
	if primary_ball != null:
		var ball_id: int = primary_ball.get_instance_id()
		target_index = int(target_pocket_index_by_ball_id.get(ball_id, NO_TARGET_POCKET_INDEX))
		current_state = str(state_by_ball_id.get(ball_id, STATE_HIDING))
		baseline_willingness = _get_baseline_willingness_for_ball_id(ball_id)
		aim_pressure_willingness = float(aim_pressure_by_ball_id.get(ball_id, 0.0))
		willingness = _get_willingness_for_ball_id(ball_id)
		last_pressure_reason = str(last_pressure_reason_by_ball_id.get(ball_id, PRESSURE_REASON_NONE))
		var target_data: Dictionary = _get_move_target_data(ball_id)
		if not target_data.is_empty():
			move_target = target_data["target_position"]
			move_target_text = str(target_data.get("mode", "unknown"))
			target_pocket_bias_amount = float(target_data.get("target_pocket_bias", 0.0))
		escape_committed_active = _is_escape_committed(ball_id)
		pocket_test_pending_active = _is_pocket_test_pending(ball_id)

	return {
		"active_embezzlers": _get_active_embezzler_count(),
		"stored_value": _get_active_stored_value_total(),
		"skimmed_total": skimmed_total,
		"target_pocket_index": target_index,
		"target_pocket_name": _get_pocket_debug_name(target_index),
		"current_state": current_state,
		"willingness": willingness,
		"baseline_willingness": baseline_willingness,
		"aim_pressure_willingness": aim_pressure_willingness,
		"last_pressure_reason": last_pressure_reason,
		"pressure_events": pressure_events_count,
		"calm_decay_rate": aim_pressure_decay_per_second,
		"move_target": move_target,
		"move_target_mode": move_target_text,
		"target_pocket_bias_amount": target_pocket_bias_amount,
		"target_switches": target_switches_total,
		"blocked_target_attempts": blocked_target_attempts_total,
		"scuttle_applications": scuttle_applications_this_frame,
		"target_switch_reason": last_target_switch_reason,
		"last_blocked_target_reason": last_blocked_target_reason,
		"escape_roll_attempts": escape_roll_attempts,
		"escape_roll_successes": escape_roll_successes,
		"escape_roll_failures": escape_roll_failures,
		"last_escape_roll_chance": last_escape_roll_chance,
		"last_escape_roll_reason": last_escape_roll_reason,
		"escape_committed_active": escape_committed_active,
		"pocket_test_pending_active": pocket_test_pending_active,
		"pocket_test_pending_count": _get_pocket_test_pending_count(),
		"pocket_test_pending_total": pocket_test_pending_total,
		"pocket_roll_attempts": pocket_roll_attempts,
		"pocket_roll_successes": pocket_roll_successes,
		"pocket_roll_failures": pocket_roll_failures,
		"last_pocket_roll_chance": last_pocket_roll_chance,
		"last_pocket_roll_result": last_pocket_roll_result,
		"escaped_count": escaped_count,
		"panic_retreats": panic_retreats,
		"last_escaped_stored_value": last_escaped_stored_value,
		"escaped_stored_value_total": escaped_stored_value_total,
		"captures_total": captures_total,
		"recovered_value_total": recovered_value_total,
		"last_recovered_value": last_recovered_value,
		"last_capture_pocket_index": last_capture_pocket_index,
		"last_capture_pocket_name": last_capture_pocket_name,
		"double_award_preventions": double_award_preventions,
	}


func _initialize_embezzler_state(ball: Ball) -> void:
	var ball_id: int = ball.get_instance_id()
	stored_value_by_ball_id[ball_id] = 0
	skim_fraction_by_ball_id[ball_id] = 0.0
	target_pocket_index_by_ball_id[ball_id] = _choose_secret_target_pocket_index()
	state_by_ball_id[ball_id] = STATE_HIDING
	aim_pressure_by_ball_id[ball_id] = 0.0
	aim_pressure_linger_by_ball_id[ball_id] = 0.0
	last_pressure_reason_by_ball_id[ball_id] = PRESSURE_REASON_NONE
	move_targets_by_ball_id.erase(ball_id)
	self_steering_until_by_ball_id.erase(ball_id)
	self_scuttle_velocity_by_ball_id.erase(ball_id)
	hide_committed_by_ball_id.erase(ball_id)
	escape_committed_by_ball_id.erase(ball_id)
	pocket_test_pending_by_ball_id.erase(ball_id)
	last_escape_roll_msec_by_ball_id.erase(ball_id)
	last_shot_decision_serial_by_ball_id.erase(ball_id)
	last_pocket_roll_msec_by_ball_id.erase(ball_id)
	panic_retreat_until_by_ball_id.erase(ball_id)
	resolved_capture_ball_ids.erase(ball_id)
	_update_embezzler_visual(ball)


func _copy_doubloons_into_embezzler(embezzler_ball: Ball, amount: int) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	var skim_value: float = float(amount) * skim_rate + float(skim_fraction_by_ball_id.get(ball_id, 0.0))
	var copied_amount: int = floori(skim_value)
	skim_fraction_by_ball_id[ball_id] = skim_value - float(copied_amount)
	if copied_amount <= 0:
		return

	stored_value_by_ball_id[ball_id] = int(stored_value_by_ball_id.get(ball_id, 0)) + copied_amount
	skimmed_total += copied_amount
	_update_embezzler_visual(embezzler_ball)


func _apply_aim_pressure(ball_id: int, seen_entry: Dictionary) -> void:
	var lateral_distance: float = float(seen_entry.get("lateral_distance", INF))
	var direct_threshold: float = maxf(direct_aim_lateral_distance, 1.0)
	var near_threshold: float = maxf(near_aim_lateral_distance, direct_threshold + 1.0)
	var edge_intensity: float = 1.0 - clampf(lateral_distance / near_threshold, 0.0, 1.0)
	var pressure_target: float = near_aim_pressure_willingness * maxf(edge_intensity, 0.35)
	var pressure_reason: String = PRESSURE_REASON_NEAR_AIM
	if lateral_distance <= direct_threshold:
		pressure_target = direct_aim_pressure_willingness
		pressure_reason = PRESSURE_REASON_DIRECT_AIM

	var current_pressure: float = float(aim_pressure_by_ball_id.get(ball_id, 0.0))
	aim_pressure_by_ball_id[ball_id] = clampf(maxf(current_pressure, pressure_target), 0.0, MAX_WILLINGNESS)
	aim_pressure_linger_by_ball_id[ball_id] = aim_pressure_linger_time
	last_pressure_reason_by_ball_id[ball_id] = pressure_reason
	pressure_events_count += 1


func _update_aim_pressure_decay(ball_id: int, delta: float) -> void:
	var linger_remaining: float = float(aim_pressure_linger_by_ball_id.get(ball_id, 0.0))
	if linger_remaining > 0.0:
		aim_pressure_linger_by_ball_id[ball_id] = maxf(linger_remaining - delta, 0.0)
		return

	var current_pressure: float = float(aim_pressure_by_ball_id.get(ball_id, 0.0))
	if current_pressure <= 0.0:
		aim_pressure_by_ball_id[ball_id] = 0.0
		if str(last_pressure_reason_by_ball_id.get(ball_id, PRESSURE_REASON_NONE)) == PRESSURE_REASON_CALMING:
			last_pressure_reason_by_ball_id[ball_id] = PRESSURE_REASON_NONE
		return

	var next_pressure: float = move_toward(current_pressure, 0.0, aim_pressure_decay_per_second * delta)
	aim_pressure_by_ball_id[ball_id] = next_pressure
	if next_pressure > 0.0:
		last_pressure_reason_by_ball_id[ball_id] = PRESSURE_REASON_CALMING
	else:
		last_pressure_reason_by_ball_id[ball_id] = PRESSURE_REASON_NONE


func _get_baseline_willingness_for_ball_id(ball_id: int) -> float:
	var stored_value: float = float(stored_value_by_ball_id.get(ball_id, 0))
	if stored_value <= 0.0:
		return 0.0

	var full_value: float = maxf(stored_value_full_willingness, 1.0)
	var stored_ratio: float = clampf(stored_value / full_value, 0.0, 1.0)
	return stored_ratio * max_stored_value_baseline_willingness


func _get_willingness_for_ball_id(ball_id: int) -> float:
	var baseline_willingness: float = _get_baseline_willingness_for_ball_id(ball_id)
	var aim_pressure_willingness: float = float(aim_pressure_by_ball_id.get(ball_id, 0.0))
	return clampf(baseline_willingness + aim_pressure_willingness, 0.0, MAX_WILLINGNESS)


func _update_embezzler_visual(embezzler_ball: Ball) -> void:
	if not _is_active_embezzler_ball(embezzler_ball):
		return

	var ball_id: int = embezzler_ball.get_instance_id()
	var willingness_strength: float = _get_willingness_for_ball_id(ball_id) / MAX_WILLINGNESS
	if _is_escape_committed(ball_id):
		willingness_strength = maxf(willingness_strength, 0.86)
	if _is_pocket_test_pending(ball_id):
		willingness_strength = maxf(willingness_strength, 0.96)
	var stored_value_strength: float = _get_stored_value_visual_strength(ball_id)
	var escape_strength: float = 1.0 if _is_escape_committed(ball_id) else 0.0
	embezzler_ball.set_embezzler_visual_state(willingness_strength, stored_value_strength, escape_strength)


func _get_stored_value_visual_strength(ball_id: int) -> float:
	var stored_value: float = float(stored_value_by_ball_id.get(ball_id, 0))
	var full_value: float = maxf(stored_value_full_willingness, 1.0)
	return clampf(stored_value / full_value, 0.0, 1.0)


func _update_state_for_ball_id(ball_id: int) -> void:
	state_by_ball_id[ball_id] = _get_state_for_willingness(ball_id, _get_willingness_for_ball_id(ball_id))


func _get_state_for_willingness(ball_id: int, willingness: float) -> String:
	if _is_pocket_test_pending(ball_id):
		return STATE_POCKET_TEST_PENDING
	if _is_panic_retreat_active(ball_id):
		return STATE_PANIC_RETREAT
	if _is_escape_committed(ball_id):
		return STATE_ESCAPE_COMMITTED
	if _is_hide_committed(ball_id):
		return STATE_HIDING
	if willingness >= agitated_willingness_threshold:
		return STATE_AGITATED
	if willingness >= stalking_willingness_threshold:
		return STATE_STALKING_TARGET
	return STATE_HIDING


func _update_pressure_move_target(
	embezzler_ball: Ball,
	seen_entry: Dictionary,
	path_points: Array,
	cover_candidates: Array,
	aim_direction: Vector2,
	aim_origin: Vector2
) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	var new_target: Dictionary = _select_pressure_move_target(
		embezzler_ball,
		seen_entry,
		path_points,
		cover_candidates,
		aim_direction,
		aim_origin
	)
	var current_target: Dictionary = _get_move_target_data(ball_id)
	var chosen_target: Dictionary = _choose_committed_move_target(
		embezzler_ball,
		current_target,
		new_target,
		path_points
	)
	if not chosen_target.is_empty():
		_set_move_target(ball_id, chosen_target)


func _select_pressure_move_target(
	embezzler_ball: Ball,
	seen_entry: Dictionary,
	path_points: Array,
	cover_candidates: Array,
	aim_direction: Vector2,
	aim_origin: Vector2
) -> Dictionary:
	var embezzler_position: Vector2 = embezzler_ball.global_position
	if seen_entry.has("position"):
		embezzler_position = seen_entry["position"]
	var embezzler_path_distance: float = float(seen_entry.get("distance_along_path", _get_path_total_distance(path_points)))
	var pressure_strength: float = _get_pressure_strength_from_seen_entry(seen_entry)
	var best_cover: Dictionary = _find_best_cover_ball(
		embezzler_ball,
		embezzler_position,
		embezzler_path_distance,
		path_points,
		cover_candidates,
		aim_origin
	)
	if not best_cover.is_empty():
		return _make_move_target_data(
			embezzler_ball,
			embezzler_position,
			best_cover["hide_position"],
			path_points,
			"cover",
			pressure_strength,
			true,
			float(best_cover["score"]),
			"pressure_cover"
		)

	var fallback_position: Vector2 = _get_fallback_flee_position(
		embezzler_position,
		path_points,
		aim_direction,
		embezzler_ball.radius
	)
	return _make_move_target_data(
		embezzler_ball,
		embezzler_position,
		fallback_position,
		path_points,
		"flee",
		pressure_strength,
		false,
		embezzler_position.distance_squared_to(fallback_position),
		"pressure_flee"
	)


func _make_move_target_data(
	embezzler_ball: Ball,
	start_position: Vector2,
	base_target_position: Vector2,
	path_points: Array,
	mode: String,
	pressure_strength: float,
	cover_found: bool,
	score: float,
	switch_reason: String
) -> Dictionary:
	var target_position: Vector2 = _push_position_away_from_pockets(
		_clamp_to_playfield(base_target_position, embezzler_ball.radius),
		embezzler_ball.radius
	)
	if not _is_reposition_path_pocket_safe(start_position, target_position, embezzler_ball.radius):
		_note_blocked_target("target_near_pocket")
		return {}
	if _does_reposition_path_cross_aim_corridor(start_position, target_position, path_points):
		_note_blocked_target("target_crosses_aim")
		return {}

	return {
		"target_position": target_position,
		"mode": mode,
		"cover_found": cover_found,
		"pressure_strength": pressure_strength,
		"score": score,
		"commit_remaining": move_target_commit_time,
		"switch_reason": switch_reason,
		"target_pocket_bias": 0.0,
	}


func _find_best_cover_ball(
	embezzler_ball: Ball,
	embezzler_position: Vector2,
	embezzler_path_distance: float,
	path_points: Array,
	cover_candidates: Array,
	aim_origin: Vector2
) -> Dictionary:
	if path_points.size() < 2:
		return {}

	var best_cover: Dictionary = {}
	var best_score: float = INF
	for candidate_value in cover_candidates:
		var candidate: Dictionary = candidate_value as Dictionary
		var candidate_id: int = int(candidate.get("ball_id", -1))
		if candidate_id == embezzler_ball.get_instance_id():
			continue

		var candidate_position: Vector2 = Vector2.ZERO
		if candidate.has("position"):
			candidate_position = candidate["position"]
		if candidate_position.distance_to(embezzler_position) > cover_max_distance_from_embezzler:
			continue

		var distance_along_path: float = float(candidate.get("distance_along_path", -1.0))
		if distance_along_path <= 1.0 or distance_along_path >= embezzler_path_distance - embezzler_ball.radius:
			continue

		var lateral_distance: float = float(candidate.get("lateral_distance", INF))
		if lateral_distance > cover_search_lateral_radius:
			continue

		var cover_data: Dictionary = candidate.duplicate()
		var hide_position: Vector2 = _get_cover_hide_position(embezzler_ball, cover_data)
		if not _is_reposition_path_pocket_safe(embezzler_position, hide_position, embezzler_ball.radius):
			continue
		if _does_reposition_path_cross_aim_corridor(embezzler_position, hide_position, path_points):
			continue

		var score: float = _score_cover_candidate(embezzler_ball, embezzler_position, cover_data, hide_position, aim_origin)
		if score >= best_score:
			continue

		best_score = score
		best_cover = cover_data
		best_cover["score"] = score
		best_cover["hide_position"] = hide_position

	return best_cover


func _get_cover_hide_position(embezzler_ball: Ball, cover_data: Dictionary) -> Vector2:
	var cover_position: Vector2 = Vector2.ZERO
	if cover_data.has("position"):
		cover_position = cover_data["position"]
	var cover_radius: float = float(cover_data.get("radius", embezzler_ball.radius))
	var path_direction: Vector2 = Vector2.RIGHT
	if cover_data.has("segment_direction"):
		path_direction = cover_data["segment_direction"]
	if path_direction.length_squared() <= 0.001:
		path_direction = Vector2.RIGHT

	var hide_distance: float = cover_radius + embezzler_ball.radius + hide_behind_padding
	return _clamp_to_playfield(cover_position + path_direction.normalized() * hide_distance, embezzler_ball.radius)


func _score_cover_candidate(
	embezzler_ball: Ball,
	embezzler_position: Vector2,
	cover_data: Dictionary,
	hide_position: Vector2,
	aim_origin: Vector2
) -> float:
	var lateral_distance: float = float(cover_data.get("lateral_distance", cover_search_lateral_radius))
	var cover_position: Vector2 = Vector2.ZERO
	if cover_data.has("position"):
		cover_position = cover_data["position"]
	var distance_from_embezzler: float = cover_position.distance_to(embezzler_position)
	var away_gain: float = aim_origin.distance_to(hide_position) - aim_origin.distance_to(embezzler_position)
	var pulls_toward_cue_penalty: float = absf(minf(away_gain, 0.0)) * 1.8
	return (
		lateral_distance * 1.45
		+ distance_from_embezzler * 0.26
		+ pulls_toward_cue_penalty
		- maxf(away_gain, 0.0) * 1.35
		+ _get_hide_drift_penalty(embezzler_position, hide_position, embezzler_ball.get_instance_id())
	)


func _get_hide_drift_penalty(start_position: Vector2, target_position: Vector2, ball_id: int) -> float:
	var penalty: float = 0.0
	var target_pocket_position: Vector2 = _get_target_pocket_position_for_ball_id(ball_id)
	if target_pocket_position != Vector2.ZERO:
		var start_to_pocket: float = start_position.distance_to(target_pocket_position)
		var target_to_pocket: float = target_position.distance_to(target_pocket_position)
		var pocket_approach: float = start_to_pocket - target_to_pocket
		penalty += maxf(pocket_approach, 0.0) * 2.4
		penalty -= minf(maxf(-pocket_approach, 0.0), passive_reposition_distance) * 0.45

	if table != null and table.playfield_rect.size != Vector2.ZERO:
		var center_position: Vector2 = table.playfield_rect.get_center()
		var start_to_center: float = start_position.distance_to(center_position)
		var target_to_center: float = target_position.distance_to(center_position)
		var center_approach: float = start_to_center - target_to_center
		penalty += maxf(center_approach, 0.0) * 1.25
		penalty -= minf(maxf(-center_approach, 0.0), passive_reposition_distance) * 0.18

	return penalty


func _get_fallback_flee_position(
	embezzler_position: Vector2,
	path_points: Array,
	aim_direction: Vector2,
	embezzler_radius: float
) -> Vector2:
	var direction: Vector2 = aim_direction
	if direction.length_squared() <= 0.001 and path_points.size() >= 2:
		direction = path_points[path_points.size() - 1] - path_points[0]
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT

	var perpendicular: Vector2 = direction.normalized().orthogonal()
	var options: Array[Vector2] = [
		_clamp_to_playfield(embezzler_position + perpendicular * fallback_flee_distance, embezzler_radius),
		_clamp_to_playfield(embezzler_position - perpendicular * fallback_flee_distance, embezzler_radius),
		_clamp_to_playfield(embezzler_position - direction.normalized() * fallback_flee_distance, embezzler_radius),
	]
	return _get_best_safe_option(embezzler_position, options, embezzler_radius, path_points)


func _ensure_passive_target(embezzler_ball: Ball) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	if _is_pocket_test_pending(ball_id):
		move_targets_by_ball_id.erase(ball_id)
		return
	if _is_escape_committed(ball_id):
		_ensure_escape_committed_target(embezzler_ball)
		return
	if _is_panic_retreat_active(ball_id):
		var panic_target: Dictionary = _get_move_target_data(ball_id)
		if panic_target.is_empty():
			_set_panic_retreat_target(embezzler_ball, "panic_retreat")
		return

	var current_target: Dictionary = _get_move_target_data(ball_id)
	if current_target.is_empty():
		return

	if _get_move_target_invalid_reason(embezzler_ball, current_target, []) != "none":
		move_targets_by_ball_id.erase(ball_id)


func _choose_committed_move_target(
	embezzler_ball: Ball,
	current_target: Dictionary,
	new_target: Dictionary,
	path_points: Array
) -> Dictionary:
	var current_reason: String = _get_move_target_invalid_reason(embezzler_ball, current_target, path_points)
	if current_reason == "none" and not _new_target_is_worth_switching(current_target, new_target):
		current_target["switch_reason"] = "kept_committed"
		last_target_switch_reason = "kept_committed"
		return current_target

	if new_target.is_empty():
		last_target_switch_reason = current_reason
		return {}

	if current_reason == "none":
		new_target["switch_reason"] = "switched_better"
	else:
		new_target["switch_reason"] = current_reason
	return new_target


func _get_move_target_invalid_reason(embezzler_ball: Ball, current_target: Dictionary, path_points: Array) -> String:
	if current_target.is_empty():
		return "new_target"

	var target_position: Vector2 = current_target["target_position"]
	var mode: String = str(current_target.get("mode", "unknown"))
	if mode == STATE_ESCAPE_COMMITTED:
		if _is_pocket_test_pending(embezzler_ball.get_instance_id()):
			return "pocket_test_pending"
		if target_position == Vector2.ZERO:
			return "escape_target_missing"
		return "none"
	if embezzler_ball.global_position.distance_to(target_position) <= hide_arrival_radius:
		return "reached_target"
	if not _is_reposition_path_pocket_safe(embezzler_ball.global_position, target_position, embezzler_ball.radius):
		return "target_near_pocket"
	if _does_reposition_path_cross_aim_corridor(embezzler_ball.global_position, target_position, path_points):
		return "target_crosses_aim"
	return "none"


func _new_target_is_worth_switching(current_target: Dictionary, new_target: Dictionary) -> bool:
	if new_target.is_empty():
		return false
	var current_commit_remaining: float = float(current_target.get("commit_remaining", 0.0))
	if current_commit_remaining > 0.0:
		var current_score: float = float(current_target.get("score", INF))
		var new_score: float = float(new_target.get("score", INF))
		return new_score <= current_score - target_switch_improvement_threshold

	return true


func _set_move_target(ball_id: int, target_data: Dictionary) -> void:
	var previous_target: Dictionary = _get_move_target_data(ball_id)
	var target_changed: bool = previous_target.is_empty()
	if not target_changed:
		var previous_mode: String = str(previous_target.get("mode", "unknown"))
		var next_mode: String = str(target_data.get("mode", "unknown"))
		if previous_mode == STATE_ESCAPE_COMMITTED and next_mode == STATE_ESCAPE_COMMITTED:
			target_changed = false
		else:
			var previous_position: Vector2 = previous_target["target_position"]
			var next_position: Vector2 = target_data["target_position"]
			target_changed = previous_position.distance_to(next_position) > 3.0
	if target_changed:
		target_switches_total += 1

	last_target_switch_reason = str(target_data.get("switch_reason", "updated"))
	move_targets_by_ball_id[ball_id] = target_data


func _decay_move_target_commit(ball_id: int, delta: float) -> void:
	if not move_targets_by_ball_id.has(ball_id):
		return

	var target_data: Dictionary = move_targets_by_ball_id[ball_id] as Dictionary
	var commit_remaining: float = maxf(float(target_data.get("commit_remaining", 0.0)) - delta, 0.0)
	target_data["commit_remaining"] = commit_remaining
	move_targets_by_ball_id[ball_id] = target_data


func _get_move_target_data(ball_id: int) -> Dictionary:
	if not move_targets_by_ball_id.has(ball_id):
		return {}
	return move_targets_by_ball_id[ball_id] as Dictionary


func _apply_reposition_steer(embezzler_ball: Ball, target_data: Dictionary, delta: float) -> bool:
	var target_position: Vector2 = target_data["target_position"]
	var to_target: Vector2 = target_position - embezzler_ball.global_position
	var distance_to_target: float = to_target.length()
	if distance_to_target <= hide_arrival_radius:
		return false

	var target_direction: Vector2 = to_target / distance_to_target
	var distance_factor: float = 1.0
	if hide_slow_radius > hide_arrival_radius:
		distance_factor = clampf(
			(distance_to_target - hide_arrival_radius) / (hide_slow_radius - hide_arrival_radius),
			0.25,
			1.0
		)

	var pressure_strength: float = clampf(float(target_data.get("pressure_strength", 0.25)), 0.15, 1.0)
	var state_multiplier: float = _get_state_speed_multiplier(embezzler_ball.get_instance_id())
	var acceleration: float = scuttle_steering_acceleration * lerp(0.75, 1.12, pressure_strength) * state_multiplier
	var speed_cap: float = max_scuttle_speed * state_multiplier
	var current_speed_toward_target: float = embezzler_ball.velocity.dot(target_direction)
	var available_steering_speed: float = maxf(speed_cap * distance_factor - current_speed_toward_target, 0.0)
	if available_steering_speed <= 0.0:
		return false

	var steering_speed: float = minf(acceleration * delta, available_steering_speed)
	if steering_speed <= 0.0:
		return false

	var steering_delta: Vector2 = target_direction * steering_speed
	embezzler_ball.velocity += steering_delta
	_add_scuttle_velocity(embezzler_ball, steering_delta)
	_mark_self_steering_collision_soft(embezzler_ball)
	scuttle_applications_this_frame += 1
	return true


func _get_state_speed_multiplier(ball_id: int) -> float:
	var state: String = str(state_by_ball_id.get(ball_id, STATE_HIDING))
	var willingness_strength: float = _get_willingness_for_ball_id(ball_id) / MAX_WILLINGNESS
	var stored_strength: float = _get_stored_value_visual_strength(ball_id)
	var urgency: float = clampf(maxf(willingness_strength, stored_strength * 0.8), 0.0, 1.0)
	if state == STATE_ESCAPE_COMMITTED:
		return committed_escape_speed_multiplier * lerp(0.9, 1.12, urgency)
	if state == STATE_POCKET_TEST_PENDING:
		return 0.0
	if state == STATE_AGITATED:
		return lerp(1.0, agitated_speed_multiplier, urgency)
	if state == STATE_STALKING_TARGET:
		return lerp(0.82, 1.06, urgency)
	return lerp(0.58, 0.98, urgency)


func _is_scuttle_target_active(embezzler_ball: Ball, target_data: Dictionary) -> bool:
	if embezzler_ball == null or target_data.is_empty():
		return false

	var target_position: Vector2 = target_data["target_position"]
	return embezzler_ball.global_position.distance_to(target_position) > hide_arrival_radius


func _get_pressure_strength_from_seen_entry(seen_entry: Dictionary) -> float:
	var lateral_distance: float = float(seen_entry.get("lateral_distance", near_aim_lateral_distance))
	var pressure_span: float = maxf(near_aim_lateral_distance - direct_aim_lateral_distance, 1.0)
	var raw_pressure: float = 1.0 - clampf((lateral_distance - direct_aim_lateral_distance) / pressure_span, 0.0, 1.0)
	return clampf(maxf(0.18, raw_pressure), 0.0, 1.0)


func _resolve_turn_escape_decision(embezzler_ball: Ball) -> void:
	if not _is_active_embezzler_ball(embezzler_ball):
		return

	var ball_id: int = embezzler_ball.get_instance_id()
	if _is_pocket_test_pending(ball_id) or _is_panic_retreat_active(ball_id):
		return
	if int(last_shot_decision_serial_by_ball_id.get(ball_id, -1)) == shot_decision_serial:
		return

	last_shot_decision_serial_by_ball_id[ball_id] = shot_decision_serial
	escape_committed_by_ball_id.erase(ball_id)
	pocket_test_pending_by_ball_id.erase(ball_id)

	var roll_chance: float = _get_escape_roll_chance(ball_id, "shot_started")
	last_escape_roll_msec_by_ball_id[ball_id] = Time.get_ticks_msec()
	last_escape_roll_chance = roll_chance
	last_escape_roll_reason = "shot_started"

	if roll_chance <= 0.0:
		_commit_turn_hide(embezzler_ball, "shot_low_willingness")
		return

	escape_roll_attempts += 1
	if randf() <= roll_chance:
		escape_roll_successes += 1
		_commit_escape(embezzler_ball, "shot_started")
		return

	escape_roll_failures += 1
	_commit_turn_hide(embezzler_ball, "shot_roll_failed")


func _get_escape_roll_chance(ball_id: int, _reason: String) -> float:
	var willingness: float = _get_willingness_for_ball_id(ball_id)
	if willingness < escape_roll_min_willingness:
		return 0.0

	var chance_span: float = maxf(MAX_WILLINGNESS - escape_roll_min_willingness, 1.0)
	var chance_ratio: float = clampf((willingness - escape_roll_min_willingness) / chance_span, 0.0, 1.0)
	var roll_chance: float = escape_roll_min_chance + (escape_roll_max_chance - escape_roll_min_chance) * chance_ratio
	return clampf(roll_chance, 0.0, 0.95)


func _commit_turn_hide(embezzler_ball: Ball, reason: String) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	hide_committed_by_ball_id[ball_id] = true
	escape_committed_by_ball_id.erase(ball_id)
	pocket_test_pending_by_ball_id.erase(ball_id)
	state_by_ball_id[ball_id] = STATE_HIDING

	var current_target: Dictionary = _get_move_target_data(ball_id)
	if _is_current_hide_target_usable(embezzler_ball, current_target):
		last_target_switch_reason = "kept_turn_hide"
		_update_embezzler_visual(embezzler_ball)
		return

	var hide_target: Dictionary = _select_turn_hide_target(embezzler_ball, reason)
	if hide_target.is_empty():
		move_targets_by_ball_id.erase(ball_id)
		_note_blocked_target("turn_hide_blocked")
	else:
		_set_move_target(ball_id, hide_target)
	_update_embezzler_visual(embezzler_ball)


func _is_current_hide_target_usable(embezzler_ball: Ball, current_target: Dictionary) -> bool:
	if current_target.is_empty():
		return false
	if float(current_target.get("target_pocket_bias", 0.0)) > 0.001:
		return false

	var mode: String = str(current_target.get("mode", "unknown"))
	if mode == STATE_ESCAPE_COMMITTED or mode == STATE_PANIC_RETREAT or mode == STATE_POCKET_TEST_PENDING:
		return false
	return _get_move_target_invalid_reason(embezzler_ball, current_target, []) == "none"


func _select_turn_hide_target(embezzler_ball: Ball, reason: String) -> Dictionary:
	var cover_target: Dictionary = _select_turn_cover_hide_target(embezzler_ball, reason)
	if not cover_target.is_empty():
		return cover_target

	var fallback_position: Vector2 = _get_turn_hide_fallback_position(embezzler_ball)
	if fallback_position == embezzler_ball.global_position:
		return {}
	return _make_turn_hide_target_data(embezzler_ball, fallback_position, false, reason)


func _select_turn_cover_hide_target(embezzler_ball: Ball, reason: String) -> Dictionary:
	if table == null or table.balls == null:
		return {}

	var start_position: Vector2 = embezzler_ball.global_position
	var best_position: Vector2 = start_position
	var best_score: float = INF
	for child in table.balls.get_children():
		var cover_ball: Ball = child as Ball
		if cover_ball == null or cover_ball == embezzler_ball:
			continue
		if not cover_ball.is_gameplay_active():
			continue

		var distance_from_embezzler: float = cover_ball.global_position.distance_to(start_position)
		if distance_from_embezzler > cover_max_distance_from_embezzler:
			continue

		var option: Vector2 = _get_turn_cover_hide_position(embezzler_ball, cover_ball)
		if not _is_reposition_path_pocket_safe(start_position, option, embezzler_ball.radius):
			continue

		var score: float = (
			distance_from_embezzler * 0.35
			+ _get_hide_drift_penalty(start_position, option, embezzler_ball.get_instance_id())
		)
		if score < best_score:
			best_score = score
			best_position = option

	if best_position == start_position:
		return {}
	return _make_turn_hide_target_data(embezzler_ball, best_position, true, reason)


func _get_turn_cover_hide_position(embezzler_ball: Ball, cover_ball: Ball) -> Vector2:
	var ball_id: int = embezzler_ball.get_instance_id()
	var target_pocket_position: Vector2 = _get_target_pocket_position_for_ball_id(ball_id)
	var cover_position: Vector2 = cover_ball.global_position
	var away_direction: Vector2 = cover_position - target_pocket_position
	if away_direction.length_squared() <= 0.001 and table != null:
		away_direction = cover_position - table.playfield_rect.get_center()
	if away_direction.length_squared() <= 0.001:
		away_direction = cover_position - embezzler_ball.global_position
	if away_direction.length_squared() <= 0.001:
		away_direction = Vector2.RIGHT

	var hide_distance: float = cover_ball.radius + embezzler_ball.radius + hide_behind_padding
	var base_direction: Vector2 = away_direction.normalized()
	var options: Array[Vector2] = [
		cover_position + base_direction * hide_distance,
		cover_position + base_direction.rotated(0.48) * hide_distance,
		cover_position + base_direction.rotated(-0.48) * hide_distance,
		cover_position + base_direction.rotated(0.9) * hide_distance,
		cover_position + base_direction.rotated(-0.9) * hide_distance,
	]
	return _get_best_turn_hide_option(embezzler_ball.global_position, options, embezzler_ball.radius, ball_id)


func _get_turn_hide_fallback_position(embezzler_ball: Ball) -> Vector2:
	var ball_id: int = embezzler_ball.get_instance_id()
	var start_position: Vector2 = embezzler_ball.global_position
	var target_pocket_position: Vector2 = _get_target_pocket_position_for_ball_id(ball_id)
	var away_direction: Vector2 = start_position - target_pocket_position
	if table != null and table.playfield_rect.size != Vector2.ZERO:
		away_direction += (start_position - table.playfield_rect.get_center()) * 0.65
	if away_direction.length_squared() <= 0.001:
		away_direction = Vector2.RIGHT.rotated(float(ball_id % 360) * 0.0174533)

	var hide_distance: float = maxf(fallback_flee_distance, passive_reposition_distance)
	var base_direction: Vector2 = away_direction.normalized()
	var options: Array[Vector2] = [
		start_position + base_direction * hide_distance,
		start_position + base_direction.rotated(0.54) * hide_distance,
		start_position + base_direction.rotated(-0.54) * hide_distance,
		start_position + base_direction.orthogonal() * hide_distance * 0.72,
		start_position - base_direction.orthogonal() * hide_distance * 0.72,
	]
	return _get_best_turn_hide_option(start_position, options, embezzler_ball.radius, ball_id)


func _get_best_turn_hide_option(start_position: Vector2, options: Array[Vector2], ball_radius: float, ball_id: int) -> Vector2:
	var best_position: Vector2 = start_position
	var best_score: float = INF
	for option_value in options:
		var option: Vector2 = _push_position_away_from_pockets(_clamp_to_playfield(option_value, ball_radius), ball_radius)
		if not _is_reposition_path_pocket_safe(start_position, option, ball_radius):
			continue

		var score: float = _get_hide_drift_penalty(start_position, option, ball_id)
		score += start_position.distance_to(option) * 0.08
		if score < best_score:
			best_score = score
			best_position = option

	return best_position


func _make_turn_hide_target_data(embezzler_ball: Ball, target_position: Vector2, cover_found: bool, reason: String) -> Dictionary:
	var ball_id: int = embezzler_ball.get_instance_id()
	return {
		"target_position": target_position,
		"mode": STATE_HIDING,
		"cover_found": cover_found,
		"pressure_strength": _get_turn_hide_pressure_strength(ball_id),
		"score": _get_hide_drift_penalty(embezzler_ball.global_position, target_position, ball_id),
		"commit_remaining": move_target_commit_time,
		"switch_reason": reason,
		"target_pocket_bias": 0.0,
	}


func _get_turn_hide_pressure_strength(ball_id: int) -> float:
	var willingness_strength: float = _get_willingness_for_ball_id(ball_id) / MAX_WILLINGNESS
	var stored_strength: float = _get_stored_value_visual_strength(ball_id)
	return clampf(0.22 + maxf(willingness_strength, stored_strength * 0.8) * 0.58, 0.18, 0.86)


func _commit_escape(embezzler_ball: Ball, reason: String) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	hide_committed_by_ball_id.erase(ball_id)
	escape_committed_by_ball_id[ball_id] = true
	pocket_test_pending_by_ball_id.erase(ball_id)
	panic_retreat_until_by_ball_id.erase(ball_id)
	state_by_ball_id[ball_id] = STATE_ESCAPE_COMMITTED
	last_target_switch_reason = "escape_%s" % reason
	_ensure_escape_committed_target(embezzler_ball)
	_update_embezzler_visual(embezzler_ball)


func _update_escape_commitment_state(embezzler_ball: Ball, delta: float) -> bool:
	var ball_id: int = embezzler_ball.get_instance_id()
	if _is_pocket_test_pending(ball_id):
		_apply_pocket_test_pending_brake(embezzler_ball, delta)
		return true
	if not _is_escape_committed(ball_id):
		return true

	if _is_at_pocket_test_distance(embezzler_ball):
		_try_pocket_escape_roll(embezzler_ball)
		return _is_active_embezzler_ball(embezzler_ball)

	_ensure_escape_committed_target(embezzler_ball)
	return true


func _ensure_escape_committed_target(embezzler_ball: Ball) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	if not _is_escape_committed(ball_id):
		return

	var target_position: Vector2 = _get_committed_pocket_staging_position(embezzler_ball)
	if target_position == Vector2.ZERO:
		_enter_panic_retreat(ball_id, "escape_target_missing", embezzler_ball)
		return

	var target_data: Dictionary = {
		"target_position": target_position,
		"mode": STATE_ESCAPE_COMMITTED,
		"cover_found": false,
		"pressure_strength": 1.0,
		"score": embezzler_ball.global_position.distance_to(target_position),
		"commit_remaining": move_target_commit_time,
		"switch_reason": "escape_committed",
		"target_pocket_bias": 1.0,
	}
	_set_move_target(ball_id, target_data)


func _get_committed_pocket_staging_position(embezzler_ball: Ball) -> Vector2:
	var ball_id: int = embezzler_ball.get_instance_id()
	var target_pocket_position: Vector2 = _get_target_pocket_position_for_ball_id(ball_id)
	if target_pocket_position == Vector2.ZERO:
		return Vector2.ZERO

	var from_pocket: Vector2 = embezzler_ball.global_position - target_pocket_position
	if from_pocket.length_squared() <= 0.001 and table != null:
		from_pocket = table.playfield_rect.get_center() - target_pocket_position
	if from_pocket.length_squared() <= 0.001:
		from_pocket = Vector2.RIGHT

	var stop_distance: float = _get_committed_pocket_stop_distance(ball_id, embezzler_ball.radius)
	return _clamp_to_playfield(target_pocket_position + from_pocket.normalized() * stop_distance, embezzler_ball.radius)


func _get_committed_pocket_stop_distance(ball_id: int, ball_radius: float) -> float:
	return _get_target_pocket_radius_for_ball_id(ball_id) + ball_radius + committed_pocket_stop_buffer


func _is_at_pocket_test_distance(embezzler_ball: Ball) -> bool:
	var ball_id: int = embezzler_ball.get_instance_id()
	var target_pocket_position: Vector2 = _get_target_pocket_position_for_ball_id(ball_id)
	if target_pocket_position == Vector2.ZERO:
		return false

	var stop_distance: float = _get_committed_pocket_stop_distance(ball_id, embezzler_ball.radius)
	return embezzler_ball.global_position.distance_to(target_pocket_position) <= stop_distance + pocket_test_pending_distance


func _try_pocket_escape_roll(embezzler_ball: Ball) -> bool:
	if not _is_active_embezzler_ball(embezzler_ball):
		return false

	var ball_id: int = embezzler_ball.get_instance_id()
	if not _is_escape_committed(ball_id):
		return false
	if not _is_pocket_roll_cooldown_ready(ball_id):
		return false

	var roll_chance: float = _get_pocket_roll_chance(ball_id)
	last_pocket_roll_msec_by_ball_id[ball_id] = Time.get_ticks_msec()
	last_pocket_roll_chance = roll_chance
	pocket_roll_attempts += 1
	if randf() <= roll_chance:
		pocket_roll_successes += 1
		last_pocket_roll_result = "escaped"
		_resolve_escape_success(embezzler_ball)
		return true

	pocket_roll_failures += 1
	last_pocket_roll_result = "panic_retreat"
	_resolve_escape_failure(embezzler_ball)
	return false


func _get_pocket_roll_chance(ball_id: int) -> float:
	var willingness: float = _get_willingness_for_ball_id(ball_id)
	var chance_span: float = maxf(MAX_WILLINGNESS - pocket_roll_min_willingness, 1.0)
	var chance_ratio: float = clampf((willingness - pocket_roll_min_willingness) / chance_span, 0.0, 1.0)
	var roll_chance: float = pocket_roll_min_chance + (pocket_roll_max_chance - pocket_roll_min_chance) * chance_ratio
	return clampf(roll_chance, 0.0, 0.95)


func _is_pocket_roll_cooldown_ready(ball_id: int) -> bool:
	var last_roll_msec: int = int(last_pocket_roll_msec_by_ball_id.get(ball_id, -1000000))
	var elapsed_msec: int = Time.get_ticks_msec() - last_roll_msec
	return elapsed_msec >= int(maxf(pocket_roll_cooldown_time, 0.0) * 1000.0)


func _resolve_escape_success(embezzler_ball: Ball) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	var escaped_value: int = int(stored_value_by_ball_id.get(ball_id, 0))
	resolved_capture_ball_ids[ball_id] = true
	last_escaped_stored_value = escaped_value
	escaped_stored_value_total += escaped_value
	escaped_count += 1
	last_target_switch_reason = "escaped"

	_clear_embezzler_state_for_id(ball_id)
	embezzler_balls.erase(embezzler_ball)
	embezzler_ball.velocity = Vector2.ZERO
	embezzler_ball.gameplay_enabled = false
	embezzler_ball.is_embezzler_ball = false
	embezzler_ball.visible = false
	embezzler_ball.queue_free()

	if table != null:
		table.queue_spawn_reward_message(false, false, false, false, _get_escape_callout_text(escaped_value))


func _resolve_escape_failure(embezzler_ball: Ball) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	var current_pressure: float = float(aim_pressure_by_ball_id.get(ball_id, 0.0))
	aim_pressure_by_ball_id[ball_id] = maxf(current_pressure - failed_pocket_roll_pressure_drop, 0.0)
	panic_retreats += 1
	_enter_panic_retreat(ball_id, "pocket_roll_failed", embezzler_ball)


func _enter_pocket_test_pending(embezzler_ball: Ball) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	if _is_pocket_test_pending(ball_id):
		return

	hide_committed_by_ball_id.erase(ball_id)
	escape_committed_by_ball_id.erase(ball_id)
	pocket_test_pending_by_ball_id[ball_id] = true
	move_targets_by_ball_id.erase(ball_id)
	state_by_ball_id[ball_id] = STATE_POCKET_TEST_PENDING
	last_target_switch_reason = "pocket_test_pending"
	pocket_test_pending_total += 1
	_update_embezzler_visual(embezzler_ball)


func _apply_pocket_test_pending_brake(embezzler_ball: Ball, delta: float) -> void:
	embezzler_ball.velocity = embezzler_ball.velocity.move_toward(Vector2.ZERO, self_scuttle_braking * delta)
	self_scuttle_velocity_by_ball_id.erase(embezzler_ball.get_instance_id())


func _enter_panic_retreat(ball_id: int, reason: String, embezzler_ball: Ball = null) -> void:
	hide_committed_by_ball_id.erase(ball_id)
	escape_committed_by_ball_id.erase(ball_id)
	pocket_test_pending_by_ball_id.erase(ball_id)
	move_targets_by_ball_id.erase(ball_id)
	panic_retreat_until_by_ball_id[ball_id] = Time.get_ticks_msec() + int(maxf(panic_retreat_duration, 0.0) * 1000.0)
	state_by_ball_id[ball_id] = STATE_PANIC_RETREAT
	last_target_switch_reason = reason
	if _is_active_embezzler_ball(embezzler_ball):
		_set_panic_retreat_target(embezzler_ball, reason)


func _set_panic_retreat_target(embezzler_ball: Ball, reason: String) -> void:
	var ball_id: int = embezzler_ball.get_instance_id()
	var target_position: Vector2 = _get_panic_retreat_position(embezzler_ball)
	if target_position == embezzler_ball.global_position:
		_note_blocked_target("panic_retreat_blocked")
		return

	_set_move_target(ball_id, {
		"target_position": target_position,
		"mode": STATE_PANIC_RETREAT,
		"cover_found": false,
		"pressure_strength": 0.82,
		"score": embezzler_ball.global_position.distance_to(target_position),
		"commit_remaining": move_target_commit_time,
		"switch_reason": reason,
		"target_pocket_bias": 0.0,
	})


func _get_panic_retreat_position(embezzler_ball: Ball) -> Vector2:
	var ball_id: int = embezzler_ball.get_instance_id()
	var target_pocket_position: Vector2 = _get_target_pocket_position_for_ball_id(ball_id)
	var start_position: Vector2 = embezzler_ball.global_position
	var away_direction: Vector2 = start_position - target_pocket_position
	if away_direction.length_squared() <= 0.001 and table != null:
		away_direction = start_position - table.playfield_rect.get_center()
	if away_direction.length_squared() <= 0.001:
		away_direction = Vector2.RIGHT
	away_direction = away_direction.normalized()

	var retreat_distance: float = maxf(panic_retreat_distance, embezzler_ball.radius * 2.0)
	var options: Array[Vector2] = [
		start_position + away_direction * retreat_distance,
		start_position + away_direction.rotated(0.42) * retreat_distance,
		start_position + away_direction.rotated(-0.42) * retreat_distance,
		start_position + away_direction.orthogonal() * retreat_distance * 0.72,
		start_position - away_direction.orthogonal() * retreat_distance * 0.72,
	]
	var best_position: Vector2 = start_position
	var best_score: float = -1.0e20
	for option_value in options:
		var option: Vector2 = _push_position_away_from_pockets(_clamp_to_playfield(option_value, embezzler_ball.radius), embezzler_ball.radius)
		if not _is_reposition_path_pocket_safe(start_position, option, embezzler_ball.radius):
			continue

		var distance_from_pocket: float = option.distance_squared_to(target_pocket_position)
		var distance_from_start: float = start_position.distance_squared_to(option)
		var score: float = distance_from_pocket + distance_from_start * 0.2
		if score > best_score:
			best_score = score
			best_position = option

	return best_position


func _is_escape_routing_active(ball_id: int) -> bool:
	return _is_escape_committed(ball_id) or _is_pocket_test_pending(ball_id) or _is_panic_retreat_active(ball_id)


func _is_escape_committed(ball_id: int) -> bool:
	return bool(escape_committed_by_ball_id.get(ball_id, false))


func _is_hide_committed(ball_id: int) -> bool:
	return bool(hide_committed_by_ball_id.get(ball_id, false))


func _is_pocket_test_pending(ball_id: int) -> bool:
	return bool(pocket_test_pending_by_ball_id.get(ball_id, false))


func _is_panic_retreat_active(ball_id: int) -> bool:
	var panic_until_msec: int = int(panic_retreat_until_by_ball_id.get(ball_id, 0))
	if Time.get_ticks_msec() > panic_until_msec:
		panic_retreat_until_by_ball_id.erase(ball_id)
		return false
	return true


func _get_pocket_test_pending_count() -> int:
	var pending_count: int = 0
	for ball_id_value in pocket_test_pending_by_ball_id:
		var ball_id: int = int(ball_id_value)
		if _is_pocket_test_pending(ball_id) and _get_active_embezzler_ball_by_id(ball_id) != null:
			pending_count += 1
	return pending_count


func _get_capture_callout_text(recovered_value: int) -> String:
	if recovered_value > 0:
		return "Loot Recovered! +%s" % recovered_value
	return "Embezzler Caught!"


func _get_escape_callout_text(escaped_value: int) -> String:
	if escaped_value > 0:
		return "The Embezzler Escaped! %s Loot" % escaped_value
	return "The Embezzler Escaped!"


func _get_capture_pocket_index(sink_context: Dictionary) -> int:
	if table == null or table.pocket_system == null:
		return NO_TARGET_POCKET_INDEX

	var pocket_position: Vector2 = sink_context.get("pocket_position", Vector2.ZERO)
	if pocket_position == Vector2.ZERO:
		return NO_TARGET_POCKET_INDEX

	var pocket_positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
	var best_index: int = NO_TARGET_POCKET_INDEX
	var best_distance_sq: float = INF
	for pocket_index in range(pocket_positions.size()):
		var distance_sq: float = pocket_position.distance_squared_to(pocket_positions[pocket_index])
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_index = pocket_index
	return best_index


func _choose_secret_target_pocket_index() -> int:
	if table == null or table.pocket_system == null:
		return NO_TARGET_POCKET_INDEX

	var pocket_positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
	if pocket_positions.is_empty():
		return NO_TARGET_POCKET_INDEX

	return randi() % pocket_positions.size()


func _get_pocket_debug_name(pocket_index: int) -> String:
	if pocket_index < 0 or table == null or table.pocket_system == null:
		return "none"

	var pocket_positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
	if pocket_index >= pocket_positions.size():
		return "none"

	var pocket_position: Vector2 = pocket_positions[pocket_index]
	var playfield_center: Vector2 = table.playfield_rect.get_center()
	var center_tolerance: float = maxf(table.playfield_rect.size.x * 0.18, 80.0)
	var vertical_name: String = "Top" if pocket_position.y < playfield_center.y else "Bottom"
	var horizontal_name: String = "Middle"
	if pocket_position.x < playfield_center.x - center_tolerance:
		horizontal_name = "Left"
	elif pocket_position.x > playfield_center.x + center_tolerance:
		horizontal_name = "Right"
	return "%s %s" % [vertical_name, horizontal_name]


func _get_target_pocket_position() -> Vector2:
	var primary_ball: Ball = _get_primary_embezzler_ball()
	if primary_ball == null or table == null or table.pocket_system == null:
		return Vector2.ZERO

	return _get_target_pocket_position_for_ball_id(primary_ball.get_instance_id())


func _get_target_pocket_position_for_ball_id(ball_id: int) -> Vector2:
	if table == null or table.pocket_system == null:
		return Vector2.ZERO

	var target_index: int = int(target_pocket_index_by_ball_id.get(ball_id, NO_TARGET_POCKET_INDEX))
	var pocket_positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
	if target_index < 0 or target_index >= pocket_positions.size():
		return Vector2.ZERO
	return pocket_positions[target_index]


func _get_target_pocket_radius_for_ball_id(ball_id: int) -> float:
	if table == null or table.pocket_system == null:
		return 0.0

	var target_index: int = int(target_pocket_index_by_ball_id.get(ball_id, NO_TARGET_POCKET_INDEX))
	var pocket_radii: Array[float] = table.pocket_system.get_pocket_radii()
	if target_index < 0 or target_index >= pocket_radii.size():
		return 0.0
	return pocket_radii[target_index]


func _get_best_safe_option(start_position: Vector2, options: Array[Vector2], ball_radius: float, path_points: Array) -> Vector2:
	var best_position: Vector2 = start_position
	var best_score: float = -1.0e20
	for option_value in options:
		var option: Vector2 = _push_position_away_from_pockets(_clamp_to_playfield(option_value, ball_radius), ball_radius)
		if not _is_reposition_path_pocket_safe(start_position, option, ball_radius):
			continue
		if _does_reposition_path_cross_aim_corridor(start_position, option, path_points):
			continue
		var score: float = start_position.distance_squared_to(option)
		if score > best_score:
			best_score = score
			best_position = option

	return best_position


func _project_point_onto_path(point: Vector2, path_points: Array) -> Dictionary:
	var best_projection: Dictionary = {}
	var best_distance: float = INF
	var distance_before_segment: float = 0.0
	for point_index in range(path_points.size() - 1):
		var segment_start: Vector2 = path_points[point_index]
		var segment_end: Vector2 = path_points[point_index + 1]
		var segment: Vector2 = segment_end - segment_start
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			continue

		var segment_fraction: float = clampf((point - segment_start).dot(segment) / segment.length_squared(), 0.0, 1.0)
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
	var total_distance: float = 0.0
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
		clampf(position.x, safe_rect.position.x, safe_end.x),
		clampf(position.y, safe_rect.position.y, safe_end.y)
	)


func _is_reposition_path_pocket_safe(start_position: Vector2, end_position: Vector2, ball_radius: float) -> bool:
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

		var segment_fraction: float = clampf((pocket_position - start_position).dot(segment) / segment_length_sq, 0.0, 1.0)
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


func _does_reposition_path_cross_aim_corridor(start_position: Vector2, end_position: Vector2, path_points: Array) -> bool:
	if path_points.size() < 2:
		return false

	var start_side: float = _get_point_side_of_aim_path(start_position, path_points)
	var end_side: float = _get_point_side_of_aim_path(end_position, path_points)
	var side_deadzone: float = maxf(aim_corridor_crossing_side_deadzone, 1.0)
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


func _note_blocked_target(reason: String) -> void:
	blocked_target_attempts_total += 1
	last_blocked_target_reason = reason


func _mark_self_steering_collision_soft(embezzler_ball: Ball) -> void:
	if embezzler_ball == null or self_steer_collision_soft_time <= 0.0:
		return

	var expires_at_msec: int = Time.get_ticks_msec() + int(self_steer_collision_soft_time * 1000.0)
	self_steering_until_by_ball_id[embezzler_ball.get_instance_id()] = expires_at_msec


func _add_scuttle_velocity(embezzler_ball: Ball, steering_delta: Vector2) -> void:
	if embezzler_ball == null or steering_delta.length_squared() <= 0.001:
		return

	var ball_id: int = embezzler_ball.get_instance_id()
	var scuttle_velocity: Vector2 = _get_stored_scuttle_velocity(ball_id) + steering_delta
	self_scuttle_velocity_by_ball_id[ball_id] = _get_scuttle_velocity_aligned_to_ball(embezzler_ball, scuttle_velocity)


func _update_scuttle_velocity(delta: float, active_scuttle_ids: Dictionary) -> void:
	if self_scuttle_velocity_by_ball_id.is_empty():
		return

	var kept_scuttle_velocity: Dictionary = {}
	for ball_id in self_scuttle_velocity_by_ball_id:
		var embezzler_ball: Ball = _get_active_embezzler_ball_by_id(int(ball_id))
		if embezzler_ball == null:
			continue

		var stored_scuttle_velocity: Vector2 = self_scuttle_velocity_by_ball_id[ball_id]
		var scuttle_velocity: Vector2 = _get_scuttle_velocity_aligned_to_ball(embezzler_ball, stored_scuttle_velocity)
		if scuttle_velocity.length() <= self_scuttle_min_speed:
			continue

		if not active_scuttle_ids.has(int(ball_id)):
			var previous_scuttle_velocity: Vector2 = scuttle_velocity
			scuttle_velocity = scuttle_velocity.move_toward(Vector2.ZERO, self_scuttle_braking * delta)
			embezzler_ball.velocity -= previous_scuttle_velocity - scuttle_velocity

		scuttle_velocity = _get_scuttle_velocity_aligned_to_ball(embezzler_ball, scuttle_velocity)
		if scuttle_velocity.length() > self_scuttle_min_speed:
			kept_scuttle_velocity[ball_id] = scuttle_velocity

	self_scuttle_velocity_by_ball_id = kept_scuttle_velocity


func _get_stored_scuttle_velocity(ball_id: int) -> Vector2:
	if not self_scuttle_velocity_by_ball_id.has(ball_id):
		return Vector2.ZERO
	var stored_scuttle_velocity: Vector2 = self_scuttle_velocity_by_ball_id[ball_id]
	return stored_scuttle_velocity


func _get_scuttle_velocity_aligned_to_ball(embezzler_ball: Ball, scuttle_velocity: Vector2) -> Vector2:
	if embezzler_ball == null or scuttle_velocity.length_squared() <= 0.001:
		return Vector2.ZERO
	if embezzler_ball.velocity.length_squared() <= 0.001:
		return Vector2.ZERO

	var scuttle_direction: Vector2 = scuttle_velocity.normalized()
	var ball_speed_along_scuttle: float = embezzler_ball.velocity.dot(scuttle_direction)
	if ball_speed_along_scuttle <= 0.0:
		return Vector2.ZERO
	return scuttle_direction * minf(scuttle_velocity.length(), ball_speed_along_scuttle)


func _get_soft_scuttle_impulse(impulse: Vector2) -> Vector2:
	var soft_impulse: Vector2 = impulse * self_steer_collision_transfer_multiplier
	if self_steer_collision_impulse_cap > 0.0:
		soft_impulse = soft_impulse.limit_length(self_steer_collision_impulse_cap)
	return soft_impulse


func _is_self_steering_embezzler_driving(embezzler_ball: Ball, other_ball: Ball, embezzler_to_other_normal: Vector2) -> bool:
	if not _is_self_steering_collision_soft_active(embezzler_ball):
		return false
	if embezzler_to_other_normal.length_squared() <= 0.001:
		return false

	var normal: Vector2 = embezzler_to_other_normal.normalized()
	var scuttle_velocity: Vector2 = _get_scuttle_velocity_aligned_to_ball(
		embezzler_ball,
		_get_stored_scuttle_velocity(embezzler_ball.get_instance_id())
	)
	var embezzler_speed_toward_other: float = maxf(scuttle_velocity.dot(normal), 0.0)
	var other_speed_toward_embezzler: float = maxf(-other_ball.velocity.dot(normal), 0.0)
	return embezzler_speed_toward_other > self_scuttle_min_speed and embezzler_speed_toward_other > other_speed_toward_embezzler


func _is_self_steering_collision_soft_active(embezzler_ball: Ball) -> bool:
	if embezzler_ball == null or not embezzler_ball.is_embezzler_ball:
		return false

	var ball_id: int = embezzler_ball.get_instance_id()
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
		if _get_active_embezzler_ball_by_id(int(ball_id)) != null:
			kept_state[ball_id] = self_steering_until_by_ball_id[ball_id]
	self_steering_until_by_ball_id = kept_state

	var kept_scuttle_velocity: Dictionary = {}
	for ball_id in self_scuttle_velocity_by_ball_id:
		var embezzler_ball: Ball = _get_active_embezzler_ball_by_id(int(ball_id))
		if embezzler_ball == null:
			continue

		var stored_scuttle_velocity: Vector2 = self_scuttle_velocity_by_ball_id[ball_id]
		var scuttle_velocity: Vector2 = _get_scuttle_velocity_aligned_to_ball(embezzler_ball, stored_scuttle_velocity)
		if scuttle_velocity.length() > self_scuttle_min_speed:
			kept_scuttle_velocity[ball_id] = scuttle_velocity
	self_scuttle_velocity_by_ball_id = kept_scuttle_velocity


func _get_active_stored_value_total() -> int:
	var total: int = 0
	for embezzler_ball in embezzler_balls:
		if not _is_active_embezzler_ball(embezzler_ball):
			continue
		total += int(stored_value_by_ball_id.get(embezzler_ball.get_instance_id(), 0))
	return total


func _get_active_embezzler_count() -> int:
	var active_count: int = 0
	for embezzler_ball in embezzler_balls:
		if _is_active_embezzler_ball(embezzler_ball):
			active_count += 1
	return active_count


func _get_primary_embezzler_ball() -> Ball:
	for embezzler_ball in embezzler_balls:
		if _is_active_embezzler_ball(embezzler_ball):
			return embezzler_ball
	return null


func _get_active_embezzler_ball_by_id(ball_id: int) -> Ball:
	for embezzler_ball in embezzler_balls:
		if not _is_active_embezzler_ball(embezzler_ball):
			continue
		if embezzler_ball.get_instance_id() == ball_id:
			return embezzler_ball
	return null


func _prune_tracked_embezzlers() -> void:
	var kept_balls: Array = []
	var kept_ids: Dictionary = {}
	for embezzler_ball in embezzler_balls:
		if not _is_active_embezzler_ball(embezzler_ball):
			continue
		kept_balls.append(embezzler_ball)
		kept_ids[embezzler_ball.get_instance_id()] = true
	embezzler_balls = kept_balls

	_prune_state_dictionary(stored_value_by_ball_id, kept_ids)
	_prune_state_dictionary(skim_fraction_by_ball_id, kept_ids)
	_prune_state_dictionary(target_pocket_index_by_ball_id, kept_ids)
	_prune_state_dictionary(state_by_ball_id, kept_ids)
	_prune_state_dictionary(aim_pressure_by_ball_id, kept_ids)
	_prune_state_dictionary(aim_pressure_linger_by_ball_id, kept_ids)
	_prune_state_dictionary(last_pressure_reason_by_ball_id, kept_ids)
	_prune_state_dictionary(move_targets_by_ball_id, kept_ids)
	_prune_state_dictionary(self_steering_until_by_ball_id, kept_ids)
	_prune_state_dictionary(self_scuttle_velocity_by_ball_id, kept_ids)
	_prune_state_dictionary(hide_committed_by_ball_id, kept_ids)
	_prune_state_dictionary(escape_committed_by_ball_id, kept_ids)
	_prune_state_dictionary(pocket_test_pending_by_ball_id, kept_ids)
	_prune_state_dictionary(last_escape_roll_msec_by_ball_id, kept_ids)
	_prune_state_dictionary(last_shot_decision_serial_by_ball_id, kept_ids)
	_prune_state_dictionary(last_pocket_roll_msec_by_ball_id, kept_ids)
	_prune_state_dictionary(panic_retreat_until_by_ball_id, kept_ids)


func _prune_state_dictionary(state_dictionary: Dictionary, kept_ids: Dictionary) -> void:
	for ball_id in state_dictionary.keys():
		if not kept_ids.has(int(ball_id)):
			state_dictionary.erase(ball_id)


func _clear_embezzler_state_for_id(ball_id: int) -> void:
	stored_value_by_ball_id.erase(ball_id)
	skim_fraction_by_ball_id.erase(ball_id)
	target_pocket_index_by_ball_id.erase(ball_id)
	state_by_ball_id.erase(ball_id)
	aim_pressure_by_ball_id.erase(ball_id)
	aim_pressure_linger_by_ball_id.erase(ball_id)
	last_pressure_reason_by_ball_id.erase(ball_id)
	move_targets_by_ball_id.erase(ball_id)
	self_steering_until_by_ball_id.erase(ball_id)
	self_scuttle_velocity_by_ball_id.erase(ball_id)
	hide_committed_by_ball_id.erase(ball_id)
	escape_committed_by_ball_id.erase(ball_id)
	pocket_test_pending_by_ball_id.erase(ball_id)
	last_escape_roll_msec_by_ball_id.erase(ball_id)
	last_shot_decision_serial_by_ball_id.erase(ball_id)
	last_pocket_roll_msec_by_ball_id.erase(ball_id)
	panic_retreat_until_by_ball_id.erase(ball_id)


func _is_active_embezzler_ball(ball) -> bool:
	if ball == null or not is_instance_valid(ball):
		return false
	if not (ball is Ball):
		return false
	return ball.is_embezzler_ball and ball.visible
