extends RefCounted
class_name RogueliteBuildEffectEvaluatorTests

const CATALOG := preload("res://scripts/RogueliteEightBallCatalog.gd")
const EVALUATOR := preload("res://scripts/RogueliteBuildEffectEvaluator.gd")
const RESOLVER := preload("res://scripts/RogueliteScoreResolver.gd")

const RATTLE_ID := "tap_stateful_xmult_rattle_of_the_deep"
const ECHO_ID := "tap_legendary_retrigger_echo_chamber"


static func run_self_tests() -> Dictionary:
	var cases: Array[Dictionary] = []
	var one_double: Dictionary = _make_tap_case([
		{"ball_id": 2, "cue_events": [10], "object_taps": []},
	])
	_run_score_case(cases, "Double Tap base", one_double, [], 20)
	_run_score_case(cases, "Second Bite", one_double, [
		"double_tap_haul_second_bite",
	], 40)
	_run_score_case(cases, "Echoing Toll", one_double, [
		"double_tap_mult_echoing_toll",
	], 30)
	_run_score_case(cases, "Revenant Rhythm", one_double, [
		"double_tap_xmult_revenant_rhythm",
	], 25)
	_run_score_case(cases, "Double Tap trio", one_double, [
		"double_tap_haul_second_bite",
		"double_tap_mult_echoing_toll",
		"double_tap_xmult_revenant_rhythm",
	], 75)

	var one_ball_tap: Dictionary = _make_tap_case([
		{"ball_id": 2, "cue_events": [], "object_taps": [{"target": 3, "event": 10}]},
	])
	_run_score_case(cases, "Ball Tap base", one_ball_tap, [], 20)
	_run_score_case(cases, "Knock-On Plunder", one_ball_tap, [
		"ball_tap_haul_knock_on_plunder",
	], 36)
	_run_score_case(cases, "Crowded Wake", one_ball_tap, [
		"ball_tap_mult_crowded_wake",
	], 30)
	_run_score_case(cases, "Carom Current", one_ball_tap, [
		"ball_tap_xmult_carom_current",
	], 24)
	_run_score_case(cases, "Ball Tap trio", one_ball_tap, [
		"ball_tap_haul_knock_on_plunder",
		"ball_tap_mult_crowded_wake",
		"ball_tap_xmult_carom_current",
	], 64)

	_run_rattle_cases(cases, one_double)
	_run_one_two_cases(cases)
	_run_aftershock_cases(cases)
	_run_echo_cases(cases)
	_run_dead_reckoning_isolation_case(cases)

	var failures: Array[Dictionary] = []
	for case_result in cases:
		if not bool(case_result.get("passed", false)):
			failures.append(case_result.duplicate(true))
	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"total": cases.size(),
		"passed": cases.size() - failures.size(),
		"failed": failures.size(),
		"cases": cases,
		"failures": failures,
		"timestamp": Time.get_datetime_string_from_system(),
	}


static func _run_rattle_cases(cases: Array[Dictionary], one_tap: Dictionary) -> void:
	var first: Dictionary = _resolve_case(one_tap, [RATTLE_ID])
	_record(cases, "Rattle first Tap score", int(first.get("shot_score", -1)), 24)
	_record(cases, "Rattle first Tap simulated state", _rattle_value(first), 1.2)
	_record(cases, "Rattle prediction does not return authority mutations", _mutation_count(first), 0)

	var second: Dictionary = _resolve_case(one_tap, [RATTLE_ID], {
		RATTLE_ID: {
			"state_version": 1,
			"current_xmult": 1.2,
			"lifetime_growth_triggers": 1,
			"shots_activated": 1,
		},
	})
	_record(cases, "Rattle second Tap score", int(second.get("shot_score", -1)), 28)
	_record(cases, "Rattle second Tap simulated state", _rattle_value(second), 1.4)

	var three_taps: Dictionary = _make_tap_case([
		{
			"ball_id": 2,
			"cue_events": [10],
			"object_taps": [
				{"target": 3, "event": 20},
				{"target": 4, "event": 30},
			],
		},
	])
	var three_result: Dictionary = _resolve_case(three_taps, [RATTLE_ID])
	_record(cases, "Rattle three-Tap score", int(three_result.get("shot_score", -1)), 64)
	_record(cases, "Rattle three-Tap simulated state", _rattle_value(three_result), 1.6)
	_record(cases, "Rattle emits one xMult modifier", _modifier_count_for_item(three_result, RATTLE_ID), 1)

	var no_tap: Dictionary = _make_tap_case([{"ball_id": 2, "cue_events": [], "object_taps": []}])
	var no_tap_result: Dictionary = _resolve_case(no_tap, [RATTLE_ID], {
		RATTLE_ID: {
			"state_version": 1,
			"current_xmult": 1.6,
			"lifetime_growth_triggers": 3,
			"shots_activated": 1,
		},
	})
	_record(cases, "Rattle non-Tap score unchanged", int(no_tap_result.get("shot_score", -1)), 10)
	_record(cases, "Rattle non-Tap state unchanged", _rattle_value(no_tap_result), 1.6)
	_record(cases, "Rattle non-Tap has no modifier", _modifier_count_for_item(no_tap_result, RATTLE_ID), 0)


static func _run_one_two_cases(cases: Array[Dictionary]) -> void:
	var one_ball: Dictionary = _make_tap_case([{
		"ball_id": 2,
		"cue_events": [10],
		"object_taps": [{"target": 3, "event": 20}],
	}])
	var one_result: Dictionary = _resolve_case(one_ball, ["tap_hybrid_xmult_one_two_punch"])
	_record(cases, "One-Two one qualifying ball score", int(one_result.get("shot_score", -1)), 60)
	_record(cases, "One-Two one qualifying ball activation", _diagnostic_int(
		one_result,
		"one_two_punch_qualifying_ball_count"
	), 1)

	var two_balls: Dictionary = _make_tap_case([
		{"ball_id": 2, "cue_events": [10], "object_taps": [{"target": 4, "event": 20}]},
		{"ball_id": 3, "cue_events": [30], "object_taps": [{"target": 5, "event": 40}]},
	])
	var two_result: Dictionary = _resolve_case(two_balls, ["tap_hybrid_xmult_one_two_punch"])
	_record(cases, "One-Two two qualifying balls activate twice", _modifier_count_for_item(
		two_result,
		"tap_hybrid_xmult_one_two_punch"
	), 2)

	var split_balls: Dictionary = _make_tap_case([
		{"ball_id": 2, "cue_events": [10], "object_taps": []},
		{"ball_id": 3, "cue_events": [], "object_taps": [{"target": 5, "event": 20}]},
	])
	var split_result: Dictionary = _resolve_case(split_balls, ["tap_hybrid_xmult_one_two_punch"])
	_record(cases, "One-Two does not combine different balls", _modifier_count_for_item(
		split_result,
		"tap_hybrid_xmult_one_two_punch"
	), 0)


static func _run_aftershock_cases(cases: Array[Dictionary]) -> void:
	var one_tap: Dictionary = _make_tap_case([
		{"ball_id": 2, "cue_events": [10], "object_taps": []},
	])
	var one_result: Dictionary = _resolve_case(one_tap, ["tap_ordinal_xmult_aftershock"])
	_record(cases, "Aftershock ignores first Tap", _modifier_count_for_item(
		one_result,
		"tap_ordinal_xmult_aftershock"
	), 0)
	_record(cases, "Aftershock one-Tap base score", int(one_result.get("shot_score", -1)), 20)

	var three_taps: Dictionary = _make_tap_case([{
		"ball_id": 2,
		"cue_events": [10],
		"object_taps": [
			{"target": 3, "event": 20},
			{"target": 4, "event": 30},
		],
	}])
	var three_result: Dictionary = _resolve_case(three_taps, ["tap_ordinal_xmult_aftershock"])
	_record(cases, "Aftershock three-Tap score", int(three_result.get("shot_score", -1)), 62)
	_record(cases, "Aftershock three-Tap activations", _modifier_count_for_item(
		three_result,
		"tap_ordinal_xmult_aftershock"
	), 2)

	var four_taps: Dictionary = _make_tap_case([{
		"ball_id": 2,
		"cue_events": [10, 40],
		"object_taps": [
			{"target": 3, "event": 20},
			{"target": 4, "event": 30},
		],
	}])
	var four_result: Dictionary = _resolve_case(four_taps, ["tap_ordinal_xmult_aftershock"])
	_record(cases, "Aftershock four-Tap activations", _modifier_count_for_item(
		four_result,
		"tap_ordinal_xmult_aftershock"
	), 3)


