extends Control
class_name DevOptionsPanel

signal back_requested

const TAB_SESSION := "session"
const TAB_AIM_PHYSICS := "aim_physics"
const TAB_BALLS_EVENTS := "balls_events"
const TAB_RUN_SYSTEMS := "run_systems"
const TAB_PANELS_DIAGNOSTICS := "panels_diagnostics"
const TAB_DEFINITIONS: Array[Dictionary] = [
	{"id": TAB_SESSION, "label": "SESSION"},
	{"id": TAB_AIM_PHYSICS, "label": "AIM & PHYSICS"},
	{"id": TAB_BALLS_EVENTS, "label": "BALLS & EVENTS"},
	{"id": TAB_RUN_SYSTEMS, "label": "RUN SYSTEMS"},
	{"id": TAB_PANELS_DIAGNOSTICS, "label": "PANELS & DIAGNOSTICS"},
]
const SECTION_ORDER_BY_TAB := {
	TAB_SESSION: ["Display & Session", "Session Utilities"],
	TAB_AIM_PHYSICS: ["Aim Testing", "Player Aim Benchmark", "Live Collision Accuracy", "Cloned Predictor", "Simulation Timing & Work", "Event & Contact Limits", "Trace Limits", "Aim Drawing", "Aim Profiler"],
	TAB_BALLS_EVENTS: ["Table Events", "Cargo & Contraband", "Table Debris", "Anchor Testing / Visuals", "Treasure Testing / Visuals", "Powder Keg Presentation"],
	TAB_RUN_SYSTEMS: ["Back Room", "Kraken Boons", "Reserve Stack Tests", "Sunken Spoils", "Oath Testing"],
	TAB_PANELS_DIAGNOSTICS: ["Panel Workspace Actions", "Aim Panels", "Performance Panels", "System Panels", "Overlay Diagnostics"],
}

const OVERLAY_Z_INDEX := 20
const HELP_POPUP_Z_INDEX := 50
const VIEWPORT_MARGIN := 32.0
const MAX_PANEL_SIZE := Vector2(1500.0, 860.0)
const MIN_PANEL_SIZE := Vector2(720.0, 520.0)
const PANEL_PADDING := 24.0
const TITLE_HEIGHT := 34.0
const SEARCH_HEIGHT := 36.0
const SEARCH_HINT_WIDTH := 370.0
const TAB_BAR_HEIGHT := 42.0
const HEADER_GAP := 10.0
const FOOTER_HEIGHT := 46.0
const FOOTER_GAP := 14.0
const CARD_GAP := 12
const CARD_PADDING := 14
const ONE_COLUMN_THRESHOLD := 900.0
const THREE_COLUMN_THRESHOLD := 1350.0
const HELP_POPUP_WIDTH := 440.0
const HELP_POPUP_MAX_HEIGHT := 460.0

var panel_shell: Panel
var shade: ColorRect
var title_label: Label
var search_edit: LineEdit
var search_hint_label: Label
var tab_bar: HBoxContainer
var content_root: Control
var back_button: Button
var help_popup: PanelContainer
var help_label: Label
var search_scroll: ScrollContainer
var search_grid: GridContainer
var no_results_label: Label
var tab_buttons: Dictionary = {}
var tab_scrolls: Dictionary = {}
var tab_grids: Dictionary = {}
var tab_scroll_positions: Dictionary = {}
var selected_tab_id := TAB_SESSION
var _search_restore_tab_id := TAB_SESSION
var _font_source: Control
var _panel_style_source: Control
var _registry: DevOptionRegistry
var _editors_by_option_id: Dictionary = {}
var _normal_editor_nodes: Array[Control] = []
var _search_editor_nodes: Array[Control] = []
var _hovered_option_id := ""
var _alt_help_was_active := false
var _built := false


func setup(
	font_source: Control,
	panel_style_source: Control,
	registry_ref: DevOptionRegistry = null
) -> void:
	if _built:
		return
	_built = true
	_font_source = font_source
	_panel_style_source = panel_style_source
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	z_index = OVERLAY_Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_overlay()
	set_registry(registry_ref)
	_layout_overlay()
	_select_tab(selected_tab_id, false)


