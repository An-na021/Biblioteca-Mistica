class_name MerchantScreen
extends Control

signal purchase_requested(book_id: String, condition: String)
signal closed
signal next_day_requested

const Art = preload("res://scripts/hud_art.gd")
const Paper = preload("res://scripts/inventory_paper.gd")
const BackButtonStyle = preload("res://scripts/back_button_style.gd")
const BOOK: Texture2D = preload("res://IMG/day_summary_book.png")
const DESIGN_SIZE := Vector2(1280, 720)
const BOOKS_PER_SPREAD := 6
const INK := Color("302014")
const MUTED := Color("6b5037")
const GREEN := Color("486034")

var offers: Dictionary = {}
var inventory: Inventory
var money := 0
var can_start_next_day := false
var reservations: Array[Dictionary] = []
var book_list: Control
var book: Control
var wallet_label: Button
var previous_page: Button
var next_page: Button
var page_label: Label
var current_spread := 0
var _selected_conditions: Dictionary = {}


class CatalogueEntry extends Control:
	var framed := false
	var reserved := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if framed or reserved:
			draw_polyline(PackedVector2Array([
				Vector2(2, 2), Vector2(size.x * 0.35, 1), Vector2(size.x * 0.67, 3),
				Vector2(size.x - 2, 1), Vector2(size.x - 1, size.y - 3),
				Vector2(size.x * 0.55, size.y - 1), Vector2(2, size.y - 2), Vector2(2, 2)
			]), Color(0.28, 0.17, 0.08, 0.7), 1.2, true)
		for y in [35, 69, 103]:
			draw_line(Vector2(8, y), Vector2(size.x - 8, y + 0.5), Color(0.4, 0.27, 0.12, 0.17), 0.8, true)


func setup(value_inventory: Inventory, value_offers: Dictionary, value_money: int, value_can_start_next_day := false, value_reservations: Array[Dictionary] = []) -> void:
	inventory = value_inventory
	offers = value_offers
	money = value_money
	can_start_next_day = value_can_start_next_day
	reservations = value_reservations.duplicate(true)
	build()


func refresh(value_money: int) -> void:
	money = value_money
	wallet_label.text = "MOEDAS  %d" % money
	_rebuild_entries()


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.018, 0.01, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	book = Control.new()
	book.name = "ShopBook"
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
	_place(_make_label("LOJA DE LIVROS", 36, INK, true), Rect2(150, 86, 455, 50), book)
	_place(_make_label("Todos os livros em um só lugar.", 19, MUTED, false, true), Rect2(153, 140, 445, 32), book)

	wallet_label = Button.new()
	wallet_label.name = "Wallet"
	wallet_label.text = "MOEDAS  %d" % money
	wallet_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet_label.focus_mode = Control.FOCUS_NONE
	BackButtonStyle.apply(wallet_label)
	wallet_label.add_theme_font_size_override("font_size", 18)
	_place(wallet_label, Rect2(977, 47, 210, 45), book)
	book_list = Control.new()
	book_list.name = "CatalogueEntries"
	book_list.size = DESIGN_SIZE
	book_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(book_list)

	var close := _paper_button("VOLTAR À LIVRARIA")
	close.name = "Back"
	close.pressed.connect(func() -> void: closed.emit())
	_place(close, Rect2(345, 628, 255, 50), book)
	previous_page = _paper_button("‹")
	previous_page.name = "PreviousPage"
	previous_page.add_theme_font_size_override("font_size", 25)
	previous_page.pressed.connect(func() -> void: _show_spread(current_spread - 1))
	_place(previous_page, Rect2(668, 634, 40, 40), book)
	page_label = _make_label("", 14, MUTED)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(page_label, Rect2(710, 635, 152, 38), book)
	next_page = _paper_button("›")
	next_page.name = "NextPage"
	next_page.add_theme_font_size_override("font_size", 25)
	next_page.pressed.connect(func() -> void: _show_spread(current_spread + 1))
	_place(next_page, Rect2(864, 634, 40, 40), book)
	if can_start_next_day:
		var next_day := _paper_button("ABRIR O PRÓXIMO DIA")
		next_day.name = "NextDay"
		next_day.pressed.connect(func() -> void: next_day_requested.emit())
		_place(next_day, Rect2(920, 628, 268, 50), book)
	_rebuild_entries()


