extends Node2D
class_name PocketStreakPresenter

# Presentation-only pocket wake-up effect for same-pocket scoring streaks.

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const EFFECT_DURATION := 1.05
const EFFECT_DURATION_X3 := 1.22
const EFFECT_DURATION_X4_PLUS := 1.42
const PRESENTATION_MIN_DISPLAY_TIME := 0.30
const LABEL_SIZE := Vector2(138, 76)
const LABEL_FONT_SIZE := 48
const LABEL_COLOR := Color(1.0, 0.90, 0.28, 1.0)
const LABEL_CURSED_COLOR := Color(1.0, 0.94, 0.44, 1.0)
const LABEL_OUTLINE_COLOR := Color(0.48, 0.25, 0.02, 0.98)
const LABEL_CURSED_OUTLINE_COLOR := Color(0.24, 0.12, 0.30, 0.98)
const LABEL_SHADOW_COLOR := Color(0.18, 0.08, 0.0, 0.86)
const GLOW_COLOR := Color(1.0, 0.72, 0.12, 0.50)
const WHIRL_COLOR := Color(0.46, 0.22, 0.72, 0.34)
const WHIRL_GOLD_COLOR := Color(1.0, 0.72, 0.18, 0.36)
const WHIRL_MOUTH_COLOR := Color(0.015, 0.006, 0.020, 0.54)
const DARK_RIPPLE_COLOR := Color(0.025, 0.012, 0.030, 0.20)
const THREAT_HALO_COLOR := Color(0.025, 0.010, 0.034, 0.18)
const THREAT_RING_COLOR := Color(0.34, 0.20, 0.58, 0.20)
const THREAT_DUST_COLOR := Color(0.74, 0.42, 0.18, 0.34)
const THREAT_GLINT_COLOR := Color(1.0, 0.78, 0.28, 0.48)
const SPARK_COLOR := Color(1.0, 0.95, 0.48, 0.84)
const EFFECT_LIFT := Vector2(0.0, -34.0)
const SPARK_COUNT := 9
const WHIRLPOOL_INTENSITY_CAP_MULTIPLIER := 6
const WHIRLPOOL_EXTRA_DURATION_STEP := 0.08
const WHIRLPOOL_EXTRA_DURATION_CAP := 0.24
const AUDIO_PLAYER_POOL_SIZE := 4
const AUDIO_COOLDOWN_MSEC := 100
const POCKET_STREAK_AUDIO_PATH := "res://audio/sfx/environment/namedpoocket_multi.wav"
const POCKET_STREAK_AUDIO_FALLBACK_PATH := "res://audio/sfx/environment/pocket_multi.wav"
const AUDIO_BASE_VOLUME_DB := -12.0
const AUDIO_MAX_VOLUME_DB := -7.0
const AUDIO_PITCH_STEP := 0.05
const AUDIO_MAX_PITCH_SCALE := 1.20
const POCKET_STREAK_AUDIO_BUS_NAME := "PocketStreakSFX"
const REVERB_ROOM_SIZE := 0.48
const REVERB_DAMPING := 0.46
const REVERB_SPREAD := 0.72
const REVERB_HIPASS := 0.18
const REVERB_WET_X2 := 0.08
const REVERB_WET_X3 := 0.14
const REVERB_WET_X4_PLUS := 0.22
const REVERB_WET_MAX := 0.26

@export var audio_bus_name := POCKET_STREAK_AUDIO_BUS_NAME
@export var pocket_streak_audio_enabled := true
@export var queue_gate_duration := PRESENTATION_MIN_DISPLAY_TIME
@export var whirlpool_extra_duration_cap := WHIRLPOOL_EXTRA_DURATION_CAP
@export var whirlpool_intensity_cap_multiplier := WHIRLPOOL_INTENSITY_CAP_MULTIPLIER
@export var audio_max_pitch_scale := AUDIO_MAX_PITCH_SCALE
@export var audio_max_volume_db := AUDIO_MAX_VOLUME_DB
@export var reverb_wet_cap := REVERB_WET_MAX

class PocketStreakEffect:
	var label: Label
	var anchor_position := Vector2.ZERO
	var pocket_radius := 0.0
	var elapsed := 0.0
	var duration := EFFECT_DURATION
	var multiplier := 2
	var tier := 0
	var spin_offset := 0.0

var active_effects: Array[PocketStreakEffect] = []
var presentation_queue: Array[Dictionary] = []
var presentation_delay_remaining := 0.0
var audio_players: Array[AudioStreamPlayer] = []
var pocket_streak_audio_stream: AudioStream
var next_audio_player_index := 0
var last_audio_time_msec := -AUDIO_COOLDOWN_MSEC
var total_streak_triggers := 0
var total_presentations_queued := 0
var total_presentations_started := 0
var total_audio_requests := 0
var total_audio_plays := 0
var total_audio_cooldown_skips := 0
var total_audio_pool_steals := 0
var max_audio_players_playing := 0
var last_presented_multiplier := 0
var last_audio_multiplier := 0
var pocket_streak_audio_bus_index := -1
var reverb_effect_index := -1
var reverb_wet_level := 0.0
var reverb_updates := 0
var recent_whirlpool_count := 0
var last_whirlpool_multiplier := 0


func _ready() -> void:
	AudioSettings.load_and_apply()
	_ensure_pocket_streak_audio_bus()
	_ensure_audio_pool()
	pocket_streak_audio_stream = _load_streak_audio_stream()
	set_process(false)


func show_streak(multiplier: int, pocket_position: Vector2, pocket_radius: float) -> void:
	if multiplier < 2 or pocket_position == Vector2.ZERO:
		return

	total_streak_triggers += 1
	total_presentations_queued += 1
	presentation_queue.append({
		"multiplier": multiplier,
		"pocket_position": pocket_position,
		"pocket_radius": pocket_radius,
	})
	_try_start_next_queued_presentation()
	set_process(true)


func _try_start_next_queued_presentation() -> void:
	if presentation_delay_remaining > 0.0 or presentation_queue.is_empty():
		return

	var presentation: Dictionary = presentation_queue[0]
	presentation_queue.remove_at(0)
	var pocket_position: Vector2 = Vector2.ZERO
	var pocket_position_value: Variant = presentation.get("pocket_position", Vector2.ZERO)
	if pocket_position_value is Vector2:
		pocket_position = pocket_position_value

	_start_streak_presentation(
		int(presentation.get("multiplier", 0)),
		pocket_position,
		float(presentation.get("pocket_radius", 0.0))
	)


func _start_streak_presentation(multiplier: int, pocket_position: Vector2, pocket_radius: float) -> void:
	if multiplier < 2 or pocket_position == Vector2.ZERO:
		return

	total_presentations_started += 1
	last_presented_multiplier = multiplier
	presentation_delay_remaining = queue_gate_duration
	var effect: PocketStreakEffect = PocketStreakEffect.new()
	effect.multiplier = multiplier
	effect.tier = _get_effect_tier(multiplier)
	effect.duration = _get_effect_duration(multiplier)
	effect.anchor_position = pocket_position
	effect.pocket_radius = maxf(pocket_radius, 32.0)
	effect.spin_offset = float((multiplier * 37) % 360) * PI / 180.0
	effect.label = _make_streak_label("X%s" % multiplier, multiplier)
	effect.label.position = pocket_position - LABEL_SIZE * 0.5
	add_child(effect.label)
	active_effects.append(effect)
	if multiplier >= 4:
		recent_whirlpool_count += 1
		last_whirlpool_multiplier = multiplier
	_play_streak_audio(multiplier)
	queue_redraw()


func _process(delta: float) -> void:
	if presentation_delay_remaining > 0.0:
		presentation_delay_remaining = maxf(presentation_delay_remaining - delta, 0.0)
	_try_start_next_queued_presentation()

	for effect_index in range(active_effects.size() - 1, -1, -1):
		var effect: PocketStreakEffect = active_effects[effect_index]
		if not is_instance_valid(effect.label):
			active_effects.remove_at(effect_index)
			continue

		effect.elapsed += delta
		_update_effect_label(effect)
		if effect.elapsed >= effect.duration:
			effect.label.queue_free()
			active_effects.remove_at(effect_index)

	set_process(
		not active_effects.is_empty()
		or not presentation_queue.is_empty()
		or presentation_delay_remaining > 0.0
	)
	if not active_effects.is_empty():
		queue_redraw()


func _draw() -> void:
	for effect in active_effects:
		_draw_pocket_wake_effect(effect)


func _make_streak_label(text: String, multiplier: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.size = LABEL_SIZE
	label.pivot_offset = LABEL_SIZE * 0.5
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", _get_label_font_size(multiplier))
	label.add_theme_color_override("font_color", LABEL_CURSED_COLOR if multiplier >= 4 else LABEL_COLOR)
	label.add_theme_color_override(
		"font_outline_color",
		LABEL_CURSED_OUTLINE_COLOR if multiplier >= 4 else LABEL_OUTLINE_COLOR
	)
	label.add_theme_color_override("font_shadow_color", LABEL_SHADOW_COLOR)
	label.add_theme_constant_override("outline_size", 10 if multiplier >= 4 else 8)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.modulate = Color(1, 1, 1, 0)
	label.scale = Vector2(0.62, 0.62)
	return label


func _update_effect_label(effect: PocketStreakEffect) -> void:
	var ratio: float = clampf(effect.elapsed / effect.duration, 0.0, 1.0)
	var pop: float = sin(minf(ratio * PI * 1.35, PI))
	var fade: float = 1.0 - smoothstep(0.68, 1.0, ratio)
	var lift: Vector2 = EFFECT_LIFT * _ease_out_cubic(ratio)
	var tier_scale: float = 0.08 * float(effect.tier)
	var settle_scale: float = lerpf(0.92 + tier_scale, 1.05 + tier_scale, pop)
	effect.label.position = effect.anchor_position - LABEL_SIZE * 0.5 + lift
	effect.label.scale = Vector2.ONE * settle_scale
	effect.label.rotation = sin(effect.elapsed * (9.0 + float(effect.tier) * 2.0) + effect.spin_offset) * deg_to_rad(5.0)
	effect.label.modulate = Color(1.0, 1.0, 1.0, fade)


func _draw_pocket_wake_effect(effect: PocketStreakEffect) -> void:
	var ratio: float = clampf(effect.elapsed / effect.duration, 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(0.62, 1.0, ratio)
	var pulse: float = sin(minf(ratio * PI * 1.25, PI))
	var center: Vector2 = effect.anchor_position + EFFECT_LIFT * 0.35 * _ease_out_cubic(ratio)
	var whirlpool_intensity: float = _get_whirlpool_intensity(effect.multiplier)
	var tier_strength: float = 1.0 + float(effect.tier) * 0.38 + whirlpool_intensity * 0.18
	var base_radius: float = effect.pocket_radius + 15.0 + pulse * 16.0 * tier_strength
	var spin: float = effect.elapsed * (5.5 + float(effect.tier) * 2.0 + whirlpool_intensity * 2.3) + effect.spin_offset

	if effect.tier >= 1:
		_draw_dark_ripple(center, base_radius, fade, pulse, effect.tier)
	if effect.tier >= 2:
		_draw_cursed_whirlpool(center, base_radius, spin, fade, pulse, ratio, effect.multiplier)

	var outer_glow: Color = GLOW_COLOR
	outer_glow.a *= fade * (0.52 + 0.16 * float(effect.tier))
	draw_arc(center, base_radius + 12.0, spin, spin + TAU * 0.86, 72, outer_glow, 9.0 + float(effect.tier) * 2.0)

	var inner_glow: Color = GLOW_COLOR.lightened(0.18)
	inner_glow.a *= fade * (0.72 + 0.12 * float(effect.tier))
	draw_arc(center, base_radius, -spin * 0.85, -spin * 0.85 + TAU * 0.72, 72, inner_glow, 4.0 + float(effect.tier))

	_draw_shimmer_sweep(center, base_radius, spin, fade, effect.tier)
	if effect.tier >= 1:
		_draw_inward_drift(center, base_radius, spin, fade, ratio, effect.tier)

	var sparkle_alpha: float = fade * (0.35 + pulse * 0.55)
	var spark_count: int = SPARK_COUNT + effect.tier * 4
	for spark_index in range(spark_count):
		var spark_ratio: float = float(spark_index) / float(spark_count)
		var angle: float = spin * 0.72 + spark_ratio * TAU
		var spark_radius: float = base_radius + 8.0 + sin(effect.elapsed * 8.0 + spark_ratio * TAU) * 8.0
		var spark_position: Vector2 = center + Vector2.RIGHT.rotated(angle) * spark_radius
		var spark_color: Color = SPARK_COLOR
		spark_color.a = sparkle_alpha * (0.55 + 0.45 * sin(effect.elapsed * 10.0 + spark_ratio * TAU))
		draw_circle(spark_position, 2.2 + pulse * (1.4 + float(effect.tier) * 0.55), spark_color)


func _draw_dark_ripple(center: Vector2, base_radius: float, fade: float, pulse: float, tier: int) -> void:
	var ripple_color: Color = DARK_RIPPLE_COLOR
	ripple_color.a *= fade * (0.75 + float(tier) * 0.25)
	draw_circle(center, base_radius + 20.0 + pulse * 7.0, ripple_color)


func _draw_shimmer_sweep(center: Vector2, base_radius: float, spin: float, fade: float, tier: int) -> void:
	var sweep_color: Color = Color(1.0, 0.98, 0.58, 0.58)
	sweep_color.a *= fade * (0.85 + float(tier) * 0.12)
	var sweep_start: float = spin * 1.45
	var sweep_length: float = TAU * (0.12 + float(tier) * 0.025)
	draw_arc(center, base_radius + 19.0, sweep_start, sweep_start + sweep_length, 18, sweep_color, 11.0 + float(tier) * 2.0)


func _draw_inward_drift(
	center: Vector2,
	base_radius: float,
	spin: float,
	fade: float,
	ratio: float,
	tier: int
) -> void:
	var drift_count: int = 8 + tier * 5
	for drift_index in range(drift_count):
		var drift_ratio: float = float(drift_index) / float(drift_count)
		var travel: float = fmod(ratio * (1.35 + float(tier) * 0.25) + drift_ratio, 1.0)
		var angle: float = -spin * 0.55 + drift_ratio * TAU + sin(travel * TAU) * 0.22
		var particle_radius: float = lerpf(base_radius + 34.0, maxf(base_radius * 0.36, 18.0), travel)
		var particle_position: Vector2 = center + Vector2.RIGHT.rotated(angle) * particle_radius
		var particle_color: Color = Color(1.0, 0.86, 0.34, fade * (1.0 - travel) * 0.62)
		if tier >= 2:
			particle_color = particle_color.lerp(Color(0.62, 0.34, 0.82, particle_color.a), 0.35)
		draw_circle(particle_position, 2.0 + float(tier) * 0.55, particle_color)


func _draw_cursed_whirlpool(
	center: Vector2,
	base_radius: float,
	spin: float,
	fade: float,
	pulse: float,
	ratio: float,
	multiplier: int
) -> void:
	var intensity: float = _get_whirlpool_intensity(multiplier)
	_draw_whirlpool_threat_tell(center, base_radius, spin, fade, pulse, ratio, intensity)

	var mouth_radius: float = maxf(base_radius * (0.28 + intensity * 0.04), 18.0)
	var mouth_color: Color = WHIRL_MOUTH_COLOR
	mouth_color.a *= fade * (0.88 + intensity * 0.20)
	draw_circle(center, mouth_radius + pulse * 3.0, mouth_color)

	var undertow_color: Color = WHIRL_COLOR.darkened(0.35)
	undertow_color.a *= fade * (0.54 + intensity * 0.18)
	draw_arc(center, mouth_radius + 9.0 + pulse * 2.0, spin * 0.9, spin * 0.9 + TAU * 0.92, 48, undertow_color, 8.0)

	var arm_count: int = 5 + int(round(intensity * 2.0))
	for arm_index in range(arm_count):
		var arm_ratio: float = float(arm_index) / float(arm_count)
		var arm_radius: float = base_radius * 0.38 + arm_ratio * (15.0 + intensity * 7.0) + pulse * 3.0
		var arm_start: float = -spin * (1.18 + intensity * 0.18) + arm_ratio * TAU
		var arm_length: float = TAU * (0.46 + intensity * 0.08)
		var arm_width: float = 3.0 + intensity * 1.6
		var arm_color: Color = WHIRL_COLOR
		arm_color.a *= fade * (0.78 + intensity * 0.22 - arm_ratio * 0.08)
		draw_arc(center, arm_radius, arm_start, arm_start + arm_length, 36, arm_color, arm_width)

		var gold_color: Color = WHIRL_GOLD_COLOR
		gold_color.a *= fade * (0.40 + intensity * 0.18 - arm_ratio * 0.06)
		draw_arc(center, arm_radius + 5.0, arm_start + TAU * 0.06, arm_start + arm_length * 0.58, 20, gold_color, 2.0)

	_draw_whirlpool_inward_particles(center, base_radius, spin, fade, ratio, intensity)


func _draw_whirlpool_threat_tell(
	center: Vector2,
	base_radius: float,
	spin: float,
	fade: float,
	pulse: float,
	ratio: float,
	intensity: float
) -> void:
	var threat_strength: float = 0.45 + intensity * 0.55
	var threat_radius: float = base_radius + 30.0 + pulse * (6.0 + intensity * 4.0)
	var halo_color: Color = THREAT_HALO_COLOR
	halo_color.a *= fade * threat_strength
	draw_circle(center, threat_radius, halo_color)

	for ring_index in range(3):
		var ring_ratio: float = float(ring_index) / 3.0
		var ring_radius: float = base_radius + 15.0 + ring_ratio * (30.0 + intensity * 12.0)
		var ring_spin: float = spin * (0.36 + ring_ratio * 0.18)
		var ring_color: Color = THREAT_RING_COLOR
		ring_color.a *= fade * threat_strength * (0.78 - ring_ratio * 0.18)
		draw_arc(
			center,
			ring_radius,
			ring_spin + ratio * TAU * 0.16,
			ring_spin + ratio * TAU * 0.16 + TAU * (0.34 + ring_ratio * 0.08),
			34,
			ring_color,
			2.0 + intensity
		)

	var dust_count: int = 7 + int(round(intensity * 5.0))
	for dust_index in range(dust_count):
		var dust_ratio: float = float(dust_index) / float(dust_count)
		var travel: float = fmod(ratio * (0.92 + intensity * 0.20) + dust_ratio, 1.0)
		var angle: float = -spin * 0.42 + dust_ratio * TAU * 1.35 + sin(travel * TAU) * 0.16
		var dust_radius: float = lerpf(base_radius + 45.0, maxf(base_radius * 0.44, 22.0), travel)
		var dust_position: Vector2 = center + Vector2.RIGHT.rotated(angle) * dust_radius
		var dust_color: Color = THREAT_DUST_COLOR
		dust_color.a *= fade * threat_strength * (1.0 - travel * 0.72)
		draw_circle(dust_position, 1.5 + intensity * 0.55, dust_color)

	var glint_count: int = 3 + int(round(intensity * 2.0))
	for glint_index in range(glint_count):
		var glint_ratio: float = float(glint_index) / float(glint_count)
		var glint_travel: float = fmod(ratio * (1.18 + intensity * 0.22) + glint_ratio * 0.73, 1.0)
		var glint_angle: float = spin * 0.24 + glint_ratio * TAU * 1.9
		var outer_position: Vector2 = center + Vector2.RIGHT.rotated(glint_angle) * lerpf(base_radius + 38.0, base_radius * 0.60, glint_travel)
		var inward_direction: Vector2 = (center - outer_position).normalized()
		var glint_color: Color = THREAT_GLINT_COLOR
		glint_color.a *= fade * threat_strength * sin(glint_travel * PI)
		draw_line(outer_position, outer_position + inward_direction * (6.0 + intensity * 3.0), glint_color, 1.4 + intensity * 0.4)


func _draw_whirlpool_inward_particles(
	center: Vector2,
	base_radius: float,
	spin: float,
	fade: float,
	ratio: float,
	intensity: float
) -> void:
	var particle_count: int = 10 + int(round(intensity * 8.0))
	for particle_index in range(particle_count):
		var particle_ratio: float = float(particle_index) / float(particle_count)
		var travel: float = fmod(ratio * (1.65 + intensity * 0.40) + particle_ratio, 1.0)
		var angle: float = -spin * (0.72 + intensity * 0.12) + particle_ratio * TAU * 1.7
		var radius: float = lerpf(base_radius + 24.0, maxf(base_radius * 0.24, 14.0), _ease_out_cubic(travel))
		var particle_position: Vector2 = center + Vector2.RIGHT.rotated(angle) * radius
		var particle_color: Color = Color(0.64, 0.34, 0.86, fade * (1.0 - travel) * (0.42 + intensity * 0.20))
		if particle_index % 3 == 0:
			particle_color = Color(1.0, 0.75, 0.24, particle_color.a * 0.82)
		draw_circle(particle_position, 1.8 + intensity * 0.9, particle_color)


func _get_effect_tier(multiplier: int) -> int:
	if multiplier >= 4:
		return 2
	if multiplier >= 3:
		return 1
	return 0


func _get_effect_duration(multiplier: int) -> float:
	if multiplier >= 4:
		var extra_duration: float = minf(
			float(maxi(multiplier - 4, 0)) * WHIRLPOOL_EXTRA_DURATION_STEP,
			whirlpool_extra_duration_cap
		)
		return EFFECT_DURATION_X4_PLUS + extra_duration
	if multiplier >= 3:
		return EFFECT_DURATION_X3
	return EFFECT_DURATION


func _get_whirlpool_intensity(multiplier: int) -> float:
	if multiplier < 4:
		return 0.0

	var cap_multiplier: int = maxi(whirlpool_intensity_cap_multiplier, 5)
	var capped_multiplier: int = mini(multiplier, cap_multiplier)
	return clampf(float(capped_multiplier - 4) / float(cap_multiplier - 4), 0.0, 1.0)


func _get_label_font_size(multiplier: int) -> int:
	return LABEL_FONT_SIZE + mini(maxi(multiplier - 2, 0), 2) * 4


func _ensure_audio_pool() -> void:
	while audio_players.size() < AUDIO_PLAYER_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = audio_bus_name
		add_child(player)
		audio_players.append(player)


func _play_streak_audio(multiplier: int) -> void:
	total_audio_requests += 1
	if not pocket_streak_audio_enabled:
		return
	if audio_players.is_empty():
		return
	if pocket_streak_audio_stream == null:
		return

	var now_msec: int = Time.get_ticks_msec()
	if now_msec - last_audio_time_msec < AUDIO_COOLDOWN_MSEC:
		total_audio_cooldown_skips += 1
		return

	_apply_streak_reverb_for_multiplier(multiplier)
	var player: AudioStreamPlayer = _get_next_audio_player()
	player.stream = pocket_streak_audio_stream
	player.pitch_scale = _get_streak_audio_pitch(multiplier)
	player.volume_db = _get_streak_audio_volume_db(multiplier)
	player.play()
	total_audio_plays += 1
	last_audio_multiplier = multiplier
	last_audio_time_msec = now_msec
	max_audio_players_playing = maxi(max_audio_players_playing, get_playing_audio_player_count())


func _get_next_audio_player() -> AudioStreamPlayer:
	for player in audio_players:
		if not player.playing:
			return player

	var player: AudioStreamPlayer = audio_players[next_audio_player_index]
	next_audio_player_index = (next_audio_player_index + 1) % audio_players.size()
	player.stop()
	total_audio_pool_steals += 1
	return player


func _load_streak_audio_stream() -> AudioStream:
	if ResourceLoader.exists(POCKET_STREAK_AUDIO_PATH):
		return load(POCKET_STREAK_AUDIO_PATH) as AudioStream
	if ResourceLoader.exists(POCKET_STREAK_AUDIO_FALLBACK_PATH):
		return load(POCKET_STREAK_AUDIO_FALLBACK_PATH) as AudioStream
	return null


func _get_streak_audio_pitch(multiplier: int) -> float:
	var max_pitch_scale: float = maxf(audio_max_pitch_scale, 1.0)
	return clampf(1.0 + float(maxi(multiplier - 2, 0)) * AUDIO_PITCH_STEP, 1.0, max_pitch_scale)


func _get_streak_audio_volume_db(multiplier: int) -> float:
	var max_volume_step: float = maxf(audio_max_volume_db - AUDIO_BASE_VOLUME_DB, 0.0)
	var volume_step: float = clampf(float(maxi(multiplier - 2, 0)) * 1.25, 0.0, max_volume_step)
	return AUDIO_BASE_VOLUME_DB + volume_step


func _ensure_pocket_streak_audio_bus() -> void:
	if audio_bus_name == "Master":
		audio_bus_name = POCKET_STREAK_AUDIO_BUS_NAME

	AudioSettings.ensure_audio_buses()
	pocket_streak_audio_bus_index = AudioServer.get_bus_index(audio_bus_name)
	if pocket_streak_audio_bus_index < 0:
		pocket_streak_audio_bus_index = AudioServer.get_bus_count()
		AudioServer.add_bus(pocket_streak_audio_bus_index)
		AudioServer.set_bus_name(pocket_streak_audio_bus_index, audio_bus_name)
	AudioServer.set_bus_send(pocket_streak_audio_bus_index, AudioSettings.SFX_BUS_NAME)

	_ensure_pocket_streak_reverb_effect()


func _ensure_pocket_streak_reverb_effect() -> void:
	if pocket_streak_audio_bus_index < 0:
		return

	for effect_index in range(AudioServer.get_bus_effect_count(pocket_streak_audio_bus_index)):
		var existing_reverb: AudioEffectReverb = AudioServer.get_bus_effect(pocket_streak_audio_bus_index, effect_index) as AudioEffectReverb
		if existing_reverb != null:
			reverb_effect_index = effect_index
			_configure_reverb_effect(existing_reverb)
			AudioServer.set_bus_effect_enabled(pocket_streak_audio_bus_index, reverb_effect_index, true)
			return

	var reverb: AudioEffectReverb = AudioEffectReverb.new()
	_configure_reverb_effect(reverb)
	AudioServer.add_bus_effect(pocket_streak_audio_bus_index, reverb)
	reverb_effect_index = AudioServer.get_bus_effect_count(pocket_streak_audio_bus_index) - 1
	AudioServer.set_bus_effect_enabled(pocket_streak_audio_bus_index, reverb_effect_index, true)


func _configure_reverb_effect(reverb: AudioEffectReverb) -> void:
	_set_audio_effect_property_if_present(reverb, "room_size", REVERB_ROOM_SIZE)
	_set_audio_effect_property_if_present(reverb, "damping", REVERB_DAMPING)
	_set_audio_effect_property_if_present(reverb, "spread", REVERB_SPREAD)
	_set_audio_effect_property_if_present(reverb, "hipass", REVERB_HIPASS)
	_set_audio_effect_property_if_present(reverb, "dry", 1.0)
	_set_audio_effect_property_if_present(reverb, "wet", REVERB_WET_X2)
	reverb_wet_level = REVERB_WET_X2


func _apply_streak_reverb_for_multiplier(multiplier: int) -> void:
	var reverb: AudioEffectReverb = _get_pocket_streak_reverb_effect()
	if reverb == null:
		return

	var wet_level: float = _get_streak_reverb_wet_level(multiplier)
	_set_audio_effect_property_if_present(reverb, "wet", wet_level)
	reverb_wet_level = wet_level
	reverb_updates += 1


func _get_pocket_streak_reverb_effect() -> AudioEffectReverb:
	if pocket_streak_audio_bus_index < 0 or reverb_effect_index < 0:
		return null
	return AudioServer.get_bus_effect(pocket_streak_audio_bus_index, reverb_effect_index) as AudioEffectReverb


func _get_streak_reverb_wet_level(multiplier: int) -> float:
	var wet_cap: float = clampf(reverb_wet_cap, 0.0, 1.0)
	if multiplier >= 4:
		return minf(REVERB_WET_X4_PLUS + float(multiplier - 4) * 0.01, wet_cap)
	if multiplier >= 3:
		return minf(REVERB_WET_X3, wet_cap)
	return minf(REVERB_WET_X2, wet_cap)


func _set_audio_effect_property_if_present(effect: AudioEffect, property_name: String, value: Variant) -> void:
	for property_data: Dictionary in effect.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			effect.set(property_name, value)
			return


func get_playing_audio_player_count() -> int:
	var playing_count: int = 0
	for player in audio_players:
		if player.playing:
			playing_count += 1
	return playing_count


func get_active_whirlpool_count() -> int:
	var whirlpool_count: int = 0
	for effect in active_effects:
		if effect.multiplier >= 4:
			whirlpool_count += 1
	return whirlpool_count


func get_audio_debug_snapshot() -> Dictionary:
	return {
		"pool_size": audio_players.size(),
		"playing_players": get_playing_audio_player_count(),
		"max_playing_players": max_audio_players_playing,
		"streak_triggers": total_streak_triggers,
		"presentations_queued": total_presentations_queued,
		"presentations_started": total_presentations_started,
		"last_presented_multiplier": last_presented_multiplier,
		"presentation_queue_size": presentation_queue.size(),
		"presentation_delay_remaining": presentation_delay_remaining,
		"queue_gate_duration": queue_gate_duration,
		"audio_requests": total_audio_requests,
		"audio_plays": total_audio_plays,
		"cooldown_skips": total_audio_cooldown_skips,
		"pool_steals": total_audio_pool_steals,
		"last_multiplier": last_audio_multiplier,
		"active_whirlpools": get_active_whirlpool_count(),
		"recent_whirlpools": recent_whirlpool_count,
		"last_whirlpool_multiplier": last_whirlpool_multiplier,
		"whirlpool_extra_duration_cap": whirlpool_extra_duration_cap,
		"whirlpool_intensity_cap_multiplier": whirlpool_intensity_cap_multiplier,
		"audio_max_pitch_scale": audio_max_pitch_scale,
		"audio_max_volume_db": audio_max_volume_db,
		"audio_bus": audio_bus_name,
		"audio_bus_index": pocket_streak_audio_bus_index,
		"reverb_effect_index": reverb_effect_index,
		"reverb_wet_level": reverb_wet_level,
		"reverb_wet_cap": reverb_wet_cap,
		"reverb_updates": reverb_updates,
	}


func _ease_out_cubic(value: float) -> float:
	var inverse: float = 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - inverse * inverse * inverse
