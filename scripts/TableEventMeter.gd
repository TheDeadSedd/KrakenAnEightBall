extends Control
class_name TableEventMeter

signal event_icon_clicked

# Player-facing meter for shot-earned Kraken Intervention opportunities.
# Internally, those opportunities are Table Events.
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const INTERVENTION_BUTTON_TEXTURE_PATH := "res://assets/ui/kraken_intervention_button.png"
const BORDER_COLOR := Color(0.74, 0.55, 0.22, 0.72)
const BORDER_READY_COLOR := Color(1.0, 0.84, 0.36, 1.0)
const TRACK_COLOR := Color(0.02, 0.025, 0.024, 0.88)
const FILL_COLOR := Color(0.22, 0.72, 0.84, 0.92)
const FILL_READY_COLOR := Color(1.0, 0.72, 0.22, 1.0)
const SEGMENT_FILL_COLORS := [
	Color(0.22, 0.72, 0.84, 0.92),
	Color(0.24, 0.86, 0.58, 0.92),
	Color(0.62, 0.42, 0.94, 0.92),
	Color(1.0, 0.72, 0.22, 0.96),
]
const TEXT_COLOR := Color(0.95, 0.88, 0.66, 1.0)
const VALUE_TEXT_COLOR := Color(0.78, 0.96, 1.0, 1.0)
const SHADOW_COLOR := Color(0.02, 0.015, 0.01, 0.72)
const ICON_FILL := Color(0.055, 0.038, 0.020, 0.90)
const ICON_FILL_HOVER := Color(0.13, 0.09, 0.035, 0.96)
const ICON_BORDER := Color(0.94, 0.72, 0.26, 0.88)
const ICON_GLOW := Color(1.0, 0.70, 0.18, 0.22)
const TITLE_FONT_SIZE := 17
const VALUE_FONT_SIZE := 16
const PERCENT_FONT_SIZE := 24
const BAR_LEFT := 20.0
const BAR_TOP := 40.0
const BAR_HEIGHT := 22.0
const BAR_ICON_GAP := 78.0
const ICON_SIZE := Vector2(44.0, 44.0)
const ICON_RIGHT_MARGIN := 14.0
const TALLY_BASE_SPEED := 14.0
const TALLY_ACCELERATION := 42.0
const TALLY_DISTANCE_BONUS := 0.24
const TALLY_MAX_SPEED := 205.0
const TALLY_TICK_POOL_SIZE := 6
const TALLY_TICK_BUS_NAME := "SFX"
const TALLY_TICK_SAMPLE_RATE := 22050
const TALLY_TICK_DURATION := 0.058
const TALLY_TICK_ATTACK := 0.007
const TALLY_TICK_BASE_FREQUENCY := 76.0
const TALLY_TICK_VOLUME_DB := -14.0
const TALLY_TICK_PITCH_STEP := 0.012
const TALLY_TICK_MAX_PITCH := 1.85
const TALLY_TICK_MIN_INTERVAL := 0.035
const PROGRESS_PULSE_TIME := 0.22
const EVENT_EARNED_FLASH_TIME := 0.68
const READY_FLASH_TIME := 0.42
const READY_IDLE_PULSE_SPEED := 2.8
const READY_IDLE_PULSE_ALPHA := 0.18
const TALLY_EPSILON := 0.01

var table_event_system: TableEventSystem
var table
var intervention_button_texture: Texture2D = load(INTERVENTION_BUTTON_TEXTURE_PATH) as Texture2D
var progress := 0
var threshold := 60
var target_abs_progress := 0.0
var displayed_abs_progress := 0.0
var tally_catchup_time := 0.0
var tally_was_catching_up := false
var tally_initialized := false
var tally_tick_stream: AudioStreamWAV
var tally_tick_players: Array[AudioStreamPlayer] = []
var tally_tick_next_player_index := 0
var tally_tick_cooldown_remaining := 0.0
var tally_audio_points_counted := 0
var last_tally_audio_floor := 0
var last_gain := 0
var pending_event := false
var event_ready := false
var pending_charges := 0
var segment_index := 0
var icon_hovered := false
var hover_ui_suppressed := false
var progress_pulse_remaining := 0.0
var event_earned_flash_remaining := 0.0
var ready_flash_remaining := 0.0
var ready_idle_phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	pivot_offset = size * 0.5
	AudioSettings.load_and_apply()
	_ensure_tally_tick_audio()
	set_process(false)
	queue_redraw()


func _exit_tree() -> void:
	_disconnect_table_event_system()


func setup(system: TableEventSystem, table_ref) -> void:
	_disconnect_table_event_system()
	table_event_system = system
	table = table_ref
	if table_event_system == null:
		return

	table_event_system.meter_changed.connect(_on_meter_changed)
	table_event_system.progress_advanced.connect(_on_progress_advanced)
	table_event_system.pending_event_changed.connect(_on_pending_event_changed)
	var snapshot: Dictionary = table_event_system.get_debug_snapshot()
	tally_initialized = false
	_set_progress(
		int(snapshot.get("shot_progress", 0)),
		int(snapshot.get("shot_threshold", 1)),
		float(snapshot.get("progress_percent", 0.0)),
		bool(snapshot.get("pending_event_available", false)),
		bool(snapshot.get("pending_event_ready", false)),
		int(snapshot.get("pending_intervention_charges", 0)),
		int(snapshot.get("current_segment_index", 0))
	)
	queue_redraw()


func set_hover_ui_suppressed(suppressed: bool) -> void:
	if hover_ui_suppressed == suppressed:
		return

	hover_ui_suppressed = suppressed
	mouse_filter = Control.MOUSE_FILTER_IGNORE if suppressed else Control.MOUSE_FILTER_PASS
	if suppressed and icon_hovered:
		icon_hovered = false
		queue_redraw()


func _process(delta: float) -> void:
	tally_tick_cooldown_remaining = maxf(tally_tick_cooldown_remaining - delta, 0.0)
	_update_tally(delta)

	progress_pulse_remaining = maxf(progress_pulse_remaining - delta, 0.0)
	event_earned_flash_remaining = maxf(event_earned_flash_remaining - delta, 0.0)
	ready_flash_remaining = maxf(ready_flash_remaining - delta, 0.0)
	if event_ready:
		ready_idle_phase = fposmod(ready_idle_phase + delta * READY_IDLE_PULSE_SPEED, TAU)
	_update_pulse_scale()
	queue_redraw()

	if not _is_animating():
		scale = Vector2.ONE
		set_process(false)


func _gui_input(event: InputEvent) -> void:
	if _should_suppress_hover_ui():
		if icon_hovered:
			icon_hovered = false
			queue_redraw()
		return

	if event is InputEventMouseMotion:
		_update_icon_hover(event.position)
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		_update_icon_hover(mouse_event.position)
		if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not _is_icon_clickable():
			return
		if _is_cue_drag_active():
			return

		_snap_tally_to_target()
		queue_redraw()
		accept_event()
		event_icon_clicked.emit()


func _draw() -> void:
	var draw_size: Vector2 = size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return

	var pulse_strength: float = _get_pulse_strength()
	var earned_strength: float = _get_event_earned_strength()
	var ready_strength: float = _get_ready_strength()
	var idle_strength: float = _get_ready_idle_strength()
	var event_strength: float = maxf(earned_strength, maxf(ready_strength, idle_strength * 0.45))
	var border_color: Color = BORDER_COLOR.lerp(BORDER_READY_COLOR, maxf(pulse_strength * 0.45, event_strength))
	var displayed_state := _get_displayed_segment_state()
	var displayed_segment_index := int(displayed_state.get("segment_index", 0))
	var fill_color: Color = _get_segment_fill_color(displayed_segment_index).lerp(FILL_READY_COLOR, maxf(pulse_strength * 0.45, event_strength))

	_draw_event_earned_glow(_get_bar_rect(draw_size), earned_strength)
	_draw_meter_text(draw_size, pulse_strength, maxf(ready_strength, earned_strength), displayed_state)
	_draw_meter_bar(draw_size, fill_color, border_color, displayed_state)
	_draw_event_icon(draw_size, ready_strength, idle_strength)


func _on_meter_changed(
	new_progress: int,
	new_threshold: int,
	new_percent: float,
	pending: bool,
	ready: bool,
	charges: int,
	new_segment_index: int
) -> void:
	_set_progress(new_progress, new_threshold, new_percent, pending, ready, charges, new_segment_index)
	_wake_animation()


func _on_progress_advanced(amount: int, _shot_total: int) -> void:
	if amount <= 0:
		return
	last_gain = amount
	progress_pulse_remaining = PROGRESS_PULSE_TIME
	_wake_animation()


func _on_pending_event_changed(_pending: bool, _ready: bool) -> void:
	_wake_animation()


func _set_progress(
	new_progress: int,
	new_threshold: int,
	_new_percent: float,
	pending: bool,
	ready: bool,
	charges: int,
	new_segment_index: int
) -> void:
	var was_pending: bool = pending_event
	var was_ready: bool = event_ready
	var previous_target_abs := target_abs_progress
	progress = maxi(new_progress, 0)
	threshold = maxi(new_threshold, 1)
	pending_event = pending
	event_ready = ready
	pending_charges = maxi(charges, 0)
	segment_index = maxi(new_segment_index, 0)
	target_abs_progress = _get_absolute_progress_for_segment(segment_index, progress)
	if not tally_initialized:
		tally_initialized = true
		_snap_tally_to_target()
	elif target_abs_progress < previous_target_abs - TALLY_EPSILON:
		_snap_tally_to_target()
	elif target_abs_progress <= displayed_abs_progress + TALLY_EPSILON:
		_snap_tally_to_target()
	elif not tally_was_catching_up:
		_reset_tally_audio_sequence()
	if pending_event and not was_pending:
		event_earned_flash_remaining = EVENT_EARNED_FLASH_TIME
	if event_ready and not was_ready:
		ready_flash_remaining = READY_FLASH_TIME


func _wake_animation() -> void:
	pivot_offset = size * 0.5
	set_process(true)
	queue_redraw()


func _is_animating() -> bool:
	return (
		abs(displayed_abs_progress - target_abs_progress) > TALLY_EPSILON
		or progress_pulse_remaining > 0.0
		or event_earned_flash_remaining > 0.0
		or ready_flash_remaining > 0.0
		or event_ready
	)


func _update_pulse_scale() -> void:
	var scale_boost: float = 1.0 + _get_pulse_strength() * 0.025 + _get_event_earned_strength() * 0.035 + _get_ready_strength() * 0.050
	scale = Vector2.ONE * scale_boost


func _update_tally(delta: float) -> void:
	var gap := target_abs_progress - displayed_abs_progress
	if gap < -TALLY_EPSILON:
		_snap_tally_to_target()
		return
	if gap <= TALLY_EPSILON:
		if tally_was_catching_up:
			_snap_tally_to_target()
		return

	var previous_segment_index := _get_segment_index_for_absolute_progress(displayed_abs_progress)
	tally_catchup_time += delta
	tally_was_catching_up = true
	var tally_speed := TALLY_BASE_SPEED
	tally_speed += TALLY_ACCELERATION * tally_catchup_time
	tally_speed += gap * TALLY_DISTANCE_BONUS
	tally_speed = minf(tally_speed, TALLY_MAX_SPEED)
	displayed_abs_progress = minf(target_abs_progress, displayed_abs_progress + tally_speed * delta)
	_update_tally_tick_audio()
	var next_segment_index := _get_segment_index_for_absolute_progress(displayed_abs_progress)
	if next_segment_index > previous_segment_index:
		_trigger_segment_crossing_feedback()


func _snap_tally_to_target() -> void:
	displayed_abs_progress = target_abs_progress
	tally_catchup_time = 0.0
	tally_was_catching_up = false
	_reset_tally_audio_sequence()


func _trigger_segment_crossing_feedback() -> void:
	progress_pulse_remaining = maxf(progress_pulse_remaining, PROGRESS_PULSE_TIME)
	event_earned_flash_remaining = maxf(event_earned_flash_remaining, EVENT_EARNED_FLASH_TIME * 0.55)


func _update_tally_tick_audio() -> void:
	var current_displayed_floor := int(floor(displayed_abs_progress + 0.001))
	var crossed_points := current_displayed_floor - last_tally_audio_floor
	if crossed_points <= 0:
		if crossed_points < 0:
			last_tally_audio_floor = current_displayed_floor
		return

	tally_audio_points_counted += crossed_points
	last_tally_audio_floor = current_displayed_floor
	_play_tally_tick()


func _reset_tally_audio_sequence() -> void:
	tally_audio_points_counted = 0
	last_tally_audio_floor = int(floor(displayed_abs_progress + 0.001))
	tally_tick_cooldown_remaining = 0.0


func _ensure_tally_tick_audio() -> void:
	if tally_tick_stream == null:
		tally_tick_stream = _make_tally_tick_stream()

	while tally_tick_players.size() < TALLY_TICK_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = TALLY_TICK_BUS_NAME
		player.stream = tally_tick_stream
		player.volume_db = TALLY_TICK_VOLUME_DB
		add_child(player)
		tally_tick_players.append(player)


func _make_tally_tick_stream() -> AudioStreamWAV:
	var sample_count := maxi(int(float(TALLY_TICK_SAMPLE_RATE) * TALLY_TICK_DURATION), 1)
	var attack_samples := maxi(int(float(TALLY_TICK_SAMPLE_RATE) * TALLY_TICK_ATTACK), 1)
	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var time := float(sample_index) / float(TALLY_TICK_SAMPLE_RATE)
		var attack := clampf(float(sample_index) / float(attack_samples), 0.0, 1.0)
		var decay := pow(1.0 - clampf(time / TALLY_TICK_DURATION, 0.0, 1.0), 2.35)
		var envelope := attack * decay
		var wave := sin(TAU * TALLY_TICK_BASE_FREQUENCY * time)
		var softened_wave := wave * (0.86 + 0.14 * cos(TAU * TALLY_TICK_BASE_FREQUENCY * time))
		var sample_value := clampf(softened_wave * envelope * 0.82, -1.0, 1.0)
		var int_sample := int(round(sample_value * 32767.0))
		if int_sample < 0:
			int_sample += 65536
		var byte_index := sample_index * 2
		audio_data[byte_index] = int_sample & 0xff
		audio_data[byte_index + 1] = (int_sample >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TALLY_TICK_SAMPLE_RATE
	stream.stereo = false
	stream.data = audio_data
	return stream


func _play_tally_tick() -> void:
	if tally_tick_cooldown_remaining > 0.0:
		return
	if tally_tick_stream == null:
		return

	var player := _get_available_tally_tick_player()
	if player == null:
		return

	player.stream = tally_tick_stream
	player.bus = TALLY_TICK_BUS_NAME
	player.volume_db = TALLY_TICK_VOLUME_DB
	player.pitch_scale = minf(1.0 + float(tally_audio_points_counted) * TALLY_TICK_PITCH_STEP, TALLY_TICK_MAX_PITCH)
	player.play()
	tally_tick_cooldown_remaining = TALLY_TICK_MIN_INTERVAL


func _get_available_tally_tick_player() -> AudioStreamPlayer:
	if tally_tick_players.is_empty():
		_ensure_tally_tick_audio()
	if tally_tick_players.is_empty():
		return null

	for player in tally_tick_players:
		if not player.playing:
			return player

	var player := tally_tick_players[tally_tick_next_player_index]
	tally_tick_next_player_index = (tally_tick_next_player_index + 1) % tally_tick_players.size()
	player.stop()
	return player


func _draw_meter_text(draw_size: Vector2, pulse_strength: float, ready_strength: float, displayed_state: Dictionary) -> void:
	var title_color: Color = TEXT_COLOR.lerp(BORDER_READY_COLOR, ready_strength)
	var value_color: Color = VALUE_TEXT_COLOR.lerp(FILL_READY_COLOR, maxf(pulse_strength * 0.45, ready_strength))
	var displayed_percent := float(displayed_state.get("percent", 0.0))
	var displayed_progress := int(displayed_state.get("progress", 0))
	var displayed_goal := int(displayed_state.get("goal", 1))
	var percent_text: String = "%d%%" % int(round(displayed_percent * 100.0))
	var value_text: String = "%d / %d" % [displayed_progress, displayed_goal]
	var bar_rect: Rect2 = _get_bar_rect(draw_size)

	_draw_shadowed_text("KRAKEN INTERVENTION", Vector2(BAR_LEFT, 25.0), TITLE_FONT_SIZE, title_color)
	_draw_shadowed_text(value_text, Vector2(BAR_LEFT, bar_rect.end.y + 25.0), VALUE_FONT_SIZE, value_color)
	draw_string(
		UI_FONT,
		Vector2(bar_rect.end.x - 96.0, bar_rect.position.y + 18.0) + Vector2(1.5, 1.5),
		percent_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		96.0,
		PERCENT_FONT_SIZE,
		SHADOW_COLOR
	)
	draw_string(
		UI_FONT,
		Vector2(bar_rect.end.x - 96.0, bar_rect.position.y + 18.0),
		percent_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		96.0,
		PERCENT_FONT_SIZE,
		value_color
	)

	if progress_pulse_remaining > 0.0 and last_gain > 0:
		var gain_color: Color = FILL_READY_COLOR.lerp(Color.WHITE, ready_strength)
		draw_string(
			UI_FONT,
			Vector2(bar_rect.end.x - 122.0, 25.0),
			"+%d" % last_gain,
			HORIZONTAL_ALIGNMENT_RIGHT,
			120.0,
			VALUE_FONT_SIZE,
			gain_color
		)


func _draw_meter_bar(draw_size: Vector2, fill_color: Color, border_color: Color, displayed_state: Dictionary) -> void:
	var track_rect: Rect2 = _get_bar_rect(draw_size)
	var displayed_percent := float(displayed_state.get("percent", 0.0))
	var displayed_segment_index := int(displayed_state.get("segment_index", 0))
	var fill_width: float = track_rect.size.x * clampf(displayed_percent, 0.0, 1.0)
	var fill_rect: Rect2 = Rect2(track_rect.position, Vector2(fill_width, track_rect.size.y))
	draw_rect(track_rect, _get_segment_base_color(displayed_segment_index), true)
	if fill_width > 0.0:
		draw_rect(fill_rect, fill_color, true)
		draw_line(
			Vector2(fill_rect.end.x, fill_rect.position.y + 3.0),
			Vector2(fill_rect.end.x, fill_rect.end.y - 3.0),
			fill_color.lightened(0.32),
			2.0
		)

	draw_rect(track_rect, border_color, false, 1.5)
	for tick_index in range(1, 5):
		var tick_x: float = track_rect.position.x + track_rect.size.x * float(tick_index) / 5.0
		draw_line(
			Vector2(tick_x, track_rect.position.y + 2.0),
			Vector2(tick_x, track_rect.end.y - 2.0),
			border_color.darkened(0.25),
			1.0
		)


func _draw_event_earned_glow(panel_rect: Rect2, earned_strength: float) -> void:
	if earned_strength <= 0.0:
		return

	var glow_color: Color = Color(1.0, 0.72, 0.20, 0.20 * earned_strength)
	draw_rect(panel_rect.grow(8.0), glow_color, false, 4.0)
	draw_rect(panel_rect.grow(15.0), Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.42), false, 7.0)


func _draw_event_icon(draw_size: Vector2, ready_strength: float, idle_strength: float) -> void:
	if not event_ready:
		return

	var icon_rect: Rect2 = _get_icon_rect(draw_size)
	var icon_fill: Color = ICON_FILL_HOVER if icon_hovered else ICON_FILL
	var combined_strength: float = maxf(ready_strength, idle_strength)
	var glow_alpha: float = (0.55 + 0.45 * _get_ready_strength()) if icon_hovered else (0.32 + combined_strength * 0.40)
	var glow_color: Color = Color(ICON_GLOW.r, ICON_GLOW.g, ICON_GLOW.b, ICON_GLOW.a * glow_alpha)
	draw_rect(icon_rect.grow(7.0 + idle_strength * 2.0), glow_color, true)
	draw_rect(icon_rect.grow(13.0 + idle_strength * 3.0), Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.36), true)
	draw_rect(icon_rect, icon_fill, true)
	draw_rect(icon_rect, ICON_BORDER.lerp(BORDER_READY_COLOR, combined_strength), false, 2.0)
	if _can_draw_intervention_button_texture():
		var texture_rect: Rect2 = _get_texture_fit_rect(icon_rect.grow(-1.0), intervention_button_texture)
		var texture_tint: Color = Color.WHITE.lerp(BORDER_READY_COLOR, combined_strength * 0.12)
		draw_texture_rect(intervention_button_texture, texture_rect, false, texture_tint)
	else:
		_draw_event_icon_fallback(icon_rect, idle_strength)
	if pending_charges > 1:
		_draw_charge_badge(icon_rect)


func _update_icon_hover(local_position: Vector2) -> void:
	if _should_suppress_hover_ui():
		if icon_hovered:
			icon_hovered = false
			queue_redraw()
		return

	var next_hovered: bool = event_ready and _get_icon_rect(size).has_point(local_position)
	if icon_hovered == next_hovered:
		return
	icon_hovered = next_hovered
	queue_redraw()


func _is_icon_clickable() -> bool:
	return (
		not _should_suppress_hover_ui()
		and table_event_system != null
		and table_event_system.is_event_icon_clickable()
		and _get_icon_rect(size).has_point(get_local_mouse_position())
	)


func _is_cue_drag_active() -> bool:
	return table != null and table.is_cue_drag_active()


func _should_suppress_hover_ui() -> bool:
	return hover_ui_suppressed or (table != null and table.should_suppress_hover_ui())


func _get_bar_rect(draw_size: Vector2) -> Rect2:
	var bar_width: float = maxf(draw_size.x - BAR_LEFT - BAR_ICON_GAP - ICON_SIZE.x - ICON_RIGHT_MARGIN, 80.0)
	return Rect2(Vector2(BAR_LEFT, BAR_TOP), Vector2(bar_width, BAR_HEIGHT))


func _get_icon_rect(draw_size: Vector2) -> Rect2:
	var icon_position: Vector2 = Vector2(
		draw_size.x - ICON_RIGHT_MARGIN - ICON_SIZE.x,
		(draw_size.y - ICON_SIZE.y) * 0.5 + 4.0
	)
	return Rect2(icon_position, ICON_SIZE)


func _can_draw_intervention_button_texture() -> bool:
	if intervention_button_texture == null:
		return false
	var texture_size: Vector2 = intervention_button_texture.get_size()
	return texture_size.x > 0.0 and texture_size.y > 0.0


func _get_texture_fit_rect(container_rect: Rect2, texture: Texture2D) -> Rect2:
	if texture == null:
		return container_rect

	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return container_rect

	var scale_factor: float = minf(container_rect.size.x / texture_size.x, container_rect.size.y / texture_size.y)
	var fitted_size: Vector2 = texture_size * scale_factor
	return Rect2(container_rect.position + (container_rect.size - fitted_size) * 0.5, fitted_size)


func _draw_event_icon_fallback(icon_rect: Rect2, idle_strength: float) -> void:
	var center: Vector2 = icon_rect.get_center()
	draw_arc(center, 14.0 + idle_strength * 1.5, -PI * 0.15, TAU * 0.72, 36, FILL_READY_COLOR, 3.0)
	draw_circle(center, 4.0, BORDER_READY_COLOR)
	_draw_shadowed_text("!", center + Vector2(-4.0, 9.0), 24, BORDER_READY_COLOR)


func _draw_charge_badge(icon_rect: Rect2) -> void:
	var badge_rect := Rect2(icon_rect.end - Vector2(24.0, 17.0), Vector2(30.0, 18.0))
	draw_rect(badge_rect, Color(0.035, 0.022, 0.012, 0.96), true)
	draw_rect(badge_rect, BORDER_READY_COLOR, false, 1.5)
	draw_string(
		UI_FONT,
		badge_rect.position + Vector2(0.0, 14.0),
		"x%s" % pending_charges,
		HORIZONTAL_ALIGNMENT_CENTER,
		badge_rect.size.x,
		13,
		BORDER_READY_COLOR
	)


func _draw_shadowed_text(text: String, position: Vector2, font_size: int, color: Color) -> void:
	draw_string(UI_FONT, position + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, SHADOW_COLOR)
	draw_string(UI_FONT, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _get_displayed_segment_state() -> Dictionary:
	return _get_segment_state_for_absolute_progress(displayed_abs_progress)


func _get_segment_state_for_absolute_progress(absolute_progress: float) -> Dictionary:
	var remaining := maxf(absolute_progress, 0.0)
	var state_segment_index := 0
	for _guard in range(512):
		var segment_goal := _get_segment_goal_for_display(state_segment_index)
		if remaining < float(segment_goal):
			return _make_segment_state(state_segment_index, remaining, segment_goal)
		remaining -= float(segment_goal)
		state_segment_index += 1

	var fallback_goal := _get_segment_goal_for_display(state_segment_index)
	return _make_segment_state(state_segment_index, minf(remaining, float(fallback_goal)), fallback_goal)


func _make_segment_state(state_segment_index: int, segment_progress: float, segment_goal: int) -> Dictionary:
	var safe_goal := maxi(segment_goal, 1)
	var clamped_progress := clampf(segment_progress, 0.0, float(safe_goal))
	return {
		"segment_index": state_segment_index,
		"progress": int(floor(clamped_progress + 0.001)),
		"progress_float": clamped_progress,
		"goal": safe_goal,
		"percent": clampf(clamped_progress / float(safe_goal), 0.0, 1.0),
	}


func _get_segment_index_for_absolute_progress(absolute_progress: float) -> int:
	var displayed_state := _get_segment_state_for_absolute_progress(absolute_progress)
	return int(displayed_state.get("segment_index", 0))


func _get_absolute_progress_for_segment(state_segment_index: int, segment_progress: int) -> float:
	return _get_segment_absolute_start(state_segment_index) + float(clampi(segment_progress, 0, _get_segment_goal_for_display(state_segment_index)))


func _get_segment_absolute_start(state_segment_index: int) -> float:
	var absolute_start := 0.0
	for segment_offset in range(maxi(state_segment_index, 0)):
		absolute_start += float(_get_segment_goal_for_display(segment_offset))
	return absolute_start


func _get_segment_goal_for_display(state_segment_index: int) -> int:
	if table_event_system != null:
		return table_event_system.get_intervention_segment_goal(state_segment_index)
	return maxi(threshold, 1)


func _get_segment_fill_color(state_segment_index: int) -> Color:
	return _get_segment_fill_color_for_index(state_segment_index)


func _get_segment_base_color(state_segment_index: int) -> Color:
	if state_segment_index <= 0:
		return TRACK_COLOR

	var previous_color := _get_segment_fill_color_for_index(maxi(state_segment_index - 1, 0))
	var base_color := previous_color.darkened(0.44)
	base_color.a = 0.64
	return base_color


func _get_segment_fill_color_for_index(index: int) -> Color:
	if SEGMENT_FILL_COLORS.is_empty():
		return FILL_COLOR
	var color_index := posmod(maxi(index, 0), SEGMENT_FILL_COLORS.size())
	return SEGMENT_FILL_COLORS[color_index]


func _get_pulse_strength() -> float:
	if progress_pulse_remaining <= 0.0:
		return 0.0
	return sin(progress_pulse_remaining / PROGRESS_PULSE_TIME * PI)


func _get_event_earned_strength() -> float:
	if event_earned_flash_remaining <= 0.0:
		return 0.0
	return sin(event_earned_flash_remaining / EVENT_EARNED_FLASH_TIME * PI)


func _get_ready_strength() -> float:
	if ready_flash_remaining <= 0.0:
		return 0.0
	return sin(ready_flash_remaining / READY_FLASH_TIME * PI)


func _get_ready_idle_strength() -> float:
	if not event_ready:
		return 0.0
	return (0.5 + 0.5 * sin(ready_idle_phase)) * READY_IDLE_PULSE_ALPHA


func _disconnect_table_event_system() -> void:
	if table_event_system == null:
		return
	if table_event_system.meter_changed.is_connected(_on_meter_changed):
		table_event_system.meter_changed.disconnect(_on_meter_changed)
	if table_event_system.progress_advanced.is_connected(_on_progress_advanced):
		table_event_system.progress_advanced.disconnect(_on_progress_advanced)
	if table_event_system.pending_event_changed.is_connected(_on_pending_event_changed):
		table_event_system.pending_event_changed.disconnect(_on_pending_event_changed)