static func _run_echo_cases(cases: Array[Dictionary]) -> void:
	var three_ball_taps: Dictionary = _make_tap_case([{
		"ball_id": 2,
		"cue_events": [],
		"object_taps": [
			{"target": 3, "event": 10},
			{"target": 4, "event": 20},
			{"target": 5, "event": 30},
		],
	}])
	var loadout: Array[String] = [
		"ball_tap_haul_knock_on_plunder",
		"ball_tap_mult_crowded_wake",
		"ball_tap_xmult_carom_current",
		ECHO_ID,
	]
	var result: Dictionary = _resolve_case(three_ball_taps, loadout)
	_record(cases, "Echo Chamber exact three-Tap score", int(result.get("shot_score", -1)), 696)
	_record(cases, "Echo Chamber threshold count", _diagnostic_int(result, "echo_threshold_count"), 1)
	_record(cases, "Echo Chamber retriggers three regular items", _diagnostic_int(
		result,
		"echo_retrigger_activation_count"
	), 3)
	_record(cases, "Echo Chamber does not recurse", _diagnostic_int(
		result,
		"maximum_retrigger_depth"
	), 1)

	var six_mixed: Dictionary = _make_tap_case([{
		"ball_id": 2,
		"cue_events": [10, 20, 30],
		"object_taps": [
			{"target": 3, "event": 40},
			{"target": 4, "event": 50},
			{"target": 5, "event": 60},
		],
	}])
	var six_result: Dictionary = _resolve_case(six_mixed, [
		"double_tap_haul_second_bite",
		"ball_tap_haul_knock_on_plunder",
		ECHO_ID,
	])
	_record(cases, "Echo Chamber thresholds three and six", _diagnostic_int(
		six_result,
		"echo_threshold_count"
	), 2)
	_record(cases, "Echo Chamber thresholds match their own Tap family", _diagnostic_int(
		six_result,
		"echo_retrigger_activation_count"
	), 2)


static func _run_dead_reckoning_isolation_case(cases: Array[Dictionary]) -> void:
	var direct_with_tap: Dictionary = _make_tap_case([{
		"ball_id": 2,
		"cue_events": [10],
		"object_taps": [],
	}])
	var result: Dictionary = _resolve_case(direct_with_tap, [
		"direct_pot_haul_clean_plunder",
		"direct_pot_legendary_dead_reckoning",
		"double_tap_haul_second_bite",
	])
	_record(cases, "Dead Reckoning does not retrigger Tap items", _retrigger_count_for_item(
		result,
		"double_tap_haul_second_bite"
	), 0)
	_record(cases, "Dead Reckoning still retriggers Direct Pot items", _retrigger_count_for_item(
		result,
		"direct_pot_haul_clean_plunder"
	), 1)


static func _run_score_case(
	cases: Array[Dictionary],
	name: String,
	test_case: Dictionary,
	item_ids: Array[String],
	expected_score: int
) -> void:
	var result: Dictionary = _resolve_case(test_case, item_ids)
	_record(cases, name, int(result.get("shot_score", -1)), expected_score)


static func _resolve_case(
	test_case: Dictionary,
	item_ids: Array[String],
	state_by_item: Dictionary = {}
) -> Dictionary:
	var build_snapshot: Dictionary = _make_build_snapshot(item_ids, state_by_item)
	var occurrences: Array[Dictionary] = _dictionary_array(test_case, "occurrences")
	var evaluation: Dictionary = EVALUATOR.evaluate(
		_dictionary_value(test_case, "ledger"),
		occurrences,
		build_snapshot,
		EVALUATOR.SOURCE_PREDICTED
	)
	var resolved: Dictionary = RESOLVER.resolve(
		_dictionary_value(test_case, "ledger"),
		_array_value(evaluation, "modifier_context")
	)
	resolved["eight_ball_build_evaluation"] = evaluation.duplicate(true)
	return resolved


