extends RefCounted
class_name RogueliteScorePresentationMapper

const SCHEMA_VERSION := 2
const SELF_TEST_CASE_COUNT := 8

const SOURCE_CUE_RECONTACT := "base_cue_recontact"
const SOURCE_CUE_RECONTACT_MILESTONE := "cue_recontact_milestone"
const SOURCE_OBJECT_BALL_TAP := "base_object_ball_tap"
const SOURCE_OBJECT_BALL_TAP_MILESTONE := "object_ball_tap_milestone"


static func map_score_result(score_result: Dictionary, frozen_ledger: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = {
		"identity_match": _identity_matches(score_result, frozen_ledger),
		"mapped_anchor_count": 0,
		"fallback_count": 0,
		"missing_event_indices": [],
		"invalid_position_count": 0,
		"warnings": [],
	}
	var mapped_steps: Array[Dictionary] = []
	if score_result.is_empty() or frozen_ledger.is_empty() or not bool(diagnostics["identity_match"]):
		diagnostics["warnings"].append("Score result and frozen Shot Ledger identities do not match.")
		return {
			"schema_version": SCHEMA_VERSION,
			"resolution_key": _resolution_key(score_result),
			"steps": mapped_steps,
			"diagnostics": diagnostics,
		}

	var event_lookup: Dictionary = _build_event_lookup(frozen_ledger)
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
			diagnostics
		)
		mapped_steps.append(mapped)
		if str(mapped.get("anchor_type", "hud")) == "world":
			diagnostics["mapped_anchor_count"] = int(diagnostics["mapped_anchor_count"]) + 1
		if bool(mapped.get("fallback_used", false)):
			diagnostics["fallback_count"] = int(diagnostics["fallback_count"]) + 1
			var fallback_reason: String = str(mapped.get("fallback_reason", ""))
			if not fallback_reason.is_empty():
				diagnostics["warnings"].append(fallback_reason)

	return {
		"schema_version": SCHEMA_VERSION,
		"resolution_key": _resolution_key(score_result),
		"steps": mapped_steps,
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
	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"total": cases.size(),
		"passed": passed,
		"failed": failures.size(),
		"failures": failures,
	}


static func _map_step(
	step: Dictionary,
	event_lookup: Dictionary,
	tap_milestone_lookup: Dictionary,
	diagnostics: Dictionary
) -> Dictionary:
	var source_id: String = str(step.get("source_id", ""))
	var source_type: String = str(step.get("source_type", ""))
	var event_index: int = int(step.get("event_index", -1))
	var metadata: Dictionary = _dictionary_value(step, "metadata")
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
		"effect_text": _step_effect_text(step),
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
	}

	match source_id:
		"base_object_ball_value", "base_additional_ball", "scratch":
			_apply_pocket_anchor(mapped, event_lookup, event_index, diagnostics)
		"base_bank_rail":
			_apply_rail_anchor(mapped, event_lookup, metadata, diagnostics)
		"base_combination":
			_apply_contact_anchor(mapped, event_lookup, event_index, diagnostics)
		_:
			if _is_tap_step(step):
				_apply_canonical_tap_anchor(
					mapped,
					event_lookup,
					canonical_tap,
					diagnostics
				)
			elif source_type == "modifier":
				mapped["anchor_reason"] = "modifier_hud_anchor"
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
	var haul_delta: int = int(step.get("haul_delta", 0))
	if haul_delta != 0:
		return "%s HAUL" % _signed_number(float(haul_delta))
	var xmult: float = float(step.get("xmult_factor", 1.0))
	if not is_equal_approx(xmult, 1.0):
		return "x%s MULT" % _format_number(xmult)
	var mult_delta: float = float(step.get("mult_delta", 0.0))
	if not is_zero_approx(mult_delta):
		return "%s MULT" % _signed_number(mult_delta)
	return "Score unchanged"


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
	return "%.2f" % value


static func _signed_number(value: float) -> String:
	return "+%s" % _format_number(value) if value >= 0.0 else _format_number(value)


static func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []


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
		"resolution_steps": [
			{"step_index": 0, "source_id": "base_object_ball_value", "source_type": "pocketed_object_ball", "display_name": "Ball Sunk", "event_index": 2, "ball_id": 2, "haul_delta": 10, "mult_delta": 0.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {}},
			{"step_index": 1, "source_id": "base_bank_rail", "source_type": "rail_contact", "display_name": "Rail", "event_index": 3, "ball_id": 2, "haul_delta": 0, "mult_delta": 1.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {"capped_count": 1, "scored_rail_event_indices": [3], "pocket_event_index": 2}},
			{"step_index": 2, "source_id": "base_combination", "source_type": "combination_pot", "display_name": "Combination", "event_index": 4, "ball_id": 2, "haul_delta": 0, "mult_delta": 1.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {"causal_activation_event_index": 4}},
			{"step_index": 3, "source_id": "debug_x2", "source_type": "modifier", "display_name": "Black Flag", "event_index": -1, "ball_id": -1, "haul_delta": 0, "mult_delta": 0.0, "xmult_factor": 2.0, "affects_score": true, "metadata": {"slot_index": 0}},
			{"step_index": 4, "source_id": SOURCE_CUE_RECONTACT, "source_type": SOURCE_CUE_RECONTACT_MILESTONE, "display_name": "Double Tap", "event_index": 6, "ball_id": 2, "haul_delta": 0, "mult_delta": 1.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {"trigger_id": SOURCE_CUE_RECONTACT_MILESTONE, "cue_strike_ordinal": 2, "bonus_ordinal": 1, "contacted_ball_id": 1}},
			{"step_index": 5, "source_id": SOURCE_OBJECT_BALL_TAP, "source_type": SOURCE_OBJECT_BALL_TAP_MILESTONE, "display_name": "Ball Tap", "event_index": 7, "ball_id": 2, "haul_delta": 0, "mult_delta": 1.0, "xmult_factor": 1.0, "affects_score": true, "metadata": {"trigger_id": SOURCE_OBJECT_BALL_TAP_MILESTONE, "unique_contact_ordinal": 2, "contacted_ball_id": 4}},
		],
	}
