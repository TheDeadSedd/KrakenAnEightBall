extends Node
class_name BackRoomDealSystem

signal state_changed(snapshot: Dictionary)
signal status_changed(text: String)
signal deal_completed(item_id: String, cost: int, deal_count: int)

# Expensive deterministic procurement. This owns Back Room definitions and
# spending; Reserve/Spawn still own storage, placement, and actual ball creation.
const ITEM_WAYFINDER_BALL := "wayfinder_ball"
const ITEM_POWDER_KEG_BALL := "powder_keg_ball"
const ITEM_TREASURE_BALL := "treasure_ball"
const ITEM_CANNON_BALL := "cannon_ball"
const ITEM_EMBEZZLER_BALL := "embezzler_ball"

const DEAL_ITEM_IDS := [
	ITEM_WAYFINDER_BALL,
	ITEM_POWDER_KEG_BALL,
	ITEM_TREASURE_BALL,
	ITEM_CANNON_BALL,
	ITEM_EMBEZZLER_BALL,
]

const DEAL_ITEMS := {
	ITEM_WAYFINDER_BALL: {
		"id": ITEM_WAYFINDER_BALL,
		"name": "Wayfinder Ball",
		"description": "A pocket-hungry compass ball.",
		"spawn_type": "wayfinder_ball",
		"icon_key": ITEM_WAYFINDER_BALL,
	},
	ITEM_POWDER_KEG_BALL: {
		"id": ITEM_POWDER_KEG_BALL,
		"name": "Powder Keg",
		"description": "A fuse-lit explosive ball.",
		"spawn_type": "powder_keg_ball",
		"icon_key": ITEM_POWDER_KEG_BALL,
	},
	ITEM_TREASURE_BALL: {
		"id": ITEM_TREASURE_BALL,
		"name": "Treasure Ball",
		"description": "A skittish hoard with legs.",
		"spawn_type": "treasure_ball",
		"icon_key": ITEM_TREASURE_BALL,
	},
	ITEM_CANNON_BALL: {
		"id": ITEM_CANNON_BALL,
		"name": "Cannon Ball",
		"description": "Heavy iron for ugly angles.",
		"spawn_type": "cannon_ball",
		"icon_key": ITEM_CANNON_BALL,
	},
	ITEM_EMBEZZLER_BALL: {
		"id": ITEM_EMBEZZLER_BALL,
		"name": "Embezzler",
		"description": "A greedy stowaway with a secret pocket.",
		"spawn_type": "embezzler_ball",
		"icon_key": ITEM_EMBEZZLER_BALL,
	},
}

@export var unlock_refresh_cost := 80
@export var deal_cost := 250

var table: BilliardsTable
var deals_made := 0
var doubloons_spent := 0
var denied_attempts := 0
var last_blocker_reason := ""
var debug_force_available := false


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	deals_made = 0
	doubloons_spent = 0
	denied_attempts = 0
	last_blocker_reason = ""
	debug_force_available = false
	_connect_event_sources()
	_emit_state_changed()


func get_deal_snapshot() -> Dictionary:
	var blocker := _get_deal_blocker()
	var unlocked := _is_unlocked()
	return {
		"unlocked": unlocked,
		"unlock_refresh_cost": _get_unlock_refresh_cost(),
		"current_refresh_cost": _get_current_refresh_cost(),
		"cost": _get_deal_cost(),
		"available": unlocked and blocker.is_empty(),
		"blocked_reason": blocker,
		"deals_made": deals_made,
		"doubloons_spent": doubloons_spent,
		"denied_attempts": denied_attempts,
		"last_blocker_reason": last_blocker_reason,
		"debug_force_available": debug_force_available,
		"options": _get_option_snapshots(),
	}


func set_debug_force_available(enabled: bool) -> void:
	if debug_force_available == enabled:
		return
	debug_force_available = enabled
	_emit_state_changed()


func request_purchase_deal(item_id: String) -> bool:
	var item := _get_item(item_id)
	if item.is_empty():
		return _deny_purchase("Unknown Back Room item")

	var blocker := _get_option_blocker(item_id)
	if not blocker.is_empty():
		return _deny_purchase(blocker)

	var slot_index: int = table.reserve_system.get_first_empty_slot_index()
	if slot_index == -1:
		return _deny_purchase("Reserve slots full")

	var cost := _get_deal_cost()
	if not table.score_system.try_spend_doubloons(cost):
		return _deny_purchase("Not enough Doubloons")

	if not table.reserve_system.store_item_in_slot(slot_index, _make_reserve_item_payload(item, cost)):
		return _deny_purchase("Reserve slot unavailable")

	deals_made += 1
	doubloons_spent += cost
	last_blocker_reason = ""
	deal_completed.emit(str(item["id"]), cost, deals_made)
	status_changed.emit("Back Room delivered %s to reserve slot %s." % [str(item["name"]), slot_index + 1])
	_emit_state_changed()
	return true


