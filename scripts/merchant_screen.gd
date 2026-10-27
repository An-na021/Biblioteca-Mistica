class_name MerchantScreen
extends Control

signal purchase_requested(book_id: String, condition: String)
signal closed
signal next_day_requested

var offers: Dictionary = {}
var inventory: Inventory
var money := 0
var can_start_next_day := false
var reservations: Array[Dictionary] = []
var book_list: VBoxContainer

const PANEL_BACKGROUND := Color("171a15")
const CARD_BACKGROUND := Color("25281f")
const GOLD := Color("e4c477")
const TEXT_PRIMARY := Color("f3ead6")
const TEXT_MUTED := Color("b9ad96")
const GREEN := Color("9eb77a")

func setup(value_inventory: Inventory, value_offers: Dictionary, value_money: int, value_can_start_next_day := false, value_reservations: Array[Dictionary] = []) -> void:
	inventory = value_inventory
	offers = value_offers
	money = value_money
	can_start_next_day = value_can_start_next_day
	reservations = value_reservations.duplicate(true)
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
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 24
	panel.offset_right = -24
	panel.offset_bottom = -24
	panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BACKGROUND, GOLD, 2, 18))
	add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(_make_label("LOJA DE LIVROS", 25, GOLD))
	titles.add_child(_make_label("Todos os livros em um só lugar.", 13, TEXT_MUTED))
	var wallet := _make_badge("MOEDAS  %d" % money, Color("3a3021"), GOLD)
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(wallet)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 160
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	book_list = VBoxContainer.new()
	book_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_list.add_theme_constant_override("separation", 9)
	scroll.add_child(book_list)
	var book_ids: Array[String] = []
	for order in reservations:
		var book_id := str(order.book_id)
		if not book_ids.has(book_id):
			book_ids.append(book_id)
	for book in BookCatalog.all_books():
		if not book_ids.has(str(book.id)):
			book_ids.append(str(book.id))
	for book_id in book_ids:
		book_list.add_child(_book_row(book_id, offers.get(book_id, {})))
	if book_ids.is_empty():
		book_list.add_child(_make_label("Nenhum livro no catálogo.", 15, TEXT_MUTED))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	var close := Button.new()
	close.text = "VOLTAR À LIVRARIA"
	close.custom_minimum_size = Vector2(230, 42)
	_style_button(close, true)
	close.pressed.connect(func() -> void: closed.emit())
	footer.add_child(close)
	if can_start_next_day:
		var next_day := Button.new()
		next_day.text = "ABRIR O PRÓXIMO DIA"
		next_day.custom_minimum_size = Vector2(230, 42)
		_style_button(next_day, true)
		next_day.pressed.connect(func() -> void: next_day_requested.emit())
		footer.add_child(next_day)

func _book_row(book_id: String, offer: Dictionary) -> Control:
	var book := BookCatalog.get_book(book_id)
	var orders := _orders_for_book(book_id)
	var panel := PanelContainer.new()
	panel.set_meta("book_id", book_id)
	panel.add_theme_stylebox_override("panel", _make_panel_style(CARD_BACKGROUND, Color("514b3a"), 1, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var cover := _make_book_cover(book)
	cover.custom_minimum_size = Vector2(50, 74)
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cover)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)
	var title := _make_label(str(book.title), 17, TEXT_PRIMARY)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(title)
	var author := _make_label("%s · %d no estoque" % [str(book.author), inventory.get_quantity(book_id)], 12, TEXT_MUTED)
	author.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(author)
	var demand: Dictionary = {}
	for order in orders:
		var condition := str(order.condition)
		demand[condition] = int(demand.get(condition, 0)) + 1
	for condition in demand:
		var readers := PackedStringArray()
		for order in orders:
			if str(order.condition) == str(condition):
				readers.append(str(order.get("customer_name", "Leitor")))
		var missing := maxi(0, int(demand[condition]) - inventory.get_condition_quantity(book_id, str(condition)))
		var status := "comprar %d" % missing if missing > 0 else "pronto para entregar"
		var reserved := _make_label("Reserva: %s · %s · %s" % [", ".join(readers), str(BookCatalog.get_condition(str(condition)).label), status], 12, GOLD if missing > 0 else GREEN)
		reserved.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.add_child(reserved)
	var condition_stock: Dictionary = offer.get("conditions", {})
	var purchase := HBoxContainer.new()
	purchase.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	purchase.add_theme_constant_override("separation", 10)
	row.add_child(purchase)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(130, 36)
	_style_condition_picker(picker)
	var preferred_index := -1
	for condition in BookCatalog.CONDITIONS:
		var available: Dictionary = condition_stock.get(condition, {})
		if int(available.get("quantity", 0)) <= 0:
			continue
		var index := picker.item_count
		picker.add_item(str(BookCatalog.get_condition(condition).label))
		picker.set_item_metadata(index, condition)
		if preferred_index < 0 and int(demand.get(condition, 0)) > inventory.get_condition_quantity(book_id, condition):
			preferred_index = index
	if picker.item_count == 0:
		var unavailable := _make_label("Indisponível hoje", 12, TEXT_MUTED)
		unavailable.custom_minimum_size.x = 290
		unavailable.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		purchase.add_child(unavailable)
		picker.free()
		return panel
	picker.select(preferred_index if preferred_index >= 0 else 0)
	purchase.add_child(picker)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(150, 36)
	_style_button(buy, true)
	purchase.add_child(buy)
	var update_purchase := func() -> void:
		var selected := str(picker.get_item_metadata(picker.selected))
		var selected_offer: Dictionary = condition_stock[selected]
		var price := int(selected_offer.price)
		buy.text = "Comprar · %d moedas" % price
		buy.disabled = money < price
		buy.tooltip_text = "Moedas insuficientes." if buy.disabled else "Comprar um exemplar. Risco de avaria: %d%%." % roundi(float(selected_offer.get("risk", 0.0)) * 100.0)
	update_purchase.call()
	picker.item_selected.connect(func(_index: int) -> void: update_purchase.call())
	buy.pressed.connect(func() -> void: purchase_requested.emit(book_id, str(picker.get_item_metadata(picker.selected))))
	return panel

func _orders_for_book(book_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order in reservations:
		if str(order.book_id) == book_id:
			result.append(order)
	return result

func _missing_reservation_count() -> int:
	var demand: Dictionary = {}
	var missing := 0
	for order in reservations:
		var key := str(order.book_id) + ":" + str(order.condition)
		demand[key] = int(demand.get(key, 0)) + 1
		if int(demand[key]) > inventory.get_condition_quantity(str(order.book_id), str(order.condition)):
			missing += 1
	return missing

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
