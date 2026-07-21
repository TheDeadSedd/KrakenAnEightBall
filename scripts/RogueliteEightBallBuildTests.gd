extends SceneTree

# Standalone pure regression harness for the Phase 4 Eight Ball build pipeline.
# Run with:
# godot4 --headless --path <project> --script res://scripts/RogueliteEightBallBuildTests.gd
#
# Integration API assumptions are intentionally isolated in the adapter helpers
# near the bottom of this file. Preferred production APIs are:
# - RogueliteEightBallCatalog.get_all_definitions() -> Array[Dictionary]
# - RogueliteScoringTriggerEvaluator.evaluate(analyzed_ledger) -> Array[Dictionary]
# - RogueliteBuildSystem.set_shot_lab_loadout(item_ids) or acquire_eight_ball(item_id)
# - RogueliteBuildSystem.build_modifier_context(trigger_occurrences) -> Array[Dictionary]
# - RogueliteBuildSystem.get_build_snapshot() -> Dictionary
# Catalog and trigger evaluation call those exact APIs. Build helpers accept a
# few semantically equivalent public names so inventory wiring can integrate
# without weakening any scoring or lifecycle assertion.

const CATALOG_SCRIPT := preload("res://scripts/RogueliteEightBallCatalog.gd")
const TRIGGER_EVALUATOR_SCRIPT := preload(
	"res://scripts/RogueliteScoringTriggerEvaluator.gd"
)
const BUILD_SYSTEM_SCRIPT := preload("res://scripts/RogueliteBuildSystem.gd")
const REWARD_SYSTEM_SCRIPT := preload("res://scripts/RogueliteRewardSystem.gd")
const SCORING_SYSTEM_SCRIPT := preload("res://scripts/RogueliteScoringSystem.gd")
const RESOLVER_SCRIPT := preload("res://scripts/RogueliteScoreResolver.gd")
const ANALYZER_SCRIPT := preload("res://scripts/ShotLedgerAnalyzer.gd")

const EXPECTED_CATALOG_SIZE := 22
const EXPECTED_TRAY_CAPACITY := 5
const FLOAT_EPSILON := 0.0001

const SINGLE_HAUL := "single_bank_haul_crooked_coin"
const SINGLE_MULT := "single_bank_mult_first_toll"
const SINGLE_XMULT := "single_bank_xmult_rogue_current"
const DOUBLE_HAUL := "double_bank_haul_twin_tribute"
const DOUBLE_MULT := "double_bank_mult_second_bell"
const DOUBLE_XMULT := "double_bank_xmult_crossed_tides"
const TRIPLE_HAUL := "triple_bank_haul_threefold_plunder"
const TRIPLE_MULT := "triple_bank_mult_third_toll"
const TRIPLE_XMULT := "triple_bank_xmult_krakens_trine"
const COMBO_HAUL := "combination_haul_shared_spoils"
const COMBO_MULT := "combination_mult_chain_of_command"
const COMBO_XMULT := "combination_xmult_conspirators_cut"
const DIRECT_HAUL := "direct_pot_haul_clean_plunder"
const DIRECT_MULT := "direct_pot_mult_true_bearing"
const DIRECT_XMULT := "direct_pot_xmult_unerring_course"
const DEAD_RECKONING := "direct_pot_legendary_dead_reckoning"
const MULTI_HAUL := "multi_pot_haul_loaded_hold"
const MULTI_MULT := "multi_pot_mult_all_hands"
const MULTI_XMULT := "multi_pot_xmult_broadside_dividend"
const SAME_HAUL := "same_pocket_haul_shared_grave"
const SAME_MULT := "same_pocket_mult_feeding_frenzy"
const SAME_XMULT := "same_pocket_xmult_the_maw_below"

const TRIGGER_SINGLE := "single_bank_milestone"
const TRIGGER_DOUBLE := "double_bank_milestone"
const TRIGGER_TRIPLE := "triple_bank_milestone"
const TRIGGER_COMBINATION := "combination_pot"
const TRIGGER_DIRECT := "direct_pot"
const TRIGGER_MULTI := "multi_pot_shot"
const TRIGGER_SAME_POCKET := "same_pocket_streak"

const EXPECTED_DEFINITIONS := {
	SINGLE_HAUL: {
		"trigger_id": TRIGGER_SINGLE,
		"modifier_phase": "add_haul",
		"value": 10,
		"rarity": "common",
	},
	SINGLE_MULT: {
		"trigger_id": TRIGGER_SINGLE,
		"modifier_phase": "add_mult",
		"value": 1,
		"rarity": "uncommon",
	},
	SINGLE_XMULT: {
		"trigger_id": TRIGGER_SINGLE,
		"modifier_phase": "xmult",
		"value": 1.25,
		"rarity": "rare",
	},
	DOUBLE_HAUL: {
		"trigger_id": TRIGGER_DOUBLE,
		"modifier_phase": "add_haul",
		"value": 15,
		"rarity": "common",
	},
	DOUBLE_MULT: {
		"trigger_id": TRIGGER_DOUBLE,
		"modifier_phase": "add_mult",
		"value": 2,
		"rarity": "uncommon",
	},
	DOUBLE_XMULT: {
		"trigger_id": TRIGGER_DOUBLE,
		"modifier_phase": "xmult",
		"value": 1.5,
		"rarity": "rare",
	},
	TRIPLE_HAUL: {
		"trigger_id": TRIGGER_TRIPLE,
		"modifier_phase": "add_haul",
		"value": 25,
		"rarity": "common",
	},
	TRIPLE_MULT: {
		"trigger_id": TRIGGER_TRIPLE,
		"modifier_phase": "add_mult",
		"value": 3,
		"rarity": "uncommon",
	},
	TRIPLE_XMULT: {
		"trigger_id": TRIGGER_TRIPLE,
		"modifier_phase": "xmult",
		"value": 2.0,
		"rarity": "rare",
	},
	COMBO_HAUL: {
		"trigger_id": TRIGGER_COMBINATION,
		"modifier_phase": "add_haul",
		"value": 10,
		"rarity": "common",
	},
	COMBO_MULT: {
		"trigger_id": TRIGGER_COMBINATION,
		"modifier_phase": "add_mult",
		"value": 2,
		"rarity": "uncommon",
	},
	COMBO_XMULT: {
		"trigger_id": TRIGGER_COMBINATION,
		"modifier_phase": "xmult",
		"value": 1.5,
		"rarity": "rare",
	},
	DIRECT_HAUL: {
		"trigger_id": TRIGGER_DIRECT,
		"modifier_phase": "add_haul",
		"value": 10,
		"rarity": "common",
	},
	DIRECT_MULT: {
		"trigger_id": TRIGGER_DIRECT,
		"modifier_phase": "add_mult",
		"value": 1,
		"rarity": "uncommon",
	},
	DIRECT_XMULT: {
		"trigger_id": TRIGGER_DIRECT,
		"modifier_phase": "xmult",
		"value": 1.25,
		"rarity": "rare",
	},
	DEAD_RECKONING: {
		"trigger_id": TRIGGER_DIRECT,
		"effect_kind": "retrigger_family",
		"retrigger_family": "direct_pot",
		"retrigger_count": 1,
		"rarity": "legendary",
		"offer_weight": 8,
	},
	MULTI_HAUL: {
		"trigger_id": TRIGGER_MULTI,
		"modifier_phase": "add_haul",
		"value": 20,
		"rarity": "common",
	},
	MULTI_MULT: {
		"trigger_id": TRIGGER_MULTI,
		"modifier_phase": "add_mult",
		"value": 2,
		"rarity": "uncommon",
	},
	MULTI_XMULT: {
		"trigger_id": TRIGGER_MULTI,
		"modifier_phase": "xmult",
		"value": 1.5,
		"rarity": "rare",
	},
	SAME_HAUL: {
		"trigger_id": TRIGGER_SAME_POCKET,
		"modifier_phase": "add_haul",
		"value": 25,
		"rarity": "common",
	},
	SAME_MULT: {
		"trigger_id": TRIGGER_SAME_POCKET,
		"modifier_phase": "add_mult",
		"value": 3,
		"rarity": "uncommon",
	},
	SAME_XMULT: {
		"trigger_id": TRIGGER_SAME_POCKET,
		"modifier_phase": "xmult",
		"value": 1.75,
		"rarity": "rare",
	},
}

static var _cases: Array[Dictionary] = []
static var _api_notes: Array[String] = []


func _init() -> void:
	call_deferred("_run_cli")


func _run_cli() -> void:
	var report: Dictionary = run_all()
	print(_format_report(report))
	quit(0 if int(report.get("failed", 0)) == 0 else 1)


static func run_all() -> Dictionary:
	_cases.clear()
	_api_notes.clear()
	_test_catalog_contract()
	_test_trigger_evaluator_contract()
	_test_all_single_item_scores()
	_test_cumulative_bank_scores()
	_test_family_trio_scores()
	_test_multiple_occurrences()
	_test_modifier_ordering()
	_test_predicted_authoritative_parity()
	_test_inventory_semantics_if_available()
	_test_build_lifecycle_and_mode_scope()
	_test_reward_offer_and_replacement_flow()
	_test_phase5b_trigger_contract()
	_test_phase5b_exact_scores()
	_test_dead_reckoning_contract()
	_test_phase5b_overlap_contract()
	_test_phase5b_reward_contract()

	var passed: int = 0
	var failures: Array[Dictionary] = []
	for case_result in _cases:
		if bool(case_result.get("passed", false)):
			passed += 1
		else:
			failures.append(case_result.duplicate(true))
	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"timestamp": Time.get_datetime_string_from_system(),
		"total": _cases.size(),
		"passed": passed,
		"failed": failures.size(),
		"cases": _cases.duplicate(true),
		"failures": failures,
		"api_notes": _api_notes.duplicate(),
	}


