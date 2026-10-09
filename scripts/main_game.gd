extends Node2D

const CUSTOMER_PROFILES: Array[Dictionary] = [
	{
		"name": "Lyria, a elfa",
		"greeting": "Boa tarde",
		"scene_path": "res://scenes/characters/elfa.tscn",
		"personality": "Observadora, paciente e muito ligada a historias antigas.",
		"history": "Viajou entre bosques procurando registros sobre as sementes luminosas de sua terra.",
		"preferences": "Prefere romances poeticos, mitologia e livros com temas de natureza."
	},
	{
		"name": "Tom, o aprendiz",
		"greeting": "Ola",
		"scene_path": "res://scenes/characters/aprendiz.tscn",
		"personality": "Curioso, entusiasmado e facilmente impressionado por magia.",
		"history": "Estuda com um mago itinerante e economiza moedas para montar sua primeira biblioteca.",
		"preferences": "Busca grimorios introdutorios, aventuras e livros cheios de diagramas."
	},
	{
		"name": "Mestre Elian",
		"greeting": "Com licenca",
		"scene_path": "res://scenes/characters/mago.tscn",
		"personality": "Reservado, exigente e sempre atento a detalhes raros.",
		"history": "Foi bibliotecario de uma torre arcana antes de partir em busca de conhecimentos perdidos.",
		"preferences": "Valoriza cronicas, tratados de magia e edicoes antigas bem conservadas."
	},
	{
		"name": "Borin, o anao",
		"greeting": "Boa noite",
		"scene_path": "res://scenes/characters/anao.tscn",
		"personality": "Direto, desconfiado e leal quando encontra um bom negocio.",
		"history": "Trabalhou em minas do norte e coleciona relatos sobre povos e reinos subterraneos.",
		"preferences": "Prefere mapas, relatos de viagem, engenharia e historias de batalhas."
	}
]
@onready var dialogue_panel: DialoguePanel = $UI/DialoguePanel
@onready var status_label: Label = $UI/StatusPanel/StatusLabel
@onready var customer_spawn: Node2D = $CustomerSpawn
@onready var shop_button: Button = $UI/ShopButton
var customer: Customer
var day_manager := DayManager.new()
var inventory := Inventory.new()
var money := 0
var reputation := 0
var merchant_offers: Dictionary = {}
var active_overlay: Node = null
var store_is_open := true

func _ready() -> void:
	randomize()
	for interactable in get_tree().get_nodes_in_group("interactables"): _connect_interactable(interactable)
	for interactable in [$Door, $Window, $Lamp, $Clipboard]: _connect_interactable(interactable)
	day_manager.customer_ready.connect(_on_customer_ready)
	day_manager.store_closed.connect(_on_store_closed)
	shop_button.pressed.connect(_show_shop)
	dialogue_panel.show_message("Livraria", "A loja esta abrindo. Aguarde a chegada do primeiro cliente.")
	day_manager.start_day()
	_update_status()

func _process(delta: float) -> void:
	day_manager.tick(delta)

func _connect_interactable(interactable: Interactable) -> void:
	if not interactable.interacted.is_connected(_on_interactable_clicked): interactable.interacted.connect(_on_interactable_clicked)

func _on_interactable_clicked(interactable: Interactable) -> void:
	if active_overlay != null: return
	match interactable.interaction_type:
		"customer":
			if not store_is_open or not customer.visible: return
			dialogue_panel.show_message(customer.customer_name, customer.get_greeting())
			_show_customer_profile()
		"clipboard": _open_inventory()
		"door": _request_store_closure()
		"window", "lamp": dialogue_panel.show_message(interactable.interaction_name, interactable.description)
		_: dialogue_panel.show_message(interactable.interaction_name, interactable.description)


func _show_customer_profile() -> void:
	if customer == null or not customer.visible:
		return
	customer.set_selected(true)
	var profile_panel := CustomerProfilePanel.new()
	$UI.add_child(profile_panel)
	active_overlay = profile_panel
	profile_panel.setup(customer, customer.get_profile(), BookCatalog.get_book(customer.requested_book_id))
	profile_panel.closed.connect(func() -> void:
		if is_instance_valid(customer):
			customer.set_selected(false)
		active_overlay = null
		profile_panel.queue_free()
	)

func _on_customer_ready(index: int, total: int) -> void:
	var profile: Dictionary = CUSTOMER_PROFILES.pick_random()
	var customer_scene := load(str(profile.scene_path)) as PackedScene
	if customer_scene == null:
		push_error("Nao foi possivel carregar a cena do cliente: %s" % profile.scene_path)
		return
	if customer != null:
		customer.set_selected(false)
		customer.queue_free()
	customer = customer_scene.instantiate() as Customer
	if customer == null:
		push_error("A cena do cliente precisa ter um script Customer na raiz.")
		return
	customer_spawn.add_child(customer)
	customer.configure(profile, BookCatalog.random_book())
	_connect_interactable(customer)
	customer.visible = true
	dialogue_panel.show_message("Porta", "%s entra na loja." % customer.customer_name)

func _on_store_closed() -> void:
	store_is_open = false
	if customer != null:
		customer.set_selected(false)
	customer.visible = false
	dialogue_panel.show_message("Livraria", "Esta ficando tarde acho que nenhum cliente mais ira vir.")
	if active_overlay != null:
		active_overlay.queue_free()
		active_overlay = null
	# O DayManager chega aqui exatamente 5 segundos apos a conclusao do ultimo cliente.
	# O proximo dia comeca automaticamente, sem exigir o botao "ABRIR O PROXIMO DIA".
	_finish_day()

func _make_merchant_offers() -> Dictionary:
	var candidates := BookCatalog.all_books()
	candidates.shuffle()
	var offers := {}
	for book in candidates:
		offers[book.id] = randi_range(1, 3)
	return offers

func _open_inventory() -> void:
	var screen := InventoryScreen.new()
	$UI.add_child(screen)
	active_overlay = screen
	var requested_book_id := customer.requested_book_id if store_is_open and customer.visible else ""
	screen.setup(inventory, requested_book_id)
	screen.deliver_requested.connect(func(book_id: String) -> void: _handle_stock_action(book_id, "deliver", screen))
	screen.negotiate_requested.connect(func(book_id: String) -> void: _handle_stock_action(book_id, "negotiate", screen))
	screen.offer_requested.connect(func(book_id: String) -> void: _handle_stock_action(book_id, "offer", screen))
	screen.closed.connect(func() -> void: active_overlay = null; screen.queue_free())

func _handle_stock_action(book_id: String, action: String, screen: InventoryScreen) -> void:
	if not store_is_open or not customer.visible or not inventory.has(book_id):
		return
	var book := BookCatalog.get_book(book_id)
	var result: Dictionary
	match action:
		"deliver": result = customer.deliver(book)
		"negotiate": result = customer.negotiate(book)
		"offer": result = customer.react_to_offer(book)
	if bool(result.accepted):
		inventory.remove(book_id)
		money += int(result.money)
		reputation += int(result.reputation)
		customer.set_selected(false)
		customer.visible = false
		day_manager.customer_completed()
	dialogue_panel.show_message(customer.customer_name, result.text)
	active_overlay = null
	screen.queue_free()
	_update_status()


func _show_shop() -> void:
	if active_overlay != null: return
	if merchant_offers.is_empty(): merchant_offers = _make_merchant_offers()
	var screen := MerchantScreen.new()
	$UI.add_child(screen)
	active_overlay = screen
	screen.setup(inventory, merchant_offers, money, not store_is_open)
	screen.purchase_requested.connect(func(book_id: String) -> void:
		var book := BookCatalog.get_book(book_id)
		if int(merchant_offers.get(book_id, 0)) <= 0 or money < int(book.buy_price): return
		money -= int(book.buy_price)
		merchant_offers[book_id] = int(merchant_offers[book_id]) - 1
		inventory.add(book_id)
		_update_status()
		screen.refresh(money)
	)
	screen.closed.connect(func() -> void: active_overlay = null; screen.queue_free())
	screen.next_day_requested.connect(func() -> void:
		active_overlay = null
		screen.queue_free()
		_finish_day()
	)

func _request_store_closure() -> void:
	if not store_is_open:
		dialogue_panel.show_message("Porta", "A loja ja esta fechada. Nenhum cliente novo podera entrar.")
		return
	var customer_inside := customer.visible
	var message := "Ainda ha um cliente dentro da loja. Deseja fechar a loja e pedir para ele se retirar?"
	if not customer_inside:
		message = "Nao ha clientes dentro da loja. Deseja fechar a loja?"
	_show_close_confirmation(message, customer_inside)

func _show_close_confirmation(message: String, customer_inside: bool) -> void:
	var confirmation := ConfirmationDialog.new()
	confirmation.title = "Fechar loja"
	confirmation.dialog_text = message
	confirmation.ok_button_text = "Fechar loja"
	confirmation.cancel_button_text = "Manter aberta"
	$UI.add_child(confirmation)
	active_overlay = confirmation
	confirmation.confirmed.connect(func() -> void:
		active_overlay = null
		confirmation.queue_free()
		_close_store(customer_inside)
	)
	confirmation.canceled.connect(func() -> void:
		active_overlay = null
		confirmation.queue_free()
	)
	confirmation.popup_centered()

func _close_store(customer_inside: bool) -> void:
	store_is_open = false
	day_manager.close_store()
	if customer_inside:
		reputation -= 1
		customer.set_selected(false)
		customer.visible = false
		dialogue_panel.show_message("Livraria", "A loja foi fechada e o cliente foi convidado a se retirar. Reputacao -1.")
	else:
		dialogue_panel.show_message("Livraria", "A loja foi fechada. Nenhum cliente estava dentro.")
	_update_status()

func _finish_day() -> void:
	day_manager.finish_day()
	store_is_open = true
	merchant_offers = _make_merchant_offers()
	_update_status()

func _update_status() -> void:
	status_label.text = "Dia %d | Moedas: %d | Reputacao: %d" % [day_manager.day, money, reputation]
