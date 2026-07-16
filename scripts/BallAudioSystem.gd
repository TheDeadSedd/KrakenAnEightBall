extends Node
class_name BallAudioSystem

# Table reports collision events; this presentation-only owner filters them,
# chooses sampled/procedural layers, and reuses bounded player pools.
const PROCEDURAL_AUDIO_SCRIPT := preload("res://scripts/ProceduralBallCollisionAudio.gd")
const BALL_HIT_STREAMS: Array[AudioStream] = [
	preload("res://audio/sfx/billiards/ball_hit_01.wav"),
	preload("res://audio/sfx/billiards/ball_hit_02.wav"),
]
const MODE_SAMPLED := AudioSettings.COLLISION_MODE_SAMPLED
const MODE_PROCEDURAL := AudioSettings.COLLISION_MODE_PROCEDURAL
const MODE_LAYERED := AudioSettings.COLLISION_MODE_LAYERED
const MODE_CHOICES := [MODE_SAMPLED, MODE_PROCEDURAL, MODE_LAYERED]
const MATERIAL_DENSE_PHENOLIC := AudioSettings.COLLISION_MATERIAL_DENSE_PHENOLIC
const MATERIAL_SOLID_PHENOLIC_A_DRY := AudioSettings.COLLISION_MATERIAL_SOLID_PHENOLIC_A_DRY
const MATERIAL_SOLID_PHENOLIC_B_BALANCED := AudioSettings.COLLISION_MATERIAL_SOLID_PHENOLIC_B_BALANCED
const MATERIAL_SOLID_PHENOLIC_C_FULL := AudioSettings.COLLISION_MATERIAL_SOLID_PHENOLIC_C_FULL
const MATERIAL_SOLID_PHENOLIC_D_SHARP := AudioSettings.COLLISION_MATERIAL_SOLID_PHENOLIC_D_SHARP
const MATERIAL_RESONANT_RESIN_PROTOTYPE := AudioSettings.COLLISION_MATERIAL_RESONANT_RESIN_PROTOTYPE
const MATERIAL_BRIGHT_PROTOTYPE := AudioSettings.COLLISION_MATERIAL_BRIGHT_PROTOTYPE
const MATERIAL_CHOICES := [
	MATERIAL_SOLID_PHENOLIC_A_DRY,
	MATERIAL_SOLID_PHENOLIC_B_BALANCED,
	MATERIAL_SOLID_PHENOLIC_C_FULL,
	MATERIAL_SOLID_PHENOLIC_D_SHARP,
	MATERIAL_DENSE_PHENOLIC,
	MATERIAL_RESONANT_RESIN_PROTOTYPE,
	MATERIAL_BRIGHT_PROTOTYPE,
]
const SOLID_PHENOLIC_CANDIDATES := [
	MATERIAL_SOLID_PHENOLIC_A_DRY,
	MATERIAL_SOLID_PHENOLIC_B_BALANCED,
	MATERIAL_SOLID_PHENOLIC_C_FULL,
	MATERIAL_SOLID_PHENOLIC_D_SHARP,
]

# These constants are the original sampled path. Sampled mode intentionally
# retains them verbatim as the immediate safe fallback.
const PLAYER_POOL_SIZE := 8
const MIN_MEANINGFUL_IMPACT_SPEED := 70.0
const MAX_VOLUME_IMPACT_SPEED := 720.0
const MIN_VOLUME_DB := -18.0
const MAX_VOLUME_DB := -3.0
const MIN_PITCH_SCALE := 0.94
const MAX_PITCH_SCALE := 1.06
const MIN_GLOBAL_INTERVAL_MSEC := 30
const PAIR_COOLDOWN_MSEC := 90
const PAIR_COOLDOWN_MEMORY_MSEC := 1000
const MAX_SOUNDS_PER_FRAME := 3
const MAX_TRACKED_PAIR_COOLDOWNS := 384

const PROCEDURAL_PLAYER_POOL_CAPACITY := 32
const PROCEDURAL_PAIR_COOLDOWN_MSEC := 24
const PROCEDURAL_STRONGER_RECONTACT_MARGIN := 0.12
const PROCEDURAL_SOFT_DENSE_THRESHOLD := 0.22
const PROCEDURAL_DENSE_POOL_RATIO := 0.67
const PROCEDURAL_EVENT_SOFT_LIMIT_PER_FRAME := 8
const PROCEDURAL_EVENT_HARD_LIMIT_PER_FRAME := 16
const PROCEDURAL_MIN_VOLUME_DB := -19.0
const PROCEDURAL_MAX_VOLUME_DB := -4.5
const PROCEDURAL_BASE_MIN_PITCH := 0.985
const PROCEDURAL_BASE_MAX_PITCH := 1.015
const LAYERED_SAMPLED_GAIN_DB := -8.0
const LAYERED_SAMPLE_MIN_STRENGTH := 0.20
const LAYERED_SAMPLED_LIMIT_PER_FRAME := 3
const BANK_REGENERATION_DEBOUNCE_SECONDS := 0.35
const DEFAULT_SFX_BUS_NAME := "SFX"

# Offline PCM inspection at 44.1 kHz found signal at frame zero in both files.
# The second recording reaches its strong transient by frame four (0.09 ms),
# so neither source contains removable leading silence.
const SAMPLED_WAV_LEADING_SILENCE_MSEC := {
	"ball_hit_01": 0.0,
	"ball_hit_02": 0.0,
}
const SAMPLED_WAV_STRONG_TRANSIENT_MSEC := {
	"ball_hit_01": 0.0,
	"ball_hit_02": 0.09,
}
const SAMPLED_WAV_TRIMMED_MSEC := {
	"ball_hit_01": 0.0,
	"ball_hit_02": 0.0,
}

@export var audio_bus_name := DEFAULT_SFX_BUS_NAME

var table: BilliardsTable
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var procedural_runtime_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var procedural_generator
var material_audition_generators: Dictionary = {}
var collision_audio_mode := MODE_SAMPLED
var players: Array[AudioStreamPlayer] = []
var procedural_players: Array[AudioStreamPlayer2D] = []
var procedural_voice_strengths: Array[float] = []
var procedural_voice_limit := AudioSettings.DEFAULT_PROCEDURAL_COLLISION_VOICE_LIMIT
var regeneration_timer: Timer
var next_player_index := 0
var sounds_played_this_frame := 0
var requests_this_frame := 0
var layered_sampled_plays_this_frame := 0
var last_global_play_time_msec := -MIN_GLOBAL_INTERVAL_MSEC
var pair_last_played_msec: Dictionary = {}
var procedural_pair_state: Dictionary = {}
var total_collision_audio_requests := 0
var total_collision_audio_plays := 0
var sampled_play_requests := 0
var sampled_playback_count := 0
var sampled_layer_plays := 0
var procedural_layer_plays := 0
var skipped_tiny_impacts := 0
var skipped_frame_limit := 0
var skipped_global_cooldown := 0
var skipped_pair_cooldown := 0
var suppressed_weak_impacts := 0
var suppressed_repeated_pair_contacts := 0
var voice_budget_rejections := 0
var pool_steals := 0
var procedural_pool_steals := 0
var layered_sample_budget_skips := 0
var fallback_to_sampled_count := 0
var max_players_playing := 0
var max_procedural_players_playing := 0
var last_normalized_impact_strength := 0.0
var last_selected_band := -1
var last_selected_variant := -1
var last_collision_playback_volume_db := MIN_VOLUME_DB
var last_collision_point := Vector2.ZERO
var generation_failure_logged := false
var last_collision_to_play_request_delay_usec := 0
# The immediate sampled path keeps these at zero. Setup instrumentation makes
# any future lazy allocation visible without adding allocation to the hot path.
var deferred_sampled_play_count := 0
var impact_time_player_allocations := 0
var first_hit_initialization_count := 0


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	if Engine.is_editor_hint():
		return
	AudioSettings.load_and_apply()
	if audio_bus_name == AudioSettings.MASTER_BUS_NAME:
		audio_bus_name = DEFAULT_SFX_BUS_NAME
	rng.randomize()
	procedural_runtime_rng.randomize()
	collision_audio_mode = _sanitize_mode(AudioSettings.get_collision_mode())
	procedural_voice_limit = AudioSettings.get_procedural_collision_voice_limit()
	_ensure_player_pool()
	_ensure_procedural_player_pool()
	_ensure_regeneration_timer()
	procedural_generator = PROCEDURAL_AUDIO_SCRIPT.new()
	regenerate_procedural_bank()


func reset_frame_stats() -> void:
	sounds_played_this_frame = 0
	requests_this_frame = 0
	layered_sampled_plays_this_frame = 0


func handle_ball_collision(
	ball_a: Ball,
	ball_b: Ball,
	impact_speed: float,
	accepted_collision_usec: int = -1
) -> void:
	total_collision_audio_requests += 1
	requests_this_frame += 1
	if impact_speed < MIN_MEANINGFUL_IMPACT_SPEED:
		skipped_tiny_impacts += 1
		return

	var normalized_strength: float = get_normalized_impact_strength(impact_speed)
	var collision_point: Vector2 = (ball_a.global_position + ball_b.global_position) * 0.5
	last_normalized_impact_strength = normalized_strength
	last_collision_point = collision_point
	var collision_request_usec: int = accepted_collision_usec
	if collision_request_usec < 0:
		collision_request_usec = Time.get_ticks_usec()
	if collision_audio_mode == MODE_SAMPLED:
		_handle_sampled_collision(ball_a, ball_b, impact_speed, collision_request_usec)
	else:
		_handle_procedural_collision(
			ball_a,
			ball_b,
			impact_speed,
			normalized_strength,
			collision_point,
			collision_request_usec
		)


func set_collision_audio_mode(value: String) -> void:
	collision_audio_mode = _sanitize_mode(value)
	AudioSettings.set_collision_mode(collision_audio_mode)
	if collision_audio_mode != MODE_SAMPLED and not is_procedural_bank_ready():
		regenerate_procedural_bank()


func get_collision_audio_mode() -> String:
	return collision_audio_mode


func reset_collision_audio_settings() -> void:
	# Save happens in reset_procedural_tuning() after all in-memory defaults,
	# including Sampled mode, have been restored.
	AudioSettings.set_collision_mode(MODE_SAMPLED, false)
	collision_audio_mode = MODE_SAMPLED
	reset_procedural_tuning()


func set_procedural_material_profile(value: String) -> void:
	AudioSettings.set_procedural_collision_material(value)
	_clear_material_audition_banks()
	regenerate_procedural_bank()


func get_procedural_material_profile() -> String:
	return AudioSettings.get_procedural_collision_material()


func set_procedural_hardness(value: float) -> void:
	AudioSettings.set_procedural_collision_hardness(value)
	_clear_material_audition_banks()
	_schedule_bank_regeneration()


func get_procedural_hardness() -> float:
	return AudioSettings.get_procedural_collision_hardness()


func set_procedural_brightness(value: float) -> void:
	AudioSettings.set_procedural_collision_brightness(value)
	_clear_material_audition_banks()
	_schedule_bank_regeneration()


func get_procedural_brightness() -> float:
	return AudioSettings.get_procedural_collision_brightness()


func set_procedural_body(value: float) -> void:
	AudioSettings.set_procedural_collision_body(value)
	_clear_material_audition_banks()
	_schedule_bank_regeneration()


func get_procedural_body() -> float:
	return AudioSettings.get_procedural_collision_body()


func set_procedural_decay(value: float) -> void:
	AudioSettings.set_procedural_collision_decay(value)
	_clear_material_audition_banks()
	_schedule_bank_regeneration()


func get_procedural_decay() -> float:
	return AudioSettings.get_procedural_collision_decay()


func set_procedural_variation(value: float) -> void:
	AudioSettings.set_procedural_collision_variation(value)
	_clear_material_audition_banks()
	_schedule_bank_regeneration()


func get_procedural_variation() -> float:
	return AudioSettings.get_procedural_collision_variation()


func set_procedural_voice_limit(value: int) -> void:
	procedural_voice_limit = clampi(value, 4, PROCEDURAL_PLAYER_POOL_CAPACITY)
	AudioSettings.set_procedural_collision_voice_limit(procedural_voice_limit)
	for player_index in range(procedural_voice_limit, procedural_players.size()):
		procedural_players[player_index].stop()
		procedural_voice_strengths[player_index] = 0.0


func get_procedural_voice_limit() -> int:
	return procedural_voice_limit


func reset_procedural_tuning() -> void:
	AudioSettings.set_procedural_collision_material(
		AudioSettings.DEFAULT_PROCEDURAL_COLLISION_MATERIAL,
		false
	)
	AudioSettings.set_procedural_collision_hardness(
		AudioSettings.DEFAULT_PROCEDURAL_COLLISION_HARDNESS,
		false
	)
	AudioSettings.set_procedural_collision_brightness(
		AudioSettings.DEFAULT_PROCEDURAL_COLLISION_BRIGHTNESS,
		false
	)
	AudioSettings.set_procedural_collision_body(
		AudioSettings.DEFAULT_PROCEDURAL_COLLISION_BODY,
		false
	)
	AudioSettings.set_procedural_collision_decay(
		AudioSettings.DEFAULT_PROCEDURAL_COLLISION_DECAY,
		false
	)
	AudioSettings.set_procedural_collision_variation(
		AudioSettings.DEFAULT_PROCEDURAL_COLLISION_VARIATION,
		false
	)
	_clear_material_audition_banks()
	set_procedural_voice_limit(AudioSettings.DEFAULT_PROCEDURAL_COLLISION_VOICE_LIMIT)
	regenerate_procedural_bank()


func regenerate_procedural_bank() -> void:
	if procedural_generator == null:
		procedural_generator = PROCEDURAL_AUDIO_SCRIPT.new()
	var generated: bool = procedural_generator.generate_bank(_get_procedural_tuning())
	if generated:
		generation_failure_logged = false
		return
	_log_generation_failure_once()


func debug_play_soft_collision() -> void:
	_debug_play_normalized_collision(0.12)


func debug_play_medium_collision() -> void:
	_debug_play_normalized_collision(0.52)


func debug_play_hard_collision() -> void:
	_debug_play_normalized_collision(0.95)


func debug_play_collision_burst() -> void:
	var strengths: Array[float] = [
		0.05, 0.10, 0.16, 0.22, 0.30, 0.40, 0.52, 0.66,
		0.82, 1.0, 0.14, 0.28, 0.46, 0.64, 0.84, 0.98,
		0.08, 0.18, 0.26, 0.36, 0.48, 0.60, 0.74, 0.90,
		0.12, 0.24, 0.38, 0.54, 0.70, 0.86, 0.96, 1.0,
	]
	layered_sampled_plays_this_frame = 0
	for strength in strengths:
		_debug_play_normalized_collision(strength)


func debug_play_solid_phenolic_a_sequence() -> void:
	await _debug_play_material_strength_sequence(MATERIAL_SOLID_PHENOLIC_A_DRY)


func debug_play_solid_phenolic_b_sequence() -> void:
	await _debug_play_material_strength_sequence(MATERIAL_SOLID_PHENOLIC_B_BALANCED)


func debug_play_solid_phenolic_c_sequence() -> void:
	await _debug_play_material_strength_sequence(MATERIAL_SOLID_PHENOLIC_C_FULL)


func debug_play_solid_phenolic_d_sequence() -> void:
	await _debug_play_material_strength_sequence(MATERIAL_SOLID_PHENOLIC_D_SHARP)


func debug_compare_solid_phenolic_candidates() -> void:
	for material_profile_value in SOLID_PHENOLIC_CANDIDATES:
		var material_profile: String = str(material_profile_value)
		var generator: ProceduralBallCollisionAudio = _get_material_audition_generator(
			material_profile
		)
		if generator == null:
			continue
		for strength in [0.12, 0.52, 0.95]:
			_debug_play_procedural_generator(generator, float(strength))
			await get_tree().create_timer(0.22, true).timeout
		await get_tree().create_timer(0.38, true).timeout


