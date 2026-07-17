@tool
extends Node2D
class_name CueController

# Owns the cue sprite presentation and cue-specific grab-zone hit testing.
# Table.gd remains responsible for shot state, shot velocity, and aim prediction.
const CUE_TEXTURE := preload("res://assets/table_art/tentacle_pool_cue.png")
const CUE_GAP := 22.0
const CUE_MIN_PULLBACK := 8.0
const CUE_MAX_PULLBACK := 78.0
const CUE_TEXTURE_REGION := Rect2(88, 339, 1356, 310)
const CUE_SPRITE_LENGTH := 230.0
const CUE_IDLE_SWAY_AMOUNT := 0.02
const CUE_IDLE_SWAY_SPEED := 2.2
const CUE_PULLBACK_LERP_SPEED := 14.0
const CUE_STRIKE_TIME := 0.055
const CUE_RECOIL_TIME := 0.08
const CUE_SETTLE_TIME := 0.14
const CUE_STRIKE_FORWARD_PULLBACK_LOW := 2.0
const CUE_STRIKE_FORWARD_PULLBACK_HIGH := -34.0
const CUE_RECOIL_PULLBACK_RATIO := 0.34
const CUE_GRAB_BACK_PADDING_X := 34.0
const CUE_GRAB_FRONT_PADDING_X := 10.0
const CUE_GRAB_PADDING_Y := 28.0
const DEFAULT_CUE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const BLACKWOOD_CUE_MODULATE := Color(0.56, 0.42, 0.30, 1.0)
const BRASS_TIP_COLOR := Color(1.0, 0.74, 0.28, 0.84)
const WAYFINDER_WRAP_COLOR := Color(0.16, 0.86, 0.82, 0.62)
const BONE_FERRULE_COLOR := Color(0.92, 0.86, 0.70, 0.78)
const LUCKY_CHALK_COLOR := Color(1.0, 0.92, 0.36, 0.86)
const SLOT_BODY := "body"
const SLOT_TIP := "tip"
const SLOT_GRIP := "grip"
const SLOT_FERRULE := "ferrule"
const SLOT_CHALK := "chalk"
const PART_WEATHERED_BODY := "weathered_cue_body"
const PART_BLACKWOOD_BODY := "blackwood_cue"
const PART_PLAIN_TIP := "plain_tip"
const PART_BRASS_TIP := "brass_tip"
const PART_SAILCLOTH_GRIP := "sailcloth_grip"
const PART_WAYFINDER_WRAP := "wayfinder_wrap"
const PART_PLAIN_FERRULE := "plain_ferrule"
const PART_BONE_FERRULE := "bone_ferrule"
const PART_PLAIN_CHALK := "plain_chalk"
const PART_LUCKY_CHALK := "lucky_chalk"

@onready var cue_sprite: Sprite2D = $CueSprite

var cue_visual_pullback := 0.0
var release_animation_timer := 0.0
var release_start_pullback := 0.0
var release_power_ratio := 0.0
var release_position := Vector2.ZERO
var release_rotation := 0.0
var cue_loadout_snapshot: Dictionary = {}
var equipped_cue_part_ids: Dictionary = {}
var tip_accent_polygon: Polygon2D
var grip_accent_polygon: Polygon2D
var ferrule_accent_polygon: Polygon2D
var chalk_glint_polygon: Polygon2D


func setup() -> void:
	cue_sprite.texture = CUE_TEXTURE
	cue_sprite.centered = false
	cue_sprite.region_enabled = true
	cue_sprite.region_rect = CUE_TEXTURE_REGION
	var cue_scale: float = CUE_SPRITE_LENGTH / CUE_TEXTURE_REGION.size.x
	cue_sprite.scale = Vector2.ONE * cue_scale
	cue_sprite.z_index = 12
	_cache_equipped_cue_part_ids()
	if not Engine.is_editor_hint():
		_ensure_cue_accent_nodes()
	_apply_cue_loadout_visuals()


func update_cue(
	cue_ball_value: Variant,
	can_shoot: bool,
	is_dragging: bool,
	shot_drag_vector: Vector2,
	max_drag_distance: float,
	game_over: bool,
	delta: float
) -> void:
	# Keep this boundary tolerant of a stale Object long enough to hide safely.
	# Table still owns authoritative cue validation before calling this method.
	if not is_instance_valid(cue_ball_value) or not cue_ball_value is Ball:
		clear_cue()
		return
	var cue_ball: Ball = cue_ball_value as Ball
	if cue_ball.is_queued_for_deletion() or not cue_ball.visible or not cue_ball.gameplay_enabled or game_over:
		clear_cue()
		return

	var should_show: bool = is_dragging or release_animation_timer > 0.0
	if not should_show and not can_shoot:
		visible = false
		return

	_update_cue_transform(cue_ball, can_shoot, is_dragging, shot_drag_vector, max_drag_distance, delta)


