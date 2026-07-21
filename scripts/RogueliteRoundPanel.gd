extends Control
class_name RogueliteRoundPanel

# index:title Roguelite Round Panel
# index:category UI / Presentation
# index:status First Pass
# index:owner ui_agent
# index:notes Modal presenter for roguelite round clear/run complete states; no round logic ownership.

signal continue_requested
signal restart_requested
signal abandon_requested
signal balance_report_requested

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const ROUND_PANEL_SIZE := Vector2(520.0, 300.0)
const TERMINAL_PANEL_SIZE := Vector2(700.0, 520.0)
const VIEWPORT_MARGIN := 24.0
const SHADE_COLOR := Color(0.01, 0.012, 0.016, 0.48)
const PANEL_Z_INDEX := 76

var shade: ColorRect
var panel: Panel
var panel_margin: MarginContainer
var title_label: Label
var body_label: Label
var continue_button: Button
var balance_report_button: Button
var abandon_button: Button
var primary_action: String = "continue"
var current_panel_size: Vector2 = ROUND_PANEL_SIZE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = PANEL_Z_INDEX
	visible = false
	_set_full_rect(self)
	_build_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_panel()


func open_round_cleared(snapshot: Dictionary) -> void:
	var round_number: int = maxi(int(snapshot.get("round_number", 1)), 1)
	current_panel_size = ROUND_PANEL_SIZE
	primary_action = "continue"
	title_label.text = "Round Cleared"
	_set_body_font_size(21)
	body_label.text = "Round %s is cleared.\nThe table sinks deeper." % round_number
	continue_button.text = "Continue"
	continue_button.visible = true
	continue_button.disabled = false
	balance_report_button.visible = false
	balance_report_button.disabled = true
	abandon_button.text = "Abandon Run"
	visible = true
	_center_panel()
	continue_button.grab_focus()


func open_run_completed(snapshot: Dictionary) -> void:
	current_panel_size = TERMINAL_PANEL_SIZE
	primary_action = "none"
	title_label.text = "Run Complete"
	_set_body_font_size(18)
	body_label.text = _make_completed_summary_text(snapshot)
	continue_button.visible = false
	continue_button.disabled = true
	balance_report_button.visible = true
	balance_report_button.disabled = false
	abandon_button.text = "Return to Main Menu"
	visible = true
	_center_panel()
	abandon_button.grab_focus()


func open_run_failed(snapshot: Dictionary = {}) -> void:
	current_panel_size = TERMINAL_PANEL_SIZE
	primary_action = "restart"
	title_label.text = "Run Failed"
	_set_body_font_size(18)
	body_label.text = _make_failed_summary_text(snapshot)
	continue_button.text = "Restart"
	continue_button.visible = true
	continue_button.disabled = false
	balance_report_button.visible = true
	balance_report_button.disabled = false
	abandon_button.text = "Main Menu"
	visible = true
	_center_panel()
	continue_button.grab_focus()


func close_panel() -> void:
	visible = false


func _build_panel() -> void:
	shade = ColorRect.new()
	shade.name = "Shade"
	shade.color = SHADE_COLOR
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_full_rect(shade)
	add_child(shade)

	panel = Panel.new()
	panel.name = "Panel"
	panel.custom_minimum_size = current_panel_size
	panel.size = current_panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 34)
	panel_margin.add_theme_constant_override("margin_top", 28)
	panel_margin.add_theme_constant_override("margin_right", 34)
	panel_margin.add_theme_constant_override("margin_bottom", 28)
	_set_full_rect(panel_margin)
	panel.add_child(panel_margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 16)
	panel_margin.add_child(stack)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.010, 0.92))
	title_label.add_theme_constant_override("outline_size", 5)
	stack.add_child(title_label)

	body_label = Label.new()
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_override("font", UI_FONT)
	body_label.add_theme_font_size_override("font_size", 21)
	body_label.add_theme_color_override("font_color", Color(0.84, 0.91, 0.82, 0.94))
	body_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	body_label.add_theme_constant_override("outline_size", 3)
	stack.add_child(body_label)

	stack.add_child(_make_gap(4.0))

	continue_button = _make_button("Continue")
	continue_button.pressed.connect(_on_continue_pressed)
	stack.add_child(continue_button)

	balance_report_button = _make_button("VIEW BALANCE REPORT")
	balance_report_button.visible = false
	balance_report_button.disabled = true
	balance_report_button.pressed.connect(_on_balance_report_pressed)
	stack.add_child(balance_report_button)

	abandon_button = _make_button("Abandon Run")
	abandon_button.pressed.connect(_on_abandon_pressed)
	stack.add_child(abandon_button)

	_center_panel()


