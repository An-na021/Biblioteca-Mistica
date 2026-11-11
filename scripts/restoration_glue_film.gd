extends RefCounted

const LIGHT := Vector2(-0.6, -0.8)

static func paint(painter: Control, edge: PackedVector2Array, coverage: PackedFloat32Array, seed: int) -> void:
	var normals := PackedVector2Array()
	var widths := PackedFloat32Array()
	for cell in range(edge.size()):
		var tangent := (edge[(cell + 1) % edge.size()] - edge[posmod(cell - 1, edge.size())]).normalized()
		# This contour runs clockwise on the page; paste spreads OUT onto the paper.
		normals.append(Vector2(tangent.y, -tangent.x))
		var uneven := sin(cell * 0.57 + seed * 1.7) * 1.5 + sin(cell * 1.31 + seed) * 0.7
		widths.append(4.0 + uneven + coverage[cell] * 3.0)
	# Moisture slightly darkens the paper beneath a feathered, translucent film.
	_band(painter, edge, normals, widths, coverage, -0.1, 1.45, Color("795a32"), 0.24, 0.0)
	_band(painter, edge, normals, widths, coverage, -0.15, 0.12, Color("f0e4bf"), 0.18, 0.76)
	_band(painter, edge, normals, widths, coverage, 0.12, 0.6, Color("f0e4bf"), 0.76, 0.62)
	_band(painter, edge, normals, widths, coverage, 0.6, 1.15, Color("f0e4bf"), 0.62, 0.0)
	for cell in range(edge.size()):
		var point := edge[cell]
		var next := edge[(cell + 1) % edge.size()]
		var normal := normals[cell]
		var wet := coverage[cell]
		var variation := 0.5 + sin(cell * 2.73 + seed * 1.9) * 0.5
		if cell % 2 == 0:
			# Torn fibers stay visible through the adhesive and soften its boundary.
			var fiber := normal * (1.0 + variation * 1.8)
			painter.draw_line(point - normal * 0.5, point + fiber, Color(0.83, 0.72, 0.51, 0.32 - wet * 0.1), 0.55, true)
		if wet <= 0.001:
			continue
		var middle := point.lerp(next, 0.5)
		var tangent := (next - point).normalized()
		if cell % 3 != 0:
			# Fine brush grooves taper into the paper rather than forming an outline.
			var start := middle + normal * widths[cell] * 0.18
			var finish := middle + normal * widths[cell] * 0.83 + tangent * (variation - 0.5)
			painter.draw_line(start, finish, Color(0.65, 0.53, 0.32, wet * 0.28), 0.55, true)
		var facing := maxf(0.0, normal.dot(LIGHT))
		if facing > 0.3 and variation > 0.6:
			# Wet glints face the lamp and break into short, irregular strokes.
			var start := point.lerp(next, 0.12 + variation * 0.2) + normal * 0.7
			var finish := point.lerp(next, 0.62 + variation * 0.23) + normal * 0.9
			painter.draw_line(start, finish, Color(0.99, 0.95, 0.8, wet * facing * (0.45 + variation * 0.25)), 0.8, true)
		if variation > 0.93 and wet > 0.7:
			painter.draw_circle(middle + normal * widths[cell] * 0.4, 0.55, Color(0.96, 0.9, 0.72, wet * 0.35), true, -1, true)

static func _band(painter: Control, edge: PackedVector2Array, normals: PackedVector2Array, widths: PackedFloat32Array, coverage: PackedFloat32Array, inner: float, outer: float, tint: Color, inner_alpha: float, outer_alpha: float) -> void:
	for cell in range(edge.size()):
		var next := (cell + 1) % edge.size()
		# The first thin coat must already read clearly against the golden page.
		# This changes opacity only; completion still uses the original coverage.
		var wet_a := sqrt(clampf(coverage[cell], 0.0, 1.0))
		var wet_b := sqrt(clampf(coverage[next], 0.0, 1.0))
		if maxf(wet_a, wet_b) <= 0.001:
			continue
		var a := edge[cell]
		var b := edge[next]
		var normal_a := normals[cell] * widths[cell]
		var normal_b := normals[next] * widths[next]
		var points := PackedVector2Array([a + normal_a * inner, b + normal_b * inner, b + normal_b * outer, a + normal_a * outer])
		var colors := PackedColorArray([Color(tint, wet_a * inner_alpha), Color(tint, wet_b * inner_alpha), Color(tint, wet_b * outer_alpha), Color(tint, wet_a * outer_alpha)])
		painter.draw_primitive(points, colors, PackedVector2Array())
