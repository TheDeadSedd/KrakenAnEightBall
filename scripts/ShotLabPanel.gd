extends Control
class_name ShotLabPanel

signal raw_events_requested

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const PANEL_SIZE := Vector2(900.0, 760.0)
const VIEWPORT_MARGIN := 24.0

var shot_lab_system: ShotLabSystem
var summary_label: Label
var reference_label: Label
var expected_label: Label
var observed_label: Label
var scoring_label: Label
var raw_events_label: Label
var tab_container: TabContainer
var tally_snapshot: Dictionary = {}


func setup(system_ref: ShotLabSystem) -> void:
	shot_lab_system = system_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	z_index = 135
	_build_ui()
	if not shot_lab_system.state_changed.is_connected(_on_state_changed):
		shot_lab_system.state_changed.connect(_on_state_changed)
	visible = false
	_refresh(shot_lab_system.get_snapshot())


func open_panel() -> void:
	if shot_lab_system == null:
		return
	visible = true
	shot_lab_system.set_panel_open(true)
	_center_in_viewport()
	_refresh(shot_lab_system.get_snapshot())


func open_scoring_panel() -> void:
	open_panel()
	if tab_container == null:
		return
	for tab_index in range(tab_container.get_tab_count()):
		if tab_container.get_tab_title(tab_index) == "SCORING":
			tab_container.current_tab = tab_index
			break


func close_panel() -> void:
	visible = false
	if shot_lab_system != null:
		shot_lab_system.set_panel_open(false)


func set_tally_snapshot(snapshot: Dictionary) -> void:
	tally_snapshot = snapshot.duplicate(true)
	if visible and shot_lab_system != null:
		_refresh(shot_lab_system.get_snapshot())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_center_in_viewport()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var shell := PanelContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(shell)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	shell.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	var title := _make_label("SHOT LAB INSPECTOR", 24, Color("e6c66f"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _make_button("Close")
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	tab_container = TabContainer.new()
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_theme_font_override("font", UI_FONT)
	tab_container.add_theme_font_size_override("font_size", 15)
	stack.add_child(tab_container)
	summary_label = _add_text_tab("SUMMARY")
	reference_label = _add_text_tab("REFERENCE")
	expected_label = _add_text_tab("EXPECTED")
	observed_label = _add_text_tab("OBSERVED")
	scoring_label = _add_text_tab("SCORING")
	raw_events_label = _add_text_tab("RAW EVENTS")

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	stack.add_child(footer)
	var filtered_raw_button := _make_button("Open Filtered Raw Events")
	filtered_raw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filtered_raw_button.pressed.connect(_on_raw_events_requested)
	footer.add_child(filtered_raw_button)
	var copy_result_button := _make_button("Copy Result")
	copy_result_button.pressed.connect(_call_system_action.bind("copy_last_result"))
	footer.add_child(copy_result_button)
	var copy_score_button := _make_button("Copy Score JSON")
	copy_score_button.pressed.connect(_call_system_action.bind("copy_score_breakdown_json"))
	footer.add_child(copy_score_button)
	var copy_arrangement_button := _make_button("Copy Arrangement")
	copy_arrangement_button.pressed.connect(_call_system_action.bind("copy_current_arrangement_as_preset"))
	footer.add_child(copy_arrangement_button)


func _add_text_tab(tab_name: String) -> Label:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tab_container.add_child(scroll)
	var label := _make_label("", 14, Color("d7d0bb"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(PANEL_SIZE.x - 72.0, 0.0)
	scroll.add_child(label)
	return label


func _call_system_action(method_name: String) -> void:
	if shot_lab_system != null and shot_lab_system.has_method(method_name):
		shot_lab_system.call(method_name)


func _on_raw_events_requested() -> void:
	raw_events_requested.emit()


func _on_state_changed(snapshot: Dictionary) -> void:
	if visible:
		_refresh(snapshot)


func _refresh(snapshot: Dictionary) -> void:
	if summary_label == null:
		return
	var loaded: Dictionary = _dictionary_value(snapshot, "loaded_preset")
	var result: Dictionary = _dictionary_value(snapshot, "last_result")
	var loaded_name: String = str(loaded.get("display_name", "Not loaded"))
	var description: String = str(loaded.get("description", ""))
	var summary_lines: Array[String] = [
		loaded_name,
		description,
		"",
		"ROLE MAP",
		_format_dictionary(_dictionary_value(snapshot, "role_to_ball_id")),
		"",
		"CUE LIFECYCLE",
		_format_dictionary(_dictionary_value(snapshot, "cue_lifecycle")),
		"",
	]
	if result.is_empty() or str(result.get("status", "")) == "NOT RUN":
		summary_lines.append("RESULT: NOT RUN")
		summary_lines.append("No completed laboratory shot.")
		summary_label.add_theme_color_override("font_color", Color("d7d0bb"))
	else:
		var passed: bool = bool(result.get("passed", false))
		summary_lines.append("RESULT: %s" % ("PASS" if passed else "FAIL"))
		summary_lines.append("Assertions: %d passed / %d failed" % [
			int(result.get("assertions_passed", 0)),
			int(result.get("assertions_failed", 0)),
		])
		summary_lines.append("Shot %d | Attempt %d" % [
			int(result.get("shot_id", -1)),
			int(result.get("attempt_id", -1)),
		])
		var failures: Array = _array_value(result, "failures")
		if not failures.is_empty():
			summary_lines.append("")
			summary_lines.append("FAILURES")
			for failure_value in failures:
				if failure_value is Dictionary:
					var failure: Dictionary = failure_value
					summary_lines.append("- %s: expected %s, observed %s" % [
						str(failure.get("path", "assertion")),
						str(failure.get("expected", "")),
						str(failure.get("actual", "")),
					])
		summary_label.add_theme_color_override("font_color", Color("7dd9a2") if passed else Color("ef8a79"))
	var suite: Dictionary = _dictionary_value(snapshot, "suite")
	if bool(suite.get("running", false)) or bool(suite.get("completed", false)) or int(suite.get("index", 0)) > 0:
		summary_lines.append("")
		summary_lines.append("REFERENCE SUITE")
		var suite_attempt_total: int = int(suite.get("total_attempts", suite.get("total", 0)))
		summary_lines.append("%d / %d passed | %d failed" % [
			int(suite.get("passed", 0)),
			suite_attempt_total,
			int(suite.get("failed", 0)),
		])
		var preflight_counts: Dictionary = _dictionary_value(suite, "preflight_counts")
		summary_lines.append("Resolved: %d | Preflight P/W/F: %d/%d/%d | Contact mismatches: %d" % [
			int(suite.get("resolved_count", 0)),
			int(preflight_counts.get("PASS", 0)),
			int(preflight_counts.get("WARN", 0)),
			int(preflight_counts.get("FAIL", 0)),
			int(suite.get("first_contact_mismatches", 0)),
		])
		var per_preset: Dictionary = _dictionary_value(suite, "per_preset")
		if not per_preset.is_empty():
			summary_lines.append("Repeatability:")
			for preset_id_value in per_preset.keys():
				var preset_summary_value: Variant = per_preset[preset_id_value]
				if not preset_summary_value is Dictionary:
					continue
				var preset_summary: Dictionary = preset_summary_value
				summary_lines.append("  %s: %d/%d passed" % [
					str(preset_summary.get("display_name", preset_summary.get("preset_id", "Preset"))),
					int(preset_summary.get("passed", 0)),
					int(preset_summary.get("attempts", 0)),
				])
		var suite_failures: Array = _array_value(suite, "failures")
		for failure_name in suite_failures:
			summary_lines.append("- %s" % str(failure_name))
		var suite_results: Array = _array_value(suite, "results")
		for suite_result_value in suite_results:
			if not suite_result_value is Dictionary:
				continue
			var suite_result: Dictionary = suite_result_value
			if bool(suite_result.get("passed", false)):
				continue
			summary_lines.append("  %s" % str(suite_result.get("display_name", "Preset")))
			for failure_value in _array_value(suite_result, "failures"):
				if not failure_value is Dictionary:
					continue
				var failure: Dictionary = failure_value
				summary_lines.append("    %s: expected %s, observed %s" % [
					str(failure.get("path", "assertion")),
					str(failure.get("expected", "")),
					str(failure.get("actual", "")),
				])
	summary_label.text = "\n".join(summary_lines)

	var resolved: Dictionary = _dictionary_value(snapshot, "resolved_reference")
	var preflight: Dictionary = _dictionary_value(snapshot, "reference_preflight")
	var active_attempt: Dictionary = _dictionary_value(snapshot, "active_reference_attempt")
	var completed_attempt: Dictionary = _dictionary_value(result, "reference_attempt")
	var reference_lines: Array[String] = ["RESOLVED REFERENCE", ""]
	if resolved.is_empty():
		reference_lines.append("No valid reference is currently resolved.")
		reference_lines.append(str(snapshot.get("reference_fire_blocker", "Load a reference-capable preset.")))
	else:
		reference_lines.append(_format_dictionary(resolved))
	reference_lines.append("")
	reference_lines.append("REFERENCE PREFLIGHT")
	reference_lines.append("")
	reference_lines.append(_format_dictionary(preflight) if not preflight.is_empty() else "Not run.")
	reference_lines.append("")
	reference_lines.append("REFERENCE ATTEMPT")
	reference_lines.append("")
	if not completed_attempt.is_empty():
		reference_lines.append(_format_dictionary(completed_attempt))
	elif not active_attempt.is_empty():
		reference_lines.append(_format_dictionary(active_attempt))
	else:
		reference_lines.append("Not fired.")
	reference_label.text = "\n".join(reference_lines)

	var expected: Dictionary = _dictionary_value(result, "expected")
	if expected.is_empty():
		expected = _dictionary_value(loaded, "expected")
	var expected_score: Dictionary = _dictionary_value(loaded, "expected_score")
	expected_label.text = "EXPECTED SEMANTIC ASSERTIONS\n\n%s\n\nEXPECTED SHADOW SCORE\n\n%s" % [
		_format_dictionary(expected),
		_format_dictionary(expected_score),
	]

	var observed: Dictionary = _dictionary_value(result, "observed")
	observed_label.text = (
		"OBSERVED LEDGER SUMMARY\n\nNo completed laboratory shot."
		if observed.is_empty()
		else "OBSERVED LEDGER SUMMARY\n\n%s" % _format_dictionary(observed)
	)

	var scoring_snapshot: Dictionary = _dictionary_value(snapshot, "scoring")
	var last_scoring: Dictionary = _dictionary_value(scoring_snapshot, "last")
	var scoring_system: Dictionary = _dictionary_value(scoring_snapshot, "system")
	var scoring_diagnostics: Dictionary = _dictionary_value(scoring_system, "diagnostics")
	var scoring_lines: Array[String] = ["HAUL x MULT SHADOW SCORING", ""]
	if last_scoring.is_empty():
		scoring_lines.append("No completed laboratory score.")
		var predicted_score: Dictionary = _dictionary_value(scoring_snapshot, "predicted")
		if not predicted_score.is_empty():
			scoring_lines.append("")
			scoring_lines.append("CURRENT PREDICTED BREAKDOWN")
			scoring_lines.append(_format_dictionary(predicted_score))
	else:
		scoring_lines.append("PREDICTED BREAKDOWN")
		scoring_lines.append(_format_dictionary(_dictionary_value(last_scoring, "predicted")))
		scoring_lines.append("")
		scoring_lines.append("AUTHORITATIVE BREAKDOWN")
		scoring_lines.append(_format_dictionary(_dictionary_value(last_scoring, "authoritative")))
		scoring_lines.append("")
		scoring_lines.append("PARITY")
		scoring_lines.append(_format_dictionary(_dictionary_value(last_scoring, "parity")))
		scoring_lines.append("")
		scoring_lines.append("SCORE ASSERTIONS")
		scoring_lines.append(_format_dictionary(_dictionary_value(last_scoring, "assertions")))
	scoring_lines.append("")
	scoring_lines.append("SCORING DIAGNOSTICS")
	scoring_lines.append(_format_dictionary(scoring_diagnostics))
	var self_test: Dictionary = _dictionary_value(scoring_diagnostics, "last_self_test_result")
	scoring_lines.append("")
	scoring_lines.append("SELF-TEST")
	scoring_lines.append(_format_dictionary(self_test) if not self_test.is_empty() else "NOT RUN")
	scoring_lines.append("")
	scoring_lines.append("TALLY PLAYBACK")
	scoring_lines.append_array(_make_tally_playback_lines(tally_snapshot))
	scoring_label.text = "\n".join(scoring_lines)

	var ledger: Dictionary = _dictionary_value(result, "ledger")
	var raw_events: Array = _array_value(ledger, "raw_events")
	raw_events_label.text = (
		"RAW EVENTS\n\nNo completed laboratory shot."
		if raw_events.is_empty()
		else "RAW EVENTS (%d)\n\n%s" % [raw_events.size(), JSON.stringify(_to_json_safe(raw_events), "  ")]
	)


func _make_tally_playback_lines(snapshot: Dictionary) -> Array[String]:
	if snapshot.is_empty():
		return ["No tally result observed."]
	var lines: Array[String] = [
		"State: %s | Active: %s | Replay: %s" % [
			str(snapshot.get("current_state", "idle")),
			bool(snapshot.get("presenter_active", false)),
			bool(snapshot.get("replay_mode_active", false)),
		],
	]
	var live_scoring: Dictionary = _dictionary_value(snapshot, "live_scoring")
	var prediction_release: Dictionary = _dictionary_value(snapshot, "prediction_release")
	var conductor: Dictionary = _dictionary_value(snapshot, "scoring_conductor")
	var narrative_validation: Dictionary = _dictionary_value(snapshot, "narrative_validation")
	lines.append("Narrative: %s | Fallbacks: %d" % [
		str(narrative_validation.get("status", "NOT RUN")),
		int(snapshot.get("narrative_fallback_count", 0)),
	])
	var narrative_input: Dictionary = _dictionary_value(snapshot, "narrative_input")
	lines.append("Input: identity %s | derived %s | events %d | balls %d" % [
		bool(narrative_input.get("identity_present", false)),
		bool(narrative_input.get("derived_present", false)),
		int(narrative_input.get("raw_event_count", 0)),
		int(narrative_input.get("starting_ball_count", 0)),
	])
	var fallback_reason: String = str(snapshot.get("last_narrative_warning", ""))
	if fallback_reason.is_empty():
		fallback_reason = str(snapshot.get("narrative_fallback_reason", ""))
	if not fallback_reason.is_empty():
		lines.append("Fallback reason: %s" % fallback_reason)
	lines.append("")
	lines.append_array(_make_live_anticipation_lines(live_scoring, prediction_release))
	lines.append("Matching: %d live events | Diverged: %d" % [
		int(live_scoring.get("matched_live_events", 0)),
		int(live_scoring.get("diverged_lanes", 0)),
	])
	lines.append("Structural: %d/%d | Silent: %d | Presented: %d/%d | Direct: %d" % [
		int(live_scoring.get("structural_events_matched", 0)),
		int(live_scoring.get("structural_events_expected", 0)),
		int(live_scoring.get("silent_structural_events_matched", 0)),
		int(live_scoring.get("presentation_milestones_matched", 0)),
		int(live_scoring.get("presentation_milestones_expected", 0)),
		int(live_scoring.get("direct_activations_matched", 0)),
	])
	lines.append("Normalized events: %d -> %d | Overlaps suppressed: %d" % [
		int(live_scoring.get("predicted_events_before_normalization", 0)),
		int(live_scoring.get("predicted_events_after_normalization", 0)),
		int(live_scoring.get("suppressed_predicted_overlap_contacts", 0)),
	])
	lines.append("Lookahead skips: %d | Rails exact/tolerant/failed: %d/%d/%d" % [
		int(live_scoring.get("silent_lookahead_skips", 0)),
		int(live_scoring.get("exact_rail_matches", 0)),
		int(live_scoring.get("tolerant_rail_matches", 0)),
		int(live_scoring.get("rail_match_failures", 0)),
	])
	var divergence_reason: String = str(live_scoring.get("lane_divergence_reason", ""))
	if not divergence_reason.is_empty():
		lines.append("Lane divergence: %s" % divergence_reason)
	lines.append("Commit: %s | Wait %.1f ms | Timeouts %d | Available %s" % [
		str(prediction_release.get("last_commit_status", "not_committed")),
		float(prediction_release.get("last_queue_duration_ms", 0.0)),
		int(prediction_release.get("timeout_count", 0)),
		bool(prediction_release.get("live_anticipation_plan_available", false)),
	])
	lines.append("Excitement peak: %.2f | Cues coalesced/dropped: %d/%d" % [
		float(live_scoring.get("global_excitement_peak", snapshot.get("inherited_live_excitement", 0.0))),
		int(conductor.get("cues_coalesced_total", 0)),
		int(conductor.get("cues_dropped_total", 0)),
	])
	if bool(snapshot.get("show_predicted_narratives", false)):
		lines.append("")
		lines.append("PREDICTED NARRATIVE")
		lines.append(_format_dictionary(_dictionary_value(snapshot, "predicted_narrative")))
		lines.append("")
		lines.append("AUTHORITATIVE NARRATIVE")
		lines.append(_format_dictionary(_dictionary_value(snapshot, "authoritative_narrative")))
	if bool(snapshot.get("show_event_matching", false)):
		lines.append("")
		lines.append("EVENT MATCHING")
		lines.append(_format_dictionary(_dictionary_value(snapshot, "event_matching")))
	var score_result: Dictionary = _dictionary_value(snapshot, "score_result")
	if score_result.is_empty():
		lines.append("No completed score result retained.")
		return lines
	var steps: Array = _array_value(score_result, "resolution_steps")
	var current_index: int = int(snapshot.get("current_step_index", -1))
	lines.append("Steps: %d | Final: %d Haul x %s Mult = %d" % [
		steps.size(),
		int(score_result.get("final_haul", 0)),
		_format_tally_number(float(score_result.get("final_mult", 1.0))),
		int(score_result.get("shot_score", 0)),
	])
	if steps.is_empty():
		lines.append("No resolution mutations (zero-score result).")
		return lines
	lines.append("")
	for step_value in steps:
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		var step_index: int = int(step.get("step_index", 0))
		var marker: String = ">" if bool(snapshot.get("presenter_active", false)) and step_index == current_index else " "
		lines.append("%s [%02d] %s | %s | %s" % [
			marker,
			step_index + 1,
			str(step.get("phase", "")),
			str(step.get("source_id", "")),
			str(step.get("display_name", "")),
		])
		lines.append("    Haul %d %+d -> %d | Mult %s %s x%s -> %s | Preview %d" % [
			int(step.get("haul_before", 0)),
			int(step.get("haul_delta", 0)),
			int(step.get("haul_after", 0)),
			_format_tally_number(float(step.get("mult_before", 1.0))),
			_format_tally_signed_number(float(step.get("mult_delta", 0.0))),
			_format_tally_number(float(step.get("xmult_factor", 1.0))),
			_format_tally_number(float(step.get("mult_after", 1.0))),
			int(step.get("score_preview_after", 0)),
		])
	return lines


func _make_live_anticipation_lines(
	live_scoring: Dictionary,
	prediction_release: Dictionary
) -> Array[String]:
	var lines: Array[String] = ["LIVE ANTICIPATION"]
	lines.append("Plan: %s" % str(live_scoring.get("plan_status", "DISABLED")))
	lines.append("Prediction result mode: %s" % str(live_scoring.get(
		"prediction_result_mode",
		"unknown"
	)))
	lines.append("Prediction: release %s | wait %s | timeout %s | capped %s | unsupported %s" % [
		bool(prediction_release.get("exact_prediction_ready_at_release", false)),
		bool(prediction_release.get("accepted_after_wait", false)),
		bool(prediction_release.get("timed_out", false)),
		bool(live_scoring.get("prediction_capped", false)),
		bool(live_scoring.get("prediction_unsupported", false)),
	])
	lines.append("Lanes: total %d | complete %d | incomplete %d | active %d | diverged %d" % [
		int(live_scoring.get("total_predicted_scoring_lanes", 0)),
		int(live_scoring.get("complete_lanes", 0)),
		int(live_scoring.get("incomplete_lanes", 0)),
		int(live_scoring.get("active_lanes", 0)),
		int(live_scoring.get("diverged_lanes", 0)),
	])
	lines.append("Rail semantic evidence: %s | exact %d | geometric %d | received %d" % [
		str(live_scoring.get("rail_semantic_evidence_status", "NOT_APPLICABLE")),
		int(live_scoring.get("rail_events_eligible_for_exact_matching", 0)),
		int(live_scoring.get("rail_events_eligible_for_geometric_matching", 0)),
		int(live_scoring.get("predicted_rail_events_received", 0)),
	])
	lines.append("Rail missing name/normal/center/surface/radius: %d/%d/%d/%d/%d" % [
		int(live_scoring.get("rail_events_missing_name", 0)),
		int(live_scoring.get("rail_events_missing_normal", 0)),
		int(live_scoring.get("rail_events_missing_center", 0)),
		int(live_scoring.get("rail_events_missing_surface", 0)),
		int(live_scoring.get("rail_events_missing_radius", 0)),
	])
	var globally_missing_rail_fields: Array = _array_value(
		live_scoring,
		"rail_semantic_evidence_missing_fields"
	)
	if not globally_missing_rail_fields.is_empty():
		lines.append("Predicted rail semantic evidence incomplete: %s" % (
			_join_string_values(globally_missing_rail_fields)
		))
	var lane_lookup: Dictionary = _dictionary_value(live_scoring, "lanes")
	var lane_ids: Array[int] = []
	for lane_key in lane_lookup.keys():
		var lane_id: int = int(lane_key)
		if lane_id > 0:
			lane_ids.append(lane_id)
	lane_ids.sort()
	for lane_id in lane_ids:
		var lane: Dictionary = _dictionary_value(lane_lookup, str(lane_id))
		var ball_number: int = int(lane.get("ball_number", -1))
		var label: String = "Ball %d" % lane_id
		if ball_number >= 0:
			label = "Ball #%d" % ball_number
		lines.append("%s: %s | cap %s | unsupported %s" % [
			label,
			str(lane.get("lane_plan_status", "incomplete")).to_upper(),
			bool(lane.get("affected_by_prediction_cap", false)),
			bool(lane.get("affected_by_unsupported_event", false)),
		])
		var milestone_parts: Array[String] = [
			"activation %s" % _yes_no(bool(lane.get("activation_matched", false))),
		]
		for milestone_value in _array_value(lane, "bank_milestones"):
			if not milestone_value is Dictionary:
				continue
			var milestone: Dictionary = milestone_value
			milestone_parts.append("bank %d %s" % [
				int(milestone.get("tier", milestone_parts.size())),
				_yes_no(bool(milestone.get("matched", false))),
			])
		milestone_parts.append("pocket %s" % _yes_no(bool(lane.get("pocket_matched", false))))
		lines.append("  " + " | ".join(milestone_parts))
		var disable_reason: String = str(lane.get("lane_disable_reason", ""))
		var divergence_reason: String = str(lane.get("divergence_reason", ""))
		if not disable_reason.is_empty():
			lines.append("  Disabled: %s" % disable_reason)
		if not divergence_reason.is_empty():
			lines.append("  Diverged: %s" % divergence_reason)
		var missing_rail_fields: Array = _array_value(
			lane,
			"missing_predicted_rail_semantic_evidence"
		)
		if not missing_rail_fields.is_empty():
			lines.append("  Predicted rail semantic evidence incomplete: %s" % (
				_join_string_values(missing_rail_fields)
			))
		if bool(lane.get("has_next_expected_rail", false)):
			var next_rail_name: String = str(lane.get("next_expected_rail_name", ""))
			if next_rail_name.is_empty():
				next_rail_name = "<missing>"
			lines.append("  Next rail: %s | index %d | side %s | normal %s" % [
				next_rail_name,
				int(lane.get("next_expected_rail_index", -1)),
				str(lane.get("next_expected_rail_side", "unknown")),
				_format_vector2_diagnostic(lane.get(
					"next_expected_rail_normal",
					Vector2.ZERO
				)),
			])
			lines.append("  Next center/surface: %s / %s | evidence %s" % [
				_format_vector2_diagnostic(lane.get(
					"next_expected_rail_center",
					Vector2.INF
				)),
				_format_vector2_diagnostic(lane.get(
					"next_expected_rail_surface",
					Vector2.INF
				)),
				(
					"COMPLETE"
					if bool(lane.get(
						"next_expected_rail_semantic_evidence_complete",
						false
					))
					else "INCOMPLETE"
				),
			])
		var rail_match: Dictionary = _dictionary_value(lane, "last_rail_match")
		if not rail_match.is_empty():
			lines.append("  Rail %s/%s/%s -> %s/%s/%s" % [
				str(rail_match.get("expected_rail_id", "?")),
				str(rail_match.get("expected_rail_kind", "?")),
				str(rail_match.get("expected_rail_side", "?")),
				str(rail_match.get("actual_rail_id", "?")),
				str(rail_match.get("actual_rail_kind", "?")),
				str(rail_match.get("actual_rail_side", "?")),
			])
			lines.append("  Delta center/surface/normal: %s / %s px / %s deg | %s | %s" % [
				_format_diagnostic_delta(float(rail_match.get("center_delta_px", INF))),
				_format_diagnostic_delta(float(rail_match.get("surface_delta_px", INF))),
				_format_diagnostic_delta(float(rail_match.get("normal_angle_delta_degrees", INF))),
				str(rail_match.get("quality", "failed")),
				str(rail_match.get("decision", "diverge")),
			])
	return lines


func _yes_no(value: bool) -> String:
	return "YES" if value else "no"


func _format_diagnostic_delta(value: float) -> String:
	return "-" if not is_finite(value) else "%.1f" % value


func _format_vector2_diagnostic(value: Variant) -> String:
	if not value is Vector2:
		return "-"
	var vector: Vector2 = value
	if not is_finite(vector.x) or not is_finite(vector.y):
		return "-"
	return "(%.1f, %.1f)" % [vector.x, vector.y]


func _join_string_values(values: Array) -> String:
	var text_values: Array[String] = []
	for value in values:
		text_values.append(str(value))
	return ", ".join(text_values)


func _format_tally_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


func _format_tally_signed_number(value: float) -> String:
	return ("+" if value >= 0.0 else "") + _format_tally_number(value)


func _center_in_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var desired_position: Vector2 = (viewport_size - PANEL_SIZE) * 0.5
	desired_position.x = clampf(desired_position.x, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.x - PANEL_SIZE.x - VIEWPORT_MARGIN))
	desired_position.y = clampf(desired_position.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - PANEL_SIZE.y - VIEWPORT_MARGIN))
	position = desired_position


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.024, 0.028, 0.97)
	style.border_color = Color(0.63, 0.49, 0.20, 0.95)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 14)
	return button


func _format_dictionary(value: Dictionary) -> String:
	if value.is_empty():
		return "none"
	return JSON.stringify(_to_json_safe(value), "  ")


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []


func _to_json_safe(value: Variant) -> Variant:
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Dictionary:
		var converted: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			converted[str(key_value)] = _to_json_safe((value as Dictionary)[key_value])
		return converted
	if value is Array:
		var converted_array: Array = []
		for item in value as Array:
			converted_array.append(_to_json_safe(item))
		return converted_array
	return value
