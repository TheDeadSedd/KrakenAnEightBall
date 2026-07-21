extends RefCounted
class_name RoguelitePredictedLedgerAdapter

# Converts one already-accepted cloned result into the value-only Shot Ledger
# shape consumed by the existing analyzer and resolver. It never simulates.

const PREDICTOR := preload("res://scripts/AimTrajectoryPredictor.gd")
const SHOT_LEDGER_SCRIPT := preload("res://scripts/ShotLedgerSystem.gd")

const MAX_SUPPRESSION_RECORDS := 64
const SUSTAINED_CONTACT_TIME_WINDOW_SEC := 0.030
const SUSTAINED_CONTACT_FRAME_WINDOW := 3
const SUSTAINED_CONTACT_POSITION_WINDOW_PX := 3.0
const MEANINGFUL_RECONTACT_TIME_SEC := 0.045
const MEANINGFUL_RECONTACT_POSITION_PX := 4.0


static func build(
	prediction_bundle: Dictionary,
	active_shot: Dictionary,
	prediction_source_to_run_id: Dictionary
) -> Dictionary:
	var diagnostics: Dictionary = {
		"valid": false,
		"reason": "not_built",
		"events_received": 0,
		"events_converted": 0,
		"events_retained": 0,
		"unmapped_ball_ids": 0,
		"unsupported_events": 0,
		"predicted_rail_events_received": 0,
		"rail_events_missing_name": 0,
		"rail_events_missing_normal": 0,
		"rail_events_missing_center": 0,
		"rail_events_missing_surface": 0,
		"rail_events_missing_radius": 0,
		"rail_events_eligible_for_exact_matching": 0,
		"rail_events_eligible_for_geometric_matching": 0,
		"rail_events_semantic_evidence_complete": 0,
		"rail_events_semantic_evidence_incomplete": 0,
		"rail_compatibility_warnings": [],
		"normalization": {},
	}
	var output: Dictionary = {
		"valid": false,
		"ledger": {},
		"diagnostics": diagnostics,
	}
	if not bool(prediction_bundle.get("accepted", false)):
		diagnostics["reason"] = str(prediction_bundle.get("status", "prediction_not_accepted"))
		return output
	var prediction: Dictionary = _dictionary_value(prediction_bundle, "prediction_result")
	var request_snapshot: Dictionary = _dictionary_value(prediction_bundle, "request_snapshot")
	var result_configuration: Dictionary = _dictionary_value(prediction, "configuration")
	var requested_result_mode: String = str(request_snapshot.get("result_detail_mode", ""))
	var result_mode: String = str(result_configuration.get("result_detail_mode", ""))
	var result_mode_source: String = "result_configuration"
	if result_mode.is_empty() and prediction.has("result_detail_mode"):
		result_mode = str(prediction.get("result_detail_mode", ""))
		result_mode_source = "prediction_result"
	if result_mode.is_empty():
		result_mode = requested_result_mode
		result_mode_source = "request_snapshot" if not result_mode.is_empty() else "missing"
	diagnostics["prediction_requested_result_mode"] = requested_result_mode
	diagnostics["prediction_result_mode"] = result_mode
	diagnostics["prediction_result_mode_source"] = result_mode_source
	diagnostics["prediction_result_mode_matches_request"] = (
		not requested_result_mode.is_empty()
		and not result_mode.is_empty()
		and requested_result_mode == result_mode
	)
	if (
		not requested_result_mode.is_empty()
		and not result_mode.is_empty()
		and requested_result_mode != result_mode
	):
		diagnostics["reason"] = "result_detail_mode_mismatch"
		return output
	if not bool(prediction.get("valid", false)):
		diagnostics["reason"] = "accepted_prediction_invalid"
		return output
	if active_shot.is_empty():
		diagnostics["reason"] = "active_shot_missing"
		return output

	var starting_balls: Dictionary = _dictionary_value(active_shot, "starting_balls").duplicate(true)
	var converted_events: Array[Dictionary] = []
	var unsupported_event_records: Array[Dictionary] = []
	var prediction_events: Array = _array_value(prediction, "events")
	diagnostics["events_received"] = prediction_events.size()
	for event_value in prediction_events:
		if not event_value is Dictionary:
			diagnostics["unsupported_events"] = int(diagnostics["unsupported_events"]) + 1
			continue
		var event: Dictionary = event_value
		var source_id: int = _map_source_id(event.get("source_ball_id", -1), prediction_source_to_run_id)
		var target_id: int = _map_source_id(event.get("target_ball_id", -1), prediction_source_to_run_id)
		var event_type: String = str(event.get("event_type", ""))
		var rail_semantic_evidence: Dictionary = {}
		if event_type == PREDICTOR.EVENT_RAIL_CONTACT:
			rail_semantic_evidence = _get_rail_semantic_evidence(event)
			_record_rail_semantic_diagnostics(
				diagnostics,
				rail_semantic_evidence,
				int(event.get("event_index", -1))
			)
		if not bool(event.get("supported", true)):
			diagnostics["unsupported_events"] = int(diagnostics["unsupported_events"]) + 1
			unsupported_event_records.append({
				"predictor_event_index": int(event.get("event_index", -1)),
				"event_type": event_type,
				"source_ball_id": source_id,
				"target_ball_id": target_id,
				"reason": str(event.get("unsupported_reason", "unsupported_event")),
			})
			continue
		if source_id <= 0:
			diagnostics["unmapped_ball_ids"] = int(diagnostics["unmapped_ball_ids"]) + 1
			continue
		var predictor_event_index: int = int(event.get(
			"event_index",
			converted_events.size()
		))
		var converted: Dictionary = {
			"event_index": predictor_event_index,
			"predictor_event_index": predictor_event_index,
			"shot_elapsed_sec": float(event.get("simulated_time", 0.0)),
			"physics_frame": int(event.get("physics_frame", -1)),
			"substep": int(event.get("substep", -1)),
		}
		match event_type:
			PREDICTOR.EVENT_BALL_CONTACT:
				if target_id <= 0:
					diagnostics["unmapped_ball_ids"] = int(diagnostics["unmapped_ball_ids"]) + 1
					continue
				var contact_normal: Vector2 = _vector_value(event, "collision_normal")
				var incoming_source: Vector2 = _vector_value(
					event,
					"incoming_source_velocity"
				)
				var incoming_target: Vector2 = _vector_value(
					event,
					"incoming_target_velocity"
				)
				var approach: Dictionary = _get_contact_approach_evidence(
					event,
					contact_normal,
					incoming_source,
					incoming_target
				)
				converted.merge({
					"event_type": "ball_contact",
					"ball_a_id": source_id,
					"ball_b_id": target_id,
					"source_ball_id": source_id,
					"target_ball_id": target_id,
					"accepted_impact": bool(approach.get("accepted_impact", true)),
					"approach_evidence_available": bool(approach.get("available", false)),
					"relative_normal_speed": float(approach.get("speed", 0.0)),
					"causal_direction_ambiguous": false,
					"contact_point": _vector_value(event, "contact_point"),
					"contact_normal": contact_normal,
					"ball_a_position": _vector_value(event, "source_center"),
					"ball_b_position": _vector_value(event, "target_center"),
					"pre_velocity_a": incoming_source,
					"pre_velocity_b": incoming_target,
					"post_velocity_a": _vector_value(event, "outgoing_source_velocity"),
					"post_velocity_b": _vector_value(event, "outgoing_target_velocity"),
					"impact_speed": float(event.get(
						"impact_speed",
						approach.get("speed", 0.0)
					)),
					"source_parent_contact_event": int(event.get(
						"source_parent_contact_event",
						-1
					)),
					"resolution_source": str(event.get("resolution_source", "prediction")),
				})
			PREDICTOR.EVENT_RAIL_CONTACT:
				var rail_name: String = str(rail_semantic_evidence.get("rail_name", ""))
				var rail_id: String = rail_name
				var rail_index: int = int(event.get("rail_index", -1))
				var rail_normal: Vector2 = _vector_value(event, "collision_normal")
				var rail_unit_normal: Vector2 = (
					rail_normal.normalized() if rail_normal != Vector2.ZERO else Vector2.ZERO
				)
				var rail_start_snapshot: Dictionary = _dictionary_value(
					starting_balls,
					str(source_id)
				)
				var ball_radius: float = maxf(float(event.get(
					"ball_radius",
					event.get("source_radius", rail_start_snapshot.get("radius", 0.0))
				)), 0.0)
				var ball_center: Vector2 = _vector_value(
					event,
					"ball_center_at_contact",
					_vector_value(
						event,
						"source_center",
						_vector_value(event, "contact_point")
					)
				)
				var surface_point: Vector2 = _vector_value(
					event,
					"surface_contact_point",
					ball_center - rail_unit_normal * ball_radius
				)
				var incoming_velocity: Vector2 = _vector_value(
					event,
					"incoming_source_velocity"
				)
				var rail_kind: String = _derive_rail_kind(event, rail_id)
				converted.merge({
					"event_type": "rail_contact",
					"ball_id": source_id,
					"rail_id": rail_id,
					"rail_name": rail_name,
					"rail_index": rail_index,
					"rail_kind": rail_kind,
					"rail_identity_source": str(rail_semantic_evidence.get(
						"rail_identity_source",
						"missing"
					)),
					"rail_compatibility_warning": str(rail_semantic_evidence.get(
						"rail_compatibility_warning",
						""
					)),
					"rail_semantic_evidence_complete": bool(rail_semantic_evidence.get(
						"complete",
						false
					)),
					"rail_semantic_evidence_missing": _array_value(
						rail_semantic_evidence,
						"missing"
					).duplicate(),
					"rail_eligible_for_exact_matching": bool(rail_semantic_evidence.get(
						"eligible_for_exact_matching",
						false
					)),
					"rail_eligible_for_geometric_matching": bool(rail_semantic_evidence.get(
						"eligible_for_geometric_matching",
						false
					)),
					"ball_center_at_contact": ball_center,
					"surface_contact_point": surface_point,
					"ball_radius": ball_radius,
					"contact_point": surface_point,
					"rail_contact_position": surface_point,
					"predictor_contact_point": _vector_value(event, "contact_point"),
					"contact_normal": rail_normal,
					"rail_side": _derive_rail_side(rail_normal),
					"pre_velocity": incoming_velocity,
					"post_velocity": _vector_value(event, "outgoing_source_velocity"),
					"normal_speed": maxf(-incoming_velocity.dot(rail_normal), 0.0),
				})
			PREDICTOR.EVENT_POCKET:
				var start_snapshot: Dictionary = _dictionary_value(starting_balls, str(source_id))
				converted.merge({
					"event_type": "pocket",
					"ball_id": source_id,
					"pocket_index": int(event.get("pocket_index", -1)),
					"pocket_center": _vector_value(event, "target_center"),
					"capture_position": _vector_value(event, "source_center", _vector_value(event, "contact_point")),
					"ball_kind": str(start_snapshot.get("ball_kind", "unknown")),
					"counts_as_object_ball": bool(start_snapshot.get("counts_as_object_ball", false)),
				})
			_:
				diagnostics["unsupported_events"] = int(diagnostics["unsupported_events"]) + 1
				continue
		converted_events.append(converted)

	diagnostics["events_converted"] = converted_events.size()
	var normalization_result: Dictionary = _normalize_converted_events(converted_events)
	var raw_events: Array[Dictionary] = []
	for normalized_value in _array_value(normalization_result, "events"):
		if normalized_value is Dictionary:
			raw_events.append((normalized_value as Dictionary).duplicate(true))
	var normalization_diagnostics: Dictionary = _dictionary_value(
		normalization_result,
		"diagnostics"
	)
	diagnostics["normalization"] = normalization_diagnostics.duplicate(true)

	var ending_balls: Dictionary = {}
	var cap_affected_id_set: Dictionary = {}
	var unsupported_affected_id_set: Dictionary = {}
	var prediction_stop_reason: String = str(prediction.get("stop_reason", "none"))
	var prediction_capped: bool = bool(prediction.get("truncated", false))
	for unsupported_record in unsupported_event_records:
		_add_positive_id(unsupported_affected_id_set, int(unsupported_record.get("source_ball_id", -1)))
		_add_positive_id(unsupported_affected_id_set, int(unsupported_record.get("target_ball_id", -1)))
	for ball_value in _array_value(prediction, "balls"):
		if not ball_value is Dictionary:
			continue
		var ball_result: Dictionary = ball_value
		var run_ball_id: int = _map_source_id(
			ball_result.get("source_ball_id", -1),
			prediction_source_to_run_id
		)
		if run_ball_id <= 0:
			continue
		var start_snapshot: Dictionary = _dictionary_value(starting_balls, str(run_ball_id))
		var pocketed: bool = bool(ball_result.get("pocketed", false))
		var final_stop_reason: String = str(ball_result.get("final_stop_reason", ""))
		var path_points: Array = _array_value(ball_result, "path_points")
		var travel_distance: float = _path_distance(path_points)
		ending_balls[str(run_ball_id)] = {
			"ball_id": run_ball_id,
			"ball_number": int(start_snapshot.get("ball_number", -1)),
			"ball_kind": str(start_snapshot.get("ball_kind", "unknown")),
			"active": not pocketed,
			"pocketed": pocketed,
			"final_position": _vector_value(ball_result, "ending_position"),
			"final_velocity": _vector_value(ball_result, "ending_velocity"),
			"travel_distance": travel_distance,
			"final_stop_reason": final_stop_reason,
			"generation_depth": int(ball_result.get("generation_depth", -1)),
			"parent_contact_event": int(ball_result.get("parent_contact_event", -1)),
			"first_movement_event": int(ball_result.get("first_movement_event", -1)),
			"parent_source_ball_id": _map_source_id(
				ball_result.get("parent_source_ball_id", -1),
				prediction_source_to_run_id
			),
		}
		if (
			prediction_capped
			and not pocketed
			and final_stop_reason == prediction_stop_reason
			and _ball_result_has_causal_activity(ball_result, travel_distance)
		):
			_add_positive_id(cap_affected_id_set, run_ball_id)

	var mapped_unsupported_warnings: Array[Dictionary] = []
	for warning_value in _array_value(prediction, "unsupported_warnings"):
		if not warning_value is Dictionary:
			continue
		var warning: Dictionary = (warning_value as Dictionary).duplicate(true)
		var predictor_ball_id: int = int(warning.get("ball_id", -1))
		var warning_ball_id: int = _map_source_id(
			predictor_ball_id,
			prediction_source_to_run_id
		)
		warning["predictor_ball_id"] = predictor_ball_id
		warning["ball_id"] = warning_ball_id
		mapped_unsupported_warnings.append(warning)
		_add_positive_id(unsupported_affected_id_set, warning_ball_id)

	for cap_detail_key in ["iteration_cap_detail", "geometry_probe_cap_detail"]:
		var cap_detail: Dictionary = _dictionary_value(prediction, cap_detail_key)
		var cap_boundary_ball_id: int = _map_source_id(
			cap_detail.get("last_processed_ball_id", -1),
			prediction_source_to_run_id
		)
		var cap_boundary_ending: Dictionary = _dictionary_value(
			ending_balls,
			str(cap_boundary_ball_id)
		)
		if not bool(cap_boundary_ending.get("pocketed", false)):
			_add_positive_id(cap_affected_id_set, cap_boundary_ball_id)
	var cap_affected_ball_ids: Array[int] = _sorted_positive_ids(cap_affected_id_set)
	var unsupported_affected_ball_ids: Array[int] = _sorted_positive_ids(
		unsupported_affected_id_set
	)

	var ledger: Dictionary = {
		"schema_version": int(active_shot.get("schema_version", SHOT_LEDGER_SCRIPT.SCHEMA_VERSION)),
		"source": "accepted_cloned_prediction",
		"mode_id": str(active_shot.get("mode_id", "")),
		"run_generation": int(active_shot.get("run_generation", -1)),
		"shot_id": int(active_shot.get("shot_id", -1)),
		"attempt_id": int(active_shot.get("attempt_id", -1)),
		"round_index": int(active_shot.get("round_index", -1)),
		"round_number": int(active_shot.get("round_number", -1)),
		"shot_lab_active": bool(active_shot.get("shot_lab_active", false)),
		"shot_lab_preset_id": str(active_shot.get("shot_lab_preset_id", "")),
		"cue_ball_id": int(active_shot.get("cue_ball_id", -1)),
		"starting_balls": starting_balls,
		"ending_balls": ending_balls,
		"raw_events": raw_events,
		"prediction_event_normalization": normalization_diagnostics.duplicate(true),
		"prediction_generation": int(prediction_bundle.get("prediction_generation", 0)),
		"prediction_key": str(prediction_bundle.get("prediction_key", "")),
		"prediction_requested_result_mode": requested_result_mode,
		"prediction_result_mode": result_mode,
		"prediction_result_mode_source": result_mode_source,
		"prediction_result_mode_matches_request": bool(
			diagnostics.get("prediction_result_mode_matches_request", false)
		),
		"prediction_truncated": prediction_capped,
		"prediction_stop_reason": prediction_stop_reason,
		"prediction_cap_reached": str(prediction.get("cap_reached", "")),
		"prediction_capped": prediction_capped,
		"prediction_cap_affected_ball_ids": cap_affected_ball_ids,
		"unsupported_prediction": (
			not mapped_unsupported_warnings.is_empty()
			or not unsupported_event_records.is_empty()
		),
		"prediction_unsupported_affected_ball_ids": unsupported_affected_ball_ids,
		"unsupported_warnings": mapped_unsupported_warnings,
		"unsupported_event_records": unsupported_event_records,
	}
	diagnostics["prediction_cap_affected_ball_ids"] = cap_affected_ball_ids.duplicate()
	diagnostics["prediction_unsupported_affected_ball_ids"] = (
		unsupported_affected_ball_ids.duplicate()
	)
	diagnostics["events_retained"] = raw_events.size()
	diagnostics["valid"] = true
	diagnostics["reason"] = "accepted"
	output["valid"] = true
	output["ledger"] = ledger
	return output


