extends SceneTree

# Standalone pure regression harness for Phase 5A balance aggregation.
# Run with:
# godot4 --headless --path <project> --script res://scripts/RogueliteBalanceAnalyzerTests.gd

const ANALYZER := preload("res://scripts/RogueliteBalanceAnalyzer.gd")
const TELEMETRY := preload("res://scripts/RogueliteBalanceTelemetry.gd")
const TEST_CASE_COUNT := 44

const SINGLE_TRIGGER := "single_bank_milestone"
const DOUBLE_TRIGGER := "double_bank_milestone"
const TRIPLE_TRIGGER := "triple_bank_milestone"
const COMBINATION_TRIGGER := "combination_pot"
const DIRECT_TRIGGER := "direct_pot"
const MULTI_TRIGGER := "multi_pot_shot"
const SAME_POCKET_TRIGGER := "same_pocket_streak"
const CUE_RECONTACT_TRIGGER := "cue_recontact_milestone"
const BALL_TAP_TRIGGER := "object_ball_tap_milestone"
const DEAD_RECKONING_ID := "direct_pot_legendary_dead_reckoning"
const RATTLE_ID := "tap_stateful_xmult_rattle_of_the_deep"
const ONE_TWO_PUNCH_ID := "tap_hybrid_xmult_one_two_punch"
const AFTERSHOCK_ID := "tap_ordinal_xmult_aftershock"
const ECHO_CHAMBER_ID := "tap_legendary_retrigger_echo_chamber"
const SECOND_BITE_ID := "double_tap_haul_second_bite"
const ECHOING_TOLL_ID := "double_tap_mult_echoing_toll"
const KNOCK_ON_PLUNDER_ID := "ball_tap_haul_knock_on_plunder"
const CROWDED_WAKE_ID := "ball_tap_mult_crowded_wake"


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var report: Dictionary = run_all()
	print(_format_report(report))
	quit(0 if int(report.get("failed", 0)) == 0 else 1)


static func run_all() -> Dictionary:
	var cases: Array[Dictionary] = []
	_test_empty_build(cases)
	_test_add_haul_attribution(cases)
	_test_add_mult_attribution(cases)
	_test_xmult_marginal_attribution(cases)
	_test_interaction_surplus(cases)
	_test_cumulative_bank_aggregation(cases)
	_test_two_scoring_ball_occurrences(cases)
	_test_offer_selection_aggregation(cases)
	_test_replacement_lifecycle(cases)
	_test_round_finalization_once(cases)
	_test_rewind_removes_one_shot(cases)
	_test_replay_adds_fresh_shot(cases)
	_test_median_and_highest(cases)
	_test_largest_shot_concentration(cases)
	_test_single_bank_dominance_watch(cases)
	_test_dead_item_watch(cases)
	_test_build_identity(cases)
	_test_fresh_run_clearing(cases)
	_test_passage_excluded(cases)
	_test_shot_lab_isolation(cases)
	_test_phase_5b_trigger_families(cases)
	_test_phase_5b_item_metrics(cases)
	_test_direct_pot_identity(cases)
	_test_multi_pot_identity(cases)
	_test_same_pocket_identity(cases)
	_test_phase_5b_hybrid_identity(cases)
	_test_dead_reckoning_supported_metrics(cases)
	_test_dead_reckoning_dead_support_metrics(cases)
	_test_telemetry_preserves_retrigger_evidence(cases)
	_test_tap_run_aggregation(cases)
	_test_tap_frequency_comparison(cases)
	_test_tap_exploit_watch(cases)
	_test_contact_farm_watch(cases)
	_test_telemetry_preserves_tap_evidence(cases)
	_test_tap_rewind_restores_accumulators(cases)
	_test_phase_5c_telemetry_preserves_state(cases)
	_test_phase_5c_rattle_aggregation(cases)
	_test_phase_5c_one_two_punch_aggregation(cases)
	_test_phase_5c_aftershock_aggregation(cases)
	_test_phase_5c_echo_attribution(cases)
	_test_phase_5c_echo_support_rounds(cases)
	_test_phase_5c_build_identities(cases)
	_test_phase_5c_state_history_is_bounded(cases)
	_test_phase_5c_rewind_restores_accumulator(cases)
	return _build_report(cases)


static func run_self_tests() -> Dictionary:
	return run_all()


static func _test_empty_build(cases: Array[Dictionary]) -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [_shot(10, 10)]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var summary: Dictionary = _dict(report, "run_summary")
	_record_case(
		cases,
		"1. Empty build produces zero uplift",
		int(summary.get("total_build_uplift", -1)) == 0
			and _items(report).is_empty(),
		{"total_build_uplift": 0, "item_count": 0},
		{
			"total_build_uplift": summary.get("total_build_uplift"),
			"item_count": _items(report).size(),
		}
	)


static func _test_add_haul_attribution(cases: Array[Dictionary]) -> void:
	var item_id: String = "test_add_haul"
	var activation: Dictionary = _activation(
		item_id,
		"Test Haul",
		"single_bank",
		"add_haul",
		10,
		SINGLE_TRIGGER
	)
	var shot: Dictionary = _shot(20, 10, 1, 1, 1, [activation], {}, [item_id])
	shot["score_without_item_by_id"] = _counterfactual_scores([item_id], [10])
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [shot]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var item: Dictionary = _item(report, item_id)
	_record_case(
		cases,
		"2. +Haul item attribution",
		is_equal_approx(float(item.get("total_haul_added", -1.0)), 10.0)
			and int(item.get("final_score_uplift", -1)) == 10,
		{"total_haul_added": 10.0, "final_score_uplift": 10},
		_item_summary(item)
	)


static func _test_add_mult_attribution(cases: Array[Dictionary]) -> void:
	var item_id: String = "test_add_mult"
	var activation: Dictionary = _activation(
		item_id,
		"Test Mult",
		"single_bank",
		"add_mult",
		2.0,
		SINGLE_TRIGGER
	)
	var shot: Dictionary = _shot(30, 10, 1, 1, 1, [activation], {}, [item_id])
	shot["score_without_item_by_id"] = _counterfactual_scores([item_id], [10])
	shot["final_mult"] = 3.0
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [shot]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var item: Dictionary = _item(report, item_id)
	_record_case(
		cases,
		"3. +Mult item attribution",
		is_equal_approx(float(item.get("total_mult_added", -1.0)), 2.0)
			and int(item.get("final_score_uplift", -1)) == 20,
		{"total_mult_added": 2.0, "final_score_uplift": 20},
		_item_summary(item)
	)


static func _test_xmult_marginal_attribution(cases: Array[Dictionary]) -> void:
	var item_id: String = "test_xmult"
	var activation: Dictionary = _activation(
		item_id,
		"Test xMult",
		"triple_bank",
		"xmult",
		2.0,
		TRIPLE_TRIGGER
	)
	var shot: Dictionary = _shot(20, 10, 1, 1, 1, [activation], {}, [item_id])
	shot["score_without_item_by_id"] = _counterfactual_scores([item_id], [10])
	shot["build_xmult_product"] = 2.0
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [shot]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var item: Dictionary = _item(report, item_id)
	_record_case(
		cases,
		"4. xMult marginal attribution",
		is_equal_approx(float(item.get("cumulative_xmult_factor", -1.0)), 2.0)
			and int(item.get("final_score_uplift", -1)) == 10,
		{"cumulative_xmult_factor": 2.0, "final_score_uplift": 10},
		_item_summary(item)
	)


static func _test_interaction_surplus(cases: Array[Dictionary]) -> void:
	var item_a: String = "interaction_a"
	var item_b: String = "interaction_b"
	var activations: Array[Dictionary] = [
		_activation(item_a, "A", "single_bank", "add_haul", 10, SINGLE_TRIGGER),
		_activation(item_b, "B", "combination", "xmult", 2.0, COMBINATION_TRIGGER),
	]
	var shot: Dictionary = _shot(40, 10, 1, 1, 1, activations, {}, [item_a, item_b])
	shot["score_without_item_by_id"] = _counterfactual_scores([item_a, item_b], [20, 20])
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [shot]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var attribution: Dictionary = _dict(report, "attribution")
	_record_case(
		cases,
		"5. Interaction surplus reported",
		int(attribution.get("total_build_uplift", -1)) == 30
			and int(attribution.get("total_item_marginal_uplift", -1)) == 40
			and int(attribution.get("interaction_surplus", 999)) == -10,
		{
			"total_build_uplift": 30,
			"total_item_marginal_uplift": 40,
			"interaction_surplus": -10,
		},
		attribution
	)


static func _test_cumulative_bank_aggregation(cases: Array[Dictionary]) -> void:
	var shot: Dictionary = _shot(40, 40)
	shot["trigger_counts"] = {
		SINGLE_TRIGGER: 1,
		DOUBLE_TRIGGER: 1,
		TRIPLE_TRIGGER: 1,
	}
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [shot]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var trigger_metrics: Dictionary = _dict(report, "trigger_metrics")
	var families: Dictionary = _dict(trigger_metrics, "families")
	_record_case(
		cases,
		"6. Cumulative Bank trigger aggregation",
		_trigger_occurrences(families, "single_bank") == 1
			and _trigger_occurrences(families, "double_bank") == 1
			and _trigger_occurrences(families, "triple_bank") == 1
			and int(trigger_metrics.get("cumulative_bank_activation_expansion", -1)) == 3,
		{"single": 1, "double": 1, "triple": 1, "expansion": 3},
		{
			"single": _trigger_occurrences(families, "single_bank"),
			"double": _trigger_occurrences(families, "double_bank"),
			"triple": _trigger_occurrences(families, "triple_bank"),
			"expansion": trigger_metrics.get("cumulative_bank_activation_expansion"),
		}
	)


static func _test_two_scoring_ball_occurrences(cases: Array[Dictionary]) -> void:
	var shot: Dictionary = _shot(40, 40)
	shot["object_balls_pocketed"] = 2
	shot["trigger_counts"] = {SINGLE_TRIGGER: 2}
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [shot]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var summary: Dictionary = _dict(report, "run_summary")
	var families: Dictionary = _dict(_dict(report, "trigger_metrics"), "families")
	_record_case(
		cases,
		"7. Two scoring balls count separate occurrences",
		int(summary.get("total_scoring_balls_pocketed", -1)) == 2
			and _trigger_occurrences(families, "single_bank") == 2,
		{"scoring_balls": 2, "single_occurrences": 2},
		{
			"scoring_balls": summary.get("total_scoring_balls_pocketed"),
			"single_occurrences": _trigger_occurrences(families, "single_bank"),
		}
	)


static func _test_offer_selection_aggregation(cases: Array[Dictionary]) -> void:
	var selected_id: String = "offer_single"
	var snapshot: Dictionary = _snapshot()
	snapshot["reward_screens"] = [{
		"round_number": 2,
		"offered_items": [
			_offer_item(selected_id, "single_bank", "add_haul"),
			_offer_item("offer_double", "double_bank", "add_mult"),
			_offer_item("offer_combo", "combination", "xmult"),
		],
		"selected_item_id": selected_id,
		"eligible_pool": [selected_id, "offer_double", "offer_combo", "other"],
		"tray_before": [],
		"tray_after": [selected_id],
	}]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var offers: Dictionary = _dict(report, "offer_metrics")
	var offer_counts: Dictionary = _dict(offers, "offer_count_by_item")
	var selection_counts: Dictionary = _dict(offers, "selection_count_by_item")
	var selection_rates: Dictionary = _dict(offers, "selection_rate_by_item")
	_record_case(
		cases,
		"8. Offer selection aggregation",
		int(offer_counts.get(selected_id, 0)) == 1
			and int(selection_counts.get(selected_id, 0)) == 1
			and is_equal_approx(float(selection_rates.get(selected_id, 0.0)), 1.0),
		{"offered": 1, "selected": 1, "selection_rate": 1.0},
		{
			"offered": offer_counts.get(selected_id),
			"selected": selection_counts.get(selected_id),
			"selection_rate": selection_rates.get(selected_id),
		}
	)


