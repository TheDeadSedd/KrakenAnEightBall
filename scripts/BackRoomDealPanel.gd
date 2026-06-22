extends Control
class_name BackRoomDealPanel

signal close_requested
signal deal_option_selected(item_id: String)

# Back Room Deal presentation only. BackRoomDealSystem owns definitions,
# economy checks, Reserve insertion, and spending.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const QUARTERMASTER_TEXTURE := preload("res://assets/characters/quartermaster.png")
const ITEM_ICON_DRAW := preload("res://scripts/ItemIconDraw.gd")

const PANEL_WIDTH := 820.0
const PANEL_HEIGHT := 440.0
const PANEL_SIZE := Vector2(PANEL_WIDTH, PANEL_HEIGHT)
const LEFT_COLUMN_WIDTH := 238.0
const PORTRAIT_SIZE := Vector2(204.0, 210.0)
const OPTION_HEIGHT := 62.0
const OPTION_SPACING := 7.0
const MAX_VISIBLE_OPTION_ROWS := 5
const HEADER_HEIGHT := 30.0
const OUTER_MARGIN_TOP := 14.0
const OUTER_MARGIN_BOTTOM := 16.0
const HEADER_BODY_GAP := 10.0
const OPTIONS_LABEL_HEIGHT := 18.0
const OPTIONS_LABEL_GAP := 7.0
const LEFT_COLUMN_MIN_HEIGHT := 304.0
const TITLE_TEXT := "Back Room Deal"
const FLAVOR_TEXT := "The Quartermaster can get what the manifest omits."
const OPTIONS_TITLE := "Special procurement"
const CORNER_RADIUS := 9

const PANEL_FILL := Color(0.032, 0.024, 0.018, 0.97)
const PANEL_BORDER := Color(0.96, 0.78, 0.34, 0.50)
const ROW_FILL := Color(0.055, 0.043, 0.030, 0.78)
const ROW_BORDER := Color(0.96, 0.78, 0.34, 0.30)
const ROW_UNAVAILABLE_FILL := Color(0.035, 0.032, 0.030, 0.58)
const ROW_UNAVAILABLE_BORDER := Color(0.52, 0.45, 0.34, 0.26)
const BUTTON_FILL := Color(0.065, 0.052, 0.035, 0.78)
const BUTTON_BORDER := Color(0.96, 0.78, 0.34, 0.48)
const BUTTON_HOVER_FILL := Color(0.10, 0.075, 0.035, 0.88)
const BUTTON_HOVER_BORDER := Color(1.0, 0.86, 0.42, 0.86)
const BUTTON_UNAVAILABLE_FILL := Color(0.04, 0.038, 0.034, 0.52)
const BUTTON_UNAVAILABLE_BORDER := Color(0.52, 0.45, 0.34, 0.38)

var deal_snapshot: Dictionary = {}
var hover_ui_suppressed := false
var status_label: Label
var cost_label: Label
var options_stack: VBoxContainer
var scroll_container: ScrollContainer
var body_container: HBoxContainer
var panel_shell: Panel
var close_button: Button
var option_buy_buttons: Array[Button] = []
var desired_panel_size := PANEL_SIZE

var row_style := StyleBoxFlat.new()
var row_unavailable_style := StyleBoxFlat.new()
var button_style := StyleBoxFlat.new()
var button_hover_style := StyleBoxFlat.new()
var button_unavailable_style := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_dynamic_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_configure_styles()
	_build_panel()
	_refresh_panel()


func set_deal_snapshot(snapshot: Dictionary) -> void:
	deal_snapshot = snapshot.duplicate(true)
	if not bool(deal_snapshot.get("unlocked", false)):
		close_panel()
	_refresh_panel()


func set_hover_ui_suppressed(suppressed: bool) -> void:
	hover_ui_suppressed = suppressed
	_update_input_filters()


