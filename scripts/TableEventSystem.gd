extends Node
class_name TableEventSystem

signal meter_changed(progress: int, threshold: int, percent: float, pending: bool, ready: bool)
signal progress_advanced(amount: int, shot_total: int)
signal pending_event_changed(pending: bool, ready: bool)
signal offers_changed(offers: Array)
signal status_changed(text: String)
signal event_purchased(event_id: String, cost: int)
signal event_purchase_blocked(reason: String)
signal offer_rerolled(offer_index: int, previous_event_id: String, new_event_id: String, oath_id: String)
signal intervention_executed(event_id: String, debug_trigger: bool)
signal contraband_found(kind: String)

# Naming model:
# - Table Event is the internal architecture/system name.
# - Kraken Intervention is the player-facing meter/menu name.
# - Omen is the player-facing offer/rarity flavor.
# ScoreSystem awards Doubloons; SpawnSystem performs event consequences.
const EVENT_LOOSE_CARGO := "loose_cargo"
const EVENT_CHEAP_CARGO := "cheap_cargo"
const EVENT_POWDER_CACHE := "powder_cache"
const EVENT_WAYFINDERS_FAVOR := "wayfinders_favor"
const EVENT_CANNON_WARNING := "cannon_warning"
const EVENT_BROADSIDE_ATTACK := "broadside_attack"
const EVENT_WAYFINDER_CURRENT := "wayfinder_current"
const OFFER_SLOT_COUNT := 3
const OFFER_RNG_SEED := 1742026
const CARGO_STOWAWAY_RNG_SEED := 580813
const EMPTY_OFFER_ID := ""
const CANNON_WARNING_BALL_COUNT := 1
const WAYFINDER_CURRENT_BALL_COUNT := 2
const BROADSIDE_PHASE_NONE := 0
const BROADSIDE_PHASE_WARNING := 1
const BROADSIDE_PHASE_CANNON := 2
const CARGO_TREASURE_FOUND_MESSAGE := "Something glittered in the cargo..."
const LOOSE_CARGO_CONTRABAND_FOUND_MESSAGES := [
	"Contraband found in the hold...",
	"Something illegal crawled out of the cargo.",
	"The cargo manifest lied.",
	"This shipment was cursed.",
]
const LOOSE_CARGO_CONTRABAND_TABLE := [
	{"kind": SpawnSystem.CARGO_REPLACEMENT_WAYFINDER, "weight": 50},
	{"kind": SpawnSystem.CARGO_REPLACEMENT_POWDER_KEG, "weight": 30},
	{"kind": SpawnSystem.CARGO_REPLACEMENT_TREASURE, "weight": 15},
	{"kind": SpawnSystem.CARGO_REPLACEMENT_CANNON, "weight": 4},
	{"kind": SpawnSystem.CARGO_REPLACEMENT_EMBEZZLER, "weight": 1},
]
const LOOSE_CARGO_CONTRABAND_FALLBACK_KINDS := [
	SpawnSystem.CARGO_REPLACEMENT_TREASURE,
	SpawnSystem.CARGO_REPLACEMENT_WAYFINDER,
]
const CUE_MODIFIER_LOOSE_CARGO_CONTRABAND_CHANCE_BONUS := "loose_cargo_contraband_chance_bonus"
const DEBUG_LOOSE_CARGO_CONTRABAND_RANDOM := "random"
const DEBUG_LOOSE_CARGO_CONTRABAND_KINDS := [
	DEBUG_LOOSE_CARGO_CONTRABAND_RANDOM,
	SpawnSystem.CARGO_REPLACEMENT_WAYFINDER,
	SpawnSystem.CARGO_REPLACEMENT_POWDER_KEG,
	SpawnSystem.CARGO_REPLACEMENT_TREASURE,
	SpawnSystem.CARGO_REPLACEMENT_CANNON,
	SpawnSystem.CARGO_REPLACEMENT_EMBEZZLER,
]
const EVENT_EARNED_MESSAGES := [
	"The table offers a choice...",
	"The Kraken opens the ledger.",
	"Kraken Intervention is ready.",
	"The Quartermaster smells opportunity.",
]
const EVENT_POOL := [
	EVENT_LOOSE_CARGO,
	EVENT_CHEAP_CARGO,
	EVENT_POWDER_CACHE,
	EVENT_WAYFINDERS_FAVOR,
	EVENT_CANNON_WARNING,
	EVENT_BROADSIDE_ATTACK,
	EVENT_WAYFINDER_CURRENT,
]
const EVENT_DATA := {
	"loose_cargo": {
		"id": EVENT_LOOSE_CARGO,
		"name": "Loose Cargo",
		"description": "Drop 10 regular object balls onto the table.",
		"flavor": "A cargo net snaps. The table gets crowded.",
		"icon_key": "plain_object_ball",
		"rarity": "Common",
		"weight": 8,
	},
	"cheap_cargo": {
		"id": EVENT_CHEAP_CARGO,
		"name": "Cheap Cargo",
		"description": "Drop 5 regular object balls onto the table.",
		"flavor": "A smaller crate splits open.",
		"icon_key": "plain_object_ball",
		"rarity": "Common",
		"weight": 10,
	},
	"powder_cache": {
		"id": EVENT_POWDER_CACHE,
		"name": "Powder Cache",
		"description": "Drop 3 Powder Kegs onto the table.",
		"flavor": "Someone stored the fireworks badly.",
		"icon_key": "powder_keg_ball",
		"rarity": "Uncommon",
		"weight": 4,
	},
	"wayfinders_favor": {
		"id": EVENT_WAYFINDERS_FAVOR,
		"name": "Wayfinder's Favor",
		"description": "Drop 2 Wayfinder Balls onto the table.",
		"flavor": "The compass stones start whispering.",
		"icon_key": "wayfinder_ball",
		"rarity": "Uncommon",
		"weight": 5,
	},
	"cannon_warning": {
		"id": EVENT_CANNON_WARNING,
		"name": "Cannon Warning",
		"description": "Drop one heavy Cannon Ball onto the table.",
		"flavor": "A future problem rolls aboard.",
		"icon_key": "cannon_ball",
		"rarity": "Rare",
		"weight": 2,
	},
	"broadside_attack": {
		"id": EVENT_BROADSIDE_ATTACK,
		"name": "Broadside Attack",
		"description": "Powder Kegs fall in lanes. Cannon Balls follow.",
		"flavor": "A gun deck answers the deep.",
		"icon_key": "cannon_ball",
		"rarity": "Rare",
		"weight": 1,
	},
	"wayfinder_current": {
		"id": EVENT_WAYFINDER_CURRENT,
		"name": "Wayfinder Current",
		"description": "Two Wayfinders drop. Nearby balls are swept into guided motion.",
		"flavor": "Compass stones drag the tide sideways.",
		"icon_key": "wayfinder_ball",
		"rarity": "Rare",
		"weight": 3,
	},
}

