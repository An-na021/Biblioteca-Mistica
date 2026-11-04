extends RefCounted


static func apply(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Noto Sans", "sans-serif"])
	font.font_weight = 600
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 15)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("302014"))
	button.add_theme_color_override("font_disabled_color", Color("78664e"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin(SIDE_LEFT, 14)
		empty.set_content_margin(SIDE_RIGHT, 14)
		button.add_theme_stylebox_override(state, empty)
	if not button.has_node("BackButtonWood"):
		var backing := WoodBacking.new()
		backing.name = "BackButtonWood"
		button.add_child(backing)


class WoodBacking extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(queue_redraw)
		var button := get_parent() as Button
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)
		button.focus_entered.connect(queue_redraw)
		button.focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var button := get_parent() as Button
		var fill := Color("ba905f")
		if button.disabled:
			fill = Color("a99577")
		elif button.is_pressed():
			fill = fill.darkened(0.15)
		elif button.is_hovered() or button.has_focus():
			fill = fill.lightened(0.2)
		var edge := PackedVector2Array([
			Vector2(5, 2), Vector2(size.x * 0.3, 3), Vector2(size.x * 0.57, 1),
			Vector2(size.x - 5, 2), Vector2(size.x - 1, 7),
			Vector2(size.x - 3, size.y - 5), Vector2(size.x - 7, size.y - 1),
			Vector2(size.x * 0.55, size.y - 2), Vector2(3, size.y - 1),
			Vector2(1, size.y - 6), Vector2(3, 7), Vector2(5, 2)
		])
		var shadow := edge.duplicate()
		for index in range(shadow.size()):
			shadow[index] += Vector2(1, 3)
		draw_colored_polygon(shadow, Color(0.16, 0.08, 0.03, 0.4))
		draw_colored_polygon(edge, fill)
		draw_polyline(edge, Color("735035"), 1.6, true)
		var inset := PackedVector2Array([
			Vector2(8, 7), Vector2(size.x * 0.55, 6), Vector2(size.x - 8, 7),
			Vector2(size.x - 9, size.y - 7), Vector2(8, size.y - 6), Vector2(8, 7)
		])
		draw_polyline(inset, Color(0.4, 0.25, 0.12, 0.46), 0.8, true)
		for index in range(4):
			var y := 9.0 + float(index) * (size.y - 18.0) / 3.0
			draw_polyline(PackedVector2Array([
				Vector2(10, y), Vector2(size.x * 0.3, y + 0.7),
				Vector2(size.x * 0.65, y - 0.6), Vector2(size.x - 10, y)
			]), Color(0.3, 0.16, 0.06, 0.18), 0.7, true)
		if (button.is_hovered() or button.has_focus()) and not button.disabled:
			draw_polyline(edge, Color(1, 0.94, 0.8, 0.9), 1.6, true)
