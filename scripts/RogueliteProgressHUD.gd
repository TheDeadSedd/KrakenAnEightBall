extends Control
class_name RogueliteProgressHUD

signal final_result_dismiss_requested(method: String)

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")

const PANEL_SIZE := Vector2(610.0, 108.0)
const PANEL_TOP_MARGIN := 20.0
const VIEWPORT_MARGIN := 24.0
const FINAL_CARD_SIZE := Vector2(430.0, 168.0)
const PAYOUT_CONFIRMATION_DURATION := 0.92
const PAYOUT_CONFIRMATION_FADE_IN := 0.10
const PAYOUT_CONFIRMATION_FADE_OUT_START := 0.56
const PAYOUT_CONFIRMATION_RISE := 10.0

const GOLD := Color("f0ca68")
const HAUL := Color("f2c45f")
const MULT := Color("87ded1")
const SCORE := Color("fff0a8")
const TEXT := Color("e2dcc8")
const MUTED := Color("aaa596")

var mode_id := GAME_MODE_SCRIPT.MODE_ROGUELITE
var display_enabled := false
var persistent_equation_enabled := true
var persistent_round_bar_enabled := true

var displayed_round_score := 0.0
var authoritative_round_score := 0
var round_quota := 0
var displayed_haul := 0.0
var displayed_mult := 1.0
var displayed_shot_score := 0.0
var last_completed_shot_score := 0
var current_result_active := false
var pending_score_delta := 0
var shot_in_motion := false
var payout_confirmation_active := false
var payout_confirmation_amount := 0
var payout_confirmation_elapsed := 0.0
var payout_confirmation_count := 0

var zero_indicator_active := false
var zero_indicator_reason := "NO HAUL"
var zero_indicator_alpha := 1.0

var final_layer: Control
var final_card: Panel
var final_equation_label: Label
var final_score_label: Label
var final_hint_label: Label
var final_close_button: Button
var final_result_waiting := false
var dismissal_pending := false
var last_dismissal_method := "none"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 62
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_final_result_layer()
	_layout_controls()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if not payout_confirmation_active:
		set_process(false)
		return
	payout_confirmation_elapsed += maxf(delta, 0.0)
	if payout_confirmation_elapsed >= PAYOUT_CONFIRMATION_DURATION:
		_clear_payout_confirmation()
		return
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_controls()
		queue_redraw()


func set_mode(active_mode_id: String, enabled: bool) -> void:
	mode_id = active_mode_id
	display_enabled = enabled
	visible = enabled
	if not enabled:
		clear_presentation("mode_hidden")
	queue_redraw()


func sync_run_snapshot(snapshot: Dictionary, snap_display: bool = false) -> void:
	if mode_id != GAME_MODE_SCRIPT.MODE_ROGUELITE:
		return
	authoritative_round_score = maxi(int(snapshot.get("round_score", authoritative_round_score)), 0)
	round_quota = maxi(int(snapshot.get("round_target", snapshot.get("target", round_quota))), 0)
	if snap_display or not current_result_active:
		displayed_round_score = float(authoritative_round_score)
	queue_redraw()


func set_shot_in_motion(active: bool) -> void:
	shot_in_motion = active
	if active:
		current_result_active = false
		zero_indicator_active = false
		_clear_payout_confirmation()
	queue_redraw()


func begin_result(score_result: Dictionary) -> void:
	shot_in_motion = false
	current_result_active = true
	displayed_haul = 0.0
	displayed_mult = 1.0
	displayed_shot_score = 0.0
	pending_score_delta = maxi(int(score_result.get(
		"round_score_delta_pending",
		score_result.get("round_score_delta_applied", score_result.get("shot_score", 0))
	)), 0)
	if mode_id == GAME_MODE_SCRIPT.MODE_ROGUELITE:
		displayed_round_score = float(maxi(int(score_result.get("round_score_before", authoritative_round_score - pending_score_delta)), 0))
		authoritative_round_score = maxi(int(score_result.get("round_score_after", authoritative_round_score)), 0)
		round_quota = maxi(int(score_result.get("round_quota", round_quota)), 0)
	queue_redraw()


