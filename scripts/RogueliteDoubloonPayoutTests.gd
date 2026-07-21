extends SceneTree

# Standalone pure regression harness for result-derived Long Sink Doubloons.
# Run with:
# godot4 --headless --path <project> --script res://scripts/RogueliteDoubloonPayoutTests.gd

const PAYOUT_RESOLVER := preload(
	"res://scripts/RogueliteDoubloonPayoutResolver.gd"
)
const TEST_CASE_COUNT := 13
const MODE_ROGUELITE := "roguelite"
const MODE_SHOT_LAB := "shot_lab"
const MODE_PASSAGE := "passage"


class MockPayoutApplication:
	extends RefCounted
	const ROGUELITE_MODE_ID := "roguelite"
	const SHOT_LAB_MODE_ID := "shot_lab"
	const PASSAGE_MODE_ID := "passage"

	var wallet_total: int = 0
	var applied_keys: Dictionary = {}
	var last_payout_result: Dictionary = {}
	var duplicate_suppressions: int = 0
	var shot_lab_apply_enabled: bool = false


	func apply(
		payout: Dictionary,
		mode_id: String,
		terminal_outcome: String = "continue"
	) -> Dictionary:
		var application_key: String = _application_key(payout)
		var result: Dictionary = {
			"applied": false,
			"duplicate": false,
			"reason": "",
			"application_key": application_key,
			"wallet_before": wallet_total,
			"wallet_after": wallet_total,
			"terminal_outcome": terminal_outcome,
		}
		if mode_id == PASSAGE_MODE_ID:
			result["reason"] = "passage_excluded"
			return result
		if mode_id == SHOT_LAB_MODE_ID and not shot_lab_apply_enabled:
			result["reason"] = "shot_lab_wallet_mutation_suppressed"
			return result
		if mode_id != ROGUELITE_MODE_ID and mode_id != SHOT_LAB_MODE_ID:
			result["reason"] = "unsupported_mode"
			return result
		if application_key.is_empty():
			result["reason"] = "invalid_application_key"
			return result
		if applied_keys.has(application_key):
			duplicate_suppressions += 1
			result["duplicate"] = true
			result["reason"] = "duplicate_application"
			return result

		var amount: int = maxi(int(payout.get("doubloons_awarded", 0)), 0)
		applied_keys[application_key] = true
		wallet_total += amount
		last_payout_result = payout.duplicate(true)
		result["applied"] = true
		result["wallet_after"] = wallet_total
		return result


	func get_rewind_state() -> Dictionary:
		return {
			"wallet_total": wallet_total,
			"applied_keys": applied_keys.duplicate(true),
			"last_payout_result": last_payout_result.duplicate(true),
			"duplicate_suppressions": duplicate_suppressions,
		}


	func restore_rewind_state(state: Dictionary) -> void:
		wallet_total = int(state.get("wallet_total", 0))
		var keys_value: Variant = state.get("applied_keys", {})
		applied_keys = (keys_value as Dictionary).duplicate(true) if keys_value is Dictionary else {}
		var payout_value: Variant = state.get("last_payout_result", {})
		last_payout_result = (
			(payout_value as Dictionary).duplicate(true)
			if payout_value is Dictionary
			else {}
		)
		duplicate_suppressions = int(state.get("duplicate_suppressions", 0))


	func _application_key(payout: Dictionary) -> String:
		var shot_id: int = int(payout.get("shot_id", -1))
		var attempt_id: int = int(payout.get("attempt_id", -1))
		if shot_id < 0 or attempt_id < 0:
			return ""
		return "%s|shot:%d|attempt:%d" % [
			str(payout.get("source", "")),
			shot_id,
			attempt_id,
		]


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var report: Dictionary = run_all()
	print(_format_report(report))
	quit(0 if int(report.get("failed", 0)) == 0 else 1)


static func run_all() -> Dictionary:
	var cases: Array[Dictionary] = []
	_test_base_haul(cases, "Base Haul 0", 0, 0, 0)
	_test_base_haul(cases, "Base Haul 10", 10, 1, 1)
	_test_base_haul(cases, "Base Haul 20", 20, 2, 2)
	_test_base_haul(cases, "Base Haul 30", 30, 3, 3)
	_test_final_haul_ignored(cases)
	_test_mult_and_xmult_ignored(cases)
	_test_scratch_preserves_payout(cases)
	_test_duplicate_application(cases)
	_test_fatal_terminal_retains_payout(cases)
	_test_rewind_restores_wallet(cases)
	_test_replay_reapplies_once(cases)
	_test_shot_lab_suppresses_wallet(cases)
	_test_passage_excluded(cases)
	return _build_report(cases)


static func run_self_tests() -> Dictionary:
	return run_all()


