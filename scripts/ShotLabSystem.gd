extends Node2D
class_name ShotLabSystem

signal state_changed(snapshot: Dictionary)
signal status_changed(message: String)
signal result_completed(result: Dictionary)
signal reference_suite_completed(result: Dictionary)

const PRESET_CATALOG := preload("res://scripts/ShotLabPresetCatalog.gd")
const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")
const EIGHT_BALL_CATALOG := preload("res://scripts/RogueliteEightBallCatalog.gd")
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const DEFAULT_OPTIONS := {
	"auto_fire_after_load": false,
	"auto_reset_after_failure": false,
	"show_expected_ledger": true,
	"show_reference_aim": true,
	"freeze_unrelated_run_consequences": true,
	"ordinary_balls_only": true,
}
const BALL_RADIUS := 14.0
const START_CLEARANCE := 0.5
const REFERENCE_LINE_LENGTH := 250.0
const REFERENCE_AIM_NUDGE_WORLD := 2.0
const REFERENCE_POWER_NUDGE := 0.01
const REPEATABILITY_ATTEMPTS := 5
const REFERENCE_LAUNCH_SPEED_EPSILON := 0.001
const REFERENCE_LAUNCH_DIRECTION_DOT_MIN := 0.999999
const REFERENCE_COMMIT_ORIGIN_TOLERANCE_PX := 0.01
const REFERENCE_COMMIT_VELOCITY_TOLERANCE := 0.01
const REFERENCE_COMMIT_POWER_TOLERANCE := 0.000001

const AIM_ROLE_CENTER := "role_center"
const AIM_ROLE_OFFSET := "role_offset"
const AIM_NORMALIZED_PLAYFIELD_POINT := "normalized_playfield_point"
const AIM_POCKET_CENTER := "pocket_center"
const AIM_WORLD_DIRECTION := "world_direction"

const PREFLIGHT_PASS := "PASS"
const PREFLIGHT_WARN := "WARN"
const PREFLIGHT_FAIL := "FAIL"
const PREFLIGHT_NOT_RUN := "NOT RUN"

const SCORING_MODIFIER_NONE := "none"
const SCORING_MODIFIER_ADD_HAUL := "add_haul_20"
const SCORING_MODIFIER_ADD_MULT := "add_mult_3"
const SCORING_MODIFIER_XMULT_1_5 := "xmult_1_5"
const SCORING_MODIFIER_XMULT_2 := "xmult_2"
const SCORING_MODIFIER_ALL := "all"
const SCORING_MODIFIER_CHOICES := [
	{"label": "None", "value": SCORING_MODIFIER_NONE},
	{"label": "+20 Haul", "value": SCORING_MODIFIER_ADD_HAUL},
	{"label": "+3 Mult", "value": SCORING_MODIFIER_ADD_MULT},
	{"label": "x1.5 Mult", "value": SCORING_MODIFIER_XMULT_1_5},
	{"label": "x2 Mult", "value": SCORING_MODIFIER_XMULT_2},
	{"label": "All Test Modifiers", "value": SCORING_MODIFIER_ALL},
]

const EIGHT_BALL_LOADOUT_PRESETS := {
	"single_bank_trio": [
		"single_bank_haul_crooked_coin",
		"single_bank_mult_first_toll",
		"single_bank_xmult_rogue_current",
	],
	"double_bank_trio": [
		"double_bank_haul_twin_tribute",
		"double_bank_mult_second_bell",
		"double_bank_xmult_crossed_tides",
	],
	"triple_bank_trio": [
		"triple_bank_haul_threefold_plunder",
		"triple_bank_mult_third_toll",
		"triple_bank_xmult_krakens_trine",
	],
	"combination_trio": [
		"combination_haul_shared_spoils",
		"combination_mult_chain_of_command",
		"combination_xmult_conspirators_cut",
	],
	"bank_combo_hybrid": [
		"single_bank_haul_crooked_coin",
		"double_bank_mult_second_bell",
		"double_bank_xmult_crossed_tides",
		"combination_haul_shared_spoils",
		"combination_xmult_conspirators_cut",
	],
	"direct_pot_trio": [
		"direct_pot_haul_clean_plunder",
		"direct_pot_mult_true_bearing",
		"direct_pot_xmult_unerring_course",
	],
	"direct_pot_trio_dead_reckoning": [
		"direct_pot_haul_clean_plunder",
		"direct_pot_mult_true_bearing",
		"direct_pot_xmult_unerring_course",
		"direct_pot_legendary_dead_reckoning",
	],
	"multi_pot_trio": [
		"multi_pot_haul_loaded_hold",
		"multi_pot_mult_all_hands",
		"multi_pot_xmult_broadside_dividend",
	],
	"same_pocket_trio": [
		"same_pocket_haul_shared_grave",
		"same_pocket_mult_feeding_frenzy",
		"same_pocket_xmult_the_maw_below",
	],
	"direct_multi_hybrid": [
		"direct_pot_haul_clean_plunder",
		"direct_pot_mult_true_bearing",
		"multi_pot_haul_loaded_hold",
		"multi_pot_mult_all_hands",
		"multi_pot_xmult_broadside_dividend",
	],
	"multi_same_pocket_hybrid": [
		"multi_pot_haul_loaded_hold",
		"multi_pot_mult_all_hands",
		"same_pocket_haul_shared_grave",
		"same_pocket_mult_feeding_frenzy",
		"same_pocket_xmult_the_maw_below",
	],
}

var table: BilliardsTable
var presets: Array[Dictionary] = []
var selected_preset_id := "direct_pot"
var loaded_preset: Dictionary = {}
var role_to_ball_id: Dictionary = {}
var options: Dictionary = DEFAULT_OPTIONS.duplicate(true)
var active := false
var dedicated_session := false
var panel_open := false
var last_result: Dictionary = {}
var last_reference_fired := false
var last_load_error := ""
var setup_generation := 0
var resolved_reference: Dictionary = {}
var reference_preflight: Dictionary = {}
var reference_prediction_commit_bundle: Dictionary = {}
var reference_preflight_generation := 0
var active_reference_attempt: Dictionary = {}
var suite_running := false
var suite_cancel_requested := false
var suite_index := 0
var suite_passed := 0
var suite_failed := 0
var suite_failures: Array[String] = []
var suite_results: Array[Dictionary] = []
var suite_generation := 0
var suite_completed := false
var suite_repeat_target := 1
var suite_repeat_index := 0
var suite_completed_attempts := 0
var suite_resolved_count := 0
var suite_preflight_counts := {PREFLIGHT_PASS: 0, PREFLIGHT_WARN: 0, PREFLIGHT_FAIL: 0}
var suite_first_contact_mismatches := 0
var cue_restore_pending := false
var last_scratched_cue_ball_id := -1
var shot_lab_cue_scratches := 0
var shot_lab_cue_restorations := 0
var cue_restoration_failures := 0
var last_cue_restoration_error := ""
var scoring_test_modifier_mode := SCORING_MODIFIER_NONE


func setup(table_ref: BilliardsTable) -> void:
	table = table_ref
	presets = PRESET_CATALOG.get_presets()
	if not presets.is_empty():
		selected_preset_id = str(presets[0].get("preset_id", selected_preset_id))
	if not table.shot_ledger_system.shot_ledger_completed.is_connected(_on_shot_ledger_completed):
		table.shot_ledger_system.shot_ledger_completed.connect(_on_shot_ledger_completed)
	if not table.shot_rewind_system.rewind_completed.is_connected(_on_shot_rewind_completed):
		table.shot_rewind_system.rewind_completed.connect(_on_shot_rewind_completed)
	if (
		table.roguelite_build_system != null
		and not table.roguelite_build_system.diagnostics_changed.is_connected(
			_on_eight_ball_build_changed
		)
	):
		table.roguelite_build_system.diagnostics_changed.connect(
			_on_eight_ball_build_changed
		)
	_sync_scoring_modifier_context()
	set_process(false)
	_emit_state()


func _exit_tree() -> void:
	cancel_reference_suite("scene_teardown")


func enter_dedicated_session(configuration: Dictionary = {}) -> bool:
	dedicated_session = true
	options = DEFAULT_OPTIONS.duplicate(true)
	options["freeze_unrelated_run_consequences"] = true
	options["auto_fire_after_load"] = false
	last_result.clear()
	last_reference_fired = false
	last_load_error = ""
	setup_generation = 0
	resolved_reference.clear()
	reference_preflight.clear()
	reference_prediction_commit_bundle.clear()
	reference_preflight_generation = 0
	active_reference_attempt.clear()
	suite_running = false
	suite_cancel_requested = false
	suite_index = 0
	suite_passed = 0
	suite_failed = 0
	suite_failures.clear()
	suite_results.clear()
	suite_completed = false
	_reset_suite_reference_metrics(1)
	cue_restore_pending = false
	last_scratched_cue_ball_id = -1
	shot_lab_cue_scratches = 0
	shot_lab_cue_restorations = 0
	cue_restoration_failures = 0
	last_cue_restoration_error = ""
	scoring_test_modifier_mode = SCORING_MODIFIER_NONE
	if table != null and table.roguelite_build_system != null:
		table.roguelite_build_system.clear_shot_lab_loadout("shot_lab_session_start")
	_sync_scoring_modifier_context()
	var requested_preset_id: String = str(configuration.get("selected_preset_id", selected_preset_id))
	if not PRESET_CATALOG.get_preset(requested_preset_id).is_empty():
		selected_preset_id = requested_preset_id
	var should_auto_load: bool = bool(configuration.get("auto_load", true))
	var loaded: bool = load_selected_setup(false) if should_auto_load else true
	if loaded and bool(configuration.get("run_suite", false)):
		call_deferred("run_reference_suite")
	_emit_state()
	return loaded


func get_preset_choices() -> Array:
	var choices: Array = []
	for preset in presets:
		choices.append({
			"label": str(preset.get("display_name", preset.get("preset_id", "Preset"))),
			"value": str(preset.get("preset_id", "")),
			"description": str(preset.get("description", "")),
		})
	return choices


func set_selected_preset_id(preset_id: String) -> void:
	if _is_authoritative_shot_active() or suite_running:
		status_changed.emit("Shot Lab: wait for the active test before changing presets.")
		return
	if PRESET_CATALOG.get_preset(preset_id).is_empty():
		return
	selected_preset_id = preset_id
	_emit_state()


func get_selected_preset_id() -> String:
	return selected_preset_id


func set_panel_open(enabled: bool) -> void:
	panel_open = enabled
	_emit_state()


func set_option(option_id: String, value: bool) -> void:
	if not options.has(option_id):
		return
	options[option_id] = value
	queue_redraw()
	_emit_state()


func get_option(option_id: String) -> bool:
	return bool(options.get(option_id, false))


func is_active() -> bool:
	return active


func is_dedicated_session() -> bool:
	return dedicated_session


func is_consequence_freeze_enabled() -> bool:
	return active and bool(options.get("freeze_unrelated_run_consequences", true))


func get_active_preset_id() -> String:
	return str(loaded_preset.get("preset_id", "")) if active else ""


func get_scoring_modifier_choices() -> Array:
	return SCORING_MODIFIER_CHOICES.duplicate(true)


func get_eight_ball_loadout_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = [{
		"label": "Empty",
		"value": "",
		"description": "Leave this tray slot empty.",
	}]
	for definition in EIGHT_BALL_CATALOG.get_all_definitions():
		choices.append({
			"label": str(definition.get("display_name", "Eight Ball")),
			"value": str(definition.get("eight_ball_item_id", "")),
			"description": str(definition.get("short_effect", "")),
		})
	return choices


func get_eight_ball_loadout_snapshot() -> Dictionary:
	if table == null or table.roguelite_build_system == null:
		return {}
	return table.roguelite_build_system.get_shot_lab_loadout_snapshot()


func set_eight_ball_loadout_slot(tray_slot_index: int, eight_ball_item_id: String) -> Dictionary:
	if _is_authoritative_shot_active() or suite_running:
		status_changed.emit("Shot Lab: Eight Ball loadout is locked while a test is active.")
		return {"success": false, "reason": "shot_lab_busy"}
	var build_system: RogueliteBuildSystem = _get_eight_ball_build_system()
	if build_system == null:
		status_changed.emit("Shot Lab: Eight Ball build system unavailable.")
		return {"success": false, "reason": "build_system_unavailable"}
	if tray_slot_index < 0 or tray_slot_index >= RogueliteBuildSystem.TRAY_CAPACITY:
		return {"success": false, "reason": "invalid_tray_slot"}
	var item_ids: Array[String] = _get_shot_lab_loadout_ids(build_system)
	item_ids[tray_slot_index] = eight_ball_item_id.strip_edges()
	var result: Dictionary = build_system.set_shot_lab_loadout(item_ids)
	if not bool(result.get("success", false)):
		status_changed.emit("Shot Lab loadout rejected: %s." % str(result.get("reason", "invalid loadout")))
		return result
	_refresh_reference_for_build_change("eight_ball_loadout_slot_changed")
	status_changed.emit("Shot Lab Eight Ball slot %d updated." % (tray_slot_index + 1))
	_emit_state()
	return result


func clear_eight_ball_loadout() -> void:
	if _is_authoritative_shot_active() or suite_running:
		status_changed.emit("Shot Lab: Eight Ball loadout is locked while a test is active.")
		return
	var build_system: RogueliteBuildSystem = _get_eight_ball_build_system()
	if build_system == null:
		return
	build_system.clear_shot_lab_loadout("shot_lab_manual_clear")
	_refresh_reference_for_build_change("eight_ball_loadout_cleared")
	status_changed.emit("Shot Lab Eight Ball loadout cleared.")
	_emit_state()


