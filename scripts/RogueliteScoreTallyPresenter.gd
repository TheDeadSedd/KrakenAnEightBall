extends Node
class_name RogueliteScoreTallyPresenter

signal tally_started(snapshot: Dictionary)
signal tally_step_changed(snapshot: Dictionary)
signal tally_completed(snapshot: Dictionary)
signal tally_canceled(reason: String, snapshot: Dictionary)
signal state_changed(snapshot: Dictionary)

const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")
const NARRATIVE_BUILDER := preload("res://scripts/RogueliteScoringNarrativeBuilder.gd")
const STEP_ACCENT_STREAM := preload("res://audio/sfx/billiards/ball_hit_01.wav")
const FINAL_ACCENT_STREAM := preload("res://audio/sfx/environment/pocket_multi.wav")

const PRESENTATION_LOCK_ID := "roguelite_score_tally"
const STATE_IDLE := "idle"
const STATE_ENTRANCE := "entrance"
const STATE_STEP := "resolution_step"
const STATE_FINAL_SETTLE := "final_settle"
const STATE_FINAL_COUNT := "final_count"
const STATE_ROUND_FILL := "round_progress_fill"
const STATE_FINAL_HOLD := "final_hold"
const STATE_WAITING_FOR_DISMISSAL := "waiting_for_dismissal"
const STATE_ZERO_FEEDBACK := "zero_score_feedback"
const STATE_EXIT := "exit"

const ENTRANCE_DURATION := 0.16
const ORDINARY_STEP_DURATION := 0.24
const XMULT_STEP_DURATION := 0.38
const CONSEQUENCE_STEP_DURATION := 0.25
const ZERO_CONSEQUENCE_STEP_DURATION := 0.14
const FINAL_SETTLE_DURATION := 0.13
const ROUND_FILL_DURATION := 0.34
const FINAL_HOLD_DURATION := 0.58
const ZERO_FINAL_HOLD_DURATION := 0.06
const ZERO_FEEDBACK_DURATION := 0.82
const ZERO_STING_SECOND_NOTE_DELAY := 0.155
const EXIT_DURATION := 0.15
const FAST_FORWARD_MULTIPLIER := 4.0
const IMMEDIATE_HOLD_THRESHOLD := 0.72
const MAX_STATE_TRANSITIONS_PER_FRAME := 64

const CONFIGURATION_SCHEMA_VERSION := 5
const PREVIOUS_DEFAULT_PLAYBACK_SPEED := 0.5
const DEFAULT_PLAYBACK_SPEED := 0.375
const MIN_PLAYBACK_SPEED := 0.25
const MAX_PLAYBACK_SPEED := 3.0

# Tick cadence follows tween time, not integer distance, so very large scores stay bounded.
const TALLY_TICK_VOICE_COUNT := 6
const TICK_INTERVAL_START := 0.052
const TICK_INTERVAL_END := 0.034
const TICK_FAST_FORWARD_MIN_INTERVAL := 0.028
const TICK_FAST_FORWARD_CADENCE_SCALE := 1.6
const TICK_START_PITCH := 0.90
const TICK_STEP_START_PITCH_INCREMENT := 0.05
const TICK_MAX_START_PITCH := 1.08
const TICK_ORDINARY_PITCH_SPAN := 0.28
const TICK_XMULT_PITCH_SPAN := 0.34
const TICK_FINAL_PITCH_SPAN := 0.38
const TICK_MAX_PITCH := 1.50
const DEFAULT_TICK_VOLUME_DB := -22.0
const TICK_FIRST_VOLUME_BOOST_DB := 2.5
const TICK_LANDING_VOLUME_BOOST_DB := 1.5
const MIN_TICK_VOLUME_DB := -36.0
const MAX_TICK_VOLUME_DB := -14.0
const TALLY_TICK_BASS_VOICE_COUNT := 4
const DEFAULT_TICK_BASS_ENABLED := true
const DEFAULT_TICK_BASS_VOLUME_DB := -25.0
const MIN_TICK_BASS_VOLUME_DB := -36.0
const MAX_TICK_BASS_VOLUME_DB := -18.0
const TICK_BASS_PITCH_RATIO := 0.62
const TICK_BASS_FIRST_VOLUME_BOOST_DB := 1.0
const TICK_BASS_LANDING_VOLUME_BOOST_DB := 0.75
const TICK_BASS_DENSITY_RULE := "first + every 2nd + landing; xMult/final 2 of 3; fast-forward every 3rd"
const TALLY_TICK_BUS_NAME := "TallyTick"
const TALLY_TICK_BASS_BUS_NAME := "TallyTickBass"
const DEFAULT_TICK_REVERB_ENABLED := true
const DEFAULT_TICK_REVERB_WET := 0.11
const MIN_TICK_REVERB_WET := 0.0
const MAX_TICK_REVERB_WET := 0.25
const TICK_REVERB_ROOM_SIZE := 0.32
const TICK_REVERB_DAMPING := 0.84
const TICK_REVERB_SPREAD := 0.35
const TICK_REVERB_HIPASS := 0.12
const TICK_REVERB_PREDELAY_MSEC := 2.0
const TICK_BASS_HIGHPASS_HZ := 100.0
const TICK_BASS_LOWPASS_HZ := 900.0
const MAX_TICKS_PER_FRAME := 3

var table: BilliardsTable
var tally_hud: RogueliteScoreTallyHUD
var roguelite_scoring_system: RogueliteScoringSystem
var world_presenter: RogueliteWorldScorePresenter
var live_scoring_system: RogueliteLiveScoringAnticipationSystem
var scoring_cue_conductor: RogueliteScoringCueConductor

var enabled := true
var playback_speed := DEFAULT_PLAYBACK_SPEED
var playback_speed_customized := false
var instant_tally := false
var show_resolution_history := true
var play_tally_audio := true
var world_score_callouts := true
var persistent_equation := true
var persistent_round_bar := true
var local_source_flashes := true
var detailed_modal_auto_open := false
var final_result_requires_dismissal := false
var zero_score_quick_feedback := true
var auto_dismiss_final_result := false
var show_presentation_anchors := false
var live_scoring_anticipation := true
var live_scoring_words := true
var live_scoring_audio := true
var global_excitement_enabled := true
var global_excitement_strength := 1.0
var ghost_ball_replay := true
var ghost_trails := true
var per_ball_subtotals := true
var show_predicted_narratives := false
var show_event_matching := false
var tally_tick_volume_db := DEFAULT_TICK_VOLUME_DB
var tally_tick_bass_enabled := DEFAULT_TICK_BASS_ENABLED
var tally_tick_bass_volume_db := DEFAULT_TICK_BASS_VOLUME_DB
var tally_tick_reverb_enabled := DEFAULT_TICK_REVERB_ENABLED
var tally_tick_reverb_wet := DEFAULT_TICK_REVERB_WET

var presenter_active := false
var current_state := STATE_IDLE
var state_elapsed := 0.0
var state_duration := 0.0
var presentation_started_usec := 0
var current_result: Dictionary = {}
var last_score_result: Dictionary = {}
var current_steps: Array = []
var current_step: Dictionary = {}
var current_step_index := -1
var last_applied_step_index := -1
var current_resolution_key := ""
var last_auto_resolution_key := ""
var replay_mode_active := false
var current_comparison: Dictionary = {}
var last_comparison: Dictionary = {}
var current_narrative: Dictionary = {}
var last_narrative: Dictionary = {}
var current_narrative_valid := false
var current_narrative_input_diagnostics: Dictionary = {}
var last_narrative_input_diagnostics: Dictionary = {}
var current_ball_narratives_by_id: Dictionary = {}
var current_replay_ball_id := -1
var inherited_live_excitement := 0.0
var narrative_fallback_count := 0
var last_narrative_warning := ""
var presentation_self_tests: Dictionary = {}
var active_shot_lab_setup_generation := -1
var current_detailed_modal_visible := false
var last_dismissal_method := "none"

var current_displayed_haul := 0.0
var current_displayed_mult := 1.0
var current_displayed_score := 0.0
var step_haul_from := 0.0
var step_haul_to := 0.0
var step_mult_from := 1.0
var step_mult_to := 1.0
var step_score_from := 0.0
var step_score_to := 0.0
var final_haul_from := 0.0
var final_mult_from := 1.0
var final_score_from := 0.0

var fast_forward_active := false
var fast_forward_hold_elapsed := 0.0
var presentation_lock_active := false
var queued_follow_up_presentation := "none"

var completed_tally_count := 0
var canceled_tally_count := 0
var duplicate_start_suppression_count := 0
var duplicate_completion_suppression_count := 0
var legacy_default_migration_count := 0
var last_presentation_duration := 0.0
var last_shot_id := -1
var last_attempt_id := -1
var last_cancel_reason := ""
var zero_score_sting_count := 0
var zero_second_note_pending := false
var zero_second_note_elapsed := 0.0
var zero_stale_note_suppression_count := 0

var step_audio_player: AudioStreamPlayer
var final_audio_player: AudioStreamPlayer
var zero_sting_first_player: AudioStreamPlayer
var zero_sting_second_player: AudioStreamPlayer
var tally_tick_players: Array[AudioStreamPlayer] = []
var tally_tick_bass_players: Array[AudioStreamPlayer] = []
var next_tick_voice_index := 0
var next_bass_tick_voice_index := 0
var tick_train_active := false
var tick_train_waiting_for_motion := false
var tick_train_visual_kind := ""
var tick_elapsed := 0.0
var current_tick_interval := TICK_INTERVAL_START
var current_tick_pitch := TICK_START_PITCH
var current_bass_tick_pitch := TICK_START_PITCH * TICK_BASS_PITCH_RATIO
var current_tick_start_pitch := TICK_START_PITCH
var current_tick_end_pitch := TICK_START_PITCH + TICK_ORDINARY_PITCH_SPAN
var current_step_tick_count := 0
var current_tally_tick_count := 0
var last_tally_tick_count := 0
var skipped_ticks_due_voice_cap := 0
var last_tally_skipped_ticks_due_voice_cap := 0
var tick_voice_reuse_count := 0
var skipped_bass_ticks_due_voice_cap := 0
var last_tally_skipped_bass_ticks_due_voice_cap := 0
var bass_tick_voice_reuse_count := 0
var scoring_tick_step_ordinal := 0
var tally_tick_bus_index := -1
var tally_tick_bass_bus_index := -1
var tally_reverb_effect_index := -1
var tally_reverb_effect: AudioEffectReverb
var tally_audio_effects_available := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	set_process_input(true)
	_build_audio_players()


func setup(table_ref: BilliardsTable, hud_ref: RogueliteScoreTallyHUD) -> void:
	table = table_ref
	tally_hud = hud_ref
	roguelite_scoring_system = null
	if table != null:
		roguelite_scoring_system = table.roguelite_scoring_system as RogueliteScoringSystem
	if (
		roguelite_scoring_system != null
		and not roguelite_scoring_system.roguelite_shot_score_resolved.is_connected(_on_score_resolved)
	):
		roguelite_scoring_system.roguelite_shot_score_resolved.connect(_on_score_resolved)
	if (
		table != null
		and table.shot_lab_system != null
		and not table.shot_lab_system.result_completed.is_connected(_on_shot_lab_result_completed)
	):
		table.shot_lab_system.result_completed.connect(_on_shot_lab_result_completed)
	if (
		table != null
		and table.shot_lab_system != null
		and not table.shot_lab_system.state_changed.is_connected(_on_shot_lab_state_changed)
	):
		table.shot_lab_system.state_changed.connect(_on_shot_lab_state_changed)
	presentation_self_tests["narrative"] = NARRATIVE_BUILDER.run_self_tests()
	_emit_state()


func set_world_presenter(presenter: RogueliteWorldScorePresenter) -> void:
	if (
		world_presenter != null
		and is_instance_valid(world_presenter)
		and world_presenter.final_result_dismiss_requested.is_connected(_on_final_result_dismiss_requested)
	):
		world_presenter.final_result_dismiss_requested.disconnect(_on_final_result_dismiss_requested)
	world_presenter = presenter
	if world_presenter != null:
		if not world_presenter.final_result_dismiss_requested.is_connected(_on_final_result_dismiss_requested):
			world_presenter.final_result_dismiss_requested.connect(_on_final_result_dismiss_requested)
		_apply_world_presentation_configuration()


func set_live_scoring_system(system: RogueliteLiveScoringAnticipationSystem) -> void:
	live_scoring_system = system
	scoring_cue_conductor = (
		live_scoring_system.get_conductor()
		if live_scoring_system != null
		else null
	)
	if live_scoring_system != null:
		presentation_self_tests["event_matching"] = (
			live_scoring_system.run_event_matching_self_tests()
		)
	if scoring_cue_conductor != null:
		presentation_self_tests["conductor"] = (
			scoring_cue_conductor.run_arbitration_stress_self_test()
		)
	_apply_live_scoring_configuration()


func _exit_tree() -> void:
	if presentation_lock_active:
		_set_presentation_lock(false)
	if tally_hud != null and is_instance_valid(tally_hud):
		tally_hud.finish_tally()
	if world_presenter != null and is_instance_valid(world_presenter):
		world_presenter.cancel_presentation("scene_teardown")
	presenter_active = false
	set_process(false)
	_stop_audio()
	if scoring_cue_conductor != null:
		scoring_cue_conductor.cancel_all("scene_teardown")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and presenter_active:
		complete_immediately("focus_lost", true)


func _input(event: InputEvent) -> void:
	if not presenter_active or get_tree() == null:
		return
	if get_tree().paused:
		if event is InputEventMouseButton:
			var paused_mouse_event: InputEventMouseButton = event
			if paused_mouse_event.button_index == MOUSE_BUTTON_LEFT and not paused_mouse_event.pressed:
				_set_fast_forward(false)
		elif event is InputEventKey:
			var paused_key_event: InputEventKey = event
			if (
				paused_key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
				and not paused_key_event.pressed
			):
				_set_fast_forward(false)
		return
	if current_state == STATE_WAITING_FOR_DISMISSAL:
		if event is InputEventKey:
			var dismiss_key_event: InputEventKey = event
			if (
				dismiss_key_event.pressed
				and not dismiss_key_event.echo
				and dismiss_key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
			):
				dismiss_final_result("confirm_key")
				if get_viewport() != null:
					get_viewport().set_input_as_handled()
		return
	var handled := false
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed and _is_allowed_ui_interaction_under_mouse():
				return
			_set_fast_forward(mouse_event.pressed)
			handled = true
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			if key_event.echo:
				return
			_set_fast_forward(key_event.pressed)
			handled = true
	if handled and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not presenter_active or get_tree() == null or get_tree().paused:
		return
	_update_zero_sting(delta)
	if current_state == STATE_WAITING_FOR_DISMISSAL:
		return
	if fast_forward_active:
		fast_forward_hold_elapsed += delta
		if fast_forward_hold_elapsed >= IMMEDIATE_HOLD_THRESHOLD:
			complete_immediately("sustained_fast_forward", false)
			return

	# Zero-score feedback is an authored real-time beat, not a slowed tally phase.
	var speed_multiplier: float = 1.0 if current_state == STATE_ZERO_FEEDBACK else playback_speed
	if fast_forward_active:
		speed_multiplier *= FAST_FORWARD_MULTIPLIER
	var remaining_delta: float = maxf(delta * speed_multiplier, 0.0)
	var transition_count := 0
	while presenter_active and transition_count < MAX_STATE_TRANSITIONS_PER_FRAME:
		var remaining_in_state: float = maxf(state_duration - state_elapsed, 0.0)
		if state_duration <= 0.0 or remaining_delta >= remaining_in_state:
			state_elapsed = state_duration
			_update_current_state()
			remaining_delta = maxf(remaining_delta - remaining_in_state, 0.0)
			_advance_from_current_state()
			transition_count += 1
			if remaining_delta <= 0.0:
				break
			continue
		state_elapsed += remaining_delta
		_update_current_state()
		break
	if presenter_active:
		_update_tick_train(delta)


func play_score_result(
	score_result: Dictionary,
	predicted_summary: Dictionary = {},
	replay_mode: bool = false,
	force_instant: bool = false
) -> bool:
	if score_result.is_empty() or table == null or tally_hud == null:
		return false
	var mode_id: String = str(score_result.get("mode_id", table.get_game_mode_id()))
	if mode_id not in [GAME_MODE_SCRIPT.MODE_ROGUELITE, GAME_MODE_SCRIPT.MODE_SHOT_LAB]:
		return false

	last_score_result = score_result.duplicate(true)
	last_shot_id = int(score_result.get("shot_id", -1))
	last_attempt_id = int(score_result.get("attempt_id", -1))
	var resolution_key: String = _make_resolution_key(score_result)
	if not replay_mode and resolution_key == last_auto_resolution_key:
		duplicate_start_suppression_count += 1
		_emit_state()
		return false
	if presenter_active:
		cancel_tally("superseded", false)

	current_result = score_result.duplicate(true)
	_prepare_narrative_sequence(current_result, replay_mode)
	current_step.clear()
	current_step_index = -1
	last_applied_step_index = -1
	current_replay_ball_id = -1
	current_resolution_key = resolution_key
	if not replay_mode:
		last_auto_resolution_key = resolution_key
	replay_mode_active = replay_mode
	active_shot_lab_setup_generation = -1
	if table.is_shot_lab_mode() and table.shot_lab_system != null:
		active_shot_lab_setup_generation = int(
			table.shot_lab_system.get_snapshot().get("setup_generation", -1)
		)
	current_comparison = predicted_summary.duplicate(true)
	if not predicted_summary.is_empty():
		last_comparison = predicted_summary.duplicate(true)
	current_displayed_haul = 0.0
	current_displayed_mult = 1.0
	current_displayed_score = 0.0
	current_detailed_modal_visible = detailed_modal_auto_open
	_stop_audio()
	_reset_tick_tally_state()
	fast_forward_active = false
	fast_forward_hold_elapsed = 0.0
	presentation_started_usec = Time.get_ticks_usec()
	presenter_active = true
	last_cancel_reason = ""
	last_dismissal_method = "none"
	_set_presentation_lock(true)
	tally_hud.begin_tally(
		current_result,
		replay_mode_active,
		show_resolution_history,
		current_detailed_modal_visible
	)
	if world_presenter != null:
		world_presenter.begin_presentation(current_result)
		world_presenter.begin_authoritative_narrative(current_narrative)
	inherited_live_excitement = (
		live_scoring_system.get_replay_excitement()
		if live_scoring_system != null
		else 0.0
	)
	if world_presenter != null:
		world_presenter.set_replay_excitement(inherited_live_excitement)
	if scoring_cue_conductor != null:
		scoring_cue_conductor.begin_replay(
			int(current_result.get("shot_id", -1)),
			int(current_result.get("attempt_id", -1)),
			_array_value(current_narrative, "ball_narratives"),
			inherited_live_excitement
		)
	if int(current_result.get("shot_score", 0)) <= 0 and zero_score_quick_feedback and not force_instant:
		if world_presenter != null:
			world_presenter.show_zero_indicator(_get_zero_score_reason(current_result))
		_play_zero_score_sting()
		_enter_state(STATE_ZERO_FEEDBACK, ZERO_FEEDBACK_DURATION)
	else:
		_enter_state(STATE_ENTRANCE, ENTRANCE_DURATION)
	set_process(true)
	tally_started.emit(get_diagnostics_snapshot())
	_emit_state()

	if force_instant or instant_tally:
		complete_immediately("instant_mode", true)
	return true


func replay_last_tally(force_instant: bool = false) -> bool:
	if last_score_result.is_empty():
		return false
	var previous_auto_open: bool = detailed_modal_auto_open
	detailed_modal_auto_open = true
	var started: bool = play_score_result(last_score_result, last_comparison, true, force_instant)
	detailed_modal_auto_open = previous_auto_open
	return started


func replay_last_world_tally(force_instant: bool = false) -> bool:
	if last_score_result.is_empty():
		return false
	var previous_auto_open: bool = detailed_modal_auto_open
	detailed_modal_auto_open = false
	var started: bool = play_score_result(last_score_result, last_comparison, true, force_instant)
	detailed_modal_auto_open = previous_auto_open
	return started


func complete_immediately(_reason: String = "immediate", auto_finish: bool = false) -> void:
	if not presenter_active:
		duplicate_completion_suppression_count += 1
		_emit_state()
		return
	_stop_tick_train(true)
	var start_index: int = maxi(last_applied_step_index + 1, 0)
	var presented_step_index: int = current_step_index if current_state == STATE_STEP else -1
	for step_index in range(start_index, current_steps.size()):
		var step_value: Variant = current_steps[step_index]
		if not step_value is Dictionary:
			continue
		current_step_index = step_index
		current_step = (step_value as Dictionary).duplicate(true)
		var trigger_already_presented: bool = step_index == presented_step_index
		_apply_step_exact(current_step, not trigger_already_presented)
		if world_presenter != null and not auto_finish:
			_sync_narrative_ball_for_step(current_step)
			_present_current_step_world(current_step, 0.30)
		last_applied_step_index = step_index
	_finish_current_ball_narrative()
	_apply_final_values()
	_commit_pending_round_score_if_needed()
	if tally_hud != null:
		tally_hud.show_final(
			int(current_result.get("final_haul", 0)),
			float(current_result.get("final_mult", 1.0)),
			int(current_result.get("shot_score", 0)),
			replay_mode_active,
			current_comparison
		)
	if world_presenter != null:
		world_presenter.finish_round_fill(current_result)
	if auto_finish or auto_dismiss_final_result or int(current_result.get("shot_score", 0)) <= 0:
		_finish_completed_tally()
		return
	_play_accent("final")
	if final_result_requires_dismissal and world_presenter != null:
		world_presenter.show_final_result(current_result)
		_enter_waiting_for_dismissal()
	else:
		_enter_state(STATE_EXIT, EXIT_DURATION)


func cancel_tally(reason: String, clear_last_result: bool = false) -> void:
	if not presenter_active:
		_stop_audio()
		if scoring_cue_conductor != null:
			scoring_cue_conductor.cancel_all(reason)
		if world_presenter != null:
			world_presenter.cancel_presentation(reason)
		if clear_last_result:
			_clear_retained_result()
			_emit_state()
		return
	last_cancel_reason = reason
	last_presentation_duration = _get_elapsed_presentation_seconds()
	canceled_tally_count += 1
	_archive_tick_tally_stats()
	presenter_active = false
	current_state = STATE_IDLE
	current_step.clear()
	current_step_index = -1
	current_replay_ball_id = -1
	replay_mode_active = false
	set_process(false)
	_set_fast_forward(false)
	_set_presentation_lock(false)
	_stop_audio()
	if scoring_cue_conductor != null:
		scoring_cue_conductor.cancel_all(reason)
	if tally_hud != null:
		tally_hud.finish_tally()
	if world_presenter != null:
		world_presenter.cancel_presentation(reason)
	if clear_last_result:
		_clear_retained_result()
	var snapshot: Dictionary = get_diagnostics_snapshot()
	tally_canceled.emit(reason, snapshot)
	_emit_state()


func restore_last_result_observation(score_result: Dictionary) -> void:
	if presenter_active:
		cancel_tally("rewind_restore", false)
	last_score_result = score_result.duplicate(true)
	last_shot_id = int(score_result.get("shot_id", -1)) if not score_result.is_empty() else -1
	last_attempt_id = int(score_result.get("attempt_id", -1)) if not score_result.is_empty() else -1
	last_auto_resolution_key = _make_resolution_key(score_result) if not score_result.is_empty() else ""
	last_comparison.clear()
	_emit_state()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled and presenter_active:
		complete_immediately("disabled", true)
	_emit_state()


func is_enabled() -> bool:
	return enabled


func set_shot_lab_apply_test_doubloon_payout(enabled_value: bool) -> void:
	if roguelite_scoring_system != null:
		roguelite_scoring_system.set_shot_lab_apply_test_doubloon_payout(enabled_value)
	_emit_state()


func is_shot_lab_apply_test_doubloon_payout_enabled() -> bool:
	return (
		roguelite_scoring_system != null
		and roguelite_scoring_system.is_shot_lab_apply_test_doubloon_payout_enabled()
	)


func set_playback_speed(value: float, mark_customized: bool = true) -> void:
	playback_speed = clampf(value, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
	if mark_customized:
		playback_speed_customized = true
	_emit_state()


func get_playback_speed() -> float:
	return playback_speed


func set_instant_tally(value: bool) -> void:
	instant_tally = value
	if instant_tally and presenter_active:
		complete_immediately("instant_option_enabled", true)
	_emit_state()


func is_instant_tally_enabled() -> bool:
	return instant_tally


func set_show_resolution_history(value: bool) -> void:
	show_resolution_history = value
	_emit_state()


func is_resolution_history_enabled() -> bool:
	return show_resolution_history


func set_play_tally_audio(value: bool) -> void:
	play_tally_audio = value
	if not play_tally_audio:
		_stop_audio()
	_emit_state()


func is_tally_audio_enabled() -> bool:
	return play_tally_audio


func set_tally_tick_volume_db(value: float) -> void:
	tally_tick_volume_db = clampf(value, MIN_TICK_VOLUME_DB, MAX_TICK_VOLUME_DB)
	_emit_state()


func get_tally_tick_volume_db() -> float:
	return tally_tick_volume_db


func set_tally_tick_bass_enabled(value: bool) -> void:
	tally_tick_bass_enabled = value
	if not tally_tick_bass_enabled:
		_stop_bass_tick_voices()
	_emit_state()


func is_tally_tick_bass_enabled() -> bool:
	return tally_tick_bass_enabled


func set_tally_tick_bass_volume_db(value: float) -> void:
	tally_tick_bass_volume_db = clampf(
		value,
		MIN_TICK_BASS_VOLUME_DB,
		MAX_TICK_BASS_VOLUME_DB
	)
	_emit_state()


func get_tally_tick_bass_volume_db() -> float:
	return tally_tick_bass_volume_db


func set_tally_tick_reverb_enabled(value: bool) -> void:
	tally_tick_reverb_enabled = value
	_apply_tally_reverb_tuning()
	_emit_state()


func is_tally_tick_reverb_enabled() -> bool:
	return tally_tick_reverb_enabled


func set_tally_tick_reverb_wet(value: float) -> void:
	tally_tick_reverb_wet = clampf(value, MIN_TICK_REVERB_WET, MAX_TICK_REVERB_WET)
	_apply_tally_reverb_tuning()
	_emit_state()


func get_tally_tick_reverb_wet() -> float:
	return tally_tick_reverb_wet


func reset_tally_audio_tuning() -> void:
	_reset_tally_audio_tuning_values()
	_apply_tally_audio_tuning()
	_emit_state()


func set_world_score_callouts_enabled(value: bool) -> void:
	world_score_callouts = value
	_apply_world_presentation_configuration()
	_emit_state()


func is_world_score_callouts_enabled() -> bool:
	return world_score_callouts


func set_persistent_equation_enabled(value: bool) -> void:
	persistent_equation = value
	_apply_world_presentation_configuration()
	_emit_state()


func is_persistent_equation_enabled() -> bool:
	return persistent_equation


func set_persistent_round_bar_enabled(value: bool) -> void:
	persistent_round_bar = value
	_apply_world_presentation_configuration()
	_emit_state()


func is_persistent_round_bar_enabled() -> bool:
	return persistent_round_bar


func set_local_source_flashes_enabled(value: bool) -> void:
	local_source_flashes = value
	_apply_world_presentation_configuration()
	_emit_state()


func is_local_source_flashes_enabled() -> bool:
	return local_source_flashes


func set_detailed_modal_auto_open(value: bool) -> void:
	detailed_modal_auto_open = value
	_emit_state()


func is_detailed_modal_auto_open_enabled() -> bool:
	return detailed_modal_auto_open


func set_final_result_requires_dismissal(value: bool) -> void:
	final_result_requires_dismissal = value
	if not value and current_state == STATE_WAITING_FOR_DISMISSAL:
		dismiss_final_result("dismissal_disabled")
	_emit_state()


func is_final_result_dismissal_required() -> bool:
	return final_result_requires_dismissal


func set_zero_score_quick_feedback_enabled(value: bool) -> void:
	zero_score_quick_feedback = value
	_emit_state()


func is_zero_score_quick_feedback_enabled() -> bool:
	return zero_score_quick_feedback


func set_auto_dismiss_final_result(value: bool) -> void:
	auto_dismiss_final_result = value
	if value and current_state == STATE_WAITING_FOR_DISMISSAL:
		dismiss_final_result("auto_dismiss_option")
	_emit_state()


func is_auto_dismiss_final_result_enabled() -> bool:
	return auto_dismiss_final_result


func set_show_presentation_anchors(value: bool) -> void:
	show_presentation_anchors = value
	_apply_world_presentation_configuration()
	_emit_state()


func is_show_presentation_anchors_enabled() -> bool:
	return show_presentation_anchors


func set_live_scoring_anticipation_enabled(value: bool) -> void:
	live_scoring_anticipation = value
	_apply_live_scoring_configuration()
	_emit_state()


func is_live_scoring_anticipation_enabled() -> bool:
	return live_scoring_anticipation


func set_live_scoring_words_enabled(value: bool) -> void:
	live_scoring_words = value
	_apply_live_scoring_configuration()
	_emit_state()


func is_live_scoring_words_enabled() -> bool:
	return live_scoring_words


func set_live_scoring_audio_enabled(value: bool) -> void:
	live_scoring_audio = value
	_apply_live_scoring_configuration()
	_emit_state()


func is_live_scoring_audio_enabled() -> bool:
	return live_scoring_audio


func set_global_excitement_enabled(value: bool) -> void:
	global_excitement_enabled = value
	_apply_live_scoring_configuration()
	_emit_state()


func is_global_excitement_enabled() -> bool:
	return global_excitement_enabled


func set_global_excitement_strength(value: float) -> void:
	global_excitement_strength = clampf(value, 0.0, 2.0)
	_apply_live_scoring_configuration()
	_emit_state()


func get_global_excitement_strength() -> float:
	return global_excitement_strength


func set_ghost_ball_replay_enabled(value: bool) -> void:
	ghost_ball_replay = value
	_apply_world_presentation_configuration()
	_emit_state()


func is_ghost_ball_replay_enabled() -> bool:
	return ghost_ball_replay


func set_ghost_trails_enabled(value: bool) -> void:
	ghost_trails = value
	_apply_world_presentation_configuration()
	_emit_state()


func is_ghost_trails_enabled() -> bool:
	return ghost_trails


func set_per_ball_subtotals_enabled(value: bool) -> void:
	per_ball_subtotals = value
	_apply_world_presentation_configuration()
	_emit_state()


func is_per_ball_subtotals_enabled() -> bool:
	return per_ball_subtotals


func set_show_predicted_narratives(value: bool) -> void:
	show_predicted_narratives = value
	_emit_state()


func is_show_predicted_narratives_enabled() -> bool:
	return show_predicted_narratives


func set_show_event_matching(value: bool) -> void:
	show_event_matching = value
	_emit_state()


func is_show_event_matching_enabled() -> bool:
	return show_event_matching


func replay_last_ball_narrative(force_instant: bool = false) -> bool:
	return replay_last_world_tally(force_instant)


func get_configuration_snapshot() -> Dictionary:
	return {
		"schema_version": CONFIGURATION_SCHEMA_VERSION,
		"enabled": enabled,
		"playback_speed": playback_speed,
		"playback_speed_customized": playback_speed_customized,
		"instant_tally": instant_tally,
		"show_resolution_history": show_resolution_history,
		"play_tally_audio": play_tally_audio,
		"world_score_callouts": world_score_callouts,
		"persistent_equation": persistent_equation,
		"persistent_round_bar": persistent_round_bar,
		"local_source_flashes": local_source_flashes,
		"detailed_modal_auto_open": detailed_modal_auto_open,
		"final_result_requires_dismissal": final_result_requires_dismissal,
		"zero_score_quick_feedback": zero_score_quick_feedback,
		"auto_dismiss_final_result": auto_dismiss_final_result,
		"show_presentation_anchors": show_presentation_anchors,
		"live_scoring_anticipation": live_scoring_anticipation,
		"live_scoring_words": live_scoring_words,
		"live_scoring_audio": live_scoring_audio,
		"global_excitement_enabled": global_excitement_enabled,
		"global_excitement_strength": global_excitement_strength,
		"ghost_ball_replay": ghost_ball_replay,
		"ghost_trails": ghost_trails,
		"per_ball_subtotals": per_ball_subtotals,
		"show_predicted_narratives": show_predicted_narratives,
		"show_event_matching": show_event_matching,
		"tally_tick_volume_db": tally_tick_volume_db,
		"tally_tick_bass_enabled": tally_tick_bass_enabled,
		"tally_tick_bass_volume_db": tally_tick_bass_volume_db,
		"tally_tick_reverb_enabled": tally_tick_reverb_enabled,
		"tally_tick_reverb_wet": tally_tick_reverb_wet,
	}


func apply_configuration_snapshot(snapshot: Dictionary) -> void:
	enabled = bool(snapshot.get("enabled", enabled))
	var source_schema_version: int = int(snapshot.get("schema_version", 1))
	var source_playback_speed: float = float(snapshot.get(
		"playback_speed",
		DEFAULT_PLAYBACK_SPEED
	))
	var source_customized: bool = bool(snapshot.get(
		"playback_speed_customized",
		false
	))
	var is_untouched_previous_default: bool = (
		not source_customized
		and source_schema_version < CONFIGURATION_SCHEMA_VERSION
		and is_equal_approx(source_playback_speed, PREVIOUS_DEFAULT_PLAYBACK_SPEED)
	)
	if is_untouched_previous_default:
		playback_speed = DEFAULT_PLAYBACK_SPEED
		playback_speed_customized = false
		legacy_default_migration_count += 1
	else:
		playback_speed = clampf(source_playback_speed, MIN_PLAYBACK_SPEED, MAX_PLAYBACK_SPEED)
		playback_speed_customized = source_customized
	instant_tally = bool(snapshot.get("instant_tally", instant_tally))
	show_resolution_history = bool(snapshot.get("show_resolution_history", show_resolution_history))
	play_tally_audio = bool(snapshot.get("play_tally_audio", play_tally_audio))
	world_score_callouts = bool(snapshot.get("world_score_callouts", world_score_callouts))
	persistent_equation = bool(snapshot.get("persistent_equation", persistent_equation))
	persistent_round_bar = bool(snapshot.get("persistent_round_bar", persistent_round_bar))
	local_source_flashes = bool(snapshot.get("local_source_flashes", local_source_flashes))
	detailed_modal_auto_open = bool(snapshot.get("detailed_modal_auto_open", detailed_modal_auto_open))
	final_result_requires_dismissal = (
		false
		if source_schema_version < CONFIGURATION_SCHEMA_VERSION
		else bool(snapshot.get("final_result_requires_dismissal", final_result_requires_dismissal))
	)
	zero_score_quick_feedback = bool(snapshot.get("zero_score_quick_feedback", zero_score_quick_feedback))
	auto_dismiss_final_result = bool(snapshot.get("auto_dismiss_final_result", auto_dismiss_final_result))
	show_presentation_anchors = bool(snapshot.get("show_presentation_anchors", show_presentation_anchors))
	live_scoring_anticipation = bool(snapshot.get("live_scoring_anticipation", live_scoring_anticipation))
	live_scoring_words = bool(snapshot.get("live_scoring_words", live_scoring_words))
	live_scoring_audio = bool(snapshot.get("live_scoring_audio", live_scoring_audio))
	global_excitement_enabled = bool(snapshot.get("global_excitement_enabled", global_excitement_enabled))
	global_excitement_strength = clampf(float(snapshot.get("global_excitement_strength", global_excitement_strength)), 0.0, 2.0)
	ghost_ball_replay = bool(snapshot.get("ghost_ball_replay", ghost_ball_replay))
	ghost_trails = bool(snapshot.get("ghost_trails", ghost_trails))
	per_ball_subtotals = bool(snapshot.get("per_ball_subtotals", per_ball_subtotals))
	show_predicted_narratives = bool(snapshot.get("show_predicted_narratives", show_predicted_narratives))
	show_event_matching = bool(snapshot.get("show_event_matching", show_event_matching))
	tally_tick_volume_db = clampf(
		float(snapshot.get("tally_tick_volume_db", tally_tick_volume_db)),
		MIN_TICK_VOLUME_DB,
		MAX_TICK_VOLUME_DB
	)
	tally_tick_bass_enabled = bool(snapshot.get(
		"tally_tick_bass_enabled",
		tally_tick_bass_enabled
	))
	tally_tick_bass_volume_db = clampf(
		float(snapshot.get("tally_tick_bass_volume_db", tally_tick_bass_volume_db)),
		MIN_TICK_BASS_VOLUME_DB,
		MAX_TICK_BASS_VOLUME_DB
	)
	tally_tick_reverb_enabled = bool(snapshot.get(
		"tally_tick_reverb_enabled",
		tally_tick_reverb_enabled
	))
	tally_tick_reverb_wet = clampf(
		float(snapshot.get("tally_tick_reverb_wet", tally_tick_reverb_wet)),
		MIN_TICK_REVERB_WET,
		MAX_TICK_REVERB_WET
	)
	_apply_tally_audio_tuning()
	_apply_world_presentation_configuration()
	_apply_live_scoring_configuration()
	if not enabled or instant_tally:
		if presenter_active:
			complete_immediately("configuration_applied", true)
	_emit_state()


func reset_tally_settings() -> void:
	enabled = true
	playback_speed = DEFAULT_PLAYBACK_SPEED
	playback_speed_customized = false
	instant_tally = false
	show_resolution_history = true
	play_tally_audio = true
	world_score_callouts = true
	persistent_equation = true
	persistent_round_bar = true
	local_source_flashes = true
	detailed_modal_auto_open = false
	final_result_requires_dismissal = false
	zero_score_quick_feedback = true
	auto_dismiss_final_result = false
	show_presentation_anchors = false
	live_scoring_anticipation = true
	live_scoring_words = true
	live_scoring_audio = true
	global_excitement_enabled = true
	global_excitement_strength = 1.0
	ghost_ball_replay = true
	ghost_trails = true
	per_ball_subtotals = true
	show_predicted_narratives = false
	show_event_matching = false
	_reset_tally_audio_tuning_values()
	_apply_tally_audio_tuning()
	_apply_world_presentation_configuration()
	_apply_live_scoring_configuration()
	_emit_state()


func request_open_diagnostics() -> void:
	if tally_hud == null:
		return
	tally_hud.open_diagnostics(get_diagnostics_snapshot())


func set_queued_follow_up(label: String) -> void:
	queued_follow_up_presentation = label if not label.is_empty() else "none"
	_emit_state()


func is_active() -> bool:
	return presenter_active


func get_last_score_result() -> Dictionary:
	return last_score_result.duplicate(true)


func get_diagnostics_snapshot() -> Dictionary:
	var observed_result: Dictionary = current_result if presenter_active else last_score_result
	var observed_steps: Array = current_steps if presenter_active else _array_value(
		observed_result,
		"resolution_steps"
	)
	var visual_diagnostics: Dictionary = (
		tally_hud.get_visual_diagnostics()
		if tally_hud != null and is_instance_valid(tally_hud)
		else {}
	)
	var world_diagnostics: Dictionary = (
		world_presenter.get_diagnostics_snapshot()
		if world_presenter != null and is_instance_valid(world_presenter)
		else {}
	)
	var scoring_diagnostics: Dictionary = (
		roguelite_scoring_system.get_diagnostics_snapshot()
		if roguelite_scoring_system != null
		else {}
	)
	var shot_transaction_diagnostics: Dictionary = (
		table.roguelite_run_system.get_shot_transaction_diagnostics()
		if table != null and table.roguelite_run_system != null
		else {}
	)
	var progress_diagnostics: Dictionary = _dictionary_value(world_diagnostics, "hud")
	var live_diagnostics: Dictionary = (
		live_scoring_system.get_state_snapshot()
		if live_scoring_system != null
		else {}
	)
	var conductor_diagnostics: Dictionary = (
		scoring_cue_conductor.get_state_snapshot()
		if scoring_cue_conductor != null
		else {}
	)
	var release_diagnostics: Dictionary = (
		table.get_prediction_release_snapshot()
		if table != null and table.has_method("get_prediction_release_snapshot")
		else {}
	)
	var observed_narrative: Dictionary = current_narrative if presenter_active else last_narrative
	var narrative_validation: Dictionary = _dictionary_value(observed_narrative, "validation")
	var narrative_input_diagnostics: Dictionary = (
		current_narrative_input_diagnostics
		if presenter_active
		else last_narrative_input_diagnostics
	)
	return {
		"presenter_active": presenter_active,
		"current_state": current_state,
		"current_step_index": current_step_index,
		"total_step_count": observed_steps.size(),
		"playback_speed": playback_speed,
		"playback_speed_customized": playback_speed_customized,
		"fast_forward_multiplier": FAST_FORWARD_MULTIPLIER,
		"fast_forward_effective_speed": playback_speed * FAST_FORWARD_MULTIPLIER,
		"fast_forward_active": fast_forward_active,
		"instant_mode": instant_tally,
		"current_displayed_haul": current_displayed_haul,
		"current_displayed_mult": current_displayed_mult,
		"current_displayed_score": current_displayed_score,
		"target_final_haul": int(observed_result.get("final_haul", 0)),
		"target_final_mult": float(observed_result.get("final_mult", 1.0)),
		"target_final_score": int(observed_result.get("shot_score", 0)),
		"presentation_lock_active": presentation_lock_active,
		"queued_follow_up_presentation": queued_follow_up_presentation,
		"quota_application_count": int(scoring_diagnostics.get("quota_application_count", 0)),
		"quota_application_duplicate_suppressions": int(scoring_diagnostics.get("quota_application_duplicate_suppressions", 0)),
		"current_round_score": int(progress_diagnostics.get("current_round_score", 0)),
		"displayed_round_score": float(progress_diagnostics.get("displayed_round_score", 0.0)),
		"current_quota": int(progress_diagnostics.get("current_quota", 0)),
		"pending_score_delta": int(progress_diagnostics.get("pending_score_delta", 0)),
		"authoritative_score_pending": bool(scoring_diagnostics.get("authoritative_score_pending", false)),
		"haul_mult_sole_authority": bool(scoring_diagnostics.get("haul_mult_sole_authority", true)),
		"doubloon_to_quota_connections": int(scoring_diagnostics.get("doubloon_to_quota_connections", 0)),
		"legacy_quota_bonus_calls": int(scoring_diagnostics.get("legacy_quota_bonus_calls", 0)),
		"legacy_presentation": _dictionary_value(
			scoring_diagnostics,
			"legacy_presentation"
		).duplicate(true),
		"doubloon_payout": _dictionary_value(
			scoring_diagnostics,
			"doubloon_payout"
		).duplicate(true),
		"pending_hull_damage": int(shot_transaction_diagnostics.get("pending_hull_damage", 0)),
		"shot_transaction_pending": (
			bool(scoring_diagnostics.get("authoritative_score_pending", false))
			or bool(shot_transaction_diagnostics.get("shot_transaction_pending", false))
		),
		"shot_transaction_diagnostics": shot_transaction_diagnostics.duplicate(true),
		"world_score_callouts_enabled": world_score_callouts,
		"persistent_equation_enabled": persistent_equation,
		"persistent_round_bar_enabled": persistent_round_bar,
		"local_source_flashes_enabled": local_source_flashes,
		"detailed_modal_auto_open": detailed_modal_auto_open,
		"final_result_requires_dismissal": final_result_requires_dismissal,
		"auto_dismiss_final_result": auto_dismiss_final_result,
		"final_result_waiting": current_state == STATE_WAITING_FOR_DISMISSAL,
		"outside_dismiss_layer_active": bool(_dictionary_value(world_diagnostics, "hud").get("outside_dismiss_layer_active", false)),
		"dismissal_method": last_dismissal_method,
		"zero_score_quick_feedback_enabled": zero_score_quick_feedback,
		"zero_score_indicator_active": bool(_dictionary_value(world_diagnostics, "hud").get("zero_score_indicator_active", false)),
		"zero_score_sting_count": zero_score_sting_count,
		"zero_second_note_pending": zero_second_note_pending,
		"zero_stale_note_suppression_count": zero_stale_note_suppression_count,
		"active_world_callouts": int(world_diagnostics.get("active_world_callouts", 0)),
		"mapped_anchor_count": int(world_diagnostics.get("mapped_anchor_count", 0)),
		"mapping_fallback_count": int(world_diagnostics.get("mapping_fallback_count", 0)),
		"mapped_anchors": _array_value(world_diagnostics, "mapped_anchors").duplicate(true),
		"mapping_warnings": _array_value(world_diagnostics, "mapping_warnings").duplicate(true),
		"mapping_missing_event_indices": _array_value(world_diagnostics, "mapping_missing_event_indices").duplicate(),
		"mapping_invalid_position_count": int(world_diagnostics.get("mapping_invalid_position_count", 0)),
		"offscreen_clamp_count": int(world_diagnostics.get("offscreen_clamp_count", 0)),
		"mapping_self_test": _dictionary_value(world_diagnostics, "mapping_self_test").duplicate(true),
		"show_presentation_anchors": show_presentation_anchors,
		"narrative_replay_active": current_narrative_valid,
		"narrative_validation": narrative_validation.duplicate(true),
		"narrative_fallback_count": narrative_fallback_count,
		"last_narrative_warning": last_narrative_warning,
		"narrative_input": narrative_input_diagnostics.duplicate(true),
		"narrative_input_identity_present": bool(
			narrative_input_diagnostics.get("identity_present", false)
		),
		"narrative_input_derived_present": bool(
			narrative_input_diagnostics.get("derived_present", false)
		),
		"narrative_input_raw_event_count": int(
			narrative_input_diagnostics.get("raw_event_count", 0)
		),
		"narrative_input_starting_ball_count": int(
			narrative_input_diagnostics.get("starting_ball_count", 0)
		),
		"narrative_fallback_reason": str(
			narrative_input_diagnostics.get("fallback_reason", "")
		),
		"presentation_self_tests": presentation_self_tests.duplicate(true),
		"current_replay_ball_id": current_replay_ball_id,
		"inherited_live_excitement": inherited_live_excitement,
		"live_scoring": live_diagnostics,
		"prediction_release": release_diagnostics,
		"scoring_conductor": conductor_diagnostics,
		"show_predicted_narratives": show_predicted_narratives,
		"show_event_matching": show_event_matching,
		"predicted_narrative": (
			live_scoring_system.get_predicted_narrative()
			if show_predicted_narratives and live_scoring_system != null
			else {}
		),
		"authoritative_narrative": (
			(current_narrative if presenter_active else last_narrative).duplicate(true)
			if show_predicted_narratives
			else {}
		),
		"event_matching": (
			live_diagnostics.duplicate(true)
			if show_event_matching
			else {}
		),
		"completed_tally_count": completed_tally_count,
		"canceled_tally_count": canceled_tally_count,
		"duplicate_start_suppression_count": duplicate_start_suppression_count,
		"duplicate_completion_suppression_count": duplicate_completion_suppression_count,
		"legacy_default_migration_count": legacy_default_migration_count,
		"tick_train_active": tick_train_active,
		"tick_train_visual_kind": tick_train_visual_kind,
		"current_step_tick_count": current_step_tick_count,
		"current_tally_tick_count": current_tally_tick_count,
		"last_tally_tick_count": last_tally_tick_count,
		"current_tick_pitch": current_tick_pitch,
		"current_bass_tick_pitch": current_bass_tick_pitch,
		"current_tick_start_pitch": current_tick_start_pitch,
		"current_tick_end_pitch": current_tick_end_pitch,
		"current_tick_interval": current_tick_interval,
		"active_tally_tick_voices": _get_active_tick_voice_count(),
		"active_tally_bass_tick_voices": _get_active_bass_tick_voice_count(),
		"tally_tick_volume_db": tally_tick_volume_db,
		"tally_tick_first_volume_db": _get_first_tick_volume_db(),
		"tally_tick_bass_enabled": tally_tick_bass_enabled,
		"tally_tick_bass_volume_db": tally_tick_bass_volume_db,
		"tally_tick_bass_pitch_ratio": TICK_BASS_PITCH_RATIO,
		"tally_tick_bass_density_rule": TICK_BASS_DENSITY_RULE,
		"tally_tick_reverb_enabled": (
			tally_tick_reverb_enabled and tally_audio_effects_available
		),
		"tally_tick_reverb_requested": tally_tick_reverb_enabled,
		"tally_tick_reverb_wet": tally_tick_reverb_wet,
		"tally_audio_effects_available": tally_audio_effects_available,
		"tally_tick_bus_name": TALLY_TICK_BUS_NAME,
		"tally_tick_bass_bus_name": TALLY_TICK_BASS_BUS_NAME,
		"tally_compressor_gain_reduction_available": false,
		"tally_compressor_gain_reduction_note": "Not exposed by Godot AudioEffect API",
		"skipped_ticks_due_voice_cap": skipped_ticks_due_voice_cap,
		"last_tally_skipped_ticks_due_voice_cap": last_tally_skipped_ticks_due_voice_cap,
		"tick_voice_reuse_count": tick_voice_reuse_count,
		"skipped_bass_ticks_due_voice_cap": skipped_bass_ticks_due_voice_cap,
		"last_tally_skipped_bass_ticks_due_voice_cap": last_tally_skipped_bass_ticks_due_voice_cap,
		"bass_tick_voice_reuse_count": bass_tick_voice_reuse_count,
		"current_trigger_font_size": int(visual_diagnostics.get("trigger_font_size", 0)),
		"current_trigger_glow_state": str(visual_diagnostics.get("trigger_glow_state", "idle")),
		"last_presentation_duration": last_presentation_duration,
		"last_shot_id": last_shot_id,
		"last_attempt_id": last_attempt_id,
		"replay_mode_active": replay_mode_active,
		"last_cancel_reason": last_cancel_reason,
		"current_step": current_step.duplicate(true),
		"score_result": observed_result.duplicate(true),
		"comparison": (current_comparison if presenter_active else last_comparison).duplicate(true),
	}


func _on_score_resolved(score_result: Dictionary) -> void:
	last_score_result = score_result.duplicate(true)
	last_shot_id = int(score_result.get("shot_id", -1))
	last_attempt_id = int(score_result.get("attempt_id", -1))
	if not enabled or table == null:
		_emit_state()
		return
	var force_instant: bool = table.is_shot_lab_mode() and _is_shot_lab_suite_running()
	play_score_result(score_result, {}, false, force_instant)


func _on_shot_lab_result_completed(result: Dictionary) -> void:
	var scoring: Dictionary = _dictionary_value(result, "scoring")
	var authoritative: Dictionary = _dictionary_value(scoring, "authoritative")
	if authoritative.is_empty():
		return
	var result_shot_id: int = int(authoritative.get("shot_id", result.get("shot_id", -1)))
	var result_attempt_id: int = int(authoritative.get("attempt_id", result.get("attempt_id", -1)))
	if result_shot_id != last_shot_id or result_attempt_id != last_attempt_id:
		return
	var predicted: Dictionary = _dictionary_value(scoring, "predicted")
	var parity: Dictionary = _dictionary_value(scoring, "parity")
	last_comparison = {
		"predicted_score": int(predicted.get("shot_score", 0)),
		"actual_score": int(authoritative.get("shot_score", 0)),
		"status": str(parity.get("status", "NOT RUN")),
	}
	if presenter_active:
		current_comparison = last_comparison.duplicate(true)
		if current_state in [STATE_FINAL_COUNT, STATE_ROUND_FILL, STATE_FINAL_HOLD, STATE_WAITING_FOR_DISMISSAL, STATE_EXIT] and tally_hud != null:
			tally_hud.set_comparison(current_comparison)
	_emit_state()


func _on_shot_lab_state_changed(snapshot: Dictionary) -> void:
	if not presenter_active or table == null or not table.is_shot_lab_mode():
		return
	if not bool(snapshot.get("active", false)):
		cancel_tally("shot_lab_cleared", true)
		return
	if int(snapshot.get("setup_generation", -1)) != active_shot_lab_setup_generation:
		cancel_tally("shot_lab_setup_changed", false)


func _enter_state(state_name: String, duration: float) -> void:
	current_state = state_name
	state_elapsed = 0.0
	state_duration = maxf(duration, 0.0)
	_emit_state()


func _update_current_state() -> void:
	var progress: float = 1.0 if state_duration <= 0.0 else clampf(state_elapsed / state_duration, 0.0, 1.0)
	match current_state:
		STATE_ENTRANCE:
			tally_hud.set_entrance_progress(progress)
		STATE_STEP:
			_update_resolution_step(progress)
		STATE_FINAL_COUNT:
			_update_final_count(progress)
		STATE_ROUND_FILL:
			if world_presenter != null:
				world_presenter.set_round_fill_progress(current_result, progress)
		STATE_ZERO_FEEDBACK:
			if world_presenter != null:
				world_presenter.set_zero_indicator_progress(progress)
		STATE_EXIT:
			tally_hud.set_exit_progress(progress)


func _advance_from_current_state() -> void:
	match current_state:
		STATE_ENTRANCE:
			if current_steps.is_empty():
				_finish_current_ball_narrative()
				_begin_final_settle()
			else:
				_begin_resolution_step(0)
		STATE_STEP:
			_finish_active_tick_train()
			_apply_step_exact(current_step, false)
			last_applied_step_index = current_step_index
			var next_index: int = current_step_index + 1
			if next_index < current_steps.size():
				_begin_resolution_step(next_index)
			else:
				_finish_current_ball_narrative()
				_begin_final_settle()
		STATE_FINAL_SETTLE:
			_begin_final_count()
		STATE_FINAL_COUNT:
			_finish_active_tick_train()
			_apply_final_values()
			tally_hud.show_final(
				int(current_result.get("final_haul", 0)),
				float(current_result.get("final_mult", 1.0)),
				int(current_result.get("shot_score", 0)),
				replay_mode_active,
				current_comparison
			)
			_play_accent("final")
			_commit_pending_round_score_if_needed()
			_enter_state(STATE_ROUND_FILL, ROUND_FILL_DURATION)
		STATE_ROUND_FILL:
			if world_presenter != null:
				world_presenter.finish_round_fill(current_result)
			if (
				int(current_result.get("shot_score", 0)) > 0
				and final_result_requires_dismissal
				and not auto_dismiss_final_result
				and world_presenter != null
			):
				world_presenter.show_final_result(current_result)
				_enter_waiting_for_dismissal()
			else:
				var hold_duration: float = ZERO_FINAL_HOLD_DURATION if int(current_result.get("shot_score", 0)) <= 0 else FINAL_HOLD_DURATION
				_enter_state(STATE_FINAL_HOLD, hold_duration)
		STATE_FINAL_HOLD:
			_enter_state(STATE_EXIT, EXIT_DURATION)
		STATE_ZERO_FEEDBACK:
			_commit_pending_round_score_if_needed()
			if world_presenter != null:
				world_presenter.finish_round_fill(current_result)
			_enter_state(STATE_EXIT, EXIT_DURATION)
		STATE_EXIT:
			_finish_completed_tally()
		STATE_WAITING_FOR_DISMISSAL:
			return
		_:
			finish_completed_tally_safely()


func finish_completed_tally_safely() -> void:
	if not presenter_active:
		return
	_apply_final_values()
	_finish_completed_tally()


func dismiss_final_result(method: String = "confirm") -> void:
	if not presenter_active or current_state != STATE_WAITING_FOR_DISMISSAL:
		return
	last_dismissal_method = method
	if world_presenter != null:
		world_presenter.hide_final_result(method)
	set_process(true)
	_enter_state(STATE_EXIT, EXIT_DURATION)


func _enter_waiting_for_dismissal() -> void:
	_stop_tick_train(false)
	current_state = STATE_WAITING_FOR_DISMISSAL
	state_elapsed = 0.0
	state_duration = 0.0
	set_process(false)
	_emit_state()


func _on_final_result_dismiss_requested(method: String) -> void:
	dismiss_final_result(method)


func _begin_resolution_step(step_index: int) -> void:
	_stop_tick_train(false)
	if step_audio_player != null:
		step_audio_player.stop()
	current_step_tick_count = 0
	current_step_index = step_index
	var step_value: Variant = current_steps[step_index] if step_index >= 0 and step_index < current_steps.size() else {}
	current_step = (step_value as Dictionary).duplicate(true) if step_value is Dictionary else {
		"step_index": step_index,
		"phase": "invalid",
		"source_id": "invalid_step",
		"display_name": "Invalid Resolution Step",
		"haul_before": current_displayed_haul,
		"haul_after": current_displayed_haul,
		"mult_before": current_displayed_mult,
		"mult_after": current_displayed_mult,
		"score_preview_after": current_displayed_score,
		"affects_score": false,
	}
	_sync_narrative_ball_for_step(current_step)
	step_haul_from = float(current_step.get("haul_before", current_displayed_haul))
	step_haul_to = float(current_step.get("haul_after", step_haul_from))
	step_mult_from = float(current_step.get("mult_before", current_displayed_mult))
	step_mult_to = float(current_step.get("mult_after", step_mult_from))
	step_score_from = current_displayed_score
	step_score_to = float(current_step.get("score_preview_after", step_score_from))
	current_displayed_haul = step_haul_from
	current_displayed_mult = step_mult_from
	tally_hud.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)
	if world_presenter != null:
		world_presenter.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)
	var visual_kind: String = _get_step_visual_kind(current_step)
	tally_hud.set_trigger(
		str(current_step.get("display_name", "Resolution Step")),
		_get_step_detail(current_step, visual_kind),
		_get_step_context(current_step, visual_kind),
		visual_kind,
		true,
		true
	)
	tally_hud.pulse_value(visual_kind)
	if visual_kind in ["xmult", "consequence", "legendary"]:
		_play_accent(visual_kind)
	if visual_kind in ["haul", "mult", "xmult"] and _current_step_has_numeric_motion():
		_begin_tick_train(visual_kind, visual_kind == "xmult")
	var step_duration: float = _get_step_duration(visual_kind, current_steps.size())
	if world_presenter != null:
		_present_current_step_world(
			current_step,
			step_duration / maxf(playback_speed, 0.01)
		)
	_request_replay_semantic_cue(current_step)
	_enter_state(STATE_STEP, step_duration)
	tally_step_changed.emit(get_diagnostics_snapshot())


func _update_resolution_step(progress: float) -> void:
	var visual_kind: String = _get_step_visual_kind(current_step)
	var value_progress: float = progress
	if visual_kind == "xmult":
		value_progress = clampf((progress - 0.24) / 0.76, 0.0, 1.0)
	value_progress = _ease_out_cubic(value_progress)
	current_displayed_haul = lerpf(step_haul_from, step_haul_to, value_progress)
	current_displayed_mult = lerpf(step_mult_from, step_mult_to, value_progress)
	current_displayed_score = lerpf(step_score_from, step_score_to, value_progress)
	tally_hud.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)
	if world_presenter != null:
		world_presenter.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)


func _apply_step_exact(step: Dictionary, append_history: bool) -> void:
	current_displayed_haul = float(step.get("haul_after", current_displayed_haul))
	current_displayed_mult = float(step.get("mult_after", current_displayed_mult))
	current_displayed_score = float(step.get("score_preview_after", current_displayed_score))
	if tally_hud == null:
		if world_presenter != null:
			world_presenter.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)
		return
	tally_hud.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)
	if world_presenter != null:
		world_presenter.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)
	if append_history:
		var visual_kind: String = _get_step_visual_kind(step)
		tally_hud.set_trigger(
			str(step.get("display_name", "Resolution Step")),
			_get_step_detail(step, visual_kind),
			_get_step_context(step, visual_kind),
			visual_kind,
			true,
			false
		)


func _begin_final_settle() -> void:
	_stop_tick_train(false)
	if step_audio_player != null:
		step_audio_player.stop()
	current_step_tick_count = 0
	current_step.clear()
	current_step_index = current_steps.size()
	if current_steps.is_empty() and int(current_result.get("shot_score", 0)) == 0:
		tally_hud.set_trigger(
			"No Haul",
			"0 HAUL x 1 MULT",
			"No scoring facts resolved",
			"neutral",
			false,
			false
		)
		_enter_state(STATE_FINAL_SETTLE, FINAL_SETTLE_DURATION)
		return
	tally_hud.set_trigger(
		"Final Equation",
		"%s HAUL x %s MULT" % [
			_format_number(float(current_result.get("final_haul", 0))),
			_format_number(float(current_result.get("final_mult", 1.0))),
		],
		"Resolving stored shot score",
		"final",
		false,
		true
	)
	_enter_state(STATE_FINAL_SETTLE, FINAL_SETTLE_DURATION)


func _begin_final_count() -> void:
	final_haul_from = current_displayed_haul
	final_mult_from = current_displayed_mult
	final_score_from = current_displayed_score
	var final_score: int = maxi(int(current_result.get("shot_score", 0)), 0)
	var duration: float = _get_final_count_duration(final_score, final_score_from)
	if _final_count_has_numeric_motion():
		_begin_tick_train("final", false)
	_enter_state(STATE_FINAL_COUNT, duration)


func _update_final_count(progress: float) -> void:
	var eased: float = _ease_out_cubic(progress)
	current_displayed_haul = lerpf(
		final_haul_from,
		float(current_result.get("final_haul", final_haul_from)),
		eased
	)
	current_displayed_mult = lerpf(
		final_mult_from,
		float(current_result.get("final_mult", final_mult_from)),
		eased
	)
	current_displayed_score = lerpf(final_score_from, float(current_result.get("shot_score", 0)), eased)
	tally_hud.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)
	if world_presenter != null:
		world_presenter.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)


func _apply_final_values() -> void:
	current_displayed_haul = float(current_result.get("final_haul", 0))
	current_displayed_mult = float(current_result.get("final_mult", 1.0))
	current_displayed_score = float(current_result.get("shot_score", 0))
	if tally_hud != null:
		tally_hud.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)
	if world_presenter != null:
		world_presenter.set_display_values(current_displayed_haul, current_displayed_mult, current_displayed_score)


func _finish_completed_tally() -> void:
	if not presenter_active:
		duplicate_completion_suppression_count += 1
		_emit_state()
		return
	last_presentation_duration = _get_elapsed_presentation_seconds()
	_commit_pending_round_score_if_needed()
	completed_tally_count += 1
	_archive_tick_tally_stats()
	presenter_active = false
	current_state = STATE_IDLE
	current_step.clear()
	current_step_index = -1
	replay_mode_active = false
	set_process(false)
	_set_fast_forward(false)
	_set_presentation_lock(false)
	_stop_audio()
	if scoring_cue_conductor != null:
		scoring_cue_conductor.complete_sequence(false)
	if tally_hud != null:
		tally_hud.finish_tally()
	if world_presenter != null:
		world_presenter.finish_presentation(current_result)
	var snapshot: Dictionary = get_diagnostics_snapshot()
	tally_completed.emit(snapshot)
	_emit_state()


func _get_step_visual_kind(step: Dictionary) -> String:
	var narrative_event: Dictionary = _dictionary_value(step, "narrative_event")
	if str(narrative_event.get("event_type", "")) == "retrigger_marker":
		return "legendary"
	if not bool(step.get("affects_score", true)) or str(step.get("phase", "")) == "consequence":
		return "consequence"
	if not is_equal_approx(float(step.get("xmult_factor", 1.0)), 1.0):
		return "xmult"
	if int(step.get("haul_delta", 0)) != 0:
		return "haul"
	if not is_zero_approx(float(step.get("mult_delta", 0.0))):
		return "mult"
	return "neutral"


func _get_step_detail(step: Dictionary, visual_kind: String) -> String:
	match visual_kind:
		"haul":
			return "%s HAUL" % _format_signed_number(float(step.get("haul_delta", 0)))
		"mult":
			return "%s MULT" % _format_signed_number(float(step.get("mult_delta", 0.0)))
		"xmult":
			return "x%s MULT" % _format_number(float(step.get("xmult_factor", 1.0)))
		"legendary":
			var narrative_event: Dictionary = _dictionary_value(step, "narrative_event")
			return str(narrative_event.get("effect_text", "ENGINE EFFECTS TRIGGER AGAIN"))
		"consequence":
			return "No score removed"
	return "Score unchanged"


func _get_step_context(step: Dictionary, visual_kind: String) -> String:
	if visual_kind == "legendary":
		return "Legendary retrigger marker - canonical score order retained"
	if visual_kind == "consequence":
		if table != null and table.is_roguelite_mode():
			return "Hull consequence applies - earned score retained"
		return "Shot Lab consequence frozen - earned score retained"
	var ball_id: int = int(step.get("ball_id", -1))
	var equation: String = "Haul %s -> %s | Mult %s -> %s | Preview %s" % [
		_format_number(float(step.get("haul_before", 0))),
		_format_number(float(step.get("haul_after", 0))),
		_format_number(float(step.get("mult_before", 1.0))),
		_format_number(float(step.get("mult_after", 1.0))),
		_format_number(float(step.get("score_preview_after", 0))),
	]
	return "%s | Ball #%d" % [equation, ball_id] if ball_id > 0 else equation


func _get_zero_score_reason(score_result: Dictionary) -> String:
	var warnings: Array = _array_value(score_result, "warnings")
	var diagnostics: Dictionary = _dictionary_value(score_result, "diagnostics")
	if not warnings.is_empty() and not bool(diagnostics.get("input_valid", true)):
		return "NO VALID SCORE"
	return "NO HAUL"


func _get_step_duration(visual_kind: String, step_count: int) -> float:
	var base_duration: float = ORDINARY_STEP_DURATION
	if visual_kind == "xmult":
		base_duration = XMULT_STEP_DURATION
	elif visual_kind == "legendary":
		base_duration = maxf(ORDINARY_STEP_DURATION, 0.42)
	elif visual_kind == "consequence":
		base_duration = (
			ZERO_CONSEQUENCE_STEP_DURATION
			if int(current_result.get("shot_score", 0)) == 0
			else CONSEQUENCE_STEP_DURATION
		)
	var count_progress: float = clampf((float(step_count) - 3.0) / 12.0, 0.0, 1.0)
	var pace_factor: float = lerpf(1.0, 0.44, _ease_out_cubic(count_progress))
	var sequence_progress: float = (
		float(maxi(current_step_index, 0)) / float(maxi(step_count - 1, 1))
		if step_count > 1
		else 0.0
	)
	pace_factor *= lerpf(1.0, 0.78, _ease_out_cubic(sequence_progress))
	var duration: float = base_duration * pace_factor
	if step_count > 0:
		duration = minf(duration, 3.4 / float(step_count))
	var narrative_event: Dictionary = _dictionary_value(current_step, "narrative_event")
	var event_type: String = str(narrative_event.get("event_type", ""))
	var protected_event: bool = (
		event_type in ["combination", "pocket", "additional_ball", "xmult", "retrigger_marker"]
		or (
			event_type in ["rail_milestone", "rail_group"]
			and int(narrative_event.get("tier_index", 0)) + 1
				>= int(narrative_event.get("tier_count", 1))
		)
	)
	if visual_kind == "xmult":
		duration = maxf(duration, 0.24)
	elif visual_kind == "legendary":
		duration = maxf(duration, 0.34)
	elif protected_event:
		duration = maxf(duration, 0.15)
	return maxf(duration, 0.06)


func _get_final_count_duration(final_score: int, from_score: float) -> float:
	var distance: float = absf(float(final_score) - from_score)
	if final_score <= 0 and distance <= 0.5:
		return 0.10
	return clampf(0.34 + log(maxf(distance, 1.0) + 1.0) / log(10.0) * 0.08, 0.35, 0.75)


func _set_fast_forward(value: bool) -> void:
	if fast_forward_active == value:
		return
	fast_forward_active = value
	if not value:
		fast_forward_hold_elapsed = 0.0
	_emit_state()


func _is_allowed_ui_interaction_under_mouse() -> bool:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var hovered: Control = viewport.gui_get_hovered_control()
	var current: Node = hovered
	while current != null:
		if current.has_meta("allow_during_score_tally"):
			return bool(current.get_meta("allow_during_score_tally"))
		current = current.get_parent()
	return false


func _set_presentation_lock(locked: bool) -> void:
	presentation_lock_active = locked
	if table != null and is_instance_valid(table) and table.has_method("set_presentation_input_locked"):
		table.call("set_presentation_input_locked", PRESENTATION_LOCK_ID, locked)


func _apply_world_presentation_configuration() -> void:
	if world_presenter == null or not is_instance_valid(world_presenter):
		return
	world_presenter.set_world_score_callouts_enabled(world_score_callouts)
	world_presenter.set_persistent_equation_enabled(persistent_equation)
	world_presenter.set_persistent_round_bar_enabled(persistent_round_bar)
	world_presenter.set_local_source_flashes_enabled(local_source_flashes)
	world_presenter.set_show_presentation_anchors(show_presentation_anchors)
	world_presenter.set_live_words_enabled(live_scoring_words)
	world_presenter.set_ghost_replay_enabled(ghost_ball_replay)
	world_presenter.set_ghost_trails_enabled(ghost_trails)
	world_presenter.set_per_ball_subtotals_enabled(per_ball_subtotals)


func _apply_live_scoring_configuration() -> void:
	if live_scoring_system == null or not is_instance_valid(live_scoring_system):
		return
	live_scoring_system.set_anticipation_enabled(live_scoring_anticipation)
	live_scoring_system.set_words_enabled(live_scoring_words)
	live_scoring_system.set_audio_enabled(live_scoring_audio)
	live_scoring_system.set_global_excitement_enabled(global_excitement_enabled)
	live_scoring_system.set_global_excitement_strength(global_excitement_strength)


func _prepare_narrative_sequence(score_result: Dictionary, replay_mode: bool) -> void:
	current_narrative.clear()
	current_narrative_valid = false
	current_narrative_input_diagnostics.clear()
	current_ball_narratives_by_id.clear()
	last_narrative_warning = ""
	var candidate: Dictionary = {}
	if replay_mode and _narrative_matches_result(last_narrative, score_result):
		candidate = last_narrative.duplicate(true)
	elif roguelite_scoring_system != null:
		var completed_ledger: Dictionary = roguelite_scoring_system.get_source_ledger_for_result(
			score_result
		)
		if not completed_ledger.is_empty():
			var ledger_with_derived: Dictionary = completed_ledger.duplicate(true)
			if not ledger_with_derived.has("derived"):
				ledger_with_derived["derived"] = ShotLedgerAnalyzer.analyze(ledger_with_derived)
			candidate = NARRATIVE_BUILDER.build_authoritative_narrative(
				ledger_with_derived,
				score_result
			)
			candidate = _attach_narrative_input_diagnostics(candidate, ledger_with_derived)
	if not candidate.is_empty():
		current_narrative_input_diagnostics = _dictionary_value(
			_dictionary_value(candidate, "diagnostics"),
			"input_contract"
		).duplicate(true)
		last_narrative_input_diagnostics = current_narrative_input_diagnostics.duplicate(true)
	var validation: Dictionary = _dictionary_value(candidate, "validation")
	if bool(validation.get("valid", false)):
		current_narrative = candidate.duplicate(true)
		last_narrative = candidate.duplicate(true)
		current_narrative_valid = true
		current_steps.clear()
		for event_value in _array_value(current_narrative, "presentation_sequence"):
			if event_value is Dictionary:
				current_steps.append(_narrative_event_to_step(event_value as Dictionary))
		for narrative_value in _array_value(current_narrative, "ball_narratives"):
			if narrative_value is Dictionary:
				var narrative: Dictionary = narrative_value
				current_ball_narratives_by_id[str(int(narrative.get("ball_id", -1)))] = narrative.duplicate(true)
		return
	current_steps = _array_value(score_result, "resolution_steps").duplicate(true)
	if not candidate.is_empty():
		narrative_fallback_count += 1
		var errors: Array = _array_value(validation, "errors")
		last_narrative_warning = (
			str(errors[0])
			if not errors.is_empty()
			else "Narrative validation failed; canonical tally retained."
		)
		push_warning("Long Sink narrative fallback: %s" % last_narrative_warning)


func _attach_narrative_input_diagnostics(
	narrative: Dictionary,
	ledger_with_derived: Dictionary
) -> Dictionary:
	var annotated_narrative: Dictionary = narrative.duplicate(true)
	var diagnostics: Dictionary = _dictionary_value(annotated_narrative, "diagnostics")
	var fallback: Dictionary = _dictionary_value(annotated_narrative, "fallback")
	var derived_value: Variant = ledger_with_derived.get("derived", null)
	var raw_events_value: Variant = ledger_with_derived.get("raw_events", null)
	var starting_balls_value: Variant = ledger_with_derived.get("starting_balls", null)
	var raw_event_count: int = 0
	if raw_events_value is Array:
		raw_event_count = (raw_events_value as Array).size()
	var starting_ball_count: int = 0
	if starting_balls_value is Dictionary:
		starting_ball_count = (starting_balls_value as Dictionary).size()
	diagnostics["input_contract"] = {
		"identity_present": _has_complete_ledger_identity(ledger_with_derived),
		"derived_present": derived_value is Dictionary,
		"raw_events_present": raw_events_value is Array,
		"raw_event_count": raw_event_count,
		"starting_balls_present": starting_balls_value is Dictionary,
		"starting_ball_count": starting_ball_count,
		"fallback_reason": str(fallback.get("reason", "")),
	}
	annotated_narrative["diagnostics"] = diagnostics
	return annotated_narrative


func _has_complete_ledger_identity(ledger_with_derived: Dictionary) -> bool:
	return (
		ledger_with_derived.has("run_generation")
		and ledger_with_derived.has("mode_id")
		and ledger_with_derived.has("shot_id")
		and ledger_with_derived.has("attempt_id")
		and not str(ledger_with_derived.get("mode_id", "")).is_empty()
		and int(ledger_with_derived.get("shot_id", -1)) >= 0
		and int(ledger_with_derived.get("attempt_id", -1)) >= 0
	)


func _narrative_event_to_step(event: Dictionary) -> Dictionary:
	return {
		"step_index": int(event.get("sequence_index", -1)),
		"phase": str(event.get("phase", "")),
		"source_id": str(event.get("source_id", "")),
		"source_type": str(event.get("source_type", "")),
		"display_name": str(event.get("replay_title", "Resolution Step")),
		"event_index": int(event.get("event_index", -1)),
		"ball_id": int(event.get("ball_id", -1)),
		"haul_delta": int(event.get("haul_delta", 0)),
		"mult_delta": float(event.get("mult_delta", 0.0)),
		"xmult_factor": float(event.get("xmult_factor", 1.0)),
		"haul_before": float(event.get("display_haul_before", 0.0)),
		"haul_after": float(event.get("display_haul_after", 0.0)),
		"mult_before": float(event.get("display_mult_before", 1.0)),
		"mult_after": float(event.get("display_mult_after", 1.0)),
		"score_preview_after": float(event.get("display_score_after", 0.0)),
		"affects_score": bool(event.get("affects_score", true)),
		"metadata": _dictionary_value(event, "metadata").duplicate(true),
		"canonical_step_indices": _array_value(event, "source_step_indices").duplicate(),
		"narrative_event": event.duplicate(true),
	}


func _sync_narrative_ball_for_step(step: Dictionary) -> void:
	if not current_narrative_valid or world_presenter == null:
		return
	var event: Dictionary = _dictionary_value(step, "narrative_event")
	var ball_id: int = int(event.get("ball_id", -1))
	var has_ball_story: bool = ball_id > 0 and current_ball_narratives_by_id.has(str(ball_id))
	if has_ball_story and ball_id == current_replay_ball_id:
		return
	_finish_current_ball_narrative()
	if has_ball_story:
		current_replay_ball_id = ball_id
		world_presenter.begin_ball_narrative(
			_dictionary_value(current_ball_narratives_by_id, str(ball_id))
		)


func _finish_current_ball_narrative() -> void:
	if current_replay_ball_id <= 0:
		return
	if world_presenter != null and current_ball_narratives_by_id.has(str(current_replay_ball_id)):
		world_presenter.finish_ball_narrative(
			_dictionary_value(current_ball_narratives_by_id, str(current_replay_ball_id))
		)
	current_replay_ball_id = -1


func _present_current_step_world(step: Dictionary, duration: float) -> void:
	if world_presenter == null:
		return
	var event: Dictionary = _dictionary_value(step, "narrative_event")
	if current_narrative_valid and not event.is_empty() and bool(event.get("world_position_valid", false)):
		var ball_narrative: Dictionary = _dictionary_value(
			current_ball_narratives_by_id,
			str(int(event.get("ball_id", -1)))
		)
		world_presenter.present_narrative_event(event, ball_narrative, duration)
		return
	var canonical_step: Dictionary = step.duplicate(true)
	var source_indices: Array = _array_value(step, "canonical_step_indices")
	if not source_indices.is_empty():
		canonical_step["step_index"] = int(source_indices[0])
	world_presenter.present_step(canonical_step, duration)


func _request_replay_semantic_cue(step: Dictionary) -> void:
	if scoring_cue_conductor == null or not current_narrative_valid:
		return
	var event: Dictionary = _dictionary_value(step, "narrative_event")
	if event.is_empty() or not bool(event.get("world_position_valid", false)):
		return
	var cue_kind: String = ""
	var excitement_weight := 0.0
	match str(event.get("event_type", "")):
		"combination":
			cue_kind = RogueliteScoringCueConductor.CUE_COMBINATION
			excitement_weight = 1.0
		"rail_milestone", "rail_group":
			var tier: int = clampi(int(event.get("tier_index", 0)) + 1, 1, 3)
			cue_kind = "bank_%d" % tier
			excitement_weight = [1.0, 2.0, 3.0][tier - 1]
		"pocket":
			cue_kind = RogueliteScoringCueConductor.CUE_POCKET
			excitement_weight = 2.0
		"additional_ball":
			cue_kind = RogueliteScoringCueConductor.CUE_MULTI_POT
			excitement_weight = 2.0
		_:
			return
	var world_value: Variant = event.get("world_position", Vector2.ZERO)
	if not world_value is Vector2:
		return
	scoring_cue_conductor.request_replay_cue(
		int(event.get("ball_id", -1)),
		cue_kind,
		world_value as Vector2,
		{
			"excitement_weight": excitement_weight,
			"planned_final_tier": int(event.get("tier_count", 1)),
			"cue_key": "replay:%d:%d" % [
				int(current_result.get("attempt_id", -1)),
				int(event.get("sequence_index", -1)),
			],
			"force_distinct": int(event.get("tier_index", 0)) >= 2,
		}
	)


func _commit_pending_round_score_if_needed() -> void:
	if replay_mode_active or roguelite_scoring_system == null:
		return
	if not roguelite_scoring_system.has_pending_authoritative_round_score():
		return
	var committed: Dictionary = roguelite_scoring_system.commit_pending_authoritative_round_score(
		current_result
	)
	if committed.is_empty():
		return
	current_result = committed.duplicate(true)
	last_score_result = committed.duplicate(true)
	if world_presenter != null:
		world_presenter.show_doubloon_payout(current_result)


func _narrative_matches_result(narrative: Dictionary, score_result: Dictionary) -> bool:
	return (
		not narrative.is_empty()
		and int(narrative.get("shot_id", -1)) == int(score_result.get("shot_id", -2))
		and int(narrative.get("attempt_id", -1)) == int(score_result.get("attempt_id", -2))
	)


func _clear_retained_result() -> void:
	last_score_result.clear()
	current_result.clear()
	current_steps.clear()
	current_step.clear()
	current_step_index = -1
	last_applied_step_index = -1
	current_resolution_key = ""
	last_auto_resolution_key = ""
	last_comparison.clear()
	current_comparison.clear()
	current_narrative.clear()
	last_narrative.clear()
	current_narrative_valid = false
	current_narrative_input_diagnostics.clear()
	last_narrative_input_diagnostics.clear()
	current_ball_narratives_by_id.clear()
	current_replay_ball_id = -1
	last_shot_id = -1
	last_attempt_id = -1
	replay_mode_active = false
	current_displayed_haul = 0.0
	current_displayed_mult = 1.0
	current_displayed_score = 0.0


func _ensure_tally_audio_buses() -> void:
	AudioSettings.ensure_audio_buses()
	var parent_bus_name: String = (
		AudioSettings.SFX_BUS_NAME
		if AudioServer.get_bus_index(AudioSettings.SFX_BUS_NAME) >= 0
		else AudioSettings.MASTER_BUS_NAME
	)
	tally_tick_bus_index = _ensure_runtime_audio_bus(TALLY_TICK_BUS_NAME, parent_bus_name)
	tally_tick_bass_bus_index = _ensure_runtime_audio_bus(
		TALLY_TICK_BASS_BUS_NAME,
		parent_bus_name
	)
	tally_audio_effects_available = not AudioSettings.is_web_build()
	if not tally_audio_effects_available:
		tally_reverb_effect_index = -1
		tally_reverb_effect = null
		return
	_configure_tally_tick_bus_effects()
	_configure_tally_tick_bass_bus_effects()


func _ensure_runtime_audio_bus(bus_name: String, send_bus_name: String) -> int:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		bus_index = AudioServer.get_bus_count()
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, send_bus_name)
	return bus_index


func _configure_tally_tick_bus_effects() -> void:
	if tally_tick_bus_index < 0:
		return
	tally_reverb_effect_index = _find_bus_effect_index(
		tally_tick_bus_index,
		"AudioEffectReverb"
	)
	if tally_reverb_effect_index < 0:
		tally_reverb_effect = AudioEffectReverb.new()
		AudioServer.add_bus_effect(tally_tick_bus_index, tally_reverb_effect)
		tally_reverb_effect_index = AudioServer.get_bus_effect_count(tally_tick_bus_index) - 1
	else:
		tally_reverb_effect = AudioServer.get_bus_effect(
			tally_tick_bus_index,
			tally_reverb_effect_index
		) as AudioEffectReverb
	if tally_reverb_effect != null:
		_set_audio_effect_property_if_present(
			tally_reverb_effect,
			"room_size",
			TICK_REVERB_ROOM_SIZE
		)
		_set_audio_effect_property_if_present(
			tally_reverb_effect,
			"damping",
			TICK_REVERB_DAMPING
		)
		_set_audio_effect_property_if_present(
			tally_reverb_effect,
			"spread",
			TICK_REVERB_SPREAD
		)
		_set_audio_effect_property_if_present(
			tally_reverb_effect,
			"hipass",
			TICK_REVERB_HIPASS
		)
		_set_audio_effect_property_if_present(
			tally_reverb_effect,
			"predelay_msec",
			TICK_REVERB_PREDELAY_MSEC
		)
		_set_audio_effect_property_if_present(tally_reverb_effect, "predelay_feedback", 0.0)
		_set_audio_effect_property_if_present(tally_reverb_effect, "dry", 1.0)
	_ensure_compressor_effect(tally_tick_bus_index, -15.0, 3.0, 1800.0, 75.0)
	_ensure_limiter_effect(tally_tick_bus_index, -1.0, -4.0)


func _configure_tally_tick_bass_bus_effects() -> void:
	if tally_tick_bass_bus_index < 0:
		return
	var highpass_index: int = _find_bus_effect_index(
		tally_tick_bass_bus_index,
		"AudioEffectHighPassFilter"
	)
	var highpass: AudioEffectHighPassFilter
	if highpass_index < 0:
		highpass = AudioEffectHighPassFilter.new()
		AudioServer.add_bus_effect(tally_tick_bass_bus_index, highpass)
		highpass_index = AudioServer.get_bus_effect_count(tally_tick_bass_bus_index) - 1
	else:
		highpass = AudioServer.get_bus_effect(
			tally_tick_bass_bus_index,
			highpass_index
		) as AudioEffectHighPassFilter
	if highpass != null:
		_set_audio_effect_property_if_present(highpass, "cutoff_hz", TICK_BASS_HIGHPASS_HZ)
		_set_audio_effect_property_if_present(highpass, "resonance", 0.2)
		_set_audio_effect_property_if_present(highpass, "db", 1)
		AudioServer.set_bus_effect_enabled(tally_tick_bass_bus_index, highpass_index, true)

	var lowpass_index: int = _find_bus_effect_index(
		tally_tick_bass_bus_index,
		"AudioEffectLowPassFilter"
	)
	var lowpass: AudioEffectLowPassFilter
	if lowpass_index < 0:
		lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(tally_tick_bass_bus_index, lowpass)
		lowpass_index = AudioServer.get_bus_effect_count(tally_tick_bass_bus_index) - 1
	else:
		lowpass = AudioServer.get_bus_effect(
			tally_tick_bass_bus_index,
			lowpass_index
		) as AudioEffectLowPassFilter
	if lowpass != null:
		_set_audio_effect_property_if_present(lowpass, "cutoff_hz", TICK_BASS_LOWPASS_HZ)
		_set_audio_effect_property_if_present(lowpass, "resonance", 0.18)
		_set_audio_effect_property_if_present(lowpass, "db", 1)
		AudioServer.set_bus_effect_enabled(tally_tick_bass_bus_index, lowpass_index, true)
	_ensure_compressor_effect(tally_tick_bass_bus_index, -18.0, 3.5, 1500.0, 80.0)
	_ensure_limiter_effect(tally_tick_bass_bus_index, -2.0, -5.0)


func _ensure_compressor_effect(
	bus_index: int,
	threshold_db: float,
	ratio: float,
	attack_us: float,
	release_ms: float
) -> void:
	var effect_index: int = _find_bus_effect_index(bus_index, "AudioEffectCompressor")
	var compressor: AudioEffectCompressor
	if effect_index < 0:
		compressor = AudioEffectCompressor.new()
		AudioServer.add_bus_effect(bus_index, compressor)
		effect_index = AudioServer.get_bus_effect_count(bus_index) - 1
	else:
		compressor = AudioServer.get_bus_effect(bus_index, effect_index) as AudioEffectCompressor
	if compressor == null:
		return
	_set_audio_effect_property_if_present(compressor, "threshold", threshold_db)
	_set_audio_effect_property_if_present(compressor, "ratio", ratio)
	_set_audio_effect_property_if_present(compressor, "gain", 0.0)
	_set_audio_effect_property_if_present(compressor, "attack_us", attack_us)
	_set_audio_effect_property_if_present(compressor, "release_ms", release_ms)
	_set_audio_effect_property_if_present(compressor, "mix", 1.0)
	AudioServer.set_bus_effect_enabled(bus_index, effect_index, true)


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


func _apply_tally_audio_tuning() -> void:
	_apply_tally_reverb_tuning()
	if not tally_tick_bass_enabled:
		_stop_bass_tick_voices()


func _apply_tally_reverb_tuning() -> void:
	if tally_reverb_effect != null:
		_set_audio_effect_property_if_present(tally_reverb_effect, "wet", tally_tick_reverb_wet)
	if tally_tick_bus_index >= 0 and tally_reverb_effect_index >= 0:
		AudioServer.set_bus_effect_enabled(
			tally_tick_bus_index,
			tally_reverb_effect_index,
			tally_tick_reverb_enabled
		)


func _reset_tally_audio_tuning_values() -> void:
	tally_tick_volume_db = DEFAULT_TICK_VOLUME_DB
	tally_tick_bass_enabled = DEFAULT_TICK_BASS_ENABLED
	tally_tick_bass_volume_db = DEFAULT_TICK_BASS_VOLUME_DB
	tally_tick_reverb_enabled = DEFAULT_TICK_REVERB_ENABLED
	tally_tick_reverb_wet = DEFAULT_TICK_REVERB_WET


func _build_audio_players() -> void:
	if step_audio_player != null:
		return
	_ensure_tally_audio_buses()
	step_audio_player = AudioStreamPlayer.new()
	step_audio_player.name = "TallyStepAudio"
	add_child(step_audio_player)
	final_audio_player = AudioStreamPlayer.new()
	final_audio_player.name = "TallyFinalAudio"
	add_child(final_audio_player)
	zero_sting_first_player = AudioStreamPlayer.new()
	zero_sting_first_player.name = "ZeroScoreStingFirst"
	zero_sting_first_player.stream = STEP_ACCENT_STREAM
	add_child(zero_sting_first_player)
	zero_sting_second_player = AudioStreamPlayer.new()
	zero_sting_second_player.name = "ZeroScoreStingSecond"
	zero_sting_second_player.stream = STEP_ACCENT_STREAM
	add_child(zero_sting_second_player)
	var accent_bus_name: String = (
		AudioSettings.SFX_BUS_NAME
		if AudioServer.get_bus_index(AudioSettings.SFX_BUS_NAME) >= 0
		else AudioSettings.MASTER_BUS_NAME
	)
	step_audio_player.bus = accent_bus_name
	final_audio_player.bus = accent_bus_name
	zero_sting_first_player.bus = accent_bus_name
	zero_sting_second_player.bus = accent_bus_name
	for voice_index in range(TALLY_TICK_VOICE_COUNT):
		var tick_player := AudioStreamPlayer.new()
		tick_player.name = "TallyTickAudio%d" % (voice_index + 1)
		tick_player.stream = STEP_ACCENT_STREAM
		tick_player.bus = TALLY_TICK_BUS_NAME
		add_child(tick_player)
		tally_tick_players.append(tick_player)
	for voice_index in range(TALLY_TICK_BASS_VOICE_COUNT):
		var bass_tick_player := AudioStreamPlayer.new()
		bass_tick_player.name = "TallyTickBassAudio%d" % (voice_index + 1)
		bass_tick_player.stream = STEP_ACCENT_STREAM
		bass_tick_player.bus = TALLY_TICK_BASS_BUS_NAME
		add_child(bass_tick_player)
		tally_tick_bass_players.append(bass_tick_player)
	_apply_tally_audio_tuning()


func _play_accent(visual_kind: String) -> void:
	if not play_tally_audio or step_audio_player == null or final_audio_player == null:
		return
	if visual_kind == "final":
		step_audio_player.stop()
		final_audio_player.stop()
		final_audio_player.stream = FINAL_ACCENT_STREAM
		final_audio_player.volume_db = -17.0
		final_audio_player.pitch_scale = 1.0
		final_audio_player.play()
		return
	step_audio_player.stop()
	step_audio_player.stream = STEP_ACCENT_STREAM
	match visual_kind:
		"haul":
			step_audio_player.volume_db = -21.0
			step_audio_player.pitch_scale = 1.10
		"mult":
			step_audio_player.volume_db = -20.0
			step_audio_player.pitch_scale = minf(1.16 + float(current_step_index) * 0.015, 1.34)
		"xmult":
			step_audio_player.stream = FINAL_ACCENT_STREAM
			step_audio_player.volume_db = -19.0
			step_audio_player.pitch_scale = 0.92
		"consequence":
			step_audio_player.volume_db = -24.0
			step_audio_player.pitch_scale = 0.72
		_:
			step_audio_player.volume_db = -24.0
			step_audio_player.pitch_scale = 1.0
	step_audio_player.play()


func _stop_audio() -> void:
	_stop_tick_train(true)
	zero_second_note_pending = false
	zero_second_note_elapsed = 0.0
	if step_audio_player != null:
		step_audio_player.stop()
	if final_audio_player != null:
		final_audio_player.stop()
	if zero_sting_first_player != null:
		zero_sting_first_player.stop()
	if zero_sting_second_player != null:
		zero_sting_second_player.stop()


func _play_zero_score_sting() -> void:
	_stop_tick_train(true)
	if not play_tally_audio or zero_sting_first_player == null or zero_sting_second_player == null:
		zero_second_note_pending = false
		return
	if step_audio_player != null:
		step_audio_player.stop()
	if final_audio_player != null:
		final_audio_player.stop()
	zero_sting_first_player.stop()
	zero_sting_second_player.stop()
	zero_sting_first_player.pitch_scale = 1.0
	zero_sting_first_player.volume_db = -20.0
	zero_sting_second_player.pitch_scale = 0.68
	zero_sting_second_player.volume_db = -23.0
	zero_sting_first_player.play()
	zero_second_note_elapsed = 0.0
	zero_second_note_pending = true
	zero_score_sting_count += 1


func _update_zero_sting(delta: float) -> void:
	if not zero_second_note_pending:
		return
	if current_state != STATE_ZERO_FEEDBACK or not presenter_active:
		zero_second_note_pending = false
		zero_stale_note_suppression_count += 1
		return
	zero_second_note_elapsed += maxf(delta, 0.0)
	if zero_second_note_elapsed < ZERO_STING_SECOND_NOTE_DELAY:
		return
	zero_second_note_pending = false
	if play_tally_audio and zero_sting_second_player != null:
		zero_sting_second_player.play()


func _reset_tick_tally_state() -> void:
	_stop_tick_train(true)
	next_tick_voice_index = 0
	next_bass_tick_voice_index = 0
	current_step_tick_count = 0
	current_tally_tick_count = 0
	skipped_ticks_due_voice_cap = 0
	skipped_bass_ticks_due_voice_cap = 0
	tick_voice_reuse_count = 0
	bass_tick_voice_reuse_count = 0
	scoring_tick_step_ordinal = 0


func _archive_tick_tally_stats() -> void:
	last_tally_tick_count = current_tally_tick_count
	last_tally_skipped_ticks_due_voice_cap = skipped_ticks_due_voice_cap
	last_tally_skipped_bass_ticks_due_voice_cap = skipped_bass_ticks_due_voice_cap


func _current_step_has_numeric_motion() -> bool:
	return (
		not is_equal_approx(step_haul_from, step_haul_to)
		or not is_equal_approx(step_mult_from, step_mult_to)
		or not is_equal_approx(step_score_from, step_score_to)
	)


func _final_count_has_numeric_motion() -> bool:
	return (
		not is_equal_approx(final_haul_from, float(current_result.get("final_haul", final_haul_from)))
		or not is_equal_approx(final_mult_from, float(current_result.get("final_mult", final_mult_from)))
		or not is_equal_approx(final_score_from, float(current_result.get("shot_score", final_score_from)))
	)


func _begin_tick_train(visual_kind: String, wait_for_motion: bool) -> void:
	_stop_tick_train(false)
	if not play_tally_audio or tally_tick_players.is_empty():
		return
	current_step_tick_count = 0
	tick_train_active = true
	tick_train_waiting_for_motion = wait_for_motion
	tick_train_visual_kind = visual_kind
	tick_elapsed = 0.0
	current_tick_interval = TICK_INTERVAL_START
	current_tick_start_pitch = minf(
		TICK_START_PITCH + float(scoring_tick_step_ordinal) * TICK_STEP_START_PITCH_INCREMENT,
		TICK_MAX_START_PITCH
	)
	scoring_tick_step_ordinal += 1
	var pitch_span: float = TICK_ORDINARY_PITCH_SPAN
	if visual_kind == "xmult":
		pitch_span = TICK_XMULT_PITCH_SPAN
	elif visual_kind == "final":
		pitch_span = TICK_FINAL_PITCH_SPAN
	current_tick_end_pitch = minf(current_tick_start_pitch + pitch_span, TICK_MAX_PITCH)
	current_tick_pitch = current_tick_start_pitch
	current_bass_tick_pitch = current_tick_pitch * TICK_BASS_PITCH_RATIO
	if not wait_for_motion:
		_emit_tally_tick(0.0)


func _update_tick_train(delta: float) -> void:
	if not tick_train_active:
		return
	if not play_tally_audio or tally_tick_players.is_empty():
		_stop_tick_train(true)
		return
	var motion_progress: float = _get_tick_motion_progress()
	if motion_progress < 0.0:
		_stop_tick_train(true)
		return
	if tick_train_waiting_for_motion:
		if motion_progress <= 0.0:
			return
		tick_train_waiting_for_motion = false
		tick_elapsed = 0.0
		_emit_tally_tick(motion_progress)
	current_tick_interval = lerpf(TICK_INTERVAL_START, TICK_INTERVAL_END, motion_progress)
	if fast_forward_active:
		current_tick_interval = maxf(
			current_tick_interval / TICK_FAST_FORWARD_CADENCE_SCALE,
			TICK_FAST_FORWARD_MIN_INTERVAL
		)
	tick_elapsed += maxf(delta, 0.0)
	var emitted_this_frame := 0
	while tick_elapsed >= current_tick_interval and emitted_this_frame < MAX_TICKS_PER_FRAME:
		tick_elapsed -= current_tick_interval
		_emit_tally_tick(motion_progress)
		emitted_this_frame += 1
	if emitted_this_frame >= MAX_TICKS_PER_FRAME:
		tick_elapsed = minf(tick_elapsed, current_tick_interval)


func _get_tick_motion_progress() -> float:
	var raw_progress: float = 0.0
	if tick_train_visual_kind == "final":
		if current_state != STATE_FINAL_COUNT:
			return -1.0
		raw_progress = 1.0 if state_duration <= 0.0 else clampf(state_elapsed / state_duration, 0.0, 1.0)
	elif current_state == STATE_STEP:
		raw_progress = 1.0 if state_duration <= 0.0 else clampf(state_elapsed / state_duration, 0.0, 1.0)
		if tick_train_visual_kind == "xmult":
			raw_progress = clampf((raw_progress - 0.24) / 0.76, 0.0, 1.0)
	else:
		return -1.0
	return _ease_out_cubic(raw_progress)


func _finish_active_tick_train() -> void:
	if not tick_train_active:
		return
	if current_step_tick_count > 0:
		_emit_tally_tick(1.0, true, true)
	_stop_tick_train(false)


func _emit_tally_tick(
	progress: float,
	force_bass: bool = false,
	landing_tick: bool = false
) -> void:
	var tick_player: AudioStreamPlayer = _get_available_tick_player()
	if tick_player == null:
		skipped_ticks_due_voice_cap += 1
		return
	current_tick_pitch = lerpf(
		current_tick_start_pitch,
		current_tick_end_pitch,
		clampf(progress, 0.0, 1.0)
	)
	current_bass_tick_pitch = current_tick_pitch * TICK_BASS_PITCH_RATIO
	var tick_number: int = current_step_tick_count + 1
	tick_player.stream = STEP_ACCENT_STREAM
	tick_player.pitch_scale = current_tick_pitch
	tick_player.volume_db = tally_tick_volume_db
	if tick_number == 1:
		tick_player.volume_db = _get_first_tick_volume_db()
	elif landing_tick:
		tick_player.volume_db = minf(
			tally_tick_volume_db + TICK_LANDING_VOLUME_BOOST_DB,
			MAX_TICK_VOLUME_DB
		)
	tick_player.play()
	if _should_play_bass_tick(tick_number, force_bass):
		_emit_bass_tick(tick_number, landing_tick, force_bass)
	current_step_tick_count += 1
	current_tally_tick_count += 1


func _get_first_tick_volume_db() -> float:
	return minf(
		tally_tick_volume_db + TICK_FIRST_VOLUME_BOOST_DB,
		MAX_TICK_VOLUME_DB
	)


func _should_play_bass_tick(tick_number: int, force_bass: bool) -> bool:
	if not tally_tick_bass_enabled or not play_tally_audio:
		return false
	if force_bass or tick_number == 1:
		return true
	if fast_forward_active:
		return tick_number % 3 == 0
	if tick_train_visual_kind in ["xmult", "final"]:
		return tick_number % 3 != 0
	return tick_number % 2 == 0


func _emit_bass_tick(tick_number: int, landing_tick: bool, force_voice: bool) -> void:
	var bass_player: AudioStreamPlayer = _get_available_bass_tick_player(force_voice)
	if bass_player == null:
		skipped_bass_ticks_due_voice_cap += 1
		return
	bass_player.stream = STEP_ACCENT_STREAM
	bass_player.pitch_scale = current_bass_tick_pitch
	bass_player.volume_db = tally_tick_bass_volume_db
	if tick_number == 1:
		bass_player.volume_db = minf(
			tally_tick_bass_volume_db + TICK_BASS_FIRST_VOLUME_BOOST_DB,
			MAX_TICK_BASS_VOLUME_DB
		)
	elif landing_tick:
		bass_player.volume_db = minf(
			tally_tick_bass_volume_db + TICK_BASS_LANDING_VOLUME_BOOST_DB,
			MAX_TICK_BASS_VOLUME_DB
		)
	bass_player.play()


func _get_available_tick_player() -> AudioStreamPlayer:
	var voice_count: int = tally_tick_players.size()
	if voice_count <= 0:
		return null
	for offset in range(voice_count):
		var candidate_index: int = (next_tick_voice_index + offset) % voice_count
		var candidate: AudioStreamPlayer = tally_tick_players[candidate_index]
		if not candidate.playing:
			next_tick_voice_index = (candidate_index + 1) % voice_count
			return candidate
	var reused: AudioStreamPlayer = tally_tick_players[next_tick_voice_index]
	next_tick_voice_index = (next_tick_voice_index + 1) % voice_count
	reused.stop()
	tick_voice_reuse_count += 1
	return reused


func _get_available_bass_tick_player(force_voice: bool) -> AudioStreamPlayer:
	var voice_count: int = tally_tick_bass_players.size()
	if voice_count <= 0:
		return null
	for offset in range(voice_count):
		var candidate_index: int = (next_bass_tick_voice_index + offset) % voice_count
		var candidate: AudioStreamPlayer = tally_tick_bass_players[candidate_index]
		if not candidate.playing:
			next_bass_tick_voice_index = (candidate_index + 1) % voice_count
			return candidate
	if not force_voice:
		return null
	var reused: AudioStreamPlayer = tally_tick_bass_players[next_bass_tick_voice_index]
	next_bass_tick_voice_index = (next_bass_tick_voice_index + 1) % voice_count
	reused.stop()
	bass_tick_voice_reuse_count += 1
	return reused


func _get_active_tick_voice_count() -> int:
	var active_count := 0
	for tick_player in tally_tick_players:
		if tick_player.playing:
			active_count += 1
	return active_count


func _get_active_bass_tick_voice_count() -> int:
	var active_count := 0
	for tick_player in tally_tick_bass_players:
		if tick_player.playing:
			active_count += 1
	return active_count


func _stop_bass_tick_voices() -> void:
	for tick_player in tally_tick_bass_players:
		tick_player.stop()


func _stop_tick_train(stop_voices: bool) -> void:
	tick_train_active = false
	tick_train_waiting_for_motion = false
	tick_train_visual_kind = ""
	tick_elapsed = 0.0
	if not stop_voices:
		return
	for tick_player in tally_tick_players:
		tick_player.stop()
	_stop_bass_tick_voices()


func _is_shot_lab_suite_running() -> bool:
	if table == null or table.shot_lab_system == null:
		return false
	var snapshot: Dictionary = table.shot_lab_system.get_snapshot()
	var suite: Dictionary = _dictionary_value(snapshot, "suite")
	return bool(suite.get("running", false))


func _make_resolution_key(score_result: Dictionary) -> String:
	return "%s|%s|%d|%d" % [
		str(score_result.get("run_generation", "")),
		str(score_result.get("mode_id", "")),
		int(score_result.get("shot_id", -1)),
		int(score_result.get("attempt_id", -1)),
	]


func _get_elapsed_presentation_seconds() -> float:
	if presentation_started_usec <= 0:
		return 0.0
	return maxf(float(Time.get_ticks_usec() - presentation_started_usec) / 1000000.0, 0.0)


func _emit_state() -> void:
	var snapshot: Dictionary = get_diagnostics_snapshot()
	state_changed.emit(snapshot)
	if tally_hud != null and tally_hud.is_diagnostics_open():
		tally_hud.set_diagnostics_snapshot(snapshot)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	var formatted: String = "%.2f" % value
	while formatted.ends_with("0"):
		formatted = formatted.left(formatted.length() - 1)
	if formatted.ends_with("."):
		formatted = formatted.left(formatted.length() - 1)
	return formatted


func _format_signed_number(value: float) -> String:
	var prefix: String = "+" if value >= 0.0 else ""
	return prefix + _format_number(value)


func _ease_out_cubic(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []
