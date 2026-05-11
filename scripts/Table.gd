@tool
extends Node2D
class_name BilliardsTable

signal status_text_changed(text: String)
signal game_finished(text: String)

#region Data Containers
class ResultCallout:
	var label: Label
	var stack_index := 0
	var drift_tween: Tween
	var slot_tween: Tween

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

# Escalation loop. Stylish shots immediately queue new ball drops.
const MULTI_POCKET_BONUS_THRESHOLD := 2
const CHAIN_EVENT_SPEED_GAIN_MIN := 6.0

# Spawn/drop-flow callouts. Scoring feedback stays in ScoreSystem.gd.
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
const PHYSICS_SUBSTEPS := 4
const BALL_COLLISION_GRID_CELL_SIZE := 56.0
const PHYSICS_DEBUG_SPEED_THRESHOLD := 5.0
const PHYSICS_DEBUG_MAX_BALLS := 10
#endregion

#region Cached Node References
# Scene-authored nodes stay the source of truth for geometry and cue art.
@onready var balls: Node2D = $Balls
@onready var pocket_system: PocketSystem = $PocketSystem
@onready var boundary_system: BoundarySystem = $BoundarySystem
@onready var shot_event_system: ShotEventSystem = $ShotEventSystem
@onready var score_system: ScoreSystem = $ScoreSystem
@onready var aim_preview: AimPreview = $AimPreview
@onready var spawn_system: SpawnSystem = $SpawnSystem
@onready var wayfinder_system: WayfinderSystem = $WayfinderSystem
@onready var powder_keg_system: PowderKegSystem = $PowderKegSystem
@onready var anchor_ball_system: AnchorBallSystem = $AnchorBallSystem
@onready var cue_controller: CueController = $CuePivot
#endregion

#region Runtime State
# Table.gd still owns core run state; extracted systems own their local state.
# Remaining clusters mark natural future owners like PocketSystem and BallPhysics.
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
var shot_bank_eligible_ball_ids: Dictionary = {}
var table_frame_art_rect := Rect2()
var playfield_rect := Rect2()
var perf_ball_pair_checks := 0
var perf_broadphase_candidate_pairs := 0
var perf_spatial_grid_cells := 0
var perf_spatial_grid_max_cell_size := 0
var perf_ball_collisions_resolved := 0
var perf_physics_process_ms := 0.0
var perf_ball_collision_ms := 0.0
var perf_rail_collision_ms := 0.0
var perf_pocket_check_ms := 0.0
#endregion


#region Setup / Main Loop
# Owns startup, per-frame orchestration, and update order.
# Future extraction: this can become a thin coordinator after systems split.
func _ready() -> void:
	pocket_system.setup(self)
	boundary_system.setup(self)
	shot_event_system.setup(self)
	score_system.setup(self)
	aim_preview.setup(self)
	spawn_system.setup(self)
	wayfinder_system.setup(self)
	powder_keg_system.setup(self)
	anchor_ball_system.setup(self)
	_cache_table_geometry()
	cue_controller.setup()
	if Engine.is_editor_hint():
		cue_controller.update_cue(cue_ball, false, is_dragging, Vector2.ZERO, MAX_DRAG_DISTANCE, game_over, 0.0)
		queue_redraw()
		return

	var starting_balls = spawn_system.spawn_starting_balls()
	cue_ball = starting_balls.cue_ball
	eight_ball = starting_balls.eight_ball
	eight_start = starting_balls.eight_start
	status_text_changed.emit("Drag backward from the cue ball and release to shoot.")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if game_over:
		return

	var physics_start_usec: int = Time.get_ticks_usec()
	_reset_performance_frame_stats()
	wayfinder_system.update_redirect_cooldowns(delta)
	aim_preview.update_debug(delta, is_dragging)

	var step_delta: float = delta / float(PHYSICS_SUBSTEPS)
	for _step in range(PHYSICS_SUBSTEPS):
		wayfinder_system.update_guidance(step_delta)
		anchor_ball_system.update_pull(step_delta)
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

	anchor_ball_system.finish_frame()
	spawn_system.process_spawn_queue(delta)
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
	return spawn_system.try_handle_debug_spawn_input(event)
