class_name InventoryScreen
extends Control

signal closed
signal deliver_requested(book_id: String, condition: String)
signal negotiate_requested(book_id: String, condition: String)
signal offer_requested(book_id: String, condition: String)

class NotebookLines extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var line_color := Color(0.55, 0.42, 0.25, 0.16)
		var margin_color := Color(0.58, 0.24, 0.18, 0.20)
		var y := 44.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), line_color, 1.0)
			y += 28.0
		draw_line(Vector2(58, 0), Vector2(58, size.y), margin_color, 1.0)

const PANEL_BG := Color("3d2418")
const PAGE_BG := Color("ead5a6")
const CARD_BG := Color("f1dfb7")
const GOLD := Color("a87932")
const TEXT_PRIMARY := Color("3d2b1e")
const TEXT_MUTED := Color("70583b")
const GREEN := Color("5f7049")
const PAGE_LINE := Color("c8ad78")

var inventory: Inventory
var request_clue: Dictionary = {}
var has_active_customer := false

func setup(value: Inventory, value_request_clue: Dictionary = {}, value_has_active_customer := false) -> void:
	inventory = value
	request_clue = value_request_clue.duplicate(true)
	has_active_customer = value_has_active_customer
	build()

func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.009, 0.005, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.position = Vector2(100, 35)
	panel.size = Vector2(1080, 650)
	panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, Color("6d4324"), 8, 14))
	add_child(panel)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _make_panel_style(PAGE_BG, Color("d4b77b"), 2, 16))
	panel.add_child(paper)
	var page_root := Control.new()
	page_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(page_root)
	var page_lines := NotebookLines.new()
	page_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_root.add_child(page_lines)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 18.0
	layout.offset_top = 14.0
	layout.offset_right = -18.0
	layout.offset_bottom = -14.0
	page_root.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)
	var title := _make_label("ESTOQUE DA LIVRARIA", 27, TEXT_PRIMARY)
	title_stack.add_child(title)
	var subtitle := _make_label("Livros disponíveis para atender seus clientes", 14, TEXT_MUTED)
	title_stack.add_child(subtitle)
	var stocked_books := inventory.stocked_books()
	var item_count := 0
	for stocked_book in stocked_books:
		item_count += int(stocked_book.get("quantity", 0))
	var item_name := "exemplar" if item_count == 1 else "exemplares"
	var count := _make_badge("%d %s" % [item_count, item_name], Color("d6bd83"), TEXT_PRIMARY)
	header.add_child(count)

	if has_active_customer:
		var request_banner := PanelContainer.new()
		request_banner.add_theme_stylebox_override("panel", _make_panel_style(Color("e1c88f"), Color("a87932"), 1, 9))
		layout.add_child(request_banner)
		var clue_type := str(request_clue.get("type", "titulo")).to_upper()
		var request_label := _make_label("PISTA DO CLIENTE · %s · %s" % [clue_type, str(request_clue.get("text", "Observe autor, temas e descrição dos livros."))], 13, TEXT_PRIMARY)
		request_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		request_banner.add_child(request_label)

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

	for book in stocked_books:
		list.add_child(_make_book_row(book))
	if stocked_books.is_empty():
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, PAGE_LINE, 1, 18))
		list.add_child(empty)
		var empty_text := _make_label("O estoque está vazio. Visite o mercador no próximo dia de compras para repor os livros.", 16, TEXT_MUTED)
		empty.add_child(empty_text)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(footer)
	var close := Button.new()
	close.text = "VOLTAR À LIVRARIA"
	close.custom_minimum_size = Vector2(230, 42)
	_style_button(close, true)
	close.pressed.connect(func() -> void: closed.emit())
	footer.add_child(close)

func _make_book_row(book: Dictionary) -> Control:
	var book_id: String = str(book.get("id", ""))
	var condition_items: Array = book.get("conditions", [])
	var row := PanelContainer.new()
	row.custom_minimum_size.y = 158 if has_active_customer else 112
	row.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, PAGE_LINE, 1, 9))

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	row.add_child(content)

	var cover := _make_book_cover(book)
	cover.custom_minimum_size = Vector2(72, 108)
	cover.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.tooltip_text = "Capa de " + str(book.get("title", "Livro"))
	content.add_child(cover)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	content.add_child(details)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	details.add_child(heading)
	var book_title := _make_label(str(book.get("title", "Livro")), 17, TEXT_PRIMARY)
	book_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(book_title)
	var author := _make_label(str(book.get("author", "Autor desconhecido")), 13, TEXT_MUTED)
	heading.add_child(author)
	var metadata := HBoxContainer.new()
	metadata.add_theme_constant_override("separation", 6)
	details.add_child(metadata)
	metadata.add_child(_make_badge("ESTOQUE  %d" % int(book.get("quantity", 0)), Color("c3d0a0"), GREEN))
	var condition_colors := {"novo": Color("c3d0a0"), "usado": Color("d9c59a"), "danificado": Color("d9a49a"), "raro": Color("d3bdde")}
	var price_summary := PackedStringArray()
	var condition_group: ButtonGroup
	var condition_selector := HFlowContainer.new()
	if has_active_customer:
		condition_group = ButtonGroup.new()
		condition_group.allow_unpress = false
		condition_selector.add_theme_constant_override("h_separation", 5)
		condition_selector.add_theme_constant_override("v_separation", 4)
		details.add_child(condition_selector)
	for condition_item in condition_items:
		var condition_id := str(condition_item.get("condition", "novo"))
		var condition_label := str(condition_item.get("condition_label", "Novo")).to_upper()
		if has_active_customer:
			var condition_button := Button.new()
			condition_button.toggle_mode = true
			condition_button.button_group = condition_group
			condition_button.custom_minimum_size.y = 27
			condition_button.set_meta("condition", condition_id)
			condition_button.text = "%s  ·  %d un.  ·  %d moedas" % [condition_label, int(condition_item.get("quantity", 0)), int(condition_item.get("sale_price", 0))]
			condition_button.tooltip_text = "%s: %d exemplar(es). Compra %d moedas; venda %d moedas." % [condition_label.capitalize(), int(condition_item.get("quantity", 0)), int(condition_item.get("buy_price", 0)), int(condition_item.get("sale_price", 0))]
			_style_condition_choice(condition_button, condition_colors.get(condition_id, Color("d8c79d")))
			condition_selector.add_child(condition_button)
			if condition_selector.get_child_count() == 1:
				condition_button.button_pressed = true
		else:
			metadata.add_child(_make_badge("%s  ×%d" % [condition_label, int(condition_item.get("quantity", 0))], condition_colors.get(condition_id, Color("d8c79d")), TEXT_PRIMARY))
			price_summary.append("%s %d/%d" % [condition_label, int(condition_item.get("buy_price", 0)), int(condition_item.get("sale_price", 0))])
	if not has_active_customer:
		var price_line := _make_label("Compra/venda: " + "  ·  ".join(price_summary), 10, TEXT_MUTED)
		details.add_child(price_line)

	var description := _make_label(str(book.get("description", "")), 12, TEXT_MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(description)
	var theme_names := PackedStringArray()
	for tag in book.get("tags", []):
		theme_names.append(str(tag).capitalize())
	var themes := _make_label("TEMAS  " + ", ".join(theme_names), 10, TEXT_MUTED)
	themes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(themes)

	if has_active_customer:
		var actions := VBoxContainer.new()
		actions.custom_minimum_size.x = 122
		actions.add_theme_constant_override("separation", 3)
		content.add_child(actions)

		var deliver := Button.new()
		deliver.text = "ENTREGAR"
		_style_button(deliver, true)
		deliver.tooltip_text = "Entregar este exemplar; confira as pistas do cliente."
		deliver.pressed.connect(func() -> void: deliver_requested.emit(book_id, _selected_condition(condition_group)))
		actions.add_child(deliver)

		var negotiate := Button.new()
		negotiate.text = "NEGOCIAR"
		negotiate.tooltip_text = "Negociar o preço deste exemplar."
		_style_button(negotiate, false)
		negotiate.pressed.connect(func() -> void: negotiate_requested.emit(book_id, _selected_condition(condition_group)))
		actions.add_child(negotiate)

		var offer := Button.new()
		offer.text = "OFERECER"
		offer.tooltip_text = "Oferecer este título como alternativa ao cliente."
		_style_button(offer, false)
		offer.pressed.connect(func() -> void: offer_requested.emit(book_id, _selected_condition(condition_group)))
		actions.add_child(offer)

	return row

func _selected_condition(condition_group: ButtonGroup) -> String:
	if condition_group == null or condition_group.get_pressed_button() == null:
		return "novo"
	return str(condition_group.get_pressed_button().get_meta("condition", "novo"))

func _style_condition_choice(button: Button, tint: Color) -> void:
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color("2d2115"))
	button.add_theme_color_override("font_pressed_color", Color("2d2115"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = tint.lightened(0.18)
	normal.border_color = tint.darkened(0.25)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.set_content_margin(SIDE_LEFT, 7.0)
	normal.set_content_margin(SIDE_RIGHT, 7.0)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.32)
	hover.border_color = GOLD
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = tint
	pressed.border_color = GOLD
	pressed.set_border_width_all(2)
	button.add_theme_stylebox_override("pressed", pressed)
	var hover_pressed := pressed.duplicate() as StyleBoxFlat
	hover_pressed.bg_color = tint.lightened(0.12)
	button.add_theme_stylebox_override("hover_pressed", hover_pressed)

func _make_panel_style(background: Color, border: Color, border_width: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(padding)
	return style

func _make_badge(text: String, background: Color, foreground: Color) -> Control:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(2)
	style.set_content_margin(SIDE_LEFT, 8.0)
	style.set_content_margin(SIDE_TOP, 3.0)
	style.set_content_margin(SIDE_RIGHT, 8.0)
	style.set_content_margin(SIDE_BOTTOM, 3.0)
	badge.add_theme_stylebox_override("panel", style)
	var label := _make_label(text, 11, foreground)
	badge.add_child(label)
	return badge

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _style_button(button: Button, prominent: bool) -> void:
	button.custom_minimum_size.y = 27
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("2d2115"))
	button.add_theme_color_override("font_hover_color", Color("2d2115"))
	button.add_theme_color_override("font_pressed_color", Color("2d2115"))
	button.add_theme_color_override("font_disabled_color", Color("8c7757"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d5b56d") if prominent else Color("d8bb7b")
	normal.border_color = Color("a87932") if prominent else Color("b18c51")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f0d99c")
	hover.border_color = Color("8e5b20")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("bd934b")
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color("c5b38e")
	disabled.border_color = Color("b8a47c")
	button.add_theme_stylebox_override("disabled", disabled)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color("fff0c7")
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)

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
