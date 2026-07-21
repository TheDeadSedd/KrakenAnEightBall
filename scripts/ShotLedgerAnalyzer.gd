extends RefCounted
class_name ShotLedgerAnalyzer

const SELF_TEST_CASE_COUNT := 27

# Pure semantic analysis for authoritative and future predicted shot ledgers.
# This script owns no Nodes and never mutates the supplied raw ledger.
const SCHEMA_VERSION := 2
const CONTACT_DIRECTION_EPSILON := 0.01
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
	"cue_recontact_milestone",
	"object_ball_tap_milestone",
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
	var cue_recontact_milestones: Array[Dictionary] = []
	var object_ball_tap_milestones: Array[Dictionary] = []
	var double_tap_scoring_ball_ids: Array[int] = []
	var triple_tap_plus_scoring_ball_ids: Array[int] = []
	var ball_tap_scoring_ball_ids: Array[int] = []
	var ambiguous_cue_contact_event_set: Dictionary = {}
	var ambiguous_object_tap_event_set: Dictionary = {}
	var maximum_qualifying_cue_strike_count := 0
	var maximum_unique_object_tap_count := 0
	var repeated_object_tap_contact_count := 0
	var safely_resolved_ambiguous_cue_contact_count := 0
	var direct_pot_tap_disqualification_count := 0
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
		var qualifying_rail_event_indices: Array[int] = []
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
				qualifying_rail_event_indices.append(rail_event_index)
				unique_rails[str(rail_event.get("rail_id", ""))] = true
		rail_contacts_before_pocket_by_ball[ball_key] = rails_before_pocket
		maximum_bank_count = maxi(maximum_bank_count, rails_after_activation)

		var causal_depth: int = int(causal_depth_by_ball.get(ball_key, -1))
		var is_combination_pot: bool = causal_depth >= 2
		var bank_class: String = _get_bank_class(rails_after_activation)
		var rails_list: Array[String] = []
		for rail_id_value in unique_rails.keys():
			rails_list.append(str(rail_id_value))
		rails_list.sort()
		var start_snapshot: Dictionary = _get_ball_snapshot(starting_balls, ball_id)
		var end_snapshot: Dictionary = _get_ball_snapshot(ending_balls, ball_id)
		var contact_facts: Dictionary = _analyze_pocketed_ball_contacts(
			ball_id,
			int(start_snapshot.get("ball_number", -1)),
			cue_ball_id,
			activation_event_index,
			pocket_event_index,
			semantic_ball_contacts,
			starting_balls
		)
		var qualifying_cue_strike_count: int = int(
			contact_facts.get("qualifying_cue_strike_count", 0)
		)
		var unique_object_tap_count: int = int(contact_facts.get("unique_object_tap_count", 0))
		var direct_pot_disqualifiers: Array[String] = _get_direct_pot_disqualifiers(
			causal_depth,
			is_combination_pot,
			rails_after_activation,
			contact_facts
		)
		var is_depth1_zero_rail_pot: bool = causal_depth == 1 and rails_after_activation == 0
		var is_direct_pot: bool = direct_pot_disqualifiers.is_empty()
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
			"qualifying_rail_event_indices": qualifying_rail_event_indices.duplicate(),
			"rail_contacts_before_pocket": rails_before_pocket,
			"unique_rails_before_pocket": rails_list,
			"travel_distance": float(end_snapshot.get("travel_distance", 0.0)),
			"is_depth1_zero_rail_pot": is_depth1_zero_rail_pot,
			"is_direct_pot": is_direct_pot,
			"direct_pot_disqualifiers": direct_pot_disqualifiers.duplicate(),
			"is_combination_pot": is_combination_pot,
			"bank_count": rails_after_activation,
			"bank_class": bank_class,
		}
		pocket_fact.merge(contact_facts, true)
		pocket_facts.append(pocket_fact)
		maximum_qualifying_cue_strike_count = maxi(
			maximum_qualifying_cue_strike_count,
			qualifying_cue_strike_count
		)
		maximum_unique_object_tap_count = maxi(maximum_unique_object_tap_count, unique_object_tap_count)
		repeated_object_tap_contact_count += int(
			contact_facts.get("repeated_object_tap_contact_count", 0)
		)
		safely_resolved_ambiguous_cue_contact_count += int(
			contact_facts.get("safely_resolved_ambiguous_cue_contact_count", 0)
		)
		if qualifying_cue_strike_count >= 2:
			double_tap_scoring_ball_ids.append(ball_id)
		if qualifying_cue_strike_count >= 3:
			triple_tap_plus_scoring_ball_ids.append(ball_id)
		if unique_object_tap_count > 0:
			ball_tap_scoring_ball_ids.append(ball_id)
		if direct_pot_disqualifiers.has("cue_recontact") or direct_pot_disqualifiers.has("ball_tap"):
			direct_pot_tap_disqualification_count += 1
		for event_index_value in _array_value(contact_facts, "ambiguous_cue_contact_event_indices"):
			ambiguous_cue_contact_event_set[int(event_index_value)] = true
		for event_index_value in _array_value(contact_facts, "ambiguous_object_tap_event_indices"):
			ambiguous_object_tap_event_set[int(event_index_value)] = true
		for milestone_value in _array_value(contact_facts, "cue_recontact_milestones"):
			if not milestone_value is Dictionary:
				continue
			var milestone: Dictionary = (milestone_value as Dictionary).duplicate(true)
			cue_recontact_milestones.append(milestone)
			tags.append(_make_tag(
				"cue_recontact_milestone",
				int(milestone.get("event_index", -1)),
				ball_id,
				_dictionary_value(milestone, "metadata")
			))
		for milestone_value in _array_value(contact_facts, "object_ball_tap_milestones"):
			if not milestone_value is Dictionary:
				continue
			var milestone: Dictionary = (milestone_value as Dictionary).duplicate(true)
			object_ball_tap_milestones.append(milestone)
			tags.append(_make_tag(
				"object_ball_tap_milestone",
				int(milestone.get("event_index", -1)),
				ball_id,
				_dictionary_value(milestone, "metadata")
			))
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
	var ambiguous_cue_contact_event_indices: Array[int] = _sorted_int_keys(
		ambiguous_cue_contact_event_set
	)
	var ambiguous_object_tap_event_indices: Array[int] = _sorted_int_keys(
		ambiguous_object_tap_event_set
	)
	var ambiguous_qualifying_contact_rejection_count: int = (
		ambiguous_cue_contact_event_indices.size()
		+ ambiguous_object_tap_event_indices.size()
	)

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
		"cue_recontact_milestones": cue_recontact_milestones.duplicate(true),
		"cue_recontact_milestone_count": cue_recontact_milestones.size(),
		"total_cue_recontact_milestones": cue_recontact_milestones.size(),
		"maximum_qualifying_cue_strike_count": maximum_qualifying_cue_strike_count,
		"maximum_cue_strikes_against_one_scoring_ball": maximum_qualifying_cue_strike_count,
		"double_tap_scoring_ball_ids": double_tap_scoring_ball_ids.duplicate(),
		"double_tap_scoring_ball_count": double_tap_scoring_ball_ids.size(),
		"scoring_balls_with_double_tap": double_tap_scoring_ball_ids.size(),
		"triple_tap_plus_scoring_ball_ids": triple_tap_plus_scoring_ball_ids.duplicate(),
		"triple_tap_plus_scoring_ball_count": triple_tap_plus_scoring_ball_ids.size(),
		"scoring_balls_with_triple_tap_or_higher": triple_tap_plus_scoring_ball_ids.size(),
		"object_ball_tap_milestones": object_ball_tap_milestones.duplicate(true),
		"object_ball_tap_milestone_count": object_ball_tap_milestones.size(),
		"total_unique_ball_tap_milestones": object_ball_tap_milestones.size(),
		"maximum_unique_object_tap_count": maximum_unique_object_tap_count,
		"maximum_ball_taps_by_one_scoring_ball": maximum_unique_object_tap_count,
		"ball_tap_scoring_ball_ids": ball_tap_scoring_ball_ids.duplicate(),
		"ball_tap_scoring_ball_count": ball_tap_scoring_ball_ids.size(),
		"scoring_balls_with_ball_tap": ball_tap_scoring_ball_ids.size(),
		"repeated_object_tap_contact_count": repeated_object_tap_contact_count,
		"repeated_ball_tap_contacts_ignored": repeated_object_tap_contact_count,
		"ambiguous_qualifying_contact_rejection_count": ambiguous_qualifying_contact_rejection_count,
		"ambiguous_cue_contacts_rejected": ambiguous_cue_contact_event_indices.size(),
		"ambiguous_ball_tap_contacts_rejected": ambiguous_object_tap_event_indices.size(),
		"ambiguous_tap_contacts_rejected": ambiguous_qualifying_contact_rejection_count,
		"direct_pot_tap_disqualification_count": direct_pot_tap_disqualification_count,
		"tap_direct_pot_disqualifications": direct_pot_tap_disqualification_count,
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
			"ambiguous_cue_contact_event_indices": ambiguous_cue_contact_event_indices,
			"ambiguous_object_tap_event_indices": ambiguous_object_tap_event_indices,
			"ambiguous_qualifying_contact_rejection_count": ambiguous_qualifying_contact_rejection_count,
			"ambiguous_cue_contacts_rejected": ambiguous_cue_contact_event_indices.size(),
			"ambiguous_ball_tap_contacts_rejected": ambiguous_object_tap_event_indices.size(),
			"safely_resolved_ambiguous_cue_contact_count": safely_resolved_ambiguous_cue_contact_count,
			"repeated_object_tap_contact_count": repeated_object_tap_contact_count,
			"repeated_ball_tap_contacts_ignored": repeated_object_tap_contact_count,
			"cue_recontact_milestone_count": cue_recontact_milestones.size(),
			"object_ball_tap_milestone_count": object_ball_tap_milestones.size(),
			"direct_pot_tap_disqualification_count": direct_pot_tap_disqualification_count,
			"ignored_nonsemantic_ball_contacts": ignored_nonsemantic_ball_contacts,
			"ignored_duplicate_pockets": ignored_duplicate_pockets,
		},
	}


