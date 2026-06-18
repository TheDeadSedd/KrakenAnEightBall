extends Node
class_name RunStatsSystem

signal run_stats_changed(snapshot: Dictionary)

# Current-run ledger only. No persistence or run-history ownership lives here.
const RUN_TIME_EMIT_INTERVAL := 0.25

var table: BilliardsTable
var doubloons_earned := 0
var doubloons_lost := 0
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
		"doubloons_lost": doubloons_lost,
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
		"passage_completed": bool(passage_snapshot.get("run_completed", false)),
		"voyage_marks_awarded": int(passage_snapshot.get("voyage_marks_awarded", 0)),
		"active_oaths_summary": str(oath_snapshot.get("active_oaths_summary", "None sworn.")),
		"active_oath_count": int(oath_snapshot.get("active_oath_count", 0)),
		"intervention_purchase_history": _get_intervention_purchase_history_snapshot(),
	}


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


func _on_doubloons_lost(amount: int, _new_total: int, _reason: String) -> void:
	if amount <= 0:
		return

	doubloons_lost += amount
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


func _on_intervention_executed(_event_id: String, _debug_trigger: bool) -> void:
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


func _on_intervention_purchased(event_id: String, cost: int) -> void:
	if event_id.is_empty():
		return

	var summary: Dictionary = intervention_purchase_summaries.get(event_id, {})
	if summary.is_empty():
		summary = {
			"event_id": event_id,
			"name": _get_intervention_name(event_id),
			"count": 0,
			"total_cost": 0,
			"last_run_time_seconds": 0.0,
		}
		intervention_purchase_order.append(event_id)

	summary["count"] = maxi(int(summary.get("count", 0)), 0) + 1
	summary["total_cost"] = maxi(int(summary.get("total_cost", 0)), 0) + maxi(cost, 0)
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
