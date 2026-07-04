extends Control
class_name RogueliteHUD

# index:title Roguelite HUD
# index:category UI / Presentation
# index:status First Pass
# index:owner ui_agent
# index:notes Displays current roguelite round quota and shot budget; no gameplay ownership.

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const PANEL_SIZE := Vector2(270.0, 170.0)
const PANEL_POSITION := Vector2(36.0, 94.0)
const PANEL_PADDING := 14.0

var snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 28
	position = PANEL_POSITION
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	visible = false
	queue_redraw()


func set_visible_for_roguelite(enabled: bool) -> void:
	visible = enabled
	queue_redraw()


func set_snapshot(new_snapshot: Dictionary) -> void:
	snapshot = new_snapshot.duplicate(true)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var rect: Rect2 = Rect2(Vector2.ZERO, PANEL_SIZE)
	draw_rect(rect, Color(0.018, 0.014, 0.020, 0.74), true)
	draw_rect(rect, Color(0.92, 0.72, 0.32, 0.56), false, 2.0)

	var title_font: Font = UI_FONT
	var body_font: Font = UI_FONT
	var title_color := Color(1.0, 0.88, 0.48, 1.0)
	var body_color := Color(0.86, 0.91, 0.80, 0.94)
	var accent_color := Color(0.56, 0.92, 0.88, 0.96)
	var warning_color := Color(1.0, 0.50, 0.42, 0.96)
	var line_x: float = PANEL_PADDING
	var y: float = PANEL_PADDING + 17.0

	draw_string(title_font, Vector2(line_x, y), "THE LONG SINK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, title_color)
	y += 29.0

	var round_number: int = int(snapshot.get("round_number", 1))
	var round_count: int = maxi(int(snapshot.get("round_count", 1)), 1)
	draw_string(body_font, Vector2(line_x, y), "Round %s / %s" % [round_number, round_count], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, body_color)
	y += 26.0

	var round_score: int = maxi(int(snapshot.get("round_score", 0)), 0)
	var round_target: int = maxi(int(snapshot.get("round_target", 0)), 0)
	draw_string(body_font, Vector2(line_x, y), "Quota: %s / %s" % [round_score, round_target], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, accent_color)
	y += 26.0

	var shots_left: int = maxi(int(snapshot.get("shots_left", 0)), 0)
	draw_string(body_font, Vector2(line_x, y), "Shots: %s" % shots_left, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, body_color)
	y += 24.0

	var hull: int = maxi(int(snapshot.get("hull", 3)), 0)
	var max_hull: int = maxi(int(snapshot.get("max_hull", hull)), 1)
	draw_string(body_font, Vector2(line_x, y), "Hull: %s / %s" % [hull, max_hull], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, body_color)
	y += 24.0

	if bool(snapshot.get("run_completed", false)):
		draw_string(body_font, Vector2(line_x, y), "Run Complete", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, title_color)
	elif bool(snapshot.get("round_won", false)):
		draw_string(body_font, Vector2(line_x, y), "Round Cleared", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, title_color)
	elif bool(snapshot.get("run_failed", false)):
		draw_string(body_font, Vector2(line_x, y), "Run Failed", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, warning_color)
