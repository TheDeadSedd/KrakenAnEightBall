@tool
extends Node
class_name ScoreSystem

signal doubloons_changed(total: int)
signal doubloons_awarded(amount: int, total: int)
signal doubloons_lost(amount: int, total: int, reason: String)
signal scoring_event_awarded(event_type: String, amount: int)
signal score_feed_message(text: String)

# Converts ShotEventSystem histories into Doubloon rewards.
# This owns lightweight score presentation, but not coin sprays or pocket VFX.
const DEBUG_SCORE_BREAKDOWNS := false
const DEBUG_SCORE_POPUP_ROUTING_LOGS := false
const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const BASE_SINK_REWARD := 10
const BANK_REWARD := 5
const CHAIN_REWARD := 5
const MULTI_CHAIN_REWARD := 5
const MULTI_SINK_REWARD := 5
const ANOMALY_TOUCH_REWARD := 2
const KRAKEN_KICK_REWARD := 10
const DOUBLE_BANK_REWARD := 10
const THIN_CUT_REWARD := 6
const CLUSTER_BREAK_REWARD := 8
const LAST_GASP_REWARD := 7
const POWER_SINK_REWARD := 7
const SPLIT_THE_LOOT_REWARD := 6
const CROSS_CORNER_BANK_REWARD := 14
const FULL_TABLE_KICK_REWARD := 12
const LONG_HAUL_REWARD := 12
const POWDER_ROUTE_REWARD := 10
const KRAKEN_CURRENT_REWARD := 10
const TRIPLE_BANK_REWARD := 18
const CANNON_CHAIN_REWARD := 16
const TREASURE_SNARE_REWARD := 12
const EVENT_TREASURE_CLAIM := "treasure_claim"
const POCKET_STREAK_FEED_TEMPLATES: Array[String] = [
	"The pocket hungers x%s!",
	"The deep takes interest x%s.",
	"A mouth in the table opens x%s.",
	"The Kraken approves this greed x%s.",
	"The table feeds upon repetition x%s.",
]
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
const SCORE_STACK_LANE_CONFLICT_DISTANCE := 168.0
const SCORE_STACK_LANE_SIDE_STEP := 22.0
const SCORE_STACK_RETREAT_SPEED := 72.0
const SCORE_STACK_INACTIVE_RETREAT_RATIO := 0.35
const SCORE_STACK_BOTTOM_POCKET_SUBTITLE_EXTRA_GAP := 10.0
const SCORE_STACK_CENTER_POCKET_SUBTITLE_GAP_SCALE := 0.72
const FOUNDATIONAL_STACK_CLASS_ID := "foundational_sink"
const FOUNDATIONAL_STACK_HOLD_TIME := 1.35
const FOUNDATIONAL_STACK_FADE_TIME := 0.28
const FOUNDATIONAL_STACK_UPDATE_PULSE_SCALE := Vector2(1.18, 1.18)
const FOUNDATIONAL_STACK_UPDATE_PULSE_TIME := 0.08
const FOUNDATIONAL_STACK_NEAREST_POCKET_MAX_DISTANCE := 140.0
const FOUNDATIONAL_STACK_SUBTITLE_GAP := 22.0
const FOUNDATIONAL_STACK_SUBTITLE_FONT_SIZE := 15
const FOUNDATIONAL_STACK_SUBTITLE_COLOR := Color(1.0, 0.92, 0.62, 0.86)
const SKILLED_STACK_CLASS_ID := "skilled"
const SKILLED_STACK_HOLD_TIME := 1.55
const SKILLED_STACK_FADE_TIME := 0.32
const SKILLED_STACK_NUMBER_FONT_SIZE := 32
const SKILLED_STACK_NUMBER_COLOR := Color(0.68, 0.92, 1.0, 1.0)
const SKILLED_STACK_OUTLINE_COLOR := Color(0.05, 0.26, 0.66, 0.96)
const SKILLED_STACK_SHADOW_COLOR := Color(0.02, 0.08, 0.20, 0.86)
const SKILLED_STACK_POP_FLASH_COLOR := Color(0.78, 1.08, 1.22, 1.0)
const SKILLED_STACK_POP_SCALE := Vector2(1.42, 1.42)
const SKILLED_STACK_GLOW_COLOR := Color(0.35, 0.82, 1.0, 0.44)
const SKILLED_STACK_GLOW_FONT_COLOR := Color(0.74, 0.96, 1.0, 0.22)
const SKILLED_STACK_GLOW_OUTLINE_COLOR := Color(0.18, 0.55, 1.0, 0.72)
const SKILLED_STACK_GLOW_OUTLINE_SIZE := 12
const SKILLED_STACK_OUTWARD_OFFSET := 38.0
const SKILLED_STACK_SUBTITLE_GAP := 25.0
const SKILLED_STACK_SUBTITLE_FONT_SIZE := 16
const SKILLED_STACK_SUBTITLE_COLOR := Color(0.72, 0.96, 1.0, 0.90)
const SKILLED_STACK_UPDATE_PULSE_SCALE := Vector2(1.24, 1.24)
const SKILLED_STACK_UPDATE_PULSE_TIME := 0.10
const HEROIC_STACK_CLASS_ID := "heroic"
const HEROIC_STACK_HOLD_TIME := 1.8
const HEROIC_STACK_FADE_TIME := 0.36
const HEROIC_STACK_NUMBER_FONT_SIZE := 36
const HEROIC_STACK_NUMBER_COLOR := Color(0.92, 0.72, 1.0, 1.0)
const HEROIC_STACK_OUTLINE_COLOR := Color(0.33, 0.08, 0.62, 0.98)
const HEROIC_STACK_SHADOW_COLOR := Color(0.10, 0.02, 0.20, 0.90)
const HEROIC_STACK_POP_FLASH_COLOR := Color(1.08, 0.82, 1.28, 1.0)
const HEROIC_STACK_POP_SCALE := Vector2(1.50, 1.50)
const HEROIC_STACK_GLOW_COLOR := Color(0.72, 0.28, 1.0, 0.46)
const HEROIC_STACK_GLOW_FONT_COLOR := Color(0.94, 0.76, 1.0, 0.25)
const HEROIC_STACK_GLOW_OUTLINE_COLOR := Color(0.60, 0.18, 1.0, 0.78)
const HEROIC_STACK_GLOW_OUTLINE_SIZE := 14
const HEROIC_STACK_OUTWARD_OFFSET := 78.0
const HEROIC_STACK_SUBTITLE_GAP := 28.0
const HEROIC_STACK_SUBTITLE_FONT_SIZE := 17
const HEROIC_STACK_SUBTITLE_COLOR := Color(0.94, 0.78, 1.0, 0.92)
const HEROIC_STACK_UPDATE_PULSE_SCALE := Vector2(1.32, 1.32)
const HEROIC_STACK_UPDATE_PULSE_TIME := 0.12
const LEGENDARY_STACK_CLASS_ID := "legendary"
const LEGENDARY_STACK_HOLD_TIME := 2.05
const LEGENDARY_STACK_FADE_TIME := 0.40
const LEGENDARY_STACK_NUMBER_FONT_SIZE := 40
const LEGENDARY_STACK_NUMBER_COLOR := Color(1.0, 0.92, 0.38, 1.0)
const LEGENDARY_STACK_OUTLINE_COLOR := Color(0.62, 0.34, 0.02, 1.0)
const LEGENDARY_STACK_SHADOW_COLOR := Color(0.20, 0.10, 0.00, 0.92)
const LEGENDARY_STACK_POP_FLASH_COLOR := Color(1.28, 1.10, 0.48, 1.0)
const LEGENDARY_STACK_POP_SCALE := Vector2(1.60, 1.60)
const LEGENDARY_STACK_GLOW_COLOR := Color(1.0, 0.74, 0.14, 0.52)
const LEGENDARY_STACK_GLOW_FONT_COLOR := Color(1.0, 0.95, 0.50, 0.30)
const LEGENDARY_STACK_GLOW_OUTLINE_COLOR := Color(1.0, 0.68, 0.08, 0.84)
const LEGENDARY_STACK_GLOW_OUTLINE_SIZE := 16
const LEGENDARY_STACK_OUTWARD_OFFSET := 124.0
const LEGENDARY_STACK_SUBTITLE_GAP := 31.0
const LEGENDARY_STACK_SUBTITLE_FONT_SIZE := 18
const LEGENDARY_STACK_SUBTITLE_COLOR := Color(1.0, 0.90, 0.48, 0.94)
const LEGENDARY_STACK_UPDATE_PULSE_SCALE := Vector2(1.40, 1.40)
const LEGENDARY_STACK_UPDATE_PULSE_TIME := 0.14
const FOUNDATIONAL_EVENT_TYPES := {
	ShotEventSystem.EVENT_BANK: true,
	ShotEventSystem.EVENT_CHAIN: true,
	ShotEventSystem.EVENT_MULTI_CHAIN: true,
	ShotEventSystem.EVENT_MULTI_SINK: true,
	ShotEventSystem.EVENT_ANOMALY_TOUCH: true,
}
const SKILLED_EVENT_TYPES := {
	ShotEventSystem.EVENT_KRAKEN_KICK: true,
	ShotEventSystem.EVENT_DOUBLE_BANK: true,
	ShotEventSystem.EVENT_THIN_CUT: true,
	ShotEventSystem.EVENT_CLUSTER_BREAK: true,
	ShotEventSystem.EVENT_LAST_GASP: true,
	ShotEventSystem.EVENT_POWER_SINK: true,
	ShotEventSystem.EVENT_SPLIT_THE_LOOT: true,
}
const HEROIC_EVENT_TYPES := {
	ShotEventSystem.EVENT_CROSS_CORNER_BANK: true,
	ShotEventSystem.EVENT_FULL_TABLE_KICK: true,
	ShotEventSystem.EVENT_LONG_HAUL: true,
	ShotEventSystem.EVENT_POWDER_ROUTE: true,
	ShotEventSystem.EVENT_KRAKEN_CURRENT: true,
}
const LEGENDARY_EVENT_TYPES := {
	ShotEventSystem.EVENT_TRIPLE_BANK: true,
	ShotEventSystem.EVENT_CANNON_CHAIN: true,
	ShotEventSystem.EVENT_TREASURE_SNARE: true,
	EVENT_TREASURE_CLAIM: true,
}
const EVENT_REWARDS := {
	ShotEventSystem.EVENT_BANK: BANK_REWARD,
	ShotEventSystem.EVENT_CHAIN: CHAIN_REWARD,
	ShotEventSystem.EVENT_MULTI_CHAIN: MULTI_CHAIN_REWARD,
	ShotEventSystem.EVENT_MULTI_SINK: MULTI_SINK_REWARD,
	ShotEventSystem.EVENT_ANOMALY_TOUCH: ANOMALY_TOUCH_REWARD,
	ShotEventSystem.EVENT_KRAKEN_KICK: KRAKEN_KICK_REWARD,
	ShotEventSystem.EVENT_DOUBLE_BANK: DOUBLE_BANK_REWARD,
	ShotEventSystem.EVENT_THIN_CUT: THIN_CUT_REWARD,
	ShotEventSystem.EVENT_CLUSTER_BREAK: CLUSTER_BREAK_REWARD,
	ShotEventSystem.EVENT_LAST_GASP: LAST_GASP_REWARD,
	ShotEventSystem.EVENT_POWER_SINK: POWER_SINK_REWARD,
	ShotEventSystem.EVENT_SPLIT_THE_LOOT: SPLIT_THE_LOOT_REWARD,
	ShotEventSystem.EVENT_CROSS_CORNER_BANK: CROSS_CORNER_BANK_REWARD,
	ShotEventSystem.EVENT_FULL_TABLE_KICK: FULL_TABLE_KICK_REWARD,
	ShotEventSystem.EVENT_LONG_HAUL: LONG_HAUL_REWARD,
	ShotEventSystem.EVENT_POWDER_ROUTE: POWDER_ROUTE_REWARD,
	ShotEventSystem.EVENT_KRAKEN_CURRENT: KRAKEN_CURRENT_REWARD,
	ShotEventSystem.EVENT_TRIPLE_BANK: TRIPLE_BANK_REWARD,
	ShotEventSystem.EVENT_CANNON_CHAIN: CANNON_CHAIN_REWARD,
	ShotEventSystem.EVENT_TREASURE_SNARE: TREASURE_SNARE_REWARD,
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

class ScoreStack:
	var stack_key := ""
	var stack_class_id := FOUNDATIONAL_STACK_CLASS_ID
	var label: Label
	var subtitle_label: Label
	var anchor_position := Vector2.ZERO
	var outward_direction := Vector2.UP
	var inward_direction := Vector2.DOWN
	var tangent_direction := Vector2.RIGHT
	var lifetime_drift := Vector2.ZERO
	var lane_tangent_offset := 0.0
	var retreat_offset := 0.0
	var retreat_target := 0.0
	var line_rotation := 0.0
	var is_corner_pocket := false
	var pocket_radius := 0.0
	var total := 0
	var latest_summary := ""
	var hold_timer := 0.0
	var removal_started := false

var table
var doubloons_total := 0
var awarded_base_ball_ids: Dictionary = {}
var awarded_event_types_by_ball: Dictionary = {}
var sink_contexts_by_ball: Dictionary = {}
var score_popups_by_ball: Dictionary = {}
var score_stacks_by_key: Dictionary = {}
var active_score_popups: Array[ScorePopup] = []
var active_score_stacks: Array[ScoreStack] = []
var active_score_glow_label_count := 0
var active_score_popup_tween_count := 0
var foundational_score_stack_coalesces := 0
var foundational_score_stack_labels_avoided := 0
var foundational_stack_path_count := 0
var foundational_fallback_stack_path_count := 0
var skilled_score_stack_coalesces := 0
var skilled_score_stack_labels_avoided := 0
var skilled_stack_path_count := 0
var skilled_special_popups_avoided := 0
var heroic_score_stack_coalesces := 0
var heroic_score_stack_labels_avoided := 0
var heroic_stack_path_count := 0
var heroic_special_popups_avoided := 0
var legendary_score_stack_coalesces := 0
var legendary_score_stack_labels_avoided := 0
var legendary_stack_path_count := 0
var legendary_special_popups_avoided := 0
var score_stack_lane_conflicts := 0
var score_stack_replacements := 0
var score_stack_early_fades := 0
var score_stack_yields := 0
var special_popup_path_count := 0
var pocket_streak_feed_message_index := 0
var last_score_popup_route := "none"


func setup(table_ref) -> void:
	table = table_ref
	set_process(true)
	doubloons_changed.emit(doubloons_total)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	for popup in active_score_popups.duplicate():
		_update_score_popup(popup, delta)
	for stack_value in active_score_stacks.duplicate():
		var stack: ScoreStack = stack_value as ScoreStack
		_update_score_stack(stack, delta)


func get_doubloons_total() -> int:
	return doubloons_total


func can_afford_doubloons(amount: int) -> bool:
	return doubloons_total >= max(amount, 0)


func try_spend_doubloons(amount: int) -> bool:
	var spend_amount: int = max(amount, 0)
	if spend_amount <= 0:
		return true
	if not can_afford_doubloons(spend_amount):
		return false

	doubloons_total -= spend_amount
	doubloons_changed.emit(doubloons_total)
	doubloons_lost.emit(spend_amount, doubloons_total, "spend")
	return true


func apply_doubloons_penalty(amount: int) -> int:
	var penalty_amount: int = max(amount, 0)
	if penalty_amount <= 0:
		return 0

	doubloons_total -= penalty_amount
	doubloons_changed.emit(doubloons_total)
	doubloons_lost.emit(penalty_amount, doubloons_total, "penalty")
	return penalty_amount


func award_embezzler_recovery(amount: int, sink_context: Dictionary = {}) -> int:
	var recovery_amount: int = max(amount, 0)
	if recovery_amount <= 0:
		return 0

	_store_sink_context(sink_context)
	doubloons_total += recovery_amount
	doubloons_changed.emit(doubloons_total)
	doubloons_awarded.emit(recovery_amount, doubloons_total)
	var ball_id: int = int(sink_context.get("ball_id", 0))
	var recovery_items: Array[Dictionary] = [
		{
			"label": "Loot Recovered",
			"amount": recovery_amount,
			"event_type": "embezzler_recovery",
		},
	]
	_emit_score_feed_message("Embezzler", recovery_items, recovery_amount)
	if ball_id != 0:
		_add_line_items_to_score_popup(ball_id, "Embezzler", recovery_items)
	return recovery_amount


func award_treasure_claim(amount: int, sink_context: Dictionary = {}) -> int:
	var treasure_amount: int = max(amount, 0)
	if treasure_amount <= 0:
		return 0

	_store_sink_context(sink_context)
	doubloons_total += treasure_amount
	doubloons_changed.emit(doubloons_total)
	doubloons_awarded.emit(treasure_amount, doubloons_total)
	var ball_id: int = int(sink_context.get("ball_id", 0))
	var treasure_items: Array[Dictionary] = [
		{
			"label": "Treasure Claimed",
			"amount": treasure_amount,
			"event_type": EVENT_TREASURE_CLAIM,
		},
	]
	score_feed_message.emit("Treasure claimed! +%s Doubloons" % treasure_amount)
	if ball_id != 0:
		_add_line_items_to_score_popup(ball_id, "Treasure Ball", treasure_items)
	return treasure_amount


func award_pocket_streak(multiplier: int, streak_context: Dictionary = {}) -> int:
	var streak_multiplier: int = maxi(multiplier, 0)
	if streak_multiplier < 2:
		return 0

	var same_pocket_subtotal: int = maxi(int(streak_context.get("score_subtotal", 0)), 0)
	var bonus_already_awarded: int = maxi(int(streak_context.get("bonus_already_awarded", 0)), 0)
	var desired_total_bonus: int = same_pocket_subtotal * (streak_multiplier - 1)
	var streak_reward: int = maxi(desired_total_bonus - bonus_already_awarded, 0)
	if streak_reward <= 0:
		return 0

	doubloons_total += streak_reward
	doubloons_changed.emit(doubloons_total)
	doubloons_awarded.emit(streak_reward, doubloons_total)
	score_feed_message.emit(_get_pocket_streak_feed_message(streak_multiplier, streak_reward, same_pocket_subtotal))
	last_score_popup_route = "pocket_streak x%s subtotal %s +%s" % [
		streak_multiplier,
		same_pocket_subtotal,
		streak_reward,
	]
	return streak_reward


func _get_pocket_streak_feed_message(multiplier: int, reward: int, pocket_base: int) -> String:
	var template_index: int = pocket_streak_feed_message_index % POCKET_STREAK_FEED_TEMPLATES.size()
	var template: String = POCKET_STREAK_FEED_TEMPLATES[template_index]
	pocket_streak_feed_message_index = (pocket_streak_feed_message_index + 1) % POCKET_STREAK_FEED_TEMPLATES.size()
	var flavor_text: String = template % multiplier

	return "%s +%s Doubloons from a %s-Doubloon pocket haul" % [
		flavor_text,
		reward,
		pocket_base,
	]


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
	for stack_value in active_score_stacks:
		var stack: ScoreStack = stack_value as ScoreStack
		if stack != null and is_instance_valid(stack.label):
			label_count += 1
		if stack != null and is_instance_valid(stack.subtitle_label):
			label_count += 1
	return label_count


func get_active_score_stack_count() -> int:
	return active_score_stacks.size()


func get_active_foundational_score_stack_count() -> int:
	var count := 0
	for stack_value in active_score_stacks:
		var stack: ScoreStack = stack_value as ScoreStack
		if stack != null and stack.stack_class_id == FOUNDATIONAL_STACK_CLASS_ID:
			count += 1
	return count


func get_active_skilled_score_stack_count() -> int:
	var count := 0
	for stack_value in active_score_stacks:
		var stack: ScoreStack = stack_value as ScoreStack
		if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
			count += 1
	return count


func get_active_heroic_score_stack_count() -> int:
	var count := 0
	for stack_value in active_score_stacks:
		var stack: ScoreStack = stack_value as ScoreStack
		if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
			count += 1
	return count


func get_active_legendary_score_stack_count() -> int:
	var count := 0
	for stack_value in active_score_stacks:
		var stack: ScoreStack = stack_value as ScoreStack
		if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
			count += 1
	return count


func get_foundational_score_stack_coalesce_count() -> int:
	return foundational_score_stack_coalesces


func get_foundational_score_stack_labels_avoided_count() -> int:
	return foundational_score_stack_labels_avoided


func get_foundational_stack_path_count() -> int:
	return foundational_stack_path_count


func get_foundational_fallback_stack_path_count() -> int:
	return foundational_fallback_stack_path_count


func get_skilled_stack_path_count() -> int:
	return skilled_stack_path_count


func get_skilled_score_stack_coalesce_count() -> int:
	return skilled_score_stack_coalesces


func get_skilled_score_stack_labels_avoided_count() -> int:
	return skilled_score_stack_labels_avoided


func get_skilled_special_popup_avoided_count() -> int:
	return skilled_special_popups_avoided


func get_heroic_stack_path_count() -> int:
	return heroic_stack_path_count


func get_heroic_score_stack_coalesce_count() -> int:
	return heroic_score_stack_coalesces


func get_heroic_score_stack_labels_avoided_count() -> int:
	return heroic_score_stack_labels_avoided


func get_heroic_special_popup_avoided_count() -> int:
	return heroic_special_popups_avoided


func get_legendary_stack_path_count() -> int:
	return legendary_stack_path_count


func get_legendary_score_stack_coalesce_count() -> int:
	return legendary_score_stack_coalesces


func get_legendary_score_stack_labels_avoided_count() -> int:
	return legendary_score_stack_labels_avoided


func get_legendary_special_popup_avoided_count() -> int:
	return legendary_special_popups_avoided


func get_score_stack_lane_conflict_count() -> int:
	return score_stack_lane_conflicts


func get_score_stack_replacement_count() -> int:
	return score_stack_replacements


func get_score_stack_early_fade_count() -> int:
	return score_stack_early_fades


func get_score_stack_yield_count() -> int:
	return score_stack_yields


func get_special_popup_path_count() -> int:
	return special_popup_path_count


func get_last_score_popup_route() -> String:
	return last_score_popup_route


func get_active_score_glow_label_count() -> int:
	return active_score_glow_label_count


func get_active_score_popup_tween_count() -> int:
	return active_score_popup_tween_count


func score_sunk_ball_snapshot(snapshot: Dictionary, sink_context: Dictionary = {}) -> int:
	_store_sink_context(sink_context)
	return _score_sunk_ball_snapshot(snapshot)


func _score_sunk_ball_snapshot(snapshot: Dictionary) -> int:
	var ball_id: int = int(snapshot.get("ball_id", 0))
	if ball_id == 0:
		return 0

	var line_items: Array[Dictionary] = []
	var includes_base_reward: bool = _try_add_base_reward(ball_id, line_items)
	_try_add_event_rewards(ball_id, snapshot, line_items)
	if line_items.is_empty():
		return 0

	var gained_total: int = _sum_line_items(line_items)
	doubloons_total += gained_total
	doubloons_changed.emit(doubloons_total)
	doubloons_awarded.emit(gained_total, doubloons_total)
	var ball_label: String = str(snapshot.get("label", "Ball"))
	_add_line_items_to_score_popup(ball_id, ball_label, line_items)
	_emit_score_feed_message(ball_label, line_items, gained_total)
	_print_score_breakdown(ball_label, line_items, gained_total, includes_base_reward)
	return gained_total


func _try_add_base_reward(ball_id: int, line_items: Array[Dictionary]) -> bool:
	if awarded_base_ball_ids.has(ball_id):
		return false

	awarded_base_ball_ids[ball_id] = true
	line_items.append({"label": "Sink", "amount": BASE_SINK_REWARD, "event_type": ""})
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
			"event_type": event_type,
		})
		scoring_event_awarded.emit(event_type, int(reward_data["amount"]))


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
	return event_type == ShotEventSystem.EVENT_MULTI_CHAIN


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
	return _get_score_anchor_position(ball_id)


