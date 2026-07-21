extends RefCounted
class_name RogueliteScoreResolver

# Pure, value-only Haul x Mult resolution for authoritative and predicted ledgers.
# This resolver never reads scene state and never mutates the supplied ledger.

const SCHEMA_VERSION := 1
const SCORING_MODEL := "haul_mult_v1"
# Predicted Shot Lab ledgers currently use v1; authoritative frozen ledgers use v2.
const SUPPORTED_LEDGER_SCHEMA_VERSIONS := [1, 2]
const SUPPORTED_ANALYZED_SCHEMA_VERSION := ShotLedgerAnalyzer.SCHEMA_VERSION
const BASE_OBJECT_BALL_HAUL := 10
const BASE_MULT := 1.0
const MAX_RAIL_MULT_PER_BALL := 3
const SELF_TEST_CASE_COUNT := 26

const SOURCE_BASE_CUE_RECONTACT := "base_cue_recontact"
const SOURCE_BASE_OBJECT_BALL_TAP := "base_object_ball_tap"

const PHASE_ADD_HAUL := "add_haul"
const PHASE_ADD_MULT := "add_mult"
const PHASE_XMULT := "xmult"
const MODIFIER_PHASE_ORDER := {
	PHASE_ADD_HAUL: 0,
	PHASE_ADD_MULT: 1,
	PHASE_XMULT: 2,
}


