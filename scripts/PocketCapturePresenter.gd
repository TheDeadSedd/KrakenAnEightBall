extends Node2D
class_name PocketCapturePresenter

const CAPTURE_VISUAL_SCRIPT := preload("res://scripts/PocketCapturedBallVisual.gd")
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const REWIND_STATE_VERSION := 1
const MAX_VISIBLE_PER_POCKET := 8
const MAX_VISIBLE_TOTAL := 48
const APPROACH_DURATION := 0.11
const DROP_DURATION := 0.13
const UNDER_TABLE_ROLL_DURATION := 0.23
const TRANSIENT_FADE_DURATION := 0.10
const OVERFLOW_FADE_DURATION := 0.16
const REFLOW_DURATION := 0.18
const COLLECTION_ANCHOR_NAME := "CollectionAnchor"
const FALLBACK_ANCHOR_DISTANCE := 43.0
const CORNER_BASIN_HALF_EXTENTS := Vector2(23.0, 18.0)
const SIDE_BASIN_HALF_EXTENTS := Vector2(23.0, 22.0)
const BASIN_EDGE_PADDING := 1.0
const NOMINAL_SETTLED_RADIUS := 11.5
const INWARD_SLOT_PATTERN := [-0.70, -0.10, 0.35, 0.78, -0.48, 0.05, 0.50, 0.92]
const SIDE_SLOT_PATTERN := [-0.70, 0.22, -0.12, 0.68, 0.48, -0.52, 0.08, -0.25]
const DEBUG_ANCHOR_COLOR := Color(0.96, 0.76, 0.28, 0.95)
const DEBUG_BASIN_COLOR := Color(0.24, 0.92, 0.82, 0.78)
const DEBUG_MOUTH_COLOR := Color(0.96, 0.42, 0.30, 0.68)

@export var enabled: bool = true

var table: BilliardsTable
var pocket_visuals: Dictionary = {}
var total_captures_by_pocket: Dictionary = {}
var collection_layouts: Dictionary = {}
var active_capture_visuals: Array[PocketCapturedBallVisual] = []
var show_collection_anchor_debug: bool = false
var viewport_reflow_pending: bool = false
var capture_serial_counter: int = 0
var total_capture_events: int = 0
var proxies_removed_by_visible_cap: int = 0
var collection_layout_revision: int = 0
var collection_reflow_count: int = 0
var missing_collection_anchor_count: int = 0
var last_captured_pocket: int = -1
var last_captured_ball_identity: String = "None"
var last_capture_shot_id: int = -1
var rewind_generation: int = 0
var last_clear_reason: String = "initial"
var last_reflow_reason: String = "initial"


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	set_process(false)
	_initialize_pocket_state()
	_cache_collection_layouts()
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


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

	var should_persist: bool = ball != table.cue_ball
	var pocket_local_position: Vector2 = to_local(pocket_global_position)
	var layout: Dictionary = _get_collection_layout(pocket_index, pocket_global_position)
	var anchor_local_position: Vector2 = _get_layout_vector2(layout, "anchor_local", pocket_local_position)
	var inward_direction: Vector2 = _get_layout_vector2(layout, "inward_local", Vector2.DOWN).normalized()
	if inward_direction.is_zero_approx():
		inward_direction = Vector2.DOWN
	var is_corner: bool = bool(layout.get("is_corner", false))
	var variation: Dictionary = _get_capture_variation(
		pocket_index,
		pocket_total,
		ball.ball_number,
		should_persist,
		is_corner
	)
	var target_scale: Vector2 = Vector2(
		float(variation.get("scale", 1.0)) * 0.82,
		float(variation.get("scale", 1.0)) * 0.72
	)
	var target_rotation: float = float(variation.get("rotation", 0.0))
	var inward_offset: float = float(variation.get("inward_offset", 0.0))
	var lateral_offset: float = float(variation.get("lateral_offset", 0.0))
	var proposed_target: Vector2 = anchor_local_position + inward_direction * inward_offset
	proposed_target += inward_direction.orthogonal() * lateral_offset
	var target_position: Vector2 = _clamp_resting_position(
		proposed_target,
		layout,
		ball.radius,
		target_scale
	)

	var appearance_snapshot: Dictionary = _capture_appearance(ball)
	appearance_snapshot["captured_pocket_index"] = pocket_index
	appearance_snapshot["captured_pocket_center"] = pocket_global_position
	appearance_snapshot["captured_pocket_radius"] = pocket_radius
	appearance_snapshot["collection_inward_offset"] = inward_offset
	appearance_snapshot["collection_lateral_offset"] = lateral_offset
	appearance_snapshot["collection_capture_ordinal"] = pocket_total
	appearance_snapshot["collection_layout_revision"] = collection_layout_revision
	appearance_snapshot["collection_anchor_name"] = str(layout.get("pocket_name", "Pocket %s" % pocket_index))
	visual.configure(appearance_snapshot, pocket_index, capture_serial_counter)
	visual.capture_animation_finished.connect(_on_capture_animation_finished.bind(visual))

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
		_enforce_pocket_limit(pocket_index)
		_enforce_total_limit()


