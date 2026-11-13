extends RefCounted
## Shared cover finish. The title's original illustration stays untouched; only
## the selected copy's binding and surface change. Cached once per title/condition.

static var _finishes: Dictionary = {}

static func texture_for(book: Dictionary, condition: String = "novo") -> Texture2D:
	var source := book.get("cover_texture") as Texture2D
	var finish := condition if condition in ["danificado", "usado", "novo", "raro"] else "novo"
	var tint: Color = book.get("cover_color", Color("384744"))
	var key := "%s:%s:%s:%s" % [str(book.get("id", "")), source.get_instance_id() if source != null else 0, tint.to_html(), finish]
	if _finishes.has(key) and is_instance_valid(_finishes[key].viewport):
		return _finishes[key].texture
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return source
	var viewport := SubViewport.new()
	viewport.name = "CoverFinish_" + str(book.get("id", "book")) + "_" + finish
	viewport.size = Vector2i(384, 576)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var artwork := Binding.new()
	artwork.source = source
	artwork.condition = finish
	artwork.leather = tint
	artwork.size = Vector2(384, 576)
	viewport.add_child(artwork)
	tree.root.add_child(viewport)
	var texture := viewport.get_texture()
	_finishes[key] = {"viewport": viewport, "texture": texture}
	return texture

static func apply(image: TextureRect, book: Dictionary, condition: String) -> void:
	image.texture = texture_for(book, condition)
	image.set_meta("condition", condition)
	image.set_meta("book_id", str(book.get("id", "")))
	image.tooltip_text = "%s · %s" % [str(book.get("title", "Livro")), str(BookCatalog.get_condition(condition).label)]

class Binding extends Control:
	var source: Texture2D
	var condition := "novo"
	var leather := Color("384744")
	const FACE := Rect2(24, 9, 150, 263)
	const GOLD := Color("d8ad55")
	const PALE_GOLD := Color("f0d68f")

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
		var damaged := condition == "danificado"
		var rare := condition == "raro"
		# Page block and boards create a bound volume, even at inventory size.
		draw_style_box(_box(Color(0.07, 0.04, 0.02, 0.22), 3), Rect2(23, 13, 158, 264))
		draw_style_box(_box(Color("4b3525"), 2), Rect2(25, 12, 153, 265))
		draw_rect(Rect2(172, 17, 5, 253), Color("b9a078") if not rare else Color("ba862b"))
		for y in range(20, 270, 4):
			draw_line(Vector2(173, y), Vector2(177, y), Color("8f7856") if not rare else GOLD, 0.7, true)
		draw_line(Vector2(28, 274), Vector2(173, 274), Color("bba27b") if not rare else GOLD, 2, true)
		if damaged:
			_draw_damaged()
		else:
			_draw_face(FACE, Color.WHITE if condition != "usado" else Color(0.83, 0.79, 0.70))
			_draw_spine(false, rare)
			if condition == "usado":
				_draw_wear()
			elif rare:
				_draw_gilding()

	func _box(color: Color, radius: int) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(radius)
		return box

	func _draw_face(rect: Rect2, color: Color) -> void:
		if source != null:
			draw_texture_rect(source, rect, false, color)
		else:
			draw_rect(rect, leather * color)
			draw_rect(rect.grow(-9), Color("a68a52") * color, false, 1.5)
			draw_rect(rect.grow(-13), Color("a68a52") * color, false, 0.7)
			var center := rect.get_center()
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -25), center + Vector2(18, 0), center + Vector2(0, 25), center + Vector2(-18, 0)]), Color("a68a52") * color)

	func _draw_spine(detached: bool, rare: bool) -> void:
		var spine := PackedVector2Array([Vector2(12, 10), Vector2(24, 9), Vector2(24, 272), Vector2(12, 274)])
		if detached:
			spine = PackedVector2Array([Vector2(7, 15), Vector2(19, 13), Vector2(23, 263), Vector2(11, 269), Vector2(8, 258), Vector2(9, 144)])
		draw_colored_polygon(spine, Color("3b2d24") if detached else Color("272521"))
		# A narrow strip of the same cover ties the binding to its title.
		if source != null:
			var uv := PackedVector2Array()
			for point in spine:
				uv.append(Vector2(0.02 + (point.x - 7) / 17 * 0.07, clampf((point.y - 10) / 264, 0, 1)))
			draw_polygon(spine, PackedColorArray([Color(0.42, 0.36, 0.27) if detached else Color(0.5, 0.45, 0.36)]), uv, source)
		draw_polyline(spine, Color("846343") if detached else Color("534435"), 1.2, true)
		for y in [38, 56, 224, 242]:
			draw_line(Vector2(12, y), Vector2(23, y - 1), GOLD if rare else Color("8d7653"), 2.2 if rare else 1, true)
		if not detached:
			draw_line(Vector2(25, 13), Vector2(25, 268), Color(0.02, 0.015, 0.01, 0.6), 2, true)
			draw_line(Vector2(27, 14), Vector2(27, 267), Color(1, 0.9, 0.67, 0.12), 1, true)

	func _draw_wear() -> void:
		# Small rubbed corners and thin abrasions, without a broken binding.
		for corner: Vector2 in [Vector2(26, 11), Vector2(172, 11), Vector2(26, 270), Vector2(172, 270)]:
			var inward := (FACE.get_center() - corner).normalized()
			draw_line(corner, corner + inward * 11, Color(0.72, 0.59, 0.40, 0.6), 2.3, true)
		for mark: Vector4 in [Vector4(45, 73, 53, 71), Vector4(150, 202, 157, 196), Vector4(39, 243, 44, 240), Vector4(159, 48, 163, 45)]:
			draw_line(Vector2(mark.x, mark.y), Vector2(mark.z, mark.w), Color(0.8, 0.69, 0.49, 0.48), 1.1, true)
		draw_line(Vector2(29, 25), Vector2(29, 257), Color(0.66, 0.55, 0.40, 0.36), 1.4, true)

	func _draw_damaged() -> void:
		# Clipped cover reveals board under torn corners; the spine hangs loose.
		var outline := PackedVector2Array([Vector2(30, 10), Vector2(144, 11), Vector2(147, 17), Vector2(156, 18), Vector2(153, 26), Vector2(165, 23), Vector2(173, 33), Vector2(171, 198), Vector2(164, 207), Vector2(170, 218), Vector2(170, 267), Vector2(55, 271), Vector2(51, 263), Vector2(41, 267), Vector2(44, 256), Vector2(31, 252)])
		var uv := PackedVector2Array()
		for point in outline:
			uv.append((point - FACE.position) / FACE.size)
		if source != null:
			draw_polygon(outline, PackedColorArray([Color(0.66, 0.60, 0.48)]), uv, source)
		else:
			draw_colored_polygon(outline, leather * Color(0.66, 0.60, 0.48))
		var edge := outline.duplicate()
		edge.append(outline[0])
		draw_polyline(edge, Color("977b50"), 1.8, true)
		# Linen ties remain between the board and the separated spine.
		for y in [60, 137, 229]:
			draw_line(Vector2(17, y), Vector2(32, y + 2), Color("30251c"), 5, true)
			draw_line(Vector2(17, y), Vector2(32, y + 2), Color("b9a17a"), 2, true)
		_draw_spine(true, false)
		var tear := PackedVector2Array([Vector2(31, 102), Vector2(59, 111), Vector2(69, 108), Vector2(81, 122), Vector2(103, 124), Vector2(119, 139)])
		draw_polyline(tear, Color("b49a70"), 4.5, true)
		draw_polyline(tear, Color(0.03, 0.02, 0.015, 0.95), 2.1, true)
		var second := PackedVector2Array([Vector2(170, 216), Vector2(152, 208), Vector2(138, 211), Vector2(127, 200)])
		draw_polyline(second, Color("201a16"), 3, true)
		draw_polyline(second, Color("ad8a54"), 0.8, true)
		for i in range(1, tear.size() - 1):
			var p := tear[i]
			draw_line(p, p + Vector2(3, -5), Color("bb9b6c"), 0.9, true)
		draw_colored_polygon(PackedVector2Array([Vector2(144, 11), Vector2(171, 11), Vector2(171, 33), Vector2(165, 23), Vector2(153, 26), Vector2(156, 18)]), Color("aa8a59"))
		draw_line(Vector2(148, 13), Vector2(169, 30), Color("dcc28d"), 1, true)
		for i in range(16):
			var point := Vector2(38 + fmod(i * 47.0, 126), 23 + fmod(i * 83.0, 235))
			draw_line(point, point + Vector2(3 + i % 4, -2), Color(0.65, 0.52, 0.32, 0.45), 1.1, true)

	func _draw_gilding() -> void:
		# Foil follows the cover edges; the central title artwork remains readable.
		draw_rect(Rect2(30, 15, 138, 251), Color("63441c"), false, 3.8)
		draw_rect(Rect2(30, 15, 138, 251), GOLD, false, 1.7)
		draw_rect(Rect2(34, 19, 130, 243), Color(0.94, 0.80, 0.45, 0.7), false, 0.7)
		for corner: Vector2 in [Vector2(29, 14), Vector2(169, 14), Vector2(29, 267), Vector2(169, 267)]:
			var sx := 1.0 if corner.x < 100 else -1.0
			var sy := 1.0 if corner.y < 140 else -1.0
			var points := PackedVector2Array([corner, corner + Vector2(20 * sx, 0), corner + Vector2(15 * sx, 5 * sy), corner + Vector2(10 * sx, 5 * sy), corner + Vector2(5 * sx, 10 * sy), corner + Vector2(5 * sx, 15 * sy), corner + Vector2(0, 20 * sy)])
			draw_colored_polygon(points, Color("67471f"))
			for i in range(points.size()):
				points[i] += Vector2(sx, sy)
			draw_colored_polygon(points, GOLD)
			draw_line(corner + Vector2(2 * sx, 17 * sy), corner + Vector2(2 * sx, 2 * sy), PALE_GOLD, 1, true)
			draw_line(corner + Vector2(2 * sx, 2 * sy), corner + Vector2(17 * sx, 2 * sy), PALE_GOLD, 1, true)
		var seal := Vector2(99, 242)
		draw_circle(seal + Vector2(0, 1), 10, Color("3e2c18"), true, -1, true)
		draw_circle(seal, 8.5, GOLD, true, -1, true)
		draw_arc(seal, 6.3, 0, TAU, 24, Color("80551e"), 1, true)
		draw_colored_polygon(PackedVector2Array([seal + Vector2(0, -4), seal + Vector2(3, 0), seal + Vector2(0, 4), seal + Vector2(-3, 0)]), Color("67471f"))
		draw_line(Vector2(33, 16), Vector2(165, 16), PALE_GOLD, 0.8, true)
