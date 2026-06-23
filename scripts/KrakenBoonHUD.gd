extends Control
class_name KrakenBoonHUD

# Compact active-boon presenter. KrakenBoonSystem owns definitions, timers,
# and effects; this node only mirrors the active-boon snapshot on the HUD.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const PANEL_WIDTH := 270.0
const MIN_PANEL_HEIGHT := 76.0
const HUD_RIGHT_MARGIN := 92.0
const HUD_TOP := 522.0
const VIEWPORT_MARGIN := 24.0
const PADDING_X := 12.0
const PADDING_Y := 10.0
const TITLE_HEIGHT := 24.0
const ROW_HEIGHT := 28.0
const ROW_GAP := 4.0
const TITLE_FONT_SIZE := 16
const ROW_FONT_SIZE := 15
const SHOTS_FONT_SIZE := 14
const PULSE_DURATION := 0.45

const PANEL_FILL := Color(0.035, 0.022, 0.018, 0.68)
const PANEL_BORDER := Color(0.89, 0.66, 0.28, 0.52)
const TITLE_COLOR := Color(1.0, 0.84, 0.46, 1.0)
const NAME_COLOR := Color(0.86, 0.94, 0.90, 0.98)
const SHOTS_COLOR := Color(0.46, 0.88, 0.82, 0.96)
const SHADOW_COLOR := Color(0.03, 0.015, 0.006, 0.86)
const DIVIDER_COLOR := Color(0.95, 0.62, 0.24, 0.22)
const PULSE_COLOR := Color(0.34, 0.95, 0.84, 0.34)

var kraken_boon_system: KrakenBoonSystem
var active_boons: Array = []
var pulse_time: float = 0.0
var previous_remaining_by_id: Dictionary = {}
var previous_activation_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 23
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	_apply_anchor(_get_panel_size())
	set_process(false)


func setup(system: KrakenBoonSystem) -> void:
	if kraken_boon_system != null and kraken_boon_system.boons_changed.is_connected(_on_boons_changed):
		kraken_boon_system.boons_changed.disconnect(_on_boons_changed)

	kraken_boon_system = system
	if kraken_boon_system == null:
		set_boon_snapshot({})
		return

	if not kraken_boon_system.boons_changed.is_connected(_on_boons_changed):
		kraken_boon_system.boons_changed.connect(_on_boons_changed)
	set_boon_snapshot(kraken_boon_system.get_boon_snapshot())


func set_boon_snapshot(snapshot: Dictionary) -> void:
	var previous_snapshot: Dictionary = previous_remaining_by_id.duplicate()
	var activation_count: int = int(snapshot.get("activations_total", previous_activation_count))
	active_boons = _extract_active_boons(snapshot)
	visible = not active_boons.is_empty()
	_apply_anchor(_get_panel_size())
	_update_pulse(previous_snapshot, activation_count)
	queue_redraw()


func set_hover_ui_suppressed(_suppressed: bool) -> void:
	# No hover UI in this first pass. Kept for shared HUD wiring symmetry.
	pass


func _process(delta: float) -> void:
	if pulse_time <= 0.0:
		set_process(false)
		return

	pulse_time = maxf(pulse_time - delta, 0.0)
	queue_redraw()
	if pulse_time <= 0.0:
		set_process(false)


func _draw() -> void:
	if active_boons.is_empty():
		return

	var panel_size: Vector2 = _get_panel_size()
	var panel_rect: Rect2 = Rect2(Vector2.ZERO, panel_size)
	draw_style_box(_make_panel_style(), panel_rect)

	if pulse_time > 0.0:
		var pulse_alpha: float = pulse_time / PULSE_DURATION
		draw_rect(panel_rect.grow(2.0), Color(PULSE_COLOR.r, PULSE_COLOR.g, PULSE_COLOR.b, PULSE_COLOR.a * pulse_alpha), false, 2.0)

	_draw_text("KRAKEN BOONS", Vector2(PADDING_X, PADDING_Y + TITLE_FONT_SIZE), TITLE_COLOR, TITLE_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - PADDING_X * 2.0)
	draw_line(
		Vector2(PADDING_X, PADDING_Y + TITLE_HEIGHT),
		Vector2(PANEL_WIDTH - PADDING_X, PADDING_Y + TITLE_HEIGHT),
		DIVIDER_COLOR,
		1.0
	)

	var row_top: float = PADDING_Y + TITLE_HEIGHT + 7.0
	for boon_value in active_boons:
		if not boon_value is Dictionary:
			continue
		var boon: Dictionary = boon_value
		_draw_boon_row(boon, row_top)
		row_top += ROW_HEIGHT + ROW_GAP