func set_registry(registry_ref: DevOptionRegistry) -> void:
	if _registry != null and _registry.option_changed.is_connected(_on_registry_option_changed):
		_registry.option_changed.disconnect(_on_registry_option_changed)
	_registry = registry_ref
	if _registry != null and not _registry.option_changed.is_connected(_on_registry_option_changed):
		_registry.option_changed.connect(_on_registry_option_changed)
	if _built:
		rebuild_options()


func rebuild_options() -> void:
	if not _built:
		return
	_hovered_option_id = ""
	_hide_help()
	_clear_all_editors()
	for grid_value in tab_grids.values():
		_clear_container(grid_value as Container)
	if _registry == null:
		return

	var definitions_by_location: Dictionary = {}
	for located_definition in _registry.get_definitions():
		var locations_value: Variant = located_definition.get("locations", [])
		if not locations_value is Array:
			continue
		for location_value in locations_value:
			if not location_value is Dictionary:
				continue
			var location: Dictionary = location_value
			var tab_id: String = str(location.get("tab_id", ""))
			var section_title: String = str(location.get("section", "Other"))
			if not tab_grids.has(tab_id):
				continue
			var sections: Dictionary = definitions_by_location.get(tab_id, {})
			var section_definitions: Array = sections.get(section_title, [])
			section_definitions.append(located_definition)
			sections[section_title] = section_definitions
			definitions_by_location[tab_id] = sections

	for tab_definition in TAB_DEFINITIONS:
		var ordered_tab_id: String = str(tab_definition.get("id", ""))
		var ordered_grid: GridContainer = tab_grids.get(ordered_tab_id) as GridContainer
		var ordered_sections: Dictionary = definitions_by_location.get(ordered_tab_id, {})
		if ordered_grid == null:
			continue
		for ordered_section_title in _get_ordered_section_titles(ordered_tab_id, ordered_sections):
			var card: PanelContainer = _make_section_card(ordered_section_title)
			var body: VBoxContainer = card.get_meta("section_body") as VBoxContainer
			ordered_grid.add_child(card)
			for definition_value in ordered_sections.get(ordered_section_title, []):
				var editor_definition: Dictionary = definition_value
				var editor: Control = _make_option_editor(editor_definition, false)
				if editor != null:
					body.add_child(editor)
	_update_responsive_columns()
	_rebuild_search_results()
	_registry.refresh_all()


func _get_ordered_section_titles(tab_id: String, sections: Dictionary) -> Array[String]:
	var ordered_titles: Array[String] = []
	for title_value in SECTION_ORDER_BY_TAB.get(tab_id, []):
		var title: String = str(title_value)
		if sections.has(title):
			ordered_titles.append(title)
	for title_value in sections.keys():
		var remaining_title: String = str(title_value)
		if not ordered_titles.has(remaining_title):
			ordered_titles.append(remaining_title)
	return ordered_titles


func open_panel() -> void:
	visible = true
	set_process(true)
	_layout_overlay()
	_apply_content_visibility()
	if _registry != null:
		_registry.refresh_all()
	call_deferred("_focus_initial_control")


func close_panel() -> void:
	_store_selected_scroll_position()
	_hovered_option_id = ""
	_hide_help()
	visible = false
	set_process(false)


func is_open() -> bool:
	return visible


func handle_cancel_request() -> bool:
	if search_edit != null and not search_edit.text.is_empty():
		search_edit.clear()
		search_edit.grab_focus()
		return true
	return false


func get_session_snapshot() -> Dictionary:
	_store_selected_scroll_position()
	return {
		"selected_tab_id": selected_tab_id,
		"tab_scroll_positions": tab_scroll_positions.duplicate(true),
		"search_query": search_edit.text if search_edit != null else "",
	}


