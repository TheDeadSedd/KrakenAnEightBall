@tool
extends Node
class_name BoundarySystem

# Owns scene-authored rail/jaw boundary caching and rectangle collision queries.
# Table.gd still owns the real physics loop and shot consequences.
class BoundaryMotionState:
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var rail_position := Vector2.ZERO
	var rail_normal := Vector2.ZERO
	var hit_rail := false

class BoundaryHit:
	var position := Vector2.ZERO
	var incoming_velocity := Vector2.ZERO
	var normal := Vector2.ZERO

var table
var boundaries_root: Node
var boundary_shapes: Array[CollisionShape2D] = []
var boundary_reference_rects: Array[Rect2] = []
var checks_this_frame := 0
var collisions_this_frame := 0


func setup(table_ref) -> void:
	table = table_ref
	boundaries_root = table.get_node_or_null("Boundaries")


func cache_boundaries() -> void:
	boundary_shapes.clear()
	boundary_reference_rects.clear()
	if boundaries_root == null and table != null:
		boundaries_root = table.get_node_or_null("Boundaries")
	if boundaries_root == null:
		return

	for shape_node in boundaries_root.find_children("*", "CollisionShape2D", true, false):
		_cache_boundary_shape(shape_node)


func reset_frame_stats() -> void:
	checks_this_frame = 0
	collisions_this_frame = 0


func has_boundaries() -> bool:
	return not boundary_shapes.is_empty()


func get_boundary_shapes() -> Array[CollisionShape2D]:
	return boundary_shapes


func get_boundary_reference_rects() -> Array[Rect2]:
	return boundary_reference_rects


func get_checks_this_frame() -> int:
	return checks_this_frame


func get_collisions_this_frame() -> int:
	return collisions_this_frame


func get_inner_rect() -> Rect2:
	if boundary_reference_rects.is_empty():
		return Rect2()

	var overall_bounds: Rect2 = boundary_reference_rects[0]
	for boundary_rect in boundary_reference_rects:
		overall_bounds = overall_bounds.merge(boundary_rect)

	return _calculate_inner_rect_from_reference_bounds(overall_bounds)


func resolve_ball_against_boundaries(ball: Ball, rail_restitution: float) -> Array:
	var hit_events: Array = []
	for boundary_shape in boundary_shapes:
		checks_this_frame += 1
		var hit_event = _resolve_ball_against_boundary_shape(ball, boundary_shape, rail_restitution)
		if hit_event != null:
			collisions_this_frame += 1
			hit_events.append(hit_event)

	return hit_events


func resolve_motion_state_against_shape(
	step_result,
	collision_shape: CollisionShape2D,
	ball_radius: float,
	rail_restitution: float
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
		ball_radius,
		rail_restitution
	)


func _cache_boundary_shape(shape_node: Node) -> void:
	var collision_shape := shape_node as CollisionShape2D
	if collision_shape == null:
		return
	# Preserve the current custom rail solver: it only responds to rectangle
	# collision shapes. Other authored helpers can stay in the scene safely.
	if not (collision_shape.shape is RectangleShape2D):
		return

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


func _calculate_inner_rect_from_reference_bounds(overall_bounds: Rect2) -> Rect2:
	var center: Vector2 = overall_bounds.get_center()
	var inner := _get_empty_inner_rect_edges()
	for boundary_rect in boundary_reference_rects:
		_update_inner_rect_edges(inner, boundary_rect, center)

	return _make_inner_rect_from_edges(inner)


func _get_empty_inner_rect_edges() -> Dictionary:
	return {
		"left": -INF,
		"right": INF,
		"top": -INF,
		"bottom": INF,
	}


func _update_inner_rect_edges(inner: Dictionary, boundary_rect: Rect2, center: Vector2) -> void:
	if boundary_rect.size.x >= boundary_rect.size.y:
		if boundary_rect.get_center().y < center.y:
			inner["top"] = max(float(inner["top"]), boundary_rect.end.y)
		else:
			inner["bottom"] = min(float(inner["bottom"]), boundary_rect.position.y)
	else:
		if boundary_rect.get_center().x < center.x:
			inner["left"] = max(float(inner["left"]), boundary_rect.end.x)
		else:
			inner["right"] = min(float(inner["right"]), boundary_rect.position.x)


func _make_inner_rect_from_edges(inner: Dictionary) -> Rect2:
	if inner["left"] == -INF or inner["right"] == INF or inner["top"] == -INF or inner["bottom"] == INF:
		return Rect2()
	if inner["right"] <= inner["left"] or inner["bottom"] <= inner["top"]:
		return Rect2()

	return Rect2(
		float(inner["left"]),
		float(inner["top"]),
		float(inner["right"]) - float(inner["left"]),
		float(inner["bottom"]) - float(inner["top"])
	)


func _resolve_ball_against_boundary_shape(ball: Ball, collision_shape: CollisionShape2D, rail_restitution: float):
	var incoming_velocity: Vector2 = ball.velocity
	var step_result: BoundaryMotionState = BoundaryMotionState.new()
	step_result.position = ball.global_position
	step_result.velocity = ball.velocity
	resolve_motion_state_against_shape(step_result, collision_shape, ball.radius, rail_restitution)
	ball.global_position = step_result.position
	ball.velocity = step_result.velocity

	if not step_result.hit_rail:
		return null

	var hit_event: BoundaryHit = BoundaryHit.new()
	hit_event.position = ball.global_position
	hit_event.incoming_velocity = incoming_velocity
	hit_event.normal = step_result.rail_normal
	return hit_event


func _apply_boundary_response_to_state(
	step_result,
	shape_transform: Transform2D,
	local_position: Vector2,
	closest_local: Vector2,
	half_size: Vector2,
	distance: float,
	ball_radius: float,
	rail_restitution: float
) -> void:
	var normal_local: Vector2 = _get_boundary_collision_normal_local(local_position, closest_local, half_size, distance)
	var normal_world: Vector2 = shape_transform.basis_xform(normal_local).normalized()
	step_result.position += normal_world * (ball_radius - distance + 0.01)

	var normal_speed: float = step_result.velocity.dot(normal_world)
	if normal_speed >= 0.0:
		return

	step_result.velocity -= normal_world * (1.0 + rail_restitution) * normal_speed
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
		return (local_ball_position - closest_local).normalized()

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
