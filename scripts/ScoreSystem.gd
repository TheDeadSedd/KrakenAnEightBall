@tool
extends Node
class_name ScoreSystem

signal doubloons_changed(total: int)
signal doubloons_awarded(amount: int, total: int)

# Converts ShotEventSystem histories into Doubloon rewards.
# This owns lightweight score presentation, but not coin sprays or pocket VFX.
const DEBUG_SCORE_BREAKDOWNS := false
const UI_FONT := preload("res://assets/fonts/Gothic Pixels.ttf")
const BASE_SINK_REWARD := 10
const BANK_REWARD := 5
const CHAIN_REWARD := 5
const MULTI_CHAIN_REWARD := 5
const MULTI_SINK_REWARD := 5
const ANOMALY_TOUCH_REWARD := 2
const SCORE_POPUP_REVEAL_DELAY := 0.5
const SCORE_POPUP_MIN_HOLD_TIME := 1.0
const SCORE_POPUP_HOLD_PER_ITEM := 0.35
const SCORE_POPUP_FADE_TIME := 0.28
const SCORE_POPUP_OUTWARD_DRIFT_DISTANCE := 18.0
const SCORE_POPUP_LIFETIME_DRIFT_SPEED := 8.0
const SCORE_POPUP_START_SCALE := Vector2(0.78, 0.78)
const SCORE_POPUP_POP_SCALE := Vector2(1.35, 1.35)
const SCORE_POPUP_FINAL_PULSE_SCALE := Vector2(1.08, 1.08)
const SCORE_POPUP_POP_IN_TIME := 0.1
const SCORE_POPUP_SETTLE_TIME := 0.08
const SCORE_SEGMENT_CHAR_WIDTH := 13.0
const SCORE_SEGMENT_HEIGHT := 36.0
const SCORE_SEGMENT_GAP := 6.0
const SCORE_SEGMENT_ARC_DEPTH := 16.0
const SCORE_SEGMENT_ARC_ROTATION_DEGREES := 10.0
const SCORE_SIDE_POCKET_X_TOLERANCE_RATIO := 0.18
const CORNER_SCORE_ARC_PADDING := 18.0
const CORNER_SCORE_SEGMENT_SPACING := 42.0
const CORNER_SCORE_STRAIGHT_EXTENSION := 80.0
const CORNER_SCORE_LABEL_MAX_TILT_DEGREES := 10.0
const SCORE_EVENT_LABEL_ERUPT_TIME := 0.18
const SCORE_EVENT_LABEL_START_SCALE := Vector2(0.78, 0.78)
const SCORE_EVENT_LABEL_POP_SCALE := Vector2(1.3, 1.3)
const SCORE_EVENT_LABEL_ANGLE_MIN_DEGREES := 30.0
const SCORE_EVENT_LABEL_ANGLE_MAX_DEGREES := 70.0
const SCORE_EVENT_LABEL_DISTANCE := 64.0
const SCORE_EVENT_LABEL_DISTANCE_STEP := 16.0
const SCORE_EVENT_LABEL_START_DISTANCE := 16.0
const SCORE_EVENT_LABEL_TILT_DEGREES := 10.0
const SCORE_LABEL_POP_FLASH_COLOR := Color(1.18, 1.12, 0.9, 1.0)
const SCORE_LABEL_BASE_MODULATE := Color(1, 1, 1, 1)
const SCORE_LABEL_HIDDEN_MODULATE := Color(1, 1, 1, 0)
const SCORE_LABEL_GLOW_COLOR := Color(1.0, 0.92, 0.55, 0.5)
const SCORE_LABEL_GLOW_SCALE_BOOST := Vector2(1.14, 1.14)
const SCORE_LABEL_GLOW_PEAK_BOOST := Vector2(1.5, 1.5)
const SCORE_LABEL_GLOW_POP_TIME := 0.08
const SCORE_LABEL_GLOW_FADE_TIME := 0.28
const SCORE_LABEL_GLOW_FONT_COLOR := Color(1.0, 0.96, 0.8, 0.18)
const SCORE_LABEL_GLOW_OUTLINE_COLOR := Color(1.0, 0.88, 0.45, 0.78)
const SCORE_LABEL_GLOW_OUTLINE_SIZE := 10
const EVENT_REWARDS := {
	"BANK": BANK_REWARD,
	"CHAIN": CHAIN_REWARD,
	"MULTI_CHAIN": MULTI_CHAIN_REWARD,
	"MULTI_SINK": MULTI_SINK_REWARD,
	"ANOMALY_TOUCH": ANOMALY_TOUCH_REWARD,
}

class ScorePopup:
	var ball_id := 0
	var score_labels: Array[Label] = []
	var anchor_position := Vector2.ZERO
	var outward_direction := Vector2.UP
	var inward_direction := Vector2.DOWN
	var tangent_direction := Vector2.RIGHT
	var lifetime_drift := Vector2.ZERO
	var line_rotation := 0.0
	var is_corner_pocket := false
	var pocket_radius := 0.0
	var line_items: Array[Dictionary] = []
	var event_labels: Array[Label] = []
	var event_label_counts: Dictionary = {}
	var event_label_indices: Dictionary = {}
	var revealed_count := 0
	var reveal_timer := 0.0
	var hold_timer := 0.0
	var removal_started := false

