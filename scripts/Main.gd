extends Node2D

const FULLSCREEN_TOGGLE_KEY := KEY_F11
const PAUSE_TOGGLE_KEY := KEY_ESCAPE
const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const COMPLETION_PANEL_SIZE := Vector2(620.0, 710.0)

@onready var table: BilliardsTable = $Table
@onready var run_history_system: RunHistorySystem = $RunHistorySystem
@onready var progression_system: ProgressionSystem = $ProgressionSystem
@onready var debug_overlay: DebugOverlay = $CanvasLayer/HUD
@onready var pause_menu: PauseMenu = $CanvasLayer/HUD/PauseMenu
@onready var hud_feed: HudFeed = $CanvasLayer/HUD/HudFeed
@onready var result_label: Label = $CanvasLayer/HUD/ResultLabel
@onready var doubloons_label: Label = $CanvasLayer/HUD/DoubloonsLabel
@onready var run_ledger_hud: RunLedgerHUD = $CanvasLayer/HUD/RunLedgerHUD
@onready var run_stats_hud: RunStatsHUD = $CanvasLayer/HUD/RunStatsHUD
@onready var passage_hud: PassageHUD = $CanvasLayer/HUD/PassageHUD
@onready var oath_hud: OathHUD = $CanvasLayer/HUD/OathHUD
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


func _ready() -> void:
	_configure_pause_process_modes()
	debug_overlay.visible = true
	table.status_text_changed.connect(_on_status_text_changed)
	table.game_finished.connect(_on_game_finished)
	table.score_system.doubloons_changed.connect(_on_doubloons_changed)
	table.score_system.score_feed_message.connect(_on_score_feed_message)
	table.table_event_system.status_changed.connect(_on_table_event_status_changed)
	table.table_event_system.event_purchased.connect(_on_table_event_purchased)
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
	if not reserve_slots_ui.reserve_slot_clicked.is_connected(_on_reserve_slot_clicked):
		reserve_slots_ui.reserve_slot_clicked.connect(_on_reserve_slot_clicked)
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
	if not pause_menu.quartermaster_cancel_placement_requested.is_connected(_on_pause_quartermaster_cancel_placement_requested):
		pause_menu.quartermaster_cancel_placement_requested.connect(_on_pause_quartermaster_cancel_placement_requested)
	if not quartermaster_hud.quartermaster_offer_requested.is_connected(_on_quartermaster_hud_offer_requested):
		quartermaster_hud.quartermaster_offer_requested.connect(_on_quartermaster_hud_offer_requested)
	if not quartermaster_hud.quartermaster_refresh_requested.is_connected(_on_quartermaster_hud_refresh_requested):
		quartermaster_hud.quartermaster_refresh_requested.connect(_on_quartermaster_hud_refresh_requested)
	if not quartermaster_hud.back_room_deal_option_requested.is_connected(_on_quartermaster_hud_back_room_deal_option_requested):
		quartermaster_hud.back_room_deal_option_requested.connect(_on_quartermaster_hud_back_room_deal_option_requested)
	if not passage_hud.request_reroll_requested.is_connected(_on_passage_hud_request_reroll_requested):
		passage_hud.request_reroll_requested.connect(_on_passage_hud_request_reroll_requested)
	if not table_event_meter.event_icon_clicked.is_connected(_on_table_event_icon_clicked):
		table_event_meter.event_icon_clicked.connect(_on_table_event_icon_clicked)
	if not table_event_menu.event_offer_selected.is_connected(_on_table_event_offer_selected):
		table_event_menu.event_offer_selected.connect(_on_table_event_offer_selected)
	if not table_event_menu.event_offer_replace_requested.is_connected(_on_table_event_offer_replace_requested):
		table_event_menu.event_offer_replace_requested.connect(_on_table_event_offer_replace_requested)
	result_label.text = ""
	_on_doubloons_changed(table.score_system.get_doubloons_total())
	table_event_meter.setup(table.table_event_system, table)
	table_event_menu.setup(table.table_event_system)
	run_ledger_hud.setup(table)
	run_stats_hud.setup(table.run_stats_system)
	passage_hud.setup(table.passage_system)
	oath_hud.setup(table.oath_system)
	_on_run_stats_changed(table.run_stats_system.get_run_stats_snapshot())
	reserve_slots_ui.setup(table.reserve_system, table)
	quartermaster_hud.setup(table.quartermaster_system, table)
	reserve_deployment_presenter.setup(table.reserve_system, reserve_slots_ui)
	table.emit_ready_status_if_needed("")
	debug_overlay.setup(table)
	pause_menu.set_debug_panel_states(debug_overlay.get_modular_debug_panel_states())
	pause_menu.set_debris_collision_debug_state(table.table_obstacle_system.obstacle_collision_enabled)
	pause_menu.set_debris_collision_draw_debug_state(table.table_obstacle_system.debug_collision_draw_enabled)
	quartermaster_hud.set_quartermaster_items(table.quartermaster_system.get_shop_items_snapshot())
	quartermaster_hud.set_back_room_deal_snapshot(table.back_room_deal_system.get_deal_snapshot())


func _configure_pause_process_modes() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	table.process_mode = Node.PROCESS_MODE_PAUSABLE
	debug_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_feed.process_mode = Node.PROCESS_MODE_ALWAYS
	reserve_slots_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	quartermaster_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	reserve_deployment_presenter.process_mode = Node.PROCESS_MODE_ALWAYS
	run_ledger_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	run_stats_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	passage_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	oath_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	table_event_meter.process_mode = Node.PROCESS_MODE_ALWAYS
	table_event_menu.process_mode = Node.PROCESS_MODE_ALWAYS


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
		if table.is_ball_placement_active():
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


func _on_game_finished(text: String) -> void:
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


func _on_table_event_icon_clicked() -> void:
	table_event_menu.open_menu()


func _on_table_event_offer_selected(offer_index: int) -> void:
	table.table_event_system.request_purchase_offer(offer_index)


func _on_table_event_offer_replace_requested(offer_index: int) -> void:
	table.table_event_system.request_reroll_offer_with_oath(offer_index)


func _on_table_event_purchased(_event_id: String, _cost: int) -> void:
	table_event_menu.close_menu()


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
	var obstacle := table.table_obstacle_system.debug_spawn_wood_debris()
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


func _on_quartermaster_hud_offer_requested(offer_index: int) -> void:
	table.quartermaster_system.request_purchase_offer(offer_index)


func _on_quartermaster_hud_refresh_requested() -> void:
	table.quartermaster_system.request_refresh_stock()


func _on_quartermaster_hud_back_room_deal_option_requested(item_id: String) -> void:
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
		quartermaster_hud.set_back_room_deal_snapshot(table.back_room_deal_system.get_deal_snapshot())


func _on_quartermaster_shop_state_changed(items: Array) -> void:
	quartermaster_hud.set_quartermaster_items(items)


func _on_quartermaster_status_changed(text: String) -> void:
	hud_feed.add_message(text, "shop")


func _on_back_room_deal_state_changed(snapshot: Dictionary) -> void:
	if quartermaster_hud != null:
		quartermaster_hud.set_back_room_deal_snapshot(snapshot)


func _on_back_room_deal_status_changed(text: String) -> void:
	hud_feed.add_message(text, "shop")


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


func _get_completion_rows() -> Array[Dictionary]:
	return [
		{"label": "Shots Taken", "key": "shots_taken"},
		{"label": "Doubloons Earned", "key": "doubloons_earned"},
		{"label": "Doubloons Lost", "key": "doubloons_lost"},
		{"label": "Balls Sunk", "key": "balls_sunk"},
		{"label": "Highest Pocket Streak", "key": "highest_pocket_streak"},
		{"label": "Interventions Triggered", "key": "interventions_triggered"},
		{"label": "Contraband Found", "key": "contraband_found"},
		{"label": "Treasure Claimed", "key": "treasure_claimed"},
		{"label": "Kraken Favor Earned", "key": "kraken_favor_earned"},
		{"label": "Total Kraken Favor", "key": "total_kraken_favor"},
		{"label": "Final Ball Count", "key": "current_ball_count"},
		{"label": "Run Duration", "key": "run_time_seconds"},
	]


func _update_passage_completion_values() -> void:
	if table == null or table.run_stats_system == null:
		return

	var snapshot := table.run_stats_system.get_run_stats_snapshot()
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
