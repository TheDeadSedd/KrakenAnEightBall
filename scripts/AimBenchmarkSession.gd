extends RefCounted
class_name AimBenchmarkSession

const HISTORY_LIMIT := 120
const STATUS_IDLE := "idle"
const STATUS_RECORDING := "recording"
const STATUS_COMPLETE := "complete"

const PHASE_KEYS: Array[String] = [
	"input_snapshot",
	"cache_key_construction",
	"cloned_state_setup",
	"broadphase_grid_work",
	"movement_friction",
	"swept_toi_ball_collision",
	"rail_pocket_processing",
	"rail_processing",
	"pocket_processing",
	"rail_overlap_resolution",
	"cue_boundary_chronology",
	"pocket_overlap_capture",
	"cue_pocket_chronology",
	"boundary_candidate_gathering",
	"rail_sweep_intersection_testing",
	"jaw_corner_testing",
	"rail_response_calculation",
	"boundary_result_packaging",
	"pocket_candidate_gathering",
	"pocket_sweep_capture_testing",
	"pocket_resolution",
	"pocket_result_packaging",
	"cross_type_event_ordering",
	"trace_recording",
	"trace_simplification",
	"event_result_packaging",
	"predicted_actual_comparison",
	"draw_data_preparation",
	"total_simulation",
	"total_full_rebuild",
]
const PHASE_LABELS := {
	"input_snapshot": "Snapshot",
	"cache_key_construction": "Cache key",
	"cloned_state_setup": "Clone setup",
	"broadphase_grid_work": "Broadphase",
	"movement_friction": "Movement/friction",
	"swept_toi_ball_collision": "Collisions/TOI",
	"rail_pocket_processing": "Rails/pockets",
	"rail_processing": "Boundaries total",
	"pocket_processing": "Pockets total",
	"rail_overlap_resolution": "Rail overlap resolution",
	"cue_boundary_chronology": "Cue boundary chronology",
	"pocket_overlap_capture": "Pocket overlap/capture",
	"cue_pocket_chronology": "Cue pocket chronology",
	"boundary_candidate_gathering": "Boundary candidate gathering",
	"rail_sweep_intersection_testing": "Rail tests",
	"jaw_corner_testing": "Jaw tests",
	"rail_response_calculation": "Rail response",
	"boundary_result_packaging": "Boundary result packaging",
	"pocket_candidate_gathering": "Pocket candidate gathering",
	"pocket_sweep_capture_testing": "Pocket tests",
	"pocket_resolution": "Pocket resolution",
	"pocket_result_packaging": "Pocket result packaging",
	"cross_type_event_ordering": "Cross-type event ordering",
	"trace_recording": "Trace generation",
	"trace_simplification": "Trace simplification",
	"event_result_packaging": "Packaging",
	"predicted_actual_comparison": "Predicted/actual comparison",
	"draw_data_preparation": "CPU draw preparation",
	"total_simulation": "Simulation total",
	"total_full_rebuild": "Full rebuild total",
}
const WORKLOAD_KEYS: Array[String] = [
	"simulated_physics_frames",
	"simulated_substeps",
	"total_iterations",
	"geometry_probes",
	"broadphase_rebuilds",
	"full_broadphase_rebuilds",
	"incremental_broadphase_updates",
	"current_grid_rebuilds",
	"swept_grid_rebuilds",
	"candidate_tests",
	"pair_checks",
	"swept_toi_solves",
	"total_ball_contacts",
	"total_cue_ball_contacts",
	"total_rail_contacts",
	"total_pocket_captures",
	"total_stops",
	"raw_trace_points",
	"retained_trace_points",
	"simplified_trace_points",
	"spacing_or_duplicate_trace_points",
	"collinear_simplified_trace_points",
	"balls_traced",
	"predicted_events_retained",
	"debug_events_retained",
	"compared_events",
	"visible_path_segments",
	"result_memory_estimate_bytes",
	"boundary_shapes_available",
	"rail_shapes_available",
	"jaw_shapes_available",
	"rail_candidate_queries",
	"rail_shapes_tested",
	"jaw_shapes_tested",
	"rail_swept_tests",
	"rail_candidates_rejected_by_aabb",
	"rail_events_accepted",
	"pocket_count_available",
	"pocket_candidate_queries",
	"pockets_tested",
	"pocket_swept_tests",
	"pocket_candidates_rejected_by_aabb",
	"pocket_events_accepted",
	"cloned_balls_checked_against_boundaries",
	"cloned_balls_checked_against_pockets",
	"stopped_balls_skipped_from_movement",
	"stopped_balls_skipped_from_rail_checks",
	"stopped_balls_skipped_from_pocket_checks",
	"stopped_balls_included_in_broadphase",
	"inactive_balls_skipped_from_loops",
	"repeated_boundary_checks",
	"remaining_time_boundary_iterations",
	"boundary_temporary_objects_created",
	"pocket_temporary_objects_created",
	"static_geometry_cache_hits",
	"static_geometry_cache_rebuilds",
	"scratch_buffer_reuses",
	"temporary_allocations",
	"balls_newly_stopped",
]
const MAXIMUM_WORKLOAD_KEYS: Array[String] = [
	"maximum_causal_depth",
	"maximum_simultaneously_moving_balls",
	"stationary_targets_per_substep_maximum",
	"result_memory_estimate_bytes",
]

var _status := STATUS_IDLE
var _recording := false
var _label := ""
var _preset_label := ""
var _result_mode := ""
var _start_usec := 0
var _stop_usec := 0
var _captured_rebuilds := 0
var _active_drag_rebuilds := 0
var _settled_rebuilds := 0
var _forced_rebuilds := 0
var _cache_hits := 0
var _stale_results := 0
var _discarded_results := 0
var _redraw_requests := 0
var _total_rebuild_cpu_us := 0
var _history: Array[Dictionary] = []
var _phase_totals_us: Dictionary = {}
var _phase_maximums_us: Dictionary = {}
var _work_totals: Dictionary = {}
var _work_maximums: Dictionary = {}
var _rebuild_reason_counts: Dictionary = {}
var _stop_reason_counts: Dictionary = {}
var _iteration_totals: Dictionary = {}
var _iteration_source_totals: Dictionary = {}
var _last_sample: Dictionary = {}
var _last_cap_detail: Dictionary = {}
var _last_geometry_cap_detail: Dictionary = {}
var _setup_snapshot: Dictionary = {}
var _contamination_snapshot: Dictionary = {}
var _draw_history: Array[Dictionary] = []
var _draw_total_cpu_us := 0
var _draw_maximum_cpu_us := 0
var _draw_sample_count := 0
var _last_copied_status := "not copied"


func reset() -> void:
	_status = STATUS_IDLE
	_recording = false
	_label = ""
	_preset_label = ""
	_result_mode = ""
	_start_usec = 0
	_stop_usec = 0
	_captured_rebuilds = 0
	_active_drag_rebuilds = 0
	_settled_rebuilds = 0
	_forced_rebuilds = 0
	_cache_hits = 0
	_stale_results = 0
	_discarded_results = 0
	_redraw_requests = 0
	_total_rebuild_cpu_us = 0
	_history.clear()
	_phase_totals_us.clear()
	_phase_maximums_us.clear()
	_work_totals.clear()
	_work_maximums.clear()
	_rebuild_reason_counts.clear()
	_stop_reason_counts.clear()
	_iteration_totals.clear()
	_iteration_source_totals.clear()
	_last_sample.clear()
	_last_cap_detail.clear()
	_last_geometry_cap_detail.clear()
	_setup_snapshot.clear()
	_contamination_snapshot.clear()
	_draw_history.clear()
	_draw_total_cpu_us = 0
	_draw_maximum_cpu_us = 0
	_draw_sample_count = 0
	_last_copied_status = "not copied"


func start_capture(
	label: String,
	preset_label: String,
	result_mode: String,
	contamination_snapshot: Dictionary = {}
) -> void:
	reset()
	_status = STATUS_RECORDING
	_recording = true
	_label = label.strip_edges()
	_preset_label = preset_label
	_result_mode = result_mode
	_contamination_snapshot = contamination_snapshot.duplicate(true)
	_start_usec = Time.get_ticks_usec()


func stop_capture() -> void:
	if not _recording:
		return
	_stop_usec = Time.get_ticks_usec()
	_recording = false
	_status = STATUS_COMPLETE


func is_recording() -> bool:
	return _recording