var table
var doubloons_total := 0
var awarded_base_ball_ids: Dictionary = {}
var awarded_event_types_by_ball: Dictionary = {}
var sink_contexts_by_ball: Dictionary = {}
var score_popups_by_ball: Dictionary = {}
var active_score_popups: Array[ScorePopup] = []


func setup(table_ref) -> void:
	table = table_ref
	set_process(true)
	doubloons_changed.emit(doubloons_total)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	for popup in active_score_popups.duplicate():
		_update_score_popup(popup, delta)


func get_doubloons_total() -> int:
	return doubloons_total


func apply_doubloons_penalty(amount: int) -> int:
	var penalty_amount: int = max(amount, 0)
	if penalty_amount <= 0:
		return 0

	doubloons_total -= penalty_amount
	doubloons_changed.emit(doubloons_total)
	return penalty_amount


func get_active_popup_label_count() -> int:
	var label_count := 0
	for popup_value in active_score_popups:
		var popup: ScorePopup = popup_value as ScorePopup
		if popup == null:
			continue
		for score_label in popup.score_labels:
			if is_instance_valid(score_label):
				label_count += 1
		for event_label in popup.event_labels:
			if is_instance_valid(event_label):
				label_count += 1
	return label_count


func score_sunk_ball_snapshot(snapshot: Dictionary, sink_context: Dictionary = {}) -> void:
	_store_sink_context(sink_context)
	_score_sunk_ball_snapshot(snapshot)


func _score_sunk_ball_snapshot(snapshot: Dictionary) -> void:
	var ball_id: int = int(snapshot.get("ball_id", 0))
	if ball_id == 0:
		return

	var line_items: Array[Dictionary] = []
	var includes_base_reward: bool = _try_add_base_reward(ball_id, line_items)
	_try_add_event_rewards(ball_id, snapshot, line_items)
	if line_items.is_empty():
		return

	var gained_total: int = _sum_line_items(line_items)
	doubloons_total += gained_total
	doubloons_changed.emit(doubloons_total)
	doubloons_awarded.emit(gained_total, doubloons_total)
	var ball_label: String = str(snapshot.get("label", "Ball"))
	_add_line_items_to_score_popup(ball_id, ball_label, line_items)
	_print_score_breakdown(ball_label, line_items, gained_total, includes_base_reward)


func _try_add_base_reward(ball_id: int, line_items: Array[Dictionary]) -> bool:
	if awarded_base_ball_ids.has(ball_id):
		return false

	awarded_base_ball_ids[ball_id] = true
	line_items.append({"label": "Sink", "amount": BASE_SINK_REWARD})
	return true


func _try_add_event_rewards(ball_id: int, snapshot: Dictionary, line_items: Array[Dictionary]) -> void:
	var awarded_events: Dictionary = _get_or_make_awarded_event_set(ball_id)
	var snapshot_event_counts: Dictionary = {}
	var grouped_rewards: Dictionary = {}
	var grouped_reward_order: Array[String] = []
	var events: Array = snapshot.get("events", [])
	for event_type_value in events:
		var event_type: String = str(event_type_value)
		if not EVENT_REWARDS.has(event_type):
			continue
		if _event_reward_already_awarded(event_type, awarded_events, snapshot_event_counts):
			continue

		_mark_event_reward_awarded(event_type, awarded_events, snapshot_event_counts)
		_add_grouped_event_reward(event_type, grouped_rewards, grouped_reward_order)

	_append_grouped_event_rewards(grouped_rewards, grouped_reward_order, line_items)


func _add_grouped_event_reward(
	event_type: String,
	grouped_rewards: Dictionary,
	grouped_reward_order: Array[String]
) -> void:
	if not grouped_rewards.has(event_type):
		grouped_reward_order.append(event_type)
		grouped_rewards[event_type] = {
			"label": _get_event_reward_label(event_type),
			"amount": 0,
			"count": 0,
		}

	var reward_data: Dictionary = grouped_rewards[event_type]
	reward_data["amount"] = int(reward_data["amount"]) + int(EVENT_REWARDS[event_type])
	reward_data["count"] = int(reward_data["count"]) + 1


func _append_grouped_event_rewards(
	grouped_rewards: Dictionary,
	grouped_reward_order: Array[String],
	line_items: Array[Dictionary]
) -> void:
	for event_type in grouped_reward_order:
		var reward_data: Dictionary = grouped_rewards[event_type]
		var label_text: String = _get_grouped_reward_label(str(reward_data["label"]), int(reward_data["count"]))
		line_items.append({
			"label": label_text,
			"amount": int(reward_data["amount"]),
		})


