@tool
extends Node
class_name WayfinderSystem

# Owns Wayfinder activation, guided target tracking, pocket selection, and anomaly debug logs.
# Table.gd still owns collision response, ball lists, and scene-authored pocket positions.
const WAYFINDER_CURRENT_PRESENTER_SCRIPT := preload("res://scripts/WayfinderCurrentPresenter.gd")

class GuidedWayfinderBall:
	var ball: Ball
	var pocket_position := Vector2.ZERO
	var remaining_time := 0.0
	var debug_log_cooldown := 0.0
	var start_speed := 0.0

class TemporaryCurrentCarrier:
	# Kraken Intervention current state. Guidance still uses GuidedWayfinderBall.
	var ball: Ball
	var remaining_time := 0.0
	var remaining_transfers := 0

class PendingCurrentEvent:
	var event_id := ""
	var expected_sources := 1
	var sources: Array = []
	var wait_remaining := 0.20

const DEBUG_WAYFINDER := false
const WAYFINDER_REDIRECT_COLLISION_COOLDOWN := 0.10
const WAYFINDER_CURRENT_TRANSFER_COOLDOWN := 0.10
const WAYFINDER_CURRENT_SOURCE_WAIT_SECONDS := 0.24
const WAYFINDER_GUIDE_CONE_DOT_MIN := 0.35
const WAYFINDER_GUIDE_MAX_TURN_ANGLE_DEGREES := 50.0
const WAYFINDER_GUIDE_DURATION := 0.45
const WAYFINDER_GUIDE_TURN_STRENGTH := 4.0
const WAYFINDER_GUIDE_MIN_SPEED := 90.0
const WAYFINDER_GUIDE_SPEED_RETENTION_PER_SECOND := 0.82

@export_range(60.0, 360.0, 10.0) var wayfinder_current_radius := 85.0
@export_range(80.0, 1600.0, 10.0) var wayfinder_current_impulse_strength := 900.0
@export_range(0.5, 8.0, 0.1) var wayfinder_current_lifetime_seconds := 3.0
@export_range(1, 8, 1) var wayfinder_current_transfer_limit := 4

var table: BilliardsTable
var redirect_collision_cooldowns: Dictionary = {}
var guided_balls: Dictionary = {}
var current_transfer_cooldowns: Dictionary = {}
var temporary_current_carriers: Dictionary = {}
var pending_current_events: Dictionary = {}
var wayfinder_current_scoring_snapshots: Dictionary = {}
var wayfinder_current_events_started := 0
var wayfinder_current_initial_affected := 0
var wayfinder_current_transfers := 0
var wayfinder_current_expired := 0
var wayfinder_current_last_affected := 0
var wayfinder_current_last_event_transfers := 0
var wayfinder_current_scored_sinks := 0
var wayfinder_current_transfer_flashes := 0
var wayfinder_current_presenter: WayfinderCurrentPresenter


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	_ensure_wayfinder_current_presenter()


func _ensure_wayfinder_current_presenter() -> void:
	if table == null or wayfinder_current_presenter != null:
		return

	var existing_presenter: WayfinderCurrentPresenter = table.get_node_or_null("WayfinderCurrentPresenter") as WayfinderCurrentPresenter
	if existing_presenter != null:
		wayfinder_current_presenter = existing_presenter
		return

	wayfinder_current_presenter = WAYFINDER_CURRENT_PRESENTER_SCRIPT.new() as WayfinderCurrentPresenter
	wayfinder_current_presenter.name = "WayfinderCurrentPresenter"
	wayfinder_current_presenter.z_index = 36
	table.add_child(wayfinder_current_presenter)


func update_redirect_cooldowns(delta: float) -> void:
	var expired_keys: Array[String] = []
	for pair_key in redirect_collision_cooldowns.keys():
		var remaining_time: float = float(redirect_collision_cooldowns[pair_key]) - delta
		if remaining_time <= 0.0:
			expired_keys.append(pair_key)
		else:
			redirect_collision_cooldowns[pair_key] = remaining_time

	for pair_key in expired_keys:
		redirect_collision_cooldowns.erase(pair_key)

	_update_current_transfer_cooldowns(delta)


func update_guidance(delta: float) -> void:
	_update_pending_wayfinder_current_events(delta)
	_update_temporary_currents(delta)

	var expired_ids: Array[int] = []
	for ball_id in guided_balls.keys():
		var state: GuidedWayfinderBall = guided_balls[ball_id] as GuidedWayfinderBall
		if state == null or not is_instance_valid(state.ball) or not state.ball.is_gameplay_active():
			expired_ids.append(ball_id)
			continue

		if not _apply_guidance_step(state, delta):
			expired_ids.append(ball_id)

	for ball_id in expired_ids:
		guided_balls.erase(ball_id)


func handle_collision(ball_a: Ball, ball_b: Ball) -> void:
	_try_activate_from_cue_hit(ball_a, ball_b)
	_try_activate_from_cue_hit(ball_b, ball_a)
	_try_transfer_temporary_current(ball_a, ball_b)
	_try_transfer_temporary_current(ball_b, ball_a)
	_try_begin_guidance(ball_a, ball_b)
	_try_begin_guidance(ball_b, ball_a)


func get_guided_target_count() -> int:
	return guided_balls.size()


func get_temporary_current_carrier_count() -> int:
	return temporary_current_carriers.size()


func get_wayfinder_current_debug_snapshot() -> Dictionary:
	return {
		"current_carriers": temporary_current_carriers.size(),
		"current_events_started": wayfinder_current_events_started,
		"current_initial_affected": wayfinder_current_initial_affected,
		"current_transfers": wayfinder_current_transfers,
		"current_expired": wayfinder_current_expired,
		"current_last_affected": wayfinder_current_last_affected,
		"current_last_event_transfers": wayfinder_current_last_event_transfers,
		"current_scored_sinks": wayfinder_current_scored_sinks,
		"current_transfer_flashes": wayfinder_current_transfer_flashes,
		"current_radius": wayfinder_current_radius,
		"current_impulse_strength": wayfinder_current_impulse_strength,
		"current_lifetime_seconds": wayfinder_current_lifetime_seconds,
		"current_transfer_limit": wayfinder_current_transfer_limit,
	}


func is_ball_guided(ball: Ball) -> bool:
	return ball != null and guided_balls.has(ball.get_instance_id())


func trigger_wayfinder_current_from_wayfinder(wayfinder_ball: Ball, _context: Dictionary = {}) -> void:
	if not _is_valid_wayfinder_current_source(wayfinder_ball):
		return

	var event_id: String = str(_context.get("event_id", ""))
	var expected_sources: int = maxi(int(_context.get("expected_sources", 1)), 1)
	if event_id.is_empty() or expected_sources <= 1:
		_apply_wayfinder_current_from_sources([wayfinder_ball])
		return

	var pending_event: PendingCurrentEvent = _get_or_make_pending_current_event(event_id, expected_sources)
	pending_event.sources.append(wayfinder_ball)
	if pending_event.sources.size() >= pending_event.expected_sources:
		_apply_pending_wayfinder_current_event(event_id)


func get_wayfinder_current_sink_score_snapshot(ball: Ball) -> Dictionary:
	if ball == null:
		return {}

	var ball_id: int = ball.get_instance_id()
	if not wayfinder_current_scoring_snapshots.has(ball_id):
		return {}

	return (wayfinder_current_scoring_snapshots[ball_id] as Dictionary).duplicate(true)


func note_wayfinder_current_sink_scored(ball: Ball) -> void:
	if ball == null:
		return

	var ball_id: int = ball.get_instance_id()
	if wayfinder_current_scoring_snapshots.has(ball_id):
		wayfinder_current_scoring_snapshots.erase(ball_id)
		wayfinder_current_scored_sinks += 1


func _try_activate_from_cue_hit(ball_a: Ball, ball_b: Ball) -> void:
	if ball_a != table.cue_ball or not ball_b.is_wayfinder:
		return

	ball_b.activate_wayfinder(
		"cue hit | cue dir=%s | wayfinder dir=%s" % [
			ball_a.velocity.normalized(),
			ball_b.velocity.normalized(),
		]
	)


func _try_begin_guidance(striker: Ball, target: Ball) -> void:
	if not _is_active_wayfinder_guidance_collision(striker, target):
		return

	if _is_redirect_pair_ignored(striker, target):
		return

	if target.velocity.length() < WAYFINDER_GUIDE_MIN_SPEED:
		_print_debug(
			"Wayfinder #%s no guide | target #%s | speed %.2f below minimum" % [
				striker.ball_number,
				target.ball_number,
				target.velocity.length(),
			]
		)
		return

	var chosen_pocket: Vector2 = _find_guided_pocket(target)
	if chosen_pocket == Vector2.ZERO:
		_print_debug("Wayfinder #%s no guide | target #%s | no reachable forward pocket" % [striker.ball_number, target.ball_number])
		return

	_begin_guidance(target, chosen_pocket)
	table.shot_event_system.record_anomaly_touch(target)
	_set_redirect_pair_cooldown(striker, target)
	_print_guidance_start_debug(striker, target, chosen_pocket)


func _try_transfer_temporary_current(carrier: Ball, target: Ball) -> void:
	if carrier == null or target == null:
		return
	if _is_current_transfer_pair_ignored(carrier, target):
		return

	var carrier_id: int = carrier.get_instance_id()
	var state: TemporaryCurrentCarrier = temporary_current_carriers.get(carrier_id, null) as TemporaryCurrentCarrier
	if state == null or state.remaining_transfers <= 0:
		return
	if not _is_wayfinder_current_target(target):
		return

	var next_lifetime: float = maxf(state.remaining_time, 0.05)
	var next_transfers: int = state.remaining_transfers - 1
	var flash_start: Vector2 = carrier.global_position
	var flash_end: Vector2 = target.global_position
	_end_temporary_current(carrier)
	_apply_transfer_current_impulse(carrier, target)
	if _begin_temporary_current(target, next_lifetime, next_transfers):
		_register_wayfinder_current_scoring_snapshot(target)
		_begin_current_guidance(target, next_lifetime)
		wayfinder_current_transfers += 1
		wayfinder_current_last_event_transfers += 1
		wayfinder_current_transfer_flashes += 1
		_show_wayfinder_current_transfer_flash(flash_start, flash_end)
		_set_current_transfer_pair_cooldown(carrier, target)
		_print_debug("Wayfinder Current transferred | #%s -> #%s | left %s" % [carrier.ball_number, target.ball_number, next_transfers])


func _is_active_wayfinder_guidance_collision(striker: Ball, target: Ball) -> bool:
	return striker.is_wayfinder and striker.wayfinder_active and _is_redirect_target(target)


func _is_redirect_target(ball: Ball) -> bool:
	if ball == table.cue_ball or ball == table.eight_ball:
		return false
	if ball.ball_type != Ball.BallType.OBJECT:
		return false
	return not ball.is_wayfinder


func _is_wayfinder_current_target(ball: Ball) -> bool:
	if ball == null or not is_instance_valid(ball) or not ball.is_gameplay_active():
		return false
	if table != null and (ball == table.cue_ball or ball == table.eight_ball):
		return false
	if ball.ball_type != Ball.BallType.OBJECT:
		return false
	if ball.is_wayfinder:
		return false
	if ball.is_powder_keg or ball.is_anchor_ball or ball.is_anchor_curse_seed:
		return false
	if ball.is_cannon_ball or ball.is_treasure_ball or ball.is_embezzler_ball:
		return false
	if temporary_current_carriers.has(ball.get_instance_id()):
		return false
	return true


func _is_valid_wayfinder_current_source(wayfinder_ball: Ball) -> bool:
	return (
		table != null
		and wayfinder_ball != null
		and is_instance_valid(wayfinder_ball)
		and wayfinder_ball.is_gameplay_active()
		and wayfinder_ball.is_wayfinder
	)


func _get_wayfinder_current_candidates(sources: Array) -> Dictionary:
	var candidates: Dictionary = {}
	if table == null or table.balls == null:
		return candidates

	var radius_squared: float = wayfinder_current_radius * wayfinder_current_radius
	for child in table.balls.get_children():
		var ball: Ball = child as Ball
		if not _is_wayfinder_current_target(ball):
			continue
		var nearest_source: Ball = null
		var nearest_distance_squared := INF
		for source_value in sources:
			var source: Ball = source_value as Ball
			if not _is_valid_wayfinder_current_source(source):
				continue
			var distance_squared: float = source.global_position.distance_squared_to(ball.global_position)
			if distance_squared > radius_squared or distance_squared >= nearest_distance_squared:
				continue
			nearest_source = source
			nearest_distance_squared = distance_squared
		if nearest_source == null:
			continue
		candidates[ball.get_instance_id()] = {
			"ball": ball,
			"source": nearest_source,
			"distance_squared": nearest_distance_squared,
		}
	return candidates


func _apply_wayfinder_current_from_sources(sources: Array) -> void:
	var valid_sources: Array[Ball] = _get_valid_wayfinder_current_sources(sources)
	if valid_sources.is_empty():
		return

	wayfinder_current_last_event_transfers = 0
	_show_wayfinder_current_initial_pulses(valid_sources)
	var candidates: Dictionary = _get_wayfinder_current_candidates(valid_sources)
	if candidates.is_empty():
		wayfinder_current_events_started += 1
		wayfinder_current_last_affected = 0
		return

	wayfinder_current_events_started += 1
	var affected_count := 0
	for candidate_value in candidates.values():
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value as Dictionary
		var ball: Ball = candidate.get("ball", null) as Ball
		var source: Ball = candidate.get("source", null) as Ball
		if not _is_wayfinder_current_target(ball) or not _is_valid_wayfinder_current_source(source):
			continue

		_apply_initial_current_impulse(source, ball)
		if _begin_temporary_current(ball, wayfinder_current_lifetime_seconds, wayfinder_current_transfer_limit):
			_register_wayfinder_current_scoring_snapshot(ball)
			_begin_current_guidance(ball, wayfinder_current_lifetime_seconds)
			affected_count += 1

	wayfinder_current_initial_affected += affected_count
	wayfinder_current_last_affected = affected_count
	_print_debug("Wayfinder Current | sources %s | affected %s" % [valid_sources.size(), affected_count])


func _show_wayfinder_current_initial_pulses(sources: Array[Ball]) -> void:
	if wayfinder_current_presenter == null or not is_instance_valid(wayfinder_current_presenter):
		return

	for source in sources:
		if not _is_valid_wayfinder_current_source(source):
			continue
		wayfinder_current_presenter.show_initial_pulse(source.global_position, wayfinder_current_radius)


func _show_wayfinder_current_transfer_flash(start_position: Vector2, end_position: Vector2) -> void:
	if wayfinder_current_presenter == null or not is_instance_valid(wayfinder_current_presenter):
		return

	wayfinder_current_presenter.show_transfer_flash(start_position, end_position)


func _get_valid_wayfinder_current_sources(sources: Array) -> Array[Ball]:
	var valid_sources: Array[Ball] = []
	for source_value in sources:
		var source: Ball = source_value as Ball
		if _is_valid_wayfinder_current_source(source):
			valid_sources.append(source)
	return valid_sources


func _get_or_make_pending_current_event(event_id: String, expected_sources: int) -> PendingCurrentEvent:
	var pending_event: PendingCurrentEvent = pending_current_events.get(event_id, null) as PendingCurrentEvent
	if pending_event != null:
		return pending_event

	pending_event = PendingCurrentEvent.new()
	pending_event.event_id = event_id
	pending_event.expected_sources = expected_sources
	pending_event.wait_remaining = WAYFINDER_CURRENT_SOURCE_WAIT_SECONDS
	pending_current_events[event_id] = pending_event
	return pending_event


func _apply_pending_wayfinder_current_event(event_id: String) -> void:
	var pending_event: PendingCurrentEvent = pending_current_events.get(event_id, null) as PendingCurrentEvent
	if pending_event == null:
		return

	pending_current_events.erase(event_id)
	_apply_wayfinder_current_from_sources(pending_event.sources)


func _update_pending_wayfinder_current_events(delta: float) -> void:
	var expired_event_ids: Array[String] = []
	for event_id in pending_current_events.keys():
		var pending_event: PendingCurrentEvent = pending_current_events[event_id] as PendingCurrentEvent
		if pending_event == null:
			expired_event_ids.append(str(event_id))
			continue
		pending_event.wait_remaining -= delta
		if pending_event.wait_remaining <= 0.0:
			expired_event_ids.append(str(event_id))

	for event_id in expired_event_ids:
		_apply_pending_wayfinder_current_event(event_id)


func _apply_initial_current_impulse(source: Ball, target: Ball) -> void:
	var direction: Vector2 = (target.global_position - source.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT.rotated(float(target.get_instance_id() % 360) * TAU / 360.0)
	target.velocity += direction * wayfinder_current_impulse_strength


func _apply_transfer_current_impulse(carrier: Ball, target: Ball) -> void:
	if target.velocity.length() >= WAYFINDER_GUIDE_MIN_SPEED:
		return

	var direction: Vector2 = (target.global_position - carrier.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = carrier.velocity.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	target.velocity += direction * wayfinder_current_impulse_strength * 0.55


func _begin_temporary_current(ball: Ball, lifetime: float, remaining_transfers: int) -> bool:
	if not _is_wayfinder_current_target(ball):
		return false

	var ball_id: int = ball.get_instance_id()
	var state: TemporaryCurrentCarrier = TemporaryCurrentCarrier.new()
	state.ball = ball
	state.remaining_time = maxf(lifetime, 0.05)
	state.remaining_transfers = maxi(remaining_transfers, 0)
	temporary_current_carriers[ball_id] = state
	ball.set_wayfinder_current_visual_active(true)
	return true


func _end_temporary_current(ball: Ball) -> void:
	if ball == null:
		return

	var ball_id: int = ball.get_instance_id()
	temporary_current_carriers.erase(ball_id)
	guided_balls.erase(ball_id)
	ball.set_wayfinder_current_visual_active(false)


func _begin_current_guidance(ball: Ball, duration: float) -> void:
	if ball == null or ball.velocity.length() < WAYFINDER_GUIDE_MIN_SPEED:
		return

	var chosen_pocket: Vector2 = _find_guided_pocket(ball)
	if chosen_pocket == Vector2.ZERO:
		return

	_begin_guidance(ball, chosen_pocket, duration)
	if table != null and table.shot_event_system != null:
		table.shot_event_system.record_anomaly_touch(ball)


func _register_wayfinder_current_scoring_snapshot(ball: Ball) -> void:
	if ball == null:
		return

	wayfinder_current_scoring_snapshots[ball.get_instance_id()] = {
		"ball_id": ball.get_instance_id(),
		"label": "Ball %s" % ball.ball_number,
		"events": [
			ShotEventSystem.EVENT_ANOMALY_TOUCH,
			ShotEventSystem.EVENT_KRAKEN_CURRENT,
		],
	}


func _find_guided_pocket(target: Ball) -> Vector2:
	var velocity_direction: Vector2 = target.velocity.normalized()
	if velocity_direction == Vector2.ZERO:
		return Vector2.ZERO

	var chosen_pocket := Vector2.ZERO
	var chosen_distance := INF
	_print_debug("Wayfinder guide search | target #%s | velocity=%s" % [target.ball_number, velocity_direction])
	var max_turn_dot: float = cos(deg_to_rad(WAYFINDER_GUIDE_MAX_TURN_ANGLE_DEGREES))

	for pocket_position in table.pocket_system.get_pocket_positions():
		var accepted: bool = _is_pocket_guidance_candidate(target, pocket_position, velocity_direction, max_turn_dot)
		if not accepted:
			continue

		var distance: float = target.global_position.distance_squared_to(pocket_position)
		if distance < chosen_distance:
			chosen_distance = distance
			chosen_pocket = pocket_position

	if chosen_pocket != Vector2.ZERO:
		_print_debug("guide chosen | pocket=%s | fallback=false" % chosen_pocket)
	return chosen_pocket


func _is_pocket_guidance_candidate(
	target: Ball,
	pocket_position: Vector2,
	velocity_direction: Vector2,
	max_turn_dot: float
) -> bool:
	var to_pocket: Vector2 = (pocket_position - target.global_position).normalized()
	var alignment: float = to_pocket.dot(velocity_direction)
	var turn_angle_degrees: float = rad_to_deg(acos(clamp(alignment, -1.0, 1.0)))
	var rejection_reason := ""
	if alignment < WAYFINDER_GUIDE_CONE_DOT_MIN:
		rejection_reason = "outside cone"
	elif alignment < max_turn_dot:
		rejection_reason = "turn too sharp"

	_log_pocket_evaluation(pocket_position, alignment, turn_angle_degrees, rejection_reason)
	return rejection_reason.is_empty()


func _log_pocket_evaluation(
	pocket_position: Vector2,
	alignment: float,
	turn_angle_degrees: float,
	rejection_reason: String
) -> void:
	var decision := "accepted" if rejection_reason.is_empty() else "rejected (%s)" % rejection_reason
	_print_debug(
		"pocket=%s | dot=%.3f | angle=%.1f | %s" % [
			pocket_position,
			alignment,
			turn_angle_degrees,
			decision,
		]
	)


func _apply_guidance_step(state: GuidedWayfinderBall, delta: float) -> bool:
	var speed_before: float = state.ball.velocity.length()
	state.remaining_time -= delta
	state.debug_log_cooldown = max(state.debug_log_cooldown - delta, 0.0)

	if state.remaining_time <= 0.0 or speed_before < WAYFINDER_GUIDE_MIN_SPEED:
		_print_debug("guide ended | target #%s | remaining=%.2f | speed=%.2f" % [state.ball.ball_number, max(state.remaining_time, 0.0), speed_before])
		return false

	var desired_direction: Vector2 = (state.pocket_position - state.ball.global_position).normalized()
	if desired_direction == Vector2.ZERO:
		_print_debug("guide ended | target #%s | reached pocket vector" % state.ball.ball_number)
		return false

	_rotate_guided_velocity(state, desired_direction, speed_before, delta)
	return true


func _update_temporary_currents(delta: float) -> void:
	var expired_ids: Array[int] = []
	for ball_id in temporary_current_carriers.keys():
		var state: TemporaryCurrentCarrier = temporary_current_carriers[ball_id] as TemporaryCurrentCarrier
		if state == null or not is_instance_valid(state.ball) or not state.ball.is_gameplay_active():
			expired_ids.append(ball_id)
			continue
		state.remaining_time -= delta
		if state.remaining_time <= 0.0:
			expired_ids.append(ball_id)

	for ball_id in expired_ids:
		var state: TemporaryCurrentCarrier = temporary_current_carriers.get(ball_id, null) as TemporaryCurrentCarrier
		if state != null and is_instance_valid(state.ball):
			state.ball.set_wayfinder_current_visual_active(false)
		temporary_current_carriers.erase(ball_id)
		guided_balls.erase(ball_id)
		wayfinder_current_expired += 1


func _rotate_guided_velocity(
	state: GuidedWayfinderBall,
	desired_direction: Vector2,
	speed_before: float,
	delta: float
) -> void:
	var new_direction: Vector2 = state.ball.velocity.normalized().lerp(
		desired_direction,
		clamp(WAYFINDER_GUIDE_TURN_STRENGTH * delta, 0.0, 1.0)
	).normalized()
	var speed_multiplier: float = pow(WAYFINDER_GUIDE_SPEED_RETENTION_PER_SECOND, delta)
	var guided_speed: float = min(speed_before * speed_multiplier, state.start_speed)
	state.ball.velocity = new_direction * guided_speed
	_maybe_print_guidance_step_debug(state, speed_before, guided_speed)


func _maybe_print_guidance_step_debug(state: GuidedWayfinderBall, speed_before: float, guided_speed: float) -> void:
	if state.debug_log_cooldown > 0.0:
		return

	_print_debug(
		"guiding #%s | pocket=%s | remaining=%.2f | speed %.2f -> %.2f | cap=%.2f" % [
			state.ball.ball_number,
			state.pocket_position,
			state.remaining_time,
			speed_before,
			guided_speed,
			state.start_speed,
		]
	)
	state.debug_log_cooldown = 0.10


func _set_redirect_pair_cooldown(wayfinder_ball: Ball, redirected_ball: Ball) -> void:
	var pair_key: String = _get_redirect_pair_key(wayfinder_ball, redirected_ball)
	redirect_collision_cooldowns[pair_key] = WAYFINDER_REDIRECT_COLLISION_COOLDOWN


func _is_redirect_pair_ignored(ball_a: Ball, ball_b: Ball) -> bool:
	var pair_key: String = _get_redirect_pair_key(ball_a, ball_b)
	return redirect_collision_cooldowns.has(pair_key)


func _set_current_transfer_pair_cooldown(ball_a: Ball, ball_b: Ball) -> void:
	var pair_key: String = _get_redirect_pair_key(ball_a, ball_b)
	current_transfer_cooldowns[pair_key] = WAYFINDER_CURRENT_TRANSFER_COOLDOWN


func _is_current_transfer_pair_ignored(ball_a: Ball, ball_b: Ball) -> bool:
	var pair_key: String = _get_redirect_pair_key(ball_a, ball_b)
	return current_transfer_cooldowns.has(pair_key)


func _update_current_transfer_cooldowns(delta: float) -> void:
	var expired_keys: Array[String] = []
	for pair_key in current_transfer_cooldowns.keys():
		var remaining_time: float = float(current_transfer_cooldowns[pair_key]) - delta
		if remaining_time <= 0.0:
			expired_keys.append(pair_key)
		else:
			current_transfer_cooldowns[pair_key] = remaining_time

	for pair_key in expired_keys:
		current_transfer_cooldowns.erase(pair_key)


func _get_redirect_pair_key(ball_a: Ball, ball_b: Ball) -> String:
	var first_id: int = ball_a.get_instance_id()
	var second_id: int = ball_b.get_instance_id()
	if first_id > second_id:
		var temp_id: int = first_id
		first_id = second_id
		second_id = temp_id
	return "%s:%s" % [first_id, second_id]


func _begin_guidance(target: Ball, pocket_position: Vector2, duration: float = WAYFINDER_GUIDE_DURATION) -> void:
	var state: GuidedWayfinderBall = GuidedWayfinderBall.new()
	state.ball = target
	state.pocket_position = pocket_position
	state.remaining_time = duration
	state.start_speed = target.velocity.length()
	guided_balls[target.get_instance_id()] = state


func _print_debug(message: String) -> void:
	if not DEBUG_WAYFINDER:
		return
	print("Wayfinder | %s" % message)


func _print_guidance_start_debug(wayfinder: Ball, target: Ball, pocket_position: Vector2) -> void:
	if not DEBUG_WAYFINDER:
		return

	print(
		"Wayfinder | guide | wayfinder #%s -> target #%s | pocket=%s | velocity=%s | speed=%.2f | duration=%.2f" % [
			wayfinder.ball_number,
			target.ball_number,
			pocket_position,
			target.velocity.normalized(),
			target.velocity.length(),
			WAYFINDER_GUIDE_DURATION,
		]
	)
