@tool
extends Node
class_name ShotEventSystem

# Owns passive per-shot ball event history consumed by Doubloons scoring.
# This is passive tracking only; it should not change gameplay outcomes.
const DEBUG_SHOT_EVENTS := false
const EVENT_BANK := "BANK"
const EVENT_CHAIN := "CHAIN"
const EVENT_MULTI_CHAIN := "MULTI_CHAIN"
const EVENT_ANOMALY_TOUCH := "ANOMALY_TOUCH"
const EVENT_MULTI_SINK := "MULTI_SINK"
const EVENT_KRAKEN_KICK := "KRAKEN_KICK"
const EVENT_DOUBLE_BANK := "DOUBLE_BANK"
const EVENT_THIN_CUT := "THIN_CUT"
const EVENT_CLUSTER_BREAK := "CLUSTER_BREAK"
const EVENT_CROSS_CORNER_BANK := "CROSS_CORNER_BANK"
const EVENT_FULL_TABLE_KICK := "FULL_TABLE_KICK"
const EVENT_POWDER_ROUTE := "POWDER_ROUTE"
const EVENT_KRAKEN_CURRENT := "KRAKEN_CURRENT"
const EVENT_TRIPLE_BANK := "TRIPLE_BANK"
const EVENT_CANNON_CHAIN := "CANNON_CHAIN"
const EVENT_TREASURE_SNARE := "TREASURE_SNARE"
const EVENT_LAST_GASP := "LAST_GASP"
const EVENT_POWER_SINK := "POWER_SINK"
const EVENT_LONG_HAUL := "LONG_HAUL"
const EVENT_SPLIT_THE_LOOT := "SPLIT_THE_LOOT"
const DOUBLE_BANK_RAIL_COUNT := 2
const TRIPLE_BANK_RAIL_COUNT := 3
const THIN_CUT_MAX_CENTER_ALIGNMENT := 0.30
const THIN_CUT_MIN_IMPACT_SPEED := 140.0
const CLUSTER_BREAK_MIN_WOKEN_BALLS := 3
const CLUSTER_WAKE_MIN_SPEED_GAIN := 40.0
const CLUSTER_WAKE_MIN_FINAL_SPEED := 50.0
const CROSS_CORNER_MIN_TABLE_DIAGONAL_RATIO := 0.45
const FULL_TABLE_KICK_MIN_TABLE_DIAGONAL_RATIO := 0.60
const FULL_TABLE_KICK_WITH_RAIL_MIN_TABLE_DIAGONAL_RATIO := 0.38
const POWDER_ROUTE_MIN_VELOCITY_DELTA := 90.0
const KRAKEN_CURRENT_MIN_CUMULATIVE_VELOCITY_DELTA := 70.0
const CANNON_CHAIN_MIN_IMPACT_SPEED := 105.0
const CANNON_CHAIN_MIN_TARGET_VELOCITY_DELTA := 55.0
const CANNON_CHAIN_MIN_CHAIN_SPEED_GAIN := 38.0
const CANNON_CHAIN_MIN_ROUTE_DEPTH := 2
const TREASURE_SNARE_MIN_VELOCITY_DELTA := 14.0
const CORNER_POCKET_AXIS_RATIO := 0.34

@export_range(0.0, 300.0, 1.0) var last_gasp_max_sink_speed := 45.0
@export_range(100.0, 1200.0, 5.0) var power_sink_min_sink_speed := 450.0
@export_range(0.1, 1.0, 0.01) var long_haul_min_table_diagonal_ratio := 0.45

var table
var shot_active := false
var next_event_order := 0
var ball_event_histories: Dictionary = {}
var ball_event_types: Dictionary = {}
var ball_route_start_positions: Dictionary = {}
var ball_chain_depths: Dictionary = {}
var ball_rail_counts: Dictionary = {}
var ball_rail_contact_positions: Dictionary = {}
var cue_rail_contacts := 0
var shot_start_cue_position := Vector2.ZERO
var cluster_woken_ball_ids_by_source: Dictionary = {}
var anchor_velocity_delta_totals: Dictionary = {}
var cannon_route_depths_by_ball_id: Dictionary = {}
var sunk_ball_ids: Array[int] = []
var sunk_ball_labels: Dictionary = {}
var shot_sunk_pocket_indexes: Dictionary = {}
var split_the_loot_recorded := false


