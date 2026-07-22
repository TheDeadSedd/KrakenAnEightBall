extends Control
class_name RogueliteBalanceReportPanel

# Presentation-only Balance Report modal. It accepts a completed, value-only
# report and never calculates balance metrics or writes report files.

signal close_requested

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const PANEL_SIZE := Vector2(1180.0, 780.0)
const VIEWPORT_MARGIN := 24.0
const PANEL_Z_INDEX := 78
const PANEL_PADDING := 24
const SECTION_GAP := 12
const ROW_GAP := 6
const MIN_CONTENT_WIDTH := 440.0

const TITLE_COLOR := Color(1.0, 0.88, 0.48, 1.0)
const BODY_COLOR := Color(0.84, 0.88, 0.80, 0.98)
const MUTED_COLOR := Color(0.64, 0.67, 0.60, 0.94)
const ACCENT_COLOR := Color(0.56, 0.88, 0.78, 0.98)
const WARNING_COLOR := Color(1.0, 0.70, 0.35, 1.0)
const SHADE_COLOR := Color(0.005, 0.008, 0.012, 0.72)

const ITEM_SORT_UPLIFT := "uplift"
const ITEM_SORT_ACTIVATIONS := "activations"
const ITEM_SORT_ACQUIRED := "acquired"
const ITEM_SORT_NAME := "name"

var report_snapshot: Dictionary = {}
var report_dirty: bool = true
var advanced_enabled: bool = false
var item_sort_mode: String = ITEM_SORT_UPLIFT
var _built: bool = false

var shade: ColorRect
var panel_shell: Panel
var panel_margin: MarginContainer
var root_stack: VBoxContainer
var subtitle_label: Label
var advanced_toggle: CheckButton
var item_sort_selector: OptionButton
var report_scroll: ScrollContainer
var report_content: VBoxContainer
var status_label: Label
var copy_button_grid: GridContainer
var copy_summary_button: Button
var copy_json_button: Button
var copy_items_button: Button
var copy_rounds_button: Button
var close_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	z_index = PANEL_Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	_built = true
	_layout_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout_panel()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	_request_close()
	get_viewport().set_input_as_handled()


func set_report(report: Dictionary) -> void:
	report_snapshot = report.duplicate(true)
	report_dirty = true
	if visible:
		_refresh_visible_report()


func open_report(report: Dictionary = {}) -> void:
	if not report.is_empty():
		set_report(report)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_panel()
	_refresh_visible_report()
	call_deferred("_focus_initial_control")


func open_panel(report: Dictionary = {}) -> void:
	open_report(report)


func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status_label != null:
		status_label.text = ""


func is_open() -> bool:
	return visible


func get_report_snapshot() -> Dictionary:
	return report_snapshot.duplicate(true)


func set_advanced_enabled(enabled: bool) -> void:
	advanced_enabled = enabled
	if advanced_toggle != null:
		advanced_toggle.set_pressed_no_signal(enabled)
	report_dirty = true
	if visible:
		_refresh_visible_report()


func copy_balance_summary() -> bool:
	if report_snapshot.is_empty():
		_set_status("No Balance Report is available to copy.", true)
		return false
	var summary_text: String = _format_balance_summary()
	if summary_text.strip_edges().is_empty():
		_set_status("The Balance Report summary is empty.", true)
		return false
	DisplayServer.clipboard_set(summary_text)
	_set_status("Balance summary copied.")
	return true


func copy_balance_report_json() -> bool:
	if report_snapshot.is_empty():
		_set_status("No Balance Report is available to copy.", true)
		return false
	var supplied_json: String = str(report_snapshot.get("copy_json", ""))
	if supplied_json.is_empty():
		var json_value: Variant = report_snapshot.get("json_data", report_snapshot)
		supplied_json = JSON.stringify(_to_json_safe(json_value), "  ")
	DisplayServer.clipboard_set(supplied_json)
	_set_status("Balance Report JSON copied.")
	return true


func copy_item_contribution_table() -> bool:
	var items: Array[Dictionary] = _get_item_contributions()
	if items.is_empty():
		_set_status("No item contribution rows are available.", true)
		return false
	_sort_item_rows(items)
	var lines: PackedStringArray = PackedStringArray([
		"Item\tSlot\tRound Acquired\tRounds Owned\tShots Owned\tShots Triggered\tActivations\tHaul Added\tMult Added\txMult Product\tMarginal Uplift\tBuild Uplift Percent",
	])
	for item in items:
		lines.append("\t".join(PackedStringArray([
			_tsv_cell(_item_name(item)),
			_tsv_cell(_display_value(_value_by_keys(item, ["tray_slot", "slot", "slot_index"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["round_acquired", "acquired_round"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["rounds_owned"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["shots_owned"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["shots_triggered"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["trigger_occurrences", "activations", "activation_count"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["total_haul_added", "haul_added"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["total_mult_added", "mult_added"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["cumulative_xmult_factor", "cumulative_xmult_factors", "xmult_product"]))),
			_tsv_cell(_display_value(_value_by_keys(item, ["final_score_uplift", "marginal_score_uplift", "score_uplift"]))),
			_tsv_cell(_display_percent(item, ["percentage_of_build_uplift", "build_uplift_percentage"], ["build_uplift_share"])),
		])))
	DisplayServer.clipboard_set("\n".join(lines))
	_set_status("Item contribution table copied.")
	return true


func copy_round_table() -> bool:
	var rounds: Array[Dictionary] = _get_round_rows()
	if rounds.is_empty():
		_set_status("No round rows are available.", true)
		return false
	var lines: PackedStringArray = PackedStringArray([
		"Round\tQuota\tScore\tOverflow\tShots Used\tZero-score Shots\tHighest Shot\tAverage Shot\tBuild Uplift\tOutcome\tFailure Reason",
	])
	for round_snapshot in rounds:
		lines.append("\t".join(PackedStringArray([
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["round_number", "round"]))),
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["quota", "round_target"]))),
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["round_score", "score"]))),
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["score_overflow", "overflow"]))),
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["shots_used"]))),
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["zero_score_shots"]))),
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["highest_shot"]))),
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["average_shot", "actual_average_score_per_shot"]))),
			_tsv_cell(_display_value(_value_by_keys(round_snapshot, ["build_uplift", "build_score_uplift"]))),
			_tsv_cell(str(_value_by_keys(round_snapshot, ["outcome"], ""))),
			_tsv_cell(str(_value_by_keys(round_snapshot, ["failure_reason"], ""))),
		])))
	DisplayServer.clipboard_set("\n".join(lines))
	_set_status("Round table copied.")
	return true


