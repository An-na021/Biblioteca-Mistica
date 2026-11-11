extends Control

signal purchase_requested(upgrade_id: String)
signal closed

const World = preload("res://scripts/shop_world.gd")
const Art = preload("res://scripts/hud_art.gd")
const Paper = preload("res://scripts/inventory_paper.gd")
const BOOK: Texture2D = preload("res://IMG/day_summary_book.png")
const DESIGN_SIZE := Vector2(1280, 720)
const INK := Color("302014")
const MUTED := Color("6b5037")
const GREEN := Color("4b6035")

var book: Control
var wallet_label: Label
var heading: Label
var tab_container: TabContainer
var tab_buttons: Array[Button] = []
var upgrade_buttons: Dictionary = {}
var installed_stamps: Dictionary = {}


class PageSection extends Control:
	var framed := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if framed:
			draw_polyline(PackedVector2Array([
				Vector2(2, 2), Vector2(size.x * 0.3, 0), Vector2(size.x * 0.65, 3),
				Vector2(size.x - 2, 1), Vector2(size.x, size.y * 0.6),
				Vector2(size.x - 2, size.y - 2), Vector2(size.x * 0.5, size.y),
				Vector2(2, size.y - 2), Vector2(1, size.y * 0.3), Vector2(2, 2)
			]), Color(0.25, 0.15, 0.07, 0.6), 1.3, true)
		for y in range(57, int(size.y) - 8, 32):
			draw_line(Vector2(9, y), Vector2(size.x - 9, y + 0.6), Color(0.4, 0.27, 0.12, 0.18), 0.8, true)


func setup(world: RefCounted, funds: int, next_day: int, profiles: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.018, 0.01, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	book = Control.new()
	book.name = "LivrariaBook"
	book.size = DESIGN_SIZE
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(book)
	var background := TextureRect.new()
	background.texture = BOOK
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(background, Rect2(Vector2.ZERO, DESIGN_SIZE), book)
	resized.connect(_layout_book)
	_layout_book()
	for index in range(2):
		var tab := _paper_button("Melhorias" if index == 0 else "Caderno de leitores", 23)
		tab.name = "ImprovementsTab" if index == 0 else "JournalTab"
		tab.toggle_mode = true
		tab.pressed.connect(func() -> void:
			tab_container.current_tab = index
			_select_tab(index)
		)
		_place(tab, Rect2(157, 17, 184, 44) if index == 0 else Rect2(350, 22, 252, 39), book)
		tab_buttons.append(tab)
	heading = _label("NOSSA LIVRARIA", 37, false)
	_place(heading, Rect2(150, 84, 465, 54), book)
	tab_container = TabContainer.new()
	tab_container.name = "BookPages"
	tab_container.tabs_visible = false
	tab_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_place(tab_container, Rect2(Vector2.ZERO, DESIGN_SIZE), book)
	var improvements := Control.new()
	improvements.name = "Melhorias"
	improvements.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_container.add_child(improvements)
	var event := World.event_for_day(next_day)
	_place(_label("Próximo expediente · " + str(event.name), 21), Rect2(153, 145, 450, 36), improvements)
	var description := _label(str(event.description), 22)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(description, Rect2(153, 190, 442, 77), improvements)
	wallet_label = _label("", 27, false)
	_place(wallet_label, Rect2(153, 274, 400, 39), improvements)
	_upgrade_card("lighting", 0, Rect2(150, 330, 450, 280), improvements)
	_upgrade_card("shelves", 1, Rect2(704, 151, 450, 217), improvements)
	_upgrade_card("plants", 2, Rect2(704, 392, 450, 217), improvements)
	_build_journal(world, profiles)
	tab_container.tab_changed.connect(_select_tab)
	_select_tab(0)
	var back := _paper_button("VOLTAR AO FECHAMENTO", 21)
	back.name = "Back"
	back.pressed.connect(func() -> void: closed.emit())
	_place(back, Rect2(840, 628, 310, 50), book)
	refresh(world, funds)


func _upgrade_card(upgrade_id: String, icon_index: int, rect: Rect2, parent: Control) -> void:
	var info: Dictionary = World.UPGRADES[upgrade_id]
	var card := PageSection.new()
	card.name = "Upgrade_" + upgrade_id
	card.framed = upgrade_id == "lighting"
	_place(card, rect, parent)
	_place(_label(str(info.name), 31), Rect2(12, 9, 424 if upgrade_id == "lighting" else 358, 48), card)
	var icon := TextureRect.new()
	icon.name = "Illustration"
	var atlas: Texture2D = load("res://IMG/livraria_illustrations.png")
	var cell_width := atlas.get_width() / 3.0
	icon.texture = Art.cutout(atlas, Rect2(icon_index * cell_width, 0, cell_width, atlas.get_height()))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(icon, Rect2(8, 63, 97, 116) if upgrade_id == "lighting" else Rect2(378, 6, 62, 51), card)
	var detail := _label(World.upgrade_description(upgrade_id), 18)
	detail.name = "Description"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(detail, Rect2(109, 64, 328, 126) if upgrade_id == "lighting" else Rect2(12, 64, 426, 110), card)
	var buy := _paper_button("", 21)
	buy.name = "Buy_" + upgrade_id
	buy.pressed.connect(func() -> void: purchase_requested.emit(upgrade_id))
	var action_rect := Rect2(90, 211 if upgrade_id == "lighting" else 177, 300, 46 if upgrade_id == "lighting" else 40)
	_place(buy, action_rect, card)
	upgrade_buttons[upgrade_id] = buy
	var stamp := _installed_stamp()
	_place(stamp, Rect2(134, action_rect.position.y + 3, 216, 44), card)
	installed_stamps[upgrade_id] = stamp


func _build_journal(world: RefCounted, profiles: Array) -> void:
	var journal := Control.new()
	journal.name = "Caderno de leitores"
	journal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_container.add_child(journal)
	var introduction := _label("Cada leitor tem uma história em três compras. Ao concluir, você recebe um agradecimento e 8 moedas uma única vez.", 19)
	introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(introduction, Rect2(153, 145, 442, 82), journal)
	var split := ceili(profiles.size() / 2.0)
	for column in range(2):
		var scroll := ScrollContainer.new()
		scroll.name = "ReadersLeft" if column == 0 else "ReadersRight"
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.get_v_scroll_bar().custom_minimum_size.x = 5
		_place(scroll, Rect2(150, 242, 450, 366) if column == 0 else Rect2(704, 116, 450, 492), journal)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 19)
		scroll.add_child(list)
		for index in range(column * split, mini((column + 1) * split, profiles.size())):
			list.add_child(_reader_entry(world, profiles[index]))
	if profiles.is_empty():
		var empty := _label("As histórias dos leitores aparecerão aqui nas próximas visitas.", 22)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_place(empty, Rect2(153, 260, 440, 80), journal)


func _reader_entry(world: RefCounted, profile: Dictionary) -> PanelContainer:
	var customer_id := str(profile.id)
	var memory: Dictionary = world.memory(customer_id)
	var purchases := int(memory.get("purchases", 0))
	var story: Array = World.STORIES.get(customer_id, ["Novas leituras"])
	var entry := PanelContainer.new()
	entry.name = "Reader_" + customer_id
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color(0.4, 0.27, 0.12, 0.4)
	style.border_width_bottom = 1
	style.set_content_margin_all(9)
	entry.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	entry.add_child(content)
	var texts := [
		[str(profile.name) + " · " + str(story[0]), 22, INK],
		["%d visita(s) · %d compra(s) · História %d/3" % [int(memory.get("visits", 0)), purchases, mini(3, purchases)], 16, MUTED],
		[world.story_text(customer_id), 19, INK]
	]
	var previous_id := str(memory.get("last_book", ""))
	if not previous_id.is_empty():
		texts.append(["Última leitura: " + str(BookCatalog.get_book(previous_id).get("title", "")), 16, MUTED])
	var order: Dictionary = memory.get("order", {})
	if not order.is_empty():
		texts.append(["ENCOMENDA · %s · %s · +4 moedas ao entregar" % [str(BookCatalog.get_book(str(order.book_id)).get("title", "")), str(BookCatalog.get_condition(str(order.condition)).label)], 17, GREEN])
	for text in texts:
		var line := _label(str(text[0]), int(text[1]))
		line.add_theme_color_override("font_color", text[2])
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(line)
	return entry


func refresh(world: RefCounted, funds: int) -> void:
	wallet_label.text = "MOEDAS: %d" % funds
	for upgrade_id in upgrade_buttons:
		var buy: Button = upgrade_buttons[upgrade_id]
		var installed: bool = world.upgrades.has(upgrade_id)
		var price := int(World.UPGRADES[upgrade_id].price)
		buy.text = "COMPRAR · %d moedas" % price
		buy.disabled = installed or funds < price
		buy.visible = not installed
		installed_stamps[upgrade_id].visible = installed
		buy.tooltip_text = "Moedas insuficientes." if funds < price else "Comprar e instalar na livraria."


func _select_tab(index: int) -> void:
	heading.text = "NOSSA LIVRARIA" if index == 0 else "CADERNO DE LEITORES"
	heading.add_theme_font_size_override("font_size", 37 if index == 0 else 32)
	for tab_index in range(tab_buttons.size()):
		tab_buttons[tab_index].set_pressed_no_signal(tab_index == index)
		tab_buttons[tab_index].modulate = Color.WHITE if tab_index == index else Color("d8c5a4")


func _installed_stamp() -> PanelContainer:
	var stamp := PanelContainer.new()
	stamp.name = "Installed"
	stamp.rotation = -0.075
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.56, 0.64, 0.38, 0.3)
	style.border_color = GREEN
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	stamp.add_theme_stylebox_override("panel", style)
	var text := _label("INSTALADO", 26, false)
	text.add_theme_color_override("font_color", GREEN)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.add_child(text)
	return stamp


func _paper_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Art.handwriting(false))
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


func _label(text: String, font_size: int, italic := true) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Art.handwriting(italic))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label


func _layout_book() -> void:
	var available := size - Vector2(28, 20)
	var zoom := maxf(0.1, minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y))
	book.scale = Vector2.ONE * zoom
	book.position = (size - DESIGN_SIZE * zoom) * 0.5


func _place(control: Control, rect: Rect2, parent: Control) -> void:
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)
