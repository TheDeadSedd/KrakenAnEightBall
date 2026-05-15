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


func setup(table_ref: BilliardsTable) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	table = table_ref
	debug_menu_panel.visible = false
	physics_debug_panel.visible = false
	performance_overlay_panel.visible = false
	_set_all_modular_debug_panels_visible(false)
	shot_path_check_box.set_pressed_no_signal(table.is_shot_path_debug_enabled())
	physics_debug_check_box.set_pressed_no_signal(false)
	performance_overlay_check_box.set_pressed_no_signal(false)
	anchor_visuals_check_box.set_pressed_no_signal(table.anchor_ball_system.are_anchor_visuals_enabled())
	anchor_debug_visual_check_box.set_pressed_no_signal(table.anchor_ball_system.is_debug_visual_enabled())
	anchor_single_latch_check_box.set_pressed_no_signal(table.anchor_ball_system.is_single_latch_per_target_enabled())
	treasure_debug_visual_check_box.set_pressed_no_signal(table.treasure_ball_system.is_debug_visual_enabled())
	_sync_powder_keg_debug_toggles()
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

	if physics_debug_panel.visible:
		physics_debug_label.text = _make_physics_debug_text()

	var full_performance_visible := performance_overlay_panel.visible
	var modular_performance_visible := _has_visible_modular_debug_panels()
	if full_performance_visible:
		var snapshot: Dictionary = table.get_performance_debug_snapshot()
		performance_overlay_label.text = _make_performance_debug_text_from_snapshot(snapshot)
		if modular_performance_visible:
			_refresh_visible_modular_debug_panels(snapshot)
	elif modular_performance_visible:
		var requested_sections: Dictionary = _get_visible_modular_performance_sections()
		if not requested_sections.is_empty():
			var snapshot: Dictionary = table.get_performance_debug_snapshot(requested_sections)
			_refresh_visible_modular_debug_panels(snapshot)


func set_modular_debug_panel_visible(panel_id: String, enabled: bool) -> void:
	var panel: Control = _get_modular_debug_panel(panel_id)
	if panel == null:
		return

	panel.visible = enabled
	if enabled and table != null:
		var requested_sections: Dictionary = _get_modular_panel_performance_sections(panel_id)
		_refresh_modular_debug_panel(panel_id, table.get_performance_debug_snapshot(requested_sections))


func get_modular_debug_panel_states() -> Dictionary:
	return {
		PANEL_CORE_PERFORMANCE: core_performance_panel.visible,
		PANEL_AIM_PREVIEW: aim_preview_panel.visible,
		PANEL_TREASURE: treasure_panel.visible,
		PANEL_ANCHOR: anchor_panel.visible,
		PANEL_BALL_DROPS_SCORE: ball_drops_score_panel.visible,
		PANEL_CANNON: cannon_panel.visible,
		PANEL_POWDER_KEG_WAYFINDER: powder_keg_wayfinder_panel.visible,
		PANEL_VISUAL_EFFECTS: visual_effects_panel.visible,
		PANEL_PHYSICS: physics_performance_panel.visible,
	}


func _set_all_modular_debug_panels_visible(visible_value: bool) -> void:
	core_performance_panel.visible = visible_value
	aim_preview_panel.visible = visible_value
	treasure_panel.visible = visible_value
	anchor_panel.visible = visible_value
	ball_drops_score_panel.visible = visible_value
	cannon_panel.visible = visible_value
	powder_keg_wayfinder_panel.visible = visible_value
	visual_effects_panel.visible = visible_value
	physics_performance_panel.visible = visible_value


func _has_visible_modular_debug_panels() -> bool:
	return (
		core_performance_panel.visible
		or aim_preview_panel.visible
		or treasure_panel.visible
		or anchor_panel.visible
		or ball_drops_score_panel.visible
		or cannon_panel.visible
		or powder_keg_wayfinder_panel.visible
		or visual_effects_panel.visible
		or physics_performance_panel.visible
	)


func _get_visible_modular_performance_sections() -> Dictionary:
	var requested_sections: Dictionary = {}
	if core_performance_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_CORE_PERFORMANCE))
	if aim_preview_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_AIM_PREVIEW))
	if treasure_panel.visible:
		requested_sections.merge(_get_modular_panel_performance_sections(PANEL_TREASURE))
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
	return requested_sections


func _get_modular_panel_performance_sections(panel_id: String) -> Dictionary:
	var requested_sections: Dictionary = {}
	match panel_id:
		PANEL_CORE_PERFORMANCE:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_CORE)
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_TIMING)
		PANEL_AIM_PREVIEW:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_AIM_PREVIEW)
		PANEL_TREASURE:
			_request_performance_section(requested_sections, BilliardsTable.PERFORMANCE_SECTION_TREASURE)
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


func _get_modular_debug_panel(panel_id: String) -> Control:
	match panel_id:
		PANEL_CORE_PERFORMANCE:
			return core_performance_panel
		PANEL_AIM_PREVIEW:
			return aim_preview_panel
		PANEL_TREASURE:
			return treasure_panel
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
	return null


func _get_modular_debug_label(panel_id: String) -> Label:
	match panel_id:
		PANEL_CORE_PERFORMANCE:
			return core_performance_label
		PANEL_AIM_PREVIEW:
			return aim_preview_label
		PANEL_TREASURE:
			return treasure_label
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
	return null


func _toggle_debug_menu() -> void:
	debug_menu_panel.visible = not debug_menu_panel.visible


