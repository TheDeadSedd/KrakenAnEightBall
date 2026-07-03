extends Node
class_name ReserveSystem

signal reserve_slots_changed(slots: Array)
signal deployment_started(item_name: String, slot_index: int)
signal deployment_finished(confirmed: bool, slot_index: int)
signal deployment_blocked(reason: String)

# index:title Reserve System
# index:category Systems / UI / In Progress
# index:status In Progress
# index:owner systems_agent
# index:notes Owns tactical reserve slot contents, selection/deployment state, snapshots, and reserve counters.

# Owns tactical reserve slot contents and deployment state. Quartermaster owns
# prices, while BallPlacementSystem owns placement validity/confirm/cancel.
const SLOT_COUNT := 3

var table
var slot_contents: Array = []
var selected_slot_index := -1
var deploying_slot_index := -1
var snapshot_requests := 0
var store_attempts := 0
var failed_store_attempts := 0
var cleared_slots := 0
var slot_clicks := 0
var empty_slot_clicks := 0
var invalid_slot_accesses := 0
var deploy_attempts := 0
var deploy_started_count := 0
var deploy_confirmed_count := 0
var deploy_canceled_count := 0
var deploy_blocked_count := 0
var last_deploy_blocker_reason := ""


func setup(table_ref) -> void:
	table = table_ref
	_ensure_slots_initialized()
	if table.ball_placement_system != null:
		if not table.ball_placement_system.placement_confirmed.is_connected(_on_placement_confirmed):
			table.ball_placement_system.placement_confirmed.connect(_on_placement_confirmed)
		if not table.ball_placement_system.placement_canceled.is_connected(_on_placement_canceled):
			table.ball_placement_system.placement_canceled.connect(_on_placement_canceled)
	_emit_slots_changed()


func get_slots_snapshot() -> Array:
	snapshot_requests += 1
	_ensure_slots_initialized()
	var snapshot: Array = []
	for slot_index in range(SLOT_COUNT):
		var content: Dictionary = _get_slot_content(slot_index)
		var filled := not content.is_empty()
		var quantity: int = _get_item_quantity(content) if filled else 0
		var quantity_total: int = _get_item_quantity_total(content, quantity) if filled else 0
		snapshot.append({
			"index": slot_index,
			"filled": filled,
			"item_id": str(content.get("item_id", "")),
			"item_name": str(content.get("item_name", "")),
			"display_name": str(content.get("display_name", content.get("item_name", ""))),
			"spawn_type": str(content.get("spawn_type", "")),
			"icon_key": str(content.get("icon_key", "")),
			"quantity": quantity,
			"quantity_total": quantity_total,
			"selected": slot_index == selected_slot_index,
			"deploying": slot_index == deploying_slot_index,
		})
	return snapshot


func get_debug_snapshot() -> Dictionary:
	return {
		"slot_count": SLOT_COUNT,
		"filled_slots": get_filled_slot_count(),
		"selected_slot_index": selected_slot_index,
		"deploying_slot_index": deploying_slot_index,
		"snapshot_requests": snapshot_requests,
		"store_attempts": store_attempts,
		"failed_store_attempts": failed_store_attempts,
		"cleared_slots": cleared_slots,
		"slot_clicks": slot_clicks,
		"empty_slot_clicks": empty_slot_clicks,
		"invalid_slot_accesses": invalid_slot_accesses,
		"deploy_attempts": deploy_attempts,
		"deploy_started_count": deploy_started_count,
		"deploy_confirmed_count": deploy_confirmed_count,
		"deploy_canceled_count": deploy_canceled_count,
		"deploy_blocked_count": deploy_blocked_count,
		"last_deploy_blocker_reason": last_deploy_blocker_reason,
	}


func get_filled_slot_count() -> int:
	_ensure_slots_initialized()
	var filled_count := 0
	for slot_index in range(SLOT_COUNT):
		if not _get_slot_content(slot_index).is_empty():
			filled_count += 1
	return filled_count


