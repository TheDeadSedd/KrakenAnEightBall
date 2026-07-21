extends RefCounted
class_name RogueliteBalanceTuning

# Debug-only, session-local staging for Long Sink balance experiments. The
# active snapshot is frozen by Table at fresh-run startup; edits made during a
# run are intentionally staged for the next fresh debug run.

signal changed(snapshot: Dictionary)

const EIGHT_BALL_CATALOG := preload("res://scripts/RogueliteEightBallCatalog.gd")

const FAMILY_SINGLE_BANK := "single_bank"
const FAMILY_DOUBLE_BANK := "double_bank"
const FAMILY_TRIPLE_BANK := "triple_bank"
const FAMILY_COMBINATION := "combination"
const FAMILY_DIRECT_POT := "direct_pot"
const FAMILY_MULTI_POT := "multi_pot"
const FAMILY_SAME_POCKET := "same_pocket"
const FAMILY_IDS: Array[String] = [
	FAMILY_SINGLE_BANK,
	FAMILY_DOUBLE_BANK,
	FAMILY_TRIPLE_BANK,
	FAMILY_COMBINATION,
	FAMILY_DIRECT_POT,
	FAMILY_MULTI_POT,
	FAMILY_SAME_POCKET,
]

const DEFAULT_FAMILY_MULTIPLIER := 1.0
const DEFAULT_QUOTA_MULTIPLIER := 1.0
const DEFAULT_SELECTED_ITEM_ID := "single_bank_haul_crooked_coin"

var family_offer_multipliers: Dictionary = {}
var quota_multiplier := DEFAULT_QUOTA_MULTIPLIER
var selected_item_id := DEFAULT_SELECTED_ITEM_ID
var item_overrides: Dictionary = {}
var shot_lab_telemetry_enabled := false


func _init() -> void:
	_reset_values(false)


func get_configuration_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"debug_only": true,
		"family_offer_multipliers": family_offer_multipliers.duplicate(true),
		"quota_multiplier": quota_multiplier,
		"selected_item_id": selected_item_id,
		"item_overrides": item_overrides.duplicate(true),
		"shot_lab_telemetry_enabled": shot_lab_telemetry_enabled,
		"has_overrides": has_any_overrides(),
	}.duplicate(true)


func apply_configuration_snapshot(snapshot: Dictionary) -> void:
	_reset_values(false)
	var family_value: Variant = snapshot.get("family_offer_multipliers", {})
	if family_value is Dictionary:
		for family_id in FAMILY_IDS:
			family_offer_multipliers[family_id] = clampf(
				float((family_value as Dictionary).get(family_id, DEFAULT_FAMILY_MULTIPLIER)),
				0.0,
				5.0
			)
	quota_multiplier = clampf(
		float(snapshot.get("quota_multiplier", DEFAULT_QUOTA_MULTIPLIER)),
		0.25,
		5.0
	)
	set_selected_item_id(str(snapshot.get("selected_item_id", DEFAULT_SELECTED_ITEM_ID)), false)
	var overrides_value: Variant = snapshot.get("item_overrides", {})
	if overrides_value is Dictionary:
		for item_id_value in (overrides_value as Dictionary).keys():
			var item_id: String = str(item_id_value)
			if not EIGHT_BALL_CATALOG.has_definition(item_id):
				continue
			var entry_value: Variant = (overrides_value as Dictionary).get(item_id, {})
			if not entry_value is Dictionary:
				continue
			item_overrides[item_id] = _normalize_item_override(entry_value as Dictionary)
	shot_lab_telemetry_enabled = bool(snapshot.get("shot_lab_telemetry_enabled", false))
	_emit_changed()


func make_active_run_snapshot() -> Dictionary:
	var snapshot: Dictionary = get_configuration_snapshot()
	snapshot["frozen_for_fresh_run"] = true
	snapshot["frozen_at_unix"] = int(Time.get_unix_time_from_system())
	return snapshot


func reset_overrides() -> void:
	_reset_values(true)


func has_any_overrides() -> bool:
	if shot_lab_telemetry_enabled:
		return true
	if not is_equal_approx(quota_multiplier, DEFAULT_QUOTA_MULTIPLIER):
		return true
	for family_id in FAMILY_IDS:
		if not is_equal_approx(
			float(family_offer_multipliers.get(family_id, DEFAULT_FAMILY_MULTIPLIER)),
			DEFAULT_FAMILY_MULTIPLIER
		):
			return true
	return not item_overrides.is_empty()


func get_family_offer_multiplier(family_id: String) -> float:
	return float(family_offer_multipliers.get(family_id, DEFAULT_FAMILY_MULTIPLIER))


