extends Node2D
class_name PocketStreakPresenter

# Presentation-only pocket wake-up effect for same-pocket scoring streaks.

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const EFFECT_DURATION := 1.05
const LABEL_SIZE := Vector2(138, 76)
const LABEL_FONT_SIZE := 48
const LABEL_COLOR := Color(1.0, 0.90, 0.28, 1.0)
const LABEL_OUTLINE_COLOR := Color(0.48, 0.25, 0.02, 0.98)
const LABEL_SHADOW_COLOR := Color(0.18, 0.08, 0.0, 0.86)
const GLOW_COLOR := Color(1.0, 0.72, 0.12, 0.50)
const SPARK_COLOR := Color(1.0, 0.95, 0.48, 0.84)
const EFFECT_LIFT := Vector2(0.0, -34.0)
const SPARK_COUNT := 9

class PocketStreakEffect:
	var label: Label
	var anchor_position := Vector2.ZERO
	var pocket_radius := 0.0
	var elapsed := 0.0
	var multiplier := 2
	var spin_offset := 0.0

var active_effects: Array[PocketStreakEffect] = []


func _ready() -> void:
	set_process(false)


func show_streak(multiplier: int, pocket_position: Vector2, pocket_radius: float) -> void:
	if multiplier < 2 or pocket_position == Vector2.ZERO:
		return

	var effect: PocketStreakEffect = PocketStreakEffect.new()
	effect.multiplier = multiplier
	effect.anchor_position = pocket_position
	effect.pocket_radius = maxf(pocket_radius, 32.0)
	effect.spin_offset = float((multiplier * 37) % 360) * PI / 180.0
	effect.label = _make_streak_label("X%s" % multiplier)
	effect.label.position = pocket_position - LABEL_SIZE * 0.5
	add_child(effect.label)
	active_effects.append(effect)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for effect_index in range(active_effects.size() - 1, -1, -1):
		var effect: PocketStreakEffect = active_effects[effect_index]
		if not is_instance_valid(effect.label):
			active_effects.remove_at(effect_index)
			continue

		effect.elapsed += delta
		_update_effect_label(effect)
		if effect.elapsed >= EFFECT_DURATION:
			effect.label.queue_free()
			active_effects.remove_at(effect_index)

	set_process(not active_effects.is_empty())
	queue_redraw()


func _draw() -> void:
	for effect in active_effects:
		_draw_effect_glow(effect)


func _make_streak_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size = LABEL_SIZE
	label.pivot_offset = LABEL_SIZE * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", LABEL_COLOR)
	label.add_theme_color_override("font_outline_color", LABEL_OUTLINE_COLOR)
	label.add_theme_color_override("font_shadow_color", LABEL_SHADOW_COLOR)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.modulate = Color(1, 1, 1, 0)
	label.scale = Vector2(0.62, 0.62)
	return label


func _update_effect_label(effect: PocketStreakEffect) -> void:
	var ratio: float = clampf(effect.elapsed / EFFECT_DURATION, 0.0, 1.0)
	var pop: float = sin(minf(ratio * PI * 1.35, PI))
	var fade: float = 1.0 - smoothstep(0.68, 1.0, ratio)
	var lift: Vector2 = EFFECT_LIFT * _ease_out_cubic(ratio)
	var settle_scale: float = lerpf(0.92, 1.05, pop)
	effect.label.position = effect.anchor_position - LABEL_SIZE * 0.5 + lift
	effect.label.scale = Vector2.ONE * settle_scale
	effect.label.rotation = sin(effect.elapsed * 9.0 + effect.spin_offset) * deg_to_rad(5.0)
	effect.label.modulate = Color(1.0, 1.0, 1.0, fade)


func _draw_effect_glow(effect: PocketStreakEffect) -> void:
	var ratio: float = clampf(effect.elapsed / EFFECT_DURATION, 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(0.62, 1.0, ratio)
	var pulse: float = sin(minf(ratio * PI * 1.25, PI))
	var center: Vector2 = effect.anchor_position + EFFECT_LIFT * 0.35 * _ease_out_cubic(ratio)
	var base_radius: float = effect.pocket_radius + 15.0 + pulse * 16.0
	var spin: float = effect.elapsed * 5.5 + effect.spin_offset

	var outer_glow: Color = GLOW_COLOR
	outer_glow.a *= fade * 0.52
	draw_arc(center, base_radius + 12.0, spin, spin + TAU * 0.86, 72, outer_glow, 9.0)

	var inner_glow: Color = GLOW_COLOR.lightened(0.18)
	inner_glow.a *= fade * 0.72
	draw_arc(center, base_radius, -spin * 0.85, -spin * 0.85 + TAU * 0.72, 72, inner_glow, 4.0)

	var sparkle_alpha: float = fade * (0.35 + pulse * 0.55)
	for spark_index in range(SPARK_COUNT):
		var spark_ratio: float = float(spark_index) / float(SPARK_COUNT)
		var angle: float = spin * 0.72 + spark_ratio * TAU
		var spark_radius: float = base_radius + 8.0 + sin(effect.elapsed * 8.0 + spark_ratio * TAU) * 8.0
		var spark_position: Vector2 = center + Vector2.RIGHT.rotated(angle) * spark_radius
		var spark_color: Color = SPARK_COLOR
		spark_color.a = sparkle_alpha * (0.55 + 0.45 * sin(effect.elapsed * 10.0 + spark_ratio * TAU))
		draw_circle(spark_position, 2.2 + pulse * 1.4, spark_color)


func _ease_out_cubic(value: float) -> float:
	var inverse: float = 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse
