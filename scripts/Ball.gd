extends Node2D
class_name Ball

signal sunk(ball: Ball)

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
@export var spawn_drop_start_scale := 2.6
@export var spawn_drop_lift := 36.0
@export var spawn_drop_fall_time := 0.18
@export var spawn_drop_squash_time := 0.06
@export var spawn_drop_rebound_time := 0.07
@export var spawn_drop_settle_time := 0.08
@export var spawn_drop_squash_scale := Vector2(1.18, 0.82)
@export var spawn_drop_rebound_scale := Vector2(0.92, 1.08)

@onready var number_label: Label = $NumberLabel

var velocity := Vector2.ZERO
var gameplay_enabled := true

var _spawn_drop_active := false
var _spawn_drop_elapsed := 0.0
var _spawn_drop_target := Vector2.ZERO


func _ready() -> void:
	_update_label()
	_update_number_color()
	_update_label_layout()
	queue_redraw()


func _process(delta: float) -> void:
	if _spawn_drop_active:
		_update_spawn_drop(delta)


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
	visible = false
	sunk.emit(self)


func respawn_at(new_position: Vector2) -> void:
	visible = true
	global_position = new_position
	scale = Vector2.ONE
	velocity = Vector2.ZERO
	gameplay_enabled = true
	_spawn_drop_active = false


func begin_spawn_drop(final_position: Vector2) -> void:
	visible = true
	velocity = Vector2.ZERO
	gameplay_enabled = false
	_spawn_drop_active = true
	_spawn_drop_elapsed = 0.0
	_spawn_drop_target = final_position
	global_position = final_position + Vector2.UP * spawn_drop_lift
	scale = Vector2.ONE * spawn_drop_start_scale


func _update_spawn_drop(delta: float) -> void:
	_spawn_drop_elapsed += delta

	var fall_end: float = spawn_drop_fall_time
	var squash_end: float = fall_end + spawn_drop_squash_time
	var rebound_end: float = squash_end + spawn_drop_rebound_time
	var settle_end: float = rebound_end + spawn_drop_settle_time

	if _spawn_drop_elapsed < fall_end:
		_update_drop_fall(_spawn_drop_elapsed / fall_end)
	elif _spawn_drop_elapsed < squash_end:
		_update_drop_squash((_spawn_drop_elapsed - fall_end) / spawn_drop_squash_time)
	elif _spawn_drop_elapsed < rebound_end:
		_update_drop_rebound((_spawn_drop_elapsed - squash_end) / spawn_drop_rebound_time)
	elif _spawn_drop_elapsed < settle_end:
		_update_drop_settle((_spawn_drop_elapsed - rebound_end) / spawn_drop_settle_time)
	else:
		_finish_spawn_drop()


func _update_drop_fall(ratio: float) -> void:
	var eased_ratio: float = _smooth_ratio(ratio)
	var lift: float = lerp(spawn_drop_lift, 0.0, eased_ratio)
	global_position = _spawn_drop_target + Vector2.UP * lift
	scale = Vector2.ONE * lerp(spawn_drop_start_scale, 1.0, eased_ratio)


func _update_drop_squash(ratio: float) -> void:
	global_position = _spawn_drop_target
	scale = Vector2.ONE.lerp(spawn_drop_squash_scale, _smooth_ratio(ratio))


func _update_drop_rebound(ratio: float) -> void:
	scale = spawn_drop_squash_scale.lerp(spawn_drop_rebound_scale, _smooth_ratio(ratio))


func _update_drop_settle(ratio: float) -> void:
	scale = spawn_drop_rebound_scale.lerp(Vector2.ONE, _smooth_ratio(ratio))


func _finish_spawn_drop() -> void:
	global_position = _spawn_drop_target
	scale = Vector2.ONE
	gameplay_enabled = true
	_spawn_drop_active = false


func _smooth_ratio(ratio: float) -> float:
	var clamped_ratio: float = clamp(ratio, 0.0, 1.0)
	return clamped_ratio * clamped_ratio * (3.0 - 2.0 * clamped_ratio)


func _update_label_layout() -> void:
	number_label.size = Vector2(radius * 2.0, radius * 2.0)
	number_label.position = Vector2(-radius, -radius - 1.0)


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
	var rim_color: Color = ball_color.darkened(0.45)
	var shadow_color: Color = Color(0, 0, 0, 0.22)
	var shine_color: Color = Color(1, 1, 1, 0.34)

	draw_circle(Vector2(1.5, 2.0), radius, shadow_color)
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_circle(Vector2(-radius * 0.18, -radius * 0.22), radius * 0.72, ball_color.lightened(0.16))
	draw_arc(Vector2.ZERO, radius - rim_width * 0.5, 0.0, TAU, 40, rim_color, rim_width)

	if ball_type == BallType.OBJECT or ball_type == BallType.EIGHT:
		draw_circle(Vector2.ZERO, radius * number_spot_scale, Color.WHITE)
		if ball_type == BallType.EIGHT:
			draw_circle(Vector2.ZERO, radius * number_spot_scale * 0.72, Color("151515"))

	draw_circle(Vector2(-radius * 0.32, -radius * 0.36), radius * highlight_scale, shine_color)
