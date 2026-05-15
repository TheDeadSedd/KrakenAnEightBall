extends Control
class_name MainMenuPresentationOverlay

# index:title Main Menu Presentation Overlay
# index:category UI / Presentation
# index:status In Progress
# index:owner ui_agent
# index:notes Draw-only title screen atmosphere that can be split across layered main menu artwork.

const MOON_POSITION_RATIO := Vector2(0.420, 0.176)
const OCEAN_START_RATIO := 0.56
const STAR_COUNT := 48
const FOG_BAND_COUNT := 2
const SHIMMER_LINE_COUNT := 16
const WAVE_POINT_COUNT := 48

@export var moon_glow_alpha_multiplier := 3.0
@export var moon_glow_radius_multiplier := 1.28
@export var shimmer_alpha_multiplier := 3.4
@export var shimmer_drift_multiplier := 3.25
@export var shimmer_width_multiplier := 1.45
@export var shimmer_line_width := 3.25
@export var fog_alpha_multiplier := 1.05
@export var fog_drift_multiplier := 2.4
@export var fog_band_height_multiplier := 2.05
@export var fog_center_line_alpha_multiplier := 0.10
@export var star_alpha_multiplier := 2.2
@export var star_radius_multiplier := 1.8
@export var draw_moon_glow_enabled := true
@export var draw_star_twinkles_enabled := true
@export var draw_ocean_shimmer_enabled := true
@export var draw_fog_enabled := true

var animation_time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	animation_time = fposmod(animation_time + delta, 10000.0)
	queue_redraw()


func _draw() -> void:
	var viewport_size: Vector2 = size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	if draw_moon_glow_enabled:
		_draw_moon_glow(viewport_size)
	if draw_star_twinkles_enabled:
		_draw_star_twinkles(viewport_size)
	if draw_ocean_shimmer_enabled:
		_draw_ocean_shimmer(viewport_size)
	if draw_fog_enabled:
		_draw_mist(viewport_size)


func _draw_moon_glow(viewport_size: Vector2) -> void:
	var moon_position: Vector2 = viewport_size * MOON_POSITION_RATIO
	var base_radius: float = minf(viewport_size.x, viewport_size.y) * 0.070 * moon_glow_radius_multiplier
	var pulse: float = 0.5 + sin(animation_time * 0.72) * 0.5
	for ring in range(6, 0, -1):
		var ring_ratio: float = float(ring) / 6.0
		var radius: float = base_radius * (1.0 + ring_ratio * 2.35 + pulse * 0.22)
		var alpha: float = (0.030 + pulse * 0.026) * ring_ratio * moon_glow_alpha_multiplier
		draw_circle(moon_position, radius, Color(0.78, 0.90, 1.0, minf(alpha, 0.42)))


func _draw_ocean_shimmer(viewport_size: Vector2) -> void:
	var ocean_start_y: float = viewport_size.y * OCEAN_START_RATIO
	var reflection_x: float = viewport_size.x * MOON_POSITION_RATIO.x
	for index in range(SHIMMER_LINE_COUNT):
		var depth_ratio: float = float(index) / float(SHIMMER_LINE_COUNT - 1)
		var y: float = ocean_start_y + viewport_size.y * (0.055 + depth_ratio * 0.245)
		var shimmer_phase: float = animation_time * 0.72 + float(index) * 0.82
		var drift: float = sin(shimmer_phase) * viewport_size.x * 0.012 * shimmer_drift_multiplier
		drift += fposmod(animation_time * 18.0 + float(index) * 31.0, viewport_size.x * 0.055) - viewport_size.x * 0.0275
		var width: float = viewport_size.x * (0.040 + depth_ratio * 0.060) * shimmer_width_multiplier
		var alpha: float = 0.050 * (1.0 - depth_ratio * 0.45) + sin(shimmer_phase * 1.7) * 0.018
		var start_position := Vector2(reflection_x - width * 0.5 + drift, y)
		var end_position := Vector2(reflection_x + width * 0.5 + drift, y + sin(shimmer_phase + 1.2) * 1.5)
		draw_line(
			start_position,
			end_position,
			Color(0.86, 0.98, 0.92, minf(maxf(alpha, 0.030) * shimmer_alpha_multiplier, 0.34)),
			shimmer_line_width,
			true
		)


func _draw_mist(viewport_size: Vector2) -> void:
	var base_y: float = viewport_size.y * 0.415
	for band in range(FOG_BAND_COUNT):
		var y: float = base_y + float(band) * viewport_size.y * 0.145
		var phase: float = animation_time * (0.085 + float(band) * 0.014) + float(band) * 2.1
		var alpha: float = (0.028 - float(band) * 0.004) * fog_alpha_multiplier
		var center_points: PackedVector2Array = _make_mist_points(viewport_size, y, phase, band)
		var band_height: float = viewport_size.y * (0.082 + float(band) * 0.020) * fog_band_height_multiplier
		_draw_mist_ribbon(center_points, band_height, Color(0.70, 0.88, 0.88, minf(alpha, 0.052)))
		draw_polyline(
			center_points,
			Color(0.82, 0.96, 0.95, minf(alpha * fog_center_line_alpha_multiplier, 0.006)),
			maxf(18.0, band_height * 0.12),
			true
		)


func _make_mist_points(viewport_size: Vector2, y_base: float, phase: float, band: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var offset_x: float = sin(phase) * viewport_size.x * 0.05 * fog_drift_multiplier
	for point_index in range(WAVE_POINT_COUNT + 1):
		var ratio: float = float(point_index) / float(WAVE_POINT_COUNT)
		var x: float = ratio * viewport_size.x + offset_x - viewport_size.x * 0.025
		var y: float = y_base
		y += sin(ratio * TAU * 1.10 + phase + float(band)) * (8.0 + float(band) * 2.0)
		y += sin(ratio * TAU * 2.35 - phase * 1.2) * 3.0
		points.append(Vector2(x, y))
	return points


func _draw_mist_ribbon(center_points: PackedVector2Array, band_height: float, color: Color) -> void:
	if center_points.size() < 2:
		return

	_draw_mist_ribbon_layer(center_points, band_height * 3.20, Color(color.r, color.g, color.b, color.a * 0.055))
	_draw_mist_ribbon_layer(center_points, band_height * 2.55, Color(color.r, color.g, color.b, color.a * 0.090))
	_draw_mist_ribbon_layer(center_points, band_height * 1.90, Color(color.r, color.g, color.b, color.a * 0.145))
	_draw_mist_ribbon_layer(center_points, band_height * 1.25, Color(color.r, color.g, color.b, color.a * 0.210))
	_draw_mist_ribbon_layer(center_points, band_height * 0.72, Color(color.r, color.g, color.b, color.a * 0.255))


func _draw_mist_ribbon_layer(center_points: PackedVector2Array, band_height: float, color: Color) -> void:
	var top_points := PackedVector2Array()
	var bottom_points := PackedVector2Array()
	for point in center_points:
		top_points.append(point - Vector2(0.0, band_height * 0.5))
		bottom_points.append(point + Vector2(0.0, band_height * 0.5))

	var polygon := PackedVector2Array()
	for point in top_points:
		polygon.append(point)
	for index in range(bottom_points.size() - 1, -1, -1):
		polygon.append(bottom_points[index])
	draw_colored_polygon(polygon, color)


func _draw_star_twinkles(viewport_size: Vector2) -> void:
	for index in range(STAR_COUNT):
		var x_ratio: float = fposmod(float(index * 139), 1000.0) / 1000.0
		var y_ratio: float = 0.035 + fposmod(float(index * 71), 330.0) / 1000.0
		if _is_near_moon(Vector2(x_ratio, y_ratio)):
			continue

		var twinkle: float = 0.5 + sin(animation_time * 0.85 + float(index) * 1.61) * 0.5
		if twinkle < 0.50:
			continue

		var radius: float = (1.05 + fposmod(float(index * 17), 9.0) * 0.075) * star_radius_multiplier
		var alpha: float = (0.14 + twinkle * 0.28) * star_alpha_multiplier
		draw_circle(
			Vector2(x_ratio * viewport_size.x, y_ratio * viewport_size.y),
			radius,
			Color(0.84, 0.96, 1.0, minf(alpha, 0.82))
		)


func _is_near_moon(star_ratio: Vector2) -> bool:
	return star_ratio.distance_to(MOON_POSITION_RATIO) < 0.15
