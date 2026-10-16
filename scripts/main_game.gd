extends Node2D

const MoodTimerUI = preload("res://scripts/mood_timer.gd")
const Progression = preload("res://scripts/progression_manager.gd")
const DistrictPickerUI = preload("res://scripts/district_screen.gd")

const CUSTOMER_PROFILES: Array[Dictionary] = [
	{
		"id": "lyria",
		"name": "Lyria, a elfa",
		"greeting": "Boa tarde",
		"scene_path": "res://scenes/characters/elfa.tscn",
		"personality": "Observadora, paciente e muito ligada a historias antigas.",
		"mood_type": "indeciso",
		"history": "Viajou entre bosques procurando registros sobre as sementes luminosas de sua terra.",
		"preferences": "Prefere romances poeticos, mitologia e livros com temas de natureza.",
		"preference_tags": ["natureza", "poesia", "mitologia"],
		"preferred_condition": "usado"
	},
	{
		"id": "tom",
		"name": "Tom, o aprendiz",
		"greeting": "Ola",
		"scene_path": "res://scenes/characters/aprendiz.tscn",
		"personality": "Curioso, entusiasmado e facilmente impressionado por magia.",
		"mood_type": "apressado",
		"history": "Estuda com um mago itinerante e economiza moedas para montar sua primeira biblioteca.",
		"preferences": "Busca grimorios introdutorios, aventuras e livros cheios de diagramas.",
		"preference_tags": ["magia", "aventura", "diagramas", "mitologia"],
		"preferred_condition": "novo"
	},
	{
		"id": "mestre_elian",
		"name": "Mestre Elian",
		"greeting": "Com licenca",
		"scene_path": "res://scenes/characters/mago.tscn",
		"personality": "Reservado, exigente e sempre atento a detalhes raros.",
		"mood_type": "dificil",
		"history": "Foi bibliotecario de uma torre arcana antes de partir em busca de conhecimentos perdidos.",
		"preferences": "Valoriza cronicas, tratados de magia e edicoes antigas bem conservadas.",
		"preference_tags": ["cronicas", "magia", "historia"],
		"preferred_condition": "raro"
	},
	{
		"id": "borin",
		"name": "Borin, o anao",
		"greeting": "Boa noite",
		"scene_path": "res://scenes/characters/anao.tscn",
		"personality": "Direto, desconfiado e leal quando encontra um bom negocio.",
		"mood_type": "negociador",
		"history": "Trabalhou em minas do norte e coleciona relatos sobre povos e reinos subterraneos.",
		"preferences": "Prefere mapas, relatos de viagem, engenharia e historias de batalhas.",
		"preference_tags": ["mapas", "viagem", "engenharia", "batalhas"],
		"preferred_condition": "usado"
	},
	{
		"id": "thalion_grimorio",
		"name": "Thalion Grimório",
		"greeting": "Saudacoes, guardia dos livros",
		"scene_path": "res://scenes/characters/thalion_grimorio.tscn",
		"personality": "Um estudioso inquieto, generoso e fascinado por todo tipo de magia pratica.",
		"mood_type": "colecionador",
		"history": "Percorre cidades reunindo grimorios e ingredientes para suas pesquisas alquimicas.",
		"preferences": "Procura grimorios antigos, alquimia e estudos sobre artefatos arcanos.",
		"preference_tags": ["magia", "alquimia", "rituais"],
		"preferred_condition": "raro"
	},
	{
		"id": "professor_bigodes",
		"name": "Professor Bigodes",
		"greeting": "Miau... digo, boa tarde",
		"scene_path": "res://scenes/characters/professor_bigodes.tscn",
		"personality": "Erudito, meticuloso e um pouco dramatico; avalia cada livro com cuidado.",
		"mood_type": "dificil",
		"history": "Ensina historia arcana e pesquisa a antiga tradicao dos familiares falantes.",
		"preferences": "Prefere bestiarios, historia da magia e tratados sobre criaturas encantadas.",
		"preference_tags": ["criaturas", "historia", "magia"],
		"preferred_condition": "novo"
	},
	{
		"id": "lilith_vespera",
		"name": "Lilith Vespera",
		"greeting": "Boa noite. Estou buscando algo raro.",
		"scene_path": "res://scenes/characters/lilith_vespera.tscn",
		"personality": "Confiante, observadora e precisa ao falar sobre seus estudos.",
		"mood_type": "colecionador",
		"history": "Viaja em busca de registros esquecidos para completar um arquivo de rituais antigos.",
		"preferences": "Interessa-se por cronicas ocultas, pactos lendarios e magia cerimonial.",
		"preference_tags": ["cronicas", "rituais", "mitologia"],
		"preferred_condition": "raro"
	},
	{
		"id": "evelune",
		"name": "Evelune",
		"greeting": "Ola, boa tarde.",
		"scene_path": "res://scenes/characters/evelune.tscn",
		"personality": "Gentil e reservada, mas se anima quando encontra conhecimentos novos.",
		"mood_type": "indeciso",
		"history": "Estuda a relacao entre ciclos lunares, plantas magicas e antigas receitas de pocao.",
		"preferences": "Busca herbarios, estudos dos ciclos lunares e receitas de alquimia natural.",
		"preference_tags": ["natureza", "alquimia", "poesia"],
		"preferred_condition": "novo"
	}
]
const MOOD_PATIENCE_SECONDS := {
	"apressado": 60.0,
	"indeciso": 60.0,
	"colecionador": 60.0,
	"negociador": 60.0,
	"dificil": 60.0
}
const DISTRICTS: Array[Dictionary] = [
	{
		"id": "centro",
		"name": "Centro Antigo",
		"description": "Clientes habituais e leituras variadas.",
		"unlock_day": 1,
		"unlock_reputation": 0,
		"customer_ids": ["tom", "professor_bigodes", "thalion_grimorio", "mestre_elian"],
		"book_ids": ["jardim_horas", "mar_vermelho", "inventario_chuva", "reino_vidro"]
	},
	{
		"id": "bosque",
		"name": "Bairro das Folhas",
		"description": "Leitores de natureza, poesia e magia antiga.",
		"unlock_day": 3,
		"unlock_reputation": 2,
		"customer_ids": ["lyria", "evelune", "lilith_vespera", "thalion_grimorio"],
		"book_ids": ["floresta_azul", "jardim_horas", "inventario_chuva", "reino_vidro"]
	},
	{
		"id": "minas",
		"name": "Distrito das Minas",
		"description": "Colecionadores de mapas, crônicas e engenharia.",
		"unlock_day": 5,
		"unlock_reputation": 4,
		"customer_ids": ["borin", "tom", "mestre_elian", "professor_bigodes"],
		"book_ids": ["cronicas_norte", "mar_vermelho", "ultimo_dragao", "relogio_perdido"]
	}
]
const SUPPLIERS: Array[Dictionary] = [
	{"id": "praca", "name": "Mercador da Praça", "price_factor": 1.0, "risk": 0.03, "description": "Preços equilibrados; 3% de chance de o exemplar chegar danificado.", "tags": []},
	{"id": "caravana", "name": "Caravana Verde", "price_factor": 0.82, "risk": 0.22, "description": "Preços menores; 22% de chance de o exemplar chegar danificado.", "tags": ["natureza", "poesia", "viagem", "alquimia"]},
	{"id": "antiquario", "name": "Antiquário das Minas", "price_factor": 1.28, "risk": 0.05, "description": "Edições raras; 5% de chance de o exemplar chegar danificado.", "tags": ["cronicas", "mitologia", "mapas", "historia", "rituais"]}
]
@onready var dialogue_panel: DialoguePanel = $UI/DialoguePanel
@onready var status_label: Label = $UI/StatusPanel/StatusLabel
@onready var customer_spawn: Node2D = $CustomerSpawn
var notifications: NotificationPanel
var customer: Customer
var day_manager := DayManager.new()
var inventory := Inventory.new()
var progression = Progression.new()
var money := 0
var reputation := 0
var merchant_offers: Dictionary = {}
var supplier_markets: Dictionary = {}
var selected_supplier_id := "praca"
var current_district_id := "centro"
var active_overlay: Node = null
var store_is_open := true
var day_customers_served := 0
var day_sales_count := 0
var day_sales_revenue := 0
var day_errors := 0
var day_profit := 0
var day_start_reputation := 0
var customer_ids_seen_today: Array[String] = []
var customer_time_limit := 0.0
var customer_time_left := 0.0
var mood_timer: Control

