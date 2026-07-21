extends RefCounted
class_name RogueliteScoringNarrativeBuilder

# Pure, value-only presentation narratives derived from immutable scoring data.
# This builder reorders presentation facts but never changes resolver arithmetic.

const SCHEMA_VERSION := 2
const SOURCE_PREDICTED := "predicted"
const SOURCE_AUTHORITATIVE := "authoritative"
const SELF_TEST_CASE_COUNT := 9

const SOURCE_BASE_HAUL := "base_object_ball_value"
const SOURCE_ADDITIONAL_BALL := "base_additional_ball"
const SOURCE_BANK_RAIL := "base_bank_rail"
const SOURCE_COMBINATION := "base_combination"
const SOURCE_CUE_RECONTACT := "base_cue_recontact"
const SOURCE_CUE_RECONTACT_MILESTONE := "cue_recontact_milestone"
const SOURCE_OBJECT_BALL_TAP := "base_object_ball_tap"
const SOURCE_OBJECT_BALL_TAP_MILESTONE := "object_ball_tap_milestone"
const SOURCE_SCRATCH := "scratch"
const DEAD_RECKONING_ITEM_ID := "direct_pot_legendary_dead_reckoning"
const RETRIGGER_MARKER_EFFECT := "DIRECT POT EFFECTS TRIGGER AGAIN"

const EVENT_PRIORITY := {
	"combination": 10,
	"cue_recontact_milestone": 15,
	"object_ball_tap_milestone": 16,
	"rail_milestone": 20,
	"rail_group": 20,
	"pocket": 30,
	"additional_ball": 40,
	"ball_contribution": 50,
}


static func build_predicted_narrative(ledger_with_derived: Dictionary, score_result: Dictionary) -> Dictionary:
	return build_narrative(SOURCE_PREDICTED, ledger_with_derived, score_result)


static func build_authoritative_narrative(ledger_with_derived: Dictionary, score_result: Dictionary) -> Dictionary:
	return build_narrative(SOURCE_AUTHORITATIVE, ledger_with_derived, score_result)


static func build_narrative(source: String, ledger_with_derived: Dictionary, score_result: Dictionary) -> Dictionary:
	var normalized_source: String = _normalize_source(source)
	var result: Dictionary = _make_empty_result(normalized_source, ledger_with_derived, score_result)
	var diagnostics: Dictionary = _dictionary_value(result, "diagnostics")
	var validation: Dictionary = _dictionary_value(result, "validation")

	if source not in [SOURCE_PREDICTED, SOURCE_AUTHORITATIVE]:
		return _finalize_input_failure(
			result,
			"Narrative source `%s` is unsupported." % source,
			ledger_with_derived,
			score_result
		)
	if _contains_live_node_reference(ledger_with_derived) or _contains_live_node_reference(score_result):
		return _finalize_input_failure(
			result,
			"Narrative input contains a live Node reference.",
			{},
			{}
		)
	if ledger_with_derived.is_empty() or score_result.is_empty():
		return _finalize_input_failure(
			result,
			"Narrative input is missing its ledger or score result.",
			ledger_with_derived,
			score_result
		)
	if not _identity_matches(score_result, ledger_with_derived):
		return _finalize_input_failure(
			result,
			"Score result and complete Shot Ledger identities do not match.",
			ledger_with_derived,
			score_result
		)
	var derived: Dictionary = _dictionary_value(ledger_with_derived, "derived")
	if int(derived.get("schema_version", -1)) != ShotLedgerAnalyzer.SCHEMA_VERSION:
		return _finalize_input_failure(
			result,
			"Shot Ledger derived facts are missing or use an unsupported schema.",
			ledger_with_derived,
			score_result
		)
	var resolution_steps: Array = _array_value(score_result, "resolution_steps")
	if resolution_steps.is_empty() and int(score_result.get("shot_score", 0)) != 0:
		return _finalize_input_failure(
			result,
			"A nonzero score result has no canonical resolution steps.",
			ledger_with_derived,
			score_result
		)

	diagnostics["input_valid"] = true
	var event_lookup: Dictionary = _build_event_lookup(ledger_with_derived, diagnostics)
	var tap_milestone_lookup: Dictionary = _build_tap_milestone_lookup(
		derived,
		diagnostics
	)
	var pocket_facts: Array[Dictionary] = _get_sorted_pocket_facts(derived, diagnostics)
	var pocket_fact_lookup: Dictionary = _build_pocket_fact_lookup(pocket_facts)
	var starting_balls: Dictionary = _dictionary_value(ledger_with_derived, "starting_balls")
	var narratives_by_ball: Dictionary = {}
	for fact in pocket_facts:
		var ball_id: int = int(fact.get("ball_id", -1))
		if ball_id <= 0:
			continue
		narratives_by_ball[str(ball_id)] = _make_ball_narrative(
			fact,
			_get_ball_snapshot(starting_balls, ball_id),
			normalized_source,
			ledger_with_derived
		)

	var engine_events: Array[Dictionary] = []
	var consequence_events: Array[Dictionary] = []
	var step_owners: Dictionary = {}
	var canonical_scoring_step_indices: Array[int] = []
	var canonical_engine_step_indices: Array[int] = []
	var canonical_xmult_step_indices: Array[int] = []
	for input_index in range(resolution_steps.size()):
		var step_value: Variant = resolution_steps[input_index]
		if not step_value is Dictionary:
			_add_error(validation, "Canonical resolution step %d is not a Dictionary." % input_index)
			continue
		var step: Dictionary = (step_value as Dictionary).duplicate(true)
		var step_index: int = int(step.get("step_index", input_index))
		var source_id: String = str(step.get("source_id", ""))
		var source_type: String = str(step.get("source_type", ""))
		var phase: String = str(step.get("phase", ""))
		var ball_id: int = int(step.get("ball_id", -1))
		var affects_score: bool = bool(step.get("affects_score", true))
		if affects_score:
			canonical_scoring_step_indices.append(step_index)

		if not affects_score or source_id == SOURCE_SCRATCH or phase == "consequence":
			_register_step_owner(step_owners, step_index, "consequence", validation)
			consequence_events.append(_make_consequence_event(step, event_lookup, diagnostics))
			continue

		if source_type == "modifier" or ball_id <= 0:
			_register_step_owner(step_owners, step_index, "engine", validation)
			canonical_engine_step_indices.append(step_index)
			if phase == RogueliteScoreResolver.PHASE_XMULT or not is_equal_approx(float(step.get("xmult_factor", 1.0)), 1.0):
				canonical_xmult_step_indices.append(step_index)
			engine_events.append(_make_engine_event(step))
			continue

		var ball_key: String = str(ball_id)
		if not narratives_by_ball.has(ball_key):
			var fallback_fact: Dictionary = _dictionary_value(pocket_fact_lookup, ball_key)
			narratives_by_ball[ball_key] = _make_ball_narrative(
				fallback_fact,
				_get_ball_snapshot(starting_balls, ball_id),
				normalized_source,
				ledger_with_derived,
				ball_id
			)
		_register_step_owner(step_owners, step_index, "ball:%d" % ball_id, validation)
		var narrative: Dictionary = narratives_by_ball[ball_key]
		var narrative_events: Array = _array_value(narrative, "events")
		var physical_events: Array[Dictionary] = _make_physical_events(
			step,
			_dictionary_value(pocket_fact_lookup, ball_key),
			event_lookup,
			diagnostics,
			starting_balls,
			tap_milestone_lookup
		)
		for physical_event in physical_events:
			narrative_events.append(physical_event)
		narrative["events"] = narrative_events
		narratives_by_ball[ball_key] = narrative

	var ball_narratives: Array[Dictionary] = []
	for narrative_value in narratives_by_ball.values():
		if not narrative_value is Dictionary:
			continue
		var narrative: Dictionary = (narrative_value as Dictionary).duplicate(true)
		var events: Array = _array_value(narrative, "events")
		events.sort_custom(_physical_event_precedes)
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			event["narrative_event_index"] = event_index
			events[event_index] = event
		narrative["events"] = events
		narrative["haul_contribution"] = _sum_int_field(events, "haul_delta")
		narrative["mult_contribution"] = _sum_float_field(events, "mult_delta")
		narrative["live_cue_sequence"] = _make_live_cue_sequence(events)
		var plan: Dictionary = _dictionary_value(narrative, "plan")
		plan["expected_live_cue_sequence"] = _make_live_cue_sequence(events)
		narrative["plan"] = plan
		ball_narratives.append(narrative)
	ball_narratives.sort_custom(_ball_narrative_precedes)
	engine_events.sort_custom(_canonical_step_precedes)
	engine_events = _insert_authoritative_retrigger_markers(engine_events)
	consequence_events.sort_custom(_canonical_step_precedes)

	var presentation_state: Dictionary = {
		"haul": 0,
		"mult": float(score_result.get("base_mult", RogueliteScoreResolver.BASE_MULT)),
	}
	var flattened_physical_events: Array[Dictionary] = []
	var presentation_sequence: Array[Dictionary] = []
	var sequence_index: int = 0
	for narrative_index in range(ball_narratives.size()):
		var narrative: Dictionary = ball_narratives[narrative_index]
		var events: Array = _array_value(narrative, "events")
		for event_index in range(events.size()):
			var event: Dictionary = events[event_index]
			_apply_reordered_display_state(event, presentation_state)
			event["sequence_index"] = sequence_index
			sequence_index += 1
			events[event_index] = event
			flattened_physical_events.append(event.duplicate(true))
			presentation_sequence.append(event.duplicate(true))
		narrative["events"] = events
		narrative["display_state_after"] = {
			"haul": int(presentation_state.get("haul", 0)),
			"mult": float(presentation_state.get("mult", 1.0)),
			"score": _score_preview(
				int(presentation_state.get("haul", 0)),
				float(presentation_state.get("mult", 1.0))
			),
		}
		ball_narratives[narrative_index] = narrative

	for engine_index in range(engine_events.size()):
		var event: Dictionary = engine_events[engine_index]
		if bool(event.get("presentation_only_marker", false)):
			_apply_informational_display_state(event, presentation_state)
			event["display_continuity_matches"] = true
		else:
			_apply_canonical_display_state(event, presentation_state)
		event["sequence_index"] = sequence_index
		sequence_index += 1
		engine_events[engine_index] = event
		presentation_sequence.append(event.duplicate(true))

	for consequence_index in range(consequence_events.size()):
		var event: Dictionary = consequence_events[consequence_index]
		_apply_informational_display_state(event, presentation_state)
		event["sequence_index"] = sequence_index
		sequence_index += 1
		consequence_events[consequence_index] = event
		presentation_sequence.append(event.duplicate(true))

	result["ball_narratives"] = ball_narratives
	result["physical_events"] = flattened_physical_events
	result["engine_events"] = engine_events
	result["consequence_events"] = consequence_events
	result["presentation_sequence"] = presentation_sequence
	result["display_final_haul"] = int(presentation_state.get("haul", 0))
	result["display_final_mult"] = float(presentation_state.get("mult", 1.0))
	result["display_final_score"] = _score_preview(
		int(presentation_state.get("haul", 0)),
		float(presentation_state.get("mult", 1.0))
	)

	diagnostics["ball_narrative_count"] = ball_narratives.size()
	diagnostics["physical_event_count"] = flattened_physical_events.size()
	diagnostics["cue_recontact_milestone_count"] = _count_event_type(
		flattened_physical_events,
		"cue_recontact_milestone"
	)
	diagnostics["object_ball_tap_milestone_count"] = _count_event_type(
		flattened_physical_events,
		"object_ball_tap_milestone"
	)
	diagnostics["engine_event_count"] = engine_events.size()
	diagnostics["retrigger_event_count"] = _count_retrigger_events(engine_events)
	diagnostics["retrigger_marker_count"] = _count_event_type(engine_events, "retrigger_marker")
	diagnostics["consequence_event_count"] = consequence_events.size()
	diagnostics["final_classes_by_ball"] = _final_classes_by_ball(ball_narratives)
	diagnostics["canonical_scoring_step_indices"] = canonical_scoring_step_indices.duplicate()
	diagnostics["canonical_engine_step_indices"] = canonical_engine_step_indices.duplicate()
	diagnostics["canonical_xmult_step_indices"] = canonical_xmult_step_indices.duplicate()
	diagnostics["represented_step_owners"] = step_owners.duplicate(true)
	result["diagnostics"] = diagnostics

	_finalize_validation(
		result,
		score_result,
		pocket_facts,
		resolution_steps,
		canonical_scoring_step_indices,
		canonical_engine_step_indices,
		canonical_xmult_step_indices,
		step_owners
	)
	return result.duplicate(true)


