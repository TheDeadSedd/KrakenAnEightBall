extends RefCounted
class_name BallMotionMath

# Pure layered drag math shared by Ball and cloned trajectory prediction.
static func get_speed_drag_multiplier(
	speed: float,
	stop_threshold: float,
	medium_speed_drag_start: float,
	high_speed_drag_multiplier: float,
	medium_speed_drag_multiplier: float,
	low_speed_drag_start: float,
	low_speed_drag_multiplier: float,
	crawl_speed_drag_start: float,
	crawl_speed_drag_multiplier: float
) -> float:
	if speed >= medium_speed_drag_start:
		return high_speed_drag_multiplier
	if speed >= low_speed_drag_start:
		var medium_ratio: float = _inverse_lerp(medium_speed_drag_start, low_speed_drag_start, speed)
		return lerpf(1.0, medium_speed_drag_multiplier, medium_ratio)
	if speed >= crawl_speed_drag_start:
		var low_ratio: float = _inverse_lerp(low_speed_drag_start, crawl_speed_drag_start, speed)
		return lerpf(medium_speed_drag_multiplier, low_speed_drag_multiplier, low_ratio)
	var crawl_ratio: float = _inverse_lerp(crawl_speed_drag_start, stop_threshold, speed)
	return lerpf(low_speed_drag_multiplier, crawl_speed_drag_multiplier, crawl_ratio)


static func get_effective_friction(
	speed: float,
	rolling_friction: float,
	stop_threshold: float,
	medium_speed_drag_start: float,
	high_speed_drag_multiplier: float,
	medium_speed_drag_multiplier: float,
	low_speed_drag_start: float,
	low_speed_drag_multiplier: float,
	crawl_speed_drag_start: float,
	crawl_speed_drag_multiplier: float
) -> float:
	return rolling_friction * get_speed_drag_multiplier(
		speed,
		stop_threshold,
		medium_speed_drag_start,
		high_speed_drag_multiplier,
		medium_speed_drag_multiplier,
		low_speed_drag_start,
		low_speed_drag_multiplier,
		crawl_speed_drag_start,
		crawl_speed_drag_multiplier
	)


static func apply_friction(velocity: Vector2, delta: float, parameters: Dictionary) -> Vector2:
	var speed: float = velocity.length()
	if speed <= 0.0:
		return Vector2.ZERO
	var stop_threshold: float = float(parameters.get("stop_threshold", 4.0))
	var effective_friction: float = get_effective_friction(
		speed,
		float(parameters.get("rolling_friction", 105.0)),
		stop_threshold,
		float(parameters.get("medium_speed_drag_start", 140.0)),
		float(parameters.get("high_speed_drag_multiplier", 1.22)),
		float(parameters.get("medium_speed_drag_multiplier", 1.15)),
		float(parameters.get("low_speed_drag_start", 60.0)),
		float(parameters.get("low_speed_drag_multiplier", 1.8)),
		float(parameters.get("crawl_speed_drag_start", 22.0)),
		float(parameters.get("crawl_speed_drag_multiplier", 3.0))
	)
	var updated_velocity: Vector2 = velocity.move_toward(Vector2.ZERO, effective_friction * delta)
	return Vector2.ZERO if updated_velocity.length() < stop_threshold else updated_velocity


static func _inverse_lerp(start: float, end: float, value: float) -> float:
	if is_equal_approx(start, end):
		return 0.0
	return clampf((value - start) / (end - start), 0.0, 1.0)