func _get_grouped_reward_label(label_text: String, event_count: int) -> String:
	if event_count <= 1:
		return label_text
	return "%s x%s" % [label_text, event_count]


func _event_reward_already_awarded(
	event_type: String,
	awarded_events: Dictionary,
	snapshot_event_counts: Dictionary
) -> bool:
	if _is_repeatable_event(event_type):
		var occurrence_number: int = _get_next_snapshot_event_count(event_type, snapshot_event_counts)
		return occurrence_number <= int(awarded_events.get(event_type, 0))

	return awarded_events.has(event_type)


func _mark_event_reward_awarded(
	event_type: String,
	awarded_events: Dictionary,
	snapshot_event_counts: Dictionary
) -> void:
	if _is_repeatable_event(event_type):
		awarded_events[event_type] = int(snapshot_event_counts.get(event_type, 0))
		return

	awarded_events[event_type] = true


func _get_next_snapshot_event_count(event_type: String, snapshot_event_counts: Dictionary) -> int:
	var next_count: int = int(snapshot_event_counts.get(event_type, 0)) + 1
	snapshot_event_counts[event_type] = next_count
	return next_count


func _is_repeatable_event(event_type: String) -> bool:
	return event_type == "MULTI_CHAIN"


func _get_or_make_awarded_event_set(ball_id: int) -> Dictionary:
	if not awarded_event_types_by_ball.has(ball_id):
		awarded_event_types_by_ball[ball_id] = {}
	return awarded_event_types_by_ball[ball_id]


func _store_sink_context(sink_context: Dictionary) -> void:
	var ball_id: int = int(sink_context.get("ball_id", 0))
	if ball_id == 0:
		return

	sink_contexts_by_ball[ball_id] = sink_context


func _get_popup_anchor_position(ball_id: int) -> Vector2:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	return context.get("pocket_position", Vector2.ZERO)


func _get_popup_pocket_radius(ball_id: int) -> float:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	return float(context.get("pocket_radius", 0.0))


func _get_popup_outward_direction(ball_id: int) -> Vector2:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	return -_get_popup_inward_direction_from_position(pocket_position)


func _get_popup_tangent_direction(ball_id: int, is_corner_pocket: bool) -> Vector2:
	if is_corner_pocket:
		return Vector2.RIGHT

	var inward_direction: Vector2 = _get_popup_inward_direction(ball_id)
	return _get_readable_popup_tangent(inward_direction)


func _get_popup_inward_direction(ball_id: int) -> Vector2:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	return _get_popup_inward_direction_from_position(pocket_position)


func _get_popup_inward_direction_from_position(pocket_position: Vector2) -> Vector2:
	var inward_direction: Vector2 = table.playfield_rect.get_center() - pocket_position
	if inward_direction.length() <= 0.0:
		return Vector2.DOWN
	return inward_direction.normalized()


func _get_readable_popup_tangent(inward_direction: Vector2) -> Vector2:
	var tangent_direction: Vector2 = inward_direction.rotated(PI / 2.0).normalized()
	# Keep the score chain advancing in screen-reading order after deriving
	# its basis from the authored pocket center.
	if tangent_direction.x < -0.001 or (abs(tangent_direction.x) <= 0.001 and tangent_direction.y < 0.0):
		return -tangent_direction
	return tangent_direction


func _is_corner_pocket_position(pocket_position: Vector2) -> bool:
	if pocket_position == Vector2.ZERO:
		return false

	var playfield_center_x: float = table.playfield_rect.get_center().x
	var side_pocket_tolerance: float = table.playfield_rect.size.x * SCORE_SIDE_POCKET_X_TOLERANCE_RATIO
	return abs(pocket_position.x - playfield_center_x) > side_pocket_tolerance


func _sum_line_items(line_items: Array[Dictionary]) -> int:
	var total := 0
	for line_item in line_items:
		total += int(line_item["amount"])
	return total


func _get_popup_hold_time(popup: ScorePopup) -> float:
	return SCORE_POPUP_MIN_HOLD_TIME + float(popup.line_items.size()) * SCORE_POPUP_HOLD_PER_ITEM


func _add_line_items_to_score_popup(ball_id: int, ball_label: String, line_items: Array[Dictionary]) -> void:
	var popup: ScorePopup = _get_or_create_score_popup(ball_id)
	if popup == null:
		return

	popup.line_items.append_array(line_items)
	_print_popup_line_items_added(ball_label, line_items)
	popup.removal_started = false
	popup.hold_timer = _get_popup_hold_time(popup)
	if popup.revealed_count == 0:
		_reveal_next_score_item(popup)
	else:
		popup.reveal_timer = 0.0


func _print_popup_line_items_added(ball_label: String, line_items: Array[Dictionary]) -> void:
	if not DEBUG_SCORE_BREAKDOWNS:
		return

	for line_item in line_items:
		print("Popup add: %s -> %s +%s" % [ball_label, line_item["label"], line_item["amount"]])


