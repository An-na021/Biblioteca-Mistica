extends RefCounted

# Reuse the game's existing wood, parchment and serif typography.
const Art = preload("res://scripts/hud_art.gd")
const GOLD := Color("b79966")
const IVORY := Color("edd3a2")
const INK := Color("352316")

static func style_tool(button: Button, metal: bool) -> Control:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Art.handwriting(false))
	button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var blank := StyleBoxEmpty.new()
		blank.set_content_margin_all(10)
		button.add_theme_stylebox_override(state, blank)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, IVORY)
	button.add_theme_color_override("font_disabled_color", Color("aa9270"))
	button.add_theme_color_override("font_outline_color", Color("2d1b10"))
	button.add_theme_constant_override("outline_size", 2)
	var backing := ToolPlate.new()
	backing.metal = metal
	button.add_child(backing)
	return backing

class Ornament:
	static func corner(painter: Control, origin: Vector2, flip: Vector2, extent: float, color: Color) -> void:
		painter.draw_set_transform(origin, 0, flip * (extent / 25.0))
		painter.draw_polyline(PackedVector2Array([Vector2(0, 24), Vector2(0, 0), Vector2(24, 0)]), color, 1, true)
		var curl := Curve2D.new()
		curl.add_point(Vector2(3, 22), Vector2.ZERO, Vector2(13, -1))
		curl.add_point(Vector2(13, 8), Vector2(8, 5), Vector2(-3, -9))
		curl.add_point(Vector2(6, 9), Vector2(1, -5), Vector2(-1, 5))
		curl.add_point(Vector2(10, 13), Vector2(-3, 1))
		painter.draw_polyline(curl.tessellate(), color, 1, true)
		painter.draw_polyline(PackedVector2Array([Vector2(5, 3), Vector2(8, 1), Vector2(11, 3), Vector2(8, 5), Vector2(5, 3)]), color, 1, true)
		painter.draw_set_transform(Vector2.ZERO)

class Frame extends Control:
	var kind := "panel"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var edge := PackedVector2Array()
		if kind in ["paper", "ribbon"]:
			for index in range(25):
				edge.append(Vector2(2 + (size.x - 4) * index / 24.0, 2 + fposmod(index * 7.1, 4)))
			for index in range(24, -1, -1):
				edge.append(Vector2(2 + (size.x - 4) * index / 24.0, size.y - 2 - fposmod(index * 5.3, 4)))
		else:
			edge = PackedVector2Array([Vector2(3, 1), Vector2(size.x - 3, 1), Vector2(size.x - 1, 3), Vector2(size.x - 1, size.y - 2), Vector2(1, size.y - 1), Vector2(1, 3)])
		var shadow := edge.duplicate()
		for index in range(shadow.size()):
			shadow[index] += Vector2(2, 3)
		draw_colored_polygon(shadow, Color(0.04, 0.025, 0.01, 0.55))
		if kind == "paper":
			var uvs := PackedVector2Array()
			for point in edge:
				uvs.append(Vector2(0.2, 0.25) + point / size * Vector2(0.58, 0.43))
			draw_polygon(edge, PackedColorArray([Color(0.88, 0.82, 0.68)]), uvs, Art.DIALOGUE)
		else:
			draw_colored_polygon(edge, Color("241a12"))
			draw_texture_rect_region(Art.PAUSE, Rect2(5, 5, size.x - 10, size.y - 10), Rect2(500, 390, 1000, 210), Color(0.19, 0.16, 0.13, 0.38))
		edge.append(edge[0])
		draw_polyline(edge, Color("997244") if kind == "paper" else Color("8b704d"), 1.1, true)
		if kind == "header":
			for flip in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
				var origin := Vector2(4 if flip.x > 0 else size.x - 4, 4 if flip.y > 0 else size.y - 4)
				Ornament.corner(self, origin, flip, 20, Color("9b8b70"))
			draw_line(Vector2(914, 19), Vector2(914, size.y - 19), Color(0.7, 0.55, 0.34, 0.32), 1, true)
		elif kind == "tools":
			var center := Vector2(size.x * 0.5, 49)
			draw_line(center - Vector2(73, 0), center - Vector2(15, 0), GOLD, 0.8, true)
			draw_line(center + Vector2(15, 0), center + Vector2(73, 0), GOLD, 0.8, true)
			for flip in [-1, 1]:
				draw_arc(center + Vector2(flip * 7, 0), 5, 0, TAU, 20, GOLD, 0.8, true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0)]), GOLD)

class ToolPlate extends Control:
	var metal := false
	var selected := false:
		set(value):
			if selected != value:
				selected = value
				queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)
		var button := get_parent() as Button
		for event in [button.mouse_entered, button.mouse_exited, button.button_down, button.button_up, button.focus_entered, button.focus_exited]:
			event.connect(queue_redraw)

	func _draw() -> void:
		var button := get_parent() as Button
		var hot := button.is_hovered() or button.has_focus()
		var tint := Color("96734c") if selected else Color("61594a") if metal else Color("795035")
		if button.disabled:
			tint = tint.darkened(0.22)
		elif button.is_pressed():
			tint = tint.darkened(0.15)
		elif hot:
			tint = tint.lightened(0.06)
		var edge := PackedVector2Array([Vector2(5, 1), Vector2(size.x - 5, 1), Vector2(size.x - 1, 5), Vector2(size.x - 2, size.y - 5), Vector2(size.x - 6, size.y - 1), Vector2(4, size.y - 1), Vector2(1, size.y - 5), Vector2(2, 5)])
		var shadow := edge.duplicate()
		for index in range(shadow.size()):
			shadow[index] += Vector2(1, 3)
		draw_colored_polygon(shadow, Color(0.04, 0.02, 0.01, 0.65))
		draw_colored_polygon(edge, tint.darkened(0.26))
		var face := Rect2(5, 5, size.x - 10, size.y - 10)
		if metal and not selected:
			draw_rect(face, tint)
			draw_texture_rect_region(Art.PAUSE, face, Rect2(500, 390, 1000, 210), Color(0.5, 0.48, 0.44, 0.18))
		else:
			draw_texture_rect_region(Art.PAUSE, face, Rect2(500, 390, 1000, 210), Color(tint, 1))
		edge.append(edge[0])
		draw_polyline(edge, Color("af8d57") if selected or hot else Color("8d6e50"), 1.5, true)
		draw_rect(Rect2(7, 6, size.x - 14, size.y - 13), Color("907047") if selected else Color("4b3829"), false, 0.8, true)
		for flip in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var origin := Vector2(9 if flip.x > 0 else size.x - 9, 8 if flip.y > 0 else size.y - 9)
			if metal and not selected:
				draw_circle(origin + flip * 2, 1.7, Color("c6ad81"), true, -1, true)
			else:
				Ornament.corner(self, origin, flip, 11, Color(0.3, 0.18, 0.09, 0.75))