func _get_popup_pocket_radius(ball_id: int) -> float:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	return float(context.get("pocket_radius", 0.0))


func _get_popup_outward_direction(ball_id: int) -> Vector2:
	return -_get_popup_inward_direction_from_position(_get_score_anchor_position(ball_id))


func _get_popup_tangent_direction(ball_id: int, is_corner_pocket: bool) -> Vector2:
	if is_corner_pocket:
		return Vector2.RIGHT

	var inward_direction: Vector2 = _get_popup_inward_direction(ball_id)
	return _get_readable_popup_tangent(inward_direction)


func _get_popup_inward_direction(ball_id: int) -> Vector2:
	return _get_popup_inward_direction_from_position(_get_score_anchor_position(ball_id))


func _get_score_anchor_position(ball_id: int) -> Vector2:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	if pocket_position != Vector2.ZERO:
		return pocket_position

	var sink_position: Vector2 = context.get("sink_position", Vector2.ZERO)
	if sink_position != Vector2.ZERO:
		return sink_position

	if table != null:
		return table.playfield_rect.get_center()
	return Vector2.ZERO


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


# All current scoring tiers route through evolving pocket-side stacks first.
# The old multi-segment popup path remains as a defensive fallback for future
# or unclassified rewards that have not been assigned a stack tier yet.
func _add_line_items_to_score_popup(ball_id: int, ball_label: String, line_items: Array[Dictionary]) -> void:
	var remaining_line_items: Array[Dictionary] = _route_foundational_line_items_to_score_stack(
		ball_id,
		ball_label,
		line_items
	)
	remaining_line_items = _route_skilled_line_items_to_score_stack(
		ball_id,
		ball_label,
		remaining_line_items
	)
	remaining_line_items = _route_heroic_line_items_to_score_stack(
		ball_id,
		ball_label,
		remaining_line_items
	)
	remaining_line_items = _route_legendary_line_items_to_score_stack(
		ball_id,
		ball_label,
		remaining_line_items
	)
	if remaining_line_items.is_empty():
		return

	_record_score_popup_route(
		"special_popup",
		ball_label,
		remaining_line_items,
		_sum_line_items(remaining_line_items)
	)
	var popup: ScorePopup = _get_or_create_score_popup(ball_id)
	if popup == null:
		return

	popup.line_items.append_array(remaining_line_items)
	_print_popup_line_items_added(ball_label, remaining_line_items)
	popup.removal_started = false
	popup.hold_timer = _get_popup_hold_time(popup)
	if popup.revealed_count == 0:
		_reveal_next_score_item(popup)
	else:
		popup.reveal_timer = 0.0


