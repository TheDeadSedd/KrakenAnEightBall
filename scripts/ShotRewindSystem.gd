extends Node
class_name ShotRewindSystem

signal state_changed(snapshot: Dictionary)
signal rewind_completed

const CHECKPOINT_VERSION := 1
const DEBUG_AIM_CHECKPOINT_BLOCKER := "Reset unavailable: checkpoint contains anomaly state converted by Debug Aim Mode."

var table: BilliardsTable
var ui_bridge: Object
var checkpoint: Dictionary = {}
var checkpoint_size_bytes := 0
var restoring := false
var last_blocker_reason := "Reset unavailable: no committed shot yet."


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	if not table.oath_system.oaths_changed.is_connected(_on_supported_boundary_changed):
		table.oath_system.oaths_changed.connect(_on_supported_boundary_changed)
	if not table.kraken_boon_system.boons_changed.is_connected(_on_supported_boundary_changed):
		table.kraken_boon_system.boons_changed.connect(_on_supported_boundary_changed)
	checkpoint.clear()
	checkpoint_size_bytes = 0
	restoring = false
	last_blocker_reason = "Reset unavailable: no committed shot yet."
	_emit_state()


func set_ui_bridge(bridge: Object) -> void:
	ui_bridge = bridge


func capture_pre_shot_checkpoint() -> bool:
	checkpoint.clear()
	checkpoint_size_bytes = 0
	var blocker: String = _get_capture_blocker()
	if not blocker.is_empty():
		last_blocker_reason = blocker
		_emit_state()
		return false

	var ball_states: Array[Dictionary] = table.capture_shot_rewind_ball_states()
	checkpoint = {
		"version": CHECKPOINT_VERSION,
		"mode_id": table.get_game_mode_id(),
		"ball_states": ball_states,
		"contains_anomaly_state": _contains_anomaly_state(ball_states),
		"debug_aim_mode_enabled": table.is_debug_aim_mode_enabled(),
		"table_state": table.get_shot_rewind_state(),
		"system_states": _capture_system_states(),
		"ui_state": _capture_ui_state(),
	}
	checkpoint_size_bytes = var_to_bytes(checkpoint).size()
	last_blocker_reason = "Shot resolving"
	_emit_state()
	return true


func request_rewind(preserve_last_completed_ledger: bool = false) -> bool:
	var blocker: String = get_rewind_blocker()
	if not blocker.is_empty():
		last_blocker_reason = blocker
		_emit_state()
		return false

	restoring = true
	last_blocker_reason = "Restoring checkpoint"
	_emit_state()
	var preserved_completed_ledger: Dictionary = {}
	var preserved_scoring_result: Dictionary = {}
	var preserved_shot_lab_state: Dictionary = {}
	if preserve_last_completed_ledger:
		preserved_completed_ledger = table.shot_ledger_system.get_last_completed_ledger()
		preserved_scoring_result = table.roguelite_scoring_system.get_last_score_result()
		if table.is_shot_lab_mode():
			preserved_shot_lab_state = table.shot_lab_system.capture_rewind_state()

	var system_states: Dictionary = checkpoint.get("system_states", {})
	table.prepare_for_shot_rewind()
	table.shot_ledger_system.restore_rewind_state(_get_state(system_states, "shot_ledger"))
	table.roguelite_scoring_system.restore_rewind_state(_get_state(system_states, "roguelite_scoring"))
	if table.is_shot_lab_mode():
		table.shot_lab_system.restore_rewind_state(_get_state(system_states, "shot_lab"))
	table.run_ball_identity_system.restore_rewind_state(_get_state(system_states, "run_ball_identity"))
	table.score_system.restore_rewind_state(_get_state(system_states, "score"))
	table.ball_drop_system.restore_rewind_state(_get_state(system_states, "ball_drop"))
	table.table_event_system.restore_rewind_state(_get_state(system_states, "table_event"))
	if table.is_passage_mode():
		table.passage_system.restore_rewind_state(_get_state(system_states, "passage"))
		table.sunken_spoils_system.restore_rewind_state(_get_state(system_states, "sunken_spoils"))
	table.quartermaster_system.restore_rewind_state(_get_state(system_states, "quartermaster"))
	table.reserve_system.restore_rewind_state(_get_state(system_states, "reserve"))
	if table.is_roguelite_mode():
		if table.roguelite_reward_system != null:
			table.roguelite_reward_system.restore_rewind_state(_get_state(system_states, "roguelite_rewards"))
		if table.roguelite_run_system != null:
			table.roguelite_run_system.restore_rewind_state(_get_state(system_states, "roguelite_run"))
		if table.roguelite_balance_telemetry != null:
			table.roguelite_balance_telemetry.restore_rewind_state(
				_get_state(system_states, "roguelite_balance_telemetry")
			)
	table.spawn_system.restore_rewind_state(_get_state(system_states, "spawn"))
	table.pocket_streak_system.restore_rewind_state(_get_state(system_states, "pocket_streak"))
	table.restore_shot_rewind_balls(checkpoint.get("ball_states", []))
	table.pocket_capture_presenter.restore_rewind_state(_get_state(system_states, "pocket_capture"))
	table.restore_shot_rewind_state(_get_state(checkpoint, "table_state"))
	table.run_stats_system.restore_rewind_state(_get_state(system_states, "run_stats"))
	_restore_ui_state(_get_state(checkpoint, "ui_state"))
	if preserve_last_completed_ledger and not preserved_completed_ledger.is_empty():
		table.shot_ledger_system.restore_completed_observation_after_rewind(preserved_completed_ledger)
		if not preserved_scoring_result.is_empty():
			table.roguelite_scoring_system.restore_completed_observation_after_rewind(preserved_scoring_result)
		if table.is_shot_lab_mode() and not preserved_shot_lab_state.is_empty():
			table.shot_lab_system.restore_completed_observation_after_rewind(preserved_shot_lab_state)

	restoring = false
	last_blocker_reason = ""
	_emit_state()
	rewind_completed.emit()
	return true


func notify_table_state_changed() -> void:
	var blocker: String = get_rewind_blocker()
	last_blocker_reason = blocker
	_emit_state()


func handle_debug_aim_mode_enabled() -> void:
	if checkpoint.is_empty() or not bool(checkpoint.get("contains_anomaly_state", false)):
		return
	invalidate_checkpoint(DEBUG_AIM_CHECKPOINT_BLOCKER)


func invalidate_checkpoint(reason: String) -> void:
	checkpoint.clear()
	checkpoint_size_bytes = 0
	last_blocker_reason = reason
	_emit_state()


func _on_supported_boundary_changed(_snapshot: Dictionary) -> void:
	notify_table_state_changed()


func get_rewind_blocker() -> String:
	if restoring:
		return "Reset unavailable: restoration in progress."
	if checkpoint.is_empty():
		return last_blocker_reason if not last_blocker_reason.is_empty() else "Reset unavailable: no committed shot yet."
	if int(checkpoint.get("version", 0)) != CHECKPOINT_VERSION:
		return "Reset unavailable: checkpoint version is unsupported."
	if str(checkpoint.get("mode_id", "")) != table.get_game_mode_id():
		return "Reset unavailable: checkpoint belongs to another mode."
	if (
		table.is_debug_aim_mode_enabled()
		and bool(checkpoint.get("contains_anomaly_state", false))
	):
		return DEBUG_AIM_CHECKPOINT_BLOCKER
	if not table.is_roguelite_mode():
		if table.shot_active:
			return "Reset unavailable: shot is still resolving."
		if not table.are_all_balls_stopped_for_rewind():
			return "Reset unavailable: balls are still moving."
	# Long Sink checkpoints are captured before launch, and restoration cancels
	# the active ledger/presentation before rebuilding that snapshot. Transient
	# spawns and unsupported system state remain guarded by the checks below.
	var unsupported_state_blocker: String = table.get_shot_rewind_unsupported_state_blocker()
	if not unsupported_state_blocker.is_empty():
		return unsupported_state_blocker
	var transition_blocker: String = table.get_shot_rewind_transition_blocker()
	if not transition_blocker.is_empty():
		return transition_blocker
	return ""


