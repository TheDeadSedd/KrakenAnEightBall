extends Control
class_name RogueliteBuildTrayHUD

# Presentation-only five-slot Eight Ball build tray. RogueliteBuildSystem owns
# inventory, triggers, and modifier activation; this node mirrors value snapshots.

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")

const SLOT_COUNT := 5
const PANEL_MAX_WIDTH := 344.0
const PANEL_MIN_WIDTH := 276.0
const PANEL_TOP := 238.0
const VIEWPORT_MARGIN := 20.0
const RIGHT_MARGIN := 24.0
const PANEL_PADDING := 10.0
const HEADER_HEIGHT := 34.0
const SLOT_GAP := 5.0
const SLOT_MAX_HEIGHT := 62.0
const SLOT_MIN_HEIGHT := 46.0
const ICON_RADIUS := 18.0
const TOOLTIP_SIZE := Vector2(360.0, 250.0)
const PULSE_DURATION := 0.78
const LEGENDARY_PULSE_DURATION := 1.02

const EFFECT_KIND_PERSISTENT_SCALER := "persistent_scaler"
const EFFECT_KIND_CROSS_FAMILY_CONDITIONAL := "cross_family_conditional"
const EFFECT_KIND_SHOT_ORDINAL_MULTIPLIER := "shot_ordinal_multiplier"
const EFFECT_KIND_THRESHOLD_FAMILY_RETRIGGER := "threshold_family_retrigger"
const ENGINE_EVENT_STATE_GROWTH := "state_growth"
const ENGINE_EVENT_THRESHOLD_MARKER := "threshold_marker"

const PANEL_FILL := Color(0.025, 0.021, 0.026, 0.76)
const PANEL_BORDER := Color(0.86, 0.68, 0.32, 0.48)
const SLOT_FILL := Color(0.040, 0.034, 0.038, 0.84)
const SLOT_BORDER := Color(0.62, 0.52, 0.34, 0.42)
const EMPTY_FILL := Color(0.024, 0.023, 0.028, 0.52)
const EMPTY_BORDER := Color(0.42, 0.40, 0.42, 0.26)
const TITLE_COLOR := Color(1.0, 0.86, 0.48, 1.0)
const NAME_COLOR := Color(0.94, 0.90, 0.76, 1.0)
const EFFECT_COLOR := Color(0.73, 0.90, 0.84, 0.96)
const EMPTY_COLOR := Color(0.52, 0.50, 0.52, 0.70)
const SHADOW_COLOR := Color(0.01, 0.008, 0.012, 0.90)
const LEGENDARY_COLOR := Color(1.0, 0.76, 0.28, 1.0)
const LEGENDARY_PURPLE := Color(0.58, 0.27, 0.74, 1.0)

var latest_snapshot: Dictionary = {}
var slot_snapshots: Array[Dictionary] = []
var row_hit_areas: Array[Control] = []
var hovered_slot_index: int = -1
var hover_ui_suppressed: bool = false
var tray_enabled: bool = true
var layout_on_left: bool = false
var slot_height: float = SLOT_MAX_HEIGHT
var pulse_states: Dictionary = {}

var tooltip_panel: PanelContainer
var tooltip_title_label: Label
var tooltip_meta_label: Label
var tooltip_body_label: Label
var tooltip_status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 24
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_build_row_hit_areas()
	_build_tooltip()
	_apply_responsive_layout()
	set_build_snapshot({})
	set_process(false)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func set_build_snapshot(snapshot: Dictionary) -> void:
	latest_snapshot = snapshot.duplicate(true)
	slot_snapshots = _extract_slot_snapshots(snapshot)
	_prune_stale_pulses()
	_update_row_input()
	_apply_responsive_layout()
	_refresh_tooltip()
	queue_redraw()


func update_snapshot(snapshot: Dictionary) -> void:
	set_build_snapshot(snapshot)


func get_build_snapshot() -> Dictionary:
	return latest_snapshot.duplicate(true)


func get_slot_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in slot_snapshots:
		result.append(slot.duplicate(true))
	return result


func set_visible_for_build_mode(enabled: bool) -> void:
	tray_enabled = enabled
	visible = enabled
	if not enabled:
		_hide_tooltip()
		hovered_slot_index = -1


func set_layout_on_left(enabled: bool) -> void:
	if layout_on_left == enabled:
		return
	layout_on_left = enabled
	_apply_responsive_layout()
	queue_redraw()


func set_hover_ui_suppressed(suppressed: bool) -> void:
	hover_ui_suppressed = suppressed
	if suppressed:
		hovered_slot_index = -1
		_hide_tooltip()
	_update_row_input()
	queue_redraw()


func set_cue_drag_active(active: bool) -> void:
	set_hover_ui_suppressed(active)