func record_completed_rebuild(sample_value: Dictionary) -> void:
	if not _recording:
		return

	var sample: Dictionary = sample_value.duplicate(true)
	var phase_timings: Dictionary = sample.get("phase_timings_us", {}).duplicate(true)
	for phase_key in PHASE_KEYS:
		var phase_value_us: int = maxi(int(phase_timings.get(phase_key, 0)), 0)
		phase_timings[phase_key] = phase_value_us
		_phase_totals_us[phase_key] = int(_phase_totals_us.get(phase_key, 0)) + phase_value_us
		_phase_maximums_us[phase_key] = maxi(
			int(_phase_maximums_us.get(phase_key, 0)),
			phase_value_us
		)
	sample["phase_timings_us"] = phase_timings

	_captured_rebuilds += 1
	_total_rebuild_cpu_us += int(phase_timings.get("total_full_rebuild", 0))
	var classification: String = str(sample.get("rebuild_classification", "settled"))
	match classification:
		"active_drag":
			_active_drag_rebuilds += 1
		"settled":
			_settled_rebuilds += 1
		_:
			_forced_rebuilds += 1

	var rebuild_reason: String = str(sample.get("rebuild_reason", "unknown"))
	_rebuild_reason_counts[rebuild_reason] = int(_rebuild_reason_counts.get(rebuild_reason, 0)) + 1
	var stop_reason: String = str(sample.get("stop_reason", "unknown"))
	_stop_reason_counts[stop_reason] = int(_stop_reason_counts.get(stop_reason, 0)) + 1
	var iteration_breakdown: Dictionary = sample.get("iteration_breakdown", {})
	for iteration_key_value in iteration_breakdown.keys():
		var iteration_key: String = str(iteration_key_value)
		_iteration_totals[iteration_key] = int(_iteration_totals.get(iteration_key, 0)) + int(
			iteration_breakdown.get(iteration_key, 0)
		)
	var iteration_source_attempts: Dictionary = sample.get("iteration_source_attempts", {})
	for source_key_value in iteration_source_attempts.keys():
		var source_key: String = str(source_key_value)
		_iteration_source_totals[source_key] = int(
			_iteration_source_totals.get(source_key, 0)
		) + int(iteration_source_attempts.get(source_key, 0))
	for workload_key in WORKLOAD_KEYS:
		_work_totals[workload_key] = int(_work_totals.get(workload_key, 0)) + int(
			sample.get(workload_key, 0)
		)
	for workload_key in MAXIMUM_WORKLOAD_KEYS:
		_work_maximums[workload_key] = maxi(
			int(_work_maximums.get(workload_key, 0)),
			int(sample.get(workload_key, 0))
		)

	var setup_value: Variant = sample.get("setup", {})
	if setup_value is Dictionary:
		_setup_snapshot = (setup_value as Dictionary).duplicate(true)
		_result_mode = str(_setup_snapshot.get("result_detail_mode", _result_mode))
	_last_sample = sample
	var cap_detail_value: Variant = sample.get("iteration_cap_detail", {})
	if cap_detail_value is Dictionary and not (cap_detail_value as Dictionary).is_empty():
		_last_cap_detail = (cap_detail_value as Dictionary).duplicate(true)
	var geometry_cap_detail_value: Variant = sample.get("geometry_probe_cap_detail", {})
	if (
		geometry_cap_detail_value is Dictionary
		and not (geometry_cap_detail_value as Dictionary).is_empty()
	):
		_last_geometry_cap_detail = (geometry_cap_detail_value as Dictionary).duplicate(true)
	_history.append(sample)
	if _history.size() > HISTORY_LIMIT:
		_history.pop_front()


func note_cache_hit() -> void:
	if _recording:
		_cache_hits += 1


func note_stale_result() -> void:
	if _recording:
		_stale_results += 1


func note_discarded_result() -> void:
	if _recording:
		_discarded_results += 1


func note_redraw_request() -> void:
	if _recording:
		_redraw_requests += 1


func record_draw_sample(sample_value: Dictionary) -> void:
	if not _recording:
		return
	var sample: Dictionary = sample_value.duplicate(true)
	var cpu_us: int = maxi(int(sample.get("cpu_us", 0)), 0)
	_draw_sample_count += 1
	_draw_total_cpu_us += cpu_us
	_draw_maximum_cpu_us = maxi(_draw_maximum_cpu_us, cpu_us)
	_draw_history.append(sample)
	if _draw_history.size() > HISTORY_LIMIT:
		_draw_history.pop_front()


func get_snapshot() -> Dictionary:
	var duration_seconds: float = _get_capture_duration_seconds()
	var phase_stats: Dictionary = {}
	for phase_key in PHASE_KEYS:
		var values: Array[int] = _get_phase_history_values(phase_key)
		var last_timings: Dictionary = _last_sample.get("phase_timings_us", {})
		phase_stats[phase_key] = {
			"last_us": int(last_timings.get(phase_key, 0)),
			"average_us": (
				float(_phase_totals_us.get(phase_key, 0)) / float(_captured_rebuilds)
				if _captured_rebuilds > 0
				else 0.0
			),
			"p95_us": _get_percentile(values, 0.95),
			"maximum_us": int(_phase_maximums_us.get(phase_key, 0)),
		}

	var total_values: Array[int] = _get_phase_history_values("total_full_rebuild")
	var draw_values: Array[int] = []
	for draw_sample in _draw_history:
		draw_values.append(maxi(int(draw_sample.get("cpu_us", 0)), 0))
	return {
		"status": _status,
		"recording": _recording,
		"history_limit": HISTORY_LIMIT,
		"label": _label,
		"preset": _preset_label,
		"result_mode": _result_mode,
		"capture_duration_seconds": duration_seconds,
		"captured_rebuilds": _captured_rebuilds,
		"active_drag_rebuilds": _active_drag_rebuilds,
		"settled_rebuilds": _settled_rebuilds,
		"forced_rebuilds": _forced_rebuilds,
		"rebuilds_per_second": (
			float(_captured_rebuilds) / duration_seconds
			if duration_seconds > 0.0
			else 0.0
		),
		"prediction_cpu_share_percent": (
			100.0 * (float(_total_rebuild_cpu_us) / 1000000.0) / duration_seconds
			if duration_seconds > 0.0
			else 0.0
		),
		"total_rebuild_cpu_ms": float(_total_rebuild_cpu_us) / 1000.0,
		"average_total_rebuild_ms": (
			float(_total_rebuild_cpu_us) / 1000.0 / float(_captured_rebuilds)
			if _captured_rebuilds > 0
			else 0.0
		),
		"p95_total_rebuild_ms": float(_get_percentile(total_values, 0.95)) / 1000.0,
		"maximum_total_rebuild_ms": float(_phase_maximums_us.get("total_full_rebuild", 0)) / 1000.0,
		"phase_stats": phase_stats,
		"cache_hits": _cache_hits,
		"cache_misses": _captured_rebuilds,
		"stale_results": _stale_results,
		"discarded_results": _discarded_results,
		"rebuild_reason_counts": _rebuild_reason_counts.duplicate(true),
		"stop_reason_counts": _stop_reason_counts.duplicate(true),
		"iteration_totals": _iteration_totals.duplicate(true),
		"iteration_source_totals": _iteration_source_totals.duplicate(true),
		"work_totals": _work_totals.duplicate(true),
		"work_maximums": _work_maximums.duplicate(true),
		"last_sample": _last_sample.duplicate(true),
		"last_iteration_cap_detail": _last_cap_detail.duplicate(true),
		"last_geometry_probe_cap_detail": _last_geometry_cap_detail.duplicate(true),
		"setup": _setup_snapshot.duplicate(true),
		"contamination": _contamination_snapshot.duplicate(true),
		"redraw_requests": _redraw_requests,
		"draw_sample_count": _draw_sample_count,
		"draw_cpu_average_us": (
			float(_draw_total_cpu_us) / float(_draw_sample_count)
			if _draw_sample_count > 0
			else 0.0
		),
		"draw_cpu_p95_us": _get_percentile(draw_values, 0.95),
		"draw_cpu_maximum_us": _draw_maximum_cpu_us,
		"last_draw_sample": _draw_history.back().duplicate(true) if not _draw_history.is_empty() else {},
		"last_copied_status": _last_copied_status,
	}


func copy_report_to_clipboard() -> bool:
	var report: String = make_plain_text_report()
	if report.is_empty():
		_last_copied_status = "no capture available"
		return false
	DisplayServer.clipboard_set(report)
	_last_copied_status = "copied"
	return true


