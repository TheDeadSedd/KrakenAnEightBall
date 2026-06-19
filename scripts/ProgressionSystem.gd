extends Node
class_name ProgressionSystem

signal progression_changed(snapshot: Dictionary)
signal kraken_favor_awarded(amount: int, total: int, award_snapshot: Dictionary)
signal kraken_favor_spent(amount: int, total: int, reason: String)

# Persistent run-spanning progression currency only. Cue upgrades will consume
# this later, but no upgrade inventory or shop logic belongs in this pass.
const PROGRESSION_FILE_PATH := "user://progression.json"
const SAVE_VERSION := 2

@export var base_success_favor_reward := 1
@export var doubloons_earned_bonus_threshold := 5000
@export var request_completion_bonus_threshold := 3
@export var legendary_event_bonus_threshold := 1
@export var treasure_claim_bonus_threshold := 1
@export var max_favor_reward_per_run := 5

var total_kraken_favor := 0
var lifetime_kraken_favor_earned := 0
var successful_passages := 0
var current_run_reward_finalized := false
var last_award_snapshot: Dictionary = {}
var cue_progression_data: Dictionary = {}


func _ready() -> void:
	load_progression()


func load_progression() -> void:
	total_kraken_favor = 0
	lifetime_kraken_favor_earned = 0
	successful_passages = 0
	last_award_snapshot = {}
	cue_progression_data = {}

	if not FileAccess.file_exists(PROGRESSION_FILE_PATH):
		progression_changed.emit(get_progression_snapshot())
		return

	var file := FileAccess.open(PROGRESSION_FILE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not read progression data: %s" % FileAccess.get_open_error())
		progression_changed.emit(get_progression_snapshot())
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_warning("Progression file was not a dictionary.")
		progression_changed.emit(get_progression_snapshot())
		return

	var payload: Dictionary = parsed as Dictionary
	total_kraken_favor = maxi(int(payload.get("total_kraken_favor", 0)), 0)
	lifetime_kraken_favor_earned = maxi(int(payload.get("lifetime_kraken_favor_earned", total_kraken_favor)), 0)
	successful_passages = maxi(int(payload.get("successful_passages", 0)), 0)
	var last_award_value: Variant = payload.get("last_award", {})
	if last_award_value is Dictionary:
		last_award_snapshot = (last_award_value as Dictionary).duplicate(true)
	var cue_progression_value: Variant = payload.get("cue_progression", {})
	if cue_progression_value is Dictionary:
		cue_progression_data = (cue_progression_value as Dictionary).duplicate(true)
	progression_changed.emit(get_progression_snapshot())


func get_progression_snapshot() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"save_path": PROGRESSION_FILE_PATH,
		"total_kraken_favor": total_kraken_favor,
		"lifetime_kraken_favor_earned": lifetime_kraken_favor_earned,
		"successful_passages": successful_passages,
		"current_run_reward_finalized": current_run_reward_finalized,
		"last_award": last_award_snapshot.duplicate(true),
		"cue_progression": cue_progression_data.duplicate(true),
		"reward_formula": get_reward_formula_snapshot(),
	}


func can_afford_kraken_favor(amount: int) -> bool:
	return total_kraken_favor >= maxi(amount, 0)


func try_spend_kraken_favor(amount: int, reason: String = "") -> bool:
	var spend_amount := maxi(amount, 0)
	if spend_amount <= 0:
		return true
	if not can_afford_kraken_favor(spend_amount):
		return false

	total_kraken_favor -= spend_amount
	if not _write_progression():
		total_kraken_favor += spend_amount
		return false

	kraken_favor_spent.emit(spend_amount, total_kraken_favor, reason)
	progression_changed.emit(get_progression_snapshot())
	return true


func try_spend_kraken_favor_and_set_cue_progression(amount: int, data: Dictionary, reason: String = "") -> bool:
	var spend_amount := maxi(amount, 0)
	if spend_amount > 0 and not can_afford_kraken_favor(spend_amount):
		return false

	var previous_total := total_kraken_favor
	var previous_cue_progression := cue_progression_data.duplicate(true)
	total_kraken_favor -= spend_amount
	cue_progression_data = data.duplicate(true)
	if not _write_progression():
		total_kraken_favor = previous_total
		cue_progression_data = previous_cue_progression
		return false

	if spend_amount > 0:
		kraken_favor_spent.emit(spend_amount, total_kraken_favor, reason)
	progression_changed.emit(get_progression_snapshot())
	return true


func get_cue_progression_data_snapshot() -> Dictionary:
	return cue_progression_data.duplicate(true)


func set_cue_progression_data(data: Dictionary) -> bool:
	cue_progression_data = data.duplicate(true)
	var write_succeeded := _write_progression()
	if not write_succeeded:
		load_progression()
		return false

	progression_changed.emit(get_progression_snapshot())
	return true


func get_reward_formula_snapshot() -> Dictionary:
	return {
		"base_success_favor_reward": _get_base_success_favor_reward(),
		"doubloons_earned_bonus_threshold": _get_doubloons_earned_bonus_threshold(),
		"request_completion_bonus_threshold": _get_request_completion_bonus_threshold(),
		"legendary_event_bonus_threshold": _get_legendary_event_bonus_threshold(),
		"treasure_claim_bonus_threshold": _get_treasure_claim_bonus_threshold(),
		"max_favor_reward_per_run": _get_max_favor_reward_per_run(),
	}


