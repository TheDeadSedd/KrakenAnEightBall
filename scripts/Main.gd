extends Node2D

const FULLSCREEN_TOGGLE_KEY := KEY_F11
const PAUSE_TOGGLE_KEY := KEY_ESCAPE
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const GAMEPLAY_SCENE_PATH := "res://scenes/Main.tscn"
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")
const COMPLETION_PANEL_SIZE := Vector2(620.0, 710.0)
const BACK_ROOM_PANEL_VIEWPORT_MARGIN := 24.0

@onready var table: BilliardsTable = $Table
@onready var run_history_system: RunHistorySystem = $RunHistorySystem
@onready var progression_system: ProgressionSystem = $ProgressionSystem
@onready var cue_progression_system: CueProgressionSystem = $CueProgressionSystem
@onready var debug_overlay: DebugOverlay = $CanvasLayer/HUD
@onready var pause_menu: PauseMenu = $CanvasLayer/HUD/PauseMenu
@onready var hud_feed: HudFeed = $CanvasLayer/HUD/HudFeed
@onready var result_label: Label = $CanvasLayer/HUD/ResultLabel
@onready var doubloons_label: Label = $CanvasLayer/HUD/DoubloonsLabel
@onready var run_ledger_hud: RunLedgerHUD = $CanvasLayer/HUD/RunLedgerHUD
@onready var run_stats_hud: RunStatsHUD = $CanvasLayer/HUD/RunStatsHUD
@onready var cue_start_selector_hud: CueStartSelectorHUD = $CanvasLayer/HUD/CueStartSelectorHUD
@onready var passage_hud: PassageHUD = $CanvasLayer/HUD/PassageHUD
@onready var oath_hud: OathHUD = $CanvasLayer/HUD/OathHUD
@onready var kraken_boon_hud: KrakenBoonHUD = $CanvasLayer/HUD/KrakenBoonHUD
@onready var table_event_meter: TableEventMeter = $CanvasLayer/HUD/TableEventMeter
@onready var table_event_menu: TableEventMenu = $CanvasLayer/HUD/TableEventMenu
@onready var reserve_slots_ui: ReserveSlotsUI = $CanvasLayer/HUD/ReserveSlotsUI
@onready var quartermaster_hud: QuartermasterHUD = $CanvasLayer/HUD/QuartermasterHUD
@onready var reserve_deployment_presenter: ReserveDeploymentPresenter = $CanvasLayer/HUD/ReserveDeploymentPresenter

var reserve_deployment_active := false
var reserve_deployment_previous_pause_state := false
var end_run_in_progress := false
var passage_completion_in_progress := false
var passage_completion_blocker: ColorRect
var passage_completion_panel: PanelContainer
var passage_completion_value_labels: Dictionary = {}
var passage_completion_confirm_button: Button
var passage_completion_progression_award: Dictionary = {}
var latest_cue_progression_snapshot: Dictionary = {}
var latest_back_room_deal_snapshot: Dictionary = {}
var latest_sunken_spoils_snapshot: Dictionary = {}
var back_room_panel: BackRoomDealPanel
var sunken_spoils_panel: SunkenSpoilsPanel
var sunken_spoils_hud: SunkenSpoilsHUD
var roguelite_hud: RogueliteHUD
var roguelite_round_panel: RogueliteRoundPanel
var roguelite_reward_panel: RogueliteRewardPanel
var game_mode_id: String = GAME_MODE_SCRIPT.MODE_PASSAGE
var pending_debug_session_snapshot: Dictionary = {}
var reset_table_in_progress := false


func _enter_tree() -> void:
	game_mode_id = GAME_MODE_SCRIPT.consume_pending_mode(get_tree())
	pending_debug_session_snapshot = GAME_MODE_SCRIPT.consume_pending_debug_session(get_tree())

	var table_node: BilliardsTable = get_node_or_null("Table") as BilliardsTable
	if table_node != null:
		table_node.set_game_mode_id(game_mode_id)


func get_game_mode_id() -> String:
	return game_mode_id


func _ready() -> void:
	_configure_pause_process_modes()
	debug_overlay.visible = true
	_setup_cue_progression_runtime_bridge()
	_connect_table_signals()
	_connect_pause_menu_signals()
	_connect_hud_signals()
	_setup_hud_presenters()
	_sync_initial_hud_state()
	_restore_pending_debug_session()


func _connect_table_signals() -> void:
	table.status_text_changed.connect(_on_status_text_changed)
	table.game_finished.connect(_on_game_finished)
	if not table.gameplay_mouse_lock_changed.is_connected(_on_gameplay_mouse_lock_changed):
		table.gameplay_mouse_lock_changed.connect(_on_gameplay_mouse_lock_changed)
	if not table.cue_start_selection_changed.is_connected(_on_cue_start_selection_changed):
		table.cue_start_selection_changed.connect(_on_cue_start_selection_changed)
	if not table.roguelite_round_cleared.is_connected(_on_roguelite_round_cleared):
		table.roguelite_round_cleared.connect(_on_roguelite_round_cleared)
	if not table.roguelite_run_failed.is_connected(_on_roguelite_run_failed):
		table.roguelite_run_failed.connect(_on_roguelite_run_failed)
	if not table.roguelite_run_completed.is_connected(_on_roguelite_run_completed):
		table.roguelite_run_completed.connect(_on_roguelite_run_completed)
	if not table.shot_rewind_system.state_changed.is_connected(_on_shot_rewind_state_changed):
		table.shot_rewind_system.state_changed.connect(_on_shot_rewind_state_changed)
	table.score_system.doubloons_changed.connect(_on_doubloons_changed)
	table.score_system.score_feed_message.connect(_on_score_feed_message)
	table.table_event_system.status_changed.connect(_on_table_event_status_changed)
	table.table_event_system.event_purchased.connect(_on_table_event_purchased)
	table.sunken_spoils_system.spoils_changed.connect(_on_sunken_spoils_changed)
	table.sunken_spoils_system.status_changed.connect(_on_sunken_spoils_status_changed)
	table.run_stats_system.run_stats_changed.connect(_on_run_stats_changed)
	table.passage_system.request_completed.connect(_on_passage_request_completed)
	table.passage_system.request_rerolled.connect(_on_passage_request_rerolled)
	table.passage_system.passage_completed.connect(_on_passage_completed)
	table.oath_system.status_changed.connect(_on_oath_status_changed)
	table.quartermaster_system.shop_state_changed.connect(_on_quartermaster_shop_state_changed)
	table.quartermaster_system.status_changed.connect(_on_quartermaster_status_changed)
	table.quartermaster_system.placement_started.connect(_on_quartermaster_placement_started)
	table.quartermaster_system.placement_finished.connect(_on_quartermaster_placement_finished)
	table.back_room_deal_system.state_changed.connect(_on_back_room_deal_state_changed)
	table.back_room_deal_system.status_changed.connect(_on_back_room_deal_status_changed)
	table.reserve_system.reserve_slots_changed.connect(_on_reserve_slots_changed)
	table.reserve_system.deployment_finished.connect(_on_reserve_deployment_finished)
	table.reserve_system.deployment_blocked.connect(_on_reserve_deployment_blocked)


