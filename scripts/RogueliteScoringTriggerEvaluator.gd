extends RefCounted
class_name RogueliteScoringTriggerEvaluator

# Pure semantic trigger extraction shared by predicted and authoritative ledgers.
# Build-item identities are never represented as physical scoring-ball identities.

const SCHEMA_VERSION := 3
const SELF_TEST_CASE_COUNT := 5

const TRIGGER_SINGLE_BANK := "single_bank_milestone"
const TRIGGER_DOUBLE_BANK := "double_bank_milestone"
const TRIGGER_TRIPLE_BANK := "triple_bank_milestone"
const TRIGGER_COMBINATION := "combination_pot"
const TRIGGER_DIRECT_POT := "direct_pot"
const TRIGGER_MULTI_POT := "multi_pot_shot"
const TRIGGER_SAME_POCKET_STREAK := "same_pocket_streak"
const TRIGGER_CUE_RECONTACT := "cue_recontact_milestone"
const TRIGGER_OBJECT_BALL_TAP := "object_ball_tap_milestone"

const BANK_TRIGGER_IDS: Array[String] = [
	TRIGGER_SINGLE_BANK,
	TRIGGER_DOUBLE_BANK,
	TRIGGER_TRIPLE_BANK,
]
const TRIGGER_SORT_ORDER: Dictionary = {
	TRIGGER_COMBINATION: 0,
	TRIGGER_SINGLE_BANK: 1,
	TRIGGER_DOUBLE_BANK: 2,
	TRIGGER_TRIPLE_BANK: 3,
	TRIGGER_DIRECT_POT: 4,
	TRIGGER_MULTI_POT: 5,
	TRIGGER_SAME_POCKET_STREAK: 6,
	TRIGGER_CUE_RECONTACT: 7,
	TRIGGER_OBJECT_BALL_TAP: 8,
}
const TRIGGER_ID_SUFFIX: Dictionary = {
	TRIGGER_SINGLE_BANK: "single_bank",
	TRIGGER_DOUBLE_BANK: "double_bank",
	TRIGGER_TRIPLE_BANK: "triple_bank",
	TRIGGER_COMBINATION: "combination",
	TRIGGER_DIRECT_POT: "direct_pot",
	TRIGGER_MULTI_POT: "multi_pot",
	TRIGGER_SAME_POCKET_STREAK: "same_pocket",
	TRIGGER_CUE_RECONTACT: "cue_recontact",
	TRIGGER_OBJECT_BALL_TAP: "object_ball_tap",
}


static func evaluate(analyzed_ledger: Dictionary) -> Array[Dictionary]:
	var evaluation: Dictionary = evaluate_with_diagnostics(analyzed_ledger)
	var occurrences_value: Variant = evaluation.get("occurrences", [])
	var occurrences: Array[Dictionary] = []
	if not occurrences_value is Array:
		return occurrences
	for occurrence_value in occurrences_value:
		if occurrence_value is Dictionary:
			occurrences.append((occurrence_value as Dictionary).duplicate(true))
	return occurrences


static func evaluate_trigger_occurrences(analyzed_ledger: Dictionary) -> Array[Dictionary]:
	return evaluate(analyzed_ledger)


static func evaluate_with_diagnostics(analyzed_ledger: Dictionary) -> Dictionary:
	var occurrences: Array[Dictionary] = []
	var trigger_counts: Dictionary = _empty_trigger_counts()
	var diagnostics: Dictionary = {
		"input_complete": false,
		"pocket_facts_received": 0,
		"pocket_facts_evaluated": 0,
		"invalid_scoring_ball_facts": 0,
		"bank_milestones_emitted": 0,
		"combination_occurrences_emitted": 0,
		"direct_pot_occurrences_emitted": 0,
		"multi_pot_occurrences_emitted": 0,
		"same_pocket_occurrences_emitted": 0,
		"cue_recontact_occurrences_emitted": 0,
		"object_ball_tap_occurrences_emitted": 0,
		"malformed_cue_recontact_facts": 0,
		"malformed_object_ball_tap_facts": 0,
		"invalid_pocket_indices": 0,
		"missing_exact_bank_event_indices": 0,
		"missing_world_positions": 0,
		"duplicate_occurrence_ids": 0,
	}
	var derived: Dictionary = _get_derived(analyzed_ledger)
	var raw_events: Array = _array_value(analyzed_ledger, "raw_events")
	var event_by_index: Dictionary = _build_event_index(raw_events)
	var pocket_facts: Array[Dictionary] = _get_sorted_pocket_facts(derived)
	var cue_recontact_milestones_by_ball: Dictionary = _group_semantic_milestones_by_ball(
		_array_value(derived, "cue_recontact_milestones")
	)
	var object_ball_tap_milestones_by_ball: Dictionary = _group_semantic_milestones_by_ball(
		_array_value(derived, "object_ball_tap_milestones")
	)
	var has_canonical_cue_recontact_milestones: bool = (
		derived.get("cue_recontact_milestones", null) is Array
	)
	var has_canonical_object_ball_tap_milestones: bool = (
		derived.get("object_ball_tap_milestones", null) is Array
	)
	diagnostics["canonical_cue_recontact_milestone_count"] = _count_grouped_milestones(
		cue_recontact_milestones_by_ball
	)
	diagnostics["canonical_object_ball_tap_milestone_count"] = _count_grouped_milestones(
		object_ball_tap_milestones_by_ball
	)
	diagnostics["pocket_facts_received"] = _array_value(derived, "pocket_facts").size()
	diagnostics["input_complete"] = (
		not derived.is_empty()
		and derived.has("pocket_facts")
		and analyzed_ledger.has("raw_events")
	)

	var occurrence_ids: Dictionary = {}
	var valid_pocket_facts: Array[Dictionary] = []
	for fact in pocket_facts:
		var scoring_ball_id: int = int(fact.get("ball_id", -1))
		var pocket_order: int = int(fact.get("pocket_order", -1))
		if scoring_ball_id <= 0 or pocket_order <= 0:
			diagnostics["invalid_scoring_ball_facts"] = int(
				diagnostics["invalid_scoring_ball_facts"]
			) + 1
			continue
		valid_pocket_facts.append(fact)
		diagnostics["pocket_facts_evaluated"] = int(diagnostics["pocket_facts_evaluated"]) + 1
		_append_bank_milestones(
			analyzed_ledger,
			fact,
			event_by_index,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)
		_append_direct_pot_occurrence(
			analyzed_ledger,
			fact,
			event_by_index,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)
		_append_combination_occurrence(
			analyzed_ledger,
			fact,
			event_by_index,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)
		_append_cue_recontact_occurrences(
			analyzed_ledger,
			fact,
			_get_grouped_milestones_for_ball(
				cue_recontact_milestones_by_ball,
				scoring_ball_id
			),
			has_canonical_cue_recontact_milestones,
			event_by_index,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)
		_append_object_ball_tap_occurrences(
			analyzed_ledger,
			fact,
			_get_grouped_milestones_for_ball(
				object_ball_tap_milestones_by_ball,
				scoring_ball_id
			),
			has_canonical_object_ball_tap_milestones,
			event_by_index,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)

	_append_multi_pot_occurrence(
		analyzed_ledger,
		valid_pocket_facts,
		event_by_index,
		occurrences,
		occurrence_ids,
		trigger_counts,
		diagnostics
	)
	_append_same_pocket_occurrences(
		analyzed_ledger,
		valid_pocket_facts,
		event_by_index,
		occurrences,
		occurrence_ids,
		trigger_counts,
		diagnostics
	)

	occurrences.sort_custom(_occurrence_precedes)
	return {
		"schema_version": SCHEMA_VERSION,
		"source_ledger_schema_version": int(analyzed_ledger.get("schema_version", -1)),
		"source": str(analyzed_ledger.get("source", "")),
		"run_generation": int(analyzed_ledger.get("run_generation", -1)),
		"shot_id": int(analyzed_ledger.get("shot_id", -1)),
		"attempt_id": int(analyzed_ledger.get("attempt_id", -1)),
		"occurrences": occurrences.duplicate(true),
		"trigger_counts": trigger_counts.duplicate(true),
		"diagnostics": diagnostics.duplicate(true),
	}


