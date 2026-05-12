extends Control
class_name BallDropMeter

# index:title Ball Drop Meter
# index:category UI / Systems / In Progress
# index:status In Progress
# index:owner ui_agent
# index:notes Vertical right-side meter for score progress toward the next earned ball drop.

# Player-facing progress display only. BallDropSystem owns the real state,
# signals, thresholds, and earned-drop decisions.
const UI_FONT := preload("res://assets/fonts/Gothic Pixels.ttf")
const PANEL_COLOR := Color(0.035, 0.052, 0.052, 0.82)
const PANEL_FLASH_COLOR := Color(0.32, 0.22, 0.07, 0.92)
const BORDER_COLOR := Color(0.74, 0.55, 0.22, 0.72)
const BORDER_FLASH_COLOR := Color(1.0, 0.88, 0.42, 1.0)
const TRACK_COLOR := Color(0.02, 0.025, 0.024, 0.88)
const FILL_COLOR := Color(0.18, 0.78, 0.68, 0.92)
const FILL_PULSE_COLOR := Color(1.0, 0.76, 0.24, 1.0)
const TEXT_COLOR := Color(0.95, 0.88, 0.66, 1.0)
const VALUE_TEXT_COLOR := Color(0.76, 0.98, 0.9, 1.0)
const SHADOW_COLOR := Color(0.02, 0.015, 0.01, 0.72)
const TITLE_FONT_SIZE := 15
const VALUE_FONT_SIZE := 14
const PERCENT_FONT_SIZE := 28
const BAR_WIDTH := 28.0
const BAR_LEFT := 16.0
const BAR_TOP := 74.0
const BAR_BOTTOM_MARGIN := 98.0
const TEXT_LEFT := 56.0
const FILL_SMOOTH_SPEED := 8.0
const PROGRESS_PULSE_TIME := 0.22
const DROP_FLASH_TIME := 0.36
const ANIMATION_EPSILON := 0.002

var ball_drop_system: BallDropSystem
var progress := 0
var threshold := 50
var target_percent := 0.0
var displayed_percent := 0.0
var last_gain := 0
var progress_pulse_remaining := 0.0
var drop_flash_remaining := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	set_process(false)
	queue_redraw()


func _exit_tree() -> void:
	_disconnect_ball_drop_system()


func setup(system: BallDropSystem) -> void:
	_disconnect_ball_drop_system()
	ball_drop_system = system
	if ball_drop_system == null:
		return

	ball_drop_system.progress_changed.connect(_on_progress_changed)
	ball_drop_system.progress_advanced.connect(_on_progress_advanced)
	ball_drop_system.drop_earned.connect(_on_drop_earned)

	var snapshot: Dictionary = ball_drop_system.get_debug_snapshot()
	_set_progress(
		int(snapshot.get("drop_progress", 0)),
		int(snapshot.get("doubloons_per_drop", 1)),
		float(snapshot.get("progress_percent", 0.0))
	)
	displayed_percent = target_percent
	queue_redraw()


func _process(delta: float) -> void:
	var smoothing_ratio: float = clamp(delta * FILL_SMOOTH_SPEED, 0.0, 1.0)
	displayed_percent = lerp(displayed_percent, target_percent, smoothing_ratio)
	if abs(displayed_percent - target_percent) <= ANIMATION_EPSILON:
		displayed_percent = target_percent

	progress_pulse_remaining = max(progress_pulse_remaining - delta, 0.0)
	drop_flash_remaining = max(drop_flash_remaining - delta, 0.0)
	_update_pulse_scale()
	queue_redraw()

	if not _is_animating():
		scale = Vector2.ONE
		set_process(false)


func _draw() -> void:
	var draw_size: Vector2 = size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return

	var pulse_strength: float = _get_pulse_strength()
	var drop_strength: float = _get_drop_flash_strength()
	var panel_rect := Rect2(Vector2.ZERO, draw_size)
	var panel_color: Color = PANEL_COLOR.lerp(PANEL_FLASH_COLOR, drop_strength * 0.65)
	var border_color: Color = BORDER_COLOR.lerp(BORDER_FLASH_COLOR, max(pulse_strength * 0.45, drop_strength))
	var fill_color: Color = FILL_COLOR.lerp(FILL_PULSE_COLOR, max(pulse_strength * 0.55, drop_strength))

	draw_rect(panel_rect, panel_color, true)
	draw_rect(panel_rect, border_color, false, 2.0)
	_draw_corner_rivets(panel_rect, border_color)
	_draw_meter_text(draw_size, pulse_strength, drop_strength)
	_draw_meter_bar(draw_size, fill_color, border_color)


func _on_progress_changed(new_progress: int, new_threshold: int, new_percent: float) -> void:
	_set_progress(new_progress, new_threshold, new_percent)
	_wake_animation()


func _on_progress_advanced(amount: int, _drops_earned: int) -> void:
	if amount <= 0:
		return

	last_gain = amount
	progress_pulse_remaining = PROGRESS_PULSE_TIME
	_wake_animation()


func _on_drop_earned(_drops_earned: int) -> void:
	drop_flash_remaining = DROP_FLASH_TIME
	_wake_animation()


func _set_progress(new_progress: int, new_threshold: int, new_percent: float) -> void:
	progress = max(new_progress, 0)
	threshold = max(new_threshold, 1)
	target_percent = clamp(new_percent, 0.0, 1.0)


func _wake_animation() -> void:
	pivot_offset = size * 0.5
	set_process(true)
	queue_redraw()


func _is_animating() -> bool:
	return (
		abs(displayed_percent - target_percent) > ANIMATION_EPSILON
		or progress_pulse_remaining > 0.0
		or drop_flash_remaining > 0.0
	)


func _update_pulse_scale() -> void:
	var pulse_strength: float = _get_pulse_strength()
	var drop_strength: float = _get_drop_flash_strength()
	var scale_boost: float = 1.0 + pulse_strength * 0.035 + drop_strength * 0.075
	scale = Vector2.ONE * scale_boost


func _draw_meter_text(draw_size: Vector2, pulse_strength: float, drop_strength: float) -> void:
	var title_color: Color = TEXT_COLOR.lerp(BORDER_FLASH_COLOR, drop_strength)
	var value_color: Color = VALUE_TEXT_COLOR.lerp(FILL_PULSE_COLOR, max(pulse_strength * 0.45, drop_strength))
	var percent_text := "%d%%" % int(round(target_percent * 100.0))
	var value_text := "%d / %d" % [progress, threshold]
	var title_text := "NEXT DROP"
	if drop_flash_remaining > 0.0:
		title_text = "DROP EARNED!"

	_draw_shadowed_text(title_text, Vector2(12.0, 20.0), TITLE_FONT_SIZE, title_color)
	_draw_shadowed_text(percent_text, Vector2(TEXT_LEFT, BAR_TOP + 44.0), PERCENT_FONT_SIZE, value_color)
	_draw_shadowed_text(value_text, Vector2(12.0, draw_size.y - 44.0), VALUE_FONT_SIZE, value_color)
	_draw_shadowed_text("DOUBLOONS", Vector2(12.0, draw_size.y - 20.0), VALUE_FONT_SIZE, title_color.darkened(0.08))
	if progress_pulse_remaining > 0.0 and last_gain > 0:
		var gain_color: Color = FILL_PULSE_COLOR.lerp(Color.WHITE, drop_strength)
		var gain_text := "+%d" % last_gain
		draw_string(
			UI_FONT,
			Vector2(12.0, 20.0),
			gain_text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			draw_size.x - 24.0,
			TITLE_FONT_SIZE,
			gain_color
		)


func _draw_meter_bar(draw_size: Vector2, fill_color: Color, border_color: Color) -> void:
	var bar_height: float = max(draw_size.y - BAR_TOP - BAR_BOTTOM_MARGIN, 0.0)
	var track_rect := Rect2(
		Vector2(BAR_LEFT, BAR_TOP),
		Vector2(BAR_WIDTH, bar_height)
	)
	var fill_height: float = track_rect.size.y * clamp(displayed_percent, 0.0, 1.0)
	var fill_rect := Rect2(
		Vector2(track_rect.position.x, track_rect.end.y - fill_height),
		Vector2(track_rect.size.x, fill_height)
	)
	draw_rect(track_rect, TRACK_COLOR, true)
	if fill_height > 0.0:
		draw_rect(fill_rect, fill_color, true)
		draw_line(
			Vector2(fill_rect.position.x + 3.0, fill_rect.position.y),
			Vector2(fill_rect.end.x - 3.0, fill_rect.position.y),
			fill_color.lightened(0.32),
			2.0
		)

	draw_rect(track_rect, border_color, false, 1.5)
	for tick_index in range(1, 5):
		var tick_y: float = track_rect.end.y - track_rect.size.y * float(tick_index) / 5.0
		draw_line(
			Vector2(track_rect.position.x + 2.0, tick_y),
			Vector2(track_rect.end.x - 2.0, tick_y),
			border_color.darkened(0.25),
			1.0
		)

	_draw_tide_marks(track_rect, border_color)


func _draw_tide_marks(track_rect: Rect2, color: Color) -> void:
	var label_x: float = track_rect.end.x + 8.0
	_draw_shadowed_text("FULL", Vector2(label_x, track_rect.position.y + 12.0), VALUE_FONT_SIZE, color)
	_draw_shadowed_text("LOW", Vector2(label_x, track_rect.end.y - 4.0), VALUE_FONT_SIZE, color.darkened(0.18))


func _draw_corner_rivets(panel_rect: Rect2, color: Color) -> void:
	var inset := Vector2(6.0, 6.0)
	draw_circle(panel_rect.position + inset, 2.0, color)
	draw_circle(Vector2(panel_rect.end.x - inset.x, panel_rect.position.y + inset.y), 2.0, color)
	draw_circle(Vector2(panel_rect.position.x + inset.x, panel_rect.end.y - inset.y), 2.0, color.darkened(0.25))
	draw_circle(panel_rect.end - inset, 2.0, color.darkened(0.25))


func _draw_shadowed_text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(UI_FONT, position + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, SHADOW_COLOR)
	draw_string(UI_FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_pulse_strength() -> float:
	if progress_pulse_remaining <= 0.0:
		return 0.0
	var ratio: float = progress_pulse_remaining / PROGRESS_PULSE_TIME
	return sin(ratio * PI)


func _get_drop_flash_strength() -> float:
	if drop_flash_remaining <= 0.0:
		return 0.0
	var ratio: float = drop_flash_remaining / DROP_FLASH_TIME
	return sin(ratio * PI)


func _disconnect_ball_drop_system() -> void:
	if ball_drop_system == null:
		return
	if ball_drop_system.progress_changed.is_connected(_on_progress_changed):
		ball_drop_system.progress_changed.disconnect(_on_progress_changed)
	if ball_drop_system.progress_advanced.is_connected(_on_progress_advanced):
		ball_drop_system.progress_advanced.disconnect(_on_progress_advanced)
	if ball_drop_system.drop_earned.is_connected(_on_drop_earned):
		ball_drop_system.drop_earned.disconnect(_on_drop_earned)
