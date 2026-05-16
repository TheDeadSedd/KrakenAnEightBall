extends Control
class_name ReserveSlotsUI

signal reserve_slot_clicked(slot_index: int)

# index:title Reserve Slots UI
# index:category UI / Systems / In Progress
# index:status In Progress
# index:owner ui_agent
# index:notes Draws icon-only reserve slots, emits filled-slot deploy requests, and consumes slot press input.

# Draw-only reserve slot UI. ReserveSystem owns slot data and deployment state.
const SLOT_COUNT := 3
const ITEM_ICON_DRAW := preload("res://scripts/ItemIconDraw.gd")
const SLOT_SIZE := Vector2(44, 44)
const SLOT_GAP := 12.0
const SLOT_PADDING := 8.0
const FRAME_TOP_INSET := 8.0
const UPPER_RIGHT_FRAME_ANCHOR_RATIO := 0.82
const EMPTY_SLOT_FILL := Color(0.035, 0.028, 0.022, 0.58)
const EMPTY_SLOT_BORDER := Color(0.92, 0.76, 0.38, 0.34)
const HOVER_SLOT_FILL := Color(0.09, 0.07, 0.04, 0.76)
const HOVER_SLOT_BORDER := Color(1.0, 0.86, 0.42, 0.92)
const HOVER_GLOW := Color(1.0, 0.72, 0.24, 0.18)
const FILLED_SLOT_FILL := Color(0.08, 0.11, 0.11, 0.78)
const FILLED_SLOT_BORDER := Color(0.72, 0.96, 0.84, 0.58)
const DEPLOYING_SLOT_GLOW := Color(1.0, 0.75, 0.28, 0.24)
const DEPLOYING_SLOT_RING := Color(1.0, 0.86, 0.42, 0.62)
const CORNER_RADIUS := 9
const GLOW_OUTSET := 5.0

var reserve_system: ReserveSystem
var table
var slot_snapshots: Array = []
var hovered_slot_index := -1
var hover_changes := 0
var clicks_consumed := 0
var motion_events_seen := 0

var empty_slot_style := StyleBoxFlat.new()
var hover_slot_style := StyleBoxFlat.new()
var filled_slot_style := StyleBoxFlat.new()
var hover_glow_style := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	z_index = 24
	_configure_styles()
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func setup(reserve_system_ref: ReserveSystem, table_ref) -> void:
	reserve_system = reserve_system_ref
	table = table_ref
	_position_on_table_frame()
	if reserve_system != null:
		if not reserve_system.reserve_slots_changed.is_connected(_on_reserve_slots_changed):
			reserve_system.reserve_slots_changed.connect(_on_reserve_slots_changed)
		_on_reserve_slots_changed(reserve_system.get_slots_snapshot())
	else:
		_on_reserve_slots_changed([])


func get_debug_snapshot() -> Dictionary:
	return {
		"visible": visible,
		"hovered_slot_index": hovered_slot_index,
		"hover_changes": hover_changes,
		"clicks_consumed": clicks_consumed,
		"motion_events_seen": motion_events_seen,
		"snapshot_count": slot_snapshots.size(),
	}


func get_slot_center_canvas_position(slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return get_global_transform().origin
	return get_global_transform() * _get_slot_rect(slot_index).get_center()


func get_slot_icon_key(slot_index: int) -> String:
	return str(_get_slot_snapshot(slot_index).get("icon_key", ""))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		motion_events_seen += 1
		_update_hovered_slot(event.position)
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		_update_hovered_slot(mouse_event.position)
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _is_cue_drag_active():
				return
			if hovered_slot_index == -1:
				return

			clicks_consumed += 1
			if reserve_system != null:
				reserve_system.record_slot_clicked(hovered_slot_index)
				if _is_slot_filled(hovered_slot_index):
					reserve_slot_clicked.emit(hovered_slot_index)
			accept_event()


func _draw() -> void:
	for slot_index in range(SLOT_COUNT):
		var slot_rect := _get_slot_rect(slot_index)
		var snapshot := _get_slot_snapshot(slot_index)
		var filled := bool(snapshot.get("filled", false))
		var deploying := bool(snapshot.get("deploying", false))
		if slot_index == hovered_slot_index:
			draw_style_box(hover_glow_style, slot_rect.grow(GLOW_OUTSET))
			draw_style_box(hover_slot_style, slot_rect)
		elif filled:
			draw_style_box(filled_slot_style, slot_rect)
		else:
			draw_style_box(empty_slot_style, slot_rect)

		if filled and deploying:
			_draw_deploying_slot_source(slot_rect)
		elif filled:
			_draw_slot_icon(slot_rect, str(snapshot.get("icon_key", "")))


func _configure_styles() -> void:
	_configure_slot_style(empty_slot_style, EMPTY_SLOT_FILL, EMPTY_SLOT_BORDER, 1)
	_configure_slot_style(hover_slot_style, HOVER_SLOT_FILL, HOVER_SLOT_BORDER, 2)
	_configure_slot_style(filled_slot_style, FILLED_SLOT_FILL, FILLED_SLOT_BORDER, 1)
	_configure_slot_style(hover_glow_style, HOVER_GLOW, Color(1.0, 0.72, 0.24, 0.0), 0)


func _configure_slot_style(style: StyleBoxFlat, fill: Color, border: Color, border_width: int) -> void:
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS


func _position_on_table_frame() -> void:
	var slot_area_size := Vector2(
		SLOT_PADDING * 2.0 + SLOT_SIZE.x * SLOT_COUNT + SLOT_GAP * (SLOT_COUNT - 1),
		SLOT_PADDING * 2.0 + SLOT_SIZE.y
	)
	size = slot_area_size
	custom_minimum_size = slot_area_size

	var table_rect := _get_table_outer_rect()
	var frame_anchor_x := table_rect.position.x + table_rect.size.x * UPPER_RIGHT_FRAME_ANCHOR_RATIO
	var slot_position := Vector2(
		frame_anchor_x - slot_area_size.x * 0.5,
		table_rect.position.y + FRAME_TOP_INSET
	)
	position = slot_position


func _get_table_outer_rect() -> Rect2:
	if table != null:
		return table.TABLE_OUTER_RECT
	return Rect2(400, 220, 1120, 640)


func _on_reserve_slots_changed(slots: Array) -> void:
	slot_snapshots = slots.duplicate(true)
	queue_redraw()


func _on_mouse_exited() -> void:
	if hovered_slot_index == -1:
		return
	hovered_slot_index = -1
	hover_changes += 1
	queue_redraw()


func _update_hovered_slot(local_position: Vector2) -> void:
	var next_hovered_slot := _get_slot_index_at_position(local_position)
	if next_hovered_slot == hovered_slot_index:
		return

	hovered_slot_index = next_hovered_slot
	hover_changes += 1
	queue_redraw()


func _get_slot_index_at_position(local_position: Vector2) -> int:
	for slot_index in range(SLOT_COUNT):
		if _get_slot_rect(slot_index).has_point(local_position):
			return slot_index
	return -1


func _is_cue_drag_active() -> bool:
	return table != null and table.is_cue_drag_active()


func _get_slot_rect(slot_index: int) -> Rect2:
	var slot_x := SLOT_PADDING + slot_index * (SLOT_SIZE.x + SLOT_GAP)
	return Rect2(Vector2(slot_x, SLOT_PADDING), SLOT_SIZE)


func _get_slot_snapshot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slot_snapshots.size():
		return {}
	var snapshot = slot_snapshots[slot_index]
	if snapshot is Dictionary:
		return snapshot
	return {}


func _is_slot_filled(slot_index: int) -> bool:
	return bool(_get_slot_snapshot(slot_index).get("filled", false))


func _draw_deploying_slot_source(slot_rect: Rect2) -> void:
	var center := slot_rect.get_center()
	draw_circle(center, 12.0, DEPLOYING_SLOT_GLOW)
	draw_arc(center, 14.0, 0.0, TAU, 32, DEPLOYING_SLOT_RING, 2.0)
	draw_circle(center, 3.0, Color(1.0, 0.9, 0.55, 0.74))


func _draw_slot_icon(slot_rect: Rect2, icon_key: String) -> void:
	ITEM_ICON_DRAW.draw_icon(self, slot_rect, icon_key)
