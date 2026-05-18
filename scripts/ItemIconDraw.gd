extends RefCounted
class_name ItemIconDraw

const DEFAULT_OBJECT_BALL_COLOR := Color("d7a829")
const OBJECT_BALL_PREVIEW_COLORS := [
	Color("d7a829"),
	Color("2f69c4"),
	Color("c43b36"),
	Color("7a44ae"),
	Color("2a2523"),
	Color("8a5428"),
	Color("2d9a5b"),
	Color("a87918"),
	Color("17488f"),
	Color("8f252b"),
	Color("4f2d78"),
	Color("5f656b"),
	Color("1f6f42"),
	Color("b85b24"),
]
const WAYFINDER_BASE_COLOR := Color("2f9f96")
const WAYFINDER_MARK_COLOR := Color("f3d27a")
const WAYFINDER_ACTIVE_GLOW_COLOR := Color("8ef7ea")
const WAYFINDER_RING_COLOR := Color("173d3a")
const POWDER_KEG_BASE_COLOR := Color("7b4723")
const POWDER_KEG_BAND_COLOR := Color("e0b15e")
const POWDER_KEG_FUSE_COLOR := Color("f6d07c")
const TREASURE_BALL_BASE_COLOR := Color("d99a28")
const TREASURE_BALL_RIM_COLOR := Color("5d3511")
const TREASURE_BALL_GEM_COLOR := Color("57e0d4")
const TREASURE_BALL_GLOW_COLOR := Color("ffe6a6")
const CANNON_BALL_BASE_COLOR := Color("17191b")
const CANNON_BALL_RIM_COLOR := Color("050607")
const CANNON_BALL_EDGE_COLOR := Color("3a3f42")
const EMBEZZLER_BALL_BASE_COLOR := Color("c97924")
const EMBEZZLER_BALL_RIM_COLOR := Color("46210b")
const EMBEZZLER_BALL_COIN_COLOR := Color("ffd56a")
const EMBEZZLER_BALL_MASK_COLOR := Color("1d1209")
const BALL_SHADOW := Color(0.0, 0.0, 0.0, 0.42)
const BALL_OUTER_SHADE := Color(0.0, 0.0, 0.0, 0.16)
const BALL_HIGHLIGHT := Color(1.0, 0.96, 0.78, 0.62)


static func get_random_object_ball_color(rng: RandomNumberGenerator) -> Color:
	if rng == null or OBJECT_BALL_PREVIEW_COLORS.is_empty():
		return DEFAULT_OBJECT_BALL_COLOR
	return OBJECT_BALL_PREVIEW_COLORS[rng.randi_range(0, OBJECT_BALL_PREVIEW_COLORS.size() - 1)]


static func draw_icon(
	canvas: CanvasItem,
	icon_rect: Rect2,
	icon_key: String,
	object_ball_color: Color = Color(0.0, 0.0, 0.0, 0.0)
) -> void:
	match icon_key:
		"wayfinder_ball":
			draw_wayfinder_icon(canvas, icon_rect)
		"powder_keg_ball":
			draw_powder_keg_icon(canvas, icon_rect)
		"treasure_ball":
			draw_treasure_icon(canvas, icon_rect)
		"cannon_ball":
			draw_cannon_icon(canvas, icon_rect)
		"embezzler_ball":
			draw_embezzler_icon(canvas, icon_rect)
		_:
			var preview_color := object_ball_color
			if preview_color.a <= 0.0:
				preview_color = DEFAULT_OBJECT_BALL_COLOR
			draw_plain_ball_icon(canvas, icon_rect, preview_color)


