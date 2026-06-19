extends Node
class_name CueProgressionSystem

signal cue_progression_changed(snapshot: Dictionary)
signal status_changed(text: String)

# Persistent cue unlock/loadout model. Effect IDs resolve to data-driven
# modifier snapshots; gameplay systems receive snapshots, not raw save data.
const SAVE_VERSION := 1

const SLOT_BODY := "body"
const SLOT_TIP := "tip"
const SLOT_GRIP := "grip"
const SLOT_FERRULE := "ferrule"
const SLOT_CHALK := "chalk"

const SLOT_ORDER := [
	SLOT_BODY,
	SLOT_TIP,
	SLOT_GRIP,
	SLOT_FERRULE,
	SLOT_CHALK,
]

const SLOT_LABELS := {
	SLOT_BODY: "Body",
	SLOT_TIP: "Tip",
	SLOT_GRIP: "Grip",
	SLOT_FERRULE: "Ferrule",
	SLOT_CHALK: "Chalk",
}

const DEFAULT_PART_BY_SLOT := {
	SLOT_BODY: "weathered_cue_body",
	SLOT_TIP: "plain_tip",
	SLOT_GRIP: "sailcloth_grip",
	SLOT_FERRULE: "plain_ferrule",
	SLOT_CHALK: "plain_chalk",
}

const EFFECT_NONE := "effect_none"
const EFFECT_LUCKY_CHALK := "effect_lucky_chalk"
const EFFECT_WAYFINDER_WRAP := "effect_wayfinder_wrap"
const EFFECT_BONE_FERRULE := "effect_bone_ferrule"
const EFFECT_BLACKWOOD_CUE := "effect_blackwood_cue"
const EFFECT_BRASS_TIP := "effect_brass_tip"
const MODIFIER_LOOSE_CARGO_CONTRABAND_CHANCE_BONUS := "loose_cargo_contraband_chance_bonus"
const MODIFIER_QUARTERMASTER_REFRESH_SHOT_DECAY_BONUS := "quartermaster_refresh_shot_decay_bonus"
const MODIFIER_OATH_PASSAGE_PENALTY_REDUCTION_FLAT := "oath_passage_penalty_reduction_flat"
const MODIFIER_PASSAGE_REQUEST_REWARD_MULTIPLIER_BONUS := "passage_request_reward_multiplier_bonus"
const MODIFIER_CUE_SHOT_POWER_MULTIPLIER_BONUS := "cue_shot_power_multiplier_bonus"

const EFFECT_DEFINITIONS := {
	EFFECT_NONE: {
		"id": EFFECT_NONE,
		"label": "No Active Effect",
		"description": "This cue part does not alter the run yet.",
		"modifiers": {},
		"tags": ["none"],
	},
	EFFECT_BLACKWOOD_CUE: {
		"id": EFFECT_BLACKWOOD_CUE,
		"label": "Blackwood Cue",
		"description": "Kraken Requests reduce Passage slightly more.",
		"modifiers": {
			MODIFIER_PASSAGE_REQUEST_REWARD_MULTIPLIER_BONUS: 0.10,
		},
		"tags": ["economy", "passage", "body"],
	},
	EFFECT_BRASS_TIP: {
		"id": EFFECT_BRASS_TIP,
		"label": "Brass Tip",
		"description": "Cue strikes launch slightly harder.",
		"modifiers": {
			MODIFIER_CUE_SHOT_POWER_MULTIPLIER_BONUS: 0.05,
		},
		"tags": ["shot_feel", "cue_power", "tip"],
	},
	EFFECT_WAYFINDER_WRAP: {
		"id": EFFECT_WAYFINDER_WRAP,
		"label": "Wayfinder Wrap",
		"description": "Quartermaster refresh costs cool down faster after each shot.",
		"modifiers": {
			MODIFIER_QUARTERMASTER_REFRESH_SHOT_DECAY_BONUS: 1,
		},
		"tags": ["economy", "quartermaster", "grip", "wayfinder"],
	},
	EFFECT_BONE_FERRULE: {
		"id": EFFECT_BONE_FERRULE,
		"label": "Bone Ferrule",
		"description": "Failed Oaths add less Passage.",
		"modifiers": {
			MODIFIER_OATH_PASSAGE_PENALTY_REDUCTION_FLAT: 25,
		},
		"tags": ["economy", "oath", "ferrule"],
	},
	EFFECT_LUCKY_CHALK: {
		"id": EFFECT_LUCKY_CHALK,
		"label": "Lucky Chalk",
		"description": "Slightly improves the chance that Loose Cargo contains contraband.",
		"modifiers": {
			MODIFIER_LOOSE_CARGO_CONTRABAND_CHANCE_BONUS: 0.01,
		},
		"tags": ["economy", "cargo", "chalk"],
	},
}

const PART_DEFINITIONS := [
	{
		"id": "weathered_cue_body",
		"slot_type": SLOT_BODY,
		"display_name": "Weathered Cue",
		"description": "A loyal cue worn smooth by old voyages.",
		"cost": 0,
		"unlocked_by_default": true,
		"effect_id": EFFECT_NONE,
		"tags": ["default"],
	},
	{
		"id": "blackwood_cue",
		"slot_type": SLOT_BODY,
		"display_name": "Blackwood Cue",
		"description": "Kraken Requests reduce Passage slightly more.",
		"cost": 3,
		"unlocked_by_default": false,
		"effect_id": EFFECT_BLACKWOOD_CUE,
		"tags": ["unlockable", "body"],
	},
	{
		"id": "plain_tip",
		"slot_type": SLOT_TIP,
		"display_name": "Plain Tip",
		"description": "A practical tip with no secrets yet.",
		"cost": 0,
		"unlocked_by_default": true,
		"effect_id": EFFECT_NONE,
		"tags": ["default"],
	},
	{
		"id": "brass_tip",
		"slot_type": SLOT_TIP,
		"display_name": "Brass Tip",
		"description": "Cue strikes launch slightly harder.",
		"cost": 2,
		"unlocked_by_default": false,
		"effect_id": EFFECT_BRASS_TIP,
		"tags": ["unlockable", "tip"],
	},
	{
		"id": "sailcloth_grip",
		"slot_type": SLOT_GRIP,
		"display_name": "Sailcloth Grip",
		"description": "A plain wrap cut from honest sailcloth.",
		"cost": 0,
		"unlocked_by_default": true,
		"effect_id": EFFECT_NONE,
		"tags": ["default"],
	},
	{
		"id": "wayfinder_wrap",
		"slot_type": SLOT_GRIP,
		"display_name": "Wayfinder Wrap",
		"description": "Quartermaster refresh costs cool down faster after each shot.",
		"cost": 2,
		"unlocked_by_default": false,
		"effect_id": EFFECT_WAYFINDER_WRAP,
		"tags": ["unlockable", "grip", "wayfinder"],
	},
	{
		"id": "plain_ferrule",
		"slot_type": SLOT_FERRULE,
		"display_name": "Plain Ferrule",
		"description": "A simple fitting that keeps its opinions to itself.",
		"cost": 0,
		"unlocked_by_default": true,
		"effect_id": EFFECT_NONE,
		"tags": ["default"],
	},
	{
		"id": "bone_ferrule",
		"slot_type": SLOT_FERRULE,
		"display_name": "Bone Ferrule",
		"description": "Failed Oaths add less Passage.",
		"cost": 2,
		"unlocked_by_default": false,
		"effect_id": EFFECT_BONE_FERRULE,
		"tags": ["unlockable", "ferrule"],
	},
	{
		"id": "plain_chalk",
		"slot_type": SLOT_CHALK,
		"display_name": "Plain Chalk",
		"description": "Dry, ordinary, and dependable.",
		"cost": 0,
		"unlocked_by_default": true,
		"effect_id": EFFECT_NONE,
		"tags": ["default"],
	},
	{
		"id": "lucky_chalk",
		"slot_type": SLOT_CHALK,
		"display_name": "Lucky Chalk",
		"description": "Slightly improves the chance that Loose Cargo contains contraband.",
		"cost": 1,
		"unlocked_by_default": false,
		"effect_id": EFFECT_LUCKY_CHALK,
		"tags": ["unlockable", "chalk"],
	},
]

var progression_system: ProgressionSystem
var unlocked_part_ids: Dictionary = {}
var equipped_by_slot: Dictionary = {}
var last_status_text := ""


func setup(progression_system_ref: ProgressionSystem) -> void:
	if progression_system != null and progression_system.progression_changed.is_connected(_on_progression_changed):
		progression_system.progression_changed.disconnect(_on_progression_changed)

	progression_system = progression_system_ref
	_initialize_state_from_save()
	if progression_system != null and not progression_system.progression_changed.is_connected(_on_progression_changed):
		progression_system.progression_changed.connect(_on_progression_changed)
	_emit_changed()


func get_cue_progression_snapshot() -> Dictionary:
	var favor_total := 0
	if progression_system != null:
		favor_total = int(progression_system.get_progression_snapshot().get("total_kraken_favor", 0))

	var equipped_loadout := _get_equipped_loadout_snapshot()
	var active_modifier_snapshot := get_active_cue_modifier_snapshot(true)
	return {
		"version": SAVE_VERSION,
		"kraken_favor": maxi(favor_total, 0),
		"unlocked_part_ids": _get_unlocked_part_id_list(),
		"equipped_by_slot": equipped_by_slot.duplicate(true),
		"equipped_loadout": equipped_loadout,
		"equipped_loadout_by_slot": _get_equipped_loadout_by_slot_snapshot(equipped_loadout),
		"active_modifiers": active_modifier_snapshot,
		"slots": _get_slot_snapshots(favor_total),
		"last_status_text": last_status_text,
	}


func get_equipped_loadout_snapshot() -> Dictionary:
	var equipped_loadout := _get_equipped_loadout_snapshot()
	return {
		"version": SAVE_VERSION,
		"equipped_by_slot": equipped_by_slot.duplicate(true),
		"equipped_loadout": equipped_loadout,
		"equipped_loadout_by_slot": _get_equipped_loadout_by_slot_snapshot(equipped_loadout),
	}


func get_active_cue_modifier_snapshot(modifiers_enabled: bool = true) -> Dictionary:
	var active_effects: Array = []
	var modifiers: Dictionary = {}
	for loadout_value in _get_equipped_loadout_snapshot():
		if not loadout_value is Dictionary:
			continue
		var loadout: Dictionary = loadout_value as Dictionary
		var effect_id := str(loadout.get("effect_id", EFFECT_NONE))
		var effect_definition := _get_effect_definition(effect_id)
		var effect_modifiers_value: Variant = effect_definition.get("modifiers", {})
		var effect_modifiers: Dictionary = {}
		if effect_modifiers_value is Dictionary:
			effect_modifiers = (effect_modifiers_value as Dictionary).duplicate(true)
		if effect_modifiers.is_empty():
			continue

		var effect_snapshot := effect_definition.duplicate(true)
		effect_snapshot["slot_type"] = str(loadout.get("slot_type", ""))
		effect_snapshot["slot_label"] = str(loadout.get("slot_label", ""))
		effect_snapshot["part_id"] = str(loadout.get("part_id", ""))
		effect_snapshot["part_name"] = str(loadout.get("display_name", ""))
		active_effects.append(effect_snapshot)
		if not modifiers_enabled:
			continue
		for modifier_key_value in effect_modifiers.keys():
			var modifier_key := str(modifier_key_value)
			var current_value := float(modifiers.get(modifier_key, 0.0))
			modifiers[modifier_key] = current_value + float(effect_modifiers.get(modifier_key_value, 0.0))

	return {
		"version": SAVE_VERSION,
		"modifiers_enabled": modifiers_enabled,
		"active_effects": active_effects,
		"active_effect_summary": _format_active_effect_summary(active_effects, modifiers_enabled),
		"modifiers": modifiers,
	}


func request_unlock_part(part_id: String) -> bool:
	var part := _get_part_definition(part_id)
	if part.is_empty():
		return _deny("Unknown cue part.")
	if _is_part_unlocked(part_id):
		last_status_text = "%s is already unlocked." % str(part.get("display_name", "Cue Part"))
		status_changed.emit(last_status_text)
		_emit_changed()
		return true
	if progression_system == null:
		return _deny("Cue Locker is not ready.")

	var cost := maxi(int(part.get("cost", 0)), 0)
	if not progression_system.can_afford_kraken_favor(cost):
		return _deny("Not enough Kraken Favor.")

	var previous_unlocked_part_ids := unlocked_part_ids.duplicate(true)
	unlocked_part_ids[part_id] = true
	if not progression_system.try_spend_kraken_favor_and_set_cue_progression(cost, get_save_payload(), "cue_unlock:%s" % part_id):
		unlocked_part_ids = previous_unlocked_part_ids
		return _deny("Could not spend Kraken Favor.")

	last_status_text = "Unlocked %s." % str(part.get("display_name", "Cue Part"))
	status_changed.emit(last_status_text)
	_emit_changed()
	return true


func request_equip_part(part_id: String) -> bool:
	var part := _get_part_definition(part_id)
	if part.is_empty():
		return _deny("Unknown cue part.")
	if not _is_part_unlocked(part_id):
		return _deny("Unlock this cue part first.")

	var slot_type := str(part.get("slot_type", ""))
	if not DEFAULT_PART_BY_SLOT.has(slot_type):
		return _deny("Cue part has no valid slot.")

	equipped_by_slot[slot_type] = part_id
	_save_state()
	last_status_text = "Equipped %s." % str(part.get("display_name", "Cue Part"))
	status_changed.emit(last_status_text)
	_emit_changed()
	return true


func get_save_payload() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"unlocked_part_ids": _get_unlocked_part_id_list(),
		"equipped_by_slot": equipped_by_slot.duplicate(true),
	}


func _initialize_state_from_save() -> void:
	unlocked_part_ids.clear()
	equipped_by_slot.clear()
	for part_value in PART_DEFINITIONS:
		var part: Dictionary = part_value
		if bool(part.get("unlocked_by_default", false)):
			unlocked_part_ids[str(part.get("id", ""))] = true
	for slot_type in SLOT_ORDER:
		equipped_by_slot[str(slot_type)] = str(DEFAULT_PART_BY_SLOT.get(slot_type, ""))

	var saved_data := {}
	if progression_system != null:
		saved_data = progression_system.get_cue_progression_data_snapshot()
	var unlocked_value: Variant = saved_data.get("unlocked_part_ids", [])
	if unlocked_value is Array:
		for part_id_value in unlocked_value:
			var part_id := str(part_id_value)
			if _has_part_definition(part_id):
				unlocked_part_ids[part_id] = true

	var equipped_value: Variant = saved_data.get("equipped_by_slot", {})
	if equipped_value is Dictionary:
		for slot_type_value in (equipped_value as Dictionary).keys():
			var slot_type := str(slot_type_value)
			var part_id := str((equipped_value as Dictionary).get(slot_type_value, ""))
			if _can_equip_saved_part(slot_type, part_id):
				equipped_by_slot[slot_type] = part_id

	for slot_type in SLOT_ORDER:
		var equipped_id := str(equipped_by_slot.get(slot_type, ""))
		if not _can_equip_saved_part(str(slot_type), equipped_id):
			equipped_by_slot[str(slot_type)] = str(DEFAULT_PART_BY_SLOT.get(slot_type, ""))
	_save_state()


func _save_state() -> bool:
	if progression_system == null:
		return false
	return progression_system.set_cue_progression_data(get_save_payload())


func _get_slot_snapshots(favor_total: int) -> Array:
	var slots: Array = []
	for slot_type_value in SLOT_ORDER:
		var slot_type := str(slot_type_value)
		slots.append({
			"slot_type": slot_type,
			"slot_label": str(SLOT_LABELS.get(slot_type, slot_type.capitalize())),
			"equipped_part_id": str(equipped_by_slot.get(slot_type, "")),
			"parts": _get_part_snapshots_for_slot(slot_type, favor_total),
		})
	return slots


func _get_part_snapshots_for_slot(slot_type: String, favor_total: int) -> Array:
	var parts: Array = []
	for part_value in PART_DEFINITIONS:
		var part: Dictionary = part_value
		if str(part.get("slot_type", "")) != slot_type:
			continue
		var part_id := str(part.get("id", ""))
		var cost := maxi(int(part.get("cost", 0)), 0)
		var unlocked := _is_part_unlocked(part_id)
		var equipped := str(equipped_by_slot.get(slot_type, "")) == part_id
		var snapshot := part.duplicate(true)
		snapshot["unlocked"] = unlocked
		snapshot["equipped"] = equipped
		snapshot["affordable"] = favor_total >= cost
		snapshot["slot_label"] = str(SLOT_LABELS.get(slot_type, slot_type.capitalize()))
		parts.append(snapshot)
	return parts


func _get_equipped_loadout_snapshot() -> Array:
	var loadout: Array = []
	for slot_type_value in SLOT_ORDER:
		var slot_type := str(slot_type_value)
		var part_id := str(equipped_by_slot.get(slot_type, DEFAULT_PART_BY_SLOT.get(slot_type, "")))
		var part := _get_part_definition(part_id)
		loadout.append({
			"slot_type": slot_type,
			"slot_label": str(SLOT_LABELS.get(slot_type, slot_type.capitalize())),
			"part_id": part_id,
			"display_name": str(part.get("display_name", part_id.capitalize())),
			"effect_id": str(part.get("effect_id", EFFECT_NONE)),
		})
	return loadout


func _get_equipped_loadout_by_slot_snapshot(loadout: Array) -> Dictionary:
	var by_slot: Dictionary = {}
	for loadout_value in loadout:
		if not loadout_value is Dictionary:
			continue
		var loadout_entry: Dictionary = loadout_value as Dictionary
		by_slot[str(loadout_entry.get("slot_type", ""))] = loadout_entry.duplicate(true)
	return by_slot


func _get_part_definition(part_id: String) -> Dictionary:
	for part_value in PART_DEFINITIONS:
		var part: Dictionary = part_value
		if str(part.get("id", "")) == part_id:
			return part.duplicate(true)
	return {}


func _get_effect_definition(effect_id: String) -> Dictionary:
	if EFFECT_DEFINITIONS.has(effect_id):
		return (EFFECT_DEFINITIONS[effect_id] as Dictionary).duplicate(true)
	return (EFFECT_DEFINITIONS[EFFECT_NONE] as Dictionary).duplicate(true)


func _format_active_effect_summary(active_effects: Array, modifiers_enabled: bool) -> String:
	if active_effects.is_empty():
		return "None"
	if not modifiers_enabled:
		return "Disabled"
	var labels: Array[String] = []
	for effect_value in active_effects:
		if not effect_value is Dictionary:
			continue
		var effect: Dictionary = effect_value as Dictionary
		labels.append(str(effect.get("label", "Cue Effect")))
	if labels.is_empty():
		return "None"
	return ", ".join(labels)


func _has_part_definition(part_id: String) -> bool:
	return not _get_part_definition(part_id).is_empty()


func _is_part_unlocked(part_id: String) -> bool:
	return bool(unlocked_part_ids.get(part_id, false))


func _can_equip_saved_part(slot_type: String, part_id: String) -> bool:
	var part := _get_part_definition(part_id)
	if part.is_empty():
		return false
	if str(part.get("slot_type", "")) != slot_type:
		return false
	return _is_part_unlocked(part_id)


func _get_unlocked_part_id_list() -> Array:
	var ids: Array = []
	for part_value in PART_DEFINITIONS:
		var part: Dictionary = part_value
		var part_id := str(part.get("id", ""))
		if _is_part_unlocked(part_id):
			ids.append(part_id)
	return ids


func _deny(reason: String) -> bool:
	last_status_text = reason
	status_changed.emit(reason)
	_emit_changed()
	return false


func _emit_changed() -> void:
	cue_progression_changed.emit(get_cue_progression_snapshot())


func _on_progression_changed(_snapshot: Dictionary) -> void:
	_emit_changed()