func _connect_event_sources() -> void:
	if table == null:
		return
	if table.quartermaster_system != null:
		if not table.quartermaster_system.shop_state_changed.is_connected(_on_quartermaster_shop_state_changed):
			table.quartermaster_system.shop_state_changed.connect(_on_quartermaster_shop_state_changed)
	if table.reserve_system != null:
		if not table.reserve_system.reserve_slots_changed.is_connected(_on_reserve_slots_changed):
			table.reserve_system.reserve_slots_changed.connect(_on_reserve_slots_changed)
	if table.score_system != null:
		if not table.score_system.doubloons_changed.is_connected(_on_doubloons_changed):
			table.score_system.doubloons_changed.connect(_on_doubloons_changed)


func _get_option_snapshots() -> Array:
	var options: Array = []
	for item_id_value in DEAL_ITEM_IDS:
		var item_id := str(item_id_value)
		var item := _get_item(item_id).duplicate(true)
		var blocker := _get_option_blocker(item_id)
		item["cost"] = _get_deal_cost()
		item["available"] = blocker.is_empty()
		item["blocked_reason"] = blocker
		options.append(item)
	return options


func _get_option_blocker(item_id: String) -> String:
	var deal_blocker := _get_deal_blocker()
	if not deal_blocker.is_empty():
		return deal_blocker
	if item_id == ITEM_EMBEZZLER_BALL:
		return _get_embezzler_blocker()
	return ""


func _get_deal_blocker() -> String:
	if table == null or table.score_system == null or table.reserve_system == null or table.quartermaster_system == null:
		return "Back Room not ready"
	if not _is_unlocked():
		return "Refresh cost must reach %s" % _get_unlock_refresh_cost()
	var quartermaster_blocker: String = table.quartermaster_system.get_quartermaster_access_blocker()
	if not quartermaster_blocker.is_empty():
		return quartermaster_blocker
	if table.reserve_system.is_full():
		return "Reserve slots full"
	if not table.score_system.can_afford_doubloons(_get_deal_cost()):
		return "Not enough Doubloons"
	return ""


func _get_embezzler_blocker() -> String:
	if table == null or table.spawn_system == null or table.embezzler_system == null:
		return "Embezzler unavailable"
	if _has_reserved_item(ITEM_EMBEZZLER_BALL):
		return "Embezzler already reserved"
	if not table.spawn_system.can_queue_cargo_replacement_kind(SpawnSystem.CARGO_REPLACEMENT_EMBEZZLER):
		return "Embezzler already at large"
	return ""


func _has_reserved_item(item_id: String) -> bool:
	if table == null or table.reserve_system == null:
		return false
	for slot_value in table.reserve_system.get_slots_snapshot():
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		if str(slot.get("item_id", "")) == item_id:
			return true
	return false


func _is_unlocked() -> bool:
	return debug_force_available or _get_current_refresh_cost() >= _get_unlock_refresh_cost()


func _get_current_refresh_cost() -> int:
	if table == null or table.quartermaster_system == null:
		return 0
	return table.quartermaster_system.get_current_refresh_cost()


func _get_unlock_refresh_cost() -> int:
	return maxi(unlock_refresh_cost, 0)


func _get_deal_cost() -> int:
	return maxi(deal_cost, 0)


func _get_item(item_id: String) -> Dictionary:
	if not DEAL_ITEMS.has(item_id):
		return {}
	return (DEAL_ITEMS[item_id] as Dictionary).duplicate(true)


func _make_reserve_item_payload(item: Dictionary, cost: int) -> Dictionary:
	return {
		"item_id": str(item["id"]),
		"item_name": str(item["name"]),
		"description": str(item.get("description", "")),
		"price": maxi(cost, 0),
		"spawn_type": str(item["spawn_type"]),
		"icon_key": str(item.get("icon_key", item["id"])),
		"source": "back_room_deal",
	}


func _deny_purchase(reason: String) -> bool:
	denied_attempts += 1
	last_blocker_reason = reason
	status_changed.emit(reason)
	_emit_state_changed()
	return false


func _emit_state_changed() -> void:
	state_changed.emit(get_deal_snapshot())


func _on_quartermaster_shop_state_changed(_items: Array) -> void:
	_emit_state_changed()


func _on_reserve_slots_changed(_slots: Array) -> void:
	_emit_state_changed()


func _on_doubloons_changed(_total: int) -> void:
	_emit_state_changed()
