extends Control

signal continue_requested
signal new_game_requested

const Art = preload("res://scripts/hud_art.gd")
const BOOK: Texture2D = preload("res://IMG/pause_book.png")
const BUTTON: Texture2D = preload("res://IMG/pause_resume.png")
const BOOK_SIZE := Vector2(920, 650)

var book: Control
var title: Label
var note: Label
var continue_button: Button
var new_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book = Control.new()
	book.name = "OpenStartBook"
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

	title = _label("BIBLIOTECA", Vector2(80, 60), Vector2(760, 100), 70)
	title.add_theme_color_override("font_outline_color", Color("a47a44"))
	title.add_theme_constant_override("outline_size", 1)
	_label("Uma livraria, muitas histórias.", Vector2(80, 151), Vector2(760, 42), 25, true)
	continue_button = _button("CONTINUAR", Vector2(180, 212), Vector2(560, 100), 42)
	var strip := StyleBoxTexture.new()
	strip.texture = Art.cutout(BUTTON, Rect2(56, 152, 2064, 400))
	continue_button.add_theme_stylebox_override("normal", strip)
	var hover := strip.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.08, 1.05, 1.0)
	continue_button.add_theme_stylebox_override("hover", hover)
	var pressed := strip.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.9, 0.85, 0.75)
	continue_button.add_theme_stylebox_override("pressed", pressed)
	var disabled := strip.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(0.82, 0.77, 0.65, 0.75)
	continue_button.add_theme_stylebox_override("disabled", disabled)
	continue_button.tooltip_text = "Continuar a partida salva."
	continue_button.pressed.connect(func() -> void: continue_requested.emit())
	new_button = _button("NOVO JOGO", Vector2(210, 332), Vector2(500, 75), 45)
	new_button.tooltip_text = "Começar uma nova história na livraria."
	new_button.pressed.connect(func() -> void: new_game_requested.emit())

	var ornament := Control.new()
	ornament.position = Vector2(210, 416)
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
	note = _label("", Vector2(90, 455), Vector2(740, 78), 20, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _layout_book() -> void:
	var zoom := minf(size.x / 1360.0, size.y / 760.0) * 0.75
	book.scale = Vector2.ONE * zoom
	book.position = Vector2((size.x - BOOK_SIZE.x * zoom) * 0.5, size.y * 0.54 - BOOK_SIZE.y * zoom * 0.5)

func _button(text: String, at: Vector2, dimensions: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Art.handwriting())
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Art.INK)
	button.add_theme_color_override("font_hover_color", Color("160b04"))
	button.add_theme_color_override("font_disabled_color", Color("94764f"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	book.add_child(button)
	return button

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
