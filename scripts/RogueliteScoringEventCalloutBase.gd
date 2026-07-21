extends Control
class_name RogueliteScoringEventCalloutBase

signal finished(callout)

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const CALLOUT_SIZE := Vector2(320.0, 100.0)
const TITLE_FONT_SIZES := [27, 31, 36]
const EFFECT_FONT_SIZES := [18, 20, 22]
const QUIET_TITLE_FONT_SIZE := 21
const QUIET_EFFECT_FONT_SIZE := 16

var title_glow_label: Label
var title_label: Label
var effect_glow_label: Label
var effect_label: Label
var true_source_screen_position := Vector2.ZERO
var accent_color := Color("e2dcc8")
var event_metadata: Dictionary = {}
var local_source_flashes := true
var effect_line_visible := false
var quiet_treatment := false
var visual_emphasis := 1.0
var presentation_tween: Tween
var pulse_tween: Tween
var flash_strength := 0.0:
	set(value):
		flash_strength = value
		_update_glyph_glow()
		queue_redraw()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = CALLOUT_SIZE
	custom_minimum_size = CALLOUT_SIZE
	z_as_relative = false
	z_index = 53
	_build_labels()


func configure_event_callout(
	metadata: Dictionary,
	center: Vector2,
	true_source: Vector2,
	title: String,
	effect_text: String = "",
	flashes_enabled: bool = true,
	quiet: bool = false
) -> void:
	if title_label == null:
		_build_labels()
	event_metadata = metadata.duplicate(true)
	position = center - CALLOUT_SIZE * 0.5
	true_source_screen_position = true_source
	local_source_flashes = flashes_enabled
	quiet_treatment = quiet
	effect_line_visible = not effect_text.is_empty()
	accent_color = _event_accent_color(event_metadata)
	visual_emphasis = _event_visual_emphasis(event_metadata)
	_configure_label_layout()
	_set_label_text(title, effect_text)
	_apply_label_style()
	queue_redraw()


func play(duration: float = 0.72, emphasis: float = 1.0) -> void:
	if presentation_tween != null and presentation_tween.is_valid():
		presentation_tween.kill()
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	pivot_offset = CALLOUT_SIZE * 0.5
	modulate = Color.WHITE
	var combined_emphasis: float = clampf(emphasis * visual_emphasis, 0.62, 1.72)
	var start_scale: float = 0.88 if quiet_treatment else 0.76
	var peak_scale: float = (
		1.025 + combined_emphasis * 0.025
		if quiet_treatment
		else 1.035 + combined_emphasis * 0.055
	)
	scale = Vector2.ONE * start_scale
	flash_strength = combined_emphasis
	var hold_duration: float = clampf(duration, 0.40, 1.20)
	pulse_tween = create_tween()
	pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	pulse_tween.tween_property(self, "scale", Vector2.ONE * peak_scale, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	presentation_tween = create_tween()
	presentation_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	presentation_tween.set_parallel(true)
	presentation_tween.tween_property(self, "flash_strength", 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	presentation_tween.tween_property(
		self,
		"position:y",
		position.y - (8.0 if quiet_treatment else 13.0),
		hold_duration
	)
	presentation_tween.tween_property(self, "modulate:a", 0.0, 0.20).set_delay(
		maxf(hold_duration - 0.20, 0.08)
	)
	presentation_tween.finished.connect(_finish)


func finish_immediately() -> void:
	if presentation_tween != null and presentation_tween.is_valid():
		presentation_tween.kill()
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	_finish()


func _draw() -> void:
	var halo_center: Vector2 = Vector2(CALLOUT_SIZE.x * 0.5, 45.0 if effect_line_visible else 50.0)
	if local_source_flashes:
		var tier: int = clampi(int(event_metadata.get("tier_index", 0)), 0, 2)
		var ring_count: int = 3 if quiet_treatment else 4 + tier
		var base_alpha: float = (0.075 if quiet_treatment else 0.14) * flash_strength
		for ring_index in range(ring_count):
			var ring_progress: float = float(ring_index) / float(maxi(ring_count - 1, 1))
			var radius: float = 20.0 + ring_progress * (38.0 + visual_emphasis * 12.0)
			var alpha: float = base_alpha * (1.0 - ring_progress * 0.76)
			draw_circle(
				halo_center,
				radius,
				Color(accent_color.r, accent_color.g, accent_color.b, alpha),
				false,
				lerpf(3.2, 1.4, ring_progress)
			)
	var local_source: Vector2 = true_source_screen_position - position
	var displacement: Vector2 = local_source - halo_center
	if displacement.length() > 112.0:
		var start: Vector2 = halo_center + displacement.normalized() * 90.0
		var line_alpha: float = 0.32 if quiet_treatment else 0.56
		draw_line(
			start,
			local_source,
			Color(accent_color.r, accent_color.g, accent_color.b, line_alpha),
			1.5
		)
		draw_circle(
			local_source,
			4.0,
			Color(accent_color.r, accent_color.g, accent_color.b, line_alpha + 0.22),
			false,
			2.0
		)


func _build_labels() -> void:
	if title_label != null:
		return
	title_glow_label = _make_label("TitleGlow")
	title_label = _make_label("Title")
	effect_glow_label = _make_label("EffectGlow")
	effect_label = _make_label("Effect")
	add_child(title_glow_label)
	add_child(title_label)
	add_child(effect_glow_label)
	add_child(effect_label)
	_configure_label_layout()


func _make_label(label_name: String) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	return label


func _configure_label_layout() -> void:
	var title_position := Vector2(8.0, 6.0 if effect_line_visible else 12.0)
	var title_size := Vector2(CALLOUT_SIZE.x - 16.0, 49.0 if effect_line_visible else 72.0)
	var effect_position := Vector2(10.0, 54.0)
	var effect_size := Vector2(CALLOUT_SIZE.x - 20.0, 32.0)
	for label in [title_glow_label, title_label]:
		label.position = title_position
		label.size = title_size
	for label in [effect_glow_label, effect_label]:
		label.position = effect_position
		label.size = effect_size
		label.visible = effect_line_visible


func _set_label_text(title: String, effect_text: String) -> void:
	title_glow_label.text = title
	title_label.text = title
	effect_glow_label.text = effect_text
	effect_label.text = effect_text


func _apply_label_style() -> void:
	var tier: int = clampi(int(event_metadata.get("tier_index", 0)), 0, 2)
	var title_font_size: int = QUIET_TITLE_FONT_SIZE if quiet_treatment else TITLE_FONT_SIZES[tier]
	var effect_font_size: int = QUIET_EFFECT_FONT_SIZE if quiet_treatment else EFFECT_FONT_SIZES[tier]
	var outline_size: int = 4 if quiet_treatment else 5 + tier
	var effect_outline_size: int = 3 if quiet_treatment else 4 + mini(tier, 1)
	_apply_main_glyph_style(title_label, title_font_size, accent_color, outline_size)
	_apply_main_glyph_style(
		effect_label,
		effect_font_size,
		accent_color.lightened(0.16),
		effect_outline_size
	)
	_apply_glow_glyph_style(title_glow_label, title_font_size, outline_size + 5)
	_apply_glow_glyph_style(effect_glow_label, effect_font_size, effect_outline_size + 4)
	_update_glyph_glow()


func _apply_main_glyph_style(label: Label, font_size: int, color: Color, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.008, 0.01, 0.016, 0.98))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.94))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 2)


func _apply_glow_glyph_style(label: Label, font_size: int, outline_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", accent_color)
	label.add_theme_color_override("font_outline_color", accent_color)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)


func _update_glyph_glow() -> void:
	if title_glow_label == null:
		return
	var resting_alpha: float = 0.035 if quiet_treatment else 0.07
	var pulse_alpha: float = (0.10 if quiet_treatment else 0.23) * flash_strength
	var glow_alpha: float = clampf(resting_alpha + pulse_alpha, 0.0, 0.42)
	title_glow_label.modulate = Color(1.0, 1.0, 1.0, glow_alpha)
	effect_glow_label.modulate = Color(1.0, 1.0, 1.0, glow_alpha * 0.82)


func _event_accent_color(metadata: Dictionary) -> Color:
	if bool(metadata.get("is_subtotal", false)):
		return Color("b9aa83")
	var event_type: String = str(metadata.get("event_type", ""))
	match event_type:
		"combination":
			return Color("d9a2ff")
		"pocket", "additional_ball":
			return Color("f2c45f")
		"rail_milestone", "rail_group":
			var tier: int = clampi(int(metadata.get("tier_index", 0)), 0, 2)
			return [Color("87ded1"), Color("79d8ef"), Color("fff0a8")][tier]
		"xmult", "modifier":
			return Color("d9a2ff")
		"scratch", "consequence":
			return Color("ef8477")
	var source_id: String = str(metadata.get("source_id", ""))
	if source_id in ["base_object_ball_value", "base_additional_ball"]:
		return Color("f2c45f")
	if source_id in ["base_bank_rail"]:
		return Color("87ded1")
	if source_id in ["base_combination"]:
		return Color("d9a2ff")
	if source_id == "scratch":
		return Color("ef8477")
	var effect_text: String = str(metadata.get("effect_text", ""))
	if effect_text.begins_with("x"):
		return Color("d9a2ff")
	if effect_text.contains("HAUL"):
		return Color("f2c45f")
	if effect_text.contains("MULT"):
		return Color("87ded1")
	return Color("e2dcc8")


func _event_visual_emphasis(metadata: Dictionary) -> float:
	if bool(metadata.get("is_subtotal", false)):
		return 0.72
	var tier: int = clampi(int(metadata.get("tier_index", 0)), 0, 2)
	var tier_emphasis: float = [0.92, 1.08, 1.28][tier]
	var excitement: float = clampf(float(metadata.get(
		"replay_excitement",
		metadata.get("global_excitement_normalized", 0.0)
	)), 0.0, 1.0)
	var identity_bonus: float = 0.0
	if bool(metadata.get("is_combination", false)):
		identity_bonus += 0.08
	if bool(metadata.get("is_pocket", false)):
		identity_bonus += 0.06
	if bool(metadata.get("is_final_tier", false)):
		identity_bonus += 0.10
	return clampf(tier_emphasis + excitement * 0.24 + identity_bonus, 0.70, 1.58)


func _finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit(self)
	queue_free()
