extends Node2D
class_name BallPlacementSystem

signal placement_confirmed(item_id: String, position: Vector2)
signal placement_canceled(item_id: String)

# Owns reusable "place a ball on the table" interaction state. Shop systems,
# rewards, tutorials, or debug tools can request placement without owning input.
const PREVIEW_VALID_FILL := Color(0.2, 1.0, 0.48, 0.34)
const PREVIEW_VALID_OUTLINE := Color(0.62, 1.0, 0.72, 0.92)
const PREVIEW_INVALID_FILL := Color(1.0, 0.18, 0.16, 0.30)
const PREVIEW_INVALID_OUTLINE := Color(1.0, 0.52, 0.42, 0.95)
const PREVIEW_OUTLINE_WIDTH := 3.0

var table
var active_item_id := ""
var active_item_name := ""
var preview_position := Vector2.ZERO
var preview_radius := 18.0
var preview_valid := false
var invalid_reason := "Inactive"
var pending_screen_position := Vector2.ZERO
var preview_dirty := false
var validation_checks := 0
var confirm_count := 0
var cancel_count := 0
var invalid_confirm_count := 0


func setup(table_ref) -> void:
	table = table_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	visible = false
	z_index = 40


func start_placement(item_id: String, item_name: String, ball_radius: float) -> void:
	active_item_id = item_id
	active_item_name = item_name
	preview_radius = ball_radius
	visible = true
	_set_pending_preview_position(get_viewport().get_mouse_position())
	_flush_preview_update()
	queue_redraw()


func cancel_placement() -> void:
	if not is_placement_active():
		return

	var canceled_item_id := active_item_id
	cancel_count += 1
	_clear_placement()
	placement_canceled.emit(canceled_item_id)


func is_placement_active() -> bool:
	return active_item_id != ""


func get_debug_snapshot() -> Dictionary:
	return {
		"active": is_placement_active(),
		"item_id": active_item_id,
		"item_name": active_item_name,
		"valid": preview_valid,
		"invalid_reason": invalid_reason,
		"validation_checks": validation_checks,
		"confirms": confirm_count,
		"cancels": cancel_count,
		"invalid_confirms": invalid_confirm_count,
	}


func _input(event: InputEvent) -> void:
	if not is_placement_active():
		return

	if event is InputEventMouseMotion:
		_handle_pointer_motion(event.position)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_pointer_motion(event.position)


func _process(_delta: float) -> void:
	if is_placement_active() and preview_dirty:
		_flush_preview_update()


func _draw() -> void:
	if not is_placement_active():
		return

	var fill_color := PREVIEW_VALID_FILL if preview_valid else PREVIEW_INVALID_FILL
	var outline_color := PREVIEW_VALID_OUTLINE if preview_valid else PREVIEW_INVALID_OUTLINE
	draw_circle(preview_position, preview_radius, fill_color)
	draw_arc(preview_position, preview_radius, 0.0, TAU, 48, outline_color, PREVIEW_OUTLINE_WIDTH, true)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_placement()
		get_viewport().set_input_as_handled()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	_set_pending_preview_position(event.position)
	_flush_preview_update()
	if not _is_position_in_placement_area(preview_position):
		return

	if event.pressed:
		_try_confirm_placement()
	get_viewport().set_input_as_handled()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	_set_pending_preview_position(event.position)
	_flush_preview_update()
	if not _is_position_in_placement_area(preview_position):
		return

	if event.pressed:
		_try_confirm_placement()
	get_viewport().set_input_as_handled()


func _handle_pointer_motion(screen_position: Vector2) -> void:
	_set_pending_preview_position(screen_position)
	var pending_table_position: Vector2 = _screen_to_table_position(screen_position)
	if _is_position_in_placement_area(pending_table_position):
		get_viewport().set_input_as_handled()


func _try_confirm_placement() -> void:
	if not preview_valid:
		invalid_confirm_count += 1
		return

	var confirmed_item_id := active_item_id
	var confirmed_position := preview_position
	confirm_count += 1
	_clear_placement()
	placement_confirmed.emit(confirmed_item_id, confirmed_position)


# Mouse motion can be noisy; placement validation is coalesced to one flush.
func _set_pending_preview_position(screen_position: Vector2) -> void:
	pending_screen_position = screen_position
	preview_dirty = true


func _flush_preview_update() -> void:
	if not preview_dirty:
		return

	preview_position = _screen_to_table_position(pending_screen_position)
	preview_dirty = false
	_refresh_validation()
	queue_redraw()


func _refresh_validation() -> void:
	validation_checks += 1
	if table == null or table.spawn_system == null:
		preview_valid = false
		invalid_reason = "No placement validator"
		return

	var result: Dictionary = table.spawn_system.get_manual_placement_validation(preview_position, preview_radius)
	preview_valid = bool(result.get("valid", false))
	invalid_reason = str(result.get("reason", "Invalid"))


func _is_position_in_placement_area(position: Vector2) -> bool:
	if table == null:
		return false
	return table.playfield_rect.grow(preview_radius).has_point(position)


func _screen_to_table_position(screen_position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * screen_position


func _clear_placement() -> void:
	active_item_id = ""
	active_item_name = ""
	preview_valid = false
	invalid_reason = "Inactive"
	preview_dirty = false
	visible = false
	queue_redraw()
