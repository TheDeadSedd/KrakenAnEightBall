extends RefCounted
class_name ShotLabPresetCatalog

# Ball positions and normalized aim points are authored inside Table.playfield_rect.
# Every reference aim declares its coordinate space explicitly. Expectations state
# only the semantic facts each controlled setup is intended to exercise.

const AIM_ROLE_CENTER := "role_center"
const AIM_ROLE_OFFSET := "role_offset"
const AIM_NORMALIZED_PLAYFIELD_POINT := "normalized_playfield_point"
const AIM_POCKET_CENTER := "pocket_center"
const AIM_WORLD_DIRECTION := "world_direction"

const PREFLIGHT_BLOCK := "block"
const PREFLIGHT_WARN := "warn"


static func get_presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = [
		_preset(
			"direct_pot", "Direct Pot",
			"Cue strikes one object ball directly toward the top-left pocket.",
			[_ball("cue", "cue", Vector2(0.34, 0.34)), _ball("target", "object", Vector2(0.18, 0.18), 1)],
			_role_reference("target", 0.40, _preflight("target", ["target"], false, PREFLIGHT_BLOCK)),
			{
				"exact": {"object_ball_pocket_count": 1, "scratch_occurred": false, "maximum_causal_depth": 1},
				"role_facts": {"target": {"causal_depth": 1, "bank_count": 0, "is_direct_pot": true}},
				"tag_counts": {"direct_pot": 1, "miss": 0},
			}
		),
		_preset(
			"clean_miss", "Clean Miss",
			"Cue crosses open felt without contacting the off-line target.",
			[_ball("cue", "cue", Vector2(0.22, 0.66)), _ball("target", "object", Vector2(0.72, 0.30), 2)],
			_point_reference(Vector2(0.90, 0.66), 0.28, _preflight("", [], false, PREFLIGHT_BLOCK, true)),
			{"exact": {"object_ball_pocket_count": 0, "scratch_occurred": false, "semantic_ball_contact_count": 0}, "tag_counts": {"miss": 1}}
		),
		_preset(
			"one_rail_bank", "One-Rail Bank",
			"Target is driven to the left cushion before the top-middle pocket.",
			[
				_ball("cue", "cue", Vector2(0.536017, 0.607884)),
				_ball("target", "object", Vector2(0.382415, 0.526971), 3),
			],
			_role_reference("target", 0.80, _preflight("target", ["target"], false, PREFLIGHT_BLOCK)),
			{"exact": {"object_ball_pocket_count": 1}, "role_facts": {"target": {"bank_count": 1}}, "tag_counts": {"bank": 1}}
		),
		_preset(
			"double_bank", "Double Bank",
			"Target follows bottom-then-right cushions into the top-middle pocket.",
			[
				_ball("cue", "cue", Vector2(0.173729, 0.205394)),
				_ball("target", "object", Vector2(0.329449, 0.423237), 4),
			],
			_role_reference("target", 0.95, _preflight("target", ["target"], false, PREFLIGHT_BLOCK)),
			{"exact": {"object_ball_pocket_count": 1}, "role_facts": {"target": {"bank_count": 2}}, "tag_counts": {"double_bank": 1}}
		),
		_preset(
			"kick", "Kick",
			"Cue reaches a cushion before its first object-ball contact.",
			[
				_ball("cue", "cue", Vector2(0.435381, 0.734440)),
				_ball("target", "object", Vector2(0.382415, 0.423237), 5),
			],
			_point_reference(Vector2(0.014831, 0.568465), 0.28, _preflight("target", [], false, PREFLIGHT_BLOCK)),
			{"minimum": {"cue_rails_before_first_object_contact": 1}, "tag_counts": {"kick": {"min": 1}}}
		),
		_preset(
			"combination", "Combination",
			"Cue activates an intermediate ball that sends a second ball to pocket.",
			[
				_ball("cue", "cue", Vector2(0.364407, 0.387967)),
				_ball("intermediate", "object", Vector2(0.235169, 0.244813), 6),
				_ball("pocket_target", "object", Vector2(0.170551, 0.174274), 7),
			],
			_role_reference("intermediate", 0.52, _preflight("intermediate", ["pocket_target"], false, PREFLIGHT_BLOCK)),
			{
				"exact": {"object_ball_pocket_count": 1, "maximum_causal_depth": 2},
				"role_facts": {"pocket_target": {"causal_depth": 2, "is_combination_pot": true}},
				"tag_counts": {"combination": 1},
			}
		),
		_preset(
			"bank_combination", "Bank Combination",
			"A two-ball causal chain finishes with a cushion-assisted pocket.",
			[
				_ball("cue", "cue", Vector2(0.561441, 0.621369)),
				_ball("intermediate", "object", Vector2(0.418220, 0.545851), 8),
				_ball("pocket_target", "object", Vector2(0.382415, 0.526971), 9),
			],
			_role_reference("intermediate", 0.92, _preflight("intermediate", ["pocket_target"], false, PREFLIGHT_BLOCK)),
			{"minimum": {"maximum_causal_depth": 2}, "role_facts": {"pocket_target": {"is_combination_pot": true, "bank_count": {"min": 1}}}, "tag_counts": {"combination": 1, "bank": {"min": 1}}}
		),
		_preset(
			"multi_pot_different", "Multi-Pot - Different Pockets",
			"A controlled chain sends one target left while the second enters the top-middle pocket.",
			[
				_ball("cue", "cue", Vector2(0.693856, 0.462656)),
				_ball("first_target", "object", Vector2(0.594280, 0.275934), 10),
				_ball("second_target", "object", Vector2(0.498941, 0.037344), 11),
			],
			_role_reference("first_target", 0.88, _preflight("first_target", ["first_target", "second_target"], false, PREFLIGHT_BLOCK, false, true)),
			{"exact": {"object_ball_pocket_count": 2}, "tag_counts": {"multi_pot": 1, "same_pocket_streak": 0}, "maximum": {"largest_same_pocket_count": 1}}
		),
		_preset(
			"same_pocket_x2", "Same-Pocket X2",
			"Two object balls form a controlled chain into the top-left pocket.",
			[
				_ball("cue", "cue", Vector2(0.132415, 0.170124)),
				_ball("first_target", "object", Vector2(0.062818, 0.074274), 12),
				_ball("second_target", "object", Vector2(0.035064, 0.036307), 13),
			],
			_role_reference("first_target", 0.38, _preflight("first_target", ["first_target", "second_target"], false, PREFLIGHT_BLOCK, false, false, true)),
			{"exact": {"object_ball_pocket_count": 2, "largest_same_pocket_count": 2}, "tag_counts": {"same_pocket_streak": 1, "multi_pot": 1}}
		),
		_preset(
			"cue_scratch", "Cue Scratch",
			"Cue ball travels directly into the lower-left pocket.",
			[_ball("cue", "cue", Vector2(0.24, 0.65))],
			_pocket_reference(3, 0.38, _preflight("", ["cue"], true, PREFLIGHT_BLOCK, true)),
			{"exact": {"scratch_occurred": true, "object_ball_pocket_count": 0}, "tag_counts": {"scratch": 1, "miss": 1}}
		),
		_preset(
			"direct_pot_scratch", "Direct Pot + Scratch",
			"A direct target pot is followed by the cue ball scratching.",
			[_ball("cue", "cue", Vector2(0.38, 0.38)), _ball("target", "object", Vector2(0.22, 0.22), 14)],
			_role_reference("target", 0.75, _preflight("target", ["target", "cue"], true, PREFLIGHT_BLOCK)),
			{"exact": {"scratch_occurred": true, "object_ball_pocket_count": 1}, "tag_counts": {"direct_pot": 1, "scratch": 1, "miss": 0}}
		),
		_preset(
			"sustained_contact_cluster", "Sustained Contact Cluster",
			"A tight legal cluster checks that resting overlap is not repeated as semantic impact.",
			[
				_ball("cue", "cue", Vector2(0.35, 0.50)),
				_ball("first_target", "object", Vector2(0.48, 0.50), 1),
				_ball("cluster_ball", "object", Vector2(0.515, 0.50), 2),
			],
			_role_reference("first_target", 0.18, _preflight("first_target", [], false, PREFLIGHT_WARN)),
			{"minimum": {"semantic_ball_contact_count": 1}, "maximum": {"semantic_ball_contact_count": 2}, "exact": {"object_ball_pocket_count": 0}}
		),
		_preset(
			"genuine_recontact", "Genuine Re-Contact",
			"The same pair separates through a rail exchange and collides again.",
			[_ball("cue", "cue", Vector2(0.68, 0.50)), _ball("target", "object", Vector2(0.83, 0.50), 3)],
			_role_reference("target", 0.68, _preflight("target", [], false, PREFLIGHT_WARN)),
			{"exact": {"semantic_ball_contact_count": 2, "unique_ball_contact_pair_count": 1, "object_ball_pocket_count": 0}, "minimum": {"semantic_rail_contact_count": 1}, "tag_counts": {"miss": 1}}
		),
		_preset(
			"tiny_travel", "Tiny Travel",
			"A minimum legal open-table shot provides a short travel sample.",
			[_ball("cue", "cue", Vector2(0.50, 0.50))],
			_point_reference(Vector2(0.80, 0.50), 0.08, _preflight("", [], false, PREFLIGHT_WARN, true)),
			{"travel_ranges": {"cue": {"min": 5.0, "max": 220.0}}, "exact": {"object_ball_pocket_count": 0}}
		),
		_preset(
			"medium_travel", "Medium Travel",
			"An open-table medium-power shot exercises accumulated travel.",
			[_ball("cue", "cue", Vector2(0.30, 0.50))],
			_point_reference(Vector2(0.80, 0.50), 0.28, _preflight("", [], false, PREFLIGHT_WARN, true)),
			{"travel_ranges": {"cue": {"min": 200.0, "max": 1600.0}}, "exact": {"object_ball_pocket_count": 0}}
		),
		_preset(
			"long_rail_route", "Long Rail Route",
			"A strong horizontal shot follows a long multi-rail route without a target.",
			[_ball("cue", "cue", Vector2(0.35, 0.50))],
			_point_reference(Vector2(0.80, 0.50), 0.82, _preflight("", [], false, PREFLIGHT_WARN, true)),
			{"travel_ranges": {"cue": {"min": 1200.0, "max": 12000.0}}, "minimum": {"semantic_rail_contact_count": 2}, "exact": {"object_ball_pocket_count": 0}}
		),
	]
	var score_expectations: Dictionary = _score_expectations_by_preset()
	for preset in presets:
		var preset_id: String = str(preset.get("preset_id", ""))
		preset["expected_score"] = _dictionary_value(score_expectations, preset_id).duplicate(true)
	return presets


