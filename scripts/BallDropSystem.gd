@tool
extends Node
class_name BallDropSystem

signal progress_changed(progress: int, threshold: int, percent: float)
signal progress_advanced(amount: int, drops_earned: int)
signal drop_earned(drops_earned: int)

# index:title Ball Drop System
# index:category Mechanics / Systems / UI / Performance Concerns / In Progress
# index:status In Progress
# index:owner systems_agent
# index:notes Tracks Doubloon progress toward earned reward ball drops and special-ball sink penalties.

# Retired automatic score-drop tracking remains here for rollback/debug safety.
# Table Events are now the player-facing score-to-chaos loop, so this system no
# longer emits score-drop reward callouts.
const SPECIAL_BALL_PENALTY_MESSAGES := [
	"The Kraken collects.",
	"Payment due.",
	"The depths take their cut.",
	"That one costs you.",
]

@export var enabled := true
@export_range(1, 999, 1) var doubloons_per_drop := 50
@export var drop_progress := 0
@export_range(0, 999, 1) var special_ball_sink_penalty := 25

var table
var total_drops_queued := 0
var last_score_drops_queued := 0


func setup(table_ref) -> void:
	table = table_ref


func handle_doubloons_awarded(amount: int, _new_total: int = 0) -> void:
	last_score_drops_queued = 0
	if not enabled or amount <= 0:
		return

	drop_progress += amount
	var drops_earned: int = _queue_earned_drops()
	_emit_progress_changed()
	progress_advanced.emit(amount, drops_earned)
	if drops_earned > 0:
		drop_earned.emit(drops_earned)


func get_debug_snapshot() -> Dictionary:
	return {
		"enabled": enabled,
		"drop_progress": drop_progress,
		"doubloons_per_drop": doubloons_per_drop,
		"progress_percent": get_progress_percent(),
		"last_score_drops_queued": last_score_drops_queued,
		"total_drops_queued": total_drops_queued,
		"pending_spawn_drops": _get_pending_spawn_drop_count(),
	}


func get_progress_percent() -> float:
	if doubloons_per_drop <= 0:
		return 0.0
	return clamp(float(drop_progress) / float(doubloons_per_drop), 0.0, 1.0)


func apply_special_ball_sink_penalty() -> Dictionary:
	# Penalties subtract Doubloons only; they intentionally do not touch drop_progress.
	var applied_penalty := 0
	if table != null and table.score_system != null:
		applied_penalty = table.score_system.apply_doubloons_penalty(special_ball_sink_penalty)
	else:
		applied_penalty = max(special_ball_sink_penalty, 0)

	return {
		"penalty": applied_penalty,
		"message": _get_special_ball_penalty_message(),
	}


func _queue_earned_drops() -> int:
	if table == null or table.spawn_system == null:
		return 0
	if doubloons_per_drop <= 0:
		return 0

	var drops_to_queue := 0
	while drop_progress >= doubloons_per_drop:
		drop_progress -= doubloons_per_drop
		drops_to_queue += 1

	if drops_to_queue <= 0:
		return 0

	last_score_drops_queued = drops_to_queue
	total_drops_queued += drops_to_queue
	for _drop_index in range(drops_to_queue):
		table.spawn_system.queue_spawn_reward(1)
	return drops_to_queue


func _emit_progress_changed() -> void:
	progress_changed.emit(drop_progress, doubloons_per_drop, get_progress_percent())


func _get_special_ball_penalty_message() -> String:
	if SPECIAL_BALL_PENALTY_MESSAGES.is_empty():
		return ""
	return SPECIAL_BALL_PENALTY_MESSAGES.pick_random()


func _get_pending_spawn_drop_count() -> int:
	if table == null or table.spawn_system == null:
		return 0
	return table.spawn_system.get_pending_spawn_count()