func set_display_values(haul: float, mult: float, score: float) -> void:
	displayed_haul = maxf(haul, 0.0)
	displayed_mult = maxf(mult, 0.0)
	displayed_shot_score = maxf(score, 0.0)
	queue_redraw()


func set_round_fill_progress(score_result: Dictionary, progress: float) -> void:
	if mode_id != GAME_MODE_SCRIPT.MODE_ROGUELITE:
		return
	var from_score: float = float(maxi(int(score_result.get("round_score_before", 0)), 0))
	var to_score: float = float(maxi(int(score_result.get("round_score_after", int(from_score))), 0))
	displayed_round_score = lerpf(from_score, to_score, _ease_out_cubic(progress))
	queue_redraw()


func finish_round_fill(score_result: Dictionary) -> void:
	if mode_id == GAME_MODE_SCRIPT.MODE_ROGUELITE:
		displayed_round_score = float(maxi(int(score_result.get("round_score_after", authoritative_round_score)), 0))
		authoritative_round_score = int(displayed_round_score)
	last_completed_shot_score = maxi(int(score_result.get("shot_score", 0)), 0)
	pending_score_delta = 0
	queue_redraw()


func show_doubloon_payout(score_result: Dictionary) -> void:
	var application_value: Variant = score_result.get("doubloon_payout_application", {})
	if not application_value is Dictionary:
		return
	var application: Dictionary = application_value as Dictionary
	var amount: int = maxi(int(application.get("amount", 0)), 0)
	if not bool(application.get("applied", false)) or amount <= 0:
		return
	payout_confirmation_amount = amount
	payout_confirmation_elapsed = 0.0
	payout_confirmation_active = true
	payout_confirmation_count += 1
	set_process(true)
	queue_redraw()


