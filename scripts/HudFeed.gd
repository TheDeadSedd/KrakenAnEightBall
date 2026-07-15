extends Control
class_name HudFeed

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const DEFAULT_CATEGORY := "status"

@export var visible_message_count := 8
@export var history_limit := 80
@export var message_font_size := 15
@export var message_line_height := 21.0
@export var message_text_y_offset := 1.0
@export var message_text_extra_height := 0.0
@export var continuation_indent_spaces := 4
@export var oldest_message_alpha := 0.32
@export var newest_message_alpha := 1.0

var messages: Array[Dictionary] = []
var message_rows: Array[Control] = []
var is_hovered := false
var hover_ui_suppressed := false
var review_scroll_offset := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not resized.is_connected(_refresh_labels):
		resized.connect(_refresh_labels)
	_ensure_labels()
	_refresh_labels()


func add_message(text: String, category: String = DEFAULT_CATEGORY, amount: int = 0, tier: String = "") -> void:
	var clean_text: String = text.strip_edges()
	if clean_text.is_empty():
		return

	messages.append({
		"text": clean_text,
		"category": category,
		"amount": amount,
		"tier": tier,
		"timestamp_msec": Time.get_ticks_msec(),
	})
	var safe_history_limit: int = maxi(history_limit, 1)
	while messages.size() > safe_history_limit:
		messages.pop_front()

	if not is_hovered:
		review_scroll_offset = 0
	review_scroll_offset = clampi(review_scroll_offset, 0, _get_max_review_scroll_offset())
	_refresh_labels()


func get_rewind_state() -> Dictionary:
	return {
		"messages": messages.duplicate(true),
		"review_scroll_offset": review_scroll_offset,
	}


func restore_rewind_state(state: Dictionary) -> void:
	messages.clear()
	var messages_value: Variant = state.get("messages", [])
	if messages_value is Array:
		for message_value in messages_value:
			if message_value is Dictionary:
				messages.append((message_value as Dictionary).duplicate(true))
	review_scroll_offset = clampi(int(state.get("review_scroll_offset", 0)), 0, _get_max_review_scroll_offset())
	is_hovered = false
	_refresh_labels()


func set_hover_ui_suppressed(suppressed: bool) -> void:
	if hover_ui_suppressed == suppressed:
		return

	hover_ui_suppressed = suppressed
	mouse_filter = Control.MOUSE_FILTER_IGNORE if suppressed else Control.MOUSE_FILTER_PASS
	if suppressed:
		is_hovered = false
		_set_review_scroll_offset(0)


func _gui_input(event: InputEvent) -> void:
	if hover_ui_suppressed:
		return
	if not is_hovered:
		return
	if not (event is InputEventMouseButton):
		return

	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_button.pressed:
		return

	if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_review_scroll_offset(review_scroll_offset + 1)
		accept_event()
	elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_review_scroll_offset(review_scroll_offset - 1)
		accept_event()


func _on_mouse_entered() -> void:
	if hover_ui_suppressed:
		is_hovered = false
		_refresh_labels()
		return

	is_hovered = true
	_refresh_labels()


func _on_mouse_exited() -> void:
	is_hovered = false
	_set_review_scroll_offset(0)


func _set_review_scroll_offset(offset: int) -> void:
	review_scroll_offset = clampi(offset, 0, _get_max_review_scroll_offset())
	_refresh_labels()


func _get_max_review_scroll_offset() -> int:
	return maxi(messages.size() - 1, 0)


func _get_visible_line_count() -> int:
	return clampi(visible_message_count, 1, 12)


func _ensure_labels() -> void:
	var desired_count: int = _get_visible_line_count()
	while message_rows.size() < desired_count:
		message_rows.append(_make_message_row())
	while message_rows.size() > desired_count:
		var removed_row: Control = message_rows.pop_back() as Control
		if is_instance_valid(removed_row):
			removed_row.queue_free()


func _make_message_row() -> Control:
	var row: Control = Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.clip_contents = false

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", message_font_size)
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.01, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.01, 0.92))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("outline_size", 3)
	row.add_child(label)
	add_child(row)
	return row


func _refresh_labels() -> void:
	_ensure_labels()
	var end_index: int = clampi(messages.size() - review_scroll_offset, 0, messages.size())
	var visible_entries: Array[Dictionary] = _get_visible_entries(end_index)
	var visible_count: int = visible_entries.size()
	var total_height: float = _sum_visible_entry_heights(visible_entries)
	var y_position: float = size.y - total_height
	for row_index in range(message_rows.size()):
		var row: Control = message_rows[row_index]
		var label: Label = row.get_child(0) as Label
		if row_index >= visible_count:
			row.visible = false
			continue

		var entry_data: Dictionary = visible_entries[row_index]
		var message_data: Dictionary = entry_data["message"]
		var row_height: float = float(entry_data["height"])
		row.visible = true
		row.size = Vector2(size.x, row_height)
		row.position = Vector2(0.0, y_position)
		row.modulate = Color(1.0, 1.0, 1.0, _get_label_alpha(row_index, visible_count))
		label.visible = true
		label.text = str(entry_data["text"])
		label.position = Vector2(0.0, message_text_y_offset)
		label.size = Vector2(
			size.x,
			maxf(row_height - message_text_y_offset + message_text_extra_height, 1.0)
		)
		label.add_theme_color_override(
			"font_color",
			_get_message_font_color(str(message_data.get("category", DEFAULT_CATEGORY)), str(message_data.get("tier", "")))
		)
		y_position += row_height


func _get_visible_entries(end_index: int) -> Array[Dictionary]:
	var visible_entries: Array[Dictionary] = []
	var total_height := 0.0
	var message_index: int = end_index - 1
	while message_index >= 0 and visible_entries.size() < message_rows.size():
		var message_data: Dictionary = messages[message_index]
		var formatted_text: String = _make_wrapped_message_text(str(message_data.get("text", "")))
		var row_height: float = _get_wrapped_message_height(formatted_text)
		if not visible_entries.is_empty() and total_height + row_height > size.y:
			break

		visible_entries.push_front({
			"message": message_data,
			"text": formatted_text,
			"height": row_height,
		})
		total_height += row_height
		message_index -= 1

	return visible_entries


func _sum_visible_entry_heights(visible_entries: Array[Dictionary]) -> float:
	var total_height := 0.0
	for entry_data in visible_entries:
		total_height += float(entry_data["height"])
	return total_height


func _make_wrapped_message_text(message_text: String) -> String:
	var clean_text: String = message_text.replace("\n", " ").strip_edges()
	if clean_text.is_empty():
		return clean_text

	var max_width: float = maxf(size.x - 2.0, 1.0)
	var words: PackedStringArray = clean_text.split(" ", false)
	var lines: Array[String] = []
	var current_line := ""
	var is_first_line := true
	for word in words:
		var candidate: String = word if current_line.is_empty() else "%s %s" % [current_line, word]
		if _get_wrapped_line_width(candidate, is_first_line) <= max_width or current_line.is_empty():
			current_line = candidate
			continue

		lines.append(_format_wrapped_line(current_line, is_first_line))
		current_line = word
		is_first_line = false

	if not current_line.is_empty():
		lines.append(_format_wrapped_line(current_line, is_first_line))

	return "\n".join(lines)


func _get_wrapped_line_width(line_text: String, is_first_line: bool) -> float:
	return UI_FONT.get_string_size(
		_format_wrapped_line(line_text, is_first_line),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		message_font_size
	).x


func _format_wrapped_line(line_text: String, is_first_line: bool) -> String:
	if is_first_line:
		return line_text
	return "%s%s" % [_get_continuation_indent(), line_text]


func _get_continuation_indent() -> String:
	var indent := ""
	for _index in range(maxi(continuation_indent_spaces, 0)):
		indent += " "
	return indent


func _get_wrapped_message_height(formatted_text: String) -> float:
	var line_count: int = formatted_text.count("\n") + 1
	return maxf(message_line_height, float(line_count) * message_line_height)


func _get_label_alpha(label_index: int, visible_count: int) -> float:
	if is_hovered:
		return 1.0
	if visible_count <= 1:
		return newest_message_alpha

	var age_ratio: float = float(label_index) / float(visible_count - 1)
	return lerpf(oldest_message_alpha, newest_message_alpha, age_ratio)


func _get_message_font_color(category: String, tier: String) -> Color:
	if tier == "legendary":
		return Color(1.0, 0.9, 0.34, 1.0)
	if tier == "heroic":
		return Color(0.92, 0.72, 1.0, 1.0)
	if tier == "skilled":
		return Color(0.70, 0.92, 1.0, 1.0)
	if category == "score":
		return Color(1.0, 0.88, 0.48, 1.0)
	if category == "shop":
		return Color(0.88, 0.86, 0.76, 1.0)
	if category == "callout":
		return Color(1.0, 0.84, 0.48, 1.0)
	return Color(0.88, 0.86, 0.76, 1.0)
