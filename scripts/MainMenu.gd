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
const RUN_HISTORY_PANEL_SCRIPT := preload("res://scripts/MainMenuRunHistoryPanel.gd")
const CUE_LOCKER_PANEL_SCRIPT := preload("res://scripts/MainMenuCueLockerPanel.gd")
const RUN_HISTORY_SCRIPT := preload("res://scripts/RunHistorySystem.gd")
const PROGRESSION_SCRIPT := preload("res://scripts/ProgressionSystem.gd")
const CUE_PROGRESSION_SCRIPT := preload("res://scripts/CueProgressionSystem.gd")
const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")
const CREDITS_MARGIN := Vector2(34.0, 28.0)
const CREDITS_HEIGHT := 154.0

var background_layer: TextureRect
var behind_foreground_overlay: MainMenuPresentationOverlay
var foreground_layer: TextureRect
var fog_overlay: MainMenuPresentationOverlay
var menu_panel: PanelContainer
var mode_select_panel: PanelContainer
var credits_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var status_label: Label
var kraken_favor_label: Label
var start_button: Button
var passage_mode_button: Button
var roguelite_mode_button: Button
var mode_select_back_button: Button
var options_button: Button
var cue_locker_button: Button
var run_history_button: Button
var quit_button: Button
var options_panel: OptionsMenu
var run_history_system: RunHistorySystem
var progression_system: ProgressionSystem
var cue_progression_system: CueProgressionSystem
var run_history_panel: MainMenuRunHistoryPanel
var cue_locker_panel: MainMenuCueLockerPanel


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	AudioSettings.load_and_apply()
	run_history_system = RUN_HISTORY_SCRIPT.new()
	run_history_system.name = "RunHistorySystem"
	add_child(run_history_system)
	progression_system = PROGRESSION_SCRIPT.new()
	progression_system.name = "ProgressionSystem"
	add_child(progression_system)
	cue_progression_system = CUE_PROGRESSION_SCRIPT.new()
	cue_progression_system.name = "CueProgressionSystem"
	add_child(cue_progression_system)
	cue_progression_system.cue_progression_changed.connect(_on_cue_progression_changed)
	cue_progression_system.status_changed.connect(_on_cue_progression_status_changed)
	cue_progression_system.setup(progression_system)
	_build_scene_layers()
	_build_interface()
	_update_menu_layout()
	_update_progression_display()
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
	cue_locker_button = _make_menu_button("Cue Locker")
	run_history_button = _make_menu_button("Run History")
	quit_button = _make_menu_button("Quit")
	stack.add_child(start_button)
	stack.add_child(options_button)
	stack.add_child(cue_locker_button)
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

	kraken_favor_label = Label.new()
	kraken_favor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kraken_favor_label.add_theme_font_override("font", UI_FONT)
	kraken_favor_label.add_theme_font_size_override("font_size", 20)
	kraken_favor_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36, 0.94))
	kraken_favor_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	kraken_favor_label.add_theme_constant_override("outline_size", 2)
	stack.add_child(kraken_favor_label)

	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	cue_locker_button.pressed.connect(_on_cue_locker_pressed)
	run_history_button.pressed.connect(_on_run_history_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_build_credits_block()
	_create_mode_select_panel()

	options_panel = OPTIONS_MENU_SCRIPT.new()
	options_panel.name = "OptionsPanel"
	options_panel.visible = false
	options_panel.back_requested.connect(_on_options_back_requested)
	add_child(options_panel)

	_create_run_history_panel()
	_create_cue_locker_panel()


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
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.58, 0.50, 0.58))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.09, 0.063, 0.041, 0.90), Color(0.88, 0.68, 0.32, 0.58)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.15, 0.096, 0.044, 0.98), Color(1.0, 0.82, 0.38, 0.94)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.88, 0.67, 0.31, 0.98), Color(1.0, 0.91, 0.62, 1.0)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.11, 0.070, 0.038, 0.96), Color(0.64, 0.95, 0.88, 0.78)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.050, 0.044, 0.043, 0.74), Color(0.45, 0.40, 0.32, 0.36)))
	return button


func _make_description_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.77, 0.86, 0.78, 0.88))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.68))
	label.add_theme_constant_override("outline_size", 2)
	return label


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


func _build_credits_block() -> void:
	credits_panel = PanelContainer.new()
	credits_panel.name = "CreditsPanel"
	credits_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_panel.add_theme_stylebox_override("panel", _make_credits_style())
	add_child(credits_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 11)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 11)
	credits_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)

	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "Credits"
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.50, 0.96))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.76))
	title.add_theme_constant_override("outline_size", 2)
	stack.add_child(title)

	var credit_lines := Label.new()
	credit_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credit_lines.text = "Background music by: Little Robot Sound Factory\nSome SFX by: Vrymaa\nFont by: Not Jam (Old Style 11)\nPlaceholder art: ChatGPT"
	credit_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	credit_lines.add_theme_font_override("font", UI_FONT)
	credit_lines.add_theme_font_size_override("font_size", 15)
	credit_lines.add_theme_color_override("font_color", Color(0.88, 0.78, 0.56, 0.88))
	credit_lines.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.68))
	credit_lines.add_theme_constant_override("outline_size", 2)
	stack.add_child(credit_lines)

	var artist_line := Label.new()
	artist_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artist_line.text = "Looking for artists to work with for final release"
	artist_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	artist_line.add_theme_font_override("font", UI_FONT)
	artist_line.add_theme_font_size_override("font_size", 13)
	artist_line.add_theme_color_override("font_color", Color(0.78, 0.86, 0.80, 0.72))
	artist_line.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.62))
	artist_line.add_theme_constant_override("outline_size", 2)
	stack.add_child(artist_line)


func _make_credits_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.015, 0.019, 0.54)
	style.border_color = Color(0.83, 0.64, 0.28, 0.30)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 11
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _create_run_history_panel() -> void:
	run_history_panel = RUN_HISTORY_PANEL_SCRIPT.new()
	run_history_panel.name = "RunHistoryPanel"
	run_history_panel.visible = false
	run_history_panel.setup(run_history_system)
	run_history_panel.back_requested.connect(_on_run_history_back_requested)
	add_child(run_history_panel)


func _create_cue_locker_panel() -> void:
	cue_locker_panel = CUE_LOCKER_PANEL_SCRIPT.new()
	cue_locker_panel.name = "CueLockerPanel"
	cue_locker_panel.visible = false
	cue_locker_panel.setup(cue_progression_system)
	cue_locker_panel.back_requested.connect(_on_cue_locker_back_requested)
	add_child(cue_locker_panel)


func _create_mode_select_panel() -> void:
	mode_select_panel = PanelContainer.new()
	mode_select_panel.name = "ModeSelectPanel"
	mode_select_panel.visible = false
	mode_select_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	mode_select_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(mode_select_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	mode_select_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "Choose Your Voyage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.03, 0.018, 0.012, 0.95))
	title.add_theme_constant_override("outline_size", 5)
	stack.add_child(title)

	stack.add_child(_make_gap(8.0))

	passage_mode_button = _make_menu_button("Passage")
	stack.add_child(passage_mode_button)
	stack.add_child(_make_description_label("The current full Kraken An Eight Ball run."))

	stack.add_child(_make_gap(8.0))

	roguelite_mode_button = _make_menu_button("The Long Sink")
	stack.add_child(roguelite_mode_button)
	stack.add_child(_make_description_label("A round-based roguelite voyage through escalating score quotas."))

	stack.add_child(_make_gap(12.0))

	mode_select_back_button = _make_menu_button("Back")
	stack.add_child(mode_select_back_button)

	passage_mode_button.pressed.connect(_on_passage_mode_pressed)
	roguelite_mode_button.pressed.connect(_on_roguelite_mode_pressed)
	mode_select_back_button.pressed.connect(_on_mode_select_back_pressed)


func _update_menu_layout() -> void:
	if menu_panel == null:
		return

	var viewport_size: Vector2 = size
	var panel_width: float = clampf(viewport_size.x * 0.28, 390.0, 520.0)
	var panel_height: float = clampf(viewport_size.y * 0.66, 640.0, 760.0)
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -panel_width * 0.5
	menu_panel.offset_right = panel_width * 0.5
	menu_panel.offset_top = -panel_height * 0.5
	menu_panel.offset_bottom = panel_height * 0.5

	if credits_panel != null:
		var credits_width: float = clampf(viewport_size.x * 0.30, 340.0, 480.0)
		credits_panel.anchor_left = 0.0
		credits_panel.anchor_right = 0.0
		credits_panel.anchor_top = 1.0
		credits_panel.anchor_bottom = 1.0
		credits_panel.offset_left = CREDITS_MARGIN.x
		credits_panel.offset_right = CREDITS_MARGIN.x + credits_width
		credits_panel.offset_top = -CREDITS_MARGIN.y - CREDITS_HEIGHT
		credits_panel.offset_bottom = -CREDITS_MARGIN.y

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

	if mode_select_panel != null:
		var mode_width: float = clampf(viewport_size.x * 0.32, 540.0, 660.0)
		var mode_height: float = clampf(viewport_size.y * 0.48, 480.0, 560.0)
		mode_select_panel.anchor_left = 0.5
		mode_select_panel.anchor_right = 0.5
		mode_select_panel.anchor_top = 0.5
		mode_select_panel.anchor_bottom = 0.5
		mode_select_panel.offset_left = -mode_width * 0.5
		mode_select_panel.offset_right = mode_width * 0.5
		mode_select_panel.offset_top = -mode_height * 0.5
		mode_select_panel.offset_bottom = mode_height * 0.5

	if run_history_panel != null:
		run_history_panel.update_layout_for_viewport(viewport_size)

	if cue_locker_panel != null:
		cue_locker_panel.update_layout_for_viewport(viewport_size)


func _update_progression_display() -> void:
	var total_favor := 0
	if progression_system != null:
		total_favor = maxi(int(progression_system.get_progression_snapshot().get("total_kraken_favor", 0)), 0)
	if kraken_favor_label != null:
		kraken_favor_label.text = "Kraken Favor: %s" % total_favor


func _set_menu_chrome_visible(is_visible: bool) -> void:
	if menu_panel != null:
		menu_panel.visible = is_visible
	if credits_panel != null:
		credits_panel.visible = is_visible


func _on_start_pressed() -> void:
	_open_mode_select_panel()


func _start_game(mode_id: String, travel_message: String) -> void:
	start_button.disabled = true
	if passage_mode_button != null:
		passage_mode_button.disabled = true
	if roguelite_mode_button != null:
		roguelite_mode_button.disabled = true
	status_label.text = travel_message
	GAME_MODE_SCRIPT.set_pending_mode(get_tree(), mode_id)

	var error_code: int = get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
	if error_code != OK:
		start_button.disabled = false
		if passage_mode_button != null:
			passage_mode_button.disabled = false
		if roguelite_mode_button != null:
			roguelite_mode_button.disabled = false
		if mode_select_panel != null:
			mode_select_panel.visible = false
		_set_menu_chrome_visible(true)
		status_label.text = "Could not load the table. Error %s" % error_code


func _open_mode_select_panel() -> void:
	_set_menu_chrome_visible(false)
	if options_panel != null:
		options_panel.visible = false
	if run_history_panel != null:
		run_history_panel.close_panel()
	if cue_locker_panel != null:
		cue_locker_panel.close_panel()
	if passage_mode_button != null:
		passage_mode_button.disabled = false
	if roguelite_mode_button != null:
		roguelite_mode_button.disabled = false
	mode_select_panel.visible = true
	passage_mode_button.grab_focus()


func _on_passage_mode_pressed() -> void:
	_start_game(GAME_MODE_SCRIPT.MODE_PASSAGE, "Casting off...")


func _on_roguelite_mode_pressed() -> void:
	_start_game(GAME_MODE_SCRIPT.MODE_ROGUELITE, "The table sinks...")


func _on_mode_select_back_pressed() -> void:
	if mode_select_panel != null:
		mode_select_panel.visible = false
	_set_menu_chrome_visible(true)
	status_label.text = "The moon is high. The table waits."
	start_button.grab_focus()


func _on_options_pressed() -> void:
	_set_menu_chrome_visible(false)
	if mode_select_panel != null:
		mode_select_panel.visible = false
	if run_history_panel != null:
		run_history_panel.close_panel()
	if cue_locker_panel != null:
		cue_locker_panel.close_panel()
	options_panel.visible = true
	options_panel.refresh_from_audio_settings()
	options_panel.grab_default_focus()


func _on_options_back_requested() -> void:
	options_panel.visible = false
	_set_menu_chrome_visible(true)
	status_label.text = "The moon is high. The table waits."
	_update_progression_display()
	options_button.grab_focus()


func _on_cue_locker_pressed() -> void:
	_set_menu_chrome_visible(false)
	if mode_select_panel != null:
		mode_select_panel.visible = false
	if options_panel != null:
		options_panel.visible = false
	if run_history_panel != null:
		run_history_panel.close_panel()
	cue_locker_panel.open_panel()


func _on_cue_locker_back_requested() -> void:
	_set_menu_chrome_visible(true)
	_update_progression_display()
	status_label.text = "The locker shuts with a salt-stiff click."
	cue_locker_button.grab_focus()


func _on_cue_progression_changed(_snapshot: Dictionary) -> void:
	_update_progression_display()


func _on_cue_progression_status_changed(text: String) -> void:
	if text.is_empty():
		return
	status_label.text = text


func _on_run_history_pressed() -> void:
	_set_menu_chrome_visible(false)
	if mode_select_panel != null:
		mode_select_panel.visible = false
	if options_panel != null:
		options_panel.visible = false
	if cue_locker_panel != null:
		cue_locker_panel.close_panel()
	_update_progression_display()
	run_history_panel.open_panel()


func _on_run_history_back_requested() -> void:
	_set_menu_chrome_visible(true)
	status_label.text = "The moon is high. The ledger waits."
	run_history_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
