extends Control
class_name PauseMenu

signal resume_requested
signal end_run_requested
signal debug_panel_toggled(panel_id: String, enabled: bool)
signal debug_wayfinder_current_test_button_toggled(enabled: bool)
signal debug_broadside_attack_test_button_toggled(enabled: bool)
signal debug_force_loose_cargo_contraband_toggled(enabled: bool)
signal debug_loose_cargo_contraband_kind_selected(kind: String)
signal debug_spawn_wood_debris_requested
signal debug_clear_debris_requested
signal debug_obstacle_collision_toggled(enabled: bool)
signal debug_obstacle_collision_draw_toggled(enabled: bool)
signal debug_oath_activate_requested(oath_id: String)
signal debug_oath_clear_requested
signal debug_oath_advance_shot_requested
signal debug_oath_fail_requested(oath_id: String)
signal debug_oath_complete_requested(oath_id: String)
signal debug_back_room_force_available_toggled(enabled: bool)
signal debug_back_room_open_requested
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
# Keep the pause shade above live gameplay HUD siblings.
# Passage completion modal uses higher priority around 79/80.
const PAUSE_MENU_Z_INDEX := 70
const EVENT_TEST_SECTION_TITLE := "Event Test Buttons"
const EVENT_TEST_WAYFINDER_TEXT := "Show Wayfinder Current Test Button"
const EVENT_TEST_BROADSIDE_TEXT := "Show Broadside Attack Test Button"
const EVENT_TEST_FORCE_LOOSE_CARGO_CONTRABAND_TEXT := "Force Loose Cargo Contraband"
const EVENT_TEST_SPAWN_WOOD_DEBRIS_TEXT := "Spawn Wood Debris"
const EVENT_TEST_CLEAR_DEBRIS_TEXT := "Clear Debris"
const EVENT_TEST_OBSTACLE_COLLISION_TEXT := "Enable Debris Collision"
const EVENT_TEST_OBSTACLE_COLLISION_DRAW_TEXT := "Show Debris Collision Shape"
const BACK_ROOM_TEST_SECTION_TITLE := "Back Room Testing"
const BACK_ROOM_TEST_FORCE_AVAILABLE_TEXT := "Force Back Room Available"
const BACK_ROOM_TEST_OPEN_TEXT := "Open Back Room Deal"
const OATH_TEST_SECTION_TITLE := "Oath Testing"
const OATH_TESTING_SELECTOR_ITEMS := [
	{"label": "Oath of Urgency", "oath_id": OathSystem.OATH_OF_URGENCY},
	{"label": "Oath of Isolation", "oath_id": OathSystem.OATH_OF_ISOLATION},
	{"label": "Oath of Sacrifice", "oath_id": OathSystem.OATH_OF_SACRIFICE},
	{"label": "Oath of Humility", "oath_id": OathSystem.OATH_OF_HUMILITY},
]
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
const RUN_STATS_PANEL_SIZE := Vector2(590.0, 1080.0)

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
var spawn_wood_debris_button: Button
var clear_debris_button: Button
var obstacle_collision_check_box: CheckBox
var obstacle_collision_debug_check_box: CheckBox
var back_room_testing_section_label: Label
var force_back_room_available_check_box: CheckBox
var open_back_room_deal_button: Button
var oath_testing_section_label: Label
var oath_testing_selector: OptionButton
var oath_activate_button: Button
var oath_clear_button: Button
var oath_advance_shot_button: Button
var oath_fail_button: Button
var oath_complete_button: Button
var oath_testing_readout_label: Label
var run_stats_button: Button
var run_stats_panel: PanelContainer
var run_stats_back_button: Button
var run_stats_value_labels: Dictionary = {}
var latest_run_stats_snapshot: Dictionary = {}
var run_stats_purchase_history_label: Label
var dev_options_button: Button
var dev_options_title_label: Label
var dev_options_scroll_container: ScrollContainer
var dev_options_scroll_content: VBoxContainer
var dev_options_back_button: Button
var options_button: Button
var options_panel: OptionsMenu
var end_run_button: Button
var end_run_confirm_panel: PanelContainer
var end_run_yes_button: Button
var end_run_cancel_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = PAUSE_MENU_Z_INDEX
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
	_ensure_back_room_testing_controls()
	_ensure_oath_testing_controls()
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
	if not spawn_wood_debris_button.pressed.is_connected(_on_spawn_wood_debris_pressed):
		spawn_wood_debris_button.pressed.connect(_on_spawn_wood_debris_pressed)
	if not clear_debris_button.pressed.is_connected(_on_clear_debris_pressed):
		clear_debris_button.pressed.connect(_on_clear_debris_pressed)
	if not obstacle_collision_check_box.toggled.is_connected(_on_obstacle_collision_toggled):
		obstacle_collision_check_box.toggled.connect(_on_obstacle_collision_toggled)
	if not obstacle_collision_debug_check_box.toggled.is_connected(_on_obstacle_collision_draw_toggled):
		obstacle_collision_debug_check_box.toggled.connect(_on_obstacle_collision_draw_toggled)
	if not force_back_room_available_check_box.toggled.is_connected(_on_back_room_force_available_toggled):
		force_back_room_available_check_box.toggled.connect(_on_back_room_force_available_toggled)
	if not open_back_room_deal_button.pressed.is_connected(_on_open_back_room_deal_pressed):
		open_back_room_deal_button.pressed.connect(_on_open_back_room_deal_pressed)
	if not oath_activate_button.pressed.is_connected(_on_oath_activate_pressed):
		oath_activate_button.pressed.connect(_on_oath_activate_pressed)
	if not oath_clear_button.pressed.is_connected(_on_oath_clear_pressed):
		oath_clear_button.pressed.connect(_on_oath_clear_pressed)
	if not oath_advance_shot_button.pressed.is_connected(_on_oath_advance_shot_pressed):
		oath_advance_shot_button.pressed.connect(_on_oath_advance_shot_pressed)
	if not oath_fail_button.pressed.is_connected(_on_oath_fail_pressed):
		oath_fail_button.pressed.connect(_on_oath_fail_pressed)
	if not oath_complete_button.pressed.is_connected(_on_oath_complete_pressed):
		oath_complete_button.pressed.connect(_on_oath_complete_pressed)
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


