extends RefCounted
class_name RogueliteBalanceAnalyzer

# Pure, value-only aggregation for a completed Long Sink telemetry snapshot.
# It never queries scenes or gameplay systems and never mutates its input.
# Telemetry v1 accepts compact `shots`, `rounds`, and `offers` arrays. Per-shot
# leave-one-out data may be supplied directly or in the collector's compact
# `item_counterfactual_scores` records.

const REPORT_SCHEMA_VERSION := 1
const TELEMETRY_SCHEMA_VERSION := 1
const MODE_ROGUELITE := "roguelite"
const MODE_SHOT_LAB := "shot_lab"
const MODE_PASSAGE := "passage"

const TRIGGER_SINGLE_BANK := "single_bank_milestone"
const TRIGGER_DOUBLE_BANK := "double_bank_milestone"
const TRIGGER_TRIPLE_BANK := "triple_bank_milestone"
const TRIGGER_COMBINATION := "combination_pot"
const TRIGGER_DIRECT_POT := "direct_pot"
const TRIGGER_MULTI_POT := "multi_pot_shot"
const TRIGGER_SAME_POCKET := "same_pocket_streak"
const TRIGGER_CUE_RECONTACT := "cue_recontact_milestone"
const TRIGGER_OBJECT_BALL_TAP := "object_ball_tap_milestone"

const FAMILY_SINGLE_BANK := "single_bank"
const FAMILY_DOUBLE_BANK := "double_bank"
const FAMILY_TRIPLE_BANK := "triple_bank"
const FAMILY_COMBINATION := "combination"
const FAMILY_DIRECT_POT := "direct_pot"
const FAMILY_MULTI_POT := "multi_pot"
const FAMILY_SAME_POCKET := "same_pocket"
const FAMILY_CUE_RECONTACT := "cue_recontact"
const FAMILY_DOUBLE_TAP := "double_tap"
const FAMILY_BALL_TAP := "ball_tap"
const FAMILY_TAP_ODDITY := "tap_oddity"
const FAMILY_UNKNOWN := "unknown"

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

const PHASE_ADD_HAUL := "add_haul"
const PHASE_ADD_MULT := "add_mult"
const PHASE_XMULT := "xmult"

const WATCH_SINGLE_BANK_DOMINANCE := "single_bank_dominance"
const WATCH_ONE_SHOT_CONCENTRATION := "one_shot_concentration"
const WATCH_QUOTA_UNDERPRESSURE := "quota_underpressure"
const WATCH_DEAD_ITEM := "dead_item"
const WATCH_OFFER_BIAS := "offer_bias"
const WATCH_TAP_EXPLOIT := "tap_exploit"
const WATCH_CONTACT_FARM := "contact_farm"

const SINGLE_BANK_DOMINANCE_SHARE := 0.60
const ONE_SHOT_CONCENTRATION_SHARE := 0.40
const QUOTA_UNDERPRESSURE_STREAK := 3
const DEAD_ITEM_MIN_FULL_ROUNDS := 2
const OFFER_BIAS_SHARE := 0.50
const OFFER_BIAS_MIN_CARDS := 6

# Diagnostic-only thresholds. They never alter scoring or contact acceptance.
const TAP_EXPLOIT_MAX_CUE_STRIKES_PER_BALL := 6
const CONTACT_FARM_MIN_REPEATED_CONTACTS_PER_SHOT := 4
const CONTACT_FARM_REPEATED_TO_UNIQUE_RATIO := 2.0
const MAX_WATCH_EXAMPLE_SHOTS := 12
const MAX_PHASE_5C_STATE_HISTORY := 120

const IDENTITY_DOMINANT_SHARE := 0.45
const IDENTITY_HYBRID_SHARE := 0.25

const LOW_SHOT_MAX := 99
const MEDIUM_SHOT_MAX := 499


static func analyze(completed_telemetry_snapshot: Dictionary) -> Dictionary:
	var started_at_usec: int = Time.get_ticks_usec()
	var report: Dictionary = _make_empty_report(completed_telemetry_snapshot)
	var warnings: Array[String] = []
	var diagnostics: Dictionary = report["diagnostics"]

	if _contains_object_reference(completed_telemetry_snapshot):
		warnings.append("Telemetry contains an Object reference; value-only analysis was rejected.")
		return _finalize_report(report, warnings, started_at_usec)

	var schema_version: int = int(completed_telemetry_snapshot.get("schema_version", -1))
	if schema_version != TELEMETRY_SCHEMA_VERSION:
		warnings.append("Unsupported or missing balance telemetry schema version.")
		return _finalize_report(report, warnings, started_at_usec)

	var mode_id: String = str(completed_telemetry_snapshot.get("mode_id", ""))
	var run_metadata: Dictionary = _dictionary_value(
		completed_telemetry_snapshot,
		"run_metadata"
	)
	var balance_tuning: Dictionary = _dictionary_value(run_metadata, "balance_tuning")
	diagnostics["active_balance_tuning"] = balance_tuning.duplicate(true)
	diagnostics["debug_balance_overrides_active"] = bool(balance_tuning.get(
		"has_overrides",
		false
	))
	var shot_lab_enabled: bool = bool(completed_telemetry_snapshot.get(
		"include_shot_lab_telemetry",
		completed_telemetry_snapshot.get("telemetry_debug_enabled", false)
	))
	if mode_id == MODE_PASSAGE:
		report["excluded"] = true
		report["exclusion_reason"] = "passage_excluded"
		return _finalize_report(report, warnings, started_at_usec)
	if mode_id == MODE_SHOT_LAB and not shot_lab_enabled:
		report["excluded"] = true
		report["exclusion_reason"] = "shot_lab_telemetry_disabled"
		return _finalize_report(report, warnings, started_at_usec)
	if mode_id != MODE_ROGUELITE and mode_id != MODE_SHOT_LAB:
		report["excluded"] = true
		report["exclusion_reason"] = "unsupported_mode"
		warnings.append("Balance telemetry mode is unsupported.")
		return _finalize_report(report, warnings, started_at_usec)
	if not bool(completed_telemetry_snapshot.get("finalized", false)):
		warnings.append("Telemetry snapshot is not finalized; derived metrics are provisional.")

	var shots: Array[Dictionary] = _get_accepted_shots(completed_telemetry_snapshot, diagnostics)
	var rounds: Array[Dictionary] = _aggregate_rounds(
		completed_telemetry_snapshot,
		shots,
		diagnostics
	)
	var offers: Dictionary = _aggregate_offers(completed_telemetry_snapshot)
	var items: Array[Dictionary] = _aggregate_items(
		completed_telemetry_snapshot,
		shots,
		rounds,
		offers,
		diagnostics
	)
	var dead_reckoning: Dictionary = _aggregate_dead_reckoning(shots, rounds, items)
	var triggers: Dictionary = _aggregate_triggers(shots)
	var tap_metrics: Dictionary = _aggregate_taps(shots, triggers)
	var phase_5c_tap_items: Dictionary = _aggregate_phase_5c_tap_items(
		completed_telemetry_snapshot,
		shots,
		rounds,
		items
	)
	var run_summary: Dictionary = _aggregate_run_summary(
		completed_telemetry_snapshot,
		shots,
		rounds,
		items,
		tap_metrics
	)
	var attribution: Dictionary = _aggregate_attribution(shots, items, run_summary, diagnostics)
	var build_identity: Dictionary = _classify_build(items, attribution, phase_5c_tap_items)
	var shot_distribution: Dictionary = _build_shot_distribution(shots)
	var watch_flags: Array[Dictionary] = _build_watch_flags(
		run_summary,
		rounds,
		items,
		offers,
		attribution,
		tap_metrics
	)
	var shot_metrics: Array[Dictionary] = _build_shot_metrics(shots)

	report["input_valid"] = true
	report["run_summary"] = run_summary
	report["shot_metrics"] = shot_metrics
	report["round_metrics"] = rounds
	report["item_metrics"] = items
	report["dead_reckoning_metrics"] = dead_reckoning
	report["trigger_metrics"] = triggers
	report["tap_metrics"] = tap_metrics
	report["phase_5c_tap_items"] = phase_5c_tap_items
	report["offer_metrics"] = offers
	report["attribution"] = attribution
	report["build_identity"] = build_identity
	report["shot_distribution"] = shot_distribution
	report["watch_flags"] = watch_flags
	diagnostics["accepted_shot_count"] = shots.size()
	diagnostics["accepted_round_count"] = rounds.size()
	diagnostics["item_metric_count"] = items.size()
	diagnostics["dead_reckoning_owned"] = bool(dead_reckoning.get("owned", false))
	diagnostics["dead_reckoning_retriggers"] = int(dead_reckoning.get(
		"regular_activations_retriggered",
		0
	))
	diagnostics["cue_recontact_milestones"] = int(tap_metrics.get(
		"cue_recontact_milestones",
		0
	))
	diagnostics["ball_tap_milestones"] = int(tap_metrics.get("ball_tap_milestones", 0))
	diagnostics["phase_5c_state_history_records"] = _dictionary_array_value(
		phase_5c_tap_items,
		"state_history"
	).size()
	diagnostics["echo_chamber_thresholds"] = int(_dictionary_value(
		phase_5c_tap_items,
		"echo_chamber"
	).get("threshold_milestones", 0))
	diagnostics["watch_flag_count"] = watch_flags.size()
	diagnostics["attribution_method"] = "deterministic_leave_one_item_out"
	diagnostics["interaction_method"] = (
		"build_uplift_minus_sum_of_item_leave_one_out_marginals"
	)
	diagnostics["no_live_node_references"] = true

	return _finalize_report(report, warnings, started_at_usec)


static func _make_empty_report(snapshot: Dictionary) -> Dictionary:
	return {
		"schema_version": REPORT_SCHEMA_VERSION,
		"source": "roguelite_balance_analyzer",
		"telemetry_schema_version": int(snapshot.get("schema_version", -1)),
		"mode_id": str(snapshot.get("mode_id", "")),
		"run_generation": int(snapshot.get("run_generation", -1)),
		"finalized": bool(snapshot.get("finalized", false)),
		"input_valid": false,
		"excluded": false,
		"exclusion_reason": "",
		"run_summary": _empty_run_summary(snapshot),
		"shot_metrics": [],
		"round_metrics": [],
		"item_metrics": [],
		"dead_reckoning_metrics": _empty_dead_reckoning_metrics(),
		"trigger_metrics": _empty_trigger_metrics(),
		"tap_metrics": _empty_tap_metrics(),
		"phase_5c_tap_items": _empty_phase_5c_metrics(),
		"offer_metrics": _empty_offer_metrics(),
		"attribution": _empty_attribution(),
		"build_identity": {
			"label": "Unformed Build",
			"reason": "No analyzed build contribution or activation data.",
			"family_uplift": {},
			"family_uplift_share": {},
			"family_activation_share": {},
		},
		"shot_distribution": {
			"zero": 0,
			"low": 0,
			"medium": 0,
			"high": 0,
			"largest_shot": 0,
			"largest_shot_concentration": 0.0,
		},
		"watch_flags": [],
		"warnings": [],
		"diagnostics": {
			"input_shot_count": 0,
			"accepted_shot_count": 0,
			"rewound_or_discarded_shots_ignored": 0,
			"non_authoritative_shots_ignored": 0,
			"duplicate_shot_keys_ignored": 0,
			"duplicate_round_records_ignored": 0,
			"missing_item_counterfactuals": 0,
			"available_item_counterfactuals": 0,
			"accepted_attempt_ids": [],
		},
		"analysis_duration_usec": 0,
		"copy_summary": "",
		"copy_item_contribution_table": "",
		"copy_round_table": "",
		"copy_json": "",
		"json_data": {},
	}


static func _empty_run_summary(snapshot: Dictionary) -> Dictionary:
	return {
		"rounds_reached": 0,
		"final_outcome": str(snapshot.get("final_outcome", "")),
		"total_authoritative_score": 0,
		"total_base_score_without_build": 0,
		"total_build_uplift": 0,
		"build_uplift_percentage": 0.0,
		"total_doubloons_from_base_haul": 0,
		"total_scoring_balls_pocketed": 0,
		"total_shots": 0,
		"zero_score_shots": 0,
		"scratches": 0,
		"highest_shot": 0,
		"average_shot": 0.0,
		"median_shot": 0.0,
		"largest_shot_percentage": 0.0,
		"maximum_haul": 0,
		"maximum_mult": 1.0,
		"maximum_xmult_product": 1.0,
		"maximum_global_excitement": 0.0,
		"final_tray": _normalize_item_ids(snapshot.get("final_tray", [])),
		"most_valuable_item": {},
		"most_frequently_triggered_item": {},
		"least_triggered_owned_item": {},
		"tap_metrics": _empty_tap_metrics(),
	}


static func _empty_attribution() -> Dictionary:
	return {
		"method": "deterministic_leave_one_item_out",
		"total_build_uplift": 0,
		"total_item_marginal_uplift": 0,
		"interaction_surplus": 0,
		"interaction_note": (
			"Interaction surplus is full build uplift minus summed leave-one-item-out "
			+ "marginals. It may be negative when item effects overlap."
		),
		"counterfactuals_available": 0,
		"counterfactuals_missing": 0,
		"attribution_complete": true,
	}


static func _empty_trigger_metrics() -> Dictionary:
	return {
		"families": {
			FAMILY_SINGLE_BANK: _empty_trigger_family(TRIGGER_SINGLE_BANK),
			FAMILY_DOUBLE_BANK: _empty_trigger_family(TRIGGER_DOUBLE_BANK),
			FAMILY_TRIPLE_BANK: _empty_trigger_family(TRIGGER_TRIPLE_BANK),
			FAMILY_COMBINATION: _empty_trigger_family(TRIGGER_COMBINATION),
			FAMILY_DIRECT_POT: _empty_trigger_family(TRIGGER_DIRECT_POT),
			FAMILY_MULTI_POT: _empty_trigger_family(TRIGGER_MULTI_POT),
			FAMILY_SAME_POCKET: _empty_trigger_family(TRIGGER_SAME_POCKET),
			FAMILY_CUE_RECONTACT: _empty_trigger_family(TRIGGER_CUE_RECONTACT),
			FAMILY_BALL_TAP: _empty_trigger_family(TRIGGER_OBJECT_BALL_TAP),
		},
		"single_per_double": 0.0,
		"single_per_triple": 0.0,
		"double_per_triple": 0.0,
		"ratio_availability": {
			"single_per_double": false,
			"single_per_triple": false,
			"double_per_triple": false,
		},
		"total_bank_milestone_occurrences": 0,
		"cumulative_bank_activation_expansion": 0,
	}


static func _empty_tap_metrics() -> Dictionary:
	return {
		"shots_with_double_tap": 0,
		"shots_with_triple_tap_or_higher": 0,
		"cue_recontact_milestones": 0,
		"qualifying_cue_strike_count": 0,
		"maximum_cue_strikes_against_one_scoring_ball": 0,
		"maximum_cue_recontact_milestones_in_one_shot": 0,
		"scoring_balls_with_double_tap": 0,
		"scoring_balls_with_triple_tap_or_higher": 0,
		"average_double_tap_mult": 0.0,
		"average_cue_recontact_mult_per_scoring_ball": 0.0,
		"ball_tap_milestones": 0,
		"unique_ball_tap_target_count": 0,
		"maximum_ball_taps_by_one_scoring_ball": 0,
		"maximum_ball_tap_milestones_in_one_shot": 0,
		"scoring_balls_with_ball_tap": 0,
		"average_ball_tap_mult": 0.0,
		"repeated_ball_tap_contacts_ignored": 0,
		"ambiguous_cue_contacts_rejected": 0,
		"ambiguous_ball_tap_contacts_rejected": 0,
		"ambiguous_tap_contacts_rejected": 0,
		"tap_direct_pot_disqualifications": 0,
		"cue_recontact_score_supplied": 0,
		"double_tap_score_supplied": 0,
		"ball_tap_score_supplied": 0,
		"total_tap_score_supplied": 0,
		"score_supply_method": "immediate_base_resolution_step_score_delta",
		"bank_milestone_occurrences": 0,
		"combination_occurrences": 0,
		"frequency_comparison": {
			"cue_recontact_shot_frequency": 0.0,
			"ball_tap_shot_frequency": 0.0,
			"bank_shot_frequency": 0.0,
			"combination_shot_frequency": 0.0,
			"cue_recontact_to_bank_occurrence_ratio": 0.0,
			"ball_tap_to_bank_occurrence_ratio": 0.0,
			"cue_recontact_to_combination_ratio": 0.0,
			"ball_tap_to_combination_ratio": 0.0,
		},
		"tap_exploit_candidate_shots": [],
		"tap_exploit_candidate_shot_count": 0,
		"contact_farm_candidate_shots": [],
		"contact_farm_candidate_shot_count": 0,
		"watch_thresholds": {
			"tap_exploit_max_cue_strikes_per_ball": TAP_EXPLOIT_MAX_CUE_STRIKES_PER_BALL,
			"contact_farm_min_repeated_contacts_per_shot": CONTACT_FARM_MIN_REPEATED_CONTACTS_PER_SHOT,
			"contact_farm_repeated_to_unique_ratio": CONTACT_FARM_REPEATED_TO_UNIQUE_RATIO,
		},
	}


