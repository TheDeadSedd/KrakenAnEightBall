extends RefCounted
class_name AimTrajectoryProfiler

const HISTORY_LIMIT := 120
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

var enabled := false
var _history: Array[Dictionary] = []
var _phase_totals_us: Dictionary = {}
var _phase_maximums_us: Dictionary = {}
var _last_sample: Dictionary = {}
var _reason_counts: Dictionary = {}
var _recent_completion_usec: Array[int] = []
var _rebuilds_per_second := 0.0
var _stale_result_count := 0
var _discarded_result_count := 0
var _cache_rebuild_baseline := 0
var _cache_hit_baseline := 0


func set_enabled(enabled_value: bool) -> void:
	enabled = enabled_value


func reset(cache_snapshot: Dictionary = {}) -> void:
	_history.clear()
	_phase_totals_us.clear()
	_phase_maximums_us.clear()
	_last_sample.clear()
	_reason_counts.clear()
	_recent_completion_usec.clear()
	_rebuilds_per_second = 0.0
	_stale_result_count = 0
	_discarded_result_count = 0
	_cache_rebuild_baseline = int(cache_snapshot.get("rebuild_count", 0))
	_cache_hit_baseline = int(cache_snapshot.get("cache_hit_count", 0))


func record_completed_rebuild(sample: Dictionary) -> void:
	if not enabled:
		return

	var normalized_sample: Dictionary = sample.duplicate(true)
	var phase_timings: Dictionary = normalized_sample.get("phase_timings_us", {}).duplicate(true)
	for phase_key in PHASE_KEYS:
		phase_timings[phase_key] = maxi(int(phase_timings.get(phase_key, 0)), 0)
	normalized_sample["phase_timings_us"] = phase_timings

	_history.append(normalized_sample)
	for phase_key in PHASE_KEYS:
		var phase_value_us: int = int(phase_timings.get(phase_key, 0))
		_phase_totals_us[phase_key] = int(_phase_totals_us.get(phase_key, 0)) + phase_value_us
		_phase_maximums_us[phase_key] = maxi(
			int(_phase_maximums_us.get(phase_key, 0)),
			phase_value_us
		)

	if _history.size() > HISTORY_LIMIT:
		var removed_sample: Dictionary = _history.pop_front()
		var removed_timings: Dictionary = removed_sample.get("phase_timings_us", {})
		for phase_key in PHASE_KEYS:
			var removed_value_us: int = int(removed_timings.get(phase_key, 0))
			_phase_totals_us[phase_key] = maxi(
				int(_phase_totals_us.get(phase_key, 0)) - removed_value_us,
				0
			)
			if removed_value_us >= int(_phase_maximums_us.get(phase_key, 0)):
				_recalculate_phase_maximum(phase_key)

	_last_sample = normalized_sample
	var reason: String = str(normalized_sample.get("rebuild_reason", "unknown"))
	_reason_counts[reason] = int(_reason_counts.get(reason, 0)) + 1
	_record_completion_time(int(normalized_sample.get("completed_usec", Time.get_ticks_usec())))


func note_stale_result() -> void:
	if enabled:
		_stale_result_count += 1


func note_discarded_result() -> void:
	if enabled:
		_discarded_result_count += 1


func get_snapshot(cache_snapshot: Dictionary = {}) -> Dictionary:
	var sample_count: int = _history.size()
	var phase_stats: Dictionary = {}
	var last_phase_timings: Dictionary = _last_sample.get("phase_timings_us", {})
	for phase_key in PHASE_KEYS:
		var phase_values: Array[int] = _get_phase_values(phase_key)
		phase_stats[phase_key] = {
			"last_us": int(last_phase_timings.get(phase_key, 0)),
			"average_us": (
				float(_phase_totals_us.get(phase_key, 0)) / float(sample_count)
				if sample_count > 0
				else 0.0
			),
			"p95_us": _get_percentile(phase_values, 0.95),
			"maximum_us": int(_phase_maximums_us.get(phase_key, 0)),
		}

	return {
		"enabled": enabled,
		"history_limit": HISTORY_LIMIT,
		"sample_count": sample_count,
		"phase_stats": phase_stats,
		"last_sample": _last_sample.duplicate(true),
		"rebuilds_per_second": _rebuilds_per_second,
		"cache_hits": maxi(int(cache_snapshot.get("cache_hit_count", 0)) - _cache_hit_baseline, 0),
		"cache_misses": maxi(int(cache_snapshot.get("rebuild_count", 0)) - _cache_rebuild_baseline, 0),
		"stale_results": _stale_result_count,
		"discarded_results": _discarded_result_count,
		"last_rebuild_reason": str(_last_sample.get("rebuild_reason", "none")),
		"rebuild_reason_counts": _reason_counts.duplicate(true),
	}


func _record_completion_time(completed_usec: int) -> void:
	_recent_completion_usec.append(completed_usec)
	var cutoff_usec: int = completed_usec - 1000000
	while not _recent_completion_usec.is_empty() and _recent_completion_usec[0] < cutoff_usec:
		_recent_completion_usec.pop_front()
	_rebuilds_per_second = float(_recent_completion_usec.size())


func _recalculate_phase_maximum(phase_key: String) -> void:
	var maximum_us: int = 0
	for sample in _history:
		var timings: Dictionary = sample.get("phase_timings_us", {})
		maximum_us = maxi(maximum_us, int(timings.get(phase_key, 0)))
	_phase_maximums_us[phase_key] = maximum_us


func _get_phase_values(phase_key: String) -> Array[int]:
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