static func _analyze_pocketed_ball_contacts(
	scoring_ball_id: int,
	ball_number: int,
	cue_ball_id: int,
	activation_event_index: int,
	pocket_event_index: int,
	semantic_ball_contacts: Array[Dictionary],
	starting_balls: Dictionary
) -> Dictionary:
	var ordered_contacts: Array[Dictionary] = []
	for event_value in semantic_ball_contacts:
		ordered_contacts.append(event_value)
	ordered_contacts.sort_custom(_contact_event_precedes)

	var qualifying_cue_contacts: Array[Dictionary] = []
	var unique_object_tap_contacts: Array[Dictionary] = []
	var unique_object_tap_ball_ids: Array[int] = []
	var unique_object_tap_set: Dictionary = {}
	var repeated_object_tap_event_indices: Array[int] = []
	var repeated_object_tap_positions: Array[Vector2] = []
	var ambiguous_cue_contact_event_indices: Array[int] = []
	var ambiguous_object_tap_event_indices: Array[int] = []
	var material_secondary_object_contact_event_indices: Array[int] = []
	var nonqualifying_post_activation_cue_contact_event_indices: Array[int] = []
	var safely_resolved_ambiguous_cue_contact_count := 0

	for event in ordered_contacts:
		var event_index: int = int(event.get("event_index", -1))
		if event_index < 0 or event_index >= pocket_event_index:
			continue
		var other_ball_id: int = _get_other_contact_ball_id(event, scoring_ball_id)
		if other_ball_id < 0:
			continue
		if other_ball_id == cue_ball_id:
			var cue_evaluation: Dictionary = _evaluate_cue_strike_direction(
				event,
				cue_ball_id,
				scoring_ball_id
			)
			if bool(cue_evaluation.get("qualified", false)):
				qualifying_cue_contacts.append({
					"event_index": event_index,
					"world_position": _get_contact_world_position(event),
					"safely_resolved_ambiguous": bool(
						cue_evaluation.get("safely_resolved_ambiguous", false)
					),
				})
				if bool(cue_evaluation.get("safely_resolved_ambiguous", false)):
					safely_resolved_ambiguous_cue_contact_count += 1
			elif bool(cue_evaluation.get("ambiguous_rejected", false)):
				ambiguous_cue_contact_event_indices.append(event_index)
			if (
				activation_event_index >= 0
				and event_index > activation_event_index
				and not bool(cue_evaluation.get("qualified", false))
			):
				nonqualifying_post_activation_cue_contact_event_indices.append(event_index)
			continue

		if not _is_authoritative_object_ball(starting_balls, other_ball_id):
			continue
		if activation_event_index < 0 or event_index <= activation_event_index:
			continue

		material_secondary_object_contact_event_indices.append(event_index)
		if _is_contact_direction_ambiguous(event):
			ambiguous_object_tap_event_indices.append(event_index)
			continue
		if (
			int(event.get("source_ball_id", -1)) != scoring_ball_id
			or int(event.get("target_ball_id", -1)) != other_ball_id
		):
			continue

		var target_key: String = str(other_ball_id)
		if unique_object_tap_set.has(target_key):
			repeated_object_tap_event_indices.append(event_index)
			repeated_object_tap_positions.append(_get_contact_world_position(event))
			continue
		unique_object_tap_set[target_key] = true
		unique_object_tap_ball_ids.append(other_ball_id)
		unique_object_tap_contacts.append({
			"event_index": event_index,
			"world_position": _get_contact_world_position(event),
			"contacted_ball_id": other_ball_id,
		})

	var qualifying_cue_strike_event_indices: Array[int] = []
	var qualifying_cue_strike_positions: Array[Vector2] = []
	for cue_contact in qualifying_cue_contacts:
		qualifying_cue_strike_event_indices.append(int(cue_contact.get("event_index", -1)))
		qualifying_cue_strike_positions.append(
			cue_contact.get("world_position", Vector2.ZERO) as Vector2
		)

	var cue_recontact_milestones: Array[Dictionary] = []
	var cue_recontact_event_indices: Array[int] = []
	var cue_recontact_positions: Array[Vector2] = []
	var qualifying_cue_strike_count: int = qualifying_cue_contacts.size()
	for cue_contact_index in range(1, qualifying_cue_strike_count):
		var cue_contact: Dictionary = qualifying_cue_contacts[cue_contact_index]
		var cue_strike_ordinal: int = cue_contact_index + 1
		var event_index: int = int(cue_contact.get("event_index", -1))
		var world_position: Vector2 = cue_contact.get("world_position", Vector2.ZERO)
		cue_recontact_event_indices.append(event_index)
		cue_recontact_positions.append(world_position)
		cue_recontact_milestones.append({
			"trigger_occurrence_id": "cue_recontact_milestone:%d:%d:%d" % [
				scoring_ball_id,
				event_index,
				cue_strike_ordinal,
			],
			"trigger_id": "cue_recontact_milestone",
			"ball_id": scoring_ball_id,
			"ball_number": ball_number,
			"event_index": event_index,
			"world_position": world_position,
			"cue_strike_ordinal": cue_strike_ordinal,
			"bonus_ordinal": cue_contact_index,
			"display_tier": _get_cue_recontact_display_tier(cue_strike_ordinal),
			"metadata": {
				"qualifying_cue_strike_count": qualifying_cue_strike_count,
				"safely_resolved_ambiguous": bool(
					cue_contact.get("safely_resolved_ambiguous", false)
				),
			},
		})

	var object_tap_event_indices: Array[int] = []
	var object_tap_positions: Array[Vector2] = []
	var object_ball_tap_milestones: Array[Dictionary] = []
	var unique_object_tap_count: int = unique_object_tap_contacts.size()
	for tap_index in range(unique_object_tap_count):
		var tap_contact: Dictionary = unique_object_tap_contacts[tap_index]
		var unique_contact_ordinal: int = tap_index + 1
		var event_index: int = int(tap_contact.get("event_index", -1))
		var world_position: Vector2 = tap_contact.get("world_position", Vector2.ZERO)
		var contacted_ball_id: int = int(tap_contact.get("contacted_ball_id", -1))
		object_tap_event_indices.append(event_index)
		object_tap_positions.append(world_position)
		object_ball_tap_milestones.append({
			"trigger_occurrence_id": "object_ball_tap_milestone:%d:%d:%d" % [
				scoring_ball_id,
				contacted_ball_id,
				event_index,
			],
			"trigger_id": "object_ball_tap_milestone",
			"ball_id": scoring_ball_id,
			"ball_number": ball_number,
			"contacted_ball_id": contacted_ball_id,
			"event_index": event_index,
			"world_position": world_position,
			"unique_contact_ordinal": unique_contact_ordinal,
			"display_tier": _get_object_tap_display_tier(unique_contact_ordinal),
			"metadata": {
				"unique_target_count": unique_object_tap_count,
				"repeated_target_contact": false,
			},
		})

	return {
		"qualifying_cue_strike_count": qualifying_cue_strike_count,
		"qualifying_cue_strike_event_indices": qualifying_cue_strike_event_indices,
		"qualifying_cue_strike_positions": qualifying_cue_strike_positions,
		"cue_recontact_bonus_count": cue_recontact_milestones.size(),
		"cue_recontact_event_indices": cue_recontact_event_indices,
		"cue_recontact_positions": cue_recontact_positions,
		"cue_recontact_milestones": cue_recontact_milestones,
		"unique_object_tap_count": unique_object_tap_count,
		"unique_object_tap_ball_ids": unique_object_tap_ball_ids,
		"object_tap_event_indices": object_tap_event_indices,
		"object_tap_positions": object_tap_positions,
		"object_ball_tap_milestones": object_ball_tap_milestones,
		"repeated_object_tap_contact_count": repeated_object_tap_event_indices.size(),
		"repeated_object_tap_event_indices": repeated_object_tap_event_indices,
		"repeated_object_tap_positions": repeated_object_tap_positions,
		"ambiguous_cue_contact_count": ambiguous_cue_contact_event_indices.size(),
		"ambiguous_cue_contact_event_indices": ambiguous_cue_contact_event_indices,
		"ambiguous_object_tap_count": ambiguous_object_tap_event_indices.size(),
		"ambiguous_object_tap_event_indices": ambiguous_object_tap_event_indices,
		"ambiguous_qualifying_contact_count": (
			ambiguous_cue_contact_event_indices.size()
			+ ambiguous_object_tap_event_indices.size()
		),
		"safely_resolved_ambiguous_cue_contact_count": safely_resolved_ambiguous_cue_contact_count,
		"material_secondary_object_contact_count": (
			material_secondary_object_contact_event_indices.size()
		),
		"material_secondary_object_contact_event_indices": (
			material_secondary_object_contact_event_indices
		),
		"nonqualifying_post_activation_cue_contact_count": (
			nonqualifying_post_activation_cue_contact_event_indices.size()
		),
		"nonqualifying_post_activation_cue_contact_event_indices": (
			nonqualifying_post_activation_cue_contact_event_indices
		),
	}