func pulse_activation(activation: Dictionary) -> bool:
	var metadata: Dictionary = _dictionary_value(activation, "metadata")
	var slot_index: int = int(activation.get(
		"slot_index",
		activation.get(
			"tray_slot_index",
			metadata.get(
				"slot_index",
				metadata.get(
					"tray_slot_index",
					metadata.get("retrigger_source_slot_index", -1)
				)
			)
		)
	))
	var item_id: String = _get_item_id(activation)
	var owned_instance_id: int = int(activation.get(
		"owned_item_instance_id",
		metadata.get("owned_item_instance_id", 0)
	))
	if not _slot_matches_activation(slot_index, item_id, owned_instance_id):
		slot_index = _find_slot_index_for_activation(item_id, owned_instance_id)
		if slot_index < 0:
			return false

	var phase: String = str(activation.get("phase", activation.get("modifier_phase", "")))
	var engine_event_type: String = str(activation.get(
		"engine_event_kind",
		activation.get(
			"engine_event_type",
			activation.get(
				"event_type",
				metadata.get("engine_event_kind", metadata.get("engine_event_type", ""))
			)
		)
	))
	var is_state_growth: bool = (
		engine_event_type in [ENGINE_EVENT_STATE_GROWTH, "state_mutation", "persistent_growth"]
		or bool(activation.get("is_state_growth", metadata.get("is_state_growth", false)))
	)
	var is_retrigger: bool = bool(activation.get(
		"is_retrigger",
		metadata.get("is_retrigger", false)
	))
	var is_retrigger_marker: bool = bool(activation.get(
		"is_retrigger_marker",
		metadata.get("is_retrigger_marker", false)
	)) or engine_event_type in [
		"threshold_retrigger",
		ENGINE_EVENT_THRESHOLD_MARKER,
		"retrigger_marker",
	]
	var effect_text: String = str(activation.get("effect_text", activation.get("display_delta", "")))
	if is_retrigger_marker:
		effect_text = str(activation.get(
			"threshold_label",
			activation.get("label", metadata.get("threshold_label", ""))
		)).strip_edges()
		if effect_text.is_empty():
			var threshold_ordinal: int = maxi(int(activation.get(
				"tap_ordinal",
				activation.get(
					"retrigger_threshold_ordinal",
					metadata.get("retrigger_threshold_ordinal", 3)
				)
			)), 1)
			effect_text = "%s TAP - RETRIGGER" % _format_ordinal_word(
				threshold_ordinal
			).to_upper()
	elif is_retrigger:
		effect_text = "RETRIGGER" if effect_text.is_empty() else effect_text
	elif is_state_growth:
		effect_text = _format_state_growth(activation, metadata)
	elif effect_text.is_empty():
		effect_text = _format_activation_delta(phase, activation.get("value", 0))
	var pulse_duration: float = (
		LEGENDARY_PULSE_DURATION
		if is_retrigger_marker or phase == "xmult"
		else PULSE_DURATION
	)
	var strength: float = _get_phase_pulse_strength(phase)
	if is_state_growth:
		strength = maxf(strength, 0.88)
	if is_retrigger or is_retrigger_marker:
		strength = 1.0
	pulse_states[slot_index] = {
		"item_id": item_id,
		"owned_item_instance_id": owned_instance_id,
		"remaining": pulse_duration,
		"duration": pulse_duration,
		"strength": strength,
		"phase": phase,
		"engine_event_type": engine_event_type,
		"effect_text": effect_text,
		"is_state_growth": is_state_growth,
		"is_retrigger": is_retrigger,
		"is_retrigger_marker": is_retrigger_marker,
	}
	set_process(true)
	queue_redraw()
	return true


func pulse_slot_for_step(resolution_step: Dictionary) -> bool:
	var narrative_event: Dictionary = _dictionary_value(resolution_step, "narrative_event")
	var source: Dictionary = narrative_event if not narrative_event.is_empty() else resolution_step
	var metadata: Dictionary = _dictionary_value(source, "metadata")
	if metadata.is_empty():
		metadata = _dictionary_value(resolution_step, "metadata")
	var phase: String = str(metadata.get(
		"modifier_phase",
		source.get(
			"modifier_phase",
			source.get(
				"phase",
				resolution_step.get("modifier_phase", resolution_step.get("phase", ""))
			)
		)
	))
	var value: Variant = source.get("value", resolution_step.get("value", 0))
	match phase:
		"add_haul":
			value = int(source.get("haul_delta", resolution_step.get("haul_delta", value)))
		"add_mult":
			value = float(source.get("mult_delta", resolution_step.get("mult_delta", value)))
		"xmult":
			value = float(source.get("xmult_factor", resolution_step.get("xmult_factor", value)))
	var activation: Dictionary = {
		"slot_index": int(metadata.get(
			"slot_index",
			metadata.get(
				"tray_slot_index",
				metadata.get(
					"retrigger_source_slot_index",
					source.get("slot_index", source.get("tray_slot_index", -1))
				)
			)
		)),
		"eight_ball_item_id": str(metadata.get(
			"eight_ball_item_id",
			metadata.get(
				"source_item_id",
				source.get("eight_ball_item_id", source.get("source_id", ""))
			)
		)),
		"owned_item_instance_id": int(metadata.get(
			"owned_item_instance_id",
			source.get("owned_item_instance_id", 0)
		)),
		"phase": phase,
		"value": value,
		"engine_event_type": str(source.get(
			"engine_event_kind",
			source.get(
				"engine_event_type",
				source.get(
					"event_type",
					metadata.get("engine_event_kind", metadata.get("engine_event_type", ""))
				)
			)
		)),
		"effect_text": str(source.get("effect_text", resolution_step.get("effect_text", ""))),
		"value_before": source.get("value_before", metadata.get("value_before", 0.0)),
		"value_after": source.get("value_after", metadata.get("value_after", 0.0)),
		"is_retrigger": bool(metadata.get(
			"is_retrigger",
			source.get("is_retrigger", false)
		)),
		"is_retrigger_marker": bool(metadata.get(
			"is_retrigger_marker",
			source.get("is_retrigger_marker", false)
		)),
		"threshold_label": str(source.get(
			"threshold_label",
			metadata.get("threshold_label", "")
		)),
		"metadata": metadata.duplicate(true),
	}
	return pulse_activation(activation)


