extends Control
class_name QuartermasterHUD

signal quartermaster_offer_requested(offer_index: int)

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const OFFER_SLOT_COUNT := 3
const SLOT_SIZE := Vector2(44, 44)
const SLOT_PADDING := 8.0
const COST_LEFT := 58.0
const ROW_HEIGHT := 58.0
const COST_FONT_SIZE := 17
const TOOLTIP_FONT_SIZE := 15
const TOOLTIP_WIDTH := 310.0
const REFRESH_CUE_SECONDS := 0.46
const EMPTY_SLOT_FILL := Color(0.035, 0.028, 0.022, 0.58)
const EMPTY_SLOT_BORDER := Color(0.92, 0.76, 0.38, 0.34)
const HOVER_SLOT_FILL := Color(0.09, 0.07, 0.04, 0.76)
const HOVER_SLOT_BORDER := Color(1.0, 0.86, 0.42, 0.92)
const HOVER_GLOW := Color(1.0, 0.72, 0.24, 0.18)
const FILLED_SLOT_FILL := Color(0.08, 0.11, 0.11, 0.78)
const FILLED_SLOT_BORDER := Color(0.72, 0.96, 0.84, 0.58)
const UNAFFORDABLE_TINT := Color(0.06, 0.05, 0.045, 0.48)
const REFRESH_GLOW := Color(1.0, 0.76, 0.22, 0.26)
const REFRESH_SWEEP := Color(1.0, 0.94, 0.58, 0.42)
const COST_AVAILABLE := Color(1.0, 0.84, 0.36, 1.0)
const COST_UNAVAILABLE := Color(0.62, 0.55, 0.44, 0.76)
const COST_SHADOW := Color(0.04, 0.02, 0.0, 0.78)
const SHOP_X_OFFSET_FROM_TABLE := -8.0
const SHOP_Y_OFFSET_FROM_TABLE := 106.0
const CORNER_RADIUS := 9
const GLOW_OUTSET := 5.0

const ITEM_ICON_DRAW := preload("res://scripts/ItemIconDraw.gd")
const FLAVOR_BY_ITEM_ID := {
	"plain_object_ball": "Loose cargo for a crowded table.",
	"wayfinder_ball": "A sly compass with a pocket-hungry eye.",
	"powder_keg_ball": "A bad idea with a short fuse.",
}

var quartermaster_system: QuartermasterSystem
var table
var offer_snapshots: Array = []
var hovered_offer_index := -1
var refresh_offer_index := -1
var refresh_timer := 0.0
var last_seen_stock_refresh_serial := 0

var empty_slot_style := StyleBoxFlat.new()
var hover_slot_style := StyleBoxFlat.new()
var filled_slot_style := StyleBoxFlat.new()
var hover_glow_style := StyleBoxFlat.new()
var tooltip_panel: PanelContainer
var tooltip_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	z_index = 22
	_configure_styles()
	_build_tooltip()
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	set_process(false)


func setup(quartermaster_system_ref: QuartermasterSystem, table_ref) -> void:
	quartermaster_system = quartermaster_system_ref
	table = table_ref
	_position_on_table_rail()
	if quartermaster_system != null:
		set_quartermaster_items(quartermaster_system.get_shop_items_snapshot())
	else:
		set_quartermaster_items([])


func set_quartermaster_items(items: Array) -> void:
	offer_snapshots = items.duplicate(true)
	_note_refresh_state(offer_snapshots)
	_update_tooltip()
	queue_redraw()


func _process(delta: float) -> void:
	if refresh_timer <= 0.0:
		set_process(false)
		return

	refresh_timer = maxf(refresh_timer - delta, 0.0)
	queue_redraw()
	if refresh_timer <= 0.0:
		refresh_offer_index = -1
		set_process(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hovered_offer(event.position)
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		_update_hovered_offer(mouse_event.position)
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if hovered_offer_index == -1:
			return
		if _is_cue_drag_active():
			return

		accept_event()
		if _is_offer_available(hovered_offer_index):
			quartermaster_offer_requested.emit(hovered_offer_index)


func _draw() -> void:
	for offer_index in range(OFFER_SLOT_COUNT):
		var slot_rect: Rect2 = _get_slot_rect(offer_index)
		var item: Dictionary = _get_offer_snapshot(offer_index)
		var has_item: bool = not item.is_empty()
		var available: bool = bool(item.get("available", false))
		var affordable: bool = bool(item.get("affordable", false))

		if offer_index == hovered_offer_index:
			draw_style_box(hover_glow_style, slot_rect.grow(GLOW_OUTSET))
			draw_style_box(hover_slot_style, slot_rect)
		elif has_item:
			draw_style_box(filled_slot_style, slot_rect)
		else:
			draw_style_box(empty_slot_style, slot_rect)

		if has_item:
			ITEM_ICON_DRAW.draw_icon(self, slot_rect, str(item.get("icon_key", item.get("id", ""))))
			if not available or not affordable:
				draw_rect(slot_rect.grow(-1.0), UNAFFORDABLE_TINT, true)
			_draw_offer_cost(offer_index, item, available and affordable)

		if offer_index == refresh_offer_index and refresh_timer > 0.0:
			_draw_refresh_cue(slot_rect)


func _configure_styles() -> void:
	_configure_slot_style(empty_slot_style, EMPTY_SLOT_FILL, EMPTY_SLOT_BORDER, 1)
	_configure_slot_style(hover_slot_style, HOVER_SLOT_FILL, HOVER_SLOT_BORDER, 2)
	_configure_slot_style(filled_slot_style, FILLED_SLOT_FILL, FILLED_SLOT_BORDER, 1)
	_configure_slot_style(hover_glow_style, HOVER_GLOW, Color(1.0, 0.72, 0.24, 0.0), 0)


func _configure_slot_style(style: StyleBoxFlat, fill: Color, border: Color, border_width: int) -> void:
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


func _build_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 12
	tooltip_panel.add_theme_stylebox_override("panel", _make_tooltip_style())
	add_child(tooltip_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 9)
	tooltip_panel.add_child(margin)

	tooltip_label = Label.new()
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0.0)
	tooltip_label.add_theme_font_override("font", UI_FONT)
	tooltip_label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	tooltip_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66, 0.96))
	tooltip_label.add_theme_color_override("font_outline_color", Color(0.05, 0.025, 0.0, 0.92))
	tooltip_label.add_theme_constant_override("outline_size", 2)
	margin.add_child(tooltip_label)


func _make_tooltip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.026, 0.018, 0.94)
	style.border_color = Color(0.96, 0.78, 0.34, 0.46)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _position_on_table_rail() -> void:
	var shop_size := Vector2(
		COST_LEFT + 70.0,
		SLOT_PADDING * 2.0 + ROW_HEIGHT * OFFER_SLOT_COUNT
	)
	size = shop_size
	custom_minimum_size = shop_size
	var table_rect: Rect2 = _get_table_outer_rect()
	position = Vector2(
		table_rect.end.x + SHOP_X_OFFSET_FROM_TABLE,
		table_rect.position.y + SHOP_Y_OFFSET_FROM_TABLE
	)


func _get_table_outer_rect() -> Rect2:
	if table != null:
		return table.TABLE_OUTER_RECT
	return Rect2(400, 220, 1120, 640)


func _note_refresh_state(items: Array) -> void:
	if items.is_empty():
		return

	var first_value: Variant = items[0]
	if not first_value is Dictionary:
		return

	var first_item: Dictionary = first_value
	var refresh_serial: int = int(first_item.get("stock_refresh_serial", 0))
	var refreshed_offer_index: int = int(first_item.get("last_refreshed_offer_index", -1))
	if refresh_serial > last_seen_stock_refresh_serial and _is_valid_offer_index(refreshed_offer_index):
		refresh_offer_index = refreshed_offer_index
		refresh_timer = REFRESH_CUE_SECONDS
		set_process(true)
	last_seen_stock_refresh_serial = max(last_seen_stock_refresh_serial, refresh_serial)


func _draw_offer_cost(offer_index: int, item: Dictionary, is_available: bool) -> void:
	var slot_rect: Rect2 = _get_slot_rect(offer_index)
	var cost_text := "%s" % int(item.get("price", 0))
	var text_position := Vector2(COST_LEFT, slot_rect.position.y + 29.0)
	var color: Color = COST_AVAILABLE if is_available else COST_UNAVAILABLE
	draw_string(UI_FONT, text_position + Vector2(1.5, 1.5), cost_text, HORIZONTAL_ALIGNMENT_LEFT, 64.0, COST_FONT_SIZE, COST_SHADOW)
	draw_string(UI_FONT, text_position, cost_text, HORIZONTAL_ALIGNMENT_LEFT, 64.0, COST_FONT_SIZE, color)


