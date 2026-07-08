@tool
extends Node2D
class_name AimPreview

# Owns cue aim prediction, bank preview drawing, and shot-path debug overlays.
# Table.gd owns real balls/gameplay state; BoundarySystem owns boundary queries.

# Debug-only comparison tools.
const DEBUG_AIM_PATH_COMPARISON_DEFAULT := false
const DEBUG_BANK_PREDICTION := false

# Cue-ball guide simulation and rendering.
const AIM_GUIDE_LENGTH := 180.0
const AIM_PREDICTION_ENABLED := true
const AIM_PREDICTION_MAX_DISTANCE := 900.0
const AIM_SIMULATION_FRAME_DELTA := 1.0 / 60.0
const AIM_PREDICTION_STEP_SUBSTEPS := 2
const AIM_SIMULATION_MAX_BOUNCES := 1
const AIM_BALL_HIT_GRAZE_MARGIN := 1.25
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
const DEBUG_AIM_LINE_COLOR := Color(0.38, 0.95, 1.0, 0.92)
const DEBUG_AIM_LINE_WIDTH := 1.0
const DEBUG_AIM_CHILD_LINE_COLOR := Color(1.0, 0.78, 0.32, 0.88)
const DEBUG_AIM_ACTUAL_LINE_COLOR := Color(1.0, 0.35, 0.24, 0.9)
const DEBUG_AIM_MARKER_COLOR := Color(1.0, 0.88, 0.38, 0.95)
const DEBUG_AIM_ACTUAL_CONTACT_COLOR := Color(1.0, 0.24, 0.18, 0.96)
const DEBUG_AIM_GHOST_LINE_WIDTH := 1.0
const DEBUG_AIM_CENTER_MARKER_RADIUS := 2.0
const DEBUG_AIM_COLLISION_MARKER_RADIUS := 3.0
const DEBUG_AIM_ACTUAL_CONTACT_MARKER_RADIUS := 4.0
const DEBUG_AIM_TRACE_MAX_POINTS := 500
const DEBUG_AIM_TRACE_POINT_SPACING := 4.0
const DEBUG_AIM_TRACE_MAX_POINTS_PER_BALL := 300
const DEBUG_AIM_TRACE_MAX_TOTAL_POINTS := 1500
const DEBUG_AIM_TRACE_BALL_POINT_SPACING := 1.0
const DEBUG_AIM_COLLISION_LOG_MAX_ENTRIES := 12
const DEBUG_AIM_FIRST_HIT_CANDIDATE_MAX_ENTRIES := 32

# Struck-ball guide simulation and rendering.
const AIM_TARGET_LINE_WIDTH := 2.6
const AIM_TARGET_LINE_GLOW_WIDTH := 7.0
const AIM_TARGET_LINE_GLOW_ALPHA := 0.24
const AIM_TARGET_LINE_SEGMENT_LENGTH := 28.0
const AIM_TARGET_CURSED_CORE_COLOR := Color(0.018, 0.022, 0.026, 0.82)
const AIM_TARGET_CURSED_GLOW_COLOR := Color(0.16, 0.92, 0.72, 0.28)
const AIM_TARGET_POCKET_MARKER_COLOR := Color(0.78, 1.0, 0.82, 0.42)
const AIM_TARGET_POCKET_MARKER_RADIUS := 7.0
const AIM_TARGET_ENDPOINT_MARKER_RADIUS := 5.0
const AIM_TARGET_PREDICTION_MAX_DISTANCE := 360.0
const AIM_TARGET_PREDICTION_MAX_STEPS := 120
const AIM_TARGET_PREDICTION_STEP_SUBSTEPS := 2
const AIM_EFFECT_CHAIN_DEPTH := "aim_preview_chain_depth"
const AIM_LONG_SIGHT_FALLBACK_ENABLED := "aim_preview_long_sight_enabled"
const AIM_EFFECT_CUE_BALL_CANNON_WAKE_ENABLED := "cue_ball_cannon_wake_enabled"
const AIM_EFFECT_CUE_BALL_CANNON_WAKE_IMPACT_MULTIPLIER := "cue_ball_cannon_wake_impact_multiplier"
const AIM_LONG_SIGHT_FALLBACK_CHAIN_DEPTH := 5
const AIM_LONG_SIGHT_MAX_CHAIN_DEPTH := 8
const AIM_CHAIN_LINE_WIDTH := 1.7
const AIM_CHAIN_LINE_GLOW_WIDTH := 5.0
const AIM_CHAIN_LINE_GLOW_ALPHA := 0.15
const AIM_CHAIN_CORE_COLOR := Color(0.10, 0.56, 0.64, 0.44)
const AIM_CHAIN_GLOW_COLOR := Color(0.30, 1.0, 0.92, 0.22)
const AIM_CHAIN_ENDPOINT_MARKER_RADIUS := 3.8
const AIM_TREASURE_PERCEPTION_RADIUS := 54.0
const AIM_TREASURE_COVER_CANDIDATE_QUERY_RADIUS := 120.0
const AIM_TREASURE_OCCLUSION_DISTANCE_PADDING := 4.0
const AIM_EMBEZZLER_PERCEPTION_RADIUS := 54.0

# Bank/path comparison debug visuals.
const BANK_DEBUG_MARKER_LIFETIME := 1.0
const AIM_PATH_DEBUG_LIFETIME := 3.0
const AIM_PATH_DEBUG_MAX_POINTS := 240
const AIM_PATH_DEBUG_POINT_SPACING := 5.0

class AimPrediction:
	var collision_type := "none"
	var position := Vector2.ZERO
	var ball: Ball = null
	var target_direction := Vector2.ZERO
	var impact_incoming_direction := Vector2.ZERO
	var predicted_target_velocity := Vector2.ZERO
	var rail_hit_count_before_target: int = 0
	var cue_target_impact_segment_index: int = -1
	var target_path_points: Array[Vector2] = []
	var target_ends_in_pocket := false
	var target_prediction_steps: int = 0
	var target_first_stop_reason: String = "inactive"
	var target_path_length: float = 0.0
	var target_first_hit_ball: Ball = null
	var target_first_hit_position := Vector2.ZERO
	var target_incoming_velocity_at_stop := Vector2.ZERO
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
	var steps: int = 0
	var first_stop_reason: String = "inactive"
	var path_length: float = 0.0
	var first_hit_ball: Ball = null
	var first_hit_position := Vector2.ZERO
	var incoming_velocity_at_stop := Vector2.ZERO

class AimChainLink:
	var ball: Ball = null
	var path_points: Array[Vector2] = []
	var ends_in_pocket := false
	var first_stop_reason := "inactive"
	var path_length := 0.0
	var next_ball: Ball = null
	var incoming_velocity_at_stop := Vector2.ZERO
	var predicted_next_velocity := Vector2.ZERO

class DebugAimShotOverlay:
	var predicted_launch_position := Vector2.ZERO
	var predicted_launch_velocity := Vector2.ZERO
	var has_actual_launch := false
	var actual_launch_position := Vector2.ZERO
	var actual_launch_velocity := Vector2.ZERO
	var predicted_cue_path: Array[Vector2] = []
	var predicted_cue_contact_position := Vector2.ZERO
	var has_predicted_cue_contact := false
	var predicted_child_path: Array[Vector2] = []
	var predicted_child_marker_position := Vector2.ZERO
	var has_predicted_child_marker := false
	var predicted_child_radius := 10.0
	var predicted_hit_ball_id := -1
	var predicted_hit_ball_number := -1
	var predicted_impact_normal := Vector2.ZERO
	var predicted_impact_incoming_direction := Vector2.ZERO
	var predicted_target_outgoing_velocity := Vector2.ZERO
	var predicted_distance_to_first_hit := -1.0
	var predicted_cut_angle_degrees := 0.0
	var cue_radius := 10.0
	var target_radius := 10.0
	var actual_cue_path: Array[Vector2] = []
	var actual_ball_traces: Dictionary = {}
	var actual_first_contact_position := Vector2.ZERO
	var actual_first_cue_center := Vector2.ZERO
	var actual_first_object_center := Vector2.ZERO
	var has_actual_first_contact := false
	var actual_hit_ball_id := -1
	var actual_hit_ball_number := -1
	var actual_impact_normal := Vector2.ZERO
	var actual_incoming_cue_direction := Vector2.ZERO
	var actual_cue_speed_at_contact := 0.0
	var actual_target_outgoing_velocity := Vector2.ZERO
	var actual_distance_to_first_hit := -1.0
	var actual_center_distance := -1.0
	var actual_cut_angle_degrees := 0.0
	var first_contact_time_msec := -1
	var first_contact_physics_frame := -1
	var collision_log: Array[String] = []
	var first_hit_candidate_log: Array[Dictionary] = []
	var first_hit_selected_ball_id := -1
	var first_hit_selected_ball_number := -1

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
var preview_initial_velocity := Vector2.ZERO
var preview_power_ratio := 0.0
var current_prediction: AimPrediction
var active_effect_snapshot: Dictionary = {}
var long_sight_chain_links: Array[AimChainLink] = []
var bank_debug_markers: Array[BankDebugMarker] = []
var last_predicted_aim_path: Array[Vector2] = []
var last_predicted_rail_position := Vector2.ZERO
var last_predicted_rail_normal := Vector2.ZERO
var last_predicted_post_bank_direction := Vector2.ZERO
var actual_cue_path: Array[Vector2] = []
var aim_path_debug_timer := 0.0
var actual_cue_path_recording := false
var debug_aim_path_comparison_enabled := DEBUG_AIM_PATH_COMPARISON_DEFAULT
var debug_aim_line_enabled := false
var debug_persisted_shot: DebugAimShotOverlay
var debug_actual_trace_recording := false
var prediction_ms := 0.0
var prediction_frame_ms := 0.0
var prediction_recalculations_this_frame := 0
var cue_prediction_steps_this_frame := 0
var target_prediction_steps_this_frame := 0
var ball_collision_checks_this_frame := 0
var pocket_checks_this_frame := 0
var rail_checks_this_frame := 0
var aim_spatial_cells := 0
var aim_spatial_balls := 0
var aim_spatial_treasure_balls := 0
var aim_spatial_embezzler_balls := 0
var aim_spatial_query_cells_this_frame := 0
var aim_spatial_candidates_this_frame := 0
var treasure_perception_epoch := 0
var treasure_perception_rebuilds_this_frame := 0
var treasure_perception_checks_this_frame := 0
var embezzler_perception_epoch := 0
var embezzler_perception_rebuilds_this_frame := 0
var embezzler_perception_checks_this_frame := 0
var _treasure_last_rebuild_checks := 0
var _treasure_perceived_ball_ids: Array[int] = []
var _treasure_seen_entries: Array[Dictionary] = []
var _treasure_cover_candidate_entries: Array[Dictionary] = []
var _treasure_visibility_debug_entries: Array[Dictionary] = []
var _treasure_aim_path_points: Array[Vector2] = []
var _treasure_aim_origin := Vector2.ZERO
var _treasure_aim_direction := Vector2.ZERO
var _embezzler_last_rebuild_checks := 0
var _embezzler_perceived_ball_ids: Array[int] = []
var _embezzler_seen_entries: Array[Dictionary] = []
var _embezzler_cover_candidate_entries: Array[Dictionary] = []
var _embezzler_visibility_debug_entries: Array[Dictionary] = []
var _embezzler_aim_path_points: Array[Vector2] = []
var _embezzler_aim_origin := Vector2.ZERO
var _embezzler_aim_direction := Vector2.ZERO
var draw_ms_last_draw := 0.0
var draw_segments_last_draw := 0
var draw_calls_last_draw := 0
var _draw_segments_in_progress := 0
var _draw_calls_in_progress := 0
var _aim_ball_spatial_grid: Dictionary = {}
var _aim_spatial_cell_size := 56.0
var _aim_spatial_max_ball_radius := 0.0
var _debug_first_hit_candidate_log: Array[Dictionary] = []
var _debug_first_hit_selected_ball_id := -1
var _debug_first_hit_selected_ball_number := -1


#region Setup / Public API
func setup(table_ref) -> void:
	table = table_ref


