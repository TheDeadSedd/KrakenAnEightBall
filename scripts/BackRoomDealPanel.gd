extends PanelContainer
class_name BackRoomDealPanel

signal close_requested
signal deal_option_selected(item_id: String)

# Back Room Deal presentation only. BackRoomDealSystem owns definitions,
# economy checks, Reserve insertion, and spending.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const PANEL_SIZE := Vector2(344.0, 470.0)
const OPTION_HEIGHT := 58.0
const TITLE_TEXT := "Back Room Deal"
const FLAVOR_TEXT := "The Quartermaster can get what the manifest omits."
const CORNER_RADIUS := 9

const PANEL_FILL := Color(0.032, 0.024, 0.018, 0.96)
const PANEL_BORDER := Color(0.96, 0.78, 0.34, 0.50)
const BUTTON_FILL := Color(0.065, 0.052, 0.035, 0.78)
const BUTTON_BORDER := Color(0.96, 0.78, 0.34, 0.48)
const BUTTON_HOVER_FILL := Color(0.10, 0.075, 0.035, 0.88)
const BUTTON_HOVER_BORDER := Color(1.0, 0.86, 0.42, 0.86)
const BUTTON_UNAVAILABLE_FILL := Color(0.04, 0.038, 0.034, 0.52)
const BUTTON_UNAVAILABLE_BORDER := Color(0.52, 0.45, 0.34, 0.38)

var deal_snapshot: Dictionary = {}
var hover_ui_suppressed := false
var status_label: Label
var options_stack: VBoxContainer
var close_button: Button

var button_style := StyleBoxFlat.new()
var button_hover_style := StyleBoxFlat.new()
var button_unavailable_style := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("panel", _make_panel_style())
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


func _build_panel() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	stack.add_child(title_row)

	var title_label := Label.new()
	title_label.text = TITLE_TEXT
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	title_label.add_theme_constant_override("outline_size", 2)
	title_row.add_child(title_label)

	close_button = Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Close"
	close_button.custom_minimum_size = Vector2(32.0, 28.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_override("font", UI_FONT)
	close_button.add_theme_font_size_override("font_size", 14)
	close_button.add_theme_stylebox_override("normal", button_style)
	close_button.add_theme_stylebox_override("hover", button_hover_style)
	close_button.add_theme_stylebox_override("pressed", button_hover_style)
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	title_row.add_child(close_button)
	close_button.pressed.connect(_on_close_pressed)

	var flavor_label := Label.new()
	flavor_label.text = FLAVOR_TEXT
	flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor_label.add_theme_font_override("font", UI_FONT)
	flavor_label.add_theme_font_size_override("font_size", 14)
	flavor_label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.74, 0.94))
	flavor_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	flavor_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(flavor_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_override("font", UI_FONT)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36, 0.96))
	status_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	status_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(status_label)

	options_stack = VBoxContainer.new()
	options_stack.add_theme_constant_override("separation", 7)
	stack.add_child(options_stack)


func _refresh_panel() -> void:
	if status_label == null or options_stack == null:
		return

	var blocker: String = str(deal_snapshot.get("blocked_reason", ""))
	if blocker.is_empty():
		status_label.text = "Choose one item. Cost: %s Doubloons." % _get_deal_cost()
	else:
		status_label.text = "Unavailable: %s" % blocker

	_clear_options()
	var options_value: Variant = deal_snapshot.get("options", [])
	if not options_value is Array:
		return

	for option_value in options_value:
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value
		options_stack.add_child(_make_option_button(option))
	_update_input_filters()


func _clear_options() -> void:
	if options_stack == null:
		return
	for child in options_stack.get_children():
		child.queue_free()


func _make_option_button(option: Dictionary) -> Button:
	var button := Button.new()
	var item_id: String = str(option.get("id", ""))
	var available: bool = bool(option.get("available", false))
	var blocked_reason: String = str(option.get("blocked_reason", ""))
	button.text = _make_option_text(option)
	button.disabled = not available
	button.tooltip_text = "" if hover_ui_suppressed else blocked_reason
	button.set_meta("blocked_reason", blocked_reason)
	button.custom_minimum_size = Vector2(0.0, OPTION_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.58, 0.52, 0.42, 0.78))
	button.add_theme_stylebox_override("normal", button_style)
	button.add_theme_stylebox_override("hover", button_hover_style)
	button.add_theme_stylebox_override("pressed", button_hover_style)
	button.add_theme_stylebox_override("disabled", button_unavailable_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_option_pressed.bind(item_id))
	return button


func _make_option_text(option: Dictionary) -> String:
	var label: String = str(option.get("name", "Back Room Item"))
	var cost: int = maxi(int(option.get("cost", _get_deal_cost())), 0)
	var description: String = str(option.get("description", ""))
	var blocker: String = str(option.get("blocked_reason", ""))
	var first_line := "%s - %s Doubloons" % [label, cost]
	if not blocker.is_empty():
		return "%s\nUnavailable: %s" % [first_line, blocker]
	return "%s\n%s" % [first_line, description]


func _update_input_filters() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if hover_ui_suppressed else Control.MOUSE_FILTER_STOP
	if close_button != null:
		close_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if hover_ui_suppressed else Control.MOUSE_FILTER_STOP
		close_button.tooltip_text = "" if hover_ui_suppressed else "Close"
	if options_stack == null:
		return
	for child in options_stack.get_children():
		var button := child as Button
		if button == null:
			continue
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if hover_ui_suppressed else Control.MOUSE_FILTER_STOP
		button.tooltip_text = "" if hover_ui_suppressed else str(button.get_meta("blocked_reason", ""))


func _configure_styles() -> void:
	_configure_button_style(button_style, BUTTON_FILL, BUTTON_BORDER)
	_configure_button_style(button_hover_style, BUTTON_HOVER_FILL, BUTTON_HOVER_BORDER)
	_configure_button_style(button_unavailable_style, BUTTON_UNAVAILABLE_FILL, BUTTON_UNAVAILABLE_BORDER)


func _configure_button_style(style: StyleBoxFlat, fill: Color, border: Color) -> void:
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _get_deal_cost() -> int:
	return maxi(int(deal_snapshot.get("cost", 0)), 0)


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_option_pressed(item_id: String) -> void:
	deal_option_selected.emit(item_id)