func get_state_snapshot() -> Dictionary:
	var blocker: String = get_rewind_blocker()
	return {
		"checkpoint_version": CHECKPOINT_VERSION,
		"has_checkpoint": not checkpoint.is_empty(),
		"restoring": restoring,
		"can_rewind": blocker.is_empty(),
		"blocker_reason": blocker,
		"checkpoint_ball_count": _get_checkpoint_ball_count(),
		"checkpoint_size_bytes": checkpoint_size_bytes,
		"checkpoint_mode_id": str(checkpoint.get("mode_id", "")),
	}


func get_ui_transition_blocker() -> String:
	if ui_bridge != null and ui_bridge.has_method("get_shot_rewind_transition_blocker"):
		return str(ui_bridge.call("get_shot_rewind_transition_blocker"))
	return ""


func _get_capture_blocker() -> String:
	if table == null:
		return "Reset unavailable: table is missing."
	return table.get_shot_rewind_capture_blocker()


func _capture_system_states() -> Dictionary:
	var states := {
		"run_ball_identity": table.run_ball_identity_system.get_rewind_state(),
		"shot_ledger": table.shot_ledger_system.capture_rewind_state(),
		"roguelite_scoring": table.roguelite_scoring_system.capture_rewind_state(),
		"score": table.score_system.get_rewind_state(),
		"ball_drop": table.ball_drop_system.get_rewind_state(),
		"table_event": table.table_event_system.get_rewind_state(),
		"run_stats": table.run_stats_system.get_rewind_state(),
		"quartermaster": table.quartermaster_system.get_rewind_state(),
		"reserve": table.reserve_system.get_rewind_state(),
		"spawn": table.spawn_system.get_rewind_state(),
		"pocket_streak": table.pocket_streak_system.get_rewind_state(),
		"pocket_capture": table.pocket_capture_presenter.get_rewind_state(),
	}
	if table.is_shot_lab_mode():
		states["shot_lab"] = table.shot_lab_system.capture_rewind_state()
	if table.is_passage_mode():
		states["passage"] = table.passage_system.get_rewind_state()
		states["sunken_spoils"] = table.sunken_spoils_system.get_rewind_state()
	if table.is_roguelite_mode():
		if table.roguelite_run_system != null:
			states["roguelite_run"] = table.roguelite_run_system.get_rewind_state()
		if table.roguelite_reward_system != null:
			states["roguelite_rewards"] = table.roguelite_reward_system.get_rewind_state()
		if table.roguelite_balance_telemetry != null:
			states["roguelite_balance_telemetry"] = (
				table.roguelite_balance_telemetry.capture_rewind_state()
			)
	return states


func _capture_ui_state() -> Dictionary:
	if ui_bridge != null and ui_bridge.has_method("capture_shot_rewind_ui_state"):
		var state_value: Variant = ui_bridge.call("capture_shot_rewind_ui_state")
		if state_value is Dictionary:
			return (state_value as Dictionary).duplicate(true)
	return {}


func _restore_ui_state(state: Dictionary) -> void:
	if ui_bridge != null and ui_bridge.has_method("restore_shot_rewind_ui_state"):
		ui_bridge.call("restore_shot_rewind_ui_state", state.duplicate(true))


func _get_state(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	if value is Dictionary:
		return value as Dictionary
	return {}


func _get_checkpoint_ball_count() -> int:
	var ball_states_value: Variant = checkpoint.get("ball_states", [])
	if ball_states_value is Array:
		return (ball_states_value as Array).size()
	return 0


func _contains_anomaly_state(ball_states: Array[Dictionary]) -> bool:
	for state in ball_states:
		if (
			bool(state.get("is_wayfinder", false))
			or bool(state.get("wayfinder_active", false))
			or bool(state.get("is_powder_keg", false))
			or bool(state.get("is_anchor_ball", false))
			or bool(state.get("is_anchor_curse_seed", false))
			or bool(state.get("is_cannon_ball", false))
			or bool(state.get("is_treasure_ball", false))
			or bool(state.get("is_embezzler_ball", false))
			or bool(state.get("wayfinder_current_active", false))
		):
			return true
	return false


func _emit_state() -> void:
	state_changed.emit(get_state_snapshot())
