extends RefCounted
class_name EventMetadata

const EVENT_POCKET_STREAK_X3 := "POCKET_STREAK_X3"

const EVENT_DATA := {
	ShotEventSystem.EVENT_BANK: {
		"label": "BANK",
		"description": "Sink a ball after a rail contact.",
	},
	ShotEventSystem.EVENT_DOUBLE_BANK: {
		"label": "DOUBLE BANK",
		"description": "Sink a ball after two rail contacts.",
	},
	ShotEventSystem.EVENT_LONG_HAUL: {
		"label": "LONG HAUL",
		"description": "Sink a ball after it travels a long table route.",
	},
	ShotEventSystem.EVENT_POWER_SINK: {
		"label": "POWER SINK",
		"description": "Sink a ball while it is moving fast.",
	},
	EVENT_POCKET_STREAK_X3: {
		"label": "POCKET STREAK X3",
		"description": "Sink three object balls into the same pocket during one shot.",
	},
	ShotEventSystem.EVENT_POWDER_ROUTE: {
		"label": "POWDER ROUTE",
		"description": "Sink a ball after Powder Keg force influences its route.",
	},
	ShotEventSystem.EVENT_CANNON_CHAIN: {
		"label": "CANNON CHAIN",
		"description": "Sink a ball after Cannon Ball chaos carries through a chain route.",
	},
	ShotEventSystem.EVENT_TREASURE_SNARE: {
		"label": "TREASURE SNARE",
		"description": "Sink a ball after Treasure's aim-line panic influences the route.",
	},
	ShotEventSystem.EVENT_KRAKEN_CURRENT: {
		"label": "KRAKEN CURRENT",
		"description": "Sink a ball after Wayfinder Current guides or transfers cursed momentum.",
	},
	ShotEventSystem.EVENT_LAST_GASP: {
		"label": "LAST GASP",
		"description": "Sink a ball while it is barely moving.",
	},
	ShotEventSystem.EVENT_SPLIT_THE_LOOT: {
		"label": "SPLIT THE LOOT",
		"description": "Sink several balls into different pockets during one shot.",
	},
}


static func get_event_metadata(event_id: String) -> Dictionary:
	if EVENT_DATA.has(event_id):
		return (EVENT_DATA[event_id] as Dictionary).duplicate(true)

	return {
		"label": event_id.replace("_", " ").capitalize(),
		"description": "Complete this requested scoring feat.",
	}


static func get_event_label(event_id: String) -> String:
	return str(get_event_metadata(event_id).get("label", event_id))


static func get_event_description(event_id: String) -> String:
	return str(get_event_metadata(event_id).get("description", "Complete this requested scoring feat."))
