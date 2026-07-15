extends RefCounted
class_name AimTrajectoryPredictor

const BALL_SWEEP_MATH := preload("res://scripts/BallSweepMath.gd")
const BALL_COLLISION_MATH := preload("res://scripts/BallCollisionMath.gd")
const BALL_MOTION_MATH := preload("res://scripts/BallMotionMath.gd")

const EVENT_BALL_CONTACT := "ball_contact"
const EVENT_RAIL_CONTACT := "rail_contact"
const EVENT_POCKET := "pocket"
const EVENT_STOPPED := "stopped"
const UNREACHED_GENERATION := 2147483647
const MIN_REMAINING_TIME := 0.000001
const FRACTION_EPSILON := 0.0001
const TIE_EPSILON := 0.000001
const PLAYER_TRACE_COLLINEAR_ANGLE_DEGREES := 1.25
const PLAYER_TRACE_COLLINEAR_DISTANCE_EPSILON := 0.75
const PLAYER_FIRST_BALL_ROUTE_SIMULATION_DEPTH := 16
const EMERGENCY_MAX_ITERATIONS := 1000000
const EMERGENCY_MAX_GEOMETRY_PROBES := 50000000
const EMERGENCY_MAX_REMAINING_TIME_ITERATIONS := 512
const EMERGENCY_MAX_PROCESSING_MS := 60000.0

const EFFECT_CANNON_WAKE_ENABLED := "cue_ball_cannon_wake_enabled"
const EFFECT_CANNON_WAKE_IMPACT_MULTIPLIER := "cue_ball_cannon_wake_impact_multiplier"
const EFFECT_CANNON_WAKE_CUE_RETENTION := "cue_ball_cannon_wake_cue_retention"

const PROFILE_CACHE_KEY := "cache_key_construction"
const PROFILE_CLONED_SETUP := "cloned_state_setup"
const PROFILE_BROADPHASE := "broadphase_grid_work"
const PROFILE_MOVEMENT := "movement_friction"
const PROFILE_COLLISION := "swept_toi_ball_collision"
const PROFILE_RAIL_POCKET := "rail_pocket_processing"
const PROFILE_RAIL_PROCESSING := "rail_processing"
const PROFILE_POCKET_PROCESSING := "pocket_processing"
const PROFILE_RAIL_OVERLAP := "rail_overlap_resolution"
const PROFILE_CUE_BOUNDARY_CHRONOLOGY := "cue_boundary_chronology"
const PROFILE_POCKET_OVERLAP := "pocket_overlap_capture"
const PROFILE_CUE_POCKET_CHRONOLOGY := "cue_pocket_chronology"
const PROFILE_BOUNDARY_CANDIDATES := "boundary_candidate_gathering"
const PROFILE_RAIL_TESTS := "rail_sweep_intersection_testing"
const PROFILE_JAW_TESTS := "jaw_corner_testing"
const PROFILE_RAIL_RESPONSE := "rail_response_calculation"
const PROFILE_BOUNDARY_PACKAGING := "boundary_result_packaging"
const PROFILE_POCKET_CANDIDATES := "pocket_candidate_gathering"
const PROFILE_POCKET_TESTS := "pocket_sweep_capture_testing"
const PROFILE_POCKET_RESOLUTION := "pocket_resolution"
const PROFILE_POCKET_PACKAGING := "pocket_result_packaging"
const PROFILE_CROSS_TYPE_ORDERING := "cross_type_event_ordering"
const PROFILE_TRACE := "trace_recording"
const PROFILE_TRACE_SIMPLIFICATION := "trace_simplification"
const PROFILE_EVENT_PACKAGING := "event_result_packaging"
const PROFILE_TOTAL_SIMULATION := "total_simulation"

const RESULT_MODE_PLAYER_MINIMAL := "player_minimal"
const RESULT_MODE_PLAYER_EXTENDED := "player_extended"
const RESULT_MODE_FULL_DEBUG := "full_debug"
const RESULT_MODE_CHOICES: Array[Dictionary] = [
	{
		"label": "Player Minimal",
		"value": RESULT_MODE_PLAYER_MINIMAL,
		"description": "Retains exact player-facing paths and compact event identity while omitting diagnostic evidence.",
	},
	{
		"label": "Player Extended",
		"value": RESULT_MODE_PLAYER_EXTENDED,
		"description": "Adds compact ordered event and causal presentation data without full debug histories.",
	},
	{
		"label": "Full Debug",
		"value": RESULT_MODE_FULL_DEBUG,
		"description": "Retains the complete cloned prediction evidence used by the deep aim diagnostics.",
	},
]

const BENCHMARK_PRESET_LONG_SIGHT_5 := "player_long_sight_5"
const BENCHMARK_PRESET_EXTENDED_10 := "player_extended_10"
const BENCHMARK_PRESET_EXTENDED_20 := "player_extended_20"
const BENCHMARK_PRESET_STRESS_40 := "player_stress_40"
const BENCHMARK_PRESET_DEEP_DEBUG := "deep_debug"


class PredictionBall:
	var source_id: int = -1
	var ball_number: int = -1
	var label: String = "Ball"
	var source_index: int = -1
	var ball_type: int = 0
	var is_cue: bool = false
	var is_eight: bool = false
	var active: bool = true
	var pocketed: bool = false
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var starting_position: Vector2 = Vector2.ZERO
	var step_start_position: Vector2 = Vector2.ZERO
	var starting_velocity: Vector2 = Vector2.ZERO
	var radius: float = 14.0
	var motion_parameters: Dictionary = {}
	var anomaly_kind: String = ""
	var initial_unsupported_reason: String = ""
	var generation_depth: int = UNREACHED_GENERATION
	var causal_root_ball_id: int = -1
	var parent_contact_event: int = -1
	var parent_source_ball_id: int = -1
	var first_movement_event: int = -1
	var final_stop_reason: String = "active"
	var trace: Array[Vector2] = []
	var trace_protected: Array[bool] = []

	func is_moving() -> bool:
		if not active or pocketed:
			return false
		return velocity.length() >= float(motion_parameters.get("stop_threshold", 4.0))


class MotionState:
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var rail_position: Vector2 = Vector2.ZERO
	var rail_normal: Vector2 = Vector2.ZERO
	var hit_rail: bool = false


var _config: Dictionary = {}
var _constants: Dictionary = {}
var _balls: Array[PredictionBall] = []
var _ball_by_id: Dictionary = {}
var _moving_sources: Array[PredictionBall] = []
var _stationary_targets: Array[PredictionBall] = []
var _boundary_geometry: Array = []
var _pocket_geometry: Array = []
var _effect_snapshot: Dictionary = {}
var _boundary_system: BoundarySystem
var _pocket_system: PocketSystem
var _result: Dictionary = {}
var _cue_ball: PredictionBall
var _cue_toi_pending: bool = false
var _current_frame: int = 0
var _current_substep: int = 0
var _simulated_time: float = 0.0
var _current_step_delta: float = 0.0
var _total_trace_points: int = 0
var _raw_trace_points_generated: int = 0
var _trace_points_removed_by_simplification: int = 0
var _collision_events_this_substep: int = 0
var _stop_requested: bool = false
var _processing_start_usec: int = 0
var _broadphase_rebuilds: int = 0
var _maximum_simultaneously_moving_balls: int = 0
var _maximum_causal_depth: int = 0
var _input_table_revision: int = -1
var _boundary_candidates: Array[PredictionBall] = []
var _pocket_candidates: Array[PredictionBall] = []
var _boundary_profile_timings: Dictionary = {}
var _motion_state_scratch: MotionState = MotionState.new()
var _swept_candidate_scratch: Array[PredictionBall] = []
var _seen_candidate_ids_scratch: Dictionary = {}
var _moving_ball_sample_total := 0
var _moving_ball_sample_count := 0
var _stationary_ball_sample_total := 0
var _stationary_ball_sample_count := 0
var _maximum_stationary_targets := 0
var _last_iteration_source := "none"
var _last_iteration_ball_id := -1
var _last_iteration_ball_label := "none"
var _last_iteration_geometry_index := -1
var _last_iteration_event_type := "none"
var _last_iteration_remaining_fraction := -1.0
var _total_iterations := 0
var _geometry_probes := 0
var _iteration_remaining_time_attempts := 0
var _iteration_remaining_time_completed := 0
var _iteration_substep_attempts := 0
var _iteration_cue_toi_attempts := 0
var _iteration_legacy_pair_attempts := 0
var _iteration_rail_probe_attempts := 0
var _iteration_pocket_probe_attempts := 0
var _iteration_other_attempts := 0
var _iteration_substep_completed := 0
var _iteration_cue_toi_completed := 0
var _iteration_legacy_pair_completed := 0
var _iteration_rail_probe_completed := 0
var _iteration_pocket_probe_completed := 0
var _iteration_other_completed := 0

var _cache_signature: int = 0
var _cached_table_revision: int = -1
var _has_cache: bool = false
var _cached_result: Dictionary = {}
var _rebuild_count: int = 0
var _cache_hit_count: int = 0
var _processing_total_ms: float = 0.0
var _processing_max_ms: float = 0.0
var _profile_enabled := false
var _profile_phase_timings_us: Dictionary = {}
var _profile_broadphase_rebuilds := 0
var _last_boundary_geometry_revision := -1
var _last_pocket_geometry_revision := -1
var _static_geometry_cache_hits := 0
var _static_geometry_cache_rebuilds := 0
var _scratch_buffer_reuses := 0
var _temporary_allocations := 0
var _current_grid_rebuilds := 0
var _swept_grid_rebuilds := 0


static func get_configuration_schema(default_substeps: int = 4) -> Array[Dictionary]:
	var schema: Array[Dictionary] = [
		{"key": "enabled", "label": "Enable Cloned Aim Simulation", "type": "bool", "default": true},
		{"key": "use_legacy_long_sight_debug", "label": "Use Legacy Long Sight Predictor (Debug A/B)", "type": "bool", "default": false},
		{"key": "profile_enabled", "label": "Profile Cloned Aim Simulation", "type": "bool", "default": false},
		{"key": "result_detail_mode", "label": "Prediction Result Detail", "type": "select", "default": RESULT_MODE_FULL_DEBUG, "choices": RESULT_MODE_CHOICES},
		{"key": "max_simulated_seconds", "label": "Maximum Simulated Seconds", "type": "float", "minimum": 0.1, "maximum": 120.0, "step": 0.1, "default": 10.0},
		{"key": "simulation_frame_rate", "label": "Simulation Frame Rate", "type": "int", "minimum": 15, "maximum": 240, "step": 1, "default": 60},
		{"key": "simulation_substeps", "label": "Simulation Substeps", "type": "int", "minimum": 1, "maximum": 64, "step": 1, "default": maxi(default_substeps, 1)},
		{"key": "max_physics_frames", "label": "Maximum Physics Frames", "type": "int", "minimum": 1, "maximum": 20000, "step": 1, "default": 1200},
		{"key": "max_total_iterations", "label": "Maximum Control Iterations", "type": "int", "minimum": 1, "maximum": 250000, "step": 1, "default": 25000},
		{"key": "max_geometry_probes", "label": "Maximum Geometry Probes", "type": "int", "minimum": 1000, "maximum": 20000000, "step": 1000, "default": 500000},
		{"key": "max_total_events", "label": "Maximum Total Events", "type": "int", "minimum": 1, "maximum": 10000, "step": 1, "default": 500},
		{"key": "max_ball_contacts", "label": "Maximum Ball Contacts", "type": "int", "minimum": 1, "maximum": 5000, "step": 1, "default": 250},
		{"key": "max_cue_ball_contacts", "label": "Maximum Cue-Ball Contacts", "type": "int", "minimum": 1, "maximum": 1000, "step": 1, "default": 64},
		{"key": "max_rail_contacts", "label": "Maximum Rail Contacts", "type": "int", "minimum": 1, "maximum": 5000, "step": 1, "default": 250},
		{"key": "max_pocket_events", "label": "Maximum Pocket Events", "type": "int", "minimum": 1, "maximum": 1000, "step": 1, "default": 64},
		{"key": "max_tracked_balls", "label": "Maximum Tracked Balls", "type": "int", "minimum": 1, "maximum": 512, "step": 1, "default": 128},
		{"key": "max_child_generation_depth", "label": "Maximum Child Generation Depth", "type": "int", "minimum": 0, "maximum": 64, "step": 1, "default": 16},
		{"key": "max_points_per_ball", "label": "Maximum Points Per Ball", "type": "int", "minimum": 10, "maximum": 50000, "step": 10, "default": 2500},
		{"key": "max_total_trace_points", "label": "Maximum Total Trace Points", "type": "int", "minimum": 100, "maximum": 500000, "step": 100, "default": 50000},
		{"key": "trace_point_spacing", "label": "Trace Point Spacing", "type": "float", "minimum": 0.1, "maximum": 32.0, "step": 0.1, "default": 2.0},
		{"key": "player_trace_spacing", "label": "Player Trace Spacing", "type": "float", "minimum": 0.5, "maximum": 64.0, "step": 0.5, "default": 10.0},
		{"key": "max_processing_time_ms", "label": "Maximum Processing Time (ms)", "type": "float", "minimum": 1.0, "maximum": 10000.0, "step": 1.0, "default": 250.0},
		{"key": "max_collision_events_per_substep", "label": "Maximum Collision Events Per Substep", "type": "int", "minimum": 1, "maximum": 256, "step": 1, "default": 16},
		{"key": "draw_cue_continuation", "label": "Draw Cue Continuation", "type": "bool", "default": true},
		{"key": "draw_child_ball_paths", "label": "Draw Child Ball Paths", "type": "bool", "default": true},
		{"key": "draw_ghost_balls", "label": "Draw Ghost Balls", "type": "bool", "default": true},
		{"key": "draw_event_numbers", "label": "Draw Event Numbers", "type": "bool", "default": true},
		{"key": "draw_ball_labels", "label": "Draw Ball Labels", "type": "bool", "default": true},
		{"key": "draw_stop_pocket_markers", "label": "Draw Stop/Pocket Markers", "type": "bool", "default": true},
		{"key": "compare_predicted_event_chain", "label": "Compare Predicted Event Chain", "type": "bool", "default": true},
	]
	var help_by_key: Dictionary = _get_configuration_help()
	for definition in schema:
		var key: String = str(definition.get("key", ""))
		var help: Dictionary = help_by_key.get(key, {})
		definition.merge(help, true)
	return schema


static func _get_configuration_help() -> Dictionary:
	return {
		"enabled": {
			"description": "Runs the cloned deterministic table simulation used by advanced aim diagnostics. Player-facing extended aim keeps its required production clone path.",
			"on_effect": "The cloned predictor may rebuild while aiming and provide simulation diagnostics.",
			"off_effect": "Debug cloned simulation is disabled; active player-facing extended aim still uses its production cloned configuration.",
			"keywords": ["trajectory clone", "deterministic prediction"],
			"aliases": ["Cloned Predictor"],
		},
		"use_legacy_long_sight_debug": {
			"description": "Uses the older lightweight extended-aim calculation instead of the cloned deterministic predictor. This exists only for developer comparison and may be less accurate.",
			"on_effect": "Tests the old linear predictor in debug builds. Release builds ignore this switch and remain cloned.",
			"off_effect": "Player-facing Long Sight uses the accurate cloned deterministic simulation.",
			"keywords": ["boon", "secondary path", "advanced aim"],
			"aliases": [
				"legacy aim",
				"old long sight",
				"linear predictor",
				"cloned predictor comparison",
				"Use Cloned Predictor for Long Sight",
			],
		},
		"profile_enabled": {
			"description": "Records phase-level CPU timings and bounded rebuild history for the cloned aim simulation.",
			"on_effect": "Completed rebuilds collect detailed timing and workload samples.",
			"off_effect": "Detailed profiler sampling is skipped to avoid measurement overhead.",
			"keywords": ["aim profiler", "microseconds", "timing baseline"],
		},
		"result_detail_mode": {
			"description": "Controls retained prediction evidence and presentation data without changing deterministic collision math.",
			"keywords": ["player minimal", "player extended", "full debug", "result evidence"],
		},
		"max_simulated_seconds": {
			"description": "Limits how far into the future the cloned aim predictor may simulate.",
			"unit": "seconds",
			"low_effect": "Faster and more responsive, but long ball routes may be cut off early.",
			"high_effect": "Predicts farther into the future, but can make aiming significantly slower.",
			"keywords": ["time horizon", "future path"],
			"aliases": ["simulation duration"],
		},
		"simulation_frame_rate": {
			"description": "Sets how many cloned physics frames are simulated per predicted second.",
			"unit": "frames/second",
			"low_effect": "Uses fewer frames and less CPU time, but fast or curved sequences may be less detailed.",
			"high_effect": "Samples motion more often for finer timing at a higher CPU cost.",
			"keywords": ["simulation fps", "time step"],
		},
		"simulation_substeps": {
			"description": "Splits each cloned physics frame into smaller collision and movement steps.",
			"unit": "substeps/frame",
			"low_effect": "Runs faster with coarser collision timing.",
			"high_effect": "Improves fast-contact resolution but multiplies prediction work.",
			"keywords": ["collision accuracy", "physics substeps"],
		},
		"max_physics_frames": {
			"description": "Stops the cloned simulation after this many predicted physics frames even if balls are still moving.",
			"unit": "frames",
			"low_effect": "Finishes quickly but may truncate long trajectories.",
			"high_effect": "Allows longer trajectories while increasing worst-case work.",
			"keywords": ["frame cap", "simulation limit"],
		},
		"max_total_iterations": {
			"description": "Stops the cloned simulation after this many control-loop steps, including substeps and remaining-time passes.",
			"unit": "control iterations",
			"low_effect": "Protects responsiveness aggressively but can stop complex predictions early.",
			"high_effect": "Allows more complex contact chains but raises worst-case CPU cost.",
			"keywords": ["work cap", "safety limit"],
		},
		"max_geometry_probes": {
			"description": "Stops the cloned simulation after this many ball, rail, jaw, and pocket candidate probes.",
			"unit": "geometry probes",
			"low_effect": "Protects responsiveness aggressively but may truncate geometry-heavy predictions.",
			"high_effect": "Allows dense tables and long bank chains at a higher worst-case CPU cost.",
			"keywords": ["geometry budget", "candidate cap", "probe limit"],
		},
		"max_total_events": {
			"description": "Caps the total number of ball, rail, pocket, and stop events recorded by one cloned prediction.",
			"unit": "events",
			"low_effect": "Keeps event packaging small but can truncate busy chains.",
			"high_effect": "Retains more complex chains at greater memory and formatting cost.",
			"keywords": ["event cap", "contact history"],
		},
		"max_ball_contacts": {
			"description": "Caps all ball-to-ball contacts recorded during one cloned prediction.",
			"unit": "contacts",
			"low_effect": "Stops dense collision chains sooner.",
			"high_effect": "Allows more collision cascades at higher simulation cost.",
			"keywords": ["ball collision cap", "contact limit"],
		},
		"max_cue_ball_contacts": {
			"description": "Caps how many ball contacts involving the cue ball may be followed in one cloned prediction.",
			"unit": "contacts",
			"low_effect": "Limits repeated cue-ball caroms quickly.",
			"high_effect": "Follows longer cue-ball contact sequences at added cost.",
			"keywords": ["cue collision cap", "cue contacts"],
		},
		"max_rail_contacts": {
			"description": "Caps rail contacts recorded across all cloned balls in one prediction.",
			"unit": "contacts",
			"low_effect": "Long bank routes may end early.",
			"high_effect": "Allows more banks and rebounds at greater work cost.",
			"keywords": ["bank cap", "rail events"],
		},
		"max_pocket_events": {
			"description": "Caps pocket-entry events recorded during one cloned prediction.",
			"unit": "events",
			"low_effect": "Large multi-sink simulations may truncate early.",
			"high_effect": "Allows more predicted sinks with a larger event record.",
			"keywords": ["sink cap", "pocket limit"],
		},
		"max_tracked_balls": {
			"description": "Limits how many active table balls are cloned and followed by the predictor.",
			"unit": "balls",
			"low_effect": "Reduces setup and pair work but may omit balls on crowded tables.",
			"high_effect": "Covers denser tables while increasing broadphase and collision work.",
			"keywords": ["clone count", "ball limit"],
		},
		"max_child_generation_depth": {
			"description": "Limits how many successive ball-to-ball transfers away from the cue ball receive visible predicted paths.",
			"unit": "generations",
			"low_effect": "Shows only immediate outcomes and keeps the trace simple.",
			"high_effect": "Follows deeper chain reactions with more simulation and draw data.",
			"keywords": ["chain depth", "secondary balls"],
		},
		"max_points_per_ball": {
			"description": "Caps the number of recorded path points for each cloned ball.",
			"unit": "points/ball",
			"low_effect": "Uses less memory but long paths may stop drawing early.",
			"high_effect": "Preserves longer detailed paths at higher memory and presentation cost.",
			"keywords": ["trace cap", "path samples"],
		},
		"max_total_trace_points": {
			"description": "Caps path points recorded across all cloned balls in one prediction.",
			"unit": "points",
			"low_effect": "Protects memory and draw preparation but truncates busy traces sooner.",
			"high_effect": "Allows larger multi-ball traces at higher CPU and memory cost.",
			"keywords": ["global trace cap", "path memory"],
		},
		"trace_point_spacing": {
			"description": "Controls the minimum travel distance between stored trajectory points.",
			"unit": "pixels",
			"low_effect": "Records smoother, denser paths with higher memory and draw cost.",
			"high_effect": "Records fewer points for faster, coarser path drawing.",
			"keywords": ["trace density", "path resolution"],
		},
		"player_trace_spacing": {
			"description": "Sets the pre-simplification spacing between non-event path points in player-facing result modes.",
			"unit": "pixels",
			"low_effect": "Retains a denser player path with more presentation work.",
			"high_effect": "Stores fewer straight-route points while exact contacts, rails, pockets, and stops stay protected.",
			"keywords": ["player path density", "trace simplification", "long sight spacing"],
		},
		"max_processing_time_ms": {
			"description": "Stops one cloned prediction rebuild after this much CPU processing time.",
			"unit": "milliseconds",
			"low_effect": "Protects aiming responsiveness but may truncate difficult simulations.",
			"high_effect": "Allows expensive predictions to finish but can cause visible stalls.",
			"keywords": ["time budget", "timeout", "cpu cap"],
		},
		"max_collision_events_per_substep": {
			"description": "Limits repeated collision resolutions inside one cloned simulation substep.",
			"unit": "events/substep",
			"low_effect": "Prevents collision loops quickly but may stop dense simultaneous contacts.",
			"high_effect": "Resolves more crowded contacts at higher worst-case CPU cost.",
			"keywords": ["collision loop cap", "resolver limit"],
		},
		"draw_cue_continuation": _draw_help("Draws the cue ball's predicted route after its first object-ball contact.", "The post-contact cue path is shown.", "The cue path ends at its first object-ball contact.", ["cue path", "post impact"]),
		"draw_child_ball_paths": _draw_help("Draws predicted paths for object balls moved by the cue ball or later contacts.", "Secondary ball paths are shown.", "Only the cue path is drawn.", ["object paths", "chain lines"]),
		"draw_ghost_balls": _draw_help("Draws translucent ball markers at important predicted contact positions.", "Ghost contact balls are visible.", "Ghost contact balls are hidden.", ["contact marker", "ghost position"]),
		"draw_event_numbers": _draw_help("Numbers predicted contacts, rails, pockets, and stops in event order.", "Event-order numbers are drawn.", "Event-order numbers are hidden.", ["event labels", "sequence numbers"]),
		"draw_ball_labels": _draw_help("Labels cloned trajectory paths with their source ball identities.", "Ball identity labels are drawn.", "Ball identity labels are hidden.", ["path names", "ball ids"]),
		"draw_stop_pocket_markers": _draw_help("Marks where cloned balls stop or enter pockets.", "Stop and pocket endpoint markers are drawn.", "Endpoint markers are hidden.", ["end marker", "sink marker"]),
		"compare_predicted_event_chain": _draw_help("Records and compares the ordered cloned event chain with events observed during the real shot.", "Predicted-versus-actual event comparison is collected.", "Event-chain comparison work is skipped.", ["event comparison", "actual shot chain"]),
	}


static func _draw_help(description: String, on_effect: String, off_effect: String, keywords: Array) -> Dictionary:
	return {
		"description": description,
		"on_effect": on_effect,
		"off_effect": off_effect,
		"keywords": keywords,
	}


static func get_default_configuration(default_substeps: int = 4) -> Dictionary:
	var defaults: Dictionary = {}
	for definition in get_configuration_schema(default_substeps):
		defaults[str(definition.get("key", ""))] = definition.get("default")
	return defaults


static func normalize_configuration(configuration: Dictionary, default_substeps: int = 4) -> Dictionary:
	var normalized: Dictionary = get_default_configuration(default_substeps)
	for definition in get_configuration_schema(default_substeps):
		var key: String = str(definition.get("key", ""))
		var value: Variant = configuration.get(key, definition.get("default"))
		match str(definition.get("type", "")):
			"bool":
				normalized[key] = bool(value)
			"int":
				normalized[key] = clampi(
					int(value),
					int(definition.get("minimum", 0)),
					int(definition.get("maximum", 0))
				)
			"float":
				normalized[key] = clampf(
					float(value),
					float(definition.get("minimum", 0.0)),
					float(definition.get("maximum", 0.0))
				)
			"select":
				var selected_value: String = str(value)
				var valid_values: Array[String] = []
				for choice_value in definition.get("choices", []):
					if choice_value is Dictionary:
						valid_values.append(str((choice_value as Dictionary).get("value", "")))
				normalized[key] = (
					selected_value
					if selected_value in valid_values
					else str(definition.get("default", ""))
				)
	_apply_result_mode_constraints(normalized)
	return normalized


static func _apply_result_mode_constraints(configuration: Dictionary) -> void:
	var result_mode: String = str(configuration.get("result_detail_mode", RESULT_MODE_FULL_DEBUG))
	if result_mode == RESULT_MODE_PLAYER_MINIMAL:
		configuration["draw_ghost_balls"] = false
		configuration["draw_event_numbers"] = false
		configuration["draw_ball_labels"] = false
		configuration["compare_predicted_event_chain"] = false
	elif result_mode == RESULT_MODE_PLAYER_EXTENDED:
		configuration["draw_event_numbers"] = false
		configuration["draw_ball_labels"] = false
		configuration["compare_predicted_event_chain"] = false


static func get_benchmark_preset_definitions(default_substeps: int = 4) -> Array[Dictionary]:
	return [
		{
			"id": BENCHMARK_PRESET_LONG_SIGHT_5,
			"label": "Player Long Sight 5",
			"description": "Production-like depth-5 player paths with minimal retained evidence.",
			"configuration": _make_player_benchmark_configuration(
				RESULT_MODE_PLAYER_MINIMAL,
				5,
				8.0,
				40,
				32,
				16,
				48,
				16,
				5000,
				400,
				10.0,
				default_substeps
			),
		},
		{
			"id": BENCHMARK_PRESET_EXTENDED_10,
			"label": "Player Extended 10",
			"description": "Production-like minimal evidence with a ten-generation causal horizon.",
			"configuration": _make_player_benchmark_configuration(
				RESULT_MODE_PLAYER_MINIMAL,
				10,
				12.0,
				64,
				48,
				24,
				80,
				24,
				10000,
				700,
				10.0,
				default_substeps
			),
		},
		{
			"id": BENCHMARK_PRESET_EXTENDED_20,
			"label": "Player Extended 20",
			"description": "A deeper production-like route with minimal evidence and wider work limits.",
			"configuration": _make_player_benchmark_configuration(
				RESULT_MODE_PLAYER_MINIMAL,
				20,
				18.0,
				128,
				96,
				48,
				160,
				48,
				20000,
				1200,
				8.0,
				default_substeps
			),
		},
		{
			"id": BENCHMARK_PRESET_STRESS_40,
			"label": "Player Stress 40",
			"description": "Compact extended presentation evidence with a forty-generation stress horizon.",
			"configuration": _make_player_benchmark_configuration(
				RESULT_MODE_PLAYER_EXTENDED,
				40,
				30.0,
				300,
				220,
				100,
				400,
				100,
				50000,
				2500,
				6.0,
				default_substeps
			),
		},
		{
			"id": BENCHMARK_PRESET_DEEP_DEBUG,
			"label": "Deep Debug",
			"description": "Restores full diagnostic evidence, comparison, ghost markers, labels, and dense traces.",
			"configuration": _make_deep_debug_configuration(default_substeps),
		},
	]


static func get_benchmark_preset_configuration(
	preset_id: String,
	default_substeps: int = 4
) -> Dictionary:
	for preset in get_benchmark_preset_definitions(default_substeps):
		if str(preset.get("id", "")) == preset_id:
			return normalize_configuration(
				(preset.get("configuration", {}) as Dictionary).duplicate(true),
				default_substeps
			)
	return get_benchmark_preset_configuration(BENCHMARK_PRESET_LONG_SIGHT_5, default_substeps)


static func get_benchmark_preset_label(preset_id: String, default_substeps: int = 4) -> String:
	for preset in get_benchmark_preset_definitions(default_substeps):
		if str(preset.get("id", "")) == preset_id:
			return str(preset.get("label", preset_id))
	return preset_id


static func _make_player_benchmark_configuration(
	result_mode: String,
	depth: int,
	seconds: float,
	max_events: int,
	max_ball_contacts: int,
	max_cue_contacts: int,
	max_rail_contacts: int,
	max_pocket_events: int,
	max_total_points: int,
	max_points_per_ball: int,
	trace_spacing: float,
	default_substeps: int
) -> Dictionary:
	var configuration: Dictionary = get_default_configuration(default_substeps)
	configuration["enabled"] = true
	configuration["profile_enabled"] = true
	configuration["result_detail_mode"] = result_mode
	configuration["max_child_generation_depth"] = depth
	configuration["max_simulated_seconds"] = seconds
	configuration["max_physics_frames"] = maxi(ceili(seconds * 60.0), 1)
	configuration["max_total_events"] = max_events
	configuration["max_ball_contacts"] = max_ball_contacts
	configuration["max_cue_ball_contacts"] = max_cue_contacts
	configuration["max_rail_contacts"] = max_rail_contacts
	configuration["max_pocket_events"] = max_pocket_events
	configuration["max_total_trace_points"] = max_total_points
	configuration["max_points_per_ball"] = max_points_per_ball
	configuration["player_trace_spacing"] = trace_spacing
	configuration["draw_cue_continuation"] = true
	configuration["draw_child_ball_paths"] = true
	configuration["draw_ghost_balls"] = false
	configuration["draw_event_numbers"] = false
	configuration["draw_ball_labels"] = false
	configuration["draw_stop_pocket_markers"] = true
	configuration["compare_predicted_event_chain"] = false
	return normalize_configuration(configuration, default_substeps)


static func _make_deep_debug_configuration(default_substeps: int) -> Dictionary:
	var configuration: Dictionary = get_default_configuration(default_substeps)
	configuration["enabled"] = true
	configuration["profile_enabled"] = true
	configuration["result_detail_mode"] = RESULT_MODE_FULL_DEBUG
	configuration["draw_cue_continuation"] = true
	configuration["draw_child_ball_paths"] = true
	configuration["draw_ghost_balls"] = true
	configuration["draw_event_numbers"] = true
	configuration["draw_ball_labels"] = true
	configuration["draw_stop_pocket_markers"] = true
	configuration["compare_predicted_event_chain"] = true
	configuration["max_geometry_probes"] = 5000000
	return normalize_configuration(configuration, default_substeps)


static func get_player_long_sight_configuration(chain_depth: int, default_substeps: int = 4) -> Dictionary:
	return get_player_aim_configuration(chain_depth, default_substeps)


static func get_player_aim_configuration(chain_depth: int, default_substeps: int = 4) -> Dictionary:
	var configuration: Dictionary = get_default_configuration(default_substeps)
	configuration["result_detail_mode"] = RESULT_MODE_PLAYER_MINIMAL
	configuration["max_simulated_seconds"] = 8.0
	configuration["max_physics_frames"] = 480
	if chain_depth <= 0:
		# Normal aim is shallow in causal visibility, not in travel distance. The
		# cue still has room to reach a first contact after several rail events.
		configuration["max_total_iterations"] = 16000
		configuration["max_geometry_probes"] = 750000
		configuration["max_total_events"] = 40
		configuration["max_ball_contacts"] = 16
		configuration["max_cue_ball_contacts"] = 8
		configuration["max_rail_contacts"] = 48
		configuration["max_pocket_events"] = 8
		# Visible normal aim remains depth 1. Hidden causal simulation continues
		# far enough to retain the first struck ball's own complete response route.
		configuration["max_child_generation_depth"] = PLAYER_FIRST_BALL_ROUTE_SIMULATION_DEPTH
	else:
		configuration["max_total_iterations"] = 12000
		configuration["max_geometry_probes"] = 500000
		configuration["max_total_events"] = 160
		configuration["max_ball_contacts"] = 96
		configuration["max_cue_ball_contacts"] = 32
		configuration["max_rail_contacts"] = 96
		configuration["max_pocket_events"] = 32
		configuration["max_child_generation_depth"] = maxi(
			clampi(chain_depth, 1, 64),
			PLAYER_FIRST_BALL_ROUTE_SIMULATION_DEPTH
		)
	configuration["max_points_per_ball"] = 900
	configuration["max_total_trace_points"] = 8000
	configuration["player_trace_spacing"] = 10.0
	configuration["max_processing_time_ms"] = 24.0
	configuration["draw_ghost_balls"] = false
	configuration["draw_event_numbers"] = false
	configuration["draw_ball_labels"] = false
	configuration["compare_predicted_event_chain"] = false
	return normalize_configuration(configuration, default_substeps)


func simulate(input_snapshot: Dictionary, configuration: Dictionary) -> Dictionary:
	var default_substeps: int = maxi(int(input_snapshot.get("default_substeps", 4)), 1)
	_config = normalize_configuration(configuration, default_substeps)
	_profile_enabled = bool(_config.get("profile_enabled", false))
	_profile_phase_timings_us.clear()
	_profile_broadphase_rebuilds = 0
	if not bool(_config.get("enabled", true)):
		return _make_disabled_result()

	var cache_key_start_usec: int = _profile_begin_phase()
	var signature: int = _make_input_signature(input_snapshot, _config)
	_profile_end_phase(PROFILE_CACHE_KEY, cache_key_start_usec)
	var input_table_revision: int = int(input_snapshot.get("table_prediction_revision", -1))
	if (
		_has_cache
		and signature == _cache_signature
		and _cached_table_revision == input_table_revision
	):
		_cache_hit_count += 1
		_cached_result["cache_hit"] = true
		_cached_result["cache_hit_count"] = _cache_hit_count
		return _cached_result.duplicate(true)

	_rebuild_count += 1
	_processing_start_usec = Time.get_ticks_usec()
	var setup_start_usec: int = _profile_begin_phase()
	_reset_working_state(input_snapshot)
	_result = _make_empty_result()
	_result["table_revision"] = _input_table_revision
	_result["rebuild_count"] = _rebuild_count
	_result["cache_hit_count"] = _cache_hit_count
	_result["cache_hit"] = false
	_clone_balls(input_snapshot.get("balls", []))
	_profile_end_phase(PROFILE_CLONED_SETUP, setup_start_usec)

	var simulation_start_usec: int = _profile_begin_phase()
	if not _stop_requested:
		_run_simulation()
	_profile_end_phase(PROFILE_TOTAL_SIMULATION, simulation_start_usec)
	var simplification_start_usec: int = _profile_begin_phase()
	_prepare_player_result_traces()
	_profile_end_phase(PROFILE_TRACE_SIMPLIFICATION, simplification_start_usec)
	var packaging_start_usec: int = _profile_begin_phase()
	_finalize_result()
	_profile_end_phase(PROFILE_EVENT_PACKAGING, packaging_start_usec)
	if _profile_enabled:
		_result["profile_phase_timings_us"] = _profile_phase_timings_us.duplicate(true)
		_result["profile_broadphase_rebuilds"] = _profile_broadphase_rebuilds

	var processing_ms: float = _elapsed_processing_ms()
	_result["processing_time_ms"] = processing_ms
	_processing_total_ms += processing_ms
	_processing_max_ms = maxf(_processing_max_ms, processing_ms)
	_result["average_processing_time_ms"] = _processing_total_ms / float(maxi(_rebuild_count, 1))
	_result["maximum_processing_time_ms"] = _processing_max_ms
	_cache_signature = signature
	_cached_table_revision = _input_table_revision
	_cached_result = _result.duplicate(true)
	_has_cache = true
	return _cached_result.duplicate(true)


func clear_cache() -> void:
	_has_cache = false
	_cache_signature = 0
	_cached_table_revision = -1
	_cached_result.clear()


func get_cache_debug_snapshot() -> Dictionary:
	return {
		"has_cache": _has_cache,
		"cached_revision": _cached_table_revision,
		"rebuild_count": _rebuild_count,
		"cache_hit_count": _cache_hit_count,
		"average_processing_time_ms": _processing_total_ms / float(maxi(_rebuild_count, 1)),
		"maximum_processing_time_ms": _processing_max_ms,
	}


func _profile_begin_phase() -> int:
	if not _profile_enabled:
		return 0
	return Time.get_ticks_usec()


func _profile_end_phase(phase_key: String, start_usec: int) -> void:
	if not _profile_enabled or start_usec <= 0:
		return
	var elapsed_usec: int = maxi(Time.get_ticks_usec() - start_usec, 0)
	_profile_phase_timings_us[phase_key] = (
		int(_profile_phase_timings_us.get(phase_key, 0)) + elapsed_usec
	)


func _profile_add_elapsed(phase_key: String, elapsed_usec: int) -> void:
	if not _profile_enabled or elapsed_usec <= 0:
		return
	_profile_phase_timings_us[phase_key] = (
		int(_profile_phase_timings_us.get(phase_key, 0)) + elapsed_usec
	)


func _profile_move_active_balls(delta: float) -> void:
	var phase_start_usec: int = _profile_begin_phase()
	_move_active_balls(delta)
	_profile_end_phase(PROFILE_MOVEMENT, phase_start_usec)


func _reset_working_state(input_snapshot: Dictionary) -> void:
	_constants = input_snapshot.get("physics_constants", {}).duplicate(true)
	var boundary_geometry_value: Variant = input_snapshot.get("boundary_geometry", [])
	var pocket_geometry_value: Variant = input_snapshot.get("pocket_geometry", [])
	_boundary_geometry = boundary_geometry_value if boundary_geometry_value is Array else []
	_pocket_geometry = pocket_geometry_value if pocket_geometry_value is Array else []
	var boundary_revision: int = int(input_snapshot.get("boundary_geometry_revision", -1))
	var pocket_revision: int = int(input_snapshot.get("pocket_geometry_revision", -1))
	_static_geometry_cache_hits = 0
	_static_geometry_cache_rebuilds = 0
	if boundary_revision == _last_boundary_geometry_revision:
		_static_geometry_cache_hits += 1
	else:
		_static_geometry_cache_rebuilds += 1
	if pocket_revision == _last_pocket_geometry_revision:
		_static_geometry_cache_hits += 1
	else:
		_static_geometry_cache_rebuilds += 1
	_last_boundary_geometry_revision = boundary_revision
	_last_pocket_geometry_revision = pocket_revision
	_effect_snapshot = input_snapshot.get("effect_snapshot", {}).duplicate(true)
	_input_table_revision = int(input_snapshot.get("table_prediction_revision", -1))
	_boundary_system = input_snapshot.get("boundary_system") as BoundarySystem
	_pocket_system = input_snapshot.get("pocket_system") as PocketSystem
	_balls.clear()
	_ball_by_id.clear()
	_moving_sources.clear()
	_stationary_targets.clear()
	_cue_ball = null
	_cue_toi_pending = bool(input_snapshot.get("cue_first_contact_toi_enabled", true))
	_current_frame = 0
	_current_substep = 0
	_simulated_time = 0.0
	_current_step_delta = 0.0
	_total_trace_points = 0
	_raw_trace_points_generated = 0
	_trace_points_removed_by_simplification = 0
	_collision_events_this_substep = 0
	_stop_requested = false
	_broadphase_rebuilds = 0
	_maximum_simultaneously_moving_balls = 0
	_maximum_causal_depth = 0
	_boundary_candidates.clear()
	_pocket_candidates.clear()
	_boundary_profile_timings.clear()
	_moving_ball_sample_total = 0
	_moving_ball_sample_count = 0
	_stationary_ball_sample_total = 0
	_stationary_ball_sample_count = 0
	_maximum_stationary_targets = 0
	_last_iteration_source = "none"
	_last_iteration_ball_id = -1
	_last_iteration_ball_label = "none"
	_last_iteration_geometry_index = -1
	_last_iteration_event_type = "none"
	_last_iteration_remaining_fraction = -1.0
	_total_iterations = 0
	_geometry_probes = 0
	_iteration_remaining_time_attempts = 0
	_iteration_remaining_time_completed = 0
	_iteration_substep_attempts = 0
	_iteration_cue_toi_attempts = 0
	_iteration_legacy_pair_attempts = 0
	_iteration_rail_probe_attempts = 0
	_iteration_pocket_probe_attempts = 0
	_iteration_other_attempts = 0
	_iteration_substep_completed = 0
	_iteration_cue_toi_completed = 0
	_iteration_legacy_pair_completed = 0
	_iteration_rail_probe_completed = 0
	_iteration_pocket_probe_completed = 0
	_iteration_other_completed = 0
	_scratch_buffer_reuses = 0
	_temporary_allocations = 0
	_current_grid_rebuilds = 0
	_swept_grid_rebuilds = 0


func _make_empty_result() -> Dictionary:
	return {
		"valid": true,
		"complete": false,
		"truncated": false,
		"stop_reason": "running",
		"cap_reached": "",
		"elapsed_simulated_time": 0.0,
		"simulated_physics_frames": 0,
		"simulated_substeps": 0,
		"total_iterations": 0,
		"geometry_probes": 0,
		"control_iteration_budget": int(_config.get("max_total_iterations", 25000)),
		"geometry_probe_budget": int(_config.get("max_geometry_probes", 500000)),
		"iteration_breakdown": {
			"frames": 0,
			"substeps": 0,
			"ball_movement": 0,
			"pair_collision": 0,
			"boundaries": 0,
			"pockets": 0,
			"remaining_time": 0,
			"broadphase": 0,
			"event_loop": 0,
			"trace": 0,
			"other": 0,
		},
		"completed_iteration_breakdown": {},
		"iteration_source_attempts": {},
		"iteration_source_completed": {},
		"iteration_cap_detail": {},
		"geometry_probe_cap_detail": {},
		"total_events": 0,
		"total_ball_contacts": 0,
		"total_cue_ball_contacts": 0,
		"total_rail_contacts": 0,
		"total_pocket_captures": 0,
		"total_stops": 0,
		"total_traced_balls": 0,
		"total_trace_points": 0,
		"raw_trace_points_generated": 0,
		"retained_trace_points": 0,
		"trace_points_removed_by_simplification": 0,
		"trace_points_removed_by_spacing_or_duplicates": 0,
		"trace_points_removed_by_collinear_simplification": 0,
		"trace_simplification_percent": 0.0,
		"candidate_tests": 0,
		"pair_checks": 0,
		"swept_toi_solves": 0,
		"broadphase_rebuilds": 0,
		"full_broadphase_rebuilds": 0,
		"incremental_broadphase_updates": 0,
		"current_grid_rebuilds": 0,
		"swept_grid_rebuilds": 0,
		"maximum_simultaneously_moving_balls": 0,
		"maximum_causal_depth": 0,
		"result_memory_estimate_bytes": 0,
		"broadphase_cells": 0,
		"maximum_broadphase_cell_size": 0,
		"boundary_shapes_available": _boundary_geometry.size(),
		"rail_shapes_available": _count_boundary_geometry_kind("rail"),
		"jaw_shapes_available": _count_boundary_geometry_kind("jaw"),
		"rail_candidate_queries": 0,
		"rail_shapes_tested": 0,
		"jaw_shapes_tested": 0,
		"rail_swept_tests": 0,
		"rail_candidates_rejected_by_aabb": 0,
		"rail_events_accepted": 0,
		"pocket_count_available": _pocket_geometry.size(),
		"pocket_candidate_queries": 0,
		"pockets_tested": 0,
		"pocket_swept_tests": 0,
		"pocket_candidates_rejected_by_aabb": 0,
		"pocket_events_accepted": 0,
		"cloned_balls_checked_against_boundaries": 0,
		"cloned_balls_checked_against_pockets": 0,
		"stopped_balls_skipped_from_movement": 0,
		"stopped_balls_skipped_from_rail_checks": 0,
		"stopped_balls_skipped_from_pocket_checks": 0,
		"stopped_balls_included_in_broadphase": 0,
		"inactive_balls_skipped_from_loops": 0,
		"repeated_boundary_checks": 0,
		"remaining_time_boundary_iterations": 0,
		"boundary_temporary_objects_created": 0,
		"pocket_temporary_objects_created": 0,
		"moving_balls_per_substep_average": 0.0,
		"moving_balls_per_substep_maximum": 0,
		"stationary_targets_per_substep_average": 0.0,
		"stationary_targets_per_substep_maximum": 0,
		"static_geometry_cache_hits": 0,
		"static_geometry_cache_rebuilds": 0,
		"scratch_buffer_reuses": 0,
		"temporary_allocations": 0,
		"balls_newly_stopped": 0,
		"processing_time_ms": 0.0,
		"unsupported_warnings": [],
		"events": [],
		"balls": [],
		"configuration": _config.duplicate(true),
	}


