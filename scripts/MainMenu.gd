extends Control
class_name MainMenu

# index:title Main Menu
# index:category UI / Presentation
# index:status In Progress
# index:owner ui_agent
# index:notes Lightweight title screen shell using the main menu artwork as the primary visual foundation.

const GAMEPLAY_SCENE_PATH := "res://scenes/Main.tscn"
const UI_FONT := preload("res://assets/fonts/Gothic Pixels.ttf")
const BACKGROUND_TEXTURE := preload("res://assets/ui/mainmenu.png")

var background_image: TextureRect
var background_scrim: ColorRect
var menu_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var status_label: Label
var start_button: Button
var options_button: Button
var quit_button: Button


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_interface()
	_update_menu_layout()
	start_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_menu_layout()


func _build_background() -> void:
	background_image = TextureRect.new()
	background_image.name = "BackgroundImage"
	background_image.texture = BACKGROUND_TEXTURE
	background_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(background_image)
	add_child(background_image)

	background_scrim = ColorRect.new()
	background_scrim.name = "ReadabilityScrim"
	background_scrim.color = Color(0.0, 0.018, 0.035, 0.16)
	background_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(background_scrim)
	add_child(background_scrim)


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
	quit_button = _make_menu_button("Quit")
	stack.add_child(start_button)
	stack.add_child(options_button)
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
	quit_button.pressed.connect(_on_quit_pressed)


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
	style.set_content_margin(SIDE_TOP, 8.0)
	style.set_content_margin(SIDE_BOTTOM, 8.0)
	return style


func _update_menu_layout() -> void:
	if menu_panel == null:
		return

	var viewport_size: Vector2 = size
	var panel_width: float = clampf(viewport_size.x * 0.28, 390.0, 520.0)
	var panel_height: float = clampf(viewport_size.y * 0.55, 500.0, 630.0)
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -panel_width * 0.5
	menu_panel.offset_right = panel_width * 0.5
	menu_panel.offset_top = -panel_height * 0.5
	menu_panel.offset_bottom = panel_height * 0.5


func _on_start_pressed() -> void:
	start_button.disabled = true
	status_label.text = "Casting off..."
	var error_code: int = get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
	if error_code != OK:
		start_button.disabled = false
		status_label.text = "Could not load the table. Error %s" % error_code


func _on_options_pressed() -> void:
	status_label.text = "Options are coming soon."


func _on_quit_pressed() -> void:
	get_tree().quit()
