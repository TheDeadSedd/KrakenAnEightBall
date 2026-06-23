extends Control
class_name TableEventMenu

signal event_offer_selected(offer_index: int)
signal boon_offer_selected(boon_offer_index: int)
signal event_offer_replace_requested(offer_index: int, oath_id: String)
signal menu_closed

# Compact Kraken Intervention choice menu. It presents Omens, while Table Event
# remains the internal architecture name.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const OFFER_SLOT_COUNT := 3
const TABLE_CENTER := Vector2(960.0, 540.0)
const PANEL_SIZE := Vector2(860.0, 408.0)
const OATH_CHOICE_PANEL_SIZE := Vector2(610.0, 430.0)
const CARD_SIZE := Vector2(250.0, 160.0)
const BOON_CARD_SIZE := Vector2(196.0, 68.0)
const BOON_TOOLTIP_SIZE := Vector2(350.0, 174.0)
const BOON_TOOLTIP_VIEWPORT_MARGIN := 10.0
const OATH_CHOICE_ROW_SIZE := Vector2(548.0, 82.0)
const CARD_GAP := 12
const CARD_HORIZONTAL_PADDING := 11
const CARD_VERTICAL_PADDING := 7
const CARD_TEXT_SEPARATION := 2
const PANEL_COLOR := Color(0.035, 0.026, 0.018, 0.96)
const PANEL_BORDER := Color(0.96, 0.78, 0.34, 0.70)
const CARD_COLOR := Color(0.055, 0.046, 0.034, 0.94)
const CARD_DISABLED_COLOR := Color(0.035, 0.032, 0.030, 0.72)
const CARD_BORDER := Color(0.78, 0.62, 0.30, 0.54)
const CARD_HOVER_BORDER := Color(1.0, 0.82, 0.34, 0.96)
const CARD_PRESSED_COLOR := Color(0.12, 0.082, 0.035, 0.98)
const REPLACE_BUTTON_SIZE := Vector2(108.0, 23.0)
const TEXT_COLOR := Color(0.94, 0.88, 0.68, 1.0)
const COST_COLOR := Color(1.0, 0.78, 0.32, 1.0)
const DISABLED_TEXT_COLOR := Color(0.53, 0.48, 0.39, 0.82)
const STATUS_COLOR := Color(0.76, 0.88, 0.82, 0.96)
const OATH_CHOICE_IDS := [
	OathSystem.OATH_OF_URGENCY,
	OathSystem.OATH_OF_ISOLATION,
	OathSystem.OATH_OF_HUMILITY,
]

var table_event_system: TableEventSystem
var offer_buttons: Array[Button] = []
var offer_name_labels: Array[Label] = []
var offer_meta_labels: Array[Label] = []
var offer_description_labels: Array[Label] = []
var offer_status_labels: Array[Label] = []
var offer_replace_buttons: Array[Button] = []
var boon_section: VBoxContainer
var boon_offer_row: HBoxContainer
var boon_offer_buttons: Array[Button] = []
var boon_offer_name_labels: Array[Label] = []
var boon_offer_meta_labels: Array[Label] = []
var boon_offer_status_labels: Array[Label] = []
var boon_tooltip_panel: PanelContainer
var boon_tooltip_title_label: Label
var boon_tooltip_details_label: Label
var boon_tooltip_description_label: Label
var current_boon_offers: Array = []
var hovered_boon_offer_index := -1
var status_label: Label
var title_label: Label
var close_button: Button
var panel: Panel
var oath_choice_panel: Panel
var oath_choice_status_label: Label
var oath_choice_cancel_button: Button
var oath_choice_buttons: Dictionary = {}
var oath_choice_name_labels: Dictionary = {}
var oath_choice_description_labels: Dictionary = {}
var oath_choice_duration_labels: Dictionary = {}
var oath_choice_consequence_labels: Dictionary = {}
var oath_choice_status_labels: Dictionary = {}
var replace_press_guard_offer_index := -1
var pending_oath_replace_offer_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_menu()
	_center_panel()


func setup(system: TableEventSystem) -> void:
	_disconnect_table_event_system()
	table_event_system = system
	if table_event_system == null:
		return
	table_event_system.offers_changed.connect(_on_offers_changed)
	table_event_system.boon_offers_changed.connect(_on_boon_offers_changed)
	table_event_system.status_changed.connect(_on_status_changed)
	_refresh_offers(table_event_system.get_event_offers_snapshot())
	_refresh_boon_offers(table_event_system.get_boon_offers_snapshot())