func set_family_offer_multiplier(family_id: String, value: float) -> void:
	if family_id not in FAMILY_IDS:
		return
	family_offer_multipliers[family_id] = clampf(value, 0.0, 5.0)
	_emit_changed()


func get_quota_multiplier() -> float:
	return quota_multiplier


func set_quota_multiplier(value: float) -> void:
	quota_multiplier = clampf(value, 0.25, 5.0)
	_emit_changed()


func get_selected_item_id() -> String:
	return selected_item_id


func set_selected_item_id(item_id: String, emit_change: bool = true) -> void:
	if not EIGHT_BALL_CATALOG.has_definition(item_id):
		return
	selected_item_id = item_id
	if emit_change:
		_emit_changed()


func get_selected_item_phase() -> String:
	return str(_get_selected_definition().get("modifier_phase", ""))


func is_selected_item_phase(phase: String) -> bool:
	return get_selected_item_phase() == phase


func get_selected_add_haul_value() -> float:
	return _get_selected_value_for_phase(EIGHT_BALL_CATALOG.PHASE_ADD_HAUL, "add_haul_value", 0.0)


func set_selected_add_haul_value(value: float) -> void:
	_set_selected_item_override("add_haul_value", maxf(value, 0.0))


func get_selected_add_mult_value() -> float:
	return _get_selected_value_for_phase(EIGHT_BALL_CATALOG.PHASE_ADD_MULT, "add_mult_value", 0.0)


func set_selected_add_mult_value(value: float) -> void:
	_set_selected_item_override("add_mult_value", maxf(value, 0.0))


func get_selected_xmult_factor() -> float:
	return _get_selected_value_for_phase(EIGHT_BALL_CATALOG.PHASE_XMULT, "xmult_factor", 1.0)


func set_selected_xmult_factor(value: float) -> void:
	_set_selected_item_override("xmult_factor", maxf(value, 0.0))


func get_selected_offer_weight() -> float:
	var definition: Dictionary = _get_selected_definition()
	var authored: float = float(definition.get("offer_weight", 0))
	return float(_get_selected_override().get("offer_weight", authored))


func set_selected_offer_weight(value: float) -> void:
	_set_selected_item_override("offer_weight", maxf(value, 0.0))


func is_shot_lab_telemetry_enabled() -> bool:
	return shot_lab_telemetry_enabled


func set_shot_lab_telemetry_enabled(enabled: bool) -> void:
	shot_lab_telemetry_enabled = enabled
	_emit_changed()


func get_selected_item_diagnostics() -> Dictionary:
	var definition: Dictionary = _get_selected_definition()
	return {
		"selected_item_id": selected_item_id,
		"display_name": str(definition.get("display_name", selected_item_id)),
		"phase": str(definition.get("modifier_phase", "")),
		"authored_value": definition.get("value", 0),
		"authored_offer_weight": int(definition.get("offer_weight", 0)),
		"staged_override": _get_selected_override().duplicate(true),
	}


static func apply_definition_overrides(
	definition: Dictionary,
	active_snapshot: Dictionary
) -> Dictionary:
	if definition.is_empty():
		return {}
	var effective: Dictionary = definition.duplicate(true)
	var item_id: String = str(effective.get("eight_ball_item_id", effective.get("id", "")))
	var authored_value: Variant = effective.get("value", 0)
	var authored_weight: int = int(effective.get("offer_weight", 0))
	effective["authored_value"] = authored_value
	effective["authored_offer_weight"] = authored_weight
	var overrides: Dictionary = _dictionary_value(active_snapshot, "item_overrides")
	var entry: Dictionary = _dictionary_value(overrides, item_id)
	var phase: String = str(effective.get("modifier_phase", ""))
	var value_key: String = _value_key_for_phase(phase)
	var notes: PackedStringArray = PackedStringArray()
	if not value_key.is_empty() and entry.has(value_key):
		effective["value"] = entry[value_key]
		notes.append("value %s -> %s" % [authored_value, entry[value_key]])
	if entry.has("offer_weight"):
		effective["offer_weight"] = maxi(int(roundf(float(entry["offer_weight"]))), 0)
		notes.append("weight %d -> %d" % [authored_weight, int(effective["offer_weight"])])
	var family_id: String = str(effective.get("family_id", ""))
	var family_multiplier: float = get_family_multiplier_from_snapshot(active_snapshot, family_id)
	effective["offer_family_multiplier"] = family_multiplier
	effective["balance_override_active"] = not notes.is_empty() or not is_equal_approx(
		family_multiplier,
		DEFAULT_FAMILY_MULTIPLIER
	)
	if not is_equal_approx(family_multiplier, DEFAULT_FAMILY_MULTIPLIER):
		notes.append("family offer x%.2f" % family_multiplier)
	if not notes.is_empty():
		effective["balance_override_notes"] = Array(notes)
		effective["tooltip"] = "%s\n\n[Debug next-run override: %s]" % [
			str(effective.get("tooltip", "")),
			", ".join(notes),
		]
	return effective


