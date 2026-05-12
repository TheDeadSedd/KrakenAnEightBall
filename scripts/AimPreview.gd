@tool
extends Node2D
class_name AimPreview

# Owns cue aim prediction, bank preview drawing, and shot-path debug overlays.
# Table.gd owns real balls/gameplay state; BoundarySystem owns boundary queries.
const DEBUG_AIM_PATH_COMPARISON_DEFAULT := false
const DEBUG_BANK_PREDICTION := false
const AIM_GUIDE_LENGTH := 180.0
const AIM_PREDICTION_ENABLED := true
const AIM_PREDICTION_MAX_DISTANCE := 900.0
const AIM_LINE_WIDTH := 3.0
const AIM_LINE_GLOW_WIDTH := 9.0
const AIM_LINE_MIN_ALPHA := 0.24
const AIM_LINE_GLOW_ALPHA := 0.26
const AIM_LINE_HIGH_POWER_GLOW_ALPHA := 0.44
const AIM_LINE_HIGH_POWER_PULSE_SPEED := 7.0
const AIM_LINE_HIGH_POWER_PULSE_STRENGTH := 0.16
const AIM_POST_BANK_ALPHA_MULTIPLIER := 0.58
const AIM_END_MARKER_SIZE := 8.0
const AIM_END_MARKER_LINE_WIDTH := 2.0
const AIM_END_MARKER_GLOW_WIDTH := 5.0
const AIM_TARGET_LINE_WIDTH := 2.6
const AIM_TARGET_LINE_GLOW_WIDTH := 7.0
const AIM_TARGET_LINE_GLOW_ALPHA := 0.24
const AIM_TARGET_LINE_SEGMENT_LENGTH := 28.0
const AIM_TARGET_CURSED_CORE_COLOR := Color(0.018, 0.022, 0.026, 0.82)
const AIM_TARGET_CURSED_GLOW_COLOR := Color(0.16, 0.92, 0.72, 0.28)
const AIM_TARGET_POCKET_MARKER_COLOR := Color(0.78, 1.0, 0.82, 0.42)
const AIM_TARGET_POCKET_MARKER_RADIUS := 7.0
const AIM_TARGET_ENDPOINT_MARKER_RADIUS := 5.0
const AIM_TARGET_PREDICTION_MAX_DISTANCE := 520.0
const AIM_TARGET_PREDICTION_MAX_STEPS := 320
const AIM_SIMULATION_FRAME_DELTA := 1.0 / 60.0
const AIM_SIMULATION_MAX_BOUNCES := 1
const BANK_DEBUG_MARKER_LIFETIME := 1.0
const AIM_PATH_DEBUG_LIFETIME := 3.0
const AIM_PATH_DEBUG_MAX_POINTS := 240
const AIM_PATH_DEBUG_POINT_SPACING := 5.0

class AimPrediction:
	var collision_type := "none"
	var position := Vector2.ZERO
	var ball: Ball = null
	var target_direction := Vector2.ZERO
	var target_path_points: Array[Vector2] = []
	var target_ends_in_pocket := false
	var path_points: Array[Vector2] = []
	var rail_position := Vector2.ZERO
	var rail_normal := Vector2.ZERO
	var post_bank_direction := Vector2.ZERO

class BankDebugMarker:
	var position := Vector2.ZERO
	var incoming_direction := Vector2.ZERO
	var outgoing_direction := Vector2.ZERO
	var normal := Vector2.ZERO
	var remaining_time := 0.0

class AimBallHit:
	var ball: Ball = null
	var distance := INF
	var position := Vector2.ZERO

class AimPocketHit:
	var pocket_index := -1
	var distance := INF
	var position := Vector2.ZERO

class AimTargetPath:
	var points: Array[Vector2] = []
	var ends_in_pocket := false

class BallMotionState:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var rail_position := Vector2.ZERO
	var rail_normal := Vector2.ZERO
	var hit_rail := false

var table
var preview_active := false
var preview_origin := Vector2.ZERO
var preview_drag_vector := Vector2.ZERO
var preview_power_ratio := 0.0
var current_prediction: AimPrediction
var bank_debug_markers: Array[BankDebugMarker] = []
var last_predicted_aim_path: Array[Vector2] = []
var last_predicted_rail_position := Vector2.ZERO
var last_predicted_rail_normal := Vector2.ZERO
var last_predicted_post_bank_direction := Vector2.ZERO
var actual_cue_path: Array[Vector2] = []
var aim_path_debug_timer := 0.0
var actual_cue_path_recording := false
var debug_aim_path_comparison_enabled := DEBUG_AIM_PATH_COMPARISON_DEFAULT
var prediction_ms := 0.0


