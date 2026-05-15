extends Node
class_name QuartermasterSystem

signal shop_state_changed(items: Array)
signal status_changed(text: String)
signal placement_started(item_name: String)
signal placement_finished

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

var table
var pending_item_id := ""
var purchase_attempts := 0
var denied_purchase_attempts := 0
var purchase_intents_started := 0
var confirmed_purchases := 0
var canceled_purchases := 0
var stock_refreshes := 0
var offer_replacements := 0
var duplicate_offer_fallbacks := 0
var stock_refresh_serial := 0
var last_refreshed_offer_index := -1
var last_blocker_reason := ""
var active_offer_item_ids: Array = []
var stock_rng := RandomNumberGenerator.new()


func setup(table_ref) -> void:
	table = table_ref
	stock_rng.seed = STOCK_RNG_SEED
	stock_refresh_serial = 0
	last_refreshed_offer_index = -1
	active_offer_item_ids.clear()
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


func cancel_active_purchase() -> void:
	return


func get_shop_items_snapshot() -> Array:
	_ensure_active_offers_filled()
	var items: Array = []
	var doubloons_available := _get_doubloons_available()
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
		items.append(item)
	return items


func can_afford_item(item_id: String) -> bool:
	var item: Dictionary = _get_item(item_id)
	if item.is_empty() or table == null or table.score_system == null:
		return false
	return table.score_system.can_afford_doubloons(int(item["price"]))


func is_purchase_pending() -> bool:
	return not pending_item_id.is_empty()


func get_debug_snapshot() -> Dictionary:
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


func _get_purchase_blocker(item_id: String) -> String:
	var item: Dictionary = _get_item(item_id)
	if item.is_empty():
		return "Unknown Quartermaster item"
	if table == null or table.score_system == null or table.reserve_system == null:
		return "Quartermaster not ready"
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


func _make_reserve_item_payload(item: Dictionary) -> Dictionary:
	return {
		"item_id": str(item["id"]),
		"item_name": str(item["name"]),
		"description": str(item.get("description", "")),
		"price": int(item.get("price", 0)),
		"spawn_type": str(item["spawn_type"]),
		"icon_key": str(item["id"]),
	}
