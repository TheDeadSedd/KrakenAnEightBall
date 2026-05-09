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

@export var ball_type := BallType.OBJECT
@export_range(0, 15, 1) var ball_number := 1
@export var ball_color := Color("d7b347")
@export var radius := 14.0
@export var rolling_friction := 105.0
@export var stop_threshold := 4.0
@export var medium_speed_drag_start := 140.0
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
@export var spawn_drop_first_bounce_height := 18.0
@export var spawn_drop_second_bounce_height := 7.0
@export var spawn_drop_fall_time := 0.18
@export var spawn_drop_squash_time := 0.06
@export var spawn_drop_bounce_time := 0.09
@export var spawn_drop_second_bounce_time := 0.07
@export var spawn_drop_settle_time := 0.08
@export var spawn_drop_impact_scale := Vector2(1.24, 0.76)
@export var spawn_drop_rebound_scale := Vector2(1.18, 1.18)
@export var spawn_drop_second_bounce_scale := Vector2(1.05, 1.05)
@export var spawn_drop_settle_velocity_min := 18.0
@export var spawn_drop_settle_velocity_max := 48.0

@onready var number_label: Label = $NumberLabel

var velocity := Vector2.ZERO
var gameplay_enabled := true

var _spawn_drop_active := false
var _spawn_drop_elapsed := 0.0
var _spawn_drop_target := Vector2.ZERO
var _spawn_drop_settle_velocity := Vector2.ZERO
var _spawn_drop_visual_offset := Vector2.ZERO
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

	_update_trail(delta)


func setup(new_type: int, new_number: int, new_color: Color) -> void:
	ball_type = new_type
	ball_number = new_number
	ball_color = new_color
	_update_label()
	_update_number_color()
	queue_redraw()


func apply_friction(delta: float) -> void:
	if not gameplay_enabled:
		return

	var speed: float = velocity.length()
	if speed <= 0.0:
		return

	# The earlier low-friction tuning was fun and may fit a chaotic table modifier later.
	var effective_friction: float = _get_effective_friction(speed)
	velocity = velocity.move_toward(Vector2.ZERO, effective_friction * delta)
	if velocity.length() < stop_threshold:
		velocity = Vector2.ZERO


func _get_effective_friction(speed: float) -> float:
	return rolling_friction * _get_speed_drag_multiplier(speed)


func _get_speed_drag_multiplier(speed: float) -> float:
	# Speed bands keep breaks lively while helping slow balls settle cleanly.
	if speed >= medium_speed_drag_start:
		return 1.0

	if speed >= low_speed_drag_start:
		var ratio: float = _inverse_lerp(medium_speed_drag_start, low_speed_drag_start, speed)
		return lerp(1.0, medium_speed_drag_multiplier, ratio)

	if speed >= crawl_speed_drag_start:
		var ratio: float = _inverse_lerp(low_speed_drag_start, crawl_speed_drag_start, speed)
		return lerp(medium_speed_drag_multiplier, low_speed_drag_multiplier, ratio)

	var ratio: float = _inverse_lerp(crawl_speed_drag_start, stop_threshold, speed)
	return lerp(low_speed_drag_multiplier, crawl_speed_drag_multiplier, ratio)


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
	_spawn_drop_active = false
	_spawn_drop_settle_velocity = Vector2.ZERO
	_spawn_drop_visual_offset = Vector2.ZERO
	_trail_points.clear()
	visible = false
	sunk.emit(self)


func respawn_at(new_position: Vector2) -> void:
	visible = true
	global_position = new_position
	scale = Vector2.ONE
	velocity = Vector2.ZERO
	gameplay_enabled = true
	_spawn_drop_active = false
	_spawn_drop_settle_velocity = Vector2.ZERO
	_spawn_drop_visual_offset = Vector2.ZERO
	_reset_trail()


func begin_spawn_drop(final_position: Vector2) -> void:
	visible = true
	velocity = Vector2.ZERO
	gameplay_enabled = false
	_spawn_drop_active = true
	_spawn_drop_elapsed = 0.0
	_spawn_drop_target = final_position
	_spawn_drop_settle_velocity = _get_random_spawn_settle_velocity()
	global_position = final_position
	_spawn_drop_visual_offset = Vector2.UP * spawn_drop_initial_visual_height
	scale = Vector2.ONE * spawn_drop_start_scale
	_update_label_layout()
	_reset_trail()


func _update_spawn_drop(delta: float) -> void:
	_spawn_drop_elapsed += delta

	var fall_end: float = spawn_drop_fall_time
	var squash_end: float = fall_end + spawn_drop_squash_time
	var rebound_end: float = squash_end + spawn_drop_bounce_time
	var second_bounce_end: float = rebound_end + spawn_drop_second_bounce_time
	var settle_end: float = second_bounce_end + spawn_drop_settle_time

	if _spawn_drop_elapsed < fall_end:
		_update_drop_fall(_spawn_drop_elapsed / fall_end)
	elif _spawn_drop_elapsed < squash_end:
		_update_drop_squash((_spawn_drop_elapsed - fall_end) / spawn_drop_squash_time)
	elif _spawn_drop_elapsed < rebound_end:
		_update_drop_rebound((_spawn_drop_elapsed - squash_end) / spawn_drop_bounce_time)
	elif _spawn_drop_elapsed < second_bounce_end:
		_update_drop_second_bounce((_spawn_drop_elapsed - rebound_end) / spawn_drop_second_bounce_time)
	elif _spawn_drop_elapsed < settle_end:
		_update_drop_settle((_spawn_drop_elapsed - second_bounce_end) / spawn_drop_settle_time)
	else:
		_finish_spawn_drop()


func _update_drop_fall(ratio: float) -> void:
	var eased_ratio: float = _smooth_ratio(ratio)
	var height: float = lerp(spawn_drop_initial_visual_height, 0.0, eased_ratio)
	_spawn_drop_visual_offset = Vector2.UP * height
	scale = Vector2.ONE * lerp(spawn_drop_start_scale, 1.0, eased_ratio)
	_update_label_layout()
	queue_redraw()


func _update_drop_squash(ratio: float) -> void:
	global_position = _spawn_drop_target
	_spawn_drop_visual_offset = Vector2.ZERO
	scale = Vector2.ONE.lerp(spawn_drop_impact_scale, _smooth_ratio(ratio))
	_update_label_layout()
	queue_redraw()


func _update_drop_rebound(ratio: float) -> void:
	var height: float = _get_bounce_height(ratio, spawn_drop_first_bounce_height)
	_spawn_drop_visual_offset = Vector2.UP * height
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
	_spawn_drop_visual_offset = Vector2.UP * height
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
	_update_label_layout()
	_reset_trail()


func _smooth_ratio(ratio: float) -> float:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	return clamped_ratio * clamped_ratio * (3.0 - 2.0 * clamped_ratio)


func _get_bounce_height(ratio: float, height: float) -> float:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	return sin(clamped_ratio * PI) * height


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
	if ball_type == BallType.CUE:
		number_label.text = ""
	else:
		number_label.text = str(ball_number)


func _update_number_color() -> void:
	if ball_type == BallType.EIGHT:
		number_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		number_label.add_theme_color_override("font_color", Color("111111"))


func _draw() -> void:
	_draw_trail()

	var origin: Vector2 = _spawn_drop_visual_offset
	var rim_color: Color = ball_color.darkened(0.45)
	var shadow_color: Color = Color(0, 0, 0, 0.22)
	var shine_color: Color = Color(1, 1, 1, 0.34)

	draw_circle(origin + Vector2(1.5, 2.0), radius, shadow_color)
	draw_circle(origin, radius, ball_color)
	draw_circle(origin + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.72, ball_color.lightened(0.16))
	draw_arc(origin, radius - rim_width * 0.5, 0.0, TAU, 40, rim_color, rim_width)

	if ball_type == BallType.OBJECT or ball_type == BallType.EIGHT:
		draw_circle(origin, radius * number_spot_scale, Color.WHITE)
		if ball_type == BallType.EIGHT:
			draw_circle(origin, radius * number_spot_scale * 0.72, Color("151515"))

	draw_circle(origin + Vector2(-radius * 0.32, -radius * 0.36), radius * highlight_scale, shine_color)


func _draw_trail() -> void:
	if not trail_enabled:
		return

	for point in _trail_points:
		var position: Vector2 = to_local(point.position)
		var fade: float = 1.0 - clamp(point.age / trail_lifetime, 0.0, 1.0)
		var dot_color: Color = ball_color.lightened(0.25)
		dot_color.a = 0.34 * fade
		draw_circle(position, trail_dot_radius * fade, dot_color)
