extends RefCounted
class_name AimTrajectoryProfiler

const HISTORY_LIMIT := 120
const RATE_EVENT_LIMIT := 2048
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
const STAGED_TIMING_KEYS: Array[String] = [
	"immediate_update_cpu",
	"deep_compute_start_latency",
	"deep_compute_duration",
	"deep_first_visible_latency_us",
	"deep_fully_visible_latency_us",
	"cache_hit_first_visible_latency_us",
	"reveal_duration_actual",
	"reveal_preparation_cpu",
	"reveal_cpu_presentation",
]
const STAGED_CPU_TIMING_KEYS: Array[String] = [
	"immediate_update_cpu",
	"deep_compute_duration",
	"reveal_preparation_cpu",
	"reveal_cpu_presentation",
]
const LIFECYCLE_REASON_LIMIT := 32

var enabled := false
var _history: Array[Dictionary] = []
var _phase_totals_us: Dictionary = {}
var _phase_maximums_us: Dictionary = {}
var _last_sample: Dictionary = {}
var _reason_counts: Dictionary = {}
var _player_request_class_counts: Dictionary = {}
var _recent_completion_usec: Array[int] = []
var _rebuilds_per_second := 0.0
var _cache_rebuild_baseline := 0
var _cache_hit_baseline := 0
var _staged_timing_history: Dictionary = {}
var _staged_timing_totals_us: Dictionary = {}
var _staged_timing_maximums_us: Dictionary = {}
var _staged_timing_last_us: Dictionary = {}
var _staged_cpu_lifetime_totals_us: Dictionary = {}
var _reveal_history: Array[Dictionary] = []
var _recent_immediate_update_usec: Array[int] = []
var _recent_deep_completion_usec: Array[int] = []
var _profiling_accumulated_usec := 0
var _profiling_enabled_since_usec := 0
var _immediate_update_count := 0
var _immediate_update_reason_counts: Dictionary = {}
# Lifecycle vocabulary is intentionally non-overlapping:
# - Canceled: an explicitly canceled pending request produced no result.
# - Invalidated before run: aim/table/config/effect changed before simulation began.
# - Blocked before run: the request reached the availability gate, but simulation
#   could not start.
# - Discarded on arrival: a completed result failed its request ID/revision check.
# - Accepted: a matching completed result became eligible for presentation.
# - Later invalidated: an accepted/shown result became stale after a later change.
# - Hidden by new aim: that stale displayed geometry was removed for new input.
# - Cache reused: an exact validated cached result was shown without simulation.
var _deep_requests_created := 0
var _deep_requests_forced := 0
var _deep_requests_canceled_before_run := 0
var _deep_requests_invalidated_before_run := 0
var _deep_requests_blocked_before_run := 0
var _deep_results_completed := 0
var _deep_results_accepted := 0
var _deep_results_discarded_on_arrival := 0
var _deep_results_rejected_revision_mismatch := 0
var _deep_results_rejected_request_id_mismatch := 0
var _accepted_results_shown := 0
var _shown_results_later_invalidated := 0
var _shown_results_hidden_by_new_aim := 0
var _shown_results_reused_from_cache := 0
var _deep_cache_hits := 0
var _deep_cache_misses := 0
var _cached_results_accepted := 0
var _cached_results_rejected := 0
var _reveal_completed_count := 0
var _reveal_interrupted_count := 0
var _reveal_completed_before_next_aim_count := 0
var _request_cancel_reason_counts: Dictionary = {}
var _request_invalidation_reason_counts: Dictionary = {}
var _request_block_reason_counts: Dictionary = {}
var _result_discard_reason_counts: Dictionary = {}
var _display_invalidation_reason_counts: Dictionary = {}
var _reveal_interruption_reason_counts: Dictionary = {}
var _reveal_sample_count := 0
var _ready_hidden_total := 0


func set_enabled(enabled_value: bool) -> void:
	if enabled_value == enabled:
		return
	var now_usec: int = Time.get_ticks_usec()
	if enabled_value:
		_profiling_enabled_since_usec = now_usec
	elif _profiling_enabled_since_usec > 0:
		_profiling_accumulated_usec += maxi(now_usec - _profiling_enabled_since_usec, 0)
		_profiling_enabled_since_usec = 0
	enabled = enabled_value