func _connect_pause_menu_signals() -> void:
	if not pause_menu.resume_requested.is_connected(_on_pause_resume_requested):
		pause_menu.resume_requested.connect(_on_pause_resume_requested)
	if not pause_menu.end_run_requested.is_connected(_on_pause_end_run_requested):
		pause_menu.end_run_requested.connect(_on_pause_end_run_requested)
	if not pause_menu.debug_panel_toggled.is_connected(_on_pause_debug_panel_toggled):
		pause_menu.debug_panel_toggled.connect(_on_pause_debug_panel_toggled)
	if not pause_menu.debug_wayfinder_current_test_button_toggled.is_connected(_on_pause_wayfinder_current_test_button_toggled):
		pause_menu.debug_wayfinder_current_test_button_toggled.connect(_on_pause_wayfinder_current_test_button_toggled)
	if not pause_menu.debug_broadside_attack_test_button_toggled.is_connected(_on_pause_broadside_attack_test_button_toggled):
		pause_menu.debug_broadside_attack_test_button_toggled.connect(_on_pause_broadside_attack_test_button_toggled)
	if not pause_menu.debug_force_loose_cargo_contraband_toggled.is_connected(_on_pause_force_loose_cargo_contraband_toggled):
		pause_menu.debug_force_loose_cargo_contraband_toggled.connect(_on_pause_force_loose_cargo_contraband_toggled)
	if not pause_menu.debug_loose_cargo_contraband_kind_selected.is_connected(_on_pause_loose_cargo_contraband_kind_selected):
		pause_menu.debug_loose_cargo_contraband_kind_selected.connect(_on_pause_loose_cargo_contraband_kind_selected)
	if not pause_menu.debug_spawn_wood_debris_requested.is_connected(_on_pause_spawn_wood_debris_requested):
		pause_menu.debug_spawn_wood_debris_requested.connect(_on_pause_spawn_wood_debris_requested)
	if not pause_menu.debug_clear_debris_requested.is_connected(_on_pause_clear_debris_requested):
		pause_menu.debug_clear_debris_requested.connect(_on_pause_clear_debris_requested)
	if not pause_menu.debug_obstacle_collision_toggled.is_connected(_on_pause_obstacle_collision_toggled):
		pause_menu.debug_obstacle_collision_toggled.connect(_on_pause_obstacle_collision_toggled)
	if not pause_menu.debug_obstacle_collision_draw_toggled.is_connected(_on_pause_obstacle_collision_draw_toggled):
		pause_menu.debug_obstacle_collision_draw_toggled.connect(_on_pause_obstacle_collision_draw_toggled)
	if not pause_menu.debug_pocket_capture_presentation_toggled.is_connected(_on_pause_pocket_capture_presentation_toggled):
		pause_menu.debug_pocket_capture_presentation_toggled.connect(_on_pause_pocket_capture_presentation_toggled)
	if not pause_menu.debug_clear_pocket_collections_requested.is_connected(_on_pause_clear_pocket_collections_requested):
		pause_menu.debug_clear_pocket_collections_requested.connect(_on_pause_clear_pocket_collections_requested)
	if not pause_menu.debug_pocket_collection_anchors_toggled.is_connected(_on_pause_pocket_collection_anchors_toggled):
		pause_menu.debug_pocket_collection_anchors_toggled.connect(_on_pause_pocket_collection_anchors_toggled)
	if not pause_menu.debug_reflow_pocket_collections_requested.is_connected(_on_pause_reflow_pocket_collections_requested):
		pause_menu.debug_reflow_pocket_collections_requested.connect(_on_pause_reflow_pocket_collections_requested)
	if not pause_menu.debug_oath_activate_requested.is_connected(_on_pause_debug_oath_activate_requested):
		pause_menu.debug_oath_activate_requested.connect(_on_pause_debug_oath_activate_requested)
	if not pause_menu.debug_oath_clear_requested.is_connected(_on_pause_debug_oath_clear_requested):
		pause_menu.debug_oath_clear_requested.connect(_on_pause_debug_oath_clear_requested)
	if not pause_menu.debug_oath_advance_shot_requested.is_connected(_on_pause_debug_oath_advance_shot_requested):
		pause_menu.debug_oath_advance_shot_requested.connect(_on_pause_debug_oath_advance_shot_requested)
	if not pause_menu.debug_oath_fail_requested.is_connected(_on_pause_debug_oath_fail_requested):
		pause_menu.debug_oath_fail_requested.connect(_on_pause_debug_oath_fail_requested)
	if not pause_menu.debug_oath_complete_requested.is_connected(_on_pause_debug_oath_complete_requested):
		pause_menu.debug_oath_complete_requested.connect(_on_pause_debug_oath_complete_requested)
	if not pause_menu.debug_back_room_force_available_toggled.is_connected(_on_pause_back_room_force_available_toggled):
		pause_menu.debug_back_room_force_available_toggled.connect(_on_pause_back_room_force_available_toggled)
	if not pause_menu.debug_back_room_open_requested.is_connected(_on_pause_back_room_open_requested):
		pause_menu.debug_back_room_open_requested.connect(_on_pause_back_room_open_requested)
	if not pause_menu.debug_activate_long_sight_requested.is_connected(_on_pause_debug_activate_long_sight_requested):
		pause_menu.debug_activate_long_sight_requested.connect(_on_pause_debug_activate_long_sight_requested)
	if not pause_menu.debug_activate_krakens_patience_requested.is_connected(_on_pause_debug_activate_krakens_patience_requested):
		pause_menu.debug_activate_krakens_patience_requested.connect(_on_pause_debug_activate_krakens_patience_requested)
	if not pause_menu.debug_activate_deep_ledger_requested.is_connected(_on_pause_debug_activate_deep_ledger_requested):
		pause_menu.debug_activate_deep_ledger_requested.connect(_on_pause_debug_activate_deep_ledger_requested)
	if not pause_menu.debug_activate_iron_wake_requested.is_connected(_on_pause_debug_activate_iron_wake_requested):
		pause_menu.debug_activate_iron_wake_requested.connect(_on_pause_debug_activate_iron_wake_requested)
	if not pause_menu.debug_expire_all_boons_requested.is_connected(_on_pause_debug_expire_all_boons_requested):
		pause_menu.debug_expire_all_boons_requested.connect(_on_pause_debug_expire_all_boons_requested)
	if not pause_menu.debug_reserve_stack_payload_requested.is_connected(_on_pause_debug_reserve_stack_payload_requested):
		pause_menu.debug_reserve_stack_payload_requested.connect(_on_pause_debug_reserve_stack_payload_requested)
	if not pause_menu.debug_sunken_spoils_advance_requested.is_connected(_on_pause_debug_sunken_spoils_advance_requested):
		pause_menu.debug_sunken_spoils_advance_requested.connect(_on_pause_debug_sunken_spoils_advance_requested)
	if not pause_menu.debug_sunken_spoils_trigger_requested.is_connected(_on_pause_debug_sunken_spoils_trigger_requested):
		pause_menu.debug_sunken_spoils_trigger_requested.connect(_on_pause_debug_sunken_spoils_trigger_requested)
	if not pause_menu.debug_sunken_spoils_reset_requested.is_connected(_on_pause_debug_sunken_spoils_reset_requested):
		pause_menu.debug_sunken_spoils_reset_requested.connect(_on_pause_debug_sunken_spoils_reset_requested)
	if not pause_menu.debug_aim_line_toggled.is_connected(_on_pause_debug_aim_line_toggled):
		pause_menu.debug_aim_line_toggled.connect(_on_pause_debug_aim_line_toggled)
	if not pause_menu.debug_aim_compare_panels_toggled.is_connected(_on_pause_debug_aim_compare_panels_toggled):
		pause_menu.debug_aim_compare_panels_toggled.connect(_on_pause_debug_aim_compare_panels_toggled)
	if not pause_menu.debug_verbose_aim_candidates_toggled.is_connected(_on_pause_debug_verbose_aim_candidates_toggled):
		pause_menu.debug_verbose_aim_candidates_toggled.connect(_on_pause_debug_verbose_aim_candidates_toggled)
	if not pause_menu.debug_cue_first_contact_toi_toggled.is_connected(_on_pause_debug_cue_first_contact_toi_toggled):
		pause_menu.debug_cue_first_contact_toi_toggled.connect(_on_pause_debug_cue_first_contact_toi_toggled)
	if not pause_menu.debug_cloned_aim_configuration_changed.is_connected(_on_pause_debug_cloned_aim_configuration_changed):
		pause_menu.debug_cloned_aim_configuration_changed.connect(_on_pause_debug_cloned_aim_configuration_changed)
	if not pause_menu.debug_force_deep_prediction_requested.is_connected(_on_pause_debug_force_deep_prediction_requested):
		pause_menu.debug_force_deep_prediction_requested.connect(_on_pause_debug_force_deep_prediction_requested)
	if not pause_menu.debug_cancel_pending_deep_prediction_requested.is_connected(_on_pause_debug_cancel_pending_deep_prediction_requested):
		pause_menu.debug_cancel_pending_deep_prediction_requested.connect(_on_pause_debug_cancel_pending_deep_prediction_requested)
	if not pause_menu.debug_reset_aim_profiler_requested.is_connected(_on_pause_debug_reset_aim_profiler_requested):
		pause_menu.debug_reset_aim_profiler_requested.connect(_on_pause_debug_reset_aim_profiler_requested)
	if not pause_menu.debug_reset_aim_benchmark_requested.is_connected(_on_pause_debug_reset_aim_benchmark_requested):
		pause_menu.debug_reset_aim_benchmark_requested.connect(_on_pause_debug_reset_aim_benchmark_requested)
	if not pause_menu.debug_start_aim_benchmark_requested.is_connected(_on_pause_debug_start_aim_benchmark_requested):
		pause_menu.debug_start_aim_benchmark_requested.connect(_on_pause_debug_start_aim_benchmark_requested)
	if not pause_menu.debug_stop_aim_benchmark_requested.is_connected(_on_pause_debug_stop_aim_benchmark_requested):
		pause_menu.debug_stop_aim_benchmark_requested.connect(_on_pause_debug_stop_aim_benchmark_requested)
	if not pause_menu.debug_copy_aim_benchmark_report_requested.is_connected(_on_pause_debug_copy_aim_benchmark_report_requested):
		pause_menu.debug_copy_aim_benchmark_report_requested.connect(_on_pause_debug_copy_aim_benchmark_report_requested)
	if not pause_menu.debug_reset_table_button_toggled.is_connected(_on_pause_debug_reset_table_button_toggled):
		pause_menu.debug_reset_table_button_toggled.connect(_on_pause_debug_reset_table_button_toggled)
	if not pause_menu.debug_reset_last_shot_button_toggled.is_connected(_on_pause_debug_reset_last_shot_button_toggled):
		pause_menu.debug_reset_last_shot_button_toggled.connect(_on_pause_debug_reset_last_shot_button_toggled)
	if not pause_menu.quartermaster_cancel_placement_requested.is_connected(_on_pause_quartermaster_cancel_placement_requested):
		pause_menu.quartermaster_cancel_placement_requested.connect(_on_pause_quartermaster_cancel_placement_requested)


