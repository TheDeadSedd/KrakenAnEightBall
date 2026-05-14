extends Control
class_name ReserveDeploymentPresenter

# index:title Reserve Deployment Presenter
# index:category UI / Systems / In Progress
# index:status In Progress
# index:owner ui_agent
# index:notes Draws presentation-only reserve deployment cursor icon and dotted tether.

# Presentation-only layer for reserve deployment. BallPlacementSystem owns
# validity/confirm/cancel; this script only draws the "pulled from slot" feel.
const CURSOR_ICON_SIZE := Vector2(34, 34)
const CURSOR_ICON_RADIUS := 10.5
const CURSOR_ICON_RING_RADIUS := 15.0
const TETHER_DOT_COUNT := 34
const TETHER_DOT_RADIUS := 2.4
const TETHER_MIN_REDRAW_DISTANCE := 0.5
const TETHER_ORIGIN_COLOR := Color(1.0, 0.78, 0.32, 0.76)
const TETHER_END_COLOR := Color(0.66, 1.0, 0.82, 0.52)
const TETHER_SOCKET_COLOR := Color(1.0, 0.77, 0.28, 0.34)
const CURSOR_RING_COLOR := Color(0.98, 0.82, 0.36, 0.46)

var reserve_system: ReserveSystem
var reserve_slots_ui: ReserveSlotsUI
var active := false
var active_slot_index := -1
var active_icon_key := ""
var origin_position := Vector2.ZERO
var cursor_position := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	set_process(false)


func setup(reserve_system_ref: ReserveSystem, reserve_slots_ui_ref: ReserveSlotsUI) -> void:
	reserve_system = reserve_system_ref
	reserve_slots_ui = reserve_slots_ui_ref
	if reserve_system == null:
		return

	if not reserve_system.deployment_started.is_connected(_on_deployment_started):
		reserve_system.deployment_started.connect(_on_deployment_started)
	if not reserve_system.deployment_finished.is_connected(_on_deployment_finished):
		reserve_system.deployment_finished.connect(_on_deployment_finished)
	if not reserve_system.deployment_blocked.is_connected(_on_deployment_blocked):
		reserve_system.deployment_blocked.connect(_on_deployment_blocked)


func _process(_delta: float) -> void:
	if not active:
		return

	var next_cursor_position := get_local_mouse_position()
	var redraw_distance_squared := TETHER_MIN_REDRAW_DISTANCE * TETHER_MIN_REDRAW_DISTANCE
	if next_cursor_position.distance_squared_to(cursor_position) < redraw_distance_squared:
		return

	cursor_position = next_cursor_position
	queue_redraw()


func _draw() -> void:
	if not active:
		return

	_draw_tether(origin_position, cursor_position)
	_draw_cursor_icon(cursor_position, active_icon_key)


func _on_deployment_started(_item_name: String, slot_index: int) -> void:
	if reserve_slots_ui == null:
		return

	active = true
	active_slot_index = slot_index
	active_icon_key = reserve_slots_ui.get_slot_icon_key(slot_index)
	origin_position = _to_local_canvas_position(reserve_slots_ui.get_slot_center_canvas_position(slot_index))
	cursor_position = get_local_mouse_position()
	visible = true
	set_process(true)
	queue_redraw()


func _on_deployment_finished(_confirmed: bool, _slot_index: int) -> void:
	_clear_deployment_presentation()


func _on_deployment_blocked(_reason: String) -> void:
	if active_slot_index == -1:
		return
	_clear_deployment_presentation()


func _clear_deployment_presentation() -> void:
	active = false
	active_slot_index = -1
	active_icon_key = ""
	visible = false
	set_process(false)
	queue_redraw()


func _to_local_canvas_position(canvas_position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * canvas_position


func _draw_tether(start: Vector2, end: Vector2) -> void:
	var distance := start.distance_to(end)
	if distance <= 4.0:
		return

	var bend := clampf(distance * 0.24, 28.0, 118.0)
	var control := (start + end) * 0.5 + Vector2(0.0, -bend)
	draw_circle(start, 6.0, TETHER_SOCKET_COLOR)
	draw_arc(start, 8.0, 0.0, TAU, 24, TETHER_ORIGIN_COLOR, 1.5, true)

	for dot_index in range(TETHER_DOT_COUNT + 1):
		if dot_index % 2 != 0:
			continue
		var t := float(dot_index) / float(TETHER_DOT_COUNT)
		var point := _quadratic_bezier(start, control, end, t)
		var color := TETHER_ORIGIN_COLOR.lerp(TETHER_END_COLOR, t)
		draw_circle(point, TETHER_DOT_RADIUS, color)


func _quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var first := start.lerp(control, t)
	var second := control.lerp(end, t)
	return first.lerp(second, t)


func _draw_cursor_icon(center: Vector2, icon_key: String) -> void:
	draw_circle(center, CURSOR_ICON_RING_RADIUS, CURSOR_RING_COLOR)
	draw_arc(center, CURSOR_ICON_RING_RADIUS, 0.0, TAU, 32, Color(1.0, 0.92, 0.54, 0.72), 1.8, true)
	var icon_rect := Rect2(center - CURSOR_ICON_SIZE * 0.5, CURSOR_ICON_SIZE)
	match icon_key:
		"wayfinder_ball":
			_draw_wayfinder_icon(icon_rect)
		"powder_keg_ball":
			_draw_powder_keg_icon(icon_rect)
		_:
			_draw_plain_ball_icon(icon_rect)


func _draw_plain_ball_icon(icon_rect: Rect2) -> void:
	var center := icon_rect.get_center()
	draw_circle(center, CURSOR_ICON_RADIUS, Color(0.9, 0.86, 0.66, 0.94))
	draw_circle(center + Vector2(-3.8, -3.8), 3.0, Color(1.0, 0.98, 0.82, 0.82))
	draw_arc(center, CURSOR_ICON_RADIUS, 0.0, TAU, 32, Color(0.12, 0.09, 0.04, 0.86), 2.0, true)


func _draw_wayfinder_icon(icon_rect: Rect2) -> void:
	var center := icon_rect.get_center()
	draw_circle(center, 11.5, Color(0.34, 0.96, 0.84, 0.9))
	draw_arc(center, 11.5, 0.0, TAU, 32, Color(0.04, 0.16, 0.15, 0.9), 2.0, true)
	draw_line(center + Vector2(-6.5, 4.8), center + Vector2(6.5, -4.8), Color(1.0, 0.92, 0.58, 0.96), 3.0)
	draw_circle(center, 2.1, Color(0.04, 0.16, 0.15, 0.96))


func _draw_powder_keg_icon(icon_rect: Rect2) -> void:
	var center := icon_rect.get_center()
	var keg_rect := Rect2(center + Vector2(-10.5, -8.5), Vector2(21, 18))
	draw_rect(keg_rect, Color(0.55, 0.16, 0.09, 0.95), true)
	draw_rect(keg_rect, Color(1.0, 0.6, 0.24, 0.9), false, 2.0)
	draw_line(center + Vector2(0, -8.5), center + Vector2(6.7, -14.5), Color(0.95, 0.78, 0.46, 0.95), 2.0)
	draw_circle(center + Vector2(8.5, -16.0), 2.2, Color(1.0, 0.42, 0.1, 0.92))
