@tool
extends Node2D
class_name BilliardsTable

signal status_text_changed(text: String)
signal game_finished(text: String)

class AimPrediction:
	var collision_type := "none"
	var position := Vector2.ZERO
	var ball: Ball = null
	var target_direction := Vector2.ZERO
	var path_points: Array[Vector2] = []

class BankDebugMarker:
	var position := Vector2.ZERO
	var incoming_direction := Vector2.ZERO
	var outgoing_direction := Vector2.ZERO
	var normal := Vector2.ZERO
	var remaining_time := 0.0

class AimBallHit:
	var ball: Ball = null
	var distance := INF

class AimRailHit:
	var distance := INF
	var position := Vector2.ZERO
	var normal := Vector2.ZERO

class ResultCallout:
	var label: Label
	var stack_index := 0
	var drift_tween: Tween
	var slot_tween: Tween

class SpawnBallRequest:
	var ball_number := 1
	var is_wayfinder := false

class GuidedWayfinderBall:
	var ball: Ball
	var pocket_position := Vector2.ZERO
	var remaining_time := 0.0
	var debug_log_cooldown := 0.0
	var start_speed := 0.0

# Debug and editor helpers.
const DEBUG_NO_GAME_OVER := true
const DEBUG_BANK_PREDICTION := false
const DEBUG_DRAW_RAIL_RECTS := false
const DEBUG_PHYSICS_PANEL_ENABLED := true
const DEBUG_SHOT_POWER := false
const DEBUG_WAYFINDER := false
const DEBUG_SPAWN_WAYFINDER_ENABLED := true
const DEBUG_SPAWN_WAYFINDER_KEY := KEY_F
const EDITOR_DRAW_GUIDES := true
const EDITOR_DRAW_POCKET_CATCH_ZONES := true

const BALL_SCENE := preload("res://scenes/Ball.tscn")
const CUE_BALL_SCENE := preload("res://scenes/CueBall.tscn")

# Presentation layout. The underlying table dimensions stay the same; the whole play space is centered in a larger 1920x1080 canvas.
const PRESENTATION_OFFSET_X := 360.0
const PRESENTATION_OFFSET_Y := 180.0

# Table bounds. Drawing, rail collision, pockets, and reset checks all use these.
const TABLE_LEFT := PRESENTATION_OFFSET_X + 40.0
const TABLE_TOP := PRESENTATION_OFFSET_Y + 40.0
const TABLE_RIGHT := PRESENTATION_OFFSET_X + 1160.0
const TABLE_BOTTOM := PRESENTATION_OFFSET_Y + 680.0
const TABLE_RAIL_LEFT := PRESENTATION_OFFSET_X + 66.0
const TABLE_RAIL_TOP := PRESENTATION_OFFSET_Y + 66.0
const PLAYFIELD_LEFT := PRESENTATION_OFFSET_X + 94.0
const PLAYFIELD_TOP := PRESENTATION_OFFSET_Y + 94.0
const PLAYFIELD_RIGHT := PRESENTATION_OFFSET_X + 1106.0
const PLAYFIELD_BOTTOM := PRESENTATION_OFFSET_Y + 626.0
const TABLE_OUTER_RECT := Rect2(TABLE_LEFT, TABLE_TOP, TABLE_RIGHT - TABLE_LEFT, TABLE_BOTTOM - TABLE_TOP)
const TABLE_RAIL_RECT := Rect2(TABLE_RAIL_LEFT, TABLE_RAIL_TOP, 1068, 588)
const PLAYFIELD_RECT := Rect2(
	PLAYFIELD_LEFT,
	PLAYFIELD_TOP,
	PLAYFIELD_RIGHT - PLAYFIELD_LEFT,
	PLAYFIELD_BOTTOM - PLAYFIELD_TOP
)
const PRESENTATION_MARGIN_LEFT := 120.0
const PRESENTATION_MARGIN_RIGHT := 120.0
const PRESENTATION_MARGIN_TOP := 80.0
const PRESENTATION_MARGIN_BOTTOM := 120.0
const TABLE_WOOD_DARK := Color("2f1a12")
const TABLE_WOOD_MID := Color("70452d")
const TABLE_WOOD_LIGHT := Color("a16d45")
const TABLE_BRASS := Color("c79b4a")
const TABLE_FELT_DARK := Color("103f38")
const TABLE_FELT_LIGHT := Color("1d6557")
const TABLE_POCKET_SHADOW := Color(0.03, 0.03, 0.04, 0.92)
const TABLE_POCKET_RING := Color("5f4630")
const TABLE_GUIDE_GLOW := Color(0.78, 0.92, 0.84, 0.12)
const TABLE_STAGE_DARK := Color("383838")
const TABLE_STAGE_LIGHT := Color("505050")
const TABLE_STAGE_LINE := Color(1.0, 1.0, 1.0, 0.05)

# Pocket feel. Catch radius also includes part of the ball radius.
const POCKET_RADIUS := 18.0
const POCKET_CATCH_BONUS := 8.0

# Starting layout.
const CUE_START := Vector2(PRESENTATION_OFFSET_X + 340.0, PRESENTATION_OFFSET_Y + 360.0)
const RACK_ORIGIN := Vector2(PRESENTATION_OFFSET_X + 790.0, PRESENTATION_OFFSET_Y + 360.0)
const RACK_ROWS := 5
const RACK_SPACING_MULTIPLIER := 2.12

# Escalation loop. Stylish shots immediately queue new ball drops.
const BALLS_PER_REWARD_DROP := 3
const MULTI_POCKET_BONUS_THRESHOLD := 2

# Wayfinder anomaly. Reward spawns can occasionally create one of these redirect balls.
const WAYFINDER_SPAWN_CHANCE := 0.12
# After a redirect hit, briefly ignore only that same pair so they can separate cleanly.
const WAYFINDER_REDIRECT_COLLISION_COOLDOWN := 0.10
# Guided balls only look for pockets meaningfully ahead of their current travel.
const WAYFINDER_GUIDE_CONE_DOT_MIN := 0.35
const WAYFINDER_GUIDE_MAX_TURN_ANGLE_DEGREES := 50.0
const WAYFINDER_GUIDE_DURATION := 0.45
const WAYFINDER_GUIDE_TURN_STRENGTH := 4.0
const WAYFINDER_GUIDE_MIN_SPEED := 90.0
const WAYFINDER_GUIDE_SPEED_RETENTION_PER_SECOND := 0.82
const SPAWN_SEARCH_CENTER := Vector2(PRESENTATION_OFFSET_X + 600.0, PRESENTATION_OFFSET_Y + 360.0)
const SPAWN_SEARCH_STEP := 34.0
const SPAWN_SEARCH_RINGS := 10
const SPAWN_DROP_STAGGER := 0.14
const SPAWN_RANDOM_RADIUS_MIN := 40.0
const SPAWN_RANDOM_RADIUS_MAX := 180.0
const SPAWN_BALL_NUMBERS := [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]