func update_preview(
	active: bool,
	origin: Vector2,
	drag_vector: Vector2,
	shot_power: float,
	power_ratio: float,
	effect_snapshot: Dictionary = {}
) -> void:
	active_effect_snapshot = effect_snapshot.duplicate(true)
	if not active:
		prediction_ms = 0.0
		_aim_ball_spatial_grid.clear()
		long_sight_chain_links.clear()
		aim_spatial_cells = 0
		aim_spatial_balls = 0
		aim_spatial_treasure_balls = 0
		aim_spatial_embezzler_balls = 0
		draw_ms_last_draw = 0.0
		draw_segments_last_draw = 0
		draw_calls_last_draw = 0
		if preview_active or current_prediction != null:
			preview_active = false
			current_prediction = null
			_rebuild_treasure_perception_snapshot(null)
			_rebuild_embezzler_perception_snapshot(null)
			queue_redraw()
		return

	preview_active = true
	preview_origin = origin
	preview_drag_vector = drag_vector
	preview_initial_velocity = drag_vector * shot_power
	preview_power_ratio = power_ratio

	var aim_start_usec: int = Time.get_ticks_usec()
	_rebuild_aim_ball_spatial_grid()
	_reset_debug_first_hit_candidate_log()
	current_prediction = _get_first_aim_collision(origin, drag_vector * shot_power)
	_finalize_debug_first_hit_candidate_selection(current_prediction)
	_rebuild_long_sight_chain(current_prediction)
	_rebuild_treasure_perception_snapshot(current_prediction)
	_rebuild_embezzler_perception_snapshot(current_prediction)
	prediction_ms = _elapsed_ms_since(aim_start_usec)
	prediction_frame_ms += prediction_ms
	prediction_recalculations_this_frame += 1
	queue_redraw()


func update_debug(delta: float, is_dragging: bool) -> void:
	_update_bank_debug_markers(delta)
	_update_aim_path_comparison_debug(delta)
	if _should_redraw_debug(is_dragging):
		queue_redraw()


func start_path_comparison(origin: Vector2, initial_velocity: Vector2) -> void:
	if not debug_aim_path_comparison_enabled and not debug_aim_line_enabled:
		return

	_rebuild_aim_ball_spatial_grid()
	_reset_debug_first_hit_candidate_log()
	var prediction: AimPrediction = _get_first_aim_collision(origin, initial_velocity)
	_finalize_debug_first_hit_candidate_selection(prediction)
	if debug_aim_line_enabled:
		debug_persisted_shot = _make_debug_shot_overlay(prediction, origin, initial_velocity)
		debug_persisted_shot.actual_cue_path.clear()
		debug_persisted_shot.actual_cue_path.append(origin)
		debug_actual_trace_recording = true

	if debug_aim_path_comparison_enabled:
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


func report_debug_actual_first_contact(
	contact_position: Vector2,
	cue_center: Vector2,
	object_center: Vector2,
	object_ball: Ball,
	cue_velocity_before_contact: Vector2,
	target_velocity_after_contact: Vector2,
	center_distance: float
) -> void:
	if (
		not debug_aim_line_enabled
		or not debug_actual_trace_recording
		or debug_persisted_shot == null
		or debug_persisted_shot.has_actual_first_contact
	):
		return

	debug_persisted_shot.actual_first_contact_position = contact_position
	debug_persisted_shot.actual_first_cue_center = cue_center
	debug_persisted_shot.actual_first_object_center = object_center
	debug_persisted_shot.has_actual_first_contact = true
	if object_ball != null and is_instance_valid(object_ball):
		debug_persisted_shot.actual_hit_ball_id = object_ball.get_instance_id()
		debug_persisted_shot.actual_hit_ball_number = object_ball.ball_number
	debug_persisted_shot.actual_impact_normal = (object_center - cue_center).normalized()
	debug_persisted_shot.actual_incoming_cue_direction = cue_velocity_before_contact.normalized()
	debug_persisted_shot.actual_cue_speed_at_contact = cue_velocity_before_contact.length()
	debug_persisted_shot.actual_target_outgoing_velocity = target_velocity_after_contact
	debug_persisted_shot.actual_distance_to_first_hit = _get_polyline_distance_to_point(
		debug_persisted_shot.actual_cue_path,
		cue_center
	)
	debug_persisted_shot.actual_center_distance = center_distance
	debug_persisted_shot.actual_cut_angle_degrees = _get_unsigned_angle_delta_degrees(
		debug_persisted_shot.actual_incoming_cue_direction,
		debug_persisted_shot.actual_impact_normal
	)
	debug_persisted_shot.first_contact_time_msec = Time.get_ticks_msec()
	debug_persisted_shot.first_contact_physics_frame = Engine.get_physics_frames()
	_append_debug_actual_path_point(cue_center, true)
	queue_redraw()


func report_debug_actual_launch(launch_position: Vector2, launch_velocity: Vector2) -> void:
	if not debug_aim_line_enabled or debug_persisted_shot == null:
		return
	debug_persisted_shot.has_actual_launch = true
	debug_persisted_shot.actual_launch_position = launch_position
	debug_persisted_shot.actual_launch_velocity = launch_velocity
	_append_debug_actual_path_point(launch_position, true)
	_record_debug_all_ball_paths()
	queue_redraw()


func report_debug_collision_event(
	ball_a: Ball,
	ball_b: Ball,
	normal: Vector2,
	impact_speed: float
) -> void:
	if not debug_aim_line_enabled or debug_persisted_shot == null:
		return
	if impact_speed <= 0.0:
		return
	var line: String = "%s -> %s | normal %.1f deg | speed %.0f" % [
		_get_debug_ball_label(ball_a),
		_get_debug_ball_label(ball_b),
		_get_vector_angle_degrees(normal),
		impact_speed,
	]
	_append_debug_collision_log(line)


func report_debug_rail_event(ball: Ball, normal: Vector2, speed: float) -> void:
	if not debug_aim_line_enabled or debug_persisted_shot == null:
		return
	var line: String = "%s -> Rail | normal %.1f deg | speed %.0f" % [
		_get_debug_ball_label(ball),
		_get_vector_angle_degrees(normal),
		speed,
	]
	_append_debug_collision_log(line)


func note_actual_cue_pocketed(ball: Ball) -> void:
	if debug_aim_line_enabled and ball == table.cue_ball and debug_actual_trace_recording:
		_append_debug_actual_path_point(table.cue_ball.global_position, true)
		debug_actual_trace_recording = false
		queue_redraw()

	if not debug_aim_path_comparison_enabled or ball != table.cue_ball or not actual_cue_path_recording:
		return

	actual_cue_path.append(table.cue_ball.global_position)
	stop_actual_path_recording()
	print("Bank debug | actual cue pocketed | pos=%s" % table.cue_ball.global_position)


func record_actual_path_step() -> void:
	_record_debug_actual_path_step()

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


func stop_debug_aim_actual_trace() -> void:
	if not debug_actual_trace_recording:
		return
	if debug_persisted_shot != null and is_instance_valid(table.cue_ball):
		_append_debug_actual_path_point(table.cue_ball.global_position, true)
	debug_actual_trace_recording = false
	queue_redraw()


func set_shot_path_debug_enabled(enabled: bool) -> void:
	debug_aim_path_comparison_enabled = enabled
	if not enabled:
		stop_actual_path_recording()
		aim_path_debug_timer = 0.0
		queue_redraw()


func is_shot_path_debug_enabled() -> bool:
	return debug_aim_path_comparison_enabled


func set_debug_aim_line_enabled(enabled: bool) -> void:
	if debug_aim_line_enabled == enabled:
		return
	debug_aim_line_enabled = enabled
	if not debug_aim_line_enabled:
		debug_persisted_shot = null
		debug_actual_trace_recording = false
		_reset_debug_first_hit_candidate_log()
	queue_redraw()


func is_debug_aim_line_enabled() -> bool:
	return debug_aim_line_enabled


func is_prediction_enabled() -> bool:
	return AIM_PREDICTION_ENABLED


func get_prediction_time_ms() -> float:
	return prediction_ms


func _make_debug_shot_overlay(
	prediction: AimPrediction,
	launch_position: Vector2,
	launch_velocity: Vector2
) -> DebugAimShotOverlay:
	var overlay: DebugAimShotOverlay = DebugAimShotOverlay.new()
	overlay.predicted_launch_position = launch_position
	overlay.predicted_launch_velocity = launch_velocity
	overlay.cue_radius = _get_debug_cue_ball_radius()
	overlay.first_hit_candidate_log = _copy_debug_first_hit_candidate_log()
	overlay.first_hit_selected_ball_id = _debug_first_hit_selected_ball_id
	overlay.first_hit_selected_ball_number = _debug_first_hit_selected_ball_number
	if prediction == null:
		return overlay

	overlay.predicted_cue_path = _copy_vector2_points(prediction.path_points)
	overlay.has_predicted_cue_contact = prediction.collision_type == "ball"
	if overlay.has_predicted_cue_contact:
		overlay.predicted_cue_contact_position = prediction.position
		overlay.predicted_distance_to_first_hit = _get_polyline_distance_to_point(prediction.path_points, prediction.position)
		overlay.predicted_impact_normal = prediction.target_direction
		overlay.predicted_impact_incoming_direction = prediction.impact_incoming_direction
		overlay.predicted_target_outgoing_velocity = prediction.predicted_target_velocity
		overlay.predicted_cut_angle_degrees = _get_unsigned_angle_delta_degrees(
			prediction.impact_incoming_direction,
			prediction.target_direction
		)
		if prediction.ball != null and is_instance_valid(prediction.ball):
			overlay.predicted_hit_ball_id = prediction.ball.get_instance_id()
			overlay.predicted_hit_ball_number = prediction.ball.ball_number
			overlay.target_radius = prediction.ball.radius
	overlay.predicted_child_path = _copy_vector2_points(prediction.target_path_points)
	if prediction.ball != null and is_instance_valid(prediction.ball):
		overlay.predicted_child_radius = prediction.ball.radius
	overlay.has_predicted_child_marker = prediction.target_path_points.size() > 0
	if overlay.has_predicted_child_marker:
		if prediction.target_first_stop_reason == "ball" and prediction.target_first_hit_position != Vector2.ZERO:
			overlay.predicted_child_marker_position = prediction.target_first_hit_position
		else:
			overlay.predicted_child_marker_position = prediction.target_path_points[prediction.target_path_points.size() - 1]
	return overlay


func _copy_vector2_points(points: Array[Vector2]) -> Array[Vector2]:
	var copied_points: Array[Vector2] = []
	for point in points:
		copied_points.append(point)
	return copied_points


func _copy_debug_first_hit_candidate_log() -> Array[Dictionary]:
	var copied_entries: Array[Dictionary] = []
	for entry_value in _debug_first_hit_candidate_log:
		var entry: Dictionary = entry_value
		copied_entries.append(entry.duplicate(true))
	return copied_entries


func _reset_debug_first_hit_candidate_log() -> void:
	_debug_first_hit_candidate_log.clear()
	_debug_first_hit_selected_ball_id = -1
	_debug_first_hit_selected_ball_number = -1


func _finalize_debug_first_hit_candidate_selection(prediction: AimPrediction) -> void:
	if not debug_aim_line_enabled:
		return
	if prediction != null and prediction.ball != null and is_instance_valid(prediction.ball):
		_debug_first_hit_selected_ball_id = prediction.ball.get_instance_id()
		_debug_first_hit_selected_ball_number = prediction.ball.ball_number
	else:
		_debug_first_hit_selected_ball_id = -1
		_debug_first_hit_selected_ball_number = -1

	for entry_index in range(_debug_first_hit_candidate_log.size()):
		var entry: Dictionary = _debug_first_hit_candidate_log[entry_index]
		entry["selected"] = int(entry.get("ball_id", -1)) == _debug_first_hit_selected_ball_id
		_debug_first_hit_candidate_log[entry_index] = entry