func _connect_hud_signals() -> void:
	if not reserve_slots_ui.reserve_slot_clicked.is_connected(_on_reserve_slot_clicked):
		reserve_slots_ui.reserve_slot_clicked.connect(_on_reserve_slot_clicked)
	if not quartermaster_hud.quartermaster_offer_requested.is_connected(_on_quartermaster_hud_offer_requested):
		quartermaster_hud.quartermaster_offer_requested.connect(_on_quartermaster_hud_offer_requested)
	if not quartermaster_hud.quartermaster_refresh_requested.is_connected(_on_quartermaster_hud_refresh_requested):
		quartermaster_hud.quartermaster_refresh_requested.connect(_on_quartermaster_hud_refresh_requested)
	if not quartermaster_hud.back_room_deal_open_requested.is_connected(_on_quartermaster_hud_back_room_deal_open_requested):
		quartermaster_hud.back_room_deal_open_requested.connect(_on_quartermaster_hud_back_room_deal_open_requested)
	if not passage_hud.request_reroll_requested.is_connected(_on_passage_hud_request_reroll_requested):
		passage_hud.request_reroll_requested.connect(_on_passage_hud_request_reroll_requested)
	if not table_event_meter.event_icon_clicked.is_connected(_on_table_event_icon_clicked):
		table_event_meter.event_icon_clicked.connect(_on_table_event_icon_clicked)
	if not table_event_menu.event_offer_selected.is_connected(_on_table_event_offer_selected):
		table_event_menu.event_offer_selected.connect(_on_table_event_offer_selected)
	if not table_event_menu.boon_offer_selected.is_connected(_on_table_event_boon_offer_selected):
		table_event_menu.boon_offer_selected.connect(_on_table_event_boon_offer_selected)
	if not table_event_menu.event_offer_replace_requested.is_connected(_on_table_event_offer_replace_requested):
		table_event_menu.event_offer_replace_requested.connect(_on_table_event_offer_replace_requested)
	if not debug_overlay.reset_table_requested.is_connected(_on_debug_reset_table_requested):
		debug_overlay.reset_table_requested.connect(_on_debug_reset_table_requested)
	if not debug_overlay.reset_last_shot_requested.is_connected(_on_debug_reset_last_shot_requested):
		debug_overlay.reset_last_shot_requested.connect(_on_debug_reset_last_shot_requested)
	if not debug_overlay.debug_notification_requested.is_connected(_on_debug_notification_requested):
		debug_overlay.debug_notification_requested.connect(_on_debug_notification_requested)


func _setup_hud_presenters() -> void:
	result_label.text = ""
	_on_doubloons_changed(table.score_system.get_doubloons_total())
	table_event_meter.setup(table.table_event_system, table)
	table_event_menu.setup(table.table_event_system)
	run_ledger_hud.setup(table)
	run_stats_hud.setup(table.run_stats_system)
	cue_start_selector_hud.setup(table)
	passage_hud.setup(table.passage_system)
	oath_hud.setup(table.oath_system)
	kraken_boon_hud.setup(table.kraken_boon_system)
	_build_sunken_spoils_ui()
	_build_roguelite_hud()
	_build_roguelite_round_panel()
	_build_roguelite_reward_panel()
	_on_run_stats_changed(table.run_stats_system.get_run_stats_snapshot())
	reserve_slots_ui.setup(table.reserve_system, table)
	quartermaster_hud.setup(table.quartermaster_system, table)
	_build_back_room_deal_panel()
	reserve_deployment_presenter.setup(table.reserve_system, reserve_slots_ui)
	table.emit_ready_status_if_needed("")
	debug_overlay.setup(table)
	pause_menu.configure_dev_options_debug_overlay(debug_overlay)
	pause_menu.configure_dev_options_ball_audio(table.ball_audio_system)
	table.shot_rewind_system.set_ui_bridge(self)
	debug_overlay.set_shot_rewind_state(table.shot_rewind_system.get_state_snapshot())
	_apply_mode_visibility()


func _build_back_room_deal_panel() -> void:
	if back_room_panel != null:
		return

	back_room_panel = BackRoomDealPanel.new()
	back_room_panel.name = "BackRoomDealPanel"
	back_room_panel.z_index = 58
	debug_overlay.add_child(back_room_panel)
	back_room_panel.close_requested.connect(_close_back_room_deal_panel)
	back_room_panel.deal_option_selected.connect(_on_back_room_panel_option_selected)
	back_room_panel.set_hover_ui_suppressed(table.should_suppress_hover_ui())
	if not latest_back_room_deal_snapshot.is_empty():
		back_room_panel.set_deal_snapshot(latest_back_room_deal_snapshot)
	_position_back_room_deal_panel()


func _set_back_room_deal_snapshot(snapshot: Dictionary) -> void:
	latest_back_room_deal_snapshot = snapshot.duplicate(true)
	if quartermaster_hud != null:
		quartermaster_hud.set_back_room_deal_snapshot(latest_back_room_deal_snapshot)
	if back_room_panel != null:
		back_room_panel.set_deal_snapshot(latest_back_room_deal_snapshot)
		if back_room_panel.visible:
			_position_back_room_deal_panel()


func _open_back_room_deal_panel(snapshot: Dictionary = {}) -> bool:
	if back_room_panel == null:
		_build_back_room_deal_panel()
	if back_room_panel == null:
		return false

	var panel_snapshot := latest_back_room_deal_snapshot
	if not snapshot.is_empty():
		_set_back_room_deal_snapshot(snapshot)
		panel_snapshot = latest_back_room_deal_snapshot

	back_room_panel.open_panel(panel_snapshot)
	if back_room_panel.visible:
		_position_back_room_deal_panel()
	return back_room_panel.visible


func _close_back_room_deal_panel() -> void:
	if back_room_panel != null:
		back_room_panel.close_panel()


func _position_back_room_deal_panel() -> void:
	if back_room_panel == null:
		return

	var panel_size := back_room_panel.get_desired_panel_size()
	var viewport_size := get_viewport_rect().size
	var panel_position := (viewport_size - panel_size) * 0.5
	var max_x := maxf(viewport_size.x - panel_size.x - BACK_ROOM_PANEL_VIEWPORT_MARGIN, BACK_ROOM_PANEL_VIEWPORT_MARGIN)
	var max_y := maxf(viewport_size.y - panel_size.y - BACK_ROOM_PANEL_VIEWPORT_MARGIN, BACK_ROOM_PANEL_VIEWPORT_MARGIN)
	panel_position.x = clampf(panel_position.x, BACK_ROOM_PANEL_VIEWPORT_MARGIN, max_x)
	panel_position.y = clampf(panel_position.y, BACK_ROOM_PANEL_VIEWPORT_MARGIN, max_y)
	back_room_panel.position = panel_position


func _build_sunken_spoils_ui() -> void:
	if sunken_spoils_hud == null:
		sunken_spoils_hud = SunkenSpoilsHUD.new()
		sunken_spoils_hud.name = "SunkenSpoilsHUD"
		debug_overlay.add_child(sunken_spoils_hud)
		sunken_spoils_hud.setup(table.sunken_spoils_system)

	if sunken_spoils_panel == null:
		sunken_spoils_panel = SunkenSpoilsPanel.new()
		sunken_spoils_panel.name = "SunkenSpoilsPanel"
		debug_overlay.add_child(sunken_spoils_panel)
		sunken_spoils_panel.reward_selected.connect(_on_sunken_spoils_reward_selected)
		sunken_spoils_panel.doubloon_reroll_requested.connect(_on_sunken_spoils_doubloon_reroll_requested)
		sunken_spoils_panel.cast_back_requested.connect(_on_sunken_spoils_cast_back_requested)
		sunken_spoils_panel.set_hover_ui_suppressed(table.should_suppress_hover_ui())

	if not latest_sunken_spoils_snapshot.is_empty():
		_set_sunken_spoils_snapshot(latest_sunken_spoils_snapshot)
	else:
		_set_sunken_spoils_snapshot(table.sunken_spoils_system.get_spoils_snapshot())


func _build_roguelite_hud() -> void:
	if roguelite_hud == null:
		roguelite_hud = RogueliteHUD.new()
		roguelite_hud.name = "RogueliteHUD"
		roguelite_hud.process_mode = Node.PROCESS_MODE_ALWAYS
		debug_overlay.add_child(roguelite_hud)

	if table.roguelite_run_system != null:
		if not table.roguelite_run_system.state_changed.is_connected(_on_roguelite_state_changed):
			table.roguelite_run_system.state_changed.connect(_on_roguelite_state_changed)
		roguelite_hud.set_snapshot(table.roguelite_run_system.get_snapshot())

	roguelite_hud.set_visible_for_roguelite(table.is_roguelite_mode())


func _build_roguelite_round_panel() -> void:
	if roguelite_round_panel != null:
		return

	roguelite_round_panel = RogueliteRoundPanel.new()
	roguelite_round_panel.name = "RogueliteRoundPanel"
	roguelite_round_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	debug_overlay.add_child(roguelite_round_panel)
	roguelite_round_panel.continue_requested.connect(_on_roguelite_continue_requested)
	roguelite_round_panel.restart_requested.connect(_on_roguelite_restart_requested)
	roguelite_round_panel.abandon_requested.connect(_on_roguelite_abandon_requested)


func _build_roguelite_reward_panel() -> void:
	if roguelite_reward_panel != null:
		return

	roguelite_reward_panel = RogueliteRewardPanel.new()
	roguelite_reward_panel.name = "RogueliteRewardPanel"
	roguelite_reward_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	debug_overlay.add_child(roguelite_reward_panel)
	roguelite_reward_panel.reward_selected.connect(_on_roguelite_reward_selected)


