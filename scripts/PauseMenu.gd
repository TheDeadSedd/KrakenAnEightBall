extends Control
class_name PauseMenu

signal resume_requested
signal end_run_requested
signal debug_panel_toggled(panel_id: String, enabled: bool)
signal debug_wayfinder_current_test_button_toggled(enabled: bool)
signal debug_broadside_attack_test_button_toggled(enabled: bool)
signal debug_force_loose_cargo_contraband_toggled(enabled: bool)
signal debug_loose_cargo_contraband_kind_selected(kind: String)
signal quartermaster_cancel_placement_requested

const PANEL_CORE_PERFORMANCE := "core_performance"
const PANEL_AIM_PREVIEW := "aim_preview"
const PANEL_TREASURE := "treasure"
const PANEL_ANCHOR := "anchor"
const PANEL_BALL_DROPS_SCORE := "ball_drops_score"
const PANEL_CANNON := "cannon"
const PANEL_POWDER_KEG_WAYFINDER := "powder_keg_wayfinder"
const PANEL_VISUAL_EFFECTS := "visual_effects"
const PANEL_PHYSICS := "physics"
const PANEL_EMBEZZLER := "embezzler"
const NORMAL_SHADE_COLOR := Color(0.01, 0.012, 0.016, 0.62)
const PLACEMENT_SHADE_COLOR := Color(0.01, 0.012, 0.016, 0.18)
const EVENT_TEST_SECTION_TITLE := "Event Test Buttons"
const EVENT_TEST_WAYFINDER_TEXT := "Show Wayfinder Current Test Button"
const EVENT_TEST_BROADSIDE_TEXT := "Show Broadside Attack Test Button"
const EVENT_TEST_FORCE_LOOSE_CARGO_CONTRABAND_TEXT := "Force Loose Cargo Contraband"
const DEV_OPTIONS_TITLE_TEXT := "Dev Options"
const RUN_STATS_TITLE_TEXT := "Run Stats"
const RUN_STATS_SUBTITLE_TEXT := "Current Run Ledger"
const DEBUG_CONTRABAND_KIND_RANDOM := "random"
const DEBUG_CONTRABAND_SELECTOR_ITEMS := [
	{"label": "Random", "kind": DEBUG_CONTRABAND_KIND_RANDOM},
	{"label": "Wayfinder", "kind": "wayfinder"},
	{"label": "Powder Keg", "kind": "powder_keg"},
	{"label": "Treasure", "kind": "treasure"},
	{"label": "Cannon", "kind": "cannon"},
	{"label": "Embezzler", "kind": "embezzler"},
]
const OPTIONS_MENU_SCRIPT := preload("res://scripts/OptionsMenu.gd")
const CONFIRM_PANEL_SIZE := Vector2(430.0, 220.0)
const RUN_STATS_PANEL_SIZE := Vector2(520.0, 430.0)
const RUN_STATS_ROWS := [
	{"label": "Doubloons Earned", "key": "doubloons_earned"},
	{"label": "Balls Sunk", "key": "balls_sunk"},
	{"label": "Highest Pocket Streak", "key": "highest_pocket_streak"},
	{"label": "Interventions Triggered", "key": "interventions_triggered"},
	{"label": "Contraband Found", "key": "contraband_found"},
	{"label": "Treasure Claimed", "key": "treasure_claimed"},
	{"label": "Current Ball Count", "key": "current_ball_count"},
	{"label": "Run Time", "key": "run_time_seconds"},
]