func _record_debug_actual_path_step() -> void:
	if (
		not debug_aim_line_enabled
		or not debug_actual_trace_recording
		or debug_persisted_shot == null
	):
		return

	if not is_instance_valid(table.cue_ball) or not table.cue_ball.is_gameplay_active():
		debug_actual_trace_recording = false
		queue_redraw()
		return

	_append_debug_actual_path_point(table.cue_ball.global_position)
	_record_debug_all_ball_paths()
	if debug_persisted_shot.actual_cue_path.size() >= DEBUG_AIM_TRACE_MAX_POINTS:
		debug_actual_trace_recording = false
	queue_redraw()


func _append_debug_actual_path_point(position: Vector2, force_append: bool = false) -> void:
	if debug_persisted_shot == null:
		return
	if debug_persisted_shot.actual_cue_path.size() >= DEBUG_AIM_TRACE_MAX_POINTS:
		return
	if debug_persisted_shot.actual_cue_path.is_empty():
		debug_persisted_shot.actual_cue_path.append(position)
		return

	var last_point: Vector2 = debug_persisted_shot.actual_cue_path[debug_persisted_shot.actual_cue_path.size() - 1]
	if force_append or last_point.distance_to(position) >= DEBUG_AIM_TRACE_POINT_SPACING:
		debug_persisted_shot.actual_cue_path.append(position)


func _record_debug_all_ball_paths() -> void:
	if debug_persisted_shot == null or table == null or table.balls == null:
		return
	for child in table.balls.get_children():
		var ball: Ball = child as Ball
		if not _should_record_debug_ball_trace(ball):
			continue
		if ball == table.cue_ball:
			continue
		_append_debug_ball_trace_point(ball)


func _should_record_debug_ball_trace(ball: Ball) -> bool:
	if ball == null or not is_instance_valid(ball):
		return false
	if ball.is_queued_for_deletion():
		return false
	if not ball.is_gameplay_active():
		return false
	return ball.is_moving()


func _append_debug_ball_trace_point(ball: Ball) -> void:
	var trace_key: int = ball.get_instance_id()
	var trace: Dictionary = debug_persisted_shot.actual_ball_traces.get(trace_key, {})
	if trace.is_empty():
		trace = {
			"label": _get_debug_ball_label(ball),
			"ball_number": ball.ball_number,
			"is_cue": ball == table.cue_ball,
			"points": [],
		}
		debug_persisted_shot.actual_ball_traces[trace_key] = trace

	var points: Array = trace.get("points", [])
	if points.size() >= DEBUG_AIM_TRACE_MAX_POINTS_PER_BALL:
		return
	if _get_debug_total_trace_points() >= DEBUG_AIM_TRACE_MAX_TOTAL_POINTS:
		return
	if points.is_empty():
		points.append(ball.global_position)
	else:
		var last_point_value: Variant = points[points.size() - 1]
		if last_point_value is Vector2:
			var last_point: Vector2 = last_point_value
			if last_point.distance_to(ball.global_position) >= DEBUG_AIM_TRACE_BALL_POINT_SPACING:
				points.append(ball.global_position)
	trace["points"] = points


func _append_debug_collision_log(line: String) -> void:
	debug_persisted_shot.collision_log.append(line)
	while debug_persisted_shot.collision_log.size() > DEBUG_AIM_COLLISION_LOG_MAX_ENTRIES:
		debug_persisted_shot.collision_log.pop_front()


func _get_debug_total_trace_points() -> int:
	if debug_persisted_shot == null:
		return 0
	var total_points: int = debug_persisted_shot.actual_cue_path.size()
	for trace_value in debug_persisted_shot.actual_ball_traces.values():
		if not trace_value is Dictionary:
			continue
		var trace: Dictionary = trace_value
		var points: Array = trace.get("points", [])
		total_points += points.size()
	return total_points


func _get_debug_ball_label(ball: Ball) -> String:
	if ball == null or not is_instance_valid(ball):
		return "Ball ?"
	if table != null and ball == table.cue_ball:
		return "Cue"
	if table != null and ball == table.eight_ball:
		return "8 Ball"
	if ball.is_wayfinder:
		return "Wayfinder"
	if ball.is_powder_keg:
		return "Powder"
	if ball.is_cannon_ball:
		return "Cannon"
	if ball.is_treasure_ball:
		return "Treasure"
	if ball.is_embezzler_ball:
		return "Embezzler"
	return "Ball %s" % ball.ball_number


func _get_debug_aim_compare_snapshot() -> Dictionary:
	var overlay: DebugAimShotOverlay = _get_active_debug_compare_overlay()
	var active_source: String = "none"
	if debug_aim_line_enabled and preview_active and current_prediction != null:
		active_source = "live"
	elif overlay != null:
		active_source = "persisted"

	var trace_summary: Dictionary = _get_debug_trace_summary(overlay)
	var launch_snapshot: Dictionary = _get_debug_launch_snapshot(overlay)
	var contact_snapshot: Dictionary = _get_debug_contact_snapshot(overlay)
	var response_snapshot: Dictionary = _get_debug_response_snapshot(overlay)
	return {
		"source": active_source,
		"debug_aim_line_enabled": debug_aim_line_enabled,
		"persisted_overlay": debug_persisted_shot != null,
		"recording_actual_trace": debug_actual_trace_recording,
		"launch": launch_snapshot,
		"contact": contact_snapshot,
		"response": response_snapshot,
		"trace": trace_summary,
		"verdict": _get_debug_mismatch_verdict(launch_snapshot, contact_snapshot, response_snapshot),
	}


func _get_active_debug_compare_overlay() -> DebugAimShotOverlay:
	if debug_aim_line_enabled and preview_active and current_prediction != null:
		return _make_debug_shot_overlay(current_prediction, preview_origin, preview_initial_velocity)
	return debug_persisted_shot


func _get_debug_launch_snapshot(overlay: DebugAimShotOverlay) -> Dictionary:
	var predicted_velocity := Vector2.ZERO
	var actual_velocity := Vector2.ZERO
	var has_predicted := overlay != null and overlay.predicted_launch_velocity.length_squared() > 0.001
	var has_actual := overlay != null and overlay.has_actual_launch
	if overlay != null:
		predicted_velocity = overlay.predicted_launch_velocity
		actual_velocity = overlay.actual_launch_velocity
	var predicted_direction: Vector2 = predicted_velocity.normalized()
	var actual_direction: Vector2 = actual_velocity.normalized()
	return {
		"has_predicted": has_predicted,
		"has_actual": has_actual,
		"predicted_position": overlay.predicted_launch_position if overlay != null else Vector2.ZERO,
		"actual_position": overlay.actual_launch_position if overlay != null else Vector2.ZERO,
		"predicted_velocity": predicted_velocity,
		"actual_velocity": actual_velocity,
		"predicted_direction": predicted_direction,
		"actual_direction": actual_direction,
		"predicted_angle": _get_vector_angle_degrees(predicted_velocity),
		"actual_angle": _get_vector_angle_degrees(actual_velocity),
		"angle_delta": _get_signed_angle_delta_degrees(predicted_velocity, actual_velocity),
		"direction_dot": predicted_direction.dot(actual_direction) if has_predicted and has_actual else 0.0,
		"predicted_speed": predicted_velocity.length(),
		"actual_speed": actual_velocity.length(),
		"speed_delta": actual_velocity.length() - predicted_velocity.length(),
	}


func _get_debug_contact_snapshot(overlay: DebugAimShotOverlay) -> Dictionary:
	var predicted_contact_point: Vector2 = _get_predicted_contact_point(overlay)
	var actual_contact_point: Vector2 = overlay.actual_first_contact_position if overlay != null else Vector2.ZERO
	var predicted_center: Vector2 = overlay.predicted_cue_contact_position if overlay != null else Vector2.ZERO
	var actual_center: Vector2 = overlay.actual_first_cue_center if overlay != null else Vector2.ZERO
	var predicted_normal: Vector2 = overlay.predicted_impact_normal if overlay != null else Vector2.ZERO
	var actual_normal: Vector2 = overlay.actual_impact_normal if overlay != null else Vector2.ZERO
	return {
		"has_predicted": overlay != null and overlay.has_predicted_cue_contact,
		"has_actual": overlay != null and overlay.has_actual_first_contact,
		"predicted_hit_ball_id": overlay.predicted_hit_ball_id if overlay != null else -1,
		"predicted_hit_ball_number": overlay.predicted_hit_ball_number if overlay != null else -1,
		"actual_hit_ball_id": overlay.actual_hit_ball_id if overlay != null else -1,
		"actual_hit_ball_number": overlay.actual_hit_ball_number if overlay != null else -1,
		"predicted_cue_center": predicted_center,
		"actual_cue_center": actual_center,
		"cue_center_delta": predicted_center.distance_to(actual_center) if overlay != null and overlay.has_predicted_cue_contact and overlay.has_actual_first_contact else -1.0,
		"predicted_contact_point": predicted_contact_point,
		"actual_contact_point": actual_contact_point,
		"contact_point_delta": predicted_contact_point.distance_to(actual_contact_point) if overlay != null and overlay.has_predicted_cue_contact and overlay.has_actual_first_contact else -1.0,
		"predicted_normal": predicted_normal,
		"actual_normal": actual_normal,
		"predicted_normal_angle": _get_vector_angle_degrees(predicted_normal),
		"actual_normal_angle": _get_vector_angle_degrees(actual_normal),
		"normal_angle_delta": _get_signed_angle_delta_degrees(predicted_normal, actual_normal),
		"predicted_cut_angle": overlay.predicted_cut_angle_degrees if overlay != null else 0.0,
		"actual_cut_angle": overlay.actual_cut_angle_degrees if overlay != null else 0.0,
		"cut_angle_delta": (overlay.actual_cut_angle_degrees - overlay.predicted_cut_angle_degrees) if overlay != null and overlay.has_predicted_cue_contact and overlay.has_actual_first_contact else 0.0,
	}


func _get_debug_response_snapshot(overlay: DebugAimShotOverlay) -> Dictionary:
	var predicted_velocity: Vector2 = overlay.predicted_target_outgoing_velocity if overlay != null else Vector2.ZERO
	var actual_velocity: Vector2 = overlay.actual_target_outgoing_velocity if overlay != null else Vector2.ZERO
	var expected_center_distance: float = (overlay.cue_radius + overlay.target_radius) if overlay != null else -1.0
	var actual_center_distance: float = overlay.actual_center_distance if overlay != null else -1.0
	return {
		"has_predicted": overlay != null and overlay.has_predicted_cue_contact,
		"has_actual": overlay != null and overlay.has_actual_first_contact,
		"predicted_outgoing_angle": _get_vector_angle_degrees(predicted_velocity),
		"actual_outgoing_angle": _get_vector_angle_degrees(actual_velocity),
		"outgoing_angle_delta": _get_signed_angle_delta_degrees(predicted_velocity, actual_velocity),
		"predicted_speed": predicted_velocity.length(),
		"actual_speed": actual_velocity.length(),
		"speed_delta": actual_velocity.length() - predicted_velocity.length(),
		"predicted_distance_to_first_hit": overlay.predicted_distance_to_first_hit if overlay != null else -1.0,
		"actual_distance_to_first_hit": overlay.actual_distance_to_first_hit if overlay != null else -1.0,
		"distance_delta": (overlay.actual_distance_to_first_hit - overlay.predicted_distance_to_first_hit) if overlay != null and overlay.actual_distance_to_first_hit >= 0.0 and overlay.predicted_distance_to_first_hit >= 0.0 else 0.0,
		"expected_center_distance": expected_center_distance,
		"actual_center_distance": actual_center_distance,
		"overlap_gap": actual_center_distance - expected_center_distance if actual_center_distance >= 0.0 and expected_center_distance >= 0.0 else 0.0,
		"cue_radius": overlay.cue_radius if overlay != null else 0.0,
		"target_radius": overlay.target_radius if overlay != null else 0.0,
	}