func _ready() -> void:
	randomize()
	notifications = NotificationPanel.new()
	$UI.add_child(notifications)
	for interactable in get_tree().get_nodes_in_group("interactables"): _connect_interactable(interactable)
	for interactable in [$Door, $Window, $Lamp, $Clipboard]: _connect_interactable(interactable)
	mood_timer = MoodTimerUI.new() as Control
	$UI.add_child(mood_timer)
	mood_timer.hide()
	day_manager.customer_ready.connect(_on_customer_ready)
	day_manager.store_closed.connect(_on_store_closed)
	_validate_customer_data()
	_reset_day_summary_stats()
	progression.record_district_visit(current_district_id)
	dialogue_panel.show_message("Livraria", "A loja esta abrindo. Aguarde a chegada do primeiro cliente.")
	day_manager.start_day(_current_customer_limit())
	_update_status()

func _process(delta: float) -> void:
	day_manager.tick(delta)
	var customer_active := store_is_open and customer != null and is_instance_valid(customer) and customer.visible
	if mood_timer != null:
		mood_timer.visible = customer_active
	if not customer_active or active_overlay is CustomerProfilePanel:
		return
	customer_time_left = maxf(0.0, customer_time_left - delta)
	mood_timer.call("set_time_left", customer_time_left)
	if customer_time_left <= 0.0:
		_customer_service_timed_out()