func get_empty_slot_count() -> int:
	return SLOT_COUNT - get_filled_slot_count()


func get_first_empty_slot_index() -> int:
	_ensure_slots_initialized()
	for slot_index in range(SLOT_COUNT):
		if _get_slot_content(slot_index).is_empty():
			return slot_index
	return -1


func is_full() -> bool:
	return get_first_empty_slot_index() == -1


func store_item_in_first_empty_slot(item: Dictionary) -> int:
	var slot_index := get_first_empty_slot_index()
	if slot_index == -1:
		store_attempts += 1
		failed_store_attempts += 1
		return -1

	if not store_item_in_slot(slot_index, item):
		return -1
	return slot_index


func store_item_in_slot(slot_index: int, item: Dictionary) -> bool:
	store_attempts += 1
	if not _is_valid_slot_index(slot_index):
		invalid_slot_accesses += 1
		failed_store_attempts += 1
		return false

	_ensure_slots_initialized()
	if not _get_slot_content(slot_index).is_empty():
		failed_store_attempts += 1
		return false

	var normalized_item: Dictionary = _normalize_reserve_item_payload(item)
	if normalized_item.is_empty():
		failed_store_attempts += 1
		return false

	slot_contents[slot_index] = normalized_item
	_emit_slots_changed()
	return true


func set_slot_content(slot_index: int, item: Dictionary) -> bool:
	if not _is_valid_slot_index(slot_index):
		invalid_slot_accesses += 1
		return false

	_ensure_slots_initialized()
	slot_contents[slot_index] = _normalize_reserve_item_payload(item)
	_emit_slots_changed()
	return true


func clear_slot(slot_index: int) -> bool:
	if not _is_valid_slot_index(slot_index):
		invalid_slot_accesses += 1
		return false

	_ensure_slots_initialized()
	if not _get_slot_content(slot_index).is_empty():
		cleared_slots += 1
	slot_contents[slot_index] = {}
	if selected_slot_index == slot_index:
		selected_slot_index = -1
	if deploying_slot_index == slot_index:
		deploying_slot_index = -1
	_emit_slots_changed()
	return true


func record_slot_clicked(slot_index: int) -> void:
	if not _is_valid_slot_index(slot_index):
		invalid_slot_accesses += 1
		return

	slot_clicks += 1
	if _get_slot_content(slot_index).is_empty():
		empty_slot_clicks += 1


func request_deploy_slot(slot_index: int) -> bool:
	deploy_attempts += 1
	var blocker := _get_deploy_blocker(slot_index)
	if not blocker.is_empty():
		deploy_blocked_count += 1
		last_deploy_blocker_reason = blocker
		deployment_blocked.emit(blocker)
		return false

	var content := _get_slot_content(slot_index)
	selected_slot_index = slot_index
	deploying_slot_index = slot_index
	deploy_started_count += 1
	last_deploy_blocker_reason = ""
	var item_name := str(content.get("item_name", "Reserve item"))
	var item_id := str(content.get("item_id", ""))
	var radius: float = table.spawn_system.get_manual_placement_ball_radius()
	table.ball_placement_system.start_placement(item_id, item_name, radius)
	_emit_slots_changed()
	deployment_started.emit(item_name, slot_index)
	return true


func _ensure_slots_initialized() -> void:
	while slot_contents.size() < SLOT_COUNT:
		slot_contents.append({})
	if slot_contents.size() > SLOT_COUNT:
		slot_contents.resize(SLOT_COUNT)


func _get_slot_content(slot_index: int) -> Dictionary:
	if not _is_valid_slot_index(slot_index):
		return {}
	_ensure_slots_initialized()
	var content = slot_contents[slot_index]
	if content is Dictionary:
		return content
	return {}


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT


func _emit_slots_changed() -> void:
	reserve_slots_changed.emit(get_slots_snapshot())


