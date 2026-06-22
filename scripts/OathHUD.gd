extends Control
class_name OathHUD

# Gameplay Oath indicator. OathSystem owns the state and wording; this node
# only presents the active-oath snapshot and keeps empty HUD space pass-through.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const ROOT_SIZE := Vector2(390.0, 250.0)
const INDICATOR_SIZE := Vector2(310.0, 36.0)
const TOOLTIP_SIZE := Vector2(370.0, 204.0)
const TOOLTIP_OFFSET := Vector2(0.0, 44.0)

var oath_system: OathSystem
var latest_snapshot: Dictionary = {}
var indicator_panel: PanelContainer
var indicator_label: Label
var tooltip_panel: PanelContainer
var tooltip_title_label: Label
var tooltip_body_label: Label
var indicator_hovered := false
var hover_ui_suppressed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = ROOT_SIZE
	custom_minimum_size = ROOT_SIZE
	_build_indicator()
	_build_tooltip()
	set_oath_snapshot({})


func setup(system: OathSystem) -> void:
	if oath_system != null and oath_system.oaths_changed.is_connected(_on_oaths_changed):
		oath_system.oaths_changed.disconnect(_on_oaths_changed)

	oath_system = system
	if oath_system == null:
		set_oath_snapshot({})
		return

	if not oath_system.oaths_changed.is_connected(_on_oaths_changed):
		oath_system.oaths_changed.connect(_on_oaths_changed)
	set_oath_snapshot(oath_system.get_oath_snapshot())


func set_oath_snapshot(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot.duplicate(true)
	var active_oaths := _get_active_oaths()
	var has_active_oaths := not active_oaths.is_empty()
	visible = has_active_oaths
	if indicator_panel != null:
		indicator_panel.visible = has_active_oaths
	if not has_active_oaths:
		indicator_hovered = false
		if tooltip_panel != null:
			tooltip_panel.visible = false
		return

	if indicator_label != null:
		indicator_label.text = _format_indicator_text(active_oaths)
	_update_tooltip(active_oaths)
	if tooltip_panel != null:
		tooltip_panel.visible = indicator_hovered and not hover_ui_suppressed


func set_hover_ui_suppressed(suppressed: bool) -> void:
	if hover_ui_suppressed == suppressed:
		return

	hover_ui_suppressed = suppressed
	if suppressed:
		indicator_hovered = false
		if indicator_panel != null:
			indicator_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			indicator_panel.add_theme_stylebox_override("panel", _make_indicator_style(false))
		if tooltip_panel != null:
			tooltip_panel.visible = false
	else:
		if indicator_panel != null:
			indicator_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _build_indicator() -> void:
	indicator_panel = PanelContainer.new()
	indicator_panel.name = "OathIndicator"
	indicator_panel.size = INDICATOR_SIZE
	indicator_panel.custom_minimum_size = INDICATOR_SIZE
	indicator_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	indicator_panel.add_theme_stylebox_override("panel", _make_indicator_style(false))
	add_child(indicator_panel)
	indicator_panel.mouse_entered.connect(_on_indicator_mouse_entered)
	indicator_panel.mouse_exited.connect(_on_indicator_mouse_exited)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	indicator_panel.add_child(margin)

	indicator_label = Label.new()
	indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	indicator_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	indicator_label.add_theme_font_override("font", UI_FONT)
	indicator_label.add_theme_font_size_override("font_size", 15)
	indicator_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.48, 1.0))
	indicator_label.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.0, 0.78))
	indicator_label.add_theme_color_override("font_outline_color", Color(0.16, 0.05, 0.02, 0.92))
	indicator_label.add_theme_constant_override("shadow_offset_x", 2)
	indicator_label.add_theme_constant_override("shadow_offset_y", 2)
	indicator_label.add_theme_constant_override("outline_size", 2)
	margin.add_child(indicator_label)


