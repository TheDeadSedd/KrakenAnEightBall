extends Node
class_name OathSystem

signal oaths_changed(snapshot: Dictionary)
signal oath_activated(oath_snapshot: Dictionary)
signal oath_completed(oath_snapshot: Dictionary)
signal oath_failed(oath_snapshot: Dictionary, penalty_text: String)
signal status_changed(text: String)

const OATH_OF_URGENCY := "OATH_OF_URGENCY"
const OATH_OF_ISOLATION := "OATH_OF_ISOLATION"
const OATH_OF_SACRIFICE := "OATH_OF_SACRIFICE"
const OATH_OF_HUMILITY := "OATH_OF_HUMILITY"

const PENALTY_PASSAGE := "passage"
const PENALTY_REMOVE_BALLS := "remove_balls"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"
const CUE_MODIFIER_OATH_PASSAGE_PENALTY_REDUCTION_FLAT := "oath_passage_penalty_reduction_flat"

const OATH_DEFINITIONS := {
	OATH_OF_URGENCY: {
		"id": OATH_OF_URGENCY,
		"label": "Oath of Urgency",
		"description": "Complete a Kraken Request within 3 shots.",
		"failure_condition": "Fail if no Kraken Request is completed before the shot limit expires.",
		"duration_shots": 3,
		"penalty": {
			"type": PENALTY_PASSAGE,
			"amount": 100,
		},
		"visible": true,
		"functional": true,
	},
	OATH_OF_ISOLATION: {
		"id": OATH_OF_ISOLATION,
		"label": "Oath of Isolation",
		"description": "Quartermaster is unavailable for 5 shots.",
		"failure_condition": "No failure condition. The oath completes when the shot counter expires.",
		"duration_shots": 5,
		"effects": {
			"quartermaster_locked": true,
		},
		"visible": true,
		"functional": true,
	},
	OATH_OF_SACRIFICE: {
		"id": OATH_OF_SACRIFICE,
		"label": "Oath of Sacrifice",
		"description": "If broken, lose 3 eligible balls from the table.",
		"failure_condition": "Future systems may break this oath. Debug/manual failure applies its penalty now.",
		"penalty": {
			"type": PENALTY_REMOVE_BALLS,
			"amount": 3,
		},
		"visible": true,
		"functional": true,
	},
	OATH_OF_HUMILITY: {
		"id": OATH_OF_HUMILITY,
		"label": "Oath of Humility",
		"description": "The Kraken demands skill without aid. Cue bonuses are disabled for 10 shots.",
		"failure_condition": "No failure condition. The oath completes when the shot counter expires.",
		"duration_shots": 10,
		"effects": {
			"cue_modifiers_suppressed": true,
		},
		"visible": true,
		"functional": true,
	},
}

var table: BilliardsTable
var active_oaths: Dictionary = {}
var completed_oaths_count := 0
var failed_oaths_count := 0
var activated_oaths_count := 0
var last_status_text := ""
var last_penalty_text := ""
var cue_modifier_snapshot: Dictionary = {}


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	active_oaths.clear()
	completed_oaths_count = 0
	failed_oaths_count = 0
	activated_oaths_count = 0
	last_status_text = ""
	last_penalty_text = ""
	_connect_event_sources()
	_emit_oaths_changed()


func get_available_oath_definitions(include_hidden: bool = false) -> Array:
	var definitions: Array = []
	for oath_id in OATH_DEFINITIONS.keys():
		var definition := _get_oath_definition(str(oath_id))
		if definition.is_empty():
			continue
		if not include_hidden and not bool(definition.get("visible", true)):
			continue
		definitions.append(definition)
	return definitions


func get_oath_choice_definition(oath_id: String, include_hidden: bool = false) -> Dictionary:
	var definition := _get_oath_definition(oath_id)
	if definition.is_empty():
		return {}
	if not include_hidden and not bool(definition.get("visible", true)):
		return {}

	var choice := definition.duplicate(true)
	choice["duration_text"] = _format_oath_duration_text(definition)
	choice["consequence_text"] = _format_oath_consequence_text(definition)
	return choice


func activate_oath(oath_id: String, allow_hidden: bool = false) -> bool:
	if not can_activate_oath(oath_id, allow_hidden):
		return false

	var definition := _get_oath_definition(oath_id)

	var oath_state := _make_active_oath_state(definition)
	active_oaths[oath_id] = oath_state
	activated_oaths_count += 1
	var snapshot := _make_oath_state_snapshot(oath_state)
	last_status_text = "%s sworn." % str(snapshot.get("label", "Oath"))
	oath_activated.emit(snapshot)
	status_changed.emit(last_status_text)
	_emit_oaths_changed()
	return true