func clear_cue() -> void:
	release_animation_timer = 0.0
	cue_visual_pullback = 0.0
	visible = false


func is_point_over_grab_zone(world_position: Vector2, cue_ball: Ball, max_drag_distance: float) -> bool:
	if visible:
		var visible_cue_position: Vector2 = global_transform.affine_inverse() * world_position
		if _get_cue_grab_rect(cue_visual_pullback).has_point(visible_cue_position):
			return true

	var drag_vector: Vector2 = _get_drag_vector(cue_ball.global_position, world_position, max_drag_distance)
	var aim_direction: Vector2 = drag_vector.normalized()
	if aim_direction == Vector2.ZERO:
		return false

	var cue_transform := Transform2D(aim_direction.angle(), cue_ball.global_position)
	var local_position: Vector2 = cue_transform.affine_inverse() * world_position
	var pullback: float = get_pullback_for_drag_vector(drag_vector, max_drag_distance)
	return _get_cue_grab_rect(pullback).has_point(local_position)


func get_pullback_for_drag_vector(drag_vector: Vector2, max_drag_distance: float) -> float:
	var power_ratio: float = clamp(drag_vector.length() / max_drag_distance, 0.0, 1.0)
	return lerp(CUE_MIN_PULLBACK, CUE_MAX_PULLBACK, power_ratio)


func begin_recoil(anchor_position: Vector2, rotation_angle: float, start_pullback: float) -> void:
	release_position = anchor_position
	release_rotation = rotation_angle
	release_start_pullback = start_pullback
	release_power_ratio = _get_power_ratio_from_pullback(start_pullback)
	release_animation_timer = _get_release_animation_total_time()


func stop_recoil() -> void:
	release_animation_timer = 0.0


func get_rotation_angle() -> float:
	return rotation


func set_cue_loadout_snapshot(snapshot: Dictionary) -> void:
	cue_loadout_snapshot = snapshot.duplicate(true)
	_cache_equipped_cue_part_ids()
	_ensure_cue_accent_nodes()
	_apply_cue_loadout_visuals()


func _update_cue_transform(
	cue_ball: Ball,
	can_shoot: bool,
	is_dragging: bool,
	shot_drag_vector: Vector2,
	max_drag_distance: float,
	delta: float
) -> void:
	var anchor_position: Vector2 = cue_ball.global_position
	var rotation_angle := 0.0
	var target_pullback := CUE_MIN_PULLBACK
	var should_show := true
	if is_dragging:
		var aim_direction: Vector2 = shot_drag_vector.normalized()
		rotation_angle = aim_direction.angle() if aim_direction != Vector2.ZERO else rotation
		target_pullback = get_pullback_for_drag_vector(shot_drag_vector, max_drag_distance)
	elif release_animation_timer > 0.0:
		anchor_position = release_position
		rotation_angle = release_rotation
		release_animation_timer = max(release_animation_timer - delta, 0.0)
		var release_elapsed: float = _get_release_animation_total_time() - release_animation_timer
		target_pullback = _get_release_animation_pullback(release_elapsed)
		_apply_cue_transform(anchor_position, rotation_angle, target_pullback, should_show, delta, true)
		return
	else:
		var mouse_direction: Vector2 = (cue_ball.global_position - get_global_mouse_position()).normalized()
		rotation_angle = mouse_direction.angle() if mouse_direction != Vector2.ZERO else rotation
		target_pullback = 0.0
		should_show = can_shoot

	_apply_cue_transform(anchor_position, rotation_angle, target_pullback, should_show, delta)


func _apply_cue_transform(
	anchor_position: Vector2,
	rotation_angle: float,
	target_pullback: float,
	should_show: bool,
	delta: float,
	snap_pullback: bool = false
) -> void:
	var idle_sway: float = sin(Time.get_ticks_msec() * 0.001 * CUE_IDLE_SWAY_SPEED) * CUE_IDLE_SWAY_AMOUNT
	if snap_pullback:
		cue_visual_pullback = target_pullback
	else:
		cue_visual_pullback = lerp(cue_visual_pullback, target_pullback, clamp(delta * CUE_PULLBACK_LERP_SPEED, 0.0, 1.0))
	global_position = anchor_position
	rotation = rotation_angle + idle_sway
	_position_cue_sprite(cue_visual_pullback)
	visible = should_show