static func _empty_phase_5c_metrics() -> Dictionary:
	return {
		"rattle": {
			"eight_ball_item_id": RATTLE_ITEM_ID,
			"display_name": "Rattle of the Deep",
			"owned": false,
			"shots_owned": 0,
			"acquired_value": 0.0,
			"current_xmult": 0.0,
			"final_xmult": 0.0,
			"tap_milestones_grown_from": 0,
			"lifetime_growth": 0,
			"shots_activated": 0,
			"non_tap_shots_owned": 0,
			"marginal_score_uplift": 0,
			"owned_item_instance_ids": [],
		},
		"one_two_punch": {
			"eight_ball_item_id": ONE_TWO_PUNCH_ITEM_ID,
			"display_name": "One-Two Punch",
			"owned": false,
			"shots_owned": 0,
			"qualifying_scoring_balls": 0,
			"activations": 0,
			"shots_with_only_one_family": 0,
			"marginal_score_uplift": 0,
		},
		"aftershock": {
			"eight_ball_item_id": AFTERSHOCK_ITEM_ID,
			"display_name": "Aftershock",
			"owned": false,
			"shots_owned": 0,
			"tap_milestones_while_owned": 0,
			"ignored_first_milestones": 0,
			"xmult_activations": 0,
			"highest_tap_ordinal": 0,
			"marginal_score_uplift": 0,
		},
		"echo_chamber": {
			"eight_ball_item_id": ECHO_CHAMBER_ITEM_ID,
			"display_name": "Echo Chamber",
			"owned": false,
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
			"rounds_owned_with_support": 0,
			"rounds_owned_without_support": 0,
			"round_numbers_owned_with_support": [],
			"round_numbers_owned_without_support": [],
			"support_item_ids_seen": [],
			"marginal_score_uplift": 0,
		},
		"state_history": [],
		"state_history_dropped": 0,
		"bounded_history_limit": MAX_PHASE_5C_STATE_HISTORY,
	}


static func _empty_trigger_family(trigger_id: String) -> Dictionary:
	return {
		"trigger_id": trigger_id,
		"milestone_occurrences": 0,
		"shots_containing": 0,
		"owned_item_activations": 0,
		"regular_item_activations": 0,
		"retriggered_item_activations": 0,
		"score_from_shots_containing": 0,
		"average_score_from_shots_containing": 0.0,
	}


static func _empty_dead_reckoning_metrics() -> Dictionary:
	return {
		"eight_ball_item_id": DEAD_RECKONING_ITEM_ID,
		"display_name": "Dead Reckoning",
		"owned": false,
		"shots_owned": 0,
		"direct_pot_occurrences_while_owned": 0,
		"supported_occurrences": 0,
		"unsupported_occurrences": 0,
		"dead_occurrences": 0,
		"regular_activations_retriggered": 0,
		"retriggered_add_haul": 0.0,
		"retriggered_add_mult": 0.0,
		"retriggered_xmult_activations": 0,
		"retriggered_xmult_product": 1.0,
		"marginal_score_uplift": 0,
		"counterfactual_shots": 0,
		"rounds_owned_without_support": 0,
		"round_numbers_owned_without_support": [],
		"support_item_ids_seen": [],
	}


static func _empty_offer_metrics() -> Dictionary:
	return {
		"screen_count": 0,
		"offer_screen_count": 0,
		"total_offer_cards": 0,
		"selection_count": 0,
		"offer_count_by_item": {},
		"offer_count_by_family": {},
		"selection_count_by_item": {},
		"selection_count_by_family": {},
		"selection_rate_by_item": {},
		"selection_rate_by_family": {},
		"average_round_acquired_by_item": {},
		"average_rounds_retained_by_item": {},
		"replacement_count": 0,
		"skip_count": 0,
		"full_tray_count": 0,
		"full_tray_frequency": 0.0,
		"unowned_eligible_pool_size_by_round": [],
		"average_unowned_eligible_pool_size": 0.0,
		"item_details": {},
		"family_offer_share": {},
		"by_item": {},
		"by_family": {},
		"generation_diagnostics": [],
	}


static func _get_accepted_shots(snapshot: Dictionary, diagnostics: Dictionary) -> Array[Dictionary]:
	var input_shots: Array[Dictionary] = _dictionary_array_alias(
		snapshot,
		["shots", "completed_shots", "shot_entries"]
	)
	diagnostics["input_shot_count"] = input_shots.size()
	var accepted: Array[Dictionary] = []
	var seen_keys: Dictionary = {}
	var attempt_ids: Array[int] = []
	for shot_index in range(input_shots.size()):
		var shot: Dictionary = input_shots[shot_index]
		if bool(shot.get("rewound", false)) or bool(shot.get("discarded", false)):
			diagnostics["rewound_or_discarded_shots_ignored"] = int(
				diagnostics.get("rewound_or_discarded_shots_ignored", 0)
			) + 1
			continue
		var status: String = str(shot.get("status", ""))
		if status == "rewound" or status == "discarded" or status == "abandoned":
			diagnostics["rewound_or_discarded_shots_ignored"] = int(
				diagnostics.get("rewound_or_discarded_shots_ignored", 0)
			) + 1
			continue
		var source: String = str(shot.get("source", "authoritative"))
		if source != "authoritative" and source != MODE_SHOT_LAB:
			diagnostics["non_authoritative_shots_ignored"] = int(
				diagnostics.get("non_authoritative_shots_ignored", 0)
			) + 1
			continue
		var shot_id: int = int(shot.get("shot_id", shot_index))
		var attempt_id: int = int(shot.get("attempt_id", shot_id))
		var key: String = "%d|%d" % [shot_id, attempt_id]
		if seen_keys.has(key):
			diagnostics["duplicate_shot_keys_ignored"] = int(
				diagnostics.get("duplicate_shot_keys_ignored", 0)
			) + 1
			continue
		seen_keys[key] = true
		attempt_ids.append(attempt_id)
		accepted.append(shot.duplicate(true))
	accepted.sort_custom(_shot_precedes)
	diagnostics["accepted_attempt_ids"] = attempt_ids
	return accepted


static func _aggregate_rounds(
	snapshot: Dictionary,
	shots: Array[Dictionary],
	diagnostics: Dictionary
) -> Array[Dictionary]:
	var explicit_rounds: Array[Dictionary] = _dictionary_array_alias(
		snapshot,
		["rounds", "round_records", "completed_rounds"]
	)
	var source_by_round: Dictionary = {}
	for round_record in explicit_rounds:
		var round_number: int = int(round_record.get("round_number", 0))
		if round_number <= 0:
			continue
		if source_by_round.has(round_number):
			diagnostics["duplicate_round_records_ignored"] = int(
				diagnostics.get("duplicate_round_records_ignored", 0)
			) + 1
		# A later finalized snapshot supersedes an earlier copy of the same round.
		source_by_round[round_number] = round_record.duplicate(true)

	for shot in shots:
		var round_number: int = maxi(int(shot.get("round_number", 1)), 1)
		if not source_by_round.has(round_number):
			source_by_round[round_number] = {"round_number": round_number}

	var round_numbers: Array[int] = []
	for round_number_value in source_by_round.keys():
		round_numbers.append(int(round_number_value))
	round_numbers.sort()

	var rounds: Array[Dictionary] = []
	for round_number in round_numbers:
		var source: Dictionary = source_by_round[round_number]
		var round_shots: Array[Dictionary] = []
		for shot in shots:
			if maxi(int(shot.get("round_number", 1)), 1) == round_number:
				round_shots.append(shot)
		var calculated_score: int = _sum_shot_scores(round_shots)
		var round_score: int = (
			maxi(int(source.get("round_score", 0)), 0)
			if source.has("round_score")
			else calculated_score
		)
		var quota: int = maxi(int(source.get("quota", source.get("round_target", 0))), 0)
		var starting_shots: int = maxi(int(source.get(
			"starting_shots",
			source.get("shots_available", 0)
		)), 0)
		var shots_used: int = maxi(int(source.get("shots_used", round_shots.size())), 0)
		var highest_shot: int = _highest_shot(round_shots)
		var zero_score_shots: int = _zero_score_shot_count(round_shots)
		var trigger_counts: Dictionary = (
			_dictionary_value(source, "trigger_counts")
			if source.has("trigger_counts")
			else _sum_trigger_counts(round_shots)
		)
		var build_uplift: int = _sum_build_uplift(round_shots)
		var overflow: int = maxi(round_score - quota, 0)
		rounds.append({
			"round_number": round_number,
			"quota": quota,
			"starting_hull": maxi(int(source.get("starting_hull", 0)), 0),
			"starting_shots": starting_shots,
			"balls_spawned": maxi(int(source.get("balls_spawned", 0)), 0),
			"round_score": round_score,
			"score_overflow": overflow,
			"shots_used": shots_used,
			"zero_score_shots": zero_score_shots,
			"highest_shot": highest_shot,
			"average_shot": _safe_ratio(float(round_score), float(shots_used)),
			"trigger_counts": trigger_counts.duplicate(true),
			"build_at_round_start": _normalize_build_item_ids(source.get("build_at_round_start", [])),
			"build_at_round_end": _normalize_build_item_ids(source.get("build_at_round_end", [])),
			"outcome": str(source.get("outcome", "")),
			"failure_reason": str(source.get("failure_reason", "")),
			"quota_completion_ratio": _safe_ratio(float(round_score), float(quota)),
			"score_per_available_shot": _safe_ratio(float(round_score), float(starting_shots)),
			"required_average_score_per_shot": _safe_ratio(float(quota), float(starting_shots)),
			"actual_average_score_per_shot": _safe_ratio(float(round_score), float(shots_used)),
			"build_uplift_over_base_scoring": build_uplift,
			"largest_shot_percentage_of_round": _safe_ratio(
				float(highest_shot) * 100.0,
				float(round_score)
			),
		})
	return rounds


static func _aggregate_offers(snapshot: Dictionary) -> Dictionary:
	var metrics: Dictionary = _empty_offer_metrics()
	var screens: Array[Dictionary] = _dictionary_array_alias(
		snapshot,
		["reward_screens", "offer_events", "offers"]
	)
	var acquisition_rounds: Dictionary = {}
	var retained_rounds: Dictionary = {}
	for screen in screens:
		metrics["screen_count"] = int(metrics["screen_count"]) + 1
		metrics["offer_screen_count"] = int(metrics["screen_count"])
		var round_number: int = maxi(int(screen.get(
			"round_number",
			screen.get("round_after", 0)
		)), 0)
		var offered_items: Array[Dictionary] = _normalize_offer_items(screen)
		var selected_id: String = str(screen.get(
			"selected_item_id",
			screen.get("selected_item", "")
		))
		var selected_family: String = FAMILY_UNKNOWN
		for offered in offered_items:
			var item_id: String = _item_id(offered)
			if item_id.is_empty():
				continue
			var family_id: String = _family_id(offered)
			metrics["total_offer_cards"] = int(metrics["total_offer_cards"]) + 1
			_increment_dictionary_count(metrics["offer_count_by_item"], item_id)
			_increment_dictionary_count(metrics["offer_count_by_family"], family_id)
			metrics["item_details"][item_id] = _item_metadata(offered)
			if item_id == selected_id:
				selected_family = family_id
		if not selected_id.is_empty():
			metrics["selection_count"] = int(metrics["selection_count"]) + 1
			_increment_dictionary_count(metrics["selection_count_by_item"], selected_id)
			_increment_dictionary_count(metrics["selection_count_by_family"], selected_family)
			_append_number(acquisition_rounds, selected_id, float(round_number))
			var retained: float = float(screen.get("rounds_retained", 0.0))
			if retained > 0.0:
				_append_number(retained_rounds, selected_id, retained)
		var skipped: bool = bool(screen.get("skipped", false))
		if skipped:
			metrics["skip_count"] = int(metrics["skip_count"]) + 1
		var replacement_slot: int = int(screen.get("replacement_slot", -1))
		var replaced_item_id: String = str(screen.get("replaced_item_id", ""))
		if replacement_slot >= 0 or not replaced_item_id.is_empty():
			metrics["replacement_count"] = int(metrics["replacement_count"]) + 1
		var full_tray: bool = bool(screen.get("full_tray", false))
		if not full_tray:
			full_tray = _normalize_item_ids(screen.get("tray_before", [])).size() >= 5
		if full_tray:
			metrics["full_tray_count"] = int(metrics["full_tray_count"]) + 1
		var eligible_size: int = _eligible_pool_size(screen)
		metrics["unowned_eligible_pool_size_by_round"].append({
			"round_number": round_number,
			"eligible_pool_size": eligible_size,
		})
		metrics["generation_diagnostics"].append({
			"round_after": round_number,
			"offer_generation": int(screen.get("offer_generation", 0)),
			"selection_policy": str(screen.get("selection_policy", "")),
			"run_reward_seed": int(screen.get("run_reward_seed", 0)),
			"rng_state": int(screen.get("rng_state", 0)),
			"weighted_rolls": _dictionary_array_alias(screen, ["weighted_rolls"]),
			"eligible_pool_complete": bool(screen.get("eligible_pool_complete", true)),
			"eligible_pool_size": eligible_size,
			"offered_item_ids": _normalize_item_ids(screen.get(
				"offered_item_ids",
				[]
			)),
		})

	# Finalized ownership records are the durable source when a reward-screen event
	# does not itself carry retention duration.
	for lifecycle in _dictionary_array_alias(
		snapshot,
		["item_lifecycles", "ownership", "item_ownership"]
	):
		var item_id: String = _item_id(lifecycle)
		if item_id.is_empty():
			continue
		if not acquisition_rounds.has(item_id):
			var acquired_round: int = maxi(int(lifecycle.get("acquired_round", 0)), 0)
			if acquired_round > 0:
				_append_number(acquisition_rounds, item_id, float(acquired_round))
		if not retained_rounds.has(item_id):
			var rounds_owned: int = maxi(int(lifecycle.get("rounds_owned", 0)), 0)
			if rounds_owned > 0:
				_append_number(retained_rounds, item_id, float(rounds_owned))

	metrics["full_tray_frequency"] = _safe_ratio(
		float(metrics["full_tray_count"]),
		float(metrics["screen_count"])
	)
	metrics["selection_rate_by_item"] = _selection_rates(
		metrics["selection_count_by_item"],
		metrics["offer_count_by_item"]
	)
	metrics["selection_rate_by_family"] = _selection_rates(
		metrics["selection_count_by_family"],
		metrics["offer_count_by_family"]
	)
	metrics["average_round_acquired_by_item"] = _averages_by_key(acquisition_rounds)
	metrics["average_rounds_retained_by_item"] = _averages_by_key(retained_rounds)
	metrics["family_offer_share"] = _shares(
		metrics["offer_count_by_family"],
		float(metrics["total_offer_cards"])
	)
	var eligible_pool_total: float = 0.0
	var eligible_pool_samples: Array = metrics["unowned_eligible_pool_size_by_round"]
	for eligible_sample_value in eligible_pool_samples:
		if eligible_sample_value is Dictionary:
			eligible_pool_total += float((eligible_sample_value as Dictionary).get(
				"eligible_pool_size",
				0
			))
	metrics["average_unowned_eligible_pool_size"] = _safe_ratio(
		eligible_pool_total,
		float(eligible_pool_samples.size())
	)
	metrics["by_item"] = _make_offer_breakdown(
		metrics["offer_count_by_item"],
		metrics["selection_count_by_item"],
		metrics["selection_rate_by_item"],
		metrics["item_details"]
	)
	metrics["by_family"] = _make_offer_breakdown(
		metrics["offer_count_by_family"],
		metrics["selection_count_by_family"],
		metrics["selection_rate_by_family"]
	)
	return metrics


