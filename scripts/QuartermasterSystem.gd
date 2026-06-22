extends Node
class_name QuartermasterSystem

signal shop_state_changed(items: Array)
signal status_changed(text: String)
signal placement_started(item_name: String)
signal placement_finished
signal stock_refresh_purchased(cost: int, refresh_count: int)

# Owns shop inventory, prices, affordability, and purchase intent. Purchases
# fill ReserveSystem slots; reserve deployment is handled outside this shop.
const ITEM_PLAIN_OBJECT_BALL := "plain_object_ball"
const ITEM_WAYFINDER_BALL := "wayfinder_ball"
const ITEM_POWDER_KEG_BALL := "powder_keg_ball"
const SPAWN_TYPE_PLAIN_OBJECT_BALL := "plain_object_ball"
const SPAWN_TYPE_WAYFINDER_BALL := "wayfinder_ball"
const SPAWN_TYPE_POWDER_KEG_BALL := "powder_keg_ball"
const OFFER_SLOT_COUNT := 3
const STOCK_RNG_SEED := 802408
const CUE_MODIFIER_QUARTERMASTER_REFRESH_SHOT_DECAY_BONUS := "quartermaster_refresh_shot_decay_bonus"
const SHOP_ITEM_IDS := ["plain_object_ball", "wayfinder_ball", "powder_keg_ball"]
const SHOP_ITEMS := {
	"plain_object_ball": {
		"id": ITEM_PLAIN_OBJECT_BALL,
		"name": "Loose Object Ball",
		"description": "Adds another normal ball to the table.",
		"price": 10,
		"spawn_type": SPAWN_TYPE_PLAIN_OBJECT_BALL,
	},
	"wayfinder_ball": {
		"id": ITEM_WAYFINDER_BALL,
		"name": "Wayfinder Ball",
		"description": "Helps guide shots toward pockets.",
		"price": 35,
		"spawn_type": SPAWN_TYPE_WAYFINDER_BALL,
	},
	"powder_keg_ball": {
		"id": ITEM_POWDER_KEG_BALL,
		"name": "Powder Keg",
		"description": "Explodes when struck by cue ball or Cannon Ball.",
		"price": 55,
		"spawn_type": SPAWN_TYPE_POWDER_KEG_BALL,
	},
}

@export var refresh_base_cost := 10
@export var refresh_cost_multiplier := 2.0
@export var refresh_shot_decay_amount := 2
@export var refresh_max_cost := 0

var table: BilliardsTable
var pending_item_id := ""
var purchase_attempts := 0
var denied_purchase_attempts := 0
var purchase_intents_started := 0
var confirmed_purchases := 0
var canceled_purchases := 0
var stock_refreshes := 0
var offer_replacements := 0
var duplicate_offer_fallbacks := 0
var manual_stock_refreshes := 0
var denied_stock_refresh_attempts := 0
var refresh_doubloons_spent := 0
var current_refresh_cost := 10
var stock_refresh_serial := 0
var last_refreshed_offer_index := -1
var last_blocker_reason := ""
var active_offer_item_ids: Array = []
var cue_modifier_snapshot: Dictionary = {}
var stock_rng := RandomNumberGenerator.new()


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	stock_rng.seed = STOCK_RNG_SEED
	stock_refresh_serial = 0
	last_refreshed_offer_index = -1
	manual_stock_refreshes = 0
	denied_stock_refresh_attempts = 0
	refresh_doubloons_spent = 0
	current_refresh_cost = _get_base_refresh_cost()
	active_offer_item_ids.clear()
	if table != null and not table.shot_taken.is_connected(_on_shot_taken):
		table.shot_taken.connect(_on_shot_taken)
	if table != null and table.oath_system != null:
		if not table.oath_system.oaths_changed.is_connected(_on_oaths_changed):
			table.oath_system.oaths_changed.connect(_on_oaths_changed)
	_ensure_active_offers_filled()
	_emit_shop_state_changed()