func _get_release_animation_pullback(elapsed: float) -> float:
	var strike_end: float = CUE_STRIKE_TIME
	var recoil_end: float = CUE_STRIKE_TIME + CUE_RECOIL_TIME
	var forward_pullback: float = lerp(
		CUE_STRIKE_FORWARD_PULLBACK_LOW,
		CUE_STRIKE_FORWARD_PULLBACK_HIGH,
		release_power_ratio
	)
	var recoil_pullback: float = release_start_pullback * CUE_RECOIL_PULLBACK_RATIO

	if elapsed <= strike_end:
		var strike_ratio: float = clamp(elapsed / CUE_STRIKE_TIME, 0.0, 1.0)
		return lerp(release_start_pullback, forward_pullback, _ease_out_cubic(strike_ratio))

	if elapsed <= recoil_end:
		var recoil_ratio: float = clamp((elapsed - strike_end) / CUE_RECOIL_TIME, 0.0, 1.0)
		return lerp(forward_pullback, recoil_pullback, _ease_out_cubic(recoil_ratio))

	var settle_ratio: float = clamp((elapsed - recoil_end) / CUE_SETTLE_TIME, 0.0, 1.0)
	return lerp(recoil_pullback, 0.0, smoothstep(0.0, 1.0, settle_ratio))


func _get_release_animation_total_time() -> float:
	return CUE_STRIKE_TIME + CUE_RECOIL_TIME + CUE_SETTLE_TIME


func _get_power_ratio_from_pullback(pullback: float) -> float:
	return clamp((pullback - CUE_MIN_PULLBACK) / (CUE_MAX_PULLBACK - CUE_MIN_PULLBACK), 0.0, 1.0)


func _ease_out_cubic(ratio: float) -> float:
	return 1.0 - pow(1.0 - ratio, 3.0)


func _get_drag_vector(cue_ball_position: Vector2, mouse_position: Vector2, max_drag_distance: float) -> Vector2:
	var drag_vector: Vector2 = cue_ball_position - mouse_position
	return drag_vector.limit_length(max_drag_distance)


func _get_cue_grab_rect(pullback: float) -> Rect2:
	var cue_scale: float = cue_sprite.scale.x
	var cue_width: float = CUE_TEXTURE_REGION.size.y * cue_scale
	var cue_length: float = CUE_TEXTURE_REGION.size.x * cue_scale
	return Rect2(
		-(CUE_GAP + pullback + cue_length) - CUE_GRAB_BACK_PADDING_X,
		-cue_width * 0.5 - CUE_GRAB_PADDING_Y,
		cue_length + CUE_GRAB_BACK_PADDING_X + CUE_GRAB_FRONT_PADDING_X,
		cue_width + CUE_GRAB_PADDING_Y * 2.0
	)


func _position_cue_sprite(pullback: float) -> void:
	var cue_scale: float = cue_sprite.scale.x
	var cue_width: float = CUE_TEXTURE_REGION.size.y * cue_scale
	var cue_length: float = CUE_TEXTURE_REGION.size.x * cue_scale
	cue_sprite.position = Vector2(
		-(CUE_GAP + pullback + cue_length),
		-cue_width * 0.5
	)
	_update_cue_accent_geometry(cue_length, cue_width)


func _cache_equipped_cue_part_ids() -> void:
	equipped_cue_part_ids = {
		SLOT_BODY: PART_WEATHERED_BODY,
		SLOT_TIP: PART_PLAIN_TIP,
		SLOT_GRIP: PART_SAILCLOTH_GRIP,
		SLOT_FERRULE: PART_PLAIN_FERRULE,
		SLOT_CHALK: PART_PLAIN_CHALK,
	}

	var by_slot_value: Variant = cue_loadout_snapshot.get("equipped_loadout_by_slot", {})
	if by_slot_value is Dictionary:
		var by_slot: Dictionary = by_slot_value as Dictionary
		for slot_type_value in by_slot.keys():
			var slot_type := str(slot_type_value)
			var entry_value: Variant = by_slot.get(slot_type_value, {})
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value as Dictionary
			var part_id := str(entry.get("part_id", ""))
			if not part_id.is_empty():
				equipped_cue_part_ids[slot_type] = part_id
		return

	var loadout_value: Variant = cue_loadout_snapshot.get("equipped_loadout", [])
	if not loadout_value is Array:
		return
	for entry_value in loadout_value:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var slot_type := str(entry.get("slot_type", ""))
		var part_id := str(entry.get("part_id", ""))
		if slot_type.is_empty() or part_id.is_empty():
			continue
		equipped_cue_part_ids[slot_type] = part_id