func _customer_service_timed_out() -> void:
	if customer == null or not customer.visible or not store_is_open:
		return
	customer.set_selected(false)
	customer.visible = false
	day_errors += 1
	reputation -= 1
	progression.record_error()
	progression.record_reputation(reputation)
	_notify_new_achievements()
	if active_overlay != null:
		active_overlay.queue_free()
		active_overlay = null
	_notify("TEMPO ESGOTADO", "%s foi embora sem comprar. Reputação -1." % customer.customer_name, "danger")
	_notify("REPUTAÇÃO ALTERADA", "-1 (total: %d)." % reputation, "reputation")
	dialogue_panel.show_message(customer.customer_name, "O cliente perdeu a paciência e foi embora sem comprar.")
	day_manager.customer_completed()
	_update_status()

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
	profile_panel.setup(customer, customer.get_profile())
	profile_panel.closed.connect(func() -> void:
		if is_instance_valid(customer):
			customer.set_selected(false)
		active_overlay = null
		profile_panel.queue_free()
	)

func _on_customer_ready(index: int, total: int) -> void:
	if index == 1:
		progression.begin_day(day_manager.day, total)
	var available_profiles: Array[Dictionary] = []
	var district := _current_district()
	var district_customer_ids: Array = district.get("customer_ids", [])
	for candidate in CUSTOMER_PROFILES:
		var candidate_id := str(candidate.get("id", candidate.get("name", "")))
		if district_customer_ids.has(candidate_id) and not customer_ids_seen_today.has(candidate_id):
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
	var matching_books: Array[Dictionary] = []
	var district_book_ids: Array = district.get("book_ids", [])
	for book in BookCatalog.books_for_preferences(profile.get("preference_tags", [])):
		if district_book_ids.has(str(book.get("id", ""))):
			matching_books.append(book)
	if matching_books.is_empty():
		push_error("O perfil %s nao possui livros compativeis." % str(profile.get("id", profile.get("name", "?"))))
		return
	customer.configure(profile, matching_books.pick_random(), reputation)
	var mood_type := str(profile.get("mood_type", "indeciso"))
	customer_time_limit = float(MOOD_PATIENCE_SECONDS.get(mood_type, 60.0))
	customer_time_left = customer_time_limit
	mood_timer.call("setup", mood_type, customer_time_limit)
	_connect_interactable(customer)
	customer.visible = true
	dialogue_panel.show_message("Porta", "%s entra na loja." % customer.customer_name)
	_update_status()

