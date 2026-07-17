extends Node
class_name RogueliteScoringSystem

signal roguelite_shot_score_resolved(score_result: Dictionary)
signal state_changed(snapshot: Dictionary)

const RESOLVER := preload("res://scripts/RogueliteScoreResolver.gd")
const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")

static var _session_self_test_result: Dictionary = {}

var table: BilliardsTable
var shadow_mode_active := true
var debug_cross_mode_inspection := false
var last_score_result: Dictionary = {}
var last_resolution_key := ""
var shot_lab_test_modifiers: Array[Dictionary] = []
var applicable_ledgers_resolved := 0
var invalid_ledger_count := 0
var duplicate_resolution_suppression_count := 0
var predicted_actual_score_mismatch_count := 0
var scoring_analysis_duration_usec := 0
var last_warning := ""
var last_clear_reason := "initial"
var last_self_test_result: Dictionary = {}


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	last_self_test_result = _session_self_test_result.duplicate(true)
	if not table.shot_ledger_system.shot_ledger_completed.is_connected(_on_shot_ledger_completed):
		table.shot_ledger_system.shot_ledger_completed.connect(_on_shot_ledger_completed)
	_emit_state()


func set_shot_lab_test_modifiers(modifiers: Array) -> void:
	shot_lab_test_modifiers.clear()
	for modifier_value in modifiers:
		if modifier_value is Dictionary:
			shot_lab_test_modifiers.append((modifier_value as Dictionary).duplicate(true))
	_emit_state()


func resolve_predicted_ledger(ledger: Dictionary, modifiers: Array = []) -> Dictionary:
	var context: Array = modifiers if not modifiers.is_empty() else shot_lab_test_modifiers
	return RESOLVER.resolve(ledger.duplicate(true), context).duplicate(true)


func get_last_score_result() -> Dictionary:
	return last_score_result.duplicate(true)


func get_score_result_for_ledger(ledger: Dictionary) -> Dictionary:
	if last_score_result.is_empty():
		return {}
	if int(last_score_result.get("shot_id", -1)) != int(ledger.get("shot_id", -2)):
		return {}
	if int(last_score_result.get("attempt_id", -1)) != int(ledger.get("attempt_id", -2)):
		return {}
	if str(last_score_result.get("mode_id", "")) != str(ledger.get("mode_id", "")):
		return {}
	return last_score_result.duplicate(true)


func note_predicted_actual_comparison(parity: Dictionary) -> void:
	if str(parity.get("status", "")) == "FAIL":
		predicted_actual_score_mismatch_count += 1
	_emit_state()


func run_self_tests() -> Dictionary:
	var started_at_usec: int = Time.get_ticks_usec()
	var result_value: Variant = RESOLVER.run_self_tests()
	if not result_value is Dictionary:
		last_self_test_result = {
			"status": "FAIL",
			"timestamp": Time.get_datetime_string_from_system(),
			"total": int(RESOLVER.SELF_TEST_CASE_COUNT),
			"passed": 0,
			"failed": int(RESOLVER.SELF_TEST_CASE_COUNT),
			"failures": [{"name": "Resolver invocation", "expected": "Dictionary", "actual": typeof(result_value)}],
		}
	else:
		last_self_test_result = (result_value as Dictionary).duplicate(true)
	last_self_test_result["duration_usec"] = maxi(Time.get_ticks_usec() - started_at_usec, 0)
	_session_self_test_result = last_self_test_result.duplicate(true)
	_emit_state()
	return last_self_test_result.duplicate(true)


func clear_transient_state(reason: String = "clear") -> void:
	last_score_result.clear()
	last_resolution_key = ""
	last_warning = ""
	last_clear_reason = reason
	_emit_state()


func handle_round_transition() -> void:
	# Keep the duplicate key so a stale completion cannot resolve twice, but clear
	# the round-local presentation result before the next rack begins.
	last_score_result.clear()
	last_warning = ""
	last_clear_reason = "roguelite_round_transition"
	_emit_state()


func capture_rewind_state() -> Dictionary:
	return {
		"last_score_result": last_score_result.duplicate(true),
		"last_resolution_key": last_resolution_key,
		"last_warning": last_warning,
		"last_clear_reason": last_clear_reason,
	}


func restore_rewind_state(state: Dictionary) -> void:
	var result_value: Variant = state.get("last_score_result", {})
	last_score_result = (result_value as Dictionary).duplicate(true) if result_value is Dictionary else {}
	last_resolution_key = str(state.get("last_resolution_key", ""))
	last_warning = str(state.get("last_warning", ""))
	last_clear_reason = str(state.get("last_clear_reason", "rewind_restore"))
	# Restoration is observational only: no score-resolution signal is emitted.
	_emit_state()


