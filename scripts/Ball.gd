extends Node2D
class_name Ball

signal sunk(ball: Ball)

class TrailPoint:
	var position := Vector2.ZERO
	var age := 0.0

enum BallType {
	OBJECT,
	CUE,
	EIGHT,
}

# Wayfinder visuals.
const WAYFINDER_BASE_COLOR := Color("2f9f96")
const WAYFINDER_MARK_COLOR := Color("f3d27a")
const WAYFINDER_ACTIVE_GLOW_COLOR := Color("8ef7ea")
const WAYFINDER_RING_COLOR := Color("173d3a")
const DEBUG_WAYFINDER := false

@export var ball_type := BallType.OBJECT
@export_range(0, 15, 1) var ball_number := 1
@export var ball_color := Color("d7b347")
@export var radius := 14.0
@export var rolling_friction := 105.0
@export var stop_threshold := 4.0
@export var medium_speed_drag_start := 140.0
@export var high_speed_drag_multiplier := 1.22
@export var medium_speed_drag_multiplier := 1.15
@export var low_speed_drag_start := 60.0
@export var low_speed_drag_multiplier := 1.8
@export var crawl_speed_drag_start := 22.0
@export var crawl_speed_drag_multiplier := 3.0
@export var rim_width := 2.0
@export var number_spot_scale := 0.48
@export var highlight_scale := 0.22
@export var trail_enabled := true
@export var trail_speed_threshold := 18.0
@export var trail_point_spacing := 9.0
@export var trail_lifetime := 0.60
@export var trail_dot_radius := 2.5
@export var spawn_drop_start_scale := 3.35
@export var spawn_drop_initial_visual_height := 64.0
@export var spawn_drop_first_bounce_height := 44.0
@export var spawn_drop_second_bounce_height := 16.0
@export var spawn_drop_fall_time := 0.18
@export var spawn_drop_squash_time := 0.06
@export var spawn_drop_impact_hold_time := 0.045
@export var spawn_drop_bounce_time := 0.19
@export var spawn_drop_second_bounce_time := 0.11
@export var spawn_drop_settle_time := 0.08
@export var spawn_drop_impact_scale := Vector2(1.24, 0.76)
@export var spawn_drop_rebound_scale := Vector2(1.30, 1.30)
@export var spawn_drop_second_bounce_scale := Vector2(1.08, 1.08)
@export var spawn_drop_settle_velocity_min := 110.0
@export var spawn_drop_settle_velocity_max := 220.0
@export var spawn_landing_damping_duration := 0.48
@export var spawn_landing_damping_multiplier := 4.2
@export var spawn_drop_visual_lean := 12.0
@export var spawn_drop_horizontal_offset_min := 140.0
@export var spawn_drop_horizontal_offset_max := 280.0

@onready var number_label: Label = $NumberLabel

var velocity := Vector2.ZERO
var gameplay_enabled := true
# Wayfinder state stays intentionally small: anomaly identity plus current activation.
var is_wayfinder := false
var wayfinder_active := false

var _spawn_drop_active := false
var _spawn_drop_elapsed := 0.0
var _spawn_drop_target := Vector2.ZERO
var _spawn_drop_settle_velocity := Vector2.ZERO
var _spawn_drop_visual_offset := Vector2.ZERO
var _spawn_drop_visual_lean_direction := Vector2.ZERO
var _spawn_drop_horizontal_offset := Vector2.ZERO
var _spawn_landing_damping_remaining := 0.0
var _trail_points: Array[TrailPoint] = []
var _last_trail_position := Vector2.ZERO


func _ready() -> void:
	_update_label()
	_update_number_color()
	_update_label_layout()
	_last_trail_position = global_position
	queue_redraw()


func _process(delta: float) -> void:
	if _spawn_drop_active:
		_update_spawn_drop(delta)

	if is_wayfinder and wayfinder_active and gameplay_enabled:
		queue_redraw()

	_update_trail(delta)


func setup(new_type: int, new_number: int, new_color: Color, new_is_wayfinder: bool = false) -> void:
	ball_type = new_type
	ball_number = new_number
	ball_color = new_color
	is_wayfinder = new_is_wayfinder
	_reset_wayfinder_state()
	_update_label()
	_update_number_color()
	_update_label_layout()
	queue_redraw()


func apply_friction(delta: float) -> void:
	if not gameplay_enabled:
		return

	var speed: float = velocity.length()
	if speed <= 0.0:
		return

	# Layered drag keeps fast shots lively while helping slow balls settle.
	var effective_friction: float = _get_effective_friction(speed)
	effective_friction *= _get_spawn_landing_damping_multiplier(delta)
	velocity = velocity.move_toward(Vector2.ZERO, effective_friction * delta)
	if velocity.length() < stop_threshold:
		velocity = Vector2.ZERO
		if is_wayfinder and wayfinder_active:
			deactivate_wayfinder("stopped")


func _get_effective_friction(speed: float) -> float:
	return rolling_friction * _get_speed_drag_multiplier(speed)


func _get_speed_drag_multiplier(speed: float) -> float:
	# Speed bands keep breaks lively while helping slow balls settle cleanly.
	if speed >= medium_speed_drag_start:
		return high_speed_drag_multiplier

	if speed >= low_speed_drag_start:
		var ratio: float = _inverse_lerp(medium_speed_drag_start, low_speed_drag_start, speed)
		return lerp(1.0, medium_speed_drag_multiplier, ratio)

	if speed >= crawl_speed_drag_start:
		var ratio: float = _inverse_lerp(low_speed_drag_start, crawl_speed_drag_start, speed)
		return lerp(medium_speed_drag_multiplier, low_speed_drag_multiplier, ratio)

	var ratio: float = _inverse_lerp(crawl_speed_drag_start, stop_threshold, speed)
	return lerp(low_speed_drag_multiplier, crawl_speed_drag_multiplier, ratio)


func _get_spawn_landing_damping_multiplier(delta: float) -> float:
	if _spawn_landing_damping_remaining <= 0.0:
		return 1.0

	var ratio: float = _spawn_landing_damping_remaining / spawn_landing_damping_duration
	_spawn_landing_damping_remaining = max(_spawn_landing_damping_remaining - delta, 0.0)
	return lerp(1.0, spawn_landing_damping_multiplier, ratio)


func _inverse_lerp(start: float, end: float, value: float) -> float:
	if is_equal_approx(start, end):
		return 0.0

	return clamp((value - start) / (end - start), 0.0, 1.0)


func is_moving() -> bool:
	return _spawn_drop_active or velocity.length() >= stop_threshold


func is_gameplay_active() -> bool:
	return visible and gameplay_enabled


func get_safe_position() -> Vector2:
	if _spawn_drop_active:
		return _spawn_drop_target

	return global_position


func move_ball(delta: float) -> void:
	if not gameplay_enabled:
		return

	position += velocity * delta


func sink() -> void:
	velocity = Vector2.ZERO
	gameplay_enabled = false
	_reset_wayfinder_state()
	_spawn_drop_active = false
	_spawn_drop_settle_velocity = Vector2.ZERO
	_spawn_drop_visual_offset = Vector2.ZERO
	_spawn_drop_visual_lean_direction = Vector2.ZERO
	_spawn_drop_horizontal_offset = Vector2.ZERO
	_spawn_landing_damping_remaining = 0.0
	_trail_points.clear()
	visible = false
	sunk.emit(self)


func respawn_at(new_position: Vector2) -> void:
	visible = true
	global_position = new_position
	scale = Vector2.ONE
	velocity = Vector2.ZERO
	gameplay_enabled = true
	_reset_wayfinder_state()
	_spawn_drop_active = false
	_spawn_drop_settle_velocity = Vector2.ZERO
	_spawn_drop_visual_offset = Vector2.ZERO
	_spawn_drop_visual_lean_direction = Vector2.ZERO
	_spawn_drop_horizontal_offset = Vector2.ZERO
	_spawn_landing_damping_remaining = 0.0
	_reset_trail()


func begin_spawn_drop(final_position: Vector2) -> void:
	visible = true
	velocity = Vector2.ZERO
	gameplay_enabled = false
	_reset_wayfinder_state()
	_spawn_drop_active = true
	_spawn_drop_elapsed = 0.0
	_spawn_drop_target = final_position
	_spawn_drop_settle_velocity = _get_random_spawn_settle_velocity()
	_spawn_drop_visual_lean_direction = _spawn_drop_settle_velocity.normalized()
	_spawn_drop_horizontal_offset = _get_drop_horizontal_offset(_spawn_drop_visual_lean_direction)
	global_position = final_position
	_spawn_drop_visual_offset = Vector2.UP * spawn_drop_initial_visual_height + _spawn_drop_horizontal_offset
	scale = Vector2.ONE * spawn_drop_start_scale
	_update_label_layout()
	_reset_trail()