func _draw_refresh_cue(slot_rect: Rect2) -> void:
	var ratio: float = 1.0 - (refresh_timer / REFRESH_CUE_SECONDS)
	var glow_alpha: float = sin(ratio * PI)
	var glow_color: Color = Color(REFRESH_GLOW.r, REFRESH_GLOW.g, REFRESH_GLOW.b, REFRESH_GLOW.a * glow_alpha)
	draw_style_box(hover_glow_style, slot_rect.grow(GLOW_OUTSET + 2.0))
	draw_rect(slot_rect.grow(3.0), glow_color, false, 2.0)
	var sweep_x: float = lerpf(slot_rect.position.x - slot_rect.size.x * 0.4, slot_rect.end.x + slot_rect.size.x * 0.4, ratio)
	draw_line(
		Vector2(sweep_x, slot_rect.position.y + 5.0),
		Vector2(sweep_x + 12.0, slot_rect.end.y - 5.0),
		REFRESH_SWEEP,
		4.0
	)


func _update_hovered_offer(local_position: Vector2) -> void:
	var next_hovered_offer := _get_offer_index_at_position(local_position)
	if next_hovered_offer == hovered_offer_index:
		return

	hovered_offer_index = next_hovered_offer
	_update_tooltip()
	queue_redraw()


func _update_tooltip() -> void:
	if tooltip_panel == null or tooltip_label == null:
		return
	if hovered_offer_index == -1:
		tooltip_panel.visible = false
		return

	var item: Dictionary = _get_offer_snapshot(hovered_offer_index)
	if item.is_empty():
		tooltip_panel.visible = false
		return

	tooltip_label.text = _make_tooltip_text(item)
	tooltip_panel.position = _get_tooltip_position(hovered_offer_index)
	tooltip_panel.visible = true


func _make_tooltip_text(item: Dictionary) -> String:
	var item_id := str(item.get("id", ""))
	var flavor := str(FLAVOR_BY_ITEM_ID.get(item_id, "A curious bit of cursed table cargo."))
	var blocker := str(item.get("blocked_reason", ""))
	var status_line := "Cost: %s Doubloons" % int(item.get("price", 0))
	if not blocker.is_empty():
		status_line = "%s - %s" % [status_line, blocker]
	return "%s\n%s\n%s\n%s" % [
		str(item.get("name", "Quartermaster Item")),
		flavor,
		str(item.get("description", "")),
		status_line,
	]


func _get_tooltip_position(offer_index: int) -> Vector2:
	var slot_rect: Rect2 = _get_slot_rect(offer_index)
	var tooltip_y: float = clampf(slot_rect.position.y - 10.0, 0.0, maxf(size.y - 118.0, 0.0))
	return Vector2(-TOOLTIP_WIDTH - 26.0, tooltip_y)


func _on_mouse_exited() -> void:
	if hovered_offer_index == -1:
		return
	hovered_offer_index = -1
	_update_tooltip()
	queue_redraw()


func _get_offer_index_at_position(local_position: Vector2) -> int:
	for offer_index in range(OFFER_SLOT_COUNT):
		if _get_offer_interaction_rect(offer_index).has_point(local_position):
			return offer_index
	return -1


func _get_offer_interaction_rect(offer_index: int) -> Rect2:
	return Rect2(
		Vector2(SLOT_PADDING, SLOT_PADDING + offer_index * ROW_HEIGHT),
		Vector2(size.x - SLOT_PADDING * 2.0, SLOT_SIZE.y)
	)


func _get_slot_rect(offer_index: int) -> Rect2:
	return Rect2(
		Vector2(SLOT_PADDING, SLOT_PADDING + offer_index * ROW_HEIGHT),
		SLOT_SIZE
	)


func _get_offer_snapshot(offer_index: int) -> Dictionary:
	if offer_index < 0 or offer_index >= offer_snapshots.size():
		return {}
	var snapshot: Variant = offer_snapshots[offer_index]
	if snapshot is Dictionary:
		return snapshot
	return {}


func _is_offer_available(offer_index: int) -> bool:
	return bool(_get_offer_snapshot(offer_index).get("available", false))


func _is_valid_offer_index(offer_index: int) -> bool:
	return offer_index >= 0 and offer_index < OFFER_SLOT_COUNT


func _is_cue_drag_active() -> bool:
	return table != null and table.is_cue_drag_active()
