extends Node
class_name RunStatsSystem

signal run_stats_changed(snapshot: Dictionary)

# Current-run ledger only. No persistence or run-history ownership lives here.
const RUN_TIME_EMIT_INTERVAL := 0.25
const RUN_STATS_ROWS := [
	{"label": "Doubloons Earned", "key": "doubloons_earned"},
	{"label": "Doubloons Spent", "key": "doubloons_spent"},
	{"label": "Doubloons Lost", "key": "doubloons_lost"},
	{"label": "Passage Remaining", "key": "remaining_passage"},
	{"label": "Kraken Wants", "key": "current_kraken_request"},
	{"label": "Request Reward Bonus", "key": "request_reward_multiplier_bonus_summary"},
	{"label": "Active Oaths", "key": "active_oaths_summary"},
	{"label": "Oath Penalty Cut", "key": "oath_passage_penalty_reduction_summary"},
	{"label": "Cue", "key": "cue_body"},
	{"label": "Tip", "key": "cue_tip"},
	{"label": "Grip", "key": "cue_grip"},
	{"label": "Ferrule", "key": "cue_ferrule"},
	{"label": "Chalk", "key": "cue_chalk"},
	{"label": "Cue Mods", "key": "active_cue_modifiers_summary"},
	{"label": "Cue Power Bonus", "key": "cue_power_bonus_summary"},
	{"label": "Loose Contraband", "key": "loose_cargo_contraband_chance_summary"},
	{"label": "QM Shot Cooldown", "key": "quartermaster_refresh_decay_summary"},
	{"label": "Shots Taken", "key": "shots_taken"},
	{"label": "Balls Sunk", "key": "balls_sunk"},
	{"label": "Highest Pocket Streak", "key": "highest_pocket_streak"},
	{"label": "Interventions Triggered", "key": "interventions_triggered"},
	{"label": "Shop Refreshes", "key": "quartermaster_refreshes_used"},
	{"label": "Refresh Doubloons", "key": "quartermaster_refresh_doubloons_spent"},
	{"label": "Back Room Deals", "key": "back_room_deals_made"},
	{"label": "Back Room Doubloons", "key": "back_room_deal_doubloons_spent"},
	{"label": "Request Rerolls", "key": "kraken_request_rerolls_used"},
	{"label": "Reroll Passage Added", "key": "passage_added_by_request_rerolls"},
	{"label": "Contraband Found", "key": "contraband_found"},
	{"label": "Treasure Claimed", "key": "treasure_claimed"},
	{"label": "Current Ball Count", "key": "current_ball_count"},
	{"label": "Run Time", "key": "run_time_seconds"},
]
const PASSAGE_COMPLETION_ROWS := [
	{"label": "Shots Taken", "key": "shots_taken"},
	{"label": "Doubloons Earned", "key": "doubloons_earned"},
	{"label": "Doubloons Spent", "key": "doubloons_spent"},
	{"label": "Doubloons Lost", "key": "doubloons_lost"},
	{"label": "Balls Sunk", "key": "balls_sunk"},
	{"label": "Highest Pocket Streak", "key": "highest_pocket_streak"},
	{"label": "Interventions Triggered", "key": "interventions_triggered"},
	{"label": "Contraband Found", "key": "contraband_found"},
	{"label": "Treasure Claimed", "key": "treasure_claimed"},
	{"label": "Kraken Favor Earned", "key": "kraken_favor_earned"},
	{"label": "Total Kraken Favor", "key": "total_kraken_favor"},
	{"label": "Final Ball Count", "key": "current_ball_count"},
	{"label": "Run Duration", "key": "run_time_seconds"},
]

var table: BilliardsTable
var doubloons_earned := 0
var doubloons_spent := 0
var doubloons_lost_to_penalties := 0
var shots_taken := 0
var balls_sunk := 0
var highest_pocket_streak := 1
var interventions_triggered := 0
var quartermaster_refreshes_used := 0
var quartermaster_refresh_doubloons_spent := 0
var back_room_deals_made := 0
var back_room_deal_doubloons_spent := 0
var kraken_request_rerolls_used := 0
var passage_added_by_request_rerolls := 0
var kraken_requests_completed := 0
var legendary_events_awarded := 0
var contraband_found := 0
var treasure_claimed := 0
var current_ball_count := 0
var run_time_seconds := 0.0
var emit_timer := 0.0
var intervention_purchase_order: Array = []
var intervention_purchase_summaries: Dictionary = {}
var passage_snapshot: Dictionary = {}
var oath_snapshot: Dictionary = {}
var cue_loadout_snapshot: Dictionary = {}
var cue_modifier_snapshot: Dictionary = {}


func _ready() -> void:
	set_process(false)


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	_sync_ball_counts_from_table()
	_connect_event_sources()
	set_process(true)
	_emit_stats_changed()


func get_run_stats_snapshot() -> Dictionary:
	return {
		"doubloons_earned": doubloons_earned,
		"doubloons_spent": doubloons_spent,
		"doubloons_lost": doubloons_lost_to_penalties,
		"doubloons_lost_to_penalties": doubloons_lost_to_penalties,
		"shots_taken": shots_taken,
		"balls_sunk": balls_sunk,
		"highest_pocket_streak": highest_pocket_streak,
		"interventions_triggered": interventions_triggered,
		"quartermaster_refreshes_used": quartermaster_refreshes_used,
		"quartermaster_refresh_doubloons_spent": quartermaster_refresh_doubloons_spent,
		"back_room_deals_made": back_room_deals_made,
		"back_room_deal_doubloons_spent": back_room_deal_doubloons_spent,
		"kraken_request_rerolls_used": kraken_request_rerolls_used,
		"passage_added_by_request_rerolls": passage_added_by_request_rerolls,
		"kraken_requests_completed": kraken_requests_completed,
		"legendary_events_awarded": legendary_events_awarded,
		"contraband_found": contraband_found,
		"treasure_claimed": treasure_claimed,
		"current_ball_count": current_ball_count,
		"run_time_seconds": run_time_seconds,
		"passage_required": int(passage_snapshot.get("passage_required", 0)),
		"remaining_passage": int(passage_snapshot.get("remaining_passage", 0)),
		"current_kraken_request": str(passage_snapshot.get("current_request_label", "")),
		"request_reward_multiplier_bonus_summary": str(passage_snapshot.get("request_reward_multiplier_bonus_summary", "+0%")),
		"passage_completed": bool(passage_snapshot.get("run_completed", false)),
		"voyage_marks_awarded": int(passage_snapshot.get("voyage_marks_awarded", 0)),
		"active_oaths_summary": str(oath_snapshot.get("active_oaths_summary", "None sworn.")),
		"active_oath_count": int(oath_snapshot.get("active_oath_count", 0)),
		"oath_passage_penalty_reduction_summary": _get_oath_passage_penalty_reduction_summary(),
		"cue_loadout": cue_loadout_snapshot.duplicate(true),
		"cue_body": _get_cue_loadout_part_name("body", "Weathered Cue"),
		"cue_tip": _get_cue_loadout_part_name("tip", "Plain Tip"),
		"cue_grip": _get_cue_loadout_part_name("grip", "Sailcloth Grip"),
		"cue_ferrule": _get_cue_loadout_part_name("ferrule", "Plain Ferrule"),
		"cue_chalk": _get_cue_loadout_part_name("chalk", "Plain Chalk"),
		"active_cue_modifiers_summary": _get_active_cue_modifier_summary(),
		"cue_power_bonus_summary": _get_cue_power_bonus_summary(),
		"loose_cargo_contraband_chance_summary": _get_loose_cargo_contraband_chance_summary(),
		"quartermaster_refresh_decay_summary": _get_quartermaster_refresh_decay_summary(),
		"intervention_purchase_history": _get_intervention_purchase_history_snapshot(),
	}


func get_rewind_state() -> Dictionary:
	return {
		"doubloons_earned": doubloons_earned,
		"doubloons_spent": doubloons_spent,
		"doubloons_lost_to_penalties": doubloons_lost_to_penalties,
		"shots_taken": shots_taken,
		"balls_sunk": balls_sunk,
		"highest_pocket_streak": highest_pocket_streak,
		"interventions_triggered": interventions_triggered,
		"quartermaster_refreshes_used": quartermaster_refreshes_used,
		"quartermaster_refresh_doubloons_spent": quartermaster_refresh_doubloons_spent,
		"back_room_deals_made": back_room_deals_made,
		"back_room_deal_doubloons_spent": back_room_deal_doubloons_spent,
		"kraken_request_rerolls_used": kraken_request_rerolls_used,
		"passage_added_by_request_rerolls": passage_added_by_request_rerolls,
		"kraken_requests_completed": kraken_requests_completed,
		"legendary_events_awarded": legendary_events_awarded,
		"contraband_found": contraband_found,
		"treasure_claimed": treasure_claimed,
		"current_ball_count": current_ball_count,
		"run_time_seconds": run_time_seconds,
		"emit_timer": emit_timer,
		"intervention_purchase_order": intervention_purchase_order.duplicate(true),
		"intervention_purchase_summaries": intervention_purchase_summaries.duplicate(true),
		"passage_snapshot": passage_snapshot.duplicate(true),
		"oath_snapshot": oath_snapshot.duplicate(true),
	}


func restore_rewind_state(state: Dictionary) -> void:
	doubloons_earned = maxi(int(state.get("doubloons_earned", 0)), 0)
	doubloons_spent = maxi(int(state.get("doubloons_spent", 0)), 0)
	doubloons_lost_to_penalties = maxi(int(state.get("doubloons_lost_to_penalties", 0)), 0)
	shots_taken = maxi(int(state.get("shots_taken", 0)), 0)
	balls_sunk = maxi(int(state.get("balls_sunk", 0)), 0)
	highest_pocket_streak = maxi(int(state.get("highest_pocket_streak", 1)), 1)
	interventions_triggered = maxi(int(state.get("interventions_triggered", 0)), 0)
	quartermaster_refreshes_used = maxi(int(state.get("quartermaster_refreshes_used", 0)), 0)
	quartermaster_refresh_doubloons_spent = maxi(int(state.get("quartermaster_refresh_doubloons_spent", 0)), 0)
	back_room_deals_made = maxi(int(state.get("back_room_deals_made", 0)), 0)
	back_room_deal_doubloons_spent = maxi(int(state.get("back_room_deal_doubloons_spent", 0)), 0)
	kraken_request_rerolls_used = maxi(int(state.get("kraken_request_rerolls_used", 0)), 0)
	passage_added_by_request_rerolls = maxi(int(state.get("passage_added_by_request_rerolls", 0)), 0)
	kraken_requests_completed = maxi(int(state.get("kraken_requests_completed", 0)), 0)
	legendary_events_awarded = maxi(int(state.get("legendary_events_awarded", 0)), 0)
	contraband_found = maxi(int(state.get("contraband_found", 0)), 0)
	treasure_claimed = maxi(int(state.get("treasure_claimed", 0)), 0)
	current_ball_count = maxi(int(state.get("current_ball_count", 0)), 0)
	run_time_seconds = maxf(float(state.get("run_time_seconds", 0.0)), 0.0)
	emit_timer = maxf(float(state.get("emit_timer", 0.0)), 0.0)
	intervention_purchase_order = _rewind_array(state, "intervention_purchase_order")
	intervention_purchase_summaries = _rewind_dictionary(state, "intervention_purchase_summaries")
	passage_snapshot = _rewind_dictionary(state, "passage_snapshot")
	oath_snapshot = _rewind_dictionary(state, "oath_snapshot")
	_emit_stats_changed()


func _rewind_array(state: Dictionary, key: String) -> Array:
	var value: Variant = state.get(key, [])
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _rewind_dictionary(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = state.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func get_run_stats_rows() -> Array:
	return RUN_STATS_ROWS.duplicate(true)


static func get_passage_completion_rows() -> Array:
	return PASSAGE_COMPLETION_ROWS.duplicate(true)


func set_cue_loadout_snapshot(snapshot: Dictionary) -> void:
	cue_loadout_snapshot = snapshot.duplicate(true)
	_emit_stats_changed()


func set_cue_modifier_snapshot(snapshot: Dictionary) -> void:
	cue_modifier_snapshot = snapshot.duplicate(true)
	_emit_stats_changed()


func _process(delta: float) -> void:
	run_time_seconds += maxf(delta, 0.0)
	emit_timer -= delta
	if emit_timer > 0.0:
		return

	emit_timer = RUN_TIME_EMIT_INTERVAL
	_emit_stats_changed()


func _connect_event_sources() -> void:
	if table == null:
		return
	if not table.run_ball_counts_changed.is_connected(_on_run_ball_counts_changed):
		table.run_ball_counts_changed.connect(_on_run_ball_counts_changed)
	if not table.shot_taken.is_connected(_on_shot_taken):
		table.shot_taken.connect(_on_shot_taken)
	if table.score_system != null and not table.score_system.doubloons_awarded.is_connected(_on_doubloons_awarded):
		table.score_system.doubloons_awarded.connect(_on_doubloons_awarded)
	if table.score_system != null and not table.score_system.doubloons_lost.is_connected(_on_doubloons_lost):
		table.score_system.doubloons_lost.connect(_on_doubloons_lost)
	if table.score_system != null and not table.score_system.scoring_event_awarded.is_connected(_on_scoring_event_awarded):
		table.score_system.scoring_event_awarded.connect(_on_scoring_event_awarded)
	if table.pocket_streak_system != null and not table.pocket_streak_system.streak_multiplier_reached.is_connected(_on_streak_multiplier_reached):
		table.pocket_streak_system.streak_multiplier_reached.connect(_on_streak_multiplier_reached)
	if table.table_event_system != null:
		if not table.table_event_system.event_purchased.is_connected(_on_intervention_purchased):
			table.table_event_system.event_purchased.connect(_on_intervention_purchased)
		if not table.table_event_system.intervention_executed.is_connected(_on_intervention_executed):
			table.table_event_system.intervention_executed.connect(_on_intervention_executed)
		if not table.table_event_system.contraband_found.is_connected(_on_contraband_found):
			table.table_event_system.contraband_found.connect(_on_contraband_found)
	if table.quartermaster_system != null:
		if not table.quartermaster_system.stock_refresh_purchased.is_connected(_on_quartermaster_stock_refresh_purchased):
			table.quartermaster_system.stock_refresh_purchased.connect(_on_quartermaster_stock_refresh_purchased)
	if table.back_room_deal_system != null:
		if not table.back_room_deal_system.deal_completed.is_connected(_on_back_room_deal_completed):
			table.back_room_deal_system.deal_completed.connect(_on_back_room_deal_completed)
	if table.treasure_ball_system != null and not table.treasure_ball_system.treasure_claimed.is_connected(_on_treasure_claimed):
		table.treasure_ball_system.treasure_claimed.connect(_on_treasure_claimed)
	if table.passage_system != null and not table.passage_system.passage_changed.is_connected(_on_passage_changed):
		table.passage_system.passage_changed.connect(_on_passage_changed)
	if table.passage_system != null:
		if not table.passage_system.request_completed.is_connected(_on_kraken_request_completed):
			table.passage_system.request_completed.connect(_on_kraken_request_completed)
		if not table.passage_system.request_rerolled.is_connected(_on_kraken_request_rerolled):
			table.passage_system.request_rerolled.connect(_on_kraken_request_rerolled)
		passage_snapshot = table.passage_system.get_passage_snapshot()
	if table.oath_system != null:
		if not table.oath_system.oaths_changed.is_connected(_on_oaths_changed):
			table.oath_system.oaths_changed.connect(_on_oaths_changed)
		oath_snapshot = table.oath_system.get_oath_snapshot()


func _sync_ball_counts_from_table() -> void:
	if table == null:
		return

	var snapshot: Dictionary = table.get_run_ball_counts_snapshot()
	current_ball_count = int(snapshot.get("active_ball_count", 0))
	balls_sunk = int(snapshot.get("balls_sunk_count", 0))


func _on_doubloons_awarded(amount: int, _new_total: int) -> void:
	if amount <= 0:
		return

	doubloons_earned += amount
	_emit_stats_changed()


func _on_doubloons_lost(amount: int, _new_total: int, reason: String) -> void:
	if amount <= 0:
		return

	match reason:
		"spend":
			doubloons_spent += amount
		"penalty":
			doubloons_lost_to_penalties += amount
		_:
			doubloons_lost_to_penalties += amount
	_emit_stats_changed()


func _on_run_ball_counts_changed(active_ball_count: int, balls_sunk_count: int) -> void:
	current_ball_count = maxi(active_ball_count, 0)
	balls_sunk = maxi(balls_sunk_count, 0)
	_emit_stats_changed()


func _on_shot_taken(count: int) -> void:
	shots_taken = maxi(count, 0)
	_emit_stats_changed()


func _on_streak_multiplier_reached(multiplier: int) -> void:
	highest_pocket_streak = maxi(highest_pocket_streak, maxi(multiplier, 1))
	_emit_stats_changed()


func _on_intervention_executed(_event_id: String, debug_trigger: bool) -> void:
	if debug_trigger:
		return

	interventions_triggered += 1
	_emit_stats_changed()


func _on_quartermaster_stock_refresh_purchased(cost: int, _refresh_count: int) -> void:
	quartermaster_refreshes_used += 1
	quartermaster_refresh_doubloons_spent += maxi(cost, 0)
	_emit_stats_changed()


func _on_back_room_deal_completed(_item_id: String, cost: int, _deal_count: int) -> void:
	back_room_deals_made += 1
	back_room_deal_doubloons_spent += maxi(cost, 0)
	_emit_stats_changed()


func _on_kraken_request_completed(_request_snapshot: Dictionary, _reward: int) -> void:
	kraken_requests_completed += 1
	_emit_stats_changed()


func _on_scoring_event_awarded(event_type: String, _amount: int) -> void:
	if ScoreSystem.LEGENDARY_EVENT_TYPES.has(event_type):
		legendary_events_awarded += 1
		_emit_stats_changed()


func _on_kraken_request_rerolled(_previous_request_snapshot: Dictionary, _new_request_snapshot: Dictionary, cost: int) -> void:
	kraken_request_rerolls_used += 1
	passage_added_by_request_rerolls += maxi(cost, 0)
	_emit_stats_changed()


func _on_intervention_purchased(event_id: String, charge_cost: int) -> void:
	if event_id.is_empty():
		return

	var summary: Dictionary = intervention_purchase_summaries.get(event_id, {})
	if summary.is_empty():
		summary = {
			"event_id": event_id,
			"name": _get_intervention_name(event_id),
			"count": 0,
			"total_cost": 0,
			"total_charge_cost": 0,
			"last_run_time_seconds": 0.0,
		}
		intervention_purchase_order.append(event_id)

	summary["count"] = maxi(int(summary.get("count", 0)), 0) + 1
	var safe_charge_cost := maxi(charge_cost, 0)
	summary["total_cost"] = maxi(int(summary.get("total_cost", 0)), 0) + safe_charge_cost
	summary["total_charge_cost"] = maxi(int(summary.get("total_charge_cost", 0)), 0) + safe_charge_cost
	summary["last_run_time_seconds"] = run_time_seconds
	intervention_purchase_summaries[event_id] = summary
	_emit_stats_changed()


func _on_contraband_found(_kind: String) -> void:
	contraband_found += 1
	_emit_stats_changed()


func _on_treasure_claimed(_amount: int) -> void:
	treasure_claimed += 1
	_emit_stats_changed()


func _on_passage_changed(snapshot: Dictionary) -> void:
	passage_snapshot = snapshot.duplicate(true)
	_emit_stats_changed()


func _on_oaths_changed(snapshot: Dictionary) -> void:
	oath_snapshot = snapshot.duplicate(true)
	_emit_stats_changed()


func _emit_stats_changed() -> void:
	run_stats_changed.emit(get_run_stats_snapshot())


func _get_intervention_purchase_history_snapshot() -> Array:
	var history: Array = []
	for event_id_value in intervention_purchase_order:
		var event_id := str(event_id_value)
		if not intervention_purchase_summaries.has(event_id):
			continue
		var summary: Dictionary = intervention_purchase_summaries[event_id] as Dictionary
		history.append(summary.duplicate(true))
	return history


func _get_intervention_name(event_id: String) -> String:
	if table != null and table.table_event_system != null and table.table_event_system.has_method("get_event_display_name"):
		return str(table.table_event_system.get_event_display_name(event_id))
	return event_id.capitalize()


func _get_cue_loadout_part_name(slot_type: String, fallback: String) -> String:
	var by_slot_value: Variant = cue_loadout_snapshot.get("equipped_loadout_by_slot", {})
	if by_slot_value is Dictionary:
		var by_slot: Dictionary = by_slot_value as Dictionary
		var entry_value: Variant = by_slot.get(slot_type, {})
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value as Dictionary
			var slot_display_name := str(entry.get("display_name", ""))
			if not slot_display_name.is_empty():
				return slot_display_name

	var loadout_value: Variant = cue_loadout_snapshot.get("equipped_loadout", [])
	if loadout_value is Array:
		for entry_value in loadout_value:
			if not entry_value is Dictionary:
				continue
			var loadout_entry: Dictionary = entry_value as Dictionary
			if str(loadout_entry.get("slot_type", "")) != slot_type:
				continue
			var loadout_display_name := str(loadout_entry.get("display_name", ""))
			if not loadout_display_name.is_empty():
				return loadout_display_name
	return fallback


func _get_active_cue_modifier_summary() -> String:
	var summary := str(cue_modifier_snapshot.get("active_effect_summary", "None"))
	return "None" if summary.is_empty() else summary


func _get_cue_power_bonus_summary() -> String:
	if table == null or not table.has_method("get_cue_shot_power_modifier_snapshot"):
		return "Unknown"
	var modifier_snapshot: Dictionary = table.get_cue_shot_power_modifier_snapshot()
	return str(modifier_snapshot.get("summary", "+0%"))


func _get_loose_cargo_contraband_chance_summary() -> String:
	if table == null or table.table_event_system == null:
		return "Unknown"
	var chance_snapshot: Dictionary = table.table_event_system.get_loose_cargo_contraband_chance_snapshot()
	var base_chance := float(chance_snapshot.get("base_chance", 0.0))
	var cue_bonus := float(chance_snapshot.get("cue_bonus", 0.0))
	var final_chance := float(chance_snapshot.get("final_chance", base_chance))
	if cue_bonus <= 0.0:
		return _format_percent(base_chance)
	return "%s + %s = %s" % [
		_format_percent(base_chance),
		_format_percent(cue_bonus),
		_format_percent(final_chance),
	]


func _get_quartermaster_refresh_decay_summary() -> String:
	if table == null or table.quartermaster_system == null:
		return "Unknown"
	var decay_snapshot: Dictionary = table.quartermaster_system.get_refresh_decay_snapshot()
	var base_decay := maxi(int(decay_snapshot.get("base_decay", 0)), 0)
	var cue_bonus := maxi(int(decay_snapshot.get("cue_bonus", 0)), 0)
	var final_decay := maxi(int(decay_snapshot.get("final_decay", base_decay)), 0)
	if cue_bonus <= 0:
		return str(base_decay)
	return "%s + %s = %s" % [base_decay, cue_bonus, final_decay]


func _get_oath_passage_penalty_reduction_summary() -> String:
	if table == null or table.oath_system == null:
		return "Unknown"
	var modifier_snapshot: Dictionary = table.oath_system.get_oath_passage_penalty_modifier_snapshot()
	return str(modifier_snapshot.get("summary", "0"))


func _format_percent(value: float) -> String:
	return "%.1f%%" % (clampf(value, 0.0, 1.0) * 100.0)
