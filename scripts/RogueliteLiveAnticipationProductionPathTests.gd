extends SceneTree

# Standalone regression harness for the production cloned-prediction compaction
# path used by Long Sink live scoring anticipation. Run with:
# godot4 --headless --path <project> --script res://scripts/RogueliteLiveAnticipationProductionPathTests.gd

const PREDICTOR_SCRIPT := preload("res://scripts/AimTrajectoryPredictor.gd")
const ADAPTER_SCRIPT := preload("res://scripts/RoguelitePredictedLedgerAdapter.gd")
const ANALYZER_SCRIPT := preload("res://scripts/ShotLedgerAnalyzer.gd")
const RESOLVER_SCRIPT := preload("res://scripts/RogueliteScoreResolver.gd")
const NARRATIVE_BUILDER_SCRIPT := preload("res://scripts/RogueliteScoringNarrativeBuilder.gd")
const LIVE_ANTICIPATION_SCRIPT := preload(
	"res://scripts/RogueliteLiveScoringAnticipationSystem.gd"
)

const RESULT_MODE_PLAYER_MINIMAL := "player_minimal"
const RESULT_MODE_PLAYER_SCORING := "player_scoring"
const SHOT_ID := 41
const ATTEMPT_ID := 73
const CUE_BALL_ID := 1
const SCORING_BALL_ID := 7
const BALL_RADIUS := 14.0


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var report: Dictionary = run_all()
	print(_format_report(report))
	quit(0 if int(report.get("failed", 0)) == 0 else 1)


