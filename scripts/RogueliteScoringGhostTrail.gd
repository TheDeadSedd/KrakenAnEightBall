extends Control
class_name RogueliteScoringGhostTrail

signal finished(trail: RogueliteScoringGhostTrail)

const MAX_POINTS := 24

var points: Array[Vector2] = []
var trail_color := Color.WHITE
var trail_alpha := 0.34:
	set(value):
		trail_alpha = value
		queue_redraw()
var presentation_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 50
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(color: Color) -> void:
	trail_color = color
	trail_alpha = 0.34
	queue_redraw()


func append_point(point: Vector2) -> void:
	if not points.is_empty() and points[points.size() - 1].distance_to(point) <= 1.0:
		return
	points.append(point)
	while points.size() > MAX_POINTS:
		points.pop_front()
	queue_redraw()


func fade_out(duration: float = 0.28) -> void:
	if presentation_tween != null and presentation_tween.is_valid():
		presentation_tween.kill()
	presentation_tween = create_tween()
	presentation_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	presentation_tween.tween_property(self, "trail_alpha", 0.0, maxf(duration, 0.06))
	presentation_tween.finished.connect(_finish)


func finish_immediately() -> void:
	if presentation_tween != null and presentation_tween.is_valid():
		presentation_tween.kill()
	_finish()


func _draw() -> void:
	if points.size() < 2:
		return
	for index in range(1, points.size()):
		var progress: float = float(index) / float(maxi(points.size() - 1, 1))
		var alpha: float = trail_alpha * lerpf(0.45, 1.0, progress)
		draw_line(
			points[index - 1],
			points[index],
			Color(trail_color.r, trail_color.g, trail_color.b, alpha),
			1.5 + progress,
			true
		)


func _finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit(self)
	queue_free()