static func normalize_predicted_events_for_test(converted_events: Array) -> Dictionary:
	return _normalize_converted_events(converted_events)


static func _normalize_converted_events(converted_events: Array) -> Dictionary:
	var ordered_events: Array = converted_events.duplicate(true)
	ordered_events.sort_custom(_converted_event_precedes)
	var normalized_events: Array[Dictionary] = []
	var last_contact_by_pair: Dictionary = {}
	var normalization: Dictionary = {
		"version": 1,
		"events_before_normalization": ordered_events.size(),
		"events_after_normalization": 0,
		"events_suppressed": 0,
		"suppressed_sustained_pair_contacts": 0,
		"suppressed_non_approaching_contacts": 0,
		"suppressed_below_impact_epsilon": 0,
		"genuine_recontacts_preserved": 0,
		"uncertain_repeated_contacts_retained": 0,
		"ball_contacts_retained": 0,
		"rail_contacts_retained": 0,
		"pockets_retained": 0,
		"suppression_reasons": {},
		"suppression_records": [],
		"rail_kind_counts": {},
	}
	for event_value in ordered_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = (event_value as Dictionary).duplicate(true)
		var event_type: String = str(event.get("event_type", ""))
		if event_type == "ball_contact":
			var pair_key: String = _pair_key(
				int(event.get("ball_a_id", -1)),
				int(event.get("ball_b_id", -1))
			)
			var previous: Dictionary = _dictionary_value(last_contact_by_pair, pair_key)
			var suppression_reason: String = _get_contact_suppression_reason(
				event,
				previous,
				normalized_events
			)
			if not suppression_reason.is_empty():
				_note_suppressed_event(normalization, event, pair_key, suppression_reason, previous)
				continue
			if not previous.is_empty():
				if _has_meaningful_recontact_evidence(previous, event, normalized_events):
					normalization["genuine_recontacts_preserved"] = int(
						normalization["genuine_recontacts_preserved"]
					) + 1
				else:
					normalization["uncertain_repeated_contacts_retained"] = int(
						normalization["uncertain_repeated_contacts_retained"]
					) + 1
			event["event_index"] = normalized_events.size()
			event["semantic_event_index"] = normalized_events.size()
			normalized_events.append(event)
			last_contact_by_pair[pair_key] = {
				"normalized_event_index": int(event.get("event_index", -1)),
				"predictor_event_index": int(event.get("predictor_event_index", -1)),
				"shot_elapsed_sec": float(event.get("shot_elapsed_sec", 0.0)),
				"physics_frame": int(event.get("physics_frame", -1)),
				"contact_point": _vector_value(event, "contact_point"),
				"source_ball_id": int(event.get("source_ball_id", -1)),
				"target_ball_id": int(event.get("target_ball_id", -1)),
			}
			normalization["ball_contacts_retained"] = int(
				normalization["ball_contacts_retained"]
			) + 1
			continue

		event["event_index"] = normalized_events.size()
		event["semantic_event_index"] = normalized_events.size()
		normalized_events.append(event)
		if event_type == "rail_contact":
			normalization["rail_contacts_retained"] = int(
				normalization["rail_contacts_retained"]
			) + 1
			var rail_kind: String = str(event.get("rail_kind", "unknown"))
			var rail_kind_counts: Dictionary = normalization["rail_kind_counts"]
			rail_kind_counts[rail_kind] = int(rail_kind_counts.get(rail_kind, 0)) + 1
		elif event_type == "pocket":
			normalization["pockets_retained"] = int(normalization["pockets_retained"]) + 1
	normalization["events_after_normalization"] = normalized_events.size()
	return {
		"events": normalized_events,
		"diagnostics": normalization,
	}


