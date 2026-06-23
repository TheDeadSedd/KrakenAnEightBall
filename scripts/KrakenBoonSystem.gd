extends Node
class_name KrakenBoonSystem

signal boons_changed(snapshot: Dictionary)
signal boon_activated(boon_id: String)
signal boon_expired(boon_id: String)

const BOON_LONG_SIGHT := "long_sight"
const BOON_KRAKENS_PATIENCE := "krakens_patience"
const BOON_DEEP_LEDGER := "deep_ledger"
const BOON_IRON_WAKE := "iron_wake"
const EFFECT_AIM_PREVIEW_LONG_SIGHT_ENABLED := "aim_preview_long_sight_enabled"
const EFFECT_AIM_PREVIEW_CHAIN_DEPTH := "aim_preview_chain_depth"
const EFFECT_INTERVENTION_PARTIAL_PROGRESS_CARRY_ENABLED := "intervention_partial_progress_carry_enabled"
const EFFECT_INTERVENTION_METER_GAIN_MULTIPLIER := "intervention_meter_gain_multiplier"
const EFFECT_CUE_BALL_CANNON_WAKE_ENABLED := "cue_ball_cannon_wake_enabled"
const EFFECT_CUE_BALL_CANNON_WAKE_IMPACT_MULTIPLIER := "cue_ball_cannon_wake_impact_multiplier"
const EFFECT_CUE_BALL_CANNON_WAKE_CUE_RETENTION := "cue_ball_cannon_wake_cue_retention"
const LONG_SIGHT_CHAIN_DEPTH := 5

const BOON_DEFINITIONS := {
	BOON_LONG_SIGHT: {
		"id": BOON_LONG_SIGHT,
		"type": "boon",
		"name": "Long Sight",
		"description": "The Kraken shows a short predictive chain of future hit-ball paths for 5 shots.",
		"flavor": "A longer shadow falls from the cue.",
		"icon_key": "wayfinder_ball",
		"rarity": "Uncommon",
		"weight": 4,
		"charge_cost": 1,
		"doubloon_cost": 60,
		"duration_shots": 5,
		"effects": {
			EFFECT_AIM_PREVIEW_LONG_SIGHT_ENABLED: true,
			EFFECT_AIM_PREVIEW_CHAIN_DEPTH: LONG_SIGHT_CHAIN_DEPTH,
		},
	},
	BOON_KRAKENS_PATIENCE: {
		"id": BOON_KRAKENS_PATIENCE,
		"type": "boon",
		"name": "Kraken's Patience",
		"description": "The Kraken lets unfinished bargains linger. Partial Intervention meter progress carries between shots for 3 shots.",
		"flavor": "The ledger refuses to close.",
		"icon_key": "wayfinder_ball",
		"rarity": "Uncommon",
		"weight": 3,
		"charge_cost": 2,
		"doubloon_cost": 100,
		"duration_shots": 3,
		"effects": {
			EFFECT_INTERVENTION_PARTIAL_PROGRESS_CARRY_ENABLED: true,
		},
	},
	BOON_DEEP_LEDGER: {
		"id": BOON_DEEP_LEDGER,
		"type": "boon",
		"name": "Deep Ledger",
		"description": "The Kraken counts your coin twice in the deep. Doubloons earned fill the Intervention meter 50% faster for 3 shots.",
		"flavor": "The ledger writes larger numbers than your purse receives.",
		"icon_key": "wayfinder_ball",
		"rarity": "Uncommon",
		"weight": 3,
		"charge_cost": 1,
		"doubloon_cost": 80,
		"duration_shots": 3,
		"effects": {
			EFFECT_INTERVENTION_METER_GAIN_MULTIPLIER: 1.5,
		},
	},
	BOON_IRON_WAKE: {
		"id": BOON_IRON_WAKE,
		"type": "boon",
		"name": "Iron Wake",
		"description": "The Kraken lends the cue ball an iron wake. Cue-ball impacts strike harder for 3 shots.",
		"flavor": "Iron sleeps behind the white ball.",
		"icon_key": "cannon_ball",
		"rarity": "Uncommon",
		"weight": 3,
		"charge_cost": 2,
		"doubloon_cost": 125,
		"duration_shots": 3,
		"effects": {
			EFFECT_CUE_BALL_CANNON_WAKE_ENABLED: true,
			EFFECT_CUE_BALL_CANNON_WAKE_IMPACT_MULTIPLIER: 1.35,
			EFFECT_CUE_BALL_CANNON_WAKE_CUE_RETENTION: 0.22,
		},
	},
}

var table: BilliardsTable
var active_boons: Dictionary = {}
var activations_total := 0
var refreshes_total := 0
var expirations_total := 0
var last_activated_boon_id := ""
var last_expired_boon_id := ""


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	if table != null and not table.shot_finished.is_connected(_on_shot_finished):
		table.shot_finished.connect(_on_shot_finished)
	_emit_boons_changed()


func get_boon_definition(boon_id: String) -> Dictionary:
	if not BOON_DEFINITIONS.has(boon_id):
		return {}
	var definition: Dictionary = BOON_DEFINITIONS[boon_id] as Dictionary
	return definition.duplicate(true)


func has_boon_definition(boon_id: String) -> bool:
	return BOON_DEFINITIONS.has(boon_id)


func is_boon_active(boon_id: String) -> bool:
	return active_boons.has(boon_id)


func get_active_boon_remaining_shots(boon_id: String) -> int:
	if not active_boons.has(boon_id):
		return 0
	var state: Dictionary = active_boons[boon_id] as Dictionary
	return maxi(int(state.get("remaining_shots", 0)), 0)


func get_boon_activation_blocker(boon_id: String) -> String:
	if boon_id.is_empty():
		return "Unknown boon"
	if not has_boon_definition(boon_id):
		return "Unknown boon"
	return ""


func activate_boon(boon_id: String) -> bool:
	var blocker := get_boon_activation_blocker(boon_id)
	if not blocker.is_empty():
		return false

	var was_active := active_boons.has(boon_id)
	active_boons[boon_id] = _make_active_boon_state(boon_id)
	activations_total += 1
	if was_active:
		refreshes_total += 1
	last_activated_boon_id = boon_id
	boon_activated.emit(boon_id)
	_emit_boons_changed()
	return true


func get_active_effects_snapshot() -> Dictionary:
	var effects: Dictionary = {}
	for boon_id_value in active_boons.keys():
		var boon_id := str(boon_id_value)
		var definition := get_boon_definition(boon_id)
		var effect_values: Variant = definition.get("effects", {})
		if not effect_values is Dictionary:
			continue
		var boon_effects: Dictionary = effect_values as Dictionary
		for effect_key_value in boon_effects.keys():
			var effect_key := str(effect_key_value)
			if effect_key.is_empty():
				continue
			effects[effect_key] = boon_effects[effect_key]
	return effects


func get_boon_snapshot() -> Dictionary:
	var active_entries: Array = []
	for boon_id_value in active_boons.keys():
		var boon_id := str(boon_id_value)
		var state: Dictionary = active_boons[boon_id] as Dictionary
		var definition := get_boon_definition(boon_id)
		active_entries.append({
			"id": boon_id,
			"name": str(definition.get("name", boon_id.capitalize())),
			"remaining_shots": maxi(int(state.get("remaining_shots", 0)), 0),
			"duration_shots": maxi(int(definition.get("duration_shots", 0)), 0),
			"description": str(definition.get("description", "")),
			"effects": _get_boon_effects_snapshot(boon_id),
		})
	return {
		"active_boons": active_entries,
		"active_boon_count": active_entries.size(),
		"active_boons_summary": _get_active_boons_summary(active_entries),
		"active_effects": get_active_effects_snapshot(),
		"activations_total": activations_total,
		"refreshes_total": refreshes_total,
		"expirations_total": expirations_total,
		"last_activated_boon_id": last_activated_boon_id,
		"last_expired_boon_id": last_expired_boon_id,
	}


func get_debug_snapshot() -> Dictionary:
	var snapshot := get_boon_snapshot()
	snapshot["known_boon_count"] = BOON_DEFINITIONS.size()
	snapshot["activations_total"] = activations_total
	snapshot["refreshes_total"] = refreshes_total
	snapshot["expirations_total"] = expirations_total
	snapshot["last_activated_boon_id"] = last_activated_boon_id
	snapshot["last_expired_boon_id"] = last_expired_boon_id
	return snapshot


func get_boon_activation_message(boon_id: String) -> String:
	var definition := get_boon_definition(boon_id)
	if definition.is_empty():
		return ""
	return "%s active: %s." % [
		str(definition.get("name", "Kraken Boon")),
		_format_shots(maxi(int(definition.get("duration_shots", 0)), 0)),
	]


func debug_expire_all_boons() -> int:
	if active_boons.is_empty():
		return 0

	var expired_ids: Array[String] = []
	for boon_id_value in active_boons.keys():
		expired_ids.append(str(boon_id_value))

	for boon_id in expired_ids:
		active_boons.erase(boon_id)
		expirations_total += 1
		last_expired_boon_id = boon_id
		boon_expired.emit(boon_id)

	_emit_boons_changed()
	return expired_ids.size()


func _on_shot_finished(_shot_count: int) -> void:
	if active_boons.is_empty():
		return

	var expired_ids: Array[String] = []
	for boon_id_value in active_boons.keys():
		var boon_id := str(boon_id_value)
		var state: Dictionary = active_boons[boon_id] as Dictionary
		var remaining := maxi(int(state.get("remaining_shots", 0)) - 1, 0)
		if remaining <= 0:
			expired_ids.append(boon_id)
		else:
			state["remaining_shots"] = remaining
			active_boons[boon_id] = state

	for boon_id in expired_ids:
		active_boons.erase(boon_id)
		expirations_total += 1
		last_expired_boon_id = boon_id
		boon_expired.emit(boon_id)

	_emit_boons_changed()


func _make_active_boon_state(boon_id: String) -> Dictionary:
	var definition := get_boon_definition(boon_id)
	return {
		"id": boon_id,
		"remaining_shots": maxi(int(definition.get("duration_shots", 0)), 0),
	}


func _get_boon_effects_snapshot(boon_id: String) -> Dictionary:
	var definition := get_boon_definition(boon_id)
	var effects_value: Variant = definition.get("effects", {})
	if not effects_value is Dictionary:
		return {}
	var effects: Dictionary = effects_value as Dictionary
	return effects.duplicate(true)


func _get_active_boons_summary(active_entries: Array) -> String:
	if active_entries.is_empty():
		return "None"

	var lines: Array[String] = []
	for entry_value in active_entries:
		var entry: Dictionary = entry_value as Dictionary
		lines.append("%s: %s" % [
			str(entry.get("name", "Kraken Boon")),
			_format_shots(maxi(int(entry.get("remaining_shots", 0)), 0)),
		])
	return ", ".join(lines)


func _format_shots(count: int) -> String:
	var safe_count := maxi(count, 0)
	return "%s shot%s" % [safe_count, "" if safe_count == 1 else "s"]


func _emit_boons_changed() -> void:
	boons_changed.emit(get_boon_snapshot())
