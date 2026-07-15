extends RefCounted
class_name AimStagingConfiguration

# AimPreview owns staging behavior. This helper is the shared schema source for
# the schema-driven Dev Options UI and AimPreview's presentation settings.

const USE_STAGED_DEEP_PREDICTION := "use_staged_deep_prediction"
const DEEP_AIM_SETTLE_DELAY_MS := "deep_aim_settle_delay_ms"
const PROGRESSIVE_DEEP_AIM_REVEAL := "progressive_deep_aim_reveal"
const DEEP_AIM_REVEAL_DURATION_MS := "deep_aim_reveal_duration_ms"
const KEEP_STALE_DEEP_AIM_FAINTLY_VISIBLE := "keep_stale_deep_aim_faintly_visible"
const SHOW_STAGING_STATUS := "show_staging_status"


static func get_configuration_schema() -> Array[Dictionary]:
	return [
		{
			"key": USE_STAGED_DEEP_PREDICTION,
			"label": "Use Staged Deep Prediction",
			"type": "bool",
			"default": true,
			"description": "Runs the accurate immediate preview while aim moves, then requests the cloned deep route after aim settles.",
			"on_effect": "Expensive cloned prediction waits for a settled aim state.",
			"off_effect": "Cloned prediction rebuilds immediately for A/B testing.",
			"keywords": ["staged aim", "responsive drag", "deep prediction"],
		},
		{
			"key": DEEP_AIM_SETTLE_DELAY_MS,
			"label": "Deep Aim Settle Delay (ms)",
			"type": "int",
			"minimum": 0,
			"maximum": 1000,
			"step": 5,
			"default": 75,
			"description": "Wait time after the last meaningful aim change before cloned deep prediction starts. This is separate from the reveal duration after prediction finishes.",
			"unit": "milliseconds",
			"low_effect": "Deep paths arrive sooner but are easier to request during brief pauses.",
			"high_effect": "Dragging stays lighter, but deep paths take longer to begin.",
			"keywords": ["settle timer", "aim pause", "request delay"],
		},
		{
			"key": PROGRESSIVE_DEEP_AIM_REVEAL,
			"label": "Progressive Deep Aim Reveal",
			"type": "bool",
			"default": true,
			"description": "Unfurls an accepted deep result by cue continuation and causal depth without rerunning simulation.",
			"on_effect": "Deep paths reveal progressively.",
			"off_effect": "Accepted deep paths appear immediately.",
			"keywords": ["unfurl", "causal depth", "reveal animation"],
		},
		{
			"key": DEEP_AIM_REVEAL_DURATION_MS,
			"label": "Deep Aim Reveal Duration (ms)",
			"type": "int",
			"minimum": 0,
			"maximum": 2000,
			"step": 5,
			"default": 125,
			"description": "How long the completed extended aim route takes to unfold after prediction finishes.",
			"unit": "milliseconds",
			"low_effect": "The entire future appears almost immediately. This is responsive but less theatrical.",
			"high_effect": "The predicted future unfolds more slowly and dramatically, but the player waits longer to see all branches.",
			"keywords": ["reveal speed", "animation duration", "deep path"],
		},
		{
			"key": KEEP_STALE_DEEP_AIM_FAINTLY_VISIBLE,
			"label": "Keep Stale Deep Aim Faintly Visible",
			"type": "bool",
			"default": false,
			"description": "Debug comparison option that retains the previous deep route at very low opacity after aim changes.",
			"on_effect": "The stale route remains faint and is marked stale in Debug Aim Mode.",
			"off_effect": "Old deep geometry hides immediately when aim changes.",
			"keywords": ["stale route", "comparison", "old prediction"],
		},
		{
			"key": SHOW_STAGING_STATUS,
			"label": "Show Staging Status",
			"type": "bool",
			"default": true,
			"description": "Shows immediate/waiting/running/ready staging state in the aim diagnostics.",
			"on_effect": "AIM SIMULATION reports staged prediction status.",
			"off_effect": "Staging still operates, but its verbose status lines are hidden.",
			"keywords": ["staging state", "settle status", "request id"],
		},
	]


static func get_default_configuration() -> Dictionary:
	var defaults: Dictionary = {}
	for definition in get_configuration_schema():
		defaults[str(definition.get("key", ""))] = definition.get("default")
	return defaults


static func normalize_configuration(configuration: Dictionary) -> Dictionary:
	var normalized: Dictionary = get_default_configuration()
	for definition in get_configuration_schema():
		var key: String = str(definition.get("key", ""))
		var value: Variant = configuration.get(key, definition.get("default"))
		match str(definition.get("type", "")):
			"bool":
				normalized[key] = bool(value)
			"int":
				normalized[key] = clampi(
					int(value),
					int(definition.get("minimum", 0)),
					int(definition.get("maximum", 0))
				)
	return normalized