@export var enabled := true
@export var disable_automatic_ball_drops := true
@export_range(1, 9999, 1) var shot_doubloon_threshold := 30
@export_range(0, 9999, 1) var cheap_cargo_cost := 20
@export_range(1, 50, 1) var cheap_cargo_ball_count := 5
@export_range(0.0, 1.0, 0.01) var cheap_cargo_treasure_chance := 0.05
@export_range(0, 9999, 1) var loose_cargo_cost := 40
@export_range(1, 50, 1) var loose_cargo_ball_count := 10
@export_range(0.0, 1.0, 0.001) var loose_cargo_contraband_chance := 0.01
@export_range(0.0, 1.0, 0.01) var loose_cargo_treasure_chance := 0.10
@export_range(0, 9999, 1) var wayfinders_favor_cost := 55
@export_range(1, 8, 1) var wayfinders_favor_ball_count := 2
@export_range(0, 9999, 1) var powder_cache_cost := 75
@export_range(1, 12, 1) var powder_cache_ball_count := 3
@export_range(0, 9999, 1) var cannon_warning_cost := 90
@export_range(0, 9999, 1) var broadside_attack_cost := 140
@export_range(0, 9999, 1) var wayfinder_current_cost := 120
@export_range(3, 5, 1) var broadside_powder_keg_count := 4
@export_range(2, 4, 1) var broadside_cannon_ball_count := 3
@export_range(0.1, 1.0, 0.05) var broadside_warning_delay := 0.35
@export_range(0.1, 2.5, 0.05) var broadside_stage_delay := 0.75
@export_range(80.0, 900.0, 10.0) var broadside_cannon_launch_speed := 420.0

var table
var shot_active := false
var current_shot_doubloons := 0
var pending_event_available := false
var pending_event_ready := false
var event_menu_open := false
var active_offer_ids: Array = []
var offer_rng := RandomNumberGenerator.new()
var cargo_stowaway_rng := RandomNumberGenerator.new()

var total_tracked_doubloons := 0
var pending_events_earned := 0
var pending_events_readied := 0
var purchased_events := 0
var denied_purchases := 0
var offer_oath_rerolls := 0
var denied_offer_oath_rerolls := 0
var offers_generated := 0
var ignored_awards_while_pending := 0
var last_award_amount := 0
var last_purchase_event_id := ""
var last_purchase_cost := 0
var last_blocker_reason := ""
var event_earned_message_index := 0
var broadside_delay_remaining := 0.0
var broadside_phase := BROADSIDE_PHASE_NONE
var broadside_pending_powder_positions: Array[Vector2] = []
var broadside_sequences_started := 0
var wayfinder_current_sequences_started := 0
var cargo_treasure_stowaways_found := 0
var last_cargo_treasure_event_id := ""
var last_cargo_treasure_roll := 1.0
var last_cargo_treasure_replacement_index := -1
var loose_cargo_contraband_stowaways_found := 0
var last_loose_cargo_contraband_roll := 1.0
var last_loose_cargo_contraband_weight_roll := 0
var last_loose_cargo_contraband_replacement_index := -1
var last_loose_cargo_contraband_replacement_kind := ""
var debug_force_loose_cargo_contraband := false
var debug_loose_cargo_contraband_kind := DEBUG_LOOSE_CARGO_CONTRABAND_RANDOM
var cue_modifier_snapshot: Dictionary = {}


func setup(table_ref) -> void:
	table = table_ref
	offer_rng.seed = OFFER_RNG_SEED
	cargo_stowaway_rng.seed = CARGO_STOWAWAY_RNG_SEED
	active_offer_ids.clear()
	set_process(false)
	_emit_state()


func _process(delta: float) -> void:
	if broadside_phase == BROADSIDE_PHASE_NONE or broadside_delay_remaining <= 0.0:
		set_process(false)
		return

	broadside_delay_remaining = maxf(broadside_delay_remaining - delta, 0.0)
	if broadside_delay_remaining > 0.0:
		return

	match broadside_phase:
		BROADSIDE_PHASE_WARNING:
			_queue_broadside_powder_stage()
		BROADSIDE_PHASE_CANNON:
			_queue_broadside_cannon_stage()
			broadside_phase = BROADSIDE_PHASE_NONE
			set_process(false)


func should_disable_automatic_ball_drops() -> bool:
	return enabled and disable_automatic_ball_drops


func start_shot() -> void:
	shot_active = true
	pending_event_ready = false
	event_menu_open = false
	if not pending_event_available:
		current_shot_doubloons = 0
	_emit_state()


func finish_shot() -> void:
	shot_active = false
	_emit_state()


func handle_cue_control_regained() -> void:
	if not enabled or not pending_event_available:
		return
	if pending_event_ready:
		_emit_state()
		return

	pending_event_ready = true
	pending_events_readied += 1
	status_changed.emit("Kraken Intervention is ready.")
	_emit_state()


func handle_doubloons_awarded(amount: int, _new_total: int = 0) -> void:
	if not enabled or amount <= 0 or not shot_active:
		return

	if pending_event_available:
		ignored_awards_while_pending += amount
		return

	last_award_amount = amount
	current_shot_doubloons += amount
	total_tracked_doubloons += amount
	progress_advanced.emit(amount, current_shot_doubloons)
	if current_shot_doubloons >= shot_doubloon_threshold:
		current_shot_doubloons = shot_doubloon_threshold
		pending_event_available = true
		pending_event_ready = false
		pending_events_earned += 1
		_generate_event_offers()
		status_changed.emit(_get_next_event_earned_message())
	_emit_state()


func set_event_menu_open(is_open: bool) -> void:
	if event_menu_open == is_open:
		return
	event_menu_open = is_open
	_emit_state()


func is_event_menu_open() -> bool:
	return event_menu_open


func is_event_icon_clickable() -> bool:
	return enabled and pending_event_available and pending_event_ready and not event_menu_open


