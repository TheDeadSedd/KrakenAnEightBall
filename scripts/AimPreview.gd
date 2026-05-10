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
const AIM_TARGET_LINE_LENGTH := 180.0
const AIM_LINE_WIDTH := 2.0
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
	for point_index in range(prediction.path_points.size() - 1):
		draw_line(prediction.path_points[point_index], prediction.path_points[point_index + 1], aim_color, AIM_LINE_WIDTH)

	for point_index in range(1, prediction.path_points.size()):
		var marker_alpha: float = 0.55 if point_index < prediction.path_points.size() - 1 else 0.8
		draw_circle(prediction.path_points[point_index], 4.0, Color(aim_color.r, aim_color.g, aim_color.b, marker_alpha))

	_draw_predicted_bank_debug(prediction)
	if prediction.collision_type != "ball":
		return

	var target_ball: Ball = prediction.ball
	var target_end: Vector2 = target_ball.global_position + prediction.target_direction * AIM_TARGET_LINE_LENGTH
	draw_line(target_ball.global_position, target_end, Color(1.0, 0.86, 0.28, 0.75), AIM_LINE_WIDTH)
	draw_circle(target_ball.global_position, 5.0, Color(1.0, 0.86, 0.28, 0.55))


func _draw_basic_guide_line() -> void:
	var aim_direction: Vector2 = preview_drag_vector.normalized()
	var guide_length: float = min(AIM_GUIDE_LENGTH, preview_drag_vector.length() * 1.2)
	var guide_end: Vector2 = preview_origin + aim_direction * guide_length
	draw_line(preview_origin, guide_end, _get_aim_power_color(preview_power_ratio), AIM_LINE_WIDTH)


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
		return prediction

	var simulated_position: Vector2 = origin
	var simulated_velocity: Vector2 = initial_velocity
	var traveled_distance := 0.0
	var bounce_count := 0
	var step_delta: float = AIM_SIMULATION_FRAME_DELTA / float(table.PHYSICS_SUBSTEPS)

	while traveled_distance < AIM_PREDICTION_MAX_DISTANCE and simulated_velocity.length() > table.cue_ball.stop_threshold:
		var previous_position: Vector2 = simulated_position
		var movement_end: Vector2 = simulated_position + simulated_velocity * step_delta
		var ball_hit: AimBallHit = _get_first_aim_ball_hit_at_position(movement_end)
		if ball_hit.ball != null:
			var hit_direction: Vector2 = simulated_velocity.normalized()
			return _make_ball_prediction_from_position(prediction, hit_direction, ball_hit.ball, movement_end)

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

	step_result.velocity = _apply_prediction_friction(step_result.velocity, delta)
	return step_result


func _apply_prediction_friction(velocity: Vector2, delta: float) -> Vector2:
	var speed: float = velocity.length()
	if speed <= 0.0:
		return Vector2.ZERO

	var effective_friction: float = table.cue_ball._get_effective_friction(speed)
	var updated_velocity: Vector2 = velocity.move_toward(Vector2.ZERO, effective_friction * delta)
	return Vector2.ZERO if updated_velocity.length() < table.cue_ball.stop_threshold else updated_velocity


func _get_first_aim_ball_hit_at_position(cue_position: Vector2) -> AimBallHit:
	var nearest_hit: AimBallHit = AimBallHit.new()
	for child in table.balls.get_children():
		var target_ball: Ball = child as Ball
		if target_ball == null or target_ball == table.cue_ball or not target_ball.is_gameplay_active():
			continue

		var hit_distance: float = cue_position.distance_to(target_ball.global_position)
		var combined_radius: float = table.cue_ball.radius + target_ball.radius + table.BALL_COLLISION_SKIN
		if hit_distance < combined_radius and hit_distance < nearest_hit.distance:
			nearest_hit.ball = target_ball
			nearest_hit.distance = hit_distance

	return nearest_hit


func _make_ball_prediction_from_position(
	prediction: AimPrediction,
	direction: Vector2,
	target_ball: Ball,
	cue_center_at_impact: Vector2
) -> AimPrediction:
	var target_direction: Vector2 = target_ball.global_position - cue_center_at_impact
	if target_direction.length() > 0.0:
		target_direction = target_direction.normalized()
	else:
		target_direction = direction

	prediction.collision_type = "ball"
	prediction.position = cue_center_at_impact
	prediction.ball = target_ball
	prediction.target_direction = target_direction
	prediction.path_points.append(cue_center_at_impact)
	return prediction


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
