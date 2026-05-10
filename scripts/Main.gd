extends Node2D

const FULLSCREEN_TOGGLE_KEY := KEY_F11

@onready var table: BilliardsTable = $Table
@onready var status_label: Label = $CanvasLayer/HUD/StatusLabel
@onready var result_label: Label = $CanvasLayer/HUD/ResultLabel
@onready var physics_debug_button: Button = $CanvasLayer/HUD/PhysicsDebugButton
@onready var physics_debug_panel: PanelContainer = $CanvasLayer/HUD/PhysicsDebugPanel
@onready var physics_debug_label: Label = $CanvasLayer/HUD/PhysicsDebugPanel/Margin/PhysicsDebugLabel


func _ready() -> void:
	table.status_text_changed.connect(_on_status_text_changed)
	table.game_finished.connect(_on_game_finished)
	physics_debug_button.pressed.connect(_on_physics_debug_button_pressed)
	result_label.text = ""
	physics_debug_panel.visible = false
	_update_physics_debug_button_text()


func _process(_delta: float) -> void:
	if not physics_debug_panel.visible:
		return

	physics_debug_label.text = table.get_physics_debug_text()


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


func _on_status_text_changed(text: String) -> void:
	status_label.text = text


func _on_game_finished(text: String) -> void:
	result_label.text = text


func _on_physics_debug_button_pressed() -> void:
	physics_debug_panel.visible = not physics_debug_panel.visible
	if physics_debug_panel.visible:
		physics_debug_label.text = table.get_physics_debug_text()
	_update_physics_debug_button_text()


func _update_physics_debug_button_text() -> void:
	physics_debug_button.text = "Hide Physics Debug" if physics_debug_panel.visible else "Physics Debug"


func _toggle_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