#endregion


#region Drawing / Art Presentation
# Draws ship/table art and boundary debug. AimPreview owns aim/path drawing now.
# Future extraction: TableArt.
func _draw() -> void:
	_ensure_table_geometry_cached()
	_draw_table_art()
	_draw_collision_debug()
	anchor_ball_system.draw_debug(self)


func _draw_table_art() -> void:
	var presentation_rect: Rect2 = get_presentation_rect()
	draw_texture_rect(SHIP_FLOOR_TEXTURE, presentation_rect, false)
	draw_rect(presentation_rect, Color(0, 0, 0, 0.18), true)
	draw_texture_rect(TABLE_FRAME_TEXTURE, table_frame_art_rect, false)
	_draw_kraken_felt_art()


func _draw_kraken_felt_art() -> void:
	# The felt is baked into the table frame, so the center symbol draws as
	# its own overlay above the frame while still staying below balls/cue.
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

	for boundary_rect in boundary_system.get_boundary_reference_rects():
		draw_rect(boundary_rect, Color(1, 0.22, 0.12, 0.22), true)
		draw_rect(boundary_rect, Color(1, 0.35, 0.2, 0.9), false, 2.0)


#endregion


#region Table Geometry Cache
# Caches presentation art bounds and asks extracted geometry systems to refresh.
func _cache_table_geometry() -> void:
	table_frame_art_rect = _calculate_table_frame_art_rect()
	playfield_rect = SPAWN_REFERENCE_RECT

	pocket_system.cache_pockets()
	boundary_system.cache_boundaries()
	var boundary_rect: Rect2 = boundary_system.get_inner_rect()
	if boundary_rect.size != Vector2.ZERO:
		playfield_rect = boundary_rect


func _ensure_table_geometry_cached() -> void:
	if table_frame_art_rect.size == Vector2.ZERO or playfield_rect.size == Vector2.ZERO:
		_cache_table_geometry()


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
	if not ball_a.is_gameplay_active() or not ball_b.is_gameplay_active():
		return

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

	var pre_collision_velocity_a: Vector2 = ball_a.velocity
	var pre_collision_velocity_b: Vector2 = ball_b.velocity
	if _apply_ball_collision_response(ball_a, ball_b, normal):
		perf_ball_collisions_resolved += 1
		_note_cue_object_contact(ball_a, ball_b)
		_note_chain_contact(ball_a, ball_b, pre_collision_velocity_a, pre_collision_velocity_b)
	_note_actual_cue_ball_hit(ball_a, ball_b)
	wayfinder_system.handle_collision(ball_a, ball_b)
	powder_keg_system.handle_collision(ball_a, ball_b)
	anchor_ball_system.handle_collision(ball_a, ball_b)


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


#region Boundaries / Rails
# Resolves moving balls against BoundarySystem's scene-authored rail cache.
func _resolve_rail_collisions() -> void:
	if not boundary_system.has_boundaries():
		return

	for ball in _get_moving_active_balls():
		var hit_events: Array = boundary_system.resolve_ball_against_boundaries(ball, RAIL_RESTITUTION)
		for hit_event in hit_events:
			_note_cue_rail_touch(ball)
			shot_event_system.record_bank(ball)
			aim_preview.record_actual_bank_debug(
				ball,
				hit_event.position,
				hit_event.incoming_velocity,
				hit_event.normal,
				shot_active
			)
#endregion


#region Pockets / Pocket Capture
# PocketSystem detects captures; Table owns the consequence of a pocketed ball.
func _handle_pocket_checks() -> bool:
	var pocketed_ball: Ball = pocket_system.check_pockets(_get_moving_active_balls())
	if pocketed_ball == null:
		return false

	_handle_pocketed_ball(pocketed_ball)
	return true


