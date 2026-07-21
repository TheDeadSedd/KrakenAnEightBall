extends "res://scripts/RogueliteScoringEventCalloutBase.gd"
class_name RogueliteLiveScoringCallout


func setup(cue: Dictionary, center: Vector2, true_source: Vector2) -> void:
	var display_cue: Dictionary = cue.duplicate(true)
	var resolved_title: String = _resolve_live_title(display_cue)
	configure_event_callout(
		display_cue,
		center,
		true_source,
		resolved_title,
		"",
		true,
		false
	)
	var event_type: String = str(display_cue.get("event_type", ""))
	if event_type == "cue_recontact_milestone":
		accent_color = Color("fff0a8")
		_apply_label_style()
		queue_redraw()
	elif event_type == "object_ball_tap_milestone":
		accent_color = Color("87ded1")
		_apply_label_style()
		queue_redraw()


func _resolve_live_title(cue: Dictionary) -> String:
	var event_type: String = str(cue.get("event_type", ""))
	var display_tier: String = str(cue.get("display_tier", ""))
	var ordinal: int = maxi(int(cue.get("tap_ordinal", 0)), 0)
	if event_type == "cue_recontact_milestone":
		ordinal = maxi(int(cue.get("cue_strike_ordinal", ordinal)), 2)
		if display_tier == "double_tap" or ordinal == 2:
			return "DOUBLE TAP!"
		if display_tier == "triple_tap" or ordinal == 3:
			return "TRIPLE TAP!"
		return "TAP x%d!" % ordinal
	if event_type == "object_ball_tap_milestone":
		ordinal = maxi(int(cue.get("unique_contact_ordinal", ordinal)), 1)
		if display_tier == "ball_tap" or ordinal == 1:
			return "BALL TAP!"
		return "BALL TAP x%d!" % ordinal
	return str(cue.get("title", ""))