func _set_full_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _center_panel() -> void:
	if panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var available_size: Vector2 = Vector2(
		maxf(viewport_size.x - VIEWPORT_MARGIN * 2.0, 1.0),
		maxf(viewport_size.y - VIEWPORT_MARGIN * 2.0, 1.0)
	)
	var panel_size: Vector2 = Vector2(
		minf(current_panel_size.x, available_size.x),
		minf(current_panel_size.y, available_size.y)
	)
	var panel_position: Vector2 = (viewport_size - panel_size) * 0.5
	var max_position: Vector2 = Vector2(
		maxf(viewport_size.x - panel_size.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN),
		maxf(viewport_size.y - panel_size.y - VIEWPORT_MARGIN, VIEWPORT_MARGIN)
	)
	panel_position = Vector2(
		clampf(panel_position.x, VIEWPORT_MARGIN, max_position.x),
		clampf(panel_position.y, VIEWPORT_MARGIN, max_position.y)
	)
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	panel.position = panel_position
	if panel_margin != null:
		_set_full_rect(panel_margin)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.018, 0.026, 0.88)
	style.border_color = Color(0.92, 0.72, 0.32, 0.62)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0.0, 8.0)
	return style


func _make_failed_summary_text(snapshot: Dictionary) -> String:
	return "\n".join(PackedStringArray([
		"Reached Round: %s / %s" % [
			maxi(int(snapshot.get("reached_round", snapshot.get("round_number", 1))), 1),
			maxi(int(snapshot.get("round_count", 1)), 1),
		],
		"Failed By: %s" % _format_failure_reason(str(snapshot.get("failure_reason", "unknown"))),
		"Quota: %s / %s" % [
			maxi(int(snapshot.get("round_score", 0)), 0),
			maxi(int(snapshot.get("round_target", 0)), 0),
		],
		"Shots Left: %s" % maxi(int(snapshot.get("shots_left", 0)), 0),
		"Hull: %s / %s" % [
			maxi(int(snapshot.get("hull", 0)), 0),
			maxi(int(snapshot.get("max_hull", 1)), 1),
		],
		"Rewards Chosen: %s" % maxi(int(snapshot.get("rewards_chosen_count", 0)), 0),
		"",
		"Rewards:",
		_format_reward_names(snapshot),
	]))


func _make_completed_summary_text(snapshot: Dictionary) -> String:
	return "\n".join(PackedStringArray([
		"Cleared Round: %s / %s" % [
			maxi(int(snapshot.get("cleared_round", snapshot.get("round_number", 1))), 1),
			maxi(int(snapshot.get("round_count", 1)), 1),
		],
		"Final Quota: %s / %s" % [
			maxi(int(snapshot.get("round_score", 0)), 0),
			maxi(int(snapshot.get("round_target", 0)), 0),
		],
		"Shots Left: %s" % maxi(int(snapshot.get("shots_left", 0)), 0),
		"Hull: %s / %s" % [
			maxi(int(snapshot.get("hull", 0)), 0),
			maxi(int(snapshot.get("max_hull", 1)), 1),
		],
		"Rewards Chosen: %s" % maxi(int(snapshot.get("rewards_chosen_count", 0)), 0),
		"",
		"Rewards:",
		_format_reward_names(snapshot),
	]))


func _format_reward_names(snapshot: Dictionary) -> String:
	var names_value: Variant = snapshot.get("rewards_chosen_display_names", [])
	var names: Array = []
	if names_value is Array:
		names = names_value
	if names.is_empty():
		return "None"

	var parts: PackedStringArray = PackedStringArray()
	for name_value in names:
		var reward_name: String = str(name_value)
		if reward_name.is_empty():
			continue
		parts.append(reward_name)
	if parts.is_empty():
		return "None"
	return ", ".join(parts)


func _format_failure_reason(reason: String) -> String:
	match reason:
		"shots":
			return "Shots"
		"hull":
			return "Hull"
		"empty_table":
			return "Empty Table"
		_:
			return "Unknown"


func _set_body_font_size(font_size: int) -> void:
	if body_label == null:
		return
	body_label.add_theme_font_size_override("font_size", font_size)


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260.0, 48.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.78, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.09, 0.03, 1.0))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.09, 0.063, 0.041, 0.92), Color(0.88, 0.68, 0.32, 0.62)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.15, 0.096, 0.044, 0.98), Color(1.0, 0.82, 0.38, 0.94)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.88, 0.67, 0.31, 0.98), Color(1.0, 0.91, 0.62, 1.0)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.11, 0.070, 0.038, 0.96), Color(0.64, 0.95, 0.88, 0.78)))
	return button


func _make_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.set_content_margin(SIDE_LEFT, 18.0)
	style.set_content_margin(SIDE_RIGHT, 18.0)
	style.set_content_margin(SIDE_TOP, 9.0)
	style.set_content_margin(SIDE_BOTTOM, 6.0)
	return style


func _make_gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1.0, height)
	return spacer


func _on_continue_pressed() -> void:
	if primary_action == "restart":
		restart_requested.emit()
	else:
		continue_requested.emit()


func _on_abandon_pressed() -> void:
	abandon_requested.emit()


func _on_balance_report_pressed() -> void:
	balance_report_requested.emit()
