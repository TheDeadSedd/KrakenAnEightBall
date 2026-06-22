extends Control
class_name CueStartSelectorHUD

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const GHOST_RADIUS := 13.0
const GUIDE_RADIUS := 4.0
const HINT_OFFSET := Vector2(0.0, 42.0)
const HINT_FONT_SIZE := 12
const HINT_LINE_HEIGHT := 14.0

var latest_snapshot: Dictionary = {}
var hover_ui_suppressed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_cue_start_snapshot({})


func setup(table: BilliardsTable) -> void:
	if table == null:
		set_cue_start_snapshot({})
		return
	set_cue_start_snapshot(table.get_cue_start_selection_snapshot())


func set_cue_start_snapshot(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot.duplicate(true)
	visible = bool(snapshot.get("active", false))
	queue_redraw()


func set_hover_ui_suppressed(suppressed: bool) -> void:
	if hover_ui_suppressed == suppressed:
		return
	hover_ui_suppressed = suppressed
	queue_redraw()


func _draw() -> void:
	if not visible or hover_ui_suppressed:
		return

	var options := _get_options()
	if options.is_empty():
		return

	var locked := bool(latest_snapshot.get("locked", false))
	var highlighted_index := int(latest_snapshot.get("highlighted_index", latest_snapshot.get("selected_index", 1)))
	if locked:
		_draw_locked_hint(options, highlighted_index)
		return

	_draw_guide_dots(options, highlighted_index)
	_draw_ghost_ball(_get_option_position(options, highlighted_index))
	_draw_hint(_get_option_position(options, highlighted_index), PackedStringArray(["Left Click", "Set Start"]))


func _draw_guide_dots(options: Array, highlighted_index: int) -> void:
	for option_value in options:
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value as Dictionary
		var option_index := int(option.get("index", -1))
		var position := _get_position_from_option(option)
		if option_index == highlighted_index:
			draw_circle(position, GUIDE_RADIUS + 3.0, Color(0.82, 1.0, 0.96, 0.24))
			draw_arc(position, GUIDE_RADIUS + 5.0, 0.0, TAU, 32, Color(0.76, 1.0, 0.92, 0.48), 1.3)
		else:
			draw_circle(position, GUIDE_RADIUS, Color(0.86, 0.94, 0.90, 0.22))


func _draw_ghost_ball(position: Vector2) -> void:
	draw_circle(position, GHOST_RADIUS + 12.0, Color(0.40, 0.95, 0.92, 0.07))
	draw_circle(position, GHOST_RADIUS + 6.0, Color(0.80, 1.0, 0.96, 0.12))
	draw_circle(position, GHOST_RADIUS, Color(0.90, 1.0, 0.98, 0.38))
	draw_circle(position + Vector2(-4.0, -5.0), GHOST_RADIUS * 0.36, Color(1.0, 1.0, 1.0, 0.30))
	draw_arc(position, GHOST_RADIUS + 1.5, 0.0, TAU, 36, Color(0.90, 1.0, 0.96, 0.52), 1.5)


func _draw_locked_hint(options: Array, selected_index: int) -> void:
	var selected_position := _get_option_position(options, selected_index)
	if selected_position == Vector2.ZERO:
		return
	_draw_hint(selected_position, PackedStringArray(["Right Click", "Change Start"]), Color(1.0, 0.88, 0.56, 0.72))


func _draw_hint(anchor_position: Vector2, lines: PackedStringArray, color: Color = Color(0.84, 0.96, 0.88, 0.76)) -> void:
	if lines.is_empty():
		return

	var total_height := float(lines.size() - 1) * HINT_LINE_HEIGHT
	var line_position := anchor_position + HINT_OFFSET - Vector2(0.0, total_height * 0.5)
	for line in lines:
		var line_size := UI_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, HINT_FONT_SIZE)
		draw_string(
			UI_FONT,
			line_position - Vector2(line_size.x * 0.5, 0.0),
			line,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			HINT_FONT_SIZE,
			color
		)
		line_position.y += HINT_LINE_HEIGHT


func _get_options() -> Array:
	var options_value: Variant = latest_snapshot.get("options", [])
	if options_value is Array:
		return options_value as Array
	return []


func _get_option_position(options: Array, option_index: int) -> Vector2:
	for option_value in options:
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value as Dictionary
		if int(option.get("index", -1)) == option_index:
			return _get_position_from_option(option)
	return Vector2.ZERO


func _get_position_from_option(option: Dictionary) -> Vector2:
	var position_value: Variant = option.get("position", Vector2.ZERO)
	if position_value is Vector2:
		return position_value
	return Vector2.ZERO
