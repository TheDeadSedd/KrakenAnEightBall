extends RefCounted
class_name RogueliteBuildSystem

# Run-local owner for The Long Sink's non-physical Eight Ball build.
# Build items are value-only catalog entries and never enter Table's ball list.

signal build_changed(snapshot: Dictionary)
signal eight_ball_acquired(eight_ball_item_id: String, tray_slot_index: int)
signal eight_ball_replaced(old_eight_ball_item_id: String, new_eight_ball_item_id: String, tray_slot_index: int)
signal eight_ball_modifier_activated(activation: Dictionary)
signal build_cleared(reason: String)
signal diagnostics_changed(snapshot: Dictionary)

const EIGHT_BALL_CATALOG := preload("res://scripts/RogueliteEightBallCatalog.gd")
const TRIGGER_EVALUATOR := preload("res://scripts/RogueliteScoringTriggerEvaluator.gd")
const BALANCE_TUNING_SCRIPT := preload("res://scripts/RogueliteBalanceTuning.gd")

const TRAY_CAPACITY := 5
const BUILD_SCHEMA_VERSION := 1
const BUILD_STATE_VERSION := 1

const SOURCE_AUTHORITATIVE := "authoritative"
const SOURCE_PREDICTED := "predicted"
const SOURCE_SHOT_LAB := "shot_lab"

const PHASE_ADD_HAUL := "add_haul"
const PHASE_ADD_MULT := "add_mult"
const PHASE_XMULT := "xmult"
const EFFECT_KIND_RETRIGGER_FAMILY := "retrigger_family"
const UNSUPPORTED_RETRIGGER_REPLACEMENT_WARNING := (
	"Dead Reckoning will currently have no Direct Pot Eight Ball to retrigger."
)
const PHASE_ORDER := {
	PHASE_ADD_HAUL: 0,
	PHASE_ADD_MULT: 1,
	PHASE_XMULT: 2,
}

static var _session_self_test_result: Dictionary = {}

var run_tray_slots: Array[String] = []
var shot_lab_tray_slots: Array[String] = []
var shot_lab_session: bool = false
var run_generation: int = 0
var build_generation: int = 0
var build_version: int = 0

var duplicate_rejection_count: int = 0
var invalid_item_rejection_count: int = 0
var full_tray_rejection_count: int = 0
var acquisitions: int = 0
var replacements: int = 0
var clears: int = 0
var round_transitions: int = 0
var activation_signal_count: int = 0

var last_authoritative_evaluation: Dictionary = {}
var last_predicted_evaluation: Dictionary = {}
var last_shot_lab_evaluation: Dictionary = {}
var last_self_test_result: Dictionary = {}
var active_balance_tuning_snapshot: Dictionary = {}


func _init() -> void:
	run_tray_slots = _make_empty_slots()
	shot_lab_tray_slots = _make_empty_slots()
	last_self_test_result = _session_self_test_result.duplicate(true)


func setup(is_shot_lab_session: bool = false, initial_run_generation: int = 0) -> void:
	shot_lab_session = is_shot_lab_session
	run_generation = maxi(initial_run_generation, 0)
	if shot_lab_session:
		clear_shot_lab_loadout("shot_lab_setup")
	else:
		begin_fresh_run(run_generation)


func set_balance_tuning_snapshot(snapshot: Dictionary) -> void:
	active_balance_tuning_snapshot = snapshot.duplicate(true)
	_emit_build_changed()


func reset_run_state(new_run_generation: int = 0) -> void:
	begin_fresh_run(new_run_generation)


func begin_fresh_run(new_run_generation: int = 0) -> void:
	shot_lab_session = false
	run_generation = maxi(new_run_generation, 0)
	build_generation += 1
	_clear_run_diagnostics()
	_clear_slots(run_tray_slots)
	build_version += 1
	clears += 1
	build_cleared.emit("fresh_run")
	_emit_build_changed()


func restart_run(new_run_generation: int = 0) -> void:
	begin_fresh_run(new_run_generation)


func clear_for_main_menu() -> void:
	shot_lab_session = false
	build_generation += 1
	_clear_run_diagnostics()
	_clear_slots(run_tray_slots)
	_clear_slots(shot_lab_tray_slots)
	build_version += 1
	clears += 1
	build_cleared.emit("main_menu")
	_emit_build_changed()


func begin_round(_round_number: int) -> void:
	# Builds intentionally persist across Long Sink rounds.
	round_transitions += 1
	_emit_diagnostics_changed()


func reset_table() -> void:
	# Table resets do not mutate the run-owned build.
	_emit_diagnostics_changed()


func reset_last_shot() -> void:
	# Reward acquisition is outside shot rewind, so the tray remains unchanged.
	_emit_diagnostics_changed()


func set_shot_lab_session(enabled: bool) -> void:
	if shot_lab_session == enabled:
		return
	shot_lab_session = enabled
	_emit_build_changed()


func is_shot_lab_session() -> bool:
	return shot_lab_session


func acquire_eight_ball(eight_ball_item_id: String) -> Dictionary:
	var item_id: String = eight_ball_item_id.strip_edges()
	var definition: Dictionary = _get_catalog_definition(item_id)
	if definition.is_empty():
		invalid_item_rejection_count += 1
		return _acquisition_failure("unknown_eight_ball_item", item_id)

	var slots: Array[String] = _get_active_slots()
	if slots.has(item_id):
		duplicate_rejection_count += 1
		return _acquisition_failure("duplicate_eight_ball_item", item_id)

	var empty_slot_index: int = _get_first_empty_slot_index(slots)
	if empty_slot_index < 0:
		full_tray_rejection_count += 1
		return _acquisition_failure("tray_full", item_id)

	slots[empty_slot_index] = item_id
	build_version += 1
	acquisitions += 1
	eight_ball_acquired.emit(item_id, empty_slot_index)
	_emit_build_changed()
	return {
		"success": true,
		"reason": "",
		"eight_ball_item_id": item_id,
		"tray_slot_index": empty_slot_index,
		"build_snapshot": get_build_snapshot(),
	}


func acquire_item(eight_ball_item_id: String) -> Dictionary:
	return acquire_eight_ball(eight_ball_item_id)


func replace_eight_ball(tray_slot_index: int, new_eight_ball_item_id: String) -> Dictionary:
	var slots: Array[String] = _get_active_slots()
	if tray_slot_index < 0 or tray_slot_index >= TRAY_CAPACITY:
		return _replacement_failure("invalid_tray_slot", new_eight_ball_item_id, tray_slot_index)

	var new_item_id: String = new_eight_ball_item_id.strip_edges()
	var definition: Dictionary = _get_catalog_definition(new_item_id)
	if definition.is_empty():
		invalid_item_rejection_count += 1
		return _replacement_failure("unknown_eight_ball_item", new_item_id, tray_slot_index)

	var old_item_id: String = slots[tray_slot_index]
	if old_item_id.is_empty():
		return _replacement_failure("tray_slot_empty", new_item_id, tray_slot_index)
	if new_item_id == old_item_id or slots.has(new_item_id):
		duplicate_rejection_count += 1
		return _replacement_failure("duplicate_eight_ball_item", new_item_id, tray_slot_index)

	slots[tray_slot_index] = new_item_id
	build_version += 1
	replacements += 1
	eight_ball_replaced.emit(old_item_id, new_item_id, tray_slot_index)
	_emit_build_changed()
	return {
		"success": true,
		"reason": "",
		"old_eight_ball_item_id": old_item_id,
		"new_eight_ball_item_id": new_item_id,
		"tray_slot_index": tray_slot_index,
		"build_snapshot": get_build_snapshot(),
	}


func replace_item(tray_slot_index: int, new_eight_ball_item_id: String) -> Dictionary:
	return replace_eight_ball(tray_slot_index, new_eight_ball_item_id)


func clear_build(reason: String = "explicit_clear") -> void:
	var slots: Array[String] = _get_active_slots()
	_clear_slots(slots)
	_clear_evaluation_diagnostics()
	build_version += 1
	clears += 1
	build_cleared.emit(reason)
	_emit_build_changed()


func owns_eight_ball(eight_ball_item_id: String) -> bool:
	return _get_active_slots().has(eight_ball_item_id)


func has_empty_slot() -> bool:
	return _get_first_empty_slot_index(_get_active_slots()) >= 0


func is_tray_full() -> bool:
	return not has_empty_slot()


func get_first_empty_slot_index() -> int:
	return _get_first_empty_slot_index(_get_active_slots())


func get_owned_eight_ball_ids() -> Array[String]:
	var owned_ids: Array[String] = []
	for item_id in _get_active_slots():
		if not item_id.is_empty():
			owned_ids.append(item_id)
	return owned_ids


func get_replacement_warning(
	tray_slot_index: int,
	replacement_item_id: String = ""
) -> String:
	var slots: Array[String] = _get_active_slots()
	if tray_slot_index < 0 or tray_slot_index >= mini(slots.size(), TRAY_CAPACITY):
		return ""
	var removed_definition: Dictionary = _get_catalog_definition(slots[tray_slot_index])
	if not _is_regular_direct_pot_definition(removed_definition):
		return ""
	var replacement_definition: Dictionary = _get_catalog_definition(replacement_item_id)
	if _is_regular_direct_pot_definition(replacement_definition):
		return ""
	var has_dead_reckoning: bool = false
	var remaining_direct_support: int = 0
	for slot_index in range(mini(slots.size(), TRAY_CAPACITY)):
		if slot_index == tray_slot_index:
			continue
		var definition: Dictionary = _get_catalog_definition(slots[slot_index])
		if _is_regular_direct_pot_definition(definition):
			remaining_direct_support += 1
		elif (
			str(definition.get("effect_kind", "")) == EFFECT_KIND_RETRIGGER_FAMILY
			and str(definition.get(
				"retrigger_family",
				definition.get("retrigger_family_id", "")
			)) == "direct_pot"
		):
			has_dead_reckoning = true
	if has_dead_reckoning and remaining_direct_support == 0:
		return UNSUPPORTED_RETRIGGER_REPLACEMENT_WARNING
	return ""


func get_build_snapshot() -> Dictionary:
	var slots: Array[String] = _get_active_slots()
	var last_shot: Dictionary = get_last_shot_diagnostics()
	var slot_snapshots: Array[Dictionary] = []
	for slot_index in range(TRAY_CAPACITY):
		var item_id: String = slots[slot_index]
		var definition: Dictionary = _get_catalog_definition(item_id) if not item_id.is_empty() else {}
		slot_snapshots.append({
			"tray_slot_index": slot_index,
			"occupied": not item_id.is_empty(),
			"eight_ball_item_id": item_id,
			"definition": definition.duplicate(true),
		})

	return {
		"schema_version": BUILD_SCHEMA_VERSION,
		"state_version": BUILD_STATE_VERSION,
		"tray_capacity": TRAY_CAPACITY,
		"occupied_slots": get_owned_eight_ball_ids().size(),
		"item_ids_by_slot": slots.duplicate(),
		"slots": slot_snapshots,
		"shot_lab_session": shot_lab_session,
		"run_generation": run_generation,
		"build_generation": build_generation,
		"build_version": build_version,
		"duplicate_rejection_count": duplicate_rejection_count,
		"invalid_item_rejection_count": invalid_item_rejection_count,
		"full_tray_rejection_count": full_tray_rejection_count,
		"acquisitions": acquisitions,
		"replacements": replacements,
		"clears": clears,
		"round_transitions": round_transitions,
		"activation_signal_count": activation_signal_count,
		"last_shot_activation_count_by_slot": last_shot.get("activation_count_by_slot", {}).duplicate(true),
		"last_shot": last_shot,
		"last_self_test_result": last_self_test_result.duplicate(true),
		"active_balance_tuning": active_balance_tuning_snapshot.duplicate(true),
	}


func get_run_state() -> Dictionary:
	# This state is run-local resume data, not persistent metaprogression.
	return {
		"state_version": BUILD_STATE_VERSION,
		"run_generation": run_generation,
		"build_generation": build_generation,
		"build_version": build_version,
		"run_tray_slots": run_tray_slots.duplicate(true),
		"duplicate_rejection_count": duplicate_rejection_count,
		"invalid_item_rejection_count": invalid_item_rejection_count,
		"full_tray_rejection_count": full_tray_rejection_count,
		"acquisitions": acquisitions,
		"replacements": replacements,
		"clears": clears,
		"round_transitions": round_transitions,
	}


func restore_run_state(state: Dictionary) -> Dictionary:
	var restored_slots: Array[String] = _normalized_slot_array(state.get("run_tray_slots", []))
	var validation: Dictionary = _validate_slot_ids(restored_slots)
	if not bool(validation.get("valid", false)):
		return {
			"success": false,
			"reason": str(validation.get("reason", "invalid_run_build_state")),
		}

	run_tray_slots = restored_slots
	run_generation = maxi(int(state.get("run_generation", run_generation)), 0)
	build_generation = maxi(int(state.get("build_generation", build_generation)), 0)
	build_version = maxi(int(state.get("build_version", build_version)), 0)
	duplicate_rejection_count = maxi(int(state.get("duplicate_rejection_count", duplicate_rejection_count)), 0)
	invalid_item_rejection_count = maxi(int(state.get("invalid_item_rejection_count", invalid_item_rejection_count)), 0)
	full_tray_rejection_count = maxi(int(state.get("full_tray_rejection_count", full_tray_rejection_count)), 0)
	acquisitions = maxi(int(state.get("acquisitions", acquisitions)), 0)
	replacements = maxi(int(state.get("replacements", replacements)), 0)
	clears = maxi(int(state.get("clears", clears)), 0)
	round_transitions = maxi(int(state.get("round_transitions", round_transitions)), 0)
	shot_lab_session = false
	_emit_build_changed()
	return {"success": true, "build_snapshot": get_build_snapshot()}


func set_shot_lab_loadout(eight_ball_item_ids: Array) -> Dictionary:
	var requested_slots: Array[String] = _normalized_slot_array(eight_ball_item_ids)
	var validation: Dictionary = _validate_slot_ids(requested_slots)
	if not bool(validation.get("valid", false)):
		return {
			"success": false,
			"reason": str(validation.get("reason", "invalid_shot_lab_loadout")),
		}

	shot_lab_tray_slots = requested_slots
	shot_lab_session = true
	build_version += 1
	_clear_evaluation_diagnostics()
	_emit_build_changed()
	return {"success": true, "build_snapshot": get_build_snapshot()}


func clear_shot_lab_loadout(reason: String = "shot_lab_clear") -> void:
	_clear_slots(shot_lab_tray_slots)
	if shot_lab_session:
		build_version += 1
		_clear_evaluation_diagnostics()
		build_cleared.emit(reason)
		_emit_build_changed()


func get_shot_lab_loadout_snapshot() -> Dictionary:
	var previous_mode: bool = shot_lab_session
	shot_lab_session = true
	var snapshot: Dictionary = get_build_snapshot()
	shot_lab_session = previous_mode
	return snapshot


func evaluate_analyzed_ledger(
	analyzed_ledger: Dictionary,
	source: String = SOURCE_AUTHORITATIVE,
	emit_activation_signals: bool = false
) -> Dictionary:
	var trigger_occurrences: Array[Dictionary] = _evaluate_trigger_occurrences(analyzed_ledger)
	return evaluate_trigger_occurrences(trigger_occurrences, source, emit_activation_signals)


func record_authoritative_result(analyzed_ledger: Dictionary, emit_activation_signals: bool = true) -> Dictionary:
	return evaluate_analyzed_ledger(analyzed_ledger, SOURCE_AUTHORITATIVE, emit_activation_signals)


func record_predicted_result(analyzed_ledger: Dictionary) -> Dictionary:
	return evaluate_analyzed_ledger(analyzed_ledger, SOURCE_PREDICTED, false)


func evaluate_trigger_occurrences(
	trigger_occurrences: Array[Dictionary],
	source: String = SOURCE_AUTHORITATIVE,
	emit_activation_signals: bool = false
) -> Dictionary:
	var modifier_context: Array[Dictionary] = build_modifier_context_from_trigger_occurrences(trigger_occurrences)
	var evaluation: Dictionary = _make_evaluation_snapshot(trigger_occurrences, modifier_context, source)
	_store_evaluation(source, evaluation)
	if emit_activation_signals:
		for activation in modifier_context:
			notify_modifier_activation(activation)
	_emit_diagnostics_changed()
	return evaluation.duplicate(true)


func build_modifier_context(analyzed_ledger: Dictionary) -> Array[Dictionary]:
	var trigger_occurrences: Array[Dictionary] = _evaluate_trigger_occurrences(analyzed_ledger)
	return build_modifier_context_from_trigger_occurrences(trigger_occurrences)


func build_modifier_context_from_trigger_occurrences(trigger_occurrences: Array[Dictionary]) -> Array[Dictionary]:
	return _build_modifier_context_for_slots(
		trigger_occurrences,
		_get_active_slots(),
		""
	)


func build_modifier_context_excluding_item(
	analyzed_ledger: Dictionary,
	excluded_item_id: String
) -> Array[Dictionary]:
	var trigger_occurrences: Array[Dictionary] = _evaluate_trigger_occurrences(analyzed_ledger)
	return _build_modifier_context_for_slots(
		trigger_occurrences,
		_get_active_slots(),
		excluded_item_id
	)


func _build_modifier_context_for_slots(
	trigger_occurrences: Array[Dictionary],
	slots: Array[String],
	excluded_item_id: String
) -> Array[Dictionary]:
	var modifier_context: Array[Dictionary] = []
	for slot_index in range(TRAY_CAPACITY):
		var item_id: String = slots[slot_index]
		if item_id.is_empty() or item_id == excluded_item_id:
			continue
		var definition: Dictionary = _get_catalog_definition(item_id)
		if definition.is_empty():
			continue
		if str(definition.get("effect_kind", "")) == EFFECT_KIND_RETRIGGER_FAMILY:
			continue
		var definition_trigger_id: String = str(definition.get("trigger_id", ""))
		for occurrence in trigger_occurrences:
			if str(occurrence.get("trigger_id", "")) != definition_trigger_id:
				continue
			var original: Dictionary = _make_modifier_activation(
				definition,
				occurrence,
				slot_index
			)
			modifier_context.append(original)
			var retrigger_source: Dictionary = _find_retrigger_source(
				definition,
				slots,
				excluded_item_id
			)
			if retrigger_source.is_empty():
				continue
			var retrigger_count: int = maxi(int(retrigger_source.get("retrigger_count", 1)), 0)
			for retrigger_index in range(1, retrigger_count + 1):
				modifier_context.append(_make_retrigger_activation(
					original,
					retrigger_source,
					retrigger_index
				))
	modifier_context.sort_custom(_modifier_activation_less_than)
	_finalize_activation_metadata(modifier_context)
	return modifier_context


func _find_retrigger_source(
	target_definition: Dictionary,
	slots: Array[String],
	excluded_item_id: String
) -> Dictionary:
	var target_family: String = str(target_definition.get("family_id", ""))
	if target_family.is_empty():
		return {}
	for source_slot_index in range(mini(slots.size(), TRAY_CAPACITY)):
		var source_item_id: String = slots[source_slot_index]
		if source_item_id.is_empty() or source_item_id == excluded_item_id:
			continue
		var source_definition: Dictionary = _get_catalog_definition(source_item_id)
		if str(source_definition.get("effect_kind", "")) != EFFECT_KIND_RETRIGGER_FAMILY:
			continue
		var retrigger_family: String = str(source_definition.get(
			"retrigger_family",
			source_definition.get("retrigger_family_id", "")
		))
		if retrigger_family != target_family:
			continue
		var source: Dictionary = source_definition.duplicate(true)
		source["tray_slot_index"] = source_slot_index
		return source
	return {}


func _is_regular_direct_pot_definition(definition: Dictionary) -> bool:
	return (
		not definition.is_empty()
		and str(definition.get("family_id", "")) == "direct_pot"
		and str(definition.get("effect_kind", "")) != EFFECT_KIND_RETRIGGER_FAMILY
	)


func notify_modifier_activation(activation: Dictionary) -> void:
	if activation.is_empty():
		return
	activation_signal_count += 1
	eight_ball_modifier_activated.emit(activation.duplicate(true))


func get_last_shot_diagnostics() -> Dictionary:
	var parity: Dictionary = _compare_evaluations(last_predicted_evaluation, last_authoritative_evaluation)
	var activation_counts: Dictionary = _dictionary_value(
		last_authoritative_evaluation,
		"activation_count_by_tray_slot"
	).duplicate(true)
	return {
		"authoritative": last_authoritative_evaluation.duplicate(true),
		"predicted": last_predicted_evaluation.duplicate(true),
		"shot_lab": last_shot_lab_evaluation.duplicate(true),
		"trigger_occurrences": last_authoritative_evaluation.get("trigger_occurrences", []).duplicate(true),
		"modifier_activations": last_authoritative_evaluation.get("modifier_context", []).duplicate(true),
		"activation_count_by_slot": activation_counts,
		"predicted_actual_build_parity": parity,
	}


func run_self_tests() -> Dictionary:
	var started_at_usec: int = Time.get_ticks_usec()
	var tests: Array[Dictionary] = []
	var catalog_definitions: Array[Dictionary] = _get_catalog_definitions()
	_record_test(
		tests,
		"Catalog contains exactly twenty-two definitions",
		catalog_definitions.size() == 22,
		22,
		catalog_definitions.size()
	)

	var subject: RogueliteBuildSystem = RogueliteBuildSystem.new()
	subject.begin_fresh_run(1)
	_record_test(tests, "Tray capacity is five", TRAY_CAPACITY == 5, 5, TRAY_CAPACITY)

	var crooked: String = "single_bank_haul_crooked_coin"
	var first_toll: String = "single_bank_mult_first_toll"
	var twin_tribute: String = "double_bank_haul_twin_tribute"
	var acquire_first: Dictionary = subject.acquire_eight_ball(crooked)
	_record_test(tests, "First acquisition uses first empty slot", bool(acquire_first.get("success", false)) and int(acquire_first.get("tray_slot_index", -1)) == 0, 0, int(acquire_first.get("tray_slot_index", -1)))
	var duplicate: Dictionary = subject.acquire_eight_ball(crooked)
	_record_test(tests, "Duplicate acquisition is rejected", not bool(duplicate.get("success", false)) and str(duplicate.get("reason", "")) == "duplicate_eight_ball_item", "duplicate_eight_ball_item", str(duplicate.get("reason", "")))
	subject.acquire_eight_ball(first_toll)
	var replacement: Dictionary = subject.replace_eight_ball(0, twin_tribute)
	_record_test(tests, "Replacement preserves slot index", bool(replacement.get("success", false)) and int(replacement.get("tray_slot_index", -1)) == 0, 0, int(replacement.get("tray_slot_index", -1)))
	_record_test(tests, "Removed item becomes eligible again", not subject.owns_eight_ball(crooked), false, subject.owns_eight_ball(crooked))

	var run_ids_before_lab: Array[String] = subject.get_owned_eight_ball_ids()
	var lab_result: Dictionary = subject.set_shot_lab_loadout([crooked, first_toll])
	var lab_ids: Array[String] = subject.get_owned_eight_ball_ids()
	subject.set_shot_lab_session(false)
	_record_test(tests, "Shot Lab loadout is accepted", bool(lab_result.get("success", false)) and lab_ids == [crooked, first_toll], [crooked, first_toll], lab_ids)
	_record_test(tests, "Shot Lab loadout is isolated from run tray", subject.get_owned_eight_ball_ids() == run_ids_before_lab, run_ids_before_lab, subject.get_owned_eight_ball_ids())

	var ordering_subject: RogueliteBuildSystem = RogueliteBuildSystem.new()
	ordering_subject.begin_fresh_run(2)
	ordering_subject.acquire_eight_ball(first_toll)
	ordering_subject.acquire_eight_ball(crooked)
	var occurrences: Array[Dictionary] = [
		{"trigger_occurrence_id": "b", "trigger_id": "single_bank_milestone", "event_index": 8, "ball_id": 2},
		{"trigger_occurrence_id": "a", "trigger_id": "single_bank_milestone", "event_index": 4, "ball_id": 1},
	]
	var context: Array[Dictionary] = ordering_subject.build_modifier_context_from_trigger_occurrences(occurrences)
	var phase_order_valid: bool = context.size() == 4
	if phase_order_valid:
		phase_order_valid = str(context[0].get("phase", "")) == PHASE_ADD_HAUL and str(context[2].get("phase", "")) == PHASE_ADD_MULT
	_record_test(tests, "Modifier phases and occurrences are deterministic", phase_order_valid, true, phase_order_valid)

	var failed_tests: Array[Dictionary] = []
	for test in tests:
		if not bool(test.get("passed", false)):
			failed_tests.append(test.duplicate(true))
	last_self_test_result = {
		"status": "PASS" if failed_tests.is_empty() else "FAIL",
		"total_tests": tests.size(),
		"passed": tests.size() - failed_tests.size(),
		"failed": failed_tests.size(),
		"failures": failed_tests,
		"tests": tests,
		"duration_usec": maxi(Time.get_ticks_usec() - started_at_usec, 0),
		"timestamp_unix": int(Time.get_unix_time_from_system()),
	}
	_session_self_test_result = last_self_test_result.duplicate(true)
	_emit_diagnostics_changed()
	return last_self_test_result.duplicate(true)


func record_self_test_result(result: Dictionary) -> void:
	last_self_test_result = result.duplicate(true)
	_session_self_test_result = last_self_test_result.duplicate(true)
	_emit_diagnostics_changed()


func _make_modifier_activation(definition: Dictionary, occurrence: Dictionary, slot_index: int) -> Dictionary:
	var item_id: String = str(definition.get("eight_ball_item_id", definition.get("id", "")))
	var occurrence_id: String = str(occurrence.get("trigger_occurrence_id", ""))
	var activation_id: String = "%s|slot:%d|%s|original" % [
		item_id,
		slot_index,
		occurrence_id,
	]
	return {
		"activation_id": activation_id,
		"modifier_id": item_id,
		"eight_ball_item_id": item_id,
		"display_name": str(definition.get("display_name", item_id)),
		"short_effect": str(definition.get("short_effect", "")),
		"tooltip": str(definition.get("tooltip", "")),
		"family_id": str(definition.get("family_id", "")),
		"phase": str(definition.get("modifier_phase", definition.get("phase", ""))),
		"slot_index": slot_index,
		"tray_slot_index": slot_index,
		"trigger_id": str(occurrence.get("trigger_id", "")),
		"trigger_occurrence_id": occurrence_id,
		"trigger_ball_id": int(occurrence.get("ball_id", occurrence.get("trigger_ball_id", -1))),
		"trigger_event_index": int(occurrence.get("event_index", occurrence.get("trigger_event_index", -1))),
		"value": definition.get("value", 0),
		"rarity": str(definition.get("rarity", "common")),
		"is_retrigger": false,
		"retrigger_index": 0,
		"retrigger_source_item_id": "",
		"retrigger_source_slot_index": -1,
		"original_activation_id": activation_id,
		"enabled": true,
		"metadata": {
			"family_id": str(definition.get("family_id", "")),
			"pocket_order": int(occurrence.get("pocket_order", -1)),
			"world_position": occurrence.get("world_position", Vector2.ZERO),
			"trigger_metadata": _dictionary_value(occurrence, "metadata").duplicate(true),
		},
	}


func _make_retrigger_activation(
	original: Dictionary,
	retrigger_source: Dictionary,
	retrigger_index: int
) -> Dictionary:
	var activation: Dictionary = original.duplicate(true)
	var original_activation_id: String = str(original.get("activation_id", ""))
	var source_item_id: String = str(retrigger_source.get(
		"eight_ball_item_id",
		retrigger_source.get("id", "")
	))
	activation["activation_id"] = "%s|retrigger:%d|source:%s" % [
		original_activation_id,
		retrigger_index,
		source_item_id,
	]
	activation["is_retrigger"] = true
	activation["retrigger_index"] = retrigger_index
	activation["retrigger_source_item_id"] = source_item_id
	activation["retrigger_source_display_name"] = str(retrigger_source.get(
		"display_name",
		source_item_id
	))
	activation["retrigger_source_slot_index"] = int(retrigger_source.get(
		"tray_slot_index",
		-1
	))
	activation["original_activation_id"] = original_activation_id
	activation["retrigger_marker_required"] = false
	var metadata: Dictionary = _dictionary_value(activation, "metadata").duplicate(true)
	metadata.merge({
		"is_retrigger": true,
		"retrigger_index": retrigger_index,
		"retrigger_source_item_id": source_item_id,
		"retrigger_source_display_name": activation["retrigger_source_display_name"],
		"retrigger_source_slot_index": activation["retrigger_source_slot_index"],
		"original_activation_id": original_activation_id,
		"trigger_occurrence_id": str(activation.get("trigger_occurrence_id", "")),
	}, true)
	activation["metadata"] = metadata
	return activation


func _finalize_activation_metadata(modifier_context: Array[Dictionary]) -> void:
	var item_ordinals: Dictionary = {}
	var marked_retrigger_occurrences: Dictionary = {}
	for activation in modifier_context:
		var item_id: String = str(activation.get("eight_ball_item_id", ""))
		var ordinal: int = int(item_ordinals.get(item_id, 0)) + 1
		item_ordinals[item_id] = ordinal
		activation["activation_ordinal"] = ordinal
		if not bool(activation.get("is_retrigger", false)):
			continue
		var marker_key: String = "%s|%s" % [
			str(activation.get("retrigger_source_item_id", "")),
			str(activation.get("trigger_occurrence_id", "")),
		]
		if marked_retrigger_occurrences.has(marker_key):
			continue
		marked_retrigger_occurrences[marker_key] = true
		activation["retrigger_marker_required"] = true
		var metadata: Dictionary = _dictionary_value(activation, "metadata").duplicate(true)
		metadata["retrigger_marker_required"] = true
		activation["metadata"] = metadata


func _modifier_activation_less_than(left: Dictionary, right: Dictionary) -> bool:
	var left_phase: int = int(PHASE_ORDER.get(str(left.get("phase", "")), 99))
	var right_phase: int = int(PHASE_ORDER.get(str(right.get("phase", "")), 99))
	if left_phase != right_phase:
		return left_phase < right_phase
	var left_slot: int = int(left.get("tray_slot_index", -1))
	var right_slot: int = int(right.get("tray_slot_index", -1))
	if left_slot != right_slot:
		return left_slot < right_slot
	var left_event_index: int = int(left.get("trigger_event_index", -1))
	var right_event_index: int = int(right.get("trigger_event_index", -1))
	if left_event_index != right_event_index:
		return left_event_index < right_event_index
	var left_occurrence: String = str(left.get("trigger_occurrence_id", ""))
	var right_occurrence: String = str(right.get("trigger_occurrence_id", ""))
	if left_occurrence != right_occurrence:
		return left_occurrence < right_occurrence
	var left_retrigger_index: int = int(left.get("retrigger_index", 0))
	var right_retrigger_index: int = int(right.get("retrigger_index", 0))
	if left_retrigger_index != right_retrigger_index:
		return left_retrigger_index < right_retrigger_index
	return str(left.get("activation_id", "")) < str(right.get("activation_id", ""))


func _make_evaluation_snapshot(
	trigger_occurrences: Array[Dictionary],
	modifier_context: Array[Dictionary],
	source: String
) -> Dictionary:
	var trigger_counts: Dictionary = {}
	for occurrence in trigger_occurrences:
		var trigger_id: String = str(occurrence.get("trigger_id", ""))
		trigger_counts[trigger_id] = int(trigger_counts.get(trigger_id, 0)) + 1

	var slot_activation_counts: Dictionary = {}
	var triggered_item_ids: Dictionary = {}
	var add_haul_total: float = 0.0
	var add_mult_total: float = 0.0
	var xmult_product: float = 1.0
	var retrigger_activation_count: int = 0
	var retrigger_count_by_source_item: Dictionary = {}
	var retrigger_count_by_phase: Dictionary = {}
	var supported_retrigger_occurrences: Dictionary = {}
	for activation in modifier_context:
		var slot_index: int = int(activation.get("tray_slot_index", -1))
		slot_activation_counts[slot_index] = int(slot_activation_counts.get(slot_index, 0)) + 1
		triggered_item_ids[str(activation.get("eight_ball_item_id", ""))] = true
		var phase: String = str(activation.get("phase", ""))
		var value: float = float(activation.get("value", 0.0))
		if bool(activation.get("is_retrigger", false)):
			retrigger_activation_count += 1
			var retrigger_source_item_id: String = str(activation.get(
				"retrigger_source_item_id",
				""
			))
			if not retrigger_source_item_id.is_empty():
				triggered_item_ids[retrigger_source_item_id] = true
				retrigger_count_by_source_item[retrigger_source_item_id] = int(
					retrigger_count_by_source_item.get(retrigger_source_item_id, 0)
				) + 1
			retrigger_count_by_phase[phase] = int(
				retrigger_count_by_phase.get(phase, 0)
			) + 1
			supported_retrigger_occurrences[str(activation.get(
				"trigger_occurrence_id",
				""
			))] = true
		match phase:
			PHASE_ADD_HAUL:
				add_haul_total += value
			PHASE_ADD_MULT:
				add_mult_total += value
			PHASE_XMULT:
				xmult_product *= value

	var items_not_triggered: Array[String] = []
	for item_id in get_owned_eight_ball_ids():
		if not triggered_item_ids.has(item_id):
			items_not_triggered.append(item_id)

	return {
		"source": source,
		"build_generation": build_generation,
		"build_version": build_version,
		"trigger_occurrences": trigger_occurrences.duplicate(true),
		"trigger_occurrence_count": trigger_occurrences.size(),
		"trigger_count_by_id": trigger_counts,
		"modifier_context": modifier_context.duplicate(true),
		"modifier_activation_count": modifier_context.size(),
		"activation_count_by_tray_slot": slot_activation_counts,
		"add_haul_total": add_haul_total,
		"add_mult_total": add_mult_total,
		"xmult_product": xmult_product,
		"retrigger_activation_count": retrigger_activation_count,
		"retrigger_count_by_source_item": retrigger_count_by_source_item,
		"retrigger_count_by_phase": retrigger_count_by_phase,
		"supported_retrigger_occurrence_count": supported_retrigger_occurrences.size(),
		"items_not_triggered": items_not_triggered,
	}


func _store_evaluation(source: String, evaluation: Dictionary) -> void:
	match source:
		SOURCE_PREDICTED:
			last_predicted_evaluation = evaluation.duplicate(true)
		SOURCE_SHOT_LAB:
			last_shot_lab_evaluation = evaluation.duplicate(true)
		_:
			last_authoritative_evaluation = evaluation.duplicate(true)


func _compare_evaluations(predicted: Dictionary, authoritative: Dictionary) -> Dictionary:
	if predicted.is_empty() or authoritative.is_empty():
		return {"available": false, "matches": false}
	var predicted_context: Array = predicted.get("modifier_context", []) as Array
	var authoritative_context: Array = authoritative.get("modifier_context", []) as Array
	var predicted_keys: Array[String] = _get_activation_parity_keys(predicted_context)
	var authoritative_keys: Array[String] = _get_activation_parity_keys(authoritative_context)
	return {
		"available": true,
		"matches": predicted_keys == authoritative_keys,
		"predicted_activation_count": predicted_context.size(),
		"authoritative_activation_count": authoritative_context.size(),
		"predicted_activation_keys": predicted_keys,
		"authoritative_activation_keys": authoritative_keys,
	}


func _get_activation_parity_keys(context: Array) -> Array[String]:
	var keys: Array[String] = []
	for activation_value in context:
		if not activation_value is Dictionary:
			continue
		var activation: Dictionary = activation_value as Dictionary
		keys.append("%s|%d|%s|%s|%d|%s|%s|%d" % [
			str(activation.get("phase", "")),
			int(activation.get("tray_slot_index", activation.get("slot_index", -1))),
			str(activation.get("eight_ball_item_id", "")),
			str(activation.get("trigger_id", "")),
			int(activation.get("trigger_event_index", -1)),
			str(activation.get("trigger_occurrence_id", "")),
			str(activation.get("retrigger_source_item_id", "")),
			int(activation.get("retrigger_index", 0)),
		])
	return keys


func _evaluate_trigger_occurrences(analyzed_ledger: Dictionary) -> Array[Dictionary]:
	return TRIGGER_EVALUATOR.evaluate(analyzed_ledger)


func _get_catalog_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for definition in EIGHT_BALL_CATALOG.get_all_definitions():
		definitions.append(BALANCE_TUNING_SCRIPT.apply_definition_overrides(
			definition,
			active_balance_tuning_snapshot
		))
	return definitions


func _get_catalog_definition(eight_ball_item_id: String) -> Dictionary:
	if eight_ball_item_id.is_empty():
		return {}
	return BALANCE_TUNING_SCRIPT.apply_definition_overrides(
		EIGHT_BALL_CATALOG.get_definition(eight_ball_item_id),
		active_balance_tuning_snapshot
	)


func _get_active_slots() -> Array[String]:
	return shot_lab_tray_slots if shot_lab_session else run_tray_slots


func _make_empty_slots() -> Array[String]:
	var slots: Array[String] = []
	for _slot_index in range(TRAY_CAPACITY):
		slots.append("")
	return slots


func _clear_slots(slots: Array[String]) -> void:
	for slot_index in range(TRAY_CAPACITY):
		slots[slot_index] = ""


func _get_first_empty_slot_index(slots: Array[String]) -> int:
	for slot_index in range(mini(slots.size(), TRAY_CAPACITY)):
		if slots[slot_index].is_empty():
			return slot_index
	return -1


func _normalized_slot_array(value: Variant) -> Array[String]:
	var slots: Array[String] = _make_empty_slots()
	if not value is Array:
		return slots
	var values: Array = value as Array
	for slot_index in range(mini(values.size(), TRAY_CAPACITY)):
		slots[slot_index] = str(values[slot_index]).strip_edges()
	return slots


func _validate_slot_ids(slots: Array[String]) -> Dictionary:
	var seen_ids: Dictionary = {}
	for item_id in slots:
		if item_id.is_empty():
			continue
		if seen_ids.has(item_id):
			return {"valid": false, "reason": "duplicate_eight_ball_item"}
		if _get_catalog_definition(item_id).is_empty():
			return {"valid": false, "reason": "unknown_eight_ball_item"}
		seen_ids[item_id] = true
	return {"valid": true, "reason": ""}


func _acquisition_failure(reason: String, item_id: String) -> Dictionary:
	_emit_diagnostics_changed()
	return {
		"success": false,
		"reason": reason,
		"eight_ball_item_id": item_id,
		"tray_slot_index": -1,
	}


func _replacement_failure(reason: String, item_id: String, slot_index: int) -> Dictionary:
	_emit_diagnostics_changed()
	return {
		"success": false,
		"reason": reason,
		"new_eight_ball_item_id": item_id,
		"tray_slot_index": slot_index,
	}


func _clear_run_diagnostics() -> void:
	duplicate_rejection_count = 0
	invalid_item_rejection_count = 0
	full_tray_rejection_count = 0
	acquisitions = 0
	replacements = 0
	clears = 0
	round_transitions = 0
	activation_signal_count = 0
	_clear_evaluation_diagnostics()


func _clear_evaluation_diagnostics() -> void:
	last_authoritative_evaluation.clear()
	last_predicted_evaluation.clear()
	last_shot_lab_evaluation.clear()


func _record_test(
	tests: Array[Dictionary],
	name: String,
	passed: bool,
	expected: Variant,
	actual: Variant
) -> void:
	tests.append({
		"name": name,
		"passed": passed,
		"expected": expected,
		"actual": actual,
	})


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry in value as Array:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return (value as Dictionary) if value is Dictionary else {}


func _emit_build_changed() -> void:
	var snapshot: Dictionary = get_build_snapshot()
	build_changed.emit(snapshot.duplicate(true))
	diagnostics_changed.emit(snapshot.duplicate(true))


func _emit_diagnostics_changed() -> void:
	diagnostics_changed.emit(get_build_snapshot())
