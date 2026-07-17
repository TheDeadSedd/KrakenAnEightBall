extends Control
class_name DebugOverlay

signal reset_table_requested
signal reset_last_shot_requested
signal dev_option_state_changed(option_id: String, value: Variant)
signal debug_notification_requested(text: String, category: String)

# Owns debug UI state, text formatting, and movable overlay behavior.
# Table.gd still owns the gameplay counters/data that this panel displays.
const DEBUG_MENU_TOGGLE_KEY := KEY_QUOTELEFT
const PERFORMANCE_OVERLAY_TOGGLE_KEY := KEY_F3
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
const PANEL_AIM_LAUNCH := "aim_launch"
const PANEL_AIM_CONTACT := "aim_contact"
const PANEL_AIM_RESPONSE := "aim_response"
const PANEL_AIM_TRACE := "aim_trace"
const PANEL_AIM_CANDIDATES := "aim_candidates"
const PANEL_AIM_COLLISIONS := "aim_collisions"
const PANEL_AIM_CONTACT_ORDER := "aim_contact_order"
const PANEL_AIM_SIMULATION := "aim_simulation"
const PANEL_AIM_PROFILER := "aim_profiler"
const PANEL_AIM_EVENT_CHAIN := "aim_event_chain"
const PANEL_SHOT_LEDGER := "shot_ledger"
const PANEL_AIM_COMPARE_GROUP := "aim_compare_panels"
const DEBUG_AIM_PANEL_LOG_MAX_ENTRIES := 16
const DEBUG_AIM_CANDIDATE_VERBOSE_MAX_ENTRIES := 64
const DEBUG_AIM_CANDIDATE_NORMAL_MAX_ENTRIES := 6
const AIM_PROFILER_PHASE_ROWS: Array[Dictionary] = [
	{"key": "input_snapshot", "label": "Input snapshot"},
	{"key": "cache_key_construction", "label": "Cache-key construction"},
	{"key": "cloned_state_setup", "label": "Cloned-state setup"},
	{"key": "broadphase_grid_work", "label": "Broadphase/grid work"},
	{"key": "movement_friction", "label": "Movement/friction"},
	{"key": "swept_toi_ball_collision", "label": "Swept TOI + ball collision"},
	{"key": "rail_pocket_processing", "label": "Rail/pocket processing"},
	{"key": "rail_processing", "label": "Boundaries total"},
	{"key": "pocket_processing", "label": "Pockets total"},
	{"key": "rail_overlap_resolution", "label": "Rail overlap resolution"},
	{"key": "cue_boundary_chronology", "label": "Cue boundary chronology"},
	{"key": "pocket_overlap_capture", "label": "Pocket overlap/capture"},
	{"key": "cue_pocket_chronology", "label": "Cue pocket chronology"},
	{"key": "boundary_candidate_gathering", "label": "Boundary candidates"},
	{"key": "rail_sweep_intersection_testing", "label": "Rail tests"},
	{"key": "jaw_corner_testing", "label": "Jaw tests"},
	{"key": "rail_response_calculation", "label": "Rail response"},
	{"key": "boundary_result_packaging", "label": "Boundary packaging"},
	{"key": "pocket_candidate_gathering", "label": "Pocket candidates"},
	{"key": "pocket_sweep_capture_testing", "label": "Pocket tests"},
	{"key": "pocket_resolution", "label": "Pocket resolution"},
	{"key": "pocket_result_packaging", "label": "Pocket packaging"},
	{"key": "cross_type_event_ordering", "label": "Cross-type ordering"},
	{"key": "trace_recording", "label": "Trace recording"},
	{"key": "trace_simplification", "label": "Trace simplification"},
	{"key": "event_result_packaging", "label": "Event-result packaging"},
	{"key": "predicted_actual_comparison", "label": "Predicted/actual comparison"},
	{"key": "draw_data_preparation", "label": "CPU draw-data preparation"},
	{"key": "total_simulation", "label": "Total simulation"},
	{"key": "total_full_rebuild", "label": "Total full rebuild"},
]
const TABLE_EVENT_TEST_BUTTON_SIZE := Vector2(132.0, 36.0)
const TABLE_EVENT_TEST_BUTTON_RIGHT_OFFSET := 304.0
const TABLE_EVENT_TEST_BUTTON_TOP := 532.0
const TABLE_EVENT_TEST_BUTTON_GAP := 8.0
const DEVELOPER_PREFERENCES_SCRIPT := preload("res://scripts/DeveloperPreferences.gd")
const FPS_UPDATE_INTERVAL := 0.25
const FPS_READOUT_SIZE := Vector2(116.0, 30.0)
const FPS_READOUT_MARGIN := Vector2(24.0, 18.0)
const FPS_READOUT_Z_INDEX := 30
const DEBUG_AIM_DISCLAIMER_Z_INDEX := 60
const DEBUG_AIM_DISCLAIMER_WIDTH := 660.0

@onready var physics_debug_panel: PanelContainer = $PhysicsDebugPanel
@onready var physics_debug_label: Label = $PhysicsDebugPanel/Margin/PhysicsDebugLabel
@onready var performance_overlay_panel: PanelContainer = $PerformanceOverlayPanel
@onready var performance_overlay_label: Label = $PerformanceOverlayPanel/Margin/PerformanceOverlayLabel
@onready var core_performance_panel: DebugPanel = $CorePerformancePanel
@onready var core_performance_label: Label = $CorePerformancePanel/Margin/CorePerformanceLabel
@onready var aim_preview_panel: DebugPanel = $AimPreviewPanel
@onready var aim_preview_label: Label = $AimPreviewPanel/Margin/AimPreviewPanelLabel
@onready var treasure_panel: DebugPanel = $TreasurePanel
@onready var treasure_label: Label = $TreasurePanel/Margin/TreasurePanelLabel
@onready var embezzler_panel: DebugPanel = $EmbezzlerPanel
@onready var embezzler_label: Label = $EmbezzlerPanel/Margin/EmbezzlerPanelLabel
@onready var anchor_panel: DebugPanel = $AnchorPanel
@onready var anchor_label: Label = $AnchorPanel/Margin/AnchorPanelLabel
@onready var ball_drops_score_panel: DebugPanel = $BallDropsScorePanel
@onready var ball_drops_score_label: Label = $BallDropsScorePanel/Margin/BallDropsScorePanelLabel
@onready var cannon_panel: DebugPanel = $CannonPanel
@onready var cannon_label: Label = $CannonPanel/Margin/CannonPanelLabel
@onready var powder_keg_wayfinder_panel: DebugPanel = $PowderKegWayfinderPanel
@onready var powder_keg_wayfinder_label: Label = $PowderKegWayfinderPanel/Margin/PowderKegWayfinderPanelLabel
@onready var visual_effects_panel: DebugPanel = $VisualEffectsPanel
@onready var visual_effects_label: Label = $VisualEffectsPanel/Margin/VisualEffectsPanelLabel
@onready var physics_performance_panel: DebugPanel = $PhysicsPerformancePanel
@onready var physics_performance_label: Label = $PhysicsPerformancePanel/Margin/PhysicsPerformancePanelLabel
@onready var debug_menu_panel: PanelContainer = $DebugMenuPanel
@onready var shot_path_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/ShotPathCheckBox
@onready var physics_debug_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/PhysicsDebugCheckBox
@onready var performance_overlay_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/PerformanceOverlayCheckBox
@onready var anchor_visuals_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/AnchorVisualsCheckBox
@onready var anchor_debug_visual_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/AnchorDebugVisualCheckBox
@onready var anchor_single_latch_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/AnchorSingleLatchCheckBox
@onready var treasure_debug_visual_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/TreasureDebugVisualCheckBox
@onready var powder_keg_particles_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/PowderKegParticlesCheckBox
@onready var powder_keg_reduced_particles_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/PowderKegReducedParticlesCheckBox
@onready var powder_keg_suppress_trails_check_box: CheckBox = $DebugMenuPanel/Margin/VBox/PowderKegSuppressTrailsCheckBox
@onready var debug_hotkey_label: Label = $DebugMenuPanel/Margin/VBox/DebugHotkeyLabel

var table: BilliardsTable
var last_debug_overlay_refresh_ms := 0.0
var wayfinder_current_test_button: Button
var broadside_attack_test_button: Button
var reset_table_button: Button
var reset_last_shot_button: Button
var aim_launch_panel: DebugPanel
var aim_launch_label: Label
var aim_contact_panel: DebugPanel
var aim_contact_label: Label
var aim_response_panel: DebugPanel
var aim_response_label: Label
var aim_trace_panel: DebugPanel
var aim_trace_label: Label
var aim_candidates_panel: DebugPanel
var aim_candidates_label: Label
var aim_collisions_panel: DebugPanel
var aim_collisions_label: Label
var aim_contact_order_panel: DebugPanel
var aim_contact_order_label: Label
var aim_simulation_panel: DebugPanel
var aim_simulation_label: Label
var aim_profiler_panel: DebugPanel
var aim_profiler_label: Label
var aim_event_chain_panel: DebugPanel
var aim_event_chain_label: Label
var shot_ledger_panel: DebugPanel
var shot_ledger_label: Label
var shot_lab_panel: ShotLabPanel
var shot_ledger_raw_events_panel: ShotLedgerRawEventsPanel
var verbose_aim_candidates := false
var developer_preferences: DeveloperPreferences
var fps_label: Label
var debug_aim_mode_disclaimer: PanelContainer
var debug_aim_mode_disclaimer_label: Label
var fps_update_accumulator := 0.0
var default_panel_positions: Dictionary = {}
var default_panel_sizes: Dictionary = {}


func setup(table_ref: BilliardsTable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	table = table_ref
	debug_menu_panel.visible = false
	physics_debug_panel.visible = false
	performance_overlay_panel.visible = false
	_ensure_aim_compare_panels()
	_ensure_shot_ledger_panel()
	_configure_resizable_debug_panels()
	_capture_default_debug_panel_layout()
	_set_all_modular_debug_panels_visible(false)
	shot_path_check_box.set_pressed_no_signal(table.is_shot_path_debug_enabled())
	physics_debug_check_box.set_pressed_no_signal(false)
	performance_overlay_check_box.set_pressed_no_signal(false)
	anchor_visuals_check_box.set_pressed_no_signal(table.anchor_ball_system.are_anchor_visuals_enabled())
	anchor_debug_visual_check_box.set_pressed_no_signal(table.anchor_ball_system.is_debug_visual_enabled())
	anchor_single_latch_check_box.set_pressed_no_signal(table.anchor_ball_system.is_single_latch_per_target_enabled())
	anchor_debug_visual_check_box.visible = false
	anchor_single_latch_check_box.visible = false
	treasure_debug_visual_check_box.set_pressed_no_signal(table.treasure_ball_system.is_debug_visual_enabled())
	_sync_powder_keg_debug_toggles()
	_ensure_on_table_debug_buttons()
	debug_hotkey_label.text = _make_debug_hotkey_text()
	_connect_debug_controls()
	_ensure_fps_readout()
	_ensure_debug_aim_mode_disclaimer()
	if not table.debug_aim_mode_changed.is_connected(_on_debug_aim_mode_changed):
		table.debug_aim_mode_changed.connect(_on_debug_aim_mode_changed)
	_on_debug_aim_mode_changed(table.get_debug_aim_mode_snapshot())
	if table.shot_lab_system != null and not table.shot_lab_system.status_changed.is_connected(_on_shot_lab_status_changed):
		table.shot_lab_system.status_changed.connect(_on_shot_lab_status_changed)
	developer_preferences = DEVELOPER_PREFERENCES_SCRIPT.new() as DeveloperPreferences
	developer_preferences.load_preferences()
	_set_show_fps(developer_preferences.show_fps, false)


func _connect_debug_controls() -> void:
	if not shot_path_check_box.toggled.is_connected(_on_shot_path_debug_toggled):
		shot_path_check_box.toggled.connect(_on_shot_path_debug_toggled)
	if not physics_debug_check_box.toggled.is_connected(_on_physics_debug_toggled):
		physics_debug_check_box.toggled.connect(_on_physics_debug_toggled)
	if not performance_overlay_check_box.toggled.is_connected(_on_performance_overlay_toggled):
		performance_overlay_check_box.toggled.connect(_on_performance_overlay_toggled)
	if not anchor_visuals_check_box.toggled.is_connected(_on_anchor_visuals_toggled):
		anchor_visuals_check_box.toggled.connect(_on_anchor_visuals_toggled)
	if not anchor_debug_visual_check_box.toggled.is_connected(_on_anchor_debug_visual_toggled):
		anchor_debug_visual_check_box.toggled.connect(_on_anchor_debug_visual_toggled)
	if not anchor_single_latch_check_box.toggled.is_connected(_on_anchor_single_latch_toggled):
		anchor_single_latch_check_box.toggled.connect(_on_anchor_single_latch_toggled)
	if not treasure_debug_visual_check_box.toggled.is_connected(_on_treasure_debug_visual_toggled):
		treasure_debug_visual_check_box.toggled.connect(_on_treasure_debug_visual_toggled)
	if not powder_keg_particles_check_box.toggled.is_connected(_on_powder_keg_particles_toggled):
		powder_keg_particles_check_box.toggled.connect(_on_powder_keg_particles_toggled)
	if not powder_keg_reduced_particles_check_box.toggled.is_connected(_on_powder_keg_reduced_particles_toggled):
		powder_keg_reduced_particles_check_box.toggled.connect(_on_powder_keg_reduced_particles_toggled)
	if not powder_keg_suppress_trails_check_box.toggled.is_connected(_on_powder_keg_suppress_trails_toggled):
		powder_keg_suppress_trails_check_box.toggled.connect(_on_powder_keg_suppress_trails_toggled)
	if wayfinder_current_test_button != null and not wayfinder_current_test_button.pressed.is_connected(_on_wayfinder_current_test_button_pressed):
		wayfinder_current_test_button.pressed.connect(_on_wayfinder_current_test_button_pressed)
	if broadside_attack_test_button != null and not broadside_attack_test_button.pressed.is_connected(_on_broadside_attack_test_button_pressed):
		broadside_attack_test_button.pressed.connect(_on_broadside_attack_test_button_pressed)
	if reset_table_button != null and not reset_table_button.pressed.is_connected(_on_reset_table_button_pressed):
		reset_table_button.pressed.connect(_on_reset_table_button_pressed)
	if reset_last_shot_button != null and not reset_last_shot_button.pressed.is_connected(_on_reset_last_shot_button_pressed):
		reset_last_shot_button.pressed.connect(_on_reset_last_shot_button_pressed)


func _ensure_debug_aim_mode_disclaimer() -> void:
	if debug_aim_mode_disclaimer != null:
		return
	debug_aim_mode_disclaimer = PanelContainer.new()
	debug_aim_mode_disclaimer.name = "DebugAimModeDisclaimer"
	debug_aim_mode_disclaimer.z_index = DEBUG_AIM_DISCLAIMER_Z_INDEX
	debug_aim_mode_disclaimer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_aim_mode_disclaimer.anchor_left = 0.5
	debug_aim_mode_disclaimer.anchor_top = 0.0
	debug_aim_mode_disclaimer.anchor_right = 0.5
	debug_aim_mode_disclaimer.anchor_bottom = 0.0
	debug_aim_mode_disclaimer.offset_left = -DEBUG_AIM_DISCLAIMER_WIDTH * 0.5
	debug_aim_mode_disclaimer.offset_top = 18.0
	debug_aim_mode_disclaimer.offset_right = DEBUG_AIM_DISCLAIMER_WIDTH * 0.5
	debug_aim_mode_disclaimer.offset_bottom = 78.0
	var panel_style: StyleBox = aim_preview_panel.get_theme_stylebox("panel")
	if panel_style != null:
		debug_aim_mode_disclaimer.add_theme_stylebox_override("panel", panel_style)
	add_child(debug_aim_mode_disclaimer)

	debug_aim_mode_disclaimer_label = Label.new()
	debug_aim_mode_disclaimer_label.name = "DisclaimerLabel"
	debug_aim_mode_disclaimer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_aim_mode_disclaimer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	debug_aim_mode_disclaimer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debug_aim_mode_disclaimer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_aim_mode_disclaimer_label.add_theme_font_override(
		"font",
		aim_preview_label.get_theme_font("font")
	)
	debug_aim_mode_disclaimer_label.add_theme_font_size_override("font_size", 13)
	debug_aim_mode_disclaimer_label.add_theme_color_override("font_color", Color("e8c66a"))
	debug_aim_mode_disclaimer.add_child(debug_aim_mode_disclaimer_label)
	debug_aim_mode_disclaimer.visible = false


func _on_debug_aim_mode_changed(snapshot: Dictionary) -> void:
	if debug_aim_mode_disclaimer == null or debug_aim_mode_disclaimer_label == null:
		return
	var enabled: bool = bool(snapshot.get("enabled", false))
	debug_aim_mode_disclaimer.visible = enabled
	if not enabled:
		return
	var converted: int = int(snapshot.get("anomalies_converted_this_session", 0))
	var normalized: int = int(snapshot.get("anomaly_spawn_requests_normalized", 0))
	debug_aim_mode_disclaimer_label.text = (
		"DEBUG AIM MODE: ANOMALIES DISABLED\n"
		+ "Converted: %d  |  Future spawns normalized: %d  |  Converted balls stay ordinary"
		% [converted, normalized]
	)


func _ensure_aim_compare_panels() -> void:
	if aim_launch_panel != null:
		return

	aim_launch_panel = _make_runtime_debug_panel("AimLaunchPanel", Vector2(478.0, 430.0), Vector2(420.0, 180.0))
	aim_launch_label = _make_runtime_debug_label("AimLaunchPanelLabel", "AIM LAUNCH")
	_add_label_to_runtime_panel(aim_launch_panel, aim_launch_label)

	aim_contact_panel = _make_runtime_debug_panel("AimContactPanel", Vector2(916.0, 430.0), Vector2(430.0, 242.0))
	aim_contact_label = _make_runtime_debug_label("AimContactPanelLabel", "AIM CONTACT")
	_add_label_to_runtime_panel(aim_contact_panel, aim_contact_label)

	aim_response_panel = _make_runtime_debug_panel("AimResponsePanel", Vector2(478.0, 626.0), Vector2(420.0, 230.0))
	aim_response_label = _make_runtime_debug_label("AimResponsePanelLabel", "AIM RESPONSE")
	_add_label_to_runtime_panel(aim_response_panel, aim_response_label)

	aim_trace_panel = _make_runtime_debug_panel("AimTracePanel", Vector2(916.0, 690.0), Vector2(330.0, 226.0))
	aim_trace_label = _make_runtime_debug_label("AimTracePanelLabel", "AIM TRACE")
	_add_label_to_runtime_panel(aim_trace_panel, aim_trace_label)

	aim_candidates_panel = _make_runtime_debug_panel("AimCandidatesPanel", Vector2(1262.0, 430.0), Vector2(300.0, 486.0))
	aim_candidates_label = _make_runtime_debug_label("AimCandidatesPanelLabel", "AIM CANDIDATES")
	_add_scroll_label_to_runtime_panel(aim_candidates_panel, aim_candidates_label)

	aim_collisions_panel = _make_runtime_debug_panel("AimCollisionsPanel", Vector2(1578.0, 430.0), Vector2(310.0, 486.0))
	aim_collisions_label = _make_runtime_debug_label("AimCollisionsPanelLabel", "AIM COLLISIONS")
	_add_scroll_label_to_runtime_panel(aim_collisions_panel, aim_collisions_label)

	aim_contact_order_panel = _make_runtime_debug_panel("AimContactOrderPanel", Vector2(1210.0, 40.0), Vector2(360.0, 370.0))
	aim_contact_order_label = _make_runtime_debug_label("AimContactOrderPanelLabel", "AIM CONTACT ORDER")
	_add_scroll_label_to_runtime_panel(aim_contact_order_panel, aim_contact_order_label)

	aim_simulation_panel = _make_runtime_debug_panel("AimSimulationPanel", Vector2(40.0, 430.0), Vector2(420.0, 300.0))
	aim_simulation_label = _make_runtime_debug_label("AimSimulationPanelLabel", "AIM SIMULATION")
	_add_scroll_label_to_runtime_panel(aim_simulation_panel, aim_simulation_label)

	aim_profiler_panel = _make_runtime_debug_panel("AimProfilerPanel", Vector2(570.0, 40.0), Vector2(620.0, 370.0))
	aim_profiler_label = _make_runtime_debug_label("AimProfilerPanelLabel", "AIM PROFILER")
	_add_scroll_label_to_runtime_panel(aim_profiler_panel, aim_profiler_label)

	aim_event_chain_panel = _make_runtime_debug_panel("AimEventChainPanel", Vector2(40.0, 746.0), Vector2(520.0, 280.0))
	aim_event_chain_label = _make_runtime_debug_label("AimEventChainPanelLabel", "AIM EVENT CHAIN")
	_add_scroll_label_to_runtime_panel(aim_event_chain_panel, aim_event_chain_label)


func _ensure_shot_ledger_panel() -> void:
	if shot_ledger_panel != null:
		return
	shot_ledger_panel = _make_runtime_debug_panel(
		"ShotLedgerPanel",
		Vector2(1320.0, 48.0),
		Vector2(500.0, 620.0)
	)
	shot_ledger_label = _make_runtime_debug_label("ShotLedgerPanelLabel", "SHOT LEDGER")
	_add_scroll_label_to_runtime_panel(shot_ledger_panel, shot_ledger_label)


func _ensure_shot_lab_panels() -> void:
	if shot_lab_panel != null:
		return
	shot_lab_panel = ShotLabPanel.new()
	shot_lab_panel.name = "ShotLabPanel"
	add_child(shot_lab_panel)
	shot_lab_panel.setup(table.shot_lab_system)
	if not shot_lab_panel.raw_events_requested.is_connected(open_shot_lab_raw_events):
		shot_lab_panel.raw_events_requested.connect(open_shot_lab_raw_events)
	shot_ledger_raw_events_panel = ShotLedgerRawEventsPanel.new()
	shot_ledger_raw_events_panel.name = "ShotLedgerRawEventsPanel"
	add_child(shot_ledger_raw_events_panel)
	shot_ledger_raw_events_panel.setup(table.shot_ledger_system, table.shot_lab_system)


func open_shot_lab_inspector() -> void:
	_ensure_shot_lab_panels()
	if shot_lab_panel != null:
		shot_lab_panel.open_panel()


func open_shot_lab_scoring_inspector() -> void:
	_ensure_shot_lab_panels()
	if shot_lab_panel != null:
		shot_lab_panel.open_scoring_panel()


func open_shot_lab_raw_events() -> void:
	_ensure_shot_lab_panels()
	if shot_ledger_raw_events_panel != null:
		shot_ledger_raw_events_panel.open_panel()


func close_shot_lab_inspectors() -> void:
	if shot_lab_panel != null:
		shot_lab_panel.close_panel()
	if shot_ledger_raw_events_panel != null:
		shot_ledger_raw_events_panel.close_panel()


func _on_shot_lab_status_changed(message: String) -> void:
	print(message)
	debug_notification_requested.emit(message, "event")


func _configure_resizable_debug_panels() -> void:
	for panel_id in _get_positionable_panel_ids():
		var panel: DebugPanel = _get_modular_debug_panel(panel_id) as DebugPanel
		var label: Label = _get_modular_debug_label(panel_id)
		if panel == null or label == null:
			continue
		var minimum_size := Vector2(240.0, 130.0)
		if panel_id in [PANEL_AIM_CANDIDATES, PANEL_AIM_COLLISIONS, PANEL_AIM_CONTACT_ORDER, PANEL_AIM_SIMULATION, PANEL_AIM_PROFILER, PANEL_AIM_EVENT_CHAIN, PANEL_SHOT_LEDGER]:
			minimum_size = Vector2(260.0, 160.0)
		panel.set_minimum_resize_size(minimum_size)
		panel.configure_adaptive_label(label, true, 7)


func _make_runtime_debug_panel(panel_name: String, panel_position: Vector2, panel_size: Vector2) -> DebugPanel:
	var panel := DebugPanel.new()
	panel.name = panel_name
	panel.visible = false
	panel.z_index = 120
	panel.position = panel_position
	panel.size = panel_size
	panel.custom_minimum_size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style_box: StyleBox = aim_preview_panel.get_theme_stylebox("panel")
	if style_box != null:
		panel.add_theme_stylebox_override("panel", style_box)
	add_child(panel)
	return panel


func _make_runtime_debug_label(label_name: String, default_text: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = default_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", aim_preview_label.get_theme_color("font_color"))
	label.add_theme_color_override("font_shadow_color", aim_preview_label.get_theme_color("font_shadow_color"))
	label.add_theme_color_override("font_outline_color", aim_preview_label.get_theme_color("font_outline_color"))
	label.add_theme_constant_override("shadow_offset_x", aim_preview_label.get_theme_constant("shadow_offset_x"))
	label.add_theme_constant_override("shadow_offset_y", aim_preview_label.get_theme_constant("shadow_offset_y"))
	label.add_theme_constant_override("outline_size", aim_preview_label.get_theme_constant("outline_size"))
	label.add_theme_font_override("font", aim_preview_label.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", aim_preview_label.get_theme_font_size("font_size"))
	return label


func _add_label_to_runtime_panel(panel: DebugPanel, label: Label) -> void:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	margin.add_child(label)


func _add_scroll_label_to_runtime_panel(panel: DebugPanel, label: Label) -> void:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(scroll)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(264.0, 0.0)
	scroll.add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	var pause_menu_node: Node = get_node_or_null("PauseMenu")
	if pause_menu_node != null and pause_menu_node.has_method("is_dev_options_open") and bool(pause_menu_node.call("is_dev_options_open")):
		return
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == DEBUG_MENU_TOGGLE_KEY:
		_toggle_debug_menu()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == PERFORMANCE_OVERLAY_TOGGLE_KEY:
		_toggle_performance_overlay()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_fps_readout(delta)
	if table == null:
		return

	var refresh_start_usec: int = Time.get_ticks_usec()
	var refreshed_debug_text := false
	if physics_debug_panel.visible:
		physics_debug_label.text = _make_physics_debug_text()
		refreshed_debug_text = true

	var full_performance_visible := performance_overlay_panel.visible
	var modular_performance_visible := _has_visible_modular_debug_panels()
	if full_performance_visible:
		var snapshot: Dictionary = _get_performance_snapshot_with_debug_overlay_metrics()
		performance_overlay_label.text = _make_performance_debug_text_from_snapshot(snapshot)
		if modular_performance_visible:
			_refresh_visible_modular_debug_panels(snapshot)
		refreshed_debug_text = true
	elif modular_performance_visible:
		var requested_sections: Dictionary = _get_visible_modular_performance_sections()
		if not requested_sections.is_empty():
			var snapshot: Dictionary = _get_performance_snapshot_with_debug_overlay_metrics(requested_sections)
			_refresh_visible_modular_debug_panels(snapshot)
			refreshed_debug_text = true
	if shot_ledger_panel != null and shot_ledger_panel.visible:
		_refresh_modular_debug_panel(PANEL_SHOT_LEDGER, {})
		refreshed_debug_text = true

	last_debug_overlay_refresh_ms = _elapsed_ms_since(refresh_start_usec) if refreshed_debug_text else 0.0


func get_dev_option_state(option_id: String) -> Variant:
	if table != null and table.shot_lab_system != null:
		if option_id == "shot_lab.selected_preset":
			return table.shot_lab_system.get_selected_preset_id()
		if option_id.begins_with("shot_lab.option."):
			return table.shot_lab_system.get_option(option_id.trim_prefix("shot_lab.option."))
	if option_id == "panel.aim_compare_panels":
		return _are_aim_compare_panels_visible()
	if option_id.begins_with("panel."):
		var panel: Control = _get_modular_debug_panel(option_id.trim_prefix("panel."))
		return panel != null and panel.visible
	match option_id:
		"overlay.show_fps":
			return fps_label != null and fps_label.visible
		"overlay.shot_path":
			return shot_path_check_box.button_pressed
		"overlay.physics_debug":
			return physics_debug_check_box.button_pressed
		"overlay.performance":
			return performance_overlay_check_box.button_pressed
		"overlay.quick_menu":
			return debug_menu_panel.visible
		"anchor.visuals":
			return anchor_visuals_check_box.button_pressed
		"anchor.debug_visual":
			return anchor_debug_visual_check_box.button_pressed
		"anchor.single_latch":
			return anchor_single_latch_check_box.button_pressed
		"treasure.debug_visual":
			return treasure_debug_visual_check_box.button_pressed
		"powder.particles":
			return powder_keg_particles_check_box.button_pressed
		"powder.reduced_particles":
			return powder_keg_reduced_particles_check_box.button_pressed
		"powder.suppress_trails":
			return powder_keg_suppress_trails_check_box.button_pressed
	return false


func get_shot_lab_preset_choices() -> Array:
	if table == null or table.shot_lab_system == null:
		return []
	return table.shot_lab_system.get_preset_choices()


func set_dev_option_state(option_id: String, value: Variant) -> void:
	if table != null and table.shot_lab_system != null:
		if option_id == "shot_lab.selected_preset":
			table.shot_lab_system.set_selected_preset_id(str(value))
			dev_option_state_changed.emit(option_id, str(value))
			return
		if option_id.begins_with("shot_lab.option."):
			table.shot_lab_system.set_option(option_id.trim_prefix("shot_lab.option."), bool(value))
			dev_option_state_changed.emit(option_id, bool(value))
			return
	var enabled: bool = bool(value)
	if option_id == "panel.aim_compare_panels":
		set_aim_compare_panels_visible(enabled)
		return
	if option_id.begins_with("panel."):
		set_modular_debug_panel_visible(option_id.trim_prefix("panel."), enabled)
		return
	match option_id:
		"overlay.show_fps":
			_set_show_fps(enabled, true)
		"overlay.shot_path":
			_set_quick_toggle(shot_path_check_box, enabled, option_id)
		"overlay.physics_debug":
			_set_quick_toggle(physics_debug_check_box, enabled, option_id)
		"overlay.performance":
			_set_quick_toggle(performance_overlay_check_box, enabled, option_id)
		"overlay.quick_menu":
			if debug_menu_panel.visible != enabled:
				debug_menu_panel.visible = enabled
			dev_option_state_changed.emit(option_id, enabled)
		"anchor.visuals":
			_set_quick_toggle(anchor_visuals_check_box, enabled, option_id)
		"anchor.debug_visual":
			_set_quick_toggle(anchor_debug_visual_check_box, enabled, option_id)
		"anchor.single_latch":
			_set_quick_toggle(anchor_single_latch_check_box, enabled, option_id)
		"treasure.debug_visual":
			_set_quick_toggle(treasure_debug_visual_check_box, enabled, option_id)
		"powder.particles":
			_set_quick_toggle(powder_keg_particles_check_box, enabled, option_id)
		"powder.reduced_particles":
			_set_quick_toggle(powder_keg_reduced_particles_check_box, enabled, option_id)
		"powder.suppress_trails":
			_set_quick_toggle(powder_keg_suppress_trails_check_box, enabled, option_id)


func trigger_dev_option_action(option_id: String) -> bool:
	match option_id:
		"panels.hide_all":
			hide_all_debug_panels()
		"panels.reset_layout":
			reset_debug_panel_layout()
		"shot_ledger.copy_summary":
			_copy_last_shot_ledger_summary()
		"shot_ledger.copy_json":
			_copy_last_shot_ledger_json()
		"shot_ledger.run_self_test":
			_run_shot_ledger_self_test()
		"shot_ledger.clear_diagnostics":
			_clear_shot_ledger_diagnostics()
		"shot_ledger.copy_lifecycle":
			_copy_shot_ledger_lifecycle()
		"shot_ledger.open_raw_events":
			open_shot_lab_raw_events()
		"shot_ledger.copy_raw_events":
			_copy_all_shot_ledger_raw_events()
		"shot_lab.open":
			open_shot_lab_inspector()
		"shot_lab.load":
			table.shot_lab_system.load_selected_setup()
		"shot_lab.fire":
			table.shot_lab_system.fire_reference_shot()
		"shot_lab.reset_setup":
			table.shot_lab_system.reset_selected_setup()
		"shot_lab.reset_last_shot":
			table.shot_lab_system.reset_last_shot()
		"shot_lab.rerun":
			table.shot_lab_system.rerun_last_reference_shot()
		"shot_lab.clear":
			table.shot_lab_system.clear_shot_lab()
		"shot_lab.copy_result":
			table.shot_lab_system.copy_last_result()
		"shot_lab.copy_arrangement":
			table.shot_lab_system.copy_current_arrangement_as_preset()
		"shot_lab.run_suite":
			table.shot_lab_system.run_reference_suite()
		"shot_lab.cancel_suite":
			table.shot_lab_system.cancel_reference_suite("dev_options")
		_:
			_report_debug_action_error("Dev Options action callback missing: %s" % option_id)
			return false
	return true


func hide_all_debug_panels() -> void:
	for panel_id in _get_positionable_panel_ids():
		set_modular_debug_panel_visible(panel_id, false)
	if shot_lab_panel != null:
		shot_lab_panel.close_panel()
	if shot_ledger_raw_events_panel != null:
		shot_ledger_raw_events_panel.close_panel()
	_set_quick_toggle(physics_debug_check_box, false, "overlay.physics_debug")
	_set_quick_toggle(performance_overlay_check_box, false, "overlay.performance")
	if debug_menu_panel.visible:
		debug_menu_panel.visible = false
	dev_option_state_changed.emit("overlay.quick_menu", false)


func reset_debug_panel_layout() -> void:
	_apply_debug_panel_positions(default_panel_positions)
	_apply_debug_panel_sizes(default_panel_sizes)


func _set_quick_toggle(check_box: CheckBox, enabled: bool, option_id: String) -> void:
	if check_box == null:
		return
	if check_box.button_pressed != enabled:
		check_box.button_pressed = enabled
	else:
		dev_option_state_changed.emit(option_id, enabled)


func _capture_default_debug_panel_layout() -> void:
	default_panel_positions = _get_debug_panel_positions()
	default_panel_sizes = _get_debug_panel_sizes()


func _ensure_fps_readout() -> void:
	if fps_label != null:
		return
	fps_label = Label.new()
	fps_label.name = "FPSReadout"
	fps_label.text = "FPS: --"
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.z_index = FPS_READOUT_Z_INDEX
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -FPS_READOUT_MARGIN.x - FPS_READOUT_SIZE.x
	fps_label.offset_right = -FPS_READOUT_MARGIN.x
	fps_label.offset_top = FPS_READOUT_MARGIN.y
	fps_label.offset_bottom = FPS_READOUT_MARGIN.y + FPS_READOUT_SIZE.y
	fps_label.add_theme_font_override("font", debug_hotkey_label.get_theme_font("font"))
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.62, 0.96))
	fps_label.add_theme_color_override("font_outline_color", Color(0.02, 0.025, 0.03, 0.92))
	fps_label.add_theme_constant_override("outline_size", 2)
	add_child(fps_label)


func _set_show_fps(enabled: bool, persist: bool) -> void:
	_ensure_fps_readout()
	if fps_label != null:
		fps_label.visible = enabled
	if persist and developer_preferences != null:
		developer_preferences.set_show_fps(enabled)
	if enabled:
		fps_update_accumulator = FPS_UPDATE_INTERVAL
	dev_option_state_changed.emit("overlay.show_fps", enabled)


func _update_fps_readout(delta: float) -> void:
	if fps_label == null or not fps_label.visible:
		return
	fps_update_accumulator += delta
	if fps_update_accumulator < FPS_UPDATE_INTERVAL:
		return
	fps_update_accumulator = fmod(fps_update_accumulator, FPS_UPDATE_INTERVAL)
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func set_modular_debug_panel_visible(panel_id: String, enabled: bool) -> void:
	var panel: Control = _get_modular_debug_panel(panel_id)
	if panel == null:
		return

	panel.visible = enabled
	if enabled and table != null:
		var requested_sections: Dictionary = _get_modular_panel_performance_sections(panel_id)
		_refresh_modular_debug_panel(panel_id, _get_performance_snapshot_with_debug_overlay_metrics(requested_sections))
	dev_option_state_changed.emit("panel.%s" % panel_id, enabled)
	if panel_id.begins_with("aim_"):
		dev_option_state_changed.emit("panel.aim_compare_panels", _are_aim_compare_panels_visible())


func set_aim_compare_panels_visible(enabled: bool) -> void:
	_set_aim_compare_panels_visible(enabled)
	if enabled and table != null:
		var requested_sections: Dictionary = _get_modular_panel_performance_sections(PANEL_AIM_LAUNCH)
		var snapshot: Dictionary = _get_performance_snapshot_with_debug_overlay_metrics(requested_sections)
		_refresh_modular_debug_panel(PANEL_AIM_LAUNCH, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_CONTACT, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_RESPONSE, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_TRACE, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_CANDIDATES, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_COLLISIONS, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_CONTACT_ORDER, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_SIMULATION, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_PROFILER, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_EVENT_CHAIN, snapshot)
	for panel_id in [PANEL_AIM_PREVIEW, PANEL_AIM_LAUNCH, PANEL_AIM_CONTACT, PANEL_AIM_RESPONSE, PANEL_AIM_TRACE, PANEL_AIM_CANDIDATES, PANEL_AIM_COLLISIONS, PANEL_AIM_CONTACT_ORDER, PANEL_AIM_SIMULATION, PANEL_AIM_PROFILER, PANEL_AIM_EVENT_CHAIN]:
		dev_option_state_changed.emit("panel.%s" % panel_id, enabled)
	dev_option_state_changed.emit("panel.aim_compare_panels", _are_aim_compare_panels_visible())


func _set_aim_compare_panels_visible(enabled: bool) -> void:
	if aim_preview_panel != null:
		aim_preview_panel.visible = enabled
	if aim_launch_panel != null:
		aim_launch_panel.visible = enabled
	if aim_contact_panel != null:
		aim_contact_panel.visible = enabled
	if aim_response_panel != null:
		aim_response_panel.visible = enabled
	if aim_trace_panel != null:
		aim_trace_panel.visible = enabled
	if aim_candidates_panel != null:
		aim_candidates_panel.visible = enabled
	if aim_collisions_panel != null:
		aim_collisions_panel.visible = enabled
	if aim_contact_order_panel != null:
		aim_contact_order_panel.visible = enabled
	if aim_simulation_panel != null:
		aim_simulation_panel.visible = enabled
	if aim_profiler_panel != null:
		aim_profiler_panel.visible = enabled
	if aim_event_chain_panel != null:
		aim_event_chain_panel.visible = enabled


func _are_aim_compare_panels_visible() -> bool:
	return (
		(aim_launch_panel != null and aim_launch_panel.visible)
		or (aim_contact_panel != null and aim_contact_panel.visible)
		or (aim_response_panel != null and aim_response_panel.visible)
		or (aim_trace_panel != null and aim_trace_panel.visible)
		or (aim_candidates_panel != null and aim_candidates_panel.visible)
		or (aim_collisions_panel != null and aim_collisions_panel.visible)
		or (aim_contact_order_panel != null and aim_contact_order_panel.visible)
		or (aim_simulation_panel != null and aim_simulation_panel.visible)
		or (aim_profiler_panel != null and aim_profiler_panel.visible)
		or (aim_event_chain_panel != null and aim_event_chain_panel.visible)
	)


func get_modular_debug_panel_states() -> Dictionary:
	return {
		PANEL_CORE_PERFORMANCE: core_performance_panel.visible,
		PANEL_AIM_PREVIEW: aim_preview_panel.visible,
		PANEL_TREASURE: treasure_panel.visible,
		PANEL_EMBEZZLER: embezzler_panel.visible,
		PANEL_ANCHOR: anchor_panel.visible,
		PANEL_BALL_DROPS_SCORE: ball_drops_score_panel.visible,
		PANEL_CANNON: cannon_panel.visible,
		PANEL_POWDER_KEG_WAYFINDER: powder_keg_wayfinder_panel.visible,
		PANEL_VISUAL_EFFECTS: visual_effects_panel.visible,
		PANEL_PHYSICS: physics_performance_panel.visible,
		PANEL_AIM_LAUNCH: aim_launch_panel != null and aim_launch_panel.visible,
		PANEL_AIM_CONTACT: aim_contact_panel != null and aim_contact_panel.visible,
		PANEL_AIM_RESPONSE: aim_response_panel != null and aim_response_panel.visible,
		PANEL_AIM_TRACE: aim_trace_panel != null and aim_trace_panel.visible,
		PANEL_AIM_CANDIDATES: aim_candidates_panel != null and aim_candidates_panel.visible,
		PANEL_AIM_COLLISIONS: aim_collisions_panel != null and aim_collisions_panel.visible,
		PANEL_AIM_CONTACT_ORDER: aim_contact_order_panel != null and aim_contact_order_panel.visible,
		PANEL_AIM_SIMULATION: aim_simulation_panel != null and aim_simulation_panel.visible,
		PANEL_AIM_PROFILER: aim_profiler_panel != null and aim_profiler_panel.visible,
		PANEL_AIM_EVENT_CHAIN: aim_event_chain_panel != null and aim_event_chain_panel.visible,
		PANEL_SHOT_LEDGER: shot_ledger_panel != null and shot_ledger_panel.visible,
		PANEL_AIM_COMPARE_GROUP: _are_aim_compare_panels_visible(),
	}


func get_debug_session_snapshot() -> Dictionary:
	return {
		"modular_panel_states": get_modular_debug_panel_states(),
		"panel_positions": _get_debug_panel_positions(),
		"panel_sizes": _get_debug_panel_sizes(),
		"shot_path": shot_path_check_box.button_pressed,
		"physics_debug": physics_debug_check_box.button_pressed,
		"performance_overlay": performance_overlay_check_box.button_pressed,
		"anchor_visuals": anchor_visuals_check_box.button_pressed,
		"anchor_debug_visual": anchor_debug_visual_check_box.button_pressed,
		"anchor_single_latch": anchor_single_latch_check_box.button_pressed,
		"treasure_debug_visual": treasure_debug_visual_check_box.button_pressed,
		"powder_particles": powder_keg_particles_check_box.button_pressed,
		"powder_reduced_particles": powder_keg_reduced_particles_check_box.button_pressed,
		"powder_suppress_trails": powder_keg_suppress_trails_check_box.button_pressed,
		"debug_quick_menu": debug_menu_panel.visible,
		"wayfinder_current_button": wayfinder_current_test_button != null and wayfinder_current_test_button.visible,
		"broadside_button": broadside_attack_test_button != null and broadside_attack_test_button.visible,
		"reset_table_button": reset_table_button != null and reset_table_button.visible,
		"reset_last_shot_button": reset_last_shot_button != null and reset_last_shot_button.visible,
		"verbose_aim_candidates": verbose_aim_candidates,
	}


func apply_debug_session_snapshot(snapshot: Dictionary) -> void:
	var panel_states_value: Variant = snapshot.get("modular_panel_states", {})
	if panel_states_value is Dictionary:
		var panel_states: Dictionary = panel_states_value
		set_aim_compare_panels_visible(bool(panel_states.get(PANEL_AIM_COMPARE_GROUP, false)))
		for panel_id_value in panel_states.keys():
			var panel_id: String = str(panel_id_value)
			if panel_id == PANEL_AIM_COMPARE_GROUP:
				continue
			set_modular_debug_panel_visible(panel_id, bool(panel_states[panel_id_value]))
	_apply_debug_toggle(shot_path_check_box, bool(snapshot.get("shot_path", false)), _on_shot_path_debug_toggled)
	_apply_debug_toggle(physics_debug_check_box, bool(snapshot.get("physics_debug", false)), _on_physics_debug_toggled)
	_apply_debug_toggle(performance_overlay_check_box, bool(snapshot.get("performance_overlay", false)), _on_performance_overlay_toggled)
	_apply_debug_toggle(anchor_visuals_check_box, bool(snapshot.get("anchor_visuals", true)), _on_anchor_visuals_toggled)
	_apply_debug_toggle(anchor_debug_visual_check_box, bool(snapshot.get("anchor_debug_visual", false)), _on_anchor_debug_visual_toggled)
	_apply_debug_toggle(anchor_single_latch_check_box, bool(snapshot.get("anchor_single_latch", false)), _on_anchor_single_latch_toggled)
	_apply_debug_toggle(treasure_debug_visual_check_box, bool(snapshot.get("treasure_debug_visual", false)), _on_treasure_debug_visual_toggled)
	_apply_debug_toggle(powder_keg_particles_check_box, bool(snapshot.get("powder_particles", true)), _on_powder_keg_particles_toggled)
	_apply_debug_toggle(powder_keg_reduced_particles_check_box, bool(snapshot.get("powder_reduced_particles", false)), _on_powder_keg_reduced_particles_toggled)
	_apply_debug_toggle(powder_keg_suppress_trails_check_box, bool(snapshot.get("powder_suppress_trails", false)), _on_powder_keg_suppress_trails_toggled)
	debug_menu_panel.visible = bool(snapshot.get("debug_quick_menu", false))
	dev_option_state_changed.emit("overlay.quick_menu", debug_menu_panel.visible)
	set_wayfinder_current_test_button_visible(bool(snapshot.get("wayfinder_current_button", false)))
	set_broadside_attack_test_button_visible(bool(snapshot.get("broadside_button", false)))
	set_reset_table_button_visible(bool(snapshot.get("reset_table_button", false)))
	set_reset_last_shot_button_visible(bool(snapshot.get("reset_last_shot_button", false)))
	set_verbose_aim_candidates(bool(snapshot.get("verbose_aim_candidates", false)))
	_apply_debug_panel_positions(snapshot.get("panel_positions", {}))
	_apply_debug_panel_sizes(snapshot.get("panel_sizes", {}))


func _apply_debug_toggle(check_box: CheckBox, enabled: bool, callback: Callable) -> void:
	if check_box == null:
		return
	check_box.set_pressed_no_signal(enabled)
	callback.call(enabled)


func _get_debug_panel_positions() -> Dictionary:
	var positions: Dictionary = {}
	for panel_id in _get_positionable_panel_ids():
		var panel: Control = _get_modular_debug_panel(panel_id)
		if panel != null:
			positions[panel_id] = panel.position
	return positions


func _apply_debug_panel_positions(positions_value: Variant) -> void:
	if not positions_value is Dictionary:
		return
	var positions: Dictionary = positions_value
	for panel_id_value in positions.keys():
		var panel: Control = _get_modular_debug_panel(str(panel_id_value))
		var position_value: Variant = positions[panel_id_value]
		if panel != null and position_value is Vector2:
			panel.position = position_value


func _get_debug_panel_sizes() -> Dictionary:
	var sizes: Dictionary = {}
	for panel_id in _get_positionable_panel_ids():
		var panel: Control = _get_modular_debug_panel(panel_id)
		if panel != null:
			sizes[panel_id] = panel.size
	return sizes


func _apply_debug_panel_sizes(sizes_value: Variant) -> void:
	if not sizes_value is Dictionary:
		return
	var sizes: Dictionary = sizes_value
	for panel_id_value in sizes.keys():
		var panel: DebugPanel = _get_modular_debug_panel(str(panel_id_value)) as DebugPanel
		var size_value: Variant = sizes[panel_id_value]
		if panel != null and size_value is Vector2:
			panel.set_session_size(size_value)


func _get_positionable_panel_ids() -> Array[String]:
	return [
		PANEL_CORE_PERFORMANCE,
		PANEL_AIM_PREVIEW,
		PANEL_TREASURE,
		PANEL_EMBEZZLER,
		PANEL_ANCHOR,
		PANEL_BALL_DROPS_SCORE,
		PANEL_CANNON,
		PANEL_POWDER_KEG_WAYFINDER,
		PANEL_VISUAL_EFFECTS,
		PANEL_PHYSICS,
		PANEL_AIM_LAUNCH,
		PANEL_AIM_CONTACT,
		PANEL_AIM_RESPONSE,
		PANEL_AIM_TRACE,
		PANEL_AIM_CANDIDATES,
		PANEL_AIM_COLLISIONS,
		PANEL_AIM_CONTACT_ORDER,
		PANEL_AIM_SIMULATION,
		PANEL_AIM_PROFILER,
		PANEL_AIM_EVENT_CHAIN,
		PANEL_SHOT_LEDGER,
	]


func _set_all_modular_debug_panels_visible(visible_value: bool) -> void:
	core_performance_panel.visible = visible_value
	aim_preview_panel.visible = visible_value
	treasure_panel.visible = visible_value
	embezzler_panel.visible = visible_value
	anchor_panel.visible = visible_value
	ball_drops_score_panel.visible = visible_value
	cannon_panel.visible = visible_value
	powder_keg_wayfinder_panel.visible = visible_value
	visual_effects_panel.visible = visible_value
	physics_performance_panel.visible = visible_value
	_set_aim_compare_panels_visible(visible_value)
	if shot_ledger_panel != null:
		shot_ledger_panel.visible = visible_value


func _has_visible_modular_debug_panels() -> bool:
	return (
		core_performance_panel.visible
		or aim_preview_panel.visible
		or treasure_panel.visible
		or embezzler_panel.visible
		or anchor_panel.visible
		or ball_drops_score_panel.visible
		or cannon_panel.visible
		or powder_keg_wayfinder_panel.visible
		or visual_effects_panel.visible
		or physics_performance_panel.visible
		or _are_aim_compare_panels_visible()
		or (shot_ledger_panel != null and shot_ledger_panel.visible)
	)


func _get_visible_debug_panel_count() -> int:
	var count: int = _get_visible_modular_debug_panel_count()
	count += 1 if physics_debug_panel.visible else 0
	count += 1 if performance_overlay_panel.visible else 0
	count += 1 if debug_menu_panel.visible else 0
	return count


func _get_visible_modular_debug_panel_count() -> int:
	var count := 0
	count += 1 if core_performance_panel.visible else 0
	count += 1 if aim_preview_panel.visible else 0
	count += 1 if treasure_panel.visible else 0
	count += 1 if embezzler_panel.visible else 0
	count += 1 if anchor_panel.visible else 0
	count += 1 if ball_drops_score_panel.visible else 0
	count += 1 if cannon_panel.visible else 0
	count += 1 if powder_keg_wayfinder_panel.visible else 0
	count += 1 if visual_effects_panel.visible else 0
	count += 1 if physics_performance_panel.visible else 0
	count += 1 if aim_launch_panel != null and aim_launch_panel.visible else 0
	count += 1 if aim_contact_panel != null and aim_contact_panel.visible else 0
	count += 1 if aim_response_panel != null and aim_response_panel.visible else 0
	count += 1 if aim_trace_panel != null and aim_trace_panel.visible else 0
	count += 1 if aim_candidates_panel != null and aim_candidates_panel.visible else 0
	count += 1 if aim_collisions_panel != null and aim_collisions_panel.visible else 0
	count += 1 if aim_contact_order_panel != null and aim_contact_order_panel.visible else 0
	count += 1 if aim_simulation_panel != null and aim_simulation_panel.visible else 0
	count += 1 if aim_profiler_panel != null and aim_profiler_panel.visible else 0
	count += 1 if aim_event_chain_panel != null and aim_event_chain_panel.visible else 0
	count += 1 if shot_ledger_panel != null and shot_ledger_panel.visible else 0
	return count


func _get_visible_modular_performance_sections() -> Dictionary:
	var requested_sections: Dictionary = {}
	if core_performance_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_CORE_PERFORMANCE))
	if aim_preview_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_PREVIEW))
	if treasure_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_TREASURE))
	if embezzler_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_EMBEZZLER))
	if anchor_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_ANCHOR))
	if ball_drops_score_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_BALL_DROPS_SCORE))
	if cannon_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_CANNON))
	if powder_keg_wayfinder_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_POWDER_KEG_WAYFINDER))
	if visual_effects_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_VISUAL_EFFECTS))
	if physics_performance_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_PHYSICS))
	if aim_launch_panel != null and aim_launch_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_LAUNCH))
	if aim_contact_panel != null and aim_contact_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_CONTACT))
	if aim_response_panel != null and aim_response_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_RESPONSE))
	if aim_trace_panel != null and aim_trace_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_TRACE))
	if aim_candidates_panel != null and aim_candidates_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_CANDIDATES))
	if aim_collisions_panel != null and aim_collisions_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_COLLISIONS))
	if aim_contact_order_panel != null and aim_contact_order_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_CONTACT_ORDER))
	if aim_simulation_panel != null and aim_simulation_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_SIMULATION))
	if aim_profiler_panel != null and aim_profiler_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_PROFILER))
	if aim_event_chain_panel != null and aim_event_chain_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_EVENT_CHAIN))
	return requested_sections


func _get_modular_panel_performance_sections(panel_id: String) -> Dictionary:
	var requested_sections: Dictionary = {}
	match panel_id:
		PANEL_CORE_PERFORMANCE:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_CORE)
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_TIMING)
		PANEL_AIM_PREVIEW:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_AIM_PREVIEW)
		PANEL_AIM_LAUNCH:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_AIM_PREVIEW)
		PANEL_AIM_CONTACT:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_AIM_PREVIEW)
		PANEL_AIM_RESPONSE:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_AIM_PREVIEW)
		PANEL_AIM_TRACE, PANEL_AIM_CANDIDATES, PANEL_AIM_COLLISIONS, PANEL_AIM_CONTACT_ORDER, PANEL_AIM_SIMULATION, PANEL_AIM_PROFILER, PANEL_AIM_EVENT_CHAIN:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_AIM_PREVIEW)
		PANEL_TREASURE:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_TREASURE)
		PANEL_EMBEZZLER:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_EMBEZZLER)
		PANEL_ANCHOR:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_ANCHOR)
		PANEL_BALL_DROPS_SCORE:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_BALL_DROPS_SCORE)
		PANEL_CANNON:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_CANNON)
		PANEL_POWDER_KEG_WAYFINDER:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_POWDER_KEG_WAYFINDER)
		PANEL_VISUAL_EFFECTS:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_VISUAL_COST)
		PANEL_PHYSICS:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_PHYSICS)
	return requested_sections


func _request_performance_section(requested_sections: Dictionary, section_id: String) -> void:
	requested_sections[section_id] = true


func _refresh_visible_modular_debug_panels(snapshot: Dictionary) -> void:
	if core_performance_panel.visible:
		_refresh_modular_debug_panel(PANEL_CORE_PERFORMANCE, snapshot)
	if aim_preview_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_PREVIEW, snapshot)
	if treasure_panel.visible:
		_refresh_modular_debug_panel(PANEL_TREASURE, snapshot)
	if embezzler_panel.visible:
		_refresh_modular_debug_panel(PANEL_EMBEZZLER, snapshot)
	if anchor_panel.visible:
		_refresh_modular_debug_panel(PANEL_ANCHOR, snapshot)
	if ball_drops_score_panel.visible:
		_refresh_modular_debug_panel(PANEL_BALL_DROPS_SCORE, snapshot)
	if cannon_panel.visible:
		_refresh_modular_debug_panel(PANEL_CANNON, snapshot)
	if powder_keg_wayfinder_panel.visible:
		_refresh_modular_debug_panel(PANEL_POWDER_KEG_WAYFINDER, snapshot)
	if visual_effects_panel.visible:
		_refresh_modular_debug_panel(PANEL_VISUAL_EFFECTS, snapshot)
	if physics_performance_panel.visible:
		_refresh_modular_debug_panel(PANEL_PHYSICS, snapshot)
	if aim_launch_panel != null and aim_launch_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_LAUNCH, snapshot)
	if aim_contact_panel != null and aim_contact_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_CONTACT, snapshot)
	if aim_response_panel != null and aim_response_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_RESPONSE, snapshot)
	if aim_trace_panel != null and aim_trace_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_TRACE, snapshot)
	if aim_candidates_panel != null and aim_candidates_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_CANDIDATES, snapshot)
	if aim_collisions_panel != null and aim_collisions_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_COLLISIONS, snapshot)
	if aim_contact_order_panel != null and aim_contact_order_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_CONTACT_ORDER, snapshot)
	if aim_simulation_panel != null and aim_simulation_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_SIMULATION, snapshot)
	if aim_profiler_panel != null and aim_profiler_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_PROFILER, snapshot)
	if aim_event_chain_panel != null and aim_event_chain_panel.visible:
		_refresh_modular_debug_panel(PANEL_AIM_EVENT_CHAIN, snapshot)


func _refresh_modular_debug_panel(panel_id: String, snapshot: Dictionary) -> void:
	var panel: DebugPanel = _get_modular_debug_panel(panel_id) as DebugPanel
	var label: Label = _get_modular_debug_label(panel_id)
	if panel == null or label == null:
		return

	var panel_text := ""
	match panel_id:
		PANEL_CORE_PERFORMANCE:
			panel_text = _make_core_performance_panel_text(snapshot)
		PANEL_AIM_PREVIEW:
			panel_text = "\n".join(_make_aim_preview_performance_lines(snapshot))
		PANEL_TREASURE:
			panel_text = _make_titled_panel_text("TREASURE", _make_treasure_performance_lines(snapshot))
		PANEL_EMBEZZLER:
			panel_text = _make_titled_panel_text("EMBEZZLER", _make_embezzler_performance_lines(snapshot))
		PANEL_ANCHOR:
			panel_text = _make_titled_panel_text("ANCHOR", _make_anchor_performance_lines(snapshot))
		PANEL_BALL_DROPS_SCORE:
			panel_text = _make_ball_drops_score_panel_text(snapshot)
		PANEL_CANNON:
			panel_text = _make_titled_panel_text("CANNON", _make_cannon_performance_lines(snapshot))
		PANEL_POWDER_KEG_WAYFINDER:
			panel_text = _make_powder_keg_wayfinder_panel_text(snapshot)
		PANEL_VISUAL_EFFECTS:
			panel_text = "\n".join(_make_visual_cost_performance_lines(snapshot))
		PANEL_PHYSICS:
			panel_text = "\n".join(_make_physics_performance_lines(snapshot))
		PANEL_AIM_LAUNCH:
			panel_text = _make_titled_panel_text("AIM LAUNCH", _make_aim_launch_lines(snapshot))
		PANEL_AIM_CONTACT:
			panel_text = _make_titled_panel_text("AIM CONTACT", _make_aim_contact_lines(snapshot))
		PANEL_AIM_RESPONSE:
			panel_text = _make_titled_panel_text("AIM RESPONSE", _make_aim_response_lines(snapshot))
		PANEL_AIM_TRACE:
			panel_text = _make_titled_panel_text("AIM TRACE", _make_aim_trace_lines(snapshot))
		PANEL_AIM_CANDIDATES:
			panel_text = _make_titled_panel_text("AIM CANDIDATES", _make_aim_candidate_lines(snapshot))
		PANEL_AIM_COLLISIONS:
			panel_text = _make_titled_panel_text("AIM COLLISIONS", _make_aim_collision_lines(snapshot))
		PANEL_AIM_CONTACT_ORDER:
			panel_text = _make_titled_panel_text("AIM CONTACT ORDER", _make_aim_contact_order_lines(snapshot))
		PANEL_AIM_SIMULATION:
			panel_text = _make_titled_panel_text("AIM SIMULATION", _make_aim_simulation_lines(snapshot))
		PANEL_AIM_PROFILER:
			panel_text = _make_titled_panel_text("AIM PROFILER", _make_aim_profiler_lines(snapshot))
		PANEL_AIM_EVENT_CHAIN:
			panel_text = _make_titled_panel_text("AIM EVENT CHAIN", _make_aim_event_chain_lines(snapshot))
		PANEL_SHOT_LEDGER:
			panel_text = _make_shot_ledger_panel_text()
	panel.set_adaptive_text(label, panel_text)


func _get_modular_debug_panel(panel_id: String) -> Control:
	match panel_id:
		PANEL_CORE_PERFORMANCE:
			return core_performance_panel
		PANEL_AIM_PREVIEW:
			return aim_preview_panel
		PANEL_TREASURE:
			return treasure_panel
		PANEL_EMBEZZLER:
			return embezzler_panel
		PANEL_ANCHOR:
			return anchor_panel
		PANEL_BALL_DROPS_SCORE:
			return ball_drops_score_panel
		PANEL_CANNON:
			return cannon_panel
		PANEL_POWDER_KEG_WAYFINDER:
			return powder_keg_wayfinder_panel
		PANEL_VISUAL_EFFECTS:
			return visual_effects_panel
		PANEL_PHYSICS:
			return physics_performance_panel
		PANEL_AIM_LAUNCH:
			return aim_launch_panel
		PANEL_AIM_CONTACT:
			return aim_contact_panel
		PANEL_AIM_RESPONSE:
			return aim_response_panel
		PANEL_AIM_TRACE:
			return aim_trace_panel
		PANEL_AIM_CANDIDATES:
			return aim_candidates_panel
		PANEL_AIM_COLLISIONS:
			return aim_collisions_panel
		PANEL_AIM_CONTACT_ORDER:
			return aim_contact_order_panel
		PANEL_AIM_SIMULATION:
			return aim_simulation_panel
		PANEL_AIM_PROFILER:
			return aim_profiler_panel
		PANEL_AIM_EVENT_CHAIN:
			return aim_event_chain_panel
		PANEL_SHOT_LEDGER:
			return shot_ledger_panel
	return null


func _get_modular_debug_label(panel_id: String) -> Label:
	match panel_id:
		PANEL_CORE_PERFORMANCE:
			return core_performance_label
		PANEL_AIM_PREVIEW:
			return aim_preview_label
		PANEL_TREASURE:
			return treasure_label
		PANEL_EMBEZZLER:
			return embezzler_label
		PANEL_ANCHOR:
			return anchor_label
		PANEL_BALL_DROPS_SCORE:
			return ball_drops_score_label
		PANEL_CANNON:
			return cannon_label
		PANEL_POWDER_KEG_WAYFINDER:
			return powder_keg_wayfinder_label
		PANEL_VISUAL_EFFECTS:
			return visual_effects_label
		PANEL_PHYSICS:
			return physics_performance_label
		PANEL_AIM_LAUNCH:
			return aim_launch_label
		PANEL_AIM_CONTACT:
			return aim_contact_label
		PANEL_AIM_RESPONSE:
			return aim_response_label
		PANEL_AIM_TRACE:
			return aim_trace_label
		PANEL_AIM_CANDIDATES:
			return aim_candidates_label
		PANEL_AIM_COLLISIONS:
			return aim_collisions_label
		PANEL_AIM_CONTACT_ORDER:
			return aim_contact_order_label
		PANEL_AIM_SIMULATION:
			return aim_simulation_label
		PANEL_AIM_PROFILER:
			return aim_profiler_label
		PANEL_AIM_EVENT_CHAIN:
			return aim_event_chain_label
		PANEL_SHOT_LEDGER:
			return shot_ledger_label
	return null


func _copy_last_shot_ledger_summary() -> void:
	if table == null or table.shot_ledger_system == null:
		return
	var summary: String = table.shot_ledger_system.get_last_completed_summary()
	DisplayServer.clipboard_set(summary)
	print("Shot Ledger summary copied to clipboard.")


func _copy_last_shot_ledger_json() -> void:
	if table == null or table.shot_ledger_system == null:
		return
	var ledger_json: String = table.shot_ledger_system.get_last_completed_json()
	DisplayServer.clipboard_set(ledger_json)
	print("Shot Ledger JSON copied to clipboard.")


func _clear_shot_ledger_diagnostics() -> void:
	if table == null or table.shot_ledger_system == null:
		_report_debug_action_error("Shot Ledger diagnostics unavailable.")
		return
	table.shot_ledger_system.clear_diagnostic_counters()
	debug_notification_requested.emit("Shot Ledger diagnostic counters cleared.", "event")
	if shot_ledger_panel != null and shot_ledger_panel.visible:
		_refresh_modular_debug_panel(PANEL_SHOT_LEDGER, {})


func _copy_shot_ledger_lifecycle() -> void:
	if table == null or table.shot_ledger_system == null:
		_report_debug_action_error("Shot Ledger lifecycle diagnostics unavailable.")
		return
	DisplayServer.clipboard_set(table.shot_ledger_system.get_lifecycle_diagnostics_summary())
	debug_notification_requested.emit("Shot Ledger lifecycle diagnostics copied.", "event")


func _copy_all_shot_ledger_raw_events() -> void:
	if table == null or table.shot_ledger_system == null:
		_report_debug_action_error("Shot Ledger raw events unavailable.")
		return
	DisplayServer.clipboard_set(table.shot_ledger_system.get_last_raw_events_json())
	debug_notification_requested.emit("Last Shot raw events copied.", "event")


func _run_shot_ledger_self_test() -> void:
	if table == null:
		_report_debug_action_error("Shot Ledger Self-Test: table unavailable.")
		return
	if table.shot_ledger_system == null:
		_report_debug_action_error("Shot Ledger Self-Test: analyzer unavailable.")
		return
	var result: Dictionary = table.shot_ledger_system.run_self_tests()
	if result.is_empty():
		_report_debug_action_error("Shot Ledger Self-Test: empty test result.")
		return

	var summary: String = _make_shot_ledger_self_test_summary(result)
	print(summary)
	var failures: Array = _debug_array(result, "failures")
	if not failures.is_empty():
		print("Failures:")
		for failure_value in failures:
			print("- %s" % str(failure_value))
	debug_notification_requested.emit(summary, "event")

	if shot_ledger_panel == null:
		print("Shot Ledger Self-Test presentation warning: diagnostics panel unavailable.")
		return
	set_modular_debug_panel_visible(PANEL_SHOT_LEDGER, true)


func _make_shot_ledger_self_test_summary(result: Dictionary) -> String:
	var status: String = str(result.get("status", "ERROR"))
	var total_count: int = int(result.get("total_count", 0))
	var passed_count: int = int(result.get("passed_count", 0))
	var failed_count: int = int(result.get("failed_count", 0))
	if status == "ERROR":
		return "Shot Ledger Self-Test: ERROR - %s" % str(result.get("error_message", "unknown test runner error"))
	if failed_count > 0:
		return "Shot Ledger Self-Test: %d/%d passed, %d failed" % [passed_count, total_count, failed_count]
	return "Shot Ledger Self-Test: %d/%d passed" % [passed_count, total_count]


func _report_debug_action_error(message: String) -> void:
	push_error(message)
	print(message)
	debug_notification_requested.emit(message, "event")


func _make_shot_ledger_panel_text() -> String:
	if table == null or table.shot_ledger_system == null:
		return "SHOT LEDGER\nSystem unavailable."
	var snapshot: Dictionary = table.shot_ledger_system.get_debug_snapshot()
	var lines: PackedStringArray = PackedStringArray(["SHOT LEDGER"])
	var active: bool = bool(snapshot.get("active", false))
	lines.append("")
	lines.append("SHOT")
	if active:
		var active_shot: Dictionary = _debug_dictionary(snapshot, "active_shot")
		lines.append("Shot %d / Attempt %d  %s / %s  ACTIVE" % [
			int(active_shot.get("shot_id", -1)),
			int(active_shot.get("attempt_id", -1)),
			str(active_shot.get("source", "")),
			str(active_shot.get("mode_id", "")),
		])
		lines.append("%.3f sec  |  %d raw events" % [
			float(active_shot.get("duration_sec", 0.0)),
			int(active_shot.get("raw_event_count", 0)),
		])
	else:
		lines.append("No active authoritative shot.")
	_append_shot_ledger_lifecycle_lines(lines, snapshot)

	var ledger: Dictionary = _debug_dictionary(snapshot, "last_completed")
	if ledger.is_empty():
		lines.append("")
		lines.append("LAST COMPLETED")
		lines.append("No completed ledger yet.")
		_append_shot_ledger_self_test_lines(
			lines,
			_debug_dictionary(snapshot, "last_self_test_result"),
			int(snapshot.get("self_test_case_count", 0))
		)
		return "\n".join(lines)

	var derived: Dictionary = _debug_dictionary(ledger, "derived")
	var diagnostics: Dictionary = _debug_dictionary(ledger, "diagnostics")
	lines.append("")
	lines.append("LAST COMPLETED")
	lines.append("Shot %d / Attempt %d  %s / %s  %.3f sec" % [
		int(ledger.get("shot_id", -1)),
		int(ledger.get("attempt_id", -1)),
		str(ledger.get("source", "")),
		str(ledger.get("mode_id", "")),
		float(ledger.get("duration_sec", 0.0)),
	])
	lines.append("Raw events: %d  |  %d bytes  |  analysis %d usec" % [
		_debug_array(ledger, "raw_events").size(),
		int(diagnostics.get("completed_ledger_approximate_size_bytes", 0)),
		int(diagnostics.get("analysis_duration_usec", 0)),
	])

	lines.append("")
	lines.append("FIRST CONTACT")
	lines.append("Ball %d at event %d  |  cue rails first: %d" % [
		int(derived.get("first_object_contact_ball_id", -1)),
		int(derived.get("first_object_contact_event_index", -1)),
		int(derived.get("cue_rails_before_first_object_contact", 0)),
	])

	lines.append("")
	lines.append("CONTACTS")
	lines.append("Ball: %d  |  Rail: %d  |  Unique pairs: %d" % [
		int(derived.get("semantic_ball_contact_count", 0)),
		int(derived.get("semantic_rail_contact_count", 0)),
		_debug_array(derived, "unique_ball_contact_pairs").size(),
	])
	lines.append("Suppressed: separation %d / overlap %d / rail clamp %d" % [
		int(diagnostics.get("suppressed_separation_only_ball_contacts", 0)),
		int(diagnostics.get("suppressed_sustained_ball_overlaps", 0)),
		int(diagnostics.get("suppressed_rail_clamps_without_bounce", 0)),
	])

	lines.append("")
	lines.append("POCKETS")
	lines.append("Objects: %s  |  order: %s" % [
		str(derived.get("object_balls_pocketed", [])),
		str(derived.get("pocket_order", [])),
	])
	lines.append("Same-pocket max: %d  |  Scratch: %s" % [
		int(derived.get("largest_same_pocket_count", 0)),
		"yes" if bool(derived.get("scratch_occurred", false)) else "no",
	])

	lines.append("")
	lines.append("CAUSALITY")
	lines.append("Maximum depth: %d  |  Ambiguous balls: %s" % [
		int(derived.get("maximum_causal_depth", 0)),
		str(derived.get("ambiguous_causality_ball_ids", [])),
	])

	lines.append("")
	lines.append("POCKET FACTS")
	var pocket_facts: Array = _debug_array(derived, "pocket_facts")
	if pocket_facts.is_empty():
		lines.append("None")
	for fact_value in pocket_facts:
		if not fact_value is Dictionary:
			continue
		var fact: Dictionary = fact_value
		lines.append("#%d / ball %d: depth %d, rails %d, %s" % [
			int(fact.get("ball_number", -1)),
			int(fact.get("ball_id", -1)),
			int(fact.get("causal_depth", -1)),
			int(fact.get("bank_count", 0)),
			str(fact.get("bank_class", "none")),
		])
		lines.append("  parent %d | direct %s | combo %s | %.1f px" % [
			int(fact.get("causal_parent_ball_id", -1)),
			"yes" if bool(fact.get("is_direct_pot", false)) else "no",
			"yes" if bool(fact.get("is_combination_pot", false)) else "no",
			float(fact.get("travel_distance", 0.0)),
		])

	lines.append("")
	lines.append("TAGS")
	lines.append(_debug_shot_ledger_tag_list(_debug_array(derived, "tags")))
	lines.append(str(derived.get("tag_counts", {})))

	lines.append("")
	lines.append("END STATE")
	lines.append("Active: %d  |  Objects: %d" % [
		int(derived.get("balls_remaining_at_end", 0)),
		int(derived.get("active_object_balls_remaining", 0)),
	])
	lines.append("Cue travel: %.1f px  |  Object travel: %.1f px" % [
		float(derived.get("cue_ball_travel_distance", 0.0)),
		float(derived.get("total_object_ball_travel_distance", 0.0)),
	])

	lines.append("")
	lines.append("WARNINGS")
	lines.append("Invalid events/snapshots/travel: %d / %d / %d" % [
		int(diagnostics.get("invalid_events", 0)),
		int(diagnostics.get("invalid_ball_snapshots", 0)),
		int(diagnostics.get("invalid_travel_samples", 0)),
	])
	lines.append("Duplicate pockets: %d  |  Travel teleports: %d" % [
		int(diagnostics.get("suppressed_duplicate_pocket_attempts", 0)),
		int(diagnostics.get("suppressed_travel_teleports", 0)),
	])
	_append_shot_ledger_self_test_lines(
		lines,
		_debug_dictionary(snapshot, "last_self_test_result"),
		int(snapshot.get("self_test_case_count", 0))
	)
	return "\n".join(lines)


func _append_shot_ledger_lifecycle_lines(lines: PackedStringArray, snapshot: Dictionary) -> void:
	var active_shot: Dictionary = _debug_dictionary(snapshot, "active_shot")
	var identity: Dictionary = _debug_dictionary(snapshot, "ball_identity")
	lines.append("")
	lines.append("LIFECYCLE")
	lines.append("Active: %s | Shot: %d | Attempt: %d" % [
		"yes" if bool(snapshot.get("active", false)) else "no",
		int(active_shot.get("shot_id", -1)),
		int(active_shot.get("attempt_id", -1)),
	])
	lines.append("Completed: %d | Canceled: %d | Misuse: %d" % [
		int(snapshot.get("total_completed_shots", 0)),
		int(snapshot.get("total_canceled_shots", 0)),
		int(snapshot.get("lifecycle_misuse_count", 0)),
	])
	lines.append("Invalid: %d | Duplicate pockets: %d | Travel teleports: %d" % [
		int(snapshot.get("global_invalid_event_count", 0)),
		int(snapshot.get("global_duplicate_pocket_count", 0)),
		int(snapshot.get("global_travel_teleport_count", 0)),
	])
	lines.append("Ball IDs next/fallback/duplicate/restored: %d / %d / %d / %d" % [
		int(identity.get("next_run_ball_id", 1)),
		int(identity.get("missing_id_fallback_count", 0)),
		int(identity.get("duplicate_id_count", 0)),
		int(identity.get("restored_id_count", 0)),
	])
	var reasons: Dictionary = _debug_dictionary(snapshot, "lifecycle_misuse_by_reason")
	lines.append("Misuse reasons: %s" % (str(reasons) if not reasons.is_empty() else "none"))
	var last_misuse: Dictionary = _debug_dictionary(snapshot, "last_lifecycle_misuse")
	if not last_misuse.is_empty():
		lines.append("Last: %s @ %s usec (shot %d / attempt %d / mode %s / %s)" % [
			str(last_misuse.get("reason", "unknown")),
			str(last_misuse.get("engine_timestamp_usec", 0)),
			int(last_misuse.get("shot_id", -1)),
			int(last_misuse.get("attempt_id", -1)),
			str(last_misuse.get("mode_id", "unknown")),
			str(last_misuse.get("context_label", "")),
		])


func _append_shot_ledger_self_test_lines(
	lines: PackedStringArray,
	result: Dictionary,
	expected_test_count: int
) -> void:
	lines.append("")
	lines.append("SELF-TEST")
	if result.is_empty():
		lines.append("Last run: Not run")
		lines.append("Status: NOT RUN")
		lines.append("Total: %d  |  Passed: -  |  Failed: -" % expected_test_count)
		lines.append("Failures: none")
		return

	var total_count: int = int(result.get("total_count", 0))
	if total_count <= 0:
		total_count = int(result.get("expected_test_count", expected_test_count))
	var passed_count: int = int(result.get("passed_count", 0))
	var failed_count: int = int(result.get("failed_count", 0))
	lines.append("Last run: %s" % str(result.get("last_run_timestamp", "Unknown")))
	lines.append("Status: %s" % str(result.get("status", "ERROR")))
	lines.append("Total: %d  |  Passed: %d  |  Failed: %d" % [total_count, passed_count, failed_count])
	lines.append("Duration: %.3f ms" % (float(result.get("duration_usec", 0)) / 1000.0))
	var failures: Array = _debug_array(result, "failures")
	if failures.is_empty():
		lines.append("Failures: none")
		return
	lines.append("Failures:")
	for failure_value in failures:
		lines.append("- %s" % str(failure_value))


func _debug_shot_ledger_tag_list(tags: Array) -> String:
	if tags.is_empty():
		return "none"
	var values: PackedStringArray = PackedStringArray()
	for tag_value in tags:
		if tag_value is Dictionary:
			var tag: Dictionary = tag_value
			values.append("%s@%d" % [str(tag.get("tag_id", "")), int(tag.get("event_index", -1))])
	return ", ".join(values)


func _debug_dictionary(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value if value is Dictionary else {}


func _debug_array(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value if value is Array else []


func _toggle_debug_menu() -> void:
	debug_menu_panel.visible = not debug_menu_panel.visible
	dev_option_state_changed.emit("overlay.quick_menu", debug_menu_panel.visible)


func _toggle_performance_overlay() -> void:
	performance_overlay_check_box.button_pressed = not performance_overlay_check_box.button_pressed


func _ensure_on_table_debug_buttons() -> void:
	if wayfinder_current_test_button == null:
		wayfinder_current_test_button = _make_table_event_test_button(
			"Current",
			"Debug: trigger Wayfinder Current without spending Doubloons."
		)
	if broadside_attack_test_button == null:
		broadside_attack_test_button = _make_table_event_test_button(
			"Broadside",
			"Debug: trigger Broadside Attack without spending Doubloons."
		)
	if reset_table_button == null:
		reset_table_button = _make_table_event_test_button(
			"Reset Table",
			"Debug: restart the current mode while preserving the aim-testing workspace."
		)
		reset_table_button.z_index = 121
	if reset_last_shot_button == null:
		reset_last_shot_button = _make_table_event_test_button(
			"Reset Last Shot",
			"Reset unavailable: no committed shot yet."
		)
		reset_last_shot_button.z_index = 121
	_update_table_event_test_button_layout()


func _make_table_event_test_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = TABLE_EVENT_TEST_BUTTON_SIZE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.visible = false
	button.z_index = 36
	add_child(button)
	return button


func set_wayfinder_current_test_button_visible(enabled: bool) -> void:
	if wayfinder_current_test_button != null:
		wayfinder_current_test_button.visible = enabled
		_update_table_event_test_button_layout()


func set_broadside_attack_test_button_visible(enabled: bool) -> void:
	if broadside_attack_test_button != null:
		broadside_attack_test_button.visible = enabled
		_update_table_event_test_button_layout()


func set_reset_table_button_visible(enabled: bool) -> void:
	if reset_table_button != null:
		reset_table_button.visible = enabled
		_update_table_event_test_button_layout()


func set_reset_last_shot_button_visible(enabled: bool) -> void:
	if reset_last_shot_button != null:
		reset_last_shot_button.visible = enabled
		_update_table_event_test_button_layout()


func set_shot_rewind_state(snapshot: Dictionary) -> void:
	if reset_last_shot_button == null:
		return
	reset_last_shot_button.disabled = not bool(snapshot.get("can_rewind", false))
	var blocker: String = str(snapshot.get("blocker_reason", ""))
	reset_last_shot_button.tooltip_text = blocker if not blocker.is_empty() else "Restore the reusable pre-shot checkpoint."


func set_verbose_aim_candidates(enabled: bool) -> void:
	if verbose_aim_candidates == enabled:
		return
	verbose_aim_candidates = enabled
	if aim_candidates_panel != null and aim_candidates_panel.visible and table != null:
		var requested: Dictionary = _get_modular_panel_performance_sections(PANEL_AIM_CANDIDATES)
		_refresh_modular_debug_panel(PANEL_AIM_CANDIDATES, _get_performance_snapshot_with_debug_overlay_metrics(requested))


func _update_table_event_test_button_layout() -> void:
	var visible_buttons: Array[Button] = []
	if wayfinder_current_test_button != null and wayfinder_current_test_button.visible:
		visible_buttons.append(wayfinder_current_test_button)
	if broadside_attack_test_button != null and broadside_attack_test_button.visible:
		visible_buttons.append(broadside_attack_test_button)
	if reset_table_button != null and reset_table_button.visible:
		visible_buttons.append(reset_table_button)
	if reset_last_shot_button != null and reset_last_shot_button.visible:
		visible_buttons.append(reset_last_shot_button)

	for button_index in range(visible_buttons.size()):
		_position_table_event_test_button(visible_buttons[button_index], button_index)


func _position_table_event_test_button(button: Button, stack_index: int) -> void:
	var top_offset: float = TABLE_EVENT_TEST_BUTTON_TOP + float(stack_index) * (TABLE_EVENT_TEST_BUTTON_SIZE.y + TABLE_EVENT_TEST_BUTTON_GAP)
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -TABLE_EVENT_TEST_BUTTON_RIGHT_OFFSET
	button.offset_right = -TABLE_EVENT_TEST_BUTTON_RIGHT_OFFSET + TABLE_EVENT_TEST_BUTTON_SIZE.x
	button.offset_top = top_offset
	button.offset_bottom = top_offset + TABLE_EVENT_TEST_BUTTON_SIZE.y


func _on_shot_path_debug_toggled(enabled: bool) -> void:
	table.set_shot_path_debug_enabled(enabled)
	dev_option_state_changed.emit("overlay.shot_path", enabled)


func _on_physics_debug_toggled(enabled: bool) -> void:
	physics_debug_panel.visible = enabled
	if enabled:
		physics_debug_label.text = _make_physics_debug_text()
	dev_option_state_changed.emit("overlay.physics_debug", enabled)


func _on_performance_overlay_toggled(enabled: bool) -> void:
	performance_overlay_panel.visible = enabled
	if enabled:
		performance_overlay_label.text = _make_performance_debug_text()
	dev_option_state_changed.emit("overlay.performance", enabled)


func _on_anchor_visuals_toggled(enabled: bool) -> void:
	table.anchor_ball_system.set_anchor_visuals_enabled(enabled)
	dev_option_state_changed.emit("anchor.visuals", enabled)


func _on_anchor_debug_visual_toggled(enabled: bool) -> void:
	table.anchor_ball_system.set_debug_visual_enabled(enabled)
	dev_option_state_changed.emit("anchor.debug_visual", enabled)


func _on_anchor_single_latch_toggled(enabled: bool) -> void:
	table.anchor_ball_system.set_single_latch_per_target_enabled(enabled)
	dev_option_state_changed.emit("anchor.single_latch", enabled)


func _on_treasure_debug_visual_toggled(enabled: bool) -> void:
	table.treasure_ball_system.set_debug_visual_enabled(enabled)
	dev_option_state_changed.emit("treasure.debug_visual", enabled)


func _sync_powder_keg_debug_toggles() -> void:
	powder_keg_particles_check_box.set_pressed_no_signal(table.powder_keg_system.explosion_particles_enabled)
	powder_keg_reduced_particles_check_box.set_pressed_no_signal(table.powder_keg_system.reduced_particles_debug_enabled)
	powder_keg_suppress_trails_check_box.set_pressed_no_signal(table.powder_keg_system.suppress_trails_after_explosion)


func _on_powder_keg_particles_toggled(enabled: bool) -> void:
	table.powder_keg_system.explosion_particles_enabled = enabled
	dev_option_state_changed.emit("powder.particles", enabled)


func _on_powder_keg_reduced_particles_toggled(enabled: bool) -> void:
	table.powder_keg_system.reduced_particles_debug_enabled = enabled
	dev_option_state_changed.emit("powder.reduced_particles", enabled)


func _on_powder_keg_suppress_trails_toggled(enabled: bool) -> void:
	table.powder_keg_system.suppress_trails_after_explosion = enabled
	dev_option_state_changed.emit("powder.suppress_trails", enabled)


func _on_wayfinder_current_test_button_pressed() -> void:
	if table == null or table.table_event_system == null:
		return

	table.table_event_system.debug_trigger_wayfinder_current()


func _on_broadside_attack_test_button_pressed() -> void:
	if table == null or table.table_event_system == null:
		return

	table.table_event_system.debug_trigger_broadside_attack()


func _on_reset_table_button_pressed() -> void:
	reset_table_requested.emit()


func _on_reset_last_shot_button_pressed() -> void:
	reset_last_shot_requested.emit()


func _make_debug_hotkey_text() -> String:
	var hotkeys: Dictionary = table.get_debug_spawn_hotkey_data()
	return "%s: Spawn Wayfinder Ball\n%s: Spawn Powder Keg\n%s: Create Anchor Curse Seed\n%s: Spawn Cannon Ball\n%s: Spawn Treasure Ball\n%s: Spawn Embezzler Ball\n%s: Spawn Normal Ball\n%s: Performance Overlay" % [
		OS.get_keycode_string(int(hotkeys["wayfinder_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["powder_keg_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["anchor_ball_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["cannon_ball_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["treasure_ball_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["embezzler_ball_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["normal_spawn_key"])),
		OS.get_keycode_string(PERFORMANCE_OVERLAY_TOGGLE_KEY),
	]


func _make_physics_debug_text() -> String:
	var snapshot: Dictionary = table.get_physics_debug_snapshot()
	if not bool(snapshot["enabled"]):
		return "Physics debug disabled."

	var moving_balls: Array = snapshot["moving_balls"]
	var speed_threshold: float = float(snapshot["speed_threshold"])
	if moving_balls.is_empty():
		return "No balls above %.1f speed." % speed_threshold

	moving_balls.sort_custom(_sort_ball_debug_snapshots_by_speed)
	var lines: Array[String] = []
	var max_count: int = mini(int(snapshot["max_balls"]), moving_balls.size())
	for index in range(max_count):
		lines.append(_get_physics_debug_line(moving_balls[index]))

	return "\n".join(lines)


func _make_performance_debug_text() -> String:
	var snapshot: Dictionary = _get_performance_snapshot_with_debug_overlay_metrics()
	return _make_performance_debug_text_from_snapshot(snapshot)


func _get_performance_snapshot_with_debug_overlay_metrics(requested_sections: Dictionary = {}) -> Dictionary:
	var snapshot: Dictionary = table.get_performance_debug_snapshot(requested_sections)
	_add_debug_overlay_metrics(snapshot)
	return snapshot


func _add_debug_overlay_metrics(snapshot: Dictionary) -> void:
	var fps: int = Engine.get_frames_per_second()
	var estimated_frame_ms: float = 1000.0 / float(fps) if fps > 0 else 0.0
	var measured_physics_ms: float = float(snapshot.get("physics_process_ms", 0.0))
	snapshot["debug_overlay_refresh_ms"] = last_debug_overlay_refresh_ms
	snapshot["visible_debug_panel_count"] = _get_visible_debug_panel_count()
	snapshot["visible_modular_debug_panel_count"] = _get_visible_modular_debug_panel_count()
	snapshot["estimated_frame_ms"] = estimated_frame_ms
	snapshot["estimated_frame_physics_gap_ms"] = estimated_frame_ms - measured_physics_ms


func _make_performance_debug_text_from_snapshot(snapshot: Dictionary) -> String:
	var lines: Array = []
	lines.append_array(_make_performance_summary_lines(snapshot))
	lines.append("")
	lines.append_array(_make_ball_drop_performance_lines(snapshot))
	lines.append("")
	lines.append_array(_make_anomaly_performance_lines(snapshot))
	lines.append("")
	lines.append_array(_make_visual_cost_performance_lines(snapshot))
	lines.append("")
	lines.append_array(_make_aim_preview_performance_lines(snapshot))
	lines.append("")
	lines.append_array(_make_physics_performance_lines(snapshot))
	lines.append("")
	lines.append_array(_make_timing_performance_lines(snapshot))
	return "\n".join(lines)


func _make_core_performance_panel_text(snapshot: Dictionary) -> String:
	var lines: Array = ["CORE PERFORMANCE"]
	var summary_lines: Array = _make_performance_summary_lines(snapshot)
	if not summary_lines.is_empty():
		summary_lines.remove_at(0)
	lines.append_array(summary_lines)
	lines.append("")
	lines.append_array(_make_timing_performance_lines(snapshot))
	return "\n".join(lines)


func _make_ball_drops_score_panel_text(snapshot: Dictionary) -> String:
	var lines: Array = ["BALL DROPS / SCORE"]
	var ball_drop_lines: Array = _make_ball_drop_performance_lines(snapshot)
	if not ball_drop_lines.is_empty():
		ball_drop_lines.remove_at(0)
	lines.append_array(ball_drop_lines)
	lines.append("Score popups: %s labels / %s glows / %s tweens" % [
		snapshot["active_score_popup_labels"],
		snapshot["active_score_glow_labels"],
		snapshot["active_score_popup_tweens"],
	])
	lines.append("Score stacks: %s total / %s foundational / %s skilled / %s heroic / %s legendary" % [
		snapshot["active_score_stacks"],
		snapshot["active_foundational_score_stacks"],
		snapshot["active_skilled_score_stacks"],
		snapshot["active_heroic_score_stacks"],
		snapshot["active_legendary_score_stacks"],
	])
	lines.append("Foundational routes: %s stack / %s fallback / %s updates / %s avoided" % [
		snapshot["score_foundational_stack_routes"],
		snapshot["score_foundational_fallback_routes"],
		snapshot["score_stack_coalesces"],
		snapshot["score_stack_labels_avoided"],
	])
	lines.append("Skilled routes: %s stack / %s updates / %s popups avoided" % [
		snapshot["score_skilled_stack_routes"],
		snapshot["score_skilled_stack_coalesces"],
		snapshot["score_skilled_special_popups_avoided"],
	])
	lines.append("Heroic routes: %s stack / %s updates / %s popups avoided" % [
		snapshot["score_heroic_stack_routes"],
		snapshot["score_heroic_stack_coalesces"],
		snapshot["score_heroic_special_popups_avoided"],
	])
	lines.append("Legendary routes: %s stack / %s updates / %s popups avoided" % [
		snapshot["score_legendary_stack_routes"],
		snapshot["score_legendary_stack_coalesces"],
		snapshot["score_legendary_special_popups_avoided"],
	])
	lines.append("Stack lanes: %s conflicts / %s yields / %s early fades / %s replacements" % [
		snapshot["score_stack_lane_conflicts"],
		snapshot["score_stack_yields"],
		snapshot["score_stack_early_fades"],
		snapshot["score_stack_replacements"],
	])
	lines.append("Fallback popup routes: %s" % [
		snapshot["score_special_popup_routes"],
	])
	lines.append("Score route last: %s" % snapshot["score_last_popup_route"])
	return "\n".join(lines)


func _make_powder_keg_wayfinder_panel_text(snapshot: Dictionary) -> String:
	var lines: Array = ["POWDER KEG / WAYFINDER"]
	lines.append_array(_make_wayfinder_performance_lines(snapshot))
	lines.append("Powder Keg bursts: %s active bursts" % snapshot["active_powder_keg_particle_bursts"])
	return "\n".join(lines)


func _make_titled_panel_text(title: String, section_lines: Array) -> String:
	var lines: Array = [title]
	lines.append_array(section_lines)
	return "\n".join(lines)


func _make_performance_summary_lines(snapshot: Dictionary) -> Array:
	return [
		"PERFORMANCE",
		"FPS: %s" % Engine.get_frames_per_second(),
		"Debug UI: last %.2f ms / %s panels / %s modular" % [
			float(snapshot["debug_overlay_refresh_ms"]),
			snapshot["visible_debug_panel_count"],
			snapshot["visible_modular_debug_panel_count"],
		],
		"Balls: %s total / %s moving / %s stopped" % [
			snapshot["total_balls"],
			snapshot["moving_balls"],
			snapshot["stopped_balls"],
		],
		"Cue reclaim: eligible %s / granted %s / movers %s" % [
			_debug_bool_text(bool(snapshot["cue_reclaim_eligible"])),
			_debug_bool_text(bool(snapshot["cue_reclaim_granted"])),
			snapshot["cue_reclaim_moving_non_cue_balls"],
		],
		"Reclaim blocker: %s" % snapshot["cue_reclaim_blocker_reason"],
	]


func _make_ball_drop_performance_lines(snapshot: Dictionary) -> Array:
	var lines: Array = [
		"TABLE EVENTS / LEGACY BALL DROPS",
		"Table Event shot meter: %s/%s Doubloons (%s%%)" % [
			snapshot["table_event_shot_progress"],
			snapshot["table_event_threshold"],
			int(round(float(snapshot["table_event_progress_percent"]) * 100.0)),
		],
		"Table Event pending: %s / ready %s / menu %s" % [
			_debug_bool_text(bool(snapshot["table_event_pending"])),
			_debug_bool_text(bool(snapshot["table_event_ready"])),
			_debug_bool_text(bool(snapshot["table_event_menu_open"])),
		],
		"Table Event charges: %s pending / %s earned this shot / segment %s / shot %s Doubloons" % [
			snapshot["table_event_pending_charges"],
			snapshot["table_event_shot_charges_earned"],
			snapshot["table_event_segment_index"],
			snapshot["table_event_current_shot_doubloons"],
		],
		"Kraken Boons: %s / effects %s" % [
			snapshot["kraken_boon_active_summary"],
			str(snapshot["kraken_boon_active_effects"]),
		],
		"Kraken Boon counts: %s active / %s activated / %s refreshed / %s expired" % [
			snapshot["kraken_boon_active_count"],
			snapshot["kraken_boon_activations_total"],
			snapshot["kraken_boon_refreshes_total"],
			snapshot["kraken_boon_expirations_total"],
		],
		"Table Event offers: %s" % str(snapshot["table_event_active_offer_ids"]),
		"Table Event counts: %s earned / %s readied / %s bought / %s denied" % [
			snapshot["table_event_pending_earned"],
			snapshot["table_event_pending_readied"],
			snapshot["table_event_purchased"],
			snapshot["table_event_denied_purchases"],
		],
		"Table Event charge costs: Cheap %s balls/%s, Loose %s/%s, Wayfinder %s/%s, Current %s/%s, Powder %s/%s, Cannon %s/%s" % [
			snapshot["table_event_cheap_cargo_ball_count"],
			snapshot["table_event_cheap_cargo_cost"],
			snapshot["table_event_loose_cargo_ball_count"],
			snapshot["table_event_loose_cargo_cost"],
			snapshot["table_event_wayfinders_favor_ball_count"],
			snapshot["table_event_wayfinders_favor_cost"],
			snapshot["table_event_wayfinder_current_ball_count"],
			snapshot["table_event_wayfinder_current_cost"],
			snapshot["table_event_powder_cache_ball_count"],
			snapshot["table_event_powder_cache_cost"],
			snapshot["table_event_cannon_warning_ball_count"],
			snapshot["table_event_cannon_warning_cost"],
		],
		"Loose Cargo special odds: Contraband %.1f%% = base %.1f%% + cue %.1f%% / Treasure fallback %.1f%%" % [
			float(snapshot["table_event_loose_cargo_contraband_final_chance"]) * 100.0,
			float(snapshot["table_event_loose_cargo_contraband_base_chance"]) * 100.0,
			float(snapshot["table_event_loose_cargo_contraband_cue_bonus"]) * 100.0,
			float(snapshot["table_event_loose_cargo_treasure_chance"]) * 100.0,
		],
		"Last cargo special: %s / Treasure source %s roll %.3f index %s" % [
			snapshot["table_event_last_cargo_special_source"],
			snapshot["table_event_last_cargo_treasure_source"],
			float(snapshot["table_event_last_cargo_treasure_roll"]),
			snapshot["table_event_last_cargo_treasure_replacement_index"],
		],
		"Last Contraband: success %s / roll %.3f / weight %s / %s (%s) / fallback %s" % [
			_debug_bool_text(bool(snapshot["table_event_last_loose_cargo_contraband_succeeded"])),
			float(snapshot["table_event_last_loose_cargo_contraband_roll"]),
			snapshot["table_event_last_loose_cargo_contraband_weight_roll"],
			snapshot["table_event_last_loose_cargo_contraband_replacement_label"],
			snapshot["table_event_last_loose_cargo_contraband_replacement_kind"],
			_debug_bool_text(bool(snapshot["table_event_last_loose_cargo_treasure_fallback_succeeded"])),
		],
		"Cargo RNG: seed %s / state %s / fixed-debug %s / force %s %s" % [
			snapshot["table_event_cargo_rng_seed"],
			snapshot["table_event_cargo_rng_state"],
			_debug_bool_text(bool(snapshot["table_event_cargo_rng_debug_fixed"])),
			_debug_bool_text(bool(snapshot["table_event_debug_force_loose_cargo_contraband"])),
			snapshot["table_event_debug_loose_cargo_contraband_kind"],
		],
		"Table Event last blocker: %s" % snapshot["table_event_last_blocker_reason"],
		"Legacy BallDrop progress: %s/%s Doubloons" % [
			snapshot["ball_drop_progress"],
			snapshot["ball_drop_threshold"],
		],
		"Ball drops queued: %s earned / %s pending / %s from last score" % [
			snapshot["ball_drop_total_queued"],
			snapshot["ball_drop_pending_spawns"],
			snapshot["ball_drop_last_score_queued"],
		],
		"Auto BallDrop score rewards: %s / gated by Table Events: %s" % [
			_debug_bool_text(bool(snapshot["ball_drop_enabled"])),
			_debug_bool_text(bool(snapshot["table_event_auto_drops_gated"])),
		],
	]
	lines.append_array(_make_audio_debug_lines(snapshot))
	return lines


func _make_audio_debug_lines(snapshot: Dictionary) -> Array:
	var sampled_wav_silence: Dictionary = snapshot.get(
		"collision_audio_sampled_wav_leading_silence_msec",
		{}
	)
	var sampled_wav_onsets: Dictionary = snapshot.get(
		"collision_audio_sampled_wav_strong_transient_msec",
		{}
	)
	var sampled_wav_trimmed: Dictionary = snapshot.get(
		"collision_audio_sampled_wav_trimmed_msec",
		{}
	)
	return [
		"Collision audio mode: %s (default %s / effective %s) / bank %s / %s Hz / %sx%s = %s streams / %.2f ms" % [
			snapshot["collision_audio_mode"],
			snapshot["collision_audio_default_mode"],
			snapshot["collision_audio_effective_mode"],
			_debug_bool_text(bool(snapshot["collision_audio_generated_bank_ready"])),
			snapshot["collision_audio_sample_rate"],
			snapshot["collision_audio_strength_band_count"],
			snapshot["collision_audio_variants_per_band"],
			snapshot["collision_audio_generated_stream_count"],
			float(snapshot["collision_audio_bank_generation_ms"]),
		],
		"Sampled path: pool %s (%s/%s) / %s requests > %s plays / accepted-to-play request %sus" % [
			_debug_bool_text(bool(snapshot["collision_audio_sampled_pool_ready"])),
			snapshot["collision_audio_pool_size"],
			snapshot["collision_audio_sampled_pool_target_size"],
			snapshot["collision_audio_sampled_requests"],
			snapshot["collision_audio_sampled_playbacks"],
			snapshot["collision_audio_last_request_delay_usec"],
		],
		"Sampled guards: deferred %s / impact allocations %s / first-hit init %s" % [
			snapshot["collision_audio_deferred_sampled_plays"],
			snapshot["collision_audio_impact_time_allocations"],
			snapshot["collision_audio_first_hit_initializations"],
		],
		"Sampled WAV: silence %.2f/%.2fms / strong onset %.2f/%.2fms / trimmed %.2f/%.2fms" % [
			float(sampled_wav_silence.get("ball_hit_01", 0.0)),
			float(sampled_wav_silence.get("ball_hit_02", 0.0)),
			float(sampled_wav_onsets.get("ball_hit_01", 0.0)),
			float(sampled_wav_onsets.get("ball_hit_02", 0.0)),
			float(sampled_wav_trimmed.get("ball_hit_01", 0.0)),
			float(sampled_wav_trimmed.get("ball_hit_02", 0.0)),
		],
		"Collision material: %s / main %.0f-%.0f Hz / secondary %.0f-%.0f Hz / body %.0f-%.0f Hz" % [
			str(snapshot["collision_audio_material_profile"]).replace("_", " ").capitalize(),
			float(snapshot["collision_audio_primary_frequency_min_hz"]),
			float(snapshot["collision_audio_primary_frequency_max_hz"]),
			float(snapshot["collision_audio_secondary_frequency_min_hz"]),
			float(snapshot["collision_audio_secondary_frequency_max_hz"]),
			float(snapshot["collision_audio_body_frequency_min_hz"]),
			float(snapshot["collision_audio_body_frequency_max_hz"]),
		],
		"Collision cluster: %s modes / %.0f-%.0f Hz / modal decay %.2f-%.2f ms" % [
			snapshot["collision_audio_modal_count"],
			float(snapshot["collision_audio_modal_frequency_min_hz"]),
			float(snapshot["collision_audio_modal_frequency_max_hz"]),
			float(snapshot["collision_audio_modal_decay_min_ms"]),
			float(snapshot["collision_audio_modal_decay_max_ms"]),
		],
		"Collision contact: body %.0f-%.0f Hz @ %.2f-%.2f / micro spacing %.2f-%.2f ms" % [
			float(snapshot["collision_audio_low_body_frequency_min_hz"]),
			float(snapshot["collision_audio_low_body_frequency_max_hz"]),
			float(snapshot["collision_audio_low_body_amplitude_min"]),
			float(snapshot["collision_audio_low_body_amplitude_max"]),
			float(snapshot["collision_audio_micro_impulse_separation_min_ms"]),
			float(snapshot["collision_audio_micro_impulse_separation_max_ms"]),
		],
		"Collision candidate: %s / centers %s / secondary pulse %s" % [
			str(snapshot["collision_audio_candidate_name"]),
			str(snapshot["collision_audio_modal_centers_hz"]),
			_debug_bool_text(bool(snapshot["collision_audio_secondary_pulse_enabled"])),
		],
		"Collision shaping: compression %.3f / table coupling %.3f / high-pass %.0f Hz / saturation %.2f" % [
			float(snapshot["collision_audio_compression_impulse_level"]),
			float(snapshot["collision_audio_table_coupling_level"]),
			float(snapshot["collision_audio_highpass_cutoff_hz"]),
			float(snapshot["collision_audio_saturation_amount"]),
		],
		"Collision envelope: generated %.1f-%.1f ms (authored %.1f-%.1f) / transient %.1f-%.1f ms (authored %.1f-%.1f) / body:main %.2f / tail %s" % [
			float(snapshot["collision_audio_generated_duration_min_ms"]),
			float(snapshot["collision_audio_generated_duration_max_ms"]),
			float(snapshot["collision_audio_authored_duration_min_ms"]),
			float(snapshot["collision_audio_authored_duration_max_ms"]),
			float(snapshot["collision_audio_generated_transient_min_ms"]),
			float(snapshot["collision_audio_generated_transient_max_ms"]),
			float(snapshot["collision_audio_authored_transient_min_ms"]),
			float(snapshot["collision_audio_authored_transient_max_ms"]),
			float(snapshot["collision_audio_body_primary_ratio"]),
			_debug_bool_text(bool(snapshot["collision_audio_material_tail_retained"])),
		],
		"Collision audio voices: proc %s/%s (max %s) / sampled %s / layer plays %s proc + %s sampled" % [
			snapshot["collision_audio_active_procedural_voices"],
			snapshot["collision_audio_procedural_voice_limit"],
			snapshot["collision_audio_max_procedural_voices"],
			snapshot["collision_audio_active_sampled_voices"],
			snapshot["collision_audio_procedural_layer_plays"],
			snapshot["collision_audio_sampled_layer_plays"],
		],
		"Collision audio proc guards: weak %s / repeat pair %s / voice reject %s / proc steals %s / layered skips %s / fallback %s" % [
			snapshot["collision_audio_suppressed_weak"],
			snapshot["collision_audio_suppressed_repeated_pair"],
			snapshot["collision_audio_voice_budget_rejections"],
			snapshot["collision_audio_procedural_pool_steals"],
			snapshot["collision_audio_layered_sample_budget_skips"],
			snapshot["collision_audio_fallback_count"],
		],
		"Collision audio last: strength %.3f / band %s / variant %s / %.1f dB / bank builds %s" % [
			float(snapshot["collision_audio_last_strength"]),
			snapshot["collision_audio_last_band"],
			snapshot["collision_audio_last_variant"],
			float(snapshot["collision_audio_last_volume_db"]),
			snapshot["collision_audio_bank_generation_count"],
		],
		"Collision audio: %s/%s playing / max %s / frame %s req>%s plays / total %s>%s" % [
			snapshot["collision_audio_playing_players"],
			snapshot["collision_audio_pool_size"],
			snapshot["collision_audio_max_playing_players"],
			snapshot["collision_audio_requests_this_frame"],
			snapshot["collision_audio_played_this_frame"],
			snapshot["collision_audio_total_requests"],
			snapshot["collision_audio_total_plays"],
		],
		"Collision audio skips: tiny %s / frame %s / global %s / pair %s / steals %s" % [
			snapshot["collision_audio_skipped_tiny"],
			snapshot["collision_audio_skipped_frame_limit"],
			snapshot["collision_audio_skipped_global_cooldown"],
			snapshot["collision_audio_skipped_pair_cooldown"],
			snapshot["collision_audio_pool_steals"],
		],
		"Pocket streak queue: last X%s / %s pending / %.2fs gate / %.2fs tune / %s queued / %s shown" % [
			snapshot["pocket_streak_last_multiplier"],
			snapshot["pocket_streak_presentation_queue_size"],
			float(snapshot["pocket_streak_presentation_delay_remaining"]),
			float(snapshot["pocket_streak_queue_gate_duration"]),
			snapshot["pocket_streak_presentations_queued"],
			snapshot["pocket_streak_presentations_started"],
		],
		"Pocket streak audio: %s/%s playing / max %s / triggers %s / req %s / plays %s" % [
			snapshot["pocket_streak_audio_playing_players"],
			snapshot["pocket_streak_audio_pool_size"],
			snapshot["pocket_streak_audio_max_playing_players"],
			snapshot["pocket_streak_triggers"],
			snapshot["pocket_streak_audio_requests"],
			snapshot["pocket_streak_audio_plays"],
		],
		"Pocket streak audio guard: cooldown %s / steals %s / last X%s" % [
			snapshot["pocket_streak_audio_cooldown_skips"],
			snapshot["pocket_streak_audio_pool_steals"],
			snapshot["pocket_streak_audio_last_multiplier"],
		],
		"Pocket streak whirlpool: %s active / %s recent / last X%s / cap X%s" % [
			snapshot["pocket_streak_active_whirlpools"],
			snapshot["pocket_streak_recent_whirlpools"],
			snapshot["pocket_streak_last_whirlpool_multiplier"],
			snapshot["pocket_streak_whirlpool_intensity_cap_multiplier"],
		],
		"Pocket streak reverb: %s bus #%s / effect %s / wet %.2f/%.2f / updates %s" % [
			snapshot["pocket_streak_audio_bus"],
			snapshot["pocket_streak_audio_bus_index"],
			snapshot["pocket_streak_reverb_effect_index"],
			float(snapshot["pocket_streak_reverb_wet_level"]),
			float(snapshot["pocket_streak_reverb_wet_cap"]),
			snapshot["pocket_streak_reverb_updates"],
		],
		"Pocket streak tuning: whirl +%.2fs / pitch cap %.2f / vol cap %.1fdB" % [
			float(snapshot["pocket_streak_whirlpool_extra_duration_cap"]),
			float(snapshot["pocket_streak_audio_max_pitch_scale"]),
			float(snapshot["pocket_streak_audio_max_volume_db"]),
		],
	]


func _make_anomaly_performance_lines(snapshot: Dictionary) -> Array:
	var lines: Array = [
		"ANOMALIES",
	]
	lines.append_array(_make_wayfinder_performance_lines(snapshot))
	lines.append_array(_make_anchor_performance_lines(snapshot))
	lines.append_array(_make_cannon_performance_lines(snapshot))
	lines.append_array(_make_treasure_performance_lines(snapshot))
	lines.append_array(_make_embezzler_performance_lines(snapshot))
	return lines


func _make_wayfinder_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"Wayfinder: %s active / %s guided" % [
			snapshot["active_wayfinders"],
			snapshot["guided_wayfinder_targets"],
		],
		"Wayfinder Current: %s carriers / %s events / %s total hit / %s last hit / %s transfers / %s this event / %s scored / %s expired" % [
			snapshot["wayfinder_current_carriers"],
			snapshot["wayfinder_current_events_started"],
			snapshot["wayfinder_current_initial_affected"],
			snapshot["wayfinder_current_last_affected"],
			snapshot["wayfinder_current_transfers"],
			snapshot["wayfinder_current_last_event_transfers"],
			snapshot["wayfinder_current_scored_sinks"],
			snapshot["wayfinder_current_expired"],
		],
		"Wayfinder Current FX: %s transfer flashes" % [
			snapshot["wayfinder_current_transfer_flashes"],
		],
		"Wayfinder Current tuning: r %.0f / impulse %.0f / uncapped / %.1fs / depth %s" % [
			float(snapshot["wayfinder_current_radius"]),
			float(snapshot["wayfinder_current_impulse_strength"]),
			float(snapshot["wayfinder_current_lifetime_seconds"]),
			snapshot["wayfinder_current_transfer_limit"],
		],
	]


func _make_anchor_performance_lines(snapshot: Dictionary) -> Array:
	var lines: Array = []
	lines.append_array(_make_anchor_seed_state_lines(snapshot))
	lines.append_array(_make_anchor_chain_state_lines(snapshot))
	lines.append_array(_make_anchor_tighten_state_lines(snapshot))
	lines.append_array(_make_anchor_warning_state_lines(snapshot))
	lines.append_array(_make_anchor_collapse_state_lines(snapshot))
	lines.append_array(_make_anchor_spread_state_lines(snapshot))
	return lines


func _make_anchor_seed_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Anchor curse seeds: %s active / %s created / %s candidates" % [
			snapshot["anchor_curse_seeds_active"],
			snapshot["anchor_curse_seeds_created"],
			snapshot["anchor_curse_seed_eligible_candidates"],
		],
		"Anchor curse pick: #%s / %.1f / %s / replacements %s/%s" % [
			snapshot["anchor_curse_seed_selected_ball_number"],
			float(snapshot["anchor_curse_seed_selected_score"]),
			snapshot["anchor_curse_seed_selected_reason"],
			snapshot["anchor_curse_seed_penalty_replacements"],
			snapshot["anchor_curse_seed_penalty_attempts"],
		],
	]


func _make_anchor_chain_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Anchor chains: %s links / per seed %s / last %s" % [
			snapshot["anchor_curse_chain_links"],
			snapshot["anchor_curse_chain_links_per_seed"],
			snapshot["anchor_curse_chain_last_created"],
		],
		"Anchor chain max: %s" % snapshot["anchor_curse_chain_max_lengths"],
		"Anchor chain health: failed %s / invalidated %s" % [
			snapshot["anchor_curse_chain_failed_acquisitions"],
			snapshot["anchor_curse_chain_invalidated_links"],
		],
	]


func _make_anchor_tighten_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Anchor tighten: %s applied / %s skipped / touching %s" % [
			snapshot["anchor_curse_chain_tighten_steps_applied"],
			snapshot["anchor_curse_chain_tighten_steps_skipped"],
			snapshot["anchor_curse_chain_touching_seed_links"],
		],
		"Anchor tighten distance: avg %.1f / last %.1f" % [
			float(snapshot["anchor_curse_chain_tighten_avg_distance"]),
			float(snapshot["anchor_curse_chain_tighten_last_distance"]),
		],
		"Anchor leash: %s clamps / slides %s>%s / blocked %s" % [
			snapshot["anchor_curse_chain_constraint_clamps"],
			snapshot["anchor_curse_chain_tighten_slides_started"],
			snapshot["anchor_curse_chain_tighten_slides_completed"],
			snapshot["anchor_curse_chain_tighten_slides_blocked"],
		],
		"Anchor lanes: %s attempts / %s success / %s blocked / %s skipped" % [
			snapshot["anchor_curse_chain_deconfliction_attempts"],
			snapshot["anchor_curse_chain_deconfliction_successes"],
			snapshot["anchor_curse_chain_deconfliction_blocked"],
			snapshot["anchor_curse_chain_deconfliction_skipped"],
		],
		"Anchor lane last: %s" % snapshot["anchor_curse_chain_deconfliction_last_reason"],
		"Anchor tighten skips: %s / %s" % [
			snapshot["anchor_curse_chain_tighten_last_skip_reason"],
			snapshot["anchor_curse_chain_tighten_skip_reasons"],
		],
	]


func _make_anchor_warning_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Anchor warning: %s warning / %s ready / %.1fs / %s" % [
			snapshot["anchor_curse_warning_seeds"],
			snapshot["anchor_curse_spread_ready"],
			float(snapshot["anchor_curse_warning_timer_remaining"]),
			snapshot["anchor_curse_warning_timer_state"],
		],
		"Anchor warning counts: %s started / %s reset" % [
			snapshot["anchor_curse_warning_started"],
			snapshot["anchor_curse_warning_resets"],
		],
	]


func _make_anchor_collapse_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Anchor collapses: %s total / cue %s / powder %s / cannon %s" % [
			snapshot["anchor_curse_collapsed_total"],
			snapshot["anchor_curse_collapsed_by_cue"],
			snapshot["anchor_curse_collapsed_by_powder"],
			snapshot["anchor_curse_collapsed_by_cannon"],
		],
		"Anchor collapse pocket: %s / last chained %s" % [
			snapshot["anchor_curse_collapsed_by_chained_ball_pocket"],
			_debug_id_text(int(snapshot["anchor_curse_last_collapsed_chained_ball"])),
		],
		"Anchor collapse chains released: %s" % snapshot["anchor_curse_chains_released_by_collapse"],
	]


func _make_anchor_spread_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Anchor spread: %s events / %s seeds / %s skipped" % [
			snapshot["anchor_curse_spread_events_total"],
			snapshot["anchor_curse_seeds_created_by_spread"],
			snapshot["anchor_curse_spread_blocked_skipped"],
		],
		"Anchor spread state: %s grace / max active %s" % [
			snapshot["anchor_curse_new_seed_grace_count"],
			snapshot["anchor_curse_max_active_seeds"],
		],
		"Anchor visuals: %s" % [
			_debug_bool_text(bool(snapshot["anchor_visuals_enabled"])),
		],
	]


func _make_cannon_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"Cannon: %s active / %s collisions / %s heavy impacts" % [
			snapshot["cannon_balls"],
			snapshot["cannon_collisions"],
			snapshot["cannon_heavy_impacts"],
		],
	]


func _make_treasure_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"Treasure: %s active / %s seen / steering %s / %s" % [
			snapshot["treasure_balls"],
			snapshot["treasure_balls_seen"],
			_debug_true_false_text(bool(snapshot["treasure_steering_active"])),
			snapshot["treasure_steering_mode"],
		],
		"Treasure threat: %.2f / panic %s / %s steer apps" % [
			float(snapshot["treasure_threat_strength"]),
			_debug_true_false_text(bool(snapshot["treasure_panic_active"])),
			snapshot["treasure_steering_applications"],
		],
		"Treasure hide target: found %s / cover target %s" % [
			_debug_true_false_text(bool(snapshot["treasure_hide_target_found"])),
			_debug_true_false_text(int(snapshot["treasure_hide_cover_found"]) > 0),
		],
		"Treasure target: cover %s / dist %s / commit %s" % [
			_debug_id_text(int(snapshot["treasure_target_cover_ball_id"])),
			_debug_distance_text(float(snapshot["treasure_target_distance"])),
			_debug_distance_text(float(snapshot["treasure_target_commit_remaining"])),
		],
		"Treasure target reason: %s" % [
			snapshot["treasure_target_switch_reason"],
		],
		"Treasure visibility: %s / lat %s / path %s" % [
			snapshot["treasure_visibility_reason"],
			_debug_distance_text(float(snapshot["treasure_visibility_lateral_distance"])),
			_debug_distance_text(float(snapshot["treasure_visibility_distance_along_path"])),
		],
		"Treasure blocker: %s / lat %s / path %s" % [
			_debug_id_text(int(snapshot["treasure_visibility_blocker_ball_id"])),
			_debug_distance_text(float(snapshot["treasure_visibility_blocker_lateral_distance"])),
			_debug_distance_text(float(snapshot["treasure_visibility_blocker_distance_along_path"])),
		],
		"Treasure perception: %s checks / epoch %s / %s rebuilds" % [
			snapshot["treasure_perception_checks"],
			snapshot["treasure_perception_epoch"],
			snapshot["treasure_perception_rebuilds"],
		],
		"Treasure stability: lost %s / reacq %s / linger %s" % [
			snapshot["treasure_perception_lost_events"],
			snapshot["treasure_perception_reacquired_events"],
			snapshot["treasure_perception_linger_activations"],
		],
		"Treasure grace: direct %s / active %s / max %.2fs / frame %s" % [
			snapshot["treasure_perception_direct_seen"],
			snapshot["treasure_perception_grace_active"],
			float(snapshot["treasure_perception_grace_max_remaining"]),
			snapshot["treasure_perception_lingered"],
		],
	]


func _make_embezzler_performance_lines(snapshot: Dictionary) -> Array:
	var lines: Array = []
	lines.append_array(_make_embezzler_value_state_lines(snapshot))
	lines.append_array(_make_embezzler_movement_state_lines(snapshot))
	lines.append_array(_make_embezzler_escape_state_lines(snapshot))
	lines.append_array(_make_embezzler_capture_state_lines(snapshot))
	return lines


func _make_embezzler_value_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Embezzler: %s active / %s state" % [
			snapshot["embezzler_balls"],
			snapshot["embezzler_state"],
		],
		"Embezzler value: %s stored / %s skimmed total" % [
			snapshot["embezzler_stored_value"],
			snapshot["embezzler_skimmed_total"],
		],
		"Embezzler will: %.1f%% total / %.1f base / %.1f aim" % [
			float(snapshot["embezzler_willingness"]),
			float(snapshot["embezzler_baseline_willingness"]),
			float(snapshot["embezzler_aim_pressure_willingness"]),
		],
		"Embezzler pressure: %s / %s events / %.1f calm/s" % [
			snapshot["embezzler_last_pressure_reason"],
			snapshot["embezzler_pressure_events"],
			float(snapshot["embezzler_calm_decay_rate"]),
		],
	]


func _make_embezzler_movement_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Embezzler target: %s @ %s / bias %.2f" % [
			snapshot["embezzler_move_target_mode"],
			_debug_vector_text(snapshot["embezzler_move_target"]),
			float(snapshot["embezzler_target_pocket_bias_amount"]),
		],
		"Embezzler movement: %s scuttles / %s switches / %s blocked" % [
			snapshot["embezzler_scuttle_applications"],
			snapshot["embezzler_target_switches"],
			snapshot["embezzler_blocked_target_attempts"],
		],
		"Embezzler routing: %s / block %s" % [
			snapshot["embezzler_target_switch_reason"],
			snapshot["embezzler_last_blocked_target_reason"],
		],
	]


func _make_embezzler_escape_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Embezzler escape: %s committed / %s pending / %s pending count / %s total" % [
			snapshot["embezzler_escape_committed_active"],
			snapshot["embezzler_pocket_test_pending_active"],
			snapshot["embezzler_pocket_test_pending_count"],
			snapshot["embezzler_pocket_test_pending_total"],
		],
		"Embezzler rolls: %s attempts / %s success / %s fail" % [
			snapshot["embezzler_escape_roll_attempts"],
			snapshot["embezzler_escape_roll_successes"],
			snapshot["embezzler_escape_roll_failures"],
		],
		"Embezzler last roll: %.1f%% / %s" % [
			float(snapshot["embezzler_last_escape_roll_chance"]) * 100.0,
			snapshot["embezzler_last_escape_roll_reason"],
		],
		"Embezzler pocket rolls: %s attempts / %s escaped / %s retreat" % [
			snapshot["embezzler_pocket_roll_attempts"],
			snapshot["embezzler_pocket_roll_successes"],
			snapshot["embezzler_pocket_roll_failures"],
		],
		"Embezzler pocket result: %.1f%% / %s / %s escapes / %s panics" % [
			float(snapshot["embezzler_last_pocket_roll_chance"]) * 100.0,
			snapshot["embezzler_last_pocket_roll_result"],
			snapshot["embezzler_escaped_count"],
			snapshot["embezzler_panic_retreats"],
		],
		"Embezzler escaped value: %s last / %s total" % [
			snapshot["embezzler_last_escaped_stored_value"],
			snapshot["embezzler_escaped_stored_value_total"],
		],
	]


func _make_embezzler_capture_state_lines(snapshot: Dictionary) -> Array:
	return [
		"Embezzler captures: %s caught / %s recovered / %s last" % [
			snapshot["embezzler_captures_total"],
			snapshot["embezzler_recovered_value_total"],
			snapshot["embezzler_last_recovered_value"],
		],
		"Embezzler capture pocket: %s (%s) / %s double blocks" % [
			snapshot["embezzler_last_capture_pocket_name"],
			_debug_id_text(int(snapshot["embezzler_last_capture_pocket_index"])),
			snapshot["embezzler_double_award_preventions"],
		],
		"Embezzler pocket: %s (%s)" % [
			snapshot["embezzler_target_pocket_name"],
			_debug_id_text(int(snapshot["embezzler_target_pocket_index"])),
		],
	]


func _make_visual_cost_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"VISUAL COST",
		"Trails: %s points / %s balls / %s redraws" % [
			snapshot["trail_points"],
			snapshot["balls_with_trails"],
			snapshot["trail_redraws"],
		],
		"Score UI: %s labels / %s glow clones / %s tweens" % [
			snapshot["active_score_popup_labels"],
			snapshot["active_score_glow_labels"],
			snapshot["active_score_popup_tweens"],
		],
		"Score stacks: %s total / %s foundational / %s skilled / %s heroic / %s legendary" % [
			snapshot["active_score_stacks"],
			snapshot["active_foundational_score_stacks"],
			snapshot["active_skilled_score_stacks"],
			snapshot["active_heroic_score_stacks"],
			snapshot["active_legendary_score_stacks"],
		],
		"Foundational routes: %s stack / %s fallback / %s updates / %s avoided" % [
			snapshot["score_foundational_stack_routes"],
			snapshot["score_foundational_fallback_routes"],
			snapshot["score_stack_coalesces"],
			snapshot["score_stack_labels_avoided"],
		],
		"Skilled routes: %s stack / %s updates / %s popups avoided" % [
			snapshot["score_skilled_stack_routes"],
			snapshot["score_skilled_stack_coalesces"],
			snapshot["score_skilled_special_popups_avoided"],
		],
		"Heroic routes: %s stack / %s updates / %s popups avoided" % [
			snapshot["score_heroic_stack_routes"],
			snapshot["score_heroic_stack_coalesces"],
			snapshot["score_heroic_special_popups_avoided"],
		],
		"Legendary routes: %s stack / %s updates / %s popups avoided" % [
			snapshot["score_legendary_stack_routes"],
			snapshot["score_legendary_stack_coalesces"],
			snapshot["score_legendary_special_popups_avoided"],
		],
		"Stack lanes: %s conflicts / %s yields / %s early fades / %s replacements" % [
			snapshot["score_stack_lane_conflicts"],
			snapshot["score_stack_yields"],
			snapshot["score_stack_early_fades"],
			snapshot["score_stack_replacements"],
		],
		"Fallback popup routes: %s" % [
			snapshot["score_special_popup_routes"],
		],
		"Debug UI: last %.2f ms / %s panels visible" % [
			float(snapshot["debug_overlay_refresh_ms"]),
			snapshot["visible_debug_panel_count"],
		],
		"Particles: %s Powder Keg bursts" % [
			snapshot["active_powder_keg_particle_bursts"],
		],
		"Pocket captures: %s / %s visible / %s animating / %s nodes / %s total" % [
			_debug_bool_text(bool(snapshot["pocket_capture_enabled"])),
			snapshot["pocket_capture_visible_proxies"],
			snapshot["pocket_capture_active_animations"],
			snapshot["pocket_capture_total_visual_nodes"],
			snapshot["pocket_capture_total_captures"],
		],
		"Pocket piles: %s visible / cap fades %s / %s / last %s @ %s" % [
			snapshot["pocket_capture_visible_by_pocket"],
			snapshot["pocket_capture_cap_removals"],
			snapshot["pocket_capture_mode_policy"],
			snapshot["pocket_capture_last_identity"],
			snapshot["pocket_capture_last_pocket"],
		],
		"Pocket basins: %s authored / %s missing / guides %s / rev %s / reflows %s (%s)" % [
			snapshot["pocket_capture_authored_anchors"],
			snapshot["pocket_capture_missing_anchors"],
			_debug_bool_text(bool(snapshot["pocket_capture_anchor_debug"])),
			snapshot["pocket_capture_layout_revision"],
			snapshot["pocket_capture_reflows"],
			snapshot["pocket_capture_last_reflow_reason"],
		],
	]


func _make_aim_preview_performance_lines(snapshot: Dictionary) -> Array:
	var lines: Array = [
		"AIM PREVIEW",
		"Aim: %s / comparison %s / frame %.2f ms / last %.2f ms" % [
			_debug_bool_text(bool(snapshot["aim_prediction_enabled"])),
			_debug_bool_text(bool(snapshot["shot_comparison_enabled"])),
			float(snapshot["aim_prediction_frame_ms"]),
			float(snapshot["aim_prediction_ms"]),
		],
		"Aim recalcs: %s/frame" % [
			snapshot["aim_prediction_recalculations"],
		],
		"Aim steps: %s cue / %s target" % [
			snapshot["aim_cue_prediction_steps"],
			snapshot["aim_target_prediction_steps"],
		],
		"Aim checks: %s balls / %s pockets / %s rails" % [
			snapshot["aim_ball_collision_checks"],
			snapshot["aim_pocket_checks"],
			snapshot["aim_rail_checks"],
		],
		"Aim broadphase: %s cells / %s balls / %s query cells / %s candidates" % [
			snapshot["aim_spatial_cells"],
			snapshot["aim_spatial_balls"],
			snapshot["aim_spatial_query_cells"],
			snapshot["aim_spatial_candidates"],
		],
		"Aim draw: %.2f ms / %s segments / %s calls" % [
			float(snapshot["aim_draw_ms"]),
			snapshot["aim_draw_segments"],
			snapshot["aim_draw_calls"],
		],
	]
	lines.append("")
	lines.append_array(_make_hit_ball_prediction_lines(snapshot))
	return lines


func _make_aim_simulation_lines(snapshot: Dictionary) -> Array:
	var simulation: Dictionary = snapshot.get("aim_cloned_simulation", {})
	var availability: Dictionary = snapshot.get("aim_cloned_prediction_availability", {})
	var invalidation: Dictionary = snapshot.get("aim_cloned_invalidation", {})
	var staged_prediction: Dictionary = snapshot.get("aim_staged_prediction", {})
	var player_parity: Dictionary = snapshot.get("aim_player_parity", {})
	if simulation.is_empty():
		var unavailable_lines: Array = [
			"No cloned trajectory has been built.",
			"Enable Debug Aim Line, then drag the cue.",
		]
		_append_player_aim_parity_lines(unavailable_lines, player_parity)
		_append_staged_aim_lines(unavailable_lines, staged_prediction)
		_append_aim_availability_lines(unavailable_lines, availability, invalidation)
		return unavailable_lines
	var warnings: Array = simulation.get("unsupported_warnings", [])
	var warning_texts: Array[String] = []
	for warning_value in warnings:
		if warning_value is Dictionary:
			warning_texts.append("%s (%s)" % [
				warning_value.get("reason", "unsupported"),
				warning_value.get("ball_label", "Ball ?"),
			])
	var lines: Array = []
	_append_player_aim_parity_lines(lines, player_parity)
	lines.append_array([
		"Enabled: %s / valid: %s / complete: %s" % [
			_debug_true_false_text(bool(simulation.get("configuration", {}).get("enabled", false))),
			_debug_true_false_text(bool(simulation.get("valid", false))),
			_debug_true_false_text(bool(simulation.get("complete", false))),
		],
		"Result detail: %s" % simulation.get("configuration", {}).get("result_detail_mode", "full_debug"),
		"Simulated: %.3f sec / %s frames / %s substeps" % [
			float(simulation.get("elapsed_simulated_time", 0.0)),
			simulation.get("simulated_physics_frames", 0),
			simulation.get("simulated_substeps", 0),
		],
		"Control / geometry: %s / %s (budgets %s / %s)" % [
			simulation.get("total_iterations", 0),
			simulation.get("geometry_probes", 0),
			simulation.get("control_iteration_budget", 0),
			simulation.get("geometry_probe_budget", 0),
		],
		"Candidates / pairs: %s / %s" % [
			simulation.get("candidate_tests", 0),
			simulation.get("pair_checks", 0),
		],
		"Balls: %s traced / %s retained points" % [
			simulation.get("total_traced_balls", 0),
			simulation.get("retained_trace_points", simulation.get("total_trace_points", 0)),
		],
		"Trace raw / retained / simplified: %s / %s / %s (%.1f%%)" % [
			simulation.get("raw_trace_points_generated", 0),
			simulation.get("retained_trace_points", 0),
			simulation.get("trace_points_removed_by_simplification", 0),
			float(simulation.get("trace_simplification_percent", 0.0)),
		],
		"Trace filtered spacing / collinear: %s / %s" % [
			simulation.get("trace_points_removed_by_spacing_or_duplicates", 0),
			simulation.get("trace_points_removed_by_collinear_simplification", 0),
		],
		"Events: %s / contacts %s (cue %s)" % [
			simulation.get("total_events", 0),
			simulation.get("total_ball_contacts", 0),
			simulation.get("total_cue_ball_contacts", 0),
		],
		"Rails: %s / pockets %s" % [
			simulation.get("total_rail_contacts", 0),
			simulation.get("total_pocket_captures", 0),
		],
		"Broadphase: %s cells / max cell %s / full %s / incremental %s" % [
			simulation.get("broadphase_cells", 0),
			simulation.get("maximum_broadphase_cell_size", 0),
			simulation.get("full_broadphase_rebuilds", 0),
			simulation.get("incremental_broadphase_updates", 0),
		],
		"Stop: %s" % simulation.get("stop_reason", "none"),
		"Cap: %s" % str(simulation.get("cap_reached", "none")),
	])
	_append_staged_aim_lines(lines, staged_prediction)
	_append_aim_availability_lines(lines, availability, invalidation)
	var debug_mode: Dictionary = snapshot.get("debug_aim_mode", {})
	if bool(debug_mode.get("enabled", false)):
		lines.append("Debug Aim Mode conversions current/session/spawns: %s / %s / %s" % [
			debug_mode.get("anomalies_converted_this_activation", 0),
			debug_mode.get("anomalies_converted_this_session", 0),
			debug_mode.get("anomaly_spawn_requests_normalized", 0),
		])
	var iteration_breakdown: Dictionary = simulation.get("iteration_breakdown", {})
	lines.append("Iteration split S/P/B/K/O: %s / %s / %s / %s / %s" % [
		iteration_breakdown.get("substeps", 0),
		iteration_breakdown.get("pair_collision", 0),
		iteration_breakdown.get("boundaries", 0),
		iteration_breakdown.get("pockets", 0),
		iteration_breakdown.get("other", 0),
	])
	var cap_detail: Dictionary = simulation.get("iteration_cap_detail", {})
	if not cap_detail.is_empty():
		lines.append("Cap phase / ball / geometry: %s / %s / %s" % [
			cap_detail.get("phase_active", "unknown"),
			cap_detail.get("last_processed_ball", "none"),
			cap_detail.get("last_geometry_index", -1),
		])
		lines.append("Cap moving / time / remaining: %s / %.3f / %.3f" % [
			cap_detail.get("moving_ball_count", 0),
			float(cap_detail.get("simulated_time", 0.0)),
			float(cap_detail.get("remaining_time_fraction", -1.0)),
		])
	var geometry_cap_detail: Dictionary = simulation.get("geometry_probe_cap_detail", {})
	if not geometry_cap_detail.is_empty():
		lines.append("Geometry cap phase / ball / geometry: %s / %s / %s" % [
			geometry_cap_detail.get("phase_active", "unknown"),
			geometry_cap_detail.get("last_processed_ball", "none"),
			geometry_cap_detail.get("last_geometry_index", -1),
		])
	if warning_texts.is_empty():
		lines.append("Unsupported: none")
	else:
		lines.append("Unsupported:")
		for warning_text in warning_texts:
			lines.append("- %s" % warning_text)
	return lines


func _append_player_aim_parity_lines(lines: Array, parity: Dictionary) -> void:
	if parity.is_empty():
		return
	lines.append("Player Immediate Source: %s" % parity.get(
		"immediate_source",
		"Lightweight Responsive Predictor"
	))
	lines.append("Player Settled Source: %s" % parity.get(
		"settled_source",
		"Cloned Deterministic Predictor"
	))
	lines.append("Normal Aim Visible Scope: %s" % parity.get(
		"normal_visible_scope",
		"Cue First Contact + Full First-Ball Route"
	))
	lines.append("Extended Aim Visible Depth: %s" % parity.get("extended_visible_depth", 0))
	lines.append("Current Display Source: %s" % parity.get("current_display_source", "Immediate"))
	lines.append("Player Extended Source: %s" % parity.get(
		"extended_source",
		"Cloned Deterministic Predictor"
	))
	lines.append("Immediate first ball: %s" % _debug_aim_ball_label(
		int(parity.get("immediate_first_ball_number", -1)),
		int(parity.get("immediate_first_ball_id", -1))
	))
	lines.append("Cloned first event ball: %s" % _debug_aim_ball_label(
		int(parity.get("cloned_first_event_ball_number", -1)),
		int(parity.get("cloned_first_event_ball_id", -1))
	))
	if bool(parity.get("agreement_available", false)):
		lines.append("Immediate / cloned first contact agree: %s" % _debug_true_false_text(
			bool(parity.get("first_contacts_agree", false))
		))
	else:
		lines.append("Immediate / cloned first contact agree: n/a")
	if bool(parity.get("first_contact_mismatch", false)):
		lines.append("WARNING: Immediate/cloned first-contact mismatch")
	var first_ball_route: Dictionary = parity.get("first_ball_route", {})
	if int(first_ball_route.get("ball_id", -1)) >= 0:
		lines.append("First Struck Ball: %s" % _debug_aim_ball_label(
			int(first_ball_route.get("ball_number", -1)),
			int(first_ball_route.get("ball_id", -1))
		))
		lines.append("First-Ball Events: %s total / %s secondary / %s rails / %s pocket / %s stop" % [
			first_ball_route.get("total_events", 0),
			first_ball_route.get("secondary_ball_contacts", 0),
			first_ball_route.get("rail_contacts", 0),
			first_ball_route.get("pocket_events", 0),
			first_ball_route.get("stop_events", 0),
		])
		lines.append("First-Ball Trace: %s cloned / %s visible / final %s" % [
			first_ball_route.get("cloned_trace_points", 0),
			first_ball_route.get("visible_trace_points", 0),
			first_ball_route.get("final_stop_reason", "none"),
		])
	if bool(parity.get("legacy_debug_ignored", false)):
		lines.append("Legacy A/B request ignored outside a debug build.")
	var correction: Dictionary = parity.get("settled_correction", {})
	if not correction.is_empty():
		lines.append("Settled correction: endpoint %.2f px / cue %.2f deg / child %.2f deg" % [
			float(correction.get("cue_endpoint_delta_px", 0.0)),
			float(correction.get("cue_final_segment_angle_delta_degrees", 0.0)),
			float(correction.get("first_child_angle_delta_degrees", 0.0)),
		])
		lines.append("Rails immediate / cloned: %s / %s; max route delta %.2f px" % [
			correction.get("immediate_pre_contact_rails", 0),
			correction.get("cloned_pre_contact_rails", 0),
			float(correction.get("maximum_route_deviation_px", 0.0)),
		])
	lines.append("")


func _append_staged_aim_lines(lines: Array, staged: Dictionary) -> void:
	if staged.is_empty() or not bool(staged.get("show_status", true)):
		return
	lines.append("")
	lines.append("STAGED PREDICTION")
	lines.append("Enabled / state: %s / %s" % [
		_debug_true_false_text(bool(staged.get("enabled", true))),
		staged.get("state", "idle"),
	])
	lines.append("Reason: %s" % staged.get("reason", "none"))
	lines.append("Player class / display: %s / %s" % [
		staged.get("player_request_class", "none"),
		staged.get("current_display_source", "Immediate"),
	])
	lines.append("Blend: %.0f%% / %s ms / interruptions %s" % [
		float(staged.get("blend_progress", 1.0)) * 100.0,
		staged.get("blend_duration_ms", 60),
		staged.get("blend_interruptions", 0),
	])
	lines.append("Settle remaining / configured: %.1f / %s ms" % [
		float(staged.get("settle_remaining_ms", 0.0)),
		staged.get("settle_delay_ms", 75),
	])
	lines.append("Request current / accepted / pending: %s / %s / %s" % [
		staged.get("current_request_id", 0),
		staged.get("last_accepted_request_id", 0),
		staged.get("pending_request_count", 0),
	])
	lines.append("Reveal: %.0f%% / depth %s of %s / branches %s" % [
		float(staged.get("reveal_progress", 0.0)) * 100.0,
		staged.get("visible_depth", 0),
		staged.get("maximum_depth", 0),
		staged.get("visible_branches", 0),
	])
	lines.append("Reveal duration: %s ms" % staged.get("reveal_duration_ms", 125))
	lines.append("Stale result retained: %s" % _debug_true_false_text(
		bool(staged.get("stale_result_available", false))
	))


func _append_aim_availability_lines(
	lines: Array,
	availability: Dictionary,
	invalidation: Dictionary
) -> void:
	if availability.is_empty():
		return
	lines.append("")
	lines.append("PREDICTION AVAILABILITY")
	lines.append("Available / requested / enabled: %s / %s / %s" % [
		_debug_true_false_text(bool(availability.get("available", false))),
		_debug_true_false_text(bool(availability.get("live_preview_requested", false))),
		_debug_true_false_text(bool(availability.get("cloned_simulation_enabled", false))),
	])
	lines.append("Revision table / cache / success: %s / %s / %s" % [
		availability.get("table_revision", -1),
		availability.get("cached_revision", -1),
		availability.get("last_successful_rebuild_revision", -1),
	])
	lines.append("Cache valid / moving balls: %s / %s" % [
		_debug_true_false_text(bool(availability.get("cache_valid", false))),
		availability.get("moving_ball_count", 0),
	])
	lines.append("Pending drops / landing callbacks: %s / %s" % [
		availability.get("pending_spawn_count", 0),
		_debug_true_false_text(bool(availability.get("pending_landing_callbacks", false))),
	])
	lines.append("Balls active / cloned / transient / unsupported: %s / %s / %s / %s" % [
		availability.get("active_ball_count", 0),
		availability.get("cloned_ball_count", 0),
		availability.get("transient_ball_count", 0),
		availability.get("unsupported_ball_count", 0),
	])
	lines.append("Blocker: %s" % availability.get("blocker_reason", "none"))
	var blocker_details: String = str(availability.get("blocker_details", ""))
	if not blocker_details.is_empty():
		lines.append("- %s" % blocker_details)
	lines.append("Refresh pending: %s" % _debug_true_false_text(
		bool(availability.get("refresh_pending", false))
	))
	if invalidation.is_empty():
		return
	lines.append("Invalidations / last: %s / %s" % [
		invalidation.get("cache_invalidations", 0),
		invalidation.get("last_invalidation_reason", "none"),
	])
	lines.append("Revision changes: %s" % invalidation.get("prediction_revision_changes", 0))
	lines.append("Invalidation categories roster / spawn / remove / transform / unsupported: %s / %s / %s / %s / %s" % [
		invalidation.get("roster_change_invalidations", 0),
		invalidation.get("spawn_complete_invalidations", 0),
		invalidation.get("remove_sink_invalidations", 0),
		invalidation.get("transform_invalidations", 0),
		invalidation.get("unsupported_state_invalidations", 0),
	])
	lines.append("Invalidation reasons: %s" % _format_aim_profiler_reason_counts(
		invalidation.get("invalidation_reasons", {})
	))
	lines.append("Post-invalidation rebuilds ok / failed: %s / %s" % [
		invalidation.get("successful_rebuilds_after_invalidation", 0),
		invalidation.get("failed_rebuilds_after_invalidation", 0),
	])


func _make_aim_profiler_lines(snapshot: Dictionary) -> Array:
	var profiler: Dictionary = snapshot.get("aim_cloned_profiler", {})
	if profiler.is_empty():
		return ["No cloned trajectory profiler is available."]

	var enabled: bool = bool(profiler.get("enabled", false))
	var sample_count: int = int(profiler.get("sample_count", 0))
	var history_limit: int = int(profiler.get("history_limit", 120))
	var cache_hits: int = int(profiler.get("cache_hits", 0))
	var cache_misses: int = int(profiler.get("cache_misses", 0))
	var cache_attempts: int = cache_hits + cache_misses
	var hit_rate: float = (
		100.0 * float(cache_hits) / float(cache_attempts)
		if cache_attempts > 0
		else 0.0
	)
	var lines: Array = [
		"Profiling: %s / samples %s of %s" % [
			"enabled" if enabled else "disabled",
			sample_count,
			history_limit,
		],
		"Rebuilds/sec at last completion: %.1f" % float(profiler.get("rebuilds_per_second", 0.0)),
		"Cache: %s hits / %s misses / %.1f%% hit" % [cache_hits, cache_misses, hit_rate],
		"Last rebuild reason: %s" % profiler.get("last_rebuild_reason", "none"),
		"Reason counts: %s" % _format_aim_profiler_reason_counts(
			profiler.get("rebuild_reason_counts", {})
		),
		"Player request classes: %s" % _format_aim_profiler_reason_counts(
			profiler.get("player_request_class_counts", {})
		),
	]
	_append_staged_profiler_lines(lines, profiler)
	if not enabled:
		lines.append("Enable Profile Cloned Aim Simulation to collect new samples.")
	if sample_count <= 0:
		lines.append("No completed profiled rebuilds yet.")
		_append_aim_benchmark_lines(lines, profiler.get("benchmark", {}))
		return lines

	lines.append("")
	lines.append("CPU phase time (us): last | rolling avg | P95 | max")
	var phase_stats: Dictionary = profiler.get("phase_stats", {})
	for phase_row in AIM_PROFILER_PHASE_ROWS:
		var phase_key: String = str(phase_row.get("key", ""))
		var phase: Dictionary = phase_stats.get(phase_key, {})
		lines.append("%s: %s | %.1f | %.1f | %s" % [
			phase_row.get("label", phase_key),
			phase.get("last_us", 0),
			float(phase.get("average_us", 0.0)),
			float(phase.get("p95_us", 0.0)),
			phase.get("maximum_us", 0),
		])

	var last_sample: Dictionary = profiler.get("last_sample", {})
	lines.append("")
	lines.append("Last completed workload")
	lines.append("Player request class: %s" % last_sample.get(
		"player_request_class",
		"unclassified"
	))
	lines.append("Frames/substeps: %s / %s" % [
		last_sample.get("simulated_physics_frames", 0),
		last_sample.get("simulated_substeps", 0),
	])
	lines.append("Control / geometry work: %s / %s" % [
		last_sample.get("total_iterations", 0),
		last_sample.get("geometry_probes", 0),
	])
	lines.append("Broadphase full / incremental / current / swept: %s / %s / %s / %s" % [
		last_sample.get("full_broadphase_rebuilds", 0),
		last_sample.get("incremental_broadphase_updates", 0),
		last_sample.get("current_grid_rebuilds", 0),
		last_sample.get("swept_grid_rebuilds", 0),
	])
	lines.append("Candidate tests / pair checks: %s / %s" % [
		last_sample.get("candidate_tests", 0),
		last_sample.get("pair_checks", 0),
	])
	lines.append("Contacts resolved: %s" % last_sample.get("contacts_resolved", 0))
	lines.append("Balls traced / trace points: %s / %s" % [
		last_sample.get("balls_traced", 0),
		last_sample.get("trace_points", 0),
	])
	lines.append("Visible path segments: %s" % last_sample.get("visible_path_segments", 0))
	lines.append("Predicted / compared events: %s / %s" % [
		last_sample.get("predicted_event_count", 0),
		last_sample.get("compared_event_count", 0),
	])
	lines.append("")
	lines.append("Boundary/pocket work")
	lines.append("Shapes rail / jaw / pockets: %s / %s / %s" % [
		last_sample.get("rail_shapes_available", 0),
		last_sample.get("jaw_shapes_available", 0),
		last_sample.get("pocket_count_available", 0),
	])
	lines.append("Tests rail / jaw / pocket: %s / %s / %s" % [
		last_sample.get("rail_shapes_tested", 0),
		last_sample.get("jaw_shapes_tested", 0),
		last_sample.get("pockets_tested", 0),
	])
	lines.append("Chronology rail / pocket: %s / %s" % [
		last_sample.get("rail_swept_tests", 0),
		last_sample.get("pocket_swept_tests", 0),
	])
	lines.append("AABB rejects rail / pocket: %s / %s" % [
		last_sample.get("rail_candidates_rejected_by_aabb", 0),
		last_sample.get("pocket_candidates_rejected_by_aabb", 0),
	])
	lines.append("Geometry cache hit/rebuild: %s / %s" % [
		last_sample.get("static_geometry_cache_hits", 0),
		last_sample.get("static_geometry_cache_rebuilds", 0),
	])
	lines.append("Scratch reuses / temp allocations: %s / %s" % [
		last_sample.get("scratch_buffer_reuses", 0),
		last_sample.get("temporary_allocations", 0),
	])
	lines.append("Accepted rail / pocket: %s / %s" % [
		last_sample.get("rail_events_accepted", 0),
		last_sample.get("pocket_events_accepted", 0),
	])
	lines.append("Stopped skipped move / rail / pocket: %s / %s / %s" % [
		last_sample.get("stopped_balls_skipped_from_movement", 0),
		last_sample.get("stopped_balls_skipped_from_rail_checks", 0),
		last_sample.get("stopped_balls_skipped_from_pocket_checks", 0),
	])
	lines.append("Moving avg / max / newly stopped: %.2f / %s / %s" % [
		float(last_sample.get("moving_balls_per_substep_average", 0.0)),
		last_sample.get("moving_balls_per_substep_maximum", 0),
		last_sample.get("balls_newly_stopped", 0),
	])
	lines.append("Stationary targets avg / max: %.2f / %s" % [
		float(last_sample.get("stationary_targets_per_substep_average", 0.0)),
		last_sample.get("stationary_targets_per_substep_maximum", 0),
	])
	var iteration_breakdown: Dictionary = last_sample.get("iteration_breakdown", {})
	lines.append("Work split substep / pair / boundary / pocket / other: %s / %s / %s / %s / %s" % [
		iteration_breakdown.get("substeps", 0),
		iteration_breakdown.get("pair_collision", 0),
		iteration_breakdown.get("boundaries", 0),
		iteration_breakdown.get("pockets", 0),
		iteration_breakdown.get("other", 0),
	])
	var cap_detail: Dictionary = last_sample.get("iteration_cap_detail", {})
	if not cap_detail.is_empty():
		lines.append("Iteration cap: %s > %s in %s (%s moving)" % [
			cap_detail.get("first_trigger_total", 0),
			cap_detail.get("configured_limit", 0),
			cap_detail.get("phase_active", "unknown"),
			cap_detail.get("moving_ball_count", 0),
		])
	var geometry_cap_detail: Dictionary = last_sample.get("geometry_probe_cap_detail", {})
	if not geometry_cap_detail.is_empty():
		lines.append("Geometry cap: %s > %s in %s" % [
			geometry_cap_detail.get("first_trigger_total", 0),
			geometry_cap_detail.get("configured_limit", 0),
			geometry_cap_detail.get("phase_active", "unknown"),
		])
	lines.append("AimPreview _draw CPU: %s us (not GPU time)" % profiler.get("aim_preview_draw_cpu_us", 0))
	_append_aim_benchmark_lines(lines, profiler.get("benchmark", {}))
	return lines


func _append_staged_profiler_lines(lines: Array, profiler: Dictionary) -> void:
	var staged: Dictionary = profiler.get("staged_prediction", {})
	var state: Dictionary = profiler.get("staging_state", {})
	if staged.is_empty() and state.is_empty():
		return
	var counters: Dictionary = staged.get("counters", {})
	var timing: Dictionary = staged.get("timing_stats", {})
	lines.append("")
	lines.append("STAGED AIM")
	lines.append("State / reason: %s / %s" % [
		state.get("state", "idle"),
		state.get("reason", "none"),
	])
	lines.append("Settle / reveal: %s / %s ms" % [
		state.get("settle_delay_ms", 75),
		state.get("reveal_duration_ms", 125),
	])
	lines.append("Requests created / forced: %s / %s" % [
		counters.get("deep_requests_created", 0),
		counters.get("deep_requests_forced", 0),
	])
	lines.append("Canceled / invalidated / blocked: %s / %s / %s" % [
		counters.get("deep_requests_canceled_before_run", 0),
		counters.get("deep_requests_invalidated_before_run", 0),
		counters.get("deep_requests_blocked_before_run", 0),
	])
	lines.append("Results completed / accepted: %s / %s" % [
		counters.get("deep_results_completed", 0),
		counters.get("deep_results_accepted", 0),
	])
	lines.append("Discarded on arrival (ID / revision): %s (%s / %s)" % [
		counters.get("deep_results_discarded_on_arrival", 0),
		counters.get("deep_results_rejected_request_id_mismatch", 0),
		counters.get("deep_results_rejected_revision_mismatch", 0),
	])
	lines.append("Shown / later invalidated / hidden: %s / %s / %s" % [
		counters.get("accepted_results_shown", 0),
		counters.get("shown_results_later_invalidated", 0),
		counters.get("shown_results_hidden_by_new_aim", 0),
	])
	lines.append("Reveals completed / interrupted: %s / %s" % [
		counters.get("reveal_completed_count", 0),
		counters.get("reveal_interrupted_count", 0),
	])
	lines.append("Completed before next aim: %s" % counters.get(
		"reveal_completed_before_next_aim_count",
		0
	))
	lines.append("Active-drag / settled deep rebuilds: %s / %s" % [
		state.get("active_drag_deep_rebuilds", 0),
		state.get("settled_deep_rebuilds", 0),
	])
	lines.append("Cache hit / miss / shown reuse: %s / %s / %s" % [
		counters.get("deep_cache_hits", 0),
		counters.get("deep_cache_misses", 0),
		counters.get("shown_results_reused_from_cache", 0),
	])
	lines.append("Normal / extended requests: %s / %s" % [
		state.get("normal_cloned_requests", 0),
		state.get("extended_cloned_requests", 0),
	])
	lines.append("Normal / extended cache hits: %s / %s" % [
		state.get("normal_cloned_cache_hits", 0),
		state.get("extended_cloned_cache_hits", 0),
	])
	lines.append("Cached results accepted / rejected: %s / %s" % [
		counters.get("cached_results_accepted", 0),
		counters.get("cached_results_rejected", 0),
	])
	lines.append("")
	lines.append("IMMEDIATE PREVIEW - CPU us last | avg | P95 | max")
	lines.append(_format_staged_timing_line(
		"Update",
		timing.get("immediate_update_cpu", {})
	))
	lines.append("Updates/sec / CPU share: %.1f / %.1f%%" % [
		float(staged.get("immediate_updates_per_second", 0.0)),
		float(staged.get("cpu_shares_percent", {}).get("immediate_update", 0.0)),
	])
	lines.append("Update reasons: %s" % _format_aim_profiler_reason_counts(
		counters.get("immediate_update_reason_counts", {})
	))
	lines.append("")
	lines.append("DEEP / LATENCY - us last | avg | P95 | max")
	lines.append(_format_staged_timing_line(
		"Aim stop to request",
		timing.get("deep_compute_start_latency", {})
	))
	lines.append(_format_staged_timing_line(
		"Simulation",
		timing.get("deep_compute_duration", {})
	))
	lines.append(_format_staged_timing_line(
		"First visible",
		timing.get("deep_first_visible_latency_us", {})
	))
	lines.append(_format_staged_timing_line(
		"Fully visible",
		timing.get("deep_fully_visible_latency_us", {})
	))
	lines.append(_format_staged_timing_line(
		"Cache-hit first visible",
		timing.get("cache_hit_first_visible_latency_us", {})
	))
	lines.append("Predictions/sec / CPU share: %.1f / %.1f%%" % [
		float(staged.get("deep_predictions_per_second", 0.0)),
		float(staged.get("cpu_shares_percent", {}).get("deep_compute", 0.0)),
	])
	var settled_metrics: Dictionary = state.get("player_settled_aim", {})
	lines.append("Normal / extended first-visible avg: %.2f / %.2f ms" % [
		float(settled_metrics.get("normal_first_visible_latency_ms", 0.0)),
		float(settled_metrics.get("extended_first_visible_latency_ms", 0.0)),
	])
	lines.append("Settled accepted / identical / corrected: %s / %s / %s" % [
		settled_metrics.get("settled_routes_accepted", 0),
		settled_metrics.get("effectively_identical_routes", 0),
		settled_metrics.get("visible_corrections", 0),
	])
	lines.append("Correction thresholds 1px / 3px / 1deg / first-ball: %s / %s / %s / %s" % [
		settled_metrics.get("corrections_above_1_px", 0),
		settled_metrics.get("corrections_above_3_px", 0),
		settled_metrics.get("corrections_above_1_degree", 0),
		settled_metrics.get("first_ball_disagreements", 0),
	])
	lines.append("")
	lines.append("PRESENTATION - CPU us last | avg | P95 | max")
	lines.append(_format_staged_timing_line(
		"Actual reveal elapsed",
		timing.get("reveal_duration_actual", {})
	))
	lines.append(_format_staged_timing_line(
		"Reveal prep",
		timing.get("reveal_preparation_cpu", {})
	))
	lines.append(_format_staged_timing_line(
		"Reveal draw (CPU, not GPU)",
		timing.get("reveal_cpu_presentation", {})
	))
	lines.append("Reveal duration / progress: %s ms / %.0f%%" % [
		state.get("reveal_duration_ms", 125),
		float(state.get("reveal_progress", 0.0)) * 100.0,
	])
	lines.append("Visible depth / branches / ready-hidden: %s / %s / %s" % [
		state.get("visible_depth", 0),
		state.get("visible_branches", 0),
		state.get("ready_but_hidden_count", 0),
	])
	var interruption_reasons: Variant = counters.get("reveal_interruption_reason_counts", {})
	if interruption_reasons is Dictionary and not (interruption_reasons as Dictionary).is_empty():
		lines.append("Reveal interruption reasons: %s" % _format_aim_profiler_reason_counts(
			interruption_reasons
		))


func _format_staged_timing_line(label: String, stats: Dictionary) -> String:
	return "%s: %s | %.1f | %.1f | %s" % [
		label,
		stats.get("last_us", 0),
		float(stats.get("average_us", 0.0)),
		float(stats.get("p95_us", 0.0)),
		stats.get("maximum_us", 0),
	]


func _append_aim_benchmark_lines(lines: Array, benchmark_value: Variant) -> void:
	if not benchmark_value is Dictionary:
		return
	var benchmark: Dictionary = benchmark_value
	lines.append("")
	lines.append("BENCHMARK")
	lines.append("Capture: %s" % benchmark.get("status", "idle"))
	lines.append("Label: %s" % (
		benchmark.get("label", "")
		if not str(benchmark.get("label", "")).is_empty()
		else "none"
	))
	lines.append("Preset / result: %s / %s" % [
		benchmark.get("preset", "Custom"),
		benchmark.get("result_mode", "unknown"),
	])
	lines.append("Duration / rebuilds: %.2f s / %s" % [
		float(benchmark.get("capture_duration_seconds", 0.0)),
		benchmark.get("captured_rebuilds", 0),
	])
	lines.append("Active-drag / settled / forced: %s / %s / %s" % [
		benchmark.get("active_drag_rebuilds", 0),
		benchmark.get("settled_rebuilds", 0),
		benchmark.get("forced_rebuilds", 0),
	])
	lines.append("Rebuild avg / P95 / max: %.2f / %.2f / %.2f ms" % [
		float(benchmark.get("average_total_rebuild_ms", 0.0)),
		float(benchmark.get("p95_total_rebuild_ms", 0.0)),
		float(benchmark.get("maximum_total_rebuild_ms", 0.0)),
	])
	lines.append("Prediction CPU share: %.1f%%" % float(
		benchmark.get("prediction_cpu_share_percent", 0.0)
	))
	var staged: Dictionary = benchmark.get("staged_prediction", {})
	var staged_counters: Dictionary = staged.get("counters", {})
	if not staged.is_empty():
		lines.append("Immediate updates / sec: %s / %.1f" % [
			staged_counters.get("immediate_updates", 0),
			float(staged.get("immediate_updates_per_second", 0.0)),
		])
		lines.append("Requests made / canceled / invalid / blocked: %s / %s / %s / %s" % [
			staged_counters.get("deep_requests_created", 0),
			staged_counters.get("deep_requests_canceled_before_run", 0),
			staged_counters.get("deep_requests_invalidated_before_run", 0),
			staged_counters.get("deep_requests_blocked_before_run", 0),
		])
		lines.append("Results complete / accepted / discarded: %s / %s / %s" % [
			staged_counters.get("deep_results_completed", 0),
			staged_counters.get("deep_results_accepted", 0),
			staged_counters.get("deep_results_discarded_on_arrival", 0),
		])
		lines.append("Shown / reveal complete / interrupted: %s / %s / %s" % [
			staged_counters.get("accepted_results_shown", 0),
			staged_counters.get("reveal_completed_count", 0),
			staged_counters.get("reveal_interrupted_count", 0),
		])
	lines.append("Last copied: %s" % benchmark.get("last_copied_status", "not copied"))


func _format_aim_profiler_reason_counts(value: Variant) -> String:
	if not value is Dictionary:
		return "none"
	var reason_counts: Dictionary = value
	if reason_counts.is_empty():
		return "none"
	var reasons: Array[String] = []
	for reason_value in reason_counts.keys():
		reasons.append(str(reason_value))
	reasons.sort()
	var parts: Array[String] = []
	for reason in reasons:
		parts.append("%s=%s" % [reason, reason_counts.get(reason, 0)])
	return ", ".join(parts)


func _make_aim_event_chain_lines(snapshot: Dictionary) -> Array:
	var comparison: Dictionary = snapshot.get("aim_cloned_event_comparison", {})
	if comparison.is_empty():
		return ["No cloned event-chain comparison available."]
	if not bool(comparison.get("enabled", true)):
		return [
			"Predicted event-chain comparison is disabled.",
			"Reason: %s" % comparison.get("divergence_reason", "comparison_disabled"),
			"Prediction and actual evidence remain preserved.",
		]
	var lines: Array = [
		"Matched: %s / predicted %s / actual %s" % [
			comparison.get("matched_event_count", 0),
			comparison.get("predicted_event_count", 0),
			comparison.get("actual_event_count", 0),
		],
		"First divergence: %s" % (
			"none"
			if int(comparison.get("first_divergent_event_index", -1)) < 0
			else "#%s - %s" % [
				int(comparison.get("first_divergent_event_index", -1)) + 1,
				comparison.get("divergence_reason", "mismatch"),
			]
		),
		"Prediction stop: %s" % comparison.get("prediction_stop_reason", "none"),
		"",
	]
	var entries: Array = comparison.get("entries", [])
	for entry_value in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var result_label: String = "MATCH"
		if not bool(entry.get("matches", false)):
			result_label = "MISMATCH"
			if int(entry.get("event_index", -1)) == int(comparison.get("first_divergent_event_index", -1)):
				result_label = "FIRST DIVERGENCE"
		lines.append("EVENT %s - %s" % [
			int(entry.get("event_index", 0)) + 1,
			result_label,
		])
		lines.append("Predicted: %s" % _format_cloned_event_entry(
			str(entry.get("predicted_type", "unknown")),
			str(entry.get("predicted_source_label", "Ball ?")),
			str(entry.get("predicted_target_label", ""))
		))
		lines.append("Actual: %s" % _format_cloned_event_entry(
			str(entry.get("actual_type", "unknown")),
			str(entry.get("actual_source_label", "Ball ?")),
			str(entry.get("actual_target_label", ""))
		))
		lines.append("Delta: %.2f px / %.2f deg / %+.3f sec" % [
			float(entry.get("contact_position_delta", 0.0)),
			float(entry.get("normal_angle_delta", 0.0)),
			float(entry.get("timing_delta", 0.0)),
		])
		if not bool(entry.get("matches", false)):
			lines.append("Result: %s" % entry.get("result", "mismatch"))
		lines.append("")
	var predicted_events: Array = comparison.get("predicted_events", [])
	var actual_events: Array = comparison.get("actual_events", [])
	for event_index in range(entries.size(), predicted_events.size()):
		var predicted: Dictionary = predicted_events[event_index] as Dictionary
		lines.append("EVENT %s" % (event_index + 1))
		lines.append("Predicted: %s" % _format_cloned_event_dictionary(predicted))
		lines.append("Actual: pending" if not bool(comparison.get("actual_chain_complete", false)) else "Actual: none")
		lines.append("")
	for event_index in range(entries.size(), actual_events.size()):
		var actual: Dictionary = actual_events[event_index] as Dictionary
		lines.append("EVENT %s" % (event_index + 1))
		lines.append("Predicted: none")
		lines.append("Actual: %s" % _format_cloned_event_dictionary(actual))
		lines.append("")
	return lines


func _format_cloned_event_dictionary(event: Dictionary) -> String:
	return _format_cloned_event_entry(
		str(event.get("event_type", "unknown")),
		str(event.get("source_ball_label", "Ball ?")),
		str(event.get("target_ball_label", ""))
	)


func _format_cloned_event_entry(event_type: String, source_label: String, target_label: String) -> String:
	match event_type:
		"ball_contact":
			return "%s -> %s" % [source_label, target_label]
		"rail_contact":
			return "%s -> Rail" % source_label
		"pocket":
			return "%s -> Pocket" % source_label
		"stopped":
			return "%s -> Stopped" % source_label
	return "%s -> %s" % [source_label, event_type]


func _make_hit_ball_prediction_lines(snapshot: Dictionary) -> Array:
	var lines: Array = ["HIT-BALL PREDICTION"]
	var active: bool = bool(snapshot["aim_hit_ball_prediction_active"])
	lines.append("Active: %s / route: %s" % [
		_debug_true_false_text(active),
		snapshot["aim_hit_ball_route"],
	])
	if not active:
		return lines

	lines.append("Target: %s (#%s) / cue segment: %s / pre-hit rails: %s" % [
		_debug_id_text(int(snapshot["aim_hit_ball_target_ball_id"])),
		snapshot["aim_hit_ball_target_number"],
		snapshot["aim_hit_ball_cue_impact_segment_index"],
		snapshot["aim_hit_ball_rail_hits_before_impact"],
	])
	lines.append("Impact point: %s" % _debug_vector_text(snapshot["aim_hit_ball_impact_point"]))
	lines.append("Impact normal: %s / incoming: %s" % [
		_debug_vector_text(snapshot["aim_hit_ball_impact_normal"]),
		_debug_vector_text(snapshot["aim_hit_ball_impact_incoming_direction"]),
	])
	lines.append("Transfer velocity: %s / direction: %s" % [
		_debug_vector_text(snapshot["aim_hit_ball_transferred_velocity"]),
		_debug_vector_text(snapshot["aim_hit_ball_transferred_direction"]),
	])
	lines.append("Target path: %s steps / %s pts / %s px" % [
		snapshot["aim_hit_ball_target_prediction_steps"],
		snapshot["aim_hit_ball_target_path_point_count"],
		_debug_distance_text(float(snapshot["aim_hit_ball_target_path_length"])),
	])
	lines.append("Target stop: %s" % snapshot["aim_hit_ball_target_first_stop_reason"])
	return lines


func _make_aim_launch_lines(snapshot: Dictionary) -> Array:
	var compare: Dictionary = _get_aim_compare_snapshot(snapshot)
	var launch: Dictionary = compare.get("launch", {})
	return [
		"Debug Aim Line: %s" % _debug_bool_text(bool(compare.get("debug_aim_line_enabled", false))),
		"Deep commit: %s" % compare.get(
			"deep_prediction_commit_status",
			"immediate_only_at_commit"
		),
		"Source: %s / persisted %s / recording %s" % [
			compare.get("source", "none"),
			_debug_true_false_text(bool(compare.get("persisted_overlay", false))),
			_debug_true_false_text(bool(compare.get("recording_actual_trace", false))),
		],
		"Preview angle: %s" % _debug_angle_text(float(launch.get("predicted_angle", 0.0))),
		"Actual angle: %s" % _debug_angle_text(float(launch.get("actual_angle", 0.0))),
		"Angle delta: %s" % _debug_angle_text(float(launch.get("angle_delta", 0.0))),
		"Preview dir: %s" % _debug_vector_text(launch.get("predicted_direction", Vector2.ZERO)),
		"Actual dir: %s" % _debug_vector_text(launch.get("actual_direction", Vector2.ZERO)),
		"Direction dot: %.4f" % float(launch.get("direction_dot", 0.0)),
		"Preview speed: %.1f" % float(launch.get("predicted_speed", 0.0)),
		"Actual speed: %.1f" % float(launch.get("actual_speed", 0.0)),
		"Speed delta: %.1f" % float(launch.get("speed_delta", 0.0)),
	]


func _make_aim_contact_lines(snapshot: Dictionary) -> Array:
	var compare: Dictionary = _get_aim_compare_snapshot(snapshot)
	var contact: Dictionary = compare.get("contact", {})
	return [
		"Predicted ball: %s (#%s)" % [
			_debug_id_text(int(contact.get("predicted_hit_ball_id", -1))),
			contact.get("predicted_hit_ball_number", -1),
		],
		"Actual ball: %s (#%s)" % [
			_debug_id_text(int(contact.get("actual_hit_ball_id", -1))),
			contact.get("actual_hit_ball_number", -1),
		],
		"Pred cue center: %s" % _debug_vector_text(contact.get("predicted_cue_center", Vector2.ZERO)),
		"Actual cue center: %s" % _debug_vector_text(contact.get("actual_cue_center", Vector2.ZERO)),
		"Center delta: %s px" % _debug_distance_text(float(contact.get("cue_center_delta", -1.0))),
		"Pred target center: %s" % _debug_vector_text(contact.get("predicted_target_center", Vector2.ZERO)),
		"Actual target center: %s" % _debug_vector_text(contact.get("actual_target_center", Vector2.ZERO)),
		"Target delta: %s px" % _debug_distance_text(float(contact.get("target_center_delta", -1.0))),
		"Pred contact: %s" % _debug_vector_text(contact.get("predicted_contact_point", Vector2.ZERO)),
		"Actual contact: %s" % _debug_vector_text(contact.get("actual_contact_point", Vector2.ZERO)),
		"Contact delta: %s px" % _debug_distance_text(float(contact.get("contact_point_delta", -1.0))),
		"Normal angle: %s -> %s / delta %s" % [
			_debug_angle_text(float(contact.get("predicted_normal_angle", 0.0))),
			_debug_angle_text(float(contact.get("actual_normal_angle", 0.0))),
			_debug_angle_text(float(contact.get("normal_angle_delta", 0.0))),
		],
		"Cut angle: %s -> %s / delta %s" % [
			_debug_angle_text(float(contact.get("predicted_cut_angle", 0.0))),
			_debug_angle_text(float(contact.get("actual_cut_angle", 0.0))),
			_debug_angle_text(float(contact.get("cut_angle_delta", 0.0))),
		],
		"Verdict: %s" % compare.get("verdict", "none"),
	]


func _make_aim_response_lines(snapshot: Dictionary) -> Array:
	var compare: Dictionary = _get_aim_compare_snapshot(snapshot)
	var response: Dictionary = compare.get("response", {})
	return [
		"Outgoing angle: %s -> %s" % [
			_debug_angle_text(float(response.get("predicted_outgoing_angle", 0.0))),
			_debug_angle_text(float(response.get("actual_outgoing_angle", 0.0))),
		],
		"Outgoing delta: %s" % _debug_angle_text(float(response.get("outgoing_angle_delta", 0.0))),
		"Struck speed: %.1f -> %.1f" % [
			float(response.get("predicted_speed", 0.0)),
			float(response.get("actual_speed", 0.0)),
		],
		"Speed delta: %.1f" % float(response.get("speed_delta", 0.0)),
		"Distance to hit: %s -> %s px" % [
			_debug_distance_text(float(response.get("predicted_distance_to_first_hit", -1.0))),
			_debug_distance_text(float(response.get("actual_distance_to_first_hit", -1.0))),
		],
		"Distance delta: %.1f px" % float(response.get("distance_delta", 0.0)),
		"Center dist predicted/actual: %s / %s" % [
			_debug_distance_text(float(response.get("predicted_center_distance", -1.0))),
			_debug_distance_text(float(response.get("actual_center_distance", -1.0))),
		],
		"Center distance delta: %.2f px" % float(response.get("center_distance_delta", 0.0)),
		"Effective radius preview/physics: %s / %s" % [
			_debug_distance_text(float(response.get("prediction_effective_collision_radius", -1.0))),
			_debug_distance_text(float(response.get("physics_effective_collision_radius", -1.0))),
		],
		"Skin preview/physics: %.2f / %.2f px" % [
			float(response.get("prediction_collision_skin", 0.0)),
			float(response.get("physics_collision_skin", 0.0)),
		],
		"Geometry gap preview/actual: %.2f / %.2f px" % [
			float(response.get("prediction_geometry_gap", 0.0)),
			float(response.get("overlap_gap", 0.0)),
		],
		"Radii cue/target: %.1f / %.1f" % [
			float(response.get("cue_radius", 0.0)),
			float(response.get("target_radius", 0.0)),
		],
	]


func _make_aim_trace_lines(snapshot: Dictionary) -> Array:
	var compare: Dictionary = _get_aim_compare_snapshot(snapshot)
	var trace: Dictionary = compare.get("trace", {})
	var contact: Dictionary = compare.get("contact", {})
	var contact_order: Dictionary = compare.get("contact_order", {})
	var trace_verdict: String = str(compare.get("verdict", "none"))
	if bool(contact_order.get("captured", false)):
		trace_verdict = str(contact_order.get("verdict", trace_verdict))
	return [
		"Balls tracked: %s" % trace.get("actual_balls_tracked", 0),
		"Trace points: %s" % trace.get("total_trace_points", 0),
		"Cue points: %s" % trace.get("cue_trace_points", 0),
		"",
		"First contact:",
		"Frame: %s" % trace.get("first_contact_physics_frame", -1),
		"Time: %s ms" % trace.get("first_contact_time_msec", -1),
		"",
		"Prediction:",
		"Predicted: Ball %s" % contact.get("predicted_hit_ball_number", -1),
		"Actual: Ball %s" % contact.get("actual_hit_ball_number", -1),
		"",
		"Contact order:",
		"TOI first: Ball %s" % contact_order.get("swept_earliest_ball_number", -1),
		"Corrected resolver first: Ball %s" % contact_order.get("resolver_first_ball_number", -1),
		"",
		"Verdict:",
		trace_verdict,
	]


func _make_aim_contact_order_lines(snapshot: Dictionary) -> Array:
	var compare: Dictionary = _get_aim_compare_snapshot(snapshot)
	var contact_order: Dictionary = compare.get("contact_order", {})
	if not bool(contact_order.get("captured", false)):
		return [
			"No contact-order capture recorded.",
			"Take a committed shot with Debug Aim Line enabled.",
			"",
			"Cue TOI enabled: %s / active: %s" % [
				_debug_true_false_text(bool(snapshot.get("cue_toi_correction_enabled", false))),
				_debug_true_false_text(bool(snapshot.get("cue_toi_first_contact_active", false))),
			],
			"Tests / solves / contacts: %s / %s / %s" % [
				snapshot.get("cue_toi_candidate_tests_this_shot", 0),
				snapshot.get("cue_toi_solves_this_shot", 0),
				snapshot.get("cue_toi_contacts_resolved", 0),
			],
			"",
			"Verdict: %s" % contact_order.get("verdict", "Insufficient data"),
		]

	var lines: Array = [
		"Frame: %s / substep: %s of %s / %.3f ms" % [
			contact_order.get("physics_frame", -1),
			contact_order.get("substep_number", -1),
			contact_order.get("total_substeps", -1),
			float(contact_order.get("substep_delta", 0.0)) * 1000.0,
		],
		"Cue: %s -> %s / %.2f px" % [
			_debug_vector_text(contact_order.get("cue_start", Vector2.ZERO)),
			_debug_vector_text(contact_order.get("cue_end", Vector2.ZERO)),
			float(contact_order.get("cue_segment_length", 0.0)),
		],
		"Cue speed: %.1f / radius %.1f / skin %.2f" % [
			float(contact_order.get("cue_speed_at_substep_start", 0.0)),
			float(contact_order.get("cue_radius", 0.0)),
			float(contact_order.get("collision_skin", 0.0)),
		],
		"",
		"Preview first: %s" % _debug_aim_ball_label(
			int(contact_order.get("preview_first_ball_number", -1)),
			int(contact_order.get("preview_first_ball_id", -1))
		),
		"Swept earliest: %s" % _debug_aim_ball_label(
			int(contact_order.get("swept_earliest_ball_number", -1)),
			int(contact_order.get("swept_earliest_ball_id", -1))
		),
		"Corrected resolver first: %s" % _debug_aim_ball_label(
			int(contact_order.get("resolver_first_ball_number", -1)),
			int(contact_order.get("resolver_first_ball_id", -1))
		),
		"Legacy encounter first: %s" % _debug_aim_ball_label(
			int(contact_order.get("legacy_pair_encounter_first_ball_number", -1)),
			int(contact_order.get("legacy_pair_encounter_first_ball_id", -1))
		),
		"Reported actual: %s" % _debug_aim_ball_label(
			int(contact_order.get("reported_actual_ball_number", -1)),
			int(contact_order.get("reported_actual_ball_id", -1))
		),
		"",
		"Candidates: %s (%s stored) / resolved cue contacts: %s" % [
			contact_order.get("candidate_count", 0),
			contact_order.get("stored_candidate_count", 0),
			contact_order.get("resolver_cue_contact_count", 0),
		],
		"First/second TOI delta: %s" % _debug_optional_fraction_text(
			float(contact_order.get("first_second_toi_delta", -1.0))
		),
		"Travel delta: %s" % _debug_optional_distance_text(
			float(contact_order.get("first_second_travel_delta", -1.0))
		),
		"Estimated time delta: %s" % _debug_optional_time_text(
			float(contact_order.get("first_second_time_delta_ms", -1.0))
		),
		"Near-simultaneous: %s (TOI <= %.2f)" % [
			_debug_true_false_text(bool(contact_order.get("near_simultaneous", false))),
			float(contact_order.get("near_simultaneous_toi_threshold", 0.0)),
		],
		"",
		"Cue TOI enabled: %s / active: %s" % [
			_debug_true_false_text(bool(snapshot.get("cue_toi_correction_enabled", false))),
			_debug_true_false_text(bool(snapshot.get("cue_toi_first_contact_active", false))),
		],
		"Tests / solves / contacts: %s / %s / %s" % [
			snapshot.get("cue_toi_candidate_tests_this_shot", 0),
			snapshot.get("cue_toi_solves_this_shot", 0),
			snapshot.get("cue_toi_contacts_resolved", 0),
		],
		"Max candidates / remaining loops: %s / %s" % [
			snapshot.get("cue_toi_max_candidates_in_substep", 0),
			snapshot.get("cue_toi_remaining_time_iterations", 0),
		],
		"Cap hits / duplicate legacy skips: %s / %s" % [
			snapshot.get("cue_toi_event_cap_hits", 0),
			snapshot.get("cue_toi_duplicate_legacy_resolutions_prevented", 0),
		],
		"TOI processing: %.3f ms" % float(snapshot.get("cue_toi_processing_time_ms", 0.0)),
		"",
		"Verdict: %s" % contact_order.get("verdict", "Insufficient data"),
	]

	var candidates_value: Variant = contact_order.get("candidates", [])
	if not candidates_value is Array or (candidates_value as Array).is_empty():
		lines.append("")
		lines.append("No candidate details recorded.")
		return lines

	for candidate_value in candidates_value as Array:
		if not candidate_value is Dictionary:
			continue
		lines.append("")
		lines.append_array(_make_aim_contact_order_candidate_block(
			candidate_value as Dictionary,
			contact_order
		))
	return lines


func _make_aim_contact_order_candidate_block(candidate: Dictionary, contact_order: Dictionary) -> Array:
	var ball_id: int = int(candidate.get("ball_id", -1))
	var tags: Array[String] = []
	if ball_id == int(contact_order.get("preview_first_ball_id", -1)):
		tags.append("PREVIEW")
	if bool(candidate.get("earliest_swept_candidate", false)):
		tags.append("EARLIEST TOI")
	if ball_id == int(contact_order.get("resolver_first_ball_id", -1)):
		tags.append("CORRECTED FIRST")
	if ball_id == int(contact_order.get("legacy_pair_encounter_first_ball_id", -1)):
		tags.append("LEGACY ENCOUNTER FIRST")
	if ball_id == int(contact_order.get("reported_actual_ball_id", -1)):
		tags.append("REPORTED ACTUAL")
	if tags.is_empty():
		tags.append("CANDIDATE")

	var swept_hit: bool = bool(candidate.get("swept_hit", false))
	var toi_text := "%.4f" % float(candidate.get("swept_hit_fraction", -1.0))
	if not swept_hit:
		toi_text = "-- (%s)" % candidate.get("swept_rejection_reason", "no hit")
	var resolution_order: int = int(candidate.get("resolution_order", -1))
	var resolved_text := "no"
	if resolution_order > 0:
		resolved_text = _debug_ordinal_text(resolution_order)
	elif bool(candidate.get("resolver_processed", false)):
		resolved_text = "processed / no response"
	var resolver_visit_text := "not visited"
	if bool(candidate.get("resolver_checked", false)):
		resolver_visit_text = _debug_overlap_gap_text(
			float(candidate.get("overlap_gap_at_pair_visit", 0.0))
		)

	var lines: Array = [
		"B%s  %s" % [candidate.get("ball_number", -1), " / ".join(tags)],
		"TOI: %s / distance: %s" % [
			toi_text,
			_debug_optional_distance_text(float(candidate.get("estimated_contact_distance", -1.0))),
		],
		"Pair encounter/check: %s / %s" % [
			candidate.get("pair_encounter_index", -1),
			candidate.get("pair_check_index", -1),
		],
		"Resolved: %s / %s / impact %.1f" % [
			resolved_text,
			candidate.get("resolution_source", "legacy"),
			float(candidate.get("impact_speed", 0.0)),
		],
		"Post move: %s" % _debug_overlap_gap_text(
			float(candidate.get("overlap_gap_after_movement", 0.0))
		),
		"Resolver visit: %s" % resolver_visit_text,
	]
	if verbose_aim_candidates:
		lines.append("Pair key: %s / duplicate visits %s" % [
			candidate.get("pair_key", "--"),
			candidate.get("duplicate_pair_encounters", 0),
		])
		lines.append("Resolver pair: %s" % candidate.get("resolver_pair_order", "not visited"))
		lines.append("Cells: %s -> %s / neighbor %s" % [
			candidate.get("resolver_source_cell", Vector2i.ZERO),
			candidate.get("resolver_neighbor_cell", Vector2i.ZERO),
			_debug_true_false_text(bool(candidate.get("broadphase_neighbor_after_movement", false))),
		])
		lines.append("Array indexes: %s -> %s" % [
			candidate.get("resolver_source_ball_array_index", -1),
			candidate.get("resolver_target_ball_array_index", -1),
		])
		lines.append("Target: %s -> %s" % [
			_debug_vector_text(candidate.get("target_start", Vector2.ZERO)),
			_debug_vector_text(candidate.get("target_end", Vector2.ZERO)),
		])
		lines.append("Normal: %s" % _debug_vector_text(candidate.get("collision_normal", Vector2.ZERO)))
	return lines


func _make_aim_candidate_lines(snapshot: Dictionary) -> Array:
	var compare: Dictionary = _get_aim_compare_snapshot(snapshot)
	var trace: Dictionary = compare.get("trace", {})
	var contact: Dictionary = compare.get("contact", {})
	var candidates: Array = _get_visible_aim_candidates(
		trace.get("first_hit_candidates", []),
		int(contact.get("actual_hit_ball_id", -1))
	)
	var lines: Array = [
		"Mode: %s" % ("verbose" if verbose_aim_candidates else "focused"),
		"Selected: Ball %s" % trace.get("first_hit_selected_ball_number", -1),
		"Actual: Ball %s" % contact.get("actual_hit_ball_number", -1),
	]
	if candidates.is_empty():
		lines.append("")
		lines.append("No candidate sweep recorded.")
		return lines

	for candidate_index in range(candidates.size()):
		var candidate_value: Variant = candidates[candidate_index]
		if not candidate_value is Dictionary:
			continue
		lines.append("")
		lines.append_array(_make_aim_candidate_block(candidate_value as Dictionary, int(contact.get("actual_hit_ball_id", -1))))
	return lines


func _get_visible_aim_candidates(candidates_value: Variant, actual_ball_id: int) -> Array:
	if not candidates_value is Array:
		return []
	var candidates: Array = candidates_value as Array
	if verbose_aim_candidates:
		return candidates.slice(0, mini(candidates.size(), DEBUG_AIM_CANDIDATE_VERBOSE_MAX_ENTRIES))

	var focused: Array = []
	var rejected: Array = []
	for candidate_value in candidates:
		if not candidate_value is Dictionary:
			continue
		var entry: Dictionary = candidate_value
		var is_disagreement: bool = bool(entry.get("would_hit_real_radius", false)) != bool(entry.get("would_hit_legacy_graze_radius", false))
		var is_priority: bool = (
			bool(entry.get("selected", false))
			or int(entry.get("ball_id", -1)) == actual_ball_id
			or bool(entry.get("accepted", false))
			or is_disagreement
		)
		if is_priority:
			focused.append(entry)
		else:
			rejected.append(entry)

	rejected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("lateral_distance", INF)) < float(b.get("lateral_distance", INF))
	)
	for entry in rejected:
		if focused.size() >= DEBUG_AIM_CANDIDATE_NORMAL_MAX_ENTRIES:
			break
		focused.append(entry)
	return focused


func _make_aim_candidate_block(entry: Dictionary, actual_ball_id: int) -> Array:
	var tags: Array[String] = []
	if bool(entry.get("selected", false)):
		tags.append("SELECTED")
	if int(entry.get("ball_id", -1)) == actual_ball_id:
		tags.append("ACTUAL")
	if bool(entry.get("accepted", false)):
		tags.append("ACCEPTED")
	var real_hit: bool = bool(entry.get("would_hit_real_radius", false))
	var legacy_hit: bool = bool(entry.get("would_hit_legacy_graze_radius", false))
	if real_hit != legacy_hit:
		tags.append("RADIUS DISAGREEMENT")
	if tags.is_empty():
		tags.append("REJECTED")
	return [
		"B%s  %s" % [entry.get("ball_number", -1), " / ".join(tags)],
		"Along: %s px" % _debug_distance_text(float(entry.get("projected_distance", -1.0))),
		"Lateral: %s px" % _debug_distance_text(float(entry.get("lateral_distance", -1.0))),
		"Preview hit: %s" % _debug_optional_distance_text(float(entry.get("preview_hit_distance", -1.0))),
		"Physics hit: %s" % _debug_optional_distance_text(float(entry.get("real_hit_distance", -1.0))),
		"Legacy hit: %s" % _debug_optional_distance_text(float(entry.get("legacy_graze_hit_distance", -1.0))),
		"Result: %s" % str(entry.get("reason", "unknown")),
	]


func _make_aim_collision_lines(snapshot: Dictionary) -> Array:
	var compare: Dictionary = _get_aim_compare_snapshot(snapshot)
	var trace: Dictionary = compare.get("trace", {})
	var collision_log_value: Variant = trace.get("collision_log", [])
	if not collision_log_value is Array or (collision_log_value as Array).is_empty():
		return ["No collisions recorded."]

	var collision_log: Array = collision_log_value as Array
	var lines: Array = []
	for log_index in range(mini(collision_log.size(), DEBUG_AIM_PANEL_LOG_MAX_ENTRIES)):
		var parts: PackedStringArray = str(collision_log[log_index]).split(" | ", false)
		lines.append("%s. %s" % [log_index + 1, parts[0] if not parts.is_empty() else "Collision"])
		for part_index in range(1, parts.size()):
			lines.append(str(parts[part_index]).capitalize())
		if log_index + 1 < mini(collision_log.size(), DEBUG_AIM_PANEL_LOG_MAX_ENTRIES):
			lines.append("")
	return lines


func _debug_optional_distance_text(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%s px" % _debug_distance_text(value)


func _debug_optional_fraction_text(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%.4f" % value


func _debug_optional_time_text(value: float) -> String:
	if value < 0.0:
		return "--"
	return "%.3f ms" % value


func _debug_overlap_gap_text(gap: float) -> String:
	if gap < 0.0:
		return "overlap %.2f px" % -gap
	return "gap %.2f px" % gap


func _debug_ordinal_text(value: int) -> String:
	var remainder_100: int = value % 100
	if remainder_100 >= 11 and remainder_100 <= 13:
		return "%sth" % value
	match value % 10:
		1:
			return "%sst" % value
		2:
			return "%snd" % value
		3:
			return "%srd" % value
	return "%sth" % value


func _debug_aim_ball_label(ball_number: int, ball_id: int) -> String:
	if ball_id < 0 and ball_number < 0:
		return "--"
	return "B%s [%s]" % [ball_number, _debug_id_text(ball_id)]


func _get_aim_compare_snapshot(snapshot: Dictionary) -> Dictionary:
	var compare_value: Variant = snapshot.get("aim_compare", {})
	if compare_value is Dictionary:
		return compare_value
	return {}


func _make_physics_performance_lines(snapshot: Dictionary) -> Array:
	var lines := [
		"PHYSICS",
		"Substeps: %s" % snapshot["physics_substeps"],
		"Grid cells: %s / max cell: %s" % [
			snapshot["spatial_grid_cells"],
			snapshot["spatial_grid_max_cell_size"],
		],
		"Ball pairs: %s candidates / %s checked / %s collisions" % [
			snapshot["broadphase_candidate_pairs"],
			snapshot["ball_pair_checks"],
			snapshot["ball_collisions_resolved"],
		],
		"Rails: %s checks / %s hits" % [
			snapshot["rail_checks"],
			snapshot["rail_collisions_resolved"],
		],
		"Pockets: %s checks / %s captures" % [
			snapshot["pocket_checks"],
			snapshot["pocket_captures"],
		],
	]

	lines.append(
		"Debris: %s active / %s broad / %s detail / %s skipped / %s hits / %.2f ms" % [
			snapshot.get("active_debris_count", 0),
			snapshot.get("obstacle_broadphase_checks", 0),
			snapshot.get("obstacle_detailed_polygon_checks", 0),
			snapshot.get("obstacle_broadphase_skips", 0),
			snapshot.get("obstacle_collision_hits", 0),
			float(snapshot.get("obstacle_collision_ms", 0.0)),
		]
	)
	lines.append("Debris cache rebuilds: %s" % snapshot.get("obstacle_cache_rebuilds", 0))
	return lines


func _make_timing_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"TIMING",
		"Frame est: %.2f ms / physics gap %.2f ms" % [
			float(snapshot["estimated_frame_ms"]),
			float(snapshot["estimated_frame_physics_gap_ms"]),
		],
		"Physics: %.2f ms / ball %.2f / rail %.2f / pocket %.2f" % [
			float(snapshot["physics_process_ms"]),
			float(snapshot["ball_collision_ms"]),
			float(snapshot["rail_collision_ms"]),
			float(snapshot["pocket_check_ms"]),
		],
	]


func _elapsed_ms_since(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0


func _sort_ball_debug_snapshots_by_speed(ball_a: Dictionary, ball_b: Dictionary) -> bool:
	return float(ball_a["speed"]) > float(ball_b["speed"])


func _get_physics_debug_line(ball_data: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(_get_ball_debug_name(ball_data))
	parts.append("speed %.1f" % float(ball_data["speed"]))
	parts.append(_get_ball_drag_band_name(ball_data))
	if bool(ball_data["wayfinder_active"]):
		parts.append("active")
	if bool(ball_data["guided"]):
		parts.append("guided")
	if not bool(ball_data["gameplay_enabled"]):
		parts.append("paused")
	return " | ".join(parts)


func _get_ball_debug_name(ball_data: Dictionary) -> String:
	if bool(ball_data["is_cue_ball"]):
		return "Cue Ball"
	if bool(ball_data["is_eight_ball"]):
		return "8 Ball"
	if bool(ball_data["is_wayfinder"]):
		return "Wayfinder Ball"
	if bool(ball_data["is_powder_keg"]):
		return "Powder Keg"
	if bool(ball_data.get("is_anchor_curse_seed", false)):
		return "Anchor Curse Seed"
	if bool(ball_data["is_anchor_ball"]):
		return "Retired Anchor Ball"
	if bool(ball_data["is_cannon_ball"]):
		return "Cannon Ball"
	if bool(ball_data["is_treasure_ball"]):
		return "Treasure Ball"
	if bool(ball_data.get("is_embezzler_ball", false)):
		return "Embezzler Ball"
	return "Ball %s" % ball_data["ball_number"]


func _get_ball_drag_band_name(ball_data: Dictionary) -> String:
	var speed: float = float(ball_data["speed"])
	if speed >= float(ball_data["medium_speed_drag_start"]):
		return "high"
	if speed >= float(ball_data["low_speed_drag_start"]):
		return "medium"
	if speed >= float(ball_data["crawl_speed_drag_start"]):
		return "low"
	return "crawl"


func _debug_bool_text(enabled: bool) -> String:
	return "enabled" if enabled else "disabled"


func _debug_true_false_text(enabled: bool) -> String:
	return "true" if enabled else "false"


func _debug_distance_text(distance: float) -> String:
	if distance < 0.0:
		return "none"
	return "%.1f" % distance


func _debug_angle_text(angle: float) -> String:
	return "%.2f deg" % angle


func _debug_vector_text(value: Variant) -> String:
	if not (value is Vector2):
		return "none"
	var vector_value: Vector2 = value
	return "(%.1f, %.1f)" % [vector_value.x, vector_value.y]


func _debug_id_text(id_value: int) -> String:
	if id_value < 0:
		return "none"
	return str(id_value)
