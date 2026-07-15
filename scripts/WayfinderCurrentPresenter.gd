extends Node2D
class_name WayfinderCurrentPresenter

# Presentation-only readability layer for Kraken Intervention: Wayfinder Current.

const PULSE_DURATION := 0.48
const FLASH_DURATION := 0.20
const TEAL_COLOR := Color(0.34, 0.95, 0.88, 0.56)
const GOLD_COLOR := Color(1.0, 0.76, 0.28, 0.48)
const FLASH_CORE_COLOR := Color(0.86, 1.0, 0.93, 0.82)
const FLASH_GOLD_COLOR := Color(1.0, 0.84, 0.36, 0.62)

class CurrentPulse:
	var center := Vector2.ZERO
	var radius := 0.0
	var elapsed := 0.0
	var seed := 0.0

class TransferFlash:
	var start := Vector2.ZERO
	var end := Vector2.ZERO
	var elapsed := 0.0

var active_pulses: Array[CurrentPulse] = []
var active_flashes: Array[TransferFlash] = []


func clear_effects() -> void:
	active_pulses.clear()
	active_flashes.clear()
	set_process(false)
	queue_redraw()


func show_initial_pulse(world_position: Vector2, current_radius: float) -> void:
	var pulse: CurrentPulse = CurrentPulse.new()
	pulse.center = to_local(world_position) if is_inside_tree() else world_position
	pulse.radius = maxf(current_radius, 24.0)
	pulse.seed = float((int(world_position.x * 17.0 + world_position.y * 31.0) % 360)) * TAU / 360.0
	active_pulses.append(pulse)
	set_process(true)
	queue_redraw()


func show_transfer_flash(world_start: Vector2, world_end: Vector2) -> void:
	var flash: TransferFlash = TransferFlash.new()
	flash.start = to_local(world_start) if is_inside_tree() else world_start
	flash.end = to_local(world_end) if is_inside_tree() else world_end
	active_flashes.append(flash)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for pulse_index in range(active_pulses.size() - 1, -1, -1):
		var pulse: CurrentPulse = active_pulses[pulse_index]
		pulse.elapsed += delta
		if pulse.elapsed >= PULSE_DURATION:
			active_pulses.remove_at(pulse_index)

	for flash_index in range(active_flashes.size() - 1, -1, -1):
		var flash: TransferFlash = active_flashes[flash_index]
		flash.elapsed += delta
		if flash.elapsed >= FLASH_DURATION:
			active_flashes.remove_at(flash_index)

	set_process(not active_pulses.is_empty() or not active_flashes.is_empty())
	queue_redraw()


func _draw() -> void:
	for pulse in active_pulses:
		_draw_current_pulse(pulse)
	for flash in active_flashes:
		_draw_transfer_flash(flash)


func _draw_current_pulse(pulse: CurrentPulse) -> void:
	var ratio: float = clampf(pulse.elapsed / PULSE_DURATION, 0.0, 1.0)
	var eased: float = _ease_out_cubic(ratio)
	var fade: float = 1.0 - smoothstep(0.48, 1.0, ratio)
	var radius: float = lerpf(12.0, pulse.radius, eased)
	var spin: float = pulse.seed + pulse.elapsed * 5.4

	var soft_teal: Color = TEAL_COLOR
	soft_teal.a *= fade * 0.34
	draw_circle(pulse.center, radius * 0.86, soft_teal)

	var ring_teal: Color = TEAL_COLOR
	ring_teal.a *= fade
	draw_arc(pulse.center, radius, 0.0, TAU, 88, ring_teal, 3.0)

	var ring_gold: Color = GOLD_COLOR
	ring_gold.a *= fade * 0.86
	draw_arc(pulse.center, radius * 0.72, spin, spin + TAU * 0.52, 36, ring_gold, 2.0)
	draw_arc(pulse.center, radius * 0.96, -spin, -spin + TAU * 0.34, 32, ring_gold, 1.6)


func _draw_transfer_flash(flash: TransferFlash) -> void:
	var ratio: float = clampf(flash.elapsed / FLASH_DURATION, 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(0.30, 1.0, ratio)
	var direction: Vector2 = flash.end - flash.start
	if direction.length_squared() <= 0.01:
		return

	var normal: Vector2 = direction.normalized()
	var tangent := Vector2(-normal.y, normal.x)
	var midpoint: Vector2 = flash.start.lerp(flash.end, 0.5)

	var glow_color: Color = FLASH_GOLD_COLOR
	glow_color.a *= fade * 0.72
	draw_line(flash.start, flash.end, glow_color, 5.0)

	var core_color: Color = FLASH_CORE_COLOR
	core_color.a *= fade
	draw_line(flash.start, flash.end, core_color, 2.0)

	var spark_radius: float = lerpf(4.0, 13.0, sin(ratio * PI))
	draw_circle(midpoint, spark_radius, Color(0.34, 0.95, 0.88, 0.18 * fade))
	draw_line(midpoint - tangent * spark_radius, midpoint + tangent * spark_radius, core_color, 1.5)
	draw_line(midpoint - normal * spark_radius * 0.6, midpoint + normal * spark_radius * 0.6, glow_color, 1.4)


func _ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - clampf(value, 0.0, 1.0), 3.0)