func set_oath_debug_snapshot(oath_snapshot: Dictionary, cue_modifier_snapshot: Dictionary = {}) -> void:
	if oath_testing_readout_label == null:
		return

	var active_summary := str(oath_snapshot.get("active_oaths_summary", "None sworn."))
	var suppressed := bool(oath_snapshot.get("cue_modifiers_suppressed", false))
	var modifiers_enabled := bool(cue_modifier_snapshot.get("modifiers_enabled", true))
	oath_testing_readout_label.text = "Active: %s\nCue suppressed: %s\nFinal modifiers enabled: %s" % [
		active_summary,
		"true" if suppressed else "false",
		"true" if modifiers_enabled else "false",
	]


func set_debris_collision_debug_state(enabled: bool) -> void:
	if obstacle_collision_check_box != null:
		obstacle_collision_check_box.set_pressed_no_signal(enabled)


func set_debris_collision_draw_debug_state(enabled: bool) -> void:
	if obstacle_collision_debug_check_box != null:
		obstacle_collision_debug_check_box.set_pressed_no_signal(enabled)


func set_back_room_force_available_debug_state(enabled: bool) -> void:
	if force_back_room_available_check_box != null:
		force_back_room_available_check_box.set_pressed_no_signal(enabled)


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

	for row_value in RunStatsSystem.get_run_stats_rows():
		var row: Dictionary = row_value
		var stat_key := str(row.get("key", ""))
		var name_label := _make_run_stats_name_label(str(row.get("label", "")))
		var value_label := _make_run_stats_value_label()
		run_stats_value_labels[stat_key] = value_label
		stats_grid.add_child(name_label)
		stats_grid.add_child(value_label)

	var history_title_label := _make_run_stats_name_label("Interventions Purchased")
	history_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_title_label.custom_minimum_size = Vector2(0.0, 24.0)
	stack.add_child(history_title_label)

	run_stats_purchase_history_label = Label.new()
	run_stats_purchase_history_label.custom_minimum_size = Vector2(440.0, 86.0)
	run_stats_purchase_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	run_stats_purchase_history_label.add_theme_font_override("font", resume_button.get_theme_font("font"))
	run_stats_purchase_history_label.add_theme_font_size_override("font_size", 17)
	run_stats_purchase_history_label.add_theme_color_override("font_color", Color(0.88, 0.86, 0.76, 0.96))
	run_stats_purchase_history_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.82))
	run_stats_purchase_history_label.add_theme_constant_override("outline_size", 1)
	stack.add_child(run_stats_purchase_history_label)

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
	debug_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	if dev_options_scroll_container == null:
		dev_options_scroll_container = ScrollContainer.new()
		dev_options_scroll_container.name = "DevOptionsScroll"
		dev_options_scroll_container.custom_minimum_size = Vector2(0.0, 500.0)
		dev_options_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dev_options_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dev_options_scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
		debug_section.add_child(dev_options_scroll_container)
		debug_section.move_child(dev_options_scroll_container, 1)

	if dev_options_scroll_content == null:
		dev_options_scroll_content = VBoxContainer.new()
		dev_options_scroll_content.name = "DevOptionsScrollContent"
		dev_options_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dev_options_scroll_content.add_theme_constant_override("separation", 8)
		dev_options_scroll_container.add_child(dev_options_scroll_content)

	_move_dev_options_controls_into_scroll()

	if dev_options_back_button == null:
		dev_options_back_button = _make_pause_button("Back", "DevOptionsBackButton")
		dev_options_back_button.custom_minimum_size = Vector2(0.0, 42.0)
		dev_options_back_button.add_theme_font_size_override("font_size", 18)
		debug_section.add_child(dev_options_back_button)
		dev_options_back_button.pressed.connect(_on_dev_options_back_pressed)
	debug_section.move_child(dev_options_back_button, min(2, debug_section.get_child_count() - 1))


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
	if spawn_wood_debris_button == null:
		spawn_wood_debris_button = _make_event_test_button(EVENT_TEST_SPAWN_WOOD_DEBRIS_TEXT, "SpawnWoodDebrisButton")
		debug_section.add_child(spawn_wood_debris_button)
		debug_section.move_child(spawn_wood_debris_button, 7)
	if clear_debris_button == null:
		clear_debris_button = _make_event_test_button(EVENT_TEST_CLEAR_DEBRIS_TEXT, "ClearDebrisButton")
		debug_section.add_child(clear_debris_button)
		debug_section.move_child(clear_debris_button, 8)
	if obstacle_collision_check_box == null:
		obstacle_collision_check_box = _make_event_test_check_box(EVENT_TEST_OBSTACLE_COLLISION_TEXT)
		obstacle_collision_check_box.set_pressed_no_signal(true)
		debug_section.add_child(obstacle_collision_check_box)
		debug_section.move_child(obstacle_collision_check_box, 9)
	if obstacle_collision_debug_check_box == null:
		obstacle_collision_debug_check_box = _make_event_test_check_box(EVENT_TEST_OBSTACLE_COLLISION_DRAW_TEXT)
		obstacle_collision_debug_check_box.set_pressed_no_signal(false)
		debug_section.add_child(obstacle_collision_debug_check_box)
		debug_section.move_child(obstacle_collision_debug_check_box, 10)
	_move_dev_options_controls_into_scroll()


func _ensure_back_room_testing_controls() -> void:
	if back_room_testing_section_label == null:
		back_room_testing_section_label = Label.new()
		back_room_testing_section_label.text = BACK_ROOM_TEST_SECTION_TITLE
		_apply_debug_section_label_style(back_room_testing_section_label)
		debug_section.add_child(back_room_testing_section_label)

	if force_back_room_available_check_box == null:
		force_back_room_available_check_box = _make_event_test_check_box(BACK_ROOM_TEST_FORCE_AVAILABLE_TEXT)
		force_back_room_available_check_box.tooltip_text = "Debug-only: bypasses only the Back Room refresh-cost unlock threshold."
		debug_section.add_child(force_back_room_available_check_box)

	if open_back_room_deal_button == null:
		open_back_room_deal_button = _make_event_test_button(BACK_ROOM_TEST_OPEN_TEXT, "OpenBackRoomDealButton")
		open_back_room_deal_button.tooltip_text = "Debug-only: opens the live Back Room Deal panel."
		debug_section.add_child(open_back_room_deal_button)

	_move_dev_options_controls_into_scroll()


func _ensure_oath_testing_controls() -> void:
	if oath_testing_section_label == null:
		oath_testing_section_label = Label.new()
		oath_testing_section_label.text = OATH_TEST_SECTION_TITLE
		_apply_debug_section_label_style(oath_testing_section_label)
		debug_section.add_child(oath_testing_section_label)

	if oath_testing_selector == null:
		oath_testing_selector = _make_oath_testing_selector()
		debug_section.add_child(oath_testing_selector)

	if oath_activate_button == null:
		oath_activate_button = _make_event_test_button("Activate Selected Oath", "ActivateSelectedOathButton")
		debug_section.add_child(oath_activate_button)

	if oath_advance_shot_button == null:
		oath_advance_shot_button = _make_event_test_button("Advance Oath Shot", "AdvanceOathShotButton")
		oath_advance_shot_button.tooltip_text = "Debug-only: decrements Oath timers without taking a gameplay shot."
		debug_section.add_child(oath_advance_shot_button)

	if oath_fail_button == null:
		oath_fail_button = _make_event_test_button("Fail Active Oath", "FailActiveOathButton")
		debug_section.add_child(oath_fail_button)

	if oath_complete_button == null:
		oath_complete_button = _make_event_test_button("Complete Active Oath", "CompleteActiveOathButton")
		debug_section.add_child(oath_complete_button)

	if oath_clear_button == null:
		oath_clear_button = _make_event_test_button("Clear Active Oaths", "ClearActiveOathsButton")
		debug_section.add_child(oath_clear_button)

	if oath_testing_readout_label == null:
		oath_testing_readout_label = Label.new()
		oath_testing_readout_label.name = "OathTestingReadout"
		oath_testing_readout_label.custom_minimum_size = Vector2(260.0, 72.0)
		oath_testing_readout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		oath_testing_readout_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.84, 0.96))
		oath_testing_readout_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.03, 0.82))
		oath_testing_readout_label.add_theme_constant_override("outline_size", 1)
		oath_testing_readout_label.add_theme_font_override("font", core_performance_check_box.get_theme_font("font"))
		oath_testing_readout_label.add_theme_font_size_override("font_size", 13)
		debug_section.add_child(oath_testing_readout_label)
		set_oath_debug_snapshot({})
	_move_dev_options_controls_into_scroll()


func _move_dev_options_controls_into_scroll() -> void:
	if dev_options_scroll_content == null or dev_options_scroll_container == null:
		return

	var children := debug_section.get_children().duplicate()
	for child in children:
		if child == dev_options_title_label:
			continue
		if child == dev_options_scroll_container:
			continue
		if child == dev_options_back_button:
			continue
		debug_section.remove_child(child)
		dev_options_scroll_content.add_child(child)


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


func _make_oath_testing_selector() -> OptionButton:
	var selector := OptionButton.new()
	selector.name = "OathTestingSelector"
	selector.mouse_filter = Control.MOUSE_FILTER_STOP
	selector.focus_mode = Control.FOCUS_ALL
	selector.custom_minimum_size = Vector2(260.0, 34.0)
	selector.tooltip_text = "Debug-only Oath selection."
	selector.add_theme_color_override("font_color", Color(0.9, 0.95, 0.97, 1.0))
	selector.add_theme_font_override("font", core_performance_check_box.get_theme_font("font"))
	selector.add_theme_font_size_override("font_size", 14)
	_populate_oath_testing_selector(selector)
	return selector


func _make_event_test_button(text: String, button_name: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(260.0, 34.0)
	button.add_theme_color_override("font_color", Color(0.95, 0.88, 0.62, 1.0))
	button.add_theme_font_override("font", core_performance_check_box.get_theme_font("font"))
	button.add_theme_font_size_override("font_size", 14)
	return button


func _populate_loose_cargo_contraband_selector(selector: OptionButton) -> void:
	selector.clear()
	for item_value in DEBUG_CONTRABAND_SELECTOR_ITEMS:
		var item: Dictionary = item_value
		var item_index := selector.get_item_count()
		selector.add_item(str(item.get("label", "Random")))
		selector.set_item_metadata(item_index, str(item.get("kind", DEBUG_CONTRABAND_KIND_RANDOM)))
	selector.select(0)


func _populate_oath_testing_selector(selector: OptionButton) -> void:
	selector.clear()
	for item_value in OATH_TESTING_SELECTOR_ITEMS:
		var item: Dictionary = item_value
		var item_index := selector.get_item_count()
		selector.add_item(str(item.get("label", "Oath")))
		selector.set_item_metadata(item_index, str(item.get("oath_id", "")))
	selector.select(0)


func _get_selected_loose_cargo_contraband_kind() -> String:
	if loose_cargo_contraband_selector == null:
		return DEBUG_CONTRABAND_KIND_RANDOM
	var selected_index := loose_cargo_contraband_selector.selected
	if selected_index < 0 or selected_index >= loose_cargo_contraband_selector.get_item_count():
		return DEBUG_CONTRABAND_KIND_RANDOM
	return str(loose_cargo_contraband_selector.get_item_metadata(selected_index))


func _get_selected_debug_oath_id() -> String:
	if oath_testing_selector == null:
		return OathSystem.OATH_OF_URGENCY
	var selected_index := oath_testing_selector.selected
	if selected_index < 0 or selected_index >= oath_testing_selector.get_item_count():
		return OathSystem.OATH_OF_URGENCY
	return str(oath_testing_selector.get_item_metadata(selected_index))


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

	for row_value in RunStatsSystem.get_run_stats_rows():
		var row: Dictionary = row_value
		var stat_key := str(row.get("key", ""))
		var value_label: Label = run_stats_value_labels.get(stat_key) as Label
		if value_label == null:
			continue
		value_label.text = _format_run_stats_value(stat_key, latest_run_stats_snapshot.get(stat_key, 0))
	if run_stats_purchase_history_label != null:
		run_stats_purchase_history_label.text = _format_intervention_purchase_history(
			latest_run_stats_snapshot.get("intervention_purchase_history", [])
		)


func _format_run_stats_value(stat_key: String, value: Variant) -> String:
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


func _on_spawn_wood_debris_pressed() -> void:
	debug_spawn_wood_debris_requested.emit()


func _on_clear_debris_pressed() -> void:
	debug_clear_debris_requested.emit()


func _on_obstacle_collision_toggled(enabled: bool) -> void:
	debug_obstacle_collision_toggled.emit(enabled)


func _on_obstacle_collision_draw_toggled(enabled: bool) -> void:
	debug_obstacle_collision_draw_toggled.emit(enabled)


func _on_back_room_force_available_toggled(enabled: bool) -> void:
	debug_back_room_force_available_toggled.emit(enabled)


func _on_open_back_room_deal_pressed() -> void:
	debug_back_room_open_requested.emit()


func _on_oath_activate_pressed() -> void:
	debug_oath_activate_requested.emit(_get_selected_debug_oath_id())


func _on_oath_clear_pressed() -> void:
	debug_oath_clear_requested.emit()


func _on_oath_advance_shot_pressed() -> void:
	debug_oath_advance_shot_requested.emit()


func _on_oath_fail_pressed() -> void:
	debug_oath_fail_requested.emit(_get_selected_debug_oath_id())


func _on_oath_complete_pressed() -> void:
	debug_oath_complete_requested.emit(_get_selected_debug_oath_id())


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