static func resolve(analyzed_ledger: Dictionary, ordered_modifiers: Array = []) -> Dictionary:
	var result: Dictionary = _make_empty_result(analyzed_ledger)
	var warnings: Array[String] = []
	var diagnostics: Dictionary = {
		"input_valid": false,
		"accepted_pocket_fact_count": 0,
		"rejected_pocket_fact_count": 0,
		"uncapped_rail_contact_count": 0,
		"capped_rail_mult_count": 0,
		"cue_recontact_mult_count": 0,
		"object_ball_tap_mult_count": 0,
		"cue_recontact_fact_mismatch_count": 0,
		"object_ball_tap_fact_mismatch_count": 0,
		"duplicate_object_ball_tap_ids_ignored": 0,
		"modifier_count_received": ordered_modifiers.size(),
		"modifier_count_applied": 0,
		"source_counts": {},
		"rail_mult_cap_per_ball": MAX_RAIL_MULT_PER_BALL,
		"authoritative_score_applied_to_round": false,
	}
	result["diagnostics"] = diagnostics

	if _contains_live_node_reference(analyzed_ledger) or _contains_live_node_reference(ordered_modifiers):
		warnings.append("Scoring input contains a live Node reference; resolution was rejected.")
		return _finalize_safe_zero(result, warnings, diagnostics)
	var ledger_schema_version_value: Variant = analyzed_ledger.get("schema_version", null)
	if (
		not _is_positive_integer(ledger_schema_version_value)
		or int(ledger_schema_version_value) not in SUPPORTED_LEDGER_SCHEMA_VERSIONS
	):
		warnings.append("Unsupported, missing, or invalid Shot Ledger schema version.")
		return _finalize_safe_zero(result, warnings, diagnostics)
	diagnostics["ledger_schema_version"] = int(ledger_schema_version_value)
	var derived_value: Variant = analyzed_ledger.get("derived", null)
	if not derived_value is Dictionary:
		warnings.append("Analyzed Shot Ledger derived data is missing.")
		return _finalize_safe_zero(result, warnings, diagnostics)
	var derived: Dictionary = derived_value as Dictionary
	if int(derived.get("schema_version", -1)) != SUPPORTED_ANALYZED_SCHEMA_VERSION:
		warnings.append("Unsupported analyzed-ledger schema version.")
		return _finalize_safe_zero(result, warnings, diagnostics)
	if _contains_live_node_reference(derived):
		warnings.append("Analyzed Shot Ledger contains a live Node reference.")
		return _finalize_safe_zero(result, warnings, diagnostics)

	var object_count_value: Variant = derived.get("object_ball_pocket_count", null)
	if not _is_nonnegative_integer(object_count_value):
		warnings.append("Object-ball pocket count is missing or invalid.")
		return _finalize_safe_zero(result, warnings, diagnostics)
	var object_ball_pocket_count: int = int(object_count_value)
	var pocket_facts_value: Variant = derived.get("pocket_facts", null)
	var pocketed_ids_value: Variant = derived.get("object_balls_pocketed", null)
	if not pocket_facts_value is Array or not pocketed_ids_value is Array:
		warnings.append("Semantic pocket facts are missing or malformed.")
		return _finalize_safe_zero(result, warnings, diagnostics)
	var pocket_facts_raw: Array = pocket_facts_value as Array
	var pocketed_ids_raw: Array = pocketed_ids_value as Array
	if pocket_facts_raw.size() != object_ball_pocket_count or pocketed_ids_raw.size() != object_ball_pocket_count:
		warnings.append("Semantic pocket count does not match the analyzed pocket facts.")
		return _finalize_safe_zero(result, warnings, diagnostics)

	var semantic_ids: Dictionary = {}
	for ball_id_value in pocketed_ids_raw:
		if not _is_positive_integer(ball_id_value):
			warnings.append("Semantic pocketed-ball IDs contain an invalid value.")
			return _finalize_safe_zero(result, warnings, diagnostics)
		var semantic_id: int = int(ball_id_value)
		if semantic_ids.has(semantic_id):
			warnings.append("Semantic pocketed-ball IDs are not unique.")
			return _finalize_safe_zero(result, warnings, diagnostics)
		semantic_ids[semantic_id] = true

	var pocket_facts: Array[Dictionary] = []
	var fact_ids: Dictionary = {}
	for fact_value in pocket_facts_raw:
		if not fact_value is Dictionary:
			diagnostics["rejected_pocket_fact_count"] = int(diagnostics["rejected_pocket_fact_count"]) + 1
			warnings.append("A semantic pocket fact is not a Dictionary.")
			return _finalize_safe_zero(result, warnings, diagnostics)
		var fact: Dictionary = (fact_value as Dictionary).duplicate(true)
		var ball_id_value: Variant = fact.get("ball_id", null)
		var bank_count_value: Variant = fact.get("bank_count", null)
		if not _is_positive_integer(ball_id_value) or not _is_nonnegative_integer(bank_count_value):
			diagnostics["rejected_pocket_fact_count"] = int(diagnostics["rejected_pocket_fact_count"]) + 1
			warnings.append("A semantic pocket fact has an invalid ball ID or bank count.")
			return _finalize_safe_zero(result, warnings, diagnostics)
		var ball_id: int = int(ball_id_value)
		if fact_ids.has(ball_id) or not semantic_ids.has(ball_id):
			diagnostics["rejected_pocket_fact_count"] = int(diagnostics["rejected_pocket_fact_count"]) + 1
			warnings.append("Semantic pocket facts contain a duplicate or unclassified ball ID.")
			return _finalize_safe_zero(result, warnings, diagnostics)
		fact_ids[ball_id] = true
		pocket_facts.append(fact)

	pocket_facts.sort_custom(_pocket_fact_precedes)
	diagnostics["input_valid"] = true
	diagnostics["accepted_pocket_fact_count"] = pocket_facts.size()
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

	var resolution_steps: Array[Dictionary] = []
	var haul_additions: Array[Dictionary] = []
	var mult_additions: Array[Dictionary] = []
	var xmult_steps: Array[Dictionary] = []
	var current_haul := 0
	var current_additive_mult := BASE_MULT
	var current_xmult_product := 1.0

	# Phase 1: semantic scoring-object pockets establish Base Haul.
	for fact in pocket_facts:
		var haul_before: int = current_haul
		current_haul += BASE_OBJECT_BALL_HAUL
		var contribution: Dictionary = {
			"phase": "base_haul",
			"source_type": "pocketed_object_ball",
			"source_id": "base_object_ball_value",
			"display_name": "Ball Sunk",
			"ball_id": int(fact.get("ball_id", -1)),
			"event_index": int(fact.get("pocket_event_index", -1)),
			"amount": BASE_OBJECT_BALL_HAUL,
		}
		resolution_steps.append(_make_resolution_step(
			resolution_steps.size(), contribution, haul_before, BASE_OBJECT_BALL_HAUL,
			current_haul, current_additive_mult, 0.0, 1.0, current_additive_mult,
			{"pocket_order": int(fact.get("pocket_order", 0))}
		))
		_increment_source_count(diagnostics, "base_object_ball_value")
	result["base_haul"] = current_haul

	# Phase 2A: one additive Mult for every scoring object after the first.
	for fact_index in range(1, pocket_facts.size()):
		var fact: Dictionary = pocket_facts[fact_index]
		var mult_before: float = current_additive_mult
		current_additive_mult += 1.0
		var contribution: Dictionary = {
			"phase": "base_mult",
			"source_type": "additional_pocketed_object_ball",
			"source_id": "base_additional_ball",
			"display_name": "Additional Ball",
			"ball_id": int(fact.get("ball_id", -1)),
			"event_index": int(fact.get("pocket_event_index", -1)),
			"amount": 1.0,
		}
		mult_additions.append(contribution.duplicate(true))
		resolution_steps.append(_make_resolution_step(
			resolution_steps.size(), contribution, current_haul, 0, current_haul,
			mult_before, 1.0, 1.0, current_additive_mult,
			{"pocket_order": int(fact.get("pocket_order", fact_index + 1))}
		))
		_increment_source_count(diagnostics, "base_additional_ball")

	# Phase 2B: semantic post-activation, pre-pocket rails, capped per ball.
	for fact in pocket_facts:
		var uncapped_count: int = int(fact.get("bank_count", 0))
		var capped_count: int = mini(uncapped_count, MAX_RAIL_MULT_PER_BALL)
		diagnostics["uncapped_rail_contact_count"] = int(diagnostics["uncapped_rail_contact_count"]) + uncapped_count
		diagnostics["capped_rail_mult_count"] = int(diagnostics["capped_rail_mult_count"]) + capped_count
		if capped_count <= 0:
			continue
		var mult_before: float = current_additive_mult
		current_additive_mult += float(capped_count)
		var qualifying_indices: Array = _array_value(fact, "qualifying_rail_event_indices")
		var scored_rail_event_indices: Array[int] = []
		for event_index_value in qualifying_indices:
			if scored_rail_event_indices.size() >= capped_count:
				break
			scored_rail_event_indices.append(int(event_index_value))
		var primary_rail_event_index: int = (
			scored_rail_event_indices[scored_rail_event_indices.size() - 1]
			if not scored_rail_event_indices.is_empty()
			else int(fact.get("pocket_event_index", -1))
		)
		var contribution: Dictionary = {
			"phase": "base_mult",
			"source_type": "rail_contact",
			"source_id": "base_bank_rail",
			"display_name": _rail_display_name(capped_count),
			"ball_id": int(fact.get("ball_id", -1)),
			"event_index": primary_rail_event_index,
			"amount": capped_count,
			"uncapped_count": uncapped_count,
			"capped_count": capped_count,
		}
		mult_additions.append(contribution.duplicate(true))
		resolution_steps.append(_make_resolution_step(
			resolution_steps.size(), contribution, current_haul, 0, current_haul,
			mult_before, float(capped_count), 1.0, current_additive_mult,
			{
				"uncapped_count": uncapped_count,
				"capped_count": capped_count,
				"cap_per_ball": MAX_RAIL_MULT_PER_BALL,
				"scored_rail_event_indices": scored_rail_event_indices.duplicate(),
				"pocket_event_index": int(fact.get("pocket_event_index", -1)),
			}
		))
		_increment_source_count(diagnostics, "base_bank_rail")

	# Phase 2C: each semantic combination pot contributes one additive Mult.
	for fact in pocket_facts:
		if not bool(fact.get("is_combination_pot", false)):
			continue
		var mult_before: float = current_additive_mult
		current_additive_mult += 1.0
		var contribution: Dictionary = {
			"phase": "base_mult",
			"source_type": "combination_pot",
			"source_id": "base_combination",
			"display_name": "Combination",
			"ball_id": int(fact.get("ball_id", -1)),
			"event_index": int(fact.get("causal_activation_event_index", -1)),
			"amount": 1.0,
		}
		mult_additions.append(contribution.duplicate(true))
		resolution_steps.append(_make_resolution_step(
			resolution_steps.size(), contribution, current_haul, 0, current_haul,
			mult_before, 1.0, 1.0, current_additive_mult,
			{
				"causal_depth": int(fact.get("causal_depth", -1)),
				"causal_activation_event_index": int(fact.get("causal_activation_event_index", -1)),
				"pocket_event_index": int(fact.get("pocket_event_index", -1)),
			}
		))
		_increment_source_count(diagnostics, "base_combination")

	# Phase 2D: each accepted cue recontact milestone contributes one additive Mult.
	for fact in pocket_facts:
		var ball_id: int = int(fact.get("ball_id", -1))
		var analyzer_milestones: Array[Dictionary] = _get_grouped_milestones_for_ball(
			cue_recontact_milestones_by_ball,
			ball_id
		)
		if not has_canonical_cue_recontact_milestones:
			analyzer_milestones = _make_legacy_cue_recontact_milestones(fact)
		var declared_count: int = maxi(int(fact.get("cue_recontact_bonus_count", 0)), 0)
		if declared_count != analyzer_milestones.size():
			diagnostics["cue_recontact_fact_mismatch_count"] = int(
				diagnostics["cue_recontact_fact_mismatch_count"]
			) + 1
			warnings.append(
				"Cue-recontact pocket count does not match derived milestones for ball %d."
				% ball_id
			)
		var qualifying_strike_count: int = maxi(int(fact.get(
			"qualifying_cue_strike_count",
			analyzer_milestones.size() + 1
		)), 0)
		for milestone_index in range(analyzer_milestones.size()):
			var analyzer_milestone: Dictionary = analyzer_milestones[milestone_index]
			var event_index: int = int(analyzer_milestone.get("event_index", -1))
			if event_index < 0:
				diagnostics["cue_recontact_fact_mismatch_count"] = int(
					diagnostics["cue_recontact_fact_mismatch_count"]
				) + 1
				warnings.append("Cue-recontact milestone has an invalid event anchor.")
				continue
			var bonus_ordinal: int = maxi(int(analyzer_milestone.get(
				"bonus_ordinal",
				milestone_index + 1
			)), 1)
			var cue_strike_ordinal: int = maxi(int(analyzer_milestone.get(
				"cue_strike_ordinal",
				bonus_ordinal + 1
			)), 2)
			var position_result: Dictionary = _get_milestone_position(analyzer_milestone)
			var mult_before: float = current_additive_mult
			current_additive_mult += 1.0
			var contribution: Dictionary = {
				"phase": "base_mult",
				"source_type": "cue_recontact_milestone",
				"source_id": SOURCE_BASE_CUE_RECONTACT,
				"display_name": _cue_recontact_display_name(cue_strike_ordinal),
				"ball_id": ball_id,
				"event_index": event_index,
				"amount": 1.0,
			}
			var step_metadata: Dictionary = _dictionary_value(
				analyzer_milestone,
				"metadata"
			).duplicate(true)
			step_metadata.merge({
				"trigger_id": "cue_recontact_milestone",
				"trigger_occurrence_id": str(analyzer_milestone.get(
					"trigger_occurrence_id",
					"cue_recontact_milestone:%d:%d:%d" % [
						ball_id,
						event_index,
						cue_strike_ordinal,
					]
				)),
				"contacted_ball_id": int(analyzed_ledger.get("cue_ball_id", -1)),
				"qualifying_cue_strike_count": qualifying_strike_count,
				"cue_strike_ordinal": cue_strike_ordinal,
				"bonus_ordinal": bonus_ordinal,
				"display_tier": _cue_recontact_display_tier(cue_strike_ordinal),
				"world_position": position_result.get("position", Vector2.ZERO),
				"world_position_available": bool(position_result.get("available", false)),
				"pocket_event_index": int(fact.get("pocket_event_index", -1)),
			}, true)
			mult_additions.append(contribution.duplicate(true))
			resolution_steps.append(_make_resolution_step(
				resolution_steps.size(), contribution, current_haul, 0, current_haul,
				mult_before, 1.0, 1.0, current_additive_mult,
				step_metadata
			))
			diagnostics["cue_recontact_mult_count"] = int(
				diagnostics["cue_recontact_mult_count"]
			) + 1
			_increment_source_count(diagnostics, SOURCE_BASE_CUE_RECONTACT)

	# Phase 2E: each unique accepted object-ball tap contributes one additive Mult.
	for fact in pocket_facts:
		var ball_id: int = int(fact.get("ball_id", -1))
		var analyzer_milestones: Array[Dictionary] = _get_grouped_milestones_for_ball(
			object_ball_tap_milestones_by_ball,
			ball_id
		)
		if not has_canonical_object_ball_tap_milestones:
			analyzer_milestones = _make_legacy_object_ball_tap_milestones(fact)
		var declared_count: int = maxi(int(fact.get("unique_object_tap_count", 0)), 0)
		if declared_count != analyzer_milestones.size():
			diagnostics["object_ball_tap_fact_mismatch_count"] = int(
				diagnostics["object_ball_tap_fact_mismatch_count"]
			) + 1
			warnings.append(
				"Object-ball tap pocket count does not match derived milestones for ball %d."
				% ball_id
			)
		var seen_target_ids: Dictionary = {}
		for milestone_index in range(analyzer_milestones.size()):
			var analyzer_milestone: Dictionary = analyzer_milestones[milestone_index]
			var contacted_ball_id: int = int(analyzer_milestone.get(
				"contacted_ball_id",
				-1
			))
			var event_index: int = int(analyzer_milestone.get("event_index", -1))
			var target_key: String = str(contacted_ball_id)
			if contacted_ball_id <= 0 or event_index < 0:
				diagnostics["object_ball_tap_fact_mismatch_count"] = int(
					diagnostics["object_ball_tap_fact_mismatch_count"]
				) + 1
				warnings.append("Object-ball tap milestone has an invalid target or event anchor.")
				continue
			if seen_target_ids.has(target_key):
				diagnostics["duplicate_object_ball_tap_ids_ignored"] = int(
					diagnostics["duplicate_object_ball_tap_ids_ignored"]
				) + 1
				continue
			seen_target_ids[target_key] = true
			var unique_contact_ordinal: int = maxi(int(analyzer_milestone.get(
				"unique_contact_ordinal",
				milestone_index + 1
			)), 1)
			var position_result: Dictionary = _get_milestone_position(analyzer_milestone)
			var mult_before: float = current_additive_mult
			current_additive_mult += 1.0
			var contribution: Dictionary = {
				"phase": "base_mult",
				"source_type": "object_ball_tap_milestone",
				"source_id": SOURCE_BASE_OBJECT_BALL_TAP,
				"display_name": _object_ball_tap_display_name(unique_contact_ordinal),
				"ball_id": ball_id,
				"event_index": event_index,
				"amount": 1.0,
			}
			var step_metadata: Dictionary = _dictionary_value(
				analyzer_milestone,
				"metadata"
			).duplicate(true)
			step_metadata.merge({
				"trigger_id": "object_ball_tap_milestone",
				"trigger_occurrence_id": str(analyzer_milestone.get(
					"trigger_occurrence_id",
					"object_ball_tap_milestone:%d:%d:%d" % [
						ball_id,
						contacted_ball_id,
						event_index,
					]
				)),
				"contacted_ball_id": contacted_ball_id,
				"unique_contact_ordinal": unique_contact_ordinal,
				"unique_target_count": declared_count,
				"repeated_target_contact": false,
				"world_position": position_result.get("position", Vector2.ZERO),
				"world_position_available": bool(position_result.get("available", false)),
				"pocket_event_index": int(fact.get("pocket_event_index", -1)),
			}, true)
			mult_additions.append(contribution.duplicate(true))
			resolution_steps.append(_make_resolution_step(
				resolution_steps.size(), contribution, current_haul, 0, current_haul,
				mult_before, 1.0, 1.0, current_additive_mult,
				step_metadata
			))
			diagnostics["object_ball_tap_mult_count"] = int(
				diagnostics["object_ball_tap_mult_count"]
			) + 1
			_increment_source_count(diagnostics, SOURCE_BASE_OBJECT_BALL_TAP)

	# Build phases: ordered modifier plumbing, with no reward logic.
	var sorted_modifiers: Array[Dictionary] = _get_sorted_modifiers(ordered_modifiers, warnings)
	for modifier in sorted_modifiers:
		if not bool(modifier.get("enabled", true)):
			continue
		var conditions_value: Variant = modifier.get("conditions", {})
		if conditions_value is Dictionary and not (conditions_value as Dictionary).is_empty():
			warnings.append("Modifier `%s` has unsupported conditions and was skipped." % str(modifier.get("modifier_id", "unknown")))
			continue
		var phase: String = str(modifier.get("phase", ""))
		var modifier_id: String = str(modifier.get("modifier_id", "unknown_modifier"))
		var display_name: String = str(modifier.get("display_name", modifier_id))
		var value: Variant = modifier.get("value", null)
		if not _is_finite_number(value):
			warnings.append("Modifier `%s` has a non-finite value and was skipped." % modifier_id)
			continue
		var contribution: Dictionary = {
			"phase": phase,
			"source_type": "modifier",
			"source_id": modifier_id,
			"display_name": display_name,
			"event_index": int(modifier.get(
				"trigger_event_index",
				modifier.get("event_index", -1)
			)),
			"ball_id": int(modifier.get(
				"trigger_ball_id",
				modifier.get("ball_id", -1)
			)),
			"slot_index": int(modifier.get("slot_index", 0)),
			"amount": value,
		}
		match phase:
			PHASE_ADD_HAUL:
				if not _is_integer_number(value):
					warnings.append("Add-Haul modifier `%s` must use an integer value." % modifier_id)
					continue
				var haul_before: int = current_haul
				var haul_delta: int = int(value)
				current_haul += haul_delta
				haul_additions.append(contribution.duplicate(true))
				resolution_steps.append(_make_resolution_step(
					resolution_steps.size(), contribution, haul_before, haul_delta,
					current_haul, current_additive_mult * current_xmult_product,
					0.0, 1.0, current_additive_mult * current_xmult_product,
					_make_modifier_step_metadata(modifier, PHASE_ADD_HAUL)
				))
			PHASE_ADD_MULT:
				var mult_before: float = current_additive_mult * current_xmult_product
				var mult_delta: float = float(value)
				current_additive_mult += mult_delta
				mult_additions.append(contribution.duplicate(true))
				resolution_steps.append(_make_resolution_step(
					resolution_steps.size(), contribution, current_haul, 0, current_haul,
					mult_before, mult_delta, 1.0,
					current_additive_mult * current_xmult_product,
					_make_modifier_step_metadata(modifier, PHASE_ADD_MULT)
				))
			PHASE_XMULT:
				var factor: float = float(value)
				var mult_before: float = current_additive_mult * current_xmult_product
				current_xmult_product *= factor
				contribution["factor"] = factor
				xmult_steps.append(contribution.duplicate(true))
				resolution_steps.append(_make_resolution_step(
					resolution_steps.size(), contribution, current_haul, 0, current_haul,
					mult_before, 0.0, factor,
					current_additive_mult * current_xmult_product,
					_make_modifier_step_metadata(modifier, PHASE_XMULT)
				))
			_:
				warnings.append("Modifier `%s` uses unsupported phase `%s`." % [modifier_id, phase])
				continue
		diagnostics["modifier_count_applied"] = int(diagnostics["modifier_count_applied"]) + 1
		_increment_source_count(diagnostics, modifier_id)

	var final_haul: int = maxi(current_haul, 0)
	var mult_before_xmult: float = maxf(current_additive_mult, 0.0)
	var xmult_product: float = maxf(current_xmult_product, 0.0)
	var final_mult: float = maxf(mult_before_xmult * xmult_product, 0.0)
	var shot_score: int = maxi(int(floor(float(final_haul) * final_mult)), 0)
	result["haul_additions"] = haul_additions
	result["final_haul"] = final_haul
	result["mult_additions"] = mult_additions
	result["mult_before_xmult"] = mult_before_xmult
	result["xmult_steps"] = xmult_steps
	result["xmult_product"] = xmult_product
	result["final_mult"] = final_mult
	result["shot_score"] = shot_score

	# Consequences are appended after final score and never reinterpret the shot.
	if bool(derived.get("scratch_occurred", false)):
		var scratch_step: Dictionary = {
			"step_index": resolution_steps.size(),
			"phase": "consequence",
			"source_id": "scratch",
			"source_type": "scratch",
			"display_name": "Scratch",
			"event_index": int(derived.get("cue_ball_pocket_event_index", -1)),
			"ball_id": int(analyzed_ledger.get("cue_ball_id", -1)),
			"haul_before": final_haul,
			"haul_delta": 0,
			"haul_after": final_haul,
			"mult_before": final_mult,
			"mult_delta": 0.0,
			"xmult_factor": 1.0,
			"mult_after": final_mult,
			"score_preview_after": shot_score,
			"affects_score": false,
			"metadata": {},
		}
		resolution_steps.append(scratch_step)
		_increment_source_count(diagnostics, "scratch")
	result["resolution_steps"] = resolution_steps
	diagnostics["resolution_step_count"] = resolution_steps.size()
	diagnostics["final_haul_was_clamped"] = current_haul < 0
	diagnostics["final_additive_mult_was_clamped"] = current_additive_mult < 0.0
	diagnostics["final_xmult_product_was_clamped"] = current_xmult_product < 0.0
	result["warnings"] = warnings
	return result.duplicate(true)


static func run_self_tests() -> Dictionary:
	var cases: Array[Dictionary] = []
	_run_score_case(cases, "Direct Pot", _test_ledger([_test_fact(2, 1, 0, false)]), [], {"shot_score": 10})
	_run_score_case(cases, "Miss", _test_ledger([]), [], {"shot_score": 0})
	_run_score_case(cases, "One-Rail Bank", _test_ledger([_test_fact(2, 1, 1, false)]), [], {"shot_score": 20})
	_run_score_case(cases, "Double Bank", _test_ledger([_test_fact(2, 1, 2, false)]), [], {"shot_score": 30})
	_run_score_case(cases, "Five-Rail Cap", _test_ledger([_test_fact(2, 1, 5, false)]), [], {
		"shot_score": 40,
		"diagnostics.capped_rail_mult_count": 3,
		"diagnostics.uncapped_rail_contact_count": 5,
	})
	_run_score_case(cases, "Combination", _test_ledger([_test_fact(2, 1, 0, true)]), [], {"shot_score": 20})
	_run_score_case(cases, "Bank Combination", _test_ledger([_test_fact(2, 1, 1, true)]), [], {"shot_score": 30})
	_run_score_case(cases, "Two Direct Pots", _test_ledger([
		_test_fact(2, 1, 0, false), _test_fact(3, 2, 0, false),
	]), [], {"shot_score": 40})
	_run_score_case(cases, "Direct Plus Double-Bank Multi-Pot", _test_ledger([
		_test_fact(2, 1, 0, false), _test_fact(3, 2, 2, false),
	]), [], {"shot_score": 80})
	_run_score_case(cases, "Double Tap", _test_ledger([
		_test_tap_fact(2, 1, 0, false, [3], [], [], 0),
	]), [], {
		"shot_score": 20,
		"source_counts.base_cue_recontact": 1,
	})
	_run_score_case(cases, "Triple Tap", _test_ledger([
		_test_tap_fact(2, 1, 0, false, [3, 5], [], [], 0),
	]), [], {
		"shot_score": 30,
		"source_counts.base_cue_recontact": 2,
	})
	_run_score_case(cases, "Tap x4", _test_ledger([
		_test_tap_fact(2, 1, 0, false, [3, 5, 7], [], [], 0),
	]), [], {
		"shot_score": 40,
		"source_counts.base_cue_recontact": 3,
	})
	_run_score_case(cases, "Ball Tap x1", _test_ledger([
		_test_tap_fact(2, 1, 0, false, [], [4], [4], 0),
	]), [], {
		"shot_score": 20,
		"source_counts.base_object_ball_tap": 1,
	})
	_run_score_case(cases, "Ball Tap x2", _test_ledger([
		_test_tap_fact(2, 1, 0, false, [], [4, 5], [4, 6], 0),
	]), [], {
		"shot_score": 30,
		"source_counts.base_object_ball_tap": 2,
	})
	_run_score_case(cases, "Repeated Same Target", _test_ledger([
		_test_tap_fact(2, 1, 0, false, [], [4], [4], 1),
	]), [], {
		"shot_score": 20,
		"source_counts.base_object_ball_tap": 1,
	})
	_run_score_case(cases, "Bank Plus Double Tap", _test_ledger([
		_test_tap_fact(2, 1, 1, false, [3], [], [], 0),
	]), [], {
		"shot_score": 30,
		"source_counts.base_bank_rail": 1,
		"source_counts.base_cue_recontact": 1,
	})
	_run_score_case(cases, "Combination Plus Ball Tap", _test_ledger([
		_test_tap_fact(2, 1, 0, true, [], [4], [5], 0),
	]), [], {
		"shot_score": 30,
		"source_counts.base_combination": 1,
		"source_counts.base_object_ball_tap": 1,
	})
	_run_score_case(cases, "Bank Combination Plus Ball Tap x2", _test_ledger([
		_test_tap_fact(2, 1, 1, true, [], [4, 5], [5, 7], 0),
	]), [], {
		"shot_score": 50,
		"source_counts.base_bank_rail": 1,
		"source_counts.base_combination": 1,
		"source_counts.base_object_ball_tap": 2,
	})
	_run_score_case(cases, "Cue Scratch", _test_ledger([], true), [], {"shot_score": 0, "source_counts.scratch": 1})
	_run_score_case(cases, "Direct Pot Plus Scratch", _test_ledger([_test_fact(2, 1, 0, false)], true), [], {"shot_score": 10, "source_counts.scratch": 1})
	_run_score_case(cases, "Add Haul Ordering", _test_ledger([_test_fact(2, 1, 0, false)]), [
		_test_modifier("debug_add_5", PHASE_ADD_HAUL, 1, 5),
		_test_modifier("debug_add_20", PHASE_ADD_HAUL, 0, 20),
	], {"final_haul": 35, "shot_score": 35, "modifier_order": ["debug_add_20", "debug_add_5"]})
	_run_score_case(cases, "Add Mult Ordering", _test_ledger([_test_fact(2, 1, 0, false)]), [
		_test_modifier("debug_add_mult_2", PHASE_ADD_MULT, 1, 2.0),
		_test_modifier("debug_add_mult_3", PHASE_ADD_MULT, 0, 3.0),
	], {"mult_before_xmult": 6.0, "shot_score": 60, "modifier_order": ["debug_add_mult_3", "debug_add_mult_2"]})
	_run_score_case(cases, "x1.5 Then x2", _test_ledger([_test_fact(2, 1, 0, false)]), [
		_test_modifier("debug_x1_5", PHASE_XMULT, 0, 1.5),
		_test_modifier("debug_x2", PHASE_XMULT, 1, 2.0),
	], {"xmult_product": 3.0, "shot_score": 30, "modifier_order": ["debug_x1_5", "debug_x2"]})
	_run_score_case(cases, "Full Debug Modifier Example", _test_ledger([_test_fact(2, 1, 0, false)]), [
		_test_modifier("debug_add_haul_20", PHASE_ADD_HAUL, 0, 20),
		_test_modifier("debug_add_mult_3", PHASE_ADD_MULT, 1, 3.0),
		_test_modifier("debug_x1_5", PHASE_XMULT, 2, 1.5),
		_test_modifier("debug_x2", PHASE_XMULT, 3, 2.0),
	], {"final_haul": 30, "final_mult": 12.0, "shot_score": 360})
	var invalid_result: Dictionary = resolve({})
	var unsupported_ledger: Dictionary = _test_ledger([])
	unsupported_ledger["schema_version"] = 99
	var unsupported_result: Dictionary = resolve(unsupported_ledger)
	var invalid_passed: bool = (
		int(invalid_result.get("shot_score", -1)) == 0
		and not _array_value(invalid_result, "warnings").is_empty()
		and int(unsupported_result.get("shot_score", -1)) == 0
		and not _array_value(unsupported_result, "warnings").is_empty()
	)
	cases.append(_make_test_case(
		"Invalid Ledger Is Safe", invalid_passed,
		{"shot_score": 0, "warning_count_min": 1},
		{"shot_score": invalid_result.get("shot_score", null), "warning_count": _array_value(invalid_result, "warnings").size()}
	))
	var parity_ledger: Dictionary = _test_ledger([_test_fact(2, 1, 1, true)])
	var predicted: Dictionary = resolve(parity_ledger.duplicate(true))
	var authoritative: Dictionary = resolve(parity_ledger.duplicate(true))
	var parity_passed: bool = _score_results_equal(predicted, authoritative)
	cases.append(_make_test_case(
		"Predicted Authoritative Parity", parity_passed,
		{"same_breakdown": true},
		{"same_breakdown": parity_passed}
	))

	var passed_count := 0
	var failures: Array[Dictionary] = []
	for case_result in cases:
		if bool(case_result.get("passed", false)):
			passed_count += 1
		else:
			failures.append(case_result.duplicate(true))
	return {
		"status": "PASS" if failures.is_empty() and cases.size() == SELF_TEST_CASE_COUNT else "FAIL",
		"timestamp": Time.get_datetime_string_from_system(),
		"total": cases.size(),
		"passed": passed_count,
		"failed": failures.size(),
		"cases": cases,
		"failures": failures,
	}


static func get_resolution_source_counts(score_result: Dictionary) -> Dictionary:
	var diagnostics_value: Variant = score_result.get("diagnostics", {})
	if not diagnostics_value is Dictionary:
		return {}
	var source_counts_value: Variant = (diagnostics_value as Dictionary).get("source_counts", {})
	return (source_counts_value as Dictionary).duplicate(true) if source_counts_value is Dictionary else {}


static func _make_empty_result(ledger: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"scoring_model": SCORING_MODEL,
		"source": str(ledger.get("source", "unknown")),
		"mode_id": str(ledger.get("mode_id", "")),
		"run_generation": int(ledger.get("run_generation", -1)),
		"shot_id": int(ledger.get("shot_id", -1)),
		"attempt_id": int(ledger.get("attempt_id", -1)),
		"shot_lab_preset_id": str(ledger.get("shot_lab_preset_id", "")),
		"base_haul": 0,
		"haul_additions": [],
		"final_haul": 0,
		"base_mult": BASE_MULT,
		"mult_additions": [],
		"mult_before_xmult": BASE_MULT,
		"xmult_steps": [],
		"xmult_product": 1.0,
		"final_mult": BASE_MULT,
		"resolution_steps": [],
		"shot_score": 0,
		"warnings": [],
		"diagnostics": {},
	}


