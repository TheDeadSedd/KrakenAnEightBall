extends Node2D
class_name PocketCapturePresenter

const CAPTURE_VISUAL_SCRIPT := preload("res://scripts/PocketCapturedBallVisual.gd")
const REWIND_STATE_VERSION := 1
const MAX_VISIBLE_PER_POCKET := 8
const MAX_VISIBLE_TOTAL := 48
const APPROACH_DURATION := 0.11
const DROP_DURATION := 0.13
const UNDER_TABLE_ROLL_DURATION := 0.23
const TRANSIENT_FADE_DURATION := 0.10
const OVERFLOW_FADE_DURATION := 0.16
const MIN_INWARD_DISTANCE := 23.0
const MAX_INWARD_DISTANCE := 39.0

@export var enabled: bool = true

var table: BilliardsTable
var pocket_visuals: Dictionary = {}
var total_captures_by_pocket: Dictionary = {}
var active_capture_visuals: Array[PocketCapturedBallVisual] = []
var capture_serial_counter: int = 0
var total_capture_events: int = 0
var proxies_removed_by_visible_cap: int = 0
var last_captured_pocket: int = -1
var last_captured_ball_identity: String = "None"
var last_capture_shot_id: int = -1
var rewind_generation: int = 0
var last_clear_reason: String = "initial"


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	set_process(false)
	_initialize_pocket_state()


func present_capture(
	ball: Ball,
	pocket_index: int,
	pocket_global_position: Vector2,
	pocket_radius: float
) -> void:
	if not enabled or table == null or ball == null:
		return
	if pocket_index < 0:
		return

	_ensure_pocket_state(pocket_index)
	_cleanup_invalid_references()
	total_capture_events += 1
	capture_serial_counter += 1
	last_captured_pocket = pocket_index
	last_captured_ball_identity = _get_ball_identity_label(ball)
	last_capture_shot_id = table.shots_taken_count
	var pocket_total: int = int(total_captures_by_pocket.get(pocket_index, 0)) + 1
	total_captures_by_pocket[pocket_index] = pocket_total

	var visual: PocketCapturedBallVisual = CAPTURE_VISUAL_SCRIPT.new() as PocketCapturedBallVisual
	if visual == null:
		return
	add_child(visual)
	visual.position = to_local(ball.global_position)
	visual.rotation = ball.visual_spin_angle
	var appearance_snapshot: Dictionary = _capture_appearance(ball)
	appearance_snapshot["captured_pocket_index"] = pocket_index
	appearance_snapshot["captured_pocket_center"] = pocket_global_position
	appearance_snapshot["captured_pocket_radius"] = pocket_radius
	visual.configure(appearance_snapshot, pocket_index, capture_serial_counter)
	visual.capture_animation_finished.connect(_on_capture_animation_finished.bind(visual))

	var should_persist: bool = ball != table.cue_ball
	var pocket_local_position: Vector2 = to_local(pocket_global_position)
	var inward_direction: Vector2 = _get_inward_direction(pocket_global_position)
	var variation: Dictionary = _get_capture_variation(
		pocket_index,
		pocket_total,
		ball.ball_number,
		should_persist
	)
	var target_position: Vector2 = pocket_local_position + inward_direction * float(variation.get("inward_distance", 30.0))
	target_position += inward_direction.orthogonal() * float(variation.get("lateral_offset", 0.0))
	var target_scale: Vector2 = Vector2(
		float(variation.get("scale", 1.0)) * 0.82,
		float(variation.get("scale", 1.0)) * 0.72
	)
	var target_rotation: float = float(variation.get("rotation", 0.0))

	if should_persist:
		var pile: Array = _get_pocket_visuals(pocket_index)
		pile.append(visual)
		pocket_visuals[pocket_index] = pile
	active_capture_visuals.append(visual)
	visual.play_capture(
		pocket_local_position,
		inward_direction,
		target_position,
		target_scale,
		target_rotation,
		should_persist,
		APPROACH_DURATION,
		DROP_DURATION,
		UNDER_TABLE_ROLL_DURATION,
		TRANSIENT_FADE_DURATION
	)

	if should_persist:
		_enforce_pocket_limit(pocket_index, inward_direction)
		_enforce_total_limit(inward_direction)


