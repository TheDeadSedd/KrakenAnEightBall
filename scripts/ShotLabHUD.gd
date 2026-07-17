extends Control
class_name ShotLabHUD

signal inspect_result_requested
signal inspect_score_requested
signal raw_events_requested
signal exit_lab_requested

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const DOCK_SIZE := Vector2(356.0, 824.0)
const COLLAPSED_SIZE := Vector2(218.0, 126.0)
const BANNER_SIZE := Vector2(720.0, 54.0)
const VIEWPORT_MARGIN := 24.0
const PASS_COLOR := Color("7dd9a2")
const FAIL_COLOR := Color("ef8a79")
const GOLD_COLOR := Color("e6c66f")
const TEXT_COLOR := Color("d7d0bb")
const MUTED_COLOR := Color("9f9a8d")

static var session_collapsed := false

var shot_lab_system: ShotLabSystem
var latest_snapshot: Dictionary = {}
var hover_ui_suppressed := false
var advanced_visible := false
var interactive_controls: Array[Control] = []

var banner_panel: PanelContainer
var banner_label: Label
var dock_panel: PanelContainer
var collapsed_panel: PanelContainer
var preset_selector: OptionButton
var loaded_status_label: Label
var reference_status_label: Label
var load_button: Button
var fire_button: Button
var reset_button: Button
var rerun_button: Button
var rewind_button: Button
var exit_button: Button
var reference_aim_check: CheckBox
var freeze_consequences_check: CheckBox
var ordinary_balls_check: CheckBox
var auto_fire_check: CheckBox
var auto_reset_check: CheckBox
var advanced_button: Button
var advanced_stack: VBoxContainer
var freeze_warning_label: Label
var result_status_label: Label
var result_detail_label: Label
var scoring_summary_label: Label
var scoring_modifier_selector: OptionButton
var inspect_score_button: Button
var copy_score_summary_button: Button
var copy_score_json_button: Button
var scoring_self_test_button: Button
var inspect_button: Button
var raw_events_button: Button
var copy_result_button: Button
var copy_arrangement_button: Button
var capture_aim_button: Button
var regenerate_preflight_button: Button
var copy_resolved_button: Button
var copy_reference_snippet_button: Button
var aim_nudge_buttons: Array[Button] = []
var power_nudge_buttons: Array[Button] = []
var suite_progress_label: Label
var run_suite_button: Button
var repeat_suite_button: Button
var cancel_suite_button: Button
var collapsed_preset_label: Label
var collapsed_result_label: Label
var exit_confirmation: ConfirmationDialog


func setup(system_ref: ShotLabSystem) -> void:
	shot_lab_system = system_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 52
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not shot_lab_system.state_changed.is_connected(_on_state_changed):
		shot_lab_system.state_changed.connect(_on_state_changed)
	visible = true
	_refresh(shot_lab_system.get_snapshot())
	_layout_hud()


