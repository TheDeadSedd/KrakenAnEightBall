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
signal debug_pocket_capture_presentation_toggled(enabled: bool)
signal debug_clear_pocket_collections_requested
signal debug_pocket_collection_anchors_toggled(enabled: bool)
signal debug_reflow_pocket_collections_requested
signal debug_oath_activate_requested(oath_id: String)
signal debug_oath_clear_requested
signal debug_oath_advance_shot_requested
signal debug_oath_fail_requested(oath_id: String)
signal debug_oath_complete_requested(oath_id: String)
signal debug_back_room_force_available_toggled(enabled: bool)
signal debug_back_room_open_requested
signal debug_activate_long_sight_requested
signal debug_activate_krakens_patience_requested
signal debug_activate_deep_ledger_requested
signal debug_activate_iron_wake_requested
signal debug_expire_all_boons_requested
signal debug_reserve_stack_payload_requested(payload: Dictionary)
signal debug_sunken_spoils_advance_requested
signal debug_sunken_spoils_trigger_requested
signal debug_sunken_spoils_reset_requested
signal debug_aim_line_toggled(enabled: bool)
signal debug_aim_compare_panels_toggled(enabled: bool)
signal debug_verbose_aim_candidates_toggled(enabled: bool)
signal debug_cue_first_contact_toi_toggled(enabled: bool)
signal debug_cloned_aim_configuration_changed(configuration: Dictionary)
signal debug_force_deep_prediction_requested
signal debug_cancel_pending_deep_prediction_requested
signal debug_reset_aim_profiler_requested
signal debug_reset_aim_benchmark_requested
signal debug_start_aim_benchmark_requested(label: String, preset_label: String)
signal debug_stop_aim_benchmark_requested
signal debug_copy_aim_benchmark_report_requested
signal debug_reset_table_button_toggled(enabled: bool)
signal debug_reset_last_shot_button_toggled(enabled: bool)
signal quartermaster_cancel_placement_requested
signal shot_lab_session_requested(run_suite: bool)

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
# Debug panels use local z-indices through 120. Keep the pause modal above them.
const PAUSE_MENU_Z_INDEX := 200
const EVENT_TEST_SECTION_TITLE := "Event Test Buttons"
const EVENT_TEST_WAYFINDER_TEXT := "Show Wayfinder Current Test Button"
const EVENT_TEST_BROADSIDE_TEXT := "Show Broadside Attack Test Button"
const EVENT_TEST_FORCE_LOOSE_CARGO_CONTRABAND_TEXT := "Force Loose Cargo Contraband"
const EVENT_TEST_SPAWN_WOOD_DEBRIS_TEXT := "Spawn Wood Debris"
const EVENT_TEST_CLEAR_DEBRIS_TEXT := "Clear Debris"
const EVENT_TEST_OBSTACLE_COLLISION_TEXT := "Enable Debris Collision"
const EVENT_TEST_OBSTACLE_COLLISION_DRAW_TEXT := "Show Debris Collision Shape"
const POCKET_CAPTURE_TEST_SECTION_TITLE := "Pocket Capture Presentation"
const POCKET_CAPTURE_TEST_ENABLED_TEXT := "Pocket Capture Presentation"
const POCKET_CAPTURE_TEST_CLEAR_TEXT := "Clear Pocket Collections"
const POCKET_CAPTURE_TEST_ANCHORS_TEXT := "Show Pocket Collection Anchors"
const POCKET_CAPTURE_TEST_REFLOW_TEXT := "Reflow Pocket Collections"
const AIM_PREVIEW_TEST_SECTION_TITLE := "Aim Preview Testing"
const AIM_PREVIEW_TEST_DEBUG_LINE_TEXT := "Debug Aim Line"
const AIM_PREVIEW_TEST_COMPARE_PANELS_TEXT := "Aim Compare Panels"
const AIM_PREVIEW_TEST_VERBOSE_CANDIDATES_TEXT := "Verbose Aim Candidates"
const AIM_PREVIEW_TEST_CUE_TOI_TEXT := "Cue First-Contact TOI"
const AIM_PREVIEW_TEST_RESET_TABLE_TEXT := "Show Reset Table Button"
const AIM_PREVIEW_TEST_RESET_LAST_SHOT_TEXT := "Show Reset Last Shot Button"
const BACK_ROOM_TEST_SECTION_TITLE := "Back Room Testing"
const BACK_ROOM_TEST_FORCE_AVAILABLE_TEXT := "Force Back Room Available"
const BACK_ROOM_TEST_OPEN_TEXT := "Open Back Room Deal"
const BOON_TEST_SECTION_TITLE := "Boon Testing"
const BOON_TEST_ACTIVATE_LONG_SIGHT_TEXT := "Activate Long Sight"
const BOON_TEST_ACTIVATE_KRAKENS_PATIENCE_TEXT := "Activate Kraken's Patience"
const BOON_TEST_ACTIVATE_DEEP_LEDGER_TEXT := "Activate Deep Ledger"
const BOON_TEST_ACTIVATE_IRON_WAKE_TEXT := "Activate Iron Wake"
const BOON_TEST_EXPIRE_ALL_TEXT := "Expire All Boons"
const RESERVE_STACK_TEST_SECTION_TITLE := "Reserve Stack Tests"
const RESERVE_STACK_TEST_ITEMS := [
	{
		"label": "Add Object Ball x3",
		"item_id": "debug_object_ball_x3",
		"item_name": "Loose Object Ball",
		"display_name": "Loose Object Ball",
		"spawn_type": "plain_object_ball",
		"icon_key": "plain_object_ball",
		"quantity": 3,
	},
	{
		"label": "Add Object Ball x10",
		"item_id": "debug_object_ball_x10",
		"item_name": "Loose Object Ball",
		"display_name": "Loose Object Ball",
		"spawn_type": "plain_object_ball",
		"icon_key": "plain_object_ball",
		"quantity": 10,
	},
	{
		"label": "Add Wayfinder x2",
		"item_id": "debug_wayfinder_x2",
		"item_name": "Wayfinder Ball",
		"display_name": "Wayfinder Ball",
		"spawn_type": "wayfinder_ball",
		"icon_key": "wayfinder_ball",
		"quantity": 2,
	},
	{
		"label": "Add Powder Keg x2",
		"item_id": "debug_powder_keg_x2",
		"item_name": "Powder Keg",
		"display_name": "Powder Keg",
		"spawn_type": "powder_keg_ball",
		"icon_key": "powder_keg_ball",
		"quantity": 2,
	},
	{
		"label": "Add Cannon Ball x2",
		"item_id": "debug_cannon_ball_x2",
		"item_name": "Cannon Ball",
		"display_name": "Cannon Ball",
		"spawn_type": "cannon_ball",
		"icon_key": "cannon_ball",
		"quantity": 2,
	},
]
const SUNKEN_SPOILS_TEST_SECTION_TITLE := "Sunken Spoils Testing"
const SUNKEN_SPOILS_TEST_ADVANCE_TEXT := "Advance Spoils Progress +1"
const SUNKEN_SPOILS_TEST_TRIGGER_TEXT := "Trigger Spoils Reward"
const SUNKEN_SPOILS_TEST_RESET_TEXT := "Reset Spoils"
const OATH_TEST_SECTION_TITLE := "Oath Testing"
const OATH_TESTING_SELECTOR_ITEMS := [
	{"label": "Oath of Urgency", "oath_id": OathSystem.OATH_OF_URGENCY},
	{"label": "Oath of Isolation", "oath_id": OathSystem.OATH_OF_ISOLATION},
	{"label": "Oath of Sacrifice", "oath_id": OathSystem.OATH_OF_SACRIFICE},
	{"label": "Oath of Humility", "oath_id": OathSystem.OATH_OF_HUMILITY},
]
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
const AIM_TRAJECTORY_PREDICTOR_SCRIPT := preload("res://scripts/AimTrajectoryPredictor.gd")
const AIM_STAGING_CONFIGURATION_SCRIPT := preload("res://scripts/AimStagingConfiguration.gd")
const DEV_OPTION_REGISTRY_SCRIPT := preload("res://scripts/DevOptionRegistry.gd")
const DEV_OPTIONS_PANEL_SCRIPT := preload("res://scripts/DevOptionsPanel.gd")
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
var pocket_capture_testing_section_label: Label
var pocket_capture_presentation_check_box: CheckBox
var clear_pocket_collections_button: Button
var pocket_collection_anchors_check_box: CheckBox
var reflow_pocket_collections_button: Button
var aim_preview_testing_section_label: Label
var debug_aim_line_check_box: CheckBox
var aim_compare_panels_check_box: CheckBox
var verbose_aim_candidates_check_box: CheckBox
var cue_first_contact_toi_check_box: CheckBox
var reset_table_button_check_box: CheckBox
var reset_last_shot_button_check_box: CheckBox
var cloned_aim_testing_section_label: Label
var cloned_aim_controls: Dictionary = {}
var reset_aim_profiler_button: Button
var selected_aim_benchmark_preset_id := AimTrajectoryPredictor.BENCHMARK_PRESET_LONG_SIGHT_5
var aim_benchmark_label := ""
var back_room_testing_section_label: Label
var force_back_room_available_check_box: CheckBox
var open_back_room_deal_button: Button
var boon_testing_section_label: Label
var activate_long_sight_button: Button
var activate_krakens_patience_button: Button
var activate_deep_ledger_button: Button
var activate_iron_wake_button: Button
var expire_all_boons_button: Button
var reserve_stack_testing_section_label: Label
var reserve_stack_test_buttons: Array = []
var sunken_spoils_testing_section_label: Label
var sunken_spoils_advance_button: Button
var sunken_spoils_trigger_button: Button
var sunken_spoils_reset_button: Button
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
var dev_options_panel: DevOptionsPanel
var dev_option_registry: DevOptionRegistry
var debug_overlay_bridge: DebugOverlay
var ball_audio_system_bridge: BallAudioSystem
var _external_dev_options_registered := false
var _ball_audio_dev_options_registered := false
var options_button: Button
var options_panel: OptionsMenu
var end_run_button: Button
var end_run_confirm_panel: PanelContainer
var end_run_yes_button: Button
var end_run_cancel_button: Button
var shot_lab_entry_confirmation: ConfirmationDialog
var pending_shot_lab_suite := false


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
	_ensure_shot_lab_entry_confirmation()
	_ensure_end_run_controls()
	_ensure_event_test_controls()
	_ensure_pocket_capture_testing_controls()
	_ensure_aim_preview_testing_controls()
	_ensure_back_room_testing_controls()
	_ensure_boon_testing_controls()
	_ensure_reserve_stack_testing_controls()
	_ensure_sunken_spoils_testing_controls()
	_ensure_oath_testing_controls()
	_connect_debug_panel_toggles()
	_register_local_dev_options()
	if dev_options_panel != null:
		dev_options_panel.rebuild_options()
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
	if not pocket_capture_presentation_check_box.toggled.is_connected(_on_pocket_capture_presentation_toggled):
		pocket_capture_presentation_check_box.toggled.connect(_on_pocket_capture_presentation_toggled)
	if not clear_pocket_collections_button.pressed.is_connected(_on_clear_pocket_collections_pressed):
		clear_pocket_collections_button.pressed.connect(_on_clear_pocket_collections_pressed)
	if not pocket_collection_anchors_check_box.toggled.is_connected(_on_pocket_collection_anchors_toggled):
		pocket_collection_anchors_check_box.toggled.connect(_on_pocket_collection_anchors_toggled)
	if not reflow_pocket_collections_button.pressed.is_connected(_on_reflow_pocket_collections_pressed):
		reflow_pocket_collections_button.pressed.connect(_on_reflow_pocket_collections_pressed)
	if not debug_aim_line_check_box.toggled.is_connected(_on_debug_aim_line_toggled):
		debug_aim_line_check_box.toggled.connect(_on_debug_aim_line_toggled)
	if not aim_compare_panels_check_box.toggled.is_connected(_on_aim_compare_panels_toggled):
		aim_compare_panels_check_box.toggled.connect(_on_aim_compare_panels_toggled)
	if not verbose_aim_candidates_check_box.toggled.is_connected(_on_verbose_aim_candidates_toggled):
		verbose_aim_candidates_check_box.toggled.connect(_on_verbose_aim_candidates_toggled)
	if not cue_first_contact_toi_check_box.toggled.is_connected(_on_cue_first_contact_toi_toggled):
		cue_first_contact_toi_check_box.toggled.connect(_on_cue_first_contact_toi_toggled)
	if reset_aim_profiler_button != null and not reset_aim_profiler_button.pressed.is_connected(_on_reset_aim_profiler_pressed):
		reset_aim_profiler_button.pressed.connect(_on_reset_aim_profiler_pressed)
	if not reset_table_button_check_box.toggled.is_connected(_on_reset_table_button_toggled):
		reset_table_button_check_box.toggled.connect(_on_reset_table_button_toggled)
	if not reset_last_shot_button_check_box.toggled.is_connected(_on_reset_last_shot_button_toggled):
		reset_last_shot_button_check_box.toggled.connect(_on_reset_last_shot_button_toggled)
	if not force_back_room_available_check_box.toggled.is_connected(_on_back_room_force_available_toggled):
		force_back_room_available_check_box.toggled.connect(_on_back_room_force_available_toggled)
	if not open_back_room_deal_button.pressed.is_connected(_on_open_back_room_deal_pressed):
		open_back_room_deal_button.pressed.connect(_on_open_back_room_deal_pressed)
	if not activate_long_sight_button.pressed.is_connected(_on_activate_long_sight_pressed):
		activate_long_sight_button.pressed.connect(_on_activate_long_sight_pressed)
	if not activate_krakens_patience_button.pressed.is_connected(_on_activate_krakens_patience_pressed):
		activate_krakens_patience_button.pressed.connect(_on_activate_krakens_patience_pressed)
	if not activate_deep_ledger_button.pressed.is_connected(_on_activate_deep_ledger_pressed):
		activate_deep_ledger_button.pressed.connect(_on_activate_deep_ledger_pressed)
	if not activate_iron_wake_button.pressed.is_connected(_on_activate_iron_wake_pressed):
		activate_iron_wake_button.pressed.connect(_on_activate_iron_wake_pressed)
	if not expire_all_boons_button.pressed.is_connected(_on_expire_all_boons_pressed):
		expire_all_boons_button.pressed.connect(_on_expire_all_boons_pressed)
	if not sunken_spoils_advance_button.pressed.is_connected(_on_sunken_spoils_advance_pressed):
		sunken_spoils_advance_button.pressed.connect(_on_sunken_spoils_advance_pressed)
	if not sunken_spoils_trigger_button.pressed.is_connected(_on_sunken_spoils_trigger_pressed):
		sunken_spoils_trigger_button.pressed.connect(_on_sunken_spoils_trigger_pressed)
	if not sunken_spoils_reset_button.pressed.is_connected(_on_sunken_spoils_reset_pressed):
		sunken_spoils_reset_button.pressed.connect(_on_sunken_spoils_reset_pressed)
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
		if dev_options_panel != null:
			dev_options_panel.close_panel()
		if options_panel != null:
			options_panel.visible = false
		if run_stats_panel != null:
			run_stats_panel.visible = false
		if end_run_confirm_panel != null:
			end_run_confirm_panel.visible = false
		debug_section.visible = false
		resume_button.release_focus()


func set_quartermaster_placement_mode(enabled: bool, item_name: String = "") -> void:
	if dev_options_panel != null:
		dev_options_panel.close_panel()
	shade.visible = true
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


func is_dev_options_open() -> bool:
	return dev_options_panel != null and dev_options_panel.is_open()


func close_dev_options_to_pause() -> void:
	if is_dev_options_open():
		_on_dev_options_back_pressed()


func handle_dev_options_cancel_request() -> void:
	if not is_dev_options_open():
		return
	if dev_options_panel != null and dev_options_panel.handle_cancel_request():
		return
	_on_dev_options_back_pressed()


func configure_dev_options_debug_overlay(overlay: DebugOverlay) -> void:
	if debug_overlay_bridge != null and debug_overlay_bridge.dev_option_state_changed.is_connected(_on_debug_overlay_dev_option_changed):
		debug_overlay_bridge.dev_option_state_changed.disconnect(_on_debug_overlay_dev_option_changed)
	debug_overlay_bridge = overlay
	if debug_overlay_bridge == null:
		return
	if not debug_overlay_bridge.dev_option_state_changed.is_connected(_on_debug_overlay_dev_option_changed):
		debug_overlay_bridge.dev_option_state_changed.connect(_on_debug_overlay_dev_option_changed)
	_register_external_dev_options()
	if dev_options_panel != null:
		dev_options_panel.rebuild_options()
	if dev_option_registry != null:
		dev_option_registry.refresh_all()


func configure_dev_options_ball_audio(system: BallAudioSystem) -> void:
	ball_audio_system_bridge = system
	_register_ball_audio_dev_options()
	if dev_options_panel != null:
		dev_options_panel.rebuild_options()
	if dev_option_registry != null:
		dev_option_registry.refresh_all()


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
	if aim_compare_panels_check_box != null:
		aim_compare_panels_check_box.set_pressed_no_signal(bool(panel_states.get("aim_compare_panels", false)))
	if dev_option_registry != null:
		for panel_id_value in panel_states.keys():
			var panel_id: String = str(panel_id_value)
			dev_option_registry.refresh_option("panel.%s" % panel_id)


func get_debug_session_snapshot() -> Dictionary:
	return {
		"wayfinder_current_button": wayfinder_current_test_check_box.button_pressed,
		"broadside_button": broadside_attack_test_check_box.button_pressed,
		"force_contraband": force_loose_cargo_contraband_check_box.button_pressed,
		"contraband_kind": _get_selected_loose_cargo_contraband_kind(),
		"obstacle_collision": obstacle_collision_check_box.button_pressed,
		"obstacle_collision_draw": obstacle_collision_debug_check_box.button_pressed,
		"pocket_capture_presentation": pocket_capture_presentation_check_box.button_pressed,
		"pocket_collection_anchors": pocket_collection_anchors_check_box.button_pressed,
		"debug_aim_line": debug_aim_line_check_box.button_pressed,
		"aim_compare_panels": aim_compare_panels_check_box.button_pressed,
		"verbose_aim_candidates": verbose_aim_candidates_check_box.button_pressed,
		"cue_first_contact_toi": cue_first_contact_toi_check_box.button_pressed,
		"show_reset_table_button": reset_table_button_check_box.button_pressed,
		"show_reset_last_shot_button": reset_last_shot_button_check_box.button_pressed,
		"cloned_aim_configuration": get_cloned_aim_configuration(),
		"aim_benchmark_preset": selected_aim_benchmark_preset_id,
		"aim_benchmark_label": aim_benchmark_label,
		"force_back_room": force_back_room_available_check_box.button_pressed,
		"selected_oath_id": _get_selected_debug_oath_id(),
		"dev_options_ui": dev_options_panel.get_session_snapshot() if dev_options_panel != null else {},
	}


func apply_debug_session_snapshot(snapshot: Dictionary) -> void:
	_set_debug_option(wayfinder_current_test_check_box, bool(snapshot.get("wayfinder_current_button", false)), debug_wayfinder_current_test_button_toggled)
	_set_debug_option(broadside_attack_test_check_box, bool(snapshot.get("broadside_button", false)), debug_broadside_attack_test_button_toggled)
	_set_debug_option(force_loose_cargo_contraband_check_box, bool(snapshot.get("force_contraband", false)), debug_force_loose_cargo_contraband_toggled)
	loose_cargo_contraband_selector.disabled = not force_loose_cargo_contraband_check_box.button_pressed
	_select_contraband_kind(str(snapshot.get("contraband_kind", DEBUG_CONTRABAND_KIND_RANDOM)))
	debug_loose_cargo_contraband_kind_selected.emit(_get_selected_loose_cargo_contraband_kind())
	_set_debug_option(obstacle_collision_check_box, bool(snapshot.get("obstacle_collision", true)), debug_obstacle_collision_toggled)
	_set_debug_option(obstacle_collision_debug_check_box, bool(snapshot.get("obstacle_collision_draw", false)), debug_obstacle_collision_draw_toggled)
	_set_debug_option(pocket_capture_presentation_check_box, bool(snapshot.get("pocket_capture_presentation", true)), debug_pocket_capture_presentation_toggled)
	_set_debug_option(pocket_collection_anchors_check_box, bool(snapshot.get("pocket_collection_anchors", false)), debug_pocket_collection_anchors_toggled)
	_set_debug_option(debug_aim_line_check_box, bool(snapshot.get("debug_aim_line", false)), debug_aim_line_toggled)
	_set_debug_option(aim_compare_panels_check_box, bool(snapshot.get("aim_compare_panels", false)), debug_aim_compare_panels_toggled)
	_set_debug_option(verbose_aim_candidates_check_box, bool(snapshot.get("verbose_aim_candidates", false)), debug_verbose_aim_candidates_toggled)
	_set_debug_option(cue_first_contact_toi_check_box, bool(snapshot.get("cue_first_contact_toi", true)), debug_cue_first_contact_toi_toggled)
	_set_debug_option(reset_table_button_check_box, bool(snapshot.get("show_reset_table_button", false)), debug_reset_table_button_toggled)
	_set_debug_option(reset_last_shot_button_check_box, bool(snapshot.get("show_reset_last_shot_button", false)), debug_reset_last_shot_button_toggled)
	_apply_cloned_aim_configuration(snapshot.get("cloned_aim_configuration", get_cloned_aim_configuration()))
	selected_aim_benchmark_preset_id = str(snapshot.get(
		"aim_benchmark_preset",
		AimTrajectoryPredictor.BENCHMARK_PRESET_LONG_SIGHT_5
	))
	aim_benchmark_label = str(snapshot.get("aim_benchmark_label", ""))
	_set_debug_option(force_back_room_available_check_box, bool(snapshot.get("force_back_room", false)), debug_back_room_force_available_toggled)
	_select_debug_oath_id(str(snapshot.get("selected_oath_id", OathSystem.OATH_OF_URGENCY)))
	var dev_options_ui_value: Variant = snapshot.get("dev_options_ui", {})
	if dev_options_panel != null and dev_options_ui_value is Dictionary:
		dev_options_panel.apply_session_snapshot(dev_options_ui_value as Dictionary)
	if dev_option_registry != null:
		dev_option_registry.refresh_all()


func _set_debug_option(check_box: CheckBox, enabled: bool, output_signal: Signal) -> void:
	if check_box == null:
		return
	check_box.set_pressed_no_signal(enabled)
	output_signal.emit(enabled)


func _select_contraband_kind(kind: String) -> void:
	if loose_cargo_contraband_selector == null:
		return
	for item_index in range(loose_cargo_contraband_selector.item_count):
		if str(loose_cargo_contraband_selector.get_item_metadata(item_index)) == kind:
			loose_cargo_contraband_selector.select(item_index)
			return


func _select_debug_oath_id(oath_id: String) -> void:
	if oath_testing_selector == null:
		return
	for item_index in range(oath_testing_selector.item_count):
		if str(oath_testing_selector.get_item_metadata(item_index)) == oath_id:
			oath_testing_selector.select(item_index)
			return


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
	if dev_option_registry != null:
		dev_option_registry.refresh_option("oath.status")


func set_debris_collision_debug_state(enabled: bool) -> void:
	if obstacle_collision_check_box != null:
		obstacle_collision_check_box.set_pressed_no_signal(enabled)
	if dev_option_registry != null:
		dev_option_registry.refresh_option("debris.collision")


func set_debris_collision_draw_debug_state(enabled: bool) -> void:
	if obstacle_collision_debug_check_box != null:
		obstacle_collision_debug_check_box.set_pressed_no_signal(enabled)
	if dev_option_registry != null:
		dev_option_registry.refresh_option("debris.collision_draw")


func set_back_room_force_available_debug_state(enabled: bool) -> void:
	if force_back_room_available_check_box != null:
		force_back_room_available_check_box.set_pressed_no_signal(enabled)
	if dev_option_registry != null:
		dev_option_registry.refresh_option("back_room.force_available")


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
	if dev_options_button == null:
		dev_options_button = _make_pause_button("Dev Options", "DevOptionsButton")
		menu_stack.add_child(dev_options_button)
		menu_stack.move_child(dev_options_button, run_stats_button.get_index() + 1)
		dev_options_button.pressed.connect(_on_dev_options_pressed)

	if dev_options_panel == null:
		if dev_option_registry == null:
			dev_option_registry = DEV_OPTION_REGISTRY_SCRIPT.new() as DevOptionRegistry
		dev_options_panel = DEV_OPTIONS_PANEL_SCRIPT.new() as DevOptionsPanel
		dev_options_panel.name = "DevOptionsPanel"
		add_child(dev_options_panel)
		dev_options_panel.setup(resume_button, menu_panel, dev_option_registry)
		dev_options_panel.back_requested.connect(_on_dev_options_back_pressed)


func _ensure_shot_lab_entry_confirmation() -> void:
	if shot_lab_entry_confirmation != null:
		return
	shot_lab_entry_confirmation = ConfirmationDialog.new()
	shot_lab_entry_confirmation.name = "ShotLabEntryConfirmation"
	shot_lab_entry_confirmation.title = "Enter Shot Lab"
	shot_lab_entry_confirmation.dialog_text = "Entering Shot Lab will leave the current run."
	shot_lab_entry_confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	shot_lab_entry_confirmation.confirmed.connect(_on_shot_lab_entry_confirmed)
	add_child(shot_lab_entry_confirmation)
	shot_lab_entry_confirmation.get_ok_button().text = "Enter Shot Lab"
	shot_lab_entry_confirmation.get_cancel_button().text = "Stay"


func _request_shot_lab_entry(run_suite: bool) -> void:
	pending_shot_lab_suite = run_suite
	_ensure_shot_lab_entry_confirmation()
	shot_lab_entry_confirmation.dialog_text = (
		"Entering Shot Lab will leave the current run.\n\n"
		+ ("The reference suite will begin after the laboratory loads." if run_suite else "The selected reference setup will be loaded automatically.")
	)
	shot_lab_entry_confirmation.popup_centered(Vector2i(520, 210))


func _on_shot_lab_entry_confirmed() -> void:
	var run_suite: bool = pending_shot_lab_suite
	pending_shot_lab_suite = false
	if dev_options_panel != null:
		dev_options_panel.close_panel()
	shot_lab_session_requested.emit(run_suite)


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


func _ensure_pocket_capture_testing_controls() -> void:
	if pocket_capture_testing_section_label == null:
		pocket_capture_testing_section_label = Label.new()
		pocket_capture_testing_section_label.text = POCKET_CAPTURE_TEST_SECTION_TITLE
		_apply_debug_section_label_style(pocket_capture_testing_section_label)
		debug_section.add_child(pocket_capture_testing_section_label)
	if pocket_capture_presentation_check_box == null:
		pocket_capture_presentation_check_box = _make_event_test_check_box(POCKET_CAPTURE_TEST_ENABLED_TEXT)
		pocket_capture_presentation_check_box.set_pressed_no_signal(true)
		debug_section.add_child(pocket_capture_presentation_check_box)
	if clear_pocket_collections_button == null:
		clear_pocket_collections_button = _make_event_test_button(
			POCKET_CAPTURE_TEST_CLEAR_TEXT,
			"ClearPocketCollectionsButton"
		)
		debug_section.add_child(clear_pocket_collections_button)
	if pocket_collection_anchors_check_box == null:
		pocket_collection_anchors_check_box = _make_event_test_check_box(POCKET_CAPTURE_TEST_ANCHORS_TEXT)
		pocket_collection_anchors_check_box.set_pressed_no_signal(false)
		debug_section.add_child(pocket_collection_anchors_check_box)
	if reflow_pocket_collections_button == null:
		reflow_pocket_collections_button = _make_event_test_button(
			POCKET_CAPTURE_TEST_REFLOW_TEXT,
			"ReflowPocketCollectionsButton"
		)
		debug_section.add_child(reflow_pocket_collections_button)


func _ensure_aim_preview_testing_controls() -> void:
	if aim_preview_testing_section_label == null:
		aim_preview_testing_section_label = Label.new()
		aim_preview_testing_section_label.text = AIM_PREVIEW_TEST_SECTION_TITLE
		_apply_debug_section_label_style(aim_preview_testing_section_label)
		debug_section.add_child(aim_preview_testing_section_label)

	if debug_aim_line_check_box == null:
		debug_aim_line_check_box = _make_event_test_check_box(AIM_PREVIEW_TEST_DEBUG_LINE_TEXT)
		debug_aim_line_check_box.tooltip_text = "Debug-only: enables raw aim diagnostics, converts current anomalies to ordinary balls, and suppresses future anomaly behavior."
		debug_section.add_child(debug_aim_line_check_box)

	if aim_compare_panels_check_box == null:
		aim_compare_panels_check_box = _make_event_test_check_box(AIM_PREVIEW_TEST_COMPARE_PANELS_TEXT)
		aim_compare_panels_check_box.tooltip_text = "Debug-only: shows launch, contact, simulation, event-chain, trace, and resolver-order panels."
		debug_section.add_child(aim_compare_panels_check_box)

	if verbose_aim_candidates_check_box == null:
		verbose_aim_candidates_check_box = _make_event_test_check_box(AIM_PREVIEW_TEST_VERBOSE_CANDIDATES_TEXT)
		verbose_aim_candidates_check_box.tooltip_text = "Show the complete first-hit candidate sweep instead of the focused subset."
		debug_section.add_child(verbose_aim_candidates_check_box)

	if cue_first_contact_toi_check_box == null:
		cue_first_contact_toi_check_box = _make_event_test_check_box(AIM_PREVIEW_TEST_CUE_TOI_TEXT)
		cue_first_contact_toi_check_box.set_pressed_no_signal(true)
		cue_first_contact_toi_check_box.tooltip_text = "Use swept earliest-contact order for the cue ball's initial object-ball contact."
		debug_section.add_child(cue_first_contact_toi_check_box)

	if reset_table_button_check_box == null:
		reset_table_button_check_box = _make_event_test_check_box(AIM_PREVIEW_TEST_RESET_TABLE_TEXT)
		reset_table_button_check_box.tooltip_text = "Show the on-table current-mode restart utility."
		debug_section.add_child(reset_table_button_check_box)

	if reset_last_shot_button_check_box == null:
		reset_last_shot_button_check_box = _make_event_test_check_box(AIM_PREVIEW_TEST_RESET_LAST_SHOT_TEXT)
		reset_last_shot_button_check_box.tooltip_text = "Show the reusable one-shot checkpoint restore utility."
		debug_section.add_child(reset_last_shot_button_check_box)

	_ensure_cloned_aim_simulation_controls()


func _ensure_cloned_aim_simulation_controls() -> void:
	if cloned_aim_testing_section_label == null:
		cloned_aim_testing_section_label = Label.new()
		cloned_aim_testing_section_label.text = "Cloned Aim Simulation"
		_apply_debug_section_label_style(cloned_aim_testing_section_label)
		debug_section.add_child(cloned_aim_testing_section_label)
	for definition in _get_cloned_aim_configuration_schema():
		var key: String = str(definition.get("key", ""))
		if key.is_empty() or cloned_aim_controls.has(key):
			continue
		if str(definition.get("type", "")) == "bool":
			var check_box: CheckBox = _make_event_test_check_box(str(definition.get("label", key)))
			check_box.set_pressed_no_signal(bool(definition.get("default", false)))
			check_box.toggled.connect(_on_cloned_aim_bool_changed.bind(key))
			debug_section.add_child(check_box)
			cloned_aim_controls[key] = check_box
		elif str(definition.get("type", "")) == "select":
			var selector_row: HBoxContainer = HBoxContainer.new()
			selector_row.name = "ClonedAim%sRow" % key.to_pascal_case()
			selector_row.add_theme_constant_override("separation", 8)
			var selector_label: Label = Label.new()
			selector_label.text = str(definition.get("label", key))
			selector_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			selector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			selector_label.add_theme_font_override("font", core_performance_check_box.get_theme_font("font"))
			selector_label.add_theme_font_size_override("font_size", 13)
			selector_row.add_child(selector_label)
			var selector: OptionButton = OptionButton.new()
			selector.custom_minimum_size = Vector2(180.0, 30.0)
			for choice_value in definition.get("choices", []):
				if not choice_value is Dictionary:
					continue
				var choice: Dictionary = choice_value
				var choice_index: int = selector.item_count
				selector.add_item(str(choice.get("label", choice.get("value", "Choice"))))
				selector.set_item_metadata(choice_index, choice.get("value"))
				if str(choice.get("value", "")) == str(definition.get("default", "")):
					selector.select(choice_index)
			selector.item_selected.connect(_on_cloned_aim_select_changed.bind(key, selector))
			selector_row.add_child(selector)
			debug_section.add_child(selector_row)
			cloned_aim_controls[key] = selector
		else:
			var row: HBoxContainer = HBoxContainer.new()
			row.name = "ClonedAim%sRow" % key.to_pascal_case()
			row.add_theme_constant_override("separation", 8)
			var label: Label = Label.new()
			label.text = str(definition.get("label", key))
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.add_theme_font_override("font", core_performance_check_box.get_theme_font("font"))
			label.add_theme_font_size_override("font_size", 13)
			row.add_child(label)
			var spin_box: SpinBox = SpinBox.new()
			spin_box.custom_minimum_size = Vector2(118.0, 30.0)
			spin_box.min_value = float(definition.get("minimum", 0.0))
			spin_box.max_value = float(definition.get("maximum", 0.0))
			spin_box.step = float(definition.get("step", 1.0))
			spin_box.allow_greater = false
			spin_box.allow_lesser = false
			spin_box.value = float(definition.get("default", 0.0))
			spin_box.value_changed.connect(_on_cloned_aim_numeric_changed.bind(key))
			row.add_child(spin_box)
			debug_section.add_child(row)
			cloned_aim_controls[key] = spin_box
	if reset_aim_profiler_button == null:
		reset_aim_profiler_button = _make_event_test_button(
			"Reset Aim Profiler Stats",
			"ResetAimProfilerStatsButton"
		)
		reset_aim_profiler_button.tooltip_text = "Clears the bounded cloned-prediction timing history and cache counters shown by AIM PROFILER."
		debug_section.add_child(reset_aim_profiler_button)


func get_cloned_aim_configuration() -> Dictionary:
	var configuration: Dictionary = {}
	for definition in _get_cloned_aim_configuration_schema():
		var key: String = str(definition.get("key", ""))
		var control: Control = cloned_aim_controls.get(key) as Control
		if control is CheckBox:
			configuration[key] = (control as CheckBox).button_pressed
		elif control is SpinBox:
			var value: float = (control as SpinBox).value
			configuration[key] = int(value) if str(definition.get("type", "")) == "int" else value
		elif control is OptionButton:
			configuration[key] = _get_option_button_value(control as OptionButton)
	return _normalize_cloned_aim_configuration(configuration)


func _apply_cloned_aim_configuration(configuration_value: Variant) -> void:
	if not configuration_value is Dictionary:
		return
	var configuration: Dictionary = _normalize_cloned_aim_configuration(
		configuration_value as Dictionary
	)
	for key_value in configuration.keys():
		var key: String = str(key_value)
		var control: Control = cloned_aim_controls.get(key) as Control
		if control is CheckBox:
			(control as CheckBox).set_pressed_no_signal(bool(configuration[key_value]))
		elif control is SpinBox:
			(control as SpinBox).set_value_no_signal(float(configuration[key_value]))
		elif control is OptionButton:
			_select_option_button_value(control as OptionButton, configuration[key_value], false)
	debug_cloned_aim_configuration_changed.emit(configuration)


func _get_cloned_aim_configuration_schema() -> Array[Dictionary]:
	var combined_schema: Array[Dictionary] = []
	for definition_value in AIM_TRAJECTORY_PREDICTOR_SCRIPT.get_configuration_schema(4):
		combined_schema.append((definition_value as Dictionary).duplicate(true))
	for definition_value in AIM_STAGING_CONFIGURATION_SCRIPT.get_configuration_schema():
		combined_schema.append((definition_value as Dictionary).duplicate(true))
	return combined_schema


func _normalize_cloned_aim_configuration(configuration: Dictionary) -> Dictionary:
	var normalized: Dictionary = AIM_TRAJECTORY_PREDICTOR_SCRIPT.normalize_configuration(
		configuration,
		4
	)
	var staging_configuration: Dictionary = AIM_STAGING_CONFIGURATION_SCRIPT.normalize_configuration(
		configuration
	)
	normalized.merge(staging_configuration, true)
	return normalized


func _on_cloned_aim_bool_changed(_enabled: bool, _key: String) -> void:
	debug_cloned_aim_configuration_changed.emit(get_cloned_aim_configuration())


func _on_cloned_aim_numeric_changed(_value: float, _key: String) -> void:
	debug_cloned_aim_configuration_changed.emit(get_cloned_aim_configuration())


func _on_cloned_aim_select_changed(_index: int, _key: String, _selector: OptionButton) -> void:
	debug_cloned_aim_configuration_changed.emit(get_cloned_aim_configuration())


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


func _ensure_boon_testing_controls() -> void:
	if boon_testing_section_label == null:
		boon_testing_section_label = Label.new()
		boon_testing_section_label.text = BOON_TEST_SECTION_TITLE
		_apply_debug_section_label_style(boon_testing_section_label)
		debug_section.add_child(boon_testing_section_label)

	if activate_long_sight_button == null:
		activate_long_sight_button = _make_event_test_button(BOON_TEST_ACTIVATE_LONG_SIGHT_TEXT, "ActivateLongSightButton")
		activate_long_sight_button.tooltip_text = "Debug-only: activates or refreshes Long Sight through KrakenBoonSystem."
		debug_section.add_child(activate_long_sight_button)

	if activate_krakens_patience_button == null:
		activate_krakens_patience_button = _make_event_test_button(BOON_TEST_ACTIVATE_KRAKENS_PATIENCE_TEXT, "ActivateKrakensPatienceButton")
		activate_krakens_patience_button.tooltip_text = "Debug-only: activates or refreshes Kraken's Patience through KrakenBoonSystem."
		debug_section.add_child(activate_krakens_patience_button)

	if activate_deep_ledger_button == null:
		activate_deep_ledger_button = _make_event_test_button(BOON_TEST_ACTIVATE_DEEP_LEDGER_TEXT, "ActivateDeepLedgerButton")
		activate_deep_ledger_button.tooltip_text = "Debug-only: activates or refreshes Deep Ledger through KrakenBoonSystem."
		debug_section.add_child(activate_deep_ledger_button)

	if activate_iron_wake_button == null:
		activate_iron_wake_button = _make_event_test_button(BOON_TEST_ACTIVATE_IRON_WAKE_TEXT, "ActivateIronWakeButton")
		activate_iron_wake_button.tooltip_text = "Debug-only: activates or refreshes Iron Wake through KrakenBoonSystem."
		debug_section.add_child(activate_iron_wake_button)

	if expire_all_boons_button == null:
		expire_all_boons_button = _make_event_test_button(BOON_TEST_EXPIRE_ALL_TEXT, "ExpireAllBoonsButton")
		expire_all_boons_button.tooltip_text = "Debug-only: expires every active Kraken Boon."
		debug_section.add_child(expire_all_boons_button)


func _ensure_reserve_stack_testing_controls() -> void:
	if reserve_stack_testing_section_label == null:
		reserve_stack_testing_section_label = Label.new()
		reserve_stack_testing_section_label.text = RESERVE_STACK_TEST_SECTION_TITLE
		_apply_debug_section_label_style(reserve_stack_testing_section_label)
		debug_section.add_child(reserve_stack_testing_section_label)

	while reserve_stack_test_buttons.size() < RESERVE_STACK_TEST_ITEMS.size():
		var test_index: int = reserve_stack_test_buttons.size()
		var test_item: Dictionary = RESERVE_STACK_TEST_ITEMS[test_index]
		var button_name: String = "ReserveStackTestButton%s" % test_index
		var button: Button = _make_event_test_button(str(test_item.get("label", "Add Reserve Stack")), button_name)
		button.tooltip_text = "Debug-only: inserts this stacked payload into the first open Reserve slot."
		button.pressed.connect(_on_reserve_stack_test_pressed.bind(test_index))
		reserve_stack_test_buttons.append(button)
		debug_section.add_child(button)


func _ensure_sunken_spoils_testing_controls() -> void:
	if sunken_spoils_testing_section_label == null:
		sunken_spoils_testing_section_label = Label.new()
		sunken_spoils_testing_section_label.text = SUNKEN_SPOILS_TEST_SECTION_TITLE
		_apply_debug_section_label_style(sunken_spoils_testing_section_label)
		debug_section.add_child(sunken_spoils_testing_section_label)

	if sunken_spoils_advance_button == null:
		sunken_spoils_advance_button = _make_event_test_button(SUNKEN_SPOILS_TEST_ADVANCE_TEXT, "AdvanceSunkenSpoilsButton")
		sunken_spoils_advance_button.tooltip_text = "Debug-only: advances current Sunken Spoils milestone progress by one."
		debug_section.add_child(sunken_spoils_advance_button)

	if sunken_spoils_trigger_button == null:
		sunken_spoils_trigger_button = _make_event_test_button(SUNKEN_SPOILS_TEST_TRIGGER_TEXT, "TriggerSunkenSpoilsButton")
		sunken_spoils_trigger_button.tooltip_text = "Debug-only: opens a ready Sunken Spoils reward for the current milestone."
		debug_section.add_child(sunken_spoils_trigger_button)

	if sunken_spoils_reset_button == null:
		sunken_spoils_reset_button = _make_event_test_button(SUNKEN_SPOILS_TEST_RESET_TEXT, "ResetSunkenSpoilsButton")
		sunken_spoils_reset_button.tooltip_text = "Debug-only: resets Sunken Spoils progress and pending rewards."
		debug_section.add_child(sunken_spoils_reset_button)


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


func _register_local_dev_options() -> void:
	if dev_option_registry == null:
		return

	_register_bool_control(
		"session.show_reset_table_button",
		"Show Reset Table Button",
		reset_table_button_check_box,
		[_dev_location(DevOptionsPanel.TAB_SESSION, "Session Utilities")],
		"Shows an on-table button that restarts the current mode. Using that button replaces the current run state.",
		"The restart button is visible during gameplay.",
		"The restart button stays hidden.",
		["restart", "reset run", "mode restart"]
	)
	_register_bool_control(
		"session.show_reset_last_shot_button",
		"Show Reset Last Shot Button",
		reset_last_shot_button_check_box,
		[_dev_location(DevOptionsPanel.TAB_SESSION, "Session Utilities")],
		"Shows the one-shot checkpoint restore button. Restoring rewinds the current table to the saved pre-shot state.",
		"The shot-rewind button is visible.",
		"The shot-rewind button stays hidden.",
		["rewind", "checkpoint", "restore shot"]
	)

	_register_bool_control(
		"aim.debug_line",
		"Debug Aim Line",
		debug_aim_line_check_box,
		[_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Aim Testing")],
		"Enables raw aim diagnostics in a compatibility mode: current anomaly balls become ordinary object balls and future anomaly behavior is suppressed until disabled.",
		"Raw aim diagnostics are drawn and anomaly behavior is suppressed.",
		"The normal player-facing aim preview and future anomaly behavior are used.",
		["raw aim", "prediction line", "aim diagnostics", "disable anomalies"]
	)
	_register_bool_control(
		"aim.verbose_candidates",
		"Verbose Aim Candidates",
		verbose_aim_candidates_check_box,
		[_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Aim Testing")],
		"Shows every ball considered by the first-hit aim sweep instead of only the focused candidate subset. This can make diagnostics much denser.",
		"All considered first-hit candidates are reported.",
		"Only the focused candidate subset is reported.",
		["candidate sweep", "first hit", "contact candidates"]
	)
	_register_bool_control(
		"aim.cue_first_contact_toi",
		"Cue First-Contact TOI",
		cue_first_contact_toi_check_box,
		[_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Live Collision Accuracy")],
		"Makes the cue ball resolve its first collision in true travel order instead of whichever ball pair the collision loop encounters first. This changes the active collision test path.",
		"Swept time-of-impact ordering is used for the cue ball's first contact.",
		"The legacy pair-loop order is used for that first contact.",
		["toi", "time of impact", "first collision", "travel order"]
	)
	_register_cloned_aim_options()
	_register_staged_deep_aim_actions()
	_register_aim_benchmark_options()
	_register_action_option(
		"aim.reset_profiler",
		"Reset Aim Profiler Stats",
		reset_aim_profiler_button,
		[_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Aim Profiler")],
		"Clears the cloned predictor's bounded timing history and profiler counters. It does not change prediction settings or gameplay.",
		["clear timings", "profile history", "performance baseline"]
	)
	_register_ball_audio_dev_options()

	_register_bool_control(
		"events.show_wayfinder_current_button",
		"Show Wayfinder Current Test Button",
		wayfinder_current_test_check_box,
		[_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Table Events")],
		"Shows a gameplay-side debug button that triggers Wayfinder Current without paying its normal Intervention cost.",
		"The event test button is visible.",
		"The event test button is hidden.",
		["wayfinder event", "current test"]
	)
	_register_bool_control(
		"events.show_broadside_button",
		"Show Broadside Attack Test Button",
		broadside_attack_test_check_box,
		[_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Table Events")],
		"Shows a gameplay-side debug button that triggers Broadside Attack without paying its normal Intervention cost.",
		"The event test button is visible.",
		"The event test button is hidden.",
		["broadside", "cannon event", "attack test"]
	)
	_register_bool_control(
		"cargo.force_contraband",
		"Force Loose Cargo Contraband",
		force_loose_cargo_contraband_check_box,
		[_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Cargo & Contraband")],
		"Forces the next Loose Cargo test path to use Contraband instead of its normal chance. This changes active test outcomes while enabled.",
		"Loose Cargo Contraband is forced using the selected kind.",
		"Normal Contraband odds are used.",
		["cargo rng", "special replacement", "forced cargo"]
	)
	_register_select_control(
		"cargo.contraband_kind",
		"Forced Contraband Kind",
		loose_cargo_contraband_selector,
		_make_contraband_choices(),
		[_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Cargo & Contraband")],
		"Chooses which Contraband replacement is used while forced Contraband is enabled. Random uses the normal weighted Contraband table.",
		["wayfinder", "powder keg", "treasure", "cannon", "embezzler"],
		_is_contraband_selector_disabled
	)
	_register_action_option("debris.spawn", "Spawn Wood Debris", spawn_wood_debris_button, [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Table Debris")], "Spawns one authored wood obstacle at a safe randomized felt position. This modifies the current table.", ["obstacle", "plank"])
	_register_action_option("debris.clear", "Clear Debris", clear_debris_button, [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Table Debris")], "Removes all currently spawned wood debris from the table.", ["obstacle", "remove planks"])
	_register_bool_control("debris.collision", "Enable Debris Collision", obstacle_collision_check_box, [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Table Debris")], "Enables custom ball collision against the authored debris polygons. This changes active table collision behavior.", "Balls bounce from wood debris.", "Debris remains visual-only.", ["polygon collision", "wood blocker"])
	_register_bool_control("debris.collision_draw", "Show Debris Collision Shape", obstacle_collision_debug_check_box, [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Table Debris")], "Draws the exact transformed polygon used by debris collision so art alignment can be inspected.", "Collision polygons are visible.", "Collision polygons are hidden.", ["polygon debug", "obstacle outline"])
	_register_bool_control(
		"pocket_capture.presentation_enabled",
		"Pocket Capture Presentation",
		pocket_capture_presentation_check_box,
		[_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Pocket Capture Presentation")],
		"Enables presentation-only pocket fall animations and bounded sunk-ball collections. It does not affect capture, scoring, physics, or active-ball counts.",
		"Captured balls animate into visual pocket collections.",
		"Pocket capture presentation is disabled and its visual collections are cleared.",
		["sink animation", "pocket pile", "captured balls"]
	)
	_register_action_option(
		"pocket_capture.clear_collections",
		"Clear Pocket Collections",
		clear_pocket_collections_button,
		[_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Pocket Capture Presentation")],
		"Clears only the presentation proxies currently collected beneath the pockets. It does not restore balls, change scoring, or alter the run.",
		["clear pocket pile", "visual reset", "sunk ball presentation"]
	)
	_register_bool_control(
		"pocket_capture.show_collection_anchors",
		"Show Pocket Collection Anchors",
		pocket_collection_anchors_check_box,
		[_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Pocket Capture Presentation")],
		"Draws each presentation-only CollectionAnchor, its inward vector, and the radius-aware resting basin. These markers never affect pocket collision or gameplay.",
		"Authored pocket collection anchors and basins are visible.",
		"Pocket collection layout guides are hidden.",
		["pocket basin", "presentation anchor", "resting region"]
	)
	_register_action_option(
		"pocket_capture.reflow_collections",
		"Reflow Pocket Collections",
		reflow_pocket_collections_button,
		[_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Pocket Capture Presentation")],
		"Refreshes authored CollectionAnchor positions and moves existing settled proxies into their presentation-only basins. Scoring, captures, and ball state are untouched.",
		["refresh anchors", "retune pile", "visual layout"]
	)

	_register_bool_control("back_room.force_available", "Force Back Room Available", force_back_room_available_check_box, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Back Room")], "Bypasses only the Back Room refresh-cost unlock threshold. Real cost, Reserve capacity, Embezzler limits, and Oath blockers still apply.", "The Back Room is treated as unlocked for testing.", "The normal unlock threshold is required.", ["deal unlock", "quartermaster"])
	_register_action_option("back_room.open", "Open Back Room Deal", open_back_room_deal_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Back Room")], "Opens the real Back Room Deal panel. Purchases still use normal costs and validation.", ["deal panel", "quartermaster"])
	_register_action_option("boon.activate_long_sight", "Activate Long Sight", activate_long_sight_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Kraken Boons")], "Activates or refreshes Long Sight through the real Boon system without a purchase.", ["aim boon", "refresh boon"])
	_register_action_option("boon.activate_patience", "Activate Kraken's Patience", activate_krakens_patience_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Kraken Boons")], "Activates or refreshes Kraken's Patience through the real Boon system without a purchase.", ["meter carry", "refresh boon"])
	_register_action_option("boon.activate_deep_ledger", "Activate Deep Ledger", activate_deep_ledger_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Kraken Boons")], "Activates or refreshes Deep Ledger through the real Boon system without a purchase.", ["ledger boon", "refresh boon"])
	_register_action_option("boon.activate_iron_wake", "Activate Iron Wake", activate_iron_wake_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Kraken Boons")], "Activates or refreshes Iron Wake through the real Boon system without a purchase.", ["cannon wake", "impact boon"])
	_register_action_option("boon.expire_all", "Expire All Boons", expire_all_boons_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Kraken Boons")], "Expires every active Kraken Boon immediately so cleanup and HUD behavior can be tested.", ["clear boons", "remove boon"])

	for test_index in range(RESERVE_STACK_TEST_ITEMS.size()):
		var test_item: Dictionary = RESERVE_STACK_TEST_ITEMS[test_index]
		var button: Button = reserve_stack_test_buttons[test_index] as Button
		var item_id: String = str(test_item.get("item_id", test_index))
		_register_action_option(
			"reserve.stack.%s" % item_id,
			str(test_item.get("label", "Add Reserve Stack")),
			button,
			[_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Reserve Stack Tests")],
			"Adds this debug stack to the first empty Reserve slot without spending Doubloons. A full Reserve is left unchanged.",
			["quantity", "bundle", "stack payload"]
		)

	_register_action_option("spoils.advance", "Advance Spoils Progress +1", sunken_spoils_advance_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Sunken Spoils")], "Advances the current Sunken Spoils milestone by one debug step. This modifies current-run reward progress.", ["milestone", "sink reward"])
	_register_action_option("spoils.trigger", "Trigger Spoils Reward", sunken_spoils_trigger_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Sunken Spoils")], "Makes the current Sunken Spoils reward ready and opens its normal choice flow when allowed.", ["reward panel", "spoils ready"])
	_register_action_option("spoils.reset", "Reset Spoils", sunken_spoils_reset_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Sunken Spoils")], "Clears current Sunken Spoils progress and pending reward state.", ["clear milestone", "reset reward"])

	_register_select_control("oath.selected", "Selected Oath", oath_testing_selector, _make_oath_choices(), [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Oath Testing")], "Chooses which Oath the debug activate, fail, and complete actions target. Selection alone does not activate an Oath.", ["urgency", "isolation", "sacrifice", "humility"])
	_register_action_option("oath.activate", "Activate Selected Oath", oath_activate_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Oath Testing")], "Activates the selected Oath through OathSystem's normal compatibility checks. This can change the active run.", ["swear oath", "start oath"])
	_register_action_option("oath.advance", "Advance Oath Shot", oath_advance_shot_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Oath Testing")], "Decrements Oath shot timers once without simulating a gameplay shot or advancing unrelated shot systems.", ["timer", "countdown"])
	_register_action_option("oath.fail", "Fail Active Oath", oath_fail_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Oath Testing")], "Runs the selected or first active Oath's real failure path, including its configured penalty, then removes it.", ["penalty", "failure"])
	_register_action_option("oath.complete", "Complete Active Oath", oath_complete_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Oath Testing")], "Completes and removes the selected or first active Oath without applying a failure penalty.", ["satisfy oath", "success"])
	_register_action_option("oath.clear", "Clear Active Oaths", oath_clear_button, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Oath Testing")], "Safely removes all active Oaths and restores suppressed cue modifiers without applying penalties.", ["remove oaths", "restore modifiers"])
	_register_readout_option("oath.status", "Oath State", oath_testing_readout_label, [_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Oath Testing")], "Reports active Oaths, cue-modifier suppression, and the final modifier-enabled state.", ["remaining shots", "silenced", "snapshot"])


func _register_external_dev_options() -> void:
	if dev_option_registry == null or debug_overlay_bridge == null or _external_dev_options_registered:
		return
	_external_dev_options_registered = true

	_register_overlay_bool(
		"overlay.show_fps",
		"Show FPS",
		[
			_dev_location(DevOptionsPanel.TAB_SESSION, "Display & Session"),
			_dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Overlay Diagnostics"),
		],
		"Shows a compact frame-rate readout near the upper-right edge. This is presentation-only and persists across application restarts.",
		"The standalone FPS readout is visible and updates four times per second.",
		"The standalone FPS readout is hidden.",
		["frames per second", "performance counter", "persistent"]
	)
	_register_overlay_action("panels.hide_all", "Hide All Debug Panels", [_dev_location(DevOptionsPanel.TAB_SESSION, "Session Utilities"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Panel Workspace Actions")], "Hides every modular debug panel plus the full performance, physics-debug, and legacy quick-menu overlays. It preserves panel layout and does not disable Debug Aim Line.", ["close workspace", "clear overlays"])
	_register_overlay_action("panels.reset_layout", "Reset Debug Panel Layout", [_dev_location(DevOptionsPanel.TAB_SESSION, "Session Utilities"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Panel Workspace Actions")], "Restores every debug panel's authored position and size while preserving which panels are visible and which diagnostics are active.", ["default positions", "restore sizes"])
	_register_overlay_bool("panel.aim_compare_panels", "Show Complete Aim Workspace", [_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Aim Testing"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Panel Workspace Actions")], "Shows or hides the complete group of aim-comparison panels together. Individual aim panels remain independently controllable.", "All aim comparison panels are shown.", "The group is hidden unless individual panels are enabled.", ["aim compare panels", "workspace", "all aim panels"], ["Aim Compare Panels"])

	var aim_panels: Array[Dictionary] = [
		{"id": "aim_preview", "label": "Aim Preview", "description": "Shows timing and workload diagnostics for the polished and cloned aim-preview paths."},
		{"id": "aim_launch", "label": "Aim Launch", "description": "Compares predicted launch direction and speed with the real cue-ball launch."},
		{"id": "aim_contact", "label": "Aim Contact", "description": "Shows the predicted and actual first contacted ball and the resulting verdict."},
		{"id": "aim_response", "label": "Aim Response", "description": "Shows contact geometry, distance, radii, and response measurements for the first hit."},
		{"id": "aim_trace", "label": "Aim Trace", "description": "Shows the recorded predicted and actual cue-ball path trace diagnostics."},
		{"id": "aim_candidates", "label": "Aim Candidates", "description": "Shows every nearby ball considered as the cue ball's possible first target and why each was accepted or rejected."},
		{"id": "aim_collisions", "label": "Aim Collisions", "description": "Shows predicted collision events and resolver details from the aim path."},
		{"id": "aim_contact_order", "label": "Aim Contact Order", "description": "Shows first-contact sweep ordering so candidate selection can be compared with true travel order."},
		{"id": "aim_simulation", "label": "Aim Simulation", "description": "Shows cloned simulation state, work limits, counts, and stop reasons."},
		{"id": "aim_profiler", "label": "Aim Profiler", "description": "Shows gated phase timings, cache behavior, rebuild reasons, and cloned-prediction workload."},
		{"id": "aim_event_chain", "label": "Aim Event Chain", "description": "Compares the ordered predicted event chain with events observed during the real shot."},
	]
	for panel_definition in aim_panels:
		_register_panel_option(panel_definition, "Aim Panels")

	var performance_panels: Array[Dictionary] = [
		{"id": "core_performance", "label": "Core Performance", "description": "Shows frame, physics, ball-count, and core system performance counters."},
		{"id": "physics", "label": "Physics Performance", "description": "Shows detailed custom billiards physics timing and collision workload."},
		{"id": "visual_effects", "label": "Visual Cost / Effects", "description": "Shows presentation and visual-effect workload so draw-only costs can be inspected."},
	]
	for panel_definition in performance_panels:
		_register_panel_option(panel_definition, "Performance Panels")

	var system_panels: Array[Dictionary] = [
		{"id": "shot_ledger", "label": "Shot Ledger Diagnostics", "description": "Shows the active and last completed semantic shot ledger, causal pocket facts, tags, and collector warnings."},
		{"id": "treasure", "label": "Treasure", "description": "Shows Treasure Ball perception, hide-target, and movement diagnostics."},
		{"id": "embezzler", "label": "Embezzler", "description": "Shows Embezzler value, movement, escape, and capture state."},
		{"id": "anchor", "label": "Anchor", "description": "Shows Anchor curse-seed chain, tightening, warning, spread, and collapse diagnostics."},
		{"id": "ball_drops_score", "label": "Ball Drops / Score", "description": "Shows legacy BallDrop gating and active scoring-system counters."},
		{"id": "cannon", "label": "Cannon", "description": "Shows Cannon Ball movement, heat, impact, and performance diagnostics."},
		{"id": "powder_keg_wayfinder", "label": "Powder Keg / Wayfinder", "description": "Shows Powder Keg explosion and Wayfinder guidance/current diagnostics."},
	]
	for panel_definition in system_panels:
		_register_panel_option(panel_definition, "System Panels")

	var shot_ledger_locations: Array = [
		_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Shot Ledger"),
		_dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Shot Ledger"),
	]
	_register_overlay_action(
		"shot_ledger.copy_summary",
		"Copy Last Shot Ledger Summary",
		shot_ledger_locations,
		"Copies a concise value-only summary of the last completed authoritative shot ledger.",
		["shot facts", "copy ledger", "semantic events"]
	)
	_register_overlay_action(
		"shot_ledger.copy_json",
		"Copy Last Shot Ledger JSON",
		shot_ledger_locations,
		"Copies the complete last ledger as JSON, converting Vector2 values into readable x/y objects.",
		["export ledger", "raw events", "json"]
	)
	_register_overlay_action(
		"shot_ledger.run_self_test",
		"Run Shot Ledger Self-Test",
		shot_ledger_locations,
		"Runs pure synthetic semantic-analysis cases without spawning balls or changing gameplay.",
		["direct pot", "bank", "combination", "re-contact", "causality"]
	)
	_register_overlay_action(
		"shot_ledger.open_raw_events",
		"Open Last Shot Raw Events",
		shot_ledger_locations,
		"Opens a filtered, copyable view of the frozen raw events from the last completed authoritative shot.",
		["event list", "ball id", "event filter", "raw ledger"]
	)
	_register_overlay_action(
		"shot_ledger.copy_raw_events",
		"Copy All Raw Events",
		shot_ledger_locations,
		"Copies every frozen raw event from the last completed shot as readable JSON.",
		["clipboard", "event export", "raw ledger"]
	)
	_register_overlay_action(
		"shot_ledger.clear_diagnostics",
		"Clear Shot Ledger Diagnostic Counters",
		shot_ledger_locations,
		"Clears lifecycle, invalid-event, duplicate-pocket, travel-teleport, and stable-ID diagnostic counters without changing gameplay or completed ledgers.",
		["lifecycle reset", "clear counters", "ball identity"]
	)
	_register_overlay_action(
		"shot_ledger.copy_lifecycle",
		"Copy Lifecycle Diagnostics",
		shot_ledger_locations,
		"Copies the always-available Shot Ledger lifecycle and run-ball identity diagnostics.",
		["misuse reasons", "canceled shots", "stable ids"]
	)

	var shot_lab_locations: Array = [
		_dev_location(DevOptionsPanel.TAB_RUN_SYSTEMS, "Shot Lab"),
		_dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Shot Lab"),
	]
	dev_option_registry.register_option({
		"id": "shot_lab.enter_session",
		"label": "Enter Shot Lab",
		"kind": "action",
		"locations": shot_lab_locations,
		"description": "Opens a dedicated, consequence-frozen laboratory session. Entering from an active game leaves the current run.",
		"keywords": ["controlled setup", "laboratory", "leave run"],
		"action": _request_shot_lab_entry.bind(false),
	})
	dev_option_registry.register_option({
		"id": "shot_lab.enter_and_run_suite",
		"label": "Run Reference Suite in Lab",
		"kind": "action",
		"locations": shot_lab_locations,
		"description": "Enters the dedicated Shot Lab visibly and starts the authoritative reference suite there.",
		"keywords": ["batch validation", "all presets", "laboratory"],
		"action": _request_shot_lab_entry.bind(true),
	})

	_register_overlay_bool("overlay.performance", "Full Performance Overlay", [_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Aim Testing"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Performance Panels")], "Shows the original full-screen performance text overlay. It is denser and more expensive to format than the focused modular panels.", "The full performance overlay is visible.", "The full performance overlay is hidden.", ["f3", "all performance", "legacy diagnostics"])
	_register_overlay_bool("overlay.physics_debug", "Physics Debug", [_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Aim Testing"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Performance Panels")], "Shows the legacy on-screen physics debug text for moving balls and collision state.", "Physics debug text is visible.", "Physics debug text is hidden.", ["ball velocity", "collision state", "legacy overlay"])
	_register_overlay_bool("overlay.shot_path", "Shot Path Debug", [_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Aim Testing"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Overlay Diagnostics")], "Draws the actual shot path for comparison with aim prediction. This is diagnostic presentation only.", "Actual shot-path diagnostics are drawn.", "Actual shot-path diagnostics are hidden.", ["real trajectory", "path trace"])
	_register_overlay_bool("overlay.quick_menu", "Debug Quick Menu", [_dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Overlay Diagnostics")], "Shows the retained legacy quick-debug menu. Its controls mirror the same underlying debug states exposed here.", "The legacy quick menu is visible.", "The legacy quick menu is hidden.", ["f2", "old debug menu", "legacy menu"])

	_register_overlay_bool("anchor.visuals", "Anchor Visuals", [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Anchor Testing / Visuals"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Overlay Diagnostics")], "Shows Anchor chains, warning marks, and other authored Anchor presentation. This changes visuals only.", "Anchor presentation is drawn.", "Anchor presentation is hidden while Anchor state still runs.", ["chains", "curse seed visuals"])
	_register_overlay_bool("anchor.debug_visual", "Anchor Debug Visual", [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Anchor Testing / Visuals"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Overlay Diagnostics")], "Adds technical Anchor chain and constraint drawings for debugging.", "Anchor diagnostic geometry is visible.", "Only normal Anchor presentation is used.", ["constraint debug", "leash"])
	_register_overlay_bool("anchor.single_latch", "Anchor Single Latch Per Target", [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Anchor Testing / Visuals")], "Limits each eligible target ball to one Anchor latch during the active test path. This can change Anchor test behavior.", "A target can hold only one Anchor latch.", "Normal Anchor latch rules are used.", ["chain target", "latch limit"])
	_register_overlay_bool("treasure.debug_visual", "Treasure Debug Visual", [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Treasure Testing / Visuals"), _dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, "Overlay Diagnostics")], "Draws Treasure perception corridors, committed hide targets, and steering diagnostics.", "Treasure diagnostic drawings are visible.", "Treasure uses only normal presentation.", ["hide target", "aim corridor", "scuttle"])
	_register_overlay_bool("powder.particles", "Powder Keg Particles", [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Powder Keg Presentation")], "Enables normal Powder Keg explosion particles. This affects presentation workload, not explosion force.", "Powder Keg explosion particles are allowed.", "Powder Keg explosion particles are suppressed.", ["explosion vfx", "powder presentation"])
	_register_overlay_bool("powder.reduced_particles", "Reduced Powder Keg Particles", [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Powder Keg Presentation")], "Uses a reduced Powder Keg particle count to compare presentation cost while retaining the effect.", "Reduced particle density is used.", "Normal particle density is used when particles are enabled.", ["low particles", "vfx cost"])
	_register_overlay_bool("powder.suppress_trails", "Suppress Powder Keg Trails", [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Powder Keg Presentation")], "Hides Powder Keg trails for visual-cost testing without changing ball movement.", "Powder Keg trails are hidden.", "Powder Keg trails use their normal presentation.", ["trail vfx", "visual cost"])


func _register_ball_audio_dev_options() -> void:
	if (
		dev_option_registry == null
		or ball_audio_system_bridge == null
		or _ball_audio_dev_options_registered
	):
		return
	_ball_audio_dev_options_registered = true
	var locations: Array = [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Ball Audio")]
	dev_option_registry.register_option({
		"id": "audio.ball_collision_mode",
		"label": "Ball Collision Sound",
		"kind": "select",
		"locations": locations,
		"description": "Switches only ordinary ball-collision presentation. Sampled is the original safe path; Procedural uses cached generated one-shots; Layered combines both at restrained gain.",
		"keywords": ["sampled", "procedural", "layered", "collision sound"],
		"choices": [
			{"label": "Sampled", "value": BallAudioSystem.MODE_SAMPLED, "description": "Uses the original recorded collision WAV path exactly as before."},
			{"label": "Procedural", "value": BallAudioSystem.MODE_PROCEDURAL, "description": "Uses only cached generated collision one-shots."},
			{"label": "Layered", "value": BallAudioSystem.MODE_LAYERED, "description": "Adds a quiet sampled layer beneath generated collision detail."},
		],
		"getter": ball_audio_system_bridge.get_collision_audio_mode,
		"setter": ball_audio_system_bridge.set_collision_audio_mode,
	})
	dev_option_registry.register_option({
		"id": "audio.procedural_collision_material",
		"label": "Procedural Collision Material",
		"kind": "select",
		"locations": locations,
		"description": "Selects a cached synthesis recipe. Solid Phenolic B is the default audition candidate; every earlier material experiment remains available.",
		"keywords": ["solid phenolic", "audition candidate", "resin", "bright prototype", "material profile", "collision voice"],
		"choices": [
			{"label": "Solid Phenolic A - Dry", "value": BallAudioSystem.MATERIAL_SOLID_PHENOLIC_A_DRY, "description": "Shortest cluster, nearly no table coupling, and the least low-mid content."},
			{"label": "Solid Phenolic B - Balanced", "value": BallAudioSystem.MATERIAL_SOLID_PHENOLIC_B_BALANCED, "description": "Balanced contact texture with subtle compression and table coupling. Current default."},
			{"label": "Solid Phenolic C - Full", "value": BallAudioSystem.MATERIAL_SOLID_PHENOLIC_C_FULL, "description": "Strongest permitted compression and slate coupling without sustained low resonance."},
			{"label": "Solid Phenolic D - Sharp", "value": BallAudioSystem.MATERIAL_SOLID_PHENOLIC_D_SHARP, "description": "Shortest bright-edged candidate with minimal table coupling and stronger upper contact detail."},
			{"label": "Dense Phenolic", "value": BallAudioSystem.MATERIAL_DENSE_PHENOLIC, "description": "Very short inharmonic modal clusters with dense contact texture and minimal hollow body."},
			{"label": "Resonant Resin Prototype", "value": BallAudioSystem.MATERIAL_RESONANT_RESIN_PROTOTYPE, "description": "The previous lower resin recipe retained as the hollow/resonant comparison reference."},
			{"label": "Bright Prototype", "value": BallAudioSystem.MATERIAL_BRIGHT_PROTOTYPE, "description": "The original brighter, longer, more resonant generated recipe."},
		],
		"getter": ball_audio_system_bridge.get_procedural_material_profile,
		"setter": ball_audio_system_bridge.set_procedural_material_profile,
	})
	_register_ball_audio_number(
		"audio.procedural_collision_hardness",
		"Procedural Collision Hardness",
		ball_audio_system_bridge.get_procedural_hardness,
		ball_audio_system_bridge.set_procedural_hardness,
		0.5,
		1.5,
		0.05,
		1.0,
		"Balances the short contact transient against the impact body. It does not change collision response or simply boost treble.",
		"Rounder contact with a little more body.",
		"Denser, firmer contact edge with restrained body."
	)
	_register_ball_audio_number(
		"audio.procedural_collision_brightness",
		"Procedural Collision Brightness",
		ball_audio_system_bridge.get_procedural_brightness,
		ball_audio_system_bridge.set_procedural_brightness,
		0.5,
		1.5,
		0.05,
		1.0,
		"Adjusts the bounded secondary resonance and first-millisecond upper tick without changing collision behavior.",
		"Darker, rounder generated collision tone.",
		"More upper definition while retaining the selected material identity."
	)
	_register_ball_audio_number(
		"audio.procedural_collision_body",
		"Procedural Collision Body",
		ball_audio_system_bridge.get_procedural_body,
		ball_audio_system_bridge.set_procedural_body,
		0.5,
		1.5,
		0.05,
		1.0,
		"Controls the selected profile's restrained mass component. Solid Phenolic uses only short 700-1500 Hz compression and quiet slate coupling.",
		"Lighter generated impacts.",
		"Weightier generated impacts without a long sub-bass tail."
	)
	_register_ball_audio_number(
		"audio.procedural_collision_decay",
		"Procedural Collision Decay",
		ball_audio_system_bridge.get_procedural_decay,
		ball_audio_system_bridge.set_procedural_decay,
		0.65,
		1.4,
		0.05,
		1.0,
		"Scales the selected profile's compact authored decay range. It never changes gameplay timing.",
		"Shorter, drier generated clacks.",
		"Modestly longer impact body within the profile's hard duration cap."
	)
	_register_ball_audio_number(
		"audio.procedural_collision_variation",
		"Procedural Collision Variation",
		ball_audio_system_bridge.get_procedural_variation,
		ball_audio_system_bridge.set_procedural_variation,
		0.0,
		1.5,
		0.05,
		1.0,
		"Scales narrow bank-frequency, decay, texture, and playback-pitch variation using audio-only random sources.",
		"More uniform generated collisions.",
		"More variation while retaining one billiard-ball material identity."
	)
	_register_ball_audio_number(
		"audio.procedural_collision_voice_limit",
		"Procedural Collision Voice Limit",
		ball_audio_system_bridge.get_procedural_voice_limit,
		ball_audio_system_bridge.set_procedural_voice_limit,
		4.0,
		32.0,
		1.0,
		24,
		"Caps simultaneous generated collision voices. Stronger impacts can replace weaker voices when this presentation budget is full.",
		"More aggressive culling during dense collision chains.",
		"More simultaneous generated collision voices."
	)
	_register_direct_action_option(
		"audio.procedural_collision_reset",
		"Reset Collision Audio Settings",
		locations,
		"Restores Sampled collision audio plus the default procedural audition profile, tuning, and 24-voice limit.",
		_reset_collision_audio_settings,
		["audio defaults", "reset collision sound"]
	)
	_register_direct_action_option(
		"audio.play_soft_collision",
		"Play Soft Collision",
		locations,
		"Auditions a soft impact through the currently selected collision-audio mode without touching gameplay balls.",
		ball_audio_system_bridge.debug_play_soft_collision,
		["audio test", "graze"]
	)
	_register_direct_action_option(
		"audio.play_medium_collision",
		"Play Medium Collision",
		locations,
		"Auditions a medium impact through the currently selected collision-audio mode without touching gameplay balls.",
		ball_audio_system_bridge.debug_play_medium_collision,
		["audio test", "clack"]
	)
	_register_direct_action_option(
		"audio.play_hard_collision",
		"Play Hard Collision",
		locations,
		"Auditions a hard impact through the currently selected collision-audio mode without touching gameplay balls.",
		ball_audio_system_bridge.debug_play_hard_collision,
		["audio test", "crack"]
	)
	_register_direct_action_option(
		"audio.play_collision_burst",
		"Play Collision Burst",
		locations,
		"Auditions a mixed-strength burst against the real bounded audio pools and priority rules without spawning or colliding balls.",
		ball_audio_system_bridge.debug_play_collision_burst,
		["audio stress", "voice budget", "chain"]
	)
	_register_direct_action_option(
		"audio.compare_solid_phenolic_candidates",
		"Compare Solid Phenolic Candidates",
		locations,
		"Auditions A, B, C, and D in order at identical soft, medium, and hard strengths with clear pauses between candidates.",
		ball_audio_system_bridge.debug_compare_solid_phenolic_candidates,
		["phenolic audition pack", "candidate comparison", "audio ab"]
	)
	_register_direct_action_option(
		"audio.play_solid_phenolic_a_sequence",
		"Play Solid Phenolic A Sequence",
		locations,
		"Auditions the Dry candidate at fixed soft, medium, and hard strengths without changing the selected profile.",
		ball_audio_system_bridge.debug_play_solid_phenolic_a_sequence,
		["candidate a", "dry collision", "audio sequence"]
	)
	_register_direct_action_option(
		"audio.play_solid_phenolic_b_sequence",
		"Play Solid Phenolic B Sequence",
		locations,
		"Auditions the Balanced candidate at fixed soft, medium, and hard strengths without changing the selected profile.",
		ball_audio_system_bridge.debug_play_solid_phenolic_b_sequence,
		["candidate b", "balanced collision", "audio sequence"]
	)
	_register_direct_action_option(
		"audio.play_solid_phenolic_c_sequence",
		"Play Solid Phenolic C Sequence",
		locations,
		"Auditions the Full candidate at fixed soft, medium, and hard strengths without changing the selected profile.",
		ball_audio_system_bridge.debug_play_solid_phenolic_c_sequence,
		["candidate c", "full collision", "audio sequence"]
	)
	_register_direct_action_option(
		"audio.play_solid_phenolic_d_sequence",
		"Play Solid Phenolic D Sequence",
		locations,
		"Auditions the Sharp candidate at fixed soft, medium, and hard strengths without changing the selected profile.",
		ball_audio_system_bridge.debug_play_solid_phenolic_d_sequence,
		["candidate d", "sharp collision", "audio sequence"]
	)
	_register_direct_action_option(
		"audio.cycle_solid_phenolic_candidate",
		"Cycle Solid Phenolic Candidate",
		locations,
		"Selects and caches the next live candidate in A to B to C to D order. Diagnostics immediately show the active candidate.",
		_cycle_solid_phenolic_candidate,
		["next candidate", "in-game audio cycle", "phenolic quick test"]
	)
	_register_direct_action_option(
		"audio.play_dense_phenolic_sequence",
		"Play Dense Phenolic Collision Sequence",
		locations,
		"Auditions Dense Phenolic at fixed soft, medium, and hard strengths followed by a short mixed burst without changing the saved material selection.",
		ball_audio_system_bridge.debug_play_dense_phenolic_collision_sequence,
		["phenolic test", "audio sequence", "soft medium hard", "mixed burst"]
	)
	_register_direct_action_option(
		"audio.compare_collision_material_profiles",
		"Compare Material Profiles",
		locations,
		"Plays Dense Phenolic, Resonant Resin Prototype, then Bright Prototype at identical soft, medium, and hard authored strengths using cached comparison banks.",
		ball_audio_system_bridge.debug_compare_material_profiles,
		["audio ab", "resin versus bright", "material comparison"]
	)
	_register_direct_action_option(
		"audio.regenerate_collision_bank",
		"Regenerate Procedural Collision Bank",
		locations,
		"Explicitly rebuilds the 32 cached generated one-shots using current presentation tuning.",
		ball_audio_system_bridge.regenerate_procedural_bank,
		["rebuild sounds", "cached wav"]
	)


func _register_ball_audio_number(
	option_id: String,
	label: String,
	getter: Callable,
	setter: Callable,
	minimum: float,
	maximum: float,
	step: float,
	default_value: Variant,
	description: String,
	low_effect: String,
	high_effect: String
) -> void:
	if dev_option_registry.has_option(option_id):
		return
	dev_option_registry.register_option({
		"id": option_id,
		"label": label,
		"kind": "number",
		"locations": [_dev_location(DevOptionsPanel.TAB_BALLS_EVENTS, "Ball Audio")],
		"description": description,
		"minimum": minimum,
		"maximum": maximum,
		"step": step,
		"default": default_value,
		"low_effect": low_effect,
		"high_effect": high_effect,
		"keywords": ["ball audio", "procedural collision", "presentation only"],
		"getter": getter,
		"setter": setter,
	})


func _cycle_solid_phenolic_candidate() -> void:
	if ball_audio_system_bridge == null:
		return
	ball_audio_system_bridge.cycle_solid_phenolic_candidate()
	if dev_option_registry != null:
		dev_option_registry.refresh_option("audio.procedural_collision_material")


func _reset_collision_audio_settings() -> void:
	if ball_audio_system_bridge == null:
		return
	ball_audio_system_bridge.reset_collision_audio_settings()
	if dev_option_registry != null:
		for option_id in [
			"audio.ball_collision_mode",
			"audio.procedural_collision_material",
			"audio.procedural_collision_hardness",
			"audio.procedural_collision_brightness",
			"audio.procedural_collision_body",
			"audio.procedural_collision_decay",
			"audio.procedural_collision_variation",
			"audio.procedural_collision_voice_limit",
		]:
			dev_option_registry.refresh_option(option_id)


func _register_panel_option(panel_definition: Dictionary, section: String) -> void:
	var panel_id: String = str(panel_definition.get("id", ""))
	_register_overlay_bool(
		"panel.%s" % panel_id,
		str(panel_definition.get("label", panel_id)),
		[_dev_location(DevOptionsPanel.TAB_PANELS_DIAGNOSTICS, section)],
		str(panel_definition.get("description", "Shows this modular debug panel.")),
		"The modular panel is visible and updates only the diagnostics it needs.",
		"The modular panel is hidden and does not format its text.",
		[panel_id.replace("_", " "), "debug panel", "diagnostics"]
	)


func _register_overlay_bool(option_id: String, label: String, locations: Array, description: String, on_effect: String, off_effect: String, keywords: Array = [], aliases: Array = []) -> void:
	if dev_option_registry.has_option(option_id):
		return
	dev_option_registry.register_option({
		"id": option_id,
		"label": label,
		"kind": "bool",
		"locations": locations,
		"description": description,
		"on_effect": on_effect,
		"off_effect": off_effect,
		"keywords": keywords,
		"aliases": aliases,
		"getter": _get_debug_overlay_option_value.bind(option_id),
		"setter": _set_debug_overlay_option_value.bind(option_id),
	})


func _register_overlay_action(option_id: String, label: String, locations: Array, description: String, keywords: Array = []) -> void:
	if dev_option_registry.has_option(option_id):
		return
	dev_option_registry.register_option({
		"id": option_id,
		"label": label,
		"kind": "action",
		"locations": locations,
		"description": description,
		"keywords": keywords,
		"action": _trigger_debug_overlay_action.bind(option_id),
	})


func _get_debug_overlay_option_value(option_id: String) -> Variant:
	if debug_overlay_bridge == null:
		return false
	return debug_overlay_bridge.get_dev_option_state(option_id)


func _set_debug_overlay_option_value(value: Variant, option_id: String) -> void:
	if debug_overlay_bridge != null:
		debug_overlay_bridge.set_dev_option_state(option_id, bool(value))


func _set_debug_overlay_variant_option_value(value: Variant, option_id: String) -> void:
	if debug_overlay_bridge != null:
		debug_overlay_bridge.set_dev_option_state(option_id, value)


func _trigger_debug_overlay_action(option_id: String) -> void:
	if debug_overlay_bridge != null:
		debug_overlay_bridge.trigger_dev_option_action(option_id)


func _on_debug_overlay_dev_option_changed(option_id: String, _value: Variant) -> void:
	_sync_legacy_panel_check_box(option_id)
	if dev_option_registry != null:
		dev_option_registry.refresh_option(option_id)
		if option_id.begins_with("panel.aim_"):
			dev_option_registry.refresh_option("panel.aim_compare_panels")


func _sync_legacy_panel_check_box(option_id: String) -> void:
	if debug_overlay_bridge == null:
		return
	var check_box_by_option: Dictionary = {
		"panel.core_performance": core_performance_check_box,
		"panel.aim_preview": aim_preview_check_box,
		"panel.treasure": treasure_check_box,
		"panel.embezzler": embezzler_check_box,
		"panel.anchor": anchor_check_box,
		"panel.ball_drops_score": ball_drops_score_check_box,
		"panel.cannon": cannon_check_box,
		"panel.powder_keg_wayfinder": powder_keg_wayfinder_check_box,
		"panel.visual_effects": visual_effects_check_box,
		"panel.physics": physics_check_box,
		"panel.aim_compare_panels": aim_compare_panels_check_box,
	}
	var check_box: CheckBox = check_box_by_option.get(option_id) as CheckBox
	if check_box != null:
		check_box.set_pressed_no_signal(bool(debug_overlay_bridge.get_dev_option_state(option_id)))


func _register_cloned_aim_options() -> void:
	for definition_value in _get_cloned_aim_configuration_schema():
		var schema: Dictionary = definition_value
		var key: String = str(schema.get("key", ""))
		var source: Control = cloned_aim_controls.get(key) as Control
		if key.is_empty() or source == null:
			continue
		var registry_definition: Dictionary = schema.duplicate(true)
		registry_definition["id"] = "aim.cloned.%s" % key
		var schema_type: String = str(schema.get("type", ""))
		if schema_type == "bool":
			registry_definition["kind"] = "bool"
		elif schema_type == "select":
			registry_definition["kind"] = "select"
		else:
			registry_definition["kind"] = "number"
		registry_definition["locations"] = [_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, _get_cloned_aim_section(key))]
		registry_definition["getter"] = _get_control_value.bind(source, str(schema.get("type", "")))
		registry_definition["setter"] = _set_control_value.bind(source, str(schema.get("type", "")))
		dev_option_registry.register_option(registry_definition)


func _register_staged_deep_aim_actions() -> void:
	var locations: Array = [
		_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Staged Deep Prediction")
	]
	_register_direct_action_option(
		"aim.staging.force_deep_prediction",
		"Force Deep Prediction Now",
		locations,
		"Requests the current deep aim prediction immediately without changing staging configuration.",
		_force_deep_prediction_now,
		["run deep aim", "bypass settle delay", "staged prediction"]
	)
	_register_direct_action_option(
		"aim.staging.cancel_pending_prediction",
		"Cancel Pending Deep Prediction",
		locations,
		"Cancels the current pending deep prediction request without changing staging configuration.",
		_cancel_pending_deep_prediction,
		["stop deep aim", "clear pending", "staged prediction"]
	)


func _register_aim_benchmark_options() -> void:
	var locations: Array = [_dev_location(DevOptionsPanel.TAB_AIM_PHYSICS, "Player Aim Benchmark")]
	var preset_choices: Array = []
	for preset_value in AIM_TRAJECTORY_PREDICTOR_SCRIPT.get_benchmark_preset_definitions(4):
		var preset: Dictionary = preset_value
		preset_choices.append({
			"label": str(preset.get("label", "Preset")),
			"value": str(preset.get("id", "")),
			"description": str(preset.get("description", "Applies this benchmark configuration.")),
		})
	dev_option_registry.register_option({
		"id": "aim.benchmark.preset",
		"label": "Benchmark Preset",
		"kind": "select",
		"locations": locations,
		"description": "Selects a named production-like or deep-debug cloned aim configuration. Use Apply Preset to update the real predictor controls.",
		"keywords": ["long sight 5", "extended 10", "extended 20", "stress 40", "deep debug"],
		"choices": preset_choices,
		"getter": _get_selected_aim_benchmark_preset,
		"setter": _set_selected_aim_benchmark_preset,
	})
	dev_option_registry.register_option({
		"id": "aim.benchmark.apply_preset",
		"label": "Apply Preset",
		"kind": "action",
		"locations": locations,
		"description": "Applies the selected preset to the existing cloned aim controls. Every value remains editable afterward.",
		"keywords": ["load preset", "benchmark configuration"],
		"action": _apply_selected_aim_benchmark_preset,
	})
	dev_option_registry.register_option({
		"id": "aim.benchmark.label",
		"label": "Benchmark Label",
		"kind": "text",
		"locations": locations,
		"description": "Adds an optional human-readable setup label to the copied benchmark report.",
		"placeholder": "Round 2 - 3 balls - depth 10",
		"keywords": ["report name", "capture label"],
		"getter": _get_aim_benchmark_label,
		"setter": _set_aim_benchmark_label,
	})
	_register_direct_action_option(
		"aim.benchmark.reset",
		"Reset Benchmark Stats",
		locations,
		"Clears only the bounded player benchmark capture and report state.",
		_reset_aim_benchmark,
		["clear capture", "benchmark history"]
	)
	_register_direct_action_option(
		"aim.benchmark.start",
		"Start Benchmark Capture",
		locations,
		"Starts a fresh bounded capture and records only completed cloned prediction rebuilds after this action.",
		_start_aim_benchmark,
		["record benchmark", "begin capture"]
	)
	_register_direct_action_option(
		"aim.benchmark.stop",
		"Stop Benchmark Capture",
		locations,
		"Stops the active benchmark window and finalizes its duration and report statistics.",
		_stop_aim_benchmark,
		["finish capture", "finalize report"]
	)
	_register_direct_action_option(
		"aim.benchmark.copy",
		"Copy Benchmark Report",
		locations,
		"Copies a compact plain-text setup, timing, workload, cache, stop-reason, and contamination report to the system clipboard.",
		_copy_aim_benchmark_report,
		["clipboard", "performance report"]
	)


func _register_direct_action_option(
	option_id: String,
	label: String,
	locations: Array,
	description: String,
	action: Callable,
	keywords: Array = []
) -> void:
	if dev_option_registry.has_option(option_id):
		return
	dev_option_registry.register_option({
		"id": option_id,
		"label": label,
		"kind": "action",
		"locations": locations,
		"description": description,
		"keywords": keywords,
		"action": action,
	})


func _get_selected_aim_benchmark_preset() -> String:
	return selected_aim_benchmark_preset_id


func _set_selected_aim_benchmark_preset(value: Variant) -> void:
	selected_aim_benchmark_preset_id = str(value)


func _get_aim_benchmark_label() -> String:
	return aim_benchmark_label


func _set_aim_benchmark_label(value: Variant) -> void:
	aim_benchmark_label = str(value)


func _apply_selected_aim_benchmark_preset() -> void:
	var configuration: Dictionary = get_cloned_aim_configuration()
	var preset_configuration: Dictionary = AIM_TRAJECTORY_PREDICTOR_SCRIPT.get_benchmark_preset_configuration(
		selected_aim_benchmark_preset_id,
		4
	)
	# Player-facing presets measure the authored staged presentation. Deep Debug
	# deliberately preserves the developer's currently selected staging values.
	if selected_aim_benchmark_preset_id != AimTrajectoryPredictor.BENCHMARK_PRESET_DEEP_DEBUG:
		configuration.merge(
			AIM_STAGING_CONFIGURATION_SCRIPT.get_default_configuration(),
			true
		)
	configuration.merge(preset_configuration, true)
	_apply_cloned_aim_configuration(configuration)
	if debug_aim_line_check_box != null and not debug_aim_line_check_box.button_pressed:
		debug_aim_line_check_box.button_pressed = true
	if (
		str(configuration.get("result_detail_mode", ""))
		!= AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
		and verbose_aim_candidates_check_box != null
		and verbose_aim_candidates_check_box.button_pressed
	):
		verbose_aim_candidates_check_box.button_pressed = false
	if dev_option_registry != null:
		dev_option_registry.refresh_all()


func _reset_aim_benchmark() -> void:
	debug_reset_aim_benchmark_requested.emit()


func _start_aim_benchmark() -> void:
	var profile_control: Control = cloned_aim_controls.get("profile_enabled") as Control
	if profile_control is CheckBox and not (profile_control as CheckBox).button_pressed:
		(profile_control as CheckBox).button_pressed = true
	debug_start_aim_benchmark_requested.emit(
		aim_benchmark_label,
		AIM_TRAJECTORY_PREDICTOR_SCRIPT.get_benchmark_preset_label(
			selected_aim_benchmark_preset_id,
			4
		)
	)


func _stop_aim_benchmark() -> void:
	debug_stop_aim_benchmark_requested.emit()


func _copy_aim_benchmark_report() -> void:
	debug_copy_aim_benchmark_report_requested.emit()


func _force_deep_prediction_now() -> void:
	debug_force_deep_prediction_requested.emit()


func _cancel_pending_deep_prediction() -> void:
	debug_cancel_pending_deep_prediction_requested.emit()


func _get_cloned_aim_section(key: String) -> String:
	if key in [
		"use_cloned_settled_normal_aim",
		"immediate_to_cloned_blend_duration_ms",
	]:
		return "Aim Presentation"
	if key in [
		"use_staged_deep_prediction",
		"deep_aim_settle_delay_ms",
		"progressive_deep_aim_reveal",
		"deep_aim_reveal_duration_ms",
		"keep_stale_deep_aim_faintly_visible",
		"show_staging_status",
	]:
		return "Staged Deep Prediction"
	if key == "profile_enabled":
		return "Aim Profiler"
	if key in ["enabled", "use_legacy_long_sight_debug", "result_detail_mode"]:
		return "Cloned Predictor"
	if key in ["max_simulated_seconds", "simulation_frame_rate", "simulation_substeps", "max_physics_frames", "max_total_iterations", "max_geometry_probes", "max_processing_time_ms", "max_collision_events_per_substep"]:
		return "Simulation Timing & Work"
	if key in ["max_total_events", "max_ball_contacts", "max_cue_ball_contacts", "max_rail_contacts", "max_pocket_events", "max_tracked_balls", "max_child_generation_depth"]:
		return "Event & Contact Limits"
	if key in ["max_points_per_ball", "max_total_trace_points", "trace_point_spacing", "player_trace_spacing"]:
		return "Trace Limits"
	return "Aim Drawing"


func _register_bool_control(
	option_id: String,
	label: String,
	check_box: CheckBox,
	locations: Array,
	description: String,
	on_effect: String,
	off_effect: String,
	keywords: Array = [],
	aliases: Array = []
) -> void:
	if check_box == null or dev_option_registry.has_option(option_id):
		return
	dev_option_registry.register_option({
		"id": option_id,
		"label": label,
		"kind": "bool",
		"locations": locations,
		"description": description,
		"on_effect": on_effect,
		"off_effect": off_effect,
		"keywords": keywords,
		"aliases": aliases,
		"getter": _get_check_box_value.bind(check_box),
		"setter": _set_check_box_value.bind(check_box),
	})


func _register_action_option(option_id: String, label: String, button: Button, locations: Array, description: String, keywords: Array = [], aliases: Array = []) -> void:
	if button == null or dev_option_registry.has_option(option_id):
		return
	dev_option_registry.register_option({
		"id": option_id,
		"label": label,
		"kind": "action",
		"locations": locations,
		"description": description,
		"keywords": keywords,
		"aliases": aliases,
		"action": _press_debug_button.bind(button),
	})


func _register_select_control(option_id: String, label: String, selector: OptionButton, choices: Array, locations: Array, description: String, keywords: Array = [], disabled_getter: Callable = Callable()) -> void:
	if selector == null or dev_option_registry.has_option(option_id):
		return
	dev_option_registry.register_option({
		"id": option_id,
		"label": label,
		"kind": "select",
		"locations": locations,
		"description": description,
		"keywords": keywords,
		"choices": choices,
		"getter": _get_option_button_value.bind(selector),
		"setter": _set_option_button_value.bind(selector),
		"disabled_getter": disabled_getter,
	})


func _register_readout_option(option_id: String, label: String, source_label: Label, locations: Array, description: String, keywords: Array = []) -> void:
	if source_label == null or dev_option_registry.has_option(option_id):
		return
	dev_option_registry.register_option({
		"id": option_id,
		"label": label,
		"kind": "readout",
		"locations": locations,
		"description": description,
		"keywords": keywords,
		"getter": _get_label_text.bind(source_label),
	})


func _dev_location(tab_id: String, section: String) -> Dictionary:
	return {"tab_id": tab_id, "section": section}


func _make_contraband_choices() -> Array:
	var choices: Array = []
	var descriptions: Dictionary = {
		DEBUG_CONTRABAND_KIND_RANDOM: "Use the normal weighted Contraband table.",
		"wayfinder": "Force one Wayfinder Ball replacement.",
		"powder_keg": "Force one Powder Keg replacement.",
		"treasure": "Force one Treasure Ball replacement.",
		"cannon": "Force one Cannon Ball replacement.",
		"embezzler": "Force one Embezzler replacement when its cap permits.",
	}
	for item_value in DEBUG_CONTRABAND_SELECTOR_ITEMS:
		var item: Dictionary = item_value
		var kind: String = str(item.get("kind", DEBUG_CONTRABAND_KIND_RANDOM))
		choices.append({"label": str(item.get("label", "Random")), "value": kind, "description": str(descriptions.get(kind, "Select this replacement."))})
	return choices


func _make_oath_choices() -> Array:
	var choices: Array = []
	var descriptions: Dictionary = {
		OathSystem.OATH_OF_URGENCY: "Complete any Kraken Request before the shot timer expires.",
		OathSystem.OATH_OF_ISOLATION: "Temporarily locks Quartermaster purchases, refreshes, and Back Room access.",
		OathSystem.OATH_OF_SACRIFICE: "Exercises the eligible-ball loss failure path.",
		OathSystem.OATH_OF_HUMILITY: "Temporarily suppresses equipped cue gameplay modifiers.",
	}
	for item_value in OATH_TESTING_SELECTOR_ITEMS:
		var item: Dictionary = item_value
		var oath_id: String = str(item.get("oath_id", ""))
		choices.append({"label": str(item.get("label", "Oath")), "value": oath_id, "description": str(descriptions.get(oath_id, "Select this Oath for debug actions."))})
	return choices


func _get_check_box_value(check_box: CheckBox) -> bool:
	return check_box != null and check_box.button_pressed


func _is_contraband_selector_disabled() -> bool:
	return loose_cargo_contraband_selector == null or loose_cargo_contraband_selector.disabled


func _get_label_text(label: Label) -> String:
	return label.text if label != null else ""


func _set_check_box_value(value: Variant, check_box: CheckBox) -> void:
	if check_box == null:
		return
	var enabled: bool = bool(value)
	if check_box.button_pressed != enabled:
		check_box.button_pressed = enabled


func _press_debug_button(button: Button) -> void:
	if button != null and not button.disabled:
		button.pressed.emit()


func _get_option_button_value(selector: OptionButton) -> Variant:
	if selector == null or selector.selected < 0 or selector.selected >= selector.item_count:
		return ""
	return selector.get_item_metadata(selector.selected)


func _set_option_button_value(value: Variant, selector: OptionButton) -> void:
	_select_option_button_value(selector, value, true)


func _select_option_button_value(selector: OptionButton, value: Variant, emit_change: bool) -> void:
	if selector == null:
		return
	for item_index in range(selector.item_count):
		if selector.get_item_metadata(item_index) == value or str(selector.get_item_metadata(item_index)) == str(value):
			if selector.selected != item_index:
				selector.select(item_index)
				if emit_change:
					selector.item_selected.emit(item_index)
			return


func _get_control_value(control: Control, value_type: String) -> Variant:
	if control is CheckBox:
		return (control as CheckBox).button_pressed
	if control is SpinBox:
		var numeric_value: float = (control as SpinBox).value
		return int(numeric_value) if value_type == "int" else numeric_value
	if control is OptionButton:
		return _get_option_button_value(control as OptionButton)
	return null


func _set_control_value(value: Variant, control: Control, value_type: String) -> void:
	if control is CheckBox:
		_set_check_box_value(value, control as CheckBox)
	elif control is SpinBox:
		var numeric_value: float = float(value)
		if value_type == "int":
			numeric_value = float(int(numeric_value))
		if not is_equal_approx((control as SpinBox).value, numeric_value):
			(control as SpinBox).value = numeric_value
	elif control is OptionButton:
		_select_option_button_value(control as OptionButton, value, true)


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


func _make_debug_reserve_stack_payload(test_item: Dictionary) -> Dictionary:
	var quantity: int = maxi(int(test_item.get("quantity", 1)), 1)
	return {
		"item_id": str(test_item.get("item_id", "")),
		"item_name": str(test_item.get("item_name", "Reserve Item")),
		"display_name": str(test_item.get("display_name", test_item.get("item_name", "Reserve Item"))),
		"description": "Debug Reserve stack test payload.",
		"price": 0,
		"spawn_type": str(test_item.get("spawn_type", "")),
		"icon_key": str(test_item.get("icon_key", test_item.get("spawn_type", ""))),
		"source": "debug_reserve_stack_test",
		"quantity": quantity,
		"quantity_total": quantity,
	}


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
	if dev_options_panel != null:
		dev_options_panel.close_panel()
	shade.visible = true
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
	menu_panel.visible = false
	tab_bar.visible = false
	quartermaster_section.visible = false
	debug_section.visible = false
	quartermaster_tab_button.disabled = true
	debug_tab_button.disabled = true
	shade.color = NORMAL_SHADE_COLOR
	shade.visible = false
	if dev_options_panel != null:
		dev_options_panel.open_panel()


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
		var total_cost := maxi(int(record.get("total_charge_cost", record.get("total_cost", 0))), 0)
		if count <= 0:
			continue
		if count > 1:
			lines.append("%s x%s - %s Charges total" % [name, count, total_cost])
		else:
			lines.append("%s - %s Charge%s" % [name, total_cost, "" if total_cost == 1 else "s"])

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
	if dev_options_panel != null:
		dev_options_panel.close_panel()
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
	if dev_option_registry != null:
		dev_option_registry.refresh_option("cargo.contraband_kind")
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


func _on_pocket_capture_presentation_toggled(enabled: bool) -> void:
	debug_pocket_capture_presentation_toggled.emit(enabled)


func _on_clear_pocket_collections_pressed() -> void:
	debug_clear_pocket_collections_requested.emit()


func _on_pocket_collection_anchors_toggled(enabled: bool) -> void:
	debug_pocket_collection_anchors_toggled.emit(enabled)


func _on_reflow_pocket_collections_pressed() -> void:
	debug_reflow_pocket_collections_requested.emit()


func _on_debug_aim_line_toggled(enabled: bool) -> void:
	debug_aim_line_toggled.emit(enabled)


func _on_aim_compare_panels_toggled(enabled: bool) -> void:
	if aim_preview_check_box != null:
		aim_preview_check_box.set_pressed_no_signal(enabled)
		debug_panel_toggled.emit(PANEL_AIM_PREVIEW, enabled)
	debug_aim_compare_panels_toggled.emit(enabled)


func _on_verbose_aim_candidates_toggled(enabled: bool) -> void:
	debug_verbose_aim_candidates_toggled.emit(enabled)


func _on_cue_first_contact_toi_toggled(enabled: bool) -> void:
	debug_cue_first_contact_toi_toggled.emit(enabled)


func _on_reset_aim_profiler_pressed() -> void:
	debug_reset_aim_profiler_requested.emit()


func _on_reset_table_button_toggled(enabled: bool) -> void:
	debug_reset_table_button_toggled.emit(enabled)


func _on_reset_last_shot_button_toggled(enabled: bool) -> void:
	debug_reset_last_shot_button_toggled.emit(enabled)


func _on_back_room_force_available_toggled(enabled: bool) -> void:
	debug_back_room_force_available_toggled.emit(enabled)


func _on_open_back_room_deal_pressed() -> void:
	debug_back_room_open_requested.emit()


func _on_activate_long_sight_pressed() -> void:
	debug_activate_long_sight_requested.emit()


func _on_activate_krakens_patience_pressed() -> void:
	debug_activate_krakens_patience_requested.emit()


func _on_activate_deep_ledger_pressed() -> void:
	debug_activate_deep_ledger_requested.emit()


func _on_activate_iron_wake_pressed() -> void:
	debug_activate_iron_wake_requested.emit()


func _on_expire_all_boons_pressed() -> void:
	debug_expire_all_boons_requested.emit()


func _on_reserve_stack_test_pressed(test_index: int) -> void:
	if test_index < 0 or test_index >= RESERVE_STACK_TEST_ITEMS.size():
		return
	var test_item: Dictionary = RESERVE_STACK_TEST_ITEMS[test_index]
	debug_reserve_stack_payload_requested.emit(_make_debug_reserve_stack_payload(test_item))


func _on_sunken_spoils_advance_pressed() -> void:
	debug_sunken_spoils_advance_requested.emit()


func _on_sunken_spoils_trigger_pressed() -> void:
	debug_sunken_spoils_trigger_requested.emit()


func _on_sunken_spoils_reset_pressed() -> void:
	debug_sunken_spoils_reset_requested.emit()


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