func apply_session_snapshot(snapshot: Dictionary) -> void:
	var requested_tab: String = str(snapshot.get("selected_tab_id", TAB_SESSION))
	if tab_scrolls.has(requested_tab):
		selected_tab_id = requested_tab
	var positions_value: Variant = snapshot.get("tab_scroll_positions", {})
	if positions_value is Dictionary:
		tab_scroll_positions = (positions_value as Dictionary).duplicate(true)
	_select_tab(selected_tab_id, false)
	if search_edit != null:
		search_edit.text = str(snapshot.get("search_query", ""))
		_on_search_text_changed(search_edit.text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_layout_overlay()


func _process(_delta: float) -> void:
	if not visible or _hovered_option_id.is_empty():
		if help_popup != null and help_popup.visible:
			_hide_help()
		return
	var alt_help_active: bool = Input.is_key_pressed(KEY_ALT)
	if alt_help_active != _alt_help_was_active:
		_alt_help_was_active = alt_help_active
		_update_help_visibility()
	elif alt_help_active and help_popup.visible:
		_position_help_popup()


func _unhandled_key_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func _build_overlay() -> void:
	shade = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.005, 0.008, 0.012, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(_consume_pointer_input)

	panel_shell = Panel.new()
	panel_shell.name = "PanelShell"
	panel_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	if _panel_style_source != null:
		var panel_style: StyleBox = _panel_style_source.get_theme_stylebox("panel")
		if panel_style != null:
			var panel_style_copy: StyleBox = panel_style.duplicate() as StyleBox
			if panel_style_copy != null:
				panel_shell.add_theme_stylebox_override("panel", panel_style_copy)
	add_child(panel_shell)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Dev Options"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(title_label, 26)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.95))
	title_label.add_theme_constant_override("outline_size", 2)
	panel_shell.add_child(title_label)

	search_edit = LineEdit.new()
	search_edit.name = "SearchEdit"
	search_edit.placeholder_text = "Search Dev Options..."
	search_edit.clear_button_enabled = true
	search_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_font(search_edit, 16)
	search_edit.text_changed.connect(_on_search_text_changed)
	panel_shell.add_child(search_edit)

	search_hint_label = Label.new()
	search_hint_label.name = "SearchHintLabel"
	search_hint_label.text = "Hold Left Alt while hovering an option for help."
	search_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	search_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	search_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(search_hint_label, 13)
	search_hint_label.add_theme_color_override("font_color", Color(0.72, 0.72, 0.66, 0.92))
	panel_shell.add_child(search_hint_label)

	tab_bar = HBoxContainer.new()
	tab_bar.name = "TabBar"
	tab_bar.add_theme_constant_override("separation", 6)
	panel_shell.add_child(tab_bar)

	content_root = Control.new()
	content_root.name = "ContentRoot"
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_shell.add_child(content_root)

	for tab_definition in TAB_DEFINITIONS:
		_build_tab(tab_definition)
	_build_search_view()

	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(180.0, FOOTER_HEIGHT)
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	back_button.focus_mode = Control.FOCUS_ALL
	_apply_font(back_button, 18)
	back_button.pressed.connect(_on_back_pressed)
	panel_shell.add_child(back_button)

	_build_help_popup()


func _build_tab(tab_definition: Dictionary) -> void:
	var tab_id: String = str(tab_definition.get("id", ""))
	var button: Button = Button.new()
	button.name = "%sTabButton" % tab_id.to_pascal_case()
	button.text = str(tab_definition.get("label", tab_id))
	button.toggle_mode = true
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, TAB_BAR_HEIGHT)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	_apply_font(button, 14)
	button.pressed.connect(_on_tab_pressed.bind(tab_id))
	tab_bar.add_child(button)
	tab_buttons[tab_id] = button

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "%sScroll" % tab_id.to_pascal_case()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.visible = false
	content_root.add_child(scroll)
	tab_scrolls[tab_id] = scroll

	var grid: GridContainer = GridContainer.new()
	grid.name = "%sGrid" % tab_id.to_pascal_case()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", CARD_GAP)
	grid.add_theme_constant_override("v_separation", CARD_GAP)
	scroll.add_child(grid)
	tab_grids[tab_id] = grid
	tab_scroll_positions[tab_id] = 0


func _build_search_view() -> void:
	search_scroll = ScrollContainer.new()
	search_scroll.name = "SearchResultsScroll"
	search_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	search_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	search_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	search_scroll.visible = false
	content_root.add_child(search_scroll)

	search_grid = GridContainer.new()
	search_grid.name = "SearchResultsGrid"
	search_grid.columns = 1
	search_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_grid.add_theme_constant_override("h_separation", CARD_GAP)
	search_grid.add_theme_constant_override("v_separation", CARD_GAP)
	search_scroll.add_child(search_grid)