static func _test_replacement_lifecycle(cases: Array[Dictionary]) -> void:
	var old_id: String = "old_item"
	var new_id: String = "new_item"
	var snapshot: Dictionary = _snapshot()
	snapshot["reward_screens"] = [{
		"round_number": 4,
		"offered_items": [_offer_item(new_id, "double_bank", "add_mult")],
		"selected_item_id": new_id,
		"replacement_slot": 1,
		"replaced_item_id": old_id,
		"full_tray": true,
		"tray_before": ["a", old_id, "c", "d", "e"],
		"tray_after": ["a", new_id, "c", "d", "e"],
	}]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var offers: Dictionary = _dict(report, "offer_metrics")
	var new_item: Dictionary = _item(report, new_id)
	var old_item: Dictionary = _item(report, old_id)
	_record_case(
		cases,
		"9. Replacement lifecycle",
		int(offers.get("replacement_count", 0)) == 1
			and int(new_item.get("replacement_count", 0)) == 1
			and int(old_item.get("replaced_count", 0)) == 1
			and int(old_item.get("removed_round", 0)) == 4,
		{"replacements": 1, "new_replacements": 1, "old_replaced": 1, "removed_round": 4},
		{
			"replacements": offers.get("replacement_count"),
			"new_replacements": new_item.get("replacement_count"),
			"old_replaced": old_item.get("replaced_count"),
			"removed_round": old_item.get("removed_round"),
		}
	)


static func _test_round_finalization_once(cases: Array[Dictionary]) -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [_shot(20, 20)]
	snapshot["rounds"] = [
		_round(1, 10, 20),
		_round(1, 10, 20),
	]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var diagnostics: Dictionary = _dict(report, "diagnostics")
	_record_case(
		cases,
		"10. Round finalization exactly once",
		_rounds(report).size() == 1
			and int(diagnostics.get("duplicate_round_records_ignored", 0)) == 1,
		{"round_count": 1, "duplicate_round_records_ignored": 1},
		{
			"round_count": _rounds(report).size(),
			"duplicate_round_records_ignored": diagnostics.get("duplicate_round_records_ignored"),
		}
	)


static func _test_rewind_removes_one_shot(cases: Array[Dictionary]) -> void:
	var retained: Dictionary = _shot(10, 10, 1, 10)
	var rewound: Dictionary = _shot(90, 10, 2, 11)
	rewound["rewound"] = true
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [retained, rewound]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var summary: Dictionary = _dict(report, "run_summary")
	var diagnostics: Dictionary = _dict(report, "diagnostics")
	_record_case(
		cases,
		"11. Rewind removes one shot",
		int(summary.get("total_shots", -1)) == 1
			and int(summary.get("total_authoritative_score", -1)) == 10
			and int(diagnostics.get("rewound_or_discarded_shots_ignored", 0)) == 1,
		{"total_shots": 1, "total_score": 10, "rewound_ignored": 1},
		{
			"total_shots": summary.get("total_shots"),
			"total_score": summary.get("total_authoritative_score"),
			"rewound_ignored": diagnostics.get("rewound_or_discarded_shots_ignored"),
		}
	)


static func _test_replay_adds_fresh_shot(cases: Array[Dictionary]) -> void:
	var old_attempt: Dictionary = _shot(10, 10, 2, 20)
	old_attempt["status"] = "abandoned"
	var replay: Dictionary = _shot(30, 10, 2, 21)
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [old_attempt, replay]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var summary: Dictionary = _dict(report, "run_summary")
	var diagnostics: Dictionary = _dict(report, "diagnostics")
	var accepted_attempts: Array = diagnostics.get("accepted_attempt_ids", []) as Array
	_record_case(
		cases,
		"12. Replay adds one fresh shot",
		int(summary.get("total_shots", -1)) == 1
			and int(summary.get("total_authoritative_score", -1)) == 30
			and accepted_attempts == [21],
		{"total_shots": 1, "total_score": 30, "accepted_attempt_ids": [21]},
		{
			"total_shots": summary.get("total_shots"),
			"total_score": summary.get("total_authoritative_score"),
			"accepted_attempt_ids": accepted_attempts,
		}
	)


static func _test_median_and_highest(cases: Array[Dictionary]) -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [
		_shot(10, 10, 1, 1),
		_shot(40, 40, 2, 2),
		_shot(20, 20, 3, 3),
		_shot(30, 30, 4, 4),
	]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var summary: Dictionary = _dict(report, "run_summary")
	_record_case(
		cases,
		"13. Median and highest-shot calculations",
		is_equal_approx(float(summary.get("median_shot", -1.0)), 25.0)
			and int(summary.get("highest_shot", -1)) == 40,
		{"median_shot": 25.0, "highest_shot": 40},
		{
			"median_shot": summary.get("median_shot"),
			"highest_shot": summary.get("highest_shot"),
		}
	)


static func _test_largest_shot_concentration(cases: Array[Dictionary]) -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [_shot(60, 60, 1, 1), _shot(40, 40, 2, 2)]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var summary: Dictionary = _dict(report, "run_summary")
	var distribution: Dictionary = _dict(report, "shot_distribution")
	_record_case(
		cases,
		"14. Largest-shot concentration",
		is_equal_approx(float(summary.get("largest_shot_percentage", -1.0)), 60.0)
			and is_equal_approx(float(distribution.get("largest_shot_concentration", -1.0)), 0.60),
		{"largest_shot_percentage": 60.0, "concentration": 0.60},
		{
			"largest_shot_percentage": summary.get("largest_shot_percentage"),
			"concentration": distribution.get("largest_shot_concentration"),
		}
	)


static func _test_single_bank_dominance_watch(cases: Array[Dictionary]) -> void:
	var single_id: String = "dominant_single"
	var combo_id: String = "minor_combo"
	var activations: Array[Dictionary] = [
		_activation(single_id, "Single", "single_bank", "add_haul", 10, SINGLE_TRIGGER),
		_activation(combo_id, "Combo", "combination", "add_mult", 1, COMBINATION_TRIGGER),
	]
	var shot: Dictionary = _shot(110, 10, 1, 1, 1, activations, {}, [single_id, combo_id])
	shot["score_without_item_by_id"] = _counterfactual_scores(
		[single_id, combo_id],
		[40, 80]
	)
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [shot]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	_record_case(
		cases,
		"15. Single Bank dominance watch flag",
		_has_watch_flag(report, "single_bank_dominance"),
		{"watch_flag": "single_bank_dominance"},
		{"watch_flags": _watch_ids(report)}
	)


static func _test_dead_item_watch(cases: Array[Dictionary]) -> void:
	var item_id: String = "dead_item"
	var snapshot: Dictionary = _snapshot()
	snapshot["rounds"] = [_round(1, 100, 80), _round(2, 120, 90)]
	snapshot["item_lifecycles"] = [{
		"eight_ball_item_id": item_id,
		"display_name": "Dead Item",
		"family_id": "double_bank",
		"modifier_phase": "add_haul",
		"rounds_owned": 2,
		"shots_owned": 6,
	}]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	_record_case(
		cases,
		"16. Dead-item watch flag",
		_has_watch_flag(report, "dead_item")
			and int(_item(report, item_id).get("rounds_owned", 0)) == 2,
		{"watch_flag": "dead_item", "rounds_owned": 2},
		{
			"watch_flags": _watch_ids(report),
			"rounds_owned": _item(report, item_id).get("rounds_owned"),
		}
	)


static func _test_build_identity(cases: Array[Dictionary]) -> void:
	var item_id: String = "single_identity"
	var activation: Dictionary = _activation(
		item_id,
		"Single Identity",
		"single_bank",
		"add_haul",
		50,
		SINGLE_TRIGGER
	)
	var shot: Dictionary = _shot(60, 10, 1, 1, 1, [activation], {}, [item_id])
	shot["score_without_item_by_id"] = _counterfactual_scores([item_id], [10])
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = [shot]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var identity: Dictionary = _dict(report, "build_identity")
	_record_case(
		cases,
		"17. Build identity classification",
		str(identity.get("label", "")) == "Single Bank Engine"
			and str(identity.get("reason", "")).contains("100.0%"),
		{"label": "Single Bank Engine", "reason_contains": "100.0%"},
		identity
	)


static func _test_fresh_run_clearing(cases: Array[Dictionary]) -> void:
	var item_id: String = "old_run_item"
	var populated: Dictionary = _snapshot()
	var activation: Dictionary = _activation(
		item_id,
		"Old Run",
		"single_bank",
		"add_haul",
		10,
		SINGLE_TRIGGER
	)
	var populated_shot: Dictionary = _shot(20, 10, 1, 1, 1, [activation], {}, [item_id])
	populated_shot["score_without_item_by_id"] = _counterfactual_scores([item_id], [10])
	populated["shots"] = [populated_shot]
	var first_report: Dictionary = ANALYZER.analyze(populated)
	var fresh: Dictionary = _snapshot()
	fresh["run_generation"] = 2
	var fresh_report: Dictionary = ANALYZER.analyze(fresh)
	var fresh_summary: Dictionary = _dict(fresh_report, "run_summary")
	_record_case(
		cases,
		"18. Fresh run clearing",
		not _items(first_report).is_empty()
			and _items(fresh_report).is_empty()
			and int(fresh_summary.get("total_shots", -1)) == 0
			and int(fresh_summary.get("total_authoritative_score", -1)) == 0,
		{"first_item_count": 1, "fresh_item_count": 0, "fresh_shots": 0, "fresh_score": 0},
		{
			"first_item_count": _items(first_report).size(),
			"fresh_item_count": _items(fresh_report).size(),
			"fresh_shots": fresh_summary.get("total_shots"),
			"fresh_score": fresh_summary.get("total_authoritative_score"),
		}
	)


static func _test_passage_excluded(cases: Array[Dictionary]) -> void:
	var snapshot: Dictionary = _snapshot("passage")
	snapshot["shots"] = [_shot(100, 10)]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	_record_case(
		cases,
		"19. Passage excluded",
		bool(report.get("excluded", false))
			and str(report.get("exclusion_reason", "")) == "passage_excluded"
			and int(_dict(report, "run_summary").get("total_shots", -1)) == 0,
		{"excluded": true, "reason": "passage_excluded", "total_shots": 0},
		{
			"excluded": report.get("excluded"),
			"reason": report.get("exclusion_reason"),
			"total_shots": _dict(report, "run_summary").get("total_shots"),
		}
	)


static func _test_shot_lab_isolation(cases: Array[Dictionary]) -> void:
	var disabled_snapshot: Dictionary = _snapshot("shot_lab")
	disabled_snapshot["shots"] = [_shot(30, 10)]
	var disabled_report: Dictionary = ANALYZER.analyze(disabled_snapshot)
	var enabled_snapshot: Dictionary = disabled_snapshot.duplicate(true)
	enabled_snapshot["include_shot_lab_telemetry"] = true
	var enabled_report: Dictionary = ANALYZER.analyze(enabled_snapshot)
	_record_case(
		cases,
		"20. Shot Lab isolated unless telemetry debug toggle is enabled",
		bool(disabled_report.get("excluded", false))
			and str(disabled_report.get("exclusion_reason", "")) == "shot_lab_telemetry_disabled"
			and not bool(enabled_report.get("excluded", true))
			and int(_dict(enabled_report, "run_summary").get("total_shots", 0)) == 1,
		{"disabled_excluded": true, "enabled_shots": 1},
		{
			"disabled_excluded": disabled_report.get("excluded"),
			"disabled_reason": disabled_report.get("exclusion_reason"),
			"enabled_excluded": enabled_report.get("excluded"),
			"enabled_shots": _dict(enabled_report, "run_summary").get("total_shots"),
		}
	)


static func _test_phase_5b_trigger_families(cases: Array[Dictionary]) -> void:
	var direct: Dictionary = _activation(
		"direct_pot_haul_clean_plunder",
		"Clean Plunder",
		"direct_pot",
		"add_haul",
		10,
		DIRECT_TRIGGER
	)
	var multi: Dictionary = _activation(
		"multi_pot_haul_loaded_hold",
		"Loaded Hold",
		"multi_pot",
		"add_haul",
		20,
		MULTI_TRIGGER
	)
	var same: Dictionary = _activation(
		"same_pocket_haul_shared_grave",
		"Shared Grave",
		"same_pocket",
		"add_haul",
		25,
		SAME_POCKET_TRIGGER
	)
	var shot: Dictionary = _shot(
		100,
		40,
		1,
		1,
		1,
		[direct, multi, same],
		{DIRECT_TRIGGER: 2, MULTI_TRIGGER: 1, SAME_POCKET_TRIGGER: 2},
		[
			"direct_pot_haul_clean_plunder",
			"multi_pot_haul_loaded_hold",
			"same_pocket_haul_shared_grave",
		]
	)
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([shot]))
	var families: Dictionary = _dict(_dict(report, "trigger_metrics"), "families")
	_record_case(
		cases,
		"21. Phase 5B trigger families aggregate independently",
		_trigger_occurrences(families, "direct_pot") == 2
			and _trigger_occurrences(families, "multi_pot") == 1
			and _trigger_occurrences(families, "same_pocket") == 2
			and int(_dict(families, "direct_pot").get("owned_item_activations", 0)) == 1
			and int(_dict(families, "multi_pot").get("owned_item_activations", 0)) == 1
			and int(_dict(families, "same_pocket").get("owned_item_activations", 0)) == 1,
		{"direct_pot": 2, "multi_pot": 1, "same_pocket": 2, "activations_each": 1},
		{
			"direct_pot": _dict(families, "direct_pot"),
			"multi_pot": _dict(families, "multi_pot"),
			"same_pocket": _dict(families, "same_pocket"),
		}
	)


static func _test_phase_5b_item_metrics(cases: Array[Dictionary]) -> void:
	var definitions: Array[Dictionary] = _phase_5b_definitions()
	var snapshot: Dictionary = _snapshot()
	snapshot["reward_screens"] = [{
		"round_number": 1,
		"offered_items": definitions,
		"offered_item_ids": _definition_ids(definitions),
		"eligible_pool_size": definitions.size(),
	}]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var found_ids: Array[String] = []
	var family_counts: Dictionary = {}
	for item in _items(report):
		var item_id: String = str(item.get("eight_ball_item_id", ""))
		if _definition_ids(definitions).has(item_id):
			found_ids.append(item_id)
			var family_id: String = str(item.get("family_id", ""))
			family_counts[family_id] = int(family_counts.get(family_id, 0)) + 1
	_record_case(
		cases,
		"22. All ten Phase 5B items receive contribution rows",
		found_ids.size() == 10
			and int(family_counts.get("direct_pot", 0)) == 4
			and int(family_counts.get("multi_pot", 0)) == 3
			and int(family_counts.get("same_pocket", 0)) == 3,
		{"item_count": 10, "direct_pot": 4, "multi_pot": 3, "same_pocket": 3},
		{"item_count": found_ids.size(), "families": family_counts}
	)


static func _test_direct_pot_identity(cases: Array[Dictionary]) -> void:
	_test_family_identity(
		cases,
		"23. Direct Pot build identity",
		"direct_pot_haul_clean_plunder",
		"Clean Plunder",
		"direct_pot",
		DIRECT_TRIGGER,
		"Direct Pot Engine"
	)


static func _test_multi_pot_identity(cases: Array[Dictionary]) -> void:
	_test_family_identity(
		cases,
		"24. Multi-Pot build identity",
		"multi_pot_haul_loaded_hold",
		"Loaded Hold",
		"multi_pot",
		MULTI_TRIGGER,
		"Multi-Pot Engine"
	)


static func _test_same_pocket_identity(cases: Array[Dictionary]) -> void:
	_test_family_identity(
		cases,
		"25. Same-Pocket build identity",
		"same_pocket_haul_shared_grave",
		"Shared Grave",
		"same_pocket",
		SAME_POCKET_TRIGGER,
		"Same-Pocket Engine"
	)


static func _test_family_identity(
	cases: Array[Dictionary],
	case_name: String,
	item_id: String,
	display_name: String,
	family_id: String,
	trigger_id: String,
	expected_label: String
) -> void:
	var activation: Dictionary = _activation(
		item_id,
		display_name,
		family_id,
		"add_haul",
		10,
		trigger_id
	)
	var shot: Dictionary = _shot(20, 10, 1, 1, 1, [activation], {trigger_id: 1}, [item_id])
	shot["score_without_item_by_id"] = _counterfactual_scores([item_id], [10])
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([shot]))
	var identity: Dictionary = _dict(report, "build_identity")
	_record_case(
		cases,
		case_name,
		str(identity.get("label", "")) == expected_label,
		{"label": expected_label},
		identity
	)


static func _test_phase_5b_hybrid_identity(cases: Array[Dictionary]) -> void:
	var direct_id: String = "direct_pot_haul_clean_plunder"
	var multi_id: String = "multi_pot_haul_loaded_hold"
	var activations: Array[Dictionary] = [
		_activation(direct_id, "Clean Plunder", "direct_pot", "add_haul", 10, DIRECT_TRIGGER),
		_activation(multi_id, "Loaded Hold", "multi_pot", "add_haul", 20, MULTI_TRIGGER),
	]
	var shot: Dictionary = _shot(
		50,
		10,
		1,
		1,
		1,
		activations,
		{DIRECT_TRIGGER: 1, MULTI_TRIGGER: 1},
		[direct_id, multi_id]
	)
	shot["score_without_item_by_id"] = _counterfactual_scores(
		[direct_id, multi_id],
		[30, 30]
	)
	var identity: Dictionary = _dict(
		ANALYZER.analyze(_snapshot_with_shots([shot])),
		"build_identity"
	)
	_record_case(
		cases,
		"26. Multiple Phase 5B families classify as Hybrid",
		str(identity.get("label", "")) == "Direct Pot / Multi-Pot Hybrid",
		{"label": "Direct Pot / Multi-Pot Hybrid"},
		identity
	)


static func _test_dead_reckoning_supported_metrics(cases: Array[Dictionary]) -> void:
	var clean_id: String = "direct_pot_haul_clean_plunder"
	var true_id: String = "direct_pot_mult_true_bearing"
	var unerring_id: String = "direct_pot_xmult_unerring_course"
	var activations: Array[Dictionary] = []
	for original in [
		_activation(clean_id, "Clean Plunder", "direct_pot", "add_haul", 10, DIRECT_TRIGGER),
		_activation(true_id, "True Bearing", "direct_pot", "add_mult", 1, DIRECT_TRIGGER),
		_activation(unerring_id, "Unerring Course", "direct_pot", "xmult", 1.25, DIRECT_TRIGGER),
	]:
		activations.append(original)
		activations.append(_retrigger_activation(original, activations.size()))
	var owned_ids: Array[String] = [clean_id, true_id, unerring_id, DEAD_RECKONING_ID]
	var shot: Dictionary = _shot(
		140,
		10,
		1,
		1,
		1,
		activations,
		{DIRECT_TRIGGER: 1},
		owned_ids
	)
	shot["score_without_item_by_id"] = _counterfactual_scores(
		owned_ids,
		[100, 80, 90, 50]
	)
	shot["build_snapshot"] = _build_snapshot(owned_ids)
	var round_record: Dictionary = _round(1, 100, 140)
	round_record["build_at_round_start"] = owned_ids.duplicate()
	round_record["build_at_round_end"] = owned_ids.duplicate()
	var snapshot: Dictionary = _snapshot_with_shots([shot])
	snapshot["rounds"] = [round_record]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var metrics: Dictionary = _dict(report, "dead_reckoning_metrics")
	var direct_family: Dictionary = _dict(
		_dict(_dict(report, "trigger_metrics"), "families"),
		"direct_pot"
	)
	var dead_item: Dictionary = _item(report, DEAD_RECKONING_ID)
	_record_case(
		cases,
		"27. Dead Reckoning supported retriggers are attributed",
		int(metrics.get("direct_pot_occurrences_while_owned", -1)) == 1
			and int(metrics.get("supported_occurrences", -1)) == 1
			and int(metrics.get("unsupported_occurrences", -1)) == 0
			and int(metrics.get("regular_activations_retriggered", -1)) == 3
			and is_equal_approx(float(metrics.get("retriggered_add_haul", -1.0)), 10.0)
			and is_equal_approx(float(metrics.get("retriggered_add_mult", -1.0)), 1.0)
			and int(metrics.get("retriggered_xmult_activations", -1)) == 1
			and is_equal_approx(float(metrics.get("retriggered_xmult_product", -1.0)), 1.25)
			and int(metrics.get("marginal_score_uplift", -1)) == 90
			and int(metrics.get("rounds_owned_without_support", -1)) == 0
			and int(direct_family.get("retriggered_item_activations", -1)) == 3
			and int(dead_item.get("final_score_uplift", -1)) == 90,
		{
			"supported": 1,
			"retriggered": 3,
			"haul": 10.0,
			"mult": 1.0,
			"xmult": 1.25,
			"marginal": 90,
			"unsupported_rounds": 0,
		},
		metrics
	)


static func _test_dead_reckoning_dead_support_metrics(cases: Array[Dictionary]) -> void:
	var owned_ids: Array[String] = [DEAD_RECKONING_ID]
	var shot: Dictionary = _shot(
		20,
		20,
		1,
		1,
		1,
		[],
		{DIRECT_TRIGGER: 2},
		owned_ids
	)
	shot["score_without_item_by_id"] = _counterfactual_scores(owned_ids, [20])
	shot["build_snapshot"] = _build_snapshot(owned_ids)
	var round_record: Dictionary = _round(1, 100, 20)
	round_record["build_at_round_start"] = owned_ids.duplicate()
	round_record["build_at_round_end"] = owned_ids.duplicate()
	var snapshot: Dictionary = _snapshot_with_shots([shot])
	snapshot["rounds"] = [round_record]
	var metrics: Dictionary = _dict(
		ANALYZER.analyze(snapshot),
		"dead_reckoning_metrics"
	)
	_record_case(
		cases,
		"28. Dead Reckoning unsupported occurrences and rounds stay visible",
		int(metrics.get("direct_pot_occurrences_while_owned", -1)) == 2
			and int(metrics.get("supported_occurrences", -1)) == 0
			and int(metrics.get("unsupported_occurrences", -1)) == 2
			and int(metrics.get("dead_occurrences", -1)) == 2
			and int(metrics.get("regular_activations_retriggered", -1)) == 0
			and int(metrics.get("marginal_score_uplift", -1)) == 0
			and int(metrics.get("rounds_owned_without_support", -1)) == 1,
		{
			"direct_pots": 2,
			"supported": 0,
			"dead": 2,
			"retriggered": 0,
			"marginal": 0,
			"unsupported_rounds": 1,
		},
		metrics
	)