static func draw_plain_ball_icon(canvas: CanvasItem, icon_rect: Rect2, ball_color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	if ball_color.a <= 0.0:
		ball_color = DEFAULT_OBJECT_BALL_COLOR
	var center: Vector2 = icon_rect.get_center()
	var radius: float = _get_preview_radius(icon_rect)
	_draw_ball_base(canvas, center, radius, ball_color, ball_color.darkened(0.42))
	_draw_roll_marks(canvas, center, radius, ball_color)


static func draw_wayfinder_icon(canvas: CanvasItem, icon_rect: Rect2) -> void:
	var center: Vector2 = icon_rect.get_center()
	var radius: float = _get_preview_radius(icon_rect)
	canvas.draw_circle(center, radius * 1.22, Color(WAYFINDER_ACTIVE_GLOW_COLOR.r, WAYFINDER_ACTIVE_GLOW_COLOR.g, WAYFINDER_ACTIVE_GLOW_COLOR.b, 0.15))
	_draw_ball_base(canvas, center, radius, WAYFINDER_BASE_COLOR, WAYFINDER_RING_COLOR)
	_draw_roll_marks(canvas, center, radius, WAYFINDER_BASE_COLOR)
	canvas.draw_arc(center, radius - 3.2, 0.0, TAU, 40, WAYFINDER_RING_COLOR, 1.6, true)
	_draw_wayfinder_mark(canvas, center, radius)


static func draw_powder_keg_icon(canvas: CanvasItem, icon_rect: Rect2) -> void:
	var center: Vector2 = icon_rect.get_center()
	var radius: float = _get_preview_radius(icon_rect)
	_draw_ball_base(canvas, center, radius, POWDER_KEG_BASE_COLOR, POWDER_KEG_BASE_COLOR.darkened(0.45))
	_draw_powder_keg_mark(canvas, center, radius)


static func draw_treasure_icon(canvas: CanvasItem, icon_rect: Rect2) -> void:
	var center: Vector2 = icon_rect.get_center()
	var radius: float = _get_preview_radius(icon_rect)
	canvas.draw_circle(center, radius * 1.12, Color(TREASURE_BALL_GLOW_COLOR.r, TREASURE_BALL_GLOW_COLOR.g, TREASURE_BALL_GLOW_COLOR.b, 0.18))
	_draw_ball_base(canvas, center, radius, TREASURE_BALL_BASE_COLOR, TREASURE_BALL_RIM_COLOR)
	canvas.draw_arc(center, radius - 2.8, 0.0, TAU, 40, TREASURE_BALL_RIM_COLOR, 1.8, true)
	_draw_treasure_mark(canvas, center, radius)


static func draw_cannon_icon(canvas: CanvasItem, icon_rect: Rect2) -> void:
	var center: Vector2 = icon_rect.get_center()
	var radius: float = _get_preview_radius(icon_rect)
	_draw_ball_base(canvas, center, radius, CANNON_BALL_BASE_COLOR, CANNON_BALL_RIM_COLOR)
	canvas.draw_arc(center, radius - 5.0, deg_to_rad(210.0), deg_to_rad(330.0), 18, CANNON_BALL_EDGE_COLOR, 1.4, true)
	for dent_position in [Vector2(-0.24, -0.18), Vector2(0.26, 0.12), Vector2(-0.05, 0.34)]:
		canvas.draw_circle(center + dent_position * radius, radius * 0.12, Color("070809"))


static func draw_embezzler_icon(canvas: CanvasItem, icon_rect: Rect2) -> void:
	var center: Vector2 = icon_rect.get_center()
	var radius: float = _get_preview_radius(icon_rect)
	canvas.draw_circle(center, radius * 1.1, Color(1.0, 0.85, 0.34, 0.16))
	_draw_ball_base(canvas, center, radius, EMBEZZLER_BALL_BASE_COLOR, EMBEZZLER_BALL_RIM_COLOR)
	canvas.draw_arc(center, radius - 2.6, 0.0, TAU, 40, EMBEZZLER_BALL_RIM_COLOR, 1.8, true)
	canvas.draw_rect(
		Rect2(center + Vector2(-radius * 0.44, -radius * 0.32), Vector2(radius * 0.88, radius * 0.30)),
		EMBEZZLER_BALL_MASK_COLOR,
		true
	)
	canvas.draw_circle(center + Vector2(-radius * 0.18, -radius * 0.18), radius * 0.07, EMBEZZLER_BALL_COIN_COLOR)
	canvas.draw_circle(center + Vector2(radius * 0.18, -radius * 0.18), radius * 0.07, EMBEZZLER_BALL_COIN_COLOR)


static func _get_preview_radius(icon_rect: Rect2) -> float:
	return minf(icon_rect.size.x, icon_rect.size.y) * 0.32


static func _draw_ball_base(canvas: CanvasItem, center: Vector2, radius: float, base_color: Color, rim_color: Color) -> void:
	canvas.draw_circle(center + Vector2(1.5, 2.0), radius, BALL_SHADOW)
	canvas.draw_circle(center, radius + 1.2, BALL_OUTER_SHADE)
	canvas.draw_circle(center, radius, base_color)
	canvas.draw_circle(center + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.72, base_color.lightened(0.16))
	canvas.draw_arc(center, radius - 1.0, 0.0, TAU, 40, rim_color, 2.0, true)
	canvas.draw_circle(center + Vector2(-radius * 0.32, -radius * 0.36), radius * 0.22, BALL_HIGHLIGHT)


static func _draw_roll_marks(canvas: CanvasItem, center: Vector2, radius: float, display_color: Color) -> void:
	var mark_color := display_color.lightened(0.2)
	mark_color.a = 0.34
	canvas.draw_arc(center + Vector2(radius * 0.08, radius * 0.02), radius * 0.48, deg_to_rad(205.0), deg_to_rad(332.0), 18, mark_color, 1.1, true)
	canvas.draw_arc(center + Vector2(-radius * 0.08, -radius * 0.02), radius * 0.36, deg_to_rad(28.0), deg_to_rad(148.0), 16, mark_color, 0.9, true)


static func _draw_wayfinder_mark(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	var mark_radius: float = radius * 0.34
	var mark_color := WAYFINDER_RING_COLOR
	canvas.draw_arc(center, mark_radius * 0.92, 0.0, TAU, 28, Color(0.96, 0.84, 0.48, 0.68), 1.1, true)
	canvas.draw_line(
		center + Vector2(0, -mark_radius),
		center + Vector2(0, mark_radius),
		mark_color,
		1.8
	)
	canvas.draw_line(
		center + Vector2(-mark_radius, 0),
		center + Vector2(mark_radius, 0),
		mark_color,
		1.8
	)
	canvas.draw_line(
		center + Vector2(-mark_radius * 0.72, -mark_radius * 0.72),
		center + Vector2(mark_radius * 0.72, mark_radius * 0.72),
		mark_color,
		1.2
	)
	canvas.draw_line(
		center + Vector2(mark_radius * 0.72, -mark_radius * 0.72),
		center + Vector2(-mark_radius * 0.72, mark_radius * 0.72),
		mark_color,
		1.2
	)

	var north_tip := center + Vector2(0, -mark_radius - radius * 0.21)
	var north_left := center + Vector2(-radius * 0.30, -mark_radius * 0.18)
	var north_right := center + Vector2(radius * 0.30, -mark_radius * 0.18)
	canvas.draw_colored_polygon(
		PackedVector2Array([north_tip, north_left, center, north_right]),
		Color(0.96, 0.84, 0.48, 0.9)
	)


static func _draw_powder_keg_mark(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_arc(center + Vector2(0, -radius * 0.28), radius * 0.82, 0.0, TAU, 34, POWDER_KEG_BAND_COLOR, 2.2, true)
	canvas.draw_arc(center + Vector2(0, radius * 0.32), radius * 0.78, 0.0, TAU, 34, POWDER_KEG_BAND_COLOR, 2.0, true)
	canvas.draw_circle(center, radius * 0.15, Color("1e120c"))
	canvas.draw_arc(center, radius * 0.15, 0.0, TAU, 20, POWDER_KEG_BAND_COLOR, 1.0, true)
	canvas.draw_line(
		center + Vector2(radius * 0.18, -radius * 0.62),
		center + Vector2(radius * 0.56, -radius * 1.02),
		POWDER_KEG_FUSE_COLOR,
		2.0
	)
	canvas.draw_circle(center + Vector2(radius * 0.62, -radius * 1.08), 2.4, Color(1.0, 0.76, 0.34, 0.9))


static func _draw_treasure_mark(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	var gem_top := center + Vector2(0.0, -radius * 0.42)
	var gem_right := center + Vector2(radius * 0.46, 0.0)
	var gem_bottom := center + Vector2(0.0, radius * 0.42)
	var gem_left := center + Vector2(-radius * 0.46, 0.0)
	canvas.draw_colored_polygon(
		PackedVector2Array([gem_top, gem_right, gem_bottom, gem_left]),
		TREASURE_BALL_GEM_COLOR
	)
	canvas.draw_polyline(PackedVector2Array([gem_top, gem_right, gem_bottom, gem_left, gem_top]), TREASURE_BALL_RIM_COLOR, 1.2, true)
	canvas.draw_line(gem_left, gem_right, TREASURE_BALL_GLOW_COLOR, 1.1)
	canvas.draw_line(gem_top, gem_bottom, Color(1.0, 0.94, 0.64, 0.72), 1.0)