# Shot result callouts. These are temporary arcade feedback, not scoring.
const RESULT_MESSAGES_ENABLED := true
const RESULT_MESSAGE_POSITION := Vector2(PRESENTATION_OFFSET_X + 600.0, PRESENTATION_OFFSET_Y + 132.0)
const RESULT_MESSAGE_SIZE := Vector2(540, 58)
const RESULT_MESSAGE_DRIFT := Vector2(0, -24)
const CALLOUT_SPAWN_DELAY := 0.5
const CALLOUT_LIFETIME := 1.2
const CALLOUT_STACK_SPACING := 28.0
const CALLOUT_MAX_ACTIVE := 4
const CALLOUT_SHIFT_TIME := 0.12
const CALLOUT_START_SCALE := 0.88
const CALLOUT_PEAK_SCALE := 1.08

# Cue controls and aim preview.
const MAX_DRAG_DISTANCE := 210.0
const MIN_SHOT_DISTANCE := 12.0
const SHOT_POWER := 9.4
const CUE_GAP := 22.0
const CUE_LENGTH := 130.0
const CUE_WIDTH := 5.0
const CUE_MIN_PULLBACK := 8.0
const CUE_MAX_PULLBACK := 78.0
const AIM_GUIDE_LENGTH := 180.0
const AIM_PREDICTION_ENABLED := true
const AIM_PREDICTION_MAX_DISTANCE := 900.0
const AIM_TARGET_LINE_LENGTH := 180.0
const AIM_LINE_WIDTH := 2.0
const AIM_PREDICTION_MARGIN := 1.5
const AIM_BANK_EPSILON := 0.5

# Arcade physics tuning.
const BALL_COLLISION_RESTITUTION := 0.86
const BALL_VELOCITY_TRANSFER := 0.90
const BALL_COLLISION_SKIN := 1.5
const RAIL_RESTITUTION := 0.78
const RAIL_THICKNESS := 28.0
const RESET_SEARCH_STEP := 22.0
const RESET_SEARCH_RINGS := 8
const PHYSICS_SUBSTEPS := 4
const PHYSICS_DEBUG_SPEED_THRESHOLD := 5.0
const PHYSICS_DEBUG_MAX_BALLS := 10
const BANK_DEBUG_MARKER_LIFETIME := 1.0

@onready var balls: Node2D = $Balls
@onready var pockets: Node2D = $Pockets

var active_result_callouts: Array[ResultCallout] = []
var pending_callout_messages: Array[String] = []
var callout_spawn_cooldown := 0.0
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
var pending_spawn_requests: Array[SpawnBallRequest] = []
var spawn_drop_cooldown := 0.0
var next_spawn_ball_index := 0
var pocket_positions: Array[Vector2] = []
var rail_rects: Array[Rect2] = []
# Only redirected Wayfinder-target pairs use this brief ignore window.
var wayfinder_redirect_collision_cooldowns: Dictionary = {}
var guided_wayfinder_balls: Dictionary = {}
var bank_debug_markers: Array[BankDebugMarker] = []


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

	_update_wayfinder_redirect_cooldowns(delta)
	_update_bank_debug_markers(delta)

	var step_delta: float = delta / float(PHYSICS_SUBSTEPS)
	for _step in range(PHYSICS_SUBSTEPS):
		_update_wayfinder_guidance(step_delta)
		_move_balls(step_delta)
		_resolve_ball_collisions()
		if _handle_pocket_checks():
			break
		_resolve_rail_collisions()
		_apply_ball_friction(step_delta)

	_process_spawn_queue(delta)
	_process_callout_queue(delta)
	_try_finish_shot()

	if DEBUG_BANK_PREDICTION and (is_dragging or not bank_debug_markers.is_empty()):
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if game_over or not is_instance_valid(cue_ball):
		return

	if _try_debug_spawn_wayfinder(event):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_start_drag(event.position)
		else:
			_release_shot(event.position)
	elif event is InputEventMouseMotion and is_dragging:
		drag_mouse_position = event.position
		queue_redraw()


func _try_debug_spawn_wayfinder(event: InputEvent) -> bool:
	if not DEBUG_SPAWN_WAYFINDER_ENABLED:
		return false

	if not (event is InputEventKey):
		return false

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false

	if key_event.keycode != DEBUG_SPAWN_WAYFINDER_KEY:
		return false

	_queue_debug_wayfinder_spawn()
	return true


func _draw() -> void:
	_draw_table_art()
	_draw_collision_debug()
	_draw_pocket_art()
	_draw_bank_debug_markers()

	_draw_editor_guides()

	if not is_dragging or not _can_shoot():
		return

	var drag_vector: Vector2 = _get_drag_vector(drag_mouse_position)
	var aim_direction: Vector2 = drag_vector.normalized()
	var power_ratio: float = clamp(drag_vector.length() / MAX_DRAG_DISTANCE, 0.0, 1.0)
	var cue_pullback: float = _get_cue_pullback(drag_vector)
	var cue_tip: Vector2 = cue_ball.global_position - aim_direction * (CUE_GAP + cue_pullback)
	var cue_end: Vector2 = cue_tip - aim_direction * CUE_LENGTH
	if AIM_PREDICTION_ENABLED:
		_draw_aim_prediction(cue_ball.global_position, aim_direction, power_ratio)
	else:
		var guide_length: float = min(AIM_GUIDE_LENGTH, drag_vector.length() * 1.2)
		var guide_end: Vector2 = cue_ball.global_position + aim_direction * guide_length
		draw_line(cue_ball.global_position, guide_end, _get_aim_power_color(power_ratio), AIM_LINE_WIDTH)
	draw_line(cue_tip, cue_end, Color("d8c298"), CUE_WIDTH)
	draw_circle(cue_end, 6.0, Color("8a5b36"))


func _draw_table_art() -> void:
	var presentation_rect: Rect2 = get_presentation_rect()
	draw_rect(presentation_rect, TABLE_STAGE_DARK, true)
	draw_rect(presentation_rect.grow(-14.0), TABLE_STAGE_LIGHT, false, 3.0)
	_draw_stage_lines(presentation_rect)
	draw_rect(TABLE_OUTER_RECT.grow(10.0), Color(0, 0, 0, 0.22), true)
	draw_rect(TABLE_OUTER_RECT, TABLE_WOOD_DARK, true)
	draw_rect(TABLE_RAIL_RECT, TABLE_WOOD_MID, true)
	draw_rect(PLAYFIELD_RECT, TABLE_FELT_DARK, true)
	_draw_rail_planks()
	_draw_felt_compass()
	draw_rect(TABLE_RAIL_RECT.grow(-8.0), TABLE_WOOD_LIGHT.darkened(0.24), false, 4.0)
	draw_rect(TABLE_OUTER_RECT, TABLE_WOOD_LIGHT.darkened(0.62), false, 4.0)
	draw_rect(PLAYFIELD_RECT.grow(3.0), TABLE_BRASS.darkened(0.38), false, 2.0)
	draw_rect(PLAYFIELD_RECT, TABLE_FELT_LIGHT, false, 2.0)