# Public self-test entry used by integration runners. The standalone CLI calls
# the same implementation, so there is one result schema and one set of cases:
# {
#   "status": "PASS" | "FAIL",
#   "timestamp": String,
#   "total": int,
#   "passed": int,
#   "failed": int,
#   "cases": Array[{"name", "passed", "expected", "actual"}],
#   "failures": Array[failed case Dictionaries],
#   "api_notes": Array[String],
# }
static func run_self_tests() -> Dictionary:
	return run_all()


static func _test_catalog_contract() -> void:
	var definitions: Array[Dictionary] = _get_catalog_definitions()
	var ids: Array[String] = []
	var duplicates: Array[String] = []
	var actual_by_id: Dictionary = {}
	for definition in definitions:
		var item_id: String = str(definition.get("eight_ball_item_id", ""))
		if item_id in ids:
			duplicates.append(item_id)
		ids.append(item_id)
		actual_by_id[item_id] = definition
	_record_case(
		"Catalog has exactly 22 unique definitions",
		definitions.size() == EXPECTED_CATALOG_SIZE
			and ids.size() == EXPECTED_CATALOG_SIZE
			and duplicates.is_empty(),
		{"count": EXPECTED_CATALOG_SIZE, "unique": true},
		{"count": definitions.size(), "ids": ids, "duplicates": duplicates}
	)

	var field_failures: Array[Dictionary] = []
	for item_id_value in EXPECTED_DEFINITIONS.keys():
		var item_id: String = str(item_id_value)
		var expected: Dictionary = EXPECTED_DEFINITIONS[item_id]
		var actual: Dictionary = _dictionary_value(actual_by_id, item_id)
		if actual.is_empty():
			field_failures.append({"item_id": item_id, "missing": true})
			continue
		for field_value in expected.keys():
			var field: String = str(field_value)
			if not _values_equal(actual.get(field), expected[field]):
				field_failures.append({
					"item_id": item_id,
					"field": field,
					"expected": expected[field],
					"actual": actual.get(field),
				})
		for required_field in [
			"display_name", "family_id", "short_effect", "tooltip", "offer_weight",
		]:
			if not actual.has(required_field) or str(actual.get(required_field, "")).is_empty():
				field_failures.append({
					"item_id": item_id,
					"field": required_field,
					"expected": "non-empty",
					"actual": actual.get(required_field),
				})
	_record_case(
		"Catalog definitions match authored trigger, phase, value, and rarity",
		field_failures.is_empty(),
		EXPECTED_DEFINITIONS,
		{"field_failures": field_failures}
	)
	var family_counts: Dictionary = {}
	var legendary_count: int = 0
	for definition in definitions:
		var family_id: String = str(definition.get("family_id", ""))
		family_counts[family_id] = int(family_counts.get(family_id, 0)) + 1
		if str(definition.get("rarity", "")) == "legendary":
			legendary_count += 1
	var expected_family_counts: Dictionary = {
		"single_bank": 3,
		"double_bank": 3,
		"triple_bank": 3,
		"combination": 3,
		"direct_pot": 4,
		"multi_pot": 3,
		"same_pocket": 3,
	}
	_record_case(
		"Catalog family composition is 9 Bank, 3 Combination, 4 Direct, 3 Multi, 3 Same-Pocket",
		_dictionaries_equal(family_counts, expected_family_counts)
			and legendary_count == 1,
		{"families": expected_family_counts, "legendary_count": 1},
		{"families": family_counts, "legendary_count": legendary_count}
	)


static func _test_trigger_evaluator_contract() -> void:
	var one_bank: Array[Dictionary] = _evaluate_triggers(_make_ledger([
		_make_fact(2, 1, 1, false, 10),
	]))
	_record_trigger_case(
		"One bank emits Single Bank once",
		one_bank,
		{TRIGGER_SINGLE: 1}
	)

	var double_bank: Array[Dictionary] = _evaluate_triggers(_make_ledger([
		_make_fact(2, 1, 2, false, 20),
	]))
	_record_trigger_case(
		"Double Bank emits cumulative Single and Double milestones",
		double_bank,
		{TRIGGER_SINGLE: 1, TRIGGER_DOUBLE: 1}
	)

	var triple_combo_ledger: Dictionary = _make_ledger([
		_make_fact(7, 1, 3, true, 30),
	])
	var triple_combo: Array[Dictionary] = _evaluate_triggers(triple_combo_ledger)
	_record_trigger_case(
		"Triple Bank Combination overlaps all four trigger families",
		triple_combo,
		{
			TRIGGER_SINGLE: 1,
			TRIGGER_DOUBLE: 1,
			TRIGGER_TRIPLE: 1,
			TRIGGER_COMBINATION: 1,
		}
	)
	var expected_indices: Dictionary = {
		TRIGGER_SINGLE: 31,
		TRIGGER_DOUBLE: 32,
		TRIGGER_TRIPLE: 33,
		TRIGGER_COMBINATION: 29,
	}
	var index_failures: Array[Dictionary] = []
	for occurrence in triple_combo:
		var trigger_id: String = str(occurrence.get("trigger_id", ""))
		if expected_indices.has(trigger_id):
			var actual_index: int = _occurrence_event_index(occurrence)
			if actual_index != int(expected_indices[trigger_id]):
				index_failures.append({
					"trigger_id": trigger_id,
					"expected": expected_indices[trigger_id],
					"actual": actual_index,
				})
	_record_case(
		"Trigger occurrences retain exact milestone and causal event indices",
		index_failures.is_empty() and triple_combo.size() == 4,
		expected_indices,
		{"occurrences": triple_combo, "failures": index_failures}
	)


static func _test_all_single_item_scores() -> void:
	var cases: Array[Dictionary] = [
		{"name": "Crooked Coin / one bank", "item": SINGLE_HAUL, "bank": 1, "combo": false, "score": 40, "haul": 20, "mult": 2.0},
		{"name": "First Toll / one bank", "item": SINGLE_MULT, "bank": 1, "combo": false, "score": 30, "haul": 10, "mult": 3.0},
		{"name": "Rogue Current / one bank", "item": SINGLE_XMULT, "bank": 1, "combo": false, "score": 25, "haul": 10, "mult": 2.5},
		{"name": "Twin Tribute / double bank", "item": DOUBLE_HAUL, "bank": 2, "combo": false, "score": 75, "haul": 25, "mult": 3.0},
		{"name": "Second Bell / double bank", "item": DOUBLE_MULT, "bank": 2, "combo": false, "score": 50, "haul": 10, "mult": 5.0},
		{"name": "Crossed Tides / double bank", "item": DOUBLE_XMULT, "bank": 2, "combo": false, "score": 45, "haul": 10, "mult": 4.5},
		{"name": "Threefold Plunder / triple bank", "item": TRIPLE_HAUL, "bank": 3, "combo": false, "score": 140, "haul": 35, "mult": 4.0},
		{"name": "Third Toll / triple bank", "item": TRIPLE_MULT, "bank": 3, "combo": false, "score": 70, "haul": 10, "mult": 7.0},
		{"name": "Kraken's Trine / triple bank", "item": TRIPLE_XMULT, "bank": 3, "combo": false, "score": 80, "haul": 10, "mult": 8.0},
		{"name": "Shared Spoils / combination", "item": COMBO_HAUL, "bank": 0, "combo": true, "score": 40, "haul": 20, "mult": 2.0},
		{"name": "Chain of Command / combination", "item": COMBO_MULT, "bank": 0, "combo": true, "score": 40, "haul": 10, "mult": 4.0},
		{"name": "Conspirator's Cut / combination", "item": COMBO_XMULT, "bank": 0, "combo": true, "score": 30, "haul": 10, "mult": 3.0},
	]
	for case_data in cases:
		_run_score_case(
			"Single item: %s" % str(case_data.get("name", "unknown")),
			[_string_value(case_data, "item")],
			[_make_fact(2, 1, int(case_data.get("bank", 0)), bool(case_data.get("combo", false)), 100)],
			int(case_data.get("score", -1)),
			int(case_data.get("haul", -1)),
			float(case_data.get("mult", -1.0))
		)


static func _test_cumulative_bank_scores() -> void:
	_run_score_case(
		"Cumulative: Double Bank triggers Crooked Coin",
		[SINGLE_HAUL],
		[_make_fact(2, 1, 2, false, 200)],
		60, 20, 3.0
	)
	_run_score_case(
		"Cumulative: Triple Bank with all Haul milestones",
		[SINGLE_HAUL, DOUBLE_HAUL, TRIPLE_HAUL],
		[_make_fact(2, 1, 3, false, 210)],
		240, 60, 4.0
	)
	_run_score_case(
		"Cumulative: Triple Bank with all additive Mult milestones",
		[SINGLE_MULT, DOUBLE_MULT, TRIPLE_MULT],
		[_make_fact(2, 1, 3, false, 220)],
		100, 10, 10.0
	)
	_run_score_case(
		"Cumulative: Triple Bank with all xMult milestones",
		[SINGLE_XMULT, DOUBLE_XMULT, TRIPLE_XMULT],
		[_make_fact(2, 1, 3, false, 230)],
		150, 10, 15.0
	)


