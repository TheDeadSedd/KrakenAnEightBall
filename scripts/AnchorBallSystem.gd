@tool
extends Node
class_name AnchorBallSystem

# Owns the current Anchor curse-seed identity: seed selection, chains,
# warning countdowns, collapse, and presentation.
const DEBUG_RADIUS_COLOR := Color(0.28, 0.72, 0.84, 0.26)
const DEBUG_RADIUS_EDGE_COLOR := Color(0.60, 0.96, 1.0, 0.82)
const DEBUG_VECTOR_COLOR := Color(0.82, 0.98, 1.0, 0.92)
const DEBUG_VECTOR_LENGTH_SCALE := 0.32
const DEBUG_VECTOR_MIN_LENGTH := 8.0
const DEBUG_VECTOR_MAX_LENGTH := 36.0
const STATIONARY_ANCHOR_PULL_MULTIPLIER := 0.5
const CURSE_SEED_MAX_REASON_COUNT := 3
const CURSE_CHAIN_SHADOW_COLOR := Color(0.02, 0.06, 0.07, 0.62)
const CURSE_CHAIN_GLOW_COLOR := Color(0.12, 0.66, 0.76, 0.28)
const CURSE_CHAIN_CORE_COLOR := Color(0.67, 0.94, 0.91, 0.86)
const CURSE_CHAIN_LINK_COLOR := Color(0.36, 0.78, 0.80, 0.78)
const CURSE_WARNING_FONT := preload("res://assets/fonts/Gothic Pixels.ttf")
const CURSE_WARNING_GLOW_COLOR := Color(1.0, 0.47, 0.16, 0.34)
const CURSE_WARNING_RING_COLOR := Color(1.0, 0.78, 0.30, 0.88)
const CURSE_WARNING_TEXT_COLOR := Color(1.0, 0.88, 0.48, 0.96)
const CURSE_WARNING_PAUSED_COLOR := Color(0.74, 0.92, 0.96, 0.68)
const CURSE_WARNING_READY_COLOR := Color(1.0, 0.22, 0.12, 0.96)
const CURSE_COLLAPSE_GLOW_COLOR := Color(0.72, 1.0, 0.94, 0.34)
const CURSE_COLLAPSE_RING_COLOR := Color(0.92, 1.0, 0.78, 0.90)
const CURSE_SPREAD_GLOW_COLOR := Color(1.0, 0.26, 0.15, 0.36)
const CURSE_SPREAD_RING_COLOR := Color(1.0, 0.72, 0.24, 0.90)
const CURSE_SPREAD_LINE_COLOR := Color(1.0, 0.40, 0.20, 0.76)
const CURSE_CHAIN_POINT_COUNT := 11
const CURSE_CHAIN_MARK_COUNT := 6
const CURSE_WARNING_FONT_SIZE := 28
const CURSE_WARNING_TEXT_WIDTH := 96.0
const CURSE_COLLAPSE_PULSE_DURATION := 0.38
const CURSE_SPREAD_PULSE_DURATION := 0.48
const RETIRED_CONTINUOUS_PULL_ENABLED := false

class CurseChainLink:
	var target_ball: Ball
	var target_ball_id := 0
	var initial_distance := 0.0
	var current_max_length := 0.0
	var acquisition_score := 0.0
	var touching_at_acquisition := false
	var slide_active := false
	var slide_elapsed := 0.0
	var slide_duration := 0.0
	var slide_start_position := Vector2.ZERO
	var slide_target_position := Vector2.ZERO
	var slide_target_max_length := 0.0

class CurseSeedState:
	var seed_ball: Ball
	var seed_ball_id := 0
	var links: Array = []
	var warning_active := false
	var warning_timer_remaining := 0.0
	var warning_paused := true
	var spread_ready := false
	var cue_hit_count := 0
	var warning_grace_remaining := 0.0

# Retired continuous-field tuning. Kept only as a short-term compatibility
# shell while old pull code is removed; RETIRED_CONTINUOUS_PULL_ENABLED keeps
# it hard-disabled for normal play and debug testing.
@export var enabled := true
@export var influence_radius := 230.0
@export var pull_strength := 400.0
@export_range(0.0, 1.0, 0.01) var minimum_pull_strength := 0.08
# Lets close settled balls barely wake without turning Anchor into a table-wide vacuum.
@export_range(0.0, 1.0, 0.01) var stationary_ball_multiplier := 0.20

# Stopped object balls use a cheaper wake path so settled high-ball-count tables
# do not do full Anchor-vs-stationary work every physics substep.
@export var stationary_pull_update_interval := 0.18
@export var stationary_min_wake_speed := 5.0
@export var max_stationary_wake_impulse := 8.0
@export var stationary_wake_cooldown := 0.55
@export var stationary_wake_recheck_distance := 10.0

# Contact-loop guards.
@export var inner_dead_zone_radius := 28.0
@export var post_collision_pull_cooldown := 0.35

# Visual/debug controls.
@export_range(0.0, 1.0, 0.01) var visual_effect_strength := 1.0
@export var anchor_visuals_enabled := true
@export var max_visible_field_auras := 3
@export var debug_visual_enabled := false
# Official overlap rule: each target follows one strongest Anchor current per update.
@export var anchor_single_latch_per_target_enabled := true

# Debug safety valve only. Normal play should support chaos by degrading visuals first.
@export var anchor_spawn_cap_enabled := false
@export var max_anchor_balls_on_table := 3

# Curse seed selection is event-time only: score candidates once when the eight
# ball penalty fires, then leave the seed dormant until later Anchor slices.
@export var curse_seed_rail_score_distance := 120.0
@export var curse_seed_clutter_radius := 96.0
@export var curse_seed_pocket_extra_clearance := 42.0
@export var curse_seed_direct_line_clearance := 7.0
@export_range(1, 3, 1) var curse_chain_max_links := 3
@export var curse_chain_acquisition_radius := 220.0
@export var curse_chain_touching_buffer := 8.0
@export var curse_chain_tighten_step_distance := 18.0
@export var curse_chain_tighten_pocket_clearance := 18.0
@export var curse_chain_tighten_overlap_clearance := 3.0
@export var curse_chain_tighten_trail_suppression := 0.12
@export var curse_chain_tighten_slide_duration := 0.18
@export var curse_chain_deconflict_angle_degrees := 18.0
@export var curse_chain_deconflict_angle_step_degrees := 10.0
@export var curse_warning_duration := 3.0
@export var curse_warning_touch_epsilon := 1.5
@export_range(1, 4, 1) var curse_seed_cue_hits_to_collapse := 1
@export var curse_seed_cannon_collapse_min_speed := 80.0
@export var curse_spread_new_seed_warning_grace := 0.75

var table
var active_anchor_ball_count := 0
var force_applications_this_frame := 0
var total_force_this_frame := 0.0
var max_force_this_frame := 0.0
var nearest_distance_this_frame := INF
var affected_ball_ids: Dictionary = {}
var debug_pull_vectors: Dictionary = {}
var latch_candidate_counts_this_update: Dictionary = {}
var multi_latch_candidates_this_frame := 0
var single_latch_skipped_this_frame := 0
var max_anchors_affecting_same_ball_this_frame := 0
var multi_latch_target_ids_this_frame: Dictionary = {}
var post_collision_pull_cooldowns: Dictionary = {}
var stationary_wake_cooldowns: Dictionary = {}
var stationary_wake_positions: Dictionary = {}
var stationary_pull_accumulator := 0.0
var curse_seeds_created := 0
var curse_seed_penalty_attempts := 0
var curse_seed_penalty_replacements := 0
var last_curse_seed_eligible_candidates := 0
var last_curse_seed_selected_score := 0.0
var last_curse_seed_selected_reason := "none"
var last_curse_seed_selected_ball_number := -1
var curse_seed_states: Dictionary = {}
var failed_chain_acquisitions := 0
var invalidated_chain_links := 0
var last_chain_links_created := 0
var chain_tighten_steps_applied := 0
var chain_tighten_steps_skipped := 0
var chain_tighten_total_distance := 0.0
var chain_tighten_last_distance := 0.0
var chain_tighten_last_skip_reason := "none"
var chain_tighten_skip_reasons: Dictionary = {}
var chain_constraint_clamps_applied := 0
var chain_tighten_slides_started := 0
var chain_tighten_slides_completed := 0
var chain_tighten_slides_blocked := 0
var chain_deconfliction_attempts := 0
var chain_deconfliction_successes := 0
var chain_deconfliction_blocked := 0
var chain_deconfliction_skipped := 0
var chain_deconfliction_last_reason := "none"
var curse_warning_started := 0
var curse_warning_resets := 0
var curse_seeds_collapsed_total := 0
var curse_seeds_collapsed_by_cue := 0
var curse_seeds_collapsed_by_powder := 0
var curse_seeds_collapsed_by_cannon := 0
var curse_seeds_collapsed_by_chained_ball_pocket := 0
var last_collapsed_chained_ball_number := -1
var curse_chains_released_by_collapse := 0
var curse_spread_events_total := 0
var curse_seeds_created_by_spread := 0
var curse_spread_blocked_skipped := 0
var max_active_curse_seeds := 0
var curse_collapse_pulses: Array[Dictionary] = []
var curse_spread_pulses: Array[Dictionary] = []


func setup(table_ref) -> void:
	table = table_ref


func try_create_curse_seed_from_eight_ball_penalty(sink_position: Vector2) -> Dictionary:
	curse_seed_penalty_attempts += 1
	var selection: Dictionary = _select_curse_seed_candidate(sink_position)
	return _create_curse_seed_from_selection(selection, true)


func try_create_debug_curse_seed() -> Dictionary:
	var selection_origin: Vector2 = _get_debug_curse_seed_selection_origin()
	var selection: Dictionary = _select_curse_seed_candidate(selection_origin)
	return _create_curse_seed_from_selection(selection, false)


func _create_curse_seed_from_selection(selection: Dictionary, counts_as_penalty_replacement: bool) -> Dictionary:
	last_curse_seed_eligible_candidates = int(selection.get("eligible_candidates", 0))
	if not selection.has("ball"):
		last_curse_seed_selected_score = 0.0
		last_curse_seed_selected_reason = "no eligible normal object ball"
		last_curse_seed_selected_ball_number = -1
		return {
			"created": false,
			"eligible_candidates": last_curse_seed_eligible_candidates,
			"score": last_curse_seed_selected_score,
			"reason": last_curse_seed_selected_reason,
			"ball_number": last_curse_seed_selected_ball_number,
		}

	var seed_ball: Ball = selection["ball"] as Ball
	if seed_ball == null:
		last_curse_seed_selected_score = 0.0
		last_curse_seed_selected_reason = "selected ball invalid"
		last_curse_seed_selected_ball_number = -1
		return {
			"created": false,
			"eligible_candidates": last_curse_seed_eligible_candidates,
			"score": last_curse_seed_selected_score,
			"reason": last_curse_seed_selected_reason,
			"ball_number": last_curse_seed_selected_ball_number,
		}

	_transform_ball_to_curse_seed(seed_ball)
	_register_curse_seed_state(seed_ball)
	curse_seeds_created += 1
	if counts_as_penalty_replacement:
		curse_seed_penalty_replacements += 1
	last_curse_seed_selected_score = float(selection["score"])
	last_curse_seed_selected_reason = str(selection["reason"])
	if not counts_as_penalty_replacement:
		last_curse_seed_selected_reason = "debug spawn, %s" % last_curse_seed_selected_reason
	last_curse_seed_selected_ball_number = seed_ball.ball_number
	_update_max_active_curse_seed_count()
	return {
		"created": true,
		"eligible_candidates": last_curse_seed_eligible_candidates,
		"score": last_curse_seed_selected_score,
		"reason": last_curse_seed_selected_reason,
		"ball_number": last_curse_seed_selected_ball_number,
	}


func _get_debug_curse_seed_selection_origin() -> Vector2:
	if table != null and table.cue_ball != null and is_instance_valid(table.cue_ball):
		return table.cue_ball.global_position
	if table != null and table.playfield_rect.size != Vector2.ZERO:
		return table.playfield_rect.get_center()
	return Vector2.ZERO


func is_curse_seed_ball(ball: Ball) -> bool:
	return ball != null and ball.is_anchor_curse_seed and ball.is_gameplay_active()