func pulse_slot_activation(slot_index: int, item_id: String, effect_text: String = "", phase: String = "") -> bool:
	return pulse_activation({
		"slot_index": slot_index,
		"eight_ball_item_id": item_id,
		"effect_text": effect_text,
		"phase": phase,
	})


func apply_activation_snapshot(snapshot: Dictionary) -> int:
	var activations_value: Variant = snapshot.get("modifier_activations", snapshot.get("activations", []))
	if not activations_value is Array:
		return 0
	var applied: int = 0
	for activation_value in activations_value:
		if activation_value is Dictionary and pulse_activation(activation_value as Dictionary):
			applied += 1
	return applied


func clear_activation_pulses() -> void:
	pulse_states.clear()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var active_pulse_count: int = 0
	for slot_index_value in pulse_states.keys():
		var slot_index: int = int(slot_index_value)
		var pulse_value: Variant = pulse_states.get(slot_index, {})
		if not pulse_value is Dictionary:
			pulse_states.erase(slot_index)
			continue
		var pulse: Dictionary = pulse_value
		var remaining: float = maxf(float(pulse.get("remaining", 0.0)) - delta, 0.0)
		if remaining <= 0.0:
			pulse_states.erase(slot_index)
			continue
		pulse["remaining"] = remaining
		pulse_states[slot_index] = pulse
		active_pulse_count += 1
	queue_redraw()
	if active_pulse_count <= 0:
		set_process(false)


func _draw() -> void:
	if not tray_enabled:
		return

	var panel_rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_style_box(_make_panel_style(), panel_rect)
	var occupied_count: int = _get_occupied_count()
	_draw_text("EIGHT BALLS", Vector2(PANEL_PADDING, 23.0), TITLE_COLOR, 17, HORIZONTAL_ALIGNMENT_LEFT, size.x - 100.0)
	_draw_text("%d / %d" % [occupied_count, SLOT_COUNT], Vector2(size.x - 80.0, 23.0), TITLE_COLOR, 15, HORIZONTAL_ALIGNMENT_RIGHT, 68.0)
	draw_line(
		Vector2(PANEL_PADDING, HEADER_HEIGHT - 2.0),
		Vector2(size.x - PANEL_PADDING, HEADER_HEIGHT - 2.0),
		Color(0.92, 0.72, 0.34, 0.22),
		1.0
	)

	for slot_index in range(SLOT_COUNT):
		_draw_slot(slot_index)


func _draw_slot(slot_index: int) -> void:
	var slot: Dictionary = slot_snapshots[slot_index]
	var slot_rect: Rect2 = _get_slot_rect(slot_index)
	var occupied: bool = bool(slot.get("occupied", false))
	var hovered: bool = slot_index == hovered_slot_index and not hover_ui_suppressed
	var pulse: Dictionary = _get_valid_pulse(slot_index, slot)
	var rarity_color: Color = _get_rarity_color(str(slot.get("rarity", "common")))
	var is_legendary: bool = str(slot.get("rarity", "common")).to_lower() == "legendary"
	var fill: Color = SLOT_FILL if occupied else EMPTY_FILL
	var border: Color = rarity_color if occupied else EMPTY_BORDER
	var border_alpha: float = 0.54 if occupied else 0.26
	if hovered:
		fill = fill.lightened(0.08)
		border_alpha = 0.92
	if occupied and is_legendary:
		var legendary_outer: Color = LEGENDARY_PURPLE
		legendary_outer.a = 0.34 if not hovered else 0.58
		draw_style_box(
			_make_slot_style(Color(0.10, 0.035, 0.13, 0.46), legendary_outer),
			slot_rect.grow(2.0)
		)

	if not pulse.is_empty():
		var duration: float = maxf(float(pulse.get("duration", PULSE_DURATION)), 0.001)
		var alpha: float = clampf(float(pulse.get("remaining", 0.0)) / duration, 0.0, 1.0)
		var strength: float = clampf(float(pulse.get("strength", 0.7)), 0.0, 1.0)
		var glow_color: Color = rarity_color
		glow_color.a = alpha * (0.22 + strength * 0.28)
		draw_style_box(_make_slot_style(glow_color, glow_color), slot_rect.grow(3.0 + strength * 3.0))
		fill = fill.lightened(alpha * 0.14)
		border_alpha = 1.0

	border.a = border_alpha
	draw_style_box(_make_slot_style(fill, border), slot_rect)
	if not occupied:
		_draw_empty_slot(slot_index, slot_rect)
		return

	var icon_center: Vector2 = Vector2(slot_rect.position.x + 27.0, slot_rect.get_center().y)
	_draw_eight_ball_icon(icon_center, pulse, str(slot.get("rarity", "common")))
	var text_left: float = slot_rect.position.x + 52.0
	var text_width: float = slot_rect.size.x - 62.0
	var compact: bool = slot_height < 54.0
	var name_size: int = 14 if compact else 16
	var detail_size: int = 12 if compact else 13
	var rarity_size: int = 10 if compact else 11
	var name_y: float = slot_rect.position.y + (17.0 if compact else 20.0)
	var effect_y: float = slot_rect.position.y + (34.0 if compact else 42.0)
	var rarity_width: float = minf(92.0 if is_legendary else 76.0, text_width * 0.42)
	var family_name: String = _format_trigger_name(str(slot.get("family_id", slot.get("trigger_id", ""))))
	var family_width: float = minf(94.0, text_width * 0.43)
	var right_detail: String = family_name.to_upper()
	var right_detail_color: Color = rarity_color
	var support_warning: String = str(slot.get("support_warning", "")).strip_edges()
	if not support_warning.is_empty():
		right_detail = "NO SUPPORT"
		right_detail_color = Color(1.0, 0.61, 0.31, 1.0)
	var pulse_text: String = str(pulse.get("effect_text", "")) if not pulse.is_empty() else ""
	if not pulse_text.is_empty():
		right_detail = pulse_text.to_upper()
		var duration: float = maxf(float(pulse.get("duration", PULSE_DURATION)), 0.001)
		right_detail_color.a = clampf(float(pulse.get("remaining", 0.0)) / duration, 0.0, 1.0)
	_draw_text(str(slot.get("display_name", "Eight Ball")), Vector2(text_left, name_y), NAME_COLOR, name_size, HORIZONTAL_ALIGNMENT_LEFT, text_width - rarity_width - 4.0)
	_draw_text(str(slot.get("rarity", "Common")).to_upper(), Vector2(text_left + text_width - rarity_width, name_y), rarity_color, rarity_size, HORIZONTAL_ALIGNMENT_RIGHT, rarity_width)
	_draw_text(str(slot.get("dynamic_short_effect", slot.get("short_effect", ""))), Vector2(text_left, effect_y), EFFECT_COLOR, detail_size, HORIZONTAL_ALIGNMENT_LEFT, text_width - family_width - 5.0)
	_draw_text(right_detail, Vector2(text_left + text_width - family_width, effect_y), right_detail_color, rarity_size, HORIZONTAL_ALIGNMENT_RIGHT, family_width)


