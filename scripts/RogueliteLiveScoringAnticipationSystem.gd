extends Node
class_name RogueliteLiveScoringAnticipationSystem

signal live_cue_requested(cue: Dictionary)
signal shot_plan_frozen(snapshot: Dictionary)
signal shot_finalized(snapshot: Dictionary)
signal state_changed(snapshot: Dictionary)

const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")
const PREDICTED_LEDGER_ADAPTER := preload("res://scripts/RoguelitePredictedLedgerAdapter.gd")
const NARRATIVE_BUILDER := preload("res://scripts/RogueliteScoringNarrativeBuilder.gd")
const CUE_CONDUCTOR_SCRIPT := preload("res://scripts/RogueliteScoringCueConductor.gd")

const MAX_LOGICAL_LANES := 8
const MAX_LANE_EVENT_LOG_ENTRIES := 32
const POSITION_DIAGNOSTIC_TOLERANCE := 18.0
const SILENT_STRUCTURAL_LOOKAHEAD_LIMIT := 3
const PLAN_STATUS_FULL := "FULL"
const PLAN_STATUS_PARTIAL := "PARTIAL"
const PLAN_STATUS_DISABLED := "DISABLED"
const RAIL_CENTER_POSITION_TOLERANCE_PX := 8.0
const RAIL_SURFACE_POSITION_TOLERANCE_PX := 8.0
const RAIL_COMPATIBLE_NORMAL_TOLERANCE_DEGREES := 12.0
const RAIL_GEOMETRY_FALLBACK_POSITION_TOLERANCE_PX := 6.0
const RAIL_GEOMETRY_FALLBACK_NORMAL_TOLERANCE_DEGREES := 10.0

var table: BilliardsTable
var conductor: RogueliteScoringCueConductor

var anticipation_enabled := true
var words_enabled := true
var audio_enabled := true
var global_excitement_enabled := true
var global_excitement_strength := 1.0

var active := false
var presentation_suppressed := false
var current_shot_id := -1
var current_attempt_id := -1
var current_prediction_generation := 0
var current_prediction_key := ""
var current_prediction_result_mode := "unknown"
var predicted_ledger_with_derived: Dictionary = {}
var predicted_score_result: Dictionary = {}
var predicted_narrative: Dictionary = {}
var authoritative_narrative: Dictionary = {}
var lanes: Dictionary = {}
var predicted_ball_ids: Dictionary = {}
var prediction_adapter_diagnostics: Dictionary = {}
var prediction_normalization_diagnostics: Dictionary = {}
var current_cue_ball_id := -1
var authoritative_cue_object_contacts_seen := 0

var prediction_accepted_at_commit := false
var plan_status := PLAN_STATUS_DISABLED
var plans_frozen_total := 0
var plans_unavailable_total := 0
var matched_live_events := 0
var unmatched_predicted_events := 0
var unexpected_authoritative_events := 0
var diverged_lane_count := 0
var identity_rejection_count := 0
var presentation_cues_emitted := 0
var silent_lookahead_skips := 0
var exact_rail_matches := 0
var center_geometry_rail_matches := 0
var surface_geometry_rail_matches := 0
var kind_geometry_rail_matches := 0
var geometry_fallback_rail_matches := 0
var rail_match_failures := 0
var ambiguous_direct_activation_matches := 0
var matched_cue_recontact_milestones := 0
var matched_object_ball_tap_milestones := 0
var rejected_ambiguous_tap_contacts := 0
var last_disable_reason := "not_started"
var last_divergence: Dictionary = {}
var last_finalized_snapshot: Dictionary = {}
var last_live_sequence_snapshot: Dictionary = {}
var last_event_matching_self_test: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_conductor()


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	_ensure_conductor()
	if (
		table != null
		and table.shot_ledger_system != null
		and not table.shot_ledger_system.semantic_shot_event_recorded.is_connected(
			_on_semantic_shot_event_recorded
		)
	):
		table.shot_ledger_system.semantic_shot_event_recorded.connect(
			_on_semantic_shot_event_recorded
		)
	if (
		table != null
		and table.roguelite_scoring_system != null
		and not table.roguelite_scoring_system.roguelite_shot_score_resolved.is_connected(
			_on_authoritative_score_resolved
		)
	):
		table.roguelite_scoring_system.roguelite_shot_score_resolved.connect(
			_on_authoritative_score_resolved
		)
	_apply_conductor_configuration()
	_emit_state()


func prepare_committed_shot(
	prediction_bundle: Dictionary,
	prediction_source_to_run_id: Dictionary
) -> Dictionary:
	cancel_current_shot("new_shot", false)
	last_live_sequence_snapshot.clear()
	matched_live_events = 0
	unmatched_predicted_events = 0
	unexpected_authoritative_events = 0
	diverged_lane_count = 0
	identity_rejection_count = 0
	presentation_cues_emitted = 0
	silent_lookahead_skips = 0
	exact_rail_matches = 0
	center_geometry_rail_matches = 0
	surface_geometry_rail_matches = 0
	kind_geometry_rail_matches = 0
	geometry_fallback_rail_matches = 0
	rail_match_failures = 0
	ambiguous_direct_activation_matches = 0
	matched_cue_recontact_milestones = 0
	matched_object_ball_tap_milestones = 0
	rejected_ambiguous_tap_contacts = 0
	authoritative_cue_object_contacts_seen = 0
	prediction_normalization_diagnostics.clear()
	last_divergence.clear()
	if table == null or table.shot_ledger_system == null:
		return _disable_plan("shot_ledger_unavailable")
	var active_shot: Dictionary = table.shot_ledger_system.get_active_shot_snapshot()
	current_shot_id = int(active_shot.get("shot_id", -1))
	current_attempt_id = int(active_shot.get("attempt_id", -1))
	current_cue_ball_id = int(active_shot.get("cue_ball_id", -1))
	presentation_suppressed = _is_automated_shot_lab_suite_running()
	prediction_accepted_at_commit = bool(prediction_bundle.get("accepted", false))
	current_prediction_generation = int(prediction_bundle.get("prediction_generation", 0))
	current_prediction_key = str(prediction_bundle.get("prediction_key", ""))
	current_prediction_result_mode = _get_prediction_result_mode(prediction_bundle)
	if not _mode_supports_anticipation(str(active_shot.get("mode_id", ""))):
		return _disable_plan("mode_not_supported")
	if not anticipation_enabled:
		return _disable_plan("anticipation_disabled", false)
	if not prediction_accepted_at_commit:
		return _disable_plan(str(prediction_bundle.get("status", "prediction_not_accepted")))

	var adapted: Dictionary = PREDICTED_LEDGER_ADAPTER.build(
		prediction_bundle,
		active_shot,
		prediction_source_to_run_id
	)
	var adapter_diagnostics: Dictionary = _dictionary_value(adapted, "diagnostics")
	prediction_adapter_diagnostics = adapter_diagnostics.duplicate(true)
	var adapted_result_mode: String = str(adapter_diagnostics.get(
		"prediction_result_mode",
		""
	))
	if not adapted_result_mode.is_empty():
		current_prediction_result_mode = adapted_result_mode
	prediction_normalization_diagnostics = _dictionary_value(
		adapter_diagnostics,
		"normalization"
	).duplicate(true)
	if not bool(adapted.get("valid", false)):
		return _disable_plan(str(adapter_diagnostics.get("reason", "prediction_adapter_failed")))
	predicted_ledger_with_derived = _dictionary_value(adapted, "ledger").duplicate(true)
	predicted_ledger_with_derived["derived"] = ShotLedgerAnalyzer.analyze(
		predicted_ledger_with_derived
	)
	predicted_score_result = table.roguelite_scoring_system.resolve_predicted_ledger(
		predicted_ledger_with_derived,
		[]
	)
	predicted_narrative = NARRATIVE_BUILDER.build_predicted_narrative(
		predicted_ledger_with_derived,
		predicted_score_result
	)
	predicted_narrative = _attach_narrative_input_diagnostics(
		predicted_narrative,
		predicted_ledger_with_derived
	)
	var validation: Dictionary = _dictionary_value(predicted_narrative, "validation")
	if not bool(validation.get("valid", false)):
		return _disable_plan("predicted_narrative_validation_failed")
	_build_lanes_from_predicted_narrative()
	_append_incomplete_prediction_boundary_lanes()
	var lane_counts: Dictionary = _get_lane_plan_counts()
	if int(lane_counts.get("complete", 0)) <= 0:
		if _has_lane_disable_reason("missing_predicted_rail_semantic_evidence"):
			return _disable_plan("missing_predicted_rail_semantic_evidence", false)
		return _disable_plan("no_complete_predicted_scoring_lanes", false)

	active = true
	plan_status = _determine_plan_status(lane_counts)
	last_disable_reason = ""
	plans_frozen_total += 1
	if conductor != null:
		conductor.begin_live_shot(
			current_shot_id,
			current_attempt_id,
			_get_complete_predicted_narratives(),
			0.0
		)
	var snapshot: Dictionary = get_state_snapshot()
	shot_plan_frozen.emit(snapshot)
	_emit_state()
	return snapshot


func cancel_current_shot(reason: String = "canceled", stop_audio: bool = true) -> void:
	active = false
	current_shot_id = -1
	current_attempt_id = -1
	current_prediction_generation = 0
	current_prediction_key = ""
	current_prediction_result_mode = "unknown"
	current_cue_ball_id = -1
	authoritative_cue_object_contacts_seen = 0
	prediction_accepted_at_commit = false
	presentation_suppressed = false
	predicted_ledger_with_derived.clear()
	predicted_score_result.clear()
	predicted_narrative.clear()
	authoritative_narrative.clear()
	lanes.clear()
	predicted_ball_ids.clear()
	prediction_adapter_diagnostics.clear()
	prediction_normalization_diagnostics.clear()
	plan_status = PLAN_STATUS_DISABLED
	last_disable_reason = reason
	if conductor != null:
		if stop_audio:
			conductor.cancel_all(reason)
		else:
			conductor.complete_sequence(false)
	_emit_state()


func set_anticipation_enabled(value: bool) -> void:
	anticipation_enabled = value
	if not anticipation_enabled:
		cancel_current_shot("anticipation_disabled")
	_emit_state()


func set_words_enabled(value: bool) -> void:
	words_enabled = value
	_emit_state()


func set_audio_enabled(value: bool) -> void:
	audio_enabled = value
	_apply_conductor_configuration()
	_emit_state()


func set_global_excitement_enabled(value: bool) -> void:
	global_excitement_enabled = value
	_apply_conductor_configuration()
	_emit_state()


func set_global_excitement_strength(value: float) -> void:
	global_excitement_strength = clampf(value, 0.0, 2.0)
	_apply_conductor_configuration()
	_emit_state()


func get_predicted_narrative() -> Dictionary:
	return predicted_narrative.duplicate(true)


func get_authoritative_narrative() -> Dictionary:
	return authoritative_narrative.duplicate(true)


func get_replay_excitement() -> float:
	if conductor == null:
		return float(last_live_sequence_snapshot.get("peak_global_excitement", 0.0))
	var conductor_snapshot: Dictionary = conductor.get_state_snapshot()
	var current_peak: float = float(conductor_snapshot.get(
		"current_sequence_peak_excitement",
		conductor_snapshot.get("peak_global_excitement", 0.0)
	))
	return maxf(
		current_peak,
		float(last_live_sequence_snapshot.get("peak_global_excitement", 0.0))
	)


func get_conductor() -> RogueliteScoringCueConductor:
	_ensure_conductor()
	return conductor


