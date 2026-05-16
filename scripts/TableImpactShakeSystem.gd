@tool
extends Node
class_name TableImpactShakeSystem

# index:title Table Impact Shake System
# index:category UI / Systems / Performance Concerns / In Progress
# index:status In Progress
# index:owner ui_agent
# index:notes Presentation-only fake-3D table impact shake for Powder Keg explosions and Cannon heavy impacts.

# Presentation-only impact feedback. Gameplay nodes keep their real positions;
# Table.gd and Ball.gd only read temporary draw offsets from this system.
@export var enabled := true
@export var impact_duration := 0.22
@export var base_strength := 3.2
@export var strength_per_affected_ball := 0.32
@export var cannon_ball_bonus_strength := 2.2
@export var anchor_spread_strength := 4.2
@export var anchor_spread_strength_per_seed := 0.65
@export var anchor_spread_duration := 0.18
@export var max_table_art_offset := 11.0
@export var floor_offset_ratio := 0.0
@export var ball_shimmy_ratio := 0.30
@export var ball_random_shimmy_ratio := 0.16
@export var max_ball_shimmy_offset := 3.2
@export var center_fallback_radius := 34.0
@export var cannon_impact_duration := 0.12

var table
var _active := false
var _elapsed := 0.0
var _duration := 0.0
var _strength := 0.0
var _direction := Vector2.RIGHT
var _phase := 0.0
var _table_art_visual_offset := Vector2.ZERO
var _ball_variations: Dictionary = {}


func setup(table_ref) -> void:
	table = table_ref
	set_process(false)


func request_powder_keg_impact(
	explosion_position: Vector2,
	affected_ball_count: int,
	cannon_ball_count: int
) -> void:
	if not enabled or table == null:
		return

	_start_impact(
		_get_powder_keg_shake_direction(explosion_position),
		_get_powder_keg_shake_strength(affected_ball_count, cannon_ball_count),
		impact_duration
	)


func request_cannon_heavy_impact(impact_direction: Vector2, impact_strength: float) -> void:
	if not enabled or table == null:
		return
	if _active and _strength >= impact_strength:
		return

	_start_impact(_get_safe_direction(impact_direction), impact_strength, cannon_impact_duration)


func request_anchor_spread_impact(spread_position: Vector2, created_seed_count: int) -> void:
	if not enabled or table == null:
		return

	var table_center: Vector2 = table.playfield_rect.get_center()
	var impact_direction: Vector2 = spread_position - table_center
	var impact_strength: float = anchor_spread_strength + float(created_seed_count) * anchor_spread_strength_per_seed
	_start_impact(_get_safe_direction(impact_direction), impact_strength, anchor_spread_duration)


func _start_impact(impact_direction: Vector2, impact_strength: float, duration: float) -> void:
	_direction = _get_safe_direction(impact_direction)
	_strength = clamp(impact_strength, 0.0, max_table_art_offset)
	_duration = max(duration, 0.01)
	_elapsed = 0.0
	_phase = randf_range(0.0, TAU)
	_active = true
	_clear_ball_shimmy_offsets()
	_cache_ball_variations()
	set_process(true)
	_update_visual_offsets(0.0)


func get_table_art_visual_offset() -> Vector2:
	return _table_art_visual_offset


func get_floor_visual_offset() -> Vector2:
	return _table_art_visual_offset * floor_offset_ratio


func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	if _elapsed >= _duration:
		_finish_impact()
		return

	_update_visual_offsets(_elapsed / _duration)


func _get_powder_keg_shake_direction(explosion_position: Vector2) -> Vector2:
	var table_center: Vector2 = table.playfield_rect.get_center()
	var raw_direction: Vector2 = table_center - explosion_position
	if raw_direction.length() <= center_fallback_radius:
		return Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	return raw_direction.normalized()


func _get_safe_direction(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.001:
		return Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	return direction.normalized()


func _get_powder_keg_shake_strength(affected_ball_count: int, cannon_ball_count: int) -> float:
	var raw_strength: float = (
		base_strength
		+ float(affected_ball_count) * strength_per_affected_ball
		+ float(cannon_ball_count) * cannon_ball_bonus_strength
	)
	return clamp(raw_strength, 0.0, max_table_art_offset)


func _cache_ball_variations() -> void:
	_ball_variations.clear()
	if table == null:
		return

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.visible or not ball.is_gameplay_active():
			continue
		var variation_direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		var variation_scale := randf_range(0.35, 1.0)
		_ball_variations[ball.get_instance_id()] = variation_direction * variation_scale


func _update_visual_offsets(progress: float) -> void:
	var envelope: float = pow(1.0 - clamp(progress, 0.0, 1.0), 2.0)
	var directional_pulse: float = 0.72 + 0.28 * sin(_elapsed * 68.0 + _phase)
	var lateral_pulse: float = sin(_elapsed * 91.0 + _phase * 1.37) * 0.22
	var lateral_direction: Vector2 = _direction.orthogonal()
	_table_art_visual_offset = (
		_direction * directional_pulse
		+ lateral_direction * lateral_pulse
	) * _strength * envelope

	_apply_ball_shimmy_offsets(envelope)
	table.queue_redraw()


func _apply_ball_shimmy_offsets(envelope: float) -> void:
	if table == null:
		return

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball == null or not ball.visible or not ball.is_gameplay_active():
			continue
		var variation: Vector2 = _ball_variations.get(ball.get_instance_id(), Vector2.ZERO)
		var shimmy: Vector2 = (
			_table_art_visual_offset * ball_shimmy_ratio
			+ variation * _strength * ball_random_shimmy_ratio * envelope
		)
		ball.set_impact_shimmy_visual_offset(shimmy.limit_length(max_ball_shimmy_offset))


func _finish_impact() -> void:
	_active = false
	_table_art_visual_offset = Vector2.ZERO
	_clear_ball_shimmy_offsets()
	_ball_variations.clear()
	set_process(false)
	if table != null:
		table.queue_redraw()


func _clear_ball_shimmy_offsets() -> void:
	if table == null:
		return

	for child in table.balls.get_children():
		var ball := child as Ball
		if ball != null:
			ball.set_impact_shimmy_visual_offset(Vector2.ZERO)
