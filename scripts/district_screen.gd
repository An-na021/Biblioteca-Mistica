class_name DistrictScreen
extends Control

signal closed
signal district_selected(district_id: String)

const Art = preload("res://scripts/hud_art.gd")
const Paper = preload("res://scripts/inventory_paper.gd")
const BOOK: Texture2D = preload("res://IMG/districts_book.png")
const DESIGN_SIZE := Vector2(1280, 720)
const INK := Color("302014")
const MUTED := Color("6b5037")

var book: Control


class DistrictCard extends Button:
	var framed := true
	var current := false

	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var edge := PackedVector2Array([
			Vector2(3, 3), Vector2(size.x * 0.35, 1), Vector2(size.x * 0.7, 3),
			Vector2(size.x - 3, 2), Vector2(size.x - 1, size.y * 0.5),
			Vector2(size.x - 3, size.y - 3), Vector2(size.x * 0.65, size.y - 1),
			Vector2(3, size.y - 3), Vector2(1, size.y * 0.4), Vector2(3, 3)
		])
		var highlighted := not disabled and (is_hovered() or has_focus())
		if highlighted:
			draw_colored_polygon(edge, Color(1, 0.96, 0.84, 0.16))
		if framed or highlighted:
			draw_polyline(edge, Color("56613d") if current else Color("6e5034"), 1.8 if current else 1.2, true)
		if highlighted:
			draw_polyline(edge, Color(1, 0.97, 0.85, 0.95), 2.5, true)
		var y := 62.0
		while y < size.y - 10:
			draw_line(Vector2(9, y), Vector2(size.x - 9, y + 0.5), Color(0.4, 0.27, 0.12, 0.17), 0.8, true)
			y += 33


class Padlock extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := Color("774b37")
		draw_arc(Vector2(19, 17), 10, PI, TAU, 24, ink, 2.2, true)
		draw_rect(Rect2(6, 17, 26, 25), Color(0.45, 0.29, 0.14, 0.08))
		draw_rect(Rect2(6, 17, 26, 25), ink, false, 2.0)
		draw_circle(Vector2(19, 28), 3, ink)
		draw_line(Vector2(19, 28), Vector2(19, 35), ink, 2.5, true)


func setup(districts: Array, selected_id: String) -> void:
	build(districts, selected_id)


func build(districts: Array, selected_id: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.018, 0.01, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	book = Control.new()
	book.name = "DistrictBook"
	book.size = DESIGN_SIZE
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(book)
	var background := TextureRect.new()
	background.texture = BOOK
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = DESIGN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(background)
	resized.connect(_layout_book)
	_layout_book()
	_place(_label("BAIRROS DA CIDADE", 36, false), Rect2(153, 82, 455, 52), book)
	var subtitle := _label("Cada região traz clientes e livros diferentes.", 18)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(subtitle, Rect2(154, 141, 446, 50), book)
	for index in range(districts.size()):
		var district: Dictionary = districts[index]
		var district_id := str(district.get("id", ""))
		var card := _district_card(district, district_id == selected_id, index)
		var rect := Rect2(150, 205, 450, 213) if index == 0 else Rect2(150, 451, 450, 157)
		if index >= 2:
			rect = Rect2(704, 158 + (index - 2) * 260, 450, 250)
		_place(card, rect, book)
	var close := Button.new()
	close.name = "Back"
	close.text = "VOLTAR"
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_override("font", _body_font())
	close.add_theme_font_size_override("font_size", 22)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		close.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		close.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	close.add_child(Paper.ButtonBacking.new())
	close.pressed.connect(func() -> void: closed.emit())
	_place(close, Rect2(1000, 628, 200, 54), book)


func _district_card(district: Dictionary, current: bool, index: int) -> DistrictCard:
	var id := str(district.get("id", ""))
	var unlocked := bool(district.get("unlocked", false))
	var state := "ATUAL" if current else ("DESBLOQUEADO" if unlocked else "BLOQUEADO")
	var description := str(district.get("description", "Explore uma nova região."))
	var card := DistrictCard.new()
	card.name = "District_" + id
	card.set_meta("district_id", id)
	card.current = current
	card.framed = index < 2
	card.disabled = not unlocked
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_ARROW
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		card.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	var heading := _label(str(district.get("name", "Bairro")), 27 if index == 1 else 31)
	_place(heading, Rect2(12, 12, 280 if index < 2 else 300, 47), card)
	var stamp := _state_stamp(state, current, unlocked)
	var stamp_x := 330 if current else 281
	var stamp_width := 100 if current else 157
	if index >= 2:
		stamp_x = 300
		stamp_width = 146
	_place(stamp, Rect2(stamp_x, 16, stamp_width, 38), card)
	var detail := _label(description, 21)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if index == 0:
		_place(detail, Rect2(198, 83, 232, 114), card)
	elif index == 1:
		if not unlocked:
			detail.add_theme_font_size_override("font_size", 19)
		_place(detail, Rect2(116, 66, 314, 82) if unlocked else Rect2(116, 58, 267, 50), card)
	else:
		_place(detail, Rect2(12, 87, 369 if not unlocked else 426, 82), card)
	if not unlocked:
		var hint := _label(str(district.get("unlock_hint", "Ainda indisponível")), 16 if index == 1 else 18)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Color("824b31"))
		_place(hint, Rect2(12, 174, 422, 65) if index >= 2 else Rect2(198 if index == 0 else 116, 153 if index == 0 else 111, 232 if index == 0 else 314, 54 if index == 0 else 42), card)
		var lock := Padlock.new()
		_place(lock, Rect2(395, 90, 40, 46) if index >= 2 else Rect2(390, 64, 40, 46), card)
	card.pressed.connect(_emit_district_selected.bind(id))
	return card


func _state_stamp(text: String, current: bool, unlocked: bool) -> PanelContainer:
	var stamp := PanelContainer.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.rotation = -0.065
	var ink := Color("465333") if current else (Color("8a5b2c") if unlocked else Color("a13e30"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("9caa75") if current else Color(0.75, 0.57, 0.32, 0.06)
	style.border_color = ink
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	stamp.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _body_font())
	label.add_theme_font_size_override("font_size", 18 if current else 14)
	label.add_theme_color_override("font_color", ink)
	stamp.add_child(label)
	return stamp


func _layout_book() -> void:
	var available := size - Vector2(28, 20)
	var zoom := maxf(0.1, minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y))
	book.scale = Vector2.ONE * zoom
	book.position = (size - DESIGN_SIZE * zoom) * 0.5


func _place(control: Control, rect: Rect2, parent: Control) -> void:
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)


func _emit_district_selected(district_id: String) -> void:
	district_selected.emit(district_id)


func _body_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Noto Sans", "sans-serif"])
	return font


func _label(text: String, font_size: int, italic := true) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Art.handwriting(italic))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label
