extends Control
class_name RogueliteRewardPanel

# index:title Roguelite Reward Panel
# index:category UI / Presentation
# index:status First Pass
# index:owner ui_agent
# index:notes Presentation-only reward choice panel for roguelite round-clear rewards.

signal reward_selected(reward_id: String)

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const PANEL_SIZE := Vector2(980.0, 430.0)
const VIEWPORT_MARGIN := 24.0
const CARD_SIZE := Vector2(270.0, 220.0)
const CARD_GAP := 26
const SHADE_COLOR := Color(0.01, 0.012, 0.016, 0.50)
const PANEL_Z_INDEX := 77

var shade: ColorRect
var panel: Panel
var panel_margin: MarginContainer
var card_row: HBoxContainer
var first_card_button: Button


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


func open_panel(reward_snapshot: Dictionary) -> void:
	_clear_cards()
	first_card_button = null

	var offers_value: Variant = reward_snapshot.get("offers", [])
	var offers: Array = []
	if offers_value is Array:
		offers = offers_value
	for offer_value in offers:
		var offer: Dictionary = offer_value as Dictionary
		if offer.is_empty():
			continue
		_add_reward_card(offer)

	visible = true
	_center_panel()
	if first_card_button != null:
		first_card_button.grab_focus()


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
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	panel_margin = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 34)
	panel_margin.add_theme_constant_override("margin_top", 26)
	panel_margin.add_theme_constant_override("margin_right", 34)
	panel_margin.add_theme_constant_override("margin_bottom", 28)
	_set_full_rect(panel_margin)
	panel.add_child(panel_margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 22)
	panel_margin.add_child(stack)

	var title_label: Label = Label.new()
	title_label.text = "Mark Your Course"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.012, 0.010, 0.92))
	title_label.add_theme_constant_override("outline_size", 5)
	stack.add_child(title_label)

	card_row = HBoxContainer.new()
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", CARD_GAP)
	stack.add_child(card_row)

	_center_panel()


func _add_reward_card(offer: Dictionary) -> void:
	var reward_id: String = str(offer.get("id", ""))
	if reward_id.is_empty():
		return

	var card: Button = Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.text = ""
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("normal", _make_card_style("normal"))
	card.add_theme_stylebox_override("hover", _make_card_style("hover"))
	card.add_theme_stylebox_override("pressed", _make_card_style("pressed"))
	card.add_theme_stylebox_override("focus", _make_card_style("focus"))
	card.pressed.connect(_on_reward_card_pressed.bind(reward_id))
	card_row.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	_set_full_rect(margin)
	card.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var name_label: Label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = str(offer.get("display_name", "Reward"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_override("font", UI_FONT)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.custom_minimum_size = Vector2(CARD_SIZE.x - 44.0, 50.0)
	stack.add_child(name_label)

	var description_label: Label = Label.new()
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.text = str(offer.get("description", ""))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_override("font", UI_FONT)
	description_label.add_theme_font_size_override("font_size", 16)
	description_label.add_theme_color_override("font_color", Color(0.84, 0.91, 0.82, 0.94))
	description_label.custom_minimum_size = Vector2(CARD_SIZE.x - 44.0, 118.0)
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(description_label)

	if first_card_button == null:
		first_card_button = card


func _clear_cards() -> void:
	if card_row == null:
		return
	for child in card_row.get_children():
		card_row.remove_child(child)
		child.queue_free()


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
		minf(PANEL_SIZE.x, available_size.x),
		minf(PANEL_SIZE.y, available_size.y)
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
	style.bg_color = Color(0.020, 0.018, 0.026, 0.90)
	style.border_color = Color(0.92, 0.72, 0.32, 0.66)
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


func _make_card_style(state: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = Color(0.15, 0.096, 0.044, 0.98)
			style.border_color = Color(1.0, 0.82, 0.38, 0.94)
		"pressed":
			style.bg_color = Color(0.88, 0.67, 0.31, 0.98)
			style.border_color = Color(1.0, 0.91, 0.62, 1.0)
		"focus":
			style.bg_color = Color(0.11, 0.070, 0.038, 0.96)
			style.border_color = Color(0.64, 0.95, 0.88, 0.78)
		_:
			style.bg_color = Color(0.035, 0.029, 0.027, 0.88)
			style.border_color = Color(0.76, 0.58, 0.28, 0.42)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _on_reward_card_pressed(reward_id: String) -> void:
	reward_selected.emit(reward_id)