func debug_trigger_wayfinder_current() -> void:
	_execute_wayfinder_current()
	intervention_executed.emit(EVENT_WAYFINDER_CURRENT, true)
	status_changed.emit("Debug Wayfinder Current triggered.")


func debug_trigger_broadside_attack() -> void:
	_execute_broadside_attack()
	intervention_executed.emit(EVENT_BROADSIDE_ATTACK, true)
	status_changed.emit("Debug Broadside Attack triggered.")


func set_debug_force_loose_cargo_contraband(enabled: bool) -> void:
	debug_force_loose_cargo_contraband = enabled
	_emit_state()


func set_debug_loose_cargo_contraband_kind(kind: String) -> void:
	debug_loose_cargo_contraband_kind = _sanitize_debug_loose_cargo_contraband_kind(kind)
	_emit_state()


func set_cue_modifier_snapshot(snapshot: Dictionary) -> void:
	cue_modifier_snapshot = snapshot.duplicate(true)
	_emit_state()


func request_purchase_offer(offer_index: int) -> bool:
	var blocker: String = _get_offer_purchase_blocker(offer_index)
	if not blocker.is_empty():
		denied_purchases += 1
		last_blocker_reason = blocker
		status_changed.emit(blocker)
		event_purchase_blocked.emit(blocker)
		_emit_state()
		return false

	var event_id: String = str(active_offer_ids[offer_index])
	var cost: int = _get_event_cost(event_id)
	if not table.score_system.try_spend_doubloons(cost):
		denied_purchases += 1
		last_blocker_reason = "Not enough Doubloons"
		status_changed.emit(last_blocker_reason)
		event_purchase_blocked.emit(last_blocker_reason)
		_emit_state()
		return false

	var event_status_messages: Array = _execute_event(event_id)
	purchased_events += 1
	last_purchase_event_id = event_id
	last_purchase_cost = cost
	last_blocker_reason = ""
	_clear_pending_event()
	status_changed.emit(_get_event_purchase_message(event_id, cost))
	for status_message_value in event_status_messages:
		var status_message := str(status_message_value)
		if not status_message.is_empty():
			status_changed.emit(status_message)
	event_purchased.emit(event_id, cost)
	intervention_executed.emit(event_id, false)
	_emit_state()
	return true


func request_reroll_offer_with_oath(offer_index: int, oath_id: String = OathSystem.OATH_OF_URGENCY) -> bool:
	var blocker := _get_offer_reroll_blocker(offer_index, oath_id)
	if not blocker.is_empty():
		denied_offer_oath_rerolls += 1
		last_blocker_reason = blocker
		status_changed.emit(blocker)
		event_purchase_blocked.emit(blocker)
		_emit_state()
		return false

	_ensure_offer_slots()
	var previous_event_id := str(active_offer_ids[offer_index])
	var replacement_event_id := _pick_reroll_replacement_event_id(offer_index)
	if replacement_event_id.is_empty():
		denied_offer_oath_rerolls += 1
		last_blocker_reason = "No replacement omen available"
		status_changed.emit(last_blocker_reason)
		event_purchase_blocked.emit(last_blocker_reason)
		_emit_state()
		return false

	if not table.oath_system.activate_oath(oath_id):
		denied_offer_oath_rerolls += 1
		last_blocker_reason = table.oath_system.get_oath_activation_blocker(oath_id)
		status_changed.emit(last_blocker_reason)
		event_purchase_blocked.emit(last_blocker_reason)
		_emit_state()
		return false

	active_offer_ids[offer_index] = replacement_event_id
	offer_oath_rerolls += 1
	offers_generated += 1
	last_blocker_reason = ""
	offer_rerolled.emit(offer_index, previous_event_id, replacement_event_id, oath_id)
	status_changed.emit("One omen is cast aside. %s replaces %s." % [
		_get_event_name(replacement_event_id),
		_get_event_name(previous_event_id),
	])
	_emit_state()
	return true


func get_event_offers_snapshot() -> Array:
	_ensure_offer_slots()
	var offers: Array = []
	for offer_index in range(OFFER_SLOT_COUNT):
		var event_id: String = str(active_offer_ids[offer_index])
		offers.append(_make_offer_snapshot(event_id, offer_index))
	return offers


func get_event_display_name(event_id: String) -> String:
	return _get_event_name(event_id)


func get_loose_cargo_contraband_chance_snapshot() -> Dictionary:
	var base_chance := _get_base_loose_cargo_contraband_chance()
	var cue_bonus := _get_loose_cargo_contraband_cue_bonus()
	var final_chance := _get_effective_loose_cargo_contraband_chance()
	return {
		"base_chance": base_chance,
		"cue_bonus": cue_bonus,
		"final_chance": final_chance,
		"active_cue_modifiers_summary": _get_active_cue_modifier_summary(),
	}


