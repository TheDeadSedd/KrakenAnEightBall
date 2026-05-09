@tool
extends Node2D
class_name BilliardsTable

signal status_text_changed(text: String)
signal game_finished(text: String)

# Debug and editor helpers.
const DEBUG_NO_GAME_OVER := true
const DEBUG_DRAW_RAIL_RECTS := false
const EDITOR_DRAW_GUIDES := true
const EDITOR_DRAW_POCKET_CATCH_ZONES := true

const BALL_SCENE := preload("res://scenes/Ball.tscn")
const CUE_BALL_SCENE := preload("res://scenes/CueBall.tscn")

# Table bounds. Drawing, rail collision, pockets, and reset checks all use these.
const TABLE_LEFT := 40.0
const TABLE_TOP := 40.0
const TABLE_RIGHT := 1160.0
const TABLE_BOTTOM := 680.0
const PLAYFIELD_LEFT := 94.0
const PLAYFIELD_TOP := 94.0
const PLAYFIELD_RIGHT := 1106.0
const PLAYFIELD_BOTTOM := 626.0
const TABLE_OUTER_RECT := Rect2(TABLE_LEFT, TABLE_TOP, TABLE_RIGHT - TABLE_LEFT, TABLE_BOTTOM - TABLE_TOP)
const TABLE_RAIL_RECT := Rect2(66, 66, 1068, 588)
const PLAYFIELD_RECT := Rect2(
	PLAYFIELD_LEFT,
	PLAYFIELD_TOP,
	PLAYFIELD_RIGHT - PLAYFIELD_LEFT,
	PLAYFIELD_BOTTOM - PLAYFIELD_TOP
)

# Pocket feel. Catch radius also includes part of the ball radius.
const POCKET_RADIUS := 18.0
const POCKET_CATCH_BONUS := 8.0

# Starting layout.
const CUE_START := Vector2(340, 360)
const RACK_ORIGIN := Vector2(790, 360)
const RACK_ROWS := 5
const RACK_SPACING_MULTIPLIER := 2.12

# Escalation loop. Stylish shots immediately queue new ball drops.
const BASE_SPAWN_POCKET_COUNT := 2
const MULTI_POCKET_BONUS_THRESHOLD := 2
const SPAWN_SEARCH_CENTER := Vector2(600, 360)
const SPAWN_SEARCH_STEP := 34.0
const SPAWN_SEARCH_RINGS := 10
const SPAWN_DROP_STAGGER := 0.14
const SPAWN_BALL_NUMBERS := [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]

# Cue controls and aim preview.
const MAX_DRAG_DISTANCE := 210.0
const MIN_SHOT_DISTANCE := 12.0
const SHOT_POWER := 9.4
const CUE_GAP := 22.0
const CUE_LENGTH := 130.0
const AIM_GUIDE_LENGTH := 180.0

# Arcade physics tuning.
const BALL_COLLISION_RESTITUTION := 0.98
const RAIL_RESTITUTION := 0.92
const RAIL_THICKNESS := 28.0
const RESET_SEARCH_STEP := 22.0
const RESET_SEARCH_RINGS := 8
const PHYSICS_SUBSTEPS := 2

@onready var balls: Node2D = $Balls
@onready var pockets: Node2D = $Pockets

var cue_ball: Ball
var eight_ball: Ball
var eight_start := Vector2.ZERO
var drag_mouse_position := Vector2.ZERO
var is_dragging := false
var game_over := false
var shot_active := false
var shot_pocketed_object_balls := 0
var shot_cue_touched_rail := false
var shot_had_bank_pocket := false
var shot_multi_pocket_bonus_awarded := false
var shot_bank_bonus_awarded := false
var pocketed_object_ball_spawn_progress := 0
var pending_spawn_count := 0
var spawn_drop_cooldown := 0.0
var next_spawn_ball_index := 0
var pocket_positions: Array[Vector2] = []
var rail_rects: Array[Rect2] = []


func _ready() -> void:
	_cache_table_geometry()
	if Engine.is_editor_hint():
		queue_redraw()
		return

	_spawn_starting_balls()
	status_text_changed.emit("Drag backward from the cue ball and release to shoot.")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if game_over:
		return

	var step_delta: float = delta / float(PHYSICS_SUBSTEPS)
	for _step in range(PHYSICS_SUBSTEPS):
		_move_balls(step_delta)
		_resolve_ball_collisions()
		if _handle_pocket_checks():
			break
		_resolve_rail_collisions()
		_apply_ball_friction(step_delta)

	_process_spawn_queue(delta)
	_try_finish_shot()