func react_to_pocket_streak(pocket_global_position: Vector2, multiplier: int) -> void:
	if not enabled or multiplier < 2:
		return
	var pocket_index: int = _find_nearest_pocket_index(pocket_global_position)
	if pocket_index < 0:
		return
	var pile: Array = _get_pocket_visuals(pocket_index)
	if pile.is_empty():
		return
	var inward: Vector2 = _get_inward_direction(pocket_global_position)
	var strength: float = clampf(float(multiplier - 1), 1.0, 4.0)
	for visual_index in range(pile.size()):
		var visual: PocketCapturedBallVisual = pile[visual_index] as PocketCapturedBallVisual
		if visual == null or not is_instance_valid(visual) or not visual.settled:
			continue
		var side_sign: float = -1.0 if visual_index % 2 == 0 else 1.0
		var offset: Vector2
		if multiplier >= 4:
			offset = -inward * (3.5 + strength) + inward.orthogonal() * side_sign * 1.8
		elif multiplier == 3:
			offset = inward * 3.5 + inward.orthogonal() * side_sign * 2.4
		else:
			offset = inward * 2.5 + inward.orthogonal() * side_sign * 1.6
		visual.play_collection_reaction(offset, 1.0 - 0.025 * strength, 0.22 + 0.025 * strength)


func set_presentation_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		clear_collections("presentation_disabled")


func clear_collections(reason: String = "manual") -> void:
	for child in get_children():
		var visual: PocketCapturedBallVisual = child as PocketCapturedBallVisual
		if visual == null:
			continue
		visual.cancel_animation()
		remove_child(visual)
		visual.free()
	pocket_visuals.clear()
	total_captures_by_pocket.clear()
	active_capture_visuals.clear()
	capture_serial_counter = 0
	total_capture_events = 0
	proxies_removed_by_visible_cap = 0
	last_captured_pocket = -1
	last_captured_ball_identity = "None"
	last_capture_shot_id = -1
	last_clear_reason = reason
	_initialize_pocket_state()


func prepare_for_rewind() -> void:
	for visual in active_capture_visuals.duplicate():
		if visual != null and is_instance_valid(visual):
			visual.cancel_animation()
	active_capture_visuals.clear()


func get_rewind_state() -> Dictionary:
	var visual_states: Array[Dictionary] = []
	for pocket_index_value in pocket_visuals.keys():
		var pocket_index: int = int(pocket_index_value)
		for visual_value in _get_pocket_visuals(pocket_index):
			var visual: PocketCapturedBallVisual = visual_value as PocketCapturedBallVisual
			if visual == null or not is_instance_valid(visual):
				continue
			visual_states.append(visual.get_rewind_state())
	return {
		"version": REWIND_STATE_VERSION,
		"visuals": visual_states,
		"total_capture_events": total_capture_events,
		"total_captures_by_pocket": total_captures_by_pocket.duplicate(true),
		"capture_serial_counter": capture_serial_counter,
		"proxies_removed_by_visible_cap": proxies_removed_by_visible_cap,
		"last_captured_pocket": last_captured_pocket,
		"last_captured_ball_identity": last_captured_ball_identity,
		"last_capture_shot_id": last_capture_shot_id,
	}


func restore_rewind_state(state: Dictionary) -> void:
	clear_collections("shot_rewind")
	rewind_generation += 1
	if int(state.get("version", 0)) != REWIND_STATE_VERSION:
		return
	total_capture_events = maxi(int(state.get("total_capture_events", 0)), 0)
	capture_serial_counter = maxi(int(state.get("capture_serial_counter", 0)), 0)
	proxies_removed_by_visible_cap = maxi(int(state.get("proxies_removed_by_visible_cap", 0)), 0)
	last_captured_pocket = int(state.get("last_captured_pocket", -1))
	last_captured_ball_identity = str(state.get("last_captured_ball_identity", "None"))
	last_capture_shot_id = int(state.get("last_capture_shot_id", -1))
	var totals_value: Variant = state.get("total_captures_by_pocket", {})
	if totals_value is Dictionary:
		var restored_totals: Dictionary = totals_value as Dictionary
		for key_value in restored_totals.keys():
			total_captures_by_pocket[int(key_value)] = int(restored_totals[key_value])
	if not enabled:
		return
	var visuals_value: Variant = state.get("visuals", [])
	if not visuals_value is Array:
		return
	for visual_state_value in visuals_value:
		if not visual_state_value is Dictionary:
			continue
		var visual_state: Dictionary = visual_state_value
		var pocket_index: int = int(visual_state.get("pocket_index", -1))
		if pocket_index < 0:
			continue
		_ensure_pocket_state(pocket_index)
		var visual: PocketCapturedBallVisual = CAPTURE_VISUAL_SCRIPT.new() as PocketCapturedBallVisual
		if visual == null:
			continue
		add_child(visual)
		visual.restore_settled(visual_state)
		var pile: Array = _get_pocket_visuals(pocket_index)
		pile.append(visual)
		pocket_visuals[pocket_index] = pile