func setup(table_ref) -> void:
	table = table_ref


func update_preview(active: bool, origin: Vector2, drag_vector: Vector2, shot_power: float, power_ratio: float) -> void:
	if not active:
		prediction_ms = 0.0
		if preview_active or current_prediction != null:
			preview_active = false
			current_prediction = null
			queue_redraw()
		return

	preview_active = true
	preview_origin = origin
	preview_drag_vector = drag_vector
	preview_power_ratio = power_ratio

	var aim_start_usec: int = Time.get_ticks_usec()
	current_prediction = _get_first_aim_collision(origin, drag_vector * shot_power)
	prediction_ms = _elapsed_ms_since(aim_start_usec)
	queue_redraw()


func update_debug(delta: float, is_dragging: bool) -> void:
	_update_bank_debug_markers(delta)
	_update_aim_path_comparison_debug(delta)
	if _should_redraw_debug(is_dragging):
		queue_redraw()


func start_path_comparison(origin: Vector2, initial_velocity: Vector2) -> void:
	if not debug_aim_path_comparison_enabled:
		return

	var prediction: AimPrediction = _get_first_aim_collision(origin, initial_velocity)
	last_predicted_aim_path = prediction.path_points.duplicate()
	last_predicted_rail_position = prediction.rail_position
	last_predicted_rail_normal = prediction.rail_normal
	last_predicted_post_bank_direction = prediction.post_bank_direction
	actual_cue_path = [origin]
	actual_cue_path_recording = true
	aim_path_debug_timer = AIM_PATH_DEBUG_LIFETIME
	_print_predicted_bank_debug(prediction)
	queue_redraw()


func record_actual_bank_debug(
	ball: Ball,
	hit_position: Vector2,
	incoming_velocity: Vector2,
	normal: Vector2,
	shot_active: bool
) -> void:
	if not _bank_debug_visuals_enabled() or ball != table.cue_ball or not shot_active or normal == Vector2.ZERO:
		return

	var marker: BankDebugMarker = BankDebugMarker.new()
	marker.position = hit_position
	marker.incoming_direction = incoming_velocity.normalized()
	marker.outgoing_direction = ball.velocity.normalized()
	marker.normal = normal
	marker.remaining_time = BANK_DEBUG_MARKER_LIFETIME
	bank_debug_markers.append(marker)
	queue_redraw()
	_print_actual_bank_debug(hit_position, marker.incoming_direction, marker.outgoing_direction, normal)


func note_actual_cue_ball_hit() -> void:
	if not debug_aim_path_comparison_enabled or not actual_cue_path_recording:
		return

	actual_cue_path.append(table.cue_ball.global_position)
	stop_actual_path_recording()
	print("Bank debug | actual cue hit ball | pos=%s" % table.cue_ball.global_position)


func note_actual_cue_pocketed(ball: Ball) -> void:
	if not debug_aim_path_comparison_enabled or ball != table.cue_ball or not actual_cue_path_recording:
		return

	actual_cue_path.append(table.cue_ball.global_position)
	stop_actual_path_recording()
	print("Bank debug | actual cue pocketed | pos=%s" % table.cue_ball.global_position)


func record_actual_path_step() -> void:
	if not debug_aim_path_comparison_enabled or not actual_cue_path_recording:
		return

	if not is_instance_valid(table.cue_ball) or not table.cue_ball.is_gameplay_active():
		stop_actual_path_recording()
		return

	if actual_cue_path.is_empty():
		actual_cue_path.append(table.cue_ball.global_position)
		return

	var last_point: Vector2 = actual_cue_path[actual_cue_path.size() - 1]
	if last_point.distance_to(table.cue_ball.global_position) >= AIM_PATH_DEBUG_POINT_SPACING:
		actual_cue_path.append(table.cue_ball.global_position)

	if actual_cue_path.size() >= AIM_PATH_DEBUG_MAX_POINTS or table.cue_ball.velocity.length() <= table.PHYSICS_DEBUG_SPEED_THRESHOLD:
		stop_actual_path_recording()


func stop_actual_path_recording() -> void:
	actual_cue_path_recording = false


func set_shot_path_debug_enabled(enabled: bool) -> void:
	debug_aim_path_comparison_enabled = enabled
	if not enabled:
		stop_actual_path_recording()
		aim_path_debug_timer = 0.0
		queue_redraw()


func is_shot_path_debug_enabled() -> bool:
	return debug_aim_path_comparison_enabled


func is_prediction_enabled() -> bool:
	return AIM_PREDICTION_ENABLED


func get_prediction_time_ms() -> float:
	return prediction_ms


