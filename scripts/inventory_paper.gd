extends RefCounted

class Note extends PanelContainer:
	var paper_color := Color("dfc38e")

	func _ready() -> void:
		var margins := StyleBoxEmpty.new()
		margins.set_content_margin_all(10.0)
		margins.content_margin_left = 17.0
		add_theme_stylebox_override("panel", margins)
		resized.connect(queue_redraw)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var outline := PackedVector2Array([
			Vector2(2, 1), Vector2(size.x * 0.27, 0), Vector2(size.x * 0.58, 3),
			Vector2(size.x - 2, 1), Vector2(size.x, size.y * 0.36),
			Vector2(size.x - 3, size.y * 0.68), Vector2(size.x - 1, size.y - 2),
			Vector2(size.x * 0.65, size.y), Vector2(size.x * 0.33, size.y - 2),
			Vector2(0, size.y - 1), Vector2(3, size.y * 0.55), Vector2(0, size.y * 0.3), Vector2(2, 1)
		])
		var shadow := outline.duplicate()
		for index in range(shadow.size()):
			shadow[index] += Vector2(2, 4)
		draw_colored_polygon(shadow, Color(0.15, 0.08, 0.03, 0.18))
		draw_colored_polygon(outline, paper_color)
		draw_polyline(outline, Color(0.35, 0.23, 0.11, 0.55), 1.0, true)
		draw_line(Vector2(8, 1), Vector2(5, 11), Color("524432"), 2.0, true)
		draw_circle(Vector2(10, 1), 4.0, Color("534e43"), true, -1, true)
		draw_circle(Vector2(9, 0), 2.6, Color("a7a496"), true, -1, true)

class Entry extends PanelContainer:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var ink := Color(0.25, 0.15, 0.07, 0.50)
		var top := PackedVector2Array([Vector2(0, 2), Vector2(size.x * 0.3, 0), Vector2(size.x * 0.55, 3), Vector2(size.x * 0.8, 0), Vector2(size.x, 2)])
		draw_polyline(top, ink, 1.2, true)
		var y := 35.0
		while y < size.y - 10.0:
			draw_line(Vector2(size.x * 0.57, y), Vector2(size.x - 2, y + 1), Color(0.35, 0.24, 0.12, 0.16), 1.0, true)
			y += 30.0
		draw_line(Vector2(size.x - 143, 8), Vector2(size.x - 141, size.y - 6), Color(0.35, 0.24, 0.12, 0.28), 1.0, true)

class ButtonBacking extends Control:
	var wooden := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)
		var button := get_parent() as BaseButton
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)

	func _draw() -> void:
		var button := get_parent() as BaseButton
		var color := Color("b88d5d") if wooden else Color("dfc18b")
		if button.disabled:
			color = Color("bca682")
		elif button.is_pressed():
			color = color.darkened(0.12)
		elif button.is_hovered():
			color = color.lightened(0.14)
		var edge := PackedVector2Array([
			Vector2(4, 1), Vector2(size.x * 0.24, 2), Vector2(size.x * 0.6, 0),
			Vector2(size.x - 3, 1), Vector2(size.x, 5), Vector2(size.x - 1, size.y * 0.7),
			Vector2(size.x - 4, size.y - 1), Vector2(size.x * 0.7, size.y - 2),
			Vector2(size.x * 0.38, size.y), Vector2(2, size.y - 1),
			Vector2(0, size.y - 5), Vector2(2, size.y * 0.35), Vector2(0, 5), Vector2(4, 1)
		])
		var shadow := edge.duplicate()
		for index in range(shadow.size()):
			shadow[index] += Vector2(1, 2)
		draw_colored_polygon(shadow, Color(0.16, 0.08, 0.03, 0.22))
		draw_colored_polygon(edge, color)
		draw_polyline(edge, Color("705033"), 1.2, true)
		if wooden:
			for index in range(5):
				var y := 5.0 + float(index) * (size.y - 10.0) / 4.0
				draw_polyline(PackedVector2Array([Vector2(6, y), Vector2(size.x * 0.32, y + 1), Vector2(size.x * 0.64, y - 1), Vector2(size.x - 6, y)]), Color(0.27, 0.13, 0.04, 0.16), 0.7, true)
		else:
			draw_line(Vector2(size.x - 12, 1), Vector2(size.x - 7, 6), Color(0.35, 0.23, 0.11, 0.4), 1.0, true)

class Mark extends PanelContainer:
	var tint := Color("aab478")

	func _ready() -> void:
		resized.connect(queue_redraw)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var edge := PackedVector2Array([
			Vector2(0, size.y * 0.3), Vector2(6, 2), Vector2(size.x * 0.3, 0),
			Vector2(size.x * 0.62, 2), Vector2(size.x - 6, 0), Vector2(size.x, 6),
			Vector2(size.x - 3, size.y * 0.5), Vector2(size.x, size.y - 4),
			Vector2(size.x - 8, size.y), Vector2(size.x * 0.48, size.y - 1),
			Vector2(4, size.y), Vector2(0, size.y - 4)
		])
		draw_colored_polygon(edge, Color(tint, 0.7))
