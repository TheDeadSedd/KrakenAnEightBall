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
const CUE_MODIFIER_PASSAGE_REQUEST_REWARD_MULTIPLIER_BONUS := "passage_request_reward_multiplier_bonus"

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
@export var request_reroll_lockout_count := 3

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
var cue_modifier_snapshot: Dictionary = {}
var request_reroll_lockout_queue: Array[String] = []
var last_rejected_request_id := ""


func _ready() -> void:
	rng.randomize()


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	passage_reduced_by_requests = 0
	passage_added_by_request_rerolls = 0
	passage_added_by_oaths = 0
	request_rerolls_used = 0
	current_request_reroll_cost = _get_request_reroll_base_cost()
	request_reroll_lockout_queue.clear()
	last_rejected_request_id = ""
	completed = false
	voyage_marks_awarded = 0
	_select_new_request()
	_connect_event_sources()
	_recalculate_remaining_passage()


func get_passage_snapshot() -> Dictionary:
	var request := _get_active_request()
	var request_id := str(request.get("id", ""))
	var metadata: Dictionary = EventMetadata.get_event_metadata(request_id)
	var base_reward: int = _get_base_request_reward(request)
	var effective_reward: int = _get_effective_request_reward(base_reward)
	var reward_modifier_snapshot: Dictionary = get_request_reward_modifier_snapshot()
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
		"request_reroll_lockout_count": _get_request_reroll_lockout_count(),
		"request_reroll_lockout_queue": request_reroll_lockout_queue.duplicate(),
		"request_reroll_lockout_labels": _get_request_reroll_lockout_labels(),
		"last_rejected_request_id": last_rejected_request_id,
		"last_rejected_request_label": _get_request_label_for_id(last_rejected_request_id),
		"request_reroll_available": _can_reroll_request(),
		"current_request_id": request_id,
		"current_request_label": str(metadata.get("label", request.get("label", ""))),
		"current_request_description": str(metadata.get("description", "Complete this requested scoring feat.")),
		"current_request_base_reward": base_reward,
		"current_request_reward": effective_reward,
		"request_reward_multiplier": float(reward_modifier_snapshot.get("multiplier", 1.0)),
		"request_reward_multiplier_bonus": float(reward_modifier_snapshot.get("bonus", 0.0)),
		"request_reward_multiplier_bonus_summary": str(reward_modifier_snapshot.get("summary", "+0%")),
		"current_request_tier": str(request.get("tier", "")),
		"run_completed": completed,
		"voyage_marks_awarded": voyage_marks_awarded,
	}


func set_cue_modifier_snapshot(snapshot: Dictionary) -> void:
	cue_modifier_snapshot = snapshot.duplicate(true)
	_recalculate_remaining_passage()


func get_request_reward_modifier_snapshot() -> Dictionary:
	var bonus := _get_request_reward_multiplier_bonus()
	var multiplier := _get_request_reward_multiplier()
	return {
		"bonus": bonus,
		"multiplier": multiplier,
		"summary": _format_multiplier_bonus_percent(bonus),
		"active_cue_modifiers_summary": _get_active_cue_modifier_summary(),
	}


func get_active_request_snapshot() -> Dictionary:
	return _make_request_snapshot(_get_active_request())


func request_reroll_active_request() -> bool:
	if not _can_reroll_request():
		return false

	var previous_request := get_active_request_snapshot()
	var previous_request_id := str(previous_request.get("id", ""))
	var reroll_cost := get_current_request_reroll_cost()
	passage_added_by_request_rerolls += reroll_cost
	request_rerolls_used += 1
	_remember_reroll_rejection(previous_request_id)
	_select_new_request(true)
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


func _select_new_request(use_reroll_lockout: bool = false) -> void:
	if REQUEST_POOL.is_empty():
		request_index = -1
		return

	var current_request_id := _get_request_id_at_index(request_index)
	var excluded_request_ids: Array[String] = []
	if not current_request_id.is_empty():
		excluded_request_ids.append(current_request_id)
	if use_reroll_lockout:
		excluded_request_ids.append_array(request_reroll_lockout_queue)

	var candidate_indices := _get_request_candidate_indices(excluded_request_ids)
	if candidate_indices.is_empty() and use_reroll_lockout:
		var current_only_exclusions: Array[String] = []
		if not current_request_id.is_empty():
			current_only_exclusions.append(current_request_id)
		candidate_indices = _get_request_candidate_indices(current_only_exclusions)
	if candidate_indices.is_empty():
		candidate_indices = _get_all_request_indices()

	var next_index: int = candidate_indices[rng.randi_range(0, candidate_indices.size() - 1)]
	request_index = next_index


func _remember_reroll_rejection(request_id: String) -> void:
	last_rejected_request_id = request_id
	if request_id.is_empty():
		return

	var lockout_count := _get_request_reroll_lockout_count()
	if lockout_count <= 0:
		request_reroll_lockout_queue.clear()
		return

	request_reroll_lockout_queue.erase(request_id)
	request_reroll_lockout_queue.append(request_id)
	while request_reroll_lockout_queue.size() > lockout_count:
		request_reroll_lockout_queue.pop_front()


func _get_request_candidate_indices(excluded_request_ids: Array[String]) -> Array[int]:
	var excluded_lookup := {}
	for excluded_request_id in excluded_request_ids:
		if not excluded_request_id.is_empty():
			excluded_lookup[excluded_request_id] = true

	var indices: Array[int] = []
	for index in range(REQUEST_POOL.size()):
		var request_id := _get_request_id_at_index(index)
		if request_id.is_empty() or excluded_lookup.has(request_id):
			continue
		indices.append(index)
	return indices


func _get_all_request_indices() -> Array[int]:
	var indices: Array[int] = []
	for index in range(REQUEST_POOL.size()):
		indices.append(index)
	return indices


func _get_request_id_at_index(index: int) -> String:
	if index < 0 or index >= REQUEST_POOL.size():
		return ""
	var request: Dictionary = REQUEST_POOL[index] as Dictionary
	return str(request.get("id", ""))


func _get_request_label_for_id(request_id: String) -> String:
	if request_id.is_empty():
		return ""
	for request_value in REQUEST_POOL:
		var request: Dictionary = request_value as Dictionary
		if str(request.get("id", "")) != request_id:
			continue
		var metadata: Dictionary = EventMetadata.get_event_metadata(request_id)
		return str(metadata.get("label", request.get("label", request_id)))
	return request_id


func _get_request_reroll_lockout_labels() -> Array[String]:
	var labels: Array[String] = []
	for request_id in request_reroll_lockout_queue:
		labels.append(_get_request_label_for_id(request_id))
	return labels


func _get_active_request() -> Dictionary:
	if request_index < 0 or request_index >= REQUEST_POOL.size():
		return {}
	return (REQUEST_POOL[request_index] as Dictionary).duplicate(true)


func _make_request_snapshot(request: Dictionary) -> Dictionary:
	if request.is_empty():
		return {}

	var snapshot := request.duplicate(true)
	var request_id := str(snapshot.get("id", ""))
	var metadata: Dictionary = EventMetadata.get_event_metadata(request_id)
	snapshot["id"] = request_id
	snapshot["request_id"] = request_id
	snapshot["event_type"] = str(snapshot.get("event_type", ""))
	snapshot["label"] = str(metadata.get("label", snapshot.get("label", "")))
	snapshot["description"] = str(metadata.get("description", "Complete this requested scoring feat."))
	var base_reward := _get_base_request_reward(snapshot)
	snapshot["base_reward"] = base_reward
	snapshot["reward"] = _get_effective_request_reward(base_reward)
	snapshot["reward_multiplier"] = _get_request_reward_multiplier()
	snapshot["reward_multiplier_bonus"] = _get_request_reward_multiplier_bonus()
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


func _get_request_reroll_lockout_count() -> int:
	return maxi(request_reroll_lockout_count, 0)


func _get_request_reroll_completion_decay() -> int:
	return maxi(request_reroll_completion_decay, 0)


func _get_base_request_reward(request: Dictionary) -> int:
	if request.has("base_reward"):
		return maxi(int(request.get("base_reward", 0)), 0)
	return maxi(int(request.get("reward", 0)), 0)


func _get_effective_request_reward(base_reward: int) -> int:
	var multiplier := _get_request_reward_multiplier()
	return maxi(roundi(float(maxi(base_reward, 0)) * multiplier), 0)


func _get_request_reward_multiplier() -> float:
	return maxf(1.0 + _get_request_reward_multiplier_bonus(), 0.0)


func _get_request_reward_multiplier_bonus() -> float:
	return maxf(_get_cue_modifier_value(CUE_MODIFIER_PASSAGE_REQUEST_REWARD_MULTIPLIER_BONUS, 0.0), 0.0)


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


func _format_multiplier_bonus_percent(value: float) -> String:
	return "+%.0f%%" % (maxf(value, 0.0) * 100.0)


func _get_next_request_reroll_cost(paid_cost: int) -> int:
	var next_cost := ceili(float(maxi(paid_cost, _get_request_reroll_base_cost())) * maxf(request_reroll_cost_multiplier, 1.0))
	return maxi(next_cost, _get_request_reroll_min_cost())


func _decay_request_reroll_cost() -> void:
	var floor_cost := _get_request_reroll_base_cost()
	current_request_reroll_cost = maxi(current_request_reroll_cost - _get_request_reroll_completion_decay(), floor_cost)