func _build_ui() -> void:
	shade = ColorRect.new()
	shade.name = "Shade"
	shade.color = SHADE_COLOR
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_consume_pointer_input)
	add_child(shade)

	panel_shell = Panel.new()
	panel_shell.name = "PanelShell"
	panel_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_shell.add_theme_stylebox_override("panel", _make_panel_style())
	panel_shell.gui_input.connect(_consume_pointer_input)
	add_child(panel_shell)

	panel_margin = MarginContainer.new()
	panel_margin.name = "PanelMargin"
	panel_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	panel_margin.add_theme_constant_override("margin_top", 20)
	panel_margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	panel_margin.add_theme_constant_override("margin_bottom", 18)
	panel_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_shell.add_child(panel_margin)

	root_stack = VBoxContainer.new()
	root_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_stack.add_theme_constant_override("separation", 8)
	panel_margin.add_child(root_stack)

	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	root_stack.add_child(header)

	var title_label: Label = _make_label("BALANCE REPORT", 30, TITLE_COLOR)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	close_button = _make_button("Close", 92.0)
	close_button.pressed.connect(_request_close)
	header.add_child(close_button)

	subtitle_label = _make_label(
		"Run-level Long Sink telemetry. Compact findings first; internal attribution stays under Advanced.",
		14,
		MUTED_COLOR
	)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_stack.add_child(subtitle_label)

	var view_controls: HBoxContainer = HBoxContainer.new()
	view_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_controls.add_theme_constant_override("separation", 10)
	root_stack.add_child(view_controls)

	var sort_label: Label = _make_label("Item Order", 14, MUTED_COLOR)
	sort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	view_controls.add_child(sort_label)

	item_sort_selector = OptionButton.new()
	item_sort_selector.name = "ItemSortSelector"
	item_sort_selector.custom_minimum_size = Vector2(170.0, 36.0)
	item_sort_selector.mouse_filter = Control.MOUSE_FILTER_STOP
	item_sort_selector.add_theme_font_override("font", UI_FONT)
	item_sort_selector.add_theme_font_size_override("font_size", 14)
	item_sort_selector.add_item("Score Uplift")
	item_sort_selector.set_item_metadata(0, ITEM_SORT_UPLIFT)
	item_sort_selector.add_item("Activations")
	item_sort_selector.set_item_metadata(1, ITEM_SORT_ACTIVATIONS)
	item_sort_selector.add_item("Round Acquired")
	item_sort_selector.set_item_metadata(2, ITEM_SORT_ACQUIRED)
	item_sort_selector.add_item("Name")
	item_sort_selector.set_item_metadata(3, ITEM_SORT_NAME)
	item_sort_selector.item_selected.connect(_on_item_sort_selected)
	view_controls.add_child(item_sort_selector)

	var view_spacer: Control = Control.new()
	view_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_controls.add_child(view_spacer)

	advanced_toggle = CheckButton.new()
	advanced_toggle.name = "AdvancedToggle"
	advanced_toggle.text = "Advanced"
	advanced_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	advanced_toggle.add_theme_font_override("font", UI_FONT)
	advanced_toggle.add_theme_font_size_override("font_size", 15)
	advanced_toggle.toggled.connect(_on_advanced_toggled)
	view_controls.add_child(advanced_toggle)

	report_scroll = ScrollContainer.new()
	report_scroll.name = "ReportScroll"
	report_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	report_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root_stack.add_child(report_scroll)

	report_content = VBoxContainer.new()
	report_content.name = "ReportContent"
	report_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	report_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_content.add_theme_constant_override("separation", SECTION_GAP)
	report_scroll.add_child(report_content)

	status_label = _make_label("", 13, ACCENT_COLOR)
	status_label.custom_minimum_size = Vector2(0.0, 20.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_stack.add_child(status_label)

	copy_button_grid = GridContainer.new()
	copy_button_grid.name = "CopyActions"
	copy_button_grid.columns = 4
	copy_button_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy_button_grid.add_theme_constant_override("h_separation", 8)
	copy_button_grid.add_theme_constant_override("v_separation", 6)
	root_stack.add_child(copy_button_grid)

	copy_summary_button = _make_button("Copy Balance Summary")
	copy_summary_button.pressed.connect(copy_balance_summary)
	copy_button_grid.add_child(copy_summary_button)

	copy_json_button = _make_button("Copy Balance Report JSON")
	copy_json_button.pressed.connect(copy_balance_report_json)
	copy_button_grid.add_child(copy_json_button)

	copy_items_button = _make_button("Copy Item Contribution Table")
	copy_items_button.pressed.connect(copy_item_contribution_table)
	copy_button_grid.add_child(copy_items_button)

	copy_rounds_button = _make_button("Copy Round Table")
	copy_rounds_button.pressed.connect(copy_round_table)
	copy_button_grid.add_child(copy_rounds_button)


func _layout_panel() -> void:
	if panel_shell == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = size
	var available_size: Vector2 = Vector2(
		maxf(viewport_size.x - VIEWPORT_MARGIN * 2.0, 1.0),
		maxf(viewport_size.y - VIEWPORT_MARGIN * 2.0, 1.0)
	)
	var final_size: Vector2 = Vector2(
		minf(PANEL_SIZE.x, available_size.x),
		minf(PANEL_SIZE.y, available_size.y)
	)
	panel_shell.custom_minimum_size = Vector2.ZERO
	panel_shell.size = final_size
	panel_shell.position = ((viewport_size - final_size) * 0.5).floor()
	panel_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if report_content != null:
		var inner_width: float = maxf(final_size.x - float(PANEL_PADDING * 2) - 22.0, MIN_CONTENT_WIDTH)
		report_content.custom_minimum_size = Vector2(inner_width, 0.0)
	if copy_button_grid != null:
		copy_button_grid.columns = 4 if final_size.x >= 1040.0 else 2


func _refresh_visible_report() -> void:
	if not visible or report_content == null:
		return
	_clear_container(report_content)
	status_label.text = ""
	if report_snapshot.is_empty():
		_add_empty_state()
	else:
		_add_overview_section()
		_add_round_section()
		_add_item_section()
		_add_trigger_section()
		_add_tap_section()
		_add_phase_5c_tap_item_section()
		_add_dead_reckoning_section()
		_add_offer_section()
		_add_shot_distribution_section()
		_add_watch_flags_section()
		if advanced_enabled:
			_add_advanced_sections()
	report_dirty = false
	report_scroll.scroll_vertical = 0
	_update_copy_button_states()


func _add_empty_state() -> void:
	var section: VBoxContainer = _add_section("NO REPORT AVAILABLE")
	var label: Label = _make_body_label(
		"Finish or inspect a Long Sink run, then open this panel with its completed value-only Balance Report."
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, 130.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	section.add_child(label)


func _add_overview_section() -> void:
	var summary: Dictionary = _get_run_summary()
	var section: VBoxContainer = _add_section("OVERVIEW")
	var identity: Dictionary = _get_build_identity()
	var identity_label: String = str(_value_by_keys(identity, ["label", "identity", "name"], _value_by_keys(summary, ["build_identity"], "Unformed Build")))
	var outcome: String = _humanize_identifier(str(_value_by_keys(summary, ["final_outcome", "outcome"], "In Progress")))
	var rounds_reached: String = _display_value(_value_by_keys(summary, ["rounds_reached", "reached_round", "round_number"]))
	var uplift_text: String = _display_value(_value_by_keys(summary, ["total_build_uplift", "build_uplift"]))
	var uplift_percent: String = _display_percent(summary, ["build_uplift_percentage"], ["build_uplift_ratio"])
	if uplift_percent != "-":
		uplift_text = "%s (%s)" % [uplift_text, uplift_percent]
	_add_key_value_grid(section, [
		{"label": "Run", "value": "Round %s - %s" % [rounds_reached, outcome]},
		{"label": "Build", "value": identity_label},
		{"label": "Total Score", "value": _display_value(_value_by_keys(summary, ["total_authoritative_score", "total_score"]))},
		{"label": "Base Score", "value": _display_value(_value_by_keys(summary, ["total_base_score_without_build", "total_base_score", "base_score"]))},
		{"label": "Build Uplift", "value": uplift_text},
		{"label": "Highest Shot", "value": _display_value(_value_by_keys(summary, ["highest_shot"]))},
		{"label": "Shots", "value": _display_value(_value_by_keys(summary, ["total_shots", "shots"]))},
		{"label": "Zero-score Shots", "value": _display_value(_value_by_keys(summary, ["zero_score_shots"]))},
		{"label": "Scratches", "value": _display_value(_value_by_keys(summary, ["scratches"]))},
		{"label": "Base-Haul Doubloons", "value": _display_value(_value_by_keys(summary, ["total_doubloons_from_base_haul", "total_doubloons_earned_from_base_haul", "doubloons_earned"]))},
	])
	var identity_reason: String = str(_value_by_keys(identity, ["reason", "classification_reason"], ""))
	if not identity_reason.is_empty():
		var reason_label: Label = _make_body_label(identity_reason, 14, MUTED_COLOR)
		section.add_child(reason_label)


func _add_round_section() -> void:
	var rounds: Array[Dictionary] = _get_round_rows()
	var section: VBoxContainer = _add_section("ROUND BREAKDOWN", "%d recorded rounds" % rounds.size())
	if rounds.is_empty():
		section.add_child(_make_body_label("No finalized round metrics."))
		return
	for round_snapshot in rounds:
		var round_number: String = _display_value(_value_by_keys(round_snapshot, ["round_number", "round"]))
		var outcome: String = _humanize_identifier(str(_value_by_keys(round_snapshot, ["outcome"], "")))
		var title: String = "Round %s" % round_number
		if not outcome.is_empty():
			title += "  |  %s" % outcome
		var compact: String = "Quota %s  |  Score %s  |  Overflow %s  |  Shots %s  |  Highest %s" % [
			_display_value(_value_by_keys(round_snapshot, ["quota", "round_target"])),
			_display_value(_value_by_keys(round_snapshot, ["round_score", "score"])),
			_display_value(_value_by_keys(round_snapshot, ["score_overflow", "overflow"])),
			_display_value(_value_by_keys(round_snapshot, ["shots_used"])),
			_display_value(_value_by_keys(round_snapshot, ["highest_shot"])),
		]
		var detail: String = ""
		if advanced_enabled:
			detail = "Available shots %s  |  Zero-score %s  |  Required avg %s  |  Actual avg %s  |  Base %s  |  Build uplift %s" % [
				_display_value(_value_by_keys(round_snapshot, ["starting_shots", "shots_available"])),
				_display_value(_value_by_keys(round_snapshot, ["zero_score_shots"])),
				_display_value(_value_by_keys(round_snapshot, ["required_average_score_per_shot"])),
				_display_value(_value_by_keys(round_snapshot, ["actual_average_score_per_shot", "average_shot"])),
				_display_value(_value_by_keys(round_snapshot, ["total_base_score_without_build", "base_score_without_build", "base_score"])),
				_display_value(_value_by_keys(round_snapshot, ["build_uplift_over_base_scoring", "build_uplift", "build_score_uplift"])),
			]
		_add_compact_row(section, title, compact, detail)


func _add_item_section() -> void:
	var items: Array[Dictionary] = _get_item_contributions()
	_sort_item_rows(items)
	var section: VBoxContainer = _add_section("EIGHT BALLS", "%d owned items represented" % items.size())
	if items.is_empty():
		section.add_child(_make_body_label("No Eight Ball contribution rows."))
		return
	for item in items:
		var name: String = _item_name(item)
		var slot: String = _display_value(_value_by_keys(item, ["tray_slot", "slot", "slot_index"]))
		var acquired: String = _display_value(_value_by_keys(item, ["round_acquired", "acquired_round"]))
		var activations: String = _display_value(_value_by_keys(item, ["trigger_occurrences", "activations", "activation_count"]))
		var uplift: String = _display_value(_value_by_keys(item, ["final_score_uplift", "marginal_score_uplift", "score_uplift"]))
		var share: String = _display_percent(item, ["percentage_of_build_uplift", "build_uplift_percentage"], ["build_uplift_share"])
		var compact: String = "Slot %s  |  Acquired R%s  |  %s activations  |  %s uplift  |  %s of build uplift" % [
			slot,
			acquired,
			activations,
			uplift,
			share,
		]
		var detail: String = ""
		if advanced_enabled:
			detail = "Owned %s rounds / %s shots  |  Triggered %s shots  |  Regular %s / Retrigger %s  |  +Haul %s  |  +Mult %s  |  xMult %s  |  Avg/activation %s" % [
				_display_value(_value_by_keys(item, ["rounds_owned"])),
				_display_value(_value_by_keys(item, ["shots_owned"])),
				_display_value(_value_by_keys(item, ["shots_triggered"])),
				_display_value(_value_by_keys(item, ["regular_activations"])),
				_display_value(_value_by_keys(item, ["retriggered_activations"])),
				_display_value(_value_by_keys(item, ["total_haul_added", "haul_added"])),
				_display_value(_value_by_keys(item, ["total_mult_added", "mult_added"])),
				_display_value(_value_by_keys(item, ["cumulative_xmult_factor", "cumulative_xmult_factors", "xmult_product"])),
				_display_value(_value_by_keys(item, ["average_score_uplift_per_activation", "average_uplift_per_activation"])),
			]
			var phase_metrics: Dictionary = _dictionary_by_keys(item, ["phase_5c_metrics"])
			if not phase_metrics.is_empty():
				var state_suffix: String = ""
				if phase_metrics.has("final_xmult"):
					state_suffix = "  |  State x%s" % _display_value(
						phase_metrics.get("final_xmult")
					)
				detail += "\nPhase 5C: %s marginal uplift%s" % [
					_display_value(_value_by_keys(phase_metrics, ["marginal_score_uplift"])),
					state_suffix,
				]
		_add_compact_row(section, name, compact, detail)


func _add_trigger_section() -> void:
	var metrics: Dictionary = _get_trigger_metrics()
	var section: VBoxContainer = _add_section("TRIGGERS")
	if metrics.is_empty():
		section.add_child(_make_body_label("No trigger-family metrics."))
		return
	var preferred_keys: Array[String] = [
		"single_bank",
		"double_bank",
		"triple_bank",
		"combination",
		"direct_pot",
		"multi_pot",
		"same_pocket",
		"cue_recontact",
		"ball_tap",
	]
	var rendered_keys: Array[String] = []
	for trigger_key in preferred_keys:
		if not metrics.has(trigger_key):
			continue
		_add_trigger_row(section, trigger_key, metrics[trigger_key])
		rendered_keys.append(trigger_key)
	for key_value in metrics.keys():
		var trigger_key: String = str(key_value)
		if rendered_keys.has(trigger_key) or not metrics[key_value] is Dictionary:
			continue
		_add_trigger_row(section, trigger_key, metrics[key_value])


func _add_trigger_row(section: VBoxContainer, trigger_key: String, metric_value: Variant) -> void:
	if not metric_value is Dictionary:
		return
	var metric: Dictionary = metric_value
	var compact: String = "%s milestones  |  %s shots containing  |  %s owned activations" % [
		_display_value(_value_by_keys(metric, ["milestone_occurrences", "occurrences", "trigger_occurrences"])),
		_display_value(_value_by_keys(metric, ["shots_containing", "shots"])),
		_display_value(_value_by_keys(metric, ["owned_item_activations", "activations"])),
	]
	var detail: String = ""
	if advanced_enabled:
		detail = "Regular activations %s  |  Retriggers %s  |  Average score on containing shots %s" % [
			_display_value(_value_by_keys(metric, ["regular_item_activations"])),
			_display_value(_value_by_keys(metric, ["retriggered_item_activations"])),
			_display_value(_value_by_keys(metric, ["average_score_from_shots_containing", "average_score_from_containing_shots", "average_score"])),
		]
	_add_compact_row(section, _humanize_identifier(trigger_key), compact, detail)


func _add_tap_section() -> void:
	var metrics: Dictionary = _get_tap_metrics()
	var section: VBoxContainer = _add_section(
		"TAP SCORING",
		"Authoritative Double Tap and unique Ball Tap evidence"
	)
	if metrics.is_empty():
		section.add_child(_make_body_label("No Tap telemetry was recorded.", 14, MUTED_COLOR))
		return
	_add_key_value_grid(section, [
		{"label": "Double Tap Shots", "value": _display_value(_value_by_keys(metrics, ["shots_with_double_tap"]))},
		{"label": "Triple Tap+ Shots", "value": _display_value(_value_by_keys(metrics, ["shots_with_triple_tap_or_higher"]))},
		{"label": "Cue Recontact Milestones", "value": _display_value(_value_by_keys(metrics, ["cue_recontact_milestones"]))},
		{"label": "Ball Tap Scoring Balls", "value": _display_value(_value_by_keys(metrics, ["scoring_balls_with_ball_tap"]))},
		{"label": "Unique Ball Tap Milestones", "value": _display_value(_value_by_keys(metrics, ["ball_tap_milestones", "unique_ball_tap_target_count"]))},
		{"label": "Tap Score Supplied", "value": "%s cue + %s ball = %s" % [
			_display_value(_value_by_keys(metrics, ["cue_recontact_score_supplied"])),
			_display_value(_value_by_keys(metrics, ["ball_tap_score_supplied"])),
			_display_value(_value_by_keys(metrics, ["total_tap_score_supplied"])),
		]},
	])
	if not advanced_enabled:
		return
	section.add_child(_make_body_label(
		"Score supplied is the immediate score-preview delta at each base Tap resolution step, before Eight Ball modifiers.",
		13,
		MUTED_COLOR
	))
	var comparison: Dictionary = _dictionary_by_keys(metrics, ["frequency_comparison"])
	_add_key_value_grid(section, [
		{"label": "Average Double Tap Mult", "value": _display_value(_value_by_keys(metrics, ["average_double_tap_mult"]))},
		{"label": "Average Ball Tap Mult", "value": _display_value(_value_by_keys(metrics, ["average_ball_tap_mult"]))},
		{"label": "Max Cue Strikes / Ball", "value": _display_value(_value_by_keys(metrics, ["maximum_cue_strikes_against_one_scoring_ball"]))},
		{"label": "Max Ball Taps / Ball", "value": _display_value(_value_by_keys(metrics, ["maximum_ball_taps_by_one_scoring_ball"]))},
		{"label": "Repeated Targets Ignored", "value": _display_value(_value_by_keys(metrics, ["repeated_ball_tap_contacts_ignored"]))},
		{"label": "Ambiguity Rejects", "value": _display_value(_value_by_keys(metrics, ["ambiguous_tap_contacts_rejected"]))},
		{"label": "Tap Direct-Pot Disqualifications", "value": _display_value(_value_by_keys(metrics, ["tap_direct_pot_disqualifications"]))},
		{"label": "Cue / Ball / Bank / Combo Shot Frequency", "value": "%s / %s / %s / %s" % [
			_display_percent(comparison, [], ["cue_recontact_shot_frequency"]),
			_display_percent(comparison, [], ["ball_tap_shot_frequency"]),
			_display_percent(comparison, [], ["bank_shot_frequency"]),
			_display_percent(comparison, [], ["combination_shot_frequency"]),
		]},
		{"label": "Cue:Bank / Ball:Bank Occurrence Ratio", "value": "%s / %s" % [
			_display_value(_value_by_keys(comparison, ["cue_recontact_to_bank_occurrence_ratio"])),
			_display_value(_value_by_keys(comparison, ["ball_tap_to_bank_occurrence_ratio"])),
		]},
		{"label": "Cue:Combo / Ball:Combo Occurrence Ratio", "value": "%s / %s" % [
			_display_value(_value_by_keys(comparison, ["cue_recontact_to_combination_ratio"])),
			_display_value(_value_by_keys(comparison, ["ball_tap_to_combination_ratio"])),
		]},
	])
	var thresholds: Dictionary = _dictionary_by_keys(metrics, ["watch_thresholds"])
	if not thresholds.is_empty():
		section.add_child(_make_body_label(
			"Diagnostic thresholds: Tap Exploit at %s cue strikes on one scoring ball; Contact Farm at %s repeated contacts and %s repeated-to-unique ratio in one shot." % [
				_display_value(_value_by_keys(thresholds, ["tap_exploit_max_cue_strikes_per_ball"])),
				_display_value(_value_by_keys(thresholds, ["contact_farm_min_repeated_contacts_per_shot"])),
				_display_value(_value_by_keys(thresholds, ["contact_farm_repeated_to_unique_ratio"])),
			],
			13,
			MUTED_COLOR
		))


func _add_phase_5c_tap_item_section() -> void:
	var metrics: Dictionary = _get_phase_5c_tap_item_metrics()
	if metrics.is_empty():
		return
	var rattle: Dictionary = _dictionary_by_keys(metrics, ["rattle"])
	var punch: Dictionary = _dictionary_by_keys(metrics, ["one_two_punch"])
	var aftershock: Dictionary = _dictionary_by_keys(metrics, ["aftershock"])
	var echo: Dictionary = _dictionary_by_keys(metrics, ["echo_chamber"])
	if not (
		bool(rattle.get("owned", false))
		or bool(punch.get("owned", false))
		or bool(aftershock.get("owned", false))
		or bool(echo.get("owned", false))
	):
		return
	var section: VBoxContainer = _add_section(
		"TAP ENGINE",
		"State, conditional activation, escalation, and retrigger attribution"
	)
	if bool(rattle.get("owned", false)):
		var rattle_compact: String = "x%s acquired -> x%s current  |  %s Tap growth  |  %s uplift" % [
			_display_value(_value_by_keys(rattle, ["acquired_value"])),
			_display_value(_value_by_keys(rattle, ["final_xmult", "current_xmult"])),
			_display_value(_value_by_keys(rattle, ["tap_milestones_grown_from"])),
			_display_value(_value_by_keys(rattle, ["marginal_score_uplift"])),
		]
		var rattle_detail: String = "Activated %s / %s owned shots  |  Non-Tap owned shots %s  |  Lifetime growth %s  |  Instance IDs %s" % [
			_display_value(_value_by_keys(rattle, ["shots_activated"])),
			_display_value(_value_by_keys(rattle, ["shots_owned"])),
			_display_value(_value_by_keys(rattle, ["non_tap_shots_owned"])),
			_display_value(_value_by_keys(rattle, ["lifetime_growth"])),
			_join_values(_array_by_keys(rattle, ["owned_item_instance_ids"])),
		] if advanced_enabled else ""
		_add_compact_row(section, "Rattle of the Deep", rattle_compact, rattle_detail)
	if bool(punch.get("owned", false)):
		_add_compact_row(
			section,
			"One-Two Punch",
			"%s qualifying balls  |  %s activations  |  %s uplift" % [
				_display_value(_value_by_keys(punch, ["qualifying_scoring_balls"])),
				_display_value(_value_by_keys(punch, ["activations"])),
				_display_value(_value_by_keys(punch, ["marginal_score_uplift"])),
			],
			"One-family-only shots while owned: %s" % _display_value(_value_by_keys(
				punch,
				["shots_with_only_one_family"]
			)) if advanced_enabled else ""
		)
	if bool(aftershock.get("owned", false)):
		_add_compact_row(
			section,
			"Aftershock",
			"%s Tap milestones  |  %s xMult activations  |  highest ordinal %s  |  %s uplift" % [
				_display_value(_value_by_keys(aftershock, ["tap_milestones_while_owned"])),
				_display_value(_value_by_keys(aftershock, ["xmult_activations"])),
				_display_value(_value_by_keys(aftershock, ["highest_tap_ordinal"])),
				_display_value(_value_by_keys(aftershock, ["marginal_score_uplift"])),
			],
			"Ignored first milestones: %s" % _display_value(_value_by_keys(
				aftershock,
				["ignored_first_milestones"]
			)) if advanced_enabled else ""
		)
	if bool(echo.get("owned", false)):
		var family_counts: Dictionary = _dictionary_by_keys(echo, ["retriggers_by_family"])
		var echo_detail: String = "Double Tap / Ball Tap retriggers %s / %s  |  +Haul %s  |  +Mult %s  |  xMult %s (%s product)\nSupported rounds: %s  |  Unsupported rounds: %s" % [
			_display_value(_value_by_keys(family_counts, ["double_tap"])),
			_display_value(_value_by_keys(family_counts, ["ball_tap"])),
			_display_value(_value_by_keys(echo, ["retriggered_add_haul"])),
			_display_value(_value_by_keys(echo, ["retriggered_add_mult"])),
			_display_value(_value_by_keys(echo, ["retriggered_xmult_activations"])),
			_display_value(_value_by_keys(echo, ["retriggered_xmult_product"])),
			_join_values(_array_by_keys(echo, ["round_numbers_owned_with_support"])),
			_join_values(_array_by_keys(echo, ["round_numbers_owned_without_support"])),
		] if advanced_enabled else ""
		_add_compact_row(
			section,
			"Echo Chamber",
			"%s thresholds  |  %s supported / %s unsupported  |  %s retriggers  |  %s uplift" % [
				_display_value(_value_by_keys(echo, ["threshold_milestones"])),
				_display_value(_value_by_keys(echo, ["supported_thresholds"])),
				_display_value(_value_by_keys(echo, ["unsupported_thresholds"])),
				_display_value(_value_by_keys(echo, ["regular_activations_retriggered"])),
				_display_value(_value_by_keys(echo, ["marginal_score_uplift"])),
			],
			echo_detail
		)
	if advanced_enabled:
		var history: Array[Dictionary] = _dictionary_array_by_keys(metrics, ["state_history"])
		if not history.is_empty():
			var latest: Dictionary = history[history.size() - 1]
			section.add_child(_make_body_label(
				"Latest Rattle state: x%s -> x%s on %s (%s Tap milestones). Retained %s/%s bounded records." % [
					_display_value(_value_by_keys(latest, ["current_xmult_before"])),
					_display_value(_value_by_keys(latest, ["current_xmult_after"])),
					str(_value_by_keys(latest, ["shot_key"], "shot")),
					_display_value(_value_by_keys(latest, ["tap_milestones"])),
					_display_value(history.size()),
					_display_value(_value_by_keys(metrics, ["bounded_history_limit"])),
				],
				13,
				MUTED_COLOR
			))


func _add_dead_reckoning_section() -> void:
	var metrics: Dictionary = _get_dead_reckoning_metrics()
	if metrics.is_empty() or not bool(metrics.get("owned", false)):
		return
	var section: VBoxContainer = _add_section(
		"DEAD RECKONING",
		"Bounded Direct Pot family retrigger support"
	)
	_add_key_value_grid(section, [
		{"label": "Direct Pots While Owned", "value": _display_value(_value_by_keys(metrics, ["direct_pot_occurrences_while_owned"]))},
		{"label": "Supported", "value": _display_value(_value_by_keys(metrics, ["supported_occurrences"]))},
		{"label": "Unsupported / Dead", "value": _display_value(_value_by_keys(metrics, ["unsupported_occurrences", "dead_occurrences"]))},
		{"label": "Activations Retriggered", "value": _display_value(_value_by_keys(metrics, ["regular_activations_retriggered"]))},
		{"label": "Retriggered +Haul", "value": _display_value(_value_by_keys(metrics, ["retriggered_add_haul"]))},
		{"label": "Retriggered +Mult", "value": _display_value(_value_by_keys(metrics, ["retriggered_add_mult"]))},
		{"label": "Retriggered xMult", "value": "%s activations / %s product" % [
			_display_value(_value_by_keys(metrics, ["retriggered_xmult_activations"])),
			_display_value(_value_by_keys(metrics, ["retriggered_xmult_product"])),
		]},
		{"label": "Marginal Score", "value": _display_value(_value_by_keys(metrics, ["marginal_score_uplift"]))},
		{"label": "Rounds Without Support", "value": _display_value(_value_by_keys(metrics, ["rounds_owned_without_support"]))},
	])
	if advanced_enabled:
		var support_ids: Array = _array_by_keys(metrics, ["support_item_ids_seen"])
		var unsupported_rounds: Array = _array_by_keys(
			metrics,
			["round_numbers_owned_without_support"]
		)
		section.add_child(_make_body_label(
			"Support seen: %s\nUnsupported rounds: %s" % [
				_join_values(support_ids),
				_join_values(unsupported_rounds),
			],
			13,
			MUTED_COLOR
		))


func _add_offer_section() -> void:
	var metrics: Dictionary = _get_offer_metrics()
	var section: VBoxContainer = _add_section("OFFERS")
	if metrics.is_empty():
		section.add_child(_make_body_label("No Mark Your Course offer metrics."))
		return
	_add_key_value_grid(section, [
		{"label": "Screens", "value": _display_value(_value_by_keys(metrics, ["offer_screen_count", "screens", "reward_screen_count"]))},
		{"label": "Selections", "value": _display_value(_value_by_keys(metrics, ["selection_count", "selected_count"]))},
		{"label": "Replacements", "value": _display_value(_value_by_keys(metrics, ["replacement_count"]))},
		{"label": "Skips", "value": _display_value(_value_by_keys(metrics, ["skip_count"]))},
		{"label": "Full Tray", "value": _display_percent(metrics, ["full_tray_frequency", "full_tray_percentage"], ["full_tray_ratio"])},
		{"label": "Avg Eligible Pool", "value": _display_value(_value_by_keys(metrics, ["average_unowned_eligible_pool_size", "average_eligible_pool_size"]))},
	])
	_add_offer_breakdown(section, "BY FAMILY", _value_by_keys(metrics, ["by_family", "families", "family_metrics"], {}))
	if advanced_enabled:
		_add_offer_breakdown(section, "BY ITEM", _value_by_keys(metrics, ["by_item", "items", "item_metrics"], {}))


func _add_offer_breakdown(section: VBoxContainer, title: String, value: Variant) -> void:
	var rows: Array[Dictionary] = _normalize_named_rows(value)
	if rows.is_empty():
		return
	section.add_child(_make_label(title, 14, ACCENT_COLOR))
	for row in rows:
		var row_name: String = str(_value_by_keys(row, ["display_name", "label", "name", "id"], "Entry"))
		var compact: String = "Offered %s  |  Selected %s  |  Rate %s" % [
			_display_value(_value_by_keys(row, ["offer_count", "offered", "offers"])),
			_display_value(_value_by_keys(row, ["selection_count", "selected", "selections"])),
			_display_percent(row, ["selection_rate", "selection_percentage"], ["selection_ratio"]),
		]
		_add_compact_row(section, row_name, compact)


func _add_shot_distribution_section() -> void:
	var distribution: Dictionary = _get_shot_distribution()
	var section: VBoxContainer = _add_section("SHOT DISTRIBUTION")
	if distribution.is_empty():
		section.add_child(_make_body_label("No shot-distribution metrics."))
		return
	_add_key_value_grid(section, [
		{"label": "Zero", "value": _display_value(_value_by_keys(distribution, ["zero", "zero_score_shots"]))},
		{"label": "Low", "value": _display_value(_value_by_keys(distribution, ["low", "low_score_shots"]))},
		{"label": "Medium", "value": _display_value(_value_by_keys(distribution, ["medium", "medium_score_shots"]))},
		{"label": "High", "value": _display_value(_value_by_keys(distribution, ["high", "high_score_shots"]))},
		{"label": "Largest Shot", "value": _display_value(_value_by_keys(distribution, ["largest_shot", "highest_shot"]))},
		{"label": "Largest-shot Concentration", "value": _display_percent(distribution, ["largest_shot_percentage", "largest_shot_concentration_percentage"], ["largest_shot_ratio", "largest_shot_concentration"])},
	])


func _add_watch_flags_section() -> void:
	var flags: Array[Dictionary] = _get_watch_flags()
	var section: VBoxContainer = _add_section("BALANCE WATCH", "%d diagnostic flags" % flags.size())
	if flags.is_empty():
		section.add_child(_make_body_label("No balance watch flags were raised for this report.", 14, MUTED_COLOR))
		return
	for flag in flags:
		var flag_id: String = str(_value_by_keys(flag, ["label", "display_name", "id", "code"], "Watch Item"))
		var reason: String = str(_value_by_keys(flag, ["reason", "description", "message"], ""))
		var card: PanelContainer = _make_row_card(true)
		var stack: VBoxContainer = _make_card_stack(card)
		stack.add_child(_make_label(_humanize_identifier(flag_id).to_upper(), 16, WARNING_COLOR))
		if not reason.is_empty():
			stack.add_child(_make_body_label(reason, 14, BODY_COLOR))
		section.add_child(card)


func _add_advanced_sections() -> void:
	var attribution: Dictionary = _dictionary_by_keys(report_snapshot, ["attribution", "attribution_summary", "item_attribution"])
	var summary: Dictionary = _get_run_summary()
	var attribution_section: VBoxContainer = _add_section("ATTRIBUTION DETAILS", "Counterfactual results supplied by the Balance Analyzer")
	_add_key_value_grid(attribution_section, [
		{"label": "Method", "value": str(_value_by_keys(attribution, ["method", "marginal_method", "attribution_method"], _value_by_keys(report_snapshot, ["attribution_method"], "-")))},
		{"label": "Interaction Surplus", "value": _display_value(_value_by_keys(attribution, ["interaction_surplus", "xmult_interaction_surplus"], _value_by_keys(summary, ["interaction_surplus"], null)))},
		{"label": "Maximum Haul", "value": _display_value(_value_by_keys(summary, ["maximum_haul", "max_haul"]))},
		{"label": "Maximum Mult", "value": _display_value(_value_by_keys(summary, ["maximum_mult", "max_mult"]))},
		{"label": "Maximum xMult", "value": _display_value(_value_by_keys(summary, ["maximum_xmult_product", "max_xmult_product"]))},
		{"label": "Maximum Excitement", "value": _display_value(_value_by_keys(summary, ["maximum_global_excitement", "max_global_excitement"]))},
	])
	var attribution_note: String = str(_value_by_keys(attribution, ["note", "interaction_note", "description"], ""))
	if not attribution_note.is_empty():
		attribution_section.add_child(_make_body_label(attribution_note, 14, MUTED_COLOR))

	var technical_section: VBoxContainer = _add_section("TECHNICAL", "Value-only report metadata and analyzer diagnostics")
	var metadata: Dictionary = _dictionary_by_keys(report_snapshot, ["metadata", "report_metadata"])
	var diagnostics: Dictionary = _dictionary_by_keys(report_snapshot, ["diagnostics", "analysis_diagnostics"])
	_add_key_value_grid(technical_section, [
		{"label": "Schema", "value": _display_value(_value_by_keys(report_snapshot, ["schema_version"], _value_by_keys(metadata, ["schema_version"], null)))},
		{"label": "Report ID", "value": str(_value_by_keys(report_snapshot, ["report_id", "run_id"], _value_by_keys(metadata, ["report_id", "run_id"], "-")))},
		{"label": "Analysis Duration", "value": _format_duration(_value_by_keys(report_snapshot, ["analysis_duration_usec", "analysis_duration_us"], _value_by_keys(diagnostics, ["analysis_duration_usec", "analysis_duration_us"], null)))},
		{"label": "Recorded Shots", "value": _display_value(_value_by_keys(diagnostics, ["shot_record_count", "shots_recorded"], _value_by_keys(summary, ["total_shots"], null)))},
		{"label": "Counterfactual Resolves", "value": _display_value(_value_by_keys(diagnostics, ["counterfactual_resolution_count", "counterfactual_resolves"]))},
		{"label": "Abandoned Attempts", "value": _display_value(_value_by_keys(diagnostics, ["abandoned_attempt_count", "abandoned_attempts"]))},
	])
	var diagnostic_lines: Array[String] = []
	_collect_scalar_lines(diagnostics, "", diagnostic_lines, 0)
	if not diagnostic_lines.is_empty():
		var diagnostics_label: Label = _make_body_label("\n".join(diagnostic_lines), 13, MUTED_COLOR)
		technical_section.add_child(diagnostics_label)
	var warnings: Array = _array_by_keys(report_snapshot, ["warnings", "analysis_warnings"])
	if not warnings.is_empty():
		technical_section.add_child(_make_label("WARNINGS", 14, WARNING_COLOR))
		for warning_value in warnings:
			technical_section.add_child(_make_body_label("- %s" % str(warning_value), 13, BODY_COLOR))


func _add_section(title: String, subtitle: String = "") -> VBoxContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _make_section_style())
	report_content.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", ROW_GAP)
	margin.add_child(stack)
	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(header)
	var title_label: Label = _make_label(title, 18, TITLE_COLOR)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	if not subtitle.is_empty():
		var subtitle_label: Label = _make_label(subtitle, 13, MUTED_COLOR)
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header.add_child(subtitle_label)
	return stack


func _add_key_value_grid(parent: VBoxContainer, entries: Array) -> void:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 5)
	parent.add_child(grid)
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var key_label: Label = _make_label(str(entry.get("label", "Metric")), 13, MUTED_COLOR)
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(key_label)
		var value_label: Label = _make_label(str(entry.get("value", "-")), 14, BODY_COLOR)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value_label)


func _add_compact_row(parent: VBoxContainer, title: String, compact: String, detail: String = "") -> void:
	var card: PanelContainer = _make_row_card(false)
	var stack: VBoxContainer = _make_card_stack(card)
	stack.add_child(_make_label(title, 15, ACCENT_COLOR))
	stack.add_child(_make_body_label(compact, 14, BODY_COLOR))
	if not detail.is_empty():
		stack.add_child(_make_body_label(detail, 13, MUTED_COLOR))
	parent.add_child(card)


func _make_row_card(warning: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: Color = Color(0.052, 0.040, 0.030, 0.78) if not warning else Color(0.085, 0.045, 0.022, 0.82)
	var border: Color = Color(0.56, 0.45, 0.24, 0.34) if not warning else Color(0.95, 0.53, 0.20, 0.60)
	card.add_theme_stylebox_override("panel", _make_flat_style(fill, border, 1, 5))
	return card


func _make_card_stack(card: PanelContainer) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 3)
	margin.add_child(stack)
	return stack


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_body_label(text_value: String, font_size: int = 14, color: Color = BODY_COLOR) -> Label:
	var label: Label = _make_label(text_value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _make_button(text_value: String, minimum_width: float = 0.0) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(minimum_width, 38.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.62, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.76, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.18, 0.09, 0.03, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.50, 0.49, 0.44, 0.74))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.075, 0.055, 0.036, 0.94), Color(0.72, 0.56, 0.28, 0.62)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.13, 0.088, 0.042, 0.98), Color(1.0, 0.80, 0.36, 0.92)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.84, 0.63, 0.27, 0.98), Color(1.0, 0.90, 0.58, 1.0)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.09, 0.066, 0.038, 0.98), Color(0.56, 0.90, 0.80, 0.82)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.035, 0.032, 0.030, 0.72), Color(0.34, 0.31, 0.25, 0.42)))
	return button


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_flat_style(Color(0.018, 0.022, 0.024, 0.985), Color(0.88, 0.68, 0.30, 0.86), 2, 8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 24
	style.shadow_offset = Vector2(0.0, 8.0)
	return style


func _make_section_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_flat_style(Color(0.030, 0.034, 0.032, 0.92), Color(0.62, 0.50, 0.27, 0.48), 1, 6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	style.shadow_size = 5
	return style


func _make_button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _make_flat_style(fill, border, 1, 5)
	style.set_content_margin(SIDE_LEFT, 12.0)
	style.set_content_margin(SIDE_RIGHT, 12.0)
	style.set_content_margin(SIDE_TOP, 7.0)
	style.set_content_margin(SIDE_BOTTOM, 6.0)
	return style


func _make_flat_style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _get_run_summary() -> Dictionary:
	var summary: Dictionary = _dictionary_by_keys(report_snapshot, ["run_summary", "overview", "summary"])
	return summary if not summary.is_empty() else report_snapshot


func _get_build_identity() -> Dictionary:
	var identity_value: Variant = _value_by_keys(report_snapshot, ["build_identity", "build_identity_summary"], {})
	if identity_value is Dictionary:
		return (identity_value as Dictionary).duplicate(true)
	if identity_value is String:
		return {"label": str(identity_value)}
	var summary: Dictionary = _get_run_summary()
	identity_value = summary.get("build_identity", {})
	if identity_value is Dictionary:
		return (identity_value as Dictionary).duplicate(true)
	if identity_value is String:
		return {"label": str(identity_value)}
	return {}


func _get_round_rows() -> Array[Dictionary]:
	return _dictionary_array_by_keys(report_snapshot, ["rounds", "round_breakdown", "round_metrics"])


func _get_item_contributions() -> Array[Dictionary]:
	return _dictionary_array_by_keys(report_snapshot, ["item_contributions", "eight_balls", "item_metrics"])


func _get_trigger_metrics() -> Dictionary:
	var metrics: Dictionary = _dictionary_by_keys(
		report_snapshot,
		["trigger_families", "trigger_metrics", "triggers"]
	)
	var families_value: Variant = metrics.get("families", {})
	return (
		(families_value as Dictionary).duplicate(true)
		if families_value is Dictionary
		else metrics
	)


func _get_tap_metrics() -> Dictionary:
	var metrics: Dictionary = _dictionary_by_keys(
		report_snapshot,
		["tap_metrics", "tap_scoring_metrics"]
	)
	if not metrics.is_empty():
		return metrics
	var summary: Dictionary = _get_run_summary()
	return _dictionary_by_keys(summary, ["tap_metrics", "tap_scoring_metrics"])


func _get_phase_5c_tap_item_metrics() -> Dictionary:
	return _dictionary_by_keys(
		report_snapshot,
		["phase_5c_tap_items", "tap_item_metrics", "unusual_tap_metrics"]
	)


func _get_dead_reckoning_metrics() -> Dictionary:
	return _dictionary_by_keys(
		report_snapshot,
		["dead_reckoning_metrics", "dead_reckoning", "retrigger_metrics"]
	)


func _get_offer_metrics() -> Dictionary:
	return _dictionary_by_keys(report_snapshot, ["offer_metrics", "offers", "offer_summary"])


func _get_shot_distribution() -> Dictionary:
	return _dictionary_by_keys(report_snapshot, ["shot_distribution", "shot_metrics", "distribution"])


func _get_watch_flags() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var values: Array = _array_by_keys(report_snapshot, ["watch_flags", "balance_watch_flags", "warnings"])
	for value in values:
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
		else:
			result.append({"label": str(value)})
	return result


func _dictionary_by_keys(source: Dictionary, keys: Array) -> Dictionary:
	for key_value in keys:
		var key: String = str(key_value)
		if not source.has(key):
			continue
		var value: Variant = source[key]
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


func _array_by_keys(source: Dictionary, keys: Array) -> Array:
	for key_value in keys:
		var key: String = str(key_value)
		if source.has(key) and source[key] is Array:
			return (source[key] as Array).duplicate(true)
	return []


func _dictionary_array_by_keys(source: Dictionary, keys: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in _array_by_keys(source, keys):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result


func _value_by_keys(source: Dictionary, keys: Array, fallback: Variant = null) -> Variant:
	for key_value in keys:
		var key: String = str(key_value)
		if source.has(key) and source[key] != null:
			return source[key]
	return fallback


func _normalize_named_rows(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if value is Array:
		for row_value in value as Array:
			if row_value is Dictionary:
				rows.append((row_value as Dictionary).duplicate(true))
	elif value is Dictionary:
		for key_value in (value as Dictionary).keys():
			var row_value: Variant = (value as Dictionary)[key_value]
			if row_value is Dictionary:
				var row: Dictionary = (row_value as Dictionary).duplicate(true)
				if not row.has("id"):
					row["id"] = str(key_value)
				rows.append(row)
	return rows


func _sort_item_rows(items: Array[Dictionary]) -> void:
	items.sort_custom(_compare_item_rows)


func _compare_item_rows(left: Dictionary, right: Dictionary) -> bool:
	match item_sort_mode:
		ITEM_SORT_ACTIVATIONS:
			var left_activations: float = _numeric_by_keys(left, ["trigger_occurrences", "activations", "activation_count"])
			var right_activations: float = _numeric_by_keys(right, ["trigger_occurrences", "activations", "activation_count"])
			if not is_equal_approx(left_activations, right_activations):
				return left_activations > right_activations
		ITEM_SORT_ACQUIRED:
			var left_round: float = _numeric_by_keys(left, ["round_acquired", "acquired_round"], 999999.0)
			var right_round: float = _numeric_by_keys(right, ["round_acquired", "acquired_round"], 999999.0)
			if not is_equal_approx(left_round, right_round):
				return left_round < right_round
		ITEM_SORT_NAME:
			return _item_name(left).nocasecmp_to(_item_name(right)) < 0
		_:
			var left_uplift: float = _numeric_by_keys(left, ["final_score_uplift", "marginal_score_uplift", "score_uplift"])
			var right_uplift: float = _numeric_by_keys(right, ["final_score_uplift", "marginal_score_uplift", "score_uplift"])
			if not is_equal_approx(left_uplift, right_uplift):
				return left_uplift > right_uplift
	return _item_name(left).nocasecmp_to(_item_name(right)) < 0


func _numeric_by_keys(source: Dictionary, keys: Array, fallback: float = 0.0) -> float:
	var value: Variant = _value_by_keys(source, keys, fallback)
	if value is int or value is float:
		return float(value)
	if value is String and (value as String).is_valid_float():
		return (value as String).to_float()
	return fallback


func _item_name(item: Dictionary) -> String:
	return str(_value_by_keys(item, ["display_name", "label", "item_name", "item_id", "id"], "Unknown Eight Ball"))


func _display_value(value: Variant) -> String:
	if value == null:
		return "-"
	if value is int:
		return _format_integer(int(value))
	if value is float:
		var number: float = float(value)
		if is_equal_approx(number, roundf(number)):
			return _format_integer(int(roundf(number)))
		return "%.2f" % number
	if value is bool:
		return "Yes" if bool(value) else "No"
	if value is Array:
		var parts: PackedStringArray = PackedStringArray()
		for item in value as Array:
			parts.append(str(item))
		return ", ".join(parts) if not parts.is_empty() else "-"
	var text: String = str(value)
	return text if not text.is_empty() else "-"


func _join_values(values: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value in values:
		parts.append(str(value))
	return ", ".join(parts) if not parts.is_empty() else "None"


func _display_percent(source: Dictionary, percent_keys: Array, ratio_keys: Array = []) -> String:
	var percentage: Variant = _value_by_keys(source, percent_keys, null)
	if percentage != null:
		return _format_percent_number(percentage, false)
	var ratio: Variant = _value_by_keys(source, ratio_keys, null)
	if ratio != null:
		return _format_percent_number(ratio, true)
	return "-"


func _format_percent_number(value: Variant, is_ratio: bool) -> String:
	if value is String:
		var text: String = str(value)
		if text.contains("%"):
			return text
		if not text.is_valid_float():
			return text
	var number: float = float(value)
	if is_ratio:
		number *= 100.0
	return "%.1f%%" % number


func _format_integer(value: int) -> String:
	var negative: bool = value < 0
	var digits: String = str(absi(value))
	var grouped: String = ""
	var count: int = 0
	for index in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			grouped = "," + grouped
		grouped = digits.substr(index, 1) + grouped
		count += 1
	return ("-" if negative else "") + grouped


func _format_duration(value: Variant) -> String:
	if value == null:
		return "-"
	return "%s us" % _display_value(value)


func _humanize_identifier(value: String) -> String:
	if value.is_empty():
		return ""
	var words: PackedStringArray = value.replace("-", "_").split("_", false)
	for index in range(words.size()):
		words[index] = words[index].capitalize()
	return " ".join(words)


func _format_balance_summary() -> String:
	var supplied_summary: String = str(_value_by_keys(report_snapshot, ["copy_summary", "summary_text", "discussion_summary"], ""))
	if not supplied_summary.strip_edges().is_empty():
		return supplied_summary
	var summary: Dictionary = _get_run_summary()
	var identity: Dictionary = _get_build_identity()
	var lines: PackedStringArray = PackedStringArray()
	var rounds_reached: String = _display_value(_value_by_keys(summary, ["rounds_reached", "reached_round", "round_number"]))
	var outcome: String = _humanize_identifier(str(_value_by_keys(summary, ["final_outcome", "outcome"], "In Progress")))
	lines.append("Run: Round %s - %s" % [rounds_reached, outcome])
	lines.append("Build: %s" % str(_value_by_keys(identity, ["label", "identity", "name"], "Unformed Build")))
	lines.append("Score: %s" % _display_value(_value_by_keys(summary, ["total_authoritative_score", "total_score"])))
	lines.append("Base Score: %s" % _display_value(_value_by_keys(summary, ["total_base_score_without_build", "total_base_score", "base_score"])))
	var uplift: String = _display_value(_value_by_keys(summary, ["total_build_uplift", "build_uplift"]))
	var uplift_percent: String = _display_percent(summary, ["build_uplift_percentage"], ["build_uplift_ratio"])
	lines.append("Build Uplift: %s%s" % [uplift, " (%s)" % uplift_percent if uplift_percent != "-" else ""])
	var tap_metrics: Dictionary = _get_tap_metrics()
	if not tap_metrics.is_empty():
		lines.append("")
		lines.append("Tap Scoring:")
		lines.append("%s cue-recontact + %s Ball Tap milestones" % [
			_display_value(_value_by_keys(tap_metrics, ["cue_recontact_milestones"])),
			_display_value(_value_by_keys(tap_metrics, ["ball_tap_milestones"])),
		])
		lines.append("%s cue + %s ball score supplied" % [
			_display_value(_value_by_keys(tap_metrics, ["cue_recontact_score_supplied"])),
			_display_value(_value_by_keys(tap_metrics, ["ball_tap_score_supplied"])),
		])

	var items: Array[Dictionary] = _get_item_contributions()
	_sort_item_rows(items)
	for item in items:
		lines.append("")
		lines.append("%s:" % _item_name(item))
		lines.append("%s activations" % _display_value(_value_by_keys(item, ["trigger_occurrences", "activations", "activation_count"])))
		var haul_added: Variant = _value_by_keys(item, ["total_haul_added", "haul_added"], null)
		var mult_added: Variant = _value_by_keys(item, ["total_mult_added", "mult_added"], null)
		var xmult_product: Variant = _value_by_keys(item, ["cumulative_xmult_factor", "cumulative_xmult_factors", "xmult_product"], null)
		if haul_added != null:
			lines.append("+%s Haul" % _display_value(haul_added))
		if mult_added != null:
			lines.append("+%s Mult" % _display_value(mult_added))
		if xmult_product != null:
			lines.append("%s xMult product" % _display_value(xmult_product))
		lines.append("%s marginal score" % _display_value(_value_by_keys(item, ["final_score_uplift", "marginal_score_uplift", "score_uplift"])))

	lines.append("")
	lines.append("Largest Shot:")
	var largest_share: String = _display_percent(summary, ["largest_shot_percentage", "largest_shot_percentage_of_total"], ["largest_shot_ratio", "largest_shot_concentration"])
	lines.append("%s%s" % [
		_display_value(_value_by_keys(summary, ["highest_shot", "largest_shot"])),
		" - %s of run score" % largest_share if largest_share != "-" else "",
	])
	return "\n".join(lines)


func _collect_scalar_lines(source: Dictionary, prefix: String, lines: Array[String], depth: int) -> void:
	if depth > 1 or lines.size() >= 80:
		return
	for key_value in source.keys():
		if lines.size() >= 80:
			return
		var key: String = str(key_value)
		var value: Variant = source[key_value]
		var path: String = key if prefix.is_empty() else "%s.%s" % [prefix, key]
		if value is Dictionary:
			_collect_scalar_lines(value as Dictionary, path, lines, depth + 1)
		elif value is Array:
			if (value as Array).size() <= 8:
				lines.append("%s: %s" % [_humanize_identifier(path), _display_value(value)])
		elif value == null or value is String or value is bool or value is int or value is float:
			lines.append("%s: %s" % [_humanize_identifier(path), _display_value(value)])


func _to_json_safe(value: Variant) -> Variant:
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
	if value is PackedStringArray or value is PackedInt32Array or value is PackedInt64Array or value is PackedFloat32Array or value is PackedFloat64Array:
		var converted_packed_array: Array = []
		for item in value:
			converted_packed_array.append(_to_json_safe(item))
		return converted_packed_array
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is Color:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	return value


func _tsv_cell(value: String) -> String:
	return value.replace("\t", " ").replace("\r", " ").replace("\n", " ")


func _update_copy_button_states() -> void:
	var has_report: bool = not report_snapshot.is_empty()
	copy_summary_button.disabled = not has_report
	copy_json_button.disabled = not has_report
	copy_items_button.disabled = _get_item_contributions().is_empty()
	copy_rounds_button.disabled = _get_round_rows().is_empty()


func _set_status(message: String, is_error: bool = false) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", WARNING_COLOR if is_error else ACCENT_COLOR)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _focus_initial_control() -> void:
	if visible and close_button != null:
		close_button.grab_focus()


func _consume_pointer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()


func _request_close() -> void:
	close_panel()
	close_requested.emit()


func _on_advanced_toggled(enabled: bool) -> void:
	advanced_enabled = enabled
	report_dirty = true
	if visible:
		_refresh_visible_report()


func _on_item_sort_selected(index: int) -> void:
	if item_sort_selector == null or index < 0:
		return
	item_sort_mode = str(item_sort_selector.get_item_metadata(index))
	report_dirty = true
	if visible:
		_refresh_visible_report()
