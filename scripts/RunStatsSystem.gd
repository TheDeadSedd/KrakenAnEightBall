extends Node
class_name RunStatsSystem

signal run_stats_changed(snapshot: Dictionary)

# Current-run ledger only. No persistence or run-history ownership lives here.
const RUN_TIME_EMIT_INTERVAL := 0.25

var table: BilliardsTable
var doubloons_earned := 0
var balls_sunk := 0
var highest_pocket_streak := 1
var interventions_triggered := 0
var contraband_found := 0
var treasure_claimed := 0
var current_ball_count := 0
var run_time_seconds := 0.0
var emit_timer := 0.0


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
		"balls_sunk": balls_sunk,
		"highest_pocket_streak": highest_pocket_streak,
		"interventions_triggered": interventions_triggered,
		"contraband_found": contraband_found,
		"treasure_claimed": treasure_claimed,
		"current_ball_count": current_ball_count,
		"run_time_seconds": run_time_seconds,
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
	if table.score_system != null and not table.score_system.doubloons_awarded.is_connected(_on_doubloons_awarded):
		table.score_system.doubloons_awarded.connect(_on_doubloons_awarded)
	if table.pocket_streak_system != null and not table.pocket_streak_system.streak_multiplier_reached.is_connected(_on_streak_multiplier_reached):
		table.pocket_streak_system.streak_multiplier_reached.connect(_on_streak_multiplier_reached)
	if table.table_event_system != null:
		if not table.table_event_system.intervention_executed.is_connected(_on_intervention_executed):
			table.table_event_system.intervention_executed.connect(_on_intervention_executed)
		if not table.table_event_system.contraband_found.is_connected(_on_contraband_found):
			table.table_event_system.contraband_found.connect(_on_contraband_found)
	if table.treasure_ball_system != null and not table.treasure_ball_system.treasure_claimed.is_connected(_on_treasure_claimed):
		table.treasure_ball_system.treasure_claimed.connect(_on_treasure_claimed)


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


func _on_run_ball_counts_changed(active_ball_count: int, balls_sunk_count: int) -> void:
	current_ball_count = maxi(active_ball_count, 0)
	balls_sunk = maxi(balls_sunk_count, 0)
	_emit_stats_changed()


func _on_streak_multiplier_reached(multiplier: int) -> void:
	highest_pocket_streak = maxi(highest_pocket_streak, maxi(multiplier, 1))
	_emit_stats_changed()


func _on_intervention_executed(_event_id: String, _debug_trigger: bool) -> void:
	interventions_triggered += 1
	_emit_stats_changed()


func _on_contraband_found(_kind: String) -> void:
	contraband_found += 1
	_emit_stats_changed()


func _on_treasure_claimed(_amount: int) -> void:
	treasure_claimed += 1
	_emit_stats_changed()


func _emit_stats_changed() -> void:
	run_stats_changed.emit(get_run_stats_snapshot())
