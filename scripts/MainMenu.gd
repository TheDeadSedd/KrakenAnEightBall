extends Control
class_name MainMenu

# index:title Main Menu
# index:category UI / Presentation
# index:status In Progress
# index:owner ui_agent
# index:notes Lightweight title screen shell using layered main menu artwork as the primary visual foundation.

const GAMEPLAY_SCENE_PATH := "res://scenes/Main.tscn"
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const BACKGROUND_TEXTURE := preload("res://assets/ui/mainmenu_bg.png")
const FOREGROUND_TEXTURE := preload("res://assets/ui/mainmenu_fg.png")
const PRESENTATION_OVERLAY_SCRIPT := preload("res://scripts/MainMenuPresentationOverlay.gd")
const OPTIONS_MENU_SCRIPT := preload("res://scripts/OptionsMenu.gd")
const RUN_HISTORY_SCRIPT := preload("res://scripts/RunHistorySystem.gd")
const HISTORY_PANEL_SIZE := Vector2(780.0, 610.0)
const HISTORY_EMPTY_TEXT := "No voyages logged yet."

var background_layer: TextureRect
var behind_foreground_overlay: MainMenuPresentationOverlay
var foreground_layer: TextureRect
var fog_overlay: MainMenuPresentationOverlay
var menu_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var status_label: Label
var start_button: Button
var options_button: Button
var run_history_button: Button
var quit_button: Button
var options_panel: OptionsMenu
var run_history_system: RunHistorySystem
var run_history_panel: PanelContainer
var run_history_list: VBoxContainer
var run_history_empty_label: Label
var run_history_back_button: Button


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	AudioSettings.load_and_apply()
	run_history_system = RUN_HISTORY_SCRIPT.new()
	run_history_system.name = "RunHistorySystem"
	add_child(run_history_system)
	_build_scene_layers()
	_build_interface()
	_update_menu_layout()
	start_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_menu_layout()


func _build_scene_layers() -> void:
	background_layer = _make_fullscreen_texture_layer("BackgroundLayer", BACKGROUND_TEXTURE)
	add_child(background_layer)

	behind_foreground_overlay = _make_presentation_overlay("BehindForegroundOverlay")
	behind_foreground_overlay.draw_fog_enabled = false
	add_child(behind_foreground_overlay)

	foreground_layer = _make_fullscreen_texture_layer("ForegroundLayer", FOREGROUND_TEXTURE)
	add_child(foreground_layer)

	fog_overlay = _make_presentation_overlay("FogOverlay")
	fog_overlay.draw_moon_glow_enabled = false
	fog_overlay.draw_star_twinkles_enabled = false
	fog_overlay.draw_ocean_shimmer_enabled = false
	add_child(fog_overlay)


func _make_fullscreen_texture_layer(layer_name: String, texture: Texture2D) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(layer)
	return layer


func _make_presentation_overlay(layer_name: String) -> MainMenuPresentationOverlay:
	var overlay: MainMenuPresentationOverlay = PRESENTATION_OVERLAY_SCRIPT.new()
	overlay.name = layer_name
	_set_full_rect(overlay)
	return overlay


func _build_interface() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.name = "MenuPanel"
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(menu_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	menu_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 13)
	margin.add_child(stack)

	title_label = Label.new()
	title_label.text = "KRAKEN AN\nEIGHT BALL"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.018, 0.012, 0.95))
	title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	title_label.add_theme_constant_override("outline_size", 7)
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	stack.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.text = "Arcade billiards on a troublesome sea"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_override("font", UI_FONT)
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.90, 0.95))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	subtitle_label.add_theme_constant_override("outline_size", 3)
	stack.add_child(subtitle_label)

	stack.add_child(_make_gap(10.0))
	start_button = _make_menu_button("Start Run")
	options_button = _make_menu_button("Options")
	run_history_button = _make_menu_button("Run History")
	quit_button = _make_menu_button("Quit")
	stack.add_child(start_button)
	stack.add_child(options_button)
	stack.add_child(run_history_button)
	stack.add_child(quit_button)

	status_label = Label.new()
	status_label.text = "The moon is high. The table waits."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_override("font", UI_FONT)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color(0.74, 0.83, 0.80, 0.90))
	status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	status_label.add_theme_constant_override("outline_size", 2)
	stack.add_child(_make_gap(4.0))
	stack.add_child(status_label)

	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	run_history_button.pressed.connect(_on_run_history_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	options_panel = OPTIONS_MENU_SCRIPT.new()
	options_panel.name = "OptionsPanel"
	options_panel.visible = false
	options_panel.back_requested.connect(_on_options_back_requested)
	add_child(options_panel)

	_build_run_history_panel()


func _set_full_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _make_gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1.0, height)
	return spacer


func _make_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(290.0, 54.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.78, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.09, 0.03, 1.0))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.09, 0.063, 0.041, 0.90), Color(0.88, 0.68, 0.32, 0.58)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.15, 0.096, 0.044, 0.98), Color(1.0, 0.82, 0.38, 0.94)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.88, 0.67, 0.31, 0.98), Color(1.0, 0.91, 0.62, 1.0)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.11, 0.070, 0.038, 0.96), Color(0.64, 0.95, 0.88, 0.78)))
	return button


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.018, 0.026, 0.66)
	style.border_color = Color(0.92, 0.72, 0.32, 0.38)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0.0, 8.0)
	return style


func _make_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_content_margin(SIDE_LEFT, 18.0)
	style.set_content_margin(SIDE_RIGHT, 18.0)
	style.set_content_margin(SIDE_TOP, 10.0)
	style.set_content_margin(SIDE_BOTTOM, 6.0)
	return style


func _make_history_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.026, 0.018, 0.82)
	style.border_color = Color(0.96, 0.78, 0.34, 0.28)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _build_run_history_panel() -> void:
	run_history_panel = PanelContainer.new()
	run_history_panel.name = "RunHistoryPanel"
	run_history_panel.visible = false
	run_history_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	run_history_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(run_history_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	run_history_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = "Run History"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.018, 0.012, 0.95))
	title_label.add_theme_constant_override("outline_size", 4)
	stack.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Most recent voyages"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_override("font", UI_FONT)
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.90, 0.92))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	subtitle_label.add_theme_constant_override("outline_size", 2)
	stack.add_child(subtitle_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(690.0, 410.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(scroll)

	run_history_list = VBoxContainer.new()
	run_history_list.add_theme_constant_override("separation", 8)
	run_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(run_history_list)

	run_history_empty_label = Label.new()
	run_history_empty_label.text = HISTORY_EMPTY_TEXT
	run_history_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	run_history_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	run_history_empty_label.custom_minimum_size = Vector2(680.0, 180.0)
	run_history_empty_label.add_theme_font_override("font", UI_FONT)
	run_history_empty_label.add_theme_font_size_override("font_size", 24)
	run_history_empty_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.78, 0.9))
	run_history_empty_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	run_history_empty_label.add_theme_constant_override("outline_size", 2)

	run_history_back_button = _make_menu_button("Back")
	run_history_back_button.custom_minimum_size = Vector2(230.0, 48.0)
	run_history_back_button.add_theme_font_size_override("font_size", 24)
	stack.add_child(run_history_back_button)
	run_history_back_button.pressed.connect(_on_run_history_back_pressed)


func _update_menu_layout() -> void:
	if menu_panel == null:
		return

	var viewport_size: Vector2 = size
	var panel_width: float = clampf(viewport_size.x * 0.28, 390.0, 520.0)
	var panel_height: float = clampf(viewport_size.y * 0.60, 560.0, 700.0)
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -panel_width * 0.5
	menu_panel.offset_right = panel_width * 0.5
	menu_panel.offset_top = -panel_height * 0.5
	menu_panel.offset_bottom = panel_height * 0.5

	if options_panel != null:
		var options_width: float = clampf(viewport_size.x * 0.34, 560.0, 700.0)
		var options_height: float = clampf(viewport_size.y * 0.48, 430.0, 560.0)
		options_panel.anchor_left = 0.5
		options_panel.anchor_right = 0.5
		options_panel.anchor_top = 0.5
		options_panel.anchor_bottom = 0.5
		options_panel.offset_left = -options_width * 0.5
		options_panel.offset_right = options_width * 0.5
		options_panel.offset_top = -options_height * 0.5
		options_panel.offset_bottom = options_height * 0.5

	if run_history_panel != null:
		var history_width: float = clampf(viewport_size.x * 0.48, HISTORY_PANEL_SIZE.x, 920.0)
		var history_height: float = clampf(viewport_size.y * 0.66, HISTORY_PANEL_SIZE.y, 720.0)
		run_history_panel.anchor_left = 0.5
		run_history_panel.anchor_right = 0.5
		run_history_panel.anchor_top = 0.5
		run_history_panel.anchor_bottom = 0.5
		run_history_panel.offset_left = -history_width * 0.5
		run_history_panel.offset_right = history_width * 0.5
		run_history_panel.offset_top = -history_height * 0.5
		run_history_panel.offset_bottom = history_height * 0.5


func _rebuild_run_history_list() -> void:
	if run_history_system == null or run_history_list == null:
		return

	run_history_system.load_history()
	_clear_run_history_list()
	var records: Array = run_history_system.get_records_snapshot()
	if records.is_empty():
		run_history_list.add_child(run_history_empty_label)
		return

	for record_value in records:
		if record_value is Dictionary:
			run_history_list.add_child(_make_run_history_row(record_value as Dictionary))


func _clear_run_history_list() -> void:
	for child in run_history_list.get_children():
		run_history_list.remove_child(child)
		if child != run_history_empty_label:
			child.queue_free()


func _make_run_history_row(record: Dictionary) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.add_theme_stylebox_override("panel", _make_history_row_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	row_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	var timestamp_label := _make_history_label(str(record.get("timestamp", "Unknown voyage")), 19, Color(1.0, 0.88, 0.48, 1.0))
	stack.add_child(timestamp_label)
	stack.add_child(_make_history_label(
		"Time %s    Final %s Doubloons    Earned %s" % [
			_format_run_duration(float(record.get("run_duration", 0.0))),
			maxi(int(record.get("final_doubloons", 0)), 0),
			maxi(int(record.get("doubloons_earned", 0)), 0),
		],
		16,
		Color(0.88, 0.86, 0.76, 0.96)
	))
	stack.add_child(_make_history_label(
		"Sunk %s    Best Streak X%s    Interventions %s" % [
			maxi(int(record.get("balls_sunk", 0)), 0),
			maxi(int(record.get("highest_pocket_streak", 1)), 1),
			maxi(int(record.get("interventions_triggered", 0)), 0),
		],
		16,
		Color(0.78, 0.92, 0.90, 0.92)
	))
	stack.add_child(_make_history_label(
		"Contraband %s    Treasure %s    Final Balls %s" % [
			maxi(int(record.get("contraband_found", 0)), 0),
			maxi(int(record.get("treasure_claimed", 0)), 0),
			maxi(int(record.get("final_ball_count", 0)), 0),
		],
		16,
		Color(1.0, 0.84, 0.36, 0.94)
	))
	return row_panel


func _make_history_label(text: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _format_run_duration(seconds_value: float) -> String:
	var total_seconds := maxi(int(floor(seconds_value)), 0)
	var hours := int(total_seconds / 3600)
	var minutes := int((total_seconds % 3600) / 60)
	var seconds := total_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func _on_start_pressed() -> void:
	start_button.disabled = true
	status_label.text = "Casting off..."
	var error_code: int = get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
	if error_code != OK:
		start_button.disabled = false
		status_label.text = "Could not load the table. Error %s" % error_code


func _on_options_pressed() -> void:
	menu_panel.visible = false
	if run_history_panel != null:
		run_history_panel.visible = false
	options_panel.visible = true
	options_panel.refresh_from_audio_settings()
	options_panel.grab_default_focus()


func _on_options_back_requested() -> void:
	options_panel.visible = false
	menu_panel.visible = true
	status_label.text = "The moon is high. The table waits."
	options_button.grab_focus()


func _on_run_history_pressed() -> void:
	menu_panel.visible = false
	if options_panel != null:
		options_panel.visible = false
	_rebuild_run_history_list()
	run_history_panel.visible = true
	run_history_back_button.grab_focus()


func _on_run_history_back_pressed() -> void:
	run_history_panel.visible = false
	menu_panel.visible = true
	status_label.text = "The moon is high. The ledger waits."
	run_history_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
