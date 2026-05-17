extends Control
class_name TableEventMenu

signal event_offer_selected(offer_index: int)
signal menu_closed

# Compact player-choice menu for pending Table Events. It owns UI only.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const OFFER_SLOT_COUNT := 3
const TABLE_CENTER := Vector2(960.0, 540.0)
const PANEL_SIZE := Vector2(860.0, 241.0)
const CARD_SIZE := Vector2(250.0, 142.0)
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
const TEXT_COLOR := Color(0.94, 0.88, 0.68, 1.0)
const COST_COLOR := Color(1.0, 0.78, 0.32, 1.0)
const DISABLED_TEXT_COLOR := Color(0.53, 0.48, 0.39, 0.82)
const STATUS_COLOR := Color(0.76, 0.88, 0.82, 0.96)

var table_event_system: TableEventSystem
var offer_buttons: Array[Button] = []
var offer_name_labels: Array[Label] = []
var offer_meta_labels: Array[Label] = []
var offer_description_labels: Array[Label] = []
var offer_status_labels: Array[Label] = []
var status_label: Label
var title_label: Label
var close_button: Button
var panel: Panel


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
	table_event_system.status_changed.connect(_on_status_changed)
	_refresh_offers(table_event_system.get_event_offers_snapshot())


func open_menu() -> void:
	if table_event_system == null or not table_event_system.is_event_icon_clickable():
		return
	visible = true
	table_event_system.set_event_menu_open(true)
	refresh_offers()
	status_label.text = "Choose one event to unleash, or close and keep the opportunity."


func close_menu() -> void:
	if table_event_system != null:
		table_event_system.set_event_menu_open(false)
	visible = false
	menu_closed.emit()


func refresh_offers() -> void:
	if table_event_system == null:
		return
	_refresh_offers(table_event_system.get_event_offers_snapshot())


func _build_menu() -> void:
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.color = Color(0.0, 0.0, 0.0, 0.06)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2.ZERO
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR, PANEL_BORDER, 2, 14))
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	title_label = Label.new()
	title_label.text = "Request Kraken Intervention..."
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.46, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	title_label.add_theme_constant_override("outline_size", 3)
	header.add_child(title_label)

	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(76.0, 30.0)
	close_button.add_theme_font_override("font", UI_FONT)
	close_button.add_theme_font_size_override("font_size", 14)
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)

	status_label = Label.new()
	status_label.text = "Spend Doubloons to unleash one table event, or close and keep the choice."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_override("font", UI_FONT)
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", STATUS_COLOR)
	status_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.86))
	status_label.add_theme_constant_override("outline_size", 1)
	root.add_child(status_label)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.custom_minimum_size = Vector2(0.0, CARD_SIZE.y)
	cards.add_theme_constant_override("separation", CARD_GAP)
	root.add_child(cards)
	for offer_index in range(OFFER_SLOT_COUNT):
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = CARD_SIZE
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		button.add_theme_stylebox_override("normal", _make_panel_style(CARD_COLOR, CARD_BORDER, 1, 10))
		button.add_theme_stylebox_override("hover", _make_panel_style(CARD_COLOR.lightened(0.08), CARD_HOVER_BORDER, 2, 10))
		button.add_theme_stylebox_override("pressed", _make_panel_style(CARD_PRESSED_COLOR, CARD_HOVER_BORDER, 2, 10))
		button.add_theme_stylebox_override("disabled", _make_panel_style(CARD_DISABLED_COLOR, CARD_BORDER.darkened(0.25), 1, 10))
		button.pressed.connect(_on_offer_button_pressed.bind(offer_index))
		_add_offer_card_content(button)
		offer_buttons.append(button)
		cards.add_child(button)


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


func _refresh_offers(offers: Array) -> void:
	for offer_index in range(OFFER_SLOT_COUNT):
		var button: Button = offer_buttons[offer_index]
		var offer: Dictionary = _get_offer(offers, offer_index)
		button.disabled = not bool(offer.get("available", false))
		_refresh_offer_card_content(offer_index, offer, button.disabled)


func _refresh_offer_card_content(offer_index: int, offer: Dictionary, disabled: bool) -> void:
	if offer.is_empty():
		offer_name_labels[offer_index].text = "Unknown Event"
		offer_meta_labels[offer_index].text = ""
		offer_description_labels[offer_index].text = "The deep says nothing."
		offer_status_labels[offer_index].text = "Unavailable"
		_set_offer_card_colors(offer_index, true)
		return

	var cost: int = int(offer.get("cost", 0))
	var cost_text: String = "Cost: %s Doubloons" % cost if cost > 0 else str(offer.get("blocked_reason", "Unavailable"))
	var rarity: String = str(offer.get("rarity", ""))
	var rarity_text: String = "%s Omen" % rarity if not rarity.is_empty() else ""
	var cost_line: String = cost_text
	if not rarity_text.is_empty():
		cost_line = "%s  |  %s" % [cost_text, rarity_text]
	var blocker: String = str(offer.get("blocked_reason", ""))
	var availability_text: String = "Ready to unleash"
	if not blocker.is_empty():
		availability_text = blocker

	offer_name_labels[offer_index].text = str(offer.get("name", "Table Event"))
	offer_meta_labels[offer_index].text = cost_line
	offer_description_labels[offer_index].text = str(offer.get("description", ""))
	offer_status_labels[offer_index].text = availability_text
	_set_offer_card_colors(offer_index, disabled)


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
	status_line.custom_minimum_size = Vector2(0.0, 19.0)
	stack.add_child(status_line)
	offer_status_labels.append(status_line)


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


func _set_offer_card_colors(offer_index: int, disabled: bool) -> void:
	var primary_color: Color = DISABLED_TEXT_COLOR if disabled else TEXT_COLOR
	var meta_color: Color = DISABLED_TEXT_COLOR if disabled else COST_COLOR
	var status_color: Color = DISABLED_TEXT_COLOR if disabled else STATUS_COLOR
	offer_name_labels[offer_index].add_theme_color_override("font_color", primary_color)
	offer_meta_labels[offer_index].add_theme_color_override("font_color", meta_color)
	offer_description_labels[offer_index].add_theme_color_override("font_color", primary_color)
	offer_status_labels[offer_index].add_theme_color_override("font_color", status_color)


func _get_offer(offers: Array, offer_index: int) -> Dictionary:
	if offer_index < 0 or offer_index >= offers.size():
		return {}
	var offer_value: Variant = offers[offer_index]
	if offer_value is Dictionary:
		return offer_value
	return {}


func _on_offer_button_pressed(offer_index: int) -> void:
	event_offer_selected.emit(offer_index)


func _on_offers_changed(offers: Array) -> void:
	if not visible:
		return
	_refresh_offers(offers)


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
	if table_event_system.status_changed.is_connected(_on_status_changed):
		table_event_system.status_changed.disconnect(_on_status_changed)