static func run_all() -> Dictionary:
	var cases: Array[Dictionary] = []
	var scoring_compaction: Dictionary = _compact_predictor_events(
		RESULT_MODE_PLAYER_SCORING,
		_make_double_bank_predictor_events()
	)
	var minimal_compaction: Dictionary = _compact_predictor_events(
		RESULT_MODE_PLAYER_MINIMAL,
		[_make_predictor_rail_event(
			0,
			"BottomRail",
			3,
			Vector2(560.0, 610.0),
			Vector2.UP,
			Vector2(330.0, 440.0)
		)]
	)

	var scoring_events: Array = _array_value(scoring_compaction, "events")
	var scoring_bottom: Dictionary = _find_compacted_rail(scoring_events, "BottomRail")
	var scoring_configuration: Dictionary = _dictionary_value(
		scoring_compaction,
		"configuration"
	)
	_record_case(
		cases,
		"PLAYER_SCORING retains rail name and normal",
		str(scoring_configuration.get("result_detail_mode", "")) == RESULT_MODE_PLAYER_SCORING
			and str(scoring_bottom.get("rail_name", "")) == "BottomRail"
			and _vector_value(scoring_bottom, "collision_normal") == Vector2.UP
			and scoring_bottom.has("incoming_source_velocity")
			and scoring_bottom.has("incoming_target_velocity")
			and scoring_bottom.has("source_parent_contact_event"),
		"player_scoring rail event retains semantic identity, normal, and contact evidence",
		{
			"result_mode": scoring_configuration.get("result_detail_mode", "missing"),
			"retained_fields": _present_fields(scoring_bottom, [
				"rail_name",
				"collision_normal",
				"incoming_source_velocity",
				"incoming_target_velocity",
				"source_parent_contact_event",
			]),
		}
	)

	var minimal_events: Array = _array_value(minimal_compaction, "events")
	var minimal_rail: Dictionary = (
		minimal_events[0] as Dictionary if not minimal_events.is_empty() else {}
	)
	_record_case(
		cases,
		"PLAYER_MINIMAL behavior remains documented",
		str(_dictionary_value(minimal_compaction, "configuration").get(
			"result_detail_mode",
			""
		)) == RESULT_MODE_PLAYER_MINIMAL
			and not minimal_rail.has("rail_name")
			and not minimal_rail.has("collision_normal")
			and minimal_rail.has("ball_center_at_contact")
			and minimal_rail.has("surface_contact_point")
			and minimal_rail.has("ball_radius"),
		"player_minimal keeps compact geometry but omits scoring semantic evidence",
		{
			"retained_fields": _present_fields(minimal_rail, [
				"rail_name",
				"collision_normal",
				"ball_center_at_contact",
				"surface_contact_point",
				"ball_radius",
			]),
		}
	)
	var mismatched_mode_adapter: Dictionary = _build_mode_mismatch_adapter_result(
		minimal_compaction
	)
	_record_case(
		cases,
		"PLAYER_MINIMAL cannot satisfy a PLAYER_SCORING request",
		not bool(mismatched_mode_adapter.get("valid", false))
			and str(_dictionary_value(
				mismatched_mode_adapter,
				"diagnostics"
			).get("reason", "")) == "result_detail_mode_mismatch",
		"adapter rejects result_detail_mode_mismatch",
		_dictionary_value(mismatched_mode_adapter, "diagnostics")
	)

	var pipeline: Dictionary = _build_production_pipeline(scoring_compaction)
	var pipeline_valid: bool = bool(pipeline.get("valid", false))
	var lane: Dictionary = _dictionary_value(pipeline, "lane")
	var structural_events: Array = _array_value(lane, "structural_expected_events")
	var bottom_expected: Dictionary = _find_structural_rail(structural_events, "BottomRail")
	var right_expected: Dictionary = _find_structural_rail(structural_events, "RightRail")
	var matcher: Variant = LIVE_ANTICIPATION_SCRIPT.new()

	var bottom_actual: Dictionary = _make_authoritative_rail_from_expected(
		bottom_expected,
		"BottomRail",
		"rail"
	)
	var bottom_match: Dictionary = (
		matcher.call("_get_rail_match_result", bottom_expected, bottom_actual)
		if pipeline_valid and not bottom_expected.is_empty()
		else {}
	)
	_record_case(
		cases,
		"Bottom rail exact-name match",
		bool(bottom_match.get("matched", false))
			and str(bottom_match.get("quality", "")) == "exact_id",
		"BottomRail matches by exact stable rail identity",
		bottom_match
	)

	var right_actual: Dictionary = _make_authoritative_rail_from_expected(
		right_expected,
		"RightRail",
		"rail"
	)
	var right_match: Dictionary = (
		matcher.call("_get_rail_match_result", right_expected, right_actual)
		if pipeline_valid and not right_expected.is_empty()
		else {}
	)
	_record_case(
		cases,
		"Right rail exact-name match",
		bool(right_match.get("matched", false))
			and str(right_match.get("quality", "")) == "exact_id",
		"RightRail matches by exact stable rail identity",
		right_match
	)

	var jaw_actual: Dictionary = _make_authoritative_rail_from_expected(
		bottom_expected,
		"BottomRightJaw",
		"jaw",
		Vector2(2.0, -1.0)
	)
	var jaw_match: Dictionary = (
		matcher.call("_get_rail_match_result", bottom_expected, jaw_actual)
		if pipeline_valid and not bottom_expected.is_empty()
		else {}
	)
	_record_case(
		cases,
		"Adjoining jaw tolerant match",
		bool(jaw_match.get("matched", false))
			and str(jaw_match.get("quality", "")) == "geometry_fallback"
			and bool(jaw_match.get("warning", false)),
		"an adjoining jaw with compatible side, normal, and geometry matches tolerantly",
		jaw_match
	)

	var rail_roles: Array[String] = []
	var rail_ids: Array[String] = []
	var rail_event_indices: Array[int] = []
	var adapter_diagnostics: Dictionary = _dictionary_value(
		_dictionary_value(pipeline, "adapter"),
		"diagnostics"
	)
	for event_value in structural_events:
		if not event_value is Dictionary:
			continue
		var structural_event: Dictionary = event_value
		if str(structural_event.get("semantic_event_type", "")) != "rail_contact":
			continue
		rail_roles.append(str(structural_event.get("structural_role", "")))
		rail_ids.append(str(structural_event.get("rail_id", "")))
		rail_event_indices.append(int(structural_event.get("predicted_event_index", -1)))
	_record_case(
		cases,
		"Two chronological rails survive the production pipeline",
		pipeline_valid
			and rail_roles == ["rail_1", "rail_2"]
			and rail_ids == ["BottomRail", "RightRail"]
			and rail_event_indices.size() == 2
			and rail_event_indices[0] < rail_event_indices[1]
			and int(adapter_diagnostics.get("predicted_rail_events_received", 0)) == 2
			and int(adapter_diagnostics.get(
				"rail_events_semantic_evidence_complete",
				0
			)) == 2
			and int(adapter_diagnostics.get(
				"rail_events_eligible_for_exact_matching",
				0
			)) == 2
			and int(adapter_diagnostics.get(
				"rail_events_eligible_for_geometric_matching",
				0
			)) == 2,
		"BottomRail then RightRail remain distinct and ordered after compaction and adaptation",
		{
			"pipeline_reason": pipeline.get("reason", ""),
			"rail_roles": rail_roles,
			"rail_ids": rail_ids,
			"rail_event_indices": rail_event_indices,
			"adapter_rail_diagnostics": {
				"received": adapter_diagnostics.get("predicted_rail_events_received", 0),
				"complete": adapter_diagnostics.get(
					"rail_events_semantic_evidence_complete",
					0
				),
				"exact_eligible": adapter_diagnostics.get(
					"rail_events_eligible_for_exact_matching",
					0
				),
				"geometry_eligible": adapter_diagnostics.get(
					"rail_events_eligible_for_geometric_matching",
					0
				),
			},
		}
	)

	var replay: Dictionary = _replay_double_bank_pipeline(pipeline)
	var replay_lane: Dictionary = _dictionary_value(replay, "lane")
	var cue_kinds: Array[String] = []
	for cue_value in _array_value(replay, "cues"):
		if cue_value is Dictionary:
			cue_kinds.append(str((cue_value as Dictionary).get("cue_kind", "")))
	_record_case(
		cases,
		"Double Bank lane does not diverge",
		bool(replay.get("valid", false))
			and not bool(replay_lane.get("diverged", true))
			and bool(replay_lane.get("completed", false))
			and int(replay_lane.get("matched_structural_event_count", 0)) == 4
			and "bank_1" in cue_kinds
			and "bank_2" in cue_kinds
			and "pocket" in cue_kinds,
		"the real adapted Double Bank lane presents both bank milestones and the pocket",
		{
			"pipeline_reason": pipeline.get("reason", ""),
			"divergence_reason": replay_lane.get("divergence_reason", ""),
			"matched_structural_events": replay_lane.get(
				"matched_structural_event_count",
				0
			),
			"cue_kinds": cue_kinds,
			"last_rail_match": replay_lane.get("last_rail_match", {}),
		}
	)

	if matcher is Node:
		(matcher as Node).free()
	return _finalize_report(cases, pipeline)


