extends Control
class_name PauseMenu

signal resume_requested
signal debug_panel_toggled(panel_id: String, enabled: bool)
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

@onready var shade: ColorRect = $Shade
@onready var menu_panel: PanelContainer = $Shade/MenuPanel
@onready var resume_button: Button = $Shade/MenuPanel/Margin/VBox/ResumeButton
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_connect_debug_panel_toggles()
	_show_debug_tab()


func _retire_quartermaster_menu_ui() -> void:
	quartermaster_tab_button.visible = false
	quartermaster_tab_button.disabled = true
	quartermaster_section.visible = false
	debug_tab_button.visible = true
	debug_section.visible = true


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


func set_pause_visible(should_show: bool) -> void:
	visible = should_show
	if should_show:
		_show_debug_tab()
		resume_button.grab_focus()
	else:
		resume_button.release_focus()


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


func _show_debug_tab() -> void:
	quartermaster_section.visible = false
	debug_section.visible = true
	quartermaster_tab_button.disabled = true
	debug_tab_button.disabled = true


func _on_resume_pressed() -> void:
	resume_requested.emit()


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
