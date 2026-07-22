extends RefCounted
class_name RogueliteEightBallCatalog

# Pure, immutable-by-copy definitions for run-owned Eight Ball build items.
# These items are never physical table balls and never receive run_ball_id values.

const CATALOG_VERSION := 3
const EXPECTED_DEFINITION_COUNT := 32
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
const TRIGGER_CUE_RECONTACT := "cue_recontact_milestone"
const TRIGGER_OBJECT_BALL_TAP := "object_ball_tap_milestone"

const PHASE_ADD_HAUL := "add_haul"
const PHASE_ADD_MULT := "add_mult"
const PHASE_XMULT := "xmult"

const EFFECT_KIND_NUMERIC_MODIFIER := "numeric_modifier"
const EFFECT_KIND_PERSISTENT_SCALER := "persistent_scaler"
const EFFECT_KIND_CROSS_FAMILY_CONDITIONAL := "cross_family_conditional"
const EFFECT_KIND_SHOT_ORDINAL_MULTIPLIER := "shot_ordinal_multiplier"
const EFFECT_KIND_THRESHOLD_FAMILY_RETRIGGER := "threshold_family_retrigger"
const EFFECT_KIND_RETRIGGER_FAMILY := "retrigger_family"
const DEAD_RECKONING_ITEM_ID := "direct_pot_legendary_dead_reckoning"
const ECHO_CHAMBER_ITEM_ID := "tap_legendary_retrigger_echo_chamber"
const DIRECT_POT_SUPPORT_ITEM_IDS: Array[String] = [
	"direct_pot_haul_clean_plunder",
	"direct_pot_mult_true_bearing",
	"direct_pot_xmult_unerring_course",
]
const DOUBLE_TAP_SUPPORT_ITEM_IDS: Array[String] = [
	"double_tap_haul_second_bite",
	"double_tap_mult_echoing_toll",
	"double_tap_xmult_revenant_rhythm",
]
const BALL_TAP_SUPPORT_ITEM_IDS: Array[String] = [
	"ball_tap_haul_knock_on_plunder",
	"ball_tap_mult_crowded_wake",
	"ball_tap_xmult_carom_current",
]
const REGULAR_TAP_ITEM_IDS: Array[String] = [
	"double_tap_haul_second_bite",
	"double_tap_mult_echoing_toll",
	"double_tap_xmult_revenant_rhythm",
	"ball_tap_haul_knock_on_plunder",
	"ball_tap_mult_crowded_wake",
	"ball_tap_xmult_carom_current",
]
const TAP_TRIGGER_IDS: Array[String] = [
	TRIGGER_CUE_RECONTACT,
	TRIGGER_OBJECT_BALL_TAP,
]
const RATTLE_DEFAULT_STATE: Dictionary = {
	"state_version": 1,
	"current_xmult": 1.0,
	"lifetime_growth_triggers": 0,
	"shots_activated": 0,
}

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
	"double_tap_haul_second_bite",
	"double_tap_mult_echoing_toll",
	"double_tap_xmult_revenant_rhythm",
	"ball_tap_haul_knock_on_plunder",
	"ball_tap_mult_crowded_wake",
	"ball_tap_xmult_carom_current",
	"tap_stateful_xmult_rattle_of_the_deep",
	"tap_hybrid_xmult_one_two_punch",
	"tap_ordinal_xmult_aftershock",
	"tap_legendary_retrigger_echo_chamber",
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
	"double_tap_haul_second_bite": {
		"eight_ball_item_id": "double_tap_haul_second_bite",
		"display_name": "Second Bite",
		"family_id": "double_tap",
		"offer_family": "double_tap",
		"trigger_id": TRIGGER_CUE_RECONTACT,
		"trigger_ids": [TRIGGER_CUE_RECONTACT],
		"effect_kind": EFFECT_KIND_NUMERIC_MODIFIER,
		"modifier_phase": PHASE_ADD_HAUL,
		"application_phase": PHASE_ADD_HAUL,
		"application_scope": "per_trigger_occurrence",
		"value": 10,
		"regular_family_retriggerable": true,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Tap Milestone: +10 Haul",
		"tooltip": "Whenever a scoring ball earns a Double Tap, Triple Tap, or later cue-recontact milestone, gain +10 Haul.\n\nTriggers once for every scored cue-recontact milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"double_tap_mult_echoing_toll": {
		"eight_ball_item_id": "double_tap_mult_echoing_toll",
		"display_name": "Echoing Toll",
		"family_id": "double_tap",
		"offer_family": "double_tap",
		"trigger_id": TRIGGER_CUE_RECONTACT,
		"trigger_ids": [TRIGGER_CUE_RECONTACT],
		"effect_kind": EFFECT_KIND_NUMERIC_MODIFIER,
		"modifier_phase": PHASE_ADD_MULT,
		"application_phase": PHASE_ADD_MULT,
		"application_scope": "per_trigger_occurrence",
		"value": 1,
		"regular_family_retriggerable": true,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Tap Milestone: +1 Mult",
		"tooltip": "Whenever a scoring ball earns a Double Tap, Triple Tap, or later cue-recontact milestone, gain +1 Mult.\n\nTriggers once for every scored cue-recontact milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"double_tap_xmult_revenant_rhythm": {
		"eight_ball_item_id": "double_tap_xmult_revenant_rhythm",
		"display_name": "Revenant Rhythm",
		"family_id": "double_tap",
		"offer_family": "double_tap",
		"trigger_id": TRIGGER_CUE_RECONTACT,
		"trigger_ids": [TRIGGER_CUE_RECONTACT],
		"effect_kind": EFFECT_KIND_NUMERIC_MODIFIER,
		"modifier_phase": PHASE_XMULT,
		"application_phase": PHASE_XMULT,
		"application_scope": "per_trigger_occurrence",
		"value": 1.25,
		"regular_family_retriggerable": true,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Tap Milestone: x1.25 Mult",
		"tooltip": "Whenever a scoring ball earns a Double Tap, Triple Tap, or later cue-recontact milestone, multiply Mult by 1.25.\n\nTriggers once for every scored cue-recontact milestone.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"ball_tap_haul_knock_on_plunder": {
		"eight_ball_item_id": "ball_tap_haul_knock_on_plunder",
		"display_name": "Knock-On Plunder",
		"family_id": "ball_tap",
		"offer_family": "ball_tap",
		"trigger_id": TRIGGER_OBJECT_BALL_TAP,
		"trigger_ids": [TRIGGER_OBJECT_BALL_TAP],
		"effect_kind": EFFECT_KIND_NUMERIC_MODIFIER,
		"modifier_phase": PHASE_ADD_HAUL,
		"application_phase": PHASE_ADD_HAUL,
		"application_scope": "per_trigger_occurrence",
		"value": 8,
		"regular_family_retriggerable": true,
		"rarity": RARITY_COMMON,
		"offer_weight": OFFER_WEIGHT_COMMON,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Ball Tap: +8 Haul",
		"tooltip": "Whenever a scoring ball strikes a new unique object ball before pocketing, gain +8 Haul.\n\nRepeated contact with the same object ball does not trigger this effect again.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"ball_tap_mult_crowded_wake": {
		"eight_ball_item_id": "ball_tap_mult_crowded_wake",
		"display_name": "Crowded Wake",
		"family_id": "ball_tap",
		"offer_family": "ball_tap",
		"trigger_id": TRIGGER_OBJECT_BALL_TAP,
		"trigger_ids": [TRIGGER_OBJECT_BALL_TAP],
		"effect_kind": EFFECT_KIND_NUMERIC_MODIFIER,
		"modifier_phase": PHASE_ADD_MULT,
		"application_phase": PHASE_ADD_MULT,
		"application_scope": "per_trigger_occurrence",
		"value": 1,
		"regular_family_retriggerable": true,
		"rarity": RARITY_UNCOMMON,
		"offer_weight": OFFER_WEIGHT_UNCOMMON,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Ball Tap: +1 Mult",
		"tooltip": "Whenever a scoring ball strikes a new unique object ball before pocketing, gain +1 Mult.\n\nRepeated contact with the same object ball does not trigger this effect again.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"ball_tap_xmult_carom_current": {
		"eight_ball_item_id": "ball_tap_xmult_carom_current",
		"display_name": "Carom Current",
		"family_id": "ball_tap",
		"offer_family": "ball_tap",
		"trigger_id": TRIGGER_OBJECT_BALL_TAP,
		"trigger_ids": [TRIGGER_OBJECT_BALL_TAP],
		"effect_kind": EFFECT_KIND_NUMERIC_MODIFIER,
		"modifier_phase": PHASE_XMULT,
		"application_phase": PHASE_XMULT,
		"application_scope": "per_trigger_occurrence",
		"value": 1.20,
		"regular_family_retriggerable": true,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Ball Tap: x1.20 Mult",
		"tooltip": "Whenever a scoring ball strikes a new unique object ball before pocketing, multiply Mult by 1.20.\n\nRepeated contact with the same object ball does not trigger this effect again.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"tap_stateful_xmult_rattle_of_the_deep": {
		"eight_ball_item_id": "tap_stateful_xmult_rattle_of_the_deep",
		"display_name": "Rattle of the Deep",
		"family_id": "tap_oddity",
		"offer_family": "tap_growth",
		"trigger_ids": TAP_TRIGGER_IDS,
		"effect_kind": EFFECT_KIND_PERSISTENT_SCALER,
		"state_schema_version": 1,
		"state_defaults": RATTLE_DEFAULT_STATE,
		"initial_state": RATTLE_DEFAULT_STATE,
		"state_value_key": "current_xmult",
		"starting_value": 1.0,
		"growth_per_trigger": 0.2,
		"authored_cap": null,
		"modifier_phase": PHASE_XMULT,
		"application_phase": PHASE_XMULT,
		"application_scope": "once_per_qualifying_shot",
		"uses_post_growth_value": true,
		"state_mutation_policy": "authoritative_settlement_only",
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Gains +0.2x per Tap. Applies on Tap shots.",
		"tooltip": "Starts at x1 Mult.\n\nWhenever a Double Tap, Triple Tap, later cue-recontact milestone, or Ball Tap occurs, this Eight Ball permanently gains +0.2x Mult.\n\nOn a shot containing at least one Tap milestone, it applies its current xMult. The current shot benefits from the growth it creates.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"tap_hybrid_xmult_one_two_punch": {
		"eight_ball_item_id": "tap_hybrid_xmult_one_two_punch",
		"display_name": "One-Two Punch",
		"family_id": "tap_oddity",
		"offer_family": "tap_hybrid",
		"trigger_ids": TAP_TRIGGER_IDS,
		"required_trigger_ids": TAP_TRIGGER_IDS,
		"minimum_trigger_count_by_id": {
			TRIGGER_CUE_RECONTACT: 1,
			TRIGGER_OBJECT_BALL_TAP: 1,
		},
		"effect_kind": EFFECT_KIND_CROSS_FAMILY_CONDITIONAL,
		"condition_scope": "same_scoring_ball",
		"modifier_phase": PHASE_XMULT,
		"application_phase": PHASE_XMULT,
		"application_scope": "once_per_qualifying_scoring_ball",
		"value": 2.0,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Double Tap + Ball Tap on one ball: x2 Mult",
		"tooltip": "Whenever the same scoring ball earns at least one cue-recontact milestone and at least one Ball Tap milestone before pocketing, multiply Mult by 2.\n\nTriggers once for each qualifying scoring ball.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"tap_ordinal_xmult_aftershock": {
		"eight_ball_item_id": "tap_ordinal_xmult_aftershock",
		"display_name": "Aftershock",
		"family_id": "tap_oddity",
		"offer_family": "tap_escalation",
		"trigger_ids": TAP_TRIGGER_IDS,
		"effect_kind": EFFECT_KIND_SHOT_ORDINAL_MULTIPLIER,
		"ordinal_scope": "shot",
		"ordinal_order_fields": ["event_index", "trigger_occurrence_id"],
		"ignored_leading_triggers": 1,
		"first_activating_ordinal": 2,
		"modifier_phase": PHASE_XMULT,
		"application_phase": PHASE_XMULT,
		"application_scope": "per_trigger_from_ordinal",
		"value": 1.25,
		"rarity": RARITY_RARE,
		"offer_weight": OFFER_WEIGHT_RARE,
		"eligibility": {"exclude_when_owned": true},
		"short_effect": "Each Tap after the first: x1.25 Mult",
		"tooltip": "The first Tap milestone in a shot does not activate this Eight Ball.\n\nEvery Tap milestone after the first multiplies Mult by 1.25. The count resets every shot.",
		"icon_key": ICON_KEY_PLACEHOLDER,
	},
	"tap_legendary_retrigger_echo_chamber": {
		"eight_ball_item_id": ECHO_CHAMBER_ITEM_ID,
		"display_name": "Echo Chamber",
		"family_id": "tap_oddity",
		"offer_family": "tap_retrigger",
		"trigger_ids": TAP_TRIGGER_IDS,
		"effect_kind": EFFECT_KIND_THRESHOLD_FAMILY_RETRIGGER,
		"threshold": 3,
		"threshold_interval": 3,
		"threshold_scope": "shot",
		"application_phase": "source_modifier_phase",
		"application_scope": "every_threshold_milestone",
		"matching_family_by_trigger_id": {
			TRIGGER_CUE_RECONTACT: "double_tap",
			TRIGGER_OBJECT_BALL_TAP: "ball_tap",
		},
		"retrigger_effect_kinds": [EFFECT_KIND_NUMERIC_MODIFIER],
		"retrigger_regular_items_only": true,
		"maximum_retrigger_generation": 1,
		"rarity": RARITY_LEGENDARY,
		"offer_weight": OFFER_WEIGHT_LEGENDARY,
		"eligibility": {
			"exclude_when_owned": true,
			"requires_owned_any_item_ids": REGULAR_TAP_ITEM_IDS,
			"requires_owned_any_family_ids": ["double_tap", "ball_tap"],
			"unmet_reason": "Requires at least one regular Tap Eight Ball.",
			"retained_without_support_warning": "Echo Chamber currently has no regular Tap Eight Ball to retrigger.",
		},
		"short_effect": "Every third Tap retriggers matching Tap Eight Balls",
		"tooltip": "Every third Tap milestone in a shot causes your regular Tap Eight Balls that match that milestone to trigger one additional time.\n\nThe count resets every shot. Echo Chamber does not retrigger itself, unusual Tap Eight Balls, base scoring, or another retrigger.",
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
	var offer_family_counts: Dictionary = {}
	var effect_kind_counts: Dictionary = {}
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
		var offer_family: String = str(definition.get("offer_family", family_id))
		offer_family_counts[offer_family] = int(offer_family_counts.get(offer_family, 0)) + 1
		var effect_kind: String = str(definition.get(
			"effect_kind",
			EFFECT_KIND_NUMERIC_MODIFIER
		))
		effect_kind_counts[effect_kind] = int(effect_kind_counts.get(effect_kind, 0)) + 1
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
		"double_tap": 3,
		"ball_tap": 3,
		"tap_oddity": 4,
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
	if legendary_count != 2:
		failures.append("Catalog expected 2 Legendary items, received %d." % legendary_count)

	var expected_tap_offer_family_counts: Dictionary = {
		"double_tap": 3,
		"ball_tap": 3,
		"tap_growth": 1,
		"tap_hybrid": 1,
		"tap_escalation": 1,
		"tap_retrigger": 1,
	}
	for offer_family_value in expected_tap_offer_family_counts.keys():
		var offer_family: String = str(offer_family_value)
		var expected_count: int = int(expected_tap_offer_family_counts[offer_family])
		var actual_count: int = int(offer_family_counts.get(offer_family, 0))
		if actual_count != expected_count:
			failures.append(
				"Offer family %s expected %d items, received %d."
				% [offer_family, expected_count, actual_count]
			)

	return {
		"catalog_version": CATALOG_VERSION,
		"definition_count": _DEFINITIONS.size(),
		"expected_definition_count": EXPECTED_DEFINITION_COUNT,
		"family_counts": family_counts.duplicate(true),
		"offer_family_counts": offer_family_counts.duplicate(true),
		"effect_kind_counts": effect_kind_counts.duplicate(true),
		"legendary_count": legendary_count,
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

	var trigger_ids: Array[String] = _get_definition_trigger_ids(definition)
	_validate_trigger_ids(eight_ball_item_id, trigger_ids, failures)

	var effect_kind: String = str(definition.get(
		"effect_kind",
		EFFECT_KIND_NUMERIC_MODIFIER
	))
	match effect_kind:
		EFFECT_KIND_NUMERIC_MODIFIER:
			_validate_modifier_definition(eight_ball_item_id, definition, failures)
		EFFECT_KIND_PERSISTENT_SCALER:
			_validate_persistent_scaler_definition(eight_ball_item_id, definition, failures)
		EFFECT_KIND_CROSS_FAMILY_CONDITIONAL:
			_validate_cross_family_definition(eight_ball_item_id, definition, failures)
		EFFECT_KIND_SHOT_ORDINAL_MULTIPLIER:
			_validate_shot_ordinal_definition(eight_ball_item_id, definition, failures)
		EFFECT_KIND_THRESHOLD_FAMILY_RETRIGGER:
			_validate_threshold_retrigger_definition(eight_ball_item_id, definition, failures)
		EFFECT_KIND_RETRIGGER_FAMILY:
			_validate_retrigger_definition(eight_ball_item_id, definition, failures)
		_:
			failures.append("%s has unknown effect_kind %s." % [eight_ball_item_id, effect_kind])

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
		"double_tap": TRIGGER_CUE_RECONTACT,
		"ball_tap": TRIGGER_OBJECT_BALL_TAP,
	}
	var family_id: String = str(definition.get("family_id", ""))
	if family_id == "tap_oddity":
		if trigger_ids.is_empty() or not _is_subset_of(trigger_ids, TAP_TRIGGER_IDS):
			failures.append("%s must use only trusted Tap trigger IDs." % eight_ball_item_id)
	elif not expected_trigger_by_family.has(family_id):
		failures.append("%s has invalid family_id %s." % [eight_ball_item_id, family_id])
	elif trigger_ids != [str(expected_trigger_by_family[family_id])]:
		failures.append("%s family and trigger do not agree." % eight_ball_item_id)

	if family_id in ["double_tap", "ball_tap", "tap_oddity"]:
		if str(definition.get("offer_family", "")).is_empty():
			failures.append("%s has no Tap offer_family metadata." % eight_ball_item_id)
		if not definition.get("eligibility", {}) is Dictionary:
			failures.append("%s has invalid eligibility metadata." % eight_ball_item_id)
	if family_id in ["double_tap", "ball_tap"]:
		if effect_kind != EFFECT_KIND_NUMERIC_MODIFIER:
			failures.append("%s must be a numeric Tap modifier." % eight_ball_item_id)
		if str(definition.get("offer_family", "")) != family_id:
			failures.append("%s must use its Tap family as offer_family." % eight_ball_item_id)
		if str(definition.get("application_scope", "")) != "per_trigger_occurrence":
			failures.append("%s must apply once per Tap trigger occurrence." % eight_ball_item_id)


static func _get_definition_trigger_ids(definition: Dictionary) -> Array[String]:
	var trigger_ids: Array[String] = []
	var trigger_ids_value: Variant = definition.get("trigger_ids", [])
	if trigger_ids_value is Array:
		for trigger_id_value in trigger_ids_value:
			var trigger_id: String = str(trigger_id_value)
			if not trigger_id.is_empty() and trigger_id not in trigger_ids:
				trigger_ids.append(trigger_id)
	var legacy_trigger_id: String = str(definition.get("trigger_id", ""))
	if trigger_ids.is_empty() and not legacy_trigger_id.is_empty():
		trigger_ids.append(legacy_trigger_id)
	return trigger_ids


static func _validate_trigger_ids(
	eight_ball_item_id: String,
	trigger_ids: Array[String],
	failures: Array[String]
) -> void:
	if trigger_ids.is_empty():
		failures.append("%s has no trigger IDs." % eight_ball_item_id)
		return
	var supported_trigger_ids: Array[String] = [
		TRIGGER_SINGLE_BANK,
		TRIGGER_DOUBLE_BANK,
		TRIGGER_TRIPLE_BANK,
		TRIGGER_COMBINATION,
		TRIGGER_DIRECT_POT,
		TRIGGER_MULTI_POT,
		TRIGGER_SAME_POCKET,
		TRIGGER_CUE_RECONTACT,
		TRIGGER_OBJECT_BALL_TAP,
	]
	for trigger_id in trigger_ids:
		if trigger_id not in supported_trigger_ids:
			failures.append("%s has invalid trigger ID %s." % [eight_ball_item_id, trigger_id])


static func _is_subset_of(values: Array[String], allowed_values: Array[String]) -> bool:
	for value in values:
		if value not in allowed_values:
			return false
	return true


static func _has_same_string_values(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	return _is_subset_of(left, right) and _is_subset_of(right, left)


static func _string_array_value(source: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var values: Variant = source.get(key, [])
	if not values is Array:
		return result
	for value in values:
		var text: String = str(value)
		if not text.is_empty() and text not in result:
			result.append(text)
	return result


static func _validate_persistent_scaler_definition(
	eight_ball_item_id: String,
	definition: Dictionary,
	failures: Array[String]
) -> void:
	if eight_ball_item_id != "tap_stateful_xmult_rattle_of_the_deep":
		failures.append("%s is an unknown persistent scaler." % eight_ball_item_id)
	if not _has_same_string_values(_get_definition_trigger_ids(definition), TAP_TRIGGER_IDS):
		failures.append("%s must grow from both trusted Tap trigger families." % eight_ball_item_id)
	if str(definition.get("modifier_phase", "")) != PHASE_XMULT:
		failures.append("%s must resolve in the xMult phase." % eight_ball_item_id)
	if str(definition.get("application_phase", "")) != PHASE_XMULT:
		failures.append("%s has invalid application_phase." % eight_ball_item_id)
	if str(definition.get("application_scope", "")) != "once_per_qualifying_shot":
		failures.append("%s must apply once per qualifying shot." % eight_ball_item_id)
	if int(definition.get("state_schema_version", 0)) != 1:
		failures.append("%s must use state schema version 1." % eight_ball_item_id)
	var state_defaults_value: Variant = definition.get("state_defaults", {})
	if not state_defaults_value is Dictionary:
		failures.append("%s has invalid state_defaults." % eight_ball_item_id)
	else:
		var state_defaults: Dictionary = state_defaults_value as Dictionary
		if int(state_defaults.get("state_version", 0)) != 1:
			failures.append("%s has an invalid default state version." % eight_ball_item_id)
		if not is_equal_approx(float(state_defaults.get("current_xmult", 0.0)), 1.0):
			failures.append("%s must start at x1 Mult." % eight_ball_item_id)
		if int(state_defaults.get("lifetime_growth_triggers", -1)) != 0:
			failures.append("%s must start with zero lifetime growth triggers." % eight_ball_item_id)
		if int(state_defaults.get("shots_activated", -1)) != 0:
			failures.append("%s must start with zero activated shots." % eight_ball_item_id)
	if not is_equal_approx(float(definition.get("starting_value", 0.0)), 1.0):
		failures.append("%s must declare starting_value 1.0." % eight_ball_item_id)
	if not is_equal_approx(float(definition.get("growth_per_trigger", 0.0)), 0.2):
		failures.append("%s must grow by 0.2 per Tap." % eight_ball_item_id)
	if not bool(definition.get("uses_post_growth_value", false)):
		failures.append("%s must apply its post-growth value." % eight_ball_item_id)
	if definition.has("value"):
		failures.append("%s must derive xMult from owned-item state." % eight_ball_item_id)


static func _validate_cross_family_definition(
	eight_ball_item_id: String,
	definition: Dictionary,
	failures: Array[String]
) -> void:
	if eight_ball_item_id != "tap_hybrid_xmult_one_two_punch":
		failures.append("%s is an unknown cross-family conditional." % eight_ball_item_id)
	_validate_modifier_definition(eight_ball_item_id, definition, failures)
	if not _has_same_string_values(_get_definition_trigger_ids(definition), TAP_TRIGGER_IDS):
		failures.append("%s must inspect both trusted Tap trigger families." % eight_ball_item_id)
	if not _has_same_string_values(
		_string_array_value(definition, "required_trigger_ids"),
		TAP_TRIGGER_IDS
	):
		failures.append("%s must require both Tap trigger families." % eight_ball_item_id)
	if str(definition.get("condition_scope", "")) != "same_scoring_ball":
		failures.append("%s must qualify Tap families on the same scoring ball." % eight_ball_item_id)
	if str(definition.get("application_scope", "")) != "once_per_qualifying_scoring_ball":
		failures.append("%s has invalid application_scope." % eight_ball_item_id)
	var minimums_value: Variant = definition.get("minimum_trigger_count_by_id", {})
	if not minimums_value is Dictionary:
		failures.append("%s has invalid trigger minimums." % eight_ball_item_id)
	else:
		var minimums: Dictionary = minimums_value as Dictionary
		for trigger_id in TAP_TRIGGER_IDS:
			if int(minimums.get(trigger_id, 0)) != 1:
				failures.append("%s must require one %s." % [eight_ball_item_id, trigger_id])


static func _validate_shot_ordinal_definition(
	eight_ball_item_id: String,
	definition: Dictionary,
	failures: Array[String]
) -> void:
	if eight_ball_item_id != "tap_ordinal_xmult_aftershock":
		failures.append("%s is an unknown shot-ordinal multiplier." % eight_ball_item_id)
	_validate_modifier_definition(eight_ball_item_id, definition, failures)
	if not _has_same_string_values(_get_definition_trigger_ids(definition), TAP_TRIGGER_IDS):
		failures.append("%s must order both trusted Tap trigger families." % eight_ball_item_id)
	if str(definition.get("ordinal_scope", "")) != "shot":
		failures.append("%s must reset its ordinal each shot." % eight_ball_item_id)
	if int(definition.get("ignored_leading_triggers", -1)) != 1:
		failures.append("%s must ignore the first Tap milestone." % eight_ball_item_id)
	if int(definition.get("first_activating_ordinal", 0)) != 2:
		failures.append("%s must begin activating at Tap ordinal 2." % eight_ball_item_id)
	if str(definition.get("application_scope", "")) != "per_trigger_from_ordinal":
		failures.append("%s has invalid application_scope." % eight_ball_item_id)


static func _validate_threshold_retrigger_definition(
	eight_ball_item_id: String,
	definition: Dictionary,
	failures: Array[String]
) -> void:
	if eight_ball_item_id != ECHO_CHAMBER_ITEM_ID:
		failures.append("%s is an unknown threshold-family retrigger." % eight_ball_item_id)
	if not _has_same_string_values(_get_definition_trigger_ids(definition), TAP_TRIGGER_IDS):
		failures.append("%s must count both trusted Tap trigger families." % eight_ball_item_id)
	if int(definition.get("threshold", 0)) != 3:
		failures.append("%s must use threshold 3." % eight_ball_item_id)
	if int(definition.get("threshold_interval", 0)) != 3:
		failures.append("%s must retrigger every third Tap." % eight_ball_item_id)
	if str(definition.get("threshold_scope", "")) != "shot":
		failures.append("%s must reset its threshold count each shot." % eight_ball_item_id)
	if str(definition.get("application_phase", "")) != "source_modifier_phase":
		failures.append("%s must preserve each source modifier phase." % eight_ball_item_id)
	if int(definition.get("maximum_retrigger_generation", 0)) != 1:
		failures.append("%s must cap retriggers at one generation." % eight_ball_item_id)
	if str(definition.get("rarity", "")) != RARITY_LEGENDARY:
		failures.append("%s must use Legendary rarity." % eight_ball_item_id)
	if definition.has("value") or definition.has("modifier_phase"):
		failures.append("%s must not masquerade as a numeric modifier." % eight_ball_item_id)
	var family_map_value: Variant = definition.get("matching_family_by_trigger_id", {})
	if not family_map_value is Dictionary:
		failures.append("%s has invalid matching-family metadata." % eight_ball_item_id)
	else:
		var family_map: Dictionary = family_map_value as Dictionary
		if str(family_map.get(TRIGGER_CUE_RECONTACT, "")) != "double_tap":
			failures.append("%s must map cue recontacts to double_tap." % eight_ball_item_id)
		if str(family_map.get(TRIGGER_OBJECT_BALL_TAP, "")) != "ball_tap":
			failures.append("%s must map object taps to ball_tap." % eight_ball_item_id)
	var eligibility_value: Variant = definition.get("eligibility", {})
	if not eligibility_value is Dictionary:
		failures.append("%s has invalid eligibility metadata." % eight_ball_item_id)
	else:
		var eligibility: Dictionary = eligibility_value as Dictionary
		var required_support: Array[String] = _string_array_value(
			eligibility,
			"requires_owned_any_item_ids"
		)
		if not _has_same_string_values(required_support, REGULAR_TAP_ITEM_IDS):
			failures.append("%s must require any regular Tap Eight Ball." % eight_ball_item_id)


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