func _get_or_create_score_popup(ball_id: int) -> ScorePopup:
	if score_popups_by_ball.has(ball_id):
		var existing_popup: ScorePopup = score_popups_by_ball[ball_id] as ScorePopup
		if existing_popup != null and not existing_popup.removal_started:
			return existing_popup

	var popup: ScorePopup = ScorePopup.new()
	popup.ball_id = ball_id
	popup.inward_direction = _get_popup_inward_direction(ball_id)
	popup.anchor_position = _get_popup_anchor_position(ball_id)
	popup.pocket_radius = _get_popup_pocket_radius(ball_id)
	popup.is_corner_pocket = _is_corner_pocket_position(popup.anchor_position)
	popup.outward_direction = _get_popup_outward_direction(ball_id)
	popup.tangent_direction = _get_popup_tangent_direction(ball_id, popup.is_corner_pocket)
	popup.line_rotation = popup.tangent_direction.angle()
	score_popups_by_ball[ball_id] = popup
	active_score_popups.append(popup)
	return popup


func _update_score_popup(popup: ScorePopup, delta: float) -> void:
	if popup == null or popup.removal_started:
		return

	_update_score_popup_drift(popup, delta)
	if popup.revealed_count < popup.line_items.size():
		popup.reveal_timer -= delta
		if popup.reveal_timer <= 0.0:
			_reveal_next_score_item(popup)
		return

	popup.hold_timer -= delta
	if popup.hold_timer <= 0.0:
		_fade_out_score_popup(popup)


func _reveal_next_score_item(popup: ScorePopup) -> void:
	if popup.revealed_count >= popup.line_items.size():
		return

	popup.revealed_count += 1
	_update_score_popup_segments(popup)
	_show_event_label_for_latest_item(popup)
	if popup.revealed_count >= popup.line_items.size() and popup.line_items.size() > 1:
		_pulse_final_score_total(popup)
	popup.reveal_timer = SCORE_POPUP_REVEAL_DELAY


func _update_score_popup_segments(popup: ScorePopup) -> void:
	var score_segments: Array[String] = _get_score_segments(popup)
	_sync_score_segment_labels(popup, score_segments)
	_layout_score_segment_labels(popup, score_segments)


func _get_score_segments(popup: ScorePopup) -> Array[String]:
	var segments: Array[String] = ["Sink!"]
	var revealed_total := 0
	for index in range(popup.revealed_count):
		var line_item: Dictionary = popup.line_items[index]
		var amount: int = int(line_item["amount"])
		segments.append("+%s" % amount)
		revealed_total += amount

	if popup.revealed_count >= popup.line_items.size():
		segments.append("=%s" % revealed_total)
	return segments


func _print_score_breakdown(
	ball_label: String,
	line_items: Array[Dictionary],
	gained_total: int,
	includes_base_reward: bool
) -> void:
	if not DEBUG_SCORE_BREAKDOWNS:
		return

	print("%s %s:" % [ball_label, "sunk" if includes_base_reward else "bonus update"])
	for line_item in line_items:
		print("%s +%s" % [line_item["label"], line_item["amount"]])
	print("Total +%s Doubloons" % gained_total)
	print("Run Total: %s" % doubloons_total)


func _get_event_reward_label(event_type: String) -> String:
	match event_type:
		"BANK":
			return "Bank"
		"CHAIN":
			return "Chain"
		"MULTI_CHAIN":
			return "Multi Chain"
		"MULTI_SINK":
			return "Multi Sink"
		"ANOMALY_TOUCH":
			return "Anomaly Touch"
		_:
			return event_type.capitalize()


func _sync_score_segment_labels(popup: ScorePopup, score_segments: Array[String]) -> void:
	for index in range(score_segments.size()):
		if index >= popup.score_labels.size():
			_add_score_segment_label(popup, score_segments[index])
		else:
			popup.score_labels[index].text = score_segments[index]
	_trim_stale_score_segment_labels(popup, score_segments.size())


func _trim_stale_score_segment_labels(popup: ScorePopup, active_segment_count: int) -> void:
	while popup.score_labels.size() > active_segment_count:
		var stale_label: Label = popup.score_labels.pop_back()
		if is_instance_valid(stale_label):
			stale_label.queue_free()


func _add_score_segment_label(popup: ScorePopup, text: String) -> void:
	var label: Label = _make_score_segment_label(text)
	table.add_child(label)
	_place_score_label_below_gameplay(label)
	popup.score_labels.append(label)
	_play_score_segment_pop_in(label)


func _make_score_segment_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.scale = SCORE_POPUP_START_SCALE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_score_segment_theme(label)
	label.modulate = SCORE_LABEL_HIDDEN_MODULATE
	return label


func _apply_score_segment_theme(label: Label) -> void:
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	label.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.0, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.0, 0.96))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 4)


func _layout_score_segment_labels(popup: ScorePopup, score_segments: Array[String]) -> void:
	var widths: Array[float] = _get_score_segment_widths(score_segments)
	if popup.is_corner_pocket:
		_layout_corner_score_segment_labels(popup, widths)
		return

	_layout_side_score_segment_labels(popup, widths)


