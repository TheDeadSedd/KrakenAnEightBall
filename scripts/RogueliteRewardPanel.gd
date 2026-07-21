extends Control
class_name RogueliteRewardPanel

# Presentation-only Mark Your Course modal. Reward/build systems own offer
# generation, eligibility, acquisition, replacement, and progression.

signal reward_selected(reward_id: String)
signal replacement_selected(item_id: String, tray_slot_index: int)
signal replacement_canceled
signal keep_current_course_requested

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const PANEL_SIZE := Vector2(1080.0, 650.0)
const VIEWPORT_MARGIN := 24.0
const PANEL_Z_INDEX := 77
const SHADE_COLOR := Color(0.01, 0.012, 0.016, 0.56)
const CARD_GAP := 18
const REPLACEMENT_GAP := 10
const TOOLTIP_SIZE := Vector2(390.0, 270.0)

const TITLE_COLOR := Color(1.0, 0.88, 0.48, 1.0)
const NAME_COLOR := Color(0.94, 0.90, 0.76, 1.0)
const BODY_COLOR := Color(0.84, 0.91, 0.82, 0.96)
const MUTED_COLOR := Color(0.66, 0.66, 0.59, 0.90)
const SHADOW_COLOR := Color(0.02, 0.012, 0.010, 0.92)
const LEGENDARY_COLOR := Color(1.0, 0.76, 0.28, 1.0)
const LEGENDARY_PURPLE := Color(0.58, 0.27, 0.74, 1.0)
const WARNING_COLOR := Color(1.0, 0.61, 0.31, 1.0)

var latest_snapshot: Dictionary = {}
var offer_snapshots: Array[Dictionary] = []
var tray_slot_snapshots: Array[Dictionary] = []
var selected_offer: Dictionary = {}
var hover_ui_suppressed: bool = false
var hovered_control: Control
var hovered_item: Dictionary = {}
var hovered_slot_index: int = -1

var shade: ColorRect
var panel: Panel
var panel_margin: MarginContainer
var root_stack: VBoxContainer
var title_label: Label
var subtitle_label: Label
var offer_view: VBoxContainer
var card_row: HBoxContainer
var offer_footer: HBoxContainer
var skip_button: Button
var replacement_view: VBoxContainer
var replacement_intro_label: Label
var replacement_warning_label: Label
var selected_item_holder: CenterContainer
var replacement_row: HBoxContainer
var cancel_button: Button
var first_card_button: Button
var offer_card_buttons: Array[Button] = []
var replacement_buttons: Array[Button] = []

var tooltip_panel: PanelContainer
var tooltip_title_label: Label
var tooltip_meta_label: Label
var tooltip_effect_label: Label
var tooltip_body_label: Label
var tooltip_status_label: Label


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


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if is_showing_replacement():
		_cancel_replacement()
		get_viewport().set_input_as_handled()


func open_panel(reward_snapshot: Dictionary, build_snapshot: Dictionary = {}) -> void:
	latest_snapshot = reward_snapshot.duplicate(true)
	if not build_snapshot.is_empty():
		latest_snapshot["build_snapshot"] = build_snapshot.duplicate(true)
	offer_snapshots = _extract_offer_snapshots(latest_snapshot)
	tray_slot_snapshots = _extract_tray_slots(latest_snapshot)
	selected_offer.clear()
	_rebuild_offer_cards()
	_rebuild_replacement_slots()
	show_offer_view()
	visible = true
	_center_panel()
	if first_card_button != null:
		first_card_button.grab_focus()


func set_reward_snapshot(reward_snapshot: Dictionary, build_snapshot: Dictionary = {}) -> void:
	var was_visible: bool = visible
	open_panel(reward_snapshot, build_snapshot)
	visible = was_visible


func close_panel() -> void:
	_hide_tooltip()
	_release_all_focus()
	hovered_control = null
	hovered_item.clear()
	hovered_slot_index = -1
	selected_offer.clear()
	visible = false


func set_hover_ui_suppressed(suppressed: bool) -> void:
	hover_ui_suppressed = suppressed
	if suppressed:
		_hide_tooltip()


func show_offer_view() -> void:
	selected_offer.clear()
	if offer_view != null:
		offer_view.visible = true
	if replacement_view != null:
		replacement_view.visible = false
	if title_label != null:
		title_label.text = "Mark Your Course"
	if subtitle_label != null:
		subtitle_label.text = "Choose an Eight Ball for your scoring engine."
	_clear_replacement_warning()
	_hide_tooltip()
	if visible and first_card_button != null:
		first_card_button.grab_focus()


func show_replacement_view(offer: Dictionary) -> void:
	if offer.is_empty() or not _is_eight_ball_offer(offer):
		return
	selected_offer = offer.duplicate(true)
	_rebuild_selected_item_summary()
	_rebuild_replacement_slots()
	if offer_view != null:
		offer_view.visible = false
	if replacement_view != null:
		replacement_view.visible = true
	if title_label != null:
		title_label.text = "CAST ONE OVERBOARD"
	if subtitle_label != null:
		subtitle_label.text = "Choose which current Eight Ball yields its tray slot."
	_clear_replacement_warning()
	_hide_tooltip()
	for button in replacement_buttons:
		if not button.disabled:
			button.grab_focus()
			break


func open_replacement_view(item_snapshot: Dictionary, build_snapshot: Dictionary = {}) -> void:
	if not build_snapshot.is_empty():
		var merged_snapshot: Dictionary = latest_snapshot.duplicate(true)
		merged_snapshot["build_snapshot"] = build_snapshot.duplicate(true)
		latest_snapshot = merged_snapshot
		tray_slot_snapshots = _extract_tray_slots(latest_snapshot)
	show_replacement_view(item_snapshot)


func is_showing_replacement() -> bool:
	return replacement_view != null and replacement_view.visible


func get_selected_item_id() -> String:
	return _get_offer_id(selected_offer)


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
	panel_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_margin.add_theme_constant_override("margin_left", 30)
	panel_margin.add_theme_constant_override("margin_top", 22)
	panel_margin.add_theme_constant_override("margin_right", 30)
	panel_margin.add_theme_constant_override("margin_bottom", 24)
	_set_full_rect(panel_margin)
	panel.add_child(panel_margin)

	root_stack = VBoxContainer.new()
	root_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_stack.add_theme_constant_override("separation", 8)
	panel_margin.add_child(root_stack)

	title_label = _make_label(34, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.custom_minimum_size = Vector2(0.0, 40.0)
	root_stack.add_child(title_label)

	subtitle_label = _make_label(16, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label.custom_minimum_size = Vector2(0.0, 24.0)
	root_stack.add_child(subtitle_label)

	_build_offer_view()
	_build_replacement_view()
	_build_tooltip()
	_center_panel()


func _build_offer_view() -> void:
	offer_view = VBoxContainer.new()
	offer_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offer_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	offer_view.add_theme_constant_override("separation", 12)
	root_stack.add_child(offer_view)

	card_row = HBoxContainer.new()
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_row.add_theme_constant_override("separation", CARD_GAP)
	offer_view.add_child(card_row)

	offer_footer = HBoxContainer.new()
	offer_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	offer_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	offer_footer.custom_minimum_size = Vector2(0.0, 44.0)
	offer_view.add_child(offer_footer)

	skip_button = Button.new()
	skip_button.name = "KeepCurrentCourseButton"
	skip_button.text = "KEEP CURRENT COURSE"
	skip_button.custom_minimum_size = Vector2(250.0, 36.0)
	_configure_action_button(skip_button, false)
	skip_button.pressed.connect(_on_skip_pressed)
	offer_footer.add_child(skip_button)


func _build_replacement_view() -> void:
	replacement_view = VBoxContainer.new()
	replacement_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replacement_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replacement_view.add_theme_constant_override("separation", 10)
	replacement_view.visible = false
	root_stack.add_child(replacement_view)

	replacement_intro_label = _make_label(15, BODY_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	replacement_intro_label.text = "The new Eight Ball inherits the selected slot. Other slots remain unchanged."
	replacement_intro_label.custom_minimum_size = Vector2(0.0, 22.0)
	replacement_view.add_child(replacement_intro_label)

	replacement_warning_label = _make_label(13, WARNING_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	replacement_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	replacement_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	replacement_warning_label.custom_minimum_size = Vector2(0.0, 40.0)
	replacement_warning_label.visible = false
	replacement_view.add_child(replacement_warning_label)

	selected_item_holder = CenterContainer.new()
	selected_item_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_item_holder.custom_minimum_size = Vector2(0.0, 94.0)
	replacement_view.add_child(selected_item_holder)

	replacement_row = HBoxContainer.new()
	replacement_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replacement_row.alignment = BoxContainer.ALIGNMENT_CENTER
	replacement_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replacement_row.add_theme_constant_override("separation", REPLACEMENT_GAP)
	replacement_view.add_child(replacement_row)

	var cancel_row: HBoxContainer = HBoxContainer.new()
	cancel_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cancel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cancel_row.custom_minimum_size = Vector2(0.0, 42.0)
	replacement_view.add_child(cancel_row)

	cancel_button = Button.new()
	cancel_button.name = "CancelReplacementButton"
	cancel_button.text = "Cancel"
	cancel_button.custom_minimum_size = Vector2(180.0, 34.0)
	_configure_action_button(cancel_button, true)
	cancel_button.pressed.connect(_cancel_replacement)
	cancel_row.add_child(cancel_button)


func _build_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "EightBallRewardTooltip"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 12
	tooltip_panel.custom_minimum_size = TOOLTIP_SIZE
	tooltip_panel.size = TOOLTIP_SIZE
	tooltip_panel.add_theme_stylebox_override("panel", _make_tooltip_style())
	add_child(tooltip_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 12)
	tooltip_panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	tooltip_title_label = _make_label(19, TITLE_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	tooltip_meta_label = _make_label(13, Color(0.75, 0.91, 0.84, 0.98), HORIZONTAL_ALIGNMENT_LEFT)
	tooltip_effect_label = _make_label(15, Color(0.95, 0.80, 0.43, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	tooltip_body_label = _make_label(14, Color(0.86, 0.83, 0.72, 0.96), HORIZONTAL_ALIGNMENT_LEFT)
	tooltip_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tooltip_status_label = _make_label(13, Color(0.64, 0.87, 0.82, 0.96), HORIZONTAL_ALIGNMENT_LEFT)
	stack.add_child(tooltip_title_label)
	stack.add_child(tooltip_meta_label)
	stack.add_child(tooltip_effect_label)
	stack.add_child(tooltip_body_label)
	stack.add_child(tooltip_status_label)


func _rebuild_offer_cards() -> void:
	_clear_container(card_row)
	offer_card_buttons.clear()
	first_card_button = null
	var displayed_offer_count: int = mini(offer_snapshots.size(), 3)
	for offer_index in range(displayed_offer_count):
		var offer: Dictionary = offer_snapshots[offer_index]
		var card: Button = _make_offer_card(offer)
		card_row.add_child(card)
		offer_card_buttons.append(card)
		if first_card_button == null:
			first_card_button = card
	var allow_skip: bool = bool(latest_snapshot.get("allow_skip", true))
	if skip_button != null:
		skip_button.visible = allow_skip


func _make_offer_card(offer: Dictionary) -> Button:
	var offer_id: String = _get_offer_id(offer)
	var rarity: String = _format_rarity(str(offer.get("rarity", "common")))
	var card: Button = Button.new()
	card.name = "RewardCard_%s" % offer_id
	card.text = ""
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(220.0, 300.0)
	card.add_theme_stylebox_override("normal", _make_card_style("normal", rarity))
	card.add_theme_stylebox_override("hover", _make_card_style("hover", rarity))
	card.add_theme_stylebox_override("pressed", _make_card_style("pressed", rarity))
	card.add_theme_stylebox_override("focus", _make_card_style("focus", rarity))
	card.pressed.connect(_on_offer_pressed.bind(offer.duplicate(true)))
	card.mouse_entered.connect(_on_item_hover_started.bind(card, offer.duplicate(true), -1))
	card.mouse_exited.connect(_on_item_hover_ended.bind(card))

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 14)
	_set_full_rect(margin)
	card.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	var icon_holder: CenterContainer = CenterContainer.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.custom_minimum_size = Vector2(0.0, 68.0)
	icon_holder.add_child(_make_eight_ball_icon(58.0, rarity))
	stack.add_child(icon_holder)

	var name_label: Label = _make_label(21, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text = str(offer.get("display_name", "Reward"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0.0, 48.0)
	stack.add_child(name_label)

	var rarity_label: Label = _make_label(15 if rarity.to_lower() == "legendary" else 13, _get_rarity_color(rarity), HORIZONTAL_ALIGNMENT_CENTER)
	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_constant_override("outline_size", 3 if rarity.to_lower() == "legendary" else 2)
	stack.add_child(rarity_label)
	var family_label: Label = _make_label(14, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	family_label.text = _format_family_name(str(offer.get("family_id", offer.get("trigger_id", ""))))
	stack.add_child(family_label)

	var effect_label: Label = _make_label(16, BODY_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	effect_label.text = _get_short_effect(offer)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(effect_label)

	var choose_label: Label = _make_label(14, Color(0.98, 0.78, 0.36, 0.96), HORIZONTAL_ALIGNMENT_CENTER)
	choose_label.text = "Choose"
	choose_label.custom_minimum_size = Vector2(0.0, 22.0)
	stack.add_child(choose_label)
	return card


func _rebuild_selected_item_summary() -> void:
	_clear_container(selected_item_holder)
	if selected_offer.is_empty():
		return
	var summary: PanelContainer = PanelContainer.new()
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.custom_minimum_size = Vector2(500.0, 82.0)
	summary.add_theme_stylebox_override("panel", _make_summary_style(str(selected_offer.get("rarity", "common"))))
	selected_item_holder.add_child(summary)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 8)
	summary.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	row.add_child(_make_eight_ball_icon(54.0, _format_rarity(str(selected_offer.get("rarity", "common")))))

	var text_stack: VBoxContainer = VBoxContainer.new()
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_stack)
	var name_label: Label = _make_label(19, TITLE_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.text = "NEW: %s" % str(selected_offer.get("display_name", "Eight Ball"))
	text_stack.add_child(name_label)
	var effect_label: Label = _make_label(15, BODY_COLOR, HORIZONTAL_ALIGNMENT_LEFT)
	effect_label.text = _get_short_effect(selected_offer)
	text_stack.add_child(effect_label)


func _rebuild_replacement_slots() -> void:
	_clear_container(replacement_row)
	replacement_buttons.clear()
	for slot_index in range(5):
		var slot: Dictionary = tray_slot_snapshots[slot_index] if slot_index < tray_slot_snapshots.size() else _make_empty_slot_snapshot(slot_index)
		var button: Button = _make_replacement_slot_button(slot, slot_index)
		replacement_row.add_child(button)
		replacement_buttons.append(button)


func _make_replacement_slot_button(slot: Dictionary, slot_index: int) -> Button:
	var item_id: String = _get_offer_id(slot)
	var occupied: bool = not item_id.is_empty()
	var rarity: String = _format_rarity(str(slot.get("rarity", "common")))
	var button: Button = Button.new()
	button.name = "ReplacementSlot%d" % (slot_index + 1)
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(150.0, 210.0)
	button.disabled = not occupied
	button.add_theme_stylebox_override("normal", _make_card_style("normal", rarity))
	button.add_theme_stylebox_override("hover", _make_card_style("hover", rarity))
	button.add_theme_stylebox_override("pressed", _make_card_style("pressed", rarity))
	button.add_theme_stylebox_override("focus", _make_card_style("focus", rarity))
	button.add_theme_stylebox_override("disabled", _make_card_style("disabled", rarity))
	button.pressed.connect(_on_replacement_slot_pressed.bind(slot_index))
	if occupied:
		button.mouse_entered.connect(_on_item_hover_started.bind(button, slot.duplicate(true), slot_index))
		button.mouse_exited.connect(_on_item_hover_ended.bind(button))

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 10)
	_set_full_rect(margin)
	button.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var slot_label: Label = _make_label(12, MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	slot_label.text = "SLOT %d" % (slot_index + 1)
	stack.add_child(slot_label)
	var icon_holder: CenterContainer = CenterContainer.new()
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.custom_minimum_size = Vector2(0.0, 52.0)
	icon_holder.add_child(_make_eight_ball_icon(46.0, rarity) if occupied else _make_empty_slot_mark())
	stack.add_child(icon_holder)
	var name_label: Label = _make_label(15, NAME_COLOR if occupied else MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text = str(slot.get("display_name", "Empty Slot"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0.0, 42.0)
	stack.add_child(name_label)
	var effect_label: Label = _make_label(12, BODY_COLOR if occupied else MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	effect_label.text = _get_short_effect(slot) if occupied else "No Eight Ball"
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(effect_label)
	var replacement_warning: String = _get_replacement_warning(slot, slot_index)
	if occupied and not replacement_warning.is_empty():
		var warning_badge: Label = _make_label(11, WARNING_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
		warning_badge.text = "WARNING"
		warning_badge.custom_minimum_size = Vector2(0.0, 18.0)
		stack.add_child(warning_badge)
		button.focus_entered.connect(_show_replacement_warning.bind(slot.duplicate(true), slot_index))
		button.focus_exited.connect(_clear_replacement_warning)
	return button


func _on_offer_pressed(offer: Dictionary) -> void:
	var offer_id: String = _get_offer_id(offer)
	if offer_id.is_empty():
		return
	reward_selected.emit(offer_id)


func _on_replacement_slot_pressed(slot_index: int) -> void:
	var item_id: String = _get_offer_id(selected_offer)
	if item_id.is_empty() or slot_index < 0 or slot_index >= tray_slot_snapshots.size():
		return
	if _get_offer_id(tray_slot_snapshots[slot_index]).is_empty():
		return
	replacement_selected.emit(item_id, slot_index)


func _cancel_replacement() -> void:
	if not is_showing_replacement():
		return
	replacement_canceled.emit()
	show_offer_view()


func _on_skip_pressed() -> void:
	keep_current_course_requested.emit()


func _on_item_hover_started(control: Control, item: Dictionary, slot_index: int) -> void:
	if hover_ui_suppressed:
		return
	hovered_control = control
	hovered_item = item.duplicate(true)
	hovered_slot_index = slot_index
	_update_tooltip_content()
	_position_tooltip(control)
	tooltip_panel.visible = true
	if slot_index >= 0:
		_show_replacement_warning(item, slot_index)


func _on_item_hover_ended(control: Control) -> void:
	if hovered_control != control:
		return
	hovered_control = null
	hovered_item.clear()
	hovered_slot_index = -1
	_hide_tooltip()
	_clear_replacement_warning()


func _update_tooltip_content() -> void:
	if hovered_item.is_empty():
		return
	var rarity: String = _format_rarity(str(hovered_item.get("rarity", "common")))
	tooltip_title_label.text = str(hovered_item.get("display_name", "Reward")).to_upper()
	tooltip_meta_label.text = "%s  |  %s" % [
		rarity,
		_format_family_name(str(hovered_item.get("family_id", hovered_item.get("trigger_id", "Reward")))),
	]
	tooltip_panel.add_theme_stylebox_override("panel", _make_tooltip_style(rarity))
	tooltip_effect_label.text = _get_short_effect(hovered_item)
	tooltip_body_label.text = str(hovered_item.get("tooltip", hovered_item.get("description", _get_short_effect(hovered_item))))
	if hovered_slot_index >= 0:
		var replacement_warning: String = _get_replacement_warning(hovered_item, hovered_slot_index)
		tooltip_status_label.text = "Current tray slot %d\nChoose to replace this Eight Ball." % (hovered_slot_index + 1)
		if not replacement_warning.is_empty():
			tooltip_status_label.text += "\nWARNING: %s" % replacement_warning
	elif _requires_replacement():
		tooltip_status_label.text = "Tray full. Choosing this opens replacement."
	else:
		tooltip_status_label.text = "Choose to mark this course."


func _position_tooltip(source: Control) -> void:
	if tooltip_panel == null or source == null:
		return
	var source_rect: Rect2 = source.get_global_rect()
	var viewport_size: Vector2 = get_viewport_rect().size
	var desired_global: Vector2 = Vector2(source_rect.end.x + 10.0, source_rect.position.y)
	if desired_global.x + TOOLTIP_SIZE.x > viewport_size.x - VIEWPORT_MARGIN:
		desired_global.x = source_rect.position.x - TOOLTIP_SIZE.x - 10.0
	desired_global.x = clampf(desired_global.x, VIEWPORT_MARGIN, maxf(viewport_size.x - TOOLTIP_SIZE.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN))
	desired_global.y = clampf(desired_global.y, VIEWPORT_MARGIN, maxf(viewport_size.y - TOOLTIP_SIZE.y - VIEWPORT_MARGIN, VIEWPORT_MARGIN))
	tooltip_panel.position = desired_global - global_position


func _hide_tooltip() -> void:
	if tooltip_panel != null:
		tooltip_panel.visible = false


func _show_replacement_warning(item: Dictionary, slot_index: int) -> void:
	if replacement_warning_label == null or not is_showing_replacement():
		return
	var warning: String = _get_replacement_warning(item, slot_index)
	replacement_warning_label.text = "WARNING: %s" % warning if not warning.is_empty() else ""
	replacement_warning_label.visible = not warning.is_empty()


func _clear_replacement_warning() -> void:
	if replacement_warning_label == null:
		return
	replacement_warning_label.text = ""
	replacement_warning_label.visible = false


func _get_replacement_warning(item: Dictionary, slot_index: int) -> String:
	for key in ["replacement_warning", "replacement_warning_text", "warning_text"]:
		var direct_warning: String = str(item.get(key, "")).strip_edges()
		if not direct_warning.is_empty():
			return direct_warning

	var item_id: String = _get_offer_id(item)
	var warning_containers: Array[Dictionary] = [latest_snapshot, selected_offer]
	var build_snapshot_value: Variant = latest_snapshot.get("build_snapshot", null)
	if build_snapshot_value is Dictionary:
		warning_containers.append(build_snapshot_value as Dictionary)
	for container in warning_containers:
		for map_key in [
			"replacement_warnings_by_slot",
			"replacement_warnings",
			"replacement_warning_by_slot",
			"warnings_by_slot",
		]:
			var warnings_value: Variant = container.get(map_key, null)
			var mapped_warning: String = _replacement_warning_from_collection(
				warnings_value,
				slot_index,
				item_id
			)
			if not mapped_warning.is_empty():
				return mapped_warning
		var preview_value: Variant = container.get("replacement_preview", null)
		if preview_value is Dictionary:
			var preview: Dictionary = preview_value
			for preview_map_key in ["replacement_warnings", "warnings_by_slot"]:
				var preview_warning: String = _replacement_warning_from_collection(
					preview.get(preview_map_key, null),
					slot_index,
					item_id
				)
				if not preview_warning.is_empty():
					return preview_warning
	return ""


func _replacement_warning_from_collection(
	collection: Variant,
	slot_index: int,
	item_id: String
) -> String:
	var warning_value: Variant = null
	if collection is Dictionary:
		var warning_map: Dictionary = collection
		warning_value = warning_map.get(
			slot_index,
			warning_map.get(str(slot_index), warning_map.get(item_id, null))
		)
	elif collection is Array and slot_index >= 0 and slot_index < (collection as Array).size():
		warning_value = (collection as Array)[slot_index]
	if warning_value is Dictionary:
		var warning: Dictionary = warning_value
		return str(warning.get("message", warning.get("warning", warning.get("text", "")))).strip_edges()
	return str(warning_value).strip_edges() if warning_value != null else ""


func _extract_offer_snapshots(snapshot: Dictionary) -> Array[Dictionary]:
	var offers_value: Variant = snapshot.get("eight_ball_offers", snapshot.get("offers", []))
	var offers: Array[Dictionary] = []
	if not offers_value is Array:
		return offers
	for offer_value in offers_value:
		if offer_value is Dictionary:
			var offer: Dictionary = (offer_value as Dictionary).duplicate(true)
			if not _get_offer_id(offer).is_empty() and _is_eight_ball_offer(offer):
				offers.append(offer)
	return offers


func _extract_tray_slots(snapshot: Dictionary) -> Array[Dictionary]:
	var slots_value: Variant = snapshot.get("tray_slots", snapshot.get("build_slots", snapshot.get("slots", [])))
	if not slots_value is Array or (slots_value as Array).is_empty():
		var build_value: Variant = snapshot.get("build_snapshot", {})
		if build_value is Dictionary:
			var build: Dictionary = build_value
			slots_value = build.get("tray_slots", build.get("slots", []))
	var source: Array = slots_value if slots_value is Array else []
	var result: Array[Dictionary] = []
	for slot_index in range(5):
		var slot: Dictionary = _make_empty_slot_snapshot(slot_index)
		if slot_index < source.size() and source[slot_index] is Dictionary:
			var raw_slot: Dictionary = (source[slot_index] as Dictionary).duplicate(true)
			var item_value: Variant = raw_slot.get("item", raw_slot.get("definition", {}))
			var item: Dictionary = (item_value as Dictionary).duplicate(true) if item_value is Dictionary else raw_slot
			if not _get_offer_id(item).is_empty():
				slot = raw_slot.duplicate(true)
				slot.merge(item, true)
				slot["slot_index"] = slot_index
		result.append(slot)
	return result


func _make_empty_slot_snapshot(slot_index: int) -> Dictionary:
	return {
		"slot_index": slot_index,
		"display_name": "Empty Slot",
	}


func _is_eight_ball_offer(offer: Dictionary) -> bool:
	if not str(offer.get("eight_ball_item_id", offer.get("build_item_id", ""))).is_empty():
		return true
	var offer_type: String = str(offer.get("offer_type", offer.get("reward_type", offer.get("item_type", ""))))
	if offer_type in ["eight_ball", "eight_ball_item", "build_item"]:
		return true
	return offer.has("trigger_id") and offer.has("modifier_phase")


func _requires_replacement() -> bool:
	if bool(latest_snapshot.get("requires_replacement", latest_snapshot.get("tray_full", latest_snapshot.get("build_tray_full", false)))):
		return true
	if tray_slot_snapshots.size() < 5:
		return false
	for slot in tray_slot_snapshots:
		if _get_offer_id(slot).is_empty():
			return false
	return true


func _get_offer_id(offer: Dictionary) -> String:
	return str(offer.get("eight_ball_item_id", offer.get("build_item_id", offer.get("item_id", offer.get("id", "")))))


func _get_short_effect(offer: Dictionary) -> String:
	return str(offer.get("short_effect", offer.get("effect", offer.get("description", ""))))


func _format_family_name(family_id: String) -> String:
	match family_id:
		"single_bank", "single_bank_milestone":
			return "Single Bank"
		"double_bank", "double_bank_milestone":
			return "Double Bank"
		"triple_bank", "triple_bank_milestone":
			return "Triple Bank"
		"combination", "combination_pot":
			return "Combination"
		"direct_pot":
			return "Direct Pot"
		"multi_pot", "multi_pot_shot":
			return "Multi-Pot"
		"same_pocket", "same_pocket_streak":
			return "Same Pocket"
		_:
			return family_id.replace("_", " ").capitalize() if not family_id.is_empty() else "Scoring Engine"


func _format_rarity(rarity: String) -> String:
	var normalized: String = rarity.strip_edges().to_lower()
	return normalized.capitalize() if not normalized.is_empty() else "Common"


func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"legendary":
			return LEGENDARY_COLOR
		"rare":
			return Color(0.43, 0.94, 0.87, 1.0)
		"uncommon":
			return Color(0.98, 0.72, 0.30, 1.0)
		_:
			return Color(0.84, 0.82, 0.72, 1.0)


func _make_eight_ball_icon(diameter: float, rarity: String = "Common") -> Control:
	var icon: Control = Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(diameter, diameter)
	icon.size = Vector2(diameter, diameter)

	var is_legendary: bool = rarity.to_lower() == "legendary"
	var outer: Panel = Panel.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.position = Vector2.ZERO
	outer.size = Vector2(diameter, diameter)
	var outer_style: StyleBoxFlat = _make_circle_style(
		Color(0.055, 0.012, 0.075, 1.0) if is_legendary else Color(0.006, 0.007, 0.010, 1.0),
		LEGENDARY_COLOR if is_legendary else Color(0.72, 0.62, 0.42, 0.70),
		diameter * 0.5
	)
	if is_legendary:
		outer_style.border_width_left = 3
		outer_style.border_width_top = 3
		outer_style.border_width_right = 3
		outer_style.border_width_bottom = 3
		outer_style.shadow_color = Color(LEGENDARY_PURPLE.r, LEGENDARY_PURPLE.g, LEGENDARY_PURPLE.b, 0.58)
		outer_style.shadow_size = 7
	outer.add_theme_stylebox_override("panel", outer_style)
	icon.add_child(outer)

	var inset_size: float = diameter * 0.38
	var inset: Panel = Panel.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.position = Vector2((diameter - inset_size) * 0.5, (diameter - inset_size) * 0.5)
	inset.size = Vector2(inset_size, inset_size)
	inset.add_theme_stylebox_override("panel", _make_circle_style(Color(0.94, 0.92, 0.83, 1.0), Color(0.18, 0.15, 0.12, 0.50), inset_size * 0.5))
	icon.add_child(inset)

	var number: Label = _make_label(maxi(int(diameter * 0.24), 11), Color(0.02, 0.02, 0.025, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	number.text = "8"
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.position = inset.position
	number.size = inset.size
	icon.add_child(number)
	return icon


func _make_empty_slot_mark() -> Control:
	var mark: Control = Control.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.custom_minimum_size = Vector2(46.0, 46.0)
	var ring: Panel = Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = Vector2(4.0, 4.0)
	ring.size = Vector2(38.0, 38.0)
	ring.add_theme_stylebox_override("panel", _make_circle_style(Color(0.03, 0.03, 0.035, 0.45), Color(0.48, 0.46, 0.48, 0.36), 19.0))
	mark.add_child(ring)
	return mark


func _configure_action_button(button: Button, quiet: bool) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", BODY_COLOR if quiet else TITLE_COLOR)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.72, 1.0))
	button.add_theme_stylebox_override("normal", _make_action_style("normal", quiet))
	button.add_theme_stylebox_override("hover", _make_action_style("hover", quiet))
	button.add_theme_stylebox_override("pressed", _make_action_style("pressed", quiet))
	button.add_theme_stylebox_override("focus", _make_action_style("focus", quiet))


func _make_label(font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", SHADOW_COLOR)
	label.add_theme_constant_override("outline_size", 2)
	return label


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
	var panel_size: Vector2 = Vector2(minf(PANEL_SIZE.x, available_size.x), minf(PANEL_SIZE.y, available_size.y))
	var panel_position: Vector2 = (viewport_size - panel_size) * 0.5
	panel_position.x = clampf(panel_position.x, VIEWPORT_MARGIN, maxf(viewport_size.x - panel_size.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN))
	panel_position.y = clampf(panel_position.y, VIEWPORT_MARGIN, maxf(viewport_size.y - panel_size.y - VIEWPORT_MARGIN, VIEWPORT_MARGIN))
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	panel.position = panel_position
	if panel_margin != null:
		_set_full_rect(panel_margin)
	if hovered_control != null and tooltip_panel != null and tooltip_panel.visible:
		_position_tooltip(hovered_control)


func _clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _release_all_focus() -> void:
	for button in offer_card_buttons:
		button.release_focus()
	for button in replacement_buttons:
		button.release_focus()
	if skip_button != null:
		skip_button.release_focus()
	if cancel_button != null:
		cancel_button.release_focus()


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.018, 0.026, 0.94)
	style.border_color = Color(0.92, 0.72, 0.32, 0.72)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0.0, 8.0)
	return style


func _make_card_style(state: String, rarity: String) -> StyleBoxFlat:
	var accent: Color = _get_rarity_color(rarity)
	var is_legendary: bool = rarity.to_lower() == "legendary"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = Color(0.13, 0.087, 0.043, 0.98)
			style.border_color = accent.lightened(0.16)
		"pressed":
			style.bg_color = Color(0.20, 0.14, 0.064, 0.98)
			style.border_color = Color(1.0, 0.92, 0.64, 1.0)
		"focus":
			style.bg_color = Color(0.085, 0.064, 0.046, 0.98)
			style.border_color = Color(0.64, 0.95, 0.88, 0.88)
		"disabled":
			style.bg_color = Color(0.027, 0.025, 0.029, 0.62)
			style.border_color = Color(0.38, 0.36, 0.36, 0.28)
		_:
			style.bg_color = Color(0.035, 0.029, 0.030, 0.92)
			style.border_color = Color(accent.r, accent.g, accent.b, 0.58)
	if is_legendary and state != "disabled":
		match state:
			"hover":
				style.bg_color = Color(0.16, 0.055, 0.19, 0.98)
				style.border_color = LEGENDARY_COLOR.lightened(0.14)
			"pressed":
				style.bg_color = Color(0.21, 0.075, 0.20, 0.98)
				style.border_color = Color(1.0, 0.91, 0.58, 1.0)
			"focus":
				style.bg_color = Color(0.11, 0.043, 0.15, 0.98)
				style.border_color = Color(0.91, 0.66, 1.0, 0.96)
			_:
				style.bg_color = Color(0.075, 0.030, 0.095, 0.96)
				style.border_color = Color(LEGENDARY_COLOR.r, LEGENDARY_COLOR.g, LEGENDARY_COLOR.b, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_summary_style(rarity: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_card_style("normal", rarity)
	style.bg_color = Color(0.045, 0.055, 0.052, 0.92)
	return style


func _make_tooltip_style(rarity: String = "common") -> StyleBoxFlat:
	var is_legendary: bool = rarity.to_lower() == "legendary"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.021, 0.068, 0.97) if is_legendary else Color(0.035, 0.026, 0.018, 0.96)
	style.border_color = Color(LEGENDARY_COLOR.r, LEGENDARY_COLOR.g, LEGENDARY_COLOR.b, 0.88) if is_legendary else Color(0.96, 0.78, 0.34, 0.68)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_circle_style(fill: Color, border: Color, radius: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	var corner_radius: int = maxi(int(round(radius)), 1)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func _make_action_style(state: String, quiet: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = Color(0.11, 0.076, 0.034, 0.96)
			style.border_color = Color(1.0, 0.84, 0.40, 0.86)
		"pressed":
			style.bg_color = Color(0.07, 0.13, 0.11, 0.96)
			style.border_color = Color(0.56, 0.96, 0.88, 0.84)
		"focus":
			style.bg_color = Color(0.07, 0.055, 0.038, 0.94)
			style.border_color = Color(0.62, 0.92, 0.84, 0.78)
		_:
			style.bg_color = Color(0.045, 0.039, 0.036, 0.82 if quiet else 0.92)
			style.border_color = Color(0.70, 0.58, 0.36, 0.38 if quiet else 0.62)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