func make_plain_text_report() -> String:
	if _status == STATUS_IDLE and _captured_rebuilds <= 0:
		return ""
	var snapshot: Dictionary = get_snapshot()
	var setup: Dictionary = snapshot.get("setup", {})
	var work: Dictionary = snapshot.get("work_totals", {})
	var lines: Array[String] = [
		"KRAKEN AN EIGHT BALL - AIM BENCHMARK",
		"",
		"Label: %s" % (_label if not _label.is_empty() else "Unlabelled capture"),
		"Mode: %s" % setup.get("mode_id", "unknown"),
	]
	var round_number: int = int(setup.get("roguelite_round", 0))
	if round_number > 0:
		lines.append("Roguelite round: %s" % round_number)
	lines.append("Preset: %s" % (_preset_label if not _preset_label.is_empty() else "Custom"))
	lines.append("Result mode: %s" % (_result_mode if not _result_mode.is_empty() else "unknown"))
	lines.append("")
	lines.append("SETUP")
	lines.append("Active balls: %s" % setup.get("active_balls", 0))
	lines.append("Cloned balls: %s" % setup.get("cloned_balls", 0))
	lines.append("Initially moving balls: %s" % setup.get("initially_moving_balls", 0))
	lines.append("Cue speed: %.1f" % float(setup.get("cue_launch_speed", 0.0)))
	lines.append("Depth limit: %s" % setup.get("max_child_generation_depth", 0))
	lines.append("Simulated seconds limit: %.1f" % float(setup.get("max_simulated_seconds", 0.0)))
	lines.append("Frame rate / substeps: %s / %s" % [
		setup.get("simulation_frame_rate", 0),
		setup.get("simulation_substeps", 0),
	])
	lines.append("Trace spacing: %.1f px" % float(setup.get("trace_spacing", 0.0)))
	lines.append("")
	lines.append("CAPTURE")
	lines.append("Status: %s" % snapshot.get("status", STATUS_IDLE))
	lines.append("Duration: %.2f s" % float(snapshot.get("capture_duration_seconds", 0.0)))
	lines.append("Completed rebuilds: %s" % snapshot.get("captured_rebuilds", 0))
	lines.append("Active-drag rebuilds: %s" % snapshot.get("active_drag_rebuilds", 0))
	lines.append("Settled rebuilds: %s" % snapshot.get("settled_rebuilds", 0))
	lines.append("Forced/config rebuilds: %s" % snapshot.get("forced_rebuilds", 0))
	lines.append("Rebuilds/sec: %.2f" % float(snapshot.get("rebuilds_per_second", 0.0)))
	lines.append("Total rebuild CPU: %.2f ms" % float(snapshot.get("total_rebuild_cpu_ms", 0.0)))
	lines.append("Prediction CPU share: %.1f%%" % float(snapshot.get("prediction_cpu_share_percent", 0.0)))
	lines.append("")
	lines.append("TIMING - LAST / AVG / P95 / MAX (microseconds)")
	var phase_stats: Dictionary = snapshot.get("phase_stats", {})
	for phase_key in PHASE_KEYS:
		var phase: Dictionary = phase_stats.get(phase_key, {})
		lines.append("%s: %s / %.1f / %.1f / %s" % [
			PHASE_LABELS.get(phase_key, phase_key),
			phase.get("last_us", 0),
			float(phase.get("average_us", 0.0)),
			float(phase.get("p95_us", 0.0)),
			phase.get("maximum_us", 0),
		])
	lines.append("")
	lines.append("WORK - TOTAL (average per rebuild)")
	var work_maximums: Dictionary = snapshot.get("work_maximums", {})
	var last_sample: Dictionary = snapshot.get("last_sample", {})
	_append_work_line(lines, "Frames simulated", work, "simulated_physics_frames")
	_append_work_line(lines, "Substeps", work, "simulated_substeps")
	_append_work_line(lines, "Control iterations", work, "total_iterations")
	_append_work_line(lines, "Geometry probes", work, "geometry_probes")
	lines.append("Configured control / geometry budget: %s / %s" % [
		last_sample.get("control_iteration_budget", 0),
		last_sample.get("geometry_probe_budget", 0),
	])
	_append_work_line(lines, "Broadphase rebuilds", work, "broadphase_rebuilds")
	_append_work_line(lines, "- full rebuilds", work, "full_broadphase_rebuilds")
	_append_work_line(lines, "- incremental updates", work, "incremental_broadphase_updates")
	_append_work_line(lines, "- current-grid rebuilds", work, "current_grid_rebuilds")
	_append_work_line(lines, "- swept-grid rebuilds", work, "swept_grid_rebuilds")
	_append_work_line(lines, "Candidate tests", work, "candidate_tests")
	_append_work_line(lines, "Pair checks", work, "pair_checks")
	_append_work_line(lines, "Swept TOI solves", work, "swept_toi_solves")
	_append_work_line(lines, "Ball contacts", work, "total_ball_contacts")
	_append_work_line(lines, "Cue-ball contacts", work, "total_cue_ball_contacts")
	_append_work_line(lines, "Rail contacts", work, "total_rail_contacts")
	_append_work_line(lines, "Pockets", work, "total_pocket_captures")
	_append_work_line(lines, "Stops", work, "total_stops")
	_append_work_line(lines, "Trace points raw", work, "raw_trace_points")
	_append_work_line(lines, "Trace points retained", work, "retained_trace_points")
	_append_work_line(lines, "Trace points removed total", work, "simplified_trace_points")
	_append_work_line(lines, "- spacing/duplicate filtered", work, "spacing_or_duplicate_trace_points")
	_append_work_line(lines, "- collinear simplified", work, "collinear_simplified_trace_points")
	_append_work_line(lines, "Balls traced", work, "balls_traced")
	_append_work_line(lines, "Predicted events retained", work, "predicted_events_retained")
	_append_work_line(lines, "Debug events retained", work, "debug_events_retained")
	_append_work_line(lines, "Compared events", work, "compared_events")
	_append_work_line(lines, "Visible path segments", work, "visible_path_segments")
	lines.append("Maximum causal depth reached: %s" % work_maximums.get("maximum_causal_depth", 0))
	lines.append("Maximum simultaneously moving clones: %s" % work_maximums.get("maximum_simultaneously_moving_balls", 0))
	lines.append("Maximum stationary collision targets: %s" % work_maximums.get("stationary_targets_per_substep_maximum", 0))
	lines.append("Maximum result memory estimate: %s bytes" % work_maximums.get("result_memory_estimate_bytes", 0))
	lines.append("")
	lines.append("CPU PRESENTATION / DRAW (not GPU time)")
	lines.append("Draw samples: %s" % snapshot.get("draw_sample_count", 0))
	lines.append("AimPreview _draw avg / P95 / max: %.1f / %.1f / %s us" % [
		float(snapshot.get("draw_cpu_average_us", 0.0)),
		float(snapshot.get("draw_cpu_p95_us", 0.0)),
		snapshot.get("draw_cpu_maximum_us", 0),
	])
	lines.append("Redraw requests: %s" % snapshot.get("redraw_requests", 0))
	var last_draw: Dictionary = snapshot.get("last_draw_sample", {})
	lines.append("Last draw paths / segments / balls: %s / %s / %s" % [
		last_draw.get("visible_paths", 0),
		last_draw.get("visible_path_segments", 0),
		last_draw.get("predicted_balls_drawn", 0),
	])
	lines.append("Last draw ghosts / labels / markers: %s / %s / %s" % [
		last_draw.get("ghost_balls_drawn", 0),
		last_draw.get("labels_drawn", 0),
		last_draw.get("event_markers_drawn", 0),
	])
	lines.append("")
	lines.append("CACHE")
	lines.append("Hits: %s" % snapshot.get("cache_hits", 0))
	lines.append("Misses/completed rebuilds: %s" % snapshot.get("cache_misses", 0))
	lines.append("Stale/discarded: %s / %s" % [
		snapshot.get("stale_results", 0),
		snapshot.get("discarded_results", 0),
	])
	lines.append("Rebuild reasons: %s" % _format_counts(snapshot.get("rebuild_reason_counts", {})))
	lines.append("")
	lines.append("PREDICTION AVAILABILITY")
	var availability: Dictionary = last_sample.get("prediction_availability", {})
	lines.append("Available / requested / enabled: %s / %s / %s" % [
		_yes_no(availability.get("available", false)),
		_yes_no(availability.get("live_preview_requested", false)),
		_yes_no(availability.get("cloned_simulation_enabled", false)),
	])
	lines.append("Table / cached / successful revision: %s / %s / %s" % [
		availability.get("table_revision", -1),
		availability.get("cached_revision", -1),
		availability.get("last_successful_rebuild_revision", -1),
	])
	lines.append("Active / cloned / transient / unsupported balls: %s / %s / %s / %s" % [
		availability.get("active_ball_count", 0),
		availability.get("cloned_ball_count", 0),
		availability.get("transient_ball_count", 0),
		availability.get("unsupported_ball_count", 0),
	])
	lines.append("Blocker: %s" % availability.get("blocker_reason", "none"))
	lines.append("Details: %s" % availability.get("blocker_details", "none"))
	var invalidation: Dictionary = last_sample.get("invalidation", {})
	lines.append("Invalidations / last: %s / %s" % [
		invalidation.get("cache_invalidations", 0),
		invalidation.get("last_invalidation_reason", "none"),
	])
	lines.append("Invalidation reasons: %s" % _format_counts(invalidation.get("invalidation_reasons", {})))
	lines.append("")
	lines.append("BOUNDARY/POCKET TIMING - LAST / AVG / P95 / MAX (microseconds)")
	for phase_key in [
		"rail_pocket_processing",
		"rail_processing",
		"pocket_processing",
		"rail_overlap_resolution",
		"cue_boundary_chronology",
		"pocket_overlap_capture",
		"cue_pocket_chronology",
		"boundary_candidate_gathering",
		"rail_sweep_intersection_testing",
		"jaw_corner_testing",
		"rail_response_calculation",
		"boundary_result_packaging",
		"pocket_candidate_gathering",
		"pocket_sweep_capture_testing",
		"pocket_resolution",
		"pocket_result_packaging",
		"cross_type_event_ordering",
	]:
		var boundary_phase: Dictionary = phase_stats.get(phase_key, {})
		lines.append("%s: %s / %.1f / %.1f / %s" % [
			PHASE_LABELS.get(phase_key, phase_key),
			boundary_phase.get("last_us", 0),
			float(boundary_phase.get("average_us", 0.0)),
			float(boundary_phase.get("p95_us", 0.0)),
			boundary_phase.get("maximum_us", 0),
		])
	lines.append("")
	lines.append("BOUNDARY/POCKET WORK - TOTAL (average per rebuild)")
	_append_work_line(lines, "Boundary shapes available", work, "boundary_shapes_available")
	_append_work_line(lines, "Rail shapes available", work, "rail_shapes_available")
	_append_work_line(lines, "Jaw shapes available", work, "jaw_shapes_available")
	_append_work_line(lines, "Rail shapes tested", work, "rail_shapes_tested")
	_append_work_line(lines, "Jaw tests", work, "jaw_shapes_tested")
	_append_work_line(lines, "Rail candidate queries", work, "rail_candidate_queries")
	_append_work_line(lines, "Rail chronology sweeps", work, "rail_swept_tests")
	_append_work_line(lines, "Rail candidates rejected by AABB", work, "rail_candidates_rejected_by_aabb")
	_append_work_line(lines, "Rail events accepted", work, "rail_events_accepted")
	_append_work_line(lines, "Pocket count available", work, "pocket_count_available")
	_append_work_line(lines, "Pocket candidate queries", work, "pocket_candidate_queries")
	_append_work_line(lines, "Pocket overlap tests", work, "pockets_tested")
	_append_work_line(lines, "Pocket chronology sweeps", work, "pocket_swept_tests")
	_append_work_line(lines, "Pocket candidates rejected by AABB", work, "pocket_candidates_rejected_by_aabb")
	_append_work_line(lines, "Pocket events accepted", work, "pocket_events_accepted")
	_append_work_line(lines, "Balls checked against boundaries", work, "cloned_balls_checked_against_boundaries")
	_append_work_line(lines, "Balls checked against pockets", work, "cloned_balls_checked_against_pockets")
	_append_work_line(lines, "Repeated boundary checks", work, "repeated_boundary_checks")
	_append_work_line(lines, "Remaining-time boundary loops", work, "remaining_time_boundary_iterations")
	_append_work_line(lines, "Boundary temporary objects", work, "boundary_temporary_objects_created")
	_append_work_line(lines, "Pocket temporary objects", work, "pocket_temporary_objects_created")
	_append_work_line(lines, "Static geometry cache hits", work, "static_geometry_cache_hits")
	_append_work_line(lines, "Static geometry cache rebuilds", work, "static_geometry_cache_rebuilds")
	_append_work_line(lines, "Scratch buffer reuses", work, "scratch_buffer_reuses")
	_append_work_line(lines, "Temporary allocations", work, "temporary_allocations")
	_append_work_line(lines, "Stopped skipped movement", work, "stopped_balls_skipped_from_movement")
	_append_work_line(lines, "Stopped skipped rails", work, "stopped_balls_skipped_from_rail_checks")
	_append_work_line(lines, "Stopped skipped pockets", work, "stopped_balls_skipped_from_pocket_checks")
	_append_work_line(lines, "Stopped retained in broadphase", work, "stopped_balls_included_in_broadphase")
	_append_work_line(lines, "Inactive skipped from loops", work, "inactive_balls_skipped_from_loops")
	lines.append("Last moving balls average / max: %.2f / %s" % [
		float(last_sample.get("moving_balls_per_substep_average", 0.0)),
		last_sample.get("moving_balls_per_substep_maximum", 0),
	])
	lines.append("Last stationary targets average / max: %.2f / %s" % [
		float(last_sample.get("stationary_targets_per_substep_average", 0.0)),
		last_sample.get("stationary_targets_per_substep_maximum", 0),
	])
	lines.append("Last balls newly stopped: %s" % last_sample.get("balls_newly_stopped", 0))
	lines.append("")
	lines.append("ITERATION BREAKDOWN")
	var iteration_totals: Dictionary = snapshot.get("iteration_totals", {})
	lines.append("Total control iterations: %s" % work.get("total_iterations", 0))
	lines.append("Total geometry probes: %s" % work.get("geometry_probes", 0))
	for iteration_key in [
		"frames",
		"substeps",
		"ball_movement",
		"pair_collision",
		"boundaries",
		"pockets",
		"remaining_time",
		"broadphase",
		"event_loop",
		"trace",
		"other",
	]:
		lines.append("- %s: %s" % [iteration_key.replace("_", " ").capitalize(), iteration_totals.get(iteration_key, 0)])
	var iteration_source_totals: Dictionary = snapshot.get("iteration_source_totals", {})
	lines.append("Counted sources:")
	for source_key in [
		"substep",
		"remaining_time",
		"cue_toi_candidate",
		"legacy_pair",
		"rail_probe",
		"pocket_probe",
		"other",
	]:
		lines.append("- %s: %s" % [source_key.replace("_", " ").capitalize(), iteration_source_totals.get(source_key, 0)])
	lines.append("")
	lines.append("CAP DETAIL")
	var cap_detail: Dictionary = snapshot.get("last_iteration_cap_detail", {})
	if cap_detail.is_empty():
		lines.append("No max_total_iterations cap captured.")
	else:
		lines.append("Limit / first trigger / final / overshoot: %s / %s / %s / %s" % [
			cap_detail.get("configured_limit", 0),
			cap_detail.get("first_trigger_total", 0),
			cap_detail.get("final_total", 0),
			cap_detail.get("overshoot", 0),
		])
		lines.append("Phase / event / ball: %s / %s / %s" % [
			cap_detail.get("phase_active", "unknown"),
			cap_detail.get("last_event_type", "none"),
			cap_detail.get("last_processed_ball", "none"),
		])
		lines.append("Time / frame / substep: %.4f / %s / %s" % [
			float(cap_detail.get("simulated_time", 0.0)),
			cap_detail.get("frame_index", 0),
			cap_detail.get("substep_index", 0),
		])
		lines.append("Active / moving / nearly stopped: %s / %s / %s" % [
			cap_detail.get("active_ball_count", 0),
			cap_detail.get("moving_ball_count", 0),
			_yes_no(cap_detail.get("all_balls_nearly_stopped", false)),
		])
		lines.append("Remaining fraction / depth / traces / events: %.4f / %s / %s / %s" % [
			float(cap_detail.get("remaining_time_fraction", -1.0)),
			cap_detail.get("causal_depth_reached", 0),
			cap_detail.get("trace_points_retained", 0),
			cap_detail.get("predicted_events_retained", 0),
		])
	var geometry_cap_detail: Dictionary = snapshot.get("last_geometry_probe_cap_detail", {})
	if geometry_cap_detail.is_empty():
		lines.append("No max_geometry_probes cap captured.")
	else:
		lines.append("Geometry limit / first trigger / final / overshoot: %s / %s / %s / %s" % [
			geometry_cap_detail.get("configured_limit", 0),
			geometry_cap_detail.get("first_trigger_total", 0),
			geometry_cap_detail.get("final_total", 0),
			geometry_cap_detail.get("overshoot", 0),
		])
		lines.append("Geometry phase / event / ball: %s / %s / %s" % [
			geometry_cap_detail.get("phase_active", "unknown"),
			geometry_cap_detail.get("last_event_type", "none"),
			geometry_cap_detail.get("last_processed_ball", "none"),
		])
	lines.append("")
	lines.append("STOP REASONS")
	lines.append(_format_counts(snapshot.get("stop_reason_counts", {})))
	lines.append("")
	lines.append("BENCHMARK CONTAMINATION FLAGS")
	lines.append("Full debug comparison: %s" % _yes_no(_contamination_snapshot.get("full_debug_comparison", false)))
	lines.append("Candidate diagnostics: %s" % _yes_no(_contamination_snapshot.get("candidate_diagnostics", false)))
	lines.append("Actual trace comparison: %s" % _yes_no(_contamination_snapshot.get("actual_trace_comparison", false)))
	lines.append("AIM PROFILER visible: %s" % _yes_no(_contamination_snapshot.get("profiler_panel_visible", false)))
	lines.append("Complete aim workspace visible: %s" % _yes_no(_contamination_snapshot.get("complete_aim_workspace_visible", false)))
	return "\n".join(lines)


func _append_work_line(lines: Array[String], label: String, work: Dictionary, key: String) -> void:
	var total: int = int(work.get(key, 0))
	var average: float = float(total) / float(_captured_rebuilds) if _captured_rebuilds > 0 else 0.0
	lines.append("%s: %s (%.1f)" % [label, total, average])


func _get_capture_duration_seconds() -> float:
	if _start_usec <= 0:
		return 0.0
	var end_usec: int = Time.get_ticks_usec() if _recording else _stop_usec
	return maxf(float(end_usec - _start_usec) / 1000000.0, 0.0)


func _get_phase_history_values(phase_key: String) -> Array[int]:
	var values: Array[int] = []
	for sample in _history:
		var timings: Dictionary = sample.get("phase_timings_us", {})
		values.append(maxi(int(timings.get(phase_key, 0)), 0))
	return values


func _get_percentile(values: Array[int], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[int] = values.duplicate()
	sorted_values.sort()
	var index: int = clampi(ceili(float(sorted_values.size()) * percentile) - 1, 0, sorted_values.size() - 1)
	return float(sorted_values[index])


func _format_counts(value: Variant) -> String:
	if not value is Dictionary or (value as Dictionary).is_empty():
		return "none"
	var counts: Dictionary = value
	var keys: Array[String] = []
	for key_value in counts.keys():
		keys.append(str(key_value))
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%s" % [key, counts.get(key, 0)])
	return ", ".join(parts)


func _yes_no(value: Variant) -> String:
	return "yes" if bool(value) else "no"