func set_hover_ui_suppressed(suppressed: bool) -> void:
	if hover_ui_suppressed == suppressed:
		return
	hover_ui_suppressed = suppressed
	for control in interactive_controls:
		if is_instance_valid(control):
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE if suppressed else Control.MOUSE_FILTER_STOP
	if dock_panel != null:
		dock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if suppressed else Control.MOUSE_FILTER_STOP
	if collapsed_panel != null:
		collapsed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if suppressed else Control.MOUSE_FILTER_STOP


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_hud()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	interactive_controls.clear()

	banner_panel = PanelContainer.new()
	banner_panel.name = "LaboratoryBanner"
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.014, 0.022, 0.025, 0.91), Color(0.54, 0.78, 0.71, 0.78)))
	add_child(banner_panel)
	var banner_margin := MarginContainer.new()
	banner_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_margin.add_theme_constant_override("margin_left", 16)
	banner_margin.add_theme_constant_override("margin_top", 7)
	banner_margin.add_theme_constant_override("margin_right", 16)
	banner_margin.add_theme_constant_override("margin_bottom", 7)
	banner_panel.add_child(banner_margin)
	banner_label = _make_label("SHOT LAB", 16, GOLD_COLOR)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_margin.add_child(banner_label)

	dock_panel = PanelContainer.new()
	dock_panel.name = "ControlDock"
	dock_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dock_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.014, 0.019, 0.022, 0.96), Color(0.66, 0.50, 0.20, 0.94)))
	add_child(dock_panel)
	var dock_scroll := ScrollContainer.new()
	dock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dock_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	dock_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock_panel.add_child(dock_scroll)
	var dock_margin := MarginContainer.new()
	dock_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock_margin.add_theme_constant_override("margin_left", 14)
	dock_margin.add_theme_constant_override("margin_top", 12)
	dock_margin.add_theme_constant_override("margin_right", 14)
	dock_margin.add_theme_constant_override("margin_bottom", 12)
	dock_scroll.add_child(dock_margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	dock_margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	var title := _make_label("SHOT LAB", 22, GOLD_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var collapse_button := _make_button("<", 34.0)
	collapse_button.tooltip_text = "Collapse Shot Lab controls"
	collapse_button.pressed.connect(_set_collapsed.bind(true))
	header.add_child(collapse_button)

	stack.add_child(_make_section_heading("Preset"))
	preset_selector = OptionButton.new()
	preset_selector.custom_minimum_size = Vector2(0.0, 34.0)
	preset_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_selector.add_theme_font_override("font", UI_FONT)
	preset_selector.add_theme_font_size_override("font_size", 15)
	preset_selector.item_selected.connect(_on_preset_selected)
	_register_interactive(preset_selector)
	stack.add_child(preset_selector)
	loaded_status_label = _make_label("Not loaded", 13, MUTED_COLOR)
	loaded_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(loaded_status_label)
	reference_status_label = _make_label("REFERENCE NOT RESOLVED", 12, MUTED_COLOR)
	reference_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(reference_status_label)

	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 6)
	action_grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(action_grid)
	load_button = _add_action_button(action_grid, "Load Setup", _on_load_pressed)
	fire_button = _add_action_button(action_grid, "Fire Reference", _on_fire_pressed)
	reset_button = _add_action_button(action_grid, "Reset Setup", _on_reset_pressed)
	rerun_button = _add_action_button(action_grid, "Re-run", _on_rerun_pressed)
	rewind_button = _add_action_button(action_grid, "Rewind Shot", _on_rewind_pressed)
	exit_button = _add_action_button(action_grid, "Exit Lab", _on_exit_pressed)

	reference_aim_check = _make_check_box("Reference Aim", "show_reference_aim")
	freeze_consequences_check = _make_check_box("Freeze Consequences", "freeze_unrelated_run_consequences")
	ordinary_balls_check = _make_check_box("Ordinary Balls Only", "ordinary_balls_only")
	stack.add_child(reference_aim_check)
	stack.add_child(freeze_consequences_check)
	stack.add_child(ordinary_balls_check)
	freeze_warning_label = _make_label("WARNING: Run consequences are live.", 12, FAIL_COLOR)
	freeze_warning_label.visible = false
	stack.add_child(freeze_warning_label)

	advanced_button = _make_button("Advanced >", 30.0)
	advanced_button.pressed.connect(_toggle_advanced)
	stack.add_child(advanced_button)
	advanced_stack = VBoxContainer.new()
	advanced_stack.add_theme_constant_override("separation", 2)
	advanced_stack.visible = advanced_visible
	stack.add_child(advanced_stack)
	auto_fire_check = _make_check_box("Auto-Fire After Load", "auto_fire_after_load")
	auto_reset_check = _make_check_box("Auto-Reset After Failure", "auto_reset_after_failure")
	advanced_stack.add_child(auto_fire_check)
	advanced_stack.add_child(auto_reset_check)
	advanced_stack.add_child(_make_section_heading("Reference Authoring"))
	var authoring_grid := GridContainer.new()
	authoring_grid.columns = 2
	authoring_grid.add_theme_constant_override("h_separation", 5)
	authoring_grid.add_theme_constant_override("v_separation", 5)
	advanced_stack.add_child(authoring_grid)
	capture_aim_button = _add_action_button(authoring_grid, "Capture Aim", _on_capture_aim_pressed)
	regenerate_preflight_button = _add_action_button(authoring_grid, "Preflight", _on_regenerate_preflight_pressed)
	copy_resolved_button = _add_action_button(authoring_grid, "Copy Resolved", _on_copy_resolved_pressed)
	copy_reference_snippet_button = _add_action_button(authoring_grid, "Copy Snippet", _on_copy_reference_snippet_pressed)
	var aim_nudge_row := HBoxContainer.new()
	aim_nudge_row.add_theme_constant_override("separation", 4)
	advanced_stack.add_child(aim_nudge_row)
	for nudge_spec_value in [
		{"label": "Aim L", "offset": Vector2(-2.0, 0.0)},
		{"label": "R", "offset": Vector2(2.0, 0.0)},
		{"label": "U", "offset": Vector2(0.0, -2.0)},
		{"label": "D", "offset": Vector2(0.0, 2.0)},
	]:
		var nudge_spec: Dictionary = nudge_spec_value as Dictionary
		var nudge_button: Button = _add_action_button(
			aim_nudge_row,
			str(nudge_spec["label"]),
			_on_nudge_aim_pressed.bind(nudge_spec["offset"])
		)
		aim_nudge_buttons.append(nudge_button)
	var power_nudge_row := HBoxContainer.new()
	power_nudge_row.add_theme_constant_override("separation", 4)
	advanced_stack.add_child(power_nudge_row)
	for power_spec_value in [
		{"label": "Power -1%", "delta": -0.01},
		{"label": "Power +1%", "delta": 0.01},
	]:
		var power_spec: Dictionary = power_spec_value as Dictionary
		var power_button: Button = _add_action_button(
			power_nudge_row,
			str(power_spec["label"]),
			_on_nudge_power_pressed.bind(float(power_spec["delta"]))
		)
		power_nudge_buttons.append(power_button)

	stack.add_child(_make_section_heading("Last Result"))
	var result_panel := PanelContainer.new()
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.032, 0.034, 0.92), Color(0.34, 0.36, 0.30, 0.72)))
	stack.add_child(result_panel)
	var result_margin := MarginContainer.new()
	result_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_margin.add_theme_constant_override("margin_left", 10)
	result_margin.add_theme_constant_override("margin_top", 7)
	result_margin.add_theme_constant_override("margin_right", 10)
	result_margin.add_theme_constant_override("margin_bottom", 7)
	result_panel.add_child(result_margin)
	var result_stack := VBoxContainer.new()
	result_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_margin.add_child(result_stack)
	result_status_label = _make_label("NOT RUN", 20, MUTED_COLOR)
	result_stack.add_child(result_status_label)
	result_detail_label = _make_label("No completed laboratory shot.", 13, TEXT_COLOR)
	result_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_stack.add_child(result_detail_label)

	stack.add_child(_make_section_heading("New Scoring"))
	scoring_summary_label = _make_label("Haul: 0\nMult: 1\nScore: 0", 14, TEXT_COLOR)
	scoring_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(scoring_summary_label)
	scoring_modifier_selector = OptionButton.new()
	scoring_modifier_selector.custom_minimum_size = Vector2(0.0, 32.0)
	scoring_modifier_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoring_modifier_selector.add_theme_font_override("font", UI_FONT)
	scoring_modifier_selector.add_theme_font_size_override("font_size", 14)
	scoring_modifier_selector.item_selected.connect(_on_scoring_modifier_selected)
	_register_interactive(scoring_modifier_selector)
	stack.add_child(scoring_modifier_selector)
	var scoring_actions := GridContainer.new()
	scoring_actions.columns = 2
	scoring_actions.add_theme_constant_override("h_separation", 6)
	scoring_actions.add_theme_constant_override("v_separation", 6)
	stack.add_child(scoring_actions)
	inspect_score_button = _add_action_button(scoring_actions, "Inspect Score", _on_inspect_score_pressed)
	copy_score_summary_button = _add_action_button(scoring_actions, "Copy Summary", _on_copy_score_summary_pressed)
	copy_score_json_button = _add_action_button(scoring_actions, "Copy Score JSON", _on_copy_score_json_pressed)
	scoring_self_test_button = _add_action_button(scoring_actions, "Scoring Self-Test", _on_scoring_self_test_pressed)

	var inspect_grid := GridContainer.new()
	inspect_grid.columns = 2
	inspect_grid.add_theme_constant_override("h_separation", 6)
	inspect_grid.add_theme_constant_override("v_separation", 6)
	stack.add_child(inspect_grid)
	inspect_button = _add_action_button(inspect_grid, "Inspect Result", _on_inspect_pressed)
	raw_events_button = _add_action_button(inspect_grid, "Raw Events", _on_raw_events_pressed)
	copy_result_button = _add_action_button(inspect_grid, "Copy Result", _on_copy_result_pressed)
	copy_arrangement_button = _add_action_button(inspect_grid, "Copy Arrangement", _on_copy_arrangement_pressed)

	stack.add_child(_make_section_heading("Reference Suite"))
	suite_progress_label = _make_label("Ready", 13, TEXT_COLOR)
	suite_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(suite_progress_label)
	var suite_row := HBoxContainer.new()
	suite_row.add_theme_constant_override("separation", 6)
	stack.add_child(suite_row)
	run_suite_button = _add_action_button(suite_row, "Run Suite", _on_run_suite_pressed)
	repeat_suite_button = _add_action_button(suite_row, "Run 5x", _on_run_repeatability_suite_pressed)
	cancel_suite_button = _add_action_button(suite_row, "Cancel Suite", _on_cancel_suite_pressed)

	_build_collapsed_panel()
	_build_exit_confirmation()
	_normalize_dock_mouse_filters()
	_set_collapsed(session_collapsed)