static func _test_telemetry_preserves_retrigger_evidence(cases: Array[Dictionary]) -> void:
	var clean_id: String = "direct_pot_haul_clean_plunder"
	var owned_ids: Array[String] = [clean_id, DEAD_RECKONING_ID]
	var build_snapshot: Dictionary = _build_snapshot(owned_ids)
	var run_before: Dictionary = {
		"round_number": 1,
		"round_index": 0,
		"round_target": 100,
		"round_score": 0,
		"shots_left": 5,
		"hull": 3,
	}
	var run_after: Dictionary = run_before.duplicate(true)
	run_after["round_score"] = 30
	run_after["shots_left"] = 4
	var ledger: Dictionary = {
		"source": "authoritative",
		"mode_id": "roguelite",
		"run_generation": 77,
		"shot_id": 1,
		"attempt_id": 1,
		"round_number": 1,
		"round_index": 0,
		"derived": {
			"object_ball_pocket_count": 1,
			"scratch_occurred": false,
		},
	}
	var occurrence: Dictionary = {
		"trigger_occurrence_id": "shot1_ball2_direct_pot",
		"trigger_id": DIRECT_TRIGGER,
		"trigger_ball_id": 2,
		"trigger_event_index": 5,
		"ball_number": 2,
		"pocket_order": 1,
		"pocket_index": 0,
		"pocket_event_index": 5,
		"world_position": Vector2(100.0, 200.0),
		"metadata": {"causal_depth": 1, "qualifying_rail_count": 0},
	}
	var original_metadata: Dictionary = {
		"eight_ball_item_id": clean_id,
		"family_id": "direct_pot",
		"modifier_phase": "add_haul",
		"slot_index": 0,
		"trigger_id": DIRECT_TRIGGER,
		"trigger_occurrence_id": "shot1_ball2_direct_pot",
		"trigger_ball_id": 2,
		"trigger_event_index": 5,
		"activation_id": "clean|original",
		"is_retrigger": false,
		"retrigger_index": 0,
		"original_activation_id": "clean|original",
	}
	var retrigger_metadata: Dictionary = original_metadata.duplicate(true)
	retrigger_metadata["activation_id"] = "clean|original|retrigger:1"
	retrigger_metadata["is_retrigger"] = true
	retrigger_metadata["retrigger_index"] = 1
	retrigger_metadata["retrigger_source_item_id"] = DEAD_RECKONING_ID
	retrigger_metadata["retrigger_source_slot_index"] = 1
	var score_result: Dictionary = {
		"run_generation": 77,
		"shot_id": 1,
		"attempt_id": 1,
		"mode_id": "roguelite",
		"shot_transaction_accepted": true,
		"shot_transaction_outcome": "continue",
		"shot_score": 30,
		"final_haul": 30,
		"final_mult": 1.0,
		"eight_ball_build_evaluation": {
			"trigger_occurrences": [occurrence],
			"add_haul_total": 20,
			"add_mult_total": 0.0,
			"xmult_product": 1.0,
		},
		"resolution_steps": [
			{
				"source_type": "modifier",
				"source_id": clean_id,
				"display_name": "Clean Plunder",
				"phase": "add_haul",
				"haul_delta": 10,
				"haul_before": 10,
				"haul_after": 20,
				"mult_before": 1.0,
				"mult_after": 1.0,
				"score_preview_after": 20,
				"step_index": 2,
				"metadata": original_metadata,
			},
			{
				"source_type": "modifier",
				"source_id": clean_id,
				"display_name": "Clean Plunder",
				"phase": "add_haul",
				"haul_delta": 10,
				"haul_before": 20,
				"haul_after": 30,
				"mult_before": 1.0,
				"mult_after": 1.0,
				"score_preview_after": 30,
				"step_index": 3,
				"metadata": retrigger_metadata,
			},
		],
	}
	var base_result: Dictionary = {
		"run_generation": 77,
		"shot_id": 1,
		"attempt_id": 1,
		"mode_id": "roguelite",
		"shot_score": 10,
		"final_haul": 10,
		"final_mult": 1.0,
	}
	var telemetry = TELEMETRY.new()
	telemetry.begin_fresh_run(77, "roguelite", run_before, build_snapshot)
	var result: Dictionary = telemetry.record_authoritative_shot(
		ledger,
		score_result,
		base_result,
		run_before,
		run_after,
		build_snapshot,
		{clean_id: 20, DEAD_RECKONING_ID: 20}
	)
	var record: Dictionary = _dict(result, "record")
	var activations: Array[Dictionary] = _dict_array(record, "item_activations")
	var dead_summary: Dictionary = _dict(record, "dead_reckoning")
	var compact_build: Dictionary = _dict(record, "build_snapshot")
	var compact_occurrences: Array[Dictionary] = _dict_array(record, "trigger_occurrences")
	_record_case(
		cases,
		"29. Telemetry preserves Phase 5B retrigger and support evidence",
		bool(result.get("accepted", false))
			and activations.size() == 2
			and not bool(activations[0].get("is_retrigger", true))
			and bool(activations[1].get("is_retrigger", false))
			and str(activations[1].get("retrigger_source_item_id", "")) == DEAD_RECKONING_ID
			and str(activations[1].get("original_activation_id", "")) == "clean|original"
			and int(dead_summary.get("supported_occurrences", -1)) == 1
			and int(dead_summary.get("regular_activations_retriggered", -1)) == 1
			and (_dict_array(compact_build, "item_definitions_by_slot")).size() == 2
			and compact_occurrences.size() == 1
			and int(compact_occurrences[0].get("pocket_index", -1)) == 0,
		{
			"accepted": true,
			"activations": 2,
			"retrigger_source": DEAD_RECKONING_ID,
			"supported": 1,
			"definitions": 2,
			"pocket_index": 0,
		},
		{
			"accepted": result.get("accepted"),
			"activations": activations,
			"dead_reckoning": dead_summary,
			"build": compact_build,
			"occurrences": compact_occurrences,
		}
	)


static func _test_tap_run_aggregation(cases: Array[Dictionary]) -> void:
	var shot_a: Dictionary = _tap_shot(
		_shot(40, 40, 1, 1, 1, [], {
			CUE_RECONTACT_TRIGGER: 2,
			SINGLE_TRIGGER: 1,
		}),
		{
			"cue_recontact_milestones": 2,
			"maximum_cue_strikes_against_one_scoring_ball": 3,
			"scoring_balls_with_double_tap": 1,
			"scoring_balls_with_triple_tap_or_higher": 1,
			"has_double_tap": true,
			"has_triple_tap_or_higher": true,
			"tap_direct_pot_disqualifications": 1,
			"cue_recontact_score_supplied": 20,
		}
	)
	var shot_b: Dictionary = _tap_shot(
		_shot(30, 30, 2, 2, 1, [], {
			BALL_TAP_TRIGGER: 2,
			COMBINATION_TRIGGER: 1,
		}),
		{
			"ball_tap_milestones": 2,
			"unique_ball_tap_target_count": 2,
			"maximum_ball_taps_by_one_scoring_ball": 2,
			"scoring_balls_with_ball_tap": 1,
			"repeated_ball_tap_contacts_ignored": 1,
			"ball_tap_score_supplied": 20,
		}
	)
	var shot_c: Dictionary = _tap_shot(
		_shot(30, 30, 3, 3, 1, [], {
			CUE_RECONTACT_TRIGGER: 1,
			BALL_TAP_TRIGGER: 1,
		}),
		{
			"cue_recontact_milestones": 1,
			"maximum_cue_strikes_against_one_scoring_ball": 2,
			"scoring_balls_with_double_tap": 1,
			"has_double_tap": true,
			"ball_tap_milestones": 1,
			"unique_ball_tap_target_count": 1,
			"maximum_ball_taps_by_one_scoring_ball": 1,
			"scoring_balls_with_ball_tap": 1,
			"ambiguous_cue_contacts_rejected": 1,
			"ambiguous_ball_tap_contacts_rejected": 2,
			"ambiguous_tap_contacts_rejected": 3,
			"cue_recontact_score_supplied": 10,
			"ball_tap_score_supplied": 10,
		}
	)
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([
		shot_a,
		shot_b,
		shot_c,
	]))
	var tap: Dictionary = _dict(report, "tap_metrics")
	_record_case(
		cases,
		"30. Tap run metrics aggregate counts, maxima, averages, and supplied score",
		int(tap.get("shots_with_double_tap", -1)) == 2
			and int(tap.get("shots_with_triple_tap_or_higher", -1)) == 1
			and int(tap.get("cue_recontact_milestones", -1)) == 3
			and int(tap.get("ball_tap_milestones", -1)) == 3
			and int(tap.get("maximum_cue_strikes_against_one_scoring_ball", -1)) == 3
			and int(tap.get("maximum_ball_taps_by_one_scoring_ball", -1)) == 2
			and is_equal_approx(float(tap.get("average_double_tap_mult", -1.0)), 1.5)
			and is_equal_approx(float(tap.get("average_ball_tap_mult", -1.0)), 1.5)
			and int(tap.get("ambiguous_tap_contacts_rejected", -1)) == 3
			and int(tap.get("cue_recontact_score_supplied", -1)) == 30
			and int(tap.get("ball_tap_score_supplied", -1)) == 30
			and int(tap.get("total_tap_score_supplied", -1)) == 60
			and str(report.get("copy_summary", "")).contains("Tap Score Supplied: 30 cue + 30 ball = 60"),
		{
			"double_tap_shots": 2,
			"triple_tap_shots": 1,
			"cue_milestones": 3,
			"ball_milestones": 3,
			"average_mult": 1.5,
			"tap_score": 60,
		},
		tap
	)


static func _test_tap_frequency_comparison(cases: Array[Dictionary]) -> void:
	var shots: Array[Dictionary] = [
		_tap_shot(_shot(20, 20, 1, 1, 1, [], {CUE_RECONTACT_TRIGGER: 1}), {
			"cue_recontact_milestones": 1,
			"has_double_tap": true,
		}),
		_tap_shot(_shot(20, 20, 2, 2, 1, [], {BALL_TAP_TRIGGER: 1}), {
			"ball_tap_milestones": 1,
			"unique_ball_tap_target_count": 1,
			"scoring_balls_with_ball_tap": 1,
		}),
		_shot(20, 20, 3, 3, 1, [], {SINGLE_TRIGGER: 1}),
		_shot(20, 20, 4, 4, 1, [], {COMBINATION_TRIGGER: 1}),
	]
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots(shots))
	var tap: Dictionary = _dict(report, "tap_metrics")
	var frequency: Dictionary = _dict(tap, "frequency_comparison")
	var trigger_metrics: Dictionary = _dict(report, "trigger_metrics")
	var families: Dictionary = _dict(trigger_metrics, "families")
	_record_case(
		cases,
		"31. Tap frequency compares directly with Bank and Combination",
		is_equal_approx(float(frequency.get("cue_recontact_shot_frequency", -1.0)), 0.25)
			and is_equal_approx(float(frequency.get("ball_tap_shot_frequency", -1.0)), 0.25)
			and is_equal_approx(float(frequency.get("bank_shot_frequency", -1.0)), 0.25)
			and is_equal_approx(float(frequency.get("combination_shot_frequency", -1.0)), 0.25)
			and is_equal_approx(float(frequency.get("cue_recontact_to_bank_occurrence_ratio", -1.0)), 1.0)
			and is_equal_approx(float(frequency.get("ball_tap_to_combination_ratio", -1.0)), 1.0)
			and _trigger_occurrences(families, "cue_recontact") == 1
			and _trigger_occurrences(families, "ball_tap") == 1,
		{"each_shot_frequency": 0.25, "occurrence_ratios": 1.0},
		{"frequency": frequency, "families": families}
	)


static func _test_tap_exploit_watch(cases: Array[Dictionary]) -> void:
	var shot: Dictionary = _tap_shot(_shot(60, 60), {
		"cue_recontact_milestones": 5,
		"maximum_cue_strikes_against_one_scoring_ball": 6,
		"has_double_tap": true,
		"has_triple_tap_or_higher": true,
	})
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([shot]))
	var flags: Array[String] = _watch_ids(report)
	_record_case(
		cases,
		"32. TAP EXPLOIT WATCH uses the transparent six-strike threshold",
		flags.has("tap_exploit") and not flags.has("contact_farm"),
		{"tap_exploit": true, "contact_farm": false, "threshold": 6},
		{"flags": flags, "tap": _dict(report, "tap_metrics")}
	)


static func _test_contact_farm_watch(cases: Array[Dictionary]) -> void:
	var shot: Dictionary = _tap_shot(_shot(20, 20), {
		"ball_tap_milestones": 2,
		"unique_ball_tap_target_count": 2,
		"maximum_ball_taps_by_one_scoring_ball": 2,
		"scoring_balls_with_ball_tap": 1,
		"repeated_ball_tap_contacts_ignored": 4,
	})
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([shot]))
	var flags: Array[String] = _watch_ids(report)
	_record_case(
		cases,
		"33. CONTACT FARM WATCH uses repeated-count and ratio thresholds",
		flags.has("contact_farm") and not flags.has("tap_exploit"),
		{
			"contact_farm": true,
			"tap_exploit": false,
			"repeated_contacts": 4,
			"ratio": 2.0,
		},
		{"flags": flags, "tap": _dict(report, "tap_metrics")}
	)