static func _test_family_trio_scores() -> void:
	_run_score_case(
		"Family trio: Single Bank",
		[SINGLE_HAUL, SINGLE_MULT, SINGLE_XMULT],
		[_make_fact(2, 1, 1, false, 300)],
		75, 20, 3.75
	)
	_run_score_case(
		"Family trio: Double Bank",
		[DOUBLE_HAUL, DOUBLE_MULT, DOUBLE_XMULT],
		[_make_fact(2, 1, 2, false, 310)],
		187, 25, 7.5
	)
	_run_score_case(
		"Family trio: Triple Bank",
		[TRIPLE_HAUL, TRIPLE_MULT, TRIPLE_XMULT],
		[_make_fact(2, 1, 3, false, 320)],
		490, 35, 14.0
	)
	_run_score_case(
		"Family trio: Combination",
		[COMBO_HAUL, COMBO_MULT, COMBO_XMULT],
		[_make_fact(2, 1, 0, true, 330)],
		120, 20, 6.0
	)


static func _test_multiple_occurrences() -> void:
	var two_banks: Dictionary = _run_score_pipeline(
		[SINGLE_HAUL],
		[
			_make_fact(2, 1, 1, false, 400),
			_make_fact(3, 2, 1, false, 410),
		]
	)
	_record_pipeline_case(
		"Multiple occurrences: two Single Banks activate Crooked Coin twice",
		two_banks,
		160,
		{TRIGGER_SINGLE: 2, TRIGGER_MULTI: 1},
		{SINGLE_HAUL: 2}
	)

	var two_combinations: Dictionary = _run_score_pipeline(
		[COMBO_XMULT],
		[
			_make_fact(2, 1, 0, true, 420),
			_make_fact(3, 2, 0, true, 430),
		]
	)
	_record_pipeline_case(
		"Multiple occurrences: two Combinations compound x1.5 twice",
		two_combinations,
		180,
		{TRIGGER_COMBINATION: 2, TRIGGER_MULTI: 1},
		{COMBO_XMULT: 2}
	)

	var bank_combo: Dictionary = _run_score_pipeline(
		[SINGLE_HAUL, COMBO_HAUL],
		[_make_fact(7, 1, 2, true, 440)]
	)
	_record_pipeline_case(
		"Overlap: Double Bank Combination activates Bank and Combination families",
		bank_combo,
		120,
		{TRIGGER_SINGLE: 1, TRIGGER_DOUBLE: 1, TRIGGER_COMBINATION: 1},
		{SINGLE_HAUL: 1, COMBO_HAUL: 1}
	)

	var triple_combo: Dictionary = _run_score_pipeline(
		[SINGLE_HAUL, DOUBLE_HAUL, TRIPLE_HAUL, COMBO_HAUL],
		[_make_fact(8, 1, 3, true, 450)]
	)
	_record_pipeline_case(
		"Overlap: Triple Bank Combination activates all four trigger IDs",
		triple_combo,
		350,
		{
			TRIGGER_SINGLE: 1,
			TRIGGER_DOUBLE: 1,
			TRIGGER_TRIPLE: 1,
			TRIGGER_COMBINATION: 1,
		},
		{SINGLE_HAUL: 1, DOUBLE_HAUL: 1, TRIPLE_HAUL: 1, COMBO_HAUL: 1}
	)


static func _test_modifier_ordering() -> void:
	var pipeline: Dictionary = _run_score_pipeline(
		[TRIPLE_XMULT, COMBO_MULT, SINGLE_HAUL, SINGLE_XMULT, COMBO_HAUL],
		[_make_fact(9, 1, 3, true, 500)]
	)
	var score_result: Dictionary = _dictionary_value(pipeline, "score_result")
	var actual_order: Array[String] = _modifier_source_order(score_result)
	var expected_order: Array[String] = [
		SINGLE_HAUL,
		COMBO_HAUL,
		COMBO_MULT,
		TRIPLE_XMULT,
		SINGLE_XMULT,
	]
	_record_case(
		"Modifier phases and tray slots resolve deterministically",
		actual_order == expected_order,
		expected_order,
		{
			"order": actual_order,
			"modifier_context": pipeline.get("modifiers", []),
		}
	)

	var repeated: Dictionary = _run_score_pipeline(
		[SINGLE_HAUL],
		[
			_make_fact(12, 2, 1, false, 530),
			_make_fact(11, 1, 1, false, 510),
		]
	)
	var repeated_modifiers: Array[Dictionary] = _dictionary_array_value(repeated, "modifiers")
	var event_indices: Array[int] = []
	var occurrence_ids: Array[String] = []
	for modifier in repeated_modifiers:
		event_indices.append(_modifier_trigger_event_index(modifier))
		occurrence_ids.append(str(modifier.get("trigger_occurrence_id", "")))
	var unique_occurrence_ids: Dictionary = {}
	for occurrence_id in occurrence_ids:
		unique_occurrence_ids[occurrence_id] = true
	_record_case(
		"Same-slot occurrences order by event index and stable occurrence ID",
		event_indices == [511, 531]
			and unique_occurrence_ids.size() == 2
			and not occurrence_ids.has(""),
		{"event_indices": [511, 531], "unique_occurrence_ids": 2},
		{"event_indices": event_indices, "occurrence_ids": occurrence_ids}
	)


static func _test_predicted_authoritative_parity() -> void:
	var facts: Array[Dictionary] = [
		_make_fact(2, 1, 3, true, 600),
		_make_fact(3, 2, 1, true, 620),
	]
	var loadout: Array[String] = [
		SINGLE_HAUL,
		DOUBLE_MULT,
		TRIPLE_XMULT,
		COMBO_HAUL,
		COMBO_XMULT,
	]
	var predicted: Dictionary = _run_score_pipeline(loadout, facts, "predicted")
	var authoritative: Dictionary = _run_score_pipeline(loadout, facts, "authoritative")
	var predicted_result: Dictionary = _dictionary_value(predicted, "score_result")
	var actual_result: Dictionary = _dictionary_value(authoritative, "score_result")
	var expected_equal: bool = _score_results_equal(predicted_result, actual_result)
	_record_case(
		"Predicted and authoritative ledgers use identical build scoring",
		expected_equal,
		{"same_score_breakdown": true},
		{
			"same_score_breakdown": expected_equal,
			"predicted": _score_summary(predicted_result),
			"authoritative": _score_summary(actual_result),
			"predicted_trigger_counts": _trigger_counts(_dictionary_array_value(predicted, "occurrences")),
			"authoritative_trigger_counts": _trigger_counts(_dictionary_array_value(authoritative, "occurrences")),
		}
	)


static func _test_inventory_semantics_if_available() -> void:
	var build: Variant = BUILD_SYSTEM_SCRIPT.new()
	var acquisition_method: String = _find_method_name(build, [
		"acquire_eight_ball", "try_acquire_eight_ball", "acquire_build_item",
	])
	var replacement_method: String = _find_method_name(build, [
		"replace_eight_ball", "replace_build_item", "replace_tray_slot",
	])
	var snapshot_method: String = _find_method_name(build, [
		"get_build_snapshot", "get_snapshot", "get_tray_snapshot",
	])
	if acquisition_method.is_empty() or replacement_method.is_empty() or snapshot_method.is_empty():
		_record_case(
			"Inventory duplicate and replacement semantics expose callable APIs",
			false,
			{
				"acquire": "public method",
				"replace": "public method",
				"snapshot": "public method",
			},
			{
				"acquire": acquisition_method,
				"replace": replacement_method,
				"snapshot": snapshot_method,
				"available_methods": _script_method_names(BUILD_SYSTEM_SCRIPT),
			}
		)
		return

	var first_result: Variant = build.call(acquisition_method, SINGLE_HAUL)
	var second_result: Variant = build.call(acquisition_method, DOUBLE_MULT)
	var duplicate_result: Variant = build.call(acquisition_method, SINGLE_HAUL)
	var before_replace: Dictionary = _coerce_dictionary(build.call(snapshot_method))
	var before_slots: Array[String] = _snapshot_slot_ids(before_replace)
	var replacement_result: Variant = _call_replacement(
		build,
		replacement_method,
		0,
		TRIPLE_XMULT
	)
	var after_replace: Dictionary = _coerce_dictionary(build.call(snapshot_method))
	var after_slots: Array[String] = _snapshot_slot_ids(after_replace)
	var reacquire_result: Variant = build.call(acquisition_method, SINGLE_HAUL)
	var final_snapshot: Dictionary = _coerce_dictionary(build.call(snapshot_method))
	var final_slots: Array[String] = _snapshot_slot_ids(final_snapshot)
	var duplicate_rejected: bool = not _operation_succeeded(duplicate_result)
	var first_empty_correct: bool = (
		before_slots.size() >= 2
		and before_slots[0] == SINGLE_HAUL
		and before_slots[1] == DOUBLE_MULT
	)
	var replacement_preserved: bool = (
		after_slots.size() >= 2
		and after_slots[0] == TRIPLE_XMULT
		and after_slots[1] == DOUBLE_MULT
	)
	var removed_eligible_again: bool = (
		_operation_succeeded(reacquire_result)
		and final_slots.has(SINGLE_HAUL)
		and final_slots.find(SINGLE_HAUL) != 0
	)
	_record_case(
		"Inventory rejects duplicates and uses first empty tray slots",
		_operation_succeeded(first_result)
			and _operation_succeeded(second_result)
			and duplicate_rejected
			and first_empty_correct,
		{
			"first_two_slots": [SINGLE_HAUL, DOUBLE_MULT],
			"duplicate_rejected": true,
		},
		{
			"first_result": first_result,
			"second_result": second_result,
			"duplicate_result": duplicate_result,
			"slots": before_slots,
		}
	)
	_record_case(
		"Replacement preserves slot index and removed item becomes eligible",
		_operation_succeeded(replacement_result)
			and replacement_preserved
			and removed_eligible_again,
		{
			"slot_0": TRIPLE_XMULT,
			"slot_1_unchanged": DOUBLE_MULT,
			"removed_item_reacquired": true,
		},
		{
			"replacement_result": replacement_result,
			"after_replace": after_slots,
			"reacquire_result": reacquire_result,
			"final_slots": final_slots,
		}
	)
	var capacity: int = int(final_snapshot.get(
		"tray_capacity",
		final_snapshot.get("capacity", EXPECTED_TRAY_CAPACITY)
	))
	_record_case(
		"Build tray capacity is five",
		capacity == EXPECTED_TRAY_CAPACITY,
		EXPECTED_TRAY_CAPACITY,
		capacity
	)