func _set_sunken_spoils_snapshot(snapshot: Dictionary) -> void:
	latest_sunken_spoils_snapshot = snapshot.duplicate(true)
	if _is_roguelite_mode():
		if sunken_spoils_hud != null:
			sunken_spoils_hud.visible = false
		if sunken_spoils_panel != null:
			sunken_spoils_panel.close_panel()
		return
	if sunken_spoils_hud != null:
		sunken_spoils_hud.set_spoils_snapshot(latest_sunken_spoils_snapshot)
	if sunken_spoils_panel != null:
		sunken_spoils_panel.set_spoils_snapshot(latest_sunken_spoils_snapshot)
		if bool(latest_sunken_spoils_snapshot.get("pending_reward_ready", false)):
			if passage_completion_in_progress:
				sunken_spoils_panel.close_panel()
				return
			if table_event_menu != null and table_event_menu.visible:
				table_event_menu.close_menu()
			sunken_spoils_panel.open_panel(latest_sunken_spoils_snapshot)
		elif sunken_spoils_panel.visible:
			sunken_spoils_panel.close_panel()


func _sync_initial_hud_state() -> void:
	pause_menu.set_debug_panel_states(debug_overlay.get_modular_debug_panel_states())
	pause_menu.set_debris_collision_debug_state(table.table_obstacle_system.obstacle_collision_enabled)
	pause_menu.set_debris_collision_draw_debug_state(table.table_obstacle_system.debug_collision_draw_enabled)
	pause_menu.set_back_room_force_available_debug_state(bool(table.back_room_deal_system.get_deal_snapshot().get("debug_force_available", false)))
	table.set_debug_cloned_aim_configuration(pause_menu.get_cloned_aim_configuration())
	quartermaster_hud.set_quartermaster_items(table.quartermaster_system.get_shop_items_snapshot())
	_set_back_room_deal_snapshot(table.back_room_deal_system.get_deal_snapshot())
	_set_sunken_spoils_snapshot(table.sunken_spoils_system.get_spoils_snapshot())
	cue_start_selector_hud.set_cue_start_snapshot(table.get_cue_start_selection_snapshot())
	_on_gameplay_mouse_lock_changed(table.should_suppress_hover_ui())
	_apply_mode_visibility()


func _configure_pause_process_modes() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	progression_system.process_mode = Node.PROCESS_MODE_ALWAYS
	cue_progression_system.process_mode = Node.PROCESS_MODE_ALWAYS
	table.process_mode = Node.PROCESS_MODE_PAUSABLE
	debug_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_feed.process_mode = Node.PROCESS_MODE_ALWAYS
	reserve_slots_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	quartermaster_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	reserve_deployment_presenter.process_mode = Node.PROCESS_MODE_ALWAYS
	run_ledger_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	run_stats_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	cue_start_selector_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	passage_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	oath_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	kraken_boon_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	table_event_meter.process_mode = Node.PROCESS_MODE_ALWAYS
	table_event_menu.process_mode = Node.PROCESS_MODE_ALWAYS


func _is_roguelite_mode() -> bool:
	return table != null and table.is_roguelite_mode()


func _apply_mode_visibility() -> void:
	var roguelite_active := _is_roguelite_mode()
	if passage_hud != null:
		passage_hud.visible = not roguelite_active
	if oath_hud != null:
		oath_hud.visible = not roguelite_active
	if kraken_boon_hud != null:
		kraken_boon_hud.visible = not roguelite_active
	if table_event_meter != null:
		table_event_meter.visible = not roguelite_active
	if table_event_menu != null and roguelite_active:
		table_event_menu.close_menu()
	if reserve_slots_ui != null:
		reserve_slots_ui.visible = not roguelite_active
	if reserve_deployment_presenter != null:
		reserve_deployment_presenter.visible = not roguelite_active
	if quartermaster_hud != null:
		quartermaster_hud.visible = not roguelite_active
	if back_room_panel != null and roguelite_active:
		back_room_panel.close_panel()
	if sunken_spoils_hud != null:
		sunken_spoils_hud.visible = not roguelite_active
	if sunken_spoils_panel != null and roguelite_active:
		sunken_spoils_panel.close_panel()
	if roguelite_hud != null:
		roguelite_hud.set_visible_for_roguelite(roguelite_active)
	if roguelite_round_panel != null and not roguelite_active:
		roguelite_round_panel.close_panel()
	if roguelite_reward_panel != null and not roguelite_active:
		roguelite_reward_panel.close_panel()


func _setup_cue_progression_runtime_bridge() -> void:
	if cue_progression_system == null or progression_system == null:
		return

	if not cue_progression_system.cue_progression_changed.is_connected(_on_cue_progression_changed):
		cue_progression_system.cue_progression_changed.connect(_on_cue_progression_changed)
	if table != null and table.oath_system != null and not table.oath_system.oaths_changed.is_connected(_on_oaths_runtime_changed):
		table.oath_system.oaths_changed.connect(_on_oaths_runtime_changed)
	cue_progression_system.setup(progression_system)
	_apply_cue_progression_snapshot(cue_progression_system.get_cue_progression_snapshot())


func _apply_cue_progression_snapshot(snapshot: Dictionary) -> void:
	if table == null:
		return
	latest_cue_progression_snapshot = snapshot.duplicate(true)
	var base_modifier_snapshot := _get_cue_modifier_snapshot_from_progression_snapshot(snapshot)
	var modifier_snapshot := _get_runtime_cue_modifier_snapshot(base_modifier_snapshot)
	if table.has_method("set_cue_modifier_snapshot"):
		table.set_cue_modifier_snapshot(modifier_snapshot)
	if table.table_event_system != null:
		table.table_event_system.set_cue_modifier_snapshot(modifier_snapshot)
	if table.quartermaster_system != null:
		table.quartermaster_system.set_cue_modifier_snapshot(modifier_snapshot)
	if table.oath_system != null:
		table.oath_system.set_cue_modifier_snapshot(modifier_snapshot)
	if table.passage_system != null:
		table.passage_system.set_cue_modifier_snapshot(modifier_snapshot)
	if table.run_stats_system != null:
		table.run_stats_system.set_cue_loadout_snapshot(snapshot)
		table.run_stats_system.set_cue_modifier_snapshot(modifier_snapshot)
	if table.cue_controller != null:
		table.cue_controller.set_cue_loadout_snapshot(snapshot)
	if pause_menu != null and table.oath_system != null:
		pause_menu.set_oath_debug_snapshot(table.oath_system.get_oath_snapshot(), modifier_snapshot)


func _get_cue_modifier_snapshot_from_progression_snapshot(snapshot: Dictionary) -> Dictionary:
	var modifier_value: Variant = snapshot.get("active_modifiers", {})
	if modifier_value is Dictionary:
		return (modifier_value as Dictionary).duplicate(true)
	if cue_progression_system != null:
		return cue_progression_system.get_active_cue_modifier_snapshot(true)
	return {}


func _get_runtime_cue_modifier_snapshot(base_modifier_snapshot: Dictionary) -> Dictionary:
	var runtime_snapshot := base_modifier_snapshot.duplicate(true)
	runtime_snapshot["suppressed_by_oath"] = false
	runtime_snapshot["suppression_reason"] = ""
	runtime_snapshot["suppression_label"] = ""
	runtime_snapshot["suppression_remaining_text"] = ""
	if table == null or table.oath_system == null:
		return runtime_snapshot

	var suppression_snapshot: Dictionary = table.oath_system.get_cue_modifier_suppression_snapshot()
	if not bool(suppression_snapshot.get("suppressed", false)):
		return runtime_snapshot

	runtime_snapshot["modifiers_enabled"] = false
	runtime_snapshot["suppressed_by_oath"] = true
	runtime_snapshot["suppression_reason"] = str(suppression_snapshot.get("reason", "Cue bonuses are silenced."))
	runtime_snapshot["suppression_label"] = str(suppression_snapshot.get("label", "Oath of Humility"))
	runtime_snapshot["suppression_remaining_text"] = str(suppression_snapshot.get("remaining_text", ""))
	runtime_snapshot["unsuppressed_active_effect_summary"] = str(base_modifier_snapshot.get("active_effect_summary", "None"))
	runtime_snapshot["active_effect_summary"] = "Silenced by Oath"
	return runtime_snapshot


func _refresh_runtime_cue_modifier_snapshot() -> void:
	if latest_cue_progression_snapshot.is_empty():
		if cue_progression_system == null:
			return
		latest_cue_progression_snapshot = cue_progression_system.get_cue_progression_snapshot()
	_apply_cue_progression_snapshot(latest_cue_progression_snapshot)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == PAUSE_TOGGLE_KEY:
		if passage_completion_in_progress:
			get_viewport().set_input_as_handled()
			return
		if get_tree().paused and pause_menu.is_dev_options_open():
			pause_menu.handle_dev_options_cancel_request()
		elif table.is_ball_placement_active():
			table.cancel_active_ball_placement()
		else:
			_set_game_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == FULLSCREEN_TOGGLE_KEY:
		_toggle_fullscreen()
	elif key_event.alt_pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
		_toggle_fullscreen()


func _on_status_text_changed(text: String) -> void:
	hud_feed.add_message(text, "status")


func _on_debug_notification_requested(text: String, category: String) -> void:
	if text.strip_edges().is_empty():
		return
	hud_feed.add_message(text, category if not category.is_empty() else "event")


func _on_game_finished(text: String) -> void:
	if _is_roguelite_mode():
		result_label.text = ""
		hud_feed.add_message(text, "status")
		return

	result_label.text = text
	hud_feed.add_message(text, "status")


func _on_doubloons_changed(total: int) -> void:
	doubloons_label.text = "Doubloons: %s" % total
	if quartermaster_hud != null and table != null:
		quartermaster_hud.set_quartermaster_items(table.quartermaster_system.get_shop_items_snapshot())
	if table_event_menu != null and table_event_menu.visible:
		table_event_menu.refresh_offers()


func _on_score_feed_message(text: String) -> void:
	hud_feed.add_message(text, "score")


