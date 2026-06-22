extends Control
class_name PassageHUD

signal request_reroll_requested

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const PANEL_SIZE := Vector2(420.0, 64.0)
const TOOLTIP_SIZE := Vector2(350.0, 174.0)
const REQUEST_LABEL_WIDTH := 220.0
const REROLL_BUTTON_POSITION := Vector2(238.0, 34.0)
const REROLL_BUTTON_SIZE := Vector2(170.0, 24.0)

var passage_system: PassageSystem
var passage_label: Label
var request_label: Label
var reroll_button: Button
var tooltip_panel: PanelContainer
var tooltip_title_label: Label
var tooltip_description_label: Label
var tooltip_reward_label: Label
var latest_snapshot: Dictionary = {}
var request_hovered := false
var reroll_hovered := false
var hover_ui_suppressed := false
var panel_style := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	_configure_panel_style()
	_build_labels()
	_build_reroll_button()
	_build_tooltip()
	set_passage_snapshot({})


func setup(system: PassageSystem) -> void:
	if passage_system != null and passage_system.passage_changed.is_connected(_on_passage_changed):
		passage_system.passage_changed.disconnect(_on_passage_changed)

	passage_system = system
	if passage_system == null:
		set_passage_snapshot({})
		return

	if not passage_system.passage_changed.is_connected(_on_passage_changed):
		passage_system.passage_changed.connect(_on_passage_changed)
	set_passage_snapshot(passage_system.get_passage_snapshot())


func set_passage_snapshot(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot.duplicate(true)
	var remaining := maxi(int(snapshot.get("remaining_passage", 0)), 0)
	var request_label_text := str(snapshot.get("current_request_label", ""))
	if request_label_text.is_empty():
		request_label_text = "NONE"

	if passage_label != null:
		passage_label.text = "PASSAGE: %s" % remaining
	if request_label != null:
		request_label.text = "KRAKEN WANTS: %s" % request_label_text
	if reroll_button != null:
		var reroll_cost := maxi(int(snapshot.get("current_request_reroll_cost", 0)), 0)
		reroll_button.text = "Reroll: +%s Passage" % reroll_cost
		reroll_button.disabled = not bool(snapshot.get("request_reroll_available", false))
	_update_tooltip()


func set_hover_ui_suppressed(suppressed: bool) -> void:
	if hover_ui_suppressed == suppressed:
		return

	hover_ui_suppressed = suppressed
	if suppressed:
		request_hovered = false
		reroll_hovered = false
		if request_label != null:
			request_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if reroll_button != null:
			reroll_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			reroll_button.release_focus()
		if tooltip_panel != null:
			tooltip_panel.visible = false
	else:
		if request_label != null:
			request_label.mouse_filter = Control.MOUSE_FILTER_STOP
		if reroll_button != null:
			reroll_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	draw_style_box(panel_style, Rect2(Vector2.ZERO, size))


func _configure_panel_style() -> void:
	panel_style.bg_color = Color(0.035, 0.026, 0.018, 0.52)
	panel_style.border_color = Color(0.96, 0.78, 0.34, 0.30)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7


func _build_labels() -> void:
	passage_label = _make_label(Vector2(12.0, 7.0), 18, Color(1.0, 0.86, 0.36, 1.0))
	request_label = _make_label(Vector2(12.0, 34.0), 15, Color(0.78, 0.94, 0.90, 0.96))
	request_label.mouse_filter = Control.MOUSE_FILTER_STOP
	request_label.size = Vector2(REQUEST_LABEL_WIDTH, 24.0)
	add_child(passage_label)
	add_child(request_label)
	request_label.mouse_entered.connect(_on_request_mouse_entered)
	request_label.mouse_exited.connect(_on_request_mouse_exited)


func _build_reroll_button() -> void:
	reroll_button = Button.new()
	reroll_button.name = "RerollRequestButton"
	reroll_button.position = REROLL_BUTTON_POSITION
	reroll_button.size = REROLL_BUTTON_SIZE
	reroll_button.custom_minimum_size = REROLL_BUTTON_SIZE
	reroll_button.mouse_filter = Control.MOUSE_FILTER_STOP
	reroll_button.focus_mode = Control.FOCUS_NONE
	reroll_button.add_theme_font_override("font", UI_FONT)
	reroll_button.add_theme_font_size_override("font_size", 13)
	reroll_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54, 0.96))
	reroll_button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))
	reroll_button.add_theme_color_override("font_disabled_color", Color(0.56, 0.50, 0.40, 0.70))
	reroll_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.055, 0.042, 0.028, 0.66), Color(0.96, 0.78, 0.34, 0.34)))
	reroll_button.add_theme_stylebox_override("hover", _make_button_style(Color(0.09, 0.065, 0.032, 0.82), Color(1.0, 0.86, 0.42, 0.74)))
	reroll_button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.05, 0.11, 0.10, 0.82), Color(0.45, 0.94, 0.86, 0.70)))
	reroll_button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.035, 0.030, 0.026, 0.46), Color(0.52, 0.45, 0.34, 0.28)))
	reroll_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(reroll_button)
	reroll_button.pressed.connect(_on_reroll_button_pressed)
	reroll_button.mouse_entered.connect(_on_reroll_mouse_entered)
	reroll_button.mouse_exited.connect(_on_reroll_mouse_exited)


func _build_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "KrakenRequestTooltip"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 2
	tooltip_panel.position = Vector2(42.0, PANEL_SIZE.y + 8.0)
	tooltip_panel.size = TOOLTIP_SIZE
	tooltip_panel.custom_minimum_size = TOOLTIP_SIZE
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_theme_stylebox_override("panel", _make_tooltip_style())
	add_child(tooltip_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	tooltip_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	tooltip_title_label = _make_tooltip_label(19, Color(1.0, 0.88, 0.54, 1.0))
	stack.add_child(tooltip_title_label)

	tooltip_description_label = _make_tooltip_label(15, Color(0.86, 0.84, 0.72, 0.96))
	tooltip_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_description_label.custom_minimum_size = Vector2(312.0, 58.0)
	stack.add_child(tooltip_description_label)

	tooltip_reward_label = _make_tooltip_label(16, Color(0.78, 0.94, 0.90, 0.98))
	tooltip_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_reward_label.custom_minimum_size = Vector2(312.0, 42.0)
	stack.add_child(tooltip_reward_label)


func _make_label(label_position: Vector2, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = Vector2(PANEL_SIZE.x - 24.0, 24.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.0, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.16, 0.07, 0.02, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_tooltip_label(font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.026, 0.018, 0.90)
	style.border_color = Color(0.96, 0.78, 0.34, 0.58)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _update_tooltip() -> void:
	if tooltip_title_label == null:
		return

	if reroll_hovered:
		_update_reroll_tooltip()
		return

	_update_request_tooltip()


func _update_request_tooltip() -> void:
	var request_label_text := str(latest_snapshot.get("current_request_label", "Unknown Request"))
	var request_description := str(latest_snapshot.get("current_request_description", "Complete this requested scoring feat."))
	var reward := maxi(int(latest_snapshot.get("current_request_reward", 0)), 0)
	tooltip_title_label.text = request_label_text
	tooltip_description_label.text = request_description
	tooltip_reward_label.text = "Reward:\n-%s Passage" % reward


func _update_reroll_tooltip() -> void:
	var cost := maxi(int(latest_snapshot.get("current_request_reroll_cost", 0)), 0)
	var decay := maxi(int(latest_snapshot.get("request_reroll_completion_decay", 0)), 0)
	tooltip_title_label.text = "REROLL REQUEST"
	tooltip_description_label.text = "Replace the Kraken's current demand. This adds Passage instead of spending Doubloons."
	tooltip_reward_label.text = "Cost:\n+%s Passage\nCost rises after rerolls. Completing requests lowers it by %s." % [cost, decay]


func _on_request_mouse_entered() -> void:
	if hover_ui_suppressed:
		request_hovered = false
		_update_tooltip_visibility()
		return

	request_hovered = true
	_update_tooltip()
	if tooltip_panel != null:
		tooltip_panel.visible = true


func _on_request_mouse_exited() -> void:
	request_hovered = false
	_update_tooltip()
	_update_tooltip_visibility()


func _on_reroll_mouse_entered() -> void:
	if hover_ui_suppressed:
		reroll_hovered = false
		_update_tooltip_visibility()
		return

	reroll_hovered = true
	_update_tooltip()
	if tooltip_panel != null:
		tooltip_panel.visible = true


func _on_reroll_mouse_exited() -> void:
	reroll_hovered = false
	_update_tooltip()
	_update_tooltip_visibility()


func _update_tooltip_visibility() -> void:
	if tooltip_panel != null:
		tooltip_panel.visible = not hover_ui_suppressed and (request_hovered or reroll_hovered)


func _on_reroll_button_pressed() -> void:
	if hover_ui_suppressed:
		return
	request_reroll_requested.emit()


func _on_passage_changed(snapshot: Dictionary) -> void:
	set_passage_snapshot(snapshot)
