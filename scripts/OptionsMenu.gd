extends PanelContainer
class_name OptionsMenu

signal back_requested

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const SLIDER_WIDTH := 300.0
const VALUE_LABEL_WIDTH := 62.0

var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var master_value_label: Label
var music_value_label: Label
var sfx_value_label: Label
var back_button: Button
var applying_values := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_content()
	refresh_from_audio_settings()


func refresh_from_audio_settings() -> void:
	AudioSettings.load_and_apply()
	applying_values = true
	_set_slider_percent(master_slider, AudioSettings.get_master_volume())
	_set_slider_percent(music_slider, AudioSettings.get_music_volume())
	_set_slider_percent(sfx_slider, AudioSettings.get_sfx_volume())
	applying_values = false
	_update_value_labels()


func grab_default_focus() -> void:
	if master_slider != null:
		master_slider.grab_focus()


func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = "Options"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 56)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.018, 0.012, 0.95))
	title_label.add_theme_constant_override("outline_size", 6)
	stack.add_child(title_label)

	var tab_label := Label.new()
	tab_label.text = "Audio"
	tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_label.custom_minimum_size = Vector2(148.0, 40.0)
	tab_label.add_theme_font_override("font", UI_FONT)
	tab_label.add_theme_font_size_override("font_size", 28)
	tab_label.add_theme_color_override("font_color", Color(0.82, 0.98, 0.93, 1.0))
	tab_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	tab_label.add_theme_constant_override("outline_size", 3)
	stack.add_child(tab_label)

	stack.add_child(_make_gap(4.0))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 18)
	stack.add_child(rows)

	master_slider = _make_slider()
	music_slider = _make_slider()
	sfx_slider = _make_slider()
	master_value_label = _make_value_label()
	music_value_label = _make_value_label()
	sfx_value_label = _make_value_label()

	rows.add_child(_make_slider_row("Master", master_slider, master_value_label))
	rows.add_child(_make_slider_row("Music", music_slider, music_value_label))
	rows.add_child(_make_slider_row("FX / SFX", sfx_slider, sfx_value_label))

	stack.add_child(_make_gap(8.0))
	back_button = _make_button("Back")
	stack.add_child(back_button)

	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	back_button.pressed.connect(_on_back_pressed)


func _make_slider_row(label_text: String, slider: HSlider, value_label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(132.0, 34.0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UI_FONT)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.88, 0.70, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	name_label.add_theme_constant_override("outline_size", 2)

	row.add_child(name_label)
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _make_slider() -> HSlider:
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 34.0)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = 100.0
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.add_theme_stylebox_override("slider", _make_slider_track_style(Color(0.07, 0.055, 0.050, 0.92)))
	slider.add_theme_stylebox_override("grabber_area", _make_slider_track_style(Color(0.78, 0.58, 0.24, 0.95)))
	slider.add_theme_icon_override("grabber", _make_slider_grabber_icon(Color(1.0, 0.86, 0.42, 1.0)))
	slider.add_theme_icon_override("grabber_highlight", _make_slider_grabber_icon(Color(0.78, 0.98, 0.92, 1.0)))
	return slider


func _make_value_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(VALUE_LABEL_WIDTH, 34.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.80, 0.94, 0.90, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(230.0, 52.0)
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


func _make_gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1.0, height)
	return spacer


func _set_slider_percent(slider: HSlider, value: float) -> void:
	if slider == null:
		return
	slider.value = roundi(clampf(value, 0.0, 1.0) * 100.0)


func _update_value_labels() -> void:
	_update_value_label(master_value_label, master_slider)
	_update_value_label(music_value_label, music_slider)
	_update_value_label(sfx_value_label, sfx_slider)


func _update_value_label(label: Label, slider: HSlider) -> void:
	if label == null or slider == null:
		return
	label.text = "%s%%" % int(round(slider.value))


func _on_master_slider_changed(value: float) -> void:
	if applying_values:
		return
	AudioSettings.set_master_volume(value / 100.0)
	_update_value_label(master_value_label, master_slider)


func _on_music_slider_changed(value: float) -> void:
	if applying_values:
		return
	AudioSettings.set_music_volume(value / 100.0)
	_update_value_label(music_value_label, music_slider)


func _on_sfx_slider_changed(value: float) -> void:
	if applying_values:
		return
	AudioSettings.set_sfx_volume(value / 100.0)
	_update_value_label(sfx_value_label, sfx_slider)


func _on_back_pressed() -> void:
	back_requested.emit()


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.018, 0.026, 0.72)
	style.border_color = Color(0.92, 0.72, 0.32, 0.44)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 22
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


func _make_slider_track_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	return style


func _make_slider_grabber_icon(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color.lightened(0.12))
	gradient.set_color(1, color.darkened(0.24))

	var texture := GradientTexture2D.new()
	texture.width = 18
	texture.height = 26
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.50, 0.36)
	texture.fill_to = Vector2(0.50, 1.0)
	texture.gradient = gradient
	return texture