func _get_debug_trace_summary(overlay: DebugAimShotOverlay) -> Dictionary:
	var collision_log: Array[String] = []
	var actual_balls_tracked := 0
	var total_points := 0
	var cue_points := 0
	var first_contact_time := -1
	var first_contact_frame := -1
	var first_hit_candidates: Array[Dictionary] = []
	var first_hit_selected_ball_id := -1
	var first_hit_selected_ball_number := -1
	if overlay != null:
		for log_line in overlay.collision_log:
			collision_log.append(log_line)
		for candidate_entry_value in overlay.first_hit_candidate_log:
			var candidate_entry: Dictionary = candidate_entry_value
			first_hit_candidates.append(candidate_entry.duplicate(true))
		first_hit_selected_ball_id = overlay.first_hit_selected_ball_id
		first_hit_selected_ball_number = overlay.first_hit_selected_ball_number
		cue_points = overlay.actual_cue_path.size()
		total_points = cue_points
		first_contact_time = overlay.first_contact_time_msec
		first_contact_frame = overlay.first_contact_physics_frame
		for trace_value in overlay.actual_ball_traces.values():
			if not trace_value is Dictionary:
				continue
			var trace: Dictionary = trace_value
			var points: Array = trace.get("points", [])
			if points.size() > 0:
				actual_balls_tracked += 1
				total_points += points.size()
		if cue_points > 0:
			actual_balls_tracked += 1
	return {
		"actual_balls_tracked": actual_balls_tracked,
		"total_trace_points": total_points,
		"cue_trace_points": cue_points,
		"first_contact_time_msec": first_contact_time,
		"first_contact_physics_frame": first_contact_frame,
		"collision_log": collision_log,
		"first_hit_candidates": first_hit_candidates,
		"first_hit_selected_ball_id": first_hit_selected_ball_id,
		"first_hit_selected_ball_number": first_hit_selected_ball_number,
	}


func _get_debug_mismatch_verdict(
	launch_snapshot: Dictionary,
	contact_snapshot: Dictionary,
	response_snapshot: Dictionary
) -> String:
	if not bool(launch_snapshot.get("has_predicted", false)):
		return "no prediction"
	if not bool(launch_snapshot.get("has_actual", false)):
		return "awaiting shot"
	if absf(float(launch_snapshot.get("angle_delta", 0.0))) > 0.5:
		return "launch mismatch"
	if not bool(contact_snapshot.get("has_actual", false)):
		return "no actual contact recorded"
	if int(contact_snapshot.get("predicted_hit_ball_id", -1)) != int(contact_snapshot.get("actual_hit_ball_id", -1)):
		return "predicted wrong first ball"
	if float(contact_snapshot.get("cue_center_delta", -1.0)) > 2.0:
		return "launch matches, contact late"
	if absf(float(contact_snapshot.get("normal_angle_delta", 0.0))) > 2.0:
		return "normal mismatch"
	if absf(float(response_snapshot.get("outgoing_angle_delta", 0.0))) > 3.0:
		return "contact matches, response mismatch"
	return "launch/contact match"


func _get_predicted_contact_point(overlay: DebugAimShotOverlay) -> Vector2:
	if overlay == null or not overlay.has_predicted_cue_contact:
		return Vector2.ZERO
	return overlay.predicted_cue_contact_position + overlay.predicted_impact_normal * overlay.cue_radius


func _get_polyline_distance_to_point(points: Array[Vector2], point: Vector2) -> float:
	if points.is_empty():
		return -1.0
	var total_distance := 0.0
	for point_index in range(points.size() - 1):
		var start_point: Vector2 = points[point_index]
		var end_point: Vector2 = points[point_index + 1]
		var segment_distance: float = start_point.distance_to(end_point)
		if end_point.distance_squared_to(point) <= 1.0:
			return total_distance + segment_distance
		total_distance += segment_distance
	return total_distance


func _get_vector_angle_degrees(vector: Vector2) -> float:
	if vector.length_squared() <= 0.001:
		return 0.0
	return rad_to_deg(vector.angle())


func _get_signed_angle_delta_degrees(from_vector: Vector2, to_vector: Vector2) -> float:
	if from_vector.length_squared() <= 0.001 or to_vector.length_squared() <= 0.001:
		return 0.0
	return rad_to_deg(wrapf(to_vector.angle() - from_vector.angle(), -PI, PI))


func _get_unsigned_angle_delta_degrees(from_vector: Vector2, to_vector: Vector2) -> float:
	return absf(_get_signed_angle_delta_degrees(from_vector, to_vector))


func reset_frame_stats() -> void:
	prediction_frame_ms = 0.0
	prediction_recalculations_this_frame = 0
	cue_prediction_steps_this_frame = 0
	target_prediction_steps_this_frame = 0
	ball_collision_checks_this_frame = 0
	pocket_checks_this_frame = 0
	rail_checks_this_frame = 0
	aim_spatial_query_cells_this_frame = 0
	aim_spatial_candidates_this_frame = 0
	treasure_perception_rebuilds_this_frame = 0
	treasure_perception_checks_this_frame = 0
	embezzler_perception_rebuilds_this_frame = 0
	embezzler_perception_checks_this_frame = 0


func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"debug_aim_line_enabled": debug_aim_line_enabled,
		"debug_aim_actual_trace_recording": debug_actual_trace_recording,
		"debug_aim_persisted_overlay": debug_persisted_shot != null,
		"debug_aim_actual_points": debug_persisted_shot.actual_cue_path.size() if debug_persisted_shot != null else 0,
		"debug_aim_has_actual_first_contact": debug_persisted_shot.has_actual_first_contact if debug_persisted_shot != null else false,
		"aim_compare": _get_debug_aim_compare_snapshot(),
		"prediction_ms": prediction_ms,
		"prediction_frame_ms": prediction_frame_ms,
		"prediction_recalculations": prediction_recalculations_this_frame,
		"cue_prediction_steps": cue_prediction_steps_this_frame,
		"target_prediction_steps": target_prediction_steps_this_frame,
		"ball_collision_checks": ball_collision_checks_this_frame,
		"pocket_checks": pocket_checks_this_frame,
		"rail_checks": rail_checks_this_frame,
		"spatial_cells": aim_spatial_cells,
		"spatial_balls": aim_spatial_balls,
		"spatial_treasure_balls": aim_spatial_treasure_balls,
		"spatial_embezzler_balls": aim_spatial_embezzler_balls,
		"spatial_query_cells": aim_spatial_query_cells_this_frame,
		"spatial_candidates": aim_spatial_candidates_this_frame,
		"treasure_perception_epoch": treasure_perception_epoch,
		"treasure_perception_rebuilds": treasure_perception_rebuilds_this_frame,
		"treasure_perception_checks": treasure_perception_checks_this_frame,
		"long_sight_chain_depth": _get_active_aim_chain_depth(),
		"long_sight_chain_links": long_sight_chain_links.size(),
		"draw_ms": draw_ms_last_draw,
		"draw_segments": draw_segments_last_draw,
		"draw_calls": draw_calls_last_draw,
	}
	snapshot.merge(_get_hit_ball_prediction_debug_snapshot())
	return snapshot


func get_treasure_perception_snapshot() -> Dictionary:
	return {
		"epoch": treasure_perception_epoch,
		"rebuilds_this_frame": treasure_perception_rebuilds_this_frame,
		"checks_this_frame": treasure_perception_checks_this_frame,
		"last_rebuild_checks": _treasure_last_rebuild_checks,
		"aim_origin": _treasure_aim_origin,
		"aim_direction": _treasure_aim_direction,
		"aim_path_points": _treasure_aim_path_points.duplicate(),
		"seen_treasure_ball_ids": _treasure_perceived_ball_ids.duplicate(),
		"seen_treasure_balls": _treasure_seen_entries.duplicate(),
		"cover_candidates": _treasure_cover_candidate_entries.duplicate(),
		"visibility_debug_entries": _treasure_visibility_debug_entries.duplicate(),
	}


func get_embezzler_perception_snapshot() -> Dictionary:
	return {
		"epoch": embezzler_perception_epoch,
		"rebuilds_this_frame": embezzler_perception_rebuilds_this_frame,
		"checks_this_frame": embezzler_perception_checks_this_frame,
		"last_rebuild_checks": _embezzler_last_rebuild_checks,
		"aim_origin": _embezzler_aim_origin,
		"aim_direction": _embezzler_aim_direction,
		"aim_path_points": _embezzler_aim_path_points.duplicate(),
		"seen_embezzler_ball_ids": _embezzler_perceived_ball_ids.duplicate(),
		"seen_embezzler_balls": _embezzler_seen_entries.duplicate(),
		"cover_candidates": _embezzler_cover_candidate_entries.duplicate(),
		"visibility_debug_entries": _embezzler_visibility_debug_entries.duplicate(),
	}


func _get_hit_ball_prediction_debug_snapshot() -> Dictionary:
	var prediction: AimPrediction = current_prediction
	var hit_prediction_active: bool = (
		preview_active
		and prediction != null
		and prediction.collision_type == "ball"
		and is_instance_valid(prediction.ball)
	)
	if not hit_prediction_active:
		return {
			"hit_ball_prediction_active": false,
			"hit_ball_target_ball_id": -1,
			"hit_ball_target_number": -1,
			"hit_ball_route": "none",
			"hit_ball_impact_point": Vector2.ZERO,
			"hit_ball_impact_normal": Vector2.ZERO,
			"hit_ball_impact_incoming_direction": Vector2.ZERO,
			"hit_ball_transferred_velocity": Vector2.ZERO,
			"hit_ball_transferred_direction": Vector2.ZERO,
			"hit_ball_target_prediction_steps": 0,
			"hit_ball_target_first_stop_reason": "inactive",
			"hit_ball_target_path_length": 0.0,
			"hit_ball_target_path_point_count": 0,
			"hit_ball_rail_hits_before_impact": 0,
			"hit_ball_cue_impact_segment_index": -1,
		}

	var transferred_direction: Vector2 = Vector2.ZERO
	if prediction.predicted_target_velocity.length_squared() > 0.001:
		transferred_direction = prediction.predicted_target_velocity.normalized()

	return {
		"hit_ball_prediction_active": true,
		"hit_ball_target_ball_id": prediction.ball.get_instance_id(),
		"hit_ball_target_number": prediction.ball.ball_number,
		"hit_ball_route": "after_rail" if prediction.rail_hit_count_before_target > 0 else "direct",
		"hit_ball_impact_point": prediction.position,
		"hit_ball_impact_normal": prediction.target_direction,
		"hit_ball_impact_incoming_direction": prediction.impact_incoming_direction,
		"hit_ball_transferred_velocity": prediction.predicted_target_velocity,
		"hit_ball_transferred_direction": transferred_direction,
		"hit_ball_target_prediction_steps": prediction.target_prediction_steps,
		"hit_ball_target_first_stop_reason": prediction.target_first_stop_reason,
		"hit_ball_target_path_length": prediction.target_path_length,
		"hit_ball_target_path_point_count": prediction.target_path_points.size(),
		"hit_ball_rail_hits_before_impact": prediction.rail_hit_count_before_target,
		"hit_ball_cue_impact_segment_index": prediction.cue_target_impact_segment_index,
	}
#endregion


#region Drawing
func _draw() -> void:
	var draw_start_usec: int = Time.get_ticks_usec()
	_draw_segments_in_progress = 0
	_draw_calls_in_progress = 0
	_draw_bank_debug_markers()
	_draw_aim_path_comparison_debug()
	if not preview_active:
		if debug_aim_line_enabled:
			_draw_debug_persisted_overlay()
		_store_draw_stats(draw_start_usec)
		return

	if AIM_PREDICTION_ENABLED and current_prediction != null:
		if debug_aim_line_enabled:
			_draw_debug_aim_line(current_prediction)
		else:
			_draw_prediction(current_prediction)
	else:
		if debug_aim_line_enabled:
			_draw_debug_basic_guide_line()
		else:
			_draw_basic_guide_line()
	_store_draw_stats(draw_start_usec)


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
	_draw_long_sight_chain()


func _draw_basic_guide_line() -> void:
	var aim_direction: Vector2 = preview_drag_vector.normalized()
	var guide_length: float = min(AIM_GUIDE_LENGTH, preview_drag_vector.length() * 1.2)
	var guide_end: Vector2 = preview_origin + aim_direction * guide_length
	_draw_aim_line_segment(preview_origin, guide_end, _get_aim_power_color(preview_power_ratio), 1.0, 1.0)
	_draw_aim_end_marker(guide_end, aim_direction, _get_aim_power_color(preview_power_ratio))