func finalize_successful_passage(stats_snapshot: Dictionary) -> Dictionary:
	if current_run_reward_finalized:
		return last_award_snapshot.duplicate(true)
	if not bool(stats_snapshot.get("passage_completed", false)):
		last_award_snapshot = _make_empty_award("Passage was not completed.")
		return last_award_snapshot.duplicate(true)

	current_run_reward_finalized = true
	var award_snapshot := calculate_kraken_favor_reward(stats_snapshot)
	var amount := maxi(int(award_snapshot.get("kraken_favor_earned", 0)), 0)
	total_kraken_favor += amount
	lifetime_kraken_favor_earned += amount
	successful_passages += 1
	award_snapshot["total_kraken_favor"] = total_kraken_favor
	award_snapshot["successful_passages"] = successful_passages
	award_snapshot["timestamp"] = Time.get_datetime_string_from_system(false, false)
	last_award_snapshot = award_snapshot.duplicate(true)
	_write_progression()
	kraken_favor_awarded.emit(amount, total_kraken_favor, last_award_snapshot.duplicate(true))
	progression_changed.emit(get_progression_snapshot())
	return last_award_snapshot.duplicate(true)


func calculate_kraken_favor_reward(stats_snapshot: Dictionary) -> Dictionary:
	var amount := _get_base_success_favor_reward()
	var breakdown: Array[Dictionary] = []
	_add_breakdown_line(breakdown, "Passage granted", _get_base_success_favor_reward(), true)

	var earned_doubloons := maxi(int(stats_snapshot.get("doubloons_earned", 0)), 0)
	var earned_doubloons_bonus := earned_doubloons >= _get_doubloons_earned_bonus_threshold()
	if earned_doubloons_bonus:
		amount += 1
	_add_breakdown_line(
		breakdown,
		"Earned %s+ Doubloons" % _get_doubloons_earned_bonus_threshold(),
		1,
		earned_doubloons_bonus
	)

	var requests_completed := maxi(int(stats_snapshot.get("kraken_requests_completed", 0)), 0)
	var request_bonus := requests_completed >= _get_request_completion_bonus_threshold()
	if request_bonus:
		amount += 1
	_add_breakdown_line(
		breakdown,
		"Completed %s+ Kraken Requests" % _get_request_completion_bonus_threshold(),
		1,
		request_bonus
	)

	var legendary_events := maxi(int(stats_snapshot.get("legendary_events_awarded", 0)), 0)
	var legendary_bonus := legendary_events >= _get_legendary_event_bonus_threshold()
	if legendary_bonus:
		amount += 1
	_add_breakdown_line(
		breakdown,
		"Scored a Legendary event",
		1,
		legendary_bonus
	)

	var treasure_claimed := maxi(int(stats_snapshot.get("treasure_claimed", 0)), 0)
	var treasure_bonus := treasure_claimed >= _get_treasure_claim_bonus_threshold()
	if treasure_bonus:
		amount += 1
	_add_breakdown_line(
		breakdown,
		"Claimed Treasure",
		1,
		treasure_bonus
	)

	var reward_cap := _get_max_favor_reward_per_run()
	if reward_cap > 0:
		amount = mini(amount, reward_cap)

	return {
		"kraken_favor_earned": maxi(amount, 0),
		"total_kraken_favor": total_kraken_favor,
		"breakdown": breakdown,
		"stats_used": {
			"doubloons_earned": earned_doubloons,
			"kraken_requests_completed": requests_completed,
			"legendary_events_awarded": legendary_events,
			"treasure_claimed": treasure_claimed,
		},
		"formula": get_reward_formula_snapshot(),
	}


func get_save_path() -> String:
	return PROGRESSION_FILE_PATH


func _make_empty_award(reason: String) -> Dictionary:
	return {
		"kraken_favor_earned": 0,
		"total_kraken_favor": total_kraken_favor,
		"breakdown": [],
		"reason": reason,
	}


func _add_breakdown_line(lines: Array[Dictionary], label: String, amount: int, earned: bool) -> void:
	lines.append({
		"label": label,
		"amount": maxi(amount, 0),
		"earned": earned,
	})


func _write_progression() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"total_kraken_favor": maxi(total_kraken_favor, 0),
		"lifetime_kraken_favor_earned": maxi(lifetime_kraken_favor_earned, 0),
		"successful_passages": maxi(successful_passages, 0),
		"last_award": last_award_snapshot,
		"cue_progression": cue_progression_data,
	}
	var file := FileAccess.open(PROGRESSION_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write progression data: %s" % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	return true


func _get_base_success_favor_reward() -> int:
	return maxi(base_success_favor_reward, 0)


func _get_doubloons_earned_bonus_threshold() -> int:
	return maxi(doubloons_earned_bonus_threshold, 0)


func _get_request_completion_bonus_threshold() -> int:
	return maxi(request_completion_bonus_threshold, 1)


func _get_legendary_event_bonus_threshold() -> int:
	return maxi(legendary_event_bonus_threshold, 1)


func _get_treasure_claim_bonus_threshold() -> int:
	return maxi(treasure_claim_bonus_threshold, 1)


func _get_max_favor_reward_per_run() -> int:
	return maxi(max_favor_reward_per_run, 0)
