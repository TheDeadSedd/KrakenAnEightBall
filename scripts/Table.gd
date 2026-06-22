@tool
extends Node2D
class_name BilliardsTable

signal status_text_changed(text: String)
signal game_finished(text: String)
signal run_ball_counts_changed(active_ball_count: int, balls_sunk_count: int)
signal shot_taken(count: int)
signal shot_finished(count: int)
signal gameplay_mouse_lock_changed(locked: bool)

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
const DEBUG_DRAW_BOUNDARY_RECTS := false
const DEBUG_PHYSICS_PANEL_ENABLED := true
const DEBUG_SHOT_POWER := false
const PERFORMANCE_SECTION_ALL := "all"
const PERFORMANCE_SECTION_CORE := "core"
const PERFORMANCE_SECTION_TIMING := "timing"
const PERFORMANCE_SECTION_BALL_DROPS_SCORE := "ball_drops_score"
const PERFORMANCE_SECTION_WAYFINDER := "wayfinder"
const PERFORMANCE_SECTION_ANCHOR := "anchor"
const PERFORMANCE_SECTION_CANNON := "cannon"
const PERFORMANCE_SECTION_TREASURE := "treasure"
const PERFORMANCE_SECTION_EMBEZZLER := "embezzler"
const PERFORMANCE_SECTION_POWDER_KEG_WAYFINDER := "powder_keg_wayfinder"
const PERFORMANCE_SECTION_VISUAL_COST := "visual_cost"
const PERFORMANCE_SECTION_AIM_PREVIEW := "aim_preview"
const PERFORMANCE_SECTION_PHYSICS := "physics"
const PERFORMANCE_SECTION_QUARTERMASTER := "quartermaster"
const SHIP_FLOOR_TEXTURE := preload("res://assets/table_art/ship_floor_full.png")
const TABLE_FRAME_TEXTURE := preload("res://assets/table_art/pool_table_frame.png")
const KRAKEN_SILHOUETTE_TEXTURE := preload("res://assets/table_art/kraken_silhouette.png")
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

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
const SHIP_FLOOR_FULL_ART_RECT := Rect2(0, 0, 1920, 1080)
const TABLE_FRAME_VISIBLE_BOUNDS := Rect2(311, 130, 1294, 794)
const KRAKEN_ART_ALPHA := 0.18
const READY_STATUS_TEXT := "The Kraken waits with payment."
const LOADING_STATUS_TEXT := "Loading table..."

# Legacy pre-BallDrop reward triggers. Keep disabled for normal gameplay.
# The active score-to-chaos path is ScoreSystem -> TableEventSystem /
# Kraken Intervention -> SpawnSystem; BallDrop remains legacy/gated support
# plus cue/eight-ball penalty plumbing.
const LEGACY_NON_SCORE_REWARD_DROPS_ENABLED := false
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
const SPECIAL_BALL_PENALTY_REMOVAL_TIME := 0.18

# Shot controls and cue aim input.
const MAX_DRAG_DISTANCE := 210.0
const MIN_SHOT_DISTANCE := 12.0
const SHOT_POWER := 9.4
const CUE_MODIFIER_CUE_SHOT_POWER_MULTIPLIER_BONUS := "cue_shot_power_multiplier_bonus"
const HIDE_CURSOR_DURING_CUE_DRAG := true
const CUE_AIM_DEADZONE_RADIUS := 20.0
const EARLY_CUE_RECLAIM_DELAY := 0.35
const EARLY_CUE_RECLAIM_LOW_SPEED := 85.0
const EARLY_CUE_RECLAIM_MEDIUM_SPEED := 180.0
const EARLY_CUE_RECLAIM_THREAT_LOOKAHEAD := 0.45
const EARLY_CUE_RECLAIM_THREAT_MARGIN := 8.0

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
@onready var obstacles: Node2D = get_node_or_null("Obstacles") as Node2D
@onready var pocket_system: PocketSystem = $PocketSystem
@onready var boundary_system: BoundarySystem = $BoundarySystem
@onready var shot_event_system: ShotEventSystem = $ShotEventSystem
@onready var score_system: ScoreSystem = $ScoreSystem
@onready var pocket_streak_system: PocketStreakSystem = $PocketStreakSystem
@onready var ball_drop_system: BallDropSystem = $BallDropSystem
@onready var table_event_system: TableEventSystem = $TableEventSystem
@onready var run_stats_system: RunStatsSystem = $RunStatsSystem
@onready var passage_system: PassageSystem = $PassageSystem
@onready var oath_system: OathSystem = $OathSystem
@onready var table_obstacle_system: TableObstacleSystem = $TableObstacleSystem
@onready var ball_audio_system: BallAudioSystem = $BallAudioSystem
@onready var aim_preview: AimPreview = $AimPreview
@onready var spawn_system: SpawnSystem = $SpawnSystem
@onready var ball_placement_system: BallPlacementSystem = $BallPlacementSystem
@onready var quartermaster_system: QuartermasterSystem = $QuartermasterSystem
@onready var reserve_system: ReserveSystem = $ReserveSystem
@onready var back_room_deal_system: BackRoomDealSystem = $BackRoomDealSystem
@onready var wayfinder_system: WayfinderSystem = $WayfinderSystem
@onready var powder_keg_system: PowderKegSystem = $PowderKegSystem
@onready var anchor_ball_system: AnchorBallSystem = $AnchorBallSystem
@onready var cannon_ball_system: CannonBallSystem = $CannonBallSystem
@onready var treasure_ball_system: TreasureBallSystem = $TreasureBallSystem
@onready var embezzler_system: EmbezzlerSystem = $EmbezzlerSystem
@onready var table_impact_shake_system: TableImpactShakeSystem = $TableImpactShakeSystem
@onready var pocket_streak_presenter: PocketStreakPresenter = $PocketStreakPresenter
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
var gameplay_mouse_lock_active := false
var cue_drag_restore_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var aim_preview_dirty := true
var game_over := false
var shot_active := false
var shot_pocketed_object_balls := 0
var shot_cue_touched_rail := false
var shot_had_bank_pocket := false
var shot_multi_pocket_bonus_awarded := false
var shot_bank_bonus_awarded := false
var shot_bank_eligible_ball_ids: Dictionary = {}
var shot_elapsed_time := 0.0
var shots_taken_count := 0
var balls_sunk_count := 0
var run_ball_count_update_queued := false
var cue_control_reclaimed := false
var cue_reclaim_eligible := false
var cue_reclaim_blocker_reason := "No active shot"
var cue_reclaim_moving_non_cue_count := 0
var cue_reclaim_low_speed_count := 0
var cue_reclaim_medium_speed_count := 0
var cue_reclaim_high_speed_count := 0
var cue_reclaim_has_cue_collision_threat := false
var cue_reclaim_motion_snapshot_updated := false
var cue_reclaim_cached_signature := ""
var cue_reclaim_cached_eligible := false
var cue_reclaim_cached_blocker_reason := "No active shot"
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
var cue_modifier_snapshot: Dictionary = {}
#endregion


#region Setup / Main Loop
# Owns startup, per-frame orchestration, and update order.
# Future extraction: this can become a thin coordinator after systems split.
func _ready() -> void:
	_connect_run_ball_count_events()
	pocket_system.setup(self)
	boundary_system.setup(self)
	shot_event_system.setup(self)
	score_system.setup(self)
	pocket_streak_system.setup(self)
	ball_drop_system.setup(self)
	table_event_system.setup(self)
	if table_event_system.should_disable_automatic_ball_drops():
		ball_drop_system.enabled = false
	passage_system.setup(self)
	oath_system.setup(self)
	table_obstacle_system.setup(self)
	ball_audio_system.setup(self)
	_connect_score_drop_events()
	aim_preview.setup(self)
	spawn_system.setup(self)
	ball_placement_system.setup(self)
	wayfinder_system.setup(self)
	powder_keg_system.setup(self)
	anchor_ball_system.setup(self)
	cannon_ball_system.setup(self)
	treasure_ball_system.setup(self)
	embezzler_system.setup(self)
	table_impact_shake_system.setup(self)
	quartermaster_system.setup(self)
	reserve_system.setup(self)
	back_room_deal_system.setup(self)
	run_stats_system.setup(self)
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
	_queue_run_ball_count_update()
	status_text_changed.emit(READY_STATUS_TEXT)
	queue_redraw()


func _exit_tree() -> void:
	if gameplay_mouse_lock_active and HIDE_CURSOR_DURING_CUE_DRAG:
		Input.mouse_mode = cue_drag_restore_mouse_mode


func _connect_run_ball_count_events() -> void:
	if not balls.child_entered_tree.is_connected(_on_balls_child_tree_changed):
		balls.child_entered_tree.connect(_on_balls_child_tree_changed)
	if not balls.child_exiting_tree.is_connected(_on_balls_child_tree_changed):
		balls.child_exiting_tree.connect(_on_balls_child_tree_changed)


func get_run_ball_counts_snapshot() -> Dictionary:
	return {
		"active_ball_count": _count_active_run_balls(),
		"balls_sunk_count": balls_sunk_count,
	}


func _on_balls_child_tree_changed(_node: Node) -> void:
	_queue_run_ball_count_update()


func _queue_run_ball_count_update() -> void:
	if run_ball_count_update_queued:
		return

	run_ball_count_update_queued = true
	call_deferred("_emit_run_ball_count_update")


func _emit_run_ball_count_update() -> void:
	run_ball_count_update_queued = false
	run_ball_counts_changed.emit(_count_active_run_balls(), balls_sunk_count)


func _count_active_run_balls() -> int:
	var active_ball_count := 0
	for child in balls.get_children():
		var ball := child as Ball
		if _is_active_run_ball(ball):
			active_ball_count += 1
	return active_ball_count


func _is_active_run_ball(ball: Ball) -> bool:
	return (
		ball != null
		and ball != cue_ball
		and not ball.is_queued_for_deletion()
		and ball.is_gameplay_active()
	)


func _connect_score_drop_events() -> void:
	if not score_system.doubloons_awarded.is_connected(ball_drop_system.handle_doubloons_awarded):
		score_system.doubloons_awarded.connect(ball_drop_system.handle_doubloons_awarded)
	if not score_system.doubloons_awarded.is_connected(table_event_system.handle_doubloons_awarded):
		score_system.doubloons_awarded.connect(table_event_system.handle_doubloons_awarded)
	if not score_system.doubloons_awarded.is_connected(embezzler_system.handle_doubloons_awarded):
		score_system.doubloons_awarded.connect(embezzler_system.handle_doubloons_awarded)


func emit_ready_status_if_needed(current_status_text: String) -> void:
	if not _is_loading_status_text(current_status_text):
		return
	if _can_start_aiming():
		status_text_changed.emit(READY_STATUS_TEXT)


func can_start_manual_ball_placement() -> bool:
	if game_over or ball_placement_system.is_placement_active():
		return false
	if shot_active:
		return false
	return _all_balls_stopped() and _get_cue_control_base_blocker().is_empty()


