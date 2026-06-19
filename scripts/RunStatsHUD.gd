extends Control
class_name RunStatsHUD

# Top-left current-run ledger overlay. RunStatsSystem owns the numbers; this
# node only presents snapshots and consumes clicks inside its own controls.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const BUTTON_SIZE := Vector2(56.0, 42.0)
const PANEL_SIZE := Vector2(420.0, 995.0)
const PANEL_OFFSET := Vector2(0.0, 50.0)
const ROOT_SIZE := Vector2(450.0, 1085.0)
const ROWS := [
	{"label": "Doubloons Earned", "key": "doubloons_earned"},
	{"label": "Doubloons Lost", "key": "doubloons_lost"},
	{"label": "Passage Remaining", "key": "remaining_passage"},
	{"label": "Kraken Wants", "key": "current_kraken_request"},
	{"label": "Request Reward Bonus", "key": "request_reward_multiplier_bonus_summary"},
	{"label": "Active Oaths", "key": "active_oaths_summary"},
	{"label": "Oath Penalty Cut", "key": "oath_passage_penalty_reduction_summary"},
	{"label": "Cue", "key": "cue_body"},
	{"label": "Tip", "key": "cue_tip"},
	{"label": "Grip", "key": "cue_grip"},
	{"label": "Ferrule", "key": "cue_ferrule"},
	{"label": "Chalk", "key": "cue_chalk"},
	{"label": "Cue Mods", "key": "active_cue_modifiers_summary"},
	{"label": "Cue Power Bonus", "key": "cue_power_bonus_summary"},
	{"label": "Loose Contraband", "key": "loose_cargo_contraband_chance_summary"},
	{"label": "QM Shot Cooldown", "key": "quartermaster_refresh_decay_summary"},
	{"label": "Shots Taken", "key": "shots_taken"},
	{"label": "Balls Sunk", "key": "balls_sunk"},
	{"label": "Highest Pocket Streak", "key": "highest_pocket_streak"},
	{"label": "Interventions Triggered", "key": "interventions_triggered"},
	{"label": "Shop Refreshes", "key": "quartermaster_refreshes_used"},
	{"label": "Refresh Doubloons", "key": "quartermaster_refresh_doubloons_spent"},
	{"label": "Back Room Deals", "key": "back_room_deals_made"},
	{"label": "Back Room Doubloons", "key": "back_room_deal_doubloons_spent"},
	{"label": "Request Rerolls", "key": "kraken_request_rerolls_used"},
	{"label": "Reroll Passage Added", "key": "passage_added_by_request_rerolls"},
	{"label": "Contraband Found", "key": "contraband_found"},
	{"label": "Treasure Claimed", "key": "treasure_claimed"},
	{"label": "Current Ball Count", "key": "current_ball_count"},
	{"label": "Run Time", "key": "run_time_seconds"},
]

var run_stats_system: RunStatsSystem
var ledger_button: Button
var stats_panel: PanelContainer
var close_button: Button
var value_labels: Dictionary = {}
var latest_snapshot: Dictionary = {}
var intervention_history_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size = ROOT_SIZE
	custom_minimum_size = ROOT_SIZE
	_build_button()
	_build_panel()
	set_run_stats_snapshot({})


func setup(stats_system: RunStatsSystem) -> void:
	if run_stats_system != null and run_stats_system.run_stats_changed.is_connected(_on_run_stats_changed):
		run_stats_system.run_stats_changed.disconnect(_on_run_stats_changed)

	run_stats_system = stats_system
	if run_stats_system == null:
		set_run_stats_snapshot({})
		return

	if not run_stats_system.run_stats_changed.is_connected(_on_run_stats_changed):
		run_stats_system.run_stats_changed.connect(_on_run_stats_changed)
	set_run_stats_snapshot(run_stats_system.get_run_stats_snapshot())


func set_run_stats_snapshot(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot.duplicate(true)
	_update_values()


func close_panel() -> void:
	if stats_panel != null:
		stats_panel.visible = false
	if ledger_button != null:
		ledger_button.button_pressed = false


func _build_button() -> void:
	ledger_button = Button.new()
	ledger_button.name = "RunStatsLedgerButton"
	ledger_button.text = "LOG"
	ledger_button.tooltip_text = "Run Stats"
	ledger_button.position = Vector2.ZERO
	ledger_button.size = BUTTON_SIZE
	ledger_button.custom_minimum_size = BUTTON_SIZE
	ledger_button.mouse_filter = Control.MOUSE_FILTER_STOP
	ledger_button.focus_mode = Control.FOCUS_NONE
	ledger_button.toggle_mode = true
	ledger_button.add_theme_font_override("font", UI_FONT)
	ledger_button.add_theme_font_size_override("font_size", 17)
	ledger_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	ledger_button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.72, 1.0))
	ledger_button.add_theme_color_override("font_pressed_color", Color(0.45, 0.9, 0.86, 1.0))
	ledger_button.add_theme_stylebox_override("normal", _make_panel_style(0.58, 0.34))
	ledger_button.add_theme_stylebox_override("hover", _make_panel_style(0.74, 0.74))
	ledger_button.add_theme_stylebox_override("pressed", _make_panel_style(0.78, 0.88, Color(0.34, 0.92, 0.86, 0.82)))
	ledger_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(ledger_button)
	ledger_button.pressed.connect(_on_ledger_button_pressed)


func _build_panel() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.name = "RunStatsOverlayPanel"
	stats_panel.visible = false
	stats_panel.position = PANEL_OFFSET
	stats_panel.size = PANEL_SIZE
	stats_panel.custom_minimum_size = PANEL_SIZE
	stats_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_panel.add_theme_stylebox_override("panel", _make_panel_style(0.88, 0.66))
	add_child(stats_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	stats_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	stack.add_child(title_row)

	var title_label := Label.new()
	title_label.text = "Run Stats"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_override("font", UI_FONT)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	title_label.add_theme_constant_override("outline_size", 2)
	title_row.add_child(title_label)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.tooltip_text = "Close"
	close_button.custom_minimum_size = Vector2(34.0, 30.0)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_override("font", UI_FONT)
	close_button.add_theme_font_size_override("font_size", 15)
	close_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	close_button.add_theme_stylebox_override("normal", _make_panel_style(0.32, 0.24))
	close_button.add_theme_stylebox_override("hover", _make_panel_style(0.52, 0.62))
	close_button.add_theme_stylebox_override("pressed", _make_panel_style(0.68, 0.8, Color(0.34, 0.92, 0.86, 0.82)))
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	title_row.add_child(close_button)
	close_button.pressed.connect(close_panel)

	var subtitle_label := Label.new()
	subtitle_label.text = "Current Run Ledger"
	subtitle_label.add_theme_font_override("font", UI_FONT)
	subtitle_label.add_theme_font_size_override("font_size", 14)
	subtitle_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.76, 0.94))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	subtitle_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(subtitle_label)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 5)
	stack.add_child(stats_grid)

	for row_value in ROWS:
		var row: Dictionary = row_value
		var stat_key := str(row.get("key", ""))
		stats_grid.add_child(_make_name_label(str(row.get("label", ""))))
		var value_label := _make_value_label()
		value_labels[stat_key] = value_label
		stats_grid.add_child(value_label)

	var history_title_label := Label.new()
	history_title_label.text = "Interventions Purchased"
	history_title_label.add_theme_font_override("font", UI_FONT)
	history_title_label.add_theme_font_size_override("font_size", 16)
	history_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	history_title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	history_title_label.add_theme_constant_override("outline_size", 2)
	stack.add_child(history_title_label)

	intervention_history_label = Label.new()
	intervention_history_label.custom_minimum_size = Vector2(300.0, 82.0)
	intervention_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intervention_history_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intervention_history_label.add_theme_font_override("font", UI_FONT)
	intervention_history_label.add_theme_font_size_override("font_size", 14)
	intervention_history_label.add_theme_color_override("font_color", Color(0.86, 0.84, 0.72, 0.96))
	intervention_history_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	intervention_history_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(intervention_history_label)


func _make_name_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(170.0, 20.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.84, 0.83, 0.72, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _make_value_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(174.0, 20.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.01, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _make_panel_style(fill_alpha: float, border_alpha: float, border_color: Color = Color(0.96, 0.78, 0.34, 1.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.026, 0.018, fill_alpha)
	style.border_color = Color(border_color.r, border_color.g, border_color.b, border_alpha)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _update_values() -> void:
	if value_labels.is_empty():
		return

	for row_value in ROWS:
		var row: Dictionary = row_value
		var stat_key := str(row.get("key", ""))
		var value_label: Label = value_labels.get(stat_key) as Label
		if value_label == null:
			continue
		value_label.text = _format_value(stat_key, latest_snapshot.get(stat_key, 0))
	if intervention_history_label != null:
		intervention_history_label.text = _format_intervention_purchase_history(
			latest_snapshot.get("intervention_purchase_history", [])
		)


func _format_value(stat_key: String, value: Variant) -> String:
	match stat_key:
		"highest_pocket_streak":
			return "X%s" % maxi(int(value), 1)
		"run_time_seconds":
			return _format_run_time(float(value))
		"current_kraken_request":
			var request_text := str(value)
			return "None" if request_text.is_empty() else request_text
		"active_oaths_summary":
			var oath_text := str(value)
			return "None sworn." if oath_text.is_empty() else oath_text
		"cue_body", "cue_tip", "cue_grip", "cue_ferrule", "cue_chalk":
			var cue_text := str(value)
			return "Unknown" if cue_text.is_empty() else cue_text
		"active_cue_modifiers_summary", "cue_power_bonus_summary", "loose_cargo_contraband_chance_summary", "quartermaster_refresh_decay_summary", "oath_passage_penalty_reduction_summary", "request_reward_multiplier_bonus_summary":
			var modifier_text := str(value)
			return "None" if modifier_text.is_empty() else modifier_text
	return str(maxi(int(value), 0))


func _format_run_time(seconds_value: float) -> String:
	var total_seconds := maxi(int(floor(seconds_value)), 0)
	var hours := int(total_seconds / 3600)
	var minutes := int((total_seconds % 3600) / 60)
	var seconds := total_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func _format_intervention_purchase_history(value: Variant) -> String:
	if not value is Array:
		return "None purchased yet."

	var lines: Array = []
	for record_value in value:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		var name := str(record.get("name", "Intervention"))
		var count := maxi(int(record.get("count", 0)), 0)
		var total_cost := maxi(int(record.get("total_cost", 0)), 0)
		if count <= 0:
			continue
		if count > 1:
			lines.append("%s x%s - %s total" % [name, count, total_cost])
		else:
			lines.append("%s - %s" % [name, total_cost])

	if lines.is_empty():
		return "None purchased yet."
	return "\n".join(lines)


func _on_run_stats_changed(snapshot: Dictionary) -> void:
	set_run_stats_snapshot(snapshot)


func _on_ledger_button_pressed() -> void:
	stats_panel.visible = ledger_button.button_pressed
