extends Control
class_name RogueliteScoreTallyHUD

const UI_FONT := preload("res://assets/fonts/NotJamOldStyle11.ttf")
const GAME_MODE_SCRIPT := preload("res://scripts/GameModeSystem.gd")

const TALLY_PANEL_SIZE := Vector2(680.0, 372.0)
const DIAGNOSTICS_PANEL_SIZE := Vector2(540.0, 620.0)
const VIEWPORT_MARGIN := 24.0
const TALLY_TOP_MARGIN := 66.0
const MAX_HISTORY_ROWS := 4
const REFERENCE_VIEWPORT_SIZE := Vector2(1920.0, 1080.0)
const TRIGGER_TITLE_FONT_SIZE := 28
const TRIGGER_DETAIL_FONT_SIZE := 22
const TRIGGER_CONTEXT_FONT_SIZE := 12
const MIN_TRIGGER_TYPE_SCALE := 0.78
const MAX_TRIGGER_TYPE_SCALE := 1.08
const TRIGGER_TITLE_HEIGHT := 42.0
const TRIGGER_GLOW_PEAK_DURATION := 0.10
const TRIGGER_GLOW_FADE_DURATION := 0.24
const TRIGGER_SCALE_UP_DURATION := 0.11
const TRIGGER_SCALE_SETTLE_DURATION := 0.20

const GOLD_COLOR := Color("f0ca68")
const HAUL_COLOR := Color("f2c45f")
const MULT_COLOR := Color("87ded1")
const XMULT_COLOR := Color("d9a2ff")
const SCORE_COLOR := Color("fff0a8")
const TEXT_COLOR := Color("e2dcc8")
const MUTED_COLOR := Color("aaa596")
const WARNING_COLOR := Color("ef8477")

var tally_panel: PanelContainer
var heading_label: Label
var warning_label: Label
var haul_value_label: Label
var mult_value_label: Label
var score_value_label: Label
var trigger_title_holder: Control
var trigger_glow_label: Label
var trigger_name_label: Label
var trigger_detail_label: Label
var trigger_context_label: Label
var history_label: Label
var comparison_label: Label
var hint_label: Label

var diagnostics_panel: PanelContainer
var diagnostics_label: Label

var trigger_history: Array[String] = []
var history_enabled := true
var pulse_tween_by_target: Dictionary = {}
var trigger_title_tween: Tween
var trigger_glow_state := "idle"
var current_trigger_font_size := TRIGGER_TITLE_FONT_SIZE
var tally_mode_id: String = GAME_MODE_SCRIPT.MODE_ROGUELITE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 64
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_diagnostics_panel()
	_layout_panels()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panels()


func begin_tally(
	score_result: Dictionary,
	replay_mode: bool,
	show_history: bool,
	show_detailed_panel: bool = true
) -> void:
	tally_mode_id = str(score_result.get("mode_id", GAME_MODE_SCRIPT.MODE_ROGUELITE))
	history_enabled = show_history
	trigger_history.clear()
	_kill_pulse_tweens()
	if not show_detailed_panel:
		return
	_ensure_tally_panel()
	heading_label.text = "SHOT RESOLUTION - REPLAY" if replay_mode else "SHOT RESOLUTION"
	warning_label.visible = false
	warning_label.text = ""
	comparison_label.visible = false
	comparison_label.text = ""
	history_label.visible = history_enabled
	history_label.text = ""
	hint_label.text = "Hold Left Mouse, Space, or Enter to hasten"
	set_display_values(0.0, 1.0, 0.0)
	var origin_label: String = "SHOT LAB" if tally_mode_id == GAME_MODE_SCRIPT.MODE_SHOT_LAB else "THE LONG SINK"
	set_trigger(origin_label, "HAUL x MULT", "A new reckoning of the shot", "neutral", false, false)

	var diagnostics: Dictionary = _dictionary_value(score_result, "diagnostics")
	var warnings: Array = _array_value(score_result, "warnings")
	if not bool(diagnostics.get("input_valid", true)) or not warnings.is_empty():
		warning_label.visible = true
		warning_label.text = "RESOLUTION WARNING - SAFE RESOLVED VALUES RETAINED"

	tally_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	tally_panel.scale = Vector2(0.97, 0.97)
	tally_panel.pivot_offset = TALLY_PANEL_SIZE * 0.5
	tally_panel.visible = show_detailed_panel
	_layout_panels()


func set_entrance_progress(progress: float) -> void:
	if tally_panel == null:
		return
	var eased: float = _ease_out_cubic(clampf(progress, 0.0, 1.0))
	tally_panel.modulate.a = eased
	tally_panel.scale = Vector2.ONE * lerpf(0.97, 1.0, eased)


func set_exit_progress(progress: float) -> void:
	if tally_panel == null:
		return
	var clamped: float = clampf(progress, 0.0, 1.0)
	tally_panel.modulate.a = 1.0 - clamped
	tally_panel.scale = Vector2.ONE * lerpf(1.0, 0.985, clamped)


func finish_tally() -> void:
	_kill_pulse_tweens()
	if tally_panel == null:
		return
	tally_panel.visible = false
	tally_panel.modulate = Color.WHITE
	tally_panel.scale = Vector2.ONE


func set_display_values(haul: float, mult: float, score: float) -> void:
	if haul_value_label == null or mult_value_label == null or score_value_label == null:
		return
	haul_value_label.text = _format_integer_like(haul)
	mult_value_label.text = _format_number(mult)
	score_value_label.text = _format_integer_like(score)


func set_trigger(
	display_name: String,
	detail: String,
	context: String,
	visual_kind: String,
	append_history: bool = true,
	animate_title: bool = true
) -> void:
	if trigger_name_label == null or trigger_glow_label == null:
		return
	var title_text: String = display_name.to_upper()
	trigger_name_label.text = title_text
	trigger_glow_label.text = title_text
	trigger_detail_label.text = detail
	trigger_context_label.text = context
	var color: Color = _get_visual_kind_color(visual_kind)
	trigger_name_label.add_theme_color_override("font_color", color)
	trigger_detail_label.add_theme_color_override("font_color", color)
	trigger_glow_label.add_theme_color_override("font_color", color.lightened(0.28))
	trigger_glow_label.add_theme_color_override("font_outline_color", color.lightened(0.42))
	if animate_title:
		_animate_trigger_title(visual_kind)
	else:
		if trigger_title_tween != null and trigger_title_tween.is_valid():
			trigger_title_tween.kill()
		trigger_title_tween = null
		_reset_trigger_glow()

	if append_history and history_enabled:
		var history_entry: String = "%s  %s" % [display_name.to_upper(), detail]
		trigger_history.append(history_entry)
		while trigger_history.size() > MAX_HISTORY_ROWS:
			trigger_history.pop_front()
		history_label.text = "  |  ".join(trigger_history)


func pulse_value(visual_kind: String) -> void:
	if tally_panel == null:
		return
	var target: Label = score_value_label
	var peak_scale: Vector2 = Vector2(1.10, 1.10)
	match visual_kind:
		"haul":
			target = haul_value_label
			peak_scale = Vector2(1.11, 1.11)
		"mult":
			target = mult_value_label
			peak_scale = Vector2(1.12, 1.12)
		"xmult":
			target = mult_value_label
			peak_scale = Vector2(1.22, 1.22)
		"consequence":
			target = trigger_detail_label
			peak_scale = Vector2(1.06, 1.06)
		"final":
			target = score_value_label
			peak_scale = Vector2(1.18, 1.18)

	if target == null:
		return
	var previous_tween: Tween = pulse_tween_by_target.get(target) as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", peak_scale, 0.10)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, 0.17)
	pulse_tween_by_target[target] = tween
	tween.finished.connect(_on_pulse_tween_finished.bind(target, tween))


func show_final(
	final_haul: int,
	final_mult: float,
	final_score: int,
	replay_mode: bool,
	comparison: Dictionary = {}
) -> void:
	if tally_panel == null:
		return
	set_display_values(float(final_haul), final_mult, float(final_score))
	var context: String = (
		"Presentation replay - no score applied"
		if replay_mode
		else (
			"Shot Lab Haul x Mult result"
			if tally_mode_id == GAME_MODE_SCRIPT.MODE_SHOT_LAB
			else "The Long Sink's Haul x Mult result"
		)
	)
	set_trigger(
		"Shot Score",
		"%s HAUL x %s MULT" % [_format_integer_like(float(final_haul)), _format_number(final_mult)],
		context,
		"final",
		false,
		true
	)
	set_comparison(comparison)
	pulse_value("final")


func set_comparison(comparison: Dictionary) -> void:
	if comparison_label == null:
		return
	if comparison.is_empty():
		comparison_label.visible = false
		comparison_label.text = ""
		return
	var predicted: int = int(comparison.get("predicted_score", 0))
	var actual: int = int(comparison.get("actual_score", 0))
	var status: String = str(comparison.get("status", "NOT RUN"))
	comparison_label.text = "PREDICTED %s   ACTUAL %s   PARITY %s" % [predicted, actual, status]
	comparison_label.add_theme_color_override(
		"font_color",
		Color("7dd9a2") if status == "PASS" else (WARNING_COLOR if status == "FAIL" else MUTED_COLOR)
	)
	comparison_label.visible = true


func open_diagnostics(snapshot: Dictionary) -> void:
	diagnostics_panel.visible = true
	_layout_panels()
	set_diagnostics_snapshot(snapshot)


func close_diagnostics() -> void:
	diagnostics_panel.visible = false


func is_diagnostics_open() -> bool:
	return diagnostics_panel != null and diagnostics_panel.visible


func set_diagnostics_snapshot(snapshot: Dictionary) -> void:
	if not is_diagnostics_open() or diagnostics_label == null:
		return
	var transaction_diagnostics_value: Variant = snapshot.get("shot_transaction_diagnostics", {})
	var transaction_diagnostics: Dictionary = (
		transaction_diagnostics_value as Dictionary
		if transaction_diagnostics_value is Dictionary
		else {}
	)
	var last_transaction_value: Variant = transaction_diagnostics.get("last_transaction", {})
	var last_transaction: Dictionary = (
		last_transaction_value as Dictionary
		if last_transaction_value is Dictionary
		else {}
	)
	var legacy_value: Variant = snapshot.get("legacy_presentation", {})
	var legacy: Dictionary = legacy_value as Dictionary if legacy_value is Dictionary else {}
	var payout_value: Variant = snapshot.get("doubloon_payout", {})
	var payout: Dictionary = payout_value as Dictionary if payout_value is Dictionary else {}
	var lines: Array[String] = [
		"HAUL x MULT TALLY DIAGNOSTICS",
		"",
		"Active: %s" % snapshot.get("presenter_active", false),
		"State: %s" % snapshot.get("current_state", "idle"),
		"Step: %d / %d" % [
			int(snapshot.get("current_step_index", -1)) + 1,
			int(snapshot.get("total_step_count", 0)),
		],
		"Playback speed: %.3fx" % float(snapshot.get("playback_speed", 0.375)),
		"Held fast-forward: %.2fx (%.1fx multiplier)" % [
			float(snapshot.get("fast_forward_effective_speed", 1.5)),
			float(snapshot.get("fast_forward_multiplier", 4.0)),
		],
		"Customized speed: %s" % snapshot.get("playback_speed_customized", false),
		"Legacy defaults migrated: %d" % int(snapshot.get("legacy_default_migration_count", 0)),
		"Fast-forward: %s" % snapshot.get("fast_forward_active", false),
		"Instant mode: %s" % snapshot.get("instant_mode", false),
		"Replay mode: %s" % snapshot.get("replay_mode_active", false),
		"Quota applications / duplicate suppressions: %d / %d" % [
			int(snapshot.get("quota_application_count", 0)),
			int(snapshot.get("quota_application_duplicate_suppressions", 0)),
		],
		"Round score displayed / authoritative / quota: %s / %d / %d" % [
			_format_number(float(snapshot.get("displayed_round_score", 0.0))),
			int(snapshot.get("current_round_score", 0)),
			int(snapshot.get("current_quota", 0)),
		],
		"Pending score delta: %d" % int(snapshot.get("pending_score_delta", 0)),
		"Score result pending / presentation active: %s / %s" % [
			snapshot.get("authoritative_score_pending", false),
			snapshot.get("presenter_active", false),
		],
		"Haul x Mult sole authority: %s" % snapshot.get("haul_mult_sole_authority", true),
		"Doubloon-to-quota / legacy bonus paths: %d / %d" % [
			int(snapshot.get("doubloon_to_quota_connections", 0)),
			int(snapshot.get("legacy_quota_bonus_calls", 0)),
		],
		"Shot transaction pending / Hull pending: %s / %d" % [
			snapshot.get("shot_transaction_pending", false),
			int(snapshot.get("pending_hull_damage", 0)),
		],
		"Last transaction: %s | %s" % [
			str(last_transaction.get("transaction_key", "none")),
			str(last_transaction.get("outcome", "not run")),
		],
		"Score before / delta / after: %d / %d / %d" % [
			int(last_transaction.get("score_before", 0)),
			int(last_transaction.get("score_delta", 0)),
			int(last_transaction.get("score_after", 0)),
		],
		"Hull before / after | Shots before / after: %d / %d | %d / %d" % [
			int(last_transaction.get("hull_before", 0)),
			int(last_transaction.get("hull_after", 0)),
			int(last_transaction.get("shots_before", 0)),
			int(last_transaction.get("shots_after", 0)),
		],
		"Transaction state / terminal signals / duplicate suppressions: %d / %d / %d" % [
			int(transaction_diagnostics.get("state_emit_count", 0)),
			int(transaction_diagnostics.get("terminal_signal_count", 0)),
			int(transaction_diagnostics.get("duplicate_transaction_suppressions", 0)),
		],
		"",
		"LEGACY PRESENTATION",
		"Long Sink callouts / feed / popups / scoring audio: %d / %d / %d / %d (expected 0)" % [
			int(legacy.get("legacy_long_sink_callouts_emitted", 0)),
			int(legacy.get("legacy_long_sink_feed_entries_emitted", 0)),
			int(legacy.get("legacy_long_sink_popups_emitted", 0)),
			int(legacy.get("legacy_scoring_audio_emitted", 0)),
		],
		"Legacy Long Sink Doubloon awards: %d (expected 0)" % int(
			legacy.get("legacy_long_sink_doubloon_awards", 0)
		),
		"",
		"DOUBLOON PAYOUT",
		"Model: %s | Shot %d | Attempt %d" % [
			str(payout.get("payout_model", "haul_mult_base_haul_v1")),
			int(payout.get("shot_id", -1)),
			int(payout.get("attempt_id", -1)),
		],
		"Base Haul / scoring balls / derived payout: %d / %d / %d" % [
			int(payout.get("base_haul", 0)),
			int(payout.get("scoring_balls", 0)),
			int(payout.get("derived_payout", 0)),
		],
		"Wallet before / after | applied: %d / %d | %s" % [
			int(payout.get("wallet_before", 0)),
			int(payout.get("wallet_after", 0)),
			payout.get("applied", false),
		],
		"Duplicate suppressed / terminal payout / Shot Lab suppressed: %s / %s / %s" % [
			payout.get("duplicate_suppression", false),
			payout.get("terminal_shot_payout", false),
			payout.get("shot_lab_wallet_mutation_suppressed", false),
		],
		"Application key: %s" % str(payout.get("application_key", "none")),
		"World callouts / mapped / fallbacks: %d / %d / %d" % [
			int(snapshot.get("active_world_callouts", 0)),
			int(snapshot.get("mapped_anchor_count", 0)),
			int(snapshot.get("mapping_fallback_count", 0)),
		],
		"Mapping invalid positions / offscreen clamps: %d / %d" % [
			int(snapshot.get("mapping_invalid_position_count", 0)),
			int(snapshot.get("offscreen_clamp_count", 0)),
		],
		"Final waiting / dismiss layer / method: %s / %s / %s" % [
			snapshot.get("final_result_waiting", false),
			snapshot.get("outside_dismiss_layer_active", false),
			str(snapshot.get("dismissal_method", "none")),
		],
		"Zero indicator / sting count: %s / %d" % [
			snapshot.get("zero_score_indicator_active", false),
			int(snapshot.get("zero_score_sting_count", 0)),
		],
		"",
		"Tick train: %s (%s)" % [
			snapshot.get("tick_train_active", false),
			str(snapshot.get("tick_train_visual_kind", "")),
		],
		"Ticks step / tally / last: %d / %d / %d" % [
			int(snapshot.get("current_step_tick_count", 0)),
			int(snapshot.get("current_tally_tick_count", 0)),
			int(snapshot.get("last_tally_tick_count", 0)),
		],
		"Tick pitch: %.3f (%.3f -> %.3f)" % [
			float(snapshot.get("current_tick_pitch", 1.0)),
			float(snapshot.get("current_tick_start_pitch", 0.9)),
			float(snapshot.get("current_tick_end_pitch", 1.18)),
		],
		"Tick interval / main voices: %.3fs / %d" % [
			float(snapshot.get("current_tick_interval", 0.052)),
			int(snapshot.get("active_tally_tick_voices", 0)),
		],
		"Main / first tick level: %.1f / %.1f dB" % [
			float(snapshot.get("tally_tick_volume_db", -22.0)),
			float(snapshot.get("tally_tick_first_volume_db", -19.5)),
		],
		"Bass: %s | voices %d | level %.1f dB" % [
			snapshot.get("tally_tick_bass_enabled", true),
			int(snapshot.get("active_tally_bass_tick_voices", 0)),
			float(snapshot.get("tally_tick_bass_volume_db", -25.0)),
		],
		"Bass pitch / ratio: %.3f / %.2f" % [
			float(snapshot.get("current_bass_tick_pitch", 0.62)),
			float(snapshot.get("tally_tick_bass_pitch_ratio", 0.62)),
		],
		"Bass density: %s" % str(snapshot.get("tally_tick_bass_density_rule", "")),
		"Tick cap skips / voice reuses: %d / %d" % [
			int(snapshot.get("skipped_ticks_due_voice_cap", 0)),
			int(snapshot.get("tick_voice_reuse_count", 0)),
		],
		"Bass cap skips / landing reuses: %d / %d" % [
			int(snapshot.get("skipped_bass_ticks_due_voice_cap", 0)),
			int(snapshot.get("bass_tick_voice_reuse_count", 0)),
		],
		"Reverb requested / effective / wet: %s / %s / %.2f" % [
			snapshot.get("tally_tick_reverb_requested", true),
			snapshot.get("tally_tick_reverb_enabled", false),
			float(snapshot.get("tally_tick_reverb_wet", 0.11)),
		],
		"Audio buses: %s / %s" % [
			str(snapshot.get("tally_tick_bus_name", "TallyTick")),
			str(snapshot.get("tally_tick_bass_bus_name", "TallyTickBass")),
		],
		"Compressor gain reduction: %s" % str(snapshot.get(
			"tally_compressor_gain_reduction_note",
			"Unavailable"
		)),
		"Trigger font / glow: %d px / %s" % [
			int(snapshot.get("current_trigger_font_size", 0)),
			str(snapshot.get("current_trigger_glow_state", "idle")),
		],
		"",
		"Displayed: Haul %s | Mult %s | Score %s" % [
			_format_number(float(snapshot.get("current_displayed_haul", 0.0))),
			_format_number(float(snapshot.get("current_displayed_mult", 1.0))),
			_format_number(float(snapshot.get("current_displayed_score", 0.0))),
		],
		"Target: Haul %s | Mult %s | Score %s" % [
			_format_number(float(snapshot.get("target_final_haul", 0.0))),
			_format_number(float(snapshot.get("target_final_mult", 1.0))),
			_format_number(float(snapshot.get("target_final_score", 0.0))),
		],
		"",
		"Presentation lock: %s" % snapshot.get("presentation_lock_active", false),
		"Queued follow-up: %s" % str(snapshot.get("queued_follow_up_presentation", "none")),
		"Completed tallies: %d" % int(snapshot.get("completed_tally_count", 0)),
		"Canceled tallies: %d" % int(snapshot.get("canceled_tally_count", 0)),
		"Duplicate starts suppressed: %d" % int(snapshot.get("duplicate_start_suppression_count", 0)),
		"Duplicate completions suppressed: %d" % int(snapshot.get("duplicate_completion_suppression_count", 0)),
		"Last duration: %.3fs" % float(snapshot.get("last_presentation_duration", 0.0)),
		"Last shot / attempt: %d / %d" % [
			int(snapshot.get("last_shot_id", -1)),
			int(snapshot.get("last_attempt_id", -1)),
		],
	]
	var current_step: Dictionary = _dictionary_value(snapshot, "current_step")
	if not current_step.is_empty():
		lines.append("")
		lines.append("CURRENT RESOLUTION STEP")
		lines.append("Phase: %s" % str(current_step.get("phase", "")))
		lines.append("Source: %s / %s" % [
			str(current_step.get("source_id", "")),
			str(current_step.get("display_name", "")),
		])
		lines.append("Haul: %d %+d -> %d" % [
			int(current_step.get("haul_before", 0)),
			int(current_step.get("haul_delta", 0)),
			int(current_step.get("haul_after", 0)),
		])
		lines.append("Mult: %s %s x%s -> %s" % [
			_format_number(float(current_step.get("mult_before", 1.0))),
			_format_signed_number(float(current_step.get("mult_delta", 0.0))),
			_format_number(float(current_step.get("xmult_factor", 1.0))),
			_format_number(float(current_step.get("mult_after", 1.0))),
		])
		lines.append("Score preview: %d" % int(current_step.get("score_preview_after", 0)))
	diagnostics_label.text = "\n".join(lines)


