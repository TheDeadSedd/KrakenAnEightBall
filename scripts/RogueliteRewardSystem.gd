extends RefCounted
class_name RogueliteRewardSystem

# index:title Roguelite Reward System
# index:category Run Modes
# index:status First Pass
# index:owner systems_agent
# index:notes Owns Eight Ball reward offers, chosen history, replacement, and skip state.

signal rewards_changed(snapshot: Dictionary)
signal reward_chosen(reward_snapshot: Dictionary, effects_snapshot: Dictionary)
signal reward_replacement_required(reward_snapshot: Dictionary, build_snapshot: Dictionary)
signal reward_skipped(skip_snapshot: Dictionary)

const EIGHT_BALL_CATALOG := preload("res://scripts/RogueliteEightBallCatalog.gd")
const BALANCE_TUNING_SCRIPT := preload("res://scripts/RogueliteBalanceTuning.gd")

const OFFER_COUNT := 3
const REWARD_KIND_EIGHT_BALL := "eight_ball"
const DEFAULT_OFFER_WEIGHT_COMMON := EIGHT_BALL_CATALOG.OFFER_WEIGHT_COMMON
const DEFAULT_OFFER_WEIGHT_UNCOMMON := EIGHT_BALL_CATALOG.OFFER_WEIGHT_UNCOMMON
const DEFAULT_OFFER_WEIGHT_RARE := EIGHT_BALL_CATALOG.OFFER_WEIGHT_RARE
const DEFAULT_OFFER_WEIGHT_LEGENDARY := EIGHT_BALL_CATALOG.OFFER_WEIGHT_LEGENDARY
const DEAD_RECKONING_ITEM_ID := EIGHT_BALL_CATALOG.DEAD_RECKONING_ITEM_ID

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var build_system: RogueliteBuildSystem
var chosen_reward_ids: Array[String] = []
var chosen_reward_history: Array[Dictionary] = []
var active_offer_ids: Array[String] = []
var active_offer_round: int = 0
var pending_replacement_eight_ball_item_id: String = ""
var skipped_rewards: int = 0
var skipped_reward_history: Array[Dictionary] = []
var run_reward_seed: int = 0
var offer_generation: int = 0
var last_eligible_pool_count: int = 0
var last_offer_exclusions: Array[String] = []
var last_offer_rarities: Array[String] = []
var last_offer_rolls: Array[Dictionary] = []
var last_offer_diagnostics: Dictionary = {}
var last_eligible_pool: Array[Dictionary] = []
var active_balance_tuning_snapshot: Dictionary = {}


func setup(seed_override: int = -1) -> void:
	if seed_override >= 0:
		set_run_reward_seed(seed_override)
	else:
		rng.randomize()
		run_reward_seed = int(rng.seed)
	reset_run_state()


func set_build_system(system: RogueliteBuildSystem) -> void:
	build_system = system
	_emit_changed()


func set_balance_tuning_snapshot(snapshot: Dictionary) -> void:
	active_balance_tuning_snapshot = snapshot.duplicate(true)
	_emit_changed()


func set_run_reward_seed(seed_value: int) -> void:
	run_reward_seed = seed_value
	rng.seed = seed_value
	offer_generation = 0
	last_offer_rolls.clear()


func reset_run_state() -> void:
	rng.seed = run_reward_seed
	chosen_reward_ids.clear()
	chosen_reward_history.clear()
	active_offer_ids.clear()
	active_offer_round = 0
	pending_replacement_eight_ball_item_id = ""
	skipped_rewards = 0
	skipped_reward_history.clear()
	offer_generation = 0
	last_eligible_pool_count = 0
	last_offer_exclusions.clear()
	last_offer_rarities.clear()
	last_offer_rolls.clear()
	last_offer_diagnostics.clear()
	last_eligible_pool.clear()
	_emit_changed()


func generate_reward_offers(round_number: int) -> Dictionary:
	active_offer_ids.clear()
	active_offer_round = maxi(round_number, 0)
	pending_replacement_eight_ball_item_id = ""
	offer_generation += 1
	last_offer_rolls.clear()
	last_offer_rarities.clear()
	last_offer_exclusions.clear()
	last_offer_diagnostics.clear()

	_generate_eight_ball_offers()

	_emit_changed()
	return get_reward_snapshot()


func choose_reward(reward_id: String) -> Dictionary:
	if not active_offer_ids.has(reward_id):
		return {}
	return _choose_eight_ball_reward(reward_id)