func _draw() -> void:
	_draw_bank_debug_markers()
	_draw_aim_path_comparison_debug()
	if not preview_active:
		return

	if AIM_PREDICTION_ENABLED and current_prediction != null:
		_draw_prediction(current_prediction)
	else:
		_draw_basic_guide_line()


func _draw_prediction(prediction: AimPrediction) -> void:
	var aim_color: Color = _get_aim_power_color(preview_power_ratio)
	var bank_segment_start_index: int = _get_bank_segment_start_index(prediction)
	for point_index in range(prediction.path_points.size() - 1):
		var segment_alpha_multiplier := 1.0
		if bank_segment_start_index >= 0 and point_index >= bank_segment_start_index:
			segment_alpha_multiplier = AIM_POST_BANK_ALPHA_MULTIPLIER
		_draw_aim_line_segment(
			prediction.path_points[point_index],
			prediction.path_points[point_index + 1],
			aim_color,
			_get_path_fade_ratio(point_index, prediction.path_points.size() - 1),
			segment_alpha_multiplier
		)

	_draw_aim_end_marker(prediction.position, _get_prediction_end_direction(prediction), aim_color)
	_draw_predicted_bank_debug(prediction)
	if prediction.collision_type != "ball":
		return

	_draw_target_prediction_line(prediction)


func _draw_basic_guide_line() -> void:
	var aim_direction: Vector2 = preview_drag_vector.normalized()
	var guide_length: float = min(AIM_GUIDE_LENGTH, preview_drag_vector.length() * 1.2)
	var guide_end: Vector2 = preview_origin + aim_direction * guide_length
	_draw_aim_line_segment(preview_origin, guide_end, _get_aim_power_color(preview_power_ratio), 1.0, 1.0)
	_draw_aim_end_marker(guide_end, aim_direction, _get_aim_power_color(preview_power_ratio))


func _draw_aim_line_segment(
	start: Vector2,
	end: Vector2,
	base_color: Color,
	fade_ratio: float,
	alpha_multiplier: float
) -> void:
	if start.distance_squared_to(end) <= 0.001:
		return

	var glow_alpha: float = lerp(AIM_LINE_GLOW_ALPHA, AIM_LINE_HIGH_POWER_GLOW_ALPHA, preview_power_ratio)
	glow_alpha += _get_high_power_pulse() * AIM_LINE_HIGH_POWER_PULSE_STRENGTH
	var outer_width: float = lerp(AIM_LINE_GLOW_WIDTH * 0.72, AIM_LINE_GLOW_WIDTH, preview_power_ratio)
	_draw_guidance_line_segment(
		start,
		end,
		base_color,
		base_color,
		fade_ratio,
		alpha_multiplier,
		AIM_LINE_WIDTH,
		outer_width,
		glow_alpha
	)


func _draw_guidance_line_segment(
	start: Vector2,
	end: Vector2,
	inner_base_color: Color,
	glow_base_color: Color,
	fade_ratio: float,
	alpha_multiplier: float,
	inner_base_width: float,
	glow_width: float,
	glow_alpha: float
) -> void:
	if start.distance_squared_to(end) <= 0.001:
		return

	var clamped_fade: float = clamp(fade_ratio, 0.0, 1.0)
	var fade_alpha: float = lerp(1.0, AIM_LINE_MIN_ALPHA, clamped_fade)
	var inner_color := Color(inner_base_color.r, inner_base_color.g, inner_base_color.b, inner_base_color.a * fade_alpha * alpha_multiplier)
	var glow_color := Color(glow_base_color.r, glow_base_color.g, glow_base_color.b, glow_alpha * fade_alpha * alpha_multiplier)
	var inner_width: float = max(1.25, inner_base_width * lerp(1.0, 0.62, clamped_fade))

	draw_line(start, end, glow_color, glow_width)
	draw_line(start, end, inner_color, inner_width)


func _draw_aim_end_marker(position: Vector2, direction: Vector2, base_color: Color) -> void:
	var marker_direction: Vector2 = Vector2.RIGHT if direction.length_squared() <= 0.001 else direction.normalized()
	var marker_perp: Vector2 = marker_direction.orthogonal()
	var diagonal_a: Vector2 = (marker_direction + marker_perp).normalized()
	var diagonal_b: Vector2 = (marker_direction - marker_perp).normalized()
	var marker_size: float = AIM_END_MARKER_SIZE + preview_power_ratio * 2.0
	var glow_color := Color(base_color.r, base_color.g, base_color.b, 0.36 + _get_high_power_pulse() * 0.18)
	var core_color := Color(base_color.r, base_color.g, base_color.b, 0.92)

	draw_line(position - diagonal_a * marker_size, position + diagonal_a * marker_size, glow_color, AIM_END_MARKER_GLOW_WIDTH)
	draw_line(position - diagonal_b * marker_size, position + diagonal_b * marker_size, glow_color, AIM_END_MARKER_GLOW_WIDTH)
	draw_line(position - diagonal_a * marker_size, position + diagonal_a * marker_size, core_color, AIM_END_MARKER_LINE_WIDTH)
	draw_line(position - diagonal_b * marker_size, position + diagonal_b * marker_size, core_color, AIM_END_MARKER_LINE_WIDTH)


func _draw_target_prediction_line(prediction: AimPrediction) -> void:
	if prediction.ball == null or prediction.target_path_points.size() < 2:
		return

	var segment_count: int = prediction.target_path_points.size() - 1
	for segment_index in range(segment_count):
		_draw_guidance_line_segment(
			prediction.target_path_points[segment_index],
			prediction.target_path_points[segment_index + 1],
			AIM_TARGET_CURSED_CORE_COLOR,
			AIM_TARGET_CURSED_GLOW_COLOR,
			_get_path_fade_ratio(segment_index, segment_count),
			1.0,
			AIM_TARGET_LINE_WIDTH,
			AIM_TARGET_LINE_GLOW_WIDTH,
			AIM_TARGET_LINE_GLOW_ALPHA
		)

	if prediction.target_ends_in_pocket:
		_draw_target_pocket_marker(prediction.target_path_points[prediction.target_path_points.size() - 1])
	else:
		_draw_target_endpoint_marker(prediction.target_path_points[prediction.target_path_points.size() - 1])


func _draw_target_pocket_marker(position: Vector2) -> void:
	var glow_color := Color(
		AIM_TARGET_POCKET_MARKER_COLOR.r,
		AIM_TARGET_POCKET_MARKER_COLOR.g,
		AIM_TARGET_POCKET_MARKER_COLOR.b,
		0.16
	)
	draw_circle(position, AIM_TARGET_POCKET_MARKER_RADIUS * 1.9, glow_color)
	draw_circle(position, AIM_TARGET_POCKET_MARKER_RADIUS, AIM_TARGET_POCKET_MARKER_COLOR)


func _draw_target_endpoint_marker(position: Vector2) -> void:
	var glow_color := Color(
		AIM_TARGET_CURSED_GLOW_COLOR.r,
		AIM_TARGET_CURSED_GLOW_COLOR.g,
		AIM_TARGET_CURSED_GLOW_COLOR.b,
		0.14
	)
	var core_color := Color(
		AIM_TARGET_CURSED_CORE_COLOR.r,
		AIM_TARGET_CURSED_CORE_COLOR.g,
		AIM_TARGET_CURSED_CORE_COLOR.b,
		0.72
	)
	draw_circle(position, AIM_TARGET_ENDPOINT_MARKER_RADIUS * 1.85, glow_color)
	draw_circle(position, AIM_TARGET_ENDPOINT_MARKER_RADIUS, core_color)


func _get_prediction_end_direction(prediction: AimPrediction) -> Vector2:
	if prediction.path_points.size() < 2:
		return preview_drag_vector.normalized()

	var point_index: int = prediction.path_points.size() - 2
	while point_index >= 0:
		var end_point: Vector2 = prediction.path_points[prediction.path_points.size() - 1]
		var start_point: Vector2 = prediction.path_points[point_index]
		var direction: Vector2 = end_point - start_point
		if direction.length_squared() > 0.001:
			return direction.normalized()
		point_index -= 1

	return preview_drag_vector.normalized()


func _get_path_fade_ratio(segment_index: int, segment_count: int) -> float:
	if segment_count <= 1:
		return 0.0
	return float(segment_index) / float(segment_count - 1)


