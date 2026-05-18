extends Node
class_name BallAudioSystem

# Owns lightweight table SFX playback. Table reports collision events; this
# system filters, varies, and reuses players so chaos does not become audio spam.
const BALL_HIT_STREAMS: Array[AudioStream] = [
	preload("res://audio/sfx/billiards/ball_hit_01.wav"),
	preload("res://audio/sfx/billiards/ball_hit_02.wav"),
]
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
const DEFAULT_SFX_BUS_NAME := "SFX"

@export var audio_bus_name := DEFAULT_SFX_BUS_NAME

var table: BilliardsTable
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var players: Array[AudioStreamPlayer] = []
var next_player_index := 0
var sounds_played_this_frame := 0
var requests_this_frame := 0
var last_global_play_time_msec := -MIN_GLOBAL_INTERVAL_MSEC
var pair_last_played_msec: Dictionary = {}
var total_collision_audio_requests := 0
var total_collision_audio_plays := 0
var skipped_tiny_impacts := 0
var skipped_frame_limit := 0
var skipped_global_cooldown := 0
var skipped_pair_cooldown := 0
var pool_steals := 0
var max_players_playing := 0


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	if Engine.is_editor_hint():
		return
	AudioSettings.load_and_apply()
	if audio_bus_name == AudioSettings.MASTER_BUS_NAME:
		audio_bus_name = DEFAULT_SFX_BUS_NAME
	rng.randomize()
	_ensure_player_pool()


func reset_frame_stats() -> void:
	sounds_played_this_frame = 0
	requests_this_frame = 0


func handle_ball_collision(ball_a: Ball, ball_b: Ball, impact_speed: float) -> void:
	total_collision_audio_requests += 1
	requests_this_frame += 1
	if impact_speed < MIN_MEANINGFUL_IMPACT_SPEED:
		skipped_tiny_impacts += 1
		return
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

	_play_ball_hit_sound(impact_speed)
	sounds_played_this_frame += 1
	total_collision_audio_plays += 1
	last_global_play_time_msec = now_msec
	pair_last_played_msec[pair_key] = now_msec
	max_players_playing = maxi(max_players_playing, get_playing_player_count())
	if pair_last_played_msec.size() > MAX_TRACKED_PAIR_COOLDOWNS:
		_prune_pair_cooldowns(now_msec)


func _ensure_player_pool() -> void:
	while players.size() < PLAYER_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = audio_bus_name
		add_child(player)
		players.append(player)


func _play_ball_hit_sound(impact_speed: float) -> void:
	if BALL_HIT_STREAMS.is_empty():
		return

	var stream_index: int = rng.randi_range(0, BALL_HIT_STREAMS.size() - 1)
	var player: AudioStreamPlayer = _get_next_player()
	player.stream = BALL_HIT_STREAMS[stream_index]
	player.volume_db = _get_collision_volume_db(impact_speed)
	player.pitch_scale = rng.randf_range(MIN_PITCH_SCALE, MAX_PITCH_SCALE)
	player.play()


func _get_next_player() -> AudioStreamPlayer:
	if players.is_empty():
		_ensure_player_pool()

	for player in players:
		if not player.playing:
			return player

	var player: AudioStreamPlayer = players[next_player_index]
	next_player_index = (next_player_index + 1) % players.size()
	player.stop()
	pool_steals += 1
	return player


func _get_collision_volume_db(impact_speed: float) -> float:
	var normalized_intensity: float = clampf(
		(impact_speed - MIN_MEANINGFUL_IMPACT_SPEED)
		/ (MAX_VOLUME_IMPACT_SPEED - MIN_MEANINGFUL_IMPACT_SPEED),
		0.0,
		1.0
	)
	var shaped_intensity: float = sqrt(normalized_intensity)
	return lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, shaped_intensity)


func _get_ball_pair_key(ball_a: Ball, ball_b: Ball) -> String:
	var first_id: int = ball_a.get_instance_id()
	var second_id: int = ball_b.get_instance_id()
	if first_id > second_id:
		var temp_id: int = first_id
		first_id = second_id
		second_id = temp_id
	return "%s:%s" % [first_id, second_id]


func _prune_pair_cooldowns(now_msec: int) -> void:
	for pair_key in pair_last_played_msec.keys():
		var pair_time: int = int(pair_last_played_msec[pair_key])
		if now_msec - pair_time > PAIR_COOLDOWN_MEMORY_MSEC:
			pair_last_played_msec.erase(pair_key)
		if pair_last_played_msec.size() <= MAX_TRACKED_PAIR_COOLDOWNS:
			return


func get_playing_player_count() -> int:
	var playing_count: int = 0
	for player in players:
		if player.playing:
			playing_count += 1
	return playing_count


func get_debug_snapshot() -> Dictionary:
	return {
		"pool_size": players.size(),
		"playing_players": get_playing_player_count(),
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
	}