func _route_foundational_line_items_to_score_stack(
	ball_id: int,
	ball_label: String,
	line_items: Array[Dictionary]
) -> Array[Dictionary]:
	var foundational_items: Array[Dictionary] = []
	var remaining_items: Array[Dictionary] = []
	for line_item in line_items:
		if _is_foundational_stack_line_item(line_item):
			foundational_items.append(line_item)
		else:
			remaining_items.append(line_item)

	if foundational_items.is_empty():
		return line_items

	if not _try_add_foundational_items_to_score_stack(ball_id, ball_label, foundational_items):
		_add_foundational_fallback_score_label(ball_id, ball_label, foundational_items)

	return remaining_items


func _route_skilled_line_items_to_score_stack(
	ball_id: int,
	ball_label: String,
	line_items: Array[Dictionary]
) -> Array[Dictionary]:
	var skilled_items: Array[Dictionary] = []
	var remaining_items: Array[Dictionary] = []
	for line_item in line_items:
		if _is_skilled_stack_line_item(line_item):
			skilled_items.append(line_item)
		else:
			remaining_items.append(line_item)

	if skilled_items.is_empty():
		return line_items

	if not _try_add_skilled_items_to_score_stack(ball_id, ball_label, skilled_items):
		_add_skilled_fallback_score_label(ball_id, ball_label, skilled_items)

	return remaining_items


func _route_heroic_line_items_to_score_stack(
	ball_id: int,
	ball_label: String,
	line_items: Array[Dictionary]
) -> Array[Dictionary]:
	var heroic_items: Array[Dictionary] = []
	var remaining_items: Array[Dictionary] = []
	for line_item in line_items:
		if _is_heroic_stack_line_item(line_item):
			heroic_items.append(line_item)
		else:
			remaining_items.append(line_item)

	if heroic_items.is_empty():
		return line_items

	if not _try_add_heroic_items_to_score_stack(ball_id, ball_label, heroic_items):
		_add_heroic_fallback_score_label(ball_id, ball_label, heroic_items)

	return remaining_items


func _route_legendary_line_items_to_score_stack(
	ball_id: int,
	ball_label: String,
	line_items: Array[Dictionary]
) -> Array[Dictionary]:
	var legendary_items: Array[Dictionary] = []
	var remaining_items: Array[Dictionary] = []
	for line_item in line_items:
		if _is_legendary_stack_line_item(line_item):
			legendary_items.append(line_item)
		else:
			remaining_items.append(line_item)

	if legendary_items.is_empty():
		return line_items

	if not _try_add_legendary_items_to_score_stack(ball_id, ball_label, legendary_items):
		_add_legendary_fallback_score_label(ball_id, ball_label, legendary_items)

	return remaining_items


func _try_add_foundational_items_to_score_stack(
	ball_id: int,
	ball_label: String,
	foundational_items: Array[Dictionary]
) -> bool:
	var stack_key: String = _get_foundational_stack_key(ball_id)
	if stack_key.is_empty():
		return false

	var stack: ScoreStack = _get_active_score_stack(stack_key)
	var amount: int = _sum_line_items(foundational_items)
	if amount <= 0:
		return false

	var did_update_existing_stack: bool = stack != null
	if stack == null:
		stack = _create_foundational_score_stack(ball_id, stack_key)
		if stack == null:
			return false
		stack.total = amount
		stack.latest_summary = _make_foundational_stack_summary(foundational_items)
		_update_score_stack_label(stack)
		_play_score_stack_pop_in(stack)
	else:
		stack.total += amount
		stack.latest_summary = _make_foundational_stack_summary(foundational_items)
		stack.removal_started = false
		_update_score_stack_label(stack)
		_play_score_stack_update_pulse(stack)
		foundational_score_stack_coalesces += 1
		foundational_score_stack_labels_avoided += maxi(foundational_items.size(), 1)

	if not did_update_existing_stack and foundational_items.size() > 1:
		foundational_score_stack_labels_avoided += foundational_items.size() - 1

	foundational_stack_path_count += 1
	_record_score_popup_route("foundational_stack", ball_label, foundational_items, amount)
	_print_popup_line_items_added(ball_label, foundational_items)
	_refresh_score_stack_lane_state(stack)
	return true


func _try_add_skilled_items_to_score_stack(
	ball_id: int,
	ball_label: String,
	skilled_items: Array[Dictionary]
) -> bool:
	var stack_key: String = _get_skilled_stack_key(ball_id)
	if stack_key.is_empty():
		return false

	var stack: ScoreStack = _get_active_score_stack(stack_key)
	var amount: int = _sum_line_items(skilled_items)
	if amount <= 0:
		return false

	var did_update_existing_stack: bool = stack != null
	if stack == null:
		stack = _create_skilled_score_stack(ball_id, stack_key)
		if stack == null:
			return false
		stack.total = amount
		stack.latest_summary = _make_score_stack_summary(skilled_items, "Skilled")
		_update_score_stack_label(stack)
		_play_score_stack_pop_in(stack)
	else:
		stack.total += amount
		stack.latest_summary = _make_score_stack_summary(skilled_items, "Skilled")
		stack.removal_started = false
		_update_score_stack_label(stack)
		_play_score_stack_update_pulse(stack)
		skilled_score_stack_coalesces += 1
		skilled_score_stack_labels_avoided += maxi(skilled_items.size(), 1)

	if not did_update_existing_stack and skilled_items.size() > 1:
		skilled_score_stack_labels_avoided += skilled_items.size() - 1

	skilled_stack_path_count += 1
	skilled_special_popups_avoided += 1
	_record_score_popup_route("skilled_stack", ball_label, skilled_items, amount)
	_print_popup_line_items_added(ball_label, skilled_items)
	_refresh_score_stack_lane_state(stack)
	return true


func _try_add_heroic_items_to_score_stack(
	ball_id: int,
	ball_label: String,
	heroic_items: Array[Dictionary]
) -> bool:
	var stack_key: String = _get_heroic_stack_key(ball_id)
	if stack_key.is_empty():
		return false

	var stack: ScoreStack = _get_active_score_stack(stack_key)
	var amount: int = _sum_line_items(heroic_items)
	if amount <= 0:
		return false

	var did_update_existing_stack: bool = stack != null
	if stack == null:
		stack = _create_heroic_score_stack(ball_id, stack_key)
		if stack == null:
			return false
		stack.total = amount
		stack.latest_summary = _make_score_stack_summary(heroic_items, "Heroic")
		_update_score_stack_label(stack)
		_play_score_stack_pop_in(stack)
	else:
		stack.total += amount
		stack.latest_summary = _make_score_stack_summary(heroic_items, "Heroic")
		stack.removal_started = false
		_update_score_stack_label(stack)
		_play_score_stack_update_pulse(stack)
		heroic_score_stack_coalesces += 1
		heroic_score_stack_labels_avoided += maxi(heroic_items.size(), 1)

	if not did_update_existing_stack and heroic_items.size() > 1:
		heroic_score_stack_labels_avoided += heroic_items.size() - 1

	heroic_stack_path_count += 1
	heroic_special_popups_avoided += 1
	_record_score_popup_route("heroic_stack", ball_label, heroic_items, amount)
	_print_popup_line_items_added(ball_label, heroic_items)
	_refresh_score_stack_lane_state(stack)
	return true


func _try_add_legendary_items_to_score_stack(
	ball_id: int,
	ball_label: String,
	legendary_items: Array[Dictionary]
) -> bool:
	var stack_key: String = _get_legendary_stack_key(ball_id)
	if stack_key.is_empty():
		return false

	var stack: ScoreStack = _get_active_score_stack(stack_key)
	var amount: int = _sum_line_items(legendary_items)
	if amount <= 0:
		return false

	var did_update_existing_stack: bool = stack != null
	if stack == null:
		stack = _create_legendary_score_stack(ball_id, stack_key)
		if stack == null:
			return false
		stack.total = amount
		stack.latest_summary = _make_score_stack_summary(legendary_items, "Legendary")
		_update_score_stack_label(stack)
		_play_score_stack_pop_in(stack)
	else:
		stack.total += amount
		stack.latest_summary = _make_score_stack_summary(legendary_items, "Legendary")
		stack.removal_started = false
		_update_score_stack_label(stack)
		_play_score_stack_update_pulse(stack)
		legendary_score_stack_coalesces += 1
		legendary_score_stack_labels_avoided += maxi(legendary_items.size(), 1)

	if not did_update_existing_stack and legendary_items.size() > 1:
		legendary_score_stack_labels_avoided += legendary_items.size() - 1

	legendary_stack_path_count += 1
	legendary_special_popups_avoided += 1
	_record_score_popup_route("legendary_stack", ball_label, legendary_items, amount)
	_print_popup_line_items_added(ball_label, legendary_items)
	_refresh_score_stack_lane_state(stack)
	return true


func _is_foundational_stack_line_item(line_item: Dictionary) -> bool:
	if int(line_item.get("amount", 0)) <= 0:
		return false
	if str(line_item.get("label", "")) == "Sink":
		return true

	var event_type: String = str(line_item.get("event_type", ""))
	return FOUNDATIONAL_EVENT_TYPES.has(event_type)


func _is_skilled_stack_line_item(line_item: Dictionary) -> bool:
	if int(line_item.get("amount", 0)) <= 0:
		return false

	var event_type: String = str(line_item.get("event_type", ""))
	return SKILLED_EVENT_TYPES.has(event_type)


func _is_heroic_stack_line_item(line_item: Dictionary) -> bool:
	if int(line_item.get("amount", 0)) <= 0:
		return false

	var event_type: String = str(line_item.get("event_type", ""))
	return HEROIC_EVENT_TYPES.has(event_type)


func _is_legendary_stack_line_item(line_item: Dictionary) -> bool:
	if int(line_item.get("amount", 0)) <= 0:
		return false

	var event_type: String = str(line_item.get("event_type", ""))
	return LEGENDARY_EVENT_TYPES.has(event_type)


func _make_foundational_stack_summary(foundational_items: Array[Dictionary]) -> String:
	return _make_score_stack_summary(foundational_items, "Sink")

func _make_score_stack_summary(line_items: Array[Dictionary], fallback_text: String) -> String:
	var contributors: Array[String] = []
	for line_item in line_items:
		var event_type: String = str(line_item.get("event_type", ""))
		var label_text: String = _get_event_reward_label(event_type) if not event_type.is_empty() else str(line_item.get("label", ""))
		if label_text.is_empty() or label_text == "Sink":
			continue
		if contributors.has(label_text):
			continue
		contributors.append(label_text)

	if contributors.is_empty():
		return fallback_text
	return " / ".join(contributors)


func _get_foundational_stack_key(ball_id: int) -> String:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	if pocket_position != Vector2.ZERO:
		return _make_foundational_position_stack_key(pocket_position)

	var sink_position: Vector2 = context.get("sink_position", Vector2.ZERO)
	var nearest_pocket_position: Vector2 = _get_nearest_foundational_pocket_position(sink_position)
	if nearest_pocket_position != Vector2.ZERO:
		return _make_foundational_position_stack_key(nearest_pocket_position)

	return _make_foundational_fallback_stack_key(ball_id)


func _get_skilled_stack_key(ball_id: int) -> String:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	if pocket_position != Vector2.ZERO:
		return _make_score_stack_position_key(SKILLED_STACK_CLASS_ID, pocket_position)

	var sink_position: Vector2 = context.get("sink_position", Vector2.ZERO)
	var nearest_pocket_position: Vector2 = _get_nearest_foundational_pocket_position(sink_position)
	if nearest_pocket_position != Vector2.ZERO:
		return _make_score_stack_position_key(SKILLED_STACK_CLASS_ID, nearest_pocket_position)

	return _make_score_stack_fallback_key(SKILLED_STACK_CLASS_ID, ball_id)


func _get_heroic_stack_key(ball_id: int) -> String:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	if pocket_position != Vector2.ZERO:
		return _make_score_stack_position_key(HEROIC_STACK_CLASS_ID, pocket_position)

	var sink_position: Vector2 = context.get("sink_position", Vector2.ZERO)
	var nearest_pocket_position: Vector2 = _get_nearest_foundational_pocket_position(sink_position)
	if nearest_pocket_position != Vector2.ZERO:
		return _make_score_stack_position_key(HEROIC_STACK_CLASS_ID, nearest_pocket_position)

	return _make_score_stack_fallback_key(HEROIC_STACK_CLASS_ID, ball_id)


func _get_legendary_stack_key(ball_id: int) -> String:
	var context: Dictionary = sink_contexts_by_ball.get(ball_id, {})
	var pocket_position: Vector2 = context.get("pocket_position", Vector2.ZERO)
	if pocket_position != Vector2.ZERO:
		return _make_score_stack_position_key(LEGENDARY_STACK_CLASS_ID, pocket_position)

	var sink_position: Vector2 = context.get("sink_position", Vector2.ZERO)
	var nearest_pocket_position: Vector2 = _get_nearest_foundational_pocket_position(sink_position)
	if nearest_pocket_position != Vector2.ZERO:
		return _make_score_stack_position_key(LEGENDARY_STACK_CLASS_ID, nearest_pocket_position)

	return _make_score_stack_fallback_key(LEGENDARY_STACK_CLASS_ID, ball_id)


func _make_foundational_position_stack_key(pocket_position: Vector2) -> String:
	return _make_score_stack_position_key(FOUNDATIONAL_STACK_CLASS_ID, pocket_position)