func open_panel(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		set_deal_snapshot(snapshot)
	if not bool(deal_snapshot.get("unlocked", false)):
		close_panel()
		return

	_refresh_panel()
	visible = true
	_update_input_filters()


func close_panel() -> void:
	visible = false


func get_current_panel_size() -> Vector2:
	return get_desired_panel_size()


func get_desired_panel_size() -> Vector2:
	return desired_panel_size


func _build_panel() -> void:
	panel_shell = Panel.new()
	panel_shell.name = "PanelShell"
	panel_shell.position = Vector2.ZERO
	panel_shell.custom_minimum_size = desired_panel_size
	panel_shell.size = desired_panel_size
	panel_shell.clip_contents = true
	panel_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_shell.focus_mode = Control.FOCUS_NONE
	panel_shell.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel_shell)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel_shell.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	stack.add_child(_build_header())
	stack.add_child(_build_body())


func _build_header() -> Control:
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)

	var title_label := Label.new()
	title_label.text = TITLE_TEXT
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_label_style(title_label, 23, Color(1.0, 0.88, 0.54, 1.0), 2)
	title_row.add_child(title_label)

	close_button = Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Close"
	close_button.custom_minimum_size = Vector2(32.0, 28.0)
	close_button.focus_mode = Control.FOCUS_NONE
	_apply_button_style(close_button, 14)
	title_row.add_child(close_button)
	close_button.pressed.connect(_on_close_pressed)

	return title_row


func _build_body() -> Control:
	body_container = HBoxContainer.new()
	body_container.add_theme_constant_override("separation", 18)
	body_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	body_container.add_child(_build_left_column())
	body_container.add_child(_build_options_column())
	return body_container


func _build_left_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(LEFT_COLUMN_WIDTH, 0.0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 8)

	var portrait := TextureRect.new()
	portrait.texture = QUARTERMASTER_TEXTURE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)

	var flavor_label := Label.new()
	flavor_label.text = FLAVOR_TEXT
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_label_style(flavor_label, 14, Color(0.76, 0.86, 0.74, 0.94), 1)
	column.add_child(flavor_label)

	cost_label = Label.new()
	_apply_label_style(cost_label, 14, Color(1.0, 0.84, 0.36, 0.96), 1)
	column.add_child(cost_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_label_style(status_label, 13, Color(0.85, 0.78, 0.62, 0.92), 1)
	column.add_child(status_label)
	return column


func _build_options_column() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	column.add_theme_constant_override("separation", 7)

	var options_label := Label.new()
	options_label.text = OPTIONS_TITLE
	_apply_label_style(options_label, 15, Color(1.0, 0.88, 0.54, 0.96), 1)
	column.add_child(options_label)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(scroll_container)

	options_stack = VBoxContainer.new()
	options_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_stack.add_theme_constant_override("separation", int(OPTION_SPACING))
	scroll_container.add_child(options_stack)
	return column


func _refresh_panel() -> void:
	if status_label == null or options_stack == null:
		return

	if cost_label != null:
		cost_label.text = "Cost: %s Doubloons" % _get_deal_cost()

	var blocker: String = str(deal_snapshot.get("blocked_reason", ""))
	if blocker.is_empty():
		status_label.text = "Choose one item for Reserve."
	else:
		status_label.text = "Unavailable: %s" % blocker

	_clear_options()
	var options_value: Variant = deal_snapshot.get("options", [])
	if not options_value is Array:
		_apply_dynamic_size(0)
		return

	var option_count := 0
	for option_value in options_value:
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value
		options_stack.add_child(_make_option_row(option))
		option_count += 1
	_apply_dynamic_size(option_count)
	_update_input_filters()


func _clear_options() -> void:
	option_buy_buttons.clear()
	if options_stack == null:
		return
	for child in options_stack.get_children():
		options_stack.remove_child(child)
		child.queue_free()


func _make_option_row(option: Dictionary) -> Control:
	var item_id: String = str(option.get("id", ""))
	var available: bool = bool(option.get("available", false))
	var blocked_reason: String = str(option.get("blocked_reason", ""))

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, OPTION_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_stylebox_override("panel", row_style if available else row_unavailable_style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 5)
	row.add_child(margin)

	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(42.0, 42.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta("icon_key", str(option.get("icon_key", item_id)))
	icon.draw.connect(_on_option_icon_draw.bind(icon))
	content.add_child(icon)

	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	text_stack.add_theme_constant_override("separation", 1)
	content.add_child(text_stack)

	var name_label := Label.new()
	name_label.text = str(option.get("name", "Back Room Item"))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label_style(name_label, 14, Color(1.0, 0.88, 0.54, 1.0) if available else Color(0.68, 0.62, 0.50, 0.86), 1)
	text_stack.add_child(name_label)

	var description_label := Label.new()
	description_label.text = str(option.get("description", ""))
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label_style(description_label, 11, Color(0.78, 0.84, 0.72, 0.92) if available else Color(0.56, 0.54, 0.48, 0.84), 1)
	text_stack.add_child(description_label)

	var reason_label := Label.new()
	reason_label.text = "" if blocked_reason.is_empty() else blocked_reason
	reason_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reason_label.visible = not blocked_reason.is_empty()
	_apply_label_style(reason_label, 11, Color(1.0, 0.66, 0.42, 0.95), 1)
	text_stack.add_child(reason_label)

	var action_stack := VBoxContainer.new()
	action_stack.custom_minimum_size = Vector2(100.0, 0.0)
	action_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	action_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	action_stack.add_theme_constant_override("separation", 4)
	content.add_child(action_stack)

	var row_cost_label := Label.new()
	row_cost_label.text = "%s Doubloons" % maxi(int(option.get("cost", _get_deal_cost())), 0)
	row_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_label_style(row_cost_label, 11, Color(1.0, 0.84, 0.36, 0.94) if available else Color(0.58, 0.52, 0.42, 0.82), 1)
	action_stack.add_child(row_cost_label)

	var buy_button := Button.new()
	buy_button.text = "Buy"
	buy_button.disabled = not available
	buy_button.custom_minimum_size = Vector2(78.0, 24.0)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.set_meta("blocked_reason", blocked_reason)
	_apply_button_style(buy_button, 13)
	action_stack.add_child(buy_button)
	buy_button.pressed.connect(_on_option_pressed.bind(item_id))
	option_buy_buttons.append(buy_button)

	return row


func _on_option_icon_draw(icon_control: Control) -> void:
	var icon_key := str(icon_control.get_meta("icon_key", ""))
	ITEM_ICON_DRAW.draw_icon(icon_control, Rect2(Vector2.ZERO, icon_control.size), icon_key)


func _apply_dynamic_size(option_count: int = -1) -> void:
	if option_count < 0:
		option_count = _get_option_count_from_snapshot()

	var scroll_height := _calculate_scroll_height(option_count)
	if scroll_container != null:
		scroll_container.custom_minimum_size = Vector2(0.0, scroll_height)
		scroll_container.size = Vector2(scroll_container.size.x, scroll_height)

	var body_height := _calculate_body_height(option_count)
	if body_container != null:
		body_container.custom_minimum_size = Vector2(0.0, body_height)

	_set_desired_panel_size(PANEL_SIZE)


func _set_desired_panel_size(panel_size: Vector2) -> void:
	desired_panel_size = panel_size
	custom_minimum_size = desired_panel_size
	size = desired_panel_size
	set_deferred("size", desired_panel_size)
	if panel_shell != null:
		panel_shell.position = Vector2.ZERO
		panel_shell.custom_minimum_size = desired_panel_size
		panel_shell.size = desired_panel_size
		panel_shell.set_deferred("size", desired_panel_size)
		panel_shell.update_minimum_size()
	update_minimum_size()


func _calculate_body_height(option_count: int) -> float:
	var available_body_height := PANEL_HEIGHT - OUTER_MARGIN_TOP - HEADER_HEIGHT - HEADER_BODY_GAP - OUTER_MARGIN_BOTTOM
	var options_column_height := OPTIONS_LABEL_HEIGHT + OPTIONS_LABEL_GAP + _calculate_scroll_height(option_count)
	return maxf(LEFT_COLUMN_MIN_HEIGHT, minf(options_column_height, available_body_height))


func _calculate_scroll_height(option_count: int) -> float:
	var content_height := _calculate_options_content_height(option_count)
	var max_scroll_height := minf(_calculate_max_option_list_height(), _calculate_max_scroll_height_from_panel())
	return minf(content_height, max_scroll_height)


func _calculate_options_content_height(option_count: int) -> float:
	if option_count <= 0:
		return 0.0
	return option_count * OPTION_HEIGHT + maxf(float(option_count - 1), 0.0) * OPTION_SPACING


func _calculate_max_option_list_height() -> float:
	return MAX_VISIBLE_OPTION_ROWS * OPTION_HEIGHT + maxf(float(MAX_VISIBLE_OPTION_ROWS - 1), 0.0) * OPTION_SPACING


func _calculate_max_scroll_height_from_panel() -> float:
	return maxf(
		0.0,
		PANEL_HEIGHT
		- OUTER_MARGIN_TOP
		- HEADER_HEIGHT
		- HEADER_BODY_GAP
		- OUTER_MARGIN_BOTTOM
		- OPTIONS_LABEL_HEIGHT
		- OPTIONS_LABEL_GAP
	)


func _get_option_count_from_snapshot() -> int:
	var options_value: Variant = deal_snapshot.get("options", [])
	if not options_value is Array:
		return 0

	var count := 0
	for option_value in options_value:
		if option_value is Dictionary:
			count += 1
	return count


func _update_input_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel_shell != null:
		panel_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE if hover_ui_suppressed else Control.MOUSE_FILTER_STOP
	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if hover_ui_suppressed else Control.MOUSE_FILTER_STOP
		close_button.tooltip_text = "" if hover_ui_suppressed else "Close"
	for button in option_buy_buttons:
		if button == null:
			continue
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if hover_ui_suppressed else Control.MOUSE_FILTER_STOP
		button.tooltip_text = "" if hover_ui_suppressed else str(button.get_meta("blocked_reason", ""))


func _configure_styles() -> void:
	_configure_panel_style(row_style, ROW_FILL, ROW_BORDER, 1)
	_configure_panel_style(row_unavailable_style, ROW_UNAVAILABLE_FILL, ROW_UNAVAILABLE_BORDER, 1)
	_configure_panel_style(button_style, BUTTON_FILL, BUTTON_BORDER, 1)
	_configure_panel_style(button_hover_style, BUTTON_HOVER_FILL, BUTTON_HOVER_BORDER, 1)
	_configure_panel_style(button_unavailable_style, BUTTON_UNAVAILABLE_FILL, BUTTON_UNAVAILABLE_BORDER, 1)


func _configure_panel_style(style: StyleBoxFlat, fill: Color, border: Color, border_width: int) -> void:
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	_configure_panel_style(style, PANEL_FILL, PANEL_BORDER, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _apply_label_style(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.84))
	label.add_theme_constant_override("outline_size", outline_size)


func _apply_button_style(button: Button, font_size: int) -> void:
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.52, 0.42, 0.78))
	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_hover_style)
	button.add_theme_stylebox_override("pressed", button_hover_style)
	button.add_theme_stylebox_override("disabled", button_unavailable_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _get_deal_cost() -> int:
	return maxi(int(deal_snapshot.get("cost", 0)), 0)


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_option_pressed(item_id: String) -> void:
	deal_option_selected.emit(item_id)
