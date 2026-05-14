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
var last_blocker_reason := ""


func setup(table_ref) -> void:
	table = table_ref
	_emit_shop_state_changed()


func request_purchase(item_id: String) -> bool:
	purchase_attempts += 1
	var blocker := _get_purchase_blocker(item_id)
	if not blocker.is_empty():
		denied_purchase_attempts += 1
		last_blocker_reason = blocker
		status_changed.emit(blocker)
		_emit_shop_state_changed()
		return false

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
	status_changed.emit("Quartermaster stowed %s in reserve slot %s." % [str(item["name"]), slot_index + 1])
	_emit_shop_state_changed()
	return true


func cancel_active_purchase() -> void:
	return


func get_shop_items_snapshot() -> Array:
	var items: Array = []
	var doubloons_available := _get_doubloons_available()
	for item_id in SHOP_ITEM_IDS:
		var item: Dictionary = _get_item(item_id).duplicate(true)
		item["affordable"] = can_afford_item(item_id)
		item["doubloons_available"] = doubloons_available
		item["blocked_reason"] = _get_purchase_blocker(item_id)
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
		"last_blocker_reason": last_blocker_reason,
	}


func _emit_shop_state_changed() -> void:
	shop_state_changed.emit(get_shop_items_snapshot())


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