static func _compact_predictor_events(result_mode: String, events: Array) -> Dictionary:
	var configuration: Dictionary = PREDICTOR_SCRIPT.get_player_aim_configuration(
		0,
		4,
		result_mode
	)
	var predictor: Variant = PREDICTOR_SCRIPT.new()
	predictor.set("_config", configuration)
	var compacted_events: Array[Dictionary] = []
	for event_index in range(events.size()):
		var event_value: Variant = events[event_index]
		if not event_value is Dictionary:
			continue
		var event: Dictionary = (event_value as Dictionary).duplicate(true)
		event["event_index"] = event_index
		event["simulated_time"] = float(event_index) * 0.1
		event["physics_frame"] = event_index * 6
		event["substep"] = 0
		var compacted_value: Variant = predictor.call("_compact_event_for_result", event)
		if compacted_value is Dictionary:
			compacted_events.append((compacted_value as Dictionary).duplicate(true))
	return {
		"configuration": configuration,
		"events": compacted_events,
	}


static func _build_production_pipeline(compaction: Dictionary) -> Dictionary:
	var compacted_events: Array = _array_value(compaction, "events")
	var prediction_result: Dictionary = {
		"valid": true,
		"complete": true,
		"truncated": false,
		"stop_reason": "all_balls_stopped",
		"cap_reached": "",
		"configuration": _dictionary_value(compaction, "configuration"),
		"events": compacted_events.duplicate(true),
		"balls": _make_prediction_ball_results(),
		"unsupported_warnings": [],
	}
	var prediction_bundle: Dictionary = {
		"accepted": true,
		"status": "settled_cloned_at_commit",
		"prediction_generation": 1,
		"prediction_key": "production_compaction_regression",
		"request_snapshot": {
			"result_detail_mode": _dictionary_value(
				compaction,
				"configuration"
			).get("result_detail_mode", ""),
		},
		"prediction_result": prediction_result,
	}
	var active_shot: Dictionary = _make_active_shot()
	var adapted: Dictionary = ADAPTER_SCRIPT.build(
		prediction_bundle,
		active_shot,
		{
			str(CUE_BALL_ID): CUE_BALL_ID,
			str(SCORING_BALL_ID): SCORING_BALL_ID,
		}
	)
	if not bool(adapted.get("valid", false)):
		return {
			"valid": false,
			"reason": "adapter_failed",
			"adapter": adapted,
		}
	var ledger: Dictionary = _dictionary_value(adapted, "ledger").duplicate(true)
	ledger["derived"] = ANALYZER_SCRIPT.analyze(ledger)
	var score_result: Dictionary = RESOLVER_SCRIPT.resolve(ledger, [])
	var narrative: Dictionary = NARRATIVE_BUILDER_SCRIPT.build_predicted_narrative(
		ledger,
		score_result
	)
	var validation: Dictionary = _dictionary_value(narrative, "validation")
	if not bool(validation.get("valid", false)):
		return {
			"valid": false,
			"reason": "narrative_validation_failed",
			"adapter": adapted,
			"ledger": ledger,
			"score_result": score_result,
			"narrative": narrative,
		}
	var live: Variant = LIVE_ANTICIPATION_SCRIPT.new()
	live.set("predicted_ledger_with_derived", ledger)
	live.set("predicted_narrative", narrative)
	live.call("_build_lanes_from_predicted_narrative")
	var lane: Dictionary = _dictionary_value(live.get("lanes"), str(SCORING_BALL_ID))
	if live is Node:
		(live as Node).free()
	return {
		"valid": not lane.is_empty(),
		"reason": "accepted" if not lane.is_empty() else "lane_missing",
		"adapter": adapted,
		"ledger": ledger,
		"score_result": score_result,
		"narrative": narrative,
		"lane": lane,
	}