static func _finalize_safe_zero(result: Dictionary, warnings: Array[String], diagnostics: Dictionary) -> Dictionary:
	diagnostics["input_valid"] = false
	diagnostics["resolution_step_count"] = 0
	result["warnings"] = warnings
	result["diagnostics"] = diagnostics
	return result.duplicate(true)


static func _make_resolution_step(
	step_index: int,
	contribution: Dictionary,
	haul_before: int,
	haul_delta: int,
	haul_after: int,
	mult_before: float,
	mult_delta: float,
	xmult_factor: float,
	mult_after: float,
	metadata: Dictionary
) -> Dictionary:
	return {
		"step_index": step_index,
		"phase": str(contribution.get("phase", "")),
		"source_id": str(contribution.get("source_id", "")),
		"source_type": str(contribution.get("source_type", "")),
		"display_name": str(contribution.get("display_name", "")),
		"event_index": int(contribution.get("event_index", -1)),
		"ball_id": int(contribution.get("ball_id", -1)),
		"haul_before": haul_before,
		"haul_delta": haul_delta,
		"haul_after": haul_after,
		"mult_before": mult_before,
		"mult_delta": mult_delta,
		"xmult_factor": xmult_factor,
		"mult_after": mult_after,
		"score_preview_after": maxi(int(floor(float(maxi(haul_after, 0)) * maxf(mult_after, 0.0))), 0),
		"affects_score": true,
		"metadata": metadata.duplicate(true),
	}


static func _get_sorted_modifiers(modifiers: Array, warnings: Array[String]) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for input_index in range(modifiers.size()):
		var modifier_value: Variant = modifiers[input_index]
		if not modifier_value is Dictionary:
			warnings.append("A scoring modifier is not a Dictionary and was skipped.")
			continue
		var modifier: Dictionary = (modifier_value as Dictionary).duplicate(true)
		modifier["_input_order"] = input_index
		sorted.append(modifier)
	sorted.sort_custom(_modifier_precedes)
	return sorted


static func _modifier_precedes(a: Dictionary, b: Dictionary) -> bool:
	var phase_a: int = int(MODIFIER_PHASE_ORDER.get(str(a.get("phase", "")), 99))
	var phase_b: int = int(MODIFIER_PHASE_ORDER.get(str(b.get("phase", "")), 99))
	if phase_a != phase_b:
		return phase_a < phase_b
	var slot_a: int = int(a.get("slot_index", 0))
	var slot_b: int = int(b.get("slot_index", 0))
	if slot_a != slot_b:
		return slot_a < slot_b
	var event_a: int = int(a.get("trigger_event_index", a.get("event_index", -1)))
	var event_b: int = int(b.get("trigger_event_index", b.get("event_index", -1)))
	if event_a != event_b:
		return event_a < event_b
	var occurrence_a: String = str(a.get("trigger_occurrence_id", ""))
	var occurrence_b: String = str(b.get("trigger_occurrence_id", ""))
	if occurrence_a != occurrence_b:
		return occurrence_a < occurrence_b
	var retrigger_a: int = int(a.get("retrigger_index", 0))
	var retrigger_b: int = int(b.get("retrigger_index", 0))
	if retrigger_a != retrigger_b:
		return retrigger_a < retrigger_b
	var id_a: String = str(a.get("modifier_id", ""))
	var id_b: String = str(b.get("modifier_id", ""))
	if id_a != id_b:
		return id_a < id_b
	return int(a.get("_input_order", 0)) < int(b.get("_input_order", 0))


static func _make_modifier_step_metadata(modifier: Dictionary, phase: String) -> Dictionary:
	var metadata: Dictionary = {}
	var metadata_value: Variant = modifier.get("metadata", {})
	if metadata_value is Dictionary:
		metadata = (metadata_value as Dictionary).duplicate(true)
	metadata.merge({
		"modifier_phase": phase,
		"slot_index": int(modifier.get("slot_index", 0)),
		"eight_ball_item_id": str(modifier.get("eight_ball_item_id", "")),
		"trigger_id": str(modifier.get("trigger_id", "")),
		"trigger_occurrence_id": str(modifier.get("trigger_occurrence_id", "")),
		"trigger_ball_id": int(modifier.get("trigger_ball_id", -1)),
		"trigger_event_index": int(modifier.get("trigger_event_index", -1)),
		"rarity": str(modifier.get("rarity", "")),
		"short_effect": str(modifier.get("short_effect", "")),
		"activation_id": str(modifier.get("activation_id", "")),
		"activation_ordinal": int(modifier.get("activation_ordinal", 0)),
		"is_retrigger": bool(modifier.get("is_retrigger", false)),
		"retrigger_index": int(modifier.get("retrigger_index", 0)),
		"retrigger_source_item_id": str(modifier.get("retrigger_source_item_id", "")),
		"retrigger_source_display_name": str(modifier.get(
			"retrigger_source_display_name",
			""
		)),
		"retrigger_source_slot_index": int(modifier.get(
			"retrigger_source_slot_index",
			-1
		)),
		"original_activation_id": str(modifier.get("original_activation_id", "")),
		"retrigger_marker_required": bool(modifier.get(
			"retrigger_marker_required",
			false
		)),
	}, true)
	return metadata


static func _pocket_fact_precedes(a: Dictionary, b: Dictionary) -> bool:
	var event_a: int = int(a.get("pocket_event_index", -1))
	var event_b: int = int(b.get("pocket_event_index", -1))
	if event_a != event_b:
		return event_a < event_b
	var order_a: int = int(a.get("pocket_order", 0))
	var order_b: int = int(b.get("pocket_order", 0))
	if order_a != order_b:
		return order_a < order_b
	return int(a.get("ball_id", -1)) < int(b.get("ball_id", -1))


static func _rail_display_name(capped_count: int) -> String:
	if capped_count == 1:
		return "Rail"
	if capped_count == 2:
		return "Double Bank"
	return "Triple Bank"


static func _cue_recontact_display_name(cue_strike_ordinal: int) -> String:
	if cue_strike_ordinal == 2:
		return "Double Tap"
	if cue_strike_ordinal == 3:
		return "Triple Tap"
	return "Tap x%d" % maxi(cue_strike_ordinal, 4)


static func _cue_recontact_display_tier(cue_strike_ordinal: int) -> String:
	if cue_strike_ordinal == 2:
		return "double_tap"
	if cue_strike_ordinal == 3:
		return "triple_tap"
	return "tap_x%d" % maxi(cue_strike_ordinal, 4)


static func _object_ball_tap_display_name(unique_contact_ordinal: int) -> String:
	if unique_contact_ordinal <= 1:
		return "Ball Tap"
	return "Ball Tap x%d" % unique_contact_ordinal


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


static func _get_milestone_position(milestone: Dictionary) -> Dictionary:
	var position_value: Variant = milestone.get("world_position", null)
	if not position_value is Vector2:
		return {"available": false, "position": Vector2.ZERO}
	var position: Vector2 = position_value as Vector2
	if not is_finite(position.x) or not is_finite(position.y):
		return {"available": false, "position": Vector2.ZERO}
	return {"available": true, "position": position}


