extends RefCounted
class_name AimContactOrderDiagnostics

# Debug-only capture for the first cue-contact substep of the current shot.
# It observes the resolver; it never changes pair order or collision response.
const BALL_SWEEP_MATH := preload("res://scripts/BallSweepMath.gd")
const MAX_CANDIDATES := 16
const NEAR_SIMULTANEOUS_TOI_THRESHOLD := 0.10

var capture_complete := false
var resolver_capture_open := false
var substep_start_states: Dictionary = {}
var substep_cue_id := -1
var snapshot: Dictionary = {}
var candidate_index_by_pair_key: Dictionary = {}
var pair_encounter_index := 0
var pair_check_index := 0
var cue_resolution_order := 0


func reset_for_committed_shot() -> void:
	capture_complete = false
	resolver_capture_open = false
	substep_start_states.clear()
	substep_cue_id = -1
	snapshot.clear()
	candidate_index_by_pair_key.clear()
	pair_encounter_index = 0
	pair_check_index = 0
	cue_resolution_order = 0


func begin_substep(
	physics_frame: int,
	substep_index: int,
	total_substeps: int,
	substep_delta: float,
	cue_ball: Ball,
	active_balls: Array[Ball],
	collision_skin: float,
	grid_cell_size: float
) -> void:
	if capture_complete or cue_ball == null or not is_instance_valid(cue_ball):
		return
	substep_start_states.clear()
	substep_cue_id = cue_ball.get_instance_id()
	for ball_index in range(active_balls.size()):
		var ball: Ball = active_balls[ball_index]
		if ball == null or not is_instance_valid(ball):
			continue
		substep_start_states[ball.get_instance_id()] = {
			"ball_id": ball.get_instance_id(),
			"ball_number": ball.ball_number,
			"position": ball.global_position,
			"velocity": ball.velocity,
			"radius": ball.radius,
			"ball_array_index": ball_index,
			"grid_cell": _get_grid_cell(ball.global_position, grid_cell_size),
		}
	snapshot = {
		"captured": false,
		"physics_frame": physics_frame,
		"substep_index": substep_index,
		"substep_number": substep_index + 1,
		"total_substeps": total_substeps,
		"substep_delta": substep_delta,
		"collision_skin": collision_skin,
		"grid_cell_size": grid_cell_size,
		"near_simultaneous_toi_threshold": NEAR_SIMULTANEOUS_TOI_THRESHOLD,
	}