func _layout_side_score_segment_labels(popup: ScorePopup, widths: Array[float]) -> void:
	var total_width: float = _get_score_segment_total_width(widths)
	var cursor_x: float = -total_width * 0.5
	for index in range(widths.size()):
		var label: Label = popup.score_labels[index]
		var width: float = widths[index]
		var local_x: float = cursor_x + width * 0.5
		var center: Vector2 = _get_score_segment_center(popup, local_x, total_width)
		_layout_score_segment_label(label, center, width, local_x, total_width, popup)
		cursor_x += width + SCORE_SEGMENT_GAP


func _layout_corner_score_segment_labels(popup: ScorePopup, widths: Array[float]) -> void:
	var arc_radius: float = _get_corner_score_arc_radius(popup)
	var distances: Array[float] = _get_corner_score_segment_distances(widths, arc_radius)
	for index in range(widths.size()):
		var label: Label = popup.score_labels[index]
		var path_point: Dictionary = _get_corner_score_path_point(popup, distances[index], arc_radius)
		var center: Vector2 = path_point["position"]
		var rotation: float = _get_corner_score_label_rotation(float(path_point["rotation"]))
		_apply_score_segment_label_layout(label, center, widths[index], rotation)


func _get_score_segment_widths(score_segments: Array[String]) -> Array[float]:
	var widths: Array[float] = []
	for segment in score_segments:
		widths.append(max(36.0, float(segment.length()) * SCORE_SEGMENT_CHAR_WIDTH))
	return widths


func _get_score_segment_total_width(widths: Array[float]) -> float:
	var total_width := 0.0
	for width in widths:
		total_width += width
	return total_width + SCORE_SEGMENT_GAP * max(widths.size() - 1, 0)


func _get_score_segment_center(popup: ScorePopup, local_x: float, total_width: float) -> Vector2:
	var arc_ratio: float = _get_score_segment_arc_ratio(local_x, total_width)
	var arc_depth: float = _get_score_segment_arc_depth(popup)
	var arc_offset: Vector2 = popup.inward_direction * arc_depth * arc_ratio
	return _get_score_chain_anchor(popup) + popup.tangent_direction * local_x + arc_offset


func _get_score_chain_anchor(popup: ScorePopup) -> Vector2:
	return popup.anchor_position + popup.lifetime_drift


func _get_score_segment_arc_depth(popup: ScorePopup) -> float:
	return SCORE_SEGMENT_ARC_DEPTH


func _layout_score_segment_label(
	label: Label,
	center: Vector2,
	width: float,
	local_x: float,
	total_width: float,
	popup: ScorePopup
) -> void:
	var rotation: float = _get_score_segment_rotation(local_x, total_width, popup)
	_apply_score_segment_label_layout(label, center, width, rotation)


func _apply_score_segment_label_layout(label: Label, center: Vector2, width: float, rotation: float) -> void:
	label.size = Vector2(width, SCORE_SEGMENT_HEIGHT)
	label.pivot_offset = label.size * 0.5
	label.position = center - label.size * 0.5
	label.rotation = rotation


func _get_score_segment_rotation(local_x: float, total_width: float, popup: ScorePopup) -> float:
	var arc_ratio: float = 0.0 if total_width <= 0.0 else clamp(local_x / (total_width * 0.5), -1.0, 1.0)
	var arc_rotation: float = _get_score_segment_arc_rotation_degrees(popup)
	var local_rotation := deg_to_rad(arc_rotation) * arc_ratio
	return popup.line_rotation + local_rotation


func _get_score_segment_arc_rotation_degrees(popup: ScorePopup) -> float:
	return SCORE_SEGMENT_ARC_ROTATION_DEGREES


func _get_score_segment_arc_ratio(local_x: float, total_width: float) -> float:
	if total_width <= 0.0:
		return 0.0
	return pow(abs(local_x) / (total_width * 0.5), 2.0)


func _get_corner_score_arc_radius(popup: ScorePopup) -> float:
	return max(popup.pocket_radius + CORNER_SCORE_ARC_PADDING, CORNER_SCORE_ARC_PADDING)


func _get_corner_score_segment_distances(widths: Array[float], arc_radius: float) -> Array[float]:
	var distances: Array[float] = []
	var cursor := 0.0
	for width in widths:
		var slot_width: float = max(width, CORNER_SCORE_SEGMENT_SPACING)
		distances.append(cursor + slot_width * 0.5)
		cursor += slot_width + SCORE_SEGMENT_GAP

	var raw_total: float = max(cursor - SCORE_SEGMENT_GAP, 0.0)
	var target_total: float = _get_corner_score_path_length(raw_total, widths.size(), arc_radius)
	var scale: float = target_total / raw_total if raw_total > 0.0 else 1.0
	for index in range(distances.size()):
		distances[index] = (distances[index] - raw_total * 0.5) * scale
	return distances