func get_debug_snapshot() -> Dictionary:
	_cleanup_invalid_references()
	var visible_by_pocket: Dictionary = {}
	var visible_total: int = 0
	for pocket_index_value in pocket_visuals.keys():
		var pocket_index: int = int(pocket_index_value)
		var visible_count: int = _get_pocket_visuals(pocket_index).size()
		visible_by_pocket[pocket_index] = visible_count
		visible_total += visible_count
	return {
		"enabled": enabled,
		"active_capture_animations": active_capture_visuals.size(),
		"visible_collected_proxies": visible_total,
		"total_visual_nodes": get_child_count(),
		"total_captures_represented": total_capture_events,
		"visible_proxies_by_pocket": visible_by_pocket,
		"total_captures_by_pocket": total_captures_by_pocket.duplicate(true),
		"proxies_removed_by_visible_cap": proxies_removed_by_visible_cap,
		"maximum_visible_per_pocket": MAX_VISIBLE_PER_POCKET,
		"maximum_visible_total": MAX_VISIBLE_TOTAL,
		"mode_persistence_policy": _get_mode_persistence_policy(),
		"last_captured_pocket": last_captured_pocket,
		"last_captured_ball_identity": last_captured_ball_identity,
		"last_capture_shot_id": last_capture_shot_id,
		"rewind_generation": rewind_generation,
		"last_clear_reason": last_clear_reason,
	}


func _capture_appearance(ball: Ball) -> Dictionary:
	var identity: String = "object"
	if ball == table.cue_ball or ball.ball_type == Ball.BallType.CUE:
		identity = "cue"
	elif ball == table.eight_ball or ball.ball_type == Ball.BallType.EIGHT:
		identity = "eight"
	return {
		"identity": identity,
		"ball_number": ball.ball_number,
		"ball_color": ball.ball_color,
		"display_color": ball.get_aim_preview_display_color(),
		"radius": ball.radius,
		"show_ball_numbers": ball.show_ball_numbers,
		"source_global_position": ball.global_position,
		"incoming_velocity": ball.velocity,
		"visual_spin_angle": ball.visual_spin_angle,
		"is_wayfinder": ball.is_wayfinder,
		"is_powder_keg": ball.is_powder_keg,
		"is_anchor_ball": ball.is_anchor_ball,
		"is_anchor_curse_seed": ball.is_anchor_curse_seed,
		"is_cannon_ball": ball.is_cannon_ball,
		"is_treasure_ball": ball.is_treasure_ball,
		"is_embezzler_ball": ball.is_embezzler_ball,
	}


func _get_ball_identity_label(ball: Ball) -> String:
	if ball == table.cue_ball or ball.ball_type == Ball.BallType.CUE:
		return "Cue Ball"
	if ball == table.eight_ball or ball.ball_type == Ball.BallType.EIGHT:
		return "8 Ball"
	if ball.is_wayfinder:
		return "Wayfinder Ball"
	if ball.is_powder_keg:
		return "Powder Keg"
	if ball.is_anchor_ball or ball.is_anchor_curse_seed:
		return "Anchor Ball"
	if ball.is_cannon_ball:
		return "Cannon Ball"
	if ball.is_treasure_ball:
		return "Treasure Ball"
	if ball.is_embezzler_ball:
		return "Embezzler"
	return "Ball #%s" % ball.ball_number


func _get_capture_variation(
	pocket_index: int,
	pocket_total: int,
	ball_number: int,
	should_persist: bool
) -> Dictionary:
	var visual_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	visual_rng.seed = int(
		(pocket_index + 1) * 1000003
		+ pocket_total * 9176
		+ (ball_number + 17) * 131
	)
	if not should_persist:
		return {
			"inward_distance": visual_rng.randf_range(31.0, 37.0),
			"lateral_offset": visual_rng.randf_range(-4.0, 4.0),
			"scale": visual_rng.randf_range(0.90, 0.97),
			"rotation": visual_rng.randf_range(-0.15, 0.15),
		}
	var slot: int = (pocket_total - 1) % MAX_VISIBLE_PER_POCKET
	var depth_band: int = floori(float(slot) / 4.0)
	var lane: int = slot % 4
	var lateral_pattern: Array[float] = [-6.5, 3.0, -1.5, 7.0]
	var inward_distance: float = MIN_INWARD_DISTANCE + float(lane) * 3.4 + float(depth_band) * 5.2
	inward_distance += visual_rng.randf_range(-2.2, 2.2)
	return {
		"inward_distance": clampf(inward_distance, MIN_INWARD_DISTANCE, MAX_INWARD_DISTANCE),
		"lateral_offset": lateral_pattern[lane] + visual_rng.randf_range(-2.6, 2.6),
		"scale": visual_rng.randf_range(0.92, 1.03),
		"rotation": visual_rng.randf_range(-0.18, 0.18),
	}


