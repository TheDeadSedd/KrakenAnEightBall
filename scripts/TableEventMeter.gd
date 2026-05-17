extends Control
class_name TableEventMeter

signal event_icon_clicked

# Player-facing meter for shot-earned Kraken Intervention opportunities.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const BORDER_COLOR := Color(0.74, 0.55, 0.22, 0.72)
const BORDER_READY_COLOR := Color(1.0, 0.84, 0.36, 1.0)
const TRACK_COLOR := Color(0.02, 0.025, 0.024, 0.88)
const FILL_COLOR := Color(0.22, 0.72, 0.84, 0.92)
const FILL_READY_COLOR := Color(1.0, 0.72, 0.22, 1.0)
const TEXT_COLOR := Color(0.95, 0.88, 0.66, 1.0)
const VALUE_TEXT_COLOR := Color(0.78, 0.96, 1.0, 1.0)
const SHADOW_COLOR := Color(0.02, 0.015, 0.01, 0.72)
const ICON_FILL := Color(0.055, 0.038, 0.020, 0.90)
const ICON_FILL_HOVER := Color(0.13, 0.09, 0.035, 0.96)
const ICON_BORDER := Color(0.94, 0.72, 0.26, 0.88)
const ICON_GLOW := Color(1.0, 0.70, 0.18, 0.22)
const TITLE_FONT_SIZE := 17
const VALUE_FONT_SIZE := 16
const PERCENT_FONT_SIZE := 24
const BAR_LEFT := 20.0
const BAR_TOP := 40.0
const BAR_HEIGHT := 22.0
const BAR_ICON_GAP := 78.0
const ICON_SIZE := Vector2(44.0, 44.0)
const ICON_RIGHT_MARGIN := 14.0
const FILL_SMOOTH_SPEED := 7.5
const PROGRESS_PULSE_TIME := 0.22
const EVENT_EARNED_FLASH_TIME := 0.68
const READY_FLASH_TIME := 0.42
const READY_IDLE_PULSE_SPEED := 2.8
const READY_IDLE_PULSE_ALPHA := 0.18
const ANIMATION_EPSILON := 0.002

var table_event_system: TableEventSystem
var table
var progress := 0
var threshold := 60
var target_percent := 0.0
var displayed_percent := 0.0
var last_gain := 0
var pending_event := false
var event_ready := false
var icon_hovered := false
var progress_pulse_remaining := 0.0
var event_earned_flash_remaining := 0.0
var ready_flash_remaining := 0.0
var ready_idle_phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	pivot_offset = size * 0.5
	set_process(false)
	queue_redraw()


func _exit_tree() -> void:
	_disconnect_table_event_system()


func setup(system: TableEventSystem, table_ref) -> void:
	_disconnect_table_event_system()
	table_event_system = system
	table = table_ref
	if table_event_system == null:
		return

	table_event_system.meter_changed.connect(_on_meter_changed)
	table_event_system.progress_advanced.connect(_on_progress_advanced)
	table_event_system.pending_event_changed.connect(_on_pending_event_changed)
	var snapshot: Dictionary = table_event_system.get_debug_snapshot()
	_set_progress(
		int(snapshot.get("shot_progress", 0)),
		int(snapshot.get("shot_threshold", 1)),
		float(snapshot.get("progress_percent", 0.0)),
		bool(snapshot.get("pending_event_available", false)),
		bool(snapshot.get("pending_event_ready", false))
	)
	displayed_percent = target_percent
	queue_redraw()


