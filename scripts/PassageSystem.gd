extends Node
class_name PassageSystem

signal passage_changed(snapshot: Dictionary)
signal request_completed(request_snapshot: Dictionary, reward: int)
signal request_rerolled(previous_request_snapshot: Dictionary, new_request_snapshot: Dictionary, cost: int)
signal passage_completed(snapshot: Dictionary)

const REQUEST_BANK := "BANK"
const REQUEST_DOUBLE_BANK := "DOUBLE_BANK"
const REQUEST_LONG_HAUL := "LONG_HAUL"
const REQUEST_POWER_SINK := "POWER_SINK"
const REQUEST_POCKET_STREAK_X3 := EventMetadata.EVENT_POCKET_STREAK_X3
const REQUEST_POWDER_ROUTE := "POWDER_ROUTE"
const REQUEST_CANNON_CHAIN := "CANNON_CHAIN"
const REQUEST_TREASURE_SNARE := "TREASURE_SNARE"

const REQUEST_POOL := [
	{
		"id": REQUEST_BANK,
		"event_type": ShotEventSystem.EVENT_BANK,
		"label": "BANK",
		"reward": 250,
		"tier": "common",
	},
	{
		"id": REQUEST_DOUBLE_BANK,
		"event_type": ShotEventSystem.EVENT_DOUBLE_BANK,
		"label": "DOUBLE BANK",
		"reward": 600,
		"tier": "skilled",
	},
	{
		"id": REQUEST_LONG_HAUL,
		"event_type": ShotEventSystem.EVENT_LONG_HAUL,
		"label": "LONG HAUL",
		"reward": 900,
		"tier": "heroic",
	},
	{
		"id": REQUEST_POWER_SINK,
		"event_type": ShotEventSystem.EVENT_POWER_SINK,
		"label": "POWER SINK",
		"reward": 600,
		"tier": "skilled",
	},
	{
		"id": REQUEST_POCKET_STREAK_X3,
		"event_type": "",
		"label": "POCKET STREAK X3",
		"reward": 850,
		"tier": "heroic",
	},
	{
		"id": REQUEST_POWDER_ROUTE,
		"event_type": ShotEventSystem.EVENT_POWDER_ROUTE,
		"label": "POWDER ROUTE",
		"reward": 900,
		"tier": "heroic",
	},
	{
		"id": REQUEST_CANNON_CHAIN,
		"event_type": ShotEventSystem.EVENT_CANNON_CHAIN,
		"label": "CANNON CHAIN",
		"reward": 1400,
		"tier": "legendary",
	},
	{
		"id": REQUEST_TREASURE_SNARE,
		"event_type": ShotEventSystem.EVENT_TREASURE_SNARE,
		"label": "TREASURE SNARE",
		"reward": 1400,
		"tier": "legendary",
	},
]

@export var passage_required := 10000
@export var voyage_marks_reward := 1
@export var request_reroll_base_cost := 10
@export var request_reroll_cost_multiplier := 2.0
@export var request_reroll_completion_decay := 10
@export var request_reroll_min_cost := 10

var table: BilliardsTable
var rng := RandomNumberGenerator.new()
var request_index := -1
var passage_reduced_by_requests := 0
var passage_added_by_request_rerolls := 0
var passage_added_by_oaths := 0
var request_rerolls_used := 0
var current_request_reroll_cost := 10
var remaining_passage := 10000
var completed := false
var voyage_marks_awarded := 0


func _ready() -> void:
	rng.randomize()


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	passage_reduced_by_requests = 0
	passage_added_by_request_rerolls = 0
	passage_added_by_oaths = 0
	request_rerolls_used = 0
	current_request_reroll_cost = _get_request_reroll_base_cost()
	completed = false
	voyage_marks_awarded = 0
	_select_new_request()
	_connect_event_sources()
	_recalculate_remaining_passage()


func get_passage_snapshot() -> Dictionary:
	var request := _get_active_request()
	var request_id := str(request.get("id", ""))
	var metadata := EventMetadata.get_event_metadata(request_id)
	return {
		"passage_required": maxi(passage_required, 0),
		"remaining_passage": maxi(remaining_passage, 0),
		"passage_reduced_by_requests": maxi(passage_reduced_by_requests, 0),
		"passage_added_by_request_rerolls": maxi(passage_added_by_request_rerolls, 0),
		"passage_added_by_oaths": maxi(passage_added_by_oaths, 0),
		"request_rerolls_used": maxi(request_rerolls_used, 0),
		"current_request_reroll_cost": get_current_request_reroll_cost(),
		"request_reroll_base_cost": _get_request_reroll_base_cost(),
		"request_reroll_cost_multiplier": maxf(request_reroll_cost_multiplier, 1.0),
		"request_reroll_completion_decay": _get_request_reroll_completion_decay(),
		"request_reroll_min_cost": _get_request_reroll_min_cost(),
		"request_reroll_available": _can_reroll_request(),
		"current_request_id": request_id,
		"current_request_label": str(metadata.get("label", request.get("label", ""))),
		"current_request_description": str(metadata.get("description", "Complete this requested scoring feat.")),
		"current_request_reward": maxi(int(request.get("reward", 0)), 0),
		"current_request_tier": str(request.get("tier", "")),
		"run_completed": completed,
		"voyage_marks_awarded": voyage_marks_awarded,
	}


func get_active_request_snapshot() -> Dictionary:
	return _make_request_snapshot(_get_active_request())