func _draw_debug_aim_line(prediction: AimPrediction) -> void:
	if prediction == null or prediction.path_points.size() < 2:
		_draw_debug_basic_guide_line()
		return

	_draw_debug_prediction_data(
		prediction.path_points,
		prediction.collision_type == "ball",
		prediction.position,
		prediction.target_path_points,
		prediction.target_path_points.size() > 0,
		_get_debug_child_marker_position(prediction),
		_get_debug_prediction_child_radius(prediction)
	)


func _draw_debug_basic_guide_line() -> void:
	if preview_drag_vector.length_squared() <= 0.001:
		return

	var aim_direction: Vector2 = preview_drag_vector.normalized()
	var guide_length: float = min(AIM_GUIDE_LENGTH, preview_drag_vector.length() * 1.2)
	var guide_end: Vector2 = preview_origin + aim_direction * guide_length
	_draw_segments_in_progress += 1
	_draw_calls_in_progress += 2
	draw_line(preview_origin, guide_end, DEBUG_AIM_LINE_COLOR, DEBUG_AIM_LINE_WIDTH, false)
	draw_circle(preview_origin, DEBUG_AIM_CENTER_MARKER_RADIUS, DEBUG_AIM_MARKER_COLOR)


func _draw_debug_persisted_overlay() -> void:
	if debug_persisted_shot == null:
		return
	_draw_debug_prediction_data(
		debug_persisted_shot.predicted_cue_path,
		debug_persisted_shot.has_predicted_cue_contact,
		debug_persisted_shot.predicted_cue_contact_position,
		debug_persisted_shot.predicted_child_path,
		debug_persisted_shot.has_predicted_child_marker,
		debug_persisted_shot.predicted_child_marker_position,
		debug_persisted_shot.predicted_child_radius
	)
	_draw_debug_actual_trace(debug_persisted_shot)


func _draw_debug_prediction_data(
	cue_path: Array[Vector2],
	has_cue_contact: bool,
	cue_contact_position: Vector2,
	child_path: Array[Vector2],
	has_child_marker: bool,
	child_marker_position: Vector2,
	child_radius: float
) -> void:
	_draw_debug_polyline(cue_path, DEBUG_AIM_LINE_COLOR, DEBUG_AIM_LINE_WIDTH)
	if not cue_path.is_empty():
		_draw_calls_in_progress += 1
		draw_circle(cue_path[0], DEBUG_AIM_CENTER_MARKER_RADIUS, DEBUG_AIM_MARKER_COLOR)
	if has_cue_contact:
		_draw_debug_ghost_ball(cue_contact_position, _get_debug_cue_ball_radius(), DEBUG_AIM_LINE_COLOR)
		_draw_calls_in_progress += 1
		draw_circle(cue_contact_position, DEBUG_AIM_COLLISION_MARKER_RADIUS, DEBUG_AIM_MARKER_COLOR)

	if child_path.size() >= 2:
		_draw_debug_polyline(child_path, DEBUG_AIM_CHILD_LINE_COLOR, DEBUG_AIM_LINE_WIDTH)
	if has_child_marker:
		_draw_debug_ghost_ball(child_marker_position, child_radius, DEBUG_AIM_CHILD_LINE_COLOR)
		_draw_calls_in_progress += 1
		draw_circle(child_marker_position, DEBUG_AIM_COLLISION_MARKER_RADIUS, DEBUG_AIM_CHILD_LINE_COLOR)


func _draw_debug_actual_trace(overlay: DebugAimShotOverlay) -> void:
	if overlay == null:
		return
	_draw_debug_actual_ball_traces(overlay)
	_draw_debug_polyline(overlay.actual_cue_path, DEBUG_AIM_ACTUAL_LINE_COLOR, DEBUG_AIM_LINE_WIDTH)
	if not overlay.has_actual_first_contact:
		return

	_draw_calls_in_progress += 3
	draw_line(
		overlay.actual_first_contact_position - Vector2(DEBUG_AIM_ACTUAL_CONTACT_MARKER_RADIUS, 0.0),
		overlay.actual_first_contact_position + Vector2(DEBUG_AIM_ACTUAL_CONTACT_MARKER_RADIUS, 0.0),
		DEBUG_AIM_ACTUAL_CONTACT_COLOR,
		DEBUG_AIM_LINE_WIDTH,
		false
	)
	draw_line(
		overlay.actual_first_contact_position - Vector2(0.0, DEBUG_AIM_ACTUAL_CONTACT_MARKER_RADIUS),
		overlay.actual_first_contact_position + Vector2(0.0, DEBUG_AIM_ACTUAL_CONTACT_MARKER_RADIUS),
		DEBUG_AIM_ACTUAL_CONTACT_COLOR,
		DEBUG_AIM_LINE_WIDTH,
		false
	)
	draw_circle(overlay.actual_first_contact_position, DEBUG_AIM_CENTER_MARKER_RADIUS, DEBUG_AIM_ACTUAL_CONTACT_COLOR)


func _draw_debug_actual_ball_traces(overlay: DebugAimShotOverlay) -> void:
	for trace_value in overlay.actual_ball_traces.values():
		if not trace_value is Dictionary:
			continue
		var trace: Dictionary = trace_value
		var raw_points: Array = trace.get("points", [])
		var points: Array[Vector2] = []
		for point_value in raw_points:
			if point_value is Vector2:
				points.append(point_value)
		if points.size() < 2:
			continue
		_draw_debug_polyline(points, Color(0.96, 0.68, 0.28, 0.58), DEBUG_AIM_LINE_WIDTH)


func _draw_debug_polyline(points: Array[Vector2], color: Color, width: float) -> void:
	if points.size() < 2:
		return
	for point_index in range(points.size() - 1):
		var start_point: Vector2 = points[point_index]
		var end_point: Vector2 = points[point_index + 1]
		if start_point.distance_squared_to(end_point) <= 0.001:
			continue
		_draw_segments_in_progress += 1
		_draw_calls_in_progress += 1
		draw_line(start_point, end_point, color, width, false)


