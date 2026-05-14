extends Node2D

const FULLSCREEN_TOGGLE_KEY := KEY_F11
const PAUSE_TOGGLE_KEY := KEY_ESCAPE

@onready var table: BilliardsTable = $Table
@onready var debug_overlay: DebugOverlay = $CanvasLayer/HUD
@onready var pause_menu: PauseMenu = $CanvasLayer/HUD/PauseMenu
@onready var status_label: Label = $CanvasLayer/HUD/StatusLabel
@onready var result_label: Label = $CanvasLayer/HUD/ResultLabel
@onready var doubloons_label: Label = $CanvasLayer/HUD/DoubloonsLabel
@onready var ball_drop_meter: BallDropMeter = $CanvasLayer/HUD/BallDropMeter


func _ready() -> void:
	_configure_pause_process_modes()
	debug_overlay.visible = true
	table.status_text_changed.connect(_on_status_text_changed)
	table.game_finished.connect(_on_game_finished)
	table.score_system.doubloons_changed.connect(_on_doubloons_changed)
	if not pause_menu.resume_requested.is_connected(_on_pause_resume_requested):
		pause_menu.resume_requested.connect(_on_pause_resume_requested)
	if not pause_menu.debug_panel_toggled.is_connected(_on_pause_debug_panel_toggled):
		pause_menu.debug_panel_toggled.connect(_on_pause_debug_panel_toggled)
	result_label.text = ""
	_on_doubloons_changed(table.score_system.get_doubloons_total())
	ball_drop_meter.setup(table.ball_drop_system)
	table.emit_ready_status_if_needed(status_label.text)
	debug_overlay.setup(table)
	pause_menu.set_debug_panel_states(debug_overlay.get_modular_debug_panel_states())


func _configure_pause_process_modes() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	table.process_mode = Node.PROCESS_MODE_PAUSABLE
	debug_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	ball_drop_meter.process_mode = Node.PROCESS_MODE_PAUSABLE


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == PAUSE_TOGGLE_KEY:
		_set_game_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


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


func _on_pause_resume_requested() -> void:
	_set_game_paused(false)


func _on_pause_debug_panel_toggled(panel_id: String, enabled: bool) -> void:
	debug_overlay.set_modular_debug_panel_visible(panel_id, enabled)


func _set_game_paused(paused: bool) -> void:
	if paused == get_tree().paused and pause_menu.visible == paused:
		return

	if paused:
		table.cancel_active_cue_drag_for_pause()
		get_tree().paused = true
		pause_menu.set_pause_visible(true)
	else:
		pause_menu.set_pause_visible(false)
		get_tree().paused = false


func _toggle_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