func _update_spawn_drop(delta: float) -> void:
	_spawn_drop_elapsed += delta

	var fall_end: float = spawn_drop_fall_time
	var squash_end: float = fall_end + spawn_drop_squash_time
	var impact_hold_end: float = squash_end + spawn_drop_impact_hold_time
	var rebound_end: float = impact_hold_end + spawn_drop_bounce_time
	var second_bounce_end: float = rebound_end + spawn_drop_second_bounce_time
	var settle_end: float = second_bounce_end + spawn_drop_settle_time

	if _spawn_drop_elapsed < fall_end:
		_update_drop_fall(_spawn_drop_elapsed / fall_end)
	elif _spawn_drop_elapsed < squash_end:
		_update_drop_squash((_spawn_drop_elapsed - fall_end) / spawn_drop_squash_time)
	elif _spawn_drop_elapsed < impact_hold_end:
		_update_drop_impact_hold()
	elif _spawn_drop_elapsed < rebound_end:
		_update_drop_rebound((_spawn_drop_elapsed - impact_hold_end) / spawn_drop_bounce_time)
	elif _spawn_drop_elapsed < second_bounce_end:
		_update_drop_second_bounce((_spawn_drop_elapsed - rebound_end) / spawn_drop_second_bounce_time)
	elif _spawn_drop_elapsed < settle_end:
		_update_drop_settle((_spawn_drop_elapsed - second_bounce_end) / spawn_drop_settle_time)
	else:
		_finish_spawn_drop()


func _update_drop_fall(ratio: float) -> void:
	var eased_ratio: float = _smooth_ratio(ratio)
	var height: float = lerp(spawn_drop_initial_visual_height, 0.0, eased_ratio)
	var horizontal_offset: Vector2 = _spawn_drop_horizontal_offset.lerp(Vector2.ZERO, eased_ratio)
	_spawn_drop_visual_offset = Vector2.UP * height + horizontal_offset
	scale = Vector2.ONE * lerp(spawn_drop_start_scale, 1.0, eased_ratio)
	_update_label_layout()
	queue_redraw()


func _update_drop_squash(ratio: float) -> void:
	global_position = _spawn_drop_target
	_spawn_drop_visual_offset = Vector2.ZERO
	scale = Vector2.ONE.lerp(spawn_drop_impact_scale, _smooth_ratio(ratio))
	_update_label_layout()
	queue_redraw()


func _update_drop_impact_hold() -> void:
	_spawn_drop_visual_offset = Vector2.ZERO
	scale = spawn_drop_impact_scale
	_update_label_layout()
	queue_redraw()


func _update_drop_rebound(ratio: float) -> void:
	var height: float = _get_weighted_bounce_height(ratio, spawn_drop_first_bounce_height)
	_spawn_drop_visual_offset = Vector2.UP * height + _get_visual_lean_offset(ratio, 1.0)
	scale = spawn_drop_impact_scale.lerp(spawn_drop_rebound_scale, _smooth_ratio(ratio))
	_update_label_layout()
	queue_redraw()


func _update_drop_settle(ratio: float) -> void:
	_spawn_drop_visual_offset = Vector2.ZERO
	scale = spawn_drop_second_bounce_scale.lerp(Vector2.ONE, _smooth_ratio(ratio))
	_update_label_layout()
	queue_redraw()


func _update_drop_second_bounce(ratio: float) -> void:
	var height: float = _get_bounce_height(ratio, spawn_drop_second_bounce_height)
	_spawn_drop_visual_offset = Vector2.UP * height + _get_visual_lean_offset(ratio, 0.45)
	scale = spawn_drop_rebound_scale.lerp(spawn_drop_second_bounce_scale, _smooth_ratio(ratio))
	_update_label_layout()
	queue_redraw()


func _finish_spawn_drop() -> void:
	global_position = _spawn_drop_target
	scale = Vector2.ONE
	_spawn_drop_visual_offset = Vector2.ZERO
	velocity = _spawn_drop_settle_velocity
	gameplay_enabled = true
	_spawn_drop_active = false
	_spawn_drop_settle_velocity = Vector2.ZERO
	_spawn_drop_visual_lean_direction = Vector2.ZERO
	_spawn_drop_horizontal_offset = Vector2.ZERO
	_spawn_landing_damping_remaining = spawn_landing_damping_duration
	_update_label_layout()
	_reset_trail()


func _smooth_ratio(ratio: float) -> float:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	return clamped_ratio * clamped_ratio * (3.0 - 2.0 * clamped_ratio)


func _get_bounce_height(ratio: float, height: float) -> float:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	return sin(clamped_ratio * PI) * height


func _get_weighted_bounce_height(ratio: float, height: float) -> float:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	var bounce_arc: float = sin(clamped_ratio * PI)
	var hang_time: float = sin(clamped_ratio * PI) * 0.22
	return min(bounce_arc + hang_time, 1.0) * height


func _get_visual_lean_offset(ratio: float, strength: float) -> Vector2:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	var arc_amount: float = sin(clamped_ratio * PI) * spawn_drop_visual_lean * strength
	return _spawn_drop_visual_lean_direction * arc_amount


func _get_drop_horizontal_offset(direction: Vector2) -> Vector2:
	var distance: float = randf_range(spawn_drop_horizontal_offset_min, spawn_drop_horizontal_offset_max)
	return -direction * distance


func _get_random_spawn_settle_velocity() -> Vector2:
	var speed: float = randf_range(spawn_drop_settle_velocity_min, spawn_drop_settle_velocity_max)
	var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	return direction * speed


func _update_trail(delta: float) -> void:
	if not trail_enabled:
		if not _trail_points.is_empty():
			_trail_points.clear()
			queue_redraw()
		return

	_age_trail_points(delta)
	_try_add_trail_point()

	if not _trail_points.is_empty():
		queue_redraw()


func _age_trail_points(delta: float) -> void:
	for point in _trail_points:
		point.age += delta

	_trail_points = _trail_points.filter(_is_trail_point_alive)


func _is_trail_point_alive(point: TrailPoint) -> bool:
	return point.age < trail_lifetime


func _try_add_trail_point() -> void:
	if not visible or not gameplay_enabled:
		return

	if velocity.length() < trail_speed_threshold:
		_last_trail_position = global_position
		return

	if global_position.distance_to(_last_trail_position) < trail_point_spacing:
		return

	var trail_point: TrailPoint = TrailPoint.new()
	trail_point.position = global_position
	_trail_points.append(trail_point)
	_last_trail_position = global_position


func _reset_trail() -> void:
	_trail_points.clear()
	_last_trail_position = global_position
	queue_redraw()


func _update_label_layout() -> void:
	number_label.size = Vector2(radius * 2.0, radius * 2.0)
	number_label.position = _spawn_drop_visual_offset + Vector2(-radius, -radius - 1.0)


func _update_label() -> void:
	if ball_type == BallType.CUE or is_wayfinder:
		number_label.text = ""
	else:
		number_label.text = str(ball_number)


func _update_number_color() -> void:
	if is_wayfinder:
		number_label.add_theme_color_override("font_color", Color("082522"))
	elif ball_type == BallType.EIGHT:
		number_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		number_label.add_theme_color_override("font_color", Color("111111"))


func activate_wayfinder(debug_context: String = "") -> void:
	if not is_wayfinder:
		return

	if not wayfinder_active:
		var debug_message := "activated"
		if not debug_context.is_empty():
			debug_message += " | %s" % debug_context
		_print_wayfinder_debug(debug_message)

	wayfinder_active = true
	queue_redraw()


func deactivate_wayfinder(reason: String = "") -> void:
	if not is_wayfinder:
		return

	if wayfinder_active:
		var debug_reason := reason if not reason.is_empty() else "manual"
		_print_wayfinder_debug("deactivated (%s)" % debug_reason)

	wayfinder_active = false
	queue_redraw()


func _reset_wayfinder_state() -> void:
	if is_wayfinder and wayfinder_active:
		_print_wayfinder_debug("deactivated (reset)")

	wayfinder_active = false


func _print_wayfinder_debug(message: String) -> void:
	if not DEBUG_WAYFINDER:
		return

	print("Wayfinder | #%s | %s" % [ball_number, message])


func _draw() -> void:
	_draw_trail()

	var origin: Vector2 = _spawn_drop_visual_offset
	var display_color: Color = _get_display_color()
	var rim_color: Color = display_color.darkened(0.45)
	var shadow_color: Color = Color(0, 0, 0, 0.22)
	var shine_color: Color = Color(1, 1, 1, 0.34)

	if is_wayfinder:
		_draw_wayfinder_aura(origin)

	draw_circle(origin + Vector2(1.5, 2.0), radius, shadow_color)
	draw_circle(origin, radius + 1.2, Color(0, 0, 0, 0.12))
	draw_circle(origin, radius, display_color)
	draw_circle(origin + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.72, display_color.lightened(0.16))
	draw_arc(origin, radius - rim_width * 0.5, 0.0, TAU, 40, rim_color, rim_width)

	if not is_wayfinder and (ball_type == BallType.OBJECT or ball_type == BallType.EIGHT):
		var number_spot_color := Color.WHITE
		draw_circle(origin, radius * number_spot_scale, number_spot_color)
		draw_arc(
			origin,
			radius * number_spot_scale,
			0.0,
			TAU,
			30,
			Color(0.14, 0.08, 0.05, 0.28),
			1.2
		)
		if ball_type == BallType.EIGHT:
			draw_circle(origin, radius * number_spot_scale * 0.72, Color("151515"))

	if is_wayfinder:
		draw_arc(origin, radius - 3.2, 0.0, TAU, 40, WAYFINDER_RING_COLOR, 1.6)
		_draw_wayfinder_mark(origin)

	draw_circle(origin + Vector2(-radius * 0.32, -radius * 0.36), radius * highlight_scale, shine_color)


func _get_display_color() -> Color:
	if not is_wayfinder:
		return ball_color

	if wayfinder_active:
		return WAYFINDER_BASE_COLOR.lightened(0.18)

	return WAYFINDER_BASE_COLOR


func _draw_wayfinder_mark(origin: Vector2) -> void:
	var mark_radius: float = radius * 0.34
	var mark_color := WAYFINDER_RING_COLOR
	draw_arc(origin, mark_radius * 0.92, 0.0, TAU, 28, Color(0.96, 0.84, 0.48, 0.68), 1.1)
	draw_line(
		origin + Vector2(0, -mark_radius),
		origin + Vector2(0, mark_radius),
		mark_color,
		1.8
	)
	draw_line(
		origin + Vector2(-mark_radius, 0),
		origin + Vector2(mark_radius, 0),
		mark_color,
		1.8
	)
	draw_line(
		origin + Vector2(-mark_radius * 0.72, -mark_radius * 0.72),
		origin + Vector2(mark_radius * 0.72, mark_radius * 0.72),
		mark_color,
		1.2
	)
	draw_line(
		origin + Vector2(mark_radius * 0.72, -mark_radius * 0.72),
		origin + Vector2(-mark_radius * 0.72, mark_radius * 0.72),
		mark_color,
		1.2
	)

	var north_tip := origin + Vector2(0, -mark_radius - 3.0)
	var north_left := origin + Vector2(-4.2, -mark_radius * 0.18)
	var north_right := origin + Vector2(4.2, -mark_radius * 0.18)
	draw_colored_polygon(
		PackedVector2Array([north_tip, north_left, origin, north_right]),
		Color(0.96, 0.84, 0.48, 0.9)
	)


func _draw_wayfinder_aura(origin: Vector2) -> void:
	var aura_alpha: float = 0.18
	var aura_radius: float = radius + 2.0
	if wayfinder_active:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 140.0)
		aura_alpha = 0.34 + pulse * 0.18
		aura_radius = radius + 3.8 + pulse * 2.8
	else:
		aura_alpha = 0.16
		aura_radius = radius + 1.8

	var aura_color: Color = WAYFINDER_ACTIVE_GLOW_COLOR
	aura_color.a = aura_alpha
	draw_arc(origin, aura_radius, 0.0, TAU, 42, aura_color, 2.4)
	if wayfinder_active:
		var inner_glow: Color = WAYFINDER_MARK_COLOR
		inner_glow.a = 0.22
		draw_arc(origin, aura_radius - 4.0, 0.0, TAU, 32, inner_glow, 1.4)


func _draw_trail() -> void:
	if not trail_enabled:
		return

	for point in _trail_points:
		var position: Vector2 = to_local(point.position)
		var fade: float = 1.0 - clamp(point.age / trail_lifetime, 0.0, 1.0)
		var dot_color: Color = ball_color.lightened(0.25)
		dot_color.a = 0.34 * fade
		draw_circle(position, trail_dot_radius * fade, dot_color)
