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

@onready var number_label: Label = $NumberLabel

var velocity := Vector2.ZERO


func _ready() -> void:
	_update_label()
	_update_label_layout()
	queue_redraw()


func setup(new_type: int, new_number: int, new_color: Color) -> void:
	ball_type = new_type
	ball_number = new_number
	ball_color = new_color
	_update_label()
	queue_redraw()


func apply_friction(delta: float) -> void:
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
	return velocity.length() >= stop_threshold


func move_ball(delta: float) -> void:
	position += velocity * delta


func sink() -> void:
	velocity = Vector2.ZERO
	visible = false
	sunk.emit(self)


func respawn_at(new_position: Vector2) -> void:
	visible = true
	global_position = new_position
	velocity = Vector2.ZERO


func _update_label_layout() -> void:
	number_label.size = Vector2(radius * 2.0, radius * 2.0)
	number_label.position = Vector2(-radius, -radius - 1.0)


func _update_label() -> void:
	if ball_type == BallType.CUE:
		number_label.text = ""
	else:
		number_label.text = str(ball_number)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, ball_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.3), 2.0)

	if ball_type != BallType.CUE:
		draw_circle(Vector2.ZERO, radius * 0.42, Color.WHITE)

	draw_circle(Vector2(-radius * 0.28, -radius * 0.32), radius * 0.18, Color(1, 1, 1, 0.28))