static func _test_telemetry_preserves_tap_evidence(cases: Array[Dictionary]) -> void:
	var telemetry = TELEMETRY.new()
	var run_snapshot: Dictionary = _telemetry_run_snapshot(91)
	telemetry.begin_fresh_run(91, "roguelite", run_snapshot, {})
	var target_ids: Array[int] = []
	for target_id in range(10, 80):
		target_ids.append(target_id)
	var result: Dictionary = _record_telemetry_tap_shot(
		telemetry,
		91,
		1,
		3,
		target_ids,
		2,
		1,
		2
	)
	var record: Dictionary = _dict(result, "record")
	var tap: Dictionary = _dict(record, "tap_metrics")
	var targets: Array[Dictionary] = _dict_array(tap, "unique_ball_tap_targets")
	var snapshot: Dictionary = telemetry.get_current_run_snapshot()
	var accumulator: Dictionary = _dict(_dict(snapshot, "run_accumulators"), "tap_metrics")
	_record_case(
		cases,
		"34. Telemetry compacts Tap evidence, score supply, and bounded targets",
		bool(result.get("accepted", false))
			and int(tap.get("cue_recontact_milestones", -1)) == 2
			and int(tap.get("maximum_cue_strikes_against_one_scoring_ball", -1)) == 3
			and int(tap.get("ball_tap_milestones", -1)) == 70
			and int(tap.get("repeated_ball_tap_contacts_ignored", -1)) == 2
			and int(tap.get("ambiguous_tap_contacts_rejected", -1)) == 3
			and int(tap.get("tap_direct_pot_disqualifications", -1)) == 1
			and int(tap.get("cue_recontact_score_supplied", -1)) == 20
			and int(tap.get("ball_tap_score_supplied", -1)) == 700
			and targets.size() == 64
			and bool(tap.get("target_evidence_truncated", false))
			and int(accumulator.get("cue_recontact_milestones", -1)) == 2
			and int(accumulator.get("ball_tap_milestones", -1)) == 70,
		{
			"cue_milestones": 2,
			"ball_milestones": 70,
			"score_supply": [20, 700],
			"bounded_targets": 64,
			"ambiguity_rejects": 3,
		},
		{"tap": tap, "accumulator": accumulator, "target_count": targets.size()}
	)


static func _test_tap_rewind_restores_accumulators(cases: Array[Dictionary]) -> void:
	var telemetry = TELEMETRY.new()
	var run_snapshot: Dictionary = _telemetry_run_snapshot(92)
	telemetry.begin_fresh_run(92, "roguelite", run_snapshot, {})
	_record_telemetry_tap_shot(telemetry, 92, 1, 2, [10])
	var checkpoint: Dictionary = telemetry.capture_rewind_state()
	_record_telemetry_tap_shot(telemetry, 92, 2, 4, [11, 12], 4)
	var restore_result: Dictionary = telemetry.restore_rewind_state(checkpoint)
	var snapshot: Dictionary = telemetry.get_current_run_snapshot()
	var accumulator: Dictionary = _dict(_dict(snapshot, "run_accumulators"), "tap_metrics")
	var shots: Array[Dictionary] = _dict_array(snapshot, "shots")
	_record_case(
		cases,
		"35. Rewind restores Tap shot history and accumulators exactly",
		bool(restore_result.get("accepted", false))
			and shots.size() == 1
			and int(accumulator.get("shots_with_double_tap", -1)) == 1
			and int(accumulator.get("shots_with_triple_tap_or_higher", -1)) == 0
			and int(accumulator.get("cue_recontact_milestones", -1)) == 1
			and int(accumulator.get("ball_tap_milestones", -1)) == 1
			and int(accumulator.get("repeated_ball_tap_contacts_ignored", -1)) == 0,
		{
			"shots": 1,
			"double_tap_shots": 1,
			"triple_tap_shots": 0,
			"cue_milestones": 1,
			"ball_milestones": 1,
			"repeated": 0,
		},
		{"shots": shots.size(), "accumulator": accumulator}
	)


static func _test_phase_5c_telemetry_preserves_state(cases: Array[Dictionary]) -> void:
	var telemetry = TELEMETRY.new()
	var run_snapshot: Dictionary = _telemetry_run_snapshot(101)
	var build: Dictionary = _phase_5c_build_snapshot([
		RATTLE_ID,
		SECOND_BITE_ID,
		ECHO_CHAMBER_ID,
	], 14, 1.6)
	telemetry.begin_fresh_run(101, "roguelite", run_snapshot, build)
	var result: Dictionary = _record_phase_5c_telemetry_shot(
		telemetry,
		101,
		1,
		build,
		1.0,
		1.6,
		3,
		1
	)
	var record: Dictionary = _dict(result, "record")
	var metrics: Dictionary = _dict(record, "phase_5c_tap_items")
	var rattle: Dictionary = _dict(metrics, "rattle")
	var echo: Dictionary = _dict(metrics, "echo_chamber")
	var compact_build: Dictionary = _dict(record, "build_snapshot")
	var slots: Array[Dictionary] = _dict_array(compact_build, "slots")
	var states_before: Dictionary = _dict(metrics, "item_states_before")
	var mutations: Array[Dictionary] = _dict_array(metrics, "state_mutations")
	var engine_events: Array[Dictionary] = _dict_array(metrics, "engine_events")
	var mutation_after: Dictionary = (
		_dict(mutations[0], "state_after")
		if not mutations.is_empty()
		else {}
	)
	_record_case(
		cases,
		"36. Telemetry preserves bounded state, instance, threshold, and uplift evidence",
		bool(result.get("accepted", false))
			and slots.size() == 3
			and int(slots[0].get("owned_item_instance_id", -1)) == 14
			and is_equal_approx(float(rattle.get("current_xmult_before", 0.0)), 1.0)
			and is_equal_approx(float(rattle.get("current_xmult_after", 0.0)), 1.6)
			and int(rattle.get("tap_milestones_grown_from", -1)) == 3
			and int(rattle.get("marginal_score_uplift", -1)) == 24
			and int(echo.get("threshold_milestones", -1)) == 1
			and int(echo.get("supported_thresholds", -1)) == 1
			and is_equal_approx(float(_dict(states_before, "14").get(
				"current_xmult",
				0.0
			)), 1.0)
			and is_equal_approx(float(mutation_after.get("current_xmult", 0.0)), 1.6)
			and not engine_events.is_empty()
			and str(engine_events[0].get("event_kind", "")) == "state_growth"
			and bool(metrics.get("evidence_bounded", false)),
		{
			"instance_id": 14,
			"state": [1.0, 1.6],
			"taps": 3,
			"thresholds": 1,
			"uplift": 24,
			"engine_event_kind": "state_growth",
		},
		{"slots": slots, "rattle": rattle, "echo": echo}
	)


static func _test_phase_5c_rattle_aggregation(cases: Array[Dictionary]) -> void:
	var tap_shot: Dictionary = _shot(44, 24, 1, 1, 1, [], {}, [RATTLE_ID])
	tap_shot["item_counterfactual_scores"] = {
		RATTLE_ID: {"available": true, "score_without_item": 24, "marginal_score_uplift": 20},
	}
	tap_shot["phase_5c_tap_items"] = _phase_5c_summary({
		"rattle": _phase_5c_rattle(1.0, 1.4, 2, 20, true, 14),
	})
	var quiet_shot: Dictionary = _shot(10, 10, 2, 2, 1, [], {}, [RATTLE_ID])
	quiet_shot["item_counterfactual_scores"] = {
		RATTLE_ID: {"available": true, "score_without_item": 10, "marginal_score_uplift": 0},
	}
	quiet_shot["phase_5c_tap_items"] = _phase_5c_summary({
		"rattle": _phase_5c_rattle(1.4, 1.4, 0, 0, false, 14),
	})
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([tap_shot, quiet_shot]))
	var rattle: Dictionary = _dict(_dict(report, "phase_5c_tap_items"), "rattle")
	_record_case(
		cases,
		"37. Rattle aggregates state before/after, growth, idle ownership, and uplift",
		bool(rattle.get("owned", false))
			and int(rattle.get("shots_owned", -1)) == 2
			and int(rattle.get("tap_milestones_grown_from", -1)) == 2
			and int(rattle.get("shots_activated", -1)) == 1
			and int(rattle.get("non_tap_shots_owned", -1)) == 1
			and is_equal_approx(float(rattle.get("acquired_value", 0.0)), 1.0)
			and is_equal_approx(float(rattle.get("final_xmult", 0.0)), 1.4)
			and int(rattle.get("marginal_score_uplift", -1)) == 20,
		{"owned_shots": 2, "growth": 2, "idle": 1, "state": [1.0, 1.4], "uplift": 20},
		rattle
	)


static func _test_phase_5c_one_two_punch_aggregation(cases: Array[Dictionary]) -> void:
	var qualifying: Dictionary = _shot(60, 30, 1, 1, 1, [], {}, [ONE_TWO_PUNCH_ID])
	qualifying["phase_5c_tap_items"] = _phase_5c_summary({
		"one_two_punch": {
			"owned": true,
			"qualifying_scoring_balls": 2,
			"activations": 2,
			"only_one_tap_family_present": false,
			"marginal_score_uplift": 30,
		},
	})
	var unsupported: Dictionary = _shot(20, 20, 2, 2, 1, [], {}, [ONE_TWO_PUNCH_ID])
	unsupported["phase_5c_tap_items"] = _phase_5c_summary({
		"one_two_punch": {
			"owned": true,
			"qualifying_scoring_balls": 0,
			"activations": 0,
			"only_one_tap_family_present": true,
			"marginal_score_uplift": 0,
		},
	})
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([qualifying, unsupported]))
	var punch: Dictionary = _dict(_dict(report, "phase_5c_tap_items"), "one_two_punch")
	_record_case(
		cases,
		"38. One-Two Punch reports qualifying balls and one-family misses",
		int(punch.get("qualifying_scoring_balls", -1)) == 2
			and int(punch.get("activations", -1)) == 2
			and int(punch.get("shots_with_only_one_family", -1)) == 1
			and int(punch.get("marginal_score_uplift", -1)) == 30,
		{"qualifying": 2, "activations": 2, "one_family_only": 1, "uplift": 30},
		punch
	)


static func _test_phase_5c_aftershock_aggregation(cases: Array[Dictionary]) -> void:
	var shot: Dictionary = _shot(62, 40, 1, 1, 1, [], {}, [AFTERSHOCK_ID])
	shot["phase_5c_tap_items"] = _phase_5c_summary({
		"aftershock": {
			"owned": true,
			"tap_milestones_while_owned": 3,
			"ignored_first_milestones": 1,
			"xmult_activations": 2,
			"highest_tap_ordinal": 3,
			"marginal_score_uplift": 22,
		},
	})
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([shot]))
	var aftershock: Dictionary = _dict(_dict(report, "phase_5c_tap_items"), "aftershock")
	_record_case(
		cases,
		"39. Aftershock aggregates ignored first Tap, activations, highest ordinal, and uplift",
		int(aftershock.get("tap_milestones_while_owned", -1)) == 3
			and int(aftershock.get("ignored_first_milestones", -1)) == 1
			and int(aftershock.get("xmult_activations", -1)) == 2
			and int(aftershock.get("highest_tap_ordinal", -1)) == 3
			and int(aftershock.get("marginal_score_uplift", -1)) == 22,
		{"taps": 3, "ignored": 1, "activations": 2, "ordinal": 3, "uplift": 22},
		aftershock
	)


static func _test_phase_5c_echo_attribution(cases: Array[Dictionary]) -> void:
	var shot: Dictionary = _shot(
		696,
		40,
		1,
		1,
		1,
		[],
		{},
		[ECHO_CHAMBER_ID, KNOCK_ON_PLUNDER_ID, CROWDED_WAKE_ID]
	)
	shot["phase_5c_tap_items"] = _phase_5c_summary({
		"echo_chamber": {
			"owned": true,
			"has_regular_tap_support": true,
			"threshold_milestones": 2,
			"supported_thresholds": 2,
			"unsupported_thresholds": 0,
			"regular_activations_retriggered": 4,
			"retriggers_by_family": {"double_tap": 1, "ball_tap": 3},
			"retriggered_add_haul": 8.0,
			"retriggered_add_mult": 1.0,
			"retriggered_xmult_activations": 2,
			"retriggered_xmult_product": 1.44,
			"support_item_ids": [KNOCK_ON_PLUNDER_ID, CROWDED_WAKE_ID],
			"marginal_score_uplift": 180,
		},
	})
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots([shot]))
	var echo: Dictionary = _dict(_dict(report, "phase_5c_tap_items"), "echo_chamber")
	var families: Dictionary = _dict(echo, "retriggers_by_family")
	_record_case(
		cases,
		"40. Echo Chamber attributes thresholds, families, retrigger phases, and uplift",
		int(echo.get("threshold_milestones", -1)) == 2
			and int(echo.get("supported_thresholds", -1)) == 2
			and int(echo.get("regular_activations_retriggered", -1)) == 4
			and int(families.get("double_tap", -1)) == 1
			and int(families.get("ball_tap", -1)) == 3
			and is_equal_approx(float(echo.get("retriggered_add_haul", -1.0)), 8.0)
			and is_equal_approx(float(echo.get("retriggered_add_mult", -1.0)), 1.0)
			and int(echo.get("retriggered_xmult_activations", -1)) == 2
			and is_equal_approx(float(echo.get("retriggered_xmult_product", -1.0)), 1.44)
			and int(echo.get("marginal_score_uplift", -1)) == 180,
		{"thresholds": 2, "families": [1, 3], "haul": 8.0, "mult": 1.0, "xmult": [2, 1.44], "uplift": 180},
		echo
	)