func load_eight_ball_loadout_preset(preset_id: String) -> Dictionary:
	if _is_authoritative_shot_active() or suite_running:
		status_changed.emit("Shot Lab: Eight Ball loadout is locked while a test is active.")
		return {"success": false, "reason": "shot_lab_busy"}
	var preset_value: Variant = EIGHT_BALL_LOADOUT_PRESETS.get(preset_id, [])
	if not preset_value is Array:
		return {"success": false, "reason": "unknown_loadout_preset"}
	var build_system: RogueliteBuildSystem = _get_eight_ball_build_system()
	if build_system == null:
		return {"success": false, "reason": "build_system_unavailable"}
	var result: Dictionary = build_system.set_shot_lab_loadout((preset_value as Array).duplicate())
	if not bool(result.get("success", false)):
		status_changed.emit("Shot Lab loadout rejected: %s." % str(result.get("reason", "invalid loadout")))
		return result
	_refresh_reference_for_build_change("eight_ball_loadout_preset_changed")
	status_changed.emit("Shot Lab Eight Ball preset loaded: %s." % preset_id.replace("_", " ").capitalize())
	_emit_state()
	return result


func copy_eight_ball_loadout() -> bool:
	var snapshot: Dictionary = get_eight_ball_loadout_snapshot()
	if snapshot.is_empty():
		return false
	DisplayServer.clipboard_set(JSON.stringify(_to_json_safe({
		"item_ids_by_slot": snapshot.get("item_ids_by_slot", []),
		"slots": snapshot.get("slots", []),
	}), "  "))
	status_changed.emit("Shot Lab Eight Ball loadout copied.")
	return true


func get_eight_ball_build_diagnostics() -> Dictionary:
	var build_system: RogueliteBuildSystem = _get_eight_ball_build_system()
	if build_system == null:
		return {"available": false, "reason": "build_system_unavailable"}
	return {
		"available": true,
		"catalog": EIGHT_BALL_CATALOG.validate_catalog(),
		"build": build_system.get_shot_lab_loadout_snapshot(),
		"last_shot": build_system.get_last_shot_diagnostics(),
	}


func set_scoring_test_modifier_mode(mode_id: String) -> void:
	if mode_id == scoring_test_modifier_mode or not _is_scoring_modifier_mode_valid(mode_id):
		return
	if _is_authoritative_shot_active() or suite_running:
		status_changed.emit("Shot Lab: scoring modifiers are locked while a test is active.")
		return
	scoring_test_modifier_mode = mode_id
	_sync_scoring_modifier_context()
	if active and not loaded_preset.is_empty():
		_refresh_reference_state("scoring_test_modifiers_changed")
	status_changed.emit("Shot Lab scoring test modifiers: %s." % _get_scoring_modifier_label(mode_id))
	_emit_state()


func run_scoring_self_tests() -> Dictionary:
	if table == null or table.roguelite_scoring_system == null:
		status_changed.emit("Roguelite Scoring Self-Test unavailable: scoring system missing.")
		return {}
	var result: Dictionary = table.roguelite_scoring_system.run_self_tests()
	status_changed.emit("Roguelite Scoring Self-Test: %d/%d passed%s" % [
		int(result.get("passed", 0)),
		int(result.get("total", 0)),
		"" if int(result.get("failed", 0)) == 0 else ", %d failed" % int(result.get("failed", 0)),
	])
	_emit_state()
	return result


func copy_score_summary() -> bool:
	var scoring: Dictionary = _dictionary_value(last_result, "scoring")
	var actual: Dictionary = _dictionary_value(scoring, "authoritative")
	var predicted: Dictionary = _dictionary_value(scoring, "predicted")
	if actual.is_empty() and predicted.is_empty():
		return false
	var lines: Array[String] = []
	if not predicted.is_empty():
		lines.append("PREDICTED: %d Haul x %s Mult = %d" % [
			int(predicted.get("final_haul", 0)),
			_format_mult(float(predicted.get("final_mult", 1.0))),
			int(predicted.get("shot_score", 0)),
		])
	if not actual.is_empty():
		lines.append("ACTUAL: %d Haul x %s Mult = %d" % [
			int(actual.get("final_haul", 0)),
			_format_mult(float(actual.get("final_mult", 1.0))),
			int(actual.get("shot_score", 0)),
		])
	lines.append("PARITY: %s" % str(_dictionary_value(scoring, "parity").get("status", "NOT RUN")))
	DisplayServer.clipboard_set("\n".join(lines))
	status_changed.emit("Shot Lab score summary copied.")
	return true


func copy_score_breakdown_json() -> bool:
	var scoring: Dictionary = _dictionary_value(last_result, "scoring")
	if scoring.is_empty():
		return false
	DisplayServer.clipboard_set(JSON.stringify(_to_json_safe(scoring), "  "))
	status_changed.emit("Shot Lab score breakdown copied.")
	return true


func load_selected_setup(from_suite: bool = false) -> bool:
	if _is_authoritative_shot_active():
		status_changed.emit("Shot Lab: setup controls are locked while a shot is active.")
		return false
	var preset: Dictionary = PRESET_CATALOG.get_preset(selected_preset_id)
	if preset.is_empty():
		return _fail_load("Unknown preset: %s" % selected_preset_id)
	var reference_schema_error: String = _get_reference_schema_error(preset)
	if not reference_schema_error.is_empty():
		return _fail_load(reference_schema_error)
	if suite_running and not from_suite:
		cancel_reference_suite("manual_setup_load")

	var resolved_balls: Array[Dictionary] = _resolve_and_validate_balls(preset)
	if resolved_balls.is_empty():
		return false

	table.prepare_for_shot_lab_setup("shot_lab_load:%s" % selected_preset_id)
	role_to_ball_id.clear()
	var loaded_cue: Ball
	var loaded_eight: Ball
	for definition in resolved_balls:
		var ball: Ball = table.spawn_system.spawn_controlled_shot_lab_ball(
			str(definition.get("ball_kind", "object")),
			int(definition.get("ball_number", 1)),
			definition.get("world_position", Vector2.ZERO)
		)
		if ball == null:
			table.prepare_for_shot_lab_setup("shot_lab_spawn_failure")
			return _fail_load("Could not spawn role '%s'." % str(definition.get("role", "unknown")))
		var role: String = str(definition.get("role", ""))
		role_to_ball_id[role] = table.get_run_ball_id(ball)
		match str(definition.get("ball_kind", "object")):
			"cue":
				loaded_cue = ball
			"eight":
				loaded_eight = ball

	if loaded_cue == null:
		table.prepare_for_shot_lab_setup("shot_lab_missing_cue")
		return _fail_load("Preset has no cue ball.")

	table.finish_shot_lab_setup(loaded_cue, loaded_eight)
	loaded_preset = preset.duplicate(true)
	setup_generation += 1
	active = true
	last_reference_fired = false
	last_load_error = ""
	last_result = _make_not_run_result(preset)
	_refresh_reference_state("setup_loaded")
	status_changed.emit("Shot Lab loaded: %s" % str(preset.get("display_name", selected_preset_id)))
	queue_redraw()
	_emit_state()
	if bool(options.get("auto_fire_after_load", false)) and not from_suite:
		call_deferred("fire_reference_shot")
	return true


func fire_reference_shot() -> bool:
	var blocker: String = _get_reference_fire_blocker()
	if not blocker.is_empty():
		status_changed.emit("Shot Lab: %s" % blocker)
		return false
	var direction: Vector2 = resolved_reference.get("world_direction", Vector2.ZERO)
	var power_normalized: float = float(resolved_reference.get("power_normalized", 0.0))
	active_reference_attempt = {
		"resolved_reference": resolved_reference.duplicate(true),
		"preflight": reference_preflight.duplicate(true),
		"committed_prediction": {
			"generation": int(reference_prediction_commit_bundle.get("prediction_generation", 0)),
			"key": str(reference_prediction_commit_bundle.get("prediction_key", "")),
			"request_snapshot": _dictionary_value(
				reference_prediction_commit_bundle,
				"request_snapshot"
			).duplicate(true),
		},
		"setup_generation": setup_generation,
		"suite_repeat_index": suite_repeat_index,
		"commit_requested_usec": Time.get_ticks_usec(),
	}
	last_reference_fired = table.commit_debug_reference_shot(
		direction,
		power_normalized,
		reference_prediction_commit_bundle.duplicate(true)
	)
	if not last_reference_fired:
		active_reference_attempt["commit_succeeded"] = false
		status_changed.emit("Shot Lab: reference shot could not be committed.")
	else:
		# The exact preflight is a one-shot commitment token. Rewind/setup refresh
		# produces a fresh token for the next physical attempt.
		reference_prediction_commit_bundle.clear()
		active_reference_attempt["commit_succeeded"] = true
		var actual_launch_velocity: Vector2 = (
			table.cue_ball.velocity
			if table != null and is_instance_valid(table.cue_ball)
			else Vector2.ZERO
		)
		var expected_launch_velocity: Vector2 = resolved_reference.get(
			"launch_velocity",
			Vector2.ZERO
		)
		active_reference_attempt["actual_launch_velocity"] = actual_launch_velocity
		active_reference_attempt["launch_speed_delta"] = (
			actual_launch_velocity.length() - expected_launch_velocity.length()
		)
		active_reference_attempt["launch_direction_dot"] = (
			actual_launch_velocity.normalized().dot(expected_launch_velocity.normalized())
			if actual_launch_velocity != Vector2.ZERO and expected_launch_velocity != Vector2.ZERO
			else 0.0
		)
		_emit_state()
	return last_reference_fired


func reset_selected_setup() -> bool:
	return load_selected_setup(false)


func reset_last_shot() -> bool:
	if _is_authoritative_shot_active() or suite_running:
		return false
	if table == null or table.shot_rewind_system == null:
		return false
	return table.shot_rewind_system.request_rewind()


func rerun_last_reference_shot() -> bool:
	if not active or _is_authoritative_shot_active() or suite_running:
		return false
	if table.shot_rewind_system.request_rewind():
		call_deferred("fire_reference_shot")
		return true
	if load_selected_setup(false):
		call_deferred("fire_reference_shot")
		return true
	return false


func clear_shot_lab() -> void:
	cancel_reference_suite("shot_lab_clear")
	if table != null:
		table.prepare_for_shot_lab_setup("shot_lab_clear")
	active = false
	dedicated_session = false
	loaded_preset.clear()
	role_to_ball_id.clear()
	resolved_reference.clear()
	reference_preflight.clear()
	reference_prediction_commit_bundle.clear()
	reference_preflight_generation = 0
	active_reference_attempt.clear()
	last_result.clear()
	last_reference_fired = false
	last_load_error = ""
	panel_open = false
	suite_running = false
	suite_cancel_requested = false
	suite_index = 0
	suite_passed = 0
	suite_failed = 0
	suite_failures.clear()
	suite_results.clear()
	suite_completed = false
	_reset_suite_reference_metrics(1)
	cue_restore_pending = false
	last_scratched_cue_ball_id = -1
	scoring_test_modifier_mode = SCORING_MODIFIER_NONE
	_sync_scoring_modifier_context()
	queue_redraw()
	status_changed.emit("Shot Lab cleared. Controlled balls were removed safely.")
	_emit_state()


func copy_last_result() -> bool:
	if last_result.is_empty():
		return false
	DisplayServer.clipboard_set(JSON.stringify(_to_json_safe(last_result), "  "))
	status_changed.emit("Shot Lab result copied.")
	return true


func copy_current_arrangement_as_preset() -> bool:
	if table == null:
		return false
	var ball_rows: Array = []
	for child in table.balls.get_children():
		var ball: Ball = child as Ball
		if ball == null or not is_instance_valid(ball):
			continue
		var normalized: Vector2 = _world_to_normalized(ball.global_position)
		ball_rows.append({
			"role": _get_role_for_ball_id(table.get_run_ball_id(ball)),
			"ball_kind": table.get_shot_ledger_ball_kind_for_debug(ball),
			"ball_number": ball.ball_number,
			"position": normalized,
			"run_ball_id_debug": table.get_run_ball_id(ball),
		})
	var snippet: Dictionary = {
		"preset_id": "authored_setup",
		"display_name": "Authored Setup",
		"coordinate_space": "normalized_playfield",
		"balls": ball_rows,
		"reference_shot": _dictionary_value(loaded_preset, "reference_shot").duplicate(true),
		"expected": {},
	}
	DisplayServer.clipboard_set(JSON.stringify(_to_json_safe(snippet), "  "))
	status_changed.emit("Shot Lab arrangement copied as preset text.")
	return true


func capture_current_aim_as_reference() -> bool:
	if not _can_edit_reference():
		return false
	var manual_aim: Dictionary = table.get_last_manual_aim_authoring_snapshot()
	if not bool(manual_aim.get("valid", false)):
		status_changed.emit("Shot Lab: aim manually before capturing a reference.")
		return false
	var aim_world_value: Variant = manual_aim.get("aim_world_position", null)
	if not aim_world_value is Vector2:
		status_changed.emit("Shot Lab: the last manual aim has no valid world point.")
		return false
	var previous_reference: Dictionary = _dictionary_value(loaded_preset, "reference_shot")
	loaded_preset["reference_shot"] = {
		"enabled": true,
		"aim_type": AIM_NORMALIZED_PLAYFIELD_POINT,
		"aim_point": _world_to_normalized(aim_world_value as Vector2),
		"power_normalized": clampf(float(manual_aim.get("power_normalized", 0.0)), 0.0, 1.0),
		"preflight": _dictionary_value(previous_reference, "preflight").duplicate(true),
		"authored_from_manual_aim": true,
	}
	_refresh_reference_state("manual_aim_captured")
	status_changed.emit("Shot Lab: current manual aim captured as an explicit playfield point.")
	return true


