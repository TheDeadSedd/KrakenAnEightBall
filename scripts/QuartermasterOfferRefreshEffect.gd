extends Control
class_name QuartermasterOfferRefreshEffect

# Presentation-only stock arrival cue for a single Quartermaster offer button.
# It draws a soft glow and a quick light sweep; it never owns shop state.
const EFFECT_SECONDS: float = 0.58
const GLOW_CORNER_RADIUS: int = 12
const GLOW_BASE_COLOR: Color = Color(1.0, 0.74, 0.22, 1.0)
const GLOW_EDGE_COLOR: Color = Color(1.0, 0.86, 0.42, 1.0)
const SWEEP_COLOR: Color = Color(1.0, 0.92, 0.58, 1.0)
const SWEEP_WIDTH_RATIO: float = 0.24
const SWEEP_SOFT_WIDTH_RATIO: float = 0.16

var elapsed: float = 0.0
var active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	visible = false


func play() -> void:
	elapsed = 0.0
	active = true
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return

	elapsed += delta
	if elapsed >= EFFECT_SECONDS:
		active = false
		visible = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if not active:
		return

	var progress: float = clampf(elapsed / EFFECT_SECONDS, 0.0, 1.0)
	var slot_rect: Rect2 = Rect2(Vector2.ZERO, size)
	_draw_soft_gold_glow(slot_rect, progress)
	_draw_shimmer_sweep(slot_rect, progress)


func _draw_soft_gold_glow(slot_rect: Rect2, progress: float) -> void:
	var pulse: float = sin(progress * PI)
	var fade: float = 1.0 - smoothstep(0.68, 1.0, progress)
	var alpha: float = pulse * fade
	if alpha <= 0.01:
		return

	var glow_layers: Array[Dictionary] = [
		{"outset": 11.0, "alpha": 0.08, "border": 0},
		{"outset": 7.0, "alpha": 0.13, "border": 1},
		{"outset": 3.0, "alpha": 0.18, "border": 1},
	]
	for layer: Dictionary in glow_layers:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		var layer_alpha: float = alpha * float(layer["alpha"])
		style.bg_color = _with_alpha(GLOW_BASE_COLOR, layer_alpha)
		style.border_color = _with_alpha(GLOW_EDGE_COLOR, layer_alpha * 1.45)
		var border_width: int = int(layer["border"])
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		_apply_corner_radius(style)
		draw_style_box(style, slot_rect.grow(float(layer["outset"])))


func _draw_shimmer_sweep(slot_rect: Rect2, progress: float) -> void:
	var sweep_alpha: float = sin(progress * PI) * (1.0 - smoothstep(0.82, 1.0, progress))
	if sweep_alpha <= 0.01:
		return

	var travel_start: float = slot_rect.position.x - slot_rect.size.x * 0.45
	var travel_end: float = slot_rect.end.x + slot_rect.size.x * 0.20
	var center_x: float = lerpf(travel_start, travel_end, progress)
	var core_width: float = maxf(float(slot_rect.size.x) * SWEEP_WIDTH_RATIO, 18.0)
	var soft_width: float = maxf(float(slot_rect.size.x) * SWEEP_SOFT_WIDTH_RATIO, 12.0)

	_draw_sweep_band(slot_rect, center_x, core_width + soft_width, sweep_alpha * 0.10)
	_draw_sweep_band(slot_rect, center_x, core_width, sweep_alpha * 0.18)
	_draw_sweep_band(slot_rect, center_x, core_width * 0.36, sweep_alpha * 0.26)


func _draw_sweep_band(slot_rect: Rect2, center_x: float, width: float, alpha: float) -> void:
	var left: float = clampf(center_x - width * 0.5, slot_rect.position.x, slot_rect.end.x)
	var right: float = clampf(center_x + width * 0.5, slot_rect.position.x, slot_rect.end.x)
	if right <= left:
		return

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = _with_alpha(SWEEP_COLOR, alpha)
	style.border_color = Color(0.0, 0.0, 0.0, 0.0)
	_apply_corner_radius(style)
	draw_style_box(style, Rect2(Vector2(left, slot_rect.position.y), Vector2(right - left, slot_rect.size.y)))


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))


func _apply_corner_radius(style: StyleBoxFlat) -> void:
	style.corner_radius_top_left = GLOW_CORNER_RADIUS
	style.corner_radius_top_right = GLOW_CORNER_RADIUS
	style.corner_radius_bottom_left = GLOW_CORNER_RADIUS
	style.corner_radius_bottom_right = GLOW_CORNER_RADIUS