static func _test_build_lifecycle_and_mode_scope() -> void:
	var build: RogueliteBuildSystem = BUILD_SYSTEM_SCRIPT.new() as RogueliteBuildSystem
	build.begin_fresh_run(41)
	build.acquire_eight_ball(SINGLE_HAUL)
	var before_round: Array[String] = _snapshot_slot_ids(build.get_build_snapshot())
	build.begin_round(2)
	var after_round: Array[String] = _snapshot_slot_ids(build.get_build_snapshot())
	_record_case(
		"Round transition preserves the run build",
		before_round == after_round and after_round.has(SINGLE_HAUL),
		before_round,
		after_round
	)
	build.begin_fresh_run(42)
	var fresh_slots: Array[String] = _snapshot_slot_ids(build.get_build_snapshot())
	_record_case(
		"Fresh run clears the build",
		_not_empty_slot_count(fresh_slots) == 0,
		{"occupied_slots": 0, "run_generation": 42},
		{
			"occupied_slots": _not_empty_slot_count(fresh_slots),
			"run_generation": build.get_build_snapshot().get("run_generation", -1),
		}
	)

	build.acquire_eight_ball(DOUBLE_MULT)
	var run_slots_before_lab: Array[String] = _snapshot_slot_ids(build.get_build_snapshot())
	var lab_result: Dictionary = build.set_shot_lab_loadout([
		COMBO_HAUL,
		COMBO_MULT,
		COMBO_XMULT,
	])
	var lab_slots: Array[String] = _snapshot_slot_ids(build.get_build_snapshot())
	build.set_shot_lab_session(false)
	var run_slots_after_lab: Array[String] = _snapshot_slot_ids(build.get_build_snapshot())
	_record_case(
		"Shot Lab loadout remains isolated from the run tray",
		bool(lab_result.get("success", false))
			and lab_slots.slice(0, 3) == [COMBO_HAUL, COMBO_MULT, COMBO_XMULT]
			and run_slots_after_lab == run_slots_before_lab,
		{
			"lab_slots": [COMBO_HAUL, COMBO_MULT, COMBO_XMULT],
			"run_slots_unchanged": run_slots_before_lab,
		},
		{"lab_slots": lab_slots, "run_slots": run_slots_after_lab}
	)
	_record_case(
		"Eight Ball build modifiers are scoped away from Passage",
		not SCORING_SYSTEM_SCRIPT.is_eight_ball_build_mode("passage")
			and SCORING_SYSTEM_SCRIPT.is_eight_ball_build_mode("roguelite")
			and SCORING_SYSTEM_SCRIPT.is_eight_ball_build_mode("shot_lab"),
		{"passage": false, "roguelite": true, "shot_lab": true},
		{
			"passage": SCORING_SYSTEM_SCRIPT.is_eight_ball_build_mode("passage"),
			"roguelite": SCORING_SYSTEM_SCRIPT.is_eight_ball_build_mode("roguelite"),
			"shot_lab": SCORING_SYSTEM_SCRIPT.is_eight_ball_build_mode("shot_lab"),
		}
	)


static func _test_reward_offer_and_replacement_flow() -> void:
	var build_a: RogueliteBuildSystem = BUILD_SYSTEM_SCRIPT.new() as RogueliteBuildSystem
	build_a.begin_fresh_run(71)
	build_a.acquire_eight_ball(SINGLE_HAUL)
	var reward_a: RogueliteRewardSystem = REWARD_SYSTEM_SCRIPT.new() as RogueliteRewardSystem
	reward_a.setup(8675309)
	reward_a.set_build_system(build_a)
	var first_snapshot: Dictionary = reward_a.generate_reward_offers(1)
	var first_ids: Array[String] = _string_array_value(first_snapshot, "active_offer_ids")
	var unique_offer_lookup: Dictionary = {}
	for item_id in first_ids:
		unique_offer_lookup[item_id] = true
	_record_case(
		"Mark Your Course offers three unique unowned Eight Balls",
		first_ids.size() == 3
			and unique_offer_lookup.size() == 3
			and not first_ids.has(SINGLE_HAUL)
			and str(first_snapshot.get("offer_kind", "")) == "eight_ball"
			and not first_snapshot.has("legacy_rewards_enabled"),
		{
			"count": 3,
			"unique": true,
			"owned_excluded": SINGLE_HAUL,
			"offer_kind": "eight_ball",
			"legacy_field_present": false,
		},
		{
			"offer_ids": first_ids,
			"unique_count": unique_offer_lookup.size(),
			"offer_kind": first_snapshot.get("offer_kind", null),
			"legacy_field_present": first_snapshot.has("legacy_rewards_enabled"),
		}
	)

	var retained_offer_id: String = first_ids[0] if not first_ids.is_empty() else SINGLE_MULT
	var old_reward_state: Dictionary = reward_a.get_rewind_state()
	old_reward_state["active_offer_ids"] = [retained_offer_id, "heavy_purse"]
	old_reward_state["active_offer_kind"] = "legacy_reward"
	old_reward_state["legacy_rewards_enabled"] = true
	old_reward_state["future_quota_bonus"] = 10
	old_reward_state["object_sink_quota_bonus"] = 5
	old_reward_state["last_offer_diagnostics"] = {
		"selection_policy": "legacy_uniform_without_replacement",
		"legacy_rewards_enabled": true,
	}
	var restored_rewards: RogueliteRewardSystem = REWARD_SYSTEM_SCRIPT.new() as RogueliteRewardSystem
	restored_rewards.setup(8675309)
	restored_rewards.set_build_system(build_a)
	restored_rewards.restore_rewind_state(old_reward_state)
	var restored_snapshot: Dictionary = restored_rewards.get_reward_snapshot()
	var restored_ids: Array[String] = _string_array_value(restored_snapshot, "active_offer_ids")
	_record_case(
		"Obsolete utility reward rewind fields are ignored",
		restored_ids == [retained_offer_id]
			and str(restored_snapshot.get("offer_kind", "")) == "eight_ball"
			and not restored_snapshot.has("legacy_rewards_enabled")
			and not restored_snapshot.has("effects"),
		{
			"active_offer_ids": [retained_offer_id],
			"offer_kind": "eight_ball",
			"legacy_fields_present": false,
		},
		{
			"active_offer_ids": restored_ids,
			"offer_kind": restored_snapshot.get("offer_kind", null),
			"legacy_rewards_enabled_present": restored_snapshot.has("legacy_rewards_enabled"),
			"effects_present": restored_snapshot.has("effects"),
		}
	)

	var build_b: RogueliteBuildSystem = BUILD_SYSTEM_SCRIPT.new() as RogueliteBuildSystem
	build_b.begin_fresh_run(71)
	build_b.acquire_eight_ball(SINGLE_HAUL)
	var reward_b: RogueliteRewardSystem = REWARD_SYSTEM_SCRIPT.new() as RogueliteRewardSystem
	reward_b.setup(8675309)
	reward_b.set_build_system(build_b)
	var second_ids: Array[String] = _string_array_value(
		reward_b.generate_reward_offers(1),
		"active_offer_ids"
	)
	_record_case(
		"Reward offers are deterministic for the same seed and build",
		first_ids == second_ids,
		first_ids,
		second_ids
	)

	var fill_ids: Array[String] = [SINGLE_HAUL, SINGLE_MULT, SINGLE_XMULT, DOUBLE_HAUL, DOUBLE_MULT]
	var full_build: RogueliteBuildSystem = BUILD_SYSTEM_SCRIPT.new() as RogueliteBuildSystem
	full_build.begin_fresh_run(72)
	for item_id in fill_ids:
		full_build.acquire_eight_ball(item_id)
	var full_rewards: RogueliteRewardSystem = REWARD_SYSTEM_SCRIPT.new() as RogueliteRewardSystem
	full_rewards.setup(112358)
	full_rewards.set_build_system(full_build)
	var full_offer_snapshot: Dictionary = full_rewards.generate_reward_offers(2)
	var full_offer_ids: Array[String] = _string_array_value(full_offer_snapshot, "active_offer_ids")
	var selected_id: String = full_offer_ids[0] if not full_offer_ids.is_empty() else ""
	var pending: Dictionary = full_rewards.choose_reward(selected_id)
	var old_slot_id: String = fill_ids[2]
	var replacement: Dictionary = full_rewards.confirm_eight_ball_replacement(2)
	var replaced_slots: Array[String] = _snapshot_slot_ids(full_build.get_build_snapshot())
	_record_case(
		"Full tray selection requires replacement and preserves slot order",
		bool(pending.get("requires_replacement", false))
			and bool(replacement.get("completed", false))
			and replaced_slots[2] == selected_id
			and replaced_slots[0] == fill_ids[0]
			and replaced_slots[1] == fill_ids[1]
			and not full_build.owns_eight_ball(old_slot_id),
		{
			"requires_replacement": true,
			"slot_2": selected_id,
			"other_slots_unchanged": true,
			"removed_item_eligible": old_slot_id,
		},
		{
			"pending": pending,
			"replacement": replacement,
			"slots": replaced_slots,
		}
	)

	var skip_snapshot: Dictionary = full_rewards.generate_reward_offers(3)
	var before_skip_slots: Array[String] = _snapshot_slot_ids(full_build.get_build_snapshot())
	var skip_result: Dictionary = full_rewards.keep_current_course("self_test")
	var after_skip_slots: Array[String] = _snapshot_slot_ids(full_build.get_build_snapshot())
	_record_case(
		"Keep Current Course preserves the full build",
		not _string_array_value(skip_snapshot, "active_offer_ids").is_empty()
			and bool(skip_result.get("completed", false))
			and bool(skip_result.get("skipped", false))
			and before_skip_slots == after_skip_slots,
		{"skipped": true, "build_unchanged": before_skip_slots},
		{"skip": skip_result, "build": after_skip_slots}
	)