static func _build_mode_mismatch_adapter_result(minimal_compaction: Dictionary) -> Dictionary:
	return ADAPTER_SCRIPT.build({
		"accepted": true,
		"status": "settled_cloned_at_commit",
		"prediction_generation": 1,
		"prediction_key": "mode_mismatch_regression",
		"request_snapshot": {
			"result_detail_mode": RESULT_MODE_PLAYER_SCORING,
		},
		"prediction_result": {
			"valid": true,
			"complete": true,
			"configuration": _dictionary_value(minimal_compaction, "configuration"),
			"events": _array_value(minimal_compaction, "events"),
			"balls": _make_prediction_ball_results(),
		},
	}, _make_active_shot(), {
		str(CUE_BALL_ID): CUE_BALL_ID,
		str(SCORING_BALL_ID): SCORING_BALL_ID,
	})


static func _replay_double_bank_pipeline(pipeline: Dictionary) -> Dictionary:
	if not bool(pipeline.get("valid", false)):
		return {
			"valid": false,
			"reason": str(pipeline.get("reason", "pipeline_invalid")),
		}
	var live: Variant = LIVE_ANTICIPATION_SCRIPT.new()
	var cues: Array[Dictionary] = []
	live.live_cue_requested.connect(func(cue: Dictionary) -> void:
		cues.append(cue.duplicate(true))
	)
	live.set("predicted_ledger_with_derived", _dictionary_value(pipeline, "ledger"))
	live.set("predicted_narrative", _dictionary_value(pipeline, "narrative"))
	live.call("_build_lanes_from_predicted_narrative")
	live.set("current_shot_id", SHOT_ID)
	live.set("current_attempt_id", ATTEMPT_ID)
	live.set("current_cue_ball_id", CUE_BALL_ID)
	live.set("active", true)
	live.set("anticipation_enabled", true)
	live.set("words_enabled", true)
	live.set("audio_enabled", false)
	live.set("presentation_suppressed", false)
	var raw_events: Array = _array_value(_dictionary_value(pipeline, "ledger"), "raw_events")
	for raw_value in raw_events:
		if not raw_value is Dictionary:
			continue
		var actual_event: Dictionary = (raw_value as Dictionary).duplicate(true)
		actual_event["shot_id"] = SHOT_ID
		actual_event["attempt_id"] = ATTEMPT_ID
		live.call("_on_semantic_shot_event_recorded", actual_event)
	var lane: Dictionary = _dictionary_value(live.get("lanes"), str(SCORING_BALL_ID))
	if live is Node:
		(live as Node).free()
	return {
		"valid": not lane.is_empty(),
		"lane": lane,
		"cues": cues,
	}