func get_state_snapshot() -> Dictionary:
	var predicted_diagnostics: Dictionary = _dictionary_value(predicted_narrative, "diagnostics")
	var authoritative_diagnostics: Dictionary = _dictionary_value(authoritative_narrative, "diagnostics")
	var predicted_input_diagnostics: Dictionary = _dictionary_value(
		predicted_diagnostics,
		"input_contract"
	)
	var authoritative_input_diagnostics: Dictionary = _dictionary_value(
		authoritative_diagnostics,
		"input_contract"
	)
	var conductor_snapshot: Dictionary = conductor.get_state_snapshot() if conductor != null else {}
	var lane_diagnostic_totals: Dictionary = _get_lane_diagnostic_totals()
	var lane_plan_counts: Dictionary = _get_lane_plan_counts()
	return {
		"schema_version": 1,
		"active": active,
		"anticipation_enabled": anticipation_enabled,
		"words_enabled": words_enabled,
		"audio_enabled": audio_enabled,
		"presentation_suppressed": presentation_suppressed,
		"global_excitement_enabled": global_excitement_enabled,
		"global_excitement_strength": global_excitement_strength,
		"shot_id": current_shot_id,
		"attempt_id": current_attempt_id,
		"prediction_generation": current_prediction_generation,
		"prediction_key": current_prediction_key,
		"prediction_result_mode": current_prediction_result_mode,
		"prediction_requested_result_mode": str(prediction_adapter_diagnostics.get(
			"prediction_requested_result_mode",
			current_prediction_result_mode
		)),
		"prediction_result_mode_matches_request": bool(
			prediction_adapter_diagnostics.get(
				"prediction_result_mode_matches_request",
				true
			)
		),
		"prediction_accepted_at_commit": prediction_accepted_at_commit,
		"plan_status": plan_status,
		"prediction_capped": bool(predicted_ledger_with_derived.get(
			"prediction_capped",
			false
		)),
		"prediction_unsupported": bool(predicted_ledger_with_derived.get(
			"unsupported_prediction",
			false
		)),
		"prediction_stop_reason": str(predicted_ledger_with_derived.get(
			"prediction_stop_reason",
			"none"
		)),
		"prediction_cap_affected_ball_ids": _array_value(
			predicted_ledger_with_derived,
			"prediction_cap_affected_ball_ids"
		).duplicate(),
		"prediction_unsupported_affected_ball_ids": _array_value(
			predicted_ledger_with_derived,
			"prediction_unsupported_affected_ball_ids"
		).duplicate(),
		"prediction_event_normalization": prediction_normalization_diagnostics.duplicate(true),
		"prediction_adapter": prediction_adapter_diagnostics.duplicate(true),
		"predicted_rail_events_received": int(prediction_adapter_diagnostics.get(
			"predicted_rail_events_received",
			0
		)),
		"rail_events_missing_name": int(prediction_adapter_diagnostics.get(
			"rail_events_missing_name",
			0
		)),
		"rail_events_missing_normal": int(prediction_adapter_diagnostics.get(
			"rail_events_missing_normal",
			0
		)),
		"rail_events_missing_center": int(prediction_adapter_diagnostics.get(
			"rail_events_missing_center",
			0
		)),
		"rail_events_missing_surface": int(prediction_adapter_diagnostics.get(
			"rail_events_missing_surface",
			0
		)),
		"rail_events_missing_radius": int(prediction_adapter_diagnostics.get(
			"rail_events_missing_radius",
			0
		)),
		"rail_events_eligible_for_exact_matching": int(
			prediction_adapter_diagnostics.get(
				"rail_events_eligible_for_exact_matching",
				0
			)
		),
		"rail_events_eligible_for_geometric_matching": int(
			prediction_adapter_diagnostics.get(
				"rail_events_eligible_for_geometric_matching",
				0
			)
		),
		"rail_semantic_evidence_status": _get_rail_semantic_evidence_status(),
		"rail_semantic_evidence_missing_fields": _get_rail_semantic_missing_fields(),
		"predicted_events_before_normalization": int(
			prediction_normalization_diagnostics.get("events_before_normalization", 0)
		),
		"predicted_events_after_normalization": int(
			prediction_normalization_diagnostics.get("events_after_normalization", 0)
		),
		"suppressed_predicted_overlap_contacts": int(
			prediction_normalization_diagnostics.get(
				"suppressed_sustained_pair_contacts",
				0
			)
		),
		"suppressed_predicted_non_approaching_contacts": int(
			prediction_normalization_diagnostics.get(
				"suppressed_non_approaching_contacts",
				0
			)
		),
		"predicted_scoring_ball_count": predicted_ball_ids.size(),
		"authoritative_scoring_ball_count": int(authoritative_diagnostics.get("ball_narrative_count", 0)),
		"predicted_narrative_count": int(predicted_diagnostics.get("physical_event_count", 0)),
		"authoritative_narrative_count": int(authoritative_diagnostics.get("physical_event_count", 0)),
		"scoring_ball_lane_count": lanes.size(),
		"total_predicted_scoring_lanes": int(lane_plan_counts.get("total", 0)),
		"complete_lanes": int(lane_plan_counts.get("complete", 0)),
		"incomplete_lanes": int(lane_plan_counts.get("incomplete", 0)),
		"active_lanes": int(lane_plan_counts.get("active", 0)),
		"disabled_lanes": int(lane_plan_counts.get("disabled", 0)),
		"lane_cap": MAX_LOGICAL_LANES,
		"lanes": lanes.duplicate(true),
		"structural_events_expected": int(lane_diagnostic_totals.get("expected", 0)),
		"structural_events_matched": int(lane_diagnostic_totals.get("matched", 0)),
		"silent_structural_events_matched": int(lane_diagnostic_totals.get("silent", 0)),
		"presentation_milestones_expected": int(lane_diagnostic_totals.get("presentation_expected", 0)),
		"presentation_milestones_matched": int(lane_diagnostic_totals.get("presentation_matched", 0)),
		"direct_activations_matched": int(lane_diagnostic_totals.get("direct_activations", 0)),
		"matched_live_events": matched_live_events,
		"unmatched_predicted_events": unmatched_predicted_events,
		"unexpected_authoritative_events": unexpected_authoritative_events,
		"diverged_lanes": diverged_lane_count,
		"identity_rejections": identity_rejection_count,
		"presentation_cues_emitted": presentation_cues_emitted,
		"silent_lookahead_limit": SILENT_STRUCTURAL_LOOKAHEAD_LIMIT,
		"silent_lookahead_skips": silent_lookahead_skips,
		"exact_rail_matches": exact_rail_matches,
		"center_geometry_rail_matches": center_geometry_rail_matches,
		"surface_geometry_rail_matches": surface_geometry_rail_matches,
		"tolerant_rail_matches": (
			kind_geometry_rail_matches + geometry_fallback_rail_matches
		),
		"kind_and_geometry_rail_matches": kind_geometry_rail_matches,
		"geometry_fallback_rail_matches": geometry_fallback_rail_matches,
		"rail_match_failures": rail_match_failures,
		"ambiguous_direct_activation_matches": ambiguous_direct_activation_matches,
		"cue_recontact_milestones_expected": int(
			lane_diagnostic_totals.get("cue_recontact_expected", 0)
		),
		"cue_recontact_milestones_matched": int(
			lane_diagnostic_totals.get("cue_recontact_matched", 0)
		),
		"object_ball_tap_milestones_expected": int(
			lane_diagnostic_totals.get("object_ball_tap_expected", 0)
		),
		"object_ball_tap_milestones_matched": int(
			lane_diagnostic_totals.get("object_ball_tap_matched", 0)
		),
		"matched_cue_recontact_milestones": matched_cue_recontact_milestones,
		"matched_object_ball_tap_milestones": matched_object_ball_tap_milestones,
		"rejected_ambiguous_tap_contacts": rejected_ambiguous_tap_contacts,
		"authoritative_cue_object_contacts_seen": authoritative_cue_object_contacts_seen,
		"plans_frozen_total": plans_frozen_total,
		"plans_unavailable_total": plans_unavailable_total,
		"last_disable_reason": last_disable_reason,
		"last_divergence": last_divergence.duplicate(true),
		"lane_divergence_reason": str(last_divergence.get("reason", "")),
		"predicted_narrative_input": predicted_input_diagnostics.duplicate(true),
		"authoritative_narrative_input": authoritative_input_diagnostics.duplicate(true),
		"predicted_narrative_fallback_reason": str(
			predicted_input_diagnostics.get("fallback_reason", "")
		),
		"authoritative_narrative_fallback_reason": str(
			authoritative_input_diagnostics.get("fallback_reason", "")
		),
		"predicted_final_classes_by_ball": _dictionary_value(
			predicted_diagnostics,
			"final_classes_by_ball"
		).duplicate(true),
		"authoritative_final_classes_by_ball": _dictionary_value(
			authoritative_diagnostics,
			"final_classes_by_ball"
		).duplicate(true),
		"global_excitement_peak": float(conductor_snapshot.get(
			"current_sequence_peak_excitement",
			last_live_sequence_snapshot.get("peak_global_excitement", 0.0)
		)),
		"maximum_simultaneous_audio_requests": int(conductor_snapshot.get("max_simultaneous_requests", 0)),
		"coalesced_cues": int(conductor_snapshot.get("cues_coalesced_total", 0)),
		"dropped_cues": int(conductor_snapshot.get("cues_dropped_total", 0)),
		"cue_requests_by_kind": _dictionary_value(
			conductor_snapshot,
			"request_counts_by_kind"
		).duplicate(true),
		"cue_coalesced_by_kind": _dictionary_value(
			conductor_snapshot,
			"coalesced_counts_by_kind"
		).duplicate(true),
		"cue_dropped_by_kind": _dictionary_value(
			conductor_snapshot,
			"dropped_counts_by_kind"
		).duplicate(true),
		"conductor": conductor_snapshot,
		"last_live_sequence": last_live_sequence_snapshot.duplicate(true),
		"last_finalized": last_finalized_snapshot.duplicate(true),
		"event_matching_self_test": last_event_matching_self_test.duplicate(true),
	}


func run_event_matching_self_tests() -> Dictionary:
	var cases: Array[Dictionary] = []
	var direct_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_pocket(1, 7, 0),
	]
	var direct_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 0, 1, false, [], false),
		direct_events
	)
	var direct_activation: Dictionary = _structural_event_at(direct_lane, 0)
	_append_matching_case(cases, "Direct activation is a silent prerequisite", (
		str(direct_activation.get("structural_role", "")) == "direct_activation"
		and not bool(direct_activation.get("presentation_enabled", true))
		and _event_matches_expected(direct_activation, direct_events[0])
	), {
		"role": "direct_activation", "presentation_enabled": false, "matches": true,
	}, direct_activation)

	var direct_bank_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_rail(1, 7, "TopRail"),
		_test_pocket(2, 7, 1),
	]
	var direct_bank_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 0, 2, false, [1], false),
		direct_bank_events
	)
	_append_matching_case(cases, "Direct bank keeps activation before rail", (
		_structural_roles(direct_bank_lane) == ["direct_activation", "rail_1", "pocket"]
		and int(direct_bank_lane.get("presentation_milestone_count", 0)) == 2
	), ["direct_activation", "rail_1", "pocket"], _structural_roles(direct_bank_lane))

	var double_bank_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_rail(1, 7, "TopRail"),
		_test_rail(2, 7, "RightRail"),
		_test_pocket(3, 7, 2),
	]
	var double_bank_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 0, 3, false, [1, 2], false),
		double_bank_events
	)
	_append_matching_case(cases, "Double bank retains both milestones", (
		_structural_roles(double_bank_lane) == [
			"direct_activation", "rail_1", "rail_2", "pocket",
		]
		and int(double_bank_lane.get("presentation_milestone_count", 0)) == 3
	), 3, int(double_bank_lane.get("presentation_milestone_count", 0)))

	var triple_bank_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_rail(1, 7, "TopRail"),
		_test_rail(2, 7, "RightRail"),
		_test_rail(3, 7, "BottomRail"),
		_test_pocket(4, 7, 3),
	]
	var triple_bank_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 0, 4, false, [1, 2, 3], false),
		triple_bank_events
	)
	_append_matching_case(cases, "Triple bank retains all three milestones", (
		_structural_roles(triple_bank_lane) == [
			"direct_activation", "rail_1", "rail_2", "rail_3", "pocket",
		]
		and int(triple_bank_lane.get("presentation_milestone_count", 0)) == 4
	), 4, int(triple_bank_lane.get("presentation_milestone_count", 0)))

	var combination_events: Array[Dictionary] = [
		_test_contact(0, 1, 4),
		_test_contact(1, 4, 7),
		_test_pocket(2, 7, 0),
	]
	var combination_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 1, 2, true, [], false),
		combination_events
	)
	var combination_activation: Dictionary = _structural_event_at(combination_lane, 0)
	_append_matching_case(cases, "Combination activation remains presentational", (
		str(combination_activation.get("structural_role", "")) == "combination_activation"
		and bool(combination_activation.get("presentation_enabled", false))
		and _event_matches_expected(combination_activation, combination_events[1])
	), {
		"role": "combination_activation", "presentation_enabled": true, "matches": true,
	}, combination_activation)

	var bank_combination_events: Array[Dictionary] = [
		_test_contact(0, 1, 4),
		_test_contact(1, 4, 7),
		_test_rail(2, 7, "LeftRail"),
		_test_pocket(3, 7, 1),
	]
	var bank_combination_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 1, 3, true, [2], false),
		bank_combination_events
	)
	_append_matching_case(cases, "Bank combination keeps activation and rail", (
		_structural_roles(bank_combination_lane) == [
			"combination_activation", "rail_1", "pocket",
		]
		and int(bank_combination_lane.get("presentation_milestone_count", 0)) == 3
	), 3, int(bank_combination_lane.get("presentation_milestone_count", 0)))

	var intermediate_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_contact(1, 7, 9),
		_test_rail(2, 7, "BottomRail"),
		_test_pocket(3, 7, 2),
	]
	var intermediate_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 0, 3, false, [2], false),
		intermediate_events
	)
	var intermediate_contact: Dictionary = _structural_event_at(intermediate_lane, 1)
	var ambiguous_intermediate_actual: Dictionary = intermediate_events[1].duplicate(true)
	ambiguous_intermediate_actual["source_ball_id"] = -1
	ambiguous_intermediate_actual["target_ball_id"] = -1
	ambiguous_intermediate_actual["causal_direction_ambiguous"] = true
	_append_matching_case(cases, "Predicted non-scoring contact matches silently", (
		str(intermediate_contact.get("structural_role", "")) == "ball_contact"
		and not bool(intermediate_contact.get("presentation_enabled", true))
		and _event_matches_expected(intermediate_contact, ambiguous_intermediate_actual)
	), {
		"role": "ball_contact", "presentation_enabled": false,
		"ambiguous_pair_matches": true,
	}, intermediate_contact)

	var multi_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_contact(1, 1, 8),
		_test_pocket(2, 7, 0),
		_test_pocket(3, 8, 1),
	]
	var first_multi_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 0, 2, false, [], false), multi_events
	)
	var second_multi_lane: Dictionary = _build_structural_lane(
		_test_narrative(8, 1, 3, false, [], true), multi_events
	)
	_append_matching_case(cases, "Multi-pot lanes remain independent", (
		int(first_multi_lane.get("expected_structural_event_count", 0)) == 2
		and int(second_multi_lane.get("expected_structural_event_count", 0)) == 2
		and _array_value(
			_structural_event_at(second_multi_lane, 1), "presentation_events"
		).size() == 2
		and int(first_multi_lane.get("ball_id", -1)) == 7
		and int(second_multi_lane.get("ball_id", -1)) == 8
	), {"lane_7_events": 2, "lane_8_events": 2, "shared_pocket_milestones": 2}, {
		"lane_7_events": int(first_multi_lane.get("expected_structural_event_count", 0)),
		"lane_8_events": int(second_multi_lane.get("expected_structural_event_count", 0)),
		"shared_pocket_milestones": _array_value(
			_structural_event_at(second_multi_lane, 1), "presentation_events"
		).size(),
	})

	var expected_intermediate: Dictionary = _structural_event_at(intermediate_lane, 1)
	var contradictory_contact: Dictionary = _test_contact(4, 7, 10)
	_append_matching_case(cases, "Unexpected lane contact still threatens honestly", (
		not _event_matches_expected(expected_intermediate, contradictory_contact)
		and _actual_event_threatens_lane(
			intermediate_lane, expected_intermediate, contradictory_contact
		)
	), {"matches": false, "threatens": true}, {
		"matches": _event_matches_expected(expected_intermediate, contradictory_contact),
		"threatens": _actual_event_threatens_lane(
			intermediate_lane, expected_intermediate, contradictory_contact
		),
	})

	var saved_cue_ball_id: int = current_cue_ball_id
	current_cue_ball_id = 1
	var ambiguous_direct_actual: Dictionary = direct_events[0].duplicate(true)
	ambiguous_direct_actual["source_ball_id"] = -1
	ambiguous_direct_actual["target_ball_id"] = -1
	ambiguous_direct_actual["causal_direction_ambiguous"] = true
	var ambiguous_direct_match: Dictionary = _get_event_match_result(
		direct_activation,
		ambiguous_direct_actual,
		true
	)
	_append_matching_case(cases, "First direct cue activation tolerates ambiguous causality", (
		bool(ambiguous_direct_match.get("matched", false))
		and str(ambiguous_direct_match.get("quality", ""))
			== "ambiguous_direct_first_contact"
		and not _event_matches_expected(direct_activation, ambiguous_direct_actual, false)
	), "ambiguous_direct_first_contact", ambiguous_direct_match)
	var ambiguous_combination_actual: Dictionary = combination_events[1].duplicate(true)
	ambiguous_combination_actual["source_ball_id"] = -1
	ambiguous_combination_actual["target_ball_id"] = -1
	ambiguous_combination_actual["causal_direction_ambiguous"] = true
	_append_matching_case(cases, "Combination activation keeps strict causality", (
		not _event_matches_expected(
			combination_activation,
			ambiguous_combination_actual,
			true
		)
	), false, _event_matches_expected(
		combination_activation,
		ambiguous_combination_actual,
		true
	))
	current_cue_ball_id = saved_cue_ball_id

	var exact_expected_rail: Dictionary = _structural_event_at(direct_bank_lane, 1)
	var exact_actual_rail: Dictionary = _test_rail(
		10,
		7,
		"TopRail",
		"rail",
		_vector_value(exact_expected_rail, "ball_center_at_contact"),
		_vector_value(exact_expected_rail, "rail_contact_normal", Vector2.UP)
	)
	var exact_rail_result: Dictionary = _get_rail_match_result(
		exact_expected_rail,
		exact_actual_rail
	)
	_append_matching_case(cases, "One-rail bank uses exact rail identity", (
		bool(exact_rail_result.get("matched", false))
		and str(exact_rail_result.get("quality", "")) == "exact_id"
	), "exact_id", exact_rail_result)

	var tolerant_actual_rail: Dictionary = exact_actual_rail.duplicate(true)
	tolerant_actual_rail["rail_id"] = "TopRailSegmentB"
	tolerant_actual_rail.erase("rail_kind")
	var tolerant_offset: Vector2 = Vector2(7.0, 1.0)
	tolerant_actual_rail["ball_center_at_contact"] = (
		_vector_value(exact_expected_rail, "ball_center_at_contact") + tolerant_offset
	)
	tolerant_actual_rail["surface_contact_point"] = (
		_vector_value(exact_expected_rail, "surface_contact_point") + tolerant_offset
	)
	tolerant_actual_rail["contact_point"] = tolerant_actual_rail["surface_contact_point"]
	var tolerant_rail_result: Dictionary = _get_rail_match_result(
		exact_expected_rail,
		tolerant_actual_rail
	)
	_append_matching_case(cases, "Rail identity tolerates compatible kind and geometry", (
		bool(tolerant_rail_result.get("matched", false))
		and str(tolerant_rail_result.get("quality", "")) == "kind_side_center_normal"
	), "kind_side_center_normal", tolerant_rail_result)

	var surface_actual_rail: Dictionary = tolerant_actual_rail.duplicate(true)
	surface_actual_rail["ball_center_at_contact"] = (
		_vector_value(exact_expected_rail, "ball_center_at_contact") + Vector2(20.0, 0.0)
	)
	surface_actual_rail["surface_contact_point"] = (
		_vector_value(exact_expected_rail, "surface_contact_point") + Vector2(6.0, 0.0)
	)
	surface_actual_rail["contact_point"] = surface_actual_rail["surface_contact_point"]
	var surface_rail_result: Dictionary = _get_rail_match_result(
		exact_expected_rail,
		surface_actual_rail
	)
	_append_matching_case(cases, "Compatible rail may fall back to normalized surface", (
		bool(surface_rail_result.get("matched", false))
		and str(surface_rail_result.get("quality", "")) == "kind_side_surface_normal"
	), "kind_side_surface_normal", surface_rail_result)

	var jaw_expected: Dictionary = exact_expected_rail.duplicate(true)
	jaw_expected["rail_id"] = "TopLeftJaw"
	jaw_expected["rail_kind"] = "jaw"
	var adjoining_rail_actual: Dictionary = tolerant_actual_rail.duplicate(true)
	adjoining_rail_actual["rail_kind"] = "rail"
	adjoining_rail_actual["ball_center_at_contact"] = (
		_vector_value(jaw_expected, "ball_center_at_contact") + Vector2(5.0, 0.0)
	)
	adjoining_rail_actual["surface_contact_point"] = (
		_vector_value(jaw_expected, "surface_contact_point") + Vector2(5.0, 0.0)
	)
	adjoining_rail_actual["contact_point"] = adjoining_rail_actual["surface_contact_point"]
	var jaw_fallback_result: Dictionary = _get_rail_match_result(
		jaw_expected,
		adjoining_rail_actual
	)
	_append_matching_case(cases, "Adjoining jaw and rail use geometric fallback", (
		bool(jaw_fallback_result.get("matched", false))
		and str(jaw_fallback_result.get("quality", "")) == "geometry_fallback"
	), "geometry_fallback", jaw_fallback_result)

	var distant_rail_actual: Dictionary = tolerant_actual_rail.duplicate(true)
	distant_rail_actual["ball_center_at_contact"] = (
		_vector_value(exact_expected_rail, "ball_center_at_contact") + Vector2(120.0, 0.0)
	)
	distant_rail_actual["surface_contact_point"] = (
		_vector_value(exact_expected_rail, "surface_contact_point") + Vector2(120.0, 0.0)
	)
	distant_rail_actual["contact_point"] = distant_rail_actual["surface_contact_point"]
	var failed_rail_result: Dictionary = _get_rail_match_result(
		exact_expected_rail,
		distant_rail_actual
	)
	_append_matching_case(cases, "Unrelated rail geometry remains rejected", (
		not bool(failed_rail_result.get("matched", false))
		and str(failed_rail_result.get("quality", "")) == "failed"
	), "failed", failed_rail_result)

	var incomplete_evidence_events: Array[Dictionary] = direct_bank_events.duplicate(true)
	var incomplete_evidence_rail: Dictionary = incomplete_evidence_events[1].duplicate(true)
	incomplete_evidence_rail["rail_id"] = ""
	incomplete_evidence_rail["rail_semantic_evidence_complete"] = false
	incomplete_evidence_rail["rail_semantic_evidence_missing"] = [
		"rail_name",
		"collision_normal",
	]
	incomplete_evidence_rail["contact_normal"] = Vector2.ZERO
	incomplete_evidence_events[1] = incomplete_evidence_rail
	var incomplete_evidence_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 0, 2, false, [1], false),
		incomplete_evidence_events
	)
	_append_matching_case(cases, "Incomplete rail evidence disables the lane before motion", (
		not bool(incomplete_evidence_lane.get("lane_active", true))
		and str(incomplete_evidence_lane.get("lane_plan_status", "")) == "incomplete"
		and str(incomplete_evidence_lane.get("lane_disable_reason", ""))
			== "missing_predicted_rail_semantic_evidence"
		and _array_value(
			incomplete_evidence_lane,
			"missing_predicted_rail_semantic_evidence"
		) == ["rail_name", "collision_normal"]
	), {
		"status": "incomplete",
		"reason": "missing_predicted_rail_semantic_evidence",
		"missing": ["rail_name", "collision_normal"],
	}, {
		"status": incomplete_evidence_lane.get("lane_plan_status", ""),
		"reason": incomplete_evidence_lane.get("lane_disable_reason", ""),
		"missing": incomplete_evidence_lane.get(
			"missing_predicted_rail_semantic_evidence",
			[]
		),
	})

	var opposite_side_actual: Dictionary = tolerant_actual_rail.duplicate(true)
	var opposite_normal: Vector2 = -_vector_value(
		exact_expected_rail,
		"rail_contact_normal",
		Vector2.UP
	)
	opposite_side_actual["contact_normal"] = opposite_normal
	opposite_side_actual["rail_side"] = _derive_rail_side(opposite_normal)
	var opposite_side_result: Dictionary = _get_rail_match_result(
		exact_expected_rail,
		opposite_side_actual
	)
	_append_matching_case(cases, "Opposite table sides never geometry-match", (
		not bool(opposite_side_result.get("matched", false))
		and str(opposite_side_result.get("reason", "")) == "rail_side_mismatch"
	), "rail_side_mismatch", opposite_side_result)

	var lookahead_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_contact(1, 7, 9),
		_test_rail(2, 7, "TopRail"),
		_test_pocket(3, 7, 0),
	]
	var lookahead_lane: Dictionary = _build_structural_lane(
		_test_narrative(7, 0, 3, false, [2], false),
		lookahead_events
	)
	lookahead_lane["next_structural_index"] = 1
	var lookahead_actual_rail: Dictionary = lookahead_events[2].duplicate(true)
	var lookahead_result: Dictionary = _find_silent_lookahead_match(
		lookahead_lane,
		lookahead_actual_rail,
		false
	)
	_append_matching_case(cases, "Silent contact lookahead preserves later bank milestone", (
		bool(lookahead_result.get("matched", false))
		and int(lookahead_result.get("skipped_count", 0)) == 1
		and int(lookahead_result.get("candidate_index", -1)) == 2
	), {"skipped_count": 1, "candidate_index": 2}, lookahead_result)
	var protected_milestone_lane: Dictionary = direct_bank_lane.duplicate(true)
	protected_milestone_lane["next_structural_index"] = 1
	var protected_milestone_result: Dictionary = _find_silent_lookahead_match(
		protected_milestone_lane,
		direct_bank_events[2],
		false
	)
	_append_matching_case(cases, "Lookahead never skips a bank presentation milestone", (
		not bool(protected_milestone_result.get("matched", false))
	), false, protected_milestone_result)

	var normalization_input: Array[Dictionary] = [
		_test_normalization_contact(0, 1, 7, 0.000, 0, Vector2(20.0, 20.0), 12.0),
		_test_normalization_contact(1, 1, 7, 0.005, 1, Vector2(20.5, 20.0), 8.0),
		_test_rail(2, 7, "TopRail", "rail", Vector2(40.0, 20.0), Vector2.DOWN),
		_test_normalization_contact(3, 7, 1, 0.100, 12, Vector2(32.0, 20.0), 6.0),
		_test_normalization_contact(4, 7, 9, 0.110, 13, Vector2(36.0, 20.0), -1.0),
	]
	for normalization_index in range(normalization_input.size()):
		var normalization_event: Dictionary = normalization_input[normalization_index]
		normalization_event["predictor_event_index"] = normalization_index
		normalization_input[normalization_index] = normalization_event
	var normalization_result: Dictionary = (
		PREDICTED_LEDGER_ADAPTER.normalize_predicted_events_for_test(normalization_input)
	)
	var normalized_events: Array = _array_value(normalization_result, "events")
	var normalization_diagnostics: Dictionary = _dictionary_value(
		normalization_result,
		"diagnostics"
	)
	_append_matching_case(cases, "Predicted contacts normalize like semantic acceptance", (
		normalized_events.size() == 3
		and int(normalization_diagnostics.get("suppressed_sustained_pair_contacts", 0)) == 1
		and int(normalization_diagnostics.get("suppressed_non_approaching_contacts", 0)) == 1
		and int(normalization_diagnostics.get("genuine_recontacts_preserved", 0)) == 1
		and int((normalized_events[1] as Dictionary).get("predictor_event_index", -1)) == 2
		and str((normalized_events[1] as Dictionary).get("rail_kind", "")) == "rail"
	), {
		"events": 3,
		"sustained_suppressed": 1,
		"non_approaching_suppressed": 1,
		"recontacts_preserved": 1,
	}, normalization_diagnostics)

	var cap_adapter_result: Dictionary = PREDICTED_LEDGER_ADAPTER.build({
		"accepted": true,
		"prediction_generation": 1,
		"prediction_key": "cap_scope_test",
		"prediction_result": {
			"valid": true,
			"events": [],
			"truncated": true,
			"stop_reason": "max_total_iterations",
			"cap_reached": "iterations",
			"iteration_cap_detail": {"last_processed_ball_id": 103},
			"balls": [
				{
					"source_ball_id": 101,
					"pocketed": true,
					"final_stop_reason": "pocketed",
					"path_points": [Vector2.ZERO, Vector2(40.0, 0.0)],
					"ending_position": Vector2(40.0, 0.0),
					"ending_velocity": Vector2.ZERO,
				},
				{
					"source_ball_id": 102,
					"pocketed": false,
					"final_stop_reason": "max_total_iterations",
					"path_points": [Vector2(80.0, 0.0)],
					"ending_position": Vector2(80.0, 0.0),
					"ending_velocity": Vector2.ZERO,
					"parent_contact_event": -1,
					"first_movement_event": -1,
				},
				{
					"source_ball_id": 103,
					"pocketed": false,
					"final_stop_reason": "max_total_iterations",
					"path_points": [Vector2(120.0, 0.0)],
					"ending_position": Vector2(120.0, 0.0),
					"ending_velocity": Vector2.ZERO,
					"parent_contact_event": -1,
					"first_movement_event": -1,
				},
				{
					"source_ball_id": 104,
					"pocketed": false,
					"final_stop_reason": "max_total_iterations",
					"path_points": [Vector2(160.0, 0.0), Vector2(164.0, 0.0)],
					"ending_position": Vector2(164.0, 0.0),
					"ending_velocity": Vector2(2.0, 0.0),
					"parent_contact_event": 4,
					"first_movement_event": 4,
				},
			],
		},
	}, {
		"schema_version": 1,
		"mode_id": GAME_MODE_SCRIPT.MODE_SHOT_LAB,
		"shot_id": 1,
		"attempt_id": 1,
		"cue_ball_id": 1,
		"starting_balls": {
			"7": {"ball_number": 7, "ball_kind": "object", "counts_as_object_ball": true},
			"8": {"ball_number": 8, "ball_kind": "object", "counts_as_object_ball": true},
			"9": {"ball_number": 9, "ball_kind": "object", "counts_as_object_ball": true},
			"10": {"ball_number": 10, "ball_kind": "object", "counts_as_object_ball": true},
		},
	}, {
		"101": 7,
		"102": 8,
		"103": 9,
		"104": 10,
	})
	var cap_adapter_ledger: Dictionary = _dictionary_value(cap_adapter_result, "ledger")
	var scoped_cap_ids: Array = _array_value(
		cap_adapter_ledger,
		"prediction_cap_affected_ball_ids"
	)
	_append_matching_case(cases, "Cap metadata excludes stationary unrelated survivors", (
		bool(cap_adapter_result.get("valid", false))
		and scoped_cap_ids.size() == 2
		and not _int_array_contains(scoped_cap_ids, 7)
		and not _int_array_contains(scoped_cap_ids, 8)
		and _int_array_contains(scoped_cap_ids, 9)
		and _int_array_contains(scoped_cap_ids, 10)
	), [9, 10], scoped_cap_ids)

	var double_tap_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_contact(1, 1, 7),
		_test_pocket(2, 7, 0),
	]
	var double_tap_narrative: Dictionary = _test_narrative(
		7,
		0,
		2,
		false,
		[],
		false
	)
	var double_tap_presentation: Array = _array_value(double_tap_narrative, "events")
	double_tap_presentation.append({
		"event_type": "cue_recontact_milestone",
		"event_index": 1,
		"ball_id": 7,
		"contacted_ball_id": 1,
		"canonical_milestone_valid": true,
		"trigger_occurrence_id": "cue_recontact_milestone:7:1:2",
		"display_tier": "double_tap",
		"tap_family": "cue_recontact",
		"tap_ordinal": 2,
		"cue_strike_ordinal": 2,
		"tier_index": 0,
		"tier_count": 1,
		"live_title": "DOUBLE TAP!",
	})
	double_tap_narrative["events"] = double_tap_presentation
	var double_tap_lane: Dictionary = _build_structural_lane(
		double_tap_narrative,
		double_tap_events
	)
	var double_tap_expected: Dictionary = _structural_event_at(double_tap_lane, 1)
	_append_matching_case(cases, "Double Tap requires exact directed cue recontact", (
		_structural_roles(double_tap_lane) == [
			"direct_activation", "cue_recontact_milestone", "pocket",
		]
		and bool(_get_event_match_result(
			double_tap_expected,
			double_tap_events[1],
			false
		).get("matched", false))
	), ["direct_activation", "cue_recontact_milestone", "pocket"], {
		"roles": _structural_roles(double_tap_lane),
		"match": _get_event_match_result(
			double_tap_expected,
			double_tap_events[1],
			false
		),
	})
	var ambiguous_tap_actual: Dictionary = double_tap_events[1].duplicate(true)
	ambiguous_tap_actual["source_ball_id"] = -1
	ambiguous_tap_actual["target_ball_id"] = -1
	ambiguous_tap_actual["causal_direction_ambiguous"] = true
	var ambiguous_tap_result: Dictionary = _get_event_match_result(
		double_tap_expected,
		ambiguous_tap_actual,
		false
	)
	_append_matching_case(cases, "Ambiguous Tap causality never overpromises", (
		not bool(ambiguous_tap_result.get("matched", false))
		and str(ambiguous_tap_result.get("reason", "")) == "ambiguous_tap_causality"
	), "ambiguous_tap_causality", ambiguous_tap_result)
	var incomplete_tap_narrative: Dictionary = double_tap_narrative.duplicate(true)
	var incomplete_tap_events: Array = _array_value(incomplete_tap_narrative, "events")
	var incomplete_tap_event: Dictionary = _dictionary_at(incomplete_tap_events, 1)
	incomplete_tap_event["canonical_milestone_valid"] = false
	incomplete_tap_events[1] = incomplete_tap_event
	incomplete_tap_narrative["events"] = incomplete_tap_events
	var incomplete_tap_lane: Dictionary = _build_structural_lane(
		incomplete_tap_narrative,
		double_tap_events
	)
	_append_matching_case(cases, "Incomplete Tap prediction stays silent", (
		not bool(incomplete_tap_lane.get("lane_active", true))
		and str(incomplete_tap_lane.get("lane_disable_reason", ""))
			== "missing_predicted_tap_causality"
	), "missing_predicted_tap_causality", {
		"lane_active": incomplete_tap_lane.get("lane_active", true),
		"reason": incomplete_tap_lane.get("lane_disable_reason", ""),
	})

	var ball_tap_events: Array[Dictionary] = [
		_test_contact(0, 1, 7),
		_test_contact(1, 7, 9),
		_test_pocket(2, 7, 0),
	]
	var ball_tap_narrative: Dictionary = _test_narrative(
		7,
		0,
		2,
		false,
		[],
		false
	)
	var ball_tap_presentation: Array = _array_value(ball_tap_narrative, "events")
	ball_tap_presentation.append({
		"event_type": "object_ball_tap_milestone",
		"event_index": 1,
		"ball_id": 7,
		"contacted_ball_id": 9,
		"canonical_milestone_valid": true,
		"trigger_occurrence_id": "object_ball_tap_milestone:7:9:1",
		"display_tier": "ball_tap",
		"tap_family": "object_ball_tap",
		"tap_ordinal": 1,
		"unique_contact_ordinal": 1,
		"tier_index": 0,
		"tier_count": 1,
		"live_title": "BALL TAP!",
	})
	ball_tap_narrative["events"] = ball_tap_presentation
	var ball_tap_lane: Dictionary = _build_structural_lane(
		ball_tap_narrative,
		ball_tap_events
	)
	var ball_tap_expected: Dictionary = _structural_event_at(ball_tap_lane, 1)
	var reversed_ball_tap: Dictionary = ball_tap_events[1].duplicate(true)
	reversed_ball_tap["source_ball_id"] = 9
	reversed_ball_tap["target_ball_id"] = 7
	_append_matching_case(cases, "Ball Tap preserves striker ownership", (
		str(ball_tap_expected.get("structural_role", ""))
			== "object_ball_tap_milestone"
		and bool(_get_event_match_result(
			ball_tap_expected,
			ball_tap_events[1],
			false
		).get("matched", false))
		and not bool(_get_event_match_result(
			ball_tap_expected,
			reversed_ball_tap,
			false
		).get("matched", false))
	), {"forward": true, "reverse": false}, {
		"forward": _get_event_match_result(
			ball_tap_expected,
			ball_tap_events[1],
			false
		),
		"reverse": _get_event_match_result(
			ball_tap_expected,
			reversed_ball_tap,
			false
		),
	})

	var saved_predicted_ledger: Dictionary = predicted_ledger_with_derived.duplicate(true)
	var saved_lanes: Dictionary = lanes.duplicate(true)
	predicted_ledger_with_derived = {
		"prediction_capped": true,
		"unsupported_prediction": false,
		"prediction_cap_affected_ball_ids": [8],
		"prediction_unsupported_affected_ball_ids": [],
	}
	var partial_complete_lane: Dictionary = direct_bank_lane.duplicate(true)
	_classify_lane_against_prediction_metadata(partial_complete_lane)
	var partial_incomplete_lane: Dictionary = _make_incomplete_boundary_lane(
		8,
		{"ball_number": 8, "counts_as_object_ball": true},
		"prediction_cap_before_pocket"
	)
	lanes = {
		"7": partial_complete_lane,
		"8": partial_incomplete_lane,
	}
	var partial_counts: Dictionary = _get_lane_plan_counts()
	var partial_status: String = _determine_plan_status(partial_counts)
	_append_matching_case(cases, "Capped unrelated branch preserves complete bank lane", (
		bool(partial_complete_lane.get("prediction_complete_through_pocket", false))
		and not bool(partial_incomplete_lane.get("prediction_complete_through_pocket", true))
		and partial_status == PLAN_STATUS_PARTIAL
		and int(partial_counts.get("complete", 0)) == 1
		and int(partial_counts.get("incomplete", 0)) == 1
	), {
		"status": PLAN_STATUS_PARTIAL,
		"complete": 1,
		"incomplete": 1,
	}, {
		"status": partial_status,
		"counts": partial_counts,
		"complete_lane": partial_complete_lane,
		"incomplete_lane": partial_incomplete_lane,
	})
	predicted_ledger_with_derived = saved_predicted_ledger
	lanes = saved_lanes

	var failures: Array[Dictionary] = []
	var passed: int = 0
	for case_value in cases:
		if bool(case_value.get("passed", false)):
			passed += 1
		else:
			failures.append(case_value.duplicate(true))
	last_event_matching_self_test = {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"total": cases.size(),
		"passed": passed,
		"failed": failures.size(),
		"cases": cases,
		"failures": failures,
	}
	_emit_state()
	return last_event_matching_self_test.duplicate(true)


func _on_semantic_shot_event_recorded(event: Dictionary) -> void:
	if not active:
		return
	if (
		int(event.get("shot_id", -1)) != current_shot_id
		or int(event.get("attempt_id", -1)) != current_attempt_id
	):
		identity_rejection_count += 1
		return
	var is_cue_object_contact: bool = _is_authoritative_cue_object_contact(event)
	var allow_ambiguous_direct_activation: bool = (
		is_cue_object_contact and authoritative_cue_object_contacts_seen == 0
	)
	for lane_key_value in lanes.keys():
		var lane_key: String = str(lane_key_value)
		var lane_value: Variant = lanes.get(lane_key, {})
		if not lane_value is Dictionary:
			continue
		var lane: Dictionary = lane_value
		if (
			str(lane.get("lane_plan_status", "incomplete")) != "complete"
			or not bool(lane.get("lane_active", false))
			or bool(lane.get("diverged", false))
			or bool(lane.get("completed", false))
		):
			continue
		var structural_events: Array = _array_value(lane, "structural_expected_events")
		var next_index: int = int(lane.get("next_structural_index", 0))
		if next_index >= structural_events.size():
			lane["completed"] = true
			_refresh_lane_next_event_diagnostics(lane)
			_refresh_lane_milestone_diagnostics(lane)
			lanes[lane_key] = lane
			continue
		var expected_value: Variant = structural_events[next_index]
		if not expected_value is Dictionary:
			_mark_lane_diverged(lane_key, lane, "invalid_structural_event", event)
			continue
		var expected: Dictionary = expected_value
		var match_result: Dictionary = _get_event_match_result(
			expected,
			event,
			allow_ambiguous_direct_activation
		)
		if bool(match_result.get("matched", false)):
			_consume_matching_structural_event(lane_key, lane, event, match_result)
			continue
		var lookahead_result: Dictionary = _find_silent_lookahead_match(
			lane,
			event,
			allow_ambiguous_direct_activation
		)
		if bool(lookahead_result.get("matched", false)):
			_apply_silent_lookahead_skip(lane, lookahead_result, event)
			_consume_matching_structural_event(
				lane_key,
				lane,
				event,
				_dictionary_value(lookahead_result, "match_result")
			)
			continue
		if _actual_event_threatens_lane(lane, expected, event):
			var divergence_reason: String = "expected_%s_received_%s" % [
				str(expected.get("semantic_event_type", "event")),
				str(event.get("event_type", "event")),
			]
			if (
				str(expected.get("semantic_event_type", "")) == "rail_contact"
				and str(event.get("event_type", "")) == "rail_contact"
			):
				divergence_reason = str(match_result.get(
					"reason",
					"rail_identity_or_geometry_mismatch"
				))
			_mark_lane_diverged(
				lane_key,
				lane,
				divergence_reason,
				event
			)
	if is_cue_object_contact:
		authoritative_cue_object_contacts_seen += 1
	_emit_state()


func _on_authoritative_score_resolved(score_result: Dictionary) -> void:
	if table == null or table.roguelite_scoring_system == null:
		return
	var completed_ledger: Dictionary = table.roguelite_scoring_system.get_source_ledger_for_result(
		score_result
	)
	if completed_ledger.is_empty():
		return
	var authoritative_ledger_with_derived: Dictionary = completed_ledger.duplicate(true)
	if not authoritative_ledger_with_derived.has("derived"):
		authoritative_ledger_with_derived["derived"] = ShotLedgerAnalyzer.analyze(
			authoritative_ledger_with_derived
		)
	authoritative_narrative = NARRATIVE_BUILDER.build_authoritative_narrative(
		authoritative_ledger_with_derived,
		score_result
	)
	authoritative_narrative = _attach_narrative_input_diagnostics(
		authoritative_narrative,
		authoritative_ledger_with_derived
	)
	unmatched_predicted_events = _count_unmatched_predicted_events()
	unexpected_authoritative_events = _count_unexpected_authoritative_events()
	if (
		int(score_result.get("shot_id", -1)) == current_shot_id
		and int(score_result.get("attempt_id", -1)) == current_attempt_id
	):
		active = false
	if conductor != null:
		last_live_sequence_snapshot = conductor.complete_sequence(false)
	last_finalized_snapshot = get_state_snapshot()
	last_finalized_snapshot.erase("last_finalized")
	shot_finalized.emit(last_finalized_snapshot.duplicate(true))
	_emit_state()


func _build_lanes_from_predicted_narrative() -> void:
	lanes.clear()
	predicted_ball_ids.clear()
	var raw_events: Array = _array_value(predicted_ledger_with_derived, "raw_events")
	for narrative_value in _array_value(predicted_narrative, "ball_narratives"):
		if not narrative_value is Dictionary or lanes.size() >= MAX_LOGICAL_LANES:
			continue
		var narrative: Dictionary = narrative_value
		var ball_id: int = int(narrative.get("ball_id", -1))
		if ball_id <= 0:
			continue
		var lane: Dictionary = _build_structural_lane(narrative, raw_events)
		if lane.is_empty():
			continue
		_classify_lane_against_prediction_metadata(lane)
		lanes[str(ball_id)] = lane
		if bool(lane.get("prediction_complete_through_pocket", false)):
			predicted_ball_ids[str(ball_id)] = true


func _classify_lane_against_prediction_metadata(lane: Dictionary) -> void:
	var ball_id: int = int(lane.get("ball_id", -1))
	var affected_by_cap: bool = _int_array_contains(
		_array_value(predicted_ledger_with_derived, "prediction_cap_affected_ball_ids"),
		ball_id
	)
	var affected_by_unsupported: bool = _int_array_contains(
		_array_value(
			predicted_ledger_with_derived,
			"prediction_unsupported_affected_ball_ids"
		),
		ball_id
	)
	lane["affected_by_prediction_cap"] = affected_by_cap
	lane["affected_by_unsupported_event"] = affected_by_unsupported
	var structurally_complete: bool = bool(lane.get(
		"prediction_complete_through_pocket",
		false
	))
	var complete: bool = structurally_complete and not affected_by_cap and not affected_by_unsupported
	var disable_reason: String = str(lane.get("lane_disable_reason", ""))
	if affected_by_unsupported:
		disable_reason = "unsupported_event_affects_lane_before_pocket"
	elif affected_by_cap:
		disable_reason = "prediction_cap_affects_lane_before_pocket"
	elif not structurally_complete and disable_reason.is_empty():
		disable_reason = "prediction_incomplete_before_pocket"
	lane["prediction_complete_through_pocket"] = complete
	lane["lane_plan_status"] = "complete" if complete else "incomplete"
	lane["lane_active"] = complete
	lane["lane_disable_reason"] = "" if complete else disable_reason


func _append_incomplete_prediction_boundary_lanes() -> void:
	var boundary_reasons: Dictionary = {}
	for ball_id_value in _array_value(
		predicted_ledger_with_derived,
		"prediction_cap_affected_ball_ids"
	):
		var cap_ball_id: int = int(ball_id_value)
		if cap_ball_id > 0:
			boundary_reasons[str(cap_ball_id)] = "prediction_cap_before_pocket"
	for ball_id_value in _array_value(
		predicted_ledger_with_derived,
		"prediction_unsupported_affected_ball_ids"
	):
		var unsupported_ball_id: int = int(ball_id_value)
		if unsupported_ball_id > 0:
			boundary_reasons[str(unsupported_ball_id)] = "unsupported_event_before_pocket"
	var starting_balls: Dictionary = _dictionary_value(
		predicted_ledger_with_derived,
		"starting_balls"
	)
	for ball_key_value in boundary_reasons.keys():
		if lanes.size() >= MAX_LOGICAL_LANES:
			break
		var ball_key: String = str(ball_key_value)
		if lanes.has(ball_key):
			continue
		var ball_snapshot: Dictionary = _dictionary_value(starting_balls, ball_key)
		if not _snapshot_is_scoring_object_ball(ball_snapshot):
			continue
		var disable_reason: String = str(boundary_reasons.get(
			ball_key,
			"prediction_incomplete_before_pocket"
		))
		lanes[ball_key] = _make_incomplete_boundary_lane(
			int(ball_key),
			ball_snapshot,
			disable_reason
		)


func _make_incomplete_boundary_lane(
	ball_id: int,
	ball_snapshot: Dictionary,
	disable_reason: String
) -> Dictionary:
	return {
		"ball_id": ball_id,
		"ball_number": int(ball_snapshot.get("ball_number", -1)),
		"planned_final_tier": 0,
		"final_classification": "incomplete_prediction_branch",
		"activation_event_index": -1,
		"pocket_event_index": -1,
		"expected_combination": false,
		"structural_expected_events": [],
		"presentation_milestones": [],
		"expected_structural_event_count": 0,
		"presentation_milestone_count": 0,
		"required_bank_milestone_count": 0,
		"retained_bank_milestone_count": 0,
		"prediction_complete_through_pocket": false,
		"rail_semantic_evidence_complete": not disable_reason.contains(
			"rail_semantic_evidence"
		),
		"missing_predicted_rail_semantic_evidence": [],
		"incomplete_rail_event_indices": [],
		"tap_causality_complete": not disable_reason.contains("tap_causality"),
		"incomplete_tap_event_indices": [],
		"affected_by_prediction_cap": disable_reason.contains("cap"),
		"affected_by_unsupported_event": disable_reason.contains("unsupported"),
		"lane_plan_status": "incomplete",
		"lane_active": false,
		"lane_disable_reason": disable_reason,
		"next_structural_index": 0,
		"matched_structural_event_count": 0,
		"silent_events_matched": 0,
		"presentation_events_matched": 0,
		"direct_activation_matched": false,
		"activation_matched": false,
		"pocket_matched": false,
		"bank_milestones": [],
		"cue_recontact_milestones": [],
		"object_ball_tap_milestones": [],
		"cue_recontact_milestones_expected": 0,
		"cue_recontact_milestones_matched": 0,
		"object_ball_tap_milestones_expected": 0,
		"object_ball_tap_milestones_matched": 0,
		"completed": false,
		"diverged": false,
		"divergence_reason": "",
		"event_log": [],
		"last_match_quality": "not_matched",
		"last_rail_match": {},
	}


func _get_complete_predicted_narratives() -> Array:
	var complete_narratives: Array = []
	for narrative_value in _array_value(predicted_narrative, "ball_narratives"):
		if not narrative_value is Dictionary:
			continue
		var narrative: Dictionary = narrative_value
		var lane: Dictionary = _dictionary_value(lanes, str(int(narrative.get("ball_id", -1))))
		if bool(lane.get("prediction_complete_through_pocket", false)):
			complete_narratives.append(narrative.duplicate(true))
	return complete_narratives


