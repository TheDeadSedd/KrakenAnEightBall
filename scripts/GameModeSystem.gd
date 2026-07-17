extends RefCounted
class_name GameModeSystem

# index:title Game Mode System
# index:category Run Modes
# index:status Foundation
# index:owner systems_agent
# index:notes Tiny scene handoff helper for keeping Passage as the default mode while future modes branch explicitly.

# Tiny mode helper for scene-to-scene handoff. Passage remains the default
# when no pending mode is provided, so the existing Start Run path is safe.
const MODE_PASSAGE := "passage"
const MODE_ROGUELITE := "roguelite"
const MODE_SHOT_LAB := "shot_lab"
const DEFAULT_MODE := MODE_PASSAGE
const PENDING_MODE_META := "kaeb_pending_game_mode"
const ACTIVE_MODE_META := "kaeb_active_game_mode"
const PENDING_DEBUG_SESSION_META := "kaeb_pending_debug_session"
const PENDING_SHOT_LAB_SESSION_META := "kaeb_pending_shot_lab_session"


static func normalize_mode_id(mode_id: String) -> String:
	match mode_id:
		MODE_SHOT_LAB:
			return MODE_SHOT_LAB
		MODE_ROGUELITE:
			return MODE_ROGUELITE
		MODE_PASSAGE:
			return MODE_PASSAGE
		_:
			return DEFAULT_MODE


static func get_mode_label(mode_id: String) -> String:
	match normalize_mode_id(mode_id):
		MODE_SHOT_LAB:
			return "Shot Lab"
		MODE_ROGUELITE:
			return "The Long Sink"
		_:
			return "Passage"


static func set_pending_mode(tree: SceneTree, mode_id: String) -> void:
	if tree == null or tree.root == null:
		return
	tree.root.set_meta(PENDING_MODE_META, normalize_mode_id(mode_id))


static func consume_pending_mode(tree: SceneTree) -> String:
	if tree == null or tree.root == null:
		return DEFAULT_MODE

	var mode_id: String = DEFAULT_MODE
	if tree.root.has_meta(PENDING_MODE_META):
		mode_id = normalize_mode_id(str(tree.root.get_meta(PENDING_MODE_META)))
		tree.root.remove_meta(PENDING_MODE_META)

	tree.root.set_meta(ACTIVE_MODE_META, mode_id)
	return mode_id


static func get_active_mode(tree: SceneTree) -> String:
	if tree == null or tree.root == null:
		return DEFAULT_MODE
	if not tree.root.has_meta(ACTIVE_MODE_META):
		return DEFAULT_MODE
	return normalize_mode_id(str(tree.root.get_meta(ACTIVE_MODE_META)))


static func set_pending_debug_session(tree: SceneTree, snapshot: Dictionary) -> void:
	if tree == null or tree.root == null:
		return
	tree.root.set_meta(PENDING_DEBUG_SESSION_META, snapshot.duplicate(true))


static func consume_pending_debug_session(tree: SceneTree) -> Dictionary:
	if tree == null or tree.root == null or not tree.root.has_meta(PENDING_DEBUG_SESSION_META):
		return {}
	var value: Variant = tree.root.get_meta(PENDING_DEBUG_SESSION_META)
	tree.root.remove_meta(PENDING_DEBUG_SESSION_META)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func set_pending_shot_lab_session(tree: SceneTree, configuration: Dictionary = {}) -> void:
	if tree == null or tree.root == null:
		return
	tree.root.set_meta(PENDING_SHOT_LAB_SESSION_META, configuration.duplicate(true))


static func consume_pending_shot_lab_session(tree: SceneTree) -> Dictionary:
	if tree == null or tree.root == null or not tree.root.has_meta(PENDING_SHOT_LAB_SESSION_META):
		return {}
	var value: Variant = tree.root.get_meta(PENDING_SHOT_LAB_SESSION_META)
	tree.root.remove_meta(PENDING_SHOT_LAB_SESSION_META)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func is_passage(mode_id: String) -> bool:
	return normalize_mode_id(mode_id) == MODE_PASSAGE


static func is_roguelite(mode_id: String) -> bool:
	return normalize_mode_id(mode_id) == MODE_ROGUELITE


static func is_shot_lab(mode_id: String) -> bool:
	return normalize_mode_id(mode_id) == MODE_SHOT_LAB


static func is_debug_tooling_available() -> bool:
	return OS.is_debug_build()
