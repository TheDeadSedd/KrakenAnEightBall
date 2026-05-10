@tool
extends Node
class_name WayfinderSystem

# Owns Wayfinder activation, guided target tracking, pocket selection, and anomaly debug logs.
# Table.gd still owns collision response, ball lists, and scene-authored pocket positions.
class GuidedWayfinderBall:
	var ball: Ball
	var pocket_position := Vector2.ZERO
	var remaining_time := 0.0
	var debug_log_cooldown := 0.0
	var start_speed := 0.0

const DEBUG_WAYFINDER := false
const WAYFINDER_REDIRECT_COLLISION_COOLDOWN := 0.10
const WAYFINDER_GUIDE_CONE_DOT_MIN := 0.35
const WAYFINDER_GUIDE_MAX_TURN_ANGLE_DEGREES := 50.0
const WAYFINDER_GUIDE_DURATION := 0.45
const WAYFINDER_GUIDE_TURN_STRENGTH := 4.0
const WAYFINDER_GUIDE_MIN_SPEED := 90.0
const WAYFINDER_GUIDE_SPEED_RETENTION_PER_SECOND := 0.82

var table
var redirect_collision_cooldowns: Dictionary = {}
var guided_balls: Dictionary = {}


func setup(table_ref) -> void:
	table = table_ref


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


func update_guidance(delta: float) -> void:
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
	_try_begin_guidance(ball_a, ball_b)
	_try_begin_guidance(ball_b, ball_a)


func get_guided_target_count() -> int:
	return guided_balls.size()


func is_ball_guided(ball: Ball) -> bool:
	return ball != null and guided_balls.has(ball.get_instance_id())


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
	_set_redirect_pair_cooldown(striker, target)
	_print_guidance_start_debug(striker, target, chosen_pocket)


func _is_active_wayfinder_guidance_collision(striker: Ball, target: Ball) -> bool:
	return striker.is_wayfinder and striker.wayfinder_active and _is_redirect_target(target)


func _is_redirect_target(ball: Ball) -> bool:
	if ball == table.cue_ball or ball == table.eight_ball:
		return false
	if ball.ball_type != Ball.BallType.OBJECT:
		return false
	return not ball.is_wayfinder


func _find_guided_pocket(target: Ball) -> Vector2:
	var velocity_direction: Vector2 = target.velocity.normalized()
	if velocity_direction == Vector2.ZERO:
		return Vector2.ZERO

	var chosen_pocket := Vector2.ZERO
	var chosen_distance := INF
	_print_debug("Wayfinder guide search | target #%s | velocity=%s" % [target.ball_number, velocity_direction])
	var max_turn_dot: float = cos(deg_to_rad(WAYFINDER_GUIDE_MAX_TURN_ANGLE_DEGREES))

	for pocket_position in table.pocket_positions:
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


func _get_redirect_pair_key(ball_a: Ball, ball_b: Ball) -> String:
	var first_id: int = ball_a.get_instance_id()
	var second_id: int = ball_b.get_instance_id()
	if first_id > second_id:
		var temp_id: int = first_id
		first_id = second_id
		second_id = temp_id
	return "%s:%s" % [first_id, second_id]


func _begin_guidance(target: Ball, pocket_position: Vector2) -> void:
	var state: GuidedWayfinderBall = GuidedWayfinderBall.new()
	state.ball = target
	state.pocket_position = pocket_position
	state.remaining_time = WAYFINDER_GUIDE_DURATION
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