static func _get_direct_pot_disqualifiers(
	causal_depth: int,
	is_combination_pot: bool,
	rail_contacts_after_activation: int,
	contact_facts: Dictionary
) -> Array[String]:
	var disqualifiers: Array[String] = []
	if causal_depth != 1:
		disqualifiers.append("causal_depth_not_one")
	if is_combination_pot:
		disqualifiers.append("combination")
	if rail_contacts_after_activation > 0:
		disqualifiers.append("bank")
	var cue_strike_count: int = int(contact_facts.get("qualifying_cue_strike_count", 0))
	if cue_strike_count <= 0:
		disqualifiers.append("missing_qualifying_cue_strike")
	elif cue_strike_count > 1:
		disqualifiers.append("cue_recontact")
	if int(contact_facts.get("unique_object_tap_count", 0)) > 0:
		disqualifiers.append("ball_tap")
	if int(contact_facts.get("material_secondary_object_contact_count", 0)) > 0:
		disqualifiers.append("secondary_object_contact")
	if int(contact_facts.get("ambiguous_cue_contact_count", 0)) > 0:
		disqualifiers.append("ambiguous_cue_contact")
	if int(contact_facts.get("nonqualifying_post_activation_cue_contact_count", 0)) > 0:
		disqualifiers.append("secondary_cue_contact")
	return disqualifiers


static func _evaluate_cue_strike_direction(
	event: Dictionary,
	cue_ball_id: int,
	scoring_ball_id: int
) -> Dictionary:
	var source_ball_id: int = int(event.get("source_ball_id", -1))
	var target_ball_id: int = int(event.get("target_ball_id", -1))
	if not _is_contact_direction_ambiguous(event):
		return {
			"qualified": source_ball_id == cue_ball_id and target_ball_id == scoring_ball_id,
			"ambiguous_rejected": false,
			"safely_resolved_ambiguous": false,
		}
	var safely_resolved: bool = _ambiguous_contact_proves_source(
		event,
		cue_ball_id,
		scoring_ball_id
	)
	return {
		"qualified": safely_resolved,
		"ambiguous_rejected": not safely_resolved,
		"safely_resolved_ambiguous": safely_resolved,
	}


static func _ambiguous_contact_proves_source(
	event: Dictionary,
	requested_source_ball_id: int,
	requested_target_ball_id: int
) -> bool:
	var ball_a_id: int = int(event.get("ball_a_id", -1))
	var ball_b_id: int = int(event.get("ball_b_id", -1))
	if not (
		(ball_a_id == requested_source_ball_id and ball_b_id == requested_target_ball_id)
		or (ball_b_id == requested_source_ball_id and ball_a_id == requested_target_ball_id)
	):
		return false
	var normal_value: Variant = event.get("contact_normal", null)
	var velocity_a_value: Variant = event.get("pre_velocity_a", null)
	var velocity_b_value: Variant = event.get("pre_velocity_b", null)
	if not normal_value is Vector2 or not velocity_a_value is Vector2 or not velocity_b_value is Vector2:
		return false
	var normal: Vector2 = normal_value
	var velocity_a: Vector2 = velocity_a_value
	var velocity_b: Vector2 = velocity_b_value
	if not _is_finite_vector(normal) or not _is_finite_vector(velocity_a) or not _is_finite_vector(velocity_b):
		return false
	if normal.length_squared() <= 0.000001:
		return false
	normal = normal.normalized()
	var source_drive := 0.0
	var target_drive := 0.0
	if ball_a_id == requested_source_ball_id:
		source_drive = maxf(velocity_a.dot(normal), 0.0)
		target_drive = maxf(-velocity_b.dot(normal), 0.0)
	else:
		source_drive = maxf(-velocity_b.dot(normal), 0.0)
		target_drive = maxf(velocity_a.dot(normal), 0.0)
	return source_drive > CONTACT_DIRECTION_EPSILON and target_drive <= CONTACT_DIRECTION_EPSILON


