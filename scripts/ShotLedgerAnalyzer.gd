extends RefCounted
class_name ShotLedgerAnalyzer

const SELF_TEST_CASE_COUNT := 13

# Pure semantic analysis for authoritative and future predicted shot ledgers.
# This script owns no Nodes and never mutates the supplied raw ledger.
const SCHEMA_VERSION := 1
const TAG_IDS: Array[String] = [
	"direct_pot",
	"bank",
	"double_bank",
	"triple_bank_plus",
	"combination",
	"multi_pot",
	"same_pocket_streak",
	"scratch",
	"miss",
	"kick",
]


static func analyze(raw_ledger: Dictionary) -> Dictionary:
	var starting_balls: Dictionary = _dictionary_value(raw_ledger, "starting_balls")
	var ending_balls: Dictionary = _dictionary_value(raw_ledger, "ending_balls")
	var raw_events: Array = _array_value(raw_ledger, "raw_events")
	var cue_ball_id: int = int(raw_ledger.get("cue_ball_id", -1))

	var semantic_events: Array[Dictionary] = []
	var semantic_ball_contacts: Array[Dictionary] = []
	var rail_events_by_ball: Dictionary = {}
	var pocket_events: Array[Dictionary] = []
	var pocket_event_by_ball: Dictionary = {}
	var ignored_nonsemantic_ball_contacts := 0
	var ignored_duplicate_pockets := 0
	for event_value in raw_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var event_type: String = str(event.get("event_type", ""))
		match event_type:
			"ball_contact":
				if not bool(event.get("accepted_impact", false)):
					ignored_nonsemantic_ball_contacts += 1
					continue
				semantic_events.append(event)
				semantic_ball_contacts.append(event)
			"rail_contact":
				semantic_events.append(event)
				var rail_ball_key: String = str(int(event.get("ball_id", -1)))
				if not rail_events_by_ball.has(rail_ball_key):
					rail_events_by_ball[rail_ball_key] = []
				var ball_rail_events: Array = rail_events_by_ball[rail_ball_key]
				ball_rail_events.append(event)
			"pocket":
				var pocket_ball_key: String = str(int(event.get("ball_id", -1)))
				if pocket_event_by_ball.has(pocket_ball_key):
					ignored_duplicate_pockets += 1
					continue
				semantic_events.append(event)
				pocket_events.append(event)
				pocket_event_by_ball[pocket_ball_key] = event

	var causal_parent_by_ball: Dictionary = {}
	var causal_depth_by_ball: Dictionary = {}
	var causal_activation_event_by_ball: Dictionary = {}
	var ambiguous_ball_ids: Dictionary = {}
	var ambiguous_event_indices: Array[int] = []
	if cue_ball_id >= 0:
		causal_depth_by_ball[str(cue_ball_id)] = 0

	var first_object_contact_ball_id := -1
	var first_object_contact_event_index := -1
	var unique_contact_pairs: Dictionary = {}
	for event in semantic_ball_contacts:
		var ball_a_id: int = int(event.get("ball_a_id", -1))
		var ball_b_id: int = int(event.get("ball_b_id", -1))
		var event_index: int = int(event.get("event_index", -1))
		if ball_a_id >= 0 and ball_b_id >= 0:
			unique_contact_pairs[_pair_key(ball_a_id, ball_b_id)] = true

		if first_object_contact_event_index < 0:
			var contacted_object_id: int = _get_cue_contacted_object_id(
				cue_ball_id,
				ball_a_id,
				ball_b_id,
				starting_balls
			)
			if contacted_object_id >= 0:
				first_object_contact_ball_id = contacted_object_id
				first_object_contact_event_index = event_index

		var source_ball_id: int = int(event.get("source_ball_id", -1))
		var target_ball_id: int = int(event.get("target_ball_id", -1))
		if source_ball_id < 0 or target_ball_id < 0:
			ambiguous_event_indices.append(event_index)
			_mark_unactivated_ball_ambiguous(ball_a_id, cue_ball_id, causal_depth_by_ball, ambiguous_ball_ids)
			_mark_unactivated_ball_ambiguous(ball_b_id, cue_ball_id, causal_depth_by_ball, ambiguous_ball_ids)
			continue

		var source_key: String = str(source_ball_id)
		var target_key: String = str(target_ball_id)
		if causal_depth_by_ball.has(source_key) and not causal_depth_by_ball.has(target_key):
			causal_parent_by_ball[target_key] = source_ball_id
			causal_depth_by_ball[target_key] = int(causal_depth_by_ball[source_key]) + 1
			causal_activation_event_by_ball[target_key] = event_index

	var rail_contacts_by_ball: Dictionary = {}
	for ball_key_value in rail_events_by_ball.keys():
		var ball_key: String = str(ball_key_value)
		var rail_events: Array = rail_events_by_ball[ball_key]
		rail_contacts_by_ball[ball_key] = rail_events.size()

	var object_balls_pocketed: Array[int] = []
	var pocket_order: Array[int] = []
	var pocket_index_by_ball: Dictionary = {}
	var same_pocket_counts: Dictionary = {}
	var last_object_pocket_event_by_index: Dictionary = {}
	var scratch_occurred := false
	var cue_ball_pocket_event_index := -1
	for pocket_event in pocket_events:
		var pocketed_ball_id: int = int(pocket_event.get("ball_id", -1))
		var pocket_index: int = int(pocket_event.get("pocket_index", -1))
		var event_index: int = int(pocket_event.get("event_index", -1))
		pocket_order.append(pocketed_ball_id)
		pocket_index_by_ball[str(pocketed_ball_id)] = pocket_index
		if pocketed_ball_id == cue_ball_id or str(pocket_event.get("ball_kind", "")) == "cue":
			scratch_occurred = true
			cue_ball_pocket_event_index = event_index
		if not bool(pocket_event.get("counts_as_object_ball", false)):
			continue
		object_balls_pocketed.append(pocketed_ball_id)
		var pocket_key: String = str(pocket_index)
		same_pocket_counts[pocket_key] = int(same_pocket_counts.get(pocket_key, 0)) + 1
		last_object_pocket_event_by_index[pocket_key] = event_index

	var rail_contacts_before_pocket_by_ball: Dictionary = {}
	var pocket_facts: Array[Dictionary] = []
	var tags: Array[Dictionary] = []
	var maximum_bank_count := 0
	var object_pocket_order := 0
	for pocket_event in pocket_events:
		if not bool(pocket_event.get("counts_as_object_ball", false)):
			continue
		object_pocket_order += 1
		var ball_id: int = int(pocket_event.get("ball_id", -1))
		var ball_key: String = str(ball_id)
		var pocket_event_index: int = int(pocket_event.get("event_index", -1))
		var activation_event_index: int = int(causal_activation_event_by_ball.get(ball_key, -1))
		var all_rail_events: Array = rail_events_by_ball.get(ball_key, [])
		var rails_before_pocket := 0
		var rails_after_activation := 0
		var unique_rails: Dictionary = {}
		for rail_event_value in all_rail_events:
			if not rail_event_value is Dictionary:
				continue
			var rail_event: Dictionary = rail_event_value
			var rail_event_index: int = int(rail_event.get("event_index", -1))
			if rail_event_index >= pocket_event_index:
				continue
			rails_before_pocket += 1
			if activation_event_index >= 0 and rail_event_index > activation_event_index:
				rails_after_activation += 1
				unique_rails[str(rail_event.get("rail_id", ""))] = true
		rail_contacts_before_pocket_by_ball[ball_key] = rails_before_pocket
		maximum_bank_count = maxi(maximum_bank_count, rails_after_activation)

		var causal_depth: int = int(causal_depth_by_ball.get(ball_key, -1))
		var is_direct_pot: bool = causal_depth == 1 and rails_after_activation == 0
		var is_combination_pot: bool = causal_depth >= 2
		var bank_class: String = _get_bank_class(rails_after_activation)
		var rails_list: Array[String] = []
		for rail_id_value in unique_rails.keys():
			rails_list.append(str(rail_id_value))
		rails_list.sort()
		var start_snapshot: Dictionary = _get_ball_snapshot(starting_balls, ball_id)
		var end_snapshot: Dictionary = _get_ball_snapshot(ending_balls, ball_id)
		var pocket_fact: Dictionary = {
			"ball_id": ball_id,
			"ball_number": int(start_snapshot.get("ball_number", -1)),
			"pocket_order": object_pocket_order,
			"pocket_event_index": pocket_event_index,
			"pocket_index": int(pocket_event.get("pocket_index", -1)),
			"causal_parent_ball_id": int(causal_parent_by_ball.get(ball_key, -1)),
			"causal_depth": causal_depth,
			"causal_activation_event_index": activation_event_index,
			"rail_contacts_after_activation": rails_after_activation,
			"rail_contacts_before_pocket": rails_before_pocket,
			"unique_rails_before_pocket": rails_list,
			"travel_distance": float(end_snapshot.get("travel_distance", 0.0)),
			"is_direct_pot": is_direct_pot,
			"is_combination_pot": is_combination_pot,
			"bank_count": rails_after_activation,
			"bank_class": bank_class,
		}
		pocket_facts.append(pocket_fact)
		if is_direct_pot:
			tags.append(_make_tag("direct_pot", pocket_event_index, ball_id))
		if rails_after_activation == 1:
			tags.append(_make_tag("bank", pocket_event_index, ball_id, {"bank_count": 1}))
		elif rails_after_activation == 2:
			tags.append(_make_tag("double_bank", pocket_event_index, ball_id, {"bank_count": 2}))
		elif rails_after_activation >= 3:
			tags.append(_make_tag("triple_bank_plus", pocket_event_index, ball_id, {"bank_count": rails_after_activation}))
		if is_combination_pot:
			tags.append(_make_tag("combination", pocket_event_index, ball_id, {"causal_depth": causal_depth}))

	if object_balls_pocketed.size() >= 2:
		var multi_event_index: int = _last_object_pocket_event_index(pocket_events)
		tags.append(_make_tag("multi_pot", multi_event_index, -1, {"count": object_balls_pocketed.size()}))
	for pocket_key_value in same_pocket_counts.keys():
		var pocket_key: String = str(pocket_key_value)
		var streak_count: int = int(same_pocket_counts[pocket_key_value])
		if streak_count < 2:
			continue
		tags.append(_make_tag(
			"same_pocket_streak",
			int(last_object_pocket_event_by_index.get(pocket_key, -1)),
			-1,
			{"pocket_index": int(pocket_key), "count": streak_count}
		))

	if scratch_occurred:
		tags.append(_make_tag("scratch", cue_ball_pocket_event_index, cue_ball_id))
	if object_balls_pocketed.is_empty():
		tags.append(_make_tag("miss", _last_event_index(semantic_events), -1))

	var cue_rails_before_first_contact := 0
	var first_cue_rail_event_index := -1
	var cue_rail_events: Array = rail_events_by_ball.get(str(cue_ball_id), [])
	for rail_event_value in cue_rail_events:
		if not rail_event_value is Dictionary:
			continue
		var rail_event: Dictionary = rail_event_value
		var rail_event_index: int = int(rail_event.get("event_index", -1))
		if first_object_contact_event_index >= 0 and rail_event_index < first_object_contact_event_index:
			cue_rails_before_first_contact += 1
			if first_cue_rail_event_index < 0:
				first_cue_rail_event_index = rail_event_index
	if cue_rails_before_first_contact > 0:
		tags.append(_make_tag("kick", first_cue_rail_event_index, cue_ball_id, {"rail_count": cue_rails_before_first_contact}))

	tags.sort_custom(_tag_precedes)
	var tag_counts: Dictionary = {}
	for tag_id in TAG_IDS:
		tag_counts[tag_id] = 0
	for tag in tags:
		var tag_id: String = str(tag.get("tag_id", ""))
		tag_counts[tag_id] = int(tag_counts.get(tag_id, 0)) + int(tag.get("count", 1))

	var maximum_causal_depth := 0
	for depth_value in causal_depth_by_ball.values():
		maximum_causal_depth = maxi(maximum_causal_depth, int(depth_value))

	var largest_same_pocket_count := 0
	for count_value in same_pocket_counts.values():
		largest_same_pocket_count = maxi(largest_same_pocket_count, int(count_value))

	var total_object_ball_travel_distance := 0.0
	var cue_ball_travel_distance := 0.0
	var balls_remaining_at_end := 0
	var active_object_balls_remaining := 0
	for ball_key_value in ending_balls.keys():
		var ending_snapshot_value: Variant = ending_balls[ball_key_value]
		if not ending_snapshot_value is Dictionary:
			continue
		var ending_snapshot: Dictionary = ending_snapshot_value
		var ball_id: int = int(ending_snapshot.get("ball_id", int(str(ball_key_value))))
		var travel_distance: float = maxf(float(ending_snapshot.get("travel_distance", 0.0)), 0.0)
		var start_snapshot: Dictionary = _get_ball_snapshot(starting_balls, ball_id)
		if ball_id == cue_ball_id:
			cue_ball_travel_distance = travel_distance
		elif bool(start_snapshot.get("counts_as_object_ball", false)):
			total_object_ball_travel_distance += travel_distance
		if bool(ending_snapshot.get("active", false)):
			balls_remaining_at_end += 1
			if bool(start_snapshot.get("counts_as_object_ball", false)):
				active_object_balls_remaining += 1

	var ambiguous_causality_ball_ids: Array[int] = []
	for ball_id_value in ambiguous_ball_ids.keys():
		ambiguous_causality_ball_ids.append(int(ball_id_value))
	ambiguous_causality_ball_ids.sort()
	var unique_ball_contact_pairs: Array[String] = []
	for pair_value in unique_contact_pairs.keys():
		unique_ball_contact_pairs.append(str(pair_value))
	unique_ball_contact_pairs.sort()

	return {
		"schema_version": SCHEMA_VERSION,
		"source": str(raw_ledger.get("source", "")),
		"first_object_contact_ball_id": first_object_contact_ball_id,
		"first_object_contact_event_index": first_object_contact_event_index,
		"cue_rails_before_first_object_contact": cue_rails_before_first_contact,
		"object_balls_pocketed": object_balls_pocketed,
		"object_ball_pocket_count": object_balls_pocketed.size(),
		"pocket_order": pocket_order,
		"pocket_index_by_ball": pocket_index_by_ball,
		"scratch_occurred": scratch_occurred,
		"cue_ball_pocket_event_index": cue_ball_pocket_event_index,
		"rail_contacts_by_ball": rail_contacts_by_ball,
		"rail_contacts_before_pocket_by_ball": rail_contacts_before_pocket_by_ball,
		"unique_ball_contact_pairs": unique_ball_contact_pairs,
		"semantic_ball_contact_count": semantic_ball_contacts.size(),
		"semantic_rail_contact_count": _count_rail_events(rail_events_by_ball),
		"causal_parent_by_ball": causal_parent_by_ball,
		"causal_depth_by_ball": causal_depth_by_ball,
		"causal_activation_event_by_ball": causal_activation_event_by_ball,
		"ambiguous_causality_ball_ids": ambiguous_causality_ball_ids,
		"maximum_causal_depth": maximum_causal_depth,
		"maximum_bank_count": maximum_bank_count,
		"same_pocket_counts": same_pocket_counts,
		"largest_same_pocket_count": largest_same_pocket_count,
		"total_object_ball_travel_distance": total_object_ball_travel_distance,
		"cue_ball_travel_distance": cue_ball_travel_distance,
		"balls_remaining_at_end": balls_remaining_at_end,
		"active_object_balls_remaining": active_object_balls_remaining,
		"pocket_facts": pocket_facts,
		"tags": tags,
		"tag_counts": tag_counts,
		"diagnostics": {
			"ambiguous_causality_event_indices": ambiguous_event_indices,
			"ignored_nonsemantic_ball_contacts": ignored_nonsemantic_ball_contacts,
			"ignored_duplicate_pockets": ignored_duplicate_pockets,
		},
	}