func finish_substep(
	cue_ball: Ball,
	active_balls: Array[Ball],
	collision_skin: float,
	grid_cell_size: float,
	use_projected_motion: bool = false
) -> bool:
	if capture_complete or cue_ball == null or not is_instance_valid(cue_ball):
		return false
	var cue_start_state: Dictionary = _get_start_state(substep_cue_id)
	if cue_start_state.is_empty():
		return false

	var cue_start: Vector2 = cue_start_state.get("position", cue_ball.global_position)
	var substep_delta: float = float(snapshot.get("substep_delta", 0.0))
	var cue_end: Vector2 = (
		cue_start + cue_ball.velocity * substep_delta
		if use_projected_motion
		else cue_ball.global_position
	)
	var cue_movement: Vector2 = cue_end - cue_start
	var cue_segment_length: float = cue_movement.length()
	var candidates: Array[Dictionary] = []
	for target_ball in active_balls:
		if target_ball == null or target_ball == cue_ball or not is_instance_valid(target_ball):
			continue
		var target_start_state: Dictionary = _get_start_state(target_ball.get_instance_id())
		if target_start_state.is_empty():
			continue
		var target_start: Vector2 = target_start_state.get("position", target_ball.global_position)
		var target_end: Vector2 = (
			target_start + target_ball.velocity * substep_delta
			if use_projected_motion
			else target_ball.global_position
		)
		var target_movement: Vector2 = target_end - target_start
		var collision_radius: float = BALL_SWEEP_MATH.get_effective_collision_radius(
			cue_ball.radius,
			target_ball.radius,
			collision_skin
		)
		var toi_result: Dictionary = BALL_SWEEP_MATH.sweep_circles(
			cue_start,
			cue_movement,
			target_start,
			target_movement,
			collision_radius
		)
		var center_distance_after_movement: float = cue_end.distance_to(target_end)
		var overlap_gap_after_movement: float = center_distance_after_movement - collision_radius
		var overlaps_after_movement: bool = overlap_gap_after_movement < 0.0
		var swept_hit: bool = bool(toi_result.get("hit", false))
		if not swept_hit and not overlaps_after_movement:
			continue

		var hit_fraction: float = float(toi_result.get("fraction", -1.0))
		var estimated_cue_center := Vector2.ZERO
		var estimated_target_center := Vector2.ZERO
		var estimated_contact_point := Vector2.ZERO
		if swept_hit:
			estimated_cue_center = toi_result.get("moving_center_at_impact", cue_start + cue_movement * hit_fraction)
			estimated_target_center = toi_result.get("target_center_at_impact", target_start + target_movement * hit_fraction)
			var contact_normal: Vector2 = toi_result.get("collision_normal", Vector2.ZERO)
			estimated_contact_point = estimated_cue_center + contact_normal * cue_ball.radius

		var cue_end_cell: Vector2i = _get_grid_cell(cue_end, grid_cell_size)
		var target_end_cell: Vector2i = _get_grid_cell(target_end, grid_cell_size)
		var cell_delta: Vector2i = target_end_cell - cue_end_cell
		var pair_key: String = _get_pair_key(cue_ball.get_instance_id(), target_ball.get_instance_id())
		candidates.append({
			"ball_id": target_ball.get_instance_id(),
			"ball_number": target_ball.ball_number,
			"pair_key": pair_key,
			"cue_start": cue_start,
			"cue_end": cue_end,
			"target_start": target_start,
			"target_end": target_end,
			"target_movement": target_movement,
			"target_radius": target_ball.radius,
			"target_ball_array_index": int(target_start_state.get("ball_array_index", -1)),
			"target_start_cell": target_start_state.get("grid_cell", Vector2i.ZERO),
			"target_end_cell": target_end_cell,
			"broadphase_neighbor_after_movement": absi(cell_delta.x) <= 1 and absi(cell_delta.y) <= 1,
			"collision_radius": collision_radius,
			"swept_hit": swept_hit,
			"swept_hit_fraction": hit_fraction,
			"swept_rejection_reason": str(toi_result.get("reason", "unknown")),
			"estimated_contact_distance": cue_segment_length * hit_fraction if swept_hit else -1.0,
			"estimated_contact_time_ms": float(snapshot.get("substep_delta", 0.0)) * hit_fraction * 1000.0 if swept_hit else -1.0,
			"estimated_cue_center": estimated_cue_center,
			"estimated_target_center": estimated_target_center,
			"estimated_contact_point": estimated_contact_point,
			"overlaps_after_movement": overlaps_after_movement,
			"center_distance_after_movement": center_distance_after_movement,
			"overlap_gap_after_movement": overlap_gap_after_movement,
			"earliest_swept_candidate": false,
			"pair_encounter_index": -1,
			"pair_check_index": -1,
			"duplicate_pair_encounters": 0,
			"resolver_checked": false,
			"resolver_processed": false,
			"resolver_response_applied": false,
			"resolution_order": -1,
			"center_distance_at_pair_visit": -1.0,
			"overlap_gap_at_pair_visit": 0.0,
			"impact_speed": 0.0,
			"collision_normal": Vector2.ZERO,
		})

	if candidates.is_empty():
		substep_start_states.clear()
		substep_cue_id = -1
		snapshot.clear()
		return false

	candidates.sort_custom(_sort_candidates_by_toi)
	var total_candidate_count: int = candidates.size()
	if candidates.size() > MAX_CANDIDATES:
		candidates.resize(MAX_CANDIDATES)
	_mark_earliest_candidate_and_gaps(candidates, cue_segment_length)

	var cue_velocity: Vector2 = cue_start_state.get("velocity", Vector2.ZERO)
	snapshot.merge({
		"captured": true,
		"cue_ball_id": cue_ball.get_instance_id(),
		"cue_ball_number": cue_ball.ball_number,
		"cue_start": cue_start,
		"cue_end": cue_end,
		"cue_movement": cue_movement,
		"cue_segment_length": cue_segment_length,
		"cue_velocity_at_substep_start": cue_velocity,
		"cue_speed_at_substep_start": cue_velocity.length(),
		"cue_radius": cue_ball.radius,
		"cue_ball_array_index": int(cue_start_state.get("ball_array_index", -1)),
		"cue_start_cell": cue_start_state.get("grid_cell", Vector2i.ZERO),
		"cue_end_cell": _get_grid_cell(cue_end, grid_cell_size),
		"candidate_count": total_candidate_count,
		"stored_candidate_count": candidates.size(),
		"candidates": candidates,
		"resolver_first_ball_id": -1,
		"resolver_first_ball_number": -1,
		"legacy_pair_encounter_first_ball_id": -1,
		"legacy_pair_encounter_first_ball_number": -1,
		"resolver_cue_contact_count": 0,
	}, true)
	candidate_index_by_pair_key.clear()
	for candidate_index in range(candidates.size()):
		candidate_index_by_pair_key[str(candidates[candidate_index].get("pair_key", ""))] = candidate_index
	pair_encounter_index = 0
	pair_check_index = 0
	cue_resolution_order = 0
	capture_complete = true
	resolver_capture_open = true
	substep_start_states.clear()
	substep_cue_id = -1
	return true


