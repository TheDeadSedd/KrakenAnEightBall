extends Node
class_name ShotLedgerSystem

signal shot_ledger_completed(ledger: Dictionary)

# Completed schema v1 is value-only and intentionally shared with future
# predicted ledgers:
# schema/source/shot/mode/timing/cue identity, starting_balls, ordered
# raw_events, ending_balls, pocketed_ball_ids, derived facts, and diagnostics.
const SCHEMA_VERSION := 2
const SOURCE_AUTHORITATIVE := "authoritative"
const REWIND_STATE_VERSION := 1
const MEANINGFUL_IMPACT_EPSILON := 0.01
const MOVEMENT_EPSILON_SQUARED := 0.000001
const MAX_TRAVEL_STEP_DISTANCE := 256.0
const ANALYZER := preload("res://scripts/ShotLedgerAnalyzer.gd")
const SELF_TEST_STATUS_PASS := "PASS"
const SELF_TEST_STATUS_FAIL := "FAIL"
const SELF_TEST_STATUS_ERROR := "ERROR"

static var _session_self_test_result: Dictionary = {}

var table: BilliardsTable
var current_shot: Dictionary = {}
var last_completed_ledger: Dictionary = {}
var next_shot_id := 1
var next_attempt_id := 1
var total_completed_shots := 0
var total_canceled_shots := 0
var lifecycle_misuse_count := 0
var lifecycle_misuse_by_reason: Dictionary = {}
var last_lifecycle_misuse: Dictionary = {}
var global_invalid_event_count := 0
var global_duplicate_pocket_count := 0
var global_travel_teleport_count := 0
var last_cancel_reason := ""
var last_self_test_result: Dictionary = {}

var active_last_positions: Dictionary = {}
var active_travel_distances: Dictionary = {}
var active_pocketed_ball_ids: Array[int] = []
var active_pocketed_ball_set: Dictionary = {}
var active_pocket_capture_by_ball: Dictionary = {}
var active_semantic_pair_set: Dictionary = {}
var active_diagnostics: Dictionary = {}


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	current_shot.clear()
	last_completed_ledger.clear()
	next_shot_id = 1
	next_attempt_id = 1
	total_completed_shots = 0
	total_canceled_shots = 0
	lifecycle_misuse_count = 0
	lifecycle_misuse_by_reason.clear()
	last_lifecycle_misuse.clear()
	global_invalid_event_count = 0
	global_duplicate_pocket_count = 0
	global_travel_teleport_count = 0
	last_cancel_reason = ""
	last_self_test_result = _session_self_test_result.duplicate(true)
	_clear_active_value_state()


func begin_shot(context: Dictionary) -> void:
	if is_shot_active():
		_record_lifecycle_misuse("begin_while_active", "begin_shot")
		cancel_active_shot("begin_shot_replaced_active_recording")
	if not _is_valid_shot_context(context):
		_record_lifecycle_misuse("invalid_shot_context", "begin_shot")

	var starting_balls: Dictionary = _dictionary_value(context, "starting_balls").duplicate(true)
	var started_at_usec: int = Time.get_ticks_usec()
	current_shot = {
		"schema_version": SCHEMA_VERSION,
		"source": SOURCE_AUTHORITATIVE,
		"shot_id": next_shot_id,
		"attempt_id": next_attempt_id,
		"run_generation": int(context.get("run_generation", -1)),
		"mode_id": str(context.get("mode_id", "")),
		"round_index": int(context.get("round_index", -1)),
		"round_number": int(context.get("round_number", -1)),
		"passage_index": int(context.get("passage_index", -1)),
		"shot_lab_active": bool(context.get("shot_lab_active", false)),
		"shot_lab_preset_id": str(context.get("shot_lab_preset_id", "")),
		"started_at_usec": started_at_usec,
		"ended_at_usec": 0,
		"duration_sec": 0.0,
		"cue_ball_id": int(context.get("cue_ball_id", -1)),
		"ball_id_strategy": str(context.get("ball_id_strategy", "run_local_monotonic")),
		"starting_balls": starting_balls,
		"raw_events": [],
	}
	next_shot_id += 1
	next_attempt_id += 1
	_clear_active_value_state()
	active_diagnostics = _make_empty_diagnostics()
	for ball_key_value in starting_balls.keys():
		var ball_key: String = str(ball_key_value)
		var snapshot_value: Variant = starting_balls[ball_key_value]
		if not snapshot_value is Dictionary:
			active_diagnostics["invalid_ball_snapshots"] = int(active_diagnostics["invalid_ball_snapshots"]) + 1
			global_invalid_event_count += 1
			continue
		var snapshot: Dictionary = snapshot_value
		var position_value: Variant = snapshot.get("start_position", Vector2.ZERO)
		if not position_value is Vector2 or not _is_finite_vector(position_value):
			active_diagnostics["invalid_ball_snapshots"] = int(active_diagnostics["invalid_ball_snapshots"]) + 1
			global_invalid_event_count += 1
			continue
		active_last_positions[ball_key] = position_value
		active_travel_distances[ball_key] = 0.0


