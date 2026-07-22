extends RefCounted
class_name RogueliteBuildEffectEvaluator

# Pure build-effect expansion for analyzed Long Sink shots. This evaluator owns
# no run state: prediction and authority both operate on copied value snapshots.

const CATALOG := preload("res://scripts/RogueliteEightBallCatalog.gd")

const SOURCE_PREDICTED := "predicted"
const SOURCE_AUTHORITATIVE := "authoritative"

const EFFECT_NUMERIC := "numeric_modifier"
const EFFECT_LEGACY_NUMERIC := "modifier"
const EFFECT_PERSISTENT_SCALER := "persistent_scaler"
const EFFECT_CROSS_FAMILY := "cross_family_conditional"
const EFFECT_SHOT_ORDINAL := "shot_ordinal_multiplier"
const EFFECT_THRESHOLD_RETRIGGER := "threshold_family_retrigger"
const EFFECT_RETRIGGER_FAMILY := "retrigger_family"

const TRIGGER_CUE_RECONTACT := "cue_recontact_milestone"
const TRIGGER_OBJECT_BALL_TAP := "object_ball_tap_milestone"
const TAP_TRIGGER_IDS: Array[String] = [
	TRIGGER_CUE_RECONTACT,
	TRIGGER_OBJECT_BALL_TAP,
]

const PHASE_ADD_HAUL := "add_haul"
const PHASE_ADD_MULT := "add_mult"
const PHASE_XMULT := "xmult"
const PHASE_ORDER := {
	PHASE_ADD_HAUL: 0,
	PHASE_ADD_MULT: 1,
	PHASE_XMULT: 2,
}