func _draw_debug_ghost_ball(center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	_draw_calls_in_progress += 1
	draw_arc(center, radius, 0.0, PI * 2.0, 48, color, DEBUG_AIM_GHOST_LINE_WIDTH, false)


func _get_debug_child_marker_position(prediction: AimPrediction) -> Vector2:
	if prediction == null or prediction.target_path_points.is_empty():
		return Vector2.ZERO
	if prediction.target_first_stop_reason == "ball" and prediction.target_first_hit_position != Vector2.ZERO:
		return prediction.target_first_hit_position
	return prediction.target_path_points[prediction.target_path_points.size() - 1]


func _get_debug_cue_ball_radius() -> float:
	if table != null and is_instance_valid(table.cue_ball):
		return table.cue_ball.radius
	return 10.0


func _get_debug_prediction_child_radius(prediction: AimPrediction) -> float:
	if prediction != null and prediction.ball != null and is_instance_valid(prediction.ball):
		return prediction.ball.radius
	return _get_debug_cue_ball_radius()


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

	_draw_segments_in_progress += 1
	_draw_calls_in_progress += 2
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

	_draw_calls_in_progress += 4
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
	_draw_calls_in_progress += 2
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
	_draw_calls_in_progress += 2
	draw_circle(position, AIM_TARGET_ENDPOINT_MARKER_RADIUS * 1.85, glow_color)
	draw_circle(position, AIM_TARGET_ENDPOINT_MARKER_RADIUS, core_color)


func _draw_long_sight_chain() -> void:
	if long_sight_chain_links.is_empty():
		return

	for link_index in range(long_sight_chain_links.size()):
		var link: AimChainLink = long_sight_chain_links[link_index]
		if link == null or link.path_points.size() < 2:
			continue
		var alpha_multiplier: float = maxf(0.28, 0.76 - float(link_index) * 0.11)
		var segment_count: int = link.path_points.size() - 1
		for segment_index in range(segment_count):
			_draw_guidance_line_segment(
				link.path_points[segment_index],
				link.path_points[segment_index + 1],
				AIM_CHAIN_CORE_COLOR,
				AIM_CHAIN_GLOW_COLOR,
				_get_path_fade_ratio(segment_index, segment_count),
				alpha_multiplier,
				AIM_CHAIN_LINE_WIDTH,
				AIM_CHAIN_LINE_GLOW_WIDTH,
				AIM_CHAIN_LINE_GLOW_ALPHA
			)

		_draw_long_sight_endpoint_marker(
			link.path_points[link.path_points.size() - 1],
			link.ends_in_pocket,
			alpha_multiplier
		)


func _draw_long_sight_endpoint_marker(position: Vector2, ends_in_pocket: bool, alpha_multiplier: float) -> void:
	var marker_color := AIM_TARGET_POCKET_MARKER_COLOR if ends_in_pocket else AIM_CHAIN_CORE_COLOR
	var glow_color := Color(AIM_CHAIN_GLOW_COLOR.r, AIM_CHAIN_GLOW_COLOR.g, AIM_CHAIN_GLOW_COLOR.b, 0.11 * alpha_multiplier)
	var core_color := Color(marker_color.r, marker_color.g, marker_color.b, marker_color.a * alpha_multiplier)
	_draw_calls_in_progress += 2
	draw_circle(position, AIM_CHAIN_ENDPOINT_MARKER_RADIUS * 1.9, glow_color)
	draw_circle(position, AIM_CHAIN_ENDPOINT_MARKER_RADIUS, core_color)


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
	_draw_calls_in_progress += 2
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
		_draw_calls_in_progress += 4
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
		_draw_segments_in_progress += 1
		_draw_calls_in_progress += 1
		draw_line(path_points[point_index], path_points[point_index + 1], color, width)

	for point in path_points:
		_draw_calls_in_progress += 1
		draw_circle(point, 2.5, color)


func _draw_predicted_rail_comparison_marker(fade: float) -> void:
	if last_predicted_rail_normal == Vector2.ZERO:
		return

	var rail_color := Color(0.25, 0.95, 1.0, 0.9 * fade)
	var normal_color := Color(1.0, 0.95, 0.28, 0.75 * fade)
	var post_bank_color := Color(0.95, 0.42, 1.0, 0.75 * fade)
	_draw_calls_in_progress += 3
	draw_circle(last_predicted_rail_position, 7.0, rail_color)
	draw_line(last_predicted_rail_position, last_predicted_rail_position + last_predicted_rail_normal * 30.0, normal_color, 2.0)
	draw_line(last_predicted_rail_position, last_predicted_rail_position + last_predicted_post_bank_direction * 44.0, post_bank_color, 2.2)
#endregion


#region Prediction Simulation
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
	var step_delta: float = _get_prediction_step_delta(AIM_PREDICTION_STEP_SUBSTEPS)

	while traveled_distance < AIM_PREDICTION_MAX_DISTANCE and simulated_velocity.length() > table.cue_ball.stop_threshold:
		cue_prediction_steps_this_frame += 1
		var previous_position: Vector2 = simulated_position
		var movement_end: Vector2 = simulated_position + simulated_velocity * step_delta
		var segment_index: int = maxi(prediction.path_points.size() - 1, 0)
		var ball_hit: AimBallHit = _get_first_aim_ball_hit_on_segment(
			previous_position,
			movement_end,
			traveled_distance,
			segment_index
		)
		if ball_hit.ball != null:
			return _make_ball_prediction_from_position(
				prediction,
				simulated_velocity,
				ball_hit.ball,
				ball_hit.position,
				bounce_count,
				segment_index
			)

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


func _rebuild_long_sight_chain(prediction: AimPrediction) -> void:
	long_sight_chain_links.clear()
	var chain_depth: int = _get_active_aim_chain_depth()
	if chain_depth <= 1 or prediction == null or prediction.collision_type != "ball":
		return
	if not is_instance_valid(prediction.ball) or prediction.target_first_stop_reason != "ball":
		return

	var previous_moving_ball: Ball = prediction.ball
	var target_path := _make_target_path_from_prediction(prediction)
	var remaining_links: int = chain_depth - 1
	while remaining_links > 0:
		var link: AimChainLink = _make_long_sight_chain_link(previous_moving_ball, target_path)
		if link == null:
			return

		long_sight_chain_links.append(link)
		remaining_links -= 1
		if link.first_stop_reason != "ball" or not is_instance_valid(link.next_ball):
			return

		previous_moving_ball = link.ball
		target_path = _make_target_path_from_link(link)


func _make_target_path_from_prediction(prediction: AimPrediction) -> AimTargetPath:
	var target_path: AimTargetPath = AimTargetPath.new()
	target_path.points = prediction.target_path_points.duplicate()
	target_path.ends_in_pocket = prediction.target_ends_in_pocket
	target_path.steps = prediction.target_prediction_steps
	target_path.first_stop_reason = prediction.target_first_stop_reason
	target_path.path_length = prediction.target_path_length
	target_path.first_hit_ball = prediction.target_first_hit_ball
	target_path.first_hit_position = prediction.target_first_hit_position
	target_path.incoming_velocity_at_stop = prediction.target_incoming_velocity_at_stop
	return target_path


func _make_target_path_from_link(link: AimChainLink) -> AimTargetPath:
	var target_path: AimTargetPath = AimTargetPath.new()
	target_path.points = link.path_points.duplicate()
	target_path.ends_in_pocket = link.ends_in_pocket
	target_path.first_stop_reason = link.first_stop_reason
	target_path.path_length = link.path_length
	target_path.first_hit_ball = link.next_ball
	if link.path_points.size() > 0:
		target_path.first_hit_position = link.path_points[link.path_points.size() - 1]
	target_path.incoming_velocity_at_stop = link.incoming_velocity_at_stop
	return target_path


func _make_long_sight_chain_link(previous_moving_ball: Ball, previous_path: AimTargetPath) -> AimChainLink:
	if previous_path == null or not is_instance_valid(previous_path.first_hit_ball):
		return null
	if not is_instance_valid(previous_moving_ball):
		return null

	var next_ball: Ball = previous_path.first_hit_ball
	var hit_position: Vector2 = previous_path.first_hit_position
	var incoming_velocity: Vector2 = previous_path.incoming_velocity_at_stop
	if incoming_velocity.length_squared() <= 0.001:
		return null

	var target_direction: Vector2 = next_ball.global_position - hit_position
	if target_direction.length_squared() > 0.001:
		target_direction = target_direction.normalized()
	else:
		target_direction = incoming_velocity.normalized()

	var predicted_next_velocity: Vector2 = _get_predicted_target_velocity(incoming_velocity, next_ball, target_direction)
	if predicted_next_velocity.length_squared() <= 0.001:
		return null

	var next_path: AimTargetPath = _get_predicted_target_path(next_ball, predicted_next_velocity, previous_moving_ball)
	if next_path.points.size() < 2:
		return null

	var link: AimChainLink = AimChainLink.new()
	link.ball = next_ball
	link.path_points = next_path.points.duplicate()
	link.ends_in_pocket = next_path.ends_in_pocket
	link.first_stop_reason = next_path.first_stop_reason
	link.path_length = next_path.path_length
	link.next_ball = next_path.first_hit_ball
	link.incoming_velocity_at_stop = next_path.incoming_velocity_at_stop
	link.predicted_next_velocity = predicted_next_velocity
	return link


func _get_active_aim_chain_depth() -> int:
	var depth := clampi(int(active_effect_snapshot.get(AIM_EFFECT_CHAIN_DEPTH, 0)), 0, AIM_LONG_SIGHT_MAX_CHAIN_DEPTH)
	if depth > 0:
		return depth
	if bool(active_effect_snapshot.get(AIM_LONG_SIGHT_FALLBACK_ENABLED, false)):
		return AIM_LONG_SIGHT_FALLBACK_CHAIN_DEPTH
	return 0


func _rebuild_treasure_perception_snapshot(prediction: AimPrediction) -> void:
	_treasure_perceived_ball_ids.clear()
	_treasure_seen_entries.clear()
	_treasure_cover_candidate_entries.clear()
	_treasure_visibility_debug_entries.clear()
	_treasure_aim_path_points.clear()
	_treasure_aim_origin = Vector2.ZERO
	_treasure_aim_direction = Vector2.ZERO
	_treasure_last_rebuild_checks = 0
	if prediction != null and prediction.path_points.size() >= 2:
		_treasure_aim_origin = preview_origin
		_treasure_aim_direction = preview_drag_vector.normalized()
		_treasure_aim_path_points = prediction.path_points.duplicate()
		_rebuild_treasure_corridor_perception(prediction.path_points)

	treasure_perception_checks_this_frame += _treasure_last_rebuild_checks
	treasure_perception_rebuilds_this_frame += 1
	treasure_perception_epoch += 1


func _rebuild_embezzler_perception_snapshot(prediction: AimPrediction) -> void:
	_embezzler_perceived_ball_ids.clear()
	_embezzler_seen_entries.clear()
	_embezzler_cover_candidate_entries.clear()
	_embezzler_visibility_debug_entries.clear()
	_embezzler_aim_path_points.clear()
	_embezzler_aim_origin = Vector2.ZERO
	_embezzler_aim_direction = Vector2.ZERO
	_embezzler_last_rebuild_checks = 0
	if prediction != null and prediction.path_points.size() >= 2:
		_embezzler_aim_origin = preview_origin
		_embezzler_aim_direction = preview_drag_vector.normalized()
		_embezzler_aim_path_points = prediction.path_points.duplicate()
		_rebuild_embezzler_corridor_perception(prediction.path_points)

	embezzler_perception_checks_this_frame += _embezzler_last_rebuild_checks
	embezzler_perception_rebuilds_this_frame += 1
	embezzler_perception_epoch += 1


func _get_prediction_step_delta(step_substeps: int) -> float:
	# AimPreview uses coarser visual-prediction steps than real physics, while
	# swept ball/pocket checks keep fast paths from skipping collision targets.
	return AIM_SIMULATION_FRAME_DELTA / float(maxi(step_substeps, 1))


func _simulate_aim_cue_step(moved_position: Vector2, velocity: Vector2, delta: float) -> BallMotionState:
	var step_result: BallMotionState = BallMotionState.new()
	step_result.position = moved_position
	step_result.velocity = velocity

	for boundary_shape in table.boundary_system.get_boundary_shapes():
		rail_checks_this_frame += 1
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
		rail_checks_this_frame += 1
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


func _get_first_aim_ball_hit_on_segment(
	segment_start: Vector2,
	segment_end: Vector2,
	path_distance_before_segment: float,
	segment_index: int
) -> AimBallHit:
	return _get_first_ball_hit_on_segment(
		segment_start,
		segment_end,
		table.cue_ball.radius,
		table.cue_ball,
		null,
		null,
		path_distance_before_segment,
		segment_index,
		true
	)


func _get_first_target_ball_hit_on_segment(
	segment_start: Vector2,
	segment_end: Vector2,
	target_ball: Ball,
	extra_ignored_ball: Ball = null
) -> AimBallHit:
	return _get_first_ball_hit_on_segment(segment_start, segment_end, target_ball.radius, table.cue_ball, target_ball, extra_ignored_ball)


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
		pocket_checks_this_frame += 1
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
	# Match PocketSystem's capture radius without mutating real pocket state.
	return pocket_radius + ball_radius * 0.5 + PocketSystem.POCKET_CATCH_BONUS


func _rebuild_aim_ball_spatial_grid() -> void:
	_aim_ball_spatial_grid.clear()
	_aim_spatial_cell_size = max(float(table.BALL_COLLISION_GRID_CELL_SIZE), 1.0)
	_aim_spatial_max_ball_radius = 0.0
	aim_spatial_balls = 0
	aim_spatial_treasure_balls = 0
	aim_spatial_embezzler_balls = 0

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.is_gameplay_active():
			continue

		var cell: Vector2i = _get_aim_spatial_cell(ball.global_position)
		if not _aim_ball_spatial_grid.has(cell):
			_aim_ball_spatial_grid[cell] = []
		_aim_ball_spatial_grid[cell].append(ball)
		_aim_spatial_max_ball_radius = max(_aim_spatial_max_ball_radius, ball.radius)
		aim_spatial_balls += 1
		if ball.is_treasure_ball:
			aim_spatial_treasure_balls += 1
		if ball.is_embezzler_ball:
			aim_spatial_embezzler_balls += 1

	aim_spatial_cells = _aim_ball_spatial_grid.size()


func _get_aim_spatial_candidates_for_segment(
	segment_start: Vector2,
	segment_end: Vector2,
	moving_ball_radius: float
) -> Array[Ball]:
	var candidates: Array[Ball] = []
	if _aim_ball_spatial_grid.is_empty():
		return candidates

	var query_padding: float = moving_ball_radius + _aim_spatial_max_ball_radius + table.BALL_COLLISION_SKIN
	var min_position := Vector2(
		min(segment_start.x, segment_end.x) - query_padding,
		min(segment_start.y, segment_end.y) - query_padding
	)
	var max_position := Vector2(
		max(segment_start.x, segment_end.x) + query_padding,
		max(segment_start.y, segment_end.y) + query_padding
	)
	var min_cell: Vector2i = _get_aim_spatial_cell(min_position)
	var max_cell: Vector2i = _get_aim_spatial_cell(max_position)
	var seen_ball_ids: Dictionary = {}

	for cell_x in range(min_cell.x, max_cell.x + 1):
		for cell_y in range(min_cell.y, max_cell.y + 1):
			aim_spatial_query_cells_this_frame += 1
			var cell := Vector2i(cell_x, cell_y)
			if not _aim_ball_spatial_grid.has(cell):
				continue

			for candidate in _aim_ball_spatial_grid[cell]:
				var ball := candidate as Ball
				if ball == null:
					continue
				var ball_id: int = ball.get_instance_id()
				if seen_ball_ids.has(ball_id):
					continue
				seen_ball_ids[ball_id] = true
				candidates.append(ball)

	aim_spatial_candidates_this_frame += candidates.size()
	return candidates


func _rebuild_treasure_corridor_perception(path_points: Array[Vector2]) -> void:
	if aim_spatial_treasure_balls <= 0:
		return

	var query_radius: float = max(AIM_TREASURE_PERCEPTION_RADIUS, AIM_TREASURE_COVER_CANDIDATE_QUERY_RADIUS)
	var path_candidate_entries: Array[Dictionary] = _get_treasure_path_candidate_entries(path_points, query_radius)
	_treasure_last_rebuild_checks = path_candidate_entries.size()
	_treasure_cover_candidate_entries = _get_treasure_cover_candidates_from_entries(path_candidate_entries)

	for candidate_entry_value in path_candidate_entries:
		var candidate_entry: Dictionary = candidate_entry_value
		if not bool(candidate_entry["is_treasure_ball"]):
			continue
		var visibility_result: Dictionary = _get_treasure_visibility_result(candidate_entry, path_candidate_entries)
		_treasure_visibility_debug_entries.append(visibility_result)
		if str(visibility_result["reason"]) != "seen":
			continue

		var ball_id: int = int(candidate_entry["ball_id"])
		_treasure_perceived_ball_ids.append(ball_id)
		_treasure_seen_entries.append({
			"ball_id": ball_id,
			"position": candidate_entry["position"],
			"radius": candidate_entry["radius"],
			"impact_position": candidate_entry["closest_point"],
			"distance_along_path": candidate_entry["distance_along_path"],
			"lateral_distance": candidate_entry["lateral_distance"],
			"visibility_reason": visibility_result["reason"],
		})


func _rebuild_embezzler_corridor_perception(path_points: Array[Vector2]) -> void:
	if aim_spatial_embezzler_balls <= 0:
		return

	var path_candidate_entries: Array[Dictionary] = _get_embezzler_path_candidate_entries(path_points, AIM_EMBEZZLER_PERCEPTION_RADIUS)
	_embezzler_last_rebuild_checks = path_candidate_entries.size()
	_embezzler_cover_candidate_entries = _get_embezzler_cover_candidates_from_entries(path_candidate_entries)

	for candidate_entry_value in path_candidate_entries:
		var candidate_entry: Dictionary = candidate_entry_value
		if not bool(candidate_entry["is_embezzler_ball"]):
			continue
		var visibility_result: Dictionary = _get_treasure_visibility_result(candidate_entry, path_candidate_entries)
		_embezzler_visibility_debug_entries.append(visibility_result)
		if str(visibility_result["reason"]) != "seen":
			continue

		var ball_id: int = int(candidate_entry["ball_id"])
		_embezzler_perceived_ball_ids.append(ball_id)
		_embezzler_seen_entries.append({
			"ball_id": ball_id,
			"position": candidate_entry["position"],
			"radius": candidate_entry["radius"],
			"impact_position": candidate_entry["closest_point"],
			"distance_along_path": candidate_entry["distance_along_path"],
			"lateral_distance": candidate_entry["lateral_distance"],
			"visibility_reason": visibility_result["reason"],
		})


func _get_treasure_path_candidate_entries(path_points: Array[Vector2], query_radius: float) -> Array[Dictionary]:
	var candidate_entries: Array[Dictionary] = []
	if path_points.size() < 2:
		return candidate_entries

	var seen_ball_ids: Dictionary = {}
	for point_index in range(path_points.size() - 1):
		var segment_start: Vector2 = path_points[point_index]
		var segment_end: Vector2 = path_points[point_index + 1]
		for candidate_ball in _get_treasure_spatial_candidates_for_segment(segment_start, segment_end, query_radius):
			if candidate_ball == null or candidate_ball == table.cue_ball or not candidate_ball.is_gameplay_active():
				continue

			var ball_id: int = candidate_ball.get_instance_id()
			if seen_ball_ids.has(ball_id):
				continue

			var projection: Dictionary = _project_point_onto_path(candidate_ball.global_position, path_points)
			if projection.is_empty():
				continue

			var lateral_distance: float = float(projection["lateral_distance"])
			if lateral_distance > query_radius + candidate_ball.radius:
				continue

			seen_ball_ids[ball_id] = true
			candidate_entries.append({
				"ball_id": ball_id,
				"position": candidate_ball.global_position,
				"radius": candidate_ball.radius,
				"is_treasure_ball": candidate_ball.is_treasure_ball,
				"closest_point": projection["closest_point"],
				"distance_along_path": projection["distance_along_path"],
				"lateral_distance": lateral_distance,
				"segment_direction": projection["segment_direction"],
			})

	return candidate_entries


func _get_embezzler_path_candidate_entries(path_points: Array[Vector2], query_radius: float) -> Array[Dictionary]:
	var candidate_entries: Array[Dictionary] = []
	if path_points.size() < 2:
		return candidate_entries

	var seen_ball_ids: Dictionary = {}
	for point_index in range(path_points.size() - 1):
		var segment_start: Vector2 = path_points[point_index]
		var segment_end: Vector2 = path_points[point_index + 1]
		for candidate_ball in _get_treasure_spatial_candidates_for_segment(segment_start, segment_end, query_radius):
			if candidate_ball == null or candidate_ball == table.cue_ball or not candidate_ball.is_gameplay_active():
				continue

			var ball_id: int = candidate_ball.get_instance_id()
			if seen_ball_ids.has(ball_id):
				continue

			var projection: Dictionary = _project_point_onto_path(candidate_ball.global_position, path_points)
			if projection.is_empty():
				continue

			var lateral_distance: float = float(projection["lateral_distance"])
			if lateral_distance > query_radius + candidate_ball.radius:
				continue

			seen_ball_ids[ball_id] = true
			candidate_entries.append({
				"ball_id": ball_id,
				"position": candidate_ball.global_position,
				"radius": candidate_ball.radius,
				"is_embezzler_ball": candidate_ball.is_embezzler_ball,
				"closest_point": projection["closest_point"],
				"distance_along_path": projection["distance_along_path"],
				"lateral_distance": lateral_distance,
				"segment_direction": projection["segment_direction"],
			})

	return candidate_entries


func _get_embezzler_cover_candidates_from_entries(path_candidate_entries: Array[Dictionary]) -> Array[Dictionary]:
	var cover_candidates: Array[Dictionary] = []
	for candidate_entry_value in path_candidate_entries:
		var candidate_entry: Dictionary = candidate_entry_value
		if bool(candidate_entry["is_embezzler_ball"]):
			continue

		cover_candidates.append({
			"ball_id": candidate_entry["ball_id"],
			"position": candidate_entry["position"],
			"radius": candidate_entry["radius"],
			"closest_point": candidate_entry["closest_point"],
			"distance_along_path": candidate_entry["distance_along_path"],
			"lateral_distance": candidate_entry["lateral_distance"],
			"segment_direction": candidate_entry["segment_direction"],
		})

	return cover_candidates


func _get_treasure_cover_candidates_from_entries(path_candidate_entries: Array[Dictionary]) -> Array[Dictionary]:
	var cover_candidates: Array[Dictionary] = []
	for candidate_entry_value in path_candidate_entries:
		var candidate_entry: Dictionary = candidate_entry_value
		if bool(candidate_entry["is_treasure_ball"]):
			continue

		cover_candidates.append({
			"ball_id": candidate_entry["ball_id"],
			"position": candidate_entry["position"],
			"radius": candidate_entry["radius"],
			"closest_point": candidate_entry["closest_point"],
			"distance_along_path": candidate_entry["distance_along_path"],
			"lateral_distance": candidate_entry["lateral_distance"],
			"segment_direction": candidate_entry["segment_direction"],
		})

	return cover_candidates


func _get_treasure_visibility_result(
	treasure_entry: Dictionary,
	path_candidate_entries: Array[Dictionary]
) -> Dictionary:
	var result: Dictionary = {
		"ball_id": treasure_entry["ball_id"],
		"reason": "seen",
		"lateral_distance": treasure_entry["lateral_distance"],
		"distance_along_path": treasure_entry["distance_along_path"],
		"blocker_ball_id": -1,
		"blocker_lateral_distance": -1.0,
		"blocker_distance_along_path": -1.0,
		"blocker_entry_distance": -1.0,
	}
	if float(treasure_entry["lateral_distance"]) > AIM_TREASURE_PERCEPTION_RADIUS:
		result["reason"] = "outside_corridor"
		return result

	var treasure_distance: float = float(treasure_entry["distance_along_path"])
	if treasure_distance <= 0.0:
		result["reason"] = "behind_origin"
		return result

	var treasure_entry_distance: float = _get_treasure_visibility_entry_distance(treasure_entry)
	var treasure_ball_id: int = int(treasure_entry["ball_id"])
	for blocker_entry_value in path_candidate_entries:
		var blocker_entry: Dictionary = blocker_entry_value
		var blocker_ball_id: int = int(blocker_entry["ball_id"])
		if blocker_ball_id == treasure_ball_id:
			continue

		var blocker_distance: float = float(blocker_entry["distance_along_path"])
		if blocker_distance <= 0.0:
			continue

		var blocker_lateral_distance: float = float(blocker_entry["lateral_distance"])
		var blocker_occlusion_radius: float = _get_treasure_occlusion_radius(blocker_entry)
		if blocker_lateral_distance > blocker_occlusion_radius:
			continue

		var blocker_entry_distance: float = _get_circle_path_entry_distance(
			blocker_distance,
			blocker_lateral_distance,
			blocker_occlusion_radius
		)
		if blocker_entry_distance >= treasure_entry_distance - AIM_TREASURE_OCCLUSION_DISTANCE_PADDING:
			continue

		result["reason"] = "occluded"
		result["blocker_ball_id"] = blocker_ball_id
		result["blocker_lateral_distance"] = blocker_lateral_distance
		result["blocker_distance_along_path"] = blocker_distance
		result["blocker_entry_distance"] = blocker_entry_distance
		return result

	return result


func _get_treasure_visibility_entry_distance(treasure_entry: Dictionary) -> float:
	var treasure_distance: float = float(treasure_entry["distance_along_path"])
	var treasure_lateral_distance: float = float(treasure_entry["lateral_distance"])
	var treasure_radius: float = float(treasure_entry["radius"]) + AIM_TREASURE_OCCLUSION_DISTANCE_PADDING
	if treasure_lateral_distance <= treasure_radius:
		return _get_circle_path_entry_distance(treasure_distance, treasure_lateral_distance, treasure_radius)

	return treasure_distance


func _get_treasure_occlusion_radius(blocker_entry: Dictionary) -> float:
	var blocker_radius: float = float(blocker_entry["radius"])
	return min(AIM_TREASURE_PERCEPTION_RADIUS, blocker_radius + AIM_TREASURE_OCCLUSION_DISTANCE_PADDING)


func _get_circle_path_entry_distance(center_distance: float, lateral_distance: float, radius: float) -> float:
	var entry_offset_squared: float = max(radius * radius - lateral_distance * lateral_distance, 0.0)
	return center_distance - sqrt(entry_offset_squared)


func _get_treasure_spatial_candidates_for_segment(
	segment_start: Vector2,
	segment_end: Vector2,
	query_radius: float
) -> Array[Ball]:
	var candidates: Array[Ball] = []
	if _aim_ball_spatial_grid.is_empty():
		return candidates

	var query_padding: float = query_radius + _aim_spatial_max_ball_radius
	var min_position := Vector2(
		min(segment_start.x, segment_end.x) - query_padding,
		min(segment_start.y, segment_end.y) - query_padding
	)
	var max_position := Vector2(
		max(segment_start.x, segment_end.x) + query_padding,
		max(segment_start.y, segment_end.y) + query_padding
	)
	var min_cell: Vector2i = _get_aim_spatial_cell(min_position)
	var max_cell: Vector2i = _get_aim_spatial_cell(max_position)

	for cell_x in range(min_cell.x, max_cell.x + 1):
		for cell_y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(cell_x, cell_y)
			if not _aim_ball_spatial_grid.has(cell):
				continue

			for candidate in _aim_ball_spatial_grid[cell]:
				var ball := candidate as Ball
				if ball != null:
					candidates.append(ball)

	return candidates


func _project_point_onto_path(point: Vector2, path_points: Array[Vector2]) -> Dictionary:
	var best_projection: Dictionary = {}
	var best_distance := INF
	var distance_before_segment := 0.0
	for point_index in range(path_points.size() - 1):
		var segment_start: Vector2 = path_points[point_index]
		var segment_end: Vector2 = path_points[point_index + 1]
		var segment: Vector2 = segment_end - segment_start
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			continue

		var raw_segment_fraction: float = (point - segment_start).dot(segment) / segment.length_squared()
		var segment_fraction: float = clamp(raw_segment_fraction, 0.0, 1.0)
		var closest_point: Vector2 = segment_start + segment * segment_fraction
		var lateral_distance: float = point.distance_to(closest_point)
		if lateral_distance < best_distance:
			best_distance = lateral_distance
			best_projection = {
				"closest_point": closest_point,
				"lateral_distance": lateral_distance,
				"distance_along_path": distance_before_segment + segment_length * raw_segment_fraction,
				"segment_direction": segment / segment_length,
			}

		distance_before_segment += segment_length

	return best_projection


func _get_aim_spatial_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / _aim_spatial_cell_size),
		floori(position.y / _aim_spatial_cell_size)
	)