static func _build_shot_metrics(shots: Array[Dictionary]) -> Array[Dictionary]:
	var metrics: Array[Dictionary] = []
	for shot in shots:
		var activations: Array[Dictionary] = _shot_activations(shot)
		var marginal_by_item: Dictionary = {}
		var activated_ids: Array[String] = []
		for activation in activations:
			var item_id: String = _item_id(activation)
			if not item_id.is_empty() and not activated_ids.has(item_id):
				activated_ids.append(item_id)
		var marginal_candidate_ids: Array[String] = _shot_owned_item_ids(shot)
		for activated_item_id in activated_ids:
			if not marginal_candidate_ids.has(activated_item_id):
				marginal_candidate_ids.append(activated_item_id)
		for item_id in marginal_candidate_ids:
			var marginal: Dictionary = _item_marginal_for_shot(shot, item_id, activations)
			if bool(marginal.get("available", false)):
				marginal_by_item[item_id] = int(marginal.get("uplift", 0))
		var summed_marginal: int = 0
		for uplift_value in marginal_by_item.values():
			summed_marginal += int(uplift_value)
		var build_uplift: int = _shot_score(shot) - _base_score(shot)
		var tap: Dictionary = _tap_metrics_for_shot(shot)
		metrics.append({
			"shot_id": int(shot.get("shot_id", -1)),
			"attempt_id": int(shot.get("attempt_id", -1)),
			"round_number": maxi(int(shot.get("round_number", 1)), 1),
			"shots_remaining_before": maxi(int(shot.get("shots_remaining_before", 0)), 0),
			"shots_remaining_after": maxi(int(shot.get("shots_remaining_after", 0)), 0),
			"hull_before": maxi(int(shot.get("hull_before", 0)), 0),
			"hull_after": maxi(int(shot.get("hull_after", 0)), 0),
			"object_balls_pocketed": maxi(int(shot.get("object_balls_pocketed", 0)), 0),
			"trigger_counts": _shot_trigger_counts(shot),
			"maximum_bank_tier": maxi(int(shot.get("maximum_bank_tier", 0)), 0),
			"combination_count": maxi(int(shot.get("combination_count", 0)), 0),
			"tap_metrics": tap,
			"cue_recontact_milestones": int(tap.get("cue_recontact_milestones", 0)),
			"maximum_cue_strikes_against_one_scoring_ball": int(tap.get(
				"maximum_cue_strikes_against_one_scoring_ball",
				0
			)),
			"ball_tap_milestones": int(tap.get("ball_tap_milestones", 0)),
			"unique_ball_tap_target_count": int(tap.get(
				"unique_ball_tap_target_count",
				0
			)),
			"repeated_ball_tap_contacts_ignored": int(tap.get(
				"repeated_ball_tap_contacts_ignored",
				0
			)),
			"ambiguous_tap_contacts_rejected": int(tap.get(
				"ambiguous_tap_contacts_rejected",
				0
			)),
			"base_haul": maxi(int(shot.get("base_haul", 0)), 0),
			"base_mult": maxf(float(shot.get("base_mult", 1.0)), 0.0),
			"base_score_without_build": _base_score(shot),
			"build_haul_added": float(shot.get("build_haul_added", 0.0)),
			"build_mult_added": float(shot.get("build_mult_added", 0.0)),
			"build_xmult_product": maxf(float(shot.get(
				"build_xmult_product",
				shot.get("xmult_product", 1.0)
			)), 0.0),
			"final_haul": maxi(int(shot.get("final_haul", 0)), 0),
			"final_mult": maxf(float(shot.get("final_mult", 1.0)), 0.0),
			"final_score": _shot_score(shot),
			"build_uplift": build_uplift,
			"item_marginal_uplift_by_id": marginal_by_item,
			"summed_item_marginal_uplift": summed_marginal,
			"interaction_surplus": build_uplift - summed_marginal,
			"item_activations": activations,
			"owned_item_ids": _shot_owned_item_ids(shot),
			"scratch": bool(shot.get("scratch", false)),
			"terminal_outcome": str(shot.get("terminal_outcome", "")),
		})
	return metrics


static func _aggregate_items(
	snapshot: Dictionary,
	shots: Array[Dictionary],
	rounds: Array[Dictionary],
	offers: Dictionary,
	diagnostics: Dictionary
) -> Array[Dictionary]:
	var metrics_by_id: Dictionary = {}
	var lifecycles: Array[Dictionary] = _dictionary_array_alias(
		snapshot,
		["item_lifecycles", "ownership", "item_ownership"]
	)
	for lifecycle in lifecycles:
		var item_id: String = _item_id(lifecycle)
		if item_id.is_empty():
			continue
		var metric: Dictionary = _ensure_item_metric(metrics_by_id, item_id, lifecycle)
		metric["tray_slot"] = int(lifecycle.get(
			"tray_slot",
			lifecycle.get("tray_slot_index", metric["tray_slot"])
		))
		var acquired_round: int = maxi(int(lifecycle.get("acquired_round", 0)), 0)
		if acquired_round > 0:
			metric["round_acquired"] = acquired_round
		var explicit_owned_rounds: Array[int] = _int_array(lifecycle.get("owned_round_numbers", []))
		for round_number in explicit_owned_rounds:
			metric["_owned_rounds"][round_number] = true
		var explicit_round_count: int = maxi(int(lifecycle.get("rounds_owned", 0)), 0)
		metric["_explicit_rounds_owned"] = maxi(
			int(metric["_explicit_rounds_owned"]),
			explicit_round_count
		)
		var explicit_shot_count: int = maxi(int(lifecycle.get("shots_owned", 0)), 0)
		metric["_explicit_shots_owned"] = maxi(
			int(metric["_explicit_shots_owned"]),
			explicit_shot_count
		)
		metric["removed_round"] = maxi(int(lifecycle.get("removed_round", 0)), 0)

	var offered_details: Dictionary = _dictionary_value(offers, "item_details")
	for item_id_value in offered_details.keys():
		var item_id: String = str(item_id_value)
		var details_value: Variant = offered_details[item_id_value]
		if details_value is Dictionary:
			_ensure_item_metric(metrics_by_id, item_id, details_value)

	var final_tray_value: Variant = snapshot.get(
		"final_tray",
		_dictionary_value(snapshot, "final_build_snapshot")
	)
	for final_item_id in _normalize_build_item_ids(final_tray_value):
		_ensure_item_metric(metrics_by_id, final_item_id, {})["in_final_tray"] = true

	for shot in shots:
		var shot_key: String = _shot_key(shot)
		var round_number: int = maxi(int(shot.get("round_number", 1)), 1)
		var activations: Array[Dictionary] = _shot_activations(shot)
		var owned_ids: Array[String] = _shot_owned_item_ids(shot)
		if owned_ids.is_empty():
			for activation in activations:
				var activation_item_id: String = _item_id(activation)
				if not activation_item_id.is_empty() and not owned_ids.has(activation_item_id):
					owned_ids.append(activation_item_id)
		for item_id in owned_ids:
			var owned_metric: Dictionary = _ensure_item_metric(
				metrics_by_id,
				item_id,
				_shot_item_metadata(shot, item_id)
			)
			owned_metric["_owned_shot_keys"][shot_key] = true
			owned_metric["_owned_rounds"][round_number] = true

		var activated_ids: Array[String] = []
		for activation in activations:
			var item_id: String = _item_id(activation)
			if item_id.is_empty():
				continue
			var metric: Dictionary = _ensure_item_metric(metrics_by_id, item_id, activation)
			metric["trigger_occurrences"] = int(metric["trigger_occurrences"]) + 1
			var is_retrigger: bool = bool(activation.get("is_retrigger", false))
			if is_retrigger:
				metric["retriggered_activations"] = int(metric["retriggered_activations"]) + 1
			else:
				metric["regular_activations"] = int(metric["regular_activations"]) + 1
			metric["_triggered_shot_keys"][shot_key] = true
			if not activated_ids.has(item_id):
				activated_ids.append(item_id)
			var phase: String = str(activation.get(
				"modifier_phase",
				activation.get("phase", metric["modifier_phase"])
			))
			var value: float = float(activation.get(
				"applied_value",
				activation.get("value", 0.0)
			))
			match phase:
				PHASE_ADD_HAUL:
					metric["total_haul_added"] = float(metric["total_haul_added"]) + value
					if is_retrigger:
						metric["retriggered_haul_added"] = float(
							metric["retriggered_haul_added"]
						) + value
				PHASE_ADD_MULT:
					metric["total_mult_added"] = float(metric["total_mult_added"]) + value
					if is_retrigger:
						metric["retriggered_mult_added"] = float(
							metric["retriggered_mult_added"]
						) + value
				PHASE_XMULT:
					metric["cumulative_xmult_factor"] = (
						float(metric["cumulative_xmult_factor"]) * value
					)
					if is_retrigger:
						metric["retriggered_xmult_activations"] = int(
							metric["retriggered_xmult_activations"]
						) + 1
						metric["retriggered_xmult_product"] = float(
							metric["retriggered_xmult_product"]
						) * value

		var marginal_candidate_ids: Array[String] = owned_ids.duplicate()
		for activated_item_id in activated_ids:
			if not marginal_candidate_ids.has(activated_item_id):
				marginal_candidate_ids.append(activated_item_id)
		for item_id in marginal_candidate_ids:
			var marginal: Dictionary = _item_marginal_for_shot(shot, item_id, activations)
			var metric: Dictionary = _ensure_item_metric(
				metrics_by_id,
				item_id,
				_shot_item_metadata(shot, item_id)
			)
			if bool(marginal.get("available", false)):
				metric["final_score_uplift"] = int(metric["final_score_uplift"]) + int(
					marginal.get("uplift", 0)
				)
				metric["counterfactual_shots"] = int(metric["counterfactual_shots"]) + 1
				diagnostics["available_item_counterfactuals"] = int(
					diagnostics.get("available_item_counterfactuals", 0)
				) + 1
			else:
				metric["missing_counterfactual_shots"] = int(
					metric["missing_counterfactual_shots"]
				) + 1
				diagnostics["missing_item_counterfactuals"] = int(
					diagnostics.get("missing_item_counterfactuals", 0)
				) + 1

	_apply_offer_lifecycle_to_items(metrics_by_id, snapshot, offers, rounds)
	var total_run_score: int = _sum_shot_scores(shots)
	var total_build_uplift: int = _sum_build_uplift(shots)
	var results: Array[Dictionary] = []
	for item_id_value in metrics_by_id.keys():
		var item_id: String = str(item_id_value)
		var metric: Dictionary = metrics_by_id[item_id]
		var shots_owned: int = maxi(
			(metric["_owned_shot_keys"] as Dictionary).size(),
			int(metric["_explicit_shots_owned"])
		)
		var rounds_owned: int = maxi(
			(metric["_owned_rounds"] as Dictionary).size(),
			int(metric["_explicit_rounds_owned"])
		)
		var triggers: int = int(metric["trigger_occurrences"])
		var uplift: int = int(metric["final_score_uplift"])
		metric["shots_owned"] = shots_owned
		metric["rounds_owned"] = rounds_owned
		metric["shots_triggered"] = (metric["_triggered_shot_keys"] as Dictionary).size()
		metric["average_score_uplift_per_owned_shot"] = _safe_ratio(
			float(uplift),
			float(shots_owned)
		)
		metric["average_score_uplift_per_activation"] = _safe_ratio(
			float(uplift),
			float(triggers)
		)
		metric["percentage_of_run_score"] = _safe_ratio(
			float(uplift) * 100.0,
			float(total_run_score)
		)
		metric["percentage_of_build_uplift"] = _safe_ratio(
			float(uplift) * 100.0,
			float(total_build_uplift)
		)
		metric.erase("_owned_shot_keys")
		metric.erase("_triggered_shot_keys")
		metric.erase("_owned_rounds")
		metric.erase("_explicit_rounds_owned")
		metric.erase("_explicit_shots_owned")
		results.append(metric.duplicate(true))
	results.sort_custom(_item_metric_precedes)
	return results


static func _ensure_item_metric(
	metrics_by_id: Dictionary,
	item_id: String,
	metadata: Dictionary
) -> Dictionary:
	if not metrics_by_id.has(item_id):
		metrics_by_id[item_id] = {
			"eight_ball_item_id": item_id,
			"display_name": str(metadata.get("display_name", item_id)),
			"family_id": _family_id(metadata),
			"offer_family": str(metadata.get("offer_family", "")),
			"modifier_phase": str(metadata.get(
				"modifier_phase",
				metadata.get("phase", "")
			)),
			"rarity": str(metadata.get("rarity", "")),
			"offer_weight": int(metadata.get("offer_weight", 0)),
			"effect_kind": str(metadata.get("effect_kind", "")),
			"owned_item_instance_ids": [],
			"retrigger_family": str(metadata.get(
				"retrigger_family",
				metadata.get("retrigger_family_id", "")
			)),
			"tray_slot": int(metadata.get(
				"tray_slot",
				metadata.get("tray_slot_index", metadata.get("slot_index", -1))
			)),
			"round_acquired": maxi(int(metadata.get("acquired_round", 0)), 0),
			"removed_round": maxi(int(metadata.get("removed_round", 0)), 0),
			"rounds_owned": 0,
			"shots_owned": 0,
			"shots_triggered": 0,
			"trigger_occurrences": 0,
			"regular_activations": 0,
			"retriggered_activations": 0,
			"total_haul_added": 0.0,
			"total_mult_added": 0.0,
			"cumulative_xmult_factor": 1.0,
			"retriggered_haul_added": 0.0,
			"retriggered_mult_added": 0.0,
			"retriggered_xmult_activations": 0,
			"retriggered_xmult_product": 1.0,
			"final_score_uplift": 0,
			"average_score_uplift_per_owned_shot": 0.0,
			"average_score_uplift_per_activation": 0.0,
			"percentage_of_run_score": 0.0,
			"percentage_of_build_uplift": 0.0,
			"counterfactual_shots": 0,
			"missing_counterfactual_shots": 0,
			"offer_count": 0,
			"selection_count": 0,
			"replacement_count": 0,
			"replaced_count": 0,
			"average_round_acquired": 0.0,
			"average_rounds_retained": 0.0,
			"in_final_tray": false,
			"_owned_shot_keys": {},
			"_triggered_shot_keys": {},
			"_owned_rounds": {},
			"_explicit_rounds_owned": 0,
			"_explicit_shots_owned": 0,
		}
	var metric: Dictionary = metrics_by_id[item_id]
	if str(metric["display_name"]) == item_id and not str(metadata.get("display_name", "")).is_empty():
		metric["display_name"] = str(metadata.get("display_name"))
	if str(metric["family_id"]) == FAMILY_UNKNOWN and _family_id(metadata) != FAMILY_UNKNOWN:
		metric["family_id"] = _family_id(metadata)
	if str(metric["modifier_phase"]).is_empty():
		metric["modifier_phase"] = str(metadata.get("modifier_phase", metadata.get("phase", "")))
	if str(metric["effect_kind"]).is_empty():
		metric["effect_kind"] = str(metadata.get("effect_kind", ""))
	if str(metric["offer_family"]).is_empty():
		metric["offer_family"] = str(metadata.get("offer_family", ""))
	var instance_id: int = int(metadata.get("owned_item_instance_id", -1))
	if instance_id >= 0:
		var instance_ids: Array = metric["owned_item_instance_ids"]
		if not instance_ids.has(instance_id):
			instance_ids.append(instance_id)
	if str(metric["retrigger_family"]).is_empty():
		metric["retrigger_family"] = str(metadata.get(
			"retrigger_family",
			metadata.get("retrigger_family_id", "")
		))
	if int(metric["tray_slot"]) < 0:
		metric["tray_slot"] = int(metadata.get(
			"tray_slot",
			metadata.get("tray_slot_index", metadata.get("slot_index", -1))
		))
	return metric


static func _apply_offer_lifecycle_to_items(
	metrics_by_id: Dictionary,
	snapshot: Dictionary,
	offers: Dictionary,
	rounds: Array[Dictionary]
) -> void:
	var offer_count_by_item: Dictionary = _dictionary_value(offers, "offer_count_by_item")
	var selection_count_by_item: Dictionary = _dictionary_value(offers, "selection_count_by_item")
	var average_rounds: Dictionary = _dictionary_value(offers, "average_round_acquired_by_item")
	var average_retained: Dictionary = _dictionary_value(offers, "average_rounds_retained_by_item")
	for item_id_value in offer_count_by_item.keys():
		var item_id: String = str(item_id_value)
		var metric: Dictionary = _ensure_item_metric(metrics_by_id, item_id, {})
		metric["offer_count"] = int(offer_count_by_item[item_id_value])
		metric["selection_count"] = int(selection_count_by_item.get(item_id, 0))
		metric["average_round_acquired"] = float(average_rounds.get(item_id, 0.0))
		metric["average_rounds_retained"] = float(average_retained.get(item_id, 0.0))

	var screens: Array[Dictionary] = _dictionary_array_alias(
		snapshot,
		["reward_screens", "offer_events", "offers"]
	)
	var max_round: int = rounds.size()
	for round_record in rounds:
		max_round = maxi(max_round, int(round_record.get("round_number", 0)))
	for screen in screens:
		var selected_id: String = str(screen.get(
			"selected_item_id",
			screen.get("selected_item", "")
		))
		var replaced_id: String = str(screen.get("replaced_item_id", ""))
		var replacement_slot: int = int(screen.get("replacement_slot", -1))
		var round_number: int = maxi(int(screen.get(
			"round_number",
			screen.get("round_after", 0)
		)), 0)
		if not selected_id.is_empty():
			var selected_metric: Dictionary = _ensure_item_metric(metrics_by_id, selected_id, {})
			var selected_slot: int = int(screen.get("selected_tray_slot", -1))
			if selected_slot < 0:
				selected_slot = _find_item_slot(screen.get("tray_after", []), selected_id)
			if selected_slot >= 0:
				selected_metric["tray_slot"] = selected_slot
			if int(selected_metric["round_acquired"]) <= 0:
				selected_metric["round_acquired"] = round_number
			if replacement_slot >= 0 or not replaced_id.is_empty():
				selected_metric["replacement_count"] = int(selected_metric["replacement_count"]) + 1
		if not replaced_id.is_empty():
			var replaced_metric: Dictionary = _ensure_item_metric(metrics_by_id, replaced_id, {})
			replaced_metric["replaced_count"] = int(replaced_metric["replaced_count"]) + 1
			replaced_metric["removed_round"] = round_number

	for item_id_value in metrics_by_id.keys():
		var metric: Dictionary = metrics_by_id[item_id_value]
		if float(metric["average_rounds_retained"]) > 0.0:
			continue
		var acquired_round: int = int(metric["round_acquired"])
		if acquired_round <= 0:
			continue
		var removed_round: int = int(metric["removed_round"])
		var final_round: int = removed_round if removed_round > 0 else max_round + 1
		metric["average_rounds_retained"] = float(maxi(final_round - acquired_round, 0))


static func _aggregate_dead_reckoning(
	shots: Array[Dictionary],
	rounds: Array[Dictionary],
	items: Array[Dictionary]
) -> Dictionary:
	var metrics: Dictionary = _empty_dead_reckoning_metrics()
	var support_ids_seen: Dictionary = {}
	var shot_round_support: Dictionary = {}
	for shot in shots:
		var owned_ids: Array[String] = _shot_owned_item_ids(shot)
		if not owned_ids.has(DEAD_RECKONING_ITEM_ID):
			continue
		metrics["owned"] = true
		metrics["shots_owned"] = int(metrics["shots_owned"]) + 1
		var support_ids: Array[String] = _direct_support_ids_for_shot(shot, owned_ids)
		for support_id in support_ids:
			support_ids_seen[support_id] = true
		var direct_occurrences: int = maxi(int(
			_shot_trigger_counts(shot).get(TRIGGER_DIRECT_POT, 0)
		), 0)
		var compact_summary: Dictionary = _dictionary_value(shot, "dead_reckoning")
		if compact_summary.has("direct_pot_occurrences_while_owned"):
			direct_occurrences = maxi(int(compact_summary.get(
				"direct_pot_occurrences_while_owned",
				direct_occurrences
			)), 0)
		metrics["direct_pot_occurrences_while_owned"] = int(
			metrics["direct_pot_occurrences_while_owned"]
		) + direct_occurrences
		if support_ids.is_empty():
			metrics["unsupported_occurrences"] = int(
				metrics["unsupported_occurrences"]
			) + direct_occurrences
			metrics["dead_occurrences"] = int(metrics["dead_occurrences"]) + direct_occurrences
		else:
			metrics["supported_occurrences"] = int(
				metrics["supported_occurrences"]
			) + direct_occurrences

		var round_number: int = maxi(int(shot.get("round_number", 1)), 1)
		var round_evidence: Dictionary = _dictionary_value(
			shot_round_support,
			str(round_number)
		)
		round_evidence["owned"] = true
		round_evidence["supported"] = bool(round_evidence.get("supported", false)) or (
			not support_ids.is_empty()
		)
		shot_round_support[str(round_number)] = round_evidence

		var retrigger_activations: Array[Dictionary] = []
		for activation in _shot_activations(shot):
			if (
				bool(activation.get("is_retrigger", false))
				and str(activation.get("retrigger_source_item_id", ""))
				== DEAD_RECKONING_ITEM_ID
			):
				retrigger_activations.append(activation)
		if retrigger_activations.is_empty() and not compact_summary.is_empty():
			_apply_compact_dead_reckoning_retriggers(metrics, compact_summary)
		else:
			for activation in retrigger_activations:
				_apply_dead_reckoning_retrigger(metrics, activation)

		var marginal: Dictionary = _item_marginal_for_shot(
			shot,
			DEAD_RECKONING_ITEM_ID,
			_shot_activations(shot)
		)
		if bool(marginal.get("available", false)):
			metrics["marginal_score_uplift"] = int(
				metrics["marginal_score_uplift"]
			) + int(marginal.get("uplift", 0))
			metrics["counterfactual_shots"] = int(metrics["counterfactual_shots"]) + 1

	var unsupported_rounds: Dictionary = {}
	for round_record in rounds:
		var round_number: int = maxi(int(round_record.get("round_number", 1)), 1)
		var owned_ids: Array[String] = _normalize_item_ids(round_record.get(
			"build_at_round_start",
			[]
		))
		if owned_ids.is_empty():
			var fallback_evidence: Dictionary = _dictionary_value(
				shot_round_support,
				str(round_number)
			)
			if bool(fallback_evidence.get("owned", false)) and not bool(
				fallback_evidence.get("supported", false)
			):
				unsupported_rounds[round_number] = true
			continue
		if (
			owned_ids.has(DEAD_RECKONING_ITEM_ID)
			and not _owned_ids_have_direct_support(owned_ids)
		):
			unsupported_rounds[round_number] = true
	for round_key_value in shot_round_support.keys():
		var round_number: int = int(round_key_value)
		var evidence: Dictionary = _dictionary_value(shot_round_support, str(round_number))
		if (
			bool(evidence.get("owned", false))
			and not bool(evidence.get("supported", false))
			and not _round_number_is_represented(rounds, round_number)
		):
			unsupported_rounds[round_number] = true
	var unsupported_round_numbers: Array[int] = []
	for round_number_value in unsupported_rounds.keys():
		unsupported_round_numbers.append(int(round_number_value))
	unsupported_round_numbers.sort()
	metrics["rounds_owned_without_support"] = unsupported_round_numbers.size()
	metrics["round_numbers_owned_without_support"] = unsupported_round_numbers
	var support_ids: Array[String] = []
	for support_id_value in support_ids_seen.keys():
		support_ids.append(str(support_id_value))
	support_ids.sort()
	metrics["support_item_ids_seen"] = support_ids

	for item in items:
		if _item_id(item) != DEAD_RECKONING_ITEM_ID:
			continue
		item["direct_pot_occurrences_while_owned"] = int(
			metrics["direct_pot_occurrences_while_owned"]
		)
		item["supported_occurrences"] = int(metrics["supported_occurrences"])
		item["unsupported_occurrences"] = int(metrics["unsupported_occurrences"])
		item["dead_occurrences"] = int(metrics["dead_occurrences"])
		item["regular_activations_retriggered"] = int(
			metrics["regular_activations_retriggered"]
		)
		item["retriggered_haul_added"] = float(metrics["retriggered_add_haul"])
		item["retriggered_mult_added"] = float(metrics["retriggered_add_mult"])
		item["retriggered_xmult_activations"] = int(
			metrics["retriggered_xmult_activations"]
		)
		item["retriggered_xmult_product"] = float(metrics["retriggered_xmult_product"])
		item["rounds_owned_without_support"] = unsupported_round_numbers.size()
		metrics["marginal_score_uplift"] = int(item.get("final_score_uplift", 0))
		break
	return metrics


