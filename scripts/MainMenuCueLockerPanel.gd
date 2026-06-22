extends PanelContainer
class_name MainMenuCueLockerPanel

signal back_requested

# Main-menu Cue Locker presentation only. CueProgressionSystem owns cue
# definitions, unlock/equip validation, and persistence through ProgressionSystem.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const PANEL_SIZE := Vector2(900.0, 720.0)

var cue_progression_system: CueProgressionSystem
var favor_label: Label
var loadout_label: Label
var status_label: Label
var cue_part_list: VBoxContainer
var back_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_panel()
	_refresh_panel()


func setup(cue_system: CueProgressionSystem) -> void:
	if cue_progression_system != null:
		if cue_progression_system.cue_progression_changed.is_connected(_on_cue_progression_changed):
			cue_progression_system.cue_progression_changed.disconnect(_on_cue_progression_changed)
		if cue_progression_system.status_changed.is_connected(_on_cue_progression_status_changed):
			cue_progression_system.status_changed.disconnect(_on_cue_progression_status_changed)

	cue_progression_system = cue_system
	if cue_progression_system != null:
		if not cue_progression_system.cue_progression_changed.is_connected(_on_cue_progression_changed):
			cue_progression_system.cue_progression_changed.connect(_on_cue_progression_changed)
		if not cue_progression_system.status_changed.is_connected(_on_cue_progression_status_changed):
			cue_progression_system.status_changed.connect(_on_cue_progression_status_changed)
	_refresh_panel()


func open_panel() -> void:
	_refresh_panel()
	visible = true
	if back_button != null:
		back_button.grab_focus()


func close_panel() -> void:
	visible = false


func update_layout_for_viewport(viewport_size: Vector2) -> void:
	var locker_width: float = clampf(viewport_size.x * 0.56, PANEL_SIZE.x, 1040.0)
	var locker_height: float = clampf(viewport_size.y * 0.74, PANEL_SIZE.y, 820.0)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -locker_width * 0.5
	offset_right = locker_width * 0.5
	offset_top = -locker_height * 0.5
	offset_bottom = locker_height * 0.5


func set_status_text(text: String) -> void:
	if text.is_empty() or status_label == null:
		return
	status_label.text = text


func _build_panel() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = "Cue Locker"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.03, 0.018, 0.012, 0.95))
	title_label.add_theme_constant_override("outline_size", 4)
	stack.add_child(title_label)

	favor_label = Label.new()
	favor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	favor_label.add_theme_font_override("font", UI_FONT)
	favor_label.add_theme_font_size_override("font_size", 22)
	favor_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36, 0.96))
	favor_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.74))
	favor_label.add_theme_constant_override("outline_size", 2)
	stack.add_child(favor_label)

	loadout_label = Label.new()
	loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout_label.add_theme_font_override("font", UI_FONT)
	loadout_label.add_theme_font_size_override("font_size", 17)
	loadout_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.90, 0.94))
	loadout_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	loadout_label.add_theme_constant_override("outline_size", 2)
	stack.add_child(loadout_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_override("font", UI_FONT)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.66, 0.94))
	status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	status_label.add_theme_constant_override("outline_size", 2)
	stack.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(805.0, 420.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(scroll)

	cue_part_list = VBoxContainer.new()
	cue_part_list.add_theme_constant_override("separation", 10)
	cue_part_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cue_part_list)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 18)
	stack.add_child(action_row)

	back_button = _make_menu_button("Back")
	back_button.custom_minimum_size = Vector2(190.0, 48.0)
	back_button.add_theme_font_size_override("font_size", 24)
	action_row.add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)


func _refresh_panel() -> void:
	if cue_progression_system == null or cue_part_list == null:
		return

	var snapshot: Dictionary = cue_progression_system.get_cue_progression_snapshot()
	var favor_total := maxi(int(snapshot.get("kraken_favor", 0)), 0)
	if favor_label != null:
		favor_label.text = "Kraken Favor: %s" % favor_total
	if loadout_label != null:
		loadout_label.text = _format_cue_loadout(snapshot.get("equipped_loadout", []))
	if status_label != null:
		var status_text := str(snapshot.get("last_status_text", ""))
		status_label.text = "Choose what the locker remembers." if status_text.is_empty() else status_text

	_clear_cue_part_list()
	var slots_value: Variant = snapshot.get("slots", [])
	if not slots_value is Array:
		return
	for slot_value in slots_value:
		if not slot_value is Dictionary:
			continue
		var slot: Dictionary = slot_value
		cue_part_list.add_child(_make_cue_slot_label(str(slot.get("slot_label", "Cue Part"))))
		var parts_value: Variant = slot.get("parts", [])
		if not parts_value is Array:
			continue
		for part_value in parts_value:
			if part_value is Dictionary:
				cue_part_list.add_child(_make_cue_part_row(part_value as Dictionary))


func _clear_cue_part_list() -> void:
	if cue_part_list == null:
		return
	for child in cue_part_list.get_children():
		cue_part_list.remove_child(child)
		child.queue_free()


func _make_cue_slot_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.018, 0.012, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _make_cue_part_row(part: Dictionary) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.add_theme_stylebox_override("panel", _make_row_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	row_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 3)
	row.add_child(text_stack)

	var part_name := str(part.get("display_name", "Cue Part"))
	var unlocked := bool(part.get("unlocked", false))
	var equipped := bool(part.get("equipped", false))
	var status_suffix := ""
	if equipped:
		status_suffix = "  Equipped"
	elif unlocked:
		status_suffix = "  Unlocked"

	text_stack.add_child(_make_text_label("%s%s" % [part_name, status_suffix], 18, Color(1.0, 0.88, 0.48, 1.0)))
	text_stack.add_child(_make_text_label(str(part.get("description", "")), 15, Color(0.88, 0.86, 0.76, 0.96)))

	var cost := maxi(int(part.get("cost", 0)), 0)
	text_stack.add_child(_make_text_label("Cost %s Favor" % cost, 14, Color(0.74, 0.88, 0.82, 0.90)))

	var action_button := _make_secondary_menu_button(_get_cue_part_action_text(part))
	action_button.custom_minimum_size = Vector2(150.0, 42.0)
	action_button.disabled = _is_cue_part_action_disabled(part)
	row.add_child(action_button)

	var part_id := str(part.get("id", ""))
	if not unlocked:
		action_button.pressed.connect(_on_cue_part_unlock_pressed.bind(part_id))
	elif not equipped:
		action_button.pressed.connect(_on_cue_part_equip_pressed.bind(part_id))
	return row_panel


func _get_cue_part_action_text(part: Dictionary) -> String:
	if bool(part.get("equipped", false)):
		return "Equipped"
	if bool(part.get("unlocked", false)):
		return "Equip"
	return "Unlock: %s" % maxi(int(part.get("cost", 0)), 0)


func _is_cue_part_action_disabled(part: Dictionary) -> bool:
	if bool(part.get("equipped", false)):
		return true
	if bool(part.get("unlocked", false)):
		return false
	return not bool(part.get("affordable", false))


func _format_cue_loadout(value: Variant) -> String:
	if not value is Array:
		return "Equipped: Weathered Cue"
	var pieces: Array[String] = []
	for loadout_value in value:
		if not loadout_value is Dictionary:
			continue
		var loadout: Dictionary = loadout_value
		pieces.append("%s: %s" % [
			str(loadout.get("slot_label", "Slot")),
			str(loadout.get("display_name", "Cue Part")),
		])
	if pieces.is_empty():
		return "Equipped: Weathered Cue"
	return "Equipped  " + "   ".join(pieces)


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


func _make_secondary_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170.0, 42.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.86, 0.82, 0.66, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.60, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.09, 0.03, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.43, 0.36, 0.62))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.055, 0.044, 0.034, 0.76), Color(0.72, 0.58, 0.34, 0.34)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.11, 0.074, 0.040, 0.92), Color(0.96, 0.74, 0.34, 0.78)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.80, 0.58, 0.26, 0.94), Color(1.0, 0.88, 0.56, 0.96)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.030, 0.027, 0.024, 0.50), Color(0.38, 0.34, 0.26, 0.28)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.070, 0.054, 0.035, 0.88), Color(0.64, 0.95, 0.88, 0.58)))
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


func _make_row_style() -> StyleBoxFlat:
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


func _make_text_label(text: String, font_size: int, font_color: Color) -> Label:
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


func _on_back_pressed() -> void:
	close_panel()
	back_requested.emit()


func _on_cue_part_unlock_pressed(part_id: String) -> void:
	if cue_progression_system == null:
		return
	cue_progression_system.request_unlock_part(part_id)
	_refresh_panel()


func _on_cue_part_equip_pressed(part_id: String) -> void:
	if cue_progression_system == null:
		return
	cue_progression_system.request_equip_part(part_id)
	_refresh_panel()


func _on_cue_progression_changed(_snapshot: Dictionary) -> void:
	if visible:
		_refresh_panel()


func _on_cue_progression_status_changed(text: String) -> void:
	set_status_text(text)
