extends Control

signal resume_requested
signal relaxed_changed(enabled: bool)

const Art = preload("res://scripts/hud_art.gd")
const BOOK: Texture2D = preload("res://IMG/pause_book.png")
const RESUME: Texture2D = preload("res://IMG/pause_resume.png")
const BOOK_SIZE := Vector2(920, 650)

var book: Control
var resume_button: Button
var active_button: Button
var inactive_button: Button

class Clasp extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var edge := PackedVector2Array([Vector2(2, 1), Vector2(17, 1), Vector2(17, 10), Vector2(22, 22), Vector2(23, 47), Vector2(18, 54), Vector2(18, 65), Vector2(3, 65), Vector2(3, 53), Vector2(8, 48), Vector2(8, 24), Vector2(2, 15), Vector2(2, 1)])
		draw_colored_polygon(edge, Color("ac792f"))
		draw_polyline(edge, Color("573716"), 1.5, true)
		for y in [7.0, 35.0, 59.0]:
			draw_circle(Vector2(11, y), 3.5, Color("573716"), true, -1, true)
			draw_circle(Vector2(10.5, y - 0.5), 2.0, Color("e1ad52"), true, -1, true)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book = Control.new()
	book.name = "OpenPauseBook"
	book.size = BOOK_SIZE
	add_child(book)
	var background := TextureRect.new()
	background.texture = BOOK
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = BOOK_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(background)
	resized.connect(_layout_book)
	_layout_book()

	var heading := _label("UMA PAUSA PARA LER", Vector2(70, 75), Vector2(780, 66), 52)
	heading.add_theme_color_override("font_outline_color", Color("a47a44"))
	heading.add_theme_constant_override("outline_size", 1)
	_label("Uma livraria, muitas histórias.", Vector2(80, 144), Vector2(760, 42), 25, true)

	resume_button = Button.new()
	resume_button.text = "RETOMAR"
	resume_button.position = Vector2(180, 212)
	resume_button.size = Vector2(560, 100)
	resume_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resume_button.add_theme_font_override("font", Art.handwriting(false))
	resume_button.add_theme_font_size_override("font_size", 42)
	resume_button.add_theme_color_override("font_color", Art.INK)
	resume_button.add_theme_color_override("font_hover_color", Color("160b04"))
	resume_button.add_theme_color_override("font_pressed_color", Art.INK)
	resume_button.add_theme_color_override("font_focus_color", Art.INK)
	var strip := StyleBoxTexture.new()
	strip.texture = Art.cutout(RESUME, Rect2(56, 152, 2064, 400))
	resume_button.add_theme_stylebox_override("normal", strip)
	var hover := strip.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.08, 1.05, 1.0)
	resume_button.add_theme_stylebox_override("hover", hover)
	var pressed := strip.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.9, 0.85, 0.75)
	resume_button.add_theme_stylebox_override("pressed", pressed)
	resume_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	book.add_child(resume_button)

	_label("Modo tranquilo · sem limite de tempo", Vector2(70, 325), Vector2(780, 38), 24)
	var mode_switch := Panel.new()
	mode_switch.position = Vector2(310, 382)
	mode_switch.size = Vector2(300, 50)
	mode_switch.add_theme_stylebox_override("panel", _pill(Color("e5bf7e"), 24))
	book.add_child(mode_switch)
	var group := ButtonGroup.new()
	active_button = _mode_button("Ativado", Vector2(4, 4), group, true)
	inactive_button = _mode_button("Desativado", Vector2(151, 4), group, false)
	mode_switch.add_child(active_button)
	mode_switch.add_child(inactive_button)
	active_button.pressed.connect(func() -> void: relaxed_changed.emit(true))
	inactive_button.pressed.connect(func() -> void: relaxed_changed.emit(false))
	var clasp := Clasp.new()
	clasp.position = Vector2(138, -8)
	clasp.size = Vector2(26, 66)
	mode_switch.add_child(clasp)
	set_relaxed(false)

	var ornament := Control.new()
	ornament.position = Vector2(210, 444)
	ornament.size = Vector2(500, 34)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(ornament)
	for x in [0.0, 278.0]:
		var line := ColorRect.new()
		line.position = Vector2(x, 16)
		line.size = Vector2(222, 1)
		line.color = Color("87602f")
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ornament.add_child(line)
	var icon := Art.BookStamp.new()
	icon.position = Vector2(226, -3)
	icon.size = Vector2(48, 40)
	ornament.add_child(icon)
	var note := _label("O atendimento e a chegada de clientes estão pausados.\nEsc para retomar. O progresso é salvo entre dias.", Vector2(90, 480), Vector2(740, 65), 20, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _layout_book() -> void:
	var zoom := minf(size.x / 1360.0, size.y / 760.0) * 0.75
	book.scale = Vector2.ONE * zoom
	book.position = Vector2((size.x - BOOK_SIZE.x * zoom) * 0.5, size.y * 0.54 - BOOK_SIZE.y * zoom * 0.5)

func set_relaxed(enabled: bool) -> void:
	active_button.set_pressed_no_signal(enabled)
	inactive_button.set_pressed_no_signal(not enabled)

func _mode_button(text: String, at: Vector2, group: ButtonGroup, left: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = Vector2(145, 42)
	button.toggle_mode = true
	button.button_group = group
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Art.handwriting())
	button.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Art.INK)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var background := Color("e7c996")
		if state in ["pressed", "hover_pressed"]:
			background = Color("c18b35")
		elif state == "hover":
			background = Color("f1d7a5")
		var style := _pill(background, 18)
		style.shadow_size = 0
		style.corner_radius_top_right = 0 if left else 18
		style.corner_radius_bottom_right = 0 if left else 18
		style.corner_radius_top_left = 18 if left else 0
		style.corner_radius_bottom_left = 18 if left else 0
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("6b431f")
		button.add_theme_stylebox_override(state, style)
	return button

func _pill(background: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("795329")
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.2, 0.09, 0.02, 0.25)
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 2)
	return style

func _label(text: String, at: Vector2, dimensions: Vector2, font_size: int, italic := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Art.handwriting(italic))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Art.INK)
	book.add_child(label)
	return label
