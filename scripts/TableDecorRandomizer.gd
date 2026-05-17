extends Node2D
class_name TableDecorRandomizer

# Presentation-only table dressing. This script only toggles authored sprite
# visibility at run start; it never touches gameplay geometry or input.

@export_range(0.0, 1.0, 0.01) var bottom_right_chance: float = 0.55

@export var bottom_right_prop_path: NodePath = ^"BottomRight"

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	randomize_decor()


func randomize_decor() -> void:
	_set_prop_visible(bottom_right_prop_path, _rng.randf() < bottom_right_chance)


func _set_prop_visible(prop_path: NodePath, is_visible: bool) -> void:
	var prop: CanvasItem = get_node_or_null(prop_path) as CanvasItem
	if prop == null:
		return

	prop.visible = is_visible
