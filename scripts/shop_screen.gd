extends Control

const GOLD := Color("e4c477")
const MUTED := Color("cbbfa7")

func build_panel(heading: String, subtitle: String, panel_size := Vector2(680, 500)) -> VBoxContainer:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("201f19")
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	layout.add_child(label(heading, 24, GOLD))
	var detail := label(subtitle, 13)
	detail.custom_minimum_size.x = panel_size.x - 48
	layout.add_child(detail)
	return layout

func label(text: String, font_size := 14, color := MUTED) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 40
	node.add_theme_font_size_override("font_size", 14)
	node.add_theme_color_override("font_color", Color("f3ead6"))
	node.add_theme_color_override("font_hover_color", Color("211b12"))
	node.add_theme_color_override("font_pressed_color", Color("211b12"))
	node.add_theme_color_override("font_disabled_color", Color("918974"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("3b4033")
	normal.border_color = Color("8e7543")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.set_content_margin(SIDE_LEFT, 12.0)
	normal.set_content_margin(SIDE_RIGHT, 12.0)
	node.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = GOLD
	hover.border_color = Color("fff0c7")
	node.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("b9954f")
	node.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("292b25")
	disabled.border_color = Color("514b3a")
	node.add_theme_stylebox_override("disabled", disabled)
	node.pressed.connect(callback)
	parent.add_child(node)
	return node