@onready var shade: ColorRect = $Shade
@onready var menu_panel: PanelContainer = $Shade/MenuPanel
@onready var menu_stack: VBoxContainer = $Shade/MenuPanel/Margin/VBox
@onready var resume_button: Button = $Shade/MenuPanel/Margin/VBox/ResumeButton
@onready var tab_bar: HBoxContainer = $Shade/MenuPanel/Margin/VBox/TabBar
@onready var quartermaster_tab_button: Button = $Shade/MenuPanel/Margin/VBox/TabBar/QuartermasterTabButton
@onready var debug_tab_button: Button = $Shade/MenuPanel/Margin/VBox/TabBar/DebugTabButton
@onready var quartermaster_section: VBoxContainer = $Shade/MenuPanel/Margin/VBox/QuartermasterSection
@onready var debug_section: VBoxContainer = $Shade/MenuPanel/Margin/VBox/DebugSection
@onready var placement_hint_panel: PanelContainer = $Shade/PlacementHintPanel
@onready var placement_hint_label: Label = $Shade/PlacementHintPanel/Margin/VBox/PlacementHintLabel
@onready var cancel_placement_button: Button = $Shade/PlacementHintPanel/Margin/VBox/CancelPlacementButton
@onready var core_performance_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/CorePerformancePanelCheckBox
@onready var aim_preview_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/AimPreviewPanelCheckBox
@onready var treasure_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/TreasurePanelCheckBox
@onready var embezzler_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/EmbezzlerPanelCheckBox
@onready var anchor_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/AnchorPanelCheckBox
@onready var ball_drops_score_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/BallDropsScorePanelCheckBox
@onready var cannon_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/CannonPanelCheckBox
@onready var powder_keg_wayfinder_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/PowderKegWayfinderPanelCheckBox
@onready var visual_effects_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/VisualEffectsPanelCheckBox
@onready var physics_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/PhysicsPerformancePanelCheckBox

var event_test_section_label: Label
var wayfinder_current_test_check_box: CheckBox
var broadside_attack_test_check_box: CheckBox
var force_loose_cargo_contraband_check_box: CheckBox
var loose_cargo_contraband_selector: OptionButton
var run_stats_button: Button
var run_stats_panel: PanelContainer
var run_stats_back_button: Button
var run_stats_value_labels: Dictionary = {}
var latest_run_stats_snapshot: Dictionary = {}
var dev_options_button: Button
var dev_options_title_label: Label
var dev_options_back_button: Button
var options_button: Button
var options_panel: OptionsMenu
var end_run_button: Button
var end_run_confirm_panel: PanelContainer
var end_run_yes_button: Button
var end_run_cancel_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	placement_hint_panel.visible = false
	_retire_quartermaster_menu_ui()
	if not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if not debug_tab_button.pressed.is_connected(_show_debug_tab):
		debug_tab_button.pressed.connect(_show_debug_tab)
	if not cancel_placement_button.pressed.is_connected(_on_cancel_placement_pressed):
		cancel_placement_button.pressed.connect(_on_cancel_placement_pressed)
	_ensure_options_controls()
	_ensure_run_stats_controls()
	_ensure_dev_options_controls()
	_ensure_end_run_controls()
	_ensure_event_test_controls()
	_connect_debug_panel_toggles()
	_show_pause_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_options_panel_layout()
		_update_run_stats_panel_layout()
		_update_end_run_confirm_layout()


func _retire_quartermaster_menu_ui() -> void:
	tab_bar.visible = false
	quartermaster_tab_button.visible = false
	quartermaster_tab_button.disabled = true
	quartermaster_section.visible = false
	debug_tab_button.visible = false
	debug_tab_button.disabled = true
	debug_section.visible = false


func _connect_debug_panel_toggles() -> void:
	if not wayfinder_current_test_check_box.toggled.is_connected(_on_wayfinder_current_test_button_toggled):
		wayfinder_current_test_check_box.toggled.connect(_on_wayfinder_current_test_button_toggled)
	if not broadside_attack_test_check_box.toggled.is_connected(_on_broadside_attack_test_button_toggled):
		broadside_attack_test_check_box.toggled.connect(_on_broadside_attack_test_button_toggled)
	if not force_loose_cargo_contraband_check_box.toggled.is_connected(_on_force_loose_cargo_contraband_toggled):
		force_loose_cargo_contraband_check_box.toggled.connect(_on_force_loose_cargo_contraband_toggled)
	if not loose_cargo_contraband_selector.item_selected.is_connected(_on_loose_cargo_contraband_kind_selected):
		loose_cargo_contraband_selector.item_selected.connect(_on_loose_cargo_contraband_kind_selected)
	if not core_performance_check_box.toggled.is_connected(_on_core_performance_panel_toggled):
		core_performance_check_box.toggled.connect(_on_core_performance_panel_toggled)
	if not aim_preview_check_box.toggled.is_connected(_on_aim_preview_panel_toggled):
		aim_preview_check_box.toggled.connect(_on_aim_preview_panel_toggled)
	if not treasure_check_box.toggled.is_connected(_on_treasure_panel_toggled):
		treasure_check_box.toggled.connect(_on_treasure_panel_toggled)
	if not embezzler_check_box.toggled.is_connected(_on_embezzler_panel_toggled):
		embezzler_check_box.toggled.connect(_on_embezzler_panel_toggled)
	if not anchor_check_box.toggled.is_connected(_on_anchor_panel_toggled):
		anchor_check_box.toggled.connect(_on_anchor_panel_toggled)
	if not ball_drops_score_check_box.toggled.is_connected(_on_ball_drops_score_panel_toggled):
		ball_drops_score_check_box.toggled.connect(_on_ball_drops_score_panel_toggled)
	if not cannon_check_box.toggled.is_connected(_on_cannon_panel_toggled):
		cannon_check_box.toggled.connect(_on_cannon_panel_toggled)
	if not powder_keg_wayfinder_check_box.toggled.is_connected(_on_powder_keg_wayfinder_panel_toggled):
		powder_keg_wayfinder_check_box.toggled.connect(_on_powder_keg_wayfinder_panel_toggled)
	if not visual_effects_check_box.toggled.is_connected(_on_visual_effects_panel_toggled):
		visual_effects_check_box.toggled.connect(_on_visual_effects_panel_toggled)
	if not physics_check_box.toggled.is_connected(_on_physics_panel_toggled):
		physics_check_box.toggled.connect(_on_physics_panel_toggled)


func set_pause_visible(should_show: bool) -> void:
	visible = should_show
	if should_show:
		_show_pause_panel()
		resume_button.grab_focus()
	else:
		if options_panel != null:
			options_panel.visible = false
		if run_stats_panel != null:
			run_stats_panel.visible = false
		if end_run_confirm_panel != null:
			end_run_confirm_panel.visible = false
		if dev_options_back_button != null:
			debug_section.visible = false
		resume_button.release_focus()


func set_quartermaster_placement_mode(enabled: bool, item_name: String = "") -> void:
	if options_panel != null:
		options_panel.visible = false
	if run_stats_panel != null:
		run_stats_panel.visible = false
	if end_run_confirm_panel != null:
		end_run_confirm_panel.visible = false
	menu_panel.visible = not enabled
	placement_hint_panel.visible = enabled
	shade.color = PLACEMENT_SHADE_COLOR if enabled else NORMAL_SHADE_COLOR
	if enabled:
		placement_hint_label.text = "Place %s\nLeft-click a green spot. Right-click or Esc cancels." % item_name
	else:
		placement_hint_label.text = ""


func set_debug_panel_states(panel_states: Dictionary) -> void:
	core_performance_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_CORE_PERFORMANCE, false)))
	aim_preview_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_AIM_PREVIEW, false)))
	treasure_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_TREASURE, false)))
	embezzler_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_EMBEZZLER, false)))
	anchor_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_ANCHOR, false)))
	ball_drops_score_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_BALL_DROPS_SCORE, false)))
	cannon_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_CANNON, false)))
	powder_keg_wayfinder_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_POWDER_KEG_WAYFINDER, false)))
	visual_effects_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_VISUAL_EFFECTS, false)))
	physics_check_box.set_pressed_no_signal(bool(panel_states.get(PANEL_PHYSICS, false)))


func set_run_stats_snapshot(snapshot: Dictionary) -> void:
	latest_run_stats_snapshot = snapshot.duplicate(true)
	_update_run_stats_values()


func _ensure_options_controls() -> void:
	if options_button == null:
		options_button = Button.new()
		options_button.name = "OptionsButton"
		options_button.text = "Options"
		options_button.custom_minimum_size = resume_button.custom_minimum_size
		options_button.mouse_filter = Control.MOUSE_FILTER_STOP
		options_button.focus_mode = Control.FOCUS_ALL
		options_button.add_theme_font_override("font", resume_button.get_theme_font("font"))
		options_button.add_theme_font_size_override("font_size", resume_button.get_theme_font_size("font_size"))
		menu_stack.add_child(options_button)
		menu_stack.move_child(options_button, resume_button.get_index() + 1)
		options_button.pressed.connect(_on_options_pressed)

	if options_panel == null:
		options_panel = OPTIONS_MENU_SCRIPT.new()
		options_panel.name = "OptionsPanel"
		options_panel.visible = false
		options_panel.back_requested.connect(_on_options_back_requested)
		shade.add_child(options_panel)
		_update_options_panel_layout()


func _ensure_run_stats_controls() -> void:
	if run_stats_button == null:
		run_stats_button = _make_pause_button("Run Stats", "RunStatsButton")
		menu_stack.add_child(run_stats_button)
		menu_stack.move_child(run_stats_button, options_button.get_index() + 1)
		run_stats_button.pressed.connect(_on_run_stats_pressed)

	if run_stats_panel == null:
		run_stats_panel = PanelContainer.new()
		run_stats_panel.name = "RunStatsPanel"
		run_stats_panel.visible = false
		run_stats_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		run_stats_panel.add_theme_stylebox_override("panel", menu_panel.get_theme_stylebox("panel"))
		shade.add_child(run_stats_panel)
		_build_run_stats_panel()
		_update_run_stats_panel_layout()


func _build_run_stats_panel() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	run_stats_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = RUN_STATS_TITLE_TEXT
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", resume_button.get_theme_font("font"))
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	title_label.add_theme_constant_override("outline_size", 3)
	stack.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = RUN_STATS_SUBTITLE_TEXT
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_override("font", resume_button.get_theme_font("font"))
	subtitle_label.add_theme_font_size_override("font_size", 17)
	subtitle_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.76, 0.94))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	subtitle_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(subtitle_label)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 28)
	stats_grid.add_theme_constant_override("v_separation", 8)
	stack.add_child(stats_grid)

	for row_value in RUN_STATS_ROWS:
		var row: Dictionary = row_value
		var stat_key := str(row.get("key", ""))
		var name_label := _make_run_stats_name_label(str(row.get("label", "")))
		var value_label := _make_run_stats_value_label()
		run_stats_value_labels[stat_key] = value_label
		stats_grid.add_child(name_label)
		stats_grid.add_child(value_label)

	run_stats_back_button = _make_pause_button("Back", "RunStatsBackButton")
	run_stats_back_button.custom_minimum_size = Vector2(0.0, 44.0)
	run_stats_back_button.add_theme_font_size_override("font_size", 18)
	stack.add_child(run_stats_back_button)
	run_stats_back_button.pressed.connect(_on_run_stats_back_pressed)
	_update_run_stats_values()