static func _test_phase5b_trigger_contract() -> void:
	var direct_fact: Dictionary = _fact_with_pocket_index(
		_make_fact(20, 1, 0, false, 900),
		0
	)
	_record_trigger_case(
		"Direct Pot emits once for one qualifying scoring ball",
		_evaluate_triggers(_make_ledger([direct_fact])),
		{TRIGGER_DIRECT: 1}
	)

	var two_direct_facts: Array[Dictionary] = [
		_fact_with_pocket_index(_make_fact(20, 1, 0, false, 910), 0),
		_fact_with_pocket_index(_make_fact(21, 2, 0, false, 920), 1),
	]
	var two_direct_occurrences: Array[Dictionary] = _evaluate_triggers(
		_make_ledger(two_direct_facts)
	)
	_record_trigger_case(
		"Two Direct Pots emit two Direct occurrences and one Multi-Pot",
		two_direct_occurrences,
		{TRIGGER_DIRECT: 2, TRIGGER_MULTI: 1}
	)
	var multi_occurrence: Dictionary = _find_trigger_occurrence(
		two_direct_occurrences,
		TRIGGER_MULTI
	)
	_record_case(
		"Multi-Pot anchors to the second scoring-ball pocket",
		int(multi_occurrence.get("ball_id", -1)) == 21
			and int(multi_occurrence.get("event_index", -1)) == int(
				two_direct_facts[1].get("pocket_event_index", -2)
			),
		{"ball_id": 21, "event_index": two_direct_facts[1].get("pocket_event_index")},
		multi_occurrence
	)

	var same_pocket_facts: Array[Dictionary] = [
		_fact_with_pocket_index(_make_fact(22, 1, 0, false, 930), 2),
		_fact_with_pocket_index(_make_fact(23, 2, 0, false, 940), 2),
	]
	var same_pocket_occurrences: Array[Dictionary] = _evaluate_triggers(
		_make_ledger(same_pocket_facts)
	)
	_record_trigger_case(
		"Same-Pocket X2 overlaps Direct Pot and Multi-Pot once",
		same_pocket_occurrences,
		{TRIGGER_DIRECT: 2, TRIGGER_MULTI: 1, TRIGGER_SAME_POCKET: 1}
	)
	var same_occurrence: Dictionary = _find_trigger_occurrence(
		same_pocket_occurrences,
		TRIGGER_SAME_POCKET
	)
	_record_case(
		"Same-Pocket anchors when the pocket first reaches X2",
		int(same_occurrence.get("ball_id", -1)) == 23
			and int(_dictionary_value(same_occurrence, "metadata").get(
				"final_streak_count",
				0
			)) == 2,
		{"ball_id": 23, "final_streak_count": 2},
		same_occurrence
	)

	var two_streak_facts: Array[Dictionary] = [
		_fact_with_pocket_index(_make_fact(24, 1, 0, false, 950), 0),
		_fact_with_pocket_index(_make_fact(25, 2, 0, false, 960), 0),
		_fact_with_pocket_index(_make_fact(26, 3, 0, false, 970), 1),
		_fact_with_pocket_index(_make_fact(27, 4, 0, false, 980), 1),
	]
	_record_trigger_case(
		"Two qualifying pockets emit two Same-Pocket occurrences",
		_evaluate_triggers(_make_ledger(two_streak_facts)),
		{TRIGGER_DIRECT: 4, TRIGGER_MULTI: 1, TRIGGER_SAME_POCKET: 2}
	)


static func _test_phase5b_exact_scores() -> void:
	var one_direct: Array[Dictionary] = [
		_fact_with_pocket_index(_make_fact(30, 1, 0, false, 1000), 0),
	]
	_run_score_case("Direct Pot base", [], one_direct, 10, 10, 1.0)
	_run_score_case("Clean Plunder only", [DIRECT_HAUL], one_direct, 20, 20, 1.0)
	_run_score_case("True Bearing only", [DIRECT_MULT], one_direct, 20, 10, 2.0)
	_run_score_case("Unerring Course only", [DIRECT_XMULT], one_direct, 12, 10, 1.25)
	_run_score_case(
		"Direct Pot Trio",
		[DIRECT_HAUL, DIRECT_MULT, DIRECT_XMULT],
		one_direct,
		50, 20, 2.5
	)
	_run_score_case("Dead Reckoning only", [DEAD_RECKONING], one_direct, 10, 10, 1.0)
	_run_score_case(
		"Clean Plunder + Dead Reckoning",
		[DIRECT_HAUL, DEAD_RECKONING], one_direct, 30, 30, 1.0
	)
	_run_score_case(
		"True Bearing + Dead Reckoning",
		[DIRECT_MULT, DEAD_RECKONING], one_direct, 30, 10, 3.0
	)
	_run_score_case(
		"Unerring Course + Dead Reckoning",
		[DIRECT_XMULT, DEAD_RECKONING], one_direct, 15, 10, 1.5625
	)
	_run_score_case(
		"Direct Pot Trio + Dead Reckoning",
		[DIRECT_HAUL, DIRECT_MULT, DIRECT_XMULT, DEAD_RECKONING],
		one_direct,
		140, 30, 4.6875
	)

	var two_direct: Array[Dictionary] = [
		_fact_with_pocket_index(_make_fact(31, 1, 0, false, 1010), 0),
		_fact_with_pocket_index(_make_fact(32, 2, 0, false, 1020), 1),
	]
	_run_score_case("Multi-Pot base", [], two_direct, 40, 20, 2.0)
	_run_score_case("Loaded Hold only", [MULTI_HAUL], two_direct, 80, 40, 2.0)
	_run_score_case("All Hands only", [MULTI_MULT], two_direct, 80, 20, 4.0)
	_run_score_case("Broadside Dividend only", [MULTI_XMULT], two_direct, 60, 20, 3.0)
	_run_score_case(
		"Multi-Pot Trio",
		[MULTI_HAUL, MULTI_MULT, MULTI_XMULT],
		two_direct,
		240, 40, 6.0
	)

	var same_pocket: Array[Dictionary] = [
		_fact_with_pocket_index(_make_fact(33, 1, 0, false, 1030), 3),
		_fact_with_pocket_index(_make_fact(34, 2, 0, false, 1040), 3),
	]
	_run_score_case("Same-Pocket base", [], same_pocket, 40, 20, 2.0)
	_run_score_case("Shared Grave only", [SAME_HAUL], same_pocket, 90, 45, 2.0)
	_run_score_case("Feeding Frenzy only", [SAME_MULT], same_pocket, 100, 20, 5.0)
	_run_score_case("The Maw Below only", [SAME_XMULT], same_pocket, 70, 20, 3.5)
	_run_score_case(
		"Same-Pocket Trio",
		[SAME_HAUL, SAME_MULT, SAME_XMULT],
		same_pocket,
		393, 45, 8.75
	)


static func _test_dead_reckoning_contract() -> void:
	var two_direct: Array[Dictionary] = [
		_fact_with_pocket_index(_make_fact(40, 1, 0, false, 1100), 0),
		_fact_with_pocket_index(_make_fact(41, 2, 0, false, 1110), 1),
	]
	var pipeline: Dictionary = _run_score_pipeline(
		[DIRECT_HAUL, DIRECT_MULT, DIRECT_XMULT, DEAD_RECKONING],
		two_direct
	)
	var modifiers: Array[Dictionary] = _dictionary_array_value(pipeline, "modifiers")
	var result: Dictionary = _dictionary_value(pipeline, "score_result")
	var activation_counts: Dictionary = _activation_counts(modifiers)
	var retrigger_count: int = 0
	var marker_count: int = 0
	var invalid_retriggers: Array[Dictionary] = []
	for modifier in modifiers:
		if not bool(modifier.get("is_retrigger", false)):
			continue
		retrigger_count += 1
		if bool(modifier.get("retrigger_marker_required", false)):
			marker_count += 1
		if (
			int(modifier.get("retrigger_index", 0)) != 1
			or str(modifier.get("retrigger_source_item_id", "")) != DEAD_RECKONING
			or str(modifier.get("original_activation_id", "")).is_empty()
		):
			invalid_retriggers.append(modifier.duplicate(true))
	_record_case(
		"Two Direct Pots with Dead Reckoning resolve exact bounded score",
		bool(pipeline.get("valid", false))
			and int(result.get("shot_score", -1)) == 878
			and int(result.get("final_haul", -1)) == 60
			and is_equal_approx(float(result.get("final_mult", -1.0)), 14.6484375)
			and int(activation_counts.get(DIRECT_HAUL, 0)) == 4
			and int(activation_counts.get(DIRECT_MULT, 0)) == 4
			and int(activation_counts.get(DIRECT_XMULT, 0)) == 4
			and int(activation_counts.get(DEAD_RECKONING, 0)) == 0
			and retrigger_count == 6
			and marker_count == 2
			and invalid_retriggers.is_empty(),
		{
			"score": 878,
			"haul": 60,
			"mult": 14.6484375,
			"support_activations_each": 4,
			"retrigger_count": 6,
			"marker_count": 2,
		},
		{
			"score": result.get("shot_score"),
			"haul": result.get("final_haul"),
			"mult": result.get("final_mult"),
			"activation_counts": activation_counts,
			"retrigger_count": retrigger_count,
			"marker_count": marker_count,
			"invalid_retriggers": invalid_retriggers,
			"modifiers": modifiers,
		}
	)

	var predicted: Dictionary = _run_score_pipeline(
		[DIRECT_HAUL, DIRECT_MULT, DIRECT_XMULT, DEAD_RECKONING],
		two_direct,
		"predicted"
	)
	_record_case(
		"Dead Reckoning predicted and authoritative results match",
		_score_results_equal(
			_dictionary_value(predicted, "score_result"),
			result
		)
			and _modifier_source_order(_dictionary_value(predicted, "score_result"))
				== _modifier_source_order(result),
		_score_summary(result),
		_score_summary(_dictionary_value(predicted, "score_result"))
	)


static func _test_phase5b_overlap_contract() -> void:
	var direct_multi: Dictionary = _run_score_pipeline(
		[DIRECT_HAUL, MULTI_HAUL],
		[
			_fact_with_pocket_index(_make_fact(50, 1, 0, false, 1200), 0),
			_fact_with_pocket_index(_make_fact(51, 2, 0, false, 1210), 1),
		]
	)
	_record_pipeline_case(
		"Overlap: two Direct Pots also activate Multi-Pot exactly once",
		direct_multi,
		120,
		{TRIGGER_DIRECT: 2, TRIGGER_MULTI: 1},
		{DIRECT_HAUL: 2, MULTI_HAUL: 1}
	)

	var multi_same: Dictionary = _run_score_pipeline(
		[MULTI_MULT, SAME_MULT],
		[
			_fact_with_pocket_index(_make_fact(52, 1, 0, false, 1220), 4),
			_fact_with_pocket_index(_make_fact(53, 2, 0, false, 1230), 4),
		]
	)
	_record_pipeline_case(
		"Overlap: Multi-Pot and Same-Pocket each activate exactly once",
		multi_same,
		140,
		{TRIGGER_DIRECT: 2, TRIGGER_MULTI: 1, TRIGGER_SAME_POCKET: 1},
		{MULTI_MULT: 1, SAME_MULT: 1}
	)

	var bank_combo_multi: Dictionary = _run_score_pipeline(
		[SINGLE_HAUL, COMBO_HAUL, MULTI_HAUL],
		[
			_fact_with_pocket_index(_make_fact(54, 1, 1, true, 1240), 0),
			_fact_with_pocket_index(_make_fact(55, 2, 0, false, 1250), 1),
		]
	)
	_record_pipeline_case(
		"Overlap: Bank Combination plus Multi-Pot keeps every semantic occurrence once",
		bank_combo_multi,
		240,
		{
			TRIGGER_SINGLE: 1,
			TRIGGER_COMBINATION: 1,
			TRIGGER_DIRECT: 1,
			TRIGGER_MULTI: 1,
		},
		{SINGLE_HAUL: 1, COMBO_HAUL: 1, MULTI_HAUL: 1}
	)

	var unsupported: Dictionary = _run_score_pipeline(
		[DEAD_RECKONING],
		[_fact_with_pocket_index(_make_fact(56, 1, 0, false, 1260), 0)]
	)
	_record_case(
		"Dead Reckoning without Direct support is inert",
		int(_dictionary_value(unsupported, "score_result").get("shot_score", -1)) == 10
			and _dictionary_array_value(unsupported, "modifiers").is_empty(),
		{"score": 10, "modifier_count": 0},
		{
			"score": _dictionary_value(unsupported, "score_result").get("shot_score"),
			"modifiers": unsupported.get("modifiers", []),
		}
	)


static func _test_phase5b_reward_contract() -> void:
	var unsupported_build: RogueliteBuildSystem = BUILD_SYSTEM_SCRIPT.new() as RogueliteBuildSystem
	unsupported_build.begin_fresh_run(81)
	var unsupported_reward: RogueliteRewardSystem = REWARD_SYSTEM_SCRIPT.new() as RogueliteRewardSystem
	unsupported_reward.setup(314159)
	unsupported_reward.set_build_system(unsupported_build)
	var unsupported_snapshot: Dictionary = unsupported_reward.generate_reward_offers(1)
	var unsupported_pool_ids: Array[String] = _reward_item_ids(
		_array_value(unsupported_snapshot, "eligible_pool")
	)
	_record_case(
		"Dead Reckoning is excluded without regular Direct Pot support",
		not unsupported_pool_ids.has(DEAD_RECKONING),
		false,
		unsupported_pool_ids.has(DEAD_RECKONING)
	)

	var supported_build: RogueliteBuildSystem = BUILD_SYSTEM_SCRIPT.new() as RogueliteBuildSystem
	supported_build.begin_fresh_run(82)
	supported_build.acquire_eight_ball(DIRECT_HAUL)
	var supported_reward: RogueliteRewardSystem = REWARD_SYSTEM_SCRIPT.new() as RogueliteRewardSystem
	supported_reward.setup(314159)
	supported_reward.set_build_system(supported_build)
	var supported_snapshot: Dictionary = supported_reward.generate_reward_offers(1)
	var supported_pool_ids: Array[String] = _reward_item_ids(
		_array_value(supported_snapshot, "eligible_pool")
	)
	var offered_families: Dictionary = {}
	var legendary_offers: int = 0
	for offer_value in _array_value(supported_snapshot, "offers"):
		if not offer_value is Dictionary:
			continue
		var offer: Dictionary = offer_value as Dictionary
		offered_families[str(offer.get("family_id", ""))] = true
		if str(offer.get("rarity", "")) == "legendary":
			legendary_offers += 1
	_record_case(
		"Supported rewards expose Dead Reckoning and family-diverse offers",
		supported_pool_ids.has(DEAD_RECKONING)
			and offered_families.size() >= 2
			and legendary_offers <= 1,
		{"dead_reckoning_eligible": true, "minimum_families": 2, "max_legendary": 1},
		{
			"dead_reckoning_eligible": supported_pool_ids.has(DEAD_RECKONING),
			"families": offered_families.keys(),
			"legendary_offers": legendary_offers,
			"offers": supported_snapshot.get("offers", []),
		}
	)

	var warning_build: RogueliteBuildSystem = BUILD_SYSTEM_SCRIPT.new() as RogueliteBuildSystem
	warning_build.begin_fresh_run(83)
	warning_build.acquire_eight_ball(DIRECT_HAUL)
	warning_build.acquire_eight_ball(DEAD_RECKONING)
	_record_case(
		"Replacing final Direct support exposes Dead Reckoning warning",
		warning_build.get_replacement_warning(0, SINGLE_HAUL)
			== RogueliteBuildSystem.UNSUPPORTED_RETRIGGER_REPLACEMENT_WARNING,
		RogueliteBuildSystem.UNSUPPORTED_RETRIGGER_REPLACEMENT_WARNING,
		warning_build.get_replacement_warning(0, SINGLE_HAUL)
	)


static func _run_score_case(
	name: String,
	loadout: Array[String],
	facts: Array[Dictionary],
	expected_score: int,
	expected_haul: int,
	expected_mult: float
) -> void:
	var pipeline: Dictionary = _run_score_pipeline(loadout, facts)
	var result: Dictionary = _dictionary_value(pipeline, "score_result")
	var actual_score: int = int(result.get("shot_score", -1))
	var actual_haul: int = int(result.get("final_haul", -1))
	var actual_mult: float = float(result.get("final_mult", -1.0))
	var passed: bool = (
		bool(pipeline.get("valid", false))
		and actual_score == expected_score
		and actual_haul == expected_haul
		and is_equal_approx(actual_mult, expected_mult)
	)
	_record_case(
		name,
		passed,
		{
			"shot_score": expected_score,
			"final_haul": expected_haul,
			"final_mult": expected_mult,
		},
		{
			"shot_score": actual_score,
			"final_haul": actual_haul,
			"final_mult": actual_mult,
			"trigger_counts": _trigger_counts(_dictionary_array_value(pipeline, "occurrences")),
			"modifier_order": _modifier_source_order(result),
			"errors": pipeline.get("errors", []),
			"warnings": result.get("warnings", []),
		}
	)


static func _run_score_pipeline(
	loadout: Array[String],
	facts: Array[Dictionary],
	source: String = "authoritative"
) -> Dictionary:
	var ledger: Dictionary = _make_ledger(facts, source)
	var occurrences: Array[Dictionary] = _evaluate_triggers(ledger)
	var build_result: Dictionary = _build_modifiers(loadout, occurrences)
	var modifiers: Array[Dictionary] = _dictionary_array_value(build_result, "modifiers")
	var errors: Array[String] = _string_array_value(build_result, "errors")
	var score_result: Dictionary = RESOLVER_SCRIPT.resolve(ledger, modifiers)
	return {
		"valid": errors.is_empty()
			and bool(_dictionary_value(score_result, "diagnostics").get("input_valid", false)),
		"ledger": ledger,
		"occurrences": occurrences,
		"modifiers": modifiers,
		"score_result": score_result,
		"errors": errors,
		"build_snapshot": build_result.get("snapshot", {}),
	}


