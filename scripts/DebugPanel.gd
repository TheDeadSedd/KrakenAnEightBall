extends PanelContainer
class_name DebugPanel

# Reusable debug panel shell. It consumes direct panel clicks so they do not
# leak into cue input, while leaving empty HUD space transparent to gameplay.
const ADAPTIVE_COMPACT_LINE_SPACING := -1
const ADAPTIVE_COMPACT_SECTION_SPACING := 1
const ADAPTIVE_MAX_LAYOUT_RETRIES := 4
const ADAPTIVE_MAX_VERIFY_PASSES := 12
const ADAPTIVE_FIT_EPSILON := 1.0

@export var draggable := true
@export var drag_header_height := 34.0
@export var resizable := true
@export var resize_hotspot_size := 18.0
@export var minimum_resize_size := Vector2(240.0, 130.0)
@export var resize_viewport_margin := 16.0
@export_range(7, 16, 1) var adaptive_font_min_size := 7
@export_range(8, 18, 1) var adaptive_heading_font_min_size := 8

var is_dragging_panel := false
var is_resizing_panel := false
var clicked_inside_panel := false
var drag_offset := Vector2.ZERO
var resize_start_mouse_position := Vector2.ZERO
var resize_start_size := Vector2.ZERO
var adaptive_label_entries: Dictionary = {}
var adaptive_fit_queued := false
var adaptive_verify_queued := false
var adaptive_layout_retry_count := 0

static var resize_cursor_owner_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = minimum_resize_size
	if not resized.is_connected(_on_panel_resized):
		resized.connect(_on_panel_resized)
	if not visibility_changed.is_connected(_on_panel_visibility_changed):
		visibility_changed.connect(_on_panel_visibility_changed)
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)
	set_process_input(true)


func _process(_delta: float) -> void:
	if (is_dragging_panel or is_resizing_panel or clicked_inside_panel) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if is_resizing_panel:
			_end_resize()
		is_dragging_panel = false
		clicked_inside_panel = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_position_in_resize_hotspot(event.position):
			_begin_resize(get_global_mouse_position())
			accept_event()
			return
		if not event.pressed and is_resizing_panel:
			_end_resize()
			accept_event()
			return
		if _handle_mouse_button(event.pressed, event.position):
			accept_event()
	elif event is InputEventMouseMotion:
		_update_resize_cursor(get_global_mouse_position())
		if is_resizing_panel:
			_resize_from_global_mouse(get_global_mouse_position())
			accept_event()
			return
		if _handle_mouse_motion(get_global_mouse_position()):
			accept_event()