func copy_resolved_reference() -> bool:
	if resolved_reference.is_empty():
		return false
	DisplayServer.clipboard_set(JSON.stringify(_to_json_safe(resolved_reference), "  "))
	status_changed.emit("Shot Lab resolved reference copied.")
	return true


func copy_reference_as_preset_snippet() -> bool:
	if loaded_preset.is_empty():
		return false
	var reference: Dictionary = _dictionary_value(loaded_preset, "reference_shot")
	if reference.is_empty():
		return false
	DisplayServer.clipboard_set(_format_reference_as_gdscript(reference))
	status_changed.emit("Shot Lab explicit reference snippet copied.")
	return true


func nudge_reference_aim(offset_world: Vector2) -> bool:
	if not _can_edit_reference() or offset_world == Vector2.ZERO:
		return false
	var reference: Dictionary = _dictionary_value(loaded_preset, "reference_shot").duplicate(true)
	if str(reference.get("aim_type", "")) == AIM_ROLE_CENTER:
		reference["aim_type"] = AIM_ROLE_OFFSET
	var previous_offset_value: Variant = reference.get("aim_offset_world", Vector2.ZERO)
	var previous_offset: Vector2 = (
		previous_offset_value as Vector2
		if previous_offset_value is Vector2
		else Vector2.ZERO
	)
	reference["aim_offset_world"] = previous_offset + offset_world
	loaded_preset["reference_shot"] = reference
	_refresh_reference_state("reference_aim_nudged")
	status_changed.emit("Shot Lab reference aim nudged by %s px." % offset_world)
	return true


func nudge_reference_power(delta: float) -> bool:
	if not _can_edit_reference() or is_zero_approx(delta):
		return false
	var reference: Dictionary = _dictionary_value(loaded_preset, "reference_shot").duplicate(true)
	reference["power_normalized"] = clampf(
		float(reference.get("power_normalized", 0.0)) + delta,
		0.0,
		1.0
	)
	loaded_preset["reference_shot"] = reference
	_refresh_reference_state("reference_power_nudged")
	status_changed.emit(
		"Shot Lab reference power: %d%%." % roundi(float(reference["power_normalized"]) * 100.0)
	)
	return true


func regenerate_reference_preflight() -> bool:
	if not active or loaded_preset.is_empty() or _is_authoritative_shot_active():
		return false
	_refresh_reference_state("manual_preflight_regeneration")
	status_changed.emit(
		"Shot Lab reference preflight: %s." % str(reference_preflight.get("status", PREFLIGHT_NOT_RUN))
	)
	return bool(resolved_reference.get("resolution_valid", false))


func copy_reference_suite_results() -> bool:
	if not suite_completed and suite_results.is_empty():
		return false
	var suite_snapshot: Dictionary = {
		"total": presets.size(),
		"total_attempts": presets.size() * suite_repeat_target,
		"repeat_target": suite_repeat_target,
		"passed": suite_passed,
		"failed": suite_failed,
		"resolved_count": suite_resolved_count,
		"preflight_counts": suite_preflight_counts.duplicate(true),
		"first_contact_mismatches": suite_first_contact_mismatches,
		"failures": suite_failures.duplicate(),
		"results": suite_results.duplicate(true),
		"per_preset": _make_suite_per_preset_summary(),
	}
	DisplayServer.clipboard_set(JSON.stringify(_to_json_safe(suite_snapshot), "  "))
	status_changed.emit("Shot Lab reference suite results copied.")
	return true


func run_reference_suite() -> bool:
	return _start_reference_suite(1)


func run_reference_repeatability_suite() -> bool:
	return _start_reference_suite(REPEATABILITY_ATTEMPTS)


func _start_reference_suite(repeat_target: int) -> bool:
	if suite_running or _is_authoritative_shot_active():
		return false
	if table != null and table.roguelite_scoring_system != null:
		table.roguelite_scoring_system.set_shot_lab_apply_test_doubloon_payout(false)
	suite_running = true
	suite_cancel_requested = false
	suite_index = 0
	suite_passed = 0
	suite_failed = 0
	suite_failures.clear()
	suite_results.clear()
	suite_completed = false
	_reset_suite_reference_metrics(maxi(repeat_target, 1))
	suite_generation += 1
	status_changed.emit(
		"Shot Lab Reference Suite started%s." % (
			" (%dx repeatability)" % suite_repeat_target
			if suite_repeat_target > 1
			else ""
		)
	)
	_emit_state()
	call_deferred("_run_next_suite_preset", suite_generation)
	return true


func cancel_reference_suite(reason: String = "manual") -> void:
	if not suite_running:
		return
	suite_cancel_requested = true
	suite_running = false
	suite_completed = false
	suite_generation += 1
	status_changed.emit("Shot Lab Reference Suite canceled (%s)." % reason)
	_emit_state()


func get_snapshot() -> Dictionary:
	var shot_active_now: bool = _is_authoritative_shot_active()
	var balls_idle: bool = table != null and table.are_all_balls_stopped_for_rewind()
	var rewind_snapshot: Dictionary = (
		table.shot_rewind_system.get_state_snapshot()
		if table != null and table.shot_rewind_system != null
		else {}
	)
	var reference: Dictionary = _dictionary_value(loaded_preset, "reference_shot")
	var loaded_preset_id: String = str(loaded_preset.get("preset_id", ""))
	var reference_fire_blocker: String = _get_reference_fire_blocker()
	var cue_lifecycle: Dictionary = table.get_cue_lifecycle_debug_snapshot() if table != null else {}
	cue_lifecycle["shot_lab_cue_scratches"] = shot_lab_cue_scratches
	cue_lifecycle["shot_lab_cue_restorations"] = shot_lab_cue_restorations
	cue_lifecycle["cue_restoration_failures"] = cue_restoration_failures
	cue_lifecycle["cue_restore_pending"] = cue_restore_pending
	cue_lifecycle["last_scratched_cue_ball_id"] = last_scratched_cue_ball_id
	cue_lifecycle["last_cue_restoration_error"] = last_cue_restoration_error
	return {
		"active": active,
		"dedicated_session": dedicated_session,
		"panel_open": panel_open,
		"selected_preset_id": selected_preset_id,
		"loaded_preset_id": loaded_preset_id,
		"selected_preset_loaded": active and loaded_preset_id == selected_preset_id,
		"shot_active": shot_active_now,
		"balls_idle": balls_idle,
		"reference_available": (
			bool(reference.get("enabled", false))
			and bool(resolved_reference.get("resolution_valid", false))
		),
		"reference_can_fire": reference_fire_blocker.is_empty(),
		"reference_fire_blocker": reference_fire_blocker,
		"resolved_reference": resolved_reference.duplicate(true),
		"reference_preflight": reference_preflight.duplicate(true),
		"reference_prediction_commit": {
			"ready": _get_reference_prediction_commit_blocker().is_empty(),
			"generation": int(reference_prediction_commit_bundle.get("prediction_generation", 0)),
			"key": str(reference_prediction_commit_bundle.get("prediction_key", "")),
			"blocker": _get_reference_prediction_commit_blocker(),
			"request_snapshot": _dictionary_value(
				reference_prediction_commit_bundle,
				"request_snapshot"
			).duplicate(true),
		},
		"active_reference_attempt": active_reference_attempt.duplicate(true),
		"setup_generation": setup_generation,
		"rewind": rewind_snapshot,
		"loaded_preset": loaded_preset.duplicate(true),
		"presets": get_preset_choices(),
		"role_to_ball_id": role_to_ball_id.duplicate(true),
		"options": options.duplicate(true),
		"last_result": last_result.duplicate(true),
		"last_load_error": last_load_error,
		"last_reference_fired": last_reference_fired,
		"cue_lifecycle": cue_lifecycle,
		"scoring": {
			"modifier_mode": scoring_test_modifier_mode,
			"modifier_choices": get_scoring_modifier_choices(),
			"active_test_modifiers": _get_scoring_test_modifiers(),
			"last": _dictionary_value(last_result, "scoring").duplicate(true),
			"predicted": _dictionary_value(reference_preflight, "predicted_score_result").duplicate(true),
			"system": (
				table.roguelite_scoring_system.get_snapshot()
				if table != null and table.roguelite_scoring_system != null
				else {}
			),
		},
		"eight_ball_build": {
			"choices": get_eight_ball_loadout_choices(),
			"presets": EIGHT_BALL_LOADOUT_PRESETS.duplicate(true),
			"snapshot": get_eight_ball_loadout_snapshot(),
		},
		"suite": {
			"running": suite_running,
			"completed": suite_completed,
			"index": suite_index,
			"total": presets.size(),
			"total_attempts": presets.size() * suite_repeat_target,
			"completed_attempts": suite_completed_attempts,
			"repeat_target": suite_repeat_target,
			"repeat_index": suite_repeat_index,
			"passed": suite_passed,
			"failed": suite_failed,
			"resolved_count": suite_resolved_count,
			"preflight_counts": suite_preflight_counts.duplicate(true),
			"first_contact_mismatches": suite_first_contact_mismatches,
			"per_preset": _make_suite_per_preset_summary(),
			"failures": suite_failures.duplicate(),
			"results": suite_results.duplicate(true),
			"current_preset_name": _get_suite_current_preset_name(),
		},
	}


func _on_eight_ball_build_changed(_snapshot: Dictionary) -> void:
	if not dedicated_session:
		return
	_emit_state()


func _get_eight_ball_build_system() -> RogueliteBuildSystem:
	if table == null:
		return null
	return table.roguelite_build_system


func _get_shot_lab_loadout_ids(build_system: RogueliteBuildSystem) -> Array[String]:
	var snapshot: Dictionary = build_system.get_shot_lab_loadout_snapshot()
	var values: Variant = snapshot.get("item_ids_by_slot", [])
	var item_ids: Array[String] = []
	if values is Array:
		for value in values as Array:
			item_ids.append(str(value))
	while item_ids.size() < RogueliteBuildSystem.TRAY_CAPACITY:
		item_ids.append("")
	if item_ids.size() > RogueliteBuildSystem.TRAY_CAPACITY:
		item_ids.resize(RogueliteBuildSystem.TRAY_CAPACITY)
	return item_ids


func _refresh_reference_for_build_change(reason: String) -> void:
	if active and not loaded_preset.is_empty():
		_refresh_reference_state(reason)


func notify_authoritative_shot_started() -> void:
	if active:
		_emit_state()


func note_cue_ball_scratched(cue_run_ball_id: int) -> void:
	if not active:
		return
	shot_lab_cue_scratches += 1
	last_scratched_cue_ball_id = cue_run_ball_id
	cue_restore_pending = true
	last_cue_restoration_error = ""
	_emit_state()


func get_role_names_by_ball_id() -> Dictionary:
	var names: Dictionary = {}
	for role_value in role_to_ball_id.keys():
		names[str(role_to_ball_id[role_value])] = str(role_value)
	return names


func _on_shot_ledger_completed(ledger: Dictionary) -> void:
	if not active or loaded_preset.is_empty():
		return
	if not bool(ledger.get("shot_lab_active", false)):
		return
	if str(ledger.get("shot_lab_preset_id", "")) != str(loaded_preset.get("preset_id", "")):
		return
	last_result = _evaluate_ledger(ledger, loaded_preset)
	var authoritative_score: Dictionary = (
		table.roguelite_scoring_system.get_score_result_for_ledger(ledger)
		if table.roguelite_scoring_system != null
		else {}
	)
	var predicted_score: Dictionary = _dictionary_value(reference_preflight, "predicted_score_result")
	var score_expectations: Dictionary = _get_active_score_expectations()
	var score_assertions: Dictionary = _evaluate_score_expectations(authoritative_score, score_expectations)
	_merge_score_assertions_into_result(last_result, score_assertions)
	var score_parity: Dictionary = _compare_score_results(
		predicted_score,
		authoritative_score,
		bool(reference_preflight.get("prediction_truncated", false)),
		bool(reference_preflight.get("prediction_valid", false))
	)
	last_result["scoring"] = {
		"authoritative": authoritative_score.duplicate(true),
		"predicted": predicted_score.duplicate(true),
		"parity": score_parity.duplicate(true),
		"assertions": score_assertions.duplicate(true),
		"modifier_mode": scoring_test_modifier_mode,
		"modifiers": _get_scoring_test_modifiers(),
	}
	if table.roguelite_scoring_system != null:
		table.roguelite_scoring_system.note_predicted_actual_comparison(score_parity)
	var reference_comparison: Dictionary = _make_reference_actual_comparison(ledger)
	active_reference_attempt["actual_comparison"] = reference_comparison.duplicate(true)
	last_result["reference_attempt"] = active_reference_attempt.duplicate(true)
	result_completed.emit(last_result.duplicate(true))
	var display_name: String = str(loaded_preset.get("display_name", selected_preset_id))
	var verdict: String = "PASS" if bool(last_result.get("passed", false)) else "FAIL"
	var message: String = "Shot Lab: %s - %s" % [display_name, verdict]
	var failures: Array = _array_value(last_result, "failures")
	if verdict == "FAIL" and not failures.is_empty() and failures[0] is Dictionary:
		var first_failure: Dictionary = failures[0]
		message += "\nExpected %s = %s, received %s" % [
			str(first_failure.get("path", "assertion")),
			str(first_failure.get("expected", "")),
			str(first_failure.get("actual", "")),
		]
	status_changed.emit(message)
	_emit_state()

	if suite_running:
		var suite_result: Dictionary = _make_suite_result_summary(last_result)
		suite_results.append(suite_result)
		suite_completed_attempts += 1
		if bool(resolved_reference.get("resolution_valid", false)):
			suite_resolved_count += 1
		var preflight_status: String = str(reference_preflight.get("status", PREFLIGHT_NOT_RUN))
		if suite_preflight_counts.has(preflight_status):
			suite_preflight_counts[preflight_status] = int(suite_preflight_counts[preflight_status]) + 1
		if bool(reference_comparison.get("first_contact_mismatch", false)):
			suite_first_contact_mismatches += 1
		if bool(suite_result.get("passed", false)):
			suite_passed += 1
		else:
			suite_failed += 1
			suite_failures.append("%s (attempt %d)" % [display_name, suite_repeat_index + 1])
		suite_repeat_index += 1
		if suite_repeat_index >= suite_repeat_target:
			suite_repeat_index = 0
			suite_index += 1
		if cue_restore_pending:
			call_deferred("_restore_after_cue_scratch", suite_generation)
		else:
			call_deferred("_run_next_suite_preset", suite_generation)
	elif cue_restore_pending:
		call_deferred("_restore_after_cue_scratch", -1)
	elif bool(options.get("auto_reset_after_failure", false)) and not bool(last_result.get("passed", false)):
		call_deferred("reset_selected_setup")