func _make_run_stats_name_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(260.0, 24.0)
	label.add_theme_font_override("font", resume_button.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.84, 0.83, 0.72, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	label.add_theme_constant_override("outline_size", 1)
	return label


func _make_run_stats_value_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(136.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_override("font", resume_button.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.01, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _ensure_dev_options_controls() -> void:
	if dev_options_button == null:
		dev_options_button = _make_pause_button("Dev Options", "DevOptionsButton")
		menu_stack.add_child(dev_options_button)
		menu_stack.move_child(dev_options_button, run_stats_button.get_index() + 1)
		dev_options_button.pressed.connect(_on_dev_options_pressed)

	if dev_options_title_label == null:
		dev_options_title_label = Label.new()
		dev_options_title_label.text = DEV_OPTIONS_TITLE_TEXT
		dev_options_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dev_options_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
		dev_options_title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
		dev_options_title_label.add_theme_constant_override("outline_size", 2)
		dev_options_title_label.add_theme_font_override("font", resume_button.get_theme_font("font"))
		dev_options_title_label.add_theme_font_size_override("font_size", 26)
		debug_section.add_child(dev_options_title_label)
		debug_section.move_child(dev_options_title_label, 0)

	if dev_options_back_button == null:
		dev_options_back_button = _make_pause_button("Back", "DevOptionsBackButton")
		dev_options_back_button.custom_minimum_size = Vector2(0.0, 42.0)
		dev_options_back_button.add_theme_font_size_override("font_size", 18)
		debug_section.add_child(dev_options_back_button)
		debug_section.move_child(dev_options_back_button, 1)
		dev_options_back_button.pressed.connect(_on_dev_options_back_pressed)


func _ensure_end_run_controls() -> void:
	if end_run_button == null:
		end_run_button = _make_pause_button("End Run", "EndRunButton")
		menu_stack.add_child(end_run_button)
		menu_stack.move_child(end_run_button, dev_options_button.get_index() + 1)
		end_run_button.pressed.connect(_on_end_run_pressed)

	if end_run_confirm_panel == null:
		end_run_confirm_panel = PanelContainer.new()
		end_run_confirm_panel.name = "EndRunConfirmPanel"
		end_run_confirm_panel.visible = false
		end_run_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		end_run_confirm_panel.add_theme_stylebox_override("panel", menu_panel.get_theme_stylebox("panel"))
		shade.add_child(end_run_confirm_panel)
		_build_end_run_confirmation()
		_update_end_run_confirm_layout()


func _build_end_run_confirmation() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	end_run_confirm_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)

	var title_label := Label.new()
	title_label.text = "End Run?"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_override("font", resume_button.get_theme_font("font"))
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	title_label.add_theme_constant_override("outline_size", 3)
	stack.add_child(title_label)

	var body_label := Label.new()
	body_label.text = "Return to the title screen and abandon this run."
	body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_override("font", resume_button.get_theme_font("font"))
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.76, 1.0))
	body_label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 0.8))
	body_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(body_label)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	stack.add_child(button_row)

	end_run_yes_button = _make_pause_button("Yes", "EndRunYesButton")
	end_run_cancel_button = _make_pause_button("Cancel", "EndRunCancelButton")
	end_run_yes_button.custom_minimum_size = Vector2(132.0, 46.0)
	end_run_cancel_button.custom_minimum_size = Vector2(132.0, 46.0)
	button_row.add_child(end_run_yes_button)
	button_row.add_child(end_run_cancel_button)
	end_run_yes_button.pressed.connect(_on_end_run_confirmed)
	end_run_cancel_button.pressed.connect(_on_end_run_cancelled)


func _make_pause_button(text: String, button_name: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = resume_button.custom_minimum_size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", resume_button.get_theme_font("font"))
	button.add_theme_font_size_override("font_size", resume_button.get_theme_font_size("font_size"))
	return button


func _ensure_event_test_controls() -> void:
	if event_test_section_label == null:
		event_test_section_label = Label.new()
		event_test_section_label.text = EVENT_TEST_SECTION_TITLE
		_apply_debug_section_label_style(event_test_section_label)
		debug_section.add_child(event_test_section_label)
		debug_section.move_child(event_test_section_label, 2)
	if wayfinder_current_test_check_box == null:
		wayfinder_current_test_check_box = _make_event_test_check_box(EVENT_TEST_WAYFINDER_TEXT)
		debug_section.add_child(wayfinder_current_test_check_box)
		debug_section.move_child(wayfinder_current_test_check_box, 3)
	if broadside_attack_test_check_box == null:
		broadside_attack_test_check_box = _make_event_test_check_box(EVENT_TEST_BROADSIDE_TEXT)
		debug_section.add_child(broadside_attack_test_check_box)
		debug_section.move_child(broadside_attack_test_check_box, 4)
	if force_loose_cargo_contraband_check_box == null:
		force_loose_cargo_contraband_check_box = _make_event_test_check_box(EVENT_TEST_FORCE_LOOSE_CARGO_CONTRABAND_TEXT)
		debug_section.add_child(force_loose_cargo_contraband_check_box)
		debug_section.move_child(force_loose_cargo_contraband_check_box, 5)
	if loose_cargo_contraband_selector == null:
		loose_cargo_contraband_selector = _make_loose_cargo_contraband_selector()
		debug_section.add_child(loose_cargo_contraband_selector)
		debug_section.move_child(loose_cargo_contraband_selector, 6)


func _make_event_test_check_box(text: String) -> CheckBox:
	var check_box := CheckBox.new()
	check_box.text = text
	check_box.mouse_filter = Control.MOUSE_FILTER_STOP
	check_box.set_pressed_no_signal(false)
	_apply_debug_check_box_style(check_box)
	return check_box


func _make_loose_cargo_contraband_selector() -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "LooseCargoContrabandSelector"
	selector.mouse_filter = Control.MOUSE_FILTER_STOP
	selector.focus_mode = Control.FOCUS_ALL
	selector.disabled = true
	selector.custom_minimum_size = Vector2(260.0, 34.0)
	selector.tooltip_text = "Debug-only Loose Cargo contraband kind."
	selector.add_theme_color_override("font_color", Color(0.9, 0.95, 0.97, 1.0))
	selector.add_theme_font_override("font", core_performance_check_box.get_theme_font("font"))
	selector.add_theme_font_size_override("font_size", 14)
	_populate_loose_cargo_contraband_selector(selector)
	return selector


func _populate_loose_cargo_contraband_selector(selector: OptionButton) -> void:
	selector.clear()
	for item_value in DEBUG_CONTRABAND_SELECTOR_ITEMS:
		var item: Dictionary = item_value
		var item_index := selector.get_item_count()
		selector.add_item(str(item.get("label", "Random")))
		selector.set_item_metadata(item_index, str(item.get("kind", DEBUG_CONTRABAND_KIND_RANDOM)))
	selector.select(0)


func _get_selected_loose_cargo_contraband_kind() -> String:
	if loose_cargo_contraband_selector == null:
		return DEBUG_CONTRABAND_KIND_RANDOM
	var selected_index := loose_cargo_contraband_selector.selected
	if selected_index < 0 or selected_index >= loose_cargo_contraband_selector.get_item_count():
		return DEBUG_CONTRABAND_KIND_RANDOM
	return str(loose_cargo_contraband_selector.get_item_metadata(selected_index))


func _apply_debug_section_label_style(label: Label) -> void:
	label.add_theme_color_override("font_color", Color(0.76, 0.86, 0.82, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.03, 0.82))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_override("font", core_performance_check_box.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", 15)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _apply_debug_check_box_style(check_box: CheckBox) -> void:
	check_box.add_theme_color_override("font_color", Color(0.9, 0.95, 0.97, 1.0))
	check_box.add_theme_font_override("font", core_performance_check_box.get_theme_font("font"))
	check_box.add_theme_font_size_override("font_size", 14)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()


func _show_pause_panel() -> void:
	if options_panel != null:
		options_panel.visible = false
	if run_stats_panel != null:
		run_stats_panel.visible = false
	if end_run_confirm_panel != null:
		end_run_confirm_panel.visible = false
	resume_button.visible = true
	if options_button != null:
		options_button.visible = true
	if run_stats_button != null:
		run_stats_button.visible = true
	if dev_options_button != null:
		dev_options_button.visible = true
	if end_run_button != null:
		end_run_button.visible = true
	tab_bar.visible = false
	quartermaster_section.visible = false
	debug_section.visible = false
	if not placement_hint_panel.visible:
		menu_panel.visible = true
	shade.color = PLACEMENT_SHADE_COLOR if placement_hint_panel.visible else NORMAL_SHADE_COLOR


func _show_debug_tab() -> void:
	_show_dev_options_panel()


func _show_dev_options_panel() -> void:
	resume_button.visible = false
	if options_button != null:
		options_button.visible = false
	if run_stats_button != null:
		run_stats_button.visible = false
	if dev_options_button != null:
		dev_options_button.visible = false
	if end_run_button != null:
		end_run_button.visible = false
	if options_panel != null:
		options_panel.visible = false
	if run_stats_panel != null:
		run_stats_panel.visible = false
	if end_run_confirm_panel != null:
		end_run_confirm_panel.visible = false
	placement_hint_panel.visible = false
	menu_panel.visible = true
	tab_bar.visible = false
	quartermaster_section.visible = false
	debug_section.visible = true
	quartermaster_tab_button.disabled = true
	debug_tab_button.disabled = true
	shade.color = NORMAL_SHADE_COLOR
	if dev_options_back_button != null:
		dev_options_back_button.grab_focus()


func _update_options_panel_layout() -> void:
	if options_panel == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_width: float = clampf(viewport_size.x * 0.34, 560.0, 700.0)
	var panel_height: float = clampf(viewport_size.y * 0.48, 430.0, 560.0)
	options_panel.anchor_left = 0.5
	options_panel.anchor_right = 0.5
	options_panel.anchor_top = 0.5
	options_panel.anchor_bottom = 0.5
	options_panel.offset_left = -panel_width * 0.5
	options_panel.offset_right = panel_width * 0.5
	options_panel.offset_top = -panel_height * 0.5
	options_panel.offset_bottom = panel_height * 0.5


func _update_run_stats_panel_layout() -> void:
	if run_stats_panel == null:
		return

	run_stats_panel.anchor_left = 0.5
	run_stats_panel.anchor_right = 0.5
	run_stats_panel.anchor_top = 0.5
	run_stats_panel.anchor_bottom = 0.5
	run_stats_panel.offset_left = -RUN_STATS_PANEL_SIZE.x * 0.5
	run_stats_panel.offset_right = RUN_STATS_PANEL_SIZE.x * 0.5
	run_stats_panel.offset_top = -RUN_STATS_PANEL_SIZE.y * 0.5
	run_stats_panel.offset_bottom = RUN_STATS_PANEL_SIZE.y * 0.5


func _update_end_run_confirm_layout() -> void:
	if end_run_confirm_panel == null:
		return

	end_run_confirm_panel.anchor_left = 0.5
	end_run_confirm_panel.anchor_right = 0.5
	end_run_confirm_panel.anchor_top = 0.5
	end_run_confirm_panel.anchor_bottom = 0.5
	end_run_confirm_panel.offset_left = -CONFIRM_PANEL_SIZE.x * 0.5
	end_run_confirm_panel.offset_right = CONFIRM_PANEL_SIZE.x * 0.5
	end_run_confirm_panel.offset_top = -CONFIRM_PANEL_SIZE.y * 0.5
	end_run_confirm_panel.offset_bottom = CONFIRM_PANEL_SIZE.y * 0.5


func _update_run_stats_values() -> void:
	if run_stats_value_labels.is_empty():
		return

	for row_value in RUN_STATS_ROWS:
		var row: Dictionary = row_value
		var stat_key := str(row.get("key", ""))
		var value_label: Label = run_stats_value_labels.get(stat_key) as Label
		if value_label == null:
			continue
		value_label.text = _format_run_stats_value(stat_key, latest_run_stats_snapshot.get(stat_key, 0))


func _format_run_stats_value(stat_key: String, value: Variant) -> String:
	match stat_key:
		"highest_pocket_streak":
			return "X%s" % maxi(int(value), 1)
		"run_time_seconds":
			return _format_run_time(float(value))
	return str(maxi(int(value), 0))


func _format_run_time(seconds_value: float) -> String:
	var total_seconds := maxi(int(floor(seconds_value)), 0)
	var hours := int(total_seconds / 3600)
	var minutes := int((total_seconds % 3600) / 60)
	var seconds := total_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_options_pressed() -> void:
	menu_panel.visible = false
	placement_hint_panel.visible = false
	if run_stats_panel != null:
		run_stats_panel.visible = false
	end_run_confirm_panel.visible = false
	shade.color = NORMAL_SHADE_COLOR
	options_panel.visible = true
	options_panel.refresh_from_audio_settings()
	options_panel.grab_default_focus()


func _on_options_back_requested() -> void:
	options_panel.visible = false
	_show_pause_panel()
	options_button.grab_focus()


func _on_run_stats_pressed() -> void:
	menu_panel.visible = false
	placement_hint_panel.visible = false
	if options_panel != null:
		options_panel.visible = false
	if end_run_confirm_panel != null:
		end_run_confirm_panel.visible = false
	shade.color = NORMAL_SHADE_COLOR
	_update_run_stats_values()
	run_stats_panel.visible = true
	if run_stats_back_button != null:
		run_stats_back_button.grab_focus()


func _on_run_stats_back_pressed() -> void:
	run_stats_panel.visible = false
	_show_pause_panel()
	run_stats_button.grab_focus()


func _on_dev_options_pressed() -> void:
	_show_dev_options_panel()


func _on_dev_options_back_pressed() -> void:
	_show_pause_panel()
	dev_options_button.grab_focus()


func _on_end_run_pressed() -> void:
	menu_panel.visible = false
	placement_hint_panel.visible = false
	options_panel.visible = false
	if run_stats_panel != null:
		run_stats_panel.visible = false
	shade.color = NORMAL_SHADE_COLOR
	end_run_confirm_panel.visible = true
	end_run_cancel_button.grab_focus()


func _on_end_run_confirmed() -> void:
	end_run_requested.emit()


func _on_end_run_cancelled() -> void:
	end_run_confirm_panel.visible = false
	_show_pause_panel()
	end_run_button.grab_focus()


func _on_cancel_placement_pressed() -> void:
	quartermaster_cancel_placement_requested.emit()


func _on_wayfinder_current_test_button_toggled(enabled: bool) -> void:
	debug_wayfinder_current_test_button_toggled.emit(enabled)


func _on_broadside_attack_test_button_toggled(enabled: bool) -> void:
	debug_broadside_attack_test_button_toggled.emit(enabled)


func _on_force_loose_cargo_contraband_toggled(enabled: bool) -> void:
	if loose_cargo_contraband_selector != null:
		loose_cargo_contraband_selector.disabled = not enabled
	debug_force_loose_cargo_contraband_toggled.emit(enabled)
	if enabled:
		debug_loose_cargo_contraband_kind_selected.emit(_get_selected_loose_cargo_contraband_kind())


func _on_loose_cargo_contraband_kind_selected(_index: int) -> void:
	debug_loose_cargo_contraband_kind_selected.emit(_get_selected_loose_cargo_contraband_kind())


func _on_core_performance_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_CORE_PERFORMANCE, enabled)


func _on_aim_preview_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_AIM_PREVIEW, enabled)


func _on_treasure_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_TREASURE, enabled)


func _on_embezzler_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_EMBEZZLER, enabled)


func _on_anchor_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_ANCHOR, enabled)


func _on_ball_drops_score_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_BALL_DROPS_SCORE, enabled)


func _on_cannon_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_CANNON, enabled)


func _on_powder_keg_wayfinder_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_POWDER_KEG_WAYFINDER, enabled)


func _on_visual_effects_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_VISUAL_EFFECTS, enabled)


func _on_physics_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_PHYSICS, enabled)