static func _get_contact_suppression_reason(
	event: Dictionary,
	previous: Dictionary,
	normalized_events: Array[Dictionary]
) -> String:
	if bool(event.get("approach_evidence_available", false)):
		var relative_speed: float = float(event.get("relative_normal_speed", 0.0))
		if not is_finite(relative_speed) or relative_speed < 0.0:
			return "non_approaching_or_separating"
		if relative_speed <= SHOT_LEDGER_SCRIPT.MEANINGFUL_IMPACT_EPSILON:
			return "below_impact_epsilon"
	if previous.is_empty():
		return ""
	if _has_meaningful_recontact_evidence(previous, event, normalized_events):
		return ""
	var time_delta: float = maxf(
		float(event.get("shot_elapsed_sec", 0.0))
		- float(previous.get("shot_elapsed_sec", 0.0)),
		0.0
	)
	var frame_delta: int = (
		int(event.get("physics_frame", -1))
		- int(previous.get("physics_frame", -1))
	)
	var position_delta: float = _vector_value(
		previous,
		"contact_point"
	).distance_to(_vector_value(event, "contact_point"))
	if (
		time_delta <= SUSTAINED_CONTACT_TIME_WINDOW_SEC
		or (frame_delta >= 0 and frame_delta <= SUSTAINED_CONTACT_FRAME_WINDOW)
	) and position_delta <= SUSTAINED_CONTACT_POSITION_WINDOW_PX:
		return "sustained_pair_contact"
	return ""


static func _has_meaningful_recontact_evidence(
	previous: Dictionary,
	event: Dictionary,
	normalized_events: Array[Dictionary]
) -> bool:
	var previous_index: int = int(previous.get("normalized_event_index", -1))
	var ball_a_id: int = int(event.get("ball_a_id", -1))
	var ball_b_id: int = int(event.get("ball_b_id", -1))
	for event_index in range(previous_index + 1, normalized_events.size()):
		var between: Dictionary = normalized_events[event_index]
		if _event_proves_pair_separation(between, ball_a_id, ball_b_id):
			return true
	var time_delta: float = maxf(
		float(event.get("shot_elapsed_sec", 0.0))
		- float(previous.get("shot_elapsed_sec", 0.0)),
		0.0
	)
	var position_delta: float = _vector_value(
		previous,
		"contact_point"
	).distance_to(_vector_value(event, "contact_point"))
	if (
		time_delta >= MEANINGFUL_RECONTACT_TIME_SEC
		and position_delta >= MEANINGFUL_RECONTACT_POSITION_PX
	):
		return true
	return (
		int(previous.get("source_ball_id", -1)) == int(event.get("target_ball_id", -2))
		and int(previous.get("target_ball_id", -1)) == int(event.get("source_ball_id", -2))
		and position_delta >= SUSTAINED_CONTACT_POSITION_WINDOW_PX
	)