func _on_table_event_status_changed(text: String) -> void:
	hud_feed.add_message(text, "event")


func _on_sunken_spoils_changed(snapshot: Dictionary) -> void:
	_set_sunken_spoils_snapshot(snapshot)


func _on_sunken_spoils_status_changed(text: String) -> void:
	if _is_roguelite_mode():
		return
	if text.is_empty():
		return
	hud_feed.add_message(text, "event")


func _on_roguelite_state_changed(snapshot: Dictionary) -> void:
	if roguelite_hud != null:
		roguelite_hud.set_snapshot(snapshot)
	_apply_mode_visibility()


func _on_roguelite_round_cleared(snapshot: Dictionary) -> void:
	hud_feed.add_message("Round Cleared", "status")
	if table != null and table.should_offer_roguelite_reward(snapshot):
		var reward_snapshot: Dictionary = table.generate_roguelite_reward_offers(snapshot)
		var offers_value: Variant = reward_snapshot.get("offers", [])
		var offers: Array = []
		if offers_value is Array:
			offers = offers_value
		if roguelite_reward_panel != null and not offers.is_empty():
			roguelite_reward_panel.open_panel(reward_snapshot)
			return

	if roguelite_round_panel != null:
		roguelite_round_panel.open_round_cleared(snapshot)


func _on_roguelite_run_failed(snapshot: Dictionary) -> void:
	result_label.text = ""
	if roguelite_reward_panel != null:
		roguelite_reward_panel.close_panel()
	if roguelite_round_panel != null:
		roguelite_round_panel.open_run_failed(snapshot)
	hud_feed.add_message("Run Failed", "status")


func _on_roguelite_run_completed(snapshot: Dictionary) -> void:
	if roguelite_reward_panel != null:
		roguelite_reward_panel.close_panel()
	if roguelite_round_panel != null:
		roguelite_round_panel.open_run_completed(snapshot)
	hud_feed.add_message("Run Complete", "status")


func _on_roguelite_continue_requested() -> void:
	if table == null or not table.is_roguelite_mode():
		return
	if not table.continue_roguelite_round():
		return

	if roguelite_round_panel != null:
		roguelite_round_panel.close_panel()
	if roguelite_reward_panel != null:
		roguelite_reward_panel.close_panel()
	if roguelite_hud != null:
		roguelite_hud.set_snapshot(table.get_roguelite_run_snapshot())
	result_label.text = ""
	_apply_mode_visibility()


func _on_roguelite_restart_requested() -> void:
	if end_run_in_progress:
		return

	end_run_in_progress = true
	if roguelite_round_panel != null:
		roguelite_round_panel.close_panel()
	if roguelite_reward_panel != null:
		roguelite_reward_panel.close_panel()
	result_label.text = ""
	get_tree().paused = false
	GAME_MODE_SCRIPT.set_pending_mode(get_tree(), GAME_MODE_SCRIPT.MODE_ROGUELITE)
	var error_code: int = get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
	if error_code != OK:
		end_run_in_progress = false
		if roguelite_round_panel != null:
			var snapshot: Dictionary = table.get_roguelite_run_snapshot() if table != null else {}
			roguelite_round_panel.open_run_failed(snapshot)


func _on_roguelite_reward_selected(reward_id: String) -> void:
	if table == null or not table.is_roguelite_mode():
		return
	if not table.choose_roguelite_reward(reward_id):
		return

	if roguelite_reward_panel != null:
		roguelite_reward_panel.close_panel()
	if roguelite_hud != null:
		roguelite_hud.set_snapshot(table.get_roguelite_run_snapshot())
	_on_roguelite_continue_requested()


func _on_roguelite_abandon_requested() -> void:
	if end_run_in_progress:
		return

	end_run_in_progress = true
	if roguelite_round_panel != null:
		roguelite_round_panel.close_panel()
	if roguelite_reward_panel != null:
		roguelite_reward_panel.close_panel()
	get_tree().paused = false
	var error_code: int = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error_code != OK:
		end_run_in_progress = false
		if roguelite_round_panel != null:
			roguelite_round_panel.visible = true


func _on_gameplay_mouse_lock_changed(locked: bool) -> void:
	oath_hud.set_hover_ui_suppressed(locked)
	passage_hud.set_hover_ui_suppressed(locked)
	kraken_boon_hud.set_hover_ui_suppressed(locked)
	cue_start_selector_hud.set_hover_ui_suppressed(locked)
	quartermaster_hud.set_hover_ui_suppressed(locked)
	table_event_meter.set_hover_ui_suppressed(locked)
	run_stats_hud.set_hover_ui_suppressed(locked)
	hud_feed.set_hover_ui_suppressed(locked)
	reserve_slots_ui.set_hover_ui_suppressed(locked)
	if back_room_panel != null:
		back_room_panel.set_hover_ui_suppressed(locked)
	if sunken_spoils_hud != null:
		sunken_spoils_hud.set_hover_ui_suppressed(locked)
	if sunken_spoils_panel != null:
		sunken_spoils_panel.set_hover_ui_suppressed(locked)


func _on_cue_start_selection_changed(snapshot: Dictionary) -> void:
	cue_start_selector_hud.set_cue_start_snapshot(snapshot)


func _on_table_event_icon_clicked() -> void:
	table_event_menu.open_menu()


func _on_table_event_offer_selected(offer_index: int) -> void:
	table.table_event_system.request_purchase_offer(offer_index)


func _on_table_event_boon_offer_selected(boon_offer_index: int) -> void:
	table.table_event_system.request_purchase_boon_offer(boon_offer_index)


func _on_table_event_offer_replace_requested(offer_index: int, oath_id: String) -> void:
	table.table_event_system.request_reroll_offer_with_oath(offer_index, oath_id)


func _on_table_event_purchased(_event_id: String, _charge_cost: int) -> void:
	table_event_menu.close_menu()


func _on_sunken_spoils_reward_selected(reward_id: String) -> void:
	table.sunken_spoils_system.claim_reward(reward_id)


func _on_sunken_spoils_doubloon_reroll_requested() -> void:
	table.sunken_spoils_system.request_doubloon_reroll()


func _on_sunken_spoils_cast_back_requested() -> void:
	table.sunken_spoils_system.cast_back()


func _on_run_stats_changed(snapshot: Dictionary) -> void:
	if pause_menu != null:
		pause_menu.set_run_stats_snapshot(snapshot)


func _on_passage_request_completed(request_snapshot: Dictionary, reward: int) -> void:
	var request_label := str(request_snapshot.get("label", "REQUEST"))
	hud_feed.add_message("Kraken request met: %s. Passage -%s." % [request_label, maxi(reward, 0)], "event")


func _on_passage_request_rerolled(previous_request_snapshot: Dictionary, new_request_snapshot: Dictionary, cost: int) -> void:
	var previous_label := str(previous_request_snapshot.get("label", "REQUEST"))
	var new_label := str(new_request_snapshot.get("label", "REQUEST"))
	hud_feed.add_message("The Kraken changes its demand: %s to %s. Passage +%s." % [previous_label, new_label, maxi(cost, 0)], "event")


func _on_oath_status_changed(text: String) -> void:
	if text.is_empty():
		return
	hud_feed.add_message(text, "event")


func _on_passage_completed(passage_snapshot: Dictionary) -> void:
	if passage_completion_in_progress or end_run_in_progress:
		return

	passage_completion_in_progress = true
	_finalize_successful_passage_progression(passage_snapshot)
	if table_event_menu != null and table_event_menu.visible:
		table_event_menu.close_menu()
	if sunken_spoils_panel != null and sunken_spoils_panel.visible:
		sunken_spoils_panel.close_panel()
	if run_stats_hud != null:
		run_stats_hud.close_panel()
	if table != null and table.is_ball_placement_active():
		table.cancel_active_ball_placement()
	if pause_menu != null:
		pause_menu.set_pause_visible(false)

	get_tree().paused = true
	hud_feed.add_message("Passage bought. The Kraken lets the ship through.", "status")
	var favor_earned := maxi(int(passage_completion_progression_award.get("kraken_favor_earned", 0)), 0)
	if favor_earned > 0:
		hud_feed.add_message("The Kraken remembers. Favor +%s." % favor_earned, "status")
	_show_passage_completion_panel()


func _on_pause_resume_requested() -> void:
	_set_game_paused(false)


func _on_pause_end_run_requested() -> void:
	if end_run_in_progress:
		return

	end_run_in_progress = true
	if table_event_menu != null and table_event_menu.visible:
		table_event_menu.close_menu()
	if table != null and table.is_ball_placement_active():
		table.cancel_active_ball_placement()
	if pause_menu != null:
		pause_menu.set_pause_visible(false)

	_save_final_run_history()
	get_tree().paused = false
	var error_code: int = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error_code != OK:
		end_run_in_progress = false
		get_tree().paused = true
		pause_menu.set_pause_visible(true)


func _on_pause_debug_panel_toggled(panel_id: String, enabled: bool) -> void:
	debug_overlay.set_modular_debug_panel_visible(panel_id, enabled)


func _on_pause_wayfinder_current_test_button_toggled(enabled: bool) -> void:
	debug_overlay.set_wayfinder_current_test_button_visible(enabled)


func _on_pause_broadside_attack_test_button_toggled(enabled: bool) -> void:
	debug_overlay.set_broadside_attack_test_button_visible(enabled)


func _on_pause_force_loose_cargo_contraband_toggled(enabled: bool) -> void:
	table.table_event_system.set_debug_force_loose_cargo_contraband(enabled)


func _on_pause_loose_cargo_contraband_kind_selected(kind: String) -> void:
	table.table_event_system.set_debug_loose_cargo_contraband_kind(kind)


func _on_pause_spawn_wood_debris_requested() -> void:
	var obstacle: Node = table.table_obstacle_system.debug_spawn_wood_debris()
	if obstacle == null:
		hud_feed.add_message("Debris spawn failed.", "event")
	else:
		hud_feed.add_message("Wood debris dropped onto the felt.", "event")


func _on_pause_clear_debris_requested() -> void:
	table.table_obstacle_system.clear_debug_debris()
	hud_feed.add_message("Debris cleared.", "event")


func _on_pause_obstacle_collision_toggled(enabled: bool) -> void:
	table.table_obstacle_system.set_obstacle_collision_enabled(enabled)
	var status_text := "Debris collision enabled." if enabled else "Debris collision disabled."
	hud_feed.add_message(status_text, "event")


func _on_pause_obstacle_collision_draw_toggled(enabled: bool) -> void:
	table.table_obstacle_system.set_debug_collision_draw_enabled(enabled)
	var status_text := "Debris collision shape shown." if enabled else "Debris collision shape hidden."
	hud_feed.add_message(status_text, "event")


func _on_pause_pocket_capture_presentation_toggled(enabled: bool) -> void:
	table.set_pocket_capture_presentation_enabled(enabled)
	var status_text := "Pocket capture presentation enabled." if enabled else "Pocket capture presentation disabled."
	hud_feed.add_message(status_text, "event")


func _on_pause_clear_pocket_collections_requested() -> void:
	table.clear_pocket_capture_collections("debug_clear")
	hud_feed.add_message("Pocket collections cleared (presentation only).", "event")


func _on_pause_pocket_collection_anchors_toggled(enabled: bool) -> void:
	table.set_pocket_collection_anchor_debug_enabled(enabled)
	var status_text: String = "Pocket collection anchors shown." if enabled else "Pocket collection anchors hidden."
	hud_feed.add_message(status_text, "event")


func _on_pause_reflow_pocket_collections_requested() -> void:
	table.reflow_pocket_capture_collections("debug_reflow")
	hud_feed.add_message("Pocket collections reflowed to authored anchors.", "event")


func _on_pause_debug_oath_activate_requested(oath_id: String) -> void:
	if table.oath_system.debug_activate_oath(oath_id):
		hud_feed.add_message("Debug Oath activated: %s." % _get_oath_label(oath_id), "event")
		return

	var blocker: String = table.oath_system.get_oath_activation_blocker(oath_id, true)
	hud_feed.add_message("Debug Oath blocked: %s." % blocker, "event")


func _on_pause_debug_oath_clear_requested() -> void:
	table.oath_system.debug_clear_oaths()
	hud_feed.add_message("Debug Oaths cleared.", "event")


func _on_pause_debug_oath_advance_shot_requested() -> void:
	if table.oath_system.debug_advance_oath_shot():
		hud_feed.add_message("Debug Oath timers advanced.", "event")
	else:
		hud_feed.add_message("Debug Oath advance skipped: no active Oaths.", "event")


func _on_pause_debug_oath_fail_requested(oath_id: String) -> void:
	if table.oath_system.debug_fail_oath(oath_id):
		hud_feed.add_message("Debug Oath failed.", "event")
	else:
		hud_feed.add_message("Debug Oath fail skipped: no matching active Oath.", "event")


func _on_pause_debug_oath_complete_requested(oath_id: String) -> void:
	if table.oath_system.debug_complete_oath(oath_id):
		hud_feed.add_message("Debug Oath completed.", "event")
	else:
		hud_feed.add_message("Debug Oath complete skipped: no matching active Oath.", "event")


func _on_pause_back_room_force_available_toggled(enabled: bool) -> void:
	table.back_room_deal_system.set_debug_force_available(enabled)
	var status_text := "Back Room debug availability forced." if enabled else "Back Room debug availability restored."
	hud_feed.add_message(status_text, "shop")


func _on_pause_back_room_open_requested() -> void:
	var snapshot: Dictionary = table.back_room_deal_system.get_deal_snapshot()
	if _open_back_room_deal_panel(snapshot):
		_set_game_paused(false)
		hud_feed.add_message("Back Room opened for testing.", "shop")
		return

	var blocker := str(snapshot.get("blocked_reason", "Back Room unavailable."))
	hud_feed.add_message("Back Room debug open blocked: %s" % blocker, "shop")


func _on_pause_debug_activate_long_sight_requested() -> void:
	_debug_activate_boon(KrakenBoonSystem.BOON_LONG_SIGHT)


func _on_pause_debug_activate_krakens_patience_requested() -> void:
	_debug_activate_boon(KrakenBoonSystem.BOON_KRAKENS_PATIENCE)


func _on_pause_debug_activate_deep_ledger_requested() -> void:
	_debug_activate_boon(KrakenBoonSystem.BOON_DEEP_LEDGER)


func _on_pause_debug_activate_iron_wake_requested() -> void:
	_debug_activate_boon(KrakenBoonSystem.BOON_IRON_WAKE)


func _debug_activate_boon(boon_id: String) -> void:
	if table.kraken_boon_system.activate_boon(boon_id):
		var message: String = table.kraken_boon_system.get_boon_activation_message(boon_id)
		hud_feed.add_message("Debug Boon: %s" % (message if not message.is_empty() else "Boon active."), "event")
		return

	var blocker: String = table.kraken_boon_system.get_boon_activation_blocker(boon_id)
	hud_feed.add_message("Debug Boon blocked: %s." % blocker, "event")


func _on_pause_debug_expire_all_boons_requested() -> void:
	var expired_count: int = table.kraken_boon_system.debug_expire_all_boons()
	if expired_count <= 0:
		hud_feed.add_message("Debug Boon expire skipped: no active boons.", "event")
	else:
		hud_feed.add_message("Debug Boons expired: %s." % expired_count, "event")


func _on_pause_debug_reserve_stack_payload_requested(payload: Dictionary) -> void:
	if table == null or table.reserve_system == null:
		hud_feed.add_message("Reserve stack test blocked: Reserve unavailable.", "shop")
		return

	if table.reserve_system.is_full():
		hud_feed.add_message("Reserve stack test blocked: Reserve is full.", "shop")
		return

	var stored_slot_index: int = table.reserve_system.store_item_in_first_empty_slot(payload)
	if stored_slot_index < 0:
		hud_feed.add_message("Reserve stack test failed: payload could not be stowed.", "shop")
		return

	var item_name: String = str(payload.get("display_name", payload.get("item_name", "Reserve item")))
	var quantity: int = maxi(int(payload.get("quantity", 1)), 1)
	hud_feed.add_message("Debug Reserve stack: %s x%s stowed in slot %s." % [
		item_name,
		quantity,
		stored_slot_index + 1,
	], "shop")


func _on_pause_debug_sunken_spoils_advance_requested() -> void:
	if table == null or table.sunken_spoils_system == null:
		hud_feed.add_message("Sunken Spoils debug blocked: system unavailable.", "event")
		return
	if table.is_roguelite_mode():
		hud_feed.add_message("Sunken Spoils debug blocked in roguelite mode.", "event")
		return

	table.sunken_spoils_system.debug_advance_progress(1)
	_unpause_if_sunken_spoils_ready()


func _on_pause_debug_sunken_spoils_trigger_requested() -> void:
	if table == null or table.sunken_spoils_system == null:
		hud_feed.add_message("Sunken Spoils debug blocked: system unavailable.", "event")
		return
	if table.is_roguelite_mode():
		hud_feed.add_message("Sunken Spoils debug blocked in roguelite mode.", "event")
		return

	table.sunken_spoils_system.debug_trigger_reward()
	_unpause_if_sunken_spoils_ready()


func _on_pause_debug_sunken_spoils_reset_requested() -> void:
	if table == null or table.sunken_spoils_system == null:
		hud_feed.add_message("Sunken Spoils debug blocked: system unavailable.", "event")
		return
	if table.is_roguelite_mode():
		hud_feed.add_message("Sunken Spoils debug blocked in roguelite mode.", "event")
		return

	table.sunken_spoils_system.debug_reset_spoils()


func _on_pause_debug_aim_line_toggled(enabled: bool) -> void:
	if table == null:
		return
	table.set_debug_aim_line_enabled(enabled)
	var snapshot: Dictionary = table.get_debug_aim_mode_snapshot()
	var converted: int = int(snapshot.get("anomalies_converted_this_activation", 0))
	var status_text: String
	if enabled and converted > 0:
		status_text = "Debug Aim Mode regularized %d anomaly ball%s." % [
			converted,
			"" if converted == 1 else "s",
		]
	elif enabled:
		status_text = "Debug Aim Mode enabled. Anomaly behavior is disabled."
	else:
		status_text = "Debug Aim Mode ended. Future anomalies are enabled."
	hud_feed.add_message(status_text, "event")


func _on_pause_debug_aim_compare_panels_toggled(enabled: bool) -> void:
	debug_overlay.set_aim_compare_panels_visible(enabled)


func _on_pause_debug_verbose_aim_candidates_toggled(enabled: bool) -> void:
	debug_overlay.set_verbose_aim_candidates(enabled)


func _on_pause_debug_cue_first_contact_toi_toggled(enabled: bool) -> void:
	table.set_debug_cue_first_contact_toi_enabled(enabled)


func _on_pause_debug_cloned_aim_configuration_changed(configuration: Dictionary) -> void:
	if table == null:
		return
	table.set_debug_cloned_aim_configuration(configuration)


func _on_pause_debug_force_deep_prediction_requested() -> void:
	if table == null:
		return
	var requested: bool = table.force_debug_deep_aim_prediction_now()
	hud_feed.add_message(
		"Deep aim prediction requested." if requested else "No active aim to predict.",
		"event"
	)


func _on_pause_debug_cancel_pending_deep_prediction_requested() -> void:
	if table == null:
		return
	table.cancel_debug_pending_deep_aim_prediction()
	hud_feed.add_message("Pending deep aim prediction canceled.", "event")


func _on_pause_debug_reset_aim_profiler_requested() -> void:
	if table == null:
		return
	table.reset_debug_aim_profiler_stats()
	hud_feed.add_message("Aim profiler statistics reset.", "event")


func _on_pause_debug_reset_aim_benchmark_requested() -> void:
	if table == null:
		return
	table.reset_debug_aim_benchmark_stats()
	hud_feed.add_message("Aim benchmark statistics reset.", "event")


func _on_pause_debug_start_aim_benchmark_requested(label: String, preset_label: String) -> void:
	if table == null:
		return
	table.start_debug_aim_benchmark(
		label,
		preset_label,
		_get_aim_benchmark_contamination_snapshot()
	)
	hud_feed.add_message("Aim benchmark capture started.", "event")


func _on_pause_debug_stop_aim_benchmark_requested() -> void:
	if table == null:
		return
	table.stop_debug_aim_benchmark()
	hud_feed.add_message("Aim benchmark capture stopped.", "event")


func _on_pause_debug_copy_aim_benchmark_report_requested() -> void:
	if table == null:
		return
	if table.copy_debug_aim_benchmark_report():
		hud_feed.add_message("Aim benchmark report copied.", "event")
	else:
		hud_feed.add_message("Aim benchmark report unavailable: capture has no results.", "event")


func _get_aim_benchmark_contamination_snapshot() -> Dictionary:
	var configuration: Dictionary = table.get_debug_cloned_aim_configuration() if table != null else {}
	var full_debug: bool = str(configuration.get(
		"result_detail_mode",
		AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
	)) == AimTrajectoryPredictor.RESULT_MODE_FULL_DEBUG
	var panel_states: Dictionary = (
		debug_overlay.get_modular_debug_panel_states()
		if debug_overlay != null
		else {}
	)
	return {
		"full_debug_comparison": full_debug and bool(configuration.get("compare_predicted_event_chain", false)),
		"candidate_diagnostics": full_debug and table != null and table.is_debug_aim_line_enabled(),
		"actual_trace_comparison": table != null and table.is_shot_path_debug_enabled(),
		"profiler_panel_visible": bool(panel_states.get("aim_profiler", false)),
		"complete_aim_workspace_visible": bool(panel_states.get("aim_compare_panels", false)),
	}


func _on_pause_debug_reset_table_button_toggled(enabled: bool) -> void:
	debug_overlay.set_reset_table_button_visible(enabled)


func _on_pause_debug_reset_last_shot_button_toggled(enabled: bool) -> void:
	debug_overlay.set_reset_last_shot_button_visible(enabled)


func _on_shot_rewind_state_changed(snapshot: Dictionary) -> void:
	debug_overlay.set_shot_rewind_state(snapshot)


func _on_debug_reset_table_requested() -> void:
	if reset_table_in_progress or end_run_in_progress:
		return
	reset_table_in_progress = true
	if table != null and table.shot_ledger_system != null:
		table.shot_ledger_system.cancel_active_shot("reset_table")
	GAME_MODE_SCRIPT.set_pending_mode(get_tree(), game_mode_id)
	GAME_MODE_SCRIPT.set_pending_debug_session(get_tree(), _capture_debug_session_snapshot())
	get_tree().paused = false
	var error_code: int = get_tree().change_scene_to_file(GAMEPLAY_SCENE_PATH)
	if error_code != OK:
		reset_table_in_progress = false
		hud_feed.add_message("Reset Table failed: scene reload could not start.", "event")


func _on_debug_reset_last_shot_requested() -> void:
	if table == null or table.shot_rewind_system == null:
		return
	if table.shot_rewind_system.request_rewind():
		return
	var blocker: String = str(table.shot_rewind_system.get_state_snapshot().get("blocker_reason", "Reset unavailable."))
	hud_feed.add_message(blocker, "event")


func _capture_debug_session_snapshot() -> Dictionary:
	return {
		"pause_menu": pause_menu.get_debug_session_snapshot(),
		"debug_overlay": debug_overlay.get_debug_session_snapshot(),
	}


func _restore_pending_debug_session() -> void:
	if pending_debug_session_snapshot.is_empty():
		return
	var pause_value: Variant = pending_debug_session_snapshot.get("pause_menu", {})
	if pause_value is Dictionary:
		pause_menu.apply_debug_session_snapshot(pause_value as Dictionary)
	var overlay_value: Variant = pending_debug_session_snapshot.get("debug_overlay", {})
	if overlay_value is Dictionary:
		debug_overlay.apply_debug_session_snapshot(overlay_value as Dictionary)
	pause_menu.set_debug_panel_states(debug_overlay.get_modular_debug_panel_states())
	pending_debug_session_snapshot.clear()


func capture_shot_rewind_ui_state() -> Dictionary:
	return {
		"hud_feed": hud_feed.get_rewind_state(),
		"result_text": result_label.text,
		"progression": (
			progression_system.get_rewind_state()
			if progression_system != null and table != null and table.is_passage_mode()
			else {}
		),
		"passage_completion_progression_award": passage_completion_progression_award.duplicate(true),
	}


func restore_shot_rewind_ui_state(state: Dictionary) -> void:
	var progression_value: Variant = state.get("progression", {})
	if (
		progression_system != null
		and progression_value is Dictionary
		and not (progression_value as Dictionary).is_empty()
	):
		if not progression_system.restore_rewind_state(progression_value as Dictionary):
			push_warning("Shot rewind restored gameplay, but persistent progression could not be rewritten.")
	var passage_award_value: Variant = state.get("passage_completion_progression_award", {})
	passage_completion_progression_award = (
		(passage_award_value as Dictionary).duplicate(true)
		if passage_award_value is Dictionary
		else {}
	)
	if table_event_menu != null and table_event_menu.visible:
		table_event_menu.close_menu()
	if sunken_spoils_panel != null:
		sunken_spoils_panel.close_panel()
	if back_room_panel != null:
		back_room_panel.close_panel()
	if roguelite_round_panel != null:
		roguelite_round_panel.close_panel()
	if roguelite_reward_panel != null:
		roguelite_reward_panel.close_panel()
	if passage_completion_panel != null:
		passage_completion_panel.visible = false
	if passage_completion_blocker != null:
		passage_completion_blocker.visible = false
	passage_completion_in_progress = false
	end_run_in_progress = false
	result_label.text = str(state.get("result_text", ""))
	var feed_value: Variant = state.get("hud_feed", {})
	if feed_value is Dictionary:
		hud_feed.restore_rewind_state(feed_value as Dictionary)
	get_tree().paused = false
	pause_menu.set_pause_visible(false)
	_apply_mode_visibility()


func get_shot_rewind_transition_blocker() -> String:
	if reset_table_in_progress or end_run_in_progress:
		return "Reset unavailable: a scene transition is active."
	return ""


func _unpause_if_sunken_spoils_ready() -> void:
	if table == null or table.sunken_spoils_system == null:
		return
	var snapshot: Dictionary = table.sunken_spoils_system.get_spoils_snapshot()
	if bool(snapshot.get("pending_reward_ready", false)):
		_set_game_paused(false)


func _get_oath_label(oath_id: String) -> String:
	if table == null or table.oath_system == null:
		return oath_id
	for definition_value in table.oath_system.get_available_oath_definitions(true):
		if not definition_value is Dictionary:
			continue
		var definition: Dictionary = definition_value
		if str(definition.get("id", "")) == oath_id:
			return str(definition.get("label", oath_id))
	return oath_id


func _on_quartermaster_hud_offer_requested(offer_index: int) -> void:
	table.quartermaster_system.request_purchase_offer(offer_index)


func _on_quartermaster_hud_refresh_requested() -> void:
	table.quartermaster_system.request_refresh_stock()


func _on_quartermaster_hud_back_room_deal_open_requested() -> void:
	_open_back_room_deal_panel(table.back_room_deal_system.get_deal_snapshot())


func _on_back_room_panel_option_selected(item_id: String) -> void:
	_close_back_room_deal_panel()
	table.back_room_deal_system.request_purchase_deal(item_id)


func _on_passage_hud_request_reroll_requested() -> void:
	table.passage_system.request_reroll_active_request()


func _on_pause_quartermaster_cancel_placement_requested() -> void:
	table.cancel_active_ball_placement()


func _on_reserve_slot_clicked(slot_index: int) -> void:
	if reserve_deployment_active:
		return

	reserve_deployment_previous_pause_state = get_tree().paused
	if not reserve_deployment_previous_pause_state:
		table.cancel_active_cue_drag_for_pause()
		get_tree().paused = true

	if table.reserve_system.request_deploy_slot(slot_index):
		reserve_deployment_active = true
	else:
		get_tree().paused = reserve_deployment_previous_pause_state


func _on_reserve_deployment_finished(_confirmed: bool, _slot_index: int) -> void:
	if not reserve_deployment_active:
		return

	reserve_deployment_active = false
	get_tree().paused = reserve_deployment_previous_pause_state


func _on_reserve_deployment_blocked(reason: String) -> void:
	hud_feed.add_message(reason, "shop")


func _on_reserve_slots_changed(_slots: Array) -> void:
	if quartermaster_hud != null and table != null:
		quartermaster_hud.set_quartermaster_items(table.quartermaster_system.get_shop_items_snapshot())
		_set_back_room_deal_snapshot(table.back_room_deal_system.get_deal_snapshot())


func _on_quartermaster_shop_state_changed(items: Array) -> void:
	quartermaster_hud.set_quartermaster_items(items)


func _on_quartermaster_status_changed(text: String) -> void:
	hud_feed.add_message(text, "shop")


func _on_back_room_deal_state_changed(snapshot: Dictionary) -> void:
	_set_back_room_deal_snapshot(snapshot)


func _on_back_room_deal_status_changed(text: String) -> void:
	hud_feed.add_message(text, "shop")


func _on_cue_progression_changed(snapshot: Dictionary) -> void:
	_apply_cue_progression_snapshot(snapshot)


func _on_oaths_runtime_changed(_snapshot: Dictionary) -> void:
	_refresh_runtime_cue_modifier_snapshot()


func _on_quartermaster_placement_started(item_name: String) -> void:
	pause_menu.set_quartermaster_placement_mode(true, item_name)


func _on_quartermaster_placement_finished() -> void:
	pause_menu.set_quartermaster_placement_mode(false)
	quartermaster_hud.set_quartermaster_items(table.quartermaster_system.get_shop_items_snapshot())


func _set_game_paused(paused: bool) -> void:
	if paused == get_tree().paused and pause_menu.visible == paused:
		return

	if paused:
		if table_event_menu.visible:
			table_event_menu.close_menu()
		if run_stats_hud != null:
			run_stats_hud.close_panel()
		table.cancel_active_cue_drag_for_pause()
		get_tree().paused = true
		_refresh_pause_run_stats()
		pause_menu.set_pause_visible(true)
		quartermaster_hud.set_quartermaster_items(table.quartermaster_system.get_shop_items_snapshot())
	else:
		if table.is_ball_placement_active():
			table.cancel_active_ball_placement()
		pause_menu.set_pause_visible(false)
		get_tree().paused = false


func _refresh_pause_run_stats() -> void:
	if pause_menu == null or table == null or table.run_stats_system == null:
		return

	pause_menu.set_run_stats_snapshot(table.run_stats_system.get_run_stats_snapshot())


func _save_final_run_history() -> void:
	if run_history_system == null or table == null or table.run_stats_system == null or table.score_system == null:
		return

	var stats_snapshot: Dictionary = table.run_stats_system.get_run_stats_snapshot()
	if not passage_completion_progression_award.is_empty():
		stats_snapshot["kraken_favor_earned"] = int(passage_completion_progression_award.get("kraken_favor_earned", 0))
		stats_snapshot["total_kraken_favor_after_run"] = int(passage_completion_progression_award.get("total_kraken_favor", 0))
	var final_doubloons: int = table.score_system.get_doubloons_total()
	run_history_system.save_finalized_run(stats_snapshot, final_doubloons)


func _finalize_successful_passage_progression(passage_snapshot: Dictionary = {}) -> void:
	passage_completion_progression_award = {}
	if progression_system == null or table == null or table.run_stats_system == null:
		return

	var stats_snapshot: Dictionary = table.run_stats_system.get_run_stats_snapshot()
	if not passage_snapshot.is_empty():
		stats_snapshot["passage_completed"] = bool(passage_snapshot.get("run_completed", true))
		stats_snapshot["remaining_passage"] = maxi(int(passage_snapshot.get("remaining_passage", 0)), 0)
		stats_snapshot["voyage_marks_awarded"] = maxi(int(passage_snapshot.get("voyage_marks_awarded", 0)), 0)
	passage_completion_progression_award = progression_system.finalize_successful_passage(stats_snapshot)


func _show_passage_completion_panel() -> void:
	if passage_completion_panel == null:
		_build_passage_completion_panel()
	_update_passage_completion_values()
	if passage_completion_blocker != null:
		passage_completion_blocker.visible = true
	passage_completion_panel.visible = true
	if passage_completion_confirm_button != null:
		passage_completion_confirm_button.grab_focus()


func _build_passage_completion_panel() -> void:
	passage_completion_blocker = ColorRect.new()
	passage_completion_blocker.name = "PassageCompleteBlocker"
	passage_completion_blocker.visible = false
	passage_completion_blocker.process_mode = Node.PROCESS_MODE_ALWAYS
	passage_completion_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	passage_completion_blocker.color = Color(0.01, 0.012, 0.016, 0.62)
	passage_completion_blocker.anchor_left = 0.0
	passage_completion_blocker.anchor_right = 1.0
	passage_completion_blocker.anchor_top = 0.0
	passage_completion_blocker.anchor_bottom = 1.0
	passage_completion_blocker.z_index = 79
	$CanvasLayer/HUD.add_child(passage_completion_blocker)

	passage_completion_panel = PanelContainer.new()
	passage_completion_panel.name = "PassageCompletePanel"
	passage_completion_panel.visible = false
	passage_completion_panel.z_index = 80
	passage_completion_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	passage_completion_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	passage_completion_panel.anchor_left = 0.5
	passage_completion_panel.anchor_right = 0.5
	passage_completion_panel.anchor_top = 0.5
	passage_completion_panel.anchor_bottom = 0.5
	passage_completion_panel.offset_left = -COMPLETION_PANEL_SIZE.x * 0.5
	passage_completion_panel.offset_right = COMPLETION_PANEL_SIZE.x * 0.5
	passage_completion_panel.offset_top = -COMPLETION_PANEL_SIZE.y * 0.5
	passage_completion_panel.offset_bottom = COMPLETION_PANEL_SIZE.y * 0.5
	passage_completion_panel.add_theme_stylebox_override("panel", _make_passage_completion_panel_style())
	$CanvasLayer/HUD.add_child(passage_completion_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 26)
	passage_completion_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)

	var title_label := _make_completion_label("Passage Granted", 36, Color(1.0, 0.88, 0.54, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(title_label)

	var subtitle_label := _make_completion_label(
		"The bargain holds. The ship slips past the deep.",
		17,
		Color(0.74, 0.88, 0.82, 0.96),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	stack.add_child(subtitle_label)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 26)
	stats_grid.add_theme_constant_override("v_separation", 7)
	stack.add_child(stats_grid)

	for row in _get_completion_rows():
		var key := str(row.get("key", ""))
		stats_grid.add_child(_make_completion_name_label(str(row.get("label", ""))))
		var value_label := _make_completion_value_label()
		passage_completion_value_labels[key] = value_label
		stats_grid.add_child(value_label)

	passage_completion_confirm_button = Button.new()
	passage_completion_confirm_button.name = "PassageCompleteConfirmButton"
	passage_completion_confirm_button.text = "Return to Main Menu"
	passage_completion_confirm_button.custom_minimum_size = Vector2(0.0, 48.0)
	passage_completion_confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	passage_completion_confirm_button.focus_mode = Control.FOCUS_ALL
	passage_completion_confirm_button.add_theme_font_override("font", UI_FONT)
	passage_completion_confirm_button.add_theme_font_size_override("font_size", 20)
	passage_completion_confirm_button.pressed.connect(_on_passage_completion_confirmed)
	stack.add_child(passage_completion_confirm_button)


func _make_passage_completion_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.026, 0.018, 0.95)
	style.border_color = Color(0.96, 0.78, 0.34, 0.76)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


func _get_completion_rows() -> Array:
	return RunStatsSystem.get_passage_completion_rows()


func _update_passage_completion_values() -> void:
	if table == null or table.run_stats_system == null:
		return

	var snapshot: Dictionary = table.run_stats_system.get_run_stats_snapshot()
	snapshot["kraken_favor_earned"] = int(passage_completion_progression_award.get("kraken_favor_earned", 0))
	if progression_system != null:
		snapshot["total_kraken_favor"] = int(progression_system.get_progression_snapshot().get("total_kraken_favor", 0))
	else:
		snapshot["total_kraken_favor"] = int(passage_completion_progression_award.get("total_kraken_favor", 0))
	for row in _get_completion_rows():
		var key := str(row.get("key", ""))
		var value_label: Label = passage_completion_value_labels.get(key) as Label
		if value_label == null:
			continue
		value_label.text = _format_completion_value(key, snapshot.get(key, 0))


func _make_completion_name_label(text: String) -> Label:
	return _make_completion_label(text, 18, Color(0.84, 0.83, 0.72, 0.96), HORIZONTAL_ALIGNMENT_LEFT)


func _make_completion_value_label() -> Label:
	var label := _make_completion_label("", 18, Color(1.0, 0.86, 0.36, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	label.custom_minimum_size = Vector2(170.0, 24.0)
	return label


func _make_completion_label(text: String, font_size: int, font_color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(320.0, 24.0)
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.88))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _format_completion_value(key: String, value: Variant) -> String:
	match key:
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


func _on_passage_completion_confirmed() -> void:
	if passage_completion_blocker != null:
		passage_completion_blocker.visible = false
	if passage_completion_panel != null:
		passage_completion_panel.visible = false
	_save_final_run_history()
	get_tree().paused = false
	var error_code: int = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if error_code != OK:
		passage_completion_in_progress = false
		get_tree().paused = true
		if passage_completion_blocker != null:
			passage_completion_blocker.visible = true
		if passage_completion_panel != null:
			passage_completion_panel.visible = true


func _toggle_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