func react_to_pocket_streak(pocket_global_position: Vector2, multiplier: int) -> void:
	if not enabled or multiplier < 2:
		return
	var pocket_index: int = _find_nearest_pocket_index(pocket_global_position)
	if pocket_index < 0:
		return
	var pile: Array = _get_pocket_visuals(pocket_index)
	if pile.is_empty():
		return
	var layout: Dictionary = _get_collection_layout(pocket_index, pocket_global_position)
	var inward: Vector2 = _get_layout_vector2(layout, "inward_local", Vector2.DOWN).normalized()
	if inward.is_zero_approx():
		inward = Vector2.DOWN
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


func set_collection_anchor_debug_enabled(value: bool) -> void:
	if show_collection_anchor_debug == value:
		return
	show_collection_anchor_debug = value
	queue_redraw()


func reflow_collections(
	reason: String = "manual",
	animate: bool = true,
	refresh_anchors: bool = true
) -> void:
	if refresh_anchors:
		_cache_collection_layouts()
	_cleanup_invalid_references()
	for pocket_index_value in pocket_visuals.keys():
		var pocket_index: int = int(pocket_index_value)
		var layout: Dictionary = _get_collection_layout(pocket_index)
		for visual_value in _get_pocket_visuals(pocket_index):
			var visual: PocketCapturedBallVisual = visual_value as PocketCapturedBallVisual
			if visual == null or not is_instance_valid(visual) or not visual.settled:
				continue
			var target_position: Vector2 = _get_visual_resting_position(visual, layout)
			visual.reflow_settled(target_position, REFLOW_DURATION if animate else 0.0)
	collection_reflow_count += 1
	last_reflow_reason = reason
	queue_redraw()


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
		"collection_layout_revision": collection_layout_revision,
	}


