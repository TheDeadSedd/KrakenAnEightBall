extends RefCounted
class_name RogueliteBalanceTelemetry

# Value-only current-run evidence for future balance analysis and report UI.
# Callers supply frozen authoritative snapshots; this collector never queries
# scenes, reruns scoring, formats reports, or performs per-frame work.

const TELEMETRY_SCHEMA_VERSION := 1
const REWIND_STATE_VERSION := 1
const SHOT_RECORD_SCHEMA_VERSION := 1
const OFFER_RECORD_SCHEMA_VERSION := 1
const ROUND_RECORD_SCHEMA_VERSION := 1
const REPORT_SOURCE_SCHEMA_VERSION := 1

const MODE_ROGUELITE := "roguelite"
const SOURCE_AUTHORITATIVE := "authoritative"

const TRIGGER_DIRECT_POT := "direct_pot"
const TRIGGER_CUE_RECONTACT := "cue_recontact_milestone"
const TRIGGER_OBJECT_BALL_TAP := "object_ball_tap_milestone"
const FAMILY_DIRECT_POT := "direct_pot"
const EFFECT_KIND_RETRIGGER_FAMILY := "retrigger_family"
const DEAD_RECKONING_ITEM_ID := "direct_pot_legendary_dead_reckoning"
const RATTLE_ITEM_ID := "tap_stateful_xmult_rattle_of_the_deep"
const ONE_TWO_PUNCH_ITEM_ID := "tap_hybrid_xmult_one_two_punch"
const AFTERSHOCK_ITEM_ID := "tap_ordinal_xmult_aftershock"
const ECHO_CHAMBER_ITEM_ID := "tap_legendary_retrigger_echo_chamber"
const REGULAR_DOUBLE_TAP_ITEM_IDS: Array[String] = [
	"double_tap_haul_second_bite",
	"double_tap_mult_echoing_toll",
	"double_tap_xmult_revenant_rhythm",
]
const REGULAR_BALL_TAP_ITEM_IDS: Array[String] = [
	"ball_tap_haul_knock_on_plunder",
	"ball_tap_mult_crowded_wake",
	"ball_tap_xmult_carom_current",
]
const DEAD_RECKONING_SUPPORT_ITEM_IDS: Array[String] = [
	"direct_pot_haul_clean_plunder",
	"direct_pot_mult_true_bearing",
	"direct_pot_xmult_unerring_course",
]

const MAX_SHOT_RECORDS := 512
const MAX_OFFER_RECORDS := 64
const MAX_ROUND_RECORDS := 32
const MAX_ABANDONED_ATTEMPTS := 128
const MAX_RECENT_REJECTIONS := 64
const MAX_TAP_TARGET_REFERENCES_PER_SHOT := 64
const MAX_PHASE_5C_ENGINE_EVENTS_PER_SHOT := 64
const MAX_PHASE_5C_STATE_MUTATIONS_PER_SHOT := 16
const MAX_PHASE_5C_STATE_ITEMS := 5
const MAX_PHASE_5C_VALUE_KEYS := 24
const MAX_PHASE_5C_HISTORY_RECORDS := 120
const MAX_VALUE_DEPTH := 64

const OUTCOME_UNKNOWN := "unknown"
static var _session_last_finalized_report_source: Dictionary = {}
var active_run := false
var run_finalized := false
var active_run_generation := -1
var active_mode_id := ""
var run_started_at_unix := 0
var run_metadata: Dictionary = {}
var initial_run_snapshot: Dictionary = {}
var current_run_snapshot: Dictionary = {}
var initial_build_snapshot: Dictionary = {}
var current_build_snapshot: Dictionary = {}

var shot_records: Array[Dictionary] = []
var offer_records: Array[Dictionary] = []
var round_records: Array[Dictionary] = []
var recorded_shot_keys: Dictionary = {}
var offer_record_index_by_key: Dictionary = {}
var round_record_index_by_key: Dictionary = {}
var finalized_round_keys: Dictionary = {}
var active_round_key := ""
var unkeyed_offer_serial := 0
var run_accumulators: Dictionary = {}

var last_finalized_report_source: Dictionary = {}
var last_abandoned_run: Dictionary = {}
var abandoned_attempts: Array[Dictionary] = []
var abandoned_attempt_keys: Dictionary = {}

var session_fresh_run_count := 0
var session_finalization_count := 0
var session_abandoned_run_count := 0
var accepted_shot_count := 0
var accepted_offer_count := 0
var resolved_offer_count := 0
var accepted_round_start_count := 0
var accepted_round_finalization_count := 0
var duplicate_shot_suppressions := 0
var duplicate_offer_suppressions := 0
var duplicate_offer_resolution_suppressions := 0
var duplicate_round_start_suppressions := 0
var duplicate_round_finalization_suppressions := 0
var duplicate_run_finalization_suppressions := 0
var rejected_record_count := 0
var rejected_records_by_reason: Dictionary = {}
var recent_rejections: Array[Dictionary] = []
var value_reference_rejections := 0
var shot_history_overflow_count := 0
var offer_history_overflow_count := 0
var round_history_overflow_count := 0
var rewind_restore_count := 0
var abandoned_attempt_count := 0
var auto_started_round_count := 0
var auto_finalized_round_count := 0
var unfinalized_round_transition_count := 0
var missing_base_score_result_count := 0
var incomplete_counterfactual_shot_count := 0
var incomplete_eligible_pool_count := 0
var last_operation := ""
var last_error := ""


func _init() -> void:
	last_finalized_report_source = _session_last_finalized_report_source.duplicate(true)


func begin_fresh_run(
	run_generation_value: int,
	mode_id: String,
	run_snapshot: Dictionary = {},
	build_snapshot: Dictionary = {},
	metadata: Dictionary = {}
) -> Dictionary:
	if mode_id != MODE_ROGUELITE:
		return _reject("begin_fresh_run", "mode_not_roguelite", {
			"run_generation": run_generation_value,
			"mode_id": mode_id,
		})
	if run_generation_value < 0:
		return _reject("begin_fresh_run", "invalid_run_generation", {
			"run_generation": run_generation_value,
		})
	if not _inputs_are_value_only([run_snapshot, build_snapshot, metadata]):
		value_reference_rejections += 1
		return _reject("begin_fresh_run", "non_value_input")

	if active_run and not run_finalized:
		_abandon_active_run_internal("fresh_run_replaced_active")
	_reset_current_run_state()
	_reset_current_run_diagnostics()

	active_run = true
	run_finalized = false
	active_run_generation = run_generation_value
	active_mode_id = mode_id
	run_started_at_unix = _timestamp_from_context(metadata)
	run_metadata = metadata.duplicate(true)
	initial_run_snapshot = _compact_run_snapshot(run_snapshot)
	current_run_snapshot = initial_run_snapshot.duplicate(true)
	initial_build_snapshot = _compact_build_snapshot(build_snapshot)
	current_build_snapshot = initial_build_snapshot.duplicate(true)
	run_accumulators = _make_empty_run_accumulators()
	session_fresh_run_count += 1
	last_operation = "begin_fresh_run"
	last_error = ""
	return {
		"accepted": true,
		"duplicate": false,
		"run_generation": active_run_generation,
		"mode_id": active_mode_id,
	}


func sync_current_snapshots(
	run_snapshot: Dictionary = {},
	build_snapshot: Dictionary = {}
) -> Dictionary:
	if not active_run:
		return _reject("sync_current_snapshots", "no_active_run")
	if not _inputs_are_value_only([run_snapshot, build_snapshot]):
		value_reference_rejections += 1
		return _reject("sync_current_snapshots", "non_value_input")
	if not run_snapshot.is_empty():
		current_run_snapshot = _compact_run_snapshot(run_snapshot)
	if not build_snapshot.is_empty():
		current_build_snapshot = _compact_build_snapshot(build_snapshot)
	last_operation = "sync_current_snapshots"
	last_error = ""
	return {"accepted": true, "duplicate": false}


func record_round_started(
	run_snapshot: Dictionary,
	build_snapshot: Dictionary,
	balls_spawned: int = -1,
	context: Dictionary = {}
) -> Dictionary:
	if not active_run or run_finalized:
		return _reject("record_round_started", "no_mutable_run")
	if not _inputs_are_value_only([run_snapshot, build_snapshot, context]):
		value_reference_rejections += 1
		return _reject("record_round_started", "non_value_input")
	return _record_round_started_internal(run_snapshot, build_snapshot, balls_spawned, context)