func _ensure_cue_accent_nodes() -> void:
	if tip_accent_polygon == null:
		tip_accent_polygon = _make_cue_accent_polygon("TipAccent", BRASS_TIP_COLOR)
	if grip_accent_polygon == null:
		grip_accent_polygon = _make_cue_accent_polygon("GripAccent", WAYFINDER_WRAP_COLOR)
	if ferrule_accent_polygon == null:
		ferrule_accent_polygon = _make_cue_accent_polygon("FerruleAccent", BONE_FERRULE_COLOR)
	if chalk_glint_polygon == null:
		chalk_glint_polygon = _make_cue_accent_polygon("ChalkGlint", LUCKY_CHALK_COLOR)


func _make_cue_accent_polygon(node_name: String, accent_color: Color) -> Polygon2D:
	var polygon_node := Polygon2D.new()
	polygon_node.name = node_name
	polygon_node.color = accent_color
	polygon_node.z_index = 13
	polygon_node.visible = false
	add_child(polygon_node)
	return polygon_node


func _apply_cue_loadout_visuals() -> void:
	if cue_sprite != null:
		var body_id := _get_equipped_cue_part_id(SLOT_BODY, PART_WEATHERED_BODY)
		cue_sprite.modulate = BLACKWOOD_CUE_MODULATE if body_id == PART_BLACKWOOD_BODY else DEFAULT_CUE_MODULATE

	if tip_accent_polygon != null:
		tip_accent_polygon.visible = _get_equipped_cue_part_id(SLOT_TIP, PART_PLAIN_TIP) == PART_BRASS_TIP
	if grip_accent_polygon != null:
		grip_accent_polygon.visible = _get_equipped_cue_part_id(SLOT_GRIP, PART_SAILCLOTH_GRIP) == PART_WAYFINDER_WRAP
	if ferrule_accent_polygon != null:
		ferrule_accent_polygon.visible = _get_equipped_cue_part_id(SLOT_FERRULE, PART_PLAIN_FERRULE) == PART_BONE_FERRULE
	if chalk_glint_polygon != null:
		chalk_glint_polygon.visible = _get_equipped_cue_part_id(SLOT_CHALK, PART_PLAIN_CHALK) == PART_LUCKY_CHALK

	_update_cue_accent_geometry()


func _get_equipped_cue_part_id(slot_type: String, fallback: String) -> String:
	return str(equipped_cue_part_ids.get(slot_type, fallback))


func _update_cue_accent_geometry(cue_length: float = -1.0, cue_width: float = -1.0) -> void:
	if cue_sprite == null:
		return
	if tip_accent_polygon == null or grip_accent_polygon == null or ferrule_accent_polygon == null or chalk_glint_polygon == null:
		return
	if cue_length <= 0.0 or cue_width <= 0.0:
		var cue_scale: float = cue_sprite.scale.x
		cue_width = CUE_TEXTURE_REGION.size.y * cue_scale
		cue_length = CUE_TEXTURE_REGION.size.x * cue_scale

	var left_x := cue_sprite.position.x
	var right_x := cue_sprite.position.x + cue_length
	var top_y := cue_sprite.position.y
	var center_y := top_y + cue_width * 0.5
	var core_top := center_y - cue_width * 0.18
	var core_height := cue_width * 0.36

	_set_rect_polygon(tip_accent_polygon, Rect2(right_x - 8.0, core_top, 5.0, core_height))
	_set_rect_polygon(ferrule_accent_polygon, Rect2(right_x - 21.0, core_top - 2.0, 9.0, core_height + 4.0))
	_set_rect_polygon(grip_accent_polygon, Rect2(left_x + cue_length * 0.34, top_y + cue_width * 0.24, 42.0, cue_width * 0.52))

	var glint_center := Vector2(right_x - 16.0, center_y - cue_width * 0.24)
	var glint_radius := 5.0
	chalk_glint_polygon.polygon = PackedVector2Array([
		glint_center + Vector2(0.0, -glint_radius),
		glint_center + Vector2(glint_radius, 0.0),
		glint_center + Vector2(0.0, glint_radius),
		glint_center + Vector2(-glint_radius, 0.0),
	])


func _set_rect_polygon(polygon_node: Polygon2D, rect: Rect2) -> void:
	if polygon_node == null:
		return
	polygon_node.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	])
