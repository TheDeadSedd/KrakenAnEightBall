extends PanelContainer
class_name MainMenuRunHistoryPanel

signal back_requested

# Main-menu Run History presentation only. RunHistorySystem owns persistence.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const PANEL_SIZE := Vector2(780.0, 610.0)
const EMPTY_TEXT := "No voyages logged yet."

var run_history_system: RunHistorySystem
var history_list: VBoxContainer
var empty_label: Label
var clear_button: Button
var clear_confirm_panel: PanelContainer
var clear_confirm_yes_button: Button
var clear_confirm_cancel_button: Button
var back_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_panel_style())
	_build_panel()
	_refresh_clear_button_state()


func setup(history_system: RunHistorySystem) -> void:
	run_history_system = history_system
	_refresh_clear_button_state()


func open_panel() -> void:
	_rebuild_history_list()
	visible = true
	if back_button != null:
		back_button.grab_focus()


func close_panel() -> void:
	_set_clear_confirm_visible(false)
	visible = false


func update_layout_for_viewport(viewport_size: Vector2) -> void:
	var history_width: float = clampf(viewport_size.x * 0.48, PANEL_SIZE.x, 920.0)
	var history_height: float = clampf(viewport_size.y * 0.66, PANEL_SIZE.y, 720.0)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -history_width * 0.5
	offset_right = history_width * 0.5
	offset_top = -history_height * 0.5
	offset_bottom = history_height * 0.5


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
	scroll.custom_minimum_size = Vector2(690.0, 360.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	stack.add_child(scroll)

	history_list = VBoxContainer.new()
	history_list.add_theme_constant_override("separation", 8)
	history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(history_list)

	empty_label = Label.new()
	empty_label.text = EMPTY_TEXT
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_label.custom_minimum_size = Vector2(680.0, 180.0)
	empty_label.add_theme_font_override("font", UI_FONT)
	empty_label.add_theme_font_size_override("font_size", 24)
	empty_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.78, 0.9))
	empty_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	empty_label.add_theme_constant_override("outline_size", 2)

	clear_confirm_panel = PanelContainer.new()
	clear_confirm_panel.visible = false
	clear_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	clear_confirm_panel.add_theme_stylebox_override("panel", _make_history_row_style())
	stack.add_child(clear_confirm_panel)

	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 14)
	confirm_margin.add_theme_constant_override("margin_top", 8)
	confirm_margin.add_theme_constant_override("margin_right", 14)
	confirm_margin.add_theme_constant_override("margin_bottom", 8)
	clear_confirm_panel.add_child(confirm_margin)

	var confirm_row := HBoxContainer.new()
	confirm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_row.add_theme_constant_override("separation", 12)
	confirm_margin.add_child(confirm_row)

	var confirm_label := Label.new()
	confirm_label.text = "Clear all voyage records?"
	confirm_label.add_theme_font_override("font", UI_FONT)
	confirm_label.add_theme_font_size_override("font_size", 19)
	confirm_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 0.96))
	confirm_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.74))
	confirm_label.add_theme_constant_override("outline_size", 2)
	confirm_row.add_child(confirm_label)

	clear_confirm_yes_button = _make_secondary_menu_button("Yes")
	clear_confirm_yes_button.custom_minimum_size = Vector2(92.0, 38.0)
	clear_confirm_cancel_button = _make_secondary_menu_button("Cancel")
	clear_confirm_cancel_button.custom_minimum_size = Vector2(112.0, 38.0)
	confirm_row.add_child(clear_confirm_yes_button)
	confirm_row.add_child(clear_confirm_cancel_button)
	clear_confirm_yes_button.pressed.connect(_on_clear_confirmed)
	clear_confirm_cancel_button.pressed.connect(_on_clear_cancelled)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 18)
	stack.add_child(action_row)

	clear_button = _make_secondary_menu_button("Clear History")
	clear_button.custom_minimum_size = Vector2(180.0, 42.0)
	action_row.add_child(clear_button)
	clear_button.pressed.connect(_on_clear_pressed)

	back_button = _make_menu_button("Back")
	back_button.custom_minimum_size = Vector2(190.0, 48.0)
	back_button.add_theme_font_size_override("font_size", 24)
	action_row.add_child(back_button)
	back_button.pressed.connect(_on_back_pressed)


func _rebuild_history_list() -> void:
	if run_history_system == null or history_list == null:
		return

	_set_clear_confirm_visible(false)
	run_history_system.load_history()
	_clear_history_list()
	var records: Array = run_history_system.get_records_snapshot()
	_refresh_clear_button_state(records)
	if records.is_empty():
		history_list.add_child(empty_label)
		return

	for record_value in records:
		if record_value is Dictionary:
			history_list.add_child(_make_run_history_row(record_value as Dictionary))


func _clear_history_list() -> void:
	for child in history_list.get_children():
		history_list.remove_child(child)
		if child != empty_label:
			child.queue_free()


func _set_clear_confirm_visible(is_visible: bool) -> void:
	if clear_confirm_panel != null:
		clear_confirm_panel.visible = is_visible
	_refresh_clear_button_state()


func _refresh_clear_button_state(records: Array = []) -> void:
	if clear_button == null:
		return
	var has_records := false
	if not records.is_empty():
		has_records = true
	elif run_history_system != null:
		has_records = not run_history_system.get_records_snapshot().is_empty()
	clear_button.disabled = bool(clear_confirm_panel != null and clear_confirm_panel.visible) or not has_records


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
		"Time %s    Final %s Doubloons    Earned %s    Spent %s    Lost %s" % [
			_format_run_duration(float(record.get("run_duration", 0.0))),
			maxi(int(record.get("final_doubloons", 0)), 0),
			maxi(int(record.get("doubloons_earned", 0)), 0),
			_get_history_doubloons_spent(record),
			_get_history_doubloons_lost(record),
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
	var has_passage_fields := record.has("passage_completed") or record.has("remaining_passage")
	var passage_text := "Passage Not Logged"
	if has_passage_fields:
		passage_text = "Passage Granted" if bool(record.get("passage_completed", false)) else "Passage Unfinished"
	var favor_earned := maxi(int(record.get("kraken_favor_earned", record.get("voyage_marks_awarded", 0))), 0)
	stack.add_child(_make_history_label(
		"%s    Remaining %s    Kraken Favor +%s" % [
			passage_text,
			maxi(int(record.get("remaining_passage", 0 if has_passage_fields else -1)), 0),
			favor_earned,
		],
		16,
		Color(0.74, 0.88, 0.82, 0.94)
	))
	return row_panel


func _get_history_doubloons_spent(record: Dictionary) -> int:
	return maxi(int(record.get("doubloons_spent", 0)), 0)


func _get_history_doubloons_lost(record: Dictionary) -> int:
	return maxi(int(record.get("doubloons_lost_to_penalties", record.get("doubloons_lost", 0))), 0)


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


func _on_back_pressed() -> void:
	close_panel()
	back_requested.emit()


func _on_clear_pressed() -> void:
	_set_clear_confirm_visible(true)
	if clear_confirm_cancel_button != null:
		clear_confirm_cancel_button.grab_focus()


func _on_clear_confirmed() -> void:
	if run_history_system == null:
		return

	var clear_succeeded := run_history_system.clear_history()
	_rebuild_history_list()
	if not clear_succeeded:
		push_warning("Run history could not be cleared.")
	if back_button != null:
		back_button.grab_focus()


func _on_clear_cancelled() -> void:
	_set_clear_confirm_visible(false)
	if clear_button != null:
		clear_button.grab_focus()
