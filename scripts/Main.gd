extends Node2D

const FULLSCREEN_TOGGLE_KEY := KEY_F11
const DEBUG_MENU_TOGGLE_KEY := KEY_QUOTELEFT
const PERFORMANCE_OVERLAY_TOGGLE_KEY := KEY_F3
const PERFORMANCE_OVERLAY_DRAG_HEIGHT := 34.0

@onready var table: BilliardsTable = $Table
@onready var hud: Control = $CanvasLayer/HUD
@onready var status_label: Label = $CanvasLayer/HUD/StatusLabel
@onready var result_label: Label = $CanvasLayer/HUD/ResultLabel
@onready var physics_debug_panel: PanelContainer = $CanvasLayer/HUD/PhysicsDebugPanel
@onready var physics_debug_label: Label = $CanvasLayer/HUD/PhysicsDebugPanel/Margin/PhysicsDebugLabel
@onready var performance_overlay_panel: PanelContainer = $CanvasLayer/HUD/PerformanceOverlayPanel
@onready var performance_overlay_label: Label = $CanvasLayer/HUD/PerformanceOverlayPanel/Margin/PerformanceOverlayLabel
@onready var debug_menu_panel: PanelContainer = $CanvasLayer/HUD/DebugMenuPanel
@onready var shot_path_check_box: CheckBox = $CanvasLayer/HUD/DebugMenuPanel/Margin/VBox/ShotPathCheckBox
@onready var physics_debug_check_box: CheckBox = $CanvasLayer/HUD/DebugMenuPanel/Margin/VBox/PhysicsDebugCheckBox
@onready var performance_overlay_check_box: CheckBox = $CanvasLayer/HUD/DebugMenuPanel/Margin/VBox/PerformanceOverlayCheckBox
@onready var debug_hotkey_label: Label = $CanvasLayer/HUD/DebugMenuPanel/Margin/VBox/DebugHotkeyLabel

var is_dragging_performance_overlay := false
var performance_overlay_drag_offset := Vector2.ZERO


func _ready() -> void:
	hud.visible = true
	table.status_text_changed.connect(_on_status_text_changed)
	table.game_finished.connect(_on_game_finished)
	shot_path_check_box.toggled.connect(_on_shot_path_debug_toggled)
	physics_debug_check_box.toggled.connect(_on_physics_debug_toggled)
	performance_overlay_check_box.toggled.connect(_on_performance_overlay_toggled)
	result_label.text = ""
	debug_menu_panel.visible = false
	physics_debug_panel.visible = false
	performance_overlay_panel.visible = false
	shot_path_check_box.button_pressed = table.is_shot_path_debug_enabled()
	physics_debug_check_box.button_pressed = false
	performance_overlay_check_box.button_pressed = false
	debug_hotkey_label.text = "%s\n%s: Performance Overlay" % [
		table.get_debug_spawn_hotkey_text(),
		OS.get_keycode_string(PERFORMANCE_OVERLAY_TOGGLE_KEY),
	]


func _input(event: InputEvent) -> void:
	if _handle_performance_overlay_drag(event):
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if physics_debug_panel.visible:
		physics_debug_label.text = table.get_physics_debug_text()

	if performance_overlay_panel.visible:
		performance_overlay_label.text = table.get_performance_debug_text()


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


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == FULLSCREEN_TOGGLE_KEY:
		_toggle_fullscreen()
	elif key_event.alt_pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
		_toggle_fullscreen()
	elif key_event.keycode == DEBUG_MENU_TOGGLE_KEY:
		_toggle_debug_menu()
	elif key_event.keycode == PERFORMANCE_OVERLAY_TOGGLE_KEY:
		_toggle_performance_overlay()


func _on_status_text_changed(text: String) -> void:
	status_label.text = text


func _on_game_finished(text: String) -> void:
	result_label.text = text


func _on_shot_path_debug_toggled(enabled: bool) -> void:
	table.set_shot_path_debug_enabled(enabled)


func _on_physics_debug_toggled(enabled: bool) -> void:
	physics_debug_panel.visible = enabled
	if enabled:
		physics_debug_label.text = table.get_physics_debug_text()


func _on_performance_overlay_toggled(enabled: bool) -> void:
	performance_overlay_panel.visible = enabled
	if enabled:
		performance_overlay_label.text = table.get_performance_debug_text()


func _toggle_debug_menu() -> void:
	debug_menu_panel.visible = not debug_menu_panel.visible


func _toggle_performance_overlay() -> void:
	performance_overlay_check_box.button_pressed = not performance_overlay_check_box.button_pressed


func _toggle_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