static func evaluate(
	analyzed_ledger: Dictionary,
	trigger_occurrences: Array[Dictionary],
	build_snapshot: Dictionary,
	source: String,
	excluded_item_id: String = ""
) -> Dictionary:
	var started_at_usec: int = Time.get_ticks_usec()
	var slots: Array[Dictionary] = _normalized_slots(build_snapshot, excluded_item_id)
	var ordered_occurrences: Array[Dictionary] = trigger_occurrences.duplicate(true)
	ordered_occurrences.sort_custom(_occurrence_precedes)
	var tap_occurrences: Array[Dictionary] = _tap_occurrences(ordered_occurrences)
	var modifier_context: Array[Dictionary] = []
	var engine_events: Array[Dictionary] = []
	var state_before: Dictionary = _state_snapshot(slots)
	var simulated_state_after: Dictionary = state_before.duplicate(true)
	var authoritative_mutations: Array[Dictionary] = []
	var warnings: Array[String] = []
	var regular_activations_by_occurrence_and_family: Dictionary = {}
	var modifier_activations_before_retriggers: int = 0
	var rattle_growth_count: int = 0
	var one_two_qualifying_balls: Array[int] = []
	var aftershock_activation_count: int = 0
	var echo_threshold_count: int = 0
	var echo_retrigger_count: int = 0
	var maximum_retrigger_depth: int = 0

	# Original numeric effects are expanded first. Retrigger effects only clone
	# these originals, which makes recursive activation graphs impossible.
	for slot in slots:
		var definition: Dictionary = _slot_definition(slot)
		var effect_kind: String = str(definition.get("effect_kind", EFFECT_LEGACY_NUMERIC))
		match effect_kind:
			EFFECT_NUMERIC, EFFECT_LEGACY_NUMERIC:
				var trigger_id: String = str(definition.get("trigger_id", ""))
				for occurrence in ordered_occurrences:
					if str(occurrence.get("trigger_id", "")) != trigger_id:
						continue
					var activation: Dictionary = _make_modifier_activation(
						definition,
						occurrence,
						slot,
						false
					)
					modifier_context.append(activation)
					modifier_activations_before_retriggers += 1
					var family_id: String = str(definition.get("family_id", ""))
					var lookup_key: String = _activation_lookup_key(
						str(occurrence.get("trigger_occurrence_id", "")),
						family_id
					)
					if not regular_activations_by_occurrence_and_family.has(lookup_key):
						regular_activations_by_occurrence_and_family[lookup_key] = []
					var grouped: Array = regular_activations_by_occurrence_and_family[lookup_key]
					grouped.append(activation.duplicate(true))
					regular_activations_by_occurrence_and_family[lookup_key] = grouped
			EFFECT_PERSISTENT_SCALER:
				var scaler_result: Dictionary = _evaluate_persistent_scaler(
					definition,
					slot,
					tap_occurrences,
					source
				)
				modifier_context.append_array(_array_value(scaler_result, "modifier_context"))
				engine_events.append_array(_array_value(scaler_result, "engine_events"))
				var instance_key: String = str(slot.get("owned_item_instance_id", 0))
				var state_after: Dictionary = _dictionary_value(scaler_result, "state_after")
				if not state_after.is_empty():
					simulated_state_after[instance_key] = state_after.duplicate(true)
				var mutation: Dictionary = _dictionary_value(scaler_result, "mutation")
				if source == SOURCE_AUTHORITATIVE and not mutation.is_empty():
					authoritative_mutations.append(mutation.duplicate(true))
				rattle_growth_count += int(scaler_result.get("growth_count", 0))
			EFFECT_CROSS_FAMILY:
				var cross_result: Dictionary = _evaluate_cross_family(
					definition,
					slot,
					tap_occurrences
				)
				modifier_context.append_array(_array_value(cross_result, "modifier_context"))
				engine_events.append_array(_array_value(cross_result, "engine_events"))
				one_two_qualifying_balls.append_array(_int_array_value(
					cross_result,
					"qualifying_ball_ids"
				))
			EFFECT_SHOT_ORDINAL:
				var ordinal_result: Dictionary = _evaluate_shot_ordinal(
					definition,
					slot,
					tap_occurrences
				)
				modifier_context.append_array(_array_value(ordinal_result, "modifier_context"))
				engine_events.append_array(_array_value(ordinal_result, "engine_events"))
				aftershock_activation_count += int(ordinal_result.get("activation_count", 0))
			_:
				pass

	# Existing family retriggers (Dead Reckoning) are retained and isolated from
	# Tap families. Only original regular numeric activations are eligible.
	for slot in slots:
		var definition: Dictionary = _slot_definition(slot)
		if str(definition.get("effect_kind", "")) != EFFECT_RETRIGGER_FAMILY:
			continue
		var target_family: String = str(definition.get(
			"retrigger_family",
			definition.get("retrigger_family_id", "")
		))
		var source_trigger: String = str(definition.get("trigger_id", ""))
		var retrigger_count: int = maxi(int(definition.get("retrigger_count", 1)), 0)
		for occurrence in ordered_occurrences:
			if str(occurrence.get("trigger_id", "")) != source_trigger:
				continue
			var key: String = _activation_lookup_key(
				str(occurrence.get("trigger_occurrence_id", "")),
				target_family
			)
			for original_value in _array_variant(regular_activations_by_occurrence_and_family, key):
				if not original_value is Dictionary:
					continue
				for retrigger_index in range(1, retrigger_count + 1):
					modifier_context.append(_make_retrigger_activation(
						original_value as Dictionary,
						definition,
						slot,
						retrigger_index,
						0
					))
					maximum_retrigger_depth = 1

	# Threshold retriggers count all trusted Tap occurrences chronologically, but
	# clone only regular numeric items matching the threshold occurrence family.
	for slot in slots:
		var definition: Dictionary = _slot_definition(slot)
		if str(definition.get("effect_kind", "")) != EFFECT_THRESHOLD_RETRIGGER:
			continue
		var threshold: int = maxi(int(definition.get("threshold", 3)), 1)
		for tap_index in range(tap_occurrences.size()):
			var tap_ordinal: int = tap_index + 1
			if tap_ordinal % threshold != 0:
				continue
			echo_threshold_count += 1
			var occurrence: Dictionary = tap_occurrences[tap_index]
			var target_family: String = (
				"double_tap"
				if str(occurrence.get("trigger_id", "")) == TRIGGER_CUE_RECONTACT
				else "ball_tap"
			)
			engine_events.append(_make_engine_event(
				definition,
				slot,
				occurrence,
				"threshold_retrigger",
				{
					"tap_ordinal": tap_ordinal,
					"threshold": threshold,
					"target_family": target_family,
					"label": _ordinal_label(tap_ordinal) + " TAP - RETRIGGER",
				}
			))
			var key: String = _activation_lookup_key(
				str(occurrence.get("trigger_occurrence_id", "")),
				target_family
			)
			for original_value in _array_variant(regular_activations_by_occurrence_and_family, key):
				if not original_value is Dictionary:
					continue
				modifier_context.append(_make_retrigger_activation(
					original_value as Dictionary,
					definition,
					slot,
					1,
					tap_ordinal
				))
				echo_retrigger_count += 1
				maximum_retrigger_depth = 1

	modifier_context.sort_custom(_modifier_precedes)
	_finalize_activation_metadata(modifier_context)
	engine_events.sort_custom(_engine_event_precedes)
	var trigger_counts: Dictionary = _count_triggers(ordered_occurrences)
	var activation_counts: Dictionary = _count_activations_by_slot(modifier_context, engine_events)
	var duration_usec: int = maxi(Time.get_ticks_usec() - started_at_usec, 0)
	return {
		"source": source,
		"analyzed_ledger_identity": _ledger_identity(analyzed_ledger),
		"build_generation": int(build_snapshot.get("build_generation", 0)),
		"build_version": int(build_snapshot.get("build_version", 0)),
		"trigger_occurrences": ordered_occurrences.duplicate(true),
		"trigger_occurrence_count": ordered_occurrences.size(),
		"trigger_count_by_id": trigger_counts,
		"tap_milestone_count": tap_occurrences.size(),
		"modifier_context": modifier_context.duplicate(true),
		"engine_events": engine_events.duplicate(true),
		"state_before": state_before.duplicate(true),
		"simulated_state_after": simulated_state_after.duplicate(true),
		"authoritative_state_mutations": authoritative_mutations.duplicate(true),
		"warnings": warnings.duplicate(),
		"activation_count_by_tray_slot": activation_counts,
		"modifier_activation_count": modifier_context.size(),
		"modifier_activations_before_retriggers": modifier_activations_before_retriggers,
		"modifier_activations_after_retriggers": modifier_context.size(),
		"state_mutation_count": authoritative_mutations.size(),
		"rattle_growth_trigger_count": rattle_growth_count,
		"one_two_punch_qualifying_ball_ids": one_two_qualifying_balls.duplicate(),
		"aftershock_activation_count": aftershock_activation_count,
		"echo_threshold_count": echo_threshold_count,
		"echo_retrigger_activation_count": echo_retrigger_count,
		"maximum_retrigger_depth": maximum_retrigger_depth,
		"evaluation_duration_usec": duration_usec,
		"diagnostics": {
			"tap_milestone_count": tap_occurrences.size(),
			"rattle_growth_trigger_count": rattle_growth_count,
			"one_two_punch_qualifying_ball_count": one_two_qualifying_balls.size(),
			"aftershock_activation_count": aftershock_activation_count,
			"echo_threshold_count": echo_threshold_count,
			"echo_retrigger_activation_count": echo_retrigger_count,
			"state_mutation_count": authoritative_mutations.size(),
			"maximum_retrigger_depth": maximum_retrigger_depth,
			"evaluation_duration_usec": duration_usec,
		},
	}


static func _evaluate_persistent_scaler(
	definition: Dictionary,
	slot: Dictionary,
	tap_occurrences: Array[Dictionary],
	source: String
) -> Dictionary:
	var state_before: Dictionary = _slot_state(slot, definition)
	var state_after: Dictionary = state_before.duplicate(true)
	var current_value: float = float(state_before.get(
		"current_xmult",
		definition.get("starting_value", 1.0)
	))
	var growth_per_trigger: float = float(definition.get("growth_per_trigger", 0.0))
	var engine_events: Array[Dictionary] = []
	for occurrence in tap_occurrences:
		var value_before: float = current_value
		# Persistent decimal growth must not drift just below an authored value;
		# the resolver intentionally floors the final score.
		current_value = (
			roundf((current_value + growth_per_trigger) * 1000000.0)
			/ 1000000.0
		)
		engine_events.append(_make_engine_event(
			definition,
			slot,
			occurrence,
			"state_growth",
			{
				"value_before": value_before,
				"value_after": current_value,
				"growth_amount": growth_per_trigger,
				"source": source,
				"label": "x%.1f -> x%.1f" % [value_before, current_value],
			}
		))
	state_after["state_version"] = maxi(int(definition.get("state_schema_version", 1)), 1)
	state_after["current_xmult"] = current_value
	state_after["lifetime_growth_triggers"] = maxi(int(
		state_before.get("lifetime_growth_triggers", 0)
	), 0) + tap_occurrences.size()
	state_after["shots_activated"] = maxi(int(state_before.get("shots_activated", 0)), 0)
	var modifiers: Array[Dictionary] = []
	if not tap_occurrences.is_empty():
		state_after["shots_activated"] = int(state_after["shots_activated"]) + 1
		var final_occurrence: Dictionary = tap_occurrences[tap_occurrences.size() - 1]
		var activation: Dictionary = _make_custom_modifier_activation(
			definition,
			final_occurrence,
			slot,
			str(definition.get("application_phase", PHASE_XMULT)),
			current_value,
			"persistent_scaler"
		)
		activation["metadata"]["post_growth_value"] = current_value
		activation["metadata"]["tap_milestone_count"] = tap_occurrences.size()
		modifiers.append(activation)
		engine_events.append(_make_engine_event(
			definition,
			slot,
			final_occurrence,
			"stateful_modifier",
			{
				"value": current_value,
				"phase": str(definition.get("application_phase", PHASE_XMULT)),
				"label": "x%.1f MULT" % current_value,
			}
		))
	var mutation: Dictionary = {}
	if state_after != state_before:
		mutation = {
			"mutation_kind": "replace_owned_item_state",
			"owned_item_instance_id": int(slot.get("owned_item_instance_id", 0)),
			"eight_ball_item_id": str(definition.get("eight_ball_item_id", "")),
			"tray_slot_index": int(slot.get("tray_slot_index", slot.get("slot_index", -1))),
			"state_before": state_before.duplicate(true),
			"state_after": state_after.duplicate(true),
			"source": source,
		}
	return {
		"modifier_context": modifiers,
		"engine_events": engine_events,
		"state_after": state_after,
		"mutation": mutation,
		"growth_count": tap_occurrences.size(),
	}


static func _evaluate_cross_family(
	definition: Dictionary,
	slot: Dictionary,
	tap_occurrences: Array[Dictionary]
) -> Dictionary:
	var by_ball: Dictionary = {}
	for occurrence in tap_occurrences:
		var ball_id: int = int(occurrence.get("trigger_ball_id", occurrence.get("ball_id", -1)))
		if ball_id <= 0:
			continue
		var key: String = str(ball_id)
		var group: Dictionary = _dictionary_value(by_ball, key).duplicate(true)
		if group.is_empty():
			group = {"ball_id": ball_id, "cue": [], "object": []}
		var bucket_key: String = (
			"cue"
			if str(occurrence.get("trigger_id", "")) == TRIGGER_CUE_RECONTACT
			else "object"
		)
		var bucket: Array = group[bucket_key]
		bucket.append(occurrence.duplicate(true))
		group[bucket_key] = bucket
		by_ball[key] = group
	var qualifying_ids: Array[int] = []
	var modifiers: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	var sorted_ball_ids: Array[int] = []
	for key_value in by_ball.keys():
		sorted_ball_ids.append(int(key_value))
	sorted_ball_ids.sort()
	for ball_id in sorted_ball_ids:
		var group: Dictionary = _dictionary_value(by_ball, str(ball_id))
		var cue: Array = _array_value(group, "cue")
		var object_taps: Array = _array_value(group, "object")
		if cue.is_empty() or object_taps.is_empty():
			continue
		qualifying_ids.append(ball_id)
		var anchor: Dictionary = _later_occurrence(cue[0] as Dictionary, object_taps[0] as Dictionary)
		var activation: Dictionary = _make_custom_modifier_activation(
			definition,
			anchor,
			slot,
			str(definition.get("modifier_phase", PHASE_XMULT)),
			float(definition.get("value", 1.0)),
			"cross_family_conditional"
		)
		activation["trigger_ball_id"] = ball_id
		activation["metadata"]["qualifying_ball_id"] = ball_id
		activation["metadata"]["cue_recontact_count"] = cue.size()
		activation["metadata"]["object_ball_tap_count"] = object_taps.size()
		modifiers.append(activation)
		events.append(_make_engine_event(
			definition,
			slot,
			anchor,
			"cross_family_activation",
			{"ball_id": ball_id, "value": float(definition.get("value", 1.0))}
		))
	return {
		"modifier_context": modifiers,
		"engine_events": events,
		"qualifying_ball_ids": qualifying_ids,
	}


static func _evaluate_shot_ordinal(
	definition: Dictionary,
	slot: Dictionary,
	tap_occurrences: Array[Dictionary]
) -> Dictionary:
	var modifiers: Array[Dictionary] = []
	var events: Array[Dictionary] = []
	for tap_index in range(1, tap_occurrences.size()):
		var tap_ordinal: int = tap_index + 1
		var occurrence: Dictionary = tap_occurrences[tap_index]
		var activation: Dictionary = _make_custom_modifier_activation(
			definition,
			occurrence,
			slot,
			str(definition.get("modifier_phase", PHASE_XMULT)),
			float(definition.get("value", 1.0)),
			"shot_ordinal_multiplier"
		)
		activation["metadata"]["tap_ordinal"] = tap_ordinal
		modifiers.append(activation)
		events.append(_make_engine_event(
			definition,
			slot,
			occurrence,
			"ordinal_activation",
			{"tap_ordinal": tap_ordinal, "value": float(definition.get("value", 1.0))}
		))
	return {
		"modifier_context": modifiers,
		"engine_events": events,
		"activation_count": modifiers.size(),
	}


static func _make_modifier_activation(
	definition: Dictionary,
	occurrence: Dictionary,
	slot: Dictionary,
	is_retrigger: bool
) -> Dictionary:
	return _make_custom_modifier_activation(
		definition,
		occurrence,
		slot,
		str(definition.get("modifier_phase", definition.get("phase", ""))),
		definition.get("value", 0),
		"numeric_modifier",
		is_retrigger
	)


static func _make_custom_modifier_activation(
	definition: Dictionary,
	occurrence: Dictionary,
	slot: Dictionary,
	phase: String,
	value: Variant,
	effect_kind: String,
	is_retrigger: bool = false
) -> Dictionary:
	var item_id: String = str(definition.get("eight_ball_item_id", ""))
	var occurrence_id: String = str(occurrence.get("trigger_occurrence_id", ""))
	var slot_index: int = int(slot.get("tray_slot_index", slot.get("slot_index", -1)))
	var instance_id: int = int(slot.get("owned_item_instance_id", 0))
	var activation_id: String = "%s|instance:%d|slot:%d|occurrence:%s" % [
		item_id,
		instance_id,
		slot_index,
		occurrence_id,
	]
	var metadata: Dictionary = {
		"effect_kind": effect_kind,
		"family_id": str(definition.get("family_id", "")),
		"offer_family_id": str(definition.get(
			"offer_family_id",
			definition.get("offer_family", definition.get("family_id", ""))
		)),
		"owned_item_instance_id": instance_id,
		"tray_slot_index": slot_index,
		"trigger_id": str(occurrence.get("trigger_id", "")),
		"trigger_occurrence_id": occurrence_id,
		"trigger_ball_id": int(occurrence.get("trigger_ball_id", occurrence.get("ball_id", -1))),
		"trigger_event_index": int(occurrence.get("trigger_event_index", occurrence.get("event_index", -1))),
		"is_retrigger": is_retrigger,
		"retrigger_index": 0,
		"retrigger_depth": 0,
	}
	return {
		"modifier_id": activation_id,
		"activation_id": activation_id,
		"eight_ball_item_id": item_id,
		"owned_item_instance_id": instance_id,
		"display_name": str(definition.get("display_name", item_id)),
		"phase": phase,
		"value": value,
		"slot_index": slot_index,
		"tray_slot_index": slot_index,
		"trigger_id": str(occurrence.get("trigger_id", "")),
		"trigger_occurrence_id": occurrence_id,
		"trigger_ball_id": int(occurrence.get("trigger_ball_id", occurrence.get("ball_id", -1))),
		"trigger_event_index": int(occurrence.get("trigger_event_index", occurrence.get("event_index", -1))),
		"event_index": int(occurrence.get("trigger_event_index", occurrence.get("event_index", -1))),
		"rarity": str(definition.get("rarity", "")),
		"short_effect": str(definition.get("short_effect", "")),
		"enabled": true,
		"is_retrigger": is_retrigger,
		"retrigger_index": 0,
		"metadata": metadata,
	}


static func _make_retrigger_activation(
	original: Dictionary,
	source_definition: Dictionary,
	source_slot: Dictionary,
	retrigger_index: int,
	threshold_ordinal: int
) -> Dictionary:
	var activation: Dictionary = original.duplicate(true)
	var original_id: String = str(original.get("activation_id", original.get("modifier_id", "")))
	var source_item_id: String = str(source_definition.get("eight_ball_item_id", ""))
	activation["modifier_id"] = "%s|retrigger:%d|source:%s|threshold:%d" % [
		original_id,
		retrigger_index,
		source_item_id,
		threshold_ordinal,
	]
	activation["activation_id"] = activation["modifier_id"]
	activation["is_retrigger"] = true
	activation["retrigger_index"] = retrigger_index
	activation["retrigger_source_item_id"] = source_item_id
	activation["retrigger_source_display_name"] = str(source_definition.get(
		"display_name",
		source_item_id
	))
	activation["retrigger_source_slot_index"] = int(source_slot.get(
		"tray_slot_index",
		source_slot.get("slot_index", -1)
	))
	activation["retrigger_threshold_ordinal"] = threshold_ordinal
	activation["original_activation_id"] = original_id
	activation["retrigger_marker_required"] = false
	var metadata: Dictionary = _dictionary_value(activation, "metadata").duplicate(true)
	metadata.merge({
		"is_retrigger": true,
		"retrigger_index": retrigger_index,
		"retrigger_depth": 1,
		"retrigger_source_item_id": source_item_id,
		"retrigger_source_display_name": activation["retrigger_source_display_name"],
		"retrigger_source_slot_index": activation["retrigger_source_slot_index"],
		"retrigger_threshold_ordinal": threshold_ordinal,
		"original_activation_id": original_id,
		"owned_item_instance_id": int(original.get("owned_item_instance_id", 0)),
	}, true)
	activation["metadata"] = metadata
	return activation


static func _make_engine_event(
	definition: Dictionary,
	slot: Dictionary,
	occurrence: Dictionary,
	event_kind: String,
	extra: Dictionary
) -> Dictionary:
	var event: Dictionary = {
		"engine_event_kind": event_kind,
		"eight_ball_item_id": str(definition.get("eight_ball_item_id", "")),
		"owned_item_instance_id": int(slot.get("owned_item_instance_id", 0)),
		"display_name": str(definition.get("display_name", "")),
		"tray_slot_index": int(slot.get("tray_slot_index", slot.get("slot_index", -1))),
		"rarity": str(definition.get("rarity", "")),
		"trigger_id": str(occurrence.get("trigger_id", "")),
		"trigger_occurrence_id": str(occurrence.get("trigger_occurrence_id", "")),
		"trigger_ball_id": int(occurrence.get("trigger_ball_id", occurrence.get("ball_id", -1))),
		"trigger_event_index": int(occurrence.get("trigger_event_index", occurrence.get("event_index", -1))),
		"affects_score": false,
	}
	event.merge(extra.duplicate(true), true)
	return event


static func _normalized_slots(
	build_snapshot: Dictionary,
	excluded_item_id: String
) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var slots_value: Variant = build_snapshot.get("slots", [])
	if slots_value is Array:
		for slot_value in slots_value:
			if not slot_value is Dictionary:
				continue
			var slot: Dictionary = (slot_value as Dictionary).duplicate(true)
			var item_id: String = str(slot.get("eight_ball_item_id", ""))
			if item_id.is_empty() or item_id == excluded_item_id:
				continue
			if _slot_definition(slot).is_empty():
				continue
			slots.append(slot)
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("tray_slot_index", a.get("slot_index", -1))) < int(
			b.get("tray_slot_index", b.get("slot_index", -1))
		)
	)
	return slots


static func _slot_definition(slot: Dictionary) -> Dictionary:
	var definition: Dictionary = _dictionary_value(slot, "definition")
	if not definition.is_empty():
		return definition.duplicate(true)
	return CATALOG.get_definition(str(slot.get("eight_ball_item_id", "")))


static func _slot_state(slot: Dictionary, definition: Dictionary) -> Dictionary:
	var state: Dictionary = _dictionary_value(slot, "state")
	if not state.is_empty():
		return state.duplicate(true)
	var default_value: Variant = definition.get("initial_state", definition.get("default_state", {}))
	if default_value is Dictionary:
		return (default_value as Dictionary).duplicate(true)
	if str(definition.get("effect_kind", "")) == EFFECT_PERSISTENT_SCALER:
		return {
			"state_version": maxi(int(definition.get("state_schema_version", 1)), 1),
			"current_xmult": float(definition.get("starting_value", 1.0)),
			"lifetime_growth_triggers": 0,
			"shots_activated": 0,
		}
	return {}


static func _state_snapshot(slots: Array[Dictionary]) -> Dictionary:
	var snapshot: Dictionary = {}
	for slot in slots:
		var definition: Dictionary = _slot_definition(slot)
		var state: Dictionary = _slot_state(slot, definition)
		if state.is_empty():
			continue
		snapshot[str(slot.get("owned_item_instance_id", 0))] = state.duplicate(true)
	return snapshot


static func _tap_occurrences(occurrences: Array[Dictionary]) -> Array[Dictionary]:
	var taps: Array[Dictionary] = []
	for occurrence in occurrences:
		if str(occurrence.get("trigger_id", "")) in TAP_TRIGGER_IDS:
			taps.append(occurrence.duplicate(true))
	taps.sort_custom(_occurrence_precedes)
	return taps


static func _occurrence_precedes(a: Dictionary, b: Dictionary) -> bool:
	var event_a: int = int(a.get("trigger_event_index", a.get("event_index", -1)))
	var event_b: int = int(b.get("trigger_event_index", b.get("event_index", -1)))
	if event_a != event_b:
		return event_a < event_b
	return str(a.get("trigger_occurrence_id", "")) < str(b.get("trigger_occurrence_id", ""))


static func _modifier_precedes(a: Dictionary, b: Dictionary) -> bool:
	var phase_a: int = int(PHASE_ORDER.get(str(a.get("phase", "")), 99))
	var phase_b: int = int(PHASE_ORDER.get(str(b.get("phase", "")), 99))
	if phase_a != phase_b:
		return phase_a < phase_b
	var slot_a: int = int(a.get("slot_index", -1))
	var slot_b: int = int(b.get("slot_index", -1))
	if slot_a != slot_b:
		return slot_a < slot_b
	var event_a: int = int(a.get("trigger_event_index", -1))
	var event_b: int = int(b.get("trigger_event_index", -1))
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
	return str(a.get("activation_id", "")) < str(b.get("activation_id", ""))


static func _engine_event_precedes(a: Dictionary, b: Dictionary) -> bool:
	var event_a: int = int(a.get("trigger_event_index", -1))
	var event_b: int = int(b.get("trigger_event_index", -1))
	if event_a != event_b:
		return event_a < event_b
	var slot_a: int = int(a.get("tray_slot_index", -1))
	var slot_b: int = int(b.get("tray_slot_index", -1))
	if slot_a != slot_b:
		return slot_a < slot_b
	return str(a.get("engine_event_kind", "")) < str(b.get("engine_event_kind", ""))


static func _finalize_activation_metadata(context: Array[Dictionary]) -> void:
	var item_ordinals: Dictionary = {}
	var marker_keys: Dictionary = {}
	for activation in context:
		var item_id: String = str(activation.get("eight_ball_item_id", ""))
		var ordinal: int = int(item_ordinals.get(item_id, 0)) + 1
		item_ordinals[item_id] = ordinal
		activation["activation_ordinal"] = ordinal
		var metadata: Dictionary = _dictionary_value(activation, "metadata").duplicate(true)
		metadata["activation_ordinal"] = ordinal
		if bool(activation.get("is_retrigger", false)):
			var marker_key: String = "%s|%s|%d" % [
				str(activation.get("retrigger_source_item_id", "")),
				str(activation.get("trigger_occurrence_id", "")),
				int(activation.get("retrigger_threshold_ordinal", 0)),
			]
			if not marker_keys.has(marker_key):
				marker_keys[marker_key] = true
				activation["retrigger_marker_required"] = true
				metadata["retrigger_marker_required"] = true
		activation["metadata"] = metadata


static func _count_triggers(occurrences: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for occurrence in occurrences:
		var trigger_id: String = str(occurrence.get("trigger_id", ""))
		counts[trigger_id] = int(counts.get(trigger_id, 0)) + 1
	return counts


static func _count_activations_by_slot(
	modifiers: Array[Dictionary],
	engine_events: Array[Dictionary]
) -> Dictionary:
	var counts: Dictionary = {}
	for activation in modifiers:
		var slot_index: int = int(activation.get("tray_slot_index", activation.get("slot_index", -1)))
		counts[slot_index] = int(counts.get(slot_index, 0)) + 1
	for event in engine_events:
		var slot_index: int = int(event.get("tray_slot_index", -1))
		counts[slot_index] = int(counts.get(slot_index, 0)) + 1
	return counts


static func _ledger_identity(ledger: Dictionary) -> Dictionary:
	return {
		"mode_id": str(ledger.get("mode_id", "")),
		"run_generation": int(ledger.get("run_generation", -1)),
		"shot_id": int(ledger.get("shot_id", -1)),
		"attempt_id": int(ledger.get("attempt_id", -1)),
	}


static func _activation_lookup_key(occurrence_id: String, family_id: String) -> String:
	return occurrence_id + "|family:" + family_id


static func _array_variant(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return value as Array if value is Array else []


static func _array_value(source: Dictionary, key: String) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var value: Variant = source.get(key, [])
	if not value is Array:
		return output
	for entry in value as Array:
		if entry is Dictionary:
			output.append((entry as Dictionary).duplicate(true))
	return output


static func _int_array_value(source: Dictionary, key: String) -> Array[int]:
	var output: Array[int] = []
	var value: Variant = source.get(key, [])
	if value is Array:
		for entry in value as Array:
			output.append(int(entry))
	return output


static func _dictionary_value(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func _later_occurrence(a: Dictionary, b: Dictionary) -> Dictionary:
	return b.duplicate(true) if _occurrence_precedes(a, b) else a.duplicate(true)


static func _ordinal_label(value: int) -> String:
	var last_two: int = value % 100
	if last_two >= 11 and last_two <= 13:
		return "%dTH" % value
	match value % 10:
		1:
			return "%dST" % value
		2:
			return "%dND" % value
		3:
			return "%dRD" % value
		_:
			return "%dTH" % value