func _get_first_ball_hit_on_segment(
	segment_start: Vector2,
	segment_end: Vector2,
	moving_ball_radius: float,
	ignored_ball_a: Ball,
	ignored_ball_b: Ball,
	ignored_ball_c: Ball = null,
	path_distance_before_segment: float = 0.0,
	segment_index: int = -1,
	track_debug_first_hit_candidates: bool = false
) -> AimBallHit:
	var nearest_hit: AimBallHit = AimBallHit.new()
	var segment: Vector2 = segment_end - segment_start
	var segment_length: float = segment.length()
	if segment_length <= 0.001:
		return nearest_hit

	var query_order := 0
	for target_ball in _get_aim_spatial_candidates_for_segment(segment_start, segment_end, moving_ball_radius):
		query_order += 1
		var rejection_reason := "accepted"
		var is_filtered := false
		if (
			target_ball == null
			or target_ball == ignored_ball_a
			or target_ball == ignored_ball_b
			or target_ball == ignored_ball_c
		):
			rejection_reason = "ignored"
			is_filtered = true
		elif not target_ball.is_gameplay_active():
			rejection_reason = "inactive"
			is_filtered = true

		if track_debug_first_hit_candidates:
			_append_debug_first_hit_candidate_entry(
				target_ball,
				segment_start,
				segment,
				segment_length,
				moving_ball_radius,
				path_distance_before_segment,
				segment_index,
				query_order,
				is_filtered,
				rejection_reason
			)

		if is_filtered:
			continue

		ball_collision_checks_this_frame += 1
		var combined_radius: float = _get_prediction_ball_hit_radius(moving_ball_radius, target_ball.radius)
		var hit_fraction: float = _get_segment_circle_hit_fraction(
			segment_start,
			segment,
			target_ball.global_position,
			combined_radius
		)
		if hit_fraction < 0.0:
			if track_debug_first_hit_candidates:
				_update_debug_first_hit_candidate_result(target_ball, "miss_preview_radius", false)
			continue

		var hit_distance: float = hit_fraction * segment_length
		if track_debug_first_hit_candidates:
			_update_debug_first_hit_candidate_result(target_ball, "accepted", true)
		if hit_distance < nearest_hit.distance:
			nearest_hit.ball = target_ball
			nearest_hit.distance = hit_distance
			nearest_hit.position = segment_start + segment * hit_fraction

	return nearest_hit


