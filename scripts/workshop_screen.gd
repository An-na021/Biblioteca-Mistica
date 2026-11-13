extends Control

signal closed
signal purchase_requested(upgrade_id: String)
signal restoration_requested(book_id: String)
signal theme_requested(theme: String)
signal contract_action_requested(id: String, action: String)
signal contract_completed_requested(id: String)
signal contract_schedule_requested(id: String, pickup_day: int)

const Art = preload("res://scripts/hud_art.gd")
const Paper = preload("res://scripts/inventory_paper.gd")
const BackButtonStyle = preload("res://scripts/back_button_style.gd")
const RestorationBench = preload("res://scripts/restoration_bench.gd")
const RoomSign = preload("res://scripts/workshop_sign.gd")
const ROOM: Texture2D = preload("res://IMG/workshop/atelier_room_warm.png")
const World = preload("res://scripts/shop_world.gd")
const Diagnosis = preload("res://scripts/restoration_diagnosis.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const INK := Color("302014")
const MUTED := Color("6b5037")
const ITEMS: Array[Dictionary] = [
	{
		"id": "orders_cabinet", "name": "Armário de encomendas", "category": "Encomendas dos leitores",
		"area": Rect2(162, 111, 251, 453)
	},
	{
		"id": "restoration_table", "name": "Mesa de restauração", "category": "Cuidado com os livros",
		"area": Rect2(419, 283, 482, 358)
	},
	{
		"id": "themed_display", "name": "Vitrine temática", "category": "Livros em destaque",
		"area": Rect2(938, 244, 270, 355)
	}
]

# Hit areas follow the furniture painted in the room, not catalogue tabs.
class FurnitureHotspot extends Button:
	var _glow_strength := 0.0
	var _glow_tween: Tween

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(_refresh_glow)
		mouse_exited.connect(_refresh_glow)
		focus_entered.connect(_refresh_glow)
		focus_exited.connect(_refresh_glow)

	func _refresh_glow() -> void:
		if is_hovered() or has_focus():
			if _glow_tween != null and _glow_tween.is_running():
				return
			_glow_tween = create_tween().set_loops()
			_glow_tween.tween_method(_set_glow_strength, 0.12, 0.75, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_glow_tween.tween_method(_set_glow_strength, 0.75, 0.12, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			if _glow_tween != null:
				_glow_tween.kill()
			_glow_tween = null
			_set_glow_strength(0.0)

	func _set_glow_strength(value: float) -> void:
		_glow_strength = value
		queue_redraw()

	func _draw() -> void:
		if not is_hovered() and not has_focus():
			return
		var border := Rect2(Vector2.ZERO, size).grow(2)
		draw_rect(border, Color(1.0, 0.76, 0.32, _glow_strength * 0.08), true)
		draw_rect(border.grow(7.0), Color(1.0, 0.72, 0.25, _glow_strength * 0.22), false, 8.0, true)
		draw_rect(border, Color(1.0, 0.88, 0.52, _glow_strength * 0.9), false, 2.0, true)

class Sheet extends Control:
	func _draw() -> void:
		var edge := PackedVector2Array([
			Vector2(3, 2), Vector2(size.x * 0.33, 0), Vector2(size.x * 0.62, 3),
			Vector2(size.x - 3, 1), Vector2(size.x, 8),
			Vector2(size.x - 2, size.y * 0.65), Vector2(size.x, size.y - 4),
			Vector2(size.x - 8, size.y), Vector2(size.x * 0.45, size.y - 2),
			Vector2(2, size.y), Vector2(0, size.y - 7), Vector2(2, 2)
		])
		var shadow := edge.duplicate()
		for index in range(shadow.size()):
			shadow[index] += Vector2(3, 5)
		draw_colored_polygon(shadow, Color(0.07, 0.04, 0.02, 0.5))
		draw_colored_polygon(edge, Color("e4c991"))
		draw_polyline(edge, Color("745333"), 1.4, true)
		draw_line(Vector2(12, 8), Vector2(size.x - 13, 8), Color(0.9, 0.8, 0.58, 0.7), 1.0, true)

var room: Control
var hotspots: Array[Button] = []
var detail_layer: Control
var detail_panel: Control
var item_name: Label
var description: Label
var benefit: Label
var category: Label
var back_button: Button
var room_button: Button
var selected_item := -1
var world: RefCounted
var inventory: Inventory
var funds := 0
var day := 1
var profiles: Array = []
var wallet_label: Label
var buy_button: Button
var action_picker: OptionButton
var restoration_quality_picker: OptionButton
var restoration_condition := "usado"
var action_button: Button
var action_status: Label
var reservation_scroll: ScrollContainer
var reservation_list: VBoxContainer
var restoration_bench: Control
var orders_panel: Control
var orders_button: Button
var visiting_customer_id := ""
var can_schedule_today := true
var restoration_contract_id := ""
var _closing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("130e09")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	room = Control.new()
	room.name = "WorkshopRoom"
	room.size = DESIGN_SIZE
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room)
	var background := TextureRect.new()
	background.name = "RoomBackground"
	background.texture = ROOM
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(background, Rect2(Vector2.ZERO, DESIGN_SIZE), room)
	resized.connect(_layout_room)
	_layout_room()
	for index in range(ITEMS.size()):
		var hotspot := FurnitureHotspot.new()
		hotspot.name = "Furniture_" + str(ITEMS[index].id)
		hotspot.pressed.connect(func() -> void: show_item(index))
		_place(hotspot, ITEMS[index].area, room)
		hotspots.append(hotspot)
	var title_sign := RoomSign.new()
	title_sign.name = "AtelierTitleSign"
	_place(title_sign, Rect2(21, 15, 540, 86), room)
	_place(_sign_label("ATELIÊ DA LIVRARIA", 25), Rect2(77, 10, 436, 33), title_sign)
	_place(_sign_label("Clique nos móveis para instalar ou usar.", 16, true), Rect2(77, 48, 436, 26), title_sign)
	var wallet := RoomSign.new()
	wallet.name = "AtelierWalletSign"
	wallet.wallet = true
	_place(wallet, Rect2(1040, 18, 214, 76), room)
	_place(_sign_label("MOEDAS", 13), Rect2(76, 11, 111, 20), wallet)
	wallet_label = _sign_label("", 27)
	_place(wallet_label, Rect2(76, 31, 111, 36), wallet)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "VOLTAR À LIVRARIA"
	BackButtonStyle.apply(back_button)
	back_button.add_theme_font_size_override("font_size", 17)
	back_button.pressed.connect(_close)
	_place(back_button, Rect2(21, 660, 264, 43), room)
	orders_button = _orders_sign_button()
	orders_button.name = "RestorationOrdersButton"
	orders_button.pressed.connect(show_restoration_orders)
	_place(orders_button, Rect2(865, 660, 389, 43), room)
	_build_detail_panel()
	orders_panel = preload("res://scripts/restoration_orders_panel.gd").new()
	room.add_child(orders_panel)
	orders_panel.hide()
	orders_panel.closed.connect(show_room)
	orders_panel.action_requested.connect(func(id: String, action: String) -> void:
		if action == "work":
			_open_contract_bench(id)
		else:
			contract_action_requested.emit(id, action)
	)
	orders_panel.pickup_scheduled.connect(func(id: String, pickup_day: int) -> void: contract_schedule_requested.emit(id, pickup_day))
	show_room()

func _build_detail_panel() -> void:
	detail_layer = Control.new()
	detail_layer.name = "FurnitureDetails"
	_place(detail_layer, Rect2(Vector2.ZERO, DESIGN_SIZE), room)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.01, 0.48)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			show_room()
	)
	_place(dim, Rect2(Vector2.ZERO, DESIGN_SIZE), detail_layer)
	detail_panel = _note(Rect2(755, 108, 495, 550), detail_layer)
	detail_panel.name = "ActionPanel"
	detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	category = _label("", 15, false)
	category.add_theme_color_override("font_color", MUTED)
	_place(category, Rect2(27, 20, 441, 27), detail_panel)
	item_name = _label("", 28, false)
	item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(item_name, Rect2(25, 52, 445, 64), detail_panel)
	description = _label("", 20)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(description, Rect2(27, 122, 439, 96), detail_panel)
	benefit = _label("", 18)
	benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(benefit, Rect2(27, 224, 439, 80), detail_panel)
	buy_button = _paper_button("", 21)
	buy_button.name = "BuyUpgrade"
	buy_button.pressed.connect(func() -> void:
		if selected_item >= 0:
			purchase_requested.emit(str(ITEMS[selected_item].id))
	)
	_place(buy_button, Rect2(28, 346, 438, 46), detail_panel)
	action_picker = OptionButton.new()
	action_picker.name = "ActionPicker"
	BackButtonStyle.apply(action_picker)
	_style_action_picker(action_picker)
	action_picker.item_selected.connect(func(_index: int) -> void:
		if selected_item == 1:
			_refresh_restoration_quote()
	)
	_place(action_picker, Rect2(28, 335, 438, 40), detail_panel)
	restoration_quality_picker = OptionButton.new()
	restoration_quality_picker.name = "RestorationQualityPicker"
	BackButtonStyle.apply(restoration_quality_picker)
	_style_action_picker(restoration_quality_picker)
	restoration_quality_picker.tooltip_text = "Escolha a condição final do exemplar e confira o preço dos materiais."
	restoration_quality_picker.item_selected.connect(func(index: int) -> void:
		restoration_condition = str(restoration_quality_picker.get_item_metadata(index))
		_refresh_restoration_quote(false)
	)
	_place(restoration_quality_picker, Rect2(28, 358, 438, 38), detail_panel)
	action_button = _paper_button("", 19)
	action_button.name = "UseUpgrade"
	action_button.pressed.connect(_use_item)
	_place(action_button, Rect2(28, 388, 438, 44), detail_panel)
	action_status = _label("", 17)
	action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(action_status, Rect2(29, 443, 436, 48), detail_panel)
	reservation_scroll = ScrollContainer.new()
	reservation_scroll.name = "ReservedBooks"
	reservation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(reservation_scroll, Rect2(28, 330, 438, 151), detail_panel)
	reservation_list = VBoxContainer.new()
	reservation_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reservation_list.add_theme_constant_override("separation", 13)
	reservation_scroll.add_child(reservation_list)
	room_button = _paper_button("VOLTAR AO ATELIÊ", 18)
	room_button.name = "BackToRoom"
	room_button.pressed.connect(show_room)
	_place(room_button, Rect2(93, 497, 310, 36), detail_panel)