func _input(event: InputEvent) -> void:
	if _is_dev_options_modal_open():
		if is_resizing_panel:
			_end_resize()
		is_dragging_panel = false
		clicked_inside_panel = false
		_release_resize_cursor_if_owned()
		return
	if not is_visible_in_tree():
		_release_resize_cursor_if_owned()
		return

	# Pause-menu shade can sit above panels in the normal GUI path; direct
	# hit checks keep visible panels draggable without exposing empty HUD space.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_global_position_in_resize_hotspot(event.position):
			_begin_resize(event.position)
			get_viewport().set_input_as_handled()
			return
		if not event.pressed and is_resizing_panel:
			_end_resize()
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not get_global_rect().has_point(event.position):
			return
		var local_position: Vector2 = _get_panel_local_position(event.position)
		var should_handle_directly: bool = (
			is_dragging_panel
			or clicked_inside_panel
			or (event.pressed and draggable and _is_position_in_header(local_position))
		)
		if should_handle_directly and _handle_mouse_button(event.pressed, local_position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_update_resize_cursor(event.position)
		if is_resizing_panel:
			_resize_from_global_mouse(event.position)
			get_viewport().set_input_as_handled()
			return
		if _handle_mouse_motion(event.position):
			get_viewport().set_input_as_handled()


func _is_dev_options_modal_open() -> bool:
	var pause_menu_node: Node = get_parent().get_node_or_null("PauseMenu") if get_parent() != null else null
	return (
		pause_menu_node != null
		and pause_menu_node.has_method("is_dev_options_open")
		and bool(pause_menu_node.call("is_dev_options_open"))
	)


func _handle_mouse_button(pressed: bool, local_position: Vector2) -> bool:
	if is_resizing_panel:
		return true
	if pressed:
		move_to_front()
		clicked_inside_panel = true
		if draggable and _is_position_in_header(local_position):
			is_dragging_panel = true
			drag_offset = local_position
		return true

	if is_dragging_panel or clicked_inside_panel:
		is_dragging_panel = false
		clicked_inside_panel = false
		return true

	return false


func _handle_mouse_motion(global_mouse_position: Vector2) -> bool:
	if is_resizing_panel:
		return false
	if is_dragging_panel:
		position = _get_parent_local_position(global_mouse_position) - drag_offset
		return true
	elif clicked_inside_panel:
		return true

	return false


func _get_panel_local_position(global_position: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_position


func _get_parent_local_position(global_position: Vector2) -> Vector2:
	var parent_canvas_item := get_parent() as CanvasItem
	if parent_canvas_item == null:
		return global_position
	return parent_canvas_item.get_global_transform().affine_inverse() * global_position


func _is_position_in_header(local_position: Vector2) -> bool:
	return local_position.y >= 0.0 and local_position.y <= drag_header_height


func set_minimum_resize_size(value: Vector2) -> void:
	minimum_resize_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
	custom_minimum_size = minimum_resize_size
	_clamp_to_viewport()


func set_session_size(value: Vector2) -> void:
	var safe_size := Vector2(maxf(value.x, minimum_resize_size.x), maxf(value.y, minimum_resize_size.y))
	if is_inside_tree():
		_clamp_resize_origin_to_viewport()
	size = _clamp_size_to_viewport(safe_size)
	_queue_adaptive_fit()


func configure_adaptive_label(label: Label, use_scroll_fallback: bool = true, minimum_font_size: int = -1) -> void:
	if label == null or not is_instance_valid(label):
		return
	var label_id: int = label.get_instance_id()
	if adaptive_label_entries.has(label_id):
		return
	var initial_text: String = label.text
	var structure: Dictionary = _ensure_adaptive_content_structure(label, use_scroll_fallback)
	if structure.is_empty():
		return
	var heading_label: Label = structure.get("heading_label") as Label
	var content_stack: VBoxContainer = structure.get("content_stack") as VBoxContainer
	if heading_label == null or content_stack == null:
		return
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.custom_minimum_size = Vector2.ZERO
	var max_body_font_size: int = maxi(label.get_theme_font_size("font_size"), 1)
	var max_heading_font_size: int = maxi(heading_label.get_theme_font_size("font_size"), 1)
	var min_body_font_size: int = adaptive_font_min_size if minimum_font_size < 0 else minimum_font_size
	min_body_font_size = clampi(min_body_font_size, 1, max_body_font_size)
	var min_heading_font_size: int = clampi(
		adaptive_heading_font_min_size,
		min_body_font_size,
		max_heading_font_size
	)
	var entry: Dictionary = {
		"label": label,
		"heading_label": heading_label,
		"content_stack": content_stack,
		"scroll": structure.get("scroll"),
		"scroll_fallback_enabled": use_scroll_fallback,
		"max_body_font_size": max_body_font_size,
		"max_heading_font_size": max_heading_font_size,
		"min_body_font_size": min_body_font_size,
		"min_heading_font_size": min_heading_font_size,
		"authored_body_line_spacing": label.get_theme_constant("line_spacing"),
		"authored_heading_line_spacing": heading_label.get_theme_constant("line_spacing"),
		"authored_section_spacing": content_stack.get_theme_constant("separation"),
		"selected_body_font_size": max_body_font_size,
		"selected_heading_font_size": max_heading_font_size,
		"selected_line_spacing": label.get_theme_constant("line_spacing"),
		"selected_section_spacing": content_stack.get_theme_constant("separation"),
		"use_compact_text": false,
		"verify_passes": 0,
		"layout_signature": _get_text_layout_signature(initial_text),
	}
	adaptive_label_entries[label_id] = entry
	_set_adaptive_entry_text(entry, initial_text)
	_queue_adaptive_fit()


func set_adaptive_text(label: Label, text: String) -> void:
	if label == null or not is_instance_valid(label):
		return
	if not adaptive_label_entries.has(label.get_instance_id()):
		configure_adaptive_label(label)
	var entry: Dictionary = adaptive_label_entries.get(label.get_instance_id(), {})
	if entry.is_empty():
		label.text = text
		return
	var new_signature: String = _get_text_layout_signature(text)
	var layout_changed: bool = str(entry.get("layout_signature", "")) != new_signature
	_set_adaptive_entry_text(entry, text)
	if layout_changed:
		entry["layout_signature"] = new_signature
		_queue_adaptive_fit()
	adaptive_label_entries[label.get_instance_id()] = entry


func _begin_resize(global_mouse_position: Vector2) -> void:
	if not resizable:
		return
	move_to_front()
	_clamp_resize_origin_to_viewport()
	is_resizing_panel = true
	is_dragging_panel = false
	clicked_inside_panel = false
	resize_start_mouse_position = global_mouse_position
	resize_start_size = size
	_claim_resize_cursor()


func _end_resize() -> void:
	is_resizing_panel = false
	_queue_adaptive_fit()


func _resize_from_global_mouse(global_mouse_position: Vector2) -> void:
	var mouse_delta: Vector2 = global_mouse_position - resize_start_mouse_position
	var desired_size: Vector2 = resize_start_size + mouse_delta
	size = _clamp_size_to_viewport(desired_size)


func _clamp_size_to_viewport(desired_size: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_global_position: Vector2 = get_global_rect().position
	var maximum_size := Vector2(
		maxf(viewport_size.x - resize_viewport_margin - panel_global_position.x, minimum_resize_size.x),
		maxf(viewport_size.y - resize_viewport_margin - panel_global_position.y, minimum_resize_size.y)
	)
	return Vector2(
		clampf(desired_size.x, minimum_resize_size.x, maximum_size.x),
		clampf(desired_size.y, minimum_resize_size.y, maximum_size.y)
	)


func _clamp_resize_origin_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var current_global_position: Vector2 = get_global_rect().position
	var maximum_global_position := Vector2(
		maxf(resize_viewport_margin, viewport_size.x - resize_viewport_margin - minimum_resize_size.x),
		maxf(resize_viewport_margin, viewport_size.y - resize_viewport_margin - minimum_resize_size.y)
	)
	var clamped_global_position := Vector2(
		clampf(current_global_position.x, resize_viewport_margin, maximum_global_position.x),
		clampf(current_global_position.y, resize_viewport_margin, maximum_global_position.y)
	)
	var parent_canvas: CanvasItem = get_parent() as CanvasItem
	position = (
		parent_canvas.get_global_transform().affine_inverse() * clamped_global_position
		if parent_canvas != null
		else clamped_global_position
	)


func _clamp_to_viewport() -> void:
	if not is_inside_tree():
		return
	_clamp_resize_origin_to_viewport()
	size = _clamp_size_to_viewport(size)
	_queue_adaptive_fit()


func _is_global_position_in_resize_hotspot(global_position: Vector2) -> bool:
	return _is_position_in_resize_hotspot(_get_panel_local_position(global_position))


func _is_position_in_resize_hotspot(local_position: Vector2) -> bool:
	if not resizable:
		return false
	return (
		local_position.x >= size.x - resize_hotspot_size
		and local_position.y >= size.y - resize_hotspot_size
		and local_position.x <= size.x
		and local_position.y <= size.y
	)


func _update_resize_cursor(global_mouse_position: Vector2) -> void:
	if is_resizing_panel or _is_global_position_in_resize_hotspot(global_mouse_position):
		_claim_resize_cursor()
	else:
		_release_resize_cursor_if_owned()


func _claim_resize_cursor() -> void:
	resize_cursor_owner_id = get_instance_id()
	Input.set_default_cursor_shape(Input.CURSOR_FDIAGSIZE)


func _release_resize_cursor_if_owned() -> void:
	if resize_cursor_owner_id != get_instance_id():
		return
	resize_cursor_owner_id = 0
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _ensure_adaptive_content_structure(label: Label, scroll_fallback_enabled: bool) -> Dictionary:
	var current_parent: Control = label.get_parent() as Control
	if current_parent == null:
		return {}

	var content_parent: Control = current_parent
	var old_scroll: ScrollContainer = current_parent as ScrollContainer
	if old_scroll != null:
		content_parent = old_scroll.get_parent() as Control
		if content_parent == null:
			return {}
		old_scroll.remove_child(label)
		content_parent.remove_child(old_scroll)
		old_scroll.free()
	else:
		content_parent.remove_child(label)

	var content_stack := VBoxContainer.new()
	content_stack.name = "%sAdaptiveContent" % label.name
	content_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.add_theme_constant_override("separation", 4)
	content_parent.add_child(content_stack)

	var heading_label := Label.new()
	heading_label.name = "%sHeading" % label.name
	heading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading_label.clip_text = false
	heading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_copy_label_presentation(label, heading_label)
	var top_padding := 0.0
	if content_parent is MarginContainer:
		top_padding = float(content_parent.get_theme_constant("margin_top"))
	heading_label.custom_minimum_size = Vector2(0.0, maxf(drag_header_height - top_padding, 1.0))
	content_stack.add_child(heading_label)

	var scroll := ScrollContainer.new()
	scroll.name = "%sScroll" % label.name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if scroll_fallback_enabled
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.add_child(scroll)
	scroll.add_child(label)
	return {
		"content_parent": content_parent,
		"content_stack": content_stack,
		"heading_label": heading_label,
		"scroll": scroll,
	}


func _copy_label_presentation(source: Label, target: Label) -> void:
	target.add_theme_font_override("font", source.get_theme_font("font"))
	target.add_theme_font_size_override("font_size", source.get_theme_font_size("font_size"))
	for color_name in ["font_color", "font_shadow_color", "font_outline_color"]:
		target.add_theme_color_override(color_name, source.get_theme_color(color_name))
	for constant_name in [
		"line_spacing",
		"outline_size",
		"shadow_offset_x",
		"shadow_offset_y",
		"shadow_outline_size",
	]:
		target.add_theme_constant_override(constant_name, source.get_theme_constant(constant_name))


func _set_adaptive_entry_text(entry: Dictionary, full_text: String) -> void:
	var heading_label: Label = entry.get("heading_label") as Label
	var body_label: Label = entry.get("label") as Label
	if heading_label == null or body_label == null:
		return
	var heading_text := full_text
	var body_text := ""
	var first_line_break: int = full_text.find("\n")
	if first_line_break >= 0:
		heading_text = full_text.left(first_line_break)
		body_text = full_text.substr(first_line_break + 1)
		while body_text.begins_with("\n"):
			body_text = body_text.substr(1)
	entry["full_text"] = full_text
	entry["heading_text"] = heading_text
	entry["body_text"] = body_text
	entry["compact_body_text"] = _compact_adaptive_body_text(body_text)
	heading_label.text = heading_text
	body_label.text = (
		str(entry.get("compact_body_text", body_text))
		if bool(entry.get("use_compact_text", false))
		else body_text
	)


func _compact_adaptive_body_text(text: String) -> String:
	var compact_text := text
	while compact_text.contains("\n\n"):
		compact_text = compact_text.replace("\n\n", "\n")
	return compact_text


func _queue_adaptive_fit() -> void:
	adaptive_layout_retry_count = 0
	_schedule_adaptive_fit()


func _schedule_adaptive_fit() -> void:
	if not is_visible_in_tree() or adaptive_fit_queued:
		return
	adaptive_fit_queued = true
	call_deferred("_fit_adaptive_labels")


func _fit_adaptive_labels() -> void:
	adaptive_fit_queued = false
	if not is_visible_in_tree():
		return
	var needs_layout_retry := false
	for label_id in adaptive_label_entries.keys():
		var entry: Dictionary = adaptive_label_entries[label_id]
		var body_label: Label = entry.get("label") as Label
		var heading_label: Label = entry.get("heading_label") as Label
		var content_stack: VBoxContainer = entry.get("content_stack") as VBoxContainer
		if (
			body_label == null
			or heading_label == null
			or content_stack == null
			or not is_instance_valid(body_label)
		):
			adaptive_label_entries.erase(label_id)
			continue
		if content_stack.size.x <= 1.0 or content_stack.size.y <= 1.0:
			needs_layout_retry = true
			continue
		entry["verify_passes"] = 0
		_fit_adaptive_entry(entry)
		adaptive_label_entries[label_id] = entry
	if needs_layout_retry and adaptive_layout_retry_count < ADAPTIVE_MAX_LAYOUT_RETRIES:
		adaptive_layout_retry_count += 1
		_schedule_adaptive_fit()
		return
	adaptive_layout_retry_count = 0
	if not needs_layout_retry:
		_queue_adaptive_verification()


func _fit_adaptive_entry(entry: Dictionary) -> void:
	var content_stack: VBoxContainer = entry.get("content_stack") as VBoxContainer
	var heading_label: Label = entry.get("heading_label") as Label
	var body_label: Label = entry.get("label") as Label
	var scroll: ScrollContainer = entry.get("scroll") as ScrollContainer
	if content_stack == null or heading_label == null or body_label == null or scroll == null:
		return

	var available_width: float = maxf(content_stack.size.x, 48.0)
	var available_height: float = maxf(content_stack.size.y, 36.0)
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if bool(entry.get("scroll_fallback_enabled", true))
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	scroll.scroll_vertical = 0

	var max_body_size: int = int(entry.get("max_body_font_size", 15))
	var max_heading_size: int = int(entry.get("max_heading_font_size", 15))
	var min_body_size: int = int(entry.get("min_body_font_size", adaptive_font_min_size))
	var min_heading_size: int = int(entry.get("min_heading_font_size", adaptive_heading_font_min_size))
	var body_line_spacing: int = int(entry.get("authored_body_line_spacing", 3))
	var heading_line_spacing: int = int(entry.get("authored_heading_line_spacing", 3))
	var section_spacing: int = int(entry.get("authored_section_spacing", 4))
	var reduction_count: int = maxi(max_body_size - min_body_size, max_heading_size - min_heading_size)
	for reduction in range(reduction_count + 1):
		var body_size: int = maxi(max_body_size - reduction, min_body_size)
		var heading_size: int = maxi(max_heading_size - reduction, min_heading_size)
		if _does_adaptive_entry_fit(
			entry,
			available_width,
			available_height,
			body_size,
			heading_size,
			body_line_spacing,
			heading_line_spacing,
			section_spacing,
			false
		):
			_apply_adaptive_entry_layout(
				entry,
				body_size,
				heading_size,
				body_line_spacing,
				heading_line_spacing,
				section_spacing,
				false
			)
			return

	for compact_spacing in range(body_line_spacing - 1, ADAPTIVE_COMPACT_LINE_SPACING - 1, -1):
		var compact_section_spacing: int = maxi(
			ADAPTIVE_COMPACT_SECTION_SPACING,
			section_spacing - (body_line_spacing - compact_spacing)
		)
		var compact_heading_spacing: int = maxi(compact_spacing, ADAPTIVE_COMPACT_LINE_SPACING)
		if _does_adaptive_entry_fit(
			entry,
			available_width,
			available_height,
			min_body_size,
			min_heading_size,
			compact_spacing,
			compact_heading_spacing,
			compact_section_spacing,
			true
		):
			_apply_adaptive_entry_layout(
				entry,
				min_body_size,
				min_heading_size,
				compact_spacing,
				compact_heading_spacing,
				compact_section_spacing,
				true
			)
			return

	_apply_adaptive_entry_layout(
		entry,
		min_body_size,
		min_heading_size,
		ADAPTIVE_COMPACT_LINE_SPACING,
		ADAPTIVE_COMPACT_LINE_SPACING,
		ADAPTIVE_COMPACT_SECTION_SPACING,
		true
	)


func _does_adaptive_entry_fit(
	entry: Dictionary,
	available_width: float,
	available_height: float,
	body_font_size: int,
	heading_font_size: int,
	body_line_spacing: int,
	heading_line_spacing: int,
	section_spacing: int,
	use_compact_text: bool
) -> bool:
	var heading_label: Label = entry.get("heading_label") as Label
	var body_label: Label = entry.get("label") as Label
	if heading_label == null or body_label == null:
		return false
	var heading_size: Vector2 = _measure_adaptive_label(
		heading_label,
		str(entry.get("heading_text", "")),
		available_width,
		heading_font_size,
		heading_line_spacing
	)
	heading_size.y = maxf(heading_size.y, heading_label.custom_minimum_size.y)
	var body_text: String = str(
		entry.get("compact_body_text", "")
		if use_compact_text
		else entry.get("body_text", "")
	)
	var body_size: Vector2 = _measure_adaptive_label(
		body_label,
		body_text,
		available_width,
		body_font_size,
		body_line_spacing
	)
	var total_height: float = heading_size.y + float(section_spacing) + body_size.y
	return (
		heading_size.x <= available_width + ADAPTIVE_FIT_EPSILON
		and body_size.x <= available_width + ADAPTIVE_FIT_EPSILON
		and total_height <= available_height + ADAPTIVE_FIT_EPSILON
	)


func _measure_adaptive_label(
	label: Label,
	text: String,
	available_width: float,
	font_size: int,
	line_spacing: int
) -> Vector2:
	if text.is_empty():
		return Vector2.ZERO
	var font: Font = label.get_theme_font("font")
	if font == null:
		return Vector2(INF, INF)
	var measured_size: Vector2 = font.get_multiline_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		available_width,
		font_size
	)
	var font_line_height: float = maxf(font.get_height(font_size), 1.0)
	var estimated_line_count: int = maxi(ceili(measured_size.y / font_line_height), 1)
	measured_size.y += float(line_spacing * maxi(estimated_line_count - 1, 0))
	var outline_size: float = float(label.get_theme_constant("outline_size"))
	measured_size += Vector2(outline_size * 2.0, outline_size * 2.0)
	return measured_size


func _apply_adaptive_entry_layout(
	entry: Dictionary,
	body_font_size: int,
	heading_font_size: int,
	body_line_spacing: int,
	heading_line_spacing: int,
	section_spacing: int,
	use_compact_text: bool
) -> void:
	var body_label: Label = entry.get("label") as Label
	var heading_label: Label = entry.get("heading_label") as Label
	var content_stack: VBoxContainer = entry.get("content_stack") as VBoxContainer
	var scroll: ScrollContainer = entry.get("scroll") as ScrollContainer
	if body_label == null or heading_label == null or content_stack == null or scroll == null:
		return
	body_label.add_theme_font_size_override("font_size", body_font_size)
	heading_label.add_theme_font_size_override("font_size", heading_font_size)
	body_label.add_theme_constant_override("line_spacing", body_line_spacing)
	heading_label.add_theme_constant_override("line_spacing", heading_line_spacing)
	content_stack.add_theme_constant_override("separation", section_spacing)
	entry["selected_body_font_size"] = body_font_size
	entry["selected_heading_font_size"] = heading_font_size
	entry["selected_line_spacing"] = body_line_spacing
	entry["selected_heading_line_spacing"] = heading_line_spacing
	entry["selected_section_spacing"] = section_spacing
	entry["use_compact_text"] = use_compact_text
	body_label.text = str(
		entry.get("compact_body_text", "")
		if use_compact_text
		else entry.get("body_text", "")
	)
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if bool(entry.get("scroll_fallback_enabled", true))
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	body_label.update_minimum_size()
	heading_label.update_minimum_size()
	content_stack.update_minimum_size()


func _queue_adaptive_verification() -> void:
	if not is_visible_in_tree() or adaptive_verify_queued:
		return
	adaptive_verify_queued = true
	call_deferred("_verify_adaptive_labels")


func _verify_adaptive_labels() -> void:
	adaptive_verify_queued = false
	if not is_visible_in_tree():
		return
	var needs_another_pass := false
	for label_id in adaptive_label_entries.keys():
		var entry: Dictionary = adaptive_label_entries[label_id]
		var body_label: Label = entry.get("label") as Label
		var heading_label: Label = entry.get("heading_label") as Label
		var content_stack: VBoxContainer = entry.get("content_stack") as VBoxContainer
		var scroll: ScrollContainer = entry.get("scroll") as ScrollContainer
		if body_label == null or heading_label == null or content_stack == null or scroll == null:
			continue

		var actual_height: float = (
			maxf(heading_label.get_combined_minimum_size().y, heading_label.custom_minimum_size.y)
			+ float(entry.get("selected_section_spacing", ADAPTIVE_COMPACT_SECTION_SPACING))
			+ body_label.get_combined_minimum_size().y
		)
		var overflow: bool = actual_height > content_stack.size.y + ADAPTIVE_FIT_EPSILON
		if not overflow:
			scroll.vertical_scroll_mode = (
				ScrollContainer.SCROLL_MODE_SHOW_NEVER
				if bool(entry.get("scroll_fallback_enabled", true))
				else ScrollContainer.SCROLL_MODE_DISABLED
			)
			continue

		var verify_passes: int = int(entry.get("verify_passes", 0))
		var body_size: int = int(entry.get("selected_body_font_size", adaptive_font_min_size))
		var heading_size: int = int(entry.get("selected_heading_font_size", adaptive_heading_font_min_size))
		var min_body_size: int = int(entry.get("min_body_font_size", adaptive_font_min_size))
		var min_heading_size: int = int(entry.get("min_heading_font_size", adaptive_heading_font_min_size))
		if verify_passes < ADAPTIVE_MAX_VERIFY_PASSES and (body_size > min_body_size or heading_size > min_heading_size):
			_apply_adaptive_entry_layout(
				entry,
				maxi(body_size - 1, min_body_size),
				maxi(heading_size - 1, min_heading_size),
				int(entry.get("selected_line_spacing", 3)),
				int(entry.get("selected_heading_line_spacing", 3)),
				int(entry.get("selected_section_spacing", 4)),
				false
			)
			entry["verify_passes"] = verify_passes + 1
			adaptive_label_entries[label_id] = entry
			needs_another_pass = true
			continue

		if not bool(entry.get("use_compact_text", false)):
			_apply_adaptive_entry_layout(
				entry,
				min_body_size,
				min_heading_size,
				ADAPTIVE_COMPACT_LINE_SPACING,
				ADAPTIVE_COMPACT_LINE_SPACING,
				ADAPTIVE_COMPACT_SECTION_SPACING,
				true
			)
			entry["verify_passes"] = verify_passes + 1
			adaptive_label_entries[label_id] = entry
			needs_another_pass = true
			continue

		if bool(entry.get("scroll_fallback_enabled", true)):
			scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	if needs_another_pass:
		_queue_adaptive_verification()


func _get_text_layout_signature(text: String) -> String:
	var lines: PackedStringArray = text.split("\n", true)
	var longest_line: int = 0
	var line_lengths: PackedStringArray = PackedStringArray()
	for line in lines:
		longest_line = maxi(longest_line, line.length())
		line_lengths.append(str(line.length()))
	var normalized_text: String = _normalize_adaptive_layout_text(text)
	return "%s:%s:%s:%s:%s" % [
		lines.size(),
		longest_line,
		text.length(),
		",".join(line_lengths),
		normalized_text.hash(),
	]


func _normalize_adaptive_layout_text(text: String) -> String:
	var normalized_text: String = ""
	for character_value in text:
		var character: String = str(character_value)
		normalized_text += "8" if "0123456789".contains(character) else character
	return normalized_text


func _on_panel_resized() -> void:
	_queue_adaptive_fit()


func _on_panel_visibility_changed() -> void:
	if visible:
		_queue_adaptive_fit()
	else:
		is_dragging_panel = false
		is_resizing_panel = false
		clicked_inside_panel = false
		_release_resize_cursor_if_owned()


func _on_viewport_size_changed() -> void:
	_clamp_to_viewport()


func _exit_tree() -> void:
	_release_resize_cursor_if_owned()