func record_ball_contact(event: Dictionary) -> bool:
	if not is_shot_active():
		_record_lifecycle_misuse("record_event_without_active", "record_ball_contact")
		return false
	if not bool(event.get("accepted_impact", false)):
		record_suppressed_ball_contact(
			int(event.get("ball_a_id", -1)),
			int(event.get("ball_b_id", -1)),
			"separation_only"
		)
		return false
	var relative_normal_speed: float = float(event.get("relative_normal_speed", 0.0))
	if not is_finite(relative_normal_speed) or relative_normal_speed <= MEANINGFUL_IMPACT_EPSILON:
		record_suppressed_ball_contact(
			int(event.get("ball_a_id", -1)),
			int(event.get("ball_b_id", -1)),
			"below_impact_epsilon"
		)
		return false
	if not _validate_contact_vectors(event):
		active_diagnostics["invalid_events"] = int(active_diagnostics["invalid_events"]) + 1
		global_invalid_event_count += 1
		return false

	var accepted_event: Dictionary = event.duplicate(true)
	var ball_a_id: int = int(accepted_event.get("ball_a_id", -1))
	var ball_b_id: int = int(accepted_event.get("ball_b_id", -1))
	var source_target: Dictionary = _determine_contact_source_target(accepted_event)
	accepted_event["source_ball_id"] = int(source_target.get("source_ball_id", -1))
	accepted_event["target_ball_id"] = int(source_target.get("target_ball_id", -1))
	accepted_event["causal_direction_ambiguous"] = bool(source_target.get("ambiguous", true))
	_append_event("ball_contact", accepted_event)
	active_semantic_pair_set[_pair_key(ball_a_id, ball_b_id)] = true
	return true


func record_suppressed_ball_contact(ball_a_id: int, ball_b_id: int, reason: String) -> void:
	if not is_shot_active():
		return
	var pair_key: String = _pair_key(ball_a_id, ball_b_id)
	if active_semantic_pair_set.has(pair_key):
		active_diagnostics["suppressed_sustained_ball_overlaps"] = int(active_diagnostics["suppressed_sustained_ball_overlaps"]) + 1
	else:
		active_diagnostics["suppressed_separation_only_ball_contacts"] = int(active_diagnostics["suppressed_separation_only_ball_contacts"]) + 1
	var reason_counts: Dictionary = active_diagnostics["suppressed_ball_contact_reasons"]
	reason_counts[reason] = int(reason_counts.get(reason, 0)) + 1


func record_rail_contact(event: Dictionary) -> bool:
	if not is_shot_active():
		_record_lifecycle_misuse("record_event_without_active", "record_rail_contact")
		return false
	var normal_speed: float = float(event.get("normal_speed", 0.0))
	if not is_finite(normal_speed) or normal_speed <= MEANINGFUL_IMPACT_EPSILON:
		active_diagnostics["invalid_events"] = int(active_diagnostics["invalid_events"]) + 1
		global_invalid_event_count += 1
		return false
	if not _validate_rail_vectors(event):
		active_diagnostics["invalid_events"] = int(active_diagnostics["invalid_events"]) + 1
		global_invalid_event_count += 1
		return false
	_append_event("rail_contact", event)
	return true


func record_suppressed_rail_clamps(count: int = 1) -> void:
	if not is_shot_active() or count <= 0:
		return
	active_diagnostics["suppressed_rail_clamps_without_bounce"] = int(active_diagnostics["suppressed_rail_clamps_without_bounce"]) + count


func record_pocket(event: Dictionary) -> bool:
	if not is_shot_active():
		_record_lifecycle_misuse("record_event_without_active", "record_pocket")
		return false
	var ball_id: int = int(event.get("ball_id", -1))
	var ball_key: String = str(ball_id)
	if active_pocketed_ball_set.has(ball_key):
		active_diagnostics["suppressed_duplicate_pocket_attempts"] = int(active_diagnostics["suppressed_duplicate_pocket_attempts"]) + 1
		global_duplicate_pocket_count += 1
		return false
	var capture_position_value: Variant = event.get("capture_position", Vector2.ZERO)
	if not capture_position_value is Vector2 or not _is_finite_vector(capture_position_value):
		active_diagnostics["invalid_events"] = int(active_diagnostics["invalid_events"]) + 1
		global_invalid_event_count += 1
		return false
	record_ball_position(ball_id, capture_position_value)
	_append_event("pocket", event)
	active_pocketed_ball_set[ball_key] = true
	active_pocketed_ball_ids.append(ball_id)
	active_pocket_capture_by_ball[ball_key] = {
		"position": capture_position_value,
		"event_index": _get_last_event_index(),
	}
	active_last_positions.erase(ball_key)
	return true


func record_ball_position(ball_id: int, position: Vector2) -> void:
	if not is_shot_active():
		return
	var ball_key: String = str(ball_id)
	if active_pocketed_ball_set.has(ball_key) or not active_last_positions.has(ball_key):
		return
	if not _is_finite_vector(position):
		active_diagnostics["invalid_travel_samples"] = int(active_diagnostics["invalid_travel_samples"]) + 1
		global_invalid_event_count += 1
		return
	var previous_position_value: Variant = active_last_positions.get(ball_key, position)
	if not previous_position_value is Vector2 or not _is_finite_vector(previous_position_value):
		active_last_positions[ball_key] = position
		active_diagnostics["invalid_travel_samples"] = int(active_diagnostics["invalid_travel_samples"]) + 1
		global_invalid_event_count += 1
		return
	var delta: Vector2 = position - previous_position_value
	var distance_squared: float = delta.length_squared()
	if distance_squared > MAX_TRAVEL_STEP_DISTANCE * MAX_TRAVEL_STEP_DISTANCE:
		active_last_positions[ball_key] = position
		active_diagnostics["suppressed_travel_teleports"] = int(active_diagnostics["suppressed_travel_teleports"]) + 1
		global_travel_teleport_count += 1
		return
	if distance_squared > MOVEMENT_EPSILON_SQUARED:
		active_travel_distances[ball_key] = float(active_travel_distances.get(ball_key, 0.0)) + sqrt(distance_squared)
	active_last_positions[ball_key] = position


func finalize_shot(final_state: Dictionary) -> Dictionary:
	if not is_shot_active():
		_record_lifecycle_misuse("finalize_without_active", "finalize_shot")
		return {}
	var ended_at_usec: int = Time.get_ticks_usec()
	var ledger: Dictionary = current_shot.duplicate(true)
	ledger["ended_at_usec"] = ended_at_usec
	ledger["duration_sec"] = maxf(
		float(ended_at_usec - int(ledger.get("started_at_usec", ended_at_usec))) / 1000000.0,
		0.0
	)
	ledger["ending_balls"] = _build_completed_ending_balls(final_state)
	ledger["pocketed_ball_ids"] = active_pocketed_ball_ids.duplicate()
	ledger["diagnostics"] = active_diagnostics.duplicate(true)
	var completion_diagnostics: Dictionary = ledger["diagnostics"]
	completion_diagnostics["lifecycle_misuse_count_at_completion"] = lifecycle_misuse_count

	var analysis_start_usec: int = Time.get_ticks_usec()
	ledger["derived"] = ANALYZER.analyze(ledger)
	var analysis_duration_usec: int = maxi(Time.get_ticks_usec() - analysis_start_usec, 0)
	var diagnostics: Dictionary = ledger["diagnostics"]
	diagnostics["analysis_duration_usec"] = analysis_duration_usec
	diagnostics["completed_ledger_approximate_size_bytes"] = 0
	diagnostics["completed_ledger_approximate_size_bytes"] = var_to_bytes(ledger).size()

	last_completed_ledger = ledger.duplicate(true)
	total_completed_shots += 1
	_clear_active_recording()
	var emitted_ledger: Dictionary = last_completed_ledger.duplicate(true)
	shot_ledger_completed.emit(emitted_ledger)
	return emitted_ledger


func cancel_active_shot(reason: String, report_if_inactive: bool = false) -> void:
	if not is_shot_active():
		if report_if_inactive:
			_record_lifecycle_misuse("cancel_without_active", reason)
		return
	total_canceled_shots += 1
	last_cancel_reason = reason
	_clear_active_recording()


func is_shot_active() -> bool:
	return not current_shot.is_empty()


func get_last_completed_ledger() -> Dictionary:
	return last_completed_ledger.duplicate(true)


func capture_rewind_state() -> Dictionary:
	return {
		"version": REWIND_STATE_VERSION,
		"next_shot_id": next_shot_id,
		"next_attempt_id": next_attempt_id,
		"last_completed_ledger": last_completed_ledger.duplicate(true),
	}


func restore_rewind_state(state: Dictionary) -> void:
	if is_shot_active():
		_record_lifecycle_misuse("restore_while_active", "restore_rewind_state")
	_clear_active_recording()
	if int(state.get("version", 0)) != REWIND_STATE_VERSION:
		last_completed_ledger.clear()
		return
	next_shot_id = maxi(int(state.get("next_shot_id", 1)), 1)
	# attempt_id identifies physical attempts, including discarded timelines.
	next_attempt_id = maxi(
		maxi(next_attempt_id, int(state.get("next_attempt_id", 1))),
		1
	)
	last_completed_ledger = _dictionary_value(state, "last_completed_ledger").duplicate(true)
	# Completed/canceled attempt counts and diagnostic evidence are session-wide,
	# not timeline state. Reset Last Shot must never erase them.
	last_self_test_result = _session_self_test_result.duplicate(true)


func restore_completed_observation_after_rewind(ledger: Dictionary) -> void:
	# Shot Lab rewinds the physical setup after a scratch, but the just-completed
	# observation remains the result under inspection. Do not emit completion twice.
	if is_shot_active():
		_record_lifecycle_misuse("restore_observation_while_active", "shot_lab_scratch_restore")
		return
	last_completed_ledger = ledger.duplicate(true)


func run_self_tests() -> Dictionary:
	var started_at_usec: int = Time.get_ticks_usec()
	var run_timestamp: String = Time.get_datetime_string_from_system(false, true)
	if ANALYZER == null:
		return _store_self_test_error("Analyzer unavailable.", run_timestamp, started_at_usec)

	var result_value: Variant = ANALYZER.run_self_tests()
	if not result_value is Dictionary:
		return _store_self_test_error(
			"Self-test construction failure: analyzer returned %s instead of Dictionary." % type_string(typeof(result_value)),
			run_timestamp,
			started_at_usec
		)

	var result: Dictionary = (result_value as Dictionary).duplicate(true)
	var validation_error: String = _get_self_test_validation_error(result)
	if not validation_error.is_empty():
		return _store_self_test_error(validation_error, run_timestamp, started_at_usec)

	var total_count: int = int(result.get("total_count", 0))
	var passed_count: int = int(result.get("passed_count", 0))
	var failed_count: int = int(result.get("failed_count", 0))
	result["last_run_timestamp"] = run_timestamp
	result["duration_usec"] = maxi(Time.get_ticks_usec() - started_at_usec, 0)
	result["expected_test_count"] = int(ANALYZER.SELF_TEST_CASE_COUNT)
	result["status"] = SELF_TEST_STATUS_PASS if failed_count == 0 and passed_count == total_count else SELF_TEST_STATUS_FAIL
	result["error_message"] = ""
	last_self_test_result = result
	_session_self_test_result = result.duplicate(true)
	return last_self_test_result.duplicate(true)


func _get_self_test_validation_error(result: Dictionary) -> String:
	if result.is_empty():
		return "Empty self-test result."

	var tests_value: Variant = result.get("tests", null)
	if not tests_value is Array:
		return "Self-test construction failure: tests collection is unavailable."
	var tests: Array = tests_value as Array
	var total_count: int = int(result.get("total_count", 0))
	var passed_count: int = int(result.get("passed_count", -1))
	var failed_count: int = int(result.get("failed_count", -1))
	if total_count <= 0 or tests.is_empty():
		return "Empty self-test result."
	if total_count != tests.size():
		return "Self-test construction failure: total count %d does not match %d test rows." % [total_count, tests.size()]
	if passed_count < 0 or failed_count < 0 or passed_count + failed_count != total_count:
		return "Self-test construction failure: pass/fail counts do not match total tests."

	var failures_value: Variant = result.get("failures", null)
	if not failures_value is Array:
		return "Self-test construction failure: failure details are unavailable."
	for test_index in range(tests.size()):
		var test_value: Variant = tests[test_index]
		if not test_value is Dictionary:
			return "Self-test construction failure: test row %d is not a Dictionary." % test_index
		var test: Dictionary = test_value as Dictionary
		var test_failures_value: Variant = test.get("failures", null)
		if not test.has("name") or not test.has("passed") or not test_failures_value is Array:
			return "Self-test construction failure: test row %d is malformed." % test_index
	return ""


func _store_self_test_error(error_message: String, run_timestamp: String, started_at_usec: int) -> Dictionary:
	last_self_test_result = {
		"last_run_timestamp": run_timestamp,
		"duration_usec": maxi(Time.get_ticks_usec() - started_at_usec, 0),
		"expected_test_count": int(ANALYZER.SELF_TEST_CASE_COUNT) if ANALYZER != null else 0,
		"total_count": 0,
		"passed_count": 0,
		"failed_count": 0,
		"passed": false,
		"status": SELF_TEST_STATUS_ERROR,
		"error_message": error_message,
		"failures": [error_message],
		"tests": [],
	}
	_session_self_test_result = last_self_test_result.duplicate(true)
	push_error("Shot Ledger Self-Test: %s" % error_message)
	return last_self_test_result.duplicate(true)


func get_debug_snapshot() -> Dictionary:
	var active_snapshot: Dictionary = {}
	if is_shot_active():
		active_snapshot = {
			"shot_id": int(current_shot.get("shot_id", -1)),
			"attempt_id": int(current_shot.get("attempt_id", -1)),
			"run_generation": int(current_shot.get("run_generation", -1)),
			"source": str(current_shot.get("source", "")),
			"mode_id": str(current_shot.get("mode_id", "")),
			"round_index": int(current_shot.get("round_index", -1)),
			"round_number": int(current_shot.get("round_number", -1)),
			"passage_index": int(current_shot.get("passage_index", -1)),
			"shot_lab_active": bool(current_shot.get("shot_lab_active", false)),
			"shot_lab_preset_id": str(current_shot.get("shot_lab_preset_id", "")),
			"duration_sec": _get_shot_elapsed_sec(),
			"raw_event_count": _get_raw_events().size(),
			"diagnostics": active_diagnostics.duplicate(true),
		}
	var identity_snapshot: Dictionary = {}
	if table != null and table.run_ball_identity_system != null:
		identity_snapshot = table.run_ball_identity_system.get_debug_snapshot()
	return {
		"active": is_shot_active(),
		"active_shot": active_snapshot,
		"last_completed": last_completed_ledger.duplicate(true),
		"next_shot_id": next_shot_id,
		"next_attempt_id": next_attempt_id,
		"total_completed_shots": total_completed_shots,
		"total_canceled_shots": total_canceled_shots,
		"lifecycle_misuse_count": lifecycle_misuse_count,
		"lifecycle_misuse_by_reason": lifecycle_misuse_by_reason.duplicate(true),
		"last_lifecycle_misuse": last_lifecycle_misuse.duplicate(true),
		"global_invalid_event_count": global_invalid_event_count,
		"global_duplicate_pocket_count": global_duplicate_pocket_count,
		"global_travel_teleport_count": global_travel_teleport_count,
		"ball_identity": identity_snapshot,
		"last_cancel_reason": last_cancel_reason,
		"self_test_case_count": int(ANALYZER.SELF_TEST_CASE_COUNT),
		"last_self_test_result": last_self_test_result.duplicate(true),
	}


func get_last_completed_summary() -> String:
	if last_completed_ledger.is_empty():
		return "No completed Shot Ledger yet."
	var derived: Dictionary = _dictionary_value(last_completed_ledger, "derived")
	var diagnostics: Dictionary = _dictionary_value(last_completed_ledger, "diagnostics")
	var lines: PackedStringArray = PackedStringArray()
	lines.append("SHOT LEDGER v%d / %s" % [int(last_completed_ledger.get("schema_version", 0)), str(last_completed_ledger.get("source", ""))])
	lines.append("Shot %d | Attempt %d | Mode %s | %.3f sec" % [
		int(last_completed_ledger.get("shot_id", -1)),
		int(last_completed_ledger.get("attempt_id", -1)),
		str(last_completed_ledger.get("mode_id", "")),
		float(last_completed_ledger.get("duration_sec", 0.0)),
	])
	lines.append("Events: %d ball contacts, %d rail contacts, %d pockets" % [
		int(derived.get("semantic_ball_contact_count", 0)),
		int(derived.get("semantic_rail_contact_count", 0)),
		_array_value(last_completed_ledger, "pocketed_ball_ids").size(),
	])
	lines.append("First object contact: %s at event %s" % [
		int(derived.get("first_object_contact_ball_id", -1)),
		int(derived.get("first_object_contact_event_index", -1)),
	])
	lines.append("Object pockets: %s | Scratch: %s | Same-pocket max: %d" % [
		str(derived.get("object_balls_pocketed", [])),
		str(bool(derived.get("scratch_occurred", false))),
		int(derived.get("largest_same_pocket_count", 0)),
	])
	lines.append("Max causal depth: %d | Max bank count: %d" % [
		int(derived.get("maximum_causal_depth", 0)),
		int(derived.get("maximum_bank_count", 0)),
	])
	lines.append("Tags: %s" % _format_tag_ids(_array_value(derived, "tags")))
	lines.append("Cue travel: %.1f px | Object travel: %.1f px" % [
		float(derived.get("cue_ball_travel_distance", 0.0)),
		float(derived.get("total_object_ball_travel_distance", 0.0)),
	])
	lines.append("Analysis: %d usec | Approx size: %d bytes" % [
		int(diagnostics.get("analysis_duration_usec", 0)),
		int(diagnostics.get("completed_ledger_approximate_size_bytes", 0)),
	])
	return "\n".join(lines)


func get_last_completed_json() -> String:
	if last_completed_ledger.is_empty():
		return "{}"
	return JSON.stringify(_to_json_safe(last_completed_ledger), "  ")


func clear_diagnostic_counters() -> void:
	lifecycle_misuse_count = 0
	lifecycle_misuse_by_reason.clear()
	last_lifecycle_misuse.clear()
	global_invalid_event_count = 0
	global_duplicate_pocket_count = 0
	global_travel_teleport_count = 0
	last_cancel_reason = ""
	if table != null and table.run_ball_identity_system != null:
		table.run_ball_identity_system.clear_diagnostic_counters()


func get_lifecycle_diagnostics_summary() -> String:
	var identity: Dictionary = {}
	if table != null and table.run_ball_identity_system != null:
		identity = table.run_ball_identity_system.get_debug_snapshot()
	var lines: PackedStringArray = PackedStringArray([
		"SHOT LEDGER LIFECYCLE",
		"Active: %s | Shot: %d | Attempt: %d" % [
			str(is_shot_active()),
			int(current_shot.get("shot_id", -1)),
			int(current_shot.get("attempt_id", -1)),
		],
		"Completed: %d | Canceled: %d | Misuse: %d" % [
			total_completed_shots,
			total_canceled_shots,
			lifecycle_misuse_count,
		],
		"Invalid events: %d | Duplicate pockets: %d | Travel teleports: %d" % [
			global_invalid_event_count,
			global_duplicate_pocket_count,
			global_travel_teleport_count,
		],
		"Fallback ball IDs: %d | Duplicate ball IDs: %d | Restored IDs: %d" % [
			int(identity.get("missing_id_fallback_count", 0)),
			int(identity.get("duplicate_id_count", 0)),
			int(identity.get("restored_id_count", 0)),
		],
	])
	if not lifecycle_misuse_by_reason.is_empty():
		lines.append("Misuse reasons: %s" % str(lifecycle_misuse_by_reason))
	if not last_lifecycle_misuse.is_empty():
		lines.append("Last misuse: %s" % str(last_lifecycle_misuse))
	if not last_cancel_reason.is_empty():
		lines.append("Last cancel: %s" % last_cancel_reason)
	return "\n".join(lines)


func get_last_raw_events(event_type_filter: String = "", ball_id_filter: int = -1) -> Array:
	var filtered_events: Array = []
	if last_completed_ledger.is_empty():
		return filtered_events
	var raw_events: Array = _array_value(last_completed_ledger, "raw_events")
	for event_value in raw_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if not event_type_filter.is_empty() and str(event.get("event_type", "")) != event_type_filter:
			continue
		if ball_id_filter > 0 and not _event_mentions_ball(event, ball_id_filter):
			continue
		filtered_events.append(event.duplicate(true))
	return filtered_events


func get_last_raw_events_json(event_type_filter: String = "", ball_id_filter: int = -1) -> String:
	return JSON.stringify(_to_json_safe(get_last_raw_events(event_type_filter, ball_id_filter)), "  ")


func _append_event(event_type: String, event: Dictionary) -> void:
	var accepted_event: Dictionary = event.duplicate(true)
	accepted_event["event_index"] = _get_raw_events().size()
	accepted_event["event_type"] = event_type
	accepted_event["shot_elapsed_sec"] = _get_shot_elapsed_sec()
	_get_raw_events().append(accepted_event)


func _record_lifecycle_misuse(reason: String, context_label: String) -> void:
	var normalized_reason: String = reason if not reason.is_empty() else "unknown"
	lifecycle_misuse_count += 1
	lifecycle_misuse_by_reason[normalized_reason] = int(lifecycle_misuse_by_reason.get(normalized_reason, 0)) + 1
	var context_source: Dictionary = current_shot if is_shot_active() else last_completed_ledger
	last_lifecycle_misuse = {
		"reason": normalized_reason,
		"engine_timestamp_usec": Time.get_ticks_usec(),
		"shot_id": int(context_source.get("shot_id", -1)),
		"attempt_id": int(context_source.get("attempt_id", -1)),
		"mode_id": str(context_source.get("mode_id", table.get_game_mode_id() if table != null else "")),
		"context_label": context_label,
	}


func _is_valid_shot_context(context: Dictionary) -> bool:
	var starting_balls: Dictionary = _dictionary_value(context, "starting_balls")
	return (
		not starting_balls.is_empty()
		and int(context.get("cue_ball_id", -1)) > 0
		and not str(context.get("mode_id", "")).is_empty()
	)


func _event_mentions_ball(event: Dictionary, ball_id: int) -> bool:
	for key in ["ball_id", "ball_a_id", "ball_b_id", "source_ball_id", "target_ball_id"]:
		if int(event.get(key, -1)) == ball_id:
			return true
	return false


func _get_raw_events() -> Array:
	var events_value: Variant = current_shot.get("raw_events", [])
	if events_value is Array:
		return events_value
	return []


func _get_last_event_index() -> int:
	return _get_raw_events().size() - 1


func _get_shot_elapsed_sec() -> float:
	if not is_shot_active():
		return 0.0
	return maxf(
		float(Time.get_ticks_usec() - int(current_shot.get("started_at_usec", Time.get_ticks_usec()))) / 1000000.0,
		0.0
	)


func _determine_contact_source_target(event: Dictionary) -> Dictionary:
	var ball_a_id: int = int(event.get("ball_a_id", -1))
	var ball_b_id: int = int(event.get("ball_b_id", -1))
	var normal: Vector2 = event.get("contact_normal", Vector2.ZERO)
	var pre_velocity_a: Vector2 = event.get("pre_velocity_a", Vector2.ZERO)
	var pre_velocity_b: Vector2 = event.get("pre_velocity_b", Vector2.ZERO)
	var a_drive: float = maxf(pre_velocity_a.dot(normal), 0.0)
	var b_drive: float = maxf(-pre_velocity_b.dot(normal), 0.0)
	if a_drive > MEANINGFUL_IMPACT_EPSILON and b_drive <= MEANINGFUL_IMPACT_EPSILON:
		return {"source_ball_id": ball_a_id, "target_ball_id": ball_b_id, "ambiguous": false}
	if b_drive > MEANINGFUL_IMPACT_EPSILON and a_drive <= MEANINGFUL_IMPACT_EPSILON:
		return {"source_ball_id": ball_b_id, "target_ball_id": ball_a_id, "ambiguous": false}
	return {"source_ball_id": -1, "target_ball_id": -1, "ambiguous": true}


func _build_completed_ending_balls(final_state: Dictionary) -> Dictionary:
	var ending_balls: Dictionary = _dictionary_value(final_state, "ending_balls").duplicate(true)
	var starting_balls: Dictionary = _dictionary_value(current_shot, "starting_balls")
	for ball_key_value in ending_balls.keys():
		var ball_key: String = str(ball_key_value)
		var ending_value: Variant = ending_balls[ball_key_value]
		if not ending_value is Dictionary:
			ending_balls[ball_key_value] = {}
			continue
		var ending_snapshot: Dictionary = ending_value
		ending_snapshot["travel_distance"] = maxf(float(active_travel_distances.get(ball_key, 0.0)), 0.0)
		ending_snapshot["pocketed"] = active_pocketed_ball_set.has(ball_key) or bool(ending_snapshot.get("pocketed", false))

	for ball_key_value in starting_balls.keys():
		var ball_key: String = str(ball_key_value)
		if ending_balls.has(ball_key):
			continue
		var start_snapshot_value: Variant = starting_balls[ball_key_value]
		var start_snapshot: Dictionary = start_snapshot_value if start_snapshot_value is Dictionary else {}
		var fallback_position: Vector2 = start_snapshot.get("start_position", Vector2.ZERO)
		if active_last_positions.has(ball_key) and active_last_positions[ball_key] is Vector2:
			fallback_position = active_last_positions[ball_key]
		var pocket_capture: Dictionary = _dictionary_value(active_pocket_capture_by_ball, ball_key)
		if pocket_capture.get("position", null) is Vector2:
			fallback_position = pocket_capture["position"]
		ending_balls[ball_key] = {
			"ball_id": int(start_snapshot.get("ball_id", int(ball_key))),
			"active": false,
			"pocketed": active_pocketed_ball_set.has(ball_key),
			"final_position": fallback_position,
			"final_velocity": Vector2.ZERO,
			"travel_distance": maxf(float(active_travel_distances.get(ball_key, 0.0)), 0.0),
		}
	return ending_balls


func _validate_contact_vectors(event: Dictionary) -> bool:
	for key in ["contact_point", "contact_normal", "pre_velocity_a", "pre_velocity_b", "post_velocity_a", "post_velocity_b"]:
		var value: Variant = event.get(key, null)
		if not value is Vector2 or not _is_finite_vector(value):
			return false
	return true


func _validate_rail_vectors(event: Dictionary) -> bool:
	for key in ["contact_point", "contact_normal", "pre_velocity", "post_velocity"]:
		var value: Variant = event.get(key, null)
		if not value is Vector2 or not _is_finite_vector(value):
			return false
	return true


func _make_empty_diagnostics() -> Dictionary:
	return {
		"suppressed_separation_only_ball_contacts": 0,
		"suppressed_sustained_ball_overlaps": 0,
		"suppressed_ball_contact_reasons": {},
		"suppressed_rail_clamps_without_bounce": 0,
		"suppressed_duplicate_pocket_attempts": 0,
		"suppressed_travel_teleports": 0,
		"invalid_events": 0,
		"invalid_ball_snapshots": 0,
		"invalid_travel_samples": 0,
		"ball_id_strategy": str(current_shot.get("ball_id_strategy", "run_local_monotonic")),
		"lifecycle_misuse_count_at_shot_start": lifecycle_misuse_count,
	}


func _clear_active_recording() -> void:
	current_shot.clear()
	_clear_active_value_state()


func _clear_active_value_state() -> void:
	active_last_positions.clear()
	active_travel_distances.clear()
	active_pocketed_ball_ids.clear()
	active_pocketed_ball_set.clear()
	active_pocket_capture_by_ball.clear()
	active_semantic_pair_set.clear()
	active_diagnostics.clear()


func _pair_key(ball_a_id: int, ball_b_id: int) -> String:
	return "%d:%d" % [mini(ball_a_id, ball_b_id), maxi(ball_a_id, ball_b_id)]


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	if value is Dictionary:
		return value
	return {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	if value is Array:
		return value
	return []


func _format_tag_ids(tags: Array) -> String:
	if tags.is_empty():
		return "none"
	var tag_ids: PackedStringArray = PackedStringArray()
	for tag_value in tags:
		if tag_value is Dictionary:
			tag_ids.append(str((tag_value as Dictionary).get("tag_id", "")))
	return ", ".join(tag_ids)


func _to_json_safe(value: Variant) -> Variant:
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Dictionary:
		var converted_dictionary: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			converted_dictionary[str(key_value)] = _to_json_safe((value as Dictionary)[key_value])
		return converted_dictionary
	if value is Array:
		var converted_array: Array = []
		for item in value as Array:
			converted_array.append(_to_json_safe(item))
		return converted_array
	return value