func _restore_after_cue_scratch(continue_suite_generation: int) -> void:
	if not cue_restore_pending:
		if continue_suite_generation >= 0:
			call_deferred("_run_next_suite_preset", continue_suite_generation)
		return

	var expected_cue_id: int = last_scratched_cue_ball_id
	var restored: bool = false
	var blocker: String = "Shot rewind system unavailable."
	if table != null and table.shot_rewind_system != null:
		restored = table.shot_rewind_system.request_rewind(true)
		if not restored:
			blocker = str(table.shot_rewind_system.get_state_snapshot().get(
				"blocker_reason",
				"Pre-shot checkpoint could not be restored."
			))

	var restored_cue_id: int = -1
	var cue_is_valid: bool = (
		table != null
		and table.cue_ball != null
		and is_instance_valid(table.cue_ball)
		and not table.cue_ball.is_queued_for_deletion()
		and table.cue_ball.is_gameplay_active()
	)
	if cue_is_valid:
		restored_cue_id = table.get_run_ball_id(table.cue_ball)
	var identity_matches: bool = expected_cue_id <= 0 or restored_cue_id == expected_cue_id
	if restored and cue_is_valid and identity_matches:
		shot_lab_cue_restorations += 1
		cue_restore_pending = false
		last_cue_restoration_error = ""
		status_changed.emit("Shot Lab cue restored from the pre-shot checkpoint (ball ID %d)." % restored_cue_id)
	else:
		cue_restoration_failures += 1
		cue_restore_pending = false
		if restored and not identity_matches:
			blocker = "Cue identity mismatch: expected %d, restored %d." % [expected_cue_id, restored_cue_id]
		elif restored and not cue_is_valid:
			blocker = "Checkpoint restored without a valid cue ball."
		last_cue_restoration_error = blocker
		status_changed.emit("Shot Lab cue restoration failed: %s" % blocker)
		push_warning("Shot Lab cue restoration failed: %s" % blocker)
	_emit_state()
	if continue_suite_generation >= 0:
		call_deferred("_run_next_suite_preset", continue_suite_generation)


func _run_next_suite_preset(generation: int) -> void:
	if not suite_running or suite_cancel_requested or generation != suite_generation or not is_inside_tree():
		return
	if suite_index >= presets.size():
		_finish_reference_suite()
		return
	var preset: Dictionary = presets[suite_index]
	selected_preset_id = str(preset.get("preset_id", ""))
	if not load_selected_setup(true):
		_record_remaining_suite_attempt_failures(preset, "Setup could not be loaded.", "load failed")
		suite_index += 1
		suite_repeat_index = 0
		call_deferred("_run_next_suite_preset", generation)
		return
	call_deferred("_fire_suite_reference", generation)


func _fire_suite_reference(generation: int) -> void:
	if not suite_running or suite_cancel_requested or generation != suite_generation:
		return
	if not fire_reference_shot():
		var preset: Dictionary = PRESET_CATALOG.get_preset(selected_preset_id)
		var blocker: String = _get_reference_fire_blocker()
		var reason: String = "Reference shot could not be committed."
		if not blocker.is_empty():
			reason += " %s" % blocker
		_record_remaining_suite_attempt_failures(preset, reason, "fire failed")
		suite_index += 1
		suite_repeat_index = 0
		call_deferred("_run_next_suite_preset", generation)


func _finish_reference_suite() -> void:
	suite_running = false
	suite_completed = true
	var total_attempts: int = presets.size() * suite_repeat_target
	var result: Dictionary = {
		"total": presets.size(),
		"total_attempts": total_attempts,
		"repeat_target": suite_repeat_target,
		"passed": suite_passed,
		"failed": suite_failed,
		"resolved_count": suite_resolved_count,
		"preflight_counts": suite_preflight_counts.duplicate(true),
		"first_contact_mismatches": suite_first_contact_mismatches,
		"failures": suite_failures.duplicate(),
		"results": suite_results.duplicate(true),
		"per_preset": _make_suite_per_preset_summary(),
	}
	reference_suite_completed.emit(result.duplicate(true))
	status_changed.emit("Shot Lab Reference Suite: %d/%d passed%s" % [
		suite_passed,
		total_attempts,
		"" if suite_failed == 0 else ", %d failed" % suite_failed,
	])
	_emit_state()


func _on_shot_rewind_completed() -> void:
	if active:
		_refresh_reference_state("shot_rewind_completed")
		_emit_state()


func _resolve_and_validate_balls(preset: Dictionary) -> Array[Dictionary]:
	if table == null or table.playfield_rect.size == Vector2.ZERO:
		_fail_load("Playfield geometry is unavailable.")
		return []
	var definitions_value: Variant = preset.get("balls", [])
	if not definitions_value is Array or (definitions_value as Array).is_empty():
		_fail_load("Preset has no balls.")
		return []
	var resolved: Array[Dictionary] = []
	var roles: Dictionary = {}
	for definition_value in definitions_value:
		if not definition_value is Dictionary:
			_fail_load("Preset contains a malformed ball definition.")
			return []
		var definition: Dictionary = (definition_value as Dictionary).duplicate(true)
		var role: String = str(definition.get("role", "")).strip_edges()
		if role.is_empty() or roles.has(role):
			_fail_load("Preset role is missing or duplicated: '%s'." % role)
			return []
		roles[role] = true
		var ball_kind: String = str(definition.get("ball_kind", "object"))
		if ball_kind not in ["cue", "eight", "object"]:
			var kind_reason: String = "is not an ordinary Shot Lab ball" if bool(options.get("ordinary_balls_only", true)) else "has no controlled Shot Lab spawn adapter yet"
			_fail_load("Role '%s' %s ('%s')." % [role, kind_reason, ball_kind])
			return []
		var normalized_value: Variant = definition.get("position", null)
		if not normalized_value is Vector2:
			_fail_load("Role '%s' has no normalized Vector2 position." % role)
			return []
		var normalized_position: Vector2 = normalized_value as Vector2
		var world_position: Vector2 = _normalized_to_world(normalized_position)
		if not table.playfield_rect.grow(-BALL_RADIUS).has_point(world_position):
			_fail_load("Role '%s' begins outside the playable area." % role)
			return []
		var boundary_name: String = _get_intersecting_boundary_name(world_position, BALL_RADIUS)
		if not boundary_name.is_empty():
			_fail_load("Role '%s' intersects authored boundary '%s'." % [role, boundary_name])
			return []
		if table.pocket_system.is_position_too_close_to_pocket(world_position, BALL_RADIUS, 0.0):
			_fail_load("Role '%s' begins inside a pocket capture region." % role)
			return []
		for previous in resolved:
			var previous_position: Vector2 = previous.get("world_position", Vector2.ZERO)
			if world_position.distance_to(previous_position) < BALL_RADIUS * 2.0 + START_CLEARANCE:
				_fail_load("Roles '%s' and '%s' overlap at setup." % [role, str(previous.get("role", ""))])
				return []
		definition["world_position"] = world_position
		resolved.append(definition)
	return resolved


func _get_intersecting_boundary_name(position: Vector2, ball_radius: float) -> String:
	if table == null or table.boundary_system == null:
		return ""
	for geometry_value in table.boundary_system.get_prediction_geometry_snapshot():
		if not geometry_value is Dictionary:
			continue
		var geometry: Dictionary = geometry_value
		var inverse_transform: Transform2D = geometry.get("inverse_transform", Transform2D.IDENTITY)
		var half_size: Vector2 = geometry.get("half_size", Vector2.ZERO) + Vector2.ONE * ball_radius
		var local_position: Vector2 = inverse_transform * position
		if absf(local_position.x) <= half_size.x and absf(local_position.y) <= half_size.y:
			return str(geometry.get("boundary_name", geometry.get("boundary_index", "boundary")))
	return ""


func _get_reference_schema_error(preset: Dictionary) -> String:
	var reference: Dictionary = _dictionary_value(preset, "reference_shot")
	if not bool(reference.get("enabled", false)):
		return ""
	if reference.has("direction"):
		return "Legacy reference direction has ambiguous coordinate space."
	var aim_type: String = str(reference.get("aim_type", ""))
	if aim_type not in [
		AIM_ROLE_CENTER,
		AIM_ROLE_OFFSET,
		AIM_NORMALIZED_PLAYFIELD_POINT,
		AIM_POCKET_CENTER,
		AIM_WORLD_DIRECTION,
	]:
		return "Reference aim type is missing or unsupported: '%s'." % aim_type
	if not reference.has("power_normalized"):
		return "Reference has no authored normalized power."
	return ""


func _refresh_reference_state(_reason: String) -> void:
	resolved_reference = _resolve_reference_shot()
	reference_preflight = _build_reference_preflight(resolved_reference)
	queue_redraw()


func _resolve_reference_shot() -> Dictionary:
	var result: Dictionary = {
		"preset_id": str(loaded_preset.get("preset_id", "")),
		"setup_generation": setup_generation,
		"resolution_valid": false,
		"failure_reason": "Reference has not been resolved.",
		"aim_type": "",
		"aim_world_position": Vector2.ZERO,
		"world_direction": Vector2.ZERO,
		"power_normalized": 0.0,
		"drag_magnitude": 0.0,
		"launch_speed": 0.0,
		"launch_velocity": Vector2.ZERO,
		"baseline_reference_shot_power": 0.0,
		"modifiers_bypassed": true,
	}
	if not active or loaded_preset.is_empty() or table == null:
		result["failure_reason"] = "Load a Shot Lab setup first."
		return result
	var reference: Dictionary = _dictionary_value(loaded_preset, "reference_shot")
	if not bool(reference.get("enabled", false)):
		result["failure_reason"] = "This preset has no reference shot."
		return result
	if reference.has("direction"):
		result["failure_reason"] = "Legacy reference direction has ambiguous coordinate space."
		push_warning(str(result["failure_reason"]))
		return result

	var cue: Ball = _get_authoritative_role_ball("cue")
	if cue == null or cue != table.cue_ball:
		result["failure_reason"] = "Role `cue` has no valid authoritative cue ball."
		return result
	var cue_position: Vector2 = cue.global_position
	var aim_type: String = str(reference.get("aim_type", ""))
	var aim_world_position := Vector2.ZERO
	var world_direction := Vector2.ZERO
	var aim_offset_value: Variant = reference.get("aim_offset_world", Vector2.ZERO)
	if not aim_offset_value is Vector2 or not _is_finite_vector(aim_offset_value as Vector2):
		result["failure_reason"] = "Reference world-space aim offset is invalid."
		return result
	var aim_offset_world: Vector2 = aim_offset_value as Vector2

	match aim_type:
		AIM_ROLE_CENTER, AIM_ROLE_OFFSET:
			var aim_role: String = str(reference.get("aim_role", "")).strip_edges()
			var target_ball: Ball = _get_authoritative_role_ball(aim_role)
			if aim_role.is_empty() or target_ball == null:
				result["failure_reason"] = "Role `%s` has no valid authoritative ball." % aim_role
				return result
			aim_world_position = target_ball.global_position + aim_offset_world
			result["aim_role"] = aim_role
			result["aim_role_ball_id"] = table.get_run_ball_id(target_ball)
		AIM_NORMALIZED_PLAYFIELD_POINT:
			var aim_point_value: Variant = reference.get("aim_point", null)
			if not aim_point_value is Vector2 or not _is_finite_vector(aim_point_value as Vector2):
				result["failure_reason"] = "Reference normalized playfield point is invalid."
				return result
			result["aim_point_normalized"] = aim_point_value as Vector2
			aim_world_position = _normalized_to_world(aim_point_value as Vector2) + aim_offset_world
		AIM_POCKET_CENTER:
			var pocket_index: int = _resolve_reference_pocket_index(reference)
			var pocket_positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
			if pocket_index < 0 or pocket_index >= pocket_positions.size():
				result["failure_reason"] = "Reference pocket is missing or out of range."
				return result
			aim_world_position = pocket_positions[pocket_index] + aim_offset_world
			result["pocket_index"] = pocket_index
			var pocket_names: Array[String] = table.pocket_system.get_pocket_names()
			result["pocket_name"] = pocket_names[pocket_index] if pocket_index < pocket_names.size() else "Pocket %d" % pocket_index
		AIM_WORLD_DIRECTION:
			var direction_value: Variant = reference.get("world_direction", null)
			if not direction_value is Vector2 or not _is_finite_vector(direction_value as Vector2):
				result["failure_reason"] = "Reference world direction is invalid."
				return result
			world_direction = (direction_value as Vector2).normalized()
			aim_world_position = cue_position + world_direction * REFERENCE_LINE_LENGTH + aim_offset_world
		_:
			result["failure_reason"] = "Reference aim type is unsupported: '%s'." % aim_type
			return result

	if not _is_finite_vector(aim_world_position):
		result["failure_reason"] = "Resolved reference aim point is not finite."
		return result
	if aim_type != AIM_WORLD_DIRECTION:
		world_direction = (aim_world_position - cue_position).normalized()
	if not _is_finite_vector(world_direction) or world_direction == Vector2.ZERO:
		result["failure_reason"] = "Resolved reference direction is zero or invalid."
		return result

	var power_normalized: float = float(reference.get("power_normalized", -1.0))
	if not is_finite(power_normalized) or power_normalized < 0.0 or power_normalized > 1.0:
		result["failure_reason"] = "Reference normalized power must be between 0 and 1."
		return result
	var power_profile: Dictionary = table.get_shot_lab_reference_power_profile(power_normalized)
	if float(power_profile.get("drag_magnitude", 0.0)) < float(power_profile.get("minimum_drag_distance", 0.0)):
		result["failure_reason"] = "Reference power is below the canonical minimum shot distance."
		return result

	result.merge({
		"resolution_valid": true,
		"failure_reason": "",
		"aim_type": aim_type,
		"cue_ball_id": table.get_run_ball_id(cue),
		"cue_world_position": cue_position,
		"aim_world_position": aim_world_position,
		"aim_offset_world": aim_offset_world,
		"world_direction": world_direction,
		"power_normalized": power_normalized,
		"drag_magnitude": float(power_profile.get("drag_magnitude", 0.0)),
		"launch_speed": float(power_profile.get("launch_speed", 0.0)),
		"launch_velocity": world_direction * float(power_profile.get("launch_speed", 0.0)),
		"baseline_reference_shot_power": float(power_profile.get("baseline_shot_power", 0.0)),
		"modifiers_bypassed": bool(power_profile.get("modifiers_bypassed", true)),
	}, true)
	return result