func show_final_result(score_result: Dictionary) -> void:
	final_equation_label.text = "%s HAUL x %s MULT" % [
		_format_number(float(score_result.get("final_haul", 0))),
		_format_number(float(score_result.get("final_mult", 1.0))),
	]
	final_score_label.text = "SHOT SCORE: %s" % maxi(int(score_result.get("shot_score", 0)), 0)
	final_result_waiting = true
	dismissal_pending = false
	last_dismissal_method = "none"
	final_layer.visible = true
	final_card.visible = true
	_layout_controls()
	final_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	final_card.scale = Vector2(0.94, 0.94)
	final_card.pivot_offset = FINAL_CARD_SIZE * 0.5
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.set_parallel(true)
	tween.tween_property(final_card, "modulate:a", 1.0, 0.14)
	tween.tween_property(final_card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func hide_final_result(method: String = "cleanup") -> void:
	if method not in ["cleanup", "presentation_complete"] or last_dismissal_method == "none":
		last_dismissal_method = method
	final_result_waiting = false
	dismissal_pending = false
	if final_layer != null:
		final_layer.visible = false
	if final_card != null:
		final_card.visible = false
	queue_redraw()


func show_zero_indicator(reason: String = "NO HAUL") -> void:
	zero_indicator_reason = reason if not reason.strip_edges().is_empty() else "NO HAUL"
	zero_indicator_active = true
	zero_indicator_alpha = 1.0
	current_result_active = true
	displayed_haul = 0.0
	displayed_mult = 1.0
	displayed_shot_score = 0.0
	queue_redraw()


func set_zero_indicator_progress(progress: float) -> void:
	var clamped: float = clampf(progress, 0.0, 1.0)
	zero_indicator_alpha = 1.0 if clamped < 0.55 else 1.0 - ((clamped - 0.55) / 0.45)
	queue_redraw()


func hide_zero_indicator() -> void:
	zero_indicator_active = false
	zero_indicator_alpha = 1.0
	queue_redraw()


func finish_result_observation(score_result: Dictionary) -> void:
	last_completed_shot_score = maxi(int(score_result.get("shot_score", 0)), 0)
	current_result_active = false
	pending_score_delta = 0
	if mode_id == GAME_MODE_SCRIPT.MODE_ROGUELITE:
		displayed_round_score = float(authoritative_round_score)
	queue_redraw()


func clear_presentation(_reason: String = "clear") -> void:
	hide_final_result("cleanup")
	hide_zero_indicator()
	_clear_payout_confirmation()
	current_result_active = false
	shot_in_motion = false
	pending_score_delta = 0
	queue_redraw()


func capture_observation() -> Dictionary:
	return {
		"mode_id": mode_id,
		"displayed_round_score": displayed_round_score,
		"authoritative_round_score": authoritative_round_score,
		"round_quota": round_quota,
		"displayed_haul": displayed_haul,
		"displayed_mult": displayed_mult,
		"displayed_shot_score": displayed_shot_score,
		"last_completed_shot_score": last_completed_shot_score,
		"shot_in_motion": shot_in_motion,
		"payout_confirmation_count": payout_confirmation_count,
	}


func restore_observation(state: Dictionary) -> void:
	clear_presentation("rewind_restore")
	mode_id = str(state.get("mode_id", mode_id))
	displayed_round_score = float(state.get("displayed_round_score", 0.0))
	authoritative_round_score = maxi(int(state.get("authoritative_round_score", int(displayed_round_score))), 0)
	round_quota = maxi(int(state.get("round_quota", 0)), 0)
	displayed_haul = float(state.get("displayed_haul", 0.0))
	displayed_mult = float(state.get("displayed_mult", 1.0))
	displayed_shot_score = float(state.get("displayed_shot_score", 0.0))
	last_completed_shot_score = maxi(int(state.get("last_completed_shot_score", 0)), 0)
	shot_in_motion = bool(state.get("shot_in_motion", false))
	payout_confirmation_count = maxi(int(state.get("payout_confirmation_count", 0)), 0)
	queue_redraw()


func get_equation_anchor_screen_position() -> Vector2:
	var panel_rect: Rect2 = _get_panel_rect()
	return Vector2(panel_rect.get_center().x, panel_rect.end.y - 27.0)


func get_diagnostics_snapshot() -> Dictionary:
	return {
		"current_round_score": authoritative_round_score,
		"displayed_round_score": displayed_round_score,
		"current_quota": round_quota,
		"pending_score_delta": pending_score_delta,
		"final_result_waiting": final_result_waiting,
		"outside_dismiss_layer_active": final_layer != null and final_layer.visible,
		"dismissal_method": last_dismissal_method,
		"zero_score_indicator_active": zero_indicator_active,
		"shot_in_motion": shot_in_motion,
		"payout_confirmation_active": payout_confirmation_active,
		"payout_confirmation_amount": payout_confirmation_amount,
		"payout_confirmation_count": payout_confirmation_count,
	}


func _draw() -> void:
	if not display_enabled:
		return
	var panel_rect: Rect2 = _get_panel_rect()
	draw_rect(panel_rect, Color(0.012, 0.015, 0.021, 0.86), true)
	draw_rect(panel_rect, Color(GOLD.r, GOLD.g, GOLD.b, 0.66), false, 2.0)
	var title_y: float = panel_rect.position.y + 21.0
	var center_x: float = panel_rect.get_center().x
	if mode_id == GAME_MODE_SCRIPT.MODE_ROGUELITE and persistent_round_bar_enabled:
		draw_string(UI_FONT, Vector2(panel_rect.position.x + 18.0, title_y), "ROUND SCORE", HORIZONTAL_ALIGNMENT_LEFT, 160.0, 16, GOLD)
		var score_text := "%s / %s" % [int(roundf(displayed_round_score)), round_quota]
		if round_quota > 0 and displayed_round_score > float(round_quota):
			score_text += "  (+%s OVER)" % int(roundf(displayed_round_score - float(round_quota)))
		draw_string(UI_FONT, Vector2(panel_rect.end.x - 212.0, title_y), score_text, HORIZONTAL_ALIGNMENT_RIGHT, 194.0, 16, SCORE)
		var bar_rect := Rect2(panel_rect.position + Vector2(18.0, 31.0), Vector2(panel_rect.size.x - 36.0, 16.0))
		draw_rect(bar_rect, Color(0.05, 0.06, 0.07, 0.92), true)
		var fill_ratio: float = clampf(displayed_round_score / float(maxi(round_quota, 1)), 0.0, 1.0)
		var fill_rect := Rect2(bar_rect.position + Vector2(2.0, 2.0), Vector2((bar_rect.size.x - 4.0) * fill_ratio, bar_rect.size.y - 4.0))
		draw_rect(fill_rect, Color(0.35, 0.82, 0.74, 0.92), true)
	else:
		draw_string(UI_FONT, Vector2(panel_rect.position.x + 18.0, title_y), "TEST SCORE", HORIZONTAL_ALIGNMENT_LEFT, 180.0, 16, GOLD)

	if persistent_equation_enabled:
		if shot_in_motion:
			draw_string(
				UI_FONT,
				Vector2(center_x - 205.0, panel_rect.position.y + 87.0),
				"SHOT IN MOTION",
				HORIZONTAL_ALIGNMENT_CENTER,
				410.0,
				22,
				MULT
			)
			return
		var equation_label: String = "CURRENT SHOT" if current_result_active else "LAST SHOT"
		draw_string(UI_FONT, Vector2(panel_rect.position.x + 18.0, panel_rect.position.y + 69.0), equation_label, HORIZONTAL_ALIGNMENT_LEFT, 138.0, 14, MUTED)
		var equation_score: float = displayed_shot_score if current_result_active else float(last_completed_shot_score)
		var equation: String = "%s HAUL x %s MULT = %s" % [
			_format_number(displayed_haul),
			_format_number(displayed_mult),
			_format_number(equation_score),
		]
		draw_string(UI_FONT, Vector2(center_x - 205.0, panel_rect.position.y + 91.0), equation, HORIZONTAL_ALIGNMENT_CENTER, 410.0, 22, TEXT)

	if zero_indicator_active:
		var viewport_size: Vector2 = get_viewport_rect().size
		var zero_center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.54)
		var zero_color := Color(TEXT.r, TEXT.g, TEXT.b, clampf(zero_indicator_alpha, 0.0, 1.0))
		draw_string(UI_FONT, zero_center + Vector2(-150.0, -6.0), zero_indicator_reason.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 300.0, 32, zero_color)
		draw_string(UI_FONT, zero_center + Vector2(-150.0, 31.0), "0 SCORE", HORIZONTAL_ALIGNMENT_CENTER, 300.0, 22, Color(MUTED.r, MUTED.g, MUTED.b, zero_color.a))

	if payout_confirmation_active and payout_confirmation_amount > 0:
		_draw_payout_confirmation(panel_rect)


func _draw_payout_confirmation(panel_rect: Rect2) -> void:
	var progress: float = clampf(
		payout_confirmation_elapsed / PAYOUT_CONFIRMATION_DURATION,
		0.0,
		1.0
	)
	var alpha: float = 1.0
	if payout_confirmation_elapsed < PAYOUT_CONFIRMATION_FADE_IN:
		alpha = payout_confirmation_elapsed / PAYOUT_CONFIRMATION_FADE_IN
	elif progress > PAYOUT_CONFIRMATION_FADE_OUT_START:
		alpha = 1.0 - (
			(progress - PAYOUT_CONFIRMATION_FADE_OUT_START)
			/ (1.0 - PAYOUT_CONFIRMATION_FADE_OUT_START)
		)
	alpha = clampf(alpha, 0.0, 1.0)
	var rise: float = PAYOUT_CONFIRMATION_RISE * progress
	var text_value: String = "+%d %s" % [
		payout_confirmation_amount,
		"DOUBLOON" if payout_confirmation_amount == 1 else "DOUBLOONS",
	]
	var baseline := Vector2(
		panel_rect.get_center().x - 130.0,
		panel_rect.end.y + 29.0 - rise
	)
	draw_string(
		UI_FONT,
		baseline + Vector2(2.0, 2.0),
		text_value,
		HORIZONTAL_ALIGNMENT_CENTER,
		260.0,
		19,
		Color(0.0, 0.0, 0.0, alpha * 0.82)
	)
	draw_string(
		UI_FONT,
		baseline,
		text_value,
		HORIZONTAL_ALIGNMENT_CENTER,
		260.0,
		19,
		Color(GOLD.r, GOLD.g, GOLD.b, alpha)
	)


func _clear_payout_confirmation() -> void:
	payout_confirmation_active = false
	payout_confirmation_amount = 0
	payout_confirmation_elapsed = 0.0
	set_process(false)
	queue_redraw()


func _build_final_result_layer() -> void:
	final_layer = Control.new()
	final_layer.name = "FinalResultDismissLayer"
	final_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	final_layer.visible = false
	add_child(final_layer)
	final_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	final_layer.gui_input.connect(_on_final_layer_gui_input)

	final_card = Panel.new()
	final_card.name = "FinalResultCard"
	final_card.mouse_filter = Control.MOUSE_FILTER_STOP
	final_card.custom_minimum_size = FINAL_CARD_SIZE
	final_card.size = FINAL_CARD_SIZE
	final_layer.add_child(final_card)
	final_card.gui_input.connect(_on_final_card_gui_input)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.012, 0.014, 0.020, 0.96)
	card_style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.88)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(4)
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	card_style.shadow_size = 12
	final_card.add_theme_stylebox_override("panel", card_style)

	final_equation_label = _make_final_label(24, TEXT)
	final_equation_label.position = Vector2(30.0, 34.0)
	final_equation_label.size = Vector2(FINAL_CARD_SIZE.x - 60.0, 36.0)
	final_card.add_child(final_equation_label)

	final_score_label = _make_final_label(30, SCORE)
	final_score_label.position = Vector2(30.0, 73.0)
	final_score_label.size = Vector2(FINAL_CARD_SIZE.x - 60.0, 42.0)
	final_card.add_child(final_score_label)

	final_hint_label = _make_final_label(14, MUTED)
	final_hint_label.text = "Click outside, press Space, or press Enter"
	final_hint_label.position = Vector2(24.0, 128.0)
	final_hint_label.size = Vector2(FINAL_CARD_SIZE.x - 48.0, 24.0)
	final_card.add_child(final_hint_label)

	final_close_button = Button.new()
	final_close_button.name = "CloseButton"
	final_close_button.text = "X"
	final_close_button.position = Vector2(FINAL_CARD_SIZE.x - 42.0, 10.0)
	final_close_button.size = Vector2(30.0, 28.0)
	final_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	final_close_button.add_theme_font_override("font", UI_FONT)
	final_close_button.add_theme_font_size_override("font_size", 16)
	final_close_button.pressed.connect(_request_final_dismissal.bind("close_button"))
	final_card.add_child(final_close_button)


func _make_final_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _layout_controls() -> void:
	if final_layer != null:
		final_layer.position = Vector2.ZERO
		final_layer.size = get_viewport_rect().size
	if final_card != null:
		var viewport_size: Vector2 = get_viewport_rect().size
		var desired: Vector2 = (viewport_size - FINAL_CARD_SIZE) * 0.5
		final_card.position = Vector2(
			clampf(desired.x, VIEWPORT_MARGIN, maxf(viewport_size.x - FINAL_CARD_SIZE.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN)),
			clampf(desired.y, VIEWPORT_MARGIN, maxf(viewport_size.y - FINAL_CARD_SIZE.y - VIEWPORT_MARGIN, VIEWPORT_MARGIN))
		)
		final_card.size = FINAL_CARD_SIZE


func _get_panel_rect() -> Rect2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var width: float = minf(PANEL_SIZE.x, maxf(viewport_size.x - VIEWPORT_MARGIN * 2.0, 320.0))
	return Rect2(Vector2((viewport_size.x - width) * 0.5, PANEL_TOP_MARGIN), Vector2(width, PANEL_SIZE.y))


func _on_final_layer_gui_input(event: InputEvent) -> void:
	if not final_result_waiting or dismissal_pending:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			accept_event()
			_request_final_dismissal("outside_click")


func _on_final_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()


func _request_final_dismissal(method: String) -> void:
	if not final_result_waiting or dismissal_pending:
		return
	dismissal_pending = true
	last_dismissal_method = method
	final_result_dismiss_requested.emit(method)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.2f" % value


func _ease_out_cubic(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)