func request_purchase(item_id: String) -> bool:
	_ensure_active_offers_filled()
	var offer_index := active_offer_item_ids.find(item_id)
	if offer_index == -1:
		purchase_attempts += 1
		denied_purchase_attempts += 1
		last_blocker_reason = "Quartermaster offer not in stock"
		status_changed.emit(last_blocker_reason)
		_emit_shop_state_changed()
		return false

	return request_purchase_offer(offer_index)


func request_purchase_offer(offer_index: int) -> bool:
	purchase_attempts += 1
	_ensure_active_offers_filled()
	var blocker := _get_offer_purchase_blocker(offer_index)
	if not blocker.is_empty():
		denied_purchase_attempts += 1
		last_blocker_reason = blocker
		status_changed.emit(blocker)
		_emit_shop_state_changed()
		return false

	var item_id := str(active_offer_item_ids[offer_index])
	var item: Dictionary = _get_item(item_id)
	var slot_index: int = table.reserve_system.get_first_empty_slot_index()
	if slot_index == -1:
		denied_purchase_attempts += 1
		last_blocker_reason = "Reserve slots full"
		status_changed.emit(last_blocker_reason)
		_emit_shop_state_changed()
		return false

	var price := int(item["price"])
	if not table.score_system.try_spend_doubloons(price):
		denied_purchase_attempts += 1
		last_blocker_reason = "Not enough Doubloons"
		status_changed.emit(last_blocker_reason)
		_emit_shop_state_changed()
		return false

	purchase_intents_started += 1
	if not table.reserve_system.store_item_in_slot(slot_index, _make_reserve_item_payload(item)):
		last_blocker_reason = "Reserve slot unavailable"
		status_changed.emit(last_blocker_reason)
		_emit_shop_state_changed()
		return false

	confirmed_purchases += 1
	last_blocker_reason = ""
	_replace_offer_slot(offer_index, item_id)
	status_changed.emit("Quartermaster stowed %s in reserve slot %s." % [str(item["name"]), slot_index + 1])
	_emit_shop_state_changed()
	return true


func request_refresh_stock() -> bool:
	_ensure_active_offers_filled()
	var blocker := _get_refresh_blocker()
	if not blocker.is_empty():
		denied_stock_refresh_attempts += 1
		last_blocker_reason = blocker
		status_changed.emit(blocker)
		_emit_shop_state_changed()
		return false

	var refresh_cost := get_current_refresh_cost()
	if not table.score_system.try_spend_doubloons(refresh_cost):
		denied_stock_refresh_attempts += 1
		last_blocker_reason = "Not enough Doubloons"
		status_changed.emit(last_blocker_reason)
		_emit_shop_state_changed()
		return false

	_reroll_all_offer_slots()
	manual_stock_refreshes += 1
	refresh_doubloons_spent += refresh_cost
	current_refresh_cost = _get_next_refresh_cost(refresh_cost)
	last_blocker_reason = ""
	stock_refresh_purchased.emit(refresh_cost, manual_stock_refreshes)
	status_changed.emit("Quartermaster refreshed stock for %s Doubloons." % refresh_cost)
	_emit_shop_state_changed()
	return true


func set_cue_modifier_snapshot(snapshot: Dictionary) -> void:
	cue_modifier_snapshot = snapshot.duplicate(true)
	_emit_shop_state_changed()


func cancel_active_purchase() -> void:
	return


func get_shop_items_snapshot() -> Array:
	_ensure_active_offers_filled()
	var items: Array = []
	var doubloons_available := _get_doubloons_available()
	var refresh_snapshot := get_refresh_snapshot()
	for offer_index in range(OFFER_SLOT_COUNT):
		var item_id := str(active_offer_item_ids[offer_index])
		var item: Dictionary = _get_item(item_id).duplicate(true)
		item["offer_index"] = offer_index
		item["affordable"] = can_afford_item(item_id)
		item["doubloons_available"] = doubloons_available
		item["stock_refresh_serial"] = stock_refresh_serial
		item["last_refreshed_offer_index"] = last_refreshed_offer_index
		item["blocked_reason"] = _get_offer_purchase_blocker(offer_index)
		item["available"] = str(item["blocked_reason"]).is_empty()
		item["refresh"] = refresh_snapshot
		items.append(item)
	return items


func get_refresh_snapshot() -> Dictionary:
	var blocker := _get_refresh_blocker()
	var cost := get_current_refresh_cost()
	var decay_snapshot := get_refresh_decay_snapshot()
	return {
		"cost": cost,
		"base_cost": _get_base_refresh_cost(),
		"cost_multiplier": refresh_cost_multiplier,
		"shot_decay_amount": int(decay_snapshot.get("final_decay", 0)),
		"base_shot_decay_amount": int(decay_snapshot.get("base_decay", 0)),
		"cue_shot_decay_bonus": int(decay_snapshot.get("cue_bonus", 0)),
		"final_shot_decay_amount": int(decay_snapshot.get("final_decay", 0)),
		"active_cue_modifiers_summary": str(decay_snapshot.get("active_cue_modifiers_summary", "None")),
		"max_cost": refresh_max_cost,
		"affordable": blocker.is_empty(),
		"blocked_reason": blocker,
		"refreshes_used": manual_stock_refreshes,
		"doubloons_spent": refresh_doubloons_spent,
	}


func get_refresh_decay_snapshot() -> Dictionary:
	var base_decay := _get_base_refresh_decay_amount()
	var cue_bonus := _get_refresh_decay_cue_bonus()
	var final_decay := _get_refresh_decay_amount()
	return {
		"base_decay": base_decay,
		"cue_bonus": cue_bonus,
		"final_decay": final_decay,
		"active_cue_modifiers_summary": _get_active_cue_modifier_summary(),
	}


func get_current_refresh_cost() -> int:
	return _apply_refresh_cost_cap(maxi(current_refresh_cost, _get_base_refresh_cost()))


func get_quartermaster_access_blocker() -> String:
	return _get_oath_quartermaster_blocker()


func can_afford_item(item_id: String) -> bool:
	var item: Dictionary = _get_item(item_id)
	if item.is_empty() or table == null or table.score_system == null:
		return false
	return table.score_system.can_afford_doubloons(int(item["price"]))


func is_purchase_pending() -> bool:
	return not pending_item_id.is_empty()


func get_debug_snapshot() -> Dictionary:
	var decay_snapshot := get_refresh_decay_snapshot()
	return {
		"purchase_pending": is_purchase_pending(),
		"pending_item_id": pending_item_id,
		"purchase_attempts": purchase_attempts,
		"denied_purchase_attempts": denied_purchase_attempts,
		"purchase_intents_started": purchase_intents_started,
		"confirmed_purchases": confirmed_purchases,
		"canceled_purchases": canceled_purchases,
		"active_offer_item_ids": active_offer_item_ids.duplicate(),
		"stock_refreshes": stock_refreshes,
		"manual_stock_refreshes": manual_stock_refreshes,
		"denied_stock_refresh_attempts": denied_stock_refresh_attempts,
		"refresh_doubloons_spent": refresh_doubloons_spent,
		"current_refresh_cost": get_current_refresh_cost(),
		"refresh_base_cost": _get_base_refresh_cost(),
		"refresh_shot_decay_amount": int(decay_snapshot.get("final_decay", 0)),
		"refresh_base_shot_decay_amount": int(decay_snapshot.get("base_decay", 0)),
		"refresh_cue_shot_decay_bonus": int(decay_snapshot.get("cue_bonus", 0)),
		"refresh_final_shot_decay_amount": int(decay_snapshot.get("final_decay", 0)),
		"active_cue_modifiers_summary": str(decay_snapshot.get("active_cue_modifiers_summary", "None")),
		"offer_replacements": offer_replacements,
		"duplicate_offer_fallbacks": duplicate_offer_fallbacks,
		"stock_refresh_serial": stock_refresh_serial,
		"last_refreshed_offer_index": last_refreshed_offer_index,
		"last_blocker_reason": last_blocker_reason,
	}


func _emit_shop_state_changed() -> void:
	shop_state_changed.emit(get_shop_items_snapshot())


func _get_offer_purchase_blocker(offer_index: int) -> String:
	if not _is_valid_offer_index(offer_index):
		return "Unknown Quartermaster offer"

	var item_id := str(active_offer_item_ids[offer_index])
	if item_id.is_empty():
		return "Quartermaster offer unavailable"
	return _get_purchase_blocker(item_id)


func _get_refresh_blocker() -> String:
	if table == null or table.score_system == null:
		return "Quartermaster not ready"
	var oath_blocker := _get_oath_quartermaster_blocker()
	if not oath_blocker.is_empty():
		return oath_blocker
	if not table.score_system.can_afford_doubloons(get_current_refresh_cost()):
		return "Not enough Doubloons"
	return ""


func _get_purchase_blocker(item_id: String) -> String:
	var item: Dictionary = _get_item(item_id)
	if item.is_empty():
		return "Unknown Quartermaster item"
	if table == null or table.score_system == null or table.reserve_system == null:
		return "Quartermaster not ready"
	var oath_blocker := _get_oath_quartermaster_blocker()
	if not oath_blocker.is_empty():
		return oath_blocker
	if is_purchase_pending():
		return "Placement already active"
	if table.reserve_system.is_full():
		return "Reserve slots full"
	if not can_afford_item(item_id):
		return "Not enough Doubloons"
	return ""


func _get_item(item_id: String) -> Dictionary:
	if not SHOP_ITEMS.has(item_id):
		return {}
	return SHOP_ITEMS[item_id]


func _get_oath_quartermaster_blocker() -> String:
	if table == null or table.oath_system == null:
		return ""
	return table.oath_system.get_quartermaster_access_blocker()


func _ensure_active_offers_filled() -> void:
	while active_offer_item_ids.size() < OFFER_SLOT_COUNT:
		active_offer_item_ids.append("")
	if active_offer_item_ids.size() > OFFER_SLOT_COUNT:
		active_offer_item_ids.resize(OFFER_SLOT_COUNT)

	for offer_index in range(OFFER_SLOT_COUNT):
		if str(active_offer_item_ids[offer_index]).is_empty():
			active_offer_item_ids[offer_index] = _pick_offer_item_id(offer_index)
			stock_refreshes += 1


func _replace_offer_slot(offer_index: int, previous_item_id: String) -> void:
	if not _is_valid_offer_index(offer_index):
		return

	active_offer_item_ids[offer_index] = _pick_offer_item_id(offer_index, previous_item_id)
	stock_refreshes += 1
	offer_replacements += 1
	stock_refresh_serial += 1
	last_refreshed_offer_index = offer_index


func _reroll_all_offer_slots() -> void:
	var previous_offers := active_offer_item_ids.duplicate()
	var refreshed_offers := _pick_refreshed_offer_set(previous_offers)
	if refreshed_offers.is_empty():
		return

	active_offer_item_ids = refreshed_offers
	stock_refreshes += active_offer_item_ids.size()
	offer_replacements += active_offer_item_ids.size()
	stock_refresh_serial += 1
	last_refreshed_offer_index = -1


func _pick_refreshed_offer_set(previous_offers: Array) -> Array:
	var pool := _get_purchasable_item_ids()
	if pool.is_empty():
		return []

	var refreshed_offers: Array = []
	var available_unique := pool.duplicate()
	for offer_index in range(OFFER_SLOT_COUNT):
		var previous_item_id := ""
		if offer_index < previous_offers.size():
			previous_item_id = str(previous_offers[offer_index])

		var candidates := _get_candidates_excluding_item(available_unique, previous_item_id)
		if candidates.is_empty():
			candidates = available_unique.duplicate()
		if candidates.is_empty():
			candidates = _get_candidates_excluding_item(pool, previous_item_id)
		if candidates.is_empty():
			candidates = pool.duplicate()

		var picked_item_id := _pick_random_item_id(candidates)
		refreshed_offers.append(picked_item_id)
		available_unique.erase(picked_item_id)
		if available_unique.is_empty() and refreshed_offers.size() < min(OFFER_SLOT_COUNT, pool.size()):
			available_unique = pool.duplicate()
	return refreshed_offers


func _pick_offer_item_id(offer_index: int, previous_item_id: String = "") -> String:
	var pool := _get_purchasable_item_ids()
	if pool.is_empty():
		return ""

	var unique_candidates := _get_candidates_excluding_other_active_offers(pool, offer_index)
	var rotating_unique_candidates := _get_candidates_excluding_item(unique_candidates, previous_item_id)
	if not rotating_unique_candidates.is_empty():
		return _pick_random_item_id(rotating_unique_candidates)

	if not unique_candidates.is_empty() and previous_item_id.is_empty():
		return _pick_random_item_id(unique_candidates)

	var rotating_fallbacks := _get_candidates_excluding_item(pool, previous_item_id)
	if not rotating_fallbacks.is_empty():
		duplicate_offer_fallbacks += 1
		return _pick_random_item_id(rotating_fallbacks)

	if not unique_candidates.is_empty():
		return _pick_random_item_id(unique_candidates)
	return _pick_random_item_id(pool)


func _get_purchasable_item_ids() -> Array:
	return SHOP_ITEM_IDS.duplicate()


func _get_candidates_excluding_other_active_offers(pool: Array, offer_index: int) -> Array:
	var candidates: Array = []
	for candidate_value in pool:
		var candidate_id := str(candidate_value)
		if not _is_item_active_in_other_offer(candidate_id, offer_index):
			candidates.append(candidate_id)
	return candidates


func _get_candidates_excluding_item(pool: Array, excluded_item_id: String) -> Array:
	if excluded_item_id.is_empty():
		return pool.duplicate()

	var candidates: Array = []
	for candidate_value in pool:
		var candidate_id := str(candidate_value)
		if candidate_id != excluded_item_id:
			candidates.append(candidate_id)
	return candidates


func _is_item_active_in_other_offer(item_id: String, offer_index: int) -> bool:
	for active_index in range(active_offer_item_ids.size()):
		if active_index == offer_index:
			continue
		if str(active_offer_item_ids[active_index]) == item_id:
			return true
	return false


func _pick_random_item_id(candidates: Array) -> String:
	if candidates.is_empty():
		return ""
	var candidate_index := stock_rng.randi_range(0, candidates.size() - 1)
	return str(candidates[candidate_index])


func _is_valid_offer_index(offer_index: int) -> bool:
	return offer_index >= 0 and offer_index < active_offer_item_ids.size()


func _get_doubloons_available() -> int:
	if table == null or table.score_system == null:
		return 0
	return table.score_system.get_doubloons_total()


func _get_base_refresh_cost() -> int:
	return maxi(refresh_base_cost, 0)


func _get_base_refresh_decay_amount() -> int:
	return maxi(refresh_shot_decay_amount, 0)


func _get_refresh_decay_cue_bonus() -> int:
	return maxi(roundi(_get_cue_modifier_value(CUE_MODIFIER_QUARTERMASTER_REFRESH_SHOT_DECAY_BONUS, 0.0)), 0)


func _get_refresh_decay_amount() -> int:
	return maxi(_get_base_refresh_decay_amount() + _get_refresh_decay_cue_bonus(), 0)


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


func _get_next_refresh_cost(paid_cost: int) -> int:
	var multiplied_cost := ceili(maxf(float(paid_cost), float(_get_base_refresh_cost())) * maxf(refresh_cost_multiplier, 1.0))
	return _apply_refresh_cost_cap(maxi(multiplied_cost, _get_base_refresh_cost()))


func _apply_refresh_cost_cap(cost: int) -> int:
	if refresh_max_cost > 0:
		return mini(cost, refresh_max_cost)
	return cost


func _on_shot_taken(_count: int) -> void:
	var base_cost := _get_base_refresh_cost()
	if current_refresh_cost <= base_cost:
		return

	var decayed_cost := maxi(current_refresh_cost - _get_refresh_decay_amount(), base_cost)
	if decayed_cost == current_refresh_cost:
		return

	current_refresh_cost = decayed_cost
	_emit_shop_state_changed()


func _on_oaths_changed(_snapshot: Dictionary) -> void:
	_emit_shop_state_changed()


func _make_reserve_item_payload(item: Dictionary) -> Dictionary:
	return {
		"item_id": str(item["id"]),
		"item_name": str(item["name"]),
		"description": str(item.get("description", "")),
		"price": int(item.get("price", 0)),
		"spawn_type": str(item["spawn_type"]),
		"icon_key": str(item["id"]),
	}