func open_menu() -> void:
	if table_event_system == null or not table_event_system.is_event_icon_clickable():
		return
	visible = true
	panel.visible = true
	if oath_choice_panel != null:
		oath_choice_panel.visible = false
	pending_oath_replace_offer_index = -1
	table_event_system.set_event_menu_open(true)
	refresh_offers()
	status_label.text = "Choose an omen to unleash, or claim a short-lived boon below."


func close_menu() -> void:
	if table_event_system != null:
		table_event_system.set_event_menu_open(false)
	if oath_choice_panel != null:
		oath_choice_panel.visible = false
	_hide_boon_tooltip()
	if panel != null:
		panel.visible = true
	pending_oath_replace_offer_index = -1
	visible = false
	menu_closed.emit()


func refresh_offers() -> void:
	if table_event_system == null:
		return
	_refresh_offers(table_event_system.get_event_offers_snapshot())
	_refresh_boon_offers(table_event_system.get_boon_offers_snapshot())


func _build_menu() -> void:
	add_child(_build_shade())

	panel = _build_panel()
	add_child(panel)

	var margin := _build_panel_margin()
	panel.add_child(margin)

	var root := _build_root_stack()
	margin.add_child(root)

	root.add_child(_build_header())
	status_label = _build_status_label()
	root.add_child(status_label)
	root.add_child(_build_offer_row())
	root.add_child(_build_boon_section())

	oath_choice_panel = _build_oath_choice_panel()
	add_child(oath_choice_panel)
	boon_tooltip_panel = _build_boon_tooltip_panel()
	add_child(boon_tooltip_panel)


func _build_shade() -> ColorRect:
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.color = Color(0.0, 0.0, 0.0, 0.06)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	return shade


func _build_panel() -> Panel:
	var menu_panel := Panel.new()
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_panel.clip_contents = true
	menu_panel.custom_minimum_size = Vector2.ZERO
	menu_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_style_panel(menu_panel)
	return menu_panel


func _build_panel_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	return margin


func _build_root_stack() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	return root


func _build_header() -> HBoxContainer:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.add_child(_build_title_label())
	header.add_child(_build_close_button())
	return header


func _build_title_label() -> Label:
	title_label = Label.new()
	title_label.text = "Request Kraken Intervention..."
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.46, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	title_label.add_theme_constant_override("outline_size", 3)
	return title_label


func _build_close_button() -> Button:
	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76.0, 30.0)
	close_button.add_theme_font_override("font", UI_FONT)
	close_button.add_theme_font_size_override("font_size", 14)
	close_button.pressed.connect(close_menu)
	return close_button


func _build_status_label() -> Label:
	var label := Label.new()
	label.text = "Spend Intervention Charges to unleash one omen, or close and keep the choice."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", STATUS_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.86))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _build_offer_row() -> HBoxContainer:
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.custom_minimum_size = Vector2(0.0, CARD_SIZE.y)
	cards.add_theme_constant_override("separation", CARD_GAP)
	for offer_index in range(OFFER_SLOT_COUNT):
		cards.add_child(_build_offer_card(offer_index))
	return cards


func _build_boon_section() -> VBoxContainer:
	boon_section = VBoxContainer.new()
	boon_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boon_section.add_theme_constant_override("separation", 3)

	var section_title := _make_offer_card_label(15, Color(1.0, 0.84, 0.46, 1.0))
	section_title.text = "Kraken Boons"
	section_title.custom_minimum_size = Vector2(0.0, 19.0)
	boon_section.add_child(section_title)

	boon_offer_row = HBoxContainer.new()
	boon_offer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boon_offer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	boon_offer_row.add_theme_constant_override("separation", CARD_GAP)
	boon_offer_row.custom_minimum_size = Vector2(0.0, BOON_CARD_SIZE.y)
	boon_section.add_child(boon_offer_row)
	return boon_section


func _build_offer_card(offer_index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_offer_card(button)
	button.pressed.connect(_on_offer_button_pressed.bind(offer_index))
	_add_offer_card_content(button)
	offer_buttons.append(button)
	return button


func _build_boon_offer_card(boon_offer_index: int) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = BOON_CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.tooltip_text = ""
	_style_boon_card(button)
	button.pressed.connect(_on_boon_offer_button_pressed.bind(boon_offer_index))
	button.mouse_entered.connect(_on_boon_offer_mouse_entered.bind(boon_offer_index))
	button.mouse_exited.connect(_on_boon_offer_mouse_exited.bind(boon_offer_index))
	_add_boon_offer_card_content(button)
	boon_offer_buttons.append(button)
	return button


func _build_boon_tooltip_panel() -> PanelContainer:
	var tooltip: PanelContainer = PanelContainer.new()
	tooltip.name = "KrakenBoonTooltip"
	tooltip.visible = false
	tooltip.z_index = 3
	tooltip.size = BOON_TOOLTIP_SIZE
	tooltip.custom_minimum_size = BOON_TOOLTIP_SIZE
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_theme_stylebox_override("panel", _make_boon_tooltip_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	tooltip.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	boon_tooltip_title_label = _make_boon_tooltip_label(19, Color(1.0, 0.88, 0.54, 1.0))
	stack.add_child(boon_tooltip_title_label)

	boon_tooltip_details_label = _make_boon_tooltip_label(15, Color(0.78, 0.94, 0.90, 0.98))
	boon_tooltip_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boon_tooltip_details_label.custom_minimum_size = Vector2(312.0, 46.0)
	stack.add_child(boon_tooltip_details_label)

	boon_tooltip_description_label = _make_boon_tooltip_label(14, Color(0.86, 0.84, 0.72, 0.96))
	boon_tooltip_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boon_tooltip_description_label.custom_minimum_size = Vector2(312.0, 58.0)
	stack.add_child(boon_tooltip_description_label)
	return tooltip


func _build_oath_choice_panel() -> Panel:
	var oath_panel := Panel.new()
	oath_panel.visible = false
	oath_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	oath_panel.clip_contents = true
	oath_panel.z_index = 2
	oath_panel.custom_minimum_size = OATH_CHOICE_PANEL_SIZE
	oath_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	oath_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR, PANEL_BORDER, 2, 14))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	oath_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var oath_title := _make_oath_choice_label(24, Color(1.0, 0.84, 0.46, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	oath_title.text = "Swear an Oath"
	oath_title.add_theme_constant_override("outline_size", 3)
	stack.add_child(oath_title)

	oath_choice_status_label = _make_oath_choice_label(13, STATUS_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	oath_choice_status_label.text = "Choose what price the Kraken may remember."
	oath_choice_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(oath_choice_status_label)

	for oath_id_value in OATH_CHOICE_IDS:
		var oath_id := str(oath_id_value)
		var row := _build_oath_choice_row(oath_id)
		stack.add_child(row)

	oath_choice_cancel_button = Button.new()
	oath_choice_cancel_button.text = "Cancel"
	oath_choice_cancel_button.custom_minimum_size = Vector2(130.0, 32.0)
	oath_choice_cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	oath_choice_cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
	oath_choice_cancel_button.focus_mode = Control.FOCUS_ALL
	oath_choice_cancel_button.add_theme_font_override("font", UI_FONT)
	oath_choice_cancel_button.add_theme_font_size_override("font_size", 15)
	oath_choice_cancel_button.pressed.connect(_on_oath_choice_cancel_pressed)
	stack.add_child(oath_choice_cancel_button)

	return oath_panel


func _build_oath_choice_row(oath_id: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = OATH_CHOICE_ROW_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_stylebox_override("normal", _make_panel_style(CARD_COLOR, CARD_BORDER, 1, 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(CARD_COLOR.lightened(0.08), CARD_HOVER_BORDER, 2, 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_PRESSED_COLOR, CARD_HOVER_BORDER, 2, 8))
	button.add_theme_stylebox_override("disabled", _make_panel_style(CARD_DISABLED_COLOR, CARD_BORDER.darkened(0.25), 1, 8))
	button.pressed.connect(_on_oath_choice_pressed.bind(oath_id))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	button.add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 1)
	margin.add_child(stack)

	var name_label := _make_oath_choice_label(16, TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	stack.add_child(name_label)
	oath_choice_name_labels[oath_id] = name_label

	var description_label := _make_oath_choice_label(12, TEXT_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(description_label)
	oath_choice_description_labels[oath_id] = description_label

	var duration_label := _make_oath_choice_label(12, STATUS_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	stack.add_child(duration_label)
	oath_choice_duration_labels[oath_id] = duration_label

	var consequence_label := _make_oath_choice_label(12, COST_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	stack.add_child(consequence_label)
	oath_choice_consequence_labels[oath_id] = consequence_label

	var status_line := _make_oath_choice_label(12, STATUS_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	stack.add_child(status_line)
	oath_choice_status_labels[oath_id] = status_line

	oath_choice_buttons[oath_id] = button
	return button


func _make_oath_choice_label(font_size: int, font_color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.01, 0.92))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _style_panel(menu_panel: Panel) -> void:
	menu_panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR, PANEL_BORDER, 2, 14))


func _style_offer_card(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_panel_style(CARD_COLOR, CARD_BORDER, 1, 10))
	button.add_theme_stylebox_override("hover", _make_panel_style(CARD_COLOR.lightened(0.08), CARD_HOVER_BORDER, 2, 10))
	button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_PRESSED_COLOR, CARD_HOVER_BORDER, 2, 10))
	button.add_theme_stylebox_override("disabled", _make_panel_style(CARD_DISABLED_COLOR, CARD_BORDER.darkened(0.25), 1, 10))


func _style_boon_card(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.038, 0.062, 0.058, 0.94), Color(0.42, 0.92, 0.82, 0.52), 1, 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.052, 0.088, 0.080, 0.98), Color(0.62, 1.0, 0.90, 0.86), 2, 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.030, 0.108, 0.092, 0.98), Color(0.76, 1.0, 0.90, 0.96), 2, 8))
	button.add_theme_stylebox_override("disabled", _make_panel_style(CARD_DISABLED_COLOR, CARD_BORDER.darkened(0.18), 1, 8))


