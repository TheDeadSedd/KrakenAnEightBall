extends RefCounted
class_name RogueliteRunSystem

# index:title Roguelite Run System
# index:category Run Modes
# index:status First Pass
# index:owner systems_agent
# index:notes Owns roguelite round objective state; gameplay mode ID remains roguelite.

signal state_changed(snapshot: Dictionary)
signal round_started(snapshot: Dictionary)
signal round_won(snapshot: Dictionary)
signal run_failed(snapshot: Dictionary)
signal run_completed(snapshot: Dictionary)

const ROUND_SETUPS := [
	{
		"round_number": 1,
		"target": 30,
		"shots": 3,
		"object_balls": 2,
	},
	{
		"round_number": 2,
		"target": 60,
		"shots": 4,
		"object_balls": 3,
	},
	{
		"round_number": 3,
		"target": 95,
		"shots": 4,
		"object_balls": 4,
	},
	{
		"round_number": 4,
		"target": 130,
		"shots": 5,
		"object_balls": 5,
	},
	{
		"round_number": 5,
		"target": 170,
		"shots": 5,
		"object_balls": 6,
	},
	{
		"round_number": 6,
		"target": 215,
		"shots": 5,
		"object_balls": 7,
	},
	{
		"round_number": 7,
		"target": 265,
		"shots": 6,
		"object_balls": 8,
	},
	{
		"round_number": 8,
		"target": 320,
		"shots": 6,
		"object_balls": 9,
	},
	{
		"round_number": 9,
		"target": 380,
		"shots": 6,
		"object_balls": 10,
	},
	{
		"round_number": 10,
		"target": 455,
		"shots": 7,
		"object_balls": 12,
	},
]

const STARTING_HULL := 3
const TERMINAL_RESULT_FAILED := "failed"
const TERMINAL_RESULT_COMPLETED := "completed"
const TERMINAL_RESULT_UNKNOWN := "unknown"
const FAILURE_REASON_SHOTS := "shots"
const FAILURE_REASON_HULL := "hull"
const FAILURE_REASON_EMPTY_TABLE := "empty_table"
const FAILURE_REASON_UNKNOWN := "unknown"
const OUTCOME_CONTINUE := "continue"
const OUTCOME_ROUND_WON := "round_won"
const OUTCOME_RUN_FAILED_HULL := "run_failed_hull"
const OUTCOME_RUN_FAILED_SHOTS := "run_failed_shots"
const OUTCOME_RUN_FAILED_EMPTY_TABLE := "run_failed_empty_table"
const MAX_RESOLVED_SHOT_TRANSACTION_KEYS := 256
const BALANCE_TUNING_SCRIPT := preload("res://scripts/RogueliteBalanceTuning.gd")

var current_round_index := 0
var round_number := 1
var round_target := 30
var round_score := 0
var shots_left := 3
var hull := STARTING_HULL
var object_ball_count := 2
var round_active := false
var round_won_state := false
var run_failed_state := false
var run_completed_state := false
var failure_reason: String = FAILURE_REASON_UNKNOWN
var total_quota_score_earned: int = 0
var highest_single_round_score: int = 0
var pending_shot_hull_damage: int = 0
var pending_shot_transaction_key: String = ""
var resolved_shot_transaction_keys: Dictionary = {}
var resolved_shot_transaction_key_order: Array[String] = []
var last_completed_shot_transaction: Dictionary = {}
var last_rejected_shot_transaction: Dictionary = {}
var completed_shot_transaction_count: int = 0
var duplicate_shot_transaction_suppressions: int = 0
var rejected_shot_transaction_count: int = 0
var queued_hull_damage_count: int = 0
var duplicate_hull_damage_queue_suppressions: int = 0
var shot_transaction_state_emit_count: int = 0
var shot_transaction_terminal_signal_count: int = 0
var unkeyed_shot_transaction_serial: int = 0
var doubloon_payout_applier: Callable
var build_state_mutation_preparer: Callable
var build_state_mutation_applier: Callable
var last_doubloon_payout_result: Dictionary = {}
var doubloon_payout_application_count: int = 0
var doubloon_payout_duplicate_suppressions: int = 0
var doubloons_awarded_from_shot_payouts: int = 0
var reward_system: RogueliteRewardSystem
var active_balance_tuning_snapshot: Dictionary = {}


func set_reward_system(system: RogueliteRewardSystem) -> void:
	reward_system = system


func set_doubloon_payout_applier(applier: Callable) -> void:
	doubloon_payout_applier = applier


func set_build_state_mutation_handlers(
	preparer: Callable,
	applier: Callable
) -> void:
	build_state_mutation_preparer = preparer
	build_state_mutation_applier = applier


func set_balance_tuning_snapshot(snapshot: Dictionary) -> void:
	active_balance_tuning_snapshot = snapshot.duplicate(true)


func start_run() -> void:
	current_round_index = 0
	if reward_system != null:
		reward_system.reset_run_state()
	_reset_shot_transaction_state()
	hull = _get_current_max_hull()
	failure_reason = FAILURE_REASON_UNKNOWN
	total_quota_score_earned = 0
	highest_single_round_score = 0
	run_completed_state = false
	run_failed_state = false
	start_current_round()


func start_current_round() -> void:
	_clear_queued_shot_consequences()
	var setup: Dictionary = get_current_round_setup()
	round_number = int(setup.get("round_number", 1))
	round_target = maxi(int(setup.get("target", 0)), 0)
	round_score = 0
	shots_left = maxi(int(setup.get("shots", 0)), 0)
	object_ball_count = maxi(int(setup.get("object_balls", 0)), 0)
	round_active = true
	round_won_state = false
	run_failed_state = false
	run_completed_state = false
	failure_reason = FAILURE_REASON_UNKNOWN
	_emit_state()
	round_started.emit(get_snapshot())


func advance_to_next_round() -> bool:
	if run_failed_state or run_completed_state:
		return false
	if not round_won_state:
		return false
	if has_next_round():
		current_round_index += 1
		start_current_round()
		return true

	run_completed_state = true
	round_active = false
	_emit_state()
	run_completed.emit(get_snapshot())
	return false


func has_next_round() -> bool:
	return current_round_index + 1 < ROUND_SETUPS.size()


func get_current_round_setup() -> Dictionary:
	if ROUND_SETUPS.is_empty():
		return {}
	var safe_index: int = clampi(current_round_index, 0, ROUND_SETUPS.size() - 1)
	var setup: Dictionary = ROUND_SETUPS[safe_index] as Dictionary
	var effective_setup: Dictionary = setup.duplicate(true)
	var authored_target: int = maxi(int(setup.get("target", 0)), 0)
	var quota_multiplier: float = BALANCE_TUNING_SCRIPT.get_quota_multiplier_from_snapshot(
		active_balance_tuning_snapshot
	)
	effective_setup["authored_target"] = authored_target
	effective_setup["quota_multiplier"] = quota_multiplier
	effective_setup["target"] = maxi(
		int(roundf(float(authored_target) * quota_multiplier)),
		0
	)
	return effective_setup


func get_round_count() -> int:
	return ROUND_SETUPS.size()


# Production callers should pass the stable ledger attempt key. Blank keys stay
# safe for compatibility and receive a bounded run-local identity at settlement.
func queue_shot_hull_damage(amount: int = 1, transaction_key: String = "") -> Dictionary:
	var normalized_key: String = transaction_key.strip_edges()
	var damage_amount: int = maxi(amount, 0)
	if damage_amount <= 0:
		return _make_hull_queue_result(false, false, normalized_key, "damage_not_positive")
	if not _is_round_eligible_for_shot_resolution():
		return _make_hull_queue_result(false, false, normalized_key, "round_not_eligible")
	if not normalized_key.is_empty() and resolved_shot_transaction_keys.has(normalized_key):
		duplicate_hull_damage_queue_suppressions += 1
		return _make_hull_queue_result(false, true, normalized_key, "transaction_already_resolved")
	if (
		pending_shot_hull_damage > 0
		and not pending_shot_transaction_key.is_empty()
		and not normalized_key.is_empty()
		and pending_shot_transaction_key != normalized_key
	):
		return _make_hull_queue_result(false, false, normalized_key, "pending_transaction_mismatch")

	var duplicate_queue: bool = pending_shot_hull_damage > 0
	if duplicate_queue:
		pending_shot_hull_damage = maxi(pending_shot_hull_damage, damage_amount)
		duplicate_hull_damage_queue_suppressions += 1
	else:
		pending_shot_hull_damage = damage_amount
		queued_hull_damage_count += 1
	if pending_shot_transaction_key.is_empty() and not normalized_key.is_empty():
		pending_shot_transaction_key = normalized_key
	return _make_hull_queue_result(true, duplicate_queue, pending_shot_transaction_key, "")


func resolve_completed_shot(
	score_amount: int,
	scoreable_ball_count: int,
	transaction_key: String = "",
	doubloon_payout: Dictionary = {},
	build_state_mutations: Array = []
) -> Dictionary:
	var normalized_key: String = transaction_key.strip_edges()
	if normalized_key.is_empty() and not pending_shot_transaction_key.is_empty():
		normalized_key = pending_shot_transaction_key
	if not normalized_key.is_empty() and resolved_shot_transaction_keys.has(normalized_key):
		duplicate_shot_transaction_suppressions += 1
		if _get_doubloon_payout_amount(doubloon_payout) > 0:
			doubloon_payout_duplicate_suppressions += 1
		return _reject_completed_shot_transaction(
			normalized_key,
			true,
			"transaction_already_resolved",
			scoreable_ball_count,
			doubloon_payout
		)
	if not _is_round_eligible_for_shot_resolution():
		return _reject_completed_shot_transaction(
			normalized_key,
			false,
			"round_not_eligible",
			scoreable_ball_count,
			doubloon_payout
		)
	if (
		pending_shot_hull_damage > 0
		and not pending_shot_transaction_key.is_empty()
		and not normalized_key.is_empty()
		and pending_shot_transaction_key != normalized_key
	):
		return _reject_completed_shot_transaction(
			normalized_key,
			false,
			"pending_transaction_mismatch",
			scoreable_ball_count,
			doubloon_payout
		)
	if normalized_key.is_empty():
		normalized_key = _make_unkeyed_shot_transaction_key()
	var build_mutation_preparation: Dictionary = _prepare_build_state_mutations(
		normalized_key,
		build_state_mutations
	)
	if not bool(build_mutation_preparation.get("success", false)):
		return _reject_completed_shot_transaction(
			normalized_key,
			false,
			"build_state_mutation_invalid:%s" % str(
				build_mutation_preparation.get("reason", "unknown")
			),
			scoreable_ball_count,
			doubloon_payout
		)

	var score_before: int = round_score
	var score_delta: int = maxi(score_amount, 0)
	var hull_before: int = hull
	var shots_before: int = shots_left
	var queued_hull_damage: int = pending_shot_hull_damage
	var safe_scoreable_ball_count: int = maxi(scoreable_ball_count, 0)
	var safe_payout: Dictionary = _normalize_doubloon_payout(doubloon_payout)

	round_score += score_delta
	total_quota_score_earned += score_delta
	highest_single_round_score = maxi(highest_single_round_score, round_score)
	var payout_application: Dictionary = _apply_doubloon_payout(safe_payout, normalized_key)
	hull = maxi(hull - queued_hull_damage, 0)
	shots_left = maxi(shots_left - 1, 0)
	_clear_queued_shot_consequences()
	# Apply the already-validated value-only build mutation before terminal
	# outcome signals so a terminal shot's earned growth reaches final reports.
	var build_mutation_application: Dictionary = _apply_build_state_mutations(
		normalized_key,
		build_state_mutations,
		build_mutation_preparation
	)

	var outcome: String = _select_completed_shot_outcome(safe_scoreable_ball_count)
	var terminal_shot_payout: bool = (
		outcome != OUTCOME_CONTINUE
		and bool(payout_application.get("applied", false))
		and int(payout_application.get("amount", 0)) > 0
	)
	payout_application["terminal_shot_payout"] = terminal_shot_payout
	payout_application["outcome"] = outcome
	last_doubloon_payout_result = payout_application.duplicate(true)
	_apply_completed_shot_outcome(outcome)
	_remember_resolved_shot_transaction(normalized_key)
	completed_shot_transaction_count += 1
	shot_transaction_state_emit_count += 1
	var terminal_signal_count: int = 0 if outcome == OUTCOME_CONTINUE else 1
	shot_transaction_terminal_signal_count += terminal_signal_count

	var transaction: Dictionary = {
		"accepted": true,
		"duplicate": false,
		"transaction_key": normalized_key,
		"score_before": score_before,
		"score_delta": score_delta,
		"score_after": round_score,
		"round_quota": round_target,
		"doubloon_payout": safe_payout.duplicate(true),
		"doubloon_payout_application": payout_application.duplicate(true),
		"doubloon_payout_amount": int(safe_payout.get("doubloons_awarded", 0)),
		"doubloon_payout_applied": bool(payout_application.get("applied", false)),
		"doubloon_wallet_before": int(payout_application.get("wallet_before", 0)),
		"doubloon_wallet_after": int(payout_application.get("wallet_after", 0)),
		"doubloon_payout_application_key": str(payout_application.get("application_key", "")),
		"terminal_shot_payout": terminal_shot_payout,
		"build_state_mutation_key": normalized_key,
		"item_states_before": _dictionary_from_result(
			build_mutation_preparation,
			"state_before"
		),
		"pending_item_state_mutations": _dictionary_array_from_value(
			build_mutation_preparation.get("pending_state_mutations", build_state_mutations)
		),
		"item_states_after": _dictionary_from_result(
			build_mutation_application,
			"state_after"
		),
		"build_state_mutation_applied": bool(build_mutation_application.get(
			"applied",
			false
		)),
		"build_state_mutation_duplicate_suppressed": bool(
			build_mutation_application.get("duplicate_suppressed", false)
		),
		"build_state_mutation_result": build_mutation_application.duplicate(true),
		"pending_hull_damage": queued_hull_damage,
		"hull_before": hull_before,
		"hull_after": hull,
		"shots_before": shots_before,
		"shots_after": shots_left,
		"scoreable_ball_count": safe_scoreable_ball_count,
		"outcome": outcome,
		"failure_reason": failure_reason,
		"state_emit_count": 1,
		"terminal_signal_count": terminal_signal_count,
		"rejection_reason": "",
	}
	last_completed_shot_transaction = transaction.duplicate(true)
	_emit_state()
	var resolved_snapshot: Dictionary = get_snapshot()
	transaction["snapshot"] = resolved_snapshot
	_emit_completed_shot_outcome_signal(outcome, resolved_snapshot)
	return transaction.duplicate(true)


