extends RefCounted

const INK := Color("322115")
const DIALOGUE: Texture2D = preload("res://IMG/dialogue_parchment.png")
const STATUS: Texture2D = preload("res://IMG/status_parchment.png")
const PAUSE: Texture2D = preload("res://IMG/pause_wood.png")

static func cutout(source: Texture2D, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = region
	return texture

static func handwriting(italic := true) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	font.font_italic = italic
	return font

static func style_pause(button: Button) -> void:
	button.add_theme_font_override("font", handwriting(false))
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("201209"))
	button.add_theme_color_override("font_pressed_color", INK)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxTexture.new()
	normal.texture = cutout(PAUSE, Rect2(132, 0, 1788, 720))
	normal.content_margin_top = 20
	normal.content_margin_bottom = 4
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.1, 1.08, 1.02)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.88, 0.83, 0.75)
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("e1bc7d")
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", focus)

class BookStamp extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, -0.08, size / Vector2(48, 40))
		var ink := Color("76502c")
		var book := PackedVector2Array([Vector2(4, 10), Vector2(15, 8), Vector2(24, 12), Vector2(33, 8), Vector2(44, 10), Vector2(44, 31), Vector2(33, 29), Vector2(24, 33), Vector2(15, 29), Vector2(4, 31), Vector2(4, 10)])
		draw_colored_polygon(book, Color(0.5, 0.31, 0.12, 0.12))
		draw_polyline(book, ink, 1.5, true)
		draw_line(Vector2(24, 12), Vector2(24, 32), ink, 1.3, true)
		for y in [15, 20, 25]:
			draw_line(Vector2(8, y), Vector2(19, y - 1), Color(ink, 0.65), 1.0, true)
			draw_line(Vector2(29, y - 1), Vector2(40, y), Color(ink, 0.65), 1.0, true)
