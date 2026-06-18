extends Node2D
class_name TableObstacleSystem

const TABLE_OBSTACLE_SCENE := preload("res://scenes/TableObstacle.tscn")
const OBSTACLE_Z_INDEX := 0
const OBSTACLE_SEPARATION_EPSILON := 0.25
const COLLISION_DISTANCE_EPSILON := 0.001
const DEBUG_COLLISION_FILL_COLOR := Color(0.1, 0.75, 0.95, 0.12)
const DEBUG_COLLISION_LINE_COLOR := Color(0.45, 0.95, 1.0, 0.92)
const DEBUG_COLLISION_CENTER_COLOR := Color(1.0, 0.78, 0.28, 0.95)

@export var obstacle_collision_enabled := true
@export var debug_collision_draw_enabled := false
@export_range(0.0, 1.0, 0.01) var obstacle_bounce_restitution := 0.65
@export_range(0.0, 1.0, 0.01) var obstacle_tangent_retention := 0.94
@export var obstacle_collision_skin := 0.75
@export var debris_spawn_margin := 96.0
@export var debris_min_spawn_distance := 190.0
@export_range(1, 80, 1) var debris_spawn_attempts := 32

class ObstacleCollisionData:
	var obstacle: Node2D
	var polygon_node: CollisionPolygon2D
	var local_points := PackedVector2Array()
	var world_points := PackedVector2Array()
	var world_aabb := Rect2()
	var world_center := Vector2.ZERO
	var bounding_radius := 0.0
	var edge_normals := PackedVector2Array()
	var cached_polygon_transform := Transform2D.IDENTITY
	var cache_valid := false

var table: BilliardsTable
var obstacles_holder: Node2D
var rng := RandomNumberGenerator.new()
var spawned_obstacles: Array[Node2D] = []
var obstacle_collision_data_by_id: Dictionary = {}
var perf_active_debris_count := 0
var perf_obstacle_broadphase_checks := 0
var perf_obstacle_broadphase_skips := 0
var perf_obstacle_detailed_polygon_checks := 0
var perf_obstacle_collision_hits := 0
var perf_obstacle_cache_rebuilds := 0
var perf_obstacle_collision_ms := 0.0


func _ready() -> void:
	rng.randomize()


func _process(_delta: float) -> void:
	if debug_collision_draw_enabled:
		queue_redraw()


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	obstacles_holder = _get_or_create_obstacles_holder()


func _draw() -> void:
	draw_debug(self)


func set_obstacle_collision_enabled(enabled: bool) -> void:
	obstacle_collision_enabled = enabled


func set_debug_collision_draw_enabled(enabled: bool) -> void:
	debug_collision_draw_enabled = enabled
	_queue_table_redraw()


func has_collision_obstacles() -> bool:
	if not obstacle_collision_enabled:
		return false
	if obstacles_holder == null and table != null:
		obstacles_holder = table.get_node_or_null("Obstacles") as Node2D
	return obstacles_holder != null and obstacles_holder.get_child_count() > 0


func reset_frame_stats() -> void:
	perf_active_debris_count = 0
	perf_obstacle_broadphase_checks = 0
	perf_obstacle_broadphase_skips = 0
	perf_obstacle_detailed_polygon_checks = 0
	perf_obstacle_collision_hits = 0
	perf_obstacle_cache_rebuilds = 0
	perf_obstacle_collision_ms = 0.0


func get_debug_snapshot() -> Dictionary:
	return {
		"active_debris_count": maxi(perf_active_debris_count, _count_active_debris()),
		"obstacle_broadphase_checks": perf_obstacle_broadphase_checks,
		"obstacle_broadphase_skips": perf_obstacle_broadphase_skips,
		"obstacle_detailed_polygon_checks": perf_obstacle_detailed_polygon_checks,
		"obstacle_collision_hits": perf_obstacle_collision_hits,
		"obstacle_cache_rebuilds": perf_obstacle_cache_rebuilds,
		"obstacle_collision_ms": perf_obstacle_collision_ms,
	}


func debug_spawn_wood_debris() -> Node2D:
	if table == null:
		return null

	if obstacles_holder == null:
		obstacles_holder = _get_or_create_obstacles_holder()
	if obstacles_holder == null:
		return null

	var obstacle := TABLE_OBSTACLE_SCENE.instantiate() as Node2D
	if obstacle == null:
		return null

	_center_obstacle_visual(obstacle)
	_disable_collision_shapes(obstacle)
	obstacle.name = "WoodDebris"
	obstacle.position = _get_debug_spawn_position()
	obstacle.rotation = rng.randf_range(0.0, TAU)
	obstacle.z_index = OBSTACLE_Z_INDEX
	obstacle.z_as_relative = true
	obstacles_holder.add_child(obstacle)
	spawned_obstacles.append(obstacle)
	_register_obstacle_collision_data(obstacle)
	_queue_table_redraw()
	return obstacle


func draw_debug(canvas: CanvasItem) -> void:
	if not debug_collision_draw_enabled or canvas == null:
		return

	for collision_data in _get_active_collision_data():
		_draw_obstacle_collision_debug(canvas, collision_data)


func resolve_ball_collisions(active_balls: Array[Ball]) -> void:
	if not obstacle_collision_enabled or active_balls.is_empty():
		return

	var collision_start_usec: int = Time.get_ticks_usec()
	var active_collision_data := _get_active_collision_data()
	perf_active_debris_count = active_collision_data.size()
	if active_collision_data.is_empty():
		perf_obstacle_collision_ms += _elapsed_ms_since(collision_start_usec)
		return

	for ball in active_balls:
		if ball == null or not ball.is_gameplay_active() or not ball.is_moving():
			continue
		for collision_data in active_collision_data:
			_resolve_ball_against_obstacle(ball, collision_data)
	perf_obstacle_collision_ms += _elapsed_ms_since(collision_start_usec)


func clear_debug_debris() -> void:
	if obstacles_holder == null:
		for obstacle in spawned_obstacles:
			if is_instance_valid(obstacle):
				obstacle.queue_free()
		spawned_obstacles.clear()
		obstacle_collision_data_by_id.clear()
		_queue_table_redraw()
		return

	for child in obstacles_holder.get_children():
		child.queue_free()
	spawned_obstacles.clear()
	obstacle_collision_data_by_id.clear()
	_queue_table_redraw()


func _get_active_collision_data() -> Array:
	var active_collision_data: Array = []
	if obstacles_holder == null:
		obstacles_holder = _get_or_create_obstacles_holder()
	if obstacles_holder == null:
		return active_collision_data

	var active_ids := {}
	for child in obstacles_holder.get_children():
		var obstacle := child as Node2D
		if obstacle != null and obstacle.visible and not obstacle.is_queued_for_deletion():
			var obstacle_id: int = obstacle.get_instance_id()
			active_ids[obstacle_id] = true
			if not obstacle_collision_data_by_id.has(obstacle_id):
				_register_obstacle_collision_data(obstacle)
			var collision_data = obstacle_collision_data_by_id.get(obstacle_id)
			if _is_collision_data_valid(collision_data):
				_refresh_collision_data_cache(collision_data)
				active_collision_data.append(collision_data)

	for obstacle_id in obstacle_collision_data_by_id.keys():
		if not active_ids.has(obstacle_id):
			obstacle_collision_data_by_id.erase(obstacle_id)
	return active_collision_data


func _count_active_debris() -> int:
	if obstacles_holder == null:
		obstacles_holder = _get_or_create_obstacles_holder()
	if obstacles_holder == null:
		return 0

	var active_count := 0
	for child in obstacles_holder.get_children():
		var obstacle := child as Node2D
		if obstacle != null and obstacle.visible and not obstacle.is_queued_for_deletion():
			active_count += 1
	return active_count


func _register_obstacle_collision_data(obstacle: Node2D) -> void:
	if obstacle == null:
		return

	var polygon_node := _find_collision_polygon(obstacle)
	if polygon_node == null or polygon_node.polygon.size() < 3:
		return

	var collision_data := ObstacleCollisionData.new()
	collision_data.obstacle = obstacle
	collision_data.polygon_node = polygon_node
	collision_data.local_points = polygon_node.polygon.duplicate()
	_refresh_collision_data_cache(collision_data)
	obstacle_collision_data_by_id[obstacle.get_instance_id()] = collision_data


func _find_collision_polygon(root: Node) -> CollisionPolygon2D:
	if root is CollisionPolygon2D:
		return root as CollisionPolygon2D

	for child in root.get_children():
		var polygon_node := _find_collision_polygon(child)
		if polygon_node != null:
			return polygon_node
	return null