func record_pair_encounter(
	ball_a: Ball,
	ball_b: Ball,
	pair_key: String,
	source_cell: Vector2i,
	neighbor_cell: Vector2i,
	is_duplicate: bool
) -> void:
	if not resolver_capture_open:
		return
	pair_encounter_index += 1
	if not is_duplicate:
		pair_check_index += 1
	if not candidate_index_by_pair_key.has(pair_key):
		return
	var candidate: Dictionary = _get_candidate(pair_key)
	if candidate.is_empty():
		return
	if int(candidate.get("pair_encounter_index", -1)) < 0:
		candidate["pair_encounter_index"] = pair_encounter_index
		candidate["resolver_source_ball_id"] = ball_a.get_instance_id()
		candidate["resolver_target_ball_id"] = ball_b.get_instance_id()
		candidate["resolver_source_ball_number"] = ball_a.ball_number
		candidate["resolver_target_ball_number"] = ball_b.ball_number
		candidate["resolver_source_cell"] = source_cell
		candidate["resolver_neighbor_cell"] = neighbor_cell
		var cue_is_source: bool = ball_a.get_instance_id() == int(snapshot.get("cue_ball_id", -1))
		candidate["resolver_source_ball_array_index"] = (
			int(snapshot.get("cue_ball_array_index", -1))
			if cue_is_source
			else int(candidate.get("target_ball_array_index", -1))
		)
		candidate["resolver_target_ball_array_index"] = (
			int(candidate.get("target_ball_array_index", -1))
			if cue_is_source
			else int(snapshot.get("cue_ball_array_index", -1))
		)
	if is_duplicate:
		candidate["duplicate_pair_encounters"] = int(candidate.get("duplicate_pair_encounters", 0)) + 1
	else:
		candidate["pair_check_index"] = pair_check_index
	_set_candidate(pair_key, candidate)


func record_pair_test(
	ball_a: Ball,
	ball_b: Ball,
	pair_key: String,
	center_distance: float,
	effective_radius: float,
	resolver_processed: bool
) -> void:
	if not resolver_capture_open or not candidate_index_by_pair_key.has(pair_key):
		return
	var candidate: Dictionary = _get_candidate(pair_key)
	candidate["resolver_checked"] = true
	candidate["resolver_processed"] = resolver_processed
	candidate["center_distance_at_pair_visit"] = center_distance
	candidate["overlap_gap_at_pair_visit"] = center_distance - effective_radius
	candidate["resolver_pair_order"] = "%s -> %s" % [ball_a.ball_number, ball_b.ball_number]
	_set_candidate(pair_key, candidate)


func record_pair_resolution(
	ball_a: Ball,
	ball_b: Ball,
	pair_key: String,
	response_applied: bool,
	normal: Vector2,
	impact_speed: float,
	resolution_source: String = "legacy"
) -> void:
	if not resolver_capture_open or not candidate_index_by_pair_key.has(pair_key):
		return
	var candidate: Dictionary = _get_candidate(pair_key)
	candidate["resolver_response_applied"] = response_applied
	candidate["resolution_source"] = resolution_source
	candidate["collision_normal"] = normal
	candidate["impact_speed"] = impact_speed
	if response_applied:
		cue_resolution_order += 1
		candidate["resolution_order"] = cue_resolution_order
		snapshot["resolver_cue_contact_count"] = cue_resolution_order
		if int(snapshot.get("resolver_first_ball_id", -1)) < 0:
			var contacted_ball: Ball = ball_b if ball_a.get_instance_id() == int(snapshot.get("cue_ball_id", -1)) else ball_a
			snapshot["resolver_first_ball_id"] = contacted_ball.get_instance_id()
			snapshot["resolver_first_ball_number"] = contacted_ball.ball_number
	_set_candidate(pair_key, candidate)


func get_snapshot() -> Dictionary:
	return snapshot.duplicate(true)


func complete_resolver_pass() -> Dictionary:
	if not resolver_capture_open:
		return {}
	resolver_capture_open = false
	_mark_legacy_pair_encounter_first()
	return get_snapshot()


func _mark_legacy_pair_encounter_first() -> void:
	var candidates_value: Variant = snapshot.get("candidates", [])
	if not candidates_value is Array:
		return
	var earliest_encounter_index: int = 2147483647
	var earliest_ball_id: int = -1
	var earliest_ball_number: int = -1
	for candidate_value in candidates_value:
		if not candidate_value is Dictionary:
			continue
		var candidate: Dictionary = candidate_value
		var encounter_index: int = int(candidate.get("pair_encounter_index", -1))
		if encounter_index < 0 or encounter_index >= earliest_encounter_index:
			continue
		earliest_encounter_index = encounter_index
		earliest_ball_id = int(candidate.get("ball_id", -1))
		earliest_ball_number = int(candidate.get("ball_number", -1))
	snapshot["legacy_pair_encounter_first_ball_id"] = earliest_ball_id
	snapshot["legacy_pair_encounter_first_ball_number"] = earliest_ball_number


func _mark_earliest_candidate_and_gaps(candidates: Array[Dictionary], cue_segment_length: float) -> void:
	var swept_candidates: Array[Dictionary] = []
	for candidate in candidates:
		if bool(candidate.get("swept_hit", false)):
			swept_candidates.append(candidate)
	if swept_candidates.is_empty():
		snapshot["swept_earliest_ball_id"] = -1
		snapshot["swept_earliest_ball_number"] = -1
		snapshot["first_second_toi_delta"] = -1.0
		snapshot["first_second_travel_delta"] = -1.0
		snapshot["first_second_time_delta_ms"] = -1.0
		snapshot["near_simultaneous"] = false
		return

	swept_candidates.sort_custom(_sort_candidates_by_toi)
	var earliest_pair_key: String = str(swept_candidates[0].get("pair_key", ""))
	for candidate_index in range(candidates.size()):
		if str(candidates[candidate_index].get("pair_key", "")) == earliest_pair_key:
			candidates[candidate_index]["earliest_swept_candidate"] = true
			break
	snapshot["swept_earliest_ball_id"] = int(swept_candidates[0].get("ball_id", -1))
	snapshot["swept_earliest_ball_number"] = int(swept_candidates[0].get("ball_number", -1))
	if swept_candidates.size() < 2:
		snapshot["first_second_toi_delta"] = -1.0
		snapshot["first_second_travel_delta"] = -1.0
		snapshot["first_second_time_delta_ms"] = -1.0
		snapshot["near_simultaneous"] = false
		return

	var toi_delta: float = absf(
		float(swept_candidates[1].get("swept_hit_fraction", 0.0))
		- float(swept_candidates[0].get("swept_hit_fraction", 0.0))
	)
	var substep_delta: float = float(snapshot.get("substep_delta", 0.0))
	snapshot["first_second_toi_delta"] = toi_delta
	snapshot["first_second_travel_delta"] = toi_delta * cue_segment_length
	snapshot["first_second_time_delta_ms"] = toi_delta * substep_delta * 1000.0
	snapshot["near_simultaneous"] = toi_delta <= NEAR_SIMULTANEOUS_TOI_THRESHOLD


func _sort_candidates_by_toi(candidate_a: Dictionary, candidate_b: Dictionary) -> bool:
	var a_hit: bool = bool(candidate_a.get("swept_hit", false))
	var b_hit: bool = bool(candidate_b.get("swept_hit", false))
	if a_hit != b_hit:
		return a_hit
	if a_hit:
		return float(candidate_a.get("swept_hit_fraction", INF)) < float(candidate_b.get("swept_hit_fraction", INF))
	return float(candidate_a.get("center_distance_after_movement", INF)) < float(candidate_b.get("center_distance_after_movement", INF))


func _get_candidate(pair_key: String) -> Dictionary:
	var candidates_value: Variant = snapshot.get("candidates", [])
	if not candidates_value is Array:
		return {}
	var candidate_index: int = int(candidate_index_by_pair_key.get(pair_key, -1))
	if candidate_index < 0 or candidate_index >= (candidates_value as Array).size():
		return {}
	var candidate_value: Variant = (candidates_value as Array)[candidate_index]
	return candidate_value as Dictionary if candidate_value is Dictionary else {}


func _set_candidate(pair_key: String, candidate: Dictionary) -> void:
	var candidates: Array = snapshot.get("candidates", [])
	var candidate_index: int = int(candidate_index_by_pair_key.get(pair_key, -1))
	if candidate_index < 0 or candidate_index >= candidates.size():
		return
	candidates[candidate_index] = candidate
	snapshot["candidates"] = candidates


func _get_start_state(ball_id: int) -> Dictionary:
	var value: Variant = substep_start_states.get(ball_id, {})
	return value as Dictionary if value is Dictionary else {}


func _get_grid_cell(position: Vector2, grid_cell_size: float) -> Vector2i:
	var safe_cell_size: float = maxf(grid_cell_size, 1.0)
	return Vector2i(floori(position.x / safe_cell_size), floori(position.y / safe_cell_size))


func _get_pair_key(first_id_value: int, second_id_value: int) -> String:
	var first_id: int = first_id_value
	var second_id: int = second_id_value
	if first_id > second_id:
		var temporary_id: int = first_id
		first_id = second_id
		second_id = temporary_id
	return "%s:%s" % [first_id, second_id]
