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
const BUILD_EFFECT_EVALUATOR := preload("res://scripts/RogueliteBuildEffectEvaluator.gd")
const BALANCE_TUNING_SCRIPT := preload("res://scripts/RogueliteBalanceTuning.gd")

const TRAY_CAPACITY := 5
const BUILD_SCHEMA_VERSION := 2
const BUILD_STATE_VERSION := 2
const OWNED_ITEM_STATE_VERSION := 1
const FIRST_OWNED_ITEM_INSTANCE_ID := 1

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
var run_owned_item_instances: Array[Dictionary] = []
var shot_lab_owned_item_instances: Array[Dictionary] = []
var shot_lab_session: bool = false
var run_generation: int = 0
var build_generation: int = 0
var build_version: int = 0
var current_round: int = 0
var run_owned_item_state_version: int = 0
var shot_lab_owned_item_state_version: int = 0
var next_run_owned_item_instance_id: int = FIRST_OWNED_ITEM_INSTANCE_ID
var next_shot_lab_owned_item_instance_id: int = FIRST_OWNED_ITEM_INSTANCE_ID

var run_applied_state_mutation_transaction_keys: Dictionary = {}
var shot_lab_applied_state_mutation_transaction_keys: Dictionary = {}
var run_applied_state_mutation_transaction_order: Array[String] = []
var shot_lab_applied_state_mutation_transaction_order: Array[String] = []
var run_state_mutation_transactions_applied: int = 0
var shot_lab_state_mutation_transactions_applied: int = 0
var run_state_mutations_applied: int = 0
var shot_lab_state_mutations_applied: int = 0
var run_duplicate_state_mutation_suppressions: int = 0
var shot_lab_duplicate_state_mutation_suppressions: int = 0
var run_invalid_state_mutation_rejections: int = 0
var shot_lab_invalid_state_mutation_rejections: int = 0
var run_last_state_mutation_result: Dictionary = {}
var shot_lab_last_state_mutation_result: Dictionary = {}

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
	run_owned_item_instances = _make_empty_instance_slots()
	shot_lab_owned_item_instances = _make_empty_instance_slots()
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
	_clear_slots(shot_lab_tray_slots)
	_clear_owned_item_instances(run_owned_item_instances)
	_clear_owned_item_instances(shot_lab_owned_item_instances)
	_reset_state_mutation_context(false, true)
	_reset_state_mutation_context(true, true)
	current_round = 0
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
	_clear_owned_item_instances(run_owned_item_instances)
	_clear_owned_item_instances(shot_lab_owned_item_instances)
	_reset_state_mutation_context(false, true)
	_reset_state_mutation_context(true, true)
	current_round = 0
	build_version += 1
	clears += 1
	build_cleared.emit("main_menu")
	_emit_build_changed()


func begin_round(round_number: int) -> void:
	# Builds intentionally persist across Long Sink rounds.
	current_round = maxi(round_number, 0)
	round_transitions += 1
	_emit_diagnostics_changed()


func reset_table() -> void:
	# Table resets do not mutate the run-owned build.
	_emit_diagnostics_changed()


func reset_last_shot() -> void:
	# The rewind owner restores item state through restore_rewind_state().
	# This compatibility hook intentionally does not infer or replay mutations.
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
	var owned_instance: Dictionary = _create_owned_item_instance(
		definition,
		empty_slot_index,
		0 if shot_lab_session else current_round
	)
	_set_active_owned_item_instance(empty_slot_index, owned_instance)
	_increment_active_owned_item_state_version()
	build_version += 1
	acquisitions += 1
	eight_ball_acquired.emit(item_id, empty_slot_index)
	_emit_build_changed()
	return {
		"success": true,
		"reason": "",
		"eight_ball_item_id": item_id,
		"tray_slot_index": empty_slot_index,
		"owned_item_instance_id": int(owned_instance.get("owned_item_instance_id", 0)),
		"owned_item_instance": owned_instance.duplicate(true),
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

	var old_owned_instance: Dictionary = _get_active_owned_item_instance(tray_slot_index)
	slots[tray_slot_index] = new_item_id
	var new_owned_instance: Dictionary = _create_owned_item_instance(
		definition,
		tray_slot_index,
		0 if shot_lab_session else current_round
	)
	_set_active_owned_item_instance(tray_slot_index, new_owned_instance)
	_increment_active_owned_item_state_version()
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
		"removed_owned_item_instance_id": int(old_owned_instance.get(
			"owned_item_instance_id",
			0
		)),
		"owned_item_instance_id": int(new_owned_instance.get("owned_item_instance_id", 0)),
		"owned_item_instance": new_owned_instance.duplicate(true),
		"build_snapshot": get_build_snapshot(),
	}


func replace_item(tray_slot_index: int, new_eight_ball_item_id: String) -> Dictionary:
	return replace_eight_ball(tray_slot_index, new_eight_ball_item_id)


func clear_build(reason: String = "explicit_clear") -> void:
	var slots: Array[String] = _get_active_slots()
	_clear_slots(slots)
	_clear_owned_item_instances(_get_active_owned_item_instances())
	_reset_state_mutation_context(shot_lab_session, false)
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


func get_owned_item_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for instance in _get_active_owned_item_instances():
		if not instance.is_empty():
			result.append(instance.duplicate(true))
	return result


func get_owned_item_instance_by_slot(tray_slot_index: int) -> Dictionary:
	return _get_active_owned_item_instance(tray_slot_index).duplicate(true)


func get_owned_item_instance(owned_item_instance_id: int) -> Dictionary:
	var slot_index: int = _find_instance_slot_index(
		_get_active_owned_item_instances(),
		owned_item_instance_id
	)
	if slot_index < 0:
		return {}
	return _get_active_owned_item_instance(slot_index).duplicate(true)


func get_owned_item_state(owned_item_instance_id: int) -> Dictionary:
	var instance: Dictionary = get_owned_item_instance(owned_item_instance_id)
	return _dictionary_value(instance, "state").duplicate(true)


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
	var owned_instances: Array[Dictionary] = _get_active_owned_item_instances()
	var last_shot: Dictionary = get_last_shot_diagnostics()
	var slot_snapshots: Array[Dictionary] = []
	for slot_index in range(TRAY_CAPACITY):
		var item_id: String = slots[slot_index]
		var definition: Dictionary = _get_catalog_definition(item_id) if not item_id.is_empty() else {}
		var owned_instance: Dictionary = owned_instances[slot_index].duplicate(true)
		slot_snapshots.append({
			"tray_slot_index": slot_index,
			"slot_index": slot_index,
			"occupied": not item_id.is_empty(),
			"eight_ball_item_id": item_id,
			"owned_item_instance_id": int(owned_instance.get("owned_item_instance_id", 0)),
			"acquired_round": int(owned_instance.get("acquired_round", 0)),
			"state": _dictionary_value(owned_instance, "state").duplicate(true),
			"owned_item_instance": owned_instance,
			"definition": definition.duplicate(true),
		})
	var item_state_snapshot: Dictionary = get_owned_item_state_snapshot()

	return {
		"schema_version": BUILD_SCHEMA_VERSION,
		"state_version": BUILD_STATE_VERSION,
		"tray_capacity": TRAY_CAPACITY,
		"occupied_slots": get_owned_eight_ball_ids().size(),
		"item_ids_by_slot": slots.duplicate(),
		"slots": slot_snapshots,
		"owned_item_instances": get_owned_item_instances(),
		"owned_item_instances_by_slot": _duplicate_instance_slots(owned_instances),
		"owned_item_state_snapshot": item_state_snapshot,
		"owned_item_state_version": _get_active_owned_item_state_version(),
		"next_owned_item_instance_id": _get_active_next_owned_item_instance_id(),
		"shot_lab_session": shot_lab_session,
		"run_generation": run_generation,
		"current_round": 0 if shot_lab_session else current_round,
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
		"state_mutation_diagnostics": _get_active_state_mutation_diagnostics(),
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
		"current_round": current_round,
		"run_tray_slots": run_tray_slots.duplicate(true),
		"run_owned_item_instances": _duplicate_instance_slots(run_owned_item_instances),
		"run_owned_item_state_version": run_owned_item_state_version,
		"next_run_owned_item_instance_id": next_run_owned_item_instance_id,
		"applied_state_mutation_transaction_keys": (
			run_applied_state_mutation_transaction_order.duplicate()
		),
		"state_mutation_transactions_applied": run_state_mutation_transactions_applied,
		"state_mutations_applied": run_state_mutations_applied,
		"duplicate_state_mutation_suppressions": run_duplicate_state_mutation_suppressions,
		"invalid_state_mutation_rejections": run_invalid_state_mutation_rejections,
		"last_state_mutation_result": run_last_state_mutation_result.duplicate(true),
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

	var restored_instances_result: Dictionary = _normalized_owned_item_instance_slots(
		state.get("run_owned_item_instances", []),
		restored_slots,
		maxi(int(state.get("next_run_owned_item_instance_id", FIRST_OWNED_ITEM_INSTANCE_ID)), FIRST_OWNED_ITEM_INSTANCE_ID),
		maxi(int(state.get("current_round", 0)), 0)
	)
	if not bool(restored_instances_result.get("valid", false)):
		return {
			"success": false,
			"reason": str(restored_instances_result.get(
				"reason",
				"invalid_owned_item_instance_state"
			)),
		}

	run_tray_slots = restored_slots
	run_owned_item_instances = _dictionary_array_slots(
		restored_instances_result.get("instances", [])
	)
	run_generation = maxi(int(state.get("run_generation", run_generation)), 0)
	build_generation = maxi(int(state.get("build_generation", build_generation)), 0)
	build_version = maxi(int(state.get("build_version", build_version)), 0)
	current_round = maxi(int(state.get("current_round", current_round)), 0)
	run_owned_item_state_version = maxi(int(state.get(
		"run_owned_item_state_version",
		run_owned_item_state_version
	)), 0)
	next_run_owned_item_instance_id = maxi(
		maxi(next_run_owned_item_instance_id, int(restored_instances_result.get(
			"next_owned_item_instance_id",
			FIRST_OWNED_ITEM_INSTANCE_ID
		))),
		maxi(int(state.get(
			"next_run_owned_item_instance_id",
			FIRST_OWNED_ITEM_INSTANCE_ID
		)), FIRST_OWNED_ITEM_INSTANCE_ID)
	)
	_restore_run_state_mutation_diagnostics(state)
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
	_clear_owned_item_instances(shot_lab_owned_item_instances)
	_reset_state_mutation_context(true, false)
	for slot_index in range(TRAY_CAPACITY):
		var item_id: String = shot_lab_tray_slots[slot_index]
		if item_id.is_empty():
			continue
		var definition: Dictionary = _get_catalog_definition(item_id)
		shot_lab_owned_item_instances[slot_index] = _create_owned_item_instance_for_context(
			definition,
			slot_index,
			0,
			true
		)
	shot_lab_session = true
	if not get_owned_eight_ball_ids().is_empty():
		_increment_active_owned_item_state_version()
	build_version += 1
	_clear_evaluation_diagnostics()
	_emit_build_changed()
	return {"success": true, "build_snapshot": get_build_snapshot()}


func clear_shot_lab_loadout(reason: String = "shot_lab_clear") -> void:
	_clear_slots(shot_lab_tray_slots)
	_clear_owned_item_instances(shot_lab_owned_item_instances)
	_reset_state_mutation_context(true, false)
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


func get_owned_item_state_snapshot() -> Dictionary:
	return _make_owned_item_state_snapshot(shot_lab_session)


func snapshot_pending_item_state_mutations(
	transaction_key: String,
	pending_mutations: Array
) -> Dictionary:
	var normalized_transaction_key: String = transaction_key.strip_edges()
	var state_before: Dictionary = get_owned_item_state_snapshot()
	if normalized_transaction_key.is_empty():
		return _state_mutation_failure(
			"missing_transaction_key",
			normalized_transaction_key,
			state_before
		)
	if _get_active_applied_state_mutation_keys().has(normalized_transaction_key):
		return {
			"success": true,
			"reason": "duplicate_transaction_key",
			"transaction_key": normalized_transaction_key,
			"applied": false,
			"duplicate_suppressed": true,
			"mutation_count": 0,
			"pending_state_mutations": [],
			"state_before": state_before,
			"simulated_state_after": state_before.duplicate(true),
		}

	var simulation: Dictionary = _simulate_pending_item_state_mutations(pending_mutations)
	if not bool(simulation.get("success", false)):
		return _state_mutation_failure(
			str(simulation.get("reason", "invalid_state_mutation")),
			normalized_transaction_key,
			state_before,
			int(simulation.get("mutation_index", -1))
		)
	var simulated_instances: Array[Dictionary] = _dictionary_array_slots(
		simulation.get("instances_after", [])
	)
	var state_after: Dictionary = _make_owned_item_state_snapshot(
		shot_lab_session,
		simulated_instances
	)
	return {
		"success": true,
		"reason": "",
		"transaction_key": normalized_transaction_key,
		"applied": false,
		"duplicate_suppressed": false,
		"mutation_count": int(simulation.get("mutation_count", 0)),
		"pending_state_mutations": _dictionary_array(
			simulation.get("normalized_mutations", [])
		),
		"state_before": state_before,
		"simulated_state_after": state_after,
		"instances_after": _duplicate_instance_slots(simulated_instances),
	}


func prepare_item_state_mutation_transaction(
	transaction_key: String,
	pending_mutations: Array
) -> Dictionary:
	return snapshot_pending_item_state_mutations(transaction_key, pending_mutations)


func apply_pending_item_state_mutations(
	transaction_key: String,
	pending_mutations: Array
) -> Dictionary:
	var normalized_transaction_key: String = transaction_key.strip_edges()
	if (
		not normalized_transaction_key.is_empty()
		and _get_active_applied_state_mutation_keys().has(normalized_transaction_key)
	):
		_increment_active_duplicate_state_mutation_suppressions()
		var duplicate_result: Dictionary = {
			"success": true,
			"reason": "duplicate_transaction_key",
			"transaction_key": normalized_transaction_key,
			"applied": false,
			"duplicate_suppressed": true,
			"mutation_count": 0,
			"state_before": get_owned_item_state_snapshot(),
			"state_after": get_owned_item_state_snapshot(),
		}
		_set_active_last_state_mutation_result(duplicate_result)
		_emit_diagnostics_changed()
		return duplicate_result.duplicate(true)

	var prepared: Dictionary = snapshot_pending_item_state_mutations(
		normalized_transaction_key,
		pending_mutations
	)
	if not bool(prepared.get("success", false)):
		_increment_active_invalid_state_mutation_rejections()
		_set_active_last_state_mutation_result(prepared)
		_emit_diagnostics_changed()
		return prepared.duplicate(true)

	var mutation_count: int = int(prepared.get("mutation_count", 0))
	if mutation_count <= 0:
		var no_op_result: Dictionary = prepared.duplicate(true)
		no_op_result["reason"] = "no_mutations"
		no_op_result["state_after"] = _dictionary_value(
			prepared,
			"simulated_state_after"
		).duplicate(true)
		_set_active_last_state_mutation_result(no_op_result)
		_emit_diagnostics_changed()
		return no_op_result

	var instances_after: Array[Dictionary] = _dictionary_array_slots(
		prepared.get("instances_after", [])
	)
	_set_active_owned_item_instances(instances_after)
	_mark_active_state_mutation_transaction_applied(normalized_transaction_key)
	_increment_active_state_mutation_application_counts(mutation_count)
	_increment_active_owned_item_state_version()
	build_version += 1

	var applied_result: Dictionary = prepared.duplicate(true)
	applied_result.erase("instances_after")
	applied_result["applied"] = true
	applied_result["reason"] = ""
	applied_result["state_after"] = get_owned_item_state_snapshot()
	applied_result["owned_item_state_version"] = _get_active_owned_item_state_version()
	_set_active_last_state_mutation_result(applied_result)
	_emit_build_changed()
	return applied_result.duplicate(true)


func apply_item_state_mutations_once(
	transaction_key: String,
	pending_mutations: Array
) -> Dictionary:
	return apply_pending_item_state_mutations(transaction_key, pending_mutations)


func apply_authoritative_state_mutations(
	mutations: Array,
	application_key: String
) -> Dictionary:
	var result: Dictionary = apply_pending_item_state_mutations(application_key, mutations)
	result["application_key"] = application_key.strip_edges()
	return result


func restore_owned_item_state_snapshot(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = _restore_owned_item_state_snapshot_for_context(
		snapshot,
		shot_lab_session,
		true
	)
	if bool(result.get("success", false)):
		_emit_build_changed()
	else:
		_increment_active_invalid_state_mutation_rejections()
		_emit_diagnostics_changed()
	return result


func capture_rewind_state() -> Dictionary:
	return {
		"state_version": BUILD_STATE_VERSION,
		"run_generation": run_generation,
		"build_generation": build_generation,
		"build_version": build_version,
		"current_round": current_round,
		"shot_lab_session": shot_lab_session,
		"run_item_state": _make_owned_item_state_snapshot(false),
		"shot_lab_item_state": _make_owned_item_state_snapshot(true),
	}


func get_rewind_state() -> Dictionary:
	return capture_rewind_state()


func restore_rewind_state(state: Dictionary) -> Dictionary:
	if int(state.get("run_generation", run_generation)) != run_generation:
		return {
			"success": false,
			"reason": "run_generation_mismatch",
		}
	var previous_run_state: Dictionary = _make_owned_item_state_snapshot(false)
	var previous_lab_state: Dictionary = _make_owned_item_state_snapshot(true)
	var run_restore: Dictionary = _restore_owned_item_state_snapshot_for_context(
		_dictionary_value(state, "run_item_state"),
		false,
		false
	)
	if not bool(run_restore.get("success", false)):
		return run_restore
	var lab_restore: Dictionary = _restore_owned_item_state_snapshot_for_context(
		_dictionary_value(state, "shot_lab_item_state"),
		true,
		false
	)
	if not bool(lab_restore.get("success", false)):
		_restore_owned_item_state_snapshot_for_context(previous_run_state, false, false)
		_restore_owned_item_state_snapshot_for_context(previous_lab_state, true, false)
		return lab_restore
	build_generation = maxi(int(state.get("build_generation", build_generation)), 0)
	build_version = maxi(int(state.get("build_version", build_version)), 0)
	current_round = maxi(int(state.get("current_round", current_round)), 0)
	shot_lab_session = bool(state.get("shot_lab_session", shot_lab_session))
	_emit_build_changed()
	return {
		"success": true,
		"reason": "",
		"build_snapshot": get_build_snapshot(),
	}


func evaluate_analyzed_ledger(
	analyzed_ledger: Dictionary,
	source: String = SOURCE_AUTHORITATIVE,
	emit_activation_signals: bool = false
) -> Dictionary:
	var trigger_occurrences: Array[Dictionary] = _evaluate_trigger_occurrences(analyzed_ledger)
	return _evaluate_build_effects(
		analyzed_ledger,
		trigger_occurrences,
		source,
		emit_activation_signals
	)


func record_authoritative_result(analyzed_ledger: Dictionary, emit_activation_signals: bool = true) -> Dictionary:
	return evaluate_analyzed_ledger(analyzed_ledger, SOURCE_AUTHORITATIVE, emit_activation_signals)


func record_predicted_result(analyzed_ledger: Dictionary) -> Dictionary:
	return evaluate_analyzed_ledger(analyzed_ledger, SOURCE_PREDICTED, false)


func evaluate_trigger_occurrences(
	trigger_occurrences: Array[Dictionary],
	source: String = SOURCE_AUTHORITATIVE,
	emit_activation_signals: bool = false
) -> Dictionary:
	return _evaluate_build_effects(
		{"source": "trigger_occurrence_evaluation"},
		trigger_occurrences,
		source,
		emit_activation_signals
	)


func _evaluate_build_effects(
	analyzed_ledger: Dictionary,
	trigger_occurrences: Array[Dictionary],
	source: String,
	emit_activation_signals: bool
) -> Dictionary:
	var evaluation: Dictionary = BUILD_EFFECT_EVALUATOR.evaluate(
		analyzed_ledger.duplicate(true),
		trigger_occurrences,
		get_build_snapshot(),
		source
	)
	_store_evaluation(source, evaluation)
	if emit_activation_signals:
		for event_value in evaluation.get("engine_events", []):
			if event_value is Dictionary:
				notify_modifier_activation(event_value as Dictionary)
		for activation in evaluation.get("modifier_context", []):
			if not activation is Dictionary:
				continue
			notify_modifier_activation(activation)
	_emit_diagnostics_changed()
	return evaluation.duplicate(true)


func build_modifier_context(analyzed_ledger: Dictionary) -> Array[Dictionary]:
	var trigger_occurrences: Array[Dictionary] = _evaluate_trigger_occurrences(analyzed_ledger)
	return build_modifier_context_from_trigger_occurrences(trigger_occurrences)


func build_modifier_context_from_trigger_occurrences(trigger_occurrences: Array[Dictionary]) -> Array[Dictionary]:
	var evaluation: Dictionary = BUILD_EFFECT_EVALUATOR.evaluate(
		{"source": "modifier_context"},
		trigger_occurrences,
		get_build_snapshot(),
		SOURCE_PREDICTED
	)
	return _dictionary_array(evaluation.get("modifier_context", []))


func build_modifier_context_excluding_item(
	analyzed_ledger: Dictionary,
	excluded_item_id: String
) -> Array[Dictionary]:
	var trigger_occurrences: Array[Dictionary] = _evaluate_trigger_occurrences(analyzed_ledger)
	var evaluation: Dictionary = BUILD_EFFECT_EVALUATOR.evaluate(
		analyzed_ledger.duplicate(true),
		trigger_occurrences,
		get_build_snapshot(),
		SOURCE_PREDICTED,
		excluded_item_id
	)
	return _dictionary_array(evaluation.get("modifier_context", []))


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
		"Catalog contains exactly thirty-two definitions",
		catalog_definitions.size() == 32,
		32,
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

	var state_subject: RogueliteBuildSystem = RogueliteBuildSystem.new()
	state_subject.begin_fresh_run(3)
	state_subject.begin_round(3)
	var first_instance_result: Dictionary = state_subject.acquire_eight_ball(crooked)
	var first_instance_id: int = int(first_instance_result.get("owned_item_instance_id", 0))
	var replaced_instance_result: Dictionary = state_subject.replace_eight_ball(0, twin_tribute)
	var second_instance_id: int = int(replaced_instance_result.get("owned_item_instance_id", 0))
	var reacquired_instance_result: Dictionary = state_subject.replace_eight_ball(0, crooked)
	var reacquired_instance_id: int = int(reacquired_instance_result.get(
		"owned_item_instance_id",
		0
	))
	_record_test(
		tests,
		"Owned item instance IDs are monotonic across replacement and reacquisition",
		[first_instance_id, second_instance_id, reacquired_instance_id] == [1, 2, 3],
		[1, 2, 3],
		[first_instance_id, second_instance_id, reacquired_instance_id]
	)
	var reacquired_instance: Dictionary = state_subject.get_owned_item_instance(
		reacquired_instance_id
	)
	_record_test(
		tests,
		"Reacquisition creates fresh state at the current round",
		int(reacquired_instance.get("acquired_round", -1)) == 3
			and not state_subject.get_owned_item_state(reacquired_instance_id).has("test_counter"),
		{"acquired_round": 3, "test_counter": false},
		{
			"acquired_round": int(reacquired_instance.get("acquired_round", -1)),
			"test_counter": state_subject.get_owned_item_state(
				reacquired_instance_id
			).has("test_counter"),
		}
	)

	var synthetic_initial_state: Dictionary = state_subject._make_initial_owned_item_state({
		"state_schema_version": 2,
		"state_defaults": {"charges": 3},
		"starting_value": 1.4,
		"state_value_key": "current_xmult",
		"effect_kind": "persistent_scaler",
	})
	_record_test(
		tests,
		"Definition fields initialize value-only owned state",
		int(synthetic_initial_state.get("state_version", 0)) == 2
			and int(synthetic_initial_state.get("charges", 0)) == 3
			and is_equal_approx(float(synthetic_initial_state.get("current_xmult", 0.0)), 1.4)
			and int(synthetic_initial_state.get("lifetime_growth_triggers", -1)) == 0
			and int(synthetic_initial_state.get("shots_activated", -1)) == 0,
		{"state_version": 2, "charges": 3, "current_xmult": 1.4},
		synthetic_initial_state
	)

	var mutation_one: Array = [{
		"owned_item_instance_id": reacquired_instance_id,
		"eight_ball_item_id": crooked,
		"state_before": state_subject.get_owned_item_state(reacquired_instance_id),
		"state_patch": {"test_counter": 1},
	}]
	var mutation_preview: Dictionary = state_subject.snapshot_pending_item_state_mutations(
		"attempt:1",
		mutation_one
	)
	_record_test(
		tests,
		"Pending mutation snapshots simulate without mutating live state",
		bool(mutation_preview.get("success", false))
			and not state_subject.get_owned_item_state(reacquired_instance_id).has("test_counter"),
		false,
		state_subject.get_owned_item_state(reacquired_instance_id).has("test_counter")
	)
	var mutation_applied: Dictionary = state_subject.apply_authoritative_state_mutations(
		mutation_one,
		"attempt:1"
	)
	_record_test(
		tests,
		"Authoritative mutation applies once",
		bool(mutation_applied.get("applied", false))
			and int(state_subject.get_owned_item_state(
				reacquired_instance_id
			).get("test_counter", 0)) == 1,
		1,
		int(state_subject.get_owned_item_state(reacquired_instance_id).get("test_counter", 0))
	)
	var duplicate_mutation: Dictionary = state_subject.apply_authoritative_state_mutations(
		[{
			"owned_item_instance_id": reacquired_instance_id,
			"state_patch": {"test_counter": 99},
		}],
		"attempt:1"
	)
	_record_test(
		tests,
		"Duplicate transaction keys are suppressed without reapplying state",
		bool(duplicate_mutation.get("duplicate_suppressed", false))
			and int(state_subject.get_owned_item_state(
				reacquired_instance_id
			).get("test_counter", 0)) == 1,
		1,
		int(state_subject.get_owned_item_state(reacquired_instance_id).get("test_counter", 0))
	)

	var invalid_atomic_result: Dictionary = state_subject.apply_authoritative_state_mutations(
		[
			{
				"owned_item_instance_id": reacquired_instance_id,
				"state_patch": {"test_counter": 7},
			},
			{
				"owned_item_instance_id": 9999,
				"state_patch": {"test_counter": 8},
			},
		],
		"attempt:invalid"
	)
	_record_test(
		tests,
		"Invalid mutation batches are atomic",
		not bool(invalid_atomic_result.get("success", true))
			and int(state_subject.get_owned_item_state(
				reacquired_instance_id
			).get("test_counter", 0)) == 1,
		1,
		int(state_subject.get_owned_item_state(reacquired_instance_id).get("test_counter", 0))
	)

	state_subject.begin_round(4)
	_record_test(
		tests,
		"Owned item state persists across rounds",
		int(state_subject.get_owned_item_state(
			reacquired_instance_id
		).get("test_counter", 0)) == 1,
		1,
		int(state_subject.get_owned_item_state(reacquired_instance_id).get("test_counter", 0))
	)
	var rewind_state: Dictionary = state_subject.get_rewind_state()
	var mutation_two: Array = [{
		"owned_item_instance_id": reacquired_instance_id,
		"state_before": state_subject.get_owned_item_state(reacquired_instance_id),
		"state_patch": {"test_counter": 2},
	}]
	state_subject.apply_authoritative_state_mutations(mutation_two, "attempt:2")
	var rewind_restore: Dictionary = state_subject.restore_rewind_state(rewind_state)
	var reapplied_after_rewind: Dictionary = state_subject.apply_authoritative_state_mutations(
		mutation_two,
		"attempt:2"
	)
	_record_test(
		tests,
		"Rewind restores state and transaction keys for one legitimate replay",
		bool(rewind_restore.get("success", false))
			and bool(reapplied_after_rewind.get("applied", false))
			and int(state_subject.get_owned_item_state(
				reacquired_instance_id
			).get("test_counter", 0)) == 2,
		2,
		int(state_subject.get_owned_item_state(reacquired_instance_id).get("test_counter", 0))
	)

	var saved_run_state: Dictionary = state_subject.get_run_state()
	var restored_subject: RogueliteBuildSystem = RogueliteBuildSystem.new()
	restored_subject.begin_fresh_run(3)
	var run_restore_result: Dictionary = restored_subject.restore_run_state(saved_run_state)
	_record_test(
		tests,
		"Run state round-trip preserves instances, state, and mutation keys",
		bool(run_restore_result.get("success", false))
			and int(restored_subject.get_owned_item_state(
				reacquired_instance_id
			).get("test_counter", 0)) == 2
			and bool(restored_subject.apply_authoritative_state_mutations(
				mutation_two,
				"attempt:2"
			).get("duplicate_suppressed", false)),
		{"test_counter": 2, "duplicate_suppressed": true},
		{
			"test_counter": int(restored_subject.get_owned_item_state(
				reacquired_instance_id
			).get("test_counter", 0)),
			"diagnostics": restored_subject.get_owned_item_state_snapshot(),
		}
	)

	var run_state_before_lab: Dictionary = state_subject.get_owned_item_state(
		reacquired_instance_id
	)
	state_subject.set_shot_lab_loadout([crooked])
	var lab_instance_id: int = int(state_subject.get_owned_item_instance_by_slot(0).get(
		"owned_item_instance_id",
		0
	))
	state_subject.apply_authoritative_state_mutations(
		[{
			"owned_item_instance_id": lab_instance_id,
			"state_patch": {"test_counter": 88},
		}],
		"shot_lab:attempt:1"
	)
	state_subject.set_shot_lab_session(false)
	_record_test(
		tests,
		"Shot Lab item state and transaction keys are isolated from the run",
		state_subject.get_owned_item_state(reacquired_instance_id) == run_state_before_lab
			and not state_subject.get_owned_item_state_snapshot().get(
				"applied_state_mutation_transaction_keys",
				[]
			).has("shot_lab:attempt:1"),
		run_state_before_lab,
		state_subject.get_owned_item_state(reacquired_instance_id)
	)

	state_subject.begin_fresh_run(4)
	var fresh_run_acquisition: Dictionary = state_subject.acquire_eight_ball(crooked)
	_record_test(
		tests,
		"Fresh runs clear state and restart the run-local instance allocator",
		int(fresh_run_acquisition.get("owned_item_instance_id", 0)) == 1
			and state_subject.get_owned_item_state_snapshot().get(
				"applied_state_mutation_transaction_keys",
				[]
			).is_empty(),
		1,
		int(fresh_run_acquisition.get("owned_item_instance_id", 0))
	)

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
	var predicted_state_after: Dictionary = _dictionary_value(
		predicted,
		"simulated_state_after"
	)
	var authoritative_state_after: Dictionary = _dictionary_value(
		authoritative,
		"simulated_state_after"
	)
	var activation_matches: bool = predicted_keys == authoritative_keys
	var state_matches: bool = predicted_state_after == authoritative_state_after
	var tap_count_matches: bool = int(predicted.get("tap_milestone_count", 0)) == int(
		authoritative.get("tap_milestone_count", 0)
	)
	var unusual_counts_match: bool = (
		_int_array(predicted.get("one_two_punch_qualifying_ball_ids", []))
		== _int_array(authoritative.get("one_two_punch_qualifying_ball_ids", []))
		and int(predicted.get("aftershock_activation_count", 0))
		== int(authoritative.get("aftershock_activation_count", 0))
		and int(predicted.get("echo_threshold_count", 0))
		== int(authoritative.get("echo_threshold_count", 0))
		and int(predicted.get("echo_retrigger_activation_count", 0))
		== int(authoritative.get("echo_retrigger_activation_count", 0))
	)
	return {
		"available": true,
		"matches": activation_matches and state_matches and tap_count_matches and unusual_counts_match,
		"activation_matches": activation_matches,
		"state_matches": state_matches,
		"tap_count_matches": tap_count_matches,
		"unusual_counts_match": unusual_counts_match,
		"predicted_activation_count": predicted_context.size(),
		"authoritative_activation_count": authoritative_context.size(),
		"predicted_activation_keys": predicted_keys,
		"authoritative_activation_keys": authoritative_keys,
		"predicted_state_after": predicted_state_after.duplicate(true),
		"authoritative_state_after": authoritative_state_after.duplicate(true),
		"predicted_tap_milestone_count": int(predicted.get("tap_milestone_count", 0)),
		"authoritative_tap_milestone_count": int(authoritative.get("tap_milestone_count", 0)),
		"predicted_one_two_punch_ball_ids": _int_array(
			predicted.get("one_two_punch_qualifying_ball_ids", [])
		),
		"authoritative_one_two_punch_ball_ids": _int_array(
			authoritative.get("one_two_punch_qualifying_ball_ids", [])
		),
		"predicted_aftershock_activation_count": int(predicted.get(
			"aftershock_activation_count",
			0
		)),
		"authoritative_aftershock_activation_count": int(authoritative.get(
			"aftershock_activation_count",
			0
		)),
		"predicted_echo_threshold_count": int(predicted.get("echo_threshold_count", 0)),
		"authoritative_echo_threshold_count": int(authoritative.get(
			"echo_threshold_count",
			0
		)),
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


func _get_active_owned_item_instances() -> Array[Dictionary]:
	return shot_lab_owned_item_instances if shot_lab_session else run_owned_item_instances


func _set_active_owned_item_instances(instances: Array[Dictionary]) -> void:
	var copied_instances: Array[Dictionary] = _duplicate_instance_slots(instances)
	if shot_lab_session:
		shot_lab_owned_item_instances = copied_instances
	else:
		run_owned_item_instances = copied_instances


func _get_active_owned_item_instance(tray_slot_index: int) -> Dictionary:
	var instances: Array[Dictionary] = _get_active_owned_item_instances()
	if tray_slot_index < 0 or tray_slot_index >= mini(instances.size(), TRAY_CAPACITY):
		return {}
	return instances[tray_slot_index]


func _set_active_owned_item_instance(tray_slot_index: int, instance: Dictionary) -> void:
	var instances: Array[Dictionary] = _get_active_owned_item_instances()
	if tray_slot_index < 0 or tray_slot_index >= mini(instances.size(), TRAY_CAPACITY):
		return
	instances[tray_slot_index] = instance.duplicate(true)


func _create_owned_item_instance(
	definition: Dictionary,
	tray_slot_index: int,
	acquired_round: int
) -> Dictionary:
	return _create_owned_item_instance_for_context(
		definition,
		tray_slot_index,
		acquired_round,
		shot_lab_session
	)


func _create_owned_item_instance_for_context(
	definition: Dictionary,
	tray_slot_index: int,
	acquired_round: int,
	for_shot_lab: bool
) -> Dictionary:
	var owned_item_instance_id: int = _allocate_owned_item_instance_id(for_shot_lab)
	var item_id: String = str(definition.get(
		"eight_ball_item_id",
		definition.get("id", "")
	))
	return {
		"slot_index": tray_slot_index,
		"tray_slot_index": tray_slot_index,
		"eight_ball_item_id": item_id,
		"owned_item_instance_id": owned_item_instance_id,
		"acquired_round": maxi(acquired_round, 0),
		"state": _make_initial_owned_item_state(definition),
	}


func _allocate_owned_item_instance_id(for_shot_lab: bool) -> int:
	var allocated_id: int = (
		next_shot_lab_owned_item_instance_id
		if for_shot_lab
		else next_run_owned_item_instance_id
	)
	allocated_id = maxi(allocated_id, FIRST_OWNED_ITEM_INSTANCE_ID)
	if for_shot_lab:
		next_shot_lab_owned_item_instance_id = allocated_id + 1
	else:
		next_run_owned_item_instance_id = allocated_id + 1
	return allocated_id


func _make_initial_owned_item_state(definition: Dictionary) -> Dictionary:
	var state_schema_version: int = maxi(int(definition.get(
		"state_schema_version",
		definition.get("owned_item_state_version", OWNED_ITEM_STATE_VERSION)
	)), OWNED_ITEM_STATE_VERSION)
	var state: Dictionary = {"state_version": state_schema_version}
	for field_name in ["state_defaults", "initial_state", "starting_state"]:
		var field_value: Variant = definition.get(field_name, {})
		if field_value is Dictionary and _is_value_only_variant(field_value):
			state.merge((field_value as Dictionary).duplicate(true), true)

	if definition.has("starting_value"):
		var default_value_key: String = (
			"current_xmult"
			if str(definition.get("application_phase", "")) == PHASE_XMULT
			else "current_value"
		)
		var state_value_key: String = str(definition.get(
			"state_value_key",
			default_value_key
		)).strip_edges()
		if not state_value_key.is_empty() and not state.has(state_value_key):
			var starting_value: Variant = definition.get("starting_value")
			if _is_value_only_variant(starting_value):
				state[state_value_key] = starting_value

	if str(definition.get("effect_kind", "")) == "persistent_scaler":
		if not state.has("lifetime_growth_triggers"):
			state["lifetime_growth_triggers"] = 0
		if not state.has("shots_activated"):
			state["shots_activated"] = 0
	state["state_version"] = state_schema_version
	return state


func _make_owned_item_state_snapshot(
	for_shot_lab: bool,
	instances_override: Array[Dictionary] = []
) -> Dictionary:
	var instances: Array[Dictionary] = (
		_duplicate_instance_slots(instances_override)
		if instances_override.size() == TRAY_CAPACITY
		else _duplicate_instance_slots(
			shot_lab_owned_item_instances if for_shot_lab else run_owned_item_instances
		)
	)
	var occupied_instances: Array[Dictionary] = []
	var item_states_by_instance_id: Dictionary = {}
	for instance in instances:
		if instance.is_empty():
			continue
		var copied_instance: Dictionary = instance.duplicate(true)
		occupied_instances.append(copied_instance)
		item_states_by_instance_id[str(int(instance.get(
			"owned_item_instance_id",
			0
		)))] = _dictionary_value(instance, "state").duplicate(true)
	var transaction_order: Array[String] = (
		shot_lab_applied_state_mutation_transaction_order
		if for_shot_lab
		else run_applied_state_mutation_transaction_order
	)
	return {
		"schema_version": BUILD_SCHEMA_VERSION,
		"state_version": BUILD_STATE_VERSION,
		"context": "shot_lab" if for_shot_lab else "run",
		"run_generation": run_generation,
		"build_generation": build_generation,
		"build_version": build_version,
		"current_round": 0 if for_shot_lab else current_round,
		"owned_item_state_version": (
			shot_lab_owned_item_state_version
			if for_shot_lab
			else run_owned_item_state_version
		),
		"next_owned_item_instance_id": (
			next_shot_lab_owned_item_instance_id
			if for_shot_lab
			else next_run_owned_item_instance_id
		),
		"owned_item_instances": occupied_instances,
		"instances_by_slot": instances,
		"item_states_by_instance_id": item_states_by_instance_id,
		"applied_state_mutation_transaction_keys": transaction_order.duplicate(),
		"state_mutation_transactions_applied": (
			shot_lab_state_mutation_transactions_applied
			if for_shot_lab
			else run_state_mutation_transactions_applied
		),
		"state_mutations_applied": (
			shot_lab_state_mutations_applied
			if for_shot_lab
			else run_state_mutations_applied
		),
		"duplicate_state_mutation_suppressions": (
			shot_lab_duplicate_state_mutation_suppressions
			if for_shot_lab
			else run_duplicate_state_mutation_suppressions
		),
		"invalid_state_mutation_rejections": (
			shot_lab_invalid_state_mutation_rejections
			if for_shot_lab
			else run_invalid_state_mutation_rejections
		),
		"last_state_mutation_result": (
			shot_lab_last_state_mutation_result.duplicate(true)
			if for_shot_lab
			else run_last_state_mutation_result.duplicate(true)
		),
	}


func _simulate_pending_item_state_mutations(pending_mutations: Array) -> Dictionary:
	var working_instances: Array[Dictionary] = _duplicate_instance_slots(
		_get_active_owned_item_instances()
	)
	var normalized_mutations: Array[Dictionary] = []
	for mutation_index in range(pending_mutations.size()):
		var mutation_value: Variant = pending_mutations[mutation_index]
		if not mutation_value is Dictionary:
			return _mutation_simulation_failure("mutation_not_dictionary", mutation_index)
		var mutation: Dictionary = mutation_value as Dictionary
		var owned_item_instance_id: int = int(mutation.get("owned_item_instance_id", 0))
		if owned_item_instance_id < FIRST_OWNED_ITEM_INSTANCE_ID:
			return _mutation_simulation_failure("missing_owned_item_instance_id", mutation_index)
		var slot_index: int = _find_instance_slot_index(
			working_instances,
			owned_item_instance_id
		)
		if slot_index < 0:
			return _mutation_simulation_failure("owned_item_instance_not_found", mutation_index)
		var instance: Dictionary = working_instances[slot_index]
		var item_id: String = str(instance.get("eight_ball_item_id", ""))
		var expected_item_id: String = str(mutation.get("eight_ball_item_id", item_id))
		if expected_item_id != item_id:
			return _mutation_simulation_failure("owned_item_identity_mismatch", mutation_index)
		if mutation.has("tray_slot_index") and int(mutation.get(
			"tray_slot_index",
			slot_index
		)) != slot_index:
			return _mutation_simulation_failure("owned_item_slot_mismatch", mutation_index)

		var state_before: Dictionary = _dictionary_value(instance, "state").duplicate(true)
		if mutation.has("state_before"):
			var expected_state_value: Variant = mutation.get("state_before")
			if not expected_state_value is Dictionary:
				return _mutation_simulation_failure("state_before_not_dictionary", mutation_index)
			if (expected_state_value as Dictionary) != state_before:
				return _mutation_simulation_failure("stale_item_state", mutation_index)
		if mutation.has("expected_state_version") and int(mutation.get(
			"expected_state_version",
			-1
		)) != int(state_before.get("state_version", OWNED_ITEM_STATE_VERSION)):
			return _mutation_simulation_failure("state_version_mismatch", mutation_index)

		var state_after_result: Dictionary = _resolve_state_after_mutation(
			state_before,
			mutation
		)
		if not bool(state_after_result.get("success", false)):
			return _mutation_simulation_failure(
				str(state_after_result.get("reason", "invalid_state_after")),
				mutation_index
			)
		var state_after: Dictionary = _dictionary_value(state_after_result, "state")
		if not _is_value_only_variant(state_after):
			return _mutation_simulation_failure("state_contains_object_reference", mutation_index)
		var updated_instance: Dictionary = instance.duplicate(true)
		updated_instance["state"] = state_after.duplicate(true)
		working_instances[slot_index] = updated_instance

		var normalized_mutation: Dictionary = {
			"mutation_index": mutation_index,
			"mutation_id": str(mutation.get("mutation_id", "mutation:%d" % mutation_index)),
			"owned_item_instance_id": owned_item_instance_id,
			"eight_ball_item_id": item_id,
			"tray_slot_index": slot_index,
			"state_before": state_before,
			"state_after": state_after.duplicate(true),
			"source": str(mutation.get("source", "authoritative")),
			"reason": str(mutation.get("reason", "")),
		}
		var metadata_value: Variant = mutation.get("metadata", {})
		if metadata_value is Dictionary and _is_value_only_variant(metadata_value):
			normalized_mutation["metadata"] = (metadata_value as Dictionary).duplicate(true)
		normalized_mutations.append(normalized_mutation)

	return {
		"success": true,
		"reason": "",
		"mutation_count": normalized_mutations.size(),
		"normalized_mutations": normalized_mutations,
		"instances_after": working_instances,
	}


func _resolve_state_after_mutation(state_before: Dictionary, mutation: Dictionary) -> Dictionary:
	var state_after: Dictionary = state_before.duplicate(true)
	var replacement_key: String = ""
	for candidate_key in ["state_after", "new_state"]:
		if mutation.has(candidate_key):
			replacement_key = candidate_key
			break
	if not replacement_key.is_empty():
		var replacement_value: Variant = mutation.get(replacement_key)
		if not replacement_value is Dictionary:
			return {"success": false, "reason": "state_after_not_dictionary"}
		state_after = (replacement_value as Dictionary).duplicate(true)
	else:
		var patch_key: String = ""
		for candidate_key in ["state_patch", "state_changes", "changes"]:
			if mutation.has(candidate_key):
				patch_key = candidate_key
				break
		if patch_key.is_empty():
			return {"success": false, "reason": "missing_state_after_or_patch"}
		var patch_value: Variant = mutation.get(patch_key)
		if not patch_value is Dictionary:
			return {"success": false, "reason": "state_patch_not_dictionary"}
		for key in (patch_value as Dictionary).keys():
			state_after[key] = (patch_value as Dictionary)[key]
	if not state_after.has("state_version"):
		state_after["state_version"] = int(state_before.get(
			"state_version",
			OWNED_ITEM_STATE_VERSION
		))
	if int(state_after.get("state_version", 0)) < OWNED_ITEM_STATE_VERSION:
		return {"success": false, "reason": "invalid_state_version"}
	return {"success": true, "reason": "", "state": state_after}


func _restore_owned_item_state_snapshot_for_context(
	snapshot: Dictionary,
	for_shot_lab: bool,
	restore_build_revision: bool
) -> Dictionary:
	if snapshot.is_empty():
		return {"success": false, "reason": "missing_item_state_snapshot"}
	var expected_context: String = "shot_lab" if for_shot_lab else "run"
	var snapshot_context: String = str(snapshot.get("context", expected_context))
	if snapshot_context != expected_context:
		return {"success": false, "reason": "item_state_context_mismatch"}
	if int(snapshot.get("run_generation", run_generation)) != run_generation:
		return {"success": false, "reason": "run_generation_mismatch"}
	if not snapshot.has("instances_by_slot"):
		return {"success": false, "reason": "missing_owned_item_instances"}

	var slots: Array[String] = shot_lab_tray_slots if for_shot_lab else run_tray_slots
	var restored_instances_result: Dictionary = _normalized_owned_item_instance_slots(
		snapshot.get("instances_by_slot", []),
		slots,
		maxi(int(snapshot.get(
			"next_owned_item_instance_id",
			FIRST_OWNED_ITEM_INSTANCE_ID
		)), FIRST_OWNED_ITEM_INSTANCE_ID),
		0 if for_shot_lab else current_round
	)
	if not bool(restored_instances_result.get("valid", false)):
		return {
			"success": false,
			"reason": str(restored_instances_result.get(
				"reason",
				"invalid_owned_item_instance_state"
			)),
		}
	var restored_instances: Array[Dictionary] = _dictionary_array_slots(
		restored_instances_result.get("instances", [])
	)
	if for_shot_lab:
		shot_lab_owned_item_instances = restored_instances
		shot_lab_owned_item_state_version = maxi(int(snapshot.get(
			"owned_item_state_version",
			shot_lab_owned_item_state_version
		)), 0)
		next_shot_lab_owned_item_instance_id = maxi(
			next_shot_lab_owned_item_instance_id,
			int(restored_instances_result.get(
				"next_owned_item_instance_id",
				FIRST_OWNED_ITEM_INSTANCE_ID
			))
		)
		_restore_context_state_mutation_diagnostics(snapshot, true)
	else:
		run_owned_item_instances = restored_instances
		run_owned_item_state_version = maxi(int(snapshot.get(
			"owned_item_state_version",
			run_owned_item_state_version
		)), 0)
		next_run_owned_item_instance_id = maxi(
			next_run_owned_item_instance_id,
			int(restored_instances_result.get(
				"next_owned_item_instance_id",
				FIRST_OWNED_ITEM_INSTANCE_ID
			))
		)
		current_round = maxi(int(snapshot.get("current_round", current_round)), 0)
		_restore_context_state_mutation_diagnostics(snapshot, false)
	if restore_build_revision:
		build_version = maxi(int(snapshot.get("build_version", build_version)), 0)
	return {
		"success": true,
		"reason": "",
		"context": expected_context,
		"owned_item_state_version": (
			shot_lab_owned_item_state_version
			if for_shot_lab
			else run_owned_item_state_version
		),
	}


func _normalized_owned_item_instance_slots(
	value: Variant,
	slots: Array[String],
	fallback_next_instance_id: int,
	fallback_acquired_round: int
) -> Dictionary:
	var normalized_instances: Array[Dictionary] = _make_empty_instance_slots()
	var values: Array = value as Array if value is Array else []
	var has_instance_payload: bool = false
	for entry in values:
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			has_instance_payload = true
			break

	var seen_instance_ids: Dictionary = {}
	var next_instance_id: int = maxi(
		fallback_next_instance_id,
		FIRST_OWNED_ITEM_INSTANCE_ID
	)
	if not has_instance_payload:
		for slot_index in range(TRAY_CAPACITY):
			var legacy_item_id: String = slots[slot_index]
			if legacy_item_id.is_empty():
				continue
			var legacy_definition: Dictionary = _get_catalog_definition(legacy_item_id)
			normalized_instances[slot_index] = {
				"slot_index": slot_index,
				"tray_slot_index": slot_index,
				"eight_ball_item_id": legacy_item_id,
				"owned_item_instance_id": next_instance_id,
				"acquired_round": maxi(fallback_acquired_round, 0),
				"state": _make_initial_owned_item_state(legacy_definition),
			}
			next_instance_id += 1
		return {
			"valid": true,
			"reason": "",
			"instances": normalized_instances,
			"next_owned_item_instance_id": next_instance_id,
			"legacy_instances_created": true,
		}

	for slot_index in range(TRAY_CAPACITY):
		var item_id: String = slots[slot_index]
		var raw_value: Variant = values[slot_index] if slot_index < values.size() else {}
		var raw_instance: Dictionary = (
			raw_value as Dictionary
			if raw_value is Dictionary
			else {}
		)
		if item_id.is_empty():
			if not raw_instance.is_empty():
				return {"valid": false, "reason": "owned_instance_in_empty_slot"}
			continue
		if raw_instance.is_empty():
			return {"valid": false, "reason": "missing_owned_item_instance"}
		if not _is_value_only_variant(raw_instance):
			return {"valid": false, "reason": "owned_instance_contains_object_reference"}
		var instance_item_id: String = str(raw_instance.get(
			"eight_ball_item_id",
			item_id
		))
		if instance_item_id != item_id:
			return {"valid": false, "reason": "owned_item_identity_mismatch"}
		var owned_item_instance_id: int = int(raw_instance.get(
			"owned_item_instance_id",
			0
		))
		if owned_item_instance_id < FIRST_OWNED_ITEM_INSTANCE_ID:
			return {"valid": false, "reason": "invalid_owned_item_instance_id"}
		if seen_instance_ids.has(owned_item_instance_id):
			return {"valid": false, "reason": "duplicate_owned_item_instance_id"}
		seen_instance_ids[owned_item_instance_id] = true

		var definition: Dictionary = _get_catalog_definition(item_id)
		var state_value: Variant = raw_instance.get(
			"state",
			_make_initial_owned_item_state(definition)
		)
		if not state_value is Dictionary:
			return {"valid": false, "reason": "owned_item_state_not_dictionary"}
		var item_state: Dictionary = (state_value as Dictionary).duplicate(true)
		if not item_state.has("state_version"):
			item_state["state_version"] = maxi(int(definition.get(
				"state_schema_version",
				OWNED_ITEM_STATE_VERSION
			)), OWNED_ITEM_STATE_VERSION)
		if int(item_state.get("state_version", 0)) < OWNED_ITEM_STATE_VERSION:
			return {"valid": false, "reason": "invalid_owned_item_state_version"}
		if not _is_value_only_variant(item_state):
			return {"valid": false, "reason": "owned_item_state_contains_object_reference"}

		var normalized_instance: Dictionary = raw_instance.duplicate(true)
		normalized_instance["slot_index"] = slot_index
		normalized_instance["tray_slot_index"] = slot_index
		normalized_instance["eight_ball_item_id"] = item_id
		normalized_instance["owned_item_instance_id"] = owned_item_instance_id
		normalized_instance["acquired_round"] = maxi(int(raw_instance.get(
			"acquired_round",
			fallback_acquired_round
		)), 0)
		normalized_instance["state"] = item_state
		normalized_instances[slot_index] = normalized_instance
		next_instance_id = maxi(next_instance_id, owned_item_instance_id + 1)

	return {
		"valid": true,
		"reason": "",
		"instances": normalized_instances,
		"next_owned_item_instance_id": next_instance_id,
		"legacy_instances_created": false,
	}


func _make_empty_instance_slots() -> Array[Dictionary]:
	var instances: Array[Dictionary] = []
	for _slot_index in range(TRAY_CAPACITY):
		instances.append({})
	return instances


func _duplicate_instance_slots(instances: Array[Dictionary]) -> Array[Dictionary]:
	var copied_instances: Array[Dictionary] = _make_empty_instance_slots()
	for slot_index in range(mini(instances.size(), TRAY_CAPACITY)):
		copied_instances[slot_index] = instances[slot_index].duplicate(true)
	return copied_instances


func _dictionary_array_slots(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = _make_empty_instance_slots()
	if not value is Array:
		return result
	var values: Array = value as Array
	for slot_index in range(mini(values.size(), TRAY_CAPACITY)):
		var entry: Variant = values[slot_index]
		if entry is Dictionary:
			result[slot_index] = (entry as Dictionary).duplicate(true)
	return result


func _clear_owned_item_instances(instances: Array[Dictionary]) -> void:
	for slot_index in range(mini(instances.size(), TRAY_CAPACITY)):
		instances[slot_index] = {}


func _find_instance_slot_index(
	instances: Array[Dictionary],
	owned_item_instance_id: int
) -> int:
	if owned_item_instance_id < FIRST_OWNED_ITEM_INSTANCE_ID:
		return -1
	for slot_index in range(mini(instances.size(), TRAY_CAPACITY)):
		if int(instances[slot_index].get("owned_item_instance_id", 0)) == owned_item_instance_id:
			return slot_index
	return -1


func _reset_state_mutation_context(for_shot_lab: bool, reset_allocator: bool) -> void:
	if for_shot_lab:
		shot_lab_owned_item_state_version = 0
		shot_lab_applied_state_mutation_transaction_keys.clear()
		shot_lab_applied_state_mutation_transaction_order.clear()
		shot_lab_state_mutation_transactions_applied = 0
		shot_lab_state_mutations_applied = 0
		shot_lab_duplicate_state_mutation_suppressions = 0
		shot_lab_invalid_state_mutation_rejections = 0
		shot_lab_last_state_mutation_result.clear()
		if reset_allocator:
			next_shot_lab_owned_item_instance_id = FIRST_OWNED_ITEM_INSTANCE_ID
		return
	run_owned_item_state_version = 0
	run_applied_state_mutation_transaction_keys.clear()
	run_applied_state_mutation_transaction_order.clear()
	run_state_mutation_transactions_applied = 0
	run_state_mutations_applied = 0
	run_duplicate_state_mutation_suppressions = 0
	run_invalid_state_mutation_rejections = 0
	run_last_state_mutation_result.clear()
	if reset_allocator:
		next_run_owned_item_instance_id = FIRST_OWNED_ITEM_INSTANCE_ID


func _get_active_owned_item_state_version() -> int:
	return (
		shot_lab_owned_item_state_version
		if shot_lab_session
		else run_owned_item_state_version
	)


func _increment_active_owned_item_state_version() -> void:
	if shot_lab_session:
		shot_lab_owned_item_state_version += 1
	else:
		run_owned_item_state_version += 1


func _get_active_next_owned_item_instance_id() -> int:
	return (
		next_shot_lab_owned_item_instance_id
		if shot_lab_session
		else next_run_owned_item_instance_id
	)


func _get_active_applied_state_mutation_keys() -> Dictionary:
	return (
		shot_lab_applied_state_mutation_transaction_keys
		if shot_lab_session
		else run_applied_state_mutation_transaction_keys
	)


func _mark_active_state_mutation_transaction_applied(transaction_key: String) -> void:
	if shot_lab_session:
		shot_lab_applied_state_mutation_transaction_keys[transaction_key] = true
		shot_lab_applied_state_mutation_transaction_order.append(transaction_key)
	else:
		run_applied_state_mutation_transaction_keys[transaction_key] = true
		run_applied_state_mutation_transaction_order.append(transaction_key)


func _increment_active_state_mutation_application_counts(mutation_count: int) -> void:
	if shot_lab_session:
		shot_lab_state_mutation_transactions_applied += 1
		shot_lab_state_mutations_applied += maxi(mutation_count, 0)
	else:
		run_state_mutation_transactions_applied += 1
		run_state_mutations_applied += maxi(mutation_count, 0)


func _increment_active_duplicate_state_mutation_suppressions() -> void:
	if shot_lab_session:
		shot_lab_duplicate_state_mutation_suppressions += 1
	else:
		run_duplicate_state_mutation_suppressions += 1


func _increment_active_invalid_state_mutation_rejections() -> void:
	if shot_lab_session:
		shot_lab_invalid_state_mutation_rejections += 1
	else:
		run_invalid_state_mutation_rejections += 1


func _set_active_last_state_mutation_result(result: Dictionary) -> void:
	var compact_result: Dictionary = _compact_state_mutation_result(result)
	if shot_lab_session:
		shot_lab_last_state_mutation_result = compact_result
	else:
		run_last_state_mutation_result = compact_result


func _compact_state_mutation_result(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	return {
		"success": bool(result.get("success", false)),
		"reason": str(result.get("reason", "")),
		"transaction_key": str(result.get("transaction_key", "")),
		"applied": bool(result.get("applied", false)),
		"duplicate_suppressed": bool(result.get("duplicate_suppressed", false)),
		"mutation_count": int(result.get("mutation_count", 0)),
		"mutation_index": int(result.get("mutation_index", -1)),
	}


func _get_active_state_mutation_diagnostics() -> Dictionary:
	var for_shot_lab: bool = shot_lab_session
	var transaction_order: Array[String] = (
		shot_lab_applied_state_mutation_transaction_order
		if for_shot_lab
		else run_applied_state_mutation_transaction_order
	)
	return {
		"context": "shot_lab" if for_shot_lab else "run",
		"owned_item_state_version": _get_active_owned_item_state_version(),
		"next_owned_item_instance_id": _get_active_next_owned_item_instance_id(),
		"applied_transaction_count": transaction_order.size(),
		"applied_transaction_keys": transaction_order.duplicate(),
		"state_mutation_transactions_applied": (
			shot_lab_state_mutation_transactions_applied
			if for_shot_lab
			else run_state_mutation_transactions_applied
		),
		"state_mutations_applied": (
			shot_lab_state_mutations_applied
			if for_shot_lab
			else run_state_mutations_applied
		),
		"duplicate_state_mutation_suppressions": (
			shot_lab_duplicate_state_mutation_suppressions
			if for_shot_lab
			else run_duplicate_state_mutation_suppressions
		),
		"invalid_state_mutation_rejections": (
			shot_lab_invalid_state_mutation_rejections
			if for_shot_lab
			else run_invalid_state_mutation_rejections
		),
		"last_result": (
			shot_lab_last_state_mutation_result.duplicate(true)
			if for_shot_lab
			else run_last_state_mutation_result.duplicate(true)
		),
	}


func _restore_run_state_mutation_diagnostics(state: Dictionary) -> void:
	_restore_context_state_mutation_diagnostics(state, false)


func _restore_context_state_mutation_diagnostics(
	state: Dictionary,
	for_shot_lab: bool
) -> void:
	var transaction_order: Array[String] = _normalized_transaction_key_array(
		state.get("applied_state_mutation_transaction_keys", [])
	)
	var transaction_keys: Dictionary = {}
	for transaction_key in transaction_order:
		transaction_keys[transaction_key] = true
	var last_result: Dictionary = _compact_state_mutation_result(_dictionary_value(
		state,
		"last_state_mutation_result"
	))
	if for_shot_lab:
		shot_lab_applied_state_mutation_transaction_order = transaction_order
		shot_lab_applied_state_mutation_transaction_keys = transaction_keys
		shot_lab_state_mutation_transactions_applied = maxi(int(state.get(
			"state_mutation_transactions_applied",
			transaction_order.size()
		)), 0)
		shot_lab_state_mutations_applied = maxi(int(state.get(
			"state_mutations_applied",
			0
		)), 0)
		shot_lab_duplicate_state_mutation_suppressions = maxi(int(state.get(
			"duplicate_state_mutation_suppressions",
			0
		)), 0)
		shot_lab_invalid_state_mutation_rejections = maxi(int(state.get(
			"invalid_state_mutation_rejections",
			0
		)), 0)
		shot_lab_last_state_mutation_result = last_result
		return
	run_applied_state_mutation_transaction_order = transaction_order
	run_applied_state_mutation_transaction_keys = transaction_keys
	run_state_mutation_transactions_applied = maxi(int(state.get(
		"state_mutation_transactions_applied",
		transaction_order.size()
	)), 0)
	run_state_mutations_applied = maxi(int(state.get("state_mutations_applied", 0)), 0)
	run_duplicate_state_mutation_suppressions = maxi(int(state.get(
		"duplicate_state_mutation_suppressions",
		0
	)), 0)
	run_invalid_state_mutation_rejections = maxi(int(state.get(
		"invalid_state_mutation_rejections",
		0
	)), 0)
	run_last_state_mutation_result = last_result


func _normalized_transaction_key_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	if not value is Array:
		return result
	for entry in value as Array:
		var transaction_key: String = str(entry).strip_edges()
		if transaction_key.is_empty() or seen.has(transaction_key):
			continue
		seen[transaction_key] = true
		result.append(transaction_key)
	return result


func _state_mutation_failure(
	reason: String,
	transaction_key: String,
	state_before: Dictionary,
	mutation_index: int = -1
) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"transaction_key": transaction_key,
		"applied": false,
		"duplicate_suppressed": false,
		"mutation_count": 0,
		"mutation_index": mutation_index,
		"pending_state_mutations": [],
		"state_before": state_before.duplicate(true),
		"simulated_state_after": state_before.duplicate(true),
	}


func _mutation_simulation_failure(reason: String, mutation_index: int) -> Dictionary:
	return {
		"success": false,
		"reason": reason,
		"mutation_index": mutation_index,
		"mutation_count": 0,
	}


func _is_value_only_variant(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if typeof(value) == TYPE_OBJECT or typeof(value) == TYPE_CALLABLE:
		return false
	if value is Array:
		for entry in value as Array:
			if not _is_value_only_variant(entry, depth + 1):
				return false
	elif value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_value_only_variant(key, depth + 1):
				return false
			if not _is_value_only_variant((value as Dictionary)[key], depth + 1):
				return false
	return true


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


func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for entry in value as Array:
			result.append(int(entry))
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