func _style_action_picker(picker: OptionButton) -> void:
	picker.add_theme_font_override("font", Art.handwriting(false))
	picker.add_theme_font_size_override("font_size", 18)
	picker.add_theme_constant_override("modulate_arrow", 1)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		picker.add_theme_color_override(state, INK)
	var popup := picker.get_popup()
	popup.add_theme_font_override("font", Art.handwriting(false))
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", INK)
	popup.add_theme_color_override("font_hover_color", INK)
	popup.add_theme_color_override("font_disabled_color", MUTED)
	popup.add_theme_constant_override("v_separation", 10)
	popup.add_theme_constant_override("h_separation", 10)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("dec38e")
	panel.border_color = Color("795735")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(3)
	panel.set_content_margin_all(10)
	panel.shadow_color = Color(0.08, 0.045, 0.02, 0.45)
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(2, 3)
	popup.add_theme_stylebox_override("panel", panel)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("c2a06a")
	hover.border_color = Color("a2804c")
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(2)
	popup.add_theme_stylebox_override("hover", hover)
	# A narrow ink bookmark replaces the default black radio circles.
	for state in ["radio_checked", "radio_unchecked"]:
		var icon := GradientTexture2D.new()
		icon.width = 5
		icon.height = 16
		icon.gradient = Gradient.new()
		var color := Color("795735") if state == "radio_checked" else Color.TRANSPARENT
		icon.gradient.colors = PackedColorArray([color, color])
		popup.add_theme_icon_override(state, icon)

func setup(value_world: RefCounted, value_inventory: Inventory, value_funds: int, value_day: int, value_profiles: Array = [], room_light: Color = Color.WHITE) -> void:
	world = value_world
	inventory = value_inventory
	profiles = value_profiles
	# This screen uses a CanvasLayer, so it must inherit the shop's daylight
	# explicitly. Tint only the room; paper and controls keep their contrast.
	room.get_node("RoomBackground").self_modulate = room_light
	refresh(value_funds, value_day)

func refresh(value_funds: int, value_day: int) -> void:
	funds = value_funds
	day = value_day
	wallet_label.text = str(funds)
	orders_button.text = "ENCOMENDAS DE RESTAURO · %d" % world.restoration_jobs.pending().size()
	if orders_panel.visible:
		orders_panel.refresh(world, day, funds, visiting_customer_id, can_schedule_today)
	_refresh_actions()

func show_item(index: int) -> void:
	selected_item = clampi(index, 0, ITEMS.size() - 1)
	var item: Dictionary = ITEMS[selected_item]
	var info: Dictionary = World.UPGRADES[str(item.id)]
	item_name.text = str(item.name)
	category.text = str(item.category).to_upper()
	description.text = str(info.description)
	benefit.text = str(info.usage)
	# Leave the clicked object visible beside its action sheet.
	detail_panel.position.x = 755 if selected_item == 0 else 30
	detail_layer.show()
	_refresh_actions()
	room_button.grab_focus()

func show_room() -> void:
	detail_layer.hide()
	if is_instance_valid(orders_panel):
		orders_panel.hide()
	selected_item = -1
	for hotspot in hotspots:
		hotspot.release_focus()
	room_button.release_focus()

func _refresh_actions() -> void:
	for control in [buy_button, action_picker, restoration_quality_picker, action_button, action_status, reservation_scroll]:
		control.hide()
	if world == null or inventory == null or selected_item < 0:
		return
	var item_id := str(ITEMS[selected_item].id)
	if not world.upgrades.has(item_id):
		var price := int(World.UPGRADES[item_id].price)
		buy_button.text = "INSTALAR · %d moedas" % price
		buy_button.disabled = funds < price
		buy_button.tooltip_text = "Moedas insuficientes." if buy_button.disabled else "Comprar e instalar este móvel."
		buy_button.show()
		action_status.text = "Faltam %d moedas para instalar." % (price - funds) if funds < price else "Compra única. Depois, clique no móvel para usá-lo."
		action_status.show()
		return
	if item_id == "orders_cabinet":
		_refresh_reservations()
		return
	var previous_book := str(action_picker.get_item_metadata(action_picker.selected)) if action_picker.selected >= 0 else ""
	action_picker.clear()
	action_picker.position.y = 335
	action_button.position.y = 388
	action_status.position.y = 443
	action_picker.show()
	action_button.show()
	action_status.show()
	if item_id == "restoration_table":
		for entry in world.restorable_books(inventory):
			action_picker.add_item(str(entry.title))
			action_picker.set_item_metadata(action_picker.item_count - 1, str(entry.id))
			if str(entry.id) == previous_book:
				action_picker.select(action_picker.item_count - 1)
		action_picker.position.y = 311
		action_picker.size.y = 38
		action_button.position.y = 405
		action_status.position.y = 452
		_refresh_restoration_quote()
	else:
		action_picker.add_item("Sem tema em destaque")
		action_picker.set_item_metadata(0, "")
		var tags: Array[String] = []
		for entry in BookCatalog.all_books():
			for tag in entry.get("tags", []):
				if not tags.has(str(tag)):
					tags.append(str(tag))
		tags.sort()
		for tag in tags:
			action_picker.add_item(tag.capitalize())
			action_picker.set_item_metadata(action_picker.item_count - 1, tag)
			if tag == world.display_theme:
				action_picker.select(action_picker.item_count - 1)
		action_picker.disabled = false
		action_button.disabled = false
		action_button.text = "EXPOR ESTE TEMA"
		action_status.text = "Tema exposto: " + (str(world.display_theme).capitalize() if not str(world.display_theme).is_empty() else "nenhum") + ". Vale para os próximos clientes."

func _selected_restoration_condition() -> String:
	var index := restoration_quality_picker.selected
	if index >= 0:
		var condition := str(restoration_quality_picker.get_item_metadata(index))
		if condition in World.RESTORATION_TARGETS:
			return condition
	return restoration_condition