static func _make_double_bank_predictor_events() -> Array[Dictionary]:
	return [
		_make_predictor_ball_contact_event(0),
		_make_predictor_rail_event(
			1,
			"BottomRail",
			3,
			Vector2(560.0, 610.0),
			Vector2.UP,
			Vector2(330.0, 440.0)
		),
		_make_predictor_rail_event(
			2,
			"RightRail",
			1,
			Vector2(980.0, 420.0),
			Vector2.LEFT,
			Vector2(420.0, -190.0)
		),
		_make_predictor_pocket_event(3),
	]


static func _make_predictor_ball_contact_event(event_index: int) -> Dictionary:
	return {
		"event_type": PREDICTOR_SCRIPT.EVENT_BALL_CONTACT,
		"event_index": event_index,
		"source_ball_id": CUE_BALL_ID,
		"source_ball_number": 0,
		"source_ball_label": "Cue Ball",
		"target_ball_id": SCORING_BALL_ID,
		"target_ball_number": 2,
		"target_ball_label": "Ball 2",
		"generation_depth": 0,
		"causal_root_ball_id": CUE_BALL_ID,
		"source_parent_contact_event": -1,
		"contact_point": Vector2(315.0, 300.0),
		"collision_normal": Vector2.RIGHT,
		"incoming_source_velocity": Vector2(900.0, 0.0),
		"incoming_target_velocity": Vector2.ZERO,
		"outgoing_source_velocity": Vector2(120.0, 0.0),
		"outgoing_target_velocity": Vector2(780.0, 0.0),
		"source_radius": BALL_RADIUS,
		"target_radius": BALL_RADIUS,
		"source_center": Vector2(300.0, 300.0),
		"target_center": Vector2(328.0, 300.0),
		"effective_collision_radius": BALL_RADIUS * 2.0,
		"impact_speed": 900.0,
		"resolution_source": "swept_toi",
		"supported": true,
	}


static func _make_predictor_rail_event(
	event_index: int,
	rail_name: String,
	rail_index: int,
	ball_center: Vector2,
	normal: Vector2,
	incoming_velocity: Vector2
) -> Dictionary:
	var unit_normal: Vector2 = normal.normalized()
	return {
		"event_type": PREDICTOR_SCRIPT.EVENT_RAIL_CONTACT,
		"event_index": event_index,
		"source_ball_id": SCORING_BALL_ID,
		"source_ball_number": 2,
		"source_ball_label": "Ball 2",
		"target_ball_id": -1,
		"target_ball_number": -1,
		"generation_depth": 1,
		"causal_root_ball_id": CUE_BALL_ID,
		"source_parent_contact_event": 0,
		"source_center": ball_center,
		"target_center": ball_center,
		"ball_center_at_contact": ball_center,
		"surface_contact_point": ball_center - unit_normal * BALL_RADIUS,
		"ball_radius": BALL_RADIUS,
		"source_radius": BALL_RADIUS,
		"contact_point": ball_center,
		"collision_normal": unit_normal,
		"incoming_source_velocity": incoming_velocity,
		"incoming_target_velocity": Vector2.ZERO,
		"outgoing_source_velocity": incoming_velocity.bounce(unit_normal) * 0.78,
		"outgoing_target_velocity": Vector2.ZERO,
		"effective_collision_radius": BALL_RADIUS,
		"impact_speed": absf(incoming_velocity.dot(unit_normal)),
		"resolution_source": "boundary_sweep",
		"rail_index": rail_index,
		"rail_name": rail_name,
		"supported": true,
	}