func _resolve_reference_pocket_index(reference: Dictionary) -> int:
	if reference.has("pocket_index"):
		return int(reference.get("pocket_index", -1))
	var requested_name: String = str(reference.get("pocket_name", ""))
	if requested_name.is_empty() or table == null or table.pocket_system == null:
		return -1
	var pocket_names: Array[String] = table.pocket_system.get_pocket_names()
	for pocket_index in range(pocket_names.size()):
		if pocket_names[pocket_index] == requested_name:
			return pocket_index
	return -1


func _build_reference_preflight(resolved: Dictionary) -> Dictionary:
	reference_prediction_commit_bundle.clear()
	var preflight: Dictionary = {
		"status": PREFLIGHT_NOT_RUN,
		"failure_reason": "",
		"warnings": [],
		"issues": [],
		"prediction_valid": false,
		"prediction_truncated": false,
		"prediction_stop_reason": "not_run",
		"predicted_first_contact_role": "none",
		"expected_first_contact_role": "none",
		"predicted_pocket_roles": [],
		"expected_pocket_roles": [],
		"predicted_rail_counts_by_role": {},
		"predicted_scratch": false,
		"predicted_tags": [],
		"predicted_tag_counts": {},
		"predicted_score_result": {},
		"predicted_score_assertions": {},
	}
	if not bool(resolved.get("resolution_valid", false)):
		preflight["status"] = PREFLIGHT_FAIL
		preflight["failure_reason"] = str(resolved.get("failure_reason", "Reference resolution failed."))
		return preflight

	var reference: Dictionary = _dictionary_value(loaded_preset, "reference_shot")
	var expectation: Dictionary = _dictionary_value(reference, "preflight")
	var expected_first: String = str(expectation.get("expected_first_contact_role", ""))
	var expected_pockets: Array = _array_value(expectation, "expected_pocket_roles")
	preflight["expected_first_contact_role"] = expected_first if not expected_first.is_empty() else "none"
	preflight["expected_pocket_roles"] = expected_pockets.duplicate()

	reference_preflight_generation += 1
	var prediction: Dictionary = table.aim_preview.simulate_shot_lab_reference(
		resolved.get("cue_world_position", Vector2.ZERO),
		resolved.get("launch_velocity", Vector2.ZERO)
	)
	var prediction_valid: bool = bool(prediction.get("valid", false))
	var prediction_truncated: bool = bool(prediction.get("truncated", false))
	preflight["prediction_valid"] = prediction_valid
	preflight["prediction_truncated"] = prediction_truncated
	preflight["prediction_stop_reason"] = str(prediction.get("stop_reason", "unknown"))
	preflight["prediction_event_count"] = _array_value(prediction, "events").size()
	preflight["prediction_ball_count"] = _array_value(prediction, "balls").size()
	preflight["prediction_unsupported_warnings"] = _array_value(prediction, "unsupported_warnings").duplicate(true)
	if prediction_valid:
		reference_prediction_commit_bundle = _make_reference_prediction_commit_bundle(
			resolved,
			prediction
		)

	var issues: Array[String] = []
	var warnings: Array[String] = []
	if not prediction_valid:
		issues.append("Cloned prediction was unavailable: %s." % preflight["prediction_stop_reason"])
	else:
		var predicted_ledger: Dictionary = _make_predicted_reference_ledger(prediction)
		var derived: Dictionary = ShotLedgerAnalyzer.analyze(predicted_ledger)
		predicted_ledger["derived"] = derived
		var predicted_evaluation: Dictionary = _evaluate_ledger(predicted_ledger, loaded_preset)
		var predicted_score: Dictionary = {}
		if table.roguelite_scoring_system != null:
			predicted_score = table.roguelite_scoring_system.resolve_predicted_ledger(
				predicted_ledger,
				_get_scoring_test_modifiers()
			)
		preflight["predicted_score_result"] = predicted_score.duplicate(true)
		var predicted_score_assertions: Dictionary = _evaluate_score_expectations(
			predicted_score,
			_get_active_score_expectations()
		)
		preflight["predicted_score_assertions"] = predicted_score_assertions.duplicate(true)
		var first_ball_id: int = int(derived.get("first_object_contact_ball_id", -1))
		var first_role: String = _get_role_for_ball_id(first_ball_id)
		if first_role.is_empty():
			first_role = "none"
		var pocket_roles: Array[String] = _get_roles_for_ball_ids(_array_value(derived, "pocket_order"))
		var rail_counts: Dictionary = _map_ball_counts_to_roles(_dictionary_value(derived, "rail_contacts_by_ball"))
		var tag_counts: Dictionary = _dictionary_value(derived, "tag_counts").duplicate(true)
		preflight["predicted_first_contact_role"] = first_role
		preflight["predicted_pocket_roles"] = pocket_roles
		preflight["predicted_pocket_indices_by_role"] = _map_pocket_indices_to_roles(
			_dictionary_value(derived, "pocket_index_by_ball")
		)
		preflight["predicted_rail_counts_by_role"] = rail_counts
		preflight["predicted_cue_rails_before_first_contact"] = int(derived.get("cue_rails_before_first_object_contact", 0))
		preflight["predicted_scratch"] = bool(derived.get("scratch_occurred", false))
		preflight["predicted_tags"] = _get_tag_ids(derived)
		preflight["predicted_tag_counts"] = tag_counts
		preflight["predicted_assertions_passed"] = int(predicted_evaluation.get("assertions_passed", 0))
		preflight["predicted_assertions_total"] = int(predicted_evaluation.get("assertions_total", 0))
		preflight["predicted_assertion_failures"] = _array_value(predicted_evaluation, "failures").duplicate(true)

		if bool(expectation.get("expect_no_first_contact", false)):
			if first_role != "none":
				issues.append("Expected no first object contact; predicted `%s`." % first_role)
		elif not expected_first.is_empty() and first_role != expected_first:
			issues.append("Expected first contact `%s`; predicted `%s`." % [expected_first, first_role])
		for expected_role_value in expected_pockets:
			var expected_role: String = str(expected_role_value)
			if expected_role not in pocket_roles:
				issues.append("Expected `%s` to be pocketed." % expected_role)
		if bool(derived.get("scratch_occurred", false)) != bool(expectation.get("expected_scratch", false)):
			issues.append("Predicted scratch state does not match the authored expectation.")
		var pocket_indices_by_role: Dictionary = preflight["predicted_pocket_indices_by_role"]
		if bool(expectation.get("require_different_pockets", false)) and not _roles_use_different_pockets(expected_pockets, pocket_indices_by_role):
			issues.append("Expected pocketed roles do not use different pockets in prediction.")
		if bool(expectation.get("require_same_pocket", false)) and not _roles_use_same_pocket(expected_pockets, pocket_indices_by_role):
			issues.append("Expected pocketed roles do not use the same pocket in prediction.")
		for failure_value in _array_value(predicted_evaluation, "failures"):
			if failure_value is Dictionary:
				var failure: Dictionary = failure_value
				issues.append("Predicted assertion `%s` expected %s, received %s." % [
					str(failure.get("path", "assertion")),
					str(failure.get("expected", "")),
					str(failure.get("actual", "")),
				])
		if not prediction_truncated:
			for failure_value in _array_value(predicted_score_assertions, "failures"):
				if failure_value is Dictionary:
					var failure: Dictionary = failure_value
					issues.append("Predicted score `%s` expected %s, received %s." % [
						str(failure.get("path", "score")),
						str(failure.get("expected", "")),
						str(failure.get("actual", "")),
					])

	if prediction_truncated:
		warnings.append("Prediction was capped at `%s`; deeper semantics may be incomplete." % preflight["prediction_stop_reason"])
	var failure_policy: String = str(expectation.get("failure_policy", "warn"))
	if not issues.is_empty():
		preflight["status"] = PREFLIGHT_FAIL if failure_policy == "block" else PREFLIGHT_WARN
		preflight["failure_reason"] = issues[0]
	elif not warnings.is_empty():
		preflight["status"] = PREFLIGHT_WARN
		preflight["failure_reason"] = warnings[0]
	else:
		preflight["status"] = PREFLIGHT_PASS
	preflight["issues"] = issues
	preflight["warnings"] = warnings
	preflight["failure_policy"] = failure_policy
	return preflight


func _make_reference_prediction_commit_bundle(
	resolved: Dictionary,
	prediction: Dictionary
) -> Dictionary:
	var request_value: Variant = prediction.get("reference_request_snapshot", {})
	if not request_value is Dictionary:
		return {}
	var request_snapshot: Dictionary = (request_value as Dictionary).duplicate(true)
	request_snapshot.merge({
		"source": "shot_lab_reference_preflight",
		"request_id": reference_preflight_generation,
		"setup_generation": setup_generation,
		"preflight_generation": reference_preflight_generation,
		"preset_id": str(loaded_preset.get("preset_id", "")),
		"cue_ball_id": int(resolved.get("cue_ball_id", -1)),
		"cue_origin": resolved.get("cue_world_position", Vector2.ZERO),
		"world_direction": resolved.get("world_direction", Vector2.ZERO),
		"launch_velocity": resolved.get("launch_velocity", Vector2.ZERO),
		"launch_speed": float(resolved.get("launch_speed", 0.0)),
		"power_normalized": float(resolved.get("power_normalized", 0.0)),
		"player_request_class": "shot_lab_reference",
	}, true)
	return {
		"accepted": true,
		"status": "shot_lab_reference_preflight_at_commit",
		"prediction_generation": reference_preflight_generation,
		"prediction_key": "%s:%d:%d" % [
			str(prediction.get("reference_prediction_key", "shot_lab_reference")),
			setup_generation,
			reference_preflight_generation,
		],
		"request_snapshot": request_snapshot,
		"prediction_result": prediction.duplicate(true),
	}


func _make_predicted_reference_ledger(prediction: Dictionary) -> Dictionary:
	var instance_to_run_id: Dictionary = {}
	var starting_balls: Dictionary = {}
	var cue_ball_id := -1
	for child in table.balls.get_children():
		var ball: Ball = child as Ball
		if ball == null or not is_instance_valid(ball) or ball.is_queued_for_deletion():
			continue
		var run_ball_id: int = table.get_run_ball_id(ball)
		instance_to_run_id[str(ball.get_instance_id())] = run_ball_id
		var ball_kind: String = table.get_shot_ledger_ball_kind_for_debug(ball)
		starting_balls[str(run_ball_id)] = {
			"ball_id": run_ball_id,
			"ball_number": ball.ball_number,
			"ball_kind": ball_kind,
			"counts_as_object_ball": ball.ball_type == Ball.BallType.OBJECT,
			"active": ball.is_gameplay_active(),
			"start_position": ball.global_position,
		}
		if ball == table.cue_ball:
			cue_ball_id = run_ball_id

	var raw_events: Array[Dictionary] = []
	for event_value in _array_value(prediction, "events"):
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var event_type: String = str(event.get("event_type", ""))
		var source_id: int = _prediction_source_to_run_id(event.get("source_ball_id", -1), instance_to_run_id)
		var target_id: int = _prediction_source_to_run_id(event.get("target_ball_id", -1), instance_to_run_id)
		match event_type:
			AimTrajectoryPredictor.EVENT_BALL_CONTACT:
				raw_events.append({
					"event_type": "ball_contact",
					"event_index": int(event.get("event_index", raw_events.size())),
					"ball_a_id": source_id,
					"ball_b_id": target_id,
					"source_ball_id": source_id,
					"target_ball_id": target_id,
					"accepted_impact": bool(event.get("supported", true)),
				})
			AimTrajectoryPredictor.EVENT_RAIL_CONTACT:
				raw_events.append({
					"event_type": "rail_contact",
					"event_index": int(event.get("event_index", raw_events.size())),
					"ball_id": source_id,
					"rail_id": str(event.get("rail_name", event.get("rail_index", "rail"))),
				})
			AimTrajectoryPredictor.EVENT_POCKET:
				var start_snapshot: Dictionary = _dictionary_value(starting_balls, str(source_id))
				raw_events.append({
					"event_type": "pocket",
					"event_index": int(event.get("event_index", raw_events.size())),
					"ball_id": source_id,
					"pocket_index": int(event.get("pocket_index", -1)),
					"ball_kind": str(start_snapshot.get("ball_kind", "unknown")),
					"counts_as_object_ball": bool(start_snapshot.get("counts_as_object_ball", false)),
				})

	var ending_balls: Dictionary = {}
	for ball_value in _array_value(prediction, "balls"):
		if not ball_value is Dictionary:
			continue
		var ball_result: Dictionary = ball_value
		var run_ball_id: int = _prediction_source_to_run_id(ball_result.get("source_ball_id", -1), instance_to_run_id)
		if run_ball_id <= 0:
			continue
		var start_snapshot: Dictionary = _dictionary_value(starting_balls, str(run_ball_id))
		ending_balls[str(run_ball_id)] = {
			"ball_id": run_ball_id,
			"ball_number": int(start_snapshot.get("ball_number", -1)),
			"ball_kind": str(start_snapshot.get("ball_kind", "unknown")),
			"active": not bool(ball_result.get("pocketed", false)),
			"pocketed": bool(ball_result.get("pocketed", false)),
			"final_position": ball_result.get("ending_position", Vector2.ZERO),
			"final_velocity": ball_result.get("ending_velocity", Vector2.ZERO),
			"travel_distance": _sum_path_distance(_array_value(ball_result, "path_points")),
		}
	return {
		"schema_version": ShotLedgerAnalyzer.SCHEMA_VERSION,
		"source": "shot_lab_reference_preflight",
		"mode_id": GAME_MODE_SCRIPT.MODE_SHOT_LAB,
		"shot_id": -1,
		"attempt_id": -1,
		"shot_lab_active": true,
		"shot_lab_preset_id": str(loaded_preset.get("preset_id", "")),
		"cue_ball_id": cue_ball_id,
		"starting_balls": starting_balls,
		"ending_balls": ending_balls,
		"raw_events": raw_events,
	}