static func _is_contact_direction_ambiguous(event: Dictionary) -> bool:
	if bool(event.get("causal_direction_ambiguous", false)):
		return true
	var source_ball_id: int = int(event.get("source_ball_id", -1))
	var target_ball_id: int = int(event.get("target_ball_id", -1))
	if source_ball_id < 0 or target_ball_id < 0 or source_ball_id == target_ball_id:
		return true
	var ball_a_id: int = int(event.get("ball_a_id", -1))
	var ball_b_id: int = int(event.get("ball_b_id", -1))
	return not (
		(source_ball_id == ball_a_id and target_ball_id == ball_b_id)
		or (source_ball_id == ball_b_id and target_ball_id == ball_a_id)
	)


static func _get_other_contact_ball_id(event: Dictionary, ball_id: int) -> int:
	var ball_a_id: int = int(event.get("ball_a_id", -1))
	var ball_b_id: int = int(event.get("ball_b_id", -1))
	if ball_a_id == ball_id and ball_b_id != ball_id:
		return ball_b_id
	if ball_b_id == ball_id and ball_a_id != ball_id:
		return ball_a_id
	return -1


static func _is_authoritative_object_ball(starting_balls: Dictionary, ball_id: int) -> bool:
	if ball_id < 0 or not starting_balls.has(str(ball_id)):
		return false
	return bool(_get_ball_snapshot(starting_balls, ball_id).get("counts_as_object_ball", false))


static func _get_contact_world_position(event: Dictionary) -> Vector2:
	var position_value: Variant = event.get("contact_point", Vector2.ZERO)
	if position_value is Vector2 and _is_finite_vector(position_value):
		return position_value
	return Vector2.ZERO


static func _get_cue_recontact_display_tier(cue_strike_ordinal: int) -> String:
	if cue_strike_ordinal == 2:
		return "double_tap"
	if cue_strike_ordinal == 3:
		return "triple_tap"
	return "tap_x%d" % cue_strike_ordinal


static func _get_object_tap_display_tier(unique_contact_ordinal: int) -> String:
	if unique_contact_ordinal <= 1:
		return "ball_tap"
	return "ball_tap_x%d" % unique_contact_ordinal


static func _contact_event_precedes(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("event_index", -1)) < int(right.get("event_index", -1))


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
	_run_case(results, "DOUBLE TAP", _test_double_tap())
	_run_case(results, "TRIPLE TAP", _test_triple_tap())
	_run_case(results, "CUE AS TARGET", _test_cue_as_target_not_double_tap())
	_run_case(results, "AMBIGUOUS CUE REJECTED", _test_ambiguous_cue_rejected())
	_run_case(results, "AMBIGUOUS CUE SAFELY PROVED", _test_ambiguous_cue_safely_proved())
	_run_case(results, "BALL TAP ACTIVATION EXCLUDED", _test_ball_tap_activation_excluded())
	_run_case(results, "BALL TAP PARENT RECONTACT", _test_ball_tap_parent_recontact())
	_run_case(results, "BALL TAP REPEATED TARGET", _test_ball_tap_repeated_target())
	_run_case(results, "BALL TAP TWO UNIQUE TARGETS", _test_ball_tap_two_unique_targets())
	_run_case(results, "BALL TAP BEFORE ACTIVATION", _test_ball_tap_before_activation())
	_run_case(results, "BALL TAP AFTER POCKET", _test_ball_tap_after_pocket())
	_run_case(results, "BALL TAP NON-OBJECT TARGET", _test_ball_tap_non_object_target())
	_run_case(results, "BALL TAP AMBIGUOUS SOURCE", _test_ball_tap_ambiguous_source())
	_run_case(results, "STRICT DIRECT SECONDARY CONTACT", _test_strict_direct_secondary_contact())

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
	_expect(failures, "one cue strike", _pocket_fact_int(derived, 2, "qualifying_cue_strike_count"), 1)
	_expect(failures, "legacy direct condition", _pocket_fact_bool(derived, 2, "is_depth1_zero_rail_pot"), true)
	_expect(failures, "strict direct", _pocket_fact_bool(derived, 2, "is_direct_pot"), true)
	return failures