func _toggle_performance_overlay() -> void:
	performance_overlay_check_box.button_pressed = not performance_overlay_check_box.button_pressed


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


func _make_debug_hotkey_text() -> String:
	var hotkeys: Dictionary = table.get_debug_spawn_hotkey_data()
	return "%s: Spawn Wayfinder Ball\n%s: Spawn Powder Keg\n%s: Spawn Anchor Ball\n%s: Spawn Cannon Ball\n%s: Spawn Treasure Ball\n%s: Spawn Normal Ball\n%s: Performance Overlay" % [
		OS.get_keycode_string(int(hotkeys["wayfinder_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["powder_keg_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["anchor_ball_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["cannon_ball_spawn_key"])),
		OS.get_keycode_string(int(hotkeys["treasure_ball_spawn_key"])),
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
	var snapshot: Dictionary = table.get_performance_debug_snapshot()
	return _make_performance_debug_text_from_snapshot(snapshot)


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
	lines.append("Score popups: %s active labels" % snapshot["active_score_popup_labels"])
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
	return [
		"BALL DROPS",
		"Ball drop progress: %s/%s Doubloons" % [
			snapshot["ball_drop_progress"],
			snapshot["ball_drop_threshold"],
		],
		"Ball drops queued: %s earned / %s pending / %s from last score" % [
			snapshot["ball_drop_total_queued"],
			snapshot["ball_drop_pending_spawns"],
			snapshot["ball_drop_last_score_queued"],
		],
		"BallDropSystem enabled: %s" % _debug_bool_text(bool(snapshot["ball_drop_enabled"])),
	]


func _make_anomaly_performance_lines(snapshot: Dictionary) -> Array:
	var lines: Array = [
		"ANOMALIES",
	]
	lines.append_array(_make_wayfinder_performance_lines(snapshot))
	lines.append_array(_make_anchor_performance_lines(snapshot))
	lines.append_array(_make_cannon_performance_lines(snapshot))
	lines.append_array(_make_treasure_performance_lines(snapshot))
	return lines


func _make_wayfinder_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"Wayfinder: %s active / %s guided" % [
			snapshot["active_wayfinders"],
			snapshot["guided_wayfinder_targets"],
		],
	]


func _make_anchor_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"Anchor: %s active / %s affected / %s force apps" % [
			snapshot["anchor_balls"],
			snapshot["anchor_affected_balls"],
			snapshot["anchor_force_applications"],
		],
		"Anchor force: avg %.2f / max %.2f / nearest %s" % [
			float(snapshot["anchor_avg_force"]),
			float(snapshot["anchor_max_force"]),
			_debug_distance_text(float(snapshot["anchor_nearest_distance"])),
		],
		"Anchor overlap: one current %s / skipped %s / max considered %s / overlap targets %s" % [
			_debug_bool_text(bool(snapshot["anchor_single_latch_enabled"])),
			snapshot["anchor_single_latch_skipped"],
			snapshot["anchor_max_anchors_affecting_same_ball"],
			snapshot["anchor_targets_affected_by_multiple_anchors"],
		],
		"Anchor tuning: %s / radius %.1f / strength %.1f" % [
			_debug_bool_text(bool(snapshot["anchor_enabled"])),
			float(snapshot["anchor_radius"]),
			float(snapshot["anchor_strength"]),
		],
		"Anchor visuals: %s / nodes %s / fields %s/%s / markers %s" % [
			_debug_bool_text(bool(snapshot["anchor_visuals_enabled"])),
			snapshot["anchor_visual_nodes_active"],
			snapshot["anchor_field_rings_drawn"],
			snapshot["anchor_max_visible_field_auras"],
			snapshot["anchor_affected_markers_active"],
		],
		"Anchor debug cap: %s / %s" % [
			_debug_bool_text(bool(snapshot["anchor_spawn_cap_enabled"])),
			snapshot["anchor_spawn_cap"],
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


func _make_visual_cost_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"VISUAL COST",
		"Trails: %s points / %s balls / %s redraws" % [
			snapshot["trail_points"],
			snapshot["balls_with_trails"],
			snapshot["trail_redraws"],
		],
		"Particles/popups: %s Powder Keg bursts / %s score labels" % [
			snapshot["active_powder_keg_particle_bursts"],
			snapshot["active_score_popup_labels"],
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


func _make_physics_performance_lines(snapshot: Dictionary) -> Array:
	return [
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


func _make_timing_performance_lines(snapshot: Dictionary) -> Array:
	return [
		"TIMING",
		"Frame: %.2f ms / ball %.2f / rail %.2f / pocket %.2f" % [
			float(snapshot["physics_process_ms"]),
			float(snapshot["ball_collision_ms"]),
			float(snapshot["rail_collision_ms"]),
			float(snapshot["pocket_check_ms"]),
		],
	]


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
	if bool(ball_data["is_anchor_ball"]):
		return "Anchor Ball"
	if bool(ball_data["is_cannon_ball"]):
		return "Cannon Ball"
	if bool(ball_data["is_treasure_ball"]):
		return "Treasure Ball"
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


func _debug_vector_text(value: Variant) -> String:
	if not (value is Vector2):
		return "none"
	var vector_value: Vector2 = value
	return "(%.1f, %.1f)" % [vector_value.x, vector_value.y]


func _debug_id_text(id_value: int) -> String:
	if id_value < 0:
		return "none"
	return str(id_value)
