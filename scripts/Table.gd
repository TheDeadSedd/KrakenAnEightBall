@tool
extends Node2D
class_name BilliardsTable

signal status_text_changed(text: String)
signal game_finished(text: String)

#region Data Containers
# Lightweight data carriers owned by Table.gd for now.
# Extraction note: AimPreview now owns prediction/debug path containers.
class BallMotionState:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var rail_position := Vector2.ZERO
	var rail_normal := Vector2.ZERO
	var hit_rail := false

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
#endregion

#region Constants / Config
# Central tuning for the current prototype. Future extractions should copy only
# their own values into CueController, AimPreview, BallPhysics, SpawnSystem, etc.
# Debug and testing helpers.
# Pre-alpha testing mode: cue-ball and 8-ball sinks reset instead of ending the run.
const DEBUG_NO_GAME_OVER := true
const DEBUG_DRAW_BOUNDARY_RECTS := false
const DEBUG_PHYSICS_PANEL_ENABLED := true
const DEBUG_SHOT_POWER := false
const DEBUG_WAYFINDER := false
# Testing shortcut: press F to drop a Wayfinder without waiting for random reward spawns.
const DEBUG_SPAWN_WAYFINDER_ENABLED := true
const DEBUG_SPAWN_WAYFINDER_KEY := KEY_F
# Testing shortcut: press G to drop a normal object ball without changing reward rules.
const DEBUG_SPAWN_NORMAL_BALL_ENABLED := true
const DEBUG_SPAWN_NORMAL_BALL_KEY := KEY_G

const BALL_SCENE := preload("res://scenes/Ball.tscn")
const CUE_BALL_SCENE := preload("res://scenes/CueBall.tscn")
const SHIP_FLOOR_TEXTURE := preload("res://assets/table_art/ship_floor.png")
const TABLE_FRAME_TEXTURE := preload("res://assets/table_art/pool_table_frame.png")
const KRAKEN_SILHOUETTE_TEXTURE := preload("res://assets/table_art/kraken_silhouette.png")
const UI_FONT := preload("res://assets/fonts/Gothic Pixels.ttf")

# Presentation layout. The underlying table dimensions stay the same; the whole play space is centered in a larger 1920x1080 canvas.
const PRESENTATION_OFFSET_X := 360.0
const PRESENTATION_OFFSET_Y := 180.0

# Table bounds. Drawing uses the full table rect; spawn helpers fall back to a simple reference rect if scene geometry is missing.
const TABLE_LEFT := PRESENTATION_OFFSET_X + 40.0
const TABLE_TOP := PRESENTATION_OFFSET_Y + 40.0
const TABLE_RIGHT := PRESENTATION_OFFSET_X + 1160.0
const TABLE_BOTTOM := PRESENTATION_OFFSET_Y + 680.0
const TABLE_OUTER_RECT := Rect2(TABLE_LEFT, TABLE_TOP, TABLE_RIGHT - TABLE_LEFT, TABLE_BOTTOM - TABLE_TOP)
const SPAWN_REFERENCE_RECT := Rect2(
	PRESENTATION_OFFSET_X + 94.0,
	PRESENTATION_OFFSET_Y + 94.0,
	1106.0 - 94.0,
	626.0 - 94.0
)
const PRESENTATION_MARGIN_LEFT := 120.0
const PRESENTATION_MARGIN_RIGHT := 120.0
const PRESENTATION_MARGIN_TOP := 80.0
const PRESENTATION_MARGIN_BOTTOM := 120.0
const TABLE_FRAME_VISIBLE_BOUNDS := Rect2(311, 130, 1294, 794)
const KRAKEN_ART_ALPHA := 0.18
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

# Shot controls and cue aim input.
const MAX_DRAG_DISTANCE := 210.0
const MIN_SHOT_DISTANCE := 12.0
const SHOT_POWER := 9.4
const CUE_AIM_DEADZONE_RADIUS := 20.0

# Arcade physics tuning.
const BALL_COLLISION_RESTITUTION := 0.86
const BALL_VELOCITY_TRANSFER := 0.90
const BALL_COLLISION_SKIN := 1.5
const RAIL_RESTITUTION := 0.78
const RESET_SEARCH_STEP := 22.0
const RESET_SEARCH_RINGS := 8
const PHYSICS_SUBSTEPS := 4
const BALL_COLLISION_GRID_CELL_SIZE := 56.0
const PHYSICS_DEBUG_SPEED_THRESHOLD := 5.0
const PHYSICS_DEBUG_MAX_BALLS := 10
#endregion

#region Cached Node References
# Scene-authored nodes stay the source of truth for geometry and cue art.
# Future extraction: TableGeometry can own boundaries_root/pockets_root.
@onready var balls: Node2D = $Balls
@onready var boundaries_root: Node = get_node_or_null("Boundaries")
@onready var pockets_root: Node = get_node_or_null("Pockets")
@onready var aim_preview: AimPreview = $AimPreview
@onready var cue_controller: CueController = $CuePivot
#endregion