func _rebuild_entries() -> void:
	for child in book_list.get_children():
		book_list.remove_child(child)
		child.queue_free()
	var book_ids: Array[String] = []
	for order in reservations:
		var id := str(order.book_id)
		if not book_ids.has(id):
			book_ids.append(id)
	for entry in BookCatalog.all_books():
		if not book_ids.has(str(entry.id)):
			book_ids.append(str(entry.id))
	for id in book_ids:
		book_list.add_child(_book_row(id, offers.get(id, {})))
	_show_spread(current_spread)


func _show_spread(value: int) -> void:
	var spread_count := maxi(1, ceili(float(book_list.get_child_count()) / BOOKS_PER_SPREAD))
	current_spread = clampi(value, 0, spread_count - 1)
	for index in range(book_list.get_child_count()):
		var row := book_list.get_child(index) as CatalogueEntry
		var within := index % BOOKS_PER_SPREAD
		var left_page := within < 3
		row.framed = left_page
		row.position = Vector2(137 if left_page else 704, (190 if left_page else 153) + (within % 3) * 140)
		row.size = Vector2(470, 130)
		row.visible = floori(float(index) / BOOKS_PER_SPREAD) == current_spread
		row.queue_redraw()
	previous_page.disabled = current_spread == 0
	next_page.disabled = current_spread >= spread_count - 1
	previous_page.visible = spread_count > 1
	next_page.visible = spread_count > 1
	page_label.visible = spread_count > 1
	page_label.text = "CATÁLOGO  %d / %d" % [current_spread + 1, spread_count]


func _layout_book() -> void:
	var available := size - Vector2(28, 20)
	var zoom := maxf(0.1, minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y))
	book.scale = Vector2.ONE * zoom
	book.position = (size - DESIGN_SIZE * zoom) * 0.5


func _book_row(book_id: String, offer: Dictionary) -> CatalogueEntry:
	var item := BookCatalog.get_book(book_id)
	var orders := _orders_for_book(book_id)
	var row := CatalogueEntry.new()
	row.name = "Book_" + book_id
	row.set_meta("book_id", book_id)
	row.reserved = not orders.is_empty()
	_place(_make_book_cover(item), Rect2(6, 12, 66, 103), row)
	var title := _make_label(str(item.title), 23, INK)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(title, Rect2(84, 5, 251, 30), row)
	_place(_make_label("%s · %d no estoque" % [str(item.author), inventory.get_quantity(book_id)], 17, MUTED, false, true), Rect2(84, 40, 222, 27), row)

	var demand: Dictionary = {}
	for order in orders:
		var condition := str(order.condition)
		demand[condition] = int(demand.get(condition, 0)) + 1
	if not demand.is_empty():
		var notes_scroll := ScrollContainer.new()
		notes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		notes_scroll.get_v_scroll_bar().custom_minimum_size.x = 3
		_place(notes_scroll, Rect2(84, 77, 377, 47), row)
		var notes := VBoxContainer.new()
		notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		notes.add_theme_constant_override("separation", 2)
		notes_scroll.add_child(notes)
		for condition in demand:
			var readers := PackedStringArray()
			for order in orders:
				if str(order.condition) == str(condition):
					readers.append(str(order.get("customer_name", "Leitor")))
			var missing := maxi(0, int(demand[condition]) - inventory.get_condition_quantity(book_id, str(condition)))
			var status := "comprar %d" % missing if missing > 0 else "pronto para entregar"
			var reserved := _make_label("Reserva: %s · %s · %s" % [", ".join(readers), str(BookCatalog.get_condition(str(condition)).label), status], 14, MUTED if missing > 0 else GREEN, false, true)
			reserved.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			notes.add_child(reserved)

	var condition_stock: Dictionary = offer.get("conditions", {})
	var picker := OptionButton.new()
	picker.name = "Condition"
	_style_condition_picker(picker)
	var preferred_index := -1
	var saved_index := -1
	for condition in BookCatalog.CONDITIONS:
		var available: Dictionary = condition_stock.get(condition, {})
		if int(available.get("quantity", 0)) <= 0:
			continue
		var index := picker.item_count
		picker.add_item(str(BookCatalog.get_condition(condition).label))
		picker.set_item_metadata(index, condition)
		if str(_selected_conditions.get(book_id, "")) == str(condition):
			saved_index = index
		if preferred_index < 0 and int(demand.get(condition, 0)) > inventory.get_condition_quantity(book_id, condition):
			preferred_index = index
	if picker.item_count == 0:
		_place(_unavailable_stamp(), Rect2(333, 8, 130, 32), row)
		picker.free()
		return row
	picker.select(saved_index if saved_index >= 0 else (preferred_index if preferred_index >= 0 else 0))
	_place(picker, Rect2(343, 4, 120, 31), row)
	var buy := _paper_button("", 15)
	buy.name = "Buy"
	_place(buy, Rect2(305, 40, 158, 31), row)
	var update_purchase := func() -> void:
		var selected := str(picker.get_item_metadata(picker.selected))
		_selected_conditions[book_id] = selected
		var selected_offer: Dictionary = condition_stock[selected]
		var price := int(selected_offer.price)
		buy.text = "Comprar · %d moedas" % price
		buy.disabled = money < price
		buy.tooltip_text = "Moedas insuficientes." if buy.disabled else "Comprar um exemplar. Risco de avaria: %d%%." % roundi(float(selected_offer.get("risk", 0.0)) * 100.0)
	update_purchase.call()
	picker.item_selected.connect(func(_index: int) -> void: update_purchase.call())
	buy.pressed.connect(func() -> void: purchase_requested.emit(book_id, str(picker.get_item_metadata(picker.selected))))
	return row


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


func _unavailable_stamp() -> PanelContainer:
	var stamp := PanelContainer.new()
	stamp.rotation = -0.05
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.2, 0.1, 0.03)
	style.border_color = Color("a04b3a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(3)
	stamp.add_theme_stylebox_override("panel", style)
	var label := _make_label("Indisponível hoje", 14, Color("984735"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.add_child(label)
	return stamp


func _paper_button(text: String, font_size := 17) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _body_font())
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, INK)
	button.add_theme_color_override("font_disabled_color", Color("8b775b"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("8d6437")
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", focus)
	button.add_child(Paper.ButtonBacking.new())
	return button


func _style_condition_picker(picker: OptionButton) -> void:
	picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	picker.add_theme_font_override("font", _body_font())
	picker.add_theme_font_size_override("font_size", 16)
	picker.add_theme_constant_override("modulate_arrow", 1)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		picker.add_theme_color_override(state, INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.TRANSPARENT
	normal.border_color = Color(0.4, 0.27, 0.12, 0.45)
	normal.border_width_bottom = 1
	normal.set_content_margin_all(4)
	picker.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 0.94, 0.78, 0.3)
	picker.add_theme_stylebox_override("hover", hover)
	picker.add_theme_stylebox_override("pressed", hover)
	picker.add_theme_stylebox_override("focus", hover)
	var popup := picker.get_popup()
	popup.add_theme_font_override("font", _body_font())
	popup.add_theme_font_size_override("font_size", 15)
	popup.add_theme_color_override("font_color", INK)
	popup.add_theme_color_override("font_hover_color", INK)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("e6ca96")
	panel.border_color = Color("8d6437")
	panel.set_border_width_all(1)
	panel.set_content_margin_all(5)
	popup.add_theme_stylebox_override("panel", panel)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("cfa86f")
	popup.add_theme_stylebox_override("hover", selected)


func _place(control: Control, rect: Rect2, parent: Control) -> void:
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)


func _body_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Noto Sans", "sans-serif"])
	return font


func _make_label(text: String, font_size: int, color: Color, heading := false, italic := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", Art.handwriting(italic) if heading or italic else _body_font())
	return label


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