static func get_supported_trigger_ids() -> Array[String]:
	return [
		TRIGGER_SINGLE_BANK,
		TRIGGER_DOUBLE_BANK,
		TRIGGER_TRIPLE_BANK,
		TRIGGER_COMBINATION,
		TRIGGER_DIRECT_POT,
		TRIGGER_MULTI_POT,
		TRIGGER_SAME_POCKET_STREAK,
		TRIGGER_CUE_RECONTACT,
		TRIGGER_OBJECT_BALL_TAP,
	]


static func run_self_tests() -> Dictionary:
	var cases: Array[Dictionary] = []

	var cue_fact: Dictionary = _test_pocket_fact()
	cue_fact["qualifying_cue_strike_count"] = 3
	cue_fact["cue_recontact_bonus_count"] = 2
	cue_fact["cue_recontact_event_indices"] = [4, 6]
	cue_fact["cue_recontact_positions"] = [Vector2(40.0, 4.0), Vector2(60.0, 6.0)]
	var cue_evaluation: Dictionary = evaluate_with_diagnostics(_test_analyzed_ledger(cue_fact))
	var cue_occurrences: Array[Dictionary] = _test_occurrences_for_trigger(
		cue_evaluation,
		TRIGGER_CUE_RECONTACT
	)
	_append_test_case(cases, "Cue Recontact Milestones", (
		cue_occurrences.size() == 2
		and int(cue_occurrences[0].get("event_index", -1)) == 4
		and str(cue_occurrences[0].get("trigger_occurrence_id", "")) == (
			"cue_recontact_milestone:7:4:2"
		)
		and int(cue_occurrences[0].get("cue_strike_ordinal", -1)) == 2
		and str(cue_occurrences[0].get("display_tier", "")) == "double_tap"
		and int(cue_occurrences[1].get("event_index", -1)) == 6
		and str(cue_occurrences[1].get("trigger_occurrence_id", "")) == (
			"cue_recontact_milestone:7:6:3"
		)
		and int(cue_occurrences[1].get("cue_strike_ordinal", -1)) == 3
		and str(cue_occurrences[1].get("display_tier", "")) == "triple_tap"
	), {"count": 2, "event_indices": [4, 6]}, {
		"count": cue_occurrences.size(),
		"event_indices": _test_occurrence_event_indices(cue_occurrences),
	})

	var tap_fact: Dictionary = _test_pocket_fact()
	tap_fact["unique_object_tap_count"] = 2
	tap_fact["unique_object_tap_ball_ids"] = [11, 12]
	tap_fact["object_tap_event_indices"] = [5, 7]
	tap_fact["object_tap_positions"] = [Vector2(50.0, 5.0), Vector2(70.0, 7.0)]
	var tap_evaluation: Dictionary = evaluate_with_diagnostics(_test_analyzed_ledger(tap_fact))
	var tap_occurrences: Array[Dictionary] = _test_occurrences_for_trigger(
		tap_evaluation,
		TRIGGER_OBJECT_BALL_TAP
	)
	_append_test_case(cases, "Unique Object Tap Milestones", (
		tap_occurrences.size() == 2
		and int(tap_occurrences[0].get("contacted_ball_id", -1)) == 11
		and str(tap_occurrences[0].get("trigger_occurrence_id", "")) == (
			"object_ball_tap_milestone:7:11:5"
		)
		and int(tap_occurrences[0].get("unique_contact_ordinal", -1)) == 1
		and int(tap_occurrences[1].get("contacted_ball_id", -1)) == 12
		and str(tap_occurrences[1].get("trigger_occurrence_id", "")) == (
			"object_ball_tap_milestone:7:12:7"
		)
		and int(tap_occurrences[1].get("unique_contact_ordinal", -1)) == 2
	), {"target_ids": [11, 12]}, {
		"target_ids": _test_occurrence_target_ids(tap_occurrences),
	})

	var cue_direct_fact: Dictionary = _test_pocket_fact(true)
	cue_direct_fact["qualifying_cue_strike_count"] = 2
	cue_direct_fact["cue_recontact_bonus_count"] = 1
	cue_direct_fact["cue_recontact_event_indices"] = [4]
	cue_direct_fact["cue_recontact_positions"] = [Vector2(40.0, 4.0)]
	var cue_direct_evaluation: Dictionary = evaluate_with_diagnostics(
		_test_analyzed_ledger(cue_direct_fact)
	)
	_append_test_case(cases, "Double Tap Silences Direct Pot", (
		_test_trigger_count(cue_direct_evaluation, TRIGGER_DIRECT_POT) == 0
		and _test_trigger_count(cue_direct_evaluation, TRIGGER_CUE_RECONTACT) == 1
	), {"direct_pot": 0, "cue_recontact": 1}, {
		"direct_pot": _test_trigger_count(cue_direct_evaluation, TRIGGER_DIRECT_POT),
		"cue_recontact": _test_trigger_count(cue_direct_evaluation, TRIGGER_CUE_RECONTACT),
	})

	var tap_direct_fact: Dictionary = _test_pocket_fact(true)
	tap_direct_fact["unique_object_tap_count"] = 1
	tap_direct_fact["unique_object_tap_ball_ids"] = [11]
	tap_direct_fact["object_tap_event_indices"] = [5]
	tap_direct_fact["object_tap_positions"] = [Vector2(50.0, 5.0)]
	var tap_direct_evaluation: Dictionary = evaluate_with_diagnostics(
		_test_analyzed_ledger(tap_direct_fact)
	)
	_append_test_case(cases, "Ball Tap Silences Direct Pot", (
		_test_trigger_count(tap_direct_evaluation, TRIGGER_DIRECT_POT) == 0
		and _test_trigger_count(tap_direct_evaluation, TRIGGER_OBJECT_BALL_TAP) == 1
	), {"direct_pot": 0, "object_ball_tap": 1}, {
		"direct_pot": _test_trigger_count(tap_direct_evaluation, TRIGGER_DIRECT_POT),
		"object_ball_tap": _test_trigger_count(
			tap_direct_evaluation,
			TRIGGER_OBJECT_BALL_TAP
		),
	})

	var clean_direct_fact: Dictionary = _test_pocket_fact(true)
	clean_direct_fact["qualifying_cue_strike_count"] = 1
	var clean_direct_evaluation: Dictionary = evaluate_with_diagnostics(
		_test_analyzed_ledger(clean_direct_fact)
	)
	var repeated_clean_evaluation: Dictionary = evaluate_with_diagnostics(
		_test_analyzed_ledger(clean_direct_fact)
	)
	_append_test_case(cases, "Clean Direct Pot Remains Deterministic", (
		_test_trigger_count(clean_direct_evaluation, TRIGGER_DIRECT_POT) == 1
		and _array_value(clean_direct_evaluation, "occurrences") == _array_value(
			repeated_clean_evaluation,
			"occurrences"
		)
	), {"direct_pot": 1, "deterministic": true}, {
		"direct_pot": _test_trigger_count(clean_direct_evaluation, TRIGGER_DIRECT_POT),
		"deterministic": _array_value(clean_direct_evaluation, "occurrences") == _array_value(
			repeated_clean_evaluation,
			"occurrences"
		),
	})

	var failures: Array[Dictionary] = []
	for case_result in cases:
		if not bool(case_result.get("passed", false)):
			failures.append(case_result.duplicate(true))
	return {
		"status": "PASS" if failures.is_empty() and cases.size() == SELF_TEST_CASE_COUNT else "FAIL",
		"timestamp": Time.get_datetime_string_from_system(),
		"total": cases.size(),
		"passed": cases.size() - failures.size(),
		"failed": failures.size(),
		"cases": cases,
		"failures": failures,
	}


static func _append_bank_milestones(
	analyzed_ledger: Dictionary,
	fact: Dictionary,
	event_by_index: Dictionary,
	occurrences: Array[Dictionary],
	occurrence_ids: Dictionary,
	trigger_counts: Dictionary,
	diagnostics: Dictionary
) -> void:
	var bank_count: int = maxi(int(fact.get("bank_count", 0)), 0)
	var qualifying_indices: Array[int] = _sorted_unique_nonnegative_ints(
		_array_value(fact, "qualifying_rail_event_indices")
	)
	var supported_milestone_count: int = mini(bank_count, BANK_TRIGGER_IDS.size())
	var exact_milestone_count: int = mini(supported_milestone_count, qualifying_indices.size())
	if exact_milestone_count < supported_milestone_count:
		diagnostics["missing_exact_bank_event_indices"] = int(
			diagnostics["missing_exact_bank_event_indices"]
		) + supported_milestone_count - exact_milestone_count

	for milestone_index in range(exact_milestone_count):
		var milestone_tier: int = milestone_index + 1
		var trigger_id: String = BANK_TRIGGER_IDS[milestone_index]
		var event_index: int = qualifying_indices[milestone_index]
		var position_result: Dictionary = _get_event_world_position(event_by_index, event_index)
		if not bool(position_result.get("available", false)):
			diagnostics["missing_world_positions"] = int(diagnostics["missing_world_positions"]) + 1
		var occurrence: Dictionary = _make_occurrence(
			analyzed_ledger,
			fact,
			trigger_id,
			event_index,
			position_result.get("position", Vector2.ZERO),
			milestone_tier,
			{
				"bank_count": bank_count,
				"rail_ordinal": milestone_tier,
				"qualifying_rail_event_index": event_index,
				"pocket_event_index": int(fact.get("pocket_event_index", -1)),
				"world_position_available": bool(position_result.get("available", false)),
			}
		)
		_append_unique_occurrence(
			occurrence,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)
		diagnostics["bank_milestones_emitted"] = int(diagnostics["bank_milestones_emitted"]) + 1


static func _append_combination_occurrence(
	analyzed_ledger: Dictionary,
	fact: Dictionary,
	event_by_index: Dictionary,
	occurrences: Array[Dictionary],
	occurrence_ids: Dictionary,
	trigger_counts: Dictionary,
	diagnostics: Dictionary
) -> void:
	if not bool(fact.get("is_combination_pot", false)):
		return
	var event_index: int = int(fact.get("causal_activation_event_index", -1))
	if event_index < 0:
		return
	var position_result: Dictionary = _get_event_world_position(event_by_index, event_index)
	if not bool(position_result.get("available", false)):
		diagnostics["missing_world_positions"] = int(diagnostics["missing_world_positions"]) + 1
	var occurrence: Dictionary = _make_occurrence(
		analyzed_ledger,
		fact,
		TRIGGER_COMBINATION,
		event_index,
		position_result.get("position", Vector2.ZERO),
		0,
		{
			"causal_activation_event_index": event_index,
			"causal_parent_ball_id": int(fact.get("causal_parent_ball_id", -1)),
			"causal_depth": int(fact.get("causal_depth", -1)),
			"pocket_event_index": int(fact.get("pocket_event_index", -1)),
			"world_position_available": bool(position_result.get("available", false)),
		}
	)
	_append_unique_occurrence(
		occurrence,
		occurrences,
		occurrence_ids,
		trigger_counts,
		diagnostics
	)
	diagnostics["combination_occurrences_emitted"] = int(
		diagnostics["combination_occurrences_emitted"]
	) + 1


static func _append_direct_pot_occurrence(
	analyzed_ledger: Dictionary,
	fact: Dictionary,
	event_by_index: Dictionary,
	occurrences: Array[Dictionary],
	occurrence_ids: Dictionary,
	trigger_counts: Dictionary,
	diagnostics: Dictionary
) -> void:
	if not bool(fact.get("is_direct_pot", false)):
		return
	if bool(fact.get("is_combination_pot", false)):
		return
	if int(fact.get("causal_depth", -1)) != 1:
		return
	if fact.has("is_depth1_zero_rail_pot") and not bool(
		fact.get("is_depth1_zero_rail_pot", false)
	):
		return
	if (
		fact.has("qualifying_cue_strike_count")
		and int(fact.get("qualifying_cue_strike_count", 0)) != 1
	):
		return
	if maxi(
		maxi(
			int(fact.get("cue_recontact_bonus_count", 0)),
			_array_value(fact, "cue_recontact_event_indices").size()
		),
		_array_value(fact, "cue_recontact_milestones").size()
	) > 0:
		return
	if maxi(
		maxi(
			int(fact.get("unique_object_tap_count", 0)),
			_array_value(fact, "unique_object_tap_ball_ids").size()
		),
		_array_value(fact, "object_ball_tap_milestones").size()
	) > 0:
		return
	var qualifying_indices: Array[int] = _sorted_unique_nonnegative_ints(
		_array_value(fact, "qualifying_rail_event_indices")
	)
	var qualifying_rail_count: int = maxi(
		maxi(int(fact.get("bank_count", 0)), int(fact.get("rail_contacts_after_activation", 0))),
		qualifying_indices.size()
	)
	if qualifying_rail_count != 0:
		return
	var event_index: int = int(fact.get("pocket_event_index", -1))
	if event_index < 0:
		return
	var position_result: Dictionary = _get_event_world_position(event_by_index, event_index)
	if not bool(position_result.get("available", false)):
		diagnostics["missing_world_positions"] = int(diagnostics["missing_world_positions"]) + 1
	var occurrence: Dictionary = _make_occurrence(
		analyzed_ledger,
		fact,
		TRIGGER_DIRECT_POT,
		event_index,
		position_result.get("position", Vector2.ZERO),
		0,
		{
			"pocket_event_index": event_index,
			"pocket_index": int(fact.get("pocket_index", -1)),
			"pocket_order": int(fact.get("pocket_order", -1)),
			"causal_depth": 1,
			"is_direct_pot": true,
			"is_combination_pot": false,
			"qualifying_rail_contact_count": qualifying_rail_count,
			"qualifying_rail_event_indices": qualifying_indices.duplicate(),
			"pocket_world_position": position_result.get("position", Vector2.ZERO),
			"world_position_available": bool(position_result.get("available", false)),
		}
	)
	_append_unique_occurrence(
		occurrence,
		occurrences,
		occurrence_ids,
		trigger_counts,
		diagnostics
	)
	diagnostics["direct_pot_occurrences_emitted"] = int(
		diagnostics["direct_pot_occurrences_emitted"]
	) + 1


static func _append_cue_recontact_occurrences(
	analyzed_ledger: Dictionary,
	fact: Dictionary,
	canonical_milestones: Array[Dictionary],
	has_canonical_milestones: bool,
	event_by_index: Dictionary,
	occurrences: Array[Dictionary],
	occurrence_ids: Dictionary,
	trigger_counts: Dictionary,
	diagnostics: Dictionary
) -> void:
	var analyzer_milestones: Array[Dictionary] = canonical_milestones.duplicate(true)
	if not has_canonical_milestones:
		analyzer_milestones = _make_legacy_cue_recontact_milestones(fact)
	var declared_count: int = maxi(int(fact.get("cue_recontact_bonus_count", 0)), 0)
	if declared_count != analyzer_milestones.size():
		diagnostics["malformed_cue_recontact_facts"] = int(
			diagnostics["malformed_cue_recontact_facts"]
		) + 1
	var qualifying_strike_count: int = maxi(int(fact.get(
		"qualifying_cue_strike_count",
		analyzer_milestones.size() + 1
	)), 0)
	for milestone_index in range(analyzer_milestones.size()):
		var analyzer_milestone: Dictionary = analyzer_milestones[milestone_index]
		var event_index: int = int(analyzer_milestone.get("event_index", -1))
		if event_index < 0:
			diagnostics["malformed_cue_recontact_facts"] = int(
				diagnostics["malformed_cue_recontact_facts"]
			) + 1
			continue
		var bonus_ordinal: int = maxi(int(analyzer_milestone.get(
			"bonus_ordinal",
			milestone_index + 1
		)), 1)
		var cue_strike_ordinal: int = maxi(int(analyzer_milestone.get(
			"cue_strike_ordinal",
			bonus_ordinal + 1
		)), 2)
		var position_result: Dictionary = _get_milestone_world_position(
			analyzer_milestone,
			event_by_index,
			event_index
		)
		if not bool(position_result.get("available", false)):
			diagnostics["missing_world_positions"] = int(
				diagnostics["missing_world_positions"]
			) + 1
		var occurrence_metadata: Dictionary = _dictionary_value(
			analyzer_milestone,
			"metadata"
		).duplicate(true)
		occurrence_metadata.merge({
			"contacted_ball_id": int(analyzed_ledger.get("cue_ball_id", -1)),
			"qualifying_cue_strike_count": qualifying_strike_count,
			"cue_strike_ordinal": cue_strike_ordinal,
			"bonus_ordinal": bonus_ordinal,
			"display_tier": _cue_recontact_display_tier(cue_strike_ordinal),
			"pocket_event_index": int(fact.get("pocket_event_index", -1)),
			"world_position_available": bool(position_result.get("available", false)),
		}, true)
		var occurrence: Dictionary = _make_occurrence(
			analyzed_ledger,
			fact,
			TRIGGER_CUE_RECONTACT,
			event_index,
			position_result.get("position", Vector2.ZERO),
			cue_strike_ordinal,
			occurrence_metadata
		)
		occurrence["trigger_occurrence_id"] = str(analyzer_milestone.get(
			"trigger_occurrence_id",
			_make_milestone_occurrence_id(
				analyzed_ledger,
				int(fact.get("ball_id", -1)),
				TRIGGER_CUE_RECONTACT,
				bonus_ordinal
			)
		))
		occurrence["cue_strike_ordinal"] = cue_strike_ordinal
		occurrence["bonus_ordinal"] = bonus_ordinal
		occurrence["display_tier"] = _cue_recontact_display_tier(cue_strike_ordinal)
		_append_unique_occurrence(
			occurrence,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)
		diagnostics["cue_recontact_occurrences_emitted"] = int(
			diagnostics["cue_recontact_occurrences_emitted"]
		) + 1


static func _append_object_ball_tap_occurrences(
	analyzed_ledger: Dictionary,
	fact: Dictionary,
	canonical_milestones: Array[Dictionary],
	has_canonical_milestones: bool,
	event_by_index: Dictionary,
	occurrences: Array[Dictionary],
	occurrence_ids: Dictionary,
	trigger_counts: Dictionary,
	diagnostics: Dictionary
) -> void:
	var analyzer_milestones: Array[Dictionary] = canonical_milestones.duplicate(true)
	if not has_canonical_milestones:
		analyzer_milestones = _make_legacy_object_ball_tap_milestones(fact)
	var declared_count: int = maxi(int(fact.get("unique_object_tap_count", 0)), 0)
	if declared_count != analyzer_milestones.size():
		diagnostics["malformed_object_ball_tap_facts"] = int(
			diagnostics["malformed_object_ball_tap_facts"]
		) + 1
	var seen_target_ids: Dictionary = {}
	for milestone_index in range(analyzer_milestones.size()):
		var analyzer_milestone: Dictionary = analyzer_milestones[milestone_index]
		var contacted_ball_id: int = int(analyzer_milestone.get(
			"contacted_ball_id",
			-1
		))
		var event_index: int = int(analyzer_milestone.get("event_index", -1))
		var target_key: String = str(contacted_ball_id)
		if contacted_ball_id <= 0 or event_index < 0 or seen_target_ids.has(target_key):
			diagnostics["malformed_object_ball_tap_facts"] = int(
				diagnostics["malformed_object_ball_tap_facts"]
			) + 1
			continue
		seen_target_ids[target_key] = true
		var unique_contact_ordinal: int = maxi(int(analyzer_milestone.get(
			"unique_contact_ordinal",
			milestone_index + 1
		)), 1)
		var position_result: Dictionary = _get_milestone_world_position(
			analyzer_milestone,
			event_by_index,
			event_index
		)
		if not bool(position_result.get("available", false)):
			diagnostics["missing_world_positions"] = int(
				diagnostics["missing_world_positions"]
			) + 1
		var occurrence_metadata: Dictionary = _dictionary_value(
			analyzer_milestone,
			"metadata"
		).duplicate(true)
		occurrence_metadata.merge({
			"contacted_ball_id": contacted_ball_id,
			"unique_contact_ordinal": unique_contact_ordinal,
			"unique_target_count": declared_count,
			"repeated_target_contact": false,
			"pocket_event_index": int(fact.get("pocket_event_index", -1)),
			"world_position_available": bool(position_result.get("available", false)),
		}, true)
		var occurrence: Dictionary = _make_occurrence(
			analyzed_ledger,
			fact,
			TRIGGER_OBJECT_BALL_TAP,
			event_index,
			position_result.get("position", Vector2.ZERO),
			unique_contact_ordinal,
			occurrence_metadata
		)
		occurrence["trigger_occurrence_id"] = str(analyzer_milestone.get(
			"trigger_occurrence_id",
			_make_milestone_occurrence_id(
				analyzed_ledger,
				int(fact.get("ball_id", -1)),
				TRIGGER_OBJECT_BALL_TAP,
				unique_contact_ordinal,
				contacted_ball_id
			)
		))
		occurrence["contacted_ball_id"] = contacted_ball_id
		occurrence["unique_contact_ordinal"] = unique_contact_ordinal
		_append_unique_occurrence(
			occurrence,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)
		diagnostics["object_ball_tap_occurrences_emitted"] = int(
			diagnostics["object_ball_tap_occurrences_emitted"]
		) + 1


static func _append_multi_pot_occurrence(
	analyzed_ledger: Dictionary,
	pocket_facts: Array[Dictionary],
	event_by_index: Dictionary,
	occurrences: Array[Dictionary],
	occurrence_ids: Dictionary,
	trigger_counts: Dictionary,
	diagnostics: Dictionary
) -> void:
	if pocket_facts.size() < 2:
		return
	var anchor_fact: Dictionary = pocket_facts[1]
	var event_index: int = int(anchor_fact.get("pocket_event_index", -1))
	if event_index < 0:
		return
	var position_result: Dictionary = _get_event_world_position(event_by_index, event_index)
	if not bool(position_result.get("available", false)):
		diagnostics["missing_world_positions"] = int(diagnostics["missing_world_positions"]) + 1
	var pocket_order_ball_ids: Array[int] = _get_pocket_order_ball_ids(pocket_facts)
	var distinct_pocket_indices: Array[int] = _get_distinct_pocket_indices(pocket_facts)
	var occurrence: Dictionary = _make_occurrence(
		analyzed_ledger,
		anchor_fact,
		TRIGGER_MULTI_POT,
		event_index,
		position_result.get("position", Vector2.ZERO),
		0,
		{
			"total_scoring_object_balls_pocketed": pocket_facts.size(),
			"first_scoring_ball_id": int(pocket_facts[0].get("ball_id", -1)),
			"second_scoring_ball_id": int(anchor_fact.get("ball_id", -1)),
			"full_pocket_order": pocket_order_ball_ids.duplicate(),
			"pocket_order_ball_ids": pocket_order_ball_ids.duplicate(),
			"pocket_order_entries": _get_pocket_order_entries(pocket_facts),
			"distinct_pockets_used": distinct_pocket_indices.size(),
			"distinct_pocket_indices": distinct_pocket_indices.duplicate(),
			"distinct_pocket_count": distinct_pocket_indices.size(),
			"largest_same_pocket_count": _get_largest_same_pocket_count(pocket_facts),
			"establishing_event_index": event_index,
			"world_position_available": bool(position_result.get("available", false)),
		}
	)
	_append_unique_occurrence(
		occurrence,
		occurrences,
		occurrence_ids,
		trigger_counts,
		diagnostics
	)
	diagnostics["multi_pot_occurrences_emitted"] = int(
		diagnostics["multi_pot_occurrences_emitted"]
	) + 1


static func _append_same_pocket_occurrences(
	analyzed_ledger: Dictionary,
	pocket_facts: Array[Dictionary],
	event_by_index: Dictionary,
	occurrences: Array[Dictionary],
	occurrence_ids: Dictionary,
	trigger_counts: Dictionary,
	diagnostics: Dictionary
) -> void:
	var facts_by_pocket: Dictionary = {}
	for fact in pocket_facts:
		var pocket_index: int = int(fact.get("pocket_index", -1))
		if pocket_index < 0:
			diagnostics["invalid_pocket_indices"] = int(diagnostics["invalid_pocket_indices"]) + 1
			continue
		var pocket_key: String = str(pocket_index)
		if not facts_by_pocket.has(pocket_key):
			facts_by_pocket[pocket_key] = []
		(facts_by_pocket[pocket_key] as Array).append(fact)

	var qualifying_pocket_indices: Array[int] = []
	for pocket_key_value in facts_by_pocket.keys():
		var pocket_facts_value: Variant = facts_by_pocket[pocket_key_value]
		if pocket_facts_value is Array and (pocket_facts_value as Array).size() >= 2:
			qualifying_pocket_indices.append(int(pocket_key_value))
	qualifying_pocket_indices.sort()

	for pocket_index in qualifying_pocket_indices:
		var grouped_values: Array = facts_by_pocket.get(str(pocket_index), [])
		var grouped_facts: Array[Dictionary] = []
		for grouped_value in grouped_values:
			if grouped_value is Dictionary:
				grouped_facts.append(grouped_value as Dictionary)
		grouped_facts.sort_custom(_pocket_fact_precedes)
		if grouped_facts.size() < 2:
			continue
		var anchor_fact: Dictionary = grouped_facts[1]
		var event_index: int = int(anchor_fact.get("pocket_event_index", -1))
		if event_index < 0:
			continue
		var position_result: Dictionary = _get_event_world_position(event_by_index, event_index)
		if not bool(position_result.get("available", false)):
			diagnostics["missing_world_positions"] = int(diagnostics["missing_world_positions"]) + 1
		var scoring_ball_ids: Array[int] = _get_pocket_order_ball_ids(grouped_facts)
		var occurrence: Dictionary = _make_occurrence(
			analyzed_ledger,
			anchor_fact,
			TRIGGER_SAME_POCKET_STREAK,
			event_index,
			position_result.get("position", Vector2.ZERO),
			0,
			{
				"pocket_index": pocket_index,
				"final_streak_count": grouped_facts.size(),
				"scoring_ball_ids_in_pocket_order": scoring_ball_ids.duplicate(),
				"event_index_that_established_x2": event_index,
				"establishing_event_index": event_index,
				"world_position_available": bool(position_result.get("available", false)),
			}
		)
		_append_unique_occurrence(
			occurrence,
			occurrences,
			occurrence_ids,
			trigger_counts,
			diagnostics
		)
		diagnostics["same_pocket_occurrences_emitted"] = int(
			diagnostics["same_pocket_occurrences_emitted"]
		) + 1


static func _make_occurrence(
	analyzed_ledger: Dictionary,
	fact: Dictionary,
	trigger_id: String,
	event_index: int,
	world_position_value: Variant,
	milestone_tier: int,
	metadata: Dictionary
) -> Dictionary:
	var scoring_ball_id: int = int(fact.get("ball_id", -1))
	var world_position := Vector2.ZERO
	if world_position_value is Vector2:
		world_position = world_position_value as Vector2
	return {
		"trigger_occurrence_id": _make_occurrence_id(
			analyzed_ledger,
			scoring_ball_id,
			trigger_id
		),
		"trigger_id": trigger_id,
		"ball_id": scoring_ball_id,
		"scoring_ball_id": scoring_ball_id,
		"trigger_ball_id": scoring_ball_id,
		"ball_number": int(fact.get("ball_number", -1)),
		"event_index": event_index,
		"world_position": world_position,
		"pocket_order": int(fact.get("pocket_order", -1)),
		"pocket_index": int(fact.get("pocket_index", -1)),
		"pocket_event_index": int(fact.get("pocket_event_index", -1)),
		"milestone_tier": milestone_tier,
		"metadata": metadata.duplicate(true),
	}


static func _append_unique_occurrence(
	occurrence: Dictionary,
	occurrences: Array[Dictionary],
	occurrence_ids: Dictionary,
	trigger_counts: Dictionary,
	diagnostics: Dictionary
) -> void:
	var occurrence_id: String = str(occurrence.get("trigger_occurrence_id", ""))
	if occurrence_id.is_empty() or occurrence_ids.has(occurrence_id):
		diagnostics["duplicate_occurrence_ids"] = int(diagnostics["duplicate_occurrence_ids"]) + 1
		return
	occurrence_ids[occurrence_id] = true
	occurrences.append(occurrence)
	var trigger_id: String = str(occurrence.get("trigger_id", ""))
	trigger_counts[trigger_id] = int(trigger_counts.get(trigger_id, 0)) + 1


static func _make_occurrence_id(
	analyzed_ledger: Dictionary,
	scoring_ball_id: int,
	trigger_id: String
) -> String:
	var suffix: String = str(TRIGGER_ID_SUFFIX.get(trigger_id, trigger_id))
	var shot_id: int = int(analyzed_ledger.get("shot_id", -1))
	if shot_id >= 0:
		return "shot%d_ball%d_%s" % [shot_id, scoring_ball_id, suffix]
	var attempt_id: int = int(analyzed_ledger.get("attempt_id", -1))
	if attempt_id >= 0:
		return "attempt%d_ball%d_%s" % [attempt_id, scoring_ball_id, suffix]
	return "ledger_ball%d_%s" % [scoring_ball_id, suffix]


static func _make_milestone_occurrence_id(
	analyzed_ledger: Dictionary,
	scoring_ball_id: int,
	trigger_id: String,
	ordinal: int,
	contacted_ball_id: int = -1
) -> String:
	var base_id: String = _make_occurrence_id(
		analyzed_ledger,
		scoring_ball_id,
		trigger_id
	)
	if contacted_ball_id > 0:
		return "%s_%d_target%d" % [base_id, ordinal, contacted_ball_id]
	return "%s_%d" % [base_id, ordinal]


static func _group_semantic_milestones_by_ball(values: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for milestone_value in values:
		if not milestone_value is Dictionary:
			continue
		var milestone: Dictionary = (milestone_value as Dictionary).duplicate(true)
		var ball_id: int = int(milestone.get("ball_id", -1))
		if ball_id <= 0:
			continue
		var ball_key: String = str(ball_id)
		var ball_milestones: Array = grouped.get(ball_key, [])
		ball_milestones.append(milestone)
		grouped[ball_key] = ball_milestones
	for ball_key_value in grouped.keys():
		var ball_key: String = str(ball_key_value)
		var ball_milestones: Array = grouped.get(ball_key, [])
		ball_milestones.sort_custom(_semantic_milestone_precedes)
		grouped[ball_key] = ball_milestones
	return grouped


static func _get_grouped_milestones_for_ball(
	grouped: Dictionary,
	ball_id: int
) -> Array[Dictionary]:
	var milestones: Array[Dictionary] = []
	var values: Variant = grouped.get(str(ball_id), [])
	if not values is Array:
		return milestones
	for milestone_value in values as Array:
		if milestone_value is Dictionary:
			milestones.append((milestone_value as Dictionary).duplicate(true))
	return milestones


static func _count_grouped_milestones(grouped: Dictionary) -> int:
	var count: int = 0
	for values in grouped.values():
		if values is Array:
			count += (values as Array).size()
	return count


static func _semantic_milestone_precedes(a: Dictionary, b: Dictionary) -> bool:
	var event_a: int = int(a.get("event_index", 2147483647))
	var event_b: int = int(b.get("event_index", 2147483647))
	if event_a != event_b:
		return event_a < event_b
	var ordinal_a: int = int(a.get(
		"bonus_ordinal",
		a.get("unique_contact_ordinal", 2147483647)
	))
	var ordinal_b: int = int(b.get(
		"bonus_ordinal",
		b.get("unique_contact_ordinal", 2147483647)
	))
	if ordinal_a != ordinal_b:
		return ordinal_a < ordinal_b
	return str(a.get("trigger_occurrence_id", "")) < str(
		b.get("trigger_occurrence_id", "")
	)


static func _get_milestone_world_position(
	milestone: Dictionary,
	event_by_index: Dictionary,
	event_index: int
) -> Dictionary:
	var position_value: Variant = milestone.get("world_position", null)
	if position_value is Vector2 and _is_finite_vector(position_value as Vector2):
		return {"available": true, "position": position_value as Vector2}
	return _get_event_world_position(event_by_index, event_index)


static func _make_legacy_cue_recontact_milestones(fact: Dictionary) -> Array[Dictionary]:
	var milestones: Array[Dictionary] = []
	var event_indices: Array = _array_value(fact, "cue_recontact_event_indices")
	var positions: Array = _array_value(fact, "cue_recontact_positions")
	var ball_id: int = int(fact.get("ball_id", -1))
	for milestone_index in range(event_indices.size()):
		var event_index: int = int(event_indices[milestone_index])
		var bonus_ordinal: int = milestone_index + 1
		var cue_strike_ordinal: int = bonus_ordinal + 1
		var position: Vector2 = Vector2.ZERO
		if milestone_index < positions.size() and positions[milestone_index] is Vector2:
			position = positions[milestone_index] as Vector2
		milestones.append({
			"trigger_occurrence_id": "cue_recontact_milestone:%d:%d:%d" % [
				ball_id,
				event_index,
				cue_strike_ordinal,
			],
			"trigger_id": TRIGGER_CUE_RECONTACT,
			"ball_id": ball_id,
			"event_index": event_index,
			"world_position": position,
			"cue_strike_ordinal": cue_strike_ordinal,
			"bonus_ordinal": bonus_ordinal,
			"display_tier": _cue_recontact_display_tier(cue_strike_ordinal),
			"metadata": {
				"qualifying_cue_strike_count": int(fact.get(
					"qualifying_cue_strike_count",
					event_indices.size() + 1
				)),
			},
		})
	return milestones


static func _make_legacy_object_ball_tap_milestones(fact: Dictionary) -> Array[Dictionary]:
	var milestones: Array[Dictionary] = []
	var target_ball_ids: Array = _array_value(fact, "unique_object_tap_ball_ids")
	var event_indices: Array = _array_value(fact, "object_tap_event_indices")
	var positions: Array = _array_value(fact, "object_tap_positions")
	var ball_id: int = int(fact.get("ball_id", -1))
	var aligned_count: int = mini(target_ball_ids.size(), event_indices.size())
	for milestone_index in range(aligned_count):
		var contacted_ball_id: int = int(target_ball_ids[milestone_index])
		var event_index: int = int(event_indices[milestone_index])
		var position: Vector2 = Vector2.ZERO
		if milestone_index < positions.size() and positions[milestone_index] is Vector2:
			position = positions[milestone_index] as Vector2
		milestones.append({
			"trigger_occurrence_id": "object_ball_tap_milestone:%d:%d:%d" % [
				ball_id,
				contacted_ball_id,
				event_index,
			],
			"trigger_id": TRIGGER_OBJECT_BALL_TAP,
			"ball_id": ball_id,
			"contacted_ball_id": contacted_ball_id,
			"event_index": event_index,
			"world_position": position,
			"unique_contact_ordinal": milestone_index + 1,
			"metadata": {
				"unique_target_count": target_ball_ids.size(),
				"repeated_target_contact": false,
			},
		})
	return milestones


static func _get_aligned_world_position(
	positions: Array,
	position_index: int,
	event_by_index: Dictionary,
	event_index: int
) -> Dictionary:
	if position_index >= 0 and position_index < positions.size():
		var position_value: Variant = positions[position_index]
		if position_value is Vector2 and _is_finite_vector(position_value as Vector2):
			return {"available": true, "position": position_value as Vector2}
	return _get_event_world_position(event_by_index, event_index)


static func _cue_recontact_display_tier(cue_strike_ordinal: int) -> String:
	if cue_strike_ordinal == 2:
		return "double_tap"
	if cue_strike_ordinal == 3:
		return "triple_tap"
	return "tap_x%d" % maxi(cue_strike_ordinal, 4)


static func _get_event_world_position(event_by_index: Dictionary, event_index: int) -> Dictionary:
	var event_value: Variant = event_by_index.get(str(event_index), null)
	if not event_value is Dictionary:
		return {"available": false, "position": Vector2.ZERO}
	var event: Dictionary = event_value as Dictionary
	var event_type: String = str(event.get("event_type", ""))
	var candidate_keys: Array[String] = []
	match event_type:
		"ball_contact":
			candidate_keys = ["contact_point"]
		"rail_contact":
			candidate_keys = ["surface_contact_point", "contact_point", "ball_center_at_contact"]
		"pocket":
			candidate_keys = ["capture_position", "pocket_center"]
		_:
			candidate_keys = [
				"contact_point",
				"surface_contact_point",
				"capture_position",
				"pocket_center",
				"ball_center_at_contact",
			]
	for key in candidate_keys:
		var position_value: Variant = event.get(key, null)
		if position_value is Vector2 and _is_finite_vector(position_value as Vector2):
			return {"available": true, "position": position_value}
	return {"available": false, "position": Vector2.ZERO}


static func _build_event_index(raw_events: Array) -> Dictionary:
	var event_by_index: Dictionary = {}
	for event_value in raw_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value as Dictionary
		var event_index: int = int(event.get("event_index", -1))
		if event_index < 0:
			continue
		var event_key: String = str(event_index)
		if not event_by_index.has(event_key):
			event_by_index[event_key] = event
	return event_by_index


static func _get_sorted_pocket_facts(derived: Dictionary) -> Array[Dictionary]:
	var pocket_facts: Array[Dictionary] = []
	for fact_value in _array_value(derived, "pocket_facts"):
		if fact_value is Dictionary:
			pocket_facts.append((fact_value as Dictionary).duplicate(true))
	pocket_facts.sort_custom(_pocket_fact_precedes)
	return pocket_facts


static func _get_derived(analyzed_ledger: Dictionary) -> Dictionary:
	var derived_value: Variant = analyzed_ledger.get("derived", null)
	if derived_value is Dictionary:
		return derived_value as Dictionary
	if analyzed_ledger.get("pocket_facts", null) is Array:
		return analyzed_ledger
	return {}


static func _sorted_unique_nonnegative_ints(values: Array) -> Array[int]:
	var unique: Dictionary = {}
	for value in values:
		var event_index: int = int(value)
		if event_index >= 0:
			unique[str(event_index)] = event_index
	var result: Array[int] = []
	for event_index_value in unique.values():
		result.append(int(event_index_value))
	result.sort()
	return result


static func _get_pocket_order_ball_ids(pocket_facts: Array[Dictionary]) -> Array[int]:
	var ball_ids: Array[int] = []
	for fact in pocket_facts:
		ball_ids.append(int(fact.get("ball_id", -1)))
	return ball_ids


static func _get_pocket_order_entries(pocket_facts: Array[Dictionary]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for fact in pocket_facts:
		entries.append({
			"ball_id": int(fact.get("ball_id", -1)),
			"ball_number": int(fact.get("ball_number", -1)),
			"pocket_order": int(fact.get("pocket_order", -1)),
			"pocket_index": int(fact.get("pocket_index", -1)),
			"pocket_event_index": int(fact.get("pocket_event_index", -1)),
		})
	return entries


static func _get_distinct_pocket_indices(pocket_facts: Array[Dictionary]) -> Array[int]:
	var seen: Dictionary = {}
	var pocket_indices: Array[int] = []
	for fact in pocket_facts:
		var pocket_index: int = int(fact.get("pocket_index", -1))
		if pocket_index < 0 or seen.has(str(pocket_index)):
			continue
		seen[str(pocket_index)] = true
		pocket_indices.append(pocket_index)
	return pocket_indices


static func _get_largest_same_pocket_count(pocket_facts: Array[Dictionary]) -> int:
	var counts: Dictionary = {}
	var largest_count: int = 0
	for fact in pocket_facts:
		var pocket_index: int = int(fact.get("pocket_index", -1))
		if pocket_index < 0:
			continue
		var pocket_key: String = str(pocket_index)
		var count: int = int(counts.get(pocket_key, 0)) + 1
		counts[pocket_key] = count
		largest_count = maxi(largest_count, count)
	return largest_count


static func _occurrence_precedes(a: Dictionary, b: Dictionary) -> bool:
	var event_a: int = int(a.get("event_index", 2147483647))
	var event_b: int = int(b.get("event_index", 2147483647))
	if event_a != event_b:
		return event_a < event_b
	var pocket_order_a: int = int(a.get("pocket_order", 2147483647))
	var pocket_order_b: int = int(b.get("pocket_order", 2147483647))
	if pocket_order_a != pocket_order_b:
		return pocket_order_a < pocket_order_b
	var trigger_order_a: int = int(TRIGGER_SORT_ORDER.get(str(a.get("trigger_id", "")), 99))
	var trigger_order_b: int = int(TRIGGER_SORT_ORDER.get(str(b.get("trigger_id", "")), 99))
	if trigger_order_a != trigger_order_b:
		return trigger_order_a < trigger_order_b
	var ball_a: int = int(a.get("scoring_ball_id", 2147483647))
	var ball_b: int = int(b.get("scoring_ball_id", 2147483647))
	if ball_a != ball_b:
		return ball_a < ball_b
	return str(a.get("trigger_occurrence_id", "")) < str(b.get("trigger_occurrence_id", ""))


static func _pocket_fact_precedes(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("pocket_order", 2147483647))
	var order_b: int = int(b.get("pocket_order", 2147483647))
	if order_a != order_b:
		return order_a < order_b
	return int(a.get("ball_id", 2147483647)) < int(b.get("ball_id", 2147483647))


static func _empty_trigger_counts() -> Dictionary:
	return {
		TRIGGER_SINGLE_BANK: 0,
		TRIGGER_DOUBLE_BANK: 0,
		TRIGGER_TRIPLE_BANK: 0,
		TRIGGER_COMBINATION: 0,
		TRIGGER_DIRECT_POT: 0,
		TRIGGER_MULTI_POT: 0,
		TRIGGER_SAME_POCKET_STREAK: 0,
		TRIGGER_CUE_RECONTACT: 0,
		TRIGGER_OBJECT_BALL_TAP: 0,
	}


static func _test_pocket_fact(is_direct_pot: bool = false) -> Dictionary:
	return {
		"ball_id": 7,
		"ball_number": 3,
		"pocket_order": 1,
		"pocket_index": 0,
		"pocket_event_index": 10,
		"causal_activation_event_index": 1,
		"causal_parent_ball_id": 1,
		"causal_depth": 1,
		"bank_count": 0,
		"rail_contacts_after_activation": 0,
		"qualifying_rail_event_indices": [],
		"is_combination_pot": false,
		"is_depth1_zero_rail_pot": true,
		"is_direct_pot": is_direct_pot,
		"cue_recontact_bonus_count": 0,
		"cue_recontact_event_indices": [],
		"cue_recontact_positions": [],
		"cue_recontact_milestones": [],
		"unique_object_tap_count": 0,
		"unique_object_tap_ball_ids": [],
		"object_tap_event_indices": [],
		"object_tap_positions": [],
		"object_ball_tap_milestones": [],
	}


static func _test_analyzed_ledger(fact: Dictionary) -> Dictionary:
	var cue_recontact_milestones: Array[Dictionary] = (
		_make_legacy_cue_recontact_milestones(fact)
	)
	var object_ball_tap_milestones: Array[Dictionary] = (
		_make_legacy_object_ball_tap_milestones(fact)
	)
	var canonical_fact: Dictionary = fact.duplicate(true)
	canonical_fact["cue_recontact_milestones"] = cue_recontact_milestones.duplicate(true)
	canonical_fact["object_ball_tap_milestones"] = (
		object_ball_tap_milestones.duplicate(true)
	)
	return {
		"schema_version": 2,
		"source": "trigger_self_test",
		"run_generation": 1,
		"shot_id": 9,
		"attempt_id": 9,
		"cue_ball_id": 1,
		"raw_events": [{
			"event_type": "pocket",
			"event_index": 10,
			"capture_position": Vector2(100.0, 10.0),
		}],
		"derived": {
			"pocket_facts": [canonical_fact],
			"cue_recontact_milestones": cue_recontact_milestones,
			"cue_recontact_milestone_count": cue_recontact_milestones.size(),
			"object_ball_tap_milestones": object_ball_tap_milestones,
			"object_ball_tap_milestone_count": object_ball_tap_milestones.size(),
		},
	}


static func _test_trigger_count(evaluation: Dictionary, trigger_id: String) -> int:
	var trigger_counts_value: Variant = evaluation.get("trigger_counts", {})
	if not trigger_counts_value is Dictionary:
		return 0
	return int((trigger_counts_value as Dictionary).get(trigger_id, 0))


static func _test_occurrences_for_trigger(
	evaluation: Dictionary,
	trigger_id: String
) -> Array[Dictionary]:
	var matching: Array[Dictionary] = []
	for occurrence_value in _array_value(evaluation, "occurrences"):
		if not occurrence_value is Dictionary:
			continue
		var occurrence: Dictionary = occurrence_value as Dictionary
		if str(occurrence.get("trigger_id", "")) == trigger_id:
			matching.append(occurrence)
	return matching


static func _test_occurrence_event_indices(occurrences: Array[Dictionary]) -> Array[int]:
	var indices: Array[int] = []
	for occurrence in occurrences:
		indices.append(int(occurrence.get("event_index", -1)))
	return indices


static func _test_occurrence_target_ids(occurrences: Array[Dictionary]) -> Array[int]:
	var target_ids: Array[int] = []
	for occurrence in occurrences:
		target_ids.append(int(occurrence.get("contacted_ball_id", -1)))
	return target_ids


static func _append_test_case(
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


static func _array_value(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, null)
	if value is Array:
		return value
	return []


static func _dictionary_value(source: Dictionary, key: StringName) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value as Dictionary
	return {}


static func _dictionary_at(values: Array, index: int) -> Dictionary:
	if index < 0 or index >= values.size():
		return {}
	var value: Variant = values[index]
	return value as Dictionary if value is Dictionary else {}


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