func _is_collision_data_valid(collision_data) -> bool:
	return (
		collision_data != null
		and is_instance_valid(collision_data.obstacle)
		and is_instance_valid(collision_data.polygon_node)
		and collision_data.local_points.size() >= 3
	)


func _get_transformed_polygon_points(collision_data) -> PackedVector2Array:
	if not _is_collision_data_valid(collision_data):
		return PackedVector2Array()
	_refresh_collision_data_cache(collision_data)
	return collision_data.world_points


func _refresh_collision_data_cache(collision_data) -> void:
	if not _is_collision_data_valid(collision_data):
		return

	var polygon_transform: Transform2D = collision_data.polygon_node.global_transform
	if collision_data.cache_valid and polygon_transform == collision_data.cached_polygon_transform:
		return

	var world_points := PackedVector2Array()
	for local_point in collision_data.local_points:
		world_points.append(polygon_transform * local_point)

	collision_data.world_points = world_points
	collision_data.world_aabb = _calculate_polygon_aabb(world_points)
	collision_data.world_center = _get_polygon_centroid(world_points)
	collision_data.bounding_radius = _calculate_polygon_bounding_radius(world_points, collision_data.world_center)
	collision_data.edge_normals = _calculate_polygon_edge_normals(world_points)
	collision_data.cached_polygon_transform = polygon_transform
	collision_data.cache_valid = true
	perf_obstacle_cache_rebuilds += 1


func _resolve_ball_against_obstacle(ball: Ball, collision_data) -> void:
	if not _is_collision_data_valid(collision_data):
		return

	var collision_radius := ball.radius + obstacle_collision_skin
	perf_obstacle_broadphase_checks += 1
	if not _passes_obstacle_broadphase(ball.global_position, collision_radius, collision_data):
		perf_obstacle_broadphase_skips += 1
		return

	perf_obstacle_detailed_polygon_checks += 1
	var hit := _get_circle_polygon_collision(ball.global_position, collision_radius, collision_data)
	if not bool(hit.get("hit", false)):
		return

	var normal_world: Vector2 = hit.get("normal", Vector2.ZERO)
	var penetration := float(hit.get("penetration", 0.0))
	if normal_world.length_squared() <= COLLISION_DISTANCE_EPSILON or penetration <= 0.0:
		return
	normal_world = normal_world.normalized()
	ball.global_position += normal_world * (penetration + OBSTACLE_SEPARATION_EPSILON)
	_apply_obstacle_velocity_response(ball, normal_world)
	perf_obstacle_collision_hits += 1


func _apply_obstacle_velocity_response(ball: Ball, normal_world: Vector2) -> void:
	var normal_speed: float = ball.velocity.dot(normal_world)
	if normal_speed >= 0.0:
		return

	var normal_velocity: Vector2 = normal_world * normal_speed
	var tangent_velocity: Vector2 = ball.velocity - normal_velocity
	ball.velocity = tangent_velocity * obstacle_tangent_retention - normal_velocity * obstacle_bounce_restitution


func _draw_obstacle_collision_debug(canvas: CanvasItem, collision_data) -> void:
	var points := _get_transformed_polygon_points(collision_data)
	if points.size() < 3:
		return

	var canvas_points := PackedVector2Array()
	for point in points:
		canvas_points.append(_to_canvas_local(canvas, point))

	canvas.draw_colored_polygon(canvas_points, DEBUG_COLLISION_FILL_COLOR)
	for index in range(canvas_points.size()):
		var next_index := (index + 1) % canvas_points.size()
		canvas.draw_line(canvas_points[index], canvas_points[next_index], DEBUG_COLLISION_LINE_COLOR, 2.0)

	var center: Vector2 = _to_canvas_local(canvas, _get_polygon_centroid(points))
	canvas.draw_line(center + Vector2(-6.0, 0.0), center + Vector2(6.0, 0.0), DEBUG_COLLISION_CENTER_COLOR, 1.5)
	canvas.draw_line(center + Vector2(0.0, -6.0), center + Vector2(0.0, 6.0), DEBUG_COLLISION_CENTER_COLOR, 1.5)


func _passes_obstacle_broadphase(center: Vector2, radius: float, collision_data) -> bool:
	var radius_sum: float = collision_data.bounding_radius + radius
	if center.distance_squared_to(collision_data.world_center) > radius_sum * radius_sum:
		return false

	return collision_data.world_aabb.grow(radius).has_point(center)


func _get_circle_polygon_collision(center: Vector2, radius: float, collision_data) -> Dictionary:
	var polygon_points: PackedVector2Array = collision_data.world_points
	if polygon_points.size() < 3:
		return {"hit": false, "normal": Vector2.ZERO, "penetration": 0.0}

	var center_inside := Geometry2D.is_point_in_polygon(center, polygon_points)
	var best_hit := {
		"hit": false,
		"normal": Vector2.ZERO,
		"penetration": 0.0,
	}
	var nearest_edge := {
		"distance": INF,
		"closest_point": Vector2.ZERO,
		"outward_normal": Vector2.RIGHT,
	}

	for index in range(polygon_points.size()):
		var edge_start: Vector2 = polygon_points[index]
		var edge_end: Vector2 = polygon_points[(index + 1) % polygon_points.size()]
		var closest_point := _get_closest_point_on_segment(center, edge_start, edge_end)
		var offset: Vector2 = center - closest_point
		var distance: float = offset.length()
		var outward_normal := _get_cached_edge_normal(collision_data, index)

		if distance < float(nearest_edge["distance"]):
			nearest_edge["distance"] = distance
			nearest_edge["closest_point"] = closest_point
			nearest_edge["outward_normal"] = outward_normal

		if center_inside or distance > radius:
			continue

		var normal := outward_normal if distance <= COLLISION_DISTANCE_EPSILON else offset / distance
		var penetration := radius - distance
		if penetration > float(best_hit["penetration"]):
			best_hit["hit"] = true
			best_hit["normal"] = normal
			best_hit["penetration"] = penetration

	if center_inside:
		var nearest_distance := float(nearest_edge["distance"])
		var nearest_point: Vector2 = nearest_edge["closest_point"]
		var normal: Vector2 = nearest_edge["outward_normal"]
		if nearest_distance > COLLISION_DISTANCE_EPSILON:
			normal = (nearest_point - center) / nearest_distance
		best_hit["hit"] = true
		best_hit["normal"] = normal
		best_hit["penetration"] = radius + nearest_distance

	return best_hit


func _get_closest_point_on_segment(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> Vector2:
	var segment: Vector2 = segment_end - segment_start
	var length_squared: float = segment.length_squared()
	if length_squared <= COLLISION_DISTANCE_EPSILON:
		return segment_start

	var t := clampf((point - segment_start).dot(segment) / length_squared, 0.0, 1.0)
	return segment_start + segment * t


func _get_cached_edge_normal(collision_data, edge_index: int) -> Vector2:
	if edge_index < 0 or edge_index >= collision_data.edge_normals.size():
		return Vector2.RIGHT
	return collision_data.edge_normals[edge_index]


func _calculate_polygon_edge_normals(polygon_points: PackedVector2Array) -> PackedVector2Array:
	var normals := PackedVector2Array()
	if polygon_points.size() < 2:
		return normals

	var signed_area := _calculate_polygon_signed_area(polygon_points)
	var use_right_normals := signed_area > 0.0
	for index in range(polygon_points.size()):
		var edge_start: Vector2 = polygon_points[index]
		var edge_end: Vector2 = polygon_points[(index + 1) % polygon_points.size()]
		var edge: Vector2 = edge_end - edge_start
		if edge.length_squared() <= COLLISION_DISTANCE_EPSILON:
			normals.append(Vector2.RIGHT)
			continue

		var normal := Vector2(edge.y, -edge.x) if use_right_normals else Vector2(-edge.y, edge.x)
		normals.append(normal.normalized())
	return normals


func _calculate_polygon_signed_area(polygon_points: PackedVector2Array) -> float:
	var signed_area := 0.0
	for index in range(polygon_points.size()):
		var current_point: Vector2 = polygon_points[index]
		var next_point: Vector2 = polygon_points[(index + 1) % polygon_points.size()]
		signed_area += current_point.cross(next_point)
	return signed_area * 0.5


func _calculate_polygon_aabb(polygon_points: PackedVector2Array) -> Rect2:
	if polygon_points.size() == 0:
		return Rect2()

	var aabb := Rect2(polygon_points[0], Vector2.ZERO)
	for point in polygon_points:
		aabb = aabb.expand(point)
	return aabb


func _calculate_polygon_bounding_radius(polygon_points: PackedVector2Array, center: Vector2) -> float:
	var radius := 0.0
	for point in polygon_points:
		radius = maxf(radius, center.distance_to(point))
	return radius


func _get_polygon_centroid(polygon_points: PackedVector2Array) -> Vector2:
	if polygon_points.size() == 0:
		return Vector2.ZERO

	var centroid := Vector2.ZERO
	for point in polygon_points:
		centroid += point
	return centroid / float(polygon_points.size())


func _to_canvas_local(canvas: CanvasItem, world_position: Vector2) -> Vector2:
	var node_2d := canvas as Node2D
	if node_2d == null:
		return world_position
	return node_2d.to_local(world_position)


func _get_or_create_obstacles_holder() -> Node2D:
	if table == null:
		return null

	var holder := table.get_node_or_null("Obstacles") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "Obstacles"
		table.add_child(holder)
		if table.balls != null:
			table.move_child(holder, table.balls.get_index())

	holder.z_index = OBSTACLE_Z_INDEX
	holder.z_as_relative = true
	table.obstacles = holder
	return holder


func _get_debug_spawn_position() -> Vector2:
	table._ensure_table_geometry_cached()
	var spawn_rect := _get_debris_spawn_rect()
	var existing_positions := _get_existing_debris_positions()
	if existing_positions.is_empty():
		return _get_random_point_in_rect(spawn_rect)

	var best_position := spawn_rect.get_center()
	var best_distance := -INF
	for _attempt_index in range(maxi(debris_spawn_attempts, 1)):
		var candidate := _get_random_point_in_rect(spawn_rect)
		var nearest_distance := _get_nearest_existing_debris_distance(candidate, existing_positions)
		if nearest_distance > best_distance:
			best_distance = nearest_distance
			best_position = candidate
		if nearest_distance >= debris_min_spawn_distance:
			return candidate

	return best_position


func _get_debris_spawn_rect() -> Rect2:
	var source_rect := table.playfield_rect
	if source_rect.size == Vector2.ZERO:
		source_rect = BilliardsTable.SPAWN_REFERENCE_RECT

	var max_safe_margin: float = maxf(minf(source_rect.size.x, source_rect.size.y) * 0.45, 0.0)
	var safe_margin: float = clampf(debris_spawn_margin, 0.0, max_safe_margin)
	var spawn_rect: Rect2 = source_rect.grow(-safe_margin)
	if spawn_rect.size.x <= 0.0 or spawn_rect.size.y <= 0.0:
		return source_rect
	return spawn_rect


func _get_random_point_in_rect(rect: Rect2) -> Vector2:
	return Vector2(
		rng.randf_range(rect.position.x, rect.end.x),
		rng.randf_range(rect.position.y, rect.end.y)
	)


func _get_existing_debris_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if obstacles_holder == null:
		obstacles_holder = _get_or_create_obstacles_holder()
	if obstacles_holder == null:
		return positions

	for child in obstacles_holder.get_children():
		var obstacle := child as Node2D
		if obstacle != null and obstacle.visible and not obstacle.is_queued_for_deletion():
			positions.append(obstacle.global_position)
	return positions


func _get_nearest_existing_debris_distance(position: Vector2, existing_positions: Array[Vector2]) -> float:
	var nearest_distance := INF
	for existing_position in existing_positions:
		nearest_distance = minf(nearest_distance, position.distance_to(existing_position))
	return nearest_distance


func _center_obstacle_visual(obstacle: Node2D) -> void:
	var sprite := obstacle.get_node_or_null("Sprite2D") as Node2D
	if sprite != null:
		sprite.position = Vector2.ZERO


func _disable_collision_shapes(root: Node) -> void:
	if root is CollisionShape2D:
		var shape := root as CollisionShape2D
		shape.disabled = true
	elif root is CollisionPolygon2D:
		var polygon := root as CollisionPolygon2D
		polygon.disabled = true

	for child in root.get_children():
		_disable_collision_shapes(child)


func _queue_table_redraw() -> void:
	queue_redraw()


func _elapsed_ms_since(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1000.0
