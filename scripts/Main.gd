extends Node2D

const FULLSCREEN_TOGGLE_KEY := KEY_F11
const PAUSE_TOGGLE_KEY := KEY_ESCAPE

@onready var table: BilliardsTable = $Table
@onready var debug_overlay: DebugOverlay = $CanvasLayer/HUD
@onready var pause_menu: PauseMenu = $CanvasLayer/HUD/PauseMenu
@onready var hud_feed: HudFeed = $CanvasLayer/HUD/HudFeed
@onready var result_label: Label = $CanvasLayer/HUD/ResultLabel
@onready var doubloons_label: Label = $CanvasLayer/HUD/DoubloonsLabel
@onready var table_event_meter: TableEventMeter = $CanvasLayer/HUD/TableEventMeter
@onready var table_event_menu: TableEventMenu = $CanvasLayer/HUD/TableEventMenu
@onready var reserve_slots_ui: ReserveSlotsUI = $CanvasLayer/HUD/ReserveSlotsUI
@onready var quartermaster_hud: QuartermasterHUD = $CanvasLayer/HUD/QuartermasterHUD
@onready var reserve_deployment_presenter: ReserveDeploymentPresenter = $CanvasLayer/HUD/ReserveDeploymentPresenter

var reserve_deployment_active := false
var reserve_deployment_previous_pause_state := false


func _ready() -> void:
	_configure_pause_process_modes()
	debug_overlay.visible = true
	table.status_text_changed.connect(_on_status_text_changed)
	table.game_finished.connect(_on_game_finished)
	table.score_system.doubloons_changed.connect(_on_doubloons_changed)
	table.score_system.score_feed_message.connect(_on_score_feed_message)
	table.table_event_system.status_changed.connect(_on_table_event_status_changed)
	table.table_event_system.event_purchased.connect(_on_table_event_purchased)
	table.quartermaster_system.shop_state_changed.connect(_on_quartermaster_shop_state_changed)
	table.quartermaster_system.status_changed.connect(_on_quartermaster_status_changed)
	table.quartermaster_system.placement_started.connect(_on_quartermaster_placement_started)
	table.quartermaster_system.placement_finished.connect(_on_quartermaster_placement_finished)
	table.reserve_system.reserve_slots_changed.connect(_on_reserve_slots_changed)
	table.reserve_system.deployment_finished.connect(_on_reserve_deployment_finished)
	table.reserve_system.deployment_blocked.connect(_on_reserve_deployment_blocked)
	if not reserve_slots_ui.reserve_slot_clicked.is_connected(_on_reserve_slot_clicked):
		reserve_slots_ui.reserve_slot_clicked.connect(_on_reserve_slot_clicked)
	if not pause_menu.resume_requested.is_connected(_on_pause_resume_requested):
		pause_menu.resume_requested.connect(_on_pause_resume_requested)
	if not pause_menu.debug_panel_toggled.is_connected(_on_pause_debug_panel_toggled):
		pause_menu.debug_panel_toggled.connect(_on_pause_debug_panel_toggled)
	if not pause_menu.quartermaster_cancel_placement_requested.is_connected(_on_pause_quartermaster_cancel_placement_requested):
		pause_menu.quartermaster_cancel_placement_requested.connect(_on_pause_quartermaster_cancel_placement_requested)
	if not quartermaster_hud.quartermaster_offer_requested.is_connected(_on_quartermaster_hud_offer_requested):
		quartermaster_hud.quartermaster_offer_requested.connect(_on_quartermaster_hud_offer_requested)
	if not table_event_meter.event_icon_clicked.is_connected(_on_table_event_icon_clicked):
		table_event_meter.event_icon_clicked.connect(_on_table_event_icon_clicked)
	if not table_event_menu.event_offer_selected.is_connected(_on_table_event_offer_selected):
		table_event_menu.event_offer_selected.connect(_on_table_event_offer_selected)
	result_label.text = ""
	_on_doubloons_changed(table.score_system.get_doubloons_total())
	table_event_meter.setup(table.table_event_system, table)
	table_event_menu.setup(table.table_event_system)
	reserve_slots_ui.setup(table.reserve_system, table)
	quartermaster_hud.setup(table.quartermaster_system, table)
	reserve_deployment_presenter.setup(table.reserve_system, reserve_slots_ui)
	table.emit_ready_status_if_needed("")
	debug_overlay.setup(table)
	pause_menu.set_debug_panel_states(debug_overlay.get_modular_debug_panel_states())
	quartermaster_hud.set_quartermaster_items(table.quartermaster_system.get_shop_items_snapshot())


func _configure_pause_process_modes() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	table.process_mode = Node.PROCESS_MODE_PAUSABLE
	debug_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_feed.process_mode = Node.PROCESS_MODE_ALWAYS
	reserve_slots_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	quartermaster_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	reserve_deployment_presenter.process_mode = Node.PROCESS_MODE_ALWAYS
	table_event_meter.process_mode = Node.PROCESS_MODE_ALWAYS
	table_event_menu.process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == PAUSE_TOGGLE_KEY:
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


func _on_table_event_purchased(_event_id: String, _cost: int) -> void:
	table_event_menu.close_menu()


func _on_pause_resume_requested() -> void:
	_set_game_paused(false)


func _on_pause_debug_panel_toggled(panel_id: String, enabled: bool) -> void:
	debug_overlay.set_modular_debug_panel_visible(panel_id, enabled)


func _on_quartermaster_hud_offer_requested(offer_index: int) -> void:
	table.quartermaster_system.request_purchase_offer(offer_index)


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


func _on_quartermaster_shop_state_changed(items: Array) -> void:
	quartermaster_hud.set_quartermaster_items(items)


func _on_quartermaster_status_changed(text: String) -> void:
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
		table.cancel_active_cue_drag_for_pause()
		get_tree().paused = true
		pause_menu.set_pause_visible(true)
		quartermaster_hud.set_quartermaster_items(table.quartermaster_system.get_shop_items_snapshot())
	else:
		if table.is_ball_placement_active():
			table.cancel_active_ball_placement()
		pause_menu.set_pause_visible(false)
		get_tree().paused = false


func _toggle_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