func _unhandled_input(event: InputEvent) -> void:
	if game_over or not is_instance_valid(cue_ball):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_start_drag(event.position)
		else:
			_release_shot(event.position)
	elif event is InputEventMouseMotion and is_dragging:
		drag_mouse_position = event.position
		queue_redraw()


func _draw() -> void:
	_draw_table_art()
	_draw_collision_debug()

	for pocket_position in pocket_positions:
		draw_circle(pocket_position, POCKET_RADIUS + 8.0, Color(0.08, 0.08, 0.08))

	_draw_editor_guides()

	if not is_dragging or not _can_shoot():
		return

	var drag_vector: Vector2 = _get_drag_vector(drag_mouse_position)
	var aim_direction: Vector2 = drag_vector.normalized()
	var cue_start: Vector2 = cue_ball.global_position - aim_direction * CUE_GAP
	var cue_end: Vector2 = cue_start - aim_direction * CUE_LENGTH
	var guide_length: float = min(AIM_GUIDE_LENGTH, drag_vector.length() * 1.2)
	var guide_end: Vector2 = cue_ball.global_position + aim_direction * guide_length
	draw_line(cue_ball.global_position, guide_end, Color(1, 1, 1, 0.45), 2.0)
	draw_line(cue_start, cue_end, Color("d8c298"), 5.0)
	draw_circle(cue_end, 6.0, Color("8a5b36"))


func _draw_table_art() -> void:
	draw_rect(TABLE_OUTER_RECT, Color("5b3924"), true)
	draw_rect(TABLE_RAIL_RECT, Color("8f6741"), true)
	draw_rect(PLAYFIELD_RECT, Color("1f6b4f"), true)
	draw_rect(TABLE_OUTER_RECT, Color("2d1c12"), false, 4.0)
	draw_rect(PLAYFIELD_RECT, Color("134431"), false, 2.0)


func _draw_collision_debug() -> void:
	if Engine.is_editor_hint() or not DEBUG_DRAW_RAIL_RECTS:
		return

	for rail_rect in rail_rects:
		draw_rect(rail_rect, Color(1, 0.22, 0.12, 0.22), true)
		draw_rect(rail_rect, Color(1, 0.35, 0.2, 0.9), false, 2.0)


func _draw_editor_guides() -> void:
	if not Engine.is_editor_hint() or not EDITOR_DRAW_GUIDES:
		return

	draw_rect(PLAYFIELD_RECT, Color(0.2, 0.7, 1.0, 0.95), false, 2.0)

	for rail_rect in rail_rects:
		draw_rect(rail_rect, Color(1.0, 0.25, 0.1, 0.16), true)
		draw_rect(rail_rect, Color(1.0, 0.25, 0.1, 0.8), false, 1.5)

	for pocket_position in pocket_positions:
		draw_circle(pocket_position, 4.0, Color(1.0, 0.95, 0.25, 0.95))
		if EDITOR_DRAW_POCKET_CATCH_ZONES:
			draw_arc(
				pocket_position,
				_get_pocket_catch_radius(14.0),
				0.0,
				TAU,
				48,
				Color(1.0, 0.95, 0.25, 0.85),
				2.0
			)


func _cache_table_geometry() -> void:
	pocket_positions.clear()
	rail_rects.clear()

	_build_pocket_positions()
	_build_rail_debug_rects()


func _build_pocket_positions() -> void:
	var center_x: float = PLAYFIELD_RECT.get_center().x
	pocket_positions.append(PLAYFIELD_RECT.position)
	pocket_positions.append(Vector2(center_x, PLAYFIELD_RECT.position.y - 2.0))
	pocket_positions.append(Vector2(PLAYFIELD_RECT.end.x, PLAYFIELD_RECT.position.y))
	pocket_positions.append(Vector2(PLAYFIELD_RECT.position.x, PLAYFIELD_RECT.end.y))
	pocket_positions.append(Vector2(center_x, PLAYFIELD_RECT.end.y + 2.0))
	pocket_positions.append(PLAYFIELD_RECT.end)