func _draw_boon_row(boon: Dictionary, row_top: float) -> void:
	var name: String = str(boon.get("name", "Kraken Boon"))
	var remaining: int = maxi(int(boon.get("remaining_shots", 0)), 0)
	var shots_text: String = _format_shots(remaining)
	var row_baseline: float = row_top + float(ROW_FONT_SIZE)
	var shots_width: float = 78.0
	var name_width: float = PANEL_WIDTH - PADDING_X * 2.0 - shots_width - 8.0

	_draw_text(name, Vector2(PADDING_X, row_baseline), NAME_COLOR, ROW_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, name_width)
	_draw_text(
		shots_text,
		Vector2(PANEL_WIDTH - PADDING_X - shots_width, row_baseline),
		SHOTS_COLOR,
		SHOTS_FONT_SIZE,
		HORIZONTAL_ALIGNMENT_RIGHT,
		shots_width
	)


func _draw_text(text: String, position: Vector2, color: Color, font_size: int, alignment: HorizontalAlignment, width: float) -> void:
	draw_string(UI_FONT, position + Vector2(1.5, 1.5), text, alignment, width, font_size, SHADOW_COLOR)
	draw_string(UI_FONT, position, text, alignment, width, font_size, color)


func _extract_active_boons(snapshot: Dictionary) -> Array:
	var active_value: Variant = snapshot.get("active_boons", [])
	if not active_value is Array:
		return []

	var entries: Array = []
	for entry_value in active_value:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			entries.append(entry.duplicate(true))
	return entries


func _update_pulse(previous_snapshot: Dictionary, activation_count: int) -> void:
	var current_remaining: Dictionary = {}
	var should_pulse: bool = activation_count > previous_activation_count and not active_boons.is_empty()
	for boon_value in active_boons:
		if not boon_value is Dictionary:
			continue
		var boon: Dictionary = boon_value
		var boon_id: String = str(boon.get("id", ""))
		if boon_id.is_empty():
			continue
		var remaining: int = maxi(int(boon.get("remaining_shots", 0)), 0)
		current_remaining[boon_id] = remaining
		if not previous_snapshot.has(boon_id) or remaining > int(previous_snapshot.get(boon_id, 0)):
			should_pulse = true

	previous_remaining_by_id = current_remaining
	previous_activation_count = activation_count
	if should_pulse:
		pulse_time = PULSE_DURATION
		set_process(true)


func _format_shots(count: int) -> String:
	var safe_count: int = maxi(count, 0)
	return "%s shot%s" % [safe_count, "" if safe_count == 1 else "s"]


func _get_panel_size() -> Vector2:
	var row_count: int = maxi(active_boons.size(), 1)
	var row_gap_count: int = maxi(row_count - 1, 0)
	var row_area: float = float(row_count) * ROW_HEIGHT + float(row_gap_count) * ROW_GAP
	var height: float = maxf(MIN_PANEL_HEIGHT, PADDING_Y * 2.0 + TITLE_HEIGHT + row_area + 6.0)
	return Vector2(PANEL_WIDTH, height)


func _apply_anchor(panel_size: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var right_margin: float = minf(
		HUD_RIGHT_MARGIN,
		maxf(VIEWPORT_MARGIN, viewport_size.x - panel_size.x - VIEWPORT_MARGIN)
	)
	var top_offset: float = minf(
		HUD_TOP,
		maxf(VIEWPORT_MARGIN, viewport_size.y - panel_size.y - VIEWPORT_MARGIN)
	)

	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -right_margin - panel_size.x
	offset_right = -right_margin
	offset_top = top_offset
	offset_bottom = top_offset + panel_size.y
	custom_minimum_size = panel_size
	size = panel_size


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _on_boons_changed(snapshot: Dictionary) -> void:
	set_boon_snapshot(snapshot)