static func _make_build_snapshot(
	item_ids: Array[String],
	state_by_item: Dictionary
) -> Dictionary:
	var slots: Array[Dictionary] = []
	for slot_index in range(5):
		if slot_index >= item_ids.size():
			slots.append({
				"tray_slot_index": slot_index,
				"occupied": false,
				"eight_ball_item_id": "",
			})
			continue
		var item_id: String = item_ids[slot_index]
		var definition: Dictionary = CATALOG.get_definition(item_id)
		var state: Dictionary = {}
		var state_value: Variant = state_by_item.get(item_id, definition.get("initial_state", {}))
		if state_value is Dictionary:
			state = (state_value as Dictionary).duplicate(true)
		slots.append({
			"tray_slot_index": slot_index,
			"occupied": true,
			"eight_ball_item_id": item_id,
			"owned_item_instance_id": slot_index + 1,
			"acquired_round": 1,
			"state": state,
			"definition": definition,
		})
	return {
		"build_generation": 1,
		"build_version": 1,
		"slots": slots,
	}


static func _make_tap_case(specs: Array[Dictionary]) -> Dictionary:
	var facts: Array[Dictionary] = []
	var cue_milestones: Array[Dictionary] = []
	var object_milestones: Array[Dictionary] = []
	var occurrences: Array[Dictionary] = []
	for spec_index in range(specs.size()):
		var spec: Dictionary = specs[spec_index]
		var ball_id: int = int(spec.get("ball_id", spec_index + 2))
		var cue_events: Array = spec.get("cue_events", []) as Array
		var object_taps: Array = spec.get("object_taps", []) as Array
		var fact: Dictionary = {
			"ball_id": ball_id,
			"ball_number": ball_id,
			"pocket_order": spec_index + 1,
			"pocket_event_index": 100 + spec_index,
			"pocket_index": 0,
			"causal_depth": 1,
			"bank_count": 0,
			"is_combination_pot": false,
			"qualifying_cue_strike_count": cue_events.size() + 1,
			"cue_recontact_bonus_count": cue_events.size(),
			"cue_recontact_event_indices": cue_events.duplicate(),
			"cue_recontact_positions": [],
			"cue_recontact_milestones": [],
			"unique_object_tap_count": object_taps.size(),
			"unique_object_tap_ball_ids": [],
			"object_tap_event_indices": [],
			"object_tap_positions": [],
			"object_ball_tap_milestones": [],
			"repeated_object_tap_contact_count": 0,
		}
		for cue_index in range(cue_events.size()):
			var event_index: int = int(cue_events[cue_index])
			var occurrence_id: String = "cue:%d:%d" % [ball_id, event_index]
			var milestone: Dictionary = {
				"trigger_occurrence_id": occurrence_id,
				"trigger_id": "cue_recontact_milestone",
				"ball_id": ball_id,
				"event_index": event_index,
				"world_position": Vector2(float(event_index), float(ball_id)),
				"cue_strike_ordinal": cue_index + 2,
				"bonus_ordinal": cue_index + 1,
				"metadata": {},
			}
			cue_milestones.append(milestone)
			(fact["cue_recontact_milestones"] as Array).append(milestone.duplicate(true))
			(fact["cue_recontact_positions"] as Array).append(milestone["world_position"])
			occurrences.append(_occurrence_from_milestone(milestone))
		for tap_index in range(object_taps.size()):
			var tap: Dictionary = object_taps[tap_index] as Dictionary
			var target_id: int = int(tap.get("target", -1))
			var event_index: int = int(tap.get("event", -1))
			var occurrence_id: String = "object:%d:%d:%d" % [ball_id, target_id, event_index]
			var milestone: Dictionary = {
				"trigger_occurrence_id": occurrence_id,
				"trigger_id": "object_ball_tap_milestone",
				"ball_id": ball_id,
				"contacted_ball_id": target_id,
				"event_index": event_index,
				"world_position": Vector2(float(event_index), float(ball_id)),
				"unique_contact_ordinal": tap_index + 1,
				"metadata": {},
			}
			object_milestones.append(milestone)
			(fact["object_ball_tap_milestones"] as Array).append(milestone.duplicate(true))
			(fact["unique_object_tap_ball_ids"] as Array).append(target_id)
			(fact["object_tap_event_indices"] as Array).append(event_index)
			(fact["object_tap_positions"] as Array).append(milestone["world_position"])
			occurrences.append(_occurrence_from_milestone(milestone))
		occurrences.append({
			"trigger_occurrence_id": "direct:%d:%d" % [
				ball_id,
				int(fact["pocket_event_index"]),
			],
			"trigger_id": "direct_pot",
			"ball_id": ball_id,
			"trigger_ball_id": ball_id,
			"event_index": int(fact["pocket_event_index"]),
			"trigger_event_index": int(fact["pocket_event_index"]),
			"world_position": Vector2.ZERO,
			"metadata": {},
		})
		facts.append(fact)
	occurrences.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var event_a: int = int(a.get("event_index", -1))
		var event_b: int = int(b.get("event_index", -1))
		if event_a != event_b:
			return event_a < event_b
		return str(a.get("trigger_occurrence_id", "")) < str(b.get("trigger_occurrence_id", ""))
	)
	var object_ids: Array[int] = []
	for fact in facts:
		object_ids.append(int(fact.get("ball_id", -1)))
	return {
		"ledger": {
			"schema_version": 1,
			"source": "phase_5c_self_test",
			"mode_id": "shot_lab",
			"run_generation": 1,
			"shot_id": 1,
			"attempt_id": 1,
			"cue_ball_id": 1,
			"derived": {
				"schema_version": 2,
				"object_ball_pocket_count": facts.size(),
				"object_balls_pocketed": object_ids,
				"pocket_facts": facts,
				"cue_recontact_milestones": cue_milestones,
				"cue_recontact_milestone_count": cue_milestones.size(),
				"object_ball_tap_milestones": object_milestones,
				"object_ball_tap_milestone_count": object_milestones.size(),
				"scratch_occurred": false,
				"cue_ball_pocket_event_index": -1,
			},
		},
		"occurrences": occurrences,
	}


static func _occurrence_from_milestone(milestone: Dictionary) -> Dictionary:
	var metadata_value: Variant = milestone.get("metadata", {})
	var metadata: Dictionary = (
		(metadata_value as Dictionary).duplicate(true)
		if metadata_value is Dictionary
		else {}
	)
	return {
		"trigger_occurrence_id": str(milestone.get("trigger_occurrence_id", "")),
		"trigger_id": str(milestone.get("trigger_id", "")),
		"ball_id": int(milestone.get("ball_id", -1)),
		"trigger_ball_id": int(milestone.get("ball_id", -1)),
		"event_index": int(milestone.get("event_index", -1)),
		"trigger_event_index": int(milestone.get("event_index", -1)),
		"world_position": milestone.get("world_position", Vector2.ZERO),
		"metadata": metadata,
	}


static func _rattle_value(result: Dictionary) -> float:
	var evaluation: Dictionary = _dictionary_value(result, "eight_ball_build_evaluation")
	var states: Dictionary = _dictionary_value(evaluation, "simulated_state_after")
	var state: Dictionary = _dictionary_value(states, "1")
	return float(state.get("current_xmult", -1.0))


static func _mutation_count(result: Dictionary) -> int:
	var evaluation: Dictionary = _dictionary_value(result, "eight_ball_build_evaluation")
	return _array_value(evaluation, "authoritative_state_mutations").size()


static func _modifier_count_for_item(result: Dictionary, item_id: String) -> int:
	var evaluation: Dictionary = _dictionary_value(result, "eight_ball_build_evaluation")
	var count: int = 0
	for modifier in _array_value(evaluation, "modifier_context"):
		if str(modifier.get("eight_ball_item_id", "")) == item_id:
			count += 1
	return count


static func _retrigger_count_for_item(result: Dictionary, item_id: String) -> int:
	var evaluation: Dictionary = _dictionary_value(result, "eight_ball_build_evaluation")
	var count: int = 0
	for modifier in _array_value(evaluation, "modifier_context"):
		if (
			str(modifier.get("eight_ball_item_id", "")) == item_id
			and bool(modifier.get("is_retrigger", false))
		):
			count += 1
	return count


static func _diagnostic_int(result: Dictionary, key: String) -> int:
	var evaluation: Dictionary = _dictionary_value(result, "eight_ball_build_evaluation")
	var diagnostics: Dictionary = _dictionary_value(evaluation, "diagnostics")
	return int(diagnostics.get(key, 0))


static func _record(
	cases: Array[Dictionary],
	name: String,
	actual: Variant,
	expected: Variant
) -> void:
	var passed: bool
	if typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT:
		passed = is_equal_approx(float(actual), float(expected))
	else:
		passed = actual == expected
	cases.append({
		"name": name,
		"passed": passed,
		"expected": expected,
		"actual": actual,
	})


static func _dictionary_value(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func _array_value(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value as Array if value is Array else []


static func _dictionary_array(source: Dictionary, key: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for value in _array_value(source, key):
		if value is Dictionary:
			output.append((value as Dictionary).duplicate(true))
	return output