func restore_rewind_state(state: Dictionary) -> void:
	clear_collections("shot_rewind")
	rewind_generation += 1
	_cache_collection_layouts()
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
		var restored_visual_state: Dictionary = visual_state.duplicate(true)
		var layout: Dictionary = _get_collection_layout(pocket_index)
		restored_visual_state["settled_position"] = _get_rewind_resting_position(
			restored_visual_state,
			layout
		)
		visual.restore_settled(restored_visual_state)
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
		"show_collection_anchor_debug": show_collection_anchor_debug,
		"collection_layout_revision": collection_layout_revision,
		"collection_reflow_count": collection_reflow_count,
		"last_reflow_reason": last_reflow_reason,
		"authored_collection_anchor_count": maxi(collection_layouts.size() - missing_collection_anchor_count, 0),
		"missing_collection_anchor_count": missing_collection_anchor_count,
		"collection_layouts": _get_collection_layout_debug_snapshot(),
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
	should_persist: bool,
	is_corner: bool
) -> Dictionary:
	var visual_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	visual_rng.seed = int(
		(pocket_index + 1) * 1000003
		+ pocket_total * 9176
		+ (ball_number + 17) * 131
	)
	if not should_persist:
		return {
			"inward_offset": visual_rng.randf_range(-3.0, 1.5),
			"lateral_offset": visual_rng.randf_range(-2.5, 2.5),
			"scale": visual_rng.randf_range(0.90, 0.97),
			"rotation": visual_rng.randf_range(-0.15, 0.15),
		}
	var slot: int = (pocket_total - 1) % MAX_VISIBLE_PER_POCKET
	var inward_amplitude: float = 8.5
	var sideways_amplitude: float = 5.2 if is_corner else 8.8
	var inward_jitter: float = visual_rng.randf_range(-1.3, 1.3)
	var sideways_jitter_limit: float = 0.8 if is_corner else 1.3
	return {
		"inward_offset": float(INWARD_SLOT_PATTERN[slot]) * inward_amplitude + inward_jitter,
		"lateral_offset": float(SIDE_SLOT_PATTERN[slot]) * sideways_amplitude + visual_rng.randf_range(-sideways_jitter_limit, sideways_jitter_limit),
		"scale": visual_rng.randf_range(0.92, 1.03),
		"rotation": visual_rng.randf_range(-0.18, 0.18),
	}


func _cache_collection_layouts() -> void:
	collection_layouts.clear()
	missing_collection_anchor_count = 0
	if table == null:
		collection_layout_revision += 1
		queue_redraw()
		return
	var pockets_root: Node = table.get_node_or_null("Pockets")
	if pockets_root == null:
		collection_layout_revision += 1
		queue_redraw()
		return
	var table_center_global: Vector2 = table.to_global(table.playfield_rect.get_center())
	var pocket_index: int = 0
	for child_value in pockets_root.get_children():
		var pocket_node: Node2D = child_value as Node2D
		if pocket_node == null:
			continue
		var collision_shape: CollisionShape2D = pocket_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape == null:
			continue
		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		if circle_shape == null:
			continue
		var mouth_global: Vector2 = collision_shape.global_position
		var center_direction: Vector2 = (table_center_global - mouth_global).normalized()
		if center_direction.is_zero_approx():
			center_direction = Vector2.DOWN
		var anchor: Marker2D = pocket_node.get_node_or_null(COLLECTION_ANCHOR_NAME) as Marker2D
		var anchor_authored: bool = anchor != null
		var anchor_global: Vector2 = anchor.global_position if anchor_authored else mouth_global + center_direction * FALLBACK_ANCHOR_DISTANCE
		if not anchor_authored:
			missing_collection_anchor_count += 1
		var mouth_local: Vector2 = to_local(mouth_global)
		var anchor_local: Vector2 = to_local(anchor_global)
		var inward_local: Vector2 = (anchor_local - mouth_local).normalized()
		if inward_local.is_zero_approx():
			inward_local = _global_direction_to_local(center_direction, mouth_global)
		var pocket_name: String = str(pocket_node.name)
		var is_corner: bool = not pocket_name.to_lower().contains("middle")
		collection_layouts[pocket_index] = {
			"pocket_index": pocket_index,
			"pocket_name": pocket_name,
			"is_corner": is_corner,
			"anchor_authored": anchor_authored,
			"mouth_local": mouth_local,
			"anchor_local": anchor_local,
			"inward_local": inward_local,
			"side_local": inward_local.orthogonal(),
			"basin_half_extents": CORNER_BASIN_HALF_EXTENTS if is_corner else SIDE_BASIN_HALF_EXTENTS,
		}
		pocket_index += 1
	collection_layout_revision += 1
	queue_redraw()


func _get_collection_layout(
	pocket_index: int,
	fallback_mouth_global: Vector2 = Vector2.ZERO
) -> Dictionary:
	var layout_value: Variant = collection_layouts.get(pocket_index, {})
	if layout_value is Dictionary and not (layout_value as Dictionary).is_empty():
		return layout_value as Dictionary
	var mouth_global: Vector2 = fallback_mouth_global
	if mouth_global == Vector2.ZERO and table != null and table.pocket_system != null:
		var positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
		if pocket_index >= 0 and pocket_index < positions.size():
			mouth_global = positions[pocket_index]
	var inward_local: Vector2 = _get_fallback_inward_direction(mouth_global)
	var mouth_local: Vector2 = to_local(mouth_global)
	return {
		"pocket_index": pocket_index,
		"pocket_name": "Pocket %s" % pocket_index,
		"is_corner": true,
		"anchor_authored": false,
		"mouth_local": mouth_local,
		"anchor_local": mouth_local + inward_local * FALLBACK_ANCHOR_DISTANCE,
		"inward_local": inward_local,
		"side_local": inward_local.orthogonal(),
		"basin_half_extents": CORNER_BASIN_HALF_EXTENTS,
	}


func _get_fallback_inward_direction(pocket_global_position: Vector2) -> Vector2:
	if table == null:
		return Vector2.DOWN
	var table_center_global: Vector2 = table.to_global(table.playfield_rect.get_center())
	var global_direction: Vector2 = (table_center_global - pocket_global_position).normalized()
	if global_direction.is_zero_approx():
		global_direction = Vector2.DOWN
	return _global_direction_to_local(global_direction, pocket_global_position)


func _global_direction_to_local(global_direction: Vector2, global_origin: Vector2) -> Vector2:
	var local_direction: Vector2 = to_local(global_origin + global_direction) - to_local(global_origin)
	if local_direction.is_zero_approx():
		return Vector2.DOWN
	return local_direction.normalized()


func _get_layout_vector2(layout: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = layout.get(key, fallback)
	return value if value is Vector2 else fallback


func _get_safe_center_extents(layout: Dictionary, visual_radius: float) -> Vector2:
	var basin_half_extents: Vector2 = _get_layout_vector2(
		layout,
		"basin_half_extents",
		CORNER_BASIN_HALF_EXTENTS
	)
	return Vector2(
		maxf(basin_half_extents.x - visual_radius - BASIN_EDGE_PADDING, 1.0),
		maxf(basin_half_extents.y - visual_radius - BASIN_EDGE_PADDING, 1.0)
	)


func _clamp_resting_position(
	proposed_position: Vector2,
	layout: Dictionary,
	base_radius: float,
	target_scale: Vector2
) -> Vector2:
	var anchor_local: Vector2 = _get_layout_vector2(layout, "anchor_local", proposed_position)
	var inward_local: Vector2 = _get_layout_vector2(layout, "inward_local", Vector2.DOWN).normalized()
	if inward_local.is_zero_approx():
		inward_local = Vector2.DOWN
	var side_local: Vector2 = inward_local.orthogonal()
	var visual_radius: float = maxf(base_radius, 1.0) * maxf(absf(target_scale.x), absf(target_scale.y))
	var safe_extents: Vector2 = _get_safe_center_extents(layout, visual_radius)
	var offset: Vector2 = proposed_position - anchor_local
	var inward_amount: float = offset.dot(inward_local)
	var side_amount: float = offset.dot(side_local)
	var normalized_distance_squared: float = (
		(inward_amount * inward_amount) / (safe_extents.x * safe_extents.x)
		+ (side_amount * side_amount) / (safe_extents.y * safe_extents.y)
	)
	if normalized_distance_squared > 1.0:
		var clamp_scale: float = 1.0 / sqrt(normalized_distance_squared)
		inward_amount *= clamp_scale
		side_amount *= clamp_scale
	return anchor_local + inward_local * inward_amount + side_local * side_amount


func _get_visual_resting_position(
	visual: PocketCapturedBallVisual,
	layout: Dictionary
) -> Vector2:
	var anchor_local: Vector2 = _get_layout_vector2(layout, "anchor_local", visual.settled_position)
	var inward_local: Vector2 = _get_layout_vector2(layout, "inward_local", Vector2.DOWN).normalized()
	if inward_local.is_zero_approx():
		inward_local = Vector2.DOWN
	var inward_offset: float = float(visual.appearance.get("collection_inward_offset", 0.0))
	var lateral_offset: float = float(visual.appearance.get("collection_lateral_offset", 0.0))
	var proposed_position: Vector2 = anchor_local + inward_local * inward_offset
	proposed_position += inward_local.orthogonal() * lateral_offset
	return _clamp_resting_position(
		proposed_position,
		layout,
		float(visual.appearance.get("radius", 14.0)),
		visual.settled_scale
	)


func _get_rewind_resting_position(state: Dictionary, layout: Dictionary) -> Vector2:
	var appearance_value: Variant = state.get("appearance", {})
	var appearance: Dictionary = {}
	if appearance_value is Dictionary:
		appearance = appearance_value as Dictionary
	var scale_value: Variant = state.get("settled_scale", Vector2(0.82, 0.72))
	var target_scale: Vector2 = scale_value if scale_value is Vector2 else Vector2(0.82, 0.72)
	var stored_position_value: Variant = state.get("settled_position", Vector2.ZERO)
	var stored_position: Vector2 = stored_position_value if stored_position_value is Vector2 else Vector2.ZERO
	var proposed_position: Vector2 = stored_position
	if appearance.has("collection_inward_offset") and appearance.has("collection_lateral_offset"):
		var anchor_local: Vector2 = _get_layout_vector2(layout, "anchor_local", stored_position)
		var inward_local: Vector2 = _get_layout_vector2(layout, "inward_local", Vector2.DOWN).normalized()
		if inward_local.is_zero_approx():
			inward_local = Vector2.DOWN
		proposed_position = anchor_local + inward_local * float(appearance.get("collection_inward_offset", 0.0))
		proposed_position += inward_local.orthogonal() * float(appearance.get("collection_lateral_offset", 0.0))
	return _clamp_resting_position(
		proposed_position,
		layout,
		float(appearance.get("radius", 14.0)),
		target_scale
	)


func _get_collection_layout_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for pocket_index_value in collection_layouts.keys():
		var pocket_index: int = int(pocket_index_value)
		var layout: Dictionary = _get_collection_layout(pocket_index)
		var mouth_local: Vector2 = _get_layout_vector2(layout, "mouth_local", Vector2.ZERO)
		var anchor_local: Vector2 = _get_layout_vector2(layout, "anchor_local", mouth_local)
		snapshot[pocket_index] = {
			"name": str(layout.get("pocket_name", "Pocket %s" % pocket_index)),
			"is_corner": bool(layout.get("is_corner", false)),
			"anchor_authored": bool(layout.get("anchor_authored", false)),
			"mouth_local": mouth_local,
			"anchor_local": anchor_local,
			"anchor_offset": anchor_local - mouth_local,
			"inward_local": _get_layout_vector2(layout, "inward_local", Vector2.DOWN),
			"basin_half_extents": _get_layout_vector2(layout, "basin_half_extents", CORNER_BASIN_HALF_EXTENTS),
			"safe_center_extents": _get_safe_center_extents(layout, NOMINAL_SETTLED_RADIUS),
		}
	return snapshot


func _on_viewport_size_changed() -> void:
	if viewport_reflow_pending:
		return
	viewport_reflow_pending = true
	call_deferred("_apply_viewport_reflow")


func _apply_viewport_reflow() -> void:
	viewport_reflow_pending = false
	if not is_inside_tree():
		return
	reflow_collections("viewport_resize", false, true)


func _draw() -> void:
	if not show_collection_anchor_debug:
		return
	var pocket_indices: Array = collection_layouts.keys()
	pocket_indices.sort()
	for pocket_index_value in pocket_indices:
		var pocket_index: int = int(pocket_index_value)
		var layout: Dictionary = _get_collection_layout(pocket_index)
		var mouth_local: Vector2 = _get_layout_vector2(layout, "mouth_local", Vector2.ZERO)
		var anchor_local: Vector2 = _get_layout_vector2(layout, "anchor_local", mouth_local)
		var inward_local: Vector2 = _get_layout_vector2(layout, "inward_local", Vector2.DOWN).normalized()
		if inward_local.is_zero_approx():
			inward_local = Vector2.DOWN
		var side_local: Vector2 = inward_local.orthogonal()
		var safe_extents: Vector2 = _get_safe_center_extents(layout, NOMINAL_SETTLED_RADIUS)
		var basin_points: PackedVector2Array = _make_oriented_ellipse_points(
			anchor_local,
			inward_local,
			side_local,
			safe_extents
		)
		var basin_fill: Color = DEBUG_BASIN_COLOR
		basin_fill.a = 0.10
		draw_colored_polygon(basin_points, basin_fill)
		var basin_outline: PackedVector2Array = basin_points.duplicate()
		basin_outline.append(basin_points[0])
		draw_polyline(basin_outline, DEBUG_BASIN_COLOR, 1.5, true)
		draw_line(mouth_local, anchor_local, DEBUG_MOUTH_COLOR, 1.2, true)
		draw_circle(mouth_local, 3.0, DEBUG_MOUTH_COLOR)
		var anchor_color: Color = DEBUG_ANCHOR_COLOR if bool(layout.get("anchor_authored", false)) else Color(1.0, 0.25, 0.20, 0.95)
		draw_circle(anchor_local, 4.0, anchor_color)
		var arrow_end: Vector2 = anchor_local + inward_local * 25.0
		draw_line(anchor_local, arrow_end, anchor_color, 2.0, true)
		draw_line(arrow_end, arrow_end - inward_local * 6.0 + side_local * 3.5, anchor_color, 1.6, true)
		draw_line(arrow_end, arrow_end - inward_local * 6.0 - side_local * 3.5, anchor_color, 1.6, true)
		var label_position: Vector2 = anchor_local + side_local * (safe_extents.y + 10.0) - inward_local * 5.0
		var label_text: String = "%s: %s" % [pocket_index, str(layout.get("pocket_name", "Pocket"))]
		draw_string(UI_FONT, label_position, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, anchor_color)


func _make_oriented_ellipse_points(
	center: Vector2,
	inward_axis: Vector2,
	side_axis: Vector2,
	half_extents: Vector2
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segment_count: int = 32
	for segment_index in range(segment_count):
		var angle: float = TAU * float(segment_index) / float(segment_count)
		points.append(
			center
			+ inward_axis * cos(angle) * half_extents.x
			+ side_axis * sin(angle) * half_extents.y
		)
	return points


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


func _enforce_pocket_limit(pocket_index: int) -> void:
	var pile: Array = _get_pocket_visuals(pocket_index)
	while pile.size() > MAX_VISIBLE_PER_POCKET:
		var oldest: PocketCapturedBallVisual = pile.pop_front() as PocketCapturedBallVisual
		_retire_visual_for_cap(oldest)
	pocket_visuals[pocket_index] = pile


func _enforce_total_limit() -> void:
	while _get_visible_collected_count() > MAX_VISIBLE_TOTAL:
		var oldest: PocketCapturedBallVisual = _find_oldest_collected_visual()
		if oldest == null:
			return
		var old_pocket_index: int = oldest.pocket_index
		var pile: Array = _get_pocket_visuals(old_pocket_index)
		pile.erase(oldest)
		pocket_visuals[old_pocket_index] = pile
		_retire_visual_for_cap(oldest)


func _retire_visual_for_cap(visual: PocketCapturedBallVisual) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	active_capture_visuals.erase(visual)
	proxies_removed_by_visible_cap += 1
	var layout: Dictionary = _get_collection_layout(visual.pocket_index)
	var inward_direction: Vector2 = _get_layout_vector2(layout, "inward_local", Vector2.DOWN).normalized()
	if inward_direction.is_zero_approx():
		inward_direction = Vector2.DOWN
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
