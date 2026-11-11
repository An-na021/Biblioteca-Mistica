extends RefCounted

const HOLES := [Vector2(586, 262), Vector2(612, 262), Vector2(586, 335), Vector2(612, 335), Vector2(586, 408), Vector2(612, 408), Vector2(586, 481), Vector2(612, 481)]
const INSERT_SECONDS := 0.45
const SETTLE_SECONDS := 0.4
const PULL_DISTANCE := 60.0
const BOOK_RECT := Rect2(253, 164, 690, 451)
const THREAD := Color("bba278")
enum Phase { READY, INSERTING, PULLING, SETTLING, COMPLETE }

var count := 0
var phase: int = Phase.READY
var held := false
var time := 0.0
var pull := 0.0
var needle_tip := Vector2(657, 287)
var angle := 0.55
var message := "Segure a agulha no primeiro furo dourado para atravessar o papel."
var _pointer := needle_tip
var _grab_offset := Vector2.ZERO
var _settle_tip := Vector2.ZERO

func outward() -> Vector2:
	return Vector2.LEFT if count % 2 == 0 else Vector2.RIGHT

func begin(point: Vector2) -> void:
	_pointer = point
	if phase == Phase.READY:
		if point.distance_to(HOLES[count]) > 13:
			message = "Comece pelo furo dourado. Os outros furos ainda não recebem a agulha."
			return
		needle_tip = HOLES[count]
		angle = -0.5 if count % 2 == 0 else 0.5
		held = true
		time = 0.0
		phase = Phase.INSERTING
		message = "Mantenha o botão pressionado enquanto a agulha atravessa o papel."
	elif phase == Phase.PULLING:
		var eye := needle_tip + Vector2(0, -67 * needle_length()).rotated(angle)
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point, needle_tip, eye)) <= 18:
			held = true
			_grab_offset = needle_tip - point
		else:
			message = "Pegue a agulha pela haste e continue puxando a linha para firmar o ponto."

func move(point: Vector2) -> void:
	_pointer = point
	if not held:
		return
	if phase == Phase.INSERTING:
		if point.distance_to(HOLES[count]) > 22:
			release()
			message = "A agulha saiu do furo antes de atravessar. Segure novamente no furo dourado."
	elif phase == Phase.PULLING:
		needle_tip = point + _grab_offset
		var distance: Vector2 = needle_tip - HOLES[count]
		pull = clampf(distance.dot(outward()) / PULL_DISTANCE, 0.0, 1.0)
		if distance.length() > 10 and distance.normalized().dot(outward()) < 0.65:
			message = "Puxe para fora da lombada, seguindo a seta; a linha ainda está frouxa."
		else:
			message = "Puxe devagar até a linha ficar firme."
		if pull >= 1.0 and distance.normalized().dot(outward()) >= 0.65:
			phase = Phase.SETTLING
			time = 0.0
			held = false
			_settle_tip = needle_tip
			message = "Acomodando a linha e apertando o ponto."

func release() -> void:
	held = false
	if phase == Phase.INSERTING:
		phase = Phase.READY
		time = 0.0
		message = "A agulha ainda não atravessou. Segure no furo dourado por um instante."
	elif phase == Phase.PULLING:
		message = "A linha ainda está frouxa. Pegue a agulha para terminar de puxar."

func advance(delta: float) -> void:
	if phase == Phase.READY:
		needle_tip = needle_tip.lerp(_pointer, 1.0 - exp(-delta * 25.0))
		angle = lerp_angle(angle, 0.55, 1.0 - exp(-delta * 10.0))
	elif phase == Phase.INSERTING and held:
		time += delta
		if time >= INSERT_SECONDS:
			phase = Phase.PULLING
			needle_tip = HOLES[count]
			_grab_offset = needle_tip - _pointer
			pull = 0.0
			message = "Agulha passada. Puxe para a esquerda." if count % 2 == 0 else "Agulha passada. Puxe para a direita."
	elif phase == Phase.SETTLING:
		time += delta
		if time >= SETTLE_SECONDS:
			count += 1
			pull = 0.0
			phase = Phase.COMPLETE if count == HOLES.size() else Phase.READY
			message = "Costura terminada e nó de acabamento firme." if phase == Phase.COMPLETE else "Ponto firme. Continue pelo próximo furo dourado."

func instruction() -> String:
	match phase:
		Phase.INSERTING:
			return "Segure: a agulha está atravessando o papel."
		Phase.PULLING:
			return "Puxe a agulha para a esquerda para firmar a linha." if count % 2 == 0 else "Puxe a agulha para a direita para firmar a linha."
		Phase.SETTLING:
			return "A linha está se acomodando. Aguarde o ponto ficar firme."
	return "Segure no furo dourado e puxe a agulha para o lado indicado."

func needle_length() -> float:
	if phase == Phase.INSERTING:
		return lerpf(1.0, 0.22, clampf(time / INSERT_SECONDS, 0, 1))
	if phase == Phase.PULLING:
		return lerpf(0.22, 1.0, pull)
	return 1.0

func paint(painter: Control, elapsed: float, show_needle: bool) -> void:
	# Four small bridges cross the fold; vertical joins sit in the recessed spine.
	for row in range(4):
		var left: Vector2 = HOLES[row * 2]
		var right: Vector2 = HOLES[row * 2 + 1]
		if count >= row * 2 + 2:
			_thread(painter, left, right, Vector2(0, 3), 1.0)
			if row > 0:
				_thread(painter, Vector2(600, HOLES[row * 2 - 1].y), Vector2(600, right.y), Vector2(-3, 0), 0.65)
			# Waxed linen turns once around each pierced paper edge.
			for hole in [left, right]:
				painter.draw_arc(hole + Vector2(0, 1), 3.8, -0.6, PI + 0.6, 18, THREAD.darkened(0.25), 2, true)
	for index in range(HOLES.size()):
		var hole: Vector2 = HOLES[index]
		painter.draw_set_transform(hole, 0, Vector2(1, 0.65))
		painter.draw_circle(Vector2(0.8, 1.4), 4.5, Color(0.19, 0.12, 0.055, 0.35), true, -1, true)
		painter.draw_circle(Vector2.ZERO, 3.0, Color("392719"), true, -1, true)
		painter.draw_arc(Vector2.ZERO, 4, 0.1, PI, 14, Color(0.65, 0.46, 0.25, 0.7), 0.8, true)
		painter.draw_set_transform(Vector2.ZERO)
	if phase != Phase.COMPLETE:
		var target: Vector2 = HOLES[count]
		if phase == Phase.READY:
			painter.draw_arc(target, 7.5 + sin(elapsed * 4) * 0.8, 0, TAU, 32, Color(0.92, 0.75, 0.4, 0.65), 1.2, true)
		elif phase == Phase.INSERTING:
			painter.draw_arc(target, 9, -PI * 0.5, -PI * 0.5 + TAU * minf(1, time / INSERT_SECONDS), 30, Color("c5a66e"), 1.5, true)
		elif phase == Phase.PULLING:
			var end := target + outward() * PULL_DISTANCE
			painter.draw_line(target + outward() * 16, end, Color(0.6, 0.45, 0.24, 0.5), 1, true)
			painter.draw_polyline(PackedVector2Array([end + Vector2(-outward().x * 7, -4), end, end + Vector2(-outward().x * 7, 4)]), Color("a0824d"), 1.3, true)
		if phase in [Phase.PULLING, Phase.SETTLING]:
			var slack := (1.0 - pull) * 30.0
			var tip := needle_tip
			if phase == Phase.SETTLING:
				var t := clampf(time / SETTLE_SECONDS, 0, 1)
				slack = sin(t * PI) * 7
				tip = _settle_tip.lerp(target + outward() * PULL_DISTANCE, t)
			var eye := tip + Vector2(0, -67 * needle_length()).rotated(angle)
			_thread(painter, target, eye, Vector2(outward().x * slack, slack + 7), 0.85)
			# The remaining loop at the hole shrinks as linen is pulled through.
			if slack > 1:
				_thread(painter, target, target + Vector2(2, 1), Vector2(outward().x * slack, slack * 0.6), 1.0)
			if count % 2 == 1:
				_thread(painter, HOLES[count - 1], target, Vector2(0, slack * 0.4 + 3), 1.0)
	if count >= HOLES.size() or phase == Phase.SETTLING and count == HOLES.size() - 1:
		var knot: Vector2 = HOLES.back()
		painter.draw_arc(knot + Vector2(-1.5, -0.5), 2.5, 0, TAU, 16, THREAD, 1.3, true)
		painter.draw_arc(knot + Vector2(1.5, 1), 2.2, 0, TAU, 16, THREAD.darkened(0.15), 1.3, true)
		painter.draw_line(knot, knot + Vector2(8, 5), THREAD, 1.2, true)
	if show_needle and (BOOK_RECT.has_point(_pointer) or phase in [Phase.INSERTING, Phase.PULLING, Phase.SETTLING]):
		var eye := needle_tip + Vector2(0, -67 * needle_length()).rotated(angle)
		if phase in [Phase.READY, Phase.INSERTING]:
			var anchor: Vector2 = HOLES[count - 1] if count > 0 else eye + Vector2(22, 26)
			_thread(painter, anchor, eye, Vector2(17, 20), 0.75)
		_paint_needle(painter, needle_tip, angle, needle_length())

func _thread(painter: Control, start: Vector2, end: Vector2, sag: Vector2, opacity: float) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var t := index / 24.0
		points.append(start.lerp(end, t) + sin(t * PI) * sag)
	var shadow := points.duplicate()
	for index in range(shadow.size()):
		shadow[index] += Vector2(1.2, 1.8)
	painter.draw_polyline(shadow, Color(0.12, 0.07, 0.025, opacity * 0.55), 2.6, true)
	painter.draw_polyline(points, Color(THREAD.darkened(0.25), opacity), 2.0, true)
	painter.draw_polyline(points, Color(THREAD, opacity), 0.9, true)
	for index in range(2, points.size() - 1, 3):
		painter.draw_line(points[index] + Vector2(-0.5, 0.6), points[index] + Vector2(0.7, -0.6), Color(0.9, 0.8, 0.6, opacity * 0.6), 0.5, true)

func _paint_needle(painter: Control, tip: Vector2, rotation: float, length_ratio: float) -> void:
	# Tapered steel shaft, an actual open eye, and asymmetric reflected window light.
	painter.draw_set_transform(tip + Vector2(2.5, 3), rotation, Vector2(1, length_ratio))
	painter.draw_line(Vector2.ZERO, Vector2(0, -71), Color(0.1, 0.07, 0.03, 0.22), 3, true)
	painter.draw_set_transform(tip, rotation, Vector2(1, length_ratio))
	var shaft := PackedVector2Array([Vector2(0, 0), Vector2(-1.4, -8), Vector2(-1.8, -60), Vector2(0, -63), Vector2(1.8, -60), Vector2(1.4, -8)])
	painter.draw_polygon(shaft, PackedColorArray([Color("d4d4bf"), Color("626d6b"), Color("707772"), Color("d6d6c2"), Color("bcbda9"), Color("d8d8c2")]))
	painter.draw_line(Vector2(0.5, -7), Vector2(0.5, -60), Color("e0dec7"), 0.7, true)
	var eye := PackedVector2Array()
	for index in range(25):
		var t := TAU * index / 24.0
		eye.append(Vector2(cos(t) * 2.2, -67 + sin(t) * 6))
	painter.draw_polyline(eye, Color("a6ada2"), 1.4, true)
	painter.draw_line(Vector2(1.5, -70), Vector2(1.5, -64), Color("e1deca"), 0.7, true)
	painter.draw_set_transform(Vector2.ZERO)
