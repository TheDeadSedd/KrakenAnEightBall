extends RefCounted
class_name RogueliteScorePresentationMapper

const SCHEMA_VERSION := 2
const SELF_TEST_CASE_COUNT := 12

const SOURCE_CUE_RECONTACT := "base_cue_recontact"
const SOURCE_CUE_RECONTACT_MILESTONE := "cue_recontact_milestone"
const SOURCE_OBJECT_BALL_TAP := "base_object_ball_tap"
const SOURCE_OBJECT_BALL_TAP_MILESTONE := "object_ball_tap_milestone"
const EFFECT_KIND_PERSISTENT_SCALER := "persistent_scaler"
const EFFECT_KIND_CROSS_FAMILY_CONDITIONAL := "cross_family_conditional"
const EFFECT_KIND_SHOT_ORDINAL_MULTIPLIER := "shot_ordinal_multiplier"
const EFFECT_KIND_THRESHOLD_FAMILY_RETRIGGER := "threshold_family_retrigger"


static func map_score_result(score_result: Dictionary, frozen_ledger: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = {
		"identity_match": _identity_matches(score_result, frozen_ledger),
		"mapped_anchor_count": 0,
		"fallback_count": 0,
		"missing_event_indices": [],
		"invalid_position_count": 0,
		"mapped_engine_event_count": 0,
		"warnings": [],
	}
	var mapped_steps: Array[Dictionary] = []
	var mapped_engine_events: Array[Dictionary] = []
	if score_result.is_empty() or frozen_ledger.is_empty() or not bool(diagnostics["identity_match"]):
		diagnostics["warnings"].append("Score result and frozen Shot Ledger identities do not match.")
		return {
			"schema_version": SCHEMA_VERSION,
			"resolution_key": _resolution_key(score_result),
			"steps": mapped_steps,
			"engine_events": mapped_engine_events,
			"diagnostics": diagnostics,
		}

	var event_lookup: Dictionary = _build_event_lookup(frozen_ledger)
	var starting_balls: Dictionary = _dictionary_value(frozen_ledger, "starting_balls")
	var tap_milestone_lookup: Dictionary = _build_tap_milestone_lookup(
		_dictionary_value(frozen_ledger, "derived"),
		diagnostics
	)
	for step_value in _array_value(score_result, "resolution_steps"):
		if not step_value is Dictionary:
			continue
		var mapped: Dictionary = _map_step(
			step_value as Dictionary,
			event_lookup,
			tap_milestone_lookup,
			diagnostics,
			starting_balls
		)
		mapped_steps.append(mapped)
		if str(mapped.get("anchor_type", "hud")) == "world":
			diagnostics["mapped_anchor_count"] = int(diagnostics["mapped_anchor_count"]) + 1
		if bool(mapped.get("fallback_used", false)):
			diagnostics["fallback_count"] = int(diagnostics["fallback_count"]) + 1
			var fallback_reason: String = str(mapped.get("fallback_reason", ""))
			if not fallback_reason.is_empty():
				diagnostics["warnings"].append(fallback_reason)
	mapped_engine_events = _map_engine_events(score_result)
	diagnostics["mapped_engine_event_count"] = mapped_engine_events.size()

	return {
		"schema_version": SCHEMA_VERSION,
		"resolution_key": _resolution_key(score_result),
		"steps": mapped_steps,
		"engine_events": mapped_engine_events,
		"diagnostics": diagnostics,
	}


static func run_self_tests() -> Dictionary:
	var cases: Array[Dictionary] = []
	var ledger: Dictionary = _test_ledger()
	var result: Dictionary = _test_result()
	var mapped: Dictionary = map_score_result(result, ledger)
	var steps: Array = _array_value(mapped, "steps")
	_append_case(cases, "Pocket maps to pocket center", _step_position(steps, 0).is_equal_approx(Vector2(100.0, 200.0)), Vector2(100.0, 200.0), _step_position(steps, 0))
	_append_case(cases, "Rail maps to rail contact", _step_position(steps, 1).is_equal_approx(Vector2(240.0, 80.0)), Vector2(240.0, 80.0), _step_position(steps, 1))
	_append_case(cases, "Combination maps to causal contact", _step_position(steps, 2).is_equal_approx(Vector2(180.0, 140.0)), Vector2(180.0, 140.0), _step_position(steps, 2))
	var modifier_anchor: Variant = _step_value(steps, 3, "anchor_type", "")
	_append_case(cases, "Modifier maps to HUD", str(modifier_anchor) == "hud", "hud", modifier_anchor)
	_append_case(cases, "Cue recontact maps to contact", (
		_step_position(steps, 4).is_equal_approx(Vector2(320.0, 160.0))
		and str(_step_value(steps, 4, "title", "")) == "DOUBLE TAP"
	), {"position": Vector2(320.0, 160.0), "title": "DOUBLE TAP"}, {
		"position": _step_position(steps, 4),
		"title": _step_value(steps, 4, "title", ""),
	})
	_append_case(cases, "Object Ball Tap maps to contact", (
		_step_position(steps, 5).is_equal_approx(Vector2(360.0, 160.0))
		and str(_step_value(steps, 5, "title", "")) == "BALL TAP x2"
	), {"position": Vector2(360.0, 160.0), "title": "BALL TAP x2"}, {
		"position": _step_position(steps, 5),
		"title": _step_value(steps, 5, "title", ""),
	})
	var engine_events: Array = _array_value(mapped, "engine_events")
	_append_case(cases, "Rattle growth maps as value-only HUD evidence", (
		engine_events.size() == 2
		and str(_step_value(engine_events, 0, "title", "")) == "RATTLE OF THE DEEP"
		and str(_step_value(engine_events, 0, "effect_text", "")) == "x1.4 -> x1.6"
		and int(_step_value(engine_events, 0, "tray_slot_index", -1)) == 2
		and str(_step_value(engine_events, 0, "anchor_type", "")) == "hud"
	), {
		"title": "RATTLE OF THE DEEP",
		"effect_text": "x1.4 -> x1.6",
		"slot": 2,
		"anchor": "hud",
	}, _dictionary_at(engine_events, 0))
	_append_case(cases, "Echo threshold maps to its exact tray slot", (
		str(_step_value(engine_events, 1, "title", "")) == "ECHO CHAMBER"
		and str(_step_value(engine_events, 1, "effect_text", "")) == "THIRD TAP - RETRIGGER"
		and int(_step_value(engine_events, 1, "tray_slot_index", -1)) == 4
	), {
		"title": "ECHO CHAMBER",
		"effect_text": "THIRD TAP - RETRIGGER",
		"slot": 4,
	}, _dictionary_at(engine_events, 1))
	var build_modifier: Dictionary = _map_step({
		"step_index": 6,
		"source_id": "double_tap_haul_second_bite",
		"source_type": "modifier",
		"display_name": "Second Bite",
		"phase": "add_haul",
		"event_index": 6,
		"ball_id": -1,
		"haul_delta": 10,
		"mult_delta": 0.0,
		"xmult_factor": 1.0,
		"affects_score": true,
		"metadata": {
			"trigger_id": SOURCE_CUE_RECONTACT_MILESTONE,
			"slot_index": 1,
			"is_retrigger": true,
		},
	}, _build_event_lookup(ledger), _build_tap_milestone_lookup(
		_dictionary_value(ledger, "derived"), {}
	), {}, _dictionary_value(ledger, "starting_balls"))
	_append_case(cases, "Tap build activation remains HUD-owned", (
		str(build_modifier.get("anchor_type", "")) == "hud"
		and str(build_modifier.get("title", "")) == "SECOND BITE"
	), {"anchor": "hud", "title": "SECOND BITE"}, build_modifier)
	_append_case(cases, "Retrigger wording is explicit", (
		str(build_modifier.get("effect_text", "")) == "RETRIGGER +10 HAUL"
	), "RETRIGGER +10 HAUL", build_modifier.get("effect_text", ""))
	var missing_result: Dictionary = result.duplicate(true)
	var missing_steps: Array = _array_value(missing_result, "resolution_steps")
	var missing_bank: Dictionary = (missing_steps[1] as Dictionary).duplicate(true)
	missing_bank["event_index"] = 999
	missing_bank["metadata"] = {"scored_rail_event_indices": [999], "pocket_event_index": 2}
	missing_steps[1] = missing_bank
	missing_result["resolution_steps"] = missing_steps
	var missing_map: Dictionary = map_score_result(missing_result, ledger)
	var missing_mapped_steps: Array = _array_value(missing_map, "steps")
	_append_case(
		cases,
		"Missing rail uses warned fallback",
		bool(_step_value(missing_mapped_steps, 1, "fallback_used", false)),
		true,
		_step_value(missing_mapped_steps, 1, "fallback_reason", "")
	)
	var invalid_ledger: Dictionary = ledger.duplicate(true)
	var invalid_events: Array = _array_value(invalid_ledger, "raw_events")
	invalid_events.append({
		"event_index": 5,
		"event_type": "pocket",
		"pocket_center": Vector2(INF, 200.0),
		"capture_position": Vector2(INF, -INF),
		"pocket_index": 0,
	})
	invalid_ledger["raw_events"] = invalid_events
	var invalid_result: Dictionary = result.duplicate(true)
	var invalid_steps: Array = _array_value(invalid_result, "resolution_steps")
	var invalid_pocket_step: Dictionary = (invalid_steps[0] as Dictionary).duplicate(true)
	invalid_pocket_step["event_index"] = 5
	invalid_steps[0] = invalid_pocket_step
	invalid_result["resolution_steps"] = invalid_steps
	var invalid_map: Dictionary = map_score_result(invalid_result, invalid_ledger)
	var invalid_mapped_steps: Array = _array_value(invalid_map, "steps")
	var invalid_diagnostics: Dictionary = _dictionary_value(invalid_map, "diagnostics")
	_append_case(
		cases,
		"Invalid position warns without crashing",
		bool(_step_value(invalid_mapped_steps, 0, "fallback_used", false))
			and int(invalid_diagnostics.get("invalid_position_count", 0)) == 1,
		{"fallback_used": true, "invalid_position_count": 1},
		{
			"fallback_used": _step_value(invalid_mapped_steps, 0, "fallback_used", false),
			"invalid_position_count": invalid_diagnostics.get("invalid_position_count", 0),
		}
	)

	var passed: int = 0
	var failures: Array[Dictionary] = []
	for case_value in cases:
		var case: Dictionary = case_value
		if bool(case.get("passed", false)):
			passed += 1
		else:
			failures.append(case.duplicate(true))
	var report: Dictionary = {
		"status": "PASS" if failures.is_empty() and cases.size() == SELF_TEST_CASE_COUNT else "FAIL",
		"total": cases.size(),
		"passed": passed,
		"failed": failures.size(),
		"failures": failures,
	}
	return report


static func _map_step(
	step: Dictionary,
	event_lookup: Dictionary,
	tap_milestone_lookup: Dictionary,
	diagnostics: Dictionary,
	starting_balls: Dictionary
) -> Dictionary:
	var source_id: String = str(step.get("source_id", ""))
	var source_type: String = str(step.get("source_type", ""))
	var event_index: int = int(step.get("event_index", -1))
	var metadata: Dictionary = _dictionary_value(step, "metadata")
	_enrich_modifier_ball_number(metadata, step, starting_balls)
	var presentation_step: Dictionary = step.duplicate(true)
	presentation_step["metadata"] = metadata.duplicate(true)
	var canonical_tap: Dictionary = _get_canonical_tap_milestone(
		step,
		tap_milestone_lookup
	)
	var mapped: Dictionary = {
		"step_index": int(step.get("step_index", -1)),
		"source_id": source_id,
		"source_type": source_type,
		"phase": str(step.get("phase", "")),
		"title": _step_title(step, canonical_tap),
		"effect_text": _step_effect_text(presentation_step),
		"affects_score": bool(step.get("affects_score", true)),
		"ball_id": int(step.get("ball_id", -1)),
		"event_index": event_index,
		"event_indices": [],
		"anchor_type": "hud",
		"coordinate_space": "hud",
		"world_position": Vector2.ZERO,
		"source_world_positions": [],
		"hud_anchor_id": "long_sink_equation",
		"anchor_reason": "modifier_or_missing_geometry",
		"fallback_used": false,
		"fallback_reason": "",
		"pocket_index": -1,
		"rail_ids": [],
		"metadata": metadata.duplicate(true),
		"source_ball_id": -1,
		"target_ball_id": -1,
		"contacted_ball_id": int(metadata.get("contacted_ball_id", -1)),
		"contact_normal": Vector2.ZERO,
		"canonical_milestone_valid": not canonical_tap.is_empty(),
		"display_tier": str(canonical_tap.get("display_tier", "")),
		"tap_ordinal": _tap_ordinal(canonical_tap),
		"eight_ball_item_id": str(metadata.get(
			"eight_ball_item_id",
			step.get("eight_ball_item_id", source_id if source_type == "modifier" else "")
		)),
		"owned_item_instance_id": int(metadata.get(
			"owned_item_instance_id",
			step.get("owned_item_instance_id", 0)
		)),
		"tray_slot_index": int(metadata.get(
			"slot_index",
			metadata.get("tray_slot_index", step.get("tray_slot_index", -1))
		)),
		"effect_kind": str(metadata.get(
			"effect_kind",
			step.get("effect_kind", "")
		)),
		"is_retrigger": bool(metadata.get(
			"is_retrigger",
			step.get("is_retrigger", false)
		)),
		"retrigger_threshold_ordinal": int(metadata.get(
			"retrigger_threshold_ordinal",
			step.get("retrigger_threshold_ordinal", 0)
		)),
	}

	match source_id:
		"base_object_ball_value", "base_additional_ball", "scratch":
			_apply_pocket_anchor(mapped, event_lookup, event_index, diagnostics)
		"base_bank_rail":
			_apply_rail_anchor(mapped, event_lookup, metadata, diagnostics)
		"base_combination":
			_apply_contact_anchor(mapped, event_lookup, event_index, diagnostics)
		_:
			if source_type == "modifier" or not str(mapped.get("eight_ball_item_id", "")).is_empty():
				mapped["anchor_reason"] = "modifier_hud_anchor"
			elif _is_tap_step(step):
				_apply_canonical_tap_anchor(
					mapped,
					event_lookup,
					canonical_tap,
					diagnostics
				)
			else:
				_apply_event_anchor_if_valid(mapped, event_lookup, event_index, diagnostics)
	return mapped


static func _apply_canonical_tap_anchor(
	mapped: Dictionary,
	event_lookup: Dictionary,
	milestone: Dictionary,
	diagnostics: Dictionary
) -> void:
	if milestone.is_empty():
		_set_fallback(
			mapped,
			"Canonical Tap milestone was unavailable; using the equation HUD."
		)
		diagnostics["missing_canonical_tap_milestones"] = int(
			diagnostics.get("missing_canonical_tap_milestones", 0)
		) + 1
		return
	var event_index: int = int(milestone.get("event_index", -1))
	var position: Vector2 = _variant_position(milestone.get("world_position", null))
	if not _is_finite_position(position):
		diagnostics["invalid_position_count"] = int(
			diagnostics["invalid_position_count"]
		) + 1
		_set_fallback(mapped, "Canonical Tap milestone had no finite world position.")
		return
	var raw_event: Dictionary = _event_at(event_lookup, event_index)
	if str(raw_event.get("event_type", "")) == "ball_contact":
		mapped["source_ball_id"] = int(raw_event.get("source_ball_id", -1))
		mapped["target_ball_id"] = int(raw_event.get("target_ball_id", -1))
		mapped["contact_normal"] = _variant_position(raw_event.get(
			"contact_normal",
			raw_event.get("collision_normal", Vector2.ZERO)
		))
	elif event_index >= 0:
		_note_missing_event(event_index, diagnostics)
	mapped["event_index"] = event_index
	mapped["ball_id"] = int(milestone.get("ball_id", mapped.get("ball_id", -1)))
	mapped["contacted_ball_id"] = int(milestone.get(
		"contacted_ball_id",
		mapped.get("contacted_ball_id", -1)
	))
	mapped["display_tier"] = str(milestone.get("display_tier", ""))
	mapped["tap_ordinal"] = _tap_ordinal(milestone)
	mapped["cue_strike_ordinal"] = int(milestone.get("cue_strike_ordinal", 0))
	mapped["unique_contact_ordinal"] = int(milestone.get(
		"unique_contact_ordinal",
		0
	))
	mapped["trigger_occurrence_id"] = str(milestone.get(
		"trigger_occurrence_id",
		""
	))
	_set_world_anchor(mapped, position, "canonical_tap_milestone", event_index)


static func _apply_pocket_anchor(mapped: Dictionary, event_lookup: Dictionary, event_index: int, diagnostics: Dictionary) -> void:
	var event: Dictionary = _event_at(event_lookup, event_index)
	if str(event.get("event_type", "")) != "pocket":
		_note_missing_event(event_index, diagnostics)
		_set_fallback(mapped, "Pocket event %d was unavailable; using the equation HUD." % event_index)
		return
	var position: Vector2 = _first_valid_position(event, ["pocket_center", "capture_position"])
	if not _is_finite_position(position):
		diagnostics["invalid_position_count"] = int(diagnostics["invalid_position_count"]) + 1
		_set_fallback(mapped, "Pocket event %d had no finite capture geometry." % event_index)
		return
	_set_world_anchor(mapped, position, "pocket_event", event_index)
	mapped["pocket_index"] = int(event.get("pocket_index", -1))


static func _apply_rail_anchor(mapped: Dictionary, event_lookup: Dictionary, metadata: Dictionary, diagnostics: Dictionary) -> void:
	var scored_indices: Array = _array_value(metadata, "scored_rail_event_indices")
	if scored_indices.is_empty() and int(mapped.get("event_index", -1)) >= 0:
		scored_indices.append(int(mapped["event_index"]))
	var positions: Array[Vector2] = []
	var rail_ids: Array[String] = []
	var accepted_indices: Array[int] = []
	for index_value in scored_indices:
		var rail_index: int = int(index_value)
		var event: Dictionary = _event_at(event_lookup, rail_index)
		if str(event.get("event_type", "")) != "rail_contact":
			_note_missing_event(rail_index, diagnostics)
			continue
		var position: Vector2 = _variant_position(event.get("contact_point", null))
		if not _is_finite_position(position):
			diagnostics["invalid_position_count"] = int(diagnostics["invalid_position_count"]) + 1
			continue
		positions.append(position)
		accepted_indices.append(rail_index)
		rail_ids.append(str(event.get("rail_id", "")))
	if not positions.is_empty():
		_set_world_anchor(mapped, positions[positions.size() - 1], "rail_contact_event", accepted_indices[accepted_indices.size() - 1])
		mapped["source_world_positions"] = positions.duplicate()
		mapped["event_indices"] = accepted_indices.duplicate()
		mapped["rail_ids"] = rail_ids.duplicate()
		return

	var pocket_event_index: int = int(metadata.get("pocket_event_index", -1))
	var pocket_event: Dictionary = _event_at(event_lookup, pocket_event_index)
	var fallback_position: Vector2 = _first_valid_position(pocket_event, ["pocket_center", "capture_position"])
	if str(pocket_event.get("event_type", "")) == "pocket" and _is_finite_position(fallback_position):
		_set_world_anchor(mapped, fallback_position, "pocket_fallback_for_missing_rail", pocket_event_index)
		_set_fallback(mapped, "Qualifying rail geometry was unavailable; pocket fallback used.", false)
		return
	_set_fallback(mapped, "Qualifying rail geometry was unavailable; equation HUD fallback used.")


static func _apply_contact_anchor(mapped: Dictionary, event_lookup: Dictionary, event_index: int, diagnostics: Dictionary) -> void:
	var event: Dictionary = _event_at(event_lookup, event_index)
	if str(event.get("event_type", "")) != "ball_contact":
		_note_missing_event(event_index, diagnostics)
		_set_fallback(mapped, "Causal contact event %d was unavailable; using the equation HUD." % event_index)
		return
	var position: Vector2 = _variant_position(event.get("contact_point", null))
	if not _is_finite_position(position):
		diagnostics["invalid_position_count"] = int(diagnostics["invalid_position_count"]) + 1
		_set_fallback(mapped, "Causal contact event %d had no finite position." % event_index)
		return
	_set_world_anchor(mapped, position, "causal_ball_contact_event", event_index)
	mapped["source_ball_id"] = int(event.get("source_ball_id", -1))
	mapped["target_ball_id"] = int(event.get("target_ball_id", -1))
	mapped["contact_normal"] = _variant_position(event.get(
		"contact_normal",
		event.get("collision_normal", Vector2.ZERO)
	))
	if int(mapped.get("contacted_ball_id", -1)) <= 0:
		var scoring_ball_id: int = int(mapped.get("ball_id", -1))
		if scoring_ball_id == int(mapped.get("source_ball_id", -1)):
			mapped["contacted_ball_id"] = int(mapped.get("target_ball_id", -1))
		elif scoring_ball_id == int(mapped.get("target_ball_id", -1)):
			mapped["contacted_ball_id"] = int(mapped.get("source_ball_id", -1))


static func _apply_event_anchor_if_valid(mapped: Dictionary, event_lookup: Dictionary, event_index: int, diagnostics: Dictionary) -> void:
	var event: Dictionary = _event_at(event_lookup, event_index)
	var event_type: String = str(event.get("event_type", ""))
	if event_type == "pocket":
		_apply_pocket_anchor(mapped, event_lookup, event_index, diagnostics)
	elif event_type == "rail_contact":
		var metadata: Dictionary = {"scored_rail_event_indices": [event_index]}
		_apply_rail_anchor(mapped, event_lookup, metadata, diagnostics)
	elif event_type == "ball_contact":
		_apply_contact_anchor(mapped, event_lookup, event_index, diagnostics)


static func _set_world_anchor(mapped: Dictionary, position: Vector2, reason: String, event_index: int) -> void:
	mapped["anchor_type"] = "world"
	mapped["coordinate_space"] = "global_canvas"
	mapped["world_position"] = position
	mapped["source_world_positions"] = [position]
	mapped["hud_anchor_id"] = ""
	mapped["anchor_reason"] = reason
	mapped["event_index"] = event_index


static func _set_fallback(mapped: Dictionary, reason: String, force_hud: bool = true) -> void:
	mapped["fallback_used"] = true
	mapped["fallback_reason"] = reason
	if force_hud:
		mapped["anchor_type"] = "hud"
		mapped["coordinate_space"] = "hud"
		mapped["hud_anchor_id"] = "long_sink_equation"


static func _step_title(step: Dictionary, canonical_tap: Dictionary = {}) -> String:
	var source_id: String = str(step.get("source_id", ""))
	if str(step.get("source_type", "")) == "modifier":
		return str(step.get("display_name", "MODIFIER")).to_upper()
	var metadata: Dictionary = _dictionary_value(step, "metadata")
	if _is_cue_recontact_step(step):
		var bonus_ordinal: int = maxi(int(canonical_tap.get(
			"bonus_ordinal",
			metadata.get("bonus_ordinal", 1)
		)), 1)
		var cue_strike_ordinal: int = maxi(int(canonical_tap.get(
			"cue_strike_ordinal",
			metadata.get("cue_strike_ordinal", bonus_ordinal + 1)
		)), 2)
		var display_tier: String = str(canonical_tap.get("display_tier", ""))
		if display_tier == "double_tap" or cue_strike_ordinal == 2:
			return "DOUBLE TAP"
		if display_tier == "triple_tap" or cue_strike_ordinal == 3:
			return "TRIPLE TAP"
		return "TAP x%d" % cue_strike_ordinal
	if _is_object_ball_tap_step(step):
		var ordinal: int = maxi(int(canonical_tap.get(
			"unique_contact_ordinal",
			metadata.get("unique_contact_ordinal", 1)
		)), 1)
		return "BALL TAP" if ordinal == 1 else "BALL TAP x%d" % ordinal
	if source_id == "base_bank_rail":
		var rail_count: int = maxi(int(metadata.get("capped_count", step.get("mult_delta", 1))), 1)
		if rail_count == 1:
			return "BANK"
		if rail_count == 2:
			return "DOUBLE BANK"
		return "TRIPLE BANK"
	return str(step.get("display_name", "SCORE")).to_upper()


static func _is_tap_step(step: Dictionary) -> bool:
	return _is_cue_recontact_step(step) or _is_object_ball_tap_step(step)


static func _is_cue_recontact_step(step: Dictionary) -> bool:
	var source_id: String = str(step.get("source_id", ""))
	var source_type: String = str(step.get("source_type", ""))
	var trigger_id: String = str(_dictionary_value(step, "metadata").get("trigger_id", ""))
	return (
		source_id in [SOURCE_CUE_RECONTACT, SOURCE_CUE_RECONTACT_MILESTONE]
		or source_type in [SOURCE_CUE_RECONTACT, SOURCE_CUE_RECONTACT_MILESTONE]
		or trigger_id == SOURCE_CUE_RECONTACT_MILESTONE
	)


static func _is_object_ball_tap_step(step: Dictionary) -> bool:
	var source_id: String = str(step.get("source_id", ""))
	var source_type: String = str(step.get("source_type", ""))
	var trigger_id: String = str(_dictionary_value(step, "metadata").get("trigger_id", ""))
	return (
		source_id in [SOURCE_OBJECT_BALL_TAP, SOURCE_OBJECT_BALL_TAP_MILESTONE]
		or source_type in [SOURCE_OBJECT_BALL_TAP, SOURCE_OBJECT_BALL_TAP_MILESTONE]
		or trigger_id == SOURCE_OBJECT_BALL_TAP_MILESTONE
	)


static func _tap_ordinal(milestone: Dictionary) -> int:
	if milestone.has("cue_strike_ordinal"):
		return maxi(int(milestone.get("cue_strike_ordinal", 0)), 0)
	return maxi(int(milestone.get("unique_contact_ordinal", 0)), 0)


static func _step_effect_text(step: Dictionary) -> String:
	if not bool(step.get("affects_score", true)) or str(step.get("source_id", "")) == "scratch":
		return "Score retained"
	var metadata: Dictionary = _dictionary_value(step, "metadata")
	var prefix: String = "RETRIGGER " if bool(metadata.get(
		"is_retrigger",
		step.get("is_retrigger", false)
	)) else ""
	var effect_kind: String = str(metadata.get("effect_kind", step.get("effect_kind", "")))
	var ball_number: int = int(metadata.get(
		"ball_number",
		metadata.get("scoring_ball_number", step.get("ball_number", 0))
	))
	var tap_ordinal: int = int(metadata.get(
		"tap_ordinal",
		metadata.get("shot_tap_ordinal", 0)
	))
	var haul_delta: int = int(step.get("haul_delta", 0))
	if haul_delta != 0:
		return "%s%s HAUL" % [prefix, _signed_number(float(haul_delta))]
	var xmult: float = float(step.get("xmult_factor", 1.0))
	if not is_equal_approx(xmult, 1.0):
		var value_text: String = "x%s MULT" % _format_number(xmult)
		if effect_kind == EFFECT_KIND_CROSS_FAMILY_CONDITIONAL and ball_number > 0:
			return "BALL %d - %s" % [ball_number, value_text]
		if effect_kind == EFFECT_KIND_SHOT_ORDINAL_MULTIPLIER and tap_ordinal > 0:
			return "TAP %d - %s" % [tap_ordinal, value_text]
		return "%s%s" % [prefix, value_text]
	var mult_delta: float = float(step.get("mult_delta", 0.0))
	if not is_zero_approx(mult_delta):
		return "%s%s MULT" % [prefix, _signed_number(mult_delta)]
	return "Score unchanged"


static func _enrich_modifier_ball_number(
	metadata: Dictionary,
	step: Dictionary,
	starting_balls: Dictionary
) -> void:
	if int(metadata.get("ball_number", metadata.get("scoring_ball_number", 0))) > 0:
		return
	var semantic_ball_id: int = int(metadata.get(
		"qualifying_ball_id",
		metadata.get(
			"trigger_ball_id",
			step.get("trigger_ball_id", step.get("ball_id", -1))
		)
	))
	if semantic_ball_id <= 0:
		return
	var snapshot_value: Variant = starting_balls.get(
		str(semantic_ball_id),
		starting_balls.get(semantic_ball_id, {})
	)
	if not snapshot_value is Dictionary:
		return
	var ball_number: int = int((snapshot_value as Dictionary).get("ball_number", 0))
	if ball_number > 0:
		metadata["ball_number"] = ball_number


static func _get_engine_event_kind(
	engine_event: Dictionary,
	metadata: Dictionary
) -> String:
	return str(engine_event.get(
		"engine_event_kind",
		engine_event.get(
			"engine_event_type",
			engine_event.get("event_type", metadata.get("engine_event_kind", "engine_event"))
		)
	))


static func _map_engine_events(score_result: Dictionary) -> Array[Dictionary]:
	var mapped: Array[Dictionary] = []
	var input_events: Array[Dictionary] = _extract_engine_events(score_result)
	for event_index in range(input_events.size()):
		mapped.append(_map_engine_event(input_events[event_index], event_index))
	return mapped


static func _extract_engine_events(score_result: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	_append_unique_engine_events(result, seen, score_result.get("engine_events", []))
	for key in [
		"eight_ball_build_evaluation",
		"build_evaluation",
		"build_effect_evaluation",
		"modifier_evaluation",
		"stateful_build_evaluation",
	]:
		var nested_value: Variant = score_result.get(key, null)
		if nested_value is Dictionary:
			_append_unique_engine_events(
				result,
				seen,
				(nested_value as Dictionary).get("engine_events", [])
			)
	return result


static func _append_unique_engine_events(
	target: Array[Dictionary],
	seen: Dictionary,
	values: Variant
) -> void:
	if not values is Array:
		return
	for value in values as Array:
		if not value is Dictionary:
			continue
		var event: Dictionary = (value as Dictionary).duplicate(true)
		var metadata: Dictionary = _dictionary_value(event, "metadata")
		var event_kind: String = _get_engine_event_kind(event, metadata)
		if event_kind in [
			"stateful_modifier",
			"cross_family_activation",
			"ordinal_activation",
		]:
			# These are diagnostic mirrors of canonical modifier resolution steps.
			continue
		var key: String = str(event.get(
			"engine_event_id",
			event.get("event_id", event.get("state_event_id", ""))
		))
		if key.is_empty():
			key = "%s|%s|%s|%d|%s|%s" % [
				event_kind,
				str(event.get("eight_ball_item_id", event.get("item_id", event.get("source_id", "")))),
				str(event.get("trigger_occurrence_id", metadata.get("trigger_occurrence_id", ""))),
				int(event.get("trigger_event_index", event.get("event_index", -1))),
				str(event.get("value_before", metadata.get("value_before", ""))),
				str(event.get("value_after", metadata.get("value_after", ""))),
			]
		if seen.has(key):
			continue
		seen[key] = true
		target.append(event)


static func _map_engine_event(engine_event: Dictionary, input_index: int) -> Dictionary:
	var metadata: Dictionary = _dictionary_value(engine_event, "metadata").duplicate(true)
	var raw_event_kind: String = _get_engine_event_kind(engine_event, metadata)
	var event_type: String = (
		"state_growth"
		if raw_event_kind in ["state_growth", "state_mutation", "persistent_growth"]
		else "threshold_marker"
		if raw_event_kind in ["threshold_retrigger", "threshold_marker", "retrigger_marker"]
		else raw_event_kind
	)
	var item_id: String = str(engine_event.get(
		"eight_ball_item_id",
		engine_event.get("item_id", engine_event.get("source_id", ""))
	))
	var slot_index: int = int(engine_event.get(
		"slot_index",
		engine_event.get(
			"tray_slot_index",
			metadata.get("slot_index", metadata.get("tray_slot_index", -1))
		)
	))
	var owned_instance_id: int = int(engine_event.get(
		"owned_item_instance_id",
		metadata.get("owned_item_instance_id", 0)
	))
	var title: String = str(engine_event.get(
		"display_name",
		engine_event.get("title", item_id.replace("_", " ").capitalize())
	)).to_upper()
	var effect_text: String = _engine_event_effect_text(engine_event, metadata, event_type)
	metadata["engine_event_type"] = event_type
	metadata["engine_event_kind"] = raw_event_kind
	metadata["eight_ball_item_id"] = item_id
	metadata["slot_index"] = slot_index
	metadata["owned_item_instance_id"] = owned_instance_id
	metadata["is_retrigger_marker"] = event_type in [
		"threshold_marker",
		"retrigger_marker",
	]
	if event_type == "threshold_marker":
		metadata["retrigger_source_item_id"] = item_id
		metadata["retrigger_threshold_ordinal"] = int(engine_event.get(
			"tap_ordinal",
			engine_event.get(
				"threshold_ordinal",
				metadata.get("retrigger_threshold_ordinal", 3)
			)
		))
	return {
		"engine_event_index": input_index,
		"engine_event_type": event_type,
		"source_id": item_id,
		"source_type": "engine_state",
		"phase": str(engine_event.get("phase", "engine_marker")),
		"title": title,
		"effect_text": effect_text,
		"affects_score": false,
		"event_index": int(engine_event.get(
			"trigger_event_index",
			engine_event.get("event_index", -1)
		)),
		"trigger_occurrence_id": str(engine_event.get(
			"trigger_occurrence_id",
			metadata.get("trigger_occurrence_id", "")
		)),
		"eight_ball_item_id": item_id,
		"owned_item_instance_id": owned_instance_id,
		"tray_slot_index": slot_index,
		"effect_kind": str(engine_event.get(
			"effect_kind",
			metadata.get("effect_kind", "")
		)),
		"is_retrigger_marker": bool(metadata.get("is_retrigger_marker", false)),
		"retrigger_threshold_ordinal": int(metadata.get(
			"retrigger_threshold_ordinal",
			0
		)),
		"value_before": float(engine_event.get(
			"value_before",
			metadata.get("value_before", metadata.get("state_value_before", 0.0))
		)),
		"value_after": float(engine_event.get(
			"value_after",
			metadata.get("value_after", metadata.get("state_value_after", 0.0))
		)),
		"anchor_type": "hud",
		"coordinate_space": "hud",
		"hud_anchor_id": "long_sink_equation",
		"anchor_reason": "value_only_engine_event",
		"metadata": metadata,
	}


static func _engine_event_effect_text(
	engine_event: Dictionary,
	metadata: Dictionary,
	event_type: String
) -> String:
	var explicit: String = str(engine_event.get(
		"effect_text",
		engine_event.get("display_text", engine_event.get("label", ""))
	)).strip_edges()
	if not explicit.is_empty():
		return explicit
	if event_type in ["state_growth", "state_mutation", "persistent_growth"]:
		var before: float = float(engine_event.get(
			"value_before",
			metadata.get("value_before", metadata.get("state_value_before", 0.0))
		))
		var after: float = float(engine_event.get(
			"value_after",
			metadata.get("value_after", metadata.get("state_value_after", before))
		))
		return "x%s -> x%s" % [_format_number(before), _format_number(after)]
	if event_type in ["threshold_marker", "retrigger_marker"]:
		var ordinal: int = maxi(int(engine_event.get(
			"tap_ordinal",
			engine_event.get(
				"threshold_ordinal",
				metadata.get(
					"retrigger_threshold_ordinal",
					metadata.get("tap_ordinal", 3)
				)
			)
		)), 1)
		return "%s TAP - RETRIGGER" % _ordinal_word(ordinal).to_upper()
	return str(engine_event.get("label", "ENGINE EVENT")).to_upper()


static func _build_event_lookup(ledger: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for event_value in _array_value(ledger, "raw_events"):
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		lookup[str(int(event.get("event_index", -1)))] = event.duplicate(true)
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
				continue
			var milestone: Dictionary = (milestone_value as Dictionary).duplicate(true)
			var ball_id: int = int(milestone.get("ball_id", -1))
			var event_index: int = int(milestone.get("event_index", -1))
			if ball_id <= 0 or event_index < 0:
				continue
			var key: String = _tap_milestone_key(event_type, ball_id, event_index)
			if lookup.has(key):
				continue
			lookup[key] = milestone
			canonical_count += 1
	diagnostics["canonical_tap_milestone_count"] = canonical_count
	return lookup


static func _get_canonical_tap_milestone(
	step: Dictionary,
	lookup: Dictionary
) -> Dictionary:
	var event_type: String = ""
	if _is_cue_recontact_step(step):
		event_type = "cue_recontact_milestone"
	elif _is_object_ball_tap_step(step):
		event_type = "object_ball_tap_milestone"
	else:
		return {}
	return _dictionary_value(lookup, _tap_milestone_key(
		event_type,
		int(step.get("ball_id", -1)),
		int(step.get("event_index", -1))
	))


static func _tap_milestone_key(
	event_type: String,
	ball_id: int,
	event_index: int
) -> String:
	return "%s:%d:%d" % [event_type, ball_id, event_index]


static func _event_at(lookup: Dictionary, event_index: int) -> Dictionary:
	var value: Variant = lookup.get(str(event_index), {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _note_missing_event(event_index: int, diagnostics: Dictionary) -> void:
	var missing: Array = _array_value(diagnostics, "missing_event_indices")
	if event_index >= 0 and not missing.has(event_index):
		missing.append(event_index)
	diagnostics["missing_event_indices"] = missing


static func _first_valid_position(container: Dictionary, keys: Array[String]) -> Vector2:
	for key in keys:
		var position: Vector2 = _variant_position(container.get(key, null))
		if _is_finite_position(position):
			return position
	return Vector2(INF, INF)


static func _variant_position(value: Variant) -> Vector2:
	return value if value is Vector2 else Vector2(INF, INF)


static func _is_finite_position(position: Vector2) -> bool:
	return is_finite(position.x) and is_finite(position.y)


static func _identity_matches(result: Dictionary, ledger: Dictionary) -> bool:
	if result.is_empty() or ledger.is_empty():
		return false
	return (
		str(result.get("run_generation", "")) == str(ledger.get("run_generation", ""))
		and str(result.get("mode_id", "")) == str(ledger.get("mode_id", ""))
		and int(result.get("shot_id", -1)) == int(ledger.get("shot_id", -2))
		and int(result.get("attempt_id", -1)) == int(ledger.get("attempt_id", -2))
	)


static func _resolution_key(result: Dictionary) -> String:
	return "%s|%s|%d|%d" % [
		str(result.get("run_generation", "")),
		str(result.get("mode_id", "")),
		int(result.get("shot_id", -1)),
		int(result.get("attempt_id", -1)),
	]


static func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.2f" % value).trim_suffix("0").trim_suffix(".")


static func _signed_number(value: float) -> String:
	return "+%s" % _format_number(value) if value >= 0.0 else _format_number(value)


static func _ordinal_word(value: int) -> String:
	match value:
		1:
			return "first"
		2:
			return "second"
		3:
			return "third"
		_:
			return "%dth" % value


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


static func _append_case(cases: Array[Dictionary], name: String, passed: bool, expected: Variant, actual: Variant) -> void:
	cases.append({"name": name, "passed": passed, "expected": expected, "actual": actual})


static func _step_position(steps: Array, index: int) -> Vector2:
	if index < 0 or index >= steps.size() or not (steps[index] is Dictionary):
		return Vector2(INF, INF)
	return _variant_position((steps[index] as Dictionary).get("world_position", null))


static func _step_value(steps: Array, index: int, key: String, fallback: Variant) -> Variant:
	if index < 0 or index >= steps.size() or not (steps[index] is Dictionary):
		return fallback
	return (steps[index] as Dictionary).get(key, fallback)


static func _test_ledger() -> Dictionary:
	return {
		"run_generation": "test",
		"mode_id": "shot_lab",
		"shot_id": 1,
		"attempt_id": 1,
		"starting_balls": {
			"2": {"ball_id": 2, "ball_number": 2},
			"4": {"ball_id": 4, "ball_number": 4},
		},
		"derived": {
			"cue_recontact_milestones": [{
				"trigger_occurrence_id": "cue_recontact_milestone:2:6:2",
				"ball_id": 2,
				"ball_number": 2,
				"event_index": 6,
				"world_position": Vector2(320.0, 160.0),
				"cue_strike_ordinal": 2,
				"bonus_ordinal": 1,
				"display_tier": "double_tap",
			}],
			"object_ball_tap_milestones": [{
				"trigger_occurrence_id": "object_ball_tap_milestone:2:4:7",
				"ball_id": 2,
				"ball_number": 2,
				"contacted_ball_id": 4,
				"event_index": 7,
				"world_position": Vector2(360.0, 160.0),
				"unique_contact_ordinal": 2,
				"display_tier": "ball_tap_x2",
			}],
		},
		"raw_events": [
			{"event_index": 2, "event_type": "pocket", "pocket_center": Vector2(100.0, 200.0), "capture_position": Vector2(102.0, 198.0), "pocket_index": 0},
			{"event_index": 3, "event_type": "rail_contact", "contact_point": Vector2(240.0, 80.0), "rail_id": "top"},
			{"event_index": 4, "event_type": "ball_contact", "contact_point": Vector2(180.0, 140.0)},
			{"event_index": 6, "event_type": "ball_contact", "contact_point": Vector2(321.0, 160.0), "contact_normal": Vector2.RIGHT, "source_ball_id": 1, "target_ball_id": 2},
			{"event_index": 7, "event_type": "ball_contact", "contact_point": Vector2(361.0, 160.0), "contact_normal": Vector2.RIGHT, "source_ball_id": 2, "target_ball_id": 4},
		],
	}


static func _test_result() -> Dictionary:
	return {
		"run_generation": "test",
		"mode_id": "shot_lab",
		"shot_id": 1,
		"attempt_id": 1,
		"eight_ball_build_evaluation": {
			"engine_events": [
			{
				"engine_event_kind": "state_growth",
				"display_name": "Rattle of the Deep",
				"eight_ball_item_id": "tap_stateful_xmult_rattle_of_the_deep",
				"slot_index": 2,
				"owned_item_instance_id": 14,
				"trigger_event_index": 6,
				"trigger_occurrence_id": "cue_recontact_milestone:2:6:2",
				"value_before": 1.4,
				"value_after": 1.6,
			},
			{
				"engine_event_kind": "stateful_modifier",
				"display_name": "Rattle of the Deep",
				"eight_ball_item_id": "tap_stateful_xmult_rattle_of_the_deep",
				"tray_slot_index": 2,
				"trigger_event_index": 6,
				"trigger_occurrence_id": "cue_recontact_milestone:2:6:2",
			},
			{
				"engine_event_kind": "threshold_retrigger",
				"display_name": "Echo Chamber",
				"eight_ball_item_id": "tap_legendary_retrigger_echo_chamber",
				"tray_slot_index": 4,
				"tap_ordinal": 3,
				"trigger_event_index": 7,
				"label": "THIRD TAP - RETRIGGER",
			},
			],
		},
		"resolution_steps": [
			{"step_index": 0, "source_id": "base_object_ball_value", "source_type": "pocketed_object_ball", "display_name": "Ball Sunk", "event_index": 2, "ball_id": 2, "haul_delta": 10, "mult_delta": 0.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {}},
			{"step_index": 1, "source_id": "base_bank_rail", "source_type": "rail_contact", "display_name": "Rail", "event_index": 3, "ball_id": 2, "haul_delta": 0, "mult_delta": 1.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {"capped_count": 1, "scored_rail_event_indices": [3], "pocket_event_index": 2}},
			{"step_index": 2, "source_id": "base_combination", "source_type": "combination_pot", "display_name": "Combination", "event_index": 4, "ball_id": 2, "haul_delta": 0, "mult_delta": 1.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {"causal_activation_event_index": 4}},
			{"step_index": 3, "source_id": "debug_x2", "source_type": "modifier", "display_name": "Black Flag", "event_index": -1, "ball_id": -1, "haul_delta": 0, "mult_delta": 0.0, "xmult_factor": 2.0, "affects_score": true, "metadata": {"slot_index": 0}},
			{"step_index": 4, "source_id": SOURCE_CUE_RECONTACT, "source_type": SOURCE_CUE_RECONTACT_MILESTONE, "display_name": "Double Tap", "event_index": 6, "ball_id": 2, "haul_delta": 0, "mult_delta": 1.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {"trigger_id": SOURCE_CUE_RECONTACT_MILESTONE, "cue_strike_ordinal": 2, "bonus_ordinal": 1, "contacted_ball_id": 1}},
			{"step_index": 5, "source_id": SOURCE_OBJECT_BALL_TAP, "source_type": SOURCE_OBJECT_BALL_TAP_MILESTONE, "display_name": "Ball Tap", "event_index": 7, "ball_id": 2, "haul_delta": 0, "mult_delta": 1.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {"trigger_id": SOURCE_OBJECT_BALL_TAP_MILESTONE, "unique_contact_ordinal": 2, "contacted_ball_id": 4}},
		],
	}
