extends Control

const Art = preload("res://scripts/hud_art.gd")
const BRASS := Color("a18554")
var wallet := false
var compact := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var edge := PackedVector2Array([
		Vector2(12, 4), Vector2(size.x * 0.28, 2), Vector2(size.x * 0.62, 3), Vector2(size.x - 12, 4),
		Vector2(size.x - 4, 12), Vector2(size.x - 3, size.y - 12), Vector2(size.x - 12, size.y - 4),
		Vector2(size.x * 0.5, size.y - 2), Vector2(12, size.y - 4), Vector2(4, size.y - 12), Vector2(3, 12)
	])
	var shadow := edge.duplicate()
	for index in range(shadow.size()):
		shadow[index] += Vector2(2, 5)
	draw_colored_polygon(shadow, Color(0.035, 0.02, 0.01, 0.65))
	# A quiet, unlettered region of the existing wooden sign provides the grain.
	var uvs := PackedVector2Array()
	for point in edge:
		uvs.append((Vector2(500, 390) + point / size * Vector2(1000, 210)) / Art.PAUSE.get_size())
	draw_polygon(edge, PackedColorArray([Color(0.48, 0.4, 0.31)]), uvs, Art.PAUSE)
	edge.append(edge[0])
	draw_polyline(edge, Color("3b291a"), 4.0, true)
	draw_polyline(edge, Color("917144"), 1.0, true)
	var inset := PackedVector2Array([
		Vector2(17, 10), Vector2(size.x - 17, 10), Vector2(size.x - 10, 17),
		Vector2(size.x - 10, size.y - 17), Vector2(size.x - 17, size.y - 10),
		Vector2(17, size.y - 10), Vector2(10, size.y - 17), Vector2(10, 17), Vector2(17, 10)
	])
	draw_polyline(inset, Color(0.1, 0.065, 0.03, 0.75), 2, true)
	draw_polyline(inset, Color(0.7, 0.54, 0.3, 0.32), 0.7, true)
	for point in [Vector2(17, 16), Vector2(size.x - 17, 16), Vector2(17, size.y - 16), Vector2(size.x - 17, size.y - 16)]:
		draw_circle(point + Vector2(0.8, 1), 2.7, Color("302217"), true, -1, true)
		draw_circle(point, 2.2, BRASS.darkened(0.2), true, -1, true)
		draw_arc(point, 1.8, PI, TAU, 12, Color("c0a16a"), 0.6, true)
		draw_line(point + Vector2(-1, 1), point + Vector2(1, -1), Color("39281a"), 0.7, true)
	if compact:
		return
	if wallet:
		_draw_coins(Vector2(42, size.y * 0.5))
	else:
		_draw_book(Vector2(42, size.y * 0.5))
		draw_line(Vector2(77, 44), Vector2(size.x - 27, 44), Color(0.7, 0.55, 0.35, 0.35), 0.8, true)

func _draw_book(center: Vector2) -> void:
	draw_circle(center + Vector2(1, 2), 23, Color(0.08, 0.05, 0.025, 0.4), true, -1, true)
	draw_arc(center, 23, 0, TAU, 60, BRASS.darkened(0.15), 1.2, true)
	draw_arc(center, 20, 0, TAU, 60, Color(0.65, 0.5, 0.28, 0.5), 0.6, true)
	var book := PackedVector2Array([
		center + Vector2(-14, -9), center + Vector2(-6, -11), center + Vector2(0, -7), center + Vector2(6, -11), center + Vector2(14, -9),
		center + Vector2(14, 10), center + Vector2(6, 8), center + Vector2(0, 12), center + Vector2(-6, 8), center + Vector2(-14, 10), center + Vector2(-14, -9)
	])
	draw_colored_polygon(book, Color(0.6, 0.45, 0.22, 0.12))
	draw_polyline(book, Color("ceb07a"), 1.2, true)
	draw_line(center + Vector2(0, -7), center + Vector2(0, 11), BRASS, 1, true)
	for y in [-4, 1, 6]:
		draw_line(center + Vector2(-11, y), center + Vector2(-4, y - 1), BRASS, 0.7, true)
		draw_line(center + Vector2(4, y - 1), center + Vector2(11, y), BRASS, 0.7, true)

func _draw_coins(center: Vector2) -> void:
	for offset in [Vector2(6, 7), Vector2(-6, 3), Vector2(2, -8)]:
		var point: Vector2 = center + offset
		draw_circle(point + Vector2(1, 2), 10.5, Color("302014"), true, -1, true)
		draw_circle(point, 10, Color("90713e"), true, -1, true)
		draw_arc(point, 9.5, PI, TAU, 24, Color("ceb77a"), 1.0, true)
		draw_arc(point, 7.2, 0, TAU, 32, Color("604824"), 0.9, true)
		draw_line(point + Vector2(-2, -4), point + Vector2(2, -4), Color("d0b77e"), 1, true)
		draw_line(point, point + Vector2(0, 4), Color("d0b77e"), 1, true)