func request_reroll_active_request() -> bool:
	if not _can_reroll_request():
		return false

	var previous_request := get_active_request_snapshot()
	var reroll_cost := get_current_request_reroll_cost()
	passage_added_by_request_rerolls += reroll_cost
	request_rerolls_used += 1
	_select_new_request()
	var new_request := get_active_request_snapshot()
	current_request_reroll_cost = _get_next_request_reroll_cost(reroll_cost)
	request_rerolled.emit(previous_request.duplicate(true), new_request.duplicate(true), reroll_cost)
	_recalculate_remaining_passage()
	return true


func get_current_request_reroll_cost() -> int:
	return maxi(current_request_reroll_cost, _get_request_reroll_base_cost())


func add_passage_pressure(amount: int) -> void:
	var pressure_amount := maxi(amount, 0)
	if pressure_amount <= 0 or completed:
		return

	passage_added_by_oaths += pressure_amount
	_recalculate_remaining_passage()


func _connect_event_sources() -> void:
	if table == null:
		return

	if table.score_system != null:
		if not table.score_system.doubloons_changed.is_connected(_on_doubloons_changed):
			table.score_system.doubloons_changed.connect(_on_doubloons_changed)
		if not table.score_system.scoring_event_awarded.is_connected(_on_scoring_event_awarded):
			table.score_system.scoring_event_awarded.connect(_on_scoring_event_awarded)
	if table.pocket_streak_system != null:
		if not table.pocket_streak_system.streak_multiplier_reached.is_connected(_on_streak_multiplier_reached):
			table.pocket_streak_system.streak_multiplier_reached.connect(_on_streak_multiplier_reached)


func _select_new_request() -> void:
	if REQUEST_POOL.is_empty():
		request_index = -1
		return

	var next_index := rng.randi_range(0, REQUEST_POOL.size() - 1)
	if REQUEST_POOL.size() > 1 and next_index == request_index:
		next_index = (next_index + 1 + rng.randi_range(0, REQUEST_POOL.size() - 2)) % REQUEST_POOL.size()
	request_index = next_index


func _get_active_request() -> Dictionary:
	if request_index < 0 or request_index >= REQUEST_POOL.size():
		return {}
	return (REQUEST_POOL[request_index] as Dictionary).duplicate(true)


func _make_request_snapshot(request: Dictionary) -> Dictionary:
	if request.is_empty():
		return {}

	var snapshot := request.duplicate(true)
	var request_id := str(snapshot.get("id", ""))
	var metadata := EventMetadata.get_event_metadata(request_id)
	snapshot["id"] = request_id
	snapshot["request_id"] = request_id
	snapshot["event_type"] = str(snapshot.get("event_type", ""))
	snapshot["label"] = str(metadata.get("label", snapshot.get("label", "")))
	snapshot["description"] = str(metadata.get("description", "Complete this requested scoring feat."))
	snapshot["reward"] = maxi(int(snapshot.get("reward", 0)), 0)
	snapshot["tier"] = str(snapshot.get("tier", ""))
	return snapshot


func _on_doubloons_changed(_total: int) -> void:
	_recalculate_remaining_passage()


func _on_scoring_event_awarded(event_type: String, _amount: int) -> void:
	var request := _get_active_request()
	if request.is_empty():
		return
	if str(request.get("event_type", "")) != event_type:
		return

	_complete_active_request(request)


func _on_streak_multiplier_reached(multiplier: int) -> void:
	if multiplier < 3:
		return

	var request := _get_active_request()
	if str(request.get("id", "")) != REQUEST_POCKET_STREAK_X3:
		return

	_complete_active_request(request)


func _complete_active_request(request: Dictionary) -> void:
	if completed:
		return

	var completed_request := _make_request_snapshot(request)
	var reward := maxi(int(completed_request.get("reward", 0)), 0)
	passage_reduced_by_requests += reward
	request_completed.emit(completed_request.duplicate(true), reward)
	_decay_request_reroll_cost()
	_select_new_request()
	_recalculate_remaining_passage()


func _recalculate_remaining_passage() -> void:
	var held_doubloons := 0
	if table != null and table.score_system != null:
		held_doubloons = maxi(table.score_system.get_doubloons_total(), 0)

	remaining_passage = maxi(passage_required + passage_added_by_request_rerolls + passage_added_by_oaths - passage_reduced_by_requests - held_doubloons, 0)
	var snapshot := get_passage_snapshot()
	passage_changed.emit(snapshot)
	if not completed and remaining_passage <= 0:
		completed = true
		voyage_marks_awarded = maxi(voyage_marks_reward, 0)
		snapshot = get_passage_snapshot()
		passage_changed.emit(snapshot)
		passage_completed.emit(snapshot)


func _can_reroll_request() -> bool:
	return not completed and not _get_active_request().is_empty() and REQUEST_POOL.size() > 1


func _get_request_reroll_base_cost() -> int:
	return maxi(request_reroll_base_cost, _get_request_reroll_min_cost())


func _get_request_reroll_min_cost() -> int:
	return maxi(request_reroll_min_cost, 0)


func _get_request_reroll_completion_decay() -> int:
	return maxi(request_reroll_completion_decay, 0)


func _get_next_request_reroll_cost(paid_cost: int) -> int:
	var next_cost := ceili(float(maxi(paid_cost, _get_request_reroll_base_cost())) * maxf(request_reroll_cost_multiplier, 1.0))
	return maxi(next_cost, _get_request_reroll_min_cost())


func _decay_request_reroll_cost() -> void:
	var floor_cost := _get_request_reroll_base_cost()
	current_request_reroll_cost = maxi(current_request_reroll_cost - _get_request_reroll_completion_decay(), floor_cost)