func _get_moving_active_balls() -> Array[Ball]:
	var moving_balls: Array[Ball] = []
	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_gameplay_active() and ball.is_moving():
			moving_balls.append(ball)
	return moving_balls


#endregion


#region Debug Data Generation
# Maintains gameplay counters consumed by DebugOverlay.gd.
# No debug UI ownership should live in Table.gd after this extraction.
func _reset_performance_frame_stats() -> void:
	_reset_ball_debug_frame_stats()
	perf_ball_pair_checks = 0
	perf_broadphase_candidate_pairs = 0
	perf_spatial_grid_cells = 0
	perf_spatial_grid_max_cell_size = 0
	perf_ball_collisions_resolved = 0
	boundary_system.reset_frame_stats()
	pocket_system.reset_frame_stats()
	perf_physics_process_ms = 0.0
	perf_ball_collision_ms = 0.0
	perf_rail_collision_ms = 0.0
	perf_pocket_check_ms = 0.0
	anchor_ball_system.reset_frame_stats()


func _reset_ball_debug_frame_stats() -> void:
	for child in balls.get_children():
		var ball := child as Ball
		if ball != null:
			ball.reset_trail_redraw_count()


func _elapsed_ms_since(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0
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
# Future extraction candidate: PocketSystem. Spawn rewards delegate to SpawnSystem.
func _can_shoot() -> bool:
	if game_over or not is_instance_valid(cue_ball) or not cue_ball.visible:
		return false

	if spawn_system.has_pending_spawns():
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
			_reset_ball(ball, spawn_system.get_cue_start(), "Cue ball reset.")
			return
		ball.sink()
		_finish_game("Cue ball sunk. Game over.")
		return

	if ball == eight_ball:
		if DEBUG_NO_GAME_OVER:
			_reset_ball(ball, eight_start, "8 ball reset.")
			return
		ball.sink()
		_finish_game("8 ball sunk. Game over.")
		return

	var score_context: Dictionary = _make_sink_score_context(ball)
	ball.sink()
	ball.queue_free()
	_note_object_ball_pocketed(ball)
	var score_snapshot: Dictionary = shot_event_system.get_sunk_ball_score_snapshot(int(score_context["ball_id"]))
	score_system.score_sunk_ball_snapshot(score_snapshot, score_context)
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
	shot_bank_eligible_ball_ids.clear()
	shot_event_system.start_shot()


func _note_cue_rail_touch(ball: Ball) -> void:
	if shot_active and ball == cue_ball:
		shot_cue_touched_rail = true


func _note_cue_object_contact(ball_a: Ball, ball_b: Ball) -> void:
	if not shot_active:
		return

	var object_ball: Ball = _get_cue_contacted_object_ball(ball_a, ball_b)
	if object_ball == null:
		return

	shot_event_system.record_cue_object_contact(object_ball)
	_note_cue_object_contact_for_bank(object_ball)


func _note_cue_object_contact_for_bank(object_ball: Ball) -> void:
	if not shot_cue_touched_rail:
		return

	# A ball is bank-eligible only if the cue had already touched a rail
	# before this cue-to-object contact.
	shot_bank_eligible_ball_ids[object_ball.get_instance_id()] = true


func _note_chain_contact(
	ball_a: Ball,
	ball_b: Ball,
	pre_collision_velocity_a: Vector2,
	pre_collision_velocity_b: Vector2
) -> void:
	if not shot_active:
		return

	if not _is_scoring_object_ball(ball_a) or not _is_scoring_object_ball(ball_b):
		return

	if _did_ball_gain_chain_motion(ball_a, pre_collision_velocity_a):
		shot_event_system.record_chain_transfer(ball_b, ball_a)

	if _did_ball_gain_chain_motion(ball_b, pre_collision_velocity_b):
		shot_event_system.record_chain_transfer(ball_a, ball_b)


func _did_ball_gain_chain_motion(ball: Ball, pre_collision_velocity: Vector2) -> bool:
	var speed_gain: float = ball.velocity.length() - pre_collision_velocity.length()
	return speed_gain >= CHAIN_EVENT_SPEED_GAIN_MIN


func _get_cue_contacted_object_ball(ball_a: Ball, ball_b: Ball) -> Ball:
	if ball_a == cue_ball:
		return ball_b if _is_scoring_object_ball(ball_b) else null
	if ball_b == cue_ball:
		return ball_a if _is_scoring_object_ball(ball_a) else null
	return null


func _make_sink_score_context(ball: Ball) -> Dictionary:
	return {
		"ball_id": ball.get_instance_id(),
		"sink_position": ball.global_position,
		"sink_velocity": ball.velocity,
		"pocket_position": pocket_system.get_last_captured_pocket_position(),
		"pocket_radius": pocket_system.get_last_captured_pocket_radius(),
	}


func _is_scoring_object_ball(ball: Ball) -> bool:
	return ball != null and ball.ball_type == Ball.BallType.OBJECT


func _note_object_ball_pocketed(ball: Ball) -> void:
	if not shot_active:
		return

	shot_event_system.record_ball_sunk(ball)
	shot_pocketed_object_balls += 1

	if shot_bank_eligible_ball_ids.has(ball.get_instance_id()):
		shot_had_bank_pocket = true
		_try_award_bank_bonus()

	_award_base_spawn_progress()
	_try_award_multi_pocket_bonus()


func _try_finish_shot() -> void:
	if not shot_active or not _all_balls_stopped():
		return

	shot_active = false
	aim_preview.stop_actual_path_recording()
	shot_event_system.finish_shot()
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
	var anchor_snapshot: Dictionary = anchor_ball_system.get_debug_snapshot()
	return {
		"total_balls": counts["total"],
		"moving_balls": counts["moving"],
		"stopped_balls": counts["stopped"],
		"active_wayfinders": counts["active_wayfinders"],
		"guided_wayfinder_targets": wayfinder_system.get_guided_target_count(),
		"anchor_balls": anchor_snapshot["active_anchor_balls"],
		"anchor_affected_balls": anchor_snapshot["affected_balls"],
		"anchor_force_applications": anchor_snapshot["force_applications"],
		"anchor_avg_force": anchor_snapshot["avg_force"],
		"anchor_max_force": anchor_snapshot["max_force"],
		"anchor_nearest_distance": anchor_snapshot["nearest_distance"],
		"anchor_enabled": anchor_snapshot["enabled"],
		"anchor_radius": anchor_snapshot["influence_radius"],
		"anchor_strength": anchor_snapshot["pull_strength"],
		"anchor_visuals_enabled": anchor_snapshot["visuals_enabled"],
		"anchor_visual_nodes_active": anchor_snapshot["visual_nodes_active"],
		"anchor_field_rings_drawn": anchor_snapshot["field_rings_drawn"],
		"anchor_affected_markers_active": anchor_snapshot["affected_markers_active"],
		"anchor_max_visible_field_auras": anchor_snapshot["max_visible_field_auras"],
		"anchor_spawn_cap_enabled": anchor_snapshot["spawn_cap_enabled"],
		"anchor_spawn_cap": anchor_snapshot["max_anchor_balls_on_table"],
		"trail_points": counts["trail_points"],
		"balls_with_trails": counts["balls_with_trails"],
		"trail_redraws": counts["trail_redraws"],
		"active_powder_keg_particle_bursts": powder_keg_system.get_active_particle_burst_count(),
		"active_score_popup_labels": score_system.get_active_popup_label_count(),
		"physics_substeps": PHYSICS_SUBSTEPS,
		"spatial_grid_cells": perf_spatial_grid_cells,
		"spatial_grid_max_cell_size": perf_spatial_grid_max_cell_size,
		"broadphase_candidate_pairs": perf_broadphase_candidate_pairs,
		"ball_pair_checks": perf_ball_pair_checks,
		"ball_collisions_resolved": perf_ball_collisions_resolved,
		"rail_checks": boundary_system.get_checks_this_frame(),
		"rail_collisions_resolved": boundary_system.get_collisions_this_frame(),
		"pocket_checks": pocket_system.get_checks_this_frame(),
		"pocket_captures": pocket_system.get_captures_this_frame(),
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
		"trail_points": 0,
		"balls_with_trails": 0,
		"trail_redraws": 0,
	}

	for child in balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.visible:
			continue
		counts["total"] += 1
		counts["moving"] += 1 if ball.is_moving() else 0
		counts["active_wayfinders"] += 1 if ball.is_wayfinder and ball.wayfinder_active else 0
		var trail_point_count: int = ball.get_trail_point_count()
		counts["trail_points"] += trail_point_count
		counts["balls_with_trails"] += 1 if trail_point_count > 0 else 0
		counts["trail_redraws"] += ball.get_trail_redraw_count()

	counts["stopped"] = max(counts["total"] - counts["moving"], 0)
	return counts


func _get_ball_debug_snapshot(ball: Ball) -> Dictionary:
	return {
		"ball_number": ball.ball_number,
		"is_cue_ball": ball == cue_ball,
		"is_eight_ball": ball == eight_ball,
		"is_wayfinder": ball.is_wayfinder,
		"is_powder_keg": ball.is_powder_keg,
		"is_anchor_ball": ball.is_anchor_ball,
		"wayfinder_active": ball.is_wayfinder and ball.wayfinder_active,
		"guided": wayfinder_system.is_ball_guided(ball),
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
	return spawn_system.get_debug_spawn_hotkey_data()
#endregion


#region Callouts / Notifications
# Center/top callouts are now reserved for spawn/drop-flow messages.
# Future extraction candidate: HUD/CalloutSystem.
func queue_spawn_reward_message(is_wayfinder: bool, is_powder_keg: bool = false, is_anchor_ball: bool = false) -> void:
	if is_wayfinder:
		_queue_result_message("WAYFINDER BALL DROPPED")
	elif is_powder_keg:
		_queue_result_message("POWDER KEG DROPPED")
	elif is_anchor_ball:
		_queue_result_message("ANCHOR BALL DROPPED")
	else:
		_queue_result_message("+1 BALL DROPPED")


func _queue_result_message(message: String) -> void:
	if not RESULT_MESSAGES_ENABLED:
		return

	pending_callout_messages.append(message)


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


#region Shot Helpers
# Small shot-state checks that do not yet justify a separate system file.
func _all_balls_stopped() -> bool:
	if spawn_system.has_pending_spawns():
		return false

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.visible and ball.is_moving():
			return false

	return true
#endregion


#region Spawn Reward Rules
# Shot rules decide when rewards are earned; SpawnSystem owns queueing and drops.
func _award_base_spawn_progress() -> void:
	spawn_system.award_base_spawn_progress()


func _try_award_multi_pocket_bonus() -> void:
	if shot_multi_pocket_bonus_awarded:
		return

	if shot_pocketed_object_balls < MULTI_POCKET_BONUS_THRESHOLD:
		return

	shot_multi_pocket_bonus_awarded = true
	spawn_system.queue_spawn_reward(1)


func _try_award_bank_bonus() -> void:
	if shot_bank_bonus_awarded:
		return

	shot_bank_bonus_awarded = true
	spawn_system.queue_spawn_reward(1)
#endregion


#region Game State Helpers
# Reset and game-end helpers remain here until PocketSystem/GameState are split.
func _reset_ball(ball: Ball, origin: Vector2, message: String) -> void:
	spawn_system.reset_ball(ball, origin)
	status_text_changed.emit(message)


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
