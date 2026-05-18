extends Node
class_name PocketStreakSystem

signal streak_multiplier_reached(multiplier: int)

# Tracks same-pocket object-ball counts and score subtotals for the current shot only.
# It does not award score or draw effects; ScoreSystem and
# PocketStreakPresenter own those responsibilities.

var pocket_counts_by_key: Dictionary = {}
var pocket_score_subtotals_by_key: Dictionary = {}
var pocket_bonus_awarded_by_key: Dictionary = {}
var recorded_ball_ids: Dictionary = {}
var total_streaks_triggered := 0
var highest_streak_this_shot := 0
var last_streak_multiplier := 0
var last_streak_pocket_key := "none"
var last_streak_score_subtotal := 0
var last_streak_bonus_awarded := 0


func setup(_table_ref) -> void:
	reset_shot()


func start_shot() -> void:
	reset_shot()


func finish_shot() -> void:
	reset_shot()


func reset_shot() -> void:
	pocket_counts_by_key.clear()
	pocket_score_subtotals_by_key.clear()
	pocket_bonus_awarded_by_key.clear()
	recorded_ball_ids.clear()
	highest_streak_this_shot = 0
	last_streak_multiplier = 0
	last_streak_pocket_key = "none"
	last_streak_score_subtotal = 0
	last_streak_bonus_awarded = 0


func record_object_ball_sink(sink_context: Dictionary, scored_amount: int) -> Dictionary:
	var ball_id: int = int(sink_context.get("ball_id", 0))
	if ball_id == 0 or recorded_ball_ids.has(ball_id):
		return {}

	recorded_ball_ids[ball_id] = true
	var pocket_key: String = _make_pocket_key(sink_context)
	if pocket_key.is_empty():
		return {}

	var pocket_count: int = int(pocket_counts_by_key.get(pocket_key, 0)) + 1
	var safe_scored_amount: int = maxi(scored_amount, 0)
	var score_subtotal: int = int(pocket_score_subtotals_by_key.get(pocket_key, 0)) + safe_scored_amount
	pocket_counts_by_key[pocket_key] = pocket_count
	pocket_score_subtotals_by_key[pocket_key] = score_subtotal
	highest_streak_this_shot = maxi(highest_streak_this_shot, pocket_count)
	if pocket_count < 2:
		return {}

	var bonus_already_awarded: int = int(pocket_bonus_awarded_by_key.get(pocket_key, 0))
	total_streaks_triggered += 1
	last_streak_multiplier = pocket_count
	last_streak_pocket_key = pocket_key
	last_streak_score_subtotal = score_subtotal
	streak_multiplier_reached.emit(pocket_count)
	return {
		"triggered": true,
		"multiplier": pocket_count,
		"pocket_key": pocket_key,
		"scored_amount": safe_scored_amount,
		"score_subtotal": score_subtotal,
		"bonus_already_awarded": bonus_already_awarded,
		"pocket_index": int(sink_context.get("pocket_index", -1)),
		"pocket_position": _get_pocket_position(sink_context),
		"pocket_radius": float(sink_context.get("pocket_radius", 0.0)),
	}


func note_bonus_awarded(streak_context: Dictionary, awarded_amount: int) -> void:
	var pocket_key: String = str(streak_context.get("pocket_key", ""))
	if pocket_key.is_empty():
		return

	var safe_awarded_amount: int = maxi(awarded_amount, 0)
	var updated_bonus: int = int(pocket_bonus_awarded_by_key.get(pocket_key, 0)) + safe_awarded_amount
	pocket_bonus_awarded_by_key[pocket_key] = updated_bonus
	last_streak_bonus_awarded = updated_bonus


func get_total_streaks_triggered() -> int:
	return total_streaks_triggered


func get_highest_streak_this_shot() -> int:
	return highest_streak_this_shot


func get_last_streak_multiplier() -> int:
	return last_streak_multiplier


func get_last_streak_pocket_key() -> String:
	return last_streak_pocket_key


func get_last_streak_score_subtotal() -> int:
	return last_streak_score_subtotal


func get_last_streak_bonus_awarded() -> int:
	return last_streak_bonus_awarded


func _make_pocket_key(sink_context: Dictionary) -> String:
	var pocket_index: int = int(sink_context.get("pocket_index", -1))
	if pocket_index >= 0:
		return "pocket:%s" % pocket_index

	var pocket_position: Vector2 = _get_pocket_position(sink_context)
	if pocket_position == Vector2.ZERO:
		return ""

	return "pocket:%s:%s" % [int(pocket_position.x + 0.5), int(pocket_position.y + 0.5)]


func _get_pocket_position(sink_context: Dictionary) -> Vector2:
	var pocket_position_value: Variant = sink_context.get("pocket_position", Vector2.ZERO)
	if pocket_position_value is Vector2:
		return pocket_position_value
	return Vector2.ZERO
