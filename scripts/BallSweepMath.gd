extends RefCounted
class_name BallSweepMath

# Side-effect-free swept-circle math shared by diagnostics and bounded gameplay
# contact ordering. Event/depth caps belong to the caller.
const MIN_RELATIVE_MOVEMENT_SQUARED := 0.000001


static func get_effective_collision_radius(
	moving_radius: float,
	target_radius: float,
	collision_skin: float
) -> float:
	return maxf(moving_radius, 0.0) + maxf(target_radius, 0.0) + maxf(collision_skin, 0.0)


static func sweep_circles(
	moving_start: Vector2,
	moving_delta: Vector2,
	target_start: Vector2,
	target_delta: Vector2,
	combined_radius: float
) -> Dictionary:
	var safe_radius: float = maxf(combined_radius, 0.0)
	var relative_start: Vector2 = moving_start - target_start
	var relative_delta: Vector2 = moving_delta - target_delta
	var c: float = relative_start.length_squared() - safe_radius * safe_radius
	if c <= 0.0:
		return _make_hit_result(
			0.0,
			"already_overlapping",
			moving_start,
			moving_delta,
			target_start,
			target_delta,
			relative_start,
			relative_delta
		)

	var a: float = relative_delta.length_squared()
	if a <= MIN_RELATIVE_MOVEMENT_SQUARED:
		return _make_miss_result("no_relative_movement", relative_start, relative_delta)

	var b: float = 2.0 * relative_start.dot(relative_delta)
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return _make_miss_result("no_intersection", relative_start, relative_delta)

	var sqrt_discriminant: float = sqrt(discriminant)
	var first_fraction: float = (-b - sqrt_discriminant) / (2.0 * a)
	var second_fraction: float = (-b + sqrt_discriminant) / (2.0 * a)
	if first_fraction >= 0.0 and first_fraction <= 1.0:
		return _make_hit_result(
			first_fraction,
			"hit",
			moving_start,
			moving_delta,
			target_start,
			target_delta,
			relative_start,
			relative_delta
		)
	if second_fraction >= 0.0 and second_fraction <= 1.0:
		return _make_hit_result(
			second_fraction,
			"exit_from_overlap",
			moving_start,
			moving_delta,
			target_start,
			target_delta,
			relative_start,
			relative_delta
		)
	return _make_miss_result("outside_substep", relative_start, relative_delta)


static func _make_hit_result(
	hit_fraction: float,
	reason: String,
	moving_start: Vector2,
	moving_delta: Vector2,
	target_start: Vector2,
	target_delta: Vector2,
	relative_start: Vector2,
	relative_delta: Vector2
) -> Dictionary:
	var safe_fraction: float = clampf(hit_fraction, 0.0, 1.0)
	var moving_center: Vector2 = moving_start + moving_delta * safe_fraction
	var target_center: Vector2 = target_start + target_delta * safe_fraction
	var center_offset: Vector2 = target_center - moving_center
	var collision_normal: Vector2 = Vector2.RIGHT
	if center_offset.length_squared() > MIN_RELATIVE_MOVEMENT_SQUARED:
		collision_normal = center_offset.normalized()
	elif relative_delta.length_squared() > MIN_RELATIVE_MOVEMENT_SQUARED:
		collision_normal = -relative_delta.normalized()
	return {
		"hit": true,
		"hit_fraction": safe_fraction,
		"fraction": safe_fraction,
		"moving_center_at_impact": moving_center,
		"target_center_at_impact": target_center,
		"collision_normal": collision_normal,
		"relative_start": relative_start,
		"relative_movement": relative_delta,
		"reason": reason,
	}


static func _make_miss_result(reason: String, relative_start: Vector2, relative_delta: Vector2) -> Dictionary:
	return {
		"hit": false,
		"hit_fraction": -1.0,
		"fraction": -1.0,
		"moving_center_at_impact": Vector2.ZERO,
		"target_center_at_impact": Vector2.ZERO,
		"collision_normal": Vector2.ZERO,
		"relative_start": relative_start,
		"relative_movement": relative_delta,
		"reason": reason,
	}
