extends Control
class_name PauseMenu

signal resume_requested
signal debug_panel_toggled(panel_id: String, enabled: bool)
signal quartermaster_item_requested(item_id: String)
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
const NORMAL_SHADE_COLOR := Color(0.01, 0.012, 0.016, 0.62)
const PLACEMENT_SHADE_COLOR := Color(0.01, 0.012, 0.016, 0.18)
const SHOP_BUTTON_AVAILABLE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const SHOP_BUTTON_BLOCKED_MODULATE := Color(0.74, 0.72, 0.64, 0.82)
const SHOP_BUTTON_UNAFFORDABLE_MODULATE := Color(0.58, 0.52, 0.46, 0.68)

@onready var shade: ColorRect = $Shade
@onready var menu_panel: PanelContainer = $Shade/MenuPanel
@onready var resume_button: Button = $Shade/MenuPanel/Margin/VBox/ResumeButton
@onready var quartermaster_tab_button: Button = $Shade/MenuPanel/Margin/VBox/TabBar/QuartermasterTabButton
@onready var debug_tab_button: Button = $Shade/MenuPanel/Margin/VBox/TabBar/DebugTabButton
@onready var quartermaster_section: VBoxContainer = $Shade/MenuPanel/Margin/VBox/QuartermasterSection
@onready var debug_section: VBoxContainer = $Shade/MenuPanel/Margin/VBox/DebugSection
@onready var quartermaster_status_label: Label = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/QuartermasterStatusLabel
@onready var quartermaster_doubloons_label: Label = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/QuartermasterDoubloonsLabel
@onready var plain_object_ball_button: Button = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/PlainObjectBallButton
@onready var wayfinder_ball_button: Button = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/WayfinderBallButton
@onready var powder_keg_ball_button: Button = $Shade/MenuPanel/Margin/VBox/QuartermasterSection/PowderKegBallButton
@onready var placement_hint_panel: PanelContainer = $Shade/PlacementHintPanel
@onready var placement_hint_label: Label = $Shade/PlacementHintPanel/Margin/VBox/PlacementHintLabel
@onready var cancel_placement_button: Button = $Shade/PlacementHintPanel/Margin/VBox/CancelPlacementButton
@onready var core_performance_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/CorePerformancePanelCheckBox
@onready var aim_preview_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/AimPreviewPanelCheckBox
@onready var treasure_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/TreasurePanelCheckBox
@onready var anchor_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/AnchorPanelCheckBox
@onready var ball_drops_score_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/BallDropsScorePanelCheckBox
@onready var cannon_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/CannonPanelCheckBox
@onready var powder_keg_wayfinder_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/PowderKegWayfinderPanelCheckBox
@onready var visual_effects_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/VisualEffectsPanelCheckBox
@onready var physics_check_box: CheckBox = $Shade/MenuPanel/Margin/VBox/DebugSection/PhysicsPerformancePanelCheckBox

var plain_object_ball_item_id := ""
var wayfinder_ball_item_id := ""
var powder_keg_ball_item_id := ""


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
	if not plain_object_ball_button.pressed.is_connected(_on_plain_object_ball_pressed):
		plain_object_ball_button.pressed.connect(_on_plain_object_ball_pressed)
	if not wayfinder_ball_button.pressed.is_connected(_on_wayfinder_ball_pressed):
		wayfinder_ball_button.pressed.connect(_on_wayfinder_ball_pressed)
	if not powder_keg_ball_button.pressed.is_connected(_on_powder_keg_ball_pressed):
		powder_keg_ball_button.pressed.connect(_on_powder_keg_ball_pressed)
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
	for item_value in items:
		var item: Dictionary = item_value
		var item_id := str(item.get("id", ""))
		var item_available := bool(item.get("available", false))
		any_available = any_available or item_available
		if first_blocker.is_empty() and not item_available:
			first_blocker = str(item.get("blocked_reason", "Unavailable"))
		match item_id:
			"plain_object_ball":
				plain_object_ball_item_id = item_id
				_apply_quartermaster_button_state(plain_object_ball_button, item)
			"wayfinder_ball":
				wayfinder_ball_item_id = item_id
				_apply_quartermaster_button_state(wayfinder_ball_button, item)
			"powder_keg_ball":
				powder_keg_ball_item_id = item_id
				_apply_quartermaster_button_state(powder_keg_ball_button, item)

	quartermaster_status_label.text = "Quartermaster cargo ready." if any_available else first_blocker


func _reset_quartermaster_item_buttons() -> void:
	plain_object_ball_item_id = ""
	wayfinder_ball_item_id = ""
	powder_keg_ball_item_id = ""
	plain_object_ball_button.text = "Loose Object Ball"
	wayfinder_ball_button.text = "Wayfinder Ball"
	powder_keg_ball_button.text = "Powder Keg"
	quartermaster_doubloons_label.text = "Doubloons Available: --"
	_reset_quartermaster_button_state(plain_object_ball_button)
	_reset_quartermaster_button_state(wayfinder_ball_button)
	_reset_quartermaster_button_state(powder_keg_ball_button)


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


func _get_doubloons_available_from_items(items: Array) -> int:
	if items.is_empty():
		return 0
	var first_item: Dictionary = items[0]
	return int(first_item.get("doubloons_available", 0))


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


func _on_plain_object_ball_pressed() -> void:
	if plain_object_ball_item_id.is_empty():
		return
	quartermaster_item_requested.emit(plain_object_ball_item_id)


func _on_wayfinder_ball_pressed() -> void:
	if wayfinder_ball_item_id.is_empty():
		return
	quartermaster_item_requested.emit(wayfinder_ball_item_id)


func _on_powder_keg_ball_pressed() -> void:
	if powder_keg_ball_item_id.is_empty():
		return
	quartermaster_item_requested.emit(powder_keg_ball_item_id)


func _on_cancel_placement_pressed() -> void:
	quartermaster_cancel_placement_requested.emit()


func _on_core_performance_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_CORE_PERFORMANCE, enabled)


func _on_aim_preview_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_AIM_PREVIEW, enabled)


func _on_treasure_panel_toggled(enabled: bool) -> void:
	debug_panel_toggled.emit(PANEL_TREASURE, enabled)


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
