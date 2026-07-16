@tool
extends Node
class_name PocketSystem

# Owns scene-authored pocket caching and pocket capture checks.
# Table.gd decides what happens after a ball is captured.
const BALL_SWEEP_MATH := preload("res://scripts/BallSweepMath.gd")
const POCKET_CATCH_BONUS := 8.0

var table
var pockets_root: Node
var pocket_positions: Array[Vector2] = []
var pocket_radii: Array[float] = []
var pocket_names: Array[String] = []
var prediction_geometry_snapshot: Array[Dictionary] = []
var prediction_geometry_revision := 0
var last_captured_pocket_index := -1
var checks_this_frame := 0
var captures_this_frame := 0


func setup(table_ref) -> void:
	table = table_ref
	pockets_root = table.get_node_or_null("Pockets")


func cache_pockets() -> void:
	pocket_positions.clear()
	pocket_radii.clear()
	pocket_names.clear()
	prediction_geometry_snapshot = []
	if pockets_root == null and table != null:
		pockets_root = table.get_node_or_null("Pockets")
	if pockets_root == null:
		prediction_geometry_revision += 1
		return

	for child in pockets_root.get_children():
		_cache_pocket_node(child)
	_rebuild_prediction_geometry_snapshot()
	prediction_geometry_revision += 1


func reset_frame_stats() -> void:
	checks_this_frame = 0
	captures_this_frame = 0


func check_pockets(moving_balls: Array[Ball]) -> Ball:
	last_captured_pocket_index = -1
	for ball in moving_balls:
		var pocket_index: int = _get_capturing_pocket_index(ball)
		if pocket_index >= 0:
			last_captured_pocket_index = pocket_index
			captures_this_frame += 1
			return ball

	return null


func is_position_too_close_to_pocket(candidate: Vector2, ball_radius: float, extra_clearance: float = 8.0) -> bool:
	for pocket_index in range(pocket_positions.size()):
		var pocket_position: Vector2 = pocket_positions[pocket_index]
		var pocket_radius: float = pocket_radii[pocket_index]
		if candidate.distance_to(pocket_position) < pocket_radius + ball_radius + extra_clearance:
			return true

	return false


func get_pocket_positions() -> Array[Vector2]:
	return pocket_positions


func get_pocket_radii() -> Array[float]:
	return pocket_radii


func get_prediction_geometry_snapshot() -> Array[Dictionary]:
	# Read-only cached records. Rebuilds replace the array atomically.
	return prediction_geometry_snapshot


func get_prediction_geometry_revision() -> int:
	return prediction_geometry_revision


func _rebuild_prediction_geometry_snapshot() -> void:
	var rebuilt_geometry: Array[Dictionary] = []
	var pocket_count: int = mini(pocket_positions.size(), pocket_radii.size())
	for pocket_index in range(pocket_count):
		var pocket_position: Vector2 = pocket_positions[pocket_index]
		var pocket_radius: float = pocket_radii[pocket_index]
		rebuilt_geometry.append({
			"pocket_index": pocket_index,
			"position": pocket_position,
			"radius": pocket_radius,
			"world_aabb": Rect2(
				pocket_position - Vector2.ONE * pocket_radius,
				Vector2.ONE * pocket_radius * 2.0
			),
		})
	prediction_geometry_snapshot = rebuilt_geometry


func get_capture_fraction_against_geometry(
	pocket_geometry: Dictionary,
	start_position: Vector2,
	displacement: Vector2,
	ball_radius: float
) -> float:
	var pocket_position: Vector2 = pocket_geometry.get("position", Vector2.ZERO)
	var catch_radius: float = get_capture_radius(
		float(pocket_geometry.get("radius", 0.0)),
		ball_radius
	)
	var relative_start: Vector2 = start_position - pocket_position
	var c: float = relative_start.length_squared() - catch_radius * catch_radius
	if c <= 0.0:
		return 0.0
	var a: float = displacement.length_squared()
	if a <= 0.0000001:
		return -1.0
	var b: float = 2.0 * relative_start.dot(displacement)
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var hit_fraction: float = (-b - sqrt(discriminant)) / (2.0 * a)
	return hit_fraction if hit_fraction >= 0.0 and hit_fraction <= 1.0 else -1.0