func _get_inward_direction(pocket_global_position: Vector2) -> Vector2:
	if table == null:
		return Vector2.DOWN
	var table_center_global: Vector2 = table.to_global(table.playfield_rect.get_center())
	var global_direction: Vector2 = (table_center_global - pocket_global_position).normalized()
	if global_direction.is_zero_approx():
		global_direction = Vector2.DOWN
	var local_direction: Vector2 = to_local(pocket_global_position + global_direction) - to_local(pocket_global_position)
	return local_direction.normalized()


func _find_nearest_pocket_index(pocket_global_position: Vector2) -> int:
	if table == null or table.pocket_system == null:
		return -1
	var positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
	var nearest_index: int = -1
	var nearest_distance_squared: float = INF
	for pocket_index in range(positions.size()):
		var distance_squared: float = positions[pocket_index].distance_squared_to(pocket_global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_index = pocket_index
	return nearest_index


func _enforce_pocket_limit(pocket_index: int, inward_direction: Vector2) -> void:
	var pile: Array = _get_pocket_visuals(pocket_index)
	while pile.size() > MAX_VISIBLE_PER_POCKET:
		var oldest: PocketCapturedBallVisual = pile.pop_front() as PocketCapturedBallVisual
		_retire_visual_for_cap(oldest, inward_direction)
	pocket_visuals[pocket_index] = pile


func _enforce_total_limit(inward_fallback: Vector2) -> void:
	while _get_visible_collected_count() > MAX_VISIBLE_TOTAL:
		var oldest: PocketCapturedBallVisual = _find_oldest_collected_visual()
		if oldest == null:
			return
		var old_pocket_index: int = oldest.pocket_index
		var pile: Array = _get_pocket_visuals(old_pocket_index)
		pile.erase(oldest)
		pocket_visuals[old_pocket_index] = pile
		_retire_visual_for_cap(oldest, inward_fallback)


func _retire_visual_for_cap(visual: PocketCapturedBallVisual, inward_direction: Vector2) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	active_capture_visuals.erase(visual)
	proxies_removed_by_visible_cap += 1
	var deeper_position: Vector2 = visual.position + inward_direction.normalized() * 9.0
	visual.fade_deeper_and_free(deeper_position, OVERFLOW_FADE_DURATION)


func _find_oldest_collected_visual() -> PocketCapturedBallVisual:
	var oldest: PocketCapturedBallVisual = null
	var oldest_serial: int = 2147483647
	for pocket_index_value in pocket_visuals.keys():
		for visual_value in _get_pocket_visuals(int(pocket_index_value)):
			var visual: PocketCapturedBallVisual = visual_value as PocketCapturedBallVisual
			if visual != null and is_instance_valid(visual) and visual.capture_serial < oldest_serial:
				oldest = visual
				oldest_serial = visual.capture_serial
	return oldest


func _on_capture_animation_finished(visual: PocketCapturedBallVisual) -> void:
	active_capture_visuals.erase(visual)
	if visual == null or not is_instance_valid(visual):
		return
	if not visual.persistent_collection_visual:
		visual.queue_free()


func _initialize_pocket_state() -> void:
	if table == null or table.pocket_system == null:
		return
	var pocket_count: int = table.pocket_system.get_pocket_positions().size()
	for pocket_index in range(pocket_count):
		_ensure_pocket_state(pocket_index)


func _ensure_pocket_state(pocket_index: int) -> void:
	if not pocket_visuals.has(pocket_index):
		pocket_visuals[pocket_index] = []
	if not total_captures_by_pocket.has(pocket_index):
		total_captures_by_pocket[pocket_index] = 0


func _get_pocket_visuals(pocket_index: int) -> Array:
	var value: Variant = pocket_visuals.get(pocket_index, [])
	if value is Array:
		return value as Array
	return []


func _cleanup_invalid_references() -> void:
	for visual in active_capture_visuals.duplicate():
		if visual == null or not is_instance_valid(visual):
			active_capture_visuals.erase(visual)
	for pocket_index_value in pocket_visuals.keys():
		var pocket_index: int = int(pocket_index_value)
		var cleaned: Array = []
		for visual_value in _get_pocket_visuals(pocket_index):
			var visual: PocketCapturedBallVisual = visual_value as PocketCapturedBallVisual
			if visual != null and is_instance_valid(visual) and not visual.is_queued_for_deletion():
				cleaned.append(visual)
		pocket_visuals[pocket_index] = cleaned


func _get_visible_collected_count() -> int:
	var count: int = 0
	for pocket_index_value in pocket_visuals.keys():
		count += _get_pocket_visuals(int(pocket_index_value)).size()
	return count


func _get_mode_persistence_policy() -> String:
	if table == null:
		return "unknown"
	return "roguelite_round" if table.is_roguelite_mode() else "passage_run"