static func _make_legacy_cue_recontact_milestones(fact: Dictionary) -> Array[Dictionary]:
	var milestones: Array[Dictionary] = []
	var event_indices: Array = _array_value(fact, "cue_recontact_event_indices")
	var positions: Array = _array_value(fact, "cue_recontact_positions")
	var ball_id: int = int(fact.get("ball_id", -1))
	for milestone_index in range(event_indices.size()):
		var event_index: int = int(event_indices[milestone_index])
		var bonus_ordinal: int = milestone_index + 1
		var cue_strike_ordinal: int = bonus_ordinal + 1
		var position_result: Dictionary = _get_aligned_position(positions, milestone_index)
		milestones.append({
			"trigger_occurrence_id": "cue_recontact_milestone:%d:%d:%d" % [
				ball_id,
				event_index,
				cue_strike_ordinal,
			],
			"trigger_id": "cue_recontact_milestone",
			"ball_id": ball_id,
			"event_index": event_index,
			"world_position": position_result.get("position", Vector2.ZERO),
			"cue_strike_ordinal": cue_strike_ordinal,
			"bonus_ordinal": bonus_ordinal,
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
		var unique_contact_ordinal: int = milestone_index + 1
		var position_result: Dictionary = _get_aligned_position(positions, milestone_index)
		milestones.append({
			"trigger_occurrence_id": "object_ball_tap_milestone:%d:%d:%d" % [
				ball_id,
				contacted_ball_id,
				event_index,
			],
			"trigger_id": "object_ball_tap_milestone",
			"ball_id": ball_id,
			"contacted_ball_id": contacted_ball_id,
			"event_index": event_index,
			"world_position": position_result.get("position", Vector2.ZERO),
			"unique_contact_ordinal": unique_contact_ordinal,
			"metadata": {
				"unique_target_count": target_ball_ids.size(),
				"repeated_target_contact": false,
			},
		})
	return milestones


static func _get_aligned_position(positions: Array, position_index: int) -> Dictionary:
	if position_index < 0 or position_index >= positions.size():
		return {"available": false, "position": Vector2.ZERO}
	var position_value: Variant = positions[position_index]
	if not position_value is Vector2:
		return {"available": false, "position": Vector2.ZERO}
	var position: Vector2 = position_value as Vector2
	if not is_finite(position.x) or not is_finite(position.y):
		return {"available": false, "position": Vector2.ZERO}
	return {"available": true, "position": position}


static func _increment_source_count(diagnostics: Dictionary, source_id: String) -> void:
	var counts_value: Variant = diagnostics.get("source_counts", {})
	var counts: Dictionary = counts_value as Dictionary if counts_value is Dictionary else {}
	counts[source_id] = int(counts.get(source_id, 0)) + 1
	diagnostics["source_counts"] = counts


static func _is_finite_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _is_integer_number(value: Variant) -> bool:
	if not _is_finite_number(value):
		return false
	return is_equal_approx(float(value), float(int(value)))


static func _is_nonnegative_integer(value: Variant) -> bool:
	return _is_integer_number(value) and int(value) >= 0


static func _is_positive_integer(value: Variant) -> bool:
	return _is_integer_number(value) and int(value) > 0


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


static func _test_ledger(facts: Array, scratch: bool = false) -> Dictionary:
	var object_ids: Array[int] = []
	var cue_recontact_milestones: Array[Dictionary] = []
	var object_ball_tap_milestones: Array[Dictionary] = []
	for fact_value in facts:
		if fact_value is Dictionary:
			var fact: Dictionary = fact_value as Dictionary
			object_ids.append(int(fact.get("ball_id", -1)))
			for milestone in _array_value(fact, "cue_recontact_milestones"):
				if milestone is Dictionary:
					cue_recontact_milestones.append(
						(milestone as Dictionary).duplicate(true)
					)
			for milestone in _array_value(fact, "object_ball_tap_milestones"):
				if milestone is Dictionary:
					object_ball_tap_milestones.append(
						(milestone as Dictionary).duplicate(true)
					)
	return {
		"schema_version": SUPPORTED_LEDGER_SCHEMA_VERSIONS[0],
		"source": "synthetic_self_test",
		"mode_id": "shot_lab",
		"shot_id": 1,
		"attempt_id": 1,
		"cue_ball_id": 1,
		"derived": {
			"schema_version": SUPPORTED_ANALYZED_SCHEMA_VERSION,
			"object_ball_pocket_count": facts.size(),
			"object_balls_pocketed": object_ids,
			"pocket_facts": facts.duplicate(true),
			"cue_recontact_milestones": cue_recontact_milestones,
			"cue_recontact_milestone_count": cue_recontact_milestones.size(),
			"object_ball_tap_milestones": object_ball_tap_milestones,
			"object_ball_tap_milestone_count": object_ball_tap_milestones.size(),
			"scratch_occurred": scratch,
			"cue_ball_pocket_event_index": 99 if scratch else -1,
		},
	}


static func _test_fact(ball_id: int, pocket_order: int, bank_count: int, combination: bool) -> Dictionary:
	return {
		"ball_id": ball_id,
		"ball_number": ball_id,
		"pocket_order": pocket_order,
		"pocket_event_index": pocket_order * 10,
		"pocket_index": 0,
		"causal_depth": 2 if combination else 1,
		"bank_count": bank_count,
		"is_combination_pot": combination,
		"qualifying_cue_strike_count": 1,
		"cue_recontact_bonus_count": 0,
		"cue_recontact_event_indices": [],
		"cue_recontact_positions": [],
		"cue_recontact_milestones": [],
		"unique_object_tap_count": 0,
		"unique_object_tap_ball_ids": [],
		"object_tap_event_indices": [],
		"object_tap_positions": [],
		"object_ball_tap_milestones": [],
		"repeated_object_tap_contact_count": 0,
	}


static func _test_tap_fact(
	ball_id: int,
	pocket_order: int,
	bank_count: int,
	combination: bool,
	cue_recontact_event_indices: Array,
	object_tap_ball_ids: Array,
	object_tap_event_indices: Array,
	repeated_object_tap_contact_count: int
) -> Dictionary:
	var fact: Dictionary = _test_fact(ball_id, pocket_order, bank_count, combination)
	fact["qualifying_cue_strike_count"] = cue_recontact_event_indices.size() + 1
	fact["cue_recontact_bonus_count"] = cue_recontact_event_indices.size()
	fact["cue_recontact_event_indices"] = cue_recontact_event_indices.duplicate()
	var cue_positions: Array[Vector2] = []
	var cue_milestones: Array[Dictionary] = []
	for cue_index in range(cue_recontact_event_indices.size()):
		var event_index: int = int(cue_recontact_event_indices[cue_index])
		var world_position := Vector2(float(event_index), float(ball_id))
		cue_positions.append(world_position)
		cue_milestones.append({
			"trigger_occurrence_id": "cue_recontact_milestone:%d:%d:%d" % [
				ball_id,
				event_index,
				cue_index + 2,
			],
			"trigger_id": "cue_recontact_milestone",
			"ball_id": ball_id,
			"ball_number": ball_id,
			"event_index": event_index,
			"world_position": world_position,
			"cue_strike_ordinal": cue_index + 2,
			"bonus_ordinal": cue_index + 1,
			"metadata": {
				"qualifying_cue_strike_count": cue_recontact_event_indices.size() + 1,
				"self_test_marker": "derived_cue_milestone",
			},
		})
	fact["cue_recontact_positions"] = cue_positions
	fact["cue_recontact_milestones"] = cue_milestones
	fact["unique_object_tap_count"] = object_tap_ball_ids.size()
	fact["unique_object_tap_ball_ids"] = object_tap_ball_ids.duplicate()
	fact["object_tap_event_indices"] = object_tap_event_indices.duplicate()
	var tap_positions: Array[Vector2] = []
	var object_tap_milestones: Array[Dictionary] = []
	for tap_index in range(object_tap_event_indices.size()):
		var event_index: int = int(object_tap_event_indices[tap_index])
		var world_position := Vector2(float(event_index), float(ball_id))
		tap_positions.append(world_position)
		var contacted_ball_id: int = int(object_tap_ball_ids[tap_index])
		object_tap_milestones.append({
			"trigger_occurrence_id": "object_ball_tap_milestone:%d:%d:%d" % [
				ball_id,
				contacted_ball_id,
				event_index,
			],
			"trigger_id": "object_ball_tap_milestone",
			"ball_id": ball_id,
			"ball_number": ball_id,
			"contacted_ball_id": contacted_ball_id,
			"event_index": event_index,
			"world_position": world_position,
			"unique_contact_ordinal": tap_index + 1,
			"metadata": {
				"unique_target_count": object_tap_ball_ids.size(),
				"repeated_target_contact": false,
				"self_test_marker": "derived_object_tap_milestone",
			},
		})
	fact["object_tap_positions"] = tap_positions
	fact["object_ball_tap_milestones"] = object_tap_milestones
	fact["repeated_object_tap_contact_count"] = repeated_object_tap_contact_count
	return fact


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


static func _run_score_case(
	cases: Array[Dictionary],
	name: String,
	ledger: Dictionary,
	modifiers: Array,
	expected: Dictionary
) -> void:
	var actual_result: Dictionary = resolve(ledger, modifiers)
	var failures: Array[Dictionary] = []
	for path_value in expected.keys():
		var path: String = str(path_value)
		var expected_value: Variant = expected[path_value]
		var actual_value: Variant
		if path == "modifier_order":
			actual_value = _modifier_source_order(actual_result)
		elif path.begins_with("source_counts."):
			actual_value = int(get_resolution_source_counts(actual_result).get(path.trim_prefix("source_counts."), 0))
		elif path.begins_with("diagnostics."):
			actual_value = _dictionary_value(actual_result, "diagnostics").get(path.trim_prefix("diagnostics."), null)
		else:
			actual_value = actual_result.get(path, null)
		var matches: bool = (
			is_equal_approx(float(actual_value), float(expected_value))
			if typeof(actual_value) in [TYPE_INT, TYPE_FLOAT] and typeof(expected_value) in [TYPE_INT, TYPE_FLOAT]
			else actual_value == expected_value
		)
		if not matches:
			failures.append({"path": path, "expected": expected_value, "actual": actual_value})
	cases.append(_make_test_case(name, failures.is_empty(), expected, {
		"shot_score": actual_result.get("shot_score", null),
		"final_haul": actual_result.get("final_haul", null),
		"final_mult": actual_result.get("final_mult", null),
		"failures": failures,
	}))


static func _modifier_source_order(score_result: Dictionary) -> Array[String]:
	var order: Array[String] = []
	for step_value in _array_value(score_result, "resolution_steps"):
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value as Dictionary
		if str(step.get("source_type", "")) == "modifier":
			order.append(str(step.get("source_id", "")))
	return order


static func _score_results_equal(a: Dictionary, b: Dictionary) -> bool:
	for key in ["base_haul", "final_haul", "base_mult", "mult_before_xmult", "xmult_product", "final_mult", "shot_score"]:
		if not is_equal_approx(float(a.get(key, -1.0)), float(b.get(key, -2.0))):
			return false
	return get_resolution_source_counts(a) == get_resolution_source_counts(b)


static func _make_test_case(name: String, passed: bool, expected: Dictionary, actual: Dictionary) -> Dictionary:
	return {
		"name": name,
		"passed": passed,
		"expected": expected.duplicate(true),
		"actual": actual.duplicate(true),
	}


static func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func _dictionary_at(values: Array, index: int) -> Dictionary:
	if index < 0 or index >= values.size():
		return {}
	var value: Variant = values[index]
	return value as Dictionary if value is Dictionary else {}


static func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []
