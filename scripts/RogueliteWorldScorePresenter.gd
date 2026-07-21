extends Control
class_name RogueliteWorldScorePresenter

signal final_result_dismiss_requested(method: String)

const MAPPER := preload("res://scripts/RogueliteScorePresentationMapper.gd")
const EVENT_CALLOUT_BASE := preload("res://scripts/RogueliteScoringEventCalloutBase.gd")
const CALLOUT_SCRIPT := preload("res://scripts/RogueliteWorldScoreCallout.gd")
const LIVE_CALLOUT_SCRIPT := preload("res://scripts/RogueliteLiveScoringCallout.gd")
const GHOST_BALL_SCRIPT := preload("res://scripts/RogueliteScoringGhostBall.gd")
const GHOST_TRAIL_SCRIPT := preload("res://scripts/RogueliteScoringGhostTrail.gd")
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const MAX_ACTIVE_CALLOUTS := 32
const MAX_ACTIVE_GHOSTS := 24
const MAX_ACTIVE_TRAILS := 8
const VIEWPORT_SAFE_MARGIN := 28.0
const SAME_ANCHOR_OFFSET := Vector2(18.0, -15.0)

var table: BilliardsTable
var progress_hud: RogueliteProgressHUD

var world_score_callouts_enabled := true
var persistent_equation_enabled := true
var persistent_round_bar_enabled := true
var local_source_flashes_enabled := true
var show_presentation_anchors := false
var live_words_enabled := true
var ghost_replay_enabled := true
var ghost_trails_enabled := true
var per_ball_subtotals_enabled := true

var current_result: Dictionary = {}
var current_mapping: Dictionary = {}
var mapped_steps_by_index: Dictionary = {}
var active_callouts: Array[RogueliteWorldScoreCallout] = []
var active_live_callouts: Array[RogueliteLiveScoringCallout] = []
var active_ghosts: Array[RogueliteScoringGhostBall] = []
var active_trails: Array[RogueliteScoringGhostTrail] = []
var current_ball_ghosts: Array[RogueliteScoringGhostBall] = []
var current_ball_trail: RogueliteScoringGhostTrail
var current_ball_id := -1
var current_ball_last_screen_position := Vector2.ZERO
var anchor_use_counts: Dictionary = {}
var last_mapping_diagnostics: Dictionary = {}
var offscreen_clamp_count := 0
var mapping_self_test_result: Dictionary = {}
var replay_excitement := 0.0
var last_replay_callout_metadata: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func setup(table_ref: BilliardsTable, hud_ref: RogueliteProgressHUD) -> void:
	table = table_ref
	progress_hud = hud_ref
	mapping_self_test_result = MAPPER.run_self_tests()
	if progress_hud != null and not progress_hud.final_result_dismiss_requested.is_connected(_on_final_result_dismiss_requested):
		progress_hud.final_result_dismiss_requested.connect(_on_final_result_dismiss_requested)
	_apply_hud_configuration()


func set_mode(mode_id: String, enabled: bool) -> void:
	visible = enabled
	if progress_hud != null:
		progress_hud.set_mode(mode_id, enabled)
	if not enabled:
		cancel_presentation("mode_hidden")


func sync_run_snapshot(snapshot: Dictionary, snap_display: bool = false) -> void:
	if progress_hud != null:
		progress_hud.sync_run_snapshot(snapshot, snap_display)


func set_shot_in_motion(active: bool) -> void:
	if progress_hud != null:
		progress_hud.set_shot_in_motion(active)
	if active:
		clear_live_callouts()


func show_live_cue(cue: Dictionary) -> void:
	if not live_words_enabled or not visible:
		return
	var world_value: Variant = cue.get("world_position", Vector2.ZERO)
	if not world_value is Vector2:
		return
	var true_screen_position: Vector2 = _world_to_screen(world_value as Vector2)
	var callout_center: Vector2 = _clamp_center_for_size(
		true_screen_position,
		EVENT_CALLOUT_BASE.CALLOUT_SIZE
	)
	if str(cue.get("event_type", "")) in ["pocket", "additional_ball"]:
		callout_center.y -= 30.0
		callout_center = _clamp_center_for_size(
			callout_center,
			EVENT_CALLOUT_BASE.CALLOUT_SIZE
		)
	_enforce_callout_cap()
	var callout: RogueliteLiveScoringCallout = (
		LIVE_CALLOUT_SCRIPT.new() as RogueliteLiveScoringCallout
	)
	callout.name = "LiveScoringCue%d" % active_live_callouts.size()
	add_child(callout)
	callout.setup(cue, callout_center, true_screen_position)
	callout.finished.connect(_on_live_callout_finished)
	active_live_callouts.append(callout)
	callout.play(0.72)


func begin_authoritative_narrative(_narrative: Dictionary) -> void:
	clear_live_callouts()
	clear_replay_echoes()
	current_ball_id = -1
	current_ball_last_screen_position = Vector2.ZERO
	replay_excitement = 0.0
	set_shot_in_motion(false)


func set_replay_excitement(value: float) -> void:
	replay_excitement = clampf(value, 0.0, 1.0)


func begin_ball_narrative(ball_narrative: Dictionary) -> void:
	_fade_current_ball_echoes()
	current_ball_id = int(ball_narrative.get("ball_id", -1))
	current_ball_last_screen_position = Vector2.ZERO
	current_ball_ghosts.clear()
	current_ball_trail = null


func present_narrative_event(
	event: Dictionary,
	ball_narrative: Dictionary,
	duration: float
) -> void:
	var world_value: Variant = event.get("world_position", Vector2.ZERO)
	var has_world_position: bool = (
		bool(event.get("world_position_valid", false))
		and world_value is Vector2
	)
	if not has_world_position:
		return
	var screen_position: Vector2 = _world_to_screen(world_value as Vector2)
	var ghost_screen_position: Vector2 = screen_position
	var scoring_position_value: Variant = event.get(
		"scoring_ball_world_position",
		world_value
	)
	if scoring_position_value is Vector2:
		ghost_screen_position = _world_to_screen(scoring_position_value as Vector2)
	current_ball_last_screen_position = ghost_screen_position
	if ghost_replay_enabled and not ball_narrative.is_empty():
		_spawn_ghost(ball_narrative, ghost_screen_position, event)
		if str(event.get("event_type", "")) in [
			"cue_recontact_milestone",
			"object_ball_tap_milestone",
		]:
			_spawn_contact_ghost(event)
	if ghost_trails_enabled and not ball_narrative.is_empty():
		_append_ghost_trail(ball_narrative, ghost_screen_position)
	if world_score_callouts_enabled:
		var callout_step: Dictionary = _make_narrative_callout_step(event, ball_narrative)
		last_replay_callout_metadata = callout_step.duplicate(true)
		var true_source: Vector2 = screen_position
		var contact_position_value: Variant = event.get(
			"contact_world_position",
			event.get("world_position", Vector2.ZERO)
		)
		if contact_position_value is Vector2:
			true_source = _world_to_screen(contact_position_value as Vector2)
		_spawn_score_callout(callout_step, screen_position, duration, true_source)
	_request_tap_replay_cue(event)


