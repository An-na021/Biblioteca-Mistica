extends RefCounted

var angle := -0.35
var rotation := 0.0
var pressure := 0.0
var _last_point := Vector2.ZERO
var _target := -1
var _wood := GradientTexture2D.new()
var _felt := GradientTexture2D.new()
var _shadow: StyleBoxFlat
var _ferrule: StyleBoxFlat
var _rim: StyleBoxFlat

func _init() -> void:
	_shadow = _rounded(Color(0.12, 0.07, 0.025, 0.24), Color.TRANSPARENT, 7)
	_ferrule = _rounded(Color("9e7b43"), Color("49351e"), 2)
	_rim = _rounded(Color("a88c57"), Color("49371f"), 5)
	var wood_gradient := Gradient.new()
	wood_gradient.offsets = PackedFloat32Array([0, 0.25, 0.55, 0.8, 1])
	wood_gradient.colors = PackedColorArray([Color("382015"), Color("7d4828"), Color("a16c3d"), Color("704024"), Color("352015")])
	_wood.gradient = wood_gradient
	_wood.fill_from = Vector2(0, 0.5)
	_wood.fill_to = Vector2(1, 0.5)
	var felt_gradient := Gradient.new()
	felt_gradient.offsets = PackedFloat32Array([0, 0.25, 0.55, 0.8, 1])
	felt_gradient.colors = PackedColorArray([Color("6a5536"), Color("c7b58a"), Color("e0d2ae"), Color("b7a078"), Color("715b3b")])
	_felt.gradient = felt_gradient
	_felt.fill_from = Vector2(0.5, 0)
	_felt.fill_to = Vector2(0.5, 1)

func advance(delta: float, point: Vector2, target: int, pressed: bool) -> void:
	var motion := point - _last_point if target == _target and target >= 0 else Vector2.ZERO
	_last_point = point
	_target = target
	pressure = move_toward(pressure, 1.0 if pressed and target >= 0 else 0.0, delta * 8)
	if motion.length() > 0.3:
		# Reversing a pass turns the cylinder back without flipping the handle.
		var desired := motion.angle() + PI * 0.5
		desired = angle + wrapf(desired - angle, -PI * 0.5, PI * 0.5)
		angle = lerp_angle(angle, desired, 1.0 - exp(-delta * 12))
		if pressed:
			rotation += motion.dot(Vector2.DOWN.rotated(angle)) / 8.0

func paint(painter: Control, point: Vector2) -> void:
	painter.draw_set_transform(point + Vector2(3 - pressure, 5 - pressure * 2), angle)
	painter.draw_style_box(_shadow, Rect2(-34, -9, 68, 21))
	painter.draw_set_transform(point + Vector2(0, pressure * 1.4), angle)
	# Rounded walnut handle, with grain and a brass ferrule joining the yoke.
	var handle := PackedVector2Array([Vector2(-5, -25), Vector2(-8, -57), Vector2(-7, -70), Vector2(-3, -75), Vector2(3, -75), Vector2(7, -70), Vector2(8, -57), Vector2(5, -25)])
	var uvs := PackedVector2Array()
	for vertex in handle:
		uvs.append(Vector2((vertex.x + 8) / 16.0, (vertex.y + 75) / 50.0))
	painter.draw_polygon(handle, PackedColorArray([Color.WHITE]), uvs, _wood)
	var outline := handle.duplicate()
	outline.append(outline[0])
	painter.draw_polyline(outline, Color("342318"), 1.2, true)
	for index in range(3):
		var x := -4 + index * 3.0
		painter.draw_polyline(PackedVector2Array([Vector2(x, -67), Vector2(x - 0.6, -56), Vector2(x + 0.7, -40), Vector2(x, -31)]), Color(0.23, 0.12, 0.06, 0.3), 0.6, true)
	painter.draw_style_box(_ferrule, Rect2(-7, -30, 14, 8))
	painter.draw_line(Vector2(-5, -28), Vector2(5, -28), Color("d4b879"), 1.1, true)
	var yoke := PackedVector2Array([Vector2(-31, -1), Vector2(-31, -21), Vector2(-27, -25), Vector2(27, -25), Vector2(31, -21), Vector2(31, -1)])
	painter.draw_polyline(yoke, Color("3e301f"), 6, true)
	painter.draw_polyline(yoke, Color("9c8153"), 3, true)
	painter.draw_circle(Vector2(0, -25), 2.5, Color("d3b77a"), true, -1, true)
	painter.draw_line(Vector2(-1.2, -25), Vector2(1.2, -25), Color("584125"), 0.8, true)
	# Broad, softly shaded linen cylinder; its surface turns with the player's passes.
	painter.draw_style_box(_rim, Rect2(-35, -10, 70, 20))
	painter.draw_texture_rect(_felt, Rect2(-29, -9, 58, 18), false)
	for index in range(5):
		var turn := rotation + index * TAU / 5.0
		if cos(turn) <= 0:
			continue
		var y := sin(turn) * 7
		painter.draw_line(Vector2(-28, y), Vector2(28, y), Color(0.4, 0.31, 0.18, cos(turn) * 0.16), 0.7, true)
	for index in range(15):
		var x := -26 + index * 3.7
		painter.draw_line(Vector2(x, -6), Vector2(x + 0.5, 6), Color(0.34, 0.25, 0.13, 0.09), 0.4, true)
	for x in [-32.0, 32.0]:
		painter.draw_line(Vector2(x, -7), Vector2(x, 7), Color("dac38d"), 1, true)
	painter.draw_set_transform(Vector2.ZERO)

func _rounded(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