#region Runtime State
# Table.gd currently owns all run state. These clusters mark natural future
# owners: DebugOverlay, CueController, PocketSystem, WayfinderSystem, SpawnSystem.
var active_result_callouts: Array[ResultCallout] = []
var pending_callout_messages: Array[String] = []
var callout_spawn_cooldown := 0.0
var cue_ball: Ball
var eight_ball: Ball
var eight_start := Vector2.ZERO
var drag_start_mouse_position := Vector2.ZERO
var drag_start_drag_vector := Vector2.ZERO
var drag_aim_direction := Vector2.RIGHT
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
var table_frame_art_rect := Rect2()
var playfield_rect := Rect2()
var pocket_positions: Array[Vector2] = []
var pocket_radii: Array[float] = []
var boundary_shapes: Array[CollisionShape2D] = []
var boundary_reference_rects: Array[Rect2] = []
# Only redirected Wayfinder-target pairs use this brief ignore window.
var wayfinder_redirect_collision_cooldowns: Dictionary = {}
var guided_wayfinder_balls: Dictionary = {}
var perf_ball_pair_checks := 0
var perf_broadphase_candidate_pairs := 0
var perf_spatial_grid_cells := 0
var perf_spatial_grid_max_cell_size := 0
var perf_ball_collisions_resolved := 0
var perf_rail_checks := 0
var perf_rail_collisions_resolved := 0
var perf_pocket_checks := 0
var perf_pocket_captures := 0
var perf_physics_process_ms := 0.0
var perf_ball_collision_ms := 0.0
var perf_rail_collision_ms := 0.0
var perf_pocket_check_ms := 0.0
#endregion


#region Setup / Main Loop
# Owns startup, per-frame orchestration, and update order.
# Future extraction: this can become a thin coordinator after systems split.
func _ready() -> void:
	_cache_table_geometry()
	aim_preview.setup(self)
	cue_controller.setup()
	if Engine.is_editor_hint():
		cue_controller.update_cue(cue_ball, false, is_dragging, Vector2.ZERO, MAX_DRAG_DISTANCE, game_over, 0.0)
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

	var physics_start_usec: int = Time.get_ticks_usec()
	_reset_performance_frame_stats()
	_update_wayfinder_redirect_cooldowns(delta)
	aim_preview.update_debug(delta, is_dragging)

	var step_delta: float = delta / float(PHYSICS_SUBSTEPS)
	for _step in range(PHYSICS_SUBSTEPS):
		_update_wayfinder_guidance(step_delta)
		_move_balls(step_delta)
		var phase_start_usec: int = Time.get_ticks_usec()
		_resolve_ball_collisions()
		perf_ball_collision_ms += _elapsed_ms_since(phase_start_usec)
		phase_start_usec = Time.get_ticks_usec()
		if _handle_pocket_checks():
			perf_pocket_check_ms += _elapsed_ms_since(phase_start_usec)
			break
		perf_pocket_check_ms += _elapsed_ms_since(phase_start_usec)
		phase_start_usec = Time.get_ticks_usec()
		_resolve_rail_collisions()
		perf_rail_collision_ms += _elapsed_ms_since(phase_start_usec)
		aim_preview.record_actual_path_step()
		_apply_ball_friction(step_delta)

	_process_spawn_queue(delta)
	_process_callout_queue(delta)
	_try_finish_shot()
	cue_controller.update_cue(cue_ball, _can_shoot(), is_dragging, _get_current_shot_drag_vector(), MAX_DRAG_DISTANCE, game_over, delta)
	_refresh_aim_preview()

	perf_physics_process_ms = _elapsed_ms_since(physics_start_usec)
#endregion


#region Input Dispatch
# Routes raw mouse/touch/debug keys. Cue-specific behavior stays in Cue Controller below.
func _unhandled_input(event: InputEvent) -> void:
	if game_over or not is_instance_valid(cue_ball):
		return

	if _try_debug_spawn_ball(event):
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_start_drag(event.position)
		else:
			_release_shot(event.position)
	elif event is InputEventMouseMotion and is_dragging:
		drag_mouse_position = event.position
		_refresh_aim_preview()
		queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_try_start_drag(event.position)
		else:
			_release_shot(event.position)
	elif event is InputEventScreenDrag and is_dragging:
		drag_mouse_position = event.position
		_refresh_aim_preview()
		queue_redraw()


func _try_debug_spawn_ball(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return false

	if DEBUG_SPAWN_WAYFINDER_ENABLED and key_event.keycode == DEBUG_SPAWN_WAYFINDER_KEY:
		_queue_debug_wayfinder_spawn()
		return true

	if DEBUG_SPAWN_NORMAL_BALL_ENABLED and key_event.keycode == DEBUG_SPAWN_NORMAL_BALL_KEY:
		_queue_debug_normal_ball_spawn()
		return true

	return false
#endregion


#region Drawing / Art Presentation
# Draws ship/table art and boundary debug. AimPreview owns aim/path drawing now.
# Future extraction: TableArt.
func _draw() -> void:
	_ensure_table_geometry_cached()
	_draw_table_art()
	_draw_collision_debug()


func _draw_table_art() -> void:
	var presentation_rect: Rect2 = get_presentation_rect()
	draw_texture_rect(SHIP_FLOOR_TEXTURE, presentation_rect, false)
	draw_rect(presentation_rect, Color(0, 0, 0, 0.18), true)
	_draw_kraken_felt_art()
	draw_texture_rect(TABLE_FRAME_TEXTURE, table_frame_art_rect, false)


func _draw_kraken_felt_art() -> void:
	var kraken_rect: Rect2 = _fit_texture_rect_inside(KRAKEN_SILHOUETTE_TEXTURE, playfield_rect.grow(-54.0))
	draw_texture_rect(
		KRAKEN_SILHOUETTE_TEXTURE,
		kraken_rect,
		false,
		Color(0.88, 0.94, 0.92, KRAKEN_ART_ALPHA)
	)


func _draw_collision_debug() -> void:
	if Engine.is_editor_hint() or not DEBUG_DRAW_BOUNDARY_RECTS:
		return

	for boundary_rect in boundary_reference_rects:
		draw_rect(boundary_rect, Color(1, 0.22, 0.12, 0.22), true)
		draw_rect(boundary_rect, Color(1, 0.35, 0.2, 0.9), false, 2.0)


#endregion


#region Table Geometry / Pockets Cache
# Reads scene-authored boundaries and pockets. Future extraction: TableGeometry
# plus PocketSystem for pocket center/radius ownership.
func _cache_table_geometry() -> void:
	table_frame_art_rect = _calculate_table_frame_art_rect()
	playfield_rect = SPAWN_REFERENCE_RECT
	pocket_positions.clear()
	pocket_radii.clear()
	boundary_shapes.clear()
	boundary_reference_rects.clear()

	_build_pocket_positions()
	_build_rail_debug_rects()
	_cache_boundary_reference_rect()


func _ensure_table_geometry_cached() -> void:
	if table_frame_art_rect.size == Vector2.ZERO or playfield_rect.size == Vector2.ZERO:
		_cache_table_geometry()


func _build_pocket_positions() -> void:
	if pockets_root == null:
		return

	for child in pockets_root.get_children():
		var pocket_node := child as Node2D
		if pocket_node == null:
			continue

		var collision_shape: CollisionShape2D = pocket_node.get_node_or_null("CollisionShape2D")
		if collision_shape == null:
			continue

		var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
		if circle_shape == null:
			continue

		pocket_positions.append(collision_shape.global_position)
		pocket_radii.append(circle_shape.radius)


func _build_rail_debug_rects() -> void:
	if boundaries_root == null:
		return

	for shape_node in boundaries_root.find_children("*", "CollisionShape2D", true, false):
		var collision_shape := shape_node as CollisionShape2D
		if collision_shape == null:
			continue
		if collision_shape.shape is RectangleShape2D:
			boundary_shapes.append(collision_shape)
			_add_boundary_reference_rect(collision_shape)


func _add_boundary_reference_rect(collision_shape: CollisionShape2D) -> void:
	var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return

	var half_size: Vector2 = rectangle_shape.size * 0.5
	var transform_2d: Transform2D = collision_shape.global_transform
	var corners := [
		transform_2d * Vector2(-half_size.x, -half_size.y),
		transform_2d * Vector2(half_size.x, -half_size.y),
		transform_2d * Vector2(half_size.x, half_size.y),
		transform_2d * Vector2(-half_size.x, half_size.y),
	]
	var bounds := Rect2(corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(corner)
	boundary_reference_rects.append(bounds)


func _cache_boundary_reference_rect() -> void:
	var boundary_rect: Rect2 = _get_boundary_inner_rect()
	if boundary_rect.size != Vector2.ZERO:
		playfield_rect = boundary_rect


func _get_boundary_inner_rect() -> Rect2:
	if boundary_shapes.is_empty():
		return Rect2()

	var overall_bounds: Rect2 = boundary_reference_rects[0]
	for boundary_rect in boundary_reference_rects:
		overall_bounds = overall_bounds.merge(boundary_rect)

	var center: Vector2 = overall_bounds.get_center()
	var left_inner := -INF
	var right_inner := INF
	var top_inner := -INF
	var bottom_inner := INF

	for boundary_rect in boundary_reference_rects:
		if boundary_rect.size.x >= boundary_rect.size.y:
			if boundary_rect.get_center().y < center.y:
				top_inner = max(top_inner, boundary_rect.end.y)
			else:
				bottom_inner = min(bottom_inner, boundary_rect.position.y)
		else:
			if boundary_rect.get_center().x < center.x:
				left_inner = max(left_inner, boundary_rect.end.x)
			else:
				right_inner = min(right_inner, boundary_rect.position.x)

	if left_inner == -INF or right_inner == INF or top_inner == -INF or bottom_inner == INF:
		return Rect2()
	if right_inner <= left_inner or bottom_inner <= top_inner:
		return Rect2()

	return Rect2(left_inner, top_inner, right_inner - left_inner, bottom_inner - top_inner)


func get_presentation_rect() -> Rect2:
	return Rect2(
		TABLE_LEFT - PRESENTATION_MARGIN_LEFT,
		TABLE_TOP - PRESENTATION_MARGIN_TOP,
		(TABLE_RIGHT - TABLE_LEFT) + PRESENTATION_MARGIN_LEFT + PRESENTATION_MARGIN_RIGHT,
		(TABLE_BOTTOM - TABLE_TOP) + PRESENTATION_MARGIN_TOP + PRESENTATION_MARGIN_BOTTOM
	)


func _calculate_table_frame_art_rect() -> Rect2:
	var texture_size: Vector2 = TABLE_FRAME_TEXTURE.get_size()
	var scale_x: float = TABLE_OUTER_RECT.size.x / TABLE_FRAME_VISIBLE_BOUNDS.size.x
	var scale_y: float = TABLE_OUTER_RECT.size.y / TABLE_FRAME_VISIBLE_BOUNDS.size.y
	return Rect2(
		TABLE_OUTER_RECT.position.x - TABLE_FRAME_VISIBLE_BOUNDS.position.x * scale_x,
		TABLE_OUTER_RECT.position.y - TABLE_FRAME_VISIBLE_BOUNDS.position.y * scale_y,
		texture_size.x * scale_x,
		texture_size.y * scale_y
	)


func _fit_texture_rect_inside(texture: Texture2D, container: Rect2) -> Rect2:
	var texture_size: Vector2 = texture.get_size()
	var scale: float = min(container.size.x / texture_size.x, container.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * scale
	return Rect2(container.get_center() - draw_size * 0.5, draw_size)
#endregion


#region Starting Layout / Ball Factory
# Creates the cue ball and deterministic rack. Future extraction: RackSetup or SpawnSystem.
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
#endregion


#region Ball Physics / Collision
# Owns arcade movement, friction calls, and collision response.
# Future extraction candidate: BallPhysics.
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
	if active_balls.is_empty():
		return

	var spatial_grid: Dictionary = _build_ball_collision_grid(active_balls)
	var checked_pairs := {}
	for ball in active_balls:
		if not ball.is_moving():
			continue
		_resolve_ball_against_neighbor_cells(ball, spatial_grid, checked_pairs)


func _get_active_balls() -> Array[Ball]:
	var active_balls: Array[Ball] = []
	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_gameplay_active():
			active_balls.append(ball)
	return active_balls


#region Spatial Grid / Broad-Phase
# Buckets active balls so BallPhysics only resolves nearby moving pairs.
# Future extraction candidate: BallPhysics broad-phase helper.
func _build_ball_collision_grid(active_balls: Array[Ball]) -> Dictionary:
	var spatial_grid := {}
	for ball in active_balls:
		var cell: Vector2i = _get_ball_collision_grid_cell(ball.global_position)
		if not spatial_grid.has(cell):
			spatial_grid[cell] = []
		spatial_grid[cell].append(ball)
		perf_spatial_grid_max_cell_size = maxi(perf_spatial_grid_max_cell_size, spatial_grid[cell].size())

	perf_spatial_grid_cells = spatial_grid.size()
	return spatial_grid


func _resolve_ball_against_neighbor_cells(ball: Ball, spatial_grid: Dictionary, checked_pairs: Dictionary) -> void:
	var center_cell: Vector2i = _get_ball_collision_grid_cell(ball.global_position)
	for x_offset in range(-1, 2):
		for y_offset in range(-1, 2):
			var neighbor_cell := center_cell + Vector2i(x_offset, y_offset)
			if not spatial_grid.has(neighbor_cell):
				continue
			_resolve_ball_against_cell(ball, spatial_grid[neighbor_cell], checked_pairs)


func _resolve_ball_against_cell(ball: Ball, cell_balls: Array, checked_pairs: Dictionary) -> void:
	for other_ball in cell_balls:
		var target_ball := other_ball as Ball
		if target_ball == null or target_ball == ball:
			continue

		var pair_key: String = _get_ball_pair_key(ball, target_ball)
		if checked_pairs.has(pair_key):
			continue

		checked_pairs[pair_key] = true
		perf_broadphase_candidate_pairs += 1
		_resolve_ball_pair(ball, target_ball)


func _get_ball_collision_grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(
		floori(position.x / BALL_COLLISION_GRID_CELL_SIZE),
		floori(position.y / BALL_COLLISION_GRID_CELL_SIZE)
	)


func _get_ball_pair_key(ball_a: Ball, ball_b: Ball) -> String:
	var first_id: int = ball_a.get_instance_id()
	var second_id: int = ball_b.get_instance_id()
	if first_id > second_id:
		var temp_id: int = first_id
		first_id = second_id
		second_id = temp_id
	return "%s:%s" % [first_id, second_id]
#endregion


func _resolve_ball_pair(ball_a: Ball, ball_b: Ball) -> void:
	perf_ball_pair_checks += 1
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

	if _apply_ball_collision_response(ball_a, ball_b, normal):
		perf_ball_collisions_resolved += 1
	_note_actual_cue_ball_hit(ball_a, ball_b)
	_handle_wayfinder_cue_activation(ball_a, ball_b)
	_try_begin_wayfinder_guidance(ball_a, ball_b)
	_try_begin_wayfinder_guidance(ball_b, ball_a)


func _separate_overlapping_balls(ball_a: Ball, ball_b: Ball, normal: Vector2, overlap: float) -> void:
	var correction: Vector2 = normal * (overlap * 0.5 + 0.01)
	ball_a.global_position -= correction
	ball_b.global_position += correction


func _apply_ball_collision_response(ball_a: Ball, ball_b: Ball, normal: Vector2) -> bool:
	var relative_velocity: Vector2 = ball_a.velocity - ball_b.velocity
	var speed_along_normal: float = relative_velocity.dot(normal)
	if speed_along_normal <= 0.0:
		return false

	var impulse_strength: float = (1.0 + BALL_COLLISION_RESTITUTION) * speed_along_normal * 0.5
	impulse_strength *= BALL_VELOCITY_TRANSFER
	var impulse: Vector2 = normal * impulse_strength
	ball_a.velocity -= impulse
	ball_b.velocity += impulse
	return true


func _note_actual_cue_ball_hit(ball_a: Ball, ball_b: Ball) -> void:
	if ball_a != cue_ball and ball_b != cue_ball:
		return

	aim_preview.note_actual_cue_ball_hit()
#endregion


#region Wayfinder
# Owns activation, guidance targeting, and redirect cooldowns.
# Future extraction candidate: WayfinderSystem.
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
#endregion


#region Boundaries / Rails
# Resolves scene-authored rail collision for moving balls.
# Future extraction candidate: TableGeometry or RailCollision.
func _resolve_rail_collisions() -> void:
	if boundary_shapes.is_empty():
		return

	for ball in _get_moving_active_balls():
		for boundary_shape in boundary_shapes:
			perf_rail_checks += 1
			_resolve_ball_against_boundary_shape(ball, boundary_shape)
#endregion


#region Pockets / Pocket Capture
# Scene-authored pocket circles decide when balls sink.
# Future extraction candidate: PocketSystem.
func _handle_pocket_checks() -> bool:
	for ball in _get_moving_active_balls():
		for pocket_index in range(pocket_positions.size()):
			perf_pocket_checks += 1
			var pocket_position: Vector2 = pocket_positions[pocket_index]
			var catch_radius: float = _get_pocket_catch_radius(pocket_radii[pocket_index], ball.radius)
			if ball.global_position.distance_to(pocket_position) <= catch_radius:
				perf_pocket_captures += 1
				_handle_pocketed_ball(ball)
				return true

	return false


func _get_moving_active_balls() -> Array[Ball]:
	var moving_balls: Array[Ball] = []
	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_gameplay_active() and ball.is_moving():
			moving_balls.append(ball)
	return moving_balls


func _get_pocket_catch_radius(pocket_radius: float, ball_radius: float) -> float:
	return pocket_radius + ball_radius * 0.5 + POCKET_CATCH_BONUS
#endregion


#region Debug Data Generation
# Maintains gameplay counters consumed by DebugOverlay.gd.
# No debug UI ownership should live in Table.gd after this extraction.
func _reset_performance_frame_stats() -> void:
	perf_ball_pair_checks = 0
	perf_broadphase_candidate_pairs = 0
	perf_spatial_grid_cells = 0
	perf_spatial_grid_max_cell_size = 0
	perf_ball_collisions_resolved = 0
	perf_rail_checks = 0
	perf_rail_collisions_resolved = 0
	perf_pocket_checks = 0
	perf_pocket_captures = 0
	perf_physics_process_ms = 0.0
	perf_ball_collision_ms = 0.0
	perf_rail_collision_ms = 0.0
	perf_pocket_check_ms = 0.0


func _elapsed_ms_since(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0
#endregion


#region Boundary Collision Helpers
# Real ball-vs-boundary collision. AimPreview mirrors this response for dry-run banks.
func _resolve_ball_against_boundary_shape(ball: Ball, collision_shape: CollisionShape2D) -> void:
	var incoming_velocity: Vector2 = ball.velocity
	var step_result: BallMotionState = BallMotionState.new()
	step_result.position = ball.global_position
	step_result.velocity = ball.velocity
	_resolve_boundary_collision_for_state(step_result, collision_shape, ball.radius)
	ball.global_position = step_result.position
	ball.velocity = step_result.velocity

	if step_result.hit_rail:
		perf_rail_collisions_resolved += 1
		_note_cue_rail_touch(ball)
		aim_preview.record_actual_bank_debug(ball, ball.global_position, incoming_velocity, step_result.rail_normal, shot_active)


func _resolve_boundary_collision_for_state(
	step_result: BallMotionState,
	collision_shape: CollisionShape2D,
	ball_radius: float
) -> void:
	var rectangle_shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if rectangle_shape == null:
		return

	var shape_transform: Transform2D = collision_shape.global_transform
	var local_position: Vector2 = shape_transform.affine_inverse() * step_result.position
	var half_size: Vector2 = rectangle_shape.size * 0.5
	var closest_local: Vector2 = local_position.clamp(-half_size, half_size)
	var distance: float = local_position.distance_to(closest_local)
	if distance >= ball_radius:
		return

	_apply_boundary_response_to_state(
		step_result,
		shape_transform,
		local_position,
		closest_local,
		half_size,
		distance,
		ball_radius
	)


func _apply_boundary_response_to_state(
	step_result: BallMotionState,
	shape_transform: Transform2D,
	local_position: Vector2,
	closest_local: Vector2,
	half_size: Vector2,
	distance: float,
	ball_radius: float
) -> void:
	var normal_local: Vector2 = _get_boundary_collision_normal_local(local_position, closest_local, half_size, distance)
	var normal_world: Vector2 = shape_transform.basis_xform(normal_local).normalized()
	step_result.position += normal_world * (ball_radius - distance + 0.01)

	var normal_speed: float = step_result.velocity.dot(normal_world)
	if normal_speed >= 0.0:
		return

	step_result.velocity -= normal_world * (1.0 + RAIL_RESTITUTION) * normal_speed
	if not step_result.hit_rail:
		step_result.hit_rail = true
		step_result.rail_position = step_result.position
		step_result.rail_normal = normal_world


func _get_boundary_collision_normal_local(
	local_ball_position: Vector2,
	closest_local: Vector2,
	half_size: Vector2,
	distance: float
) -> Vector2:
	if distance > 0.0:
		return delta_local_direction(local_ball_position, closest_local)

	var distance_to_left: float = abs(local_ball_position.x + half_size.x)
	var distance_to_right: float = abs(half_size.x - local_ball_position.x)
	var distance_to_top: float = abs(local_ball_position.y + half_size.y)
	var distance_to_bottom: float = abs(half_size.y - local_ball_position.y)
	var nearest_face: float = min(distance_to_left, distance_to_right, distance_to_top, distance_to_bottom)
	if nearest_face == distance_to_left:
		return Vector2.LEFT
	if nearest_face == distance_to_right:
		return Vector2.RIGHT
	if nearest_face == distance_to_top:
		return Vector2.UP
	return Vector2.DOWN


func delta_local_direction(local_ball_position: Vector2, closest_local: Vector2) -> Vector2:
	return (local_ball_position - closest_local).normalized()
#endregion


#region Wayfinder Guidance
# Continued Wayfinder helpers kept together for future WayfinderSystem extraction.
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
#endregion


#region Cue Input / Shot Release
# Table owns shot state and velocity. CueController owns sprite visuals and cue hit testing.
func _try_start_drag(mouse_position: Vector2) -> void:
	if not _can_shoot():
		return

	if not cue_controller.is_point_over_grab_zone(mouse_position, cue_ball, MAX_DRAG_DISTANCE):
		return

	is_dragging = true
	cue_controller.stop_recoil()
	drag_start_mouse_position = mouse_position
	drag_start_drag_vector = cue_ball.global_position - mouse_position
	drag_aim_direction = _get_initial_drag_aim_direction()
	drag_mouse_position = mouse_position
	_refresh_aim_preview()
	queue_redraw()


func _release_shot(_mouse_position: Vector2) -> void:
	if not is_dragging:
		return

	var release_position: Vector2 = drag_mouse_position
	var drag_vector: Vector2 = _get_drag_vector(release_position)
	var release_pullback: float = cue_controller.get_pullback_for_drag_vector(drag_vector, MAX_DRAG_DISTANCE)
	var release_direction: Vector2 = drag_vector.normalized()
	is_dragging = false
	if drag_vector.length() < MIN_SHOT_DISTANCE:
		cue_controller.stop_recoil()
		_refresh_aim_preview()
		queue_redraw()
		return

	if release_direction != Vector2.ZERO:
		aim_preview.start_path_comparison(cue_ball.global_position, drag_vector * SHOT_POWER)
	cue_ball.velocity = drag_vector * SHOT_POWER
	var release_rotation: float = release_direction.angle() if release_direction != Vector2.ZERO else cue_controller.get_rotation_angle()
	cue_controller.begin_recoil(cue_ball.global_position, release_rotation, release_pullback)
	_print_shot_power_debug(drag_vector, release_position)
	_start_shot_tracking()
	status_text_changed.emit("Shot taken. Wait for the balls to settle before shooting again.")
	_refresh_aim_preview()
	queue_redraw()


func _get_drag_vector(mouse_position: Vector2) -> Vector2:
	if is_dragging:
		return _get_grab_relative_drag_vector(mouse_position)

	var drag_vector: Vector2 = cue_ball.global_position - mouse_position
	return drag_vector.limit_length(MAX_DRAG_DISTANCE)


func _get_initial_drag_aim_direction() -> Vector2:
	if drag_start_drag_vector.length() > 0.0:
		return drag_start_drag_vector.normalized()

	return Vector2.RIGHT.rotated(cue_controller.get_rotation_angle())


func _get_grab_relative_drag_vector(mouse_position: Vector2) -> Vector2:
	var cue_to_mouse: Vector2 = mouse_position - cue_ball.global_position
	var mouse_distance: float = cue_to_mouse.length()
	if mouse_distance <= CUE_AIM_DEADZONE_RADIUS:
		# Near the cue ball, keep the last aim direction and drop power to zero.
		return Vector2.ZERO

	drag_aim_direction = (-cue_to_mouse).normalized()
	var neutral_grab_distance: float = drag_start_mouse_position.distance_to(cue_ball.global_position)
	var pullback_distance: float = max(mouse_distance - neutral_grab_distance, 0.0)
	return (drag_aim_direction * pullback_distance).limit_length(MAX_DRAG_DISTANCE)


func _get_current_shot_drag_vector() -> Vector2:
	if not is_dragging:
		return Vector2.ZERO

	return _get_drag_vector(drag_mouse_position)


func _refresh_aim_preview() -> void:
	if not is_dragging or not _can_shoot():
		aim_preview.update_preview(false, Vector2.ZERO, Vector2.ZERO, SHOT_POWER, 0.0)
		return

	var drag_vector: Vector2 = _get_drag_vector(drag_mouse_position)
	var power_ratio: float = clamp(drag_vector.length() / MAX_DRAG_DISTANCE, 0.0, 1.0)
	aim_preview.update_preview(true, cue_ball.global_position, drag_vector, SHOT_POWER, power_ratio)


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
#endregion


#region Shot State / Pocket Consequences
# Owns shot lifecycle, pocket outcomes, and reward triggers after pocket captures.
# Future extraction candidates: PocketSystem plus SpawnSystem reward rules.
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
	_note_actual_cue_pocketed(ball)

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


func _note_actual_cue_pocketed(ball: Ball) -> void:
	aim_preview.note_actual_cue_pocketed(ball)


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
	aim_preview.stop_actual_path_recording()
#endregion


#region Debug Data API
# Public data surface used by DebugOverlay.gd. Table still owns the counters;
# DebugOverlay owns visibility, panel movement, and text formatting.
func get_physics_debug_snapshot() -> Dictionary:
	var moving_balls: Array[Dictionary] = []
	for child in balls.get_children():
		var ball := child as Ball
		if ball == null or ball.velocity.length() < PHYSICS_DEBUG_SPEED_THRESHOLD:
			continue
		moving_balls.append(_get_ball_debug_snapshot(ball))

	return {
		"enabled": DEBUG_PHYSICS_PANEL_ENABLED,
		"speed_threshold": PHYSICS_DEBUG_SPEED_THRESHOLD,
		"max_balls": PHYSICS_DEBUG_MAX_BALLS,
		"moving_balls": moving_balls,
	}


func get_performance_debug_snapshot() -> Dictionary:
	var counts: Dictionary = _get_performance_ball_counts()
	return {
		"total_balls": counts["total"],
		"moving_balls": counts["moving"],
		"stopped_balls": counts["stopped"],
		"active_wayfinders": counts["active_wayfinders"],
		"guided_wayfinder_targets": guided_wayfinder_balls.size(),
		"physics_substeps": PHYSICS_SUBSTEPS,
		"spatial_grid_cells": perf_spatial_grid_cells,
		"spatial_grid_max_cell_size": perf_spatial_grid_max_cell_size,
		"broadphase_candidate_pairs": perf_broadphase_candidate_pairs,
		"ball_pair_checks": perf_ball_pair_checks,
		"ball_collisions_resolved": perf_ball_collisions_resolved,
		"rail_checks": perf_rail_checks,
		"rail_collisions_resolved": perf_rail_collisions_resolved,
		"pocket_checks": perf_pocket_checks,
		"pocket_captures": perf_pocket_captures,
		"aim_prediction_enabled": aim_preview.is_prediction_enabled(),
		"shot_comparison_enabled": aim_preview.is_shot_path_debug_enabled(),
		"physics_process_ms": perf_physics_process_ms,
		"ball_collision_ms": perf_ball_collision_ms,
		"rail_collision_ms": perf_rail_collision_ms,
		"pocket_check_ms": perf_pocket_check_ms,
		"aim_prediction_ms": aim_preview.get_prediction_time_ms(),
	}


func _get_performance_ball_counts() -> Dictionary:
	var counts := {
		"total": 0,
		"moving": 0,
		"stopped": 0,
		"active_wayfinders": 0,
	}

	for child in balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.visible:
			continue
		counts["total"] += 1
		counts["moving"] += 1 if ball.is_moving() else 0
		counts["active_wayfinders"] += 1 if ball.is_wayfinder and ball.wayfinder_active else 0

	counts["stopped"] = max(counts["total"] - counts["moving"], 0)
	return counts


func _get_ball_debug_snapshot(ball: Ball) -> Dictionary:
	return {
		"ball_number": ball.ball_number,
		"is_cue_ball": ball == cue_ball,
		"is_eight_ball": ball == eight_ball,
		"is_wayfinder": ball.is_wayfinder,
		"wayfinder_active": ball.is_wayfinder and ball.wayfinder_active,
		"guided": guided_wayfinder_balls.has(ball.get_instance_id()),
		"gameplay_enabled": ball.gameplay_enabled,
		"speed": ball.velocity.length(),
		"medium_speed_drag_start": ball.medium_speed_drag_start,
		"low_speed_drag_start": ball.low_speed_drag_start,
		"crawl_speed_drag_start": ball.crawl_speed_drag_start,
	}


func set_shot_path_debug_enabled(enabled: bool) -> void:
	aim_preview.set_shot_path_debug_enabled(enabled)


func is_shot_path_debug_enabled() -> bool:
	return aim_preview.is_shot_path_debug_enabled()


func get_debug_spawn_hotkey_data() -> Dictionary:
	return {
		"wayfinder_spawn_key": DEBUG_SPAWN_WAYFINDER_KEY,
		"normal_spawn_key": DEBUG_SPAWN_NORMAL_BALL_KEY,
	}
#endregion


#region Callouts / Notifications
# Owns arcade event callouts only; reward spawning is separated below.
# Future extraction candidate: HUD/CalloutSystem.
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


func _queue_debug_normal_ball_spawn() -> void:
	var request: SpawnBallRequest = SpawnBallRequest.new()
	request.ball_number = _get_next_spawn_ball_number()
	request.is_wayfinder = false
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
	label.add_theme_font_override("font", UI_FONT)
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
#endregion


#region Helpers / Utilities
# Small shared checks that do not yet justify a separate system file.
func _all_balls_stopped() -> bool:
	if not pending_spawn_requests.is_empty():
		return false

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.visible and ball.is_moving():
			return false

	return true
#endregion


#region Spawning / Drop Flow
# Owns reward accounting, safe spawn search, and the animated ball-drop queue.
# Future extraction candidate: SpawnSystem.
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

	return playfield_rect.get_center()


func _get_random_spawn_search_center() -> Vector2:
	var radius: float = randf_range(SPAWN_RANDOM_RADIUS_MIN, SPAWN_RANDOM_RADIUS_MAX)
	var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var candidate: Vector2 = SPAWN_SEARCH_CENTER + direction * radius
	return candidate.clamp(playfield_rect.position, playfield_rect.end)


func _is_safe_ball_position(candidate: Vector2, ball_radius: float, ignored_ball: Ball = null) -> bool:
	if not playfield_rect.grow(-ball_radius).has_point(candidate):
		return false

	for pocket_index in range(pocket_positions.size()):
		var pocket_position: Vector2 = pocket_positions[pocket_index]
		var pocket_radius: float = pocket_radii[pocket_index]
		if candidate.distance_to(pocket_position) < pocket_radius + ball_radius + 8.0:
			return false

	for child in balls.get_children():
		var other_ball := child as Ball
		if other_ball == null or other_ball == ignored_ball or not other_ball.visible:
			continue
		if candidate.distance_to(other_ball.get_safe_position()) < ball_radius + other_ball.radius + 4.0:
			return false

	return true
#endregion


#region Helpers / Utilities
# Reset and game-end helpers remain here until PocketSystem/GameState are split.
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
#endregion