static func _make_predictor_pocket_event(event_index: int) -> Dictionary:
	return {
		"event_type": PREDICTOR_SCRIPT.EVENT_POCKET,
		"event_index": event_index,
		"source_ball_id": SCORING_BALL_ID,
		"source_ball_number": 2,
		"source_ball_label": "Ball 2",
		"target_ball_id": -1,
		"target_ball_number": -1,
		"generation_depth": 1,
		"causal_root_ball_id": CUE_BALL_ID,
		"source_parent_contact_event": 0,
		"source_center": Vector2(1010.0, 640.0),
		"target_center": Vector2(1010.0, 640.0),
		"contact_point": Vector2(1010.0, 640.0),
		"pocket_index": 5,
		"supported": true,
	}


static func _make_prediction_ball_results() -> Array[Dictionary]:
	return [
		{
			"source_ball_id": CUE_BALL_ID,
			"source_ball_number": 0,
			"is_cue_ball": true,
			"is_eight_ball": false,
			"path_points": [Vector2(180.0, 300.0), Vector2(300.0, 300.0)],
			"ending_position": Vector2(300.0, 300.0),
			"ending_velocity": Vector2.ZERO,
			"radius": BALL_RADIUS,
			"final_stop_reason": "friction_stop",
			"pocketed": false,
			"generation_depth": 0,
			"causal_root_ball_id": CUE_BALL_ID,
			"parent_contact_event": -1,
			"parent_source_ball_id": -1,
			"first_movement_event": -1,
		},
		{
			"source_ball_id": SCORING_BALL_ID,
			"source_ball_number": 2,
			"is_cue_ball": false,
			"is_eight_ball": false,
			"path_points": [
				Vector2(328.0, 300.0),
				Vector2(560.0, 610.0),
				Vector2(980.0, 420.0),
				Vector2(1010.0, 640.0),
			],
			"ending_position": Vector2(1010.0, 640.0),
			"ending_velocity": Vector2.ZERO,
			"radius": BALL_RADIUS,
			"final_stop_reason": "pocketed",
			"pocketed": true,
			"generation_depth": 1,
			"causal_root_ball_id": CUE_BALL_ID,
			"parent_contact_event": 0,
			"parent_source_ball_id": CUE_BALL_ID,
			"first_movement_event": 0,
		},
	]


static func _make_active_shot() -> Dictionary:
	return {
		"schema_version": 2,
		"mode_id": "roguelite",
		"run_generation": 1,
		"shot_id": SHOT_ID,
		"attempt_id": ATTEMPT_ID,
		"round_index": 0,
		"round_number": 1,
		"shot_lab_active": false,
		"shot_lab_preset_id": "",
		"cue_ball_id": CUE_BALL_ID,
		"starting_balls": {
			str(CUE_BALL_ID): {
				"ball_id": CUE_BALL_ID,
				"ball_number": 0,
				"ball_kind": "cue",
				"counts_as_object_ball": false,
				"radius": BALL_RADIUS,
				"position": Vector2(180.0, 300.0),
			},
			str(SCORING_BALL_ID): {
				"ball_id": SCORING_BALL_ID,
				"ball_number": 2,
				"ball_kind": "object",
				"counts_as_object_ball": true,
				"radius": BALL_RADIUS,
				"position": Vector2(328.0, 300.0),
			},
		},
	}


static func _make_authoritative_rail_from_expected(
	expected: Dictionary,
	rail_id: String,
	rail_kind: String,
	position_offset: Vector2 = Vector2.ZERO
) -> Dictionary:
	var normal: Vector2 = _vector_value(expected, "rail_contact_normal")
	var center: Vector2 = _vector_value(
		expected,
		"ball_center_at_contact",
		Vector2.INF
	) + position_offset
	var surface: Vector2 = _vector_value(
		expected,
		"surface_contact_point",
		Vector2.INF
	) + position_offset
	return {
		"event_type": "rail_contact",
		"ball_id": int(expected.get("ball_id", -1)),
		"rail_id": rail_id,
		"rail_kind": rail_kind,
		"rail_side": _derive_rail_side(normal),
		"contact_normal": normal,
		"ball_center_at_contact": center,
		"surface_contact_point": surface,
		"contact_point": surface,
		"ball_radius": float(expected.get("ball_radius", BALL_RADIUS)),
	}


static func _find_compacted_rail(events: Array, rail_name: String) -> Dictionary:
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if (
			str(event.get("event_type", "")) == PREDICTOR_SCRIPT.EVENT_RAIL_CONTACT
			and str(event.get("rail_name", "")) == rail_name
		):
			return event
	return {}


static func _find_structural_rail(events: Array, rail_id: String) -> Dictionary:
	for event_value in events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		if (
			str(event.get("semantic_event_type", "")) == "rail_contact"
			and str(event.get("rail_id", "")) == rail_id
		):
			return event
	return {}


static func _present_fields(container: Dictionary, fields: Array[String]) -> Array[String]:
	var present: Array[String] = []
	for field in fields:
		if container.has(field):
			present.append(field)
	return present


static func _derive_rail_side(normal: Vector2) -> String:
	if normal == Vector2.ZERO:
		return "unknown"
	if absf(normal.x) > absf(normal.y):
		return "left" if normal.x > 0.0 else "right"
	return "top" if normal.y > 0.0 else "bottom"


static func _record_case(
	cases: Array[Dictionary],
	name: String,
	passed: bool,
	expected: Variant,
	actual: Variant
) -> void:
	cases.append({
		"name": name,
		"passed": passed,
		"expected": expected,
		"actual": actual,
	})


static func _finalize_report(cases: Array[Dictionary], pipeline: Dictionary) -> Dictionary:
	var passed: int = 0
	var failures: Array[Dictionary] = []
	for case_value in cases:
		if bool(case_value.get("passed", false)):
			passed += 1
		else:
			failures.append(case_value.duplicate(true))
	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"total": cases.size(),
		"passed": passed,
		"failed": failures.size(),
		"cases": cases,
		"failures": failures,
		"pipeline_reason": pipeline.get("reason", "not_built"),
		"production_result_mode": _dictionary_value(
			_dictionary_value(pipeline, "adapter"),
			"diagnostics"
		).get("prediction_result_mode", RESULT_MODE_PLAYER_SCORING),
	}


static func _format_report(report: Dictionary) -> String:
	var lines: Array[String] = [
		"Long Sink production anticipation regression: %d/%d passed (%s)" % [
			int(report.get("passed", 0)),
			int(report.get("total", 0)),
			str(report.get("status", "FAIL")),
		],
	]
	for case_value in _array_value(report, "cases"):
		if not case_value is Dictionary:
			continue
		var case: Dictionary = case_value
		lines.append("[%s] %s" % [
			"PASS" if bool(case.get("passed", false)) else "FAIL",
			str(case.get("name", "Unnamed case")),
		])
		if not bool(case.get("passed", false)):
			lines.append("  Expected: %s" % str(case.get("expected", "")))
			lines.append("  Actual: %s" % var_to_str(case.get("actual", null)))
	return "\n".join(lines)


static func _dictionary_value(container: Variant, key: String) -> Dictionary:
	if not container is Dictionary:
		return {}
	var value: Variant = (container as Dictionary).get(key, {})
	return value if value is Dictionary else {}


static func _array_value(container: Variant, key: String) -> Array:
	if not container is Dictionary:
		return []
	var value: Variant = (container as Dictionary).get(key, [])
	return value if value is Array else []


static func _vector_value(
	container: Dictionary,
	key: String,
	fallback: Vector2 = Vector2.ZERO
) -> Vector2:
	var value: Variant = container.get(key, fallback)
	return value if value is Vector2 else fallback