func get_debug_snapshot() -> Dictionary:
	var contraband_chance_snapshot := get_loose_cargo_contraband_chance_snapshot()
	return {
		"enabled": enabled,
		"automatic_ball_drops_gated": should_disable_automatic_ball_drops(),
		"shot_active": shot_active,
		"shot_progress": _get_meter_progress(),
		"shot_threshold": shot_doubloon_threshold,
		"progress_percent": _get_progress_percent(),
		"pending_event_available": pending_event_available,
		"pending_event_ready": pending_event_ready,
		"event_menu_open": event_menu_open,
		"active_offer_ids": active_offer_ids.duplicate(),
		"last_award_amount": last_award_amount,
		"total_tracked_doubloons": total_tracked_doubloons,
		"pending_events_earned": pending_events_earned,
		"pending_events_readied": pending_events_readied,
		"purchased_events": purchased_events,
		"denied_purchases": denied_purchases,
		"offer_oath_rerolls": offer_oath_rerolls,
		"denied_offer_oath_rerolls": denied_offer_oath_rerolls,
		"offers_generated": offers_generated,
		"ignored_awards_while_pending": ignored_awards_while_pending,
		"last_purchase_event_id": last_purchase_event_id,
		"last_purchase_cost": last_purchase_cost,
		"last_blocker_reason": last_blocker_reason,
		"cheap_cargo_cost": cheap_cargo_cost,
		"cheap_cargo_ball_count": cheap_cargo_ball_count,
		"cheap_cargo_treasure_chance": cheap_cargo_treasure_chance,
		"loose_cargo_cost": loose_cargo_cost,
		"loose_cargo_ball_count": loose_cargo_ball_count,
		"loose_cargo_contraband_chance": loose_cargo_contraband_chance,
		"loose_cargo_contraband_base_chance": float(contraband_chance_snapshot.get("base_chance", 0.0)),
		"loose_cargo_contraband_cue_bonus": float(contraband_chance_snapshot.get("cue_bonus", 0.0)),
		"loose_cargo_contraband_final_chance": float(contraband_chance_snapshot.get("final_chance", 0.0)),
		"active_cue_modifiers_summary": str(contraband_chance_snapshot.get("active_cue_modifiers_summary", "None")),
		"loose_cargo_treasure_chance": loose_cargo_treasure_chance,
		"cargo_treasure_stowaways_found": cargo_treasure_stowaways_found,
		"last_cargo_treasure_event_id": last_cargo_treasure_event_id,
		"last_cargo_treasure_roll": last_cargo_treasure_roll,
		"last_cargo_treasure_replacement_index": last_cargo_treasure_replacement_index,
		"loose_cargo_contraband_stowaways_found": loose_cargo_contraband_stowaways_found,
		"last_loose_cargo_contraband_roll": last_loose_cargo_contraband_roll,
		"last_loose_cargo_contraband_weight_roll": last_loose_cargo_contraband_weight_roll,
		"last_loose_cargo_contraband_replacement_index": last_loose_cargo_contraband_replacement_index,
		"last_loose_cargo_contraband_replacement_kind": last_loose_cargo_contraband_replacement_kind,
		"debug_force_loose_cargo_contraband": debug_force_loose_cargo_contraband,
		"debug_loose_cargo_contraband_kind": debug_loose_cargo_contraband_kind,
		"wayfinders_favor_cost": wayfinders_favor_cost,
		"wayfinders_favor_ball_count": wayfinders_favor_ball_count,
		"powder_cache_cost": powder_cache_cost,
		"powder_cache_ball_count": powder_cache_ball_count,
		"cannon_warning_cost": cannon_warning_cost,
		"cannon_warning_ball_count": CANNON_WARNING_BALL_COUNT,
		"wayfinder_current_cost": wayfinder_current_cost,
		"wayfinder_current_ball_count": WAYFINDER_CURRENT_BALL_COUNT,
		"broadside_attack_cost": broadside_attack_cost,
		"broadside_powder_keg_count": broadside_powder_keg_count,
		"broadside_cannon_ball_count": broadside_cannon_ball_count,
		"broadside_warning_delay": broadside_warning_delay,
		"broadside_stage_delay_remaining": broadside_delay_remaining,
		"broadside_sequences_started": broadside_sequences_started,
		"wayfinder_current_sequences_started": wayfinder_current_sequences_started,
	}


func _generate_event_offers() -> void:
	active_offer_ids.clear()
	var pool: Array = _get_weighted_unique_event_pool()
	while active_offer_ids.size() < OFFER_SLOT_COUNT and not pool.is_empty():
		active_offer_ids.append(str(pool.pop_front()))
	while active_offer_ids.size() < OFFER_SLOT_COUNT:
		active_offer_ids.append(EMPTY_OFFER_ID)
	offers_generated += 1
	offers_changed.emit(get_event_offers_snapshot())


func _clear_pending_event() -> void:
	pending_event_available = false
	pending_event_ready = false
	event_menu_open = false
	current_shot_doubloons = 0
	active_offer_ids.clear()
	offers_changed.emit(get_event_offers_snapshot())


func _execute_event(event_id: String) -> Array:
	match event_id:
		EVENT_CHEAP_CARGO:
			return _queue_cargo_event(
				event_id,
				cheap_cargo_ball_count,
				cheap_cargo_treasure_chance,
				SpawnSystem.CARGO_REPLACEMENT_TREASURE,
				"Cheap Cargo tumbles onto the felt."
			)
		EVENT_LOOSE_CARGO:
			return _queue_loose_cargo_event()
		EVENT_POWDER_CACHE:
			table.spawn_system.queue_powder_keg_drops(
				powder_cache_ball_count,
				"Powder Cache cracks open."
			)
		EVENT_WAYFINDERS_FAVOR:
			table.spawn_system.queue_wayfinder_ball_drops(
				wayfinders_favor_ball_count,
				"Wayfinder's Favor finds the felt."
			)
		EVENT_CANNON_WARNING:
			table.spawn_system.queue_cannon_ball_drops(
				CANNON_WARNING_BALL_COUNT,
				"Cannon Warning rolls aboard."
			)
		EVENT_BROADSIDE_ATTACK:
			_execute_broadside_attack()
		EVENT_WAYFINDER_CURRENT:
			_execute_wayfinder_current()
	return []


func _queue_cargo_event(
	event_id: String,
	spawn_count: int,
	replacement_chance: float,
	replacement_kind: String,
	callout_message: String
) -> Array:
	var treasure_index := _roll_cargo_treasure_replacement_index(event_id, spawn_count, replacement_chance)
	table.spawn_system.queue_cargo_object_ball_drops(
		spawn_count,
		treasure_index,
		replacement_kind if treasure_index >= 0 else SpawnSystem.CARGO_REPLACEMENT_NONE,
		callout_message
	)
	if treasure_index < 0:
		return []
	return [CARGO_TREASURE_FOUND_MESSAGE]


func _queue_loose_cargo_event() -> Array:
	var replacement: Dictionary = _roll_loose_cargo_replacement()
	var replacement_index := int(replacement.get("index", -1))
	var replacement_kind := str(replacement.get("kind", SpawnSystem.CARGO_REPLACEMENT_NONE))
	table.spawn_system.queue_cargo_object_ball_drops(
		loose_cargo_ball_count,
		replacement_index,
		replacement_kind,
		"Loose Cargo spills across the felt."
	)

	var messages: Array = []
	var messages_value: Variant = replacement.get("messages", [])
	if messages_value is Array:
		for message_value in messages_value:
			var queued_message := str(message_value)
			if not queued_message.is_empty():
				messages.append(queued_message)
	var message := str(replacement.get("message", ""))
	if not message.is_empty():
		messages.append(message)
	return messages


