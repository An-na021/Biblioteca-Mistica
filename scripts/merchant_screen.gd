class_name MerchantScreen
extends Control

signal purchase_requested(book_id: String)
signal closed
signal next_day_requested

var offers: Dictionary = {}
var inventory: Inventory
var money := 0
var can_start_next_day := false

const PANEL_BACKGROUND := Color("171a15")
const CARD_BACKGROUND := Color("25281f")
const GOLD := Color("e4c477")
const TEXT_PRIMARY := Color("f3ead6")
const TEXT_MUTED := Color("b9ad96")
const GREEN := Color("9eb77a")

func setup(value_inventory: Inventory, value_offers: Dictionary, value_money: int, value_can_start_next_day := false) -> void:
	inventory = value_inventory
	offers = value_offers
	money = value_money
	can_start_next_day = value_can_start_next_day
	build()

func refresh(value_money: int) -> void:
	money = value_money
	for child in get_children():
		child.queue_free()
	build()

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.012, 0.009, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.position = Vector2(100, 35)
	panel.size = Vector2(1080, 650)
	panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BACKGROUND, GOLD, 2, 18))
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)
	title_stack.add_child(_make_label("SHOP", 27, GOLD))
	title_stack.add_child(_make_label("Livros disponíveis para comprar", 14, TEXT_MUTED))
	header.add_child(_make_badge("MOEDAS  %d" % money, Color("3a3021"), GOLD))
	var available_titles := 0
	for value in offers.values():
		if int(value) > 0:
			available_titles += 1
	header.add_child(_make_badge("%d ofertas" % available_titles, Color("333a2d"), GREEN))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 400
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 9)
	scroll.add_child(list)

	for book_id in offers:
		var available := int(offers[book_id])
		if available <= 0:
			continue
		var book := BookCatalog.get_book(book_id)
		var row_panel := PanelContainer.new()
		row_panel.custom_minimum_size.y = 112
		row_panel.add_theme_stylebox_override("panel", _make_panel_style(CARD_BACKGROUND, Color("514b3a"), 1, 9))
		list.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)
		var cover := _make_book_cover(book)
		cover.custom_minimum_size = Vector2(58, 84)
		cover.tooltip_text = "Capa de " + book.title
		row.add_child(cover)

		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_theme_constant_override("separation", 4)
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 8)
		details.add_child(heading)
		var book_title := _make_label(book.title, 17, TEXT_PRIMARY)
		book_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(book_title)
		heading.add_child(_make_label(book.author, 13, TEXT_MUTED))
		var metadata := HBoxContainer.new()
		metadata.add_theme_constant_override("separation", 6)
		details.add_child(metadata)
		metadata.add_child(_make_badge("DISPONÍVEL  %d" % available, Color("333a2d"), GREEN))
		metadata.add_child(_make_badge("COMPRA  %d moedas" % book.buy_price, Color("3a3021"), GOLD))
		var description := _make_label(book.description, 12, TEXT_MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(description)
		var missing_money: int = maxi(0, int(book.buy_price) - money)
		if missing_money > 0:
			var disabled_reason := _make_label("Indisponível: faltam %d moedas." % missing_money, 10, Color("d58b72"))
			disabled_reason.tooltip_text = "Você não possui moedas suficientes para comprar este livro."
			disabled_reason.text = "Indisponivel: faltam %d moedas." % missing_money
			disabled_reason.tooltip_text = "Voce nao possui moedas suficientes para comprar este livro."
			details.add_child(disabled_reason)

		var buy := Button.new()
		buy.text = "COMPRAR"
		buy.custom_minimum_size = Vector2(122, 42)
		buy.disabled = money < int(book.buy_price)
		buy.tooltip_text = "Você não possui moedas suficientes." if buy.disabled else "Comprar este livro."
		_style_button(buy, false)
		buy.tooltip_text = "Voce nao possui moedas suficientes." if buy.disabled else "Comprar este livro."
		buy.pressed.connect(func() -> void: purchase_requested.emit(book_id))
		row.add_child(buy)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(footer)
	var close := Button.new()
	close.text = "VOLTAR PARA A LIVRARIA"
	close.custom_minimum_size = Vector2(230, 42)
	_style_button(close, true)
	close.pressed.connect(func() -> void: closed.emit())
	footer.add_child(close)
	if can_start_next_day:
		var next_day := Button.new()
		next_day.text = "ABRIR O PROXIMO DIA"
		next_day.custom_minimum_size = Vector2(230, 42)
		_style_button(next_day, true)
		next_day.pressed.connect(func() -> void: next_day_requested.emit())
		footer.add_child(next_day)

func _make_badge(text: String, background: Color, foreground: Color) -> Control:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_TOP, 3.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_BOTTOM, 3.0)
	badge.add_theme_stylebox_override("panel", style)
	badge.add_child(_make_label(text, 11, foreground))
	return badge

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_panel_style(background: Color, border: Color, border_width: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(padding)
	return style

func _style_button(button: Button, prominent := false) -> void:
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("211b12") if prominent else TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color("211b12"))
	button.add_theme_color_override("font_pressed_color", Color("211b12"))
	button.add_theme_color_override("font_disabled_color", Color("7c786c"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d5b56d") if prominent else Color("3b4033")
	normal.border_color = Color("f0d79d") if prominent else Color("666047")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("efd99e")
	hover.border_color = Color("fff0c7")
	hover.set_border_width_all(1)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("b9954f")
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("292b25")
	disabled.border_color = Color("393a31")
	button.add_theme_stylebox_override("disabled", disabled)

func _make_book_cover(book: Dictionary) -> Control:
	var texture: Texture2D = book.get("cover_texture")
	if texture != null:
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return image

	var color_cover := ColorRect.new()
	color_cover.color = book.cover_color
	return color_cover