func _refresh_restoration_quote(rebuild_picker := true) -> void:
	var used_today: bool = world.last_restoration_day == day
	var has_book := action_picker.item_count > 0 and action_picker.selected >= 0
	var book_id := str(action_picker.get_item_metadata(action_picker.selected)) if has_book else ""
	restoration_condition = _selected_restoration_condition()
	if rebuild_picker:
		restoration_quality_picker.clear()
		var selected_index := 0
		for condition in World.RESTORATION_TARGETS:
			var cost := World.restoration_cost(book_id, condition)
			restoration_quality_picker.add_item("%s · %d moedas" % [str(BookCatalog.get_condition(condition).label), maxi(0, cost)])
			var index := restoration_quality_picker.item_count - 1
			restoration_quality_picker.set_item_metadata(index, condition)
			# Price never disables a choice: the player may inspect any repair.
			# Restore selection AFTER all items exist; disabling the selected item
			# while adding the others made OptionButton silently jump to "Raro".
			restoration_quality_picker.set_item_disabled(index, cost < 0)
			if condition == restoration_condition:
				selected_index = index
		restoration_quality_picker.select(selected_index)
	restoration_condition = _selected_restoration_condition()
	var quote := World.restoration_cost(book_id, restoration_condition)
	restoration_quality_picker.visible = has_book
	restoration_quality_picker.disabled = used_today or not has_book
	action_picker.disabled = used_today or not has_book
	action_button.text = "ABRIR BANCADA"
	action_button.tooltip_text = "Abrir é gratuito. Só o conserto é cobrado, quando for concluído."
	action_button.disabled = used_today or not has_book or quote < 0
	if used_today:
		action_status.text = "Restauro do estoque concluído hoje. O limite de encomendas é separado."
	elif not has_book:
		action_status.text = "Não há livros danificados disponíveis no estoque."
	else:
		action_status.text = "Conserto: %s · %d moedas ao concluir." % [str(BookCatalog.get_condition(restoration_condition).label), quote]
		benefit.text = "Diagnóstico: " + Diagnosis.summary(Diagnosis.for_book(book_id, day))
		if funds < quote:
			var missing := quote - funds
			action_status.text += "\nFalta 1 moeda para concluir." if missing == 1 else "\nFaltam %d moedas para concluir." % missing

func _refresh_reservations() -> void:
	for child in reservation_list.get_children():
		reservation_list.remove_child(child)
		child.queue_free()
	reservation_scroll.show()
	var allocated: Dictionary = {}
	for order in world.pending_orders():
		var key := str(order.book_id) + ":" + str(order.condition)
		allocated[key] = int(allocated.get(key, 0)) + 1
		var ready := inventory.get_condition_quantity(str(order.book_id), str(order.condition)) >= int(allocated[key])
		var reader := str(order.customer_id)
		for profile in profiles:
			if str(profile.id) == reader:
				reader = str(profile.name)
				break
		var label := _label("%s\n%s · %s\n%s" % [reader, str(BookCatalog.get_book(str(order.book_id)).get("title", "Livro")), str(BookCatalog.get_condition(str(order.condition)).label), "Guardado para este leitor" if ready else "Falta comprar o exemplar na loja"], 18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color("4b6035") if ready else MUTED)
		reservation_list.add_child(label)
	if reservation_list.get_child_count() == 0:
		var empty := _label("Ainda não há encomendas. Quando um leitor reservar um livro, ele aparecerá aqui.", 19)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reservation_list.add_child(empty)

func _use_item() -> void:
	if selected_item < 0 or action_button.disabled or action_picker.item_count == 0:
		return
	var value := str(action_picker.get_item_metadata(action_picker.selected))
	if str(ITEMS[selected_item].id) == "restoration_table":
		_open_restoration_bench(value)
	else:
		theme_requested.emit(value)

func _open_restoration_bench(book_id: String) -> void:
	restoration_condition = _selected_restoration_condition()
	var quote := World.restoration_cost(book_id, restoration_condition)
	if is_instance_valid(restoration_bench) or quote < 0 or not world.upgrades.has("restoration_table") or world.last_restoration_day == day or world.available_for_customer(inventory, book_id, "danificado") <= 0:
		return
	var book := BookCatalog.get_book(book_id)
	if book.is_empty():
		return
	restoration_bench = RestorationBench.new()
	restoration_bench.name = "RestorationBench"
	restoration_contract_id = ""
	room.add_child(restoration_bench)
	restoration_bench.setup(book, restoration_condition, funds, Diagnosis.for_book(book_id, day))
	detail_layer.hide()
	restoration_bench.completed.connect(func(completed_book: String) -> void:
		if can_finish_restoration(completed_book):
			restoration_requested.emit(completed_book)
	)
	restoration_bench.closed.connect(func() -> void:
		var closing := restoration_bench
		restoration_bench = null
		closing.queue_free()
		show_item(1)
	)

func can_finish_restoration(book_id: String) -> bool:
	return restoration_contract_id.is_empty() and is_instance_valid(restoration_bench) and restoration_bench.can_submit(book_id)

func show_restoration_orders() -> void:
	if is_instance_valid(restoration_bench):
		return
	detail_layer.hide()
	orders_panel.refresh(world, day, funds, visiting_customer_id, can_schedule_today)
	orders_panel.show()

func _open_contract_bench(id: String) -> void:
	if is_instance_valid(restoration_bench) or not world.upgrades.has("restoration_table") or world.last_contract_restoration_day == day or not world.restoration_jobs.can_work(id, day):
		return
	var job: Dictionary = world.restoration_jobs.get_job(id)
	restoration_contract_id = id
	restoration_bench = RestorationBench.new()
	restoration_bench.name = "RestorationBench"
	room.add_child(restoration_bench)
	restoration_bench.setup(BookCatalog.get_book(str(job.book_id)), str(job.condition), funds, Diagnosis.profile(str(job.diagnosis)))
	restoration_bench.restoration_cost = int(job.cost)
	restoration_bench._materials_label.text = "Materiais: %d moedas ao concluir" % int(job.cost)
	orders_panel.hide()
	restoration_bench.completed.connect(func(_book: String) -> void:
		if can_finish_contract(id):
			contract_completed_requested.emit(id)
	)
	restoration_bench.closed.connect(func() -> void:
		var closing := restoration_bench
		restoration_bench = null
		restoration_contract_id = ""
		closing.queue_free()
		show_restoration_orders()
	)

func can_finish_contract(id: String) -> bool:
	var job: Dictionary = world.restoration_jobs.get_job(id)
	return not job.is_empty() and restoration_contract_id == id and is_instance_valid(restoration_bench) and restoration_bench.target_condition == str(job.condition) and restoration_bench.can_submit(str(job.book_id))

func restoration_target(book_id: String) -> String:
	return restoration_bench.target_condition if can_finish_restoration(book_id) else ""

func restoration_quote(book_id: String) -> int:
	return restoration_bench.restoration_cost if can_finish_restoration(book_id) else -1

func restoration_finished(success: bool) -> void:
	if is_instance_valid(restoration_bench):
		restoration_bench.show_result(success)

func _close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()

func _layout_room() -> void:
	var zoom := maxf(0.1, minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y))
	room.scale = Vector2.ONE * zoom
	room.position = (size - DESIGN_SIZE * zoom) * 0.5

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(restoration_bench):
		return
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		if detail_layer.visible or orders_panel.visible:
			show_room()
		else:
			_close()
		get_viewport().set_input_as_handled()

func _place(control: Control, rect: Rect2, parent: Control) -> void:
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)

func _note(rect: Rect2, parent: Control) -> Control:
	var note := Sheet.new()
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(note, rect, parent)
	return note

func _label(text: String, font_size: int, italic := true) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Art.handwriting(italic))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label

func _sign_label(text: String, font_size: int, italic := false) -> Label:
	var label := _label(text, font_size, italic)
	label.add_theme_color_override("font_color", Color("c7b18a") if italic else Color("e0c18b"))
	label.add_theme_color_override("font_shadow_color", Color(0.07, 0.04, 0.02, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _paper_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Art.handwriting(false))
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("8d6437")
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", focus)
	button.add_child(Paper.ButtonBacking.new())
	return button

func _orders_sign_button() -> Button:
	var button := Button.new()
	button.text = "ENCOMENDAS DE RESTAURO"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Art.handwriting(false))
	button.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("e0c18b"))
	button.add_theme_color_override("font_hover_color", Color("f6dda9"))
	button.add_theme_color_override("font_hover_pressed_color", Color("f6dda9"))
	button.add_theme_color_override("font_shadow_color", Color(0.07, 0.04, 0.02, 0.9))
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 1)
	var backing := RoomSign.new()
	backing.name = "WoodenSign"
	backing.compact = true
	backing.show_behind_parent = true
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(backing)
	var refresh_sign := func() -> void:
		backing.self_modulate = Color(1.15, 1.12, 1.06) if button.is_hovered() or button.has_focus() else Color.WHITE
	button.mouse_entered.connect(refresh_sign)
	button.mouse_exited.connect(refresh_sign)
	button.focus_entered.connect(refresh_sign)
	button.focus_exited.connect(refresh_sign)
	button.button_down.connect(func() -> void: backing.self_modulate = Color(0.85, 0.82, 0.77))
	button.button_up.connect(refresh_sign)
	return button
