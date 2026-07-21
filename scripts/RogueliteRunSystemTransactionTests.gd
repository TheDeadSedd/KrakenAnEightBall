extends SceneTree

# Standalone pure regression harness for Long Sink completed-shot settlement.
# Run with:
# godot4 --headless --path <project> --script res://scripts/RogueliteRunSystemTransactionTests.gd

const RUN_SYSTEM_SCRIPT: Script = preload("res://scripts/RogueliteRunSystem.gd")


class SignalCounter:
	extends RefCounted

	var state_changed_count: int = 0
	var round_won_count: int = 0
	var run_failed_count: int = 0


	func connect_to(run_system: RogueliteRunSystem) -> void:
		run_system.state_changed.connect(_on_state_changed)
		run_system.round_won.connect(_on_round_won)
		run_system.run_failed.connect(_on_run_failed)


	func _on_state_changed(_snapshot: Dictionary) -> void:
		state_changed_count += 1


	func _on_round_won(_snapshot: Dictionary) -> void:
		round_won_count += 1


	func _on_run_failed(_snapshot: Dictionary) -> void:
		run_failed_count += 1


class MockWallet:
	extends RefCounted

	var total: int = 0
	var application_count: int = 0


	func apply(payout: Dictionary, application_key: String) -> Dictionary:
		var before: int = total
		var amount: int = maxi(int(payout.get("doubloons_awarded", 0)), 0)
		total += amount
		application_count += 1
		return {
			"applied": amount > 0,
			"application_key": application_key,
			"amount": amount,
			"wallet_before": before,
			"wallet_after": total,
			"reason": "" if amount > 0 else "zero_payout",
		}


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var report: Dictionary = run_all()
	print(_format_report(report))
	quit(0 if int(report.get("failed", 0)) == 0 else 1)


static func run_all() -> Dictionary:
	var cases: Array[Dictionary] = []
	_test_score_continuation(cases)
	_test_quota_clear(cases)
	_test_zero_score_shot_failure(cases)
	_test_nonfatal_hull_damage(cases)
	_test_fatal_hull_after_score(cases)
	_test_fatal_hull_beats_quota(cases)
	_test_empty_table(cases)
	_test_one_prioritized_outcome_signal(cases)
	_test_duplicate_transaction_rejection(cases)
	_test_atomic_payout_before_fatal_hull(cases)
	_test_duplicate_transaction_suppresses_payout(cases)
	_test_rewind_restoration(cases)
	_test_rewind_replay_new_attempt(cases)
	return _build_report(cases)