func _make_score_stack_position_key(stack_class_id: String, pocket_position: Vector2) -> String:
	var pocket_x: int = int(pocket_position.x + 0.5)
	var pocket_y: int = int(pocket_position.y + 0.5)
	return "%s:%s:%s" % [stack_class_id, pocket_x, pocket_y]


func _make_foundational_fallback_stack_key(ball_id: int) -> String:
	return _make_score_stack_fallback_key(FOUNDATIONAL_STACK_CLASS_ID, ball_id)


func _make_score_stack_fallback_key(stack_class_id: String, ball_id: int) -> String:
	return "%s:fallback:%s" % [stack_class_id, ball_id]


func _get_nearest_foundational_pocket_position(anchor_position: Vector2) -> Vector2:
	if table == null or anchor_position == Vector2.ZERO:
		return Vector2.ZERO

	var pocket_positions: Array[Vector2] = table.pocket_system.get_pocket_positions()
	var nearest_position: Vector2 = Vector2.ZERO
	var nearest_distance_squared: float = INF
	for pocket_position in pocket_positions:
		var distance_squared: float = anchor_position.distance_squared_to(pocket_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_position = pocket_position

	var max_distance_squared: float = FOUNDATIONAL_STACK_NEAREST_POCKET_MAX_DISTANCE * FOUNDATIONAL_STACK_NEAREST_POCKET_MAX_DISTANCE
	if nearest_distance_squared > max_distance_squared:
		return Vector2.ZERO
	return nearest_position


func _get_active_score_stack(stack_key: String) -> ScoreStack:
	var stack: ScoreStack = score_stacks_by_key.get(stack_key) as ScoreStack
	if stack == null or stack.removal_started:
		return null
	if not is_instance_valid(stack.label):
		return null
	return stack


func _create_foundational_score_stack(ball_id: int, stack_key: String) -> ScoreStack:
	return _create_score_stack(ball_id, stack_key, FOUNDATIONAL_STACK_CLASS_ID)


func _create_skilled_score_stack(ball_id: int, stack_key: String) -> ScoreStack:
	return _create_score_stack(ball_id, stack_key, SKILLED_STACK_CLASS_ID)


func _create_heroic_score_stack(ball_id: int, stack_key: String) -> ScoreStack:
	return _create_score_stack(ball_id, stack_key, HEROIC_STACK_CLASS_ID)


func _create_legendary_score_stack(ball_id: int, stack_key: String) -> ScoreStack:
	return _create_score_stack(ball_id, stack_key, LEGENDARY_STACK_CLASS_ID)


func _create_score_stack(ball_id: int, stack_key: String, stack_class_id: String) -> ScoreStack:
	var stack: ScoreStack = ScoreStack.new()
	stack.stack_key = stack_key
	stack.stack_class_id = stack_class_id
	stack.inward_direction = _get_popup_inward_direction(ball_id)
	stack.anchor_position = _get_popup_anchor_position(ball_id)
	stack.pocket_radius = _get_popup_pocket_radius(ball_id)
	stack.is_corner_pocket = _is_corner_pocket_position(stack.anchor_position)
	stack.outward_direction = _get_popup_outward_direction(ball_id)
	stack.tangent_direction = _get_popup_tangent_direction(ball_id, stack.is_corner_pocket)
	stack.line_rotation = stack.tangent_direction.angle()
	stack.hold_timer = _get_score_stack_hold_time(stack)
	stack.label = _make_score_stack_label("+0", stack.stack_class_id)
	stack.subtitle_label = _make_score_stack_subtitle_label("", stack.stack_class_id)
	table.add_child(stack.label)
	table.add_child(stack.subtitle_label)
	_place_score_label_below_gameplay(stack.label)
	_place_score_label_below_gameplay(stack.subtitle_label)
	score_stacks_by_key[stack_key] = stack
	active_score_stacks.append(stack)
	return stack


func _get_score_stack_hold_time(stack: ScoreStack) -> float:
	if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return LEGENDARY_STACK_HOLD_TIME
	if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return HEROIC_STACK_HOLD_TIME
	if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return SKILLED_STACK_HOLD_TIME
	return FOUNDATIONAL_STACK_HOLD_TIME


func _get_score_stack_fade_time(stack: ScoreStack) -> float:
	if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return LEGENDARY_STACK_FADE_TIME
	if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return HEROIC_STACK_FADE_TIME
	if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return SKILLED_STACK_FADE_TIME
	return FOUNDATIONAL_STACK_FADE_TIME


func _get_score_stack_subtitle_gap(stack: ScoreStack) -> float:
	if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return LEGENDARY_STACK_SUBTITLE_GAP
	if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return HEROIC_STACK_SUBTITLE_GAP
	if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return SKILLED_STACK_SUBTITLE_GAP
	return FOUNDATIONAL_STACK_SUBTITLE_GAP


func _get_score_stack_update_pulse_time(stack: ScoreStack) -> float:
	if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return LEGENDARY_STACK_UPDATE_PULSE_TIME
	if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return HEROIC_STACK_UPDATE_PULSE_TIME
	if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return SKILLED_STACK_UPDATE_PULSE_TIME
	return FOUNDATIONAL_STACK_UPDATE_PULSE_TIME


func _get_score_stack_update_pulse_scale(stack: ScoreStack) -> Vector2:
	if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return LEGENDARY_STACK_UPDATE_PULSE_SCALE
	if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return HEROIC_STACK_UPDATE_PULSE_SCALE
	if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return SKILLED_STACK_UPDATE_PULSE_SCALE
	return FOUNDATIONAL_STACK_UPDATE_PULSE_SCALE


func _get_score_stack_pop_scale(stack: ScoreStack) -> Vector2:
	if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return LEGENDARY_STACK_POP_SCALE
	if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return HEROIC_STACK_POP_SCALE
	if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return SKILLED_STACK_POP_SCALE
	return SCORE_POPUP_POP_SCALE


func _get_score_stack_flash_color(stack: ScoreStack) -> Color:
	if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return LEGENDARY_STACK_POP_FLASH_COLOR
	if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return HEROIC_STACK_POP_FLASH_COLOR
	if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return SKILLED_STACK_POP_FLASH_COLOR
	return SCORE_LABEL_POP_FLASH_COLOR


func _get_score_stack_subtitle_char_width(stack: ScoreStack) -> float:
	if stack != null and stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return 9.6
	if stack != null and stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return 9.2
	if stack != null and stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return 8.8
	return 8.0


func _get_score_stack_anchor_offset(stack: ScoreStack) -> Vector2:
	if stack == null:
		return Vector2.ZERO

	var outward_offset: float = stack.retreat_offset
	if stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		outward_offset += LEGENDARY_STACK_OUTWARD_OFFSET
	elif stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		outward_offset += HEROIC_STACK_OUTWARD_OFFSET
	elif stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		outward_offset += SKILLED_STACK_OUTWARD_OFFSET
	return stack.outward_direction * outward_offset + stack.tangent_direction * stack.lane_tangent_offset


func _get_score_stack_subtitle_offset(stack: ScoreStack) -> Vector2:
	if _is_center_pocket_score_stack(stack):
		var center_gap: float = _get_score_stack_subtitle_gap(stack) * SCORE_STACK_CENTER_POCKET_SUBTITLE_GAP_SCALE
		return _get_score_stack_subtitle_direction(stack) * center_gap
	if _is_bottom_pocket_score_stack(stack):
		return stack.outward_direction * (_get_score_stack_subtitle_gap(stack) + SCORE_STACK_BOTTOM_POCKET_SUBTITLE_EXTRA_GAP)
	return _get_score_stack_subtitle_direction(stack) * _get_score_stack_subtitle_gap(stack)


func _get_score_stack_subtitle_direction(stack: ScoreStack) -> Vector2:
	if _is_bottom_pocket_score_stack(stack):
		return stack.outward_direction
	return stack.inward_direction


func _is_center_pocket_score_stack(stack: ScoreStack) -> bool:
	return stack != null and not stack.is_corner_pocket


func _is_bottom_pocket_score_stack(stack: ScoreStack) -> bool:
	if stack == null or table == null:
		return false

	return stack.anchor_position.y > table.playfield_rect.get_center().y


func _get_score_stack_tier_priority(stack: ScoreStack) -> int:
	if stack == null:
		return -1
	if stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return 3
	if stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		return 2
	if stack.stack_class_id == SKILLED_STACK_CLASS_ID:
		return 1
	return 0


# Lane pressure is event-time only: stack creation/update checks nearby active
# stacks once, then stores simple offsets/hold-time changes for normal updates.
func _refresh_score_stack_lane_state(stack: ScoreStack) -> void:
	if stack == null:
		return

	stack.hold_timer = _get_score_stack_hold_time(stack)
	stack.retreat_target = 0.0
	_apply_score_stack_lane_pressure(stack)
	_update_score_stack_label_layout(stack)


func _apply_score_stack_lane_pressure(stack: ScoreStack) -> void:
	if stack == null or stack.removal_started:
		return

	var stack_priority: int = _get_score_stack_tier_priority(stack)
	var conflict_index: int = 0
	for stack_value in active_score_stacks:
		var other_stack: ScoreStack = stack_value as ScoreStack
		if _should_skip_score_stack_lane_check(stack, other_stack):
			continue
		if not _score_stacks_are_nearby(stack, other_stack):
			continue

		conflict_index += 1
		score_stack_lane_conflicts += 1
		var other_priority: int = _get_score_stack_tier_priority(other_stack)
		if stack_priority > other_priority:
			_request_score_stack_yield(other_stack, stack)
		elif other_priority > stack_priority:
			_request_score_stack_yield(stack, other_stack)
		else:
			_separate_peer_score_stack_lane(stack, other_stack, conflict_index)


func _should_skip_score_stack_lane_check(stack: ScoreStack, other_stack: ScoreStack) -> bool:
	if other_stack == null or other_stack == stack:
		return true
	if other_stack.removal_started:
		return true
	return not is_instance_valid(other_stack.label)


func _score_stacks_are_nearby(stack: ScoreStack, other_stack: ScoreStack) -> bool:
	var max_distance_squared: float = SCORE_STACK_LANE_CONFLICT_DISTANCE * SCORE_STACK_LANE_CONFLICT_DISTANCE
	return stack.anchor_position.distance_squared_to(other_stack.anchor_position) <= max_distance_squared


func _request_score_stack_yield(yielding_stack: ScoreStack, dominant_stack: ScoreStack) -> void:
	var yielding_priority: int = _get_score_stack_tier_priority(yielding_stack)
	var dominant_priority: int = _get_score_stack_tier_priority(dominant_stack)
	if yielding_priority >= dominant_priority or yielding_priority >= 3:
		return

	score_stack_yields += 1
	var target_hold: float = _get_score_stack_yield_hold_time(yielding_priority, dominant_priority)
	if yielding_stack.hold_timer > target_hold:
		yielding_stack.hold_timer = target_hold
		score_stack_early_fades += 1
		score_stack_replacements += 1

	var retreat_distance: float = _get_score_stack_yield_retreat_distance(yielding_priority, dominant_priority)
	yielding_stack.retreat_target = maxf(yielding_stack.retreat_target, retreat_distance)
	_update_score_stack_label_layout(yielding_stack)


func _get_score_stack_yield_hold_time(yielding_priority: int, dominant_priority: int) -> float:
	if yielding_priority == 0:
		return 0.22 if dominant_priority >= 2 else 0.45
	if yielding_priority == 1:
		return 0.34 if dominant_priority >= 3 else 0.58
	if yielding_priority == 2 and dominant_priority >= 3:
		return 0.78
	return 0.6


func _get_score_stack_yield_retreat_distance(yielding_priority: int, dominant_priority: int) -> float:
	if yielding_priority == 0:
		return 24.0 if dominant_priority >= 2 else 16.0
	if yielding_priority == 1:
		return 18.0 if dominant_priority >= 3 else 12.0
	if yielding_priority == 2:
		return 10.0
	return 0.0


func _separate_peer_score_stack_lane(stack: ScoreStack, other_stack: ScoreStack, conflict_index: int) -> void:
	var lane_direction: float = _get_score_stack_tangent_separation_sign(stack, other_stack)
	var target_offset: float = lane_direction * SCORE_STACK_LANE_SIDE_STEP * float(conflict_index)
	if absf(stack.lane_tangent_offset) >= absf(target_offset):
		return

	stack.lane_tangent_offset = target_offset
	_update_score_stack_label_layout(stack)


func _get_score_stack_tangent_separation_sign(stack: ScoreStack, other_stack: ScoreStack) -> float:
	var tangent_distance: float = (stack.anchor_position - other_stack.anchor_position).dot(stack.tangent_direction)
	if absf(tangent_distance) > 0.5:
		return 1.0 if tangent_distance >= 0.0 else -1.0

	var stack_index: int = active_score_stacks.find(stack)
	return 1.0 if stack_index % 2 == 0 else -1.0


func _add_foundational_fallback_score_label(
	ball_id: int,
	ball_label: String,
	foundational_items: Array[Dictionary]
) -> void:
	var amount: int = _sum_line_items(foundational_items)
	if amount <= 0:
		return

	var stack_key: String = _make_foundational_fallback_stack_key(ball_id)
	var stack: ScoreStack = _get_active_score_stack(stack_key)
	if stack == null:
		stack = _create_foundational_score_stack(ball_id, stack_key)
		if stack == null:
			return
		stack.total = amount
		stack.latest_summary = _make_foundational_stack_summary(foundational_items)
		_update_score_stack_label(stack)
		_play_score_stack_pop_in(stack)
	else:
		stack.total += amount
		stack.latest_summary = _make_foundational_stack_summary(foundational_items)
		_update_score_stack_label(stack)
		_play_score_stack_update_pulse(stack)
		foundational_score_stack_coalesces += 1

	foundational_fallback_stack_path_count += 1
	foundational_score_stack_labels_avoided += foundational_items.size()
	_record_score_popup_route("foundational_fallback", ball_label, foundational_items, amount)
	_print_popup_line_items_added(ball_label, foundational_items)
	_refresh_score_stack_lane_state(stack)


func _add_skilled_fallback_score_label(
	ball_id: int,
	ball_label: String,
	skilled_items: Array[Dictionary]
) -> void:
	var amount: int = _sum_line_items(skilled_items)
	if amount <= 0:
		return

	var stack_key: String = _make_score_stack_fallback_key(SKILLED_STACK_CLASS_ID, ball_id)
	var stack: ScoreStack = _get_active_score_stack(stack_key)
	if stack == null:
		stack = _create_skilled_score_stack(ball_id, stack_key)
		if stack == null:
			return
		stack.total = amount
		stack.latest_summary = _make_score_stack_summary(skilled_items, "Skilled")
		_update_score_stack_label(stack)
		_play_score_stack_pop_in(stack)
	else:
		stack.total += amount
		stack.latest_summary = _make_score_stack_summary(skilled_items, "Skilled")
		_update_score_stack_label(stack)
		_play_score_stack_update_pulse(stack)
		skilled_score_stack_coalesces += 1

	skilled_stack_path_count += 1
	skilled_special_popups_avoided += 1
	skilled_score_stack_labels_avoided += skilled_items.size()
	_record_score_popup_route("skilled_fallback", ball_label, skilled_items, amount)
	_print_popup_line_items_added(ball_label, skilled_items)
	_refresh_score_stack_lane_state(stack)


func _add_heroic_fallback_score_label(
	ball_id: int,
	ball_label: String,
	heroic_items: Array[Dictionary]
) -> void:
	var amount: int = _sum_line_items(heroic_items)
	if amount <= 0:
		return

	var stack_key: String = _make_score_stack_fallback_key(HEROIC_STACK_CLASS_ID, ball_id)
	var stack: ScoreStack = _get_active_score_stack(stack_key)
	if stack == null:
		stack = _create_heroic_score_stack(ball_id, stack_key)
		if stack == null:
			return
		stack.total = amount
		stack.latest_summary = _make_score_stack_summary(heroic_items, "Heroic")
		_update_score_stack_label(stack)
		_play_score_stack_pop_in(stack)
	else:
		stack.total += amount
		stack.latest_summary = _make_score_stack_summary(heroic_items, "Heroic")
		_update_score_stack_label(stack)
		_play_score_stack_update_pulse(stack)
		heroic_score_stack_coalesces += 1

	heroic_stack_path_count += 1
	heroic_special_popups_avoided += 1
	heroic_score_stack_labels_avoided += heroic_items.size()
	_record_score_popup_route("heroic_fallback", ball_label, heroic_items, amount)
	_print_popup_line_items_added(ball_label, heroic_items)
	_refresh_score_stack_lane_state(stack)


func _add_legendary_fallback_score_label(
	ball_id: int,
	ball_label: String,
	legendary_items: Array[Dictionary]
) -> void:
	var amount: int = _sum_line_items(legendary_items)
	if amount <= 0:
		return

	var stack_key: String = _make_score_stack_fallback_key(LEGENDARY_STACK_CLASS_ID, ball_id)
	var stack: ScoreStack = _get_active_score_stack(stack_key)
	if stack == null:
		stack = _create_legendary_score_stack(ball_id, stack_key)
		if stack == null:
			return
		stack.total = amount
		stack.latest_summary = _make_score_stack_summary(legendary_items, "Legendary")
		_update_score_stack_label(stack)
		_play_score_stack_pop_in(stack)
	else:
		stack.total += amount
		stack.latest_summary = _make_score_stack_summary(legendary_items, "Legendary")
		_update_score_stack_label(stack)
		_play_score_stack_update_pulse(stack)
		legendary_score_stack_coalesces += 1

	legendary_stack_path_count += 1
	legendary_special_popups_avoided += 1
	legendary_score_stack_labels_avoided += legendary_items.size()
	_record_score_popup_route("legendary_fallback", ball_label, legendary_items, amount)
	_print_popup_line_items_added(ball_label, legendary_items)
	_refresh_score_stack_lane_state(stack)


func _print_popup_line_items_added(ball_label: String, line_items: Array[Dictionary]) -> void:
	if not DEBUG_SCORE_BREAKDOWNS:
		return

	for line_item in line_items:
		print("Popup add: %s -> %s +%s" % [ball_label, line_item["label"], line_item["amount"]])


func _record_score_popup_route(
	route_name: String,
	ball_label: String,
	line_items: Array[Dictionary],
	amount: int
) -> void:
	last_score_popup_route = "%s +%s %s" % [route_name, amount, _make_score_route_summary(line_items)]
	if route_name == "special_popup":
		special_popup_path_count += 1
	if DEBUG_SCORE_POPUP_ROUTING_LOGS:
		print("Score route: %s -> %s" % [ball_label, last_score_popup_route])


func _make_score_route_summary(line_items: Array[Dictionary]) -> String:
	var labels: Array[String] = []
	for line_item in line_items:
		var label_text: String = str(line_item.get("label", ""))
		if not label_text.is_empty():
			labels.append(label_text)
	if labels.is_empty():
		return "none"
	return " / ".join(labels)


func _emit_score_feed_message(ball_label: String, line_items: Array[Dictionary], amount: int) -> void:
	if amount <= 0:
		return

	var summary: String = _make_score_route_summary(line_items)
	if summary == "none":
		score_feed_message.emit("%s: +%s Doubloons" % [ball_label, amount])
	else:
		score_feed_message.emit("%s: +%s Doubloons (%s)" % [ball_label, amount, summary])


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


func _update_score_stack(stack: ScoreStack, delta: float) -> void:
	if stack == null or stack.removal_started:
		return

	_update_score_stack_drift(stack, delta)
	stack.hold_timer -= delta
	if stack.hold_timer <= 0.0:
		_fade_out_score_stack(stack)


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
	if event_type == ShotEventSystem.EVENT_BANK:
		return "Bank"
	if event_type == ShotEventSystem.EVENT_CHAIN:
		return "Chain"
	if event_type == ShotEventSystem.EVENT_MULTI_CHAIN:
		return "Multi Chain"
	if event_type == ShotEventSystem.EVENT_MULTI_SINK:
		return "Multi Sink"
	if event_type == ShotEventSystem.EVENT_ANOMALY_TOUCH:
		return "Anomaly Touch"
	if event_type == ShotEventSystem.EVENT_KRAKEN_KICK:
		return "Kraken Kick"
	if event_type == ShotEventSystem.EVENT_DOUBLE_BANK:
		return "Double Bank"
	if event_type == ShotEventSystem.EVENT_THIN_CUT:
		return "Thin Cut"
	if event_type == ShotEventSystem.EVENT_CLUSTER_BREAK:
		return "Cluster Break"
	if event_type == ShotEventSystem.EVENT_LAST_GASP:
		return "Last Gasp"
	if event_type == ShotEventSystem.EVENT_POWER_SINK:
		return "Power Sink"
	if event_type == ShotEventSystem.EVENT_SPLIT_THE_LOOT:
		return "Split the Loot"
	if event_type == ShotEventSystem.EVENT_CROSS_CORNER_BANK:
		return "Cross-Corner Bank"
	if event_type == ShotEventSystem.EVENT_FULL_TABLE_KICK:
		return "Full-Table Kick"
	if event_type == ShotEventSystem.EVENT_LONG_HAUL:
		return "Long Haul"
	if event_type == ShotEventSystem.EVENT_POWDER_ROUTE:
		return "Powder Route"
	if event_type == ShotEventSystem.EVENT_KRAKEN_CURRENT:
		return "Kraken Current"
	if event_type == ShotEventSystem.EVENT_TRIPLE_BANK:
		return "Triple Bank"
	if event_type == ShotEventSystem.EVENT_CANNON_CHAIN:
		return "Cannon Chain"
	if event_type == ShotEventSystem.EVENT_TREASURE_SNARE:
		return "Treasure Snare"
	if event_type == EVENT_TREASURE_CLAIM:
		return "Treasure Claimed"
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


func _make_score_stack_label(text: String, stack_class_id: String) -> Label:
	if stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return _make_legendary_score_stack_label(text)
	if stack_class_id == HEROIC_STACK_CLASS_ID:
		return _make_heroic_score_stack_label(text)
	if stack_class_id == SKILLED_STACK_CLASS_ID:
		return _make_skilled_score_stack_label(text)
	return _make_score_segment_label(text)


func _make_skilled_score_stack_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.scale = SCORE_POPUP_START_SCALE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", SKILLED_STACK_NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_color", SKILLED_STACK_NUMBER_COLOR)
	label.add_theme_color_override("font_shadow_color", SKILLED_STACK_SHADOW_COLOR)
	label.add_theme_color_override("font_outline_color", SKILLED_STACK_OUTLINE_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 6)
	label.modulate = SCORE_LABEL_HIDDEN_MODULATE
	return label