static func run_self_tests() -> Dictionary:
	var cases: Array[Dictionary] = []
	_run_bank_partition_case(cases, 1, "Single Bank Partitions")
	_run_bank_partition_case(cases, 2, "Double Bank Partitions")
	_run_bank_partition_case(cases, 3, "Triple Bank Partitions")

	var two_ball_ledger: Dictionary = _make_test_ledger([
		{"ball_id": 2, "ball_number": 2, "rail_count": 0},
		{"ball_id": 3, "ball_number": 3, "rail_count": 1},
	])
	var two_ball_score: Dictionary = RogueliteScoreResolver.resolve(two_ball_ledger)
	var two_ball_result: Dictionary = build_authoritative_narrative(two_ball_ledger, two_ball_score)
	var two_ball_narratives: Array = _array_value(two_ball_result, "ball_narratives")
	_append_case(cases, "Two Scoring Balls Stay Separate", (
		two_ball_narratives.size() == 2
		and int(_dictionary_at(two_ball_narratives, 0).get("ball_id", -1)) == 2
		and int(_dictionary_at(two_ball_narratives, 1).get("ball_id", -1)) == 3
		and int(_dictionary_at(two_ball_narratives, 0).get("pocket_order", -1)) == 1
		and int(_dictionary_at(two_ball_narratives, 1).get("pocket_order", -1)) == 2
	), {"ball_ids": [2, 3], "pocket_orders": [1, 2]}, {
		"ball_ids": _narrative_ball_ids(two_ball_narratives),
		"pocket_orders": _narrative_pocket_orders(two_ball_narratives),
	})

	var modifier_ledger: Dictionary = _make_test_ledger([
		{"ball_id": 2, "ball_number": 2, "rail_count": 0},
	])
	var modifiers: Array = [
		_test_modifier("late_haul", RogueliteScoreResolver.PHASE_ADD_HAUL, 1, 5),
		_test_modifier("early_xmult", RogueliteScoreResolver.PHASE_XMULT, 0, 1.5),
		_test_modifier("early_haul", RogueliteScoreResolver.PHASE_ADD_HAUL, 0, 10),
		_test_modifier("middle_mult", RogueliteScoreResolver.PHASE_ADD_MULT, 0, 2.0),
		_test_modifier("late_xmult", RogueliteScoreResolver.PHASE_XMULT, 1, 2.0),
	]
	var modifier_score: Dictionary = RogueliteScoreResolver.resolve(modifier_ledger, modifiers)
	var modifier_result: Dictionary = build_authoritative_narrative(modifier_ledger, modifier_score)
	var engine_events: Array = _array_value(modifier_result, "engine_events")
	var expected_modifier_order: Array[String] = [
		"early_haul", "late_haul", "middle_mult", "early_xmult", "late_xmult",
	]
	_append_case(cases, "Modifier And xMult Order Is Canonical", (
		_engine_source_ids(engine_events) == expected_modifier_order
	), expected_modifier_order, _engine_source_ids(engine_events))

	var arithmetic_validation: Dictionary = _dictionary_value(modifier_result, "validation")
	var arithmetic_checks: Dictionary = _dictionary_value(arithmetic_validation, "checks")
	_append_case(cases, "Final Arithmetic Equals Immutable Result", (
		bool(arithmetic_validation.get("valid", false))
		and bool(arithmetic_checks.get("display_final_haul_matches", false))
		and bool(arithmetic_checks.get("display_final_mult_matches", false))
		and bool(arithmetic_checks.get("display_final_score_matches", false))
		and int(modifier_result.get("display_final_score", -1)) == int(modifier_score.get("shot_score", -2))
	), {
		"valid": true,
		"display_final_score": modifier_score.get("shot_score", null),
	}, {
		"valid": arithmetic_validation.get("valid", false),
		"display_final_score": modifier_result.get("display_final_score", null),
		"immutable_shot_score": modifier_score.get("shot_score", null),
	})

	var fallback_ledger: Dictionary = _make_test_ledger([
		{"ball_id": 2, "ball_number": 2, "rail_count": 3},
	])
	var fallback_score: Dictionary = RogueliteScoreResolver.resolve(fallback_ledger)
	var fallback_steps: Array = _array_value(fallback_score, "resolution_steps")
	for fallback_index in range(fallback_steps.size()):
		var fallback_step: Dictionary = fallback_steps[fallback_index]
		if str(fallback_step.get("source_id", "")) != SOURCE_BANK_RAIL:
			continue
		var metadata: Dictionary = _dictionary_value(fallback_step, "metadata")
		metadata["scored_rail_event_indices"] = [999]
		fallback_step["metadata"] = metadata
		fallback_steps[fallback_index] = fallback_step
	fallback_score["resolution_steps"] = fallback_steps
	var fallback_result: Dictionary = build_authoritative_narrative(fallback_ledger, fallback_score)
	var fallback_events: Array = _array_value(_dictionary_at(_array_value(fallback_result, "ball_narratives"), 0), "events")
	_append_case(cases, "Unsafe Rail Partition Uses Grouped Step", (
		_count_event_type(fallback_events, "rail_group") == 1
		and _count_event_type(fallback_events, "rail_milestone") == 0
		and is_equal_approx(_sum_float_field(fallback_events, "mult_delta"), 3.0)
		and bool(_dictionary_value(fallback_result, "validation").get("valid", false))
	), {"rail_group": 1, "rail_milestone": 0, "mult_delta": 3.0}, {
		"rail_group": _count_event_type(fallback_events, "rail_group"),
		"rail_milestone": _count_event_type(fallback_events, "rail_milestone"),
		"mult_delta": _sum_float_field(fallback_events, "mult_delta"),
		"warnings": _dictionary_value(fallback_result, "diagnostics").get("warnings", []),
	})

	var tap_fixture: Dictionary = _make_test_tap_fixture()
	var tap_result: Dictionary = build_authoritative_narrative(
		_dictionary_value(tap_fixture, "ledger"),
		_dictionary_value(tap_fixture, "score_result")
	)
	var tap_narratives: Array = _array_value(tap_result, "ball_narratives")
	var tap_events: Array = _array_value(_dictionary_at(tap_narratives, 0), "events")
	_append_case(cases, "Tap Physical Events Stay Chronological", (
		tap_events.size() == 3
		and str(_dictionary_at(tap_events, 0).get("event_type", ""))
			== "cue_recontact_milestone"
		and str(_dictionary_at(tap_events, 1).get("event_type", ""))
			== "object_ball_tap_milestone"
		and str(_dictionary_at(tap_events, 2).get("event_type", "")) == "pocket"
		and str(_dictionary_at(tap_events, 0).get("replay_title", "")) == "DOUBLE TAP"
		and str(_dictionary_at(tap_events, 1).get("replay_title", "")) == "BALL TAP"
		and is_equal_approx(_sum_float_field(tap_events, "mult_delta"), 2.0)
		and bool(_dictionary_value(tap_result, "validation").get("valid", false))
	), ["cue_recontact_milestone", "object_ball_tap_milestone", "pocket"], [
		str(_dictionary_at(tap_events, 0).get("event_type", "")),
		str(_dictionary_at(tap_events, 1).get("event_type", "")),
		str(_dictionary_at(tap_events, 2).get("event_type", "")),
	])
	_append_case(cases, "Tap Events Carry Value-Only Contact Echoes", (
		int(_dictionary_at(tap_events, 0).get("contacted_ball_id", -1)) == 1
		and bool(_dictionary_at(tap_events, 0).get("contacted_ball_is_cue", false))
		and int(_dictionary_at(tap_events, 1).get("contacted_ball_id", -1)) == 3
		and bool(_dictionary_at(tap_events, 0).get("world_position_valid", false))
		and (_dictionary_at(tap_events, 0).get("world_position", Vector2.INF) as Vector2).is_equal_approx(
			Vector2(300.0, 300.0)
		)
		and (_dictionary_at(tap_events, 1).get("world_position", Vector2.INF) as Vector2).is_equal_approx(
			Vector2(360.0, 300.0)
		)
		and bool(_dictionary_at(tap_events, 1).get(
			"contacted_ball_world_position_valid",
			false
		))
	), {
		"cue_contact": 1,
		"object_contact": 3,
		"positions": [Vector2(300.0, 300.0), Vector2(360.0, 300.0)],
	}, {
		"cue_contact": _dictionary_at(tap_events, 0).get("contacted_ball_id", -1),
		"object_contact": _dictionary_at(tap_events, 1).get("contacted_ball_id", -1),
		"positions": [
			_dictionary_at(tap_events, 0).get("world_position", Vector2.INF),
			_dictionary_at(tap_events, 1).get("world_position", Vector2.INF),
		],
	})

	var passed: int = 0
	var failures: Array[Dictionary] = []
	for case_value in cases:
		var case: Dictionary = case_value
		if bool(case.get("passed", false)):
			passed += 1
		else:
			failures.append(case.duplicate(true))
	return {
		"status": "PASS" if failures.is_empty() and cases.size() == SELF_TEST_CASE_COUNT else "FAIL",
		"total": cases.size(),
		"passed": passed,
		"failed": failures.size(),
		"cases": cases,
		"failures": failures,
	}


static func _make_empty_result(source: String, ledger: Dictionary, score_result: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"source": source,
		"source_ledger_type": str(ledger.get("source", "")),
		"scoring_model": str(score_result.get("scoring_model", RogueliteScoreResolver.SCORING_MODEL)),
		"run_generation": int(score_result.get("run_generation", ledger.get("run_generation", -1))),
		"mode_id": str(score_result.get("mode_id", ledger.get("mode_id", ""))),
		"shot_id": int(score_result.get("shot_id", ledger.get("shot_id", -1))),
		"attempt_id": int(score_result.get("attempt_id", ledger.get("attempt_id", -1))),
		"prediction_generation": int(ledger.get("prediction_generation", -1)),
		"prediction_key": str(ledger.get("prediction_key", "")),
		"ball_narratives": [],
		"physical_events": [],
		"engine_events": [],
		"consequence_events": [],
		"presentation_sequence": [],
		"base_haul": int(score_result.get("base_haul", 0)),
		"base_mult": float(score_result.get("base_mult", RogueliteScoreResolver.BASE_MULT)),
		"final_haul": int(score_result.get("final_haul", 0)),
		"final_mult": float(score_result.get("final_mult", RogueliteScoreResolver.BASE_MULT)),
		"final_score": int(score_result.get("shot_score", 0)),
		"display_final_haul": 0,
		"display_final_mult": float(score_result.get("base_mult", RogueliteScoreResolver.BASE_MULT)),
		"display_final_score": 0,
		"validation": {
			"status": "NOT_RUN",
			"valid": false,
			"fancy_replay_allowed": false,
			"fallback_required": true,
			"checks": {},
			"warnings": [],
			"errors": [],
		},
		"fallback": {
			"required": true,
			"mode": "canonical_resolution_steps",
			"reason": "Narrative validation has not run.",
			"canonical_resolution_steps": [],
		},
		"diagnostics": {
			"input_valid": false,
			"identity_match": _identity_matches(score_result, ledger),
			"ball_narrative_count": 0,
			"physical_event_count": 0,
			"engine_event_count": 0,
			"consequence_event_count": 0,
			"rail_groups_partitioned": 0,
			"rail_groups_fallback": 0,
			"partitioned_rail_event_count": 0,
			"missing_event_indices": [],
			"invalid_position_count": 0,
			"duplicate_event_index_count": 0,
			"warnings": [],
		},
	}


