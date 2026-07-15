extends RefCounted
class_name RogueliteRewardSystem

# index:title Roguelite Reward System
# index:category Run Modes
# index:status First Pass
# index:owner systems_agent
# index:notes Owns roguelite reward definitions, offers, chosen state, and reward effect snapshots.

signal rewards_changed(snapshot: Dictionary)
signal reward_chosen(reward_snapshot: Dictionary, effects_snapshot: Dictionary)

const REWARD_REINFORCED_HULL := "reinforced_hull"
const REWARD_SPARE_SHOT := "spare_shot"
const REWARD_HEAVY_PURSE := "heavy_purse"
const REWARD_BANKERS_WAKE := "bankers_wake"
const REWARD_CROWDED_HOLD := "crowded_hold"
const REWARD_OPENING_VOLLEY := "opening_volley"

const OFFER_COUNT := 3
const HEAVY_PURSE_QUOTA_BONUS := 5
const BANKERS_WAKE_QUOTA_BONUS := 10
const OPENING_VOLLEY_QUOTA_BONUS := 10

const REWARD_DEFINITIONS := [
	{
		"id": REWARD_REINFORCED_HULL,
		"display_name": "Reinforced Hull",
		"description": "Gain +1 max Hull. Restore 1 Hull.",
		"stackable": false,
	},
	{
		"id": REWARD_SPARE_SHOT,
		"display_name": "Spare Shot",
		"description": "Start each future round with +1 shot.",
		"stackable": false,
	},
	{
		"id": REWARD_HEAVY_PURSE,
		"display_name": "Heavy Purse",
		"description": "Object-ball sinks add +5 quota progress.",
		"stackable": false,
	},
	{
		"id": REWARD_BANKERS_WAKE,
		"display_name": "Banker's Wake",
		"description": "Bank-shot scoring adds +10 quota progress.",
		"stackable": false,
	},
	{
		"id": REWARD_CROWDED_HOLD,
		"display_name": "Crowded Hold",
		"description": "Future rounds start with +1 ball. Future quotas are +10.",
		"stackable": false,
	},
	{
		"id": REWARD_OPENING_VOLLEY,
		"display_name": "Opening Volley",
		"description": "First scoring shot each round adds +10 quota progress.",
		"stackable": false,
	},
]

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var chosen_reward_ids: Array[String] = []
var chosen_reward_lookup: Dictionary = {}
var chosen_reward_history: Array[Dictionary] = []
var active_offer_ids: Array[String] = []
var active_offer_round: int = 0
var max_hull_bonus: int = 0
var future_shot_bonus: int = 0
var future_object_ball_bonus: int = 0
var future_quota_bonus: int = 0
var object_sink_quota_bonus: int = 0
var bank_shot_quota_bonus: int = 0
var opening_volley_quota_bonus: int = 0
var opening_volley_used_rounds: Dictionary = {}


func setup() -> void:
	rng.randomize()
	reset_run_state()


func reset_run_state() -> void:
	chosen_reward_ids.clear()
	chosen_reward_lookup.clear()
	chosen_reward_history.clear()
	active_offer_ids.clear()
	active_offer_round = 0
	max_hull_bonus = 0
	future_shot_bonus = 0
	future_object_ball_bonus = 0
	future_quota_bonus = 0
	object_sink_quota_bonus = 0
	bank_shot_quota_bonus = 0
	opening_volley_quota_bonus = 0
	opening_volley_used_rounds.clear()
	_emit_changed()


func generate_reward_offers(round_number: int) -> Dictionary:
	active_offer_ids.clear()
	active_offer_round = maxi(round_number, 0)

	var eligible_ids: Array[String] = _get_eligible_reward_ids()
	_append_random_offer_ids(eligible_ids)
	if active_offer_ids.size() < OFFER_COUNT:
		var fallback_ids: Array[String] = _get_all_reward_ids()
		for active_offer_id in active_offer_ids:
			fallback_ids.erase(active_offer_id)
		_append_random_offer_ids(fallback_ids)

	_emit_changed()
	return get_reward_snapshot()


func choose_reward(reward_id: String) -> Dictionary:
	if not active_offer_ids.has(reward_id):
		return {}

	var definition: Dictionary = get_reward_definition(reward_id)
	if definition.is_empty():
		return {}

	var effects_snapshot: Dictionary = _apply_reward_effect(reward_id)
	if not bool(definition.get("stackable", false)):
		chosen_reward_lookup[reward_id] = true
	if not chosen_reward_ids.has(reward_id):
		chosen_reward_ids.append(reward_id)

	active_offer_ids.clear()
	var reward_snapshot: Dictionary = _make_reward_snapshot(definition)
	chosen_reward_history.append(reward_snapshot.duplicate(true))
	reward_chosen.emit(reward_snapshot.duplicate(true), effects_snapshot.duplicate(true))
	_emit_changed()
	return {
		"reward": reward_snapshot,
		"effects": effects_snapshot,
	}