func setup(table_ref) -> void:
	table = table_ref


func start_shot(cue_start_position: Vector2 = Vector2.ZERO) -> void:
	clear_shot_events()
	shot_start_cue_position = cue_start_position
	shot_active = true


func finish_shot() -> void:
	clear_shot_events()
	shot_active = false


func clear_shot_events() -> void:
	next_event_order = 0
	ball_event_histories.clear()
	ball_event_types.clear()
	ball_route_start_positions.clear()
	ball_chain_depths.clear()
	ball_rail_counts.clear()
	ball_rail_contact_positions.clear()
	cue_rail_contacts = 0
	shot_start_cue_position = Vector2.ZERO
	cluster_woken_ball_ids_by_source.clear()
	anchor_velocity_delta_totals.clear()
	cannon_route_depths_by_ball_id.clear()
	sunk_ball_ids.clear()
	sunk_ball_labels.clear()
	shot_sunk_pocket_indexes.clear()
	split_the_loot_recorded = false


func record_rail_contact(ball: Ball, rail_position: Vector2 = Vector2.ZERO) -> void:
	if not shot_active or ball == null:
		return

	if table != null and ball == table.cue_ball:
		cue_rail_contacts += 1
		return

	if not _is_scoring_object_ball(ball):
		return

	_remember_ball_route_start(ball)
	var ball_id: int = ball.get_instance_id()
	var rail_count: int = int(ball_rail_counts.get(ball_id, 0)) + 1
	ball_rail_counts[ball_id] = rail_count
	if rail_position != Vector2.ZERO:
		_get_or_make_rail_contact_positions(ball_id).append(rail_position)
	_record_unique_event_for_id(ball_id, EVENT_BANK)
	if rail_count >= DOUBLE_BANK_RAIL_COUNT:
		_record_unique_event_for_id(ball_id, EVENT_DOUBLE_BANK)
	if rail_count >= TRIPLE_BANK_RAIL_COUNT:
		_record_unique_event_for_id(ball_id, EVENT_TRIPLE_BANK)


func record_bank(ball: Ball) -> void:
	record_rail_contact(ball)


func record_cue_object_contact(
	ball: Ball,
	center_alignment: float = 1.0,
	impact_speed: float = 0.0,
	cue_contact_position: Vector2 = Vector2.ZERO
) -> void:
	if not shot_active or ball == null:
		return

	_remember_ball_route_start(ball)
	_set_chain_depth(ball.get_instance_id(), maxi(_get_chain_depth(ball), 1))
	if cue_rail_contacts > 0:
		_record_unique_event(ball, EVENT_KRAKEN_KICK)
	if _is_full_table_kick_contact(cue_contact_position):
		_record_unique_event(ball, EVENT_FULL_TABLE_KICK)
	if _is_thin_cut_contact(center_alignment, impact_speed):
		_record_unique_event(ball, EVENT_THIN_CUT)


func record_chain_transfer(source_ball: Ball, target_ball: Ball, target_speed_gain: float = 0.0) -> void:
	if not shot_active or source_ball == null or target_ball == null:
		return

	var source_depth: int = maxi(_get_chain_depth(source_ball), 1)
	var target_depth: int = source_depth + 1
	_remember_ball_route_start(target_ball)
	_set_chain_depth(target_ball.get_instance_id(), target_depth)
	_propagate_route_events(source_ball, target_ball, target_speed_gain)


func record_collision_motion(
	ball_a: Ball,
	ball_b: Ball,
	pre_collision_velocity_a: Vector2,
	pre_collision_velocity_b: Vector2
) -> void:
	if not shot_active or ball_a == null or ball_b == null:
		return

	_try_record_cluster_wake(ball_b, ball_a, pre_collision_velocity_a)
	_try_record_cluster_wake(ball_a, ball_b, pre_collision_velocity_b)


func record_anomaly_touch(ball: Ball) -> void:
	_record_unique_event(ball, EVENT_ANOMALY_TOUCH)


func record_powder_route_influence(ball: Ball, velocity_delta: Vector2) -> void:
	if not shot_active or not _is_scoring_object_ball(ball):
		return
	if velocity_delta.length() < POWDER_ROUTE_MIN_VELOCITY_DELTA:
		return

	_record_unique_event(ball, EVENT_POWDER_ROUTE)


func record_anchor_influence(ball: Ball, velocity_delta: Vector2) -> void:
	if not shot_active or not _is_scoring_object_ball(ball):
		return

	_remember_ball_route_start(ball)
	var ball_id: int = ball.get_instance_id()
	var total_delta: float = float(anchor_velocity_delta_totals.get(ball_id, 0.0)) + velocity_delta.length()
	anchor_velocity_delta_totals[ball_id] = total_delta
	if total_delta >= KRAKEN_CURRENT_MIN_CUMULATIVE_VELOCITY_DELTA:
		_record_unique_event_for_id(ball_id, EVENT_KRAKEN_CURRENT)


func record_cannon_chain_influence(
	cannon_ball: Ball,
	target_ball: Ball,
	impact_speed: float,
	velocity_delta: Vector2
) -> void:
	if not shot_active or cannon_ball == null or target_ball == null:
		return
	if not cannon_ball.is_cannon_ball or not _is_scoring_object_ball(target_ball):
		return
	if impact_speed < CANNON_CHAIN_MIN_IMPACT_SPEED:
		return
	if velocity_delta.length() < CANNON_CHAIN_MIN_TARGET_VELOCITY_DELTA:
		return

	_remember_ball_route_start(target_ball)
	_set_cannon_route_depth(target_ball.get_instance_id(), 1)


func record_treasure_snare_influence(ball: Ball, velocity_delta: Vector2) -> void:
	if not shot_active or not _is_scoring_object_ball(ball):
		return
	if velocity_delta.length() < TREASURE_SNARE_MIN_VELOCITY_DELTA:
		return

	_record_unique_event(ball, EVENT_TREASURE_SNARE)


func record_ball_sunk(ball: Ball, sink_context: Dictionary = {}) -> void:
	if not shot_active or ball == null:
		return

	var ball_id: int = ball.get_instance_id()
	sunk_ball_labels[ball_id] = _get_ball_label(ball)
	if sunk_ball_ids.has(ball_id):
		return

	sunk_ball_ids.append(ball_id)
	_record_sink_geometry_events(ball_id, sink_context)
	_record_split_the_loot_if_qualified(ball_id, sink_context)
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

	_remember_ball_route_start(ball)
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


func _get_or_make_rail_contact_positions(ball_id: int) -> Array:
	if not ball_rail_contact_positions.has(ball_id):
		ball_rail_contact_positions[ball_id] = []
	return ball_rail_contact_positions[ball_id]


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


func _record_sink_geometry_events(ball_id: int, sink_context: Dictionary) -> void:
	var pocket_position: Vector2 = Vector2.ZERO
	var pocket_position_value: Variant = sink_context.get("pocket_position", Vector2.ZERO)
	if pocket_position_value is Vector2:
		pocket_position = pocket_position_value
	if _is_cross_corner_bank(ball_id, pocket_position):
		_record_unique_event_for_id(ball_id, EVENT_CROSS_CORNER_BANK)

	var sink_velocity := _get_vector2_from_context(sink_context, "sink_velocity")
	var sink_speed := sink_velocity.length()
	if sink_speed < last_gasp_max_sink_speed:
		_record_unique_event_for_id(ball_id, EVENT_LAST_GASP)
	elif sink_speed > power_sink_min_sink_speed:
		_record_unique_event_for_id(ball_id, EVENT_POWER_SINK)

	var sink_position := _get_vector2_from_context(sink_context, "sink_position")
	if _is_long_haul_sink(ball_id, sink_position):
		_record_unique_event_for_id(ball_id, EVENT_LONG_HAUL)


func _record_split_the_loot_if_qualified(ball_id: int, sink_context: Dictionary) -> void:
	if split_the_loot_recorded:
		return

	var pocket_index := int(sink_context.get("pocket_index", -1))
	if pocket_index >= 0:
		shot_sunk_pocket_indexes[pocket_index] = true
	if sunk_ball_ids.size() < 3 or shot_sunk_pocket_indexes.size() < 3:
		return

	split_the_loot_recorded = true
	_record_unique_event_for_id(ball_id, EVENT_SPLIT_THE_LOOT)


func _is_long_haul_sink(ball_id: int, sink_position: Vector2) -> bool:
	if sink_position == Vector2.ZERO or not ball_route_start_positions.has(ball_id):
		return false

	var table_diagonal := _get_table_diagonal()
	if table_diagonal <= 0.0:
		return false

	var start_position_value: Variant = ball_route_start_positions.get(ball_id, Vector2.ZERO)
	if not start_position_value is Vector2:
		return false

	var start_position: Vector2 = start_position_value
	var travel_ratio := start_position.distance_to(sink_position) / table_diagonal
	return travel_ratio >= long_haul_min_table_diagonal_ratio


func _get_vector2_from_context(context: Dictionary, key: String) -> Vector2:
	var value: Variant = context.get(key, Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO


func _is_cross_corner_bank(ball_id: int, pocket_position: Vector2) -> bool:
	if int(ball_rail_counts.get(ball_id, 0)) <= 0:
		return false
	if not _is_corner_pocket_position(pocket_position):
		return false

	var rail_positions: Array = []
	var rail_positions_value: Variant = ball_rail_contact_positions.get(ball_id, [])
	if rail_positions_value is Array:
		rail_positions = rail_positions_value
	var table_diagonal: float = _get_table_diagonal()
	var minimum_cross_distance: float = table_diagonal * CROSS_CORNER_MIN_TABLE_DIAGONAL_RATIO
	var pocket_corner_sign: Vector2 = _get_table_corner_sign(pocket_position)
	for rail_position_value in rail_positions:
		if not (rail_position_value is Vector2):
			continue
		var rail_position: Vector2 = rail_position_value
		if rail_position.distance_to(pocket_position) < minimum_cross_distance:
			continue

		var rail_corner_sign: Vector2 = _get_table_corner_sign(rail_position)
		if rail_corner_sign.x == -pocket_corner_sign.x and rail_corner_sign.y == -pocket_corner_sign.y:
			return true
	return false


func _is_full_table_kick_contact(cue_contact_position: Vector2) -> bool:
	if cue_contact_position == Vector2.ZERO:
		return false

	var table_diagonal: float = _get_table_diagonal()
	if table_diagonal <= 0.0:
		return false

	var travel_ratio: float = shot_start_cue_position.distance_to(cue_contact_position) / table_diagonal
	if travel_ratio >= FULL_TABLE_KICK_MIN_TABLE_DIAGONAL_RATIO:
		return true
	return cue_rail_contacts > 0 and travel_ratio >= FULL_TABLE_KICK_WITH_RAIL_MIN_TABLE_DIAGONAL_RATIO


func _is_thin_cut_contact(center_alignment: float, impact_speed: float) -> bool:
	return (
		impact_speed >= THIN_CUT_MIN_IMPACT_SPEED
		and center_alignment > 0.0
		and center_alignment <= THIN_CUT_MAX_CENTER_ALIGNMENT
	)


func _try_record_cluster_wake(source_ball: Ball, woken_ball: Ball, pre_collision_velocity: Vector2) -> void:
	if not _is_scoring_object_ball(woken_ball):
		return
	if not _was_ball_previously_stopped(woken_ball, pre_collision_velocity):
		return

	var final_speed: float = woken_ball.velocity.length()
	var speed_gain: float = final_speed - pre_collision_velocity.length()
	if final_speed < CLUSTER_WAKE_MIN_FINAL_SPEED or speed_gain < CLUSTER_WAKE_MIN_SPEED_GAIN:
		return

	var source_id: int = source_ball.get_instance_id()
	var woken_ids: Dictionary = _get_or_make_cluster_woken_set(source_id)
	var woken_id: int = woken_ball.get_instance_id()
	if woken_ids.has(woken_id):
		return

	woken_ids[woken_id] = true
	if woken_ids.size() < CLUSTER_BREAK_MIN_WOKEN_BALLS:
		return

	if _is_scoring_object_ball(source_ball):
		_record_unique_event(source_ball, EVENT_CLUSTER_BREAK)
	for cluster_woken_id in woken_ids.keys():
		_record_unique_event_for_id(int(cluster_woken_id), EVENT_CLUSTER_BREAK)


func _was_ball_previously_stopped(ball: Ball, pre_collision_velocity: Vector2) -> bool:
	return pre_collision_velocity.length() < ball.stop_threshold


func _get_or_make_cluster_woken_set(source_id: int) -> Dictionary:
	if not cluster_woken_ball_ids_by_source.has(source_id):
		cluster_woken_ball_ids_by_source[source_id] = {}
	return cluster_woken_ball_ids_by_source[source_id]


func _propagate_route_events(source_ball: Ball, target_ball: Ball, target_speed_gain: float) -> void:
	var source_id: int = source_ball.get_instance_id()
	if _has_recorded_event(source_id, EVENT_POWDER_ROUTE):
		_record_unique_event(target_ball, EVENT_POWDER_ROUTE)
	if _has_recorded_event(source_id, EVENT_KRAKEN_CURRENT):
		_record_unique_event(target_ball, EVENT_KRAKEN_CURRENT)
	if _has_recorded_event(source_id, EVENT_TREASURE_SNARE):
		_record_unique_event(target_ball, EVENT_TREASURE_SNARE)
	_propagate_cannon_chain(source_id, target_ball, target_speed_gain)


func _propagate_cannon_chain(source_id: int, target_ball: Ball, target_speed_gain: float) -> void:
	if target_speed_gain < CANNON_CHAIN_MIN_CHAIN_SPEED_GAIN:
		return

	var source_route_depth: int = int(cannon_route_depths_by_ball_id.get(source_id, 0))
	if source_route_depth <= 0:
		return

	var target_id: int = target_ball.get_instance_id()
	var target_route_depth: int = source_route_depth + 1
	_set_cannon_route_depth(target_id, target_route_depth)
	if target_route_depth >= CANNON_CHAIN_MIN_ROUTE_DEPTH:
		_record_unique_event_for_id(target_id, EVENT_CANNON_CHAIN)


func _set_cannon_route_depth(ball_id: int, route_depth: int) -> void:
	var current_route_depth: int = int(cannon_route_depths_by_ball_id.get(ball_id, 0))
	if route_depth <= current_route_depth:
		return

	cannon_route_depths_by_ball_id[ball_id] = route_depth


func _has_recorded_event(ball_id: int, event_type: String) -> bool:
	if not ball_event_types.has(ball_id):
		return false

	var known_types_value: Variant = ball_event_types[ball_id]
	if not (known_types_value is Dictionary):
		return false

	var known_types: Dictionary = known_types_value
	return known_types.has(event_type)


func _remember_ball_route_start(ball: Ball) -> void:
	if ball == null or not _is_scoring_object_ball(ball):
		return

	var ball_id := ball.get_instance_id()
	if ball_route_start_positions.has(ball_id):
		return
	ball_route_start_positions[ball_id] = ball.global_position


func _is_corner_pocket_position(pocket_position: Vector2) -> bool:
	if pocket_position == Vector2.ZERO or table == null:
		return false

	var table_rect: Rect2 = table.playfield_rect
	if table_rect.size.x <= 0.0 or table_rect.size.y <= 0.0:
		return false

	var center: Vector2 = table_rect.get_center()
	return (
		abs(pocket_position.x - center.x) >= table_rect.size.x * CORNER_POCKET_AXIS_RATIO
		and abs(pocket_position.y - center.y) >= table_rect.size.y * CORNER_POCKET_AXIS_RATIO
	)


func _get_table_corner_sign(position: Vector2) -> Vector2:
	if table == null:
		return Vector2.ONE

	var center: Vector2 = table.playfield_rect.get_center()
	var x_sign: float = -1.0 if position.x < center.x else 1.0
	var y_sign: float = -1.0 if position.y < center.y else 1.0
	return Vector2(x_sign, y_sign)


func _get_table_diagonal() -> float:
	if table == null or table.playfield_rect.size == Vector2.ZERO:
		return 0.0
	return table.playfield_rect.size.length()


func _is_scoring_object_ball(ball: Ball) -> bool:
	return ball != null and ball.ball_type == Ball.BallType.OBJECT


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
	if ball.is_cannon_ball:
		return "Cannon Ball"
	return "Ball %s" % ball.ball_number
