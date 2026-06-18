@tool
extends Node
class_name SpawnSystem

# Owns ball creation, rack setup, reward/debug spawn queues, and safe drop/reset placement.
# Table.gd still owns shot rules, pocket consequences, and the authoritative ball list.
class SpawnBallRequest:
	var ball_number := 1
	var is_wayfinder := false
	var is_powder_keg := false
	var is_anchor_ball := false
	var is_cannon_ball := false
	var is_treasure_ball := false
	var is_embezzler_ball := false
	var has_preferred_position := false
	var preferred_position := Vector2.ZERO
	var has_settle_velocity := false
	var settle_velocity := Vector2.ZERO
	var landing_callback := Callable()
	var landing_callback_data: Dictionary = {}

class SpawnLandingCallback:
	var ball: Ball
	var remaining_time := 0.0
	var callback := Callable()
	var callback_data: Dictionary = {}

class StartingBallData:
	var cue_ball: Ball
	var eight_ball: Ball
	var eight_start := Vector2.ZERO

const CARGO_REPLACEMENT_NONE := ""
const CARGO_REPLACEMENT_WAYFINDER := "wayfinder"
const CARGO_REPLACEMENT_POWDER_KEG := "powder_keg"
const CARGO_REPLACEMENT_TREASURE := "treasure"
const CARGO_REPLACEMENT_CANNON := "cannon"
const CARGO_REPLACEMENT_EMBEZZLER := "embezzler"

# Debug-only spawn shortcuts.
const DEBUG_SPAWN_WAYFINDER_ENABLED := true
const DEBUG_SPAWN_WAYFINDER_KEY := KEY_F
const DEBUG_SPAWN_POWDER_KEG_ENABLED := true
const DEBUG_SPAWN_POWDER_KEG_KEY := KEY_H
const DEBUG_SPAWN_ANCHOR_BALL_ENABLED := true
const DEBUG_SPAWN_ANCHOR_BALL_KEY := KEY_J
const DEBUG_SPAWN_CANNON_BALL_ENABLED := true
const DEBUG_SPAWN_CANNON_BALL_KEY := KEY_K
const DEBUG_SPAWN_TREASURE_BALL_ENABLED := true
const DEBUG_SPAWN_TREASURE_BALL_KEY := KEY_L
const DEBUG_SPAWN_EMBEZZLER_BALL_ENABLED := true
const DEBUG_SPAWN_EMBEZZLER_BALL_KEY := KEY_M
const DEBUG_SPAWN_NORMAL_BALL_ENABLED := true
const DEBUG_SPAWN_NORMAL_BALL_KEY := KEY_G

const BALL_SCENE := preload("res://scenes/Ball.tscn")
const CUE_BALL_SCENE := preload("res://scenes/CueBall.tscn")

# Presentation-space spawn layout. These match the current centered table setup.
const CUE_START := Vector2(700.0, 540.0)
const RACK_ORIGIN := Vector2(1150.0, 540.0)
const RACK_ROWS := 5
const RACK_SPACING_MULTIPLIER := 2.12

# Legacy sink-count reward cadence. Normal gameplay table pressure now comes
# from Table Events; this remains for disabled legacy/debug reward paths.
const BALLS_PER_REWARD_DROP := 3

# Regular reward anomaly pool. Anchor is intentionally not part of this pool.
const TOTAL_ANOMALY_SPAWN_CHANCE := 0.12
const WAYFINDER_SPAWN_CHANCE := 0.06
const POWDER_KEG_SPAWN_CHANCE := 0.06

# Retired continuous-field Anchor reward rolls stay disabled. The debug Anchor
# hotkey now transforms an eligible existing object ball into a curse seed.
const ANCHOR_PRIORITY_REWARD_SPAWN_ENABLED := false
const ANCHOR_HIGH_COUNT_THRESHOLD := 40
const ANCHOR_LOW_COUNT_SPAWN_CHANCE := 0.03
const ANCHOR_HIGH_COUNT_SPAWN_CHANCE := 0.30

# Reward drop placement and pacing.
const SPAWN_SEARCH_CENTER := Vector2(960.0, 540.0)
const SPAWN_SEARCH_STEP := 34.0
const SPAWN_SEARCH_RINGS := 10
const SPAWN_DROP_STAGGER := 0.14
const SPAWN_DROP_LANDING_CALLBACK_DELAY := 0.70
const SPAWN_RANDOM_RADIUS_MIN := 40.0
const SPAWN_RANDOM_RADIUS_MAX := 180.0
const SPAWN_BALL_NUMBERS := [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]

# Safe reset search used when cue/eight penalties return special balls to play.
const RESET_SEARCH_STEP := 22.0
const RESET_SEARCH_RINGS := 8

var table
var pocketed_object_ball_spawn_progress := 0
var pending_spawn_requests: Array[SpawnBallRequest] = []
var pending_landing_callbacks: Array[SpawnLandingCallback] = []
var spawn_drop_cooldown := 0.0
var next_spawn_ball_index := 0


func setup(table_ref) -> void:
	table = table_ref


func spawn_starting_balls() -> StartingBallData:
	var data: StartingBallData = StartingBallData.new()
	data.cue_ball = CUE_BALL_SCENE.instantiate() as Ball
	table.balls.add_child(data.cue_ball)
	data.cue_ball.global_position = CUE_START
	_spawn_starting_rack(data, data.cue_ball.radius)
	return data


func try_handle_debug_spawn_input(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false

	if DEBUG_SPAWN_WAYFINDER_ENABLED and key_event.keycode == DEBUG_SPAWN_WAYFINDER_KEY:
		queue_debug_wayfinder_spawn()
		return true

	if DEBUG_SPAWN_POWDER_KEG_ENABLED and key_event.keycode == DEBUG_SPAWN_POWDER_KEG_KEY:
		queue_debug_powder_keg_spawn()
		return true

	if DEBUG_SPAWN_ANCHOR_BALL_ENABLED and key_event.keycode == DEBUG_SPAWN_ANCHOR_BALL_KEY:
		queue_debug_anchor_ball_spawn()
		return true

	if DEBUG_SPAWN_CANNON_BALL_ENABLED and key_event.keycode == DEBUG_SPAWN_CANNON_BALL_KEY:
		queue_debug_cannon_ball_spawn()
		return true

	if DEBUG_SPAWN_TREASURE_BALL_ENABLED and key_event.keycode == DEBUG_SPAWN_TREASURE_BALL_KEY:
		queue_debug_treasure_ball_spawn()
		return true

	if DEBUG_SPAWN_EMBEZZLER_BALL_ENABLED and key_event.keycode == DEBUG_SPAWN_EMBEZZLER_BALL_KEY:
		queue_debug_embezzler_ball_spawn()
		return true

	if DEBUG_SPAWN_NORMAL_BALL_ENABLED and key_event.keycode == DEBUG_SPAWN_NORMAL_BALL_KEY:
		queue_debug_normal_ball_spawn()
		return true

	return false


func award_base_spawn_progress() -> void:
	# Legacy helper retained for reference. Normal gameplay should only reach
	# this when Table's legacy reward gate is intentionally re-enabled.
	pocketed_object_ball_spawn_progress += 1
	if pocketed_object_ball_spawn_progress < BALLS_PER_REWARD_DROP:
		return

	pocketed_object_ball_spawn_progress = 0
	queue_spawn_reward(1)


func queue_spawn_reward(spawn_count: int, callout_message: String = "") -> void:
	for spawn_index in range(spawn_count):
		var request: SpawnBallRequest = _make_reward_spawn_request()
		pending_spawn_requests.append(request)
		if spawn_index == 0 and not callout_message.is_empty():
			table.queue_spawn_reward_message(
				request.is_wayfinder,
				request.is_powder_keg,
				request.is_anchor_ball,
				request.is_cannon_ball,
				callout_message,
				request.is_treasure_ball,
				request.is_embezzler_ball
			)


func queue_plain_object_ball_drops(spawn_count: int, callout_message: String = "") -> void:
	_queue_specific_ball_drops(spawn_count, false, false, false, callout_message)


func queue_cargo_object_ball_drops(
	spawn_count: int,
	replacement_index: int = -1,
	replacement_kind: String = CARGO_REPLACEMENT_NONE,
	callout_message: String = ""
) -> void:
	var safe_spawn_count := maxi(spawn_count, 0)
	var safe_replacement_index := -1
	var safe_replacement_kind := _sanitize_cargo_replacement_kind(replacement_kind)
	if not can_queue_cargo_replacement_kind(safe_replacement_kind):
		safe_replacement_kind = CARGO_REPLACEMENT_NONE
	if replacement_index >= 0 and replacement_index < safe_spawn_count and not safe_replacement_kind.is_empty():
		safe_replacement_index = replacement_index

	for spawn_index in range(safe_spawn_count):
		var request: SpawnBallRequest = _make_cargo_spawn_request(
			safe_replacement_kind if spawn_index == safe_replacement_index else CARGO_REPLACEMENT_NONE
		)
		pending_spawn_requests.append(request)
		if spawn_index == 0 and not callout_message.is_empty():
			table.queue_spawn_reward_message(
				request.is_wayfinder,
				request.is_powder_keg,
				request.is_anchor_ball,
				request.is_cannon_ball,
				callout_message,
				request.is_treasure_ball,
				request.is_embezzler_ball
			)


func can_queue_cargo_replacement_kind(replacement_kind: String) -> bool:
	match _sanitize_cargo_replacement_kind(replacement_kind):
		CARGO_REPLACEMENT_WAYFINDER, CARGO_REPLACEMENT_POWDER_KEG, CARGO_REPLACEMENT_TREASURE, CARGO_REPLACEMENT_CANNON:
			return true
		CARGO_REPLACEMENT_EMBEZZLER:
			if table == null or table.embezzler_system == null:
				return false
			return not _has_pending_embezzler_spawn() and table.embezzler_system.can_spawn_embezzler()
	return false


func queue_wayfinder_ball_drops(spawn_count: int, callout_message: String = "") -> void:
	_queue_specific_ball_drops(spawn_count, true, false, false, callout_message)


func queue_wayfinder_current_drops(
	spawn_count: int,
	landing_callback: Callable,
	callout_message: String = "",
	landing_callback_data: Dictionary = {}
) -> void:
	for spawn_index in range(maxi(spawn_count, 0)):
		var request: SpawnBallRequest = _make_specific_spawn_request(true, false, false, false)
		request.landing_callback = landing_callback
		request.landing_callback_data = landing_callback_data.duplicate(true)
		pending_spawn_requests.append(request)
		if spawn_index == 0 and not callout_message.is_empty():
			table.queue_spawn_reward_message(
				request.is_wayfinder,
				request.is_powder_keg,
				request.is_anchor_ball,
				request.is_cannon_ball,
				callout_message,
				request.is_treasure_ball,
				request.is_embezzler_ball
			)


func queue_powder_keg_drops(spawn_count: int, callout_message: String = "") -> void:
	_queue_specific_ball_drops(spawn_count, false, true, false, callout_message)


func queue_cannon_ball_drops(spawn_count: int, callout_message: String = "") -> void:
	_queue_specific_ball_drops(spawn_count, false, false, true, callout_message)


func queue_powder_keg_drops_at_positions(spawn_positions: Array, callout_message: String = "") -> void:
	_queue_specific_ball_drops_at_positions(spawn_positions, false, true, false, callout_message)


func queue_cannon_ball_launches(launch_specs: Array, callout_message: String = "") -> void:
	for spec_index in range(launch_specs.size()):
		var launch_spec_value: Variant = launch_specs[spec_index]
		if not (launch_spec_value is Dictionary):
			continue
		var launch_spec: Dictionary = launch_spec_value
		var preferred_position: Vector2 = SPAWN_SEARCH_CENTER
		var settle_velocity: Vector2 = Vector2.ZERO
		var position_value: Variant = launch_spec.get("position", SPAWN_SEARCH_CENTER)
		var velocity_value: Variant = launch_spec.get("velocity", Vector2.ZERO)
		if position_value is Vector2:
			preferred_position = position_value
		if velocity_value is Vector2:
			settle_velocity = velocity_value
		var request: SpawnBallRequest = _make_specific_spawn_request(false, false, false, true)
		request.has_preferred_position = true
		request.preferred_position = preferred_position
		request.has_settle_velocity = true
		request.settle_velocity = settle_velocity
		pending_spawn_requests.append(request)
		if spec_index == 0 and not callout_message.is_empty():
			table.queue_spawn_reward_message(
				request.is_wayfinder,
				request.is_powder_keg,
				request.is_anchor_ball,
				request.is_cannon_ball,
				callout_message,
				request.is_treasure_ball,
				request.is_embezzler_ball
			)


func _queue_specific_ball_drops(
	spawn_count: int,
	is_wayfinder: bool,
	is_powder_keg: bool,
	is_cannon_ball: bool,
	callout_message: String = ""
) -> void:
	for spawn_index in range(maxi(spawn_count, 0)):
		var request: SpawnBallRequest = _make_specific_spawn_request(
			is_wayfinder,
			is_powder_keg,
			false,
			is_cannon_ball
		)
		pending_spawn_requests.append(request)
		if spawn_index == 0 and not callout_message.is_empty():
			table.queue_spawn_reward_message(
				request.is_wayfinder,
				request.is_powder_keg,
				request.is_anchor_ball,
				request.is_cannon_ball,
				callout_message,
				request.is_treasure_ball,
				request.is_embezzler_ball
			)


func _queue_specific_ball_drops_at_positions(
	spawn_positions: Array,
	is_wayfinder: bool,
	is_powder_keg: bool,
	is_cannon_ball: bool,
	callout_message: String = ""
) -> void:
	for spawn_index in range(spawn_positions.size()):
		var position_value: Variant = spawn_positions[spawn_index]
		if not (position_value is Vector2):
			continue
		var preferred_position: Vector2 = position_value
		var request: SpawnBallRequest = _make_specific_spawn_request(
			is_wayfinder,
			is_powder_keg,
			false,
			is_cannon_ball
		)
		request.has_preferred_position = true
		request.preferred_position = preferred_position
		pending_spawn_requests.append(request)
		if spawn_index == 0 and not callout_message.is_empty():
			table.queue_spawn_reward_message(
				request.is_wayfinder,
				request.is_powder_keg,
				request.is_anchor_ball,
				request.is_cannon_ball,
				callout_message,
				request.is_treasure_ball,
				request.is_embezzler_ball
			)


func queue_debug_wayfinder_spawn() -> void:
	var request: SpawnBallRequest = _make_specific_spawn_request(true, false, false, false)
	pending_spawn_requests.append(request)
	table.queue_spawn_reward_message(request.is_wayfinder, request.is_powder_keg, request.is_anchor_ball, request.is_cannon_ball)


func queue_debug_powder_keg_spawn() -> void:
	var request: SpawnBallRequest = _make_specific_spawn_request(false, true, false, false)
	pending_spawn_requests.append(request)
	table.queue_spawn_reward_message(request.is_wayfinder, request.is_powder_keg, request.is_anchor_ball, request.is_cannon_ball)


func queue_debug_anchor_ball_spawn() -> void:
	var result: Dictionary = table.anchor_ball_system.try_create_debug_curse_seed()
	var message := "ANCHOR CURSE SEED ROOTED"
	if not bool(result.get("created", false)):
		message = "NO ANCHOR SEED TARGET"
	table.queue_spawn_reward_message(false, false, false, false, message)


func queue_debug_cannon_ball_spawn() -> void:
	var request: SpawnBallRequest = _make_specific_spawn_request(false, false, false, true)
	pending_spawn_requests.append(request)
	table.queue_spawn_reward_message(request.is_wayfinder, request.is_powder_keg, request.is_anchor_ball, request.is_cannon_ball, "", request.is_treasure_ball)


func queue_debug_treasure_ball_spawn() -> void:
	var request: SpawnBallRequest = _make_specific_spawn_request(false, false, false, false, true)
	pending_spawn_requests.append(request)
	table.queue_spawn_reward_message(request.is_wayfinder, request.is_powder_keg, request.is_anchor_ball, request.is_cannon_ball, "", request.is_treasure_ball, request.is_embezzler_ball)


func queue_debug_embezzler_ball_spawn() -> void:
	if table == null:
		return
	if _has_pending_embezzler_spawn() or table.embezzler_system == null or not table.embezzler_system.can_spawn_embezzler():
		table.queue_spawn_reward_message(false, false, false, false, "EMBEZZLER ALREADY AT LARGE")
		return

	var request: SpawnBallRequest = _make_specific_spawn_request(false, false, false, false, false, true)
	pending_spawn_requests.append(request)
	table.queue_spawn_reward_message(request.is_wayfinder, request.is_powder_keg, request.is_anchor_ball, request.is_cannon_ball, "", request.is_treasure_ball, request.is_embezzler_ball)


func queue_debug_normal_ball_spawn() -> void:
	var request: SpawnBallRequest = _make_specific_spawn_request(false, false, false, false)
	pending_spawn_requests.append(request)
	table.queue_spawn_reward_message(request.is_wayfinder, request.is_powder_keg, request.is_anchor_ball, request.is_cannon_ball)


func process_spawn_queue(delta: float) -> void:
	_process_landing_callbacks(delta)

	if pending_spawn_requests.is_empty():
		spawn_drop_cooldown = 0.0
		return

	spawn_drop_cooldown = max(spawn_drop_cooldown - delta, 0.0)
	if spawn_drop_cooldown > 0.0:
		return

	var request: SpawnBallRequest = pending_spawn_requests.pop_front() as SpawnBallRequest
	_spawn_next_reward_ball(request)
	spawn_drop_cooldown = SPAWN_DROP_STAGGER


func reset_ball(ball: Ball, origin: Vector2) -> void:
	var safe_position: Vector2 = _find_nearest_safe_reset_position(ball, origin)
	ball.respawn_at(safe_position)


func get_manual_placement_ball_radius() -> float:
	if table != null and is_instance_valid(table.cue_ball):
		return table.cue_ball.radius
	return 18.0


func get_manual_placement_validation(candidate: Vector2, ball_radius: float) -> Dictionary:
	if table == null:
		return {"valid": false, "reason": "No table"}
	if not table.playfield_rect.grow(-ball_radius).has_point(candidate):
		return {"valid": false, "reason": "Outside table"}
	if table.pocket_system.is_position_too_close_to_pocket(candidate, ball_radius):
		return {"valid": false, "reason": "Too close to pocket"}
	if _is_position_too_close_to_ball(candidate, ball_radius, null):
		return {"valid": false, "reason": "Too close to ball"}
	return {"valid": true, "reason": "Safe"}


func is_manual_placement_safe(candidate: Vector2, ball_radius: float) -> bool:
	return bool(get_manual_placement_validation(candidate, ball_radius).get("valid", false))


func spawn_manual_plain_object_ball(position: Vector2) -> Ball:
	var ball_number: int = _get_next_spawn_ball_number()
	var ball := _create_ball(Ball.BallType.OBJECT, ball_number, _ball_color(ball_number), position)
	ball.velocity = Vector2.ZERO
	return ball


func spawn_manual_wayfinder_ball(position: Vector2) -> Ball:
	var ball_number: int = _get_next_spawn_ball_number()
	var ball := _create_wayfinder_ball(ball_number, _ball_color(ball_number), position)
	ball.velocity = Vector2.ZERO
	return ball


func spawn_manual_powder_keg_ball(position: Vector2) -> Ball:
	var ball_number: int = _get_next_spawn_ball_number()
	var ball := _create_powder_keg_ball(ball_number, _ball_color(ball_number), position)
	ball.velocity = Vector2.ZERO
	return ball


func spawn_manual_treasure_ball(position: Vector2) -> Ball:
	var ball_number: int = _get_next_spawn_ball_number()
	var ball := _create_treasure_ball(ball_number, _ball_color(ball_number), position)
	ball.velocity = Vector2.ZERO
	return ball


func spawn_manual_cannon_ball(position: Vector2) -> Ball:
	var ball_number: int = _get_next_spawn_ball_number()
	var ball := _create_cannon_ball(ball_number, _ball_color(ball_number), position)
	ball.velocity = Vector2.ZERO
	return ball


func spawn_manual_embezzler_ball(position: Vector2) -> Ball:
	if table == null or table.embezzler_system == null or not table.embezzler_system.can_spawn_embezzler():
		return null

	var ball_number: int = _get_next_spawn_ball_number()
	var ball := _create_embezzler_ball(ball_number, _ball_color(ball_number), position)
	ball.velocity = Vector2.ZERO
	return ball


func has_pending_spawns() -> bool:
	return not pending_spawn_requests.is_empty()


func _has_pending_embezzler_spawn() -> bool:
	for request_value in pending_spawn_requests:
		var request: SpawnBallRequest = request_value as SpawnBallRequest
		if request != null and request.is_embezzler_ball:
			return true
	return false


func get_pending_spawn_count() -> int:
	return pending_spawn_requests.size()


func get_cue_start() -> Vector2:
	return CUE_START


func get_debug_spawn_hotkey_data() -> Dictionary:
	return {
		"wayfinder_spawn_key": DEBUG_SPAWN_WAYFINDER_KEY,
		"powder_keg_spawn_key": DEBUG_SPAWN_POWDER_KEG_KEY,
		"anchor_ball_spawn_key": DEBUG_SPAWN_ANCHOR_BALL_KEY,
		"cannon_ball_spawn_key": DEBUG_SPAWN_CANNON_BALL_KEY,
		"treasure_ball_spawn_key": DEBUG_SPAWN_TREASURE_BALL_KEY,
		"embezzler_ball_spawn_key": DEBUG_SPAWN_EMBEZZLER_BALL_KEY,
		"normal_spawn_key": DEBUG_SPAWN_NORMAL_BALL_KEY,
	}


func _spawn_starting_rack(data: StartingBallData, cue_radius: float) -> void:
	var rack_numbers := _get_starting_rack_numbers()
	var rack_spacing: float = cue_radius * RACK_SPACING_MULTIPLIER
	var index := 0

	for row in range(RACK_ROWS):
		for slot in range(row + 1):
			var number: int = rack_numbers[index]
			var position: Vector2 = _get_rack_position(row, slot, rack_spacing)
			index += 1
			var ball := _create_ball(_ball_type_from_number(number), number, _ball_color(number), position)
			if number == 8:
				data.eight_ball = ball
				data.eight_start = position


func _get_starting_rack_numbers() -> Array[int]:
	return [
		1,
		2, 3,
		4, 8, 5,
		6, 7, 9, 10,
		11, 12, 13, 14, 15,
	]


func _get_rack_position(row: int, slot: int, spacing: float) -> Vector2:
	var x_offset: float = float(row) * spacing
	var y_offset: float = (float(slot) - float(row) * 0.5) * spacing
	return RACK_ORIGIN + Vector2(x_offset, y_offset)


func _create_ball(ball_type: int, number: int, color: Color, position: Vector2) -> Ball:
	var ball := BALL_SCENE.instantiate() as Ball
	table.balls.add_child(ball)
	ball.global_position = position
	ball.setup(ball_type, number, color)
	return ball


func _create_wayfinder_ball(number: int, color: Color, position: Vector2) -> Ball:
	var ball := BALL_SCENE.instantiate() as Ball
	table.balls.add_child(ball)
	ball.global_position = position
	ball.setup(Ball.BallType.OBJECT, number, color, true)
	return ball


func _create_powder_keg_ball(number: int, color: Color, position: Vector2) -> Ball:
	var ball := BALL_SCENE.instantiate() as Ball
	table.balls.add_child(ball)
	ball.global_position = position
	ball.setup(Ball.BallType.OBJECT, number, color, false, true)
	return ball


func _create_anchor_ball(number: int, color: Color, position: Vector2) -> Ball:
	# Retired continuous-field Anchor fallback. No caller should create old
	# field Anchors now; if this path is reached, spawn a normal ball instead.
	return _create_ball(Ball.BallType.OBJECT, number, color, position)


func _create_cannon_ball(number: int, color: Color, position: Vector2) -> Ball:
	var ball := BALL_SCENE.instantiate() as Ball
	table.balls.add_child(ball)
	ball.global_position = position
	ball.setup(Ball.BallType.OBJECT, number, color, false, false, false, true)
	return ball


func _create_treasure_ball(number: int, color: Color, position: Vector2) -> Ball:
	var ball := BALL_SCENE.instantiate() as Ball
	table.balls.add_child(ball)
	ball.global_position = position
	ball.setup(Ball.BallType.OBJECT, number, color, false, false, false, false, true)
	table.treasure_ball_system.register_treasure_ball(ball)
	return ball


func _create_embezzler_ball(number: int, color: Color, position: Vector2) -> Ball:
	var ball := BALL_SCENE.instantiate() as Ball
	table.balls.add_child(ball)
	ball.global_position = position
	ball.setup(Ball.BallType.OBJECT, number, color, false, false, false, false, false, true)
	table.embezzler_system.register_embezzler_ball(ball)
	return ball


func _ball_type_from_number(number: int) -> int:
	if number == 8:
		return Ball.BallType.EIGHT
	return Ball.BallType.OBJECT


func _ball_color(number: int) -> Color:
	var colors := {
		1: Color("d7a829"),
		2: Color("2f69c4"),
		3: Color("c43b36"),
		4: Color("7a44ae"),
		5: Color("2a2523"),
		6: Color("8a5428"),
		7: Color("2d9a5b"),
		8: Color("070707"),
		9: Color("a87918"),
		10: Color("17488f"),
		11: Color("8f252b"),
		12: Color("4f2d78"),
		13: Color("5f656b"),
		14: Color("1f6f42"),
		15: Color("b85b24"),
	}
	return colors.get(number, Color("a56f28"))


func _make_reward_spawn_request() -> SpawnBallRequest:
	var request: SpawnBallRequest = SpawnBallRequest.new()
	request.ball_number = _get_next_spawn_ball_number()
	if _roll_anchor_priority_spawn():
		request.is_anchor_ball = true
		return request

	_apply_regular_anomaly_pool_roll(request)
	return request


func _apply_regular_anomaly_pool_roll(request: SpawnBallRequest) -> void:
	var anomaly_roll: float = randf()
	if anomaly_roll > TOTAL_ANOMALY_SPAWN_CHANCE:
		return

	var powder_keg_threshold: float = WAYFINDER_SPAWN_CHANCE + POWDER_KEG_SPAWN_CHANCE
	request.is_wayfinder = anomaly_roll <= WAYFINDER_SPAWN_CHANCE
	request.is_powder_keg = anomaly_roll > WAYFINDER_SPAWN_CHANCE and anomaly_roll <= powder_keg_threshold


func _make_cargo_spawn_request(replacement_kind: String = CARGO_REPLACEMENT_NONE) -> SpawnBallRequest:
	match _sanitize_cargo_replacement_kind(replacement_kind):
		CARGO_REPLACEMENT_WAYFINDER:
			return _make_specific_spawn_request(true, false, false, false)
		CARGO_REPLACEMENT_POWDER_KEG:
			return _make_specific_spawn_request(false, true, false, false)
		CARGO_REPLACEMENT_TREASURE:
			return _make_specific_spawn_request(false, false, false, false, true)
		CARGO_REPLACEMENT_CANNON:
			return _make_specific_spawn_request(false, false, false, true)
		CARGO_REPLACEMENT_EMBEZZLER:
			if can_queue_cargo_replacement_kind(CARGO_REPLACEMENT_EMBEZZLER):
				return _make_specific_spawn_request(false, false, false, false, false, true)
	return _make_specific_spawn_request(false, false, false, false)


func _sanitize_cargo_replacement_kind(replacement_kind: String) -> String:
	match replacement_kind:
		CARGO_REPLACEMENT_WAYFINDER, CARGO_REPLACEMENT_POWDER_KEG, CARGO_REPLACEMENT_TREASURE, CARGO_REPLACEMENT_CANNON, CARGO_REPLACEMENT_EMBEZZLER:
			return replacement_kind
	return CARGO_REPLACEMENT_NONE


func _make_specific_spawn_request(
	is_wayfinder: bool,
	is_powder_keg: bool,
	is_anchor_ball: bool,
	is_cannon_ball: bool,
	is_treasure_ball: bool = false,
	is_embezzler_ball: bool = false
) -> SpawnBallRequest:
	var request: SpawnBallRequest = SpawnBallRequest.new()
	request.ball_number = _get_next_spawn_ball_number()
	request.is_wayfinder = is_wayfinder
	request.is_powder_keg = is_powder_keg
	request.is_anchor_ball = is_anchor_ball
	request.is_cannon_ball = is_cannon_ball
	request.is_treasure_ball = is_treasure_ball
	request.is_embezzler_ball = is_embezzler_ball
	if request.is_anchor_ball and not _can_spawn_anchor_ball():
		request.is_anchor_ball = false
	if request.is_embezzler_ball and (table == null or table.embezzler_system == null or not table.embezzler_system.can_spawn_embezzler()):
		request.is_embezzler_ball = false
	return request


func _spawn_next_reward_ball(request: SpawnBallRequest) -> void:
	var spawn_position: Vector2 = _get_spawn_position_for_request(request, table.cue_ball.radius)
	var ball: Ball
	if request.is_wayfinder:
		ball = _create_wayfinder_ball(request.ball_number, _ball_color(request.ball_number), spawn_position)
	elif request.is_powder_keg:
		ball = _create_powder_keg_ball(request.ball_number, _ball_color(request.ball_number), spawn_position)
	elif request.is_anchor_ball and _can_spawn_anchor_ball():
		ball = _create_anchor_ball(request.ball_number, _ball_color(request.ball_number), spawn_position)
	elif request.is_cannon_ball:
		ball = _create_cannon_ball(request.ball_number, _ball_color(request.ball_number), spawn_position)
	elif request.is_treasure_ball:
		ball = _create_treasure_ball(request.ball_number, _ball_color(request.ball_number), spawn_position)
	elif request.is_embezzler_ball:
		ball = _create_embezzler_ball(request.ball_number, _ball_color(request.ball_number), spawn_position)
	else:
		ball = _create_ball(Ball.BallType.OBJECT, request.ball_number, _ball_color(request.ball_number), spawn_position)
	if request.has_settle_velocity:
		ball.begin_spawn_drop_with_settle_velocity(spawn_position, request.settle_velocity)
	else:
		ball.begin_spawn_drop(spawn_position)
	_schedule_landing_callback(request, ball)


func _schedule_landing_callback(request: SpawnBallRequest, ball: Ball) -> void:
	if not request.landing_callback.is_valid():
		return

	var landing_callback: SpawnLandingCallback = SpawnLandingCallback.new()
	landing_callback.ball = ball
	landing_callback.remaining_time = SPAWN_DROP_LANDING_CALLBACK_DELAY
	landing_callback.callback = request.landing_callback
	landing_callback.callback_data = request.landing_callback_data.duplicate(true)
	pending_landing_callbacks.append(landing_callback)


func _process_landing_callbacks(delta: float) -> void:
	for callback_index in range(pending_landing_callbacks.size() - 1, -1, -1):
		var landing_callback: SpawnLandingCallback = pending_landing_callbacks[callback_index] as SpawnLandingCallback
		if landing_callback == null:
			pending_landing_callbacks.remove_at(callback_index)
			continue

		landing_callback.remaining_time -= delta
		if landing_callback.remaining_time > 0.0:
			continue

		pending_landing_callbacks.remove_at(callback_index)
		if not landing_callback.callback.is_valid():
			continue
		if landing_callback.ball == null or not is_instance_valid(landing_callback.ball):
			continue
		landing_callback.callback.call(landing_callback.ball, landing_callback.callback_data)


func _can_spawn_anchor_ball() -> bool:
	# Anchor spawn caps are debug/quality safety valves, not normal-play tuning.
	return table != null and table.anchor_ball_system.can_spawn_anchor_ball()


func _roll_anchor_priority_spawn() -> bool:
	if not ANCHOR_PRIORITY_REWARD_SPAWN_ENABLED:
		return false
	if not _can_spawn_anchor_ball():
		return false
	return randf() <= _get_anchor_priority_spawn_chance()


func _get_anchor_priority_spawn_chance() -> float:
	if _get_visible_table_ball_count() > ANCHOR_HIGH_COUNT_THRESHOLD:
		return ANCHOR_HIGH_COUNT_SPAWN_CHANCE
	return ANCHOR_LOW_COUNT_SPAWN_CHANCE


func _get_visible_table_ball_count() -> int:
	var visible_ball_count := 0
	for child in table.balls.get_children():
		var ball := child as Ball
		if ball != null and ball.visible:
			visible_ball_count += 1
	return visible_ball_count


func _get_next_spawn_ball_number() -> int:
	var ball_number: int = int(SPAWN_BALL_NUMBERS[next_spawn_ball_index])
	next_spawn_ball_index = (next_spawn_ball_index + 1) % SPAWN_BALL_NUMBERS.size()
	return ball_number


func _find_safe_spawn_position(ball_radius: float) -> Vector2:
	var search_center: Vector2 = _get_random_spawn_search_center()
	if _is_safe_ball_position(search_center, ball_radius):
		return search_center

	for ring in range(1, SPAWN_SEARCH_RINGS + 1):
		var radius: float = SPAWN_SEARCH_STEP * ring
		var sample_count: int = max(8, ring * 8)
		for sample_index in range(sample_count):
			var angle: float = TAU * float(sample_index) / float(sample_count)
			var candidate: Vector2 = search_center + Vector2.RIGHT.rotated(angle) * radius
			if _is_safe_ball_position(candidate, ball_radius):
				return candidate

	return table.playfield_rect.get_center()


func _get_spawn_position_for_request(request: SpawnBallRequest, ball_radius: float) -> Vector2:
	if request.has_preferred_position:
		return _find_safe_spawn_position_near(request.preferred_position, ball_radius)
	return _find_safe_spawn_position(ball_radius)


func _find_safe_spawn_position_near(preferred_position: Vector2, ball_radius: float) -> Vector2:
	var safe_rect: Rect2 = table.playfield_rect.grow(-ball_radius)
	var search_center: Vector2 = preferred_position.clamp(safe_rect.position, safe_rect.end)
	if _is_safe_ball_position(search_center, ball_radius):
		return search_center

	for ring in range(1, SPAWN_SEARCH_RINGS + 1):
		var radius: float = SPAWN_SEARCH_STEP * ring
		var sample_count: int = maxi(8, ring * 8)
		for sample_index in range(sample_count):
			var angle: float = TAU * float(sample_index) / float(sample_count)
			var candidate: Vector2 = search_center + Vector2.RIGHT.rotated(angle) * radius
			if _is_safe_ball_position(candidate, ball_radius):
				return candidate

	return _find_safe_spawn_position(ball_radius)


func _get_random_spawn_search_center() -> Vector2:
	var radius: float = randf_range(SPAWN_RANDOM_RADIUS_MIN, SPAWN_RANDOM_RADIUS_MAX)
	var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var candidate: Vector2 = SPAWN_SEARCH_CENTER + direction * radius
	return candidate.clamp(table.playfield_rect.position, table.playfield_rect.end)


func _is_safe_ball_position(candidate: Vector2, ball_radius: float, ignored_ball: Ball = null) -> bool:
	if not table.playfield_rect.grow(-ball_radius).has_point(candidate):
		return false

	if table.pocket_system.is_position_too_close_to_pocket(candidate, ball_radius):
		return false

	return not _is_position_too_close_to_ball(candidate, ball_radius, ignored_ball)


func _is_position_too_close_to_ball(candidate: Vector2, ball_radius: float, ignored_ball: Ball) -> bool:
	for child in table.balls.get_children():
		var other_ball := child as Ball
		if other_ball == null or other_ball == ignored_ball or not other_ball.visible:
			continue
		if candidate.distance_to(other_ball.get_safe_position()) < ball_radius + other_ball.radius + 4.0:
			return true

	return false


func _find_nearest_safe_reset_position(ball: Ball, origin: Vector2) -> Vector2:
	if _is_safe_ball_position(origin, ball.radius, ball):
		return origin

	for ring in range(1, RESET_SEARCH_RINGS + 1):
		var radius: float = RESET_SEARCH_STEP * ring
		var sample_count: int = max(8, ring * 8)
		for sample_index in range(sample_count):
			var angle: float = TAU * float(sample_index) / float(sample_count)
			var candidate: Vector2 = origin + Vector2.RIGHT.rotated(angle) * radius
			if _is_safe_ball_position(candidate, ball.radius, ball):
				return candidate

	return origin