func _draw_stage_lines(stage_rect: Rect2) -> void:
	for line_x in [stage_rect.position.x + 92.0, stage_rect.position.x + 248.0, stage_rect.end.x - 248.0, stage_rect.end.x - 92.0]:
		draw_line(
			Vector2(line_x, stage_rect.position.y),
			Vector2(line_x, stage_rect.end.y),
			TABLE_STAGE_LINE,
			2.0
		)

	for line_y in [stage_rect.position.y + 76.0, stage_rect.end.y - 92.0]:
		draw_line(
			Vector2(stage_rect.position.x, line_y),
			Vector2(stage_rect.end.x, line_y),
			TABLE_STAGE_LINE,
			2.0
		)


func _draw_rail_planks() -> void:
	for line_x in [TABLE_RAIL_RECT.position.x + 170.0, TABLE_RAIL_RECT.position.x + 530.0, TABLE_RAIL_RECT.position.x + 890.0]:
		draw_line(
			Vector2(line_x, TABLE_RAIL_RECT.position.y + 12.0),
			Vector2(line_x, TABLE_RAIL_RECT.end.y - 12.0),
			Color(1, 0.88, 0.72, 0.08),
			2.0
		)

	for line_y in [TABLE_RAIL_RECT.position.y + 86.0, TABLE_RAIL_RECT.end.y - 86.0]:
		draw_line(
			Vector2(TABLE_RAIL_RECT.position.x + 12.0, line_y),
			Vector2(TABLE_RAIL_RECT.end.x - 12.0, line_y),
			Color(0.18, 0.09, 0.06, 0.22),
			2.0
		)

	for bolt_position in _get_table_bolt_positions():
		draw_circle(bolt_position, 5.0, TABLE_BRASS.darkened(0.28))
		draw_circle(bolt_position + Vector2(-1.0, -1.0), 2.2, TABLE_BRASS.lightened(0.18))


func _draw_felt_compass() -> void:
	var center: Vector2 = PLAYFIELD_RECT.get_center()
	draw_circle(center, 48.0, Color(0.05, 0.18, 0.15, 0.18))
	draw_arc(center, 66.0, 0.0, TAU, 56, Color(0.74, 0.83, 0.72, 0.11), 2.0)
	draw_arc(center, 36.0, 0.0, TAU, 42, Color(0.74, 0.83, 0.72, 0.08), 1.5)

	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var tip: Vector2 = Vector2.RIGHT.rotated(angle)
		var side: Vector2 = tip.orthogonal()
		var points := PackedVector2Array([
			center + tip * 52.0,
			center - tip * 8.0 + side * 8.0,
			center + tip * 10.0,
			center - tip * 8.0 - side * 8.0,
		])
		draw_colored_polygon(points, Color(0.86, 0.79, 0.56, 0.12))

	for angle in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var tip: Vector2 = Vector2.RIGHT.rotated(angle)
		draw_line(center, center + tip * 44.0, Color(0.84, 0.88, 0.8, 0.10), 2.0)


func _draw_pocket_art() -> void:
	for pocket_position in pocket_positions:
		draw_circle(pocket_position, POCKET_RADIUS + 12.0, TABLE_POCKET_RING)
		draw_circle(pocket_position, POCKET_RADIUS + 8.5, TABLE_BRASS.darkened(0.46))
		draw_circle(pocket_position + Vector2(0, 1.5), POCKET_RADIUS + 5.0, TABLE_POCKET_SHADOW)
		draw_arc(pocket_position, POCKET_RADIUS + 9.0, 0.0, TAU, 48, Color(1.0, 0.9, 0.66, 0.22), 1.8)


func _get_table_bolt_positions() -> Array[Vector2]:
	return [
		Vector2(TABLE_RAIL_RECT.position.x + 70.0, TABLE_RAIL_RECT.position.y + 26.0),
		Vector2(TABLE_RAIL_RECT.get_center().x, TABLE_RAIL_RECT.position.y + 22.0),
		Vector2(TABLE_RAIL_RECT.end.x - 70.0, TABLE_RAIL_RECT.position.y + 26.0),
		Vector2(TABLE_RAIL_RECT.position.x + 70.0, TABLE_RAIL_RECT.end.y - 26.0),
		Vector2(TABLE_RAIL_RECT.get_center().x, TABLE_RAIL_RECT.end.y - 22.0),
		Vector2(TABLE_RAIL_RECT.end.x - 70.0, TABLE_RAIL_RECT.end.y - 26.0),
	]


func _draw_collision_debug() -> void:
	if Engine.is_editor_hint() or not DEBUG_DRAW_RAIL_RECTS:
		return

	for rail_rect in rail_rects:
		draw_rect(rail_rect, Color(1, 0.22, 0.12, 0.22), true)
		draw_rect(rail_rect, Color(1, 0.35, 0.2, 0.9), false, 2.0)


func _draw_bank_debug_markers() -> void:
	if not DEBUG_BANK_PREDICTION:
		return

	for marker in bank_debug_markers:
		var fade: float = clamp(marker.remaining_time / BANK_DEBUG_MARKER_LIFETIME, 0.0, 1.0)
		var hit_color := Color(0.42, 0.9, 1.0, 0.8 * fade)
		var incoming_color := Color(1.0, 0.44, 0.32, 0.78 * fade)
		var outgoing_color := Color(0.4, 1.0, 0.56, 0.78 * fade)
		var normal_color := Color(1.0, 0.95, 0.42, 0.72 * fade)
		draw_circle(marker.position, 6.0, hit_color)
		draw_line(marker.position, marker.position - marker.incoming_direction * 34.0, incoming_color, 2.0)
		draw_line(marker.position, marker.position + marker.outgoing_direction * 34.0, outgoing_color, 2.0)
		draw_line(marker.position, marker.position + marker.normal * 24.0, normal_color, 1.8)


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


func get_presentation_rect() -> Rect2:
	return Rect2(
		TABLE_LEFT - PRESENTATION_MARGIN_LEFT,
		TABLE_TOP - PRESENTATION_MARGIN_TOP,
		(TABLE_RIGHT - TABLE_LEFT) + PRESENTATION_MARGIN_LEFT + PRESENTATION_MARGIN_RIGHT,
		(TABLE_BOTTOM - TABLE_TOP) + PRESENTATION_MARGIN_TOP + PRESENTATION_MARGIN_BOTTOM
	)


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