func _get_reference_fire_blocker() -> String:
	if not active or loaded_preset.is_empty():
		return "Load a setup first."
	if str(loaded_preset.get("preset_id", "")) != selected_preset_id:
		return "The selected preset is not loaded."
	if not bool(resolved_reference.get("resolution_valid", false)):
		return str(resolved_reference.get("failure_reason", "Reference resolution failed."))
	if int(resolved_reference.get("setup_generation", -1)) != setup_generation:
		return "Reference belongs to a stale setup generation."
	var cue: Ball = _get_authoritative_role_ball("cue")
	if cue == null or cue != table.cue_ball:
		return "The authoritative cue no longer matches the loaded preset."
	if table.get_run_ball_id(cue) != int(resolved_reference.get("cue_ball_id", -1)):
		return "The resolved cue identity is stale."
	if _is_authoritative_shot_active():
		return "Wait for the active shot to finish."
	if not table.are_all_balls_stopped_for_rewind():
		return "Wait for all balls to stop."
	if str(reference_preflight.get("status", PREFLIGHT_NOT_RUN)) == PREFLIGHT_FAIL:
		return "REFERENCE INVALID: %s" % str(reference_preflight.get("failure_reason", "Preflight failed."))
	var prediction_blocker: String = _get_reference_prediction_commit_blocker()
	if not prediction_blocker.is_empty():
		return "REFERENCE PREDICTION STALE: %s" % prediction_blocker
	return ""


func _get_reference_prediction_commit_blocker() -> String:
	if reference_prediction_commit_bundle.is_empty():
		return "No validated cloned preflight result is available."
	if not bool(reference_prediction_commit_bundle.get("accepted", false)):
		return "The cloned preflight result was not accepted."
	var request_value: Variant = reference_prediction_commit_bundle.get("request_snapshot", {})
	var result_value: Variant = reference_prediction_commit_bundle.get("prediction_result", {})
	if not request_value is Dictionary or not result_value is Dictionary:
		return "The cloned preflight bundle is malformed."
	var request_snapshot: Dictionary = request_value
	var prediction_result: Dictionary = result_value
	if not bool(prediction_result.get("valid", false)):
		return "The cloned preflight result is invalid."
	if int(request_snapshot.get("setup_generation", -1)) != setup_generation:
		return "The setup generation changed."
	if int(request_snapshot.get("preflight_generation", -1)) != reference_preflight_generation:
		return "A newer reference preflight exists."
	if str(request_snapshot.get("preset_id", "")) != str(loaded_preset.get("preset_id", "")):
		return "The loaded preset changed."
	var cue: Ball = _get_authoritative_role_ball("cue")
	if cue == null or cue != table.cue_ball:
		return "The authoritative cue changed."
	if int(request_snapshot.get("cue_ball_id", -1)) != table.get_run_ball_id(cue):
		return "The cue identity changed."
	var origin_value: Variant = request_snapshot.get("cue_origin", null)
	var direction_value: Variant = request_snapshot.get("world_direction", null)
	var velocity_value: Variant = request_snapshot.get("launch_velocity", null)
	if not origin_value is Vector2 or not direction_value is Vector2 or not velocity_value is Vector2:
		return "The cloned preflight launch snapshot is incomplete."
	if (origin_value as Vector2).distance_to(cue.global_position) > REFERENCE_COMMIT_ORIGIN_TOLERANCE_PX:
		return "The cue origin moved."
	var expected_direction: Vector2 = resolved_reference.get("world_direction", Vector2.ZERO)
	var preflight_direction: Vector2 = (direction_value as Vector2).normalized()
	if (
		expected_direction == Vector2.ZERO
		or preflight_direction == Vector2.ZERO
		or preflight_direction.dot(expected_direction.normalized()) < REFERENCE_LAUNCH_DIRECTION_DOT_MIN
	):
		return "The reference direction changed."
	var expected_velocity: Vector2 = resolved_reference.get("launch_velocity", Vector2.ZERO)
	if (velocity_value as Vector2).distance_to(expected_velocity) > REFERENCE_COMMIT_VELOCITY_TOLERANCE:
		return "The reference launch velocity changed."
	if (
		absf(
			float(request_snapshot.get("power_normalized", -1.0))
			- float(resolved_reference.get("power_normalized", 0.0))
		) > REFERENCE_COMMIT_POWER_TOLERANCE
	):
		return "The reference power changed."
	var current_revision: int = table.get_aim_prediction_state_revision()
	if int(request_snapshot.get("table_prediction_revision", -1)) != current_revision:
		return "The table prediction revision changed."
	if int(prediction_result.get("table_revision", -1)) != current_revision:
		return "The cloned result belongs to a stale table revision."
	return ""


func _get_authoritative_role_ball(role: String) -> Ball:
	var run_ball_id: int = int(role_to_ball_id.get(role, -1))
	if run_ball_id <= 0 or table == null or table.balls == null:
		return null
	for child in table.balls.get_children():
		var ball: Ball = child as Ball
		if (
			ball != null
			and is_instance_valid(ball)
			and not ball.is_queued_for_deletion()
			and ball.get_parent() == table.balls
			and ball.is_gameplay_active()
			and table.get_run_ball_id(ball) == run_ball_id
		):
			return ball
	return null


func _make_reference_actual_comparison(ledger: Dictionary) -> Dictionary:
	var derived: Dictionary = _dictionary_value(ledger, "derived")
	var actual_first_id: int = int(derived.get("first_object_contact_ball_id", -1))
	var actual_first_role: String = _get_role_for_ball_id(actual_first_id)
	if actual_first_role.is_empty():
		actual_first_role = "none"
	var predicted_first_role: String = str(reference_preflight.get("predicted_first_contact_role", "none"))
	return {
		"predicted_first_contact_role": predicted_first_role,
		"actual_first_contact_role": actual_first_role,
		"first_contact_mismatch": predicted_first_role != actual_first_role,
		"predicted_pocket_roles": _array_value(reference_preflight, "predicted_pocket_roles").duplicate(),
		"actual_pocket_roles": _get_roles_for_ball_ids(_array_value(derived, "pocket_order")),
		"predicted_rail_counts_by_role": _dictionary_value(reference_preflight, "predicted_rail_counts_by_role").duplicate(true),
		"actual_rail_counts_by_role": _map_ball_counts_to_roles(_dictionary_value(derived, "rail_contacts_by_ball")),
		"prediction_valid": bool(reference_preflight.get("prediction_valid", false)),
		"prediction_truncated": bool(reference_preflight.get("prediction_truncated", false)),
		"assertions_passed": bool(last_result.get("passed", false)),
	}


func _prediction_source_to_run_id(source_value: Variant, instance_to_run_id: Dictionary) -> int:
	return int(instance_to_run_id.get(str(int(source_value)), -1))


func _get_roles_for_ball_ids(ball_ids: Array) -> Array[String]:
	var roles: Array[String] = []
	for ball_id_value in ball_ids:
		var role: String = _get_role_for_ball_id(int(ball_id_value))
		if role.is_empty():
			role = "ball_%d" % int(ball_id_value)
		roles.append(role)
	return roles


func _map_ball_counts_to_roles(counts: Dictionary) -> Dictionary:
	var mapped: Dictionary = {}
	for ball_id_value in counts.keys():
		var role: String = _get_role_for_ball_id(int(str(ball_id_value)))
		if role.is_empty():
			role = "ball_%s" % str(ball_id_value)
		mapped[role] = int(counts[ball_id_value])
	return mapped


func _map_pocket_indices_to_roles(indices: Dictionary) -> Dictionary:
	var mapped: Dictionary = {}
	for ball_id_value in indices.keys():
		var role: String = _get_role_for_ball_id(int(str(ball_id_value)))
		if role.is_empty():
			role = "ball_%s" % str(ball_id_value)
		mapped[role] = int(indices[ball_id_value])
	return mapped


func _roles_use_different_pockets(roles: Array, indices_by_role: Dictionary) -> bool:
	var unique_indices: Dictionary = {}
	for role_value in roles:
		var role: String = str(role_value)
		if not indices_by_role.has(role):
			return false
		unique_indices[str(indices_by_role[role])] = true
	return roles.size() >= 2 and unique_indices.size() == roles.size()


func _roles_use_same_pocket(roles: Array, indices_by_role: Dictionary) -> bool:
	var shared_index := -1
	for role_value in roles:
		var role: String = str(role_value)
		if not indices_by_role.has(role):
			return false
		var pocket_index: int = int(indices_by_role[role])
		if shared_index < 0:
			shared_index = pocket_index
		elif pocket_index != shared_index:
			return false
	return roles.size() >= 2 and shared_index >= 0


func _get_tag_ids(derived: Dictionary) -> Array[String]:
	var tag_ids: Array[String] = []
	for tag_value in _array_value(derived, "tags"):
		if tag_value is Dictionary:
			tag_ids.append(str((tag_value as Dictionary).get("tag_id", "")))
	return tag_ids


func _sum_path_distance(points: Array) -> float:
	var total := 0.0
	for point_index in range(1, points.size()):
		if points[point_index - 1] is Vector2 and points[point_index] is Vector2:
			total += (points[point_index - 1] as Vector2).distance_to(points[point_index] as Vector2)
	return total


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


func _evaluate_ledger(ledger: Dictionary, preset: Dictionary) -> Dictionary:
	var expected: Dictionary = _dictionary_value(preset, "expected")
	var failures: Array[Dictionary] = []
	var assertion_count := 0
	var passed_count := 0
	for mode in ["exact", "minimum", "maximum"]:
		var assertions: Dictionary = _dictionary_value(expected, mode)
		for path_value in assertions.keys():
			assertion_count += 1
			var path: String = str(path_value)
			var actual: Variant = _get_observed_value(path, ledger)
			var expected_value: Variant = assertions[path_value]
			var passed: bool = _compare_assertion(mode, actual, expected_value)
			if passed:
				passed_count += 1
			else:
				failures.append(_make_failure(path, mode, expected_value, actual))

	var tag_counts: Dictionary = _dictionary_value(expected, "tag_counts")
	for tag_value in tag_counts.keys():
		assertion_count += 1
		var tag_id: String = str(tag_value)
		var actual_count: int = int(_get_observed_value("tag_counts.%s" % tag_id, ledger))
		var specification: Variant = tag_counts[tag_value]
		var passed: bool = _compare_specification(actual_count, specification)
		if passed:
			passed_count += 1
		else:
			failures.append(_make_failure("tag_counts.%s" % tag_id, "specification", specification, actual_count))

	var observed_tag_counts: Dictionary = _dictionary_value(_dictionary_value(ledger, "derived"), "tag_counts")
	for tag_value in _array_value(expected, "contains_tags"):
		assertion_count += 1
		var tag_id: String = str(tag_value)
		var actual_count: int = int(observed_tag_counts.get(tag_id, 0))
		if actual_count > 0:
			passed_count += 1
		else:
			failures.append(_make_failure("contains_tags.%s" % tag_id, "contains", true, false))
	for tag_value in _array_value(expected, "excludes_tags"):
		assertion_count += 1
		var tag_id: String = str(tag_value)
		var actual_count: int = int(observed_tag_counts.get(tag_id, 0))
		if actual_count == 0:
			passed_count += 1
		else:
			failures.append(_make_failure("excludes_tags.%s" % tag_id, "excludes", 0, actual_count))

	var array_counts: Dictionary = _dictionary_value(expected, "array_counts")
	for path_value in array_counts.keys():
		assertion_count += 1
		var path: String = str(path_value)
		var array_value: Variant = _get_observed_value(path, ledger)
		var actual_count := -1
		if array_value is Array:
			actual_count = (array_value as Array).size()
		var specification: Variant = array_counts[path_value]
		if _compare_specification(actual_count, specification):
			passed_count += 1
		else:
			failures.append(_make_failure("array_counts.%s" % path, "count", specification, actual_count))

	var role_facts: Dictionary = _dictionary_value(expected, "role_facts")
	for role_value in role_facts.keys():
		var role: String = str(role_value)
		var fact_assertions_value: Variant = role_facts[role_value]
		if not fact_assertions_value is Dictionary:
			continue
		for fact_value in (fact_assertions_value as Dictionary).keys():
			assertion_count += 1
			var fact: String = str(fact_value)
			var actual: Variant = _get_role_pocket_fact(role, fact, ledger)
			var specification: Variant = (fact_assertions_value as Dictionary)[fact_value]
			if _compare_specification(actual, specification):
				passed_count += 1
			else:
				failures.append(_make_failure("role_facts.%s.%s" % [role, fact], "specification", specification, actual))

	var travel_ranges: Dictionary = _dictionary_value(expected, "travel_ranges")
	for role_value in travel_ranges.keys():
		assertion_count += 1
		var role: String = str(role_value)
		var actual: float = _get_role_travel(role, ledger)
		var specification: Variant = travel_ranges[role_value]
		if _compare_specification(actual, specification):
			passed_count += 1
		else:
			failures.append(_make_failure("travel_ranges.%s" % role, "range", specification, actual))

	return {
		"preset_id": str(preset.get("preset_id", "")),
		"display_name": str(preset.get("display_name", "")),
		"shot_id": int(ledger.get("shot_id", -1)),
		"attempt_id": int(ledger.get("attempt_id", -1)),
		"passed": failures.is_empty() and assertion_count > 0,
		"assertions_total": assertion_count,
		"assertions_passed": passed_count,
		"assertions_failed": failures.size(),
		"failures": failures,
		"role_to_ball_id": role_to_ball_id.duplicate(true),
		"expected": expected.duplicate(true),
		"observed": _make_observed_summary(ledger),
		"ledger": ledger.duplicate(true),
	}