func _get_deploy_blocker(slot_index: int) -> String:
	if table == null or table.ball_placement_system == null or table.spawn_system == null:
		return "Reserve deployment not ready"
	if deploying_slot_index != -1:
		return "Reserve deployment already active"
	if table.ball_placement_system.is_placement_active():
		return "Placement already active"
	if not _is_valid_slot_index(slot_index):
		return "Invalid reserve slot"
	if _get_slot_content(slot_index).is_empty():
		return "Reserve slot empty"
	if _get_item_quantity(_get_slot_content(slot_index)) <= 0:
		return "Reserve slot empty"
	return ""


func _on_placement_confirmed(item_id: String, position: Vector2) -> void:
	if deploying_slot_index == -1:
		return

	var slot_index := deploying_slot_index
	var content := _get_slot_content(slot_index)
	if item_id != str(content.get("item_id", "")):
		_finish_deployment(false, slot_index)
		deployment_blocked.emit("Reserve deployment item mismatch")
		deployment_finished.emit(false, slot_index)
		return

	if not _spawn_reserved_item(content, position):
		_finish_deployment(false, slot_index)
		deployment_blocked.emit("Reserve item cannot be spawned")
		deployment_finished.emit(false, slot_index)
		return

	_consume_one_from_slot(slot_index, content)
	deploy_confirmed_count += 1
	deployment_finished.emit(true, slot_index)


func _on_placement_canceled(_item_id: String) -> void:
	if deploying_slot_index == -1:
		return

	var slot_index := deploying_slot_index
	_finish_deployment(false, slot_index)
	deploy_canceled_count += 1
	deployment_finished.emit(false, slot_index)


func _finish_deployment(_confirmed: bool, slot_index: int) -> void:
	if selected_slot_index == slot_index:
		selected_slot_index = -1
	if deploying_slot_index == slot_index:
		deploying_slot_index = -1
	_emit_slots_changed()


func _consume_one_from_slot(slot_index: int, content: Dictionary) -> void:
	var remaining_quantity: int = _get_item_quantity(content) - 1
	if remaining_quantity <= 0:
		clear_slot(slot_index)
		return

	var updated_content: Dictionary = content.duplicate(true)
	updated_content["quantity"] = remaining_quantity
	slot_contents[slot_index] = _normalize_reserve_item_payload(updated_content)
	_finish_deployment(true, slot_index)


func _normalize_reserve_item_payload(item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {}

	var normalized_item: Dictionary = item.duplicate(true)
	var quantity: int = maxi(int(normalized_item.get("quantity", 1)), 0)
	if quantity <= 0:
		return {}

	var quantity_total: int = maxi(int(normalized_item.get("quantity_total", quantity)), quantity)
	normalized_item["quantity"] = quantity
	normalized_item["quantity_total"] = quantity_total
	if not normalized_item.has("display_name"):
		normalized_item["display_name"] = str(normalized_item.get("item_name", normalized_item.get("item_id", "Reserve item")))
	return normalized_item


func _get_item_quantity(content: Dictionary) -> int:
	if content.is_empty():
		return 0
	return maxi(int(content.get("quantity", 1)), 0)


func _get_item_quantity_total(content: Dictionary, fallback_quantity: int = 1) -> int:
	if content.is_empty():
		return 0
	return maxi(int(content.get("quantity_total", fallback_quantity)), fallback_quantity)


func _spawn_reserved_item(content: Dictionary, position: Vector2) -> bool:
	var ball: Ball
	match str(content.get("spawn_type", "")):
		"plain_object_ball":
			ball = table.spawn_system.spawn_manual_plain_object_ball(position)
		"wayfinder_ball":
			ball = table.spawn_system.spawn_manual_wayfinder_ball(position)
		"powder_keg_ball":
			ball = table.spawn_system.spawn_manual_powder_keg_ball(position)
		"treasure_ball":
			ball = table.spawn_system.spawn_manual_treasure_ball(position)
		"cannon_ball":
			ball = table.spawn_system.spawn_manual_cannon_ball(position)
		"embezzler_ball":
			ball = table.spawn_system.spawn_manual_embezzler_ball(position)
		_:
			return false
	return ball != null
