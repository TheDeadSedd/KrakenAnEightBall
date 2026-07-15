extends RefCounted
class_name DebugAimCompatibilitySystem

signal state_changed(snapshot: Dictionary)

var table: BilliardsTable
var enabled := false
var anomalies_converted_this_activation := 0
var anomalies_converted_this_session := 0
var last_normalized_anomaly_type := "none"


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	_apply_system_suppression(false)


func set_enabled(enabled_value: bool) -> Dictionary:
	if enabled == enabled_value:
		return get_snapshot()

	enabled = enabled_value
	anomalies_converted_this_activation = 0
	if table != null and table.spawn_system != null:
		table.spawn_system.set_debug_aim_mode_enabled(enabled)

	if enabled:
		var candidates: Array[Dictionary] = _collect_anomaly_candidates()
		for candidate in candidates:
			var ball: Ball = candidate.get("ball") as Ball
			if ball == null or not is_instance_valid(ball):
				continue
			if ball.normalize_anomaly_identity_for_debug_aim():
				anomalies_converted_this_activation += 1
				anomalies_converted_this_session += 1
				last_normalized_anomaly_type = str(candidate.get("kind", "unknown"))
		# Normalize first so current-only carriers still count as conversions;
		# suppression then releases every owning system's tracked state.
		_apply_system_suppression(true)
	else:
		_apply_system_suppression(false)

	var snapshot: Dictionary = get_snapshot()
	state_changed.emit(snapshot)
	return snapshot


func is_enabled() -> bool:
	return enabled


func get_snapshot() -> Dictionary:
	var spawn_snapshot: Dictionary = (
		table.spawn_system.get_debug_aim_normalization_snapshot()
		if table != null and table.spawn_system != null
		else {}
	)
	return {
		"enabled": enabled,
		"anomalies_converted_this_activation": anomalies_converted_this_activation,
		"anomalies_converted_this_session": anomalies_converted_this_session,
		"anomaly_spawn_requests_normalized": int(
			spawn_snapshot.get("anomaly_spawn_requests_normalized", 0)
		),
		"last_normalized_anomaly_type": (
			str(spawn_snapshot.get("last_normalized_anomaly_type", last_normalized_anomaly_type))
			if int(spawn_snapshot.get("anomaly_spawn_requests_normalized", 0)) > 0
			else last_normalized_anomaly_type
		),
		"active_anomaly_trackers_remaining": _get_active_tracker_count(),
	}


func notify_spawn_normalized() -> void:
	if enabled:
		state_changed.emit(get_snapshot())


func _collect_anomaly_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if table == null or table.balls == null:
		return candidates
	for child in table.balls.get_children():
		var ball: Ball = child as Ball
		if ball == null or ball == table.cue_ball or ball == table.eight_ball:
			continue
		var kind: String = _get_anomaly_kind(ball)
		if kind.is_empty():
			continue
		candidates.append({"ball": ball, "kind": kind})
	return candidates


func _get_anomaly_kind(ball: Ball) -> String:
	if ball.is_wayfinder or ball.wayfinder_active:
		return "wayfinder"
	if table.wayfinder_system != null and table.wayfinder_system.is_temporary_current_carrier(ball):
		return "wayfinder_current"
	if ball.is_powder_keg:
		return "powder_keg"
	if ball.is_anchor_ball or ball.is_anchor_curse_seed:
		return "anchor"
	if ball.is_cannon_ball:
		return "cannon"
	if ball.is_treasure_ball:
		return "treasure"
	if ball.is_embezzler_ball:
		return "embezzler"
	return ""


func _apply_system_suppression(suppressed: bool) -> void:
	if table == null:
		return
	table.wayfinder_system.set_debug_aim_mode_suppressed(suppressed)
	table.powder_keg_system.set_debug_aim_mode_suppressed(suppressed)
	table.anchor_ball_system.set_debug_aim_mode_suppressed(suppressed)
	table.cannon_ball_system.set_debug_aim_mode_suppressed(suppressed)
	table.treasure_ball_system.set_debug_aim_mode_suppressed(suppressed)
	table.embezzler_system.set_debug_aim_mode_suppressed(suppressed)


func _get_active_tracker_count() -> int:
	if table == null:
		return 0
	return (
		table.wayfinder_system.get_debug_aim_active_tracker_count()
		+ table.powder_keg_system.get_debug_aim_active_tracker_count()
		+ table.anchor_ball_system.get_debug_aim_active_tracker_count()
		+ table.cannon_ball_system.get_debug_aim_active_tracker_count()
		+ table.treasure_ball_system.get_debug_aim_active_tracker_count()
		+ table.embezzler_system.get_debug_aim_active_tracker_count()
	)