static func _test_one_rail_bank() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2), _rail(1, 2, "left"), _pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "bank count", _pocket_fact_int(derived, 2, "bank_count"), 1)
	_expect(failures, "bank tag", _tag_count(derived, "bank"), 1)
	_expect(failures, "bank disqualifies direct", _pocket_fact_bool(derived, 2, "is_direct_pot"), false)
	_expect(failures, "bank disqualifier", _pocket_fact_array(derived, 2, "direct_pot_disqualifiers").has("bank"), true)
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
	_expect(failures, "combination disqualifies direct", _pocket_fact_bool(derived, 3, "is_direct_pot"), false)
	_expect(failures, "combination disqualifier", _pocket_fact_array(derived, 3, "direct_pot_disqualifiers").has("combination"), true)
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
		_contact(0, 1, 2, 1, 2), rejected, _pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "semantic contacts", int(derived.get("semantic_ball_contact_count", 0)), 1)
	var diagnostics: Dictionary = _dictionary_value(derived, "diagnostics")
	_expect(failures, "ignored overlap", int(diagnostics.get("ignored_nonsemantic_ball_contacts", 0)), 1)
	_expect(failures, "overlap gives no recontact", _pocket_fact_int(derived, 2, "cue_recontact_bonus_count"), 0)
	_expect(failures, "clean direct remains", _pocket_fact_bool(derived, 2, "is_direct_pot"), true)
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


static func _test_double_tap() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 1, 2, 1, 2),
		_pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "cue strikes", _pocket_fact_int(derived, 2, "qualifying_cue_strike_count"), 2)
	_expect(failures, "recontact bonus", _pocket_fact_int(derived, 2, "cue_recontact_bonus_count"), 1)
	_expect(failures, "recontact event", _pocket_fact_array(derived, 2, "cue_recontact_event_indices"), [1])
	_expect(failures, "recontact position", _pocket_fact_array(derived, 2, "cue_recontact_positions"), [Vector2(11.0, 7.0)])
	_expect(failures, "recontact milestone", _pocket_fact_array(derived, 2, "cue_recontact_milestones").size(), 1)
	_expect(failures, "shot milestone count", int(derived.get("cue_recontact_milestone_count", 0)), 1)
	_expect(failures, "canonical cue milestone total", int(derived.get("total_cue_recontact_milestones", 0)), 1)
	_expect(failures, "double-tap ball count", int(derived.get("double_tap_scoring_ball_count", 0)), 1)
	_expect(failures, "canonical double-tap ball count", int(derived.get("scoring_balls_with_double_tap", 0)), 1)
	_expect(failures, "strict direct false", _pocket_fact_bool(derived, 2, "is_direct_pot"), false)
	_expect(failures, "cue recontact disqualifier", _pocket_fact_array(derived, 2, "direct_pot_disqualifiers").has("cue_recontact"), true)
	_expect(failures, "tap direct disqualification", int(derived.get("tap_direct_pot_disqualifications", 0)), 1)
	_expect(failures, "recontact tag", _tag_count(derived, "cue_recontact_milestone"), 1)
	return failures


static func _test_triple_tap() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 1, 2, 1, 2),
		_contact(2, 1, 2, 1, 2),
		_pocket(3, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "cue strikes", _pocket_fact_int(derived, 2, "qualifying_cue_strike_count"), 3)
	_expect(failures, "recontact bonus", _pocket_fact_int(derived, 2, "cue_recontact_bonus_count"), 2)
	_expect(failures, "recontact events", _pocket_fact_array(derived, 2, "cue_recontact_event_indices"), [1, 2])
	_expect(failures, "maximum cue strikes", int(derived.get("maximum_qualifying_cue_strike_count", 0)), 3)
	_expect(failures, "canonical maximum cue strikes", int(derived.get("maximum_cue_strikes_against_one_scoring_ball", 0)), 3)
	_expect(failures, "triple-tap ball count", int(derived.get("triple_tap_plus_scoring_ball_count", 0)), 1)
	var milestones: Array = _pocket_fact_array(derived, 2, "cue_recontact_milestones")
	_expect(failures, "milestone count", milestones.size(), 2)
	if milestones.size() >= 2 and milestones[1] is Dictionary:
		_expect(failures, "triple display tier", str((milestones[1] as Dictionary).get("display_tier", "")), "triple_tap")
	return failures


static func _test_cue_as_target_not_double_tap() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 2, 1, 2, 1),
		_pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "cue strikes remain one", _pocket_fact_int(derived, 2, "qualifying_cue_strike_count"), 1)
	_expect(failures, "no recontact bonus", _pocket_fact_int(derived, 2, "cue_recontact_bonus_count"), 0)
	_expect(failures, "secondary cue contact", _pocket_fact_int(derived, 2, "nonqualifying_post_activation_cue_contact_count"), 1)
	_expect(failures, "strict direct false", _pocket_fact_bool(derived, 2, "is_direct_pot"), false)
	return failures


static func _test_ambiguous_cue_rejected() -> Array[String]:
	var ambiguous_contact: Dictionary = _contact(1, 1, 2, -1, -1)
	ambiguous_contact["pre_velocity_a"] = Vector2(10.0, 0.0)
	ambiguous_contact["pre_velocity_b"] = Vector2(-4.0, 0.0)
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		ambiguous_contact,
		_pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "ambiguous cue not awarded", _pocket_fact_int(derived, 2, "qualifying_cue_strike_count"), 1)
	_expect(failures, "ambiguous cue diagnostic", _pocket_fact_int(derived, 2, "ambiguous_cue_contact_count"), 1)
	_expect(failures, "no recontact milestone", int(derived.get("cue_recontact_milestone_count", 0)), 0)
	_expect(failures, "shot rejection count", int(derived.get("ambiguous_qualifying_contact_rejection_count", 0)), 1)
	_expect(failures, "ambiguous disqualifies direct", _pocket_fact_bool(derived, 2, "is_direct_pot"), false)
	return failures


