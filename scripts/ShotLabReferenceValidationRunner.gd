extends SceneTree

# Command-line validation adapter for the same ShotLabSystem used by the game.
# It does not implement a second simulator or assertion path.

const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")
const SHOT_LEDGER_ANALYZER := preload("res://scripts/ShotLedgerAnalyzer.gd")
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const RESULT_MARKER := "SHOT_LAB_REFERENCE_VALIDATION="
const PREFLIGHT_MARKER := "SHOT_LAB_REFERENCE_PREFLIGHT="
const SELF_TEST_MARKER := "SHOT_LEDGER_SELF_TEST="
const SCORING_SELF_TEST_MARKER := "ROGUELITE_SCORING_SELF_TEST="
const SCORING_PREFLIGHT_MARKER := "ROGUELITE_SCORING_PREFLIGHT="
const SCORING_SUITE_MARKER := "ROGUELITE_SCORING_SUITE="
const SCORING_REWIND_MARKER := "ROGUELITE_SCORING_REWIND="
const OUTPUT_PATH := "user://shot_lab_reference_validation.json"
const TIMEOUT_SECONDS := 900.0

var main_instance: Node
var shot_lab_system: ShotLabSystem
var preflight_only := false
var repeatability := false
var rewind_check := false
var self_test_result: Dictionary = {}
var scoring_self_test_result: Dictionary = {}
var scoring_system: Node
var rewind_stage := ""
var scoring_signal_count := 0
var first_score_result: Dictionary = {}
var first_shot_lab_result: Dictionary = {}
var rewind_failures: Array[String] = []


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	preflight_only = "--preflight-only" in arguments
	repeatability = "--repeatability" in arguments
	rewind_check = "--rewind-check" in arguments
	GAME_MODE_SCRIPT.set_pending_mode(self, GAME_MODE_SCRIPT.MODE_SHOT_LAB)
	GAME_MODE_SCRIPT.set_pending_shot_lab_session(self, {
		"auto_load": true,
		"run_suite": false,
	})
	main_instance = MAIN_SCENE.instantiate()
	root.add_child(main_instance)
	call_deferred("_start_validation")


func _start_validation() -> void:
	shot_lab_system = main_instance.get_node_or_null("Table/ShotLabSystem") as ShotLabSystem
	if shot_lab_system == null:
		_finish_with_error("ShotLabSystem was not instantiated by Main.tscn.")
		return
	self_test_result = SHOT_LEDGER_ANALYZER.run_self_tests()
	print(SELF_TEST_MARKER + JSON.stringify(_to_json_safe(self_test_result)))
	scoring_self_test_result = main_instance.get_node("Table/RogueliteScoringSystem").run_self_tests()
	print(SCORING_SELF_TEST_MARKER + JSON.stringify(_to_json_safe(scoring_self_test_result)))
	if rewind_check:
		_run_scoring_rewind_check()
		return
	if preflight_only:
		_run_preflight_catalog()
		return
	if not shot_lab_system.reference_suite_completed.is_connected(_on_suite_completed):
		shot_lab_system.reference_suite_completed.connect(_on_suite_completed)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = TIMEOUT_SECONDS
	timer.timeout.connect(_on_timeout)
	root.add_child(timer)
	timer.start()
	var started: bool = (
		shot_lab_system.run_reference_repeatability_suite()
		if repeatability
		else shot_lab_system.run_reference_suite()
	)
	if not started:
		_finish_with_error("The Shot Lab reference suite did not start.")


func _run_scoring_rewind_check() -> void:
	scoring_system = main_instance.get_node_or_null("Table/RogueliteScoringSystem")
	if scoring_system == null:
		_finish_with_error("RogueliteScoringSystem was not instantiated for the rewind check.")
		return
	shot_lab_system.set_selected_preset_id("direct_pot")
	if not shot_lab_system.load_selected_setup(false):
		_finish_with_error("Direct Pot setup could not be loaded for the rewind check.")
		return

	var previous_score: Dictionary = {
		"schema_version": 1,
		"scoring_model": "haul_mult_v1",
		"source": "rewind_validation_sentinel",
		"mode_id": GAME_MODE_SCRIPT.MODE_SHOT_LAB,
		"shot_id": 700,
		"attempt_id": 700,
		"final_haul": 70,
		"final_mult": 7.0,
		"shot_score": 490,
		"warnings": [],
	}
	var shot_lab_snapshot: Dictionary = shot_lab_system.get_snapshot()
	scoring_system.restore_rewind_state({
		"last_score_result": previous_score,
		"last_resolution_key": "rewind_validation_sentinel",
		"last_warning": "",
		"last_clear_reason": "rewind_validation_sentinel",
	})
	shot_lab_system.restore_rewind_state({
		"last_result": {
			"status": "PREVIOUS",
			"rewind_validation_sentinel": true,
			"scoring": {"authoritative": previous_score},
		},
		"last_reference_fired": false,
		"active_reference_attempt": {},
		"reference_preflight": _dictionary_value(shot_lab_snapshot, "reference_preflight"),
	})

	var score_callable := Callable(self, "_on_rewind_score_resolved")
	if not scoring_system.is_connected("roguelite_shot_score_resolved", score_callable):
		scoring_system.connect("roguelite_shot_score_resolved", score_callable)
	if not shot_lab_system.result_completed.is_connected(_on_rewind_shot_lab_result):
		shot_lab_system.result_completed.connect(_on_rewind_shot_lab_result)
	var rewind_system: Node = main_instance.get_node("Table/ShotRewindSystem")
	var rewind_callable := Callable(self, "_on_rewind_restored")
	if not rewind_system.is_connected("rewind_completed", rewind_callable):
		rewind_system.connect("rewind_completed", rewind_callable)

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 60.0
	timer.timeout.connect(_on_timeout)
	root.add_child(timer)
	timer.start()
	rewind_stage = "first_shot"
	if not shot_lab_system.fire_reference_shot():
		_finish_with_error("Direct Pot reference could not be fired for the rewind check.")