static func _apply_dead_reckoning_retrigger(metrics: Dictionary, activation: Dictionary) -> void:
	metrics["regular_activations_retriggered"] = int(
		metrics["regular_activations_retriggered"]
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
		PHASE_ADD_HAUL:
			metrics["retriggered_add_haul"] = float(metrics["retriggered_add_haul"]) + value
		PHASE_ADD_MULT:
			metrics["retriggered_add_mult"] = float(metrics["retriggered_add_mult"]) + value
		PHASE_XMULT:
			metrics["retriggered_xmult_activations"] = int(
				metrics["retriggered_xmult_activations"]
			) + 1
			metrics["retriggered_xmult_product"] = float(
				metrics["retriggered_xmult_product"]
			) * value


static func _apply_compact_dead_reckoning_retriggers(
	metrics: Dictionary,
	compact_summary: Dictionary
) -> void:
	metrics["regular_activations_retriggered"] = int(
		metrics["regular_activations_retriggered"]
	) + int(compact_summary.get("regular_activations_retriggered", 0))
	metrics["retriggered_add_haul"] = float(metrics["retriggered_add_haul"]) + float(
		compact_summary.get("retriggered_add_haul", 0.0)
	)
	metrics["retriggered_add_mult"] = float(metrics["retriggered_add_mult"]) + float(
		compact_summary.get("retriggered_add_mult", 0.0)
	)
	metrics["retriggered_xmult_activations"] = int(
		metrics["retriggered_xmult_activations"]
	) + int(compact_summary.get("retriggered_xmult_activations", 0))
	metrics["retriggered_xmult_product"] = float(
		metrics["retriggered_xmult_product"]
	) * float(compact_summary.get("retriggered_xmult_product", 1.0))


static func _direct_support_ids_for_shot(
	shot: Dictionary,
	owned_item_ids: Array[String]
) -> Array[String]:
	var support_ids: Array[String] = []
	var build_snapshot: Dictionary = _dictionary_value(shot, "build_snapshot")
	var definitions_value: Variant = build_snapshot.get("item_definitions_by_slot", [])
	if definitions_value is Array:
		for definition_value in definitions_value as Array:
			if not definition_value is Dictionary:
				continue
			var definition: Dictionary = definition_value as Dictionary
			var item_id: String = _item_id(definition)
			if (
				item_id.is_empty()
				or item_id == DEAD_RECKONING_ITEM_ID
				or str(definition.get("family_id", "")) != FAMILY_DIRECT_POT
				or str(definition.get("effect_kind", "")) == "retrigger_family"
			):
				continue
			if owned_item_ids.has(item_id) and not support_ids.has(item_id):
				support_ids.append(item_id)
	for support_id in DEAD_RECKONING_SUPPORT_ITEM_IDS:
		if owned_item_ids.has(support_id) and not support_ids.has(support_id):
			support_ids.append(support_id)
	return support_ids


static func _owned_ids_have_direct_support(owned_item_ids: Array[String]) -> bool:
	for support_id in DEAD_RECKONING_SUPPORT_ITEM_IDS:
		if owned_item_ids.has(support_id):
			return true
	return false


static func _round_number_is_represented(rounds: Array[Dictionary], round_number: int) -> bool:
	for round_record in rounds:
		if int(round_record.get("round_number", -1)) == round_number:
			return true
	return false


static func _aggregate_triggers(shots: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = _empty_trigger_metrics()
	var families: Dictionary = result["families"]
	for shot in shots:
		var counts: Dictionary = _shot_trigger_counts(shot)
		var shot_score: int = _shot_score(shot)
		for trigger_id_value in counts.keys():
			var trigger_id: String = str(trigger_id_value)
			var family_id: String = _family_from_trigger(trigger_id)
			if not families.has(family_id):
				continue
			var family: Dictionary = families[family_id]
			var count: int = maxi(int(counts[trigger_id_value]), 0)
			family["milestone_occurrences"] = int(family["milestone_occurrences"]) + count
			if count > 0:
				family["shots_containing"] = int(family["shots_containing"]) + 1
				family["score_from_shots_containing"] = int(
					family["score_from_shots_containing"]
				) + shot_score
		for activation in _shot_activations(shot):
			var family_id: String = _family_id(activation)
			if family_id == FAMILY_UNKNOWN:
				family_id = _family_from_trigger(str(activation.get("trigger_id", "")))
			if families.has(family_id):
				var family: Dictionary = families[family_id]
				family["owned_item_activations"] = int(family["owned_item_activations"]) + 1
				if bool(activation.get("is_retrigger", false)):
					family["retriggered_item_activations"] = int(
						family["retriggered_item_activations"]
					) + 1
				else:
					family["regular_item_activations"] = int(
						family["regular_item_activations"]
					) + 1

	for family_id_value in families.keys():
		var family: Dictionary = families[family_id_value]
		family["average_score_from_shots_containing"] = _safe_ratio(
			float(family["score_from_shots_containing"]),
			float(family["shots_containing"])
		)
	var single_count: int = int(families[FAMILY_SINGLE_BANK]["milestone_occurrences"])
	var double_count: int = int(families[FAMILY_DOUBLE_BANK]["milestone_occurrences"])
	var triple_count: int = int(families[FAMILY_TRIPLE_BANK]["milestone_occurrences"])
	result["single_per_double"] = _safe_ratio(float(single_count), float(double_count))
	result["single_per_triple"] = _safe_ratio(float(single_count), float(triple_count))
	result["double_per_triple"] = _safe_ratio(float(double_count), float(triple_count))
	result["ratio_availability"] = {
		"single_per_double": double_count > 0,
		"single_per_triple": triple_count > 0,
		"double_per_triple": triple_count > 0,
	}
	result["total_bank_milestone_occurrences"] = single_count + double_count + triple_count
	result["cumulative_bank_activation_expansion"] = single_count + double_count + triple_count
	return result


static func _aggregate_taps(shots: Array[Dictionary], triggers: Dictionary) -> Dictionary:
	var result: Dictionary = _empty_tap_metrics()
	var tap_exploit_examples: Array[Dictionary] = []
	var contact_farm_examples: Array[Dictionary] = []
	var tap_exploit_candidate_count: int = 0
	var contact_farm_candidate_count: int = 0
	var bank_shots: int = 0
	var combination_shots: int = 0
	for shot in shots:
		var tap: Dictionary = _tap_metrics_for_shot(shot)
		var cue_milestones: int = maxi(int(tap.get("cue_recontact_milestones", 0)), 0)
		var ball_milestones: int = maxi(int(tap.get("ball_tap_milestones", 0)), 0)
		var max_cue_strikes: int = maxi(int(tap.get(
			"maximum_cue_strikes_against_one_scoring_ball",
			0
		)), 0)
		var max_ball_taps: int = maxi(int(tap.get(
			"maximum_ball_taps_by_one_scoring_ball",
			0
		)), 0)
		var repeated_contacts: int = maxi(int(tap.get(
			"repeated_ball_tap_contacts_ignored",
			0
		)), 0)
		var unique_targets: int = maxi(int(tap.get(
			"unique_ball_tap_target_count",
			ball_milestones
		)), 0)

		if bool(tap.get("has_double_tap", cue_milestones > 0)):
			result["shots_with_double_tap"] = int(result["shots_with_double_tap"]) + 1
		if bool(tap.get("has_triple_tap_or_higher", max_cue_strikes >= 3)):
			result["shots_with_triple_tap_or_higher"] = int(
				result["shots_with_triple_tap_or_higher"]
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
			"cue_recontact_score_supplied",
			"ball_tap_score_supplied",
		]:
			result[key] = int(result.get(key, 0)) + maxi(int(tap.get(key, 0)), 0)
		result["maximum_cue_strikes_against_one_scoring_ball"] = maxi(
			int(result["maximum_cue_strikes_against_one_scoring_ball"]),
			max_cue_strikes
		)
		result["maximum_cue_recontact_milestones_in_one_shot"] = maxi(
			int(result["maximum_cue_recontact_milestones_in_one_shot"]),
			cue_milestones
		)
		result["maximum_ball_taps_by_one_scoring_ball"] = maxi(
			int(result["maximum_ball_taps_by_one_scoring_ball"]),
			max_ball_taps
		)
		result["maximum_ball_tap_milestones_in_one_shot"] = maxi(
			int(result["maximum_ball_tap_milestones_in_one_shot"]),
			ball_milestones
		)

		var counts: Dictionary = _shot_trigger_counts(shot)
		if (
			int(counts.get(TRIGGER_SINGLE_BANK, 0)) > 0
			or int(counts.get(TRIGGER_DOUBLE_BANK, 0)) > 0
			or int(counts.get(TRIGGER_TRIPLE_BANK, 0)) > 0
		):
			bank_shots += 1
		if int(counts.get(TRIGGER_COMBINATION, 0)) > 0:
			combination_shots += 1

		if max_cue_strikes >= TAP_EXPLOIT_MAX_CUE_STRIKES_PER_BALL:
			tap_exploit_candidate_count += 1
			if tap_exploit_examples.size() < MAX_WATCH_EXAMPLE_SHOTS:
				tap_exploit_examples.append(_tap_watch_shot_evidence(
					shot,
					{
						"maximum_cue_strikes": max_cue_strikes,
						"cue_recontact_milestones": cue_milestones,
					}
				))
		var repeated_to_unique_ratio: float = _safe_ratio(
			float(repeated_contacts),
			float(maxi(unique_targets, 1))
		)
		if (
			repeated_contacts >= CONTACT_FARM_MIN_REPEATED_CONTACTS_PER_SHOT
			and repeated_to_unique_ratio >= CONTACT_FARM_REPEATED_TO_UNIQUE_RATIO
		):
			contact_farm_candidate_count += 1
			if contact_farm_examples.size() < MAX_WATCH_EXAMPLE_SHOTS:
				contact_farm_examples.append(_tap_watch_shot_evidence(
					shot,
					{
						"repeated_contacts": repeated_contacts,
						"unique_targets": unique_targets,
						"repeated_to_unique_ratio": repeated_to_unique_ratio,
					}
				))

	result["average_double_tap_mult"] = _safe_ratio(
		float(result["cue_recontact_milestones"]),
		float(result["shots_with_double_tap"])
	)
	result["average_cue_recontact_mult_per_scoring_ball"] = _safe_ratio(
		float(result["cue_recontact_milestones"]),
		float(result["scoring_balls_with_double_tap"])
	)
	result["average_ball_tap_mult"] = _safe_ratio(
		float(result["ball_tap_milestones"]),
		float(result["scoring_balls_with_ball_tap"])
	)
	result["total_tap_score_supplied"] = (
		int(result["cue_recontact_score_supplied"])
		+ int(result["ball_tap_score_supplied"])
	)
	result["double_tap_score_supplied"] = int(result["cue_recontact_score_supplied"])
	var families: Dictionary = _dictionary_value(triggers, "families")
	var single: Dictionary = _dictionary_value(families, FAMILY_SINGLE_BANK)
	var double: Dictionary = _dictionary_value(families, FAMILY_DOUBLE_BANK)
	var triple: Dictionary = _dictionary_value(families, FAMILY_TRIPLE_BANK)
	var combination: Dictionary = _dictionary_value(families, FAMILY_COMBINATION)
	var bank_occurrences: int = (
		int(single.get("milestone_occurrences", 0))
		+ int(double.get("milestone_occurrences", 0))
		+ int(triple.get("milestone_occurrences", 0))
	)
	var combination_occurrences: int = int(combination.get("milestone_occurrences", 0))
	result["bank_milestone_occurrences"] = bank_occurrences
	result["combination_occurrences"] = combination_occurrences
	result["frequency_comparison"] = {
		"cue_recontact_shot_frequency": _safe_ratio(
			float(result["shots_with_double_tap"]),
			float(shots.size())
		),
		"ball_tap_shot_frequency": _safe_ratio(
			float(_shots_with_ball_tap(shots)),
			float(shots.size())
		),
		"bank_shot_frequency": _safe_ratio(float(bank_shots), float(shots.size())),
		"combination_shot_frequency": _safe_ratio(
			float(combination_shots),
			float(shots.size())
		),
		"cue_recontact_to_bank_occurrence_ratio": _safe_ratio(
			float(result["cue_recontact_milestones"]),
			float(bank_occurrences)
		),
		"ball_tap_to_bank_occurrence_ratio": _safe_ratio(
			float(result["ball_tap_milestones"]),
			float(bank_occurrences)
		),
		"cue_recontact_to_combination_ratio": _safe_ratio(
			float(result["cue_recontact_milestones"]),
			float(combination_occurrences)
		),
		"ball_tap_to_combination_ratio": _safe_ratio(
			float(result["ball_tap_milestones"]),
			float(combination_occurrences)
		),
	}
	result["tap_exploit_candidate_shots"] = tap_exploit_examples
	result["tap_exploit_candidate_shot_count"] = tap_exploit_candidate_count
	result["contact_farm_candidate_shots"] = contact_farm_examples
	result["contact_farm_candidate_shot_count"] = contact_farm_candidate_count
	return result


static func _aggregate_phase_5c_tap_items(
	snapshot: Dictionary,
	shots: Array[Dictionary],
	rounds: Array[Dictionary],
	items: Array[Dictionary]
) -> Dictionary:
	var result: Dictionary = _empty_phase_5c_metrics()
	var rattle: Dictionary = _dictionary_value(result, "rattle")
	var punch: Dictionary = _dictionary_value(result, "one_two_punch")
	var aftershock: Dictionary = _dictionary_value(result, "aftershock")
	var echo: Dictionary = _dictionary_value(result, "echo_chamber")
	var state_history: Array[Dictionary] = []
	var support_rounds: Dictionary = {}
	var support_ids_seen: Dictionary = {}

	for shot in shots:
		var phase: Dictionary = _dictionary_value(shot, "phase_5c_tap_items")
		if phase.is_empty():
			continue
		var shot_key: String = _shot_key(shot)
		var round_number: int = maxi(int(shot.get("round_number", 1)), 1)
		var shot_rattle: Dictionary = _dictionary_value(phase, "rattle")
		if bool(shot_rattle.get("owned", false)):
			rattle["owned"] = true
			rattle["shots_owned"] = int(rattle["shots_owned"]) + 1
			rattle["tap_milestones_grown_from"] = int(
				rattle["tap_milestones_grown_from"]
			) + int(shot_rattle.get("tap_milestones_grown_from", 0))
			if bool(shot_rattle.get("activated_this_shot", false)):
				rattle["shots_activated"] = int(rattle["shots_activated"]) + 1
			if bool(shot_rattle.get("non_tap_shot_while_owned", false)):
				rattle["non_tap_shots_owned"] = int(rattle["non_tap_shots_owned"]) + 1
			var before: float = float(shot_rattle.get("current_xmult_before", 1.0))
			var after: float = float(shot_rattle.get("current_xmult_after", before))
			if float(rattle["acquired_value"]) <= 0.0:
				rattle["acquired_value"] = before
			rattle["current_xmult"] = after
			rattle["final_xmult"] = after
			rattle["lifetime_growth"] = maxi(
				int(rattle["lifetime_growth"]),
				int(shot_rattle.get("lifetime_growth_after", 0))
			)
			rattle["marginal_score_uplift"] = int(
				rattle["marginal_score_uplift"]
			) + int(shot_rattle.get("marginal_score_uplift", 0))
			var instance_id: int = int(shot_rattle.get("owned_item_instance_id", -1))
			var instance_ids: Array = rattle["owned_item_instance_ids"]
			if instance_id >= 0 and not instance_ids.has(instance_id):
				instance_ids.append(instance_id)
			if state_history.size() >= MAX_PHASE_5C_STATE_HISTORY:
				state_history.pop_front()
				result["state_history_dropped"] = int(result["state_history_dropped"]) + 1
			state_history.append({
				"shot_key": shot_key,
				"round_number": round_number,
				"owned_item_instance_id": instance_id,
				"current_xmult_before": before,
				"current_xmult_after": after,
				"tap_milestones": int(shot_rattle.get("tap_milestones_grown_from", 0)),
				"marginal_score_uplift": int(shot_rattle.get("marginal_score_uplift", 0)),
			})

		var shot_punch: Dictionary = _dictionary_value(phase, "one_two_punch")
		if bool(shot_punch.get("owned", false)):
			punch["owned"] = true
			punch["shots_owned"] = int(punch["shots_owned"]) + 1
			punch["qualifying_scoring_balls"] = int(
				punch["qualifying_scoring_balls"]
			) + int(shot_punch.get("qualifying_scoring_balls", 0))
			punch["activations"] = int(punch["activations"]) + int(
				shot_punch.get("activations", 0)
			)
			if bool(shot_punch.get("only_one_tap_family_present", false)):
				punch["shots_with_only_one_family"] = int(
					punch["shots_with_only_one_family"]
				) + 1
			punch["marginal_score_uplift"] = int(
				punch["marginal_score_uplift"]
			) + int(shot_punch.get("marginal_score_uplift", 0))

		var shot_aftershock: Dictionary = _dictionary_value(phase, "aftershock")
		if bool(shot_aftershock.get("owned", false)):
			aftershock["owned"] = true
			aftershock["shots_owned"] = int(aftershock["shots_owned"]) + 1
			for key in [
				"tap_milestones_while_owned",
				"ignored_first_milestones",
				"xmult_activations",
				"marginal_score_uplift",
			]:
				aftershock[key] = int(aftershock[key]) + int(shot_aftershock.get(key, 0))
			aftershock["highest_tap_ordinal"] = maxi(
				int(aftershock["highest_tap_ordinal"]),
				int(shot_aftershock.get("highest_tap_ordinal", 0))
			)

		var shot_echo: Dictionary = _dictionary_value(phase, "echo_chamber")
		if bool(shot_echo.get("owned", false)):
			echo["owned"] = true
			echo["shots_owned"] = int(echo["shots_owned"]) + 1
			for key in [
				"threshold_milestones",
				"supported_thresholds",
				"unsupported_thresholds",
				"regular_activations_retriggered",
				"retriggered_xmult_activations",
				"marginal_score_uplift",
			]:
				echo[key] = int(echo[key]) + int(shot_echo.get(key, 0))
			for key in ["retriggered_add_haul", "retriggered_add_mult"]:
				echo[key] = float(echo[key]) + float(shot_echo.get(key, 0.0))
			echo["retriggered_xmult_product"] = float(
				echo["retriggered_xmult_product"]
			) * float(shot_echo.get("retriggered_xmult_product", 1.0))
			var family_counts: Dictionary = _dictionary_value(
				echo,
				"retriggers_by_family"
			).duplicate(true)
			var shot_family_counts: Dictionary = _dictionary_value(
				shot_echo,
				"retriggers_by_family"
			)
			for family_value in shot_family_counts.keys():
				var family_id: String = str(family_value)
				family_counts[family_id] = int(family_counts.get(family_id, 0)) + int(
					shot_family_counts[family_value]
				)
			echo["retriggers_by_family"] = family_counts
			var has_support: bool = bool(shot_echo.get("has_regular_tap_support", false))
			if not support_rounds.has(round_number):
				support_rounds[round_number] = has_support
			else:
				support_rounds[round_number] = bool(support_rounds[round_number]) or has_support
			for support_id_value in shot_echo.get("support_item_ids", []):
				support_ids_seen[str(support_id_value)] = true

	for round_record in rounds:
		var round_number: int = maxi(int(round_record.get("round_number", 1)), 1)
		var build_ids: Array[String] = _normalize_build_item_ids(round_record.get(
			"build_at_round_start",
			[]
		))
		if build_ids.is_empty():
			build_ids = _normalize_build_item_ids(round_record.get(
				"build_at_round_end",
				[]
			))
		if not build_ids.has(ECHO_CHAMBER_ITEM_ID):
			continue
		echo["owned"] = true
		var has_support: bool = _has_regular_tap_support(build_ids)
		support_rounds[round_number] = has_support
		for item_id in REGULAR_DOUBLE_TAP_ITEM_IDS + REGULAR_BALL_TAP_ITEM_IDS:
			if build_ids.has(item_id):
				support_ids_seen[item_id] = true

	var with_support: Array[int] = []
	var without_support: Array[int] = []
	for round_value in support_rounds.keys():
		var round_number: int = int(round_value)
		if bool(support_rounds[round_value]):
			with_support.append(round_number)
		else:
			without_support.append(round_number)
	with_support.sort()
	without_support.sort()
	var support_ids: Array[String] = []
	for support_id_value in support_ids_seen.keys():
		support_ids.append(str(support_id_value))
	support_ids.sort()
	echo["round_numbers_owned_with_support"] = with_support
	echo["round_numbers_owned_without_support"] = without_support
	echo["rounds_owned_with_support"] = with_support.size()
	echo["rounds_owned_without_support"] = without_support.size()
	echo["support_item_ids_seen"] = support_ids
	result["rattle"] = rattle
	result["one_two_punch"] = punch
	result["aftershock"] = aftershock
	result["echo_chamber"] = echo
	result["state_history"] = state_history
	var accumulator: Dictionary = _dictionary_value(
		_dictionary_value(snapshot, "run_accumulators"),
		"phase_5c_tap_items"
	)
	result["state_history_dropped"] = maxi(
		int(result["state_history_dropped"]),
		int(accumulator.get("state_history_dropped", 0))
	)
	_attach_phase_5c_item_metrics(items, result)
	return result


static func _attach_phase_5c_item_metrics(
	items: Array[Dictionary],
	phase_metrics: Dictionary
) -> void:
	var metric_key_by_item: Dictionary = {
		RATTLE_ITEM_ID: "rattle",
		ONE_TWO_PUNCH_ITEM_ID: "one_two_punch",
		AFTERSHOCK_ITEM_ID: "aftershock",
		ECHO_CHAMBER_ITEM_ID: "echo_chamber",
	}
	for item in items:
		var item_id: String = _item_id(item)
		if not metric_key_by_item.has(item_id):
			continue
		var metrics: Dictionary = _dictionary_value(
			phase_metrics,
			str(metric_key_by_item[item_id])
		)
		item["phase_5c_metrics"] = metrics.duplicate(true)
		for key_value in metrics.keys():
			var key: String = str(key_value)
			if ["eight_ball_item_id", "display_name", "owned"].has(key):
				continue
			item[key] = metrics[key_value]


static func _has_regular_tap_support(item_ids: Array[String]) -> bool:
	for item_id in REGULAR_DOUBLE_TAP_ITEM_IDS + REGULAR_BALL_TAP_ITEM_IDS:
		if item_ids.has(item_id):
			return true
	return false


static func _aggregate_run_summary(
	snapshot: Dictionary,
	shots: Array[Dictionary],
	rounds: Array[Dictionary],
	items: Array[Dictionary],
	tap_metrics: Dictionary
) -> Dictionary:
	var summary: Dictionary = _empty_run_summary(snapshot)
	var scores: Array[int] = []
	var total_score: int = 0
	var total_base_score: int = 0
	var total_doubloons: int = 0
	var total_balls: int = 0
	var scratches: int = 0
	var max_haul: int = 0
	var max_mult: float = 1.0
	var max_xmult: float = 1.0
	var max_excitement: float = float(snapshot.get("maximum_global_excitement", 0.0))
	for shot in shots:
		var score: int = _shot_score(shot)
		var base_score: int = _base_score(shot)
		scores.append(score)
		total_score += score
		total_base_score += base_score
		total_doubloons += _shot_doubloon_payout(shot)
		total_balls += maxi(int(shot.get("object_balls_pocketed", 0)), 0)
		if bool(shot.get("scratch", false)):
			scratches += 1
		max_haul = maxi(max_haul, int(shot.get("final_haul", shot.get("base_haul", 0))))
		max_mult = maxf(max_mult, float(shot.get("final_mult", 1.0)))
		max_xmult = maxf(max_xmult, float(shot.get("build_xmult_product", shot.get("xmult_product", 1.0))))
		max_excitement = maxf(
			max_excitement,
			float(shot.get("maximum_global_excitement", shot.get("global_excitement", 0.0)))
		)
	var highest: int = 0
	for score in scores:
		highest = maxi(highest, score)
	var uplift: int = total_score - total_base_score
	var rounds_reached: int = 0
	for round_record in rounds:
		rounds_reached = maxi(rounds_reached, int(round_record.get("round_number", 0)))
	summary["rounds_reached"] = maxi(
		rounds_reached,
		int(snapshot.get("rounds_reached", 0))
	)
	summary["final_outcome"] = str(snapshot.get(
		"final_outcome",
		snapshot.get("outcome", "")
	))
	summary["total_authoritative_score"] = total_score
	summary["total_base_score_without_build"] = total_base_score
	summary["total_build_uplift"] = uplift
	summary["build_uplift_percentage"] = _safe_ratio(
		float(uplift) * 100.0,
		float(total_base_score)
	)
	summary["total_doubloons_from_base_haul"] = total_doubloons
	summary["total_scoring_balls_pocketed"] = total_balls
	summary["total_shots"] = shots.size()
	summary["zero_score_shots"] = _zero_score_shot_count(shots)
	summary["scratches"] = scratches
	summary["highest_shot"] = highest
	summary["average_shot"] = _safe_ratio(float(total_score), float(shots.size()))
	summary["median_shot"] = _median(scores)
	summary["largest_shot_percentage"] = _safe_ratio(
		float(highest) * 100.0,
		float(total_score)
	)
	summary["maximum_haul"] = max_haul
	summary["maximum_mult"] = max_mult
	summary["maximum_xmult_product"] = max_xmult
	summary["maximum_global_excitement"] = max_excitement
	summary["most_valuable_item"] = _select_item_extreme(items, "final_score_uplift", true)
	summary["most_frequently_triggered_item"] = _select_item_extreme(
		items,
		"trigger_occurrences",
		true
	)
	summary["least_triggered_owned_item"] = _least_triggered_owned_item(items)
	summary["tap_metrics"] = tap_metrics.duplicate(true)
	for key in [
		"shots_with_double_tap",
		"shots_with_triple_tap_or_higher",
		"scoring_balls_with_ball_tap",
		"average_double_tap_mult",
		"average_ball_tap_mult",
		"maximum_cue_strikes_against_one_scoring_ball",
		"maximum_ball_taps_by_one_scoring_ball",
		"cue_recontact_score_supplied",
		"double_tap_score_supplied",
		"ball_tap_score_supplied",
		"total_tap_score_supplied",
	]:
		summary[key] = tap_metrics.get(key, 0)
	return summary


static func _aggregate_attribution(
	shots: Array[Dictionary],
	items: Array[Dictionary],
	run_summary: Dictionary,
	diagnostics: Dictionary
) -> Dictionary:
	var attribution: Dictionary = _empty_attribution()
	var summed_marginal: int = 0
	for item in items:
		summed_marginal += int(item.get("final_score_uplift", 0))
	var build_uplift: int = int(run_summary.get("total_build_uplift", _sum_build_uplift(shots)))
	var available: int = int(diagnostics.get("available_item_counterfactuals", 0))
	var missing: int = int(diagnostics.get("missing_item_counterfactuals", 0))
	attribution["total_build_uplift"] = build_uplift
	attribution["total_item_marginal_uplift"] = summed_marginal
	attribution["interaction_surplus"] = build_uplift - summed_marginal
	attribution["counterfactuals_available"] = available
	attribution["counterfactuals_missing"] = missing
	attribution["attribution_complete"] = missing == 0
	return attribution


static func _classify_build(
	items: Array[Dictionary],
	attribution: Dictionary,
	phase_5c_tap_items: Dictionary = {}
) -> Dictionary:
	var family_uplift: Dictionary = {}
	var family_activations: Dictionary = {}
	var total_uplift: float = 0.0
	var total_activations: float = 0.0
	for item in items:
		var family_id: String = str(item.get("family_id", FAMILY_UNKNOWN))
		var uplift: float = float(item.get("final_score_uplift", 0))
		var activations: float = float(item.get("trigger_occurrences", 0))
		family_uplift[family_id] = float(family_uplift.get(family_id, 0.0)) + uplift
		family_activations[family_id] = float(family_activations.get(family_id, 0.0)) + activations
		total_uplift += uplift
		total_activations += activations
	var uplift_share: Dictionary = _shares(family_uplift, total_uplift)
	var activation_share: Dictionary = _shares(family_activations, total_activations)
	var single_share: float = float(uplift_share.get(FAMILY_SINGLE_BANK, 0.0))
	var deep_share: float = (
		float(uplift_share.get(FAMILY_DOUBLE_BANK, 0.0))
		+ float(uplift_share.get(FAMILY_TRIPLE_BANK, 0.0))
	)
	var combination_share: float = float(uplift_share.get(FAMILY_COMBINATION, 0.0))
	var direct_share: float = float(uplift_share.get(FAMILY_DIRECT_POT, 0.0))
	var multi_share: float = float(uplift_share.get(FAMILY_MULTI_POT, 0.0))
	var same_pocket_share: float = float(uplift_share.get(FAMILY_SAME_POCKET, 0.0))
	var double_tap_share: float = (
		float(uplift_share.get(FAMILY_DOUBLE_TAP, 0.0))
		+ float(uplift_share.get(FAMILY_CUE_RECONTACT, 0.0))
	)
	var ball_tap_share: float = float(uplift_share.get(FAMILY_BALL_TAP, 0.0))
	var bank_share: float = single_share + deep_share
	var archetype_shares: Dictionary = {
		"bank": bank_share,
		FAMILY_COMBINATION: combination_share,
		FAMILY_DIRECT_POT: direct_share,
		FAMILY_MULTI_POT: multi_share,
		FAMILY_SAME_POCKET: same_pocket_share,
		FAMILY_DOUBLE_TAP: double_tap_share,
		FAMILY_BALL_TAP: ball_tap_share,
	}
	var hybrid_archetypes: Array[String] = []
	for archetype_value in archetype_shares.keys():
		var archetype: String = str(archetype_value)
		if float(archetype_shares[archetype_value]) >= IDENTITY_HYBRID_SHARE:
			hybrid_archetypes.append(archetype)
	hybrid_archetypes.sort()
	var label: String = "Unformed Build"
	var reason: String = "No analyzed build contribution or activation data."
	var rattle: Dictionary = _dictionary_value(phase_5c_tap_items, "rattle")
	var punch: Dictionary = _dictionary_value(phase_5c_tap_items, "one_two_punch")
	var rattle_uplift: float = float(rattle.get("marginal_score_uplift", 0))
	var rattle_share: float = _safe_ratio(rattle_uplift, total_uplift)
	if total_uplift > 0.0:
		if bool(rattle.get("owned", false)) and rattle_share >= IDENTITY_DOMINANT_SHARE:
			label = "Tap Growth Engine"
			reason = "Rattle of the Deep supplied %.1f%% of represented marginal uplift." % (
				rattle_share * 100.0
			)
		elif (
			double_tap_share >= IDENTITY_HYBRID_SHARE
			and ball_tap_share >= IDENTITY_HYBRID_SHARE
		) or (
			bool(punch.get("owned", false))
			and int(punch.get("activations", 0)) > 0
		):
			label = "Tap Hybrid"
			reason = (
				"Double Tap and Ball Tap supplied %.1f%% / %.1f%% of represented marginal "
				+ "uplift."
			) % [double_tap_share * 100.0, ball_tap_share * 100.0]
		elif double_tap_share >= IDENTITY_DOMINANT_SHARE:
			label = "Double Tap Engine"
			reason = "Double Tap supplied %.1f%% of represented marginal uplift." % (
				double_tap_share * 100.0
			)
		elif ball_tap_share >= IDENTITY_DOMINANT_SHARE:
			label = "Ball Tap Engine"
			reason = "Ball Tap supplied %.1f%% of represented marginal uplift." % (
				ball_tap_share * 100.0
			)
		elif hybrid_archetypes.size() >= 3:
			label = "Generalist"
			reason = (
				"At least three trigger families each supplied 25%% or more of represented "
				+ "marginal uplift."
			)
		elif hybrid_archetypes.size() == 2 and hybrid_archetypes.has("bank") and (
			hybrid_archetypes.has(FAMILY_COMBINATION)
		):
			label = "Bank / Combination Hybrid"
			reason = (
				"Bank families supplied %.1f%% and Combination supplied %.1f%% of "
				+ "represented marginal uplift."
			) % [bank_share * 100.0, combination_share * 100.0]
		elif hybrid_archetypes.size() == 2:
			label = "%s / %s Hybrid" % [
				_identity_archetype_label(hybrid_archetypes[0]),
				_identity_archetype_label(hybrid_archetypes[1]),
			]
			reason = "%s and %s each supplied at least 25%% of represented marginal uplift." % [
				_identity_archetype_label(hybrid_archetypes[0]),
				_identity_archetype_label(hybrid_archetypes[1]),
			]
		elif single_share >= IDENTITY_DOMINANT_SHARE:
			label = "Single Bank Engine"
			reason = "Single Bank supplied %.1f%% of represented marginal uplift." % (
				single_share * 100.0
			)
		elif deep_share >= IDENTITY_DOMINANT_SHARE:
			label = "Deep Bank Engine"
			reason = "Double and Triple Bank supplied %.1f%% of represented marginal uplift." % (
				deep_share * 100.0
			)
		elif combination_share >= IDENTITY_DOMINANT_SHARE:
			label = "Combination Engine"
			reason = "Combination supplied %.1f%% of represented marginal uplift." % (
				combination_share * 100.0
			)
		elif direct_share >= IDENTITY_DOMINANT_SHARE:
			label = "Direct Pot Engine"
			reason = "Direct Pot supplied %.1f%% of represented marginal uplift." % (
				direct_share * 100.0
			)
		elif multi_share >= IDENTITY_DOMINANT_SHARE:
			label = "Multi-Pot Engine"
			reason = "Multi-Pot supplied %.1f%% of represented marginal uplift." % (
				multi_share * 100.0
			)
		elif same_pocket_share >= IDENTITY_DOMINANT_SHARE:
			label = "Same-Pocket Engine"
			reason = "Same-Pocket supplied %.1f%% of represented marginal uplift." % (
				same_pocket_share * 100.0
			)
		else:
			label = "Generalist"
			reason = "No family reached the 45%% dominant-uplift threshold."
	elif total_activations > 0.0:
		if bool(rattle.get("owned", false)) and int(rattle.get("shots_activated", 0)) > 0:
			label = "Tap Growth Engine"
			reason = "Rattle of the Deep activated, but represented marginal uplift was zero."
		elif bool(punch.get("owned", false)) and int(punch.get("activations", 0)) > 0:
			label = "Tap Hybrid"
			reason = "One-Two Punch joined Double Tap and Ball Tap on a scoring ball."
		elif (
			(
				float(activation_share.get(FAMILY_DOUBLE_TAP, 0.0))
				+ float(activation_share.get(FAMILY_CUE_RECONTACT, 0.0))
			) >= IDENTITY_HYBRID_SHARE
			and float(activation_share.get(FAMILY_BALL_TAP, 0.0)) >= IDENTITY_HYBRID_SHARE
		):
			label = "Tap Hybrid"
			reason = "Double Tap and Ball Tap both supplied at least 25% of activations."
		elif (
			float(activation_share.get(FAMILY_DOUBLE_TAP, 0.0))
			+ float(activation_share.get(FAMILY_CUE_RECONTACT, 0.0))
		) >= IDENTITY_DOMINANT_SHARE:
			label = "Double Tap Engine"
			reason = "Double Tap supplied the dominant activation share."
		elif float(activation_share.get(FAMILY_BALL_TAP, 0.0)) >= IDENTITY_DOMINANT_SHARE:
			label = "Ball Tap Engine"
			reason = "Ball Tap supplied the dominant activation share."
		else:
			label = "Generalist"
			reason = "Items activated, but represented marginal uplift was zero."
	return {
		"label": label,
		"reason": reason,
		"family_uplift": family_uplift,
		"family_uplift_share": uplift_share,
		"family_activation_share": activation_share,
		"double_tap_uplift_share": double_tap_share,
		"ball_tap_uplift_share": ball_tap_share,
		"rattle_uplift_share": rattle_share,
		"interaction_surplus": int(attribution.get("interaction_surplus", 0)),
	}


static func _identity_archetype_label(archetype: String) -> String:
	match archetype:
		"bank":
			return "Bank"
		FAMILY_COMBINATION:
			return "Combination"
		FAMILY_DIRECT_POT:
			return "Direct Pot"
		FAMILY_MULTI_POT:
			return "Multi-Pot"
		FAMILY_SAME_POCKET:
			return "Same-Pocket"
		FAMILY_DOUBLE_TAP:
			return "Double Tap"
		FAMILY_BALL_TAP:
			return "Ball Tap"
		_:
			return archetype.capitalize()


static func _build_shot_distribution(shots: Array[Dictionary]) -> Dictionary:
	var distribution: Dictionary = {
		"zero": 0,
		"low": 0,
		"medium": 0,
		"high": 0,
		"low_max": LOW_SHOT_MAX,
		"medium_max": MEDIUM_SHOT_MAX,
		"largest_shot": 0,
		"largest_shot_concentration": 0.0,
	}
	var total: int = 0
	var highest: int = 0
	for shot in shots:
		var score: int = _shot_score(shot)
		total += score
		highest = maxi(highest, score)
		if score <= 0:
			distribution["zero"] = int(distribution["zero"]) + 1
		elif score <= LOW_SHOT_MAX:
			distribution["low"] = int(distribution["low"]) + 1
		elif score <= MEDIUM_SHOT_MAX:
			distribution["medium"] = int(distribution["medium"]) + 1
		else:
			distribution["high"] = int(distribution["high"]) + 1
	distribution["largest_shot"] = highest
	distribution["largest_shot_concentration"] = _safe_ratio(float(highest), float(total))
	return distribution


static func _build_watch_flags(
	run_summary: Dictionary,
	rounds: Array[Dictionary],
	items: Array[Dictionary],
	offers: Dictionary,
	_attribution: Dictionary,
	tap_metrics: Dictionary
) -> Array[Dictionary]:
	var flags: Array[Dictionary] = []
	var family_uplift: Dictionary = {}
	var total_marginal: float = 0.0
	for item in items:
		var family_id: String = str(item.get("family_id", FAMILY_UNKNOWN))
		var uplift: float = float(item.get("final_score_uplift", 0))
		family_uplift[family_id] = float(family_uplift.get(family_id, 0.0)) + uplift
		total_marginal += uplift
	var single_share: float = _safe_ratio(
		float(family_uplift.get(FAMILY_SINGLE_BANK, 0.0)),
		total_marginal
	)
	var family_activations: Dictionary = {}
	for item in items:
		var activation_family: String = str(item.get("family_id", FAMILY_UNKNOWN))
		family_activations[activation_family] = int(family_activations.get(
			activation_family,
			0
		)) + int(item.get("trigger_occurrences", 0))
	var single_activations: int = int(family_activations.get(FAMILY_SINGLE_BANK, 0))
	var other_activations: int = 0
	for family_id in [
		FAMILY_DOUBLE_BANK,
		FAMILY_TRIPLE_BANK,
		FAMILY_COMBINATION,
		FAMILY_DIRECT_POT,
		FAMILY_MULTI_POT,
		FAMILY_SAME_POCKET,
	]:
		other_activations += int(family_activations.get(family_id, 0))
	var total_activations: int = single_activations + other_activations
	var single_activation_share: float = _safe_ratio(
		float(single_activations),
		float(total_activations)
	)
	var family_offer_share: Dictionary = _dictionary_value(offers, "family_offer_share")
	var single_offer_share: float = float(family_offer_share.get(FAMILY_SINGLE_BANK, 0.0))
	var single_activation_dominant: bool = (
		total_activations >= 6
		and single_activation_share > 0.60
	)
	var single_offer_dominant: bool = (
		int(offers.get("total_offer_cards", 0)) >= OFFER_BIAS_MIN_CARDS
		and single_offer_share > OFFER_BIAS_SHARE
	)
	if (
		single_share > SINGLE_BANK_DOMINANCE_SHARE
		or single_activation_dominant
		or single_offer_dominant
	):
		var dominance_reasons: PackedStringArray = PackedStringArray()
		if single_share > SINGLE_BANK_DOMINANCE_SHARE:
			dominance_reasons.append("marginal uplift")
		if single_activation_dominant:
			dominance_reasons.append("activation frequency")
		if single_offer_dominant:
			dominance_reasons.append("offer share")
		flags.append(_watch_flag(
			WATCH_SINGLE_BANK_DOMINANCE,
			"SINGLE BANK DOMINANCE",
			"Single Bank dominated %s in this run." % ", ".join(dominance_reasons),
			{
				"uplift_share": single_share,
				"activation_share": single_activation_share,
				"offer_share": single_offer_share,
				"uplift_threshold": SINGLE_BANK_DOMINANCE_SHARE,
				"offer_threshold": OFFER_BIAS_SHARE,
			}
		))

	var largest_share: float = float(run_summary.get("largest_shot_percentage", 0.0)) / 100.0
	if largest_share > ONE_SHOT_CONCENTRATION_SHARE:
		flags.append(_watch_flag(
			WATCH_ONE_SHOT_CONCENTRATION,
			"ONE-SHOT CONCENTRATION",
			"One shot supplied more than 40% of total run score.",
			{"share": largest_share, "threshold": ONE_SHOT_CONCENTRATION_SHARE}
		))

	var underpressure_streak: int = 0
	for round_record in rounds:
		var quota: int = int(round_record.get("quota", 0))
		var overflow: int = int(round_record.get("score_overflow", 0))
		if quota > 0 and overflow > quota:
			underpressure_streak += 1
		else:
			underpressure_streak = 0
		if underpressure_streak >= QUOTA_UNDERPRESSURE_STREAK:
			flags.append(_watch_flag(
				WATCH_QUOTA_UNDERPRESSURE,
				"QUOTA UNDERPRESSURE",
				"Three consecutive rounds exceeded quota by more than 100%.",
				{"consecutive_rounds": underpressure_streak}
			))
			break

	for item in items:
		if int(item.get("rounds_owned", 0)) >= DEAD_ITEM_MIN_FULL_ROUNDS and int(
			item.get("trigger_occurrences", 0)
		) == 0:
			flags.append(_watch_flag(
				WATCH_DEAD_ITEM,
				"DEAD ITEM",
				"An owned item triggered zero times across at least two full rounds.",
				{
					"eight_ball_item_id": str(item.get("eight_ball_item_id", "")),
					"rounds_owned": int(item.get("rounds_owned", 0)),
				}
			))

	var total_offer_cards: int = int(offers.get("total_offer_cards", 0))
	if total_offer_cards >= OFFER_BIAS_MIN_CARDS:
		for family_id_value in family_offer_share.keys():
			var share: float = float(family_offer_share[family_id_value])
			if share > OFFER_BIAS_SHARE:
				flags.append(_watch_flag(
					WATCH_OFFER_BIAS,
					"OFFER BIAS",
					"One family represented more than 50% of a sufficiently large offer sample.",
					{
						"family_id": str(family_id_value),
						"share": share,
						"offer_cards": total_offer_cards,
					}
				))
	var exploit_examples: Array[Dictionary] = _dictionary_array_value(
		tap_metrics,
		"tap_exploit_candidate_shots"
	)
	if not exploit_examples.is_empty():
		flags.append(_watch_flag(
			WATCH_TAP_EXPLOIT,
			"TAP EXPLOIT WATCH",
			"A scoring ball received at least %d qualifying cue strikes in one shot."
				% TAP_EXPLOIT_MAX_CUE_STRIKES_PER_BALL,
			{
				"threshold_max_cue_strikes_per_ball": TAP_EXPLOIT_MAX_CUE_STRIKES_PER_BALL,
				"candidate_shot_count": int(tap_metrics.get(
					"tap_exploit_candidate_shot_count",
					exploit_examples.size()
				)),
				"candidate_shots": exploit_examples,
			}
		))
	var farm_examples: Array[Dictionary] = _dictionary_array_value(
		tap_metrics,
		"contact_farm_candidate_shots"
	)
	if not farm_examples.is_empty():
		flags.append(_watch_flag(
			WATCH_CONTACT_FARM,
			"CONTACT FARM WATCH",
			(
				"A shot recorded at least %d ignored same-target contacts at a repeated-to-unique ratio of %.1f or higher."
				% [
					CONTACT_FARM_MIN_REPEATED_CONTACTS_PER_SHOT,
					CONTACT_FARM_REPEATED_TO_UNIQUE_RATIO,
				]
			),
			{
				"threshold_repeated_contacts_per_shot": CONTACT_FARM_MIN_REPEATED_CONTACTS_PER_SHOT,
				"threshold_repeated_to_unique_ratio": CONTACT_FARM_REPEATED_TO_UNIQUE_RATIO,
				"candidate_shot_count": int(tap_metrics.get(
					"contact_farm_candidate_shot_count",
					farm_examples.size()
				)),
				"candidate_shots": farm_examples,
			}
		))
	flags.sort_custom(_watch_flag_precedes)
	return flags


static func _watch_flag(flag_id: String, label: String, message: String, evidence: Dictionary) -> Dictionary:
	return {
		"id": flag_id,
		"label": label,
		"message": message,
		"evidence": evidence.duplicate(true),
		"diagnostic_only": true,
	}


static func _finalize_report(
	report: Dictionary,
	warnings: Array[String],
	started_at_usec: int
) -> Dictionary:
	report["warnings"] = warnings.duplicate()
	report["copy_summary"] = _format_copy_summary(report)
	report["copy_item_contribution_table"] = _format_item_table(report)
	report["copy_round_table"] = _format_round_table(report)
	report["analysis_duration_usec"] = maxi(Time.get_ticks_usec() - started_at_usec, 0)
	var json_data: Dictionary = report.duplicate(true)
	json_data.erase("copy_json")
	json_data.erase("json_data")
	report["json_data"] = json_data.duplicate(true)
	report["copy_json"] = JSON.stringify(json_data, "  ")
	return report.duplicate(true)


static func _format_copy_summary(report: Dictionary) -> String:
	if bool(report.get("excluded", false)):
		return "Balance Report excluded: %s" % str(report.get("exclusion_reason", "unknown"))
	var summary: Dictionary = _dictionary_value(report, "run_summary")
	var identity: Dictionary = _dictionary_value(report, "build_identity")
	var lines: Array[String] = []
	lines.append("Run: Round %d - %s" % [
		int(summary.get("rounds_reached", 0)),
		str(summary.get("final_outcome", "Unknown Outcome")),
	])
	lines.append("Build: %s" % str(identity.get("label", "Unformed Build")))
	lines.append("Score: %d" % int(summary.get("total_authoritative_score", 0)))
	lines.append("Base Score: %d" % int(summary.get("total_base_score_without_build", 0)))
	lines.append("Build Uplift: %d (%.1f%%)" % [
		int(summary.get("total_build_uplift", 0)),
		float(summary.get("build_uplift_percentage", 0.0)),
	])
	var tap_metrics: Dictionary = _dictionary_value(report, "tap_metrics")
	if (
		int(tap_metrics.get("cue_recontact_milestones", 0)) > 0
		or int(tap_metrics.get("ball_tap_milestones", 0)) > 0
		or int(tap_metrics.get("repeated_ball_tap_contacts_ignored", 0)) > 0
	):
		lines.append("")
		lines.append("Tap Scoring: %d Double/Triple shots, %d Ball Tap balls" % [
			int(tap_metrics.get("shots_with_double_tap", 0)),
			int(tap_metrics.get("scoring_balls_with_ball_tap", 0)),
		])
		lines.append("Tap Milestones: %d cue recontacts + %d unique Ball Taps" % [
			int(tap_metrics.get("cue_recontact_milestones", 0)),
			int(tap_metrics.get("ball_tap_milestones", 0)),
		])
		lines.append("Tap Score Supplied: %d cue + %d ball = %d" % [
			int(tap_metrics.get("cue_recontact_score_supplied", 0)),
			int(tap_metrics.get("ball_tap_score_supplied", 0)),
			int(tap_metrics.get("total_tap_score_supplied", 0)),
		])
	var phase_5c: Dictionary = _dictionary_value(report, "phase_5c_tap_items")
	var rattle: Dictionary = _dictionary_value(phase_5c, "rattle")
	var punch: Dictionary = _dictionary_value(phase_5c, "one_two_punch")
	var aftershock: Dictionary = _dictionary_value(phase_5c, "aftershock")
	var echo: Dictionary = _dictionary_value(phase_5c, "echo_chamber")
	if (
		bool(rattle.get("owned", false))
		or bool(punch.get("owned", false))
		or bool(aftershock.get("owned", false))
		or bool(echo.get("owned", false))
	):
		lines.append("")
		lines.append("Tap Engine:")
		if bool(rattle.get("owned", false)):
			lines.append("Rattle x%.2f -> x%.2f, %d growth Taps, %d marginal score" % [
				float(rattle.get("acquired_value", 0.0)),
				float(rattle.get("final_xmult", 0.0)),
				int(rattle.get("tap_milestones_grown_from", 0)),
				int(rattle.get("marginal_score_uplift", 0)),
			])
		if bool(punch.get("owned", false)):
			lines.append("One-Two Punch: %d qualifying balls, %d activations, %d marginal score" % [
				int(punch.get("qualifying_scoring_balls", 0)),
				int(punch.get("activations", 0)),
				int(punch.get("marginal_score_uplift", 0)),
			])
		if bool(aftershock.get("owned", false)):
			lines.append("Aftershock: %d xMult activations, highest Tap %d, %d marginal score" % [
				int(aftershock.get("xmult_activations", 0)),
				int(aftershock.get("highest_tap_ordinal", 0)),
				int(aftershock.get("marginal_score_uplift", 0)),
			])
		if bool(echo.get("owned", false)):
			lines.append("Echo Chamber: %d supported / %d unsupported thresholds, %d retriggers, %d marginal score" % [
				int(echo.get("supported_thresholds", 0)),
				int(echo.get("unsupported_thresholds", 0)),
				int(echo.get("regular_activations_retriggered", 0)),
				int(echo.get("marginal_score_uplift", 0)),
			])
			lines.append("Echo support rounds: %d with / %d without" % [
				int(echo.get("rounds_owned_with_support", 0)),
				int(echo.get("rounds_owned_without_support", 0)),
			])
	var valuable: Dictionary = _dictionary_value(summary, "most_valuable_item")
	if not valuable.is_empty():
		lines.append("")
		lines.append("Most Valuable: %s" % str(valuable.get("display_name", "Unknown")))
		lines.append("%d activations" % int(valuable.get("trigger_occurrences", 0)))
		lines.append("%d marginal score" % int(valuable.get("final_score_uplift", 0)))
	var dead_reckoning: Dictionary = _dictionary_value(report, "dead_reckoning_metrics")
	if bool(dead_reckoning.get("owned", false)):
		lines.append("")
		lines.append("Dead Reckoning: %d supported / %d dead Direct Pots" % [
			int(dead_reckoning.get("supported_occurrences", 0)),
			int(dead_reckoning.get("unsupported_occurrences", 0)),
		])
		lines.append("%d regular activations retriggered" % int(
			dead_reckoning.get("regular_activations_retriggered", 0)
		))
		lines.append("%d marginal score" % int(dead_reckoning.get(
			"marginal_score_uplift",
			0
		)))
	lines.append("")
	lines.append("Largest Shot: %d - %.1f%% of run score" % [
		int(summary.get("highest_shot", 0)),
		float(summary.get("largest_shot_percentage", 0.0)),
	])
	return "\n".join(lines)


static func _format_item_table(report: Dictionary) -> String:
	var lines: Array[String] = [
		"Item\tFamily\tEffect Kind\tSlot\tRounds Owned\tActivations\tRegular\tRetriggers\t+Haul\t+Mult\txMult Product\tMarginal Score\tBuild Uplift %\tState / Support"
	]
	for item in _dictionary_array_value(report, "item_metrics"):
		var state_summary: String = ""
		if item.has("final_xmult"):
			state_summary = "x%.2f" % float(item.get("final_xmult", 0.0))
		elif item.has("rounds_owned_without_support"):
			state_summary = "%d with / %d without support" % [
				int(item.get("rounds_owned_with_support", 0)),
				int(item.get("rounds_owned_without_support", 0)),
			]
		lines.append("%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.1f\t%.1f\t%.3f\t%d\t%.1f%%\t%s" % [
			str(item.get("display_name", item.get("eight_ball_item_id", "Unknown"))),
			str(item.get("family_id", FAMILY_UNKNOWN)),
			str(item.get("effect_kind", "")),
			int(item.get("tray_slot", -1)),
			int(item.get("rounds_owned", 0)),
			int(item.get("trigger_occurrences", 0)),
			int(item.get("regular_activations", 0)),
			int(item.get("retriggered_activations", 0)),
			float(item.get("total_haul_added", 0.0)),
			float(item.get("total_mult_added", 0.0)),
			float(item.get("cumulative_xmult_factor", 1.0)),
			int(item.get("final_score_uplift", 0)),
			float(item.get("percentage_of_build_uplift", 0.0)),
			state_summary,
		])
	return "\n".join(lines)


static func _format_round_table(report: Dictionary) -> String:
	var lines: Array[String] = [
		"Round\tQuota\tScore\tOverflow\tShots Used\tZero Shots\tHighest Shot\tOutcome"
	]
	for round_record in _dictionary_array_value(report, "round_metrics"):
		lines.append("%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s" % [
			int(round_record.get("round_number", 0)),
			int(round_record.get("quota", 0)),
			int(round_record.get("round_score", 0)),
			int(round_record.get("score_overflow", 0)),
			int(round_record.get("shots_used", 0)),
			int(round_record.get("zero_score_shots", 0)),
			int(round_record.get("highest_shot", 0)),
			str(round_record.get("outcome", "")),
		])
	return "\n".join(lines)


static func _item_marginal_for_shot(
	shot: Dictionary,
	item_id: String,
	activations: Array[Dictionary]
) -> Dictionary:
	var uplift_map: Dictionary = _dictionary_alias(
		shot,
		["item_marginal_uplift_by_id", "marginal_uplift_by_item"]
	)
	if uplift_map.has(item_id):
		return {"available": true, "uplift": int(uplift_map[item_id]), "source": "marginal_map"}
	var without_map: Dictionary = _dictionary_alias(
		shot,
		["score_without_item_by_id", "counterfactual_score_without_item"]
	)
	if without_map.has(item_id):
		return {
			"available": true,
			"uplift": _shot_score(shot) - int(without_map[item_id]),
			"source": "leave_one_out_score",
		}
	var compact_counterfactuals: Dictionary = _dictionary_value(
		shot,
		"item_counterfactual_scores"
	)
	var compact_value: Variant = compact_counterfactuals.get(item_id, {})
	if compact_value is Dictionary:
		var compact_record: Dictionary = compact_value as Dictionary
		if bool(compact_record.get("available", false)):
			if compact_record.has("marginal_score_uplift"):
				return {
					"available": true,
					"uplift": int(compact_record.get("marginal_score_uplift", 0)),
					"source": "compact_counterfactual",
				}
			if compact_record.has("score_without_item"):
				return {
					"available": true,
					"uplift": _shot_score(shot) - int(compact_record.get("score_without_item", 0)),
					"source": "compact_leave_one_out_score",
				}
	for activation in activations:
		if _item_id(activation) != item_id:
			continue
		if activation.has("item_marginal_score_uplift"):
			return {
				"available": true,
				"uplift": int(activation.get("item_marginal_score_uplift", 0)),
				"source": "activation_item_marginal",
			}
		if activation.has("score_without_item"):
			return {
				"available": true,
				"uplift": _shot_score(shot) - int(activation.get("score_without_item", 0)),
				"source": "activation_leave_one_out_score",
			}
	return {"available": false, "uplift": 0, "source": "missing"}


static func _tap_metrics_for_shot(shot: Dictionary) -> Dictionary:
	var tap: Dictionary = _dictionary_value(shot, "tap_metrics").duplicate(true)
	var counts: Dictionary = _shot_trigger_counts(shot)
	var cue_milestones: int = maxi(int(tap.get(
		"cue_recontact_milestones",
		shot.get(
			"cue_recontact_milestone_count",
			counts.get(TRIGGER_CUE_RECONTACT, 0)
		)
	)), 0)
	var ball_milestones: int = maxi(int(tap.get(
		"ball_tap_milestones",
		shot.get("ball_tap_milestone_count", counts.get(TRIGGER_OBJECT_BALL_TAP, 0))
	)), 0)
	tap["cue_recontact_milestones"] = cue_milestones
	tap["ball_tap_milestones"] = ball_milestones
	tap["cue_recontact_mult"] = maxi(int(tap.get("cue_recontact_mult", cue_milestones)), 0)
	tap["ball_tap_mult"] = maxi(int(tap.get("ball_tap_mult", ball_milestones)), 0)
	tap["maximum_cue_strikes_against_one_scoring_ball"] = maxi(int(tap.get(
		"maximum_cue_strikes_against_one_scoring_ball",
		shot.get("maximum_cue_strikes_against_one_scoring_ball", 0)
	)), 0)
	tap["maximum_ball_taps_by_one_scoring_ball"] = maxi(int(tap.get(
		"maximum_ball_taps_by_one_scoring_ball",
		shot.get("maximum_ball_taps_by_one_scoring_ball", ball_milestones)
	)), 0)
	tap["unique_ball_tap_target_count"] = maxi(int(tap.get(
		"unique_ball_tap_target_count",
		shot.get("unique_ball_tap_target_count", ball_milestones)
	)), 0)
	tap["scoring_balls_with_double_tap"] = maxi(int(tap.get(
		"scoring_balls_with_double_tap",
		1 if cue_milestones > 0 else 0
	)), 0)
	tap["scoring_balls_with_triple_tap_or_higher"] = maxi(int(tap.get(
		"scoring_balls_with_triple_tap_or_higher",
		1 if int(tap["maximum_cue_strikes_against_one_scoring_ball"]) >= 3 else 0
	)), 0)
	tap["scoring_balls_with_ball_tap"] = maxi(int(tap.get(
		"scoring_balls_with_ball_tap",
		1 if ball_milestones > 0 else 0
	)), 0)
	tap["repeated_ball_tap_contacts_ignored"] = maxi(int(tap.get(
		"repeated_ball_tap_contacts_ignored",
		shot.get("repeated_ball_tap_contacts_ignored", 0)
	)), 0)
	tap["ambiguous_cue_contacts_rejected"] = maxi(int(tap.get(
		"ambiguous_cue_contacts_rejected",
		0
	)), 0)
	tap["ambiguous_ball_tap_contacts_rejected"] = maxi(int(tap.get(
		"ambiguous_ball_tap_contacts_rejected",
		0
	)), 0)
	tap["ambiguous_tap_contacts_rejected"] = maxi(int(tap.get(
		"ambiguous_tap_contacts_rejected",
		shot.get("ambiguous_tap_contacts_rejected", (
			int(tap["ambiguous_cue_contacts_rejected"])
			+ int(tap["ambiguous_ball_tap_contacts_rejected"])
		))
	)), 0)
	tap["tap_direct_pot_disqualifications"] = maxi(int(tap.get(
		"tap_direct_pot_disqualifications",
		shot.get("tap_direct_pot_disqualifications", 0)
	)), 0)
	tap["cue_recontact_score_supplied"] = maxi(int(tap.get(
		"cue_recontact_score_supplied",
		shot.get("cue_recontact_score_supplied", 0)
	)), 0)
	tap["double_tap_score_supplied"] = int(tap["cue_recontact_score_supplied"])
	tap["ball_tap_score_supplied"] = maxi(int(tap.get(
		"ball_tap_score_supplied",
		shot.get("ball_tap_score_supplied", 0)
	)), 0)
	tap["has_double_tap"] = bool(tap.get("has_double_tap", cue_milestones > 0))
	tap["has_triple_tap_or_higher"] = bool(tap.get(
		"has_triple_tap_or_higher",
		int(tap["maximum_cue_strikes_against_one_scoring_ball"]) >= 3
	))
	return tap


static func _shots_with_ball_tap(shots: Array[Dictionary]) -> int:
	var count: int = 0
	for shot in shots:
		if int(_tap_metrics_for_shot(shot).get("ball_tap_milestones", 0)) > 0:
			count += 1
	return count


static func _tap_watch_shot_evidence(shot: Dictionary, evidence: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"shot_id": int(shot.get("shot_id", -1)),
		"attempt_id": int(shot.get("attempt_id", -1)),
		"round_number": maxi(int(shot.get("round_number", 1)), 1),
	}
	for key_value in evidence.keys():
		result[str(key_value)] = evidence[key_value]
	return result


static func _shot_activations(shot: Dictionary) -> Array[Dictionary]:
	return _dictionary_array_alias(shot, ["item_activations", "modifier_activations"])


static func _shot_owned_item_ids(shot: Dictionary) -> Array[String]:
	for key in ["owned_item_ids", "build_item_ids", "build"]:
		if shot.has(key):
			return _normalize_item_ids(shot[key])
	var build_snapshot: Dictionary = _dictionary_value(shot, "build_snapshot")
	if not build_snapshot.is_empty():
		return _normalize_item_ids(build_snapshot.get(
			"item_ids_by_slot",
			build_snapshot.get("slots", [])
		))
	return []


static func _shot_item_metadata(shot: Dictionary, item_id: String) -> Dictionary:
	for activation in _shot_activations(shot):
		if _item_id(activation) == item_id:
			return _item_metadata(activation)
	var build_snapshot: Dictionary = _dictionary_value(shot, "build_snapshot")
	var definitions_value: Variant = build_snapshot.get("item_definitions_by_slot", [])
	var slots_value: Variant = build_snapshot.get("slots", [])
	if definitions_value is Array:
		for definition_index in range((definitions_value as Array).size()):
			var definition_value: Variant = (definitions_value as Array)[definition_index]
			if definition_value is Dictionary and _item_id(
				definition_value as Dictionary
			) == item_id:
				var metadata: Dictionary = _item_metadata(definition_value as Dictionary)
				if slots_value is Array and definition_index < (slots_value as Array).size():
					var slot_value: Variant = (slots_value as Array)[definition_index]
					if slot_value is Dictionary:
						metadata["owned_item_instance_id"] = int(
							(slot_value as Dictionary).get("owned_item_instance_id", -1)
						)
						metadata["acquired_round"] = int(
							(slot_value as Dictionary).get("acquired_round", 0)
						)
				return metadata
	if slots_value is Array:
		for slot_value in slots_value as Array:
			if not slot_value is Dictionary:
				continue
			var slot: Dictionary = slot_value as Dictionary
			var definition: Dictionary = _dictionary_value(slot, "definition")
			if _item_id(definition) == item_id:
				var metadata: Dictionary = _item_metadata(definition)
				metadata["owned_item_instance_id"] = int(slot.get(
					"owned_item_instance_id",
					-1
				))
				metadata["acquired_round"] = int(slot.get("acquired_round", 0))
				return metadata
	return _item_fallback_metadata(item_id)


static func _item_fallback_metadata(item_id: String) -> Dictionary:
	var family_id: String = ""
	if item_id.begins_with("direct_pot_"):
		family_id = FAMILY_DIRECT_POT
	elif item_id.begins_with("multi_pot_"):
		family_id = FAMILY_MULTI_POT
	elif item_id.begins_with("same_pocket_"):
		family_id = FAMILY_SAME_POCKET
	elif item_id.begins_with("double_tap_"):
		family_id = FAMILY_DOUBLE_TAP
	elif item_id.begins_with("ball_tap_"):
		family_id = FAMILY_BALL_TAP
	elif [RATTLE_ITEM_ID, ONE_TWO_PUNCH_ITEM_ID, AFTERSHOCK_ITEM_ID, ECHO_CHAMBER_ITEM_ID].has(
		item_id
	):
		family_id = FAMILY_TAP_ODDITY
	if family_id.is_empty():
		return {}
	var phase: String = ""
	if item_id.contains("_haul_"):
		phase = PHASE_ADD_HAUL
	elif item_id.contains("_mult_") and not item_id.contains("_xmult_"):
		phase = PHASE_ADD_MULT
	elif item_id.contains("_xmult_"):
		phase = PHASE_XMULT
	var display_names: Dictionary = {
		"direct_pot_haul_clean_plunder": "Clean Plunder",
		"direct_pot_mult_true_bearing": "True Bearing",
		"direct_pot_xmult_unerring_course": "Unerring Course",
		DEAD_RECKONING_ITEM_ID: "Dead Reckoning",
		"multi_pot_haul_loaded_hold": "Loaded Hold",
		"multi_pot_mult_all_hands": "All Hands",
		"multi_pot_xmult_broadside_dividend": "Broadside Dividend",
		"same_pocket_haul_shared_grave": "Shared Grave",
		"same_pocket_mult_feeding_frenzy": "Feeding Frenzy",
		"same_pocket_xmult_the_maw_below": "The Maw Below",
		"double_tap_haul_second_bite": "Second Bite",
		"double_tap_mult_echoing_toll": "Echoing Toll",
		"double_tap_xmult_revenant_rhythm": "Revenant Rhythm",
		"ball_tap_haul_knock_on_plunder": "Knock-On Plunder",
		"ball_tap_mult_crowded_wake": "Crowded Wake",
		"ball_tap_xmult_carom_current": "Carom Current",
		RATTLE_ITEM_ID: "Rattle of the Deep",
		ONE_TWO_PUNCH_ITEM_ID: "One-Two Punch",
		AFTERSHOCK_ITEM_ID: "Aftershock",
		ECHO_CHAMBER_ITEM_ID: "Echo Chamber",
	}
	return {
		"eight_ball_item_id": item_id,
		"display_name": str(display_names.get(item_id, item_id)),
		"family_id": family_id,
		"modifier_phase": phase,
	}


static func _shot_trigger_counts(shot: Dictionary) -> Dictionary:
	var counts: Dictionary = _dictionary_alias(shot, ["trigger_counts", "trigger_count_by_id"])
	if not counts.is_empty():
		return counts
	for occurrence in _dictionary_array_alias(shot, ["trigger_occurrences", "occurrences"]):
		_increment_dictionary_count(counts, str(occurrence.get("trigger_id", "")))
	return counts


static func _normalize_offer_items(screen: Dictionary) -> Array[Dictionary]:
	var values: Variant = screen.get("offered_items", screen.get("offers", []))
	var items: Array[Dictionary] = []
	if values is Array:
		for value in values as Array:
			if value is Dictionary:
				items.append((value as Dictionary).duplicate(true))
			else:
				items.append({"eight_ball_item_id": str(value)})
	if not items.is_empty():
		return items
	for item_id in _normalize_item_ids(screen.get("offered_item_ids", [])):
		var metadata: Dictionary = _offer_metadata_for_id(screen, item_id)
		metadata["eight_ball_item_id"] = item_id
		items.append(metadata)
	return items


static func _offer_metadata_for_id(screen: Dictionary, item_id: String) -> Dictionary:
	var metadata_map: Dictionary = _dictionary_value(screen, "item_metadata_by_id")
	var value: Variant = metadata_map.get(item_id, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _eligible_pool_size(screen: Dictionary) -> int:
	if screen.has("unowned_eligible_pool_size"):
		return maxi(int(screen.get("unowned_eligible_pool_size", 0)), 0)
	var pool_value: Variant = screen.get("eligible_pool", screen.get("eligible_item_ids", []))
	return (pool_value as Array).size() if pool_value is Array else 0


static func _selection_rates(selections: Dictionary, offers: Dictionary) -> Dictionary:
	var rates: Dictionary = {}
	for id_value in offers.keys():
		var id: String = str(id_value)
		rates[id] = _safe_ratio(
			float(selections.get(id, 0)),
			float(offers[id_value])
		)
	return rates


static func _make_offer_breakdown(
	offers: Dictionary,
	selections: Dictionary,
	rates: Dictionary,
	metadata_by_id: Dictionary = {}
) -> Dictionary:
	var rows: Dictionary = {}
	for id_value in offers.keys():
		var id: String = str(id_value)
		var metadata: Dictionary = _dictionary_value(metadata_by_id, id)
		rows[id] = {
			"id": id,
			"display_name": str(metadata.get("display_name", id.capitalize())),
			"offer_count": int(offers.get(id_value, 0)),
			"selection_count": int(selections.get(id, 0)),
			"selection_rate": float(rates.get(id, 0.0)),
		}
	return rows


static func _find_item_slot(tray_value: Variant, item_id: String) -> int:
	var tray_ids: Array[String] = _normalize_build_item_ids(tray_value)
	for slot_index in range(tray_ids.size()):
		if tray_ids[slot_index] == item_id:
			return slot_index
	return -1


static func _averages_by_key(values_by_key: Dictionary) -> Dictionary:
	var averages: Dictionary = {}
	for key_value in values_by_key.keys():
		var values_value: Variant = values_by_key[key_value]
		if not values_value is Array:
			continue
		var values: Array = values_value
		var total: float = 0.0
		for value in values:
			total += float(value)
		averages[str(key_value)] = _safe_ratio(total, float(values.size()))
	return averages


static func _append_number(values_by_key: Dictionary, key: String, value: float) -> void:
	if not values_by_key.has(key):
		values_by_key[key] = []
	(values_by_key[key] as Array).append(value)


static func _shares(values: Dictionary, total: float) -> Dictionary:
	var result: Dictionary = {}
	for key_value in values.keys():
		result[str(key_value)] = _safe_ratio(float(values[key_value]), total)
	return result


static func _item_metadata(source: Dictionary) -> Dictionary:
	return {
		"eight_ball_item_id": _item_id(source),
		"display_name": str(source.get("display_name", _item_id(source))),
		"family_id": _family_id(source),
		"offer_family": str(source.get("offer_family", "")),
		"modifier_phase": str(source.get("modifier_phase", source.get("phase", ""))),
		"rarity": str(source.get("rarity", "")),
		"offer_weight": int(source.get("offer_weight", 0)),
		"effect_kind": str(source.get("effect_kind", "")),
		"owned_item_instance_id": int(source.get("owned_item_instance_id", -1)),
		"retrigger_family": str(source.get(
			"retrigger_family",
			source.get("retrigger_family_id", "")
		)),
	}


static func _item_id(source: Dictionary) -> String:
	return str(source.get(
		"eight_ball_item_id",
		source.get("item_id", source.get("modifier_id", source.get("id", "")))
	))


static func _family_id(source: Dictionary) -> String:
	var family: String = str(source.get("family_id", ""))
	if not family.is_empty():
		return family
	return _family_from_trigger(str(source.get("trigger_id", "")))


static func _family_from_trigger(trigger_id: String) -> String:
	match trigger_id:
		TRIGGER_SINGLE_BANK:
			return FAMILY_SINGLE_BANK
		TRIGGER_DOUBLE_BANK:
			return FAMILY_DOUBLE_BANK
		TRIGGER_TRIPLE_BANK:
			return FAMILY_TRIPLE_BANK
		TRIGGER_COMBINATION:
			return FAMILY_COMBINATION
		TRIGGER_DIRECT_POT:
			return FAMILY_DIRECT_POT
		TRIGGER_MULTI_POT:
			return FAMILY_MULTI_POT
		TRIGGER_SAME_POCKET:
			return FAMILY_SAME_POCKET
		TRIGGER_CUE_RECONTACT:
			return FAMILY_CUE_RECONTACT
		TRIGGER_OBJECT_BALL_TAP:
			return FAMILY_BALL_TAP
		_:
			return FAMILY_UNKNOWN


static func _normalize_item_ids(value: Variant) -> Array[String]:
	var ids: Array[String] = []
	if not value is Array:
		return ids
	for entry_value in value as Array:
		var item_id: String = ""
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			if bool(entry.get("occupied", true)):
				item_id = _item_id(entry)
				if item_id.is_empty():
					var definition: Dictionary = _dictionary_value(entry, "definition")
					item_id = _item_id(definition)
		else:
			item_id = str(entry_value) if entry_value != null else ""
		if not item_id.is_empty() and not ids.has(item_id):
			ids.append(item_id)
	return ids


static func _normalize_build_item_ids(value: Variant) -> Array[String]:
	if value is Dictionary:
		var build_snapshot: Dictionary = value as Dictionary
		return _normalize_item_ids(build_snapshot.get(
			"item_ids_by_slot",
			build_snapshot.get("slots", [])
		))
	return _normalize_item_ids(value)


static func _shot_score(shot: Dictionary) -> int:
	return maxi(int(shot.get("final_score", shot.get("shot_score", 0))), 0)


static func _base_score(shot: Dictionary) -> int:
	return maxi(int(shot.get("base_score_without_build", 0)), 0)


static func _shot_doubloon_payout(shot: Dictionary) -> int:
	if shot.has("doubloons_earned_from_base_haul"):
		return maxi(int(shot.get("doubloons_earned_from_base_haul", 0)), 0)
	if shot.has("doubloons_from_base_haul"):
		return maxi(int(shot.get("doubloons_from_base_haul", 0)), 0)
	var payout: Dictionary = _dictionary_value(shot, "doubloon_payout")
	if not payout.is_empty():
		return maxi(int(payout.get("doubloons_awarded", 0)), 0)
	return maxi(int(floor(float(maxi(int(shot.get("base_haul", 0)), 0)) / 10.0)), 0)


static func _sum_shot_scores(shots: Array[Dictionary]) -> int:
	var total: int = 0
	for shot in shots:
		total += _shot_score(shot)
	return total


static func _sum_build_uplift(shots: Array[Dictionary]) -> int:
	var total: int = 0
	for shot in shots:
		total += _shot_score(shot) - _base_score(shot)
	return total


static func _highest_shot(shots: Array[Dictionary]) -> int:
	var highest: int = 0
	for shot in shots:
		highest = maxi(highest, _shot_score(shot))
	return highest


static func _zero_score_shot_count(shots: Array[Dictionary]) -> int:
	var count: int = 0
	for shot in shots:
		if _shot_score(shot) == 0:
			count += 1
	return count


static func _sum_trigger_counts(shots: Array[Dictionary]) -> Dictionary:
	var total: Dictionary = {}
	for shot in shots:
		var counts: Dictionary = _shot_trigger_counts(shot)
		for trigger_id_value in counts.keys():
			var trigger_id: String = str(trigger_id_value)
			total[trigger_id] = int(total.get(trigger_id, 0)) + int(counts[trigger_id_value])
	return total


static func _median(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[int] = values.duplicate()
	sorted_values.sort()
	var midpoint: int = int(sorted_values.size() / 2)
	if sorted_values.size() % 2 == 1:
		return float(sorted_values[midpoint])
	return (float(sorted_values[midpoint - 1]) + float(sorted_values[midpoint])) * 0.5


static func _select_item_extreme(
	items: Array[Dictionary],
	field_name: String,
	maximum: bool
) -> Dictionary:
	var selected: Dictionary = {}
	for item in items:
		if selected.is_empty():
			selected = item
			continue
		var value: float = float(item.get(field_name, 0.0))
		var selected_value: float = float(selected.get(field_name, 0.0))
		if (maximum and value > selected_value) or (not maximum and value < selected_value):
			selected = item
		elif is_equal_approx(value, selected_value) and _item_id(item) < _item_id(selected):
			selected = item
	return selected.duplicate(true)


static func _least_triggered_owned_item(items: Array[Dictionary]) -> Dictionary:
	var owned: Array[Dictionary] = []
	for item in items:
		if int(item.get("shots_owned", 0)) > 0 or int(item.get("rounds_owned", 0)) > 0:
			owned.append(item)
	return _select_item_extreme(owned, "trigger_occurrences", false)


static func _safe_ratio(numerator: float, denominator: float) -> float:
	return numerator / denominator if absf(denominator) > 0.000001 else 0.0


static func _shot_key(shot: Dictionary) -> String:
	return "%d|%d" % [int(shot.get("shot_id", -1)), int(shot.get("attempt_id", -1))]


static func _shot_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_round: int = int(left.get("round_number", 0))
	var right_round: int = int(right.get("round_number", 0))
	if left_round != right_round:
		return left_round < right_round
	var left_shot: int = int(left.get("shot_id", -1))
	var right_shot: int = int(right.get("shot_id", -1))
	if left_shot != right_shot:
		return left_shot < right_shot
	return int(left.get("attempt_id", -1)) < int(right.get("attempt_id", -1))


static func _item_metric_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_uplift: int = int(left.get("final_score_uplift", 0))
	var right_uplift: int = int(right.get("final_score_uplift", 0))
	if left_uplift != right_uplift:
		return left_uplift > right_uplift
	return _item_id(left) < _item_id(right)


static func _watch_flag_precedes(left: Dictionary, right: Dictionary) -> bool:
	return str(left.get("id", "")) < str(right.get("id", ""))


static func _increment_dictionary_count(counts: Dictionary, key: String, amount: int = 1) -> void:
	if key.is_empty():
		return
	counts[key] = int(counts.get(key, 0)) + amount


static func _dictionary_array_alias(source: Dictionary, keys: Array[String]) -> Array[Dictionary]:
	for key in keys:
		if source.has(key):
			return _dictionary_array_value(source, key)
	return []


static func _dictionary_array_value(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = source.get(key, [])
	if value is Array:
		for entry_value in value as Array:
			if entry_value is Dictionary:
				result.append((entry_value as Dictionary).duplicate(true))
	return result


static func _dictionary_alias(source: Dictionary, keys: Array[String]) -> Dictionary:
	for key in keys:
		var value: Variant = source.get(key, null)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


static func _dictionary_value(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for entry in value as Array:
			result.append(int(entry))
	return result


static func _contains_object_reference(value: Variant, depth: int = 0) -> bool:
	if depth > 16:
		return true
	if typeof(value) == TYPE_OBJECT and value != null:
		return true
	if value is Dictionary:
		for key_value in (value as Dictionary).keys():
			if _contains_object_reference(key_value, depth + 1):
				return true
			if _contains_object_reference((value as Dictionary)[key_value], depth + 1):
				return true
	elif value is Array:
		for entry_value in value as Array:
			if _contains_object_reference(entry_value, depth + 1):
				return true
	return false