static func _test_score_continuation(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var result: Dictionary = run_system.resolve_completed_shot(10, 2)
	_record_case(
		cases,
		"score-only continuation",
		bool(result.get("accepted", false))
			and str(result.get("transaction_key", "")).begins_with("unkeyed:")
			and int(result.get("score_after", -1)) == 10
			and int(result.get("shots_after", -1)) == 2
			and str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_CONTINUE
			and signals.state_changed_count == 1
			and signals.round_won_count + signals.run_failed_count == 0,
		{"score_after": 10, "shots_after": 2, "outcome": "continue"},
		_result_summary(result, signals)
	)


static func _test_quota_clear(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var result: Dictionary = run_system.resolve_completed_shot(30, 2, "quota-clear")
	_record_case(
		cases,
		"quota clear",
		bool(result.get("accepted", false))
			and int(result.get("score_after", -1)) == 30
			and int(result.get("shots_after", -1)) == 2
			and str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_ROUND_WON
			and signals.state_changed_count == 1
			and signals.round_won_count == 1
			and signals.run_failed_count == 0,
		{"score_after": 30, "outcome": "round_won", "round_won_signals": 1},
		_result_summary(result, signals)
	)


static func _test_zero_score_shot_failure(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	run_system.shots_left = 1
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var result: Dictionary = run_system.resolve_completed_shot(0, 2, "zero-final-shot")
	_record_case(
		cases,
		"zero-score shots failure",
		int(result.get("score_delta", -1)) == 0
			and int(result.get("shots_after", -1)) == 0
			and str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_RUN_FAILED_SHOTS
			and str(result.get("failure_reason", "")) == RogueliteRunSystem.FAILURE_REASON_SHOTS
			and signals.state_changed_count == 1
			and signals.run_failed_count == 1,
		{"score_delta": 0, "shots_after": 0, "failure_reason": "shots"},
		_result_summary(result, signals)
	)


static func _test_nonfatal_hull_damage(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	var queue_result: Dictionary = run_system.queue_shot_hull_damage()
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var result: Dictionary = run_system.resolve_completed_shot(5, 2, "nonfatal-scratch")
	_record_case(
		cases,
		"nonfatal Hull damage",
		bool(queue_result.get("accepted", false))
			and int(result.get("pending_hull_damage", 0)) == 1
			and int(result.get("hull_before", -1)) == 3
			and int(result.get("hull_after", -1)) == 2
			and str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_CONTINUE
			and not run_system.has_pending_shot_hull_damage()
			and signals.state_changed_count == 1,
		{"hull_before": 3, "hull_after": 2, "outcome": "continue"},
		_result_summary(result, signals)
	)


static func _test_fatal_hull_after_score(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	run_system.round_target = 100
	run_system.hull = 1
	run_system.queue_shot_hull_damage(1, "fatal-score")
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var result: Dictionary = run_system.resolve_completed_shot(40, 2, "fatal-score")
	_record_case(
		cases,
		"fatal Hull damage after score",
		int(result.get("score_after", -1)) == 40
			and int(result.get("hull_after", -1)) == 0
			and int(result.get("shots_after", -1)) == 2
			and str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_RUN_FAILED_HULL
			and str(result.get("failure_reason", "")) == RogueliteRunSystem.FAILURE_REASON_HULL
			and signals.run_failed_count == 1,
		{"score_after": 40, "hull_after": 0, "failure_reason": "hull"},
		_result_summary(result, signals)
	)


static func _test_fatal_hull_beats_quota(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	run_system.round_number = 6
	run_system.round_target = 215
	run_system.round_score = 150
	run_system.total_quota_score_earned = 150
	run_system.highest_single_round_score = 150
	run_system.hull = 1
	run_system.queue_shot_hull_damage(1, "fatal-over-quota")
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var result: Dictionary = run_system.resolve_completed_shot(180, 0, "fatal-over-quota")
	var terminal: Dictionary = run_system.get_terminal_summary_snapshot()
	_record_case(
		cases,
		"fatal Hull damage with quota exceeded",
		int(result.get("score_before", -1)) == 150
			and int(result.get("score_delta", -1)) == 180
			and int(result.get("score_after", -1)) == 330
			and int(terminal.get("round_score", -1)) == 330
			and int(terminal.get("round_target", -1)) == 215
			and str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_RUN_FAILED_HULL
			and signals.state_changed_count == 1
			and signals.run_failed_count == 1
			and signals.round_won_count == 0,
		{"score": "150 + 180 = 330", "outcome": "run_failed_hull"},
		_result_summary(result, signals)
	)


static func _test_empty_table(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	run_system.round_target = 100
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var result: Dictionary = run_system.resolve_completed_shot(10, 0, "empty-table")
	_record_case(
		cases,
		"empty table after score",
		int(result.get("score_after", -1)) == 10
			and int(result.get("shots_after", -1)) == 2
			and int(result.get("scoreable_ball_count", -1)) == 0
			and str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_RUN_FAILED_EMPTY_TABLE
			and str(result.get("failure_reason", "")) == RogueliteRunSystem.FAILURE_REASON_EMPTY_TABLE
			and signals.run_failed_count == 1,
		{"score_after": 10, "failure_reason": "empty_table"},
		_result_summary(result, signals)
	)


static func _test_one_prioritized_outcome_signal(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	run_system.shots_left = 1
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var result: Dictionary = run_system.resolve_completed_shot(30, 0, "one-outcome")
	_record_case(
		cases,
		"one prioritized outcome signal",
		str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_ROUND_WON
			and int(result.get("state_emit_count", 0)) == 1
			and int(result.get("terminal_signal_count", 0)) == 1
			and signals.state_changed_count == 1
			and signals.round_won_count == 1
			and signals.run_failed_count == 0,
		{"state_signals": 1, "outcome_signals": 1, "winner": "quota"},
		_result_summary(result, signals)
	)


static func _test_duplicate_transaction_rejection(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	var signals: SignalCounter = SignalCounter.new()
	signals.connect_to(run_system)
	var first: Dictionary = run_system.resolve_completed_shot(10, 2, "duplicate-key")
	var duplicate: Dictionary = run_system.resolve_completed_shot(99, 2, "duplicate-key")
	var diagnostics: Dictionary = run_system.get_shot_transaction_diagnostics()
	_record_case(
		cases,
		"duplicate transaction rejection",
		bool(first.get("accepted", false))
			and not bool(duplicate.get("accepted", true))
			and bool(duplicate.get("duplicate", false))
			and int(duplicate.get("score_after", -1)) == 10
			and int(duplicate.get("shots_after", -1)) == 2
			and int(diagnostics.get("duplicate_transaction_suppressions", 0)) == 1
			and signals.state_changed_count == 1
			and signals.round_won_count + signals.run_failed_count == 0,
		{"score_after": 10, "shots_after": 2, "duplicate_suppressions": 1},
		{
			"first": _result_summary(first, signals),
			"duplicate": duplicate,
			"diagnostics": diagnostics,
		}
	)


static func _test_atomic_payout_before_fatal_hull(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	var wallet: MockWallet = MockWallet.new()
	run_system.set_doubloon_payout_applier(Callable(wallet, "apply"))
	run_system.round_target = 100
	run_system.hull = 1
	run_system.queue_shot_hull_damage(1, "fatal-payout")
	var result: Dictionary = run_system.resolve_completed_shot(
		10,
		2,
		"fatal-payout",
		_payout(1, 7, 70)
	)
	_record_case(
		cases,
		"atomic payout precedes fatal Hull outcome",
		wallet.total == 1
			and wallet.application_count == 1
			and bool(result.get("doubloon_payout_applied", false))
			and int(result.get("doubloon_wallet_before", -1)) == 0
			and int(result.get("doubloon_wallet_after", -1)) == 1
			and bool(result.get("terminal_shot_payout", false))
			and int(result.get("hull_after", -1)) == 0
			and str(result.get("outcome", "")) == RogueliteRunSystem.OUTCOME_RUN_FAILED_HULL,
		{"wallet": 1, "payout_applied": true, "terminal_payout": true, "outcome": "run_failed_hull"},
		{"wallet": wallet.total, "applications": wallet.application_count, "transaction": result}
	)


static func _test_duplicate_transaction_suppresses_payout(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	var wallet: MockWallet = MockWallet.new()
	run_system.set_doubloon_payout_applier(Callable(wallet, "apply"))
	var payout: Dictionary = _payout(2, 8, 80)
	var first: Dictionary = run_system.resolve_completed_shot(20, 2, "payout-once", payout)
	var duplicate: Dictionary = run_system.resolve_completed_shot(20, 2, "payout-once", payout)
	var diagnostics: Dictionary = run_system.get_shot_transaction_diagnostics()
	_record_case(
		cases,
		"duplicate transaction suppresses payout",
		bool(first.get("accepted", false))
			and bool(duplicate.get("duplicate", false))
			and wallet.total == 2
			and wallet.application_count == 1
			and int(diagnostics.get("doubloon_payout_application_count", 0)) == 1
			and int(diagnostics.get("doubloon_payout_duplicate_suppressions", 0)) == 1,
		{"wallet": 2, "wallet_applications": 1, "payout_duplicate_suppressions": 1},
		{"wallet": wallet.total, "wallet_applications": wallet.application_count, "diagnostics": diagnostics}
	)


static func _test_rewind_restoration(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	run_system.queue_shot_hull_damage(1, "rewind-key")
	var queued_state: Dictionary = run_system.get_rewind_state()
	var first: Dictionary = run_system.resolve_completed_shot(7, 2, "rewind-key")
	run_system.restore_rewind_state(queued_state)
	var restored_snapshot: Dictionary = run_system.get_snapshot()
	var replay: Dictionary = run_system.resolve_completed_shot(7, 2, "rewind-key")
	_record_case(
		cases,
		"rewind restores queued damage and dedupe state",
		bool(first.get("accepted", false))
			and int(restored_snapshot.get("round_score", -1)) == 0
			and int(restored_snapshot.get("hull", -1)) == 3
			and int(restored_snapshot.get("shots_left", -1)) == 3
			and int(restored_snapshot.get("pending_shot_hull_damage", 0)) == 1
			and str(restored_snapshot.get("pending_shot_transaction_key", "")) == "rewind-key"
			and bool(replay.get("accepted", false))
			and not bool(replay.get("duplicate", true))
			and int(replay.get("score_after", -1)) == 7
			and int(replay.get("hull_after", -1)) == 2
			and int(replay.get("shots_after", -1)) == 2,
		{"restored": "score 0, Hull 3, shots 3, pending damage 1", "replay": "accepted"},
		{"restored_snapshot": restored_snapshot, "replay": replay}
	)


static func _test_rewind_replay_new_attempt(cases: Array[Dictionary]) -> void:
	var run_system: RogueliteRunSystem = _new_run()
	var pre_shot_state: Dictionary = run_system.get_rewind_state()
	run_system.queue_shot_hull_damage(1, "attempt-1")
	var first: Dictionary = run_system.resolve_completed_shot(7, 2, "attempt-1")
	run_system.restore_rewind_state(pre_shot_state)
	run_system.queue_shot_hull_damage(1, "attempt-2")
	var replay: Dictionary = run_system.resolve_completed_shot(7, 2, "attempt-2")
	_record_case(
		cases,
		"rewind replay accepts a new physical attempt key once",
		bool(first.get("accepted", false))
			and bool(replay.get("accepted", false))
			and str(first.get("transaction_key", "")) == "attempt-1"
			and str(replay.get("transaction_key", "")) == "attempt-2"
			and int(replay.get("score_after", -1)) == 7
			and int(replay.get("hull_after", -1)) == 2
			and int(replay.get("shots_after", -1)) == 2,
		{
			"first_attempt": "attempt-1",
			"replay_attempt": "attempt-2",
			"replay_score": 7,
			"replay_hull": 2,
			"replay_shots": 2,
		},
		{"first": first, "replay": replay}
	)


static func _new_run() -> RogueliteRunSystem:
	var run_system: RogueliteRunSystem = RUN_SYSTEM_SCRIPT.new() as RogueliteRunSystem
	run_system.start_run()
	return run_system


static func _payout(amount: int, shot_id: int, attempt_id: int) -> Dictionary:
	return {
		"schema_version": 1,
		"source": "haul_mult_base_haul_v1",
		"shot_id": shot_id,
		"attempt_id": attempt_id,
		"base_haul": maxi(amount, 0) * 10,
		"scoring_object_ball_count": maxi(amount, 0),
		"doubloons_awarded": maxi(amount, 0),
		"warnings": [],
	}


static func _result_summary(result: Dictionary, signals: SignalCounter) -> Dictionary:
	return {
		"accepted": result.get("accepted", false),
		"duplicate": result.get("duplicate", false),
		"transaction_key": result.get("transaction_key", ""),
		"score_before": result.get("score_before", -1),
		"score_delta": result.get("score_delta", -1),
		"score_after": result.get("score_after", -1),
		"hull_before": result.get("hull_before", -1),
		"hull_after": result.get("hull_after", -1),
		"shots_before": result.get("shots_before", -1),
		"shots_after": result.get("shots_after", -1),
		"outcome": result.get("outcome", ""),
		"failure_reason": result.get("failure_reason", ""),
		"state_signals": signals.state_changed_count,
		"round_won_signals": signals.round_won_count,
		"run_failed_signals": signals.run_failed_count,
	}


static func _record_case(
	cases: Array[Dictionary],
	case_name: String,
	passed: bool,
	expected: Variant,
	actual: Variant
) -> void:
	cases.append({
		"name": case_name,
		"passed": passed,
		"expected": expected,
		"actual": actual,
	})


static func _build_report(cases: Array[Dictionary]) -> Dictionary:
	var passed: int = 0
	var failures: Array[Dictionary] = []
	for case_result in cases:
		if bool(case_result.get("passed", false)):
			passed += 1
		else:
			failures.append(case_result.duplicate(true))
	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"total": cases.size(),
		"passed": passed,
		"failed": failures.size(),
		"failures": failures,
		"cases": cases,
	}


static func _format_report(report: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray([
		"Roguelite Run Transaction Tests: %d/%d passed" % [
			int(report.get("passed", 0)),
			int(report.get("total", 0)),
		],
	])
	var failures_value: Variant = report.get("failures", [])
	if failures_value is Array:
		for failure_value in failures_value:
			if not failure_value is Dictionary:
				continue
			var failure: Dictionary = failure_value
			lines.append("- %s" % str(failure.get("name", "Unnamed case")))
			lines.append("  expected: %s" % str(failure.get("expected", "")))
			lines.append("  actual: %s" % str(failure.get("actual", "")))
	return "\n".join(lines)