func _make_disabled_result() -> Dictionary:
	return {
		"valid": false,
		"complete": false,
		"truncated": false,
		"stop_reason": "disabled",
		"cap_reached": "",
		"events": [],
		"balls": [],
		"configuration": _config.duplicate(true),
		"rebuild_count": _rebuild_count,
		"cache_hit_count": _cache_hit_count,
	}


func _clone_balls(ball_snapshots_value: Variant) -> void:
	if not ball_snapshots_value is Array:
		_result["valid"] = false
		_request_stop("invalid_ball_snapshot", false)
		return
	var ball_snapshots: Array = ball_snapshots_value
	if ball_snapshots.size() > int(_config.get("max_tracked_balls", 128)):
		_request_stop("max_tracked_balls", true)
		return

	for ball_value in ball_snapshots:
		if not ball_value is Dictionary:
			continue
		var snapshot: Dictionary = ball_value
		if not bool(snapshot.get("gameplay_active", false)):
			continue
		var ball: PredictionBall = PredictionBall.new()
		ball.source_id = int(snapshot.get("source_id", -1))
		ball.ball_number = int(snapshot.get("ball_number", -1))
		ball.label = str(snapshot.get("label", "Ball %s" % ball.ball_number))
		ball.source_index = int(snapshot.get("source_index", _balls.size()))
		ball.ball_type = int(snapshot.get("ball_type", 0))
		ball.is_cue = bool(snapshot.get("is_cue_ball", false))
		ball.is_eight = bool(snapshot.get("is_eight_ball", false))
		ball.position = snapshot.get("position", Vector2.ZERO)
		ball.velocity = snapshot.get("velocity", Vector2.ZERO)
		if ball.is_cue:
			ball.position = snapshot.get("launch_position", ball.position)
			ball.velocity = snapshot.get("launch_velocity", ball.velocity)
		ball.starting_position = ball.position
		ball.step_start_position = ball.position
		ball.starting_velocity = ball.velocity
		ball.radius = maxf(float(snapshot.get("radius", 14.0)), 0.01)
		ball.motion_parameters = snapshot.get("motion_parameters", {}).duplicate(true)
		ball.anomaly_kind = str(snapshot.get("anomaly_kind", ""))
		ball.initial_unsupported_reason = str(snapshot.get("initial_unsupported_reason", ""))
		ball.generation_depth = 0 if ball.is_cue or ball.is_moving() else UNREACHED_GENERATION
		if ball.generation_depth == 0:
			ball.causal_root_ball_id = ball.source_id
		_balls.append(ball)
		_ball_by_id[ball.source_id] = ball
		_append_trace_point(ball, ball.position, true)
		if ball.is_cue:
			_cue_ball = ball

	if _cue_ball == null:
		_result["valid"] = false
		_request_stop("missing_cue_ball", false)
		return
	if _cue_ball.velocity.length_squared() <= 0.0:
		_result["valid"] = false
		_request_stop("zero_launch_velocity", false)
		return
	_refresh_motion_membership()
	_update_motion_workload_samples()

	for ball in _balls:
		if ball.initial_unsupported_reason.is_empty():
			continue
		_result["valid"] = false
		_add_unsupported_warning(ball.initial_unsupported_reason, ball)
		_request_stop(ball.initial_unsupported_reason, false)
		_result["truncated"] = true
		return


func _run_simulation() -> void:
	var frame_rate: float = float(_config.get("simulation_frame_rate", 60))
	var substeps: int = int(_config.get("simulation_substeps", 4))
	var frame_delta: float = 1.0 / maxf(frame_rate, 1.0)
	var step_delta: float = frame_delta / float(maxi(substeps, 1))
	_current_step_delta = step_delta
	var max_frames: int = int(_config.get("max_physics_frames", 1200))
	var max_seconds: float = float(_config.get("max_simulated_seconds", 10.0))

	for frame_index in range(max_frames):
		_current_frame = frame_index
		for substep_index in range(substeps):
			_current_substep = substep_index
			_collision_events_this_substep = 0
			if _simulated_time >= max_seconds:
				_request_stop("max_simulated_seconds", true)
				break
			if not _consume_control_iteration("substep"):
				break
			_capture_substep_start_positions()
			_result["simulated_substeps"] = int(_result.get("simulated_substeps", 0)) + 1
			var handled_pairs: Dictionary = {}
			if _cue_toi_pending:
				handled_pairs = _move_with_cue_first_contact_toi(step_delta)
			else:
				_profile_move_active_balls(step_delta)
			if _stop_requested:
				break
			_refresh_motion_membership()
			_resolve_legacy_ball_contacts(handled_pairs)
			if _stop_requested:
				break
			_refresh_motion_membership()
			var rail_pocket_start_usec: int = _profile_begin_phase()
			var captured_pocket: bool = _resolve_first_pocket_capture()
			var should_resolve_surface_motion: bool = not captured_pocket and not _stop_requested
			if should_resolve_surface_motion:
				_resolve_rails()
			_profile_end_phase(PROFILE_RAIL_POCKET, rail_pocket_start_usec)
			var friction_start_usec: int = _profile_begin_phase()
			if should_resolve_surface_motion:
				_apply_friction(step_delta)
			_profile_end_phase(PROFILE_MOVEMENT, friction_start_usec)
			_refresh_motion_membership()
			var trace_start_usec: int = _profile_begin_phase()
			_record_all_trace_points()
			_profile_end_phase(PROFILE_TRACE, trace_start_usec)
			_update_motion_workload_samples()
			_simulated_time += step_delta
			if _all_balls_stopped_or_pocketed():
				_result["complete"] = true
				_request_stop("all_balls_stopped_or_pocketed", false)
				break
			# Authoritative Table physics ends the current frame's substep loop after
			# the first capture. Resume on the next simulated physics frame.
			if captured_pocket:
				break
			if _check_processing_budget():
				break
		if _stop_requested:
			break
		_result["simulated_physics_frames"] = frame_index + 1

	if not _stop_requested:
		_request_stop("max_physics_frames", true)


func _move_with_cue_first_contact_toi(step_delta: float) -> Dictionary:
	var handled_pairs: Dictionary = {}
	if _cue_ball == null or not _cue_ball.is_moving():
		_profile_move_active_balls(step_delta)
		return handled_pairs
	var remaining_time: float = step_delta
	var resolved_events: int = 0
	var remaining_time_iterations: int = 0
	var excluded_pairs: Dictionary = {}
	var collision_cap: int = int(_config.get("max_collision_events_per_substep", 16))
	while remaining_time > MIN_REMAINING_TIME and resolved_events < collision_cap:
		remaining_time_iterations += 1
		if remaining_time_iterations > EMERGENCY_MAX_REMAINING_TIME_ITERATIONS:
			_request_stop("max_remaining_time_iterations", true)
			return handled_pairs
		var remaining_fraction: float = (
			remaining_time / _current_step_delta
			if _current_step_delta > 0.0
			else -1.0
		)
		if not _consume_control_iteration(
			"remaining_time",
			_cue_ball,
			-1,
			EVENT_BALL_CONTACT,
			remaining_fraction
		):
			return handled_pairs
		var broadphase_start_usec: int = _profile_begin_phase()
		var swept_grid: Dictionary = _build_swept_grid(remaining_time)
		_broadphase_rebuilds += 1
		_swept_grid_rebuilds += 1
		_profile_broadphase_rebuilds += 1 if _profile_enabled else 0
		var candidates: Array[PredictionBall] = _get_swept_candidates(
			swept_grid,
			_cue_ball.position,
			_cue_ball.velocity * remaining_time,
			_cue_ball.radius
		)
		_profile_end_phase(PROFILE_BROADPHASE, broadphase_start_usec)
		var collision_start_usec: int = _profile_begin_phase()
		var earliest_hit: Dictionary = _get_earliest_cue_hit(candidates, remaining_time, excluded_pairs)
		_profile_end_phase(PROFILE_COLLISION, collision_start_usec)
		if earliest_hit.is_empty():
			break
		var cue_displacement: Vector2 = _cue_ball.velocity * remaining_time
		var hit_fraction: float = float(earliest_hit.get("hit_fraction", 1.0))
		var cross_type_start_usec: int = _profile_begin_phase()
		var cross_fraction: float = _get_earliest_cue_cross_type_fraction(cue_displacement)
		_profile_end_phase(PROFILE_RAIL_POCKET, cross_type_start_usec)
		if _stop_requested:
			return handled_pairs
		if cross_fraction >= 0.0 and cross_fraction <= hit_fraction + FRACTION_EPSILON:
			break
		var travel_time: float = remaining_time * clampf(hit_fraction, 0.0, 1.0)
		if travel_time > MIN_REMAINING_TIME:
			_profile_move_active_balls(travel_time)
			remaining_time = maxf(remaining_time - travel_time, 0.0)
		var target: PredictionBall = earliest_hit.get("ball") as PredictionBall
		if target == null:
			break
		var pair_key: String = _get_pair_key(_cue_ball, target)
		excluded_pairs[pair_key] = true
		var response_start_usec: int = _profile_begin_phase()
		if not _resolve_ball_contact(
			_cue_ball,
			target,
			earliest_hit.get("collision_normal", Vector2.RIGHT),
			"corrected_toi"
		):
			_profile_end_phase(PROFILE_COLLISION, response_start_usec)
			break
		_profile_end_phase(PROFILE_COLLISION, response_start_usec)
		handled_pairs[pair_key] = true
		_cue_toi_pending = false
		resolved_events += 1
		_refresh_motion_membership()
		if _stop_requested:
			return handled_pairs
	if resolved_events >= collision_cap and remaining_time > MIN_REMAINING_TIME:
		_request_stop("max_collision_events_per_substep", true)
		return handled_pairs
	if remaining_time > MIN_REMAINING_TIME:
		_profile_move_active_balls(remaining_time)
	return handled_pairs


func _move_active_balls(delta: float) -> void:
	if delta <= 0.0:
		return
	for ball in _moving_sources:
		if not ball.active or ball.pocketed or ball.velocity.length_squared() <= 0.0:
			continue
		ball.position += ball.velocity * delta


func _build_current_grid() -> Dictionary:
	var grid: Dictionary = {}
	_temporary_allocations += 1
	var cell_size: float = maxf(float(_constants.get("collision_grid_cell_size", 56.0)), 1.0)
	for ball in _balls:
		if not ball.active or ball.pocketed:
			continue
		if _profile_enabled and not ball.is_moving():
			_result["stopped_balls_included_in_broadphase"] = int(
				_result.get("stopped_balls_included_in_broadphase", 0)
			) + 1
		var cell: Vector2i = _get_grid_cell(ball.position, cell_size)
		if not grid.has(cell):
			grid[cell] = []
		var cell_balls: Array = grid[cell]
		cell_balls.append(ball)
		_result["maximum_broadphase_cell_size"] = maxi(
			int(_result.get("maximum_broadphase_cell_size", 0)),
			cell_balls.size()
		)
	_result["broadphase_cells"] = maxi(int(_result.get("broadphase_cells", 0)), grid.size())
	return grid


func _build_swept_grid(delta: float) -> Dictionary:
	var grid: Dictionary = {}
	_temporary_allocations += 1
	var cell_size: float = maxf(float(_constants.get("collision_grid_cell_size", 56.0)), 1.0)
	var collision_skin: float = float(_constants.get("ball_collision_skin", 1.5))
	for ball in _balls:
		if not ball.active or ball.pocketed:
			continue
		if _profile_enabled and not ball.is_moving():
			_result["stopped_balls_included_in_broadphase"] = int(
				_result.get("stopped_balls_included_in_broadphase", 0)
			) + 1
		var end_position: Vector2 = ball.position + ball.velocity * delta
		var margin: float = ball.radius + collision_skin
		_add_ball_to_grid_rect(
			grid,
			ball,
			Vector2(minf(ball.position.x, end_position.x) - margin, minf(ball.position.y, end_position.y) - margin),
			Vector2(maxf(ball.position.x, end_position.x) + margin, maxf(ball.position.y, end_position.y) + margin),
			cell_size
		)
	return grid


func _add_ball_to_grid_rect(
	grid: Dictionary,
	ball: PredictionBall,
	minimum_corner: Vector2,
	maximum_corner: Vector2,
	cell_size: float
) -> void:
	var minimum_cell: Vector2i = _get_grid_cell(minimum_corner, cell_size)
	var maximum_cell: Vector2i = _get_grid_cell(maximum_corner, cell_size)
	for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			if not grid.has(cell):
				grid[cell] = []
			var cell_balls: Array = grid[cell]
			cell_balls.append(ball)


func _get_swept_candidates(
	grid: Dictionary,
	start_position: Vector2,
	displacement: Vector2,
	radius: float
) -> Array[PredictionBall]:
	_swept_candidate_scratch.clear()
	_seen_candidate_ids_scratch.clear()
	_scratch_buffer_reuses += 2
	var cell_size: float = maxf(float(_constants.get("collision_grid_cell_size", 56.0)), 1.0)
	var end_position: Vector2 = start_position + displacement
	var minimum_corner: Vector2 = Vector2(
		minf(start_position.x, end_position.x) - radius,
		minf(start_position.y, end_position.y) - radius
	)
	var maximum_corner: Vector2 = Vector2(
		maxf(start_position.x, end_position.x) + radius,
		maxf(start_position.y, end_position.y) + radius
	)
	var minimum_cell: Vector2i = _get_grid_cell(minimum_corner, cell_size)
	var maximum_cell: Vector2i = _get_grid_cell(maximum_corner, cell_size)
	for cell_x in range(minimum_cell.x, maximum_cell.x + 1):
		for cell_y in range(minimum_cell.y, maximum_cell.y + 1):
			var cell: Vector2i = Vector2i(cell_x, cell_y)
			if not grid.has(cell):
				continue
			for candidate_value in grid[cell]:
				var candidate: PredictionBall = candidate_value as PredictionBall
				if (
					candidate == null
					or candidate == _cue_ball
					or _seen_candidate_ids_scratch.has(candidate.source_id)
				):
					continue
				_seen_candidate_ids_scratch[candidate.source_id] = true
				_swept_candidate_scratch.append(candidate)
	_swept_candidate_scratch.sort_custom(_sort_balls_by_source_index)
	return _swept_candidate_scratch