func cycle_solid_phenolic_candidate() -> void:
	var current_profile: String = get_procedural_material_profile()
	var current_index: int = SOLID_PHENOLIC_CANDIDATES.find(current_profile)
	var next_index: int = 0
	if current_index >= 0:
		next_index = (current_index + 1) % SOLID_PHENOLIC_CANDIDATES.size()
	set_procedural_material_profile(str(SOLID_PHENOLIC_CANDIDATES[next_index]))


func debug_play_dense_phenolic_collision_sequence() -> void:
	var dense_generator: ProceduralBallCollisionAudio = _get_material_audition_generator(
		MATERIAL_DENSE_PHENOLIC
	)
	if dense_generator == null:
		return
	for strength in [0.12, 0.52, 0.95]:
		_debug_play_procedural_generator(dense_generator, float(strength))
		await get_tree().create_timer(0.24, true).timeout
	await get_tree().create_timer(0.12, true).timeout
	for strength in [0.18, 0.44, 0.78, 0.32, 0.94, 0.58]:
		_debug_play_procedural_generator(dense_generator, float(strength))
		await get_tree().create_timer(0.055, true).timeout


func debug_compare_material_profiles() -> void:
	var dense_generator: ProceduralBallCollisionAudio = _get_material_audition_generator(
		MATERIAL_DENSE_PHENOLIC
	)
	var resonant_generator: ProceduralBallCollisionAudio = _get_material_audition_generator(
		MATERIAL_RESONANT_RESIN_PROTOTYPE
	)
	var bright_generator: ProceduralBallCollisionAudio = _get_material_audition_generator(
		MATERIAL_BRIGHT_PROTOTYPE
	)
	if dense_generator == null or resonant_generator == null or bright_generator == null:
		return
	for strength in [0.12, 0.52, 0.95]:
		_debug_play_procedural_generator(dense_generator, float(strength))
		await get_tree().create_timer(0.20, true).timeout
		_debug_play_procedural_generator(resonant_generator, float(strength))
		await get_tree().create_timer(0.22, true).timeout
		_debug_play_procedural_generator(bright_generator, float(strength))
		await get_tree().create_timer(0.38, true).timeout


func _debug_play_material_strength_sequence(material_profile: String) -> void:
	var generator: ProceduralBallCollisionAudio = _get_material_audition_generator(
		material_profile
	)
	if generator == null:
		return
	for strength in [0.12, 0.52, 0.95]:
		_debug_play_procedural_generator(generator, float(strength))
		await get_tree().create_timer(0.22, true).timeout


func is_procedural_bank_ready() -> bool:
	return procedural_generator != null and procedural_generator.is_ready()


func get_normalized_impact_strength(impact_speed: float) -> float:
	return clampf(
		(impact_speed - MIN_MEANINGFUL_IMPACT_SPEED)
		/ (MAX_VOLUME_IMPACT_SPEED - MIN_MEANINGFUL_IMPACT_SPEED),
		0.0,
		1.0
	)


func _handle_sampled_collision(
	ball_a: Ball,
	ball_b: Ball,
	impact_speed: float,
	accepted_collision_usec: int
) -> void:
	if sounds_played_this_frame >= MAX_SOUNDS_PER_FRAME:
		skipped_frame_limit += 1
		return

	var now_msec: int = Time.get_ticks_msec()
	if now_msec - last_global_play_time_msec < MIN_GLOBAL_INTERVAL_MSEC:
		skipped_global_cooldown += 1
		return

	var pair_key: String = _get_ball_pair_key(ball_a, ball_b)
	var previous_pair_time: int = int(pair_last_played_msec.get(pair_key, -PAIR_COOLDOWN_MSEC))
	if now_msec - previous_pair_time < PAIR_COOLDOWN_MSEC:
		skipped_pair_cooldown += 1
		return

	if not _play_sampled_ball_hit(impact_speed, 0.0, accepted_collision_usec):
		return
	sounds_played_this_frame += 1
	total_collision_audio_plays += 1
	last_global_play_time_msec = now_msec
	pair_last_played_msec[pair_key] = now_msec
	max_players_playing = maxi(max_players_playing, get_sampled_playing_player_count())
	if pair_last_played_msec.size() > MAX_TRACKED_PAIR_COOLDOWNS:
		_prune_pair_cooldowns(now_msec, pair_last_played_msec)


