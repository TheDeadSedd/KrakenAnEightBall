extends Node2D
class_name PocketCapturedBallVisual

signal capture_animation_finished

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const DEFAULT_RADIUS := 14.0
const DEFAULT_SETTLED_SCALE := Vector2(0.92, 0.92)
const DROP_COMPRESSED_SCALE := Vector2(0.80, 0.76)
const SETTLED_TINT := Color(0.88, 0.88, 0.88, 1.0)
const DROP_TINT := Color(0.72, 0.74, 0.76, 0.98)

var appearance: Dictionary = {}
var pocket_index: int = -1
var capture_serial: int = 0
var persistent_collection_visual: bool = true
var settled: bool = false
var settled_position: Vector2 = Vector2.ZERO
var settled_scale: Vector2 = Vector2.ONE
var settled_rotation: float = 0.0
var settled_modulate: Color = SETTLED_TINT

var capture_tween: Tween
var reaction_tween: Tween
var depth_tween: Tween


func configure(snapshot: Dictionary, captured_pocket_index: int, serial: int) -> void:
	appearance = snapshot.duplicate(true)
	pocket_index = captured_pocket_index
	capture_serial = serial
	set_process(false)
	queue_redraw()


func play_capture(
	pocket_position: Vector2,
	inward_direction: Vector2,
	target_position: Vector2,
	target_scale: Vector2,
	target_rotation: float,
	should_persist: bool,
	approach_duration: float,
	drop_duration: float,
	roll_duration: float,
	departure_duration: float
) -> void:
	cancel_animation()
	persistent_collection_visual = should_persist
	settled = false
	settled_position = target_position
	settled_scale = target_scale
	settled_rotation = target_rotation

	var safe_inward: Vector2 = inward_direction.normalized()
	if safe_inward.is_zero_approx():
		safe_inward = Vector2.DOWN
	var drop_position: Vector2 = pocket_position + safe_inward * 8.0
	var approach_rotation: float = lerpf(rotation, target_rotation * 0.35, 0.55)

	capture_tween = create_tween()
	capture_tween.tween_property(self, "position", pocket_position, approach_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	capture_tween.parallel().tween_property(self, "rotation", approach_rotation, approach_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	capture_tween.tween_property(self, "position", drop_position, drop_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	capture_tween.parallel().tween_property(self, "scale", DROP_COMPRESSED_SCALE, drop_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	capture_tween.parallel().tween_property(self, "modulate", DROP_TINT, drop_duration)
	capture_tween.tween_property(self, "position", target_position, roll_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	capture_tween.parallel().tween_property(self, "scale", target_scale, roll_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	capture_tween.parallel().tween_property(self, "rotation", target_rotation, roll_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	capture_tween.parallel().tween_property(self, "modulate", settled_modulate, roll_duration)
	if should_persist:
		capture_tween.tween_callback(_finish_persistent_capture)
	else:
		var hidden_tint: Color = SETTLED_TINT
		hidden_tint.a = 0.0
		capture_tween.tween_property(self, "position", target_position + safe_inward * 8.0, departure_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		capture_tween.parallel().tween_property(self, "scale", target_scale * 0.72, departure_duration)
		capture_tween.parallel().tween_property(self, "modulate", hidden_tint, departure_duration)
		capture_tween.tween_callback(_finish_transient_capture)


func restore_settled(state: Dictionary) -> void:
	cancel_animation()
	appearance = _get_dictionary(state, "appearance")
	pocket_index = int(state.get("pocket_index", -1))
	capture_serial = int(state.get("capture_serial", 0))
	persistent_collection_visual = true
	settled_position = _get_vector2(state, "settled_position", Vector2.ZERO)
	settled_scale = _get_vector2(state, "settled_scale", DEFAULT_SETTLED_SCALE)
	settled_rotation = float(state.get("settled_rotation", 0.0))
	var modulate_value: Variant = state.get("settled_modulate", SETTLED_TINT)
	settled_modulate = modulate_value if modulate_value is Color else SETTLED_TINT
	position = settled_position
	scale = settled_scale
	rotation = settled_rotation
	modulate = settled_modulate
	settled = true
	set_process(false)
	queue_redraw()


func get_rewind_state() -> Dictionary:
	return {
		"appearance": appearance.duplicate(true),
		"pocket_index": pocket_index,
		"capture_serial": capture_serial,
		"settled_position": settled_position,
		"settled_scale": settled_scale,
		"settled_rotation": settled_rotation,
		"settled_modulate": settled_modulate,
	}


func play_collection_reaction(offset: Vector2, scale_factor: float, duration: float) -> void:
	if not settled:
		return
	if reaction_tween != null and reaction_tween.is_running():
		reaction_tween.kill()
	position = settled_position
	scale = settled_scale
	rotation = settled_rotation
	reaction_tween = create_tween()
	var reaction_time: float = maxf(duration * 0.42, 0.04)
	var return_time: float = maxf(duration - reaction_time, 0.06)
	reaction_tween.tween_property(self, "position", settled_position + offset, reaction_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reaction_tween.parallel().tween_property(self, "scale", settled_scale * scale_factor, reaction_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reaction_tween.tween_property(self, "position", settled_position, return_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reaction_tween.parallel().tween_property(self, "scale", settled_scale, return_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func reflow_settled(target_position: Vector2, duration: float = 0.18) -> void:
	settled_position = target_position
	if not settled:
		return
	if reaction_tween != null and reaction_tween.is_running():
		reaction_tween.kill()
	reaction_tween = null
	if duration <= 0.0:
		position = settled_position
		return
	reaction_tween = create_tween()
	reaction_tween.tween_property(self, "position", settled_position, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func apply_collection_depth_tint(tint: Color, duration: float = 0.14) -> void:
	settled_modulate = tint
	if not settled:
		return
	if depth_tween != null and depth_tween.is_running():
		depth_tween.kill()
	depth_tween = null
	if duration <= 0.0:
		modulate = settled_modulate
		return
	depth_tween = create_tween()
	depth_tween.tween_property(self, "modulate", settled_modulate, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func fade_deeper_and_free(deeper_position: Vector2, duration: float) -> void:
	cancel_animation()
	settled = false
	var hidden_tint: Color = modulate
	hidden_tint.a = 0.0
	capture_tween = create_tween()
	capture_tween.tween_property(self, "position", deeper_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	capture_tween.parallel().tween_property(self, "scale", scale * 0.68, duration)
	capture_tween.parallel().tween_property(self, "modulate", hidden_tint, duration)
	capture_tween.tween_callback(Callable(self, "queue_free"))


func cancel_animation() -> void:
	if capture_tween != null and capture_tween.is_running():
		capture_tween.kill()
	if reaction_tween != null and reaction_tween.is_running():
		reaction_tween.kill()
	if depth_tween != null and depth_tween.is_running():
		depth_tween.kill()
	capture_tween = null
	reaction_tween = null
	depth_tween = null


func _finish_persistent_capture() -> void:
	position = settled_position
	scale = settled_scale
	rotation = settled_rotation
	modulate = settled_modulate
	settled = true
	capture_tween = null
	capture_animation_finished.emit()


func _finish_transient_capture() -> void:
	capture_tween = null
	capture_animation_finished.emit()


func _draw() -> void:
	var radius: float = maxf(float(appearance.get("radius", DEFAULT_RADIUS)), 2.0)
	var display_color_value: Variant = appearance.get("display_color", Color("d7b347"))
	var display_color: Color = display_color_value if display_color_value is Color else Color("d7b347")
	var identity: String = str(appearance.get("identity", "object"))

	draw_circle(Vector2(1.4, 2.0), radius, Color(0.0, 0.0, 0.0, 0.30))
	draw_circle(Vector2.ZERO, radius + 1.0, Color(0.0, 0.0, 0.0, 0.16))
	draw_circle(Vector2.ZERO, radius, display_color)
	draw_circle(Vector2(-radius * 0.20, -radius * 0.23), radius * 0.70, display_color.lightened(0.13))
	draw_arc(Vector2.ZERO, radius - 1.0, 0.0, TAU, 32, display_color.darkened(0.48), 1.6)

	if bool(appearance.get("is_wayfinder", false)):
		_draw_wayfinder_mark(radius)
	elif bool(appearance.get("is_powder_keg", false)):
		_draw_powder_keg_mark(radius)
	elif bool(appearance.get("is_anchor_ball", false)) or bool(appearance.get("is_anchor_curse_seed", false)):
		_draw_anchor_mark(radius)
	elif bool(appearance.get("is_cannon_ball", false)):
		_draw_cannon_mark(radius)
	elif bool(appearance.get("is_treasure_ball", false)):
		_draw_treasure_mark(radius)
	elif bool(appearance.get("is_embezzler_ball", false)):
		_draw_embezzler_mark(radius)
	elif identity == "eight" or (identity == "object" and bool(appearance.get("show_ball_numbers", false))):
		_draw_number_mark(radius)

	draw_circle(Vector2(-radius * 0.34, -radius * 0.38), radius * 0.18, Color(1.0, 1.0, 1.0, 0.28))


func _draw_number_mark(radius: float) -> void:
	draw_circle(Vector2.ZERO, radius * 0.46, Color(0.94, 0.93, 0.86, 0.92))
	var number_text: String = str(int(appearance.get("ball_number", 0)))
	var font_size: int = maxi(int(round(radius * 0.78)), 8)
	var text_size: Vector2 = UI_FONT.get_string_size(number_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_origin: Vector2 = Vector2(-text_size.x * 0.5, text_size.y * 0.32)
	draw_string(UI_FONT, text_origin, number_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color("18130e"))


func _draw_wayfinder_mark(radius: float) -> void:
	var mark_color: Color = Color(0.96, 0.83, 0.45, 0.90)
	draw_arc(Vector2.ZERO, radius * 0.48, 0.0, TAU, 24, mark_color, 1.3)
	draw_line(Vector2(0.0, -radius * 0.55), Vector2(0.0, radius * 0.55), mark_color, 1.3)
	draw_line(Vector2(-radius * 0.55, 0.0), Vector2(radius * 0.55, 0.0), mark_color, 1.3)


func _draw_powder_keg_mark(radius: float) -> void:
	var band_color: Color = Color("e0b15e")
	draw_arc(Vector2(0.0, -radius * 0.30), radius * 0.74, 0.0, TAU, 26, band_color, 1.8)
	draw_arc(Vector2(0.0, radius * 0.30), radius * 0.70, 0.0, TAU, 26, band_color, 1.7)
	draw_line(Vector2(radius * 0.08, -radius * 0.76), Vector2(radius * 0.30, -radius * 1.02), Color("f6d07c"), 1.5)


func _draw_anchor_mark(radius: float) -> void:
	var mark_color: Color = Color("9db0ae")
	draw_line(Vector2(0.0, -radius * 0.52), Vector2(0.0, radius * 0.30), mark_color, 2.0)
	draw_line(Vector2(-radius * 0.36, -radius * 0.22), Vector2(radius * 0.36, -radius * 0.22), mark_color, 1.8)
	draw_arc(Vector2(0.0, radius * 0.10), radius * 0.45, deg_to_rad(25.0), deg_to_rad(155.0), 20, mark_color, 2.0)


func _draw_cannon_mark(radius: float) -> void:
	draw_arc(Vector2.ZERO, radius - 2.0, 0.0, TAU, 30, Color("4a4f52"), 1.7)
	draw_circle(Vector2(-radius * 0.28, -radius * 0.10), radius * 0.12, Color("070809"))
	draw_circle(Vector2(radius * 0.24, radius * 0.20), radius * 0.09, Color("070809"))


func _draw_treasure_mark(radius: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -radius * 0.48),
		Vector2(radius * 0.43, 0.0),
		Vector2(0.0, radius * 0.50),
		Vector2(-radius * 0.43, 0.0),
	])
	draw_colored_polygon(points, Color("57e0d4"))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("fff0a0"), 1.3)


func _draw_embezzler_mark(radius: float) -> void:
	var coin_color: Color = Color("ffd56a")
	draw_circle(Vector2(-radius * 0.18, 0.0), radius * 0.24, coin_color)
	draw_circle(Vector2(radius * 0.20, radius * 0.08), radius * 0.22, coin_color.darkened(0.10))
	draw_arc(Vector2(-radius * 0.18, 0.0), radius * 0.24, 0.0, TAU, 18, Color("704316"), 1.1)


func _get_dictionary(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_vector2(container: Dictionary, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = container.get(key, fallback)
	return value if value is Vector2 else fallback
