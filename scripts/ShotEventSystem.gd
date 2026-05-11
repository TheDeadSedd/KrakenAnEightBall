@tool
extends Node
class_name ShotEventSystem

# Owns per-shot ball event history for the future Doubloons system.
# This is passive tracking only; it should not change gameplay outcomes.
const DEBUG_SHOT_EVENTS := true
const EVENT_BANK := "BANK"
const EVENT_CHAIN := "CHAIN"
const EVENT_MULTI_CHAIN := "MULTI_CHAIN"
const EVENT_ANOMALY_TOUCH := "ANOMALY_TOUCH"
const EVENT_MULTI_SINK := "MULTI_SINK"

var table
var shot_active := false
var next_event_order := 0
var ball_event_histories: Dictionary = {}
var ball_event_types: Dictionary = {}
var ball_chain_depths: Dictionary = {}
var sunk_ball_ids: Array[int] = []
var sunk_ball_labels: Dictionary = {}


func setup(table_ref) -> void:
	table = table_ref


func start_shot() -> void:
	clear_shot_events()
	shot_active = true


func finish_shot() -> void:
	clear_shot_events()
	shot_active = false


func clear_shot_events() -> void:
	next_event_order = 0
	ball_event_histories.clear()
	ball_event_types.clear()
	ball_chain_depths.clear()
	sunk_ball_ids.clear()
	sunk_ball_labels.clear()


func record_bank(ball: Ball) -> void:
	_record_unique_event(ball, EVENT_BANK)


func record_cue_object_contact(ball: Ball) -> void:
	if not shot_active or ball == null:
		return

	_set_chain_depth(ball.get_instance_id(), max(_get_chain_depth(ball), 1))


func record_chain_transfer(source_ball: Ball, target_ball: Ball) -> void:
	if not shot_active or source_ball == null or target_ball == null:
		return

	var source_depth: int = max(_get_chain_depth(source_ball), 1)
	var target_depth: int = source_depth + 1
	_set_chain_depth(target_ball.get_instance_id(), target_depth)


func record_anomaly_touch(ball: Ball) -> void:
	_record_unique_event(ball, EVENT_ANOMALY_TOUCH)


func record_ball_sunk(ball: Ball) -> void:
	if not shot_active or ball == null:
		return

	var ball_id: int = ball.get_instance_id()
	sunk_ball_labels[ball_id] = _get_ball_label(ball)
	if sunk_ball_ids.has(ball_id):
		return

	sunk_ball_ids.append(ball_id)
	_record_chain_events_for_sunk_ball(ball_id)
	if sunk_ball_ids.size() >= 2:
		_record_unique_event_for_id(ball_id, EVENT_MULTI_SINK)

	_print_sunk_ball_events(ball_id)


func get_event_history(ball: Ball) -> Array[String]:
	if ball == null:
		var empty_history: Array[String] = []
		return empty_history

	return _get_event_names_for_id(ball.get_instance_id())


func get_sunk_ball_score_snapshot(ball_id: int) -> Dictionary:
	if not sunk_ball_labels.has(ball_id):
		return {}

	return {
		"ball_id": ball_id,
		"label": str(sunk_ball_labels.get(ball_id, "Ball")),
		"events": _get_event_names_for_id(ball_id),
	}


func _record_unique_event(ball: Ball, event_type: String) -> void:
	if not shot_active or ball == null:
		return

	_record_unique_event_for_id(ball.get_instance_id(), event_type)


func _record_unique_event_for_id(ball_id: int, event_type: String) -> void:
	var known_types: Dictionary = _get_or_make_event_type_set(ball_id)
	if known_types.has(event_type):
		return

	known_types[event_type] = true
	var history: Array = _get_or_make_history(ball_id)
	history.append({"type": event_type, "order": next_event_order})
	next_event_order += 1


func _record_repeatable_event_for_id(ball_id: int, event_type: String) -> void:
	var history: Array = _get_or_make_history(ball_id)
	history.append({"type": event_type, "order": next_event_order})
	next_event_order += 1


func _record_chain_events_for_sunk_ball(ball_id: int) -> void:
	var chain_depth: int = int(ball_chain_depths.get(ball_id, 0))
	if chain_depth < 2:
		return

	_record_unique_event_for_id(ball_id, EVENT_CHAIN)
	for _index in range(chain_depth - 1):
		_record_repeatable_event_for_id(ball_id, EVENT_MULTI_CHAIN)


func _get_or_make_event_type_set(ball_id: int) -> Dictionary:
	if not ball_event_types.has(ball_id):
		ball_event_types[ball_id] = {}
	return ball_event_types[ball_id]


func _get_or_make_history(ball_id: int) -> Array:
	if not ball_event_histories.has(ball_id):
		ball_event_histories[ball_id] = []
	return ball_event_histories[ball_id]


func _get_event_names_for_id(ball_id: int) -> Array[String]:
	var event_names: Array[String] = []
	if not ball_event_histories.has(ball_id):
		return event_names

	for event_entry in ball_event_histories[ball_id]:
		event_names.append(str(event_entry["type"]))
	return event_names


func _get_chain_depth(ball: Ball) -> int:
	if ball == null:
		return 0
	return int(ball_chain_depths.get(ball.get_instance_id(), 0))


func _set_chain_depth(ball_id: int, chain_depth: int) -> void:
	var current_depth: int = int(ball_chain_depths.get(ball_id, 0))
	if chain_depth <= current_depth:
		return

	ball_chain_depths[ball_id] = chain_depth


func _print_sunk_ball_events(ball_id: int) -> void:
	if not DEBUG_SHOT_EVENTS:
		return

	var label: String = str(sunk_ball_labels.get(ball_id, "Ball"))
	print("%s sunk events: %s" % [label, _get_event_names_for_id(ball_id)])


func _get_ball_label(ball: Ball) -> String:
	if table != null and ball == table.cue_ball:
		return "Cue ball"
	if table != null and ball == table.eight_ball:
		return "Ball 8"
	if ball.is_wayfinder:
		return "Wayfinder Ball"
	if ball.is_powder_keg:
		return "Powder Keg"
	if ball.is_anchor_ball:
		return "Anchor Ball"
	return "Ball %s" % ball.ball_number