func _roll_loose_cargo_replacement() -> Dictionary:
	var safe_spawn_count := maxi(loose_cargo_ball_count, 0)
	var contraband_chance := _get_effective_loose_cargo_contraband_chance()
	var treasure_chance := clampf(loose_cargo_treasure_chance, 0.0, 1.0 - contraband_chance)
	var replacement := {
		"index": -1,
		"kind": SpawnSystem.CARGO_REPLACEMENT_NONE,
		"message": "",
		"messages": [],
	}
	last_cargo_treasure_event_id = EVENT_LOOSE_CARGO
	last_cargo_treasure_replacement_index = -1
	last_cargo_treasure_roll = 1.0
	last_loose_cargo_contraband_replacement_index = -1
	last_loose_cargo_contraband_replacement_kind = SpawnSystem.CARGO_REPLACEMENT_NONE
	last_loose_cargo_contraband_roll = 1.0
	last_loose_cargo_contraband_weight_roll = 0
	if safe_spawn_count <= 0:
		return replacement
	if debug_force_loose_cargo_contraband:
		return _apply_debug_forced_loose_cargo_contraband(replacement, safe_spawn_count)
	if contraband_chance + treasure_chance <= 0.0:
		return replacement

	var stowaway_roll := cargo_stowaway_rng.randf()
	last_cargo_treasure_roll = stowaway_roll
	last_loose_cargo_contraband_roll = stowaway_roll
	if stowaway_roll <= contraband_chance:
		var contraband_kind := _pick_loose_cargo_contraband_replacement_kind()
		if contraband_kind.is_empty():
			return replacement
		var contraband_index := cargo_stowaway_rng.randi_range(0, safe_spawn_count - 1)
		replacement["index"] = contraband_index
		replacement["kind"] = contraband_kind
		replacement["message"] = _get_loose_cargo_contraband_message()
		last_loose_cargo_contraband_replacement_index = contraband_index
		last_loose_cargo_contraband_replacement_kind = contraband_kind
		loose_cargo_contraband_stowaways_found += 1
		contraband_found.emit(contraband_kind)
		if contraband_kind == SpawnSystem.CARGO_REPLACEMENT_TREASURE:
			last_cargo_treasure_replacement_index = contraband_index
			cargo_treasure_stowaways_found += 1
		return replacement

	if stowaway_roll <= contraband_chance + treasure_chance:
		var treasure_index := cargo_stowaway_rng.randi_range(0, safe_spawn_count - 1)
		replacement["index"] = treasure_index
		replacement["kind"] = SpawnSystem.CARGO_REPLACEMENT_TREASURE
		replacement["message"] = CARGO_TREASURE_FOUND_MESSAGE
		last_cargo_treasure_replacement_index = treasure_index
		cargo_treasure_stowaways_found += 1
	return replacement


func _apply_debug_forced_loose_cargo_contraband(replacement: Dictionary, safe_spawn_count: int) -> Dictionary:
	var messages: Array = []
	var requested_kind := debug_loose_cargo_contraband_kind
	var contraband_kind := ""
	if requested_kind == DEBUG_LOOSE_CARGO_CONTRABAND_RANDOM:
		contraband_kind = _pick_loose_cargo_contraband_replacement_kind()
	else:
		contraband_kind = _sanitize_debug_loose_cargo_contraband_kind(requested_kind)
		if not _is_loose_cargo_contraband_kind_available(contraband_kind):
			var fallback_kind := _get_loose_cargo_contraband_fallback_kind()
			messages.append("Debug Contraband: %s unavailable; using %s." % [
				_get_loose_cargo_contraband_kind_label(contraband_kind),
				_get_loose_cargo_contraband_kind_label(fallback_kind),
			])
			contraband_kind = fallback_kind

	if contraband_kind.is_empty() or not _is_loose_cargo_contraband_kind_available(contraband_kind):
		messages.append("Debug Contraband: no safe replacement available.")
		replacement["messages"] = messages
		return replacement

	var contraband_index := cargo_stowaway_rng.randi_range(0, safe_spawn_count - 1)
	replacement["index"] = contraband_index
	replacement["kind"] = contraband_kind
	messages.append("Debug Contraband forced: %s." % _get_loose_cargo_contraband_kind_label(contraband_kind))
	messages.append(_get_loose_cargo_contraband_message())
	replacement["messages"] = messages
	last_loose_cargo_contraband_replacement_index = contraband_index
	last_loose_cargo_contraband_replacement_kind = contraband_kind
	last_loose_cargo_contraband_roll = 0.0
	loose_cargo_contraband_stowaways_found += 1
	contraband_found.emit(contraband_kind)
	if contraband_kind == SpawnSystem.CARGO_REPLACEMENT_TREASURE:
		last_cargo_treasure_replacement_index = contraband_index
		last_cargo_treasure_roll = 0.0
		cargo_treasure_stowaways_found += 1
	return replacement


func _get_loose_cargo_contraband_message() -> String:
	if LOOSE_CARGO_CONTRABAND_FOUND_MESSAGES.is_empty():
		return ""
	var message_index := loose_cargo_contraband_stowaways_found % LOOSE_CARGO_CONTRABAND_FOUND_MESSAGES.size()
	return str(LOOSE_CARGO_CONTRABAND_FOUND_MESSAGES[message_index])


func _pick_loose_cargo_contraband_replacement_kind() -> String:
	var picked_kind := _pick_weighted_loose_cargo_contraband_kind()
	if _is_loose_cargo_contraband_kind_available(picked_kind):
		return picked_kind

	var rerolled_kind := _pick_weighted_loose_cargo_contraband_kind([picked_kind])
	if _is_loose_cargo_contraband_kind_available(rerolled_kind):
		return rerolled_kind
	return _get_loose_cargo_contraband_fallback_kind()


func _pick_weighted_loose_cargo_contraband_kind(excluded_kinds: Array = []) -> String:
	var total_weight := 0
	for entry_value in LOOSE_CARGO_CONTRABAND_TABLE:
		var entry: Dictionary = entry_value
		var kind := str(entry.get("kind", SpawnSystem.CARGO_REPLACEMENT_NONE))
		var weight := int(entry.get("weight", 0))
		if weight <= 0 or excluded_kinds.has(kind):
			continue
		total_weight += weight

	if total_weight <= 0:
		last_loose_cargo_contraband_weight_roll = 0
		return SpawnSystem.CARGO_REPLACEMENT_NONE

	var weight_roll := cargo_stowaway_rng.randi_range(1, total_weight)
	last_loose_cargo_contraband_weight_roll = weight_roll
	var running_weight := 0
	for entry_value in LOOSE_CARGO_CONTRABAND_TABLE:
		var entry: Dictionary = entry_value
		var kind := str(entry.get("kind", SpawnSystem.CARGO_REPLACEMENT_NONE))
		var weight := int(entry.get("weight", 0))
		if weight <= 0 or excluded_kinds.has(kind):
			continue
		running_weight += weight
		if weight_roll <= running_weight:
			return kind

	return SpawnSystem.CARGO_REPLACEMENT_NONE


func _is_loose_cargo_contraband_kind_available(replacement_kind: String) -> bool:
	if table == null or table.spawn_system == null:
		return false
	return table.spawn_system.can_queue_cargo_replacement_kind(replacement_kind)


func _get_loose_cargo_contraband_fallback_kind() -> String:
	for replacement_kind in LOOSE_CARGO_CONTRABAND_FALLBACK_KINDS:
		var fallback_kind := str(replacement_kind)
		if _is_loose_cargo_contraband_kind_available(fallback_kind):
			return fallback_kind
	return SpawnSystem.CARGO_REPLACEMENT_NONE


func _sanitize_debug_loose_cargo_contraband_kind(kind: String) -> String:
	if DEBUG_LOOSE_CARGO_CONTRABAND_KINDS.has(kind):
		return kind
	return DEBUG_LOOSE_CARGO_CONTRABAND_RANDOM


func _get_base_loose_cargo_contraband_chance() -> float:
	return clampf(loose_cargo_contraband_chance, 0.0, 1.0)


func _get_loose_cargo_contraband_cue_bonus() -> float:
	return maxf(_get_cue_modifier_value(CUE_MODIFIER_LOOSE_CARGO_CONTRABAND_CHANCE_BONUS, 0.0), 0.0)


func _get_effective_loose_cargo_contraband_chance() -> float:
	return clampf(
		_get_base_loose_cargo_contraband_chance() + _get_loose_cargo_contraband_cue_bonus(),
		0.0,
		1.0
	)


func _get_cue_modifier_value(modifier_key: String, fallback: float = 0.0) -> float:
	if not bool(cue_modifier_snapshot.get("modifiers_enabled", true)):
		return fallback
	var modifiers_value: Variant = cue_modifier_snapshot.get("modifiers", {})
	if not modifiers_value is Dictionary:
		return fallback
	var modifiers: Dictionary = modifiers_value as Dictionary
	return float(modifiers.get(modifier_key, fallback))


func _get_active_cue_modifier_summary() -> String:
	var summary := str(cue_modifier_snapshot.get("active_effect_summary", "None"))
	return "None" if summary.is_empty() else summary


func _get_loose_cargo_contraband_kind_label(kind: String) -> String:
	match kind:
		DEBUG_LOOSE_CARGO_CONTRABAND_RANDOM:
			return "Random"
		SpawnSystem.CARGO_REPLACEMENT_WAYFINDER:
			return "Wayfinder"
		SpawnSystem.CARGO_REPLACEMENT_POWDER_KEG:
			return "Powder Keg"
		SpawnSystem.CARGO_REPLACEMENT_TREASURE:
			return "Treasure"
		SpawnSystem.CARGO_REPLACEMENT_CANNON:
			return "Cannon"
		SpawnSystem.CARGO_REPLACEMENT_EMBEZZLER:
			return "Embezzler"
	return "None"


func _roll_cargo_treasure_replacement_index(event_id: String, spawn_count: int, treasure_chance: float) -> int:
	var safe_spawn_count := maxi(spawn_count, 0)
	var clamped_chance := clampf(treasure_chance, 0.0, 1.0)
	last_cargo_treasure_event_id = event_id
	last_cargo_treasure_replacement_index = -1
	last_cargo_treasure_roll = 1.0
	if safe_spawn_count <= 0 or clamped_chance <= 0.0:
		return -1

	last_cargo_treasure_roll = cargo_stowaway_rng.randf()
	if last_cargo_treasure_roll > clamped_chance:
		return -1

	last_cargo_treasure_replacement_index = cargo_stowaway_rng.randi_range(0, safe_spawn_count - 1)
	cargo_treasure_stowaways_found += 1
	return last_cargo_treasure_replacement_index


func _get_offer_purchase_blocker(offer_index: int) -> String:
	if not enabled:
		return "Table Events disabled"
	if not pending_event_available:
		return "No Table Event pending"
	if not pending_event_ready:
		return "Wait for cue control"
	if not _is_valid_offer_index(offer_index):
		return "Unknown Table Event offer"

	_ensure_offer_slots()
	var event_id: String = str(active_offer_ids[offer_index])
	if event_id.is_empty():
		return "No event in this slot yet"
	if table == null or table.score_system == null or table.spawn_system == null:
		return "Table Event system not ready"
	if not table.score_system.can_afford_doubloons(_get_event_cost(event_id)):
		return "Not enough Doubloons"
	return ""


func _get_offer_reroll_blocker(offer_index: int, oath_id: String = OathSystem.OATH_OF_URGENCY) -> String:
	if not enabled:
		return "Table Events disabled"
	if not pending_event_available:
		return "No Table Event pending"
	if not pending_event_ready:
		return "Wait for cue control"
	if not _is_valid_offer_index(offer_index):
		return "Unknown Table Event offer"

	_ensure_offer_slots()
	var event_id := str(active_offer_ids[offer_index])
	if event_id.is_empty():
		return "No event in this slot yet"
	if table == null or table.oath_system == null:
		return "Oath system not ready"
	var oath_blocker: String = table.oath_system.get_oath_activation_blocker(oath_id)
	if not oath_blocker.is_empty():
		return oath_blocker
	if not _has_reroll_replacement_candidate(offer_index):
		return "No replacement omen available"
	return ""


func _make_offer_snapshot(event_id: String, offer_index: int) -> Dictionary:
	var reroll_blocker := _get_offer_reroll_blocker(offer_index)
	if event_id.is_empty():
		return {
			"id": EMPTY_OFFER_ID,
			"name": "More Omens Soon",
			"description": "Future Table Event slot.",
			"flavor": "The deep is quiet here for now.",
			"cost": 0,
			"offer_index": offer_index,
			"icon_key": "plain_object_ball",
			"rarity": "",
			"weight": 0,
			"available": false,
			"affordable": false,
			"blocked_reason": "Coming soon",
			"reroll_available": false,
			"reroll_blocked_reason": reroll_blocker,
			"reroll_oath_id": OathSystem.OATH_OF_URGENCY,
		}

	var event_data: Dictionary = _get_event_data(event_id)
	var blocker: String = _get_offer_purchase_blocker(offer_index)
	var description: String = _get_event_description(event_id, event_data)
	return {
		"id": event_id,
		"name": str(event_data.get("name", "Table Event")),
		"description": description,
		"flavor": str(event_data.get("flavor", "")),
		"cost": _get_event_cost(event_id),
		"offer_index": offer_index,
		"icon_key": str(event_data.get("icon_key", "plain_object_ball")),
		"rarity": _get_event_rarity(event_id),
		"weight": _get_event_weight(event_id),
		"available": blocker.is_empty(),
		"affordable": table != null and table.score_system != null and table.score_system.can_afford_doubloons(_get_event_cost(event_id)),
		"blocked_reason": blocker,
		"reroll_available": reroll_blocker.is_empty(),
		"reroll_blocked_reason": reroll_blocker,
		"reroll_oath_id": OathSystem.OATH_OF_URGENCY,
	}


func _emit_state() -> void:
	var progress: int = _get_meter_progress()
	meter_changed.emit(progress, shot_doubloon_threshold, _get_progress_percent(), pending_event_available, pending_event_ready)
	pending_event_changed.emit(pending_event_available, pending_event_ready)
	offers_changed.emit(get_event_offers_snapshot())


func _get_meter_progress() -> int:
	if pending_event_available:
		return shot_doubloon_threshold
	return clampi(current_shot_doubloons, 0, shot_doubloon_threshold)


func _get_progress_percent() -> float:
	if shot_doubloon_threshold <= 0:
		return 0.0
	return clampf(float(_get_meter_progress()) / float(shot_doubloon_threshold), 0.0, 1.0)


func _get_event_data(event_id: String) -> Dictionary:
	if not EVENT_DATA.has(event_id):
		return {}
	return EVENT_DATA[event_id] as Dictionary


func _get_event_name(event_id: String) -> String:
	return str(_get_event_data(event_id).get("name", "Table Event"))


func _get_event_cost(event_id: String) -> int:
	match event_id:
		EVENT_CHEAP_CARGO:
			return cheap_cargo_cost
		EVENT_LOOSE_CARGO:
			return loose_cargo_cost
		EVENT_POWDER_CACHE:
			return powder_cache_cost
		EVENT_WAYFINDERS_FAVOR:
			return wayfinders_favor_cost
		EVENT_CANNON_WARNING:
			return cannon_warning_cost
		EVENT_BROADSIDE_ATTACK:
			return broadside_attack_cost
		EVENT_WAYFINDER_CURRENT:
			return wayfinder_current_cost
	return 0


func _get_event_rarity(event_id: String) -> String:
	return str(_get_event_data(event_id).get("rarity", "Common"))


func _get_event_weight(event_id: String) -> int:
	return maxi(int(_get_event_data(event_id).get("weight", 1)), 0)


func _get_next_event_earned_message() -> String:
	if EVENT_EARNED_MESSAGES.is_empty():
		return "Kraken Intervention is ready."

	var message: String = str(EVENT_EARNED_MESSAGES[event_earned_message_index])
	event_earned_message_index = (event_earned_message_index + 1) % EVENT_EARNED_MESSAGES.size()
	return message


func _get_event_purchase_message(event_id: String, cost: int) -> String:
	match event_id:
		EVENT_CHEAP_CARGO:
			return "Cheap Cargo released! %s Doubloons spent." % cost
		EVENT_LOOSE_CARGO:
			return "Loose Cargo released! %s Doubloons spent." % cost
		EVENT_POWDER_CACHE:
			return "Powder Cache dropped! %s Doubloons spent." % cost
		EVENT_WAYFINDERS_FAVOR:
			return "Wayfinder's Favor accepted! %s Doubloons spent." % cost
		EVENT_CANNON_WARNING:
			return "Cannon Warning sounded! %s Doubloons spent." % cost
		EVENT_BROADSIDE_ATTACK:
			return "Cannons on the horizon! %s Doubloons spent." % cost
		EVENT_WAYFINDER_CURRENT:
			return "Wayfinder Current released! %s Doubloons spent." % cost
	return "%s unleashed for %s Doubloons." % [_get_event_name(event_id), cost]


func _get_event_description(event_id: String, event_data: Dictionary) -> String:
	match event_id:
		EVENT_CHEAP_CARGO:
			return "Drop %s regular object balls onto the table." % cheap_cargo_ball_count
		EVENT_LOOSE_CARGO:
			return "Drop %s regular object balls onto the table." % loose_cargo_ball_count
		EVENT_POWDER_CACHE:
			return "Drop %s Powder Kegs onto the table." % powder_cache_ball_count
		EVENT_WAYFINDERS_FAVOR:
			return "Drop %s Wayfinder Balls onto the table." % wayfinders_favor_ball_count
		EVENT_CANNON_WARNING:
			return "Drop one heavy Cannon Ball onto the table."
		EVENT_BROADSIDE_ATTACK:
			return "Powder Kegs fall in lanes. Cannon Balls follow."
		EVENT_WAYFINDER_CURRENT:
			return "Two Wayfinders drop. Nearby balls are swept into guided motion."
	return str(event_data.get("description", ""))


func _execute_broadside_attack() -> void:
	broadside_pending_powder_positions = _get_broadside_powder_positions()
	broadside_sequences_started += 1
	table.queue_spawn_reward_message(false, false, false, false, "BROADSIDE INCOMING!")
	broadside_phase = BROADSIDE_PHASE_WARNING
	broadside_delay_remaining = broadside_warning_delay
	set_process(true)


func _execute_wayfinder_current() -> void:
	if table == null or table.spawn_system == null or table.wayfinder_system == null:
		return

	wayfinder_current_sequences_started += 1
	var current_event_id := "wayfinder_current_%s" % wayfinder_current_sequences_started
	table.spawn_system.queue_wayfinder_current_drops(
		WAYFINDER_CURRENT_BALL_COUNT,
		Callable(table.wayfinder_system, "trigger_wayfinder_current_from_wayfinder"),
		"Wayfinder Current sweeps the felt.",
		{
			"event_id": current_event_id,
			"expected_sources": WAYFINDER_CURRENT_BALL_COUNT,
		}
	)


func _queue_broadside_powder_stage() -> void:
	if table == null or table.spawn_system == null:
		broadside_phase = BROADSIDE_PHASE_NONE
		return
	table.spawn_system.queue_powder_keg_drops_at_positions(
		broadside_pending_powder_positions,
		""
	)
	broadside_phase = BROADSIDE_PHASE_CANNON
	broadside_delay_remaining = broadside_stage_delay
	set_process(true)


func _queue_broadside_cannon_stage() -> void:
	if table == null or table.spawn_system == null:
		return
	var launch_specs: Array = _get_broadside_cannon_launch_specs(broadside_pending_powder_positions)
	broadside_pending_powder_positions.clear()
	table.spawn_system.queue_cannon_ball_launches(
		launch_specs,
		"Cannon Balls follow the broadside."
	)


func _get_broadside_powder_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if table == null:
		return positions

	var playfield: Rect2 = table.playfield_rect
	var powder_count: int = clampi(broadside_powder_keg_count, 3, 5)
	var lane_y_ratios := [0.24, 0.40, 0.56, 0.72, 0.32]
	for lane_index in range(powder_count):
		var lane_ratio: float = 0.0 if powder_count <= 1 else float(lane_index) / float(powder_count - 1)
		var x_position: float = lerpf(playfield.position.x + playfield.size.x * 0.78, playfield.position.x + playfield.size.x * 0.28, lane_ratio)
		var y_ratio: float = float(lane_y_ratios[lane_index % lane_y_ratios.size()])
		var y_position: float = playfield.position.y + playfield.size.y * y_ratio
		positions.append(Vector2(x_position, y_position))
	return positions


func _get_broadside_cannon_launch_specs(powder_positions: Array[Vector2]) -> Array:
	var launch_specs: Array = []
	if table == null:
		return launch_specs

	var playfield: Rect2 = table.playfield_rect
	var cannon_count: int = clampi(broadside_cannon_ball_count, 2, 4)
	for cannon_index in range(cannon_count):
		var target_position: Vector2 = _get_broadside_cannon_target(powder_positions, cannon_index, cannon_count)
		var launch_position := Vector2(
			target_position.x,
			playfield.end.y - 36.0
		)
		launch_position.x = clampf(launch_position.x, playfield.position.x + 70.0, playfield.end.x - 70.0)
		var launch_direction: Vector2 = (target_position - launch_position).normalized()
		if launch_direction.length_squared() <= 0.001:
			launch_direction = Vector2.UP
		launch_specs.append({
			"position": launch_position,
			"velocity": launch_direction * broadside_cannon_launch_speed,
		})
	return launch_specs


func _get_broadside_cannon_target(powder_positions: Array[Vector2], cannon_index: int, cannon_count: int) -> Vector2:
	if powder_positions.is_empty():
		return table.playfield_rect.get_center()

	var target_ratio: float = 0.0 if cannon_count <= 1 else float(cannon_index) / float(cannon_count - 1)
	var powder_index: int = clampi(roundi(target_ratio * float(powder_positions.size() - 1)), 0, powder_positions.size() - 1)
	return powder_positions[powder_index]


func _ensure_offer_slots() -> void:
	while active_offer_ids.size() < OFFER_SLOT_COUNT:
		active_offer_ids.append(EMPTY_OFFER_ID)
	if active_offer_ids.size() > OFFER_SLOT_COUNT:
		active_offer_ids.resize(OFFER_SLOT_COUNT)


func _is_valid_offer_index(offer_index: int) -> bool:
	return offer_index >= 0 and offer_index < OFFER_SLOT_COUNT


func _get_weighted_unique_event_pool() -> Array:
	var remaining_events: Array = EVENT_POOL.duplicate()
	var selected_events: Array = []
	while not remaining_events.is_empty():
		var picked_index: int = _pick_weighted_event_index(remaining_events)
		if picked_index < 0:
			break
		selected_events.append(str(remaining_events[picked_index]))
		remaining_events.remove_at(picked_index)
	return selected_events


func _pick_reroll_replacement_event_id(offer_index: int) -> String:
	_ensure_offer_slots()
	if not _is_valid_offer_index(offer_index):
		return EMPTY_OFFER_ID

	var current_event_id := str(active_offer_ids[offer_index])
	var preferred_candidates := _get_reroll_replacement_candidates(offer_index, true)
	if not preferred_candidates.is_empty():
		return _pick_weighted_event_from_candidates(preferred_candidates)

	var fallback_candidates := _get_reroll_replacement_candidates(offer_index, false)
	if not fallback_candidates.is_empty():
		return _pick_weighted_event_from_candidates(fallback_candidates)
	if not current_event_id.is_empty():
		return current_event_id
	return EMPTY_OFFER_ID


func _has_reroll_replacement_candidate(offer_index: int) -> bool:
	_ensure_offer_slots()
	if not _is_valid_offer_index(offer_index):
		return false
	var current_event_id := str(active_offer_ids[offer_index])
	if current_event_id.is_empty():
		return false
	return not _get_reroll_replacement_candidates(offer_index, false).is_empty()


func _get_reroll_replacement_candidates(offer_index: int, avoid_other_active_offers: bool) -> Array:
	var current_event_id := str(active_offer_ids[offer_index])
	var candidates: Array = []
	for event_value in EVENT_POOL:
		var event_id := str(event_value)
		if event_id.is_empty() or event_id == current_event_id:
			continue
		if avoid_other_active_offers and _is_event_active_in_other_offer(event_id, offer_index):
			continue
		candidates.append(event_id)
	return candidates


func _is_event_active_in_other_offer(event_id: String, offer_index: int) -> bool:
	for active_offer_index in range(active_offer_ids.size()):
		if active_offer_index == offer_index:
			continue
		if str(active_offer_ids[active_offer_index]) == event_id:
			return true
	return false


func _pick_weighted_event_from_candidates(candidates: Array) -> String:
	if candidates.is_empty():
		return EMPTY_OFFER_ID
	var picked_index := _pick_weighted_event_index(candidates)
	if picked_index < 0:
		return EMPTY_OFFER_ID
	return str(candidates[picked_index])


func _pick_weighted_event_index(events: Array) -> int:
	var total_weight: int = 0
	for event_value in events:
		var weighted_event_id: String = str(event_value)
		total_weight += _get_event_weight(weighted_event_id)

	if total_weight <= 0:
		return 0 if not events.is_empty() else -1

	var roll: int = offer_rng.randi_range(1, total_weight)
	var running_weight: int = 0
	for event_index in range(events.size()):
		var candidate_event_id: String = str(events[event_index])
		running_weight += _get_event_weight(candidate_event_id)
		if roll <= running_weight:
			return event_index

	return events.size() - 1