func try_separate_curse_seed_overlap(ball_a: Ball, ball_b: Ball, normal: Vector2, overlap: float) -> bool:
	var a_is_seed: bool = is_curse_seed_ball(ball_a)
	var b_is_seed: bool = is_curse_seed_ball(ball_b)
	if not a_is_seed and not b_is_seed:
		return false

	var correction: Vector2 = normal * (overlap + 0.01)
	if a_is_seed and not b_is_seed:
		ball_a.velocity = Vector2.ZERO
		ball_b.global_position += correction
	elif b_is_seed and not a_is_seed:
		ball_a.global_position -= correction
		ball_b.velocity = Vector2.ZERO
	else:
		ball_a.velocity = Vector2.ZERO
		ball_b.velocity = Vector2.ZERO
	return true


func try_apply_curse_seed_collision_response(
	ball_a: Ball,
	ball_b: Ball,
	_normal: Vector2,
	impulse: Vector2
) -> bool:
	var a_is_seed: bool = is_curse_seed_ball(ball_a)
	var b_is_seed: bool = is_curse_seed_ball(ball_b)
	if not a_is_seed and not b_is_seed:
		return false

	var seed_ball: Ball = ball_a if a_is_seed else ball_b
	if _try_collapse_curse_seed_from_cue_hit(ball_a, ball_b, seed_ball):
		return false
	if _try_collapse_curse_seed_from_cannon_hit(ball_a, ball_b, seed_ball, _normal):
		return false

	if a_is_seed and not b_is_seed:
		ball_a.velocity = Vector2.ZERO
		ball_b.velocity += impulse
	elif b_is_seed and not a_is_seed:
		ball_a.velocity -= impulse
		ball_b.velocity = Vector2.ZERO
	else:
		ball_a.velocity = Vector2.ZERO
		ball_b.velocity = Vector2.ZERO
	return true


func try_collapse_curse_seed_from_powder(seed_ball: Ball) -> bool:
	return _collapse_curse_seed_ball(seed_ball, "powder")


func advance_curse_chains_on_cue_control_regained() -> void:
	if table == null:
		return

	_validate_curse_seed_chain_states()
	var did_attempt_tighten := false
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue

		for link_value in state.links:
			var link: CurseChainLink = link_value as CurseChainLink
			if not _is_valid_curse_chain_link(state.seed_ball, link):
				continue

			did_attempt_tighten = true
			_apply_curse_chain_tighten_step(state, link)

	if did_attempt_tighten:
		table.queue_redraw()


func update_curse_chain_slides(delta: float) -> void:
	if table == null:
		return

	var did_update_slide := false
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue

		for link_value in state.links:
			var link: CurseChainLink = link_value as CurseChainLink
			if not _is_valid_curse_chain_link(state.seed_ball, link):
				continue
			if _update_curse_chain_slide(state.seed_ball, link, delta):
				did_update_slide = true

	if did_update_slide:
		table.queue_redraw()


func enforce_curse_chain_constraints() -> void:
	if table == null:
		return

	var did_clamp := false
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue

		for link_value in state.links:
			var link: CurseChainLink = link_value as CurseChainLink
			if not _is_valid_curse_chain_link(state.seed_ball, link):
				continue
			if _enforce_curse_chain_constraint(state.seed_ball, link):
				did_clamp = true

	if did_clamp:
		table.queue_redraw()


func update_curse_warning_timers(delta: float, can_player_act: bool) -> void:
	if table == null:
		return

	_validate_curse_seed_chain_states()
	var needs_redraw := false
	var spread_queue: Array = []
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue

		_tick_curse_seed_warning_grace(state, delta)
		var all_links_touching: bool = _are_all_curse_chain_links_touching_seed(state)
		if not all_links_touching:
			if state.warning_active or state.spread_ready:
				_reset_curse_warning_state(state)
			needs_redraw = true
			continue

		if state.warning_grace_remaining > 0.0:
			state.warning_paused = true
			needs_redraw = true
			continue

		if not state.warning_active and not state.spread_ready:
			_start_curse_warning_state(state)
			needs_redraw = true

		if state.spread_ready:
			needs_redraw = true
			continue

		state.warning_paused = not can_player_act
		if state.warning_paused:
			needs_redraw = true
			continue

		state.warning_timer_remaining = maxf(state.warning_timer_remaining - delta, 0.0)
		needs_redraw = true
		if state.warning_timer_remaining <= 0.0:
			state.warning_active = false
			state.warning_paused = false
			state.spread_ready = true
			spread_queue.append(state)

	for spread_state_value in spread_queue:
		var spread_state: CurseSeedState = spread_state_value as CurseSeedState
		if _spread_curse_seed_state(spread_state):
			needs_redraw = true

	if needs_redraw:
		table.queue_redraw()


func reset_frame_stats() -> void:
	active_anchor_ball_count = 0
	force_applications_this_frame = 0
	total_force_this_frame = 0.0
	max_force_this_frame = 0.0
	nearest_distance_this_frame = INF
	affected_ball_ids.clear()
	debug_pull_vectors.clear()
	latch_candidate_counts_this_update.clear()
	multi_latch_candidates_this_frame = 0
	single_latch_skipped_this_frame = 0
	max_anchors_affecting_same_ball_this_frame = 0
	multi_latch_target_ids_this_frame.clear()


func update_pull(delta: float) -> void:
	if table == null:
		return

	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		# Retired identity: no continuous Anchor field work may run in play or debug.
		active_anchor_ball_count = 0
		_clear_retired_anchor_pull_debug_state()
		return

	_update_post_collision_pull_cooldowns(delta)
	_update_stationary_wake_cooldowns(delta)
	var anchor_balls: Array[Ball] = _get_active_anchor_balls()
	active_anchor_ball_count = anchor_balls.size()
	if debug_visual_enabled:
		table.queue_redraw()
	if anchor_balls.is_empty():
		return

	_apply_anchor_visual_settings(anchor_balls)

	if not enabled:
		return

	var target_groups: Dictionary = _get_pull_target_groups()
	var moving_targets: Array = target_groups["moving"]
	var stationary_targets: Array = target_groups["stationary"]
	var should_check_stationary_pull: bool = _should_check_stationary_pull(delta, not stationary_targets.is_empty())
	if moving_targets.is_empty() and not should_check_stationary_pull:
		return

	_begin_latch_candidate_update()
	if anchor_single_latch_per_target_enabled:
		if not moving_targets.is_empty():
			_apply_single_latch_anchor_pull_to_targets(anchor_balls, moving_targets, delta, false)
		if should_check_stationary_pull:
			_apply_single_latch_anchor_pull_to_targets(anchor_balls, stationary_targets, delta, true)
	else:
		for anchor_ball in anchor_balls:
			if not moving_targets.is_empty():
				_apply_anchor_pull_to_targets(anchor_ball, moving_targets, delta, false)
			if should_check_stationary_pull:
				_apply_anchor_pull_to_targets(anchor_ball, stationary_targets, delta, true)
	_finish_latch_candidate_update()


func _clear_retired_anchor_pull_debug_state() -> void:
	affected_ball_ids.clear()
	debug_pull_vectors.clear()
	latch_candidate_counts_this_update.clear()
	multi_latch_candidates_this_frame = 0
	single_latch_skipped_this_frame = 0
	max_anchors_affecting_same_ball_this_frame = 0
	multi_latch_target_ids_this_frame.clear()
	stationary_pull_accumulator = 0.0


func finish_frame() -> void:
	_validate_curse_seed_chain_states()
	_prune_curse_collapse_pulses()
	_prune_curse_spread_pulses()
	_update_max_active_curse_seed_count()
	if (
		anchor_visuals_enabled
		and table != null
		and (
			_get_total_curse_chain_link_count() > 0
			or not curse_collapse_pulses.is_empty()
			or not curse_spread_pulses.is_empty()
		)
	):
		table.queue_redraw()
	_sync_anchor_influence_markers()


func handle_collision(ball_a: Ball, ball_b: Ball) -> void:
	_try_set_post_collision_cooldown(ball_a, ball_b)
	_try_set_post_collision_cooldown(ball_b, ball_a)


func handle_ball_pocketed(pocketed_ball: Ball) -> void:
	var owning_state: CurseSeedState = _get_curse_seed_state_for_chained_ball(pocketed_ball)
	if owning_state == null:
		return

	last_collapsed_chained_ball_number = pocketed_ball.ball_number
	_collapse_curse_seed_state(owning_state, "chained_ball_pocketed")


func get_debug_snapshot() -> Dictionary:
	var visual_counts: Dictionary = _get_retired_anchor_visual_counts()
	if RETIRED_CONTINUOUS_PULL_ENABLED:
		visual_counts = _get_anchor_visual_counts()
	return {
		"enabled": enabled,
		"active_anchor_balls": active_anchor_ball_count,
		"affected_balls": affected_ball_ids.size(),
		"force_applications": force_applications_this_frame,
		"avg_force": _get_average_force(),
		"max_force": max_force_this_frame,
		"nearest_distance": _get_nearest_distance_or_negative(),
		"single_latch_enabled": anchor_single_latch_per_target_enabled,
		"multi_latch_candidates": multi_latch_candidates_this_frame,
		"single_latch_skipped": single_latch_skipped_this_frame,
		"max_anchors_affecting_same_ball": max_anchors_affecting_same_ball_this_frame,
		"targets_affected_by_multiple_anchors": multi_latch_target_ids_this_frame.size(),
		"influence_radius": influence_radius,
		"pull_strength": pull_strength,
		"visuals_enabled": anchor_visuals_enabled,
		"visual_nodes_active": visual_counts["visual_nodes_active"],
		"field_rings_drawn": visual_counts["field_rings_drawn"],
		"affected_markers_active": visual_counts["affected_markers_active"],
		"max_visible_field_auras": max_visible_field_auras,
		"spawn_cap_enabled": anchor_spawn_cap_enabled,
		"max_anchor_balls_on_table": max_anchor_balls_on_table,
		"active_curse_seeds": _get_active_curse_seed_count(),
		"curse_seeds_created": curse_seeds_created,
		"curse_seed_penalty_attempts": curse_seed_penalty_attempts,
		"curse_seed_penalty_replacements": curse_seed_penalty_replacements,
		"curse_seed_eligible_candidates": last_curse_seed_eligible_candidates,
		"curse_seed_selected_score": last_curse_seed_selected_score,
		"curse_seed_selected_reason": last_curse_seed_selected_reason,
		"curse_seed_selected_ball_number": last_curse_seed_selected_ball_number,
		"curse_chain_links": _get_total_curse_chain_link_count(),
		"curse_chain_links_per_seed": _make_curse_chain_links_per_seed_text(),
		"curse_chain_failed_acquisitions": failed_chain_acquisitions,
		"curse_chain_invalidated_links": invalidated_chain_links,
		"curse_chain_last_created": last_chain_links_created,
		"curse_chain_tighten_steps_applied": chain_tighten_steps_applied,
		"curse_chain_tighten_steps_skipped": chain_tighten_steps_skipped,
		"curse_chain_tighten_avg_distance": _get_average_chain_tighten_distance(),
		"curse_chain_tighten_last_distance": chain_tighten_last_distance,
		"curse_chain_touching_seed_links": _get_touching_curse_chain_link_count(),
		"curse_chain_tighten_last_skip_reason": chain_tighten_last_skip_reason,
		"curse_chain_tighten_skip_reasons": _make_chain_tighten_skip_reason_text(),
		"curse_chain_max_lengths": _make_curse_chain_max_lengths_text(),
		"curse_chain_constraint_clamps": chain_constraint_clamps_applied,
		"curse_chain_tighten_slides_started": chain_tighten_slides_started,
		"curse_chain_tighten_slides_completed": chain_tighten_slides_completed,
		"curse_chain_tighten_slides_blocked": chain_tighten_slides_blocked,
		"curse_chain_deconfliction_attempts": chain_deconfliction_attempts,
		"curse_chain_deconfliction_successes": chain_deconfliction_successes,
		"curse_chain_deconfliction_blocked": chain_deconfliction_blocked,
		"curse_chain_deconfliction_skipped": chain_deconfliction_skipped,
		"curse_chain_deconfliction_last_reason": chain_deconfliction_last_reason,
		"curse_warning_seeds": _get_curse_warning_seed_count(),
		"curse_warning_timer_remaining": _get_lowest_curse_warning_timer_remaining(),
		"curse_warning_timer_state": _make_curse_warning_timer_state_text(),
		"curse_warning_spread_ready": _get_curse_spread_ready_count(),
		"curse_warning_started": curse_warning_started,
		"curse_warning_resets": curse_warning_resets,
		"curse_collapsed_total": curse_seeds_collapsed_total,
		"curse_collapsed_by_cue": curse_seeds_collapsed_by_cue,
		"curse_collapsed_by_powder": curse_seeds_collapsed_by_powder,
		"curse_collapsed_by_cannon": curse_seeds_collapsed_by_cannon,
		"curse_collapsed_by_chained_ball_pocket": curse_seeds_collapsed_by_chained_ball_pocket,
		"curse_last_collapsed_chained_ball": last_collapsed_chained_ball_number,
		"curse_chains_released_by_collapse": curse_chains_released_by_collapse,
		"curse_spread_events_total": curse_spread_events_total,
		"curse_seeds_created_by_spread": curse_seeds_created_by_spread,
		"curse_spread_blocked_skipped": curse_spread_blocked_skipped,
		"curse_new_seed_grace_count": _get_curse_new_seed_grace_count(),
		"curse_max_active_seeds": max_active_curse_seeds,
	}


func set_anchor_visuals_enabled(enabled_value: bool) -> void:
	anchor_visuals_enabled = enabled_value
	if table == null:
		return

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball != null:
			ball.set_anchor_visuals_enabled(anchor_visuals_enabled)

	_apply_anchor_visual_settings(_get_active_anchor_balls())


func are_anchor_visuals_enabled() -> bool:
	return anchor_visuals_enabled


func can_spawn_anchor_ball() -> bool:
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		return false
	if not anchor_spawn_cap_enabled:
		return true
	return get_current_anchor_ball_count() < max_anchor_balls_on_table


func get_current_anchor_ball_count() -> int:
	if table == null:
		return 0
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		return 0

	var anchor_ball_count := 0
	for child in table.balls.get_children():
		var ball := child as Ball
		if _is_anchor_field_source(ball):
			anchor_ball_count += 1
	return anchor_ball_count


func set_debug_visual_enabled(enabled_value: bool) -> void:
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		debug_visual_enabled = false
		return

	debug_visual_enabled = enabled_value
	if table != null:
		table.queue_redraw()


func is_debug_visual_enabled() -> bool:
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		return false
	return debug_visual_enabled


func set_single_latch_per_target_enabled(enabled_value: bool) -> void:
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		anchor_single_latch_per_target_enabled = false
		return
	anchor_single_latch_per_target_enabled = enabled_value


func is_single_latch_per_target_enabled() -> bool:
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		return false
	return anchor_single_latch_per_target_enabled


func draw_curse_chains(canvas: Node2D) -> void:
	if not anchor_visuals_enabled or table == null:
		return

	var visual_time: float = float(Time.get_ticks_msec()) * 0.001
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue

		for link_index in range(state.links.size()):
			var link: CurseChainLink = state.links[link_index] as CurseChainLink
			if not _is_valid_curse_chain_link(state.seed_ball, link):
				continue
			_draw_curse_chain(canvas, state.seed_ball, link.target_ball, visual_time, link_index)

		_draw_curse_warning_presentation(canvas, state, visual_time)

	_draw_curse_collapse_pulses(canvas, visual_time)
	_draw_curse_spread_pulses(canvas, visual_time)


func draw_debug(canvas: Node2D) -> void:
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		return
	if not debug_visual_enabled or table == null:
		return

	for anchor_ball in _get_active_anchor_balls():
		var anchor_position: Vector2 = canvas.to_local(anchor_ball.global_position)
		canvas.draw_circle(anchor_position, influence_radius, DEBUG_RADIUS_COLOR)
		canvas.draw_arc(anchor_position, influence_radius, 0.0, TAU, 80, DEBUG_RADIUS_EDGE_COLOR, 2.0)

	for vector_entry in debug_pull_vectors.values():
		var vector_data: Dictionary = vector_entry
		var start_global_position: Vector2 = vector_data["start"]
		var end_global_position: Vector2 = vector_data["end"]
		var start_position: Vector2 = canvas.to_local(start_global_position)
		var end_position: Vector2 = canvas.to_local(end_global_position)
		canvas.draw_line(start_position, end_position, DEBUG_VECTOR_COLOR, 2.0)
		canvas.draw_circle(end_position, 2.8, DEBUG_VECTOR_COLOR)


func _select_curse_seed_candidate(sink_position: Vector2) -> Dictionary:
	var best_selection: Dictionary = {}
	var eligible_candidates := 0
	if table == null:
		return {"eligible_candidates": eligible_candidates}

	for child in table.balls.get_children():
		var candidate: Ball = child as Ball
		if not _is_curse_seed_candidate(candidate):
			continue

		eligible_candidates += 1
		var score_data: Dictionary = _score_curse_seed_candidate(candidate, sink_position)
		if best_selection.is_empty() or float(score_data["score"]) > float(best_selection["score"]):
			best_selection = score_data

	best_selection["eligible_candidates"] = eligible_candidates
	return best_selection


func _is_curse_seed_candidate(ball: Ball) -> bool:
	if table == null or ball == null:
		return false
	if ball == table.cue_ball or ball == table.eight_ball:
		return false
	if not ball.visible or not ball.gameplay_enabled:
		return false
	if ball.ball_type != Ball.BallType.OBJECT:
		return false
	if ball.is_wayfinder or ball.is_powder_keg or ball.is_anchor_ball or ball.is_cannon_ball or ball.is_treasure_ball:
		return false
	if table.pocket_system.is_position_too_close_to_pocket(
		ball.global_position,
		ball.radius,
		curse_seed_pocket_extra_clearance
	):
		return false
	return true


func _score_curse_seed_candidate(candidate: Ball, sink_position: Vector2) -> Dictionary:
	var position: Vector2 = candidate.global_position
	var playfield_rect: Rect2 = table.playfield_rect
	var table_span: float = maxf(playfield_rect.size.length(), 1.0)
	var nearest_rail_distance: float = _get_nearest_playfield_edge_distance(position, playfield_rect)
	var rail_score: float = 1.0 - clampf(nearest_rail_distance / maxf(curse_seed_rail_score_distance, 1.0), 0.0, 1.0)
	var clutter_count: int = _count_nearby_curse_seed_clutter(candidate)
	var clutter_score: float = clampf(float(clutter_count) / 3.0, 0.0, 1.0)
	var direct_line_blockers: int = _count_direct_line_blockers(candidate)
	var shield_score: float = 1.0 if direct_line_blockers > 0 else 0.0
	var easy_direct_penalty: float = 16.0 if direct_line_blockers <= 0 else 0.0
	var opposite_score: float = _get_opposite_cue_side_score(position, playfield_rect)
	var off_center_score: float = _get_off_center_score(position, playfield_rect)
	var cue_distance_score: float = _get_cue_distance_score(position, table_span)
	var sink_distance_score: float = clampf(position.distance_to(sink_position) / table_span, 0.0, 1.0)
	var center_penalty: float = 9.0 if off_center_score < 0.18 else 0.0
	var score: float = (
		rail_score * 34.0
		+ clutter_score * 21.0
		+ shield_score * 20.0
		+ opposite_score * 15.0
		+ off_center_score * 8.0
		+ cue_distance_score * 8.0
		+ sink_distance_score * 4.0
		- easy_direct_penalty
		- center_penalty
	)
	return {
		"ball": candidate,
		"score": score,
		"reason": _make_curse_seed_reason(
			rail_score,
			clutter_count,
			direct_line_blockers,
			opposite_score,
			off_center_score,
			cue_distance_score
		),
	}


func _transform_ball_to_curse_seed(ball: Ball) -> void:
	ball.become_anchor_curse_seed()
	ball.set_anchor_visuals_enabled(anchor_visuals_enabled)
	ball.set_anchor_field_visual_enabled(false)
	if table != null:
		table.queue_redraw()


func _register_curse_seed_state(seed_ball: Ball, warning_grace: float = 0.0) -> void:
	var state: CurseSeedState = CurseSeedState.new()
	state.seed_ball = seed_ball
	state.seed_ball_id = seed_ball.get_instance_id()
	state.warning_grace_remaining = maxf(warning_grace, 0.0)
	state.links = _acquire_curse_chain_links(seed_ball)
	curse_seed_states[state.seed_ball_id] = state
	last_chain_links_created = state.links.size()
	if state.links.is_empty():
		failed_chain_acquisitions += 1
	_update_max_active_curse_seed_count()


func _acquire_curse_chain_links(seed_ball: Ball) -> Array:
	var candidate_data: Array = _get_curse_chain_candidate_data(seed_ball)
	if candidate_data.is_empty():
		return []

	candidate_data.sort_custom(_sort_curse_chain_candidates)
	var selected_links: Array = []
	var link_limit: int = clampi(curse_chain_max_links, 1, 3)
	for candidate_entry in candidate_data:
		if selected_links.size() >= link_limit:
			break

		var link_data: Dictionary = candidate_entry
		var target_ball: Ball = link_data["ball"] as Ball
		if target_ball == null:
			continue

		var link: CurseChainLink = CurseChainLink.new()
		link.target_ball = target_ball
		link.target_ball_id = target_ball.get_instance_id()
		link.initial_distance = float(link_data["distance"])
		link.current_max_length = maxf(link.initial_distance, _get_curse_chain_touching_distance(seed_ball, target_ball))
		link.acquisition_score = float(link_data["score"])
		link.touching_at_acquisition = bool(link_data["touching"])
		selected_links.append(link)
	return selected_links


func _get_curse_chain_candidate_data(seed_ball: Ball) -> Array:
	var candidates: Array = []
	var has_non_touching_candidate := false
	for child in table.balls.get_children():
		var target_ball: Ball = child as Ball
		if not _is_curse_chain_candidate(seed_ball, target_ball):
			continue

		var distance: float = seed_ball.global_position.distance_to(target_ball.global_position)
		if distance > curse_chain_acquisition_radius:
			continue

		var touching_distance: float = _get_curse_chain_acquisition_touching_distance(seed_ball, target_ball)
		var is_touching: bool = distance <= touching_distance
		if not is_touching:
			has_non_touching_candidate = true

		candidates.append({
			"ball": target_ball,
			"distance": distance,
			"touching": is_touching,
			"score": _score_curse_chain_candidate(distance, is_touching),
		})

	if not has_non_touching_candidate:
		return candidates

	var filtered_candidates: Array = []
	for candidate_entry in candidates:
		if not bool(candidate_entry["touching"]):
			filtered_candidates.append(candidate_entry)
	return filtered_candidates


func _is_curse_chain_candidate(seed_ball: Ball, target_ball: Ball) -> bool:
	if table == null or seed_ball == null or target_ball == null:
		return false
	if target_ball == seed_ball or target_ball == table.cue_ball or target_ball == table.eight_ball:
		return false
	if target_ball.is_anchor_ball or target_ball.is_anchor_curse_seed:
		return false
	if not target_ball.is_gameplay_active():
		return false
	if target_ball.ball_type != Ball.BallType.OBJECT:
		return false
	return not _is_ball_already_chained(target_ball)


func _score_curse_chain_candidate(distance: float, is_touching: bool) -> float:
	var distance_ratio: float = 1.0 - clampf(distance / maxf(curse_chain_acquisition_radius, 1.0), 0.0, 1.0)
	var touching_penalty: float = 24.0 if is_touching else 0.0
	return distance_ratio * 100.0 - touching_penalty


func _sort_curse_chain_candidates(candidate_a: Dictionary, candidate_b: Dictionary) -> bool:
	return float(candidate_a["score"]) > float(candidate_b["score"])


func _is_ball_already_chained(target_ball: Ball) -> bool:
	var target_id: int = target_ball.get_instance_id()
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue
		for link_value in state.links:
			var link: CurseChainLink = link_value as CurseChainLink
			if _is_valid_curse_chain_link(state.seed_ball, link) and link.target_ball_id == target_id:
				return true
	return false


func _validate_curse_seed_chain_states() -> void:
	var expired_seed_ids: Array[int] = []
	for seed_id in curse_seed_states.keys():
		var state: CurseSeedState = curse_seed_states[seed_id] as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			if state != null:
				invalidated_chain_links += state.links.size()
			expired_seed_ids.append(int(seed_id))
			continue

		_validate_curse_seed_state_links(state)

	for seed_id in expired_seed_ids:
		curse_seed_states.erase(seed_id)


func _validate_curse_seed_state_links(state: CurseSeedState) -> void:
	var valid_links: Array = []
	for link_value in state.links:
		var link: CurseChainLink = link_value as CurseChainLink
		if _is_valid_curse_chain_link(state.seed_ball, link):
			valid_links.append(link)
		else:
			invalidated_chain_links += 1
	state.links = valid_links


func _are_all_curse_chain_links_touching_seed(state: CurseSeedState) -> bool:
	if not _is_valid_curse_seed_state(state) or state.links.is_empty():
		return false

	for link_value in state.links:
		var link: CurseChainLink = link_value as CurseChainLink
		if not _is_valid_curse_chain_link(state.seed_ball, link):
			return false
		if link.slide_active:
			return false
		if not _is_curse_chain_link_within_warning_contact(state.seed_ball, link.target_ball):
			return false
	return true


func _start_curse_warning_state(state: CurseSeedState) -> void:
	state.warning_active = true
	state.warning_timer_remaining = maxf(curse_warning_duration, 0.01)
	state.warning_paused = true
	state.spread_ready = false
	curse_warning_started += 1


func _reset_curse_warning_state(state: CurseSeedState) -> void:
	state.warning_active = false
	state.warning_timer_remaining = 0.0
	state.warning_paused = true
	state.spread_ready = false
	curse_warning_resets += 1


func _tick_curse_seed_warning_grace(state: CurseSeedState, delta: float) -> void:
	if state.warning_grace_remaining <= 0.0:
		return
	state.warning_grace_remaining = maxf(state.warning_grace_remaining - delta, 0.0)


func _spread_curse_seed_state(state: CurseSeedState) -> bool:
	if not _is_valid_curse_seed_state(state):
		curse_spread_blocked_skipped += 1
		return false
	if not state.spread_ready:
		return false

	var spread_targets: Array[Ball] = _get_touching_curse_spread_targets(state)
	if spread_targets.is_empty():
		_reset_curse_warning_state(state)
		curse_spread_blocked_skipped += 1
		return true

	var seed_ball: Ball = state.seed_ball
	var spread_origin: Vector2 = seed_ball.global_position
	var spread_target_positions: Array[Vector2] = _get_ball_positions(spread_targets)
	_release_seed_state_for_spread(state)
	seed_ball.clear_anchor_curse_seed()

	for target_ball in spread_targets:
		if _can_transform_ball_from_spread(target_ball):
			_transform_ball_to_curse_seed(target_ball)

	var created_seed_count := 0
	for target_ball in spread_targets:
		if is_curse_seed_ball(target_ball):
			_register_curse_seed_state(target_ball, curse_spread_new_seed_warning_grace)
			created_seed_count += 1

	if created_seed_count <= 0:
		curse_spread_blocked_skipped += 1
		return true

	curse_spread_events_total += 1
	curse_seeds_created += created_seed_count
	curse_seeds_created_by_spread += created_seed_count
	_update_max_active_curse_seed_count()
	_add_curse_spread_pulse(spread_origin, spread_target_positions)
	_request_curse_spread_table_feedback(spread_origin, created_seed_count)
	return true


func _get_touching_curse_spread_targets(state: CurseSeedState) -> Array[Ball]:
	var targets: Array[Ball] = []
	for link_value in state.links:
		var link: CurseChainLink = link_value as CurseChainLink
		if not _is_valid_curse_chain_link(state.seed_ball, link):
			continue
		if not _is_curse_chain_link_within_warning_contact(state.seed_ball, link.target_ball):
			continue
		targets.append(link.target_ball)
	return targets


func _get_ball_positions(target_balls: Array[Ball]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for target_ball in target_balls:
		if target_ball != null and is_instance_valid(target_ball):
			positions.append(target_ball.global_position)
	return positions


func _release_seed_state_for_spread(state: CurseSeedState) -> void:
	state.links.clear()
	state.warning_active = false
	state.warning_timer_remaining = 0.0
	state.warning_paused = true
	state.spread_ready = false
	state.warning_grace_remaining = 0.0
	curse_seed_states.erase(state.seed_ball_id)


func _can_transform_ball_from_spread(ball: Ball) -> bool:
	if table == null or ball == null or not is_instance_valid(ball):
		return false
	if ball == table.cue_ball or ball == table.eight_ball:
		return false
	if not ball.is_gameplay_active():
		return false
	if ball.ball_type != Ball.BallType.OBJECT:
		return false
	if ball.is_anchor_ball or ball.is_anchor_curse_seed:
		return false
	return true


func _request_curse_spread_table_feedback(spread_origin: Vector2, created_seed_count: int) -> void:
	if table == null or table.table_impact_shake_system == null:
		return
	table.table_impact_shake_system.request_anchor_spread_impact(spread_origin, created_seed_count)


func _try_collapse_curse_seed_from_cue_hit(ball_a: Ball, ball_b: Ball, seed_ball: Ball) -> bool:
	if table == null or seed_ball == null:
		return false
	if ball_a != table.cue_ball and ball_b != table.cue_ball:
		return false

	var state: CurseSeedState = _get_curse_seed_state_for_ball(seed_ball)
	if state == null:
		return _collapse_curse_seed_ball(seed_ball, "cue")

	state.cue_hit_count += 1
	var hits_required: int = maxi(curse_seed_cue_hits_to_collapse, 1)
	if state.cue_hit_count < hits_required:
		return false
	return _collapse_curse_seed_state(state, "cue")


func _try_collapse_curse_seed_from_cannon_hit(
	ball_a: Ball,
	ball_b: Ball,
	seed_ball: Ball,
	normal: Vector2
) -> bool:
	var cannon_ball: Ball = _get_collision_cannon_ball(ball_a, ball_b)
	if cannon_ball == null or seed_ball == null:
		return false

	var cannon_to_seed_normal: Vector2 = normal if cannon_ball == ball_a else -normal
	var impact_speed: float = maxf(cannon_ball.velocity.dot(cannon_to_seed_normal), 0.0)
	if impact_speed < curse_seed_cannon_collapse_min_speed:
		return false
	return _collapse_curse_seed_ball(seed_ball, "cannon")


func _get_collision_cannon_ball(ball_a: Ball, ball_b: Ball) -> Ball:
	if ball_a != null and ball_a.is_cannon_ball and ball_a.is_gameplay_active():
		return ball_a
	if ball_b != null and ball_b.is_cannon_ball and ball_b.is_gameplay_active():
		return ball_b
	return null


func _collapse_curse_seed_ball(seed_ball: Ball, reason: String) -> bool:
	if not is_curse_seed_ball(seed_ball):
		return false

	var state: CurseSeedState = _get_curse_seed_state_for_ball(seed_ball)
	if state != null:
		return _collapse_curse_seed_state(state, reason)

	_record_curse_seed_collapse(reason, 0)
	_add_curse_collapse_pulse(seed_ball.global_position)
	seed_ball.clear_anchor_curse_seed()
	if table != null:
		table.queue_redraw()
	return true


func _collapse_curse_seed_state(state: CurseSeedState, reason: String) -> bool:
	if not _is_valid_curse_seed_state(state):
		return false

	var released_links: int = _get_valid_curse_chain_link_count(state)
	var seed_ball: Ball = state.seed_ball
	state.links.clear()
	state.warning_active = false
	state.warning_timer_remaining = 0.0
	state.warning_paused = true
	state.spread_ready = false
	_record_curse_seed_collapse(reason, released_links)
	_add_curse_collapse_pulse(seed_ball.global_position)
	curse_seed_states.erase(state.seed_ball_id)
	seed_ball.clear_anchor_curse_seed()
	if table != null:
		table.queue_redraw()
	return true


func _record_curse_seed_collapse(reason: String, released_links: int) -> void:
	curse_seeds_collapsed_total += 1
	curse_chains_released_by_collapse += released_links
	match reason:
		"cue":
			curse_seeds_collapsed_by_cue += 1
		"powder":
			curse_seeds_collapsed_by_powder += 1
		"cannon":
			curse_seeds_collapsed_by_cannon += 1
		"chained_ball_pocketed":
			curse_seeds_collapsed_by_chained_ball_pocket += 1


func _get_curse_seed_state_for_ball(seed_ball: Ball) -> CurseSeedState:
	if seed_ball == null:
		return null

	var seed_id: int = seed_ball.get_instance_id()
	if not curse_seed_states.has(seed_id):
		return null
	return curse_seed_states[seed_id] as CurseSeedState


func _get_curse_seed_state_for_chained_ball(target_ball: Ball) -> CurseSeedState:
	if target_ball == null:
		return null

	var target_id: int = target_ball.get_instance_id()
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue

		for link_value in state.links:
			var link: CurseChainLink = link_value as CurseChainLink
			if link != null and link.target_ball_id == target_id:
				return state

	return null


func _get_valid_curse_chain_link_count(state: CurseSeedState) -> int:
	if not _is_valid_curse_seed_state(state):
		return 0

	var valid_count := 0
	for link_value in state.links:
		var link: CurseChainLink = link_value as CurseChainLink
		if _is_valid_curse_chain_link(state.seed_ball, link):
			valid_count += 1
	return valid_count


func _is_valid_curse_seed_state(state: CurseSeedState) -> bool:
	if state == null or not is_instance_valid(state.seed_ball):
		return false
	return is_curse_seed_ball(state.seed_ball)


func _is_valid_curse_chain_link(seed_ball: Ball, link: CurseChainLink) -> bool:
	if seed_ball == null or link == null or not is_instance_valid(link.target_ball):
		return false
	return _is_curse_chain_candidate_for_validation(seed_ball, link.target_ball)


func _is_curse_chain_candidate_for_validation(seed_ball: Ball, target_ball: Ball) -> bool:
	if table == null or target_ball == null:
		return false
	if target_ball == seed_ball or target_ball == table.cue_ball or target_ball == table.eight_ball:
		return false
	if target_ball.is_anchor_ball or target_ball.is_anchor_curse_seed:
		return false
	if not target_ball.is_gameplay_active():
		return false
	return target_ball.ball_type == Ball.BallType.OBJECT


func _apply_curse_chain_tighten_step(state: CurseSeedState, link: CurseChainLink) -> void:
	var seed_ball: Ball = state.seed_ball
	var target_ball: Ball = link.target_ball
	var result: Dictionary = _get_curse_chain_tighten_step(state, link)
	if not bool(result["valid"]):
		_record_chain_tighten_skip(str(result["reason"]))
		return

	var length_delta: float = float(result["length_delta"])
	if length_delta <= 0.0:
		_record_chain_tighten_skip(str(result["reason"]))
		return

	var new_max_length: float = float(result["new_max_length"])
	var slide_distance: float = float(result["slide_distance"])
	if slide_distance > 0.0:
		var slide_target_position: Vector2 = result["position"]
		if not _start_curse_chain_tighten_slide(link, slide_target_position, slide_distance, new_max_length):
			return
	else:
		link.current_max_length = new_max_length
		target_ball.velocity = Vector2.ZERO
		target_ball.suppress_trail_for(curse_chain_tighten_trail_suppression)

	chain_tighten_steps_applied += 1
	chain_tighten_total_distance += length_delta
	chain_tighten_last_distance = length_delta


func _get_curse_chain_tighten_step(state: CurseSeedState, link: CurseChainLink) -> Dictionary:
	var seed_ball: Ball = state.seed_ball
	var target_ball: Ball = link.target_ball
	if seed_ball == null or target_ball == null:
		return _make_invalid_tighten_result("invalid link")
	if seed_ball.is_moving():
		return _make_invalid_tighten_result("seed moving")
	if target_ball.is_moving():
		return _make_invalid_tighten_result("target moving")
	if _is_position_pocket_dangerous(target_ball.global_position, target_ball):
		return _make_invalid_tighten_result("pocket danger")

	var offset: Vector2 = seed_ball.global_position - target_ball.global_position
	var distance: float = offset.length()
	var touching_distance: float = _get_curse_chain_touching_distance(seed_ball, target_ball)
	if distance <= touching_distance:
		return _make_invalid_tighten_result("touching seed")

	var direction: Vector2 = offset / distance
	var current_max_length: float = maxf(link.current_max_length, touching_distance)
	var new_max_length: float = maxf(current_max_length - curse_chain_tighten_step_distance, touching_distance)
	var length_delta: float = current_max_length - new_max_length
	if length_delta <= 0.0:
		return _make_invalid_tighten_result("touching seed")

	var desired_distance: float = minf(distance, new_max_length)
	var slide_distance: float = maxf(distance - desired_distance, 0.0)
	if slide_distance <= 0.0:
		return {
			"valid": true,
			"position": target_ball.global_position,
			"length_delta": length_delta,
			"slide_distance": 0.0,
			"new_max_length": new_max_length,
			"reason": "tightened length",
		}

	var candidate_distances: Array[float] = [
		desired_distance,
		lerp(distance, desired_distance, 0.5),
		lerp(distance, desired_distance, 0.25),
	]
	for candidate_distance in candidate_distances:
		var candidate_position: Vector2 = seed_ball.global_position - direction * candidate_distance
		var same_seed_blocker: CurseChainLink = _get_same_seed_tighten_blocker(state, link, candidate_distance, direction)
		if same_seed_blocker != null:
			var deconflicted_result: Dictionary = _try_get_deconflicted_tighten_result(
				state,
				link,
				same_seed_blocker,
				direction,
				distance,
				candidate_distance,
				current_max_length,
				touching_distance
			)
			if not deconflicted_result.is_empty():
				return deconflicted_result
			continue

		if _is_tighten_position_safe(seed_ball, target_ball, candidate_position):
			var actual_slide_distance: float = target_ball.global_position.distance_to(candidate_position)
			var actual_new_max_length: float = maxf(candidate_distance, touching_distance)
			return {
				"valid": true,
				"position": candidate_position,
				"length_delta": current_max_length - actual_new_max_length,
				"slide_distance": actual_slide_distance,
				"new_max_length": actual_new_max_length,
				"reason": "tightened",
			}

		chain_deconfliction_skipped += 1
		chain_deconfliction_last_reason = "no same-seed blocker"

	return _make_invalid_tighten_result("blocked")


func _make_invalid_tighten_result(reason: String) -> Dictionary:
	return {
		"valid": false,
		"position": Vector2.ZERO,
		"length_delta": 0.0,
		"slide_distance": 0.0,
		"new_max_length": 0.0,
		"reason": reason,
	}


func _try_get_deconflicted_tighten_result(
	state: CurseSeedState,
	link: CurseChainLink,
	blocker_link: CurseChainLink,
	inward_direction: Vector2,
	_current_distance: float,
	candidate_distance: float,
	current_max_length: float,
	touching_distance: float
) -> Dictionary:
	var seed_ball: Ball = state.seed_ball
	var target_ball: Ball = link.target_ball
	chain_deconfliction_attempts += 1
	var outward_direction: Vector2 = -inward_direction
	var angles: Array[float] = _get_deconfliction_candidate_angles(link, blocker_link)
	for angle in angles:
		var lane_direction: Vector2 = outward_direction.rotated(angle)
		var candidate_position: Vector2 = seed_ball.global_position + lane_direction * candidate_distance
		if not _is_tighten_position_safe(seed_ball, target_ball, candidate_position):
			continue
		if _is_same_seed_link_blocking_position(state, link, candidate_position):
			continue

		var actual_slide_distance: float = target_ball.global_position.distance_to(candidate_position)
		var actual_new_max_length: float = maxf(candidate_distance, touching_distance)
		chain_deconfliction_successes += 1
		chain_deconfliction_last_reason = "lane found"
		return {
			"valid": true,
			"position": candidate_position,
			"length_delta": current_max_length - actual_new_max_length,
			"slide_distance": actual_slide_distance,
			"new_max_length": actual_new_max_length,
			"reason": "deconflicted",
		}

	chain_deconfliction_blocked += 1
	chain_deconfliction_last_reason = "lanes blocked"
	return {}


func _get_same_seed_tighten_blocker(
	state: CurseSeedState,
	link: CurseChainLink,
	candidate_distance: float,
	inward_direction: Vector2
) -> CurseChainLink:
	var seed_ball: Ball = state.seed_ball
	var target_ball: Ball = link.target_ball
	var candidate_position: Vector2 = seed_ball.global_position - inward_direction * candidate_distance
	for other_link_value in state.links:
		var other_link: CurseChainLink = other_link_value as CurseChainLink
		if other_link == link or not _is_valid_curse_chain_link(seed_ball, other_link):
			continue

		var blocker_ball: Ball = other_link.target_ball
		var minimum_distance: float = target_ball.radius + blocker_ball.radius + curse_chain_tighten_overlap_clearance
		if candidate_position.distance_squared_to(blocker_ball.global_position) <= minimum_distance * minimum_distance:
			return other_link
		if _distance_to_segment(blocker_ball.global_position, target_ball.global_position, candidate_position) <= minimum_distance:
			return other_link
	return null


func _is_same_seed_link_blocking_position(
	state: CurseSeedState,
	link: CurseChainLink,
	candidate_position: Vector2
) -> bool:
	var seed_ball: Ball = state.seed_ball
	var target_ball: Ball = link.target_ball
	for other_link_value in state.links:
		var other_link: CurseChainLink = other_link_value as CurseChainLink
		if other_link == link or not _is_valid_curse_chain_link(seed_ball, other_link):
			continue

		var blocker_ball: Ball = other_link.target_ball
		var minimum_distance: float = target_ball.radius + blocker_ball.radius + curse_chain_tighten_overlap_clearance
		if candidate_position.distance_squared_to(blocker_ball.global_position) <= minimum_distance * minimum_distance:
			return true
		if _distance_to_segment(blocker_ball.global_position, target_ball.global_position, candidate_position) <= minimum_distance:
			return true
	return false


func _get_deconfliction_candidate_angles(link: CurseChainLink, blocker_link: CurseChainLink) -> Array[float]:
	var base_angle: float = deg_to_rad(maxf(curse_chain_deconflict_angle_degrees, 1.0))
	var step_angle: float = deg_to_rad(maxf(curse_chain_deconflict_angle_step_degrees, 1.0))
	var side: float = 1.0 if link.target_ball_id < blocker_link.target_ball_id else -1.0
	return [
		side * base_angle,
		-side * base_angle,
		side * (base_angle + step_angle),
		-side * (base_angle + step_angle),
		side * (base_angle + step_angle * 2.0),
		-side * (base_angle + step_angle * 2.0),
	]


func _start_curse_chain_tighten_slide(
	link: CurseChainLink,
	target_position: Vector2,
	slide_distance: float,
	target_max_length: float
) -> bool:
	var target_ball: Ball = link.target_ball
	if target_ball == null:
		_record_chain_tighten_skip("invalid slide")
		chain_tighten_slides_blocked += 1
		return false

	link.slide_active = true
	link.slide_elapsed = 0.0
	link.slide_duration = maxf(curse_chain_tighten_slide_duration, 0.001)
	link.slide_start_position = target_ball.global_position
	link.slide_target_position = target_position
	link.slide_target_max_length = target_max_length
	target_ball.velocity = Vector2.ZERO
	target_ball.suppress_trail_for(maxf(curse_chain_tighten_trail_suppression, link.slide_duration))
	chain_tighten_slides_started += 1
	if slide_distance <= 0.001:
		link.current_max_length = minf(link.current_max_length, target_max_length)
		_finish_curse_chain_slide(link, null)
	return true


func _update_curse_chain_slide(seed_ball: Ball, link: CurseChainLink, delta: float) -> bool:
	if not link.slide_active:
		return false

	var target_ball: Ball = link.target_ball
	if target_ball == null or not is_instance_valid(target_ball) or not target_ball.is_gameplay_active():
		link.slide_active = false
		chain_tighten_slides_blocked += 1
		_record_chain_tighten_skip("slide target invalid")
		return false

	link.slide_elapsed += delta
	var ratio: float = clampf(link.slide_elapsed / maxf(link.slide_duration, 0.001), 0.0, 1.0)
	var eased_ratio: float = 1.0 - pow(1.0 - ratio, 3.0)
	target_ball.global_position = link.slide_start_position.lerp(link.slide_target_position, eased_ratio)
	target_ball.velocity = Vector2.ZERO
	target_ball.suppress_trail_for(curse_chain_tighten_trail_suppression)
	_update_sliding_chain_max_length(seed_ball, link)
	if ratio >= 1.0:
		_finish_curse_chain_slide(link, seed_ball)
	return true


func _finish_curse_chain_slide(link: CurseChainLink, seed_ball: Ball) -> void:
	if link.target_ball != null and is_instance_valid(link.target_ball):
		link.target_ball.global_position = link.slide_target_position
		link.target_ball.velocity = Vector2.ZERO
		link.target_ball.suppress_trail_for(curse_chain_tighten_trail_suppression)
	if seed_ball != null and is_instance_valid(seed_ball):
		link.current_max_length = minf(link.current_max_length, link.slide_target_max_length)
	link.slide_active = false
	link.slide_elapsed = 0.0
	chain_tighten_slides_completed += 1


func _update_sliding_chain_max_length(seed_ball: Ball, link: CurseChainLink) -> void:
	if seed_ball == null or link.target_ball == null:
		return

	var current_distance: float = seed_ball.global_position.distance_to(link.target_ball.global_position)
	var sliding_max_length: float = maxf(current_distance, link.slide_target_max_length)
	link.current_max_length = minf(link.current_max_length, sliding_max_length)


func _enforce_curse_chain_constraint(seed_ball: Ball, link: CurseChainLink) -> bool:
	var target_ball: Ball = link.target_ball
	if seed_ball == null or target_ball == null:
		return false

	var max_length: float = maxf(link.current_max_length, _get_curse_chain_touching_distance(seed_ball, target_ball))
	var offset: Vector2 = target_ball.global_position - seed_ball.global_position
	var distance: float = offset.length()
	if distance <= max_length or distance <= 0.001:
		return false

	var direction: Vector2 = offset / distance
	var constrained_position: Vector2 = _get_constraint_clamp_position(seed_ball, target_ball, direction, max_length)
	target_ball.global_position = constrained_position
	_remove_outward_chain_velocity(target_ball, direction)
	target_ball.suppress_trail_for(curse_chain_tighten_trail_suppression)
	chain_constraint_clamps_applied += 1
	return true


func _get_constraint_clamp_position(
	seed_ball: Ball,
	target_ball: Ball,
	direction: Vector2,
	max_length: float
) -> Vector2:
	var touching_distance: float = _get_curse_chain_touching_distance(seed_ball, target_ball)
	var candidate_lengths: Array[float] = [
		max_length,
		lerp(max_length, touching_distance, 0.25),
		lerp(max_length, touching_distance, 0.50),
		touching_distance,
	]
	for candidate_length in candidate_lengths:
		var candidate_position: Vector2 = seed_ball.global_position + direction * candidate_length
		if not _is_position_pocket_dangerous(candidate_position, target_ball):
			return candidate_position
	return seed_ball.global_position + direction * max_length


func _remove_outward_chain_velocity(target_ball: Ball, radial_direction: Vector2) -> void:
	var outward_speed: float = target_ball.velocity.dot(radial_direction)
	if outward_speed > 0.0:
		target_ball.velocity -= radial_direction * outward_speed


func _is_tighten_position_safe(seed_ball: Ball, target_ball: Ball, candidate_position: Vector2) -> bool:
	if table == null:
		return false

	var safe_rect: Rect2 = table.playfield_rect.grow(-target_ball.radius)
	if safe_rect.size == Vector2.ZERO or not safe_rect.has_point(candidate_position):
		return false
	if _is_position_pocket_dangerous(candidate_position, target_ball):
		return false
	return not _is_tighten_position_blocked(seed_ball, target_ball, candidate_position)


func _is_position_pocket_dangerous(position: Vector2, target_ball: Ball) -> bool:
	if table == null or target_ball == null:
		return true
	return table.pocket_system.is_position_too_close_to_pocket(
		position,
		target_ball.radius,
		curse_chain_tighten_pocket_clearance
	)


func _is_tighten_position_blocked(seed_ball: Ball, target_ball: Ball, candidate_position: Vector2) -> bool:
	for child in table.balls.get_children():
		var other_ball: Ball = child as Ball
		if other_ball == null or other_ball == seed_ball or other_ball == target_ball:
			continue
		if not other_ball.is_gameplay_active():
			continue

		var minimum_distance: float = target_ball.radius + other_ball.radius + curse_chain_tighten_overlap_clearance
		if candidate_position.distance_squared_to(other_ball.global_position) < minimum_distance * minimum_distance:
			return true
	return false


func _record_chain_tighten_skip(reason: String) -> void:
	chain_tighten_steps_skipped += 1
	chain_tighten_last_skip_reason = reason
	chain_tighten_skip_reasons[reason] = int(chain_tighten_skip_reasons.get(reason, 0)) + 1


func _get_curse_chain_touching_distance(seed_ball: Ball, target_ball: Ball) -> float:
	return seed_ball.radius + target_ball.radius


func _get_curse_chain_acquisition_touching_distance(seed_ball: Ball, target_ball: Ball) -> float:
	return _get_curse_chain_touching_distance(seed_ball, target_ball) + curse_chain_touching_buffer


func _get_average_chain_tighten_distance() -> float:
	if chain_tighten_steps_applied <= 0:
		return 0.0
	return chain_tighten_total_distance / float(chain_tighten_steps_applied)


func _get_touching_curse_chain_link_count() -> int:
	var touching_count := 0
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue

		for link_value in state.links:
			var link: CurseChainLink = link_value as CurseChainLink
			if not _is_valid_curse_chain_link(state.seed_ball, link):
				continue
			var distance: float = state.seed_ball.global_position.distance_to(link.target_ball.global_position)
			if distance <= _get_curse_chain_touching_distance(state.seed_ball, link.target_ball):
				touching_count += 1
	return touching_count


func _is_curse_chain_link_within_warning_contact(seed_ball: Ball, target_ball: Ball) -> bool:
	if seed_ball == null or target_ball == null:
		return false
	var touching_distance: float = _get_curse_chain_touching_distance(seed_ball, target_ball)
	var threshold: float = touching_distance + maxf(curse_warning_touch_epsilon, 0.0)
	return seed_ball.global_position.distance_squared_to(target_ball.global_position) <= threshold * threshold


func _get_curse_warning_seed_count() -> int:
	var warning_count := 0
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if _is_valid_curse_seed_state(state) and state.warning_active:
			warning_count += 1
	return warning_count


func _get_curse_spread_ready_count() -> int:
	var ready_count := 0
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if _is_valid_curse_seed_state(state) and state.spread_ready:
			ready_count += 1
	return ready_count


func _get_curse_new_seed_grace_count() -> int:
	var grace_count := 0
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if _is_valid_curse_seed_state(state) and state.warning_grace_remaining > 0.0:
			grace_count += 1
	return grace_count


func _update_max_active_curse_seed_count() -> void:
	max_active_curse_seeds = maxi(max_active_curse_seeds, _get_active_curse_seed_count())


func _get_lowest_curse_warning_timer_remaining() -> float:
	var lowest_remaining: float = INF
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue
		if not state.warning_active and not state.spread_ready:
			continue
		lowest_remaining = minf(lowest_remaining, state.warning_timer_remaining)
	if is_inf(lowest_remaining):
		return 0.0
	return lowest_remaining


func _make_curse_warning_timer_state_text() -> String:
	var has_running := false
	var has_paused := false
	var has_ready := false
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue
		if state.spread_ready:
			has_ready = true
		elif state.warning_active and state.warning_paused:
			has_paused = true
		elif state.warning_active:
			has_running = true

	if has_ready:
		return "ready"
	if has_running:
		return "running"
	if has_paused:
		return "paused"
	return "none"


func _make_chain_tighten_skip_reason_text() -> String:
	if chain_tighten_skip_reasons.is_empty():
		return "none"

	var parts: Array[String] = []
	for reason in chain_tighten_skip_reasons.keys():
		parts.append("%s:%s" % [reason, chain_tighten_skip_reasons[reason]])
	return " | ".join(parts)


func _get_total_curse_chain_link_count() -> int:
	var link_count := 0
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if _is_valid_curse_seed_state(state):
			link_count += state.links.size()
	return link_count


func _make_curse_chain_links_per_seed_text() -> String:
	var seed_parts: Array[String] = []
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue
		seed_parts.append("#%s:%s" % [state.seed_ball.ball_number, state.links.size()])
	if seed_parts.is_empty():
		return "none"
	return " | ".join(seed_parts)


func _make_curse_chain_max_lengths_text() -> String:
	var length_parts: Array[String] = []
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if not _is_valid_curse_seed_state(state):
			continue

		for link_value in state.links:
			var link: CurseChainLink = link_value as CurseChainLink
			if not _is_valid_curse_chain_link(state.seed_ball, link):
				continue
			length_parts.append("#%s>%s:%.0f" % [
				state.seed_ball.ball_number,
				link.target_ball.ball_number,
				link.current_max_length,
			])
	if length_parts.is_empty():
		return "none"
	return " | ".join(length_parts)


func _draw_curse_chain(
	canvas: Node2D,
	seed_ball: Ball,
	target_ball: Ball,
	visual_time: float,
	link_index: int
) -> void:
	var start_position: Vector2 = canvas.to_local(seed_ball.global_position)
	var end_position: Vector2 = canvas.to_local(target_ball.global_position)
	var points: PackedVector2Array = _make_curse_chain_points(start_position, end_position, visual_time, link_index)
	var pulse: float = 0.72 + sin(visual_time * 3.1 + float(link_index)) * 0.16
	canvas.draw_polyline(points, CURSE_CHAIN_SHADOW_COLOR, 5.2)
	canvas.draw_polyline(points, _with_alpha(CURSE_CHAIN_GLOW_COLOR, CURSE_CHAIN_GLOW_COLOR.a * pulse), 3.6)
	canvas.draw_polyline(points, _with_alpha(CURSE_CHAIN_CORE_COLOR, CURSE_CHAIN_CORE_COLOR.a * pulse), 1.45)
	_draw_curse_chain_marks(canvas, points, visual_time, link_index)


func _make_curse_chain_points(
	start_position: Vector2,
	end_position: Vector2,
	visual_time: float,
	link_index: int
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var offset: Vector2 = end_position - start_position
	var distance: float = offset.length()
	if distance <= 1.0:
		points.append(start_position)
		points.append(end_position)
		return points

	var normal: Vector2 = Vector2(-offset.y, offset.x) / distance
	var phase: float = visual_time * 1.65 + float(link_index) * 0.73
	var sag: float = minf(distance * 0.08, 18.0)
	var sway: float = sin(phase) * minf(distance * 0.025, 5.0)
	for point_index in range(CURSE_CHAIN_POINT_COUNT):
		var t: float = float(point_index) / float(CURSE_CHAIN_POINT_COUNT - 1)
		var wave: float = sin(t * PI) * (sag + sway)
		var ripple: float = sin(t * TAU * 2.0 + phase) * 1.8
		points.append(start_position.lerp(end_position, t) + normal * (wave + ripple))
	return points


func _draw_curse_chain_marks(
	canvas: Node2D,
	points: PackedVector2Array,
	visual_time: float,
	link_index: int
) -> void:
	if points.size() < 2:
		return

	var pulse: float = 0.78 + sin(visual_time * 4.0 + float(link_index)) * 0.14
	for mark_index in range(CURSE_CHAIN_MARK_COUNT):
		var point_index: int = 1 + int(round(float(mark_index) * float(points.size() - 3) / maxf(float(CURSE_CHAIN_MARK_COUNT - 1), 1.0)))
		var mark_position: Vector2 = points[clampi(point_index, 1, points.size() - 2)]
		canvas.draw_circle(mark_position, 2.25, _with_alpha(CURSE_CHAIN_LINK_COLOR, CURSE_CHAIN_LINK_COLOR.a * pulse))


func _draw_curse_warning_presentation(canvas: Node2D, state: CurseSeedState, visual_time: float) -> void:
	if not state.warning_active and not state.spread_ready:
		return
	if not _is_valid_curse_seed_state(state):
		return

	var seed_ball: Ball = state.seed_ball
	var seed_position: Vector2 = canvas.to_local(seed_ball.global_position)
	var pulse: float = 0.5 + sin(visual_time * 6.4 + float(state.seed_ball_id % 31)) * 0.5
	var glow_radius: float = seed_ball.radius + 18.0 + pulse * 7.0
	var ring_radius: float = seed_ball.radius + 9.0 + pulse * 2.5
	var glow_color: Color = CURSE_WARNING_GLOW_COLOR
	var ring_color: Color = CURSE_WARNING_RING_COLOR
	var text_color: Color = CURSE_WARNING_TEXT_COLOR
	var timer_text: String = "%.1f" % state.warning_timer_remaining
	if state.spread_ready:
		timer_text = "READY"
		glow_color = _with_alpha(CURSE_WARNING_READY_COLOR, 0.30 + pulse * 0.16)
		ring_color = CURSE_WARNING_READY_COLOR
		text_color = CURSE_WARNING_READY_COLOR
	elif state.warning_paused:
		ring_color = CURSE_WARNING_PAUSED_COLOR
		text_color = CURSE_WARNING_PAUSED_COLOR
		glow_color = _with_alpha(CURSE_WARNING_GLOW_COLOR, 0.18 + pulse * 0.08)

	canvas.draw_circle(seed_position, glow_radius, glow_color)
	canvas.draw_arc(seed_position, ring_radius, -PI * 0.5, PI * 1.5, 64, _with_alpha(ring_color, 0.34), 5.6)
	canvas.draw_arc(seed_position, ring_radius, -PI * 0.5, PI * 1.5, 64, ring_color, 2.2)
	_draw_curse_warning_text(canvas, seed_position, seed_ball.radius, timer_text, text_color)


func _draw_curse_warning_text(
	canvas: Node2D,
	seed_position: Vector2,
	seed_radius: float,
	text: String,
	color: Color
) -> void:
	var text_position: Vector2 = seed_position + Vector2(-CURSE_WARNING_TEXT_WIDTH * 0.5, -seed_radius - 24.0)
	var shadow_position: Vector2 = text_position + Vector2(1.5, 1.5)
	canvas.draw_string(
		CURSE_WARNING_FONT,
		shadow_position,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		CURSE_WARNING_TEXT_WIDTH,
		CURSE_WARNING_FONT_SIZE,
		Color(0.02, 0.03, 0.04, 0.74)
	)
	canvas.draw_string(
		CURSE_WARNING_FONT,
		text_position,
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		CURSE_WARNING_TEXT_WIDTH,
		CURSE_WARNING_FONT_SIZE,
		color
	)


func _add_curse_collapse_pulse(position: Vector2) -> void:
	curse_collapse_pulses.append({
		"position": position,
		"start_time": float(Time.get_ticks_msec()) * 0.001,
	})


func _prune_curse_collapse_pulses() -> void:
	if curse_collapse_pulses.is_empty():
		return

	var visual_time: float = float(Time.get_ticks_msec()) * 0.001
	var active_pulses: Array[Dictionary] = []
	for pulse_value in curse_collapse_pulses:
		var pulse_data: Dictionary = pulse_value
		var elapsed: float = visual_time - float(pulse_data.get("start_time", visual_time))
		if elapsed <= CURSE_COLLAPSE_PULSE_DURATION:
			active_pulses.append(pulse_data)
	curse_collapse_pulses = active_pulses


func _draw_curse_collapse_pulses(canvas: Node2D, visual_time: float) -> void:
	if curse_collapse_pulses.is_empty():
		return

	for pulse_value in curse_collapse_pulses:
		var pulse_data: Dictionary = pulse_value
		var elapsed: float = visual_time - float(pulse_data.get("start_time", visual_time))
		var ratio: float = clampf(elapsed / CURSE_COLLAPSE_PULSE_DURATION, 0.0, 1.0)
		var fade: float = 1.0 - ratio
		var pulse_global_position := Vector2.ZERO
		if pulse_data.has("position"):
			pulse_global_position = pulse_data["position"] as Vector2
		var pulse_position: Vector2 = canvas.to_local(pulse_global_position)
		var radius: float = lerpf(22.0, 58.0, ratio)
		canvas.draw_circle(pulse_position, radius * 0.72, _with_alpha(CURSE_COLLAPSE_GLOW_COLOR, CURSE_COLLAPSE_GLOW_COLOR.a * fade))
		canvas.draw_arc(pulse_position, radius, 0.0, TAU, 64, _with_alpha(CURSE_COLLAPSE_RING_COLOR, CURSE_COLLAPSE_RING_COLOR.a * fade), 3.0)


func _add_curse_spread_pulse(origin: Vector2, target_positions: Array[Vector2]) -> void:
	curse_spread_pulses.append({
		"position": origin,
		"targets": target_positions,
		"start_time": float(Time.get_ticks_msec()) * 0.001,
	})


func _prune_curse_spread_pulses() -> void:
	if curse_spread_pulses.is_empty():
		return

	var visual_time: float = float(Time.get_ticks_msec()) * 0.001
	var active_pulses: Array[Dictionary] = []
	for pulse_value in curse_spread_pulses:
		var pulse_data: Dictionary = pulse_value
		var elapsed: float = visual_time - float(pulse_data.get("start_time", visual_time))
		if elapsed <= CURSE_SPREAD_PULSE_DURATION:
			active_pulses.append(pulse_data)
	curse_spread_pulses = active_pulses


func _draw_curse_spread_pulses(canvas: Node2D, visual_time: float) -> void:
	if curse_spread_pulses.is_empty():
		return

	for pulse_value in curse_spread_pulses:
		var pulse_data: Dictionary = pulse_value
		var elapsed: float = visual_time - float(pulse_data.get("start_time", visual_time))
		var ratio: float = clampf(elapsed / CURSE_SPREAD_PULSE_DURATION, 0.0, 1.0)
		var fade: float = 1.0 - ratio
		var origin_global_position := Vector2.ZERO
		if pulse_data.has("position"):
			origin_global_position = pulse_data["position"] as Vector2
		var origin_position: Vector2 = canvas.to_local(origin_global_position)
		var radius: float = lerpf(28.0, 78.0, ratio)
		canvas.draw_circle(origin_position, radius * 0.62, _with_alpha(CURSE_SPREAD_GLOW_COLOR, CURSE_SPREAD_GLOW_COLOR.a * fade))
		canvas.draw_arc(origin_position, radius, 0.0, TAU, 72, _with_alpha(CURSE_SPREAD_RING_COLOR, CURSE_SPREAD_RING_COLOR.a * fade), 3.4)
		_draw_curse_spread_snap_lines(canvas, pulse_data, origin_position, ratio, fade)


func _draw_curse_spread_snap_lines(
	canvas: Node2D,
	pulse_data: Dictionary,
	origin_position: Vector2,
	ratio: float,
	fade: float
) -> void:
	if not pulse_data.has("targets"):
		return

	var target_positions: Array = pulse_data["targets"]
	for target_value in target_positions:
		if not (target_value is Vector2):
			continue
		var target_global_position: Vector2 = target_value
		var target_position: Vector2 = canvas.to_local(target_global_position)
		var snapped_start: Vector2 = origin_position.lerp(target_position, ratio * 0.18)
		var snapped_end: Vector2 = origin_position.lerp(target_position, 0.72 + ratio * 0.28)
		canvas.draw_line(snapped_start, snapped_end, _with_alpha(CURSE_SPREAD_LINE_COLOR, CURSE_SPREAD_LINE_COLOR.a * fade), 3.0)
		canvas.draw_circle(snapped_end, 3.8, _with_alpha(CURSE_SPREAD_RING_COLOR, CURSE_SPREAD_RING_COLOR.a * fade))


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _get_active_curse_seed_count() -> int:
	var seed_count := 0
	for state_value in curse_seed_states.values():
		var state: CurseSeedState = state_value as CurseSeedState
		if _is_valid_curse_seed_state(state):
			seed_count += 1
	return seed_count


func _get_nearest_playfield_edge_distance(position: Vector2, playfield_rect: Rect2) -> float:
	if playfield_rect.size == Vector2.ZERO:
		return INF

	return minf(
		minf(position.x - playfield_rect.position.x, playfield_rect.end.x - position.x),
		minf(position.y - playfield_rect.position.y, playfield_rect.end.y - position.y)
	)


func _count_nearby_curse_seed_clutter(candidate: Ball) -> int:
	var clutter_count := 0
	var radius_squared: float = curse_seed_clutter_radius * curse_seed_clutter_radius
	for child in table.balls.get_children():
		var other_ball: Ball = child as Ball
		if other_ball == null or other_ball == candidate:
			continue
		if not other_ball.is_gameplay_active():
			continue
		if candidate.global_position.distance_squared_to(other_ball.global_position) <= radius_squared:
			clutter_count += 1
	return clutter_count


func _count_direct_line_blockers(candidate: Ball) -> int:
	if table == null or table.cue_ball == null:
		return 0

	var cue_position: Vector2 = table.cue_ball.global_position
	var target_position: Vector2 = candidate.global_position
	var segment: Vector2 = target_position - cue_position
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.001:
		return 0

	var blocker_count := 0
	for child in table.balls.get_children():
		var blocker: Ball = child as Ball
		if not _can_block_curse_seed_direct_line(blocker, candidate):
			continue

		var projection_ratio: float = (blocker.global_position - cue_position).dot(segment) / segment_length_squared
		if projection_ratio <= 0.08 or projection_ratio >= 0.92:
			continue

		var distance_to_line: float = _distance_to_segment(blocker.global_position, cue_position, target_position)
		var blocker_radius: float = blocker.radius + candidate.radius + curse_seed_direct_line_clearance
		if distance_to_line <= blocker_radius:
			blocker_count += 1
	return blocker_count


func _can_block_curse_seed_direct_line(blocker: Ball, candidate: Ball) -> bool:
	if blocker == null or blocker == candidate:
		return false
	if blocker == table.cue_ball or blocker == table.eight_ball:
		return false
	return blocker.is_gameplay_active()


func _distance_to_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment: Vector2 = segment_end - segment_start
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.001:
		return point.distance_to(segment_start)

	var projection_ratio: float = clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point: Vector2 = segment_start + segment * projection_ratio
	return point.distance_to(closest_point)


func _get_opposite_cue_side_score(position: Vector2, playfield_rect: Rect2) -> float:
	if table == null or table.cue_ball == null or playfield_rect.size == Vector2.ZERO:
		return 0.0

	var center: Vector2 = playfield_rect.get_center()
	var cue_offset: Vector2 = table.cue_ball.global_position - center
	var candidate_offset: Vector2 = position - center
	if cue_offset.length_squared() <= 0.001 or candidate_offset.length_squared() <= 0.001:
		return 0.0

	var opposite_dot: float = -cue_offset.normalized().dot(candidate_offset.normalized())
	return clampf((opposite_dot + 1.0) * 0.5, 0.0, 1.0)


func _get_off_center_score(position: Vector2, playfield_rect: Rect2) -> float:
	if playfield_rect.size == Vector2.ZERO:
		return 0.0

	var half_diagonal: float = maxf(playfield_rect.size.length() * 0.5, 1.0)
	return clampf(position.distance_to(playfield_rect.get_center()) / half_diagonal, 0.0, 1.0)


func _get_cue_distance_score(position: Vector2, table_span: float) -> float:
	if table == null or table.cue_ball == null:
		return 0.0
	return clampf(position.distance_to(table.cue_ball.global_position) / table_span, 0.0, 1.0)


func _make_curse_seed_reason(
	rail_score: float,
	clutter_count: int,
	direct_line_blockers: int,
	opposite_score: float,
	off_center_score: float,
	cue_distance_score: float
) -> String:
	var reasons: Array[String] = []
	if rail_score >= 0.58:
		reasons.append("near rail")
	if clutter_count >= 2:
		reasons.append("clutter %s" % clutter_count)
	if direct_line_blockers > 0:
		reasons.append("shielded %s" % direct_line_blockers)
	if opposite_score >= 0.58:
		reasons.append("opposite cue")
	if off_center_score >= 0.45:
		reasons.append("off-center")
	if cue_distance_score >= 0.42:
		reasons.append("long cue route")
	if reasons.is_empty():
		reasons.append("least easy candidate")

	return ", ".join(reasons.slice(0, CURSE_SEED_MAX_REASON_COUNT))


func _get_active_anchor_balls() -> Array[Ball]:
	var anchor_balls: Array[Ball] = []
	for child in table.balls.get_children():
		var ball := child as Ball
		if _is_anchor_field_source(ball):
			anchor_balls.append(ball)
	return anchor_balls


func _is_anchor_field_source(ball: Ball) -> bool:
	# Retired continuous-field Anchors are intentionally not field sources.
	# The only active Anchor identity is the curse-seed/chain state above.
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		return false
	return ball != null and ball.is_anchor_ball and not ball.is_anchor_curse_seed and ball.is_gameplay_active()


func _apply_anchor_visual_settings(anchor_balls: Array[Ball]) -> void:
	var visible_field_count := 0
	var field_cap: int = maxi(max_visible_field_auras, 0)
	for anchor_ball in anchor_balls:
		anchor_ball.anchor_visual_effect_strength = visual_effect_strength
		anchor_ball.anchor_field_visual_radius = influence_radius
		anchor_ball.set_anchor_visuals_enabled(anchor_visuals_enabled)

		var show_field_visual: bool = (
			anchor_visuals_enabled
			and visible_field_count < field_cap
		)
		anchor_ball.set_anchor_field_visual_enabled(show_field_visual)
		if show_field_visual:
			visible_field_count += 1


func _get_anchor_visual_counts() -> Dictionary:
	var visual_nodes_active := 0
	var field_rings_drawn := 0
	var affected_markers_active := 0
	if table == null:
		return {
			"visual_nodes_active": visual_nodes_active,
			"field_rings_drawn": field_rings_drawn,
			"affected_markers_active": affected_markers_active,
		}

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.visible:
			continue

		visual_nodes_active += 1 if ball.is_anchor_visual_node_active() else 0
		field_rings_drawn += 1 if ball.is_anchor_field_visual_drawn() else 0
		affected_markers_active += 1 if ball.is_anchor_influence_marker_active() else 0

	return {
		"visual_nodes_active": visual_nodes_active,
		"field_rings_drawn": field_rings_drawn,
		"affected_markers_active": affected_markers_active,
	}


func _get_retired_anchor_visual_counts() -> Dictionary:
	return {
		"visual_nodes_active": 0,
		"field_rings_drawn": 0,
		"affected_markers_active": 0,
	}


func _sync_anchor_influence_markers() -> void:
	if table == null:
		return
	if not RETIRED_CONTINUOUS_PULL_ENABLED:
		return

	# Markers live on Ball.gd, keyed by the ball instance instead of spawned as extra nodes.
	for child in table.balls.get_children():
		var ball := child as Ball
		if ball == null:
			continue

		if ball.is_anchor_ball or not anchor_visuals_enabled or not ball.visible or not ball.gameplay_enabled:
			ball.clear_anchor_influence_marker()
			continue

		if not affected_ball_ids.has(ball.get_instance_id()):
			ball.release_anchor_influence_marker()


func _get_pull_target_groups() -> Dictionary:
	var moving_targets: Array[Ball] = []
	var stationary_targets: Array[Ball] = []
	for child in table.balls.get_children():
		var target_ball := child as Ball
		if not _is_pull_target_candidate(target_ball):
			continue

		if target_ball.is_moving():
			moving_targets.append(target_ball)
		else:
			stationary_targets.append(target_ball)

	return {
		"moving": moving_targets,
		"stationary": stationary_targets,
	}


func _should_check_stationary_pull(delta: float, has_stationary_targets: bool) -> bool:
	if not has_stationary_targets or stationary_ball_multiplier <= 0.0:
		stationary_pull_accumulator = 0.0
		return false
	if stationary_pull_update_interval <= 0.0:
		return true

	stationary_pull_accumulator += delta
	if stationary_pull_accumulator < stationary_pull_update_interval:
		return false

	stationary_pull_accumulator = 0.0
	return true


func _apply_anchor_pull_to_targets(
	anchor_ball: Ball,
	target_balls: Array,
	delta: float,
	is_stationary_batch: bool
) -> void:
	for target_value in target_balls:
		var target_ball := target_value as Ball
		_try_apply_anchor_pull(anchor_ball, target_ball, delta, is_stationary_batch)


func _apply_single_latch_anchor_pull_to_targets(
	anchor_balls: Array[Ball],
	target_balls: Array,
	delta: float,
	is_stationary_batch: bool
) -> void:
	for target_value in target_balls:
		var target_ball := target_value as Ball
		if target_ball == null:
			continue

		var best_candidate: Dictionary = {}
		var best_force := -1.0
		var best_distance := INF
		for anchor_ball in anchor_balls:
			var candidate: Dictionary = _get_anchor_pull_candidate(anchor_ball, target_ball, delta, is_stationary_batch)
			if candidate.is_empty():
				continue

			_record_latch_candidate(target_ball)
			var force_magnitude: float = float(candidate["force_magnitude"])
			var distance: float = float(candidate["distance"])
			if force_magnitude < best_force:
				continue
			if is_equal_approx(force_magnitude, best_force) and distance >= best_distance:
				continue

			best_force = force_magnitude
			best_distance = distance
			best_candidate = candidate

		if best_candidate.is_empty():
			continue

		var target_id: int = target_ball.get_instance_id()
		var latch_count: int = int(latch_candidate_counts_this_update.get(target_id, 0))
		single_latch_skipped_this_frame += max(latch_count - 1, 0)
		_apply_anchor_pull_candidate(best_candidate)


func _try_apply_anchor_pull(
	anchor_ball: Ball,
	target_ball: Ball,
	delta: float,
	is_stationary_batch: bool
) -> void:
	var candidate: Dictionary = _get_anchor_pull_candidate(anchor_ball, target_ball, delta, is_stationary_batch)
	if candidate.is_empty():
		return

	_record_latch_candidate(target_ball)
	_apply_anchor_pull_candidate(candidate)


func _get_anchor_pull_candidate(
	anchor_ball: Ball,
	target_ball: Ball,
	delta: float,
	is_stationary_batch: bool
) -> Dictionary:
	if not _is_pull_target(anchor_ball, target_ball):
		return {}

	var offset: Vector2 = anchor_ball.global_position - target_ball.global_position
	var distance_squared: float = offset.length_squared()
	var influence_radius_squared: float = influence_radius * influence_radius
	if distance_squared <= 0.000001 or distance_squared > influence_radius_squared:
		return {}

	var inner_dead_zone: float = _get_inner_dead_zone_radius(anchor_ball, target_ball)
	if distance_squared <= inner_dead_zone * inner_dead_zone:
		return {}
	if _is_pull_pair_on_cooldown(anchor_ball, target_ball):
		return {}

	var distance: float = sqrt(distance_squared)
	var motion_multiplier: float = _get_motion_multiplier(target_ball)
	if motion_multiplier <= 0.0:
		return {}

	var distance_ratio: float = 1.0 - clamp(distance / influence_radius, 0.0, 1.0)
	var pull_ratio: float = lerp(minimum_pull_strength, 1.0, distance_ratio * distance_ratio)
	var source_multiplier: float = _get_anchor_source_multiplier(anchor_ball)
	var force_magnitude: float = pull_strength * source_multiplier * pull_ratio * motion_multiplier

	nearest_distance_this_frame = min(nearest_distance_this_frame, distance)
	var pull_direction: Vector2 = offset / distance
	var velocity_delta: Vector2
	if is_stationary_batch:
		var wake_impulse: float = _get_stationary_wake_impulse(anchor_ball, target_ball, force_magnitude, delta)
		if wake_impulse <= 0.0:
			return {}
		velocity_delta = pull_direction * wake_impulse
	else:
		velocity_delta = pull_direction * force_magnitude * delta

	return {
		"anchor_ball": anchor_ball,
		"target_ball": target_ball,
		"offset": offset,
		"distance": distance,
		"pull_direction": pull_direction,
		"force_magnitude": force_magnitude,
		"pull_ratio": pull_ratio,
		"velocity_delta": velocity_delta,
		"is_stationary_batch": is_stationary_batch,
	}


func _apply_anchor_pull_candidate(candidate: Dictionary) -> void:
	var anchor_ball := candidate["anchor_ball"] as Ball
	var target_ball := candidate["target_ball"] as Ball
	if anchor_ball == null or target_ball == null:
		return

	var velocity_delta: Vector2 = candidate["velocity_delta"]
	var pull_direction: Vector2 = candidate["pull_direction"]
	var offset: Vector2 = candidate["offset"]
	target_ball.velocity += velocity_delta
	table.shot_event_system.record_anchor_influence(target_ball, velocity_delta)
	if bool(candidate["is_stationary_batch"]):
		_start_stationary_wake_cooldown(anchor_ball, target_ball)

	if target_ball.is_moving():
		target_ball.note_anchor_influence(float(candidate["pull_ratio"]), pull_direction)
	_record_force_application(anchor_ball, target_ball, offset, float(candidate["force_magnitude"]))


func _get_stationary_wake_impulse(
	anchor_ball: Ball,
	target_ball: Ball,
	force_magnitude: float,
	delta: float
) -> float:
	if _is_stationary_wake_pair_on_cooldown(anchor_ball, target_ball):
		return 0.0
	if not _has_stationary_wake_pair_changed(anchor_ball, target_ball):
		return 0.0

	var estimated_interval_impulse: float = force_magnitude * max(stationary_pull_update_interval, delta)
	var wake_speed: float = _get_stationary_wake_speed(target_ball, delta)
	if estimated_interval_impulse < wake_speed:
		return 0.0

	var capped_wake_speed: float = min(wake_speed, max_stationary_wake_impulse)
	if capped_wake_speed < target_ball.stop_threshold:
		return 0.0
	return capped_wake_speed


func _get_stationary_wake_speed(target_ball: Ball, delta: float) -> float:
	var friction_buffer: float = target_ball.rolling_friction * target_ball.crawl_speed_drag_multiplier * delta * 2.0
	return max(stationary_min_wake_speed, target_ball.stop_threshold + friction_buffer)


func _is_pull_target(anchor_ball: Ball, target_ball: Ball) -> bool:
	if target_ball == null or target_ball == anchor_ball:
		return false
	return _is_pull_target_candidate(target_ball)


func _is_pull_target_candidate(target_ball: Ball) -> bool:
	if target_ball == null:
		return false
	if target_ball.is_anchor_ball:
		return false
	if not target_ball.is_gameplay_active():
		return false
	return target_ball.ball_type == Ball.BallType.OBJECT


func _get_motion_multiplier(target_ball: Ball) -> float:
	if target_ball.is_moving():
		return 1.0
	return stationary_ball_multiplier


func _begin_latch_candidate_update() -> void:
	latch_candidate_counts_this_update.clear()


func _record_latch_candidate(target_ball: Ball) -> void:
	if target_ball == null:
		return

	var target_id: int = target_ball.get_instance_id()
	latch_candidate_counts_this_update[target_id] = int(latch_candidate_counts_this_update.get(target_id, 0)) + 1


func _finish_latch_candidate_update() -> void:
	for target_id in latch_candidate_counts_this_update:
		var latch_count: int = int(latch_candidate_counts_this_update[target_id])
		max_anchors_affecting_same_ball_this_frame = max(max_anchors_affecting_same_ball_this_frame, latch_count)
		if latch_count <= 1:
			continue

		multi_latch_candidates_this_frame += latch_count - 1
		multi_latch_target_ids_this_frame[target_id] = true

	latch_candidate_counts_this_update.clear()


func _get_anchor_source_multiplier(anchor_ball: Ball) -> float:
	if anchor_ball.is_moving():
		return 1.0
	return STATIONARY_ANCHOR_PULL_MULTIPLIER


func _get_inner_dead_zone_radius(anchor_ball: Ball, target_ball: Ball) -> float:
	return max(inner_dead_zone_radius, anchor_ball.radius + target_ball.radius)


func _try_set_post_collision_cooldown(anchor_ball: Ball, target_ball: Ball) -> void:
	if not _is_anchor_field_source(anchor_ball):
		return
	if not _is_pull_target(anchor_ball, target_ball):
		return

	post_collision_pull_cooldowns[_get_pull_pair_key(anchor_ball, target_ball)] = post_collision_pull_cooldown


func _is_pull_pair_on_cooldown(anchor_ball: Ball, target_ball: Ball) -> bool:
	return post_collision_pull_cooldowns.has(_get_pull_pair_key(anchor_ball, target_ball))


func _is_stationary_wake_pair_on_cooldown(anchor_ball: Ball, target_ball: Ball) -> bool:
	return stationary_wake_cooldowns.has(_get_pull_pair_key(anchor_ball, target_ball))


func _start_stationary_wake_cooldown(anchor_ball: Ball, target_ball: Ball) -> void:
	var pair_key: String = _get_pull_pair_key(anchor_ball, target_ball)
	stationary_wake_positions[pair_key] = {
		"anchor_position": anchor_ball.global_position,
		"target_position": target_ball.global_position,
	}
	if stationary_wake_cooldown <= 0.0:
		return
	stationary_wake_cooldowns[pair_key] = stationary_wake_cooldown


func _has_stationary_wake_pair_changed(anchor_ball: Ball, target_ball: Ball) -> bool:
	if stationary_wake_recheck_distance <= 0.0:
		return true

	var pair_key: String = _get_pull_pair_key(anchor_ball, target_ball)
	if not stationary_wake_positions.has(pair_key):
		return true

	var wake_position_data: Dictionary = stationary_wake_positions[pair_key]
	var anchor_position: Vector2 = wake_position_data.get("anchor_position", anchor_ball.global_position)
	var target_position: Vector2 = wake_position_data.get("target_position", target_ball.global_position)
	var recheck_distance_squared: float = stationary_wake_recheck_distance * stationary_wake_recheck_distance
	return (
		anchor_ball.global_position.distance_squared_to(anchor_position) >= recheck_distance_squared
		or target_ball.global_position.distance_squared_to(target_position) >= recheck_distance_squared
	)


func _update_post_collision_pull_cooldowns(delta: float) -> void:
	_update_cooldown_dictionary(post_collision_pull_cooldowns, delta)


func _update_stationary_wake_cooldowns(delta: float) -> void:
	_update_cooldown_dictionary(stationary_wake_cooldowns, delta)


func _update_cooldown_dictionary(cooldowns: Dictionary, delta: float) -> void:
	var expired_keys: Array[String] = []
	for pair_key in cooldowns.keys():
		var remaining_time: float = float(cooldowns[pair_key]) - delta
		if remaining_time <= 0.0:
			expired_keys.append(pair_key)
		else:
			cooldowns[pair_key] = remaining_time

	for pair_key in expired_keys:
		cooldowns.erase(pair_key)


func _record_force_application(anchor_ball: Ball, target_ball: Ball, offset: Vector2, force_magnitude: float) -> void:
	affected_ball_ids[target_ball.get_instance_id()] = true
	force_applications_this_frame += 1
	total_force_this_frame += force_magnitude
	max_force_this_frame = max(max_force_this_frame, force_magnitude)

	if not debug_visual_enabled:
		return

	var pull_direction: Vector2 = offset.normalized()
	var vector_length: float = clamp(force_magnitude * DEBUG_VECTOR_LENGTH_SCALE, DEBUG_VECTOR_MIN_LENGTH, DEBUG_VECTOR_MAX_LENGTH)
	debug_pull_vectors[_get_pull_pair_key(anchor_ball, target_ball)] = {
		"start": target_ball.global_position,
		"end": target_ball.global_position + pull_direction * vector_length,
	}


func _get_pull_pair_key(anchor_ball: Ball, target_ball: Ball) -> String:
	return "%s:%s" % [anchor_ball.get_instance_id(), target_ball.get_instance_id()]


func _get_average_force() -> float:
	if force_applications_this_frame <= 0:
		return 0.0
	return total_force_this_frame / float(force_applications_this_frame)


func _get_nearest_distance_or_negative() -> float:
	if nearest_distance_this_frame == INF:
		return -1.0
	return nearest_distance_this_frame
