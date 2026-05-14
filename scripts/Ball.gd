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
const CANNON_HEAT_GLOW_COLOR := Color("ff3218")
const CANNON_HEAT_TRAIL_COLOR := Color("ff7a22")
const CANNON_HEAT_HOT_COLOR := Color("ffd26a")
const CANNON_PRESENCE_FADE_TIME := 0.18
const TREASURE_BALL_BASE_COLOR := Color("d99a28")
const TREASURE_BALL_RIM_COLOR := Color("5d3511")
const TREASURE_BALL_GEM_COLOR := Color("57e0d4")
const TREASURE_BALL_GLOW_COLOR := Color("ffe6a6")
const TREASURE_LEG_COLOR := Color("cf7528")
const TREASURE_LEG_FOOT_COLOR := Color("fff08a")
const TREASURE_LEG_FADE_TIME := 0.28
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
var is_treasure_ball := false
var anchor_visual_effect_strength := 0.7
var anchor_field_visual_radius := 230.0
var anchor_visuals_enabled := true
var anchor_field_visual_enabled := true

var _spawn_drop_active := false
var _spawn_drop_elapsed := 0.0
var _spawn_drop_target := Vector2.ZERO
var _spawn_drop_settle_velocity := Vector2.ZERO
var _spawn_drop_visual_offset := Vector2.ZERO
var _impact_shimmy_visual_offset := Vector2.ZERO
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
var _cannon_presence_visual_strength := 0.0
var _cannon_presence_target_strength := 0.0
var _cannon_presence_direction := Vector2.RIGHT
var _cannon_presence_flash_strength := 0.0
var _cannon_presence_flash_remaining := 0.0
var _cannon_presence_flash_fade_time := 0.24
var _treasure_leg_visual_strength := 0.0
var _treasure_leg_target_strength := 0.0
var _treasure_leg_direction := Vector2.RIGHT
var _treasure_leg_phase := 0.0


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
	_update_cannon_presence_visual(delta)
	_update_treasure_leg_visual(delta)

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


func set_impact_shimmy_visual_offset(offset: Vector2) -> void:
	if _impact_shimmy_visual_offset.distance_squared_to(offset) < 0.01:
		return
	_impact_shimmy_visual_offset = offset
	_update_label_layout()
	queue_redraw()


func set_cannon_presence_visual(strength: float, direction: Vector2) -> void:
	var clamped_strength: float = clamp(strength, 0.0, 4.0)
	var next_direction: Vector2 = _cannon_presence_direction
	if direction.length_squared() > 0.001:
		next_direction = direction.normalized()

	var should_redraw: bool = (
		absf(_cannon_presence_target_strength - clamped_strength) > 0.01
		or _cannon_presence_direction.distance_squared_to(next_direction) > 0.01
	)
	_cannon_presence_target_strength = clamped_strength
	if clamped_strength > _cannon_presence_visual_strength:
		_cannon_presence_visual_strength = clamped_strength
	_cannon_presence_direction = next_direction
	if should_redraw:
		queue_redraw()


func add_cannon_presence_flash(strength: float, duration: float) -> void:
	_cannon_presence_flash_strength = max(_cannon_presence_flash_strength, clamp(strength, 0.0, 1.0))
	_cannon_presence_flash_remaining = max(_cannon_presence_flash_remaining, duration)
	_cannon_presence_flash_fade_time = max(duration, 0.01)
	queue_redraw()


func note_treasure_fleeing(strength: float, direction: Vector2) -> void:
	if not is_treasure_ball or not visible or not gameplay_enabled:
		return

	var visual_strength: float = clamp(0.45 + strength * 0.55, 0.0, 1.0)
	_treasure_leg_target_strength = max(_treasure_leg_target_strength, visual_strength)
	if direction.length_squared() > 0.001:
		_treasure_leg_direction = direction.normalized()
	queue_redraw()


func setup(
	new_type: int,
	new_number: int,
	new_color: Color,
	new_is_wayfinder: bool = false,
	new_is_powder_keg: bool = false,
	new_is_anchor_ball: bool = false,
	new_is_cannon_ball: bool = false,
	new_is_treasure_ball: bool = false
) -> void:
	ball_type = new_type
	ball_number = new_number
	ball_color = new_color
	is_wayfinder = new_is_wayfinder
	is_powder_keg = new_is_powder_keg
	is_anchor_ball = new_is_anchor_ball
	is_cannon_ball = new_is_cannon_ball
	is_treasure_ball = new_is_treasure_ball
	set_cannon_presence_visual(0.0, Vector2.RIGHT)
	_cannon_presence_visual_strength = 0.0
	_cannon_presence_flash_strength = 0.0
	_cannon_presence_flash_remaining = 0.0
	_clear_treasure_leg_visual()
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
	_clear_treasure_leg_visual()
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
	_clear_treasure_leg_visual()
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
	_clear_treasure_leg_visual()


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


