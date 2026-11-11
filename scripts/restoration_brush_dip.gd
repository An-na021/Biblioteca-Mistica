extends RefCounted

const APPROACH_SECONDS := 0.22
const SOAK_SECONDS := 0.3
const LIFT_SECONDS := 0.28
const RETURN_SECONDS := 0.18
const DURATION := APPROACH_SECONDS + SOAK_SECONDS + LIFT_SECONDS + RETURN_SECONDS

var active := false
var elapsed := 0.0
var center := Vector2.ZERO
var origin := Vector2.ZERO
var initial_angle := 0.55
var _coat := GradientTexture2D.new()

func _init() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color(0.94, 0.88, 0.73, 0.18), Color(0.92, 0.87, 0.73, 0.62), Color(0.86, 0.79, 0.63, 0.79), Color(0.75, 0.66, 0.49, 0.73)])
	_coat.gradient = gradient
	_coat.fill_from = Vector2(0.5, 0)
	_coat.fill_to = Vector2(0.5, 1)

func begin(point: Vector2, opening: Vector2, brush_angle: float) -> void:
	if active:
		return
	active = true
	elapsed = 0.0
	origin = point
	center = opening
	initial_angle = brush_angle

func cancel() -> void:
	active = false
	elapsed = 0.0

func advance(delta: float) -> bool:
	if not active:
		return false
	elapsed = minf(DURATION, elapsed + delta)
	if elapsed < DURATION:
		return false
	active = false
	return true

func _ease(value: float) -> float:
	var t := clampf(value, 0, 1)
	return t * t * (3 - 2 * t)

func position(pointer: Vector2) -> Vector2:
	if elapsed < APPROACH_SECONDS:
		return origin.lerp(center, _ease(elapsed / APPROACH_SECONDS))
	var t := elapsed - APPROACH_SECONDS
	if t < SOAK_SECONDS:
		var stir := sin(t / SOAK_SECONDS * TAU)
		return center + Vector2(stir * 5, sin(t / SOAK_SECONDS * PI) * 6)
	t -= SOAK_SECONDS
	var lifted := center + Vector2(-4, -15)
	if t < LIFT_SECONDS:
		return center.lerp(lifted, _ease(t / LIFT_SECONDS))
	return lifted.lerp(pointer, _ease((t - LIFT_SECONDS) / RETURN_SECONDS))

func angle() -> float:
	if elapsed < APPROACH_SECONDS:
		return lerp_angle(initial_angle, 0.28, _ease(elapsed / APPROACH_SECONDS))
	var t := elapsed - APPROACH_SECONDS
	if t < SOAK_SECONDS:
		return 0.28 + sin(t / SOAK_SECONDS * TAU) * 0.09
	return lerp_angle(0.28, 0.55, _ease((t - SOAK_SECONDS) / LIFT_SECONDS))

func depth() -> float:
	if not active or elapsed < APPROACH_SECONDS:
		return 0.0
	var t := elapsed - APPROACH_SECONDS
	if t < SOAK_SECONDS:
		return sin(minf(1, t / 0.1) * PI * 0.5)
	return 1.0 - _ease((t - SOAK_SECONDS) / LIFT_SECONDS)

func wetness() -> float:
	return clampf((elapsed - APPROACH_SECONDS) / SOAK_SECONDS, 0, 1)

func paint_surface(painter: Control) -> void:
	if not active or elapsed < APPROACH_SECONDS:
		return
	var t := elapsed - APPROACH_SECONDS
	# Low contrast rings spread across the paste as the bristles stir it.
	for index in range(2):
		var wave := (t - index * 0.13) / 0.65
		if wave <= 0 or wave >= 1:
			continue
		painter.draw_set_transform(center + Vector2(0, 3), 0, Vector2(1, 0.58))
		painter.draw_arc(Vector2.ZERO, 8 + wave * 23, 0.2, TAU - 0.5, 36, Color(0.94, 0.85, 0.64, (1 - wave) * 0.6), 1.3, true)
		painter.draw_set_transform(Vector2.ZERO)

func paint_coating(painter: Control, amount: float, contact: float) -> void:
	var wet := clampf(amount, 0.0, 1.0)
	if wet <= 0.0001:
		return
	var height := 3.5 + wet * 9.0
	var paste := PackedVector2Array([
		Vector2(-11.5, -height + 1.5), Vector2(-8, -height - 0.6),
		Vector2(-3.5, -height + 0.4), Vector2(1, -height - 1.2),
		Vector2(5.5, -height + 0.7), Vector2(10.5, -height),
		Vector2(12.8, -1), Vector2(10, 0.4), Vector2(6, -0.4),
		Vector2(2, 0.8), Vector2(-3, 0.0), Vector2(-7, 0.6), Vector2(-13, -0.7)
	])
	# A translucent coat blends into the bristles and grows thicker near the tips.
	var uvs := PackedVector2Array()
	for point in paste:
		uvs.append(Vector2((point.x + 13) / 26.0, (point.y + height + 2) / (height + 3)))
	painter.draw_polygon(paste, PackedColorArray([Color.WHITE]), uvs, _coat)
	var meniscus := PackedVector2Array([paste[0], paste[1], paste[2], paste[3], paste[4], paste[5]])
	painter.draw_polyline(meniscus, Color(0.55, 0.43, 0.27, 0.35 * wet), 0.75, true)
	for index in range(8):
		var x := -10.0 + index * 2.8
		var y := -height + 2.5 + sin(index * 2.1) * 0.7
		painter.draw_line(Vector2(x, y), Vector2(x + 0.3, -1.5), Color(0.65, 0.55, 0.36, 0.23 * wet), 0.55, true)
	# Small warm highlights follow the grooves; no solid white stripe across the tip.
	painter.draw_polyline(PackedVector2Array([Vector2(-8, -height + 3), Vector2(-5, -height + 2.2), Vector2(-2, -height + 2.8)]), Color(0.99, 0.94, 0.79, 0.7 * wet), 1.2, true)
	painter.draw_line(Vector2(4, -4), Vector2(8, -4.6), Color(0.98, 0.92, 0.74, 0.5 * wet), 0.9, true)
	if wet > 0.5 and contact < 0.3:
		# A rounded bead stays attached to the loaded bristles instead of floating below them.
		painter.draw_circle(Vector2(3, 0), 1.2 + wet * 0.6, Color("e2d4ad"), true, -1, true)
		painter.draw_arc(Vector2(3, 0), 1.2 + wet * 0.6, 0.2, PI - 0.1, 12, Color(0.57, 0.45, 0.28, 0.45), 0.65, true)

func paint_paste(painter: Control, tip: Vector2, brush_angle: float, brush_scale: float) -> void:
	if not active:
		return
	var amount := depth()
	if amount > 0:
		# Paste covers the bottom of the bristles while the brush is submerged.
		painter.draw_set_transform(tip, brush_angle, Vector2.ONE * brush_scale)
		var paste := PackedVector2Array([Vector2(-10, -amount * 7), Vector2(-5, -amount * 8), Vector2(0, -amount * 6), Vector2(6, -amount * 7), Vector2(10, -amount * 5), Vector2(10, 3), Vector2(-10, 3)])
		painter.draw_colored_polygon(paste, Color(0.76, 0.66, 0.46, amount * 0.95))
		painter.draw_arc(Vector2(0, 1), 11, 0.1, PI - 0.1, 16, Color(0.93, 0.84, 0.64, amount * 0.7), 1.1, true)
		painter.draw_set_transform(Vector2.ZERO)
	var lift := (elapsed - APPROACH_SECONDS - SOAK_SECONDS) / LIFT_SECONDS
	if lift > 0 and lift < 0.8:
		# A short viscous strand stretches, thins and breaks as the brush rises.
		painter.draw_line(center + Vector2(0, 3), tip, Color(0.92, 0.84, 0.65, (1 - lift) * 0.85), lerpf(2.5, 0.6, lift), true)
