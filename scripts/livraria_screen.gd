extends "res://scripts/shop_screen.gd"

signal purchase_requested(upgrade_id: String)
signal closed

const World = preload("res://scripts/shop_world.gd")
var wallet_label: Label
var tab_container: TabContainer
var upgrade_buttons: Dictionary = {}

func setup(world: RefCounted, funds: int, next_day: int, profiles: Array) -> void:
	var event := World.event_for_day(next_day)
	var layout := build_panel("NOSSA LIVRARIA", "Próximo expediente · %s\n%s" % [str(event.name), str(event.description)], Vector2(820, 620))
	wallet_label = label("", 17, GOLD)
	layout.add_child(wallet_label)
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tab_container)
	var improvements := _scroll_tab("Melhorias")
	for upgrade_id in World.UPGRADES:
		var info: Dictionary = World.UPGRADES[upgrade_id]
		improvements.add_child(label(str(info.name), 18, GOLD))
		improvements.add_child(label(str(info.description)))
		var buy := button(improvements, "", _request_purchase.bind(str(upgrade_id)))
		upgrade_buttons[upgrade_id] = buy
	var journal := _scroll_tab("Caderno de leitores")
	journal.add_child(label("Cada leitor tem uma história em três compras. Ao concluir, você recebe um agradecimento e 8 moedas uma única vez."))
	for profile in profiles:
		var customer_id := str(profile.id)
		var memory: Dictionary = world.memory(customer_id)
		var purchases := int(memory.get("purchases", 0))
		var story: Array = World.STORIES.get(customer_id, ["Novas leituras"])
		journal.add_child(label(str(profile.name) + " · " + str(story[0]), 17, GOLD))
		journal.add_child(label("%d visita(s) · %d compra(s) · História %d/3\n%s" % [int(memory.get("visits", 0)), purchases, mini(3, purchases), world.story_text(customer_id)]))
		var previous_id := str(memory.get("last_book", ""))
		if not previous_id.is_empty():
			journal.add_child(label("Última leitura: " + str(BookCatalog.get_book(previous_id).get("title", "")), 12))
		var order: Dictionary = memory.get("order", {})
		if not order.is_empty():
			journal.add_child(label("ENCOMENDA · %s · %s · +4 moedas ao entregar" % [str(BookCatalog.get_book(str(order.book_id)).get("title", "")), str(BookCatalog.get_condition(str(order.condition)).label)], 13, GOLD))
	button(layout, "VOLTAR AO FECHAMENTO", func() -> void: closed.emit())
	refresh(world, funds)

func _scroll_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_container.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list

func refresh(world: RefCounted, funds: int) -> void:
	wallet_label.text = "MOEDAS: %d" % funds
	for upgrade_id in upgrade_buttons:
		var buy: Button = upgrade_buttons[upgrade_id]
		var installed: bool = world.upgrades.has(upgrade_id)
		var price := int(World.UPGRADES[upgrade_id].price)
		buy.text = "INSTALADO" if installed else "COMPRAR · %d moedas" % price
		buy.disabled = installed or funds < price
		buy.tooltip_text = "Já faz parte da livraria." if installed else ("Moedas insuficientes." if funds < price else "Comprar e instalar na livraria.")

func _request_purchase(upgrade_id: String) -> void:
	purchase_requested.emit(upgrade_id)