func get_reward_snapshot() -> Dictionary:
	return {
		"offers": get_active_offer_snapshots(),
		"active_offer_ids": active_offer_ids.duplicate(),
		"active_offer_round": active_offer_round,
		"chosen_reward_ids": _get_chosen_reward_history_ids(),
		"chosen_reward_display_names": _get_chosen_reward_history_names(),
		"chosen_reward_count": chosen_reward_history.size(),
		"chosen_reward_history": _get_chosen_reward_history(),
		"unique_chosen_reward_ids": chosen_reward_ids.duplicate(),
		"chosen_rewards": _get_chosen_reward_snapshots(),
		"effects": get_effects_snapshot(),
	}


func get_rewind_state() -> Dictionary:
	return {
		"chosen_reward_ids": chosen_reward_ids.duplicate(true),
		"chosen_reward_lookup": chosen_reward_lookup.duplicate(true),
		"chosen_reward_history": chosen_reward_history.duplicate(true),
		"active_offer_ids": active_offer_ids.duplicate(true),
		"active_offer_round": active_offer_round,
		"max_hull_bonus": max_hull_bonus,
		"future_shot_bonus": future_shot_bonus,
		"future_object_ball_bonus": future_object_ball_bonus,
		"future_quota_bonus": future_quota_bonus,
		"object_sink_quota_bonus": object_sink_quota_bonus,
		"bank_shot_quota_bonus": bank_shot_quota_bonus,
		"opening_volley_quota_bonus": opening_volley_quota_bonus,
		"opening_volley_used_rounds": opening_volley_used_rounds.duplicate(true),
		"rng_state": int(rng.state),
	}


func restore_rewind_state(state: Dictionary) -> void:
	chosen_reward_ids = _rewind_string_array(state, "chosen_reward_ids")
	chosen_reward_lookup = _rewind_dictionary(state, "chosen_reward_lookup")
	chosen_reward_history = _rewind_dictionary_array(state, "chosen_reward_history")
	active_offer_ids = _rewind_string_array(state, "active_offer_ids")
	active_offer_round = maxi(int(state.get("active_offer_round", 0)), 0)
	max_hull_bonus = maxi(int(state.get("max_hull_bonus", 0)), 0)
	future_shot_bonus = maxi(int(state.get("future_shot_bonus", 0)), 0)
	future_object_ball_bonus = maxi(int(state.get("future_object_ball_bonus", 0)), 0)
	future_quota_bonus = maxi(int(state.get("future_quota_bonus", 0)), 0)
	object_sink_quota_bonus = maxi(int(state.get("object_sink_quota_bonus", 0)), 0)
	bank_shot_quota_bonus = maxi(int(state.get("bank_shot_quota_bonus", 0)), 0)
	opening_volley_quota_bonus = maxi(int(state.get("opening_volley_quota_bonus", 0)), 0)
	opening_volley_used_rounds = _rewind_dictionary(state, "opening_volley_used_rounds")
	rng.state = int(state.get("rng_state", rng.state))
	_emit_changed()


func _rewind_string_array(state: Dictionary, key: String) -> Array[String]:
	var result: Array[String] = []
	var value: Variant = state.get(key, [])
	if value is Array:
		for entry in value:
			result.append(str(entry))
	return result