func _build_help_popup() -> void:
	help_popup = PanelContainer.new()
	help_popup.name = "ContextHelpPopup"
	help_popup.visible = false
	help_popup.z_index = HELP_POPUP_Z_INDEX
	help_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_popup.custom_minimum_size = Vector2(HELP_POPUP_WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.022, 0.028, 0.98)
	style.border_color = Color(0.76, 0.6, 0.25, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	help_popup.add_theme_stylebox_override("panel", style)
	add_child(help_popup)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	help_popup.add_child(margin)

	help_label = Label.new()
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label.custom_minimum_size = Vector2(HELP_POPUP_WIDTH - 32.0, 0.0)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(help_label, 14)
	help_label.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8, 1.0))
	margin.add_child(help_label)


func _make_section_card(section_title: String) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = "%sSection" % section_title.to_pascal_case().replace("&", "And")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.018, 0.027, 0.035, 0.92)
	card_style.border_color = Color(0.52, 0.43, 0.24, 0.72)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_PADDING - 2)
	margin.add_theme_constant_override("margin_right", CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING)
	card.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	var heading: Label = Label.new()
	heading.text = section_title
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(heading, 16)
	heading.add_theme_color_override("font_color", Color(0.86, 0.78, 0.52, 1.0))
	stack.add_child(heading)

	var separator: HSeparator = HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(separator)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	card.set_meta("section_body", body)
	return card


func _make_option_editor(definition: Dictionary, search_editor: bool) -> Control:
	var option_id: String = str(definition.get("id", ""))
	var kind: String = str(definition.get("kind", "bool"))
	var editor_root: Control
	var value_editor: Control
	match kind:
		"bool":
			var check_box := CheckBox.new()
			check_box.text = str(definition.get("label", option_id))
			check_box.mouse_filter = Control.MOUSE_FILTER_STOP
			check_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_apply_font(check_box, 14)
			check_box.toggled.connect(_on_bool_editor_changed.bind(option_id))
			editor_root = check_box
			value_editor = check_box
		"number":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var label := Label.new()
			label.text = str(definition.get("label", option_id))
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_font(label, 13)
			row.add_child(label)
			var spin_box := SpinBox.new()
			spin_box.custom_minimum_size = Vector2(120.0, 30.0)
			spin_box.min_value = float(definition.get("minimum", 0.0))
			spin_box.max_value = float(definition.get("maximum", 0.0))
			spin_box.step = float(definition.get("step", 1.0))
			spin_box.allow_greater = false
			spin_box.allow_lesser = false
			spin_box.value_changed.connect(_on_number_editor_changed.bind(option_id))
			row.add_child(spin_box)
			editor_root = row
			value_editor = spin_box
		"select":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var label := Label.new()
			label.text = str(definition.get("label", option_id))
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_font(label, 13)
			row.add_child(label)
			var selector := OptionButton.new()
			selector.custom_minimum_size = Vector2(150.0, 30.0)
			for choice_value in definition.get("choices", []):
				if not choice_value is Dictionary:
					continue
				var choice: Dictionary = choice_value
				var choice_index: int = selector.item_count
				selector.add_item(str(choice.get("label", choice.get("value", "Choice"))))
				selector.set_item_metadata(choice_index, choice.get("value"))
			selector.item_selected.connect(_on_select_editor_changed.bind(option_id, selector))
			row.add_child(selector)
			editor_root = row
			value_editor = selector
		"text":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var label := Label.new()
			label.text = str(definition.get("label", option_id))
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_font(label, 13)
			row.add_child(label)
			var line_edit := LineEdit.new()
			line_edit.custom_minimum_size = Vector2(270.0, 30.0)
			line_edit.placeholder_text = str(definition.get("placeholder", "Optional label"))
			line_edit.text_changed.connect(_on_text_editor_changed.bind(option_id))
			line_edit.text_submitted.connect(_on_text_editor_submitted.bind(option_id))
			line_edit.focus_exited.connect(_on_text_editor_focus_exited.bind(option_id, line_edit))
			row.add_child(line_edit)
			editor_root = row
			value_editor = line_edit
		"action":
			var button := Button.new()
			button.text = str(definition.get("label", option_id))
			button.mouse_filter = Control.MOUSE_FILTER_STOP
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_apply_font(button, 14)
			button.pressed.connect(_on_action_editor_pressed.bind(option_id))
			editor_root = button
			value_editor = button
		"readout":
			var stack := VBoxContainer.new()
			var label := Label.new()
			label.text = str(definition.get("label", option_id))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_font(label, 13)
			stack.add_child(label)
			var readout := Label.new()
			readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
			readout.add_theme_color_override("font_color", Color(0.78, 0.88, 0.84, 0.96))
			_apply_font(readout, 13)
			stack.add_child(readout)
			editor_root = stack
			value_editor = readout
		_:
			return null

	editor_root.set_meta("dev_option_id", option_id)
	editor_root.mouse_filter = Control.MOUSE_FILTER_PASS
	editor_root.mouse_entered.connect(_on_option_hover_entered.bind(option_id))
	editor_root.mouse_exited.connect(_on_option_hover_exited.bind(option_id))
	_register_value_editor(option_id, value_editor, search_editor)
	_update_editor_value(option_id, value_editor, _registry.get_value(option_id) if _registry != null else null)
	return editor_root


func _register_value_editor(option_id: String, editor: Control, search_editor: bool) -> void:
	if editor == null:
		return
	editor.set_meta("dev_option_id", option_id)
	var editors: Array = _editors_by_option_id.get(option_id, [])
	editors.append(editor)
	_editors_by_option_id[option_id] = editors
	if search_editor:
		_search_editor_nodes.append(editor)
	else:
		_normal_editor_nodes.append(editor)


func _layout_overlay() -> void:
	if panel_shell == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = size
	var available_size := Vector2(
		maxf(viewport_size.x - VIEWPORT_MARGIN * 2.0, 320.0),
		maxf(viewport_size.y - VIEWPORT_MARGIN * 2.0, 300.0)
	)
	var panel_size := Vector2(
		minf(available_size.x, MAX_PANEL_SIZE.x),
		minf(available_size.y, MAX_PANEL_SIZE.y)
	)
	if available_size.x >= MIN_PANEL_SIZE.x:
		panel_size.x = maxf(panel_size.x, MIN_PANEL_SIZE.x)
	if available_size.y >= MIN_PANEL_SIZE.y:
		panel_size.y = maxf(panel_size.y, MIN_PANEL_SIZE.y)
	panel_shell.size = panel_size
	panel_shell.position = ((viewport_size - panel_size) * 0.5).floor()

	title_label.position = Vector2(PANEL_PADDING, 12.0)
	title_label.size = Vector2(panel_size.x - PANEL_PADDING * 2.0, TITLE_HEIGHT)
	var search_top: float = title_label.position.y + TITLE_HEIGHT + 6.0
	var inner_width: float = panel_size.x - PANEL_PADDING * 2.0
	var search_width: float = maxf(inner_width - SEARCH_HINT_WIDTH - 14.0, 260.0)
	search_edit.position = Vector2(PANEL_PADDING, search_top)
	search_edit.size = Vector2(search_width, SEARCH_HEIGHT)
	search_hint_label.position = Vector2(PANEL_PADDING + search_width + 14.0, search_top)
	search_hint_label.size = Vector2(maxf(inner_width - search_width - 14.0, 0.0), SEARCH_HEIGHT)
	tab_bar.position = Vector2(PANEL_PADDING, search_top + SEARCH_HEIGHT + HEADER_GAP)
	tab_bar.size = Vector2(inner_width, TAB_BAR_HEIGHT)

	var content_top: float = tab_bar.position.y + TAB_BAR_HEIGHT + HEADER_GAP
	var content_bottom: float = panel_size.y - PANEL_PADDING - FOOTER_HEIGHT - FOOTER_GAP
	content_root.position = Vector2(PANEL_PADDING, content_top)
	content_root.size = Vector2(inner_width, maxf(content_bottom - content_top, 120.0))
	for scroll_value in tab_scrolls.values():
		var scroll: ScrollContainer = scroll_value as ScrollContainer
		if scroll != null:
			scroll.position = Vector2.ZERO
			scroll.size = content_root.size
	search_scroll.position = Vector2.ZERO
	search_scroll.size = content_root.size

	back_button.size = Vector2(180.0, FOOTER_HEIGHT)
	back_button.position = Vector2(
		panel_size.x - PANEL_PADDING - back_button.size.x,
		panel_size.y - PANEL_PADDING - FOOTER_HEIGHT
	)
	_update_responsive_columns()
	if help_popup.visible:
		_position_help_popup()