func _on_rewind_score_resolved(_score_result: Dictionary) -> void:
	scoring_signal_count += 1


func _on_rewind_shot_lab_result(result: Dictionary) -> void:
	if rewind_stage == "first_shot":
		first_shot_lab_result = result.duplicate(true)
		first_score_result = _dictionary_value(_dictionary_value(result, "scoring"), "authoritative")
		if int(first_score_result.get("shot_score", -1)) != 10:
			rewind_failures.append("First Direct Pot score was not 10.")
		rewind_stage = "rewind_requested"
		call_deferred("_request_scoring_rewind")
		return
	if rewind_stage != "replay":
		return

	var replay_score: Dictionary = _dictionary_value(_dictionary_value(result, "scoring"), "authoritative")
	if int(replay_score.get("shot_score", -1)) != 10:
		rewind_failures.append("Replayed Direct Pot score was not 10.")
	if int(replay_score.get("attempt_id", -1)) <= int(first_score_result.get("attempt_id", -1)):
		rewind_failures.append("Replay did not receive a fresh monotonic attempt_id.")
	if int(replay_score.get("shot_id", -1)) != int(first_score_result.get("shot_id", -2)):
		rewind_failures.append("Replay did not reuse the rewindable shot_id.")
	if scoring_signal_count != 2:
		rewind_failures.append("Expected exactly two score-resolution signals after replay, received %d." % scoring_signal_count)
	var diagnostics: Dictionary = scoring_system.get_diagnostics_snapshot()
	if int(diagnostics.get("duplicate_resolution_suppression_count", 0)) != 0:
		rewind_failures.append("Rewind/replay unexpectedly hit duplicate resolution suppression.")
	_finish_scoring_rewind_check(replay_score, diagnostics)


func _request_scoring_rewind() -> void:
	var signal_count_before_rewind: int = scoring_signal_count
	if not shot_lab_system.reset_last_shot():
		rewind_failures.append("Reset Last Shot rejected the completed Direct Pot checkpoint.")
		_finish_scoring_rewind_check({}, scoring_system.get_diagnostics_snapshot())
		return
	if scoring_signal_count != signal_count_before_rewind:
		rewind_failures.append("Reset Last Shot emitted a duplicate score-resolution signal.")


func _on_rewind_restored() -> void:
	if rewind_stage != "rewind_requested":
		return
	var restored_score: Dictionary = scoring_system.get_last_score_result()
	if int(restored_score.get("shot_score", -1)) != 490:
		rewind_failures.append("Reset Last Shot did not restore the previous score observation.")
	var restored_lab_result: Dictionary = _dictionary_value(shot_lab_system.get_snapshot(), "last_result")
	if not bool(restored_lab_result.get("rewind_validation_sentinel", false)):
		rewind_failures.append("Reset Last Shot did not restore the previous Shot Lab comparison observation.")
	if scoring_signal_count != 1:
		rewind_failures.append("Reset Last Shot changed the score-resolution signal count.")
	rewind_stage = "replay"
	call_deferred("_fire_scoring_replay")


func _fire_scoring_replay() -> void:
	if not shot_lab_system.fire_reference_shot():
		rewind_failures.append("Reference replay could not be committed after Reset Last Shot.")
		_finish_scoring_rewind_check({}, scoring_system.get_diagnostics_snapshot())


func _finish_scoring_rewind_check(replay_score: Dictionary, diagnostics: Dictionary) -> void:
	var result: Dictionary = {
		"status": "PASS" if rewind_failures.is_empty() else "FAIL",
		"passed": rewind_failures.is_empty(),
		"failures": rewind_failures.duplicate(),
		"first_shot_id": int(first_score_result.get("shot_id", -1)),
		"first_attempt_id": int(first_score_result.get("attempt_id", -1)),
		"replay_shot_id": int(replay_score.get("shot_id", -1)),
		"replay_attempt_id": int(replay_score.get("attempt_id", -1)),
		"score_resolution_signal_count": scoring_signal_count,
		"duplicate_resolution_suppression_count": int(diagnostics.get("duplicate_resolution_suppression_count", 0)),
	}
	_persist_result("rewind", result)
	print(SCORING_REWIND_MARKER + JSON.stringify(_to_json_safe(result)))
	quit(0 if rewind_failures.is_empty() else 2)


func _run_preflight_catalog() -> void:
	var catalog_results: Array[Dictionary] = []
	var scoring_results: Array[Dictionary] = []
	for choice_value in shot_lab_system.get_preset_choices():
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		var preset_id: String = str(choice.get("value", ""))
		shot_lab_system.set_selected_preset_id(preset_id)
		var loaded: bool = shot_lab_system.load_selected_setup(false)
		var snapshot: Dictionary = shot_lab_system.get_snapshot()
		catalog_results.append({
			"preset_id": preset_id,
			"display_name": str(choice.get("label", preset_id)),
			"loaded": loaded,
			"resolved_reference": _dictionary_value(snapshot, "resolved_reference"),
			"preflight": _dictionary_value(snapshot, "reference_preflight"),
			"fire_blocker": str(snapshot.get("reference_fire_blocker", "")),
		})
		var preflight: Dictionary = _dictionary_value(snapshot, "reference_preflight")
		var predicted_score: Dictionary = _dictionary_value(preflight, "predicted_score_result")
		var score_assertions: Dictionary = _dictionary_value(preflight, "predicted_score_assertions")
		scoring_results.append({
			"preset_id": preset_id,
			"preflight_status": str(preflight.get("status", "NOT RUN")),
			"haul": int(predicted_score.get("final_haul", 0)),
			"mult": float(predicted_score.get("final_mult", 1.0)),
			"score": int(predicted_score.get("shot_score", 0)),
			"source_counts": _dictionary_value(
				_dictionary_value(predicted_score, "diagnostics"),
				"source_counts"
			),
			"mult_additions": predicted_score.get("mult_additions", []),
			"score_assertions_passed": bool(score_assertions.get("passed", false)),
			"score_failures": _array_value(score_assertions, "failures").duplicate(true),
		})
	var result: Dictionary = {
		"preset_count": catalog_results.size(),
		"results": catalog_results,
	}
	_persist_result("preflight", result)
	print(SCORING_PREFLIGHT_MARKER + JSON.stringify(_to_json_safe(scoring_results)))
	print(PREFLIGHT_MARKER + JSON.stringify(_to_json_safe(result)))
	quit(0)


func _on_suite_completed(result: Dictionary) -> void:
	_persist_result("repeatability" if repeatability else "authoritative", result)
	print(SCORING_SUITE_MARKER + JSON.stringify(_to_json_safe(_make_compact_scoring_summary(result))))
	print(RESULT_MARKER + JSON.stringify(_to_json_safe(result)))
	quit(0 if int(result.get("failed", 0)) == 0 else 2)


func _on_timeout() -> void:
	_finish_with_error("Reference suite exceeded %.0f seconds." % TIMEOUT_SECONDS)


func _finish_with_error(message: String) -> void:
	push_error(message)
	var result: Dictionary = {"error": message}
	_persist_result("error", result)
	print(RESULT_MARKER + JSON.stringify(result))
	quit(1)


func _persist_result(validation_kind: String, result: Dictionary) -> void:
	var output: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not write Shot Lab validation result to %s." % OUTPUT_PATH)
		return
	output.store_string(JSON.stringify(_to_json_safe({
		"validation_kind": validation_kind,
		"shot_ledger_self_test": self_test_result,
		"roguelite_scoring_self_test": scoring_self_test_result,
		"result": result,
	}), "\t"))


func _make_compact_scoring_summary(result: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for suite_result_value in _array_value(result, "results"):
		if not suite_result_value is Dictionary:
			continue
		var suite_result: Dictionary = suite_result_value
		var scoring: Dictionary = _dictionary_value(suite_result, "scoring")
		var actual: Dictionary = _dictionary_value(scoring, "authoritative")
		var predicted: Dictionary = _dictionary_value(scoring, "predicted")
		var parity: Dictionary = _dictionary_value(scoring, "parity")
		var assertions: Dictionary = _dictionary_value(scoring, "assertions")
		rows.append({
			"preset_id": str(suite_result.get("preset_id", "")),
			"passed": bool(suite_result.get("passed", false)),
			"predicted_score": int(predicted.get("shot_score", 0)),
			"actual_haul": int(actual.get("final_haul", 0)),
			"actual_mult": float(actual.get("final_mult", 1.0)),
			"actual_score": int(actual.get("shot_score", 0)),
			"parity": str(parity.get("status", "NOT RUN")),
			"score_assertions_passed": bool(assertions.get("passed", false)),
			"score_failures": _array_value(assertions, "failures").duplicate(true),
		})
	return rows


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []


func _to_json_safe(value: Variant) -> Variant:
	if value is Vector2:
		return {"x": value.x, "y": value.y}
	if value is Dictionary:
		var converted: Dictionary = {}
		for key_value in (value as Dictionary).keys():
			converted[str(key_value)] = _to_json_safe((value as Dictionary)[key_value])
		return converted
	if value is Array:
		var converted_array: Array = []
		for item in value as Array:
			converted_array.append(_to_json_safe(item))
		return converted_array
	return value