func record_authoritative_shot(
	completed_ledger: Dictionary,
	score_result: Dictionary,
	base_score_result: Dictionary,
	run_snapshot_before: Dictionary,
	run_snapshot_after: Dictionary,
	build_snapshot: Dictionary,
	item_counterfactual_results: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if not active_run or run_finalized:
		return _reject("record_authoritative_shot", "no_mutable_run")
	if shot_records.size() >= MAX_SHOT_RECORDS:
		shot_history_overflow_count += 1
		return _reject("record_authoritative_shot", "shot_history_capacity_reached")
	if not _inputs_are_value_only([
		completed_ledger,
		score_result,
		base_score_result,
		run_snapshot_before,
		run_snapshot_after,
		build_snapshot,
		item_counterfactual_results,
		context,
	]):
		value_reference_rejections += 1
		return _reject("record_authoritative_shot", "non_value_input")
	var telemetry_started_usec: int = Time.get_ticks_usec()

	var source: String = str(completed_ledger.get("source", ""))
	var mode_id: String = str(completed_ledger.get("mode_id", ""))
	var run_generation: int = int(completed_ledger.get("run_generation", -1))
	var shot_id: int = int(completed_ledger.get("shot_id", -1))
	var attempt_id: int = int(completed_ledger.get("attempt_id", -1))
	if source != SOURCE_AUTHORITATIVE:
		return _reject("record_authoritative_shot", "source_not_authoritative", {
			"shot_id": shot_id,
			"attempt_id": attempt_id,
		})
	if mode_id != MODE_ROGUELITE:
		return _reject("record_authoritative_shot", "mode_not_roguelite", {
			"shot_id": shot_id,
			"attempt_id": attempt_id,
			"mode_id": mode_id,
		})
	if run_generation != active_run_generation:
		return _reject("record_authoritative_shot", "run_generation_mismatch", {
			"run_generation": run_generation,
			"shot_id": shot_id,
			"attempt_id": attempt_id,
		})
	if shot_id < 0 or attempt_id < 0:
		return _reject("record_authoritative_shot", "invalid_shot_identity", {
			"shot_id": shot_id,
			"attempt_id": attempt_id,
		})
	if not _score_result_matches_ledger(score_result, completed_ledger):
		return _reject("record_authoritative_shot", "score_ledger_identity_mismatch", {
			"shot_id": shot_id,
			"attempt_id": attempt_id,
		})
	if (
		not base_score_result.is_empty()
		and not _score_result_matches_ledger(base_score_result, completed_ledger)
	):
		return _reject("record_authoritative_shot", "base_score_ledger_identity_mismatch", {
			"shot_id": shot_id,
			"attempt_id": attempt_id,
		})
	var transaction_accepted: bool = bool(score_result.get(
		"shot_transaction_accepted",
		score_result.get("authoritative_score_applied_to_round", false)
	))
	if not transaction_accepted:
		return _reject("record_authoritative_shot", "shot_not_authoritatively_committed", {
			"shot_id": shot_id,
			"attempt_id": attempt_id,
		})

	var shot_key: String = _make_shot_key(run_generation, attempt_id)
	if recorded_shot_keys.has(shot_key):
		duplicate_shot_suppressions += 1
		return _duplicate_result("record_authoritative_shot", shot_key)

	var round_number: int = maxi(int(completed_ledger.get(
		"round_number",
		run_snapshot_before.get("round_number", 1)
	)), 1)
	var build_evaluation: Dictionary = _dictionary_value(
		score_result,
		"eight_ball_build_evaluation"
	)
	var trigger_occurrences: Array[Dictionary] = _compact_trigger_occurrences(
		_array_value(build_evaluation, "trigger_occurrences")
	)
	var trigger_counts: Dictionary = _count_trigger_occurrences(trigger_occurrences)
	var item_activations: Array[Dictionary] = _compact_item_activations(score_result)
	var base_available: bool = not base_score_result.is_empty()
	if not base_available:
		missing_base_score_result_count += 1
	var final_score: int = maxi(int(score_result.get("shot_score", 0)), 0)
	var base_score: int = maxi(int(base_score_result.get("shot_score", 0)), 0) if base_available else 0
	var derived: Dictionary = _dictionary_value(completed_ledger, "derived")
	var tap_summary: Dictionary = _summarize_tap_shot(
		derived,
		score_result,
		trigger_counts
	)
	trigger_counts[TRIGGER_CUE_RECONTACT] = maxi(
		int(trigger_counts.get(TRIGGER_CUE_RECONTACT, 0)),
		int(tap_summary.get("cue_recontact_milestones", 0))
	)
	trigger_counts[TRIGGER_OBJECT_BALL_TAP] = maxi(
		int(trigger_counts.get(TRIGGER_OBJECT_BALL_TAP, 0)),
		int(tap_summary.get("ball_tap_milestones", 0))
	)
	var object_balls_pocketed: int = _object_ball_pocket_count(derived)
	var maximum_bank_tier: int = _maximum_bank_tier(trigger_occurrences, derived)
	var build_haul_added: int = int(round(float(build_evaluation.get("add_haul_total", 0.0))))
	var build_mult_added: float = float(build_evaluation.get("add_mult_total", 0.0))
	var build_xmult_product: float = float(build_evaluation.get("xmult_product", 1.0))
	var payout: Dictionary = _dictionary_value(score_result, "doubloon_payout")
	var compact_build: Dictionary = _compact_build_snapshot(build_snapshot)
	var dead_reckoning_summary: Dictionary = _summarize_dead_reckoning_shot(
		trigger_counts,
		item_activations,
		compact_build
	)
	var compact_counterfactuals: Dictionary = _compact_item_counterfactuals(
		item_counterfactual_results,
		final_score
	)
	var phase_5c_tap_items: Dictionary = _summarize_phase_5c_tap_items(
		build_evaluation,
		score_result,
		compact_build,
		trigger_occurrences,
		item_activations,
		tap_summary,
		compact_counterfactuals
	)
	var owned_item_count: int = int(compact_build.get("occupied_slots", 0))
	var counterfactuals_complete: bool = (
		owned_item_count <= 0
		or compact_counterfactuals.size() >= owned_item_count
	)
	if not counterfactuals_complete:
		incomplete_counterfactual_shot_count += 1
	var terminal_outcome: String = str(score_result.get(
		"shot_transaction_outcome",
		_dictionary_value(score_result, "shot_transaction").get("outcome", "")
	))
	var record: Dictionary = {
		"schema_version": SHOT_RECORD_SCHEMA_VERSION,
		"source": SOURCE_AUTHORITATIVE,
		"mode_id": MODE_ROGUELITE,
		"shot_key": shot_key,
		"run_generation": run_generation,
		"shot_id": shot_id,
		"attempt_id": attempt_id,
		"round_number": round_number,
		"round_index": int(completed_ledger.get("round_index", round_number - 1)),
		"shots_remaining_before": int(score_result.get(
			"shots_before",
			run_snapshot_before.get("shots_left", 0)
		)),
		"shots_remaining_after": int(score_result.get(
			"shots_after",
			run_snapshot_after.get("shots_left", 0)
		)),
		"hull_before": int(score_result.get(
			"hull_before",
			run_snapshot_before.get("hull", 0)
		)),
		"hull_after": int(score_result.get(
			"hull_after",
			run_snapshot_after.get("hull", 0)
		)),
		"round_score_before": int(score_result.get(
			"round_score_before",
			run_snapshot_before.get("round_score", 0)
		)),
		"round_score_after": int(score_result.get(
			"round_score_after",
			run_snapshot_after.get("round_score", 0)
		)),
		"round_quota": int(score_result.get(
			"round_quota",
			run_snapshot_after.get("round_target", 0)
		)),
		"object_balls_pocketed": object_balls_pocketed,
		"trigger_counts": trigger_counts,
		"trigger_occurrences": trigger_occurrences,
		"maximum_bank_tier": maximum_bank_tier,
		"combination_count": int(trigger_counts.get("combination_pot", 0)),
		"tap_metrics": tap_summary,
		"phase_5c_tap_items": phase_5c_tap_items,
		"cue_recontact_milestone_count": int(tap_summary.get(
			"cue_recontact_milestones",
			0
		)),
		"maximum_cue_strikes_against_one_scoring_ball": int(tap_summary.get(
			"maximum_cue_strikes_against_one_scoring_ball",
			0
		)),
		"ball_tap_milestone_count": int(tap_summary.get("ball_tap_milestones", 0)),
		"repeated_ball_tap_contacts_ignored": int(tap_summary.get(
			"repeated_ball_tap_contacts_ignored",
			0
		)),
		"ambiguous_tap_contacts_rejected": int(tap_summary.get(
			"ambiguous_tap_contacts_rejected",
			0
		)),
		"tap_direct_pot_disqualifications": int(tap_summary.get(
			"tap_direct_pot_disqualifications",
			0
		)),
		"base_haul": maxi(int(base_score_result.get(
			"final_haul",
			score_result.get("base_haul", 0)
		)), 0),
		"base_mult": maxf(float(base_score_result.get(
			"final_mult",
			score_result.get("base_mult", 1.0)
		)), 0.0),
		"base_score_without_build_available": base_available,
		"base_score_without_build": base_score,
		"build_haul_added": build_haul_added,
		"build_mult_added": build_mult_added,
		"build_xmult_product": build_xmult_product,
		"final_haul": maxi(int(score_result.get("final_haul", 0)), 0),
		"final_mult": maxf(float(score_result.get("final_mult", 1.0)), 0.0),
		"final_score": final_score,
		"item_activations": item_activations,
		"dead_reckoning": dead_reckoning_summary,
		"item_counterfactual_scores": compact_counterfactuals,
		"counterfactuals_complete": counterfactuals_complete,
		"build_snapshot": compact_build,
		"scratch": bool(derived.get("scratch_occurred", false)),
		"doubloons_from_base_haul": maxi(int(payout.get("doubloons_awarded", 0)), 0),
		"global_excitement": maxf(float(context.get("global_excitement", 0.0)), 0.0),
		"base_resolution_duration_usec": maxi(int(context.get(
			"base_resolution_duration_usec",
			0
		)), 0),
		"counterfactual_resolution_duration_usec": maxi(int(context.get(
			"counterfactual_resolution_duration_usec",
			0
		)), 0),
		"terminal_outcome": terminal_outcome,
		"failure_reason": str(score_result.get("shot_transaction_failure_reason", "")),
		"recorded_at_usec": Time.get_ticks_usec(),
	}
	record["telemetry_record_duration_usec"] = maxi(
		Time.get_ticks_usec() - telemetry_started_usec,
		0
	)

	shot_records.append(record)
	recorded_shot_keys[shot_key] = true
	accepted_shot_count += 1
	current_run_snapshot = _compact_run_snapshot(run_snapshot_after)
	current_build_snapshot = _compact_build_snapshot(build_snapshot)
	_update_run_accumulators(record)
	_update_round_with_shot(record, run_snapshot_before, build_snapshot)
	last_operation = "record_authoritative_shot"
	last_error = ""
	return {
		"accepted": true,
		"duplicate": false,
		"shot_key": shot_key,
		"record": record.duplicate(true),
	}


func record_offer_generated(
	reward_snapshot: Dictionary,
	eligible_pool: Array = [],
	tray_before_snapshot: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if not active_run or run_finalized:
		return _reject("record_offer_generated", "no_mutable_run")
	if offer_records.size() >= MAX_OFFER_RECORDS:
		offer_history_overflow_count += 1
		return _reject("record_offer_generated", "offer_history_capacity_reached")
	if not _inputs_are_value_only([
		reward_snapshot,
		eligible_pool,
		tray_before_snapshot,
		context,
	]):
		value_reference_rejections += 1
		return _reject("record_offer_generated", "non_value_input")

	var offer_generation: int = maxi(int(reward_snapshot.get(
		"offer_generation",
		_dictionary_value(reward_snapshot, "offer_diagnostics").get("offer_generation", 0)
	)), 0)
	var offer_key: String = ""
	if offer_generation <= 0:
		unkeyed_offer_serial += 1
		offer_key = _make_unkeyed_offer_key(active_run_generation, unkeyed_offer_serial)
	else:
		offer_key = _make_offer_key(active_run_generation, offer_generation)
	var round_number: int = maxi(int(reward_snapshot.get(
		"active_offer_round",
		context.get("round_number", 0)
	)), 0)
	if offer_record_index_by_key.has(offer_key):
		duplicate_offer_suppressions += 1
		return _duplicate_result("record_offer_generated", offer_key)

	var offered_definitions: Array[Dictionary] = _compact_offer_definitions(
		_array_value(reward_snapshot, "offers")
	)
	var offered_ids: Array[String] = _item_ids_from_definitions(offered_definitions)
	if offered_ids.is_empty():
		offered_ids = _string_array(reward_snapshot.get("active_offer_ids", []))
	var eligible_definitions: Array[Dictionary] = _compact_offer_definitions(eligible_pool)
	var offer_diagnostics: Dictionary = _dictionary_value(reward_snapshot, "offer_diagnostics")
	var eligible_pool_complete: bool = bool(context.get(
		"eligible_pool_complete",
		not eligible_definitions.is_empty()
	))
	if not eligible_pool_complete:
		incomplete_eligible_pool_count += 1
	var tray_before: Dictionary = _compact_build_snapshot(tray_before_snapshot)
	var record: Dictionary = {
		"schema_version": OFFER_RECORD_SCHEMA_VERSION,
		"offer_key": offer_key,
		"run_generation": active_run_generation,
		"offer_generation": offer_generation,
		"round_after": round_number,
		"eligible_pool": eligible_definitions,
		"eligible_pool_complete": eligible_pool_complete,
		"eligible_pool_count": int(offer_diagnostics.get(
			"eligible_pool_count",
			eligible_definitions.size()
		)),
		"offered_item_ids": offered_ids,
		"offers": offered_definitions,
		"selection_policy": str(_dictionary_value(
			offer_diagnostics,
			"details"
		).get("selection_policy", "")),
		"run_reward_seed": int(offer_diagnostics.get("run_reward_seed", 0)),
		"rng_state": int(offer_diagnostics.get("rng_state", 0)),
		"weighted_rolls": _dictionary_array(offer_diagnostics.get("weighted_rolls", [])),
		"excluded_owned_item_ids": _string_array(offer_diagnostics.get("exclusions", [])),
		"tray_before": tray_before,
		"tray_after": tray_before.duplicate(true),
		"full_tray": int(tray_before.get("occupied_slots", 0)) >= int(
			tray_before.get("tray_capacity", 5)
		),
		"selected_item_id": "",
		"selected_tray_slot": -1,
		"skipped": false,
		"replacement_slot": -1,
		"replaced_item_id": "",
		"resolved": false,
		"resolution_reason": "",
		"generated_at_unix": _timestamp_from_context(context),
		"resolved_at_unix": 0,
	}
	offer_record_index_by_key[offer_key] = offer_records.size()
	offer_records.append(record)
	accepted_offer_count += 1
	last_operation = "record_offer_generated"
	last_error = ""
	return {
		"accepted": true,
		"duplicate": false,
		"offer_key": offer_key,
		"record": record.duplicate(true),
	}


func record_offer_selected(
	selection_result: Dictionary,
	tray_after_snapshot: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if not active_run or run_finalized:
		return _reject("record_offer_selected", "no_mutable_run")
	if not _inputs_are_value_only([selection_result, tray_after_snapshot, context]):
		value_reference_rejections += 1
		return _reject("record_offer_selected", "non_value_input")
	if not bool(selection_result.get("completed", false)):
		return _reject("record_offer_selected", "selection_not_completed")
	var index: int = _find_offer_record_index(selection_result, context)
	if index < 0:
		return _reject("record_offer_selected", "offer_record_not_found")
	var record: Dictionary = offer_records[index]
	if bool(record.get("resolved", false)):
		duplicate_offer_resolution_suppressions += 1
		return _duplicate_result("record_offer_selected", str(record.get("offer_key", "")))

	var reward: Dictionary = _dictionary_value(selection_result, "reward")
	var selected_item_id: String = _item_id(reward)
	if selected_item_id.is_empty():
		selected_item_id = str(selection_result.get("selected_item_id", ""))
	if selected_item_id.is_empty() or not _string_array(
		record.get("offered_item_ids", [])
	).has(selected_item_id):
		return _reject("record_offer_selected", "selected_item_not_offered", {
			"offer_generation": int(record.get("offer_generation", 0)),
		})

	var build_result: Dictionary = _dictionary_value(selection_result, "build_result")
	var tray_after: Dictionary = _compact_build_snapshot(tray_after_snapshot)
	if tray_after.is_empty():
		tray_after = _compact_build_snapshot(_dictionary_value(
			selection_result,
			"build_snapshot"
		))
	record["selected_item_id"] = selected_item_id
	record["selected_tray_slot"] = int(build_result.get("tray_slot_index", -1))
	record["skipped"] = false
	record["replacement_slot"] = int(build_result.get("tray_slot_index", -1)) if build_result.has(
		"old_eight_ball_item_id"
	) else -1
	record["replaced_item_id"] = str(build_result.get("old_eight_ball_item_id", ""))
	record["tray_after"] = tray_after
	record["resolved"] = true
	record["resolution_reason"] = str(context.get("reason", "selected"))
	record["resolved_at_unix"] = _timestamp_from_context(context)
	offer_records[index] = record
	resolved_offer_count += 1
	if not tray_after.is_empty():
		current_build_snapshot = tray_after.duplicate(true)
	last_operation = "record_offer_selected"
	last_error = ""
	return {
		"accepted": true,
		"duplicate": false,
		"offer_key": str(record.get("offer_key", "")),
		"record": record.duplicate(true),
	}


func record_offer_skipped(
	skip_result: Dictionary,
	tray_after_snapshot: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	if not active_run or run_finalized:
		return _reject("record_offer_skipped", "no_mutable_run")
	if not _inputs_are_value_only([skip_result, tray_after_snapshot, context]):
		value_reference_rejections += 1
		return _reject("record_offer_skipped", "non_value_input")
	if not bool(skip_result.get("completed", false)) or not bool(skip_result.get("skipped", false)):
		return _reject("record_offer_skipped", "skip_not_completed")
	var skip_snapshot: Dictionary = _dictionary_value(skip_result, "skip")
	var index: int = _find_offer_record_index(skip_snapshot, context)
	if index < 0:
		return _reject("record_offer_skipped", "offer_record_not_found")
	var record: Dictionary = offer_records[index]
	if bool(record.get("resolved", false)):
		duplicate_offer_resolution_suppressions += 1
		return _duplicate_result("record_offer_skipped", str(record.get("offer_key", "")))

	var tray_after: Dictionary = _compact_build_snapshot(tray_after_snapshot)
	record["selected_item_id"] = ""
	record["skipped"] = true
	record["replacement_slot"] = -1
	record["replaced_item_id"] = ""
	record["tray_after"] = (
		tray_after
		if not tray_after.is_empty()
		else _dictionary_value(record, "tray_before").duplicate(true)
	)
	record["resolved"] = true
	record["resolution_reason"] = str(skip_snapshot.get(
		"reason",
		context.get("reason", "skipped")
	))
	record["resolved_at_unix"] = _timestamp_from_context(context)
	offer_records[index] = record
	resolved_offer_count += 1
	if not tray_after.is_empty():
		current_build_snapshot = tray_after.duplicate(true)
	last_operation = "record_offer_skipped"
	last_error = ""
	return {
		"accepted": true,
		"duplicate": false,
		"offer_key": str(record.get("offer_key", "")),
		"record": record.duplicate(true),
	}


func record_round_finalized(
	run_snapshot: Dictionary,
	build_snapshot: Dictionary,
	outcome: String,
	failure_reason: String = "",
	context: Dictionary = {}
) -> Dictionary:
	if not active_run or run_finalized:
		return _reject("record_round_finalized", "no_mutable_run")
	if not _inputs_are_value_only([run_snapshot, build_snapshot, context]):
		value_reference_rejections += 1
		return _reject("record_round_finalized", "non_value_input")
	return _record_round_finalized_internal(
		run_snapshot,
		build_snapshot,
		outcome,
		failure_reason,
		context,
		false
	)


func finalize_run(
	run_snapshot: Dictionary,
	build_snapshot: Dictionary,
	outcome: String,
	failure_reason: String = "",
	context: Dictionary = {}
) -> Dictionary:
	if not _inputs_are_value_only([run_snapshot, build_snapshot, context]):
		value_reference_rejections += 1
		return _reject("finalize_run", "non_value_input")
	if not active_run:
		if (
			run_finalized
			and int(last_finalized_report_source.get("run_generation", -2))
			== active_run_generation
		):
			duplicate_run_finalization_suppressions += 1
			return {
				"accepted": false,
				"duplicate": true,
				"reason": "run_already_finalized",
				"report_source": last_finalized_report_source.duplicate(true),
			}
		return _reject("finalize_run", "no_active_run")
	if run_finalized:
		duplicate_run_finalization_suppressions += 1
		return {
			"accepted": false,
			"duplicate": true,
			"reason": "run_already_finalized",
			"report_source": last_finalized_report_source.duplicate(true),
		}

	var final_outcome: String = outcome if not outcome.is_empty() else OUTCOME_UNKNOWN
	var current_round_number: int = maxi(int(run_snapshot.get("round_number", 1)), 1)
	var current_key: String = _make_round_key(active_run_generation, current_round_number)
	if round_record_index_by_key.has(current_key) and not finalized_round_keys.has(current_key):
		auto_finalized_round_count += 1
		_record_round_finalized_internal(
			run_snapshot,
			build_snapshot,
			final_outcome,
			failure_reason,
			context,
			true
		)

	current_run_snapshot = _compact_run_snapshot(run_snapshot)
	current_build_snapshot = _compact_build_snapshot(build_snapshot)
	var ended_at_unix: int = _timestamp_from_context(context)
	active_run = false
	run_finalized = true
	session_finalization_count += 1
	last_operation = "finalize_run"
	last_error = ""
	var report_source: Dictionary = {
		"schema_version": REPORT_SOURCE_SCHEMA_VERSION,
		"telemetry_schema_version": TELEMETRY_SCHEMA_VERSION,
		"run_generation": active_run_generation,
		"mode_id": active_mode_id,
		"started_at_unix": run_started_at_unix,
		"ended_at_unix": ended_at_unix,
		"outcome": final_outcome,
		"final_outcome": final_outcome,
		"finalized": true,
		"failure_reason": failure_reason,
		"run_metadata": run_metadata.duplicate(true),
		"initial_run_snapshot": initial_run_snapshot.duplicate(true),
		"final_run_snapshot": current_run_snapshot.duplicate(true),
		"initial_build_snapshot": initial_build_snapshot.duplicate(true),
		"final_build_snapshot": current_build_snapshot.duplicate(true),
		"final_tray": _string_array(current_build_snapshot.get("item_ids_by_slot", [])),
		"run_accumulators": run_accumulators.duplicate(true),
		"shots": shot_records.duplicate(true),
		"offers": offer_records.duplicate(true),
		"rounds": round_records.duplicate(true),
		"abandoned_attempts": abandoned_attempts.duplicate(true),
		"history_complete": _histories_are_complete(),
		"diagnostics": get_diagnostics_snapshot(),
	}
	last_finalized_report_source = report_source.duplicate(true)
	_session_last_finalized_report_source = report_source.duplicate(true)
	return {
		"accepted": true,
		"duplicate": false,
		"report_source": report_source.duplicate(true),
	}


func abandon_active_run(reason: String = "main_menu") -> Dictionary:
	if not active_run:
		return _reject("abandon_active_run", "no_active_run")
	var abandoned: Dictionary = _abandon_active_run_internal(reason)
	_reset_current_run_state()
	last_operation = "abandon_active_run"
	last_error = ""
	return {"accepted": true, "duplicate": false, "abandoned_run": abandoned}


func capture_rewind_state() -> Dictionary:
	# Reward offers/acquisitions intentionally stay outside this shot checkpoint.
	return {
		"version": REWIND_STATE_VERSION,
		"active_run": active_run,
		"run_finalized": run_finalized,
		"active_run_generation": active_run_generation,
		"active_mode_id": active_mode_id,
		"run_started_at_unix": run_started_at_unix,
		"run_metadata": run_metadata.duplicate(true),
		"initial_run_snapshot": initial_run_snapshot.duplicate(true),
		"current_run_snapshot": current_run_snapshot.duplicate(true),
		"initial_build_snapshot": initial_build_snapshot.duplicate(true),
		"shot_records": shot_records.duplicate(true),
		"round_records": round_records.duplicate(true),
		"active_round_key": active_round_key,
		"run_accumulators": run_accumulators.duplicate(true),
		"last_finalized_report_source": last_finalized_report_source.duplicate(true),
	}


func restore_rewind_state(state: Dictionary) -> Dictionary:
	if int(state.get("version", 0)) != REWIND_STATE_VERSION:
		return _reject("restore_rewind_state", "rewind_state_version_mismatch")
	if not _inputs_are_value_only([state]):
		value_reference_rejections += 1
		return _reject("restore_rewind_state", "non_value_input")
	var restored_generation: int = int(state.get("active_run_generation", -1))
	if (
		active_run_generation >= 0
		and restored_generation >= 0
		and restored_generation != active_run_generation
	):
		return _reject("restore_rewind_state", "run_generation_mismatch", {
			"run_generation": restored_generation,
		})

	var restored_shots: Array[Dictionary] = _dictionary_array(state.get("shot_records", []))
	var restored_shot_keys: Dictionary = {}
	for restored_record in restored_shots:
		var restored_key: String = str(restored_record.get("shot_key", ""))
		if not restored_key.is_empty():
			restored_shot_keys[restored_key] = true
	_preserve_abandoned_attempts(restored_shot_keys)

	active_run = bool(state.get("active_run", false))
	run_finalized = bool(state.get("run_finalized", false))
	active_run_generation = restored_generation
	active_mode_id = str(state.get("active_mode_id", MODE_ROGUELITE))
	run_started_at_unix = int(state.get("run_started_at_unix", 0))
	run_metadata = _dictionary_value(state, "run_metadata").duplicate(true)
	initial_run_snapshot = _dictionary_value(state, "initial_run_snapshot").duplicate(true)
	current_run_snapshot = _dictionary_value(state, "current_run_snapshot").duplicate(true)
	initial_build_snapshot = _dictionary_value(state, "initial_build_snapshot").duplicate(true)
	# Build/reward acquisition is deliberately not shot-rewound. The current
	# build snapshot remains whatever the owning build system currently reports.
	shot_records = restored_shots
	round_records = _dictionary_array(state.get("round_records", []))
	active_round_key = str(state.get("active_round_key", ""))
	run_accumulators = _dictionary_value(state, "run_accumulators").duplicate(true)
	last_finalized_report_source = _dictionary_value(
		state,
		"last_finalized_report_source"
	).duplicate(true)
	_rebuild_shot_keys()
	_rebuild_round_indices()
	accepted_shot_count = shot_records.size()
	accepted_round_start_count = round_records.size()
	accepted_round_finalization_count = finalized_round_keys.size()
	rewind_restore_count += 1
	last_operation = "restore_rewind_state"
	last_error = ""
	return {
		"accepted": true,
		"duplicate": false,
		"restored_shot_count": shot_records.size(),
		"abandoned_attempt_count": abandoned_attempt_count,
	}


func get_current_run_snapshot() -> Dictionary:
	return {
		"schema_version": TELEMETRY_SCHEMA_VERSION,
		"active": active_run,
		"finalized": run_finalized,
		"run_generation": active_run_generation,
		"mode_id": active_mode_id,
		"started_at_unix": run_started_at_unix,
		"run_metadata": run_metadata.duplicate(true),
		"initial_run_snapshot": initial_run_snapshot.duplicate(true),
		"current_run_snapshot": current_run_snapshot.duplicate(true),
		"initial_build_snapshot": initial_build_snapshot.duplicate(true),
		"current_build_snapshot": current_build_snapshot.duplicate(true),
		"run_accumulators": run_accumulators.duplicate(true),
		"shots": shot_records.duplicate(true),
		"offers": offer_records.duplicate(true),
		"rounds": round_records.duplicate(true),
		"abandoned_attempts": abandoned_attempts.duplicate(true),
		"history_complete": _histories_are_complete(),
		"diagnostics": get_diagnostics_snapshot(),
	}


func get_last_finalized_report_source_snapshot() -> Dictionary:
	return last_finalized_report_source.duplicate(true)


static func get_session_last_finalized_report_source_snapshot() -> Dictionary:
	return _session_last_finalized_report_source.duplicate(true)


func get_report_source_snapshot(prefer_finalized: bool = true) -> Dictionary:
	if prefer_finalized and not last_finalized_report_source.is_empty():
		return last_finalized_report_source.duplicate(true)
	return get_current_run_snapshot()


func get_diagnostics_snapshot() -> Dictionary:
	return {
		"schema_version": TELEMETRY_SCHEMA_VERSION,
		"active_run": active_run,
		"run_finalized": run_finalized,
		"run_generation": active_run_generation,
		"mode_id": active_mode_id,
		"session_fresh_runs": session_fresh_run_count,
		"session_finalizations": session_finalization_count,
		"session_abandoned_runs": session_abandoned_run_count,
		"shot_records": shot_records.size(),
		"offer_records": offer_records.size(),
		"round_records": round_records.size(),
		"accepted_shots": accepted_shot_count,
		"accepted_offers": accepted_offer_count,
		"resolved_offers": resolved_offer_count,
		"accepted_round_starts": accepted_round_start_count,
		"accepted_round_finalizations": accepted_round_finalization_count,
		"duplicate_shot_suppressions": duplicate_shot_suppressions,
		"duplicate_offer_suppressions": duplicate_offer_suppressions,
		"duplicate_offer_resolution_suppressions": duplicate_offer_resolution_suppressions,
		"duplicate_round_start_suppressions": duplicate_round_start_suppressions,
		"duplicate_round_finalization_suppressions": duplicate_round_finalization_suppressions,
		"duplicate_run_finalization_suppressions": duplicate_run_finalization_suppressions,
		"rejected_records": rejected_record_count,
		"rejected_records_by_reason": rejected_records_by_reason.duplicate(true),
		"recent_rejections": recent_rejections.duplicate(true),
		"value_reference_rejections": value_reference_rejections,
		"shot_history_overflows": shot_history_overflow_count,
		"offer_history_overflows": offer_history_overflow_count,
		"round_history_overflows": round_history_overflow_count,
		"rewind_restores": rewind_restore_count,
		"abandoned_attempts": abandoned_attempt_count,
		"abandoned_attempt_history": abandoned_attempts.duplicate(true),
		"auto_started_rounds": auto_started_round_count,
		"auto_finalized_rounds": auto_finalized_round_count,
		"unfinalized_round_transitions": unfinalized_round_transition_count,
		"missing_base_score_results": missing_base_score_result_count,
		"incomplete_counterfactual_shots": incomplete_counterfactual_shot_count,
		"incomplete_eligible_pools": incomplete_eligible_pool_count,
		"history_complete": _histories_are_complete(),
		"last_operation": last_operation,
		"last_error": last_error,
		"last_abandoned_run": last_abandoned_run.duplicate(true),
	}


func reset_session() -> void:
	_reset_current_run_state()
	_reset_current_run_diagnostics()
	last_finalized_report_source.clear()
	last_abandoned_run.clear()
	session_fresh_run_count = 0
	session_finalization_count = 0
	session_abandoned_run_count = 0
	last_operation = "reset_session"
	last_error = ""


static func get_schema_contract() -> Dictionary:
	return {
		"telemetry_schema_version": TELEMETRY_SCHEMA_VERSION,
		"shot_record_schema_version": SHOT_RECORD_SCHEMA_VERSION,
		"offer_record_schema_version": OFFER_RECORD_SCHEMA_VERSION,
		"round_record_schema_version": ROUND_RECORD_SCHEMA_VERSION,
		"report_source_schema_version": REPORT_SOURCE_SCHEMA_VERSION,
		"mode_id": MODE_ROGUELITE,
		"authoritative_source": SOURCE_AUTHORITATIVE,
		"limits": {
			"shots": MAX_SHOT_RECORDS,
			"offers": MAX_OFFER_RECORDS,
			"rounds": MAX_ROUND_RECORDS,
			"abandoned_attempts": MAX_ABANDONED_ATTEMPTS,
		},
		"counterfactual_contract": {
			"key": "eight_ball_item_id",
			"accepted_score_fields": ["score_without_item", "shot_score"],
			"collector_calculates_marginal_uplift_if_missing": true,
		},
		"rewind_contract": {
			"shot_and_round_records_rewind": true,
			"offer_and_reward_records_rewind": false,
			"discarded_attempts_preserved_separately": true,
		},
	}


func _record_round_started_internal(
	run_snapshot: Dictionary,
	build_snapshot: Dictionary,
	balls_spawned: int,
	context: Dictionary
) -> Dictionary:
	var round_number: int = maxi(int(run_snapshot.get("round_number", 1)), 1)
	var round_key: String = _make_round_key(active_run_generation, round_number)
	if round_record_index_by_key.has(round_key):
		duplicate_round_start_suppressions += 1
		return _duplicate_result("record_round_started", round_key)
	if round_records.size() >= MAX_ROUND_RECORDS:
		round_history_overflow_count += 1
		return _reject("record_round_started", "round_history_capacity_reached", {
			"round_number": round_number,
		})
	if not active_round_key.is_empty() and not finalized_round_keys.has(active_round_key):
		unfinalized_round_transition_count += 1

	var safe_balls_spawned: int = balls_spawned
	if safe_balls_spawned < 0:
		safe_balls_spawned = maxi(int(run_snapshot.get("object_ball_count", 0)), 0)
	var compact_build: Dictionary = _compact_build_snapshot(build_snapshot)
	var record: Dictionary = {
		"schema_version": ROUND_RECORD_SCHEMA_VERSION,
		"round_key": round_key,
		"run_generation": active_run_generation,
		"round_number": round_number,
		"round_index": int(run_snapshot.get("round_index", round_number - 1)),
		"quota": maxi(int(run_snapshot.get("round_target", 0)), 0),
		"starting_hull": maxi(int(run_snapshot.get("hull", 0)), 0),
		"starting_shots": maxi(int(run_snapshot.get("shots_left", 0)), 0),
		"balls_spawned": safe_balls_spawned,
		"round_score_start": maxi(int(run_snapshot.get("round_score", 0)), 0),
		"round_score": maxi(int(run_snapshot.get("round_score", 0)), 0),
		"score_overflow": 0,
		"shots_used": 0,
		"shot_count": 0,
		"zero_score_shots": 0,
		"highest_shot": 0,
		"total_base_score_without_build": 0,
		"base_score_available_shots": 0,
		"total_build_uplift": 0,
		"object_balls_pocketed": 0,
		"scratches": 0,
		"doubloons_from_base_haul": 0,
		"trigger_counts": {},
		"shot_keys": [],
		"build_at_round_start": compact_build,
		"build_at_round_end": compact_build.duplicate(true),
		"outcome": "",
		"failure_reason": "",
		"finalized": false,
		"started_at_unix": _timestamp_from_context(context),
		"finalized_at_unix": 0,
	}
	round_record_index_by_key[round_key] = round_records.size()
	round_records.append(record)
	active_round_key = round_key
	accepted_round_start_count += 1
	current_run_snapshot = _compact_run_snapshot(run_snapshot)
	current_build_snapshot = compact_build.duplicate(true)
	last_operation = "record_round_started"
	last_error = ""
	return {
		"accepted": true,
		"duplicate": false,
		"round_key": round_key,
		"record": record.duplicate(true),
	}


func _record_round_finalized_internal(
	run_snapshot: Dictionary,
	build_snapshot: Dictionary,
	outcome: String,
	failure_reason: String,
	context: Dictionary,
	auto_finalized: bool
) -> Dictionary:
	var round_number: int = maxi(int(run_snapshot.get("round_number", 1)), 1)
	var round_key: String = _make_round_key(active_run_generation, round_number)
	if finalized_round_keys.has(round_key):
		duplicate_round_finalization_suppressions += 1
		return _duplicate_result("record_round_finalized", round_key)
	if not round_record_index_by_key.has(round_key):
		var started: Dictionary = _record_round_started_internal(
			run_snapshot,
			build_snapshot,
			int(run_snapshot.get("object_ball_count", 0)),
			context
		)
		if not bool(started.get("accepted", false)) and not bool(started.get("duplicate", false)):
			return started
		auto_started_round_count += 1

	var index: int = int(round_record_index_by_key.get(round_key, -1))
	if index < 0 or index >= round_records.size():
		return _reject("record_round_finalized", "round_record_not_found", {
			"round_number": round_number,
		})
	var record: Dictionary = round_records[index]
	var quota: int = maxi(int(record.get("quota", run_snapshot.get("round_target", 0))), 0)
	var round_score: int = maxi(int(run_snapshot.get(
		"round_score",
		record.get("round_score", 0)
	)), 0)
	record["round_score"] = round_score
	record["score_overflow"] = maxi(round_score - quota, 0)
	record["shots_used"] = maxi(
		int(record.get("starting_shots", 0)) - int(run_snapshot.get("shots_left", 0)),
		0
	)
	record["build_at_round_end"] = _compact_build_snapshot(build_snapshot)
	record["outcome"] = outcome if not outcome.is_empty() else OUTCOME_UNKNOWN
	record["failure_reason"] = failure_reason
	record["finalized"] = true
	record["auto_finalized"] = auto_finalized
	record["finalized_at_unix"] = _timestamp_from_context(context)
	round_records[index] = record
	finalized_round_keys[round_key] = true
	if active_round_key == round_key:
		active_round_key = ""
	accepted_round_finalization_count += 1
	current_run_snapshot = _compact_run_snapshot(run_snapshot)
	current_build_snapshot = _compact_build_snapshot(build_snapshot)
	last_operation = "record_round_finalized"
	last_error = ""
	return {
		"accepted": true,
		"duplicate": false,
		"round_key": round_key,
		"record": record.duplicate(true),
	}


func _update_round_with_shot(
	shot_record: Dictionary,
	run_snapshot_before: Dictionary,
	build_snapshot: Dictionary
) -> void:
	var round_number: int = int(shot_record.get("round_number", 1))
	var round_key: String = _make_round_key(active_run_generation, round_number)
	if not round_record_index_by_key.has(round_key):
		auto_started_round_count += 1
		_record_round_started_internal(
			run_snapshot_before,
			build_snapshot,
			int(run_snapshot_before.get("object_ball_count", 0)),
			{}
		)
	var index: int = int(round_record_index_by_key.get(round_key, -1))
	if index < 0 or index >= round_records.size():
		return
	var record: Dictionary = round_records[index]
	var shot_keys: Array[String] = _string_array(record.get("shot_keys", []))
	shot_keys.append(str(shot_record.get("shot_key", "")))
	record["shot_keys"] = shot_keys
	record["shot_count"] = int(record.get("shot_count", 0)) + 1
	var final_score: int = int(shot_record.get("final_score", 0))
	if final_score <= 0:
		record["zero_score_shots"] = int(record.get("zero_score_shots", 0)) + 1
	record["highest_shot"] = maxi(int(record.get("highest_shot", 0)), final_score)
	record["round_score"] = int(shot_record.get(
		"round_score_after",
		int(record.get("round_score", 0)) + final_score
	))
	if bool(shot_record.get("base_score_without_build_available", false)):
		record["base_score_available_shots"] = int(record.get(
			"base_score_available_shots",
			0
		)) + 1
		var base_score: int = int(shot_record.get("base_score_without_build", 0))
		record["total_base_score_without_build"] = int(record.get(
			"total_base_score_without_build",
			0
		)) + base_score
		record["total_build_uplift"] = int(record.get("total_build_uplift", 0)) + (
			final_score - base_score
		)
	record["object_balls_pocketed"] = int(record.get("object_balls_pocketed", 0)) + int(
		shot_record.get("object_balls_pocketed", 0)
	)
	if bool(shot_record.get("scratch", false)):
		record["scratches"] = int(record.get("scratches", 0)) + 1
	record["doubloons_from_base_haul"] = int(record.get(
		"doubloons_from_base_haul",
		0
	)) + int(shot_record.get("doubloons_from_base_haul", 0))
	var round_trigger_counts: Dictionary = _dictionary_value(record, "trigger_counts").duplicate(true)
	_add_counts(round_trigger_counts, _dictionary_value(shot_record, "trigger_counts"))
	record["trigger_counts"] = round_trigger_counts
	record["build_at_round_end"] = _compact_build_snapshot(build_snapshot)
	round_records[index] = record


func _update_run_accumulators(record: Dictionary) -> void:
	run_accumulators["total_shots"] = int(run_accumulators.get("total_shots", 0)) + 1
	var final_score: int = int(record.get("final_score", 0))
	run_accumulators["total_authoritative_score"] = int(run_accumulators.get(
		"total_authoritative_score",
		0
	)) + final_score
	if bool(record.get("base_score_without_build_available", false)):
		var base_score: int = int(record.get("base_score_without_build", 0))
		run_accumulators["base_score_available_shots"] = int(run_accumulators.get(
			"base_score_available_shots",
			0
		)) + 1
		run_accumulators["total_base_score_without_build"] = int(run_accumulators.get(
			"total_base_score_without_build",
			0
		)) + base_score
		run_accumulators["total_build_uplift"] = int(run_accumulators.get(
			"total_build_uplift",
			0
		)) + final_score - base_score
	if final_score <= 0:
		run_accumulators["zero_score_shots"] = int(run_accumulators.get(
			"zero_score_shots",
			0
		)) + 1
	if bool(record.get("scratch", false)):
		run_accumulators["scratches"] = int(run_accumulators.get("scratches", 0)) + 1
	run_accumulators["total_scoring_balls_pocketed"] = int(run_accumulators.get(
		"total_scoring_balls_pocketed",
		0
	)) + int(record.get("object_balls_pocketed", 0))
	run_accumulators["total_doubloons_from_base_haul"] = int(run_accumulators.get(
		"total_doubloons_from_base_haul",
		0
	)) + int(record.get("doubloons_from_base_haul", 0))
	run_accumulators["highest_shot"] = maxi(
		int(run_accumulators.get("highest_shot", 0)),
		final_score
	)
	run_accumulators["maximum_haul"] = maxi(
		int(run_accumulators.get("maximum_haul", 0)),
		int(record.get("final_haul", 0))
	)
	run_accumulators["maximum_mult"] = maxf(
		float(run_accumulators.get("maximum_mult", 1.0)),
		float(record.get("final_mult", 1.0))
	)
	run_accumulators["maximum_xmult_product"] = maxf(
		float(run_accumulators.get("maximum_xmult_product", 1.0)),
		float(record.get("build_xmult_product", 1.0))
	)
	run_accumulators["maximum_global_excitement"] = maxf(
		float(run_accumulators.get("maximum_global_excitement", 0.0)),
		float(record.get("global_excitement", 0.0))
	)
	var trigger_counts: Dictionary = _dictionary_value(
		run_accumulators,
		"trigger_counts"
	).duplicate(true)
	_add_counts(trigger_counts, _dictionary_value(record, "trigger_counts"))
	run_accumulators["trigger_counts"] = trigger_counts
	var tap_accumulator: Dictionary = _dictionary_value(
		run_accumulators,
		"tap_metrics"
	).duplicate(true)
	if tap_accumulator.is_empty():
		tap_accumulator = _make_empty_tap_accumulator()
	_add_tap_summary(tap_accumulator, _dictionary_value(record, "tap_metrics"))
	run_accumulators["tap_metrics"] = tap_accumulator
	var phase_5c_accumulator: Dictionary = _dictionary_value(
		run_accumulators,
		"phase_5c_tap_items"
	).duplicate(true)
	if phase_5c_accumulator.is_empty():
		phase_5c_accumulator = _make_empty_phase_5c_accumulator()
	_add_phase_5c_summary(
		phase_5c_accumulator,
		_dictionary_value(record, "phase_5c_tap_items"),
		str(record.get("shot_key", "")),
		int(record.get("round_number", 1))
	)
	run_accumulators["phase_5c_tap_items"] = phase_5c_accumulator
	var dead_reckoning_accumulator: Dictionary = _dictionary_value(
		run_accumulators,
		"dead_reckoning"
	)
	if dead_reckoning_accumulator.is_empty():
		dead_reckoning_accumulator = _make_empty_run_accumulators()[
			"dead_reckoning"
		].duplicate(true)
	_add_dead_reckoning_summary(
		dead_reckoning_accumulator,
		_dictionary_value(record, "dead_reckoning")
	)
	run_accumulators["dead_reckoning"] = dead_reckoning_accumulator


func _compact_item_activations(score_result: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var activation_ordinals: Dictionary = {}
	for step_value in _array_value(score_result, "resolution_steps"):
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value as Dictionary
		if str(step.get("source_type", "")) != "modifier":
			continue
		var metadata: Dictionary = _dictionary_value(step, "metadata")
		var item_id: String = str(metadata.get(
			"eight_ball_item_id",
			step.get("source_id", "")
		))
		if item_id.is_empty():
			continue
		var ordinal: int = int(activation_ordinals.get(item_id, 0)) + 1
		activation_ordinals[item_id] = ordinal
		var phase: String = str(metadata.get("modifier_phase", step.get("phase", "")))
		var applied_value: Variant = step.get("haul_delta", 0)
		if phase == "add_mult":
			applied_value = step.get("mult_delta", 0.0)
		elif phase == "xmult":
			applied_value = step.get("xmult_factor", 1.0)
		var haul_before: int = int(step.get("haul_before", 0))
		var mult_before: float = float(step.get("mult_before", 1.0))
		records.append({
			"eight_ball_item_id": item_id,
			"display_name": str(step.get("display_name", item_id)),
			"family_id": str(metadata.get("family_id", "")),
			"rarity": str(metadata.get("rarity", "")),
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
			"score_preview_before": maxi(int(floor(
				float(maxi(haul_before, 0)) * maxf(mult_before, 0.0)
			)), 0),
			"score_preview_after": maxi(int(step.get("score_preview_after", 0)), 0),
			"activation_ordinal_for_item": ordinal,
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
			"owned_item_instance_id": int(metadata.get(
				"owned_item_instance_id",
				step.get("owned_item_instance_id", -1)
			)),
			"effect_kind": str(metadata.get("effect_kind", "")),
			"offer_family": str(metadata.get(
				"offer_family",
				metadata.get("offer_family_id", "")
			)),
			"tap_ordinal": int(metadata.get("tap_ordinal", 0)),
			"retrigger_threshold_ordinal": int(metadata.get(
				"retrigger_threshold_ordinal",
				0
			)),
			"qualifying_scoring_ball_id": int(metadata.get(
				"qualifying_scoring_ball_id",
				metadata.get(
					"qualifying_ball_id",
					metadata.get("trigger_ball_id", step.get("ball_id", -1))
				)
			)),
			"resolution_step_index": int(step.get("step_index", -1)),
		})
	return records


func _compact_trigger_occurrences(values: Array) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for value in values:
		if not value is Dictionary:
			continue
		var occurrence: Dictionary = value as Dictionary
		records.append({
			"trigger_occurrence_id": str(occurrence.get("trigger_occurrence_id", "")),
			"trigger_id": str(occurrence.get("trigger_id", "")),
			"trigger_ball_id": int(occurrence.get(
				"trigger_ball_id",
				occurrence.get("ball_id", -1)
			)),
			"trigger_event_index": int(occurrence.get(
				"trigger_event_index",
				occurrence.get("event_index", -1)
			)),
			"pocket_order": int(occurrence.get("pocket_order", -1)),
			"ball_number": int(occurrence.get("ball_number", -1)),
			"pocket_index": int(occurrence.get("pocket_index", -1)),
			"pocket_event_index": int(occurrence.get("pocket_event_index", -1)),
			"world_position": occurrence.get("world_position", Vector2.ZERO),
			"milestone_tier": int(occurrence.get("milestone_tier", 0)),
			"contacted_ball_id": int(occurrence.get(
				"contacted_ball_id",
				occurrence.get("target_ball_id", -1)
			)),
			"metadata": _dictionary_value(occurrence, "metadata").duplicate(true),
		})
	return records


func _compact_item_counterfactuals(values: Dictionary, full_score: int) -> Dictionary:
	var records: Dictionary = {}
	for key_value in values.keys():
		var item_id: String = str(key_value)
		var value: Variant = values[key_value]
		if item_id.is_empty():
			continue
		var score_without_item := -1
		var supplied_uplift := -1
		var available := false
		if value is Dictionary:
			var counterfactual: Dictionary = value as Dictionary
			if counterfactual.has("score_without_item"):
				score_without_item = int(counterfactual.get("score_without_item", -1))
				available = score_without_item >= 0
			elif counterfactual.has("shot_score"):
				score_without_item = int(counterfactual.get("shot_score", -1))
				available = score_without_item >= 0
			if counterfactual.has("marginal_score_uplift"):
				supplied_uplift = int(counterfactual.get("marginal_score_uplift", -1))
		elif typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			score_without_item = int(value)
			available = score_without_item >= 0
		var marginal_uplift: int = supplied_uplift
		if marginal_uplift < 0 and available:
			marginal_uplift = full_score - score_without_item
		records[item_id] = {
			"available": available,
			"score_without_item": score_without_item,
			"marginal_score_uplift": marginal_uplift,
		}
	return records


func _compact_offer_definitions(values: Array) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for value in values:
		if value is Dictionary:
			var definition: Dictionary = value as Dictionary
			var item_id: String = _item_id(definition)
			if item_id.is_empty():
				continue
			definitions.append({
				"eight_ball_item_id": item_id,
				"display_name": str(definition.get("display_name", item_id)),
				"family_id": str(definition.get("family_id", "")),
				"offer_family": str(definition.get("offer_family", "")),
				"trigger_id": str(definition.get("trigger_id", "")),
				"modifier_phase": str(definition.get("modifier_phase", "")),
				"effect_kind": str(definition.get("effect_kind", "")),
				"value": definition.get("value", 0),
				"rarity": str(definition.get("rarity", "")),
				"offer_weight": int(definition.get("offer_weight", 0)),
			})
		else:
			var item_id: String = str(value)
			if not item_id.is_empty():
				definitions.append({"eight_ball_item_id": item_id})
	return definitions


func _compact_run_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	return {
		"round_index": int(snapshot.get("round_index", 0)),
		"round_number": int(snapshot.get("round_number", 1)),
		"round_count": int(snapshot.get("round_count", 0)),
		"round_target": int(snapshot.get("round_target", 0)),
		"round_score": int(snapshot.get("round_score", 0)),
		"shots_left": int(snapshot.get("shots_left", 0)),
		"hull": int(snapshot.get("hull", 0)),
		"max_hull": int(snapshot.get("max_hull", 0)),
		"object_ball_count": int(snapshot.get("object_ball_count", 0)),
		"round_active": bool(snapshot.get("round_active", false)),
		"round_won": bool(snapshot.get("round_won", false)),
		"run_failed": bool(snapshot.get("run_failed", false)),
		"run_completed": bool(snapshot.get("run_completed", false)),
		"failure_reason": str(snapshot.get("failure_reason", "")),
		"total_quota_score_earned": int(snapshot.get("total_quota_score_earned", 0)),
	}


func _compact_build_snapshot(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return {}
	var item_ids: Array[String] = _string_array(snapshot.get("item_ids_by_slot", []))
	if item_ids.is_empty():
		for slot_value in _array_value(snapshot, "slots"):
			if slot_value is Dictionary:
				var slot: Dictionary = slot_value as Dictionary
				item_ids.append(str(slot.get("eight_ball_item_id", "")))
	var occupied_slots := 0
	for item_id in item_ids:
		if not item_id.is_empty():
			occupied_slots += 1
	var item_definitions_by_slot: Array[Dictionary] = []
	var compact_slots: Array[Dictionary] = []
	var slots: Array = _array_value(snapshot, "slots")
	var supplied_definitions: Array = _array_value(snapshot, "item_definitions_by_slot")
	var state_by_instance: Dictionary = _dictionary_value(snapshot, "item_states_by_instance_id")
	if state_by_instance.is_empty():
		state_by_instance = _dictionary_value(snapshot, "owned_item_states")
	for slot_index in range(item_ids.size()):
		var definition: Dictionary = {}
		var source_slot: Dictionary = {}
		if slot_index < supplied_definitions.size() and supplied_definitions[slot_index] is Dictionary:
			definition = supplied_definitions[slot_index] as Dictionary
		elif slot_index < slots.size() and slots[slot_index] is Dictionary:
			source_slot = slots[slot_index] as Dictionary
			definition = _dictionary_value(source_slot, "definition")
		if source_slot.is_empty() and slot_index < slots.size() and slots[slot_index] is Dictionary:
			source_slot = slots[slot_index] as Dictionary
		item_definitions_by_slot.append(_compact_item_definition(
			definition,
			item_ids[slot_index]
		))
		var instance_id: int = int(source_slot.get(
			"owned_item_instance_id",
			source_slot.get("instance_id", -1)
		))
		var state: Dictionary = _dictionary_value(source_slot, "state")
		if state.is_empty() and instance_id >= 0:
			state = _dictionary_value(state_by_instance, str(instance_id))
		if state.is_empty() and not item_ids[slot_index].is_empty():
			state = _dictionary_value(state_by_instance, item_ids[slot_index])
		compact_slots.append({
			"slot_index": slot_index,
			"eight_ball_item_id": item_ids[slot_index],
			"owned_item_instance_id": instance_id,
			"acquired_round": maxi(int(source_slot.get("acquired_round", 0)), 0),
			"state": _compact_phase_5c_state(state),
			"definition": item_definitions_by_slot[item_definitions_by_slot.size() - 1],
		})
	return {
		"schema_version": int(snapshot.get("schema_version", 0)),
		"tray_capacity": int(snapshot.get("tray_capacity", item_ids.size())),
		"occupied_slots": int(snapshot.get("occupied_slots", occupied_slots)),
		"item_ids_by_slot": item_ids,
		"item_definitions_by_slot": item_definitions_by_slot,
		"slots": compact_slots,
		"next_owned_item_instance_id": maxi(int(snapshot.get(
			"next_owned_item_instance_id",
			1
		)), 1),
		"run_generation": int(snapshot.get("run_generation", active_run_generation)),
		"build_generation": int(snapshot.get("build_generation", 0)),
		"build_version": int(snapshot.get("build_version", 0)),
	}


func _compact_item_definition(definition: Dictionary, fallback_item_id: String) -> Dictionary:
	var item_id: String = str(definition.get(
		"eight_ball_item_id",
		definition.get("item_id", definition.get("id", fallback_item_id))
	))
	if item_id.is_empty():
		return {}
	return {
		"eight_ball_item_id": item_id,
		"display_name": str(definition.get("display_name", item_id)),
		"family_id": str(definition.get("family_id", "")),
		"trigger_id": str(definition.get("trigger_id", "")),
		"modifier_phase": str(definition.get(
			"modifier_phase",
			definition.get("phase", "")
		)),
		"effect_kind": str(definition.get("effect_kind", "")),
		"offer_family": str(definition.get("offer_family", "")),
		"trigger_ids": _string_array(definition.get("trigger_ids", [])),
		"application_phase": str(definition.get("application_phase", "")),
		"application_scope": str(definition.get("application_scope", "")),
		"state_schema_version": maxi(int(definition.get("state_schema_version", 0)), 0),
		"retrigger_family": str(definition.get(
			"retrigger_family",
			definition.get("retrigger_family_id", "")
		)),
		"retrigger_count": maxi(int(definition.get("retrigger_count", 0)), 0),
		"rarity": str(definition.get("rarity", "")),
		"offer_weight": maxi(int(definition.get("offer_weight", 0)), 0),
	}


func _summarize_tap_shot(
	derived: Dictionary,
	score_result: Dictionary,
	trigger_counts: Dictionary
) -> Dictionary:
	var summary: Dictionary = {
		"cue_recontact_milestones": 0,
		"qualifying_cue_strike_count": 0,
		"maximum_cue_strikes_against_one_scoring_ball": 0,
		"scoring_balls_with_double_tap": 0,
		"scoring_balls_with_triple_tap_or_higher": 0,
		"has_double_tap": false,
		"has_triple_tap_or_higher": false,
		"ball_tap_milestones": 0,
		"unique_ball_tap_target_count": 0,
		"unique_ball_tap_targets": [],
		"maximum_ball_taps_by_one_scoring_ball": 0,
		"scoring_balls_with_ball_tap": 0,
		"repeated_ball_tap_contacts_ignored": 0,
		"ambiguous_cue_contacts_rejected": 0,
		"ambiguous_ball_tap_contacts_rejected": 0,
		"ambiguous_tap_contacts_rejected": 0,
		"tap_direct_pot_disqualifications": 0,
		"cue_recontact_mult": 0,
		"double_tap_mult": 0,
		"ball_tap_mult": 0,
		"cue_recontact_score_supplied": 0,
		"double_tap_score_supplied": 0,
		"ball_tap_score_supplied": 0,
		"score_supply_method": "immediate_base_resolution_step_score_delta",
		"target_evidence_truncated": false,
	}
	var target_pairs: Array[Dictionary] = []
	for fact in _dictionary_array(derived.get("pocket_facts", [])):
		var ball_id: int = int(fact.get("ball_id", -1))
		var cue_event_indices: Array = _array_value(fact, "cue_recontact_event_indices")
		var cue_strike_count: int = maxi(
			int(fact.get("qualifying_cue_strike_count", 0)),
			cue_event_indices.size() + (1 if not cue_event_indices.is_empty() else 0)
		)
		var cue_bonus_count: int = maxi(
			int(fact.get("cue_recontact_bonus_count", 0)),
			maxi(cue_strike_count - 1, 0)
		)
		var target_ids: Array[int] = []
		for target_value in _array_value(fact, "unique_object_tap_ball_ids"):
			var target_id: int = int(target_value)
			if target_id > 0 and not target_ids.has(target_id):
				target_ids.append(target_id)
		if target_ids.is_empty():
			for target_value in _array_value(fact, "object_tap_target_ball_ids"):
				var target_id: int = int(target_value)
				if target_id > 0 and not target_ids.has(target_id):
					target_ids.append(target_id)
		var ball_tap_count: int = maxi(
			int(fact.get("unique_object_tap_count", 0)),
			target_ids.size()
		)

		summary["qualifying_cue_strike_count"] = int(
			summary["qualifying_cue_strike_count"]
		) + cue_strike_count
		summary["cue_recontact_milestones"] = int(
			summary["cue_recontact_milestones"]
		) + cue_bonus_count
		summary["maximum_cue_strikes_against_one_scoring_ball"] = maxi(
			int(summary["maximum_cue_strikes_against_one_scoring_ball"]),
			cue_strike_count
		)
		if cue_bonus_count > 0:
			summary["scoring_balls_with_double_tap"] = int(
				summary["scoring_balls_with_double_tap"]
			) + 1
		if cue_strike_count >= 3:
			summary["scoring_balls_with_triple_tap_or_higher"] = int(
				summary["scoring_balls_with_triple_tap_or_higher"]
			) + 1

		summary["ball_tap_milestones"] = int(summary["ball_tap_milestones"]) + ball_tap_count
		summary["unique_ball_tap_target_count"] = int(
			summary["unique_ball_tap_target_count"]
		) + ball_tap_count
		summary["maximum_ball_taps_by_one_scoring_ball"] = maxi(
			int(summary["maximum_ball_taps_by_one_scoring_ball"]),
			ball_tap_count
		)
		if ball_tap_count > 0:
			summary["scoring_balls_with_ball_tap"] = int(
				summary["scoring_balls_with_ball_tap"]
			) + 1
		for target_id in target_ids:
			if target_pairs.size() >= MAX_TAP_TARGET_REFERENCES_PER_SHOT:
				summary["target_evidence_truncated"] = true
				break
			target_pairs.append({
				"scoring_ball_id": ball_id,
				"target_ball_id": target_id,
			})

		summary["repeated_ball_tap_contacts_ignored"] = int(
			summary["repeated_ball_tap_contacts_ignored"]
		) + maxi(int(fact.get("repeated_object_tap_contact_count", 0)), 0)
		summary["ambiguous_cue_contacts_rejected"] = int(
			summary["ambiguous_cue_contacts_rejected"]
		) + maxi(int(fact.get("ambiguous_cue_contact_count", 0)), 0)
		summary["ambiguous_ball_tap_contacts_rejected"] = int(
			summary["ambiguous_ball_tap_contacts_rejected"]
		) + maxi(int(fact.get("ambiguous_object_tap_count", 0)), 0)
		if (cue_bonus_count > 0 or ball_tap_count > 0) and not bool(
			fact.get("is_direct_pot", false)
		):
			summary["tap_direct_pot_disqualifications"] = int(
				summary["tap_direct_pot_disqualifications"]
			) + 1

	summary["cue_recontact_milestones"] = maxi(
		int(summary["cue_recontact_milestones"]),
		maxi(
			maxi(
				int(derived.get("total_cue_recontact_milestones", 0)),
				int(derived.get("cue_recontact_milestone_count", 0))
			),
			int(trigger_counts.get(TRIGGER_CUE_RECONTACT, 0))
		)
	)
	summary["maximum_cue_strikes_against_one_scoring_ball"] = maxi(
		int(summary["maximum_cue_strikes_against_one_scoring_ball"]),
		maxi(
			int(derived.get("maximum_cue_strikes_against_one_scoring_ball", 0)),
			int(derived.get("maximum_qualifying_cue_strikes", 0))
		)
	)
	summary["ball_tap_milestones"] = maxi(
		int(summary["ball_tap_milestones"]),
		maxi(
			maxi(
				int(derived.get("total_unique_ball_tap_milestones", 0)),
				maxi(
					int(derived.get("total_ball_tap_milestones", 0)),
					int(derived.get("total_unique_object_tap_milestones", 0))
				)
			),
			int(trigger_counts.get(TRIGGER_OBJECT_BALL_TAP, 0))
		)
	)
	summary["unique_ball_tap_target_count"] = maxi(
		int(summary["unique_ball_tap_target_count"]),
		int(summary["ball_tap_milestones"])
	)
	summary["maximum_ball_taps_by_one_scoring_ball"] = maxi(
		int(summary["maximum_ball_taps_by_one_scoring_ball"]),
		int(derived.get("maximum_ball_taps_by_one_scoring_ball", 0))
	)
	summary["repeated_ball_tap_contacts_ignored"] = maxi(
		int(summary["repeated_ball_tap_contacts_ignored"]),
		maxi(
			int(derived.get("repeated_ball_tap_contacts_ignored", 0)),
			int(derived.get("repeated_object_tap_contact_count", 0))
		)
	)
	summary["ambiguous_cue_contacts_rejected"] = maxi(
		int(summary["ambiguous_cue_contacts_rejected"]),
		maxi(
			int(derived.get("ambiguous_cue_contacts_rejected", 0)),
			int(derived.get("ambiguous_cue_contact_count", 0))
		)
	)
	summary["ambiguous_ball_tap_contacts_rejected"] = maxi(
		int(summary["ambiguous_ball_tap_contacts_rejected"]),
		maxi(
			int(derived.get("ambiguous_ball_tap_contacts_rejected", 0)),
			int(derived.get("ambiguous_object_tap_count", 0))
		)
	)
	summary["ambiguous_tap_contacts_rejected"] = (
		int(summary["ambiguous_cue_contacts_rejected"])
		+ int(summary["ambiguous_ball_tap_contacts_rejected"])
	)
	summary["tap_direct_pot_disqualifications"] = maxi(
		int(summary["tap_direct_pot_disqualifications"]),
		maxi(
			int(derived.get("tap_direct_pot_disqualifications", 0)),
			int(derived.get("tap_related_direct_pot_disqualification_count", 0))
		)
	)
	summary["cue_recontact_mult"] = int(summary["cue_recontact_milestones"])
	summary["double_tap_mult"] = int(summary["cue_recontact_mult"])
	summary["ball_tap_mult"] = int(summary["ball_tap_milestones"])
	summary["has_double_tap"] = int(summary["cue_recontact_milestones"]) > 0
	summary["has_triple_tap_or_higher"] = (
		int(summary["maximum_cue_strikes_against_one_scoring_ball"]) >= 3
	)
	summary["unique_ball_tap_targets"] = target_pairs
	summary["cue_recontact_score_supplied"] = _base_family_score_supplied(
		score_result,
		"cue_recontact"
	)
	summary["ball_tap_score_supplied"] = _base_family_score_supplied(
		score_result,
		"ball_tap"
	)
	summary["double_tap_score_supplied"] = int(summary["cue_recontact_score_supplied"])
	return summary


func _base_family_score_supplied(score_result: Dictionary, family_id: String) -> int:
	var supplied: int = 0
	for step in _dictionary_array(score_result.get("resolution_steps", [])):
		if str(step.get("source_type", "")) == "modifier":
			continue
		var metadata: Dictionary = _dictionary_value(step, "metadata")
		var identity: String = "%s|%s|%s|%s" % [
			str(step.get("source_id", "")),
			str(step.get("source_type", "")),
			str(step.get("display_name", "")),
			str(metadata.get("trigger_id", "")),
		]
		identity = identity.to_lower()
		var matches: bool = false
		if family_id == "cue_recontact":
			matches = (
				identity.contains("cue_recontact")
				or identity.contains("double_tap")
				or identity.contains("triple_tap")
			)
		elif family_id == "ball_tap":
			matches = (
				identity.contains("object_ball_tap")
				or identity.contains("base_ball_tap")
				or identity.contains("ball tap")
			)
		if not matches:
			continue
		var score_before: int = maxi(int(floor(
			maxf(float(step.get("haul_before", 0)), 0.0)
			* maxf(float(step.get("mult_before", 0.0)), 0.0)
		)), 0)
		var score_after: int = maxi(int(step.get("score_preview_after", score_before)), 0)
		supplied += maxi(score_after - score_before, 0)
	return supplied


func _make_empty_tap_accumulator() -> Dictionary:
	return {
		"shots_with_double_tap": 0,
		"shots_with_triple_tap_or_higher": 0,
		"cue_recontact_milestones": 0,
		"qualifying_cue_strike_count": 0,
		"maximum_cue_strikes_against_one_scoring_ball": 0,
		"scoring_balls_with_double_tap": 0,
		"scoring_balls_with_triple_tap_or_higher": 0,
		"ball_tap_milestones": 0,
		"unique_ball_tap_target_count": 0,
		"maximum_ball_taps_by_one_scoring_ball": 0,
		"scoring_balls_with_ball_tap": 0,
		"repeated_ball_tap_contacts_ignored": 0,
		"ambiguous_cue_contacts_rejected": 0,
		"ambiguous_ball_tap_contacts_rejected": 0,
		"ambiguous_tap_contacts_rejected": 0,
		"tap_direct_pot_disqualifications": 0,
		"cue_recontact_mult": 0,
		"double_tap_mult": 0,
		"ball_tap_mult": 0,
		"cue_recontact_score_supplied": 0,
		"double_tap_score_supplied": 0,
		"ball_tap_score_supplied": 0,
	}


func _add_tap_summary(target: Dictionary, addition: Dictionary) -> void:
	if bool(addition.get("has_double_tap", false)):
		target["shots_with_double_tap"] = int(target.get("shots_with_double_tap", 0)) + 1
	if bool(addition.get("has_triple_tap_or_higher", false)):
		target["shots_with_triple_tap_or_higher"] = int(
			target.get("shots_with_triple_tap_or_higher", 0)
		) + 1
	for key in [
		"cue_recontact_milestones",
		"qualifying_cue_strike_count",
		"scoring_balls_with_double_tap",
		"scoring_balls_with_triple_tap_or_higher",
		"ball_tap_milestones",
		"unique_ball_tap_target_count",
		"scoring_balls_with_ball_tap",
		"repeated_ball_tap_contacts_ignored",
		"ambiguous_cue_contacts_rejected",
		"ambiguous_ball_tap_contacts_rejected",
		"ambiguous_tap_contacts_rejected",
		"tap_direct_pot_disqualifications",
		"cue_recontact_mult",
		"double_tap_mult",
		"ball_tap_mult",
		"cue_recontact_score_supplied",
		"double_tap_score_supplied",
		"ball_tap_score_supplied",
	]:
		target[key] = int(target.get(key, 0)) + int(addition.get(key, 0))
	target["maximum_cue_strikes_against_one_scoring_ball"] = maxi(
		int(target.get("maximum_cue_strikes_against_one_scoring_ball", 0)),
		int(addition.get("maximum_cue_strikes_against_one_scoring_ball", 0))
	)
	target["maximum_ball_taps_by_one_scoring_ball"] = maxi(
		int(target.get("maximum_ball_taps_by_one_scoring_ball", 0)),
		int(addition.get("maximum_ball_taps_by_one_scoring_ball", 0))
	)


func _summarize_phase_5c_tap_items(
	build_evaluation: Dictionary,
	score_result: Dictionary,
	build_snapshot: Dictionary,
	trigger_occurrences: Array[Dictionary],
	activations: Array[Dictionary],
	tap_summary: Dictionary,
	counterfactuals: Dictionary
) -> Dictionary:
	var owned: Dictionary = _phase_5c_owned_items(build_snapshot)
	var shot_transaction: Dictionary = _dictionary_value(score_result, "shot_transaction")
	var state_before: Dictionary = _phase_5c_state_map_alias(
		shot_transaction,
		build_evaluation,
		["state_before", "item_states_before", "build_state_before"]
	)
	if state_before.is_empty():
		state_before = _phase_5c_state_map_alias(
			score_result,
			{},
			["state_before", "item_states_before", "build_state_before"]
		)
	var state_after: Dictionary = _phase_5c_state_map_alias(
		shot_transaction,
		build_evaluation,
		[
			"state_after",
			"item_states_after",
			"simulated_state_after",
			"authoritative_state_after",
		]
	)
	if state_after.is_empty():
		state_after = _phase_5c_state_map_alias(
			score_result,
			{},
			[
				"state_after",
				"item_states_after",
				"simulated_state_after",
				"authoritative_state_after",
			]
		)
	if state_after.is_empty():
		state_after = _phase_5c_states_from_build(build_snapshot)
	var engine_events: Array[Dictionary] = _compact_phase_5c_engine_events(
		_array_alias(build_evaluation, ["engine_events", "build_engine_events"])
	)
	if engine_events.is_empty():
		engine_events = _compact_phase_5c_engine_events(
			_array_alias(score_result, ["engine_events", "build_engine_events"])
		)
	var state_mutations: Array[Dictionary] = _compact_phase_5c_state_mutations(
		_array_alias(
			build_evaluation,
			[
				"authoritative_state_mutations",
				"pending_item_state_mutations",
				"state_mutations",
			]
		)
	)
	if state_mutations.is_empty():
		state_mutations = _compact_phase_5c_state_mutations(
			_array_alias(
				shot_transaction,
				["pending_item_state_mutations", "authoritative_state_mutations"]
			)
		)
	if state_mutations.is_empty():
		state_mutations = _compact_phase_5c_state_mutations(
			_array_alias(
				score_result,
				["pending_item_state_mutations", "authoritative_state_mutations"]
			)
		)

	var cue_taps: int = maxi(int(tap_summary.get("cue_recontact_milestones", 0)), 0)
	var ball_taps: int = maxi(int(tap_summary.get("ball_tap_milestones", 0)), 0)
	var tap_count: int = cue_taps + ball_taps
	var rattle: Dictionary = _summarize_rattle(
		owned,
		state_before,
		state_after,
		state_mutations,
		engine_events,
		activations,
		tap_count,
		counterfactuals
	)
	var one_two_punch: Dictionary = _summarize_one_two_punch(
		owned,
		trigger_occurrences,
		activations,
		cue_taps,
		ball_taps,
		counterfactuals
	)
	var aftershock: Dictionary = _summarize_aftershock(
		owned,
		activations,
		tap_count,
		counterfactuals
	)
	var echo_chamber: Dictionary = _summarize_echo_chamber(
		owned,
		trigger_occurrences,
		activations,
		engine_events,
		counterfactuals
	)
	return {
		"schema_version": 1,
		"tap_milestone_count": tap_count,
		"cue_recontact_milestone_count": cue_taps,
		"object_ball_tap_milestone_count": ball_taps,
		"rattle": rattle,
		"one_two_punch": one_two_punch,
		"aftershock": aftershock,
		"echo_chamber": echo_chamber,
		"item_states_before": state_before,
		"item_states_after": state_after,
		"state_mutations": state_mutations,
		"engine_events": engine_events,
		"evidence_bounded": true,
		"max_engine_events": MAX_PHASE_5C_ENGINE_EVENTS_PER_SHOT,
		"max_state_mutations": MAX_PHASE_5C_STATE_MUTATIONS_PER_SHOT,
	}


func _summarize_rattle(
	owned: Dictionary,
	state_before: Dictionary,
	state_after: Dictionary,
	mutations: Array[Dictionary],
	engine_events: Array[Dictionary],
	activations: Array[Dictionary],
	tap_count: int,
	counterfactuals: Dictionary
) -> Dictionary:
	var owned_record: Dictionary = _dictionary_value(owned, RATTLE_ITEM_ID)
	var before: Dictionary = _phase_5c_item_state(state_before, RATTLE_ITEM_ID, owned_record)
	var after: Dictionary = _phase_5c_item_state(state_after, RATTLE_ITEM_ID, owned_record)
	var growth_events: Array[Dictionary] = []
	for event in engine_events:
		if _phase_5c_event_item_id(event) != RATTLE_ITEM_ID:
			continue
		var event_kind: String = str(event.get("event_kind", event.get("type", ""))).to_lower()
		if (
			event_kind.contains("growth")
			or event_kind.contains("state")
			or event.has("value_before")
			or event.has("value_after")
		):
			growth_events.append(event.duplicate(true))
	for mutation in mutations:
		if _phase_5c_event_item_id(mutation) != RATTLE_ITEM_ID:
			continue
		if growth_events.size() < MAX_PHASE_5C_ENGINE_EVENTS_PER_SHOT:
			growth_events.append(mutation.duplicate(true))
	var activation_count: int = _activation_count_for_item(activations, RATTLE_ITEM_ID)
	var current_before: float = _state_float(before, ["current_xmult", "xmult"], 1.0)
	var current_after: float = _state_float(after, ["current_xmult", "xmult"], current_before)
	if before.is_empty() and not growth_events.is_empty():
		current_before = float(growth_events[0].get("value_before", current_before))
	if after.is_empty() and not growth_events.is_empty():
		current_after = float(growth_events[growth_events.size() - 1].get(
			"value_after",
			current_after
		))
	return {
		"owned": not owned_record.is_empty(),
		"owned_item_instance_id": int(owned_record.get("owned_item_instance_id", -1)),
		"acquired_round": maxi(int(owned_record.get("acquired_round", 0)), 0),
		"state_before": before,
		"state_after": after,
		"current_xmult_before": current_before,
		"current_xmult_after": current_after,
		"lifetime_growth_before": maxi(int(before.get("lifetime_growth_triggers", 0)), 0),
		"lifetime_growth_after": maxi(int(after.get(
			"lifetime_growth_triggers",
			before.get("lifetime_growth_triggers", 0)
		)), 0),
		"shots_activated_before": maxi(int(before.get("shots_activated", 0)), 0),
		"shots_activated_after": maxi(int(after.get(
			"shots_activated",
			before.get("shots_activated", 0)
		)), 0),
		"tap_milestones_grown_from": tap_count if not owned_record.is_empty() else 0,
		"activated_this_shot": activation_count > 0,
		"activation_count": activation_count,
		"non_tap_shot_while_owned": not owned_record.is_empty() and tap_count == 0,
		"growth_events": growth_events,
		"marginal_score_uplift": _counterfactual_uplift(counterfactuals, RATTLE_ITEM_ID),
	}


func _summarize_one_two_punch(
	owned: Dictionary,
	trigger_occurrences: Array[Dictionary],
	activations: Array[Dictionary],
	cue_taps: int,
	ball_taps: int,
	counterfactuals: Dictionary
) -> Dictionary:
	var cue_balls: Dictionary = {}
	var ball_tap_balls: Dictionary = {}
	for occurrence in trigger_occurrences:
		var ball_id: int = int(occurrence.get("trigger_ball_id", -1))
		if ball_id < 0:
			continue
		match str(occurrence.get("trigger_id", "")):
			TRIGGER_CUE_RECONTACT:
				cue_balls[ball_id] = true
			TRIGGER_OBJECT_BALL_TAP:
				ball_tap_balls[ball_id] = true
	var qualifying_ids: Array[int] = []
	for ball_id_value in cue_balls.keys():
		var ball_id: int = int(ball_id_value)
		if ball_tap_balls.has(ball_id):
			qualifying_ids.append(ball_id)
	qualifying_ids.sort()
	var activation_ids: Array[int] = []
	for activation in activations:
		if _item_id(activation) != ONE_TWO_PUNCH_ITEM_ID:
			continue
		var ball_id: int = int(activation.get("qualifying_scoring_ball_id", -1))
		if ball_id >= 0 and not activation_ids.has(ball_id):
			activation_ids.append(ball_id)
	if qualifying_ids.is_empty() and not activation_ids.is_empty():
		qualifying_ids = activation_ids
	return {
		"owned": owned.has(ONE_TWO_PUNCH_ITEM_ID),
		"qualifying_scoring_ball_ids": qualifying_ids,
		"qualifying_scoring_balls": qualifying_ids.size(),
		"activations": _activation_count_for_item(activations, ONE_TWO_PUNCH_ITEM_ID),
		"only_one_tap_family_present": (
			owned.has(ONE_TWO_PUNCH_ITEM_ID)
			and ((cue_taps > 0) != (ball_taps > 0))
		),
		"marginal_score_uplift": _counterfactual_uplift(
			counterfactuals,
			ONE_TWO_PUNCH_ITEM_ID
		),
	}


func _summarize_aftershock(
	owned: Dictionary,
	activations: Array[Dictionary],
	tap_count: int,
	counterfactuals: Dictionary
) -> Dictionary:
	var activation_count: int = _activation_count_for_item(activations, AFTERSHOCK_ITEM_ID)
	var highest_ordinal: int = 0
	for activation in activations:
		if _item_id(activation) == AFTERSHOCK_ITEM_ID:
			highest_ordinal = maxi(highest_ordinal, int(activation.get("tap_ordinal", 0)))
	return {
		"owned": owned.has(AFTERSHOCK_ITEM_ID),
		"tap_milestones_while_owned": tap_count if owned.has(AFTERSHOCK_ITEM_ID) else 0,
		"ignored_first_milestones": 1 if owned.has(AFTERSHOCK_ITEM_ID) and tap_count > 0 else 0,
		"xmult_activations": activation_count,
		"highest_tap_ordinal": maxi(highest_ordinal, tap_count if activation_count > 0 else 0),
		"marginal_score_uplift": _counterfactual_uplift(counterfactuals, AFTERSHOCK_ITEM_ID),
	}


func _summarize_echo_chamber(
	owned: Dictionary,
	trigger_occurrences: Array[Dictionary],
	activations: Array[Dictionary],
	engine_events: Array[Dictionary],
	counterfactuals: Dictionary
) -> Dictionary:
	var echo_owned: bool = owned.has(ECHO_CHAMBER_ITEM_ID)
	var support_ids: Array[String] = []
	for item_id in REGULAR_DOUBLE_TAP_ITEM_IDS + REGULAR_BALL_TAP_ITEM_IDS:
		if owned.has(item_id):
			support_ids.append(item_id)
	var ordered_taps: Array[Dictionary] = []
	for occurrence in trigger_occurrences:
		if [TRIGGER_CUE_RECONTACT, TRIGGER_OBJECT_BALL_TAP].has(str(
			occurrence.get("trigger_id", "")
		)):
			ordered_taps.append(occurrence)
	ordered_taps.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_index: int = int(left.get("trigger_event_index", -1))
		var right_index: int = int(right.get("trigger_event_index", -1))
		if left_index != right_index:
			return left_index < right_index
		return str(left.get("trigger_occurrence_id", "")) < str(
			right.get("trigger_occurrence_id", "")
		)
	)
	var thresholds: int = floori(float(ordered_taps.size()) / 3.0) if echo_owned else 0
	var supported: int = 0
	var unsupported: int = 0
	var threshold_families: Dictionary = {"double_tap": 0, "ball_tap": 0}
	for threshold_index in range(thresholds):
		var occurrence_index: int = (threshold_index + 1) * 3 - 1
		var trigger_id: String = str(ordered_taps[occurrence_index].get("trigger_id", ""))
		var matching_ids: Array[String] = (
			REGULAR_DOUBLE_TAP_ITEM_IDS
			if trigger_id == TRIGGER_CUE_RECONTACT
			else REGULAR_BALL_TAP_ITEM_IDS
		)
		var family_id: String = "double_tap" if trigger_id == TRIGGER_CUE_RECONTACT else "ball_tap"
		threshold_families[family_id] = int(threshold_families[family_id]) + 1
		var has_matching_support: bool = false
		for item_id in matching_ids:
			if owned.has(item_id):
				has_matching_support = true
				break
		if has_matching_support:
			supported += 1
		else:
			unsupported += 1
	var retriggered_by_family: Dictionary = {"double_tap": 0, "ball_tap": 0}
	var retriggered_haul: float = 0.0
	var retriggered_mult: float = 0.0
	var retriggered_xmult: int = 0
	var retriggered_xmult_product: float = 1.0
	for activation in activations:
		if (
			not bool(activation.get("is_retrigger", false))
			or str(activation.get("retrigger_source_item_id", "")) != ECHO_CHAMBER_ITEM_ID
		):
			continue
		var family_id: String = str(activation.get("family_id", ""))
		if retriggered_by_family.has(family_id):
			retriggered_by_family[family_id] = int(retriggered_by_family[family_id]) + 1
		var value: float = float(activation.get("applied_value", 0.0))
		match str(activation.get("modifier_phase", "")):
			"add_haul":
				retriggered_haul += value
			"add_mult":
				retriggered_mult += value
			"xmult":
				retriggered_xmult += 1
				retriggered_xmult_product *= value
	var marker_count: int = 0
	for event in engine_events:
		if _phase_5c_event_item_id(event) == ECHO_CHAMBER_ITEM_ID:
			var kind: String = str(event.get("event_kind", event.get("type", ""))).to_lower()
			if kind.contains("threshold") or kind.contains("retrigger_marker"):
				marker_count += 1
	return {
		"owned": echo_owned,
		"has_regular_tap_support": not support_ids.is_empty(),
		"support_item_ids": support_ids,
		"threshold_milestones": maxi(thresholds, marker_count),
		"supported_thresholds": supported,
		"unsupported_thresholds": unsupported,
		"thresholds_by_family": threshold_families,
		"regular_activations_retriggered": (
			int(retriggered_by_family["double_tap"])
			+ int(retriggered_by_family["ball_tap"])
		),
		"retriggers_by_family": retriggered_by_family,
		"retriggered_add_haul": retriggered_haul,
		"retriggered_add_mult": retriggered_mult,
		"retriggered_xmult_activations": retriggered_xmult,
		"retriggered_xmult_product": retriggered_xmult_product,
		"marginal_score_uplift": _counterfactual_uplift(
			counterfactuals,
			ECHO_CHAMBER_ITEM_ID
		),
	}


func _phase_5c_owned_items(build_snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot_value in _array_value(build_snapshot, "slots"):
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value as Dictionary
		var item_id: String = _item_id(slot)
		if item_id.is_empty():
			continue
		result[item_id] = slot.duplicate(true)
	return result


func _phase_5c_states_from_build(build_snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot_value in _array_value(build_snapshot, "slots"):
		if not slot_value is Dictionary or result.size() >= MAX_PHASE_5C_STATE_ITEMS:
			continue
		var slot: Dictionary = slot_value as Dictionary
		var item_id: String = _item_id(slot)
		if item_id.is_empty():
			continue
		result[item_id] = _compact_phase_5c_state(_dictionary_value(slot, "state"))
	return result


func _phase_5c_state_map_alias(
	primary: Dictionary,
	secondary: Dictionary,
	keys: Array[String]
) -> Dictionary:
	for source in [primary, secondary]:
		for key in keys:
			var value: Dictionary = _dictionary_value(source, key)
			if not value.is_empty():
				return _compact_phase_5c_state_map(value)
	return {}


func _phase_5c_item_state(
	state_map: Dictionary,
	item_id: String,
	owned_record: Dictionary
) -> Dictionary:
	var state: Dictionary = _dictionary_value(state_map, item_id)
	if not state.is_empty():
		return state
	var instance_id: int = int(owned_record.get("owned_item_instance_id", -1))
	if instance_id >= 0:
		state = _dictionary_value(state_map, str(instance_id))
	return state


func _compact_phase_5c_state_map(source: Dictionary) -> Dictionary:
	for nested_key in [
		"item_states_by_instance_id",
		"owned_item_states",
		"owned_item_state_snapshot",
	]:
		var nested: Dictionary = _dictionary_value(source, nested_key)
		if not nested.is_empty():
			return _compact_phase_5c_state_map(nested)
	var result: Dictionary = {}
	if source.has("slots"):
		for slot_value in _array_value(source, "slots"):
			if not slot_value is Dictionary or result.size() >= MAX_PHASE_5C_STATE_ITEMS:
				continue
			var slot: Dictionary = slot_value as Dictionary
			var item_id: String = _item_id(slot)
			if not item_id.is_empty():
				result[item_id] = _compact_phase_5c_state(_dictionary_value(slot, "state"))
		return result
	for key_value in source.keys():
		if result.size() >= MAX_PHASE_5C_STATE_ITEMS:
			break
		var value: Variant = source[key_value]
		if value is Dictionary:
			result[str(key_value)] = _compact_phase_5c_state(value as Dictionary)
	return result


func _compact_phase_5c_state(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value in source.keys():
		if result.size() >= MAX_PHASE_5C_VALUE_KEYS:
			break
		var key: String = str(key_value)
		result[key] = _compact_phase_5c_value(source[key_value], 0)
	return result


func _compact_phase_5c_value(value: Variant, depth: int) -> Variant:
	if depth >= 4:
		return null
	if value is Dictionary:
		var result: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			if result.size() >= MAX_PHASE_5C_VALUE_KEYS:
				break
			result[str(key_value)] = _compact_phase_5c_value(
				(value as Dictionary)[key_value],
				depth + 1
			)
		return result
	if value is Array:
		var result: Array = []
		var source: Array = value as Array
		for index in range(mini(source.size(), MAX_PHASE_5C_ENGINE_EVENTS_PER_SHOT)):
			result.append(_compact_phase_5c_value(source[index], depth + 1))
		return result
	if value is Object:
		return null
	return value


func _compact_phase_5c_engine_events(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in values:
		if not value is Dictionary or result.size() >= MAX_PHASE_5C_ENGINE_EVENTS_PER_SHOT:
			continue
		var event: Dictionary = value as Dictionary
		result.append({
			"event_kind": str(event.get(
				"engine_event_kind",
				event.get("event_kind", event.get("type", ""))
			)),
			"eight_ball_item_id": _phase_5c_event_item_id(event),
			"owned_item_instance_id": int(event.get("owned_item_instance_id", -1)),
			"trigger_id": str(event.get("trigger_id", "")),
			"trigger_occurrence_id": str(event.get("trigger_occurrence_id", "")),
			"trigger_ball_id": int(event.get("trigger_ball_id", -1)),
			"trigger_event_index": int(event.get("trigger_event_index", -1)),
			"tap_ordinal": int(event.get("tap_ordinal", 0)),
			"threshold": int(event.get("threshold", 0)),
			"target_family": str(event.get("target_family", "")),
			"retrigger_threshold_ordinal": int(event.get("retrigger_threshold_ordinal", 0)),
			"phase": str(event.get("phase", "")),
			"value": event.get("value", 0.0),
			"ball_id": int(event.get("ball_id", event.get("trigger_ball_id", -1))),
			"value_before": event.get("value_before", event.get("xmult_before", 0.0)),
			"value_after": event.get("value_after", event.get("xmult_after", 0.0)),
			"growth_amount": event.get("growth_amount", 0.0),
			"source": str(event.get("source", SOURCE_AUTHORITATIVE)),
			"family_id": str(event.get("family_id", "")),
			"supported": bool(event.get("supported", false)),
		})
	return result


func _compact_phase_5c_state_mutations(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in values:
		if not value is Dictionary or result.size() >= MAX_PHASE_5C_STATE_MUTATIONS_PER_SHOT:
			continue
		var mutation: Dictionary = value as Dictionary
		result.append({
			"eight_ball_item_id": _phase_5c_event_item_id(mutation),
			"owned_item_instance_id": int(mutation.get("owned_item_instance_id", -1)),
			"mutation_kind": str(mutation.get("mutation_kind", "")),
			"mutation_key": str(mutation.get("mutation_key", "")),
			"state_key": str(mutation.get("state_key", mutation.get("key", ""))),
			"value_before": mutation.get("value_before", 0),
			"value_after": mutation.get("value_after", 0),
			"state_before": _compact_phase_5c_state(_dictionary_value(
				mutation,
				"state_before"
			)),
			"state_after": _compact_phase_5c_state(_dictionary_value(
				mutation,
				"state_after"
			)),
			"growth_amount": mutation.get("growth_amount", 0.0),
			"trigger_occurrence_id": str(mutation.get("trigger_occurrence_id", "")),
			"source": str(mutation.get("source", SOURCE_AUTHORITATIVE)),
			"applied": bool(mutation.get("applied", false)),
		})
	return result


func _phase_5c_event_item_id(event: Dictionary) -> String:
	return str(event.get(
		"eight_ball_item_id",
		event.get("item_id", event.get("source_item_id", ""))
	))


func _activation_count_for_item(activations: Array[Dictionary], item_id: String) -> int:
	var count: int = 0
	for activation in activations:
		if _item_id(activation) == item_id:
			count += 1
	return count


func _counterfactual_uplift(counterfactuals: Dictionary, item_id: String) -> int:
	return int(_dictionary_value(counterfactuals, item_id).get("marginal_score_uplift", 0))


func _state_float(state: Dictionary, keys: Array[String], fallback: float) -> float:
	for key in keys:
		if state.has(key):
			return float(state[key])
	return fallback


func _array_alias(source: Dictionary, keys: Array[String]) -> Array:
	for key in keys:
		var value: Variant = source.get(key, [])
		if value is Array and not (value as Array).is_empty():
			return value as Array
	return []


func _make_empty_phase_5c_accumulator() -> Dictionary:
	return {
		"rattle": {
			"shots_owned": 0,
			"tap_milestones_grown_from": 0,
			"shots_activated": 0,
			"non_tap_shots_owned": 0,
			"acquired_value": 0.0,
			"current_xmult": 0.0,
			"final_xmult": 0.0,
			"lifetime_growth": 0,
			"marginal_score_uplift": 0,
		},
		"one_two_punch": {
			"shots_owned": 0,
			"qualifying_scoring_balls": 0,
			"activations": 0,
			"shots_with_only_one_family": 0,
			"marginal_score_uplift": 0,
		},
		"aftershock": {
			"shots_owned": 0,
			"tap_milestones_while_owned": 0,
			"ignored_first_milestones": 0,
			"xmult_activations": 0,
			"highest_tap_ordinal": 0,
			"marginal_score_uplift": 0,
		},
		"echo_chamber": {
			"shots_owned": 0,
			"threshold_milestones": 0,
			"supported_thresholds": 0,
			"unsupported_thresholds": 0,
			"regular_activations_retriggered": 0,
			"retriggers_by_family": {"double_tap": 0, "ball_tap": 0},
			"retriggered_add_haul": 0.0,
			"retriggered_add_mult": 0.0,
			"retriggered_xmult_activations": 0,
			"retriggered_xmult_product": 1.0,
			"marginal_score_uplift": 0,
			"round_support": {},
		},
		"state_history": [],
		"state_history_dropped": 0,
	}


func _add_phase_5c_summary(
	target: Dictionary,
	addition: Dictionary,
	shot_key: String,
	round_number: int
) -> void:
	if addition.is_empty():
		return
	var rattle_target: Dictionary = _dictionary_value(target, "rattle")
	var rattle: Dictionary = _dictionary_value(addition, "rattle")
	if bool(rattle.get("owned", false)):
		rattle_target["shots_owned"] = int(rattle_target.get("shots_owned", 0)) + 1
		rattle_target["tap_milestones_grown_from"] = int(rattle_target.get(
			"tap_milestones_grown_from",
			0
		)) + int(rattle.get("tap_milestones_grown_from", 0))
		if bool(rattle.get("activated_this_shot", false)):
			rattle_target["shots_activated"] = int(rattle_target.get("shots_activated", 0)) + 1
		if bool(rattle.get("non_tap_shot_while_owned", false)):
			rattle_target["non_tap_shots_owned"] = int(rattle_target.get(
				"non_tap_shots_owned",
				0
			)) + 1
		if float(rattle_target.get("acquired_value", 0.0)) <= 0.0:
			rattle_target["acquired_value"] = float(rattle.get("current_xmult_before", 1.0))
		rattle_target["current_xmult"] = float(rattle.get("current_xmult_after", 1.0))
		rattle_target["final_xmult"] = float(rattle.get("current_xmult_after", 1.0))
		rattle_target["lifetime_growth"] = maxi(
			int(rattle_target.get("lifetime_growth", 0)),
			int(rattle.get("lifetime_growth_after", 0))
		)
		rattle_target["marginal_score_uplift"] = int(rattle_target.get(
			"marginal_score_uplift",
			0
		)) + int(rattle.get("marginal_score_uplift", 0))
	target["rattle"] = rattle_target

	var punch_target: Dictionary = _dictionary_value(target, "one_two_punch")
	var punch: Dictionary = _dictionary_value(addition, "one_two_punch")
	if bool(punch.get("owned", false)):
		punch_target["shots_owned"] = int(punch_target.get("shots_owned", 0)) + 1
		punch_target["qualifying_scoring_balls"] = int(punch_target.get(
			"qualifying_scoring_balls",
			0
		)) + int(punch.get("qualifying_scoring_balls", 0))
		punch_target["activations"] = int(punch_target.get("activations", 0)) + int(
			punch.get("activations", 0)
		)
		if bool(punch.get("only_one_tap_family_present", false)):
			punch_target["shots_with_only_one_family"] = int(punch_target.get(
				"shots_with_only_one_family",
				0
			)) + 1
		punch_target["marginal_score_uplift"] = int(punch_target.get(
			"marginal_score_uplift",
			0
		)) + int(punch.get("marginal_score_uplift", 0))
	target["one_two_punch"] = punch_target

	var aftershock_target: Dictionary = _dictionary_value(target, "aftershock")
	var aftershock: Dictionary = _dictionary_value(addition, "aftershock")
	if bool(aftershock.get("owned", false)):
		aftershock_target["shots_owned"] = int(aftershock_target.get("shots_owned", 0)) + 1
		for key in [
			"tap_milestones_while_owned",
			"ignored_first_milestones",
			"xmult_activations",
			"marginal_score_uplift",
		]:
			aftershock_target[key] = int(aftershock_target.get(key, 0)) + int(
				aftershock.get(key, 0)
			)
		aftershock_target["highest_tap_ordinal"] = maxi(
			int(aftershock_target.get("highest_tap_ordinal", 0)),
			int(aftershock.get("highest_tap_ordinal", 0))
		)
	target["aftershock"] = aftershock_target

	var echo_target: Dictionary = _dictionary_value(target, "echo_chamber")
	var echo: Dictionary = _dictionary_value(addition, "echo_chamber")
	if bool(echo.get("owned", false)):
		echo_target["shots_owned"] = int(echo_target.get("shots_owned", 0)) + 1
		for key in [
			"threshold_milestones",
			"supported_thresholds",
			"unsupported_thresholds",
			"regular_activations_retriggered",
			"retriggered_xmult_activations",
			"marginal_score_uplift",
		]:
			echo_target[key] = int(echo_target.get(key, 0)) + int(echo.get(key, 0))
		for key in ["retriggered_add_haul", "retriggered_add_mult"]:
			echo_target[key] = float(echo_target.get(key, 0.0)) + float(echo.get(key, 0.0))
		echo_target["retriggered_xmult_product"] = float(echo_target.get(
			"retriggered_xmult_product",
			1.0
		)) * float(echo.get("retriggered_xmult_product", 1.0))
		var family_counts: Dictionary = _dictionary_value(
			echo_target,
			"retriggers_by_family"
		).duplicate(true)
		_add_counts(family_counts, _dictionary_value(echo, "retriggers_by_family"))
		echo_target["retriggers_by_family"] = family_counts
		var round_support: Dictionary = _dictionary_value(echo_target, "round_support").duplicate(true)
		round_support[str(round_number)] = bool(echo.get("has_regular_tap_support", false))
		echo_target["round_support"] = round_support
	target["echo_chamber"] = echo_target

	var history: Array = _array_value(target, "state_history")
	if not rattle.is_empty() and bool(rattle.get("owned", false)):
		if history.size() >= MAX_PHASE_5C_HISTORY_RECORDS:
			history.pop_front()
			target["state_history_dropped"] = int(target.get("state_history_dropped", 0)) + 1
		history.append({
			"shot_key": shot_key,
			"round_number": round_number,
			"owned_item_instance_id": int(rattle.get("owned_item_instance_id", -1)),
			"current_xmult_before": float(rattle.get("current_xmult_before", 1.0)),
			"current_xmult_after": float(rattle.get("current_xmult_after", 1.0)),
			"tap_milestones": int(rattle.get("tap_milestones_grown_from", 0)),
			"marginal_score_uplift": int(rattle.get("marginal_score_uplift", 0)),
		})
	target["state_history"] = history


func _summarize_dead_reckoning_shot(
	trigger_counts: Dictionary,
	activations: Array[Dictionary],
	build_snapshot: Dictionary
) -> Dictionary:
	var owned_item_ids: Array[String] = _string_array(build_snapshot.get(
		"item_ids_by_slot",
		[]
	))
	var dead_reckoning_owned: bool = owned_item_ids.has(DEAD_RECKONING_ITEM_ID)
	var support_item_ids: Array[String] = _get_dead_reckoning_support_ids(
		build_snapshot,
		owned_item_ids
	)
	var direct_occurrences: int = (
		maxi(int(trigger_counts.get(TRIGGER_DIRECT_POT, 0)), 0)
		if dead_reckoning_owned
		else 0
	)
	var summary: Dictionary = {
		"dead_reckoning_owned": dead_reckoning_owned,
		"has_support": not support_item_ids.is_empty(),
		"support_item_ids": support_item_ids,
		"direct_pot_occurrences_while_owned": direct_occurrences,
		"supported_occurrences": direct_occurrences if not support_item_ids.is_empty() else 0,
		"unsupported_occurrences": direct_occurrences if support_item_ids.is_empty() else 0,
		"dead_occurrences": direct_occurrences if support_item_ids.is_empty() else 0,
		"regular_activations_retriggered": 0,
		"retriggered_add_haul": 0.0,
		"retriggered_add_mult": 0.0,
		"retriggered_xmult_activations": 0,
		"retriggered_xmult_product": 1.0,
	}
	for activation in activations:
		if not bool(activation.get("is_retrigger", false)):
			continue
		if str(activation.get("retrigger_source_item_id", "")) != DEAD_RECKONING_ITEM_ID:
			continue
		summary["regular_activations_retriggered"] = int(
			summary["regular_activations_retriggered"]
		) + 1
		var phase: String = str(activation.get(
			"modifier_phase",
			activation.get("phase", "")
		))
		var value: float = float(activation.get(
			"applied_value",
			activation.get("value", 0.0)
		))
		match phase:
			"add_haul":
				summary["retriggered_add_haul"] = float(
					summary["retriggered_add_haul"]
				) + value
			"add_mult":
				summary["retriggered_add_mult"] = float(
					summary["retriggered_add_mult"]
				) + value
			"xmult":
				summary["retriggered_xmult_activations"] = int(
					summary["retriggered_xmult_activations"]
				) + 1
				summary["retriggered_xmult_product"] = float(
					summary["retriggered_xmult_product"]
				) * value
	return summary


func _get_dead_reckoning_support_ids(
	build_snapshot: Dictionary,
	owned_item_ids: Array[String]
) -> Array[String]:
	var support_ids: Array[String] = []
	var definitions: Array = _array_value(build_snapshot, "item_definitions_by_slot")
	for definition_value in definitions:
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value as Dictionary
		var item_id: String = str(definition.get("eight_ball_item_id", ""))
		if (
			item_id.is_empty()
			or item_id == DEAD_RECKONING_ITEM_ID
			or str(definition.get("family_id", "")) != FAMILY_DIRECT_POT
			or str(definition.get("effect_kind", "")) == EFFECT_KIND_RETRIGGER_FAMILY
		):
			continue
		if owned_item_ids.has(item_id) and not support_ids.has(item_id):
			support_ids.append(item_id)
	for item_id in DEAD_RECKONING_SUPPORT_ITEM_IDS:
		if owned_item_ids.has(item_id) and not support_ids.has(item_id):
			support_ids.append(item_id)
	return support_ids


func _add_dead_reckoning_summary(target_value: Variant, addition: Dictionary) -> void:
	if not target_value is Dictionary or addition.is_empty():
		return
	var target: Dictionary = target_value as Dictionary
	for key in [
		"direct_pot_occurrences_while_owned",
		"supported_occurrences",
		"unsupported_occurrences",
		"dead_occurrences",
		"regular_activations_retriggered",
		"retriggered_xmult_activations",
	]:
		target[key] = int(target.get(key, 0)) + int(addition.get(key, 0))
	for key in ["retriggered_add_haul", "retriggered_add_mult"]:
		target[key] = float(target.get(key, 0.0)) + float(addition.get(key, 0.0))
	target["retriggered_xmult_product"] = float(target.get(
		"retriggered_xmult_product",
		1.0
	)) * float(addition.get("retriggered_xmult_product", 1.0))


func _find_offer_record_index(source: Dictionary, context: Dictionary) -> int:
	var generation: int = int(context.get(
		"offer_generation",
		source.get("offer_generation", 0)
	))
	if generation > 0:
		var offer_key: String = _make_offer_key(active_run_generation, generation)
		if offer_record_index_by_key.has(offer_key):
			return int(offer_record_index_by_key[offer_key])
	for index in range(offer_records.size() - 1, -1, -1):
		if not bool(offer_records[index].get("resolved", false)):
			return index
	return -1


func _preserve_abandoned_attempts(restored_shot_keys: Dictionary) -> void:
	for record in shot_records:
		var shot_key: String = str(record.get("shot_key", ""))
		if shot_key.is_empty() or restored_shot_keys.has(shot_key):
			continue
		if abandoned_attempt_keys.has(shot_key):
			continue
		var abandoned: Dictionary = {
			"shot_key": shot_key,
			"run_generation": int(record.get("run_generation", -1)),
			"shot_id": int(record.get("shot_id", -1)),
			"attempt_id": int(record.get("attempt_id", -1)),
			"round_number": int(record.get("round_number", -1)),
			"final_score": int(record.get("final_score", 0)),
			"reason": "rewind_discarded_attempt",
			"abandoned_at_usec": Time.get_ticks_usec(),
		}
		abandoned_attempts.append(abandoned)
		abandoned_attempt_keys[shot_key] = true
		abandoned_attempt_count += 1
		while abandoned_attempts.size() > MAX_ABANDONED_ATTEMPTS:
			var removed: Dictionary = abandoned_attempts.pop_front()
			abandoned_attempt_keys.erase(str(removed.get("shot_key", "")))


func _abandon_active_run_internal(reason: String) -> Dictionary:
	var abandoned: Dictionary = {
		"run_generation": active_run_generation,
		"mode_id": active_mode_id,
		"reason": reason,
		"shot_count": shot_records.size(),
		"offer_count": offer_records.size(),
		"round_count": round_records.size(),
		"abandoned_at_unix": int(Time.get_unix_time_from_system()),
	}
	last_abandoned_run = abandoned.duplicate(true)
	session_abandoned_run_count += 1
	return abandoned


func _reset_current_run_state() -> void:
	active_run = false
	run_finalized = false
	active_run_generation = -1
	active_mode_id = ""
	run_started_at_unix = 0
	run_metadata.clear()
	initial_run_snapshot.clear()
	current_run_snapshot.clear()
	initial_build_snapshot.clear()
	current_build_snapshot.clear()
	shot_records.clear()
	offer_records.clear()
	round_records.clear()
	recorded_shot_keys.clear()
	offer_record_index_by_key.clear()
	round_record_index_by_key.clear()
	finalized_round_keys.clear()
	active_round_key = ""
	unkeyed_offer_serial = 0
	run_accumulators = _make_empty_run_accumulators()
	abandoned_attempts.clear()
	abandoned_attempt_keys.clear()


func _reset_current_run_diagnostics() -> void:
	accepted_shot_count = 0
	accepted_offer_count = 0
	resolved_offer_count = 0
	accepted_round_start_count = 0
	accepted_round_finalization_count = 0
	duplicate_shot_suppressions = 0
	duplicate_offer_suppressions = 0
	duplicate_offer_resolution_suppressions = 0
	duplicate_round_start_suppressions = 0
	duplicate_round_finalization_suppressions = 0
	duplicate_run_finalization_suppressions = 0
	rejected_record_count = 0
	rejected_records_by_reason.clear()
	recent_rejections.clear()
	value_reference_rejections = 0
	shot_history_overflow_count = 0
	offer_history_overflow_count = 0
	round_history_overflow_count = 0
	rewind_restore_count = 0
	abandoned_attempt_count = 0
	auto_started_round_count = 0
	auto_finalized_round_count = 0
	unfinalized_round_transition_count = 0
	missing_base_score_result_count = 0
	incomplete_counterfactual_shot_count = 0
	incomplete_eligible_pool_count = 0
	last_operation = ""
	last_error = ""


func _make_empty_run_accumulators() -> Dictionary:
	return {
		"total_shots": 0,
		"total_authoritative_score": 0,
		"total_base_score_without_build": 0,
		"base_score_available_shots": 0,
		"total_build_uplift": 0,
		"total_doubloons_from_base_haul": 0,
		"total_scoring_balls_pocketed": 0,
		"zero_score_shots": 0,
		"scratches": 0,
		"highest_shot": 0,
		"maximum_haul": 0,
		"maximum_mult": 1.0,
		"maximum_xmult_product": 1.0,
		"maximum_global_excitement": 0.0,
		"trigger_counts": {},
		"tap_metrics": _make_empty_tap_accumulator(),
		"phase_5c_tap_items": _make_empty_phase_5c_accumulator(),
		"dead_reckoning": {
			"direct_pot_occurrences_while_owned": 0,
			"supported_occurrences": 0,
			"unsupported_occurrences": 0,
			"dead_occurrences": 0,
			"regular_activations_retriggered": 0,
			"retriggered_add_haul": 0.0,
			"retriggered_add_mult": 0.0,
			"retriggered_xmult_activations": 0,
			"retriggered_xmult_product": 1.0,
		},
	}


func _rebuild_shot_keys() -> void:
	recorded_shot_keys.clear()
	for record in shot_records:
		var shot_key: String = str(record.get("shot_key", ""))
		if not shot_key.is_empty():
			recorded_shot_keys[shot_key] = true


func _rebuild_round_indices() -> void:
	round_record_index_by_key.clear()
	finalized_round_keys.clear()
	for index in range(round_records.size()):
		var record: Dictionary = round_records[index]
		var round_key: String = str(record.get("round_key", ""))
		if round_key.is_empty():
			continue
		round_record_index_by_key[round_key] = index
		if bool(record.get("finalized", false)):
			finalized_round_keys[round_key] = true


func _score_result_matches_ledger(result: Dictionary, ledger: Dictionary) -> bool:
	return (
		int(result.get("run_generation", -2)) == int(ledger.get("run_generation", -1))
		and int(result.get("shot_id", -2)) == int(ledger.get("shot_id", -1))
		and int(result.get("attempt_id", -2)) == int(ledger.get("attempt_id", -1))
		and str(result.get("mode_id", "")) == str(ledger.get("mode_id", ""))
	)


func _object_ball_pocket_count(derived: Dictionary) -> int:
	if derived.has("object_ball_pocket_count"):
		return maxi(int(derived.get("object_ball_pocket_count", 0)), 0)
	return _array_value(derived, "object_balls_pocketed").size()


func _maximum_bank_tier(occurrences: Array[Dictionary], derived: Dictionary) -> int:
	var maximum_tier: int = maxi(int(derived.get("maximum_bank_count", 0)), 0)
	for occurrence in occurrences:
		maximum_tier = maxi(maximum_tier, int(occurrence.get("milestone_tier", 0)))
	return maximum_tier


func _count_trigger_occurrences(occurrences: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for occurrence in occurrences:
		var trigger_id: String = str(occurrence.get("trigger_id", ""))
		if not trigger_id.is_empty():
			counts[trigger_id] = int(counts.get(trigger_id, 0)) + 1
	return counts


func _add_counts(target: Dictionary, additions: Dictionary) -> void:
	for key_value in additions.keys():
		var key: String = str(key_value)
		target[key] = int(target.get(key, 0)) + int(additions[key_value])


func _item_ids_from_definitions(definitions: Array[Dictionary]) -> Array[String]:
	var item_ids: Array[String] = []
	for definition in definitions:
		var item_id: String = _item_id(definition)
		if not item_id.is_empty():
			item_ids.append(item_id)
	return item_ids


func _item_id(definition: Dictionary) -> String:
	return str(definition.get("eight_ball_item_id", definition.get("id", "")))


func _make_shot_key(run_generation: int, attempt_id: int) -> String:
	return "run:%d|attempt:%d" % [run_generation, attempt_id]


func _make_offer_key(run_generation: int, offer_generation: int) -> String:
	return "run:%d|offer:%d" % [run_generation, offer_generation]


func _make_unkeyed_offer_key(run_generation: int, serial: int) -> String:
	return "run:%d|offer:unkeyed:%d" % [run_generation, serial]


func _make_round_key(run_generation: int, round_number: int) -> String:
	return "run:%d|round:%d" % [run_generation, round_number]


func _timestamp_from_context(context: Dictionary) -> int:
	if context.has("timestamp_unix"):
		return int(context.get("timestamp_unix", 0))
	return int(Time.get_unix_time_from_system())


func _histories_are_complete() -> bool:
	return (
		shot_history_overflow_count == 0
		and offer_history_overflow_count == 0
		and round_history_overflow_count == 0
	)


func _inputs_are_value_only(values: Array) -> bool:
	for value in values:
		if _contains_live_reference(value):
			return false
	return true


func _contains_live_reference(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_VALUE_DEPTH:
		return true
	if value is Object or typeof(value) in [TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		return true
	if value is Dictionary:
		var dictionary: Dictionary = value as Dictionary
		for key_value in dictionary.keys():
			if _contains_live_reference(key_value, depth + 1):
				return true
			if _contains_live_reference(dictionary[key_value], depth + 1):
				return true
	elif value is Array:
		for child_value in value as Array:
			if _contains_live_reference(child_value, depth + 1):
				return true
	return false


func _reject(operation: String, reason: String, context: Dictionary = {}) -> Dictionary:
	rejected_record_count += 1
	rejected_records_by_reason[reason] = int(rejected_records_by_reason.get(reason, 0)) + 1
	last_operation = operation
	last_error = reason
	var rejection: Dictionary = {
		"operation": operation,
		"reason": reason,
		"run_generation": int(context.get("run_generation", active_run_generation)),
		"shot_id": int(context.get("shot_id", -1)),
		"attempt_id": int(context.get("attempt_id", -1)),
		"round_number": int(context.get("round_number", -1)),
		"offer_generation": int(context.get("offer_generation", -1)),
		"mode_id": str(context.get("mode_id", active_mode_id)),
		"timestamp_usec": Time.get_ticks_usec(),
	}
	recent_rejections.append(rejection)
	while recent_rejections.size() > MAX_RECENT_REJECTIONS:
		recent_rejections.pop_front()
	return {"accepted": false, "duplicate": false, "reason": reason}


func _duplicate_result(operation: String, identity_key: String) -> Dictionary:
	last_operation = operation
	last_error = "duplicate"
	return {
		"accepted": false,
		"duplicate": true,
		"reason": "duplicate",
		"identity_key": identity_key,
	}


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return (value as Dictionary) if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return (value as Array) if value is Array else []


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry in value as Array:
			result.append(str(entry))
	return result
