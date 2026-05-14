extends PanelContainer
class_name DebugPanel

# Reusable debug panel shell. It consumes direct panel clicks so they do not
# leak into cue input, while leaving empty HUD space transparent to gameplay.
@export var draggable := true
@export var drag_header_height := 34.0

var is_dragging_panel := false
var clicked_inside_panel := false
var drag_offset := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	set_process_input(true)


func _process(_delta: float) -> void:
	if (is_dragging_panel or clicked_inside_panel) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging_panel = false
		clicked_inside_panel = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _handle_mouse_button(event.pressed, event.position):
			accept_event()
	elif event is InputEventMouseMotion:
		if _handle_mouse_motion(get_global_mouse_position()):
			accept_event()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	# Pause-menu shade can sit above panels in the normal GUI path; direct
	# hit checks keep visible panels draggable without exposing empty HUD space.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not get_global_rect().has_point(event.position):
			return
		if _handle_mouse_button(event.pressed, _get_panel_local_position(event.position)):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _handle_mouse_motion(event.position):
			get_viewport().set_input_as_handled()


func _handle_mouse_button(pressed: bool, local_position: Vector2) -> bool:
	if pressed:
		move_to_front()
		clicked_inside_panel = true
		if draggable and _is_position_in_header(local_position):
			is_dragging_panel = true
			drag_offset = local_position
		return true

	if is_dragging_panel or clicked_inside_panel:
		is_dragging_panel = false
		clicked_inside_panel = false
		return true

	return false


func _handle_mouse_motion(global_mouse_position: Vector2) -> bool:
	if is_dragging_panel:
		position = _get_parent_local_position(global_mouse_position) - drag_offset
		return true
	elif clicked_inside_panel:
		return true

	return false


func _get_panel_local_position(global_position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_position


func _get_parent_local_position(global_position: Vector2) -> Vector2:
	var parent_canvas_item := get_parent() as CanvasItem
	if parent_canvas_item == null:
		return global_position
	return parent_canvas_item.get_global_transform().affine_inverse() * global_position


func _is_position_in_header(local_position: Vector2) -> bool:
	return local_position.y >= 0.0 and local_position.y <= drag_header_height