func _build_structural_lane(narrative: Dictionary, raw_events_input: Array) -> Dictionary:
	var ball_id: int = int(narrative.get("ball_id", -1))
	var plan: Dictionary = _dictionary_value(narrative, "plan")
	var activation_event_index: int = int(
		plan.get("predicted_causal_activation_event_index", -1)
	)
	var pocket_event_index: int = int(plan.get(
		"expected_pocket_event_index",
		narrative.get("pocket_event_index", -1)
	))
	if ball_id <= 0 or activation_event_index < 0 or pocket_event_index < activation_event_index:
		return {}
	var expected_combination: bool = bool(plan.get(
		"expected_combination",
		narrative.get("is_combination", false)
	))
	var presentation_lookup: Dictionary = _build_presentation_lookup(narrative)
	var required_bank_milestone_count: int = maxi(
		int(plan.get("expected_bank_tier", 0)),
		0
	)
	var ordered_raw_events: Array = raw_events_input.duplicate(true)
	ordered_raw_events.sort_custom(_raw_event_precedes)
	var structural_events: Array[Dictionary] = []
	var lane_rail_index: int = 0
	var rail_semantic_evidence_complete := true
	var missing_rail_semantic_fields: Array[String] = []
	var incomplete_rail_event_indices: Array[int] = []
	var tap_causality_complete := true
	var incomplete_tap_event_indices: Array[int] = []
	for raw_event_value in ordered_raw_events:
		if not raw_event_value is Dictionary:
			continue
		var raw_event: Dictionary = raw_event_value
		var event_index: int = int(raw_event.get("event_index", -1))
		if event_index < activation_event_index or event_index > pocket_event_index:
			continue
		if not _raw_event_is_relevant_to_lane(raw_event, ball_id):
			continue
		var presentation_events: Array = _array_value(presentation_lookup, str(event_index))
		var expected: Dictionary = _make_structural_expected_event(
			raw_event,
			ball_id,
			activation_event_index,
			expected_combination,
			presentation_events
		)
		if str(expected.get("semantic_event_type", "")) == "rail_contact":
			lane_rail_index += 1
			expected["structural_role"] = "rail_%d" % lane_rail_index
			if not bool(expected.get("rail_semantic_evidence_complete", false)):
				rail_semantic_evidence_complete = false
				incomplete_rail_event_indices.append(event_index)
				for missing_field_value in _array_value(
					expected,
					"rail_semantic_evidence_missing"
				):
					var missing_field: String = str(missing_field_value)
					if (
						not missing_field.is_empty()
						and missing_field not in missing_rail_semantic_fields
					):
						missing_rail_semantic_fields.append(missing_field)
		if str(expected.get("structural_role", "")) in [
			"cue_recontact_milestone",
			"object_ball_tap_milestone",
		]:
			var tap_presentation: Dictionary = _dictionary_value(
				expected,
				"presentation_event"
			)
			if (
				not bool(tap_presentation.get("canonical_milestone_valid", false))
				or int(expected.get("source_ball_id", -1)) <= 0
				or int(expected.get("target_ball_id", -1)) <= 0
				or bool(expected.get("causal_direction_ambiguous", true))
				or not _tap_causality_matches_canonical(
					expected,
					tap_presentation
				)
			):
				tap_causality_complete = false
				incomplete_tap_event_indices.append(event_index)
		expected["structural_order_index"] = structural_events.size()
		structural_events.append(expected)
	if structural_events.is_empty():
		return {}
	var first_structural: Dictionary = structural_events[0]
	var last_structural: Dictionary = structural_events[structural_events.size() - 1]
	if (
		int(first_structural.get("predicted_event_index", -1)) != activation_event_index
		or str(first_structural.get("semantic_event_type", "")) != "ball_contact"
		or int(last_structural.get("predicted_event_index", -1)) != pocket_event_index
		or str(last_structural.get("semantic_event_type", "")) != "pocket"
	):
		return {}
	var presentation_milestones: Array[Dictionary] = []
	for structural_index in range(structural_events.size()):
		var structural_event: Dictionary = structural_events[structural_index]
		for presentation_value in _array_value(structural_event, "presentation_events"):
			if not presentation_value is Dictionary:
				continue
			presentation_milestones.append({
				"structural_index": structural_index,
				"predicted_event_index": int(
					structural_event.get("predicted_event_index", -1)
				),
				"presentation_event": presentation_value.duplicate(true),
			})
	if presentation_milestones.size() != _presentation_lookup_event_count(presentation_lookup):
		return {}
	var bank_milestones_complete: bool = lane_rail_index >= required_bank_milestone_count
	var structurally_complete: bool = (
		bank_milestones_complete
		and rail_semantic_evidence_complete
		and tap_causality_complete
	)
	var structural_disable_reason := ""
	if not rail_semantic_evidence_complete:
		structural_disable_reason = "missing_predicted_rail_semantic_evidence"
	elif not tap_causality_complete:
		structural_disable_reason = "missing_predicted_tap_causality"
	elif not bank_milestones_complete:
		structural_disable_reason = "required_bank_milestone_missing"
	var lane: Dictionary = {
		"ball_id": ball_id,
		"ball_number": int(narrative.get("ball_number", -1)),
		"planned_final_tier": int(plan.get("expected_bank_tier", 0)),
		"final_classification": str(narrative.get("final_classification", "")),
		"activation_event_index": activation_event_index,
		"pocket_event_index": pocket_event_index,
		"expected_combination": expected_combination,
		"structural_expected_events": structural_events,
		"presentation_milestones": presentation_milestones,
		"expected_structural_event_count": structural_events.size(),
		"presentation_milestone_count": presentation_milestones.size(),
		"required_bank_milestone_count": required_bank_milestone_count,
		"retained_bank_milestone_count": lane_rail_index,
		"prediction_complete_through_pocket": structurally_complete,
		"rail_semantic_evidence_complete": rail_semantic_evidence_complete,
		"missing_predicted_rail_semantic_evidence": missing_rail_semantic_fields,
		"incomplete_rail_event_indices": incomplete_rail_event_indices,
		"tap_causality_complete": tap_causality_complete,
		"incomplete_tap_event_indices": incomplete_tap_event_indices,
		"affected_by_prediction_cap": false,
		"affected_by_unsupported_event": false,
		"lane_plan_status": "complete" if structurally_complete else "incomplete",
		"lane_active": structurally_complete,
		"lane_disable_reason": structural_disable_reason,
		"next_structural_index": 0,
		"matched_structural_event_count": 0,
		"silent_events_matched": 0,
		"presentation_events_matched": 0,
		"direct_activation_matched": false,
		"silent_lookahead_skips": 0,
		"skipped_structural_event_count": 0,
		"prediction_warning_count": 0,
		"prediction_confidence": "full",
		"last_prediction_warning": {},
		"skipped_structural_events": [],
		"exact_rail_matches": 0,
		"center_geometry_rail_matches": 0,
		"surface_geometry_rail_matches": 0,
		"kind_and_geometry_rail_matches": 0,
		"geometry_fallback_rail_matches": 0,
		"rail_match_failures": 0,
		"last_match_quality": "not_matched",
		"last_rail_match": {},
		"completed": false,
		"diverged": false,
		"divergence_reason": "",
		"divergence_event": {},
		"event_log": [],
		"expected_source_ball_id": -1,
		"expected_target_ball_id": -1,
		"actual_source_ball_id": -1,
		"actual_target_ball_id": -1,
		"expected_rail_id": "",
		"actual_rail_id": "",
		"expected_rail_kind": "",
		"actual_rail_kind": "",
		"expected_rail_side": "",
		"actual_rail_side": "",
		"last_rail_center_delta_px": INF,
		"last_rail_surface_delta_px": INF,
		"last_rail_normal_delta_degrees": INF,
		"last_rail_decision": "not_compared",
		"activation_matched": false,
		"pocket_matched": false,
		"bank_milestones": [],
		"cue_recontact_milestones": [],
		"object_ball_tap_milestones": [],
		"cue_recontact_milestones_expected": 0,
		"cue_recontact_milestones_matched": 0,
		"object_ball_tap_milestones_expected": 0,
		"object_ball_tap_milestones_matched": 0,
	}
	_refresh_lane_next_event_diagnostics(lane)
	_refresh_lane_milestone_diagnostics(lane)
	return lane


func _tap_causality_matches_canonical(
	expected: Dictionary,
	presentation_event: Dictionary
) -> bool:
	var role: String = str(expected.get("structural_role", ""))
	var scoring_ball_id: int = int(presentation_event.get(
		"ball_id",
		expected.get("ball_id", -1)
	))
	var contacted_ball_id: int = int(presentation_event.get(
		"contacted_ball_id",
		-1
	))
	var source_ball_id: int = int(expected.get("source_ball_id", -1))
	var target_ball_id: int = int(expected.get("target_ball_id", -1))
	if scoring_ball_id <= 0 or contacted_ball_id <= 0:
		return false
	if role == "cue_recontact_milestone":
		return (
			source_ball_id == contacted_ball_id
			and target_ball_id == scoring_ball_id
		)
	if role == "object_ball_tap_milestone":
		return (
			source_ball_id == scoring_ball_id
			and target_ball_id == contacted_ball_id
		)
	return false


func _build_presentation_lookup(narrative: Dictionary) -> Dictionary:
	var lookup: Dictionary = {}
	for event_value in _array_value(narrative, "events"):
		if not event_value is Dictionary:
			continue
		var narrative_event: Dictionary = event_value
		if not _is_live_presentation_event(narrative_event):
			continue
		var event_index: int = int(narrative_event.get("event_index", -1))
		if event_index < 0:
			continue
		var key: String = str(event_index)
		var attached_events: Array = _array_value(lookup, key)
		attached_events.append(narrative_event.duplicate(true))
		lookup[key] = attached_events
	return lookup


func _presentation_lookup_event_count(lookup: Dictionary) -> int:
	var count: int = 0
	for attached_value in lookup.values():
		if attached_value is Array:
			count += (attached_value as Array).size()
	return count


func _make_structural_expected_event(
	raw_event: Dictionary,
	ball_id: int,
	activation_event_index: int,
	expected_combination: bool,
	presentation_events_input: Array
) -> Dictionary:
	var event_index: int = int(raw_event.get("event_index", -1))
	var semantic_event_type: String = str(raw_event.get("event_type", ""))
	var structural_role: String = semantic_event_type
	if semantic_event_type == "ball_contact" and event_index == activation_event_index:
		structural_role = "combination_activation" if expected_combination else "direct_activation"
	elif semantic_event_type == "rail_contact":
		structural_role = "rail"
	elif semantic_event_type == "pocket":
		structural_role = "pocket"
	var presentation_events: Array[Dictionary] = []
	for presentation_value in presentation_events_input:
		if presentation_value is Dictionary:
			presentation_events.append(presentation_value.duplicate(true))
	var first_presentation: Dictionary = {}
	if not presentation_events.is_empty():
		first_presentation = presentation_events[0].duplicate(true)
		var presentation_event_type: String = str(first_presentation.get("event_type", ""))
		if presentation_event_type in [
			"cue_recontact_milestone",
			"object_ball_tap_milestone",
		]:
			structural_role = presentation_event_type
	var rail_evidence: Dictionary = {}
	if semantic_event_type == "rail_contact":
		rail_evidence = _get_predicted_rail_semantic_evidence(raw_event)
	return {
		"semantic_event_type": semantic_event_type,
		"structural_role": structural_role,
		"predicted_event_index": event_index,
		"ball_id": ball_id,
		"rail_id": str(raw_event.get("rail_id", "")),
		"rail_index": int(raw_event.get("rail_index", -1)),
		"rail_kind": str(raw_event.get("rail_kind", "")),
		"rail_side": str(raw_event.get("rail_side", "")),
		"rail_identity_source": str(raw_event.get("rail_identity_source", "missing")),
		"rail_compatibility_warning": str(raw_event.get(
			"rail_compatibility_warning",
			""
		)),
		"rail_semantic_evidence_complete": bool(rail_evidence.get(
			"complete",
			true
		)),
		"rail_semantic_evidence_missing": _array_value(
			rail_evidence,
			"missing"
		).duplicate(),
		"rail_contact_normal": _vector_value(raw_event, "contact_normal"),
		"ball_center_at_contact": _vector_value(
			raw_event,
			"ball_center_at_contact",
			Vector2.INF
		),
		"surface_contact_point": _vector_value(
			raw_event,
			"surface_contact_point",
			_vector_value(raw_event, "contact_point")
		),
		"ball_radius": maxf(float(raw_event.get("ball_radius", 0.0)), 0.0),
		"predictor_event_index": int(raw_event.get("predictor_event_index", event_index)),
		"pocket_index": int(raw_event.get("pocket_index", -1)),
		"source_ball_id": int(raw_event.get("source_ball_id", -1)),
		"target_ball_id": int(raw_event.get("target_ball_id", -1)),
		"causal_direction_ambiguous": bool(raw_event.get(
			"causal_direction_ambiguous",
			true
		)),
		"ball_a_id": int(raw_event.get("ball_a_id", -1)),
		"ball_b_id": int(raw_event.get("ball_b_id", -1)),
		"predicted_world_position": _event_position(raw_event),
		"presentation_enabled": not presentation_events.is_empty(),
		"presentation_event": first_presentation,
		"presentation_events": presentation_events,
	}


func _consume_matching_structural_event(
	lane_key: String,
	lane: Dictionary,
	actual_event: Dictionary,
	match_result: Dictionary = {}
) -> void:
	var structural_events: Array = _array_value(lane, "structural_expected_events")
	var next_index: int = int(lane.get("next_structural_index", 0))
	if next_index >= structural_events.size():
		return
	var expected_value: Variant = structural_events[next_index]
	if not expected_value is Dictionary:
		return
	var expected: Dictionary = expected_value
	var resolved_match_result: Dictionary = match_result
	if resolved_match_result.is_empty():
		resolved_match_result = _get_event_match_result(expected, actual_event, false)
	_record_lane_comparison(lane, expected, actual_event, resolved_match_result)
	_record_successful_match_quality(lane, expected, resolved_match_result)
	var presentation_events: Array = _array_value(expected, "presentation_events")
	var presentation_count: int = 0
	for presentation_value in presentation_events:
		if not presentation_value is Dictionary:
			continue
		var presentation_expected: Dictionary = expected.duplicate(true)
		presentation_expected["narrative_event"] = presentation_value.duplicate(true)
		_emit_live_milestone(lane, presentation_expected, actual_event)
		presentation_count += 1
	if presentation_count == 0:
		lane["silent_events_matched"] = int(lane.get("silent_events_matched", 0)) + 1
	else:
		lane["presentation_events_matched"] = (
			int(lane.get("presentation_events_matched", 0)) + presentation_count
		)
	if str(expected.get("structural_role", "")) == "direct_activation":
		lane["direct_activation_matched"] = true
	lane["matched_structural_event_count"] = (
		int(lane.get("matched_structural_event_count", 0)) + 1
	)
	_append_lane_event_log(lane, expected, "PRESENTED" if presentation_count > 0 else "MATCHED SILENTLY")
	next_index += 1
	lane["next_structural_index"] = next_index
	lane["completed"] = next_index >= structural_events.size()
	_refresh_lane_next_event_diagnostics(lane)
	_refresh_lane_milestone_diagnostics(lane)
	lanes[lane_key] = lane
	matched_live_events += 1


func _emit_live_milestone(
	lane: Dictionary,
	expected: Dictionary,
	actual_event: Dictionary
) -> void:
	var narrative_event: Dictionary = _dictionary_value(expected, "narrative_event")
	var event_type: String = str(narrative_event.get("event_type", ""))
	var cue_kind: String = ""
	var excitement_weight: float = 0.0
	var tap_ordinal: int = maxi(int(narrative_event.get("tap_ordinal", 0)), 0)
	match event_type:
		"combination":
			cue_kind = RogueliteScoringCueConductor.CUE_COMBINATION
			excitement_weight = 1.0
		"rail_milestone", "rail_group":
			var tier: int = clampi(int(narrative_event.get("tier_index", 0)) + 1, 1, 3)
			cue_kind = "bank_%d" % tier
			excitement_weight = [1.0, 2.0, 3.0][tier - 1]
		"pocket":
			cue_kind = RogueliteScoringCueConductor.CUE_POCKET
			excitement_weight = 2.0
		"additional_ball":
			cue_kind = RogueliteScoringCueConductor.CUE_MULTI_POT
			excitement_weight = 2.0
		"cue_recontact_milestone":
			if tap_ordinal <= 0:
				tap_ordinal = maxi(int(narrative_event.get("cue_strike_ordinal", 2)), 2)
			cue_kind = (
				RogueliteScoringCueConductor.CUE_DOUBLE_TAP
				if tap_ordinal <= 2
				else RogueliteScoringCueConductor.CUE_TRIPLE_TAP
			)
			excitement_weight = 2.0 if tap_ordinal <= 2 else 3.0
			matched_cue_recontact_milestones += 1
		"object_ball_tap_milestone":
			if tap_ordinal <= 0:
				tap_ordinal = maxi(int(narrative_event.get(
					"unique_contact_ordinal",
					1
				)), 1)
			cue_kind = (
				RogueliteScoringCueConductor.CUE_BALL_TAP
				if tap_ordinal <= 1
				else RogueliteScoringCueConductor.CUE_BALL_TAP_CHAIN
			)
			excitement_weight = 1.0 if tap_ordinal <= 1 else 2.0
			matched_object_ball_tap_milestones += 1
		_:
			return
	var world_position: Vector2 = _event_position(actual_event)
	var predicted_position_value: Variant = expected.get("predicted_world_position", Vector2.ZERO)
	var position_delta := -1.0
	if predicted_position_value is Vector2:
		position_delta = (predicted_position_value as Vector2).distance_to(world_position)
	var visual_excitement: float = 0.0
	if global_excitement_enabled:
		visual_excitement = clampf(
			float(presentation_cues_emitted + 1) * global_excitement_strength / 16.0,
			0.0,
			1.0
		)
	var cue: Dictionary = {
		"shot_id": current_shot_id,
		"attempt_id": current_attempt_id,
		"ball_id": int(lane.get("ball_id", -1)),
		"ball_number": int(lane.get("ball_number", -1)),
		"event_type": event_type,
		"actual_event_index": int(actual_event.get("event_index", -1)),
		"world_position": world_position,
		"title": str(narrative_event.get("live_title", "")),
		"tier_index": int(narrative_event.get("tier_index", 0)),
		"tier_count": int(narrative_event.get("tier_count", 1)),
		"tap_family": str(narrative_event.get("tap_family", "")),
		"display_tier": str(narrative_event.get("display_tier", "")),
		"trigger_occurrence_id": str(narrative_event.get(
			"trigger_occurrence_id",
			""
		)),
		"tap_ordinal": tap_ordinal,
		"cue_strike_ordinal": int(narrative_event.get("cue_strike_ordinal", 0)),
		"unique_contact_ordinal": int(narrative_event.get(
			"unique_contact_ordinal",
			0
		)),
		"contacted_ball_id": int(narrative_event.get("contacted_ball_id", -1)),
		"cue_kind": cue_kind,
		"excitement_weight": excitement_weight,
		"position_delta": position_delta,
		"position_outside_diagnostic_tolerance": position_delta > POSITION_DIAGNOSTIC_TOLERANCE,
		"pocket_index": int(actual_event.get("pocket_index", -1)),
		"global_excitement_normalized": visual_excitement,
	}
	if not presentation_suppressed and anticipation_enabled:
		if words_enabled:
			live_cue_requested.emit(cue.duplicate(true))
			presentation_cues_emitted += 1
		if audio_enabled and conductor != null:
			var force_distinct: bool = (
				event_type == "cue_recontact_milestone"
				or (
					event_type == "object_ball_tap_milestone"
					and tap_ordinal >= 2
				)
				or int(narrative_event.get("tier_index", 0)) >= 2
			)
			conductor.request_live_cue(
				int(cue.get("ball_id", -1)),
				cue_kind,
				world_position,
				{
					"excitement_weight": excitement_weight,
					"planned_final_tier": int(lane.get("planned_final_tier", 0)),
					"milestone": tap_ordinal,
					"tap_family": str(narrative_event.get("tap_family", "")),
					"tap_ordinal": tap_ordinal,
					"cue_key": "live:%d:%d:%d:%s:%d" % [
						current_attempt_id,
						int(cue.get("ball_id", -1)),
						int(actual_event.get("event_index", -1)),
						event_type,
						int(narrative_event.get("narrative_event_index", -1)),
					],
					"force_distinct": force_distinct,
				}
			)


func _mark_lane_diverged(
	lane_key: String,
	lane: Dictionary,
	reason: String,
	actual_event: Dictionary
) -> void:
	if bool(lane.get("diverged", false)):
		return
	var expected: Dictionary = _dictionary_value(lane, "next_structural_event")
	var failed_match: Dictionary = _get_event_match_result(expected, actual_event, false)
	if str(failed_match.get("reason", "")) == "ambiguous_tap_causality":
		rejected_ambiguous_tap_contacts += 1
	_record_lane_comparison(lane, expected, actual_event, failed_match)
	if (
		str(expected.get("semantic_event_type", "")) == "rail_contact"
		and str(actual_event.get("event_type", "")) == "rail_contact"
	):
		rail_match_failures += 1
		lane["rail_match_failures"] = int(lane.get("rail_match_failures", 0)) + 1
		lane["last_rail_match"] = failed_match.duplicate(true)
	lane["diverged"] = true
	lane["divergence_reason"] = reason
	lane["divergence_event_index"] = int(actual_event.get("event_index", -1))
	lane["divergence_event"] = actual_event.duplicate(true)
	_append_lane_event_log(lane, expected, "DIVERGED: %s" % reason)
	_refresh_lane_milestone_diagnostics(lane)
	lanes[lane_key] = lane
	diverged_lane_count += 1
	last_divergence = {
		"ball_id": int(lane.get("ball_id", -1)),
		"reason": reason,
		"expected_event": expected.duplicate(true),
		"actual_event": actual_event.duplicate(true),
		"match_result": failed_match.duplicate(true),
	}
	if conductor != null:
		conductor.mark_lane_diverged(int(lane.get("ball_id", -1)), reason)


func _event_matches_expected(
	expected: Dictionary,
	actual: Dictionary,
	allow_ambiguous_direct_activation: bool = false
) -> bool:
	return bool(_get_event_match_result(
		expected,
		actual,
		allow_ambiguous_direct_activation
	).get("matched", false))


func _get_event_match_result(
	expected: Dictionary,
	actual: Dictionary,
	allow_ambiguous_direct_activation: bool = false
) -> Dictionary:
	var expected_type: String = str(expected.get("semantic_event_type", ""))
	var actual_type: String = str(actual.get("event_type", ""))
	var result: Dictionary = {
		"matched": false,
		"quality": "failed",
		"reason": "event_type_mismatch",
		"expected_type": expected_type,
		"actual_type": actual_type,
	}
	if actual_type != expected_type:
		return result
	var ball_id: int = int(expected.get("ball_id", -1))
	match expected_type:
		"rail_contact":
			return _get_rail_match_result(expected, actual)
		"pocket":
			if int(actual.get("ball_id", -2)) != ball_id:
				result["reason"] = "pocket_ball_mismatch"
				return result
			var expected_pocket: int = int(expected.get("pocket_index", -1))
			if expected_pocket >= 0 and int(actual.get("pocket_index", -2)) != expected_pocket:
				result["reason"] = "pocket_index_mismatch"
				return result
			result.merge({"matched": true, "quality": "exact", "reason": ""}, true)
			return result
		"ball_contact":
			return _get_ball_contact_match_result(
				expected,
				actual,
				allow_ambiguous_direct_activation
			)
	return result


func _get_ball_contact_match_result(
	expected: Dictionary,
	actual: Dictionary,
	allow_ambiguous_direct_activation: bool
) -> Dictionary:
	var expected_source: int = int(expected.get("source_ball_id", -1))
	var expected_target: int = int(expected.get("target_ball_id", -1))
	var actual_a: int = int(actual.get("ball_a_id", -1))
	var actual_b: int = int(actual.get("ball_b_id", -1))
	var pair_matches: bool = (
		(actual_a == expected_source and actual_b == expected_target)
		or (actual_a == expected_target and actual_b == expected_source)
	)
	var result: Dictionary = {
		"matched": false,
		"quality": "failed",
		"reason": "ball_pair_mismatch",
		"expected_source_ball_id": expected_source,
		"expected_target_ball_id": expected_target,
		"actual_ball_a_id": actual_a,
		"actual_ball_b_id": actual_b,
	}
	if not pair_matches:
		return result
	var structural_role: String = str(expected.get("structural_role", ""))
	if structural_role in [
		"cue_recontact_milestone",
		"object_ball_tap_milestone",
	]:
		if bool(actual.get("causal_direction_ambiguous", true)):
			result["reason"] = "ambiguous_tap_causality"
			return result
		if (
			int(actual.get("source_ball_id", -1)) != expected_source
			or int(actual.get("target_ball_id", -1)) != expected_target
		):
			result["reason"] = "tap_causality_mismatch"
			return result
		result.merge({
			"matched": true,
			"quality": "exact_tap_causality",
			"reason": "",
		}, true)
		return result
	if structural_role not in ["direct_activation", "combination_activation"]:
		result.merge({"matched": true, "quality": "exact_pair", "reason": ""}, true)
		return result
	if not bool(actual.get("causal_direction_ambiguous", true)):
		if (
			int(actual.get("source_ball_id", -1)) == expected_source
			and int(actual.get("target_ball_id", -1)) == expected_target
		):
			result.merge({"matched": true, "quality": "exact_causality", "reason": ""}, true)
		else:
			result["reason"] = "activation_causality_mismatch"
		return result
	if structural_role != "direct_activation":
		result["reason"] = "ambiguous_combination_activation"
		return result
	if (
		allow_ambiguous_direct_activation
		and expected_source == current_cue_ball_id
		and expected_target == int(expected.get("ball_id", -1))
	):
		result.merge({
			"matched": true,
			"quality": "ambiguous_direct_first_contact",
			"reason": "",
		}, true)
		return result
	result["reason"] = "ambiguous_direct_not_first_cue_object_contact"
	return result


func _get_rail_match_result(expected: Dictionary, actual: Dictionary) -> Dictionary:
	var expected_ball_id: int = int(expected.get("ball_id", -1))
	var actual_ball_id: int = int(actual.get("ball_id", -2))
	var expected_id: String = str(expected.get("rail_id", ""))
	var actual_id: String = str(actual.get("rail_id", ""))
	var expected_kind: String = _resolve_rail_kind(
		str(expected.get("rail_kind", "")),
		expected_id
	)
	var actual_kind: String = _resolve_rail_kind(
		str(actual.get("rail_kind", "")),
		actual_id
	)
	var expected_normal: Vector2 = _vector_value(expected, "rail_contact_normal")
	var actual_normal: Vector2 = _vector_value(actual, "contact_normal")
	var expected_center: Vector2 = _rail_ball_center_position(expected, expected_normal)
	var actual_center: Vector2 = _rail_ball_center_position(actual, actual_normal)
	var expected_surface: Vector2 = _rail_surface_position(expected, expected_normal)
	var actual_surface: Vector2 = _rail_surface_position(actual, actual_normal)
	var center_delta: float = _finite_position_delta(expected_center, actual_center)
	var surface_delta: float = _finite_position_delta(expected_surface, actual_surface)
	var normal_angle_delta: float = _normal_angle_delta_degrees(
		expected_normal,
		actual_normal
	)
	var expected_side: String = _resolve_rail_side(
		str(expected.get("rail_side", "")),
		expected_normal
	)
	var actual_side: String = _resolve_rail_side(
		str(actual.get("rail_side", "")),
		actual_normal
	)
	var result: Dictionary = {
		"matched": false,
		"quality": "failed",
		"decision": "diverge",
		"warning": false,
		"reason": "rail_identity_or_geometry_mismatch",
		"expected_rail_id": expected_id,
		"actual_rail_id": actual_id,
		"expected_rail_kind": expected_kind,
		"actual_rail_kind": actual_kind,
		"expected_rail_side": expected_side,
		"actual_rail_side": actual_side,
		"expected_ball_center_at_contact": expected_center,
		"actual_ball_center_at_contact": actual_center,
		"expected_surface_contact_point": expected_surface,
		"actual_surface_contact_point": actual_surface,
		"center_delta_px": center_delta,
		"surface_delta_px": surface_delta,
		"position_delta_px": center_delta,
		"normal_angle_delta_degrees": normal_angle_delta,
		"center_tolerance_px": RAIL_CENTER_POSITION_TOLERANCE_PX,
		"surface_tolerance_px": RAIL_SURFACE_POSITION_TOLERANCE_PX,
		"normal_tolerance_degrees": RAIL_COMPATIBLE_NORMAL_TOLERANCE_DEGREES,
	}
	if actual_ball_id != expected_ball_id:
		result["reason"] = "rail_ball_mismatch"
		return result
	var sides_compatible: bool = _rail_sides_compatible(expected_side, actual_side)
	if not sides_compatible:
		result["reason"] = "rail_side_mismatch"
		return result
	if not expected_id.is_empty() and expected_id == actual_id:
		result.merge({
			"matched": true,
			"quality": "exact_id",
			"decision": "match",
			"reason": "",
		}, true)
		return result
	var normals_available: bool = (
		expected_normal != Vector2.ZERO and actual_normal != Vector2.ZERO
	)
	var kind_compatible: bool = (
		not expected_kind.is_empty()
		and expected_kind == actual_kind
	)
	var kind_center_geometry_match: bool = (
		kind_compatible
		and is_finite(center_delta)
		and center_delta <= RAIL_CENTER_POSITION_TOLERANCE_PX
		and normals_available
		and normal_angle_delta <= RAIL_COMPATIBLE_NORMAL_TOLERANCE_DEGREES
	)
	if kind_center_geometry_match:
		result.merge({
			"matched": true,
			"quality": "kind_side_center_normal",
			"decision": "tolerant_match",
			"warning": true,
			"reason": "rail_id_differed",
		}, true)
		return result
	var kind_surface_geometry_match: bool = (
		kind_compatible
		and is_finite(surface_delta)
		and surface_delta <= RAIL_SURFACE_POSITION_TOLERANCE_PX
		and normals_available
		and normal_angle_delta <= RAIL_COMPATIBLE_NORMAL_TOLERANCE_DEGREES
	)
	if kind_surface_geometry_match:
		result.merge({
			"matched": true,
			"quality": "kind_side_surface_normal",
			"decision": "tolerant_match",
			"warning": true,
			"reason": "rail_id_differed_center_unavailable_or_outside_tolerance",
		}, true)
		return result
	var fallback_delta: float = minf(center_delta, surface_delta)
	var fallback_geometry: String = "center" if center_delta <= surface_delta else "surface"
	var geometry_fallback_match: bool = (
		is_finite(fallback_delta)
		and fallback_delta <= RAIL_GEOMETRY_FALLBACK_POSITION_TOLERANCE_PX
		and normals_available
		and normal_angle_delta <= RAIL_GEOMETRY_FALLBACK_NORMAL_TOLERANCE_DEGREES
	)
	if geometry_fallback_match:
		result.merge({
			"matched": true,
			"quality": "geometry_fallback",
			"decision": "tolerant_match_with_warning",
			"warning": true,
			"reason": "rail_id_and_kind_differed",
			"fallback_geometry": fallback_geometry,
			"position_delta_px": fallback_delta,
			"position_tolerance_px": RAIL_GEOMETRY_FALLBACK_POSITION_TOLERANCE_PX,
			"normal_tolerance_degrees": RAIL_GEOMETRY_FALLBACK_NORMAL_TOLERANCE_DEGREES,
		}, true)
	return result


func _find_silent_lookahead_match(
	lane: Dictionary,
	actual_event: Dictionary,
	allow_ambiguous_direct_activation: bool
) -> Dictionary:
	var structural_events: Array = _array_value(lane, "structural_expected_events")
	var next_index: int = int(lane.get("next_structural_index", 0))
	var maximum_index: int = mini(
		next_index + SILENT_STRUCTURAL_LOOKAHEAD_LIMIT,
		structural_events.size() - 1
	)
	for candidate_index in range(next_index + 1, maximum_index + 1):
		var skipped_value: Variant = structural_events[candidate_index - 1]
		if not skipped_value is Dictionary:
			break
		var skipped: Dictionary = skipped_value
		if bool(skipped.get("presentation_enabled", false)):
			break
		var candidate_value: Variant = structural_events[candidate_index]
		if not candidate_value is Dictionary:
			continue
		var candidate: Dictionary = candidate_value
		var match_result: Dictionary = _get_event_match_result(
			candidate,
			actual_event,
			allow_ambiguous_direct_activation
		)
		if bool(match_result.get("matched", false)):
			return {
				"matched": true,
				"candidate_index": candidate_index,
				"skipped_count": candidate_index - next_index,
				"match_result": match_result,
			}
	return {"matched": false}


func _apply_silent_lookahead_skip(
	lane: Dictionary,
	lookahead_result: Dictionary,
	actual_event: Dictionary
) -> void:
	var structural_events: Array = _array_value(lane, "structural_expected_events")
	var start_index: int = int(lane.get("next_structural_index", 0))
	var candidate_index: int = int(lookahead_result.get("candidate_index", start_index))
	var skipped_records: Array = _array_value(lane, "skipped_structural_events")
	for skipped_index in range(start_index, candidate_index):
		if skipped_index < 0 or skipped_index >= structural_events.size():
			continue
		var skipped_value: Variant = structural_events[skipped_index]
		if not skipped_value is Dictionary:
			continue
		var skipped: Dictionary = skipped_value
		_append_lane_event_log(lane, skipped, "UNMATCHED SILENT - LOOKAHEAD SKIP")
		skipped_records.append({
			"structural_index": skipped_index,
			"predicted_event_index": int(skipped.get("predicted_event_index", -1)),
			"structural_role": str(skipped.get("structural_role", "event")),
			"actual_event_index": int(actual_event.get("event_index", -1)),
		})
	var skipped_count: int = maxi(candidate_index - start_index, 0)
	lane["skipped_structural_events"] = skipped_records
	lane["silent_lookahead_skips"] = int(lane.get("silent_lookahead_skips", 0)) + skipped_count
	lane["skipped_structural_event_count"] = int(
		lane.get("skipped_structural_event_count", 0)
	) + skipped_count
	lane["prediction_warning_count"] = int(lane.get("prediction_warning_count", 0)) + 1
	lane["prediction_confidence"] = "reduced"
	lane["last_prediction_warning"] = {
		"reason": "silent_structural_lookahead",
		"skipped_count": skipped_count,
		"from_structural_index": start_index,
		"matched_structural_index": candidate_index,
		"actual_event_index": int(actual_event.get("event_index", -1)),
	}
	lane["next_structural_index"] = candidate_index
	silent_lookahead_skips += skipped_count


func _record_successful_match_quality(
	lane: Dictionary,
	expected: Dictionary,
	match_result: Dictionary
) -> void:
	var quality: String = str(match_result.get("quality", "matched"))
	lane["last_match_quality"] = quality
	if quality == "ambiguous_direct_first_contact":
		ambiguous_direct_activation_matches += 1
	if str(expected.get("semantic_event_type", "")) != "rail_contact":
		return
	lane["last_rail_match"] = match_result.duplicate(true)
	match quality:
		"exact_id":
			exact_rail_matches += 1
			lane["exact_rail_matches"] = int(lane.get("exact_rail_matches", 0)) + 1
		"kind_side_center_normal":
			center_geometry_rail_matches += 1
			kind_geometry_rail_matches += 1
			lane["center_geometry_rail_matches"] = int(
				lane.get("center_geometry_rail_matches", 0)
			) + 1
			lane["kind_and_geometry_rail_matches"] = int(
				lane.get("kind_and_geometry_rail_matches", 0)
			) + 1
		"kind_side_surface_normal":
			surface_geometry_rail_matches += 1
			kind_geometry_rail_matches += 1
			lane["surface_geometry_rail_matches"] = int(
				lane.get("surface_geometry_rail_matches", 0)
			) + 1
			lane["kind_and_geometry_rail_matches"] = int(
				lane.get("kind_and_geometry_rail_matches", 0)
			) + 1
		"geometry_fallback":
			geometry_fallback_rail_matches += 1
			lane["geometry_fallback_rail_matches"] = int(
				lane.get("geometry_fallback_rail_matches", 0)
			) + 1
	if quality != "exact_id":
		lane["prediction_confidence"] = "reduced"
		lane["prediction_warning_count"] = int(lane.get("prediction_warning_count", 0)) + 1
		lane["last_prediction_warning"] = {
			"reason": "tolerant_rail_match",
			"quality": quality,
			"center_delta_px": float(match_result.get("center_delta_px", INF)),
			"surface_delta_px": float(match_result.get("surface_delta_px", INF)),
			"normal_angle_delta_degrees": float(
				match_result.get("normal_angle_delta_degrees", INF)
			),
		}


func _actual_event_threatens_lane(
	lane: Dictionary,
	expected: Dictionary,
	actual: Dictionary
) -> bool:
	var ball_id: int = int(lane.get("ball_id", -1))
	var actual_type: String = str(actual.get("event_type", ""))
	match actual_type:
		"rail_contact", "pocket":
			return int(actual.get("ball_id", -2)) == ball_id
		"ball_contact":
			return _ball_contact_mentions_ball(actual, ball_id)
	return false


func _raw_event_is_relevant_to_lane(event: Dictionary, ball_id: int) -> bool:
	match str(event.get("event_type", "")):
		"ball_contact":
			return (
				bool(event.get("accepted_impact", true))
				and _ball_contact_mentions_ball(event, ball_id)
			)
		"rail_contact", "pocket":
			return int(event.get("ball_id", -1)) == ball_id
	return false


func _ball_contact_mentions_ball(event: Dictionary, ball_id: int) -> bool:
	return (
		int(event.get("ball_a_id", -1)) == ball_id
		or int(event.get("ball_b_id", -1)) == ball_id
		or int(event.get("source_ball_id", -1)) == ball_id
		or int(event.get("target_ball_id", -1)) == ball_id
	)


func _is_live_presentation_event(event: Dictionary) -> bool:
	return str(event.get("event_type", "")) in [
		"combination", "rail_milestone", "rail_group", "pocket", "additional_ball",
		"cue_recontact_milestone", "object_ball_tap_milestone",
	]


func _raw_event_precedes(left_value: Variant, right_value: Variant) -> bool:
	if not left_value is Dictionary:
		return false
	if not right_value is Dictionary:
		return true
	var left: Dictionary = left_value
	var right: Dictionary = right_value
	return int(left.get("event_index", 2147483647)) < int(
		right.get("event_index", 2147483647)
	)


func _refresh_lane_next_event_diagnostics(lane: Dictionary) -> void:
	lane["has_next_expected_rail"] = false
	lane["next_expected_rail_name"] = ""
	lane["next_expected_rail_index"] = -1
	lane["next_expected_rail_normal"] = Vector2.ZERO
	lane["next_expected_rail_side"] = ""
	lane["next_expected_rail_center"] = Vector2.INF
	lane["next_expected_rail_surface"] = Vector2.INF
	lane["next_expected_rail_semantic_evidence_complete"] = false
	lane["next_expected_rail_semantic_evidence_missing"] = []
	var structural_events: Array = _array_value(lane, "structural_expected_events")
	var next_index: int = int(lane.get("next_structural_index", 0))
	if next_index < 0 or next_index >= structural_events.size():
		lane["next_structural_event"] = {}
		return
	var next_value: Variant = structural_events[next_index]
	if not next_value is Dictionary:
		lane["next_structural_event"] = {}
		return
	var next_event: Dictionary = next_value
	lane["next_structural_event"] = next_event.duplicate(true)
	var next_rail_event: Dictionary = {}
	for candidate_index in range(next_index, structural_events.size()):
		var candidate_value: Variant = structural_events[candidate_index]
		if (
			candidate_value is Dictionary
			and str((candidate_value as Dictionary).get(
				"semantic_event_type",
				""
			)) == "rail_contact"
		):
			next_rail_event = candidate_value
			break
	if not next_rail_event.is_empty():
		lane["has_next_expected_rail"] = true
		lane["next_expected_rail_name"] = str(next_rail_event.get("rail_id", ""))
		lane["next_expected_rail_index"] = int(next_rail_event.get("rail_index", -1))
		lane["next_expected_rail_normal"] = _vector_value(
			next_rail_event,
			"rail_contact_normal"
		)
		lane["next_expected_rail_side"] = str(next_rail_event.get("rail_side", ""))
		lane["next_expected_rail_center"] = _vector_value(
			next_rail_event,
			"ball_center_at_contact",
			Vector2.INF
		)
		lane["next_expected_rail_surface"] = _vector_value(
			next_rail_event,
			"surface_contact_point",
			Vector2.INF
		)
		lane["next_expected_rail_semantic_evidence_complete"] = bool(
			next_rail_event.get("rail_semantic_evidence_complete", false)
		)
		lane["next_expected_rail_semantic_evidence_missing"] = _array_value(
			next_rail_event,
			"rail_semantic_evidence_missing"
		).duplicate()
	if int(lane.get("matched_structural_event_count", 0)) == 0:
		lane["expected_source_ball_id"] = int(next_event.get("source_ball_id", -1))
		lane["expected_target_ball_id"] = int(next_event.get("target_ball_id", -1))
		lane["expected_rail_id"] = str(next_event.get("rail_id", ""))
		lane["expected_rail_kind"] = str(next_event.get("rail_kind", ""))


func _refresh_lane_milestone_diagnostics(lane: Dictionary) -> void:
	var structural_events: Array = _array_value(lane, "structural_expected_events")
	var next_index: int = int(lane.get("next_structural_index", 0))
	var activation_matched: bool = false
	var pocket_matched: bool = false
	var bank_milestones: Array[Dictionary] = []
	var cue_recontact_milestones: Array[Dictionary] = []
	var object_ball_tap_milestones: Array[Dictionary] = []
	for structural_index in range(structural_events.size()):
		var event_value: Variant = structural_events[structural_index]
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var role: String = str(event.get("structural_role", ""))
		var matched: bool = structural_index < next_index
		if role in ["direct_activation", "combination_activation"]:
			activation_matched = matched
		elif role.begins_with("rail_"):
			bank_milestones.append({
				"tier": bank_milestones.size() + 1,
				"matched": matched,
				"expected_rail_id": str(event.get("rail_id", "")),
				"expected_rail_kind": str(event.get("rail_kind", "")),
				"expected_rail_side": str(event.get("rail_side", "")),
			})
		elif role == "cue_recontact_milestone":
			var cue_presentation: Dictionary = _dictionary_value(
				event,
				"presentation_event"
			)
			cue_recontact_milestones.append({
				"matched": matched,
				"event_index": int(event.get("predicted_event_index", -1)),
				"cue_strike_ordinal": int(cue_presentation.get(
					"cue_strike_ordinal",
					cue_presentation.get("tap_ordinal", 0)
				)),
				"source_ball_id": int(event.get("source_ball_id", -1)),
				"target_ball_id": int(event.get("target_ball_id", -1)),
			})
		elif role == "object_ball_tap_milestone":
			var object_presentation: Dictionary = _dictionary_value(
				event,
				"presentation_event"
			)
			object_ball_tap_milestones.append({
				"matched": matched,
				"event_index": int(event.get("predicted_event_index", -1)),
				"unique_contact_ordinal": int(object_presentation.get(
					"unique_contact_ordinal",
					object_presentation.get("tap_ordinal", 0)
				)),
				"contacted_ball_id": int(object_presentation.get(
					"contacted_ball_id",
					event.get("target_ball_id", -1)
				)),
				"source_ball_id": int(event.get("source_ball_id", -1)),
				"target_ball_id": int(event.get("target_ball_id", -1)),
			})
		elif role == "pocket":
			pocket_matched = matched
	lane["activation_matched"] = activation_matched
	lane["pocket_matched"] = pocket_matched
	lane["bank_milestones"] = bank_milestones
	lane["cue_recontact_milestones"] = cue_recontact_milestones
	lane["object_ball_tap_milestones"] = object_ball_tap_milestones
	lane["cue_recontact_milestones_expected"] = cue_recontact_milestones.size()
	lane["cue_recontact_milestones_matched"] = _count_matched_milestones(
		cue_recontact_milestones
	)
	lane["object_ball_tap_milestones_expected"] = object_ball_tap_milestones.size()
	lane["object_ball_tap_milestones_matched"] = _count_matched_milestones(
		object_ball_tap_milestones
	)
	for tier in range(1, 4):
		var tier_matched: bool = false
		if tier <= bank_milestones.size():
			tier_matched = bool(bank_milestones[tier - 1].get("matched", false))
		lane["bank_milestone_%d_matched" % tier] = tier_matched


func _record_lane_comparison(
	lane: Dictionary,
	expected: Dictionary,
	actual: Dictionary,
	match_result: Dictionary = {}
) -> void:
	lane["expected_source_ball_id"] = int(expected.get("source_ball_id", -1))
	lane["expected_target_ball_id"] = int(expected.get("target_ball_id", -1))
	lane["actual_source_ball_id"] = int(actual.get("source_ball_id", -1))
	lane["actual_target_ball_id"] = int(actual.get("target_ball_id", -1))
	lane["expected_rail_id"] = str(expected.get("rail_id", ""))
	lane["actual_rail_id"] = str(actual.get("rail_id", ""))
	lane["expected_rail_kind"] = str(expected.get("rail_kind", ""))
	lane["actual_rail_kind"] = str(actual.get("rail_kind", ""))
	lane["last_match_quality"] = str(match_result.get("quality", "failed"))
	lane["expected_rail_side"] = str(match_result.get(
		"expected_rail_side",
		expected.get("rail_side", "")
	))
	lane["actual_rail_side"] = str(match_result.get(
		"actual_rail_side",
		actual.get("rail_side", "")
	))
	lane["last_rail_center_delta_px"] = float(match_result.get("center_delta_px", INF))
	lane["last_rail_surface_delta_px"] = float(match_result.get("surface_delta_px", INF))
	lane["last_rail_normal_delta_degrees"] = float(match_result.get(
		"normal_angle_delta_degrees",
		INF
	))
	lane["last_rail_decision"] = str(match_result.get("decision", "not_compared"))
	if not match_result.is_empty():
		lane["last_match_result"] = match_result.duplicate(true)
	lane["last_expected_event"] = expected.duplicate(true)
	lane["last_actual_event"] = actual.duplicate(true)


func _append_lane_event_log(
	lane: Dictionary,
	expected: Dictionary,
	result: String
) -> void:
	var event_log: Array = _array_value(lane, "event_log")
	var predicted_event_index: int = int(expected.get("predicted_event_index", -1))
	var structural_role: String = str(expected.get("structural_role", "event"))
	event_log.append("e%d %s - %s" % [
		predicted_event_index,
		structural_role,
		result,
	])
	while event_log.size() > MAX_LANE_EVENT_LOG_ENTRIES:
		event_log.pop_front()
	lane["event_log"] = event_log


func _get_lane_diagnostic_totals() -> Dictionary:
	var totals: Dictionary = {
		"expected": 0,
		"matched": 0,
		"silent": 0,
		"presentation_expected": 0,
		"presentation_matched": 0,
		"direct_activations": 0,
		"cue_recontact_expected": 0,
		"cue_recontact_matched": 0,
		"object_ball_tap_expected": 0,
		"object_ball_tap_matched": 0,
	}
	for lane_value in lanes.values():
		if not lane_value is Dictionary:
			continue
		var lane: Dictionary = lane_value
		totals["expected"] = int(totals["expected"]) + int(
			lane.get("expected_structural_event_count", 0)
		)
		totals["matched"] = int(totals["matched"]) + int(
			lane.get("matched_structural_event_count", 0)
		)
		totals["silent"] = int(totals["silent"]) + int(
			lane.get("silent_events_matched", 0)
		)
		totals["presentation_expected"] = int(totals["presentation_expected"]) + int(
			lane.get("presentation_milestone_count", 0)
		)
		totals["presentation_matched"] = int(totals["presentation_matched"]) + int(
			lane.get("presentation_events_matched", 0)
		)
		if bool(lane.get("direct_activation_matched", false)):
			totals["direct_activations"] = int(totals["direct_activations"]) + 1
		totals["cue_recontact_expected"] = int(
			totals["cue_recontact_expected"]
		) + int(lane.get("cue_recontact_milestones_expected", 0))
		totals["cue_recontact_matched"] = int(
			totals["cue_recontact_matched"]
		) + int(lane.get("cue_recontact_milestones_matched", 0))
		totals["object_ball_tap_expected"] = int(
			totals["object_ball_tap_expected"]
		) + int(lane.get("object_ball_tap_milestones_expected", 0))
		totals["object_ball_tap_matched"] = int(
			totals["object_ball_tap_matched"]
		) + int(lane.get("object_ball_tap_milestones_matched", 0))
	return totals


func _count_matched_milestones(milestones: Array[Dictionary]) -> int:
	var count: int = 0
	for milestone in milestones:
		if bool(milestone.get("matched", false)):
			count += 1
	return count


func _get_lane_plan_counts() -> Dictionary:
	var counts: Dictionary = {
		"total": 0,
		"complete": 0,
		"incomplete": 0,
		"active": 0,
		"disabled": 0,
		"diverged": 0,
	}
	for lane_value in lanes.values():
		if not lane_value is Dictionary:
			continue
		var lane: Dictionary = lane_value
		counts["total"] = int(counts["total"]) + 1
		var complete: bool = bool(lane.get("prediction_complete_through_pocket", false))
		if complete:
			counts["complete"] = int(counts["complete"]) + 1
		else:
			counts["incomplete"] = int(counts["incomplete"]) + 1
		if bool(lane.get("diverged", false)):
			counts["diverged"] = int(counts["diverged"]) + 1
		if (
			bool(lane.get("lane_active", false))
			and not bool(lane.get("diverged", false))
			and not bool(lane.get("completed", false))
		):
			counts["active"] = int(counts["active"]) + 1
		else:
			counts["disabled"] = int(counts["disabled"]) + 1
	return counts


func _has_lane_disable_reason(reason: String) -> bool:
	for lane_value in lanes.values():
		if (
			lane_value is Dictionary
			and str((lane_value as Dictionary).get("lane_disable_reason", "")) == reason
		):
			return true
	return false


func _determine_plan_status(lane_counts: Dictionary) -> String:
	if int(lane_counts.get("complete", 0)) <= 0:
		return PLAN_STATUS_DISABLED
	if (
		bool(predicted_ledger_with_derived.get("prediction_capped", false))
		or bool(predicted_ledger_with_derived.get("unsupported_prediction", false))
		or int(lane_counts.get("incomplete", 0)) > 0
	):
		return PLAN_STATUS_PARTIAL
	return PLAN_STATUS_FULL


func _count_unmatched_predicted_events() -> int:
	var count := 0
	for lane_value in lanes.values():
		if not lane_value is Dictionary:
			continue
		var lane: Dictionary = lane_value
		count += int(lane.get("skipped_structural_event_count", 0))
		count += maxi(
			_array_value(lane, "structural_expected_events").size()
			- int(lane.get("next_structural_index", 0)),
			0
		)
	return count


func _count_unexpected_authoritative_events() -> int:
	var count := 0
	for narrative_value in _array_value(authoritative_narrative, "ball_narratives"):
		if not narrative_value is Dictionary:
			continue
		var narrative: Dictionary = narrative_value
		if not predicted_ball_ids.has(str(int(narrative.get("ball_id", -1)))):
			count += _array_value(narrative, "events").size()
	return count


func _disable_plan(reason: String, count_unavailable: bool = true) -> Dictionary:
	active = false
	plan_status = PLAN_STATUS_DISABLED
	last_disable_reason = reason
	if count_unavailable:
		plans_unavailable_total += 1
	if conductor != null:
		conductor.cancel_all(reason)
	var snapshot: Dictionary = get_state_snapshot()
	shot_plan_frozen.emit(snapshot)
	_emit_state()
	return snapshot


func _mode_supports_anticipation(mode_id: String) -> bool:
	return mode_id in [GAME_MODE_SCRIPT.MODE_ROGUELITE, GAME_MODE_SCRIPT.MODE_SHOT_LAB]


func _is_automated_shot_lab_suite_running() -> bool:
	if table == null or not table.is_shot_lab_mode() or table.shot_lab_system == null:
		return false
	var suite: Dictionary = _dictionary_value(table.shot_lab_system.get_snapshot(), "suite")
	return bool(suite.get("running", false))


func _ensure_conductor() -> void:
	if conductor != null and is_instance_valid(conductor):
		return
	conductor = CUE_CONDUCTOR_SCRIPT.new() as RogueliteScoringCueConductor
	conductor.name = "ScoringCueConductor"
	add_child(conductor)
	_apply_conductor_configuration()


func _apply_conductor_configuration() -> void:
	if conductor == null:
		return
	conductor.set_enabled(anticipation_enabled)
	conductor.set_audio_enabled(audio_enabled)
	conductor.set_global_excitement_enabled(global_excitement_enabled)
	conductor.set_global_excitement_strength(global_excitement_strength)


func _get_prediction_result_mode(prediction_bundle: Dictionary) -> String:
	var request_snapshot: Dictionary = _dictionary_value(
		prediction_bundle,
		"request_snapshot"
	)
	var request_mode: String = str(request_snapshot.get("result_detail_mode", ""))
	if not request_mode.is_empty():
		return request_mode
	var prediction_result: Dictionary = _dictionary_value(
		prediction_bundle,
		"prediction_result"
	)
	var result_mode: String = str(prediction_result.get("result_detail_mode", ""))
	return result_mode if not result_mode.is_empty() else "unknown"


func _get_predicted_rail_semantic_evidence(event: Dictionary) -> Dictionary:
	if event.has("rail_semantic_evidence_complete"):
		return {
			"complete": bool(event.get("rail_semantic_evidence_complete", false)),
			"missing": _array_value(
				event,
				"rail_semantic_evidence_missing"
			).duplicate(),
		}
	var missing: Array[String] = []
	if str(event.get("rail_id", "")).is_empty():
		missing.append("rail_name")
	var normal: Vector2 = _vector_value(event, "contact_normal")
	if not _is_finite_vector(normal) or normal.is_zero_approx():
		missing.append("collision_normal")
	var center: Vector2 = _vector_value(
		event,
		"ball_center_at_contact",
		Vector2.INF
	)
	if not _is_finite_vector(center):
		missing.append("ball_center_at_contact")
	var surface: Vector2 = _vector_value(
		event,
		"surface_contact_point",
		Vector2.INF
	)
	if not _is_finite_vector(surface):
		missing.append("surface_contact_point")
	if not is_finite(float(event.get("ball_radius", 0.0))) or float(
		event.get("ball_radius", 0.0)
	) <= 0.0:
		missing.append("ball_radius")
	return {
		"complete": missing.is_empty(),
		"missing": missing,
	}


func _get_rail_semantic_evidence_status() -> String:
	var rail_events: int = int(prediction_adapter_diagnostics.get(
		"predicted_rail_events_received",
		0
	))
	if rail_events <= 0:
		return "NOT_APPLICABLE"
	return "COMPLETE" if _get_rail_semantic_missing_fields().is_empty() else "INCOMPLETE"


func _get_rail_semantic_missing_fields() -> Array[String]:
	var missing: Array[String] = []
	var counters: Array[Dictionary] = [
		{"field": "rail_name", "counter": "rail_events_missing_name"},
		{"field": "collision_normal", "counter": "rail_events_missing_normal"},
		{"field": "ball_center_at_contact", "counter": "rail_events_missing_center"},
		{"field": "surface_contact_point", "counter": "rail_events_missing_surface"},
		{"field": "ball_radius", "counter": "rail_events_missing_radius"},
	]
	for counter in counters:
		if int(prediction_adapter_diagnostics.get(str(counter["counter"]), 0)) > 0:
			missing.append(str(counter["field"]))
	return missing


func _event_position(event: Dictionary) -> Vector2:
	for key in [
		"surface_contact_point", "contact_point", "predicted_world_position", "pocket_center",
		"capture_position", "position",
	]:
		var value: Variant = event.get(key, null)
		if value is Vector2:
			return value
	return Vector2.ZERO


func _rail_ball_center_position(event: Dictionary, normal: Vector2) -> Vector2:
	var explicit_center: Variant = event.get("ball_center_at_contact", null)
	if explicit_center is Vector2 and _is_finite_vector(explicit_center):
		return explicit_center
	var surface: Vector2 = _rail_surface_position(event, normal, false)
	var ball_radius: float = maxf(float(event.get("ball_radius", 0.0)), 0.0)
	if _is_finite_vector(surface) and normal != Vector2.ZERO and ball_radius > 0.0:
		return surface + normal.normalized() * ball_radius
	var legacy_position: Variant = event.get("predicted_world_position", null)
	if legacy_position is Vector2 and _is_finite_vector(legacy_position):
		return legacy_position
	return Vector2.INF


func _rail_surface_position(
	event: Dictionary,
	normal: Vector2,
	allow_contact_point_fallback: bool = true
) -> Vector2:
	var explicit_surface: Variant = event.get("surface_contact_point", null)
	if explicit_surface is Vector2 and _is_finite_vector(explicit_surface):
		return explicit_surface
	if allow_contact_point_fallback:
		var contact_point: Variant = event.get("contact_point", null)
		if contact_point is Vector2 and _is_finite_vector(contact_point):
			return contact_point
	var center: Variant = event.get("ball_center_at_contact", null)
	var ball_radius: float = maxf(float(event.get("ball_radius", 0.0)), 0.0)
	if center is Vector2 and _is_finite_vector(center) and normal != Vector2.ZERO:
		return center - normal.normalized() * ball_radius
	return Vector2.INF


func _finite_position_delta(left: Vector2, right: Vector2) -> float:
	if not _is_finite_vector(left) or not _is_finite_vector(right):
		return INF
	return left.distance_to(right)


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _rail_sides_compatible(expected_side: String, actual_side: String) -> bool:
	if expected_side == "unknown" or actual_side == "unknown":
		return true
	return expected_side == actual_side


func _snapshot_is_scoring_object_ball(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	if snapshot.has("counts_as_object_ball"):
		return bool(snapshot.get("counts_as_object_ball", false))
	var ball_kind: String = str(snapshot.get("ball_kind", "unknown"))
	return ball_kind not in ["cue", "eight", "unknown"]


func _int_array_contains(values: Array, expected_value: int) -> bool:
	for value in values:
		if int(value) == expected_value:
			return true
	return false


func _is_authoritative_cue_object_contact(event: Dictionary) -> bool:
	if str(event.get("event_type", "")) != "ball_contact" or current_cue_ball_id <= 0:
		return false
	var ball_a_id: int = int(event.get("ball_a_id", -1))
	var ball_b_id: int = int(event.get("ball_b_id", -1))
	var other_ball_id: int = -1
	if ball_a_id == current_cue_ball_id:
		other_ball_id = ball_b_id
	elif ball_b_id == current_cue_ball_id:
		other_ball_id = ball_a_id
	if other_ball_id <= 0:
		return false
	var starting_balls: Dictionary = _dictionary_value(
		predicted_ledger_with_derived,
		"starting_balls"
	)
	var other_snapshot: Dictionary = _dictionary_value(starting_balls, str(other_ball_id))
	return (
		other_snapshot.is_empty()
		or bool(other_snapshot.get("counts_as_object_ball", false))
		or str(other_snapshot.get("ball_kind", "")) != "cue"
	)


func _normal_angle_delta_degrees(left: Vector2, right: Vector2) -> float:
	if left == Vector2.ZERO or right == Vector2.ZERO:
		return INF
	return rad_to_deg(acos(clampf(left.normalized().dot(right.normalized()), -1.0, 1.0)))


func _derive_rail_side(normal: Vector2) -> String:
	if normal == Vector2.ZERO:
		return "unknown"
	if absf(normal.x) > absf(normal.y):
		return "left" if normal.x > 0.0 else "right"
	return "top" if normal.y > 0.0 else "bottom"


func _resolve_rail_side(explicit_side: String, normal: Vector2) -> String:
	var normalized_side: String = explicit_side.to_lower()
	if normalized_side in ["left", "right", "top", "bottom"]:
		return normalized_side
	return _derive_rail_side(normal)


func _resolve_rail_kind(explicit_kind: String, rail_id: String) -> String:
	var normalized_kind: String = explicit_kind.to_lower()
	if normalized_kind in ["rail", "jaw"]:
		return normalized_kind
	if rail_id.is_empty():
		return ""
	return "jaw" if rail_id.to_lower().contains("jaw") else "rail"


func _attach_narrative_input_diagnostics(
	narrative: Dictionary,
	ledger_with_derived: Dictionary
) -> Dictionary:
	var annotated_narrative: Dictionary = narrative.duplicate(true)
	var diagnostics: Dictionary = _dictionary_value(annotated_narrative, "diagnostics")
	var fallback: Dictionary = _dictionary_value(annotated_narrative, "fallback")
	diagnostics["input_contract"] = _make_ledger_input_diagnostics(
		ledger_with_derived,
		str(fallback.get("reason", ""))
	)
	annotated_narrative["diagnostics"] = diagnostics
	return annotated_narrative


func _make_ledger_input_diagnostics(
	ledger_with_derived: Dictionary,
	fallback_reason: String
) -> Dictionary:
	var derived_value: Variant = ledger_with_derived.get("derived", null)
	var raw_events_value: Variant = ledger_with_derived.get("raw_events", null)
	var starting_balls_value: Variant = ledger_with_derived.get("starting_balls", null)
	var raw_event_count: int = 0
	if raw_events_value is Array:
		raw_event_count = (raw_events_value as Array).size()
	var starting_ball_count: int = 0
	if starting_balls_value is Dictionary:
		starting_ball_count = (starting_balls_value as Dictionary).size()
	return {
		"identity_present": _has_complete_ledger_identity(ledger_with_derived),
		"derived_present": derived_value is Dictionary,
		"raw_events_present": raw_events_value is Array,
		"raw_event_count": raw_event_count,
		"starting_balls_present": starting_balls_value is Dictionary,
		"starting_ball_count": starting_ball_count,
		"fallback_reason": fallback_reason,
	}


func _has_complete_ledger_identity(ledger_with_derived: Dictionary) -> bool:
	return (
		ledger_with_derived.has("run_generation")
		and ledger_with_derived.has("mode_id")
		and ledger_with_derived.has("shot_id")
		and ledger_with_derived.has("attempt_id")
		and not str(ledger_with_derived.get("mode_id", "")).is_empty()
		and int(ledger_with_derived.get("shot_id", -1)) >= 0
		and int(ledger_with_derived.get("attempt_id", -1)) >= 0
	)


func _test_contact(event_index: int, source_ball_id: int, target_ball_id: int) -> Dictionary:
	return {
		"event_index": event_index,
		"event_type": "ball_contact",
		"accepted_impact": true,
		"ball_a_id": source_ball_id,
		"ball_b_id": target_ball_id,
		"source_ball_id": source_ball_id,
		"target_ball_id": target_ball_id,
		"causal_direction_ambiguous": false,
		"contact_point": Vector2(float(event_index) * 20.0, 100.0),
	}


func _test_normalization_contact(
	event_index: int,
	source_ball_id: int,
	target_ball_id: int,
	shot_elapsed_sec: float,
	physics_frame: int,
	contact_point: Vector2,
	relative_normal_speed: float
) -> Dictionary:
	var event: Dictionary = _test_contact(event_index, source_ball_id, target_ball_id)
	event["shot_elapsed_sec"] = shot_elapsed_sec
	event["physics_frame"] = physics_frame
	event["contact_point"] = contact_point
	event["approach_evidence_available"] = true
	event["relative_normal_speed"] = relative_normal_speed
	return event


func _test_rail(
	event_index: int,
	ball_id: int,
	rail_id: String,
	rail_kind: String = "rail",
	ball_center: Vector2 = Vector2.INF,
	contact_normal: Vector2 = Vector2.UP
) -> Dictionary:
	var resolved_center: Vector2 = ball_center
	if not is_finite(resolved_center.x) or not is_finite(resolved_center.y):
		resolved_center = Vector2(float(event_index) * 20.0, 80.0)
	var ball_radius: float = 14.0
	var unit_normal: Vector2 = (
		contact_normal.normalized() if contact_normal != Vector2.ZERO else Vector2.ZERO
	)
	var surface_point: Vector2 = resolved_center - unit_normal * ball_radius
	return {
		"event_index": event_index,
		"event_type": "rail_contact",
		"ball_id": ball_id,
		"rail_id": rail_id,
		"rail_kind": rail_kind,
		"rail_side": _derive_rail_side(contact_normal),
		"ball_center_at_contact": resolved_center,
		"surface_contact_point": surface_point,
		"ball_radius": ball_radius,
		"contact_point": surface_point,
		"contact_normal": contact_normal,
	}


func _test_pocket(event_index: int, ball_id: int, pocket_index: int) -> Dictionary:
	return {
		"event_index": event_index,
		"event_type": "pocket",
		"ball_id": ball_id,
		"pocket_index": pocket_index,
		"counts_as_object_ball": true,
		"pocket_center": Vector2(float(event_index) * 20.0, 40.0),
	}


func _test_narrative(
	ball_id: int,
	activation_event_index: int,
	pocket_event_index: int,
	is_combination: bool,
	rail_event_indices: Array,
	include_additional_ball: bool
) -> Dictionary:
	var narrative_events: Array[Dictionary] = []
	if is_combination:
		narrative_events.append({
			"event_type": "combination",
			"event_index": activation_event_index,
			"ball_id": ball_id,
			"live_title": "COMBINATION!",
		})
	for rail_index in range(rail_event_indices.size()):
		narrative_events.append({
			"event_type": "rail_milestone",
			"event_index": int(rail_event_indices[rail_index]),
			"ball_id": ball_id,
			"tier_index": rail_index,
			"tier_count": rail_event_indices.size(),
			"live_title": "BANK %d" % (rail_index + 1),
		})
	narrative_events.append({
		"event_type": "pocket",
		"event_index": pocket_event_index,
		"ball_id": ball_id,
		"live_title": "SUNK!",
	})
	if include_additional_ball:
		narrative_events.append({
			"event_type": "additional_ball",
			"event_index": pocket_event_index,
			"ball_id": ball_id,
			"live_title": "MULTI-POT!",
		})
	return {
		"ball_id": ball_id,
		"ball_number": ball_id,
		"pocket_event_index": pocket_event_index,
		"final_classification": "combination" if is_combination else "direct_pot",
		"is_combination": is_combination,
		"events": narrative_events,
		"plan": {
			"predicted_causal_activation_event_index": activation_event_index,
			"expected_pocket_event_index": pocket_event_index,
			"expected_combination": is_combination,
			"expected_bank_tier": rail_event_indices.size(),
		},
	}


func _structural_event_at(lane: Dictionary, index: int) -> Dictionary:
	var events: Array = _array_value(lane, "structural_expected_events")
	if index < 0 or index >= events.size() or not events[index] is Dictionary:
		return {}
	return (events[index] as Dictionary).duplicate(true)


func _structural_roles(lane: Dictionary) -> Array[String]:
	var roles: Array[String] = []
	for event_value in _array_value(lane, "structural_expected_events"):
		if event_value is Dictionary:
			roles.append(str((event_value as Dictionary).get("structural_role", "")))
	return roles


func _append_matching_case(
	cases: Array[Dictionary],
	case_name: String,
	passed: bool,
	expected: Variant,
	actual: Variant
) -> void:
	cases.append({
		"name": case_name,
		"passed": passed,
		"expected": expected,
		"actual": actual,
	})


func _emit_state() -> void:
	state_changed.emit(get_state_snapshot())


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []


func _dictionary_at(values: Array, index: int) -> Dictionary:
	if index < 0 or index >= values.size():
		return {}
	var value: Variant = values[index]
	return value as Dictionary if value is Dictionary else {}


func _vector_value(
	container: Dictionary,
	key: String,
	fallback: Vector2 = Vector2.ZERO
) -> Vector2:
	var value: Variant = container.get(key, fallback)
	return value as Vector2 if value is Vector2 else fallback