static func _event_proves_pair_separation(
	event: Dictionary,
	ball_a_id: int,
	ball_b_id: int
) -> bool:
	match str(event.get("event_type", "")):
		"rail_contact", "pocket":
			var ball_id: int = int(event.get("ball_id", -1))
			return ball_id == ball_a_id or ball_id == ball_b_id
		"ball_contact":
			var other_a: int = int(event.get("ball_a_id", -1))
			var other_b: int = int(event.get("ball_b_id", -1))
			return (
				(other_a == ball_a_id or other_b == ball_a_id
				or other_a == ball_b_id or other_b == ball_b_id)
				and _pair_key(other_a, other_b) != _pair_key(ball_a_id, ball_b_id)
			)
	return false


static func _note_suppressed_event(
	diagnostics: Dictionary,
	event: Dictionary,
	pair_key: String,
	reason: String,
	previous: Dictionary
) -> void:
	diagnostics["events_suppressed"] = int(diagnostics["events_suppressed"]) + 1
	match reason:
		"sustained_pair_contact":
			diagnostics["suppressed_sustained_pair_contacts"] = int(
				diagnostics["suppressed_sustained_pair_contacts"]
			) + 1
		"non_approaching_or_separating":
			diagnostics["suppressed_non_approaching_contacts"] = int(
				diagnostics["suppressed_non_approaching_contacts"]
			) + 1
		"below_impact_epsilon":
			diagnostics["suppressed_below_impact_epsilon"] = int(
				diagnostics["suppressed_below_impact_epsilon"]
			) + 1
	var reasons: Dictionary = diagnostics["suppression_reasons"]
	reasons[reason] = int(reasons.get(reason, 0)) + 1
	var records: Array = diagnostics["suppression_records"]
	if records.size() >= MAX_SUPPRESSION_RECORDS:
		return
	records.append({
		"predictor_event_index": int(event.get("predictor_event_index", -1)),
		"event_type": str(event.get("event_type", "")),
		"pair_key": pair_key,
		"reason": reason,
		"relative_normal_speed": float(event.get("relative_normal_speed", 0.0)),
		"previous_predictor_event_index": int(previous.get("predictor_event_index", -1)),
		"time_delta_sec": maxf(
			float(event.get("shot_elapsed_sec", 0.0))
			- float(previous.get("shot_elapsed_sec", 0.0)),
			0.0
		),
		"position_delta_px": _vector_value(previous, "contact_point").distance_to(
			_vector_value(event, "contact_point")
		),
	})