func _get_bank_segment_start_index(prediction: AimPrediction) -> int:
	if prediction.rail_position == Vector2.ZERO:
		return -1

	for point_index in range(prediction.path_points.size() - 1):
		var segment_start: Vector2 = prediction.path_points[point_index]
		var segment_end: Vector2 = prediction.path_points[point_index + 1]
		var segment: Vector2 = segment_end - segment_start
		if segment.length_squared() <= 0.001:
			continue

		var rail_projection: float = clamp((prediction.rail_position - segment_start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var closest_point: Vector2 = segment_start + segment * rail_projection
		if closest_point.distance_to(prediction.rail_position) <= 4.0:
			return point_index + 1

	return -1


func _get_high_power_pulse() -> float:
	if preview_power_ratio <= 0.7:
		return 0.0
	return sin(Time.get_ticks_msec() * 0.001 * AIM_LINE_HIGH_POWER_PULSE_SPEED) * 0.5 + 0.5


func _draw_predicted_bank_debug(prediction: AimPrediction) -> void:
	if not DEBUG_BANK_PREDICTION or prediction.rail_normal == Vector2.ZERO:
		return

	var predicted_color := Color(0.4, 0.95, 1.0, 0.85)
	var reflected_color := Color(0.92, 0.5, 1.0, 0.75)
	draw_circle(prediction.rail_position, 6.0, predicted_color)
	draw_line(prediction.rail_position, prediction.rail_position + prediction.post_bank_direction * 42.0, reflected_color, 2.2)


func _draw_bank_debug_markers() -> void:
	if not _bank_debug_visuals_enabled():
		return

	for marker in bank_debug_markers:
		var fade: float = clamp(marker.remaining_time / BANK_DEBUG_MARKER_LIFETIME, 0.0, 1.0)
		var hit_color := Color(0.42, 0.9, 1.0, 0.8 * fade)
		var incoming_color := Color(1.0, 0.44, 0.32, 0.78 * fade)
		var outgoing_color := Color(0.4, 1.0, 0.56, 0.78 * fade)
		var normal_color := Color(1.0, 0.95, 0.42, 0.72 * fade)
		draw_circle(marker.position, 6.0, hit_color)
		draw_line(marker.position, marker.position - marker.incoming_direction * 34.0, incoming_color, 2.0)
		draw_line(marker.position, marker.position + marker.outgoing_direction * 34.0, outgoing_color, 2.0)
		draw_line(marker.position, marker.position + marker.normal * 24.0, normal_color, 1.8)


func _draw_aim_path_comparison_debug() -> void:
	if not debug_aim_path_comparison_enabled or aim_path_debug_timer <= 0.0:
		return

	var fade: float = clamp(aim_path_debug_timer / AIM_PATH_DEBUG_LIFETIME, 0.0, 1.0)
	_draw_debug_path(last_predicted_aim_path, Color(0.24, 0.92, 1.0, 0.65 * fade), 2.0)
	_draw_debug_path(actual_cue_path, Color(1.0, 0.38, 0.22, 0.82 * fade), 2.4)
	_draw_predicted_rail_comparison_marker(fade)


func _draw_debug_path(path_points: Array[Vector2], color: Color, width: float) -> void:
	if path_points.size() < 2:
		return

	for point_index in range(path_points.size() - 1):
		draw_line(path_points[point_index], path_points[point_index + 1], color, width)

	for point in path_points:
		draw_circle(point, 2.5, color)


func _draw_predicted_rail_comparison_marker(fade: float) -> void:
	if last_predicted_rail_normal == Vector2.ZERO:
		return

	var rail_color := Color(0.25, 0.95, 1.0, 0.9 * fade)
	var normal_color := Color(1.0, 0.95, 0.28, 0.75 * fade)
	var post_bank_color := Color(0.95, 0.42, 1.0, 0.75 * fade)
	draw_circle(last_predicted_rail_position, 7.0, rail_color)
	draw_line(last_predicted_rail_position, last_predicted_rail_position + last_predicted_rail_normal * 30.0, normal_color, 2.0)
	draw_line(last_predicted_rail_position, last_predicted_rail_position + last_predicted_post_bank_direction * 44.0, post_bank_color, 2.2)


func _get_first_aim_collision(origin: Vector2, initial_velocity: Vector2) -> AimPrediction:
	var prediction: AimPrediction = AimPrediction.new()
	prediction.path_points = [origin]
	if initial_velocity == Vector2.ZERO:
		prediction.position = origin
		return prediction

	var simulated_position: Vector2 = origin
	var simulated_velocity: Vector2 = initial_velocity
	var traveled_distance := 0.0
	var bounce_count := 0
	var step_delta: float = AIM_SIMULATION_FRAME_DELTA / float(table.PHYSICS_SUBSTEPS)

	while traveled_distance < AIM_PREDICTION_MAX_DISTANCE and simulated_velocity.length() > table.cue_ball.stop_threshold:
		var previous_position: Vector2 = simulated_position
		var movement_end: Vector2 = simulated_position + simulated_velocity * step_delta
		var ball_hit: AimBallHit = _get_first_aim_ball_hit_on_segment(previous_position, movement_end)
		if ball_hit.ball != null:
			return _make_ball_prediction_from_position(prediction, simulated_velocity, ball_hit.ball, ball_hit.position)

		var step_result: BallMotionState = _simulate_aim_cue_step(movement_end, simulated_velocity, step_delta)
		simulated_position = step_result.position
		simulated_velocity = step_result.velocity
		_append_prediction_path_point(prediction, simulated_position)
		traveled_distance += previous_position.distance_to(simulated_position)

		if step_result.hit_rail:
			if bounce_count == 0:
				_set_prediction_rail_debug(prediction, step_result)
			bounce_count += 1
			if bounce_count > AIM_SIMULATION_MAX_BOUNCES:
				break

	prediction.collision_type = "rail" if bounce_count > 0 else "none"
	prediction.position = simulated_position
	_append_prediction_path_point(prediction, simulated_position)
	return prediction


func _simulate_aim_cue_step(moved_position: Vector2, velocity: Vector2, delta: float) -> BallMotionState:
	var step_result: BallMotionState = BallMotionState.new()
	step_result.position = moved_position
	step_result.velocity = velocity

	for boundary_shape in table.boundary_system.get_boundary_shapes():
		table.boundary_system.resolve_motion_state_against_shape(
			step_result,
			boundary_shape,
			table.cue_ball.radius,
			table.RAIL_RESTITUTION
		)

	step_result.velocity = _apply_prediction_friction(table.cue_ball, step_result.velocity, delta)
	return step_result


func _simulate_aim_target_step(target_ball: Ball, moved_position: Vector2, velocity: Vector2, delta: float) -> BallMotionState:
	var step_result: BallMotionState = BallMotionState.new()
	step_result.position = moved_position
	step_result.velocity = velocity

	for boundary_shape in table.boundary_system.get_boundary_shapes():
		table.boundary_system.resolve_motion_state_against_shape(
			step_result,
			boundary_shape,
			target_ball.radius,
			table.RAIL_RESTITUTION
		)

	step_result.velocity = _apply_prediction_friction(target_ball, step_result.velocity, delta)
	return step_result


func _apply_prediction_friction(ball: Ball, velocity: Vector2, delta: float) -> Vector2:
	var speed: float = velocity.length()
	if speed <= 0.0:
		return Vector2.ZERO

	var effective_friction: float = ball._get_effective_friction(speed)
	var updated_velocity: Vector2 = velocity.move_toward(Vector2.ZERO, effective_friction * delta)
	return Vector2.ZERO if updated_velocity.length() < ball.stop_threshold else updated_velocity


func _get_first_aim_ball_hit_on_segment(segment_start: Vector2, segment_end: Vector2) -> AimBallHit:
	return _get_first_ball_hit_on_segment(segment_start, segment_end, table.cue_ball.radius, table.cue_ball, null)


func _get_first_target_ball_hit_on_segment(segment_start: Vector2, segment_end: Vector2, target_ball: Ball) -> AimBallHit:
	return _get_first_ball_hit_on_segment(segment_start, segment_end, target_ball.radius, table.cue_ball, target_ball)


func _get_first_target_pocket_hit_on_segment(segment_start: Vector2, segment_end: Vector2, target_ball: Ball) -> AimPocketHit:
	var nearest_hit: AimPocketHit = AimPocketHit.new()
	if table == null or table.pocket_system == null:
		return nearest_hit

	var pocket_positions: Array = table.pocket_system.get_pocket_positions()
	var pocket_radii: Array = table.pocket_system.pocket_radii
	var pocket_count: int = min(pocket_positions.size(), pocket_radii.size())
	if pocket_count <= 0:
		return nearest_hit

	var segment: Vector2 = segment_end - segment_start
	var segment_length: float = segment.length()
	if segment_length <= 0.001:
		return nearest_hit

	for pocket_index in range(pocket_count):
		var catch_radius: float = _get_prediction_pocket_catch_radius(pocket_radii[pocket_index], target_ball.radius)
		var hit_fraction: float = _get_segment_circle_hit_fraction(
			segment_start,
			segment,
			pocket_positions[pocket_index],
			catch_radius
		)
		if hit_fraction < 0.0:
			continue

		var hit_distance: float = hit_fraction * segment_length
		if hit_distance < nearest_hit.distance:
			nearest_hit.pocket_index = pocket_index
			nearest_hit.distance = hit_distance
			nearest_hit.position = segment_start + segment * hit_fraction

	return nearest_hit


func _get_prediction_pocket_catch_radius(pocket_radius: float, ball_radius: float) -> float:
	return pocket_radius + ball_radius * 0.5 + PocketSystem.POCKET_CATCH_BONUS


func _get_first_ball_hit_on_segment(
	segment_start: Vector2,
	segment_end: Vector2,
	moving_ball_radius: float,
	ignored_ball_a: Ball,
	ignored_ball_b: Ball
) -> AimBallHit:
	var nearest_hit: AimBallHit = AimBallHit.new()
	var segment: Vector2 = segment_end - segment_start
	var segment_length: float = segment.length()
	if segment_length <= 0.001:
		return nearest_hit

	for child in table.balls.get_children():
		var target_ball: Ball = child as Ball
		if (
			target_ball == null
			or target_ball == ignored_ball_a
			or target_ball == ignored_ball_b
			or not target_ball.is_gameplay_active()
		):
			continue

		var combined_radius: float = moving_ball_radius + target_ball.radius + table.BALL_COLLISION_SKIN
		var hit_fraction: float = _get_segment_circle_hit_fraction(
			segment_start,
			segment,
			target_ball.global_position,
			combined_radius
		)
		if hit_fraction < 0.0:
			continue

		var hit_distance: float = hit_fraction * segment_length
		if hit_distance < nearest_hit.distance:
			nearest_hit.ball = target_ball
			nearest_hit.distance = hit_distance
			nearest_hit.position = segment_start + segment * hit_fraction

	return nearest_hit


func _get_segment_circle_hit_fraction(
	segment_start: Vector2,
	segment: Vector2,
	circle_center: Vector2,
	circle_radius: float
) -> float:
	var start_to_center: Vector2 = segment_start - circle_center
	var a: float = segment.length_squared()
	var b: float = 2.0 * start_to_center.dot(segment)
	var c: float = start_to_center.length_squared() - circle_radius * circle_radius

	if c <= 0.0:
		return 0.0

	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0 or a <= 0.001:
		return -1.0

	var sqrt_discriminant: float = sqrt(discriminant)
	var first_fraction: float = (-b - sqrt_discriminant) / (2.0 * a)
	if first_fraction >= 0.0 and first_fraction <= 1.0:
		return first_fraction

	var second_fraction: float = (-b + sqrt_discriminant) / (2.0 * a)
	if second_fraction >= 0.0 and second_fraction <= 1.0:
		return second_fraction

	return -1.0


func _make_ball_prediction_from_position(
	prediction: AimPrediction,
	incoming_velocity: Vector2,
	target_ball: Ball,
	cue_center_at_impact: Vector2
) -> AimPrediction:
	var target_direction: Vector2 = target_ball.global_position - cue_center_at_impact
	if target_direction.length() > 0.0:
		target_direction = target_direction.normalized()
	else:
		target_direction = incoming_velocity.normalized()

	var predicted_target_velocity: Vector2 = _get_predicted_target_velocity(incoming_velocity, target_ball, target_direction)

	prediction.collision_type = "ball"
	prediction.position = cue_center_at_impact
	prediction.ball = target_ball
	prediction.target_direction = target_direction
	var target_prediction: AimTargetPath = _get_predicted_target_path(target_ball, predicted_target_velocity)
	prediction.target_path_points = target_prediction.points
	prediction.target_ends_in_pocket = target_prediction.ends_in_pocket
	prediction.path_points.append(cue_center_at_impact)
	return prediction


func _get_predicted_target_velocity(incoming_velocity: Vector2, target_ball: Ball, target_direction: Vector2) -> Vector2:
	if target_direction.length_squared() <= 0.001:
		return Vector2.ZERO

	var relative_velocity: Vector2 = incoming_velocity - target_ball.velocity
	var speed_along_normal: float = relative_velocity.dot(target_direction)
	if speed_along_normal <= 0.0:
		return Vector2.ZERO

	var impulse_strength: float = (1.0 + table.BALL_COLLISION_RESTITUTION) * speed_along_normal * 0.5
	impulse_strength *= table.BALL_VELOCITY_TRANSFER
	return target_ball.velocity + target_direction * impulse_strength


func _get_predicted_target_path(target_ball: Ball, starting_velocity: Vector2) -> AimTargetPath:
	var target_prediction: AimTargetPath = AimTargetPath.new()
	target_prediction.points.append(target_ball.global_position)

	var simulated_position: Vector2 = target_ball.global_position
	var simulated_velocity: Vector2 = starting_velocity
	var travel_distance := 0.0
	var step_delta: float = AIM_SIMULATION_FRAME_DELTA / float(table.PHYSICS_SUBSTEPS)

	for _step_index in range(AIM_TARGET_PREDICTION_MAX_STEPS):
		var speed: float = simulated_velocity.length()
		if speed <= target_ball.stop_threshold or travel_distance >= AIM_TARGET_PREDICTION_MAX_DISTANCE:
			break

		var previous_position: Vector2 = simulated_position
		var movement_end: Vector2 = previous_position + simulated_velocity * step_delta
		var pocket_hit: AimPocketHit = _get_first_target_pocket_hit_on_segment(previous_position, movement_end, target_ball)
		var ball_hit: AimBallHit = _get_first_target_ball_hit_on_segment(previous_position, movement_end, target_ball)

		var step_result: BallMotionState = _simulate_aim_target_step(target_ball, movement_end, simulated_velocity, step_delta)
		var stop_type := ""
		var stop_distance := INF
		var stop_position := Vector2.ZERO
		if pocket_hit.pocket_index >= 0:
			stop_type = "pocket"
			stop_distance = pocket_hit.distance
			stop_position = pocket_hit.position
		if ball_hit.ball != null and ball_hit.distance < stop_distance - 0.001:
			stop_type = "ball"
			stop_distance = ball_hit.distance
			stop_position = ball_hit.position
		if step_result.hit_rail:
			var rail_distance: float = previous_position.distance_to(step_result.rail_position)
			if rail_distance < stop_distance - 0.001:
				stop_type = "rail"
				stop_distance = rail_distance
				stop_position = step_result.rail_position

		if stop_type != "":
			_append_target_path_point(target_prediction.points, stop_position, true)
			target_prediction.ends_in_pocket = stop_type == "pocket"
			return target_prediction

		var next_position: Vector2 = step_result.position
		travel_distance += previous_position.distance_to(next_position)
		simulated_position = next_position
		_append_target_path_point(target_prediction.points, next_position)

		simulated_velocity = step_result.velocity

	_append_target_path_point(target_prediction.points, simulated_position, true)
	return target_prediction


func _append_target_path_point(target_path: Array[Vector2], point: Vector2, force_append: bool = false) -> void:
	if target_path.is_empty():
		target_path.append(point)
		return

	var last_point: Vector2 = target_path[target_path.size() - 1]
	if last_point.distance_squared_to(point) <= 0.001:
		return
	if force_append or last_point.distance_to(point) >= AIM_TARGET_LINE_SEGMENT_LENGTH:
		target_path.append(point)


func _append_prediction_path_point(prediction: AimPrediction, point: Vector2) -> void:
	if prediction.path_points.is_empty() or prediction.path_points[prediction.path_points.size() - 1].distance_to(point) >= 2.0:
		prediction.path_points.append(point)


func _set_prediction_rail_debug(prediction: AimPrediction, step_result: BallMotionState) -> void:
	prediction.rail_position = step_result.rail_position
	prediction.rail_normal = step_result.rail_normal
	prediction.post_bank_direction = step_result.velocity.normalized()


func _update_bank_debug_markers(delta: float) -> void:
	if not _bank_debug_visuals_enabled():
		bank_debug_markers.clear()
		return

	var kept_markers: Array[BankDebugMarker] = []
	for marker in bank_debug_markers:
		marker.remaining_time -= delta
		if marker.remaining_time > 0.0:
			kept_markers.append(marker)

	bank_debug_markers = kept_markers


func _update_aim_path_comparison_debug(delta: float) -> void:
	if not debug_aim_path_comparison_enabled:
		stop_actual_path_recording()
		last_predicted_aim_path.clear()
		actual_cue_path.clear()
		last_predicted_rail_position = Vector2.ZERO
		last_predicted_rail_normal = Vector2.ZERO
		last_predicted_post_bank_direction = Vector2.ZERO
		aim_path_debug_timer = 0.0
		return

	if aim_path_debug_timer > 0.0 and not actual_cue_path_recording:
		aim_path_debug_timer = max(aim_path_debug_timer - delta, 0.0)


func _should_redraw_debug(is_dragging: bool) -> bool:
	if DEBUG_BANK_PREDICTION and (is_dragging or not bank_debug_markers.is_empty()):
		return true

	if debug_aim_path_comparison_enabled and (actual_cue_path_recording or aim_path_debug_timer > 0.0):
		return true

	return false


func _bank_debug_visuals_enabled() -> bool:
	return DEBUG_BANK_PREDICTION or debug_aim_path_comparison_enabled


func _get_aim_power_color(power_ratio: float) -> Color:
	if power_ratio <= 0.35:
		return Color("67d97d")
	if power_ratio <= 0.70:
		return Color("f0a54f")
	return Color("df5a4d")


func _elapsed_ms_since(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func _print_actual_bank_debug(
	hit_position: Vector2,
	incoming_direction: Vector2,
	outgoing_direction: Vector2,
	normal: Vector2
) -> void:
	if not _bank_debug_visuals_enabled():
		return

	print(
		"Bank debug | actual rail hit | pos=%s | incoming=%s | outgoing=%s | normal=%s" % [
			hit_position,
			incoming_direction,
			outgoing_direction,
			normal,
		]
	)


func _print_predicted_bank_debug(prediction: AimPrediction) -> void:
	if not _bank_debug_visuals_enabled():
		return

	print(
		"Bank debug | predicted path | rail_pos=%s | rail_normal=%s | post_bank_dir=%s | points=%s" % [
			prediction.rail_position,
			prediction.rail_normal,
			prediction.post_bank_direction,
			prediction.path_points.size(),
		]
	)
