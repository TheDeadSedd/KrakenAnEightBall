extends Control
class_name RogueliteScoringGhostBall

signal finished(ghost: RogueliteScoringGhostBall)

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

var appearance: Dictionary = {}
var accent_color := Color.WHITE
var radius := 14.0
var glow_strength := 1.0:
	set(value):
		glow_strength = value
		queue_redraw()
var ghost_alpha := 0.78:
	set(value):
		ghost_alpha = value
		queue_redraw()
var presentation_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 51


func setup(appearance_snapshot: Dictionary, center: Vector2, intensity: float = 1.0) -> void:
	appearance = appearance_snapshot.duplicate(true)
	radius = clampf(float(appearance.get("radius", 14.0)), 8.0, 24.0)
	var color_value: Variant = appearance.get("base_color", Color.WHITE)
	accent_color = color_value as Color if color_value is Color else Color.WHITE
	var extent: float = radius * 4.0
	size = Vector2.ONE * extent
	custom_minimum_size = size
	position = center - size * 0.5
	pivot_offset = size * 0.5
	glow_strength = clampf(intensity, 0.65, 1.5)
	ghost_alpha = 0.76
	scale = Vector2.ONE * 0.72
	queue_redraw()
	if presentation_tween != null and presentation_tween.is_valid():
		presentation_tween.kill()
	presentation_tween = create_tween()
	presentation_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	presentation_tween.set_parallel(true)
	presentation_tween.tween_property(self, "scale", Vector2.ONE * 1.09, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	presentation_tween.tween_property(self, "glow_strength", 0.72, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	presentation_tween.set_parallel(false)
	presentation_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func fade_out(duration: float = 0.28) -> void:
	if presentation_tween != null and presentation_tween.is_valid():
		presentation_tween.kill()
	presentation_tween = create_tween()
	presentation_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	presentation_tween.set_parallel(true)
	presentation_tween.tween_property(self, "ghost_alpha", 0.0, maxf(duration, 0.06))
	presentation_tween.tween_property(self, "scale", Vector2.ONE * 0.88, maxf(duration, 0.06))
	presentation_tween.finished.connect(_finish)


func finish_immediately() -> void:
	if presentation_tween != null and presentation_tween.is_valid():
		presentation_tween.kill()
	_finish()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	for ring_index in range(4):
		var ring_radius: float = radius * (1.18 + float(ring_index) * 0.22)
		var ring_alpha: float = ghost_alpha * glow_strength * (0.13 - float(ring_index) * 0.022)
		draw_circle(center, ring_radius, Color(accent_color.r, accent_color.g, accent_color.b, ring_alpha), false, 2.0)
	draw_circle(center, radius, Color(accent_color.r, accent_color.g, accent_color.b, ghost_alpha * 0.72), true)
	draw_circle(center, radius, Color(1.0, 1.0, 1.0, ghost_alpha * 0.68), false, 1.6)
	draw_circle(
		center - Vector2(radius * 0.28, radius * 0.32),
		radius * 0.22,
		Color(1.0, 1.0, 1.0, ghost_alpha * 0.36),
		true
	)
	var ball_number: int = int(appearance.get("ball_number", -1))
	if ball_number >= 0:
		var text: String = str(ball_number)
		var font_size: int = maxi(int(roundf(radius * 0.92)), 10)
		var text_size: Vector2 = UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		draw_string(
			UI_FONT,
			center + Vector2(-text_size.x * 0.5, text_size.y * 0.34),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color(0.03, 0.035, 0.045, ghost_alpha * 0.88)
		)


func _finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit(self)
	queue_free()