func confirm_eight_ball_replacement(
	tray_slot_index: int,
	offered_eight_ball_item_id: String = ""
) -> Dictionary:
	if pending_replacement_eight_ball_item_id.is_empty():
		var offered_item_id: String = offered_eight_ball_item_id.strip_edges()
		if active_offer_ids.has(offered_item_id):
			pending_replacement_eight_ball_item_id = offered_item_id
	if pending_replacement_eight_ball_item_id.is_empty() or build_system == null:
		return {}
	var item_id: String = pending_replacement_eight_ball_item_id
	if not active_offer_ids.has(item_id):
		return {}
	var replacement_warning: String = get_eight_ball_replacement_warning(
		tray_slot_index,
		item_id
	)
	var replacement_result: Dictionary = build_system.replace_eight_ball(tray_slot_index, item_id)
	if not bool(replacement_result.get("success", false)):
		return {
			"completed": false,
			"requires_replacement": true,
			"reason": str(replacement_result.get("reason", "replacement_failed")),
			"replacement": replacement_result.duplicate(true),
			"replacement_warning": replacement_warning,
		}
	var completed_result: Dictionary = _complete_eight_ball_choice(item_id, replacement_result)
	completed_result["replacement_warning"] = replacement_warning
	return completed_result


func choose_eight_ball_replacement(
	eight_ball_item_id: String,
	tray_slot_index: int
) -> Dictionary:
	return confirm_eight_ball_replacement(tray_slot_index, eight_ball_item_id)


func cancel_eight_ball_replacement() -> void:
	pending_replacement_eight_ball_item_id = ""
	_emit_changed()


func get_eight_ball_replacement_warning(
	tray_slot_index: int,
	offered_eight_ball_item_id: String = ""
) -> String:
	if build_system == null:
		return ""
	var offered_item_id: String = offered_eight_ball_item_id.strip_edges()
	if offered_item_id.is_empty():
		offered_item_id = pending_replacement_eight_ball_item_id
	if offered_item_id.is_empty() or _get_eight_ball_definition(offered_item_id).is_empty():
		return ""
	return build_system.get_replacement_warning(tray_slot_index, offered_item_id)


func keep_current_course(reason: String = "player_skip") -> Dictionary:
	if active_offer_ids.is_empty() and pending_replacement_eight_ball_item_id.is_empty():
		return {"completed": false, "skipped": false, "reason": "no_active_reward"}
	var skip_snapshot: Dictionary = {
		"round_number": active_offer_round,
		"reason": reason,
		"offer_ids": active_offer_ids.duplicate(),
		"offer_generation": offer_generation,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
	}
	skipped_rewards += 1
	skipped_reward_history.append(skip_snapshot.duplicate(true))
	active_offer_ids.clear()
	pending_replacement_eight_ball_item_id = ""
	reward_skipped.emit(skip_snapshot.duplicate(true))
	_emit_changed()
	return {
		"completed": true,
		"skipped": true,
		"skip": skip_snapshot,
	}


func get_reward_snapshot() -> Dictionary:
	return {
		"offers": get_active_offer_snapshots(),
		"active_offer_ids": active_offer_ids.duplicate(),
		"active_offer_round": active_offer_round,
		"active_offer_kind": REWARD_KIND_EIGHT_BALL,
		"offer_kind": REWARD_KIND_EIGHT_BALL,
		"pending_replacement_eight_ball_item_id": pending_replacement_eight_ball_item_id,
		"requires_replacement": not pending_replacement_eight_ball_item_id.is_empty(),
		"replacement_warnings_by_slot": _get_pending_replacement_warnings(),
		"chosen_reward_ids": _get_chosen_reward_history_ids(),
		"chosen_reward_display_names": _get_chosen_reward_history_names(),
		"chosen_reward_count": chosen_reward_history.size(),
		"chosen_reward_history": _get_chosen_reward_history(),
		"unique_chosen_reward_ids": chosen_reward_ids.duplicate(),
		"chosen_rewards": _get_chosen_reward_snapshots(),
		"skipped_rewards": skipped_rewards,
		"skipped_reward_history": skipped_reward_history.duplicate(true),
		"offer_diagnostics": get_offer_diagnostics(),
		"eligible_pool": last_eligible_pool.duplicate(true),
		"build_snapshot": build_system.get_build_snapshot() if build_system != null else {},
		"active_balance_tuning": active_balance_tuning_snapshot.duplicate(true),
	}