func can_activate_oath(oath_id: String, allow_hidden: bool = false) -> bool:
	return _get_oath_activation_blocker(oath_id, allow_hidden).is_empty()


func get_oath_activation_blocker(oath_id: String, allow_hidden: bool = false) -> String:
	return _get_oath_activation_blocker(oath_id, allow_hidden)


func debug_activate_oath(oath_id: String) -> bool:
	return activate_oath(oath_id, true)


func debug_fail_oath(oath_id: String) -> bool:
	var target_oath_id := _get_debug_target_active_oath_id(oath_id)
	if target_oath_id.is_empty():
		return false
	_fail_active_oath(target_oath_id, "Debug failure")
	return true


func debug_complete_oath(oath_id: String = "") -> bool:
	var target_oath_id := _get_debug_target_active_oath_id(oath_id)
	if target_oath_id.is_empty():
		return false
	_complete_active_oath(target_oath_id, "Debug completion")
	return true


func debug_advance_oath_shot() -> bool:
	if active_oaths.is_empty():
		return false

	var advanced_any := false
	var oath_ids := active_oaths.keys().duplicate()
	for oath_id_value in oath_ids:
		var oath_id := str(oath_id_value)
		if not active_oaths.has(oath_id):
			continue
		_advance_oath_on_shot(oath_id)
		advanced_any = true
	_resolve_expired_oaths_after_shot()
	return advanced_any


func debug_clear_oaths() -> void:
	active_oaths.clear()
	last_status_text = "Oaths cleared."
	status_changed.emit(last_status_text)
	_emit_oaths_changed()


func set_cue_modifier_snapshot(snapshot: Dictionary) -> void:
	var next_snapshot := snapshot.duplicate(true)
	if cue_modifier_snapshot == next_snapshot:
		return
	cue_modifier_snapshot = next_snapshot
	_emit_oaths_changed()


func are_cue_modifiers_suppressed() -> bool:
	return active_oaths.has(OATH_OF_HUMILITY)


func get_cue_modifier_suppression_snapshot() -> Dictionary:
	if not are_cue_modifiers_suppressed():
		return {
			"suppressed": false,
			"label": "",
			"remaining_text": "",
			"reason": "",
		}

	var state: Dictionary = active_oaths.get(OATH_OF_HUMILITY, {})
	var oath_snapshot := _make_oath_state_snapshot(state)
	return {
		"suppressed": true,
		"oath_id": OATH_OF_HUMILITY,
		"label": str(oath_snapshot.get("label", "Oath of Humility")),
		"remaining_text": str(oath_snapshot.get("remaining_text", "")),
		"reason": "Cue bonuses are silenced by Oath of Humility.",
	}


func get_quartermaster_access_blocker() -> String:
	if not is_quartermaster_locked():
		return ""

	var state: Dictionary = active_oaths.get(OATH_OF_ISOLATION, {})
	var shots_remaining := maxi(int(state.get("shots_remaining", 0)), 0)
	var shot_text := "shot" if shots_remaining == 1 else "shots"
	return "Oath of Isolation: Quartermaster unavailable for %s %s." % [shots_remaining, shot_text]


func is_quartermaster_locked() -> bool:
	return active_oaths.has(OATH_OF_ISOLATION)


func get_oath_snapshot() -> Dictionary:
	var active_snapshots := _get_active_oath_snapshots()
	var penalty_modifier_snapshot := get_oath_passage_penalty_modifier_snapshot()
	var cue_suppression_snapshot := get_cue_modifier_suppression_snapshot()
	return {
		"available_oaths": get_available_oath_definitions(false),
		"active_oaths": active_snapshots,
		"active_oath_count": active_snapshots.size(),
		"active_oaths_summary": _format_active_oaths_summary(active_snapshots),
		"quartermaster_locked": is_quartermaster_locked(),
		"quartermaster_blocker": get_quartermaster_access_blocker(),
		"cue_modifiers_suppressed": bool(cue_suppression_snapshot.get("suppressed", false)),
		"cue_modifier_suppression": cue_suppression_snapshot,
		"completed_oaths_count": completed_oaths_count,
		"failed_oaths_count": failed_oaths_count,
		"activated_oaths_count": activated_oaths_count,
		"oath_passage_penalty_reduction_flat": int(penalty_modifier_snapshot.get("reduction_flat", 0)),
		"oath_passage_penalty_reduction_summary": str(penalty_modifier_snapshot.get("summary", "0")),
		"active_cue_modifiers_summary": str(penalty_modifier_snapshot.get("active_cue_modifiers_summary", "None")),
		"last_status_text": last_status_text,
		"last_penalty_text": last_penalty_text,
	}


func get_oath_passage_penalty_modifier_snapshot() -> Dictionary:
	var reduction := _get_oath_passage_penalty_reduction_flat()
	if not bool(cue_modifier_snapshot.get("modifiers_enabled", true)):
		return {
			"reduction_flat": reduction,
			"summary": "disabled",
			"active_cue_modifiers_summary": _get_active_cue_modifier_summary(),
		}
	return {
		"reduction_flat": reduction,
		"summary": str(reduction),
		"active_cue_modifiers_summary": _get_active_cue_modifier_summary(),
	}


func get_debug_snapshot() -> Dictionary:
	var snapshot := get_oath_snapshot()
	snapshot["all_oath_definitions"] = get_available_oath_definitions(true)
	return snapshot


func _connect_event_sources() -> void:
	if table == null:
		return
	if not table.shot_taken.is_connected(_on_shot_taken):
		table.shot_taken.connect(_on_shot_taken)
	if not table.shot_finished.is_connected(_on_shot_finished):
		table.shot_finished.connect(_on_shot_finished)
	if table.passage_system != null:
		if not table.passage_system.request_completed.is_connected(_on_kraken_request_completed):
			table.passage_system.request_completed.connect(_on_kraken_request_completed)


func _make_active_oath_state(definition: Dictionary) -> Dictionary:
	var oath_id := str(definition.get("id", ""))
	var current_request_id := ""
	var current_request_event_type := ""
	var current_request_label := ""
	if oath_id == OATH_OF_URGENCY and table != null and table.passage_system != null:
		var request_snapshot: Dictionary = table.passage_system.get_active_request_snapshot()
		current_request_id = str(request_snapshot.get("id", ""))
		current_request_event_type = str(request_snapshot.get("event_type", ""))
		current_request_label = str(request_snapshot.get("label", ""))

	var duration_shots := maxi(int(definition.get("duration_shots", 0)), 0)
	return {
		"id": oath_id,
		"status": STATUS_ACTIVE,
		"shots_remaining": duration_shots,
		"shots_elapsed": 0,
		"target_request_id": current_request_id,
		"target_request_event_type": current_request_event_type,
		"target_request_label": current_request_label,
		"definition": definition.duplicate(true),
	}


func _on_shot_taken(_count: int) -> void:
	var oath_ids := active_oaths.keys().duplicate()
	for oath_id_value in oath_ids:
		var oath_id := str(oath_id_value)
		if not active_oaths.has(oath_id):
			continue
		_advance_oath_on_shot(oath_id)


func _on_shot_finished(_count: int) -> void:
	_resolve_expired_oaths_after_shot()


func _advance_oath_on_shot(oath_id: String) -> void:
	var state: Dictionary = active_oaths.get(oath_id, {})
	if state.is_empty():
		return

	state["shots_elapsed"] = maxi(int(state.get("shots_elapsed", 0)), 0) + 1
	match oath_id:
		OATH_OF_URGENCY:
			var urgency_remaining := maxi(int(state.get("shots_remaining", 0)), 0)
			if urgency_remaining <= 0:
				_fail_active_oath(oath_id, "Request not completed in time")
				return
			state["shots_remaining"] = urgency_remaining - 1
			active_oaths[oath_id] = state
			_emit_oaths_changed()
		OATH_OF_ISOLATION:
			var isolation_remaining := maxi(int(state.get("shots_remaining", 0)), 0)
			state["shots_remaining"] = maxi(isolation_remaining - 1, 0)
			active_oaths[oath_id] = state
			if int(state["shots_remaining"]) <= 0:
				_complete_active_oath(oath_id, "Shot counter expired")
			else:
				_emit_oaths_changed()
		OATH_OF_HUMILITY:
			var humility_remaining := maxi(int(state.get("shots_remaining", 0)), 0)
			state["shots_remaining"] = maxi(humility_remaining - 1, 0)
			active_oaths[oath_id] = state
			if int(state["shots_remaining"]) <= 0:
				_complete_active_oath(oath_id, "Shot counter expired")
			else:
				_emit_oaths_changed()
		_:
			active_oaths[oath_id] = state
			_emit_oaths_changed()


func _resolve_expired_oaths_after_shot() -> void:
	if not active_oaths.has(OATH_OF_URGENCY):
		return

	var state: Dictionary = active_oaths.get(OATH_OF_URGENCY, {})
	if maxi(int(state.get("shots_remaining", 0)), 0) <= 0:
		_fail_active_oath(OATH_OF_URGENCY, "Request not completed in time")


func _on_kraken_request_completed(_request_snapshot: Dictionary, _reward: int) -> void:
	if not active_oaths.has(OATH_OF_URGENCY):
		return

	_complete_active_oath(OATH_OF_URGENCY, "Kraken Request completed")


func _complete_active_oath(oath_id: String, reason: String = "") -> void:
	if not active_oaths.has(oath_id):
		return

	var state: Dictionary = active_oaths[oath_id]
	state["status"] = STATUS_COMPLETED
	state["completion_reason"] = reason
	completed_oaths_count += 1
	var snapshot := _make_oath_state_snapshot(state)
	active_oaths.erase(oath_id)
	last_status_text = "%s fulfilled." % str(snapshot.get("label", "Oath"))
	oath_completed.emit(snapshot)
	status_changed.emit(last_status_text)
	_emit_oaths_changed()


func _fail_active_oath(oath_id: String, reason: String = "") -> void:
	if not active_oaths.has(oath_id):
		return

	var state: Dictionary = active_oaths[oath_id]
	state["status"] = STATUS_FAILED
	state["failure_reason"] = reason
	var penalty_text := _apply_oath_penalty(state)
	failed_oaths_count += 1
	var snapshot := _make_oath_state_snapshot(state)
	active_oaths.erase(oath_id)
	last_status_text = "%s broken. %s" % [str(snapshot.get("label", "Oath")), penalty_text]
	last_penalty_text = penalty_text
	oath_failed.emit(snapshot, penalty_text)
	status_changed.emit(last_status_text)
	_emit_oaths_changed()


func _apply_oath_penalty(state: Dictionary) -> String:
	var definition: Dictionary = state.get("definition", {})
	var penalty: Dictionary = definition.get("penalty", {})
	var penalty_type := str(penalty.get("type", ""))
	var amount := maxi(int(penalty.get("amount", 0)), 0)
	if amount <= 0 or penalty_type.is_empty():
		return "No penalty applied."

	match penalty_type:
		PENALTY_PASSAGE:
			if table != null and table.passage_system != null and table.passage_system.has_method("add_passage_pressure"):
				var passage_amount := _get_effective_passage_penalty_amount(amount)
				if passage_amount > 0:
					table.passage_system.add_passage_pressure(passage_amount)
				return "Passage +%s." % passage_amount
			return "Passage penalty unavailable."
		PENALTY_REMOVE_BALLS:
			if table != null and table.has_method("remove_oath_penalty_object_balls"):
				var removed_count: int = table.remove_oath_penalty_object_balls(amount)
				return "%s eligible balls lost." % removed_count
			return "Ball removal penalty unavailable."
	return "Unknown penalty."


func _get_active_oath_snapshots() -> Array:
	var snapshots: Array = []
	for oath_id_value in active_oaths.keys():
		var oath_id := str(oath_id_value)
		var state: Dictionary = active_oaths.get(oath_id, {})
		if state.is_empty():
			continue
		snapshots.append(_make_oath_state_snapshot(state))
	return snapshots


func _make_oath_state_snapshot(state: Dictionary) -> Dictionary:
	var definition: Dictionary = state.get("definition", {})
	var snapshot := definition.duplicate(true)
	snapshot["status"] = str(state.get("status", STATUS_ACTIVE))
	snapshot["shots_remaining"] = maxi(int(state.get("shots_remaining", 0)), 0)
	snapshot["shots_elapsed"] = maxi(int(state.get("shots_elapsed", 0)), 0)
	snapshot["target_request_id"] = str(state.get("target_request_id", ""))
	snapshot["target_request_event_type"] = str(state.get("target_request_event_type", ""))
	snapshot["target_request_label"] = str(state.get("target_request_label", ""))
	snapshot["failure_reason"] = str(state.get("failure_reason", ""))
	snapshot["completion_reason"] = str(state.get("completion_reason", ""))
	snapshot["remaining_text"] = _format_oath_remaining_text(snapshot)
	snapshot["penalty_text"] = _format_oath_penalty_text(definition)
	return snapshot


func _format_active_oaths_summary(active_snapshots: Array) -> String:
	if active_snapshots.is_empty():
		return "None sworn."

	var lines: Array = []
	for oath_value in active_snapshots:
		if not oath_value is Dictionary:
			continue
		var oath: Dictionary = oath_value
		var label := str(oath.get("label", "Oath"))
		var shots_remaining := maxi(int(oath.get("shots_remaining", 0)), 0)
		if shots_remaining > 0:
			var shot_text := "shot" if shots_remaining == 1 else "shots"
			lines.append("%s - %s %s" % [label, shots_remaining, shot_text])
		else:
			lines.append("%s - active" % label)
	return "\n".join(lines)


func _format_oath_remaining_text(snapshot: Dictionary) -> String:
	var status := str(snapshot.get("status", STATUS_ACTIVE))
	match status:
		STATUS_COMPLETED:
			return "Fulfilled"
		STATUS_FAILED:
			return "Broken"

	var shots_remaining := maxi(int(snapshot.get("shots_remaining", 0)), 0)
	if shots_remaining > 0:
		var shot_text := "shot" if shots_remaining == 1 else "shots"
		return "%s %s" % [shots_remaining, shot_text]
	if maxi(int(snapshot.get("duration_shots", 0)), 0) > 0:
		return "0 shots"
	return "Active"


func _format_oath_penalty_text(definition: Dictionary) -> String:
	var penalty: Dictionary = definition.get("penalty", {})
	var penalty_type := str(penalty.get("type", ""))
	var amount := maxi(int(penalty.get("amount", 0)), 0)
	if amount <= 0 or penalty_type.is_empty():
		return "No first-pass penalty."

	match penalty_type:
		PENALTY_PASSAGE:
			return "+%s Passage" % _get_effective_passage_penalty_amount(amount)
		PENALTY_REMOVE_BALLS:
			return "Lose %s eligible balls" % amount
	return "Unknown penalty"


func _format_oath_duration_text(definition: Dictionary) -> String:
	var shots := maxi(int(definition.get("duration_shots", 0)), 0)
	if shots > 0:
		var shot_text := "shot" if shots == 1 else "shots"
		return "Duration: %s %s" % [shots, shot_text]
	var failure_condition := str(definition.get("failure_condition", ""))
	if not failure_condition.is_empty():
		return "Condition-bound"
	return "Duration: Immediate"


func _format_oath_consequence_text(definition: Dictionary) -> String:
	var penalty: Dictionary = definition.get("penalty", {})
	if not penalty.is_empty():
		return "Failure: %s" % _format_oath_penalty_text(definition)

	var effects: Dictionary = definition.get("effects", {})
	if bool(effects.get("quartermaster_locked", false)):
		return "Restriction: Quartermaster unavailable"
	if bool(effects.get("cue_modifiers_suppressed", false)):
		return "Restriction: Cue bonuses silenced"
	return "Restriction: None"


func _get_effective_passage_penalty_amount(base_amount: int) -> int:
	return maxi(maxi(base_amount, 0) - _get_oath_passage_penalty_reduction_flat(), 0)


func _get_oath_passage_penalty_reduction_flat() -> int:
	return maxi(roundi(_get_cue_modifier_value(CUE_MODIFIER_OATH_PASSAGE_PENALTY_REDUCTION_FLAT, 0.0)), 0)


func _get_cue_modifier_value(modifier_key: String, fallback: float = 0.0) -> float:
	if not bool(cue_modifier_snapshot.get("modifiers_enabled", true)):
		return fallback
	var modifiers_value: Variant = cue_modifier_snapshot.get("modifiers", {})
	if not modifiers_value is Dictionary:
		return fallback
	var modifiers: Dictionary = modifiers_value as Dictionary
	return float(modifiers.get(modifier_key, fallback))


func _get_active_cue_modifier_summary() -> String:
	var summary := str(cue_modifier_snapshot.get("active_effect_summary", "None"))
	return "None" if summary.is_empty() else summary


func _get_oath_definition(oath_id: String) -> Dictionary:
	if not OATH_DEFINITIONS.has(oath_id):
		return {}
	return (OATH_DEFINITIONS[oath_id] as Dictionary).duplicate(true)


func _get_oath_activation_blocker(oath_id: String, allow_hidden: bool = false) -> String:
	var definition := _get_oath_definition(oath_id)
	if definition.is_empty():
		return "Unknown Oath"
	if active_oaths.has(oath_id):
		return "%s already active" % str(definition.get("label", "Oath"))
	if not allow_hidden and not bool(definition.get("visible", true)):
		return "%s is not available yet" % str(definition.get("label", "Oath"))
	return ""


func _get_debug_target_active_oath_id(preferred_oath_id: String = "") -> String:
	var preferred := str(preferred_oath_id)
	if not preferred.is_empty() and active_oaths.has(preferred):
		return preferred
	for oath_id_value in active_oaths.keys():
		var oath_id := str(oath_id_value)
		if active_oaths.has(oath_id):
			return oath_id
	return ""


func _emit_oaths_changed() -> void:
	oaths_changed.emit(get_oath_snapshot())