static func _make_ball_narrative(
	fact: Dictionary,
	ball_snapshot: Dictionary,
	source: String,
	ledger: Dictionary,
	forced_ball_id: int = -1
) -> Dictionary:
	var ball_id: int = int(fact.get("ball_id", forced_ball_id))
	var ball_number: int = int(fact.get("ball_number", ball_snapshot.get("ball_number", -1)))
	var bank_class: String = str(fact.get("bank_class", _bank_class(int(fact.get("bank_count", 0)))))
	var is_combination: bool = bool(fact.get("is_combination_pot", false))
	var derived: Dictionary = _dictionary_value(ledger, "derived")
	var cue_recontact_milestones: Array[Dictionary] = _canonical_milestones_for_ball(
		derived,
		"cue_recontact_milestones",
		ball_id
	)
	var object_ball_tap_milestones: Array[Dictionary] = _canonical_milestones_for_ball(
		derived,
		"object_ball_tap_milestones",
		ball_id
	)
	var cue_recontact_count: int = cue_recontact_milestones.size()
	var object_tap_count: int = object_ball_tap_milestones.size()
	var has_explicit_direct_fact: bool = fact.has("is_direct_pot")
	var is_direct_pot: bool = bool(fact.get(
		"is_direct_pot",
		bank_class == "none" and not is_combination
	))
	var classification_tags: Array[String] = []
	if bank_class != "none":
		classification_tags.append(bank_class)
	if is_combination:
		classification_tags.append("combination")
	if cue_recontact_count > 0:
		classification_tags.append("cue_recontact")
	if object_tap_count > 0:
		classification_tags.append("object_ball_tap")
	if classification_tags.is_empty():
		classification_tags.append("direct_pot" if is_direct_pot else "scoring_route")
	var final_classification: String = bank_class
	if final_classification == "none":
		if is_combination:
			final_classification = "combination"
		elif is_direct_pot:
			final_classification = "direct_pot"
		elif cue_recontact_count > 0 or object_tap_count > 0:
			final_classification = "tap_route"
		else:
			final_classification = "scoring_route" if has_explicit_direct_fact else "direct_pot"
	var qualifying_indices: Array = _array_value(fact, "qualifying_rail_event_indices")
	var prediction_capped: bool = bool(
		ledger.get("prediction_capped", _dictionary_value(ledger, "diagnostics").get("prediction_capped", false))
	)
	var unsupported_prediction: bool = bool(
		ledger.get("unsupported_prediction", _dictionary_value(ledger, "diagnostics").get("unsupported_prediction", false))
	)
	return {
		"ball_id": ball_id,
		"ball_number": ball_number,
		"pocket_order": int(fact.get("pocket_order", 2147483647)),
		"pocket_index": int(fact.get("pocket_index", -1)),
		"pocket_event_index": int(fact.get("pocket_event_index", -1)),
		"final_classification": final_classification,
		"classification_tags": classification_tags,
		"is_combination": is_combination,
		"is_direct_pot": is_direct_pot,
		"cue_recontact_milestone_count": cue_recontact_count,
		"object_ball_tap_milestone_count": object_tap_count,
		"appearance": _make_appearance(ball_snapshot, ball_number),
		"events": [],
		"live_cue_sequence": [],
		"haul_contribution": 0,
		"mult_contribution": 0.0,
		"plan": {
			"source": source,
			"ball_id": ball_id,
			"expected_pocket_index": int(fact.get("pocket_index", -1)),
			"expected_pocket_event_index": int(fact.get("pocket_event_index", -1)),
			"predicted_scoring_classification": final_classification,
			"predicted_causal_activation_event_index": int(fact.get("causal_activation_event_index", -1)),
			"predicted_qualifying_rail_event_indices": qualifying_indices.duplicate(),
			"expected_bank_tier": mini(int(fact.get("bank_count", 0)), RogueliteScoreResolver.MAX_RAIL_MULT_PER_BALL),
			"expected_combination": is_combination,
			"expected_direct_pot": is_direct_pot,
			"expected_qualifying_cue_strike_count": _maximum_int_field(
				cue_recontact_milestones,
				"cue_strike_ordinal",
				1 if cue_recontact_count > 0 else 0
			),
			"expected_cue_recontact_milestone_count": cue_recontact_count,
			"expected_object_ball_tap_milestone_count": object_tap_count,
			"expected_object_ball_tap_target_ids": _int_field_array(
				object_ball_tap_milestones,
				"contacted_ball_id"
			),
			"expected_pocket_order": int(fact.get("pocket_order", 2147483647)),
			"expected_live_cue_sequence": [],
			"prediction_capped": prediction_capped,
			"unsupported_prediction": unsupported_prediction,
		},
	}


static func _make_appearance(snapshot: Dictionary, fallback_ball_number: int) -> Dictionary:
	var base_color: Color = Color.WHITE
	for color_key in ["base_color", "display_color", "color"]:
		var color_value: Variant = snapshot.get(color_key, null)
		if color_value is Color:
			base_color = color_value
			break
	var radius: float = float(snapshot.get("radius", 14.0))
	if not is_finite(radius) or radius <= 0.0:
		radius = 14.0
	return {
		"ball_kind": str(snapshot.get("ball_kind", "object")),
		"ball_number": int(snapshot.get("ball_number", fallback_ball_number)),
		"base_color": base_color,
		"radius": radius,
		"anomaly_type": str(snapshot.get("anomaly_type", "")),
	}


static func _make_physical_events(
	step: Dictionary,
	fact: Dictionary,
	event_lookup: Dictionary,
	diagnostics: Dictionary,
	starting_balls: Dictionary,
	tap_milestone_lookup: Dictionary
) -> Array[Dictionary]:
	var source_id: String = str(step.get("source_id", ""))
	if source_id == SOURCE_BANK_RAIL:
		return _make_rail_events(step, fact, event_lookup, diagnostics)
	if _is_cue_recontact_step(step):
		return [_make_canonical_tap_event(
			step,
			"cue_recontact_milestone",
			event_lookup,
			diagnostics,
			starting_balls,
			tap_milestone_lookup
		)]
	if _is_object_ball_tap_step(step):
		return [_make_canonical_tap_event(
			step,
			"object_ball_tap_milestone",
			event_lookup,
			diagnostics,
			starting_balls,
			tap_milestone_lookup
		)]
	var event_type: String = "ball_contribution"
	var live_title: String = str(step.get("display_name", "SCORE")).to_upper()
	var replay_title: String = live_title
	match source_id:
		SOURCE_BASE_HAUL:
			event_type = "pocket"
			live_title = "SUNK!"
			replay_title = "BALL SUNK"
		SOURCE_ADDITIONAL_BALL:
			event_type = "additional_ball"
			live_title = "MULTI-POT!"
			replay_title = "ADDITIONAL BALL"
		SOURCE_COMBINATION:
			event_type = "combination"
			live_title = "COMBINATION!"
			replay_title = "COMBINATION"
	var event: Dictionary = _make_event_from_step(step, event_type, live_title, replay_title)
	_apply_event_geometry(event, event_lookup, diagnostics)
	return [event]


static func _make_canonical_tap_event(
	step: Dictionary,
	event_type: String,
	event_lookup: Dictionary,
	diagnostics: Dictionary,
	starting_balls: Dictionary,
	tap_milestone_lookup: Dictionary
) -> Dictionary:
	var ball_id: int = int(step.get("ball_id", -1))
	var step_event_index: int = int(step.get("event_index", -1))
	var milestone_key: String = _tap_milestone_key(
		event_type,
		ball_id,
		step_event_index
	)
	var milestone: Dictionary = _dictionary_value(tap_milestone_lookup, milestone_key)
	if milestone.is_empty():
		_add_diagnostic_warning(
			diagnostics,
			"Canonical %s fact was unavailable for ball %d at event %d; live tap presentation was omitted."
			% [event_type, ball_id, step_event_index]
		)
		var fallback: Dictionary = _make_event_from_step(
			step,
			"ball_contribution",
			"SCORE",
			str(step.get("display_name", "SCORE")).to_upper()
		)
		fallback["canonical_milestone_valid"] = false
		return fallback
	var metadata: Dictionary = _dictionary_value(step, "metadata")
	var milestone_metadata: Dictionary = _dictionary_value(milestone, "metadata")
	var live_title: String = ""
	var replay_title: String = ""
	var ordinal: int = 1
	var tier_count: int = 1
	if event_type == "cue_recontact_milestone":
		var bonus_ordinal: int = maxi(int(milestone.get(
			"bonus_ordinal",
			metadata.get("bonus_ordinal", 1)
		)), 1)
		ordinal = maxi(int(milestone.get(
			"cue_strike_ordinal",
			metadata.get("cue_strike_ordinal", bonus_ordinal + 1)
		)), 2)
		live_title = _tap_title_from_display_tier(
			event_type,
			str(milestone.get("display_tier", "")),
			ordinal,
			true
		)
		replay_title = _tap_title_from_display_tier(
			event_type,
			str(milestone.get("display_tier", "")),
			ordinal,
			false
		)
		tier_count = maxi(int(milestone_metadata.get(
			"qualifying_cue_strike_count",
			metadata.get("qualifying_cue_strike_count", ordinal)
		)) - 1, 1)
	else:
		ordinal = maxi(int(milestone.get(
			"unique_contact_ordinal",
			metadata.get("unique_contact_ordinal", 1)
		)), 1)
		live_title = _tap_title_from_display_tier(
			event_type,
			str(milestone.get("display_tier", "")),
			ordinal,
			true
		)
		replay_title = _tap_title_from_display_tier(
			event_type,
			str(milestone.get("display_tier", "")),
			ordinal,
			false
		)
		tier_count = maxi(int(milestone_metadata.get(
			"unique_target_count",
			metadata.get("unique_target_count", ordinal)
		)), 1)
	var event: Dictionary = _make_event_from_step(
		step,
		event_type,
		live_title,
		replay_title
	)
	event["tap_family"] = (
		"cue_recontact" if event_type == "cue_recontact_milestone"
		else "object_ball_tap"
	)
	event["tap_ordinal"] = ordinal
	event["display_tier"] = str(milestone.get("display_tier", ""))
	event["trigger_occurrence_id"] = str(milestone.get(
		"trigger_occurrence_id",
		""
	))
	event["canonical_milestone_valid"] = true
	event["event_index"] = int(milestone.get("event_index", step_event_index))
	event["ball_id"] = int(milestone.get("ball_id", ball_id))
	event["ball_number"] = int(milestone.get(
		"ball_number",
		event.get("ball_number", -1)
	))
	event["tier_index"] = maxi(ordinal - (2 if event_type == "cue_recontact_milestone" else 1), 0)
	event["tier_count"] = tier_count
	event["cue_strike_ordinal"] = (
		ordinal if event_type == "cue_recontact_milestone" else 0
	)
	event["bonus_ordinal"] = (
		maxi(ordinal - 1, 1) if event_type == "cue_recontact_milestone" else 0
	)
	event["unique_contact_ordinal"] = (
		ordinal if event_type == "object_ball_tap_milestone" else 0
	)
	event["contacted_ball_id"] = int(milestone.get(
		"contacted_ball_id",
		metadata.get("contacted_ball_id", -1)
	))
	var canonical_position_value: Variant = milestone.get(
		"world_position",
		Vector2.INF
	)
	var canonical_position: Vector2 = (
		canonical_position_value as Vector2
		if canonical_position_value is Vector2
		else Vector2.INF
	)
	if _is_finite_position(canonical_position):
		event["world_position"] = canonical_position
		event["world_position_valid"] = true
		event["anchor_type"] = "world"
		event["coordinate_space"] = "global_canvas"
	else:
		event["world_position_valid"] = false
		_add_diagnostic_warning(
			diagnostics,
			"Canonical %s fact for ball %d has no finite world position."
			% [event_type, ball_id]
		)
	_apply_tap_contact_geometry(
		event,
		event_lookup,
		starting_balls,
		canonical_position
	)
	return event


static func _apply_tap_contact_geometry(
	event: Dictionary,
	event_lookup: Dictionary,
	starting_balls: Dictionary,
	canonical_position: Vector2
) -> void:
	var raw_event: Dictionary = _event_at(event_lookup, int(event.get("event_index", -1)))
	if str(raw_event.get("event_type", "")) != "ball_contact":
		return
	var contact_position: Vector2 = canonical_position
	if not _is_finite_position(contact_position):
		contact_position = _event_position(raw_event)
	if not _is_finite_position(contact_position):
		return
	var scoring_ball_id: int = int(event.get("ball_id", -1))
	var ball_a_id: int = int(raw_event.get("ball_a_id", -1))
	var ball_b_id: int = int(raw_event.get("ball_b_id", -1))
	var source_ball_id: int = int(raw_event.get("source_ball_id", -1))
	var target_ball_id: int = int(raw_event.get("target_ball_id", -1))
	var contacted_ball_id: int = int(event.get("contacted_ball_id", -1))
	if contacted_ball_id <= 0:
		if scoring_ball_id == source_ball_id:
			contacted_ball_id = target_ball_id
		elif scoring_ball_id == target_ball_id:
			contacted_ball_id = source_ball_id
		elif scoring_ball_id == ball_a_id:
			contacted_ball_id = ball_b_id
		elif scoring_ball_id == ball_b_id:
			contacted_ball_id = ball_a_id
	var scoring_snapshot: Dictionary = _get_ball_snapshot(starting_balls, scoring_ball_id)
	var contacted_snapshot: Dictionary = _get_ball_snapshot(starting_balls, contacted_ball_id)
	var contact_normal_value: Variant = raw_event.get(
		"contact_normal",
		raw_event.get("collision_normal", Vector2.ZERO)
	)
	var contact_normal: Vector2 = (
		contact_normal_value as Vector2 if contact_normal_value is Vector2 else Vector2.ZERO
	)
	if contact_normal != Vector2.ZERO:
		contact_normal = contact_normal.normalized()
	var scoring_radius: float = maxf(float(scoring_snapshot.get("radius", 14.0)), 0.0)
	var contacted_radius: float = maxf(float(contacted_snapshot.get("radius", 14.0)), 0.0)
	var scoring_center: Vector2 = contact_position
	var contacted_center: Vector2 = contact_position
	if contact_normal != Vector2.ZERO:
		if scoring_ball_id == ball_a_id:
			scoring_center = contact_position - contact_normal * scoring_radius
			contacted_center = contact_position + contact_normal * contacted_radius
		elif scoring_ball_id == ball_b_id:
			scoring_center = contact_position + contact_normal * scoring_radius
			contacted_center = contact_position - contact_normal * contacted_radius
	event["contact_world_position"] = contact_position
	event["scoring_ball_world_position"] = scoring_center
	event["contacted_ball_world_position"] = contacted_center
	event["contacted_ball_world_position_valid"] = _is_finite_position(contacted_center)
	event["contact_normal"] = contact_normal
	event["source_ball_id"] = source_ball_id
	event["target_ball_id"] = target_ball_id
	event["contacted_ball_id"] = contacted_ball_id
	event["contacted_ball_number"] = int(contacted_snapshot.get(
		"ball_number",
		raw_event.get("source_ball_number", raw_event.get("target_ball_number", -1))
	))
	event["contacted_ball_is_cue"] = str(contacted_snapshot.get("ball_kind", "")) == "cue"
	event["contacted_ball_appearance"] = _make_appearance(
		contacted_snapshot,
		int(event.get("contacted_ball_number", -1))
	)
	if _is_finite_position(contact_position):
		event["world_position"] = contact_position
		event["world_position_valid"] = true
		event["anchor_type"] = "world"
		event["coordinate_space"] = "global_canvas"


static func _is_cue_recontact_step(step: Dictionary) -> bool:
	var source_id: String = str(step.get("source_id", ""))
	var source_type: String = str(step.get("source_type", ""))
	var metadata: Dictionary = _dictionary_value(step, "metadata")
	var trigger_id: String = str(metadata.get("trigger_id", ""))
	return (
		source_id in [SOURCE_CUE_RECONTACT, SOURCE_CUE_RECONTACT_MILESTONE]
		or source_type in [SOURCE_CUE_RECONTACT, SOURCE_CUE_RECONTACT_MILESTONE]
		or trigger_id == SOURCE_CUE_RECONTACT_MILESTONE
	)


static func _is_object_ball_tap_step(step: Dictionary) -> bool:
	var source_id: String = str(step.get("source_id", ""))
	var source_type: String = str(step.get("source_type", ""))
	var metadata: Dictionary = _dictionary_value(step, "metadata")
	var trigger_id: String = str(metadata.get("trigger_id", ""))
	return (
		source_id in [SOURCE_OBJECT_BALL_TAP, SOURCE_OBJECT_BALL_TAP_MILESTONE]
		or source_type in [SOURCE_OBJECT_BALL_TAP, SOURCE_OBJECT_BALL_TAP_MILESTONE]
		or trigger_id == SOURCE_OBJECT_BALL_TAP_MILESTONE
	)


static func _make_rail_events(
	step: Dictionary,
	fact: Dictionary,
	event_lookup: Dictionary,
	diagnostics: Dictionary
) -> Array[Dictionary]:
	var metadata: Dictionary = _dictionary_value(step, "metadata")
	var grouped_delta: float = float(step.get("mult_delta", 0.0))
	var grouped_count: int = int(metadata.get("capped_count", step.get("mult_delta", 0)))
	var indices: Array[int] = _int_array(_array_value(metadata, "scored_rail_event_indices"))
	var qualifying_indices: Array[int] = _int_array(_array_value(fact, "qualifying_rail_event_indices"))
	var partition_reason: String = _get_rail_partition_rejection(
		int(step.get("ball_id", -1)),
		grouped_delta,
		grouped_count,
		indices,
		qualifying_indices,
		event_lookup
	)
	if partition_reason.is_empty():
		var partitioned: Array[Dictionary] = []
		for tier_index in range(indices.size()):
			var rail_event_index: int = indices[tier_index]
			var event: Dictionary = _make_event_from_step(
				step,
				"rail_milestone",
				_bank_live_title(tier_index, indices.size()),
				_bank_replay_title(tier_index)
			)
			event["event_index"] = rail_event_index
			event["source_event_indices"] = [rail_event_index]
			event["mult_delta"] = 1.0
			event["effect_text"] = "+1 MULT"
			event["tier_index"] = tier_index
			event["tier_count"] = indices.size()
			event["partitioned_from_group"] = true
			_apply_event_geometry(event, event_lookup, diagnostics)
			partitioned.append(event)
		diagnostics["rail_groups_partitioned"] = int(diagnostics.get("rail_groups_partitioned", 0)) + 1
		diagnostics["partitioned_rail_event_count"] = int(diagnostics.get("partitioned_rail_event_count", 0)) + partitioned.size()
		return partitioned

	var warning: String = "Rail contribution step %d stayed grouped: %s" % [
		int(step.get("step_index", -1)), partition_reason,
	]
	_add_diagnostic_warning(diagnostics, warning)
	diagnostics["rail_groups_fallback"] = int(diagnostics.get("rail_groups_fallback", 0)) + 1
	var grouped_event: Dictionary = _make_event_from_step(
		step,
		"rail_group",
		_bank_live_title(maxi(grouped_count - 1, 0), maxi(grouped_count, 1)),
		_bank_group_title(grouped_count)
	)
	grouped_event["tier_index"] = maxi(grouped_count - 1, 0)
	grouped_event["tier_count"] = maxi(grouped_count, 1)
	grouped_event["partitioned_from_group"] = false
	grouped_event["partition_fallback_reason"] = partition_reason
	grouped_event["source_event_indices"] = indices.duplicate()
	_apply_grouped_rail_geometry(grouped_event, indices, metadata, event_lookup, diagnostics)
	return [grouped_event]


static func _get_rail_partition_rejection(
	ball_id: int,
	grouped_delta: float,
	grouped_count: int,
	indices: Array[int],
	qualifying_indices: Array[int],
	event_lookup: Dictionary
) -> String:
	if grouped_count < 1 or grouped_count > RogueliteScoreResolver.MAX_RAIL_MULT_PER_BALL:
		return "grouped rail count %d is outside the supported capped range" % grouped_count
	if not is_equal_approx(grouped_delta, float(grouped_count)):
		return "immutable Mult delta %s does not equal grouped count %d" % [grouped_delta, grouped_count]
	if indices.size() != grouped_count:
		return "expected %d exact rail indices but received %d" % [grouped_count, indices.size()]
	if qualifying_indices.size() < grouped_count:
		return "analyzed facts contain fewer than %d qualifying rails" % grouped_count
	var expected_indices: Array[int] = []
	for index in range(grouped_count):
		expected_indices.append(qualifying_indices[index])
	if indices != expected_indices:
		return "resolver rail indices do not match the analyzed qualifying prefix"
	var seen: Dictionary = {}
	var previous_index: int = -1
	for event_index in indices:
		if event_index < 0 or seen.has(str(event_index)):
			return "rail indices are invalid or duplicated"
		if previous_index >= event_index:
			return "rail indices are not chronological"
		seen[str(event_index)] = true
		previous_index = event_index
		var event: Dictionary = _event_at(event_lookup, event_index)
		if str(event.get("event_type", "")) != "rail_contact":
			return "event %d is not an accepted rail contact" % event_index
		var event_ball_id: int = int(event.get("ball_id", -1))
		if event_ball_id >= 0 and event_ball_id != ball_id:
			return "event %d belongs to ball %d instead of ball %d" % [event_index, event_ball_id, ball_id]
		if not _is_finite_position(_event_position(event)):
			return "event %d has no finite rail contact position" % event_index
	return ""


static func _make_event_from_step(
	step: Dictionary,
	event_type: String,
	live_title: String,
	replay_title: String
) -> Dictionary:
	var step_index: int = int(step.get("step_index", -1))
	return {
		"narrative_event_index": -1,
		"sequence_index": -1,
		"event_type": event_type,
		"source_id": str(step.get("source_id", "")),
		"source_type": str(step.get("source_type", "")),
		"phase": str(step.get("phase", "")),
		"event_index": int(step.get("event_index", -1)),
		"source_event_indices": [int(step.get("event_index", -1))] if int(step.get("event_index", -1)) >= 0 else [],
		"ball_id": int(step.get("ball_id", -1)),
		"live_title": live_title,
		"replay_title": replay_title,
		"effect_text": _effect_text(step),
		"haul_delta": int(step.get("haul_delta", 0)),
		"mult_delta": float(step.get("mult_delta", 0.0)),
		"xmult_factor": float(step.get("xmult_factor", 1.0)),
		"display_haul_before": 0,
		"display_haul_after": 0,
		"display_mult_before": 1.0,
		"display_mult_after": 1.0,
		"display_score_before": 0,
		"display_score_after": 0,
		"tier_index": 0,
		"tier_count": 1,
		"source_step_indices": [step_index],
		"affects_score": bool(step.get("affects_score", true)),
		"world_position": Vector2.ZERO,
		"world_position_valid": false,
		"anchor_type": "hud",
		"coordinate_space": "hud",
		"pocket_index": -1,
		"rail_id": "",
		"fallback_used": false,
		"fallback_reason": "",
		"metadata": _dictionary_value(step, "metadata").duplicate(true),
	}