func _build_tally_panel() -> void:
	if tally_panel != null:
		return
	tally_panel = PanelContainer.new()
	tally_panel.name = "TallyPanel"
	tally_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally_panel.custom_minimum_size = TALLY_PANEL_SIZE
	tally_panel.size = TALLY_PANEL_SIZE
	tally_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.018, 0.014, 0.022, 0.92),
		Color(0.92, 0.69, 0.25, 0.86),
		2
	))
	add_child(tally_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 14)
	tally_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	heading_label = _make_label("SHOT RESOLUTION", 17, GOLD_COLOR)
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading_label)
	warning_label = _make_label("", 12, WARNING_COLOR)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.visible = false
	stack.add_child(warning_label)

	var equation := HBoxContainer.new()
	equation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equation.alignment = BoxContainer.ALIGNMENT_CENTER
	equation.add_theme_constant_override("separation", 28)
	stack.add_child(equation)
	var haul_stack: VBoxContainer = _make_value_stack(equation, "HAUL", HAUL_COLOR)
	haul_value_label = haul_stack.get_child(1) as Label
	var multiply_label := _make_label("x", 38, MUTED_COLOR)
	multiply_label.custom_minimum_size = Vector2(48.0, 60.0)
	multiply_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	multiply_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equation.add_child(multiply_label)
	var mult_stack: VBoxContainer = _make_value_stack(equation, "MULT", MULT_COLOR)
	mult_value_label = mult_stack.get_child(1) as Label

	var score_heading := _make_label("SCORE", 14, MUTED_COLOR)
	score_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(score_heading)
	score_value_label = _make_label("0", 42, SCORE_COLOR)
	score_value_label.custom_minimum_size = Vector2(0.0, 48.0)
	score_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(score_value_label)

	var trigger_panel := PanelContainer.new()
	trigger_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trigger_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.045, 0.039, 0.050, 0.88),
		Color(0.72, 0.57, 0.25, 0.52),
		1
	))
	stack.add_child(trigger_panel)
	var trigger_margin := MarginContainer.new()
	trigger_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trigger_margin.add_theme_constant_override("margin_left", 12)
	trigger_margin.add_theme_constant_override("margin_top", 7)
	trigger_margin.add_theme_constant_override("margin_right", 12)
	trigger_margin.add_theme_constant_override("margin_bottom", 7)
	trigger_panel.add_child(trigger_margin)
	var trigger_stack := VBoxContainer.new()
	trigger_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trigger_stack.add_theme_constant_override("separation", 2)
	trigger_margin.add_child(trigger_stack)
	trigger_title_holder = Control.new()
	trigger_title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trigger_title_holder.custom_minimum_size = Vector2(0.0, TRIGGER_TITLE_HEIGHT)
	trigger_title_holder.clip_contents = false
	trigger_stack.add_child(trigger_title_holder)
	trigger_glow_label = _make_label("THE LONG SINK", TRIGGER_TITLE_FONT_SIZE, GOLD_COLOR)
	trigger_glow_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trigger_glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trigger_glow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trigger_glow_label.add_theme_constant_override("outline_size", 7)
	trigger_glow_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	trigger_title_holder.add_child(trigger_glow_label)
	trigger_name_label = _make_label("THE LONG SINK", TRIGGER_TITLE_FONT_SIZE, GOLD_COLOR)
	trigger_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trigger_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trigger_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trigger_title_holder.add_child(trigger_name_label)
	trigger_detail_label = _make_label("HAUL x MULT", TRIGGER_DETAIL_FONT_SIZE, TEXT_COLOR)
	trigger_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trigger_stack.add_child(trigger_detail_label)
	trigger_context_label = _make_label("A new reckoning of the shot", TRIGGER_CONTEXT_FONT_SIZE, MUTED_COLOR)
	trigger_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trigger_context_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	trigger_stack.add_child(trigger_context_label)

	comparison_label = _make_label("", 12, MUTED_COLOR)
	comparison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	comparison_label.visible = false
	stack.add_child(comparison_label)
	history_label = _make_label("", 11, MUTED_COLOR)
	history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(history_label)
	hint_label = _make_label("Hold Left Mouse, Space, or Enter to hasten", 10, Color(0.64, 0.62, 0.57, 0.88))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hint_label)
	tally_panel.visible = false


func _ensure_tally_panel() -> void:
	if tally_panel != null:
		return
	_build_tally_panel()
	_layout_panels()


func _build_diagnostics_panel() -> void:
	diagnostics_panel = PanelContainer.new()
	diagnostics_panel.name = "TallyDiagnosticsPanel"
	diagnostics_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	diagnostics_panel.custom_minimum_size = DIAGNOSTICS_PANEL_SIZE
	diagnostics_panel.size = DIAGNOSTICS_PANEL_SIZE
	diagnostics_panel.z_index = 116
	diagnostics_panel.set_meta("allow_during_score_tally", true)
	diagnostics_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.012, 0.018, 0.022, 0.97),
		Color(0.50, 0.76, 0.69, 0.82),
		2
	))
	add_child(diagnostics_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	diagnostics_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	var title := _make_label("TALLY DIAGNOSTICS", 19, GOLD_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(84.0, 32.0)
	close_button.add_theme_font_override("font", UI_FONT)
	close_button.add_theme_font_size_override("font_size", 13)
	close_button.set_meta("allow_during_score_tally", true)
	close_button.pressed.connect(close_diagnostics)
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	diagnostics_label = _make_label("No tally diagnostics yet.", 13, TEXT_COLOR)
	diagnostics_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diagnostics_label.custom_minimum_size = Vector2(DIAGNOSTICS_PANEL_SIZE.x - 56.0, 0.0)
	diagnostics_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(diagnostics_label)
	diagnostics_panel.visible = false


func _layout_panels() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	_apply_responsive_trigger_typography(viewport_size)
	if tally_panel != null:
		var tally_x: float = (viewport_size.x - TALLY_PANEL_SIZE.x) * 0.5
		var max_x: float = maxf(viewport_size.x - TALLY_PANEL_SIZE.x - VIEWPORT_MARGIN, VIEWPORT_MARGIN)
		tally_x = clampf(tally_x, VIEWPORT_MARGIN, max_x)
		var max_y: float = maxf(viewport_size.y - TALLY_PANEL_SIZE.y - VIEWPORT_MARGIN, VIEWPORT_MARGIN)
		tally_panel.position = Vector2(tally_x, clampf(TALLY_TOP_MARGIN, VIEWPORT_MARGIN, max_y))
		tally_panel.size = TALLY_PANEL_SIZE
	if diagnostics_panel != null:
		var available_size := Vector2(
			maxf(viewport_size.x - VIEWPORT_MARGIN * 2.0, 1.0),
			maxf(viewport_size.y - VIEWPORT_MARGIN * 2.0, 1.0)
		)
		var panel_size := Vector2(
			minf(DIAGNOSTICS_PANEL_SIZE.x, available_size.x),
			minf(DIAGNOSTICS_PANEL_SIZE.y, available_size.y)
		)
		diagnostics_panel.size = panel_size
		diagnostics_panel.position = Vector2(VIEWPORT_MARGIN, (viewport_size.y - panel_size.y) * 0.5)


func _make_value_stack(parent: Container, title_text: String, color: Color) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(210.0, 78.0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(stack)
	var title := _make_label(title_text, 15, color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var value := _make_label("0", 44, color)
	value.custom_minimum_size = Vector2(0.0, 54.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stack.add_child(value)
	return stack


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _make_panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 8
	return style


func get_visual_diagnostics() -> Dictionary:
	return {
		"trigger_font_size": current_trigger_font_size,
		"trigger_glow_state": trigger_glow_state,
	}


func _apply_responsive_trigger_typography(viewport_size: Vector2) -> void:
	if trigger_name_label == null or trigger_glow_label == null:
		return
	var viewport_scale: float = minf(
		viewport_size.x / REFERENCE_VIEWPORT_SIZE.x,
		viewport_size.y / REFERENCE_VIEWPORT_SIZE.y
	)
	viewport_scale = clampf(viewport_scale, MIN_TRIGGER_TYPE_SCALE, MAX_TRIGGER_TYPE_SCALE)
	current_trigger_font_size = maxi(roundi(float(TRIGGER_TITLE_FONT_SIZE) * viewport_scale), 1)
	var detail_font_size: int = maxi(roundi(float(TRIGGER_DETAIL_FONT_SIZE) * viewport_scale), 1)
	var context_font_size: int = maxi(roundi(float(TRIGGER_CONTEXT_FONT_SIZE) * viewport_scale), 1)
	trigger_name_label.add_theme_font_size_override("font_size", current_trigger_font_size)
	trigger_glow_label.add_theme_font_size_override("font_size", current_trigger_font_size)
	trigger_detail_label.add_theme_font_size_override("font_size", detail_font_size)
	trigger_context_label.add_theme_font_size_override("font_size", context_font_size)


func _animate_trigger_title(visual_kind: String) -> void:
	if trigger_title_holder == null or trigger_glow_label == null:
		return
	if trigger_title_tween != null and trigger_title_tween.is_valid():
		trigger_title_tween.kill()
	_reset_trigger_glow()
	var holder_size: Vector2 = trigger_title_holder.size
	if holder_size.x <= 0.0 or holder_size.y <= 0.0:
		holder_size = Vector2(TALLY_PANEL_SIZE.x - 68.0, TRIGGER_TITLE_HEIGHT)
	trigger_title_holder.pivot_offset = holder_size * 0.5
	trigger_title_holder.scale = Vector2(0.92, 0.92)
	var strongest: bool = visual_kind in ["xmult", "final"]
	var glow_alpha: float = 0.96 if strongest else (0.82 if visual_kind == "mult" else 0.72)
	var peak_scale: Vector2 = Vector2(1.08, 1.08) if strongest else Vector2(1.06, 1.06)
	trigger_glow_label.add_theme_constant_override("outline_size", 9 if strongest else 7)
	trigger_glow_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	trigger_glow_state = "active:%s" % visual_kind

	trigger_title_tween = create_tween()
	trigger_title_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	trigger_title_tween.set_parallel(true)
	trigger_title_tween.set_trans(Tween.TRANS_BACK)
	trigger_title_tween.set_ease(Tween.EASE_OUT)
	trigger_title_tween.tween_property(
		trigger_title_holder,
		"scale",
		peak_scale,
		TRIGGER_SCALE_UP_DURATION
	)
	trigger_title_tween.tween_property(
		trigger_glow_label,
		"modulate:a",
		glow_alpha,
		TRIGGER_GLOW_PEAK_DURATION
	)
	trigger_title_tween.chain().set_parallel(true)
	trigger_title_tween.set_trans(Tween.TRANS_QUAD)
	trigger_title_tween.set_ease(Tween.EASE_IN_OUT)
	trigger_title_tween.tween_property(
		trigger_title_holder,
		"scale",
		Vector2.ONE,
		TRIGGER_SCALE_SETTLE_DURATION
	)
	trigger_title_tween.tween_property(
		trigger_glow_label,
		"modulate:a",
		0.0,
		TRIGGER_GLOW_FADE_DURATION
	)
	trigger_title_tween.finished.connect(
		_on_trigger_title_tween_finished.bind(trigger_title_tween)
	)


func _reset_trigger_glow() -> void:
	trigger_glow_state = "idle"
	if trigger_title_holder != null:
		trigger_title_holder.scale = Vector2.ONE
	if trigger_glow_label != null:
		trigger_glow_label.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _on_trigger_title_tween_finished(finished_tween: Tween) -> void:
	if trigger_title_tween != finished_tween:
		return
	trigger_title_tween = null
	_reset_trigger_glow()


func _get_visual_kind_color(visual_kind: String) -> Color:
	match visual_kind:
		"haul":
			return HAUL_COLOR
		"mult":
			return MULT_COLOR
		"xmult":
			return XMULT_COLOR
		"consequence":
			return WARNING_COLOR
		"final":
			return SCORE_COLOR
	return TEXT_COLOR


func _kill_pulse_tweens() -> void:
	if trigger_title_tween != null and trigger_title_tween.is_valid():
		trigger_title_tween.kill()
	trigger_title_tween = null
	_reset_trigger_glow()
	for tween_value in pulse_tween_by_target.values():
		var tween: Tween = tween_value as Tween
		if tween != null and tween.is_valid():
			tween.kill()
	pulse_tween_by_target.clear()
	for label in [haul_value_label, mult_value_label, score_value_label, trigger_detail_label]:
		if label != null:
			label.scale = Vector2.ONE


func _on_pulse_tween_finished(target: Label, tween: Tween) -> void:
	if pulse_tween_by_target.get(target) == tween:
		pulse_tween_by_target.erase(target)


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	var formatted: String = "%.2f" % value
	while formatted.ends_with("0"):
		formatted = formatted.left(formatted.length() - 1)
	if formatted.ends_with("."):
		formatted = formatted.left(formatted.length() - 1)
	return formatted


func _format_integer_like(value: float) -> String:
	return str(int(roundf(value)))


func _format_signed_number(value: float) -> String:
	var prefix: String = "+" if value >= 0.0 else ""
	return prefix + _format_number(value)


func _ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


func _dictionary_value(container: Dictionary, key: String) -> Dictionary:
	var value: Variant = container.get(key, {})
	return value as Dictionary if value is Dictionary else {}


func _array_value(container: Dictionary, key: String) -> Array:
	var value: Variant = container.get(key, [])
	return value as Array if value is Array else []