func get_capture_radius(pocket_radius: float, ball_radius: float) -> float:
	return _get_pocket_catch_radius(pocket_radius, ball_radius)


func get_last_captured_pocket_position() -> Vector2:
	if last_captured_pocket_index < 0 or last_captured_pocket_index >= pocket_positions.size():
		return Vector2.ZERO

	return pocket_positions[last_captured_pocket_index]


func get_last_captured_pocket_index() -> int:
	return last_captured_pocket_index


func get_last_captured_pocket_radius() -> float:
	if last_captured_pocket_index < 0 or last_captured_pocket_index >= pocket_radii.size():
		return 0.0

	return pocket_radii[last_captured_pocket_index]


func get_last_captured_pocket_name() -> String:
	if last_captured_pocket_index < 0 or last_captured_pocket_index >= pocket_names.size():
		return ""
	return pocket_names[last_captured_pocket_index]


func get_first_capture_fraction_for_motion(
	start_position: Vector2,
	displacement: Vector2,
	ball_radius: float
) -> float:
	# Side-effect-free chronology query; normal pocket capture remains authoritative.
	var earliest_fraction: float = INF
	for pocket_index in range(pocket_positions.size()):
		var catch_radius: float = _get_pocket_catch_radius(pocket_radii[pocket_index], ball_radius)
		var sweep_result: Dictionary = BALL_SWEEP_MATH.sweep_circles(
			start_position,
			displacement,
			pocket_positions[pocket_index],
			Vector2.ZERO,
			catch_radius
		)
		if not bool(sweep_result.get("hit", false)):
			continue
		earliest_fraction = minf(earliest_fraction, float(sweep_result.get("hit_fraction", 1.0)))
	return -1.0 if earliest_fraction == INF else earliest_fraction


func get_first_capture_fraction_from_snapshot(
	geometry: Array,
	start_position: Vector2,
	displacement: Vector2,
	ball_radius: float
) -> float:
	var earliest_fraction: float = INF
	for geometry_value in geometry:
		if not geometry_value is Dictionary:
			continue
		var pocket_geometry: Dictionary = geometry_value
		var hit_fraction: float = get_capture_fraction_against_geometry(
			pocket_geometry,
			start_position,
			displacement,
			ball_radius
		)
		if hit_fraction >= 0.0:
			earliest_fraction = minf(earliest_fraction, hit_fraction)
	return -1.0 if earliest_fraction == INF else earliest_fraction


func get_checks_this_frame() -> int:
	return checks_this_frame


func get_captures_this_frame() -> int:
	return captures_this_frame


func _cache_pocket_node(node: Node) -> void:
	var pocket_node := node as Node2D
	if pocket_node == null:
		return

	var collision_shape: CollisionShape2D = pocket_node.get_node_or_null("CollisionShape2D")
	if collision_shape == null:
		return

	var circle_shape: CircleShape2D = collision_shape.shape as CircleShape2D
	if circle_shape == null:
		return

	pocket_positions.append(collision_shape.global_position)
	pocket_radii.append(circle_shape.radius)
	pocket_names.append(str(pocket_node.name))


func _get_capturing_pocket_index(ball: Ball) -> int:
	for pocket_index in range(pocket_positions.size()):
		checks_this_frame += 1
		var pocket_position: Vector2 = pocket_positions[pocket_index]
		var catch_radius: float = _get_pocket_catch_radius(pocket_radii[pocket_index], ball.radius)
		if ball.global_position.distance_to(pocket_position) <= catch_radius:
			return pocket_index

	return -1


func _get_pocket_catch_radius(pocket_radius: float, ball_radius: float) -> float:
	return pocket_radius + ball_radius * 0.5 + POCKET_CATCH_BONUS