func is_ball_placement_active() -> bool:
	return ball_placement_system.is_placement_active()


func cancel_active_ball_placement() -> void:
	ball_placement_system.cancel_placement()


func _is_loading_status_text(status_text: String) -> bool:
	return status_text.strip_edges().to_lower() in ["", LOADING_STATUS_TEXT.to_lower()]


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if game_over:
		return

	var physics_start_usec: int = Time.get_ticks_usec()
	_reset_performance_frame_stats()
	wayfinder_system.update_redirect_cooldowns(delta)
	aim_preview.update_debug(delta, is_dragging)

	_begin_cue_reclaim_motion_snapshot()
	var step_delta: float = delta / float(PHYSICS_SUBSTEPS)
	for step_index in range(PHYSICS_SUBSTEPS):
		wayfinder_system.update_guidance(step_delta)
		treasure_ball_system.update_hiding(step_delta)
		embezzler_system.update_repositioning(step_delta)
		anchor_ball_system.update_curse_chain_slides(step_delta)
		_move_balls(step_delta)
		anchor_ball_system.enforce_curse_chain_constraints()
		var phase_start_usec: int = Time.get_ticks_usec()
		_resolve_ball_collisions()
		_resolve_obstacle_collisions()
		perf_ball_collision_ms += _elapsed_ms_since(phase_start_usec)
		anchor_ball_system.enforce_curse_chain_constraints()
		phase_start_usec = Time.get_ticks_usec()
		if _handle_pocket_checks():
			perf_pocket_check_ms += _elapsed_ms_since(phase_start_usec)
			break
		perf_pocket_check_ms += _elapsed_ms_since(phase_start_usec)
		phase_start_usec = Time.get_ticks_usec()
		_resolve_rail_collisions()
		perf_rail_collision_ms += _elapsed_ms_since(phase_start_usec)
		anchor_ball_system.enforce_curse_chain_constraints()
		aim_preview.record_actual_path_step()
		_apply_ball_friction(step_delta, step_index == PHYSICS_SUBSTEPS - 1)

	if not cue_reclaim_motion_snapshot_updated:
		_rebuild_cue_reclaim_motion_snapshot()
	_update_cue_reclaim_state(delta)
	anchor_ball_system.finish_frame()
	cannon_ball_system.update_presence_visuals()
	embezzler_system.update_willingness(delta)
	spawn_system.process_spawn_queue(delta)
	_process_callout_queue(delta)
	_try_finish_shot()
	var can_use_cue: bool = _can_release_current_shot() if is_dragging else _can_start_aiming()
	var can_run_anchor_warning_timer: bool = can_use_cue and not shot_active
	anchor_ball_system.update_curse_warning_timers(delta, can_run_anchor_warning_timer)
	cue_controller.update_cue(cue_ball, can_use_cue, is_dragging, _get_current_shot_drag_vector(), MAX_DRAG_DISTANCE, game_over, delta)
	if is_dragging:
		_mark_aim_preview_dirty()
	_flush_aim_preview_refresh()

	perf_physics_process_ms = _elapsed_ms_since(physics_start_usec)
#endregion


#region Input Dispatch
# Routes raw mouse/touch/debug keys. Cue-specific behavior stays in Cue Controller below.
func _unhandled_input(event: InputEvent) -> void:
	if game_over or not is_instance_valid(cue_ball):
		return
	if ball_placement_system.is_placement_active():
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
		_mark_aim_preview_dirty()
		queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_try_start_drag(event.position)
		else:
			_release_shot(event.position)
	elif event is InputEventScreenDrag and is_dragging:
		drag_mouse_position = event.position
		_mark_aim_preview_dirty()
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
	anchor_ball_system.draw_curse_chains(self)
	anchor_ball_system.draw_debug(self)
	treasure_ball_system.draw_debug(self)


func _draw_table_art() -> void:
	var floor_offset: Vector2 = table_impact_shake_system.get_floor_visual_offset()
	var table_art_offset: Vector2 = table_impact_shake_system.get_table_art_visual_offset()
	var floor_rect: Rect2 = _offset_rect(SHIP_FLOOR_FULL_ART_RECT, floor_offset)
	draw_texture_rect(SHIP_FLOOR_TEXTURE, floor_rect, false)
	draw_rect(floor_rect, Color(0, 0, 0, 0.18), true)
	draw_texture_rect(TABLE_FRAME_TEXTURE, _offset_rect(table_frame_art_rect, table_art_offset), false)
	_draw_kraken_felt_art(table_art_offset)


func _draw_kraken_felt_art(table_art_offset: Vector2 = Vector2.ZERO) -> void:
	# The felt is baked into the table frame, so the center symbol draws as
	# its own overlay above the frame while still staying below balls/cue.
	var kraken_rect: Rect2 = _fit_texture_rect_inside(KRAKEN_SILHOUETTE_TEXTURE, playfield_rect.grow(-54.0))
	draw_texture_rect(
		KRAKEN_SILHOUETTE_TEXTURE,
		_offset_rect(kraken_rect, table_art_offset),
		false,
		Color(0.88, 0.94, 0.92, KRAKEN_ART_ALPHA)
	)


func _offset_rect(rect: Rect2, offset: Vector2) -> Rect2:
	return Rect2(rect.position + offset, rect.size)


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


func _apply_ball_friction(delta: float, track_cue_reclaim_motion: bool = false) -> void:
	if track_cue_reclaim_motion:
		_reset_cue_reclaim_motion_snapshot()

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_gameplay_active():
			ball.apply_friction(delta)
			if track_cue_reclaim_motion:
				_capture_cue_reclaim_motion(ball)

	if track_cue_reclaim_motion:
		cue_reclaim_motion_snapshot_updated = true


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


func _resolve_obstacle_collisions() -> void:
	if table_obstacle_system == null or not table_obstacle_system.has_collision_obstacles():
		return

	table_obstacle_system.resolve_ball_collisions(_get_moving_active_balls())


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
	var collision_impact_speed: float = _get_ball_collision_impact_speed(ball_a, ball_b, normal)
	if collision_impact_speed > 0.0:
		ball_audio_system.handle_ball_collision(ball_a, ball_b, collision_impact_speed)
	if _apply_ball_collision_response(ball_a, ball_b, normal, collision_impact_speed):
		perf_ball_collisions_resolved += 1
		_note_cue_object_contact(ball_a, ball_b, normal, collision_impact_speed, pre_collision_velocity_a, pre_collision_velocity_b)
		_note_chain_contact(ball_a, ball_b, pre_collision_velocity_a, pre_collision_velocity_b)
		shot_event_system.record_collision_motion(ball_a, ball_b, pre_collision_velocity_a, pre_collision_velocity_b)
	_note_actual_cue_ball_hit(ball_a, ball_b)
	wayfinder_system.handle_collision(ball_a, ball_b)
	powder_keg_system.handle_collision(ball_a, ball_b)
	anchor_ball_system.handle_collision(ball_a, ball_b)


func _separate_overlapping_balls(ball_a: Ball, ball_b: Ball, normal: Vector2, overlap: float) -> void:
	if anchor_ball_system.try_separate_curse_seed_overlap(ball_a, ball_b, normal, overlap):
		return

	var correction: Vector2 = normal * (overlap * 0.5 + 0.01)
	ball_a.global_position -= correction
	ball_b.global_position += correction


func _get_ball_collision_impact_speed(ball_a: Ball, ball_b: Ball, normal: Vector2) -> float:
	var relative_velocity: Vector2 = ball_a.velocity - ball_b.velocity
	return relative_velocity.dot(normal)


func _apply_ball_collision_response(ball_a: Ball, ball_b: Ball, normal: Vector2, speed_along_normal: float) -> bool:
	if speed_along_normal <= 0.0:
		return false

	var impulse_strength: float = (1.0 + BALL_COLLISION_RESTITUTION) * speed_along_normal * 0.5
	impulse_strength *= BALL_VELOCITY_TRANSFER
	var impulse: Vector2 = normal * impulse_strength
	if anchor_ball_system.try_apply_curse_seed_collision_response(ball_a, ball_b, normal, impulse):
		return true
	if cannon_ball_system.try_apply_collision_response(ball_a, ball_b, normal, impulse):
		return true
	if treasure_ball_system.try_apply_collision_response(ball_a, ball_b, normal, impulse):
		return true
	if embezzler_system.try_apply_collision_response(ball_a, ball_b, normal, impulse):
		return true

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
			shot_event_system.record_rail_contact(ball, hit_event.position)
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
	aim_preview.reset_frame_stats()
	ball_audio_system.reset_frame_stats()
	perf_physics_process_ms = 0.0
	perf_ball_collision_ms = 0.0
	perf_rail_collision_ms = 0.0
	perf_pocket_check_ms = 0.0
	anchor_ball_system.reset_frame_stats()
	cannon_ball_system.reset_frame_stats()
	treasure_ball_system.reset_frame_stats()
	embezzler_system.reset_frame_stats()
	table_obstacle_system.reset_frame_stats()


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
func cancel_active_cue_drag_for_pause() -> void:
	if not is_instance_valid(cue_ball):
		return

	if is_dragging:
		_end_cue_drag()
		cue_controller.stop_recoil()
	_clear_aim_preview_now()
	queue_redraw()


func is_cue_drag_active() -> bool:
	return is_dragging


func is_gameplay_mouse_locked() -> bool:
	return gameplay_mouse_lock_active


func should_suppress_hover_ui() -> bool:
	return is_gameplay_mouse_locked()


func set_cue_modifier_snapshot(snapshot: Dictionary) -> void:
	cue_modifier_snapshot = snapshot.duplicate(true)
	if is_dragging:
		_mark_aim_preview_dirty()


func get_effective_shot_power() -> float:
	return SHOT_POWER * _get_cue_shot_power_multiplier()


func get_cue_shot_power_modifier_snapshot() -> Dictionary:
	if not bool(cue_modifier_snapshot.get("modifiers_enabled", true)):
		return {
			"base_power": SHOT_POWER,
			"bonus": 0.0,
			"multiplier": 1.0,
			"effective_power": SHOT_POWER,
			"summary": "disabled",
			"suppressed": true,
			"suppression_label": str(cue_modifier_snapshot.get("suppression_label", "Oath of Humility")),
			"suppression_remaining_text": str(cue_modifier_snapshot.get("suppression_remaining_text", "")),
		}

	var bonus := _get_cue_shot_power_multiplier_bonus()
	var multiplier := _get_cue_shot_power_multiplier()
	return {
		"base_power": SHOT_POWER,
		"bonus": bonus,
		"multiplier": multiplier,
		"effective_power": SHOT_POWER * multiplier,
		"summary": _format_multiplier_bonus_percent(bonus),
		"suppressed": false,
		"suppression_label": "",
		"suppression_remaining_text": "",
	}


func _try_start_drag(mouse_position: Vector2) -> void:
	if not _can_start_aiming():
		return

	if not cue_controller.is_point_over_grab_zone(mouse_position, cue_ball, MAX_DRAG_DISTANCE):
		return

	_begin_cue_drag()
	cue_controller.stop_recoil()
	drag_start_mouse_position = mouse_position
	drag_start_drag_vector = cue_ball.global_position - mouse_position
	drag_aim_direction = _get_initial_drag_aim_direction()
	drag_mouse_position = mouse_position
	_mark_aim_preview_dirty()
	queue_redraw()


func _release_shot(_mouse_position: Vector2) -> void:
	if not is_dragging:
		return

	if not _can_release_current_shot():
		_end_cue_drag()
		cue_controller.stop_recoil()
		_clear_aim_preview_now()
		queue_redraw()
		return

	var release_position: Vector2 = drag_mouse_position
	var drag_vector: Vector2 = _get_drag_vector(release_position)
	var release_pullback: float = cue_controller.get_pullback_for_drag_vector(drag_vector, MAX_DRAG_DISTANCE)
	var release_direction: Vector2 = drag_vector.normalized()
	_end_cue_drag()
	if drag_vector.length() < MIN_SHOT_DISTANCE:
		cue_controller.stop_recoil()
		_clear_aim_preview_now()
		queue_redraw()
		return

	var effective_shot_power := get_effective_shot_power()
	if release_direction != Vector2.ZERO:
		aim_preview.start_path_comparison(cue_ball.global_position, drag_vector * effective_shot_power)
	cue_ball.velocity = drag_vector * effective_shot_power
	var release_rotation: float = release_direction.angle() if release_direction != Vector2.ZERO else cue_controller.get_rotation_angle()
	cue_controller.begin_recoil(cue_ball.global_position, release_rotation, release_pullback)
	_print_shot_power_debug(drag_vector, release_position)
	_start_shot_tracking()
	status_text_changed.emit("Shot taken. Wait for the balls to settle before shooting again.")
	_clear_aim_preview_now()
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


func _begin_cue_drag() -> void:
	if is_dragging:
		return
	is_dragging = true
	_set_gameplay_mouse_lock(true)


func _end_cue_drag() -> void:
	if not is_dragging:
		_set_gameplay_mouse_lock(false)
		return
	is_dragging = false
	_set_gameplay_mouse_lock(false)


func _set_gameplay_mouse_lock(locked: bool) -> void:
	if gameplay_mouse_lock_active == locked:
		return

	gameplay_mouse_lock_active = locked
	if locked:
		cue_drag_restore_mouse_mode = Input.mouse_mode
		if HIDE_CURSOR_DURING_CUE_DRAG:
			Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	else:
		if HIDE_CURSOR_DURING_CUE_DRAG:
			Input.mouse_mode = cue_drag_restore_mouse_mode
	gameplay_mouse_lock_changed.emit(gameplay_mouse_lock_active)


func _mark_aim_preview_dirty() -> void:
	aim_preview_dirty = true


func _flush_aim_preview_refresh() -> void:
	if not aim_preview_dirty:
		return

	_refresh_aim_preview()
	aim_preview_dirty = false


func _clear_aim_preview_now() -> void:
	aim_preview_dirty = false
	_refresh_aim_preview()


func _refresh_aim_preview() -> void:
	var effective_shot_power := get_effective_shot_power()
	if not is_dragging or not _can_release_current_shot():
		aim_preview.update_preview(false, Vector2.ZERO, Vector2.ZERO, effective_shot_power, 0.0)
		treasure_ball_system.handle_aim_perception_snapshot(aim_preview.get_treasure_perception_snapshot())
		embezzler_system.handle_aim_perception_snapshot(aim_preview.get_embezzler_perception_snapshot())
		return

	var drag_vector: Vector2 = _get_drag_vector(drag_mouse_position)
	var power_ratio: float = clamp(drag_vector.length() / MAX_DRAG_DISTANCE, 0.0, 1.0)
	aim_preview.update_preview(true, cue_ball.global_position, drag_vector, effective_shot_power, power_ratio)
	treasure_ball_system.handle_aim_perception_snapshot(aim_preview.get_treasure_perception_snapshot())
	embezzler_system.handle_aim_perception_snapshot(aim_preview.get_embezzler_perception_snapshot())


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


func _get_cue_shot_power_multiplier() -> float:
	return maxf(1.0 + _get_cue_shot_power_multiplier_bonus(), 0.0)


func _get_cue_shot_power_multiplier_bonus() -> float:
	return maxf(_get_cue_modifier_value(CUE_MODIFIER_CUE_SHOT_POWER_MULTIPLIER_BONUS, 0.0), 0.0)


func _get_cue_modifier_value(modifier_key: String, fallback: float = 0.0) -> float:
	if not bool(cue_modifier_snapshot.get("modifiers_enabled", true)):
		return fallback
	var modifiers_value: Variant = cue_modifier_snapshot.get("modifiers", {})
	if not modifiers_value is Dictionary:
		return fallback
	var modifiers: Dictionary = modifiers_value as Dictionary
	return float(modifiers.get(modifier_key, fallback))


func _format_multiplier_bonus_percent(value: float) -> String:
	return "+%.0f%%" % (maxf(value, 0.0) * 100.0)


#region Shot State / Pocket Consequences
# Owns shot lifecycle, pocket outcomes, and reward triggers after pocket captures.
# Future extraction candidate: PocketSystem. Spawn rewards delegate to SpawnSystem.
func _can_start_aiming() -> bool:
	return _can_take_cue_control()


func _can_take_cue_control() -> bool:
	if not _get_cue_control_base_blocker().is_empty():
		return false
	if shot_active:
		return cue_control_reclaimed

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.is_moving():
			return false

	return true


func _can_release_current_shot() -> bool:
	if not is_dragging:
		return false
	if not _get_cue_control_base_blocker().is_empty():
		return false

	# Once aiming has started, later non-cue-ball movement should not revoke
	# the release. For reclaimed shots, keep the original reclaim grant as
	# proof that control was safely handed back.
	if shot_active and not cue_control_reclaimed:
		return false

	return true


func _handle_pocketed_ball(ball: Ball) -> void:
	_note_actual_cue_pocketed(ball)

	if ball == cue_ball:
		_handle_special_ball_pocketed(ball, spawn_system.get_cue_start(), "Cue ball")
		return

	if ball == eight_ball:
		_note_run_ball_sunk(ball)
		_handle_special_ball_pocketed(ball, eight_start, "8 ball")
		return

	var score_context: Dictionary = _make_sink_score_context(ball)
	_note_run_ball_sunk(ball)
	anchor_ball_system.handle_ball_pocketed(ball)
	if embezzler_system.handle_ball_captured(ball, score_context):
		status_text_changed.emit("Embezzler caught.")
		return

	ball.sink()
	ball.queue_free()
	var shot_sink_recorded: bool = _note_object_ball_pocketed(ball, score_context)
	var score_snapshot: Dictionary = _get_object_ball_score_snapshot(ball, score_context, shot_sink_recorded)
	var scored_amount: int = score_system.score_sunk_ball_snapshot(score_snapshot, score_context)
	if scored_amount > 0:
		wayfinder_system.note_wayfinder_current_sink_scored(ball)
	treasure_ball_system.handle_treasure_claimed(ball, score_context)
	var pocket_streak_result: Dictionary = {}
	if shot_sink_recorded:
		pocket_streak_result = pocket_streak_system.record_object_ball_sink(score_context, scored_amount)
	_handle_pocket_streak_result(pocket_streak_result)
	status_text_changed.emit("Ball %s sunk." % ball.ball_number)


func _handle_special_ball_pocketed(ball: Ball, reset_origin: Vector2, ball_label: String) -> void:
	var sink_position: Vector2 = ball.global_position
	var penalty_result: Dictionary = ball_drop_system.apply_special_ball_sink_penalty()
	var penalty_amount: int = int(penalty_result.get("penalty", 0))
	var penalty_message: String = str(penalty_result.get("message", ""))
	if not penalty_message.is_empty():
		_queue_result_message(penalty_message)

	var curse_seed_created := false
	var removed_penalty_ball := false
	if ball == eight_ball:
		var curse_seed_result: Dictionary = anchor_ball_system.try_create_curse_seed_from_eight_ball_penalty(sink_position)
		curse_seed_created = bool(curse_seed_result.get("created", false))
	else:
		removed_penalty_ball = _remove_penalty_object_ball(sink_position)
	_reset_ball(
		ball,
		reset_origin,
		_get_special_ball_penalty_status(ball_label, penalty_amount, removed_penalty_ball, curse_seed_created)
	)


func _get_special_ball_penalty_status(
	ball_label: String,
	penalty_amount: int,
	removed_penalty_ball: bool,
	curse_seed_created: bool = false
) -> String:
	var removal_text: String = " A ball was taken." if removed_penalty_ball else ""
	var curse_text: String = " An Anchor seed took root." if curse_seed_created else ""
	return "%s recovered. -%s Doubloons.%s%s" % [ball_label, penalty_amount, removal_text, curse_text]


func _remove_penalty_object_ball(origin: Vector2) -> bool:
	var penalty_ball: Ball = _get_penalty_object_ball(origin)
	if penalty_ball == null:
		return false

	_animate_penalty_ball_removal(penalty_ball)
	return true


func remove_oath_penalty_object_balls(count: int) -> int:
	var removal_count := maxi(count, 0)
	if removal_count <= 0:
		return 0

	var removal_origin := SPAWN_REFERENCE_RECT.get_center()
	if is_instance_valid(cue_ball):
		removal_origin = cue_ball.global_position

	var removed_count := 0
	for _index in range(removal_count):
		var penalty_ball: Ball = _get_penalty_object_ball(removal_origin)
		if penalty_ball == null:
			break
		_animate_penalty_ball_removal(penalty_ball)
		removed_count += 1

	if removed_count > 0:
		_queue_run_ball_count_update()
	return removed_count


func _get_penalty_object_ball(origin: Vector2) -> Ball:
	var closest_stopped_ball: Ball = null
	var closest_stopped_distance_sq: float = INF
	var closest_any_ball: Ball = null
	var closest_any_distance_sq: float = INF
	for child in balls.get_children():
		var candidate: Ball = child as Ball
		if not _can_remove_as_special_ball_penalty(candidate):
			continue

		var distance_sq: float = candidate.global_position.distance_squared_to(origin)
		if distance_sq < closest_any_distance_sq:
			closest_any_distance_sq = distance_sq
			closest_any_ball = candidate
		if not candidate.is_moving() and distance_sq < closest_stopped_distance_sq:
			closest_stopped_distance_sq = distance_sq
			closest_stopped_ball = candidate

	# Prefer a settled ball so the penalty does not casually interrupt active chains.
	if closest_stopped_ball != null:
		return closest_stopped_ball
	return closest_any_ball


func _can_remove_as_special_ball_penalty(ball: Ball) -> bool:
	return (
		ball != null
		and ball != cue_ball
		and ball != eight_ball
		and ball.visible
		and ball.gameplay_enabled
		and ball.ball_type == Ball.BallType.OBJECT
	)


func _animate_penalty_ball_removal(ball: Ball) -> void:
	ball.velocity = Vector2.ZERO
	ball.gameplay_enabled = false
	ball.suppress_trail_for(SPECIAL_BALL_PENALTY_REMOVAL_TIME)
	ball.clear_anchor_influence_marker()

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ball, "scale", Vector2.ZERO, SPECIAL_BALL_PENALTY_REMOVAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(ball, "modulate:a", 0.0, SPECIAL_BALL_PENALTY_REMOVAL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(_finish_penalty_ball_removal.bind(ball))


func _finish_penalty_ball_removal(ball: Ball) -> void:
	if not is_instance_valid(ball):
		return

	ball.sink()
	ball.queue_free()


func _note_actual_cue_pocketed(ball: Ball) -> void:
	aim_preview.note_actual_cue_pocketed(ball)


func _start_shot_tracking() -> void:
	shot_active = true
	shots_taken_count += 1
	shot_taken.emit(shots_taken_count)
	shot_elapsed_time = 0.0
	cue_control_reclaimed = false
	cue_reclaim_eligible = false
	cue_reclaim_blocker_reason = "Post-shot delay"
	cue_reclaim_cached_signature = ""
	cue_reclaim_cached_eligible = false
	cue_reclaim_cached_blocker_reason = "Post-shot delay"
	shot_pocketed_object_balls = 0
	shot_cue_touched_rail = false
	shot_had_bank_pocket = false
	shot_multi_pocket_bonus_awarded = false
	shot_bank_bonus_awarded = false
	shot_bank_eligible_ball_ids.clear()
	shot_event_system.start_shot(cue_ball.global_position)
	pocket_streak_system.start_shot()
	table_event_system.start_shot()
	embezzler_system.handle_shot_started()


func _note_cue_rail_touch(ball: Ball) -> void:
	if shot_active and ball == cue_ball:
		shot_cue_touched_rail = true


func _note_cue_object_contact(
	ball_a: Ball,
	ball_b: Ball,
	normal: Vector2,
	impact_speed: float,
	pre_collision_velocity_a: Vector2,
	pre_collision_velocity_b: Vector2
) -> void:
	if not shot_active:
		return

	var object_ball: Ball = _get_cue_contacted_object_ball(ball_a, ball_b)
	if object_ball == null:
		return

	var center_alignment: float = _get_cue_object_contact_alignment(
		ball_a,
		ball_b,
		normal,
		pre_collision_velocity_a,
		pre_collision_velocity_b
	)
	shot_event_system.record_cue_object_contact(object_ball, center_alignment, impact_speed, cue_ball.global_position)
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

	var ball_a_speed_gain: float = _get_ball_collision_speed_gain(ball_a, pre_collision_velocity_a)
	var ball_b_speed_gain: float = _get_ball_collision_speed_gain(ball_b, pre_collision_velocity_b)
	if _did_ball_gain_chain_motion(ball_a_speed_gain):
		shot_event_system.record_chain_transfer(ball_b, ball_a, ball_a_speed_gain)

	if _did_ball_gain_chain_motion(ball_b_speed_gain):
		shot_event_system.record_chain_transfer(ball_a, ball_b, ball_b_speed_gain)


func _get_ball_collision_speed_gain(ball: Ball, pre_collision_velocity: Vector2) -> float:
	return ball.velocity.length() - pre_collision_velocity.length()


func _did_ball_gain_chain_motion(speed_gain: float) -> bool:
	return speed_gain >= CHAIN_EVENT_SPEED_GAIN_MIN


func _get_cue_contacted_object_ball(ball_a: Ball, ball_b: Ball) -> Ball:
	if ball_a == cue_ball:
		return ball_b if _is_scoring_object_ball(ball_b) else null
	if ball_b == cue_ball:
		return ball_a if _is_scoring_object_ball(ball_a) else null
	return null


func _get_cue_object_contact_alignment(
	ball_a: Ball,
	ball_b: Ball,
	normal: Vector2,
	pre_collision_velocity_a: Vector2,
	pre_collision_velocity_b: Vector2
) -> float:
	var cue_velocity: Vector2 = Vector2.ZERO
	var cue_to_object_normal: Vector2 = Vector2.RIGHT
	if ball_a == cue_ball:
		cue_velocity = pre_collision_velocity_a
		cue_to_object_normal = normal
	elif ball_b == cue_ball:
		cue_velocity = pre_collision_velocity_b
		cue_to_object_normal = -normal
	else:
		return 1.0

	if cue_velocity.length_squared() <= 0.001:
		return 1.0
	return maxf(cue_velocity.normalized().dot(cue_to_object_normal), 0.0)


func _make_sink_score_context(ball: Ball) -> Dictionary:
	return {
		"ball_id": ball.get_instance_id(),
		"sink_position": ball.global_position,
		"sink_velocity": ball.velocity,
		"pocket_position": pocket_system.get_last_captured_pocket_position(),
		"pocket_index": pocket_system.get_last_captured_pocket_index(),
		"pocket_radius": pocket_system.get_last_captured_pocket_radius(),
	}


func _is_scoring_object_ball(ball: Ball) -> bool:
	return ball != null and ball.ball_type == Ball.BallType.OBJECT


func _note_run_ball_sunk(ball: Ball) -> void:
	if ball == null or ball == cue_ball:
		return
	if ball.ball_type != Ball.BallType.OBJECT and ball.ball_type != Ball.BallType.EIGHT:
		return

	balls_sunk_count += 1
	_queue_run_ball_count_update()


func _note_object_ball_pocketed(ball: Ball, score_context: Dictionary) -> bool:
	if not shot_active:
		return false

	shot_event_system.record_ball_sunk(ball, score_context)
	shot_pocketed_object_balls += 1

	if shot_bank_eligible_ball_ids.has(ball.get_instance_id()):
		shot_had_bank_pocket = true
		_try_award_bank_bonus()

	_award_base_spawn_progress()
	_try_award_multi_pocket_bonus()
	return true


func _get_object_ball_score_snapshot(ball: Ball, score_context: Dictionary, shot_sink_recorded: bool) -> Dictionary:
	var ball_id: int = int(score_context["ball_id"])
	var current_snapshot: Dictionary = wayfinder_system.get_wayfinder_current_sink_score_snapshot(ball)
	if shot_sink_recorded:
		var shot_snapshot: Dictionary = shot_event_system.get_sunk_ball_score_snapshot(ball_id)
		if shot_snapshot.is_empty():
			return current_snapshot
		if not current_snapshot.is_empty():
			_merge_score_snapshot_events(shot_snapshot, current_snapshot)
		return shot_snapshot

	return current_snapshot


func _merge_score_snapshot_events(target_snapshot: Dictionary, source_snapshot: Dictionary) -> void:
	if target_snapshot.is_empty() or source_snapshot.is_empty():
		return

	var target_events: Array = target_snapshot.get("events", [])
	for event_type in source_snapshot.get("events", []):
		target_events.append(event_type)
	target_snapshot["events"] = target_events


func _handle_pocket_streak_result(pocket_streak_result: Dictionary) -> void:
	if not bool(pocket_streak_result.get("triggered", false)):
		return

	var multiplier: int = int(pocket_streak_result.get("multiplier", 0))
	var awarded: int = score_system.award_pocket_streak(multiplier, pocket_streak_result)
	if awarded <= 0:
		return

	pocket_streak_system.note_bonus_awarded(pocket_streak_result, awarded)
	var pocket_position: Vector2 = Vector2.ZERO
	var pocket_position_value: Variant = pocket_streak_result.get("pocket_position", Vector2.ZERO)
	if pocket_position_value is Vector2:
		pocket_position = pocket_position_value
	var pocket_radius: float = float(pocket_streak_result.get("pocket_radius", 0.0))
	pocket_streak_presenter.show_streak(multiplier, pocket_position, pocket_radius)


func _try_finish_shot() -> void:
	if not shot_active or not _all_balls_stopped():
		return

	var should_advance_anchor_chains: bool = not cue_control_reclaimed
	shot_active = false
	cue_control_reclaimed = false
	cue_reclaim_eligible = false
	cue_reclaim_blocker_reason = "No active shot"
	aim_preview.stop_actual_path_recording()
	shot_event_system.finish_shot()
	pocket_streak_system.finish_shot()
	table_event_system.finish_shot()
	shot_finished.emit(shots_taken_count)
	if should_advance_anchor_chains:
		_handle_cue_control_regained_after_shot()


func _handle_cue_control_regained_after_shot() -> void:
	anchor_ball_system.advance_curse_chains_on_cue_control_regained()
	embezzler_system.handle_cue_control_regained()
	table_event_system.handle_cue_control_regained()
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


func get_performance_debug_snapshot(requested_sections: Dictionary = {}) -> Dictionary:
	var include_all: bool = _should_collect_all_performance_sections(requested_sections)
	var needs_core: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_CORE)
	var needs_timing: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_TIMING)
	var needs_ball_drops_score: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_BALL_DROPS_SCORE)
	var needs_wayfinder: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_WAYFINDER)
	var needs_anchor: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_ANCHOR)
	var needs_cannon: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_CANNON)
	var needs_treasure: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_TREASURE)
	var needs_embezzler: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_EMBEZZLER)
	var needs_powder_keg_wayfinder: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_POWDER_KEG_WAYFINDER)
	var needs_visual_cost: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_VISUAL_COST)
	var needs_aim_preview: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_AIM_PREVIEW)
	var needs_physics: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_PHYSICS)
	var needs_quartermaster: bool = include_all or _is_performance_section_requested(requested_sections, PERFORMANCE_SECTION_QUARTERMASTER)
	var needs_counts: bool = needs_core or needs_wayfinder or needs_powder_keg_wayfinder or needs_visual_cost
	var needs_audio_debug: bool = needs_core or needs_ball_drops_score or needs_visual_cost

	var counts: Dictionary = {}
	if needs_counts:
		counts = _get_performance_ball_counts(needs_visual_cost)

	var snapshot: Dictionary = {}
	if needs_core:
		snapshot.merge(_get_table_performance_snapshot(counts))
	if needs_ball_drops_score:
		snapshot.merge(_get_ball_drop_performance_snapshot(ball_drop_system.get_debug_snapshot()))
		snapshot.merge(_get_score_popup_performance_snapshot())
	if needs_audio_debug:
		snapshot.merge(_get_audio_performance_snapshot())
	if needs_wayfinder or needs_powder_keg_wayfinder:
		snapshot.merge(_get_wayfinder_performance_snapshot(counts))
	if needs_anchor:
		snapshot.merge(_get_anchor_performance_snapshot(anchor_ball_system.get_debug_snapshot()))
	if needs_cannon:
		snapshot.merge(_get_cannon_performance_snapshot(cannon_ball_system.get_debug_snapshot()))
	if needs_treasure:
		snapshot.merge(_get_treasure_performance_snapshot(treasure_ball_system.get_debug_snapshot()))
	if needs_embezzler:
		snapshot.merge(_get_embezzler_performance_snapshot(embezzler_system.get_debug_snapshot()))
	if needs_powder_keg_wayfinder:
		snapshot.merge(_get_powder_keg_performance_snapshot())
	if needs_quartermaster:
		snapshot.merge(_get_quartermaster_performance_snapshot(quartermaster_system.get_debug_snapshot()))
	if needs_visual_cost:
		snapshot.merge(_get_visual_cost_performance_snapshot(counts))
	if needs_physics:
		snapshot.merge(_get_physics_performance_snapshot())
	if needs_aim_preview:
		snapshot.merge(_get_aim_performance_snapshot(aim_preview.get_debug_snapshot()))
	if needs_timing:
		snapshot.merge(_get_timing_performance_snapshot())
	return snapshot


func _should_collect_all_performance_sections(requested_sections: Dictionary) -> bool:
	return requested_sections.is_empty() or bool(requested_sections.get(PERFORMANCE_SECTION_ALL, false))


func _is_performance_section_requested(requested_sections: Dictionary, section_id: String) -> bool:
	return bool(requested_sections.get(section_id, false))


func _get_table_performance_snapshot(counts: Dictionary) -> Dictionary:
	return {
		"total_balls": counts["total"],
		"moving_balls": counts["moving"],
		"stopped_balls": counts["stopped"],
		"cue_reclaim_eligible": cue_reclaim_eligible,
		"cue_reclaim_granted": cue_control_reclaimed,
		"cue_reclaim_moving_non_cue_balls": cue_reclaim_moving_non_cue_count,
		"cue_reclaim_blocker_reason": cue_reclaim_blocker_reason,
	}


func _get_wayfinder_performance_snapshot(counts: Dictionary) -> Dictionary:
	var wayfinder_current_snapshot: Dictionary = wayfinder_system.get_wayfinder_current_debug_snapshot()
	return {
		"active_wayfinders": counts["active_wayfinders"],
		"guided_wayfinder_targets": wayfinder_system.get_guided_target_count(),
		"wayfinder_current_carriers": wayfinder_current_snapshot["current_carriers"],
		"wayfinder_current_events_started": wayfinder_current_snapshot["current_events_started"],
		"wayfinder_current_initial_affected": wayfinder_current_snapshot["current_initial_affected"],
		"wayfinder_current_transfers": wayfinder_current_snapshot["current_transfers"],
		"wayfinder_current_expired": wayfinder_current_snapshot["current_expired"],
		"wayfinder_current_last_affected": wayfinder_current_snapshot["current_last_affected"],
		"wayfinder_current_last_event_transfers": wayfinder_current_snapshot["current_last_event_transfers"],
		"wayfinder_current_scored_sinks": wayfinder_current_snapshot["current_scored_sinks"],
		"wayfinder_current_transfer_flashes": wayfinder_current_snapshot["current_transfer_flashes"],
		"wayfinder_current_radius": wayfinder_current_snapshot["current_radius"],
		"wayfinder_current_impulse_strength": wayfinder_current_snapshot["current_impulse_strength"],
		"wayfinder_current_lifetime_seconds": wayfinder_current_snapshot["current_lifetime_seconds"],
		"wayfinder_current_transfer_limit": wayfinder_current_snapshot["current_transfer_limit"],
	}


func _get_anchor_performance_snapshot(anchor_snapshot: Dictionary) -> Dictionary:
	return {
		"anchor_balls": anchor_snapshot["active_anchor_balls"],
		"anchor_affected_balls": anchor_snapshot["affected_balls"],
		"anchor_force_applications": anchor_snapshot["force_applications"],
		"anchor_avg_force": anchor_snapshot["avg_force"],
		"anchor_max_force": anchor_snapshot["max_force"],
		"anchor_nearest_distance": anchor_snapshot["nearest_distance"],
		"anchor_single_latch_enabled": anchor_snapshot["single_latch_enabled"],
		"anchor_multi_latch_candidates": anchor_snapshot["multi_latch_candidates"],
		"anchor_single_latch_skipped": anchor_snapshot["single_latch_skipped"],
		"anchor_max_anchors_affecting_same_ball": anchor_snapshot["max_anchors_affecting_same_ball"],
		"anchor_targets_affected_by_multiple_anchors": anchor_snapshot["targets_affected_by_multiple_anchors"],
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
		"anchor_curse_seeds_active": anchor_snapshot["active_curse_seeds"],
		"anchor_curse_seeds_created": anchor_snapshot["curse_seeds_created"],
		"anchor_curse_seed_penalty_attempts": anchor_snapshot["curse_seed_penalty_attempts"],
		"anchor_curse_seed_penalty_replacements": anchor_snapshot["curse_seed_penalty_replacements"],
		"anchor_curse_seed_eligible_candidates": anchor_snapshot["curse_seed_eligible_candidates"],
		"anchor_curse_seed_selected_score": anchor_snapshot["curse_seed_selected_score"],
		"anchor_curse_seed_selected_reason": anchor_snapshot["curse_seed_selected_reason"],
		"anchor_curse_seed_selected_ball_number": anchor_snapshot["curse_seed_selected_ball_number"],
		"anchor_curse_chain_links": anchor_snapshot["curse_chain_links"],
		"anchor_curse_chain_links_per_seed": anchor_snapshot["curse_chain_links_per_seed"],
		"anchor_curse_chain_failed_acquisitions": anchor_snapshot["curse_chain_failed_acquisitions"],
		"anchor_curse_chain_invalidated_links": anchor_snapshot["curse_chain_invalidated_links"],
		"anchor_curse_chain_last_created": anchor_snapshot["curse_chain_last_created"],
		"anchor_curse_chain_tighten_steps_applied": anchor_snapshot["curse_chain_tighten_steps_applied"],
		"anchor_curse_chain_tighten_steps_skipped": anchor_snapshot["curse_chain_tighten_steps_skipped"],
		"anchor_curse_chain_tighten_avg_distance": anchor_snapshot["curse_chain_tighten_avg_distance"],
		"anchor_curse_chain_tighten_last_distance": anchor_snapshot["curse_chain_tighten_last_distance"],
		"anchor_curse_chain_touching_seed_links": anchor_snapshot["curse_chain_touching_seed_links"],
		"anchor_curse_chain_tighten_last_skip_reason": anchor_snapshot["curse_chain_tighten_last_skip_reason"],
		"anchor_curse_chain_tighten_skip_reasons": anchor_snapshot["curse_chain_tighten_skip_reasons"],
		"anchor_curse_chain_max_lengths": anchor_snapshot["curse_chain_max_lengths"],
		"anchor_curse_chain_constraint_clamps": anchor_snapshot["curse_chain_constraint_clamps"],
		"anchor_curse_chain_tighten_slides_started": anchor_snapshot["curse_chain_tighten_slides_started"],
		"anchor_curse_chain_tighten_slides_completed": anchor_snapshot["curse_chain_tighten_slides_completed"],
		"anchor_curse_chain_tighten_slides_blocked": anchor_snapshot["curse_chain_tighten_slides_blocked"],
		"anchor_curse_chain_deconfliction_attempts": anchor_snapshot["curse_chain_deconfliction_attempts"],
		"anchor_curse_chain_deconfliction_successes": anchor_snapshot["curse_chain_deconfliction_successes"],
		"anchor_curse_chain_deconfliction_blocked": anchor_snapshot["curse_chain_deconfliction_blocked"],
		"anchor_curse_chain_deconfliction_skipped": anchor_snapshot["curse_chain_deconfliction_skipped"],
		"anchor_curse_chain_deconfliction_last_reason": anchor_snapshot["curse_chain_deconfliction_last_reason"],
		"anchor_curse_warning_seeds": anchor_snapshot["curse_warning_seeds"],
		"anchor_curse_warning_timer_remaining": anchor_snapshot["curse_warning_timer_remaining"],
		"anchor_curse_warning_timer_state": anchor_snapshot["curse_warning_timer_state"],
		"anchor_curse_spread_ready": anchor_snapshot["curse_warning_spread_ready"],
		"anchor_curse_warning_started": anchor_snapshot["curse_warning_started"],
		"anchor_curse_warning_resets": anchor_snapshot["curse_warning_resets"],
		"anchor_curse_collapsed_total": anchor_snapshot["curse_collapsed_total"],
		"anchor_curse_collapsed_by_cue": anchor_snapshot["curse_collapsed_by_cue"],
		"anchor_curse_collapsed_by_powder": anchor_snapshot["curse_collapsed_by_powder"],
		"anchor_curse_collapsed_by_cannon": anchor_snapshot["curse_collapsed_by_cannon"],
		"anchor_curse_collapsed_by_chained_ball_pocket": anchor_snapshot["curse_collapsed_by_chained_ball_pocket"],
		"anchor_curse_last_collapsed_chained_ball": anchor_snapshot["curse_last_collapsed_chained_ball"],
		"anchor_curse_chains_released_by_collapse": anchor_snapshot["curse_chains_released_by_collapse"],
		"anchor_curse_spread_events_total": anchor_snapshot["curse_spread_events_total"],
		"anchor_curse_seeds_created_by_spread": anchor_snapshot["curse_seeds_created_by_spread"],
		"anchor_curse_spread_blocked_skipped": anchor_snapshot["curse_spread_blocked_skipped"],
		"anchor_curse_new_seed_grace_count": anchor_snapshot["curse_new_seed_grace_count"],
		"anchor_curse_max_active_seeds": anchor_snapshot["curse_max_active_seeds"],
	}


func _get_cannon_performance_snapshot(cannon_snapshot: Dictionary) -> Dictionary:
	return {
		"cannon_balls": cannon_snapshot["active_cannon_balls"],
		"cannon_collisions": cannon_snapshot["collisions"],
		"cannon_heavy_impacts": cannon_snapshot["heavy_impacts"],
	}


func _get_treasure_performance_snapshot(treasure_snapshot: Dictionary) -> Dictionary:
	return {
		"treasure_balls": treasure_snapshot["active_treasure_balls"],
		"treasure_balls_seen": treasure_snapshot["seen_treasure_balls"],
		"treasure_hide_targets": treasure_snapshot["hide_targets"],
		"treasure_hide_cover_found": treasure_snapshot["hide_cover_found"],
		"treasure_hide_target_found": treasure_snapshot["hide_target_found"],
		"treasure_hiding_enabled": treasure_snapshot["hiding_movement_enabled"],
		"treasure_steering_active": treasure_snapshot["steering_active"],
		"treasure_steering_applications": treasure_snapshot["steering_applications"],
		"treasure_steering_cover_count": treasure_snapshot["steering_cover_count"],
		"treasure_steering_fallback_count": treasure_snapshot["steering_fallback_count"],
		"treasure_steering_mode": treasure_snapshot["steering_mode"],
		"treasure_threat_strength": treasure_snapshot["max_threat_strength"],
		"treasure_panic_active": treasure_snapshot["panic_active"],
		"treasure_visibility_reason": treasure_snapshot["visibility_reason"],
		"treasure_visibility_lateral_distance": treasure_snapshot["visibility_lateral_distance"],
		"treasure_visibility_distance_along_path": treasure_snapshot["visibility_distance_along_path"],
		"treasure_visibility_blocker_ball_id": treasure_snapshot["visibility_blocker_ball_id"],
		"treasure_visibility_blocker_lateral_distance": treasure_snapshot["visibility_blocker_lateral_distance"],
		"treasure_visibility_blocker_distance_along_path": treasure_snapshot["visibility_blocker_distance_along_path"],
		"treasure_target_cover_ball_id": treasure_snapshot["target_cover_ball_id"],
		"treasure_target_distance": treasure_snapshot["target_distance"],
		"treasure_target_commit_remaining": treasure_snapshot["target_commit_remaining"],
		"treasure_target_switch_reason": treasure_snapshot["target_switch_reason"],
		"treasure_perception_checks": treasure_snapshot["perception_checks"],
		"treasure_perception_epoch": treasure_snapshot["perception_epoch"],
		"treasure_perception_rebuilds": treasure_snapshot["perception_rebuilds"],
		"treasure_perception_direct_seen": treasure_snapshot["perception_direct_seen"],
		"treasure_perception_lost_events": treasure_snapshot["perception_lost_events"],
		"treasure_perception_reacquired_events": treasure_snapshot["perception_reacquired_events"],
		"treasure_perception_linger_activations": treasure_snapshot["perception_linger_activations"],
		"treasure_perception_lingered": treasure_snapshot["perception_lingered"],
		"treasure_perception_grace_active": treasure_snapshot["perception_grace_active"],
		"treasure_perception_grace_max_remaining": treasure_snapshot["perception_grace_max_remaining"],
	}


func _get_embezzler_performance_snapshot(embezzler_snapshot: Dictionary) -> Dictionary:
	return {
		"embezzler_balls": embezzler_snapshot["active_embezzlers"],
		"embezzler_stored_value": embezzler_snapshot["stored_value"],
		"embezzler_skimmed_total": embezzler_snapshot["skimmed_total"],
		"embezzler_target_pocket_index": embezzler_snapshot["target_pocket_index"],
		"embezzler_target_pocket_name": embezzler_snapshot["target_pocket_name"],
		"embezzler_state": embezzler_snapshot["current_state"],
		"embezzler_willingness": embezzler_snapshot["willingness"],
		"embezzler_baseline_willingness": embezzler_snapshot["baseline_willingness"],
		"embezzler_aim_pressure_willingness": embezzler_snapshot["aim_pressure_willingness"],
		"embezzler_last_pressure_reason": embezzler_snapshot["last_pressure_reason"],
		"embezzler_pressure_events": embezzler_snapshot["pressure_events"],
		"embezzler_calm_decay_rate": embezzler_snapshot["calm_decay_rate"],
		"embezzler_move_target": embezzler_snapshot["move_target"],
		"embezzler_move_target_mode": embezzler_snapshot["move_target_mode"],
		"embezzler_target_pocket_bias_amount": embezzler_snapshot["target_pocket_bias_amount"],
		"embezzler_target_switches": embezzler_snapshot["target_switches"],
		"embezzler_blocked_target_attempts": embezzler_snapshot["blocked_target_attempts"],
		"embezzler_scuttle_applications": embezzler_snapshot["scuttle_applications"],
		"embezzler_target_switch_reason": embezzler_snapshot["target_switch_reason"],
		"embezzler_last_blocked_target_reason": embezzler_snapshot["last_blocked_target_reason"],
		"embezzler_escape_roll_attempts": embezzler_snapshot["escape_roll_attempts"],
		"embezzler_escape_roll_successes": embezzler_snapshot["escape_roll_successes"],
		"embezzler_escape_roll_failures": embezzler_snapshot["escape_roll_failures"],
		"embezzler_last_escape_roll_chance": embezzler_snapshot["last_escape_roll_chance"],
		"embezzler_last_escape_roll_reason": embezzler_snapshot["last_escape_roll_reason"],
		"embezzler_escape_committed_active": embezzler_snapshot["escape_committed_active"],
		"embezzler_pocket_test_pending_active": embezzler_snapshot["pocket_test_pending_active"],
		"embezzler_pocket_test_pending_count": embezzler_snapshot["pocket_test_pending_count"],
		"embezzler_pocket_test_pending_total": embezzler_snapshot["pocket_test_pending_total"],
		"embezzler_pocket_roll_attempts": embezzler_snapshot["pocket_roll_attempts"],
		"embezzler_pocket_roll_successes": embezzler_snapshot["pocket_roll_successes"],
		"embezzler_pocket_roll_failures": embezzler_snapshot["pocket_roll_failures"],
		"embezzler_last_pocket_roll_chance": embezzler_snapshot["last_pocket_roll_chance"],
		"embezzler_last_pocket_roll_result": embezzler_snapshot["last_pocket_roll_result"],
		"embezzler_escaped_count": embezzler_snapshot["escaped_count"],
		"embezzler_panic_retreats": embezzler_snapshot["panic_retreats"],
		"embezzler_last_escaped_stored_value": embezzler_snapshot["last_escaped_stored_value"],
		"embezzler_escaped_stored_value_total": embezzler_snapshot["escaped_stored_value_total"],
		"embezzler_captures_total": embezzler_snapshot["captures_total"],
		"embezzler_recovered_value_total": embezzler_snapshot["recovered_value_total"],
		"embezzler_last_recovered_value": embezzler_snapshot["last_recovered_value"],
		"embezzler_last_capture_pocket_index": embezzler_snapshot["last_capture_pocket_index"],
		"embezzler_last_capture_pocket_name": embezzler_snapshot["last_capture_pocket_name"],
		"embezzler_double_award_preventions": embezzler_snapshot["double_award_preventions"],
	}


func _get_ball_drop_performance_snapshot(ball_drop_snapshot: Dictionary) -> Dictionary:
	var table_event_snapshot: Dictionary = table_event_system.get_debug_snapshot()
	return {
		"ball_drop_progress": ball_drop_snapshot["drop_progress"],
		"ball_drop_threshold": ball_drop_snapshot["doubloons_per_drop"],
		"ball_drop_enabled": ball_drop_snapshot["enabled"],
		"ball_drop_last_score_queued": ball_drop_snapshot["last_score_drops_queued"],
		"ball_drop_total_queued": ball_drop_snapshot["total_drops_queued"],
		"ball_drop_pending_spawns": ball_drop_snapshot["pending_spawn_drops"],
		"table_event_enabled": table_event_snapshot["enabled"],
		"table_event_auto_drops_gated": table_event_snapshot["automatic_ball_drops_gated"],
		"table_event_shot_progress": table_event_snapshot["shot_progress"],
		"table_event_threshold": table_event_snapshot["shot_threshold"],
		"table_event_progress_percent": table_event_snapshot["progress_percent"],
		"table_event_pending": table_event_snapshot["pending_event_available"],
		"table_event_ready": table_event_snapshot["pending_event_ready"],
		"table_event_menu_open": table_event_snapshot["event_menu_open"],
		"table_event_active_offer_ids": table_event_snapshot["active_offer_ids"],
		"table_event_last_award": table_event_snapshot["last_award_amount"],
		"table_event_total_tracked": table_event_snapshot["total_tracked_doubloons"],
		"table_event_pending_earned": table_event_snapshot["pending_events_earned"],
		"table_event_pending_readied": table_event_snapshot["pending_events_readied"],
		"table_event_purchased": table_event_snapshot["purchased_events"],
		"table_event_denied_purchases": table_event_snapshot["denied_purchases"],
		"table_event_offers_generated": table_event_snapshot["offers_generated"],
		"table_event_ignored_awards_while_pending": table_event_snapshot["ignored_awards_while_pending"],
		"table_event_last_purchase_event_id": table_event_snapshot["last_purchase_event_id"],
		"table_event_last_purchase_cost": table_event_snapshot["last_purchase_cost"],
		"table_event_last_blocker_reason": table_event_snapshot["last_blocker_reason"],
		"table_event_cheap_cargo_cost": table_event_snapshot["cheap_cargo_cost"],
		"table_event_cheap_cargo_ball_count": table_event_snapshot["cheap_cargo_ball_count"],
		"table_event_loose_cargo_cost": table_event_snapshot["loose_cargo_cost"],
		"table_event_loose_cargo_ball_count": table_event_snapshot["loose_cargo_ball_count"],
		"table_event_wayfinders_favor_cost": table_event_snapshot["wayfinders_favor_cost"],
		"table_event_wayfinders_favor_ball_count": table_event_snapshot["wayfinders_favor_ball_count"],
		"table_event_powder_cache_cost": table_event_snapshot["powder_cache_cost"],
		"table_event_powder_cache_ball_count": table_event_snapshot["powder_cache_ball_count"],
		"table_event_cannon_warning_cost": table_event_snapshot["cannon_warning_cost"],
		"table_event_cannon_warning_ball_count": table_event_snapshot["cannon_warning_ball_count"],
		"table_event_wayfinder_current_cost": table_event_snapshot["wayfinder_current_cost"],
		"table_event_wayfinder_current_ball_count": table_event_snapshot["wayfinder_current_ball_count"],
	}


func _get_score_popup_performance_snapshot() -> Dictionary:
	return {
		"active_score_popup_labels": score_system.get_active_popup_label_count(),
		"active_score_stacks": score_system.get_active_score_stack_count(),
		"active_foundational_score_stacks": score_system.get_active_foundational_score_stack_count(),
		"active_skilled_score_stacks": score_system.get_active_skilled_score_stack_count(),
		"active_heroic_score_stacks": score_system.get_active_heroic_score_stack_count(),
		"active_legendary_score_stacks": score_system.get_active_legendary_score_stack_count(),
		"score_stack_coalesces": score_system.get_foundational_score_stack_coalesce_count(),
		"score_stack_labels_avoided": score_system.get_foundational_score_stack_labels_avoided_count(),
		"score_foundational_stack_routes": score_system.get_foundational_stack_path_count(),
		"score_foundational_fallback_routes": score_system.get_foundational_fallback_stack_path_count(),
		"score_skilled_stack_routes": score_system.get_skilled_stack_path_count(),
		"score_skilled_stack_coalesces": score_system.get_skilled_score_stack_coalesce_count(),
		"score_skilled_stack_labels_avoided": score_system.get_skilled_score_stack_labels_avoided_count(),
		"score_skilled_special_popups_avoided": score_system.get_skilled_special_popup_avoided_count(),
		"score_heroic_stack_routes": score_system.get_heroic_stack_path_count(),
		"score_heroic_stack_coalesces": score_system.get_heroic_score_stack_coalesce_count(),
		"score_heroic_stack_labels_avoided": score_system.get_heroic_score_stack_labels_avoided_count(),
		"score_heroic_special_popups_avoided": score_system.get_heroic_special_popup_avoided_count(),
		"score_legendary_stack_routes": score_system.get_legendary_stack_path_count(),
		"score_legendary_stack_coalesces": score_system.get_legendary_score_stack_coalesce_count(),
		"score_legendary_stack_labels_avoided": score_system.get_legendary_score_stack_labels_avoided_count(),
		"score_legendary_special_popups_avoided": score_system.get_legendary_special_popup_avoided_count(),
		"score_stack_lane_conflicts": score_system.get_score_stack_lane_conflict_count(),
		"score_stack_replacements": score_system.get_score_stack_replacement_count(),
		"score_stack_early_fades": score_system.get_score_stack_early_fade_count(),
		"score_stack_yields": score_system.get_score_stack_yield_count(),
		"score_special_popup_routes": score_system.get_special_popup_path_count(),
		"score_last_popup_route": score_system.get_last_score_popup_route(),
		"active_score_glow_labels": score_system.get_active_score_glow_label_count(),
		"active_score_popup_tweens": score_system.get_active_score_popup_tween_count(),
	}


func _get_audio_performance_snapshot() -> Dictionary:
	var collision_audio_snapshot: Dictionary = ball_audio_system.get_debug_snapshot()
	var streak_audio_snapshot: Dictionary = pocket_streak_presenter.get_audio_debug_snapshot()
	return {
		"collision_audio_pool_size": collision_audio_snapshot["pool_size"],
		"collision_audio_playing_players": collision_audio_snapshot["playing_players"],
		"collision_audio_max_playing_players": collision_audio_snapshot["max_players_playing"],
		"collision_audio_requests_this_frame": collision_audio_snapshot["requests_this_frame"],
		"collision_audio_played_this_frame": collision_audio_snapshot["sounds_played_this_frame"],
		"collision_audio_total_requests": collision_audio_snapshot["total_requests"],
		"collision_audio_total_plays": collision_audio_snapshot["total_plays"],
		"collision_audio_skipped_tiny": collision_audio_snapshot["skipped_tiny_impacts"],
		"collision_audio_skipped_frame_limit": collision_audio_snapshot["skipped_frame_limit"],
		"collision_audio_skipped_global_cooldown": collision_audio_snapshot["skipped_global_cooldown"],
		"collision_audio_skipped_pair_cooldown": collision_audio_snapshot["skipped_pair_cooldown"],
		"collision_audio_pool_steals": collision_audio_snapshot["pool_steals"],
		"pocket_streak_audio_pool_size": streak_audio_snapshot["pool_size"],
		"pocket_streak_audio_playing_players": streak_audio_snapshot["playing_players"],
		"pocket_streak_audio_max_playing_players": streak_audio_snapshot["max_playing_players"],
		"pocket_streak_triggers": streak_audio_snapshot["streak_triggers"],
		"pocket_streak_presentations_queued": streak_audio_snapshot["presentations_queued"],
		"pocket_streak_presentations_started": streak_audio_snapshot["presentations_started"],
		"pocket_streak_last_multiplier": streak_audio_snapshot["last_presented_multiplier"],
		"pocket_streak_presentation_queue_size": streak_audio_snapshot["presentation_queue_size"],
		"pocket_streak_presentation_delay_remaining": streak_audio_snapshot["presentation_delay_remaining"],
		"pocket_streak_queue_gate_duration": streak_audio_snapshot["queue_gate_duration"],
		"pocket_streak_audio_requests": streak_audio_snapshot["audio_requests"],
		"pocket_streak_audio_plays": streak_audio_snapshot["audio_plays"],
		"pocket_streak_audio_cooldown_skips": streak_audio_snapshot["cooldown_skips"],
		"pocket_streak_audio_pool_steals": streak_audio_snapshot["pool_steals"],
		"pocket_streak_audio_last_multiplier": streak_audio_snapshot["last_multiplier"],
		"pocket_streak_active_whirlpools": streak_audio_snapshot["active_whirlpools"],
		"pocket_streak_recent_whirlpools": streak_audio_snapshot["recent_whirlpools"],
		"pocket_streak_last_whirlpool_multiplier": streak_audio_snapshot["last_whirlpool_multiplier"],
		"pocket_streak_whirlpool_extra_duration_cap": streak_audio_snapshot["whirlpool_extra_duration_cap"],
		"pocket_streak_whirlpool_intensity_cap_multiplier": streak_audio_snapshot["whirlpool_intensity_cap_multiplier"],
		"pocket_streak_audio_max_pitch_scale": streak_audio_snapshot["audio_max_pitch_scale"],
		"pocket_streak_audio_max_volume_db": streak_audio_snapshot["audio_max_volume_db"],
		"pocket_streak_audio_bus": streak_audio_snapshot["audio_bus"],
		"pocket_streak_audio_bus_index": streak_audio_snapshot["audio_bus_index"],
		"pocket_streak_reverb_effect_index": streak_audio_snapshot["reverb_effect_index"],
		"pocket_streak_reverb_wet_level": streak_audio_snapshot["reverb_wet_level"],
		"pocket_streak_reverb_wet_cap": streak_audio_snapshot["reverb_wet_cap"],
		"pocket_streak_reverb_updates": streak_audio_snapshot["reverb_updates"],
	}


func _get_quartermaster_performance_snapshot(quartermaster_snapshot: Dictionary) -> Dictionary:
	return {
		"quartermaster_offer_item_ids": quartermaster_snapshot["active_offer_item_ids"],
		"quartermaster_last_refreshed_offer_index": quartermaster_snapshot["last_refreshed_offer_index"],
	}


func _get_powder_keg_performance_snapshot() -> Dictionary:
	return {
		"active_powder_keg_particle_bursts": powder_keg_system.get_active_particle_burst_count(),
	}


func _get_visual_cost_performance_snapshot(counts: Dictionary) -> Dictionary:
	return {
		"trail_points": counts["trail_points"],
		"balls_with_trails": counts["balls_with_trails"],
		"trail_redraws": counts["trail_redraws"],
		"active_powder_keg_particle_bursts": powder_keg_system.get_active_particle_burst_count(),
		"active_score_popup_labels": score_system.get_active_popup_label_count(),
		"active_score_stacks": score_system.get_active_score_stack_count(),
		"active_foundational_score_stacks": score_system.get_active_foundational_score_stack_count(),
		"active_skilled_score_stacks": score_system.get_active_skilled_score_stack_count(),
		"active_heroic_score_stacks": score_system.get_active_heroic_score_stack_count(),
		"active_legendary_score_stacks": score_system.get_active_legendary_score_stack_count(),
		"score_stack_coalesces": score_system.get_foundational_score_stack_coalesce_count(),
		"score_stack_labels_avoided": score_system.get_foundational_score_stack_labels_avoided_count(),
		"score_foundational_stack_routes": score_system.get_foundational_stack_path_count(),
		"score_foundational_fallback_routes": score_system.get_foundational_fallback_stack_path_count(),
		"score_skilled_stack_routes": score_system.get_skilled_stack_path_count(),
		"score_skilled_stack_coalesces": score_system.get_skilled_score_stack_coalesce_count(),
		"score_skilled_stack_labels_avoided": score_system.get_skilled_score_stack_labels_avoided_count(),
		"score_skilled_special_popups_avoided": score_system.get_skilled_special_popup_avoided_count(),
		"score_heroic_stack_routes": score_system.get_heroic_stack_path_count(),
		"score_heroic_stack_coalesces": score_system.get_heroic_score_stack_coalesce_count(),
		"score_heroic_stack_labels_avoided": score_system.get_heroic_score_stack_labels_avoided_count(),
		"score_heroic_special_popups_avoided": score_system.get_heroic_special_popup_avoided_count(),
		"score_legendary_stack_routes": score_system.get_legendary_stack_path_count(),
		"score_legendary_stack_coalesces": score_system.get_legendary_score_stack_coalesce_count(),
		"score_legendary_stack_labels_avoided": score_system.get_legendary_score_stack_labels_avoided_count(),
		"score_legendary_special_popups_avoided": score_system.get_legendary_special_popup_avoided_count(),
		"score_stack_lane_conflicts": score_system.get_score_stack_lane_conflict_count(),
		"score_stack_replacements": score_system.get_score_stack_replacement_count(),
		"score_stack_early_fades": score_system.get_score_stack_early_fade_count(),
		"score_stack_yields": score_system.get_score_stack_yield_count(),
		"score_special_popup_routes": score_system.get_special_popup_path_count(),
		"score_last_popup_route": score_system.get_last_score_popup_route(),
		"active_score_glow_labels": score_system.get_active_score_glow_label_count(),
		"active_score_popup_tweens": score_system.get_active_score_popup_tween_count(),
	}


func _get_physics_performance_snapshot() -> Dictionary:
	var obstacle_snapshot := {}
	if table_obstacle_system != null:
		obstacle_snapshot = table_obstacle_system.get_debug_snapshot()

	return {
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
		"active_debris_count": int(obstacle_snapshot.get("active_debris_count", 0)),
		"obstacle_broadphase_checks": int(obstacle_snapshot.get("obstacle_broadphase_checks", 0)),
		"obstacle_broadphase_skips": int(obstacle_snapshot.get("obstacle_broadphase_skips", 0)),
		"obstacle_detailed_polygon_checks": int(obstacle_snapshot.get("obstacle_detailed_polygon_checks", 0)),
		"obstacle_collision_hits": int(obstacle_snapshot.get("obstacle_collision_hits", 0)),
		"obstacle_cache_rebuilds": int(obstacle_snapshot.get("obstacle_cache_rebuilds", 0)),
		"obstacle_collision_ms": float(obstacle_snapshot.get("obstacle_collision_ms", 0.0)),
	}


func _get_aim_performance_snapshot(aim_snapshot: Dictionary) -> Dictionary:
	return {
		"aim_prediction_enabled": aim_preview.is_prediction_enabled(),
		"shot_comparison_enabled": aim_preview.is_shot_path_debug_enabled(),
		"aim_prediction_ms": aim_snapshot["prediction_ms"],
		"aim_prediction_frame_ms": aim_snapshot["prediction_frame_ms"],
		"aim_prediction_recalculations": aim_snapshot["prediction_recalculations"],
		"aim_cue_prediction_steps": aim_snapshot["cue_prediction_steps"],
		"aim_target_prediction_steps": aim_snapshot["target_prediction_steps"],
		"aim_ball_collision_checks": aim_snapshot["ball_collision_checks"],
		"aim_pocket_checks": aim_snapshot["pocket_checks"],
		"aim_rail_checks": aim_snapshot["rail_checks"],
		"aim_spatial_cells": aim_snapshot["spatial_cells"],
		"aim_spatial_balls": aim_snapshot["spatial_balls"],
		"aim_spatial_query_cells": aim_snapshot["spatial_query_cells"],
		"aim_spatial_candidates": aim_snapshot["spatial_candidates"],
		"aim_draw_ms": aim_snapshot["draw_ms"],
		"aim_draw_segments": aim_snapshot["draw_segments"],
		"aim_draw_calls": aim_snapshot["draw_calls"],
		"aim_hit_ball_prediction_active": aim_snapshot["hit_ball_prediction_active"],
		"aim_hit_ball_target_ball_id": aim_snapshot["hit_ball_target_ball_id"],
		"aim_hit_ball_target_number": aim_snapshot["hit_ball_target_number"],
		"aim_hit_ball_route": aim_snapshot["hit_ball_route"],
		"aim_hit_ball_impact_point": aim_snapshot["hit_ball_impact_point"],
		"aim_hit_ball_impact_normal": aim_snapshot["hit_ball_impact_normal"],
		"aim_hit_ball_impact_incoming_direction": aim_snapshot["hit_ball_impact_incoming_direction"],
		"aim_hit_ball_transferred_velocity": aim_snapshot["hit_ball_transferred_velocity"],
		"aim_hit_ball_transferred_direction": aim_snapshot["hit_ball_transferred_direction"],
		"aim_hit_ball_target_prediction_steps": aim_snapshot["hit_ball_target_prediction_steps"],
		"aim_hit_ball_target_first_stop_reason": aim_snapshot["hit_ball_target_first_stop_reason"],
		"aim_hit_ball_target_path_length": aim_snapshot["hit_ball_target_path_length"],
		"aim_hit_ball_target_path_point_count": aim_snapshot["hit_ball_target_path_point_count"],
		"aim_hit_ball_rail_hits_before_impact": aim_snapshot["hit_ball_rail_hits_before_impact"],
		"aim_hit_ball_cue_impact_segment_index": aim_snapshot["hit_ball_cue_impact_segment_index"],
	}


func _get_timing_performance_snapshot() -> Dictionary:
	return {
		"physics_process_ms": perf_physics_process_ms,
		"ball_collision_ms": perf_ball_collision_ms,
		"rail_collision_ms": perf_rail_collision_ms,
		"pocket_check_ms": perf_pocket_check_ms,
	}


func _get_performance_ball_counts(include_visual_cost: bool = true) -> Dictionary:
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
		if not include_visual_cost:
			continue
		var trail_point_count: int = ball.get_trail_point_count()
		counts["trail_points"] += trail_point_count
		counts["balls_with_trails"] += 1 if trail_point_count > 0 else 0
		counts["trail_redraws"] += ball.get_trail_redraw_count()

	counts["stopped"] = maxi(int(counts["total"]) - int(counts["moving"]), 0)
	return counts


func _get_ball_debug_snapshot(ball: Ball) -> Dictionary:
	return {
		"ball_number": ball.ball_number,
		"is_cue_ball": ball == cue_ball,
		"is_eight_ball": ball == eight_ball,
		"is_wayfinder": ball.is_wayfinder,
		"is_powder_keg": ball.is_powder_keg,
		"is_anchor_ball": ball.is_anchor_ball,
		"is_anchor_curse_seed": ball.is_anchor_curse_seed,
		"is_cannon_ball": ball.is_cannon_ball,
		"is_treasure_ball": ball.is_treasure_ball,
		"is_embezzler_ball": ball.is_embezzler_ball,
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
# Center/top callouts are now reserved for explicit event/debug messages.
# Future extraction candidate: HUD/CalloutSystem.
func queue_spawn_reward_message(
	is_wayfinder: bool,
	is_powder_keg: bool = false,
	is_anchor_ball: bool = false,
	is_cannon_ball: bool = false,
	override_message: String = "",
	is_treasure_ball: bool = false,
	is_embezzler_ball: bool = false
) -> void:
	if not override_message.is_empty():
		_queue_result_message(override_message)
		return

	if is_wayfinder:
		_queue_result_message("WAYFINDER BALL DROPPED")
	elif is_powder_keg:
		_queue_result_message("POWDER KEG DROPPED")
	elif is_anchor_ball:
		_queue_result_message("ANCHOR CURSE SEED ROOTED")
	elif is_cannon_ball:
		_queue_result_message("CANNON BALL DROPPED")
	elif is_treasure_ball:
		_queue_result_message("TREASURE BALL DROPPED")
	elif is_embezzler_ball:
		_queue_result_message("EMBEZZLER BALL DROPPED")


func _queue_result_message(message: String) -> void:
	if message.strip_edges().is_empty():
		return

	status_text_changed.emit(message)
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
func _begin_cue_reclaim_motion_snapshot() -> void:
	cue_reclaim_motion_snapshot_updated = false
	_reset_cue_reclaim_motion_snapshot()


func _reset_cue_reclaim_motion_snapshot() -> void:
	cue_reclaim_moving_non_cue_count = 0
	cue_reclaim_low_speed_count = 0
	cue_reclaim_medium_speed_count = 0
	cue_reclaim_high_speed_count = 0
	cue_reclaim_has_cue_collision_threat = false


func _capture_cue_reclaim_motion(ball: Ball) -> void:
	if ball == null or ball == cue_ball or not ball.is_gameplay_active() or not ball.is_moving():
		return

	cue_reclaim_moving_non_cue_count += 1
	var speed: float = ball.velocity.length()
	if speed <= EARLY_CUE_RECLAIM_LOW_SPEED:
		cue_reclaim_low_speed_count += 1
	elif speed <= EARLY_CUE_RECLAIM_MEDIUM_SPEED:
		cue_reclaim_medium_speed_count += 1
	else:
		cue_reclaim_high_speed_count += 1

	if _is_ball_likely_to_hit_cue_soon(ball):
		cue_reclaim_has_cue_collision_threat = true


func _rebuild_cue_reclaim_motion_snapshot() -> void:
	_reset_cue_reclaim_motion_snapshot()
	for child in balls.get_children():
		_capture_cue_reclaim_motion(child as Ball)
	cue_reclaim_motion_snapshot_updated = true


func _update_cue_reclaim_state(delta: float) -> void:
	if not shot_active:
		cue_reclaim_eligible = false
		cue_reclaim_blocker_reason = "No active shot"
		return

	shot_elapsed_time += delta
	if cue_control_reclaimed:
		var base_blocker: String = _get_cue_control_base_blocker()
		cue_reclaim_eligible = base_blocker == ""
		cue_reclaim_blocker_reason = "Granted" if cue_reclaim_eligible else base_blocker
		return

	var signature: String = _get_cue_reclaim_motion_signature()
	if signature != cue_reclaim_cached_signature:
		var result: Dictionary = _evaluate_cue_reclaim_eligibility()
		cue_reclaim_cached_signature = signature
		cue_reclaim_cached_eligible = bool(result["eligible"])
		cue_reclaim_cached_blocker_reason = str(result["reason"])

	cue_reclaim_eligible = cue_reclaim_cached_eligible
	cue_reclaim_blocker_reason = cue_reclaim_cached_blocker_reason
	if cue_reclaim_eligible:
		cue_control_reclaimed = true
		cue_reclaim_blocker_reason = "Granted"
		_handle_cue_control_regained_after_shot()
		status_text_changed.emit(READY_STATUS_TEXT)


func _get_cue_reclaim_motion_signature() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s" % [
		_get_cue_control_base_blocker(),
		shot_elapsed_time >= EARLY_CUE_RECLAIM_DELAY,
		cue_reclaim_moving_non_cue_count,
		cue_reclaim_low_speed_count,
		cue_reclaim_medium_speed_count,
		cue_reclaim_high_speed_count,
		cue_reclaim_has_cue_collision_threat,
		spawn_system.has_pending_spawns(),
	]


func _evaluate_cue_reclaim_eligibility() -> Dictionary:
	var base_blocker: String = _get_cue_control_base_blocker()
	if not base_blocker.is_empty():
		return {"eligible": false, "reason": base_blocker}

	if shot_elapsed_time < EARLY_CUE_RECLAIM_DELAY:
		return {"eligible": false, "reason": "Post-shot delay"}

	if cue_reclaim_has_cue_collision_threat:
		return {"eligible": false, "reason": "Cue collision threat"}

	if cue_reclaim_moving_non_cue_count <= 1:
		return {"eligible": true, "reason": "Safe motion"}

	if cue_reclaim_moving_non_cue_count == 2:
		if cue_reclaim_high_speed_count > 0:
			return {"eligible": false, "reason": "2 balls: high speed"}
		return {"eligible": true, "reason": "Safe motion"}

	if cue_reclaim_moving_non_cue_count <= 4:
		if cue_reclaim_medium_speed_count > 0 or cue_reclaim_high_speed_count > 0:
			return {"eligible": false, "reason": "3-4 balls above low speed"}
		return {"eligible": true, "reason": "Safe motion"}

	return {"eligible": false, "reason": "5+ moving balls"}


func _get_cue_control_base_blocker() -> String:
	if game_over:
		return "Game over"
	if table_event_system != null and table_event_system.is_event_menu_open():
		return "Table Event menu open"
	if ball_placement_system.is_placement_active():
		return "Placement active"
	if not is_instance_valid(cue_ball) or not cue_ball.visible or not cue_ball.gameplay_enabled:
		return "Cue unavailable"
	if spawn_system.has_pending_spawns():
		return "Pending drops"
	if cue_ball.is_moving():
		return "Cue ball moving"
	return ""


func _is_ball_likely_to_hit_cue_soon(ball: Ball) -> bool:
	if not is_instance_valid(cue_ball) or cue_ball.is_moving():
		return false

	var velocity: Vector2 = ball.velocity
	var speed_squared: float = velocity.length_squared()
	if speed_squared <= 0.001:
		return false

	var ball_to_cue: Vector2 = cue_ball.global_position - ball.global_position
	var time_to_closest: float = clamp(
		ball_to_cue.dot(velocity) / speed_squared,
		0.0,
		EARLY_CUE_RECLAIM_THREAT_LOOKAHEAD
	)
	var closest_position: Vector2 = ball.global_position + velocity * time_to_closest
	var threat_radius: float = ball.radius + cue_ball.radius + BALL_COLLISION_SKIN + EARLY_CUE_RECLAIM_THREAT_MARGIN
	return closest_position.distance_squared_to(cue_ball.global_position) <= threat_radius * threat_radius


func _all_balls_stopped() -> bool:
	if spawn_system.has_pending_spawns():
		return false

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null and ball.visible and ball.is_moving():
			return false

	return true
#endregion


#region Legacy Spawn Reward Rules
# Disabled pre-BallDrop reward triggers. Keep these wrappers as reference only;
# the active score-to-chaos path is ScoreSystem -> TableEventSystem -> SpawnSystem.
func _award_base_spawn_progress() -> void:
	if not LEGACY_NON_SCORE_REWARD_DROPS_ENABLED:
		return

	spawn_system.award_base_spawn_progress()


func _try_award_multi_pocket_bonus() -> void:
	if not LEGACY_NON_SCORE_REWARD_DROPS_ENABLED:
		return

	if shot_multi_pocket_bonus_awarded:
		return

	if shot_pocketed_object_balls < MULTI_POCKET_BONUS_THRESHOLD:
		return

	shot_multi_pocket_bonus_awarded = true
	spawn_system.queue_spawn_reward(1)


func _try_award_bank_bonus() -> void:
	if not LEGACY_NON_SCORE_REWARD_DROPS_ENABLED:
		return

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
	_end_cue_drag()

	for child in balls.get_children():
		var ball := child as Ball
		if ball != null:
			ball.velocity = Vector2.ZERO

	status_text_changed.emit("Press F5 in the editor to play another round.")
	game_finished.emit(message)
	queue_redraw()
#endregion
