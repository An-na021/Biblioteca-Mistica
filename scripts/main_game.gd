extends Node2D

const CUSTOMER_PROFILES: Array[Dictionary] = [
	{
		"id": "lyria",
		"name": "Lyria, a elfa",
		"greeting": "Boa tarde",
		"scene_path": "res://scenes/characters/elfa.tscn",
		"personality": "Observadora, paciente e muito ligada a historias antigas.",
		"history": "Viajou entre bosques procurando registros sobre as sementes luminosas de sua terra.",
		"preferences": "Prefere romances poeticos, mitologia e livros com temas de natureza.",
		"preference_tags": ["natureza", "poesia", "mitologia"]
	},
	{
		"id": "tom",
		"name": "Tom, o aprendiz",
		"greeting": "Ola",
		"scene_path": "res://scenes/characters/aprendiz.tscn",
		"personality": "Curioso, entusiasmado e facilmente impressionado por magia.",
		"history": "Estuda com um mago itinerante e economiza moedas para montar sua primeira biblioteca.",
		"preferences": "Busca grimorios introdutorios, aventuras e livros cheios de diagramas.",
		"preference_tags": ["magia", "aventura", "diagramas", "mitologia"]
	},
	{
		"id": "mestre_elian",
		"name": "Mestre Elian",
		"greeting": "Com licenca",
		"scene_path": "res://scenes/characters/mago.tscn",
		"personality": "Reservado, exigente e sempre atento a detalhes raros.",
		"history": "Foi bibliotecario de uma torre arcana antes de partir em busca de conhecimentos perdidos.",
		"preferences": "Valoriza cronicas, tratados de magia e edicoes antigas bem conservadas.",
		"preference_tags": ["cronicas", "magia", "historia"]
	},
	{
		"id": "borin",
		"name": "Borin, o anao",
		"greeting": "Boa noite",
		"scene_path": "res://scenes/characters/anao.tscn",
		"personality": "Direto, desconfiado e leal quando encontra um bom negocio.",
		"history": "Trabalhou em minas do norte e coleciona relatos sobre povos e reinos subterraneos.",
		"preferences": "Prefere mapas, relatos de viagem, engenharia e historias de batalhas.",
		"preference_tags": ["mapas", "viagem", "engenharia", "batalhas"]
	},
	{
		"id": "thalion_grimorio",
		"name": "Thalion Grimório",
		"greeting": "Saudacoes, guardia dos livros",
		"scene_path": "res://scenes/characters/thalion_grimorio.tscn",
		"personality": "Um estudioso inquieto, generoso e fascinado por todo tipo de magia pratica.",
		"history": "Percorre cidades reunindo grimorios e ingredientes para suas pesquisas alquimicas.",
		"preferences": "Procura grimorios antigos, alquimia e estudos sobre artefatos arcanos.",
		"preference_tags": ["magia", "alquimia", "rituais"]
	},
	{
		"id": "professor_bigodes",
		"name": "Professor Bigodes",
		"greeting": "Miau... digo, boa tarde",
		"scene_path": "res://scenes/characters/professor_bigodes.tscn",
		"personality": "Erudito, meticuloso e um pouco dramatico; avalia cada livro com cuidado.",
		"history": "Ensina historia arcana e pesquisa a antiga tradicao dos familiares falantes.",
		"preferences": "Prefere bestiarios, historia da magia e tratados sobre criaturas encantadas.",
		"preference_tags": ["criaturas", "historia", "magia"]
	},
	{
		"id": "lilith_vespera",
		"name": "Lilith Vespera",
		"greeting": "Boa noite. Estou buscando algo raro.",
		"scene_path": "res://scenes/characters/lilith_vespera.tscn",
		"personality": "Confiante, observadora e precisa ao falar sobre seus estudos.",
		"history": "Viaja em busca de registros esquecidos para completar um arquivo de rituais antigos.",
		"preferences": "Interessa-se por cronicas ocultas, pactos lendarios e magia cerimonial.",
		"preference_tags": ["cronicas", "rituais", "mitologia"]
	},
	{
		"id": "evelune",
		"name": "Evelune",
		"greeting": "Ola, boa tarde.",
		"scene_path": "res://scenes/characters/evelune.tscn",
		"personality": "Gentil e reservada, mas se anima quando encontra conhecimentos novos.",
		"history": "Estuda a relacao entre ciclos lunares, plantas magicas e antigas receitas de pocao.",
		"preferences": "Busca herbarios, estudos dos ciclos lunares e receitas de alquimia natural.",
		"preference_tags": ["natureza", "alquimia", "poesia"]
	}
]
@onready var dialogue_panel: DialoguePanel = $UI/DialoguePanel
@onready var status_label: Label = $UI/StatusPanel/StatusLabel
@onready var customer_spawn: Node2D = $CustomerSpawn
@onready var shop_button: Button = $UI/ShopButton
var notifications: NotificationPanel
var customer: Customer
var day_manager := DayManager.new()
var inventory := Inventory.new()
var money := 0
var reputation := 0
var merchant_offers: Dictionary = {}
var active_overlay: Node = null
var store_is_open := true
var day_customers_served := 0
var day_sales_count := 0
var day_sales_revenue := 0
var day_errors := 0
var day_profit := 0
var day_start_reputation := 0
var customer_ids_seen_today: Array[String] = []

func _ready() -> void:
	randomize()
	notifications = NotificationPanel.new()
	$UI.add_child(notifications)
	for interactable in get_tree().get_nodes_in_group("interactables"): _connect_interactable(interactable)
	for interactable in [$Door, $Window, $Lamp, $Clipboard]: _connect_interactable(interactable)
	day_manager.customer_ready.connect(_on_customer_ready)
	day_manager.store_closed.connect(_on_store_closed)
	shop_button.pressed.connect(_show_shop)
	_style_shop_button()
	_validate_customer_data()
	_reset_day_summary_stats()
	dialogue_panel.show_message("Livraria", "A loja esta abrindo. Aguarde a chegada do primeiro cliente.")
	day_manager.start_day()
	_update_status()

func _style_shop_button() -> void:
	shop_button.custom_minimum_size = Vector2(156, 48)
	shop_button.add_theme_font_size_override("font_size", 16)
	shop_button.add_theme_color_override("font_color", Color("f6e8c7"))
	shop_button.add_theme_color_override("font_hover_color", Color("fff4d4"))
	shop_button.add_theme_color_override("font_pressed_color", Color("e5c678"))
	shop_button.add_theme_color_override("font_focus_color", Color("fff4d4"))
	shop_button.add_theme_color_override("font_disabled_color", Color("978b73"))
	shop_button.add_theme_constant_override("h_separation", 8)
	shop_button.add_theme_stylebox_override("normal", _shop_button_style(Color("38291d"), Color("bd9452"), 1, 5))
	shop_button.add_theme_stylebox_override("hover", _shop_button_style(Color("59402a"), Color("ebca82"), 2, 5))
	shop_button.add_theme_stylebox_override("pressed", _shop_button_style(Color("281d16"), Color("d4a94e"), 2, 3))
	shop_button.add_theme_stylebox_override("disabled", _shop_button_style(Color("302820"), Color("665b49"), 1, 5))
	shop_button.add_theme_stylebox_override("focus", _shop_button_style(Color("38291d"), Color("fff0bd"), 2, 5))

func _shop_button_style(fill: Color, border: Color, border_width: int, shadow_offset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 5
	style.shadow_offset = Vector2i(0, shadow_offset)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _process(delta: float) -> void:
	day_manager.tick(delta)


func _notify(title: String, message: String, tone: String = "info") -> void:
	if notifications != null:
		notifications.show_notification(title, message, tone)

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
	var available_profiles: Array[Dictionary] = []
	for candidate in CUSTOMER_PROFILES:
		if not customer_ids_seen_today.has(str(candidate.get("id", candidate.get("name", "")))):
			available_profiles.append(candidate)
	if available_profiles.is_empty():
		push_error("Nao ha clientes unicos restantes para este dia.")
		return
	var profile: Dictionary = available_profiles.pick_random()
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
	customer_ids_seen_today.append(str(profile.get("id", profile.get("name", ""))))
	customer_spawn.add_child(customer)
	var matching_books := BookCatalog.books_for_preferences(profile.get("preference_tags", []))
	if matching_books.is_empty():
		push_error("O perfil %s nao possui livros compativeis." % str(profile.get("id", profile.get("name", "?"))))
		return
	customer.configure(profile, matching_books.pick_random(), reputation)
	_connect_interactable(customer)
	customer.visible = true
	dialogue_panel.show_message("Porta", "%s entra na loja." % customer.customer_name)

func _validate_customer_data() -> void:
	var seen_ids: Dictionary = {}
	for profile in CUSTOMER_PROFILES:
		var profile_id := str(profile.get("id", ""))
		if profile_id.is_empty() or seen_ids.has(profile_id):
			push_error("Perfil de cliente sem identificador unico: %s" % str(profile.get("name", "?")))
			continue
		seen_ids[profile_id] = true
		if not Customer.REQUESTS.has(profile_id) or not Customer.VOICES.has(profile_id):
			push_error("Faltam falas para o perfil %s." % profile_id)
		elif str(Customer.REQUESTS[profile_id]).count("%s") != 1:
			push_error("A fala de pedido do perfil %s precisa de um campo para o titulo." % profile_id)
		if profile.get("preference_tags", []).is_empty():
			push_error("O perfil %s nao tem etiquetas de preferencia." % profile_id)
		if BookCatalog.books_for_preferences(profile.get("preference_tags", [])).is_empty():
			push_error("Nenhum livro corresponde as preferencias de %s." % profile_id)
		var voice_lines: Array = Customer.VOICES.get(profile_id, [])
		if voice_lines.size() != 6:
			push_error("O perfil %s precisa de seis falas contextuais." % profile_id)
		elif voice_lines[1].count("%s") != 1 or voice_lines[4].count("%s") != 1:
			push_error("Falas de recusa sem campo de titulo valido no perfil %s." % profile_id)

func _on_store_closed() -> void:
	store_is_open = false
	if customer != null:
		customer.set_selected(false)
	customer.visible = false
	dialogue_panel.show_message("Livraria", "Esta ficando tarde acho que nenhum cliente mais ira vir.")
	if active_overlay != null:
		active_overlay.queue_free()
		active_overlay = null
	_present_day_summary()

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
	var reputation_delta: int = int(result.get("reputation", 0))
	if reputation_delta != 0:
		reputation += reputation_delta
	if bool(result.accepted):
		inventory.remove(book_id)
		var sale_amount := int(result.money)
		money += sale_amount
		day_customers_served += 1
		day_sales_count += 1
		day_sales_revenue += sale_amount
		day_profit += sale_amount - int(book.get("buy_price", 0))
		_notify("VENDA CONCLUIDA", "%s por %d moedas." % [str(book.get("title", "Livro")), int(result.money)], "success")
		if inventory.get_quantity(book_id) == 0:
			_notify("ESTOQUE ESGOTADO", "%s acabou do estoque." % str(book.get("title", "Livro")), "warning")
		customer.set_selected(false)
		customer.visible = false
		day_manager.customer_completed()
	elif bool(result.get("completed", false)):
		day_errors += 1
		_notify("CLIENTE FOI EMBORA", "O cliente encerrou o atendimento sem comprar.", "warning")
		customer.set_selected(false)
		customer.visible = false
		day_manager.customer_completed()
	else:
		_notify("SUGESTAO RECUSADA", "O cliente ainda esta disposto a ouvir outra oferta.", "info")
	if reputation_delta != 0:
		var reputation_sign := "+" if reputation_delta > 0 else ""
		_notify("REPUTACAO ALTERADA", "%s%d (total: %d)." % [reputation_sign, reputation_delta, reputation], "reputation")
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
		day_errors += 1
		_notify("CLIENTE INSATISFEITO", "O cliente saiu antes de ser atendido.", "danger")
		_notify("REPUTACAO ALTERADA", "-1 (total: %d)." % reputation, "reputation")
		customer.set_selected(false)
		customer.visible = false
		dialogue_panel.show_message("Livraria", "A loja foi fechada e o cliente foi convidado a se retirar. Reputacao -1.")
	else:
		dialogue_panel.show_message("Livraria", "A loja foi fechada. Nenhum cliente estava dentro.")
	_update_status()
	_present_day_summary()

func _present_day_summary() -> void:
	if active_overlay != null:
		return
	var summary := DaySummaryScreen.new()
	$UI.add_child(summary)
	active_overlay = summary
	var reputation_change := reputation - day_start_reputation
	summary.setup(
		day_manager.day,
		day_customers_served,
		day_sales_count,
		day_sales_revenue,
		day_errors,
		reputation,
		reputation_change,
		day_profit,
		day_manager.customers_today
	)
	summary.next_day_requested.connect(func() -> void:
		active_overlay = null
		summary.queue_free()
		_finish_day()
	)

func _finish_day() -> void:
	customer_ids_seen_today.clear()
	day_manager.finish_day()
	store_is_open = true
	merchant_offers = _make_merchant_offers()
	_reset_day_summary_stats()
	_update_status()

func _reset_day_summary_stats() -> void:
	day_customers_served = 0
	day_sales_count = 0
	day_sales_revenue = 0
	day_errors = 0
	day_profit = 0
	day_start_reputation = reputation

func _update_status() -> void:
	status_label.text = "Dia %d | Moedas: %d | Reputacao: %d" % [day_manager.day, money, reputation]