func finish_ball_narrative(ball_narrative: Dictionary, duration: float = 0.42) -> void:
	if (
		per_ball_subtotals_enabled
		and world_score_callouts_enabled
		and current_ball_last_screen_position != Vector2.ZERO
	):
		var ball_number: int = int(ball_narrative.get("ball_number", -1))
		var subtotal: Dictionary = {
			"step_index": -1000 - current_ball_id,
			"sequence_index": -1000 - current_ball_id,
			"title": "BALL %s" % (str(ball_number) if ball_number >= 0 else str(current_ball_id)),
			"effect_text": "+%s HAUL  +%s MULT" % [
				int(ball_narrative.get("haul_contribution", 0)),
				_format_number(float(ball_narrative.get("mult_contribution", 0.0))),
			],
			"affects_score": true,
			"event_type": "subtotal",
			"source_id": "per_ball_subtotal",
			"ball_id": current_ball_id,
			"tier_index": 0,
			"tier_count": 1,
			"final_classification": str(ball_narrative.get("final_classification", "")),
			"global_excitement_normalized": replay_excitement,
			"replay_excitement": replay_excitement,
			"is_final_tier": false,
			"is_pocket": false,
			"is_combination": bool(ball_narrative.get("is_combination", false)),
			"is_subtotal": true,
		}
		_spawn_score_callout(
			subtotal,
			_clamp_center_for_size(
				current_ball_last_screen_position + Vector2(0.0, -54.0),
				EVENT_CALLOUT_BASE.CALLOUT_SIZE
			),
			maxf(duration, 0.30)
		)


func begin_presentation(score_result: Dictionary) -> void:
	clear_world_callouts()
	offscreen_clamp_count = 0
	current_result = score_result.duplicate(true)
	mapped_steps_by_index.clear()
	anchor_use_counts.clear()
	var ledger: Dictionary = {}
	if table != null and table.roguelite_scoring_system != null:
		ledger = table.roguelite_scoring_system.get_source_ledger_for_result(score_result)
	current_mapping = MAPPER.map_score_result(score_result, ledger)
	last_mapping_diagnostics = _dictionary_value(current_mapping, "diagnostics").duplicate(true)
	for mapped_value in _array_value(current_mapping, "steps"):
		if not mapped_value is Dictionary:
			continue
		var mapped: Dictionary = mapped_value
		mapped_steps_by_index[str(int(mapped.get("step_index", -1)))] = mapped.duplicate(true)
	if progress_hud != null:
		progress_hud.begin_result(score_result)
	queue_redraw()


func present_step(step: Dictionary, duration: float) -> void:
	if not world_score_callouts_enabled:
		return
	var mapped_value: Variant = mapped_steps_by_index.get(str(int(step.get("step_index", -1))), {})
	if not mapped_value is Dictionary:
		return
	var mapped: Dictionary = mapped_value
	var true_screen_position: Vector2 = _mapped_screen_position(mapped)
	var callout_center: Vector2 = _clamp_callout_center(true_screen_position)
	var anchor_key: String = "%d:%d" % [int(roundf(true_screen_position.x / 24.0)), int(roundf(true_screen_position.y / 24.0))]
	var use_count: int = int(anchor_use_counts.get(anchor_key, 0))
	anchor_use_counts[anchor_key] = use_count + 1
	if use_count > 0:
		var offset_count: int = mini(use_count, 3)
		callout_center += SAME_ANCHOR_OFFSET * float(offset_count)
		callout_center = _clamp_callout_center(callout_center)

	_spawn_score_callout(mapped, callout_center, duration, true_screen_position)
	queue_redraw()


func set_display_values(haul: float, mult: float, score: float) -> void:
	if progress_hud != null:
		progress_hud.set_display_values(haul, mult, score)


func set_round_fill_progress(score_result: Dictionary, progress: float) -> void:
	if progress_hud != null and persistent_round_bar_enabled:
		progress_hud.set_round_fill_progress(score_result, progress)


func finish_round_fill(score_result: Dictionary) -> void:
	if progress_hud != null:
		progress_hud.finish_round_fill(score_result)


func show_doubloon_payout(score_result: Dictionary) -> void:
	if progress_hud != null:
		progress_hud.show_doubloon_payout(score_result)


func show_final_result(score_result: Dictionary) -> void:
	if progress_hud != null:
		progress_hud.show_final_result(score_result)


func hide_final_result(method: String = "cleanup") -> void:
	if progress_hud != null:
		progress_hud.hide_final_result(method)


func show_zero_indicator(reason: String = "NO HAUL") -> void:
	if progress_hud != null:
		progress_hud.show_zero_indicator(reason)


func set_zero_indicator_progress(progress: float) -> void:
	if progress_hud != null:
		progress_hud.set_zero_indicator_progress(progress)


func finish_presentation(score_result: Dictionary) -> void:
	if progress_hud != null:
		progress_hud.hide_zero_indicator()
		progress_hud.hide_final_result("presentation_complete")
		progress_hud.finish_result_observation(score_result)
	clear_world_callouts()
	clear_replay_echoes()
	current_result.clear()
	current_mapping.clear()
	mapped_steps_by_index.clear()
	replay_excitement = 0.0
	queue_redraw()


func cancel_presentation(reason: String = "cancel") -> void:
	clear_world_callouts()
	clear_live_callouts()
	clear_replay_echoes()
	current_result.clear()
	current_mapping.clear()
	mapped_steps_by_index.clear()
	anchor_use_counts.clear()
	replay_excitement = 0.0
	if progress_hud != null:
		progress_hud.clear_presentation(reason)
	queue_redraw()


func clear_world_callouts() -> void:
	for callout in active_callouts:
		if callout != null and is_instance_valid(callout):
			callout.queue_free()
	active_callouts.clear()


func clear_live_callouts() -> void:
	for callout in active_live_callouts:
		if callout != null and is_instance_valid(callout):
			callout.queue_free()
	active_live_callouts.clear()


func clear_replay_echoes() -> void:
	for ghost in active_ghosts:
		if ghost != null and is_instance_valid(ghost):
			ghost.queue_free()
	for trail in active_trails:
		if trail != null and is_instance_valid(trail):
			trail.queue_free()
	active_ghosts.clear()
	active_trails.clear()
	current_ball_ghosts.clear()
	current_ball_trail = null
	current_ball_id = -1
	current_ball_last_screen_position = Vector2.ZERO


func capture_observation() -> Dictionary:
	return progress_hud.capture_observation() if progress_hud != null else {}


func restore_observation(state: Dictionary) -> void:
	cancel_presentation("rewind_restore")
	if progress_hud != null:
		progress_hud.restore_observation(state)


func set_world_score_callouts_enabled(value: bool) -> void:
	world_score_callouts_enabled = value
	if not value:
		clear_world_callouts()


func set_persistent_equation_enabled(value: bool) -> void:
	persistent_equation_enabled = value
	_apply_hud_configuration()


func set_persistent_round_bar_enabled(value: bool) -> void:
	persistent_round_bar_enabled = value
	_apply_hud_configuration()


func set_local_source_flashes_enabled(value: bool) -> void:
	local_source_flashes_enabled = value


func set_show_presentation_anchors(value: bool) -> void:
	show_presentation_anchors = value
	queue_redraw()


func set_live_words_enabled(value: bool) -> void:
	live_words_enabled = value
	if not value:
		clear_live_callouts()


func set_ghost_replay_enabled(value: bool) -> void:
	ghost_replay_enabled = value
	if not value:
		clear_replay_echoes()


func set_ghost_trails_enabled(value: bool) -> void:
	ghost_trails_enabled = value
	if not value:
		for trail in active_trails:
			if trail != null and is_instance_valid(trail):
				trail.queue_free()
		active_trails.clear()
		current_ball_trail = null


func set_per_ball_subtotals_enabled(value: bool) -> void:
	per_ball_subtotals_enabled = value


func get_diagnostics_snapshot() -> Dictionary:
	var hud_snapshot: Dictionary = progress_hud.get_diagnostics_snapshot() if progress_hud != null else {}
	return {
		"active_world_callouts": active_callouts.size(),
		"active_live_callouts": active_live_callouts.size(),
		"active_ghost_echoes": active_ghosts.size(),
		"active_ghost_trails": active_trails.size(),
		"ghost_echo_cap": MAX_ACTIVE_GHOSTS,
		"ghost_trail_cap": MAX_ACTIVE_TRAILS,
		"callout_cap": MAX_ACTIVE_CALLOUTS,
		"live_words_enabled": live_words_enabled,
		"ghost_replay_enabled": ghost_replay_enabled,
		"ghost_trails_enabled": ghost_trails_enabled,
		"per_ball_subtotals_enabled": per_ball_subtotals_enabled,
		"mapped_anchor_count": int(last_mapping_diagnostics.get("mapped_anchor_count", 0)),
		"mapping_fallback_count": int(last_mapping_diagnostics.get("fallback_count", 0)),
		"mapped_anchors": _array_value(current_mapping, "steps").duplicate(true),
		"mapping_warnings": _array_value(last_mapping_diagnostics, "warnings").duplicate(true),
		"mapping_missing_event_indices": _array_value(last_mapping_diagnostics, "missing_event_indices").duplicate(),
		"mapping_invalid_position_count": int(last_mapping_diagnostics.get("invalid_position_count", 0)),
		"offscreen_clamp_count": offscreen_clamp_count,
		"world_score_callouts_enabled": world_score_callouts_enabled,
		"persistent_equation_enabled": persistent_equation_enabled,
		"persistent_round_bar_enabled": persistent_round_bar_enabled,
		"local_source_flashes_enabled": local_source_flashes_enabled,
		"show_presentation_anchors": show_presentation_anchors,
		"replay_excitement": replay_excitement,
		"last_replay_callout_metadata": last_replay_callout_metadata.duplicate(true),
		"mapping_self_test": mapping_self_test_result.duplicate(true),
		"hud": hud_snapshot,
	}


func _draw() -> void:
	if not show_presentation_anchors or current_mapping.is_empty():
		return
	for mapped_value in _array_value(current_mapping, "steps"):
		if not mapped_value is Dictionary:
			continue
		var mapped: Dictionary = mapped_value
		var true_position: Vector2 = _mapped_screen_position(mapped)
		var clamped_position: Vector2 = _clamp_callout_center(true_position, false)
		var color: Color = _anchor_debug_color(str(mapped.get("anchor_reason", "")))
		draw_circle(true_position, 5.0, color, false, 2.0)
		if true_position.distance_to(clamped_position) > 1.0:
			draw_line(true_position, clamped_position, Color(color.r, color.g, color.b, 0.55), 1.0)
		var label: String = "%d %s e%d %s%s" % [
			int(mapped.get("step_index", -1)),
			str(mapped.get("source_id", "")),
			int(mapped.get("event_index", -1)),
			str(mapped.get("anchor_reason", "")),
			" FALLBACK" if bool(mapped.get("fallback_used", false)) else "",
		]
		draw_string(UI_FONT, clamped_position + Vector2(8.0, -7.0), label, HORIZONTAL_ALIGNMENT_LEFT, 420.0, 12, color)


func _mapped_screen_position(mapped: Dictionary) -> Vector2:
	if str(mapped.get("anchor_type", "hud")) != "world":
		return progress_hud.get_equation_anchor_screen_position() if progress_hud != null else get_viewport_rect().size * 0.5
	var world_value: Variant = mapped.get("world_position", Vector2.ZERO)
	if not world_value is Vector2:
		return progress_hud.get_equation_anchor_screen_position() if progress_hud != null else get_viewport_rect().size * 0.5
	return get_viewport().get_canvas_transform() * (world_value as Vector2)


func _clamp_callout_center(source: Vector2, count_clamp: bool = true) -> Vector2:
	var clamped: Vector2 = _clamp_center_for_size(source, EVENT_CALLOUT_BASE.CALLOUT_SIZE)
	if count_clamp and source.distance_to(clamped) > 1.0:
		offscreen_clamp_count += 1
	return clamped


func _clamp_center_for_size(source: Vector2, control_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_size: Vector2 = control_size * 0.5
	return Vector2(
		clampf(source.x, VIEWPORT_SAFE_MARGIN + half_size.x, maxf(viewport_size.x - VIEWPORT_SAFE_MARGIN - half_size.x, VIEWPORT_SAFE_MARGIN + half_size.x)),
		clampf(source.y, VIEWPORT_SAFE_MARGIN + half_size.y, maxf(viewport_size.y - VIEWPORT_SAFE_MARGIN - half_size.y, VIEWPORT_SAFE_MARGIN + half_size.y))
	)


func _world_to_screen(world_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world_position


func _spawn_score_callout(
	step: Dictionary,
	center: Vector2,
	duration: float,
	true_source: Vector2 = Vector2.ZERO
) -> void:
	_enforce_callout_cap()
	var source: Vector2 = center if true_source == Vector2.ZERO else true_source
	var callout_step: Dictionary = step.duplicate(true)
	if not callout_step.has("global_excitement_normalized"):
		callout_step["global_excitement_normalized"] = replay_excitement
	if not callout_step.has("replay_excitement"):
		callout_step["replay_excitement"] = replay_excitement
	var callout: RogueliteWorldScoreCallout = CALLOUT_SCRIPT.new() as RogueliteWorldScoreCallout
	callout.name = "ScoreCallout%d" % int(callout_step.get("step_index", active_callouts.size()))
	add_child(callout)
	callout.setup(callout_step, center, source, local_source_flashes_enabled)
	callout.finished.connect(_on_callout_finished)
	active_callouts.append(callout)
	callout.play(duration)


func _make_narrative_callout_step(event: Dictionary, ball_narrative: Dictionary) -> Dictionary:
	var event_type: String = str(event.get("event_type", ""))
	var tier_index: int = maxi(int(event.get("tier_index", 0)), 0)
	var tier_count: int = maxi(int(event.get("tier_count", 1)), 1)
	var sequence_index: int = int(event.get("sequence_index", -1))
	var event_excitement: float = clampf(float(event.get(
		"global_excitement_normalized",
		replay_excitement
	)), 0.0, 1.0)
	var event_replay_excitement: float = clampf(float(event.get(
		"replay_excitement",
		replay_excitement
	)), 0.0, 1.0)
	var is_pocket: bool = bool(event.get(
		"is_pocket",
		event_type in ["pocket", "additional_ball"]
	))
	var is_combination: bool = bool(event.get(
		"is_combination",
		event_type == "combination" or bool(ball_narrative.get("is_combination", false))
	))
	var is_final_tier: bool = bool(event.get(
		"is_final_tier",
		tier_index + 1 >= tier_count
	))
	return {
		"step_index": sequence_index,
		"sequence_index": sequence_index,
		"title": _get_narrative_replay_title(event),
		"effect_text": str(event.get("effect_text", "")),
		"affects_score": bool(event.get("affects_score", true)),
		"event_type": event_type,
		"source_id": str(event.get("source_id", "")),
		"tier_index": tier_index,
		"tier_count": tier_count,
		"ball_id": int(event.get("ball_id", ball_narrative.get("ball_id", -1))),
		"final_classification": str(event.get(
			"final_classification",
			ball_narrative.get("final_classification", "")
		)),
		"global_excitement_normalized": event_excitement,
		"replay_excitement": event_replay_excitement,
		"is_final_tier": is_final_tier,
		"is_pocket": is_pocket,
		"is_combination": is_combination,
		"event_index": int(event.get("event_index", -1)),
		"tap_family": str(event.get("tap_family", "")),
		"display_tier": str(event.get("display_tier", "")),
		"trigger_occurrence_id": str(event.get("trigger_occurrence_id", "")),
		"tap_ordinal": int(event.get("tap_ordinal", 0)),
		"cue_strike_ordinal": int(event.get("cue_strike_ordinal", 0)),
		"unique_contact_ordinal": int(event.get("unique_contact_ordinal", 0)),
		"contacted_ball_id": int(event.get("contacted_ball_id", -1)),
		"rail_id": str(event.get("rail_id", "")),
		"pocket_index": int(event.get("pocket_index", -1)),
	}


func _get_narrative_replay_title(event: Dictionary) -> String:
	var title: String = str(event.get("replay_title", "SCORE"))
	if (
		str(event.get("event_type", "")) in ["rail_milestone", "rail_group"]
		and int(event.get("tier_index", 0)) >= 2
	):
		return "TRIPLE BANK!!!"
	return title


func _enforce_callout_cap() -> void:
	while active_callouts.size() + active_live_callouts.size() >= MAX_ACTIVE_CALLOUTS:
		if not active_live_callouts.is_empty():
			var old_live: RogueliteLiveScoringCallout = active_live_callouts.pop_front()
			if old_live != null and is_instance_valid(old_live):
				old_live.finish_immediately()
		elif not active_callouts.is_empty():
			var old_score: RogueliteWorldScoreCallout = active_callouts.pop_front()
			if old_score != null and is_instance_valid(old_score):
				old_score.finish_immediately()
		else:
			break


func _spawn_ghost(
	ball_narrative: Dictionary,
	screen_position: Vector2,
	event: Dictionary
) -> void:
	while active_ghosts.size() >= MAX_ACTIVE_GHOSTS:
		var oldest: RogueliteScoringGhostBall = active_ghosts.pop_front()
		current_ball_ghosts.erase(oldest)
		if oldest != null and is_instance_valid(oldest):
			oldest.finish_immediately()
	var ghost: RogueliteScoringGhostBall = GHOST_BALL_SCRIPT.new() as RogueliteScoringGhostBall
	ghost.name = "ScoringGhost%d" % active_ghosts.size()
	add_child(ghost)
	var tier: int = clampi(int(event.get("tier_index", 0)), 0, 2)
	ghost.setup(_dictionary_value(ball_narrative, "appearance"), screen_position, 0.9 + float(tier) * 0.12)
	ghost.finished.connect(_on_ghost_finished)
	active_ghosts.append(ghost)
	current_ball_ghosts.append(ghost)


func _spawn_contact_ghost(event: Dictionary) -> void:
	var appearance: Dictionary = _dictionary_value(event, "contacted_ball_appearance")
	var position_value: Variant = event.get("contacted_ball_world_position", null)
	if (
		appearance.is_empty()
		or not bool(event.get("contacted_ball_world_position_valid", false))
		or not position_value is Vector2
	):
		return
	while active_ghosts.size() >= MAX_ACTIVE_GHOSTS:
		var oldest: RogueliteScoringGhostBall = active_ghosts.pop_front()
		current_ball_ghosts.erase(oldest)
		if oldest != null and is_instance_valid(oldest):
			oldest.finish_immediately()
	var ghost: RogueliteScoringGhostBall = GHOST_BALL_SCRIPT.new() as RogueliteScoringGhostBall
	ghost.name = "ScoringContactGhost%d" % active_ghosts.size()
	add_child(ghost)
	ghost.setup(
		appearance,
		_world_to_screen(position_value as Vector2),
		0.66
	)
	ghost.ghost_alpha = 0.42
	ghost.finished.connect(_on_ghost_finished)
	active_ghosts.append(ghost)
	current_ball_ghosts.append(ghost)


func _request_tap_replay_cue(event: Dictionary) -> void:
	var event_type: String = str(event.get("event_type", ""))
	if event_type not in [
		"cue_recontact_milestone",
		"object_ball_tap_milestone",
	]:
		return
	if (
		table == null
		or table.roguelite_live_scoring_system == null
		or not bool(event.get("world_position_valid", false))
	):
		return
	var conductor: RogueliteScoringCueConductor = (
		table.roguelite_live_scoring_system.get_conductor()
	)
	if conductor == null:
		return
	var ordinal: int = maxi(int(event.get("tap_ordinal", 0)), 1)
	var cue_kind: String = ""
	var excitement_weight: float = 0.0
	if event_type == "cue_recontact_milestone":
		ordinal = maxi(int(event.get("cue_strike_ordinal", ordinal)), 2)
		cue_kind = (
			RogueliteScoringCueConductor.CUE_DOUBLE_TAP
			if ordinal <= 2
			else RogueliteScoringCueConductor.CUE_TRIPLE_TAP
		)
		excitement_weight = 2.0 if ordinal <= 2 else 3.0
	else:
		ordinal = maxi(int(event.get("unique_contact_ordinal", ordinal)), 1)
		cue_kind = (
			RogueliteScoringCueConductor.CUE_BALL_TAP
			if ordinal <= 1
			else RogueliteScoringCueConductor.CUE_BALL_TAP_CHAIN
		)
		excitement_weight = 1.0 if ordinal <= 1 else 2.0
	var world_value: Variant = event.get("world_position", Vector2.ZERO)
	if not world_value is Vector2:
		return
	conductor.request_replay_cue(
		int(event.get("ball_id", -1)),
		cue_kind,
		world_value as Vector2,
		{
			"excitement_weight": excitement_weight,
			"milestone": ordinal,
			"tap_family": str(event.get("tap_family", "")),
			"tap_ordinal": ordinal,
			"planned_final_tier": int(event.get("tier_count", 1)),
			"cue_key": "replay:%d:%d" % [
				int(current_result.get("attempt_id", -1)),
				int(event.get("sequence_index", -1)),
			],
			"force_distinct": (
				event_type == "cue_recontact_milestone" or ordinal >= 2
			),
		}
	)


func _append_ghost_trail(ball_narrative: Dictionary, screen_position: Vector2) -> void:
	if current_ball_trail == null or not is_instance_valid(current_ball_trail):
		current_ball_trail = GHOST_TRAIL_SCRIPT.new() as RogueliteScoringGhostTrail
		current_ball_trail.name = "ScoringGhostTrail%d" % current_ball_id
		add_child(current_ball_trail)
		var appearance: Dictionary = _dictionary_value(ball_narrative, "appearance")
		var color_value: Variant = appearance.get("base_color", Color.WHITE)
		var trail_color: Color = color_value as Color if color_value is Color else Color.WHITE
		current_ball_trail.setup(trail_color)
		current_ball_trail.finished.connect(_on_trail_finished)
		while active_trails.size() >= MAX_ACTIVE_TRAILS:
			var oldest: RogueliteScoringGhostTrail = active_trails.pop_front()
			if oldest != null and is_instance_valid(oldest):
				oldest.finish_immediately()
		active_trails.append(current_ball_trail)
	current_ball_trail.append_point(screen_position)


func _fade_current_ball_echoes() -> void:
	for ghost in current_ball_ghosts:
		if ghost != null and is_instance_valid(ghost):
			ghost.fade_out(0.30)
	current_ball_ghosts.clear()
	if current_ball_trail != null and is_instance_valid(current_ball_trail):
		current_ball_trail.fade_out(0.30)
	current_ball_trail = null


func _apply_hud_configuration() -> void:
	if progress_hud == null:
		return
	progress_hud.persistent_equation_enabled = persistent_equation_enabled
	progress_hud.persistent_round_bar_enabled = persistent_round_bar_enabled
	progress_hud.queue_redraw()


func _on_callout_finished(callout: RogueliteWorldScoreCallout) -> void:
	active_callouts.erase(callout)


func _on_live_callout_finished(callout: RogueliteLiveScoringCallout) -> void:
	active_live_callouts.erase(callout)


func _on_ghost_finished(ghost: RogueliteScoringGhostBall) -> void:
	active_ghosts.erase(ghost)
	current_ball_ghosts.erase(ghost)


func _on_trail_finished(trail: RogueliteScoringGhostTrail) -> void:
	active_trails.erase(trail)
	if current_ball_trail == trail:
		current_ball_trail = null


func _on_final_result_dismiss_requested(method: String) -> void:
	final_result_dismiss_requested.emit(method)


func _anchor_debug_color(reason: String) -> Color:
	if reason.contains("pocket"):
		return Color("f2c45f")
	if reason.contains("rail"):
		return Color("87ded1")
	if reason.contains("contact"):
		return Color("d9a2ff")
	return Color("ef8477")


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value
