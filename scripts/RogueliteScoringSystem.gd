extends Node
class_name RogueliteScoringSystem

signal roguelite_shot_score_resolved(score_result: Dictionary)
signal authoritative_round_score_committed(score_result: Dictionary)
signal state_changed(snapshot: Dictionary)

const RESOLVER := preload("res://scripts/RogueliteScoreResolver.gd")
const TRIGGER_EVALUATOR := preload("res://scripts/RogueliteScoringTriggerEvaluator.gd")
const DOUBLOON_PAYOUT_RESOLVER := preload(
	"res://scripts/RogueliteDoubloonPayoutResolver.gd"
)
const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")

const MAX_RECENT_RESOLUTION_KEYS := 256

static var _session_self_test_result: Dictionary = {}

var table: BilliardsTable
var build_system: RogueliteBuildSystem
var scoring_enabled := true
var debug_cross_mode_inspection := false
var last_score_result: Dictionary = {}
var last_source_ledger: Dictionary = {}
var last_resolution_key := ""
var pending_authoritative_result: Dictionary = {}
var pending_authoritative_ledger: Dictionary = {}
var pending_authoritative_key := ""
var recent_resolution_keys: Dictionary = {}
var recent_resolution_key_order: Array[String] = []
var shot_lab_test_modifiers: Array[Dictionary] = []
var shot_lab_apply_test_doubloon_payout := false
var shot_lab_payout_application_keys: Dictionary = {}
var shot_lab_payout_application_key_order: Array[String] = []
var last_shot_lab_payout_application: Dictionary = {}
var shot_lab_balance_telemetry_enabled := false
var shot_lab_payout_application_count := 0
var shot_lab_payout_duplicate_suppressions := 0
var shot_lab_wallet_mutation_suppression_count := 0
var applicable_ledgers_resolved := 0
var invalid_ledger_count := 0
var duplicate_resolution_suppression_count := 0
var quota_application_count := 0
var quota_application_duplicate_suppressions := 0
var predicted_actual_score_mismatch_count := 0
var predicted_actual_tap_mismatch_count := 0
var last_predicted_actual_tap_parity: Dictionary = {}
var scoring_analysis_duration_usec := 0
var last_warning := ""
var last_clear_reason := "initial"
var last_self_test_result: Dictionary = {}


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	last_self_test_result = _session_self_test_result.duplicate(true)
	pending_authoritative_result.clear()
	pending_authoritative_ledger.clear()
	pending_authoritative_key = ""
	if not table.shot_ledger_system.shot_ledger_completed.is_connected(_on_shot_ledger_completed):
		table.shot_ledger_system.shot_ledger_completed.connect(_on_shot_ledger_completed)
	_emit_state()


func set_build_system(system_ref: RogueliteBuildSystem) -> void:
	build_system = system_ref
	_emit_state()


func set_shot_lab_test_modifiers(modifiers: Array) -> void:
	shot_lab_test_modifiers.clear()
	for modifier_value in modifiers:
		if modifier_value is Dictionary:
			shot_lab_test_modifiers.append((modifier_value as Dictionary).duplicate(true))
	_emit_state()


func set_shot_lab_apply_test_doubloon_payout(enabled: bool) -> void:
	shot_lab_apply_test_doubloon_payout = enabled
	_emit_state()


func is_shot_lab_apply_test_doubloon_payout_enabled() -> bool:
	return shot_lab_apply_test_doubloon_payout


func set_shot_lab_balance_telemetry_enabled(enabled: bool) -> void:
	shot_lab_balance_telemetry_enabled = enabled
	_emit_state()


func is_shot_lab_balance_telemetry_enabled() -> bool:
	return shot_lab_balance_telemetry_enabled


func resolve_predicted_ledger(ledger: Dictionary, modifiers: Array = []) -> Dictionary:
	var assembled: Dictionary = _assemble_modifier_context(
		ledger,
		RogueliteBuildSystem.SOURCE_PREDICTED,
		false,
		modifiers
	)
	var context: Array = _array_value(assembled, "modifier_context")
	var resolved: Dictionary = RESOLVER.resolve(ledger.duplicate(true), context)
	_attach_build_evaluation(resolved, _dictionary_value(assembled, "build_evaluation"))
	_attach_doubloon_payout(resolved)
	return resolved.duplicate(true)


static func is_eight_ball_build_mode(mode_id: String) -> bool:
	return mode_id in [GAME_MODE_SCRIPT.MODE_ROGUELITE, GAME_MODE_SCRIPT.MODE_SHOT_LAB]


func get_last_score_result() -> Dictionary:
	return last_score_result.duplicate(true)


func has_pending_authoritative_round_score() -> bool:
	return not pending_authoritative_result.is_empty()


func get_pending_authoritative_round_score() -> Dictionary:
	return pending_authoritative_result.duplicate(true)


func commit_pending_authoritative_round_score(expected_result: Dictionary = {}) -> Dictionary:
	if pending_authoritative_result.is_empty():
		quota_application_duplicate_suppressions += 1
		return last_score_result.duplicate(true)
	if not expected_result.is_empty():
		var expected_key: String = _make_resolution_key(expected_result)
		if expected_key != pending_authoritative_key:
			quota_application_duplicate_suppressions += 1
			return {}
	var resolved: Dictionary = pending_authoritative_result.duplicate(true)
	var ledger: Dictionary = pending_authoritative_ledger.duplicate(true)
	pending_authoritative_result.clear()
	pending_authoritative_ledger.clear()
	pending_authoritative_key = ""
	_commit_authoritative_round_score(resolved, ledger)
	last_score_result = resolved.duplicate(true)
	authoritative_round_score_committed.emit(last_score_result.duplicate(true))
	_emit_state()
	return last_score_result.duplicate(true)


func get_source_ledger_for_result(score_result: Dictionary) -> Dictionary:
	if _result_matches_ledger(score_result, last_source_ledger):
		return last_source_ledger.duplicate(true)
	if table != null and table.shot_ledger_system != null:
		var completed_ledger: Dictionary = table.shot_ledger_system.get_last_completed_ledger()
		if _result_matches_ledger(score_result, completed_ledger):
			return completed_ledger.duplicate(true)
	return {}


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


func get_balance_telemetry_payload(
	score_result: Dictionary,
	ledger: Dictionary
) -> Dictionary:
	var analysis: Dictionary = _dictionary_value(score_result, "balance_telemetry")
	var base_result: Dictionary = {}
	if analysis.is_empty():
		base_result = RESOLVER.resolve(ledger.duplicate(true), [])
	else:
		base_result = {
			"source": str(ledger.get("source", "")),
			"mode_id": str(ledger.get("mode_id", "")),
			"run_generation": int(ledger.get("run_generation", -1)),
			"shot_id": int(ledger.get("shot_id", -1)),
			"attempt_id": int(ledger.get("attempt_id", -1)),
			"final_haul": int(analysis.get("base_haul", 0)),
			"final_mult": float(analysis.get("base_mult", 1.0)),
			"shot_score": int(analysis.get("base_score_without_build", 0)),
		}
	var counterfactuals: Dictionary = _dictionary_value(
		analysis,
		"counterfactual_cache"
	).duplicate(true)
	var context: Dictionary = {
		"base_resolution_duration_usec": int(analysis.get(
			"base_resolution_duration_usec",
			0
		)),
		"counterfactual_resolution_duration_usec": int(analysis.get(
			"counterfactual_resolution_duration_usec",
			0
		)),
	}
	return {
		"base_score_result": base_result.duplicate(true),
		"item_counterfactual_results": counterfactuals,
		"context": context,
	}


func note_predicted_actual_comparison(parity: Dictionary) -> void:
	last_predicted_actual_tap_parity = _make_tap_parity_snapshot(parity)
	if str(parity.get("status", "")) == "FAIL":
		predicted_actual_score_mismatch_count += 1
		if (
			bool(last_predicted_actual_tap_parity.get("available", false))
			and not bool(last_predicted_actual_tap_parity.get("matches", false))
		):
			predicted_actual_tap_mismatch_count += 1
	_emit_state()


func run_self_tests() -> Dictionary:
	var started_at_usec: int = Time.get_ticks_usec()
	var resolver_result: Dictionary = _run_self_test_component(
		"Resolver",
		RESOLVER.run_self_tests(),
		int(RESOLVER.SELF_TEST_CASE_COUNT)
	)
	var trigger_result: Dictionary = _run_self_test_component(
		"Trigger Evaluator",
		TRIGGER_EVALUATOR.run_self_tests(),
		int(TRIGGER_EVALUATOR.SELF_TEST_CASE_COUNT)
	)
	var cases: Array = _array_value(resolver_result, "cases").duplicate(true)
	cases.append_array(_array_value(trigger_result, "cases").duplicate(true))
	var failures: Array = _array_value(resolver_result, "failures").duplicate(true)
	failures.append_array(_array_value(trigger_result, "failures").duplicate(true))
	var total: int = int(resolver_result.get("total", 0)) + int(trigger_result.get("total", 0))
	var passed: int = int(resolver_result.get("passed", 0)) + int(trigger_result.get("passed", 0))
	last_self_test_result = {
		"status": "PASS" if failures.is_empty() and passed == total else "FAIL",
		"timestamp": Time.get_datetime_string_from_system(),
		"total": total,
		"passed": passed,
		"failed": maxi(total - passed, 0),
		"cases": cases,
		"failures": failures,
		"components": {
			"resolver": resolver_result.duplicate(true),
			"trigger_evaluator": trigger_result.duplicate(true),
		},
	}
	last_self_test_result["duration_usec"] = maxi(Time.get_ticks_usec() - started_at_usec, 0)
	_session_self_test_result = last_self_test_result.duplicate(true)
	_emit_state()
	return last_self_test_result.duplicate(true)


func clear_transient_state(reason: String = "clear") -> void:
	last_score_result.clear()
	last_source_ledger.clear()
	last_resolution_key = ""
	pending_authoritative_result.clear()
	pending_authoritative_ledger.clear()
	pending_authoritative_key = ""
	last_warning = ""
	last_clear_reason = reason
	_emit_state()


func handle_round_transition() -> void:
	# Keep the duplicate key so a stale completion cannot resolve twice, but clear
	# the round-local result before the next rack. Retain its frozen source ledger
	# so the presentation-only Replay Last World Tally action remains truthful.
	last_score_result.clear()
	pending_authoritative_result.clear()
	pending_authoritative_ledger.clear()
	pending_authoritative_key = ""
	last_warning = ""
	last_clear_reason = "roguelite_round_transition"
	_emit_state()


func capture_rewind_state() -> Dictionary:
	return {
		"last_score_result": last_score_result.duplicate(true),
		"last_source_ledger": last_source_ledger.duplicate(true),
		"last_resolution_key": last_resolution_key,
		"pending_authoritative_result": pending_authoritative_result.duplicate(true),
		"pending_authoritative_ledger": pending_authoritative_ledger.duplicate(true),
		"pending_authoritative_key": pending_authoritative_key,
		"last_warning": last_warning,
		"last_clear_reason": last_clear_reason,
		"shot_lab_payout_application_keys": shot_lab_payout_application_keys.duplicate(true),
		"shot_lab_payout_application_key_order": shot_lab_payout_application_key_order.duplicate(),
		"last_shot_lab_payout_application": last_shot_lab_payout_application.duplicate(true),
		"shot_lab_payout_application_count": shot_lab_payout_application_count,
		"shot_lab_payout_duplicate_suppressions": shot_lab_payout_duplicate_suppressions,
		"shot_lab_wallet_mutation_suppression_count": shot_lab_wallet_mutation_suppression_count,
	}


func restore_rewind_state(state: Dictionary) -> void:
	var result_value: Variant = state.get("last_score_result", {})
	last_score_result = (result_value as Dictionary).duplicate(true) if result_value is Dictionary else {}
	var ledger_value: Variant = state.get("last_source_ledger", {})
	last_source_ledger = (ledger_value as Dictionary).duplicate(true) if ledger_value is Dictionary else {}
	last_resolution_key = str(state.get("last_resolution_key", ""))
	var pending_result_value: Variant = state.get("pending_authoritative_result", {})
	pending_authoritative_result = (
		(pending_result_value as Dictionary).duplicate(true)
		if pending_result_value is Dictionary
		else {}
	)
	var pending_ledger_value: Variant = state.get("pending_authoritative_ledger", {})
	pending_authoritative_ledger = (
		(pending_ledger_value as Dictionary).duplicate(true)
		if pending_ledger_value is Dictionary
		else {}
	)
	pending_authoritative_key = str(state.get("pending_authoritative_key", ""))
	last_warning = str(state.get("last_warning", ""))
	last_clear_reason = str(state.get("last_clear_reason", "rewind_restore"))
	_restore_shot_lab_payout_application_keys(state)
	last_shot_lab_payout_application = _dictionary_value(
		state,
		"last_shot_lab_payout_application"
	).duplicate(true)
	shot_lab_payout_application_count = maxi(
		int(state.get("shot_lab_payout_application_count", 0)),
		0
	)
	shot_lab_payout_duplicate_suppressions = maxi(
		int(state.get("shot_lab_payout_duplicate_suppressions", 0)),
		0
	)
	shot_lab_wallet_mutation_suppression_count = maxi(
		int(state.get("shot_lab_wallet_mutation_suppression_count", 0)),
		0
	)
	# Restoration is observational only: no score-resolution signal is emitted.
	_emit_state()


func restore_completed_observation_after_rewind(result: Dictionary) -> void:
	last_score_result = result.duplicate(true)
	_sanitize_rewound_payout_observation(last_score_result)
	last_source_ledger.clear()
	last_resolution_key = _make_resolution_key(result)
	pending_authoritative_result.clear()
	pending_authoritative_ledger.clear()
	pending_authoritative_key = ""
	var warnings: Array = _array_value(last_score_result, "warnings")
	last_warning = str(warnings[0]) if not warnings.is_empty() else ""
	last_clear_reason = "preserved_completed_observation"
	# Preserve the completed observation without replaying the resolution signal.
	_emit_state()


func _sanitize_rewound_payout_observation(result: Dictionary) -> void:
	var application: Dictionary = _dictionary_value(
		result,
		"doubloon_payout_application"
	).duplicate(true)
	if application.is_empty():
		return
	var restored_wallet: int = (
		table.score_system.get_doubloons_total()
		if table != null and table.score_system != null
		else int(application.get("wallet_before", 0))
	)
	application["applied"] = false
	application["wallet_before"] = restored_wallet
	application["wallet_after"] = restored_wallet
	application["terminal_shot_payout"] = false
	application["reason"] = "rewound_observation"
	application["rewound"] = true
	result["doubloon_payout_application"] = application
	result["doubloon_payout_applied"] = false
	result["terminal_shot_payout"] = false
	var diagnostics: Dictionary = _dictionary_value(result, "diagnostics")
	diagnostics["doubloon_wallet_before"] = restored_wallet
	diagnostics["doubloon_wallet_after"] = restored_wallet
	diagnostics["doubloon_payout_applied"] = false
	diagnostics["terminal_shot_payout"] = false
	result["diagnostics"] = diagnostics


func get_diagnostics_snapshot() -> Dictionary:
	var result: Dictionary = last_score_result
	var payout: Dictionary = _dictionary_value(result, "doubloon_payout")
	var payout_application: Dictionary = _dictionary_value(
		result,
		"doubloon_payout_application"
	)
	var legacy_presentation: Dictionary = {}
	if table != null and table.score_system != null:
		legacy_presentation = table.score_system.get_legacy_presentation_diagnostics()
	return {
		"schema_version": int(RESOLVER.SCHEMA_VERSION),
		"scoring_model": str(RESOLVER.SCORING_MODEL),
		"scoring_enabled": scoring_enabled,
		"haul_mult_sole_authority": true,
		"authoritative_score_applied_to_round": bool(result.get("authoritative_score_applied_to_round", false)),
		"legacy_scoring_dev_option_present": false,
		"doubloon_to_quota_connections": 0,
		"legacy_quota_bonus_calls": 0,
		"quota_application_count": quota_application_count,
		"quota_application_duplicate_suppressions": quota_application_duplicate_suppressions,
		"authoritative_score_pending": not pending_authoritative_result.is_empty(),
		"pending_authoritative_key": pending_authoritative_key,
		"pending_score_delta": int(pending_authoritative_result.get("round_score_delta_pending", 0)),
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
		"predicted_actual_tap_mismatch_count": predicted_actual_tap_mismatch_count,
		"last_predicted_actual_tap_parity": last_predicted_actual_tap_parity.duplicate(true),
		"last_warning": last_warning,
		"last_clear_reason": last_clear_reason,
		"shot_lab_test_modifiers": shot_lab_test_modifiers.duplicate(true),
		"shot_lab_apply_test_doubloon_payout": shot_lab_apply_test_doubloon_payout,
		"shot_lab_payout_application_count": shot_lab_payout_application_count,
		"shot_lab_payout_duplicate_suppressions": shot_lab_payout_duplicate_suppressions,
		"shot_lab_wallet_mutation_suppression_count": shot_lab_wallet_mutation_suppression_count,
		"legacy_presentation": legacy_presentation,
		"doubloon_payout": {
			"payout_model": str(payout.get("source", "haul_mult_base_haul_v1")),
			"shot_id": int(payout.get("shot_id", result.get("shot_id", -1))),
			"attempt_id": int(payout.get("attempt_id", result.get("attempt_id", -1))),
			"base_haul": int(payout.get("base_haul", 0)),
			"scoring_balls": int(payout.get("scoring_object_ball_count", 0)),
			"derived_payout": int(payout.get("doubloons_awarded", 0)),
			"wallet_before": int(payout_application.get("wallet_before", 0)),
			"wallet_after": int(payout_application.get("wallet_after", 0)),
			"applied": bool(payout_application.get("applied", false)),
			"duplicate_suppression": bool(payout_application.get(
				"duplicate_suppression",
				false
			)),
			"application_key": str(payout_application.get("application_key", "")),
			"terminal_shot_payout": bool(payout_application.get(
				"terminal_shot_payout",
				false
			)),
			"shot_lab_wallet_mutation_suppressed": bool(payout_application.get(
				"shot_lab_wallet_mutation_suppressed",
				str(result.get("mode_id", "")) == GAME_MODE_SCRIPT.MODE_SHOT_LAB
					and not shot_lab_apply_test_doubloon_payout
			)),
		},
		"last_self_test_result": last_self_test_result.duplicate(true),
	}


func get_snapshot() -> Dictionary:
	return {
		"last_score_result": last_score_result.duplicate(true),
		"diagnostics": get_diagnostics_snapshot(),
	}


func _on_shot_ledger_completed(ledger: Dictionary) -> void:
	if not scoring_enabled or not _is_applicable_ledger(ledger):
		return
	var resolution_key: String = _make_resolution_key(ledger)
	if resolution_key == last_resolution_key or recent_resolution_keys.has(resolution_key):
		duplicate_resolution_suppression_count += 1
		if str(ledger.get("mode_id", "")) == GAME_MODE_SCRIPT.MODE_ROGUELITE:
			quota_application_duplicate_suppressions += 1
		_emit_state()
		return
	var started_at_usec: int = Time.get_ticks_usec()
	var assembled: Dictionary = _assemble_modifier_context(
		ledger,
		RogueliteBuildSystem.SOURCE_AUTHORITATIVE,
		true
	)
	var modifiers: Array = _array_value(assembled, "modifier_context")
	var resolved: Dictionary = RESOLVER.resolve(ledger.duplicate(true), modifiers)
	_attach_build_evaluation(resolved, _dictionary_value(assembled, "build_evaluation"))
	_attach_balance_shot_analysis(resolved, ledger, assembled)
	_attach_doubloon_payout(resolved)
	_handle_shot_lab_doubloon_payout(resolved, ledger)
	scoring_analysis_duration_usec = maxi(Time.get_ticks_usec() - started_at_usec, 0)
	last_resolution_key = resolution_key
	_remember_resolution_key(resolution_key)
	last_source_ledger = ledger.duplicate(true)
	_prepare_authoritative_round_score(resolved, ledger)
	last_score_result = resolved.duplicate(true)
	applicable_ledgers_resolved += 1
	var result_diagnostics: Dictionary = _dictionary_value(last_score_result, "diagnostics")
	if not bool(result_diagnostics.get("input_valid", false)):
		invalid_ledger_count += 1
	var warnings: Array = _array_value(last_score_result, "warnings")
	last_warning = str(warnings[0]) if not warnings.is_empty() else ""
	if bool(last_score_result.get("authoritative_score_pending", false)):
		pending_authoritative_result = last_score_result.duplicate(true)
		pending_authoritative_ledger = ledger.duplicate(true)
		pending_authoritative_key = resolution_key
	roguelite_shot_score_resolved.emit(last_score_result.duplicate(true))
	_emit_state()


func _is_applicable_ledger(ledger: Dictionary) -> bool:
	var mode_id: String = str(ledger.get("mode_id", ""))
	if mode_id in [GAME_MODE_SCRIPT.MODE_ROGUELITE, GAME_MODE_SCRIPT.MODE_SHOT_LAB]:
		return true
	return debug_cross_mode_inspection


func _assemble_modifier_context(
	ledger: Dictionary,
	source: String,
	emit_activation_signals: bool,
	explicit_modifiers: Array = []
) -> Dictionary:
	var context: Array = []
	var build_evaluation: Dictionary = {}
	var mode_id: String = str(ledger.get("mode_id", ""))
	if build_system != null and is_eight_ball_build_mode(mode_id):
		build_evaluation = build_system.evaluate_analyzed_ledger(
			ledger.duplicate(true),
			source,
			emit_activation_signals
		)
		context.append_array(_array_value(build_evaluation, "modifier_context"))
	if not explicit_modifiers.is_empty():
		context.append_array(explicit_modifiers.duplicate(true))
	elif mode_id == GAME_MODE_SCRIPT.MODE_SHOT_LAB:
		context.append_array(shot_lab_test_modifiers.duplicate(true))
	return {
		"modifier_context": context,
		"build_evaluation": build_evaluation,
	}


func _attach_build_evaluation(resolved: Dictionary, evaluation: Dictionary) -> void:
	if evaluation.is_empty():
		return
	resolved["eight_ball_build_evaluation"] = evaluation.duplicate(true)
	var diagnostics: Dictionary = _dictionary_value(resolved, "diagnostics")
	diagnostics["eight_ball_trigger_occurrence_count"] = _array_value(
		evaluation,
		"trigger_occurrences"
	).size()
	diagnostics["eight_ball_modifier_activation_count"] = _array_value(
		evaluation,
		"modifier_context"
	).size()
	resolved["diagnostics"] = diagnostics


func _attach_balance_shot_analysis(
	resolved: Dictionary,
	ledger: Dictionary,
	assembled: Dictionary
) -> void:
	var mode_id: String = str(ledger.get("mode_id", ""))
	if mode_id != GAME_MODE_SCRIPT.MODE_ROGUELITE:
		if mode_id != GAME_MODE_SCRIPT.MODE_SHOT_LAB or not shot_lab_balance_telemetry_enabled:
			return
	var started_at_usec: int = Time.get_ticks_usec()
	var base_started_usec: int = Time.get_ticks_usec()
	var base_result: Dictionary = RESOLVER.resolve(ledger.duplicate(true), [])
	var base_resolution_duration_usec: int = maxi(
		Time.get_ticks_usec() - base_started_usec,
		0
	)
	var build_evaluation: Dictionary = _dictionary_value(assembled, "build_evaluation")
	var trigger_counts: Dictionary = _dictionary_value(
		build_evaluation,
		"trigger_count_by_id"
	).duplicate(true)
	var full_score: int = maxi(int(resolved.get("shot_score", 0)), 0)
	var base_score: int = maxi(int(base_result.get("shot_score", 0)), 0)
	var item_activations: Array[Dictionary] = _make_balance_item_activation_records(resolved)
	var item_marginals: Array[Dictionary] = []
	var counterfactual_cache: Dictionary = {}
	var marginal_sum := 0
	var counterfactual_started_usec: int = Time.get_ticks_usec()
	var build_snapshot: Dictionary = (
		build_system.get_build_snapshot()
		if build_system != null
		else {}
	)
	if build_system != null:
		var owned_ids_value: Variant = build_snapshot.get("item_ids_by_slot", [])
		if owned_ids_value is Array:
			for slot_index in range(mini((owned_ids_value as Array).size(), 5)):
				var item_id: String = str((owned_ids_value as Array)[slot_index])
				if item_id.is_empty() or counterfactual_cache.has(item_id):
					continue
				var without_context: Array[Dictionary] = build_system.build_modifier_context_excluding_item(
					ledger,
					item_id
				)
				var without_result: Dictionary = RESOLVER.resolve(
					ledger.duplicate(true),
					without_context
				)
				var without_score: int = maxi(int(without_result.get("shot_score", 0)), 0)
				var marginal_uplift: int = full_score - without_score
				counterfactual_cache[item_id] = without_score
				marginal_sum += marginal_uplift
				var definition: Dictionary = _get_build_definition_for_slot(build_snapshot, slot_index)
				item_marginals.append({
					"eight_ball_item_id": item_id,
					"display_name": str(definition.get("display_name", item_id)),
					"family_id": str(definition.get("family_id", "")),
					"modifier_phase": str(definition.get("modifier_phase", "")),
					"tray_slot_index": slot_index,
					"full_score": full_score,
					"score_without_item": without_score,
					"marginal_score_uplift": marginal_uplift,
				})
	var build_uplift: int = full_score - base_score
	var counterfactual_resolution_duration_usec: int = maxi(
		Time.get_ticks_usec() - counterfactual_started_usec,
		0
	)
	var diagnostics: Dictionary = _dictionary_value(resolved, "diagnostics")
	var balance_analysis: Dictionary = {
		"schema_version": 1,
		"source": "post_shot_counterfactual",
		"mode_id": mode_id,
		"shot_id": int(ledger.get("shot_id", -1)),
		"attempt_id": int(ledger.get("attempt_id", -1)),
		"round_number": _get_ledger_round_number(ledger),
		"object_balls_pocketed": maxi(int(diagnostics.get("accepted_pocket_fact_count", 0)), 0),
		"trigger_counts": trigger_counts,
		"maximum_bank_tier": _get_maximum_bank_tier(trigger_counts),
		"combination_count": int(trigger_counts.get("combination_pot", 0)),
		"base_haul": int(base_result.get("final_haul", 0)),
		"base_mult": float(base_result.get("final_mult", 1.0)),
		"base_score_without_build": base_score,
		"build_haul_added": int(resolved.get("final_haul", 0)) - int(base_result.get("final_haul", 0)),
		"build_mult_added": float(resolved.get("mult_before_xmult", 1.0)) - float(base_result.get("mult_before_xmult", 1.0)),
		"build_xmult_product": float(resolved.get("xmult_product", 1.0)),
		"final_haul": int(resolved.get("final_haul", 0)),
		"final_mult": float(resolved.get("final_mult", 1.0)),
		"final_score": full_score,
		"build_uplift": build_uplift,
		"item_activations": item_activations,
		"item_marginals": item_marginals,
		"marginal_uplift_sum": marginal_sum,
		"interaction_surplus": build_uplift - marginal_sum,
		"counterfactual_count": counterfactual_cache.size(),
		"counterfactual_cache": counterfactual_cache.duplicate(true),
		"base_resolution_duration_usec": base_resolution_duration_usec,
		"counterfactual_resolution_duration_usec": counterfactual_resolution_duration_usec,
		"build_snapshot": build_snapshot,
		"scratch": _result_has_scratch(resolved),
		"terminal_outcome": "",
	}
	balance_analysis["analysis_duration_usec"] = maxi(
		Time.get_ticks_usec() - started_at_usec,
		0
	)
	resolved["balance_telemetry"] = balance_analysis


func _make_balance_item_activation_records(resolved: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var ordinals: Dictionary = {}
	for step_value in _array_value(resolved, "resolution_steps"):
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value as Dictionary
		if str(step.get("source_type", "")) != "modifier":
			continue
		var metadata: Dictionary = _dictionary_value(step, "metadata")
		var item_id: String = str(metadata.get("eight_ball_item_id", step.get("source_id", "")))
		var ordinal: int = int(ordinals.get(item_id, 0)) + 1
		ordinals[item_id] = ordinal
		var phase: String = str(step.get("phase", metadata.get("modifier_phase", "")))
		var applied_value: float = float(step.get("xmult_factor", 1.0)) if phase == "xmult" else (
			float(step.get("haul_delta", 0)) if phase == "add_haul" else float(step.get("mult_delta", 0.0))
		)
		var haul_before: int = int(step.get("haul_before", 0))
		var mult_before: float = float(step.get("mult_before", 1.0))
		records.append({
			"eight_ball_item_id": item_id,
			"display_name": str(step.get("display_name", item_id)),
			"tray_slot_index": int(metadata.get("slot_index", step.get("slot_index", -1))),
			"trigger_id": str(metadata.get("trigger_id", "")),
			"trigger_occurrence_id": str(metadata.get("trigger_occurrence_id", "")),
			"trigger_ball_id": int(metadata.get("trigger_ball_id", step.get("ball_id", -1))),
			"trigger_event_index": int(metadata.get("trigger_event_index", step.get("event_index", -1))),
			"modifier_phase": phase,
			"applied_value": applied_value,
			"haul_before": haul_before,
			"haul_after": int(step.get("haul_after", haul_before)),
			"mult_before": mult_before,
			"mult_after": float(step.get("mult_after", mult_before)),
			"score_preview_before": maxi(int(floor(float(maxi(haul_before, 0)) * maxf(mult_before, 0.0))), 0),
			"score_preview_after": maxi(int(step.get("score_preview_after", 0)), 0),
			"activation_ordinal": ordinal,
			"family_id": str(metadata.get("family_id", "")),
			"activation_id": str(metadata.get("activation_id", "")),
			"is_retrigger": bool(metadata.get("is_retrigger", false)),
			"retrigger_index": int(metadata.get("retrigger_index", 0)),
			"retrigger_source_item_id": str(metadata.get(
				"retrigger_source_item_id",
				""
			)),
			"retrigger_source_display_name": str(metadata.get(
				"retrigger_source_display_name",
				""
			)),
			"retrigger_source_slot_index": int(metadata.get(
				"retrigger_source_slot_index",
				-1
			)),
			"original_activation_id": str(metadata.get("original_activation_id", "")),
			"retrigger_marker_required": bool(metadata.get(
				"retrigger_marker_required",
				false
			)),
		})
	return records


func _get_build_definition_for_slot(build_snapshot: Dictionary, slot_index: int) -> Dictionary:
	var slots_value: Variant = build_snapshot.get("slots", [])
	if not slots_value is Array or slot_index < 0 or slot_index >= (slots_value as Array).size():
		return {}
	var slot_value: Variant = (slots_value as Array)[slot_index]
	if not slot_value is Dictionary:
		return {}
	return _dictionary_value(slot_value as Dictionary, "definition").duplicate(true)


func _get_maximum_bank_tier(trigger_counts: Dictionary) -> int:
	if int(trigger_counts.get("triple_bank_milestone", 0)) > 0:
		return 3
	if int(trigger_counts.get("double_bank_milestone", 0)) > 0:
		return 2
	if int(trigger_counts.get("single_bank_milestone", 0)) > 0:
		return 1
	return 0


func _get_ledger_round_number(ledger: Dictionary) -> int:
	var context: Dictionary = _dictionary_value(ledger, "context")
	return maxi(int(context.get("roguelite_round_number", context.get("round_number", 0))), 0)


func _result_has_scratch(resolved: Dictionary) -> bool:
	var diagnostics: Dictionary = _dictionary_value(resolved, "diagnostics")
	var source_counts: Dictionary = _dictionary_value(diagnostics, "source_counts")
	return int(source_counts.get("scratch", 0)) > 0


func _attach_doubloon_payout(resolved: Dictionary) -> void:
	var payout: Dictionary = DOUBLOON_PAYOUT_RESOLVER.resolve(resolved.duplicate(true))
	resolved["doubloon_payout"] = payout.duplicate(true)
	resolved["doubloon_payout_amount"] = int(payout.get("doubloons_awarded", 0))
	var diagnostics: Dictionary = _dictionary_value(resolved, "diagnostics")
	diagnostics["doubloon_payout_model"] = str(payout.get("source", ""))
	diagnostics["doubloon_payout_base_haul"] = int(payout.get("base_haul", 0))
	diagnostics["doubloon_payout_scoring_balls"] = int(
		payout.get("scoring_object_ball_count", 0)
	)
	diagnostics["doubloon_payout_derived"] = int(payout.get("doubloons_awarded", 0))
	resolved["diagnostics"] = diagnostics


func _handle_shot_lab_doubloon_payout(resolved: Dictionary, ledger: Dictionary) -> void:
	if str(ledger.get("mode_id", "")) != GAME_MODE_SCRIPT.MODE_SHOT_LAB:
		return
	var payout: Dictionary = _dictionary_value(resolved, "doubloon_payout").duplicate(true)
	var amount: int = maxi(int(payout.get("doubloons_awarded", 0)), 0)
	var application_key: String = "shot_lab|%s|payout:%s" % [
		_make_resolution_key(ledger),
		str(payout.get("source", "unknown")),
	]
	var wallet_total: int = (
		table.score_system.get_doubloons_total()
		if table != null and table.score_system != null
		else 0
	)
	var application: Dictionary = payout.duplicate(true)
	application["applied"] = false
	application["amount"] = amount
	application["application_key"] = application_key
	application["wallet_before"] = wallet_total
	application["wallet_after"] = wallet_total
	application["duplicate_suppression"] = false
	application["terminal_shot_payout"] = false
	application["shot_lab_wallet_mutation_suppressed"] = not shot_lab_apply_test_doubloon_payout
	application["reason"] = "shot_lab_wallet_mutation_suppressed"
	if not shot_lab_apply_test_doubloon_payout:
		shot_lab_wallet_mutation_suppression_count += 1
	elif shot_lab_payout_application_keys.has(application_key):
		application["reason"] = "duplicate_application"
		application["duplicate_suppression"] = true
		shot_lab_payout_duplicate_suppressions += 1
	elif table == null or table.score_system == null:
		application["reason"] = "score_system_unavailable"
	else:
		var application_value: Variant = table.score_system.apply_roguelite_shot_payout(
			payout,
			application_key
		)
		if application_value is Dictionary:
			var wallet_application: Dictionary = application_value as Dictionary
			for key_value in wallet_application.keys():
				application[key_value] = wallet_application[key_value]
			if bool(application.get("applied", false)):
				_remember_shot_lab_payout_application_key(application_key)
				shot_lab_payout_application_count += 1
		else:
			application["reason"] = "invalid_wallet_application_result"
	last_shot_lab_payout_application = application.duplicate(true)
	resolved["doubloon_payout_application"] = application.duplicate(true)
	resolved["doubloon_payout_applied"] = bool(application.get("applied", false))
	var diagnostics: Dictionary = _dictionary_value(resolved, "diagnostics")
	diagnostics["shot_lab_wallet_mutation_suppressed"] = bool(
		application.get("shot_lab_wallet_mutation_suppressed", false)
	)
	diagnostics["doubloon_payout_application_key"] = application_key
	resolved["diagnostics"] = diagnostics


func _prepare_authoritative_round_score(resolved: Dictionary, ledger: Dictionary) -> void:
	var is_roguelite_result: bool = str(ledger.get("mode_id", "")) == GAME_MODE_SCRIPT.MODE_ROGUELITE
	var round_before: int = 0
	var round_after: int = 0
	var round_quota: int = 0
	var before_snapshot: Dictionary = {}
	if table != null and table.roguelite_run_system != null:
		before_snapshot = table.roguelite_run_system.get_snapshot()
		round_before = int(before_snapshot.get("round_score", 0))
		round_after = round_before
		round_quota = int(before_snapshot.get("round_target", 0))
	var should_apply: bool = (
		is_roguelite_result
		and table != null
		and table.roguelite_run_system != null
		and bool(before_snapshot.get("round_active", false))
		and not bool(before_snapshot.get("run_failed", false))
		and not bool(before_snapshot.get("run_completed", false))
	)
	if should_apply:
		round_after = round_before + maxi(int(resolved.get("shot_score", 0)), 0)
	resolved["authoritative_score_applied_to_round"] = false
	resolved["authoritative_score_pending"] = should_apply
	resolved["round_score_before"] = round_before
	resolved["round_score_after"] = round_after
	resolved["round_quota"] = round_quota
	resolved["round_score_delta_pending"] = round_after - round_before
	resolved["round_score_delta_applied"] = 0
	var diagnostics: Dictionary = _dictionary_value(resolved, "diagnostics")
	diagnostics["authoritative_score_applied_to_round"] = false
	diagnostics["authoritative_score_pending"] = should_apply
	resolved["diagnostics"] = diagnostics


func _commit_authoritative_round_score(resolved: Dictionary, ledger: Dictionary) -> void:
	if (
		str(ledger.get("mode_id", "")) != GAME_MODE_SCRIPT.MODE_ROGUELITE
		or not bool(resolved.get("authoritative_score_pending", false))
		or table == null
		or table.roguelite_run_system == null
	):
		return
	var transaction: Dictionary = table.commit_roguelite_completed_shot(resolved, ledger)
	var accepted: bool = bool(transaction.get("accepted", false))
	var transaction_snapshot: Dictionary = _dictionary_value(transaction, "snapshot")
	resolved["round_score_before"] = int(transaction.get("score_before", resolved.get("round_score_before", 0)))
	resolved["round_score_after"] = int(transaction.get("score_after", resolved.get("round_score_before", 0)))
	resolved["round_quota"] = int(transaction.get("round_quota", resolved.get("round_quota", 0)))
	resolved["round_score_delta_applied"] = int(transaction.get("score_delta", 0)) if accepted else 0
	resolved["doubloon_payout"] = _dictionary_value(transaction, "doubloon_payout").duplicate(true)
	resolved["doubloon_payout_application"] = _dictionary_value(
		transaction,
		"doubloon_payout_application"
	).duplicate(true)
	resolved["doubloon_payout_applied"] = bool(transaction.get(
		"doubloon_payout_applied",
		false
	))
	resolved["terminal_shot_payout"] = bool(transaction.get("terminal_shot_payout", false))
	resolved["round_score_delta_pending"] = 0
	resolved["authoritative_score_pending"] = false
	resolved["authoritative_score_applied_to_round"] = accepted
	resolved["shot_transaction_accepted"] = accepted
	resolved["shot_transaction_key"] = str(transaction.get("transaction_key", ""))
	resolved["shot_transaction_outcome"] = str(transaction.get("outcome", "rejected"))
	resolved["shot_transaction_failure_reason"] = str(transaction.get("failure_reason", ""))
	resolved["hull_before"] = int(transaction.get("hull_before", transaction_snapshot.get("hull", 0)))
	resolved["hull_after"] = int(transaction.get("hull_after", transaction_snapshot.get("hull", 0)))
	resolved["hull_damage_applied"] = maxi(
		int(resolved["hull_before"]) - int(resolved["hull_after"]),
		0
	)
	resolved["shots_before"] = int(transaction.get("shots_before", transaction_snapshot.get("shots_left", 0)))
	resolved["shots_after"] = int(transaction.get("shots_after", transaction_snapshot.get("shots_left", 0)))
	resolved["scoreable_ball_count_after"] = int(transaction.get("scoreable_ball_count", 0))
	var balance_analysis: Dictionary = _dictionary_value(resolved, "balance_telemetry")
	if not balance_analysis.is_empty():
		balance_analysis["shots_remaining_before"] = int(transaction.get("shots_before", 0))
		balance_analysis["shots_remaining_after"] = int(transaction.get("shots_after", 0))
		balance_analysis["hull_before"] = int(transaction.get("hull_before", 0))
		balance_analysis["hull_after"] = int(transaction.get("hull_after", 0))
		balance_analysis["round_quota"] = int(transaction.get("round_quota", 0))
		balance_analysis["round_score_before"] = int(transaction.get("score_before", 0))
		balance_analysis["round_score_after"] = int(transaction.get("score_after", 0))
		balance_analysis["terminal_outcome"] = str(transaction.get("outcome", ""))
		balance_analysis["failure_reason"] = str(transaction.get("failure_reason", ""))
		balance_analysis["doubloons_earned_from_base_haul"] = int(
			_dictionary_value(transaction, "doubloon_payout").get("doubloons_awarded", 0)
		)
		resolved["balance_telemetry"] = balance_analysis
	var transaction_summary: Dictionary = transaction.duplicate(true)
	transaction_summary.erase("snapshot")
	resolved["shot_transaction"] = transaction_summary
	var diagnostics: Dictionary = _dictionary_value(resolved, "diagnostics")
	diagnostics["authoritative_score_pending"] = false
	diagnostics["authoritative_score_applied_to_round"] = accepted
	diagnostics["shot_transaction_accepted"] = accepted
	diagnostics["shot_transaction_key"] = str(transaction.get("transaction_key", ""))
	diagnostics["shot_transaction_outcome"] = str(transaction.get("outcome", "rejected"))
	diagnostics["shot_transaction_rejection_reason"] = str(transaction.get("rejection_reason", ""))
	diagnostics["doubloon_wallet_before"] = int(transaction.get("doubloon_wallet_before", 0))
	diagnostics["doubloon_wallet_after"] = int(transaction.get("doubloon_wallet_after", 0))
	diagnostics["doubloon_payout_applied"] = bool(transaction.get(
		"doubloon_payout_applied",
		false
	))
	diagnostics["doubloon_payout_application_key"] = str(transaction.get(
		"doubloon_payout_application_key",
		""
	))
	diagnostics["terminal_shot_payout"] = bool(transaction.get(
		"terminal_shot_payout",
		false
	))
	diagnostics["hull_before"] = int(resolved["hull_before"])
	diagnostics["hull_after"] = int(resolved["hull_after"])
	diagnostics["shots_before"] = int(resolved["shots_before"])
	diagnostics["shots_after"] = int(resolved["shots_after"])
	resolved["diagnostics"] = diagnostics
	if accepted:
		quota_application_count += 1
	elif bool(transaction.get("duplicate", false)):
		quota_application_duplicate_suppressions += 1


func _result_matches_ledger(result: Dictionary, ledger: Dictionary) -> bool:
	if result.is_empty() or ledger.is_empty():
		return false
	return (
		str(result.get("run_generation", "")) == str(ledger.get("run_generation", ""))
		and str(result.get("mode_id", "")) == str(ledger.get("mode_id", ""))
		and int(result.get("shot_id", -1)) == int(ledger.get("shot_id", -2))
		and int(result.get("attempt_id", -1)) == int(ledger.get("attempt_id", -2))
	)


func _make_resolution_key(ledger: Dictionary) -> String:
	return "%s|%s|%d|%d" % [
		str(ledger.get("run_generation", "")),
		str(ledger.get("mode_id", "")),
		int(ledger.get("shot_id", -1)),
		int(ledger.get("attempt_id", -1)),
	]


func _remember_resolution_key(resolution_key: String) -> void:
	if resolution_key.is_empty() or recent_resolution_keys.has(resolution_key):
		return
	recent_resolution_keys[resolution_key] = true
	recent_resolution_key_order.append(resolution_key)
	while recent_resolution_key_order.size() > MAX_RECENT_RESOLUTION_KEYS:
		var expired_key: String = recent_resolution_key_order.pop_front()
		recent_resolution_keys.erase(expired_key)


func _remember_shot_lab_payout_application_key(application_key: String) -> void:
	if application_key.is_empty() or shot_lab_payout_application_keys.has(application_key):
		return
	shot_lab_payout_application_keys[application_key] = true
	shot_lab_payout_application_key_order.append(application_key)
	while shot_lab_payout_application_key_order.size() > MAX_RECENT_RESOLUTION_KEYS:
		var expired_key: String = shot_lab_payout_application_key_order.pop_front()
		shot_lab_payout_application_keys.erase(expired_key)


func _restore_shot_lab_payout_application_keys(state: Dictionary) -> void:
	shot_lab_payout_application_keys.clear()
	shot_lab_payout_application_key_order.clear()
	var order_value: Variant = state.get("shot_lab_payout_application_key_order", [])
	if not order_value is Array:
		return
	for key_value in order_value:
		var application_key: String = str(key_value)
		if application_key.is_empty() or shot_lab_payout_application_keys.has(application_key):
			continue
		shot_lab_payout_application_keys[application_key] = true
		shot_lab_payout_application_key_order.append(application_key)


func _make_tap_parity_snapshot(parity: Dictionary) -> Dictionary:
	var predicted_value: Variant = parity.get("predicted_source_counts", null)
	var authoritative_value: Variant = parity.get("authoritative_source_counts", null)
	if not predicted_value is Dictionary or not authoritative_value is Dictionary:
		return {
			"available": false,
			"matches": false,
			"status": str(parity.get("status", "NOT RUN")),
		}
	var predicted: Dictionary = predicted_value as Dictionary
	var authoritative: Dictionary = authoritative_value as Dictionary
	var predicted_cue_recontacts: int = _get_tap_source_count(
		predicted,
		RogueliteScoreResolver.SOURCE_BASE_CUE_RECONTACT,
		"cue_recontact_milestone"
	)
	var authoritative_cue_recontacts: int = _get_tap_source_count(
		authoritative,
		RogueliteScoreResolver.SOURCE_BASE_CUE_RECONTACT,
		"cue_recontact_milestone"
	)
	var predicted_object_taps: int = _get_tap_source_count(
		predicted,
		RogueliteScoreResolver.SOURCE_BASE_OBJECT_BALL_TAP,
		"object_ball_tap_milestone"
	)
	var authoritative_object_taps: int = _get_tap_source_count(
		authoritative,
		RogueliteScoreResolver.SOURCE_BASE_OBJECT_BALL_TAP,
		"object_ball_tap_milestone"
	)
	return {
		"available": true,
		"matches": (
			predicted_cue_recontacts == authoritative_cue_recontacts
			and predicted_object_taps == authoritative_object_taps
		),
		"status": str(parity.get("status", "NOT RUN")),
		"predicted_cue_recontact_milestones": predicted_cue_recontacts,
		"authoritative_cue_recontact_milestones": authoritative_cue_recontacts,
		"predicted_object_ball_tap_milestones": predicted_object_taps,
		"authoritative_object_ball_tap_milestones": authoritative_object_taps,
	}


func _get_tap_source_count(
	source_counts: Dictionary,
	base_source_id: String,
	trigger_id: String
) -> int:
	if source_counts.has(base_source_id):
		return maxi(int(source_counts.get(base_source_id, 0)), 0)
	return maxi(int(source_counts.get(trigger_id, 0)), 0)


func _run_self_test_component(
	component_name: String,
	result_value: Variant,
	expected_count: int
) -> Dictionary:
	if result_value is Dictionary:
		return (result_value as Dictionary).duplicate(true)
	var failure: Dictionary = {
		"name": "%s invocation" % component_name,
		"passed": false,
		"expected": "Dictionary",
		"actual": typeof(result_value),
	}
	return {
		"status": "FAIL",
		"timestamp": Time.get_datetime_string_from_system(),
		"total": expected_count,
		"passed": 0,
		"failed": expected_count,
		"cases": [failure.duplicate(true)],
		"failures": [failure.duplicate(true)],
	}


func _emit_state() -> void:
	state_changed.emit(get_snapshot())


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []
