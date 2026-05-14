extends Node
class_name QuartermasterSystem

signal shop_state_changed(items: Array)
signal status_changed(text: String)
signal placement_started(item_name: String)
signal placement_finished

# Owns shop inventory, prices, affordability, and purchase intent. Actual
# table placement is delegated to BallPlacementSystem so it can be reused.
const ITEM_PLAIN_OBJECT_BALL := "plain_object_ball"
const SPAWN_TYPE_PLAIN_OBJECT_BALL := "plain_object_ball"
const SHOP_ITEM_IDS := ["plain_object_ball"]
const SHOP_ITEMS := {
	"plain_object_ball": {
		"id": ITEM_PLAIN_OBJECT_BALL,
		"name": "Loose Object Ball",
		"description": "Buy one plain ball and choose a safe place for it.",
		"price": 10,
		"spawn_type": SPAWN_TYPE_PLAIN_OBJECT_BALL,
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
	if table.ball_placement_system != null:
		if not table.ball_placement_system.placement_confirmed.is_connected(_on_placement_confirmed):
			table.ball_placement_system.placement_confirmed.connect(_on_placement_confirmed)
		if not table.ball_placement_system.placement_canceled.is_connected(_on_placement_canceled):
			table.ball_placement_system.placement_canceled.connect(_on_placement_canceled)
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
	pending_item_id = item_id
	purchase_intents_started += 1
	var radius: float = table.spawn_system.get_manual_placement_ball_radius()
	table.ball_placement_system.start_placement(item_id, str(item["name"]), radius)
	status_changed.emit("Choose a safe spot for %s." % str(item["name"]))
	placement_started.emit(str(item["name"]))
	_emit_shop_state_changed()
	return true


func cancel_active_purchase() -> void:
	if pending_item_id.is_empty():
		return

	table.ball_placement_system.cancel_placement()


func get_shop_items_snapshot() -> Array:
	var items: Array = []
	for item_id in SHOP_ITEM_IDS:
		var item: Dictionary = _get_item(item_id).duplicate(true)
		item["affordable"] = can_afford_item(item_id)
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


func _on_placement_confirmed(item_id: String, position: Vector2) -> void:
	if item_id != pending_item_id:
		last_blocker_reason = "Placement item mismatch"
		_finish_purchase_intent()
		status_changed.emit(last_blocker_reason)
		return

	var item: Dictionary = _get_item(item_id)
	if item.is_empty():
		last_blocker_reason = "Unknown Quartermaster item"
		_finish_purchase_intent()
		status_changed.emit(last_blocker_reason)
		return

	var radius: float = table.spawn_system.get_manual_placement_ball_radius()
	if not table.spawn_system.is_manual_placement_safe(position, radius):
		last_blocker_reason = "Placement no longer safe"
		_finish_purchase_intent()
		status_changed.emit(last_blocker_reason)
		return

	var price := int(item["price"])
	if not table.score_system.try_spend_doubloons(price):
		last_blocker_reason = "Not enough Doubloons"
		_finish_purchase_intent()
		status_changed.emit(last_blocker_reason)
		return

	_spawn_purchased_item(item, position)
	confirmed_purchases += 1
	_finish_purchase_intent()
	status_changed.emit("Quartermaster placed %s." % str(item["name"]))


func _on_placement_canceled(item_id: String) -> void:
	if item_id == pending_item_id:
		canceled_purchases += 1
	_finish_purchase_intent()
	status_changed.emit("Quartermaster order canceled.")


func _spawn_purchased_item(item: Dictionary, position: Vector2) -> void:
	match str(item["spawn_type"]):
		SPAWN_TYPE_PLAIN_OBJECT_BALL:
			table.spawn_system.spawn_manual_plain_object_ball(position)


func _finish_purchase_intent() -> void:
	pending_item_id = ""
	placement_finished.emit()
	_emit_shop_state_changed()


func _emit_shop_state_changed() -> void:
	shop_state_changed.emit(get_shop_items_snapshot())


func _get_purchase_blocker(item_id: String) -> String:
	var item: Dictionary = _get_item(item_id)
	if item.is_empty():
		return "Unknown Quartermaster item"
	if table == null or table.score_system == null or table.spawn_system == null or table.ball_placement_system == null:
		return "Quartermaster not ready"
	if is_purchase_pending():
		return "Placement already active"
	if not table.can_start_manual_ball_placement():
		return "Wait for the table to settle"
	if not can_afford_item(item_id):
		return "Not enough Doubloons"
	return ""


func _get_item(item_id: String) -> Dictionary:
	if not SHOP_ITEMS.has(item_id):
		return {}
	return SHOP_ITEMS[item_id]