func restore_completed_observation_after_rewind(result: Dictionary) -> void:
	last_score_result = result.duplicate(true)
	last_resolution_key = _make_resolution_key(result)
	var warnings: Array = _array_value(last_score_result, "warnings")
	last_warning = str(warnings[0]) if not warnings.is_empty() else ""
	last_clear_reason = "preserved_completed_observation"
	# Preserve the completed observation without replaying the resolution signal.
	_emit_state()


func get_diagnostics_snapshot() -> Dictionary:
	var result: Dictionary = last_score_result
	return {
		"schema_version": int(RESOLVER.SCHEMA_VERSION),
		"scoring_model": str(RESOLVER.SCORING_MODEL),
		"shadow_mode_active": shadow_mode_active,
		"authoritative_score_applied_to_round": false,
		"last_applicable_ledger_shot_id": int(result.get("shot_id", -1)),
		"last_attempt_id": int(result.get("attempt_id", -1)),
		"last_base_haul": int(result.get("base_haul", 0)),
		"last_additive_mult": float(result.get("mult_before_xmult", 1.0)) - float(result.get("base_mult", 1.0)),
		"last_xmult_product": float(result.get("xmult_product", 1.0)),
		"last_final_mult": float(result.get("final_mult", 1.0)),
		"last_shot_score": int(result.get("shot_score", 0)),
		"resolution_step_count": _array_value(result, "resolution_steps").size(),
		"scoring_analysis_duration_usec": scoring_analysis_duration_usec,
		"applicable_ledgers_resolved": applicable_ledgers_resolved,
		"invalid_ledger_count": invalid_ledger_count,
		"duplicate_resolution_suppression_count": duplicate_resolution_suppression_count,
		"predicted_actual_score_mismatch_count": predicted_actual_score_mismatch_count,
		"last_warning": last_warning,
		"last_clear_reason": last_clear_reason,
		"shot_lab_test_modifiers": shot_lab_test_modifiers.duplicate(true),
		"last_self_test_result": last_self_test_result.duplicate(true),
	}


func get_snapshot() -> Dictionary:
	return {
		"last_score_result": last_score_result.duplicate(true),
		"diagnostics": get_diagnostics_snapshot(),
	}


func _on_shot_ledger_completed(ledger: Dictionary) -> void:
	if not shadow_mode_active or not _is_applicable_ledger(ledger):
		return
	var resolution_key: String = _make_resolution_key(ledger)
	if resolution_key == last_resolution_key:
		duplicate_resolution_suppression_count += 1
		_emit_state()
		return
	var started_at_usec: int = Time.get_ticks_usec()
	var modifiers: Array = shot_lab_test_modifiers if str(ledger.get("mode_id", "")) == GAME_MODE_SCRIPT.MODE_SHOT_LAB else []
	var resolved: Dictionary = RESOLVER.resolve(ledger.duplicate(true), modifiers)
	scoring_analysis_duration_usec = maxi(Time.get_ticks_usec() - started_at_usec, 0)
	last_resolution_key = resolution_key
	last_score_result = resolved.duplicate(true)
	applicable_ledgers_resolved += 1
	var result_diagnostics: Dictionary = _dictionary_value(last_score_result, "diagnostics")
	if not bool(result_diagnostics.get("input_valid", false)):
		invalid_ledger_count += 1
	var warnings: Array = _array_value(last_score_result, "warnings")
	last_warning = str(warnings[0]) if not warnings.is_empty() else ""
	roguelite_shot_score_resolved.emit(last_score_result.duplicate(true))
	_emit_state()


func _is_applicable_ledger(ledger: Dictionary) -> bool:
	var mode_id: String = str(ledger.get("mode_id", ""))
	if mode_id in [GAME_MODE_SCRIPT.MODE_ROGUELITE, GAME_MODE_SCRIPT.MODE_SHOT_LAB]:
		return true
	return debug_cross_mode_inspection


func _make_resolution_key(ledger: Dictionary) -> String:
	return "%s|%s|%d|%d" % [
		str(ledger.get("run_generation", "")),
		str(ledger.get("mode_id", "")),
		int(ledger.get("shot_id", -1)),
		int(ledger.get("attempt_id", -1)),
	]


func _emit_state() -> void:
	state_changed.emit(get_snapshot())


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []
