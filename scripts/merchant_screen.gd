class_name MerchantScreen
extends Control

signal purchase_requested(book_id: String, condition: String)
signal supplier_selected(supplier_id: String)
signal closed
signal next_day_requested

var offers: Dictionary = {}
var inventory: Inventory
var money := 0
var can_start_next_day := false
var suppliers: Array = []
var selected_supplier_id := ""

const PANEL_BACKGROUND := Color("171a15")
const CARD_BACKGROUND := Color("25281f")
const GOLD := Color("e4c477")
const TEXT_PRIMARY := Color("f3ead6")
const TEXT_MUTED := Color("b9ad96")
const GREEN := Color("9eb77a")

func setup(value_inventory: Inventory, value_offers: Dictionary, value_money: int, value_can_start_next_day := false, value_suppliers: Array = [], value_supplier_id := "") -> void:
	inventory = value_inventory
	offers = value_offers
	money = value_money
	can_start_next_day = value_can_start_next_day
	suppliers = value_suppliers.duplicate(true)
	selected_supplier_id = value_supplier_id
	build()

func set_market(value_offers: Dictionary, supplier_id: String, value_money: int) -> void:
	offers = value_offers
	selected_supplier_id = supplier_id
	money = value_money
	refresh(value_money)

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
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -540.0
	panel.offset_top = -325.0
	panel.offset_right = 540.0
	panel.offset_bottom = 325.0
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
	title_stack.add_child(_make_label("LOJA", 27, GOLD))
	title_stack.add_child(_make_label("Livros disponíveis para comprar", 14, TEXT_MUTED))
	header.add_child(_make_badge("MOEDAS  %d" % money, Color("3a3021"), GOLD))
	var available_titles := 0
	for value in offers.values():
		if int(value.get("quantity", 0)) > 0:
			available_titles += 1
	header.add_child(_make_badge("%d ofertas" % available_titles, Color("333a2d"), GREEN))

	if not suppliers.is_empty():
		var supplier_header := _make_label("FORNECEDORES  ·  PREÇO E RISCO VARIAM", 11, GOLD)
		layout.add_child(supplier_header)
		var supplier_row := HBoxContainer.new()
		supplier_row.add_theme_constant_override("separation", 7)
		layout.add_child(supplier_row)
		for supplier in suppliers:
			var supplier_id := str(supplier.get("id", ""))
			var risk_percent := roundi(float(supplier.get("risk", 0.0)) * 100.0)
			var price_factor := float(supplier.get("price_factor", 1.0))
			var price_description := "PREÇO NORMAL" if is_equal_approx(price_factor, 1.0) else ("%d%% MAIS BARATO" % roundi((1.0 - price_factor) * 100.0) if price_factor < 1.0 else "%d%% MAIS CARO" % roundi((price_factor - 1.0) * 100.0))
			var supplier_button := Button.new()
			supplier_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			supplier_button.custom_minimum_size.y = 58
			supplier_button.text = "%s\n%s  ·  RISCO %d%%" % [str(supplier.get("name", "Fornecedor")), price_description, risk_percent]
			supplier_button.tooltip_text = str(supplier.get("description", "Fornecedor"))
			_style_supplier_button(supplier_button, supplier_id == selected_supplier_id)
			supplier_button.pressed.connect(_emit_supplier_selected.bind(supplier_id))
			supplier_row.add_child(supplier_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 360 if not suppliers.is_empty() else 400
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 9)
	scroll.add_child(list)

	for book_id in offers:
		var offer: Dictionary = offers[book_id]
		var condition_stock: Dictionary = offer.get("conditions", {})
		if condition_stock.is_empty() and int(offer.get("quantity", 0)) > 0:
			var legacy_condition := str(offer.get("condition", "novo"))
			condition_stock[legacy_condition] = {"quantity": int(offer.get("quantity", 0)), "price": int(offer.get("price", 0))}
		var available := 0
		for condition_offer in condition_stock.values():
			available += int(condition_offer.get("quantity", 0))
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
		metadata.add_child(_make_badge("OFERTAS  %d" % available, Color("333a2d"), GREEN))
		metadata.add_child(_make_badge("ESTOQUE: %d" % inventory.get_quantity(book_id), Color("3a3021"), GOLD))
		var condition_picker := OptionButton.new()
		condition_picker.custom_minimum_size = Vector2(280, 34)
		_style_condition_picker(condition_picker)
		for condition_id in ["novo", "usado", "danificado", "raro"]:
			if not condition_stock.has(condition_id):
				continue
			var condition_offer: Dictionary = condition_stock[condition_id]
			if int(condition_offer.get("quantity", 0)) <= 0:
				continue
			var condition_info := BookCatalog.get_condition(condition_id)
			var condition_price := int(condition_offer.get("price", BookCatalog.price_for_condition(book, condition_id, "buy_price")))
			var option_index := condition_picker.item_count
			condition_picker.add_item("%s  ·  %d un.  ·  %d moedas" % [str(condition_info.get("label", condition_id)).to_upper(), int(condition_offer.get("quantity", 0)), condition_price])
			condition_picker.set_item_metadata(option_index, condition_id)
		metadata.add_child(condition_picker)
		condition_picker.select(0)
		var selected_condition := str(condition_picker.get_item_metadata(0)) if condition_picker.item_count > 0 else "novo"
		var purchase_price := int(condition_stock.get(selected_condition, {}).get("price", BookCatalog.price_for_condition(book, selected_condition, "buy_price")))
		var price_badge := _make_badge("COMPRA  %d moedas" % purchase_price, Color("3a3021"), GOLD)
		metadata.add_child(price_badge)
		var description := _make_label(book.description, 12, TEXT_MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(description)
		var buy := Button.new()
		buy.text = "COMPRAR"
		buy.custom_minimum_size = Vector2(122, 42)
		buy.disabled = money < purchase_price
		buy.tooltip_text = "Você não possui moedas suficientes." if buy.disabled else "Comprar este livro."
		_style_button(buy, false)
		buy.tooltip_text = "Voce nao possui moedas suficientes." if buy.disabled else "Comprar este livro."
		buy.pressed.connect(func() -> void: purchase_requested.emit(book_id, str(condition_picker.get_item_metadata(condition_picker.selected))))
		row.add_child(buy)
		condition_picker.item_selected.connect(func(index: int) -> void:
			var selected_id := str(condition_picker.get_item_metadata(index))
			var selected_offer: Dictionary = condition_stock.get(selected_id, {})
			var selected_price := int(selected_offer.get("price", BookCatalog.price_for_condition(book, selected_id, "buy_price")))
			price_badge.get_child(0).text = "COMPRA  %d moedas" % selected_price
			buy.disabled = money < selected_price
			buy.tooltip_text = "Voce nao possui moedas suficientes." if buy.disabled else "Comprar este livro na condicao selecionada."
		)

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

func _style_condition_picker(picker: OptionButton) -> void:
	picker.add_theme_font_size_override("font_size", 12)
	picker.add_theme_color_override("font_color", TEXT_PRIMARY)
	picker.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	picker.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	picker.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	var normal := StyleBoxFlat.new()
	normal.bg_color = CARD_BACKGROUND
	normal.border_color = Color("8b7545")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.set_content_margin(SIDE_LEFT, 10.0)
	normal.set_content_margin(SIDE_RIGHT, 10.0)
	normal.set_content_margin(SIDE_TOP, 5.0)
	normal.set_content_margin(SIDE_BOTTOM, 5.0)
	picker.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("353629")
	hover.border_color = GOLD
	picker.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("3a3021")
	pressed.border_color = GOLD
	pressed.set_border_width_all(2)
	picker.add_theme_stylebox_override("pressed", pressed)
	picker.add_theme_stylebox_override("focus", pressed)
	var popup := picker.get_popup()
	popup.add_theme_color_override("font_color", TEXT_PRIMARY)
	popup.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	popup.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	var popup_panel := StyleBoxFlat.new()
	popup_panel.bg_color = PANEL_BACKGROUND
	popup_panel.border_color = GOLD
	popup_panel.set_border_width_all(1)
	popup_panel.set_corner_radius_all(6)
	popup_panel.set_content_margin_all(4.0)
	popup.add_theme_stylebox_override("panel", popup_panel)
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = Color("51432b")
	popup_hover.set_corner_radius_all(3)
	popup.add_theme_stylebox_override("hover", popup_hover)

func _style_supplier_button(button: Button, selected: bool) -> void:
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color("211b12"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("51432b") if selected else Color("30352c")
	normal.border_color = GOLD if selected else Color("666047")
	normal.set_border_width_all(2 if selected else 1)
	normal.set_corner_radius_all(5)
	normal.set_content_margin_all(6.0)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("d5b56d")
	hover.border_color = Color("fff0c7")
	button.add_theme_stylebox_override("hover", hover)

func _emit_supplier_selected(supplier_id: String) -> void:
	supplier_selected.emit(supplier_id)

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
