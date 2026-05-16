extends Control
class_name PauseMenu

signal resume_requested
signal debug_panel_toggled(panel_id: String, enabled: bool)
signal quartermaster_offer_requested(offer_index: int)
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
const SHOP_BUTTON_AVAILABLE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const SHOP_BUTTON_BLOCKED_MODULATE := Color(0.74, 0.72, 0.64, 0.82)
const SHOP_BUTTON_UNAFFORDABLE_MODULATE := Color(0.58, 0.52, 0.46, 0.68)
const SHOP_REFRESH_FLASH_MODULATE := Color(1.0, 0.86, 0.38, 1.0)
const SHOP_REFRESH_POP_SCALE := Vector2(1.04, 1.04)
const SHOP_REFRESH_FADE_SECONDS := 0.24
const SHOP_REFRESH_SETTLE_SECONDS := 0.16

@onready var shade: ColorRect = $Shade
@onready var menu_panel: PanelContainer = $Shade/MenuPanel
@onready var resume_button: Button = $Shade/MenuPanel/Margin/VBox/ResumeButton
@onready var quartermaster_tab_button: Button = $Shade/MenuPanel/Margin/VBox/TabBar/QuartermasterTabButton
@onready var debug_tab_button: Button = $Shade/MenuPanel/Margin/VBox/TabBar/DebugTabButton
@onready var quartermaster_section: VBoxContainer = $Shade/MenuPanel/Margin/VBox/QuartermasterSection
@onready var debug_section: VBoxContainer = $Shade/MenuPanel/Margin/VBox/DebugSection
@onready var quartermaster_status_label: Label = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/QuartermasterStatusLabel
@onready var quartermaster_doubloons_label: Label = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/QuartermasterDoubloonsLabel
@onready var quartermaster_offer_button_0: Button = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/QuartermasterOfferButton0
@onready var quartermaster_offer_button_1: Button = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/QuartermasterOfferButton1
@onready var quartermaster_offer_button_2: Button = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/QuartermasterOfferButton2
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

var quartermaster_offer_buttons: Array = []
var quartermaster_offer_indexes: Array = []
var quartermaster_refresh_tweens: Dictionary = {}
var quartermaster_refresh_overlays: Dictionary = {}
var last_seen_stock_refresh_serial := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	placement_hint_panel.visible = false
	if not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if not quartermaster_tab_button.pressed.is_connected(_show_quartermaster_tab):
		quartermaster_tab_button.pressed.connect(_show_quartermaster_tab)
	if not debug_tab_button.pressed.is_connected(_show_debug_tab):
		debug_tab_button.pressed.connect(_show_debug_tab)
	_configure_quartermaster_offer_buttons()
	if not cancel_placement_button.pressed.is_connected(_on_cancel_placement_pressed):
		cancel_placement_button.pressed.connect(_on_cancel_placement_pressed)
	_connect_debug_panel_toggles()
	_show_quartermaster_tab()


func _connect_debug_panel_toggles() -> void:
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


func _configure_quartermaster_offer_buttons() -> void:
	quartermaster_offer_buttons = [
		quartermaster_offer_button_0,
		quartermaster_offer_button_1,
		quartermaster_offer_button_2,
	]
	quartermaster_offer_indexes = [-1, -1, -1]
	for offer_index in range(quartermaster_offer_buttons.size()):
		var button := quartermaster_offer_buttons[offer_index] as Button
		if button != null:
			_ensure_quartermaster_refresh_overlay(offer_index, button)
	if not quartermaster_offer_button_0.pressed.is_connected(_on_quartermaster_offer_0_pressed):
		quartermaster_offer_button_0.pressed.connect(_on_quartermaster_offer_0_pressed)
	if not quartermaster_offer_button_1.pressed.is_connected(_on_quartermaster_offer_1_pressed):
		quartermaster_offer_button_1.pressed.connect(_on_quartermaster_offer_1_pressed)
	if not quartermaster_offer_button_2.pressed.is_connected(_on_quartermaster_offer_2_pressed):
		quartermaster_offer_button_2.pressed.connect(_on_quartermaster_offer_2_pressed)


func set_pause_visible(should_show: bool) -> void:
	visible = should_show
	if should_show:
		_show_quartermaster_tab()
		resume_button.grab_focus()
	else:
		resume_button.release_focus()


func set_quartermaster_items(items: Array) -> void:
	_reset_quartermaster_item_buttons()
	if items.is_empty():
		quartermaster_status_label.text = "Quartermaster cargo unavailable"
		return

	quartermaster_doubloons_label.text = "Doubloons Available: %s" % _get_doubloons_available_from_items(items)
	var any_available := false
	var first_blocker := ""
	var refresh_serial := _get_stock_refresh_serial_from_items(items)
	var refreshed_offer_index := _get_last_refreshed_offer_index_from_items(items)
	var should_play_refresh_cue := refresh_serial > last_seen_stock_refresh_serial
	for item_value in items:
		var item: Dictionary = item_value
		var offer_index := int(item.get("offer_index", -1))
		var item_available := bool(item.get("available", false))
		any_available = any_available or item_available
		if first_blocker.is_empty() and not item_available:
			first_blocker = str(item.get("blocked_reason", "Unavailable"))
		if _is_valid_offer_button_index(offer_index):
			quartermaster_offer_indexes[offer_index] = offer_index
			var button := quartermaster_offer_buttons[offer_index] as Button
			if button != null:
				_apply_quartermaster_button_state(button, item)
				if should_play_refresh_cue and offer_index == refreshed_offer_index:
					_play_quartermaster_offer_refresh_cue(offer_index, button)

	quartermaster_status_label.text = "Quartermaster cargo ready." if any_available else first_blocker
	last_seen_stock_refresh_serial = max(last_seen_stock_refresh_serial, refresh_serial)


func _reset_quartermaster_item_buttons() -> void:
	quartermaster_offer_indexes = [-1, -1, -1]
	quartermaster_doubloons_label.text = "Doubloons Available: --"
	for offer_index in range(quartermaster_offer_buttons.size()):
		var button := quartermaster_offer_buttons[offer_index] as Button
		if button == null:
			continue
		button.text = "Offer %s" % (offer_index + 1)
		_reset_quartermaster_button_state(button)


func _apply_quartermaster_button_state(button: Button, item: Dictionary) -> void:
	var price := int(item.get("price", 0))
	var item_name := str(item.get("name", "Quartermaster Item"))
	var description := str(item.get("description", ""))
	var affordable := bool(item.get("affordable", false))
	var available := bool(item.get("available", false))
	button.text = "%s\nCost: %s Doubloons\n%s" % [item_name, price, description]
	button.tooltip_text = "%s\nCost: %s Doubloons\n%s" % [item_name, price, description]
	button.disabled = not available
	if not affordable:
		button.modulate = SHOP_BUTTON_UNAFFORDABLE_MODULATE
	elif not available:
		button.modulate = SHOP_BUTTON_BLOCKED_MODULATE
	else:
		button.modulate = SHOP_BUTTON_AVAILABLE_MODULATE


func _reset_quartermaster_button_state(button: Button) -> void:
	button.disabled = true
	button.tooltip_text = ""
	button.modulate = SHOP_BUTTON_BLOCKED_MODULATE
	button.scale = Vector2.ONE


func _get_doubloons_available_from_items(items: Array) -> int:
	if items.is_empty():
		return 0
	var first_item: Dictionary = items[0]
	return int(first_item.get("doubloons_available", 0))


func _get_stock_refresh_serial_from_items(items: Array) -> int:
	if items.is_empty():
		return 0
	var first_item: Dictionary = items[0]
	return int(first_item.get("stock_refresh_serial", 0))


func _get_last_refreshed_offer_index_from_items(items: Array) -> int:
	if items.is_empty():
		return -1
	var first_item: Dictionary = items[0]
	return int(first_item.get("last_refreshed_offer_index", -1))


func _play_quartermaster_offer_refresh_cue(offer_index: int, button: Button) -> void:
	if quartermaster_refresh_tweens.has(offer_index):
		var previous_tween := quartermaster_refresh_tweens[offer_index] as Tween
		if previous_tween != null:
			previous_tween.kill()

	_play_quartermaster_refresh_overlay(offer_index)
	var target_modulate := button.modulate
	button.pivot_offset = button.size * 0.5
	button.scale = SHOP_REFRESH_POP_SCALE
	button.modulate = SHOP_REFRESH_FLASH_MODULATE
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(button, "scale", Vector2.ONE, SHOP_REFRESH_SETTLE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", target_modulate, SHOP_REFRESH_FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_quartermaster_refresh_tween_finished.bind(offer_index))
	quartermaster_refresh_tweens[offer_index] = tween


func _on_quartermaster_refresh_tween_finished(offer_index: int) -> void:
	quartermaster_refresh_tweens.erase(offer_index)


func _ensure_quartermaster_refresh_overlay(offer_index: int, button: Button) -> void:
	if quartermaster_refresh_overlays.has(offer_index):
		return

	var overlay := QuartermasterOfferRefreshEffect.new()
	overlay.name = "StockRefreshEffect"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.z_index = 6
	button.add_child(overlay)
	quartermaster_refresh_overlays[offer_index] = overlay


func _play_quartermaster_refresh_overlay(offer_index: int) -> void:
	var overlay := quartermaster_refresh_overlays.get(offer_index) as QuartermasterOfferRefreshEffect
	if overlay == null:
		return
	overlay.play()


func set_quartermaster_status(text: String) -> void:
	quartermaster_status_label.text = text


func set_quartermaster_placement_mode(enabled: bool, item_name: String = "") -> void:
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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()


func _show_quartermaster_tab() -> void:
	quartermaster_section.visible = true
	debug_section.visible = false
	quartermaster_tab_button.disabled = true
	debug_tab_button.disabled = false


func _show_debug_tab() -> void:
	quartermaster_section.visible = false
	debug_section.visible = true
	quartermaster_tab_button.disabled = false
	debug_tab_button.disabled = true


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_quartermaster_offer_0_pressed() -> void:
	_request_quartermaster_offer(0)


func _on_quartermaster_offer_1_pressed() -> void:
	_request_quartermaster_offer(1)


func _on_quartermaster_offer_2_pressed() -> void:
	_request_quartermaster_offer(2)


func _request_quartermaster_offer(offer_index: int) -> void:
	if not _is_valid_offer_button_index(offer_index):
		return
	if int(quartermaster_offer_indexes[offer_index]) == -1:
		return
	quartermaster_offer_requested.emit(offer_index)


func _is_valid_offer_button_index(offer_index: int) -> bool:
	return offer_index >= 0 and offer_index < quartermaster_offer_buttons.size()


func _on_cancel_placement_pressed() -> void:
	quartermaster_cancel_placement_requested.emit()


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
