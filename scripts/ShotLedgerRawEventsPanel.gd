extends Control
class_name ShotLedgerRawEventsPanel

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const PANEL_SIZE := Vector2(860.0, 680.0)
const VIEWPORT_MARGIN := 24.0
const MAX_DISPLAY_EVENTS := 512

var ledger_system: ShotLedgerSystem
var shot_lab_system: ShotLabSystem
var event_filter: OptionButton
var ball_filter: SpinBox
var event_list: ItemList
var summary_label: Label
var filtered_events: Array = []


func setup(ledger_ref: ShotLedgerSystem, shot_lab_ref: ShotLabSystem) -> void:
	ledger_system = ledger_ref
	shot_lab_system = shot_lab_ref
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	z_index = 136
	_build_ui()
	if not ledger_system.shot_ledger_completed.is_connected(_on_ledger_completed):
		ledger_system.shot_ledger_completed.connect(_on_ledger_completed)
	visible = false


func open_panel() -> void:
	visible = true
	var viewport_size: Vector2 = get_viewport_rect().size
	var desired_position: Vector2 = (viewport_size - PANEL_SIZE) * 0.5
	desired_position.x = clampf(desired_position.x, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.x - PANEL_SIZE.x - VIEWPORT_MARGIN))
	desired_position.y = clampf(desired_position.y, VIEWPORT_MARGIN, maxf(VIEWPORT_MARGIN, viewport_size.y - PANEL_SIZE.y - VIEWPORT_MARGIN))
	position = desired_position
	_refresh()


func close_panel() -> void:
	visible = false


func copy_selected_event() -> bool:
	var selected: PackedInt32Array = event_list.get_selected_items()
	if selected.is_empty() or selected[0] < 0 or selected[0] >= filtered_events.size():
		return false
	DisplayServer.clipboard_set(JSON.stringify(_to_json_safe(filtered_events[selected[0]]), "  "))
	return true


func copy_all_events() -> bool:
	if ledger_system == null:
		return false
	DisplayServer.clipboard_set(ledger_system.get_last_raw_events_json(_get_event_filter(), _get_ball_filter()))
	return true


func _build_ui() -> void:
	var shell := PanelContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.024, 0.028, 0.98)
	style.border_color = Color(0.63, 0.49, 0.20, 0.95)
	style.set_border_width_all(2)
	shell.add_theme_stylebox_override("panel", style)
	add_child(shell)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	shell.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := _make_label("LAST SHOT RAW EVENTS", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _make_button("Close")
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	stack.add_child(filters)
	event_filter = OptionButton.new()
	for entry in ["All events", "ball_contact", "rail_contact", "pocket"]:
		event_filter.add_item(entry)
	event_filter.item_selected.connect(_on_filter_changed)
	filters.add_child(event_filter)
	filters.add_child(_make_label("Ball ID (0 = all)", 14))
	ball_filter = SpinBox.new()
	ball_filter.min_value = 0
	ball_filter.max_value = 99999
	ball_filter.step = 1
	ball_filter.value_changed.connect(_on_ball_filter_changed)
	filters.add_child(ball_filter)
	var copy_selected := _make_button("Copy Selected")
	copy_selected.pressed.connect(copy_selected_event)
	filters.add_child(copy_selected)
	var copy_all := _make_button("Copy All")
	copy_all.pressed.connect(copy_all_events)
	filters.add_child(copy_all)

	summary_label = _make_label("No completed ledger.", 13)
	stack.add_child(summary_label)
	event_list = ItemList.new()
	event_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_list.add_theme_font_override("font", UI_FONT)
	event_list.add_theme_font_size_override("font_size", 13)
	stack.add_child(event_list)


func _refresh() -> void:
	if not visible or ledger_system == null:
		return
	var matching_events: Array = ledger_system.get_last_raw_events(_get_event_filter(), _get_ball_filter())
	filtered_events = matching_events.slice(0, mini(matching_events.size(), MAX_DISPLAY_EVENTS))
	event_list.clear()
	var role_names: Dictionary = shot_lab_system.get_role_names_by_ball_id() if shot_lab_system != null else {}
	for event_value in filtered_events:
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		event_list.add_item(_format_event_row(event, role_names))
	var ledger: Dictionary = ledger_system.get_last_completed_ledger()
	summary_label.text = "Shot %d | Attempt %d | showing %d / %d matching events" % [
		int(ledger.get("shot_id", -1)), int(ledger.get("attempt_id", -1)), filtered_events.size(), matching_events.size()
	]


func _format_event_row(event: Dictionary, role_names: Dictionary) -> String:
	var source_id: int = int(event.get("source_ball_id", event.get("ball_a_id", event.get("ball_id", -1))))
	var target_id: int = int(event.get("target_ball_id", event.get("ball_b_id", -1)))
	var source: String = _format_ball(source_id, role_names)
	var target: String = _format_ball(target_id, role_names)
	if str(event.get("event_type", "")) == "rail_contact":
		target = str(event.get("rail_id", "rail"))
	elif str(event.get("event_type", "")) == "pocket":
		target = str(event.get("pocket_name", "pocket"))
	var detail: String = ""
	if event.has("relative_normal_speed"):
		detail = "speed %.1f" % float(event.get("relative_normal_speed", 0.0))
	elif event.has("normal_speed"):
		detail = "speed %.1f" % float(event.get("normal_speed", 0.0))
	return "%3d | %6.3f | %-13s | %-14s | %-14s | %s" % [
		int(event.get("event_index", -1)),
		float(event.get("shot_elapsed_sec", 0.0)),
		str(event.get("event_type", "")),
		source,
		target,
		detail,
	]


func _format_ball(ball_id: int, role_names: Dictionary) -> String:
	if ball_id < 0:
		return "-"
	var role: String = str(role_names.get(str(ball_id), ""))
	return "%s#%d" % [role, ball_id] if not role.is_empty() else "Ball#%d" % ball_id


func _get_event_filter() -> String:
	if event_filter == null or event_filter.selected <= 0:
		return ""
	return event_filter.get_item_text(event_filter.selected)


func _get_ball_filter() -> int:
	return int(ball_filter.value) if ball_filter != null else -1


func _on_filter_changed(_index: int) -> void:
	_refresh()


func _on_ball_filter_changed(_value: float) -> void:
	_refresh()


func _on_ledger_completed(_ledger: Dictionary) -> void:
	_refresh()


func _make_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("d8cfb8"))
	return label


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 14)
	return button


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