func _update_cannon_presence_visual(delta: float) -> void:
	var had_visual: bool = _get_cannon_presence_draw_strength() > 0.0
	if _cannon_presence_target_strength <= 0.0 and _cannon_presence_visual_strength > 0.0:
		_cannon_presence_visual_strength = move_toward(
			_cannon_presence_visual_strength,
			0.0,
			delta / CANNON_PRESENCE_FADE_TIME
		)
	elif _cannon_presence_target_strength > 0.0:
		_cannon_presence_visual_strength = _cannon_presence_target_strength

	if _cannon_presence_flash_remaining > 0.0:
		_cannon_presence_flash_remaining = max(_cannon_presence_flash_remaining - delta, 0.0)
		_cannon_presence_flash_strength = move_toward(
			_cannon_presence_flash_strength,
			0.0,
			delta / _cannon_presence_flash_fade_time
		)
	else:
		_cannon_presence_flash_strength = 0.0

	if had_visual or _get_cannon_presence_draw_strength() > 0.0:
		queue_redraw()


func _get_cannon_presence_draw_strength() -> float:
	return clamp(_cannon_presence_visual_strength + _cannon_presence_flash_strength, 0.0, 4.45)


func _update_treasure_leg_visual(delta: float) -> void:
	if not is_treasure_ball:
		return
	if _treasure_leg_target_strength <= 0.0 and _treasure_leg_visual_strength <= 0.0:
		return

	var had_visual: bool = _treasure_leg_visual_strength > 0.0
	if not visible or not gameplay_enabled:
		_clear_treasure_leg_visual()
		return

	if _treasure_leg_target_strength > 0.0:
		_treasure_leg_visual_strength = move_toward(_treasure_leg_visual_strength, _treasure_leg_target_strength, delta / 0.07)
	else:
		_treasure_leg_visual_strength = move_toward(_treasure_leg_visual_strength, 0.0, delta / TREASURE_LEG_FADE_TIME)

	var gait_speed: float = 13.0 + min(velocity.length() / 34.0, 22.0)
	_treasure_leg_phase = fmod(_treasure_leg_phase + delta * gait_speed, TAU)
	_treasure_leg_target_strength = 0.0

	if had_visual or _treasure_leg_visual_strength > 0.0:
		queue_redraw()


func _clear_treasure_leg_visual() -> void:
	var had_visual: bool = _treasure_leg_visual_strength > 0.0 or _treasure_leg_target_strength > 0.0
	_treasure_leg_visual_strength = 0.0
	_treasure_leg_target_strength = 0.0
	_treasure_leg_direction = Vector2.RIGHT
	if had_visual:
		queue_redraw()


func _queue_trail_redraw() -> void:
	_trail_redraws_this_frame += 1
	queue_redraw()


func _update_label_layout() -> void:
	number_label.size = Vector2(radius * 2.0, radius * 2.0)
	number_label.position = _get_visual_draw_origin() + Vector2(-radius, -radius - 1.0)


func _get_visual_draw_origin() -> Vector2:
	return _spawn_drop_visual_offset + _impact_shimmy_visual_offset


func _update_label() -> void:
	if ball_type == BallType.CUE or is_wayfinder or is_powder_keg or is_anchor_ball or is_cannon_ball or is_treasure_ball:
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
	elif is_treasure_ball:
		number_label.add_theme_color_override("font_color", Color("5d3511"))
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

	var origin: Vector2 = _get_visual_draw_origin()
	var display_color: Color = _get_display_color()
	var rim_color: Color = display_color.darkened(0.45)
	var shadow_color: Color = Color(0, 0, 0, 0.22)
	var shine_color: Color = Color(1, 1, 1, 0.34)

	if anchor_visuals_enabled and _anchor_influence_visual_strength > 0.0:
		_draw_anchor_influence_indicator(origin)

	if is_cannon_ball and _get_cannon_presence_draw_strength() > 0.0:
		_draw_cannon_presence(origin)

	if is_wayfinder:
		_draw_wayfinder_aura(origin)
	elif is_anchor_ball and anchor_visuals_enabled and anchor_field_visual_enabled:
		_draw_anchor_current(origin)
	elif is_treasure_ball and _treasure_leg_visual_strength > 0.0:
		_draw_treasure_legs(origin)

	draw_circle(origin + Vector2(1.5, 2.0), radius, shadow_color)
	draw_circle(origin, radius + 1.2, Color(0, 0, 0, 0.12))
	draw_circle(origin, radius, display_color)
	draw_circle(origin + Vector2(-radius * 0.18, -radius * 0.22), radius * 0.72, display_color.lightened(0.16))
	draw_arc(origin, radius - rim_width * 0.5, 0.0, TAU, 40, rim_color, rim_width)

	if not is_wayfinder and not is_anchor_ball and not is_cannon_ball and not is_treasure_ball and (ball_type == BallType.OBJECT or ball_type == BallType.EIGHT):
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
	elif is_treasure_ball:
		_draw_treasure_ball_mark(origin)

	if is_treasure_ball and _treasure_leg_visual_strength > 0.0:
		_draw_treasure_feet(origin)

	draw_circle(origin + Vector2(-radius * 0.32, -radius * 0.36), radius * highlight_scale, shine_color)