func _handle_procedural_collision(
	ball_a: Ball,
	ball_b: Ball,
	impact_speed: float,
	normalized_strength: float,
	collision_point: Vector2,
	accepted_collision_usec: int
) -> void:
	if not is_procedural_bank_ready():
		_play_fallback_sampled(impact_speed, accepted_collision_usec)
		return
	if (
		sounds_played_this_frame >= PROCEDURAL_EVENT_HARD_LIMIT_PER_FRAME
		or (
			sounds_played_this_frame >= PROCEDURAL_EVENT_SOFT_LIMIT_PER_FRAME
			and normalized_strength < 0.70
		)
	):
		skipped_frame_limit += 1
		return

	var now_msec: int = Time.get_ticks_msec()
	var pair_key: String = _get_ball_pair_key(ball_a, ball_b)
	var previous_state: Dictionary = procedural_pair_state.get(pair_key, {})
	if not previous_state.is_empty():
		var previous_time: int = int(previous_state.get("time_msec", -PROCEDURAL_PAIR_COOLDOWN_MSEC))
		var previous_strength: float = float(previous_state.get("strength", 0.0))
		if (
			now_msec - previous_time < PROCEDURAL_PAIR_COOLDOWN_MSEC
			and normalized_strength < previous_strength + PROCEDURAL_STRONGER_RECONTACT_MARGIN
		):
			suppressed_repeated_pair_contacts += 1
			return

	var active_procedural_voices: int = get_procedural_playing_player_count()
	var dense_voice_threshold: int = maxi(
		int(ceil(float(procedural_voice_limit) * PROCEDURAL_DENSE_POOL_RATIO)),
		4
	)
	if (
		normalized_strength < PROCEDURAL_SOFT_DENSE_THRESHOLD
		and active_procedural_voices >= dense_voice_threshold
	):
		suppressed_weak_impacts += 1
		return

	var procedural_played: bool = _play_procedural_ball_hit(normalized_strength, collision_point)
	var sampled_played := false
	if (
		collision_audio_mode == MODE_LAYERED
		and normalized_strength >= LAYERED_SAMPLE_MIN_STRENGTH
		and layered_sampled_plays_this_frame < LAYERED_SAMPLED_LIMIT_PER_FRAME
	):
		_play_sampled_ball_hit(
			impact_speed,
			LAYERED_SAMPLED_GAIN_DB,
			accepted_collision_usec
		)
		layered_sampled_plays_this_frame += 1
		sampled_played = true
	elif collision_audio_mode == MODE_LAYERED and normalized_strength >= LAYERED_SAMPLE_MIN_STRENGTH:
		layered_sample_budget_skips += 1

	if not procedural_played and not sampled_played:
		return
	sounds_played_this_frame += 1
	total_collision_audio_plays += 1
	procedural_pair_state[pair_key] = {
		"time_msec": now_msec,
		"strength": normalized_strength,
	}
	max_procedural_players_playing = maxi(
		max_procedural_players_playing,
		get_procedural_playing_player_count()
	)
	max_players_playing = maxi(max_players_playing, get_sampled_playing_player_count())
	if procedural_pair_state.size() > MAX_TRACKED_PAIR_COOLDOWNS:
		_prune_pair_cooldowns(now_msec, procedural_pair_state)


func _ensure_player_pool() -> void:
	if BALL_HIT_STREAMS.is_empty():
		return
	var late_initialization: bool = (
		players.size() < PLAYER_POOL_SIZE
		and total_collision_audio_requests > 0
	)
	if late_initialization and sampled_playback_count == 0:
		first_hit_initialization_count += 1
	while players.size() < PLAYER_POOL_SIZE:
		if late_initialization:
			impact_time_player_allocations += 1
		var player_index: int = players.size()
		var player := AudioStreamPlayer.new()
		player.name = "SampledBallCollisionPlayer%s" % (player_index + 1)
		player.bus = audio_bus_name
		# Assign a cached preload during setup so even the first player is fully
		# initialized before an authoritative impact arrives.
		player.stream = BALL_HIT_STREAMS[player_index % BALL_HIT_STREAMS.size()]
		add_child(player)
		players.append(player)


func _ensure_procedural_player_pool() -> void:
	while procedural_players.size() < PROCEDURAL_PLAYER_POOL_CAPACITY:
		var player := AudioStreamPlayer2D.new()
		player.bus = audio_bus_name
		player.attenuation = 0.0
		player.max_distance = 100000.0
		player.panning_strength = 0.22
		add_child(player)
		procedural_players.append(player)
		procedural_voice_strengths.append(0.0)


func _ensure_regeneration_timer() -> void:
	if regeneration_timer != null:
		return
	regeneration_timer = Timer.new()
	regeneration_timer.name = "ProceduralCollisionBankRegenerationTimer"
	regeneration_timer.one_shot = true
	regeneration_timer.wait_time = BANK_REGENERATION_DEBOUNCE_SECONDS
	regeneration_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	regeneration_timer.timeout.connect(regenerate_procedural_bank)
	add_child(regeneration_timer)


func _play_sampled_ball_hit(
	impact_speed: float,
	gain_offset_db: float = 0.0,
	accepted_collision_usec: int = -1
) -> bool:
	sampled_play_requests += 1
	if BALL_HIT_STREAMS.is_empty():
		return false

	var stream_index: int = rng.randi_range(0, BALL_HIT_STREAMS.size() - 1)
	var player: AudioStreamPlayer = _get_next_player()
	if player == null:
		return false
	# BALL_HIT_STREAMS contains preloaded resources; this selection performs no
	# runtime disk load or stream construction.
	player.stream = BALL_HIT_STREAMS[stream_index]
	player.volume_db = _get_collision_volume_db(impact_speed) + gain_offset_db
	player.pitch_scale = rng.randf_range(MIN_PITCH_SCALE, MAX_PITCH_SCALE)
	if accepted_collision_usec >= 0:
		last_collision_to_play_request_delay_usec = maxi(
			Time.get_ticks_usec() - accepted_collision_usec,
			0
		)
	player.play()
	sampled_playback_count += 1
	sampled_layer_plays += 1
	last_collision_playback_volume_db = player.volume_db
	return true


func _play_procedural_ball_hit(normalized_strength: float, collision_point: Vector2) -> bool:
	if procedural_generator == null or not procedural_generator.is_ready():
		return false
	return _play_procedural_generator(
		procedural_generator,
		normalized_strength,
		collision_point
	)


func _play_procedural_generator(
	generator,
	normalized_strength: float,
	collision_point: Vector2
) -> bool:
	var player_index: int = _get_procedural_player_index(normalized_strength)
	if player_index < 0:
		voice_budget_rejections += 1
		return false

	var variation_scale: float = get_procedural_variation()
	var variant_index: int = procedural_runtime_rng.randi_range(
		0,
		PROCEDURAL_AUDIO_SCRIPT.VARIANTS_PER_BAND - 1
	)
	var player: AudioStreamPlayer2D = procedural_players[player_index]
	player.stream = generator.get_stream(normalized_strength, variant_index)
	if player.stream == null:
		return false
	player.position = collision_point
	player.volume_db = _get_procedural_volume_db(normalized_strength)
	var authored_pitch: float = lerpf(
		PROCEDURAL_BASE_MAX_PITCH,
		PROCEDURAL_BASE_MIN_PITCH,
		normalized_strength
	)
	var pitch_variation: float = 0.012 * variation_scale
	player.pitch_scale = authored_pitch * procedural_runtime_rng.randf_range(
		1.0 - pitch_variation,
		1.0 + pitch_variation
	)
	procedural_voice_strengths[player_index] = normalized_strength
	player.play()
	procedural_layer_plays += 1
	last_selected_band = generator.get_band_for_strength(normalized_strength)
	last_selected_variant = variant_index
	last_collision_playback_volume_db = player.volume_db
	return true


func _get_next_player() -> AudioStreamPlayer:
	if players.is_empty():
		return null

	for player in players:
		if not player.playing:
			return player

	var player: AudioStreamPlayer = players[next_player_index]
	next_player_index = (next_player_index + 1) % players.size()
	player.stop()
	pool_steals += 1
	return player


func _get_procedural_player_index(normalized_strength: float) -> int:
	_ensure_procedural_player_pool()
	var active_limit: int = mini(procedural_voice_limit, procedural_players.size())
	for player_index in range(active_limit):
		if not procedural_players[player_index].playing:
			return player_index

	var weakest_index := -1
	var weakest_strength := INF
	for player_index in range(active_limit):
		var voice_strength: float = procedural_voice_strengths[player_index]
		if voice_strength < weakest_strength:
			weakest_strength = voice_strength
			weakest_index = player_index
	if weakest_index < 0 or normalized_strength <= weakest_strength:
		return -1
	procedural_players[weakest_index].stop()
	procedural_pool_steals += 1
	return weakest_index


func _get_collision_volume_db(impact_speed: float) -> float:
	var normalized_intensity: float = get_normalized_impact_strength(impact_speed)
	var shaped_intensity: float = sqrt(normalized_intensity)
	return lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, shaped_intensity)


func _get_procedural_volume_db(normalized_strength: float) -> float:
	var shaped_strength: float = sqrt(clampf(normalized_strength, 0.0, 1.0))
	return lerpf(PROCEDURAL_MIN_VOLUME_DB, PROCEDURAL_MAX_VOLUME_DB, shaped_strength)


func _get_ball_pair_key(ball_a: Ball, ball_b: Ball) -> String:
	var first_id: int = ball_a.get_instance_id()
	var second_id: int = ball_b.get_instance_id()
	if first_id > second_id:
		var temp_id: int = first_id
		first_id = second_id
		second_id = temp_id
	return "%s:%s" % [first_id, second_id]


func _prune_pair_cooldowns(now_msec: int, cooldowns: Dictionary) -> void:
	for pair_key in cooldowns.keys():
		var value: Variant = cooldowns[pair_key]
		var pair_time: int
		if value is Dictionary:
			pair_time = int((value as Dictionary).get("time_msec", 0))
		else:
			pair_time = int(value)
		if now_msec - pair_time > PAIR_COOLDOWN_MEMORY_MSEC:
			cooldowns.erase(pair_key)
		if cooldowns.size() <= MAX_TRACKED_PAIR_COOLDOWNS:
			return


func _schedule_bank_regeneration() -> void:
	_ensure_regeneration_timer()
	regeneration_timer.start(BANK_REGENERATION_DEBOUNCE_SECONDS)


func _get_procedural_tuning() -> Dictionary:
	return {
		"material_profile": get_procedural_material_profile(),
		"hardness": get_procedural_hardness(),
		"brightness": get_procedural_brightness(),
		"body": get_procedural_body(),
		"decay": get_procedural_decay(),
		"variation": get_procedural_variation(),
	}


func _get_material_audition_generator(
	material_profile: String
) -> ProceduralBallCollisionAudio:
	var cached_value: Variant = material_audition_generators.get(material_profile)
	if cached_value is ProceduralBallCollisionAudio:
		return cached_value as ProceduralBallCollisionAudio
	var generator := ProceduralBallCollisionAudio.new()
	var audition_tuning: Dictionary = _get_procedural_tuning()
	audition_tuning["material_profile"] = material_profile
	if not generator.generate_bank(audition_tuning):
		return null
	material_audition_generators[material_profile] = generator
	return generator


func _clear_material_audition_banks() -> void:
	material_audition_generators.clear()


func _sanitize_mode(value: String) -> String:
	if value in MODE_CHOICES:
		return value
	return MODE_SAMPLED


func _play_fallback_sampled(impact_speed: float, accepted_collision_usec: int = -1) -> void:
	fallback_to_sampled_count += 1
	_log_generation_failure_once()
	if not _play_sampled_ball_hit(impact_speed, 0.0, accepted_collision_usec):
		return
	sounds_played_this_frame += 1
	total_collision_audio_plays += 1


func _log_generation_failure_once() -> void:
	if generation_failure_logged:
		return
	generation_failure_logged = true
	push_warning("Procedural collision audio bank unavailable; using sampled collision audio.")


func _debug_play_normalized_collision(normalized_strength: float) -> void:
	var strength: float = clampf(normalized_strength, 0.0, 1.0)
	var impact_speed: float = lerpf(
		MIN_MEANINGFUL_IMPACT_SPEED,
		MAX_VOLUME_IMPACT_SPEED,
		strength
	)
	last_normalized_impact_strength = strength
	var collision_point: Vector2 = get_viewport().get_visible_rect().get_center()
	last_collision_point = collision_point
	if collision_audio_mode == MODE_SAMPLED or not is_procedural_bank_ready():
		_play_sampled_ball_hit(impact_speed)
		return
	_play_procedural_ball_hit(strength, collision_point)
	if (
		collision_audio_mode == MODE_LAYERED
		and strength >= LAYERED_SAMPLE_MIN_STRENGTH
		and layered_sampled_plays_this_frame < LAYERED_SAMPLED_LIMIT_PER_FRAME
	):
		_play_sampled_ball_hit(impact_speed, LAYERED_SAMPLED_GAIN_DB)
		layered_sampled_plays_this_frame += 1


func _debug_play_procedural_generator(
	generator: ProceduralBallCollisionAudio,
	normalized_strength: float
) -> void:
	var strength: float = clampf(normalized_strength, 0.0, 1.0)
	last_normalized_impact_strength = strength
	var collision_point: Vector2 = get_viewport().get_visible_rect().get_center()
	last_collision_point = collision_point
	_play_procedural_generator(generator, strength, collision_point)


func get_sampled_playing_player_count() -> int:
	var playing_count := 0
	for player in players:
		if player.playing:
			playing_count += 1
	return playing_count


func is_sampled_player_pool_ready() -> bool:
	if players.size() != PLAYER_POOL_SIZE or BALL_HIT_STREAMS.is_empty():
		return false
	for player in players:
		if (
			player == null
			or not is_instance_valid(player)
			or player.stream == null
			or player.bus != audio_bus_name
		):
			return false
	return true


func get_procedural_playing_player_count() -> int:
	var playing_count := 0
	for player_index in range(procedural_players.size()):
		if procedural_players[player_index].playing:
			playing_count += 1
		else:
			procedural_voice_strengths[player_index] = 0.0
	return playing_count


func get_playing_player_count() -> int:
	return get_sampled_playing_player_count() + get_procedural_playing_player_count()


func get_debug_snapshot() -> Dictionary:
	var generator_snapshot: Dictionary = {}
	if procedural_generator != null:
		generator_snapshot = procedural_generator.get_debug_snapshot()
	return {
		# Legacy keys remain available to existing performance views.
		"pool_size": players.size(),
		"playing_players": get_sampled_playing_player_count(),
		"max_players_playing": max_players_playing,
		"requests_this_frame": requests_this_frame,
		"sounds_played_this_frame": sounds_played_this_frame,
		"total_requests": total_collision_audio_requests,
		"total_plays": total_collision_audio_plays,
		"skipped_tiny_impacts": skipped_tiny_impacts,
		"skipped_frame_limit": skipped_frame_limit,
		"skipped_global_cooldown": skipped_global_cooldown,
		"skipped_pair_cooldown": skipped_pair_cooldown,
		"pool_steals": pool_steals,
		# Immediate sampled-path readiness and latency diagnostics.
		"default_mode": AudioSettings.DEFAULT_COLLISION_MODE,
		"sampled_play_requests": sampled_play_requests,
		"sampled_playback_count": sampled_playback_count,
		"sampled_pool_ready": is_sampled_player_pool_ready(),
		"sampled_pool_target_size": PLAYER_POOL_SIZE,
		"last_collision_to_play_request_delay_usec": last_collision_to_play_request_delay_usec,
		"deferred_sampled_play_count": deferred_sampled_play_count,
		"impact_time_player_allocations": impact_time_player_allocations,
		"first_hit_initialization_count": first_hit_initialization_count,
		"sampled_wav_leading_silence_msec": SAMPLED_WAV_LEADING_SILENCE_MSEC.duplicate(),
		"sampled_wav_strong_transient_msec": SAMPLED_WAV_STRONG_TRANSIENT_MSEC.duplicate(),
		"sampled_wav_trimmed_msec": SAMPLED_WAV_TRIMMED_MSEC.duplicate(),
		# Procedural/layered diagnostics.
		"mode": collision_audio_mode,
		"effective_mode": collision_audio_mode if is_procedural_bank_ready() else MODE_SAMPLED,
		"generated_bank_ready": bool(generator_snapshot.get("ready", false)),
		"sample_rate": int(generator_snapshot.get("sample_rate", 0)),
		"strength_band_count": int(generator_snapshot.get("strength_band_count", 0)),
		"variants_per_band": int(generator_snapshot.get("variants_per_band", 0)),
		"generated_stream_count": int(generator_snapshot.get("generated_stream_count", 0)),
		"material_profile": str(generator_snapshot.get(
			"material_profile",
			get_procedural_material_profile()
		)),
		"generated_primary_frequency_min_hz": float(generator_snapshot.get(
			"generated_primary_frequency_min_hz",
			0.0
		)),
		"generated_primary_frequency_max_hz": float(generator_snapshot.get(
			"generated_primary_frequency_max_hz",
			0.0
		)),
		"generated_secondary_frequency_min_hz": float(generator_snapshot.get(
			"generated_secondary_frequency_min_hz",
			0.0
		)),
		"generated_secondary_frequency_max_hz": float(generator_snapshot.get(
			"generated_secondary_frequency_max_hz",
			0.0
		)),
		"generated_body_frequency_min_hz": float(generator_snapshot.get(
			"generated_body_frequency_min_hz",
			0.0
		)),
		"generated_body_frequency_max_hz": float(generator_snapshot.get(
			"generated_body_frequency_max_hz",
			0.0
		)),
		"generated_duration_min_ms": float(generator_snapshot.get(
			"generated_duration_min_ms",
			0.0
		)),
		"generated_duration_max_ms": float(generator_snapshot.get(
			"generated_duration_max_ms",
			0.0
		)),
		"generated_transient_min_ms": float(generator_snapshot.get(
			"generated_transient_min_ms",
			0.0
		)),
		"generated_transient_max_ms": float(generator_snapshot.get(
			"generated_transient_max_ms",
			0.0
		)),
		"authored_duration_min_ms": float(generator_snapshot.get(
			"authored_duration_min_ms",
			0.0
		)),
		"authored_duration_max_ms": float(generator_snapshot.get(
			"authored_duration_max_ms",
			0.0
		)),
		"authored_transient_min_ms": float(generator_snapshot.get(
			"authored_transient_min_ms",
			0.0
		)),
		"authored_transient_max_ms": float(generator_snapshot.get(
			"authored_transient_max_ms",
			0.0
		)),
		"body_to_primary_amplitude_ratio": float(generator_snapshot.get(
			"body_to_primary_amplitude_ratio",
			0.0
		)),
		"modal_count": int(generator_snapshot.get("modal_count", 0)),
		"modal_frequency_min_hz": float(generator_snapshot.get(
			"modal_frequency_min_hz",
			0.0
		)),
		"modal_frequency_max_hz": float(generator_snapshot.get(
			"modal_frequency_max_hz",
			0.0
		)),
		"modal_decay_min_ms": float(generator_snapshot.get(
			"modal_decay_min_ms",
			0.0
		)),
		"modal_decay_max_ms": float(generator_snapshot.get(
			"modal_decay_max_ms",
			0.0
		)),
		"micro_impulse_separation_min_ms": float(generator_snapshot.get(
			"micro_impulse_separation_min_ms",
			0.0
		)),
		"micro_impulse_separation_max_ms": float(generator_snapshot.get(
			"micro_impulse_separation_max_ms",
			0.0
		)),
		"low_body_frequency_min_hz": float(generator_snapshot.get(
			"low_body_frequency_min_hz",
			0.0
		)),
		"low_body_frequency_max_hz": float(generator_snapshot.get(
			"low_body_frequency_max_hz",
			0.0
		)),
		"low_body_relative_amplitude_min": float(generator_snapshot.get(
			"low_body_relative_amplitude_min",
			0.0
		)),
		"low_body_relative_amplitude_max": float(generator_snapshot.get(
			"low_body_relative_amplitude_max",
			0.0
		)),
		"candidate_name": str(generator_snapshot.get("candidate_name", "")),
		"modal_center_frequencies_hz": generator_snapshot.get(
			"modal_center_frequencies_hz",
			PackedFloat32Array()
		),
		"secondary_pulse_enabled": bool(generator_snapshot.get(
			"secondary_pulse_enabled",
			false
		)),
		"compression_impulse_level": float(generator_snapshot.get(
			"compression_impulse_level",
			0.0
		)),
		"table_coupling_level": float(generator_snapshot.get(
			"table_coupling_level",
			0.0
		)),
		"highpass_cutoff_hz": float(generator_snapshot.get(
			"highpass_cutoff_hz",
			0.0
		)),
		"saturation_amount": float(generator_snapshot.get(
			"saturation_amount",
			0.0
		)),
		"material_tail_retained": bool(generator_snapshot.get(
			"material_tail_retained",
			false
		)),
		"active_procedural_voices": get_procedural_playing_player_count(),
		"active_sampled_voices": get_sampled_playing_player_count(),
		"max_procedural_voices": max_procedural_players_playing,
		"procedural_voice_limit": procedural_voice_limit,
		"sampled_layer_plays": sampled_layer_plays,
		"procedural_layer_plays": procedural_layer_plays,
		"suppressed_weak_impacts": suppressed_weak_impacts,
		"suppressed_repeated_pair_contacts": suppressed_repeated_pair_contacts,
		"voice_budget_rejections": voice_budget_rejections,
		"procedural_pool_steals": procedural_pool_steals,
		"layered_sample_budget_skips": layered_sample_budget_skips,
		"fallback_to_sampled_count": fallback_to_sampled_count,
		"last_normalized_impact_strength": last_normalized_impact_strength,
		"last_selected_band": last_selected_band,
		"last_selected_variant": last_selected_variant,
		"last_collision_playback_volume_db": last_collision_playback_volume_db,
		"last_collision_point": last_collision_point,
		"bank_generation_duration_ms": float(generator_snapshot.get("generation_duration_ms", 0.0)),
		"bank_generation_count": int(generator_snapshot.get("generation_count", 0)),
	}