static func get_preset(preset_id: String) -> Dictionary:
	for preset in get_presets():
		if str(preset.get("preset_id", "")) == preset_id:
			return preset.duplicate(true)
	return {}


static func _preset(
	preset_id: String,
	display_name: String,
	description: String,
	balls: Array,
	reference_shot: Dictionary,
	expected: Dictionary
) -> Dictionary:
	return {
		"preset_id": preset_id,
		"display_name": display_name,
		"description": description,
		"coordinate_space": "normalized_playfield",
		"balls": balls,
		"reference_shot": reference_shot,
		"expected": expected,
	}


static func _score_expectations_by_preset() -> Dictionary:
	return {
		"direct_pot": _score_expectation(10, 1.0, 10, {"base_object_ball_value": 1}),
		"clean_miss": _score_expectation(0, 1.0, 0, {"base_object_ball_value": 0}),
		"one_rail_bank": _score_expectation(10, 2.0, 20, {
			"base_object_ball_value": 1,
			"base_bank_rail": 1,
		}),
		"double_bank": _score_expectation(10, 3.0, 30, {
			"base_object_ball_value": 1,
			"base_bank_rail": 1,
		}),
		"kick": _score_expectation(0, 1.0, 0, {"base_object_ball_value": 0}),
		"combination": _score_expectation(10, 2.0, 20, {
			"base_object_ball_value": 1,
			"base_combination": 1,
		}),
		"bank_combination": _score_expectation(10, 3.0, 30, {
			"base_object_ball_value": 1,
			"base_bank_rail": 1,
			"base_combination": 1,
		}),
		"multi_pot_different": _score_expectation(20, 6.0, 120, {
			"base_object_ball_value": 2,
			"base_additional_ball": 1,
			"base_bank_rail": 1,
			"base_combination": 1,
		}),
		"same_pocket_x2": _score_expectation(20, 3.0, 60, {
			"base_object_ball_value": 2,
			"base_additional_ball": 1,
			"base_combination": 1,
		}),
		"cue_scratch": _score_expectation(0, 1.0, 0, {
			"base_object_ball_value": 0,
			"scratch": 1,
		}),
		"direct_pot_scratch": _score_expectation(10, 1.0, 10, {
			"base_object_ball_value": 1,
			"scratch": 1,
		}),
		"sustained_contact_cluster": _score_expectation(0, 1.0, 0, {"base_object_ball_value": 0}),
		"genuine_recontact": _score_expectation(0, 1.0, 0, {"base_object_ball_value": 0}),
		"tiny_travel": _score_expectation(0, 1.0, 0, {"base_object_ball_value": 0}),
		"medium_travel": _score_expectation(0, 1.0, 0, {"base_object_ball_value": 0}),
		"long_rail_route": _score_expectation(0, 1.0, 0, {"base_object_ball_value": 0}),
	}


static func _score_expectation(
	haul: int,
	mult: float,
	shot_score: int,
	source_counts: Dictionary
) -> Dictionary:
	return {
		"base_haul": haul,
		"final_haul": haul,
		"base_mult": 1.0,
		"mult_before_xmult": mult,
		"xmult_product": 1.0,
		"final_mult": mult,
		"shot_score": shot_score,
		"source_counts": source_counts.duplicate(true),
	}


static func _role_reference(role: String, power: float, preflight: Dictionary) -> Dictionary:
	return _reference(AIM_ROLE_CENTER, power, {"aim_role": role}, preflight)


static func _role_offset_reference(
	role: String,
	offset_world: Vector2,
	power: float,
	preflight: Dictionary
) -> Dictionary:
	return _reference(AIM_ROLE_OFFSET, power, {
		"aim_role": role,
		"aim_offset_world": offset_world,
	}, preflight)


static func _point_reference(point: Vector2, power: float, preflight: Dictionary) -> Dictionary:
	return _reference(AIM_NORMALIZED_PLAYFIELD_POINT, power, {"aim_point": point}, preflight)


static func _pocket_reference(pocket_index: int, power: float, preflight: Dictionary) -> Dictionary:
	return _reference(AIM_POCKET_CENTER, power, {"pocket_index": pocket_index}, preflight)


