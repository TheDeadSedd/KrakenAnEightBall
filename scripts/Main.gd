extends Node2D

const FULLSCREEN_TOGGLE_KEY := KEY_F11

@onready var table: BilliardsTable = $Table
@onready var debug_overlay: DebugOverlay = $CanvasLayer/HUD
@onready var status_label: Label = $CanvasLayer/HUD/StatusLabel
@onready var result_label: Label = $CanvasLayer/HUD/ResultLabel
@onready var doubloons_label: Label = $CanvasLayer/HUD/DoubloonsLabel


func _ready() -> void:
	debug_overlay.visible = true
	table.status_text_changed.connect(_on_status_text_changed)
	table.game_finished.connect(_on_game_finished)
	table.score_system.doubloons_changed.connect(_on_doubloons_changed)
	result_label.text = ""
	_on_doubloons_changed(table.score_system.get_doubloons_total())
	debug_overlay.setup(table)


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


func _on_doubloons_changed(total: int) -> void:
	doubloons_label.text = "Doubloons: %s" % total


func _toggle_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