static func _test_ambiguous_cue_safely_proved() -> Array[String]:
	var proved_contact: Dictionary = _contact(1, 1, 2, -1, -1)
	proved_contact["pre_velocity_a"] = Vector2(10.0, 0.0)
	proved_contact["pre_velocity_b"] = Vector2.ZERO
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		proved_contact,
		_pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "proved cue strike awarded", _pocket_fact_int(derived, 2, "qualifying_cue_strike_count"), 2)
	_expect(failures, "recontact milestone", int(derived.get("cue_recontact_milestone_count", 0)), 1)
	_expect(failures, "no ambiguity rejection", _pocket_fact_int(derived, 2, "ambiguous_cue_contact_count"), 0)
	var diagnostics: Dictionary = _dictionary_value(derived, "diagnostics")
	_expect(failures, "safe resolution diagnostic", int(diagnostics.get("safely_resolved_ambiguous_cue_contact_count", 0)), 1)
	return failures


static func _test_ball_tap_activation_excluded() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 2, 3, 2, 3),
		_pocket(2, 3, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "combination depth", _depth(derived, 3), 2)
	_expect(failures, "activation excluded", _pocket_fact_int(derived, 3, "unique_object_tap_count"), 0)
	_expect(failures, "activation not secondary", _pocket_fact_int(derived, 3, "material_secondary_object_contact_count"), 0)
	return failures


static func _test_ball_tap_parent_recontact() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 2, 3, 2, 3),
		_contact(2, 3, 2, 3, 2),
		_pocket(3, 3, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "later parent tap", _pocket_fact_int(derived, 3, "unique_object_tap_count"), 1)
	_expect(failures, "parent target id", _pocket_fact_array(derived, 3, "unique_object_tap_ball_ids"), [2])
	_expect(failures, "tap event index", _pocket_fact_array(derived, 3, "object_tap_event_indices"), [2])
	return failures


static func _test_ball_tap_repeated_target() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 2, 3, 2, 3),
		_contact(2, 2, 3, 2, 3),
		_pocket(3, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "one unique target", _pocket_fact_int(derived, 2, "unique_object_tap_count"), 1)
	_expect(failures, "one repeat ignored", _pocket_fact_int(derived, 2, "repeated_object_tap_contact_count"), 1)
	_expect(failures, "one tap milestone", int(derived.get("object_ball_tap_milestone_count", 0)), 1)
	_expect(failures, "shot repeat count", int(derived.get("repeated_object_tap_contact_count", 0)), 1)
	_expect(failures, "canonical repeat count", int(derived.get("repeated_ball_tap_contacts_ignored", 0)), 1)
	_expect(failures, "tap disqualifies direct", _pocket_fact_bool(derived, 2, "is_direct_pot"), false)
	return failures


static func _test_ball_tap_two_unique_targets() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 2, 3, 2, 3),
		_contact(2, 2, 4, 2, 4),
		_pocket(3, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "two unique targets", _pocket_fact_int(derived, 2, "unique_object_tap_count"), 2)
	_expect(failures, "target order", _pocket_fact_array(derived, 2, "unique_object_tap_ball_ids"), [3, 4])
	_expect(failures, "tap events", _pocket_fact_array(derived, 2, "object_tap_event_indices"), [1, 2])
	_expect(failures, "tap positions", _pocket_fact_array(derived, 2, "object_tap_positions"), [Vector2(11.0, 7.0), Vector2(21.0, 12.0)])
	_expect(failures, "shot tap count", int(derived.get("object_ball_tap_milestone_count", 0)), 2)
	_expect(failures, "canonical tap total", int(derived.get("total_unique_ball_tap_milestones", 0)), 2)
	_expect(failures, "maximum taps", int(derived.get("maximum_unique_object_tap_count", 0)), 2)
	_expect(failures, "canonical maximum taps", int(derived.get("maximum_ball_taps_by_one_scoring_ball", 0)), 2)
	_expect(failures, "ball-tap ball count", int(derived.get("ball_tap_scoring_ball_count", 0)), 1)
	_expect(failures, "tap tags", _tag_count(derived, "object_ball_tap_milestone"), 2)
	return failures


static func _test_ball_tap_before_activation() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 2, 3, 2, 3),
		_contact(1, 1, 2, 1, 2),
		_pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "pre-activation tap ignored", _pocket_fact_int(derived, 2, "unique_object_tap_count"), 0)
	_expect(failures, "pre-activation not material", _pocket_fact_int(derived, 2, "material_secondary_object_contact_count"), 0)
	return failures


static func _test_ball_tap_after_pocket() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_pocket(1, 2, 0, true),
		_contact(2, 2, 3, 2, 3),
	]))
	var failures: Array[String] = []
	_expect(failures, "post-pocket tap ignored", _pocket_fact_int(derived, 2, "unique_object_tap_count"), 0)
	_expect(failures, "post-pocket event absent", _pocket_fact_array(derived, 2, "object_tap_event_indices"), [])
	return failures


static func _test_ball_tap_non_object_target() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 2, 5, 2, 5),
		_pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "presentation target ignored", _pocket_fact_int(derived, 2, "unique_object_tap_count"), 0)
	_expect(failures, "presentation target not material", _pocket_fact_int(derived, 2, "material_secondary_object_contact_count"), 0)
	_expect(failures, "direct remains true", _pocket_fact_bool(derived, 2, "is_direct_pot"), true)
	return failures