static func _reference(
	aim_type: String,
	power: float,
	aim_fields: Dictionary,
	preflight: Dictionary
) -> Dictionary:
	var reference: Dictionary = {
		"enabled": true,
		"aim_type": aim_type,
		"power_normalized": clampf(power, 0.0, 1.0),
		"preflight": preflight,
	}
	reference.merge(aim_fields, true)
	return reference


static func _preflight(
	expected_first_contact_role: String,
	expected_pocket_roles: Array[String],
	expected_scratch: bool,
	failure_policy: String,
	expect_no_first_contact: bool = false,
	require_different_pockets: bool = false,
	require_same_pocket: bool = false
) -> Dictionary:
	return {
		"expected_first_contact_role": expected_first_contact_role,
		"expect_no_first_contact": expect_no_first_contact,
		"expected_pocket_roles": expected_pocket_roles,
		"expected_scratch": expected_scratch,
		"require_different_pockets": require_different_pockets,
		"require_same_pocket": require_same_pocket,
		"failure_policy": failure_policy,
	}


static func _ball(
	role: String,
	ball_kind: String,
	position: Vector2,
	ball_number: int = -1
) -> Dictionary:
	return {
		"role": role,
		"ball_kind": ball_kind,
		"ball_number": ball_number,
		"position": position,
	}


static func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}