static func run_self_tests() -> Dictionary:
	var results: Array[Dictionary] = []
	_run_case(results, "DIRECT POT", _test_direct_pot())
	_run_case(results, "ONE-RAIL BANK", _test_one_rail_bank())
	_run_case(results, "DOUBLE BANK", _test_double_bank())
	_run_case(results, "COMBINATION", _test_combination())
	_run_case(results, "BANK COMBINATION", _test_bank_combination())
	_run_case(results, "MULTI POT", _test_multi_pot())
	_run_case(results, "SAME-POCKET STREAK", _test_same_pocket_streak())
	_run_case(results, "KICK", _test_kick())
	_run_case(results, "SCRATCH", _test_scratch())
	_run_case(results, "MISS", _test_miss())
	_run_case(results, "VALID RE-CONTACT", _test_valid_recontact())
	_run_case(results, "SUSTAINED OVERLAP", _test_sustained_overlap())
	_run_case(results, "AMBIGUOUS CAUSALITY", _test_ambiguous_causality())

	var passed_count := 0
	var failures: Array[String] = []
	for result in results:
		if bool(result.get("passed", false)):
			passed_count += 1
		else:
			var errors: Array = result.get("failures", [])
			for error_value in errors:
				failures.append("%s: %s" % [str(result.get("name", "Test")), str(error_value)])
	return {
		"passed_count": passed_count,
		"failed_count": results.size() - passed_count,
		"total_count": results.size(),
		"declared_total_count": SELF_TEST_CASE_COUNT,
		"passed": passed_count == results.size(),
		"failures": failures,
		"tests": results,
	}