func _make_boon_tooltip_label(font_size: int, font_color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_boon_tooltip_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_panel()


func _center_panel() -> void:
	if panel == null:
		return
	panel.size = PANEL_SIZE
	panel.position = Vector2(
		TABLE_CENTER.x - PANEL_SIZE.x * 0.5,
		TABLE_CENTER.y - PANEL_SIZE.y * 0.5
	)
	if oath_choice_panel != null:
		oath_choice_panel.size = OATH_CHOICE_PANEL_SIZE
		oath_choice_panel.position = Vector2(
			TABLE_CENTER.x - OATH_CHOICE_PANEL_SIZE.x * 0.5,
			TABLE_CENTER.y - OATH_CHOICE_PANEL_SIZE.y * 0.5
		)


func _refresh_offers(offers: Array) -> void:
	for offer_index in range(OFFER_SLOT_COUNT):
		var button: Button = offer_buttons[offer_index]
		var offer: Dictionary = _get_offer(offers, offer_index)
		var has_offer := not offer.is_empty() and str(offer.get("id", TableEventSystem.EMPTY_OFFER_ID)) != TableEventSystem.EMPTY_OFFER_ID
		var purchase_blocked := not bool(offer.get("available", false))
		button.disabled = not has_offer
		_refresh_offer_card_content(offer_index, offer, purchase_blocked)


func _refresh_boon_offers(offers: Array) -> void:
	_clear_boon_offer_cards()
	current_boon_offers = offers.duplicate(true)
	_hide_boon_tooltip()
	if boon_section == null:
		return

	boon_section.visible = not offers.is_empty()
	if offers.is_empty():
		return

	for boon_offer_index in range(offers.size()):
		var offer: Dictionary = _get_offer(offers, boon_offer_index)
		var button := _build_boon_offer_card(boon_offer_index)
		boon_offer_row.add_child(button)
		var has_offer := not offer.is_empty() and str(offer.get("id", TableEventSystem.EMPTY_OFFER_ID)) != TableEventSystem.EMPTY_OFFER_ID
		var purchase_blocked := not bool(offer.get("available", false))
		button.disabled = not has_offer or purchase_blocked
		_refresh_boon_offer_card_content(boon_offer_index, offer, purchase_blocked)


func _refresh_offer_card_content(offer_index: int, offer: Dictionary, disabled: bool) -> void:
	if offer.is_empty():
		offer_name_labels[offer_index].text = "Unknown Event"
		offer_meta_labels[offer_index].text = ""
		offer_description_labels[offer_index].text = "The deep says nothing."
		offer_status_labels[offer_index].text = "Unavailable"
		if offer_index >= 0 and offer_index < offer_replace_buttons.size():
			var empty_replace_button: Button = offer_replace_buttons[offer_index]
			empty_replace_button.disabled = true
			empty_replace_button.tooltip_text = "This omen cannot be replaced."
		_set_offer_card_colors(offer_index, true)
		return

	var charge_cost: int = int(offer.get("charge_cost", offer.get("cost", 0)))
	var doubloon_cost: int = int(offer.get("doubloon_cost", 0))
	var cost_text: String = _format_offer_cost_text(charge_cost, doubloon_cost)
	var rarity: String = str(offer.get("rarity", ""))
	var offer_type := str(offer.get("type", TableEventSystem.OFFER_TYPE_INTERVENTION))
	var duration_shots := maxi(int(offer.get("duration_shots", 0)), 0)
	var rarity_suffix := "Boon" if offer_type == TableEventSystem.OFFER_TYPE_BOON else "Omen"
	var rarity_text: String = "%s %s" % [rarity, rarity_suffix] if not rarity.is_empty() else rarity_suffix
	if offer_type == TableEventSystem.OFFER_TYPE_BOON and duration_shots > 0:
		rarity_text = "%s  |  %s shots" % [rarity_text, duration_shots]
	var cost_line: String = cost_text
	if not rarity_text.is_empty():
		cost_line = "%s  |  %s" % [cost_text, rarity_text]
	var blocker: String = str(offer.get("blocked_reason", ""))
	var availability_text: String = "Ready to unleash"
	if not blocker.is_empty():
		availability_text = blocker
	var reroll_blocker := str(offer.get("reroll_blocked_reason", ""))
	var can_reroll := bool(offer.get("reroll_available", false))

	offer_name_labels[offer_index].text = str(offer.get("name", "Table Event"))
	offer_meta_labels[offer_index].text = cost_line
	offer_description_labels[offer_index].text = str(offer.get("description", ""))
	offer_status_labels[offer_index].text = availability_text
	if offer_index >= 0 and offer_index < offer_replace_buttons.size():
		var replace_button: Button = offer_replace_buttons[offer_index]
		replace_button.disabled = not can_reroll
		if can_reroll:
			replace_button.tooltip_text = "Choose an Oath to replace this omen."
		else:
			replace_button.tooltip_text = reroll_blocker if not reroll_blocker.is_empty() else "This omen cannot be replaced."
	_set_offer_card_colors(offer_index, disabled)


func _refresh_boon_offer_card_content(boon_offer_index: int, offer: Dictionary, disabled: bool) -> void:
	if offer.is_empty():
		return

	var charge_cost: int = int(offer.get("charge_cost", offer.get("cost", 0)))
	var doubloon_cost: int = int(offer.get("doubloon_cost", 0))
	var cost_text: String = _format_offer_cost_amount_text(charge_cost, doubloon_cost)
	var is_active: bool = bool(offer.get("active", false))

	boon_offer_name_labels[boon_offer_index].text = str(offer.get("name", "Kraken Boon"))
	boon_offer_meta_labels[boon_offer_index].text = cost_text
	boon_offer_status_labels[boon_offer_index].text = "ACTIVE" if is_active else ""
	_set_boon_offer_card_colors(boon_offer_index, disabled, is_active)


func _get_boon_offer_tooltip_details(offer: Dictionary, charge_cost: int, doubloon_cost: int) -> String:
	var lines: Array[String] = []
	var cost_text: String = _format_offer_cost_amount_text(charge_cost, doubloon_cost)
	var duration_shots: int = maxi(int(offer.get("duration_shots", 0)), 0)
	var is_active: bool = bool(offer.get("active", false))
	var active_remaining_shots: int = maxi(int(offer.get("active_remaining_shots", 0)), 0)
	var blocker: String = str(offer.get("blocked_reason", ""))

	if is_active:
		lines.append("Active: %s remaining" % _format_shots(active_remaining_shots))
		lines.append("Refresh: %s" % cost_text)
	else:
		lines.append("Cost: %s" % cost_text)
		if duration_shots > 0:
			lines.append("Duration: %s" % _format_shots(duration_shots))
	if not blocker.is_empty():
		var need_text: String = blocker
		if need_text.begins_with("Need "):
			need_text = need_text.substr(5)
		lines.append("Need: %s" % need_text)
	return "\n".join(lines)


func _format_offer_cost_text(charge_cost: int, doubloon_cost: int) -> String:
	return "Cost: %s" % _format_offer_cost_amount_text(charge_cost, doubloon_cost)


func _format_offer_cost_amount_text(charge_cost: int, doubloon_cost: int) -> String:
	var parts: Array[String] = []
	if charge_cost > 0:
		parts.append("%s Charge%s" % [charge_cost, "" if charge_cost == 1 else "s"])
	if doubloon_cost > 0:
		parts.append("%s Doubloon%s" % [doubloon_cost, "" if doubloon_cost == 1 else "s"])
	if parts.is_empty():
		return "Free"
	return " + ".join(parts)


func _format_shots(count: int) -> String:
	var safe_count: int = maxi(count, 0)
	return "%s shot%s" % [safe_count, "" if safe_count == 1 else "s"]


func _add_offer_card_content(button: Button) -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", CARD_HORIZONTAL_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_VERTICAL_PADDING)
	margin.add_theme_constant_override("margin_right", CARD_HORIZONTAL_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_VERTICAL_PADDING)
	button.add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", CARD_TEXT_SEPARATION)
	margin.add_child(stack)

	var name_label := _make_offer_card_label(16, TEXT_COLOR)
	name_label.custom_minimum_size = Vector2(0.0, 22.0)
	stack.add_child(name_label)
	offer_name_labels.append(name_label)

	var meta_label := _make_offer_card_label(12, COST_COLOR)
	meta_label.custom_minimum_size = Vector2(0.0, 31.0)
	stack.add_child(meta_label)
	offer_meta_labels.append(meta_label)

	var description_label := _make_offer_card_label(12, TEXT_COLOR)
	description_label.custom_minimum_size = Vector2(0.0, 41.0)
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(description_label)
	offer_description_labels.append(description_label)

	var status_line := _make_offer_card_label(13, STATUS_COLOR)
	status_line.custom_minimum_size = Vector2(0.0, 17.0)
	stack.add_child(status_line)
	offer_status_labels.append(status_line)

	var replace_button := _make_replace_button(offer_replace_buttons.size())
	stack.add_child(replace_button)
	offer_replace_buttons.append(replace_button)


func _add_boon_offer_card_content(button: Button) -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 4)
	button.add_child(margin)

	var text_stack := VBoxContainer.new()
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 0)
	margin.add_child(text_stack)

	var name_label := _make_offer_card_label(13, TEXT_COLOR)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(0.0, 19.0)
	text_stack.add_child(name_label)
	boon_offer_name_labels.append(name_label)

	var meta_label := _make_offer_card_label(10, COST_COLOR)
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta_label.custom_minimum_size = Vector2(0.0, 18.0)
	text_stack.add_child(meta_label)
	boon_offer_meta_labels.append(meta_label)

	var status_line := _make_offer_card_label(11, STATUS_COLOR)
	status_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_line.custom_minimum_size = Vector2(0.0, 15.0)
	status_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	text_stack.add_child(status_line)
	boon_offer_status_labels.append(status_line)


func _make_offer_card_label(font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.01, 0.92))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_replace_button(offer_index: int) -> Button:
	var button := Button.new()
	button.text = "Replace"
	button.tooltip_text = "Swear an Oath to replace this omen."
	button.custom_minimum_size = REPLACE_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54, 0.96))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT_COLOR)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.055, 0.043, 0.028, 0.72), Color(0.96, 0.78, 0.34, 0.42), 1, 6))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.09, 0.065, 0.034, 0.90), CARD_HOVER_BORDER, 1, 6))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.05, 0.11, 0.10, 0.92), Color(0.45, 0.94, 0.86, 0.78), 1, 6))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.035, 0.032, 0.030, 0.52), Color(0.48, 0.42, 0.32, 0.32), 1, 6))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.button_down.connect(_on_offer_replace_button_down.bind(offer_index))
	button.pressed.connect(_on_offer_replace_button_pressed.bind(offer_index))
	return button


func _set_offer_card_colors(offer_index: int, disabled: bool) -> void:
	var primary_color: Color = DISABLED_TEXT_COLOR if disabled else TEXT_COLOR
	var meta_color: Color = DISABLED_TEXT_COLOR if disabled else COST_COLOR
	var status_color: Color = DISABLED_TEXT_COLOR if disabled else STATUS_COLOR
	offer_name_labels[offer_index].add_theme_color_override("font_color", primary_color)
	offer_meta_labels[offer_index].add_theme_color_override("font_color", meta_color)
	offer_description_labels[offer_index].add_theme_color_override("font_color", primary_color)
	offer_status_labels[offer_index].add_theme_color_override("font_color", status_color)


func _set_boon_offer_card_colors(boon_offer_index: int, disabled: bool, active: bool = false) -> void:
	var primary_color: Color = DISABLED_TEXT_COLOR if disabled else TEXT_COLOR
	var meta_color: Color = DISABLED_TEXT_COLOR if disabled else COST_COLOR
	var status_color: Color = DISABLED_TEXT_COLOR if disabled else Color(0.66, 1.0, 0.88, 1.0)
	boon_offer_name_labels[boon_offer_index].add_theme_color_override("font_color", primary_color)
	boon_offer_meta_labels[boon_offer_index].add_theme_color_override("font_color", meta_color)
	boon_offer_status_labels[boon_offer_index].add_theme_color_override("font_color", status_color)
	if boon_offer_index < 0 or boon_offer_index >= boon_offer_buttons.size():
		return
	var button: Button = boon_offer_buttons[boon_offer_index]
	if active and not disabled:
		button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.046, 0.086, 0.074, 0.96), Color(0.68, 1.0, 0.86, 0.82), 2, 8))
		button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.060, 0.110, 0.094, 0.98), Color(0.82, 1.0, 0.92, 1.0), 2, 8))
	else:
		_style_boon_card(button)


func _clear_boon_offer_cards() -> void:
	_hide_boon_tooltip()
	if boon_offer_row != null:
		for child in boon_offer_row.get_children():
			boon_offer_row.remove_child(child)
			child.queue_free()
	boon_offer_buttons.clear()
	boon_offer_name_labels.clear()
	boon_offer_meta_labels.clear()
	boon_offer_status_labels.clear()


func _get_offer(offers: Array, offer_index: int) -> Dictionary:
	if offer_index < 0 or offer_index >= offers.size():
		return {}
	var offer_value: Variant = offers[offer_index]
	if offer_value is Dictionary:
		return offer_value
	return {}


func _open_oath_choice_panel(offer_index: int) -> void:
	if table_event_system == null or oath_choice_panel == null:
		return
	_hide_boon_tooltip()
	pending_oath_replace_offer_index = offer_index
	panel.visible = false
	oath_choice_panel.visible = true
	_refresh_oath_choice_panel()
	if oath_choice_cancel_button != null:
		oath_choice_cancel_button.grab_focus()


func _close_oath_choice_panel() -> void:
	pending_oath_replace_offer_index = -1
	if oath_choice_panel != null:
		oath_choice_panel.visible = false
	if panel != null:
		panel.visible = true
	status_label.text = "Choose an omen to unleash, or claim a short-lived boon below."


func _refresh_oath_choice_panel() -> void:
	if table_event_system == null or pending_oath_replace_offer_index < 0:
		return

	var choices: Array = table_event_system.get_offer_reroll_oath_choices_snapshot(pending_oath_replace_offer_index)
	var choices_by_id: Dictionary = {}
	for choice_value in choices:
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		choices_by_id[str(choice.get("id", ""))] = choice

	for oath_id_value in OATH_CHOICE_IDS:
		var oath_id := str(oath_id_value)
		var choice: Dictionary = choices_by_id.get(oath_id, {})
		_refresh_oath_choice_row(oath_id, choice)

	if oath_choice_status_label != null:
		oath_choice_status_label.text = "Choose what price the Kraken may remember."


func _refresh_oath_choice_row(oath_id: String, choice: Dictionary) -> void:
	var button: Button = oath_choice_buttons.get(oath_id) as Button
	if button == null:
		return

	var has_choice := not choice.is_empty()
	var available := has_choice and bool(choice.get("available", false))
	var blocker := str(choice.get("blocked_reason", ""))
	button.disabled = not available
	if available:
		button.tooltip_text = "Swear %s to replace this omen." % str(choice.get("label", "an Oath"))
	else:
		button.tooltip_text = blocker if not blocker.is_empty() else "This Oath is unavailable."

	var label_color := TEXT_COLOR if available else DISABLED_TEXT_COLOR
	var status_color := STATUS_COLOR if available else DISABLED_TEXT_COLOR
	var consequence_color := COST_COLOR if available else DISABLED_TEXT_COLOR

	var name_label: Label = oath_choice_name_labels.get(oath_id) as Label
	var description_label: Label = oath_choice_description_labels.get(oath_id) as Label
	var duration_label: Label = oath_choice_duration_labels.get(oath_id) as Label
	var consequence_label: Label = oath_choice_consequence_labels.get(oath_id) as Label
	var status_line: Label = oath_choice_status_labels.get(oath_id) as Label

	if name_label != null:
		name_label.text = str(choice.get("label", oath_id)) if has_choice else oath_id
		name_label.add_theme_color_override("font_color", label_color)
	if description_label != null:
		description_label.text = str(choice.get("description", "The Kraken gives no terms."))
		description_label.add_theme_color_override("font_color", label_color)
	if duration_label != null:
		duration_label.text = str(choice.get("duration_text", "Duration: Unknown"))
		duration_label.add_theme_color_override("font_color", status_color)
	if consequence_label != null:
		consequence_label.text = str(choice.get("consequence_text", "Restriction: Unknown"))
		consequence_label.add_theme_color_override("font_color", consequence_color)
	if status_line != null:
		var status_text := "Available"
		if not available:
			var reason := blocker if not blocker.is_empty() else "blocked"
			status_text = "Unavailable: %s" % reason
		status_line.text = status_text
		status_line.add_theme_color_override("font_color", status_color)


func _on_offer_button_pressed(offer_index: int) -> void:
	if replace_press_guard_offer_index == offer_index:
		return
	event_offer_selected.emit(offer_index)


func _on_boon_offer_button_pressed(boon_offer_index: int) -> void:
	_hide_boon_tooltip()
	boon_offer_selected.emit(boon_offer_index)


func _on_boon_offer_mouse_entered(boon_offer_index: int) -> void:
	_show_boon_tooltip(boon_offer_index)


func _on_boon_offer_mouse_exited(boon_offer_index: int) -> void:
	if hovered_boon_offer_index == boon_offer_index:
		_hide_boon_tooltip()


func _show_boon_tooltip(boon_offer_index: int) -> void:
	if boon_tooltip_panel == null:
		return
	if boon_offer_index < 0 or boon_offer_index >= current_boon_offers.size():
		_hide_boon_tooltip()
		return
	var offer: Dictionary = _get_offer(current_boon_offers, boon_offer_index)
	if offer.is_empty():
		_hide_boon_tooltip()
		return

	var charge_cost: int = int(offer.get("charge_cost", offer.get("cost", 0)))
	var doubloon_cost: int = int(offer.get("doubloon_cost", 0))
	boon_tooltip_title_label.text = str(offer.get("name", "Kraken Boon"))
	boon_tooltip_details_label.text = _get_boon_offer_tooltip_details(offer, charge_cost, doubloon_cost)
	boon_tooltip_description_label.text = str(offer.get("description", ""))
	hovered_boon_offer_index = boon_offer_index
	_position_boon_tooltip(boon_offer_index)
	boon_tooltip_panel.visible = true


func _hide_boon_tooltip() -> void:
	hovered_boon_offer_index = -1
	if boon_tooltip_panel != null:
		boon_tooltip_panel.visible = false


func _position_boon_tooltip(boon_offer_index: int) -> void:
	if boon_tooltip_panel == null or boon_offer_index < 0 or boon_offer_index >= boon_offer_buttons.size():
		return
	var button: Button = boon_offer_buttons[boon_offer_index]
	var button_rect: Rect2 = button.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = BOON_TOOLTIP_SIZE
	var margin: float = BOON_TOOLTIP_VIEWPORT_MARGIN
	var tooltip_position: Vector2 = Vector2(
		button_rect.position.x,
		button_rect.position.y - tooltip_size.y - 8.0
	)
	if tooltip_position.y < margin:
		tooltip_position.y = button_rect.position.y + button_rect.size.y + 8.0
	tooltip_position.x = clampf(tooltip_position.x, margin, viewport_size.x - tooltip_size.x - margin)
	tooltip_position.y = clampf(tooltip_position.y, margin, viewport_size.y - tooltip_size.y - margin)
	boon_tooltip_panel.global_position = tooltip_position


func _on_offer_replace_button_down(offer_index: int) -> void:
	replace_press_guard_offer_index = offer_index


func _on_offer_replace_button_pressed(offer_index: int) -> void:
	_open_oath_choice_panel(offer_index)
	call_deferred("_clear_replace_press_guard")


func _clear_replace_press_guard() -> void:
	replace_press_guard_offer_index = -1


func _on_oath_choice_pressed(oath_id: String) -> void:
	if pending_oath_replace_offer_index < 0:
		return
	var offer_index := pending_oath_replace_offer_index
	_close_oath_choice_panel()
	event_offer_replace_requested.emit(offer_index, oath_id)


func _on_oath_choice_cancel_pressed() -> void:
	_close_oath_choice_panel()


func _on_offers_changed(offers: Array) -> void:
	if not visible:
		return
	_refresh_offers(offers)
	if oath_choice_panel != null and oath_choice_panel.visible:
		_refresh_oath_choice_panel()


func _on_boon_offers_changed(offers: Array) -> void:
	if not visible:
		return
	_refresh_boon_offers(offers)


func _on_status_changed(text: String) -> void:
	if status_label != null and visible:
		status_label.text = text


func _make_panel_style(fill: Color, border: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func _disconnect_table_event_system() -> void:
	if table_event_system == null:
		return
	if table_event_system.offers_changed.is_connected(_on_offers_changed):
		table_event_system.offers_changed.disconnect(_on_offers_changed)
	if table_event_system.boon_offers_changed.is_connected(_on_boon_offers_changed):
		table_event_system.boon_offers_changed.disconnect(_on_boon_offers_changed)
	if table_event_system.status_changed.is_connected(_on_status_changed):
		table_event_system.status_changed.disconnect(_on_status_changed)