static func _test_ball_tap_ambiguous_source() -> Array[String]:
	var ambiguous_contact: Dictionary = _contact(2, 2, 3, -1, -1)
	ambiguous_contact["pre_velocity_a"] = Vector2(10.0, 0.0)
	ambiguous_contact["pre_velocity_b"] = Vector2.ZERO
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 1, 3, 1, 3),
		ambiguous_contact,
		_pocket(3, 2, 0, true),
		_pocket(4, 3, 1, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "first side not awarded", _pocket_fact_int(derived, 2, "unique_object_tap_count"), 0)
	_expect(failures, "second side not awarded", _pocket_fact_int(derived, 3, "unique_object_tap_count"), 0)
	_expect(failures, "first ambiguity diagnostic", _pocket_fact_int(derived, 2, "ambiguous_object_tap_count"), 1)
	_expect(failures, "second ambiguity diagnostic", _pocket_fact_int(derived, 3, "ambiguous_object_tap_count"), 1)
	_expect(failures, "event-level rejection deduplicated", int(derived.get("ambiguous_qualifying_contact_rejection_count", 0)), 1)
	_expect(failures, "canonical ambiguous tap rejection", int(derived.get("ambiguous_ball_tap_contacts_rejected", 0)), 1)
	_expect(failures, "no symmetric tap tag", _tag_count(derived, "object_ball_tap_milestone"), 0)
	_expect(failures, "ambiguous object contact disqualifies direct", _pocket_fact_bool(derived, 2, "is_direct_pot"), false)
	return failures


static func _test_strict_direct_secondary_contact() -> Array[String]:
	var derived: Dictionary = analyze(_make_test_ledger([
		_contact(0, 1, 2, 1, 2),
		_contact(1, 3, 2, 3, 2),
		_pocket(2, 2, 0, true),
	]))
	var failures: Array[String] = []
	_expect(failures, "legacy condition retained", _pocket_fact_bool(derived, 2, "is_depth1_zero_rail_pot"), true)
	_expect(failures, "incoming contact gives no Ball Tap", _pocket_fact_int(derived, 2, "unique_object_tap_count"), 0)
	_expect(failures, "material contact counted", _pocket_fact_int(derived, 2, "material_secondary_object_contact_count"), 1)
	_expect(failures, "strict direct false", _pocket_fact_bool(derived, 2, "is_direct_pot"), false)
	_expect(failures, "secondary contact disqualifier", _pocket_fact_array(derived, 2, "direct_pot_disqualifiers").has("secondary_object_contact"), true)
	return failures


static func _make_test_ledger(events: Array) -> Dictionary:
	var starting_balls: Dictionary = {
		"1": _ball_snapshot(1, -1, "cue", false),
		"2": _ball_snapshot(2, 2, "object", true),
		"3": _ball_snapshot(3, 3, "object", true),
		"4": _ball_snapshot(4, 4, "object", true),
		"5": _ball_snapshot(5, -1, "presentation", false),
	}
	var ending_balls: Dictionary = {
		"1": _ending_snapshot(1, true),
		"2": _ending_snapshot(2, not _events_pocket_ball(events, 2)),
		"3": _ending_snapshot(3, not _events_pocket_ball(events, 3)),
		"4": _ending_snapshot(4, not _events_pocket_ball(events, 4)),
		"5": _ending_snapshot(5, true),
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
	var normal := Vector2.RIGHT
	var pre_velocity_a := Vector2.ZERO
	var pre_velocity_b := Vector2.ZERO
	if source_id == ball_a_id and target_id == ball_b_id:
		pre_velocity_a = normal * 10.0
	elif source_id == ball_b_id and target_id == ball_a_id:
		pre_velocity_b = -normal * 10.0
	return {
		"event_index": index,
		"event_type": "ball_contact",
		"ball_a_id": ball_a_id,
		"ball_b_id": ball_b_id,
		"source_ball_id": source_id,
		"target_ball_id": target_id,
		"causal_direction_ambiguous": source_id < 0 or target_id < 0,
		"contact_point": Vector2(float(index) * 10.0 + 1.0, float(index) * 5.0 + 2.0),
		"contact_normal": normal,
		"pre_velocity_a": pre_velocity_a,
		"pre_velocity_b": pre_velocity_b,
		"post_velocity_a": pre_velocity_a * 0.5,
		"post_velocity_b": pre_velocity_b * 0.5,
		"relative_normal_speed": 10.0,
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
		"position": Vector2(float(pocket_index) * 20.0 + 5.0, 5.0),
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


static func _pocket_fact_bool(derived: Dictionary, ball_id: int, field: String) -> bool:
	for fact_value in _array_value(derived, "pocket_facts"):
		if fact_value is Dictionary:
			var fact: Dictionary = fact_value
			if int(fact.get("ball_id", -1)) == ball_id:
				return bool(fact.get(field, false))
	return false


static func _pocket_fact_array(derived: Dictionary, ball_id: int, field: String) -> Array:
	for fact_value in _array_value(derived, "pocket_facts"):
		if fact_value is Dictionary:
			var fact: Dictionary = fact_value
			if int(fact.get("ball_id", -1)) == ball_id:
				return _array_value(fact, field)
	return []


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


static func _sorted_int_keys(values: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for value in values.keys():
		result.append(int(value))
	result.sort()
	return result


static func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


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
