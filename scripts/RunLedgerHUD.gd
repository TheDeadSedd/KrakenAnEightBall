extends Control
class_name RunLedgerHUD

# Compact run counters for table population and current-run sunk-ball progress.
# Table.gd owns the numbers; this node only presents the latest snapshot.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const LEDGER_SIZE := Vector2(164, 54)
const LABEL_SIZE := Vector2(144, 21)
const LABEL_X := 10.0
const BALLS_LABEL_Y := 6.0
const SUNK_LABEL_Y := 28.0
const LABEL_FONT_SIZE := 18
const PANEL_FILL := Color(0.035, 0.026, 0.018, 0.56)
const PANEL_BORDER := Color(0.96, 0.78, 0.34, 0.32)
const BALLS_COLOR := Color(0.86, 0.96, 0.86, 0.94)
const SUNK_COLOR := Color(1.0, 0.84, 0.38, 0.94)
const SHADOW_COLOR := Color(0.04, 0.02, 0.0, 0.78)
const OUTLINE_COLOR := Color(0.16, 0.07, 0.02, 0.88)

var table: BilliardsTable
var balls_label: Label
var sunk_label: Label
var panel_style := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = LEDGER_SIZE
	custom_minimum_size = LEDGER_SIZE
	_configure_panel_style()
	_build_labels()
	set_run_counts(0, 0)


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	if table == null:
		set_run_counts(0, 0)
		return

	if not table.run_ball_counts_changed.is_connected(_on_run_ball_counts_changed):
		table.run_ball_counts_changed.connect(_on_run_ball_counts_changed)
	var snapshot: Dictionary = table.get_run_ball_counts_snapshot()
	set_run_counts(
		int(snapshot.get("active_ball_count", 0)),
		int(snapshot.get("balls_sunk_count", 0))
	)


func set_run_counts(active_ball_count: int, balls_sunk_count: int) -> void:
	if balls_label != null:
		balls_label.text = "BALLS: %s" % maxi(active_ball_count, 0)
	if sunk_label != null:
		sunk_label.text = "SUNK: %s" % maxi(balls_sunk_count, 0)


func _draw() -> void:
	draw_style_box(panel_style, Rect2(Vector2.ZERO, size))


func _configure_panel_style() -> void:
	panel_style.bg_color = PANEL_FILL
	panel_style.border_color = PANEL_BORDER
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7


func _build_labels() -> void:
	balls_label = _make_ledger_label(Vector2(LABEL_X, BALLS_LABEL_Y), BALLS_COLOR)
	sunk_label = _make_ledger_label(Vector2(LABEL_X, SUNK_LABEL_Y), SUNK_COLOR)
	add_child(balls_label)
	add_child(sunk_label)


func _make_ledger_label(label_position: Vector2, font_color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = label_position
	label.size = LABEL_SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", SHADOW_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 2)
	return label


func _on_run_ball_counts_changed(active_ball_count: int, balls_sunk_count: int) -> void:
	set_run_counts(active_ball_count, balls_sunk_count)
