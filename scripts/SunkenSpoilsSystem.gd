extends Node
class_name SunkenSpoilsSystem

signal spoils_changed(snapshot: Dictionary)
signal status_changed(text: String)
signal reward_claimed(reward_id: String, reward_label: String)

const MILESTONES := [1, 3, 7, 12, 18, 25, 35, 50]
const OFFER_COUNT := 3
const REROLL_BASE_COST := 15.0
const REROLL_MILESTONE_MULTIPLIER := 1.6
const REROLL_REPEAT_MULTIPLIER := 2.0

const TIER_EARLY := "early"
const TIER_MID := "mid"
const TIER_LATE := "late"

const REWARD_DOUBLOONS_25 := "doubloons_25"
const REWARD_DOUBLOONS_50 := "doubloons_50"
const REWARD_DOUBLOONS_100 := "doubloons_100"
const REWARD_INTERVENTION_CHARGE := "intervention_charge_1"
const REWARD_OBJECT_BALL_X3 := "object_ball_x3"
const REWARD_OBJECT_BALL_X10 := "object_ball_x10"
const REWARD_WAYFINDER_X1 := "wayfinder_x1"
const REWARD_WAYFINDER_X2 := "wayfinder_x2"
const REWARD_POWDER_KEG_X1 := "powder_keg_x1"
const REWARD_POWDER_KEG_X2 := "powder_keg_x2"
const REWARD_PASSAGE_150 := "passage_150"
const REWARD_PASSAGE_300 := "passage_300"
const REWARD_FREE_REFRESH := "free_quartermaster_refresh"

const REWARD_TYPE_DOUBLOONS := "doubloons"
const REWARD_TYPE_INTERVENTION_CHARGE := "intervention_charge"
const REWARD_TYPE_RESERVE_ITEM := "reserve_item"
const REWARD_TYPE_PASSAGE_REDUCTION := "passage_reduction"
const REWARD_TYPE_FREE_REFRESH := "free_refresh"

const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"
const FIRST_MILESTONE_FRIENDLY_REWARD_IDS := [
	REWARD_DOUBLOONS_25,
	REWARD_DOUBLOONS_50,
	REWARD_INTERVENTION_CHARGE,
	REWARD_OBJECT_BALL_X3,
]

const REWARD_DEFINITIONS := {
	REWARD_DOUBLOONS_25: {
		"id": REWARD_DOUBLOONS_25,
		"label": "+25 Doubloons",
		"display_label": "Loose Coin",
		"description": "The table spits up a small purse.",
		"type": REWARD_TYPE_DOUBLOONS,
		"amount": 25,
		"weight": 6,
		"rarity": RARITY_COMMON,
	},
	REWARD_DOUBLOONS_50: {
		"id": REWARD_DOUBLOONS_50,
		"label": "+50 Doubloons",
		"display_label": "Coin Purse",
		"description": "A better purse rises from the deep felt.",
		"type": REWARD_TYPE_DOUBLOONS,
		"amount": 50,
		"weight": 5,
		"rarity": RARITY_COMMON,
	},
	REWARD_DOUBLOONS_100: {
		"id": REWARD_DOUBLOONS_100,
		"label": "+100 Doubloons",
		"display_label": "Heavy Purse",
		"description": "A heavy purse clinks onto the rail.",
		"type": REWARD_TYPE_DOUBLOONS,
		"amount": 100,
		"weight": 3,
		"rarity": RARITY_RARE,
	},
	REWARD_INTERVENTION_CHARGE: {
		"id": REWARD_INTERVENTION_CHARGE,
		"label": "+1 Intervention Charge",
		"display_label": "Kraken's Mark",
		"description": "The Kraken marks another bargain.",
		"type": REWARD_TYPE_INTERVENTION_CHARGE,
		"amount": 1,
		"weight": 3,
		"rarity": RARITY_UNCOMMON,
	},
	REWARD_OBJECT_BALL_X3: {
		"id": REWARD_OBJECT_BALL_X3,
		"label": "Object Ball x3",
		"display_label": "Loose Cargo Stack",
		"description": "Stow three regular balls in one Reserve slot.",
		"type": REWARD_TYPE_RESERVE_ITEM,
		"spawn_type": "plain_object_ball",
		"icon_key": "plain_object_ball",
		"quantity": 3,
		"weight": 5,
		"rarity": RARITY_COMMON,
	},
	REWARD_OBJECT_BALL_X10: {
		"id": REWARD_OBJECT_BALL_X10,
		"label": "Object Ball x10",
		"display_label": "Cargo Spill",
		"description": "Stow ten regular balls in one Reserve slot.",
		"type": REWARD_TYPE_RESERVE_ITEM,
		"spawn_type": "plain_object_ball",
		"icon_key": "plain_object_ball",
		"quantity": 10,
		"weight": 2,
		"rarity": RARITY_RARE,
	},
	REWARD_WAYFINDER_X1: {
		"id": REWARD_WAYFINDER_X1,
		"label": "Wayfinder Ball x1",
		"display_label": "Wayfinder's Glint",
		"description": "Stow one Wayfinder Ball in Reserve.",
		"type": REWARD_TYPE_RESERVE_ITEM,
		"spawn_type": "wayfinder_ball",
		"icon_key": "wayfinder_ball",
		"quantity": 1,
		"weight": 4,
		"rarity": RARITY_UNCOMMON,
	},
	REWARD_WAYFINDER_X2: {
		"id": REWARD_WAYFINDER_X2,
		"label": "Wayfinder Ball x2",
		"display_label": "Twin Wayfinders",
		"description": "Stow two Wayfinder Balls in one Reserve slot.",
		"type": REWARD_TYPE_RESERVE_ITEM,
		"spawn_type": "wayfinder_ball",
		"icon_key": "wayfinder_ball",
		"quantity": 2,
		"weight": 2,
		"rarity": RARITY_RARE,
	},
	REWARD_POWDER_KEG_X1: {
		"id": REWARD_POWDER_KEG_X1,
		"label": "Powder Keg x1",
		"display_label": "Powder Gift",
		"description": "Stow one Powder Keg in Reserve.",
		"type": REWARD_TYPE_RESERVE_ITEM,
		"spawn_type": "powder_keg_ball",
		"icon_key": "powder_keg_ball",
		"quantity": 1,
		"weight": 4,
		"rarity": RARITY_UNCOMMON,
	},
	REWARD_POWDER_KEG_X2: {
		"id": REWARD_POWDER_KEG_X2,
		"label": "Powder Keg x2",
		"display_label": "Powder Pair",
		"description": "Stow two Powder Kegs in one Reserve slot.",
		"type": REWARD_TYPE_RESERVE_ITEM,
		"spawn_type": "powder_keg_ball",
		"icon_key": "powder_keg_ball",
		"quantity": 2,
		"weight": 2,
		"rarity": RARITY_RARE,
	},
	REWARD_PASSAGE_150: {
		"id": REWARD_PASSAGE_150,
		"label": "-150 Passage",
		"display_label": "Favorable Current",
		"description": "The Kraken accepts a little less.",
		"type": REWARD_TYPE_PASSAGE_REDUCTION,
		"amount": 150,
		"weight": 3,
		"rarity": RARITY_UNCOMMON,
	},
	REWARD_PASSAGE_300: {
		"id": REWARD_PASSAGE_300,
		"label": "-300 Passage",
		"display_label": "Deep Current",
		"description": "The bargain becomes easier to bear.",
		"type": REWARD_TYPE_PASSAGE_REDUCTION,
		"amount": 300,
		"weight": 2,
		"rarity": RARITY_RARE,
	},
	REWARD_FREE_REFRESH: {
		"id": REWARD_FREE_REFRESH,
		"label": "Free Quartermaster Refresh",
		"display_label": "Fresh Stock",
		"description": "Refresh Quartermaster stock without spending Doubloons.",
		"type": REWARD_TYPE_FREE_REFRESH,
		"weight": 2,
		"rarity": RARITY_UNCOMMON,
	},
}

const TIER_REWARD_POOLS := {
	TIER_EARLY: [
		REWARD_DOUBLOONS_25,
		REWARD_DOUBLOONS_50,
		REWARD_INTERVENTION_CHARGE,
		REWARD_OBJECT_BALL_X3,
		REWARD_WAYFINDER_X1,
		REWARD_POWDER_KEG_X1,
		REWARD_PASSAGE_150,
	],
	TIER_MID: [
		REWARD_DOUBLOONS_50,
		REWARD_DOUBLOONS_100,
		REWARD_INTERVENTION_CHARGE,
		REWARD_OBJECT_BALL_X3,
		REWARD_OBJECT_BALL_X10,
		REWARD_WAYFINDER_X1,
		REWARD_WAYFINDER_X2,
		REWARD_POWDER_KEG_X1,
		REWARD_POWDER_KEG_X2,
		REWARD_PASSAGE_150,
		REWARD_PASSAGE_300,
		REWARD_FREE_REFRESH,
	],
	TIER_LATE: [
		REWARD_DOUBLOONS_100,
		REWARD_INTERVENTION_CHARGE,
		REWARD_OBJECT_BALL_X10,
		REWARD_WAYFINDER_X2,
		REWARD_POWDER_KEG_X2,
		REWARD_PASSAGE_300,
		REWARD_FREE_REFRESH,
	],
}

var table: BilliardsTable
var rng := RandomNumberGenerator.new()
var current_milestone_index := 0
var current_milestone_progress := 0
var pending_reward_available := false
var pending_reward_ready := false
var active_reward_offer_ids: Array[String] = []
var doubloon_rerolls_this_menu := 0
var total_doubloon_rerolls := 0
var doubloons_spent_on_rerolls := 0
var rewards_claimed := 0
var cast_backs_used := 0
var qualifying_sinks_tracked := 0
var final_milestone_repeats := 0
var last_status := ""


func _ready() -> void:
	rng.randomize()


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	_reset_spoils_state()
	_emit_changed()


func debug_advance_progress(amount: int = 1) -> bool:
	if pending_reward_available:
		_set_status("Debug Spoils skipped: reward already pending.")
		_emit_changed()
		return false

	var advance_amount: int = maxi(amount, 1)
	qualifying_sinks_tracked += advance_amount
	current_milestone_progress = mini(current_milestone_progress + advance_amount, _get_current_milestone_required())
	if current_milestone_progress >= _get_current_milestone_required():
		_prepare_pending_reward()
		pending_reward_ready = true
		_set_status("The table coughs up sunken spoils.")
	else:
		_set_status("Debug Spoils progress advanced.")
	_emit_changed()
	return true


func debug_trigger_reward() -> bool:
	if not pending_reward_available:
		current_milestone_progress = _get_current_milestone_required()
		_prepare_pending_reward()
	pending_reward_ready = true
	_set_status("The table coughs up sunken spoils.")
	_emit_changed()
	return true


func debug_reset_spoils() -> void:
	_reset_spoils_state()
	_set_status("Debug Sunken Spoils reset.")
	_emit_changed()


func _reset_spoils_state() -> void:
	current_milestone_index = 0
	current_milestone_progress = 0
	pending_reward_available = false
	pending_reward_ready = false
	active_reward_offer_ids.clear()
	doubloon_rerolls_this_menu = 0
	total_doubloon_rerolls = 0
	doubloons_spent_on_rerolls = 0
	rewards_claimed = 0
	cast_backs_used = 0
	qualifying_sinks_tracked = 0
	final_milestone_repeats = 0
	last_status = ""


func record_qualifying_object_ball_sunk(_ball: Ball) -> void:
	if pending_reward_available:
		return

	qualifying_sinks_tracked += 1
	current_milestone_progress = mini(current_milestone_progress + 1, _get_current_milestone_required())
	if current_milestone_progress >= _get_current_milestone_required():
		_prepare_pending_reward()
	_emit_changed()


func handle_shot_resolved() -> void:
	if not pending_reward_available or pending_reward_ready:
		return

	pending_reward_ready = true
	_set_status("The table coughs up sunken spoils.")
	_emit_changed()


func get_spoils_snapshot() -> Dictionary:
	return {
		"milestones": MILESTONES.duplicate(),
		"current_milestone_index": current_milestone_index,
		"current_milestone_required": _get_current_milestone_required(),
		"current_milestone_progress": current_milestone_progress,
		"current_milestone_tier": _get_current_tier(),
		"pending_reward_available": pending_reward_available,
		"pending_reward_ready": pending_reward_ready,
		"reward_offers": _get_reward_offer_snapshots(),
		"current_reroll_cost": get_current_doubloon_reroll_cost(),
		"base_reroll_cost": _get_base_doubloon_reroll_cost(),
		"doubloon_rerolls_this_menu": doubloon_rerolls_this_menu,
		"can_afford_doubloon_reroll": _can_afford_doubloon_reroll(),
		"doubloon_reroll_blocked_reason": _get_doubloon_reroll_blocker(),
		"final_milestone_repeats": final_milestone_repeats,
		"qualifying_sinks_tracked": qualifying_sinks_tracked,
		"rewards_claimed": rewards_claimed,
		"cast_backs_used": cast_backs_used,
		"total_doubloon_rerolls": total_doubloon_rerolls,
		"doubloons_spent_on_rerolls": doubloons_spent_on_rerolls,
		"last_status": last_status,
	}


func get_rewind_state() -> Dictionary:
	return {
		"current_milestone_index": current_milestone_index,
		"current_milestone_progress": current_milestone_progress,
		"pending_reward_available": pending_reward_available,
		"pending_reward_ready": pending_reward_ready,
		"active_reward_offer_ids": active_reward_offer_ids.duplicate(),
		"doubloon_rerolls_this_menu": doubloon_rerolls_this_menu,
		"total_doubloon_rerolls": total_doubloon_rerolls,
		"doubloons_spent_on_rerolls": doubloons_spent_on_rerolls,
		"rewards_claimed": rewards_claimed,
		"cast_backs_used": cast_backs_used,
		"qualifying_sinks_tracked": qualifying_sinks_tracked,
		"final_milestone_repeats": final_milestone_repeats,
		"last_status": last_status,
		"rng_state": int(rng.state),
	}


func restore_rewind_state(state: Dictionary) -> void:
	current_milestone_index = maxi(int(state.get("current_milestone_index", 0)), 0)
	current_milestone_progress = maxi(int(state.get("current_milestone_progress", 0)), 0)
	pending_reward_available = bool(state.get("pending_reward_available", false))
	pending_reward_ready = bool(state.get("pending_reward_ready", false))
	active_reward_offer_ids.clear()
	var offers_value: Variant = state.get("active_reward_offer_ids", [])
	if offers_value is Array:
		for offer_id_value in offers_value:
			active_reward_offer_ids.append(str(offer_id_value))
	doubloon_rerolls_this_menu = maxi(int(state.get("doubloon_rerolls_this_menu", 0)), 0)
	total_doubloon_rerolls = maxi(int(state.get("total_doubloon_rerolls", 0)), 0)
	doubloons_spent_on_rerolls = maxi(int(state.get("doubloons_spent_on_rerolls", 0)), 0)
	rewards_claimed = maxi(int(state.get("rewards_claimed", 0)), 0)
	cast_backs_used = maxi(int(state.get("cast_backs_used", 0)), 0)
	qualifying_sinks_tracked = maxi(int(state.get("qualifying_sinks_tracked", 0)), 0)
	final_milestone_repeats = maxi(int(state.get("final_milestone_repeats", 0)), 0)
	last_status = str(state.get("last_status", ""))
	rng.state = int(state.get("rng_state", rng.state))
	_emit_changed()


func get_debug_snapshot() -> Dictionary:
	return get_spoils_snapshot()


func get_current_doubloon_reroll_cost() -> int:
	var base_cost: int = _get_base_doubloon_reroll_cost()
	return maxi(roundi(float(base_cost) * pow(REROLL_REPEAT_MULTIPLIER, float(doubloon_rerolls_this_menu))), 0)


func request_doubloon_reroll() -> bool:
	var blocker: String = _get_doubloon_reroll_blocker()
	if not blocker.is_empty():
		_set_status(blocker)
		_emit_changed()
		return false

	var cost: int = get_current_doubloon_reroll_cost()
	if not table.score_system.try_spend_doubloons(cost):
		_set_status("Not enough Doubloons")
		_emit_changed()
		return false

	var previous_offer_ids: Array = active_reward_offer_ids.duplicate()
	active_reward_offer_ids = _generate_reward_offer_ids(previous_offer_ids)
	doubloon_rerolls_this_menu += 1
	total_doubloon_rerolls += 1
	doubloons_spent_on_rerolls += cost
	_set_status("The spoils shift beneath the felt.")
	_emit_changed()
	return true


func cast_back() -> bool:
	if not pending_reward_available:
		return false

	pending_reward_available = false
	pending_reward_ready = false
	active_reward_offer_ids.clear()
	doubloon_rerolls_this_menu = 0
	current_milestone_progress = 0
	cast_backs_used += 1
	_set_status("You cast the prize back into the deep.")
	_emit_changed()
	return true


func claim_reward(reward_id: String) -> bool:
	if not pending_reward_available or not pending_reward_ready:
		_set_status("Sunken Spoils are not ready.")
		_emit_changed()
		return false
	if not active_reward_offer_ids.has(reward_id):
		_set_status("Unknown Sunken Spoils reward.")
		_emit_changed()
		return false

	var definition: Dictionary = _get_reward_definition(reward_id)
	var blocker: String = _get_reward_blocker(definition)
	if not blocker.is_empty():
		_set_status(blocker)
		_emit_changed()
		return false

	if not _apply_reward(definition):
		_emit_changed()
		return false

	var label: String = _get_reward_display_label(definition)
	rewards_claimed += 1
	reward_claimed.emit(reward_id, label)
	_advance_milestone_after_claim()
	_set_status("You claim the table's offering.")
	_emit_changed()
	return true


func _prepare_pending_reward() -> void:
	pending_reward_available = true
	pending_reward_ready = false
	doubloon_rerolls_this_menu = 0
	var empty_previous_offers: Array = []
	active_reward_offer_ids = _generate_reward_offer_ids(empty_previous_offers)


func _advance_milestone_after_claim() -> void:
	pending_reward_available = false
	pending_reward_ready = false
	active_reward_offer_ids.clear()
	doubloon_rerolls_this_menu = 0
	current_milestone_progress = 0
	current_milestone_index += 1
	if current_milestone_index >= MILESTONES.size():
		final_milestone_repeats += 1


func _generate_reward_offer_ids(previous_offer_ids: Array) -> Array[String]:
	var generated: Array[String] = []
	var best_attempt: Array[String] = []
	for attempt_index in range(8):
		var attempt: Array[String] = _pick_weighted_unique_rewards()
		if best_attempt.is_empty():
			best_attempt = attempt
		if not _is_same_reward_set(attempt, previous_offer_ids):
			generated = attempt
			break
	if generated.is_empty():
		generated = best_attempt
	return _ensure_first_milestone_friendly_offer(generated)


func _ensure_first_milestone_friendly_offer(offer_ids: Array[String]) -> Array[String]:
	if current_milestone_index != 0:
		return offer_ids
	for reward_id in offer_ids:
		if FIRST_MILESTONE_FRIENDLY_REWARD_IDS.has(reward_id):
			return offer_ids

	var candidates: Array = FIRST_MILESTONE_FRIENDLY_REWARD_IDS.duplicate()
	for reward_id in offer_ids:
		candidates.erase(reward_id)
	var friendly_reward_id: String = _pick_weighted_reward_id(candidates)
	if friendly_reward_id.is_empty():
		return offer_ids
	if offer_ids.is_empty():
		offer_ids.append(friendly_reward_id)
	else:
		offer_ids[offer_ids.size() - 1] = friendly_reward_id
	return offer_ids


func _pick_weighted_unique_rewards() -> Array[String]:
	var pool: Array = _get_current_reward_pool()
	var candidates: Array = pool.duplicate()
	var picked: Array[String] = []
	while picked.size() < OFFER_COUNT and not candidates.is_empty():
		var reward_id: String = _pick_weighted_reward_id(candidates)
		if reward_id.is_empty():
			break
		picked.append(reward_id)
		candidates.erase(reward_id)
	return picked


func _pick_weighted_reward_id(candidates: Array) -> String:
	var total_weight: int = 0
	for candidate_value in candidates:
		var candidate_id: String = str(candidate_value)
		total_weight += _get_reward_weight(candidate_id)
	if total_weight <= 0:
		return str(candidates[rng.randi_range(0, candidates.size() - 1)])

	var roll: int = rng.randi_range(1, total_weight)
	var running_weight: int = 0
	for weighted_candidate_value in candidates:
		var weighted_candidate_id: String = str(weighted_candidate_value)
		running_weight += _get_reward_weight(weighted_candidate_id)
		if roll <= running_weight:
			return weighted_candidate_id
	return str(candidates.back())


func _is_same_reward_set(left: Array, right: Array) -> bool:
	if left.size() != right.size():
		return false
	var left_copy: Array = left.duplicate()
	var right_copy: Array = right.duplicate()
	left_copy.sort()
	right_copy.sort()
	for index in range(left_copy.size()):
		if str(left_copy[index]) != str(right_copy[index]):
			return false
	return true


func _get_reward_offer_snapshots() -> Array:
	var offers: Array = []
	for reward_id in active_reward_offer_ids:
		var definition: Dictionary = _get_reward_definition(reward_id)
		if definition.is_empty():
			continue
		var offer: Dictionary = definition.duplicate(true)
		var blocker: String = _get_reward_blocker(definition)
		offer["display_label"] = _get_reward_display_label(definition)
		offer["rarity"] = _get_reward_rarity(definition)
		offer["available"] = blocker.is_empty()
		offer["blocked_reason"] = blocker
		offer["summary"] = _get_reward_summary(definition)
		offers.append(offer)
	return offers


func _apply_reward(definition: Dictionary) -> bool:
	match str(definition.get("type", "")):
		REWARD_TYPE_DOUBLOONS:
			var gained: int = table.score_system.grant_doubloons(int(definition.get("amount", 0)), "Sunken Spoils")
			return gained > 0
		REWARD_TYPE_INTERVENTION_CHARGE:
			var granted: int = table.table_event_system.grant_intervention_charges(int(definition.get("amount", 1)), "Sunken Spoils")
			return granted > 0
		REWARD_TYPE_RESERVE_ITEM:
			var slot_index: int = table.reserve_system.store_item_in_first_empty_slot(_make_reserve_payload(definition))
			return slot_index >= 0
		REWARD_TYPE_PASSAGE_REDUCTION:
			var reduction: int = table.passage_system.reduce_passage_from_spoils(int(definition.get("amount", 0)))
			return reduction > 0
		REWARD_TYPE_FREE_REFRESH:
			return table.quartermaster_system.request_free_refresh_stock("Sunken Spoils")
	_set_status("Sunken Spoils reward failed.")
	return false


func _make_reserve_payload(definition: Dictionary) -> Dictionary:
	var quantity: int = maxi(int(definition.get("quantity", 1)), 1)
	var label: String = _get_reward_display_label(definition)
	return {
		"item_id": "spoils_%s" % str(definition.get("id", "")),
		"item_name": label,
		"display_name": label,
		"description": str(definition.get("description", "")),
		"price": 0,
		"spawn_type": str(definition.get("spawn_type", "")),
		"icon_key": str(definition.get("icon_key", definition.get("spawn_type", ""))),
		"source": "sunken_spoils",
		"quantity": quantity,
		"quantity_total": quantity,
	}


func _get_reward_blocker(definition: Dictionary) -> String:
	if table == null:
		return "Sunken Spoils not ready"
	match str(definition.get("type", "")):
		REWARD_TYPE_DOUBLOONS:
			return "" if table.score_system != null else "Score system not ready"
		REWARD_TYPE_INTERVENTION_CHARGE:
			return "" if table.table_event_system != null else "Kraken Intervention not ready"
		REWARD_TYPE_RESERVE_ITEM:
			if table.reserve_system == null:
				return "Reserve not ready"
			if table.reserve_system.is_full():
				return "Reserve slots full"
			return ""
		REWARD_TYPE_PASSAGE_REDUCTION:
			if table.passage_system == null:
				return "Passage not ready"
			if bool(table.passage_system.get_passage_snapshot().get("run_completed", false)):
				return "Passage already complete"
			return ""
		REWARD_TYPE_FREE_REFRESH:
			if table.quartermaster_system == null:
				return "Quartermaster not ready"
			return table.quartermaster_system.get_quartermaster_access_blocker()
	return "Unknown reward"


func _get_doubloon_reroll_blocker() -> String:
	if not pending_reward_available or not pending_reward_ready:
		return "Sunken Spoils are not ready"
	if table == null or table.score_system == null:
		return "Score system not ready"
	if not table.score_system.can_afford_doubloons(get_current_doubloon_reroll_cost()):
		return "Not enough Doubloons"
	return ""


func _can_afford_doubloon_reroll() -> bool:
	return _get_doubloon_reroll_blocker().is_empty()


func _get_base_doubloon_reroll_cost() -> int:
	return maxi(roundi(REROLL_BASE_COST * pow(REROLL_MILESTONE_MULTIPLIER, float(current_milestone_index))), 0)


func _get_current_milestone_required() -> int:
	if MILESTONES.is_empty():
		return 1
	return int(MILESTONES[mini(current_milestone_index, MILESTONES.size() - 1)])


func _get_current_tier() -> String:
	if current_milestone_index <= 2:
		return TIER_EARLY
	if current_milestone_index <= 5:
		return TIER_MID
	return TIER_LATE


func _get_current_reward_pool() -> Array:
	var tier: String = _get_current_tier()
	var pool_value: Variant = TIER_REWARD_POOLS.get(tier, [])
	if not pool_value is Array:
		return []
	return (pool_value as Array).duplicate()


func _get_reward_definition(reward_id: String) -> Dictionary:
	var definition_value: Variant = REWARD_DEFINITIONS.get(reward_id, {})
	if not definition_value is Dictionary:
		return {}
	return (definition_value as Dictionary).duplicate(true)


func _get_reward_weight(reward_id: String) -> int:
	var definition: Dictionary = _get_reward_definition(reward_id)
	return maxi(int(definition.get("weight", 1)), 0)


func _get_reward_display_label(definition: Dictionary) -> String:
	return str(definition.get("display_label", definition.get("label", "Reward")))


func _get_reward_rarity(definition: Dictionary) -> String:
	var rarity: String = str(definition.get("rarity", RARITY_COMMON)).to_lower()
	if rarity == RARITY_COMMON or rarity == RARITY_UNCOMMON or rarity == RARITY_RARE:
		return rarity
	return RARITY_COMMON


func _get_reward_summary(definition: Dictionary) -> String:
	match str(definition.get("type", "")):
		REWARD_TYPE_DOUBLOONS:
			return "+%s Doubloons" % int(definition.get("amount", 0))
		REWARD_TYPE_INTERVENTION_CHARGE:
			var amount: int = maxi(int(definition.get("amount", 1)), 0)
			return "+%s Charge%s" % [amount, "" if amount == 1 else "s"]
		REWARD_TYPE_RESERVE_ITEM:
			return "%s x%s" % [
				_get_reserve_reward_spawn_label(definition),
				maxi(int(definition.get("quantity", 1)), 1),
			]
		REWARD_TYPE_PASSAGE_REDUCTION:
			return "-%s Passage" % int(definition.get("amount", 0))
		REWARD_TYPE_FREE_REFRESH:
			return "Free stock refresh"
	return "Reward"


func _get_reserve_reward_spawn_label(definition: Dictionary) -> String:
	match str(definition.get("spawn_type", "")):
		"plain_object_ball":
			return "Object Ball"
		"wayfinder_ball":
			return "Wayfinder Ball"
		"powder_keg_ball":
			return "Powder Keg"
	return "Reserve Item"


func _set_status(text: String) -> void:
	last_status = text
	if not text.is_empty():
		status_changed.emit(text)


func _emit_changed() -> void:
	spoils_changed.emit(get_spoils_snapshot())