func _get_corner_score_path_length(raw_total: float, segment_count: int, arc_radius: float) -> float:
	if segment_count < 4:
		return raw_total

	var arc_length: float = arc_radius * PI * 0.5
	var extended_length: float = arc_length + CORNER_SCORE_STRAIGHT_EXTENSION * 2.0
	return max(raw_total, extended_length)


func _get_corner_score_path_point(popup: ScorePopup, path_distance: float, arc_radius: float) -> Dictionary:
	var arc_angles: Array = _get_corner_score_arc_angles(popup.anchor_position)
	var start_angle: float = float(arc_angles[0])
	var end_angle: float = float(arc_angles[1])
	var angle_delta: float = end_angle - start_angle
	var arc_length: float = abs(angle_delta) * arc_radius
	var half_arc: float = arc_length * 0.5
	var arc_center: Vector2 = popup.anchor_position + popup.lifetime_drift
	return _get_corner_score_path_point_for_distance(path_distance, half_arc, arc_center, arc_radius, start_angle, end_angle)


func _get_corner_score_label_rotation(path_rotation: float) -> float:
	var path_direction: Vector2 = Vector2.RIGHT.rotated(path_rotation)
	var max_tilt_radians: float = deg_to_rad(CORNER_SCORE_LABEL_MAX_TILT_DEGREES)
	return clamp(path_direction.y * max_tilt_radians, -max_tilt_radians, max_tilt_radians)


func _get_corner_score_path_point_for_distance(
	path_distance: float,
	half_arc: float,
	arc_center: Vector2,
	arc_radius: float,
	start_angle: float,
	end_angle: float
) -> Dictionary:
	var direction_sign := 1.0 if end_angle >= start_angle else -1.0
	if path_distance < -half_arc:
		return _get_corner_straight_path_point(arc_center, arc_radius, start_angle, direction_sign, path_distance + half_arc)
	if path_distance > half_arc:
		return _get_corner_straight_path_point(arc_center, arc_radius, end_angle, direction_sign, path_distance - half_arc)
	return _get_corner_arc_path_point(arc_center, arc_radius, start_angle, end_angle, path_distance, half_arc)


func _get_corner_straight_path_point(
	arc_center: Vector2,
	arc_radius: float,
	angle: float,
	direction_sign: float,
	extension_distance: float
) -> Dictionary:
	var tangent: Vector2 = _get_corner_score_tangent(angle, direction_sign)
	var position: Vector2 = arc_center + Vector2(cos(angle), sin(angle)) * arc_radius
	return {"position": position + tangent * extension_distance, "rotation": _get_readable_corner_rotation(tangent.angle())}


func _get_corner_arc_path_point(
	arc_center: Vector2,
	arc_radius: float,
	start_angle: float,
	end_angle: float,
	path_distance: float,
	half_arc: float
) -> Dictionary:
	var arc_ratio: float = clamp((path_distance + half_arc) / (half_arc * 2.0), 0.0, 1.0)
	var angle: float = lerp(start_angle, end_angle, arc_ratio)
	var direction_sign := 1.0 if end_angle >= start_angle else -1.0
	var tangent: Vector2 = _get_corner_score_tangent(angle, direction_sign)
	var position: Vector2 = arc_center + Vector2(cos(angle), sin(angle)) * arc_radius
	return {"position": position, "rotation": _get_readable_corner_rotation(tangent.angle())}


func _get_corner_score_arc_angles(pocket_position: Vector2) -> Array:
	var corner_signs: Vector2 = _get_corner_signs(pocket_position)
	if corner_signs.x < 0.0 and corner_signs.y < 0.0:
		return [0.0, PI * 0.5]
	if corner_signs.x > 0.0 and corner_signs.y < 0.0:
		return [PI * 0.5, PI]
	if corner_signs.x > 0.0 and corner_signs.y > 0.0:
		return [PI, PI * 1.5]
	return [PI * 1.5, PI * 2.0]


func _get_corner_signs(pocket_position: Vector2) -> Vector2:
	var playfield_center: Vector2 = table.playfield_rect.get_center()
	var x_sign := -1.0 if pocket_position.x < playfield_center.x else 1.0
	var y_sign := -1.0 if pocket_position.y < playfield_center.y else 1.0
	return Vector2(x_sign, y_sign)


func _get_corner_score_tangent(angle: float, direction_sign: float) -> Vector2:
	return (Vector2(-sin(angle), cos(angle)) * direction_sign).normalized()


func _get_readable_corner_rotation(rotation: float) -> float:
	var label_axis: Vector2 = Vector2.RIGHT.rotated(rotation)
	if label_axis.x < -0.001 or (abs(label_axis.x) <= 0.001 and label_axis.y < 0.0):
		return rotation + PI
	return rotation


func _spawn_reveal_glow(label: Label, target_position: Variant = null) -> void:
	call_deferred("_spawn_reveal_glow_deferred", label, target_position)


