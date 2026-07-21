extends Node
class_name RogueliteScoringCueConductor

## Shared sampled-audio conductor for live anticipation and authoritative replay.
## Begin one sequence, submit value-only cue requests, then complete or cancel it.
## The conductor owns no scoring rules and never subscribes to gameplay events itself.

signal cue_started(snapshot: Dictionary)
signal cue_coalesced(snapshot: Dictionary)
signal cue_dropped(snapshot: Dictionary)
signal conductor_canceled(reason: String, snapshot: Dictionary)
signal state_changed(snapshot: Dictionary)

const MAIN_CUE_STREAM_A := preload("res://audio/sfx/billiards/ball_hit_01.wav")
const MAIN_CUE_STREAM_B := preload("res://audio/sfx/billiards/ball_hit_02.wav")
const POCKET_CUE_STREAM := preload("res://audio/sfx/environment/pocket_multi.wav")

const MODE_IDLE := "idle"
const MODE_LIVE := "live"
const MODE_REPLAY := "replay"

const CUE_BANK_1 := "bank_1"
const CUE_BANK_2 := "bank_2"
const CUE_BANK_3 := "bank_3"
const CUE_COMBINATION := "combination"
const CUE_DOUBLE_TAP := "double_tap"
const CUE_TRIPLE_TAP := "triple_tap"
const CUE_BALL_TAP := "ball_tap"
const CUE_BALL_TAP_CHAIN := "ball_tap_chain"
const CUE_POCKET := "pocket"
const CUE_MULTI_POT := "multi_pot"
const CUE_MAJOR_COMPLETION := "major_completion"
const CUE_REPLAY_TICK := "replay_tick"

const MAIN_VOICE_COUNT := 12
const BASS_VOICE_COUNT := 6
const MAX_LOGICAL_LANES := 8
const MAX_PENDING_REQUESTS := 64
const ARBITRATION_WINDOW_USEC := 30000
const LOWER_PRIORITY_STAGGER_USEC := 6000
const MAX_STAGGER_USEC := 24000
const TAP_MOTIF_BEAT_INTERVAL_USEC := 46000

const PRIORITY_MAJOR_COMPLETION := 500
const PRIORITY_SCORING_POCKET := 400
const PRIORITY_SECOND_TIER := 300
const PRIORITY_COMBINATION := 200
const PRIORITY_FIRST_TIER := 100
const PRIORITY_REPLAY_TICK := 80

const MAX_GLOBAL_EXCITEMENT := 16.0
const MAX_EXCITEMENT_PITCH_OFFSET := 0.18
const MAX_EXCITEMENT_GAIN_DB := 3.0
const MAX_EXCITEMENT_BASS_GAIN_DB := 2.5
const BASE_REVERB_WET := 0.07
const MAX_EXCITEMENT_REVERB_WET_BONUS := 0.06
const MAIN_MIN_PITCH := 0.72
const MAIN_MAX_PITCH := 1.48
const BASS_PITCH_RATIO := 0.62
const MAIN_MIN_VOLUME_DB := -36.0
const MAIN_MAX_VOLUME_DB := -13.0
const BASS_MIN_VOLUME_DB := -34.0
const BASS_MAX_VOLUME_DB := -18.0

const MAIN_BUS_NAME := "RogueliteScoringCue"
const BASS_BUS_NAME := "RogueliteScoringCueBass"
const MAIN_PANNING_STRENGTH := 0.26
const BASS_PANNING_STRENGTH := 0.12
const AUDIO_MAX_DISTANCE := 4096.0
const AUDIO_ATTENUATION := 0.15

const REVERB_ROOM_SIZE := 0.28
const REVERB_DAMPING := 0.88
const REVERB_SPREAD := 0.32
const REVERB_HIPASS := 0.14
const REVERB_PREDELAY_MSEC := 2.0
const BASS_LOWPASS_HZ := 900.0

var enabled := true
var audio_enabled := true
var global_excitement_enabled := true
var global_excitement_strength := 1.0
var cancel_on_tree_pause := true

var current_mode := MODE_IDLE
var current_shot_id := -1
var current_attempt_id := -1
var logical_lanes: Dictionary = {}
var global_excitement := 0.0
var peak_global_excitement := 0.0
var session_peak_global_excitement := 0.0

var pending_requests: Array[Dictionary] = []
var scheduled_requests: Array[Dictionary] = []
var request_serial := 0
var pause_latched := false

var main_players: Array[AudioStreamPlayer2D] = []
var bass_players: Array[AudioStreamPlayer2D] = []
var main_voice_states: Array[Dictionary] = []
var bass_voice_states: Array[Dictionary] = []
var next_main_voice_index := 0
var next_bass_voice_index := 0
var main_bus_index := -1
var bass_bus_index := -1
var reverb_effect_index := -1
var reverb_effect: AudioEffectReverb
var audio_effects_available := false

var requests_total := 0
var live_requests_total := 0
var replay_requests_total := 0
var cues_played_total := 0
var cues_coalesced_total := 0
var cues_dropped_total := 0
var bass_cues_dropped_total := 0
var voices_preempted_total := 0
var arbitration_batches_total := 0
var lane_overflow_total := 0
var cancellation_total := 0
var max_simultaneous_main_voices := 0
var max_simultaneous_bass_voices := 0
var max_simultaneous_voices := 0
var max_simultaneous_requests := 0
var motif_followup_beats_played_total := 0
var motif_followup_beats_dropped_total := 0
var request_counts_by_kind: Dictionary = {}
var played_counts_by_kind: Dictionary = {}
var coalesced_counts_by_kind: Dictionary = {}
var dropped_counts_by_kind: Dictionary = {}

var current_sequence_requests := 0
var current_sequence_played := 0
var current_sequence_coalesced := 0
var current_sequence_dropped := 0
var current_sequence_peak_excitement := 0.0
var current_sequence_request_counts_by_kind: Dictionary = {}
var current_sequence_played_counts_by_kind: Dictionary = {}
var current_sequence_coalesced_counts_by_kind: Dictionary = {}
var current_sequence_dropped_counts_by_kind: Dictionary = {}
var last_sequence_snapshot: Dictionary = {}
var last_cue_snapshot: Dictionary = {}
var last_cancel_reason := ""
var last_self_test_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_audio_pools()
	set_process(false)


func _process(_delta: float) -> void:
	var tree: SceneTree = get_tree()
	if cancel_on_tree_pause and tree != null and tree.paused:
		if not pause_latched:
			pause_latched = true
			pending_requests.clear()
			scheduled_requests.clear()
			_stop_all_voices()
		return
	pause_latched = false

	var now_usec: int = Time.get_ticks_usec()
	_refresh_voice_states()
	_process_pending_requests(now_usec)
	_process_scheduled_requests(now_usec)
	_update_simultaneous_voice_diagnostics()
	if pending_requests.is_empty() and scheduled_requests.is_empty() and not _has_playing_voice():
		set_process(false)


func _exit_tree() -> void:
	_cancel_internal("teardown", false)


func begin_live_shot(
	shot_id: int,
	attempt_id: int,
	scoring_ball_plans: Array = [],
	initial_excitement: float = 0.0
) -> Dictionary:
	_begin_sequence(MODE_LIVE, shot_id, attempt_id, scoring_ball_plans, initial_excitement)
	return get_state_snapshot()


func begin_replay(
	shot_id: int,
	attempt_id: int,
	ball_narratives: Array = [],
	inherited_excitement: float = -1.0
) -> Dictionary:
	var replay_excitement: float = global_excitement
	if inherited_excitement >= 0.0:
		replay_excitement = inherited_excitement
	_begin_sequence(MODE_REPLAY, shot_id, attempt_id, ball_narratives, replay_excitement)
	return get_state_snapshot()


func register_lane(ball_id: int, planned_final_tier: int = 0) -> bool:
	if ball_id < 0:
		return false
	if logical_lanes.has(ball_id):
		var existing: Dictionary = logical_lanes[ball_id]
		existing["planned_final_tier"] = maxi(
			int(existing.get("planned_final_tier", 0)),
			planned_final_tier
		)
		logical_lanes[ball_id] = existing
		return true
	if logical_lanes.size() >= MAX_LOGICAL_LANES:
		lane_overflow_total += 1
		return false
	logical_lanes[ball_id] = {
		"ball_id": ball_id,
		"planned_final_tier": maxi(planned_final_tier, 0),
		"current_matched_milestone": 0,
		"last_cue_usec": 0,
		"last_cue_kind": "",
		"last_pitch": 0.0,
		"request_count": 0,
		"played_count": 0,
		"diverged": false,
		"divergence_reason": "",
		"seen_cue_keys": {},
	}
	return true


func mark_lane_diverged(ball_id: int, reason: String = "prediction_diverged") -> void:
	if not logical_lanes.has(ball_id):
		return
	var lane: Dictionary = logical_lanes[ball_id]
	lane["diverged"] = true
	lane["divergence_reason"] = reason
	logical_lanes[ball_id] = lane
	state_changed.emit(get_state_snapshot())


func request_live_cue(
	ball_id: int,
	cue_kind: String,
	world_position: Vector2,
	metadata: Dictionary = {}
) -> bool:
	return _request_cue(MODE_LIVE, ball_id, cue_kind, world_position, metadata)


func request_replay_cue(
	ball_id: int,
	cue_kind: String,
	world_position: Vector2,
	metadata: Dictionary = {}
) -> bool:
	return _request_cue(MODE_REPLAY, ball_id, cue_kind, world_position, metadata)


func flush_pending_cues() -> void:
	if pending_requests.is_empty():
		return
	_arbitrate_batch(_take_all_pending_requests(), Time.get_ticks_usec())
	_process_scheduled_requests(Time.get_ticks_usec())


func complete_sequence(stop_active_audio: bool = false) -> Dictionary:
	_archive_current_sequence("completed")
	pending_requests.clear()
	scheduled_requests.clear()
	logical_lanes.clear()
	current_mode = MODE_IDLE
	current_shot_id = -1
	current_attempt_id = -1
	global_excitement = 0.0
	peak_global_excitement = 0.0
	if stop_active_audio:
		_stop_all_voices()
	if not _has_playing_voice():
		set_process(false)
	state_changed.emit(get_state_snapshot())
	return last_sequence_snapshot.duplicate(true)


func cancel_all(reason: String = "canceled") -> void:
	_cancel_internal(reason, true)


func set_conductor_paused(value: bool) -> void:
	if value:
		pause_latched = true
		cancel_all("explicit_pause")
	else:
		pause_latched = false


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		cancel_all("disabled")


func set_audio_enabled(value: bool) -> void:
	audio_enabled = value
	if not audio_enabled:
		cancel_all("audio_disabled")


func set_global_excitement_enabled(value: bool) -> void:
	global_excitement_enabled = value
	if not global_excitement_enabled:
		global_excitement = 0.0
		peak_global_excitement = 0.0
		current_sequence_peak_excitement = 0.0


func set_global_excitement_strength(value: float) -> void:
	global_excitement_strength = clampf(value, 0.0, 2.0)


func reset_diagnostics() -> void:
	requests_total = 0
	live_requests_total = 0
	replay_requests_total = 0
	cues_played_total = 0
	cues_coalesced_total = 0
	cues_dropped_total = 0
	bass_cues_dropped_total = 0
	voices_preempted_total = 0
	arbitration_batches_total = 0
	lane_overflow_total = 0
	cancellation_total = 0
	max_simultaneous_main_voices = 0
	max_simultaneous_bass_voices = 0
	max_simultaneous_voices = 0
	max_simultaneous_requests = 0
	motif_followup_beats_played_total = 0
	motif_followup_beats_dropped_total = 0
	request_counts_by_kind.clear()
	played_counts_by_kind.clear()
	coalesced_counts_by_kind.clear()
	dropped_counts_by_kind.clear()
	current_sequence_request_counts_by_kind.clear()
	current_sequence_played_counts_by_kind.clear()
	current_sequence_coalesced_counts_by_kind.clear()
	current_sequence_dropped_counts_by_kind.clear()
	session_peak_global_excitement = 0.0
	last_sequence_snapshot.clear()
	last_cue_snapshot.clear()
	last_cancel_reason = ""
	last_self_test_result.clear()


func run_arbitration_stress_self_test() -> Dictionary:
	last_self_test_result = run_pure_arbitration_stress_self_test()
	return last_self_test_result.duplicate(true)


func get_lane_snapshot(ball_id: int) -> Dictionary:
	if not logical_lanes.has(ball_id):
		return {}
	return (logical_lanes[ball_id] as Dictionary).duplicate(true)


func get_state_snapshot() -> Dictionary:
	return {
		"schema_version": 1,
		"enabled": enabled,
		"audio_enabled": audio_enabled,
		"mode": current_mode,
		"shot_id": current_shot_id,
		"attempt_id": current_attempt_id,
		"logical_lane_count": logical_lanes.size(),
		"logical_lane_cap": MAX_LOGICAL_LANES,
		"logical_lanes": logical_lanes.duplicate(true),
		"global_excitement": global_excitement,
		"global_excitement_normalized": _get_excitement_normalized(global_excitement),
		"peak_global_excitement": peak_global_excitement,
		"session_peak_global_excitement": session_peak_global_excitement,
		"pending_requests": pending_requests.size(),
		"scheduled_requests": scheduled_requests.size(),
		"main_voice_count": MAIN_VOICE_COUNT,
		"bass_voice_count": BASS_VOICE_COUNT,
		"active_main_voices": _get_active_main_voice_count(),
		"active_bass_voices": _get_active_bass_voice_count(),
		"arbitration_window_msec": float(ARBITRATION_WINDOW_USEC) / 1000.0,
		"requests_total": requests_total,
		"live_requests_total": live_requests_total,
		"replay_requests_total": replay_requests_total,
		"cues_played_total": cues_played_total,
		"cues_coalesced_total": cues_coalesced_total,
		"cues_dropped_total": cues_dropped_total,
		"bass_cues_dropped_total": bass_cues_dropped_total,
		"voices_preempted_total": voices_preempted_total,
		"arbitration_batches_total": arbitration_batches_total,
		"lane_overflow_total": lane_overflow_total,
		"cancellation_total": cancellation_total,
		"max_simultaneous_main_voices": max_simultaneous_main_voices,
		"max_simultaneous_bass_voices": max_simultaneous_bass_voices,
		"max_simultaneous_voices": max_simultaneous_voices,
		"max_simultaneous_requests": max_simultaneous_requests,
		"motif_followup_beats_played_total": motif_followup_beats_played_total,
		"motif_followup_beats_dropped_total": motif_followup_beats_dropped_total,
		"request_counts_by_kind": request_counts_by_kind.duplicate(true),
		"played_counts_by_kind": played_counts_by_kind.duplicate(true),
		"coalesced_counts_by_kind": coalesced_counts_by_kind.duplicate(true),
		"dropped_counts_by_kind": dropped_counts_by_kind.duplicate(true),
		"current_sequence_requests": current_sequence_requests,
		"current_sequence_played": current_sequence_played,
		"current_sequence_coalesced": current_sequence_coalesced,
		"current_sequence_dropped": current_sequence_dropped,
		"current_sequence_peak_excitement": current_sequence_peak_excitement,
		"current_sequence_request_counts_by_kind": current_sequence_request_counts_by_kind.duplicate(true),
		"current_sequence_played_counts_by_kind": current_sequence_played_counts_by_kind.duplicate(true),
		"current_sequence_coalesced_counts_by_kind": current_sequence_coalesced_counts_by_kind.duplicate(true),
		"current_sequence_dropped_counts_by_kind": current_sequence_dropped_counts_by_kind.duplicate(true),
		"last_cue": last_cue_snapshot.duplicate(true),
		"last_sequence": last_sequence_snapshot.duplicate(true),
		"last_cancel_reason": last_cancel_reason,
		"audio_effects_available": audio_effects_available,
		"main_bus": MAIN_BUS_NAME,
		"bass_bus": BASS_BUS_NAME,
		"last_self_test": last_self_test_result.duplicate(true),
	}


func _begin_sequence(
	mode: String,
	shot_id: int,
	attempt_id: int,
	lane_sources: Array,
	initial_excitement: float
) -> void:
	if (
		current_mode != MODE_IDLE
		or not pending_requests.is_empty()
		or not scheduled_requests.is_empty()
		or _has_playing_voice()
	):
		_cancel_internal("sequence_replaced", false)
	_ensure_audio_ready()
	current_mode = mode
	current_shot_id = shot_id
	current_attempt_id = attempt_id
	logical_lanes.clear()
	pending_requests.clear()
	scheduled_requests.clear()
	global_excitement = clampf(initial_excitement, 0.0, MAX_GLOBAL_EXCITEMENT)
	peak_global_excitement = global_excitement
	current_sequence_requests = 0
	current_sequence_played = 0
	current_sequence_coalesced = 0
	current_sequence_dropped = 0
	current_sequence_peak_excitement = global_excitement
	current_sequence_request_counts_by_kind.clear()
	current_sequence_played_counts_by_kind.clear()
	current_sequence_coalesced_counts_by_kind.clear()
	current_sequence_dropped_counts_by_kind.clear()
	for lane_value: Variant in lane_sources:
		if not lane_value is Dictionary:
			continue
		var lane_source: Dictionary = lane_value
		var ball_id: int = int(lane_source.get("ball_id", -1))
		var planned_tier: int = int(lane_source.get(
			"planned_final_tier",
			lane_source.get("bank_tier", lane_source.get("tier_count", 0))
		))
		register_lane(ball_id, planned_tier)
	state_changed.emit(get_state_snapshot())


func _request_cue(
	source_mode: String,
	ball_id: int,
	cue_kind_value: String,
	world_position: Vector2,
	metadata: Dictionary
) -> bool:
	var cue_kind: String = _normalize_cue_kind(cue_kind_value, metadata)
	requests_total += 1
	current_sequence_requests += 1
	_increment_kind_count(request_counts_by_kind, cue_kind)
	_increment_kind_count(current_sequence_request_counts_by_kind, cue_kind)
	if source_mode == MODE_LIVE:
		live_requests_total += 1
	else:
		replay_requests_total += 1
	if not enabled or not audio_enabled or current_mode != source_mode:
		_drop_request(_make_rejected_request(source_mode, ball_id, cue_kind), "inactive_mode")
		return false
	if cancel_on_tree_pause and get_tree() != null and get_tree().paused:
		_drop_request(_make_rejected_request(source_mode, ball_id, cue_kind), "tree_paused")
		return false
	if pending_requests.size() + scheduled_requests.size() >= MAX_PENDING_REQUESTS:
		_drop_request(_make_rejected_request(source_mode, ball_id, cue_kind), "pending_cap")
		return false
	if ball_id >= 0 and not logical_lanes.has(ball_id):
		var planned_tier: int = int(metadata.get("planned_final_tier", 0))
		if not register_lane(ball_id, planned_tier):
			_drop_request(_make_rejected_request(source_mode, ball_id, cue_kind), "lane_cap")
			return false
	if ball_id >= 0:
		var lane: Dictionary = logical_lanes[ball_id]
		if bool(lane.get("diverged", false)):
			_drop_request(_make_rejected_request(source_mode, ball_id, cue_kind), "lane_diverged")
			return false

	request_serial += 1
	var milestone: int = _get_cue_milestone(cue_kind, metadata)
	var cue_key: String = str(metadata.get(
		"cue_key",
		"%s:%d:%s:%d" % [source_mode, ball_id, cue_kind, milestone]
	))
	if ball_id >= 0:
		var lane: Dictionary = logical_lanes[ball_id]
		var seen_keys: Dictionary = lane.get("seen_cue_keys", {})
		if seen_keys.has(cue_key) and not bool(metadata.get("allow_repeat", false)):
			_drop_request(_make_rejected_request(source_mode, ball_id, cue_kind), "duplicate_lane_cue")
			return false
		seen_keys[cue_key] = true
		lane["seen_cue_keys"] = seen_keys
		lane["current_matched_milestone"] = maxi(
			int(lane.get("current_matched_milestone", 0)),
			milestone
		)
		lane["last_cue_usec"] = Time.get_ticks_usec()
		lane["last_cue_kind"] = cue_kind
		lane["request_count"] = int(lane.get("request_count", 0)) + 1
		logical_lanes[ball_id] = lane

	var excitement_weight: float = clampf(
		float(metadata.get("excitement_weight", _get_default_excitement_weight(cue_kind))),
		0.0,
		4.0
	)
	var excitement_at_request: float = _add_global_excitement(excitement_weight)
	var request: Dictionary = {
		"request_id": request_serial,
		"source_mode": source_mode,
		"shot_id": current_shot_id,
		"attempt_id": current_attempt_id,
		"ball_id": ball_id,
		"cue_kind": cue_kind,
		"cue_key": cue_key,
		"milestone": milestone,
		"priority": _get_cue_priority(cue_kind),
		"world_position": world_position if _is_finite_vector2(world_position) else Vector2.ZERO,
		"requested_usec": Time.get_ticks_usec(),
		"scheduled_usec": 0,
		"coalescible": _is_low_priority_coalescible(cue_kind, metadata),
		"coalesce_key": "%s:%s" % [source_mode, cue_kind],
		"force_distinct": bool(metadata.get("force_distinct", false)),
		"bass_enabled": bool(metadata.get("bass_enabled", true)),
		"excitement": excitement_at_request,
		"excitement_normalized": _get_excitement_normalized(excitement_at_request),
		"replay_progress": clampf(float(metadata.get("replay_progress", 0.0)), 0.0, 1.0),
		"metadata": metadata.duplicate(true),
	}
	request["pitch_scale"] = _calculate_main_pitch(request)
	request["volume_db"] = _calculate_main_volume_db(request)
	request["bass_pitch_scale"] = _calculate_bass_pitch(request)
	request["bass_volume_db"] = _calculate_bass_volume_db(request)
	pending_requests.append(request)
	max_simultaneous_requests = maxi(max_simultaneous_requests, pending_requests.size())
	set_process(true)
	return true


func _process_pending_requests(now_usec: int) -> void:
	while not pending_requests.is_empty():
		var oldest: Dictionary = pending_requests[0]
		var oldest_usec: int = int(oldest.get("requested_usec", now_usec))
		if now_usec - oldest_usec < ARBITRATION_WINDOW_USEC:
			return
		var cutoff_usec: int = oldest_usec + ARBITRATION_WINDOW_USEC
		var batch: Array[Dictionary] = []
		while not pending_requests.is_empty():
			var candidate: Dictionary = pending_requests[0]
			if int(candidate.get("requested_usec", now_usec)) > cutoff_usec:
				break
			batch.append(pending_requests.pop_front())
		_arbitrate_batch(batch, now_usec)


func _arbitrate_batch(batch: Array[Dictionary], now_usec: int) -> void:
	if batch.is_empty():
		return
	arbitration_batches_total += 1
	max_simultaneous_requests = maxi(max_simultaneous_requests, batch.size())
	var arbitration: Dictionary = arbitrate_request_batch(batch, MAIN_VOICE_COUNT)
	var coalesced: Array = arbitration.get("coalesced", [])
	var dropped: Array = arbitration.get("dropped", [])
	for coalesced_value: Variant in coalesced:
		if coalesced_value is Dictionary:
			_record_coalesced_request(coalesced_value)
	for dropped_value: Variant in dropped:
		if dropped_value is Dictionary:
			_drop_request(dropped_value, "arbitration_capacity")

	var accepted: Array = arbitration.get("accepted", [])
	var accepted_index := 0
	for accepted_value: Variant in accepted:
		if not accepted_value is Dictionary:
			continue
		var request: Dictionary = accepted_value
		var priority: int = int(request.get("priority", 0))
		var stagger_usec := 0
		if accepted_index > 0 and priority < PRIORITY_SCORING_POCKET:
			stagger_usec = mini(accepted_index * LOWER_PRIORITY_STAGGER_USEC, MAX_STAGGER_USEC)
		request["scheduled_usec"] = now_usec + stagger_usec
		scheduled_requests.append(request)
		accepted_index += 1


func _process_scheduled_requests(now_usec: int) -> void:
	var request_index := 0
	while request_index < scheduled_requests.size():
		var request: Dictionary = scheduled_requests[request_index]
		if int(request.get("scheduled_usec", now_usec)) > now_usec:
			request_index += 1
			continue
		scheduled_requests.remove_at(request_index)
		_play_request(request)


func _play_request(request: Dictionary) -> void:
	if current_mode == MODE_IDLE:
		_drop_request(request, "sequence_ended_before_playback")
		return
	var priority: int = int(request.get("priority", 0))
	var main_index: int = _claim_main_voice(priority)
	if main_index < 0:
		_drop_request(request, "main_voice_cap")
		return
	var main_player: AudioStreamPlayer2D = main_players[main_index]
	main_player.stream = _get_main_stream(request)
	main_player.global_position = request.get("world_position", Vector2.ZERO)
	main_player.pitch_scale = float(request.get("pitch_scale", 1.0))
	main_player.volume_db = float(request.get("volume_db", -20.0))
	main_player.play()
	main_voice_states[main_index] = {
		"request_id": int(request.get("request_id", -1)),
		"priority": priority,
		"started_usec": Time.get_ticks_usec(),
		"cue_kind": str(request.get("cue_kind", "")),
	}
	if bool(request.get("bass_enabled", true)):
		_play_bass_layer(request)
	_apply_reverb_for_request(request)

	cues_played_total += 1
	current_sequence_played += 1
	var cue_kind: String = str(request.get("cue_kind", ""))
	_increment_kind_count(played_counts_by_kind, cue_kind)
	_increment_kind_count(current_sequence_played_counts_by_kind, cue_kind)
	var motif_followup: bool = bool(request.get("motif_followup", false))
	if motif_followup:
		motif_followup_beats_played_total += 1
	var ball_id: int = int(request.get("ball_id", -1))
	if not motif_followup and ball_id >= 0 and logical_lanes.has(ball_id):
		var lane: Dictionary = logical_lanes[ball_id]
		lane["played_count"] = int(lane.get("played_count", 0)) + 1
		lane["last_pitch"] = float(request.get("pitch_scale", 1.0))
		logical_lanes[ball_id] = lane
	last_cue_snapshot = request.duplicate(true)
	last_cue_snapshot["main_voice_index"] = main_index
	_update_simultaneous_voice_diagnostics()
	last_cue_snapshot["active_main_voices"] = _get_active_main_voice_count()
	last_cue_snapshot["active_bass_voices"] = _get_active_bass_voice_count()
	cue_started.emit(last_cue_snapshot.duplicate(true))
	if not motif_followup:
		_schedule_motif_followups(request)


func _play_bass_layer(request: Dictionary) -> void:
	var priority: int = int(request.get("priority", 0))
	var bass_index: int = _claim_bass_voice(priority)
	if bass_index < 0:
		bass_cues_dropped_total += 1
		return
	var bass_player: AudioStreamPlayer2D = bass_players[bass_index]
	bass_player.stream = MAIN_CUE_STREAM_A
	bass_player.global_position = request.get("world_position", Vector2.ZERO)
	bass_player.pitch_scale = float(request.get("bass_pitch_scale", 0.62))
	bass_player.volume_db = float(request.get("bass_volume_db", -25.0))
	bass_player.play()
	bass_voice_states[bass_index] = {
		"request_id": int(request.get("request_id", -1)),
		"priority": priority,
		"started_usec": Time.get_ticks_usec(),
		"cue_kind": str(request.get("cue_kind", "")),
	}


func _claim_main_voice(priority: int) -> int:
	var voice_count: int = main_players.size()
	if voice_count <= 0:
		return -1
	for offset in range(voice_count):
		var candidate_index: int = (next_main_voice_index + offset) % voice_count
		if not main_players[candidate_index].playing:
			next_main_voice_index = (candidate_index + 1) % voice_count
			return candidate_index
	var weakest_index: int = _find_weakest_voice_index(main_voice_states)
	if weakest_index < 0 or priority <= int(main_voice_states[weakest_index].get("priority", 0)):
		return -1
	main_players[weakest_index].stop()
	voices_preempted_total += 1
	next_main_voice_index = (weakest_index + 1) % voice_count
	return weakest_index


func _claim_bass_voice(priority: int) -> int:
	var voice_count: int = bass_players.size()
	if voice_count <= 0:
		return -1
	for offset in range(voice_count):
		var candidate_index: int = (next_bass_voice_index + offset) % voice_count
		if not bass_players[candidate_index].playing:
			next_bass_voice_index = (candidate_index + 1) % voice_count
			return candidate_index
	var weakest_index: int = _find_weakest_voice_index(bass_voice_states)
	if weakest_index < 0 or priority <= int(bass_voice_states[weakest_index].get("priority", 0)):
		return -1
	bass_players[weakest_index].stop()
	voices_preempted_total += 1
	next_bass_voice_index = (weakest_index + 1) % voice_count
	return weakest_index


func _find_weakest_voice_index(voice_states: Array[Dictionary]) -> int:
	var weakest_index := -1
	var weakest_priority := 2147483647
	var oldest_started_usec := 2147483647
	for voice_index in range(voice_states.size()):
		var state: Dictionary = voice_states[voice_index]
		var priority: int = int(state.get("priority", -1))
		var started_usec: int = int(state.get("started_usec", 0))
		if priority < weakest_priority or (
			priority == weakest_priority and started_usec < oldest_started_usec
		):
			weakest_index = voice_index
			weakest_priority = priority
			oldest_started_usec = started_usec
	return weakest_index


func _record_coalesced_request(request: Dictionary) -> void:
	cues_coalesced_total += 1
	current_sequence_coalesced += 1
	var cue_kind: String = str(request.get("cue_kind", ""))
	_increment_kind_count(coalesced_counts_by_kind, cue_kind)
	_increment_kind_count(current_sequence_coalesced_counts_by_kind, cue_kind)
	var snapshot: Dictionary = request.duplicate(true)
	snapshot["reason"] = "simultaneous_low_priority"
	cue_coalesced.emit(snapshot)


func _drop_request(request: Dictionary, reason: String) -> void:
	cues_dropped_total += 1
	current_sequence_dropped += 1
	var cue_kind: String = str(request.get("cue_kind", ""))
	_increment_kind_count(dropped_counts_by_kind, cue_kind)
	_increment_kind_count(current_sequence_dropped_counts_by_kind, cue_kind)
	if bool(request.get("motif_followup", false)):
		motif_followup_beats_dropped_total += 1
	var snapshot: Dictionary = request.duplicate(true)
	snapshot["reason"] = reason
	cue_dropped.emit(snapshot)


func _add_global_excitement(weight: float) -> float:
	if not global_excitement_enabled:
		return global_excitement
	global_excitement = clampf(
		global_excitement + weight * clampf(global_excitement_strength, 0.0, 2.0),
		0.0,
		MAX_GLOBAL_EXCITEMENT
	)
	peak_global_excitement = maxf(peak_global_excitement, global_excitement)
	session_peak_global_excitement = maxf(
		session_peak_global_excitement,
		global_excitement
	)
	current_sequence_peak_excitement = maxf(
		current_sequence_peak_excitement,
		global_excitement
	)
	return global_excitement