static func _test_phase_5c_echo_support_rounds(cases: Array[Dictionary]) -> void:
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = []
	snapshot["rounds"] = [
		_round_with_build(1, [ECHO_CHAMBER_ID, SECOND_BITE_ID]),
		_round_with_build(2, [ECHO_CHAMBER_ID]),
		_round_with_build(3, [ECHO_CHAMBER_ID, KNOCK_ON_PLUNDER_ID]),
	]
	var report: Dictionary = ANALYZER.analyze(snapshot)
	var echo: Dictionary = _dict(_dict(report, "phase_5c_tap_items"), "echo_chamber")
	_record_case(
		cases,
		"41. Echo Chamber distinguishes supported and unsupported owned rounds",
		int(echo.get("rounds_owned_with_support", -1)) == 2
			and int(echo.get("rounds_owned_without_support", -1)) == 1
			and echo.get("round_numbers_owned_with_support", []) == [1, 3]
			and echo.get("round_numbers_owned_without_support", []) == [2],
		{"with_support": [1, 3], "without_support": [2]},
		{
			"with_support": echo.get("round_numbers_owned_with_support"),
			"without_support": echo.get("round_numbers_owned_without_support"),
		}
	)


static func _test_phase_5c_build_identities(cases: Array[Dictionary]) -> void:
	var double_report: Dictionary = ANALYZER.analyze(_identity_snapshot(
		[SECOND_BITE_ID],
		[40],
		60,
		20
	))
	var ball_report: Dictionary = ANALYZER.analyze(_identity_snapshot(
		[KNOCK_ON_PLUNDER_ID],
		[40],
		60,
		20
	))
	var hybrid_snapshot: Dictionary = _identity_snapshot(
		[ONE_TWO_PUNCH_ID],
		[30],
		50,
		20
	)
	var hybrid_shot: Dictionary = (hybrid_snapshot["shots"] as Array)[0]
	hybrid_shot["phase_5c_tap_items"] = _phase_5c_summary({
		"one_two_punch": {
			"owned": true,
			"qualifying_scoring_balls": 1,
			"activations": 1,
			"only_one_tap_family_present": false,
			"marginal_score_uplift": 30,
		},
	})
	var hybrid_report: Dictionary = ANALYZER.analyze(hybrid_snapshot)
	var growth_snapshot: Dictionary = _identity_snapshot([RATTLE_ID], [60], 80, 20)
	var growth_shot: Dictionary = (growth_snapshot["shots"] as Array)[0]
	growth_shot["phase_5c_tap_items"] = _phase_5c_summary({
		"rattle": _phase_5c_rattle(1.0, 1.6, 3, 60, true, 21),
	})
	var growth_report: Dictionary = ANALYZER.analyze(growth_snapshot)
	var labels: Array[String] = [
		str(_dict(double_report, "build_identity").get("label", "")),
		str(_dict(ball_report, "build_identity").get("label", "")),
		str(_dict(hybrid_report, "build_identity").get("label", "")),
		str(_dict(growth_report, "build_identity").get("label", "")),
	]
	_record_case(
		cases,
		"42. Phase 5C build identities classify Double, Ball, Hybrid, and Growth engines",
		labels == ["Double Tap Engine", "Ball Tap Engine", "Tap Hybrid", "Tap Growth Engine"],
		{"labels": ["Double Tap Engine", "Ball Tap Engine", "Tap Hybrid", "Tap Growth Engine"]},
		{"labels": labels}
	)


static func _test_phase_5c_state_history_is_bounded(cases: Array[Dictionary]) -> void:
	var shots: Array[Dictionary] = []
	for index in range(125):
		var shot: Dictionary = _shot(24, 20, index + 1, index + 1, 1, [], {}, [RATTLE_ID])
		shot["phase_5c_tap_items"] = _phase_5c_summary({
			"rattle": _phase_5c_rattle(
				1.0 + float(index) * 0.2,
				1.2 + float(index) * 0.2,
				1,
				4,
				true,
				14
			),
		})
		shots.append(shot)
	var report: Dictionary = ANALYZER.analyze(_snapshot_with_shots(shots))
	var metrics: Dictionary = _dict(report, "phase_5c_tap_items")
	var history: Array[Dictionary] = _dict_array(metrics, "state_history")
	_record_case(
		cases,
		"43. Rattle state history is bounded to 120 authoritative shots",
		history.size() == 120
			and int(metrics.get("state_history_dropped", -1)) == 5
			and str(history[0].get("shot_key", "")) == "6|6",
		{"retained": 120, "dropped": 5, "first": "6|6"},
		{
			"retained": history.size(),
			"dropped": metrics.get("state_history_dropped"),
			"first": history[0].get("shot_key") if not history.is_empty() else "",
		}
	)


static func _test_phase_5c_rewind_restores_accumulator(cases: Array[Dictionary]) -> void:
	var telemetry = TELEMETRY.new()
	var run_snapshot: Dictionary = _telemetry_run_snapshot(102)
	var build: Dictionary = _phase_5c_build_snapshot([RATTLE_ID], 30, 1.2)
	telemetry.begin_fresh_run(102, "roguelite", run_snapshot, build)
	_record_phase_5c_telemetry_shot(telemetry, 102, 1, build, 1.0, 1.2, 1, 0)
	var checkpoint: Dictionary = telemetry.capture_rewind_state()
	_record_phase_5c_telemetry_shot(telemetry, 102, 2, build, 1.2, 1.6, 2, 0)
	var restore: Dictionary = telemetry.restore_rewind_state(checkpoint)
	var snapshot: Dictionary = telemetry.get_current_run_snapshot()
	var accumulator: Dictionary = _dict(
		_dict(_dict(snapshot, "run_accumulators"), "phase_5c_tap_items"),
		"rattle"
	)
	var shots: Array[Dictionary] = _dict_array(snapshot, "shots")
	_record_case(
		cases,
		"44. Rewind restores Phase 5C state history and aggregates exactly",
		bool(restore.get("accepted", false))
			and shots.size() == 1
			and int(accumulator.get("tap_milestones_grown_from", -1)) == 1
			and is_equal_approx(float(accumulator.get("final_xmult", 0.0)), 1.2),
		{"shots": 1, "growth": 1, "final_xmult": 1.2},
		{
			"shots": shots.size(),
			"growth": accumulator.get("tap_milestones_grown_from"),
			"final_xmult": accumulator.get("final_xmult"),
		}
	)


static func _phase_5c_summary(overrides: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"schema_version": 1,
		"tap_milestone_count": 0,
		"cue_recontact_milestone_count": 0,
		"object_ball_tap_milestone_count": 0,
		"rattle": {"owned": false},
		"one_two_punch": {"owned": false},
		"aftershock": {"owned": false},
		"echo_chamber": {"owned": false},
		"item_states_before": {},
		"item_states_after": {},
		"state_mutations": [],
		"engine_events": [],
		"evidence_bounded": true,
	}
	for key_value in overrides.keys():
		result[str(key_value)] = overrides[key_value]
	return result


static func _phase_5c_rattle(
	before: float,
	after: float,
	tap_count: int,
	uplift: int,
	activated: bool,
	instance_id: int
) -> Dictionary:
	return {
		"owned": true,
		"owned_item_instance_id": instance_id,
		"state_before": {
			"state_version": 1,
			"current_xmult": before,
			"lifetime_growth_triggers": 0,
			"shots_activated": 0,
		},
		"state_after": {
			"state_version": 1,
			"current_xmult": after,
			"lifetime_growth_triggers": tap_count,
			"shots_activated": 1 if activated else 0,
		},
		"current_xmult_before": before,
		"current_xmult_after": after,
		"lifetime_growth_before": 0,
		"lifetime_growth_after": tap_count,
		"shots_activated_before": 0,
		"shots_activated_after": 1 if activated else 0,
		"tap_milestones_grown_from": tap_count,
		"activated_this_shot": activated,
		"activation_count": 1 if activated else 0,
		"non_tap_shot_while_owned": tap_count == 0,
		"growth_events": [],
		"marginal_score_uplift": uplift,
	}


static func _phase_5c_build_snapshot(
	item_ids: Array[String],
	first_instance_id: int,
	rattle_xmult: float
) -> Dictionary:
	var definitions: Array[Dictionary] = []
	var slots: Array[Dictionary] = []
	for index in range(item_ids.size()):
		var item_id: String = item_ids[index]
		var definition: Dictionary = _phase_5c_definition(item_id)
		definitions.append(definition)
		var state: Dictionary = {}
		if item_id == RATTLE_ID:
			state = {
				"state_version": 1,
				"current_xmult": rattle_xmult,
				"lifetime_growth_triggers": maxi(roundi((rattle_xmult - 1.0) / 0.2), 0),
				"shots_activated": 1 if rattle_xmult > 1.0 else 0,
			}
		slots.append({
			"slot_index": index,
			"eight_ball_item_id": item_id,
			"owned_item_instance_id": first_instance_id + index,
			"acquired_round": 1,
			"state": state,
			"definition": definition,
		})
	return {
		"schema_version": 2,
		"tray_capacity": 5,
		"occupied_slots": item_ids.size(),
		"item_ids_by_slot": item_ids.duplicate(),
		"item_definitions_by_slot": definitions,
		"slots": slots,
		"next_owned_item_instance_id": first_instance_id + item_ids.size(),
	}


static func _phase_5c_definition(item_id: String) -> Dictionary:
	var family_id: String = "tap_oddity"
	var offer_family: String = ""
	var effect_kind: String = "numeric_modifier"
	var phase: String = "xmult"
	if item_id.begins_with("double_tap_"):
		family_id = "double_tap"
	elif item_id.begins_with("ball_tap_"):
		family_id = "ball_tap"
	if item_id.contains("_haul_"):
		phase = "add_haul"
	elif item_id.contains("_mult_") and not item_id.contains("_xmult_"):
		phase = "add_mult"
	match item_id:
		RATTLE_ID:
			offer_family = "tap_growth"
			effect_kind = "persistent_scaler"
		ONE_TWO_PUNCH_ID:
			offer_family = "tap_hybrid"
			effect_kind = "cross_family_conditional"
		AFTERSHOCK_ID:
			offer_family = "tap_escalation"
			effect_kind = "shot_ordinal_multiplier"
		ECHO_CHAMBER_ID:
			offer_family = "tap_retrigger"
			effect_kind = "threshold_family_retrigger"
	return {
		"eight_ball_item_id": item_id,
		"display_name": item_id.replace("_", " ").capitalize(),
		"family_id": family_id,
		"offer_family": offer_family,
		"trigger_id": CUE_RECONTACT_TRIGGER if family_id == "double_tap" else BALL_TAP_TRIGGER,
		"modifier_phase": phase,
		"effect_kind": effect_kind,
		"rarity": "legendary" if item_id == ECHO_CHAMBER_ID else "rare",
		"offer_weight": 8 if item_id == ECHO_CHAMBER_ID else 20,
	}


static func _record_phase_5c_telemetry_shot(
	telemetry,
	run_generation: int,
	attempt_id: int,
	build: Dictionary,
	rattle_before: float,
	rattle_after: float,
	tap_count: int,
	echo_thresholds: int
) -> Dictionary:
	var occurrences: Array[Dictionary] = []
	for index in range(tap_count):
		occurrences.append({
			"trigger_occurrence_id": "phase5c_%d_tap_%d" % [attempt_id, index + 1],
			"trigger_id": CUE_RECONTACT_TRIGGER,
			"trigger_ball_id": 2,
			"trigger_event_index": 10 + index,
		})
	var base_mult: float = 1.0 + float(tap_count)
	var base_score: int = int(floor(10.0 * base_mult))
	var final_score: int = int(floor(float(base_score) * rattle_after))
	var run_before: Dictionary = _telemetry_run_snapshot(run_generation)
	var run_after: Dictionary = run_before.duplicate(true)
	run_after["shots_left"] = 4
	run_after["round_score"] = final_score
	var state_before: Dictionary = {
		str(int((build["slots"] as Array)[0].get("owned_item_instance_id", -1))): {
			"state_version": 1,
			"current_xmult": rattle_before,
			"lifetime_growth_triggers": maxi(roundi((rattle_before - 1.0) / 0.2), 0),
			"shots_activated": 0,
		},
	}
	var state_after: Dictionary = {
		str(int((build["slots"] as Array)[0].get("owned_item_instance_id", -1))): {
			"state_version": 1,
			"current_xmult": rattle_after,
			"lifetime_growth_triggers": maxi(roundi((rattle_after - 1.0) / 0.2), 0),
			"shots_activated": 1,
		},
	}
	var engine_events: Array[Dictionary] = []
	for index in range(tap_count):
		engine_events.append({
			"engine_event_kind": "state_growth",
			"eight_ball_item_id": RATTLE_ID,
			"owned_item_instance_id": int((build["slots"] as Array)[0].get(
				"owned_item_instance_id",
				-1
			)),
			"trigger_occurrence_id": str(occurrences[index].get("trigger_occurrence_id", "")),
			"value_before": rattle_before + float(index) * 0.2,
			"value_after": rattle_before + float(index + 1) * 0.2,
			"growth_amount": 0.2,
			"source": "authoritative",
		})
	for threshold_index in range(echo_thresholds):
		engine_events.append({
			"engine_event_kind": "threshold_retrigger",
			"eight_ball_item_id": ECHO_CHAMBER_ID,
			"retrigger_threshold_ordinal": (threshold_index + 1) * 3,
			"supported": true,
		})
	var ledger: Dictionary = {
		"source": "authoritative",
		"mode_id": "roguelite",
		"run_generation": run_generation,
		"shot_id": attempt_id,
		"attempt_id": attempt_id,
		"round_number": 1,
		"derived": {
			"object_ball_pocket_count": 1,
			"scratch_occurred": false,
			"pocket_facts": [{
				"ball_id": 2,
				"qualifying_cue_strike_count": tap_count + 1,
				"cue_recontact_bonus_count": tap_count,
				"cue_recontact_event_indices": range(tap_count),
				"unique_object_tap_count": 0,
				"is_direct_pot": false,
			}],
		},
	}
	var score_result: Dictionary = {
		"source": "authoritative",
		"mode_id": "roguelite",
		"run_generation": run_generation,
		"shot_id": attempt_id,
		"attempt_id": attempt_id,
		"shot_transaction_accepted": true,
		"shot_transaction_outcome": "continue",
		"shot_transaction": {
			"item_states_before": {
				"item_states_by_instance_id": state_before.duplicate(true),
			},
			"item_states_after": {
				"item_states_by_instance_id": state_after.duplicate(true),
			},
			"pending_item_state_mutations": [{
				"mutation_kind": "replace_owned_item_state",
				"eight_ball_item_id": RATTLE_ID,
				"owned_item_instance_id": int((build["slots"] as Array)[0].get(
					"owned_item_instance_id",
					-1
				)),
				"state_before": state_before.values()[0],
				"state_after": state_after.values()[0],
				"source": "authoritative",
			}],
		},
		"shot_score": final_score,
		"final_haul": 10,
		"final_mult": base_mult * rattle_after,
		"eight_ball_build_evaluation": {
			"trigger_occurrences": occurrences,
			"add_haul_total": 0,
			"add_mult_total": 0.0,
			"xmult_product": rattle_after,
			"state_before": state_before,
			"simulated_state_after": state_after,
			"engine_events": engine_events,
			"authoritative_state_mutations": [{
				"eight_ball_item_id": RATTLE_ID,
				"owned_item_instance_id": int((build["slots"] as Array)[0].get(
					"owned_item_instance_id",
					-1
				)),
				"mutation_kind": "replace_owned_item_state",
				"state_before": state_before.values()[0],
				"state_after": state_after.values()[0],
				"source": "authoritative",
			}],
		},
		"resolution_steps": [{
			"step_index": 1,
			"phase": "xmult",
			"source_type": "modifier",
			"source_id": RATTLE_ID,
			"display_name": "Rattle of the Deep",
			"haul_before": 10,
			"haul_after": 10,
			"mult_before": base_mult,
			"mult_after": base_mult * rattle_after,
			"xmult_factor": rattle_after,
			"score_preview_after": final_score,
			"metadata": {
				"eight_ball_item_id": RATTLE_ID,
				"family_id": "tap_oddity",
				"effect_kind": "persistent_scaler",
				"modifier_phase": "xmult",
				"owned_item_instance_id": int((build["slots"] as Array)[0].get(
					"owned_item_instance_id",
					-1
				)),
			},
		}],
		"doubloon_payout": {"doubloons_awarded": 10},
	}
	var base_result: Dictionary = {
		"source": "authoritative",
		"mode_id": "roguelite",
		"run_generation": run_generation,
		"shot_id": attempt_id,
		"attempt_id": attempt_id,
		"shot_score": base_score,
		"final_haul": 10,
		"final_mult": base_mult,
	}
	var counterfactuals: Dictionary = {
		RATTLE_ID: {"score_without_item": base_score},
	}
	return telemetry.record_authoritative_shot(
		ledger,
		score_result,
		base_result,
		run_before,
		run_after,
		build,
		counterfactuals
	)


static func _round_with_build(round_number: int, item_ids: Array[String]) -> Dictionary:
	var result: Dictionary = _round(round_number, 100, 100)
	var build: Dictionary = _phase_5c_build_snapshot(
		item_ids,
		50 + round_number * 10,
		1.0
	)
	result["build_at_round_start"] = build
	result["build_at_round_end"] = build.duplicate(true)
	return result


static func _identity_snapshot(
	item_ids: Array[String],
	uplifts: Array[int],
	final_score: int,
	base_score: int
) -> Dictionary:
	var activations: Array[Dictionary] = []
	for item_id in item_ids:
		var definition: Dictionary = _phase_5c_definition(item_id)
		activations.append(_activation(
			item_id,
			str(definition.get("display_name", item_id)),
			str(definition.get("family_id", "tap_oddity")),
			str(definition.get("modifier_phase", "xmult")),
			1.25 if str(definition.get("modifier_phase", "")) == "xmult" else 10,
			str(definition.get("trigger_id", CUE_RECONTACT_TRIGGER))
		))
	var shot: Dictionary = _shot(
		final_score,
		base_score,
		1,
		1,
		1,
		activations,
		{},
		item_ids
	)
	var counterfactuals: Dictionary = {}
	for index in range(mini(item_ids.size(), uplifts.size())):
		counterfactuals[item_ids[index]] = {
			"available": true,
			"score_without_item": final_score - uplifts[index],
			"marginal_score_uplift": uplifts[index],
		}
	shot["item_counterfactual_scores"] = counterfactuals
	shot["build_snapshot"] = _phase_5c_build_snapshot(item_ids, 1, 1.0)
	shot["phase_5c_tap_items"] = _phase_5c_summary()
	return _snapshot_with_shots([shot])


static func _snapshot(mode_id: String = "roguelite") -> Dictionary:
	return {
		"schema_version": 1,
		"source": "roguelite_balance_telemetry",
		"mode_id": mode_id,
		"run_generation": 1,
		"finalized": true,
		"final_outcome": "run_complete",
		"shots": [],
		"rounds": [],
		"reward_screens": [],
		"item_lifecycles": [],
		"final_tray": [],
	}


static func _snapshot_with_shots(shots: Array[Dictionary]) -> Dictionary:
	var snapshot: Dictionary = _snapshot()
	snapshot["shots"] = shots.duplicate(true)
	return snapshot


static func _phase_5b_definitions() -> Array[Dictionary]:
	return [
		_phase_5b_definition("direct_pot_haul_clean_plunder", "Clean Plunder", "direct_pot", "add_haul"),
		_phase_5b_definition("direct_pot_mult_true_bearing", "True Bearing", "direct_pot", "add_mult"),
		_phase_5b_definition("direct_pot_xmult_unerring_course", "Unerring Course", "direct_pot", "xmult"),
		_phase_5b_definition(DEAD_RECKONING_ID, "Dead Reckoning", "direct_pot", "", "retrigger_family"),
		_phase_5b_definition("multi_pot_haul_loaded_hold", "Loaded Hold", "multi_pot", "add_haul"),
		_phase_5b_definition("multi_pot_mult_all_hands", "All Hands", "multi_pot", "add_mult"),
		_phase_5b_definition("multi_pot_xmult_broadside_dividend", "Broadside Dividend", "multi_pot", "xmult"),
		_phase_5b_definition("same_pocket_haul_shared_grave", "Shared Grave", "same_pocket", "add_haul"),
		_phase_5b_definition("same_pocket_mult_feeding_frenzy", "Feeding Frenzy", "same_pocket", "add_mult"),
		_phase_5b_definition("same_pocket_xmult_the_maw_below", "The Maw Below", "same_pocket", "xmult"),
	]


static func _phase_5b_definition(
	item_id: String,
	display_name: String,
	family_id: String,
	phase: String,
	effect_kind: String = ""
) -> Dictionary:
	var trigger_id: String = DIRECT_TRIGGER
	if family_id == "multi_pot":
		trigger_id = MULTI_TRIGGER
	elif family_id == "same_pocket":
		trigger_id = SAME_POCKET_TRIGGER
	return {
		"eight_ball_item_id": item_id,
		"display_name": display_name,
		"family_id": family_id,
		"trigger_id": trigger_id,
		"modifier_phase": phase,
		"effect_kind": effect_kind,
		"retrigger_family": "direct_pot" if effect_kind == "retrigger_family" else "",
		"rarity": "legendary" if effect_kind == "retrigger_family" else "common",
		"offer_weight": 8 if effect_kind == "retrigger_family" else 100,
	}


static func _definition_ids(definitions: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for definition in definitions:
		ids.append(str(definition.get("eight_ball_item_id", "")))
	return ids


static func _build_snapshot(item_ids: Array[String]) -> Dictionary:
	var definition_by_id: Dictionary = {}
	for definition in _phase_5b_definitions():
		definition_by_id[str(definition.get("eight_ball_item_id", ""))] = definition
	var definitions: Array[Dictionary] = []
	for item_id in item_ids:
		var definition_value: Variant = definition_by_id.get(item_id, {})
		definitions.append(
			(definition_value as Dictionary).duplicate(true)
			if definition_value is Dictionary
			else {}
		)
	return {
		"item_ids_by_slot": item_ids.duplicate(),
		"item_definitions_by_slot": definitions,
		"occupied_slots": item_ids.size(),
		"tray_capacity": 5,
	}


static func _tap_shot(shot: Dictionary, tap_metrics: Dictionary) -> Dictionary:
	var result: Dictionary = shot.duplicate(true)
	result["tap_metrics"] = tap_metrics.duplicate(true)
	return result


static func _telemetry_run_snapshot(run_generation: int) -> Dictionary:
	return {
		"run_generation": run_generation,
		"round_number": 1,
		"round_count": 1,
		"round_target": 1000,
		"round_score": 0,
		"shots_left": 5,
		"hull": 3,
		"max_hull": 3,
		"object_ball_count": 15,
		"round_active": true,
		"round_won": false,
		"run_failed": false,
		"run_completed": false,
	}


static func _record_telemetry_tap_shot(
	telemetry,
	run_generation: int,
	attempt_id: int,
	cue_strike_count: int,
	target_id_values: Array,
	repeated_contacts: int = 0,
	ambiguous_cue_contacts: int = 0,
	ambiguous_ball_contacts: int = 0
) -> Dictionary:
	var target_ids: Array[int] = []
	for target_value in target_id_values:
		var target_id: int = int(target_value)
		if target_id > 0 and not target_ids.has(target_id):
			target_ids.append(target_id)
	var cue_bonus_count: int = maxi(cue_strike_count - 1, 0)
	var cue_event_indices: Array[int] = []
	var object_event_indices: Array[int] = []
	var occurrences: Array[Dictionary] = []
	var resolution_steps: Array[Dictionary] = []
	var current_mult: float = 1.0
	var step_index: int = 1
	for cue_index in range(cue_bonus_count):
		var event_index: int = 10 + cue_index
		cue_event_indices.append(event_index)
		occurrences.append({
			"trigger_occurrence_id": "tap_test_%d_cue_%d" % [attempt_id, cue_index],
			"trigger_id": CUE_RECONTACT_TRIGGER,
			"ball_id": 2,
			"event_index": event_index,
			"world_position": Vector2(100.0 + cue_index, 100.0),
		})
		resolution_steps.append(_tap_resolution_step(
			step_index,
			"base_cue_recontact",
			"cue_recontact",
			"Double Tap",
			current_mult,
			event_index
		))
		current_mult += 1.0
		step_index += 1
	for target_index in range(target_ids.size()):
		var event_index: int = 100 + target_index
		object_event_indices.append(event_index)
		occurrences.append({
			"trigger_occurrence_id": "tap_test_%d_ball_%d" % [attempt_id, target_index],
			"trigger_id": BALL_TAP_TRIGGER,
			"ball_id": 2,
			"contacted_ball_id": target_ids[target_index],
			"event_index": event_index,
			"world_position": Vector2(200.0 + target_index, 200.0),
		})
		resolution_steps.append(_tap_resolution_step(
			step_index,
			"base_object_ball_tap",
			"object_ball_tap",
			"Ball Tap",
			current_mult,
			event_index
		))
		current_mult += 1.0
		step_index += 1
	var shot_score: int = int(floor(10.0 * current_mult))
	var run_before: Dictionary = _telemetry_run_snapshot(run_generation)
	var run_after: Dictionary = run_before.duplicate(true)
	run_after["shots_left"] = 4
	run_after["round_score"] = shot_score
	var ledger: Dictionary = {
		"source": "authoritative",
		"mode_id": "roguelite",
		"run_generation": run_generation,
		"shot_id": attempt_id,
		"attempt_id": attempt_id,
		"round_number": 1,
		"derived": {
			"object_ball_pocket_count": 1,
			"scratch_occurred": false,
			"pocket_facts": [{
				"ball_id": 2,
				"qualifying_cue_strike_count": cue_strike_count,
				"cue_recontact_bonus_count": cue_bonus_count,
				"cue_recontact_event_indices": cue_event_indices,
				"unique_object_tap_count": target_ids.size(),
				"unique_object_tap_ball_ids": target_ids,
				"object_tap_event_indices": object_event_indices,
				"repeated_object_tap_contact_count": repeated_contacts,
				"ambiguous_cue_contact_count": ambiguous_cue_contacts,
				"ambiguous_object_tap_count": ambiguous_ball_contacts,
				"is_direct_pot": cue_bonus_count <= 0 and target_ids.is_empty(),
			}],
		},
	}
	var score_result: Dictionary = {
		"source": "authoritative",
		"mode_id": "roguelite",
		"run_generation": run_generation,
		"shot_id": attempt_id,
		"attempt_id": attempt_id,
		"shot_transaction_accepted": true,
		"shot_transaction_outcome": "continue",
		"shot_score": shot_score,
		"final_haul": 10,
		"final_mult": current_mult,
		"eight_ball_build_evaluation": {
			"trigger_occurrences": occurrences,
			"add_haul_total": 0,
			"add_mult_total": 0.0,
			"xmult_product": 1.0,
		},
		"resolution_steps": resolution_steps,
		"doubloon_payout": {"doubloons_awarded": 10},
	}
	var base_result: Dictionary = {
		"source": "authoritative",
		"mode_id": "roguelite",
		"run_generation": run_generation,
		"shot_id": attempt_id,
		"attempt_id": attempt_id,
		"shot_score": shot_score,
		"final_haul": 10,
		"final_mult": current_mult,
	}
	return telemetry.record_authoritative_shot(
		ledger,
		score_result,
		base_result,
		run_before,
		run_after,
		{},
		{}
	)


static func _tap_resolution_step(
	step_index: int,
	source_id: String,
	source_type: String,
	display_name: String,
	mult_before: float,
	event_index: int
) -> Dictionary:
	return {
		"step_index": step_index,
		"phase": "base_mult",
		"source_id": source_id,
		"source_type": source_type,
		"display_name": display_name,
		"event_index": event_index,
		"ball_id": 2,
		"haul_before": 10,
		"haul_delta": 0,
		"haul_after": 10,
		"mult_before": mult_before,
		"mult_delta": 1.0,
		"xmult_factor": 1.0,
		"mult_after": mult_before + 1.0,
		"score_preview_after": int(floor(10.0 * (mult_before + 1.0))),
		"affects_score": true,
		"metadata": {},
	}


static func _shot(
	final_score: int,
	base_score: int,
	shot_id: int = 1,
	attempt_id: int = 1,
	round_number: int = 1,
	activations: Array[Dictionary] = [],
	trigger_counts: Dictionary = {},
	owned_item_ids: Array[String] = []
) -> Dictionary:
	return {
		"shot_id": shot_id,
		"attempt_id": attempt_id,
		"source": "authoritative",
		"round_number": round_number,
		"shots_remaining_before": 5,
		"shots_remaining_after": 4,
		"hull_before": 3,
		"hull_after": 3,
		"object_balls_pocketed": maxi(int(floor(float(base_score) / 10.0)), 0),
		"trigger_counts": trigger_counts.duplicate(true),
		"maximum_bank_tier": 0,
		"combination_count": int(trigger_counts.get(COMBINATION_TRIGGER, 0)),
		"base_haul": maxi(base_score, 0),
		"base_mult": 1.0,
		"base_score_without_build": base_score,
		"build_haul_added": 0,
		"build_mult_added": 0.0,
		"build_xmult_product": 1.0,
		"final_haul": maxi(base_score, 0),
		"final_mult": 1.0,
		"final_score": final_score,
		"item_activations": activations.duplicate(true),
		"owned_item_ids": owned_item_ids.duplicate(),
		"scratch": false,
		"terminal_outcome": "continue",
	}


static func _activation(
	item_id: String,
	display_name: String,
	family_id: String,
	phase: String,
	value: Variant,
	trigger_id: String
) -> Dictionary:
	return {
		"eight_ball_item_id": item_id,
		"display_name": display_name,
		"family_id": family_id,
		"phase": phase,
		"modifier_phase": phase,
		"value": value,
		"applied_value": value,
		"trigger_id": trigger_id,
		"trigger_ball_id": 2,
		"trigger_event_index": 5,
		"tray_slot_index": 0,
		"activation_ordinal": 1,
		"activation_id": "%s|original" % item_id,
		"trigger_occurrence_id": "%s|occurrence" % trigger_id,
		"is_retrigger": false,
		"retrigger_index": 0,
		"retrigger_source_item_id": "",
		"original_activation_id": "%s|original" % item_id,
	}


static func _retrigger_activation(original: Dictionary, ordinal: int) -> Dictionary:
	var retrigger: Dictionary = original.duplicate(true)
	var original_activation_id: String = str(original.get("activation_id", ""))
	retrigger["activation_id"] = "%s|retrigger:1" % original_activation_id
	retrigger["is_retrigger"] = true
	retrigger["retrigger_index"] = 1
	retrigger["retrigger_source_item_id"] = DEAD_RECKONING_ID
	retrigger["retrigger_source_slot_index"] = 3
	retrigger["original_activation_id"] = original_activation_id
	retrigger["activation_ordinal"] = ordinal
	return retrigger


static func _offer_item(item_id: String, family_id: String, phase: String) -> Dictionary:
	return {
		"eight_ball_item_id": item_id,
		"display_name": item_id.capitalize(),
		"family_id": family_id,
		"modifier_phase": phase,
		"rarity": "common",
		"offer_weight": 100,
	}


static func _round(round_number: int, quota: int, score: int) -> Dictionary:
	return {
		"round_number": round_number,
		"quota": quota,
		"starting_hull": 3,
		"starting_shots": 5,
		"balls_spawned": 15,
		"round_score": score,
		"shots_used": 1,
		"outcome": "cleared" if score >= quota else "failed",
		"failure_reason": "" if score >= quota else "shots_exhausted",
	}


static func _counterfactual_scores(item_ids: Array[String], scores: Array[int]) -> Dictionary:
	var result: Dictionary = {}
	var count: int = mini(item_ids.size(), scores.size())
	for index in range(count):
		result[item_ids[index]] = scores[index]
	return result


static func _record_case(
	cases: Array[Dictionary],
	name: String,
	passed: bool,
	expected: Dictionary,
	actual: Dictionary
) -> void:
	cases.append({
		"name": name,
		"passed": passed,
		"expected": expected.duplicate(true),
		"actual": actual.duplicate(true),
	})


static func _build_report(cases: Array[Dictionary]) -> Dictionary:
	var passed_count: int = 0
	var failures: Array[Dictionary] = []
	for case_result in cases:
		if bool(case_result.get("passed", false)):
			passed_count += 1
		else:
			failures.append(case_result.duplicate(true))
	return {
		"status": (
			"PASS"
			if failures.is_empty() and cases.size() == TEST_CASE_COUNT
			else "FAIL"
		),
		"timestamp": Time.get_datetime_string_from_system(),
		"total": cases.size(),
		"passed": passed_count,
		"failed": failures.size(),
		"cases": cases.duplicate(true),
		"failures": failures,
	}


static func _item(report: Dictionary, item_id: String) -> Dictionary:
	for item in _items(report):
		if str(item.get("eight_ball_item_id", "")) == item_id:
			return item
	return {}


static func _item_summary(item: Dictionary) -> Dictionary:
	return {
		"eight_ball_item_id": item.get("eight_ball_item_id"),
		"total_haul_added": item.get("total_haul_added"),
		"total_mult_added": item.get("total_mult_added"),
		"cumulative_xmult_factor": item.get("cumulative_xmult_factor"),
		"final_score_uplift": item.get("final_score_uplift"),
	}


static func _items(report: Dictionary) -> Array[Dictionary]:
	return _dict_array(report, "item_metrics")


static func _rounds(report: Dictionary) -> Array[Dictionary]:
	return _dict_array(report, "round_metrics")


static func _trigger_occurrences(families: Dictionary, family_id: String) -> int:
	var value: Variant = families.get(family_id, {})
	return int((value as Dictionary).get("milestone_occurrences", 0)) if value is Dictionary else 0


static func _has_watch_flag(report: Dictionary, flag_id: String) -> bool:
	return _watch_ids(report).has(flag_id)


static func _watch_ids(report: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for flag in _dict_array(report, "watch_flags"):
		ids.append(str(flag.get("id", "")))
	return ids


static func _dict(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _dict_array(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = source.get(key, [])
	if value is Array:
		for entry_value in value as Array:
			if entry_value is Dictionary:
				result.append((entry_value as Dictionary).duplicate(true))
	return result


static func _format_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Roguelite Balance Analyzer Tests: %d/%d passed, %d failed" % [
		int(report.get("passed", 0)),
		int(report.get("total", 0)),
		int(report.get("failed", 0)),
	])
	for case_result in _dict_array(report, "cases"):
		var passed: bool = bool(case_result.get("passed", false))
		lines.append("[%s] %s" % ["PASS" if passed else "FAIL", str(case_result.get("name", "Unnamed"))])
		if not passed:
			lines.append("  Expected: %s" % var_to_str(case_result.get("expected")))
			lines.append("  Actual:   %s" % var_to_str(case_result.get("actual")))
	return "\n".join(lines)