func _process(delta: float) -> void:
	var smoothing_ratio: float = clampf(delta * FILL_SMOOTH_SPEED, 0.0, 1.0)
	displayed_percent = lerpf(displayed_percent, target_percent, smoothing_ratio)
	if abs(displayed_percent - target_percent) <= ANIMATION_EPSILON:
		displayed_percent = target_percent

	progress_pulse_remaining = maxf(progress_pulse_remaining - delta, 0.0)
	event_earned_flash_remaining = maxf(event_earned_flash_remaining - delta, 0.0)
	ready_flash_remaining = maxf(ready_flash_remaining - delta, 0.0)
	if event_ready:
		ready_idle_phase = fposmod(ready_idle_phase + delta * READY_IDLE_PULSE_SPEED, TAU)
	_update_pulse_scale()
	queue_redraw()

	if not _is_animating():
		scale = Vector2.ONE
		set_process(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_icon_hover(event.position)
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		_update_icon_hover(mouse_event.position)
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not _is_icon_clickable():
			return
		if _is_cue_drag_active():
			return

		accept_event()
		event_icon_clicked.emit()


func _draw() -> void:
	var draw_size: Vector2 = size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return

	var pulse_strength: float = _get_pulse_strength()
	var earned_strength: float = _get_event_earned_strength()
	var ready_strength: float = _get_ready_strength()
	var idle_strength: float = _get_ready_idle_strength()
	var event_strength: float = maxf(earned_strength, maxf(ready_strength, idle_strength * 0.45))
	var border_color: Color = BORDER_COLOR.lerp(BORDER_READY_COLOR, maxf(pulse_strength * 0.45, event_strength))
	var fill_color: Color = FILL_COLOR.lerp(FILL_READY_COLOR, maxf(pulse_strength * 0.45, event_strength))

	_draw_event_earned_glow(_get_bar_rect(draw_size), earned_strength)
	_draw_meter_text(draw_size, pulse_strength, maxf(ready_strength, earned_strength))
	_draw_meter_bar(draw_size, fill_color, border_color)
	_draw_event_icon(draw_size, ready_strength, idle_strength)


func _on_meter_changed(new_progress: int, new_threshold: int, new_percent: float, pending: bool, ready: bool) -> void:
	_set_progress(new_progress, new_threshold, new_percent, pending, ready)
	_wake_animation()


func _on_progress_advanced(amount: int, _shot_total: int) -> void:
	if amount <= 0:
		return
	last_gain = amount
	progress_pulse_remaining = PROGRESS_PULSE_TIME
	_wake_animation()


func _on_pending_event_changed(_pending: bool, _ready: bool) -> void:
	_wake_animation()


func _set_progress(new_progress: int, new_threshold: int, new_percent: float, pending: bool, ready: bool) -> void:
	var was_pending: bool = pending_event
	var was_ready: bool = event_ready
	progress = maxi(new_progress, 0)
	threshold = maxi(new_threshold, 1)
	target_percent = clampf(new_percent, 0.0, 1.0)
	pending_event = pending
	event_ready = ready
	if pending_event and not was_pending:
		event_earned_flash_remaining = EVENT_EARNED_FLASH_TIME
	if event_ready and not was_ready:
		ready_flash_remaining = READY_FLASH_TIME


func _wake_animation() -> void:
	pivot_offset = size * 0.5
	set_process(true)
	queue_redraw()


func _is_animating() -> bool:
	return (
		abs(displayed_percent - target_percent) > ANIMATION_EPSILON
		or progress_pulse_remaining > 0.0
		or event_earned_flash_remaining > 0.0
		or ready_flash_remaining > 0.0
		or event_ready
	)


func _update_pulse_scale() -> void:
	var scale_boost: float = 1.0 + _get_pulse_strength() * 0.025 + _get_event_earned_strength() * 0.035 + _get_ready_strength() * 0.050
	scale = Vector2.ONE * scale_boost


func _draw_meter_text(draw_size: Vector2, pulse_strength: float, ready_strength: float) -> void:
	var title_color: Color = TEXT_COLOR.lerp(BORDER_READY_COLOR, ready_strength)
	var value_color: Color = VALUE_TEXT_COLOR.lerp(FILL_READY_COLOR, maxf(pulse_strength * 0.45, ready_strength))
	var percent_text: String = "%d%%" % int(round(target_percent * 100.0))
	var value_text: String = "%d / %d" % [progress, threshold]
	var bar_rect: Rect2 = _get_bar_rect(draw_size)

	_draw_shadowed_text("KRAKEN INTERVENTION", Vector2(BAR_LEFT, 25.0), TITLE_FONT_SIZE, title_color)
	_draw_shadowed_text(value_text, Vector2(BAR_LEFT, bar_rect.end.y + 25.0), VALUE_FONT_SIZE, value_color)
	draw_string(
		UI_FONT,
		Vector2(bar_rect.end.x - 96.0, bar_rect.position.y + 18.0) + Vector2(1.5, 1.5),
		percent_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		96.0,
		PERCENT_FONT_SIZE,
		SHADOW_COLOR
	)
	draw_string(
		UI_FONT,
		Vector2(bar_rect.end.x - 96.0, bar_rect.position.y + 18.0),
		percent_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		96.0,
		PERCENT_FONT_SIZE,
		value_color
	)

	if progress_pulse_remaining > 0.0 and last_gain > 0:
		var gain_color: Color = FILL_READY_COLOR.lerp(Color.WHITE, ready_strength)
		draw_string(
			UI_FONT,
			Vector2(bar_rect.end.x - 122.0, 25.0),
			"+%d" % last_gain,
			HORIZONTAL_ALIGNMENT_RIGHT,
			120.0,
			VALUE_FONT_SIZE,
			gain_color
		)


func _draw_meter_bar(draw_size: Vector2, fill_color: Color, border_color: Color) -> void:
	var track_rect: Rect2 = _get_bar_rect(draw_size)
	var fill_width: float = track_rect.size.x * clampf(displayed_percent, 0.0, 1.0)
	var fill_rect: Rect2 = Rect2(track_rect.position, Vector2(fill_width, track_rect.size.y))
	draw_rect(track_rect, TRACK_COLOR, true)
	if fill_width > 0.0:
		draw_rect(fill_rect, fill_color, true)
		draw_line(
			Vector2(fill_rect.end.x, fill_rect.position.y + 3.0),
			Vector2(fill_rect.end.x, fill_rect.end.y - 3.0),
			fill_color.lightened(0.32),
			2.0
		)

	draw_rect(track_rect, border_color, false, 1.5)
	for tick_index in range(1, 5):
		var tick_x: float = track_rect.position.x + track_rect.size.x * float(tick_index) / 5.0
		draw_line(
			Vector2(tick_x, track_rect.position.y + 2.0),
			Vector2(tick_x, track_rect.end.y - 2.0),
			border_color.darkened(0.25),
			1.0
		)


func _draw_event_earned_glow(panel_rect: Rect2, earned_strength: float) -> void:
	if earned_strength <= 0.0:
		return

	var glow_color: Color = Color(1.0, 0.72, 0.20, 0.20 * earned_strength)
	draw_rect(panel_rect.grow(8.0), glow_color, false, 4.0)
	draw_rect(panel_rect.grow(15.0), Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.42), false, 7.0)


func _draw_event_icon(draw_size: Vector2, ready_strength: float, idle_strength: float) -> void:
	if not event_ready:
		return

	var icon_rect: Rect2 = _get_icon_rect(draw_size)
	var icon_fill: Color = ICON_FILL_HOVER if icon_hovered else ICON_FILL
	var combined_strength: float = maxf(ready_strength, idle_strength)
	var glow_alpha: float = (0.55 + 0.45 * _get_ready_strength()) if icon_hovered else (0.32 + combined_strength * 0.40)
	var glow_color: Color = Color(ICON_GLOW.r, ICON_GLOW.g, ICON_GLOW.b, ICON_GLOW.a * glow_alpha)
	draw_rect(icon_rect.grow(7.0 + idle_strength * 2.0), glow_color, true)
	draw_rect(icon_rect.grow(13.0 + idle_strength * 3.0), Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.36), true)
	draw_rect(icon_rect, icon_fill, true)
	draw_rect(icon_rect, ICON_BORDER.lerp(BORDER_READY_COLOR, combined_strength), false, 2.0)
	var center: Vector2 = icon_rect.get_center()
	draw_arc(center, 14.0 + idle_strength * 1.5, -PI * 0.15, TAU * 0.72, 36, FILL_READY_COLOR, 3.0)
	draw_circle(center, 4.0, BORDER_READY_COLOR)
	_draw_shadowed_text("!", center + Vector2(-4.0, 9.0), 24, BORDER_READY_COLOR)


func _update_icon_hover(local_position: Vector2) -> void:
	var next_hovered: bool = event_ready and _get_icon_rect(size).has_point(local_position)
	if icon_hovered == next_hovered:
		return
	icon_hovered = next_hovered
	queue_redraw()


func _is_icon_clickable() -> bool:
	return table_event_system != null and table_event_system.is_event_icon_clickable() and _get_icon_rect(size).has_point(get_local_mouse_position())


func _is_cue_drag_active() -> bool:
	return table != null and table.is_cue_drag_active()


func _get_bar_rect(draw_size: Vector2) -> Rect2:
	var bar_width: float = maxf(draw_size.x - BAR_LEFT - BAR_ICON_GAP - ICON_SIZE.x - ICON_RIGHT_MARGIN, 80.0)
	return Rect2(Vector2(BAR_LEFT, BAR_TOP), Vector2(bar_width, BAR_HEIGHT))


func _get_icon_rect(draw_size: Vector2) -> Rect2:
	var icon_position: Vector2 = Vector2(
		draw_size.x - ICON_RIGHT_MARGIN - ICON_SIZE.x,
		(draw_size.y - ICON_SIZE.y) * 0.5 + 4.0
	)
	return Rect2(icon_position, ICON_SIZE)


func _draw_shadowed_text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(UI_FONT, position + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, SHADOW_COLOR)
	draw_string(UI_FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_pulse_strength() -> float:
	if progress_pulse_remaining <= 0.0:
		return 0.0
	return sin(progress_pulse_remaining / PROGRESS_PULSE_TIME * PI)


func _get_event_earned_strength() -> float:
	if event_earned_flash_remaining <= 0.0:
		return 0.0
	return sin(event_earned_flash_remaining / EVENT_EARNED_FLASH_TIME * PI)


func _get_ready_strength() -> float:
	if ready_flash_remaining <= 0.0:
		return 0.0
	return sin(ready_flash_remaining / READY_FLASH_TIME * PI)


func _get_ready_idle_strength() -> float:
	if not event_ready:
		return 0.0
	return (0.5 + 0.5 * sin(ready_idle_phase)) * READY_IDLE_PULSE_ALPHA


func _disconnect_table_event_system() -> void:
	if table_event_system == null:
		return
	if table_event_system.meter_changed.is_connected(_on_meter_changed):
		table_event_system.meter_changed.disconnect(_on_meter_changed)
	if table_event_system.progress_advanced.is_connected(_on_progress_advanced):
		table_event_system.progress_advanced.disconnect(_on_progress_advanced)
	if table_event_system.pending_event_changed.is_connected(_on_pending_event_changed):
		table_event_system.pending_event_changed.disconnect(_on_pending_event_changed)