static func _record_pipeline_case(
	name: String,
	pipeline: Dictionary,
	expected_score: int,
	expected_trigger_counts: Dictionary,
	expected_activation_counts: Dictionary
) -> void:
	var result: Dictionary = _dictionary_value(pipeline, "score_result")
	var occurrences: Array[Dictionary] = _dictionary_array_value(pipeline, "occurrences")
	var modifiers: Array[Dictionary] = _dictionary_array_value(pipeline, "modifiers")
	var actual_trigger_counts: Dictionary = _trigger_counts(occurrences)
	var actual_activation_counts: Dictionary = _activation_counts(modifiers)
	var occurrence_ids: Dictionary = {}
	var duplicate_occurrences: Array[String] = []
	for modifier in modifiers:
		var occurrence_id: String = str(modifier.get("trigger_occurrence_id", ""))
		var compound_key: String = "%s|%s|%d" % [
			str(modifier.get("eight_ball_item_id", modifier.get("modifier_id", ""))),
			occurrence_id,
			int(modifier.get("retrigger_index", 0)),
		]
		if occurrence_ids.has(compound_key):
			duplicate_occurrences.append(compound_key)
		occurrence_ids[compound_key] = true
	var passed: bool = (
		bool(pipeline.get("valid", false))
		and int(result.get("shot_score", -1)) == expected_score
		and _dictionaries_equal(actual_trigger_counts, expected_trigger_counts)
		and _dictionaries_equal(actual_activation_counts, expected_activation_counts)
		and duplicate_occurrences.is_empty()
	)
	_record_case(
		name,
		passed,
		{
			"shot_score": expected_score,
			"trigger_counts": expected_trigger_counts,
			"activation_counts": expected_activation_counts,
			"duplicate_activations": [],
		},
		{
			"shot_score": result.get("shot_score", null),
			"trigger_counts": actual_trigger_counts,
			"activation_counts": actual_activation_counts,
			"duplicate_activations": duplicate_occurrences,
			"occurrences": occurrences,
			"modifiers": modifiers,
			"errors": pipeline.get("errors", []),
		}
	)


static func _record_trigger_case(
	name: String,
	occurrences: Array[Dictionary],
	expected_counts: Dictionary
) -> void:
	var actual_counts: Dictionary = _trigger_counts(occurrences)
	var occurrence_ids: Dictionary = {}
	var duplicates: Array[String] = []
	for occurrence in occurrences:
		var occurrence_id: String = str(occurrence.get("trigger_occurrence_id", ""))
		if occurrence_id.is_empty() or occurrence_ids.has(occurrence_id):
			duplicates.append(occurrence_id)
		occurrence_ids[occurrence_id] = true
	_record_case(
		name,
		_dictionaries_equal(actual_counts, expected_counts) and duplicates.is_empty(),
		{"counts": expected_counts, "unique_occurrence_ids": true},
		{"counts": actual_counts, "duplicates": duplicates, "occurrences": occurrences}
	)


static func _record_case(
	name: String,
	passed: bool,
	expected: Variant,
	actual: Variant
) -> void:
	_cases.append({
		"name": name,
		"passed": passed,
		"expected": expected,
		"actual": actual,
	})


static func _make_ledger(
	facts: Array[Dictionary],
	source: String = "authoritative"
) -> Dictionary:
	var object_ids: Array[int] = []
	var raw_events: Array[Dictionary] = []
	for fact in facts:
		var ball_id: int = int(fact.get("ball_id", -1))
		object_ids.append(ball_id)
		var activation_index: int = int(fact.get("causal_activation_event_index", -1))
		raw_events.append({
			"event_type": "ball_contact",
			"event_index": activation_index,
			"source_ball_id": 1,
			"target_ball_id": ball_id,
			"contact_point": Vector2(float(activation_index), float(ball_id)),
			"world_position": Vector2(float(activation_index), float(ball_id)),
			"contact_position": Vector2(float(activation_index), float(ball_id)),
		})
		var rail_indices: Array = _array_value(fact, "qualifying_rail_event_indices")
		for rail_ordinal in range(rail_indices.size()):
			var rail_index: int = int(rail_indices[rail_ordinal])
			raw_events.append({
				"event_type": "rail_contact",
				"event_index": rail_index,
				"ball_id": ball_id,
				"rail_id": "TestRail%d" % (rail_ordinal + 1),
				"surface_contact_point": Vector2(float(rail_index), float(ball_id)),
				"world_position": Vector2(float(rail_index), float(ball_id)),
				"contact_position": Vector2(float(rail_index), float(ball_id)),
			})
		raw_events.append({
			"event_type": "pocket",
			"event_index": int(fact.get("pocket_event_index", -1)),
			"ball_id": ball_id,
			"pocket_index": int(fact.get("pocket_index", 0)),
			"capture_position": Vector2(
				float(int(fact.get("pocket_event_index", -1))),
				float(ball_id)
			),
			"world_position": Vector2(
				float(int(fact.get("pocket_event_index", -1))),
				float(ball_id)
			),
		})
	raw_events.sort_custom(_event_precedes)
	return {
		"schema_version": 2,
		"source": source,
		"mode_id": "roguelite",
		"run_generation": 1,
		"shot_id": 1,
		"attempt_id": 1,
		"cue_ball_id": 1,
		"raw_events": raw_events,
		"derived": {
			"schema_version": ANALYZER_SCRIPT.SCHEMA_VERSION,
			"object_ball_pocket_count": facts.size(),
			"object_balls_pocketed": object_ids,
			"pocket_facts": facts.duplicate(true),
			"scratch_occurred": false,
			"cue_ball_pocket_event_index": -1,
		},
	}


static func _make_fact(
	ball_id: int,
	pocket_order: int,
	bank_count: int,
	combination: bool,
	event_base: int
) -> Dictionary:
	var rail_indices: Array[int] = []
	for rail_offset in range(bank_count):
		rail_indices.append(event_base + rail_offset + 1)
	return {
		"ball_id": ball_id,
		"ball_number": ball_id,
		"pocket_order": pocket_order,
		"pocket_event_index": event_base + bank_count + 5,
		"pocket_index": pocket_order % 6,
		"causal_parent_ball_id": 6 if combination else 1,
		"causal_depth": 2 if combination else 1,
		"causal_activation_event_index": event_base - 1,
		"rail_contacts_after_activation": bank_count,
		"qualifying_rail_event_indices": rail_indices,
		"rail_contacts_before_pocket": bank_count,
		"unique_rails_before_pocket": [],
		"travel_distance": 200.0,
		"is_direct_pot": not combination and bank_count == 0,
		"is_combination_pot": combination,
		"bank_count": bank_count,
		"bank_class": _bank_class(bank_count),
	}


static func _fact_with_pocket_index(fact: Dictionary, pocket_index: int) -> Dictionary:
	var result: Dictionary = fact.duplicate(true)
	result["pocket_index"] = pocket_index
	return result


static func _find_trigger_occurrence(
	occurrences: Array[Dictionary],
	trigger_id: String
) -> Dictionary:
	for occurrence in occurrences:
		if str(occurrence.get("trigger_id", "")) == trigger_id:
			return occurrence.duplicate(true)
	return {}


static func _reward_item_ids(values: Array) -> Array[String]:
	var item_ids: Array[String] = []
	for value in values:
		if not value is Dictionary:
			continue
		var item_id: String = str((value as Dictionary).get(
			"eight_ball_item_id",
			(value as Dictionary).get("id", "")
		))
		if not item_id.is_empty():
			item_ids.append(item_id)
	return item_ids


static func _get_catalog_definitions() -> Array[Dictionary]:
	var result: Variant = CATALOG_SCRIPT.get_all_definitions()
	var definitions: Array[Dictionary] = _coerce_definition_array(result)
	if not definitions.is_empty():
		return definitions
	_api_notes.append("Catalog API returned no definitions from get_all_definitions().")
	return []


static func _evaluate_triggers(ledger: Dictionary) -> Array[Dictionary]:
	var result: Variant = TRIGGER_EVALUATOR_SCRIPT.evaluate(ledger)
	return _extract_dictionary_array(result, [
		"trigger_occurrences", "occurrences", "triggers", "results",
	])


static func _build_modifiers(
	loadout: Array[String],
	occurrences: Array[Dictionary]
) -> Dictionary:
	var errors: Array[String] = []
	var build: Variant = BUILD_SYSTEM_SCRIPT.new()
	_set_build_loadout(build, loadout, errors)
	var snapshot: Dictionary = _get_build_snapshot(build)
	var result: Variant = null
	var builder_method: String = _find_method_name(build, [
		"build_modifier_context_from_trigger_occurrences",
		"build_modifier_context",
		"create_modifier_context",
		"get_ordered_modifier_context",
		"evaluate_modifier_context",
		"evaluate_owned_items",
	])
	if builder_method.is_empty():
		errors.append(
			"RogueliteBuildSystem exposes no recognized modifier-context builder."
		)
	else:
		var argument_count: int = _method_argument_count(BUILD_SYSTEM_SCRIPT, builder_method)
		if argument_count == 1:
			result = build.call(builder_method, occurrences)
		elif argument_count == 2:
			result = build.call(builder_method, snapshot, occurrences)
		else:
			errors.append(
				"Modifier-context method `%s` has unsupported arity %d."
				% [builder_method, argument_count]
			)
	var modifiers: Array[Dictionary] = _extract_dictionary_array(result, [
		"modifier_context", "ordered_modifiers", "modifiers", "activations",
	])
	return {
		"modifiers": modifiers,
		"snapshot": snapshot,
		"errors": errors,
	}


static func _set_build_loadout(
	build: Variant,
	loadout: Array[String],
	errors: Array[String]
) -> bool:
	var loadout_method: String = _find_method_name(build, [
		"set_debug_loadout",
		"set_shot_lab_loadout",
		"set_loadout",
		"load_debug_loadout",
	])
	if not loadout_method.is_empty():
		var result: Variant = build.call(loadout_method, loadout.duplicate())
		if _operation_succeeded(result):
			return true
		errors.append("Build loadout method `%s` rejected %s." % [loadout_method, loadout])
		return false
	var acquisition_method: String = _find_method_name(build, [
		"acquire_eight_ball", "try_acquire_eight_ball", "acquire_build_item",
	])
	if acquisition_method.is_empty():
		errors.append("RogueliteBuildSystem exposes no recognized loadout/acquisition API.")
		return false
	for item_id in loadout:
		var result: Variant = build.call(acquisition_method, item_id)
		if not _operation_succeeded(result):
			errors.append("Acquisition rejected `%s`: %s" % [item_id, result])
			return false
	return true


static func _get_build_snapshot(build: Variant) -> Dictionary:
	var method_name: String = _find_method_name(build, [
		"get_build_snapshot", "get_snapshot", "get_tray_snapshot",
	])
	return _coerce_dictionary(build.call(method_name)) if not method_name.is_empty() else {}


static func _call_replacement(
	build: Variant,
	method_name: String,
	slot_index: int,
	item_id: String
) -> Variant:
	var argument_names: Array[String] = _method_argument_names(BUILD_SYSTEM_SCRIPT, method_name)
	if argument_names.size() >= 2 and (
		"item" in argument_names[0]
		or "new" in argument_names[0]
		or "eight_ball" in argument_names[0]
	):
		return build.call(method_name, item_id, slot_index)
	return build.call(method_name, slot_index, item_id)


static func _find_method_name(target: Variant, candidates: Array[String]) -> String:
	for method_name in candidates:
		if target != null and target.has_method(method_name):
			return method_name
	return ""


static func _script_method_names(script: Script) -> Array[String]:
	var names: Array[String] = []
	for method_value in script.get_script_method_list():
		if method_value is Dictionary:
			names.append(str((method_value as Dictionary).get("name", "")))
	return names


static func _method_argument_count(script: Script, method_name: String) -> int:
	for method_value in script.get_script_method_list():
		if not method_value is Dictionary:
			continue
		var method: Dictionary = method_value
		if str(method.get("name", "")) != method_name:
			continue
		var args_value: Variant = method.get("args", [])
		return (args_value as Array).size() if args_value is Array else 0
	return -1


static func _method_argument_names(script: Script, method_name: String) -> Array[String]:
	var names: Array[String] = []
	for method_value in script.get_script_method_list():
		if not method_value is Dictionary:
			continue
		var method: Dictionary = method_value
		if str(method.get("name", "")) != method_name:
			continue
		var args_value: Variant = method.get("args", [])
		if not args_value is Array:
			return names
		for arg_value in args_value as Array:
			if arg_value is Dictionary:
				names.append(str((arg_value as Dictionary).get("name", "")))
		return names
	return names


static func _coerce_definition_array(value: Variant) -> Array[Dictionary]:
	if value is Dictionary:
		var dictionary: Dictionary = value
		for wrapper_key in ["definitions", "items", "catalog"]:
			if dictionary.has(wrapper_key):
				return _coerce_definition_array(dictionary[wrapper_key])
		var definitions: Array[Dictionary] = []
		for item_id_value in dictionary.keys():
			var definition_value: Variant = dictionary[item_id_value]
			if not definition_value is Dictionary:
				continue
			var definition: Dictionary = (definition_value as Dictionary).duplicate(true)
			if not definition.has("eight_ball_item_id"):
				definition["eight_ball_item_id"] = str(item_id_value)
			definitions.append(definition)
		return definitions
	return _extract_dictionary_array(value, [])


static func _extract_dictionary_array(
	value: Variant,
	wrapper_keys: Array[String]
) -> Array[Dictionary]:
	if value is Dictionary:
		var dictionary: Dictionary = value
		for wrapper_key in wrapper_keys:
			if dictionary.has(wrapper_key):
				return _extract_dictionary_array(dictionary[wrapper_key], [])
		return []
	if not value is Array:
		return []
	var result: Array[Dictionary] = []
	for entry_value in value as Array:
		if entry_value is Dictionary:
			result.append((entry_value as Dictionary).duplicate(true))
	return result


static func _snapshot_slot_ids(snapshot: Dictionary) -> Array[String]:
	var slots_value: Variant = snapshot.get(
		"tray_slots",
		snapshot.get("slots", snapshot.get("build_slots", []))
	)
	var ids: Array[String] = []
	if not slots_value is Array:
		return ids
	for slot_value in slots_value as Array:
		if slot_value is Dictionary:
			var slot: Dictionary = slot_value
			ids.append(str(slot.get(
				"eight_ball_item_id",
				slot.get("build_item_id", slot.get("item_id", ""))
			)))
		else:
			ids.append(str(slot_value) if slot_value != null else "")
	return ids


static func _not_empty_slot_count(slot_ids: Array[String]) -> int:
	var count: int = 0
	for item_id in slot_ids:
		if not item_id.is_empty():
			count += 1
	return count


static func _operation_succeeded(result: Variant) -> bool:
	if result == null:
		return true
	if result is bool:
		return bool(result)
	if result is Dictionary:
		var dictionary: Dictionary = result
		if dictionary.has("success"):
			return bool(dictionary.get("success", false))
		if dictionary.has("accepted"):
			return bool(dictionary.get("accepted", false))
		if dictionary.has("valid"):
			return bool(dictionary.get("valid", false))
		if dictionary.has("result") and dictionary.get("result") is bool:
			return bool(dictionary.get("result"))
		return not dictionary.is_empty()
	return true


static func _trigger_counts(occurrences: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for occurrence in occurrences:
		var trigger_id: String = str(occurrence.get("trigger_id", ""))
		counts[trigger_id] = int(counts.get(trigger_id, 0)) + 1
	return counts


static func _activation_counts(modifiers: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for modifier in modifiers:
		var item_id: String = str(modifier.get(
			"eight_ball_item_id",
			modifier.get("build_item_id", modifier.get("modifier_id", ""))
		))
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	return counts


static func _occurrence_event_index(occurrence: Dictionary) -> int:
	return int(occurrence.get(
		"trigger_event_index",
		occurrence.get("event_index", -1)
	))


static func _modifier_trigger_event_index(modifier: Dictionary) -> int:
	return int(modifier.get(
		"trigger_event_index",
		modifier.get("event_index", -1)
	))


static func _modifier_source_order(score_result: Dictionary) -> Array[String]:
	var order: Array[String] = []
	for step_value in _array_value(score_result, "resolution_steps"):
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		if str(step.get("source_type", "")) != "modifier":
			continue
		order.append(str(step.get("source_id", "")))
	return order


static func _score_results_equal(a: Dictionary, b: Dictionary) -> bool:
	for key in [
		"base_haul",
		"final_haul",
		"mult_before_xmult",
		"xmult_product",
		"final_mult",
		"shot_score",
	]:
		if not _values_equal(a.get(key), b.get(key)):
			return false
	return _modifier_source_order(a) == _modifier_source_order(b)


static func _score_summary(result: Dictionary) -> Dictionary:
	return {
		"base_haul": result.get("base_haul", null),
		"final_haul": result.get("final_haul", null),
		"mult_before_xmult": result.get("mult_before_xmult", null),
		"xmult_product": result.get("xmult_product", null),
		"final_mult": result.get("final_mult", null),
		"shot_score": result.get("shot_score", null),
		"modifier_order": _modifier_source_order(result),
	}


static func _dictionaries_equal(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size():
		return false
	for key_value in expected.keys():
		if not actual.has(key_value) or not _values_equal(actual[key_value], expected[key_value]):
			return false
	return true


static func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return absf(float(a) - float(b)) <= FLOAT_EPSILON
	return a == b


static func _event_precedes(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("event_index", -1)) < int(b.get("event_index", -1))


static func _bank_class(bank_count: int) -> String:
	if bank_count <= 0:
		return "none"
	if bank_count == 1:
		return "bank"
	if bank_count == 2:
		return "double_bank"
	return "triple_bank_plus"


static func _dictionary_value(source: Dictionary, key: String) -> Dictionary:
	var value: Variant = source.get(key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _coerce_dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _dictionary_array_value(source: Dictionary, key: String) -> Array[Dictionary]:
	return _extract_dictionary_array(source.get(key, []), [])


static func _array_value(source: Dictionary, key: String) -> Array:
	var value: Variant = source.get(key, [])
	return (value as Array).duplicate(true) if value is Array else []


static func _string_array_value(source: Dictionary, key: String) -> Array[String]:
	var values: Array[String] = []
	for value in _array_value(source, key):
		values.append(str(value))
	return values


static func _string_value(source: Dictionary, key: String) -> String:
	return str(source.get(key, ""))


static func _format_report(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(
		"Eight Ball Build Tests: %d/%d passed, %d failed"
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
			% ["PASS" if bool(case_result.get("passed", false)) else "FAIL", str(case_result.get("name", "Unnamed"))]
		)
		lines.append("  Expected: %s" % var_to_str(case_result.get("expected")))
		lines.append("  Actual:   %s" % var_to_str(case_result.get("actual")))
	var notes_value: Variant = report.get("api_notes", [])
	if notes_value is Array and not (notes_value as Array).is_empty():
		lines.append("API NOTES")
		for note_value in notes_value as Array:
			lines.append("- %s" % str(note_value))
	return "\n".join(lines)
