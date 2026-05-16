extends RefCounted
class_name ItemIconDraw

const PLAIN_BALL_FILL := Color(0.9, 0.86, 0.66, 0.94)
const PLAIN_BALL_HIGHLIGHT := Color(1.0, 0.98, 0.82, 0.82)
const PLAIN_BALL_OUTLINE := Color(0.12, 0.09, 0.04, 0.86)
const WAYFINDER_FILL := Color(0.34, 0.96, 0.84, 0.9)
const WAYFINDER_OUTLINE := Color(0.04, 0.16, 0.15, 0.9)
const WAYFINDER_MARK := Color(1.0, 0.92, 0.58, 0.96)
const KEG_FILL := Color(0.55, 0.16, 0.09, 0.95)
const KEG_BORDER := Color(1.0, 0.6, 0.24, 0.9)
const FUSE_COLOR := Color(0.95, 0.78, 0.46, 0.95)
const SPARK_COLOR := Color(1.0, 0.42, 0.1, 0.92)


static func draw_icon(canvas: CanvasItem, icon_rect: Rect2, icon_key: String) -> void:
	match icon_key:
		"wayfinder_ball":
			draw_wayfinder_icon(canvas, icon_rect)
		"powder_keg_ball":
			draw_powder_keg_icon(canvas, icon_rect)
		_:
			draw_plain_ball_icon(canvas, icon_rect)


static func draw_plain_ball_icon(canvas: CanvasItem, icon_rect: Rect2) -> void:
	var center: Vector2 = icon_rect.get_center()
	var radius: float = minf(icon_rect.size.x, icon_rect.size.y) * 0.31
	canvas.draw_circle(center, radius, PLAIN_BALL_FILL)
	canvas.draw_circle(center + Vector2(-radius * 0.36, -radius * 0.36), radius * 0.28, PLAIN_BALL_HIGHLIGHT)
	canvas.draw_arc(center, radius, 0.0, TAU, 32, PLAIN_BALL_OUTLINE, 2.0, true)


static func draw_wayfinder_icon(canvas: CanvasItem, icon_rect: Rect2) -> void:
	var center: Vector2 = icon_rect.get_center()
	var radius: float = minf(icon_rect.size.x, icon_rect.size.y) * 0.33
	canvas.draw_circle(center, radius, WAYFINDER_FILL)
	canvas.draw_arc(center, radius, 0.0, TAU, 32, WAYFINDER_OUTLINE, 2.0, true)
	canvas.draw_line(
		center + Vector2(-radius * 0.58, radius * 0.40),
		center + Vector2(radius * 0.58, -radius * 0.40),
		WAYFINDER_MARK,
		3.0
	)
	canvas.draw_circle(center, radius * 0.18, WAYFINDER_OUTLINE)


static func draw_powder_keg_icon(canvas: CanvasItem, icon_rect: Rect2) -> void:
	var center: Vector2 = icon_rect.get_center()
	var unit: float = minf(icon_rect.size.x, icon_rect.size.y)
	var keg_rect := Rect2(center + Vector2(-unit * 0.31, -unit * 0.25), Vector2(unit * 0.62, unit * 0.54))
	canvas.draw_rect(keg_rect, KEG_FILL, true)
	canvas.draw_rect(keg_rect, KEG_BORDER, false, 2.0)
	canvas.draw_line(
		center + Vector2(0.0, -unit * 0.25),
		center + Vector2(unit * 0.20, -unit * 0.43),
		FUSE_COLOR,
		2.0
	)
	canvas.draw_circle(center + Vector2(unit * 0.25, -unit * 0.50), unit * 0.065, SPARK_COLOR)