func _update_responsive_columns() -> void:
	if content_root == null:
		return
	var content_width: float = content_root.size.x
	var column_count := 1
	if content_width >= THREE_COLUMN_THRESHOLD:
		column_count = 3
	elif content_width >= ONE_COLUMN_THRESHOLD:
		column_count = 2
	for grid_value in tab_grids.values():
		var grid: GridContainer = grid_value as GridContainer
		if grid != null:
			grid.columns = column_count
			grid.custom_minimum_size = Vector2(maxf(content_width - 18.0, 280.0), 0.0)
	if search_grid != null:
		search_grid.columns = column_count
		search_grid.custom_minimum_size = Vector2(maxf(content_width - 18.0, 280.0), 0.0)


func _select_tab(tab_id: String, store_current_scroll: bool = true) -> void:
	if not tab_scrolls.has(tab_id):
		return
	if store_current_scroll:
		_store_selected_scroll_position()
	selected_tab_id = tab_id
	if search_edit == null or search_edit.text.strip_edges().is_empty():
		_search_restore_tab_id = tab_id
	_apply_content_visibility()
	var selected_scroll: ScrollContainer = tab_scrolls[selected_tab_id] as ScrollContainer
	if selected_scroll != null:
		selected_scroll.set_deferred("scroll_vertical", int(tab_scroll_positions.get(selected_tab_id, 0)))
	_hovered_option_id = ""
	_hide_help()


func _apply_content_visibility() -> void:
	var search_active: bool = search_edit != null and not search_edit.text.strip_edges().is_empty()
	for id_value in tab_scrolls.keys():
		var current_id: String = str(id_value)
		var scroll: ScrollContainer = tab_scrolls[current_id] as ScrollContainer
		var button: Button = tab_buttons[current_id] as Button
		var selected: bool = current_id == selected_tab_id
		if scroll != null:
			scroll.visible = selected and not search_active
		if button != null:
			button.set_pressed_no_signal(selected)
			button.disabled = search_active
	if search_scroll != null:
		search_scroll.visible = search_active


func _store_selected_scroll_position() -> void:
	var scroll: ScrollContainer = tab_scrolls.get(selected_tab_id) as ScrollContainer
	if scroll != null:
		tab_scroll_positions[selected_tab_id] = scroll.scroll_vertical


func _rebuild_search_results() -> void:
	if search_grid == null:
		return
	_unregister_search_editors()
	_clear_container(search_grid)
	if _registry == null or search_edit.text.strip_edges().is_empty():
		return

	var matches: Array[Dictionary] = _registry.search(search_edit.text)
	if matches.is_empty():
		no_results_label = Label.new()
		no_results_label.text = "No matching Dev Options"
		no_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_results_label.custom_minimum_size = Vector2(300.0, 72.0)
		_apply_font(no_results_label, 18)
		no_results_label.add_theme_color_override("font_color", Color(0.78, 0.76, 0.68, 0.95))
		search_grid.add_child(no_results_label)
		return

	var section_bodies: Dictionary = {}
	for definition in matches:
		var tab_id: String = str(definition.get("tab_id", ""))
		var section_title: String = str(definition.get("section", "Other"))
		var origin_title: String = "%s / %s" % [_get_tab_label(tab_id), section_title]
		var section_key: String = "%s|%s" % [tab_id, section_title]
		var body: VBoxContainer = section_bodies.get(section_key) as VBoxContainer
		if body == null:
			var card: PanelContainer = _make_section_card(origin_title)
			body = card.get_meta("section_body") as VBoxContainer
			search_grid.add_child(card)
			section_bodies[section_key] = body
		var editor: Control = _make_option_editor(definition, true)
		if editor != null:
			body.add_child(editor)


func _on_search_text_changed(new_text: String) -> void:
	var search_was_active: bool = search_scroll != null and search_scroll.visible
	var search_is_active: bool = not new_text.strip_edges().is_empty()
	if search_is_active and not search_was_active:
		_store_selected_scroll_position()
		_search_restore_tab_id = selected_tab_id
	elif not search_is_active and search_was_active and tab_scrolls.has(_search_restore_tab_id):
		selected_tab_id = _search_restore_tab_id
	_rebuild_search_results()
	_apply_content_visibility()
	_hovered_option_id = ""
	_hide_help()


func _on_registry_option_changed(option_id: String, value: Variant) -> void:
	var editors: Array = _editors_by_option_id.get(option_id, [])
	for editor_value in editors:
		var editor: Control = editor_value as Control
		if is_instance_valid(editor):
			_update_editor_value(option_id, editor, value)
	if help_popup != null and help_popup.visible and _hovered_option_id == option_id:
		help_label.text = _format_help_text(_registry.get_definition(option_id))
		help_popup.reset_size()
		_position_help_popup()


func _update_editor_value(option_id: String, editor: Control, value: Variant) -> void:
	if editor == null or _registry == null:
		return
	var definition: Dictionary = _registry.get_definition(option_id)
	var disabled_getter: Callable = definition.get("disabled_getter", Callable())
	var disabled: bool = bool(disabled_getter.call()) if disabled_getter.is_valid() else false
	if editor is CheckBox:
		(editor as CheckBox).set_pressed_no_signal(bool(value))
		(editor as CheckBox).disabled = disabled
	elif editor is SpinBox:
		(editor as SpinBox).set_value_no_signal(float(value))
		(editor as SpinBox).get_line_edit().editable = not disabled
	elif editor is OptionButton:
		var selector := editor as OptionButton
		selector.disabled = disabled
		for item_index in range(selector.item_count):
			if selector.get_item_metadata(item_index) == value or str(selector.get_item_metadata(item_index)) == str(value):
				selector.select(item_index)
				break
	elif editor is LineEdit:
		(editor as LineEdit).editable = not disabled
		if not (editor as LineEdit).has_focus() and (editor as LineEdit).text != str(value):
			(editor as LineEdit).text = str(value)
	elif editor is Label:
		(editor as Label).text = str(value)


func _on_bool_editor_changed(enabled: bool, option_id: String) -> void:
	if _registry != null:
		_registry.set_value(option_id, enabled)


func _on_number_editor_changed(value: float, option_id: String) -> void:
	if _registry != null:
		_registry.set_value(option_id, value)


func _on_select_editor_changed(index: int, option_id: String, selector: OptionButton) -> void:
	if _registry != null and selector != null and index >= 0:
		_registry.set_value(option_id, selector.get_item_metadata(index))


func _on_text_editor_submitted(value: String, option_id: String) -> void:
	if _registry != null:
		_registry.set_value(option_id, value)


func _on_text_editor_changed(value: String, option_id: String) -> void:
	if _registry != null:
		_registry.set_value(option_id, value)


func _on_text_editor_focus_exited(option_id: String, line_edit: LineEdit) -> void:
	if _registry != null and line_edit != null:
		_registry.set_value(option_id, line_edit.text)


func _on_action_editor_pressed(option_id: String) -> void:
	if _registry != null:
		_registry.trigger_action(option_id)


func _on_option_hover_entered(option_id: String) -> void:
	_hovered_option_id = option_id
	_update_help_visibility()


func _on_option_hover_exited(option_id: String) -> void:
	if _hovered_option_id == option_id:
		_hovered_option_id = ""
	_hide_help()


func _update_help_visibility() -> void:
	if not visible or _registry == null or _hovered_option_id.is_empty() or not Input.is_key_pressed(KEY_ALT):
		_hide_help()
		return
	var definition: Dictionary = _registry.get_definition(_hovered_option_id)
	if definition.is_empty():
		_hide_help()
		return
	help_label.text = _format_help_text(definition)
	help_popup.visible = true
	help_popup.reset_size()
	_position_help_popup()


func _format_help_text(definition: Dictionary) -> String:
	var option_id: String = str(definition.get("id", ""))
	var kind: String = str(definition.get("kind", "bool"))
	var lines: Array[String] = [
		str(definition.get("label", option_id)),
		"",
		str(definition.get("description", "Developer-only option.")),
	]
	var impact: String = str(definition.get("impact", ""))
	if not impact.is_empty():
		lines.append("")
		lines.append(impact)
	match kind:
		"bool":
			lines.append("")
			lines.append("Current: %s" % ("On" if bool(_registry.get_value(option_id)) else "Off"))
			var on_effect: String = str(definition.get("on_effect", ""))
			var off_effect: String = str(definition.get("off_effect", ""))
			if not on_effect.is_empty():
				lines.append("On: %s" % on_effect)
			if not off_effect.is_empty():
				lines.append("Off: %s" % off_effect)
		"number":
			var unit: String = str(definition.get("unit", ""))
			var suffix: String = " %s" % unit if not unit.is_empty() else ""
			lines.append("")
			lines.append("Current: %s%s" % [_format_number(_registry.get_value(option_id)), suffix])
			lines.append("Default: %s%s" % [_format_number(definition.get("default", 0)), suffix])
			lines.append("Range: %s-%s%s" % [
				_format_number(definition.get("minimum", 0)),
				_format_number(definition.get("maximum", 0)),
				suffix,
			])
			var low_effect: String = str(definition.get("low_effect", ""))
			var high_effect: String = str(definition.get("high_effect", ""))
			if not low_effect.is_empty():
				lines.append("")
				lines.append("Low values: %s" % low_effect)
			if not high_effect.is_empty():
				lines.append("High values: %s" % high_effect)
		"select":
			lines.append("")
			lines.append("Current: %s" % _get_choice_label(definition, _registry.get_value(option_id)))
			for choice_value in definition.get("choices", []):
				if choice_value is Dictionary:
					var choice: Dictionary = choice_value
					var choice_help: String = str(choice.get("description", ""))
					if not choice_help.is_empty():
						lines.append("%s: %s" % [choice.get("label", "Choice"), choice_help])
		"text":
			lines.append("")
			lines.append("Current: %s" % str(_registry.get_value(option_id)))
		"action":
			lines.append("")
			lines.append("Pressing this runs the described developer action immediately.")
	return "\n".join(lines)


func _position_help_popup() -> void:
	if help_popup == null or not help_popup.visible:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var minimum_size: Vector2 = help_popup.get_combined_minimum_size()
	var popup_size := Vector2(HELP_POPUP_WIDTH, minf(maxf(minimum_size.y, 120.0), HELP_POPUP_MAX_HEIGHT))
	help_popup.size = popup_size
	var desired_position: Vector2 = get_local_mouse_position() + Vector2(18.0, 18.0)
	help_popup.position = Vector2(
		clampf(desired_position.x, 12.0, maxf(viewport_size.x - popup_size.x - 12.0, 12.0)),
		clampf(desired_position.y, 12.0, maxf(viewport_size.y - popup_size.y - 12.0, 12.0))
	)


func _hide_help() -> void:
	_alt_help_was_active = Input.is_key_pressed(KEY_ALT)
	if help_popup != null:
		help_popup.visible = false


func _clear_all_editors() -> void:
	_editors_by_option_id.clear()
	_normal_editor_nodes.clear()
	_search_editor_nodes.clear()


func _unregister_search_editors() -> void:
	for editor in _search_editor_nodes:
		if not is_instance_valid(editor):
			continue
		var option_id: String = str(editor.get_meta("dev_option_id", ""))
		var editors: Array = _editors_by_option_id.get(option_id, [])
		editors.erase(editor)
		if editors.is_empty():
			_editors_by_option_id.erase(option_id)
		else:
			_editors_by_option_id[option_id] = editors
	_search_editor_nodes.clear()


func _clear_container(container: Container) -> void:
	if container == null:
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _get_choice_label(definition: Dictionary, value: Variant) -> String:
	for choice_value in definition.get("choices", []):
		if choice_value is Dictionary:
			var choice: Dictionary = choice_value
			if choice.get("value") == value or str(choice.get("value")) == str(value):
				return str(choice.get("label", value))
	return str(value)


func _get_tab_label(tab_id: String) -> String:
	for tab_definition in TAB_DEFINITIONS:
		if str(tab_definition.get("id", "")) == tab_id:
			return str(tab_definition.get("label", tab_id))
	return tab_id


func _format_number(value: Variant) -> String:
	var number: float = float(value)
	if is_equal_approx(number, roundf(number)):
		return str(int(roundf(number)))
	return "%.2f" % number


func _focus_initial_control() -> void:
	if not visible:
		return
	if search_edit != null and not search_edit.text.is_empty():
		search_edit.grab_focus()
		return
	var button: Button = tab_buttons.get(selected_tab_id) as Button
	if button != null:
		button.grab_focus()


func _apply_font(control: Control, font_size: int) -> void:
	if _font_source != null:
		control.add_theme_font_override("font", _font_source.get_theme_font("font"))
	control.add_theme_font_size_override("font_size", font_size)


func _consume_pointer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		accept_event()


func _on_tab_pressed(tab_id: String) -> void:
	_select_tab(tab_id)


func _on_back_pressed() -> void:
	back_requested.emit()