func _evaluate_score_expectations(score_result: Dictionary, expected_score: Dictionary) -> Dictionary:
	var failures: Array[Dictionary] = []
	var assertion_count := 0
	var passed_count := 0
	if expected_score.is_empty():
		return {
			"assertions_total": 0,
			"assertions_passed": 0,
			"assertions_failed": 0,
			"passed": true,
			"failures": [],
			"expected": {},
		}
	for key in [
		"base_haul", "final_haul", "base_mult", "mult_before_xmult",
		"xmult_product", "final_mult", "shot_score",
	]:
		if not expected_score.has(key):
			continue
		assertion_count += 1
		var expected_value: Variant = expected_score[key]
		var actual_value: Variant = score_result.get(key, null)
		if _score_values_match(actual_value, expected_value):
			passed_count += 1
		else:
			failures.append(_make_failure("score.%s" % key, "exact", expected_value, actual_value))
	var expected_source_counts: Dictionary = _dictionary_value(expected_score, "source_counts")
	var actual_source_counts: Dictionary = _get_score_source_counts(score_result)
	for source_id_value in expected_source_counts.keys():
		assertion_count += 1
		var source_id: String = str(source_id_value)
		var expected_count: int = int(expected_source_counts[source_id_value])
		var actual_count: int = int(actual_source_counts.get(source_id, 0))
		if actual_count == expected_count:
			passed_count += 1
		else:
			failures.append(_make_failure(
				"score.source_counts.%s" % source_id,
				"exact",
				expected_count,
				actual_count
			))
	return {
		"assertions_total": assertion_count,
		"assertions_passed": passed_count,
		"assertions_failed": failures.size(),
		"passed": failures.is_empty(),
		"failures": failures,
		"expected": expected_score.duplicate(true),
	}


func _merge_score_assertions_into_result(result: Dictionary, score_assertions: Dictionary) -> void:
	var failures: Array = _array_value(result, "failures")
	for failure_value in _array_value(score_assertions, "failures"):
		if failure_value is Dictionary:
			failures.append((failure_value as Dictionary).duplicate(true))
	result["failures"] = failures
	result["assertions_total"] = int(result.get("assertions_total", 0)) + int(score_assertions.get("assertions_total", 0))
	result["assertions_passed"] = int(result.get("assertions_passed", 0)) + int(score_assertions.get("assertions_passed", 0))
	result["assertions_failed"] = failures.size()
	result["passed"] = failures.is_empty() and int(result.get("assertions_total", 0)) > 0


func _compare_score_results(
	predicted: Dictionary,
	authoritative: Dictionary,
	prediction_truncated: bool,
	prediction_valid: bool
) -> Dictionary:
	if authoritative.is_empty():
		return {"status": "NOT RUN", "exact": false, "warnings": ["Authoritative score is unavailable."], "mismatches": []}
	if not prediction_valid or predicted.is_empty():
		return {"status": "WARN", "exact": false, "warnings": ["Predicted score is unavailable."], "mismatches": []}
	var mismatches: Array[Dictionary] = []
	for key in ["base_haul", "mult_before_xmult", "xmult_product", "final_mult", "shot_score"]:
		var expected_value: Variant = predicted.get(key, null)
		var actual_value: Variant = authoritative.get(key, null)
		if not _score_values_match(actual_value, expected_value):
			mismatches.append(_make_failure("score_parity.%s" % key, "exact", expected_value, actual_value))
	var predicted_sources: Dictionary = _get_score_source_counts(predicted)
	var actual_sources: Dictionary = _get_score_source_counts(authoritative)
	if predicted_sources != actual_sources:
		mismatches.append(_make_failure("score_parity.source_counts", "exact", predicted_sources, actual_sources))
	var warnings: Array[String] = []
	if prediction_truncated:
		warnings.append("Prediction was capped; its partial score is not treated as exact.")
	var status: String = "PASS"
	if prediction_truncated:
		status = "WARN"
	elif not mismatches.is_empty():
		status = "FAIL"
	return {
		"status": status,
		"exact": status == "PASS",
		"prediction_truncated": prediction_truncated,
		"mismatches": mismatches,
		"warnings": warnings,
		"predicted_source_counts": predicted_sources,
		"authoritative_source_counts": actual_sources,
	}


func _score_values_match(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) in [TYPE_INT, TYPE_FLOAT] and typeof(expected) in [TYPE_INT, TYPE_FLOAT]:
		return is_equal_approx(float(actual), float(expected))
	return actual == expected


