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
const POWDER_KEG_BASE_COLOR := Color("7b4723")
const POWDER_KEG_BAND_COLOR := Color("e0b15e")
const POWDER_KEG_STAVE_COLOR := Color("4a2714")
const POWDER_KEG_FUSE_COLOR := Color("f6d07c")
const ANCHOR_BALL_BASE_COLOR := Color("2a343a")
const ANCHOR_BALL_RIM_COLOR := Color("0f171b")
const ANCHOR_BALL_MARK_COLOR := Color("9db0ae")
const ANCHOR_BALL_CURRENT_COLOR := Color("70a9b4")
const ANCHOR_BALL_MIST_COLOR := Color("173b42")
const ANCHOR_INFLUENCE_COLOR := Color("8ff7e4")
const ANCHOR_INFLUENCE_WAKE_COLOR := Color("d3fff8")
const ANCHOR_INFLUENCE_FADE_TIME := 0.18
const ANCHOR_INFLUENCE_RELEASE_STRENGTH := 0.22
const CANNON_BALL_BASE_COLOR := Color("17191b")
const CANNON_BALL_RIM_COLOR := Color("050607")
const CANNON_BALL_DENT_COLOR := Color("070809")
const CANNON_BALL_EDGE_COLOR := Color("3a3f42")
const CANNON_BALL_EMBER_COLOR := Color("ff8a2d")
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
var is_powder_keg := false
var is_anchor_ball := false
var is_cannon_ball := false
var anchor_visual_effect_strength := 0.7
var anchor_field_visual_radius := 230.0
var anchor_visuals_enabled := true
var anchor_field_visual_enabled := true

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
var _trail_suppression_remaining := 0.0
var _trail_redraws_this_frame := 0
var _anchor_influence_visual_strength := 0.0
var _anchor_influence_fade_remaining := 0.0
var _anchor_influence_direction := Vector2.ZERO


func _ready() -> void:
	_update_label()
	_update_number_color()
	_update_label_layout()
	_last_trail_position = global_position
	queue_redraw()


func _exit_tree() -> void:
	_clear_anchor_influence_visual()


func _process(delta: float) -> void:
	if _spawn_drop_active:
		_update_spawn_drop(delta)

	_update_anchor_influence_visual(delta)

	if is_wayfinder and wayfinder_active and gameplay_enabled:
		queue_redraw()
	elif (
		is_anchor_ball
		and gameplay_enabled
		and visible
		and anchor_visuals_enabled
		and anchor_field_visual_enabled
		and anchor_visual_effect_strength > 0.0
	):
		queue_redraw()

	_update_trail(delta)


func suppress_trail_for(duration: float) -> void:
	_trail_suppression_remaining = max(_trail_suppression_remaining, duration)
	if not _trail_points.is_empty():
		_trail_points.clear()
		_queue_trail_redraw()
	_last_trail_position = global_position


func note_anchor_influence(strength: float, pull_direction: Vector2) -> void:
	if not visible or not gameplay_enabled:
		return
	if not anchor_visuals_enabled:
		_clear_anchor_influence_visual()
		return

	var clamped_strength: float = clamp(strength, 0.34, 1.0)
	_anchor_influence_visual_strength = max(_anchor_influence_visual_strength, clamped_strength)
	_anchor_influence_fade_remaining = ANCHOR_INFLUENCE_FADE_TIME
	if pull_direction.length_squared() > 0.001:
		_anchor_influence_direction = pull_direction.normalized()
	queue_redraw()


func release_anchor_influence_marker() -> void:
	if _anchor_influence_visual_strength <= 0.0:
		return

	if not visible or not gameplay_enabled or not anchor_visuals_enabled or not is_moving():
		_clear_anchor_influence_visual()
		return

	_anchor_influence_fade_remaining = 0.0
	_anchor_influence_visual_strength = min(_anchor_influence_visual_strength, ANCHOR_INFLUENCE_RELEASE_STRENGTH)
	queue_redraw()


func clear_anchor_influence_marker() -> void:
	_clear_anchor_influence_visual()


func set_anchor_visuals_enabled(enabled: bool) -> void:
	if anchor_visuals_enabled == enabled:
		return

	anchor_visuals_enabled = enabled
	if not anchor_visuals_enabled:
		_clear_anchor_influence_visual()
	queue_redraw()


func set_anchor_field_visual_enabled(enabled: bool) -> void:
	if anchor_field_visual_enabled == enabled:
		return

	anchor_field_visual_enabled = enabled
	queue_redraw()


func is_anchor_visual_node_active() -> bool:
	return is_anchor_field_visual_drawn() or is_anchor_influence_marker_active()


func is_anchor_field_visual_drawn() -> bool:
	return (
		is_anchor_ball
		and visible
		and gameplay_enabled
		and anchor_visuals_enabled
		and anchor_field_visual_enabled
	)


func is_anchor_influence_marker_active() -> bool:
	return (
		visible
		and gameplay_enabled
		and anchor_visuals_enabled
		and is_moving()
		and _anchor_influence_visual_strength > 0.0
	)


func get_trail_point_count() -> int:
	return _trail_points.size()


func get_trail_redraw_count() -> int:
	return _trail_redraws_this_frame


func reset_trail_redraw_count() -> void:
	_trail_redraws_this_frame = 0


func setup(
	new_type: int,
	new_number: int,
	new_color: Color,
	new_is_wayfinder: bool = false,
	new_is_powder_keg: bool = false,
	new_is_anchor_ball: bool = false,
	new_is_cannon_ball: bool = false
) -> void:
	ball_type = new_type
	ball_number = new_number
	ball_color = new_color
	is_wayfinder = new_is_wayfinder
	is_powder_keg = new_is_powder_keg
	is_anchor_ball = new_is_anchor_ball
	is_cannon_ball = new_is_cannon_ball
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
	_trail_suppression_remaining = 0.0
	_trail_points.clear()
	visible = false
	_clear_anchor_influence_visual()
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
	_trail_suppression_remaining = 0.0
	_clear_anchor_influence_visual()
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
	_clear_anchor_influence_visual()


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
	if _trail_suppression_remaining > 0.0:
		_trail_suppression_remaining = max(_trail_suppression_remaining - delta, 0.0)
		_last_trail_position = global_position
		if not _trail_points.is_empty():
			_trail_points.clear()
			_queue_trail_redraw()
		return

	if not trail_enabled:
		if not _trail_points.is_empty():
			_trail_points.clear()
			_queue_trail_redraw()
		return

	if _trail_points.is_empty() and _is_below_trail_speed():
		_last_trail_position = global_position
		return

	_age_trail_points(delta)
	_try_add_trail_point()

	if not _trail_points.is_empty():
		_queue_trail_redraw()


func _age_trail_points(delta: float) -> void:
	for point in _trail_points:
		point.age += delta

	_trail_points = _trail_points.filter(_is_trail_point_alive)


func _is_trail_point_alive(point: TrailPoint) -> bool:
	return point.age < trail_lifetime


func _try_add_trail_point() -> void:
	if not visible or not gameplay_enabled:
		return

	if _is_below_trail_speed():
		_last_trail_position = global_position
		return

	if global_position.distance_to(_last_trail_position) < trail_point_spacing:
		return

	var trail_point: TrailPoint = TrailPoint.new()
	trail_point.position = global_position
	_trail_points.append(trail_point)
	_last_trail_position = global_position


func _is_below_trail_speed() -> bool:
	return velocity.length() < trail_speed_threshold


func _reset_trail() -> void:
	_trail_points.clear()
	_last_trail_position = global_position
	_queue_trail_redraw()


func _update_anchor_influence_visual(delta: float) -> void:
	if _anchor_influence_visual_strength <= 0.0:
		return

	if not visible or not gameplay_enabled or not anchor_visuals_enabled or not is_moving():
		_clear_anchor_influence_visual()
		return

	if _anchor_influence_fade_remaining > 0.0:
		_anchor_influence_fade_remaining = max(_anchor_influence_fade_remaining - delta, 0.0)
	else:
		_anchor_influence_visual_strength = max(
			_anchor_influence_visual_strength - delta / ANCHOR_INFLUENCE_FADE_TIME,
			0.0
		)

	queue_redraw()


func _clear_anchor_influence_visual() -> void:
	var had_visual: bool = _anchor_influence_visual_strength > 0.0 or _anchor_influence_fade_remaining > 0.0
	_anchor_influence_visual_strength = 0.0
	_anchor_influence_fade_remaining = 0.0
	_anchor_influence_direction = Vector2.ZERO
	if had_visual:
		queue_redraw()


func _queue_trail_redraw() -> void:
	_trail_redraws_this_frame += 1
	queue_redraw()


func _update_label_layout() -> void:
	number_label.size = Vector2(radius * 2.0, radius * 2.0)
	number_label.position = _spawn_drop_visual_offset + Vector2(-radius, -radius - 1.0)


func _update_label() -> void:
	if ball_type == BallType.CUE or is_wayfinder or is_powder_keg or is_anchor_ball or is_cannon_ball:
		number_label.text = ""
	else:
		number_label.text = str(ball_number)


func _update_number_color() -> void:
	if is_wayfinder:
		number_label.add_theme_color_override("font_color", Color("082522"))
	elif is_powder_keg:
		number_label.add_theme_color_override("font_color", Color("f9edd2"))
	elif is_anchor_ball:
		number_label.add_theme_color_override("font_color", Color("d9e2df"))
	elif is_cannon_ball:
		number_label.add_theme_color_override("font_color", Color("f1c28a"))
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

	if anchor_visuals_enabled and _anchor_influence_visual_strength > 0.0:
		_draw_anchor_influence_indicator(origin)

	if is_wayfinder:
		_draw_wayfinder_aura(origin)
	elif is_anchor_ball and anchor_visuals_enabled and anchor_field_visual_enabled:
		_draw_anchor_current(origin)

	draw_circle(origin + Vector2(1.5, 2.0), radius, shadow_color)
	draw_circle(origin, radius + 1.2, Color(0, 0, 0, 0.12))
	draw_circle(origin, radius, display_color)
	draw_circle(origin + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.72, display_color.lightened(0.16))
	draw_arc(origin, radius - rim_width * 0.5, 0.0, TAU, 40, rim_color, rim_width)

	if not is_wayfinder and not is_anchor_ball and not is_cannon_ball and (ball_type == BallType.OBJECT or ball_type == BallType.EIGHT):
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
	elif is_powder_keg:
		_draw_powder_keg_mark(origin)
	elif is_anchor_ball:
		_draw_anchor_mark(origin)
	elif is_cannon_ball:
		_draw_cannon_ball_mark(origin)

	draw_circle(origin + Vector2(-radius * 0.32, -radius * 0.36), radius * highlight_scale, shine_color)


func _get_display_color() -> Color:
	if is_cannon_ball:
		return CANNON_BALL_BASE_COLOR

	if is_anchor_ball:
		return ANCHOR_BALL_BASE_COLOR

	if is_powder_keg:
		return POWDER_KEG_BASE_COLOR

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


func _draw_powder_keg_mark(origin: Vector2) -> void:
	var hoop_y_offset: float = radius * 0.36
	draw_arc(origin + Vector2(0, -hoop_y_offset), radius * 0.82, 0.0, TAU, 34, POWDER_KEG_BAND_COLOR, 2.2)
	draw_arc(origin + Vector2(0, hoop_y_offset), radius * 0.78, 0.0, TAU, 34, POWDER_KEG_BAND_COLOR, 2.0)
	draw_line(
		origin + Vector2(-radius * 0.34, -radius * 0.58),
		origin + Vector2(-radius * 0.18, radius * 0.58),
		POWDER_KEG_STAVE_COLOR,
		1.6
	)
	draw_line(
		origin + Vector2(radius * 0.10, -radius * 0.6),
		origin + Vector2(radius * 0.28, radius * 0.56),
		POWDER_KEG_STAVE_COLOR,
		1.6
	)
	draw_circle(origin, radius * 0.15, Color("1e120c"))
	draw_arc(origin, radius * 0.15, 0.0, TAU, 20, POWDER_KEG_BAND_COLOR, 1.0)
	draw_line(
		origin + Vector2(radius * 0.08, -radius * 0.82),
		origin + Vector2(radius * 0.26, -radius * 1.18),
		POWDER_KEG_FUSE_COLOR,
		1.7
	)
	draw_circle(origin + Vector2(radius * 0.28, -radius * 1.22), 2.4, Color(1.0, 0.76, 0.34, 0.9))


func _draw_anchor_mark(origin: Vector2) -> void:
	var shank_top: Vector2 = origin + Vector2(0, -radius * 0.58)
	var shank_bottom: Vector2 = origin + Vector2(0, radius * 0.30)
	draw_arc(origin + Vector2(0, radius * 0.18), radius * 0.45, deg_to_rad(25.0), deg_to_rad(155.0), 24, ANCHOR_BALL_MARK_COLOR, 2.2)
	draw_line(shank_top, shank_bottom, ANCHOR_BALL_MARK_COLOR, 2.6)
	draw_line(origin + Vector2(-radius * 0.34, -radius * 0.25), origin + Vector2(radius * 0.34, -radius * 0.25), ANCHOR_BALL_MARK_COLOR, 2.0)
	draw_circle(shank_top, radius * 0.16, Color(0.03, 0.06, 0.07, 0.82))
	draw_arc(shank_top, radius * 0.16, 0.0, TAU, 18, ANCHOR_BALL_MARK_COLOR, 1.6)
	draw_line(
		origin + Vector2(-radius * 0.43, radius * 0.32),
		origin + Vector2(-radius * 0.58, radius * 0.10),
		ANCHOR_BALL_MARK_COLOR,
		2.0
	)
	draw_line(
		origin + Vector2(radius * 0.43, radius * 0.32),
		origin + Vector2(radius * 0.58, radius * 0.10),
		ANCHOR_BALL_MARK_COLOR,
		2.0
	)
	draw_arc(origin, radius - 3.0, 0.0, TAU, 40, ANCHOR_BALL_RIM_COLOR, 1.5)


func _draw_cannon_ball_mark(origin: Vector2) -> void:
	draw_arc(origin, radius - 2.0, 0.0, TAU, 44, CANNON_BALL_RIM_COLOR, 2.4)
	draw_arc(origin, radius - 5.0, deg_to_rad(210.0), deg_to_rad(330.0), 18, CANNON_BALL_EDGE_COLOR, 1.4)

	var dent_positions: Array[Vector2] = [
		Vector2(-radius * 0.32, -radius * 0.10),
		Vector2(radius * 0.20, radius * 0.22),
		Vector2(radius * 0.42, -radius * 0.34),
	]
	var dent_sizes: Array[float] = [radius * 0.13, radius * 0.10, radius * 0.08]
	for dent_index in range(dent_positions.size()):
		draw_circle(origin + dent_positions[dent_index], dent_sizes[dent_index], CANNON_BALL_DENT_COLOR)
		draw_arc(origin + dent_positions[dent_index], dent_sizes[dent_index], 0.0, TAU, 14, CANNON_BALL_EDGE_COLOR.darkened(0.18), 0.7)

	var ember_center: Vector2 = origin + Vector2(radius * 0.05, -radius * 0.42)
	var ember_glow := CANNON_BALL_EMBER_COLOR
	ember_glow.a = 0.18
	draw_circle(ember_center, radius * 0.30, ember_glow)
	draw_line(
		ember_center + Vector2(-radius * 0.18, radius * 0.06),
		ember_center + Vector2(radius * 0.20, -radius * 0.08),
		CANNON_BALL_EMBER_COLOR,
		1.3
	)
	draw_circle(ember_center + Vector2(radius * 0.20, -radius * 0.08), radius * 0.07, Color(1.0, 0.58, 0.18, 0.76))


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


func _draw_anchor_influence_indicator(origin: Vector2) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(time * 9.0)
	var strength: float = clamp(_anchor_influence_visual_strength, 0.0, 1.0)

	var aura_color: Color = ANCHOR_INFLUENCE_COLOR
	aura_color.a = (0.22 + pulse * 0.10) * strength
	draw_arc(origin, radius + 4.2 + pulse * 1.5, 0.0, TAU, 34, aura_color, 2.4)

	var ripple_color: Color = ANCHOR_INFLUENCE_WAKE_COLOR
	ripple_color.a = 0.20 * strength
	draw_arc(origin, radius + 7.6, deg_to_rad(20.0) + time, deg_to_rad(160.0) + time, 20, ripple_color, 1.7)
	draw_arc(origin, radius + 7.6, deg_to_rad(200.0) + time, deg_to_rad(320.0) + time, 20, ripple_color, 1.7)

	if _anchor_influence_direction.length_squared() <= 0.001:
		return

	var wake_color: Color = ANCHOR_INFLUENCE_WAKE_COLOR
	wake_color.a = 0.30 * strength
	var wake_start: Vector2 = origin - _anchor_influence_direction * (radius + 1.5)
	var wake_end: Vector2 = origin - _anchor_influence_direction * (radius + 11.0 + pulse * 2.5)
	draw_line(wake_start, wake_end, wake_color, 2.1)


func _draw_anchor_current(origin: Vector2) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.5 + 0.5 * sin(time * 4.8)
	var strength: float = clamp(anchor_visual_effect_strength, 0.0, 1.0)

	var field_color: Color = ANCHOR_BALL_CURRENT_COLOR
	field_color.a = 0.035 * strength
	draw_arc(origin, anchor_field_visual_radius, 0.0, TAU, 96, field_color, 1.0)
	draw_arc(
		origin,
		anchor_field_visual_radius * 0.62,
		deg_to_rad(30.0) + time * 0.35,
		deg_to_rad(190.0) + time * 0.35,
		36,
		field_color,
		1.0
	)

	var mist_color: Color = ANCHOR_BALL_MIST_COLOR
	mist_color.a = (0.10 + pulse * 0.08) * strength
	draw_circle(origin, radius + 11.0 + pulse * 2.5, mist_color)

	var current_color: Color = ANCHOR_BALL_CURRENT_COLOR
	current_color.a = (0.18 + pulse * 0.10) * strength
	var swirl_offset: float = time * 1.5
	draw_arc(origin, radius + 5.0 + pulse * 1.5, deg_to_rad(205.0) + swirl_offset, deg_to_rad(335.0) + swirl_offset, 28, current_color, 2.1)
	draw_arc(origin, radius + 10.0 - pulse * 1.0, deg_to_rad(25.0) + swirl_offset, deg_to_rad(165.0) + swirl_offset, 28, current_color, 1.7)

	var dark_current_color: Color = ANCHOR_BALL_RIM_COLOR
	dark_current_color.a = (0.16 + pulse * 0.06) * strength
	draw_arc(origin, radius + 8.0, deg_to_rad(150.0) - swirl_offset, deg_to_rad(270.0) - swirl_offset, 24, dark_current_color, 1.5)


func _draw_trail() -> void:
	if not trail_enabled:
		return

	for point in _trail_points:
		var position: Vector2 = to_local(point.position)
		var fade: float = 1.0 - clamp(point.age / trail_lifetime, 0.0, 1.0)
		var dot_color: Color = ball_color.lightened(0.25)
		dot_color.a = 0.34 * fade
		draw_circle(position, trail_dot_radius * fade, dot_color)