func _build_collapsed_panel() -> void:
	collapsed_panel = PanelContainer.new()
	collapsed_panel.name = "CollapsedDock"
	collapsed_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	collapsed_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.014, 0.019, 0.022, 0.96), Color(0.66, 0.50, 0.20, 0.94)))
	add_child(collapsed_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 9)
	collapsed_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_stack)
	text_stack.add_child(_make_label("SHOT LAB", 17, GOLD_COLOR))
	collapsed_preset_label = _make_label("Direct Pot", 13, TEXT_COLOR)
	collapsed_preset_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_stack.add_child(collapsed_preset_label)
	collapsed_result_label = _make_label("NOT RUN", 14, MUTED_COLOR)
	text_stack.add_child(collapsed_result_label)
	var expand_button := _make_button(">", 34.0)
	expand_button.tooltip_text = "Expand Shot Lab controls"
	expand_button.pressed.connect(_set_collapsed.bind(false))
	row.add_child(expand_button)


func _build_exit_confirmation() -> void:
	exit_confirmation = ConfirmationDialog.new()
	exit_confirmation.title = "Exit Shot Lab"
	exit_confirmation.dialog_text = "Leave the laboratory and return to the Main Menu?"
	exit_confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	exit_confirmation.confirmed.connect(_emit_exit_requested)
	add_child(exit_confirmation)
	exit_confirmation.get_ok_button().text = "Exit Lab"
	exit_confirmation.get_cancel_button().text = "Stay"


func _refresh(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot.duplicate(true)
	_refresh_preset_selector(snapshot)
	var loaded: Dictionary = _dictionary_value(snapshot, "loaded_preset")
	var loaded_name: String = str(loaded.get("display_name", "No setup loaded"))
	var selected_loaded: bool = bool(snapshot.get("selected_preset_loaded", false))
	var reference_available: bool = bool(snapshot.get("reference_available", false))
	var options: Dictionary = _dictionary_value(snapshot, "options")
	var frozen: bool = bool(options.get("freeze_unrelated_run_consequences", true))
	var suite: Dictionary = _dictionary_value(snapshot, "suite")
	var banner_bits: Array[String] = []
	banner_bits.append("Reference available" if reference_available else "No reference shot")
	banner_bits.append("Consequences frozen" if frozen else "CONSEQUENCES LIVE")
	if bool(suite.get("running", false)):
		banner_bits.append("Suite %d/%d" % [
			mini(int(suite.get("index", 0)) + 1, int(suite.get("total", 0))),
			int(suite.get("total", 0)),
		])
	banner_label.text = "SHOT LAB - %s\n%s" % [loaded_name.to_upper(), " | ".join(banner_bits)]
	loaded_status_label.text = (
		"Loaded: %s" % loaded_name
		if selected_loaded
		else "Selected preset is not loaded. Press Load Setup."
	)
	_refresh_reference_status(snapshot)
	collapsed_preset_label.text = loaded_name
	_set_check_without_signal(reference_aim_check, bool(options.get("show_reference_aim", true)))
	_set_check_without_signal(freeze_consequences_check, frozen)
	_set_check_without_signal(ordinary_balls_check, bool(options.get("ordinary_balls_only", true)))
	_set_check_without_signal(auto_fire_check, bool(options.get("auto_fire_after_load", false)))
	_set_check_without_signal(auto_reset_check, bool(options.get("auto_reset_after_failure", false)))
	freeze_warning_label.visible = not frozen
	_refresh_result(_dictionary_value(snapshot, "last_result"))
	_refresh_scoring(_dictionary_value(snapshot, "scoring"))
	_refresh_suite(suite)
	_refresh_control_availability(snapshot)


func _refresh_reference_status(snapshot: Dictionary) -> void:
	var resolved: Dictionary = _dictionary_value(snapshot, "resolved_reference")
	var preflight: Dictionary = _dictionary_value(snapshot, "reference_preflight")
	if not bool(resolved.get("resolution_valid", false)):
		reference_status_label.text = "REFERENCE INVALID\n%s" % str(
			resolved.get("failure_reason", snapshot.get("reference_fire_blocker", "Not resolved."))
		)
		reference_status_label.add_theme_color_override("font_color", FAIL_COLOR)
		return
	var status: String = str(preflight.get("status", "NOT RUN"))
	var status_color: Color = PASS_COLOR
	if status == "WARN":
		status_color = GOLD_COLOR
	elif status in ["FAIL", "NOT RUN"]:
		status_color = FAIL_COLOR
	var expected_first: String = str(preflight.get("expected_first_contact_role", "none"))
	var predicted_first: String = str(preflight.get("predicted_first_contact_role", "none"))
	reference_status_label.text = "REFERENCE %s | %d%% | %.1f speed\nFirst: %s (expected %s)%s" % [
		status,
		roundi(float(resolved.get("power_normalized", 0.0)) * 100.0),
		float(resolved.get("launch_speed", 0.0)),
		predicted_first,
		expected_first,
		"\n%s" % str(snapshot.get("reference_fire_blocker", ""))
		if not bool(snapshot.get("reference_can_fire", false))
		else "",
	]
	reference_status_label.add_theme_color_override("font_color", status_color)


func _refresh_preset_selector(snapshot: Dictionary) -> void:
	var choices: Array = _array_value(snapshot, "presets")
	var selected_id: String = str(snapshot.get("selected_preset_id", ""))
	preset_selector.clear()
	var selected_index := 0
	for choice_value in choices:
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		var item_index: int = preset_selector.item_count
		preset_selector.add_item(str(choice.get("label", "Preset")))
		preset_selector.set_item_metadata(item_index, str(choice.get("value", "")))
		if str(choice.get("value", "")) == selected_id:
			selected_index = item_index
	if preset_selector.item_count > 0:
		preset_selector.select(selected_index)


func _refresh_result(result: Dictionary) -> void:
	if result.is_empty() or str(result.get("status", "")) == "NOT RUN":
		result_status_label.text = "NOT RUN"
		result_status_label.add_theme_color_override("font_color", MUTED_COLOR)
		result_detail_label.text = "No completed laboratory shot."
		collapsed_result_label.text = "NOT RUN"
		collapsed_result_label.add_theme_color_override("font_color", MUTED_COLOR)
		return
	var passed: bool = bool(result.get("passed", false))
	var verdict: String = "PASS" if passed else "FAIL"
	var color: Color = PASS_COLOR if passed else FAIL_COLOR
	result_status_label.text = verdict
	result_status_label.add_theme_color_override("font_color", color)
	collapsed_result_label.text = verdict
	collapsed_result_label.add_theme_color_override("font_color", color)
	var total: int = maxi(int(result.get("assertions_total", 0)), 0)
	var passed_count: int = maxi(int(result.get("assertions_passed", 0)), 0)
	var detail_lines: Array[String] = [
		"%d/%d assertions | Shot %d | Attempt %d" % [
			passed_count,
			total,
			int(result.get("shot_id", -1)),
			int(result.get("attempt_id", -1)),
		],
	]
	var failures: Array = _array_value(result, "failures")
	if not failures.is_empty() and failures[0] is Dictionary:
		var failure: Dictionary = failures[0]
		detail_lines.append("Expected %s = %s; observed %s" % [
			str(failure.get("path", "assertion")),
			str(failure.get("expected", "")),
			str(failure.get("actual", "")),
		])
		if failures.size() > 1:
			detail_lines.append("%d additional failures. Inspect for details." % (failures.size() - 1))
	result_detail_label.text = "\n".join(detail_lines)


func _refresh_scoring(scoring_snapshot: Dictionary) -> void:
	var last: Dictionary = _dictionary_value(scoring_snapshot, "last")
	var actual: Dictionary = _dictionary_value(last, "authoritative")
	var predicted: Dictionary = _dictionary_value(last, "predicted")
	if predicted.is_empty():
		predicted = _dictionary_value(scoring_snapshot, "predicted")
	var parity: Dictionary = _dictionary_value(last, "parity")
	var lines: Array[String] = []
	if actual.is_empty():
		lines.append("Haul: --  Mult: --  Score: --")
	else:
		lines.append("Haul: %d  Mult: %s  Score: %d" % [
			int(actual.get("final_haul", 0)),
			_format_mult(float(actual.get("final_mult", 1.0))),
			int(actual.get("shot_score", 0)),
		])
	if not predicted.is_empty():
		lines.append("Predicted: %d | Actual: %s" % [
			int(predicted.get("shot_score", 0)),
			"--" if actual.is_empty() else str(int(actual.get("shot_score", 0))),
		])
	lines.append("Parity: %s | SHADOW ONLY" % str(parity.get("status", "NOT RUN")))
	scoring_summary_label.text = "\n".join(lines)
	var parity_status: String = str(parity.get("status", "NOT RUN"))
	var summary_color: Color = TEXT_COLOR
	if parity_status == "PASS":
		summary_color = PASS_COLOR
	elif parity_status == "FAIL":
		summary_color = FAIL_COLOR
	elif parity_status == "WARN":
		summary_color = GOLD_COLOR
	scoring_summary_label.add_theme_color_override("font_color", summary_color)

	var choices: Array = _array_value(scoring_snapshot, "modifier_choices")
	var selected_mode: String = str(scoring_snapshot.get("modifier_mode", "none"))
	scoring_modifier_selector.clear()
	var selected_index := 0
	for choice_value in choices:
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		var index: int = scoring_modifier_selector.item_count
		scoring_modifier_selector.add_item(str(choice.get("label", "Modifier")))
		scoring_modifier_selector.set_item_metadata(index, str(choice.get("value", "none")))
		if str(choice.get("value", "none")) == selected_mode:
			selected_index = index
	if scoring_modifier_selector.item_count > 0:
		scoring_modifier_selector.select(selected_index)


func _refresh_suite(suite: Dictionary) -> void:
	var running: bool = bool(suite.get("running", false))
	var completed: bool = bool(suite.get("completed", false))
	var total: int = maxi(int(suite.get("total", 0)), 0)
	var total_attempts: int = maxi(int(suite.get("total_attempts", total)), 0)
	var completed_attempts: int = maxi(int(suite.get("completed_attempts", 0)), 0)
	var repeat_target: int = maxi(int(suite.get("repeat_target", 1)), 1)
	var repeat_index: int = maxi(int(suite.get("repeat_index", 0)), 0)
	var index: int = maxi(int(suite.get("index", 0)), 0)
	var passed: int = maxi(int(suite.get("passed", 0)), 0)
	var failed: int = maxi(int(suite.get("failed", 0)), 0)
	if running:
		suite_progress_label.text = "Preset %d / %d - %s | Attempt %d/%d\nCompleted: %d/%d | Passed: %d | Failed: %d" % [
			mini(index + 1, total),
			total,
			str(suite.get("current_preset_name", "Preset")),
			repeat_index + 1,
			repeat_target,
			completed_attempts,
			total_attempts,
			passed,
			failed,
		]
	elif completed:
		var preflight_counts: Dictionary = _dictionary_value(suite, "preflight_counts")
		suite_progress_label.text = "REFERENCE SUITE COMPLETE\n%d / %d attempts passed%s\nPreflight P/W/F: %d/%d/%d | Contact mismatches: %d" % [
			passed,
			total_attempts,
			"" if failed == 0 else " | %d failed" % failed,
			int(preflight_counts.get("PASS", 0)),
			int(preflight_counts.get("WARN", 0)),
			int(preflight_counts.get("FAIL", 0)),
			int(suite.get("first_contact_mismatches", 0)),
		]
	else:
		suite_progress_label.text = "Ready - %d reference presets | 5x validates %d attempts" % [total, total * 5]


func _refresh_control_availability(snapshot: Dictionary) -> void:
	var active: bool = bool(snapshot.get("active", false))
	var shot_active: bool = bool(snapshot.get("shot_active", false))
	var balls_idle: bool = bool(snapshot.get("balls_idle", false))
	var selected_loaded: bool = bool(snapshot.get("selected_preset_loaded", false))
	var suite: Dictionary = _dictionary_value(snapshot, "suite")
	var suite_running: bool = bool(suite.get("running", false))
	var suite_completed: bool = bool(suite.get("completed", false))
	var suite_failed: int = maxi(int(suite.get("failed", 0)), 0)
	var last_result: Dictionary = _dictionary_value(snapshot, "last_result")
	var has_completed_result: bool = (
		not last_result.is_empty()
		and str(last_result.get("status", "")) != "NOT RUN"
	)
	var manual_locked: bool = shot_active or suite_running
	preset_selector.disabled = manual_locked
	load_button.disabled = manual_locked
	fire_button.disabled = manual_locked or not active or not selected_loaded or not balls_idle or not bool(snapshot.get("reference_can_fire", false))
	reset_button.disabled = manual_locked or not active or not selected_loaded
	rerun_button.disabled = manual_locked or not active or not selected_loaded or not bool(snapshot.get("last_reference_fired", false))
	var rewind: Dictionary = _dictionary_value(snapshot, "rewind")
	rewind_button.disabled = manual_locked or not selected_loaded or not bool(rewind.get("available", false))
	reference_aim_check.disabled = manual_locked
	freeze_consequences_check.disabled = shot_active
	ordinary_balls_check.disabled = manual_locked
	auto_fire_check.disabled = manual_locked
	auto_reset_check.disabled = manual_locked
	inspect_button.disabled = not has_completed_result and not suite_completed
	raw_events_button.disabled = not has_completed_result
	copy_result_button.disabled = not has_completed_result and not suite_completed
	copy_arrangement_button.disabled = not active
	var scoring: Dictionary = _dictionary_value(snapshot, "scoring")
	var last_scoring: Dictionary = _dictionary_value(scoring, "last")
	var has_score: bool = not _dictionary_value(last_scoring, "authoritative").is_empty()
	scoring_modifier_selector.disabled = manual_locked
	inspect_score_button.disabled = not has_score
	copy_score_summary_button.disabled = not has_score
	copy_score_json_button.disabled = not has_score
	scoring_self_test_button.disabled = shot_active
	run_suite_button.disabled = manual_locked
	repeat_suite_button.disabled = manual_locked
	cancel_suite_button.disabled = not suite_running
	var authoring_locked: bool = manual_locked or not active or not selected_loaded
	capture_aim_button.disabled = authoring_locked
	regenerate_preflight_button.disabled = authoring_locked
	copy_resolved_button.disabled = not bool(snapshot.get("reference_available", false))
	copy_reference_snippet_button.disabled = authoring_locked
	for button in aim_nudge_buttons:
		button.disabled = authoring_locked
	for button in power_nudge_buttons:
		button.disabled = authoring_locked
	inspect_button.text = (
		"Inspect Failures"
		if suite_completed and suite_failed > 0
		else ("Inspect Suite" if suite_completed else "Inspect Result")
	)
	copy_result_button.text = "Copy Suite" if suite_completed else "Copy Result"
	run_suite_button.text = "Run Suite Again" if suite_completed else "Run Suite"
	repeat_suite_button.text = "Run 5x Again" if suite_completed else "Run 5x"


func _layout_hud() -> void:
	if banner_panel == null or dock_panel == null or collapsed_panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var active_dock_width: float = COLLAPSED_SIZE.x if session_collapsed else DOCK_SIZE.x
	var banner_area_width: float = maxf(viewport_size.x - active_dock_width - VIEWPORT_MARGIN * 2.0, 320.0)
	var banner_size := Vector2(minf(BANNER_SIZE.x, banner_area_width), BANNER_SIZE.y)
	banner_panel.size = banner_size
	banner_panel.position = Vector2(
		VIEWPORT_MARGIN + maxf((banner_area_width - banner_size.x) * 0.5, 0.0),
		18.0
	)
	dock_panel.size = DOCK_SIZE
	dock_panel.position = Vector2(
		maxf(viewport_size.x - DOCK_SIZE.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN),
		maxf((viewport_size.y - DOCK_SIZE.y) * 0.5, 4.0)
	)
	collapsed_panel.size = COLLAPSED_SIZE
	collapsed_panel.position = Vector2(
		maxf(viewport_size.x - COLLAPSED_SIZE.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN),
		maxf((viewport_size.y - COLLAPSED_SIZE.y) * 0.5, 4.0)
	)


func _set_collapsed(collapsed: bool) -> void:
	session_collapsed = collapsed
	if dock_panel != null:
		dock_panel.visible = not collapsed
	if collapsed_panel != null:
		collapsed_panel.visible = collapsed
	_layout_hud()


func _toggle_advanced() -> void:
	advanced_visible = not advanced_visible
	advanced_stack.visible = advanced_visible
	advanced_button.text = "Advanced <" if advanced_visible else "Advanced >"


func _on_state_changed(snapshot: Dictionary) -> void:
	if visible:
		_refresh(snapshot)


func _on_preset_selected(index: int) -> void:
	if shot_lab_system == null or index < 0 or index >= preset_selector.item_count:
		return
	shot_lab_system.set_selected_preset_id(str(preset_selector.get_item_metadata(index)))


func _on_option_toggled(enabled: bool, option_id: String) -> void:
	if shot_lab_system != null:
		shot_lab_system.set_option(option_id, enabled)


func _on_load_pressed() -> void:
	shot_lab_system.load_selected_setup()


func _on_fire_pressed() -> void:
	shot_lab_system.fire_reference_shot()


func _on_reset_pressed() -> void:
	shot_lab_system.reset_selected_setup()


func _on_rerun_pressed() -> void:
	shot_lab_system.rerun_last_reference_shot()


func _on_rewind_pressed() -> void:
	shot_lab_system.reset_last_shot()


func _on_inspect_pressed() -> void:
	inspect_result_requested.emit()


func _on_inspect_score_pressed() -> void:
	inspect_score_requested.emit()


func _on_scoring_modifier_selected(index: int) -> void:
	if shot_lab_system == null or index < 0 or index >= scoring_modifier_selector.item_count:
		return
	shot_lab_system.set_scoring_test_modifier_mode(str(scoring_modifier_selector.get_item_metadata(index)))


func _on_copy_score_summary_pressed() -> void:
	shot_lab_system.copy_score_summary()


func _on_copy_score_json_pressed() -> void:
	shot_lab_system.copy_score_breakdown_json()


func _on_scoring_self_test_pressed() -> void:
	shot_lab_system.run_scoring_self_tests()


func _on_raw_events_pressed() -> void:
	raw_events_requested.emit()


func _on_copy_result_pressed() -> void:
	var suite: Dictionary = _dictionary_value(latest_snapshot, "suite")
	if bool(suite.get("completed", false)):
		shot_lab_system.copy_reference_suite_results()
	else:
		shot_lab_system.copy_last_result()


func _on_copy_arrangement_pressed() -> void:
	shot_lab_system.copy_current_arrangement_as_preset()


func _on_capture_aim_pressed() -> void:
	shot_lab_system.capture_current_aim_as_reference()


func _on_regenerate_preflight_pressed() -> void:
	shot_lab_system.regenerate_reference_preflight()


func _on_copy_resolved_pressed() -> void:
	shot_lab_system.copy_resolved_reference()


func _on_copy_reference_snippet_pressed() -> void:
	shot_lab_system.copy_reference_as_preset_snippet()


func _on_nudge_aim_pressed(offset_world: Vector2) -> void:
	shot_lab_system.nudge_reference_aim(offset_world)


func _on_nudge_power_pressed(delta: float) -> void:
	shot_lab_system.nudge_reference_power(delta)


func _on_run_suite_pressed() -> void:
	shot_lab_system.run_reference_suite()


func _on_run_repeatability_suite_pressed() -> void:
	shot_lab_system.run_reference_repeatability_suite()


func _on_cancel_suite_pressed() -> void:
	shot_lab_system.cancel_reference_suite("shot_lab_hud")


func _on_exit_pressed() -> void:
	var suite: Dictionary = _dictionary_value(latest_snapshot, "suite")
	var shot_active: bool = bool(latest_snapshot.get("shot_active", false))
	var suite_running: bool = bool(suite.get("running", false))
	if shot_active or suite_running:
		var active_reason := "an active shot" if shot_active else "the reference suite"
		exit_confirmation.dialog_text = "Exit while %s is running? The test will be canceled and no ledger completion will be produced." % active_reason
		exit_confirmation.popup_centered(Vector2i(520, 190))
		return
	_emit_exit_requested()


func _emit_exit_requested() -> void:
	exit_lab_requested.emit()


func _add_action_button(parent: Container, text_value: String, callback: Callable) -> Button:
	var button := _make_button(text_value, 33.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _make_button(text_value: String, minimum_height: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, minimum_height)
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.68, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.47, 0.43, 0.72))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.055, 0.061, 0.060, 0.94), Color(0.48, 0.39, 0.20, 0.82)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.095, 0.088, 0.060, 0.98), GOLD_COLOR))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.035, 0.055, 0.052, 0.98), Color(0.48, 0.83, 0.74, 0.95)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.035, 0.038, 0.039, 0.78), Color(0.24, 0.24, 0.22, 0.62)))
	_register_interactive(button)
	return button


func _make_check_box(text_value: String, option_id: String) -> CheckBox:
	var check_box := CheckBox.new()
	check_box.text = text_value
	check_box.custom_minimum_size = Vector2(0.0, 24.0)
	check_box.add_theme_font_override("font", UI_FONT)
	check_box.add_theme_font_size_override("font_size", 14)
	check_box.toggled.connect(_on_option_toggled.bind(option_id))
	_register_interactive(check_box)
	return check_box


func _register_interactive(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	interactive_controls.append(control)


func _format_mult(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value, round(value)) else "%.2f" % value


func _normalize_dock_mouse_filters() -> void:
	_set_control_descendants_mouse_filter(dock_panel, Control.MOUSE_FILTER_IGNORE)
	_set_control_descendants_mouse_filter(collapsed_panel, Control.MOUSE_FILTER_IGNORE)
	for control in interactive_controls:
		if is_instance_valid(control):
			control.mouse_filter = Control.MOUSE_FILTER_STOP
	dock_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	collapsed_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _set_control_descendants_mouse_filter(node: Node, filter: int) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = filter
		_set_control_descendants_mouse_filter(child, filter)


func _set_check_without_signal(check_box: CheckBox, enabled: bool) -> void:
	if check_box != null:
		check_box.set_pressed_no_signal(enabled)


func _make_section_heading(text_value: String) -> Label:
	var label := _make_label(text_value.to_upper(), 13, GOLD_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 4.0)
	return style


func _make_button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	return style


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []
