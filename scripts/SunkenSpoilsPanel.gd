extends Control
class_name SunkenSpoilsPanel

signal reward_selected(reward_id: String)
signal doubloon_reroll_requested
signal cast_back_requested

# Presentation-only Sunken Spoils modal. SunkenSpoilsSystem owns milestone
# progress, reward definitions, reroll costs, and reward application.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const PANEL_SIZE := Vector2(720.0, 390.0)
const VIEWPORT_MARGIN := 24.0
const REWARD_CARD_SIZE := Vector2(196.0, 126.0)
const TITLE_TEXT := "Sunken Spoils"
const FLAVOR_TEXT := "The table coughs up a prize."

const SHADE_COLOR := Color(0.01, 0.012, 0.016, 0.34)
const PANEL_FILL := Color(0.034, 0.025, 0.018, 0.96)
const PANEL_BORDER := Color(0.96, 0.78, 0.34, 0.64)
const CARD_FILL := Color(0.058, 0.044, 0.030, 0.88)
const CARD_BORDER := Color(0.96, 0.78, 0.34, 0.48)
const CARD_HOVER_FILL := Color(0.092, 0.068, 0.035, 0.96)
const CARD_HOVER_BORDER := Color(1.0, 0.86, 0.42, 0.90)
const CARD_DISABLED_FILL := Color(0.034, 0.032, 0.030, 0.68)
const CARD_DISABLED_BORDER := Color(0.55, 0.47, 0.34, 0.36)
const RARITY_COMMON := "common"
const RARITY_UNCOMMON := "uncommon"
const RARITY_RARE := "rare"

var spoils_snapshot: Dictionary = {}
var shade: ColorRect
var panel: PanelContainer
var milestone_label: Label
var status_label: Label
var reward_row: HBoxContainer
var reroll_button: Button
var cast_back_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 66
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func set_spoils_snapshot(snapshot: Dictionary) -> void:
	spoils_snapshot = snapshot.duplicate(true)
	_refresh_panel()


func open_panel(snapshot: Dictionary = {}) -> void:
	if not snapshot.is_empty():
		set_spoils_snapshot(snapshot)
	if not bool(spoils_snapshot.get("pending_reward_ready", false)):
		return

	_refresh_panel()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_position_panel()
	if reroll_button != null and not reroll_button.disabled:
		reroll_button.grab_focus()


func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hover_ui_suppressed(_suppressed: bool) -> void:
	# This modal has no hover-only UI; kept for shared HUD wiring symmetry.
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_position_panel()


func _build_ui() -> void:
	shade = ColorRect.new()
	shade.name = "SunkenSpoilsShade"
	shade.color = SHADE_COLOR
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	panel = PanelContainer.new()
	panel.name = "SunkenSpoilsPanel"
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var title_label: Label = _make_label(TITLE_TEXT, 30, Color(1.0, 0.88, 0.52, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(title_label)

	var flavor_label: Label = _make_label(FLAVOR_TEXT, 16, Color(0.76, 0.88, 0.78, 0.96), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(flavor_label)

	milestone_label = _make_label("", 17, Color(0.96, 0.82, 0.40, 0.96), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(milestone_label)

	reward_row = HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 12)
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(reward_row)

	status_label = _make_label("", 14, Color(0.82, 0.78, 0.66, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
	status_label.custom_minimum_size = Vector2(0.0, 30.0)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(status_label)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_child(action_row)

	reroll_button = _make_action_button("")
	reroll_button.pressed.connect(_on_reroll_pressed)
	action_row.add_child(reroll_button)

	cast_back_button = _make_action_button("Cast Back")
	cast_back_button.pressed.connect(_on_cast_back_pressed)
	action_row.add_child(cast_back_button)


func _refresh_panel() -> void:
	if reward_row == null:
		return

	var progress: int = maxi(int(spoils_snapshot.get("current_milestone_progress", 0)), 0)
	var required: int = maxi(int(spoils_snapshot.get("current_milestone_required", 1)), 1)
	var milestone_number: int = maxi(int(spoils_snapshot.get("current_milestone_index", 0)) + 1, 1)
	milestone_label.text = "Milestone %s: %s / %s sunk" % [milestone_number, progress, required]

	_clear_reward_cards()
	var offers_value: Variant = spoils_snapshot.get("reward_offers", [])
	if offers_value is Array:
		for offer_value in offers_value:
			if offer_value is Dictionary:
				var offer: Dictionary = offer_value
				reward_row.add_child(_make_reward_card(offer))

	var reroll_cost: int = maxi(int(spoils_snapshot.get("current_reroll_cost", 0)), 0)
	var reroll_blocker: String = str(spoils_snapshot.get("doubloon_reroll_blocked_reason", ""))
	reroll_button.text = "Reroll: %s Doubloons" % reroll_cost
	reroll_button.disabled = not reroll_blocker.is_empty()
	cast_back_button.disabled = not bool(spoils_snapshot.get("pending_reward_available", false))

	var last_status: String = str(spoils_snapshot.get("last_status", ""))
	if not reroll_blocker.is_empty():
		status_label.text = reroll_blocker
	elif not last_status.is_empty():
		status_label.text = last_status
	else:
		status_label.text = "Choose a prize, reroll for Doubloons, or cast it back."


func _clear_reward_cards() -> void:
	for child in reward_row.get_children():
		reward_row.remove_child(child)
		child.queue_free()


func _make_reward_card(offer: Dictionary) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = REWARD_CARD_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.66, 0.62, 0.52, 0.82))
	button.add_theme_stylebox_override("normal", _make_card_style(CARD_FILL, CARD_BORDER))
	button.add_theme_stylebox_override("hover", _make_card_style(CARD_HOVER_FILL, CARD_HOVER_BORDER))
	button.add_theme_stylebox_override("pressed", _make_card_style(CARD_HOVER_FILL, CARD_HOVER_BORDER))
	button.add_theme_stylebox_override("disabled", _make_card_style(CARD_DISABLED_FILL, CARD_DISABLED_BORDER))

	var reward_id: String = str(offer.get("id", ""))
	var rarity: String = _normalize_rarity(str(offer.get("rarity", RARITY_COMMON)))
	var label: String = _format_card_label(str(offer.get("display_label", offer.get("label", "Reward"))))
	var summary: String = str(offer.get("summary", "Reward"))
	var blocked_reason: String = str(offer.get("blocked_reason", ""))
	button.add_theme_color_override("font_color", _get_rarity_text_color(rarity))
	button.disabled = not bool(offer.get("available", false))
	button.add_theme_stylebox_override("normal", _make_card_style_for_rarity(rarity, false, false))
	button.add_theme_stylebox_override("hover", _make_card_style_for_rarity(rarity, true, false))
	button.add_theme_stylebox_override("pressed", _make_card_style_for_rarity(rarity, true, false))
	button.add_theme_stylebox_override("disabled", _make_card_style_for_rarity(rarity, false, true))
	if button.disabled and not blocked_reason.is_empty():
		button.text = "%s\n%s\n%s" % [label, summary, blocked_reason]
	else:
		button.text = "%s\n%s" % [label, summary]
	button.pressed.connect(_on_reward_pressed.bind(reward_id))
	return button


func _format_card_label(label: String) -> String:
	match label:
		"Kraken's Mark":
			return "Kraken's\nMark"
		"Loose Cargo Stack":
			return "Loose Cargo\nStack"
		"Wayfinder's Glint":
			return "Wayfinder's\nGlint"
		"Favorable Current":
			return "Favorable\nCurrent"
	return label


func _make_action_button(text_value: String) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(220.0, 40.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.58, 0.48, 0.80))
	button.add_theme_stylebox_override("normal", _make_card_style(CARD_FILL, CARD_BORDER))
	button.add_theme_stylebox_override("hover", _make_card_style(CARD_HOVER_FILL, CARD_HOVER_BORDER))
	button.add_theme_stylebox_override("pressed", _make_card_style(CARD_HOVER_FILL, CARD_HOVER_BORDER))
	button.add_theme_stylebox_override("disabled", _make_card_style(CARD_DISABLED_FILL, CARD_DISABLED_BORDER))
	return button


func _make_label(text_value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.025, 0.012, 0.92))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _make_card_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _make_card_style_for_rarity(rarity: String, hovered: bool, disabled: bool) -> StyleBoxFlat:
	if disabled:
		return _make_card_style(CARD_DISABLED_FILL, CARD_DISABLED_BORDER)

	var fill: Color = CARD_FILL
	var border: Color = CARD_BORDER
	var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.0)
	var shadow_size: int = 0
	match rarity:
		RARITY_UNCOMMON:
			fill = Color(0.047, 0.064, 0.050, 0.91)
			border = Color(0.42, 0.92, 0.78, 0.56)
			shadow_color = Color(0.18, 0.88, 0.74, 0.16)
			shadow_size = 4
		RARITY_RARE:
			fill = Color(0.065, 0.046, 0.073, 0.94)
			border = Color(1.0, 0.82, 0.34, 0.78)
			shadow_color = Color(0.96, 0.66, 0.20, 0.25)
			shadow_size = 7
		_:
			fill = CARD_FILL
			border = Color(0.96, 0.78, 0.34, 0.48)
			shadow_color = Color(0.96, 0.72, 0.20, 0.08)
			shadow_size = 2

	if hovered:
		fill = fill.lightened(0.12)
		border = border.lightened(0.18)
		shadow_size += 2

	var style: StyleBoxFlat = _make_card_style(fill, border)
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	return style


func _normalize_rarity(rarity: String) -> String:
	var normalized: String = rarity.to_lower()
	if normalized == RARITY_COMMON or normalized == RARITY_UNCOMMON or normalized == RARITY_RARE:
		return normalized
	return RARITY_COMMON


func _get_rarity_text_color(rarity: String) -> Color:
	match rarity:
		RARITY_UNCOMMON:
			return Color(0.70, 1.0, 0.90, 1.0)
		RARITY_RARE:
			return Color(1.0, 0.88, 0.50, 1.0)
	return Color(1.0, 0.88, 0.54, 1.0)


func _position_panel() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_position: Vector2 = (viewport_size - PANEL_SIZE) * 0.5
	var max_x: float = maxf(viewport_size.x - PANEL_SIZE.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN)
	var max_y: float = maxf(viewport_size.y - PANEL_SIZE.y - VIEWPORT_MARGIN, VIEWPORT_MARGIN)
	panel_position.x = clampf(panel_position.x, VIEWPORT_MARGIN, max_x)
	panel_position.y = clampf(panel_position.y, VIEWPORT_MARGIN, max_y)
	panel.position = panel_position
	panel.custom_minimum_size = PANEL_SIZE
	panel.size = PANEL_SIZE


func _on_reward_pressed(reward_id: String) -> void:
	if reward_id.is_empty():
		return
	reward_selected.emit(reward_id)


func _on_reroll_pressed() -> void:
	doubloon_reroll_requested.emit()


func _on_cast_back_pressed() -> void:
	cast_back_requested.emit()
