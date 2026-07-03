extends Control
class_name SunkenSpoilsHUD

# Compact display-only Sunken Spoils progress badge. SunkenSpoilsSystem owns
# milestone state and rewards; this node only mirrors its snapshot.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const PANEL_WIDTH := 178.0
const PANEL_HEIGHT := 48.0
const HUD_RIGHT_MARGIN := 92.0
const HUD_TOP := 632.0
const VIEWPORT_MARGIN := 24.0
const PADDING_X := 10.0
const TITLE_FONT_SIZE := 14
const VALUE_FONT_SIZE := 16

const PANEL_FILL := Color(0.034, 0.023, 0.016, 0.66)
const PANEL_BORDER := Color(0.96, 0.78, 0.34, 0.46)
const READY_BORDER := Color(0.45, 0.92, 0.82, 0.72)
const TITLE_COLOR := Color(1.0, 0.84, 0.46, 0.96)
const VALUE_COLOR := Color(0.84, 0.94, 0.88, 0.98)
const READY_COLOR := Color(0.52, 0.98, 0.86, 1.0)
const SHADOW_COLOR := Color(0.03, 0.016, 0.006, 0.86)

var sunken_spoils_system: SunkenSpoilsSystem
var spoils_snapshot: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 24
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	_apply_anchor()


func setup(system: SunkenSpoilsSystem) -> void:
	if sunken_spoils_system != null and sunken_spoils_system.spoils_changed.is_connected(_on_spoils_changed):
		sunken_spoils_system.spoils_changed.disconnect(_on_spoils_changed)

	sunken_spoils_system = system
	if sunken_spoils_system == null:
		set_spoils_snapshot({})
		return

	if not sunken_spoils_system.spoils_changed.is_connected(_on_spoils_changed):
		sunken_spoils_system.spoils_changed.connect(_on_spoils_changed)
	set_spoils_snapshot(sunken_spoils_system.get_spoils_snapshot())


func set_spoils_snapshot(snapshot: Dictionary) -> void:
	spoils_snapshot = snapshot.duplicate(true)
	visible = not spoils_snapshot.is_empty()
	_apply_anchor()
	queue_redraw()


func set_hover_ui_suppressed(_suppressed: bool) -> void:
	# Display-only badge, no hover UI.
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_anchor()


func _draw() -> void:
	if spoils_snapshot.is_empty():
		return

	var is_ready: bool = bool(spoils_snapshot.get("pending_reward_ready", false))
	var panel_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(PANEL_WIDTH, PANEL_HEIGHT))
	draw_style_box(_make_panel_style(is_ready), panel_rect)

	_draw_text("SUNKEN SPOILS", Vector2(PADDING_X, 18.0), TITLE_COLOR, TITLE_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - PADDING_X * 2.0)
	var value_text: String = _get_value_text()
	var value_color: Color = READY_COLOR if is_ready else VALUE_COLOR
	_draw_text(value_text, Vector2(PADDING_X, 38.0), value_color, VALUE_FONT_SIZE, HORIZONTAL_ALIGNMENT_LEFT, PANEL_WIDTH - PADDING_X * 2.0)


func _get_value_text() -> String:
	if bool(spoils_snapshot.get("pending_reward_ready", false)):
		return "Spoils Ready"
	var progress: int = maxi(int(spoils_snapshot.get("current_milestone_progress", 0)), 0)
	var required: int = maxi(int(spoils_snapshot.get("current_milestone_required", 1)), 1)
	return "Spoils: %s / %s" % [progress, required]


func _draw_text(text: String, position: Vector2, color: Color, font_size: int, alignment: HorizontalAlignment, width: float) -> void:
	draw_string(UI_FONT, position + Vector2(1.5, 1.5), text, alignment, width, font_size, SHADOW_COLOR)
	draw_string(UI_FONT, position, text, alignment, width, font_size, color)


func _apply_anchor() -> void:
	var panel_size: Vector2 = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	var viewport_size: Vector2 = get_viewport_rect().size
	var right_margin: float = minf(
		HUD_RIGHT_MARGIN,
		maxf(VIEWPORT_MARGIN, viewport_size.x - panel_size.x - VIEWPORT_MARGIN)
	)
	var top_offset: float = minf(
		HUD_TOP,
		maxf(VIEWPORT_MARGIN, viewport_size.y - panel_size.y - VIEWPORT_MARGIN)
	)

	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -right_margin - panel_size.x
	offset_right = -right_margin
	offset_top = top_offset
	offset_bottom = top_offset + panel_size.y
	custom_minimum_size = panel_size
	size = panel_size


func _make_panel_style(is_ready: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = READY_BORDER if is_ready else PANEL_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _on_spoils_changed(snapshot: Dictionary) -> void:
	set_spoils_snapshot(snapshot)