static func _make_engine_event(step: Dictionary) -> Dictionary:
	var phase: String = str(step.get("phase", ""))
	var event_type: String = "xmult" if phase == RogueliteScoreResolver.PHASE_XMULT else "modifier"
	var metadata: Dictionary = _dictionary_value(step, "metadata").duplicate(true)
	var is_retrigger: bool = bool(metadata.get("is_retrigger", step.get("is_retrigger", false)))
	var replay_title: String = str(step.get("display_name", "MODIFIER")).to_upper()
	if is_retrigger:
		replay_title += " - RETRIGGER"
	var event: Dictionary = _make_event_from_step(
		step,
		event_type,
		str(step.get("display_name", "MODIFIER")).to_upper(),
		replay_title
	)
	event["anchor_type"] = "hud"
	event["coordinate_space"] = "hud"
	event["canonical_haul_before"] = int(step.get("haul_before", 0))
	event["canonical_haul_after"] = int(step.get("haul_after", 0))
	event["canonical_mult_before"] = float(step.get("mult_before", 1.0))
	event["canonical_mult_after"] = float(step.get("mult_after", 1.0))
	event["canonical_score_after"] = int(step.get("score_preview_after", 0))
	event["is_retrigger"] = is_retrigger
	event["retrigger_index"] = int(metadata.get("retrigger_index", step.get("retrigger_index", 0)))
	event["retrigger_source_item_id"] = str(metadata.get(
		"retrigger_source_item_id",
		step.get("retrigger_source_item_id", "")
	))
	event["retrigger_source_slot_index"] = int(metadata.get(
		"retrigger_source_slot_index",
		metadata.get(
			"retrigger_source_tray_slot_index",
			step.get("retrigger_source_slot_index", -1)
		)
	))
	event["original_activation_id"] = str(metadata.get(
		"original_activation_id",
		step.get("original_activation_id", "")
	))
	event["trigger_occurrence_id"] = str(metadata.get(
		"trigger_occurrence_id",
		step.get("trigger_occurrence_id", "")
	))
	return event


static func _insert_authoritative_retrigger_markers(
	canonical_engine_events: Array[Dictionary]
) -> Array[Dictionary]:
	var expanded: Array[Dictionary] = []
	var marked_occurrences: Dictionary = {}
	for engine_event in canonical_engine_events:
		var metadata: Dictionary = _dictionary_value(engine_event, "metadata")
		if bool(metadata.get("is_retrigger", engine_event.get("is_retrigger", false))):
			var source_item_id: String = str(metadata.get(
				"retrigger_source_item_id",
				engine_event.get("retrigger_source_item_id", "")
			))
			var occurrence_key: String = _get_retrigger_occurrence_key(
				engine_event,
				metadata,
				source_item_id
			)
			if source_item_id == DEAD_RECKONING_ITEM_ID and not marked_occurrences.has(occurrence_key):
				expanded.append(_make_retrigger_marker(engine_event, metadata, source_item_id))
				marked_occurrences[occurrence_key] = true
		expanded.append(engine_event.duplicate(true))
	return expanded


static func _make_retrigger_marker(
	retrigger_event: Dictionary,
	retrigger_metadata: Dictionary,
	source_item_id: String
) -> Dictionary:
	var source_display_name: String = str(retrigger_metadata.get(
		"retrigger_source_display_name",
		"Dead Reckoning" if source_item_id == DEAD_RECKONING_ITEM_ID else source_item_id.replace("_", " ").capitalize()
	))
	var source_slot_index: int = int(retrigger_metadata.get(
		"retrigger_source_slot_index",
		retrigger_metadata.get(
			"retrigger_source_tray_slot_index",
			retrigger_event.get("retrigger_source_slot_index", -1)
		)
	))
	return {
		"narrative_event_index": -1,
		"sequence_index": -1,
		"event_type": "retrigger_marker",
		"source_id": source_item_id,
		"source_type": "presentation_marker",
		"phase": "engine_marker",
		"event_index": int(retrigger_event.get("event_index", -1)),
		"source_event_indices": _array_value(retrigger_event, "source_event_indices").duplicate(),
		"ball_id": -1,
		"live_title": source_display_name.to_upper(),
		"replay_title": source_display_name.to_upper(),
		"effect_text": RETRIGGER_MARKER_EFFECT,
		"haul_delta": 0,
		"mult_delta": 0.0,
		"xmult_factor": 1.0,
		"display_haul_before": 0,
		"display_haul_after": 0,
		"display_mult_before": 1.0,
		"display_mult_after": 1.0,
		"display_score_before": 0,
		"display_score_after": 0,
		"tier_index": 0,
		"tier_count": 1,
		"source_step_indices": [],
		"affects_score": true,
		"world_position": Vector2.ZERO,
		"world_position_valid": false,
		"anchor_type": "hud",
		"coordinate_space": "hud",
		"pocket_index": -1,
		"rail_id": "",
		"fallback_used": false,
		"fallback_reason": "",
		"presentation_only_marker": true,
		"is_retrigger_marker": true,
		"metadata": {
			"is_retrigger_marker": true,
			"eight_ball_item_id": source_item_id,
			"slot_index": source_slot_index,
			"retrigger_source_item_id": source_item_id,
			"trigger_occurrence_id": str(retrigger_metadata.get("trigger_occurrence_id", "")),
		},
	}


static func _get_retrigger_occurrence_key(
	event: Dictionary,
	metadata: Dictionary,
	source_item_id: String
) -> String:
	var occurrence_id: String = str(metadata.get(
		"trigger_occurrence_id",
		event.get("trigger_occurrence_id", "")
	))
	if not occurrence_id.is_empty():
		return "%s|%s" % [source_item_id, occurrence_id]
	return "%s|event:%d" % [source_item_id, int(event.get("event_index", -1))]


static func _count_retrigger_events(events: Array[Dictionary]) -> int:
	var count: int = 0
	for event in events:
		if bool(event.get("is_retrigger", false)):
			count += 1
	return count


static func _make_consequence_event(step: Dictionary, event_lookup: Dictionary, diagnostics: Dictionary) -> Dictionary:
	var event: Dictionary = _make_event_from_step(
		step,
		"scratch" if str(step.get("source_id", "")) == SOURCE_SCRATCH else "consequence",
		str(step.get("display_name", "CONSEQUENCE")).to_upper(),
		str(step.get("display_name", "CONSEQUENCE")).to_upper()
	)
	_apply_event_geometry(event, event_lookup, diagnostics)
	return event


static func _apply_event_geometry(event: Dictionary, event_lookup: Dictionary, diagnostics: Dictionary) -> void:
	var event_index: int = int(event.get("event_index", -1))
	var raw_event: Dictionary = _event_at(event_lookup, event_index)
	if raw_event.is_empty():
		_note_missing_event(event_index, diagnostics)
		event["fallback_used"] = true
		event["fallback_reason"] = "Event %d was unavailable; equation HUD fallback used." % event_index
		return
	var position: Vector2 = _event_position(raw_event)
	if not _is_finite_position(position):
		diagnostics["invalid_position_count"] = int(diagnostics.get("invalid_position_count", 0)) + 1
		event["fallback_used"] = true
		event["fallback_reason"] = "Event %d had no finite presentation position." % event_index
		return
	event["world_position"] = position
	event["world_position_valid"] = true
	event["anchor_type"] = "world"
	event["coordinate_space"] = "global_canvas"
	event["pocket_index"] = int(raw_event.get("pocket_index", -1))
	event["rail_id"] = str(raw_event.get("rail_id", ""))


static func _apply_grouped_rail_geometry(
	event: Dictionary,
	indices: Array[int],
	metadata: Dictionary,
	event_lookup: Dictionary,
	diagnostics: Dictionary
) -> void:
	for reverse_index in range(indices.size() - 1, -1, -1):
		var rail_event_index: int = indices[reverse_index]
		var raw_event: Dictionary = _event_at(event_lookup, rail_event_index)
		if str(raw_event.get("event_type", "")) != "rail_contact":
			continue
		var position: Vector2 = _event_position(raw_event)
		if not _is_finite_position(position):
			continue
		event["event_index"] = rail_event_index
		event["world_position"] = position
		event["world_position_valid"] = true
		event["anchor_type"] = "world"
		event["coordinate_space"] = "global_canvas"
		event["rail_id"] = str(raw_event.get("rail_id", ""))
		return
	var pocket_event_index: int = int(metadata.get("pocket_event_index", -1))
	var pocket_event: Dictionary = _event_at(event_lookup, pocket_event_index)
	var pocket_position: Vector2 = _event_position(pocket_event)
	if str(pocket_event.get("event_type", "")) == "pocket" and _is_finite_position(pocket_position):
		event["event_index"] = pocket_event_index
		event["world_position"] = pocket_position
		event["world_position_valid"] = true
		event["anchor_type"] = "world"
		event["coordinate_space"] = "global_canvas"
		event["pocket_index"] = int(pocket_event.get("pocket_index", -1))
		event["fallback_used"] = true
		event["fallback_reason"] = "Grouped rail geometry used the scoring pocket fallback."
		return
	event["fallback_used"] = true
	event["fallback_reason"] = "Grouped rail geometry was unavailable; equation HUD fallback used."
	_note_missing_event(pocket_event_index, diagnostics)


static func _apply_reordered_display_state(event: Dictionary, state: Dictionary) -> void:
	var haul_before: int = int(state.get("haul", 0))
	var mult_before: float = float(state.get("mult", 1.0))
	var haul_after: int = haul_before + int(event.get("haul_delta", 0))
	var mult_after: float = mult_before + float(event.get("mult_delta", 0.0))
	var xmult_factor: float = float(event.get("xmult_factor", 1.0))
	if not is_equal_approx(xmult_factor, 1.0):
		mult_after *= xmult_factor
	event["display_haul_before"] = haul_before
	event["display_haul_after"] = haul_after
	event["display_mult_before"] = mult_before
	event["display_mult_after"] = mult_after
	event["display_score_before"] = _score_preview(haul_before, mult_before)
	event["display_score_after"] = _score_preview(haul_after, mult_after)
	state["haul"] = haul_after
	state["mult"] = mult_after


static func _apply_canonical_display_state(event: Dictionary, state: Dictionary) -> void:
	var state_haul_before: int = int(state.get("haul", 0))
	var state_mult_before: float = float(state.get("mult", 1.0))
	var haul_before: int = int(event.get("canonical_haul_before", state.get("haul", 0)))
	var mult_before: float = float(event.get("canonical_mult_before", state.get("mult", 1.0)))
	var haul_after: int = int(event.get("canonical_haul_after", haul_before))
	var mult_after: float = float(event.get("canonical_mult_after", mult_before))
	event["display_continuity_matches"] = (
		state_haul_before == haul_before
		and is_equal_approx(state_mult_before, mult_before)
	)
	event["display_haul_before"] = haul_before
	event["display_haul_after"] = haul_after
	event["display_mult_before"] = mult_before
	event["display_mult_after"] = mult_after
	event["display_score_before"] = _score_preview(haul_before, mult_before)
	event["display_score_after"] = int(event.get("canonical_score_after", _score_preview(haul_after, mult_after)))
	state["haul"] = haul_after
	state["mult"] = mult_after


static func _apply_informational_display_state(event: Dictionary, state: Dictionary) -> void:
	var haul: int = int(state.get("haul", 0))
	var mult: float = float(state.get("mult", 1.0))
	event["display_haul_before"] = haul
	event["display_haul_after"] = haul
	event["display_mult_before"] = mult
	event["display_mult_after"] = mult
	event["display_score_before"] = _score_preview(haul, mult)
	event["display_score_after"] = _score_preview(haul, mult)


static func _finalize_validation(
	result: Dictionary,
	score_result: Dictionary,
	pocket_facts: Array[Dictionary],
	resolution_steps: Array,
	canonical_scoring_step_indices: Array[int],
	canonical_engine_step_indices: Array[int],
	canonical_xmult_step_indices: Array[int],
	step_owners: Dictionary
) -> void:
	var validation: Dictionary = _dictionary_value(result, "validation")
	var checks: Dictionary = {}
	var ball_narratives: Array = _array_value(result, "ball_narratives")
	var physical_events: Array = _array_value(result, "physical_events")
	var engine_events: Array = _array_value(result, "engine_events")
	var represented_scoring_indices: Array[int] = []
	for step_index in canonical_scoring_step_indices:
		if step_owners.has(str(step_index)):
			represented_scoring_indices.append(step_index)
	represented_scoring_indices.sort()
	var expected_scoring_indices: Array[int] = canonical_scoring_step_indices.duplicate()
	expected_scoring_indices.sort()
	checks["all_scoring_steps_represented_once"] = represented_scoring_indices == expected_scoring_indices

	var expected_physical_haul: int = 0
	var expected_physical_mult: float = 0.0
	for step_value in resolution_steps:
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		if not bool(step.get("affects_score", true)):
			continue
		if str(step.get("source_type", "")) == "modifier" or int(step.get("ball_id", -1)) <= 0:
			continue
		expected_physical_haul += int(step.get("haul_delta", 0))
		expected_physical_mult += float(step.get("mult_delta", 0.0))
	checks["physical_haul_represented_exactly"] = _sum_int_field(physical_events, "haul_delta") == expected_physical_haul
	checks["physical_mult_represented_exactly"] = is_equal_approx(
		_sum_float_field(physical_events, "mult_delta"), expected_physical_mult
	)
	checks["physical_step_deltas_match_individually"] = _physical_step_deltas_match(
		physical_events,
		resolution_steps
	)

	var engine_indices: Array[int] = _event_source_step_indices(engine_events)
	checks["engine_order_is_canonical"] = engine_indices == canonical_engine_step_indices
	var engine_state_continuity: bool = true
	for engine_event_value in engine_events:
		if engine_event_value is Dictionary and not bool((engine_event_value as Dictionary).get("display_continuity_matches", false)):
			engine_state_continuity = false
			break
	checks["engine_state_continuity"] = engine_state_continuity
	var xmult_indices: Array[int] = []
	for engine_event_value in engine_events:
		if not engine_event_value is Dictionary:
			continue
		var engine_event: Dictionary = engine_event_value
		if str(engine_event.get("event_type", "")) != "xmult":
			continue
		var source_indices: Array = _array_value(engine_event, "source_step_indices")
		if not source_indices.is_empty():
			xmult_indices.append(int(source_indices[0]))
	checks["xmult_order_is_canonical"] = xmult_indices == canonical_xmult_step_indices

	var narrative_ball_ids: Dictionary = {}
	for narrative_value in ball_narratives:
		if narrative_value is Dictionary:
			narrative_ball_ids[str(int((narrative_value as Dictionary).get("ball_id", -1)))] = true
	var omitted_ball_ids: Array[int] = []
	for fact in pocket_facts:
		var ball_id: int = int(fact.get("ball_id", -1))
		if ball_id > 0 and not narrative_ball_ids.has(str(ball_id)):
			omitted_ball_ids.append(ball_id)
	checks["no_scoring_ball_omitted"] = omitted_ball_ids.is_empty()

	var immutable_final_haul: int = int(score_result.get("final_haul", 0))
	var immutable_final_mult: float = float(score_result.get("final_mult", RogueliteScoreResolver.BASE_MULT))
	var immutable_final_score: int = int(score_result.get("shot_score", 0))
	checks["display_final_haul_matches"] = int(result.get("display_final_haul", -1)) == immutable_final_haul
	checks["display_final_mult_matches"] = is_equal_approx(
		float(result.get("display_final_mult", -1.0)), immutable_final_mult
	)
	checks["display_final_score_matches"] = int(result.get("display_final_score", -1)) == immutable_final_score
	checks["immutable_final_arithmetic_matches"] = _score_preview(immutable_final_haul, immutable_final_mult) == immutable_final_score
	checks["output_has_no_live_node_references"] = not _contains_live_node_reference(result)

	if not bool(checks["all_scoring_steps_represented_once"]):
		_add_error(validation, "One or more canonical scoring steps were omitted or owned more than once.")
	if not bool(checks["physical_haul_represented_exactly"]):
		_add_error(validation, "Narrative Haul contributions do not equal the immutable physical Haul contributions.")
	if not bool(checks["physical_mult_represented_exactly"]):
		_add_error(validation, "Narrative Mult contributions do not equal the immutable physical Mult contributions.")
	if not bool(checks["physical_step_deltas_match_individually"]):
		_add_error(validation, "At least one physical contribution was not represented by its exact immutable step delta.")
	if not bool(checks["engine_order_is_canonical"]):
		_add_error(validation, "Engine/modifier steps are not in canonical resolver order.")
	if not bool(checks["engine_state_continuity"]):
		_add_error(validation, "Reordered ball presentation did not hand off the canonical modifier input state.")
	if not bool(checks["xmult_order_is_canonical"]):
		_add_error(validation, "xMult steps are not in canonical resolver order.")
	if not bool(checks["no_scoring_ball_omitted"]):
		_add_error(validation, "Pocketed scoring balls were omitted: %s" % str(omitted_ball_ids))
	if not bool(checks["display_final_haul_matches"]):
		_add_error(validation, "Presentation Haul does not land on immutable Final Haul.")
	if not bool(checks["display_final_mult_matches"]):
		_add_error(validation, "Presentation Mult does not land on immutable Final Mult.")
	if not bool(checks["display_final_score_matches"]):
		_add_error(validation, "Presentation Score does not land on immutable Shot Score.")
	if not bool(checks["immutable_final_arithmetic_matches"]):
		_add_error(validation, "Immutable Shot Score does not equal floor(Final Haul x Final Mult).")
	if not bool(checks["output_has_no_live_node_references"]):
		_add_error(validation, "Narrative output unexpectedly contains a live Node reference.")

	var errors: Array = _array_value(validation, "errors")
	var valid: bool = errors.is_empty()
	validation["checks"] = checks
	validation["status"] = "PASS" if valid else "FAIL"
	validation["valid"] = valid
	validation["fancy_replay_allowed"] = valid
	validation["fallback_required"] = not valid
	validation["represented_scoring_step_indices"] = represented_scoring_indices
	validation["omitted_ball_ids"] = omitted_ball_ids
	result["validation"] = validation
	var fallback: Dictionary = _dictionary_value(result, "fallback")
	fallback["required"] = not valid
	fallback["reason"] = "" if valid else "Narrative validation failed; use canonical resolution steps."
	fallback["canonical_resolution_steps"] = [] if valid else resolution_steps.duplicate(true)
	result["fallback"] = fallback


static func _finalize_input_failure(
	result: Dictionary,
	reason: String,
	ledger: Dictionary,
	score_result: Dictionary
) -> Dictionary:
	var validation: Dictionary = _dictionary_value(result, "validation")
	_add_error(validation, reason)
	validation["status"] = "FAIL"
	validation["valid"] = false
	validation["fancy_replay_allowed"] = false
	validation["fallback_required"] = true
	validation["checks"] = {"input_valid": false}
	result["validation"] = validation
	var fallback: Dictionary = _dictionary_value(result, "fallback")
	fallback["required"] = true
	fallback["reason"] = reason
	if not _contains_live_node_reference(ledger) and not _contains_live_node_reference(score_result):
		fallback["canonical_resolution_steps"] = _array_value(score_result, "resolution_steps").duplicate(true)
	result["fallback"] = fallback
	var diagnostics: Dictionary = _dictionary_value(result, "diagnostics")
	_add_diagnostic_warning(diagnostics, reason)
	result["diagnostics"] = diagnostics
	return result.duplicate(true)


static func _build_event_lookup(ledger: Dictionary, diagnostics: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for event_value in _array_value(ledger, "raw_events"):
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var event_index: int = int(event.get("event_index", -1))
		var key: String = str(event_index)
		if event_index < 0:
			continue
		if lookup.has(key):
			diagnostics["duplicate_event_index_count"] = int(diagnostics.get("duplicate_event_index_count", 0)) + 1
			continue
		lookup[key] = event.duplicate(true)
	return lookup


static func _build_tap_milestone_lookup(
	derived: Dictionary,
	diagnostics: Dictionary
) -> Dictionary:
	var lookup: Dictionary = {}
	var canonical_count: int = 0
	for definition_value in [
		{
			"array_key": "cue_recontact_milestones",
			"event_type": "cue_recontact_milestone",
		},
		{
			"array_key": "object_ball_tap_milestones",
			"event_type": "object_ball_tap_milestone",
		},
	]:
		var definition: Dictionary = definition_value
		var event_type: String = str(definition.get("event_type", ""))
		for milestone_value in _array_value(derived, str(definition.get(
			"array_key",
			""
		))):
			if not milestone_value is Dictionary:
				_add_diagnostic_warning(
					diagnostics,
					"A canonical %s fact was not a Dictionary and was ignored."
					% event_type
				)
				continue
			var milestone: Dictionary = (milestone_value as Dictionary).duplicate(true)
			var ball_id: int = int(milestone.get("ball_id", -1))
			var event_index: int = int(milestone.get("event_index", -1))
			if ball_id <= 0 or event_index < 0:
				_add_diagnostic_warning(
					diagnostics,
					"A canonical %s fact had an invalid ball or event index."
					% event_type
				)
				continue
			var key: String = _tap_milestone_key(event_type, ball_id, event_index)
			if lookup.has(key):
				_add_diagnostic_warning(
					diagnostics,
					"Duplicate canonical %s fact `%s` was ignored."
					% [event_type, key]
				)
				continue
			milestone["event_type"] = event_type
			lookup[key] = milestone
			canonical_count += 1
	diagnostics["canonical_tap_milestone_count"] = canonical_count
	return lookup


static func _tap_milestone_key(
	event_type: String,
	ball_id: int,
	event_index: int
) -> String:
	return "%s:%d:%d" % [event_type, ball_id, event_index]


static func _canonical_milestones_for_ball(
	derived: Dictionary,
	array_key: String,
	ball_id: int
) -> Array[Dictionary]:
	var milestones: Array[Dictionary] = []
	for milestone_value in _array_value(derived, array_key):
		if (
			milestone_value is Dictionary
			and int((milestone_value as Dictionary).get("ball_id", -1)) == ball_id
		):
			milestones.append((milestone_value as Dictionary).duplicate(true))
	milestones.sort_custom(_canonical_milestone_precedes)
	return milestones


static func _canonical_milestone_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_event_index: int = int(left.get("event_index", 2147483647))
	var right_event_index: int = int(right.get("event_index", 2147483647))
	if left_event_index != right_event_index:
		return left_event_index < right_event_index
	return str(left.get("trigger_occurrence_id", "")) < str(
		right.get("trigger_occurrence_id", "")
	)


static func _maximum_int_field(
	values: Array[Dictionary],
	key: String,
	fallback: int
) -> int:
	var maximum: int = fallback
	for value in values:
		maximum = maxi(maximum, int(value.get(key, fallback)))
	return maximum


static func _int_field_array(values: Array[Dictionary], key: String) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		var field_value: int = int(value.get(key, -1))
		if field_value > 0:
			result.append(field_value)
	return result


static func _build_pocket_fact_lookup(pocket_facts: Array[Dictionary]) -> Dictionary:
	var lookup: Dictionary = {}
	for fact in pocket_facts:
		lookup[str(int(fact.get("ball_id", -1)))] = fact.duplicate(true)
	return lookup


static func _get_sorted_pocket_facts(derived: Dictionary, diagnostics: Dictionary) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	for fact_value in _array_value(derived, "pocket_facts"):
		if not fact_value is Dictionary:
			_add_diagnostic_warning(diagnostics, "A pocket fact was not a Dictionary and was ignored.")
			continue
		facts.append((fact_value as Dictionary).duplicate(true))
	facts.sort_custom(_pocket_fact_precedes)
	return facts


static func _register_step_owner(
	step_owners: Dictionary,
	step_index: int,
	owner: String,
	validation: Dictionary
) -> void:
	var key: String = str(step_index)
	if step_owners.has(key):
		_add_error(validation, "Resolution step %d has multiple narrative owners." % step_index)
		return
	step_owners[key] = owner


static func _make_live_cue_sequence(events: Array) -> Array[Dictionary]:
	var sequence: Array[Dictionary] = []
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		sequence.append({
			"event_type": str(event.get("event_type", "")),
			"event_index": int(event.get("event_index", -1)),
			"live_title": str(event.get("live_title", "")),
			"tier_index": int(event.get("tier_index", 0)),
			"tier_count": int(event.get("tier_count", 1)),
			"tap_family": str(event.get("tap_family", "")),
			"tap_ordinal": int(event.get("tap_ordinal", 0)),
			"contacted_ball_id": int(event.get("contacted_ball_id", -1)),
		})
	return sequence


static func _event_position(event: Dictionary) -> Vector2:
	var event_type: String = str(event.get("event_type", ""))
	var keys: Array[String] = []
	match event_type:
		"pocket":
			keys = ["pocket_center", "capture_position", "contact_point", "position"]
		"rail_contact", "ball_contact":
			keys = ["contact_point", "position"]
		_:
			keys = ["contact_point", "pocket_center", "capture_position", "position"]
	for key in keys:
		var position_value: Variant = event.get(key, null)
		if position_value is Vector2 and _is_finite_position(position_value):
			return position_value
	return Vector2(INF, INF)


static func _event_at(lookup: Dictionary, event_index: int) -> Dictionary:
	var value: Variant = lookup.get(str(event_index), {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _get_ball_snapshot(starting_balls: Dictionary, ball_id: int) -> Dictionary:
	var value: Variant = starting_balls.get(str(ball_id), starting_balls.get(ball_id, {}))
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _effect_text(step: Dictionary) -> String:
	if not bool(step.get("affects_score", true)) or str(step.get("source_id", "")) == SOURCE_SCRATCH:
		return "SCORE RETAINED"
	var haul_delta: int = int(step.get("haul_delta", 0))
	if haul_delta != 0:
		return "%s HAUL" % _signed_number(float(haul_delta))
	var xmult_factor: float = float(step.get("xmult_factor", 1.0))
	if not is_equal_approx(xmult_factor, 1.0):
		return "x%s MULT" % _format_number(xmult_factor)
	var mult_delta: float = float(step.get("mult_delta", 0.0))
	if not is_zero_approx(mult_delta):
		return "%s MULT" % _signed_number(mult_delta)
	return "SCORE UNCHANGED"


static func _bank_live_title(tier_index: int, tier_count: int) -> String:
	if tier_count <= 1:
		return "BANK SHOT!"
	if tier_index <= 0:
		return "SINGLE..."
	if tier_index == 1:
		return "DOUBLE BANK!" if tier_count == 2 else "DOUBLE..."
	return "TRIPLE BANK!!!"


static func _bank_replay_title(tier_index: int) -> String:
	if tier_index <= 0:
		return "SINGLE BANK"
	if tier_index == 1:
		return "DOUBLE BANK"
	return "TRIPLE BANK!!!"


static func _cue_recontact_title(cue_strike_ordinal: int, live: bool) -> String:
	var title: String = ""
	if cue_strike_ordinal <= 2:
		title = "DOUBLE TAP"
	elif cue_strike_ordinal == 3:
		title = "TRIPLE TAP"
	else:
		title = "TAP x%d" % cue_strike_ordinal
	return "%s!" % title if live else title


static func _tap_title_from_display_tier(
	event_type: String,
	display_tier: String,
	ordinal: int,
	live: bool
) -> String:
	if event_type == "cue_recontact_milestone":
		if display_tier == "double_tap":
			return "DOUBLE TAP!" if live else "DOUBLE TAP"
		if display_tier == "triple_tap":
			return "TRIPLE TAP!" if live else "TRIPLE TAP"
		if display_tier.begins_with("tap_x"):
			var tap_title: String = "TAP x%d" % maxi(ordinal, 4)
			return "%s!" % tap_title if live else tap_title
		return _cue_recontact_title(ordinal, live)
	if display_tier == "ball_tap":
		return "BALL TAP!" if live else "BALL TAP"
	if display_tier.begins_with("ball_tap_x"):
		var ball_tap_title: String = "BALL TAP x%d" % maxi(ordinal, 2)
		return "%s!" % ball_tap_title if live else ball_tap_title
	return _object_ball_tap_title(ordinal, live)


static func _object_ball_tap_title(unique_contact_ordinal: int, live: bool) -> String:
	var title: String = "BALL TAP"
	if unique_contact_ordinal > 1:
		title = "BALL TAP x%d" % unique_contact_ordinal
	return "%s!" % title if live else title


static func _bank_group_title(grouped_count: int) -> String:
	if grouped_count <= 1:
		return "SINGLE BANK"
	if grouped_count == 2:
		return "DOUBLE BANK"
	return "TRIPLE BANK!!!"


static func _bank_class(bank_count: int) -> String:
	if bank_count == 1:
		return "bank"
	if bank_count == 2:
		return "double_bank"
	if bank_count >= 3:
		return "triple_bank_plus"
	return "none"


static func _physical_event_precedes(a: Dictionary, b: Dictionary) -> bool:
	var event_a: int = int(a.get("event_index", -1))
	var event_b: int = int(b.get("event_index", -1))
	if event_a < 0:
		event_a = 2147483647
	if event_b < 0:
		event_b = 2147483647
	if event_a != event_b:
		return event_a < event_b
	var priority_a: int = int(EVENT_PRIORITY.get(str(a.get("event_type", "")), 99))
	var priority_b: int = int(EVENT_PRIORITY.get(str(b.get("event_type", "")), 99))
	if priority_a != priority_b:
		return priority_a < priority_b
	return _first_source_step_index(a) < _first_source_step_index(b)


static func _ball_narrative_precedes(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("pocket_order", 2147483647))
	var order_b: int = int(b.get("pocket_order", 2147483647))
	if order_a != order_b:
		return order_a < order_b
	return int(a.get("ball_id", -1)) < int(b.get("ball_id", -1))


static func _pocket_fact_precedes(a: Dictionary, b: Dictionary) -> bool:
	var order_a: int = int(a.get("pocket_order", 2147483647))
	var order_b: int = int(b.get("pocket_order", 2147483647))
	if order_a != order_b:
		return order_a < order_b
	return int(a.get("ball_id", -1)) < int(b.get("ball_id", -1))


static func _canonical_step_precedes(a: Dictionary, b: Dictionary) -> bool:
	return _first_source_step_index(a) < _first_source_step_index(b)


static func _first_source_step_index(event: Dictionary) -> int:
	var indices: Array = _array_value(event, "source_step_indices")
	return int(indices[0]) if not indices.is_empty() else 2147483647


static func _identity_matches(result: Dictionary, ledger: Dictionary) -> bool:
	if result.is_empty() or ledger.is_empty():
		return false
	return (
		str(result.get("run_generation", "")) == str(ledger.get("run_generation", ""))
		and str(result.get("mode_id", "")) == str(ledger.get("mode_id", ""))
		and int(result.get("shot_id", -1)) == int(ledger.get("shot_id", -2))
		and int(result.get("attempt_id", -1)) == int(ledger.get("attempt_id", -2))
	)


static func _normalize_source(source: String) -> String:
	return source if source in [SOURCE_PREDICTED, SOURCE_AUTHORITATIVE] else "invalid"


static func _score_preview(haul: int, mult: float) -> int:
	return maxi(int(floor(float(maxi(haul, 0)) * maxf(mult, 0.0))), 0)


static func _is_finite_position(position: Vector2) -> bool:
	return is_finite(position.x) and is_finite(position.y)


static func _contains_live_node_reference(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return true
	if value is Node:
		return true
	if value is Dictionary:
		for key_value in (value as Dictionary).keys():
			if _contains_live_node_reference(key_value, depth + 1):
				return true
			if _contains_live_node_reference((value as Dictionary)[key_value], depth + 1):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_live_node_reference(item, depth + 1):
				return true
	return false


static func _add_error(validation: Dictionary, message: String) -> void:
	var errors: Array = _array_value(validation, "errors")
	if not errors.has(message):
		errors.append(message)
	validation["errors"] = errors


static func _add_diagnostic_warning(diagnostics: Dictionary, message: String) -> void:
	var warnings: Array = _array_value(diagnostics, "warnings")
	if not warnings.has(message):
		warnings.append(message)
	diagnostics["warnings"] = warnings


static func _note_missing_event(event_index: int, diagnostics: Dictionary) -> void:
	var missing: Array = _array_value(diagnostics, "missing_event_indices")
	if event_index >= 0 and not missing.has(event_index):
		missing.append(event_index)
	diagnostics["missing_event_indices"] = missing


static func _sum_int_field(values: Array, key: String) -> int:
	var total: int = 0
	for value in values:
		if value is Dictionary:
			total += int((value as Dictionary).get(key, 0))
	return total


static func _sum_float_field(values: Array, key: String) -> float:
	var total: float = 0.0
	for value in values:
		if value is Dictionary:
			total += float((value as Dictionary).get(key, 0.0))
	return total


static func _event_source_step_indices(events: Array) -> Array[int]:
	var indices: Array[int] = []
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var source_indices: Array = _array_value(event_value as Dictionary, "source_step_indices")
		if not source_indices.is_empty():
			indices.append(int(source_indices[0]))
	return indices


static func _physical_step_deltas_match(physical_events: Array, resolution_steps: Array) -> bool:
	var represented_by_step: Dictionary = {}
	for event_value in physical_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var source_indices: Array = _array_value(event, "source_step_indices")
		if source_indices.size() != 1:
			return false
		var step_key: String = str(int(source_indices[0]))
		var represented: Dictionary = _dictionary_value(represented_by_step, step_key)
		represented["haul_delta"] = int(represented.get("haul_delta", 0)) + int(event.get("haul_delta", 0))
		represented["mult_delta"] = float(represented.get("mult_delta", 0.0)) + float(event.get("mult_delta", 0.0))
		represented["xmult_factor"] = float(represented.get("xmult_factor", 1.0)) * float(event.get("xmult_factor", 1.0))
		represented_by_step[step_key] = represented
	for step_value in resolution_steps:
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		if not bool(step.get("affects_score", true)):
			continue
		if str(step.get("source_type", "")) == "modifier" or int(step.get("ball_id", -1)) <= 0:
			continue
		var step_key: String = str(int(step.get("step_index", -1)))
		var represented: Dictionary = _dictionary_value(represented_by_step, step_key)
		if represented.is_empty():
			return false
		if int(represented.get("haul_delta", 0)) != int(step.get("haul_delta", 0)):
			return false
		if not is_equal_approx(float(represented.get("mult_delta", 0.0)), float(step.get("mult_delta", 0.0))):
			return false
		if not is_equal_approx(float(represented.get("xmult_factor", 1.0)), float(step.get("xmult_factor", 1.0))):
			return false
	return true


static func _int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value in values:
		result.append(int(value))
	return result


static func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


static func _signed_number(value: float) -> String:
	return "+%s" % _format_number(value) if value >= 0.0 else _format_number(value)


static func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []


static func _dictionary_at(values: Array, index: int) -> Dictionary:
	if index < 0 or index >= values.size() or not values[index] is Dictionary:
		return {}
	return values[index] as Dictionary


static func _run_bank_partition_case(cases: Array[Dictionary], rail_count: int, name: String) -> void:
	var ledger: Dictionary = _make_test_ledger([
		{"ball_id": 2, "ball_number": 2, "rail_count": rail_count},
	])
	var score_result: Dictionary = RogueliteScoreResolver.resolve(ledger)
	var narrative_result: Dictionary = build_predicted_narrative(ledger, score_result)
	var narratives: Array = _array_value(narrative_result, "ball_narratives")
	var events: Array = _array_value(_dictionary_at(narratives, 0), "events")
	var rail_events: Array[Dictionary] = []
	for event_value in events:
		if event_value is Dictionary and str((event_value as Dictionary).get("event_type", "")) == "rail_milestone":
			rail_events.append(event_value as Dictionary)
	var deltas: Array[float] = []
	var event_indices: Array[int] = []
	for rail_event in rail_events:
		deltas.append(float(rail_event.get("mult_delta", 0.0)))
		event_indices.append(int(rail_event.get("event_index", -1)))
	var passed: bool = (
		rail_events.size() == rail_count
		and is_equal_approx(_sum_float_field(rail_events, "mult_delta"), float(rail_count))
		and bool(_dictionary_value(narrative_result, "validation").get("valid", false))
	)
	_append_case(cases, name, passed, {
		"rail_event_count": rail_count,
		"deltas": _filled_float_array(rail_count, 1.0),
	}, {
		"rail_event_count": rail_events.size(),
		"deltas": deltas,
		"event_indices": event_indices,
		"validation": _dictionary_value(narrative_result, "validation").get("status", ""),
	})


static func _make_test_ledger(ball_specs: Array) -> Dictionary:
	var starting_balls: Dictionary = {
		"1": {
			"ball_id": 1,
			"ball_number": 0,
			"ball_kind": "cue",
			"counts_as_object_ball": false,
			"radius": 14.0,
			"start_position": Vector2(120.0, 300.0),
		},
	}
	var ending_balls: Dictionary = {}
	var raw_events: Array[Dictionary] = []
	var event_index: int = 0
	var pocket_index: int = 0
	for spec_value in ball_specs:
		if not spec_value is Dictionary:
			continue
		var spec: Dictionary = spec_value
		var ball_id: int = int(spec.get("ball_id", -1))
		var ball_number: int = int(spec.get("ball_number", ball_id))
		starting_balls[str(ball_id)] = {
			"ball_id": ball_id,
			"ball_number": ball_number,
			"ball_kind": "object",
			"anomaly_type": "",
			"counts_as_object_ball": true,
			"radius": 14.0,
			"start_position": Vector2(260.0 + float(ball_id) * 18.0, 300.0),
		}
		raw_events.append({
			"event_index": event_index,
			"event_type": "ball_contact",
			"accepted_impact": true,
			"ball_a_id": 1,
			"ball_b_id": ball_id,
			"source_ball_id": 1,
			"target_ball_id": ball_id,
			"contact_point": Vector2(220.0 + float(event_index) * 6.0, 300.0),
		})
		event_index += 1
		var rail_count: int = int(spec.get("rail_count", 0))
		for rail_index in range(rail_count):
			raw_events.append({
				"event_index": event_index,
				"event_type": "rail_contact",
				"ball_id": ball_id,
				"rail_id": "rail_%d" % rail_index,
				"contact_point": Vector2(300.0 + float(rail_index) * 45.0, 90.0 + float(rail_index) * 30.0),
			})
			event_index += 1
		raw_events.append({
			"event_index": event_index,
			"event_type": "pocket",
			"ball_id": ball_id,
			"ball_kind": "object",
			"counts_as_object_ball": true,
			"pocket_index": pocket_index,
			"pocket_center": Vector2(100.0 + float(pocket_index) * 160.0, 80.0),
			"capture_position": Vector2(100.0 + float(pocket_index) * 160.0, 84.0),
		})
		event_index += 1
		pocket_index += 1
		ending_balls[str(ball_id)] = {
			"ball_id": ball_id,
			"ball_number": ball_number,
			"ball_kind": "object",
			"active": false,
			"travel_distance": 240.0,
		}
	var ledger: Dictionary = {
		"schema_version": 2,
		"source": "synthetic_narrative_test",
		"run_generation": 1,
		"mode_id": "shot_lab",
		"shot_id": 1,
		"attempt_id": 1,
		"cue_ball_id": 1,
		"starting_balls": starting_balls,
		"ending_balls": ending_balls,
		"raw_events": raw_events,
	}
	ledger["derived"] = ShotLedgerAnalyzer.analyze(ledger)
	return ledger


static func _make_test_tap_fixture() -> Dictionary:
	var ledger: Dictionary = _make_test_ledger([
		{"ball_id": 2, "ball_number": 2, "rail_count": 0},
	])
	var starting_balls: Dictionary = _dictionary_value(ledger, "starting_balls")
	starting_balls["3"] = {
		"ball_id": 3,
		"ball_number": 3,
		"ball_kind": "object",
		"counts_as_object_ball": true,
		"radius": 14.0,
		"start_position": Vector2(380.0, 300.0),
	}
	ledger["starting_balls"] = starting_balls
	var raw_events: Array = _array_value(ledger, "raw_events")
	var pocket_event: Dictionary = _dictionary_at(raw_events, 1)
	pocket_event["event_index"] = 3
	raw_events[1] = pocket_event
	raw_events.append({
		"event_index": 1,
		"event_type": "ball_contact",
		"accepted_impact": true,
		"ball_a_id": 1,
		"ball_b_id": 2,
		"source_ball_id": 1,
		"target_ball_id": 2,
		"causal_direction_ambiguous": false,
		"contact_point": Vector2(300.0, 300.0),
		"contact_normal": Vector2.RIGHT,
	})
	raw_events.append({
		"event_index": 2,
		"event_type": "ball_contact",
		"accepted_impact": true,
		"ball_a_id": 2,
		"ball_b_id": 3,
		"source_ball_id": 2,
		"target_ball_id": 3,
		"causal_direction_ambiguous": false,
		"contact_point": Vector2(360.0, 300.0),
		"contact_normal": Vector2.RIGHT,
	})
	ledger["raw_events"] = raw_events
	ledger["derived"] = ShotLedgerAnalyzer.analyze(ledger)
	var score_result: Dictionary = RogueliteScoreResolver.resolve(ledger)
	var resolution_steps: Array = _array_value(score_result, "resolution_steps")
	var next_mult: float = float(score_result.get("final_mult", 1.0))
	if not _steps_have_tap_family(resolution_steps, "cue_recontact"):
		resolution_steps.append(_make_test_tap_step(
			resolution_steps.size(),
			SOURCE_CUE_RECONTACT,
			SOURCE_CUE_RECONTACT_MILESTONE,
			"Double Tap",
			1,
			2,
			next_mult,
			{
				"trigger_id": SOURCE_CUE_RECONTACT_MILESTONE,
				"cue_strike_ordinal": 2,
				"bonus_ordinal": 1,
				"qualifying_cue_strike_count": 2,
				"contacted_ball_id": 1,
			}
		))
		next_mult += 1.0
	if not _steps_have_tap_family(resolution_steps, "object_ball_tap"):
		resolution_steps.append(_make_test_tap_step(
			resolution_steps.size(),
			SOURCE_OBJECT_BALL_TAP,
			SOURCE_OBJECT_BALL_TAP_MILESTONE,
			"Ball Tap",
			2,
			2,
			next_mult,
			{
				"trigger_id": SOURCE_OBJECT_BALL_TAP_MILESTONE,
				"unique_contact_ordinal": 1,
				"unique_target_count": 1,
				"contacted_ball_id": 3,
			}
		))
		next_mult += 1.0
	score_result["resolution_steps"] = resolution_steps
	score_result["final_mult"] = next_mult
	score_result["shot_score"] = _score_preview(
		int(score_result.get("final_haul", 0)),
		next_mult
	)
	return {"ledger": ledger, "score_result": score_result}


static func _make_test_tap_step(
	step_index: int,
	source_id: String,
	source_type: String,
	display_name: String,
	event_index: int,
	ball_id: int,
	mult_before: float,
	metadata: Dictionary
) -> Dictionary:
	return {
		"step_index": step_index,
		"phase": "base",
		"source_id": source_id,
		"source_type": source_type,
		"display_name": display_name,
		"event_index": event_index,
		"ball_id": ball_id,
		"haul_before": 10,
		"haul_delta": 0,
		"haul_after": 10,
		"mult_before": mult_before,
		"mult_delta": 1.0,
		"xmult_factor": 1.0,
		"mult_after": mult_before + 1.0,
		"score_preview_after": _score_preview(10, mult_before + 1.0),
		"affects_score": true,
		"metadata": metadata.duplicate(true),
	}


static func _steps_have_tap_family(steps: Array, family: String) -> bool:
	for step_value in steps:
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		if family == "cue_recontact" and _is_cue_recontact_step(step):
			return true
		if family == "object_ball_tap" and _is_object_ball_tap_step(step):
			return true
	return false


static func _test_modifier(modifier_id: String, phase: String, slot_index: int, value: Variant) -> Dictionary:
	return {
		"modifier_id": modifier_id,
		"display_name": modifier_id,
		"phase": phase,
		"slot_index": slot_index,
		"enabled": true,
		"conditions": {},
		"value": value,
	}


static func _append_case(cases: Array[Dictionary], name: String, passed: bool, expected: Variant, actual: Variant) -> void:
	cases.append({
		"name": name,
		"passed": passed,
		"expected": expected,
		"actual": actual,
	})


static func _narrative_ball_ids(narratives: Array) -> Array[int]:
	var ids: Array[int] = []
	for narrative_value in narratives:
		if narrative_value is Dictionary:
			ids.append(int((narrative_value as Dictionary).get("ball_id", -1)))
	return ids


static func _narrative_pocket_orders(narratives: Array) -> Array[int]:
	var orders: Array[int] = []
	for narrative_value in narratives:
		if narrative_value is Dictionary:
			orders.append(int((narrative_value as Dictionary).get("pocket_order", -1)))
	return orders


static func _engine_source_ids(events: Array) -> Array[String]:
	var ids: Array[String] = []
	for event_value in events:
		if event_value is Dictionary:
			ids.append(str((event_value as Dictionary).get("source_id", "")))
	return ids


static func _final_classes_by_ball(narratives: Array) -> Dictionary:
	var classes: Dictionary = {}
	for narrative_value in narratives:
		if not narrative_value is Dictionary:
			continue
		var narrative: Dictionary = narrative_value
		classes[str(int(narrative.get("ball_id", -1)))] = str(narrative.get("final_classification", "unknown"))
	return classes


static func _count_event_type(events: Array, event_type: String) -> int:
	var count: int = 0
	for event_value in events:
		if event_value is Dictionary and str((event_value as Dictionary).get("event_type", "")) == event_type:
			count += 1
	return count


static func _filled_float_array(count: int, value: float) -> Array[float]:
	var values: Array[float] = []
	for _index in range(count):
		values.append(value)
	return values
