extends RefCounted
class_name BallCollisionMath

# Pure normal-ball collision math shared by live physics and cloned prediction.
static func get_impact_speed(velocity_a: Vector2, velocity_b: Vector2, normal: Vector2) -> float:
	return (velocity_a - velocity_b).dot(normal)


static func get_normal_impulse(
	velocity_a: Vector2,
	velocity_b: Vector2,
	normal: Vector2,
	restitution: float,
	velocity_transfer: float
) -> Vector2:
	var speed_along_normal: float = get_impact_speed(velocity_a, velocity_b, normal)
	if speed_along_normal <= 0.0:
		return Vector2.ZERO
	var impulse_strength: float = (1.0 + restitution) * speed_along_normal * 0.5
	impulse_strength *= velocity_transfer
	return normal * impulse_strength


static func get_normal_response(
	velocity_a: Vector2,
	velocity_b: Vector2,
	normal: Vector2,
	restitution: float,
	velocity_transfer: float
) -> Dictionary:
	var impulse: Vector2 = get_normal_impulse(
		velocity_a,
		velocity_b,
		normal,
		restitution,
		velocity_transfer
	)
	return {
		"applied": impulse.length_squared() > 0.0,
		"impact_speed": get_impact_speed(velocity_a, velocity_b, normal),
		"impulse": impulse,
		"velocity_a": velocity_a - impulse,
		"velocity_b": velocity_b + impulse,
	}