static func get_effective_offer_weight(
	definition: Dictionary,
	active_snapshot: Dictionary
) -> int:
	var effective: Dictionary = apply_definition_overrides(definition, active_snapshot)
	var authored_or_override: float = maxf(float(effective.get("offer_weight", 0)), 0.0)
	var multiplier: float = get_family_multiplier_from_snapshot(
		active_snapshot,
		str(effective.get("family_id", ""))
	)
	return maxi(int(roundf(authored_or_override * multiplier)), 0)


static func get_family_multiplier_from_snapshot(
	active_snapshot: Dictionary,
	family_id: String
) -> float:
	var multipliers: Dictionary = _dictionary_value(active_snapshot, "family_offer_multipliers")
	return maxf(float(multipliers.get(family_id, DEFAULT_FAMILY_MULTIPLIER)), 0.0)


static func get_quota_multiplier_from_snapshot(active_snapshot: Dictionary) -> float:
	return maxf(float(active_snapshot.get("quota_multiplier", DEFAULT_QUOTA_MULTIPLIER)), 0.0)


func _get_selected_definition() -> Dictionary:
	return EIGHT_BALL_CATALOG.get_definition(selected_item_id)


func _get_selected_override() -> Dictionary:
	return _dictionary_value(item_overrides, selected_item_id)


func _get_selected_value_for_phase(
	phase: String,
	override_key: String,
	inactive_default: float
) -> float:
	var definition: Dictionary = _get_selected_definition()
	if str(definition.get("modifier_phase", "")) != phase:
		return inactive_default
	return float(_get_selected_override().get(override_key, definition.get("value", inactive_default)))


func _set_selected_item_override(key: String, value: Variant) -> void:
	var entry: Dictionary = _get_selected_override().duplicate(true)
	entry[key] = value
	item_overrides[selected_item_id] = entry
	_prune_selected_override_if_authored()
	_emit_changed()


func _prune_selected_override_if_authored() -> void:
	var definition: Dictionary = _get_selected_definition()
	var entry: Dictionary = _get_selected_override().duplicate(true)
	var phase_key: String = _value_key_for_phase(str(definition.get("modifier_phase", "")))
	if entry.has(phase_key) and is_equal_approx(
		float(entry[phase_key]),
		float(definition.get("value", 0.0))
	):
		entry.erase(phase_key)
	if entry.has("offer_weight") and is_equal_approx(
		float(entry["offer_weight"]),
		float(definition.get("offer_weight", 0))
	):
		entry.erase("offer_weight")
	if entry.is_empty():
		item_overrides.erase(selected_item_id)
	else:
		item_overrides[selected_item_id] = entry


func _normalize_item_override(entry: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	if entry.has("add_haul_value"):
		normalized["add_haul_value"] = maxf(float(entry["add_haul_value"]), 0.0)
	if entry.has("add_mult_value"):
		normalized["add_mult_value"] = maxf(float(entry["add_mult_value"]), 0.0)
	if entry.has("xmult_factor"):
		normalized["xmult_factor"] = maxf(float(entry["xmult_factor"]), 0.0)
	if entry.has("offer_weight"):
		normalized["offer_weight"] = maxf(float(entry["offer_weight"]), 0.0)
	return normalized


func _reset_values(emit_change: bool) -> void:
	family_offer_multipliers.clear()
	for family_id in FAMILY_IDS:
		family_offer_multipliers[family_id] = DEFAULT_FAMILY_MULTIPLIER
	quota_multiplier = DEFAULT_QUOTA_MULTIPLIER
	selected_item_id = DEFAULT_SELECTED_ITEM_ID
	item_overrides.clear()
	shot_lab_telemetry_enabled = false
	if emit_change:
		_emit_changed()


func _emit_changed() -> void:
	changed.emit(get_configuration_snapshot())


static func _value_key_for_phase(phase: String) -> String:
	match phase:
		RogueliteEightBallCatalog.PHASE_ADD_HAUL:
			return "add_haul_value"
		RogueliteEightBallCatalog.PHASE_ADD_MULT:
			return "add_mult_value"
		RogueliteEightBallCatalog.PHASE_XMULT:
			return "xmult_factor"
		_:
			return ""


static func _dictionary_value(container: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = container.get(key, {})
	return (value as Dictionary) if value is Dictionary else {}