func _get_display_color() -> Color:
	if is_cannon_ball:
		return CANNON_BALL_BASE_COLOR

	if is_treasure_ball:
		return TREASURE_BALL_BASE_COLOR

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
	if _get_cannon_presence_draw_strength() > 0.0:
		_draw_cannon_motion_ember(ember_center)


func _draw_cannon_presence(origin: Vector2) -> void:
	var strength: float = _get_cannon_presence_draw_strength()
	var tier_strength: float = min(strength, 4.0)
	var forward: Vector2 = _cannon_presence_direction.normalized()
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	var trail_direction: Vector2 = -forward

	var outer_glow := CANNON_HEAT_GLOW_COLOR
	outer_glow.a = 0.09 + tier_strength * 0.052
	draw_circle(origin, radius * (1.16 + tier_strength * 0.13), outer_glow)

	var inner_glow := CANNON_HEAT_TRAIL_COLOR
	inner_glow.a = 0.10 + tier_strength * 0.045
	draw_circle(origin, radius * (0.96 + tier_strength * 0.055), inner_glow)

	var rim_glow := CANNON_HEAT_HOT_COLOR
	rim_glow.a = 0.14 + tier_strength * 0.042
	draw_arc(origin, radius + 2.2 + tier_strength * 0.85, 0.0, TAU, 40, rim_glow, 1.2 + tier_strength * 0.26)

	if strength < 1.75:
		return

	var trail_segments := 3
	var trail_length: float = radius * 2.80
	var trail_scale := 1.15
	var start_alpha := 0.30
	var end_alpha := 0.075
	if strength >= 3.75:
		trail_segments = 5
		trail_length = radius * 5.90
		trail_scale = 1.85
		start_alpha = 0.46
		end_alpha = 0.115
	elif strength >= 2.75:
		trail_segments = 4
		trail_length = radius * 4.15
		trail_scale = 1.45
		start_alpha = 0.38
		end_alpha = 0.090

	for trail_index in range(trail_segments):
		var ratio: float = float(trail_index) / float(trail_segments)
		var fade_ratio: float = float(trail_index + 1) / float(trail_segments)
		var ember_position: Vector2 = origin + trail_direction * trail_length * ratio
		if trail_index == 0:
			ember_position += trail_direction * radius * 0.35
		var ember_radius: float = radius * lerp(1.05, 0.34, fade_ratio) * trail_scale

		var outer_trail_glow := CANNON_HEAT_GLOW_COLOR
		outer_trail_glow.a = lerp(start_alpha * 0.58, end_alpha * 0.42, fade_ratio)
		draw_circle(ember_position, ember_radius * 1.85, outer_trail_glow)

		var ember_color := CANNON_HEAT_TRAIL_COLOR
		ember_color.a = lerp(start_alpha, end_alpha, fade_ratio)
		draw_circle(ember_position, ember_radius, ember_color)

		var hot_core := CANNON_HEAT_HOT_COLOR
		hot_core.a = lerp(start_alpha * 0.78, end_alpha * 0.55, fade_ratio)
		draw_circle(ember_position, ember_radius * 0.48, hot_core)

	var rear_heat := CANNON_HEAT_HOT_COLOR
	rear_heat.a = 0.16 + tier_strength * 0.046
	draw_circle(origin + trail_direction * radius * 0.86, radius * (0.24 + tier_strength * 0.045), rear_heat)


func _draw_cannon_motion_ember(ember_center: Vector2) -> void:
	var strength: float = _get_cannon_presence_draw_strength()
	var tier_strength: float = min(strength, 4.0)
	var ember_glow := CANNON_BALL_EMBER_COLOR
	ember_glow.a = 0.16 + tier_strength * 0.095
	draw_circle(ember_center, radius * (0.34 + tier_strength * 0.095), ember_glow)

	var hot_color := CANNON_HEAT_HOT_COLOR
	hot_color.a = 0.22 + tier_strength * 0.095
	draw_line(
		ember_center + Vector2(-radius * 0.34, radius * 0.13),
		ember_center + Vector2(radius * 0.36, -radius * 0.18),
		hot_color,
		1.1 + tier_strength * 0.36
	)
	draw_circle(ember_center + Vector2(radius * 0.28, -radius * 0.12), radius * (0.065 + tier_strength * 0.043), hot_color)


func _draw_treasure_ball_mark(origin: Vector2) -> void:
	var glow_color := TREASURE_BALL_GLOW_COLOR
	glow_color.a = 0.20
	draw_circle(origin, radius * 0.88, glow_color)
	draw_arc(origin, radius - 2.8, 0.0, TAU, 40, TREASURE_BALL_RIM_COLOR, 1.8)

	var gem_top: Vector2 = origin + Vector2(0.0, -radius * 0.46)
	var gem_left: Vector2 = origin + Vector2(-radius * 0.44, -radius * 0.02)
	var gem_right: Vector2 = origin + Vector2(radius * 0.44, -radius * 0.02)
	var gem_bottom: Vector2 = origin + Vector2(0.0, radius * 0.50)
	draw_colored_polygon(
		PackedVector2Array([gem_top, gem_right, gem_bottom, gem_left]),
		TREASURE_BALL_GEM_COLOR
	)
	draw_polyline(
		PackedVector2Array([gem_top, gem_right, gem_bottom, gem_left, gem_top]),
		TREASURE_BALL_RIM_COLOR,
		1.2
	)
	draw_line(gem_left, gem_right, TREASURE_BALL_GLOW_COLOR, 1.1)
	draw_line(gem_top, gem_bottom, Color(1.0, 0.94, 0.64, 0.72), 1.0)


func _draw_treasure_legs(origin: Vector2) -> void:
	var strength: float = clamp(_treasure_leg_visual_strength, 0.0, 1.0)
	if strength <= 0.01:
		return

	var leg_color := TREASURE_LEG_COLOR
	leg_color.a = 0.92 * strength
	var highlight_color := TREASURE_BALL_GLOW_COLOR
	highlight_color.a = 0.40 * strength

	for leg_points_value in _get_treasure_leg_points(origin):
		var leg_points: Dictionary = leg_points_value as Dictionary
		var hip: Vector2 = leg_points["hip"]
		var knee: Vector2 = leg_points["knee"]
		var foot: Vector2 = leg_points["foot"]
		var step: float = float(leg_points["step"])
		var leg_width: float = 2.35 + strength * 1.25
		draw_line(hip, knee, leg_color, leg_width)
		draw_line(knee, foot, leg_color, leg_width)
		if step > 0.28:
			draw_circle(knee, 1.8 + strength * 0.4, highlight_color)


func _draw_treasure_feet(origin: Vector2) -> void:
	var strength: float = clamp(_treasure_leg_visual_strength, 0.0, 1.0)
	if strength <= 0.01:
		return

	var foot_shadow := TREASURE_BALL_RIM_COLOR
	foot_shadow.a = 0.74 * strength
	var foot_color := TREASURE_LEG_FOOT_COLOR
	foot_color.a = 1.0 * strength

	for leg_points_value in _get_treasure_leg_points(origin):
		var leg_points: Dictionary = leg_points_value as Dictionary
		var foot: Vector2 = leg_points["foot"]
		var step: float = float(leg_points["step"])
		var foot_radius: float = 2.75 + strength * 1.25 + max(step, 0.0) * 0.58
		draw_circle(foot + Vector2(0.8, 0.9), foot_radius + 0.85, foot_shadow)
		draw_circle(foot, foot_radius, foot_color)


func _get_treasure_leg_points(origin: Vector2) -> Array[Dictionary]:
	var forward: Vector2 = _treasure_leg_direction
	if forward.length_squared() <= 0.001:
		forward = Vector2.RIGHT
	forward = forward.normalized()
	var side: Vector2 = forward.orthogonal()
	var leg_points: Array[Dictionary] = []
	var side_signs: Array[float] = [-1.0, 1.0]
	var forward_offsets: Array[float] = [-0.44, 0.40]
	for side_sign in side_signs:
		for leg_index in range(forward_offsets.size()):
			var phase_offset: float = 0.0 if leg_index == 0 else PI
			if side_sign > 0.0:
				phase_offset += PI
			var step: float = sin(_treasure_leg_phase + phase_offset)
			var hip: Vector2 = origin + side * side_sign * radius * 0.80 + forward * radius * forward_offsets[leg_index]
			var knee: Vector2 = hip + side * side_sign * radius * (0.68 + 0.22 * step) - forward * radius * (0.13 * step)
			var foot: Vector2 = hip + side * side_sign * radius * (1.34 + 0.38 * step) + forward * radius * (0.34 * step)
			leg_points.append({
				"hip": hip,
				"knee": knee,
				"foot": foot,
				"step": step,
			})

	return leg_points


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