func _rewind_dictionary_array(state: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = state.get(key, [])
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _rewind_dictionary(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = state.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func get_effects_snapshot() -> Dictionary:
	return {
		"max_hull_bonus": max_hull_bonus,
		"future_shot_bonus": future_shot_bonus,
		"future_object_ball_bonus": future_object_ball_bonus,
		"future_quota_bonus": future_quota_bonus,
		"object_sink_quota_bonus": object_sink_quota_bonus,
		"bank_shot_quota_bonus": bank_shot_quota_bonus,
		"opening_volley_quota_bonus": opening_volley_quota_bonus,
	}


func get_active_offer_snapshots() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for reward_id in active_offer_ids:
		var definition: Dictionary = get_reward_definition(reward_id)
		if definition.is_empty():
			continue
		offers.append(_make_reward_snapshot(definition))
	return offers


func get_reward_definition(reward_id: String) -> Dictionary:
	for definition_value in REWARD_DEFINITIONS:
		var definition: Dictionary = definition_value as Dictionary
		if str(definition.get("id", "")) == reward_id:
			return definition.duplicate(true)
	return {}


func get_effective_round_setup(base_setup: Dictionary) -> Dictionary:
	var setup: Dictionary = base_setup.duplicate(true)
	setup["target"] = maxi(int(setup.get("target", 0)) + future_quota_bonus, 0)
	setup["shots"] = maxi(int(setup.get("shots", 0)) + future_shot_bonus, 0)
	setup["object_balls"] = maxi(int(setup.get("object_balls", 0)) + future_object_ball_bonus, 0)
	return setup


func get_max_hull_bonus() -> int:
	return maxi(max_hull_bonus, 0)


func begin_round(round_number: int) -> void:
	opening_volley_used_rounds.erase(maxi(round_number, 0))


func get_sink_quota_bonus(score_snapshot: Dictionary, scored_amount: int) -> Dictionary:
	if scored_amount <= 0:
		return {"amount": 0, "labels": []}

	var bonus_amount: int = 0
	var labels: Array[String] = []
	if object_sink_quota_bonus > 0:
		bonus_amount += object_sink_quota_bonus
		labels.append("Heavy Purse")
	if bank_shot_quota_bonus > 0 and _snapshot_has_bank_event(score_snapshot):
		bonus_amount += bank_shot_quota_bonus
		labels.append("Banker's Wake")

	return {
		"amount": bonus_amount,
		"labels": labels,
	}


func consume_opening_volley_bonus(round_number: int, scored_amount: int) -> Dictionary:
	if scored_amount <= 0 or opening_volley_quota_bonus <= 0:
		return {"amount": 0, "label": ""}

	var safe_round: int = maxi(round_number, 0)
	if bool(opening_volley_used_rounds.get(safe_round, false)):
		return {"amount": 0, "label": ""}

	opening_volley_used_rounds[safe_round] = true
	return {
		"amount": opening_volley_quota_bonus,
		"label": "Opening Volley",
	}


func _apply_reward_effect(reward_id: String) -> Dictionary:
	match reward_id:
		REWARD_REINFORCED_HULL:
			max_hull_bonus += 1
			return {"restore_hull": 1}
		REWARD_SPARE_SHOT:
			future_shot_bonus += 1
		REWARD_HEAVY_PURSE:
			object_sink_quota_bonus += HEAVY_PURSE_QUOTA_BONUS
		REWARD_BANKERS_WAKE:
			bank_shot_quota_bonus += BANKERS_WAKE_QUOTA_BONUS
		REWARD_CROWDED_HOLD:
			future_object_ball_bonus += 1
			future_quota_bonus += 10
		REWARD_OPENING_VOLLEY:
			opening_volley_quota_bonus += OPENING_VOLLEY_QUOTA_BONUS

	return {}


func _get_eligible_reward_ids() -> Array[String]:
	var eligible_ids: Array[String] = []
	for definition_value in REWARD_DEFINITIONS:
		var definition: Dictionary = definition_value as Dictionary
		var reward_id: String = str(definition.get("id", ""))
		if reward_id.is_empty():
			continue
		if chosen_reward_lookup.has(reward_id) and not bool(definition.get("stackable", false)):
			continue
		eligible_ids.append(reward_id)
	return eligible_ids


func _get_all_reward_ids() -> Array[String]:
	var reward_ids: Array[String] = []
	for definition_value in REWARD_DEFINITIONS:
		var definition: Dictionary = definition_value as Dictionary
		var reward_id: String = str(definition.get("id", ""))
		if reward_id.is_empty():
			continue
		reward_ids.append(reward_id)
	return reward_ids


func _append_random_offer_ids(candidate_ids: Array[String]) -> void:
	while active_offer_ids.size() < OFFER_COUNT and not candidate_ids.is_empty():
		var selected_index: int = rng.randi_range(0, candidate_ids.size() - 1)
		active_offer_ids.append(candidate_ids[selected_index])
		candidate_ids.remove_at(selected_index)


func _make_reward_snapshot(definition: Dictionary) -> Dictionary:
	return {
		"id": str(definition.get("id", "")),
		"display_name": str(definition.get("display_name", "")),
		"description": str(definition.get("description", "")),
		"stackable": bool(definition.get("stackable", false)),
	}


func _get_chosen_reward_snapshots() -> Array[Dictionary]:
	var chosen_rewards: Array[Dictionary] = []
	for reward_id in chosen_reward_ids:
		var definition: Dictionary = get_reward_definition(reward_id)
		if definition.is_empty():
			continue
		chosen_rewards.append(_make_reward_snapshot(definition))
	return chosen_rewards


func _get_chosen_reward_history() -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	for reward_value in chosen_reward_history:
		var reward: Dictionary = reward_value as Dictionary
		if reward.is_empty():
			continue
		history.append(reward.duplicate(true))
	return history


func _get_chosen_reward_history_ids() -> Array[String]:
	var reward_ids: Array[String] = []
	for reward_value in chosen_reward_history:
		var reward: Dictionary = reward_value as Dictionary
		var reward_id: String = str(reward.get("id", ""))
		if reward_id.is_empty():
			continue
		reward_ids.append(reward_id)
	return reward_ids


func _get_chosen_reward_history_names() -> Array[String]:
	var reward_names: Array[String] = []
	for reward_value in chosen_reward_history:
		var reward: Dictionary = reward_value as Dictionary
		var reward_name: String = str(reward.get("display_name", ""))
		if reward_name.is_empty():
			continue
		reward_names.append(reward_name)
	return reward_names


func _snapshot_has_bank_event(score_snapshot: Dictionary) -> bool:
	var events_value: Variant = score_snapshot.get("events", [])
	if not events_value is Array:
		return false
	var events: Array = events_value as Array
	return (
		events.has(ShotEventSystem.EVENT_BANK)
		or events.has(ShotEventSystem.EVENT_DOUBLE_BANK)
		or events.has(ShotEventSystem.EVENT_TRIPLE_BANK)
		or events.has(ShotEventSystem.EVENT_CROSS_CORNER_BANK)
	)


func _emit_changed() -> void:
	rewards_changed.emit(get_reward_snapshot())
