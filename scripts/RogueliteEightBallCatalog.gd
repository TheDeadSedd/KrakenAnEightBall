extends RefCounted
class_name RogueliteEightBallCatalog

# Pure, immutable-by-copy definitions for run-owned Eight Ball build items.
# These items are never physical table balls and never receive run_ball_id values.

const CATALOG_VERSION := 2
const EXPECTED_DEFINITION_COUNT := 22
const ICON_KEY_PLACEHOLDER := "eight_ball_placeholder"

const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const RARITY_LEGENDARY := "legendary"

const OFFER_WEIGHT_COMMON := 100
const OFFER_WEIGHT_UNCOMMON := 65
const OFFER_WEIGHT_RARE := 30
const OFFER_WEIGHT_LEGENDARY := 8

const RARITY_WEIGHTS: Dictionary = {
	RARITY_COMMON: OFFER_WEIGHT_COMMON,
	RARITY_UNCOMMON: OFFER_WEIGHT_UNCOMMON,
	RARITY_RARE: OFFER_WEIGHT_RARE,
	RARITY_LEGENDARY: OFFER_WEIGHT_LEGENDARY,
}

const TRIGGER_SINGLE_BANK := "single_bank_milestone"
const TRIGGER_DOUBLE_BANK := "double_bank_milestone"
const TRIGGER_TRIPLE_BANK := "triple_bank_milestone"
const TRIGGER_COMBINATION := "combination_pot"
const TRIGGER_DIRECT_POT := "direct_pot"
const TRIGGER_MULTI_POT := "multi_pot_shot"
const TRIGGER_SAME_POCKET := "same_pocket_streak"

const PHASE_ADD_HAUL := "add_haul"
const PHASE_ADD_MULT := "add_mult"
const PHASE_XMULT := "xmult"

const EFFECT_KIND_RETRIGGER_FAMILY := "retrigger_family"
const DEAD_RECKONING_ITEM_ID := "direct_pot_legendary_dead_reckoning"
const DIRECT_POT_SUPPORT_ITEM_IDS: Array[String] = [
	"direct_pot_haul_clean_plunder",
	"direct_pot_mult_true_bearing",
	"direct_pot_xmult_unerring_course",
]

const DEFINITION_ORDER: Array[String] = [
	"single_bank_haul_crooked_coin",
	"single_bank_mult_first_toll",
	"single_bank_xmult_rogue_current",
	"double_bank_haul_twin_tribute",
	"double_bank_mult_second_bell",
	"double_bank_xmult_crossed_tides",
	"triple_bank_haul_threefold_plunder",
	"triple_bank_mult_third_toll",
	"triple_bank_xmult_krakens_trine",
	"combination_haul_shared_spoils",
	"combination_mult_chain_of_command",
	"combination_xmult_conspirators_cut",
	"direct_pot_haul_clean_plunder",
	"direct_pot_mult_true_bearing",
	"direct_pot_xmult_unerring_course",
	"direct_pot_legendary_dead_reckoning",
	"multi_pot_haul_loaded_hold",
	"multi_pot_mult_all_hands",
	"multi_pot_xmult_broadside_dividend",
	"same_pocket_haul_shared_grave",
	"same_pocket_mult_feeding_frenzy",
	"same_pocket_xmult_the_maw_below",
]

const _DEFINITIONS: Dictionary = {
	"single_bank_haul_crooked_coin": {
		"eight_ball_item_id": "single_bank_haul_crooked_coin",
		"display_name": "Crooked Coin",
		"family_id": "single_bank",
		"trigger_id": TRIGGER_SINGLE_BANK,
		"modifier_phase": PHASE_ADD_HAUL,
		"value": 10,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"short_effect": "Single Bank: +10 Haul",
		"tooltip": "Whenever a scoring ball reaches the Single Bank milestone, gain +10 Haul.\nDouble and Triple Banks also trigger this milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"single_bank_mult_first_toll": {
		"eight_ball_item_id": "single_bank_mult_first_toll",
		"display_name": "First Toll",
		"family_id": "single_bank",
		"trigger_id": TRIGGER_SINGLE_BANK,
		"modifier_phase": PHASE_ADD_MULT,
		"value": 1,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"short_effect": "Single Bank: +1 Mult",
		"tooltip": "Whenever a scoring ball reaches the Single Bank milestone, gain +1 Mult.\nDouble and Triple Banks also trigger this milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"single_bank_xmult_rogue_current": {
		"eight_ball_item_id": "single_bank_xmult_rogue_current",
		"display_name": "Rogue Current",
		"family_id": "single_bank",
		"trigger_id": TRIGGER_SINGLE_BANK,
		"modifier_phase": PHASE_XMULT,
		"value": 1.25,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"short_effect": "Single Bank: x1.25 Mult",
		"tooltip": "Whenever a scoring ball reaches the Single Bank milestone, multiply Mult by 1.25.\nDouble and Triple Banks also trigger this milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"double_bank_haul_twin_tribute": {
		"eight_ball_item_id": "double_bank_haul_twin_tribute",
		"display_name": "Twin Tribute",
		"family_id": "double_bank",
		"trigger_id": TRIGGER_DOUBLE_BANK,
		"modifier_phase": PHASE_ADD_HAUL,
		"value": 15,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"short_effect": "Double Bank: +15 Haul",
		"tooltip": "Whenever a scoring ball reaches the Double Bank milestone, gain +15 Haul.\nTriple Banks also trigger this milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"double_bank_mult_second_bell": {
		"eight_ball_item_id": "double_bank_mult_second_bell",
		"display_name": "Second Bell",
		"family_id": "double_bank",
		"trigger_id": TRIGGER_DOUBLE_BANK,
		"modifier_phase": PHASE_ADD_MULT,
		"value": 2,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"short_effect": "Double Bank: +2 Mult",
		"tooltip": "Whenever a scoring ball reaches the Double Bank milestone, gain +2 Mult.\nTriple Banks also trigger this milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"double_bank_xmult_crossed_tides": {
		"eight_ball_item_id": "double_bank_xmult_crossed_tides",
		"display_name": "Crossed Tides",
		"family_id": "double_bank",
		"trigger_id": TRIGGER_DOUBLE_BANK,
		"modifier_phase": PHASE_XMULT,
		"value": 1.5,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"short_effect": "Double Bank: x1.5 Mult",
		"tooltip": "Whenever a scoring ball reaches the Double Bank milestone, multiply Mult by 1.5.\nTriple Banks also trigger this milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"triple_bank_haul_threefold_plunder": {
		"eight_ball_item_id": "triple_bank_haul_threefold_plunder",
		"display_name": "Threefold Plunder",
		"family_id": "triple_bank",
		"trigger_id": TRIGGER_TRIPLE_BANK,
		"modifier_phase": PHASE_ADD_HAUL,
		"value": 25,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"short_effect": "Triple Bank: +25 Haul",
		"tooltip": "Whenever a scoring ball reaches the Triple Bank milestone, gain +25 Haul.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"triple_bank_mult_third_toll": {
		"eight_ball_item_id": "triple_bank_mult_third_toll",
		"display_name": "Third Toll",
		"family_id": "triple_bank",
		"trigger_id": TRIGGER_TRIPLE_BANK,
		"modifier_phase": PHASE_ADD_MULT,
		"value": 3,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"short_effect": "Triple Bank: +3 Mult",
		"tooltip": "Whenever a scoring ball reaches the Triple Bank milestone, gain +3 Mult.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"triple_bank_xmult_krakens_trine": {
		"eight_ball_item_id": "triple_bank_xmult_krakens_trine",
		"display_name": "Kraken’s Trine",
		"family_id": "triple_bank",
		"trigger_id": TRIGGER_TRIPLE_BANK,
		"modifier_phase": PHASE_XMULT,
		"value": 2.0,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"short_effect": "Triple Bank: x2 Mult",
		"tooltip": "Whenever a scoring ball reaches the Triple Bank milestone, multiply Mult by 2.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"combination_haul_shared_spoils": {
		"eight_ball_item_id": "combination_haul_shared_spoils",
		"display_name": "Shared Spoils",
		"family_id": "combination",
		"trigger_id": TRIGGER_COMBINATION,
		"modifier_phase": PHASE_ADD_HAUL,
		"value": 10,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"short_effect": "Combination: +10 Haul",
		"tooltip": "Whenever a scoring ball pockets as a Combination, gain +10 Haul.\nA banked Combination may activate both Combination and Bank Eight Balls.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"combination_mult_chain_of_command": {
		"eight_ball_item_id": "combination_mult_chain_of_command",
		"display_name": "Chain of Command",
		"family_id": "combination",
		"trigger_id": TRIGGER_COMBINATION,
		"modifier_phase": PHASE_ADD_MULT,
		"value": 2,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"short_effect": "Combination: +2 Mult",
		"tooltip": "Whenever a scoring ball pockets as a Combination, gain +2 Mult.\nA banked Combination may activate both Combination and Bank Eight Balls.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"combination_xmult_conspirators_cut": {
		"eight_ball_item_id": "combination_xmult_conspirators_cut",
		"display_name": "Conspirator’s Cut",
		"family_id": "combination",
		"trigger_id": TRIGGER_COMBINATION,
		"modifier_phase": PHASE_XMULT,
		"value": 1.5,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"short_effect": "Combination: x1.5 Mult",
		"tooltip": "Whenever a scoring ball pockets as a Combination, multiply Mult by 1.5.\nA banked Combination may activate both Combination and Bank Eight Balls.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"direct_pot_haul_clean_plunder": {
		"eight_ball_item_id": "direct_pot_haul_clean_plunder",
		"display_name": "Clean Plunder",
		"family_id": "direct_pot",
		"trigger_id": TRIGGER_DIRECT_POT,
		"modifier_phase": PHASE_ADD_HAUL,
		"value": 10,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"short_effect": "Direct Pot: +10 Haul",
		"tooltip": "Whenever a scoring ball pockets as a Direct Pot, gain +10 Haul.\n\nA Direct Pot reaches its pocket without banking and without being pocketed through another object ball.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"direct_pot_mult_true_bearing": {
		"eight_ball_item_id": "direct_pot_mult_true_bearing",
		"display_name": "True Bearing",
		"family_id": "direct_pot",
		"trigger_id": TRIGGER_DIRECT_POT,
		"modifier_phase": PHASE_ADD_MULT,
		"value": 1,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"short_effect": "Direct Pot: +1 Mult",
		"tooltip": "Whenever a scoring ball pockets as a Direct Pot, gain +1 Mult.\n\nDirect Pot effects do not trigger from Banks or Combinations.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"direct_pot_xmult_unerring_course": {
		"eight_ball_item_id": "direct_pot_xmult_unerring_course",
		"display_name": "Unerring Course",
		"family_id": "direct_pot",
		"trigger_id": TRIGGER_DIRECT_POT,
		"modifier_phase": PHASE_XMULT,
		"value": 1.25,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"short_effect": "Direct Pot: x1.25 Mult",
		"tooltip": "Whenever a scoring ball pockets as a Direct Pot, multiply Mult by 1.25.\n\nDirect Pots may still contribute to Multi-Pot and Same-Pocket effects.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"direct_pot_legendary_dead_reckoning": {
		"eight_ball_item_id": DEAD_RECKONING_ITEM_ID,
		"display_name": "Dead Reckoning",
		"family_id": "direct_pot",
		"trigger_id": TRIGGER_DIRECT_POT,
		"effect_kind": EFFECT_KIND_RETRIGGER_FAMILY,
		"retrigger_family": "direct_pot",
		"retrigger_count": 1,
		"rarity": RARITY_LEGENDARY,
		"offer_weight": OFFER_WEIGHT_LEGENDARY,
		"short_effect": "Direct Pot Eight Balls trigger twice",
		"tooltip": "Whenever a Direct Pot occurs, your other Direct Pot Eight Balls trigger one additional time.\n\nDead Reckoning does not retrigger itself, base scoring, other families, or another retrigger.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"multi_pot_haul_loaded_hold": {
		"eight_ball_item_id": "multi_pot_haul_loaded_hold",
		"display_name": "Loaded Hold",
		"family_id": "multi_pot",
		"trigger_id": TRIGGER_MULTI_POT,
		"modifier_phase": PHASE_ADD_HAUL,
		"value": 20,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"short_effect": "Multi-Pot: +20 Haul",
		"tooltip": "Whenever at least two scoring object balls are pocketed in one shot, gain +20 Haul.\n\nTriggers once per shot in this version.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"multi_pot_mult_all_hands": {
		"eight_ball_item_id": "multi_pot_mult_all_hands",
		"display_name": "All Hands",
		"family_id": "multi_pot",
		"trigger_id": TRIGGER_MULTI_POT,
		"modifier_phase": PHASE_ADD_MULT,
		"value": 2,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"short_effect": "Multi-Pot: +2 Mult",
		"tooltip": "Whenever at least two scoring object balls are pocketed in one shot, gain +2 Mult.\n\nTriggers once per shot in this version.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"multi_pot_xmult_broadside_dividend": {
		"eight_ball_item_id": "multi_pot_xmult_broadside_dividend",
		"display_name": "Broadside Dividend",
		"family_id": "multi_pot",
		"trigger_id": TRIGGER_MULTI_POT,
		"modifier_phase": PHASE_XMULT,
		"value": 1.5,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"short_effect": "Multi-Pot: x1.5 Mult",
		"tooltip": "Whenever at least two scoring object balls are pocketed in one shot, multiply Mult by 1.5.\n\nTriggers once per shot in this version.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"same_pocket_haul_shared_grave": {
		"eight_ball_item_id": "same_pocket_haul_shared_grave",
		"display_name": "Shared Grave",
		"family_id": "same_pocket",
		"trigger_id": TRIGGER_SAME_POCKET,
		"modifier_phase": PHASE_ADD_HAUL,
		"value": 25,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"short_effect": "Same Pocket X2+: +25 Haul",
		"tooltip": "Whenever two or more scoring object balls enter the same pocket during one shot, gain +25 Haul.\n\nTriggers once for each qualifying pocket.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"same_pocket_mult_feeding_frenzy": {
		"eight_ball_item_id": "same_pocket_mult_feeding_frenzy",
		"display_name": "Feeding Frenzy",
		"family_id": "same_pocket",
		"trigger_id": TRIGGER_SAME_POCKET,
		"modifier_phase": PHASE_ADD_MULT,
		"value": 3,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"short_effect": "Same Pocket X2+: +3 Mult",
		"tooltip": "Whenever two or more scoring object balls enter the same pocket during one shot, gain +3 Mult.\n\nTriggers once for each qualifying pocket.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"same_pocket_xmult_the_maw_below": {
		"eight_ball_item_id": "same_pocket_xmult_the_maw_below",
		"display_name": "The Maw Below",
		"family_id": "same_pocket",
		"trigger_id": TRIGGER_SAME_POCKET,
		"modifier_phase": PHASE_XMULT,
		"value": 1.75,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"short_effect": "Same Pocket X2+: x1.75 Mult",
		"tooltip": "Whenever two or more scoring object balls enter the same pocket during one shot, multiply Mult by 1.75.\n\nTriggers once for each qualifying pocket.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
}


static func has_definition(eight_ball_item_id: String) -> bool:
	return _DEFINITIONS.has(eight_ball_item_id)


static func get_definition(eight_ball_item_id: String) -> Dictionary:
	var definition_value: Variant = _DEFINITIONS.get(eight_ball_item_id, {})
	if not definition_value is Dictionary:
		return {}
	return (definition_value as Dictionary).duplicate(true)


static func list_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for eight_ball_item_id in DEFINITION_ORDER:
		var definition: Dictionary = get_definition(eight_ball_item_id)
		if not definition.is_empty():
			definitions.append(definition)
	return definitions


static func get_all_definitions() -> Array[Dictionary]:
	return list_definitions()


static func list_item_ids() -> Array[String]:
	return DEFINITION_ORDER.duplicate()


static func get_item_ids() -> Array[String]:
	return list_item_ids()


static func get_definitions_by_id() -> Dictionary:
	return _DEFINITIONS.duplicate(true)


static func get_rarity_weights() -> Dictionary:
	return RARITY_WEIGHTS.duplicate(true)


static func get_offer_weight_for_rarity(rarity: String) -> int:
	return int(RARITY_WEIGHTS.get(rarity, 0))


static func validate_catalog() -> Dictionary:
	var failures: Array[String] = []
	var seen_ids: Dictionary = {}
	var family_counts: Dictionary = {}
	var legendary_count: int = 0
	if DEFINITION_ORDER.size() != EXPECTED_DEFINITION_COUNT:
		failures.append(
			"Definition order expected %d items, received %d."
			% [EXPECTED_DEFINITION_COUNT, DEFINITION_ORDER.size()]
		)
	if _DEFINITIONS.size() != EXPECTED_DEFINITION_COUNT:
		failures.append(
			"Definition table expected %d items, received %d."
			% [EXPECTED_DEFINITION_COUNT, _DEFINITIONS.size()]
		)

	for eight_ball_item_id in DEFINITION_ORDER:
		if seen_ids.has(eight_ball_item_id):
			failures.append("Duplicate ordered Eight Ball item ID: %s." % eight_ball_item_id)
			continue
		seen_ids[eight_ball_item_id] = true
		var definition: Dictionary = get_definition(eight_ball_item_id)
		if definition.is_empty():
			failures.append("Missing Eight Ball definition: %s." % eight_ball_item_id)
			continue
		_validate_definition(eight_ball_item_id, definition, failures)
		var family_id: String = str(definition.get("family_id", ""))
		family_counts[family_id] = int(family_counts.get(family_id, 0)) + 1
		if str(definition.get("rarity", "")) == RARITY_LEGENDARY:
			legendary_count += 1

	for definition_id_value in _DEFINITIONS.keys():
		var definition_id: String = str(definition_id_value)
		if definition_id not in DEFINITION_ORDER:
			failures.append("Definition is absent from deterministic order: %s." % definition_id)

	var expected_family_counts: Dictionary = {
		"single_bank": 3,
		"double_bank": 3,
		"triple_bank": 3,
		"combination": 3,
		"direct_pot": 4,
		"multi_pot": 3,
		"same_pocket": 3,
	}
	for family_id_value in expected_family_counts.keys():
		var family_id: String = str(family_id_value)
		var expected_count: int = int(expected_family_counts[family_id])
		var actual_count: int = int(family_counts.get(family_id, 0))
		if actual_count != expected_count:
			failures.append(
				"Family %s expected %d items, received %d."
				% [family_id, expected_count, actual_count]
			)
	if legendary_count != 1:
		failures.append("Catalog expected 1 Legendary item, received %d." % legendary_count)

	return {
		"catalog_version": CATALOG_VERSION,
		"definition_count": _DEFINITIONS.size(),
		"expected_definition_count": EXPECTED_DEFINITION_COUNT,
		"valid": failures.is_empty(),
		"failures": failures.duplicate(),
	}


static func _validate_definition(
	eight_ball_item_id: String,
	definition: Dictionary,
	failures: Array[String]
) -> void:
	var required_string_fields: Array[String] = [
		"eight_ball_item_id",
		"display_name",
		"family_id",
		"trigger_id",
		"rarity",
		"short_effect",
		"tooltip",
		"icon_key",
	]
	for field_name in required_string_fields:
		if str(definition.get(field_name, "")).is_empty():
			failures.append("%s has an empty %s." % [eight_ball_item_id, field_name])

	if str(definition.get("eight_ball_item_id", "")) != eight_ball_item_id:
		failures.append("%s does not match its embedded eight_ball_item_id." % eight_ball_item_id)

	var trigger_id: String = str(definition.get("trigger_id", ""))
	if trigger_id not in [
		TRIGGER_SINGLE_BANK,
		TRIGGER_DOUBLE_BANK,
		TRIGGER_TRIPLE_BANK,
		TRIGGER_COMBINATION,
		TRIGGER_DIRECT_POT,
		TRIGGER_MULTI_POT,
		TRIGGER_SAME_POCKET,
	]:
		failures.append("%s has invalid trigger_id %s." % [eight_ball_item_id, trigger_id])

	var effect_kind: String = str(definition.get("effect_kind", "modifier"))
	if effect_kind == EFFECT_KIND_RETRIGGER_FAMILY:
		_validate_retrigger_definition(eight_ball_item_id, definition, failures)
	else:
		_validate_modifier_definition(eight_ball_item_id, definition, failures)

	var rarity: String = str(definition.get("rarity", ""))
	var expected_weight: int = get_offer_weight_for_rarity(rarity)
	if expected_weight <= 0:
		failures.append("%s has invalid rarity %s." % [eight_ball_item_id, rarity])
	elif int(definition.get("offer_weight", 0)) != expected_weight:
		failures.append(
			"%s offer weight does not match centralized %s rarity weight."
			% [eight_ball_item_id, rarity]
		)

	var expected_trigger_by_family: Dictionary = {
		"single_bank": TRIGGER_SINGLE_BANK,
		"double_bank": TRIGGER_DOUBLE_BANK,
		"triple_bank": TRIGGER_TRIPLE_BANK,
		"combination": TRIGGER_COMBINATION,
		"direct_pot": TRIGGER_DIRECT_POT,
		"multi_pot": TRIGGER_MULTI_POT,
		"same_pocket": TRIGGER_SAME_POCKET,
	}
	var family_id: String = str(definition.get("family_id", ""))
	if not expected_trigger_by_family.has(family_id):
		failures.append("%s has invalid family_id %s." % [eight_ball_item_id, family_id])
	elif str(expected_trigger_by_family[family_id]) != trigger_id:
		failures.append("%s family and trigger do not agree." % eight_ball_item_id)


static func _validate_modifier_definition(
	eight_ball_item_id: String,
	definition: Dictionary,
	failures: Array[String]
) -> void:
	var modifier_phase: String = str(definition.get("modifier_phase", ""))
	if modifier_phase not in [PHASE_ADD_HAUL, PHASE_ADD_MULT, PHASE_XMULT]:
		failures.append("%s has invalid modifier_phase %s." % [eight_ball_item_id, modifier_phase])

	var value: Variant = definition.get("value", null)
	if (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT) or float(value) <= 0.0:
		failures.append("%s has an invalid positive numeric value." % eight_ball_item_id)
	elif modifier_phase == PHASE_XMULT and float(value) <= 1.0:
		failures.append("%s has a non-multiplying xMult value." % eight_ball_item_id)


static func _validate_retrigger_definition(
	eight_ball_item_id: String,
	definition: Dictionary,
	failures: Array[String]
) -> void:
	if eight_ball_item_id != DEAD_RECKONING_ITEM_ID:
		failures.append("%s is an unknown retrigger-family item." % eight_ball_item_id)
	if str(definition.get("family_id", "")) != "direct_pot":
		failures.append("%s must belong to the direct_pot family." % eight_ball_item_id)
	if str(definition.get("retrigger_family", "")) != "direct_pot":
		failures.append("%s must retrigger the direct_pot family." % eight_ball_item_id)
	if int(definition.get("retrigger_count", 0)) != 1:
		failures.append("%s must retrigger exactly once." % eight_ball_item_id)
	if str(definition.get("rarity", "")) != RARITY_LEGENDARY:
		failures.append("%s must use Legendary rarity." % eight_ball_item_id)
	if definition.has("value") or definition.has("modifier_phase"):
		failures.append("%s must not masquerade as a numeric modifier." % eight_ball_item_id)