func _get_score_source_counts(score_result: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = _dictionary_value(score_result, "diagnostics")
	return _dictionary_value(diagnostics, "source_counts").duplicate(true)


func _get_observed_value(path: String, ledger: Dictionary) -> Variant:
	var derived: Dictionary = _dictionary_value(ledger, "derived")
	if path == "unique_ball_contact_pair_count":
		return _array_value(derived, "unique_ball_contact_pairs").size()
	if path.begins_with("tag_counts."):
		return int(_dictionary_value(derived, "tag_counts").get(path.trim_prefix("tag_counts."), 0))
	return derived.get(path, null)


func _get_role_pocket_fact(role: String, fact: String, ledger: Dictionary) -> Variant:
	var ball_id: int = int(role_to_ball_id.get(role, -1))
	var derived: Dictionary = _dictionary_value(ledger, "derived")
	for fact_value in _array_value(derived, "pocket_facts"):
		if fact_value is Dictionary and int((fact_value as Dictionary).get("ball_id", -1)) == ball_id:
			return (fact_value as Dictionary).get(fact, null)
	return null


func _get_role_travel(role: String, ledger: Dictionary) -> float:
	var ball_id: int = int(role_to_ball_id.get(role, -1))
	var ending_balls: Dictionary = _dictionary_value(ledger, "ending_balls")
	var snapshot: Dictionary = _dictionary_value(ending_balls, str(ball_id))
	return float(snapshot.get("travel_distance", -1.0))


func _compare_assertion(mode: String, actual: Variant, expected: Variant) -> bool:
	match mode:
		"minimum":
			return actual != null and float(actual) >= float(expected)
		"maximum":
			return actual != null and float(actual) <= float(expected)
		_:
			return actual == expected


func _compare_specification(actual: Variant, specification: Variant) -> bool:
	if specification is Dictionary:
		var range_spec: Dictionary = specification
		if range_spec.has("exact") and actual != range_spec["exact"]:
			return false
		if range_spec.has("min") and (actual == null or float(actual) < float(range_spec["min"])):
			return false
		if range_spec.has("max") and (actual == null or float(actual) > float(range_spec["max"])):
			return false
		return true
	return actual == specification


func _make_failure(path: String, comparison: String, expected: Variant, actual: Variant) -> Dictionary:
	return {"path": path, "comparison": comparison, "expected": expected, "actual": actual}


func _make_suite_operation_failure(preset: Dictionary, reason: String) -> Dictionary:
	return {
		"preset_id": str(preset.get("preset_id", selected_preset_id)),
		"display_name": str(preset.get("display_name", selected_preset_id)),
		"passed": false,
		"assertions_total": 0,
		"assertions_passed": 0,
		"assertions_failed": 1,
		"suite_repeat_index": suite_repeat_index,
		"resolved_reference": resolved_reference.duplicate(true),
		"preflight": reference_preflight.duplicate(true),
		"failures": [{
			"path": "suite.operation",
			"comparison": "completed",
			"expected": "success",
			"actual": reason,
		}],
	}


func _make_suite_result_summary(result: Dictionary) -> Dictionary:
	var reference_attempt: Dictionary = _dictionary_value(result, "reference_attempt")
	var resolved: Dictionary = _dictionary_value(reference_attempt, "resolved_reference")
	var expected: Dictionary = _dictionary_value(result, "expected")
	var observed: Dictionary = _dictionary_value(result, "observed")
	var expected_launch_velocity: Vector2 = resolved.get("launch_velocity", Vector2.ZERO)
	var actual_launch_velocity: Vector2 = reference_attempt.get("actual_launch_velocity", Vector2.ZERO)
	var launch_speed_delta: float = float(reference_attempt.get("launch_speed_delta", INF))
	var launch_direction_dot: float = float(reference_attempt.get("launch_direction_dot", -1.0))
	var launch_speed_matches: bool = absf(launch_speed_delta) <= REFERENCE_LAUNCH_SPEED_EPSILON
	var launch_direction_matches: bool = (
		launch_direction_dot >= REFERENCE_LAUNCH_DIRECTION_DOT_MIN
	)
	var failures: Array = _array_value(result, "failures").duplicate(true)
	if not launch_speed_matches:
		failures.append(_make_failure(
			"reference.launch_speed",
			"epsilon",
			"abs(delta) <= %.6f" % REFERENCE_LAUNCH_SPEED_EPSILON,
			launch_speed_delta
		))
	if not launch_direction_matches:
		failures.append(_make_failure(
			"reference.launch_direction",
			"minimum_dot",
			REFERENCE_LAUNCH_DIRECTION_DOT_MIN,
			launch_direction_dot
		))
	return {
		"preset_id": str(result.get("preset_id", "")),
		"display_name": str(result.get("display_name", "Preset")),
		"shot_id": int(result.get("shot_id", -1)),
		"attempt_id": int(result.get("attempt_id", -1)),
		"passed": bool(result.get("passed", false)) and failures.is_empty(),
		"assertions_total": int(result.get("assertions_total", 0)),
		"assertions_passed": int(result.get("assertions_passed", 0)),
		"assertions_failed": int(result.get("assertions_failed", 0)),
		"failures": failures,
		"suite_repeat_index": int(reference_attempt.get("suite_repeat_index", suite_repeat_index)),
		"resolved_reference": resolved.duplicate(true),
		"preflight": _dictionary_value(reference_attempt, "preflight").duplicate(true),
		"actual_comparison": _dictionary_value(reference_attempt, "actual_comparison").duplicate(true),
		"expected_tags": {
			"tag_counts": _dictionary_value(expected, "tag_counts").duplicate(true),
			"contains_tags": _array_value(expected, "contains_tags").duplicate(),
			"excludes_tags": _array_value(expected, "excludes_tags").duplicate(),
		},
		"observed_tags": _array_value(observed, "tags").duplicate(true),
		"observed_tag_counts": _dictionary_value(observed, "tag_counts").duplicate(true),
		"scoring": _dictionary_value(result, "scoring").duplicate(true),
		"expected_score": _dictionary_value(loaded_preset, "expected_score").duplicate(true),
		"launch_comparison": {
			"expected_velocity": expected_launch_velocity,
			"actual_velocity": actual_launch_velocity,
			"speed_delta": launch_speed_delta,
			"direction_dot": launch_direction_dot,
			"speed_matches": launch_speed_matches,
			"direction_matches": launch_direction_matches,
			"matches": launch_speed_matches and launch_direction_matches,
		},
	}


func _reset_suite_reference_metrics(repeat_target: int) -> void:
	suite_repeat_target = maxi(repeat_target, 1)
	suite_repeat_index = 0
	suite_completed_attempts = 0
	suite_resolved_count = 0
	suite_preflight_counts = {
		PREFLIGHT_PASS: 0,
		PREFLIGHT_WARN: 0,
		PREFLIGHT_FAIL: 0,
	}
	suite_first_contact_mismatches = 0


func _record_remaining_suite_attempt_failures(
	preset: Dictionary,
	reason: String,
	failure_suffix: String
) -> void:
	var remaining_attempts: int = maxi(suite_repeat_target - suite_repeat_index, 1)
	var display_name: String = str(preset.get("display_name", selected_preset_id))
	for attempt_offset in range(remaining_attempts):
		var failed_attempt_index: int = suite_repeat_index + attempt_offset
		var failure: Dictionary = _make_suite_operation_failure(preset, reason)
		failure["suite_repeat_index"] = failed_attempt_index
		suite_results.append(failure)
		suite_failures.append("%s (attempt %d, %s)" % [
			display_name,
			failed_attempt_index + 1,
			failure_suffix,
		])
		suite_failed += 1
		suite_completed_attempts += 1
		if bool(resolved_reference.get("resolution_valid", false)):
			suite_resolved_count += 1
		var preflight_status: String = str(reference_preflight.get("status", PREFLIGHT_NOT_RUN))
		if suite_preflight_counts.has(preflight_status):
			suite_preflight_counts[preflight_status] = int(suite_preflight_counts[preflight_status]) + 1


func _make_suite_per_preset_summary() -> Dictionary:
	var summaries: Dictionary = {}
	for preset in presets:
		var preset_id: String = str(preset.get("preset_id", ""))
		summaries[preset_id] = {
			"display_name": str(preset.get("display_name", preset_id)),
			"attempts": 0,
			"passed": 0,
			"failed": 0,
			"failures": [],
			"resolved_direction_consistent": true,
			"resolved_launch_speed_consistent": true,
			"resolved_world_direction": Vector2.ZERO,
			"resolved_launch_speed": 0.0,
			"max_abs_actual_speed_delta": 0.0,
			"min_actual_direction_dot": 1.0,
			"predicted_first_contacts": [],
			"actual_first_contacts": [],
		}
	for result_value in suite_results:
		if not result_value is Dictionary:
			continue
		var result: Dictionary = result_value
		var preset_id: String = str(result.get("preset_id", ""))
		if not summaries.has(preset_id):
			continue
		var summary: Dictionary = summaries[preset_id]
		var previous_attempts: int = int(summary.get("attempts", 0))
		summary["attempts"] = int(summary.get("attempts", 0)) + 1
		var resolved: Dictionary = _dictionary_value(result, "resolved_reference")
		if bool(resolved.get("resolution_valid", false)):
			var direction: Vector2 = resolved.get("world_direction", Vector2.ZERO)
			var launch_speed: float = float(resolved.get("launch_speed", 0.0))
			if previous_attempts == 0:
				summary["resolved_world_direction"] = direction
				summary["resolved_launch_speed"] = launch_speed
			else:
				var first_direction: Vector2 = summary.get("resolved_world_direction", Vector2.ZERO)
				var first_speed: float = float(summary.get("resolved_launch_speed", 0.0))
				if not direction.is_equal_approx(first_direction):
					summary["resolved_direction_consistent"] = false
				if not is_equal_approx(launch_speed, first_speed):
					summary["resolved_launch_speed_consistent"] = false
		var launch_comparison: Dictionary = _dictionary_value(result, "launch_comparison")
		if not launch_comparison.is_empty():
			summary["max_abs_actual_speed_delta"] = maxf(
				float(summary.get("max_abs_actual_speed_delta", 0.0)),
				absf(float(launch_comparison.get("speed_delta", 0.0)))
			)
			summary["min_actual_direction_dot"] = minf(
				float(summary.get("min_actual_direction_dot", 1.0)),
				float(launch_comparison.get("direction_dot", 1.0))
			)
		var actual_comparison: Dictionary = _dictionary_value(result, "actual_comparison")
		var predicted_contacts: Array = summary.get("predicted_first_contacts", [])
		predicted_contacts.append(str(actual_comparison.get("predicted_first_contact_role", "none")))
		summary["predicted_first_contacts"] = predicted_contacts
		var actual_contacts: Array = summary.get("actual_first_contacts", [])
		actual_contacts.append(str(actual_comparison.get("actual_first_contact_role", "none")))
		summary["actual_first_contacts"] = actual_contacts
		if bool(result.get("passed", false)):
			summary["passed"] = int(summary.get("passed", 0)) + 1
		else:
			summary["failed"] = int(summary.get("failed", 0)) + 1
			var failures: Array = summary.get("failures", [])
			failures.append({
				"attempt": int(result.get("suite_repeat_index", 0)) + 1,
				"details": _array_value(result, "failures").duplicate(true),
			})
		summaries[preset_id] = summary
	return summaries


func _can_edit_reference() -> bool:
	if not active or loaded_preset.is_empty() or suite_running or _is_authoritative_shot_active():
		status_changed.emit("Shot Lab: reference authoring is locked during an active test.")
		return false
	return true


func _format_reference_as_gdscript(reference: Dictionary) -> String:
	var ordered_keys: Array[String] = [
		"enabled",
		"aim_type",
		"aim_role",
		"aim_point",
		"pocket_index",
		"pocket_name",
		"world_direction",
		"aim_offset_world",
		"power_normalized",
		"preflight",
	]
	var lines: Array[String] = ["{"]
	for key in ordered_keys:
		if reference.has(key):
			lines.append("\t\"%s\": %s," % [key, _format_gdscript_value(reference[key], 1)])
	lines.append("}")
	return "\n".join(lines)


func _format_gdscript_value(value: Variant, indent_level: int = 0) -> String:
	if value is Vector2:
		return "Vector2(%.4f, %.4f)" % [value.x, value.y]
	if value is String:
		return "\"%s\"" % str(value).replace("\"", "\\\"")
	if value is bool:
		return "true" if value else "false"
	if value is Dictionary:
		var dictionary: Dictionary = value
		var dictionary_parts: Array[String] = []
		for key_value in dictionary.keys():
			dictionary_parts.append("\"%s\": %s" % [
				str(key_value),
				_format_gdscript_value(dictionary[key_value], indent_level + 1),
			])
		return "{%s}" % ", ".join(dictionary_parts)
	if value is Array:
		var array_parts: Array[String] = []
		for item in value:
			array_parts.append(_format_gdscript_value(item, indent_level + 1))
		return "[%s]" % ", ".join(array_parts)
	return str(value)


func _make_observed_summary(ledger: Dictionary) -> Dictionary:
	var derived: Dictionary = _dictionary_value(ledger, "derived")
	var raw_events: Array = _array_value(ledger, "raw_events")
	return {
		"raw_event_count": raw_events.size(),
		"raw_events": raw_events.slice(0, mini(raw_events.size(), 128)),
		"tags": _array_value(derived, "tags").duplicate(true),
		"tag_counts": _dictionary_value(derived, "tag_counts").duplicate(true),
		"pocket_facts": _array_value(derived, "pocket_facts").duplicate(true),
		"object_ball_pocket_count": int(derived.get("object_ball_pocket_count", 0)),
		"scratch_occurred": bool(derived.get("scratch_occurred", false)),
		"semantic_ball_contact_count": int(derived.get("semantic_ball_contact_count", 0)),
		"semantic_rail_contact_count": int(derived.get("semantic_rail_contact_count", 0)),
		"maximum_causal_depth": int(derived.get("maximum_causal_depth", 0)),
	}


func _make_not_run_result(preset: Dictionary) -> Dictionary:
	return {
		"preset_id": str(preset.get("preset_id", "")),
		"display_name": str(preset.get("display_name", "")),
		"passed": false,
		"status": "NOT RUN",
		"assertions_total": 0,
		"assertions_passed": 0,
		"assertions_failed": 0,
		"failures": [],
	}


func _fail_load(message: String) -> bool:
	last_load_error = message
	status_changed.emit("Shot Lab setup invalid: %s" % message)
	_emit_state()
	return false


func _normalized_to_world(normalized: Vector2) -> Vector2:
	return table.playfield_rect.position + normalized * table.playfield_rect.size


func _world_to_normalized(world_position: Vector2) -> Vector2:
	if table.playfield_rect.size.x <= 0.0 or table.playfield_rect.size.y <= 0.0:
		return Vector2.ZERO
	return (world_position - table.playfield_rect.position) / table.playfield_rect.size


func _get_role_for_ball_id(ball_id: int) -> String:
	if ball_id <= 0:
		return ""
	for role_value in role_to_ball_id.keys():
		if int(role_to_ball_id[role_value]) == ball_id:
			return str(role_value)
	return "ball_%d" % ball_id


func _is_authoritative_shot_active() -> bool:
	return table != null and table.shot_active


func _get_suite_current_preset_name() -> String:
	if presets.is_empty():
		return ""
	var current_index: int = mini(suite_index, presets.size() - 1)
	if current_index < 0:
		return ""
	return str(presets[current_index].get("display_name", presets[current_index].get("preset_id", "Preset")))


func capture_rewind_state() -> Dictionary:
	return {
		"last_result": last_result.duplicate(true),
		"last_reference_fired": last_reference_fired,
		"active_reference_attempt": active_reference_attempt.duplicate(true),
		"reference_preflight": reference_preflight.duplicate(true),
		"reference_prediction_commit_bundle": reference_prediction_commit_bundle.duplicate(true),
		"reference_preflight_generation": reference_preflight_generation,
	}


func restore_rewind_state(state: Dictionary) -> void:
	last_result = _dictionary_value(state, "last_result").duplicate(true)
	last_reference_fired = bool(state.get("last_reference_fired", false))
	active_reference_attempt = _dictionary_value(state, "active_reference_attempt").duplicate(true)
	reference_preflight = _dictionary_value(state, "reference_preflight").duplicate(true)
	reference_prediction_commit_bundle = _dictionary_value(
		state,
		"reference_prediction_commit_bundle"
	).duplicate(true)
	reference_preflight_generation = int(state.get("reference_preflight_generation", 0))


func restore_completed_observation_after_rewind(state: Dictionary) -> void:
	restore_rewind_state(state)
	_emit_state()


func _is_scoring_modifier_mode_valid(mode_id: String) -> bool:
	for choice_value in SCORING_MODIFIER_CHOICES:
		if choice_value is Dictionary and str((choice_value as Dictionary).get("value", "")) == mode_id:
			return true
	return false


func _get_scoring_modifier_label(mode_id: String) -> String:
	for choice_value in SCORING_MODIFIER_CHOICES:
		if choice_value is Dictionary and str((choice_value as Dictionary).get("value", "")) == mode_id:
			return str((choice_value as Dictionary).get("label", mode_id))
	return mode_id


func _get_scoring_test_modifiers() -> Array[Dictionary]:
	var modifiers: Array[Dictionary] = []
	if scoring_test_modifier_mode in [SCORING_MODIFIER_ADD_HAUL, SCORING_MODIFIER_ALL]:
		modifiers.append(_make_scoring_test_modifier(
			"debug_add_haul_20", "Debug +20 Haul", "add_haul", 0, 20
		))
	if scoring_test_modifier_mode in [SCORING_MODIFIER_ADD_MULT, SCORING_MODIFIER_ALL]:
		modifiers.append(_make_scoring_test_modifier(
			"debug_add_mult_3", "Debug +3 Mult", "add_mult", 1, 3.0
		))
	if scoring_test_modifier_mode in [SCORING_MODIFIER_XMULT_1_5, SCORING_MODIFIER_ALL]:
		modifiers.append(_make_scoring_test_modifier(
			"debug_xmult_1_5", "Debug x1.5 Mult", "xmult", 2, 1.5
		))
	if scoring_test_modifier_mode in [SCORING_MODIFIER_XMULT_2, SCORING_MODIFIER_ALL]:
		modifiers.append(_make_scoring_test_modifier(
			"debug_xmult_2", "Debug x2 Mult", "xmult", 3, 2.0
		))
	return modifiers


func _get_active_score_expectations() -> Dictionary:
	if scoring_test_modifier_mode != SCORING_MODIFIER_NONE:
		return {}
	return _dictionary_value(loaded_preset, "expected_score").duplicate(true)


func _make_scoring_test_modifier(
	modifier_id: String,
	display_name: String,
	phase: String,
	slot_index: int,
	value: Variant
) -> Dictionary:
	return {
		"modifier_id": modifier_id,
		"display_name": display_name,
		"phase": phase,
		"slot_index": slot_index,
		"enabled": true,
		"conditions": {},
		"value": value,
	}


func _sync_scoring_modifier_context() -> void:
	if table != null and table.roguelite_scoring_system != null:
		table.roguelite_scoring_system.set_shot_lab_test_modifiers(_get_scoring_test_modifiers())


func _format_mult(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value, round(value)) else "%.2f" % value


func _emit_state() -> void:
	state_changed.emit(get_snapshot())


func _draw() -> void:
	if not active or not bool(options.get("show_reference_aim", true)) or loaded_preset.is_empty():
		return
	if table == null or not bool(resolved_reference.get("resolution_valid", false)):
		return
	var cue: Ball = _get_authoritative_role_ball("cue")
	if cue == null:
		return
	var start: Vector2 = to_local(cue.global_position)
	var aim_world: Vector2 = resolved_reference.get("aim_world_position", cue.global_position)
	var finish: Vector2 = to_local(aim_world)
	var direction: Vector2 = resolved_reference.get("world_direction", Vector2.ZERO)
	var status: String = str(reference_preflight.get("status", PREFLIGHT_NOT_RUN))
	var line_color: Color = Color(0.36, 0.94, 0.87, 0.86)
	if status == PREFLIGHT_WARN:
		line_color = Color(0.95, 0.68, 0.28, 0.90)
	elif status == PREFLIGHT_FAIL:
		line_color = Color(0.95, 0.31, 0.28, 0.92)
	draw_dashed_line(start, finish, line_color, 2.0, 10.0, true)
	draw_circle(finish, 5.0, line_color, false, 1.5)
	var power_percent: int = roundi(float(resolved_reference.get("power_normalized", 0.0)) * 100.0)
	var label_position: Vector2 = start + direction * 44.0 + Vector2(0.0, -24.0)
	var expected_first: String = str(reference_preflight.get("expected_first_contact_role", "none"))
	var predicted_first: String = str(reference_preflight.get("predicted_first_contact_role", "none"))
	draw_string(UI_FONT, label_position, "REFERENCE %d%% - %s" % [power_percent, status], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.92, 0.82, 0.48, 0.95))
	draw_string(UI_FONT, label_position + Vector2(0.0, 15.0), "Target: %s" % expected_first, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, line_color)
	draw_string(UI_FONT, label_position + Vector2(0.0, 29.0), "Predicted First: %s" % predicted_first, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, line_color)


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


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
