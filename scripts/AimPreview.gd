@tool
extends Node2D
class_name AimPreview

# Owns cue aim prediction, bank preview drawing, and shot-path debug overlays.
# Table.gd owns real balls/gameplay state; BoundarySystem owns boundary queries.

# Debug-only comparison tools.
const DEBUG_AIM_PATH_COMPARISON_DEFAULT := false
const DEBUG_BANK_PREDICTION := false
const BALL_SWEEP_MATH := preload("res://scripts/BallSweepMath.gd")
const BALL_COLLISION_MATH := preload("res://scripts/BallCollisionMath.gd")
const BALL_MOTION_MATH := preload("res://scripts/BallMotionMath.gd")
const AIM_TRAJECTORY_PREDICTOR_SCRIPT := preload("res://scripts/AimTrajectoryPredictor.gd")
const AIM_TRAJECTORY_PROFILER_SCRIPT := preload("res://scripts/AimTrajectoryProfiler.gd")
const AIM_BENCHMARK_SESSION_SCRIPT := preload("res://scripts/AimBenchmarkSession.gd")
const AIM_STAGING_CONFIGURATION_SCRIPT := preload("res://scripts/AimStagingConfiguration.gd")

const STAGED_STATE_IDLE := "idle"
const STAGED_STATE_IMMEDIATE_ONLY := "immediate_only"
const STAGED_STATE_WAITING_FOR_SETTLE := "waiting_for_settle"
const STAGED_STATE_DEEP_REQUESTED := "deep_requested"
const STAGED_STATE_DEEP_RUNNING := "deep_running"
const STAGED_STATE_DEEP_READY := "deep_ready"
const STAGED_STATE_DEEP_STALE := "deep_stale"
const STAGED_STATE_BLOCKED := "blocked"
# These reject floating-point jitter only; they are deliberately far below a
# visibly meaningful graze-shot adjustment and do not reuse prediction geometry.
const STAGED_DIRECTION_TOLERANCE_DEGREES := 0.02
const STAGED_POWER_RELATIVE_TOLERANCE := 0.0001
const STAGED_ORIGIN_TOLERANCE_PX := 0.1
const STAGED_STALE_ALPHA := 0.10

# Cue-ball guide simulation and rendering.
const AIM_GUIDE_LENGTH := 180.0
const AIM_PREDICTION_ENABLED := true
const AIM_PREDICTION_MAX_DISTANCE := 900.0
const AIM_SIMULATION_FRAME_DELTA := 1.0 / 60.0
const AIM_PREDICTION_STEP_SUBSTEPS := 2
const AIM_SIMULATION_MAX_BOUNCES := 1
const DEBUG_LEGACY_AIM_BALL_HIT_GRAZE_MARGIN := 1.25
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
const DEBUG_CLONED_PATH_COLORS := [
	Color(1.0, 0.78, 0.32, 0.86),
	Color(0.65, 1.0, 0.48, 0.82),
	Color(0.96, 0.46, 0.88, 0.82),
	Color(0.55, 0.66, 1.0, 0.82),
	Color(1.0, 0.52, 0.34, 0.82),
	Color(0.40, 1.0, 0.86, 0.82),
]

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
	var target_center_at_impact := Vector2.ZERO
	var effective_collision_radius := 0.0
	var collision_skin := 0.0
	var rail_hit_count_before_target: int = 0
	var cue_target_impact_segment_index: int = -1
	var target_path_points: Array[Vector2] = []
	var target_ends_in_pocket := false
	var target_prediction_steps: int = 0
	var target_first_stop_reason: String = "inactive"
	var target_path_length: float = 0.0
	var target_first_hit_ball: Ball = null
	var target_first_hit_position := Vector2.ZERO
	var target_first_hit_target_center := Vector2.ZERO
	var target_first_hit_normal := Vector2.ZERO
	var target_first_hit_effective_collision_radius := 0.0
	var target_first_hit_collision_skin := 0.0
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
	var target_position := Vector2.ZERO
	var collision_normal := Vector2.ZERO
	var effective_collision_radius := 0.0
	var collision_skin := 0.0

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
	var first_hit_target_center := Vector2.ZERO
	var first_hit_normal := Vector2.ZERO
	var first_hit_effective_collision_radius := 0.0
	var first_hit_collision_skin := 0.0
	var incoming_velocity_at_stop := Vector2.ZERO

class AimChainLink:
	var ball: Ball = null
	var path_points: Array[Vector2] = []
	var ends_in_pocket := false
	var first_stop_reason := "inactive"
	var path_length := 0.0
	var next_ball: Ball = null
	var first_hit_position := Vector2.ZERO
	var first_hit_target_center := Vector2.ZERO
	var first_hit_normal := Vector2.ZERO
	var first_hit_effective_collision_radius := 0.0
	var first_hit_collision_skin := 0.0
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
	var predicted_target_contact_position := Vector2.ZERO
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
	var predicted_center_distance := -1.0
	var prediction_effective_collision_radius := -1.0
	var prediction_collision_skin := 0.0
	var physics_collision_skin := 0.0
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
	var contact_order_snapshot: Dictionary = {}
	var cloned_prediction_result: Dictionary = {}
	var deep_prediction_commit_status := "deep_prediction_not_ready"
	var deep_request_snapshot: Dictionary = {}
	var actual_events: Array[Dictionary] = []
	var actual_event_start_usec: int = 0

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
var _draw_predicted_balls_in_progress := 0
var _draw_visible_paths_in_progress := 0
var _draw_ghost_balls_in_progress := 0
var _draw_labels_in_progress := 0
var _draw_event_markers_in_progress := 0
var _aim_ball_spatial_grid: Dictionary = {}
var _aim_spatial_cell_size := 56.0
var _aim_spatial_max_ball_radius := 0.0
var _debug_first_hit_candidate_log: Array[Dictionary] = []
var _debug_first_hit_selected_ball_id := -1
var _debug_first_hit_selected_ball_number := -1
var trajectory_predictor: AimTrajectoryPredictor
var trajectory_profiler: AimTrajectoryProfiler
var benchmark_session: AimBenchmarkSession
var cloned_trajectory_configuration: Dictionary = {}
var current_cloned_prediction: Dictionary = {}
var _last_cloned_rebuild_origin := Vector2.ZERO
var _last_cloned_rebuild_velocity := Vector2.ZERO
var _has_last_cloned_rebuild_input := false
var _cloned_configuration_changed_since_rebuild := false
var cloned_prediction_availability: Dictionary = {}
var _observed_table_prediction_revision := -1
var _last_successful_cloned_rebuild_revision := -1
var _cloned_refresh_pending := false
var _last_cloned_invalidation_reason := "none"
var _cloned_invalidation_count := 0
var _cloned_invalidation_reason_counts: Dictionary = {}
var _cloned_roster_change_invalidations := 0
var _cloned_spawn_complete_invalidations := 0
var _cloned_remove_sink_invalidations := 0
var _cloned_transform_invalidations := 0
var _cloned_unsupported_state_invalidations := 0
var _cloned_successful_rebuilds_after_invalidation := 0
var _cloned_failed_rebuilds_after_invalidation := 0
var _last_failed_invalidation_revision := -1
var staged_prediction_configuration: Dictionary = {}
var staged_prediction_state := STAGED_STATE_IDLE
var staged_prediction_reason := "not_requested"
var _latest_staged_origin := Vector2.ZERO
var _latest_staged_launch_velocity := Vector2.ZERO
var _latest_staged_effect_hash := 0
var _has_staged_input := false
var _last_meaningful_input_usec: int = 0
var _pending_deep_reason := "settled_deep_prediction"
var _deep_request_suppressed_until_input_change := false
var _profiled_pending_deep_request := false
var _request_generation := 0
var _current_deep_request_id := 0
var _last_accepted_deep_request_id := 0
var _last_stale_deep_request_id := 0
var _current_deep_request_snapshot: Dictionary = {}
var _accepted_deep_request_snapshot: Dictionary = {}
var _stale_cloned_prediction: Dictionary = {}
var _configuration_revision := 0
var _effect_snapshot_revision := 0
var _deep_reveal_start_usec: int = 0
var _deep_reveal_progress := 0.0
var _deep_reveal_active := false
var _deep_reveal_visible_noted := false
var _deep_reveal_completed_noted := false
var _deep_reveal_max_depth := 0
var _deep_reveal_visible_branches := 0
var _deep_reveal_preparation_us := 0
var _deep_reveal_preparation_pending_us := 0
var _deep_draw_cpu_us_in_progress := 0
var _deep_requests_created := 0
var _deep_requests_completed := 0
var _deep_requests_accepted := 0
var _deep_requests_canceled_before_run := 0
var _deep_requests_invalidated_before_run := 0
var _deep_requests_blocked_before_run := 0
var _deep_results_discarded_on_arrival := 0
var _deep_results_rejected_revision_mismatch := 0
var _deep_results_rejected_request_id_mismatch := 0
var _accepted_results_shown := 0
var _shown_results_later_invalidated := 0
var _shown_results_hidden_by_new_aim := 0
var _shown_results_reused_from_cache := 0
var _reveal_completed_count := 0
var _reveal_interrupted_count := 0
var _reveal_completed_before_next_aim_count := 0
var _deep_force_requests := 0
var _immediate_updates := 0
var _active_drag_deep_rebuilds := 0
var _settled_deep_rebuilds := 0
var _deep_cache_hits := 0
var _deep_cache_misses := 0
var _cached_results_accepted := 0
var _cached_results_rejected := 0
var _deep_reused_results := 0
var _accepted_deep_cache_hit := false
var _deep_ready_but_hidden_count := 0
var _deep_compute_start_latency_total_usec: int = 0
var _deep_compute_start_latency_samples := 0
var _deep_compute_total_usec: int = 0
var _deep_compute_samples := 0
var _deep_first_visible_latency_total_usec: int = 0
var _deep_first_visible_latency_samples := 0


#region Setup / Public API
func setup(table_ref) -> void:
	table = table_ref
	trajectory_predictor = AIM_TRAJECTORY_PREDICTOR_SCRIPT.new()
	trajectory_profiler = AIM_TRAJECTORY_PROFILER_SCRIPT.new()
	benchmark_session = AIM_BENCHMARK_SESSION_SCRIPT.new()
	cloned_trajectory_configuration = AIM_TRAJECTORY_PREDICTOR_SCRIPT.get_default_configuration(
		int(table.PHYSICS_SUBSTEPS)
	)
	staged_prediction_configuration = AIM_STAGING_CONFIGURATION_SCRIPT.get_default_configuration()
	cloned_trajectory_configuration.merge(staged_prediction_configuration, true)
	trajectory_profiler.set_enabled(bool(cloned_trajectory_configuration.get("profile_enabled", false)))
	benchmark_session.set_staging_configuration(staged_prediction_configuration)
	_observed_table_prediction_revision = int(table.get_aim_prediction_state_revision())
	cloned_prediction_availability = _make_default_cloned_prediction_availability()


func notify_table_prediction_revision_changed(
	revision: int,
	reason: String,
	category: String = "state_change"
) -> void:
	if revision == _observed_table_prediction_revision:
		return

	_observed_table_prediction_revision = revision
	_pending_deep_reason = "table_revision_deep_prediction"
	_deep_request_suppressed_until_input_change = false
	_cloned_refresh_pending = true
	_last_cloned_invalidation_reason = reason
	_cloned_invalidation_count += 1
	_cloned_invalidation_reason_counts[reason] = int(
		_cloned_invalidation_reason_counts.get(reason, 0)
	) + 1
	match category:
		"roster_change":
			_cloned_roster_change_invalidations += 1
		"spawn_complete":
			_cloned_spawn_complete_invalidations += 1
		"remove_sink":
			_cloned_remove_sink_invalidations += 1
		"transform":
			_cloned_transform_invalidations += 1
		"unsupported_state":
			_cloned_unsupported_state_invalidations += 1

	_invalidate_staged_deep_prediction(
		"invalidated_table_revision",
		preview_active and _is_deep_prediction_requested()
	)
	_has_last_cloned_rebuild_input = false
	if trajectory_predictor != null:
		trajectory_predictor.clear_cache()
	cloned_prediction_availability = _make_default_cloned_prediction_availability()
	cloned_prediction_availability["blocker_reason"] = "ball_roster_changed"
	cloned_prediction_availability["blocker_details"] = reason
	cloned_prediction_availability["table_revision"] = revision
	cloned_prediction_availability["refresh_pending"] = true
	_queue_aim_redraw()


func clear_for_authoritative_table_reset(reason: String) -> void:
	var preserve_shot_evidence: bool = reason == "shot_rewind"
	preview_active = false
	current_prediction = null
	current_cloned_prediction = {}
	_stale_cloned_prediction = {}
	long_sight_chain_links.clear()
	bank_debug_markers.clear()
	last_predicted_aim_path.clear()
	last_predicted_rail_position = Vector2.ZERO
	last_predicted_rail_normal = Vector2.ZERO
	last_predicted_post_bank_direction = Vector2.ZERO
	actual_cue_path.clear()
	aim_path_debug_timer = 0.0
	actual_cue_path_recording = false
	debug_actual_trace_recording = false
	if not preserve_shot_evidence:
		debug_persisted_shot = null
	_aim_ball_spatial_grid.clear()
	_reset_debug_first_hit_candidate_log()
	_rebuild_treasure_perception_snapshot(null)
	_rebuild_embezzler_perception_snapshot(null)
	_has_last_cloned_rebuild_input = false
	_reset_staged_prediction_runtime(reason)
	_cloned_refresh_pending = true
	_last_cloned_invalidation_reason = reason
	if trajectory_predictor != null:
		trajectory_predictor.clear_cache()
	_queue_aim_redraw()


func update_preview(
	active: bool,
	origin: Vector2,
	drag_vector: Vector2,
	shot_power: float,
	power_ratio: float,
	effect_snapshot: Dictionary = {}
) -> void:
	var incoming_effect_hash: int = hash(effect_snapshot)
	var effect_changed: bool = _has_staged_input and incoming_effect_hash != _latest_staged_effect_hash
	active_effect_snapshot = effect_snapshot.duplicate(true)
	if effect_changed:
		_effect_snapshot_revision += 1
		if trajectory_predictor != null:
			trajectory_predictor.clear_cache()
	if not active:
		_refresh_cloned_availability_for_inactive_preview()
		prediction_ms = 0.0
		_aim_ball_spatial_grid.clear()
		long_sight_chain_links.clear()
		current_cloned_prediction = {}
		_stale_cloned_prediction = {}
		_reset_staged_prediction_runtime("preview_inactive")
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
			_queue_aim_redraw()
		return

	preview_active = true
	preview_origin = origin
	preview_drag_vector = drag_vector
	preview_initial_velocity = drag_vector * shot_power
	preview_power_ratio = power_ratio
	var immediate_update_reason: String = _classify_immediate_update_reason(
		origin,
		preview_initial_velocity,
		incoming_effect_hash,
		effect_changed
	)

	var aim_start_usec: int = Time.get_ticks_usec()
	_rebuild_aim_ball_spatial_grid()
	_reset_debug_first_hit_candidate_log()
	current_prediction = _get_first_aim_collision(origin, drag_vector * shot_power)
	_finalize_debug_first_hit_candidate_selection(current_prediction)
	if not _is_deep_prediction_requested():
		_rebuild_long_sight_chain(current_prediction)
	else:
		long_sight_chain_links.clear()
	_rebuild_treasure_perception_snapshot(current_prediction)
	_rebuild_embezzler_perception_snapshot(current_prediction)
	prediction_ms = _elapsed_ms_since(aim_start_usec)
	var immediate_cpu_usec: int = maxi(Time.get_ticks_usec() - aim_start_usec, 0)
	_immediate_updates += 1
	if trajectory_profiler != null:
		trajectory_profiler.record_immediate_update(immediate_cpu_usec, immediate_update_reason)
	if benchmark_session != null:
		benchmark_session.record_immediate_update(immediate_cpu_usec, immediate_update_reason)
	_handle_staged_aim_input(
		origin,
		preview_initial_velocity,
		incoming_effect_hash,
		effect_changed,
		immediate_update_reason
	)
	prediction_frame_ms += prediction_ms
	prediction_recalculations_this_frame += 1
	_queue_aim_redraw()


func update_debug(delta: float, is_dragging: bool, input_refresh_pending: bool = false) -> void:
	_update_bank_debug_markers(delta)
	_update_aim_path_comparison_debug(delta)
	_update_staged_prediction(input_refresh_pending)
	# A queued input refresh owns this frame. Do not let geometry from the previous
	# aim finish its reveal before that input can invalidate it.
	if not input_refresh_pending:
		_update_deep_reveal()
	if _should_redraw_debug(is_dragging):
		_queue_aim_redraw()


func start_path_comparison(origin: Vector2, initial_velocity: Vector2) -> void:
	if not debug_aim_path_comparison_enabled and not debug_aim_line_enabled:
		return
	if not _full_debug_result_evidence_enabled():
		debug_persisted_shot = null
		debug_actual_trace_recording = false
		actual_cue_path_recording = false
		return

	_rebuild_aim_ball_spatial_grid()
	_reset_debug_first_hit_candidate_log()
	var prediction: AimPrediction = _get_first_aim_collision(origin, initial_velocity)
	_finalize_debug_first_hit_candidate_selection(prediction)
	var commit_status: String = _get_deep_prediction_commit_status(origin, initial_velocity)
	var committed_deep_result: Dictionary = {}
	var committed_request_snapshot: Dictionary = {}
	if commit_status == "deep_prediction_ready":
		committed_deep_result = current_cloned_prediction
		committed_request_snapshot = _accepted_deep_request_snapshot
	if debug_aim_line_enabled:
		debug_persisted_shot = _make_debug_shot_overlay(
			prediction,
			origin,
			initial_velocity,
			committed_deep_result,
			commit_status,
			committed_request_snapshot
		)
		debug_persisted_shot.actual_cue_path.clear()
		debug_persisted_shot.actual_cue_path.append(origin)
		debug_persisted_shot.actual_event_start_usec = Time.get_ticks_usec()
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
	_queue_aim_redraw()


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
	_queue_aim_redraw()
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
	_queue_aim_redraw()


func report_debug_actual_launch(launch_position: Vector2, launch_velocity: Vector2) -> void:
	if not debug_aim_line_enabled or debug_persisted_shot == null:
		return
	debug_persisted_shot.has_actual_launch = true
	debug_persisted_shot.actual_launch_position = launch_position
	debug_persisted_shot.actual_launch_velocity = launch_velocity
	_append_debug_actual_path_point(launch_position, true)
	_record_debug_all_ball_paths()
	_queue_aim_redraw()


func report_debug_collision_event(
	ball_a: Ball,
	ball_b: Ball,
	normal: Vector2,
	impact_speed: float,
	incoming_velocity_a: Vector2 = Vector2.ZERO,
	incoming_velocity_b: Vector2 = Vector2.ZERO,
	resolution_source: String = "legacy"
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
	var source_ball: Ball = _choose_actual_event_source(
		ball_a,
		ball_b,
		incoming_velocity_a,
		incoming_velocity_b
	)
	var target_ball: Ball = ball_b if source_ball == ball_a else ball_a
	var source_normal: Vector2 = normal if source_ball == ball_a else -normal
	_append_debug_actual_event({
		"event_type": AimTrajectoryPredictor.EVENT_BALL_CONTACT,
		"source_ball_id": source_ball.get_instance_id(),
		"source_ball_number": source_ball.ball_number,
		"source_ball_label": _get_debug_ball_label(source_ball),
		"target_ball_id": target_ball.get_instance_id(),
		"target_ball_number": target_ball.ball_number,
		"target_ball_label": _get_debug_ball_label(target_ball),
		"source_center": source_ball.global_position,
		"target_center": target_ball.global_position,
		"contact_point": source_ball.global_position + source_normal * source_ball.radius,
		"collision_normal": source_normal,
		"incoming_source_velocity": incoming_velocity_a if source_ball == ball_a else incoming_velocity_b,
		"incoming_target_velocity": incoming_velocity_b if source_ball == ball_a else incoming_velocity_a,
		"outgoing_source_velocity": source_ball.velocity,
		"outgoing_target_velocity": target_ball.velocity,
		"impact_speed": impact_speed,
		"resolution_source": resolution_source,
	})


func report_debug_contact_order_snapshot(contact_order_snapshot: Dictionary) -> void:
	if not debug_aim_line_enabled or debug_persisted_shot == null:
		return
	debug_persisted_shot.contact_order_snapshot = contact_order_snapshot.duplicate(true)


func report_debug_rail_event(
	ball: Ball,
	hit_position: Vector2,
	normal: Vector2,
	incoming_velocity: Vector2,
	outgoing_velocity: Vector2
) -> void:
	if not debug_aim_line_enabled or debug_persisted_shot == null:
		return
	var line: String = "%s -> Rail | normal %.1f deg | speed %.0f" % [
		_get_debug_ball_label(ball),
		_get_vector_angle_degrees(normal),
		incoming_velocity.length(),
	]
	_append_debug_collision_log(line)
	_append_debug_actual_event({
		"event_type": AimTrajectoryPredictor.EVENT_RAIL_CONTACT,
		"source_ball_id": ball.get_instance_id(),
		"source_ball_number": ball.ball_number,
		"source_ball_label": _get_debug_ball_label(ball),
		"target_ball_id": -1,
		"target_ball_number": -1,
		"source_center": ball.global_position,
		"target_center": hit_position,
		"contact_point": hit_position,
		"collision_normal": normal,
		"incoming_source_velocity": incoming_velocity,
		"outgoing_source_velocity": outgoing_velocity,
	})


func report_debug_pocket_event(ball: Ball, pocket_index: int, pocket_position: Vector2) -> void:
	if not debug_aim_line_enabled or debug_persisted_shot == null or ball == null:
		return
	if ball != table.cue_ball:
		_append_debug_ball_trace_point(ball)
	_append_debug_actual_event({
		"event_type": AimTrajectoryPredictor.EVENT_POCKET,
		"source_ball_id": ball.get_instance_id(),
		"source_ball_number": ball.ball_number,
		"source_ball_label": _get_debug_ball_label(ball),
		"target_ball_id": -1,
		"target_ball_number": -1,
		"source_center": ball.global_position,
		"target_center": pocket_position,
		"contact_point": ball.global_position,
		"collision_normal": (ball.global_position - pocket_position).normalized(),
		"incoming_source_velocity": ball.velocity,
		"outgoing_source_velocity": Vector2.ZERO,
		"pocket_index": pocket_index,
	})


func report_debug_ball_stopped(ball: Ball, incoming_velocity: Vector2) -> void:
	if not debug_aim_line_enabled or debug_persisted_shot == null or ball == null:
		return
	if ball != table.cue_ball:
		_append_debug_ball_trace_point(ball)
	_append_debug_actual_event({
		"event_type": AimTrajectoryPredictor.EVENT_STOPPED,
		"source_ball_id": ball.get_instance_id(),
		"source_ball_number": ball.ball_number,
		"source_ball_label": _get_debug_ball_label(ball),
		"target_ball_id": -1,
		"target_ball_number": -1,
		"source_center": ball.global_position,
		"target_center": Vector2.ZERO,
		"contact_point": ball.global_position,
		"collision_normal": Vector2.ZERO,
		"incoming_source_velocity": incoming_velocity,
		"outgoing_source_velocity": Vector2.ZERO,
	})


func _choose_actual_event_source(
	ball_a: Ball,
	ball_b: Ball,
	incoming_velocity_a: Vector2,
	incoming_velocity_b: Vector2
) -> Ball:
	if (ball_a == table.cue_ball) != (ball_b == table.cue_ball):
		return ball_a if ball_a == table.cue_ball else ball_b
	var speed_a: float = incoming_velocity_a.length_squared()
	var speed_b: float = incoming_velocity_b.length_squared()
	if not is_equal_approx(speed_a, speed_b):
		return ball_a if speed_a > speed_b else ball_b
	return ball_a if ball_a.get_index() <= ball_b.get_index() else ball_b


func _append_debug_actual_event(event: Dictionary) -> void:
	if debug_persisted_shot == null or not debug_actual_trace_recording:
		return
	event["event_index"] = debug_persisted_shot.actual_events.size()
	event["actual_time"] = (
		float(Time.get_ticks_usec() - debug_persisted_shot.actual_event_start_usec) / 1000000.0
		if debug_persisted_shot.actual_event_start_usec > 0
		else 0.0
	)
	event["physics_frame"] = Engine.get_physics_frames()
	debug_persisted_shot.actual_events.append(event)


func note_actual_cue_pocketed(ball: Ball) -> void:
	if debug_aim_line_enabled and ball == table.cue_ball and debug_actual_trace_recording:
		_append_debug_actual_path_point(table.cue_ball.global_position, true)
		_queue_aim_redraw()

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
	_queue_aim_redraw()


func set_shot_path_debug_enabled(enabled: bool) -> void:
	debug_aim_path_comparison_enabled = enabled
	if not enabled:
		stop_actual_path_recording()
		aim_path_debug_timer = 0.0
		_queue_aim_redraw()


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
	_queue_aim_redraw()


func set_cloned_trajectory_configuration(configuration: Dictionary) -> void:
	var profiling_was_enabled: bool = bool(cloned_trajectory_configuration.get("profile_enabled", false))
	var predictor_configuration: Dictionary = AIM_TRAJECTORY_PREDICTOR_SCRIPT.normalize_configuration(
		configuration,
		int(table.PHYSICS_SUBSTEPS) if table != null else 4
	)
	staged_prediction_configuration = AIM_STAGING_CONFIGURATION_SCRIPT.normalize_configuration(configuration)
	cloned_trajectory_configuration = predictor_configuration
	cloned_trajectory_configuration.merge(staged_prediction_configuration, true)
	if benchmark_session != null:
		benchmark_session.set_staging_configuration(staged_prediction_configuration)
	_configuration_revision += 1
	_pending_deep_reason = "config_deep_prediction"
	_deep_request_suppressed_until_input_change = false
	_cloned_configuration_changed_since_rebuild = true
	if not _full_debug_result_evidence_enabled():
		debug_persisted_shot = null
		debug_actual_trace_recording = false
		actual_cue_path_recording = false
		_reset_debug_first_hit_candidate_log()
	var profiling_enabled: bool = bool(cloned_trajectory_configuration.get("profile_enabled", false))
	if trajectory_profiler != null:
		if profiling_enabled and not profiling_was_enabled:
			trajectory_profiler.reset(
				trajectory_predictor.get_cache_debug_snapshot() if trajectory_predictor != null else {}
			)
		trajectory_profiler.set_enabled(profiling_enabled)
	_last_cloned_invalidation_reason = "configuration_changed"
	_cloned_invalidation_count += 1
	_cloned_invalidation_reason_counts["configuration_changed"] = int(
		_cloned_invalidation_reason_counts.get("configuration_changed", 0)
	) + 1
	_cloned_refresh_pending = true
	_last_failed_invalidation_revision = -1
	_invalidate_staged_deep_prediction(
		"invalidated_config_revision",
		preview_active and _is_deep_prediction_requested()
	)
	_has_last_cloned_rebuild_input = false
	if trajectory_predictor != null:
		trajectory_predictor.clear_cache()
	_queue_aim_redraw()


func get_cloned_trajectory_configuration() -> Dictionary:
	return cloned_trajectory_configuration.duplicate(true)


func reset_cloned_trajectory_profiler_stats() -> void:
	if trajectory_profiler == null:
		return
	trajectory_profiler.reset(
		trajectory_predictor.get_cache_debug_snapshot() if trajectory_predictor != null else {}
	)
	if _profiled_pending_deep_request:
		trajectory_profiler.note_deep_request_created(false)


func reset_cloned_trajectory_benchmark_stats() -> void:
	if benchmark_session != null:
		benchmark_session.reset()


func start_cloned_trajectory_benchmark(
	label: String,
	preset_label: String,
	contamination_snapshot: Dictionary = {}
) -> void:
	if benchmark_session == null:
		return
	benchmark_session.start_capture(
		label,
		preset_label,
		str(cloned_trajectory_configuration.get(
			"result_detail_mode",
			AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
		)),
		contamination_snapshot
	)
	benchmark_session.set_staging_configuration(staged_prediction_configuration)
	if _profiled_pending_deep_request:
		benchmark_session.note_deep_request_created(false)
	_cloned_configuration_changed_since_rebuild = false
	if trajectory_predictor != null:
		trajectory_predictor.clear_cache()


func stop_cloned_trajectory_benchmark() -> void:
	if benchmark_session != null:
		benchmark_session.stop_capture()


func copy_cloned_trajectory_benchmark_report() -> bool:
	return benchmark_session != null and benchmark_session.copy_report_to_clipboard()


func get_cloned_trajectory_benchmark_snapshot() -> Dictionary:
	return benchmark_session.get_snapshot() if benchmark_session != null else {}


func force_deep_prediction_now() -> bool:
	if not preview_active or not _is_deep_prediction_requested() or not _has_staged_input:
		return false
	_deep_request_suppressed_until_input_change = false
	_deep_force_requests += 1
	return _request_deep_prediction("forced_deep_prediction", true)


func cancel_pending_deep_prediction() -> void:
	if staged_prediction_state not in [
		STAGED_STATE_WAITING_FOR_SETTLE,
		STAGED_STATE_DEEP_REQUESTED,
		STAGED_STATE_DEEP_RUNNING,
		STAGED_STATE_DEEP_STALE,
	]:
		return
	var canceled_before_run: bool = _profiled_pending_deep_request
	_request_generation += 1
	_current_deep_request_id = 0
	_current_deep_request_snapshot = {}
	current_cloned_prediction = {}
	_accepted_deep_request_snapshot = {}
	_accepted_deep_cache_hit = false
	_deep_reveal_progress = 0.0
	_deep_reveal_active = false
	_deep_reveal_completed_noted = false
	_deep_reveal_preparation_pending_us = 0
	_deep_request_suppressed_until_input_change = true
	staged_prediction_state = STAGED_STATE_IMMEDIATE_ONLY
	staged_prediction_reason = "canceled_deep_request"
	if canceled_before_run:
		_profiled_pending_deep_request = false
		_deep_requests_canceled_before_run += 1
		if trajectory_profiler != null:
			trajectory_profiler.note_deep_request_canceled_before_run("debug_cancel")
		if benchmark_session != null:
			benchmark_session.note_deep_request_canceled_before_run("debug_cancel")
	_queue_aim_redraw()


func _handle_staged_aim_input(
	origin: Vector2,
	launch_velocity: Vector2,
	effect_hash: int,
	effect_changed: bool,
	immediate_update_reason: String
) -> void:
	var meaningful_change: bool = _is_meaningful_staged_input_change(
		origin,
		launch_velocity,
		effect_hash
	)
	_latest_staged_origin = origin
	_latest_staged_launch_velocity = launch_velocity
	_latest_staged_effect_hash = effect_hash
	_has_staged_input = true

	if not _is_deep_prediction_requested():
		if (
			bool(current_cloned_prediction.get("valid", false))
			or staged_prediction_state in [
				STAGED_STATE_WAITING_FOR_SETTLE,
				STAGED_STATE_DEEP_REQUESTED,
				STAGED_STATE_DEEP_RUNNING,
			]
		):
			_invalidate_staged_deep_prediction("invalidated_effect_revision", false)
		_deep_request_suppressed_until_input_change = false
		current_cloned_prediction = {}
		_stale_cloned_prediction = {}
		_accepted_deep_request_snapshot = {}
		_accepted_deep_cache_hit = false
		staged_prediction_state = STAGED_STATE_IMMEDIATE_ONLY
		staged_prediction_reason = "immediate_preview_active"
		return

	if not _is_staged_deep_prediction_enabled():
		_request_deep_prediction("immediate_preview_drag", false)
		return

	if meaningful_change:
		_deep_request_suppressed_until_input_change = false
		_last_meaningful_input_usec = Time.get_ticks_usec()
		if effect_changed:
			_pending_deep_reason = "config_deep_prediction"
		elif not (
			staged_prediction_state == STAGED_STATE_WAITING_FOR_SETTLE
			and _pending_deep_reason in [
				"table_revision_deep_prediction",
				"config_deep_prediction",
			]
		):
			_pending_deep_reason = "settled_deep_prediction"
		_invalidate_staged_deep_prediction(
			_get_staged_input_invalidation_reason(immediate_update_reason, effect_changed),
			true
		)
	elif (
		staged_prediction_state in [STAGED_STATE_IDLE, STAGED_STATE_IMMEDIATE_ONLY]
		and not _deep_request_suppressed_until_input_change
	):
		_last_meaningful_input_usec = Time.get_ticks_usec()
		_pending_deep_reason = "settled_deep_prediction"
		staged_prediction_state = STAGED_STATE_WAITING_FOR_SETTLE
		staged_prediction_reason = "waiting_for_aim_to_settle"
		_begin_profiled_pending_deep_request()


func _get_staged_input_invalidation_reason(
	immediate_update_reason: String,
	effect_changed: bool
) -> String:
	if effect_changed or immediate_update_reason == "immediate_preview_config":
		return "invalidated_effect_revision"
	if immediate_update_reason == "immediate_preview_power":
		return "invalidated_power_changed"
	return "invalidated_aim_changed"


func _is_meaningful_staged_input_change(
	origin: Vector2,
	launch_velocity: Vector2,
	effect_hash: int
) -> bool:
	if not _has_staged_input:
		return true
	if origin.distance_to(_latest_staged_origin) > STAGED_ORIGIN_TOLERANCE_PX:
		return true
	if effect_hash != _latest_staged_effect_hash:
		return true
	var previous_speed: float = _latest_staged_launch_velocity.length()
	var current_speed: float = launch_velocity.length()
	var speed_scale: float = maxf(maxf(previous_speed, current_speed), 1.0)
	if absf(current_speed - previous_speed) / speed_scale > STAGED_POWER_RELATIVE_TOLERANCE:
		return true
	if previous_speed <= 0.001 or current_speed <= 0.001:
		return previous_speed > 0.001 or current_speed > 0.001
	var angle_delta_degrees: float = absf(rad_to_deg(
		_latest_staged_launch_velocity.angle_to(launch_velocity)
	))
	return angle_delta_degrees > STAGED_DIRECTION_TOLERANCE_DEGREES


func _classify_immediate_update_reason(
	origin: Vector2,
	launch_velocity: Vector2,
	effect_hash: int,
	effect_changed: bool
) -> String:
	if not _has_staged_input:
		return "immediate_preview_initial"
	if effect_changed or effect_hash != _latest_staged_effect_hash:
		return "immediate_preview_config"
	if _pending_deep_reason == "table_revision_deep_prediction" and (
		staged_prediction_state in [STAGED_STATE_WAITING_FOR_SETTLE, STAGED_STATE_DEEP_STALE]
	):
		return "immediate_preview_table_revision"
	if origin.distance_to(_latest_staged_origin) > STAGED_ORIGIN_TOLERANCE_PX:
		return "immediate_preview_origin"
	var previous_speed: float = _latest_staged_launch_velocity.length()
	var current_speed: float = launch_velocity.length()
	var speed_scale: float = maxf(maxf(previous_speed, current_speed), 1.0)
	if absf(current_speed - previous_speed) / speed_scale > STAGED_POWER_RELATIVE_TOLERANCE:
		return "immediate_preview_power"
	if previous_speed > 0.001 and current_speed > 0.001:
		var angle_delta_degrees: float = absf(rad_to_deg(
			_latest_staged_launch_velocity.angle_to(launch_velocity)
		))
		if angle_delta_degrees > STAGED_DIRECTION_TOLERANCE_DEGREES:
			return "immediate_preview_drag"
	return "immediate_preview_refresh"


func _update_staged_prediction(input_refresh_pending: bool) -> void:
	if (
		not preview_active
		or not _has_staged_input
		or not _is_deep_prediction_requested()
		or not _is_staged_deep_prediction_enabled()
		or input_refresh_pending
	):
		return
	if staged_prediction_state == STAGED_STATE_DEEP_STALE:
		staged_prediction_state = STAGED_STATE_WAITING_FOR_SETTLE
		staged_prediction_reason = "waiting_for_aim_to_settle"
	if staged_prediction_state != STAGED_STATE_WAITING_FOR_SETTLE:
		return
	var delay_usec: int = _get_deep_settle_delay_ms() * 1000
	if Time.get_ticks_usec() - _last_meaningful_input_usec < delay_usec:
		return
	_request_deep_prediction(_pending_deep_reason, false)


func _begin_profiled_pending_deep_request() -> void:
	if _profiled_pending_deep_request:
		return
	_profiled_pending_deep_request = true
	_note_deep_request_created(false)


func _note_deep_request_created(forced: bool) -> void:
	_deep_requests_created += 1
	if trajectory_profiler != null:
		trajectory_profiler.note_deep_request_created(forced)
	if benchmark_session != null:
		benchmark_session.note_deep_request_created(forced)


func _request_deep_prediction(rebuild_reason: String, forced: bool) -> bool:
	if not preview_active or not _has_staged_input or not _is_deep_prediction_requested():
		return false
	if _profiled_pending_deep_request:
		if forced:
			if trajectory_profiler != null:
				trajectory_profiler.note_deep_request_forced()
			if benchmark_session != null:
				benchmark_session.note_deep_request_forced()
		_profiled_pending_deep_request = false
	else:
		_note_deep_request_created(forced)
	_request_generation += 1
	var request_id: int = _request_generation
	_current_deep_request_id = request_id
	_current_deep_request_snapshot = _make_deep_request_snapshot(request_id)
	staged_prediction_state = STAGED_STATE_DEEP_REQUESTED
	staged_prediction_reason = rebuild_reason
	var request_usec: int = Time.get_ticks_usec()
	var compute_start_latency_usec: int = (
		maxi(request_usec - _last_meaningful_input_usec, 0)
		if _is_staged_deep_prediction_enabled()
		else 0
	)
	_deep_compute_start_latency_total_usec += compute_start_latency_usec
	_deep_compute_start_latency_samples += 1
	if trajectory_profiler != null:
		trajectory_profiler.note_deep_compute_started(compute_start_latency_usec)
	if benchmark_session != null:
		benchmark_session.note_deep_compute_started(compute_start_latency_usec)

	staged_prediction_state = STAGED_STATE_DEEP_RUNNING
	var use_debug_limits: bool = debug_aim_line_enabled
	_simulate_cloned_trajectory(
		_latest_staged_origin,
		_latest_staged_launch_velocity,
		use_debug_limits,
		rebuild_reason
	)
	var compute_usec: int = maxi(Time.get_ticks_usec() - request_usec, 0)
	_deep_compute_total_usec += compute_usec
	_deep_compute_samples += 1
	var cache_attempted: bool = current_cloned_prediction.has("cache_hit")
	var cache_hit: bool = bool(current_cloned_prediction.get("cache_hit", false))
	if cache_attempted:
		if cache_hit:
			_deep_cache_hits += 1
		else:
			_deep_cache_misses += 1

	var request_id_matches: bool = (
		request_id == _request_generation
		and request_id == _current_deep_request_id
	)
	var revisions_match: bool = _deep_request_snapshot_matches_current(
		_current_deep_request_snapshot
	)
	var request_is_current: bool = request_id_matches and revisions_match
	if not request_is_current:
		_deep_requests_completed += 1
		var rejection_reason: String = (
			"discarded_request_id_mismatch"
			if not request_id_matches
			else "discarded_revision_mismatch"
		)
		_deep_results_discarded_on_arrival += 1
		if rejection_reason == "discarded_request_id_mismatch":
			_deep_results_rejected_request_id_mismatch += 1
		else:
			_deep_results_rejected_revision_mismatch += 1
		if cache_hit:
			_cached_results_rejected += 1
		current_cloned_prediction = {}
		_current_deep_request_snapshot = {}
		staged_prediction_state = STAGED_STATE_DEEP_STALE
		staged_prediction_reason = rejection_reason
		if trajectory_profiler != null:
			trajectory_profiler.note_deep_completion(
				compute_usec,
				false,
				cache_hit,
				rejection_reason,
				cache_attempted
			)
		if benchmark_session != null:
			benchmark_session.note_deep_completion(
				compute_usec,
				false,
				cache_hit,
				rejection_reason,
				cache_attempted
			)
		return false

	if not bool(current_cloned_prediction.get("valid", false)) and not cache_attempted:
		_deep_requests_blocked_before_run += 1
		var blocked_reason: String = str(
			cloned_prediction_availability.get("blocker_reason", "deep_prediction_blocked")
		)
		if trajectory_profiler != null:
			trajectory_profiler.note_deep_request_blocked_before_run(blocked_reason)
		if benchmark_session != null:
			benchmark_session.note_deep_request_blocked_before_run(blocked_reason)
		_current_deep_request_snapshot = {}
		staged_prediction_state = STAGED_STATE_BLOCKED
		staged_prediction_reason = blocked_reason
		return false

	_deep_requests_completed += 1
	if not bool(current_cloned_prediction.get("valid", false)):
		_current_deep_request_snapshot = {}
		staged_prediction_state = STAGED_STATE_BLOCKED
		staged_prediction_reason = str(
			cloned_prediction_availability.get("blocker_reason", "deep_prediction_blocked")
		)
		if trajectory_profiler != null:
			trajectory_profiler.note_deep_completion(
				compute_usec,
				false,
				cache_hit,
				"",
				cache_attempted
			)
		if benchmark_session != null:
			benchmark_session.note_deep_completion(
				compute_usec,
				false,
				cache_hit,
				"",
				cache_attempted
			)
		return false

	current_cloned_prediction["deep_request_id"] = request_id
	current_cloned_prediction["deep_request_snapshot"] = _current_deep_request_snapshot.duplicate(true)
	if cache_hit:
		current_cloned_prediction["rebuild_reason"] = "cache_hit_deep_prediction"
		_deep_reused_results += 1
	_accepted_deep_cache_hit = cache_hit
	_last_accepted_deep_request_id = request_id
	_last_stale_deep_request_id = 0
	_accepted_deep_request_snapshot = _current_deep_request_snapshot.duplicate(true)
	_current_deep_request_snapshot = {}
	_stale_cloned_prediction = {}
	_deep_requests_accepted += 1
	if cache_hit:
		_cached_results_accepted += 1
	if forced:
		pass
	elif rebuild_reason in ["settled_deep_prediction", "table_revision_deep_prediction", "config_deep_prediction"]:
		_settled_deep_rebuilds += 1
	else:
		_active_drag_deep_rebuilds += 1
	staged_prediction_state = STAGED_STATE_DEEP_READY
	staged_prediction_reason = (
		"cache_hit_deep_prediction" if cache_hit else "deep_prediction_ready"
	)
	_prepare_deep_reveal()
	if trajectory_profiler != null:
		trajectory_profiler.note_deep_completion(
			compute_usec,
			true,
			cache_hit,
			"",
			cache_attempted
		)
	if benchmark_session != null:
		benchmark_session.note_deep_completion(
			compute_usec,
			true,
			cache_hit,
			"",
			cache_attempted
		)
	_queue_aim_redraw()
	return true


func _make_deep_request_snapshot(request_id: int) -> Dictionary:
	return {
		"request_id": request_id,
		"aim_direction": _latest_staged_launch_velocity.normalized(),
		"launch_velocity": _latest_staged_launch_velocity,
		"cue_origin": _latest_staged_origin,
		"table_prediction_revision": _observed_table_prediction_revision,
		"configuration_revision": _configuration_revision,
		"effect_snapshot_revision": _effect_snapshot_revision,
		"effect_snapshot_hash": _latest_staged_effect_hash,
		"boundary_geometry_revision": (
			table.boundary_system.get_prediction_geometry_revision()
			if table != null and table.boundary_system != null
			else -1
		),
		"pocket_geometry_revision": (
			table.pocket_system.get_prediction_geometry_revision()
			if table != null and table.pocket_system != null
			else -1
		),
		"result_detail_mode": _get_requested_deep_result_mode(),
	}


func _deep_request_snapshot_matches_current(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	if int(snapshot.get("table_prediction_revision", -1)) != _observed_table_prediction_revision:
		return false
	if int(snapshot.get("configuration_revision", -1)) != _configuration_revision:
		return false
	if int(snapshot.get("effect_snapshot_revision", -1)) != _effect_snapshot_revision:
		return false
	if int(snapshot.get("effect_snapshot_hash", 0)) != _latest_staged_effect_hash:
		return false
	var snapshot_origin: Vector2 = snapshot.get("cue_origin", Vector2.ZERO)
	if snapshot_origin.distance_to(_latest_staged_origin) > 0.001:
		return false
	var snapshot_velocity: Vector2 = snapshot.get("launch_velocity", Vector2.ZERO)
	if snapshot_velocity.distance_to(_latest_staged_launch_velocity) > 0.001:
		return false
	if table != null and table.boundary_system != null:
		if int(snapshot.get("boundary_geometry_revision", -1)) != int(
			table.boundary_system.get_prediction_geometry_revision()
		):
			return false
	if table != null and table.pocket_system != null:
		if int(snapshot.get("pocket_geometry_revision", -1)) != int(
			table.pocket_system.get_prediction_geometry_revision()
		):
			return false
	return str(snapshot.get("result_detail_mode", "")) == _get_requested_deep_result_mode()


func _get_requested_deep_result_mode() -> String:
	if debug_aim_line_enabled:
		return str(cloned_trajectory_configuration.get(
			"result_detail_mode",
			AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
		))
	return str(AIM_TRAJECTORY_PREDICTOR_SCRIPT.get_player_long_sight_configuration(
		_get_active_aim_chain_depth(),
		int(table.PHYSICS_SUBSTEPS) if table != null else 4
	).get("result_detail_mode", AimTrajectoryPredictor.RESULT_MODE_PLAYER_MINIMAL))


func _is_deep_prediction_requested() -> bool:
	var cloned_enabled: bool = bool(cloned_trajectory_configuration.get("enabled", true))
	return cloned_enabled and (
		debug_aim_line_enabled
		or (
			_get_active_aim_chain_depth() > 0
			and bool(cloned_trajectory_configuration.get("use_for_long_sight", true))
		)
	)


func _is_staged_deep_prediction_enabled() -> bool:
	return bool(staged_prediction_configuration.get(
		AIM_STAGING_CONFIGURATION_SCRIPT.USE_STAGED_DEEP_PREDICTION,
		true
	))


func _get_deep_settle_delay_ms() -> int:
	return int(staged_prediction_configuration.get(
		AIM_STAGING_CONFIGURATION_SCRIPT.DEEP_AIM_SETTLE_DELAY_MS,
		75
	))


func _invalidate_staged_deep_prediction(reason: String, restart_wait: bool) -> void:
	var had_deep_result: bool = bool(current_cloned_prediction.get("valid", false))
	var had_pending_before_run: bool = _profiled_pending_deep_request
	var keep_stale_visible: bool = had_deep_result and bool(
		staged_prediction_configuration.get(
			AIM_STAGING_CONFIGURATION_SCRIPT.KEEP_STALE_DEEP_AIM_FAINTLY_VISIBLE,
			false
		)
	)
	var shown_result: bool = had_deep_result and _deep_reveal_visible_noted
	var hidden_by_new_aim: bool = (
		shown_result
		and not keep_stale_visible
		and reason in [
			"invalidated_aim_changed",
			"invalidated_power_changed",
			"invalidated_effect_revision",
		]
	)
	if had_pending_before_run:
		_profiled_pending_deep_request = false
		_deep_requests_invalidated_before_run += 1
		if trajectory_profiler != null:
			trajectory_profiler.note_deep_request_invalidated_before_run(reason)
		if benchmark_session != null:
			benchmark_session.note_deep_request_invalidated_before_run(reason)
	if had_deep_result:
		_last_stale_deep_request_id = _last_accepted_deep_request_id
		if shown_result:
			_shown_results_later_invalidated += 1
			if hidden_by_new_aim:
				_shown_results_hidden_by_new_aim += 1
			if trajectory_profiler != null:
				trajectory_profiler.note_shown_result_later_invalidated(
					reason,
					hidden_by_new_aim
				)
			if benchmark_session != null:
				benchmark_session.note_shown_result_later_invalidated(
					reason,
					hidden_by_new_aim
				)
	_interrupt_active_deep_reveal(_get_reveal_interruption_reason(reason))
	if keep_stale_visible:
		_stale_cloned_prediction = current_cloned_prediction
	else:
		_stale_cloned_prediction = {}
	_request_generation += 1
	_current_deep_request_id = 0
	_current_deep_request_snapshot = {}
	_accepted_deep_request_snapshot = {}
	_accepted_deep_cache_hit = false
	current_cloned_prediction = {}
	_deep_reveal_progress = 0.0
	_deep_reveal_active = false
	_deep_reveal_preparation_pending_us = 0
	_deep_reveal_visible_noted = false
	_deep_reveal_completed_noted = false
	if restart_wait and preview_active and _has_staged_input and _is_deep_prediction_requested():
		_last_meaningful_input_usec = Time.get_ticks_usec()
		if had_deep_result:
			staged_prediction_state = STAGED_STATE_DEEP_STALE
			staged_prediction_reason = "deep_result_stale: %s" % reason
		else:
			staged_prediction_state = STAGED_STATE_WAITING_FOR_SETTLE
			staged_prediction_reason = "waiting_for_aim_to_settle"
		_begin_profiled_pending_deep_request()
	else:
		staged_prediction_state = STAGED_STATE_IMMEDIATE_ONLY if preview_active else STAGED_STATE_IDLE
		staged_prediction_reason = reason


func _reset_staged_prediction_runtime(reason: String) -> void:
	if _profiled_pending_deep_request:
		_profiled_pending_deep_request = false
		_deep_requests_invalidated_before_run += 1
		if trajectory_profiler != null:
			trajectory_profiler.note_deep_request_invalidated_before_run(
				"invalidated_preview_inactive"
			)
		if benchmark_session != null:
			benchmark_session.note_deep_request_invalidated_before_run(
				"invalidated_preview_inactive"
			)
	_interrupt_active_deep_reveal("reveal_interrupted_by_preview_inactive")
	_request_generation += 1
	_current_deep_request_id = 0
	_current_deep_request_snapshot = {}
	_accepted_deep_request_snapshot = {}
	_accepted_deep_cache_hit = false
	_has_staged_input = false
	_deep_reveal_progress = 0.0
	_deep_reveal_active = false
	_deep_reveal_visible_noted = false
	_deep_reveal_completed_noted = false
	_deep_reveal_preparation_pending_us = 0
	_deep_reveal_max_depth = 0
	_deep_reveal_visible_branches = 0
	_last_stale_deep_request_id = 0
	_deep_request_suppressed_until_input_change = false
	_profiled_pending_deep_request = false
	staged_prediction_state = STAGED_STATE_IDLE
	staged_prediction_reason = reason


func _get_reveal_interruption_reason(invalidation_reason: String) -> String:
	if invalidation_reason in [
		"invalidated_aim_changed",
		"invalidated_power_changed",
		"invalidated_effect_revision",
	]:
		return "reveal_interrupted_by_aim"
	if invalidation_reason == "invalidated_table_revision":
		return "reveal_interrupted_by_table_change"
	if invalidation_reason == "invalidated_config_revision":
		return "reveal_interrupted_by_config_revision"
	return "reveal_interrupted_by_other"


func _interrupt_active_deep_reveal(reason: String) -> void:
	if not _deep_reveal_active or _deep_reveal_completed_noted:
		return
	_deep_reveal_active = false
	_reveal_interrupted_count += 1
	if trajectory_profiler != null:
		trajectory_profiler.note_reveal_interrupted(reason)
	if benchmark_session != null:
		benchmark_session.note_reveal_interrupted(reason)


func _prepare_deep_reveal() -> void:
	var preparation_start_usec: int = Time.get_ticks_usec()
	_deep_reveal_max_depth = 0
	_deep_reveal_visible_branches = 0
	for ball_value in current_cloned_prediction.get("balls", []):
		if not ball_value is Dictionary:
			continue
		var ball_result: Dictionary = ball_value
		_deep_reveal_max_depth = maxi(
			_deep_reveal_max_depth,
			int(ball_result.get("generation_depth", 0))
		)
	_deep_reveal_preparation_us = maxi(Time.get_ticks_usec() - preparation_start_usec, 0)
	_deep_reveal_preparation_pending_us = _deep_reveal_preparation_us
	_deep_reveal_start_usec = Time.get_ticks_usec()
	_deep_reveal_active = true
	_deep_reveal_visible_noted = false
	_deep_reveal_completed_noted = false
	var progressive: bool = bool(staged_prediction_configuration.get(
		AIM_STAGING_CONFIGURATION_SCRIPT.PROGRESSIVE_DEEP_AIM_REVEAL,
		true
	))
	var reveal_duration_ms: int = int(staged_prediction_configuration.get(
		AIM_STAGING_CONFIGURATION_SCRIPT.DEEP_AIM_REVEAL_DURATION_MS,
		125
	))
	_deep_reveal_progress = 0.0 if progressive and reveal_duration_ms > 0 else 1.0
	if _deep_reveal_progress < 1.0:
		_deep_ready_but_hidden_count += 1


func _update_deep_reveal() -> void:
	if staged_prediction_state != STAGED_STATE_DEEP_READY:
		return
	if _deep_reveal_completed_noted:
		return
	var reveal_duration_ms: int = int(staged_prediction_configuration.get(
		AIM_STAGING_CONFIGURATION_SCRIPT.DEEP_AIM_REVEAL_DURATION_MS,
		125
	))
	if reveal_duration_ms <= 0 or not bool(staged_prediction_configuration.get(
		AIM_STAGING_CONFIGURATION_SCRIPT.PROGRESSIVE_DEEP_AIM_REVEAL,
		true
	)):
		_deep_reveal_progress = 1.0
	else:
		var elapsed_usec: int = maxi(Time.get_ticks_usec() - _deep_reveal_start_usec, 0)
		_deep_reveal_progress = clampf(
			float(elapsed_usec) / float(reveal_duration_ms * 1000),
			0.0,
			1.0
		)
	if _deep_reveal_progress > 0.0:
		_note_deep_result_visible()
	else:
		_deep_ready_but_hidden_count += 1
	if _deep_reveal_progress >= 1.0:
		_note_deep_reveal_completed()
	_queue_aim_redraw()


func _note_deep_result_visible() -> void:
	if _deep_reveal_visible_noted:
		return
	_deep_reveal_visible_noted = true
	_accepted_results_shown += 1
	if _accepted_deep_cache_hit:
		_shown_results_reused_from_cache += 1
	var visible_latency_usec: int = maxi(
		Time.get_ticks_usec() - _last_meaningful_input_usec,
		0
	)
	_deep_first_visible_latency_total_usec += visible_latency_usec
	_deep_first_visible_latency_samples += 1
	if trajectory_profiler != null:
		trajectory_profiler.note_deep_visible(visible_latency_usec, _accepted_deep_cache_hit)
	if benchmark_session != null:
		benchmark_session.note_deep_visible(visible_latency_usec, _accepted_deep_cache_hit)


func _note_deep_reveal_completed() -> void:
	if _deep_reveal_completed_noted:
		return
	_deep_reveal_completed_noted = true
	_deep_reveal_active = false
	var now_usec: int = Time.get_ticks_usec()
	var fully_visible_latency_usec: int = maxi(now_usec - _last_meaningful_input_usec, 0)
	var actual_reveal_duration_usec: int = maxi(now_usec - _deep_reveal_start_usec, 0)
	_reveal_completed_count += 1
	_reveal_completed_before_next_aim_count += 1
	if trajectory_profiler != null:
		trajectory_profiler.note_reveal_completed(
			fully_visible_latency_usec,
			actual_reveal_duration_usec
		)
	if benchmark_session != null:
		benchmark_session.note_reveal_completed(
			fully_visible_latency_usec,
			actual_reveal_duration_usec
		)


func _get_deep_reveal_alpha(generation_depth: int, is_cue: bool) -> float:
	if _deep_reveal_progress >= 1.0:
		return 1.0
	var reveal_start: float = 0.0
	if not is_cue:
		if generation_depth <= 1:
			reveal_start = 0.22
		else:
			var depth_ratio: float = float(generation_depth - 2) / float(
				maxi(_deep_reveal_max_depth - 1, 1)
			)
			reveal_start = lerpf(0.46, 0.82, clampf(depth_ratio, 0.0, 1.0))
	var reveal_end: float = minf(reveal_start + 0.28, 1.0)
	return smoothstep(reveal_start, reveal_end, _deep_reveal_progress)


func _get_deep_prediction_commit_status(origin: Vector2, launch_velocity: Vector2) -> String:
	if (
		staged_prediction_state == STAGED_STATE_DEEP_READY
		and bool(current_cloned_prediction.get("valid", false))
		and _deep_request_snapshot_matches_commit(
			_accepted_deep_request_snapshot,
			origin,
			launch_velocity
		)
	):
		return "deep_prediction_ready"
	if (
		_last_stale_deep_request_id > 0
		or not _stale_cloned_prediction.is_empty()
		or not _accepted_deep_request_snapshot.is_empty()
	):
		return "stale_prediction_at_commit"
	if current_prediction != null:
		return "immediate_only_at_commit"
	return "deep_prediction_not_ready"


func _deep_request_snapshot_matches_commit(
	snapshot: Dictionary,
	origin: Vector2,
	launch_velocity: Vector2
) -> bool:
	if not _deep_request_snapshot_matches_current(snapshot):
		return false
	var snapshot_origin: Vector2 = snapshot.get("cue_origin", Vector2.ZERO)
	var snapshot_velocity: Vector2 = snapshot.get("launch_velocity", Vector2.ZERO)
	return (
		snapshot_origin.distance_to(origin) <= 0.001
		and snapshot_velocity.distance_to(launch_velocity) <= 0.001
	)


func _simulate_cloned_trajectory(
	origin: Vector2,
	launch_velocity: Vector2,
	use_debug_limits: bool,
	rebuild_reason: String = "unknown"
) -> void:
	if trajectory_predictor == null or table == null:
		current_cloned_prediction = {}
		return
	var configuration: Dictionary = cloned_trajectory_configuration.duplicate(true)
	if not use_debug_limits:
		configuration = AIM_TRAJECTORY_PREDICTOR_SCRIPT.get_player_long_sight_configuration(
			_get_active_aim_chain_depth(),
			int(table.PHYSICS_SUBSTEPS)
		)
		configuration["enabled"] = true
		configuration["profile_enabled"] = bool(
			cloned_trajectory_configuration.get("profile_enabled", false)
		)
	var benchmark_recording: bool = benchmark_session != null and benchmark_session.is_recording()
	if benchmark_recording:
		configuration["profile_enabled"] = true
	var profile_enabled: bool = bool(configuration.get("profile_enabled", false))
	if trajectory_profiler != null:
		trajectory_profiler.set_enabled(profile_enabled)
	var full_rebuild_start_usec: int = Time.get_ticks_usec() if profile_enabled else 0
	var input_snapshot_start_usec: int = Time.get_ticks_usec() if profile_enabled else 0
	var input_snapshot: Dictionary = _build_cloned_trajectory_input(origin, launch_velocity)
	var input_snapshot_usec: int = (
		maxi(Time.get_ticks_usec() - input_snapshot_start_usec, 0)
		if profile_enabled
		else 0
	)
	var rebuild_classification: String = _classify_cloned_rebuild(
		origin,
		launch_velocity,
		rebuild_reason
	)
	_cloned_configuration_changed_since_rebuild = false
	_last_cloned_rebuild_origin = origin
	_last_cloned_rebuild_velocity = launch_velocity
	_has_last_cloned_rebuild_input = true
	cloned_prediction_availability = _evaluate_cloned_prediction_availability(
		input_snapshot,
		launch_velocity,
		true,
		configuration
	)
	if not bool(cloned_prediction_availability.get("available", false)):
		current_cloned_prediction = _make_unavailable_cloned_prediction_result(
			configuration,
			cloned_prediction_availability
		)
		_note_failed_cloned_rebuild_after_invalidation()
		_queue_aim_redraw()
		return
	current_cloned_prediction = trajectory_predictor.simulate(
		input_snapshot,
		configuration
	)
	current_cloned_prediction["rebuild_reason"] = rebuild_reason
	var cloned_balls_value: Variant = current_cloned_prediction.get("balls", [])
	var cloned_ball_count: int = cloned_balls_value.size() if cloned_balls_value is Array else 0
	cloned_prediction_availability["cloned_ball_count"] = cloned_ball_count
	cloned_prediction_availability["cache_valid"] = true
	cloned_prediction_availability["cached_revision"] = int(
		current_cloned_prediction.get("table_revision", -1)
	)
	if bool(current_cloned_prediction.get("valid", false)):
		_last_successful_cloned_rebuild_revision = int(
			input_snapshot.get("table_prediction_revision", -1)
		)
		if _cloned_refresh_pending:
			_cloned_successful_rebuilds_after_invalidation += 1
		_cloned_refresh_pending = false
		cloned_prediction_availability["refresh_pending"] = false
		cloned_prediction_availability["last_successful_rebuild_revision"] = (
			_last_successful_cloned_rebuild_revision
		)
	else:
		_note_failed_cloned_rebuild_after_invalidation()
	current_cloned_prediction["prediction_availability"] = cloned_prediction_availability.duplicate(true)
	if bool(current_cloned_prediction.get("cache_hit", false)):
		if benchmark_recording:
			benchmark_session.note_cache_hit()
		return
	if not profile_enabled:
		return

	var phase_timings: Dictionary = current_cloned_prediction.get(
		"profile_phase_timings_us",
		{}
	).duplicate(true)
	phase_timings["input_snapshot"] = input_snapshot_usec

	var comparison_snapshot: Dictionary = {}
	if _should_build_cloned_event_comparison(configuration):
		var comparison_start_usec: int = Time.get_ticks_usec()
		comparison_snapshot = _get_cloned_event_comparison_snapshot()
		phase_timings["predicted_actual_comparison"] = maxi(
			Time.get_ticks_usec() - comparison_start_usec,
			0
		)
	else:
		phase_timings["predicted_actual_comparison"] = 0

	var draw_preparation_start_usec: int = Time.get_ticks_usec()
	var draw_workload: Dictionary = _get_cloned_draw_profile_workload(current_cloned_prediction)
	phase_timings["draw_data_preparation"] = maxi(
		Time.get_ticks_usec() - draw_preparation_start_usec,
		0
	)
	phase_timings["total_full_rebuild"] = maxi(
		Time.get_ticks_usec() - full_rebuild_start_usec,
		0
	)

	var predicted_events: Array = current_cloned_prediction.get("events", [])
	var compared_events: Array = comparison_snapshot.get("entries", [])
	var sample: Dictionary = {
		"completed_usec": Time.get_ticks_usec(),
		"rebuild_reason": rebuild_reason,
		"rebuild_classification": rebuild_classification,
		"phase_timings_us": phase_timings,
		"setup": _make_cloned_benchmark_setup_snapshot(input_snapshot, configuration, launch_velocity),
		"simulated_physics_frames": int(current_cloned_prediction.get("simulated_physics_frames", 0)),
		"simulated_substeps": int(current_cloned_prediction.get("simulated_substeps", 0)),
		"total_iterations": int(current_cloned_prediction.get("total_iterations", 0)),
		"geometry_probes": int(current_cloned_prediction.get("geometry_probes", 0)),
		"control_iteration_budget": int(current_cloned_prediction.get("control_iteration_budget", 0)),
		"geometry_probe_budget": int(current_cloned_prediction.get("geometry_probe_budget", 0)),
		"iteration_breakdown": _duplicate_dictionary_field(current_cloned_prediction, "iteration_breakdown"),
		"completed_iteration_breakdown": _duplicate_dictionary_field(
			current_cloned_prediction,
			"completed_iteration_breakdown"
		),
		"iteration_source_attempts": _duplicate_dictionary_field(
			current_cloned_prediction,
			"iteration_source_attempts"
		),
		"iteration_cap_detail": _duplicate_dictionary_field(
			current_cloned_prediction,
			"iteration_cap_detail"
		),
		"geometry_probe_cap_detail": _duplicate_dictionary_field(
			current_cloned_prediction,
			"geometry_probe_cap_detail"
		),
		"broadphase_rebuilds": int(current_cloned_prediction.get("broadphase_rebuilds", 0)),
		"full_broadphase_rebuilds": int(current_cloned_prediction.get("full_broadphase_rebuilds", 0)),
		"incremental_broadphase_updates": int(current_cloned_prediction.get("incremental_broadphase_updates", 0)),
		"current_grid_rebuilds": int(current_cloned_prediction.get("current_grid_rebuilds", 0)),
		"swept_grid_rebuilds": int(current_cloned_prediction.get("swept_grid_rebuilds", 0)),
		"candidate_tests": int(current_cloned_prediction.get("candidate_tests", 0)),
		"pair_checks": int(current_cloned_prediction.get("pair_checks", 0)),
		"swept_toi_solves": int(current_cloned_prediction.get("swept_toi_solves", 0)),
		"contacts_resolved": int(current_cloned_prediction.get("total_ball_contacts", 0)),
		"total_ball_contacts": int(current_cloned_prediction.get("total_ball_contacts", 0)),
		"total_cue_ball_contacts": int(current_cloned_prediction.get("total_cue_ball_contacts", 0)),
		"total_rail_contacts": int(current_cloned_prediction.get("total_rail_contacts", 0)),
		"total_pocket_captures": int(current_cloned_prediction.get("total_pocket_captures", 0)),
		"total_stops": int(current_cloned_prediction.get("total_stops", 0)),
		"balls_traced": int(current_cloned_prediction.get("total_traced_balls", 0)),
		"trace_points": int(current_cloned_prediction.get("retained_trace_points", 0)),
		"raw_trace_points": int(current_cloned_prediction.get("raw_trace_points_generated", 0)),
		"retained_trace_points": int(current_cloned_prediction.get("retained_trace_points", 0)),
		"simplified_trace_points": int(current_cloned_prediction.get("trace_points_removed_by_simplification", 0)),
		"spacing_or_duplicate_trace_points": int(current_cloned_prediction.get("trace_points_removed_by_spacing_or_duplicates", 0)),
		"collinear_simplified_trace_points": int(current_cloned_prediction.get("trace_points_removed_by_collinear_simplification", 0)),
		"visible_path_segments": int(draw_workload.get("visible_path_segments", 0)),
		"predicted_balls_drawn": int(draw_workload.get("predicted_balls_drawn", 0)),
		"visible_paths": int(draw_workload.get("visible_paths", 0)),
		"predicted_event_count": predicted_events.size(),
		"compared_event_count": compared_events.size(),
		"predicted_events_retained": int(current_cloned_prediction.get("predicted_events_retained", predicted_events.size())),
		"debug_events_retained": int(current_cloned_prediction.get("debug_events_retained", 0)),
		"compared_events": compared_events.size(),
		"maximum_causal_depth": int(current_cloned_prediction.get("maximum_causal_depth", 0)),
		"maximum_simultaneously_moving_balls": int(current_cloned_prediction.get("maximum_simultaneously_moving_balls", 0)),
		"moving_balls_per_substep_average": float(current_cloned_prediction.get("moving_balls_per_substep_average", 0.0)),
		"moving_balls_per_substep_maximum": int(current_cloned_prediction.get("moving_balls_per_substep_maximum", 0)),
		"stationary_targets_per_substep_average": float(current_cloned_prediction.get("stationary_targets_per_substep_average", 0.0)),
		"stationary_targets_per_substep_maximum": int(current_cloned_prediction.get("stationary_targets_per_substep_maximum", 0)),
		"balls_newly_stopped": int(current_cloned_prediction.get("balls_newly_stopped", 0)),
		"boundary_shapes_available": int(current_cloned_prediction.get("boundary_shapes_available", 0)),
		"rail_shapes_available": int(current_cloned_prediction.get("rail_shapes_available", 0)),
		"jaw_shapes_available": int(current_cloned_prediction.get("jaw_shapes_available", 0)),
		"rail_candidate_queries": int(current_cloned_prediction.get("rail_candidate_queries", 0)),
		"rail_shapes_tested": int(current_cloned_prediction.get("rail_shapes_tested", 0)),
		"jaw_shapes_tested": int(current_cloned_prediction.get("jaw_shapes_tested", 0)),
		"rail_swept_tests": int(current_cloned_prediction.get("rail_swept_tests", 0)),
		"rail_candidates_rejected_by_aabb": int(current_cloned_prediction.get("rail_candidates_rejected_by_aabb", 0)),
		"rail_events_accepted": int(current_cloned_prediction.get("rail_events_accepted", 0)),
		"pocket_count_available": int(current_cloned_prediction.get("pocket_count_available", 0)),
		"pocket_candidate_queries": int(current_cloned_prediction.get("pocket_candidate_queries", 0)),
		"pockets_tested": int(current_cloned_prediction.get("pockets_tested", 0)),
		"pocket_swept_tests": int(current_cloned_prediction.get("pocket_swept_tests", 0)),
		"pocket_candidates_rejected_by_aabb": int(current_cloned_prediction.get("pocket_candidates_rejected_by_aabb", 0)),
		"pocket_events_accepted": int(current_cloned_prediction.get("pocket_events_accepted", 0)),
		"cloned_balls_checked_against_boundaries": int(current_cloned_prediction.get("cloned_balls_checked_against_boundaries", 0)),
		"cloned_balls_checked_against_pockets": int(current_cloned_prediction.get("cloned_balls_checked_against_pockets", 0)),
		"stopped_balls_skipped_from_movement": int(current_cloned_prediction.get("stopped_balls_skipped_from_movement", 0)),
		"stopped_balls_skipped_from_rail_checks": int(current_cloned_prediction.get("stopped_balls_skipped_from_rail_checks", 0)),
		"stopped_balls_skipped_from_pocket_checks": int(current_cloned_prediction.get("stopped_balls_skipped_from_pocket_checks", 0)),
		"stopped_balls_included_in_broadphase": int(current_cloned_prediction.get("stopped_balls_included_in_broadphase", 0)),
		"inactive_balls_skipped_from_loops": int(current_cloned_prediction.get("inactive_balls_skipped_from_loops", 0)),
		"repeated_boundary_checks": int(current_cloned_prediction.get("repeated_boundary_checks", 0)),
		"remaining_time_boundary_iterations": int(current_cloned_prediction.get("remaining_time_boundary_iterations", 0)),
		"boundary_temporary_objects_created": int(current_cloned_prediction.get("boundary_temporary_objects_created", 0)),
		"pocket_temporary_objects_created": int(current_cloned_prediction.get("pocket_temporary_objects_created", 0)),
		"static_geometry_cache_hits": int(current_cloned_prediction.get("static_geometry_cache_hits", 0)),
		"static_geometry_cache_rebuilds": int(current_cloned_prediction.get("static_geometry_cache_rebuilds", 0)),
		"scratch_buffer_reuses": int(current_cloned_prediction.get("scratch_buffer_reuses", 0)),
		"temporary_allocations": int(current_cloned_prediction.get("temporary_allocations", 0)),
		"prediction_availability": cloned_prediction_availability.duplicate(true),
		"invalidation": _get_cloned_invalidation_snapshot(),
		"result_memory_estimate_bytes": int(current_cloned_prediction.get("result_memory_estimate_bytes", 0)),
		"stop_reason": str(current_cloned_prediction.get("stop_reason", "unknown")),
	}
	if trajectory_profiler != null:
		trajectory_profiler.record_completed_rebuild(sample)
	if benchmark_recording:
		benchmark_session.record_completed_rebuild(sample)


func _build_cloned_trajectory_input(origin: Vector2, launch_velocity: Vector2) -> Dictionary:
	var ball_snapshots: Array[Dictionary] = []
	var source_index: int = 0
	for child in table.balls.get_children():
		var ball: Ball = child as Ball
		if ball == null or not is_instance_valid(ball) or ball.is_queued_for_deletion():
			continue
		var transient_state: Dictionary = ball.get_prediction_transient_state()
		ball_snapshots.append({
			"source_id": ball.get_instance_id(),
			"source_index": source_index,
			"ball_number": ball.ball_number,
			"label": _get_debug_ball_label(ball),
			"position": ball.global_position,
			"velocity": ball.velocity,
			"launch_position": origin if ball == table.cue_ball else ball.global_position,
			"launch_velocity": launch_velocity if ball == table.cue_ball else ball.velocity,
			"radius": ball.radius,
			"ball_type": ball.ball_type,
			"is_cue_ball": ball == table.cue_ball,
			"is_eight_ball": ball == table.eight_ball,
			"gameplay_active": ball.is_gameplay_active(),
			"motion_parameters": ball.get_prediction_motion_snapshot(),
			"anomaly_kind": _get_prediction_anomaly_kind(ball),
			"initial_unsupported_reason": _get_initial_prediction_unsupported_reason(
				ball,
				transient_state
			),
		})
		source_index += 1
	return {
		"balls": ball_snapshots,
		"table_prediction_revision": int(table.get_aim_prediction_state_revision()),
		"physics_constants": {
			"ball_collision_skin": float(table.BALL_COLLISION_SKIN),
			"ball_collision_restitution": float(table.BALL_COLLISION_RESTITUTION),
			"ball_velocity_transfer": float(table.BALL_VELOCITY_TRANSFER),
			"rail_restitution": float(table.RAIL_RESTITUTION),
			"collision_grid_cell_size": float(table.BALL_COLLISION_GRID_CELL_SIZE),
		},
		"boundary_geometry": table.boundary_system.get_prediction_geometry_snapshot(),
		"pocket_geometry": table.pocket_system.get_prediction_geometry_snapshot(),
		"boundary_geometry_revision": table.boundary_system.get_prediction_geometry_revision(),
		"pocket_geometry_revision": table.pocket_system.get_prediction_geometry_revision(),
		"boundary_system": table.boundary_system,
		"pocket_system": table.pocket_system,
		"effect_snapshot": active_effect_snapshot.duplicate(true),
		"cue_first_contact_toi_enabled": bool(table.cue_first_contact_toi_enabled),
		"default_substeps": int(table.PHYSICS_SUBSTEPS),
	}


func _make_default_cloned_prediction_availability() -> Dictionary:
	return {
		"available": false,
		"live_preview_requested": false,
		"cloned_simulation_enabled": bool(cloned_trajectory_configuration.get("enabled", true)),
		"cache_valid": false,
		"table_revision": _observed_table_prediction_revision,
		"cached_revision": -1,
		"active_ball_count": 0,
		"cloned_ball_count": 0,
		"transient_ball_count": 0,
		"unsupported_ball_count": 0,
		"moving_ball_count": 0,
		"pending_spawn_count": 0,
		"pending_landing_callbacks": false,
		"blocker_reason": "unknown",
		"blocker_details": "",
		"refresh_pending": _cloned_refresh_pending,
		"last_successful_rebuild_revision": _last_successful_cloned_rebuild_revision,
	}


func _refresh_cloned_availability_for_inactive_preview() -> void:
	if table == null:
		cloned_prediction_availability = _make_default_cloned_prediction_availability()
		cloned_prediction_availability["blocker_reason"] = "no_cue_ball"
		return
	var origin: Vector2 = (
		table.cue_ball.global_position
		if table.cue_ball != null and is_instance_valid(table.cue_ball)
		else Vector2.ZERO
	)
	var input_snapshot: Dictionary = _build_cloned_trajectory_input(origin, Vector2.ZERO)
	cloned_prediction_availability = _evaluate_cloned_prediction_availability(
		input_snapshot,
		Vector2.ZERO,
		false,
		cloned_trajectory_configuration
	)


func _evaluate_cloned_prediction_availability(
	input_snapshot: Dictionary,
	launch_velocity: Vector2,
	live_preview_requested: bool,
	configuration: Dictionary
) -> Dictionary:
	var availability: Dictionary = _make_default_cloned_prediction_availability()
	var table_revision: int = int(input_snapshot.get("table_prediction_revision", -1))
	var cache_snapshot: Dictionary = (
		trajectory_predictor.get_cache_debug_snapshot()
		if trajectory_predictor != null
		else {}
	)
	availability["live_preview_requested"] = live_preview_requested
	availability["cloned_simulation_enabled"] = bool(configuration.get("enabled", true))
	availability["table_revision"] = table_revision
	availability["cached_revision"] = int(cache_snapshot.get("cached_revision", -1))
	availability["cache_valid"] = (
		bool(cache_snapshot.get("has_cache", false))
		and int(cache_snapshot.get("cached_revision", -1)) == table_revision
	)

	var cue_found := false
	var cue_active := false
	var active_ball_count := 0
	var transient_ball_count := 0
	var unsupported_ball_count := 0
	var moving_ball_count := 0
	var transient_labels: Array[String] = []
	var unsupported_labels: Array[String] = []
	var ball_snapshots_value: Variant = input_snapshot.get("balls", [])
	var ball_snapshots: Array = ball_snapshots_value if ball_snapshots_value is Array else []
	for ball_value in ball_snapshots:
		if not ball_value is Dictionary:
			continue
		var ball_snapshot: Dictionary = ball_value
		var gameplay_active: bool = bool(ball_snapshot.get("gameplay_active", false))
		var unsupported_reason: String = str(ball_snapshot.get("initial_unsupported_reason", ""))
		var ball_label: String = str(ball_snapshot.get("label", "Ball ?"))
		if bool(ball_snapshot.get("is_cue_ball", false)):
			cue_found = true
			cue_active = gameplay_active
		if gameplay_active:
			active_ball_count += 1
			var motion_parameters: Dictionary = ball_snapshot.get("motion_parameters", {})
			var velocity: Vector2 = ball_snapshot.get("launch_velocity", ball_snapshot.get("velocity", Vector2.ZERO))
			if velocity.length() >= float(motion_parameters.get("stop_threshold", 4.0)):
				moving_ball_count += 1
		if unsupported_reason.begins_with("unsupported_spawn_"):
			transient_ball_count += 1
			transient_labels.append(ball_label)
		elif not unsupported_reason.is_empty():
			unsupported_ball_count += 1
			unsupported_labels.append("%s: %s" % [ball_label, unsupported_reason])

	availability["active_ball_count"] = active_ball_count
	availability["transient_ball_count"] = transient_ball_count
	availability["unsupported_ball_count"] = unsupported_ball_count
	availability["moving_ball_count"] = moving_ball_count
	var pending_spawn_count: int = (
		int(table.spawn_system.get_pending_spawn_count())
		if table.spawn_system != null
		else 0
	)
	var pending_landing_callbacks: bool = (
		bool(table.spawn_system.has_pending_landing_callbacks())
		if table.spawn_system != null
		else false
	)
	availability["pending_spawn_count"] = pending_spawn_count
	availability["pending_landing_callbacks"] = pending_landing_callbacks
	var boundary_geometry_value: Variant = input_snapshot.get("boundary_geometry", [])
	var pocket_geometry_value: Variant = input_snapshot.get("pocket_geometry", [])
	var has_boundary_geometry: bool = (
		boundary_geometry_value is Array and not (boundary_geometry_value as Array).is_empty()
	)
	var has_pocket_geometry: bool = (
		pocket_geometry_value is Array and not (pocket_geometry_value as Array).is_empty()
	)

	var blocker_reason := ""
	var blocker_details := ""
	if not bool(availability["cloned_simulation_enabled"]):
		blocker_reason = "disabled"
		blocker_details = "Cloned simulation is disabled."
	elif not cue_found:
		blocker_reason = "no_cue_ball"
		blocker_details = "No cue ball is present in the prediction snapshot."
	elif table.ball_placement_system != null and table.ball_placement_system.is_placement_active():
		blocker_reason = "placement_active"
		blocker_details = "Ball placement is active."
	elif transient_ball_count > 0 or pending_spawn_count > 0 or pending_landing_callbacks:
		blocker_reason = "transient_spawn_state"
		var transient_parts: Array[String] = []
		if transient_ball_count > 0:
			transient_parts.append("%s spawned ball%s settling (%s)" % [
				transient_ball_count,
				"" if transient_ball_count == 1 else "s",
				", ".join(transient_labels),
			])
		if pending_spawn_count > 0:
			transient_parts.append("%s queued drop%s" % [
				pending_spawn_count,
				"" if pending_spawn_count == 1 else "s",
			])
		if pending_landing_callbacks:
			transient_parts.append("landing callbacks pending")
		blocker_details = "Waiting for " + "; ".join(transient_parts) + "."
	elif unsupported_ball_count > 0:
		blocker_reason = "unsupported_ball_state"
		blocker_details = "; ".join(unsupported_labels)
	elif not has_boundary_geometry:
		blocker_reason = "invalid_boundary_geometry"
		blocker_details = "No cloned boundary geometry is available."
	elif not has_pocket_geometry:
		blocker_reason = "invalid_pocket_geometry"
		blocker_details = "No cloned pocket geometry is available."
	elif not cue_active:
		blocker_reason = "cue_not_ready"
		blocker_details = "The cue ball is not gameplay-active."
	elif moving_ball_count > (1 if live_preview_requested else 0):
		blocker_reason = "table_motion_active"
		blocker_details = "Waiting for table motion to settle."
	elif not live_preview_requested:
		blocker_reason = "cue_not_ready"
		blocker_details = "Begin a valid cue drag to request cloned prediction."
	elif launch_velocity.length_squared() <= 0.0:
		blocker_reason = "zero_launch_velocity"
		blocker_details = "The requested launch velocity is zero."

	availability["available"] = blocker_reason.is_empty()
	availability["blocker_reason"] = "none" if blocker_reason.is_empty() else blocker_reason
	availability["blocker_details"] = blocker_details
	availability["refresh_pending"] = _cloned_refresh_pending
	availability["last_successful_rebuild_revision"] = _last_successful_cloned_rebuild_revision
	return availability


func _make_unavailable_cloned_prediction_result(
	configuration: Dictionary,
	availability: Dictionary
) -> Dictionary:
	return {
		"valid": false,
		"complete": false,
		"truncated": false,
		"stop_reason": str(availability.get("blocker_reason", "unknown")),
		"cap_reached": "",
		"table_revision": int(availability.get("table_revision", -1)),
		"configuration": configuration.duplicate(true),
		"unsupported_warnings": [],
		"events": [],
		"balls": [],
		"prediction_availability": availability.duplicate(true),
	}


func _note_failed_cloned_rebuild_after_invalidation() -> void:
	if not _cloned_refresh_pending:
		return
	if _last_failed_invalidation_revision == _observed_table_prediction_revision:
		return
	_last_failed_invalidation_revision = _observed_table_prediction_revision
	_cloned_failed_rebuilds_after_invalidation += 1


func _duplicate_dictionary_field(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


func _get_cloned_draw_profile_workload(result: Dictionary) -> Dictionary:
	var configuration: Dictionary = result.get("configuration", {})
	var draw_cue_continuation: bool = bool(configuration.get("draw_cue_continuation", true))
	var draw_child_paths: bool = bool(configuration.get("draw_child_ball_paths", true))
	var visible_path_segments: int = 0
	var visible_paths: int = 0
	var predicted_balls_drawn: int = 0
	for ball_value in result.get("balls", []):
		if not ball_value is Dictionary:
			continue
		var ball_result: Dictionary = ball_value
		var is_cue: bool = bool(ball_result.get("is_cue_ball", false))
		if is_cue and not draw_cue_continuation:
			continue
		if not is_cue and not draw_child_paths:
			continue
		var points: Array[Vector2] = _to_vector2_points(ball_result.get("path_points", []))
		if points.size() >= 2:
			visible_paths += 1
			predicted_balls_drawn += 1
		visible_path_segments += maxi(points.size() - 1, 0)
	return {
		"visible_path_segments": visible_path_segments,
		"visible_paths": visible_paths,
		"predicted_balls_drawn": predicted_balls_drawn,
	}


func _should_build_cloned_event_comparison(configuration: Dictionary) -> bool:
	return (
		str(configuration.get(
			"result_detail_mode",
			AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
		)) == AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
		and bool(configuration.get("compare_predicted_event_chain", true))
	)


func _classify_cloned_rebuild(
	origin: Vector2,
	launch_velocity: Vector2,
	rebuild_reason: String
) -> String:
	if rebuild_reason == "forced_deep_prediction" or rebuild_reason.contains("forced"):
		return "forced"
	if rebuild_reason == "config_deep_prediction":
		return "forced_config"
	if rebuild_reason in [
		"settled_deep_prediction",
		"table_revision_deep_prediction",
		"cache_hit_deep_prediction",
	]:
		return "settled"
	if rebuild_reason.begins_with("immediate_preview_"):
		return "active_drag"
	if _cloned_configuration_changed_since_rebuild:
		return "forced_config"
	var input_changed: bool = (
		not _has_last_cloned_rebuild_input
		or not origin.is_equal_approx(_last_cloned_rebuild_origin)
		or not launch_velocity.is_equal_approx(_last_cloned_rebuild_velocity)
	)
	if table != null and bool(table.is_dragging) and input_changed:
		return "active_drag"
	return "settled"


func _make_cloned_benchmark_setup_snapshot(
	input_snapshot: Dictionary,
	configuration: Dictionary,
	launch_velocity: Vector2
) -> Dictionary:
	var ball_snapshots: Array = input_snapshot.get("balls", [])
	var initially_moving_balls: int = 0
	for ball_value in ball_snapshots:
		if not ball_value is Dictionary:
			continue
		var ball_snapshot: Dictionary = ball_value
		var velocity: Vector2 = ball_snapshot.get("launch_velocity", ball_snapshot.get("velocity", Vector2.ZERO))
		var motion_parameters: Dictionary = ball_snapshot.get("motion_parameters", {})
		if velocity.length() >= float(motion_parameters.get("stop_threshold", 4.0)):
			initially_moving_balls += 1
	var roguelite_round: int = 0
	if (
		table != null
		and table.is_roguelite_mode()
		and table.roguelite_run_system != null
	):
		roguelite_round = int(table.roguelite_run_system.get_snapshot().get("round_number", 0))
	var result_mode: String = str(configuration.get(
		"result_detail_mode",
		AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
	))
	var trace_spacing: float = (
		float(configuration.get("trace_point_spacing", 2.0))
		if result_mode == AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
		else float(configuration.get("player_trace_spacing", 10.0))
	)
	var cloned_ball_results: Array = current_cloned_prediction.get("balls", [])
	return {
		"mode_id": table.get_game_mode_id() if table != null else "unknown",
		"table_revision": int(input_snapshot.get("table_prediction_revision", -1)),
		"roguelite_round": roguelite_round,
		"active_balls": ball_snapshots.size(),
		"cloned_balls": cloned_ball_results.size(),
		"initially_moving_balls": initially_moving_balls,
		"cue_launch_speed": launch_velocity.length(),
		"result_detail_mode": result_mode,
		"max_child_generation_depth": int(configuration.get("max_child_generation_depth", 0)),
		"max_simulated_seconds": float(configuration.get("max_simulated_seconds", 0.0)),
		"simulation_frame_rate": int(configuration.get("simulation_frame_rate", 0)),
		"simulation_substeps": int(configuration.get("simulation_substeps", 0)),
		"trace_spacing": trace_spacing,
		"staged_prediction": staged_prediction_configuration.duplicate(true),
	}


func _get_prediction_anomaly_kind(ball: Ball) -> String:
	if ball.is_powder_keg:
		return "powder_keg"
	if ball.is_anchor_ball or ball.is_anchor_curse_seed:
		return "anchor"
	if ball.is_cannon_ball:
		return "cannon"
	if ball.is_treasure_ball:
		return "treasure"
	if ball.is_embezzler_ball:
		return "embezzler"
	if ball.is_wayfinder:
		return "wayfinder"
	return ""


func _get_initial_prediction_unsupported_reason(ball: Ball, transient_state: Dictionary) -> String:
	if bool(transient_state.get("spawn_drop_active", false)):
		return "unsupported_spawn_drop_motion"
	if bool(transient_state.get("spawn_landing_damping_active", false)):
		return "unsupported_spawn_landing_damping"
	if ball.is_anchor_curse_seed:
		return "unsupported_anchor_constraint"
	if ball.is_wayfinder and (
		ball.wayfinder_active
		or (table.wayfinder_system != null and table.wayfinder_system.is_ball_guided(ball))
	):
		return "unsupported_wayfinder_guidance"
	if (
		ball.is_treasure_ball
		and table.treasure_ball_system != null
		and table.treasure_ball_system.is_prediction_self_motion_active(ball)
	):
		return "unsupported_treasure_self_motion"
	if (
		ball.is_embezzler_ball
		and table.embezzler_system != null
		and table.embezzler_system.is_prediction_self_motion_active(ball)
	):
		return "unsupported_embezzler_behavior"
	return ""


func _is_cloned_long_sight_active() -> bool:
	return (
		_get_active_aim_chain_depth() > 0
		and bool(cloned_trajectory_configuration.get("enabled", true))
		and bool(cloned_trajectory_configuration.get("use_for_long_sight", true))
		and bool(current_cloned_prediction.get("valid", false))
	)


func is_debug_aim_line_enabled() -> bool:
	return debug_aim_line_enabled


func is_prediction_enabled() -> bool:
	return AIM_PREDICTION_ENABLED


func get_prediction_time_ms() -> float:
	return prediction_ms


func _make_debug_shot_overlay(
	prediction: AimPrediction,
	launch_position: Vector2,
	launch_velocity: Vector2,
	deep_result: Dictionary = {},
	deep_commit_status: String = "deep_prediction_not_ready",
	deep_request_snapshot: Dictionary = {}
) -> DebugAimShotOverlay:
	var overlay: DebugAimShotOverlay = DebugAimShotOverlay.new()
	overlay.predicted_launch_position = launch_position
	overlay.predicted_launch_velocity = launch_velocity
	overlay.cue_radius = _get_debug_cue_ball_radius()
	overlay.physics_collision_skin = _get_physics_ball_collision_skin()
	overlay.first_hit_candidate_log = _copy_debug_first_hit_candidate_log()
	overlay.first_hit_selected_ball_id = _debug_first_hit_selected_ball_id
	overlay.first_hit_selected_ball_number = _debug_first_hit_selected_ball_number
	overlay.cloned_prediction_result = deep_result.duplicate(true)
	overlay.deep_prediction_commit_status = deep_commit_status
	overlay.deep_request_snapshot = deep_request_snapshot.duplicate(true)
	if prediction == null:
		return overlay

	overlay.predicted_cue_path = _copy_vector2_points(prediction.path_points)
	overlay.has_predicted_cue_contact = prediction.collision_type == "ball"
	if overlay.has_predicted_cue_contact:
		overlay.predicted_cue_contact_position = prediction.position
		overlay.predicted_target_contact_position = prediction.target_center_at_impact
		overlay.predicted_distance_to_first_hit = _get_polyline_distance_to_point(prediction.path_points, prediction.position)
		overlay.predicted_center_distance = prediction.position.distance_to(prediction.target_center_at_impact)
		overlay.prediction_effective_collision_radius = prediction.effective_collision_radius
		overlay.prediction_collision_skin = prediction.collision_skin
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
	if not _full_debug_result_evidence_enabled():
		return copied_entries
	for entry_value in _debug_first_hit_candidate_log:
		var entry: Dictionary = entry_value
		copied_entries.append(entry.duplicate(true))
	return copied_entries


func _reset_debug_first_hit_candidate_log() -> void:
	_debug_first_hit_candidate_log.clear()
	_debug_first_hit_selected_ball_id = -1
	_debug_first_hit_selected_ball_number = -1


func _finalize_debug_first_hit_candidate_selection(prediction: AimPrediction) -> void:
	if not debug_aim_line_enabled or not _full_debug_result_evidence_enabled():
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

	if is_instance_valid(table.cue_ball) and table.cue_ball.is_gameplay_active():
		_append_debug_actual_path_point(table.cue_ball.global_position)
	_record_debug_all_ball_paths()
	_queue_aim_redraw()


func _append_debug_actual_path_point(position: Vector2, force_append: bool = false) -> void:
	if debug_persisted_shot == null:
		return
	if debug_persisted_shot.actual_cue_path.size() >= _get_debug_actual_points_per_ball_limit():
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
	if points.size() >= _get_debug_actual_points_per_ball_limit():
		return
	if _get_debug_total_trace_points() >= _get_debug_actual_total_points_limit():
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


func _get_debug_actual_points_per_ball_limit() -> int:
	return maxi(
		int(cloned_trajectory_configuration.get("max_points_per_ball", DEBUG_AIM_TRACE_MAX_POINTS_PER_BALL)),
		DEBUG_AIM_TRACE_MAX_POINTS_PER_BALL
	)


func _get_debug_actual_total_points_limit() -> int:
	return maxi(
		int(cloned_trajectory_configuration.get("max_total_trace_points", DEBUG_AIM_TRACE_MAX_TOTAL_POINTS)),
		DEBUG_AIM_TRACE_MAX_TOTAL_POINTS
	)


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
	var contact_order_snapshot: Dictionary = _get_debug_contact_order_snapshot(overlay, contact_snapshot)
	return {
		"source": active_source,
		"deep_prediction_commit_status": (
			overlay.deep_prediction_commit_status
			if overlay != null
			else "deep_prediction_not_ready"
		),
		"debug_aim_line_enabled": debug_aim_line_enabled,
		"persisted_overlay": debug_persisted_shot != null,
		"recording_actual_trace": debug_actual_trace_recording,
		"launch": launch_snapshot,
		"contact": contact_snapshot,
		"response": response_snapshot,
		"trace": trace_summary,
		"contact_order": contact_order_snapshot,
		"verdict": _get_debug_mismatch_verdict(launch_snapshot, contact_snapshot, response_snapshot),
	}


func _get_active_cloned_prediction_result() -> Dictionary:
	if debug_aim_line_enabled and preview_active and not current_cloned_prediction.is_empty():
		return current_cloned_prediction
	if debug_persisted_shot != null:
		return debug_persisted_shot.cloned_prediction_result
	return current_cloned_prediction


func _get_cloned_event_comparison_snapshot() -> Dictionary:
	if (
		(not preview_active or current_cloned_prediction.is_empty())
		and debug_persisted_shot != null
		and debug_persisted_shot.deep_prediction_commit_status != "deep_prediction_ready"
	):
		return {
			"enabled": false,
			"matched_event_count": 0,
			"predicted_event_count": 0,
			"actual_event_count": debug_persisted_shot.actual_events.size(),
			"first_divergent_event_index": -1,
			"divergence_reason": debug_persisted_shot.deep_prediction_commit_status,
			"entries": [],
			"predicted_events": [],
			"actual_events": debug_persisted_shot.actual_events.duplicate(true),
		}
	var prediction_result: Dictionary = _get_active_cloned_prediction_result()
	var predicted_events: Array = prediction_result.get("events", [])
	var actual_events: Array = []
	if not preview_active and debug_persisted_shot != null:
		actual_events = debug_persisted_shot.actual_events
	var result_configuration: Dictionary = prediction_result.get(
		"configuration",
		cloned_trajectory_configuration
	)
	var comparison_enabled: bool = _should_build_cloned_event_comparison(result_configuration)
	if not comparison_enabled:
		return {
			"enabled": false,
			"matched_event_count": 0,
			"predicted_event_count": predicted_events.size(),
			"actual_event_count": actual_events.size(),
			"first_divergent_event_index": -1,
			"divergence_reason": "comparison_disabled",
			"entries": [],
			"predicted_events": [],
			"actual_events": [],
		}
	var entries: Array[Dictionary] = []
	var shared_count: int = mini(predicted_events.size(), actual_events.size())
	var matched_count: int = 0
	var first_divergent_index: int = -1
	var first_divergence_reason: String = ""
	for event_index in range(shared_count):
		var predicted: Dictionary = predicted_events[event_index] as Dictionary
		var actual: Dictionary = actual_events[event_index] as Dictionary
		var comparison: Dictionary = _compare_cloned_event_pair(predicted, actual, event_index)
		entries.append(comparison)
		if bool(comparison.get("matches", false)) and first_divergent_index < 0:
			matched_count += 1
		elif first_divergent_index < 0:
			first_divergent_index = event_index
			first_divergence_reason = str(comparison.get("result", "event_mismatch"))

	var actual_chain_complete: bool = (
		not preview_active
		and debug_persisted_shot != null
		and not debug_actual_trace_recording
	)
	if first_divergent_index < 0 and actual_chain_complete and predicted_events.size() != actual_events.size():
		first_divergent_index = shared_count
		if predicted_events.size() < actual_events.size():
			first_divergence_reason = "prediction_stopped_before_actual"
		else:
			first_divergence_reason = "actual_stopped_before_prediction"
	return {
		"enabled": true,
		"matched_event_count": matched_count,
		"predicted_event_count": predicted_events.size(),
		"actual_event_count": actual_events.size(),
		"first_divergent_event_index": first_divergent_index,
		"divergence_reason": first_divergence_reason,
		"actual_chain_complete": actual_chain_complete,
		"prediction_stop_reason": str(prediction_result.get("stop_reason", "none")),
		"entries": entries,
		"predicted_events": predicted_events.duplicate(true),
		"actual_events": actual_events.duplicate(true),
	}


func _compare_cloned_event_pair(predicted: Dictionary, actual: Dictionary, event_index: int) -> Dictionary:
	var predicted_type: String = str(predicted.get("event_type", "unknown"))
	var actual_type: String = str(actual.get("event_type", "unknown"))
	var source_matches: bool = int(predicted.get("source_ball_id", -1)) == int(actual.get("source_ball_id", -1))
	var target_matches: bool = int(predicted.get("target_ball_id", -1)) == int(actual.get("target_ball_id", -1))
	var type_matches: bool = predicted_type == actual_type
	var result: String = "match"
	if not type_matches:
		result = "event_type_mismatch"
	elif not source_matches:
		result = "source_ball_mismatch"
	elif not target_matches:
		result = "target_ball_mismatch"
	elif predicted_type == AimTrajectoryPredictor.EVENT_POCKET and int(predicted.get("pocket_index", -1)) != int(actual.get("pocket_index", -1)):
		result = "pocket_mismatch"
	var predicted_normal: Vector2 = predicted.get("collision_normal", Vector2.ZERO)
	var actual_normal: Vector2 = actual.get("collision_normal", Vector2.ZERO)
	var predicted_outgoing: Vector2 = predicted.get("outgoing_source_velocity", Vector2.ZERO)
	var actual_outgoing: Vector2 = actual.get("outgoing_source_velocity", Vector2.ZERO)
	var predicted_contact: Vector2 = predicted.get("contact_point", Vector2.ZERO)
	var actual_contact: Vector2 = actual.get("contact_point", Vector2.ZERO)
	return {
		"event_index": event_index,
		"matches": result == "match",
		"result": result,
		"predicted_type": predicted_type,
		"actual_type": actual_type,
		"predicted_source_label": str(predicted.get("source_ball_label", "Ball ?")),
		"actual_source_label": str(actual.get("source_ball_label", "Ball ?")),
		"predicted_target_label": str(predicted.get("target_ball_label", "")),
		"actual_target_label": str(actual.get("target_ball_label", "")),
		"source_matches": source_matches,
		"target_matches": target_matches,
		"contact_position_delta": predicted_contact.distance_to(actual_contact),
		"normal_angle_delta": _get_unsigned_angle_delta_degrees(predicted_normal, actual_normal),
		"outgoing_angle_delta": _get_unsigned_angle_delta_degrees(predicted_outgoing, actual_outgoing),
		"timing_delta": float(actual.get("actual_time", 0.0)) - float(predicted.get("simulated_time", 0.0)),
	}


func _get_active_debug_compare_overlay() -> DebugAimShotOverlay:
	if debug_aim_line_enabled and preview_active and current_prediction != null:
		var commit_status: String = _get_deep_prediction_commit_status(
			preview_origin,
			preview_initial_velocity
		)
		return _make_debug_shot_overlay(
			current_prediction,
			preview_origin,
			preview_initial_velocity,
			current_cloned_prediction if commit_status == "deep_prediction_ready" else {},
			commit_status,
			_accepted_deep_request_snapshot if commit_status == "deep_prediction_ready" else {}
		)
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
	var predicted_target_center: Vector2 = overlay.predicted_target_contact_position if overlay != null else Vector2.ZERO
	var actual_target_center: Vector2 = overlay.actual_first_object_center if overlay != null else Vector2.ZERO
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
		"predicted_target_center": predicted_target_center,
		"actual_target_center": actual_target_center,
		"target_center_delta": predicted_target_center.distance_to(actual_target_center) if overlay != null and overlay.has_predicted_cue_contact and overlay.has_actual_first_contact else -1.0,
		"predicted_center_distance": overlay.predicted_center_distance if overlay != null else -1.0,
		"actual_center_distance": overlay.actual_center_distance if overlay != null else -1.0,
		"prediction_effective_collision_radius": overlay.prediction_effective_collision_radius if overlay != null else -1.0,
		"physics_effective_collision_radius": _get_debug_physics_effective_collision_radius(overlay),
		"prediction_collision_skin": overlay.prediction_collision_skin if overlay != null else 0.0,
		"physics_collision_skin": overlay.physics_collision_skin if overlay != null else 0.0,
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
	var predicted_center_distance: float = overlay.predicted_center_distance if overlay != null else -1.0
	var prediction_effective_radius: float = overlay.prediction_effective_collision_radius if overlay != null else -1.0
	var physics_effective_radius: float = _get_debug_physics_effective_collision_radius(overlay)
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
		# Kept for existing debug consumers; this is now the skin-inclusive radius.
		"expected_center_distance": prediction_effective_radius,
		"predicted_center_distance": predicted_center_distance,
		"actual_center_distance": actual_center_distance,
		"center_distance_delta": actual_center_distance - predicted_center_distance if actual_center_distance >= 0.0 and predicted_center_distance >= 0.0 else 0.0,
		"prediction_effective_collision_radius": prediction_effective_radius,
		"physics_effective_collision_radius": physics_effective_radius,
		"effective_radius_delta": physics_effective_radius - prediction_effective_radius if physics_effective_radius >= 0.0 and prediction_effective_radius >= 0.0 else 0.0,
		"prediction_collision_skin": overlay.prediction_collision_skin if overlay != null else 0.0,
		"physics_collision_skin": overlay.physics_collision_skin if overlay != null else 0.0,
		"prediction_geometry_gap": predicted_center_distance - prediction_effective_radius if predicted_center_distance >= 0.0 and prediction_effective_radius >= 0.0 else 0.0,
		"overlap_gap": actual_center_distance - physics_effective_radius if actual_center_distance >= 0.0 and physics_effective_radius >= 0.0 else 0.0,
		"cue_radius": overlay.cue_radius if overlay != null else 0.0,
		"target_radius": overlay.target_radius if overlay != null else 0.0,
	}


func _get_debug_physics_effective_collision_radius(overlay: DebugAimShotOverlay) -> float:
	if overlay == null:
		return -1.0
	return BALL_SWEEP_MATH.get_effective_collision_radius(
		overlay.cue_radius,
		overlay.target_radius,
		overlay.physics_collision_skin
	)


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


func _get_debug_contact_order_snapshot(overlay: DebugAimShotOverlay, contact_snapshot: Dictionary) -> Dictionary:
	if overlay == null or overlay.contact_order_snapshot.is_empty():
		return {
			"captured": false,
			"verdict": "Insufficient data",
		}
	var result: Dictionary = overlay.contact_order_snapshot.duplicate(true)
	result["preview_first_ball_id"] = int(contact_snapshot.get("predicted_hit_ball_id", -1))
	result["preview_first_ball_number"] = int(contact_snapshot.get("predicted_hit_ball_number", -1))
	result["reported_actual_ball_id"] = int(contact_snapshot.get("actual_hit_ball_id", -1))
	result["reported_actual_ball_number"] = int(contact_snapshot.get("actual_hit_ball_number", -1))
	result["verdict"] = _get_debug_contact_order_verdict(result)
	return result


func _get_debug_contact_order_verdict(contact_order: Dictionary) -> String:
	if not bool(contact_order.get("captured", false)):
		return "Insufficient data"
	var preview_id: int = int(contact_order.get("preview_first_ball_id", -1))
	var swept_id: int = int(contact_order.get("swept_earliest_ball_id", -1))
	var resolver_id: int = int(contact_order.get("resolver_first_ball_id", -1))
	var actual_id: int = int(contact_order.get("reported_actual_ball_id", -1))
	if swept_id < 0:
		return "No swept hit recorded"
	if resolver_id >= 0 and resolver_id != swept_id:
		return "Resolver order differs from TOI"
	if preview_id >= 0 and preview_id != swept_id:
		return "Preview selected wrong geometric candidate"
	if actual_id >= 0 and resolver_id >= 0 and actual_id != resolver_id:
		return "Reported contact differs from resolver"
	if bool(contact_order.get("near_simultaneous", false)):
		return "Near-simultaneous multi-contact"
	if preview_id == swept_id and resolver_id == swept_id:
		return "Preview, TOI, and resolver agree"
	if resolver_id == swept_id:
		return "Resolver and TOI agree"
	if preview_id == swept_id:
		return "Preview and TOI agree"
	return "Insufficient data"


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
	if absf(float(response_snapshot.get("effective_radius_delta", 0.0))) > 0.01:
		return "prediction/physics radius mismatch"
	if absf(float(response_snapshot.get("prediction_geometry_gap", 0.0))) > 0.05:
		return "prediction contact geometry mismatch"
	if absf(float(response_snapshot.get("center_distance_delta", 0.0))) > 0.25:
		return "predicted/actual contact distance mismatch"
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


func _get_cloned_profiler_snapshot() -> Dictionary:
	if trajectory_profiler == null:
		return {
			"benchmark": get_cloned_trajectory_benchmark_snapshot(),
			"invalidation": _get_cloned_invalidation_snapshot(),
		}
	var cache_snapshot: Dictionary = (
		trajectory_predictor.get_cache_debug_snapshot()
		if trajectory_predictor != null
		else {}
	)
	var profiler_snapshot: Dictionary = trajectory_profiler.get_snapshot(cache_snapshot)
	profiler_snapshot["aim_preview_draw_cpu_us"] = maxi(int(round(draw_ms_last_draw * 1000.0)), 0)
	profiler_snapshot["staging_state"] = _get_staged_prediction_snapshot()
	profiler_snapshot["benchmark"] = get_cloned_trajectory_benchmark_snapshot()
	profiler_snapshot["invalidation"] = _get_cloned_invalidation_snapshot()
	return profiler_snapshot


func _get_staged_prediction_snapshot() -> Dictionary:
	var now_usec: int = Time.get_ticks_usec()
	var settle_delay_ms: int = _get_deep_settle_delay_ms()
	var settle_remaining_ms: float = 0.0
	if staged_prediction_state == STAGED_STATE_WAITING_FOR_SETTLE:
		settle_remaining_ms = maxf(
			float(settle_delay_ms) - float(now_usec - _last_meaningful_input_usec) / 1000.0,
			0.0
		)
	return {
		"enabled": _is_staged_deep_prediction_enabled(),
		"show_status": bool(staged_prediction_configuration.get(
			AIM_STAGING_CONFIGURATION_SCRIPT.SHOW_STAGING_STATUS,
			true
		)),
		"state": staged_prediction_state,
		"reason": staged_prediction_reason,
		"settle_delay_ms": settle_delay_ms,
		"direction_tolerance_degrees": STAGED_DIRECTION_TOLERANCE_DEGREES,
		"power_relative_tolerance": STAGED_POWER_RELATIVE_TOLERANCE,
		"origin_tolerance_px": STAGED_ORIGIN_TOLERANCE_PX,
		"settle_remaining_ms": settle_remaining_ms,
		"reveal_duration_ms": int(staged_prediction_configuration.get(
			AIM_STAGING_CONFIGURATION_SCRIPT.DEEP_AIM_REVEAL_DURATION_MS,
			125
		)),
		"progressive_reveal": bool(staged_prediction_configuration.get(
			AIM_STAGING_CONFIGURATION_SCRIPT.PROGRESSIVE_DEEP_AIM_REVEAL,
			true
		)),
		"reveal_progress": _deep_reveal_progress,
		"visible_depth": int(round(_deep_reveal_progress * float(_deep_reveal_max_depth))),
		"maximum_depth": _deep_reveal_max_depth,
		"visible_branches": _deep_reveal_visible_branches,
		"reveal_preparation_us": _deep_reveal_preparation_us,
		"current_request_id": _current_deep_request_id,
		"last_accepted_request_id": _last_accepted_deep_request_id,
		"last_stale_request_id": _last_stale_deep_request_id,
		"pending_request_count": (
			1
			if (
				_profiled_pending_deep_request
				or staged_prediction_state in [
					STAGED_STATE_DEEP_REQUESTED,
					STAGED_STATE_DEEP_RUNNING,
				]
			)
			else 0
		),
		"deep_requests_created": _deep_requests_created,
		"deep_requests_forced": _deep_force_requests,
		"deep_requests_canceled_before_run": _deep_requests_canceled_before_run,
		"deep_requests_invalidated_before_run": _deep_requests_invalidated_before_run,
		"deep_requests_blocked_before_run": _deep_requests_blocked_before_run,
		"deep_results_completed": _deep_requests_completed,
		"deep_results_accepted": _deep_requests_accepted,
		"deep_results_discarded_on_arrival": _deep_results_discarded_on_arrival,
		"deep_results_rejected_revision_mismatch": _deep_results_rejected_revision_mismatch,
		"deep_results_rejected_request_id_mismatch": _deep_results_rejected_request_id_mismatch,
		"accepted_results_shown": _accepted_results_shown,
		"shown_results_later_invalidated": _shown_results_later_invalidated,
		"shown_results_hidden_by_new_aim": _shown_results_hidden_by_new_aim,
		"shown_results_reused_from_cache": _shown_results_reused_from_cache,
		"reveal_completed_count": _reveal_completed_count,
		"reveal_interrupted_count": _reveal_interrupted_count,
		"reveal_completed_before_next_aim_count": _reveal_completed_before_next_aim_count,
		"force_requests": _deep_force_requests,
		"immediate_updates": _immediate_updates,
		"active_drag_deep_rebuilds": _active_drag_deep_rebuilds,
		"settled_deep_rebuilds": _settled_deep_rebuilds,
		"average_compute_start_latency_ms": (
			float(_deep_compute_start_latency_total_usec)
			/ float(_deep_compute_start_latency_samples)
			/ 1000.0
			if _deep_compute_start_latency_samples > 0
			else 0.0
		),
		"average_deep_computation_ms": (
			float(_deep_compute_total_usec) / float(_deep_compute_samples) / 1000.0
			if _deep_compute_samples > 0
			else 0.0
		),
		"average_first_visible_latency_ms": (
			float(_deep_first_visible_latency_total_usec)
			/ float(_deep_first_visible_latency_samples)
			/ 1000.0
			if _deep_first_visible_latency_samples > 0
			else 0.0
		),
		"deep_cache_hits": _deep_cache_hits,
		"deep_cache_misses": _deep_cache_misses,
		"cached_results_accepted": _cached_results_accepted,
		"cached_results_rejected": _cached_results_rejected,
		"reused_results": _deep_reused_results,
		"accepted_result_cache_hit": _accepted_deep_cache_hit,
		"ready_but_hidden_count": _deep_ready_but_hidden_count,
		"stale_result_available": not _stale_cloned_prediction.is_empty(),
		"request_snapshot": _current_deep_request_snapshot.duplicate(true),
		"accepted_request_snapshot": _accepted_deep_request_snapshot.duplicate(true),
	}


func _get_cloned_invalidation_snapshot() -> Dictionary:
	var table_revision_snapshot: Dictionary = (
		table.get_aim_prediction_revision_snapshot()
		if table != null
		else {}
	)
	return {
		"table_revision": int(table_revision_snapshot.get(
			"table_revision",
			_observed_table_prediction_revision
		)),
		"prediction_revision_changes": int(table_revision_snapshot.get(
			"prediction_revision_changes",
			0
		)),
		"cache_invalidations": _cloned_invalidation_count,
		"invalidation_reasons": _cloned_invalidation_reason_counts.duplicate(true),
		"last_invalidation_reason": _last_cloned_invalidation_reason,
		"roster_change_invalidations": _cloned_roster_change_invalidations,
		"spawn_complete_invalidations": _cloned_spawn_complete_invalidations,
		"remove_sink_invalidations": _cloned_remove_sink_invalidations,
		"transform_invalidations": _cloned_transform_invalidations,
		"unsupported_state_invalidations": _cloned_unsupported_state_invalidations,
		"successful_rebuilds_after_invalidation": _cloned_successful_rebuilds_after_invalidation,
		"failed_rebuilds_after_invalidation": _cloned_failed_rebuilds_after_invalidation,
	}


func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"debug_aim_line_enabled": debug_aim_line_enabled,
		"debug_aim_actual_trace_recording": debug_actual_trace_recording,
		"debug_aim_persisted_overlay": debug_persisted_shot != null,
		"debug_aim_actual_points": debug_persisted_shot.actual_cue_path.size() if debug_persisted_shot != null else 0,
		"debug_aim_has_actual_first_contact": debug_persisted_shot.has_actual_first_contact if debug_persisted_shot != null else false,
		"aim_compare": _get_debug_aim_compare_snapshot(),
		"cloned_simulation": _get_active_cloned_prediction_result().duplicate(true),
		"cloned_prediction_availability": cloned_prediction_availability.duplicate(true),
		"cloned_invalidation": _get_cloned_invalidation_snapshot(),
		"cloned_event_comparison": _get_cloned_event_comparison_snapshot(),
		"cloned_profiler": _get_cloned_profiler_snapshot(),
		"staged_prediction": _get_staged_prediction_snapshot(),
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
	_draw_predicted_balls_in_progress = 0
	_draw_visible_paths_in_progress = 0
	_draw_ghost_balls_in_progress = 0
	_draw_labels_in_progress = 0
	_draw_event_markers_in_progress = 0
	_deep_reveal_visible_branches = 0
	_deep_draw_cpu_us_in_progress = 0
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
	if _is_cloned_long_sight_active():
		var deep_draw_start_usec: int = Time.get_ticks_usec()
		_draw_cloned_long_sight_paths()
		_deep_draw_cpu_us_in_progress += maxi(
			Time.get_ticks_usec() - deep_draw_start_usec,
			0
		)
	else:
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
		_draw_cloned_unavailable_message()
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
	if not _stale_cloned_prediction.is_empty() and bool(staged_prediction_configuration.get(
		AIM_STAGING_CONFIGURATION_SCRIPT.KEEP_STALE_DEEP_AIM_FAINTLY_VISIBLE,
		false
	)):
		var stale_draw_start_usec: int = Time.get_ticks_usec()
		_draw_cloned_debug_prediction(_stale_cloned_prediction, STAGED_STALE_ALPHA, -1.0, false)
		_draw_cloned_text(
			preview_origin + Vector2(20.0, -24.0),
			"STALE DEEP",
			Color(0.72, 0.76, 0.82, 0.45)
		)
		_deep_draw_cpu_us_in_progress += maxi(
			Time.get_ticks_usec() - stale_draw_start_usec,
			0
		)
	if bool(current_cloned_prediction.get("valid", false)):
		var deep_draw_start_usec: int = Time.get_ticks_usec()
		_draw_cloned_debug_prediction(
			current_cloned_prediction,
			1.0,
			_deep_reveal_progress,
			true
		)
		_deep_draw_cpu_us_in_progress += maxi(
			Time.get_ticks_usec() - deep_draw_start_usec,
			0
		)
	else:
		_draw_cloned_unavailable_message()


func _draw_cloned_unavailable_message() -> void:
	if bool(cloned_prediction_availability.get("available", false)):
		return
	var reason: String = str(cloned_prediction_availability.get("blocker_reason", "unknown"))
	if reason == "disabled" or reason == "cue_not_ready":
		return
	var details: String = str(cloned_prediction_availability.get("blocker_details", ""))
	if details.length() > 58:
		details = details.left(55) + "..."
	var panel_position: Vector2 = preview_origin + Vector2(24.0, 28.0)
	var panel_size := Vector2(356.0, 46.0)
	draw_rect(Rect2(panel_position, panel_size), Color(0.02, 0.025, 0.035, 0.88), true)
	draw_rect(Rect2(panel_position, panel_size), Color(0.78, 0.62, 0.28, 0.78), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		panel_position + Vector2(8.0, 17.0),
		"Cloned prediction unavailable: %s" % reason.replace("_", " "),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		11,
		Color(0.96, 0.84, 0.52)
	)
	draw_string(
		ThemeDB.fallback_font,
		panel_position + Vector2(8.0, 35.0),
		details,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		10,
		Color(0.86, 0.88, 0.91)
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
	if bool(debug_persisted_shot.cloned_prediction_result.get("valid", false)):
		_draw_cloned_debug_prediction(debug_persisted_shot.cloned_prediction_result)
	else:
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


func _draw_cloned_debug_prediction(
	result: Dictionary,
	base_alpha: float = 1.0,
	reveal_progress: float = -1.0,
	draw_events: bool = true
) -> void:
	var configuration: Dictionary = result.get("configuration", {})
	var draw_cue_continuation: bool = bool(configuration.get("draw_cue_continuation", true))
	var draw_child_paths: bool = bool(configuration.get("draw_child_ball_paths", true))
	_deep_reveal_visible_branches = 0
	for ball_value in result.get("balls", []):
		if not ball_value is Dictionary:
			continue
		var ball_result: Dictionary = ball_value
		var is_cue: bool = bool(ball_result.get("is_cue_ball", false))
		if not is_cue and not draw_child_paths:
			continue
		if is_cue and not draw_cue_continuation:
			continue
		var points: Array[Vector2] = _to_vector2_points(ball_result.get("path_points", []))
		if points.size() < 2:
			continue
		var path_alpha: float = base_alpha
		if reveal_progress >= 0.0:
			path_alpha *= _get_deep_reveal_alpha(
				int(ball_result.get("generation_depth", 0)),
				is_cue
			)
		if path_alpha <= 0.001:
			continue
		_draw_predicted_balls_in_progress += 1
		_draw_visible_paths_in_progress += 1
		_deep_reveal_visible_branches += 1
		var color: Color = DEBUG_AIM_LINE_COLOR if is_cue else _get_cloned_ball_color(
			int(ball_result.get("source_ball_id", -1))
		)
		color.a *= path_alpha
		_draw_debug_polyline(points, color, DEBUG_AIM_LINE_WIDTH)
		if bool(configuration.get("draw_ball_labels", true)) and path_alpha >= 0.35:
			_draw_cloned_text(points[points.size() - 1] + Vector2(6.0, -5.0), str(ball_result.get("source_ball_label", "Ball")), color)

	if draw_events:
		var events: Array = result.get("events", [])
		var visible_event_count: int = events.size()
		if reveal_progress >= 0.0:
			visible_event_count = clampi(
				int(ceil(float(events.size()) * reveal_progress)),
				0,
				events.size()
			)
		for event_index in range(visible_event_count):
			var event_value: Variant = events[event_index]
			if not event_value is Dictionary:
				continue
			var event: Dictionary = event_value
			_draw_cloned_debug_event(event, configuration, base_alpha)

	if (
		bool(result.get("truncated", false))
		and (reveal_progress < 0.0 or reveal_progress >= 1.0)
		and str(configuration.get("result_detail_mode", "full_debug"))
		== AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
	):
		_draw_cloned_cap_marker(result)


func _draw_cloned_debug_event(
	event: Dictionary,
	configuration: Dictionary,
	alpha_multiplier: float = 1.0
) -> void:
	var drew_event_marker := false
	var event_type: String = str(event.get("event_type", ""))
	var position: Vector2 = event.get("contact_point", Vector2.ZERO)
	var supported: bool = bool(event.get("supported", true))
	var marker_color: Color = Color(1.0, 0.22, 0.68, 0.98) if not supported else DEBUG_AIM_MARKER_COLOR
	marker_color.a *= alpha_multiplier
	if bool(configuration.get("draw_ghost_balls", true)) and event_type == AimTrajectoryPredictor.EVENT_BALL_CONTACT:
		drew_event_marker = true
		_draw_debug_ghost_ball(
			event.get("source_center", position),
			float(event.get("source_radius", _get_debug_cue_ball_radius())),
			_get_cloned_ball_color(int(event.get("source_ball_id", -1))) * Color(1.0, 1.0, 1.0, alpha_multiplier)
		)
		_draw_debug_ghost_ball(
			event.get("target_center", position),
			float(event.get("target_radius", _get_debug_cue_ball_radius())),
			_get_cloned_ball_color(int(event.get("target_ball_id", -1))) * Color(1.0, 1.0, 1.0, alpha_multiplier)
		)
	elif bool(configuration.get("draw_ghost_balls", true)):
		drew_event_marker = true
		_draw_debug_ghost_ball(
			event.get("source_center", position),
			float(event.get("source_radius", _get_debug_cue_ball_radius())),
			_get_cloned_ball_color(int(event.get("source_ball_id", -1))) * Color(1.0, 1.0, 1.0, alpha_multiplier)
		)
	if bool(configuration.get("draw_stop_pocket_markers", true)):
		if event_type == AimTrajectoryPredictor.EVENT_POCKET:
			drew_event_marker = true
			_draw_calls_in_progress += 1
			draw_circle(position, 5.0, Color(0.36, 1.0, 0.76, 0.82 * alpha_multiplier), false, 1.5)
		elif event_type == AimTrajectoryPredictor.EVENT_STOPPED:
			drew_event_marker = true
			_draw_calls_in_progress += 2
			draw_line(position - Vector2(4.0, 4.0), position + Vector2(4.0, 4.0), marker_color, 1.0)
			draw_line(position + Vector2(-4.0, 4.0), position + Vector2(4.0, -4.0), marker_color, 1.0)
	if bool(configuration.get("draw_event_numbers", true)):
		drew_event_marker = true
		var prefix: String = "C" if int(event.get("source_ball_id", -1)) == table.cue_ball.get_instance_id() else "E"
		_draw_cloned_text(position + Vector2(5.0, -7.0), "%s%s" % [prefix, int(event.get("event_index", 0)) + 1], marker_color)
	if (
		not supported
		and str(configuration.get("result_detail_mode", "full_debug"))
		== AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
	):
		drew_event_marker = true
		_draw_cloned_text(position + Vector2(5.0, 10.0), str(event.get("unsupported_reason", "unsupported")), marker_color)
	if drew_event_marker:
		_draw_event_markers_in_progress += 1


func _draw_cloned_cap_marker(result: Dictionary) -> void:
	var cue_result: Dictionary = _get_cloned_cue_result(result)
	if cue_result.is_empty():
		return
	var position: Vector2 = cue_result.get("ending_position", Vector2.ZERO)
	var color: Color = Color(1.0, 0.18, 0.66, 0.95)
	_draw_calls_in_progress += 2
	draw_line(position - Vector2(6.0, 6.0), position + Vector2(6.0, 6.0), color, 1.5)
	draw_line(position + Vector2(-6.0, 6.0), position + Vector2(6.0, -6.0), color, 1.5)
	_draw_cloned_text(position + Vector2(8.0, 12.0), str(result.get("stop_reason", "cap")), color)


func _draw_cloned_text(position: Vector2, text: String, color: Color) -> void:
	_draw_calls_in_progress += 1
	_draw_labels_in_progress += 1
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, color)


func _to_vector2_points(points_value: Variant) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if not points_value is Array:
		return points
	for point_value in points_value:
		if point_value is Vector2:
			points.append(point_value)
	return points


func _get_cloned_ball_color(source_id: int) -> Color:
	if table != null and table.cue_ball != null and source_id == table.cue_ball.get_instance_id():
		return DEBUG_AIM_LINE_COLOR
	var color_index: int = posmod(source_id, DEBUG_CLONED_PATH_COLORS.size())
	return DEBUG_CLONED_PATH_COLORS[color_index]


func _get_cloned_cue_result(result: Dictionary) -> Dictionary:
	for ball_value in result.get("balls", []):
		if ball_value is Dictionary and bool(ball_value.get("is_cue_ball", false)):
			return ball_value
	return {}


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
	_draw_ghost_balls_in_progress += 1
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


func _draw_cloned_long_sight_paths() -> void:
	# Generation depth is causal: the first struck ball is depth 1, a ball it
	# strikes is depth 2, and so on. Cue continuation is revealed after C1.
	var visible_depth: int = _get_active_aim_chain_depth()
	if visible_depth <= 0:
		return
	var cue_id: int = table.cue_ball.get_instance_id()
	var first_cue_contact: Vector2 = _get_first_cloned_cue_contact(current_cloned_prediction)
	for ball_value in current_cloned_prediction.get("balls", []):
		if not ball_value is Dictionary:
			continue
		var ball_result: Dictionary = ball_value
		if int(ball_result.get("causal_root_ball_id", -1)) != cue_id:
			continue
		var generation_depth: int = int(ball_result.get("generation_depth", 0))
		if generation_depth > visible_depth:
			continue
		var points: Array[Vector2] = _to_vector2_points(ball_result.get("path_points", []))
		if bool(ball_result.get("is_cue_ball", false)):
			points = _slice_cloned_path_from_contact(points, first_cue_contact)
		if points.size() < 2:
			continue
		var reveal_alpha: float = _get_deep_reveal_alpha(
			generation_depth,
			bool(ball_result.get("is_cue_ball", false))
		)
		if reveal_alpha <= 0.001:
			continue
		_draw_predicted_balls_in_progress += 1
		_draw_visible_paths_in_progress += 1
		_deep_reveal_visible_branches += 1
		var alpha_multiplier: float = (
			maxf(0.24, 0.72 - float(generation_depth) * 0.09) * reveal_alpha
		)
		var segment_count: int = points.size() - 1
		for segment_index in range(segment_count):
			_draw_guidance_line_segment(
				points[segment_index],
				points[segment_index + 1],
				AIM_CHAIN_CORE_COLOR,
				AIM_CHAIN_GLOW_COLOR,
				_get_path_fade_ratio(segment_index, segment_count),
				alpha_multiplier,
				AIM_CHAIN_LINE_WIDTH,
				AIM_CHAIN_LINE_GLOW_WIDTH,
				AIM_CHAIN_LINE_GLOW_ALPHA
			)
		_draw_long_sight_endpoint_marker(
			points[points.size() - 1],
			bool(ball_result.get("pocketed", false)),
			alpha_multiplier
		)


func _get_first_cloned_cue_contact(result: Dictionary) -> Vector2:
	if table == null or table.cue_ball == null:
		return Vector2.ZERO
	var cue_id: int = table.cue_ball.get_instance_id()
	for event_value in result.get("events", []):
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if (
			str(event.get("event_type", "")) == AimTrajectoryPredictor.EVENT_BALL_CONTACT
			and int(event.get("source_ball_id", -1)) == cue_id
		):
			return event.get("source_center", Vector2.ZERO)
	return Vector2.ZERO


func _slice_cloned_path_from_contact(points: Array[Vector2], contact: Vector2) -> Array[Vector2]:
	if points.size() < 2 or contact == Vector2.ZERO:
		return []
	var nearest_index: int = 0
	var nearest_distance_squared: float = INF
	for point_index in range(points.size()):
		var distance_squared: float = points[point_index].distance_squared_to(contact)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_index = point_index
	var sliced: Array[Vector2] = []
	sliced.append(contact)
	for point_index in range(nearest_index + 1, points.size()):
		sliced.append(points[point_index])
	return sliced


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
			return _make_ball_prediction_from_hit(
				prediction,
				simulated_velocity,
				ball_hit,
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
	target_path.first_hit_target_center = prediction.target_first_hit_target_center
	target_path.first_hit_normal = prediction.target_first_hit_normal
	target_path.first_hit_effective_collision_radius = prediction.target_first_hit_effective_collision_radius
	target_path.first_hit_collision_skin = prediction.target_first_hit_collision_skin
	target_path.incoming_velocity_at_stop = prediction.target_incoming_velocity_at_stop
	return target_path


func _make_target_path_from_link(link: AimChainLink) -> AimTargetPath:
	var target_path: AimTargetPath = AimTargetPath.new()
	target_path.points = link.path_points.duplicate()
	target_path.ends_in_pocket = link.ends_in_pocket
	target_path.first_stop_reason = link.first_stop_reason
	target_path.path_length = link.path_length
	target_path.first_hit_ball = link.next_ball
	target_path.first_hit_position = link.first_hit_position
	target_path.first_hit_target_center = link.first_hit_target_center
	target_path.first_hit_normal = link.first_hit_normal
	target_path.first_hit_effective_collision_radius = link.first_hit_effective_collision_radius
	target_path.first_hit_collision_skin = link.first_hit_collision_skin
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

	var target_direction: Vector2 = previous_path.first_hit_normal
	if target_direction.length_squared() <= 0.001:
		target_direction = previous_path.first_hit_target_center - hit_position
	if target_direction.length_squared() <= 0.001:
		target_direction = next_ball.global_position - hit_position
	if target_direction.length_squared() <= 0.001:
		target_direction = incoming_velocity.normalized()
	else:
		target_direction = target_direction.normalized()

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
	link.first_hit_position = next_path.first_hit_position
	link.first_hit_target_center = next_path.first_hit_target_center
	link.first_hit_normal = next_path.first_hit_normal
	link.first_hit_effective_collision_radius = next_path.first_hit_effective_collision_radius
	link.first_hit_collision_skin = next_path.first_hit_collision_skin
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
	return BALL_MOTION_MATH.apply_friction(velocity, delta, {
		"rolling_friction": ball.rolling_friction,
		"stop_threshold": ball.stop_threshold,
		"medium_speed_drag_start": ball.medium_speed_drag_start,
		"high_speed_drag_multiplier": ball.high_speed_drag_multiplier,
		"medium_speed_drag_multiplier": ball.medium_speed_drag_multiplier,
		"low_speed_drag_start": ball.low_speed_drag_start,
		"low_speed_drag_multiplier": ball.low_speed_drag_multiplier,
		"crawl_speed_drag_start": ball.crawl_speed_drag_start,
		"crawl_speed_drag_multiplier": ball.crawl_speed_drag_multiplier,
	})


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
		var sweep_result: Dictionary = BALL_SWEEP_MATH.sweep_circles(
			segment_start,
			segment,
			target_ball.global_position,
			Vector2.ZERO,
			combined_radius
		)
		if not bool(sweep_result.get("hit", false)):
			if track_debug_first_hit_candidates:
				_update_debug_first_hit_candidate_result(target_ball, "miss_preview_radius", false)
			continue

		var hit_fraction: float = float(sweep_result.get("hit_fraction", -1.0))
		var hit_distance: float = hit_fraction * segment_length
		if track_debug_first_hit_candidates:
			_update_debug_first_hit_candidate_result(target_ball, "accepted", true)
		if hit_distance < nearest_hit.distance:
			nearest_hit.ball = target_ball
			nearest_hit.distance = hit_distance
			nearest_hit.position = sweep_result.get("moving_center_at_impact", segment_start + segment * hit_fraction)
			nearest_hit.target_position = sweep_result.get("target_center_at_impact", target_ball.global_position)
			nearest_hit.collision_normal = sweep_result.get("collision_normal", Vector2.ZERO)
			nearest_hit.effective_collision_radius = combined_radius
			nearest_hit.collision_skin = _get_physics_ball_collision_skin()

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
	if not debug_aim_line_enabled or not _full_debug_result_evidence_enabled():
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
	if (
		not debug_aim_line_enabled
		or not _full_debug_result_evidence_enabled()
		or target_ball == null
		or not is_instance_valid(target_ball)
	):
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
	return BALL_SWEEP_MATH.get_effective_collision_radius(
		moving_ball_radius,
		target_ball_radius,
		_get_physics_ball_collision_skin()
	)


func _full_debug_result_evidence_enabled() -> bool:
	return str(cloned_trajectory_configuration.get(
		"result_detail_mode",
		AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
	)) == AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG


func _get_legacy_graze_ball_hit_radius(moving_ball_radius: float, target_ball_radius: float) -> float:
	# Debug A/B only. Authoritative prediction never uses this reduced radius.
	var legacy_preview_skin: float = maxf(
		_get_physics_ball_collision_skin() - DEBUG_LEGACY_AIM_BALL_HIT_GRAZE_MARGIN,
		0.0
	)
	return BALL_SWEEP_MATH.get_effective_collision_radius(
		moving_ball_radius,
		target_ball_radius,
		legacy_preview_skin
	)


func _get_prediction_ball_hit_radius(moving_ball_radius: float, target_ball_radius: float) -> float:
	# First-hit prediction must match the real collision acceptance radius.
	# Visual underpromising can make the preview skip valid grazes and choose
	# the wrong first ball, while real physics still collides.
	return _get_real_ball_hit_radius(moving_ball_radius, target_ball_radius)


func _get_physics_ball_collision_skin() -> float:
	if table == null:
		return 0.0
	return maxf(float(table.BALL_COLLISION_SKIN), 0.0)


func _get_segment_circle_hit_fraction(
	segment_start: Vector2,
	segment: Vector2,
	circle_center: Vector2,
	circle_radius: float
) -> float:
	var sweep_result: Dictionary = BALL_SWEEP_MATH.sweep_circles(
		segment_start,
		segment,
		circle_center,
		Vector2.ZERO,
		circle_radius
	)
	return float(sweep_result.get("hit_fraction", -1.0)) if bool(sweep_result.get("hit", false)) else -1.0


func _make_ball_prediction_from_hit(
	prediction: AimPrediction,
	incoming_velocity: Vector2,
	ball_hit: AimBallHit,
	rail_hit_count_before_target: int,
	cue_target_impact_segment_index: int
) -> AimPrediction:
	var target_ball: Ball = ball_hit.ball
	var cue_center_at_impact: Vector2 = ball_hit.position
	var target_center_at_impact: Vector2 = ball_hit.target_position
	var target_direction: Vector2 = ball_hit.collision_normal
	if target_direction.length_squared() <= 0.001:
		target_direction = target_center_at_impact - cue_center_at_impact
	if target_direction.length_squared() <= 0.001:
		target_direction = incoming_velocity.normalized()
	else:
		target_direction = target_direction.normalized()

	var predicted_target_velocity: Vector2 = _get_predicted_target_velocity(incoming_velocity, target_ball, target_direction)

	prediction.collision_type = "ball"
	prediction.position = cue_center_at_impact
	prediction.ball = target_ball
	prediction.target_direction = target_direction
	prediction.impact_incoming_direction = incoming_velocity.normalized()
	prediction.predicted_target_velocity = predicted_target_velocity
	prediction.target_center_at_impact = target_center_at_impact
	prediction.effective_collision_radius = ball_hit.effective_collision_radius
	prediction.collision_skin = ball_hit.collision_skin
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
	prediction.target_first_hit_target_center = target_prediction.first_hit_target_center
	prediction.target_first_hit_normal = target_prediction.first_hit_normal
	prediction.target_first_hit_effective_collision_radius = target_prediction.first_hit_effective_collision_radius
	prediction.target_first_hit_collision_skin = target_prediction.first_hit_collision_skin
	prediction.target_incoming_velocity_at_stop = target_prediction.incoming_velocity_at_stop
	prediction.path_points.append(cue_center_at_impact)
	return prediction


func _get_predicted_target_velocity(incoming_velocity: Vector2, target_ball: Ball, target_direction: Vector2) -> Vector2:
	if target_direction.length_squared() <= 0.001:
		return Vector2.ZERO

	var speed_along_normal: float = BALL_COLLISION_MATH.get_impact_speed(
		incoming_velocity,
		target_ball.velocity,
		target_direction
	)
	if speed_along_normal <= 0.0:
		return Vector2.ZERO

	var impulse: Vector2 = BALL_COLLISION_MATH.get_normal_impulse(
		incoming_velocity,
		target_ball.velocity,
		target_direction,
		table.BALL_COLLISION_RESTITUTION,
		table.BALL_VELOCITY_TRANSFER
	)
	return target_ball.velocity + impulse * _get_cue_ball_wake_preview_impact_multiplier(target_ball)


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
				target_prediction.first_hit_target_center = ball_hit.target_position
				target_prediction.first_hit_normal = ball_hit.collision_normal
				target_prediction.first_hit_effective_collision_radius = ball_hit.effective_collision_radius
				target_prediction.first_hit_collision_skin = ball_hit.collision_skin
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
func _queue_aim_redraw() -> void:
	if benchmark_session != null:
		benchmark_session.note_redraw_request()
	queue_redraw()


func _store_draw_stats(draw_start_usec: int) -> void:
	var draw_cpu_us: int = maxi(Time.get_ticks_usec() - draw_start_usec, 0)
	draw_ms_last_draw = float(draw_cpu_us) / 1000.0
	draw_segments_last_draw = _draw_segments_in_progress
	draw_calls_last_draw = _draw_calls_in_progress
	if staged_prediction_state == STAGED_STATE_DEEP_READY:
		var visible_depth: int = int(round(
			_deep_reveal_progress * float(_deep_reveal_max_depth)
		))
		var ready_hidden_sample: int = 0 if _deep_reveal_visible_noted else 1
		if trajectory_profiler != null:
			trajectory_profiler.record_reveal_sample(
				_deep_reveal_preparation_pending_us,
				_deep_draw_cpu_us_in_progress,
				visible_depth,
				_deep_reveal_visible_branches,
				ready_hidden_sample
			)
		if benchmark_session != null:
			benchmark_session.record_reveal_sample(
				_deep_reveal_preparation_pending_us,
				_deep_draw_cpu_us_in_progress,
				visible_depth,
				_deep_reveal_visible_branches,
				ready_hidden_sample
			)
		_deep_reveal_preparation_pending_us = 0
	if benchmark_session != null and benchmark_session.is_recording():
		benchmark_session.record_draw_sample({
			"cpu_us": draw_cpu_us,
			"predicted_balls_drawn": _draw_predicted_balls_in_progress,
			"visible_paths": _draw_visible_paths_in_progress,
			"visible_path_segments": _draw_segments_in_progress,
			"ghost_balls_drawn": _draw_ghost_balls_in_progress,
			"labels_drawn": _draw_labels_in_progress,
			"event_markers_drawn": _draw_event_markers_in_progress,
			"draw_calls": _draw_calls_in_progress,
		})


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