func _append_debug_first_hit_candidate_entry(
	target_ball: Ball,
	segment_start: Vector2,
	segment: Vector2,
	segment_length: float,
	moving_ball_radius: float,
	path_distance_before_segment: float,
	segment_index: int,
	query_order: int,
	is_filtered: bool,
	initial_reason: String
) -> void:
	if not debug_aim_line_enabled:
		return
	if target_ball == null or not is_instance_valid(target_ball):
		return
	if _debug_first_hit_candidate_log.size() >= DEBUG_AIM_FIRST_HIT_CANDIDATE_MAX_ENTRIES:
		return

	var preview_radius: float = _get_prediction_ball_hit_radius(moving_ball_radius, target_ball.radius)
	var real_radius: float = _get_real_ball_hit_radius(moving_ball_radius, target_ball.radius)
	var legacy_graze_radius: float = _get_legacy_graze_ball_hit_radius(moving_ball_radius, target_ball.radius)
	var preview_hit_fraction: float = _get_segment_circle_hit_fraction(
		segment_start,
		segment,
		target_ball.global_position,
		preview_radius
	)
	var real_hit_fraction: float = _get_segment_circle_hit_fraction(
		segment_start,
		segment,
		target_ball.global_position,
		real_radius
	)
	var legacy_graze_hit_fraction: float = _get_segment_circle_hit_fraction(
		segment_start,
		segment,
		target_ball.global_position,
		legacy_graze_radius
	)
	var raw_projection_fraction: float = (target_ball.global_position - segment_start).dot(segment) / segment.length_squared()
	var projected_fraction: float = clamp(raw_projection_fraction, 0.0, 1.0)
	var closest_point: Vector2 = segment_start + segment * projected_fraction
	var projected_distance: float = path_distance_before_segment + projected_fraction * segment_length
	var preview_hit_distance: float = -1.0
	var real_hit_distance: float = -1.0
	var legacy_graze_hit_distance: float = -1.0
	if preview_hit_fraction >= 0.0:
		preview_hit_distance = path_distance_before_segment + preview_hit_fraction * segment_length
	if real_hit_fraction >= 0.0:
		real_hit_distance = path_distance_before_segment + real_hit_fraction * segment_length
	if legacy_graze_hit_fraction >= 0.0:
		legacy_graze_hit_distance = path_distance_before_segment + legacy_graze_hit_fraction * segment_length

	_debug_first_hit_candidate_log.append({
		"ball_id": target_ball.get_instance_id(),
		"ball_number": target_ball.ball_number,
		"ball_label": _get_debug_ball_label(target_ball),
		"ball_position": target_ball.global_position,
		"segment_index": segment_index,
		"query_order": query_order,
		"projected_distance": projected_distance,
		"projected_fraction": projected_fraction,
		"raw_projected_fraction": raw_projection_fraction,
		"lateral_distance": target_ball.global_position.distance_to(closest_point),
		"preview_radius": preview_radius,
		"real_radius": real_radius,
		"legacy_graze_radius": legacy_graze_radius,
		"preview_hit_fraction": preview_hit_fraction,
		"real_hit_fraction": real_hit_fraction,
		"legacy_graze_hit_fraction": legacy_graze_hit_fraction,
		"preview_hit_distance": preview_hit_distance,
		"real_hit_distance": real_hit_distance,
		"legacy_graze_hit_distance": legacy_graze_hit_distance,
		"would_hit_real_radius": real_hit_fraction >= 0.0,
		"would_hit_legacy_graze_radius": legacy_graze_hit_fraction >= 0.0,
		"accepted": false,
		"selected": false,
		"reason": initial_reason if is_filtered else "pending",
	})


func _update_debug_first_hit_candidate_result(target_ball: Ball, reason: String, accepted: bool) -> void:
	if not debug_aim_line_enabled or target_ball == null or not is_instance_valid(target_ball):
		return
	var ball_id: int = target_ball.get_instance_id()
	for entry_index in range(_debug_first_hit_candidate_log.size() - 1, -1, -1):
		var entry: Dictionary = _debug_first_hit_candidate_log[entry_index]
		if int(entry.get("ball_id", -1)) != ball_id:
			continue
		entry["reason"] = reason
		entry["accepted"] = accepted
		_debug_first_hit_candidate_log[entry_index] = entry
		return


func _get_real_ball_hit_radius(moving_ball_radius: float, target_ball_radius: float) -> float:
	return moving_ball_radius + target_ball_radius + table.BALL_COLLISION_SKIN


func _get_legacy_graze_ball_hit_radius(moving_ball_radius: float, target_ball_radius: float) -> float:
	var legacy_preview_skin: float = max(table.BALL_COLLISION_SKIN - AIM_BALL_HIT_GRAZE_MARGIN, 0.0)
	return moving_ball_radius + target_ball_radius + legacy_preview_skin


func _get_prediction_ball_hit_radius(moving_ball_radius: float, target_ball_radius: float) -> float:
	# First-hit prediction must match the real collision acceptance radius.
	# Visual underpromising can make the preview skip valid grazes and choose
	# the wrong first ball, while real physics still collides.
	return _get_real_ball_hit_radius(moving_ball_radius, target_ball_radius)


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
	cue_center_at_impact: Vector2,
	rail_hit_count_before_target: int,
	cue_target_impact_segment_index: int
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
	prediction.impact_incoming_direction = incoming_velocity.normalized()
	prediction.predicted_target_velocity = predicted_target_velocity
	prediction.rail_hit_count_before_target = rail_hit_count_before_target
	prediction.cue_target_impact_segment_index = cue_target_impact_segment_index
	var target_prediction: AimTargetPath = _get_predicted_target_path(target_ball, predicted_target_velocity)
	prediction.target_path_points = target_prediction.points
	prediction.target_ends_in_pocket = target_prediction.ends_in_pocket
	prediction.target_prediction_steps = target_prediction.steps
	prediction.target_first_stop_reason = target_prediction.first_stop_reason
	prediction.target_path_length = target_prediction.path_length
	prediction.target_first_hit_ball = target_prediction.first_hit_ball
	prediction.target_first_hit_position = target_prediction.first_hit_position
	prediction.target_incoming_velocity_at_stop = target_prediction.incoming_velocity_at_stop
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
	impulse_strength *= _get_cue_ball_wake_preview_impact_multiplier(target_ball)
	return target_ball.velocity + target_direction * impulse_strength


func _get_cue_ball_wake_preview_impact_multiplier(target_ball: Ball) -> float:
	if not bool(active_effect_snapshot.get(AIM_EFFECT_CUE_BALL_CANNON_WAKE_ENABLED, false)):
		return 1.0
	if not _is_cue_ball_wake_preview_target(target_ball):
		return 1.0
	return maxf(float(active_effect_snapshot.get(AIM_EFFECT_CUE_BALL_CANNON_WAKE_IMPACT_MULTIPLIER, 1.0)), 1.0)


func _is_cue_ball_wake_preview_target(ball: Ball) -> bool:
	if ball == null:
		return false
	if table != null and (ball == table.cue_ball or ball == table.eight_ball):
		return false
	if ball.ball_type != Ball.BallType.OBJECT:
		return false
	return (
		not ball.is_wayfinder
		and not ball.is_powder_keg
		and not ball.is_anchor_ball
		and not ball.is_cannon_ball
		and not ball.is_treasure_ball
		and not ball.is_embezzler_ball
	)


func _get_predicted_target_path(
	target_ball: Ball,
	starting_velocity: Vector2,
	extra_ignored_ball: Ball = null
) -> AimTargetPath:
	var target_prediction: AimTargetPath = AimTargetPath.new()
	target_prediction.points.append(target_ball.global_position)

	var simulated_position: Vector2 = target_ball.global_position
	var simulated_velocity: Vector2 = starting_velocity
	var travel_distance := 0.0
	var step_delta: float = _get_prediction_step_delta(AIM_TARGET_PREDICTION_STEP_SUBSTEPS)

	for _step_index in range(AIM_TARGET_PREDICTION_MAX_STEPS):
		var speed: float = simulated_velocity.length()
		if speed <= target_ball.stop_threshold:
			target_prediction.first_stop_reason = "stopped"
			break
		if travel_distance >= AIM_TARGET_PREDICTION_MAX_DISTANCE:
			target_prediction.first_stop_reason = "max_distance"
			break

		target_prediction_steps_this_frame += 1
		target_prediction.steps += 1
		var previous_position: Vector2 = simulated_position
		var movement_delta: Vector2 = simulated_velocity * step_delta
		var remaining_distance: float = AIM_TARGET_PREDICTION_MAX_DISTANCE - travel_distance
		if movement_delta.length() > remaining_distance:
			movement_delta = movement_delta.limit_length(remaining_distance)
		var movement_end: Vector2 = previous_position + movement_delta
		var pocket_hit: AimPocketHit = _get_first_target_pocket_hit_on_segment(previous_position, movement_end, target_ball)
		var ball_hit: AimBallHit = _get_first_target_ball_hit_on_segment(previous_position, movement_end, target_ball, extra_ignored_ball)

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
			target_prediction.first_stop_reason = stop_type
			if stop_type == "ball":
				target_prediction.first_hit_ball = ball_hit.ball
				target_prediction.first_hit_position = ball_hit.position
				target_prediction.incoming_velocity_at_stop = simulated_velocity
			target_prediction.path_length = travel_distance + previous_position.distance_to(stop_position)
			return target_prediction

		var next_position: Vector2 = step_result.position
		travel_distance += previous_position.distance_to(next_position)
		simulated_position = next_position
		_append_target_path_point(target_prediction.points, next_position)

		simulated_velocity = step_result.velocity

	if target_prediction.first_stop_reason == "inactive":
		if travel_distance >= AIM_TARGET_PREDICTION_MAX_DISTANCE:
			target_prediction.first_stop_reason = "max_distance"
		elif target_prediction.steps >= AIM_TARGET_PREDICTION_MAX_STEPS:
			target_prediction.first_stop_reason = "max_steps"
		else:
			target_prediction.first_stop_reason = "stopped"
	target_prediction.path_length = travel_distance
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
#endregion


#region Debug Path Comparison
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
#endregion


#region Color / Timing / Debug Print Helpers
func _store_draw_stats(draw_start_usec: int) -> void:
	draw_ms_last_draw = _elapsed_ms_since(draw_start_usec)
	draw_segments_last_draw = _draw_segments_in_progress
	draw_calls_last_draw = _draw_calls_in_progress


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
#endregion