static func _test_base_haul(
	cases: Array[Dictionary],
	name: String,
	base_haul: int,
	expected_ball_count: int,
	expected_doubloons: int
) -> void:
	var payout: Dictionary = PAYOUT_RESOLVER.resolve(_score_result(base_haul))
	_record_case(
		cases,
		name,
		int(payout.get("base_haul", -1)) == base_haul
			and int(payout.get("scoring_object_ball_count", -1)) == expected_ball_count
			and int(payout.get("doubloons_awarded", -1)) == expected_doubloons
			and _array_value(payout, "warnings").is_empty(),
		{
			"base_haul": base_haul,
			"scoring_object_ball_count": expected_ball_count,
			"doubloons_awarded": expected_doubloons,
		},
		_payout_summary(payout)
	)


static func _test_final_haul_ignored(cases: Array[Dictionary]) -> void:
	var score_result: Dictionary = _score_result(10)
	score_result["final_haul"] = 60
	score_result["haul_additions"] = [{"source_id": "test_add_haul", "amount": 50}]
	var payout: Dictionary = PAYOUT_RESOLVER.resolve(score_result)
	_record_case(
		cases,
		"Final Haul modifiers do not change payout",
		int(payout.get("doubloons_awarded", -1)) == 1,
		{"base_haul": 10, "final_haul": 60, "doubloons_awarded": 1},
		{"score_result_final_haul": 60, "payout": _payout_summary(payout)}
	)


static func _test_mult_and_xmult_ignored(cases: Array[Dictionary]) -> void:
	var score_result: Dictionary = _score_result(10)
	score_result["final_mult"] = 12.0
	score_result["xmult_product"] = 3.0
	score_result["shot_score"] = 120
	var payout: Dictionary = PAYOUT_RESOLVER.resolve(score_result)
	_record_case(
		cases,
		"Mult and xMult do not change payout",
		int(payout.get("doubloons_awarded", -1)) == 1,
		{"base_haul": 10, "final_mult": 12.0, "shot_score": 120, "doubloons_awarded": 1},
		{"payout": _payout_summary(payout), "ignored_shot_score": 120}
	)


static func _test_scratch_preserves_payout(cases: Array[Dictionary]) -> void:
	var score_result: Dictionary = _score_result(10)
	score_result["scratch_occurred"] = true
	var payout: Dictionary = PAYOUT_RESOLVER.resolve(score_result)
	_record_case(
		cases,
		"Scratch does not erase payout",
		int(payout.get("doubloons_awarded", -1)) == 1,
		{"base_haul": 10, "scratch": true, "doubloons_awarded": 1},
		_payout_summary(payout)
	)


static func _test_duplicate_application(cases: Array[Dictionary]) -> void:
	var application: MockPayoutApplication = MockPayoutApplication.new()
	var payout: Dictionary = PAYOUT_RESOLVER.resolve(_score_result(20))
	var first: Dictionary = application.apply(payout, MODE_ROGUELITE)
	var duplicate: Dictionary = application.apply(payout, MODE_ROGUELITE)
	_record_case(
		cases,
		"Duplicate application rejected",
		bool(first.get("applied", false))
			and not bool(duplicate.get("applied", true))
			and bool(duplicate.get("duplicate", false))
			and application.wallet_total == 2
			and application.duplicate_suppressions == 1,
		{"wallet_total": 2, "duplicate": true, "duplicate_suppressions": 1},
		{"first": first, "duplicate": duplicate, "wallet_total": application.wallet_total}
	)


static func _test_fatal_terminal_retains_payout(cases: Array[Dictionary]) -> void:
	var application: MockPayoutApplication = MockPayoutApplication.new()
	var payout: Dictionary = PAYOUT_RESOLVER.resolve(_score_result(10))
	var result: Dictionary = application.apply(payout, MODE_ROGUELITE, "run_failed_hull")
	_record_case(
		cases,
		"Fatal terminal shot retains payout",
		bool(result.get("applied", false))
			and str(result.get("terminal_outcome", "")) == "run_failed_hull"
			and application.wallet_total == 1,
		{"wallet_total": 1, "terminal_outcome": "run_failed_hull"},
		{"application": result, "wallet_total": application.wallet_total}
	)


static func _test_rewind_restores_wallet(cases: Array[Dictionary]) -> void:
	var application: MockPayoutApplication = MockPayoutApplication.new()
	application.wallet_total = 7
	var before_shot: Dictionary = application.get_rewind_state()
	application.apply(PAYOUT_RESOLVER.resolve(_score_result(20)), MODE_ROGUELITE)
	application.restore_rewind_state(before_shot)
	_record_case(
		cases,
		"Rewind restores wallet",
		application.wallet_total == 7
			and application.applied_keys.is_empty()
			and application.last_payout_result.is_empty(),
		{"wallet_total": 7, "applied_key_count": 0, "last_payout_empty": true},
		{
			"wallet_total": application.wallet_total,
			"applied_key_count": application.applied_keys.size(),
			"last_payout_empty": application.last_payout_result.is_empty(),
		}
	)


static func _test_replay_reapplies_once(cases: Array[Dictionary]) -> void:
	var application: MockPayoutApplication = MockPayoutApplication.new()
	var before_shot: Dictionary = application.get_rewind_state()
	var first_payout: Dictionary = PAYOUT_RESOLVER.resolve(_score_result(10, 4, 100))
	application.apply(first_payout, MODE_ROGUELITE)
	application.restore_rewind_state(before_shot)
	var replay_payout: Dictionary = PAYOUT_RESOLVER.resolve(_score_result(10, 4, 101))
	var replay: Dictionary = application.apply(replay_payout, MODE_ROGUELITE)
	var duplicate: Dictionary = application.apply(replay_payout, MODE_ROGUELITE)
	_record_case(
		cases,
		"Replay reapplies exactly once",
		bool(replay.get("applied", false))
			and bool(duplicate.get("duplicate", false))
			and application.wallet_total == 1
			and application.applied_keys.size() == 1,
		{"wallet_total": 1, "replay_attempt_id": 101, "applied_key_count": 1},
		{
			"wallet_total": application.wallet_total,
			"replay": replay,
			"duplicate": duplicate,
			"applied_keys": application.applied_keys.keys(),
		}
	)


static func _test_shot_lab_suppresses_wallet(cases: Array[Dictionary]) -> void:
	var application: MockPayoutApplication = MockPayoutApplication.new()
	var payout: Dictionary = PAYOUT_RESOLVER.resolve(_score_result(20))
	var result: Dictionary = application.apply(payout, MODE_SHOT_LAB)
	_record_case(
		cases,
		"Shot Lab suppresses wallet mutation",
		int(payout.get("doubloons_awarded", -1)) == 2
			and not bool(result.get("applied", true))
			and str(result.get("reason", "")) == "shot_lab_wallet_mutation_suppressed"
			and application.wallet_total == 0,
		{"expected_doubloons": 2, "wallet_total": 0, "applied": false},
		{"payout": _payout_summary(payout), "application": result}
	)


static func _test_passage_excluded(cases: Array[Dictionary]) -> void:
	var application: MockPayoutApplication = MockPayoutApplication.new()
	var payout: Dictionary = PAYOUT_RESOLVER.resolve(_score_result(20))
	var result: Dictionary = application.apply(payout, MODE_PASSAGE)
	_record_case(
		cases,
		"Passage excluded",
		not bool(result.get("applied", true))
			and str(result.get("reason", "")) == "passage_excluded"
			and application.wallet_total == 0,
		{"wallet_total": 0, "applied": false, "reason": "passage_excluded"},
		{"application": result, "wallet_total": application.wallet_total}
	)


static func _score_result(base_haul: int, shot_id: int = 4, attempt_id: int = 100) -> Dictionary:
	return {
		"schema_version": 1,
		"scoring_model": "haul_mult_v1",
		"source": "authoritative",
		"shot_id": shot_id,
		"attempt_id": attempt_id,
		"base_haul": base_haul,
		"final_haul": base_haul,
		"final_mult": 1.0,
		"shot_score": base_haul,
	}


static func _record_case(
	cases: Array[Dictionary],
	name: String,
	passed: bool,
	expected: Dictionary,
	actual: Dictionary
) -> void:
	cases.append({
		"name": name,
		"passed": passed,
		"expected": expected.duplicate(true),
		"actual": actual.duplicate(true),
	})


static func _build_report(cases: Array[Dictionary]) -> Dictionary:
	var passed_count: int = 0
	var failures: Array[Dictionary] = []
	for case_result in cases:
		if bool(case_result.get("passed", false)):
			passed_count += 1
		else:
			failures.append(case_result.duplicate(true))
	return {
		"status": (
			"PASS"
			if failures.is_empty() and cases.size() == TEST_CASE_COUNT
			else "FAIL"
		),
		"timestamp": Time.get_datetime_string_from_system(),
		"total": cases.size(),
		"passed": passed_count,
		"failed": failures.size(),
		"cases": cases.duplicate(true),
		"failures": failures,
	}


static func _payout_summary(payout: Dictionary) -> Dictionary:
	return {
		"schema_version": payout.get("schema_version", null),
		"source": payout.get("source", null),
		"shot_id": payout.get("shot_id", null),
		"attempt_id": payout.get("attempt_id", null),
		"base_haul": payout.get("base_haul", null),
		"scoring_object_ball_count": payout.get("scoring_object_ball_count", null),
		"doubloons_awarded": payout.get("doubloons_awarded", null),
		"warnings": _array_value(payout, "warnings"),
	}


static func _array_value(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return (value as Array).duplicate(true) if value is Array else []


static func _format_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(
		"Roguelite Doubloon Payout Tests: %d/%d passed, %d failed"
		% [
			int(report.get("passed", 0)),
			int(report.get("total", 0)),
			int(report.get("failed", 0)),
		]
	)
	for case_value in _array_value(report, "cases"):
		if not case_value is Dictionary:
			continue
		var case_result: Dictionary = case_value
		lines.append(
			"[%s] %s"
			% [
				"PASS" if bool(case_result.get("passed", false)) else "FAIL",
				str(case_result.get("name", "Unnamed")),
			]
		)
		if not bool(case_result.get("passed", false)):
			lines.append("  Expected: %s" % var_to_str(case_result.get("expected")))
			lines.append("  Actual:   %s" % var_to_str(case_result.get("actual")))
	return "\n".join(lines)