func get_rewind_state() -> Dictionary:
	return {
		"chosen_reward_ids": chosen_reward_ids.duplicate(true),
		"chosen_reward_history": chosen_reward_history.duplicate(true),
		"active_offer_ids": active_offer_ids.duplicate(true),
		"active_offer_round": active_offer_round,
		"pending_replacement_eight_ball_item_id": pending_replacement_eight_ball_item_id,
		"skipped_rewards": skipped_rewards,
		"skipped_reward_history": skipped_reward_history.duplicate(true),
		"run_reward_seed": run_reward_seed,
		"offer_generation": offer_generation,
		"last_eligible_pool_count": last_eligible_pool_count,
		"last_offer_exclusions": last_offer_exclusions.duplicate(true),
		"last_offer_rarities": last_offer_rarities.duplicate(true),
		"last_offer_rolls": last_offer_rolls.duplicate(true),
		"last_offer_diagnostics": last_offer_diagnostics.duplicate(true),
		"last_eligible_pool": last_eligible_pool.duplicate(true),
		"active_balance_tuning": active_balance_tuning_snapshot.duplicate(true),
		"rng_state": int(rng.state),
	}


func restore_rewind_state(state: Dictionary) -> void:
	var obsolete_legacy_offer_state: bool = (
		bool(state.get("legacy_rewards_enabled", false))
		or str(state.get("active_offer_kind", REWARD_KIND_EIGHT_BALL)) != REWARD_KIND_EIGHT_BALL
	)
	chosen_reward_ids = _filter_eight_ball_ids(_rewind_string_array(state, "chosen_reward_ids"))
	chosen_reward_history = _filter_eight_ball_history(
		_rewind_dictionary_array(state, "chosen_reward_history")
	)
	active_offer_ids = _filter_eight_ball_ids(_rewind_string_array(state, "active_offer_ids"))
	active_offer_round = maxi(int(state.get("active_offer_round", 0)), 0)
	pending_replacement_eight_ball_item_id = str(state.get("pending_replacement_eight_ball_item_id", ""))
	if not active_offer_ids.has(pending_replacement_eight_ball_item_id):
		pending_replacement_eight_ball_item_id = ""
	skipped_rewards = maxi(int(state.get("skipped_rewards", 0)), 0)
	skipped_reward_history = _rewind_dictionary_array(state, "skipped_reward_history")
	run_reward_seed = int(state.get("run_reward_seed", run_reward_seed))
	offer_generation = maxi(int(state.get("offer_generation", 0)), 0)
	last_eligible_pool_count = maxi(int(state.get("last_eligible_pool_count", 0)), 0)
	last_offer_exclusions = _filter_eight_ball_ids(
		_rewind_string_array(state, "last_offer_exclusions")
	)
	last_offer_rarities.clear()
	for offer_id in active_offer_ids:
		last_offer_rarities.append(str(_get_eight_ball_definition(offer_id).get("rarity", "common")))
	last_offer_rolls = _rewind_dictionary_array(state, "last_offer_rolls")
	last_offer_diagnostics = _rewind_dictionary(state, "last_offer_diagnostics")
	last_eligible_pool = _rewind_dictionary_array(state, "last_eligible_pool")
	active_balance_tuning_snapshot = _rewind_dictionary(state, "active_balance_tuning")
	if obsolete_legacy_offer_state:
		last_eligible_pool_count = 0
		last_offer_exclusions.clear()
		last_offer_rolls.clear()
		last_offer_diagnostics.clear()
	elif str(last_offer_diagnostics.get("selection_policy", "")).begins_with("legacy"):
		last_offer_diagnostics.clear()
	last_offer_diagnostics.erase("legacy_rewards_enabled")
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


func _filter_eight_ball_ids(candidate_ids: Array[String]) -> Array[String]:
	var filtered_ids: Array[String] = []
	for item_id in candidate_ids:
		if not _get_eight_ball_definition(item_id).is_empty() and not filtered_ids.has(item_id):
			filtered_ids.append(item_id)
	return filtered_ids


func _filter_eight_ball_history(candidate_history: Array[Dictionary]) -> Array[Dictionary]:
	var filtered_history: Array[Dictionary] = []
	for entry in candidate_history:
		var item_id: String = _eight_ball_item_id(entry)
		if _get_eight_ball_definition(item_id).is_empty():
			continue
		filtered_history.append(_make_reward_snapshot(_get_eight_ball_definition(item_id)))
	return filtered_history


func get_active_offer_snapshots() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for reward_id in active_offer_ids:
		var definition: Dictionary = get_reward_definition(reward_id)
		if definition.is_empty():
			continue
		offers.append(_make_reward_snapshot(definition))
	return offers


func get_reward_definition(reward_id: String) -> Dictionary:
	return _get_eight_ball_definition(reward_id)


func get_offer_diagnostics() -> Dictionary:
	return {
		"run_reward_seed": run_reward_seed,
		"rng_state": int(rng.state),
		"offer_generation": offer_generation,
		"active_offer_round": active_offer_round,
		"active_offer_kind": REWARD_KIND_EIGHT_BALL,
		"eligible_pool_count": last_eligible_pool_count,
		"offer_ids": active_offer_ids.duplicate(),
		"offer_rarities": last_offer_rarities.duplicate(),
		"exclusions": last_offer_exclusions.duplicate(),
		"weighted_rolls": last_offer_rolls.duplicate(true),
		"pending_replacement_eight_ball_item_id": pending_replacement_eight_ball_item_id,
		"skipped_rewards": skipped_rewards,
		"details": last_offer_diagnostics.duplicate(true),
		"eligible_pool": last_eligible_pool.duplicate(true),
		"active_balance_tuning": active_balance_tuning_snapshot.duplicate(true),
	}


func _choose_eight_ball_reward(eight_ball_item_id: String) -> Dictionary:
	var definition: Dictionary = _get_eight_ball_definition(eight_ball_item_id)
	if definition.is_empty():
		return {}
	if build_system == null:
		last_offer_diagnostics["last_selection_error"] = "build_system_unavailable"
		_emit_changed()
		return {}

	if build_system.owns_eight_ball(eight_ball_item_id):
		last_offer_diagnostics["last_selection_error"] = "already_owned"
		_emit_changed()
		return {}

	if build_system.is_tray_full():
		pending_replacement_eight_ball_item_id = eight_ball_item_id
		var pending_snapshot: Dictionary = _make_reward_snapshot(definition)
		var replacement_warnings: Dictionary = _get_pending_replacement_warnings(eight_ball_item_id)
		pending_snapshot["replacement_warnings_by_slot"] = replacement_warnings.duplicate(true)
		pending_snapshot["has_replacement_warning"] = not replacement_warnings.is_empty()
		reward_replacement_required.emit(pending_snapshot.duplicate(true), build_system.get_build_snapshot())
		_emit_changed()
		return {
			"completed": false,
			"requires_replacement": true,
			"reward": pending_snapshot,
			"effects": {},
			"build_snapshot": build_system.get_build_snapshot(),
			"replacement_warnings_by_slot": replacement_warnings.duplicate(true),
		}

	var acquisition_result: Dictionary = build_system.acquire_eight_ball(eight_ball_item_id)
	if not bool(acquisition_result.get("success", false)):
		last_offer_diagnostics["last_selection_error"] = str(acquisition_result.get("reason", "acquisition_failed"))
		_emit_changed()
		return {}
	return _complete_eight_ball_choice(eight_ball_item_id, acquisition_result)


func _complete_eight_ball_choice(eight_ball_item_id: String, build_result: Dictionary) -> Dictionary:
	var definition: Dictionary = _get_eight_ball_definition(eight_ball_item_id)
	if definition.is_empty():
		return {}
	var reward_snapshot: Dictionary = _make_reward_snapshot(definition)
	if not chosen_reward_ids.has(eight_ball_item_id):
		chosen_reward_ids.append(eight_ball_item_id)
	chosen_reward_history.append(reward_snapshot.duplicate(true))
	active_offer_ids.clear()
	pending_replacement_eight_ball_item_id = ""
	last_offer_diagnostics["last_selected_eight_ball_item_id"] = eight_ball_item_id
	last_offer_diagnostics["last_selection_error"] = ""
	reward_chosen.emit(reward_snapshot.duplicate(true), {})
	_emit_changed()
	return {
		"completed": true,
		"requires_replacement": false,
		"reward": reward_snapshot,
		"effects": {},
		"build_result": build_result.duplicate(true),
		"build_snapshot": build_system.get_build_snapshot() if build_system != null else {},
	}


func _generate_eight_ball_offers() -> void:
	var owned_ids: Array[String] = []
	if build_system != null:
		owned_ids = build_system.get_owned_eight_ball_ids()
	last_offer_exclusions = owned_ids.duplicate()

	var eligible_definitions: Array[Dictionary] = []
	var contextual_exclusions: Array[String] = []
	for definition in _get_eight_ball_definitions():
		var item_id: String = _eight_ball_item_id(definition)
		if item_id.is_empty() or owned_ids.has(item_id):
			continue
		if not _is_contextually_eligible(definition, owned_ids):
			contextual_exclusions.append(item_id)
			if not last_offer_exclusions.has(item_id):
				last_offer_exclusions.append(item_id)
			continue
		eligible_definitions.append(definition.duplicate(true))
	last_eligible_pool_count = eligible_definitions.size()
	last_eligible_pool = []
	for eligible_definition in eligible_definitions:
		last_eligible_pool.append(_make_reward_snapshot(eligible_definition))

	var candidates: Array[Dictionary] = eligible_definitions.duplicate(true)
	while active_offer_ids.size() < OFFER_COUNT and not candidates.is_empty():
		var constrained_candidates: Array[Dictionary] = _get_offer_constraint_candidates(candidates)
		if constrained_candidates.is_empty():
			break
		var selected: Dictionary = _select_weighted_definition(constrained_candidates)
		if selected.is_empty():
			break
		var selected_id: String = _eight_ball_item_id(selected)
		active_offer_ids.append(selected_id)
		_remove_definition_by_id(candidates, selected_id)

	var all_rare_repaired: bool = _repair_all_rare_offer_if_possible(eligible_definitions)
	last_offer_rarities.clear()
	for offer_id in active_offer_ids:
		last_offer_rarities.append(str(_get_eight_ball_definition(offer_id).get("rarity", "common")))
	last_offer_diagnostics = {
		"selection_policy": "weighted_without_replacement_family_diverse",
		"common_weight": DEFAULT_OFFER_WEIGHT_COMMON,
		"uncommon_weight": DEFAULT_OFFER_WEIGHT_UNCOMMON,
		"rare_weight": DEFAULT_OFFER_WEIGHT_RARE,
		"legendary_weight": DEFAULT_OFFER_WEIGHT_LEGENDARY,
		"owned_ids_excluded": owned_ids.duplicate(),
		"contextual_exclusions": contextual_exclusions.duplicate(),
		"dead_reckoning_eligible": _has_regular_direct_pot_support(owned_ids),
		"all_rare_repaired": all_rare_repaired,
		"phase_diversity_requested": false,
		"family_diversity_requested": true,
		"available_family_count": _count_definition_families(eligible_definitions),
		"selected_family_count": _count_offer_families(active_offer_ids),
		"selected_legendary_count": _count_legendary_offers(active_offer_ids),
		"family_offer_multipliers": _dictionary_value(
			active_balance_tuning_snapshot,
			"family_offer_multipliers"
		).duplicate(true),
		"debug_balance_overrides_active": bool(active_balance_tuning_snapshot.get(
			"has_overrides",
			false
		)),
	}


func _select_weighted_definition(candidates: Array[Dictionary]) -> Dictionary:
	if candidates.is_empty():
		return {}
	var total_weight: int = 0
	for definition in candidates:
		total_weight += _get_offer_weight(definition)
	if total_weight <= 0:
		return candidates[0].duplicate(true)

	var roll: int = rng.randi_range(1, total_weight)
	var remaining_roll: int = roll
	for definition in candidates:
		var weight: int = _get_offer_weight(definition)
		remaining_roll -= weight
		if remaining_roll <= 0:
			last_offer_rolls.append({
				"roll": roll,
				"total_weight": total_weight,
				"selected_id": _eight_ball_item_id(definition),
			})
			return definition.duplicate(true)
	return candidates.back().duplicate(true)


func _get_offer_constraint_candidates(candidates: Array[Dictionary]) -> Array[Dictionary]:
	var allowed_candidates: Array[Dictionary] = []
	var legendary_already_selected: bool = _count_legendary_offers(active_offer_ids) > 0
	for definition in candidates:
		if legendary_already_selected and _is_legendary_definition(definition):
			continue
		allowed_candidates.append(definition.duplicate(true))
	if allowed_candidates.is_empty() or active_offer_ids.is_empty():
		return allowed_candidates

	var selected_families: Dictionary = {}
	for offer_id in active_offer_ids:
		var family_id: String = str(_get_eight_ball_definition(offer_id).get("family_id", ""))
		if not family_id.is_empty():
			selected_families[family_id] = true

	var unseen_family_candidates: Array[Dictionary] = []
	for definition in allowed_candidates:
		var family_id: String = str(definition.get("family_id", ""))
		if not family_id.is_empty() and not selected_families.has(family_id):
			unseen_family_candidates.append(definition.duplicate(true))
	return unseen_family_candidates if not unseen_family_candidates.is_empty() else allowed_candidates


func _repair_all_rare_offer_if_possible(eligible_definitions: Array[Dictionary]) -> bool:
	if active_offer_ids.size() < OFFER_COUNT:
		return false
	for offer_id in active_offer_ids:
		if str(_get_eight_ball_definition(offer_id).get("rarity", "")) != "rare":
			return false

	var non_rare_candidates: Array[Dictionary] = []
	var retained_offer_ids: Array[String] = []
	for offer_index in range(active_offer_ids.size() - 1):
		retained_offer_ids.append(active_offer_ids[offer_index])
	var retained_has_legendary: bool = _count_legendary_offers(retained_offer_ids) > 0
	var best_family_count: int = 0
	for definition in eligible_definitions:
		var item_id: String = _eight_ball_item_id(definition)
		var rarity: String = str(definition.get("rarity", "common"))
		if rarity == "rare" or active_offer_ids.has(item_id):
			continue
		if retained_has_legendary and _is_legendary_definition(definition):
			continue
		var resulting_ids: Array[String] = retained_offer_ids.duplicate()
		resulting_ids.append(item_id)
		var resulting_family_count: int = _count_offer_families(resulting_ids)
		if resulting_family_count > best_family_count:
			best_family_count = resulting_family_count
			non_rare_candidates.clear()
		if resulting_family_count == best_family_count:
			non_rare_candidates.append(definition.duplicate(true))
	if non_rare_candidates.is_empty():
		return false
	var replacement: Dictionary = _select_weighted_definition(non_rare_candidates)
	if replacement.is_empty():
		return false
	active_offer_ids[active_offer_ids.size() - 1] = _eight_ball_item_id(replacement)
	return true


func _is_contextually_eligible(definition: Dictionary, owned_ids: Array[String]) -> bool:
	var item_id: String = _eight_ball_item_id(definition)
	if item_id == DEAD_RECKONING_ITEM_ID:
		return _has_regular_direct_pot_support(owned_ids)
	return true


func _is_legendary_definition(definition: Dictionary) -> bool:
	return str(definition.get("rarity", "")).to_lower() == "legendary"


func _count_legendary_offers(offer_ids: Array[String]) -> int:
	var count: int = 0
	for offer_id in offer_ids:
		if _is_legendary_definition(_get_eight_ball_definition(offer_id)):
			count += 1
	return count


func _count_offer_families(offer_ids: Array[String]) -> int:
	var families: Dictionary = {}
	for offer_id in offer_ids:
		var family_id: String = str(_get_eight_ball_definition(offer_id).get("family_id", ""))
		if not family_id.is_empty():
			families[family_id] = true
	return families.size()


func _count_definition_families(definitions: Array[Dictionary]) -> int:
	var families: Dictionary = {}
	for definition in definitions:
		var family_id: String = str(definition.get("family_id", ""))
		if not family_id.is_empty():
			families[family_id] = true
	return families.size()


func _has_regular_direct_pot_support(item_ids: Array[String]) -> bool:
	for support_id_value in EIGHT_BALL_CATALOG.DIRECT_POT_SUPPORT_ITEM_IDS:
		if item_ids.has(str(support_id_value)):
			return true
	return false


func _get_build_slot_item_ids() -> Array[String]:
	var slot_item_ids: Array[String] = []
	if build_system == null:
		return slot_item_ids
	var raw_ids: Variant = build_system.get_build_snapshot().get("item_ids_by_slot", [])
	if raw_ids is Array:
		for item_id_value in raw_ids:
			slot_item_ids.append(str(item_id_value))
	return slot_item_ids


func _get_pending_replacement_warnings(offered_eight_ball_item_id: String = "") -> Dictionary:
	var offered_item_id: String = offered_eight_ball_item_id.strip_edges()
	if offered_item_id.is_empty():
		offered_item_id = pending_replacement_eight_ball_item_id
	if offered_item_id.is_empty():
		return {}
	var warnings_by_slot: Dictionary = {}
	var slot_item_ids: Array[String] = _get_build_slot_item_ids()
	for tray_slot_index in range(slot_item_ids.size()):
		var warning: String = get_eight_ball_replacement_warning(
			tray_slot_index,
			offered_item_id
		)
		if not warning.is_empty():
			warnings_by_slot[tray_slot_index] = warning
	return warnings_by_slot


func _get_eight_ball_definitions() -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	for definition in EIGHT_BALL_CATALOG.get_all_definitions():
		definitions.append(BALANCE_TUNING_SCRIPT.apply_definition_overrides(
			definition,
			active_balance_tuning_snapshot
		))
	return definitions


func _get_eight_ball_definition(eight_ball_item_id: String) -> Dictionary:
	if eight_ball_item_id.is_empty():
		return {}
	return BALANCE_TUNING_SCRIPT.apply_definition_overrides(
		EIGHT_BALL_CATALOG.get_definition(eight_ball_item_id),
		active_balance_tuning_snapshot
	)


func _eight_ball_item_id(definition: Dictionary) -> String:
	return str(definition.get("eight_ball_item_id", definition.get("id", "")))


func _get_offer_weight(definition: Dictionary) -> int:
	var has_explicit_weight: bool = definition.has("offer_weight")
	var base_weight: int = maxi(int(definition.get("offer_weight", 0)), 0)
	if not has_explicit_weight:
		match str(definition.get("rarity", "common")):
			"legendary":
				base_weight = DEFAULT_OFFER_WEIGHT_LEGENDARY
			"rare":
				base_weight = DEFAULT_OFFER_WEIGHT_RARE
			"uncommon":
				base_weight = DEFAULT_OFFER_WEIGHT_UNCOMMON
			_:
				base_weight = DEFAULT_OFFER_WEIGHT_COMMON
	var family_multiplier: float = BALANCE_TUNING_SCRIPT.get_family_multiplier_from_snapshot(
		active_balance_tuning_snapshot,
		str(definition.get("family_id", ""))
	)
	return maxi(int(roundf(float(base_weight) * family_multiplier)), 0)


func _remove_definition_by_id(definitions: Array[Dictionary], item_id: String) -> void:
	for index in range(definitions.size() - 1, -1, -1):
		if _eight_ball_item_id(definitions[index]) == item_id:
			definitions.remove_at(index)


func _make_reward_snapshot(definition: Dictionary) -> Dictionary:
	var eight_ball_item_id: String = _eight_ball_item_id(definition)
	return {
		"id": eight_ball_item_id,
		"eight_ball_item_id": eight_ball_item_id,
		"reward_kind": REWARD_KIND_EIGHT_BALL,
		"offer_kind": REWARD_KIND_EIGHT_BALL,
		"display_name": str(definition.get("display_name", "")),
		"description": str(definition.get("tooltip", "")),
		"tooltip": str(definition.get("tooltip", "")),
		"short_effect": str(definition.get("short_effect", "")),
		"family_id": str(definition.get("family_id", "")),
		"trigger_id": str(definition.get("trigger_id", "")),
		"modifier_phase": str(definition.get("modifier_phase", "")),
		"value": definition.get("value", 0),
		"effect_kind": str(definition.get("effect_kind", "modifier")),
		"retrigger_family": str(definition.get("retrigger_family", "")),
		"retrigger_count": maxi(int(definition.get("retrigger_count", 0)), 0),
		"rarity": str(definition.get("rarity", "common")),
		"is_legendary": _is_legendary_definition(definition),
		"offer_weight": _get_offer_weight(definition),
		"authored_offer_weight": int(definition.get(
			"authored_offer_weight",
			definition.get("offer_weight", 0)
		)),
		"authored_value": definition.get("authored_value", definition.get("value", 0)),
		"balance_override_active": bool(definition.get("balance_override_active", false)),
		"balance_override_notes": definition.get("balance_override_notes", []),
		"icon_key": str(definition.get("icon_key", "eight_ball_placeholder")),
		"stackable": false,
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


func _emit_changed() -> void:
	rewards_changed.emit(get_reward_snapshot())


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return (value as Dictionary) if value is Dictionary else {}