func _archive_current_sequence(reason: String) -> void:
	last_sequence_snapshot = {
		"reason": reason,
		"mode": current_mode,
		"shot_id": current_shot_id,
		"attempt_id": current_attempt_id,
		"requests": current_sequence_requests,
		"played": current_sequence_played,
		"coalesced": current_sequence_coalesced,
		"dropped": current_sequence_dropped,
		"peak_global_excitement": current_sequence_peak_excitement,
		"lane_count": logical_lanes.size(),
		"lanes": logical_lanes.duplicate(true),
		"request_counts_by_kind": current_sequence_request_counts_by_kind.duplicate(true),
		"played_counts_by_kind": current_sequence_played_counts_by_kind.duplicate(true),
		"coalesced_counts_by_kind": current_sequence_coalesced_counts_by_kind.duplicate(true),
		"dropped_counts_by_kind": current_sequence_dropped_counts_by_kind.duplicate(true),
	}


func _schedule_motif_followups(request: Dictionary) -> void:
	var beat_count: int = _get_motif_beat_count(
		str(request.get("cue_kind", "")),
		int(request.get("milestone", 0))
	)
	if beat_count <= 1:
		return
	var now_usec: int = Time.get_ticks_usec()
	for beat_index in range(1, beat_count):
		var followup: Dictionary = request.duplicate(true)
		followup["request_id"] = -(
			int(request.get("request_id", 0)) * 10 + beat_index
		)
		followup["cue_key"] = "%s:beat%d" % [
			str(request.get("cue_key", "tap_motif")),
			beat_index + 1,
		]
		followup["motif_followup"] = true
		followup["motif_beat_index"] = beat_index + 1
		followup["motif_beat_count"] = beat_count
		followup["requested_usec"] = now_usec
		followup["scheduled_usec"] = (
			now_usec + beat_index * TAP_MOTIF_BEAT_INTERVAL_USEC
		)
		followup["bass_enabled"] = false
		followup["pitch_scale"] = clampf(
			float(request.get("pitch_scale", 1.0)) + float(beat_index) * 0.075,
			MAIN_MIN_PITCH,
			MAIN_MAX_PITCH
		)
		followup["volume_db"] = clampf(
			float(request.get("volume_db", -20.0)) - 1.0 + float(beat_index) * 0.35,
			MAIN_MIN_VOLUME_DB,
			MAIN_MAX_VOLUME_DB
		)
		if pending_requests.size() + scheduled_requests.size() >= MAX_PENDING_REQUESTS:
			_drop_request(followup, "motif_pending_cap")
			continue
		scheduled_requests.append(followup)
	set_process(true)


func _cancel_internal(reason: String, emit_events: bool) -> void:
	var had_activity: bool = (
		current_mode != MODE_IDLE
		or not pending_requests.is_empty()
		or not scheduled_requests.is_empty()
		or _has_playing_voice()
	)
	if had_activity:
		_archive_current_sequence(reason)
		cancellation_total += 1
	last_cancel_reason = reason
	pending_requests.clear()
	scheduled_requests.clear()
	logical_lanes.clear()
	current_mode = MODE_IDLE
	current_shot_id = -1
	current_attempt_id = -1
	global_excitement = 0.0
	peak_global_excitement = 0.0
	_stop_all_voices()
	set_process(false)
	if emit_events:
		var snapshot: Dictionary = get_state_snapshot()
		conductor_canceled.emit(reason, snapshot)
		state_changed.emit(snapshot)


func _take_all_pending_requests() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for request: Dictionary in pending_requests:
		result.append(request)
	pending_requests.clear()
	return result


func _make_rejected_request(source_mode: String, ball_id: int, cue_kind: String) -> Dictionary:
	return {
		"request_id": -1,
		"source_mode": source_mode,
		"ball_id": ball_id,
		"cue_kind": cue_kind,
		"shot_id": current_shot_id,
		"attempt_id": current_attempt_id,
	}


func _normalize_cue_kind(cue_kind: String, metadata: Dictionary) -> String:
	var normalized: String = cue_kind.strip_edges().to_lower()
	if normalized in ["bank", "bank_milestone", "rail"]:
		var milestone: int = clampi(int(metadata.get("milestone", 1)), 1, 3)
		if milestone == 2:
			return CUE_BANK_2
		if milestone == 3:
			return CUE_BANK_3
		return CUE_BANK_1
	match normalized:
		"single_bank", "first_bank":
			return CUE_BANK_1
		"double_bank", "second_bank":
			return CUE_BANK_2
		"triple_bank", "third_bank", "final_bank":
			return CUE_BANK_3
		"combo", "combination_activation":
			return CUE_COMBINATION
		"cue_recontact", "cue_recontact_milestone", "double-tap":
			return (
				CUE_TRIPLE_TAP
				if int(metadata.get("milestone", metadata.get("tap_ordinal", 2))) >= 3
				else CUE_DOUBLE_TAP
			)
		"triple-tap", "tap":
			return CUE_TRIPLE_TAP
		"object_ball_tap", "object_ball_tap_milestone", "ball-tap":
			return (
				CUE_BALL_TAP_CHAIN
				if int(metadata.get("milestone", metadata.get("tap_ordinal", 1))) >= 2
				else CUE_BALL_TAP
			)
		"sink", "sunk", "scoring_pocket":
			return CUE_POCKET
		"multipot", "multi-pot":
			return CUE_MULTI_POT
		"final", "completion":
			return CUE_MAJOR_COMPLETION
	return normalized


func _get_cue_milestone(cue_kind: String, metadata: Dictionary) -> int:
	match cue_kind:
		CUE_BANK_1:
			return 1
		CUE_BANK_2:
			return 2
		CUE_BANK_3:
			return 3
		CUE_DOUBLE_TAP:
			return maxi(int(metadata.get("milestone", 2)), 2)
		CUE_TRIPLE_TAP:
			return maxi(int(metadata.get("milestone", 3)), 3)
		CUE_BALL_TAP:
			return maxi(int(metadata.get("milestone", 1)), 1)
		CUE_BALL_TAP_CHAIN:
			return maxi(int(metadata.get("milestone", 2)), 2)
	return maxi(int(metadata.get("milestone", 0)), 0)


func _is_low_priority_coalescible(cue_kind: String, metadata: Dictionary) -> bool:
	if bool(metadata.get("force_distinct", false)):
		return false
	return cue_kind in [CUE_BANK_1, CUE_BALL_TAP, CUE_REPLAY_TICK]


static func _get_default_excitement_weight(cue_kind: String) -> float:
	match cue_kind:
		CUE_BANK_1, CUE_COMBINATION:
			return 1.0
		CUE_BALL_TAP:
			return 1.0
		CUE_BANK_2, CUE_POCKET, CUE_MULTI_POT, CUE_DOUBLE_TAP, CUE_BALL_TAP_CHAIN:
			return 2.0
		CUE_BANK_3, CUE_MAJOR_COMPLETION, CUE_TRIPLE_TAP:
			return 3.0
	return 0.5


static func _get_motif_beat_count(cue_kind: String, milestone: int) -> int:
	match cue_kind:
		CUE_DOUBLE_TAP:
			return 2
		CUE_TRIPLE_TAP:
			return 3 if milestone >= 3 else 2
	return 1


func _increment_kind_count(counts: Dictionary, cue_kind: String) -> void:
	var key: String = cue_kind if not cue_kind.is_empty() else "unknown"
	counts[key] = int(counts.get(key, 0)) + 1


func _get_main_stream(request: Dictionary) -> AudioStream:
	var cue_kind: String = str(request.get("cue_kind", ""))
	if cue_kind in [CUE_POCKET, CUE_MULTI_POT, CUE_MAJOR_COMPLETION]:
		return POCKET_CUE_STREAM
	var request_id: int = int(request.get("request_id", 0))
	return MAIN_CUE_STREAM_A if request_id % 2 == 0 else MAIN_CUE_STREAM_B


func _apply_reverb_for_request(request: Dictionary) -> void:
	if reverb_effect == null:
		return
	var excitement_normalized: float = float(request.get("excitement_normalized", 0.0))
	_set_audio_effect_property_if_present(
		reverb_effect,
		"wet",
		BASE_REVERB_WET + excitement_normalized * MAX_EXCITEMENT_REVERB_WET_BONUS
	)


func _build_audio_pools() -> void:
	if not main_players.is_empty():
		return
	_ensure_audio_buses()
	for voice_index in range(MAIN_VOICE_COUNT):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "ScoringCueMain%02d" % (voice_index + 1)
		player.bus = MAIN_BUS_NAME
		player.panning_strength = MAIN_PANNING_STRENGTH
		player.max_distance = AUDIO_MAX_DISTANCE
		player.attenuation = AUDIO_ATTENUATION
		add_child(player)
		main_players.append(player)
		main_voice_states.append(_empty_voice_state())
	for voice_index in range(BASS_VOICE_COUNT):
		var player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		player.name = "ScoringCueBass%02d" % (voice_index + 1)
		player.bus = BASS_BUS_NAME
		player.panning_strength = BASS_PANNING_STRENGTH
		player.max_distance = AUDIO_MAX_DISTANCE
		player.attenuation = AUDIO_ATTENUATION
		add_child(player)
		bass_players.append(player)
		bass_voice_states.append(_empty_voice_state())


func _ensure_audio_ready() -> void:
	if main_players.is_empty() and is_inside_tree():
		_build_audio_pools()


func _ensure_audio_buses() -> void:
	AudioSettings.ensure_audio_buses()
	var parent_bus: String = (
		AudioSettings.SFX_BUS_NAME
		if AudioServer.get_bus_index(AudioSettings.SFX_BUS_NAME) >= 0
		else AudioSettings.MASTER_BUS_NAME
	)
	main_bus_index = _ensure_runtime_audio_bus(MAIN_BUS_NAME, parent_bus)
	bass_bus_index = _ensure_runtime_audio_bus(BASS_BUS_NAME, parent_bus)
	audio_effects_available = not AudioSettings.is_web_build()
	if not audio_effects_available:
		return
	_configure_main_bus_effects()
	_configure_bass_bus_effects()


func _ensure_runtime_audio_bus(bus_name: String, send_bus_name: String) -> int:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		bus_index = AudioServer.get_bus_count()
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, send_bus_name)
	return bus_index


func _configure_main_bus_effects() -> void:
	if main_bus_index < 0:
		return
	reverb_effect_index = _find_bus_effect_index(main_bus_index, "AudioEffectReverb")
	if reverb_effect_index < 0:
		reverb_effect = AudioEffectReverb.new()
		AudioServer.add_bus_effect(main_bus_index, reverb_effect)
		reverb_effect_index = AudioServer.get_bus_effect_count(main_bus_index) - 1
	else:
		reverb_effect = AudioServer.get_bus_effect(
			main_bus_index,
			reverb_effect_index
		) as AudioEffectReverb
	if reverb_effect != null:
		_set_audio_effect_property_if_present(reverb_effect, "room_size", REVERB_ROOM_SIZE)
		_set_audio_effect_property_if_present(reverb_effect, "damping", REVERB_DAMPING)
		_set_audio_effect_property_if_present(reverb_effect, "spread", REVERB_SPREAD)
		_set_audio_effect_property_if_present(reverb_effect, "hipass", REVERB_HIPASS)
		_set_audio_effect_property_if_present(reverb_effect, "predelay_msec", REVERB_PREDELAY_MSEC)
		_set_audio_effect_property_if_present(reverb_effect, "predelay_feedback", 0.0)
		_set_audio_effect_property_if_present(reverb_effect, "dry", 1.0)
		_set_audio_effect_property_if_present(reverb_effect, "wet", BASE_REVERB_WET)
	_ensure_limiter_effect(main_bus_index, -1.0, -4.0)


func _configure_bass_bus_effects() -> void:
	if bass_bus_index < 0:
		return
	var lowpass_index: int = _find_bus_effect_index(
		bass_bus_index,
		"AudioEffectLowPassFilter"
	)
	var lowpass: AudioEffectLowPassFilter
	if lowpass_index < 0:
		lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(bass_bus_index, lowpass)
		lowpass_index = AudioServer.get_bus_effect_count(bass_bus_index) - 1
	else:
		lowpass = AudioServer.get_bus_effect(
			bass_bus_index,
			lowpass_index
		) as AudioEffectLowPassFilter
	if lowpass != null:
		_set_audio_effect_property_if_present(lowpass, "cutoff_hz", BASS_LOWPASS_HZ)
		_set_audio_effect_property_if_present(lowpass, "resonance", 0.16)
		_set_audio_effect_property_if_present(lowpass, "db", 1)
		AudioServer.set_bus_effect_enabled(bass_bus_index, lowpass_index, true)
	_ensure_limiter_effect(bass_bus_index, -2.0, -5.0)


func _ensure_limiter_effect(bus_index: int, ceiling_db: float, threshold_db: float) -> void:
	var effect_index: int = _find_bus_effect_index(bus_index, "AudioEffectLimiter")
	var limiter: AudioEffectLimiter
	if effect_index < 0:
		limiter = AudioEffectLimiter.new()
		AudioServer.add_bus_effect(bus_index, limiter)
		effect_index = AudioServer.get_bus_effect_count(bus_index) - 1
	else:
		limiter = AudioServer.get_bus_effect(bus_index, effect_index) as AudioEffectLimiter
	if limiter == null:
		return
	_set_audio_effect_property_if_present(limiter, "ceiling_db", ceiling_db)
	_set_audio_effect_property_if_present(limiter, "threshold_db", threshold_db)
	_set_audio_effect_property_if_present(limiter, "soft_clip_db", 2.0)
	_set_audio_effect_property_if_present(limiter, "soft_clip_ratio", 8.0)
	AudioServer.set_bus_effect_enabled(bus_index, effect_index, true)


func _find_bus_effect_index(bus_index: int, effect_class_name: String) -> int:
	if bus_index < 0:
		return -1
	for effect_index in range(AudioServer.get_bus_effect_count(bus_index)):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
		if effect != null and effect.is_class(effect_class_name):
			return effect_index
	return -1


func _set_audio_effect_property_if_present(
	effect: AudioEffect,
	property_name: String,
	value: Variant
) -> void:
	for property_data: Dictionary in effect.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			effect.set(property_name, value)
			return


func _refresh_voice_states() -> void:
	for voice_index in range(main_players.size()):
		if not main_players[voice_index].playing:
			main_voice_states[voice_index] = _empty_voice_state()
	for voice_index in range(bass_players.size()):
		if not bass_players[voice_index].playing:
			bass_voice_states[voice_index] = _empty_voice_state()


func _stop_all_voices() -> void:
	for voice_index in range(main_players.size()):
		main_players[voice_index].stop()
		main_voice_states[voice_index] = _empty_voice_state()
	for voice_index in range(bass_players.size()):
		bass_players[voice_index].stop()
		bass_voice_states[voice_index] = _empty_voice_state()


func _has_playing_voice() -> bool:
	return _get_active_main_voice_count() > 0 or _get_active_bass_voice_count() > 0


func _get_active_main_voice_count() -> int:
	var active_count := 0
	for player: AudioStreamPlayer2D in main_players:
		if player.playing:
			active_count += 1
	return active_count


func _get_active_bass_voice_count() -> int:
	var active_count := 0
	for player: AudioStreamPlayer2D in bass_players:
		if player.playing:
			active_count += 1
	return active_count


func _update_simultaneous_voice_diagnostics() -> void:
	var main_count: int = _get_active_main_voice_count()
	var bass_count: int = _get_active_bass_voice_count()
	max_simultaneous_main_voices = maxi(max_simultaneous_main_voices, main_count)
	max_simultaneous_bass_voices = maxi(max_simultaneous_bass_voices, bass_count)
	max_simultaneous_voices = maxi(max_simultaneous_voices, main_count + bass_count)


static func arbitrate_request_batch(requests: Array, capacity: int = MAIN_VOICE_COUNT) -> Dictionary:
	var ordered: Array[Dictionary] = []
	for request_value: Variant in requests:
		if request_value is Dictionary:
			ordered.append((request_value as Dictionary).duplicate(true))
	_sort_requests_by_priority(ordered)
	var accepted: Array[Dictionary] = []
	var coalesced: Array[Dictionary] = []
	var dropped: Array[Dictionary] = []
	var coalesced_keys: Dictionary = {}
	var safe_capacity: int = maxi(capacity, 0)
	for request: Dictionary in ordered:
		var can_coalesce: bool = (
			bool(request.get("coalescible", false))
			and not bool(request.get("force_distinct", false))
		)
		var coalesce_key: String = str(request.get("coalesce_key", ""))
		if can_coalesce and coalesce_key != "" and coalesced_keys.has(coalesce_key):
			coalesced.append(request)
			continue
		if accepted.size() >= safe_capacity:
			dropped.append(request)
			continue
		accepted.append(request)
		if can_coalesce and coalesce_key != "":
			coalesced_keys[coalesce_key] = true
	return {
		"accepted": accepted,
		"coalesced": coalesced,
		"dropped": dropped,
		"input_count": ordered.size(),
		"capacity": safe_capacity,
	}


static func run_pure_arbitration_stress_self_test() -> Dictionary:
	var failures: Array[String] = []
	var total_tests := 0
	var passed_tests := 0

	total_tests += 1
	var priority_batch: Array[Dictionary] = [
		_test_request(1, CUE_BANK_1, PRIORITY_FIRST_TIER, false),
		_test_request(2, CUE_POCKET, PRIORITY_SCORING_POCKET, false),
		_test_request(3, CUE_BANK_3, PRIORITY_MAJOR_COMPLETION, false),
		_test_request(4, CUE_COMBINATION, PRIORITY_COMBINATION, false),
	]
	var priority_result: Dictionary = arbitrate_request_batch(priority_batch, 4)
	var priority_accepted: Array = priority_result.get("accepted", [])
	if (
		priority_accepted.size() == 4
		and str((priority_accepted[0] as Dictionary).get("cue_kind", "")) == CUE_BANK_3
		and str((priority_accepted[1] as Dictionary).get("cue_kind", "")) == CUE_POCKET
	):
		passed_tests += 1
	else:
		failures.append("Priority ordering did not preserve completion before pocket and weaker cues.")

	total_tests += 1
	var coalesce_batch: Array[Dictionary] = [
		_test_request(1, CUE_BANK_1, PRIORITY_FIRST_TIER, true),
		_test_request(2, CUE_BANK_1, PRIORITY_FIRST_TIER, true),
		_test_request(3, CUE_BANK_1, PRIORITY_FIRST_TIER, true),
	]
	var coalesce_result: Dictionary = arbitrate_request_batch(coalesce_batch, MAIN_VOICE_COUNT)
	if (
		(coalesce_result.get("accepted", []) as Array).size() == 1
		and (coalesce_result.get("coalesced", []) as Array).size() == 2
	):
		passed_tests += 1
	else:
		failures.append("Simultaneous low-priority cues were not coalesced to one voice.")

	total_tests += 1
	var tap_lane_batch: Array[Dictionary] = [
		_test_request(11, CUE_DOUBLE_TAP, PRIORITY_SECOND_TIER, false, true),
		_test_request(12, CUE_DOUBLE_TAP, PRIORITY_SECOND_TIER, false, true),
		_test_request(13, CUE_DOUBLE_TAP, PRIORITY_SECOND_TIER, false, true),
	]
	var tap_lane_result: Dictionary = arbitrate_request_batch(
		tap_lane_batch,
		MAIN_VOICE_COUNT
	)
	if (
		(tap_lane_result.get("accepted", []) as Array).size() == 3
		and (tap_lane_result.get("coalesced", []) as Array).is_empty()
		and (tap_lane_result.get("dropped", []) as Array).is_empty()
	):
		passed_tests += 1
	else:
		failures.append("Three independent Double Tap lanes did not retain their cues.")

	total_tests += 1
	var light_tap_batch: Array[Dictionary] = [
		_test_request(21, CUE_BALL_TAP, PRIORITY_FIRST_TIER, true),
		_test_request(22, CUE_BALL_TAP, PRIORITY_FIRST_TIER, true),
		_test_request(23, CUE_BALL_TAP, PRIORITY_FIRST_TIER, true),
	]
	var light_tap_result: Dictionary = arbitrate_request_batch(
		light_tap_batch,
		MAIN_VOICE_COUNT
	)
	if (
		(light_tap_result.get("accepted", []) as Array).size() == 1
		and (light_tap_result.get("coalesced", []) as Array).size() == 2
	):
		passed_tests += 1
	else:
		failures.append("Simultaneous first Ball Tap cues did not coalesce safely.")

	total_tests += 1
	if (
		_get_motif_beat_count(CUE_DOUBLE_TAP, 2) == 2
		and _get_motif_beat_count(CUE_TRIPLE_TAP, 3) == 3
		and _get_motif_beat_count(CUE_TRIPLE_TAP, 8) == 3
		and _get_motif_beat_count(CUE_BALL_TAP, 1) == 1
	):
		passed_tests += 1
	else:
		failures.append("Tap motif beat counts were not bounded to the authored identities.")

	total_tests += 1
	if (
		is_equal_approx(_get_default_excitement_weight(CUE_DOUBLE_TAP), 2.0)
		and is_equal_approx(_get_default_excitement_weight(CUE_TRIPLE_TAP), 3.0)
		and is_equal_approx(_get_default_excitement_weight(CUE_BALL_TAP), 1.0)
		and is_equal_approx(_get_default_excitement_weight(CUE_BALL_TAP_CHAIN), 2.0)
	):
		passed_tests += 1
	else:
		failures.append("Tap excitement weights drifted from the presentation contract.")

	total_tests += 1
	var distinct_batch: Array[Dictionary] = [
		_test_request(1, CUE_BANK_1, PRIORITY_FIRST_TIER, true, true),
		_test_request(2, CUE_BANK_1, PRIORITY_FIRST_TIER, true, true),
	]
	var distinct_result: Dictionary = arbitrate_request_batch(distinct_batch, MAIN_VOICE_COUNT)
	if (distinct_result.get("accepted", []) as Array).size() == 2:
		passed_tests += 1
	else:
		failures.append("force_distinct cues were incorrectly coalesced.")

	total_tests += 1
	var stress_batch: Array[Dictionary] = []
	for request_index in range(40):
		var cue_kind := CUE_BANK_1
		var priority := PRIORITY_FIRST_TIER
		if request_index % 9 == 0:
			cue_kind = CUE_BANK_3
			priority = PRIORITY_MAJOR_COMPLETION
		elif request_index % 5 == 0:
			cue_kind = CUE_POCKET
			priority = PRIORITY_SCORING_POCKET
		stress_batch.append(_test_request(request_index, cue_kind, priority, false))
	var stress_result: Dictionary = arbitrate_request_batch(stress_batch, MAIN_VOICE_COUNT)
	var stress_accepted: Array = stress_result.get("accepted", [])
	var important_retained := true
	for request_value: Variant in stress_accepted:
		if request_value is Dictionary and int((request_value as Dictionary).get("priority", 0)) < PRIORITY_SCORING_POCKET:
			important_retained = false
			break
	if stress_accepted.size() == MAIN_VOICE_COUNT and important_retained:
		passed_tests += 1
	else:
		failures.append("Forty-request stress batch exceeded capacity or displaced priority cues.")

	total_tests += 1
	var lane_one_request: Dictionary = {
		"cue_kind": CUE_BANK_3,
		"milestone": 3,
		"excitement_normalized": 0.0,
		"replay_progress": 0.0,
	}
	var lane_two_request: Dictionary = {
		"cue_kind": CUE_BANK_1,
		"milestone": 1,
		"excitement_normalized": 0.0,
		"replay_progress": 0.0,
	}
	if _calculate_main_pitch(lane_one_request) > _calculate_main_pitch(lane_two_request):
		passed_tests += 1
	else:
		failures.append("Lane-local third milestone did not remain above a separate lane's first milestone.")

	total_tests += 1
	var capped_excitement: float = clampf(100.0, 0.0, MAX_GLOBAL_EXCITEMENT)
	var excitement_pitch: float = _get_excitement_normalized(capped_excitement) * MAX_EXCITEMENT_PITCH_OFFSET
	if is_equal_approx(capped_excitement, MAX_GLOBAL_EXCITEMENT) and excitement_pitch <= 0.18001:
		passed_tests += 1
	else:
		failures.append("Global excitement exceeded its pitch or value cap.")

	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"total": total_tests,
		"passed": passed_tests,
		"failed": failures.size(),
		"failures": failures,
		"stress_request_count": 40,
		"main_voice_capacity": MAIN_VOICE_COUNT,
		"bass_voice_capacity": BASS_VOICE_COUNT,
	}


static func _sort_requests_by_priority(requests: Array[Dictionary]) -> void:
	for left_index in range(requests.size()):
		var best_index: int = left_index
		for candidate_index in range(left_index + 1, requests.size()):
			if _request_sorts_before(requests[candidate_index], requests[best_index]):
				best_index = candidate_index
		if best_index != left_index:
			var swap_value: Dictionary = requests[left_index]
			requests[left_index] = requests[best_index]
			requests[best_index] = swap_value


static func _request_sorts_before(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: int = int(left.get("priority", 0))
	var right_priority: int = int(right.get("priority", 0))
	if left_priority != right_priority:
		return left_priority > right_priority
	var left_usec: int = int(left.get("requested_usec", 0))
	var right_usec: int = int(right.get("requested_usec", 0))
	if left_usec != right_usec:
		return left_usec < right_usec
	return int(left.get("request_id", 0)) < int(right.get("request_id", 0))


static func _test_request(
	request_id: int,
	cue_kind: String,
	priority: int,
	coalescible: bool,
	force_distinct: bool = false
) -> Dictionary:
	return {
		"request_id": request_id,
		"requested_usec": request_id,
		"source_mode": MODE_LIVE,
		"cue_kind": cue_kind,
		"priority": priority,
		"coalescible": coalescible,
		"coalesce_key": "%s:%s" % [MODE_LIVE, cue_kind],
		"force_distinct": force_distinct,
	}


static func _get_cue_priority(cue_kind: String) -> int:
	match cue_kind:
		CUE_BANK_3, CUE_MAJOR_COMPLETION, CUE_TRIPLE_TAP:
			return PRIORITY_MAJOR_COMPLETION
		CUE_POCKET, CUE_MULTI_POT:
			return PRIORITY_SCORING_POCKET
		CUE_BANK_2, CUE_DOUBLE_TAP, CUE_BALL_TAP_CHAIN:
			return PRIORITY_SECOND_TIER
		CUE_COMBINATION:
			return PRIORITY_COMBINATION
		CUE_BANK_1, CUE_BALL_TAP:
			return PRIORITY_FIRST_TIER
	return PRIORITY_REPLAY_TICK


static func _calculate_main_pitch(request: Dictionary) -> float:
	var cue_kind: String = str(request.get("cue_kind", ""))
	var base_pitch := 0.92
	match cue_kind:
		CUE_BANK_1:
			base_pitch = 0.92
		CUE_BANK_2:
			base_pitch = 1.07
		CUE_BANK_3:
			base_pitch = 1.22
		CUE_COMBINATION:
			base_pitch = 0.98
		CUE_DOUBLE_TAP:
			base_pitch = 1.00 + float(maxi(int(request.get("milestone", 2)) - 2, 0)) * 0.025
		CUE_TRIPLE_TAP:
			base_pitch = 1.13 + float(mini(maxi(int(request.get("milestone", 3)) - 3, 0), 4)) * 0.035
		CUE_BALL_TAP:
			base_pitch = 0.96
		CUE_BALL_TAP_CHAIN:
			base_pitch = 1.04 + float(mini(maxi(int(request.get("milestone", 2)) - 2, 0), 5)) * 0.025
		CUE_POCKET:
			base_pitch = 0.90
		CUE_MULTI_POT:
			base_pitch = 1.06
		CUE_MAJOR_COMPLETION:
			base_pitch = 1.16
		CUE_REPLAY_TICK:
			base_pitch = 0.94
	var excitement_offset: float = (
		clampf(float(request.get("excitement_normalized", 0.0)), 0.0, 1.0)
		* MAX_EXCITEMENT_PITCH_OFFSET
	)
	var replay_offset: float = (
		clampf(float(request.get("replay_progress", 0.0)), 0.0, 1.0) * 0.08
	)
	return clampf(base_pitch + excitement_offset + replay_offset, MAIN_MIN_PITCH, MAIN_MAX_PITCH)


static func _calculate_main_volume_db(request: Dictionary) -> float:
	var cue_kind: String = str(request.get("cue_kind", ""))
	var base_volume_db := -21.0
	match cue_kind:
		CUE_BANK_2:
			base_volume_db = -19.5
		CUE_BANK_3:
			base_volume_db = -17.5
		CUE_COMBINATION:
			base_volume_db = -20.0
		CUE_DOUBLE_TAP:
			base_volume_db = -19.0
		CUE_TRIPLE_TAP:
			base_volume_db = -17.5
		CUE_BALL_TAP:
			base_volume_db = -21.0
		CUE_BALL_TAP_CHAIN:
			base_volume_db = -19.5
		CUE_POCKET:
			base_volume_db = -18.5
		CUE_MULTI_POT:
			base_volume_db = -17.0
		CUE_MAJOR_COMPLETION:
			base_volume_db = -16.5
		CUE_REPLAY_TICK:
			base_volume_db = -22.0
	var excitement_gain: float = (
		clampf(float(request.get("excitement_normalized", 0.0)), 0.0, 1.0)
		* MAX_EXCITEMENT_GAIN_DB
	)
	return clampf(base_volume_db + excitement_gain, MAIN_MIN_VOLUME_DB, MAIN_MAX_VOLUME_DB)


static func _calculate_bass_pitch(request: Dictionary) -> float:
	return clampf(_calculate_main_pitch(request) * BASS_PITCH_RATIO, 0.45, 0.92)


static func _calculate_bass_volume_db(request: Dictionary) -> float:
	var cue_kind: String = str(request.get("cue_kind", ""))
	var base_volume_db := -27.5
	match cue_kind:
		CUE_BANK_2, CUE_COMBINATION:
			base_volume_db = -24.5
		CUE_DOUBLE_TAP, CUE_BALL_TAP_CHAIN:
			base_volume_db = -24.0
		CUE_TRIPLE_TAP:
			base_volume_db = -21.5
		CUE_BALL_TAP:
			base_volume_db = -27.0
		CUE_BANK_3:
			base_volume_db = -21.5
		CUE_POCKET:
			base_volume_db = -23.0
		CUE_MULTI_POT, CUE_MAJOR_COMPLETION:
			base_volume_db = -20.5
	var excitement_gain: float = (
		clampf(float(request.get("excitement_normalized", 0.0)), 0.0, 1.0)
		* MAX_EXCITEMENT_BASS_GAIN_DB
	)
	return clampf(base_volume_db + excitement_gain, BASS_MIN_VOLUME_DB, BASS_MAX_VOLUME_DB)


static func _get_excitement_normalized(value: float) -> float:
	if MAX_GLOBAL_EXCITEMENT <= 0.0:
		return 0.0
	return clampf(value / MAX_GLOBAL_EXCITEMENT, 0.0, 1.0)


static func _empty_voice_state() -> Dictionary:
	return {
		"request_id": -1,
		"priority": -1,
		"started_usec": 0,
		"cue_kind": "",
	}


static func _is_finite_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