func _make_heroic_score_stack_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.scale = SCORE_POPUP_START_SCALE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", HEROIC_STACK_NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_color", HEROIC_STACK_NUMBER_COLOR)
	label.add_theme_color_override("font_shadow_color", HEROIC_STACK_SHADOW_COLOR)
	label.add_theme_color_override("font_outline_color", HEROIC_STACK_OUTLINE_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 7)
	label.modulate = SCORE_LABEL_HIDDEN_MODULATE
	return label


func _make_legendary_score_stack_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.scale = SCORE_POPUP_START_SCALE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", LEGENDARY_STACK_NUMBER_FONT_SIZE)
	label.add_theme_color_override("font_color", LEGENDARY_STACK_NUMBER_COLOR)
	label.add_theme_color_override("font_shadow_color", LEGENDARY_STACK_SHADOW_COLOR)
	label.add_theme_color_override("font_outline_color", LEGENDARY_STACK_OUTLINE_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 8)
	label.modulate = SCORE_LABEL_HIDDEN_MODULATE
	return label


func _make_score_stack_subtitle_label(text: String, stack_class_id: String) -> Label:
	if stack_class_id == LEGENDARY_STACK_CLASS_ID:
		return _make_legendary_stack_subtitle_label(text)
	if stack_class_id == HEROIC_STACK_CLASS_ID:
		return _make_heroic_stack_subtitle_label(text)
	if stack_class_id == SKILLED_STACK_CLASS_ID:
		return _make_skilled_stack_subtitle_label(text)
	return _make_foundational_stack_subtitle_label(text)


func _make_foundational_stack_subtitle_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.scale = SCORE_POPUP_START_SCALE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", FOUNDATIONAL_STACK_SUBTITLE_FONT_SIZE)
	label.add_theme_color_override("font_color", FOUNDATIONAL_STACK_SUBTITLE_COLOR)
	label.add_theme_color_override("font_shadow_color", Color(0.04, 0.02, 0.0, 0.74))
	label.add_theme_color_override("font_outline_color", Color(0.16, 0.08, 0.02, 0.90))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("outline_size", 2)
	label.modulate = SCORE_LABEL_HIDDEN_MODULATE
	return label


func _make_skilled_stack_subtitle_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.scale = SCORE_POPUP_START_SCALE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", SKILLED_STACK_SUBTITLE_FONT_SIZE)
	label.add_theme_color_override("font_color", SKILLED_STACK_SUBTITLE_COLOR)
	label.add_theme_color_override("font_shadow_color", SKILLED_STACK_SHADOW_COLOR)
	label.add_theme_color_override("font_outline_color", SKILLED_STACK_OUTLINE_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("outline_size", 3)
	label.modulate = SCORE_LABEL_HIDDEN_MODULATE
	return label


func _make_heroic_stack_subtitle_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.scale = SCORE_POPUP_START_SCALE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", HEROIC_STACK_SUBTITLE_FONT_SIZE)
	label.add_theme_color_override("font_color", HEROIC_STACK_SUBTITLE_COLOR)
	label.add_theme_color_override("font_shadow_color", HEROIC_STACK_SHADOW_COLOR)
	label.add_theme_color_override("font_outline_color", HEROIC_STACK_OUTLINE_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("outline_size", 4)
	label.modulate = SCORE_LABEL_HIDDEN_MODULATE
	return label


func _make_legendary_stack_subtitle_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.scale = SCORE_POPUP_START_SCALE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", LEGENDARY_STACK_SUBTITLE_FONT_SIZE)
	label.add_theme_color_override("font_color", LEGENDARY_STACK_SUBTITLE_COLOR)
	label.add_theme_color_override("font_shadow_color", LEGENDARY_STACK_SHADOW_COLOR)
	label.add_theme_color_override("font_outline_color", LEGENDARY_STACK_OUTLINE_COLOR)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("outline_size", 4)
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


func _spawn_reveal_glow(
	label: Label,
	target_position: Variant = null,
	glow_font_color: Color = SCORE_LABEL_GLOW_FONT_COLOR,
	glow_outline_color: Color = SCORE_LABEL_GLOW_OUTLINE_COLOR,
	glow_outline_size: int = SCORE_LABEL_GLOW_OUTLINE_SIZE,
	glow_modulate: Color = SCORE_LABEL_GLOW_COLOR
) -> void:
	call_deferred(
		"_spawn_reveal_glow_deferred",
		label,
		target_position,
		glow_font_color,
		glow_outline_color,
		glow_outline_size,
		glow_modulate
	)


func _spawn_reveal_glow_deferred(
	label: Label,
	target_position: Variant = null,
	glow_font_color: Color = SCORE_LABEL_GLOW_FONT_COLOR,
	glow_outline_color: Color = SCORE_LABEL_GLOW_OUTLINE_COLOR,
	glow_outline_size: int = SCORE_LABEL_GLOW_OUTLINE_SIZE,
	glow_modulate: Color = SCORE_LABEL_GLOW_COLOR
) -> void:
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
	glow_label.modulate = glow_modulate
	_apply_glow_label_theme(label, glow_label, glow_font_color, glow_outline_color, glow_outline_size)
	table.add_child(glow_label)
	table.move_child(glow_label, label.get_index())
	_track_score_glow_label(glow_label)

	var tween: Tween = _create_score_popup_tween()
	tween.set_parallel(true)
	if target_position is Vector2:
		tween.tween_property(glow_label, "position", target_position, SCORE_LABEL_GLOW_POP_TIME + SCORE_LABEL_GLOW_FADE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_label, "scale", SCORE_LABEL_GLOW_PEAK_BOOST, SCORE_LABEL_GLOW_POP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_label, "modulate:a", 0.0, SCORE_LABEL_GLOW_POP_TIME + SCORE_LABEL_GLOW_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(glow_label.queue_free)


func _apply_glow_label_theme(
	source: Label,
	target: Label,
	glow_font_color: Color,
	glow_outline_color: Color,
	glow_outline_size: int
) -> void:
	target.add_theme_font_override("font", source.get_theme_font("font"))
	target.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	target.add_theme_color_override("font_color", glow_font_color)
	target.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0))
	target.add_theme_color_override("font_outline_color", glow_outline_color)
	target.add_theme_constant_override("outline_size", glow_outline_size)
	target.add_theme_constant_override("shadow_offset_x", 0)
	target.add_theme_constant_override("shadow_offset_y", 0)


func _spawn_score_stack_reveal_glow(stack: ScoreStack) -> void:
	if stack == null or not is_instance_valid(stack.label):
		return
	if stack.stack_class_id == LEGENDARY_STACK_CLASS_ID:
		_spawn_reveal_glow(
			stack.label,
			null,
			LEGENDARY_STACK_GLOW_FONT_COLOR,
			LEGENDARY_STACK_GLOW_OUTLINE_COLOR,
			LEGENDARY_STACK_GLOW_OUTLINE_SIZE,
			LEGENDARY_STACK_GLOW_COLOR
		)
		return
	if stack.stack_class_id == HEROIC_STACK_CLASS_ID:
		_spawn_reveal_glow(
			stack.label,
			null,
			HEROIC_STACK_GLOW_FONT_COLOR,
			HEROIC_STACK_GLOW_OUTLINE_COLOR,
			HEROIC_STACK_GLOW_OUTLINE_SIZE,
			HEROIC_STACK_GLOW_COLOR
		)
		return
	if stack.stack_class_id != SKILLED_STACK_CLASS_ID:
		_spawn_reveal_glow(stack.label)
		return

	_spawn_reveal_glow(
		stack.label,
		null,
		SKILLED_STACK_GLOW_FONT_COLOR,
		SKILLED_STACK_GLOW_OUTLINE_COLOR,
		SKILLED_STACK_GLOW_OUTLINE_SIZE,
		SKILLED_STACK_GLOW_COLOR
	)


func _play_score_segment_pop_in(label: Label) -> void:
	_spawn_reveal_glow(label)
	var tween: Tween = _create_score_popup_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", SCORE_LABEL_POP_FLASH_COLOR, SCORE_POPUP_POP_IN_TIME)
	tween.tween_property(label, "scale", SCORE_POPUP_POP_SCALE, SCORE_POPUP_POP_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate", SCORE_LABEL_BASE_MODULATE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2.ONE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_score_stack_pop_in(stack: ScoreStack) -> void:
	if stack == null or not is_instance_valid(stack.label):
		return

	_spawn_score_stack_reveal_glow(stack)
	var tween: Tween = _create_score_popup_tween()
	tween.set_parallel(true)
	tween.tween_property(stack.label, "modulate", _get_score_stack_flash_color(stack), SCORE_POPUP_POP_IN_TIME)
	tween.tween_property(stack.label, "scale", _get_score_stack_pop_scale(stack), SCORE_POPUP_POP_IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(stack.subtitle_label):
		tween.tween_property(stack.subtitle_label, "modulate", SCORE_LABEL_BASE_MODULATE, SCORE_POPUP_POP_IN_TIME)
	tween.chain().tween_property(stack.label, "modulate", SCORE_LABEL_BASE_MODULATE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(stack.label, "scale", Vector2.ONE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _play_score_stack_update_pulse(stack: ScoreStack) -> void:
	if stack == null or not is_instance_valid(stack.label):
		return

	var tween: Tween = _create_score_popup_tween()
	tween.set_parallel(true)
	tween.tween_property(stack.label, "modulate", _get_score_stack_flash_color(stack), _get_score_stack_update_pulse_time(stack))
	tween.tween_property(stack.label, "scale", _get_score_stack_update_pulse_scale(stack), _get_score_stack_update_pulse_time(stack)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(stack.subtitle_label):
		tween.tween_property(stack.subtitle_label, "modulate", SCORE_LABEL_BASE_MODULATE, _get_score_stack_update_pulse_time(stack))
	tween.chain().tween_property(stack.label, "modulate", SCORE_LABEL_BASE_MODULATE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(stack.label, "scale", Vector2.ONE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _pulse_final_score_total(popup: ScorePopup) -> void:
	if popup.score_labels.is_empty():
		return

	var total_label: Label = popup.score_labels[popup.score_labels.size() - 1]
	var tween: Tween = _create_score_popup_tween()
	tween.tween_property(total_label, "scale", SCORE_POPUP_FINAL_PULSE_SCALE, SCORE_POPUP_POP_IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(total_label, "scale", Vector2.ONE, SCORE_POPUP_SETTLE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _show_event_label_for_latest_item(popup: ScorePopup) -> void:
	var line_item: Dictionary = popup.line_items[popup.revealed_count - 1]
	# Stack-routed tiers should not reach this fallback path, but keep the guard
	# so future route edits cannot accidentally resurrect named-label overlap.
	if (
		_is_foundational_stack_line_item(line_item)
		or _is_skilled_stack_line_item(line_item)
		or _is_heroic_stack_line_item(line_item)
		or _is_legendary_stack_line_item(line_item)
	):
		return

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
	var tween: Tween = _create_score_popup_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", target_position, SCORE_EVENT_LABEL_ERUPT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate", SCORE_LABEL_POP_FLASH_COLOR, SCORE_EVENT_LABEL_ERUPT_TIME)
	tween.tween_property(label, "scale", SCORE_EVENT_LABEL_POP_SCALE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate", SCORE_LABEL_BASE_MODULATE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2.ONE, SCORE_EVENT_LABEL_ERUPT_TIME * 0.45)


func _play_grouped_event_label_pop(label: Label) -> void:
	_spawn_reveal_glow(label)
	var tween: Tween = _create_score_popup_tween()
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


func _update_score_stack_drift(stack: ScoreStack, delta: float) -> void:
	var drift_step: Vector2 = stack.outward_direction * SCORE_POPUP_LIFETIME_DRIFT_SPEED * delta
	stack.lifetime_drift += drift_step
	_update_score_stack_retreat(stack, delta)
	_update_score_stack_label_layout(stack)


func _update_score_stack_retreat(stack: ScoreStack, delta: float) -> void:
	if stack == null:
		return

	var hold_time: float = _get_score_stack_hold_time(stack)
	if hold_time > 0.0 and stack.hold_timer <= hold_time * SCORE_STACK_INACTIVE_RETREAT_RATIO:
		stack.retreat_target = maxf(stack.retreat_target, _get_score_stack_inactive_retreat_distance(stack))

	var retreat_step: float = SCORE_STACK_RETREAT_SPEED * delta
	stack.retreat_offset = move_toward(stack.retreat_offset, stack.retreat_target, retreat_step)


func _get_score_stack_inactive_retreat_distance(stack: ScoreStack) -> float:
	var priority: int = _get_score_stack_tier_priority(stack)
	if priority <= 0:
		return 12.0
	if priority == 1:
		return 9.0
	if priority == 2:
		return 6.0
	return 3.0


func _update_score_stack_label(stack: ScoreStack) -> void:
	if stack == null or not is_instance_valid(stack.label):
		return

	stack.label.text = "+%s" % stack.total
	if is_instance_valid(stack.subtitle_label):
		stack.subtitle_label.text = stack.latest_summary
		stack.subtitle_label.modulate = SCORE_LABEL_BASE_MODULATE
	_update_score_stack_label_layout(stack)


func _update_score_stack_label_layout(stack: ScoreStack) -> void:
	if stack == null or not is_instance_valid(stack.label):
		return

	var width: float = maxf(36.0, float(stack.label.text.length()) * SCORE_SEGMENT_CHAR_WIDTH)
	var center: Vector2 = stack.anchor_position + stack.lifetime_drift + _get_score_stack_anchor_offset(stack)
	_apply_score_segment_label_layout(stack.label, center, width, stack.line_rotation)
	if is_instance_valid(stack.subtitle_label):
		var subtitle_width: float = maxf(56.0, float(stack.subtitle_label.text.length()) * _get_score_stack_subtitle_char_width(stack))
		var subtitle_center: Vector2 = center + _get_score_stack_subtitle_offset(stack)
		_apply_score_segment_label_layout(stack.subtitle_label, subtitle_center, subtitle_width, stack.line_rotation)


func _place_score_label_below_gameplay(label: Label) -> void:
	if table == null or label == null or label.get_parent() != table:
		return

	var target_index := _get_score_readability_insert_index()
	if target_index < 0:
		return

	table.move_child(label, clampi(target_index, 0, table.get_child_count() - 1))


func _get_score_readability_insert_index() -> int:
	if table == null:
		return -1
	if table.pocket_streak_presenter != null:
		return table.pocket_streak_presenter.get_index()

	var decor_layer: CanvasItem = table.get_node_or_null("TableDecorRandomizer") as CanvasItem
	if decor_layer != null:
		return decor_layer.get_index() + 1
	if table.aim_preview != null:
		return table.aim_preview.get_index()
	return table.get_child_count() - 1


func _fade_out_score_popup(popup: ScorePopup) -> void:
	popup.removal_started = true
	var tween: Tween = _create_score_popup_tween()
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


func _fade_out_score_stack(stack: ScoreStack) -> void:
	stack.removal_started = true
	if not is_instance_valid(stack.label):
		_remove_score_stack(stack)
		return

	var tween: Tween = _create_score_popup_tween()
	var drift: Vector2 = stack.outward_direction * SCORE_POPUP_OUTWARD_DRIFT_DISTANCE
	var fade_time: float = _get_score_stack_fade_time(stack)
	tween.set_parallel(true)
	tween.tween_property(stack.label, "position", stack.label.position + drift, fade_time)
	tween.tween_property(stack.label, "modulate:a", 0.0, fade_time)
	if is_instance_valid(stack.subtitle_label):
		tween.tween_property(stack.subtitle_label, "position", stack.subtitle_label.position + drift, fade_time)
		tween.tween_property(stack.subtitle_label, "modulate:a", 0.0, fade_time)
	tween.chain().tween_callback(_remove_score_stack.bind(stack))


func _remove_score_popup(popup: ScorePopup) -> void:
	active_score_popups.erase(popup)
	score_popups_by_ball.erase(popup.ball_id)
	for score_label in popup.score_labels:
		if is_instance_valid(score_label):
			score_label.queue_free()
	for event_label in popup.event_labels:
		if is_instance_valid(event_label):
			event_label.queue_free()


func _remove_score_stack(stack: ScoreStack) -> void:
	active_score_stacks.erase(stack)
	var mapped_stack: ScoreStack = score_stacks_by_key.get(stack.stack_key) as ScoreStack
	if mapped_stack == stack:
		score_stacks_by_key.erase(stack.stack_key)
	if is_instance_valid(stack.label):
		stack.label.queue_free()
	if is_instance_valid(stack.subtitle_label):
		stack.subtitle_label.queue_free()


func _track_score_glow_label(glow_label: Label) -> void:
	active_score_glow_label_count += 1
	glow_label.tree_exiting.connect(_on_score_glow_label_tree_exiting)


func _on_score_glow_label_tree_exiting() -> void:
	active_score_glow_label_count = maxi(active_score_glow_label_count - 1, 0)


func _create_score_popup_tween() -> Tween:
	var tween: Tween = table.create_tween()
	active_score_popup_tween_count += 1
	tween.finished.connect(_on_score_popup_tween_finished)
	return tween


func _on_score_popup_tween_finished() -> void:
	active_score_popup_tween_count = maxi(active_score_popup_tween_count - 1, 0)