func _current_district() -> Dictionary:
	for district in DISTRICTS:
		if str(district.get("id", "")) == current_district_id:
			return district
	return DISTRICTS[0]

func _current_customer_limit() -> int:
	return int(_current_district().get("customer_ids", []).size())

func _district_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for district in DISTRICTS:
		var option := district.duplicate(true)
		var unlocked := day_manager.day + 1 >= int(district.get("unlock_day", 1)) or reputation >= int(district.get("unlock_reputation", 0))
		option["unlocked"] = unlocked
		if not unlocked:
			option["unlock_hint"] = "Desbloqueia no dia %d ou com reputação %d." % [int(district.get("unlock_day", 1)), int(district.get("unlock_reputation", 0))]
		options.append(option)
	return options

func _notify_new_achievements() -> void:
	for achievement in progression.take_new_achievements():
		_notify("CONQUISTA DESBLOQUEADA", "%s: %s" % [str(achievement.get("title", "Conquista")), str(achievement.get("description", ""))], "success")

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

func _prepare_supplier_markets() -> void:
	supplier_markets.clear()
	for supplier in SUPPLIERS:
		supplier_markets[str(supplier.get("id", ""))] = _make_merchant_offers(supplier)
	if not supplier_markets.has(selected_supplier_id):
		selected_supplier_id = "praca"
	merchant_offers = supplier_markets.get(selected_supplier_id, {})

func _make_merchant_offers(supplier: Dictionary) -> Dictionary:
	var district := _current_district()
	var district_book_ids: Array = district.get("book_ids", [])
	var supplier_tags: Array = supplier.get("tags", [])
	var candidates: Array[Dictionary] = []
	for book in BookCatalog.all_books():
		if not district_book_ids.has(str(book.get("id", ""))):
			continue
		var matches_supplier := supplier_tags.is_empty()
		for tag in book.get("tags", []):
			if supplier_tags.has(tag):
				matches_supplier = true
				break
		if matches_supplier:
			candidates.append(book)
	if candidates.size() < 2:
		for book in BookCatalog.all_books():
			var book_id := str(book.get("id", ""))
			var already_in_list := false
			for candidate in candidates:
				if str(candidate.get("id", "")) == book_id:
					already_in_list = true
					break
			if district_book_ids.has(book_id) and not already_in_list:
				candidates.append(book)
	candidates.shuffle()
	var offers: Dictionary = {}
	for book in candidates:
		var supplier_factor := float(supplier.get("price_factor", 1.0))
		var quantity := randi_range(1, 2) if str(supplier.get("id", "")) == "caravana" else randi_range(1, 3)
		var condition_stock: Dictionary = {}
		for _copy in range(quantity):
			var roll := randi_range(1, 100)
			var condition := "novo"
			match str(supplier.get("id", "")):
				"caravana":
					condition = "danificado" if roll <= 18 else ("usado" if roll <= 82 else "novo")
				"antiquario":
					condition = "raro" if roll <= 55 else ("usado" if roll <= 90 else "novo")
				_:
					if roll <= 10:
						condition = "raro"
					elif roll <= 22:
						condition = "danificado"
					elif roll <= 65:
						condition = "usado"
			var condition_entry: Dictionary = condition_stock.get(condition, {"quantity": 0})
			condition_entry["quantity"] = int(condition_entry.get("quantity", 0)) + 1
			condition_entry["price"] = maxi(1, roundi(float(BookCatalog.price_for_condition(book, condition, "buy_price")) * supplier_factor))
			condition_stock[condition] = condition_entry
		offers[str(book.get("id", ""))] = {
			"quantity": quantity,
			"conditions": condition_stock,
			"risk": float(supplier.get("risk", 0.0)),
			"supplier_id": str(supplier.get("id", ""))
		}
	return offers

func _open_inventory() -> void:
	var screen := InventoryScreen.new()
	$UI.add_child(screen)
	active_overlay = screen
	var customer_active := store_is_open and customer != null and customer.visible
	var request_clue: Dictionary = customer.get_request_clue() if customer_active else {}
	screen.setup(inventory, request_clue, customer_active)
	screen.deliver_requested.connect(func(book_id: String, condition: String) -> void: _handle_stock_action(book_id, condition, "deliver", screen))
	screen.negotiate_requested.connect(func(book_id: String, condition: String) -> void: _handle_stock_action(book_id, condition, "negotiate", screen))
	screen.offer_requested.connect(func(book_id: String, condition: String) -> void: _handle_stock_action(book_id, condition, "offer", screen))
	screen.closed.connect(func() -> void: active_overlay = null; screen.queue_free())

func _handle_stock_action(book_id: String, condition: String, action: String, screen: InventoryScreen) -> void:
	if not store_is_open or not customer.visible or inventory.get_condition_quantity(book_id, condition) <= 0:
		return
	var book := BookCatalog.get_book(book_id)
	book["condition"] = condition
	book["condition_label"] = BookCatalog.get_condition(condition).label
	book["sale_price"] = BookCatalog.price_for_condition(book, condition, "sale_price")
	book["buy_price"] = BookCatalog.price_for_condition(book, condition, "buy_price")
	var result: Dictionary
	match action:
		"deliver": result = customer.deliver(book)
		"negotiate": result = customer.negotiate(book)
		"offer": result = customer.react_to_offer(book)
	var reputation_delta: int = int(result.get("reputation", 0))
	if not bool(result.get("accepted", false)):
		progression.record_error()
	if reputation_delta != 0:
		reputation += reputation_delta
		progression.record_reputation(reputation)
	if bool(result.accepted):
		var acquisition_cost := inventory.get_unit_cost(book_id, condition)
		inventory.remove(book_id, 1, condition)
		var sale_amount := int(result.money)
		money += sale_amount
		day_customers_served += 1
		day_sales_count += 1
		day_sales_revenue += sale_amount
		day_profit += sale_amount - acquisition_cost
		progression.record_sale(sale_amount - acquisition_cost)
		_notify_new_achievements()
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
	_notify_new_achievements()
	dialogue_panel.show_message(customer.customer_name, result.text)
	active_overlay = null
	screen.queue_free()
	_update_status()


func _show_shop(summary: DaySummaryScreen = null) -> void:
	if active_overlay != null and active_overlay != summary: return
	if supplier_markets.is_empty(): _prepare_supplier_markets()
	merchant_offers = supplier_markets.get(selected_supplier_id, {})
	if summary != null:
		summary.visible = false
	var screen := MerchantScreen.new()
	$UI.add_child(screen)
	active_overlay = screen
	screen.setup(inventory, merchant_offers, money, summary != null or not store_is_open, SUPPLIERS, selected_supplier_id)
	screen.supplier_selected.connect(func(supplier_id: String) -> void:
		selected_supplier_id = supplier_id
		merchant_offers = supplier_markets.get(selected_supplier_id, {})
		screen.set_market(merchant_offers, selected_supplier_id, money)
	)
	screen.purchase_requested.connect(func(book_id: String, condition: String) -> void:
		var book := BookCatalog.get_book(book_id)
		var offer: Dictionary = merchant_offers.get(book_id, {})
		var condition_stock: Dictionary = offer.get("conditions", {})
		var condition_offer: Dictionary = condition_stock.get(condition, {})
		var purchase_price := int(condition_offer.get("price", BookCatalog.price_for_condition(book, condition, "buy_price")))
		if int(condition_offer.get("quantity", 0)) <= 0 or money < purchase_price: return
		money -= purchase_price
		condition_offer["quantity"] = int(condition_offer.get("quantity", 0)) - 1
		condition_stock[condition] = condition_offer
		offer["conditions"] = condition_stock
		offer["quantity"] = maxi(0, int(offer.get("quantity", 0)) - 1)
		merchant_offers[book_id] = offer
		supplier_markets[selected_supplier_id] = merchant_offers
		var actual_condition := condition
		if randf() < float(offer.get("risk", 0.0)):
			actual_condition = "danificado"
			_notify("LOTE AVARIADO", "O fornecedor entregou %s em condição danificada." % str(book.get("title", "Livro")), "warning")
		inventory.add(book_id, 1, actual_condition, purchase_price)
		progression.record_purchase(selected_supplier_id)
		_notify_new_achievements()
		_update_status()
		screen.refresh(money)
	)
	screen.closed.connect(func() -> void:
		active_overlay = summary
		if summary != null: summary.visible = true
		screen.queue_free()
	)
	screen.next_day_requested.connect(func() -> void:
		active_overlay = null
		screen.queue_free()
		if summary != null: summary.queue_free()
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
		progression.record_error()
		progression.record_reputation(reputation)
		_notify_new_achievements()
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
	var progress_report: Dictionary = progression.finish_day()
	var reward := int(progress_report.get("reward", 0))
	if reward > 0:
		money += reward
		_notify("RECOMPENSA DE OBJETIVOS", "+%d moedas" % reward, "success")
	for achievement in progress_report.get("achievements", []):
		_notify("CONQUISTA DESBLOQUEADA", "%s: %s" % [str(achievement.get("title", "Conquista")), str(achievement.get("description", ""))], "success")
	var summary := DaySummaryScreen.new()
	$UI.add_child(summary)
	active_overlay = summary
	var reputation_change := reputation - day_start_reputation
	summary.shop_requested.connect(func() -> void: _show_shop(summary))
	summary.district_requested.connect(func() -> void: _show_districts(summary))
	summary.setup(
		day_manager.day,
		day_customers_served,
		day_sales_count,
		day_sales_revenue,
		day_errors,
		reputation,
		reputation_change,
		day_profit,
		day_manager.customers_today,
		progress_report,
		str(_current_district().get("name", "Centro Antigo"))
	)
	summary.next_day_requested.connect(func() -> void:
		active_overlay = null
		summary.queue_free()
		_finish_day()
	)

func _show_districts(summary: DaySummaryScreen) -> void:
	if active_overlay != summary:
		return
	var picker := DistrictPickerUI.new() as DistrictScreen
	$UI.add_child(picker)
	active_overlay = picker
	summary.visible = false
	picker.setup(_district_options(), current_district_id)
	picker.district_selected.connect(func(district_id: String) -> void:
		current_district_id = district_id
		progression.record_district_visit(district_id)
		_notify_new_achievements()
		supplier_markets.clear()
		merchant_offers.clear()
		selected_supplier_id = "praca"
		active_overlay = summary
		summary.visible = true
		picker.queue_free()
		_update_status()
		_notify("BAIRRO SELECIONADO", str(_current_district().get("name", "")) + " será sua próxima região de atendimento.", "info")
	)
	picker.closed.connect(func() -> void:
		active_overlay = summary
		summary.visible = true
		picker.queue_free()
	)

func _finish_day() -> void:
	customer_ids_seen_today.clear()
	supplier_markets.clear()
	merchant_offers.clear()
	day_manager.finish_day(_current_customer_limit())
	store_is_open = true
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