func _build_rail_debug_rects() -> void:
	_add_rail_rect(
		Vector2(PLAYFIELD_RECT.position.x, PLAYFIELD_RECT.position.y - RAIL_THICKNESS),
		Vector2(PLAYFIELD_RECT.size.x, RAIL_THICKNESS)
	)
	_add_rail_rect(
		Vector2(PLAYFIELD_RECT.position.x, PLAYFIELD_RECT.end.y),
		Vector2(PLAYFIELD_RECT.size.x, RAIL_THICKNESS)
	)
	_add_rail_rect(
		Vector2(PLAYFIELD_RECT.position.x - RAIL_THICKNESS, PLAYFIELD_RECT.position.y),
		Vector2(RAIL_THICKNESS, PLAYFIELD_RECT.size.y)
	)
	_add_rail_rect(
		Vector2(PLAYFIELD_RECT.end.x, PLAYFIELD_RECT.position.y),
		Vector2(RAIL_THICKNESS, PLAYFIELD_RECT.size.y)
	)


func _add_rail_rect(position: Vector2, size: Vector2) -> void:
	rail_rects.append(Rect2(position, size))


func _spawn_starting_balls() -> void:
	cue_ball = CUE_BALL_SCENE.instantiate() as Ball
	balls.add_child(cue_ball)
	cue_ball.global_position = CUE_START

	var rack_numbers := _get_starting_rack_numbers()
	var rack_spacing: float = cue_ball.radius * RACK_SPACING_MULTIPLIER
	var index := 0

	for row in range(RACK_ROWS):
		for slot in range(row + 1):
			var number: int = rack_numbers[index]
			var position: Vector2 = _get_rack_position(row, slot, rack_spacing)
			index += 1

			var ball := _create_ball(_ball_type_from_number(number), number, _ball_color(number), position)
			if number == 8:
				eight_ball = ball
				eight_start = position


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
	balls.add_child(ball)
	ball.global_position = position
	ball.setup(ball_type, number, color)
	return ball


func _ball_type_from_number(number: int) -> int:
	if number == 8:
		return Ball.BallType.EIGHT
	return Ball.BallType.OBJECT


func _ball_color(number: int) -> Color:
	var colors := {
		1: Color("f0c84b"),
		2: Color("2e62c9"),
		3: Color("d6453d"),
		4: Color("7a48ad"),
		5: Color("ef8b2c"),
		6: Color("2c9b5d"),
		7: Color("8b2f2c"),
		8: Color("151515"),
		9: Color("f5df68"),
		10: Color("4f8cff"),
		11: Color("f06458"),
		12: Color("9a6bd1"),
		13: Color("f2a14a"),
		14: Color("46bd78"),
		15: Color("b84842"),
	}
	return colors.get(number, Color("d7b347"))


func _move_balls(delta: float) -> void:
	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_gameplay_active():
			ball.move_ball(delta)


func _apply_ball_friction(delta: float) -> void:
	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_gameplay_active():
			ball.apply_friction(delta)


func _resolve_ball_collisions() -> void:
	var active_balls: Array[Ball] = _get_active_balls()
	for i in range(active_balls.size()):
		for j in range(i + 1, active_balls.size()):
			_resolve_ball_pair(active_balls[i], active_balls[j])


func _get_active_balls() -> Array[Ball]:
	var active_balls: Array[Ball] = []
	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_gameplay_active():
			active_balls.append(ball)
	return active_balls


func _resolve_ball_pair(ball_a: Ball, ball_b: Ball) -> void:
	var offset: Vector2 = ball_b.global_position - ball_a.global_position
	var distance: float = offset.length()
	var combined_radius: float = ball_a.radius + ball_b.radius
	if distance >= combined_radius:
		return

	var normal: Vector2 = Vector2.RIGHT if distance == 0.0 else offset / distance
	_separate_overlapping_balls(ball_a, ball_b, normal, combined_radius - distance)
	_apply_ball_collision_response(ball_a, ball_b, normal)


func _separate_overlapping_balls(ball_a: Ball, ball_b: Ball, normal: Vector2, overlap: float) -> void:
	var correction: Vector2 = normal * (overlap * 0.5 + 0.01)
	ball_a.global_position -= correction
	ball_b.global_position += correction


func _apply_ball_collision_response(ball_a: Ball, ball_b: Ball, normal: Vector2) -> void:
	var relative_velocity: Vector2 = ball_a.velocity - ball_b.velocity
	var speed_along_normal: float = relative_velocity.dot(normal)
	if speed_along_normal <= 0.0:
		return

	var impulse_strength: float = (1.0 + BALL_COLLISION_RESTITUTION) * speed_along_normal * 0.5
	var impulse: Vector2 = normal * impulse_strength
	ball_a.velocity -= impulse
	ball_b.velocity += impulse


func _resolve_rail_collisions() -> void:
	for child in balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.is_gameplay_active():
			continue

		_resolve_ball_inside_playfield(ball)


func _resolve_ball_inside_playfield(ball: Ball) -> void:
	var bounds: Rect2 = PLAYFIELD_RECT.grow(-ball.radius)
	var position: Vector2 = ball.global_position

	if position.x < bounds.position.x:
		position.x = bounds.position.x
		ball.velocity.x = abs(ball.velocity.x) * RAIL_RESTITUTION
		_note_cue_rail_touch(ball)
	elif position.x > bounds.end.x:
		position.x = bounds.end.x
		ball.velocity.x = -abs(ball.velocity.x) * RAIL_RESTITUTION
		_note_cue_rail_touch(ball)

	if position.y < bounds.position.y:
		position.y = bounds.position.y
		ball.velocity.y = abs(ball.velocity.y) * RAIL_RESTITUTION
		_note_cue_rail_touch(ball)
	elif position.y > bounds.end.y:
		position.y = bounds.end.y
		ball.velocity.y = -abs(ball.velocity.y) * RAIL_RESTITUTION
		_note_cue_rail_touch(ball)

	ball.global_position = position


func _handle_pocket_checks() -> bool:
	for child in balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.is_gameplay_active():
			continue

		for pocket_position in pocket_positions:
			var catch_radius: float = _get_pocket_catch_radius(ball.radius)
			if ball.global_position.distance_to(pocket_position) <= catch_radius:
				_handle_pocketed_ball(ball)
				return true

	return false


func _get_pocket_catch_radius(ball_radius: float) -> float:
	return POCKET_RADIUS + ball_radius * 0.5 + POCKET_CATCH_BONUS


func _try_start_drag(mouse_position: Vector2) -> void:
	if not _can_shoot():
		return

	if cue_ball.global_position.distance_to(mouse_position) > cue_ball.radius * 1.8:
		return

	is_dragging = true
	drag_mouse_position = mouse_position
	queue_redraw()


func _release_shot(mouse_position: Vector2) -> void:
	if not is_dragging:
		return

	is_dragging = false
	var drag_vector: Vector2 = _get_drag_vector(mouse_position)
	if drag_vector.length() < MIN_SHOT_DISTANCE:
		queue_redraw()
		return

	cue_ball.velocity += drag_vector * SHOT_POWER
	_start_shot_tracking()
	status_text_changed.emit("Shot taken. Wait for the balls to settle before shooting again.")
	queue_redraw()


func _get_drag_vector(mouse_position: Vector2) -> Vector2:
	var drag_vector: Vector2 = cue_ball.global_position - mouse_position
	return drag_vector.limit_length(MAX_DRAG_DISTANCE)


func _can_shoot() -> bool:
	if game_over or not is_instance_valid(cue_ball) or not cue_ball.visible:
		return false

	if pending_spawn_count > 0:
		return false

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_moving():
			return false

	return true


func _handle_pocketed_ball(ball: Ball) -> void:
	if ball == cue_ball:
		if DEBUG_NO_GAME_OVER:
			_reset_ball(ball, CUE_START, "Cue ball reset for testing.")
			return
		ball.sink()
		_finish_game("Cue ball sunk. Game over.")
		return

	if ball == eight_ball:
		if DEBUG_NO_GAME_OVER:
			_reset_ball(ball, eight_start, "8 ball reset for testing.")
			return
		ball.sink()
		_finish_game("8 ball sunk. Game over.")
		return

	ball.sink()
	ball.queue_free()
	_note_object_ball_pocketed()
	status_text_changed.emit("Ball %s sunk." % ball.ball_number)


func _start_shot_tracking() -> void:
	shot_active = true
	shot_pocketed_object_balls = 0
	shot_cue_touched_rail = false
	shot_had_bank_pocket = false
	shot_multi_pocket_bonus_awarded = false
	shot_bank_bonus_awarded = false


func _note_cue_rail_touch(ball: Ball) -> void:
	if shot_active and ball == cue_ball:
		shot_cue_touched_rail = true


func _note_object_ball_pocketed() -> void:
	if not shot_active:
		return

	shot_pocketed_object_balls += 1
	_award_base_spawn_progress()
	_try_award_multi_pocket_bonus()

	if shot_cue_touched_rail:
		shot_had_bank_pocket = true
		_try_award_bank_bonus()


func _try_finish_shot() -> void:
	if not shot_active or not _all_balls_stopped():
		return

	shot_active = false


func _all_balls_stopped() -> bool:
	if pending_spawn_count > 0:
		return false

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.visible and ball.is_moving():
			return false

	return true


func _award_base_spawn_progress() -> void:
	pocketed_object_ball_spawn_progress += 1
	if pocketed_object_ball_spawn_progress < BASE_SPAWN_POCKET_COUNT:
		return

	pocketed_object_ball_spawn_progress = 0
	_queue_spawn_reward(1)


func _try_award_multi_pocket_bonus() -> void:
	if shot_multi_pocket_bonus_awarded:
		return

	if shot_pocketed_object_balls < MULTI_POCKET_BONUS_THRESHOLD:
		return

	shot_multi_pocket_bonus_awarded = true
	_queue_spawn_reward(1)


func _try_award_bank_bonus() -> void:
	if shot_bank_bonus_awarded:
		return

	shot_bank_bonus_awarded = true
	_queue_spawn_reward(1)


func _queue_spawn_reward(spawn_count: int) -> void:
	pending_spawn_count += spawn_count


func _process_spawn_queue(delta: float) -> void:
	if pending_spawn_count <= 0:
		spawn_drop_cooldown = 0.0
		return

	spawn_drop_cooldown = max(spawn_drop_cooldown - delta, 0.0)
	if spawn_drop_cooldown > 0.0:
		return

	_spawn_next_reward_ball()
	pending_spawn_count -= 1
	spawn_drop_cooldown = SPAWN_DROP_STAGGER


func _spawn_next_reward_ball() -> void:
	var ball_number: int = _get_next_spawn_ball_number()
	var spawn_position: Vector2 = _find_safe_spawn_position(cue_ball.radius)
	var ball: Ball = _create_ball(Ball.BallType.OBJECT, ball_number, _ball_color(ball_number), spawn_position)
	ball.begin_spawn_drop(spawn_position)


func _get_next_spawn_ball_number() -> int:
	var ball_number: int = int(SPAWN_BALL_NUMBERS[next_spawn_ball_index])
	next_spawn_ball_index = (next_spawn_ball_index + 1) % SPAWN_BALL_NUMBERS.size()
	return ball_number


func _find_safe_spawn_position(ball_radius: float) -> Vector2:
	if _is_safe_ball_position(SPAWN_SEARCH_CENTER, ball_radius):
		return SPAWN_SEARCH_CENTER

	for ring in range(1, SPAWN_SEARCH_RINGS + 1):
		var radius: float = SPAWN_SEARCH_STEP * ring
		var sample_count: int = max(8, ring * 8)
		for sample_index in range(sample_count):
			var angle: float = TAU * float(sample_index) / float(sample_count)
			var candidate: Vector2 = SPAWN_SEARCH_CENTER + Vector2.RIGHT.rotated(angle) * radius
			if _is_safe_ball_position(candidate, ball_radius):
				return candidate

	return PLAYFIELD_RECT.get_center()


func _is_safe_ball_position(candidate: Vector2, ball_radius: float, ignored_ball: Ball = null) -> bool:
	if not PLAYFIELD_RECT.grow(-ball_radius).has_point(candidate):
		return false

	for pocket_position in pocket_positions:
		if candidate.distance_to(pocket_position) < POCKET_RADIUS + ball_radius + 8.0:
			return false

	for child in balls.get_children():
		var other_ball := child as Ball
		if other_ball == null or other_ball == ignored_ball or not other_ball.visible:
			continue
		if candidate.distance_to(other_ball.get_safe_position()) < ball_radius + other_ball.radius + 4.0:
			return false

	return true


func _reset_ball(ball: Ball, origin: Vector2, message: String) -> void:
	var safe_position: Vector2 = _find_nearest_safe_reset_position(ball, origin)
	ball.respawn_at(safe_position)
	status_text_changed.emit(message)


func _find_nearest_safe_reset_position(ball: Ball, origin: Vector2) -> Vector2:
	if _is_safe_reset_position(ball, origin):
		return origin

	for ring in range(1, RESET_SEARCH_RINGS + 1):
		var radius: float = RESET_SEARCH_STEP * ring
		var sample_count: int = max(8, ring * 8)
		for sample_index in range(sample_count):
			var angle: float = TAU * float(sample_index) / float(sample_count)
			var candidate: Vector2 = origin + Vector2.RIGHT.rotated(angle) * radius
			if _is_safe_reset_position(ball, candidate):
				return candidate

	return origin


func _is_safe_reset_position(ball: Ball, candidate: Vector2) -> bool:
	return _is_safe_ball_position(candidate, ball.radius, ball)


func _finish_game(message: String) -> void:
	game_over = true
	is_dragging = false

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null:
			ball.velocity = Vector2.ZERO

	status_text_changed.emit("Press F5 in the editor to play another round.")
	game_finished.emit(message)
	queue_redraw()
