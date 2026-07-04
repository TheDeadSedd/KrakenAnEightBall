extends RefCounted
class_name RogueliteRunSystem

# index:title Roguelite Run System
# index:category Run Modes
# index:status First Pass
# index:owner systems_agent
# index:notes Owns roguelite round objective state; gameplay mode ID remains roguelite.

signal state_changed(snapshot: Dictionary)
signal round_started(snapshot: Dictionary)
signal round_won(snapshot: Dictionary)
signal run_failed(snapshot: Dictionary)
signal run_completed(snapshot: Dictionary)

const ROUND_SETUPS := [
	{
		"round_number": 1,
		"target": 30,
		"shots": 3,
		"object_balls": 2,
	},
	{
		"round_number": 2,
		"target": 60,
		"shots": 4,
		"object_balls": 3,
	},
	{
		"round_number": 3,
		"target": 95,
		"shots": 4,
		"object_balls": 4,
	},
	{
		"round_number": 4,
		"target": 130,
		"shots": 5,
		"object_balls": 5,
	},
	{
		"round_number": 5,
		"target": 170,
		"shots": 5,
		"object_balls": 6,
	},
	{
		"round_number": 6,
		"target": 215,
		"shots": 5,
		"object_balls": 7,
	},
	{
		"round_number": 7,
		"target": 265,
		"shots": 6,
		"object_balls": 8,
	},
	{
		"round_number": 8,
		"target": 320,
		"shots": 6,
		"object_balls": 9,
	},
	{
		"round_number": 9,
		"target": 380,
		"shots": 6,
		"object_balls": 10,
	},
	{
		"round_number": 10,
		"target": 455,
		"shots": 7,
		"object_balls": 12,
	},
]

const STARTING_HULL := 3

var current_round_index := 0
var round_number := 1
var round_target := 20
var round_score := 0
var shots_left := 3
var hull := STARTING_HULL
var object_ball_count := 2
var round_active := false
var round_won_state := false
var run_failed_state := false
var run_completed_state := false
var reward_system: RogueliteRewardSystem


func set_reward_system(system: RogueliteRewardSystem) -> void:
	reward_system = system


func start_run() -> void:
	current_round_index = 0
	if reward_system != null:
		reward_system.reset_run_state()
	hull = _get_current_max_hull()
	run_completed_state = false
	run_failed_state = false
	start_current_round()


func start_current_round() -> void:
	var setup: Dictionary = get_current_round_setup()
	round_number = int(setup.get("round_number", 1))
	round_target = maxi(int(setup.get("target", 0)), 0)
	round_score = 0
	shots_left = maxi(int(setup.get("shots", 0)), 0)
	object_ball_count = maxi(int(setup.get("object_balls", 0)), 0)
	if reward_system != null:
		reward_system.begin_round(round_number)
	round_active = true
	round_won_state = false
	run_failed_state = false
	run_completed_state = false
	_emit_state()
	round_started.emit(get_snapshot())


func advance_to_next_round() -> bool:
	if run_failed_state or run_completed_state:
		return false
	if not round_won_state:
		return false
	if has_next_round():
		current_round_index += 1
		start_current_round()
		return true

	run_completed_state = true
	round_active = false
	_emit_state()
	run_completed.emit(get_snapshot())
	return false


func has_next_round() -> bool:
	return current_round_index + 1 < ROUND_SETUPS.size()


func get_current_round_setup() -> Dictionary:
	if ROUND_SETUPS.is_empty():
		return {}
	var safe_index: int = clampi(current_round_index, 0, ROUND_SETUPS.size() - 1)
	var setup: Dictionary = ROUND_SETUPS[safe_index] as Dictionary
	var base_setup: Dictionary = setup.duplicate(true)
	if reward_system != null:
		return reward_system.get_effective_round_setup(base_setup)
	return base_setup


func get_round_count() -> int:
	return ROUND_SETUPS.size()


func add_round_score(amount: int) -> void:
	if not round_active or round_won_state or run_failed_state or run_completed_state:
		return
	if amount <= 0:
		return

	round_score += amount
	if round_score >= round_target:
		round_won_state = true
		round_active = false
		_emit_state()
		round_won.emit(get_snapshot())
		return

	_emit_state()


func consume_shot() -> void:
	if run_failed_state or run_completed_state:
		return

	shots_left = maxi(0, shots_left - 1)
	if not round_won_state and shots_left <= 0 and round_score < round_target:
		run_failed_state = true
		round_active = false
		_emit_state()
		run_failed.emit(get_snapshot())
		return

	_emit_state()


func apply_reward_effect_snapshot(effect_snapshot: Dictionary) -> void:
	var restore_hull_amount: int = maxi(int(effect_snapshot.get("restore_hull", 0)), 0)
	if restore_hull_amount > 0:
		hull = mini(hull + restore_hull_amount, _get_current_max_hull())
		_emit_state()


func damage_hull(amount: int = 1) -> Dictionary:
	if run_failed_state or run_completed_state:
		return get_snapshot()

	var damage_amount: int = maxi(amount, 0)
	if damage_amount <= 0:
		return get_snapshot()

	hull = maxi(hull - damage_amount, 0)
	if hull <= 0:
		run_failed_state = true
		round_active = false
		_emit_state()
		run_failed.emit(get_snapshot())
		return get_snapshot()

	_emit_state()
	return get_snapshot()


func get_snapshot() -> Dictionary:
	return {
		"round_index": current_round_index,
		"round_number": round_number,
		"round_count": get_round_count(),
		"round_target": round_target,
		"round_score": round_score,
		"shots_left": shots_left,
		"hull": hull,
		"max_hull": _get_current_max_hull(),
		"starting_hull": STARTING_HULL,
		"object_ball_count": object_ball_count,
		"round_active": round_active,
		"round_won": round_won_state,
		"run_failed": run_failed_state,
		"run_completed": run_completed_state,
		"has_next_round": has_next_round(),
	}


func _emit_state() -> void:
	state_changed.emit(get_snapshot())


func _get_current_max_hull() -> int:
	var max_hull: int = STARTING_HULL
	if reward_system != null:
		max_hull += reward_system.get_max_hull_bonus()
	return maxi(max_hull, 1)
