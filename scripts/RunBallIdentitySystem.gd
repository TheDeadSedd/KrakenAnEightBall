extends Node
class_name RunBallIdentitySystem

# Authoritative ball identity is deliberately separate from visual ball numbers
# and Node instance IDs. IDs are never recycled during one run, including when
# Reset Last Shot removes balls that were created after its checkpoint.
static var _next_application_run_generation := 1

var table: BilliardsTable
var run_generation := 0
var next_run_ball_id := 1
var duplicate_id_count := 0
var missing_id_fallback_count := 0
var restored_id_count := 0


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	run_generation = _next_application_run_generation
	_next_application_run_generation += 1
	next_run_ball_id = 1
	duplicate_id_count = 0
	missing_id_fallback_count = 0
	restored_id_count = 0


func assign_ball_id(ball: Ball, requested_id: int = -1, restored: bool = false) -> int:
	if ball == null or not is_instance_valid(ball):
		return -1

	var assigned_id: int = requested_id
	if assigned_id <= 0:
		assigned_id = _allocate_id()
	elif _is_id_in_use(assigned_id, ball):
		duplicate_id_count += 1
		assigned_id = _allocate_id()
	else:
		next_run_ball_id = maxi(next_run_ball_id, assigned_id + 1)

	ball.run_ball_id = assigned_id
	if restored and requested_id > 0 and assigned_id == requested_id:
		restored_id_count += 1
	return assigned_id


func get_ball_id(ball: Ball) -> int:
	if ball == null or not is_instance_valid(ball):
		return -1
	if ball.run_ball_id <= 0:
		missing_id_fallback_count += 1
		return assign_ball_id(ball)
	return ball.run_ball_id


func get_run_generation() -> int:
	return run_generation


func get_rewind_state() -> Dictionary:
	return {
		"run_generation": run_generation,
		"next_run_ball_id": next_run_ball_id,
	}


func restore_rewind_state(state: Dictionary) -> void:
	# The allocator never moves backward. A ball created in a discarded timeline
	# still consumed its ID, while reconstructed checkpoint balls restore theirs.
	run_generation = maxi(int(state.get("run_generation", run_generation)), 1)
	next_run_ball_id = maxi(
		maxi(next_run_ball_id, int(state.get("next_run_ball_id", 1))),
		1
	)


func clear_diagnostic_counters() -> void:
	duplicate_id_count = 0
	missing_id_fallback_count = 0
	restored_id_count = 0


func get_debug_snapshot() -> Dictionary:
	return {
		"run_generation": run_generation,
		"next_run_ball_id": next_run_ball_id,
		"duplicate_id_count": duplicate_id_count,
		"missing_id_fallback_count": missing_id_fallback_count,
		"restored_id_count": restored_id_count,
	}


func _allocate_id() -> int:
	var allocated_id: int = next_run_ball_id
	next_run_ball_id += 1
	return allocated_id


func _is_id_in_use(candidate_id: int, ignored_ball: Ball) -> bool:
	if table == null or table.balls == null:
		return false
	for child in table.balls.get_children():
		var existing_ball: Ball = child as Ball
		if existing_ball == null or existing_ball == ignored_ball:
			continue
		if existing_ball.run_ball_id == candidate_id:
			return true
	return false
