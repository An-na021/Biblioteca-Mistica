extends RefCounted

const BOOK: Texture2D = preload("res://IMG/workshop/restoration_open_book.png")
const GlueFilm = preload("res://scripts/restoration_glue_film.gd")
const BOOK_RECT := Rect2(253, 164, 690, 451)
const SPOTS := [Vector2(399, 295), Vector2(770, 456), Vector2(797, 270)]
const TARGETS := [Vector2(415, 435), Vector2(755, 350), Vector2(806, 535)]
const HOMES := [Vector2(1101, 350), Vector2(1101, 450), Vector2(1101, 550)]
const CLEAN_READY_REMAINDER := 0.06
const GLUE_READY_AVERAGE := 0.985
const GLUE_READY_EDGE := 0.9
const GLUE_STROKE_DISTANCE := 28.0
const SMOOTH_SECONDS := 4.5
const SMOOTH_MIN_SECONDS := 3.0
const SMOOTH_STROKE_DISTANCE := 900.0
const SMOOTH_ZONES := [Vector2.ZERO, Vector2(-22, 0), Vector2(22, 0), Vector2(0, -14), Vector2(0, 14)]
const OUTLINES := [
	[Vector2(-45, -17), Vector2(-16, -28), Vector2(40, -19), Vector2(26, 23), Vector2(-29, 28)],
	[Vector2(-35, -27), Vector2(35, -12), Vector2(24, 27), Vector2(-21, 18)],
	[Vector2(-42, -24), Vector2(30, -25), Vector2(43, 10), Vector2(7, 29), Vector2(-35, 17)]
]

var cleaned := [0.0, 0.0, 0.0]
var glued := [0.0, 0.0, 0.0]
var laid := [false, false, false]
var patched := [false, false, false]
var dust: Array[Array] = []
var airborne: Array[Dictionary] = []
var edges: Array[PackedVector2Array] = []
var glue_cells: Array[PackedFloat32Array] = []
var smooth_cells: Array[PackedFloat32Array] = []
var _smooth_progress := [0.0, 0.0, 0.0]
var _smooth_contact_seconds := [0.0, 0.0, 0.0]
var paper_centers: Array[Vector2] = []
var paper_goals: Array[Vector2] = []
var paper_lift := [0.0, 0.0, 0.0]
var paper_rotation := [0.0, 0.0, 0.0]
var _fibers: Array[Array] = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 481726
	for index in range(3):
		var motes: Array = []
		for grain in range(145):
			var a := _rng.randf_range(0, TAU)
			var radius := sqrt(_rng.randf())
			var point: Vector2 = SPOTS[index] + Vector2(cos(a) * 39, sin(a) * 27) * radius
			motes.append({"position": point, "health": 1.0, "radius": _rng.randf_range(0.25, 1.05), "opacity": _rng.randf_range(0.16, 0.43), "angle": a})
		dust.append(motes)
		var edge := _make_edge(index)
		edges.append(edge)
		var coverage := PackedFloat32Array()
		coverage.resize(edge.size())
		coverage.fill(0)
		glue_cells.append(coverage)
		var smoothing := PackedFloat32Array([0, 0, 0, 0, 0])
		smooth_cells.append(smoothing)
		paper_centers.append(HOMES[index])
		paper_goals.append(HOMES[index])
		var fibers: Array = []
		for fiber in range(95):
			var point := Vector2(_rng.randf_range(-44, 44), _rng.randf_range(-28, 28))
			if Geometry2D.is_point_in_polygon(point, edge):
				fibers.append({"point": point, "end": point + Vector2(_rng.randf_range(1, 5), _rng.randf_range(-1, 1)), "alpha": _rng.randf_range(0.03, 0.12)})
		_fibers.append(fibers)

func _make_edge(index: int) -> PackedVector2Array:
	var outline: Array = OUTLINES[index]
	var rounded := PackedVector2Array()
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		rounded.append(a.lerp(b, 0.15))
		rounded.append(a.lerp(b, 0.85))
	var result := PackedVector2Array()
	for i in range(rounded.size()):
		var a := rounded[i]
		var b := rounded[(i + 1) % rounded.size()]
		var normal := Vector2(-(b - a).y, (b - a).x).normalized()
		for sample in range(4):
			var t := sample / 4.0
			var fiber := sin((i * 4 + sample) * 2.73 + index) * 0.85
			result.append(a.lerp(b, t) + normal * fiber)
	return result

func shape(index: int, center: Vector2) -> PackedVector2Array:
	var result := edges[index].duplicate()
	for i in range(result.size()):
		result[i] += center
	return result

func clean_segment(from: Vector2, to: Vector2) -> bool:
	var distance := minf(40, from.distance_to(to))
	if distance <= 0.001:
		return false
	var changed := false
	for index in range(dust.size()):
		if cleaned[index] >= 1:
			continue
		for mote: Dictionary in dust[index]:
			var position: Vector2 = mote.position
			var d := position.distance_to(Geometry2D.get_closest_point_to_segment(position, from, to))
			if d < 13 and float(mote.health) > 0:
				var old: float = mote.health
				mote.health = maxf(0, old - minf(1, distance / 18.0) * (0.45 + 0.55 * (1 - d / 13)))
				changed = true
				if old > 0 and float(mote.health) <= 0 and airborne.size() < 90:
					airborne.append({"position": position, "velocity": (to - from).normalized() * _rng.randf_range(12, 27) + Vector2(_rng.randf_range(-5, 5), -12), "age": 0.0, "life": _rng.randf_range(0.4, 0.8), "radius": mote.radius})
	update_clean_completion()
	return changed

func update_clean_completion() -> void:
	for index in range(dust.size()):
		var remaining := 0.0
		var total := 0.0
		for mote: Dictionary in dust[index]:
			# Progress follows the visible dust, rather than counting faint grains
			# as heavily as opaque ones and making the player hunt invisible traces.
			var weight := float(mote.opacity) * float(mote.radius)
			remaining += float(mote.health) * weight
			total += weight
		cleaned[index] = clampf(1.0 - remaining / total, 0, 1)
		if remaining / total <= CLEAN_READY_REMAINDER:
			cleaned[index] = 1.0
			for mote: Dictionary in dust[index]:
				mote.health = 0.0

func clean_percent() -> int:
	if cleaned.all(func(value: float) -> bool: return value >= 1.0):
		return 100
	return mini(99, floori((cleaned[0] + cleaned[1] + cleaned[2]) / 3.0 * 100))

func apply_glue(from: Vector2, to: Vector2, charge: float) -> float:
	charge = maxf(0, charge - update_glue_completion())
	var distance := minf(35, from.distance_to(to))
	if distance <= 0.001 or charge <= 0.0001:
		return charge
	for index in range(TARGETS.size()):
		if glued[index] >= 1:
			continue
		var coverage := glue_cells[index]
		for cell in range(coverage.size()):
			var point: Vector2 = TARGETS[index] + edges[index][cell]
			var d := point.distance_to(Geometry2D.get_closest_point_to_segment(point, from, to))
			if d < 13 and charge > 0:
				var amount := minf(1.0 - coverage[cell], minf(charge * coverage.size(), distance / GLUE_STROKE_DISTANCE * (0.5 + 0.5 * (1 - d / 13))))
				coverage[cell] += amount
				charge = maxf(0, charge - amount / coverage.size())
		glue_cells[index] = coverage
	charge = maxf(0, charge - update_glue_completion())
	return 0.0 if charge < 0.0001 else charge

func update_glue_completion() -> float:
	var finishing_amount := 0.0
	for index in range(glue_cells.size()):
		var coverage := glue_cells[index]
		var total := 0.0
		var weakest := 1.0
		for value in coverage:
			total += value
			weakest = minf(weakest, value)
		var average := total / coverage.size()
		# A fully brushed rim may retain tiny fractional gaps in the simulated coat.
		# Accept that finish, while still requiring paste along every part of the rim.
		if average >= GLUE_READY_AVERAGE and weakest >= GLUE_READY_EDGE:
			finishing_amount += 1.0 - average
			coverage.fill(1)
			glued[index] = 1.0
		else:
			glued[index] = average
		glue_cells[index] = coverage
	return finishing_amount

func glue_percent() -> int:
	if glued.all(func(value: float) -> bool: return value >= 1.0):
		return 100
	# Only a completed coat can display 100%; an unfinished edge stays below it.
	return mini(99, floori((glued[0] + glued[1] + glued[2]) / 3.0 * 100))

func lay(index: int) -> void:
	laid[index] = true
	paper_goals[index] = TARGETS[index]

func papers_ready_for_roller() -> bool:
	return laid.all(func(value: bool) -> bool: return value)

func return_paper(index: int) -> void:
	paper_goals[index] = HOMES[index]

func smooth_contains(index: int, point: Vector2) -> bool:
	return Rect2(TARGETS[index] - Vector2(56, 40), Vector2(112, 80)).has_point(point)

func smooth(index: int, from: Vector2, to: Vector2, delta := 0.0) -> bool:
	if not papers_ready_for_roller() or patched[index] or not smooth_contains(index, to):
		return false
	var distance := minf(28.0, from.distance_to(to)) if smooth_contains(index, from) else 0.0
	# Gentle pressure or strokes in any direction work; there are no hidden zones to hit.
	_smooth_contact_seconds[index] += maxf(0.0, delta)
	var pressure_limit := minf(1.0, float(_smooth_contact_seconds[index]) / SMOOTH_MIN_SECONDS)
	# Rapid mouse events cannot finish instantly; the visible percentage includes
	# the time under pressure, so it never reaches 100% before the paper is ready.
	_smooth_progress[index] = minf(pressure_limit, float(_smooth_progress[index]) + maxf(0, delta) / SMOOTH_SECONDS + distance / SMOOTH_STROKE_DISTANCE)
	smooth_cells[index].fill(_smooth_progress[index])
	if _smooth_progress[index] >= 0.999:
		_smooth_progress[index] = 1.0
		smooth_cells[index].fill(1)
		patched[index] = true
	return patched[index]

func smooth_amount(index: int) -> float:
	return _smooth_progress[index]

func advance(delta: float, drag_index: int, drag_goal: Vector2) -> void:
	for i in range(airborne.size() - 1, -1, -1):
		var particle: Dictionary = airborne[i]
		particle.age = float(particle.age) + delta
		if float(particle.age) >= float(particle.life):
			airborne.remove_at(i)
			continue
		particle.position = Vector2(particle.position) + Vector2(particle.velocity) * delta
		particle.velocity = Vector2(particle.velocity) * exp(-delta * 1.7) + Vector2(0, -3) * delta
	for index in range(3):
		var dragged := index == drag_index
		var goal: Vector2 = drag_goal if dragged else paper_goals[index]
		var motion := goal - paper_centers[index]
		paper_centers[index] = paper_centers[index].lerp(goal, 1.0 - exp(-delta * 28))
		paper_lift[index] = lerpf(paper_lift[index], 1.0 if dragged else 0.0, 1.0 - exp(-delta * 15))
		paper_rotation[index] = lerpf(paper_rotation[index], clampf(motion.x * 0.002, -0.08, 0.08) if dragged else 0.0, 1.0 - exp(-delta * 12))

func paint_dust(painter: Control) -> void:
	for motes: Array in dust:
		for mote: Dictionary in motes:
			var opacity := float(mote.opacity) * float(mote.health)
			if opacity <= 0:
				continue
			var point: Vector2 = mote.position
			var radius: float = mote.radius
			painter.draw_circle(point, radius * 3, Color(0.3, 0.23, 0.13, opacity * 0.15), true, -1, true)
			painter.draw_circle(point, radius, Color(0.32, 0.25, 0.16, opacity), true, -1, true)
			if radius > 0.85:
				painter.draw_line(point, point + Vector2(cos(float(mote.angle)), sin(float(mote.angle))) * 3, Color(0.3, 0.23, 0.12, opacity * 0.5), 0.6, true)
	for particle: Dictionary in airborne:
		var alpha := 1.0 - float(particle.age) / float(particle.life)
		painter.draw_circle(particle.position, float(particle.radius) * 0.7, Color(0.55, 0.43, 0.26, alpha * 0.45), true, -1, true)

func paint_holes(painter: Control) -> void:
	for index in range(TARGETS.size()):
		if laid[index] and paper_centers[index].distance_to(TARGETS[index]) < 2:
			continue
		var polygon := shape(index, TARGETS[index])
		var uvs := PackedVector2Array()
		for point in polygon:
			uvs.append((point - BOOK_RECT.position + Vector2(3, 5)) / BOOK_RECT.size)
		# Missing paper reveals the shaded next page, not a black hole in the table.
		painter.draw_polygon(polygon, PackedColorArray([Color(0.61, 0.54, 0.42)]), uvs, BOOK)
		var contour := polygon.duplicate()
		contour.append(contour[0])
		painter.draw_polyline(contour, Color(0.3, 0.22, 0.12, 0.4), 0.85, true)
		GlueFilm.paint(painter, polygon, glue_cells[index], index)

func paint_paper(painter: Control, index: int) -> void:
	var center := paper_centers[index]
	var lift: float = paper_lift[index]
	var flat := smooth_amount(index) if laid[index] else 0.0
	painter.draw_set_transform(center, paper_rotation[index], Vector2.ONE * (1.0 + lift * 0.025))
	var polygon := edges[index]
	var shadow := polygon.duplicate()
	for i in range(shadow.size()):
		shadow[i] += Vector2(1.0 + lift * 4, 1.5 + lift * 5)
	painter.draw_colored_polygon(shadow, Color(0.21, 0.13, 0.055, 0.1 + lift * 0.15 + (1 - flat) * 0.04))
	var uvs := PackedVector2Array()
	for point in polygon:
		uvs.append(Vector2(0.3 + index * 0.012, 0.43) + point / BOOK.get_size())
	painter.draw_polygon(polygon, PackedColorArray([Color(0.94 - flat * 0.03, 0.9 - flat * 0.03, 0.78 - flat * 0.025, 0.96 - flat * 0.16)]), uvs, BOOK)
	var contour := polygon.duplicate()
	contour.append(contour[0])
	painter.draw_polyline(contour, Color(0.84, 0.73, 0.48, 0.65 - flat * 0.35), 1.6, true)
	for fiber: Dictionary in _fibers[index]:
		painter.draw_line(fiber.point, fiber.end, Color(0.38, 0.28, 0.13, float(fiber.alpha)), 0.5, true)
	for i in range(0, polygon.size(), 2):
		var point := polygon[i]
		painter.draw_line(point, point + point.normalized() * 1.7, Color(0.94, 0.88, 0.66, 0.6 - flat * 0.25), 0.55, true)
	if laid[index] and not patched[index]:
		# Each small crease responds to pressure in that area rather than fading globally.
		for zone in range(SMOOTH_ZONES.size()):
			var crease: Vector2 = SMOOTH_ZONES[zone]
			var remaining := 1.0 - smooth_cells[index][zone]
			painter.draw_polyline(PackedVector2Array([crease + Vector2(-7, 1), crease + Vector2(0, -1.5), crease + Vector2(7, 1)]), Color(0.4, 0.29, 0.13, remaining * 0.17), 0.8, true)
			painter.draw_line(crease + Vector2(-5, -0.5), crease + Vector2(4, -1.5), Color(0.97, 0.89, 0.67, remaining * 0.25), 0.8, true)
	painter.draw_set_transform(Vector2.ZERO)