func _prepare_build_state_mutations(
	transaction_key: String,
	mutations: Array
) -> Dictionary:
	if mutations.is_empty():
		return {
			"success": true,
			"applied": false,
			"mutation_count": 0,
			"transaction_key": transaction_key,
			"state_before": {},
			"simulated_state_after": {},
			"pending_state_mutations": [],
		}
	if not build_state_mutation_preparer.is_valid():
		return {"success": false, "reason": "build_state_mutation_preparer_missing"}
	var result_value: Variant = build_state_mutation_preparer.call(
		transaction_key,
		mutations.duplicate(true)
	)
	if result_value is Dictionary:
		return (result_value as Dictionary).duplicate(true)
	return {"success": false, "reason": "invalid_build_state_preparation_result"}


func _apply_build_state_mutations(
	transaction_key: String,
	mutations: Array,
	preparation: Dictionary
) -> Dictionary:
	if mutations.is_empty():
		return {
			"success": true,
			"applied": false,
			"duplicate_suppressed": false,
			"mutation_count": 0,
			"transaction_key": transaction_key,
			"state_before": _dictionary_from_result(preparation, "state_before"),
			"state_after": _dictionary_from_result(preparation, "simulated_state_after"),
		}
	if not build_state_mutation_applier.is_valid():
		return {"success": false, "reason": "build_state_mutation_applier_missing"}
	var result_value: Variant = build_state_mutation_applier.call(
		transaction_key,
		mutations.duplicate(true)
	)
	if result_value is Dictionary:
		return (result_value as Dictionary).duplicate(true)
	return {"success": false, "reason": "invalid_build_state_application_result"}


func _dictionary_from_result(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array_from_value(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for entry_value in value as Array:
		if entry_value is Dictionary:
			result.append((entry_value as Dictionary).duplicate(true))
	return result


func has_pending_shot_hull_damage() -> bool:
	return pending_shot_hull_damage > 0


func get_shot_transaction_diagnostics() -> Dictionary:
	return {
		"pending_hull_damage": pending_shot_hull_damage,
		"pending_transaction_key": pending_shot_transaction_key,
		"shot_transaction_pending": pending_shot_hull_damage > 0,
		"completed_transactions": completed_shot_transaction_count,
		"resolved_transaction_key_count": resolved_shot_transaction_keys.size(),
		"duplicate_transaction_suppressions": duplicate_shot_transaction_suppressions,
		"rejected_transactions": rejected_shot_transaction_count,
		"queued_hull_damage_count": queued_hull_damage_count,
		"duplicate_hull_queue_suppressions": duplicate_hull_damage_queue_suppressions,
		"state_emit_count": shot_transaction_state_emit_count,
		"terminal_signal_count": shot_transaction_terminal_signal_count,
		"doubloon_payout_application_count": doubloon_payout_application_count,
		"doubloon_payout_duplicate_suppressions": doubloon_payout_duplicate_suppressions,
		"doubloons_awarded_from_shot_payouts": doubloons_awarded_from_shot_payouts,
		"last_doubloon_payout": last_doubloon_payout_result.duplicate(true),
		"last_transaction": last_completed_shot_transaction.duplicate(true),
		"last_rejected_transaction": last_rejected_shot_transaction.duplicate(true),
	}


func get_snapshot() -> Dictionary:
	return {
		"round_index": current_round_index,
		"round_number": round_number,
		"round_count": get_round_count(),
		"round_target": round_target,
		"round_score": round_score,
		"shots_left": shots_left,
		"hull": hull,
		"max_hull": _get_current_max_hull(),
		"starting_hull": STARTING_HULL,
		"object_ball_count": object_ball_count,
		"round_active": round_active,
		"round_won": round_won_state,
		"run_failed": run_failed_state,
		"run_completed": run_completed_state,
		"failure_reason": failure_reason,
		"total_quota_score_earned": total_quota_score_earned,
		"highest_single_round_score": highest_single_round_score,
		"has_next_round": has_next_round(),
		"pending_shot_hull_damage": pending_shot_hull_damage,
		"pending_shot_transaction_key": pending_shot_transaction_key,
		"shot_transaction_pending": pending_shot_hull_damage > 0,
		"shot_transaction_diagnostics": get_shot_transaction_diagnostics(),
		"active_balance_tuning": active_balance_tuning_snapshot.duplicate(true),
	}


func get_rewind_state() -> Dictionary:
	return {
		"current_round_index": current_round_index,
		"round_number": round_number,
		"round_target": round_target,
		"round_score": round_score,
		"shots_left": shots_left,
		"hull": hull,
		"object_ball_count": object_ball_count,
		"round_active": round_active,
		"round_won_state": round_won_state,
		"run_failed_state": run_failed_state,
		"run_completed_state": run_completed_state,
		"failure_reason": failure_reason,
		"total_quota_score_earned": total_quota_score_earned,
		"highest_single_round_score": highest_single_round_score,
		"pending_shot_hull_damage": pending_shot_hull_damage,
		"pending_shot_transaction_key": pending_shot_transaction_key,
		"resolved_shot_transaction_keys": resolved_shot_transaction_keys.duplicate(true),
		"resolved_shot_transaction_key_order": resolved_shot_transaction_key_order.duplicate(),
		"last_completed_shot_transaction": last_completed_shot_transaction.duplicate(true),
		"last_rejected_shot_transaction": last_rejected_shot_transaction.duplicate(true),
		"completed_shot_transaction_count": completed_shot_transaction_count,
		"duplicate_shot_transaction_suppressions": duplicate_shot_transaction_suppressions,
		"rejected_shot_transaction_count": rejected_shot_transaction_count,
		"queued_hull_damage_count": queued_hull_damage_count,
		"duplicate_hull_damage_queue_suppressions": duplicate_hull_damage_queue_suppressions,
		"shot_transaction_state_emit_count": shot_transaction_state_emit_count,
		"shot_transaction_terminal_signal_count": shot_transaction_terminal_signal_count,
		"unkeyed_shot_transaction_serial": unkeyed_shot_transaction_serial,
		"last_doubloon_payout_result": last_doubloon_payout_result.duplicate(true),
		"doubloon_payout_application_count": doubloon_payout_application_count,
		"doubloon_payout_duplicate_suppressions": doubloon_payout_duplicate_suppressions,
		"doubloons_awarded_from_shot_payouts": doubloons_awarded_from_shot_payouts,
		"active_balance_tuning": active_balance_tuning_snapshot.duplicate(true),
	}


func restore_rewind_state(state: Dictionary) -> void:
	current_round_index = maxi(int(state.get("current_round_index", 0)), 0)
	round_number = maxi(int(state.get("round_number", 1)), 1)
	round_target = maxi(int(state.get("round_target", 0)), 0)
	round_score = maxi(int(state.get("round_score", 0)), 0)
	shots_left = maxi(int(state.get("shots_left", 0)), 0)
	hull = maxi(int(state.get("hull", STARTING_HULL)), 0)
	object_ball_count = maxi(int(state.get("object_ball_count", 0)), 0)
	round_active = bool(state.get("round_active", true))
	round_won_state = bool(state.get("round_won_state", false))
	run_failed_state = bool(state.get("run_failed_state", false))
	run_completed_state = bool(state.get("run_completed_state", false))
	failure_reason = str(state.get("failure_reason", FAILURE_REASON_UNKNOWN))
	total_quota_score_earned = maxi(int(state.get("total_quota_score_earned", 0)), 0)
	highest_single_round_score = maxi(int(state.get("highest_single_round_score", 0)), 0)
	pending_shot_hull_damage = maxi(int(state.get("pending_shot_hull_damage", 0)), 0)
	pending_shot_transaction_key = str(state.get("pending_shot_transaction_key", ""))
	_restore_resolved_shot_transaction_keys(state)
	last_completed_shot_transaction = _dictionary_from_state(
		state,
		"last_completed_shot_transaction"
	)
	last_rejected_shot_transaction = _dictionary_from_state(
		state,
		"last_rejected_shot_transaction"
	)
	completed_shot_transaction_count = maxi(
		int(state.get("completed_shot_transaction_count", 0)),
		0
	)
	duplicate_shot_transaction_suppressions = maxi(
		int(state.get("duplicate_shot_transaction_suppressions", 0)),
		0
	)
	rejected_shot_transaction_count = maxi(
		int(state.get("rejected_shot_transaction_count", 0)),
		0
	)
	queued_hull_damage_count = maxi(int(state.get("queued_hull_damage_count", 0)), 0)
	duplicate_hull_damage_queue_suppressions = maxi(
		int(state.get("duplicate_hull_damage_queue_suppressions", 0)),
		0
	)
	shot_transaction_state_emit_count = maxi(
		int(state.get("shot_transaction_state_emit_count", 0)),
		0
	)
	shot_transaction_terminal_signal_count = maxi(
		int(state.get("shot_transaction_terminal_signal_count", 0)),
		0
	)
	unkeyed_shot_transaction_serial = maxi(
		int(state.get("unkeyed_shot_transaction_serial", 0)),
		0
	)
	last_doubloon_payout_result = _dictionary_from_state(
		state,
		"last_doubloon_payout_result"
	)
	doubloon_payout_application_count = maxi(
		int(state.get("doubloon_payout_application_count", 0)),
		0
	)
	doubloon_payout_duplicate_suppressions = maxi(
		int(state.get("doubloon_payout_duplicate_suppressions", 0)),
		0
	)
	doubloons_awarded_from_shot_payouts = maxi(
		int(state.get("doubloons_awarded_from_shot_payouts", 0)),
		0
	)
	var balance_tuning_value: Variant = state.get("active_balance_tuning", {})
	active_balance_tuning_snapshot = (
		(balance_tuning_value as Dictionary).duplicate(true)
		if balance_tuning_value is Dictionary
		else {}
	)
	_emit_state()


func get_terminal_summary_snapshot(result_override: String = "") -> Dictionary:
	var result: String = result_override
	if result.is_empty():
		result = _get_terminal_result()

	var reward_snapshot: Dictionary = _get_reward_terminal_snapshot()
	return {
		"result": result,
		"reached_round": round_number,
		"cleared_round": round_number,
		"round_count": get_round_count(),
		"failure_reason": failure_reason if result == TERMINAL_RESULT_FAILED else "",
		"round_score": round_score,
		"round_target": round_target,
		"shots_left": shots_left,
		"hull": hull,
		"max_hull": _get_current_max_hull(),
		"rewards_chosen_count": int(reward_snapshot.get("chosen_reward_count", 0)),
		"rewards_chosen_display_names": reward_snapshot.get("chosen_reward_display_names", []),
		"rewards_chosen_ids": reward_snapshot.get("chosen_reward_ids", []),
		"total_quota_score_earned": total_quota_score_earned,
		"highest_single_round_score": highest_single_round_score,
		"final_object_ball_count": object_ball_count,
		"active_balance_tuning": active_balance_tuning_snapshot.duplicate(true),
	}


func _emit_state() -> void:
	state_changed.emit(get_snapshot())


func _get_current_max_hull() -> int:
	return STARTING_HULL


func _get_terminal_result() -> String:
	if run_completed_state:
		return TERMINAL_RESULT_COMPLETED
	if run_failed_state:
		return TERMINAL_RESULT_FAILED
	return TERMINAL_RESULT_UNKNOWN


func _get_reward_terminal_snapshot() -> Dictionary:
	if reward_system == null:
		return {
			"chosen_reward_count": 0,
			"chosen_reward_display_names": [],
			"chosen_reward_ids": [],
		}
	return reward_system.get_reward_snapshot()


func _is_round_eligible_for_shot_resolution() -> bool:
	return (
		round_active
		and not round_won_state
		and not run_failed_state
		and not run_completed_state
	)


func _select_completed_shot_outcome(scoreable_ball_count: int) -> String:
	if hull <= 0:
		return OUTCOME_RUN_FAILED_HULL
	if round_score >= round_target:
		return OUTCOME_ROUND_WON
	if shots_left <= 0:
		return OUTCOME_RUN_FAILED_SHOTS
	if scoreable_ball_count <= 0:
		return OUTCOME_RUN_FAILED_EMPTY_TABLE
	return OUTCOME_CONTINUE


func _apply_completed_shot_outcome(outcome: String) -> void:
	round_won_state = outcome == OUTCOME_ROUND_WON
	run_failed_state = outcome in [
		OUTCOME_RUN_FAILED_HULL,
		OUTCOME_RUN_FAILED_SHOTS,
		OUTCOME_RUN_FAILED_EMPTY_TABLE,
	]
	round_active = outcome == OUTCOME_CONTINUE
	failure_reason = FAILURE_REASON_UNKNOWN
	match outcome:
		OUTCOME_RUN_FAILED_HULL:
			failure_reason = FAILURE_REASON_HULL
		OUTCOME_RUN_FAILED_SHOTS:
			failure_reason = FAILURE_REASON_SHOTS
		OUTCOME_RUN_FAILED_EMPTY_TABLE:
			failure_reason = FAILURE_REASON_EMPTY_TABLE


func _emit_completed_shot_outcome_signal(outcome: String, snapshot: Dictionary) -> void:
	match outcome:
		OUTCOME_ROUND_WON:
			round_won.emit(snapshot)
		OUTCOME_RUN_FAILED_HULL, OUTCOME_RUN_FAILED_SHOTS, OUTCOME_RUN_FAILED_EMPTY_TABLE:
			run_failed.emit(snapshot)


func _remember_resolved_shot_transaction(transaction_key: String) -> void:
	if transaction_key.is_empty() or resolved_shot_transaction_keys.has(transaction_key):
		return
	resolved_shot_transaction_keys[transaction_key] = true
	resolved_shot_transaction_key_order.append(transaction_key)
	while resolved_shot_transaction_key_order.size() > MAX_RESOLVED_SHOT_TRANSACTION_KEYS:
		var oldest_key: String = str(resolved_shot_transaction_key_order.pop_front())
		resolved_shot_transaction_keys.erase(oldest_key)


func _make_unkeyed_shot_transaction_key() -> String:
	unkeyed_shot_transaction_serial += 1
	return "unkeyed:%d:%d" % [current_round_index, unkeyed_shot_transaction_serial]


func _clear_queued_shot_consequences() -> void:
	pending_shot_hull_damage = 0
	pending_shot_transaction_key = ""


func _reset_shot_transaction_state() -> void:
	_clear_queued_shot_consequences()
	resolved_shot_transaction_keys.clear()
	resolved_shot_transaction_key_order.clear()
	last_completed_shot_transaction.clear()
	last_rejected_shot_transaction.clear()
	completed_shot_transaction_count = 0
	duplicate_shot_transaction_suppressions = 0
	rejected_shot_transaction_count = 0
	queued_hull_damage_count = 0
	duplicate_hull_damage_queue_suppressions = 0
	shot_transaction_state_emit_count = 0
	shot_transaction_terminal_signal_count = 0
	unkeyed_shot_transaction_serial = 0
	last_doubloon_payout_result.clear()
	doubloon_payout_application_count = 0
	doubloon_payout_duplicate_suppressions = 0
	doubloons_awarded_from_shot_payouts = 0


func _make_hull_queue_result(
	accepted: bool,
	duplicate: bool,
	transaction_key: String,
	rejection_reason: String
) -> Dictionary:
	return {
		"accepted": accepted,
		"duplicate": duplicate,
		"transaction_key": transaction_key,
		"pending_hull_damage": pending_shot_hull_damage,
		"hull_before": hull,
		"projected_hull_after": maxi(hull - pending_shot_hull_damage, 0),
		"rejection_reason": rejection_reason,
	}


func _reject_completed_shot_transaction(
	transaction_key: String,
	duplicate: bool,
	rejection_reason: String,
	scoreable_ball_count: int,
	doubloon_payout: Dictionary = {}
) -> Dictionary:
	rejected_shot_transaction_count += 1
	var transaction: Dictionary = {
		"accepted": false,
		"duplicate": duplicate,
		"transaction_key": transaction_key,
		"score_before": round_score,
		"score_delta": 0,
		"score_after": round_score,
		"round_quota": round_target,
		"doubloon_payout": _normalize_doubloon_payout(doubloon_payout),
		"doubloon_payout_applied": false,
		"doubloon_payout_duplicate_suppressed": duplicate,
		"pending_hull_damage": pending_shot_hull_damage,
		"hull_before": hull,
		"hull_after": hull,
		"shots_before": shots_left,
		"shots_after": shots_left,
		"scoreable_ball_count": maxi(scoreable_ball_count, 0),
		"outcome": "rejected",
		"failure_reason": failure_reason,
		"state_emit_count": 0,
		"terminal_signal_count": 0,
		"rejection_reason": rejection_reason,
	}
	last_rejected_shot_transaction = transaction.duplicate(true)
	transaction["snapshot"] = get_snapshot()
	return transaction.duplicate(true)


func _normalize_doubloon_payout(payout: Dictionary) -> Dictionary:
	if payout.is_empty():
		return {
			"schema_version": 1,
			"source": "haul_mult_base_haul_v1",
			"shot_id": -1,
			"attempt_id": -1,
			"base_haul": 0,
			"scoring_object_ball_count": 0,
			"doubloons_awarded": 0,
			"warnings": [],
		}
	var normalized: Dictionary = payout.duplicate(true)
	normalized["base_haul"] = maxi(int(normalized.get("base_haul", 0)), 0)
	normalized["scoring_object_ball_count"] = maxi(
		int(normalized.get("scoring_object_ball_count", 0)),
		0
	)
	normalized["doubloons_awarded"] = _get_doubloon_payout_amount(normalized)
	return normalized


func _get_doubloon_payout_amount(payout: Dictionary) -> int:
	return maxi(int(payout.get("doubloons_awarded", 0)), 0)


func _apply_doubloon_payout(payout: Dictionary, transaction_key: String) -> Dictionary:
	var amount: int = _get_doubloon_payout_amount(payout)
	var application_key: String = "%s|payout:%s" % [
		transaction_key,
		str(payout.get("source", "unknown")),
	]
	var application: Dictionary = payout.duplicate(true)
	application["applied"] = false
	application["amount"] = amount
	application["application_key"] = application_key
	application["wallet_before"] = 0
	application["wallet_after"] = 0
	application["reason"] = "zero_payout" if amount <= 0 else "payout_applier_unavailable"
	application["duplicate_suppression"] = false
	application["terminal_shot_payout"] = false
	if not doubloon_payout_applier.is_valid():
		return application

	var application_value: Variant = doubloon_payout_applier.call(
		payout.duplicate(true),
		application_key
	)
	if not application_value is Dictionary:
		application["reason"] = "invalid_payout_application_result"
		return application
	var wallet_result: Dictionary = (application_value as Dictionary).duplicate(true)
	for key_value in wallet_result.keys():
		application[key_value] = wallet_result[key_value]
	if bool(application.get("applied", false)):
		doubloon_payout_application_count += 1
		doubloons_awarded_from_shot_payouts += amount
	return application


func _restore_resolved_shot_transaction_keys(state: Dictionary) -> void:
	resolved_shot_transaction_keys.clear()
	resolved_shot_transaction_key_order.clear()
	var order_value: Variant = state.get("resolved_shot_transaction_key_order", [])
	if order_value is Array:
		for key_value in order_value:
			var transaction_key: String = str(key_value)
			if transaction_key.is_empty() or resolved_shot_transaction_keys.has(transaction_key):
				continue
			resolved_shot_transaction_keys[transaction_key] = true
			resolved_shot_transaction_key_order.append(transaction_key)
	var key_map_value: Variant = state.get("resolved_shot_transaction_keys", {})
	if key_map_value is Dictionary:
		for key_value in (key_map_value as Dictionary).keys():
			var map_transaction_key: String = str(key_value)
			if map_transaction_key.is_empty() or resolved_shot_transaction_keys.has(map_transaction_key):
				continue
			resolved_shot_transaction_keys[map_transaction_key] = true
			resolved_shot_transaction_key_order.append(map_transaction_key)
	while resolved_shot_transaction_key_order.size() > MAX_RESOLVED_SHOT_TRANSACTION_KEYS:
		var oldest_key: String = str(resolved_shot_transaction_key_order.pop_front())
		resolved_shot_transaction_keys.erase(oldest_key)


func _dictionary_from_state(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = state.get(key, {})
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