func _get_earliest_cue_hit(
	candidates: Array[PredictionBall],
	remaining_time: float,
	excluded_pairs: Dictionary
) -> Dictionary:
	var earliest_hit: Dictionary = {}
	var earliest_fraction: float = INF
	var earliest_number: int = 2147483647
	var earliest_id: int = 2147483647
	var cue_displacement: Vector2 = _cue_ball.velocity * remaining_time
	for target in candidates:
		if not target.active or target.pocketed:
			continue
		var pair_key: String = _get_pair_key(_cue_ball, target)
		if excluded_pairs.has(pair_key):
			continue
		_result["candidate_tests"] = int(_result.get("candidate_tests", 0)) + 1
		_result["swept_toi_solves"] = int(_result.get("swept_toi_solves", 0)) + 1
		var remaining_fraction: float = (
			remaining_time / _current_step_delta
			if _current_step_delta > 0.0
			else -1.0
		)
		if not _consume_geometry_probe(
			"cue_toi_candidate",
			target,
			-1,
			EVENT_BALL_CONTACT,
			remaining_fraction
		):
			return {}
		var sweep_result: Dictionary = BALL_SWEEP_MATH.sweep_circles(
			_cue_ball.position,
			cue_displacement,
			target.position,
			target.velocity * remaining_time,
			BALL_SWEEP_MATH.get_effective_collision_radius(
				_cue_ball.radius,
				target.radius,
				float(_constants.get("ball_collision_skin", 1.5))
			)
		)
		if not bool(sweep_result.get("hit", false)):
			continue
		var normal: Vector2 = sweep_result.get("collision_normal", Vector2.ZERO)
		if normal == Vector2.ZERO or BALL_COLLISION_MATH.get_impact_speed(
			_cue_ball.velocity,
			target.velocity,
			normal
		) <= 0.0:
			continue
		var hit_fraction: float = float(sweep_result.get("hit_fraction", 1.0))
		var is_earlier: bool = hit_fraction < earliest_fraction - TIE_EPSILON
		var is_tied: bool = absf(hit_fraction - earliest_fraction) <= TIE_EPSILON
		if not is_earlier and not (is_tied and target.ball_number < earliest_number):
			if not (is_tied and target.ball_number == earliest_number and target.source_id < earliest_id):
				continue
		earliest_fraction = hit_fraction
		earliest_number = target.ball_number
		earliest_id = target.source_id
		earliest_hit = sweep_result.duplicate(true)
		earliest_hit["ball"] = target
	return earliest_hit


func _get_earliest_cue_cross_type_fraction(cue_displacement: Vector2) -> float:
	var boundary_fraction: float = -1.0
	var pocket_fraction: float = -1.0
	if _boundary_system != null:
		var boundary_start_usec: int = _profile_begin_phase()
		var boundary_query_aabb: Rect2 = _make_swept_aabb(
			_cue_ball.position,
			_cue_ball.position + cue_displacement,
			_cue_ball.radius
		)
		var earliest_boundary_fraction: float = INF
		for boundary_geometry_index in range(_boundary_geometry.size()):
			var boundary_value: Variant = _boundary_geometry[boundary_geometry_index]
			if not boundary_value is Dictionary:
				continue
			var boundary_geometry: Dictionary = boundary_value
			var boundary_aabb: Rect2 = boundary_geometry.get("world_aabb", Rect2())
			if boundary_aabb.has_area() and not boundary_query_aabb.intersects(boundary_aabb, true):
				_result["rail_candidates_rejected_by_aabb"] = int(
					_result.get("rail_candidates_rejected_by_aabb", 0)
				) + 1
				continue
			if not _consume_geometry_probe(
				"rail_probe",
				_cue_ball,
				boundary_geometry_index,
				EVENT_RAIL_CONTACT
			):
				break
			_result["rail_swept_tests"] = int(_result.get("rail_swept_tests", 0)) + 1
			var hit_fraction: float = _boundary_system.get_conservative_motion_hit_fraction_against_geometry(
				boundary_geometry,
				_cue_ball.position,
				cue_displacement,
				_cue_ball.radius
			)
			if hit_fraction >= 0.0:
				earliest_boundary_fraction = minf(earliest_boundary_fraction, hit_fraction)
		boundary_fraction = -1.0 if earliest_boundary_fraction == INF else earliest_boundary_fraction
		_result["remaining_time_boundary_iterations"] = int(
			_result.get("remaining_time_boundary_iterations", 0)
		) + 1
		var boundary_elapsed_usec: int = (
			maxi(Time.get_ticks_usec() - boundary_start_usec, 0)
			if _profile_enabled
			else 0
		)
		_profile_add_elapsed(PROFILE_CUE_BOUNDARY_CHRONOLOGY, boundary_elapsed_usec)
		_profile_add_elapsed(PROFILE_RAIL_PROCESSING, boundary_elapsed_usec)
	if _pocket_system != null:
		var pocket_start_usec: int = _profile_begin_phase()
		var pocket_query_aabb: Rect2 = _make_swept_aabb(
			_cue_ball.position,
			_cue_ball.position + cue_displacement,
			0.0
		)
		var earliest_pocket_fraction: float = INF
		for pocket_geometry_index in range(_pocket_geometry.size()):
			var pocket_value: Variant = _pocket_geometry[pocket_geometry_index]
			if not pocket_value is Dictionary:
				continue
			var pocket_geometry: Dictionary = pocket_value
			var catch_radius: float = _pocket_system.get_capture_radius(
				float(pocket_geometry.get("radius", 0.0)),
				_cue_ball.radius
			)
			var pocket_position: Vector2 = pocket_geometry.get("position", Vector2.ZERO)
			var capture_aabb := Rect2(
				pocket_position - Vector2.ONE * catch_radius,
				Vector2.ONE * catch_radius * 2.0
			)
			if not pocket_query_aabb.intersects(capture_aabb, true):
				_result["pocket_candidates_rejected_by_aabb"] = int(
					_result.get("pocket_candidates_rejected_by_aabb", 0)
				) + 1
				continue
			if not _consume_geometry_probe(
				"pocket_probe",
				_cue_ball,
				pocket_geometry_index,
				EVENT_POCKET
			):
				break
			_result["pocket_swept_tests"] = int(_result.get("pocket_swept_tests", 0)) + 1
			var hit_fraction: float = _pocket_system.get_capture_fraction_against_geometry(
				pocket_geometry,
				_cue_ball.position,
				cue_displacement,
				_cue_ball.radius
			)
			if hit_fraction >= 0.0:
				earliest_pocket_fraction = minf(earliest_pocket_fraction, hit_fraction)
		pocket_fraction = -1.0 if earliest_pocket_fraction == INF else earliest_pocket_fraction
		var pocket_elapsed_usec: int = (
			maxi(Time.get_ticks_usec() - pocket_start_usec, 0)
			if _profile_enabled
			else 0
		)
		_profile_add_elapsed(PROFILE_CUE_POCKET_CHRONOLOGY, pocket_elapsed_usec)
		_profile_add_elapsed(PROFILE_POCKET_PROCESSING, pocket_elapsed_usec)
	var ordering_start_usec: int = _profile_begin_phase()
	if boundary_fraction < 0.0:
		_profile_end_phase(PROFILE_CROSS_TYPE_ORDERING, ordering_start_usec)
		return pocket_fraction
	if pocket_fraction < 0.0:
		_profile_end_phase(PROFILE_CROSS_TYPE_ORDERING, ordering_start_usec)
		return boundary_fraction
	var earliest_fraction: float = minf(boundary_fraction, pocket_fraction)
	_profile_end_phase(PROFILE_CROSS_TYPE_ORDERING, ordering_start_usec)
	return earliest_fraction


func _resolve_legacy_ball_contacts(handled_pairs: Dictionary) -> void:
	var broadphase_start_usec: int = _profile_begin_phase()
	var grid: Dictionary = _build_current_grid()
	_broadphase_rebuilds += 1
	_current_grid_rebuilds += 1
	_profile_broadphase_rebuilds += 1 if _profile_enabled else 0
	_profile_end_phase(PROFILE_BROADPHASE, broadphase_start_usec)
	var collision_start_usec: int = _profile_begin_phase()
	var checked_pairs: Dictionary = handled_pairs.duplicate()
	var cell_size: float = maxf(float(_constants.get("collision_grid_cell_size", 56.0)), 1.0)
	for ball in _moving_sources:
		if _stop_requested:
			_profile_end_phase(PROFILE_COLLISION, collision_start_usec)
			return
		if not ball.is_moving():
			continue
		var center_cell: Vector2i = _get_grid_cell(ball.position, cell_size)
		for x_offset in range(-1, 2):
			for y_offset in range(-1, 2):
				var neighbor_cell: Vector2i = center_cell + Vector2i(x_offset, y_offset)
				if not grid.has(neighbor_cell):
					continue
				for other_value in grid[neighbor_cell]:
					var other: PredictionBall = other_value as PredictionBall
					if other == null or other == ball:
						continue
					var pair_key: String = _get_pair_key(ball, other)
					if checked_pairs.has(pair_key):
						continue
					checked_pairs[pair_key] = true
					_result["candidate_tests"] = int(_result.get("candidate_tests", 0)) + 1
					_resolve_ball_pair_overlap(ball, other)
	_profile_end_phase(PROFILE_COLLISION, collision_start_usec)


func _resolve_ball_pair_overlap(ball_a: PredictionBall, ball_b: PredictionBall) -> bool:
	if not ball_a.active or not ball_b.active or ball_a.pocketed or ball_b.pocketed:
		return false
	_result["pair_checks"] = int(_result.get("pair_checks", 0)) + 1
	if not _consume_geometry_probe("legacy_pair", ball_a, -1, EVENT_BALL_CONTACT):
		return false
	var offset: Vector2 = ball_b.position - ball_a.position
	var distance: float = offset.length()
	var real_combined_radius: float = ball_a.radius + ball_b.radius
	var effective_radius: float = BALL_SWEEP_MATH.get_effective_collision_radius(
		ball_a.radius,
		ball_b.radius,
		float(_constants.get("ball_collision_skin", 1.5))
	)
	if distance >= effective_radius:
		return false
	var normal: Vector2 = Vector2.RIGHT if distance == 0.0 else offset / distance
	var overlap: float = maxf(real_combined_radius - distance, 0.0)
	if overlap > 0.0:
		var correction: Vector2 = normal * (overlap * 0.5 + 0.01)
		ball_a.position -= correction
		ball_b.position += correction
	return _resolve_ball_contact(ball_a, ball_b, normal, "legacy")


func _resolve_ball_contact(
	ball_a: PredictionBall,
	ball_b: PredictionBall,
	normal_value: Vector2,
	resolution_source: String
) -> bool:
	if _collision_events_this_substep >= int(_config.get("max_collision_events_per_substep", 16)):
		_request_stop("max_collision_events_per_substep", true)
		return false
	var normal: Vector2 = normal_value.normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.RIGHT
	var incoming_a: Vector2 = ball_a.velocity
	var incoming_b: Vector2 = ball_b.velocity
	var impact_speed: float = BALL_COLLISION_MATH.get_impact_speed(incoming_a, incoming_b, normal)
	if impact_speed <= 0.0:
		return false
	if int(_result.get("total_ball_contacts", 0)) >= int(_config.get("max_ball_contacts", 250)):
		_request_stop("max_ball_contacts", true)
		return false
	if (ball_a.is_cue or ball_b.is_cue) and int(_result.get("total_cue_ball_contacts", 0)) >= int(_config.get("max_cue_ball_contacts", 64)):
		_request_stop("max_cue_ball_contacts", true)
		return false

	var causal_source: PredictionBall = _choose_causal_source(ball_a, ball_b, incoming_a, incoming_b)
	var causal_target: PredictionBall = ball_b if causal_source == ball_a else ball_a
	var source_depth: int = causal_source.generation_depth
	if source_depth == UNREACHED_GENERATION:
		source_depth = 0
		causal_source.generation_depth = 0
	var target_depth: int = source_depth + 1
	var unsupported_reason: String = _get_contact_unsupported_reason(ball_a, ball_b)
	if target_depth > int(_config.get("max_child_generation_depth", 16)):
		unsupported_reason = "max_child_generation_depth"

	var impulse: Vector2 = BALL_COLLISION_MATH.get_normal_impulse(
		incoming_a,
		incoming_b,
		normal,
		float(_constants.get("ball_collision_restitution", 0.86)),
		float(_constants.get("ball_velocity_transfer", 0.90))
	)
	var outgoing_a: Vector2 = incoming_a
	var outgoing_b: Vector2 = incoming_b
	if unsupported_reason.is_empty():
		var response: Dictionary = _get_supported_contact_response(
			ball_a,
			ball_b,
			normal,
			incoming_a,
			incoming_b,
			impulse
		)
		outgoing_a = response.get("velocity_a", incoming_a)
		outgoing_b = response.get("velocity_b", incoming_b)
		ball_a.velocity = outgoing_a
		ball_b.velocity = outgoing_b

	var event: Dictionary = _make_ball_contact_event(
		ball_a,
		ball_b,
		causal_source,
		causal_target,
		normal,
		incoming_a,
		incoming_b,
		outgoing_a,
		outgoing_b,
		impact_speed,
		resolution_source,
		unsupported_reason
	)
	var event_index: int = _append_event(event)
	if event_index < 0:
		return false
	_collision_events_this_substep += 1
	_result["total_ball_contacts"] = int(_result.get("total_ball_contacts", 0)) + 1
	if ball_a.is_cue or ball_b.is_cue:
		_result["total_cue_ball_contacts"] = int(_result.get("total_cue_ball_contacts", 0)) + 1
	_note_first_event(ball_a, event_index)
	_note_first_event(ball_b, event_index)
	if target_depth < causal_target.generation_depth:
		causal_target.generation_depth = target_depth
		_maximum_causal_depth = maxi(_maximum_causal_depth, target_depth)
		causal_target.causal_root_ball_id = causal_source.causal_root_ball_id
		causal_target.parent_contact_event = event_index
		causal_target.parent_source_ball_id = causal_source.source_id
	_append_trace_point(ball_a, ball_a.position, true)
	_append_trace_point(ball_b, ball_b.position, true)

	if not unsupported_reason.is_empty():
		if unsupported_reason.begins_with("unsupported_"):
			_add_unsupported_warning(unsupported_reason, causal_target)
			_request_stop(unsupported_reason, false)
			_result["truncated"] = true
		else:
			_request_stop(unsupported_reason, true)
		return false
	return true


func _get_supported_contact_response(
	ball_a: PredictionBall,
	ball_b: PredictionBall,
	normal: Vector2,
	incoming_a: Vector2,
	incoming_b: Vector2,
	impulse: Vector2
) -> Dictionary:
	var velocity_a: Vector2 = incoming_a - impulse
	var velocity_b: Vector2 = incoming_b + impulse
	if not bool(_effect_snapshot.get(EFFECT_CANNON_WAKE_ENABLED, false)):
		return {"velocity_a": velocity_a, "velocity_b": velocity_b}

	var cue_to_target_normal: Vector2 = normal
	var base_cue_delta: Vector2 = Vector2.ZERO
	var base_target_delta: Vector2 = Vector2.ZERO
	if ball_a.is_cue and _is_cannon_wake_target(ball_b):
		base_cue_delta = -impulse
		base_target_delta = impulse
	elif ball_b.is_cue and _is_cannon_wake_target(ball_a):
		cue_to_target_normal = -normal
		base_cue_delta = impulse
		base_target_delta = -impulse
	else:
		return {"velocity_a": velocity_a, "velocity_b": velocity_b}

	var cue: PredictionBall = ball_a if ball_a.is_cue else ball_b
	var cue_incoming: Vector2 = incoming_a if ball_a.is_cue else incoming_b
	var target_incoming: Vector2 = incoming_b if ball_a.is_cue else incoming_a
	var cue_speed_toward_target: float = cue_incoming.dot(cue_to_target_normal)
	var target_speed_toward_cue: float = target_incoming.dot(cue_to_target_normal)
	if cue_speed_toward_target <= 0.0 or cue_speed_toward_target <= target_speed_toward_cue:
		return {"velocity_a": velocity_a, "velocity_b": velocity_b}
	var impact_multiplier: float = maxf(float(_effect_snapshot.get(EFFECT_CANNON_WAKE_IMPACT_MULTIPLIER, 1.35)), 1.0)
	var cue_retention: float = clampf(float(_effect_snapshot.get(EFFECT_CANNON_WAKE_CUE_RETENTION, 0.22)), 0.0, 0.85)
	var target_outgoing: Vector2 = target_incoming + base_target_delta * impact_multiplier
	var cue_normal_outgoing: Vector2 = cue_incoming + base_cue_delta
	var cue_outgoing: Vector2 = cue_normal_outgoing.lerp(cue_incoming, cue_retention)
	if cue == ball_a:
		return {"velocity_a": cue_outgoing, "velocity_b": target_outgoing}
	return {"velocity_a": target_outgoing, "velocity_b": cue_outgoing}


func _is_cannon_wake_target(ball: PredictionBall) -> bool:
	return (
		ball != null
		and not ball.is_cue
		and not ball.is_eight
		and ball.ball_type == 0
		and ball.anomaly_kind.is_empty()
	)


func _resolve_first_pocket_capture() -> bool:
	if _pocket_system == null:
		return false
	var pocket_total_start_usec: int = _profile_begin_phase()
	var candidate_start_usec: int = _profile_begin_phase()
	_pocket_candidates.clear()
	for candidate_ball in _moving_sources:
		if not candidate_ball.active or candidate_ball.pocketed:
			if _profile_enabled:
				_result["inactive_balls_skipped_from_loops"] = int(
					_result.get("inactive_balls_skipped_from_loops", 0)
				) + 1
			continue
		_pocket_candidates.append(candidate_ball)
	_profile_end_phase(PROFILE_POCKET_CANDIDATES, candidate_start_usec)

	for ball in _pocket_candidates:
		if _profile_enabled:
			_result["pocket_candidate_queries"] = int(
				_result.get("pocket_candidate_queries", 0)
			) + 1
			_result["cloned_balls_checked_against_pockets"] = int(
				_result.get("cloned_balls_checked_against_pockets", 0)
			) + 1
		var ball_swept_aabb: Rect2 = _make_swept_aabb(
			ball.step_start_position,
			ball.position,
			0.0
		)
		for pocket_geometry_index in range(_pocket_geometry.size()):
			var pocket_value: Variant = _pocket_geometry[pocket_geometry_index]
			if not pocket_value is Dictionary:
				continue
			var pocket: Dictionary = pocket_value
			var pocket_position: Vector2 = pocket.get("position", Vector2.ZERO)
			var catch_radius: float = _pocket_system.get_capture_radius(
				float(pocket.get("radius", 0.0)),
				ball.radius
			)
			var pocket_capture_aabb: Rect2 = Rect2(
				pocket_position - Vector2.ONE * catch_radius,
				Vector2.ONE * catch_radius * 2.0
			)
			if not ball_swept_aabb.intersects(pocket_capture_aabb, true):
				_result["pocket_candidates_rejected_by_aabb"] = int(
					_result.get("pocket_candidates_rejected_by_aabb", 0)
				) + 1
				continue
			if not _consume_geometry_probe(
				"pocket_probe",
				ball,
				pocket_geometry_index,
				EVENT_POCKET
			):
				_profile_end_phase(PROFILE_POCKET_OVERLAP, pocket_total_start_usec)
				_profile_end_phase(PROFILE_POCKET_PROCESSING, pocket_total_start_usec)
				return false
			if _profile_enabled:
				_result["pockets_tested"] = int(_result.get("pockets_tested", 0)) + 1
			var pocket_test_start_usec: int = _profile_begin_phase()
			var captured: bool = ball.position.distance_to(pocket_position) <= catch_radius
			_profile_end_phase(PROFILE_POCKET_TESTS, pocket_test_start_usec)
			if not captured:
				continue
			if int(_result.get("total_pocket_captures", 0)) >= int(_config.get("max_pocket_events", 64)):
				_request_stop("max_pocket_events", true)
				_profile_end_phase(PROFILE_POCKET_OVERLAP, pocket_total_start_usec)
				_profile_end_phase(PROFILE_POCKET_PROCESSING, pocket_total_start_usec)
				return false
			var resolution_start_usec: int = _profile_begin_phase()
			var incoming_velocity: Vector2 = ball.velocity
			ball.velocity = Vector2.ZERO
			ball.active = false
			ball.pocketed = true
			ball.final_stop_reason = "pocketed"
			_profile_end_phase(PROFILE_POCKET_RESOLUTION, resolution_start_usec)
			var packaging_start_usec: int = _profile_begin_phase()
			if _profile_enabled:
				_result["pocket_temporary_objects_created"] = int(
					_result.get("pocket_temporary_objects_created", 0)
				) + 1
			var event_index: int = _append_event({
				"event_type": EVENT_POCKET,
				"source_ball_id": ball.source_id,
				"source_ball_number": ball.ball_number,
				"source_ball_label": ball.label,
				"source_radius": ball.radius,
				"target_ball_id": -1,
				"target_ball_number": -1,
				"generation_depth": _safe_generation_depth(ball),
				"causal_root_ball_id": ball.causal_root_ball_id,
				"source_center": ball.position,
				"target_center": pocket_position,
				"contact_point": ball.position,
				"collision_normal": (ball.position - pocket_position).normalized(),
				"incoming_source_velocity": incoming_velocity,
				"incoming_target_velocity": Vector2.ZERO,
				"outgoing_source_velocity": Vector2.ZERO,
				"outgoing_target_velocity": Vector2.ZERO,
				"effective_collision_radius": catch_radius,
				"pocket_index": int(pocket.get("pocket_index", -1)),
				"supported": true,
			})
			if event_index >= 0:
				_result["total_pocket_captures"] = int(_result.get("total_pocket_captures", 0)) + 1
				_result["pocket_events_accepted"] = int(_result.get("pocket_events_accepted", 0)) + 1
				_note_first_event(ball, event_index)
				_append_trace_point(ball, ball.position, true)
			_profile_end_phase(PROFILE_POCKET_PACKAGING, packaging_start_usec)
			_profile_end_phase(PROFILE_POCKET_OVERLAP, pocket_total_start_usec)
			_profile_end_phase(PROFILE_POCKET_PROCESSING, pocket_total_start_usec)
			return true
	_profile_end_phase(PROFILE_POCKET_OVERLAP, pocket_total_start_usec)
	_profile_end_phase(PROFILE_POCKET_PROCESSING, pocket_total_start_usec)
	return false


func _resolve_rails() -> void:
	if _boundary_system == null:
		return
	var rail_total_start_usec: int = _profile_begin_phase()
	var candidate_start_usec: int = _profile_begin_phase()
	_boundary_candidates.clear()
	for candidate_ball in _moving_sources:
		if not candidate_ball.active or candidate_ball.pocketed:
			if _profile_enabled:
				_result["inactive_balls_skipped_from_loops"] = int(
					_result.get("inactive_balls_skipped_from_loops", 0)
				) + 1
			continue
		_boundary_candidates.append(candidate_ball)
	_profile_end_phase(PROFILE_BOUNDARY_CANDIDATES, candidate_start_usec)

	for ball in _boundary_candidates:
		if _profile_enabled:
			_result["rail_candidate_queries"] = int(
				_result.get("rail_candidate_queries", 0)
			) + 1
			_result["cloned_balls_checked_against_boundaries"] = int(
				_result.get("cloned_balls_checked_against_boundaries", 0)
			) + 1
		var state: MotionState = _motion_state_scratch
		_scratch_buffer_reuses += 1
		var valid_boundary_checks := 0
		var collision_skin: float = float(_constants.get("ball_collision_skin", 1.5))
		var ball_swept_aabb: Rect2 = _make_swept_aabb(
			ball.step_start_position,
			ball.position,
			ball.radius + collision_skin
		)
		for boundary_geometry_index in range(_boundary_geometry.size()):
			var boundary_value: Variant = _boundary_geometry[boundary_geometry_index]
			if not boundary_value is Dictionary:
				continue
			var boundary: Dictionary = boundary_value
			var boundary_aabb: Rect2 = boundary.get("world_aabb", Rect2())
			if boundary_aabb.has_area() and not ball_swept_aabb.intersects(boundary_aabb, true):
				_result["rail_candidates_rejected_by_aabb"] = int(
					_result.get("rail_candidates_rejected_by_aabb", 0)
				) + 1
				continue
			if _profile_enabled:
				if valid_boundary_checks > 0:
					_result["repeated_boundary_checks"] = int(
						_result.get("repeated_boundary_checks", 0)
					) + 1
				valid_boundary_checks += 1
			if not _consume_geometry_probe(
				"rail_probe",
				ball,
				boundary_geometry_index,
				EVENT_RAIL_CONTACT
			):
				_profile_end_phase(PROFILE_RAIL_OVERLAP, rail_total_start_usec)
				_profile_end_phase(PROFILE_RAIL_PROCESSING, rail_total_start_usec)
				return
			state.position = ball.position
			state.velocity = ball.velocity
			state.rail_position = Vector2.ZERO
			state.rail_normal = Vector2.ZERO
			state.hit_rail = false
			var incoming_velocity: Vector2 = ball.velocity
			var boundary_test_elapsed_usec := 0
			var boundary_response_elapsed_usec := 0
			if _profile_enabled:
				_boundary_profile_timings.clear()
				_boundary_system.resolve_motion_state_against_geometry(
					state,
					boundary,
					ball.radius,
					float(_constants.get("rail_restitution", 0.78)),
					_boundary_profile_timings
				)
				boundary_test_elapsed_usec = int(_boundary_profile_timings.get("test_usec", 0))
				boundary_response_elapsed_usec = int(
					_boundary_profile_timings.get("response_usec", 0)
				)
			else:
				_boundary_system.resolve_motion_state_against_geometry(
					state,
					boundary,
					ball.radius,
					float(_constants.get("rail_restitution", 0.78))
				)
			if _profile_enabled:
				var boundary_kind: String = str(boundary.get("boundary_kind", "rail"))
				if boundary_kind == "jaw":
					_result["jaw_shapes_tested"] = int(
						_result.get("jaw_shapes_tested", 0)
					) + 1
					_profile_add_elapsed(PROFILE_JAW_TESTS, boundary_test_elapsed_usec)
				else:
					_result["rail_shapes_tested"] = int(
						_result.get("rail_shapes_tested", 0)
					) + 1
					_profile_add_elapsed(PROFILE_RAIL_TESTS, boundary_test_elapsed_usec)
			ball.position = state.position
			ball.velocity = state.velocity
			if not state.hit_rail:
				continue
			if _profile_enabled:
				_profile_add_elapsed(PROFILE_RAIL_RESPONSE, boundary_response_elapsed_usec)
			if int(_result.get("total_rail_contacts", 0)) >= int(_config.get("max_rail_contacts", 250)):
				_request_stop("max_rail_contacts", true)
				_profile_end_phase(PROFILE_RAIL_OVERLAP, rail_total_start_usec)
				_profile_end_phase(PROFILE_RAIL_PROCESSING, rail_total_start_usec)
				return
			var packaging_start_usec: int = _profile_begin_phase()
			if _profile_enabled:
				_result["boundary_temporary_objects_created"] = int(
					_result.get("boundary_temporary_objects_created", 0)
				) + 1
			var event_index: int = _append_event({
				"event_type": EVENT_RAIL_CONTACT,
				"source_ball_id": ball.source_id,
				"source_ball_number": ball.ball_number,
				"source_ball_label": ball.label,
				"source_radius": ball.radius,
				"target_ball_id": -1,
				"target_ball_number": -1,
				"generation_depth": _safe_generation_depth(ball),
				"causal_root_ball_id": ball.causal_root_ball_id,
				"source_center": ball.position,
				"target_center": state.rail_position,
				"contact_point": state.rail_position,
				"collision_normal": state.rail_normal,
				"incoming_source_velocity": incoming_velocity,
				"incoming_target_velocity": Vector2.ZERO,
				"outgoing_source_velocity": ball.velocity,
				"outgoing_target_velocity": Vector2.ZERO,
				"effective_collision_radius": ball.radius,
				"rail_index": int(boundary.get("boundary_index", -1)),
				"rail_name": str(boundary.get("boundary_name", "Rail")),
				"supported": true,
			})
			if event_index >= 0:
				_result["total_rail_contacts"] = int(_result.get("total_rail_contacts", 0)) + 1
				_result["rail_events_accepted"] = int(_result.get("rail_events_accepted", 0)) + 1
				_note_first_event(ball, event_index)
				_append_trace_point(ball, ball.position, true)
			_profile_end_phase(PROFILE_BOUNDARY_PACKAGING, packaging_start_usec)
			if _stop_requested:
				_profile_end_phase(PROFILE_RAIL_OVERLAP, rail_total_start_usec)
				_profile_end_phase(PROFILE_RAIL_PROCESSING, rail_total_start_usec)
				return
	_profile_end_phase(PROFILE_RAIL_OVERLAP, rail_total_start_usec)
	_profile_end_phase(PROFILE_RAIL_PROCESSING, rail_total_start_usec)


func _apply_friction(delta: float) -> void:
	for ball in _moving_sources:
		if not ball.active or ball.pocketed:
			continue
		var incoming_velocity: Vector2 = ball.velocity
		if incoming_velocity.length_squared() <= 0.0:
			continue
		ball.velocity = BALL_MOTION_MATH.apply_friction(ball.velocity, delta, ball.motion_parameters)
		if ball.velocity != Vector2.ZERO:
			continue
		_result["balls_newly_stopped"] = int(_result.get("balls_newly_stopped", 0)) + 1
		ball.final_stop_reason = "friction_stop"
		var event_index: int = _append_event({
			"event_type": EVENT_STOPPED,
			"source_ball_id": ball.source_id,
			"source_ball_number": ball.ball_number,
			"source_ball_label": ball.label,
			"source_radius": ball.radius,
			"target_ball_id": -1,
			"target_ball_number": -1,
			"generation_depth": _safe_generation_depth(ball),
			"causal_root_ball_id": ball.causal_root_ball_id,
			"source_center": ball.position,
			"target_center": Vector2.ZERO,
			"contact_point": ball.position,
			"collision_normal": Vector2.ZERO,
			"incoming_source_velocity": incoming_velocity,
			"incoming_target_velocity": Vector2.ZERO,
			"outgoing_source_velocity": Vector2.ZERO,
			"outgoing_target_velocity": Vector2.ZERO,
			"effective_collision_radius": ball.radius,
			"supported": true,
		})
		if event_index >= 0:
			_result["total_stops"] = int(_result.get("total_stops", 0)) + 1
			_note_first_event(ball, event_index)
			_append_trace_point(ball, ball.position, true)
		if _stop_requested:
			return


func _record_all_trace_points() -> void:
	for ball in _moving_sources:
		if ball.active and not ball.pocketed and ball.velocity.length_squared() > 0.0:
			_append_trace_point(ball, ball.position, false)


func _append_trace_point(ball: PredictionBall, position: Vector2, force: bool) -> void:
	_raw_trace_points_generated += 1
	if _stop_requested and not force:
		return
	if ball.trace.size() >= int(_config.get("max_points_per_ball", 2500)):
		_request_stop("max_points_per_ball", true)
		if not force or _get_result_detail_mode() == RESULT_MODE_FULL_DEBUG:
			return
	if _total_trace_points >= int(_config.get("max_total_trace_points", 50000)):
		_request_stop("max_total_trace_points", true)
		if not force or _get_result_detail_mode() == RESULT_MODE_FULL_DEBUG:
			return
	if not ball.trace.is_empty():
		var spacing: float = _get_active_trace_spacing()
		if not force and ball.trace[ball.trace.size() - 1].distance_to(position) < spacing:
			return
		if ball.trace[ball.trace.size() - 1].is_equal_approx(position):
			if force and not ball.trace_protected.is_empty():
				ball.trace_protected[ball.trace_protected.size() - 1] = true
			return
	ball.trace.append(position)
	ball.trace_protected.append(force)
	_total_trace_points += 1


func _get_active_trace_spacing() -> float:
	if _get_result_detail_mode() == RESULT_MODE_FULL_DEBUG:
		return float(_config.get("trace_point_spacing", 2.0))
	return float(_config.get("player_trace_spacing", 10.0))


func _prepare_player_result_traces() -> void:
	for ball in _balls:
		_append_terminal_trace_point(ball)
	if _get_result_detail_mode() == RESULT_MODE_FULL_DEBUG:
		return

	for ball in _balls:
		_simplify_ball_trace(ball)


func _append_terminal_trace_point(ball: PredictionBall) -> void:
	if ball == null or ball.trace.is_empty():
		return
	if ball.trace[ball.trace.size() - 1].is_equal_approx(ball.position):
		ball.trace_protected[ball.trace_protected.size() - 1] = true
		return
	ball.trace.append(ball.position)
	ball.trace_protected.append(true)
	_total_trace_points += 1
	_raw_trace_points_generated += 1


func _simplify_ball_trace(ball: PredictionBall) -> void:
	if ball.trace.size() <= 2:
		return
	var simplified_points: Array[Vector2] = [ball.trace[0]]
	var simplified_protected: Array[bool] = [true]
	for point_index in range(1, ball.trace.size() - 1):
		var point_is_protected: bool = bool(ball.trace_protected[point_index])
		var previous_point: Vector2 = simplified_points[simplified_points.size() - 1]
		var point: Vector2 = ball.trace[point_index]
		var next_point: Vector2 = ball.trace[point_index + 1]
		if not point_is_protected and _is_redundant_collinear_point(previous_point, point, next_point):
			_trace_points_removed_by_simplification += 1
			continue
		simplified_points.append(point)
		simplified_protected.append(point_is_protected)
	simplified_points.append(ball.trace[ball.trace.size() - 1])
	simplified_protected.append(true)
	ball.trace = simplified_points
	ball.trace_protected = simplified_protected


func _is_redundant_collinear_point(previous_point: Vector2, point: Vector2, next_point: Vector2) -> bool:
	var incoming: Vector2 = point - previous_point
	var outgoing: Vector2 = next_point - point
	if incoming.length_squared() <= 0.001 or outgoing.length_squared() <= 0.001:
		return true
	var incoming_direction: Vector2 = incoming.normalized()
	var outgoing_direction: Vector2 = outgoing.normalized()
	var minimum_dot: float = cos(deg_to_rad(PLAYER_TRACE_COLLINEAR_ANGLE_DEGREES))
	if incoming_direction.dot(outgoing_direction) < minimum_dot:
		return false
	var combined: Vector2 = next_point - previous_point
	if combined.length_squared() <= 0.001:
		return false
	var projection: float = clampf(
		(point - previous_point).dot(combined) / combined.length_squared(),
		0.0,
		1.0
	)
	var closest_point: Vector2 = previous_point + combined * projection
	return point.distance_to(closest_point) <= PLAYER_TRACE_COLLINEAR_DISTANCE_EPSILON


func _append_event(event: Dictionary) -> int:
	var events: Array = _result.get("events", [])
	if events.size() >= int(_config.get("max_total_events", 500)):
		_request_stop("max_total_events", true)
		return -1
	var event_index: int = events.size()
	event["event_index"] = event_index
	event["simulated_time"] = _simulated_time
	event["physics_frame"] = _current_frame
	event["substep"] = _current_substep
	events.append(_compact_event_for_result(event))
	_result["events"] = events
	_result["total_events"] = events.size()
	return event_index


func _compact_event_for_result(event: Dictionary) -> Dictionary:
	var result_mode: String = _get_result_detail_mode()
	if result_mode == RESULT_MODE_FULL_DEBUG:
		return event

	var compact: Dictionary = {}
	var minimal_fields: Array[String] = [
		"event_type",
		"event_index",
		"simulated_time",
		"physics_frame",
		"substep",
		"source_ball_id",
		"source_ball_number",
		"target_ball_id",
		"target_ball_number",
		"generation_depth",
		"causal_root_ball_id",
		"contact_point",
		"source_radius",
		"target_radius",
		"source_center",
		"target_center",
		"pocket_index",
		"rail_index",
		"supported",
		"unsupported_reason",
	]
	_copy_event_fields(event, compact, minimal_fields)
	if result_mode == RESULT_MODE_PLAYER_EXTENDED:
		var extended_fields: Array[String] = [
			"source_ball_label",
			"target_ball_label",
			"source_radius",
			"target_radius",
			"source_center",
			"target_center",
			"source_parent_contact_event",
			"collision_normal",
			"incoming_source_velocity",
			"incoming_target_velocity",
			"outgoing_source_velocity",
			"outgoing_target_velocity",
			"effective_collision_radius",
			"impact_speed",
			"resolution_source",
			"rail_name",
		]
		_copy_event_fields(event, compact, extended_fields)
	return compact


func _copy_event_fields(source: Dictionary, target: Dictionary, fields: Array[String]) -> void:
	for field in fields:
		if source.has(field):
			target[field] = source[field]


func _make_ball_contact_event(
	ball_a: PredictionBall,
	ball_b: PredictionBall,
	causal_source: PredictionBall,
	causal_target: PredictionBall,
	normal_a_to_b: Vector2,
	incoming_a: Vector2,
	incoming_b: Vector2,
	outgoing_a: Vector2,
	outgoing_b: Vector2,
	impact_speed: float,
	resolution_source: String,
	unsupported_reason: String
) -> Dictionary:
	var source_is_a: bool = causal_source == ball_a
	var source_normal: Vector2 = normal_a_to_b if source_is_a else -normal_a_to_b
	var source_incoming: Vector2 = incoming_a if source_is_a else incoming_b
	var target_incoming: Vector2 = incoming_b if source_is_a else incoming_a
	var source_outgoing: Vector2 = outgoing_a if source_is_a else outgoing_b
	var target_outgoing: Vector2 = outgoing_b if source_is_a else outgoing_a
	return {
		"event_type": EVENT_BALL_CONTACT,
		"source_ball_id": causal_source.source_id,
		"source_ball_number": causal_source.ball_number,
		"source_ball_label": causal_source.label,
		"source_radius": causal_source.radius,
		"target_ball_id": causal_target.source_id,
		"target_ball_number": causal_target.ball_number,
		"target_ball_label": causal_target.label,
		"target_radius": causal_target.radius,
		"generation_depth": _safe_generation_depth(causal_source) + 1,
		"causal_root_ball_id": causal_source.causal_root_ball_id,
		"source_parent_contact_event": causal_source.parent_contact_event,
		"source_center": causal_source.position,
		"target_center": causal_target.position,
		"contact_point": causal_source.position + source_normal * causal_source.radius,
		"collision_normal": source_normal,
		"incoming_source_velocity": source_incoming,
		"incoming_target_velocity": target_incoming,
		"outgoing_source_velocity": source_outgoing,
		"outgoing_target_velocity": target_outgoing,
		"effective_collision_radius": BALL_SWEEP_MATH.get_effective_collision_radius(
			ball_a.radius,
			ball_b.radius,
			float(_constants.get("ball_collision_skin", 1.5))
		),
		"impact_speed": impact_speed,
		"resolution_source": resolution_source,
		"supported": unsupported_reason.is_empty(),
		"unsupported_reason": unsupported_reason,
	}


func _choose_causal_source(
	ball_a: PredictionBall,
	ball_b: PredictionBall,
	incoming_a: Vector2,
	incoming_b: Vector2
) -> PredictionBall:
	if ball_a.is_cue != ball_b.is_cue:
		return ball_a if ball_a.is_cue else ball_b
	var speed_a: float = incoming_a.length_squared()
	var speed_b: float = incoming_b.length_squared()
	if not is_equal_approx(speed_a, speed_b):
		return ball_a if speed_a > speed_b else ball_b
	return ball_a if ball_a.source_index <= ball_b.source_index else ball_b


func _get_contact_unsupported_reason(ball_a: PredictionBall, ball_b: PredictionBall) -> String:
	for ball in [ball_a, ball_b]:
		match ball.anomaly_kind:
			"powder_keg":
				return "unsupported_powder_keg_explosion"
			"wayfinder":
				return "unsupported_wayfinder_guidance"
			"anchor":
				return "unsupported_anchor_constraint"
			"cannon":
				return "unsupported_cannon_response"
			"treasure":
				return "unsupported_treasure_self_motion"
			"embezzler":
				return "unsupported_embezzler_behavior"
	return ""


func _add_unsupported_warning(reason: String, ball: PredictionBall) -> void:
	var warnings: Array = _result.get("unsupported_warnings", [])
	var warning: Dictionary = {
		"reason": reason,
		"ball_id": ball.source_id if ball != null else -1,
		"ball_number": ball.ball_number if ball != null else -1,
		"ball_label": ball.label if ball != null else "Unknown",
		"position": ball.position if ball != null else Vector2.ZERO,
	}
	if not warnings.has(warning):
		warnings.append(warning)
	_result["unsupported_warnings"] = warnings


func _note_first_event(ball: PredictionBall, event_index: int) -> void:
	if ball.first_movement_event < 0:
		ball.first_movement_event = event_index


func _capture_substep_start_positions() -> void:
	for ball in _balls:
		ball.step_start_position = ball.position


func _refresh_motion_membership() -> void:
	_moving_sources.clear()
	_stationary_targets.clear()
	_scratch_buffer_reuses += 2
	for ball in _balls:
		if not ball.active or ball.pocketed:
			continue
		# Preserve the prior simulation semantics: friction owns the transition to
		# an exact stop, so even sub-threshold nonzero motion remains a source.
		if ball.velocity.length_squared() > 0.0:
			_moving_sources.append(ball)
		else:
			_stationary_targets.append(ball)


func _make_swept_aabb(start_position: Vector2, end_position: Vector2, margin: float) -> Rect2:
	var minimum_corner: Vector2 = Vector2(
		minf(start_position.x, end_position.x) - margin,
		minf(start_position.y, end_position.y) - margin
	)
	var maximum_corner: Vector2 = Vector2(
		maxf(start_position.x, end_position.x) + margin,
		maxf(start_position.y, end_position.y) + margin
	)
	return Rect2(minimum_corner, maximum_corner - minimum_corner)


func _all_balls_stopped_or_pocketed() -> bool:
	return _moving_sources.is_empty()


func _update_motion_workload_samples() -> void:
	var moving_count: int = _moving_sources.size()
	var stationary_count: int = _stationary_targets.size()
	_maximum_simultaneously_moving_balls = maxi(
		_maximum_simultaneously_moving_balls,
		moving_count
	)
	_maximum_stationary_targets = maxi(_maximum_stationary_targets, stationary_count)
	_moving_ball_sample_total += moving_count
	_moving_ball_sample_count += 1
	_stationary_ball_sample_total += stationary_count
	_stationary_ball_sample_count += 1


func _consume_control_iteration(
	source: String,
	ball: PredictionBall = null,
	geometry_index: int = -1,
	event_type: String = "none",
	remaining_time_fraction: float = -1.0,
	count: int = 1
) -> bool:
	_set_last_work_context(
		source,
		ball,
		geometry_index,
		event_type,
		remaining_time_fraction
	)
	_increment_iteration_source(source, count, false)
	_total_iterations += count
	if _total_iterations > EMERGENCY_MAX_ITERATIONS:
		_request_stop("emergency_control_watchdog", true)
		return false
	var configured_limit: int = int(_config.get("max_total_iterations", 25000))
	if _total_iterations > configured_limit:
		_capture_iteration_cap_detail(configured_limit)
		_request_stop("max_total_iterations", true)
		return false
	if _total_iterations % 128 == 0 and _check_processing_budget():
		return false

	_increment_iteration_source(source, count, true)
	return true


func _consume_geometry_probe(
	source: String,
	ball: PredictionBall = null,
	geometry_index: int = -1,
	event_type: String = "none",
	remaining_time_fraction: float = -1.0,
	count: int = 1
) -> bool:
	_set_last_work_context(
		source,
		ball,
		geometry_index,
		event_type,
		remaining_time_fraction
	)
	_increment_iteration_source(source, count, false)
	_geometry_probes += count
	if _geometry_probes > EMERGENCY_MAX_GEOMETRY_PROBES:
		_request_stop("emergency_geometry_watchdog", true)
		return false
	var configured_limit: int = int(_config.get("max_geometry_probes", 500000))
	if _geometry_probes > configured_limit:
		_capture_geometry_probe_cap_detail(configured_limit)
		_request_stop("max_geometry_probes", true)
		return false
	if _geometry_probes % 2048 == 0 and _check_processing_budget():
		return false

	_increment_iteration_source(source, count, true)
	return true


func _set_last_work_context(
	source: String,
	ball: PredictionBall,
	geometry_index: int,
	event_type: String,
	remaining_time_fraction: float
) -> void:
	_last_iteration_source = source
	_last_iteration_ball_id = ball.source_id if ball != null else -1
	_last_iteration_ball_label = ball.label if ball != null else "none"
	_last_iteration_geometry_index = geometry_index
	_last_iteration_event_type = event_type
	_last_iteration_remaining_fraction = remaining_time_fraction



func _increment_iteration_source(source: String, count: int, completed: bool) -> void:
	match source:
		"substep":
			if completed:
				_iteration_substep_completed += count
			else:
				_iteration_substep_attempts += count
		"remaining_time":
			if completed:
				_iteration_remaining_time_completed += count
			else:
				_iteration_remaining_time_attempts += count
		"cue_toi_candidate":
			if completed:
				_iteration_cue_toi_completed += count
			else:
				_iteration_cue_toi_attempts += count
		"legacy_pair":
			if completed:
				_iteration_legacy_pair_completed += count
			else:
				_iteration_legacy_pair_attempts += count
		"rail_probe":
			if completed:
				_iteration_rail_probe_completed += count
			else:
				_iteration_rail_probe_attempts += count
		"pocket_probe":
			if completed:
				_iteration_pocket_probe_completed += count
			else:
				_iteration_pocket_probe_attempts += count
		_:
			if completed:
				_iteration_other_completed += count
			else:
				_iteration_other_attempts += count


func _make_iteration_source_counts(completed: bool) -> Dictionary:
	return {
		"substep": _iteration_substep_completed if completed else _iteration_substep_attempts,
		"remaining_time": _iteration_remaining_time_completed if completed else _iteration_remaining_time_attempts,
		"cue_toi_candidate": _iteration_cue_toi_completed if completed else _iteration_cue_toi_attempts,
		"legacy_pair": _iteration_legacy_pair_completed if completed else _iteration_legacy_pair_attempts,
		"rail_probe": _iteration_rail_probe_completed if completed else _iteration_rail_probe_attempts,
		"pocket_probe": _iteration_pocket_probe_completed if completed else _iteration_pocket_probe_attempts,
		"other": _iteration_other_completed if completed else _iteration_other_attempts,
	}


func _make_iteration_breakdown(completed: bool) -> Dictionary:
	var substeps: int = _iteration_substep_completed if completed else _iteration_substep_attempts
	var pair_collision: int = (
		_iteration_cue_toi_completed + _iteration_legacy_pair_completed
		if completed
		else _iteration_cue_toi_attempts + _iteration_legacy_pair_attempts
	)
	return {
		"frames": 0,
		"substeps": substeps,
		"ball_movement": 0,
		"pair_collision": pair_collision,
		"boundaries": _iteration_rail_probe_completed if completed else _iteration_rail_probe_attempts,
		"pockets": _iteration_pocket_probe_completed if completed else _iteration_pocket_probe_attempts,
		"remaining_time": _iteration_remaining_time_completed if completed else _iteration_remaining_time_attempts,
		"broadphase": 0,
		"event_loop": 0,
		"trace": 0,
		"other": _iteration_other_completed if completed else _iteration_other_attempts,
	}


func _capture_iteration_cap_detail(configured_limit: int) -> void:
	var existing_detail: Dictionary = _result.get("iteration_cap_detail", {})
	if not existing_detail.is_empty():
		return
	var moving_ball_count := 0
	var active_ball_count := 0
	var all_balls_nearly_stopped := true
	for prediction_ball in _balls:
		if not prediction_ball.active or prediction_ball.pocketed:
			continue
		active_ball_count += 1
		var speed: float = prediction_ball.velocity.length()
		var stop_threshold: float = float(prediction_ball.motion_parameters.get("stop_threshold", 4.0))
		if speed >= stop_threshold:
			moving_ball_count += 1
		if speed > stop_threshold * 2.0:
			all_balls_nearly_stopped = false
	var events_value: Variant = _result.get("events", [])
	var retained_event_count: int = events_value.size() if events_value is Array else 0
	_result["iteration_cap_detail"] = {
		"configured_limit": configured_limit,
		"first_trigger_total": _total_iterations,
		"final_total": _total_iterations,
		"overshoot": maxi(_total_iterations - configured_limit, 0),
		"phase_active": _last_iteration_source,
		"simulated_time": _simulated_time,
		"frame_index": _current_frame,
		"substep_index": _current_substep,
		"simulated_frames": int(_result.get("simulated_physics_frames", 0)),
		"simulated_substeps": int(_result.get("simulated_substeps", 0)),
		"active_ball_count": active_ball_count,
		"moving_ball_count": moving_ball_count,
		"last_processed_ball_id": _last_iteration_ball_id,
		"last_processed_ball": _last_iteration_ball_label,
		"last_geometry_index": _last_iteration_geometry_index,
		"last_event_type": _last_iteration_event_type,
		"remaining_time_fraction": _last_iteration_remaining_fraction,
		"all_balls_nearly_stopped": all_balls_nearly_stopped,
		"causal_depth_reached": _maximum_causal_depth,
		"trace_points_retained": _get_current_trace_point_count(),
		"predicted_events_retained": retained_event_count,
		"iteration_breakdown": _make_iteration_breakdown(false),
		"iteration_source_attempts": _make_iteration_source_counts(false),
	}


func _capture_geometry_probe_cap_detail(configured_limit: int) -> void:
	var existing_detail: Dictionary = _result.get("geometry_probe_cap_detail", {})
	if not existing_detail.is_empty():
		return
	_result["geometry_probe_cap_detail"] = {
		"configured_limit": configured_limit,
		"first_trigger_total": _geometry_probes,
		"overshoot": maxi(_geometry_probes - configured_limit, 0),
		"phase_active": _last_iteration_source,
		"simulated_time": _simulated_time,
		"frame_index": _current_frame,
		"substep_index": _current_substep,
		"last_processed_ball_id": _last_iteration_ball_id,
		"last_processed_ball": _last_iteration_ball_label,
		"last_geometry_index": _last_iteration_geometry_index,
		"last_event_type": _last_iteration_event_type,
		"geometry_probe_attempts": _make_iteration_source_counts(false),
	}


func _get_current_trace_point_count() -> int:
	var point_count := 0
	for ball in _balls:
		point_count += ball.trace.size()
	return point_count


func _check_processing_budget() -> bool:
	var processing_ms: float = _elapsed_processing_ms()
	if processing_ms > EMERGENCY_MAX_PROCESSING_MS:
		_request_stop("emergency_watchdog", true)
		return true
	if processing_ms > float(_config.get("max_processing_time_ms", 250.0)):
		_request_stop("max_processing_time_ms", true)
		return true
	return false


func _request_stop(reason: String, truncated: bool) -> void:
	if _stop_requested:
		return
	_stop_requested = true
	_result["stop_reason"] = reason
	_result["truncated"] = truncated
	if truncated:
		_result["cap_reached"] = reason


func _finalize_result() -> void:
	_result["total_iterations"] = _total_iterations
	_result["geometry_probes"] = _geometry_probes
	_result["iteration_breakdown"] = _make_iteration_breakdown(false)
	_result["completed_iteration_breakdown"] = _make_iteration_breakdown(true)
	_result["iteration_source_attempts"] = _make_iteration_source_counts(false)
	_result["iteration_source_completed"] = _make_iteration_source_counts(true)
	_result["elapsed_simulated_time"] = _simulated_time
	var traced_balls: int = 0
	var retained_trace_points: int = 0
	var retained_events: Array = _result.get("events", [])
	var ball_results: Array = []
	for ball in _balls:
		if ball.trace.size() > 1:
			traced_balls += 1
		retained_trace_points += ball.trace.size()
		if ball.final_stop_reason == "active":
			if ball.pocketed:
				ball.final_stop_reason = "pocketed"
			elif ball.velocity == Vector2.ZERO:
				ball.final_stop_reason = "stopped"
			elif _stop_requested:
				ball.final_stop_reason = str(_result.get("stop_reason", "truncated"))
		ball_results.append(_make_ball_result(ball))
	_result["balls"] = ball_results
	_result["total_traced_balls"] = traced_balls
	_result["total_trace_points"] = retained_trace_points
	_result["retained_trace_points"] = retained_trace_points
	_result["raw_trace_points_generated"] = _raw_trace_points_generated
	var total_removed_points: int = maxi(_raw_trace_points_generated - retained_trace_points, 0)
	var spacing_or_duplicate_removals: int = maxi(
		total_removed_points - _trace_points_removed_by_simplification,
		0
	)
	_result["trace_points_removed_by_simplification"] = total_removed_points
	_result["trace_points_removed_by_spacing_or_duplicates"] = spacing_or_duplicate_removals
	_result["trace_points_removed_by_collinear_simplification"] = (
		_trace_points_removed_by_simplification
	)
	_result["trace_simplification_percent"] = (
		100.0 * float(total_removed_points) / float(_raw_trace_points_generated)
		if _raw_trace_points_generated > 0
		else 0.0
	)
	_result["broadphase_rebuilds"] = _broadphase_rebuilds
	_result["full_broadphase_rebuilds"] = _broadphase_rebuilds
	_result["incremental_broadphase_updates"] = 0
	_result["current_grid_rebuilds"] = _current_grid_rebuilds
	_result["swept_grid_rebuilds"] = _swept_grid_rebuilds
	_result["maximum_simultaneously_moving_balls"] = _maximum_simultaneously_moving_balls
	_result["moving_balls_per_substep_maximum"] = _maximum_simultaneously_moving_balls
	_result["moving_balls_per_substep_average"] = (
		float(_moving_ball_sample_total) / float(_moving_ball_sample_count)
		if _moving_ball_sample_count > 0
		else 0.0
	)
	_result["stationary_targets_per_substep_maximum"] = _maximum_stationary_targets
	_result["stationary_targets_per_substep_average"] = (
		float(_stationary_ball_sample_total) / float(_stationary_ball_sample_count)
		if _stationary_ball_sample_count > 0
		else 0.0
	)
	_result["static_geometry_cache_hits"] = _static_geometry_cache_hits
	_result["static_geometry_cache_rebuilds"] = _static_geometry_cache_rebuilds
	_result["scratch_buffer_reuses"] = _scratch_buffer_reuses
	_result["temporary_allocations"] = _temporary_allocations
	_result["maximum_causal_depth"] = _maximum_causal_depth
	_result["predicted_events_retained"] = retained_events.size()
	_result["debug_events_retained"] = (
		retained_events.size()
		if _get_result_detail_mode() == RESULT_MODE_FULL_DEBUG
		else 0
	)
	_result["result_memory_estimate_bytes"] = _estimate_result_memory_bytes(
		retained_trace_points,
		retained_events.size(),
		ball_results.size()
	)
	_result["simulated_physics_frames"] = maxi(
		int(_result.get("simulated_physics_frames", 0)),
		_current_frame + (1 if int(_result.get("simulated_substeps", 0)) > 0 else 0)
	)
	var cap_detail: Dictionary = _result.get("iteration_cap_detail", {})
	if not cap_detail.is_empty():
		var final_total: int = int(_result.get("total_iterations", 0))
		var configured_limit: int = int(cap_detail.get("configured_limit", 0))
		cap_detail["final_total"] = final_total
		cap_detail["overshoot"] = maxi(final_total - configured_limit, 0)
		cap_detail["simulated_frames"] = int(_result.get("simulated_physics_frames", 0))
		cap_detail["simulated_substeps"] = int(_result.get("simulated_substeps", 0))
		cap_detail["trace_points_retained"] = retained_trace_points
		cap_detail["predicted_events_retained"] = retained_events.size()
		_result["iteration_cap_detail"] = cap_detail
	var geometry_cap_detail: Dictionary = _result.get("geometry_probe_cap_detail", {})
	if not geometry_cap_detail.is_empty():
		geometry_cap_detail["final_total"] = _geometry_probes
		geometry_cap_detail["overshoot"] = maxi(
			_geometry_probes - int(geometry_cap_detail.get("configured_limit", 0)),
			0
		)
		_result["geometry_probe_cap_detail"] = geometry_cap_detail


func _make_ball_result(ball: PredictionBall) -> Dictionary:
	var result: Dictionary = {
		"source_ball_id": ball.source_id,
		"source_ball_number": ball.ball_number,
		"source_index": ball.source_index,
		"is_cue_ball": ball.is_cue,
		"is_eight_ball": ball.is_eight,
		"path_points": ball.trace.duplicate(),
		"ending_position": ball.position,
		"radius": ball.radius,
		"final_stop_reason": ball.final_stop_reason,
		"pocketed": ball.pocketed,
		"generation_depth": _safe_generation_depth(ball),
		"causal_root_ball_id": ball.causal_root_ball_id,
		"parent_contact_event": ball.parent_contact_event,
		"parent_source_ball_id": ball.parent_source_ball_id,
	}
	var result_mode: String = _get_result_detail_mode()
	if result_mode != RESULT_MODE_PLAYER_MINIMAL:
		result["source_ball_label"] = ball.label
		result["anomaly_kind"] = ball.anomaly_kind
		result["starting_position"] = ball.starting_position
		result["starting_velocity"] = ball.starting_velocity
		result["ending_velocity"] = ball.velocity
		result["first_movement_event"] = ball.first_movement_event
	return result


func _estimate_result_memory_bytes(trace_points: int, event_count: int, ball_count: int) -> int:
	var event_bytes: int = 360
	if _get_result_detail_mode() == RESULT_MODE_PLAYER_MINIMAL:
		event_bytes = 112
	elif _get_result_detail_mode() == RESULT_MODE_PLAYER_EXTENDED:
		event_bytes = 224
	return trace_points * 16 + event_count * event_bytes + ball_count * 192


func _make_input_signature(input_snapshot: Dictionary, configuration: Dictionary) -> int:
	var payload: Dictionary = {
		"table_prediction_revision": input_snapshot.get("table_prediction_revision", -1),
		"balls": input_snapshot.get("balls", []),
		"physics_constants": input_snapshot.get("physics_constants", {}),
		"boundary_geometry_revision": input_snapshot.get("boundary_geometry_revision", -1),
		"pocket_geometry_revision": input_snapshot.get("pocket_geometry_revision", -1),
		"effect_snapshot": input_snapshot.get("effect_snapshot", {}),
		"cue_first_contact_toi_enabled": input_snapshot.get("cue_first_contact_toi_enabled", true),
		"configuration": configuration,
	}
	return hash(var_to_str(payload))


func _safe_generation_depth(ball: PredictionBall) -> int:
	return 0 if ball.generation_depth == UNREACHED_GENERATION else ball.generation_depth


func _get_result_detail_mode() -> String:
	return str(_config.get("result_detail_mode", RESULT_MODE_FULL_DEBUG))


func _get_pair_key(ball_a: PredictionBall, ball_b: PredictionBall) -> String:
	var first_id: int = ball_a.source_id
	var second_id: int = ball_b.source_id
	if first_id > second_id:
		var swap_id: int = first_id
		first_id = second_id
		second_id = swap_id
	return "%s:%s" % [first_id, second_id]


func _get_grid_cell(position: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.y / cell_size))


func _count_boundary_geometry_kind(kind: String) -> int:
	var count := 0
	for geometry_value in _boundary_geometry:
		if not geometry_value is Dictionary:
			continue
		var geometry: Dictionary = geometry_value
		if str(geometry.get("boundary_kind", "rail")) == kind:
			count += 1
	return count


func _sort_balls_by_source_index(ball_a: PredictionBall, ball_b: PredictionBall) -> bool:
	return ball_a.source_index < ball_b.source_index


func _elapsed_processing_ms() -> float:
	return float(Time.get_ticks_usec() - _processing_start_usec) / 1000.0
