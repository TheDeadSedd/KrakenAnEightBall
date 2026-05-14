@tool
extends Node
class_name PocketSystem

# Owns scene-authored pocket caching and pocket capture checks.
# Table.gd decides what happens after a ball is captured.
const POCKET_CATCH_BONUS := 8.0

var table
var pockets_root: Node
var pocket_positions: Array[Vector2] = []
var pocket_radii: Array[float] = []
var last_captured_pocket_index := -1
var checks_this_frame := 0
var captures_this_frame := 0


func setup(table_ref) -> void:
	table = table_ref
	pockets_root = table.get_node_or_null("Pockets")


func cache_pockets() -> void:
	pocket_positions.clear()
	pocket_radii.clear()
	if pockets_root == null and table != null:
		pockets_root = table.get_node_or_null("Pockets")
	if pockets_root == null:
		return

	for child in pockets_root.get_children():
		_cache_pocket_node(child)


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


func get_last_captured_pocket_position() -> Vector2:
	if last_captured_pocket_index < 0 or last_captured_pocket_index >= pocket_positions.size():
		return Vector2.ZERO

	return pocket_positions[last_captured_pocket_index]


func get_last_captured_pocket_radius() -> float:
	if last_captured_pocket_index < 0 or last_captured_pocket_index >= pocket_radii.size():
		return 0.0

	return pocket_radii[last_captured_pocket_index]


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