func _create_wayfinder_ball(number: int, color: Color, position: Vector2) -> Ball:
	var ball := BALL_SCENE.instantiate() as Ball
	balls.add_child(ball)
	ball.global_position = position
	ball.setup(Ball.BallType.OBJECT, number, color, true)
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
	var real_combined_radius: float = ball_a.radius + ball_b.radius
	var effective_combined_radius: float = real_combined_radius + BALL_COLLISION_SKIN
	if distance >= effective_combined_radius:
		return

	var normal: Vector2 = Vector2.RIGHT if distance == 0.0 else offset / distance
	var real_overlap: float = max(real_combined_radius - distance, 0.0)
	if real_overlap > 0.0:
		_separate_overlapping_balls(ball_a, ball_b, normal, real_overlap)

	_apply_ball_collision_response(ball_a, ball_b, normal)
	_handle_wayfinder_cue_activation(ball_a, ball_b)
	_try_begin_wayfinder_guidance(ball_a, ball_b)
	_try_begin_wayfinder_guidance(ball_b, ball_a)


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
	impulse_strength *= BALL_VELOCITY_TRANSFER
	var impulse: Vector2 = normal * impulse_strength
	ball_a.velocity -= impulse
	ball_b.velocity += impulse


func _handle_wayfinder_cue_activation(ball_a: Ball, ball_b: Ball) -> void:
	_try_activate_wayfinder_from_cue_hit(ball_a, ball_b)
	_try_activate_wayfinder_from_cue_hit(ball_b, ball_a)


func _try_activate_wayfinder_from_cue_hit(ball_a: Ball, ball_b: Ball) -> void:
	if ball_a != cue_ball or not ball_b.is_wayfinder:
		return

	ball_b.activate_wayfinder(
		"cue hit | cue dir=%s | wayfinder dir=%s" % [
			ball_a.velocity.normalized(),
			ball_b.velocity.normalized(),
		]
	)


func _is_active_wayfinder_guidance_collision(striker: Ball, target: Ball) -> bool:
	return striker.is_wayfinder and striker.wayfinder_active and _is_wayfinder_redirect_target(target)


func _try_begin_wayfinder_guidance(striker: Ball, target: Ball) -> void:
	if not _is_active_wayfinder_guidance_collision(striker, target):
		return

	if _is_wayfinder_redirect_pair_ignored(striker, target):
		return

	# Guidance starts only after the normal collision has already set the target's travel.
	if target.velocity.length() < WAYFINDER_GUIDE_MIN_SPEED:
		_print_wayfinder_debug(
			"Wayfinder #%s no guide | target #%s | speed %.2f below minimum" % [
				striker.ball_number,
				target.ball_number,
				target.velocity.length(),
			]
		)
		return

	var chosen_pocket: Vector2 = _find_wayfinder_guided_pocket(target)
	if chosen_pocket == Vector2.ZERO:
		_print_wayfinder_debug(
			"Wayfinder #%s no guide | target #%s | no reachable forward pocket" % [
				striker.ball_number,
				target.ball_number,
			]
		)
		return

	_begin_wayfinder_guidance(target, chosen_pocket)
	_set_wayfinder_redirect_pair_cooldown(striker, target)
	_print_wayfinder_guidance_start_debug(striker, target, chosen_pocket)


func _resolve_rail_collisions() -> void:
	for child in balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.is_gameplay_active():
			continue

		_resolve_ball_inside_playfield(ball)


func _resolve_ball_inside_playfield(ball: Ball) -> void:
	var bounds: Rect2 = PLAYFIELD_RECT.grow(-ball.radius)
	var position: Vector2 = ball.global_position
	var incoming_velocity: Vector2 = ball.velocity
	var collision_normal := Vector2.ZERO

	if position.x < bounds.position.x:
		position.x = bounds.position.x
		ball.velocity.x = abs(ball.velocity.x) * RAIL_RESTITUTION
		collision_normal = Vector2.RIGHT
		_note_cue_rail_touch(ball)
	elif position.x > bounds.end.x:
		position.x = bounds.end.x
		ball.velocity.x = -abs(ball.velocity.x) * RAIL_RESTITUTION
		collision_normal = Vector2.LEFT
		_note_cue_rail_touch(ball)

	if position.y < bounds.position.y:
		position.y = bounds.position.y
		ball.velocity.y = abs(ball.velocity.y) * RAIL_RESTITUTION
		collision_normal = Vector2.DOWN
		_note_cue_rail_touch(ball)
	elif position.y > bounds.end.y:
		position.y = bounds.end.y
		ball.velocity.y = -abs(ball.velocity.y) * RAIL_RESTITUTION
		collision_normal = Vector2.UP
		_note_cue_rail_touch(ball)

	ball.global_position = position
	_record_actual_bank_debug(ball, position, incoming_velocity, collision_normal)


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


func _update_bank_debug_markers(delta: float) -> void:
	if not DEBUG_BANK_PREDICTION:
		bank_debug_markers.clear()
		return

	var kept_markers: Array[BankDebugMarker] = []
	for marker in bank_debug_markers:
		marker.remaining_time -= delta
		if marker.remaining_time > 0.0:
			kept_markers.append(marker)

	bank_debug_markers = kept_markers


func _record_actual_bank_debug(
	ball: Ball,
	hit_position: Vector2,
	incoming_velocity: Vector2,
	normal: Vector2
) -> void:
	if not DEBUG_BANK_PREDICTION or ball != cue_ball or not shot_active or normal == Vector2.ZERO:
		return

	var marker: BankDebugMarker = BankDebugMarker.new()
	marker.position = hit_position
	marker.incoming_direction = incoming_velocity.normalized()
	marker.outgoing_direction = ball.velocity.normalized()
	marker.normal = normal
	marker.remaining_time = BANK_DEBUG_MARKER_LIFETIME
	bank_debug_markers.append(marker)
	queue_redraw()

	print(
		"Bank debug | actual rail hit | pos=%s | incoming=%s | outgoing=%s | normal=%s" % [
			hit_position,
			marker.incoming_direction,
			marker.outgoing_direction,
			normal,
		]
	)


func _is_wayfinder_redirect_target(ball: Ball) -> bool:
	if ball == cue_ball or ball == eight_ball:
		return false

	if ball.ball_type != Ball.BallType.OBJECT:
		return false

	return not ball.is_wayfinder


func _find_wayfinder_guided_pocket(target: Ball) -> Vector2:
	var velocity_direction: Vector2 = target.velocity.normalized()
	if velocity_direction == Vector2.ZERO:
		return Vector2.ZERO

	var chosen_pocket := Vector2.ZERO
	var chosen_distance := INF
	_print_wayfinder_debug(
		"Wayfinder guide search | target #%s | velocity=%s" % [target.ball_number, velocity_direction]
	)
	var max_turn_dot: float = cos(deg_to_rad(WAYFINDER_GUIDE_MAX_TURN_ANGLE_DEGREES))

	for pocket_position in pocket_positions:
		var to_pocket: Vector2 = (pocket_position - target.global_position).normalized()
		var alignment: float = to_pocket.dot(velocity_direction)
		var turn_angle_degrees: float = rad_to_deg(acos(clamp(alignment, -1.0, 1.0)))
		var rejection_reason := ""
		if alignment < WAYFINDER_GUIDE_CONE_DOT_MIN:
			rejection_reason = "outside cone"
		elif alignment < max_turn_dot:
			rejection_reason = "turn too sharp"

		var accepted: bool = rejection_reason.is_empty()
		_log_wayfinder_pocket_evaluation(
			pocket_position,
			alignment,
			turn_angle_degrees,
			accepted,
			rejection_reason
		)
		if not accepted:
			continue

		var distance: float = target.global_position.distance_squared_to(pocket_position)
		if distance < chosen_distance:
			chosen_distance = distance
			chosen_pocket = pocket_position

	if chosen_pocket != Vector2.ZERO:
		_print_wayfinder_debug("guide chosen | pocket=%s | fallback=false" % chosen_pocket)

	return chosen_pocket


func _log_wayfinder_pocket_evaluation(
	pocket_position: Vector2,
	alignment: float,
	turn_angle_degrees: float,
	accepted: bool,
	rejection_reason: String
) -> void:
	var decision := "accepted" if accepted else "rejected (%s)" % rejection_reason
	_print_wayfinder_debug(
		"pocket=%s | dot=%.3f | angle=%.1f | %s" % [
			pocket_position,
			alignment,
			turn_angle_degrees,
			decision,
		]
	)


func _update_wayfinder_redirect_cooldowns(delta: float) -> void:
	var expired_keys: Array[String] = []

	for pair_key in wayfinder_redirect_collision_cooldowns.keys():
		var remaining_time: float = float(wayfinder_redirect_collision_cooldowns[pair_key]) - delta
		if remaining_time <= 0.0:
			expired_keys.append(pair_key)
		else:
			wayfinder_redirect_collision_cooldowns[pair_key] = remaining_time

	for pair_key in expired_keys:
		wayfinder_redirect_collision_cooldowns.erase(pair_key)


func _update_wayfinder_guidance(delta: float) -> void:
	var expired_ids: Array[int] = []

	for ball_id in guided_wayfinder_balls.keys():
		var state: GuidedWayfinderBall = guided_wayfinder_balls[ball_id] as GuidedWayfinderBall
		if state == null or not is_instance_valid(state.ball) or not state.ball.is_gameplay_active():
			expired_ids.append(ball_id)
			continue

		if not _apply_wayfinder_guidance_step(state, delta):
			expired_ids.append(ball_id)

	for ball_id in expired_ids:
		guided_wayfinder_balls.erase(ball_id)


func _apply_wayfinder_guidance_step(state: GuidedWayfinderBall, delta: float) -> bool:
	var speed_before: float = state.ball.velocity.length()
	state.remaining_time -= delta
	state.debug_log_cooldown = max(state.debug_log_cooldown - delta, 0.0)

	if state.remaining_time <= 0.0 or speed_before < WAYFINDER_GUIDE_MIN_SPEED:
		_print_wayfinder_debug(
			"guide ended | target #%s | remaining=%.2f | speed=%.2f" % [
				state.ball.ball_number,
				max(state.remaining_time, 0.0),
				speed_before,
			]
		)
		return false

	var desired_direction: Vector2 = (state.pocket_position - state.ball.global_position).normalized()
	if desired_direction == Vector2.ZERO:
		_print_wayfinder_debug("guide ended | target #%s | reached pocket vector" % state.ball.ball_number)
		return false

	var current_turn_strength: float = WAYFINDER_GUIDE_TURN_STRENGTH

	# Preserve speed and gently rotate the ball toward its chosen forward pocket.
	var new_direction: Vector2 = state.ball.velocity.normalized().lerp(
		desired_direction,
		clamp(current_turn_strength * delta, 0.0, 1.0)
	).normalized()
	var speed_multiplier: float = pow(WAYFINDER_GUIDE_SPEED_RETENTION_PER_SECOND, delta)
	var guided_speed: float = min(speed_before * speed_multiplier, state.start_speed)
	state.ball.velocity = new_direction * guided_speed

	if state.debug_log_cooldown <= 0.0:
		_print_wayfinder_debug(
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

	return true


func _set_wayfinder_redirect_pair_cooldown(wayfinder_ball: Ball, redirected_ball: Ball) -> void:
	var pair_key: String = _get_wayfinder_redirect_pair_key(wayfinder_ball, redirected_ball)
	wayfinder_redirect_collision_cooldowns[pair_key] = WAYFINDER_REDIRECT_COLLISION_COOLDOWN


func _is_wayfinder_redirect_pair_ignored(ball_a: Ball, ball_b: Ball) -> bool:
	var pair_key: String = _get_wayfinder_redirect_pair_key(ball_a, ball_b)
	return wayfinder_redirect_collision_cooldowns.has(pair_key)


func _get_wayfinder_redirect_pair_key(ball_a: Ball, ball_b: Ball) -> String:
	var first_id: int = ball_a.get_instance_id()
	var second_id: int = ball_b.get_instance_id()
	if first_id > second_id:
		var temp_id: int = first_id
		first_id = second_id
		second_id = temp_id

	return "%s:%s" % [first_id, second_id]


func _begin_wayfinder_guidance(target: Ball, pocket_position: Vector2) -> void:
	var state: GuidedWayfinderBall = GuidedWayfinderBall.new()
	state.ball = target
	state.pocket_position = pocket_position
	state.remaining_time = WAYFINDER_GUIDE_DURATION
	state.start_speed = target.velocity.length()
	guided_wayfinder_balls[target.get_instance_id()] = state


func _print_wayfinder_debug(message: String) -> void:
	if not DEBUG_WAYFINDER:
		return

	print("Wayfinder | %s" % message)


func _print_wayfinder_guidance_start_debug(
	wayfinder: Ball,
	target: Ball,
	pocket_position: Vector2
) -> void:
	var velocity_direction: Vector2 = target.velocity.normalized()
	var speed: float = target.velocity.length()
	if not DEBUG_WAYFINDER:
		return

	print(
		"Wayfinder | guide | wayfinder #%s -> target #%s | pocket=%s | velocity=%s | speed=%.2f | duration=%.2f" % [
			wayfinder.ball_number,
			target.ball_number,
			pocket_position,
			velocity_direction,
			speed,
			WAYFINDER_GUIDE_DURATION,
		]
	)


func _try_start_drag(mouse_position: Vector2) -> void:
	if not _can_shoot():
		return

	if cue_ball.global_position.distance_to(mouse_position) > cue_ball.radius * 1.8:
		return

	is_dragging = true
	drag_mouse_position = mouse_position
	queue_redraw()


func _release_shot(_mouse_position: Vector2) -> void:
	if not is_dragging:
		return

	is_dragging = false
	var release_position: Vector2 = drag_mouse_position
	var drag_vector: Vector2 = _get_drag_vector(release_position)
	if drag_vector.length() < MIN_SHOT_DISTANCE:
		queue_redraw()
		return

	cue_ball.velocity = drag_vector * SHOT_POWER
	_print_shot_power_debug(drag_vector, release_position)
	_start_shot_tracking()
	status_text_changed.emit("Shot taken. Wait for the balls to settle before shooting again.")
	queue_redraw()


func _get_drag_vector(mouse_position: Vector2) -> Vector2:
	var drag_vector: Vector2 = cue_ball.global_position - mouse_position
	return drag_vector.limit_length(MAX_DRAG_DISTANCE)


func _get_cue_pullback(drag_vector: Vector2) -> float:
	var power_ratio: float = clamp(drag_vector.length() / MAX_DRAG_DISTANCE, 0.0, 1.0)
	return lerp(CUE_MIN_PULLBACK, CUE_MAX_PULLBACK, power_ratio)


func _print_shot_power_debug(drag_vector: Vector2, release_position: Vector2) -> void:
	if not DEBUG_SHOT_POWER:
		return

	print(
		"Shot debug | drag length: %.2f | cue velocity: %.2f | release mouse: %s" % [
			drag_vector.length(),
			cue_ball.velocity.length(),
			release_position,
		]
	)


func _draw_aim_prediction(origin: Vector2, direction: Vector2, power_ratio: float) -> void:
	var prediction: AimPrediction = _get_first_aim_collision(origin, direction)
	var aim_color: Color = _get_aim_power_color(power_ratio)

	for point_index in range(prediction.path_points.size() - 1):
		draw_line(
			prediction.path_points[point_index],
			prediction.path_points[point_index + 1],
			aim_color,
			AIM_LINE_WIDTH
		)

	for point_index in range(1, prediction.path_points.size()):
		var marker_alpha: float = 0.55 if point_index < prediction.path_points.size() - 1 else 0.8
		draw_circle(prediction.path_points[point_index], 4.0, Color(aim_color.r, aim_color.g, aim_color.b, marker_alpha))

	_draw_predicted_bank_debug(prediction)

	if prediction.collision_type != "ball":
		return

	var target_ball: Ball = prediction.ball
	var target_direction: Vector2 = prediction.target_direction
	var target_end: Vector2 = target_ball.global_position + target_direction * AIM_TARGET_LINE_LENGTH
	draw_line(target_ball.global_position, target_end, Color(1.0, 0.86, 0.28, 0.75), AIM_LINE_WIDTH)
	draw_circle(target_ball.global_position, 5.0, Color(1.0, 0.86, 0.28, 0.55))


func _draw_predicted_bank_debug(prediction: AimPrediction) -> void:
	if not DEBUG_BANK_PREDICTION or prediction.path_points.size() < 3:
		return

	var rail_point: Vector2 = prediction.path_points[1]
	var reflected_direction: Vector2 = (prediction.path_points[2] - prediction.path_points[1]).normalized()
	var predicted_color := Color(0.4, 0.95, 1.0, 0.85)
	var reflected_color := Color(0.92, 0.5, 1.0, 0.75)
	draw_circle(rail_point, 6.0, predicted_color)
	draw_line(rail_point, rail_point + reflected_direction * 42.0, reflected_color, 2.2)


func _get_aim_power_color(power_ratio: float) -> Color:
	if power_ratio <= 0.35:
		return Color("67d97d")
	if power_ratio <= 0.70:
		return Color("f0a54f")
	return Color("df5a4d")


func _get_first_aim_collision(origin: Vector2, direction: Vector2) -> AimPrediction:
	var prediction: AimPrediction = AimPrediction.new()
	prediction.path_points = [origin]

	var ball_hit: AimBallHit = _get_first_aim_ball_hit(origin, direction)
	var rail_hit: AimRailHit = _get_aim_rail_hit(origin, direction)
	var rail_distance: float = rail_hit.distance
	var stop_distance: float = min(AIM_PREDICTION_MAX_DISTANCE, rail_distance)

	if ball_hit.ball != null and ball_hit.distance <= stop_distance:
		return _make_ball_prediction(origin, direction, ball_hit.ball, ball_hit.distance)

	if rail_hit.distance > AIM_PREDICTION_MAX_DISTANCE or rail_hit.normal == Vector2.ZERO:
		prediction.position = origin + direction * AIM_PREDICTION_MAX_DISTANCE
		prediction.path_points.append(prediction.position)
		return prediction

	prediction.path_points.append(rail_hit.position)
	var reflected_direction: Vector2 = direction.bounce(rail_hit.normal).normalized()
	var bounce_origin: Vector2 = rail_hit.position + reflected_direction * AIM_BANK_EPSILON
	var remaining_distance: float = max(AIM_PREDICTION_MAX_DISTANCE - rail_hit.distance, 0.0)
	var bank_ball_hit: AimBallHit = _get_first_aim_ball_hit(bounce_origin, reflected_direction)
	var bank_rail_hit: AimRailHit = _get_aim_rail_hit(bounce_origin, reflected_direction)
	var bank_stop_distance: float = min(remaining_distance, bank_rail_hit.distance)

	if bank_ball_hit.ball != null and bank_ball_hit.distance <= bank_stop_distance:
		var bank_impact_position: Vector2 = bounce_origin + reflected_direction * bank_ball_hit.distance
		prediction.collision_type = "ball"
		prediction.position = bank_impact_position
		prediction.path_points.append(bank_impact_position)
		prediction.ball = bank_ball_hit.ball
		var target_direction: Vector2 = bank_ball_hit.ball.global_position - bank_impact_position
		prediction.target_direction = target_direction.normalized() if target_direction.length() > 0.0 else reflected_direction
		return prediction

	prediction.collision_type = "rail"
	prediction.position = bounce_origin + reflected_direction * bank_stop_distance
	prediction.path_points.append(prediction.position)
	return prediction


func _get_first_aim_ball_hit(origin: Vector2, direction: Vector2) -> AimBallHit:
	var nearest_hit: AimBallHit = AimBallHit.new()

	for child in balls.get_children():
		var target_ball: Ball = child as Ball
		if target_ball == null or target_ball == cue_ball or not target_ball.is_gameplay_active():
			continue

		var hit_distance: float = _get_aim_ball_distance(origin, direction, target_ball)
		if hit_distance < nearest_hit.distance:
			nearest_hit.ball = target_ball
			nearest_hit.distance = hit_distance

	return nearest_hit


func _get_aim_ball_distance(origin: Vector2, direction: Vector2, target_ball: Ball) -> float:
	var combined_radius: float = cue_ball.radius + target_ball.radius + BALL_COLLISION_SKIN
	var prediction_radius: float = max(combined_radius - AIM_PREDICTION_MARGIN, 0.0)
	var to_target: Vector2 = target_ball.global_position - origin
	var projection: float = to_target.dot(direction)
	if projection <= 0.0:
		return INF

	var closest_point: Vector2 = origin + direction * projection
	var distance_to_ray: float = target_ball.global_position.distance_to(closest_point)
	if distance_to_ray > prediction_radius:
		return INF

	var backtrack: float = sqrt(prediction_radius * prediction_radius - distance_to_ray * distance_to_ray)
	var hit_distance: float = projection - backtrack
	if hit_distance < 0.0:
		return 0.0

	return hit_distance


func _get_aim_rail_hit(origin: Vector2, direction: Vector2) -> AimRailHit:
	var bounds: Rect2 = _get_aim_center_bounds()
	var nearest_hit: AimRailHit = AimRailHit.new()

	if direction.x > 0.0:
		_try_set_aim_rail_hit(nearest_hit, (bounds.end.x - origin.x) / direction.x, origin, direction, Vector2.LEFT)
	elif direction.x < 0.0:
		_try_set_aim_rail_hit(nearest_hit, (bounds.position.x - origin.x) / direction.x, origin, direction, Vector2.RIGHT)

	if direction.y > 0.0:
		_try_set_aim_rail_hit(nearest_hit, (bounds.end.y - origin.y) / direction.y, origin, direction, Vector2.UP)
	elif direction.y < 0.0:
		_try_set_aim_rail_hit(nearest_hit, (bounds.position.y - origin.y) / direction.y, origin, direction, Vector2.DOWN)

	return nearest_hit


func _get_aim_center_bounds() -> Rect2:
	return Rect2(
		PLAYFIELD_LEFT + cue_ball.radius,
		PLAYFIELD_TOP + cue_ball.radius,
		(PLAYFIELD_RIGHT - cue_ball.radius) - (PLAYFIELD_LEFT + cue_ball.radius),
		(PLAYFIELD_BOTTOM - cue_ball.radius) - (PLAYFIELD_TOP + cue_ball.radius)
	)


func _try_set_aim_rail_hit(
	rail_hit: AimRailHit,
	candidate_distance: float,
	origin: Vector2,
	direction: Vector2,
	normal: Vector2
) -> void:
	if candidate_distance < 0.0 or candidate_distance >= rail_hit.distance:
		return

	rail_hit.distance = candidate_distance
	rail_hit.position = origin + direction * candidate_distance
	rail_hit.normal = normal


func _make_ball_prediction(origin: Vector2, direction: Vector2, target_ball: Ball, distance: float) -> AimPrediction:
	var cue_center_at_impact: Vector2 = origin + direction * distance
	var target_direction: Vector2 = target_ball.global_position - cue_center_at_impact
	if target_direction.length() > 0.0:
		target_direction = target_direction.normalized()
	else:
		target_direction = direction

	var prediction: AimPrediction = AimPrediction.new()
	prediction.collision_type = "ball"
	prediction.position = cue_center_at_impact
	prediction.ball = target_ball
	prediction.target_direction = target_direction
	prediction.path_points = [origin, cue_center_at_impact]
	return prediction


func _can_shoot() -> bool:
	if game_over or not is_instance_valid(cue_ball) or not cue_ball.visible:
		return false

	if not pending_spawn_requests.is_empty():
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
	_queue_ball_sunk_message()

	if shot_cue_touched_rail:
		shot_had_bank_pocket = true
		_try_award_bank_bonus()

	_award_base_spawn_progress()
	_try_award_multi_pocket_bonus()


func _try_finish_shot() -> void:
	if not shot_active or not _all_balls_stopped():
		return

	shot_active = false


func get_physics_debug_text() -> String:
	if not DEBUG_PHYSICS_PANEL_ENABLED:
		return "Physics debug disabled."

	var moving_balls: Array[Ball] = []
	for child in balls.get_children():
		var ball := child as Ball
		if ball == null or ball.velocity.length() < PHYSICS_DEBUG_SPEED_THRESHOLD:
			continue
		moving_balls.append(ball)

	if moving_balls.is_empty():
		return "No balls above %.1f speed." % PHYSICS_DEBUG_SPEED_THRESHOLD

	moving_balls.sort_custom(_sort_balls_by_speed_desc)
	var lines: Array[String] = []
	var max_count: int = mini(PHYSICS_DEBUG_MAX_BALLS, moving_balls.size())
	for index in range(max_count):
		var ball: Ball = moving_balls[index]
		lines.append(_get_physics_debug_line(ball))

	return "\n".join(lines)


func _sort_balls_by_speed_desc(ball_a: Ball, ball_b: Ball) -> bool:
	return ball_a.velocity.length() > ball_b.velocity.length()


func _get_physics_debug_line(ball: Ball) -> String:
	var parts: Array[String] = []
	parts.append(_get_ball_debug_name(ball))
	parts.append("speed %.1f" % ball.velocity.length())
	parts.append(_get_ball_drag_band_name(ball))
	if ball.is_wayfinder and ball.wayfinder_active:
		parts.append("active")
	if guided_wayfinder_balls.has(ball.get_instance_id()):
		parts.append("guided")
	if not ball.gameplay_enabled:
		parts.append("paused")
	return " | ".join(parts)


func _get_ball_debug_name(ball: Ball) -> String:
	if ball == cue_ball:
		return "Cue Ball"
	if ball == eight_ball:
		return "8 Ball"
	if ball.is_wayfinder:
		return "Wayfinder Ball"
	return "Ball %s" % ball.ball_number


func _get_ball_drag_band_name(ball: Ball) -> String:
	var speed: float = ball.velocity.length()
	if speed >= ball.medium_speed_drag_start:
		return "high"
	if speed >= ball.low_speed_drag_start:
		return "medium"
	if speed >= ball.crawl_speed_drag_start:
		return "low"
	return "crawl"


func _queue_ball_sunk_message() -> void:
	if shot_pocketed_object_balls == 1:
		_queue_result_message("1 BALL SUNK")
	elif shot_pocketed_object_balls > 1:
		_queue_result_message("%s BALLS SUNK" % shot_pocketed_object_balls)


func _queue_spawn_reward_message(request: SpawnBallRequest) -> void:
	if request.is_wayfinder:
		_queue_result_message("WAYFINDER BALL DROPPED")
	else:
		_queue_result_message("+1 BALL DROPPED")


func _queue_result_message(message: String) -> void:
	if not RESULT_MESSAGES_ENABLED:
		return

	pending_callout_messages.append(message)


func _make_spawn_ball_request() -> SpawnBallRequest:
	var request: SpawnBallRequest = SpawnBallRequest.new()
	request.ball_number = _get_next_spawn_ball_number()
	request.is_wayfinder = randf() <= WAYFINDER_SPAWN_CHANCE
	return request


func _queue_debug_wayfinder_spawn() -> void:
	var request: SpawnBallRequest = SpawnBallRequest.new()
	request.ball_number = _get_next_spawn_ball_number()
	request.is_wayfinder = true
	pending_spawn_requests.append(request)
	_queue_spawn_reward_message(request)


func _process_callout_queue(delta: float) -> void:
	if not RESULT_MESSAGES_ENABLED:
		pending_callout_messages.clear()
		return

	if pending_callout_messages.is_empty():
		callout_spawn_cooldown = 0.0
		return

	callout_spawn_cooldown = max(callout_spawn_cooldown - delta, 0.0)
	if callout_spawn_cooldown > 0.0:
		return

	var message: String = pending_callout_messages.pop_front() as String
	_display_result_callout(message)
	callout_spawn_cooldown = CALLOUT_SPAWN_DELAY


func _display_result_callout(message: String) -> void:
	_create_result_callout(message)
	_trim_result_callouts()
	_update_callout_stack_positions()


func _create_result_callout(message: String) -> void:
	var label: Label = _make_result_callout_label(message)
	var callout: ResultCallout = ResultCallout.new()
	callout.label = label
	active_result_callouts.push_front(callout)
	add_child(label)
	_animate_new_callout(callout)


func _make_result_callout_label(message: String) -> Label:
	var label: Label = Label.new()
	label.text = message
	label.size = RESULT_MESSAGE_SIZE
	label.position = _get_callout_position(0)
	label.pivot_offset = RESULT_MESSAGE_SIZE * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.scale = Vector2.ONE * CALLOUT_START_SCALE
	label.modulate = Color(1, 1, 1, 0)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	label.add_theme_color_override("font_shadow_color", Color(0.07, 0.03, 0.01, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.29, 0.15, 0.08, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 34)
	return label


func _animate_new_callout(callout: ResultCallout) -> void:
	var label: Label = callout.label
	var tween: Tween = create_tween()
	callout.drift_tween = tween
	tween.set_parallel(true)
	tween.tween_property(
		label,
		"scale",
		Vector2.ONE * CALLOUT_PEAK_SCALE,
		CALLOUT_LIFETIME * 0.32
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, CALLOUT_LIFETIME * 0.18)
	tween.chain().tween_property(
		label,
		"modulate:a",
		0.0,
		CALLOUT_LIFETIME * 0.36
	).set_delay(CALLOUT_LIFETIME * 0.46)
	tween.chain().tween_callback(_remove_result_callout.bind(callout))


func _update_callout_stack_positions() -> void:
	for index in range(active_result_callouts.size()):
		var callout: ResultCallout = active_result_callouts[index]
		callout.stack_index = index
		_move_callout_to_slot(callout)


func _move_callout_to_slot(callout: ResultCallout) -> void:
	if not is_instance_valid(callout.label):
		return

	if callout.slot_tween != null and callout.slot_tween.is_running():
		callout.slot_tween.kill()

	callout.slot_tween = create_tween()
	callout.slot_tween.tween_property(
		callout.label,
		"position",
		_get_callout_position(callout.stack_index),
		CALLOUT_SHIFT_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _get_callout_position(stack_index: int) -> Vector2:
	var center_position: Vector2 = RESULT_MESSAGE_POSITION + Vector2.UP * CALLOUT_STACK_SPACING * stack_index
	return center_position - RESULT_MESSAGE_SIZE * 0.5


func _trim_result_callouts() -> void:
	while active_result_callouts.size() > CALLOUT_MAX_ACTIVE:
		var callout: ResultCallout = active_result_callouts.pop_back()
		_remove_result_callout(callout)


func _remove_result_callout(callout: ResultCallout) -> void:
	active_result_callouts.erase(callout)
	if is_instance_valid(callout.label):
		callout.label.queue_free()
	_update_callout_stack_positions()


func _all_balls_stopped() -> bool:
	if not pending_spawn_requests.is_empty():
		return false

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.visible and ball.is_moving():
			return false

	return true


func _award_base_spawn_progress() -> void:
	pocketed_object_ball_spawn_progress += 1
	if pocketed_object_ball_spawn_progress < BALLS_PER_REWARD_DROP:
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
	_queue_result_message("BANK SHOT")
	_queue_spawn_reward(1)


func _queue_spawn_reward(spawn_count: int) -> void:
	for _spawn_index in range(spawn_count):
		var request: SpawnBallRequest = _make_spawn_ball_request()
		pending_spawn_requests.append(request)
		_queue_spawn_reward_message(request)


func _process_spawn_queue(delta: float) -> void:
	if pending_spawn_requests.is_empty():
		spawn_drop_cooldown = 0.0
		return

	spawn_drop_cooldown = max(spawn_drop_cooldown - delta, 0.0)
	if spawn_drop_cooldown > 0.0:
		return

	var request: SpawnBallRequest = pending_spawn_requests.pop_front() as SpawnBallRequest
	_spawn_next_reward_ball(request)
	spawn_drop_cooldown = SPAWN_DROP_STAGGER


func _spawn_next_reward_ball(request: SpawnBallRequest) -> void:
	var spawn_position: Vector2 = _find_safe_spawn_position(cue_ball.radius)
	var ball: Ball
	if request.is_wayfinder:
		ball = _create_wayfinder_ball(request.ball_number, _ball_color(request.ball_number), spawn_position)
	else:
		ball = _create_ball(Ball.BallType.OBJECT, request.ball_number, _ball_color(request.ball_number), spawn_position)
	ball.begin_spawn_drop(spawn_position)


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

	return PLAYFIELD_RECT.get_center()


func _get_random_spawn_search_center() -> Vector2:
	var radius: float = randf_range(SPAWN_RANDOM_RADIUS_MIN, SPAWN_RANDOM_RADIUS_MAX)
	var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var candidate: Vector2 = SPAWN_SEARCH_CENTER + direction * radius
	return candidate.clamp(PLAYFIELD_RECT.position, PLAYFIELD_RECT.end)


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