func _spawn_reveal_glow_deferred(label: Label, target_position: Variant = null) -> void:
	if not is_instance_valid(label) or label.get_parent() == null:
		return

	var glow_label := Label.new()
	glow_label.text = label.text
	glow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow_label.horizontal_alignment = label.horizontal_alignment
	glow_label.vertical_alignment = label.vertical_alignment
	glow_label.position = label.position
	glow_label.size = label.size
	glow_label.pivot_offset = label.pivot_offset
	glow_label.rotation = label.rotation
	glow_label.scale = label.scale * SCORE_LABEL_GLOW_SCALE_BOOST
	glow_label.modulate = SCORE_LABEL_GLOW_COLOR
	_apply_glow_label_theme(label, glow_label)
	table.add_child(glow_label)
	table.move_child(glow_label, label.get_index())

	var tween: Tween = table.create_tween()
	tween.set_parallel(true)
	if target_position is Vector2:
		tween.tween_property(glow_label, "position", target_position, SCORE_LABEL_GLOW_POP_TIME + SCORE_LABEL_GLOW_FADE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_label, "scale", SCORE_LABEL_GLOW_PEAK_BOOST, SCORE_LABEL_GLOW_POP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_label, "modulate:a", 0.0, SCORE_LABEL_GLOW_POP_TIME + SCORE_LABEL_GLOW_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(glow_label.queue_free)


func _apply_glow_label_theme(source: Label, target: Label) -> void:
	target.add_theme_font_override("font", source.get_theme_font("font"))
	target.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	target.add_theme_color_override("font_color", SCORE_LABEL_GLOW_FONT_COLOR)
	target.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0))
	target.add_theme_color_override("font_outline_color", SCORE_LABEL_GLOW_OUTLINE_COLOR)
	target.add_theme_constant_override("outline_size", SCORE_LABEL_GLOW_OUTLINE_SIZE)
	target.add_theme_constant_override("shadow_offset_x", 0)
	target.add_theme_constant_override("shadow_offset_y", 0)


func _play_score_segment_pop_in(label: Label) -> void:
	_spawn_reveal_glow(label)
	var tween: Tween = table.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", SCORE_LABEL_POP_FLASH_COLOR, SCORE_POPUP_POP_IN_TIME)
	tween.tween_property(label, "scale", SCORE_POPUP_POP_SCALE, SCORE_POPUP_POP_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate", SCORE_LABEL_BASE_MODULATE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2.ONE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _pulse_final_score_total(popup: ScorePopup) -> void:
	if popup.score_labels.is_empty():
		return

	var total_label: Label = popup.score_labels[popup.score_labels.size() - 1]
	var tween: Tween = table.create_tween()
	tween.tween_property(total_label, "scale", SCORE_POPUP_FINAL_PULSE_SCALE, SCORE_POPUP_POP_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(total_label, "scale", Vector2.ONE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _show_event_label_for_latest_item(popup: ScorePopup) -> void:
	var line_item: Dictionary = popup.line_items[popup.revealed_count - 1]
	var label_text: String = str(line_item["label"])
	if label_text == "Sink":
		return

	var event_count: int = int(popup.event_label_counts.get(label_text, 0)) + 1
	popup.event_label_counts[label_text] = event_count
	if popup.event_label_indices.has(label_text):
		_update_grouped_event_label(popup, label_text, event_count)
		return

	var event_index: int = popup.event_labels.size()
	var total_events: int = _get_total_event_label_count(popup)
	var target_offset: Vector2 = _get_event_label_slot_offset(event_index, total_events, popup)
	var event_label := _make_score_event_label(_get_grouped_event_label_text(label_text, event_count), event_index, _get_event_label_base_rotation(popup))
	event_label.position = popup.anchor_position + popup.lifetime_drift + target_offset.normalized() * SCORE_EVENT_LABEL_START_DISTANCE
	table.add_child(event_label)
	_place_score_label_below_gameplay(event_label)
	popup.event_labels.append(event_label)
	popup.event_label_indices[label_text] = event_index
	_erupt_score_event_label(event_label, popup, target_offset)


func _update_grouped_event_label(popup: ScorePopup, label_text: String, event_count: int) -> void:
	var event_index: int = int(popup.event_label_indices[label_text])
	if event_index < 0 or event_index >= popup.event_labels.size():
		return

	var event_label: Label = popup.event_labels[event_index]
	if not is_instance_valid(event_label):
		return

	event_label.text = _get_grouped_event_label_text(label_text, event_count)
	_play_grouped_event_label_pop(event_label)


func _get_grouped_event_label_text(label_text: String, event_count: int) -> String:
	if event_count <= 1:
		return "%s!" % label_text
	return "%s x%s!" % [label_text, event_count]


func _get_total_event_label_count(popup: ScorePopup) -> int:
	var event_types: Dictionary = {}
	for line_item in popup.line_items:
		var label_text: String = str(line_item["label"])
		if label_text != "Sink":
			event_types[label_text] = true
	return max(event_types.size(), 1)


func _get_event_label_slot_offset(event_index: int, total_events: int, popup: ScorePopup) -> Vector2:
	if total_events <= 1:
		return popup.outward_direction * SCORE_EVENT_LABEL_DISTANCE

	var slot_ratio: float = float(event_index) / float(total_events - 1)
	var horizontal_slot: float = slot_ratio * 2.0 - 1.0
	var angle_degrees: float = _get_event_label_slot_angle(abs(horizontal_slot))
	var distance := SCORE_EVENT_LABEL_DISTANCE + float(event_index) * SCORE_EVENT_LABEL_DISTANCE_STEP
	return _get_event_label_slot_direction(popup.outward_direction, horizontal_slot, angle_degrees) * distance


func _get_event_label_slot_angle(horizontal_strength: float) -> float:
	return lerp(SCORE_EVENT_LABEL_ANGLE_MIN_DEGREES, SCORE_EVENT_LABEL_ANGLE_MAX_DEGREES, horizontal_strength)


func _get_event_label_slot_direction(outward_direction: Vector2, horizontal_slot: float, angle_degrees: float) -> Vector2:
	if abs(horizontal_slot) < 0.01:
		return outward_direction

	var side := -1.0 if horizontal_slot < 0.0 else 1.0
	var angle_radians: float = deg_to_rad(angle_degrees)
	return outward_direction.rotated(angle_radians * side).normalized()


func _make_score_event_label(text: String, event_index: int, line_rotation: float) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.rotation = line_rotation + deg_to_rad(_get_event_label_tilt(event_index))
	label.scale = SCORE_EVENT_LABEL_START_SCALE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.94, 1.0, 0.72))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.04, 0.92))
	label.add_theme_constant_override("outline_size", 3)
	label.modulate = SCORE_LABEL_HIDDEN_MODULATE
	return label


func _get_event_label_base_rotation(popup: ScorePopup) -> float:
	if popup.is_corner_pocket:
		return 0.0
	return popup.line_rotation


func _get_event_label_tilt(event_index: int) -> float:
	var side := -1.0 if event_index % 2 == 0 else 1.0
	return side * SCORE_EVENT_LABEL_TILT_DEGREES


func _erupt_score_event_label(label: Label, popup: ScorePopup, target_offset: Vector2) -> void:
	var target_position: Vector2 = popup.anchor_position + popup.lifetime_drift + target_offset
	_spawn_reveal_glow(label, target_position)
	var tween: Tween = table.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", target_position, SCORE_EVENT_LABEL_ERUPT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", SCORE_LABEL_POP_FLASH_COLOR, SCORE_EVENT_LABEL_ERUPT_TIME)
	tween.tween_property(label, "scale", SCORE_EVENT_LABEL_POP_SCALE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate", SCORE_LABEL_BASE_MODULATE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2.ONE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.45)


func _play_grouped_event_label_pop(label: Label) -> void:
	_spawn_reveal_glow(label)
	var tween: Tween = table.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", SCORE_LABEL_POP_FLASH_COLOR, SCORE_EVENT_LABEL_ERUPT_TIME * 0.45)
	tween.tween_property(label, "scale", SCORE_EVENT_LABEL_POP_SCALE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate", SCORE_LABEL_BASE_MODULATE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2.ONE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.35)


func _update_score_popup_drift(popup: ScorePopup, delta: float) -> void:
	var drift_step: Vector2 = popup.outward_direction * SCORE_POPUP_LIFETIME_DRIFT_SPEED * delta
	popup.lifetime_drift += drift_step
	_layout_score_segment_labels(popup, _get_score_segments(popup))
	for event_label in popup.event_labels:
		if is_instance_valid(event_label):
			event_label.position += drift_step


func _place_score_label_below_gameplay(label: Label) -> void:
	table.move_child(label, table.aim_preview.get_index())


func _fade_out_score_popup(popup: ScorePopup) -> void:
	popup.removal_started = true
	var tween: Tween = table.create_tween()
	tween.set_parallel(true)
	var drift: Vector2 = popup.outward_direction * SCORE_POPUP_OUTWARD_DRIFT_DISTANCE
	for score_label in popup.score_labels:
		if is_instance_valid(score_label):
			tween.tween_property(score_label, "position", score_label.position + drift, SCORE_POPUP_FADE_TIME)
			tween.tween_property(score_label, "modulate:a", 0.0, SCORE_POPUP_FADE_TIME)
	for event_label in popup.event_labels:
		if is_instance_valid(event_label):
			tween.tween_property(event_label, "position", event_label.position + drift, SCORE_POPUP_FADE_TIME)
			tween.tween_property(event_label, "modulate:a", 0.0, SCORE_POPUP_FADE_TIME)
	tween.chain().tween_callback(_remove_score_popup.bind(popup))


func _remove_score_popup(popup: ScorePopup) -> void:
	active_score_popups.erase(popup)
	score_popups_by_ball.erase(popup.ball_id)
	for score_label in popup.score_labels:
		if is_instance_valid(score_label):
			score_label.queue_free()
	for event_label in popup.event_labels:
		if is_instance_valid(event_label):
			event_label.queue_free()