static func _get_contact_approach_evidence(
	event: Dictionary,
	contact_normal: Vector2,
	incoming_source: Vector2,
	incoming_target: Vector2
) -> Dictionary:
	if event.has("impact_speed"):
		var impact_speed: float = float(event.get("impact_speed", 0.0))
		return {
			"available": is_finite(impact_speed),
			"speed": impact_speed,
			"accepted_impact": is_finite(impact_speed) and impact_speed > 0.0,
		}
	if (
		event.has("incoming_source_velocity")
		and event.has("incoming_target_velocity")
		and event.has("collision_normal")
		and contact_normal != Vector2.ZERO
	):
		var derived_speed: float = (incoming_source - incoming_target).dot(contact_normal)
		return {
			"available": is_finite(derived_speed),
			"speed": derived_speed,
			"accepted_impact": is_finite(derived_speed) and derived_speed > 0.0,
		}
	return {"available": false, "speed": 0.0, "accepted_impact": true}


static func _get_rail_semantic_evidence(event: Dictionary) -> Dictionary:
	var missing: Array[String] = []
	var rail_name: String = str(event.get("rail_name", "")).strip_edges()
	var rail_index: int = int(event.get("rail_index", -1))
	var normal_valid: bool = (
		_is_finite_vector_value(event.get("collision_normal", null))
		and _vector_value(event, "collision_normal").length_squared() > 0.000001
	)
	var center_valid: bool = _is_finite_vector_value(
		event.get("ball_center_at_contact", null)
	)
	var surface_valid: bool = _is_finite_vector_value(
		event.get("surface_contact_point", null)
	)
	var radius_value: Variant = event.get("ball_radius", null)
	var radius_valid: bool = (
		typeof(radius_value) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(radius_value))
		and float(radius_value) > 0.0
	)
	if rail_name.is_empty():
		missing.append("rail_name")
	if not normal_valid:
		missing.append("collision_normal")
	if not center_valid:
		missing.append("ball_center_at_contact")
	if not surface_valid:
		missing.append("surface_contact_point")
	if not radius_valid:
		missing.append("ball_radius")

	var identity_source: String = "rail_name"
	var compatibility_warning: String = ""
	if rail_name.is_empty() and rail_index >= 0:
		identity_source = "rail_index_compatibility"
		compatibility_warning = "rail_name_missing_index_retained_for_compatibility"
	elif rail_name.is_empty():
		identity_source = "missing"
		compatibility_warning = "rail_identity_missing"
	return {
		"complete": missing.is_empty(),
		"missing": missing,
		"rail_name": rail_name,
		"rail_index": rail_index,
		"rail_identity_source": identity_source,
		"rail_compatibility_warning": compatibility_warning,
		"eligible_for_exact_matching": not rail_name.is_empty() and normal_valid,
		"eligible_for_geometric_matching": (
			normal_valid and center_valid and surface_valid and radius_valid
		),
	}


static func _record_rail_semantic_diagnostics(
	diagnostics: Dictionary,
	evidence: Dictionary,
	predictor_event_index: int
) -> void:
	diagnostics["predicted_rail_events_received"] = int(
		diagnostics.get("predicted_rail_events_received", 0)
	) + 1
	var missing: Array = _array_value(evidence, "missing")
	var missing_to_counter: Dictionary = {
		"rail_name": "rail_events_missing_name",
		"collision_normal": "rail_events_missing_normal",
		"ball_center_at_contact": "rail_events_missing_center",
		"surface_contact_point": "rail_events_missing_surface",
		"ball_radius": "rail_events_missing_radius",
	}
	for missing_field_value in missing:
		var missing_field: String = str(missing_field_value)
		var counter_key: String = str(missing_to_counter.get(missing_field, ""))
		if not counter_key.is_empty():
			diagnostics[counter_key] = int(diagnostics.get(counter_key, 0)) + 1
	if bool(evidence.get("eligible_for_exact_matching", false)):
		diagnostics["rail_events_eligible_for_exact_matching"] = int(
			diagnostics.get("rail_events_eligible_for_exact_matching", 0)
		) + 1
	if bool(evidence.get("eligible_for_geometric_matching", false)):
		diagnostics["rail_events_eligible_for_geometric_matching"] = int(
			diagnostics.get("rail_events_eligible_for_geometric_matching", 0)
		) + 1
	var evidence_counter: String = (
		"rail_events_semantic_evidence_complete"
		if bool(evidence.get("complete", false))
		else "rail_events_semantic_evidence_incomplete"
	)
	diagnostics[evidence_counter] = int(diagnostics.get(evidence_counter, 0)) + 1
	var warning: String = str(evidence.get("rail_compatibility_warning", ""))
	if warning.is_empty():
		return
	var warnings: Array = diagnostics.get("rail_compatibility_warnings", [])
	if warnings.size() >= MAX_SUPPRESSION_RECORDS:
		return
	warnings.append({
		"predictor_event_index": predictor_event_index,
		"warning": warning,
		"rail_index": int(evidence.get("rail_index", -1)),
		"missing": missing.duplicate(),
	})
	diagnostics["rail_compatibility_warnings"] = warnings


static func _is_finite_vector_value(value: Variant) -> bool:
	if not value is Vector2:
		return false
	var vector: Vector2 = value
	return is_finite(vector.x) and is_finite(vector.y)


static func _derive_rail_kind(event: Dictionary, rail_id: String) -> String:
	var explicit_kind: String = str(event.get(
		"rail_kind",
		event.get("boundary_kind", "")
	)).to_lower()
	if explicit_kind in ["rail", "jaw"]:
		return explicit_kind
	return "jaw" if rail_id.to_lower().contains("jaw") else "rail"


static func _derive_rail_side(normal: Vector2) -> String:
	if normal == Vector2.ZERO:
		return "unknown"
	if absf(normal.x) > absf(normal.y):
		return "left" if normal.x > 0.0 else "right"
	return "top" if normal.y > 0.0 else "bottom"


static func _pair_key(ball_a_id: int, ball_b_id: int) -> String:
	return "%d:%d" % [mini(ball_a_id, ball_b_id), maxi(ball_a_id, ball_b_id)]


static func _converted_event_precedes(left_value: Variant, right_value: Variant) -> bool:
	if not left_value is Dictionary:
		return false
	if not right_value is Dictionary:
		return true
	return int((left_value as Dictionary).get("predictor_event_index", 2147483647)) < int(
		(right_value as Dictionary).get("predictor_event_index", 2147483647)
	)


static func _map_source_id(value: Variant, source_to_run_id: Dictionary) -> int:
	return int(source_to_run_id.get(str(int(value)), -1))


static func _add_positive_id(id_set: Dictionary, ball_id: int) -> void:
	if ball_id > 0:
		id_set[str(ball_id)] = true


static func _sorted_positive_ids(id_set: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for id_key in id_set.keys():
		var ball_id: int = int(id_key)
		if ball_id > 0:
			ids.append(ball_id)
	ids.sort()
	return ids


static func _ball_result_has_causal_activity(
	ball_result: Dictionary,
	travel_distance: float
) -> bool:
	return (
		travel_distance > 0.25
		or int(ball_result.get("parent_contact_event", -1)) >= 0
		or int(ball_result.get("first_movement_event", -1)) >= 0
	)


static func _path_distance(points: Array) -> float:
	var total := 0.0
	for index in range(1, points.size()):
		if points[index - 1] is Vector2 and points[index] is Vector2:
			total += (points[index - 1] as Vector2).distance_to(points[index] as Vector2)
	return total


static func _vector_value(container: Dictionary, key: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value: Variant = container.get(key, fallback)
	return value as Vector2 if value is Vector2 else fallback


static func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


static func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []
