extends Control
class_name DebugOverlay

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
const PANEL_AIM_COMPARE_GROUP := "aim_compare_panels"
const DEBUG_AIM_PANEL_LOG_MAX_ENTRIES := 12
const TABLE_EVENT_TEST_BUTTON_SIZE := Vector2(112.0, 36.0)
const TABLE_EVENT_TEST_BUTTON_RIGHT_OFFSET := 284.0
const TABLE_EVENT_TEST_BUTTON_TOP := 532.0
const TABLE_EVENT_TEST_BUTTON_GAP := 8.0

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
var aim_launch_panel: DebugPanel
var aim_launch_label: Label
var aim_contact_panel: DebugPanel
var aim_contact_label: Label
var aim_response_panel: DebugPanel
var aim_response_label: Label
var aim_trace_panel: DebugPanel
var aim_trace_label: Label


func setup(table_ref: BilliardsTable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	table = table_ref
	debug_menu_panel.visible = false
	physics_debug_panel.visible = false
	performance_overlay_panel.visible = false
	_ensure_aim_compare_panels()
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
	_ensure_table_event_debug_buttons()
	debug_hotkey_label.text = _make_debug_hotkey_text()
	_connect_debug_controls()


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

	aim_trace_panel = _make_runtime_debug_panel("AimTracePanel", Vector2(916.0, 690.0), Vector2(500.0, 276.0))
	aim_trace_label = _make_runtime_debug_label("AimTracePanelLabel", "AIM TRACE / LOG")
	_add_label_to_runtime_panel(aim_trace_panel, aim_trace_label)


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


func _unhandled_input(event: InputEvent) -> void:
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


func _process(_delta: float) -> void:
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

	last_debug_overlay_refresh_ms = _elapsed_ms_since(refresh_start_usec) if refreshed_debug_text else 0.0


func set_modular_debug_panel_visible(panel_id: String, enabled: bool) -> void:
	var panel: Control = _get_modular_debug_panel(panel_id)
	if panel == null:
		return

	panel.visible = enabled
	if enabled and table != null:
		var requested_sections: Dictionary = _get_modular_panel_performance_sections(panel_id)
		_refresh_modular_debug_panel(panel_id, _get_performance_snapshot_with_debug_overlay_metrics(requested_sections))


func set_aim_compare_panels_visible(enabled: bool) -> void:
	_set_aim_compare_panels_visible(enabled)
	if enabled and table != null:
		var requested_sections: Dictionary = _get_modular_panel_performance_sections(PANEL_AIM_LAUNCH)
		var snapshot: Dictionary = _get_performance_snapshot_with_debug_overlay_metrics(requested_sections)
		_refresh_modular_debug_panel(PANEL_AIM_LAUNCH, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_CONTACT, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_RESPONSE, snapshot)
		_refresh_modular_debug_panel(PANEL_AIM_TRACE, snapshot)


func _set_aim_compare_panels_visible(enabled: bool) -> void:
	if aim_launch_panel != null:
		aim_launch_panel.visible = enabled
	if aim_contact_panel != null:
		aim_contact_panel.visible = enabled
	if aim_response_panel != null:
		aim_response_panel.visible = enabled
	if aim_trace_panel != null:
		aim_trace_panel.visible = enabled


func _are_aim_compare_panels_visible() -> bool:
	return (
		(aim_launch_panel != null and aim_launch_panel.visible)
		or (aim_contact_panel != null and aim_contact_panel.visible)
		or (aim_response_panel != null and aim_response_panel.visible)
		or (aim_trace_panel != null and aim_trace_panel.visible)
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
		PANEL_AIM_COMPARE_GROUP: _are_aim_compare_panels_visible(),
	}


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
		PANEL_AIM_TRACE:
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


func _refresh_modular_debug_panel(panel_id: String, snapshot: Dictionary) -> void:
	var label: Label = _get_modular_debug_label(panel_id)
	if label == null:
		return

	match panel_id:
		PANEL_CORE_PERFORMANCE:
			label.text = _make_core_performance_panel_text(snapshot)
		PANEL_AIM_PREVIEW:
			label.text = "\n".join(_make_aim_preview_performance_lines(snapshot))
		PANEL_TREASURE:
			label.text = _make_titled_panel_text("TREASURE", _make_treasure_performance_lines(snapshot))
		PANEL_EMBEZZLER:
			label.text = _make_titled_panel_text("EMBEZZLER", _make_embezzler_performance_lines(snapshot))
		PANEL_ANCHOR:
			label.text = _make_titled_panel_text("ANCHOR", _make_anchor_performance_lines(snapshot))
		PANEL_BALL_DROPS_SCORE:
			label.text = _make_ball_drops_score_panel_text(snapshot)
		PANEL_CANNON:
			label.text = _make_titled_panel_text("CANNON", _make_cannon_performance_lines(snapshot))
		PANEL_POWDER_KEG_WAYFINDER:
			label.text = _make_powder_keg_wayfinder_panel_text(snapshot)
		PANEL_VISUAL_EFFECTS:
			label.text = "\n".join(_make_visual_cost_performance_lines(snapshot))
		PANEL_PHYSICS:
			label.text = "\n".join(_make_physics_performance_lines(snapshot))
		PANEL_AIM_LAUNCH:
			label.text = _make_titled_panel_text("AIM LAUNCH", _make_aim_launch_lines(snapshot))
		PANEL_AIM_CONTACT:
			label.text = _make_titled_panel_text("AIM CONTACT", _make_aim_contact_lines(snapshot))
		PANEL_AIM_RESPONSE:
			label.text = _make_titled_panel_text("AIM RESPONSE", _make_aim_response_lines(snapshot))
		PANEL_AIM_TRACE:
			label.text = _make_titled_panel_text("AIM TRACE / LOG", _make_aim_trace_lines(snapshot))


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
	return null


func _toggle_debug_menu() -> void:
	debug_menu_panel.visible = not debug_menu_panel.visible


func _toggle_performance_overlay() -> void:
	performance_overlay_check_box.button_pressed = not performance_overlay_check_box.button_pressed


func _ensure_table_event_debug_buttons() -> void:
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


func _update_table_event_test_button_layout() -> void:
	var visible_buttons: Array[Button] = []
	if wayfinder_current_test_button != null and wayfinder_current_test_button.visible:
		visible_buttons.append(wayfinder_current_test_button)
	if broadside_attack_test_button != null and broadside_attack_test_button.visible:
		visible_buttons.append(broadside_attack_test_button)

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


func _on_physics_debug_toggled(enabled: bool) -> void:
	physics_debug_panel.visible = enabled
	if enabled:
		physics_debug_label.text = _make_physics_debug_text()


func _on_performance_overlay_toggled(enabled: bool) -> void:
	performance_overlay_panel.visible = enabled
	if enabled:
		performance_overlay_label.text = _make_performance_debug_text()


func _on_anchor_visuals_toggled(enabled: bool) -> void:
	table.anchor_ball_system.set_anchor_visuals_enabled(enabled)


func _on_anchor_debug_visual_toggled(enabled: bool) -> void:
	table.anchor_ball_system.set_debug_visual_enabled(enabled)


func _on_anchor_single_latch_toggled(enabled: bool) -> void:
	table.anchor_ball_system.set_single_latch_per_target_enabled(enabled)


func _on_treasure_debug_visual_toggled(enabled: bool) -> void:
	table.treasure_ball_system.set_debug_visual_enabled(enabled)


func _sync_powder_keg_debug_toggles() -> void:
	powder_keg_particles_check_box.set_pressed_no_signal(table.powder_keg_system.explosion_particles_enabled)
	powder_keg_reduced_particles_check_box.set_pressed_no_signal(table.powder_keg_system.reduced_particles_debug_enabled)
	powder_keg_suppress_trails_check_box.set_pressed_no_signal(table.powder_keg_system.suppress_trails_after_explosion)


func _on_powder_keg_particles_toggled(enabled: bool) -> void:
	table.powder_keg_system.explosion_particles_enabled = enabled


func _on_powder_keg_reduced_particles_toggled(enabled: bool) -> void:
	table.powder_keg_system.reduced_particles_debug_enabled = enabled


func _on_powder_keg_suppress_trails_toggled(enabled: bool) -> void:
	table.powder_keg_system.suppress_trails_after_explosion = enabled


func _on_wayfinder_current_test_button_pressed() -> void:
	if table == null or table.table_event_system == null:
		return

	table.table_event_system.debug_trigger_wayfinder_current()


func _on_broadside_attack_test_button_pressed() -> void:
	if table == null or table.table_event_system == null:
		return

	table.table_event_system.debug_trigger_broadside_attack()


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
	return [
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
		"Center dist expected/actual: %s / %s" % [
			_debug_distance_text(float(response.get("expected_center_distance", -1.0))),
			_debug_distance_text(float(response.get("actual_center_distance", -1.0))),
		],
		"Overlap/gap: %.2f px" % float(response.get("overlap_gap", 0.0)),
		"Radii cue/target: %.1f / %.1f" % [
			float(response.get("cue_radius", 0.0)),
			float(response.get("target_radius", 0.0)),
		],
	]


func _make_aim_trace_lines(snapshot: Dictionary) -> Array:
	var compare: Dictionary = _get_aim_compare_snapshot(snapshot)
	var trace: Dictionary = compare.get("trace", {})
	var lines: Array = [
		"Actual balls tracked: %s" % trace.get("actual_balls_tracked", 0),
		"Trace points: %s total / %s cue" % [
			trace.get("total_trace_points", 0),
			trace.get("cue_trace_points", 0),
		],
		"First contact frame/time: %s / %s ms" % [
			trace.get("first_contact_physics_frame", -1),
			trace.get("first_contact_time_msec", -1),
		],
		"Verdict: %s" % compare.get("verdict", "none"),
	]
	var selected_ball_number: int = int(trace.get("first_hit_selected_ball_number", -1))
	if selected_ball_number >= 0:
		lines.append("Predicted first-hit sweep: #%s" % selected_ball_number)
	else:
		lines.append("Predicted first-hit sweep: none")
	var first_hit_candidates: Array = []
	var candidates_value: Variant = trace.get("first_hit_candidates", [])
	if candidates_value is Array:
		first_hit_candidates = candidates_value
	lines.append("Candidate log:")
	if first_hit_candidates.is_empty():
		lines.append("  none")
	else:
		for candidate_index in range(mini(first_hit_candidates.size(), DEBUG_AIM_PANEL_LOG_MAX_ENTRIES)):
			var candidate_value: Variant = first_hit_candidates[candidate_index]
			if not candidate_value is Dictionary:
				continue
			var candidate_entry: Dictionary = candidate_value
			lines.append(_make_aim_first_hit_candidate_line(candidate_index, candidate_entry))
	lines.append("Collision log:")
	var collision_log: Array = trace.get("collision_log", [])
	if collision_log.is_empty():
		lines.append("  none")
		return lines
	for log_index in range(mini(collision_log.size(), DEBUG_AIM_PANEL_LOG_MAX_ENTRIES)):
		lines.append("%s. %s" % [log_index + 1, collision_log[log_index]])
	return lines


func _make_aim_first_hit_candidate_line(candidate_index: int, entry: Dictionary) -> String:
	var ball_number: int = int(entry.get("ball_number", -1))
	var selected_prefix: String = "*" if bool(entry.get("selected", false)) else " "
	var accepted_text: String = "yes" if bool(entry.get("accepted", false)) else "no"
	var real_text: String = "yes" if bool(entry.get("would_hit_real_radius", false)) else "no"
	var legacy_text: String = "yes" if bool(entry.get("would_hit_legacy_graze_radius", false)) else "no"
	return "%s%s. #%s proj %s lat %s prev %s real %s old %s acc %s %s [%s]" % [
		selected_prefix,
		candidate_index + 1,
		ball_number,
		_debug_distance_text(float(entry.get("projected_distance", -1.0))),
		_debug_distance_text(float(entry.get("lateral_distance", -1.0))),
		_debug_distance_text(float(entry.get("preview_hit_distance", -1.0))),
		_debug_distance_text(float(entry.get("real_hit_distance", -1.0))),
		_debug_distance_text(float(entry.get("legacy_graze_hit_distance", -1.0))),
		accepted_text,
		entry.get("reason", "unknown"),
		"real:%s old:%s" % [real_text, legacy_text],
	]


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
