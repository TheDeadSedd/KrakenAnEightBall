extends Control
class_name DebugOverlay

# Owns debug UI state, text formatting, and movable overlay behavior.
# Table.gd still owns the gameplay counters/data that this panel displays.
const DEBUG_MENU_TOGGLE_KEY := KEY_QUOTELEFT
const PERFORMANCE_OVERLAY_TOGGLE_KEY := KEY_F3
const PERFORMANCE_OVERLAY_DRAG_HEIGHT := 34.0

@onready var physics_debug_panel: PanelContainer = $PhysicsDebugPanel
@onready var physics_debug_label: Label = $PhysicsDebugPanel/Margin/PhysicsDebugLabel
@onready var performance_overlay_panel: PanelContainer = $PerformanceOverlayPanel
@onready var performance_overlay_label: Label = $PerformanceOverlayPanel/Margin/PerformanceOverlayLabel
@onready var debug_menu_panel: PanelContainer = $DebugMenuPanel
@onready var shot_path_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/ShotPathCheckBox
@onready var physics_debug_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/PhysicsDebugCheckBox
@onready var performance_overlay_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/PerformanceOverlayCheckBox
@onready var debug_hotkey_label: Label = $DebugMenuPanel/Margin/VBox/DebugHotkeyLabel

var table: BilliardsTable
var is_dragging_performance_overlay := false
var performance_overlay_drag_offset := Vector2.ZERO


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	debug_menu_panel.visible = false
	physics_debug_panel.visible = false
	performance_overlay_panel.visible = false
	shot_path_check_box.set_pressed_no_signal(table.is_shot_path_debug_enabled())
	physics_debug_check_box.set_pressed_no_signal(false)
	performance_overlay_check_box.set_pressed_no_signal(false)
	debug_hotkey_label.text = _make_debug_hotkey_text()
	_connect_debug_controls()


func _connect_debug_controls() -> void:
	if not shot_path_check_box.toggled.is_connected(_on_shot_path_debug_toggled):
		shot_path_check_box.toggled.connect(_on_shot_path_debug_toggled)
	if not physics_debug_check_box.toggled.is_connected(_on_physics_debug_toggled):
		physics_debug_check_box.toggled.connect(_on_physics_debug_toggled)
	if not performance_overlay_check_box.toggled.is_connected(_on_performance_overlay_toggled):
		performance_overlay_check_box.toggled.connect(_on_performance_overlay_toggled)


func _input(event: InputEvent) -> void:
	if _handle_performance_overlay_drag(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == DEBUG_MENU_TOGGLE_KEY:
		_toggle_debug_menu()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == PERFORMANCE_OVERLAY_TOGGLE_KEY:
		_toggle_performance_overlay()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if table == null:
		return

	if physics_debug_panel.visible:
		physics_debug_label.text = _make_physics_debug_text()

	if performance_overlay_panel.visible:
		performance_overlay_label.text = _make_performance_debug_text()


func _handle_performance_overlay_drag(event: InputEvent) -> bool:
	if not performance_overlay_panel.visible:
		is_dragging_performance_overlay = false
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return _handle_performance_overlay_mouse_button(event)

	if event is InputEventMouseMotion and is_dragging_performance_overlay:
		performance_overlay_panel.position = event.position - performance_overlay_drag_offset
		return true

	return false


func _handle_performance_overlay_mouse_button(event: InputEventMouseButton) -> bool:
	if event.pressed and _is_position_in_performance_overlay_header(event.position):
		is_dragging_performance_overlay = true
		performance_overlay_drag_offset = event.position - performance_overlay_panel.position
		return true

	if not event.pressed and is_dragging_performance_overlay:
		is_dragging_performance_overlay = false
		return true

	return false


func _is_position_in_performance_overlay_header(position: Vector2) -> bool:
	var overlay_rect := Rect2(performance_overlay_panel.position, performance_overlay_panel.size)
	var header_rect := Rect2(overlay_rect.position, Vector2(overlay_rect.size.x, PERFORMANCE_OVERLAY_DRAG_HEIGHT))
	return header_rect.has_point(position)


func _toggle_debug_menu() -> void:
	debug_menu_panel.visible = not debug_menu_panel.visible


func _toggle_performance_overlay() -> void:
	performance_overlay_check_box.button_pressed = not performance_overlay_check_box.button_pressed


func _on_shot_path_debug_toggled(enabled: bool) -> void:
	table.set_shot_path_debug_enabled(enabled)


func _on_physics_debug_toggled(enabled: bool) -> void:
	physics_debug_panel.visible = enabled
	if enabled:
		physics_debug_label.text = _make_physics_debug_text()


func _on_performance_overlay_toggled(enabled: bool) -> void:
	performance_overlay_panel.visible = enabled
	if enabled:
		performance_overlay_label.text = _make_performance_debug_text()


func _make_debug_hotkey_text() -> String:
	var hotkeys: Dictionary = table.get_debug_spawn_hotkey_data()
	return "%s: Spawn Wayfinder Ball\n%s: Spawn Normal Ball\n%s: Performance Overlay" % [
		OS.get_keycode_string(int(hotkeys["wayfinder_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["normal_spawn_key"])),
		OS.get_keycode_string(PERFORMANCE_OVERLAY_TOGGLE_KEY),
	]


func _make_physics_debug_text() -> String:
	var snapshot: Dictionary = table.get_physics_debug_snapshot()
	if not bool(snapshot["enabled"]):
		return "Physics debug disabled."

	var moving_balls: Array = snapshot["moving_balls"]
	var speed_threshold: float = float(snapshot["speed_threshold"])
	if moving_balls.is_empty():
		return "No balls above %.1f speed." % speed_threshold

	moving_balls.sort_custom(_sort_ball_debug_snapshots_by_speed)
	var lines: Array[String] = []
	var max_count: int = mini(int(snapshot["max_balls"]), moving_balls.size())
	for index in range(max_count):
		lines.append(_get_physics_debug_line(moving_balls[index]))

	return "\n".join(lines)


func _make_performance_debug_text() -> String:
	var snapshot: Dictionary = table.get_performance_debug_snapshot()
	var lines := [
		"PERFORMANCE",
		"FPS: %s" % Engine.get_frames_per_second(),
		"Balls: %s total / %s moving / %s stopped" % [
			snapshot["total_balls"],
			snapshot["moving_balls"],
			snapshot["stopped_balls"],
		],
		"Wayfinders: %s active / %s guided" % [
			snapshot["active_wayfinders"],
			snapshot["guided_wayfinder_targets"],
		],
		"Substeps: %s" % snapshot["physics_substeps"],
		"Grid cells: %s / max cell: %s" % [
			snapshot["spatial_grid_cells"],
			snapshot["spatial_grid_max_cell_size"],
		],
		"Broad-phase candidates: %s" % snapshot["broadphase_candidate_pairs"],
		"Ball pairs checked: %s" % snapshot["ball_pair_checks"],
		"Ball collisions: %s" % snapshot["ball_collisions_resolved"],
		"Rail checks: %s" % snapshot["rail_checks"],
		"Rail collisions: %s" % snapshot["rail_collisions_resolved"],
		"Pocket checks: %s" % snapshot["pocket_checks"],
		"Pocket captures: %s" % snapshot["pocket_captures"],
		"Aim prediction: %s" % _debug_bool_text(bool(snapshot["aim_prediction_enabled"])),
		"Shot comparison: %s" % _debug_bool_text(bool(snapshot["shot_comparison_enabled"])),
		"Physics ms: %.2f" % float(snapshot["physics_process_ms"]),
		"Ball collision ms: %.2f" % float(snapshot["ball_collision_ms"]),
		"Rail ms: %.2f" % float(snapshot["rail_collision_ms"]),
		"Pocket ms: %.2f" % float(snapshot["pocket_check_ms"]),
		"Aim prediction ms: %.2f" % float(snapshot["aim_prediction_ms"]),
	]
	return "\n".join(lines)


func _sort_ball_debug_snapshots_by_speed(ball_a: Dictionary, ball_b: Dictionary) -> bool:
	return float(ball_a["speed"]) > float(ball_b["speed"])


func _get_physics_debug_line(ball_data: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(_get_ball_debug_name(ball_data))
	parts.append("speed %.1f" % float(ball_data["speed"]))
	parts.append(_get_ball_drag_band_name(ball_data))
	if bool(ball_data["wayfinder_active"]):
		parts.append("active")
	if bool(ball_data["guided"]):
		parts.append("guided")
	if not bool(ball_data["gameplay_enabled"]):
		parts.append("paused")
	return " | ".join(parts)


func _get_ball_debug_name(ball_data: Dictionary) -> String:
	if bool(ball_data["is_cue_ball"]):
		return "Cue Ball"
	if bool(ball_data["is_eight_ball"]):
		return "8 Ball"
	if bool(ball_data["is_wayfinder"]):
		return "Wayfinder Ball"
	return "Ball %s" % ball_data["ball_number"]


func _get_ball_drag_band_name(ball_data: Dictionary) -> String:
	var speed: float = float(ball_data["speed"])
	if speed >= float(ball_data["medium_speed_drag_start"]):
		return "high"
	if speed >= float(ball_data["low_speed_drag_start"]):
		return "medium"
	if speed >= float(ball_data["crawl_speed_drag_start"]):
		return "low"
	return "crawl"


func _debug_bool_text(enabled: bool) -> String:
	return "enabled" if enabled else "disabled"
