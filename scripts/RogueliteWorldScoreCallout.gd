extends "res://scripts/RogueliteScoringEventCalloutBase.gd"
class_name RogueliteWorldScoreCallout


func setup(
	mapped_step: Dictionary,
	screen_position: Vector2,
	true_source: Vector2,
	flashes_enabled: bool
) -> void:
	configure_event_callout(
		mapped_step,
		screen_position,
		true_source,
		str(mapped_step.get("title", "SCORE")),
		str(mapped_step.get("effect_text", "")),
		flashes_enabled,
		bool(mapped_step.get("is_subtotal", false))
	)
