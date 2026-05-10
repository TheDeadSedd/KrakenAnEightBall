@tool
extends Node
class_name ScoreSystem

signal doubloons_changed(total: int)

# Converts ShotEventSystem histories into Doubloon rewards.
# This owns lightweight score presentation, but not coin sprays or pocket VFX.
const DEBUG_SCORE_BREAKDOWNS := true
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
const SCORE_POPUP_SIZE := Vector2(360, 44)
const SCORE_POPUP_OUTWARD_DRIFT_DISTANCE := 18.0
const SCORE_EVENT_LABEL_ERUPT_TIME := 0.18
const SCORE_EVENT_LABEL_ANGLE_MIN_DEGREES := 30.0
const SCORE_EVENT_LABEL_ANGLE_MAX_DEGREES := 70.0
const SCORE_EVENT_LABEL_DISTANCE := 64.0
const SCORE_EVENT_LABEL_DISTANCE_STEP := 16.0
const SCORE_EVENT_LABEL_START_DISTANCE := 16.0
const SCORE_EVENT_LABEL_TILT_DEGREES := 10.0
const EVENT_REWARDS := {
	"BANK": BANK_REWARD,
	"CHAIN": CHAIN_REWARD,
	"MULTI_CHAIN": MULTI_CHAIN_REWARD,
	"MULTI_SINK": MULTI_SINK_REWARD,
	"ANOMALY_TOUCH": ANOMALY_TOUCH_REWARD,
}

class ScorePopup:
	var ball_id := 0
	var label: Label
	var anchor_position := Vector2.ZERO
	var outward_direction := Vector2.UP
	var line_rotation := 0.0
	var line_items: Array[Dictionary] = []
	var event_labels: Array[Label] = []
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
	var events: Array = snapshot.get("events", [])
	for event_type_value in events:
		var event_type: String = str(event_type_value)
		if not EVENT_REWARDS.has(event_type):
			continue
		if _event_reward_already_awarded(event_type, awarded_events, snapshot_event_counts):
			continue

		_mark_event_reward_awarded(event_type, awarded_events, snapshot_event_counts)
		line_items.append({"label": _get_event_reward_label(event_type), "amount": int(EVENT_REWARDS[event_type])})


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


func _get_popup_outward_direction(ball_id: int) -> Vector2:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	var pocket_direction: Vector2 = _get_popup_incoming_direction(ball_id)
	return _choose_perpendicular_popup_direction(pocket_position, Vector2(-pocket_direction.y, pocket_direction.x))


func _get_popup_line_rotation(ball_id: int) -> float:
	var perpendicular_rotation: float = _get_popup_incoming_direction(ball_id).angle() + PI / 2.0
	return _get_readable_popup_rotation(perpendicular_rotation)


func _get_readable_popup_rotation(line_rotation: float) -> float:
	var line_axis: Vector2 = Vector2.RIGHT.rotated(line_rotation)
	if line_axis.dot(Vector2.RIGHT) < 0.0:
		return line_rotation + PI
	return line_rotation


func _get_popup_incoming_direction(ball_id: int) -> Vector2:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	var sink_position: Vector2 = context.get("sink_position", pocket_position)
	var sink_velocity: Vector2 = context.get("sink_velocity", Vector2.ZERO)
	return _get_pocket_entry_direction(sink_position, pocket_position, sink_velocity)


func _get_pocket_entry_direction(sink_position: Vector2, pocket_position: Vector2, sink_velocity: Vector2) -> Vector2:
	if sink_velocity.length() > 0.0:
		return sink_velocity.normalized()
	var direction: Vector2 = pocket_position - sink_position
	if direction.length() > 0.0:
		return direction.normalized()
	return Vector2.UP


func _choose_perpendicular_popup_direction(pocket_position: Vector2, perpendicular: Vector2) -> Vector2:
	var center: Vector2 = table.playfield_rect.get_center()
	var first_candidate: Vector2 = pocket_position + perpendicular
	var second_candidate: Vector2 = pocket_position - perpendicular
	if first_candidate.distance_squared_to(center) > second_candidate.distance_squared_to(center):
		return perpendicular
	return -perpendicular


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
	popup.anchor_position = _get_popup_anchor_position(ball_id)
	popup.outward_direction = _get_popup_outward_direction(ball_id)
	popup.line_rotation = _get_popup_line_rotation(ball_id)
	popup.label = _make_score_popup_label(popup.anchor_position, popup.line_rotation)
	table.add_child(popup.label)
	_place_score_label_below_gameplay(popup.label)
	score_popups_by_ball[ball_id] = popup
	active_score_popups.append(popup)
	return popup


func _update_score_popup(popup: ScorePopup, delta: float) -> void:
	if popup == null or popup.removal_started:
		return

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

	if popup.revealed_count == 0:
		_show_score_popup_label(popup)
	popup.revealed_count += 1
	_update_score_popup_text(popup)
	_show_event_label_for_latest_item(popup)
	popup.reveal_timer = SCORE_POPUP_REVEAL_DELAY


func _show_score_popup_label(popup: ScorePopup) -> void:
	var color: Color = popup.label.modulate
	color.a = 1.0
	popup.label.modulate = color


func _update_score_popup_text(popup: ScorePopup) -> void:
	popup.label.text = _make_score_popup_text(popup)
	popup.label.position = popup.anchor_position - SCORE_POPUP_SIZE * 0.5
	popup.label.rotation = popup.line_rotation


func _make_score_popup_text(popup: ScorePopup) -> String:
	var amount_text := ""
	var revealed_total := 0
	for index in range(popup.revealed_count):
		var line_item: Dictionary = popup.line_items[index]
		amount_text += "+%s" % int(line_item["amount"])
		revealed_total += int(line_item["amount"])

	var total_text := "=%s" % revealed_total if popup.revealed_count >= popup.line_items.size() else ""
	return "Sink! %s%s" % [amount_text, total_text]


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


func _make_score_popup_label(anchor_position: Vector2, line_rotation: float) -> Label:
	var label := Label.new()
	label.size = SCORE_POPUP_SIZE
	label.position = anchor_position - SCORE_POPUP_SIZE * 0.5
	label.pivot_offset = SCORE_POPUP_SIZE * 0.5
	label.rotation = line_rotation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	label.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.0, 0.8))
	label.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.0, 0.96))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 4)
	label.modulate = Color(1, 1, 1, 0)
	return label


func _show_event_label_for_latest_item(popup: ScorePopup) -> void:
	var line_item: Dictionary = popup.line_items[popup.revealed_count - 1]
	var label_text: String = str(line_item["label"])
	if label_text == "Sink":
		return

	var event_index: int = popup.event_labels.size()
	var total_events: int = _get_total_event_label_count(popup)
	var target_offset: Vector2 = _get_event_label_slot_offset(event_index, total_events)
	var event_label := _make_score_event_label("%s!" % label_text, event_index)
	event_label.position = popup.anchor_position + target_offset.normalized() * SCORE_EVENT_LABEL_START_DISTANCE
	table.add_child(event_label)
	_place_score_label_below_gameplay(event_label)
	popup.event_labels.append(event_label)
	_erupt_score_event_label(event_label, popup, target_offset)


func _get_total_event_label_count(popup: ScorePopup) -> int:
	var event_count := 0
	for line_item in popup.line_items:
		if str(line_item["label"]) != "Sink":
			event_count += 1
	return max(event_count, 1)


func _get_event_label_slot_offset(event_index: int, total_events: int) -> Vector2:
	if total_events <= 1:
		return Vector2.UP * SCORE_EVENT_LABEL_DISTANCE

	var slot_ratio: float = float(event_index) / float(total_events - 1)
	var horizontal_slot: float = slot_ratio * 2.0 - 1.0
	var angle_degrees: float = _get_event_label_slot_angle(abs(horizontal_slot))
	var distance := SCORE_EVENT_LABEL_DISTANCE + float(event_index) * SCORE_EVENT_LABEL_DISTANCE_STEP
	return _get_event_label_slot_direction(horizontal_slot, angle_degrees) * distance


func _get_event_label_slot_angle(horizontal_strength: float) -> float:
	return lerp(SCORE_EVENT_LABEL_ANGLE_MAX_DEGREES, SCORE_EVENT_LABEL_ANGLE_MIN_DEGREES, horizontal_strength)


func _get_event_label_slot_direction(horizontal_slot: float, angle_degrees: float) -> Vector2:
	if abs(horizontal_slot) < 0.01:
		return Vector2.UP

	var side := -1.0 if horizontal_slot < 0.0 else 1.0
	var angle_radians: float = deg_to_rad(angle_degrees)
	return Vector2(cos(angle_radians) * side, -sin(angle_radians)).normalized()


func _make_score_event_label(text: String, event_index: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.rotation_degrees = _get_event_label_tilt(event_index)
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.94, 1.0, 0.72))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.04, 0.92))
	label.add_theme_constant_override("outline_size", 3)
	label.modulate = Color(1, 1, 1, 0)
	return label


func _get_event_label_tilt(event_index: int) -> float:
	var side := -1.0 if event_index % 2 == 0 else 1.0
	return side * SCORE_EVENT_LABEL_TILT_DEGREES


func _erupt_score_event_label(label: Label, popup: ScorePopup, target_offset: Vector2) -> void:
	var target_position: Vector2 = popup.anchor_position + target_offset
	var tween: Tween = table.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", target_position, SCORE_EVENT_LABEL_ERUPT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, SCORE_EVENT_LABEL_ERUPT_TIME)


func _place_score_label_below_gameplay(label: Label) -> void:
	table.move_child(label, table.aim_preview.get_index())


func _fade_out_score_popup(popup: ScorePopup) -> void:
	popup.removal_started = true
	var tween: Tween = table.create_tween()
	tween.set_parallel(true)
	var drift: Vector2 = popup.outward_direction * SCORE_POPUP_OUTWARD_DRIFT_DISTANCE
	tween.tween_property(popup.label, "position", popup.label.position + drift, SCORE_POPUP_FADE_TIME)
	tween.tween_property(popup.label, "modulate:a", 0.0, SCORE_POPUP_FADE_TIME)
	for event_label in popup.event_labels:
		if is_instance_valid(event_label):
			tween.tween_property(event_label, "position", event_label.position + drift, SCORE_POPUP_FADE_TIME)
			tween.tween_property(event_label, "modulate:a", 0.0, SCORE_POPUP_FADE_TIME)
	tween.chain().tween_callback(_remove_score_popup.bind(popup))


func _remove_score_popup(popup: ScorePopup) -> void:
	active_score_popups.erase(popup)
	score_popups_by_ball.erase(popup.ball_id)
	if is_instance_valid(popup.label):
		popup.label.queue_free()
	for event_label in popup.event_labels:
		if is_instance_valid(event_label):
			event_label.queue_free()