static func _test_direct_pot() -> Array[String]:
	var ledger: Dictionary = _make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_pocket(1, 2, 0, true),
	])
	var derived: Dictionary = analyze(ledger)
	var failures: Array[String] = []
	_expect(failures, "depth", _depth(derived, 2), 1)
	_expect(failures, "direct tag", _tag_count(derived, "direct_pot"), 1)
	_expect(failures, "bank count", _pocket_fact_int(derived, 2, "bank_count"), 0)
	return failures


static func _test_one_rail_bank() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), _rail(1, 2, "left"), _pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "bank count", _pocket_fact_int(derived, 2, "bank_count"), 1)
	_expect(failures, "bank tag", _tag_count(derived, "bank"), 1)
	return failures


static func _test_double_bank() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), _rail(1, 2, "left"), _rail(2, 2, "top"), _pocket(3, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "bank count", _pocket_fact_int(derived, 2, "bank_count"), 2)
	_expect(failures, "double bank tag", _tag_count(derived, "double_bank"), 1)
	return failures


static func _test_combination() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), _contact(1, 2, 3, 2, 3), _pocket(2, 3, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "depth", _depth(derived, 3), 2)
	_expect(failures, "combination tag", _tag_count(derived, "combination"), 1)
	return failures


static func _test_bank_combination() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), _contact(1, 2, 3, 2, 3), _rail(2, 3, "bottom"), _pocket(3, 3, 1, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "combination tag", _tag_count(derived, "combination"), 1)
	_expect(failures, "bank tag", _tag_count(derived, "bank"), 1)
	return failures


static func _test_multi_pot() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), _pocket(1, 2, 0, true),
		_contact(2, 1, 3, 1, 3), _pocket(3, 3, 1, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "object pockets", int(derived.get("object_ball_pocket_count", 0)), 2)
	_expect(failures, "multi-pot tag", _tag_count(derived, "multi_pot"), 1)
	return failures


static func _test_same_pocket_streak() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), _pocket(1, 2, 4, true),
		_contact(2, 1, 3, 1, 3), _pocket(3, 3, 4, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "same-pocket maximum", int(derived.get("largest_same_pocket_count", 0)), 2)
	_expect(failures, "same-pocket tag", _tag_count(derived, "same_pocket_streak"), 1)
	return failures


static func _test_kick() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_rail(0, 1, "top"), _contact(1, 1, 2, 1, 2), _pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "kick tag", _tag_count(derived, "kick"), 1)
	return failures


static func _test_scratch() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([_pocket(0, 1, 0, false, "cue")]))
	var failures: Array[String] = []
	_expect(failures, "scratch", bool(derived.get("scratch_occurred", false)), true)
	_expect(failures, "scratch tag", _tag_count(derived, "scratch"), 1)
	return failures


static func _test_miss() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([_contact(0, 1, 2, 1, 2)]))
	var failures: Array[String] = []
	_expect(failures, "miss tag", _tag_count(derived, "miss"), 1)
	return failures