func _build_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "OathTooltip"
	tooltip_panel.visible = false
	tooltip_panel.z_index = 2
	tooltip_panel.position = TOOLTIP_OFFSET
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
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	tooltip_title_label = _make_tooltip_label(19, Color(1.0, 0.88, 0.54, 1.0))
	stack.add_child(tooltip_title_label)

	tooltip_body_label = _make_tooltip_label(15, Color(0.86, 0.84, 0.72, 0.96))
	tooltip_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_body_label.custom_minimum_size = Vector2(330.0, 142.0)
	stack.add_child(tooltip_body_label)


func _make_indicator_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var fill_alpha := 0.78 if hovered else 0.62
	var border_alpha := 0.78 if hovered else 0.48
	style.bg_color = Color(0.055, 0.026, 0.018, fill_alpha)
	style.border_color = Color(1.0, 0.62, 0.28, border_alpha)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.026, 0.018, 0.92)
	style.border_color = Color(1.0, 0.62, 0.28, 0.66)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_tooltip_label(font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _get_active_oaths() -> Array:
	var active_value: Variant = latest_snapshot.get("active_oaths", [])
	if not active_value is Array:
		return []
	var active_oaths: Array = active_value
	return active_oaths


func _format_indicator_text(active_oaths: Array) -> String:
	if active_oaths.size() == 1 and active_oaths[0] is Dictionary:
		var oath: Dictionary = active_oaths[0]
		var label := str(oath.get("label", "Oath Active"))
		var remaining_text := str(oath.get("remaining_text", ""))
		if remaining_text.is_empty():
			return label
		return "%s: %s" % [label, remaining_text]
	return "OATHS ACTIVE: %s" % active_oaths.size()


func _update_tooltip(active_oaths: Array) -> void:
	if tooltip_title_label == null or tooltip_body_label == null:
		return

	if active_oaths.size() == 1 and active_oaths[0] is Dictionary:
		var oath: Dictionary = active_oaths[0]
		tooltip_title_label.text = str(oath.get("label", "Oath Active"))
		tooltip_body_label.text = _format_oath_tooltip_body(oath, false)
		return

	tooltip_title_label.text = "OATHS ACTIVE"
	var blocks: Array = []
	for oath_value in active_oaths:
		if oath_value is Dictionary:
			var oath: Dictionary = oath_value
			blocks.append(_format_oath_tooltip_body(oath, true))
	tooltip_body_label.text = "\n\n".join(blocks)


func _format_oath_tooltip_body(oath: Dictionary, include_name: bool) -> String:
	var lines: Array = []
	if include_name:
		lines.append(str(oath.get("label", "Oath Active")))

	var description := str(oath.get("description", "An oath is currently sworn."))
	if not description.is_empty():
		lines.append(description)

	var remaining_text := str(oath.get("remaining_text", "Active"))
	lines.append("")
	lines.append("Remaining:")
	lines.append(remaining_text)

	var failure_text := str(oath.get("failure_condition", "No failure condition listed."))
	lines.append("")
	lines.append("Failure:")
	lines.append(failure_text)

	var penalty_text := str(oath.get("penalty_text", "No first-pass penalty."))
	lines.append("")
	lines.append("Penalty:")
	lines.append(penalty_text)
	return "\n".join(lines)


func _on_indicator_mouse_entered() -> void:
	if hover_ui_suppressed:
		indicator_hovered = false
		if tooltip_panel != null:
			tooltip_panel.visible = false
		return

	indicator_hovered = true
	if indicator_panel != null:
		indicator_panel.add_theme_stylebox_override("panel", _make_indicator_style(true))
	if tooltip_panel != null:
		tooltip_panel.visible = visible


func _on_indicator_mouse_exited() -> void:
	indicator_hovered = false
	if indicator_panel != null:
		indicator_panel.add_theme_stylebox_override("panel", _make_indicator_style(false))
	if tooltip_panel != null:
		tooltip_panel.visible = false


func _on_oaths_changed(snapshot: Dictionary) -> void:
	set_oath_snapshot(snapshot)