func reset(cache_snapshot: Dictionary = {}) -> void:
	_history.clear()
	_phase_totals_us.clear()
	_phase_maximums_us.clear()
	_last_sample.clear()
	_reason_counts.clear()
	_player_request_class_counts.clear()
	_recent_completion_usec.clear()
	_rebuilds_per_second = 0.0
	_cache_rebuild_baseline = int(cache_snapshot.get("rebuild_count", 0))
	_cache_hit_baseline = int(cache_snapshot.get("cache_hit_count", 0))
	_staged_timing_history.clear()
	_staged_timing_totals_us.clear()
	_staged_timing_maximums_us.clear()
	_staged_timing_last_us.clear()
	_staged_cpu_lifetime_totals_us.clear()
	_reveal_history.clear()
	_recent_immediate_update_usec.clear()
	_recent_deep_completion_usec.clear()
	_profiling_accumulated_usec = 0
	_profiling_enabled_since_usec = Time.get_ticks_usec() if enabled else 0
	_immediate_update_count = 0
	_immediate_update_reason_counts.clear()
	_deep_requests_created = 0
	_deep_requests_forced = 0
	_deep_requests_canceled_before_run = 0
	_deep_requests_invalidated_before_run = 0
	_deep_requests_blocked_before_run = 0
	_deep_results_completed = 0
	_deep_results_accepted = 0
	_deep_results_discarded_on_arrival = 0
	_deep_results_rejected_revision_mismatch = 0
	_deep_results_rejected_request_id_mismatch = 0
	_accepted_results_shown = 0
	_shown_results_later_invalidated = 0
	_shown_results_hidden_by_new_aim = 0
	_shown_results_reused_from_cache = 0
	_deep_cache_hits = 0
	_deep_cache_misses = 0
	_cached_results_accepted = 0
	_cached_results_rejected = 0
	_reveal_completed_count = 0
	_reveal_interrupted_count = 0
	_reveal_completed_before_next_aim_count = 0
	_request_cancel_reason_counts.clear()
	_request_invalidation_reason_counts.clear()
	_request_block_reason_counts.clear()
	_result_discard_reason_counts.clear()
	_display_invalidation_reason_counts.clear()
	_reveal_interruption_reason_counts.clear()
	_reveal_sample_count = 0
	_ready_hidden_total = 0


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
	var request_class: String = str(normalized_sample.get("player_request_class", "unclassified"))
	_player_request_class_counts[request_class] = int(
		_player_request_class_counts.get(request_class, 0)
	) + 1
	_record_completion_time(int(normalized_sample.get("completed_usec", Time.get_ticks_usec())))


func record_immediate_update(
	cpu_usec: int,
	reason: String = "immediate_preview_drag"
) -> void:
	if not enabled:
		return
	_immediate_update_count += 1
	_immediate_update_reason_counts[reason] = int(
		_immediate_update_reason_counts.get(reason, 0)
	) + 1
	_record_staged_timing("immediate_update_cpu", cpu_usec)
	_record_rate_event(_recent_immediate_update_usec, Time.get_ticks_usec())


func note_deep_request_created(forced: bool) -> void:
	if not enabled:
		return
	_deep_requests_created += 1
	if forced:
		_deep_requests_forced += 1


func note_deep_request_forced() -> void:
	if enabled:
		_deep_requests_forced += 1


func note_deep_compute_started(compute_start_latency_usec: int) -> void:
	if not enabled:
		return
	_record_staged_timing("deep_compute_start_latency", compute_start_latency_usec)


func note_deep_completion(
	compute_usec: int,
	accepted: bool,
	cache_hit: bool,
	rejection_reason: String = "",
	cache_attempted: bool = true
) -> void:
	if not enabled:
		return
	_deep_results_completed += 1
	if cache_attempted:
		if cache_hit:
			_deep_cache_hits += 1
		else:
			_deep_cache_misses += 1
	if accepted:
		_deep_results_accepted += 1
		if cache_hit:
			_cached_results_accepted += 1
	elif rejection_reason in ["discarded_request_id_mismatch", "discarded_revision_mismatch"]:
		_deep_results_discarded_on_arrival += 1
		_increment_bounded_reason(_result_discard_reason_counts, rejection_reason)
		if rejection_reason == "discarded_request_id_mismatch":
			_deep_results_rejected_request_id_mismatch += 1
		else:
			_deep_results_rejected_revision_mismatch += 1
		if cache_hit:
			_cached_results_rejected += 1
	_record_staged_timing("deep_compute_duration", compute_usec)
	_record_rate_event(_recent_deep_completion_usec, Time.get_ticks_usec())


func note_deep_request_canceled_before_run(reason: String) -> void:
	if not enabled:
		return
	_deep_requests_canceled_before_run += 1
	_increment_bounded_reason(_request_cancel_reason_counts, reason)


func note_deep_request_invalidated_before_run(reason: String) -> void:
	if not enabled:
		return
	_deep_requests_invalidated_before_run += 1
	_increment_bounded_reason(_request_invalidation_reason_counts, reason)


func note_deep_request_blocked_before_run(reason: String) -> void:
	if not enabled:
		return
	_deep_requests_blocked_before_run += 1
	_increment_bounded_reason(_request_block_reason_counts, reason)


func note_deep_visible(first_visible_latency_usec: int, cache_hit: bool = false) -> void:
	if not enabled:
		return
	_accepted_results_shown += 1
	_record_staged_timing("deep_first_visible_latency_us", first_visible_latency_usec)
	if cache_hit:
		_shown_results_reused_from_cache += 1
		_record_staged_timing("cache_hit_first_visible_latency_us", first_visible_latency_usec)


func note_shown_result_later_invalidated(reason: String, hidden_by_new_aim: bool) -> void:
	if not enabled:
		return
	_shown_results_later_invalidated += 1
	if hidden_by_new_aim:
		_shown_results_hidden_by_new_aim += 1
	_increment_bounded_reason(_display_invalidation_reason_counts, reason)


func note_reveal_completed(
	fully_visible_latency_usec: int,
	actual_reveal_duration_usec: int
) -> void:
	if not enabled:
		return
	_reveal_completed_count += 1
	# Invalidation interrupts an active reveal first, so every recorded completion
	# is necessarily a completion before the next meaningful aim state.
	_reveal_completed_before_next_aim_count += 1
	_record_staged_timing("deep_fully_visible_latency_us", fully_visible_latency_usec)
	_record_staged_timing("reveal_duration_actual", actual_reveal_duration_usec)


func note_reveal_interrupted(reason: String) -> void:
	if not enabled:
		return
	_reveal_interrupted_count += 1
	_increment_bounded_reason(_reveal_interruption_reason_counts, reason)


func record_reveal_sample(
	preparation_usec: int,
	draw_usec: int,
	visible_depth: int,
	visible_branches: int,
	ready_hidden_count: int
) -> void:
	if not enabled:
		return
	var sample: Dictionary = {
		"preparation_us": maxi(preparation_usec, 0),
		"draw_us": maxi(draw_usec, 0),
		"visible_depth": maxi(visible_depth, 0),
		"visible_branches": maxi(visible_branches, 0),
		"ready_hidden_count": maxi(ready_hidden_count, 0),
	}
	_reveal_sample_count += 1
	_ready_hidden_total += int(sample.get("ready_hidden_count", 0))
	_reveal_history.append(sample)
	if _reveal_history.size() > HISTORY_LIMIT:
		_reveal_history.pop_front()
	if preparation_usec > 0:
		_record_staged_timing("reveal_preparation_cpu", preparation_usec)
	if draw_usec > 0:
		_record_staged_timing("reveal_cpu_presentation", draw_usec)


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
		"last_rebuild_reason": str(_last_sample.get("rebuild_reason", "none")),
		"rebuild_reason_counts": _reason_counts.duplicate(true),
		"player_request_class_counts": _player_request_class_counts.duplicate(true),
		"staged_prediction": _make_staged_prediction_snapshot(),
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


func _record_staged_timing(metric_key: String, value_usec: int) -> void:
	var normalized_usec: int = maxi(value_usec, 0)
	var history: Array = _staged_timing_history.get(metric_key, [])
	history.append(normalized_usec)
	_staged_timing_totals_us[metric_key] = int(
		_staged_timing_totals_us.get(metric_key, 0)
	) + normalized_usec
	_staged_timing_maximums_us[metric_key] = maxi(
		int(_staged_timing_maximums_us.get(metric_key, 0)),
		normalized_usec
	)
	_staged_timing_last_us[metric_key] = normalized_usec
	if metric_key in STAGED_CPU_TIMING_KEYS:
		_staged_cpu_lifetime_totals_us[metric_key] = int(
			_staged_cpu_lifetime_totals_us.get(metric_key, 0)
		) + normalized_usec
	if history.size() > HISTORY_LIMIT:
		var removed_usec: int = int(history.pop_front())
		_staged_timing_totals_us[metric_key] = maxi(
			int(_staged_timing_totals_us.get(metric_key, 0)) - removed_usec,
			0
		)
		if removed_usec >= int(_staged_timing_maximums_us.get(metric_key, 0)):
			var maximum_usec := 0
			for history_value in history:
				maximum_usec = maxi(maximum_usec, int(history_value))
			_staged_timing_maximums_us[metric_key] = maximum_usec
	_staged_timing_history[metric_key] = history


func _record_rate_event(history: Array[int], event_usec: int) -> void:
	history.append(event_usec)
	while history.size() > RATE_EVENT_LIMIT:
		history.pop_front()
	_prune_rate_history(history, event_usec)


func _prune_rate_history(history: Array[int], now_usec: int) -> void:
	var cutoff_usec: int = now_usec - 1000000
	while not history.is_empty() and history[0] < cutoff_usec:
		history.pop_front()


func _make_staged_prediction_snapshot() -> Dictionary:
	var counters: Dictionary = {
		"immediate_updates": _immediate_update_count,
		"deep_requests_created": _deep_requests_created,
		"deep_requests_forced": _deep_requests_forced,
		"deep_requests_canceled_before_run": _deep_requests_canceled_before_run,
		"deep_requests_invalidated_before_run": _deep_requests_invalidated_before_run,
		"deep_requests_blocked_before_run": _deep_requests_blocked_before_run,
		"deep_results_completed": _deep_results_completed,
		"deep_results_accepted": _deep_results_accepted,
		"deep_results_discarded_on_arrival": _deep_results_discarded_on_arrival,
		"deep_results_rejected_revision_mismatch": _deep_results_rejected_revision_mismatch,
		"deep_results_rejected_request_id_mismatch": _deep_results_rejected_request_id_mismatch,
		"accepted_results_shown": _accepted_results_shown,
		"shown_results_later_invalidated": _shown_results_later_invalidated,
		"shown_results_hidden_by_new_aim": _shown_results_hidden_by_new_aim,
		"shown_results_reused_from_cache": _shown_results_reused_from_cache,
		"deep_cache_hits": _deep_cache_hits,
		"deep_cache_misses": _deep_cache_misses,
		"cached_results_accepted": _cached_results_accepted,
		"cached_results_rejected": _cached_results_rejected,
		"reveal_completed_count": _reveal_completed_count,
		"reveal_interrupted_count": _reveal_interrupted_count,
		"reveal_completed_before_next_aim_count": _reveal_completed_before_next_aim_count,
		"reveal_samples": _reveal_sample_count,
		"ready_hidden_count": _ready_hidden_total,
		"ready_hidden_total": _ready_hidden_total,
		"immediate_update_reason_counts": _immediate_update_reason_counts.duplicate(true),
		"request_cancel_reason_counts": _request_cancel_reason_counts.duplicate(true),
		"request_invalidation_reason_counts": _request_invalidation_reason_counts.duplicate(true),
		"request_block_reason_counts": _request_block_reason_counts.duplicate(true),
		"result_discard_reason_counts": _result_discard_reason_counts.duplicate(true),
		"display_invalidation_reason_counts": _display_invalidation_reason_counts.duplicate(true),
		"reveal_interruption_reason_counts": _reveal_interruption_reason_counts.duplicate(true),
	}
	if not enabled:
		return {
			"enabled": false,
			"history_limit": HISTORY_LIMIT,
			"timing_stats": {},
			"counters": counters,
			"updates_per_second": 0.0,
			"predictions_per_second": 0.0,
			"immediate_updates_per_second": 0.0,
			"deep_predictions_per_second": 0.0,
			"cpu_totals_us": {},
			"cpu_shares_percent": {},
			"wall_time_cpu_share_percent": 0.0,
			"reveal_workload": {},
		}

	var now_usec: int = Time.get_ticks_usec()
	_prune_rate_history(_recent_immediate_update_usec, now_usec)
	_prune_rate_history(_recent_deep_completion_usec, now_usec)
	var timing_stats: Dictionary = {}
	for metric_key in STAGED_TIMING_KEYS:
		timing_stats[metric_key] = _make_staged_timing_stats(metric_key)

	var cpu_totals_us: Dictionary = {
		"immediate_update": int(
			_staged_cpu_lifetime_totals_us.get("immediate_update_cpu", 0)
		),
		"deep_compute": int(_staged_cpu_lifetime_totals_us.get("deep_compute_duration", 0)),
		"reveal_preparation": int(
			_staged_cpu_lifetime_totals_us.get("reveal_preparation_cpu", 0)
		),
		"reveal_cpu_presentation": int(
			_staged_cpu_lifetime_totals_us.get("reveal_cpu_presentation", 0)
		),
	}
	var combined_cpu_us: int = 0
	for cpu_value in cpu_totals_us.values():
		combined_cpu_us += int(cpu_value)
	cpu_totals_us["combined"] = combined_cpu_us
	var cpu_shares: Dictionary = {}
	for cpu_key_value in cpu_totals_us.keys():
		var cpu_key: String = str(cpu_key_value)
		cpu_shares[cpu_key] = (
			100.0 * float(cpu_totals_us.get(cpu_key, 0)) / float(combined_cpu_us)
			if combined_cpu_us > 0
			else 0.0
		)
	var elapsed_usec: int = _profiling_accumulated_usec
	if _profiling_enabled_since_usec > 0:
		elapsed_usec += maxi(now_usec - _profiling_enabled_since_usec, 0)
	var update_rate: float = float(_recent_immediate_update_usec.size())
	var prediction_rate: float = float(_recent_deep_completion_usec.size())
	return {
		"enabled": true,
		"history_limit": HISTORY_LIMIT,
		"timing_stats": timing_stats,
		"counters": counters,
		"updates_per_second": update_rate,
		"predictions_per_second": prediction_rate,
		"immediate_updates_per_second": update_rate,
		"deep_predictions_per_second": prediction_rate,
		"cpu_totals_us": cpu_totals_us,
		"cpu_shares_percent": cpu_shares,
		"wall_time_cpu_share_percent": (
			100.0 * float(combined_cpu_us) / float(elapsed_usec)
			if elapsed_usec > 0
			else 0.0
		),
		"reveal_workload": {
			"visible_depth": _make_reveal_metric_stats("visible_depth"),
			"visible_branches": _make_reveal_metric_stats("visible_branches"),
			"ready_hidden_count": _make_reveal_metric_stats("ready_hidden_count"),
		},
	}


func _increment_bounded_reason(reason_counts: Dictionary, reason: String) -> void:
	var normalized_reason: String = reason.strip_edges()
	if normalized_reason.is_empty():
		normalized_reason = "unknown"
	if not reason_counts.has(normalized_reason) and reason_counts.size() >= LIFECYCLE_REASON_LIMIT:
		normalized_reason = "other"
	reason_counts[normalized_reason] = int(reason_counts.get(normalized_reason, 0)) + 1


func _make_staged_timing_stats(metric_key: String) -> Dictionary:
	var history: Array = _staged_timing_history.get(metric_key, [])
	var values: Array[int] = []
	for history_value in history:
		values.append(maxi(int(history_value), 0))
	var sample_count: int = values.size()
	return {
		"sample_count": sample_count,
		"last_us": int(_staged_timing_last_us.get(metric_key, 0)),
		"average_us": (
			float(_staged_timing_totals_us.get(metric_key, 0)) / float(sample_count)
			if sample_count > 0
			else 0.0
		),
		"p95_us": _get_percentile(values, 0.95),
		"maximum_us": int(_staged_timing_maximums_us.get(metric_key, 0)),
		"total_us": int(_staged_timing_totals_us.get(metric_key, 0)),
	}


func _make_reveal_metric_stats(metric_key: String) -> Dictionary:
	var values: Array[int] = []
	var total := 0
	for sample in _reveal_history:
		var metric_value: int = maxi(int(sample.get(metric_key, 0)), 0)
		values.append(metric_value)
		total += metric_value
	return {
		"sample_count": values.size(),
		"last": values.back() if not values.is_empty() else 0,
		"average": float(total) / float(values.size()) if not values.is_empty() else 0.0,
		"p95": _get_percentile(values, 0.95),
		"maximum": values.max() if not values.is_empty() else 0,
	}