static func _test_valid_recontact() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), _contact(1, 1, 2, 1, 2),
	]))
	var failures: Array[String] = []
	_expect(failures, "semantic contacts", int(derived.get("semantic_ball_contact_count", 0)), 2)
	_expect(failures, "unique pairs", _array_value(derived, "unique_ball_contact_pairs").size(), 1)
	return failures


static func _test_sustained_overlap() -> Array[String]:
	var rejected: Dictionary = _contact(1, 1, 2, -1, -1)
	rejected["accepted_impact"] = false
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), rejected,
	]))
	var failures: Array[String] = []
	_expect(failures, "semantic contacts", int(derived.get("semantic_ball_contact_count", 0)), 1)
	var diagnostics: Dictionary = _dictionary_value(derived, "diagnostics")
	_expect(failures, "ignored overlap", int(diagnostics.get("ignored_nonsemantic_ball_contacts", 0)), 1)
	return failures


static func _test_ambiguous_causality() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 2, 3, -1, -1), _pocket(1, 3, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "contact retained", int(derived.get("semantic_ball_contact_count", 0)), 1)
	_expect(failures, "no invented depth", _depth(derived, 3), -1)
	var ambiguous: Array = _array_value(derived, "ambiguous_causality_ball_ids")
	_expect(failures, "ambiguity reported", ambiguous.has(3), true)
	return failures


static func _make_test_ledger(events: Array) -> Dictionary:
	var starting_balls: Dictionary = {
		"1": _ball_snapshot(1, -1, "cue", false),
		"2": _ball_snapshot(2, 2, "object", true),
		"3": _ball_snapshot(3, 3, "object", true),
	}
	var ending_balls: Dictionary = {
		"1": _ending_snapshot(1, true),
		"2": _ending_snapshot(2, not _events_pocket_ball(events, 2)),
		"3": _ending_snapshot(3, not _events_pocket_ball(events, 3)),
	}
	return {
		"schema_version": SCHEMA_VERSION,
		"source": "authoritative",
		"cue_ball_id": 1,
		"starting_balls": starting_balls,
		"raw_events": events,
		"ending_balls": ending_balls,
	}


static func _ball_snapshot(ball_id: int, ball_number: int, ball_kind: String, counts_as_object: bool) -> Dictionary:
	return {
		"ball_id": ball_id,
		"ball_number": ball_number,
		"ball_kind": ball_kind,
		"counts_as_object_ball": counts_as_object,
	}


static func _ending_snapshot(ball_id: int, active: bool) -> Dictionary:
	return {
		"ball_id": ball_id,
		"active": active,
		"pocketed": not active,
		"travel_distance": 10.0,
	}


static func _contact(index: int, ball_a_id: int, ball_b_id: int, source_id: int, target_id: int) -> Dictionary:
	return {
		"event_index": index,
		"event_type": "ball_contact",
		"ball_a_id": ball_a_id,
		"ball_b_id": ball_b_id,
		"source_ball_id": source_id,
		"target_ball_id": target_id,
		"accepted_impact": true,
	}


static func _rail(index: int, ball_id: int, rail_id: String) -> Dictionary:
	return {
		"event_index": index,
		"event_type": "rail_contact",
		"ball_id": ball_id,
		"rail_id": rail_id,
	}


static func _pocket(index: int, ball_id: int, pocket_index: int, counts_as_object: bool, ball_kind: String = "object") -> Dictionary:
	return {
		"event_index": index,
		"event_type": "pocket",
		"ball_id": ball_id,
		"pocket_index": pocket_index,
		"ball_kind": ball_kind,
		"counts_as_object_ball": counts_as_object,
	}


static func _events_pocket_ball(events: Array, ball_id: int) -> bool:
	for event_value in events:
		if event_value is Dictionary:
			var event: Dictionary = event_value
			if str(event.get("event_type", "")) == "pocket" and int(event.get("ball_id", -1)) == ball_id:
				return true
	return false


static func _run_case(results: Array[Dictionary], test_name: String, failures: Array[String]) -> void:
	results.append({"name": test_name, "passed": failures.is_empty(), "failures": failures})


static func _expect(failures: Array[String], label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		failures.append("%s expected %s, received %s" % [label, str(expected), str(actual)])


static func _depth(derived: Dictionary, ball_id: int) -> int:
	return int(_dictionary_value(derived, "causal_depth_by_ball").get(str(ball_id), -1))


static func _tag_count(derived: Dictionary, tag_id: String) -> int:
	return int(_dictionary_value(derived, "tag_counts").get(tag_id, 0))


static func _pocket_fact_int(derived: Dictionary, ball_id: int, field: String) -> int:
	for fact_value in _array_value(derived, "pocket_facts"):
		if fact_value is Dictionary:
			var fact: Dictionary = fact_value
			if int(fact.get("ball_id", -1)) == ball_id:
				return int(fact.get(field, -1))
	return -1


static func _get_ball_snapshot(ball_snapshots: Dictionary, ball_id: int) -> Dictionary:
	var snapshot_value: Variant = ball_snapshots.get(str(ball_id), {})
	if snapshot_value is Dictionary:
		return snapshot_value
	return {}


static func _get_cue_contacted_object_id(
	cue_ball_id: int,
	ball_a_id: int,
	ball_b_id: int,
	starting_balls: Dictionary
) -> int:
	if ball_a_id == cue_ball_id and bool(_get_ball_snapshot(starting_balls, ball_b_id).get("counts_as_object_ball", false)):
		return ball_b_id
	if ball_b_id == cue_ball_id and bool(_get_ball_snapshot(starting_balls, ball_a_id).get("counts_as_object_ball", false)):
		return ball_a_id
	return -1


static func _mark_unactivated_ball_ambiguous(
	ball_id: int,
	cue_ball_id: int,
	causal_depth_by_ball: Dictionary,
	ambiguous_ball_ids: Dictionary
) -> void:
	if ball_id < 0 or ball_id == cue_ball_id or causal_depth_by_ball.has(str(ball_id)):
		return
	ambiguous_ball_ids[ball_id] = true


static func _get_bank_class(bank_count: int) -> String:
	if bank_count == 1:
		return "bank"
	if bank_count == 2:
		return "double_bank"
	if bank_count >= 3:
		return "triple_bank_plus"
	return "none"


static func _make_tag(
	tag_id: String,
	event_index: int,
	ball_id: int,
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"tag_id": tag_id,
		"event_index": event_index,
		"ball_id": ball_id,
		"count": 1,
		"metadata": metadata.duplicate(true),
	}


static func _tag_precedes(left_value: Variant, right_value: Variant) -> bool:
	var left: Dictionary = left_value if left_value is Dictionary else {}
	var right: Dictionary = right_value if right_value is Dictionary else {}
	var left_index: int = int(left.get("event_index", -1))
	var right_index: int = int(right.get("event_index", -1))
	if left_index == right_index:
		return str(left.get("tag_id", "")) < str(right.get("tag_id", ""))
	return left_index < right_index


static func _last_object_pocket_event_index(pocket_events: Array[Dictionary]) -> int:
	var last_index := -1
	for event in pocket_events:
		if bool(event.get("counts_as_object_ball", false)):
			last_index = maxi(last_index, int(event.get("event_index", -1)))
	return last_index


static func _last_event_index(events: Array[Dictionary]) -> int:
	var last_index := -1
	for event in events:
		last_index = maxi(last_index, int(event.get("event_index", -1)))
	return last_index


static func _count_rail_events(rail_events_by_ball: Dictionary) -> int:
	var count := 0
	for events_value in rail_events_by_ball.values():
		if events_value is Array:
			count += (events_value as Array).size()
	return count


static func _pair_key(ball_a_id: int, ball_b_id: int) -> String:
	return "%d:%d" % [mini(ball_a_id, ball_b_id), maxi(ball_a_id, ball_b_id)]


static func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	if value is Dictionary:
		return value
	return {}


static func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	if value is Array:
		return value
	return []