func _draw_empty_slot(slot_index: int, slot_rect: Rect2) -> void:
	var center: Vector2 = Vector2(slot_rect.position.x + 27.0, slot_rect.get_center().y)
	draw_circle(center, 14.0, Color(0.05, 0.05, 0.06, 0.42))
	draw_arc(center, 14.0, 0.0, TAU, 32, Color(0.48, 0.46, 0.48, 0.30), 1.0)
	var font_size: int = 12 if slot_height < 54.0 else 14
	_draw_text("EMPTY SLOT %d" % (slot_index + 1), Vector2(slot_rect.position.x + 52.0, slot_rect.get_center().y + 5.0), EMPTY_COLOR, font_size, HORIZONTAL_ALIGNMENT_LEFT, slot_rect.size.x - 62.0)


func _draw_eight_ball_icon(center: Vector2, pulse: Dictionary, rarity: String) -> void:
	var is_legendary: bool = rarity.to_lower() == "legendary"
	if not pulse.is_empty():
		var duration: float = maxf(float(pulse.get("duration", PULSE_DURATION)), 0.001)
		var alpha: float = clampf(float(pulse.get("remaining", 0.0)) / duration, 0.0, 1.0)
		var strength: float = clampf(float(pulse.get("strength", 0.7)), 0.0, 1.0)
		draw_circle(center, ICON_RADIUS + 6.0 + strength * 3.0, Color(0.98, 0.78, 0.34, alpha * 0.18))
	if is_legendary:
		draw_circle(center, ICON_RADIUS + 4.0, Color(0.38, 0.11, 0.50, 0.34))
		draw_arc(center, ICON_RADIUS + 3.0, 0.0, TAU, 40, LEGENDARY_COLOR, 1.8)
	draw_circle(center, ICON_RADIUS, Color(0.008, 0.009, 0.012, 1.0))
	draw_arc(center, ICON_RADIUS, 0.0, TAU, 40, LEGENDARY_COLOR if is_legendary else Color(0.78, 0.68, 0.48, 0.66), 1.6 if is_legendary else 1.2)
	draw_circle(center, 8.0, Color(0.94, 0.92, 0.82, 1.0))
	draw_string(UI_FONT, center + Vector2(-4.0, 4.5), "8", HORIZONTAL_ALIGNMENT_CENTER, 8.0, 11, Color(0.02, 0.02, 0.025, 1.0))


func _build_row_hit_areas() -> void:
	for slot_index in range(SLOT_COUNT):
		var hit_area: Control = Control.new()
		hit_area.name = "TraySlotHover%d" % (slot_index + 1)
		hit_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hit_area.focus_mode = Control.FOCUS_NONE
		hit_area.mouse_entered.connect(_on_slot_mouse_entered.bind(slot_index))
		hit_area.mouse_exited.connect(_on_slot_mouse_exited.bind(slot_index))
		add_child(hit_area)
		row_hit_areas.append(hit_area)


func _build_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "EightBallTrayTooltip"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 8
	tooltip_panel.custom_minimum_size = TOOLTIP_SIZE
	tooltip_panel.size = TOOLTIP_SIZE
	tooltip_panel.add_theme_stylebox_override("panel", _make_tooltip_style())
	add_child(tooltip_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	tooltip_panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	tooltip_title_label = _make_tooltip_label(18, TITLE_COLOR)
	tooltip_meta_label = _make_tooltip_label(13, Color(0.78, 0.90, 0.84, 0.96))
	tooltip_body_label = _make_tooltip_label(14, Color(0.88, 0.84, 0.72, 0.96))
	tooltip_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tooltip_status_label = _make_tooltip_label(13, Color(0.68, 0.90, 0.86, 0.96))
	stack.add_child(tooltip_title_label)
	stack.add_child(tooltip_meta_label)
	stack.add_child(tooltip_body_label)
	stack.add_child(tooltip_status_label)


func _extract_slot_snapshots(snapshot: Dictionary) -> Array[Dictionary]:
	var slots_value: Variant = snapshot.get("slots", snapshot.get("tray_slots", snapshot.get("build_slots", [])))
	if not slots_value is Array or (slots_value as Array).is_empty():
		var nested_value: Variant = snapshot.get("build_snapshot", {})
		if nested_value is Dictionary:
			var nested: Dictionary = nested_value
			slots_value = nested.get("slots", nested.get("tray_slots", []))
	var raw_slots: Array = slots_value if slots_value is Array else []
	var activation_counts: Dictionary = _extract_activation_counts(snapshot)
	var result: Array[Dictionary] = []
	for slot_index in range(SLOT_COUNT):
		var raw_slot: Dictionary = {}
		if slot_index < raw_slots.size() and raw_slots[slot_index] is Dictionary:
			raw_slot = (raw_slots[slot_index] as Dictionary).duplicate(true)
		var item_value: Variant = raw_slot.get("item", raw_slot.get("definition", {}))
		var item: Dictionary = item_value as Dictionary if item_value is Dictionary else raw_slot
		var state: Dictionary = _dictionary_value(raw_slot, "state")
		if state.is_empty():
			state = _dictionary_value(item, "state")
		var item_id: String = _get_item_id(item)
		if item_id.is_empty():
			item_id = _get_item_id(raw_slot)
		var count: int = int(activation_counts.get(slot_index, activation_counts.get(str(slot_index), raw_slot.get("last_shot_trigger_count", item.get("last_shot_trigger_count", 0)))))
		var effect_kind: String = str(item.get("effect_kind", raw_slot.get("effect_kind", "")))
		var short_effect: String = str(item.get("short_effect", item.get("effect", raw_slot.get("short_effect", ""))))
		var support_warning: String = _get_support_warning(
			snapshot,
			raw_slot,
			slot_index,
			item_id
		)
		result.append({
			"slot_index": slot_index,
			"occupied": not item_id.is_empty(),
			"eight_ball_item_id": item_id,
			"owned_item_instance_id": int(raw_slot.get(
				"owned_item_instance_id",
				item.get("owned_item_instance_id", 0)
			)),
			"acquired_round": int(raw_slot.get("acquired_round", item.get("acquired_round", 0))),
			"display_name": str(item.get("display_name", raw_slot.get("display_name", "Eight Ball"))),
			"short_effect": short_effect,
			"dynamic_short_effect": _get_dynamic_short_effect(
				item,
				state,
				short_effect
			),
			"rarity": _format_rarity(str(item.get("rarity", raw_slot.get("rarity", "common")))),
			"family_id": str(item.get("family_id", raw_slot.get("family_id", ""))),
			"offer_family": str(item.get("offer_family", raw_slot.get("offer_family", ""))),
			"effect_kind": effect_kind,
			"modifier_phase": str(item.get("modifier_phase", item.get("phase", raw_slot.get("modifier_phase", "")))),
			"value": item.get("value", raw_slot.get("value", 0.0)),
			"threshold": int(item.get("threshold", raw_slot.get("threshold", 0))),
			"trigger_id": str(item.get("trigger_id", raw_slot.get("trigger_id", ""))),
			"tooltip": str(item.get("tooltip", item.get("description", raw_slot.get("tooltip", raw_slot.get("description", ""))))),
			"state": state.duplicate(true),
			"support_warning": support_warning,
			"last_shot_trigger_count": maxi(count, 0),
		})
	return result


func _extract_activation_counts(snapshot: Dictionary) -> Dictionary:
	var direct_value: Variant = snapshot.get("last_shot_activation_count_by_slot", snapshot.get("activation_count_by_slot", {}))
	if direct_value is Dictionary:
		return (direct_value as Dictionary).duplicate(true)
	var last_shot_value: Variant = snapshot.get("last_shot", {})
	if last_shot_value is Dictionary:
		var last_shot: Dictionary = last_shot_value
		var nested_value: Variant = last_shot.get("activation_count_by_slot", {})
		if nested_value is Dictionary:
			return (nested_value as Dictionary).duplicate(true)
	return {}


func _get_item_id(item: Dictionary) -> String:
	return str(item.get("eight_ball_item_id", item.get("build_item_id", item.get("item_id", item.get("id", "")))))


func _get_slot_rect(slot_index: int) -> Rect2:
	var y: float = HEADER_HEIGHT + PANEL_PADDING + float(slot_index) * (slot_height + SLOT_GAP)
	return Rect2(Vector2(PANEL_PADDING, y), Vector2(size.x - PANEL_PADDING * 2.0, slot_height))


func _get_occupied_count() -> int:
	var count: int = 0
	for slot in slot_snapshots:
		if bool(slot.get("occupied", false)):
			count += 1
	return count


func _slot_matches_item(slot_index: int, item_id: String) -> bool:
	if slot_index < 0 or slot_index >= slot_snapshots.size() or item_id.is_empty():
		return false
	var slot: Dictionary = slot_snapshots[slot_index]
	return bool(slot.get("occupied", false)) and str(slot.get("eight_ball_item_id", "")) == item_id


func _slot_matches_activation(
	slot_index: int,
	item_id: String,
	owned_instance_id: int
) -> bool:
	if not _slot_matches_item(slot_index, item_id):
		return false
	if owned_instance_id <= 0:
		return true
	return int(slot_snapshots[slot_index].get("owned_item_instance_id", 0)) == owned_instance_id


func _find_slot_index_by_item(item_id: String) -> int:
	if item_id.is_empty():
		return -1
	for slot_index in range(slot_snapshots.size()):
		if _slot_matches_item(slot_index, item_id):
			return slot_index
	return -1


func _find_slot_index_for_activation(item_id: String, owned_instance_id: int) -> int:
	if owned_instance_id > 0:
		for slot_index in range(slot_snapshots.size()):
			var slot: Dictionary = slot_snapshots[slot_index]
			if (
				bool(slot.get("occupied", false))
				and int(slot.get("owned_item_instance_id", 0)) == owned_instance_id
			):
				return slot_index
	return _find_slot_index_by_item(item_id)


func _get_valid_pulse(slot_index: int, slot: Dictionary) -> Dictionary:
	var pulse_value: Variant = pulse_states.get(slot_index, {})
	if not pulse_value is Dictionary:
		return {}
	var pulse: Dictionary = pulse_value
	if str(pulse.get("item_id", "")) != str(slot.get("eight_ball_item_id", "")):
		return {}
	var pulse_instance_id: int = int(pulse.get("owned_item_instance_id", 0))
	if (
		pulse_instance_id > 0
		and pulse_instance_id != int(slot.get("owned_item_instance_id", 0))
	):
		return {}
	return pulse


func _prune_stale_pulses() -> void:
	for slot_index_value in pulse_states.keys():
		var slot_index: int = int(slot_index_value)
		var pulse_value: Variant = pulse_states.get(slot_index, {})
		if not pulse_value is Dictionary or not _slot_matches_item(slot_index, str((pulse_value as Dictionary).get("item_id", ""))):
			pulse_states.erase(slot_index)
	if pulse_states.is_empty():
		set_process(false)


func _apply_responsive_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var available_height: float = maxf(viewport_size.y - VIEWPORT_MARGIN * 2.0, 1.0)
	var panel_width: float = clampf(viewport_size.x * 0.185, PANEL_MIN_WIDTH, PANEL_MAX_WIDTH)
	var fixed_height: float = HEADER_HEIGHT + PANEL_PADDING * 2.0 + SLOT_GAP * float(SLOT_COUNT - 1)
	slot_height = clampf((available_height - fixed_height) / float(SLOT_COUNT), SLOT_MIN_HEIGHT, SLOT_MAX_HEIGHT)
	var panel_height: float = fixed_height + slot_height * float(SLOT_COUNT)
	var top_offset: float = clampf(PANEL_TOP, VIEWPORT_MARGIN, maxf(viewport_size.y - panel_height - VIEWPORT_MARGIN, VIEWPORT_MARGIN))

	anchor_left = 0.0 if layout_on_left else 1.0
	anchor_right = anchor_left
	anchor_top = 0.0
	anchor_bottom = 0.0
	if layout_on_left:
		offset_left = RIGHT_MARGIN
		offset_right = RIGHT_MARGIN + panel_width
	else:
		offset_left = -RIGHT_MARGIN - panel_width
		offset_right = -RIGHT_MARGIN
	offset_top = top_offset
	offset_bottom = top_offset + panel_height
	custom_minimum_size = Vector2(panel_width, panel_height)
	size = Vector2(panel_width, panel_height)
	for slot_index in range(mini(row_hit_areas.size(), SLOT_COUNT)):
		var slot_rect: Rect2 = _get_slot_rect(slot_index)
		row_hit_areas[slot_index].position = slot_rect.position
		row_hit_areas[slot_index].size = slot_rect.size
	_position_tooltip()


func _update_row_input() -> void:
	for slot_index in range(mini(row_hit_areas.size(), SLOT_COUNT)):
		var occupied: bool = slot_index < slot_snapshots.size() and bool(slot_snapshots[slot_index].get("occupied", false))
		row_hit_areas[slot_index].mouse_filter = Control.MOUSE_FILTER_PASS if occupied and not hover_ui_suppressed else Control.MOUSE_FILTER_IGNORE


func _on_slot_mouse_entered(slot_index: int) -> void:
	if hover_ui_suppressed or slot_index < 0 or slot_index >= slot_snapshots.size():
		return
	if not bool(slot_snapshots[slot_index].get("occupied", false)):
		return
	hovered_slot_index = slot_index
	_refresh_tooltip()
	tooltip_panel.visible = true
	queue_redraw()


func _on_slot_mouse_exited(slot_index: int) -> void:
	if hovered_slot_index != slot_index:
		return
	hovered_slot_index = -1
	_hide_tooltip()
	queue_redraw()


func _refresh_tooltip() -> void:
	if tooltip_panel == null or hovered_slot_index < 0 or hovered_slot_index >= slot_snapshots.size():
		_hide_tooltip()
		return
	var slot: Dictionary = slot_snapshots[hovered_slot_index]
	if not bool(slot.get("occupied", false)):
		_hide_tooltip()
		return
	tooltip_title_label.text = str(slot.get("display_name", "Eight Ball")).to_upper()
	tooltip_meta_label.text = "%s  |  %s" % [
		str(slot.get("rarity", "Common")),
		_format_trigger_name(str(slot.get(
			"offer_family",
			slot.get("trigger_id", slot.get("family_id", ""))
		))),
	]
	tooltip_body_label.text = str(slot.get("tooltip", slot.get("short_effect", "")))
	var count: int = maxi(int(slot.get("last_shot_trigger_count", 0)), 0)
	var status_lines: Array[String] = [
		"Tray slot %d" % (hovered_slot_index + 1),
		_format_trigger_count(count),
	]
	var effect_kind: String = str(slot.get("effect_kind", ""))
	var state: Dictionary = _dictionary_value(slot, "state")
	if effect_kind == EFFECT_KIND_PERSISTENT_SCALER:
		var current_xmult: float = _get_current_scaler_value(slot, state)
		status_lines.append("Current value: x%s Mult" % _format_numeric_value(current_xmult))
		var lifetime_growth: int = maxi(int(state.get(
			"lifetime_growth_triggers",
			state.get("lifetime_trigger_count", 0)
		)), 0)
		status_lines.append("Lifetime Tap growth: %d" % lifetime_growth)
	var support_warning: String = str(slot.get("support_warning", "")).strip_edges()
	if not support_warning.is_empty():
		status_lines.append("WARNING: %s" % support_warning)
	tooltip_status_label.text = "\n".join(status_lines)
	_position_tooltip()


func _position_tooltip() -> void:
	if tooltip_panel == null or hovered_slot_index < 0:
		return
	var slot_rect: Rect2 = _get_slot_rect(hovered_slot_index)
	var tooltip_x: float = size.x + 10.0 if layout_on_left else -TOOLTIP_SIZE.x - 10.0
	var desired_global: Vector2 = global_position + Vector2(tooltip_x, slot_rect.position.y)
	var viewport_size: Vector2 = get_viewport_rect().size
	desired_global.x = clampf(desired_global.x, VIEWPORT_MARGIN, maxf(viewport_size.x - TOOLTIP_SIZE.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN))
	desired_global.y = clampf(desired_global.y, VIEWPORT_MARGIN, maxf(viewport_size.y - TOOLTIP_SIZE.y - VIEWPORT_MARGIN, VIEWPORT_MARGIN))
	tooltip_panel.position = desired_global - global_position


func _hide_tooltip() -> void:
	if tooltip_panel != null:
		tooltip_panel.visible = false


func _format_trigger_count(count: int) -> String:
	match count:
		0:
			return "Did not trigger last shot."
		1:
			return "Triggered once last shot."
		2:
			return "Triggered twice last shot."
		_:
			return "Triggered %d times last shot." % count


func _format_trigger_name(trigger_id: String) -> String:
	match trigger_id:
		"single_bank", "single_bank_milestone":
			return "Single Bank"
		"double_bank", "double_bank_milestone":
			return "Double Bank"
		"triple_bank", "triple_bank_milestone":
			return "Triple Bank"
		"combination", "combination_pot":
			return "Combination"
		"direct_pot":
			return "Direct Pot"
		"multi_pot", "multi_pot_shot":
			return "Multi-Pot"
		"same_pocket", "same_pocket_streak":
			return "Same Pocket"
		"double_tap", "cue_recontact_milestone":
			return "Double Tap"
		"ball_tap", "object_ball_tap_milestone":
			return "Ball Tap"
		"tap_growth":
			return "Tap Growth"
		"tap_hybrid":
			return "Tap Hybrid"
		"tap_escalation":
			return "Tap Escalation"
		"tap_retrigger":
			return "Tap Retrigger"
		"tap_oddity":
			return "Tap Oddity"
		_:
			return trigger_id.replace("_", " ").capitalize() if not trigger_id.is_empty() else "Scoring Engine"


func _format_rarity(rarity: String) -> String:
	var normalized: String = rarity.strip_edges().to_lower()
	return normalized.capitalize() if not normalized.is_empty() else "Common"


func _format_activation_delta(phase: String, value: Variant) -> String:
	var formatted_value: String = _format_numeric_value(value)
	match phase:
		"add_haul":
			return "+%s Haul" % formatted_value
		"add_mult":
			return "+%s Mult" % formatted_value
		"xmult":
			return "x%s Mult" % formatted_value
		_:
			return formatted_value


func _format_numeric_value(value: Variant) -> String:
	var number: float = float(value)
	if is_equal_approx(number, round(number)):
		return str(int(round(number)))
	return ("%.2f" % number).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _get_phase_pulse_strength(phase: String) -> float:
	match phase:
		"xmult":
			return 1.0
		"state_growth", "engine_marker":
			return 0.9
		"add_mult":
			return 0.82
		_:
			return 0.66


func _get_dynamic_short_effect(
	item: Dictionary,
	state: Dictionary,
	fallback: String
) -> String:
	var authored_dynamic: String = str(item.get("dynamic_short_effect", "")).strip_edges()
	if not authored_dynamic.is_empty():
		return authored_dynamic
	var effect_kind: String = str(item.get("effect_kind", ""))
	var value: float = float(item.get("value", item.get("multiplier", 1.0)))
	match effect_kind:
		EFFECT_KIND_PERSISTENT_SCALER:
			return "Tap Shot: x%s Mult" % _format_numeric_value(
				_get_current_scaler_value(item, state)
			)
		EFFECT_KIND_CROSS_FAMILY_CONDITIONAL:
			return "Double Tap + Ball Tap: x%s" % _format_numeric_value(value)
		EFFECT_KIND_SHOT_ORDINAL_MULTIPLIER:
			return "Each Tap after first: x%s" % _format_numeric_value(value)
		EFFECT_KIND_THRESHOLD_FAMILY_RETRIGGER:
			var threshold: int = maxi(int(item.get("threshold", 3)), 1)
			return "Every %s Tap retriggers" % _format_ordinal_word(threshold)
		_:
			return fallback


func _get_current_scaler_value(item: Dictionary, state: Dictionary) -> float:
	return maxf(float(state.get(
		"current_xmult",
		state.get(
			"current_value",
			item.get("current_xmult", item.get("starting_value", 1.0))
		)
	)), 0.0)


func _get_support_warning(
	snapshot: Dictionary,
	raw_slot: Dictionary,
	slot_index: int,
	item_id: String
) -> String:
	for key in ["support_warning", "support_warning_text", "warning_text"]:
		var direct: String = str(raw_slot.get(key, "")).strip_edges()
		if not direct.is_empty():
			return direct
	var containers: Array[Dictionary] = [snapshot]
	var nested_value: Variant = snapshot.get("build_snapshot", null)
	if nested_value is Dictionary:
		containers.append(nested_value as Dictionary)
	for container in containers:
		for key in ["support_warnings_by_slot", "support_warnings", "warnings_by_slot"]:
			var warning: String = _warning_from_collection(
				container.get(key, null),
				slot_index,
				item_id
			)
			if not warning.is_empty():
				return warning
	return _get_definition_support_warning(snapshot, raw_slot, item_id)


func _get_definition_support_warning(
	snapshot: Dictionary,
	raw_slot: Dictionary,
	item_id: String
) -> String:
	var definition_value: Variant = raw_slot.get(
		"definition",
		raw_slot.get("item", raw_slot)
	)
	if not definition_value is Dictionary:
		return ""
	var definition: Dictionary = definition_value as Dictionary
	if str(definition.get("effect_kind", "")) != EFFECT_KIND_THRESHOLD_FAMILY_RETRIGGER:
		return ""
	var eligibility: Dictionary = _dictionary_value(definition, "eligibility")
	var required_item_ids_value: Variant = eligibility.get(
		"requires_owned_any_item_ids",
		[]
	)
	var required_family_ids_value: Variant = eligibility.get(
		"requires_owned_any_family_ids",
		[]
	)
	var required_item_ids: Array = (
		required_item_ids_value as Array
		if required_item_ids_value is Array
		else []
	)
	var required_family_ids: Array = (
		required_family_ids_value as Array
		if required_family_ids_value is Array
		else []
	)
	if required_item_ids.is_empty() and required_family_ids.is_empty():
		return ""
	for slot_value in _get_raw_build_slots(snapshot):
		if not slot_value is Dictionary:
			continue
		var candidate_slot: Dictionary = slot_value as Dictionary
		var candidate_value: Variant = candidate_slot.get(
			"definition",
			candidate_slot.get("item", candidate_slot)
		)
		if not candidate_value is Dictionary:
			continue
		var candidate: Dictionary = candidate_value as Dictionary
		var candidate_id: String = _get_item_id(candidate)
		if candidate_id.is_empty() or candidate_id == item_id:
			continue
		if candidate_id in required_item_ids:
			return ""
		var candidate_family: String = str(candidate.get(
			"family_id",
			candidate_slot.get("family_id", "")
		))
		if candidate_family in required_family_ids:
			return ""
	return str(eligibility.get(
		"retained_without_support_warning",
		eligibility.get("unmet_reason", "")
	)).strip_edges()


func _get_raw_build_slots(snapshot: Dictionary) -> Array:
	var slots_value: Variant = snapshot.get(
		"slots",
		snapshot.get("tray_slots", snapshot.get("build_slots", []))
	)
	if slots_value is Array and not (slots_value as Array).is_empty():
		return slots_value as Array
	var nested_value: Variant = snapshot.get("build_snapshot", null)
	if nested_value is Dictionary:
		var nested: Dictionary = nested_value as Dictionary
		var nested_slots: Variant = nested.get(
			"slots",
			nested.get("tray_slots", nested.get("build_slots", []))
		)
		if nested_slots is Array:
			return nested_slots as Array
	return []


func _warning_from_collection(
	collection: Variant,
	slot_index: int,
	item_id: String
) -> String:
	var value: Variant = null
	if collection is Dictionary:
		var warning_map: Dictionary = collection
		value = warning_map.get(
			slot_index,
			warning_map.get(str(slot_index), warning_map.get(item_id, null))
		)
	elif collection is Array and slot_index >= 0 and slot_index < (collection as Array).size():
		value = (collection as Array)[slot_index]
	if value is Dictionary:
		var warning: Dictionary = value
		return str(warning.get("message", warning.get("warning", warning.get("text", "")))).strip_edges()
	return str(value).strip_edges() if value != null else ""


func _format_state_growth(activation: Dictionary, metadata: Dictionary) -> String:
	var before: float = float(activation.get(
		"value_before",
		metadata.get("value_before", metadata.get("state_value_before", 0.0))
	))
	var after: float = float(activation.get(
		"value_after",
		metadata.get("value_after", metadata.get("state_value_after", before))
	))
	return "x%s -> x%s" % [
		_format_numeric_value(before),
		_format_numeric_value(after),
	]


func _format_ordinal_word(value: int) -> String:
	match value:
		1:
			return "first"
		2:
			return "second"
		3:
			return "third"
		_:
			return "%dth" % value


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"legendary":
			return LEGENDARY_COLOR
		"rare":
			return Color(0.48, 0.94, 0.88, 1.0)
		"uncommon":
			return Color(0.93, 0.73, 0.34, 1.0)
		_:
			return Color(0.82, 0.80, 0.70, 1.0)


func _draw_text(text: String, baseline: Vector2, color: Color, font_size: int, alignment: HorizontalAlignment, width: float) -> void:
	draw_string(UI_FONT, baseline + Vector2(1.2, 1.2), text, alignment, width, font_size, SHADOW_COLOR)
	draw_string(UI_FONT, baseline, text, alignment, width, font_size, color)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = PANEL_BORDER
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_slot_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


func _make_tooltip_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.026, 0.018, 0.94)
	style.border_color = Color(0.96, 0.78, 0.34, 0.64)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_tooltip_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.015, 0.012, 0.92))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()
	queue_redraw()
