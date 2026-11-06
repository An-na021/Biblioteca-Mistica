extends Node2D

const MoodTimerUI = preload("res://scripts/mood_timer.gd")
const Progression = preload("res://scripts/progression_manager.gd")
const DistrictPickerUI = preload("res://scripts/district_screen.gd")
const GameMenuUI = preload("res://scripts/game_menu.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const World = preload("res://scripts/shop_world.gd")
const NegotiationUI = preload("res://scripts/negotiation_screen.gd")
const LivrariaUI = preload("res://scripts/livraria_screen.gd")
const ShopDecorUI = preload("res://scripts/shop_decor.gd")
const AtmosphereUI = preload("res://scripts/shop_atmosphere.gd")
const CustomerTransitions = preload("res://scripts/customer_transitions.gd")
const SaleFeedbackUI = preload("res://scripts/sale_feedback.gd")
const CatalogAPI = preload("res://scripts/catalog_api.gd")
const ClockScreen = preload("res://scenes/clock_screen.tscn")
const ClockScreenUI = preload("res://scripts/clock_screen.gd")
const NewspaperScreenScene = preload("res://scenes/newspaper_screen.tscn")
const WindowScreenScene = preload("res://scenes/window_screen.tscn")
const WindowScreenUI = preload("res://scripts/window_screen.gd")

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
var world = World.new()
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
var day_failed_customers := 0
var day_profit := 0
var day_start_reputation := 0
var customer_ids_seen_today: Array[String] = []
var customer_time_limit := 0.0
var customer_time_left := 0.0
var mood_timer: Control
var game_menu: CanvasLayer
var relaxed_mode := false
var summary_report: Dictionary = {}
var checkpoint: Dictionary = {}
var save_path := SaveGame.SAVE_PATH
var shop_decor: Node2D
var atmosphere: Node2D
var ambient_service_seconds := 0.0
var customer_transitions: Node2D
var sale_feedback: Control
var customer_profiles: Array[Dictionary] = CUSTOMER_PROFILES.duplicate(true)
var supplier_profiles: Array[Dictionary] = SUPPLIERS.duplicate(true)
var catalog_snapshot: Dictionary = {}
var api_url := OS.get_environment("BIBLIOTECA_API_URL") if OS.has_environment("BIBLIOTECA_API_URL") else "http://127.0.0.1:8000"

func _ready() -> void:
	randomize()
	BookCatalog.reset_catalog()
	notifications = NotificationPanel.new()
	$UI.add_child(notifications)
	for interactable in get_tree().get_nodes_in_group("interactables"): _connect_interactable(interactable)
	for interactable in [$Door, $Window, $RightWindow, $Lamp, $Clipboard, $Clock, $NewspaperHotspot]: _connect_interactable(interactable)
	mood_timer = MoodTimerUI.new() as Control
	$UI.add_child(mood_timer)
	mood_timer.hide()
	day_manager.customer_ready.connect(_on_customer_ready)
	day_manager.store_closed.connect(_on_store_closed)
	_validate_customer_data()
	shop_decor = ShopDecorUI.new()
	shop_decor.z_index = 1
	add_child(shop_decor)
	# Put the original shelf/table before the counter; plants stay above it.
	shop_decor.shelf.reparent(self)
	move_child(shop_decor.shelf, $CounterForeground.get_index())
	_connect_interactable(shop_decor.shelf.get_node("ShelfHotspot"))
	_connect_interactable(shop_decor.plant_hotspot)
	atmosphere = AtmosphereUI.new()
	atmosphere.name = "ShopAtmosphere"
	add_child(atmosphere)
	customer_transitions = CustomerTransitions.new()
	customer_transitions.name = "CustomerTransitions"
	add_child(customer_transitions)
	move_child(customer_transitions, customer_spawn.get_index() + 1)
	sale_feedback = SaleFeedbackUI.new()
	$UI.add_child(sale_feedback)
	sale_feedback.setup(self, $UI/StatusPanel.money_value)
	store_is_open = false
	game_menu = GameMenuUI.new()
	add_child(game_menu)
	game_menu.new_game_requested.connect(_start_new_game)
	game_menu.continue_requested.connect(_continue_game)
	game_menu.relaxed_changed.connect(_set_relaxed_mode)
	checkpoint = SaveGame.read_save(save_path)
	relaxed_mode = bool(checkpoint.get("relaxed_mode", false))
	game_menu.relaxed.set_pressed_no_signal(relaxed_mode)
	game_menu.show_start(not checkpoint.is_empty())
	_update_status()
	if not api_url.is_empty():
		_load_api_catalog()

func _process(delta: float) -> void:
	# Inspection screens suspend service, arrivals and the end-of-day notice.
	if active_overlay is ClockScreenUI or active_overlay is NewspaperScreen or active_overlay is WindowScreenUI:
		atmosphere.animations_active = false
		return
	_update_atmosphere(delta)
	day_manager.tick(delta)
	var customer_active := store_is_open and customer != null and is_instance_valid(customer) and customer.visible
	if mood_timer != null:
		mood_timer.visible = customer_active and not relaxed_mode and active_overlay == null
	if active_overlay is InventoryScreen or active_overlay is NegotiationUI:
		active_overlay.set_time_left(customer_time_left, relaxed_mode)
	if not customer_active or relaxed_mode or active_overlay is CustomerProfilePanel:
		return
	customer_time_left = maxf(0.0, customer_time_left - delta)
	mood_timer.call("set_time_left", customer_time_left)
	if customer_time_left <= 0.0:
		_customer_service_timed_out()


func _update_atmosphere(delta: float) -> void:
	atmosphere.animations_active = game_menu.in_game and active_overlay == null
	atmosphere.lighting_installed = world.upgrades.has("lighting")
	if not game_menu.in_game:
		return
	if not store_is_open:
		atmosphere.set_day_progress(1.0)
		return
	if active_overlay == null and customer != null and customer.visible:
		ambient_service_seconds += delta
	var within_service := minf(0.80, ambient_service_seconds / maxf(45.0, customer_time_limit))
	if customer == null or not customer.visible:
		within_service = 0.0
	var progress := (float(day_manager.served_today) + within_service) / maxf(1.0, day_manager.customers_today)
	atmosphere.set_day_progress(progress)

func _customer_service_timed_out() -> void:
	if customer == null or not customer.visible or not store_is_open:
		return
	_depart_customer()
	day_errors += 1
	day_failed_customers += 1
	reputation -= 1
	progression.record_error()
	world.record_departure(str(customer.profile_data.id))
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
	shop_decor.plant_hotspot.set_selected(interactable == shop_decor.plant_hotspot)
	match interactable.interaction_type:
		"customer":
			if not store_is_open or not customer.visible: return
			dialogue_panel.show_message(customer.customer_name, customer.get_greeting())
			_show_customer_profile()
		"clipboard": _open_inventory()
		"door": _request_store_closure()
		"clock": _open_clock()
		"newspaper": _open_newspaper()
		"window":
			_open_window(preload("res://IMG/janela_direita.jpg") if interactable == $RightWindow else null)
		"lamp": dialogue_panel.show_message(interactable.interaction_name, interactable.description)
		_: dialogue_panel.show_message(interactable.interaction_name, interactable.description)


func _open_clock() -> void:
	if active_overlay != null or not game_menu.in_game or get_tree().paused:
		return
	var screen := ClockScreen.instantiate()
	active_overlay = screen
	$UI.hide()
	game_menu.hide()
	add_child(screen)
	screen.closed.connect(func() -> void:
		active_overlay = null
		$UI.show()
		game_menu.show()
	)

func _open_newspaper() -> void:
	if active_overlay != null or not game_menu.in_game or get_tree().paused:
		return
	var screen := NewspaperScreenScene.instantiate() as NewspaperScreen
	screen.configure(day_manager.day, World.event_for_day(day_manager.day))
	active_overlay = screen
	$UI.hide()
	game_menu.hide()
	add_child(screen)
	screen.closed.connect(func() -> void:
		active_overlay = null
		$UI.show()
		game_menu.show()
	)

func _open_window(image: Texture2D = null) -> void:
	if active_overlay != null or not game_menu.in_game or get_tree().paused:
		return
	var screen := WindowScreenScene.instantiate()
	if image != null:
		screen.image = image
	active_overlay = screen
	$UI.hide()
	game_menu.hide()
	add_child(screen)
	screen.closed.connect(func() -> void:
		active_overlay = null
		$UI.show()
		game_menu.show()
	)

func _show_customer_profile() -> void:
	if active_overlay != null or customer == null or not customer.visible:
		return
	customer_transitions.finish_arrival()
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
	ambient_service_seconds = 0.0
	if index == 1:
		progression.begin_day(day_manager.day, total)
	var available_profiles: Array[Dictionary] = []
	var district := _current_district()
	var district_customer_ids: Array = district.get("customer_ids", [])
	for candidate in customer_profiles:
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
		customer_transitions.finish_arrival()
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
	var event_books: Array[Dictionary] = []
	var event := World.event_for_day(day_manager.day)
	for book in matching_books:
		var copy := book.duplicate()
		copy["condition"] = str(profile.get("preferred_condition", "novo"))
		if World.event_matches(event, copy):
			event_books.append(book)
	if not event_books.is_empty() and randf() < 0.75:
		matching_books = event_books
	var customer_id := str(profile.id)
	var history: Dictionary = world.memory(customer_id)
	customer.configure(profile, matching_books.pick_random(), reputation, {
		"memory": history, "story": world.story_text(customer_id),
		"patience_bonus": world.patience_bonus(), "recommendation_bonus": world.recommendation_bonus(),
		"negotiation_bonus": world.negotiation_bonus()
	})
	world.record_visit(customer_id, day_manager.day)
	var mood_type := str(profile.get("mood_type", "indeciso"))
	customer_time_limit = customer.patience_seconds()
	customer_time_left = customer_time_limit
	mood_timer.call("setup", mood_type, customer_time_limit)
	_connect_interactable(customer)
	customer.visible = true
	customer_transitions.arrive(customer)
	dialogue_panel.show_message("Porta", "%s entra na loja." % customer.customer_name)
	_update_status()

func _current_district() -> Dictionary:
	for district in DISTRICTS:
		if str(district.get("id", "")) == current_district_id:
			var result := district.duplicate(true)
			if not catalog_snapshot.is_empty():
				result["book_ids"] = []
				result["customer_ids"] = []
				for book in BookCatalog.all_books():
					if book.get("district_ids", []).has(current_district_id):
						result.book_ids.append(str(book.id))
				for profile in customer_profiles:
					if profile.get("district_ids", []).has(current_district_id):
						result.customer_ids.append(str(profile.id))
			return result
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
	for profile in customer_profiles:
		var profile_id := str(profile.get("id", ""))
		if profile_id.is_empty() or seen_ids.has(profile_id):
			push_error("Perfil de cliente sem identificador unico: %s" % str(profile.get("name", "?")))
			continue
		seen_ids[profile_id] = true
		if Customer.REQUESTS.has(profile_id) and str(Customer.REQUESTS[profile_id]).count("%s") != 1:
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
		_depart_customer()
	dialogue_panel.show_message("Livraria", "Esta ficando tarde acho que nenhum cliente mais ira vir.")
	if active_overlay != null:
		active_overlay.queue_free()
		active_overlay = null
	_present_day_summary()

func _prepare_supplier_markets() -> void:
	supplier_markets.clear()
	for supplier in supplier_profiles:
		supplier_markets[str(supplier.get("id", ""))] = _make_merchant_offers(supplier)
	if not supplier_markets.has(selected_supplier_id):
		selected_supplier_id = str(supplier_profiles[0].id)
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
	# Keep a source for reservations even when an API catalog replaces the suppliers.
	if _supplier_handles_orders(supplier):
		var needed: Dictionary = {}
		for order in world.pending_orders():
			var order_id := str(order.book_id)
			var order_condition := str(order.condition)
			var key := order_id + ":" + order_condition
			needed[key] = int(needed.get(key, 0)) + 1
			var entry: Dictionary = offers.get(order_id, {"quantity": 0, "conditions": {}, "risk": float(supplier.risk), "supplier_id": str(supplier.id)})
			var conditions: Dictionary = entry.conditions
			var condition_entry: Dictionary = conditions.get(order_condition, {"quantity": 0})
			var missing := maxi(0, int(needed[key]) - inventory.get_condition_quantity(order_id, order_condition))
			var quantity := maxi(int(condition_entry.quantity), missing)
			entry["quantity"] = int(entry.quantity) + quantity - int(condition_entry.quantity)
			condition_entry["quantity"] = quantity
			condition_entry["price"] = maxi(1, roundi(float(BookCatalog.price_for_condition(BookCatalog.get_book(order_id), order_condition, "buy_price")) * float(supplier.get("price_factor", 1.0))))
			conditions[order_condition] = condition_entry
			offers[order_id] = entry
	return offers

func _supplier_handles_orders(supplier: Dictionary) -> bool:
	for candidate in supplier_profiles:
		if bool(candidate.get("special_orders", str(candidate.get("id", "")) == "praca")):
			return bool(supplier.get("special_orders", str(supplier.get("id", "")) == "praca"))
	return not supplier_profiles.is_empty() and str(supplier.id) == str(supplier_profiles[0].id)

func _shop_reservations() -> Array[Dictionary]:
	var reservations := world.pending_orders()
	for order in reservations:
		order["customer_name"] = str(order.customer_id)
		for profile in customer_profiles:
			if str(profile.id) == str(order.customer_id):
				order["customer_name"] = str(profile.name)
				break
	return reservations

func _open_inventory() -> void:
	customer_transitions.finish_arrival()
	var screen := InventoryScreen.new()
	$UI.add_child(screen)
	active_overlay = screen
	var customer_active := store_is_open and customer != null and customer.visible
	var request_clue: Dictionary = customer.get_request_clue() if customer_active else {}
	var preference := str(customer.get_profile().get("preferred_condition", "novo")) if customer_active else ""
	screen.setup(inventory, request_clue, customer_active, preference, customer if customer_active else null)
	screen.set_time_left(customer_time_left, relaxed_mode)
	game_menu.pause_button.hide()
	screen.pause_requested.connect(game_menu.toggle_pause)
	screen.tree_exiting.connect(func() -> void:
		if is_instance_valid(game_menu):
			game_menu.pause_button.visible = game_menu.pause_enabled and not (is_instance_valid(active_overlay) and active_overlay is InventoryScreen and active_overlay != screen)
	)
	screen.deliver_requested.connect(func(book_id: String, condition: String) -> void: _handle_stock_action(book_id, condition, "deliver", screen))
	screen.negotiate_requested.connect(func(book_id: String, condition: String) -> void: _open_negotiation(book_id, condition, screen))
	screen.offer_requested.connect(func(book_id: String, condition: String) -> void: _handle_stock_action(book_id, condition, "offer", screen))
	screen.reservation_requested.connect(func() -> void: _reserve_customer_book(screen))
	screen.closed.connect(func() -> void: active_overlay = null; screen.queue_free())

func _reserve_customer_book(screen: InventoryScreen) -> void:
	if active_overlay != screen or not store_is_open or customer == null or not customer.visible or not customer.can_reserve(inventory):
		return
	var book_id := customer.requested_book_id
	var condition := str(customer.profile_data.get("preferred_condition", "novo"))
	if not world.reserve_book(str(customer.profile_data.id), book_id, condition):
		return
	var title := str(BookCatalog.get_book(book_id).get("title", "Livro"))
	_notify("RESERVA REGISTRADA", "%s · %s (%s). O livro está marcado na loja para comprar no fechamento." % [customer.customer_name, title, str(BookCatalog.get_condition(condition).label)], "success")
	dialogue_panel.show_message(customer.customer_name, "Pode reservar %s para mim? Volto em outra visita para buscar. Obrigado!" % title)
	customer.served = true
	_depart_customer()
	day_customers_served += 1
	active_overlay = null
	screen.queue_free()
	day_manager.customer_completed()
	_update_status()

func _handle_stock_action(book_id: String, condition: String, action: String, screen: InventoryScreen) -> void:
	if active_overlay != screen or not store_is_open or not customer.visible or inventory.get_condition_quantity(book_id, condition) <= 0:
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
	_complete_stock_action(book, result, screen)

func _complete_stock_action(book: Dictionary, result: Dictionary, screen: Control) -> void:
	var book_id := str(book.id)
	var condition := str(book.condition)
	var reputation_delta: int = int(result.get("reputation", 0))
	if not bool(result.get("accepted", false)) and bool(result.get("counts_as_error", true)):
		progression.record_error()
		day_errors += 1
	if reputation_delta != 0:
		reputation += reputation_delta
		progression.record_reputation(reputation)
	if bool(result.accepted):
		var acquisition_cost := inventory.get_unit_cost(book_id, condition)
		inventory.remove(book_id, 1, condition)
		var sale_amount := int(result.money)
		var event_bonus := World.event_bonus(day_manager.day, book)
		sale_amount += event_bonus
		money += sale_amount
		day_customers_served += 1
		day_sales_count += 1
		day_sales_revenue += sale_amount
		day_profit += sale_amount - acquisition_cost
		progression.record_sale(sale_amount - acquisition_cost)
		var chapter: Dictionary = world.record_purchase(str(customer.profile_data.id), book_id, condition)
		money += int(chapter.reward)
		if int(chapter.story_reward) > 0:
			_notify("HISTÓRIA CONCLUÍDA · +%d MOEDAS" % int(chapter.story_reward), str(chapter.text), "success")
		elif int(world.memory(str(customer.profile_data.id)).get("purchases", 0)) <= 3:
			_notify("CADERNO DE LEITORES · %d/3" % int(chapter.chapter), str(chapter.text), "info")
		if int(chapter.order_reward) > 0:
			_notify("ENCOMENDA ENTREGUE", "+4 moedas de agradecimento. O leitor recebeu o exemplar que reservou.", "success")
		if int(world.memory(str(customer.profile_data.id)).get("purchases", 0)) == 1:
			_create_customer_order(book_id)
		if event_bonus > 0:
			_notify("BÔNUS DO EVENTO", "+%d moedas · %s" % [event_bonus, str(World.event_for_day(day_manager.day).name)], "success")
		_notify_new_achievements()
		_notify("VENDA CONCLUIDA", "%s por %d moedas." % [str(book.get("title", "Livro")), sale_amount], "success")
		if inventory.get_quantity(book_id) == 0:
			_notify("ESTOQUE ESGOTADO", "%s acabou do estoque." % str(book.get("title", "Livro")), "warning")
		sale_feedback.play_sale(book, sale_amount + int(chapter.reward), customer.global_position + Vector2(60, 64))
		_depart_customer(0.72)
		day_manager.customer_completed()
	elif bool(result.get("completed", false)):
		world.record_departure(str(customer.profile_data.id))
		day_failed_customers += 1
		_notify("CLIENTE FOI EMBORA", "O cliente encerrou o atendimento sem comprar.", "warning")
		_depart_customer()
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


func _depart_customer(hold_seconds := 0.0) -> void:
	if customer == null or not is_instance_valid(customer):
		return
	customer.set_selected(false)
	customer_transitions.depart(customer, hold_seconds)
	customer.hide()

func _combined_merchant_offers() -> Dictionary:
	var combined: Dictionary = {}
	for supplier_id in supplier_markets:
		var market: Dictionary = supplier_markets[supplier_id]
		for book_id in market:
			var offer: Dictionary = market[book_id]
			var entry: Dictionary = combined.get(book_id, {"quantity": 0, "conditions": {}})
			var conditions: Dictionary = offer.get("conditions", {})
			for condition in conditions:
				var available: Dictionary = conditions[condition]
				var quantity := int(available.get("quantity", 0))
				if quantity <= 0:
					continue
				entry.quantity += quantity
				var best: Dictionary = entry.conditions.get(condition, {})
				var total := quantity + int(best.get("quantity", 0))
				var price := int(available.get("price", 0))
				var risk := float(offer.get("risk", 0.0))
				if best.is_empty() or price < int(best.price) or (price == int(best.price) and risk < float(best.risk)):
					best = {"price": price, "supplier_id": str(supplier_id), "risk": risk}
				best["quantity"] = total
				entry.conditions[condition] = best
			combined[book_id] = entry
	return combined

func _show_shop(summary: DaySummaryScreen = null) -> void:
	if active_overlay != null and active_overlay != summary: return
	var restore_pause: bool = game_menu.pause_enabled
	game_menu.set_pause_enabled(false)
	if supplier_markets.is_empty(): _prepare_supplier_markets()
	if not store_is_open:
		_save_checkpoint()
	merchant_offers = _combined_merchant_offers()
	if summary != null:
		summary.visible = false
	var screen := MerchantScreen.new()
	$UI.add_child(screen)
	active_overlay = screen
	screen.setup(inventory, merchant_offers, money, summary != null or not store_is_open, _shop_reservations())
	screen.purchase_requested.connect(func(book_id: String, condition: String) -> void:
		if active_overlay != screen: return
		merchant_offers = _combined_merchant_offers()
		var best: Dictionary = merchant_offers.get(book_id, {}).get("conditions", {}).get(condition, {})
		if best.is_empty(): return
		var supplier_id := str(best.supplier_id)
		var market: Dictionary = supplier_markets.get(supplier_id, {})
		var book := BookCatalog.get_book(book_id)
		var offer: Dictionary = market.get(book_id, {})
		var condition_stock: Dictionary = offer.get("conditions", {})
		var condition_offer: Dictionary = condition_stock.get(condition, {})
		var purchase_price := int(condition_offer.get("price", BookCatalog.price_for_condition(book, condition, "buy_price")))
		if int(condition_offer.get("quantity", 0)) <= 0 or money < purchase_price: return
		money -= purchase_price
		condition_offer["quantity"] = int(condition_offer.get("quantity", 0)) - 1
		condition_stock[condition] = condition_offer
		offer["conditions"] = condition_stock
		offer["quantity"] = maxi(0, int(offer.get("quantity", 0)) - 1)
		market[book_id] = offer
		supplier_markets[supplier_id] = market
		selected_supplier_id = supplier_id
		var actual_condition := condition
		if randf() < float(offer.get("risk", 0.0)):
			actual_condition = "danificado"
			_notify("LOTE AVARIADO", "O fornecedor entregou %s em condição danificada." % str(book.get("title", "Livro")), "warning")
		inventory.add(book_id, 1, actual_condition, purchase_price)
		progression.record_purchase(supplier_id)
		_notify_new_achievements()
		_update_status()
		merchant_offers = _combined_merchant_offers()
		screen.offers = merchant_offers
		screen.refresh(money)
		_save_checkpoint()
	)
	screen.closed.connect(func() -> void:
		active_overlay = summary
		if summary != null: summary.visible = true
		game_menu.set_pause_enabled(restore_pause)
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
	_show_close_confirmation(customer_inside)

func _show_close_confirmation(customer_inside: bool) -> void:
	var image_path := "res://IMG/close_store_customer.png" if customer_inside else "res://IMG/close_store_empty.png"
	var image := load(image_path) as Texture2D
	if image == null:
		push_error("Nao foi possivel carregar a imagem de fechamento: %s" % image_path)
		return

	var overlay := Control.new()
	overlay.name = "CloseStoreConfirmation"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$UI.add_child(overlay)
	active_overlay = overlay

	var viewport_size := get_viewport_rect().size
	var scale_factor := minf(0.55, minf((viewport_size.x * 0.55) / image.get_width(), (viewport_size.y * 0.55) / image.get_height()))
	var image_view := TextureRect.new()
	image_view.texture = image
	image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_view.stretch_mode = TextureRect.STRETCH_SCALE
	image_view.size = image.get_size() * scale_factor
	image_view.position = (viewport_size - image_view.size) / 2.0
	image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(image_view)

	var close_button_rect: Rect2
	var keep_open_button_rect: Rect2
	var close_store_button_rect: Rect2
	close_button_rect = Rect2(910, 195, 210, 190)
	close_store_button_rect = Rect2(190, 1045, 440, 310)
	keep_open_button_rect = Rect2(685, 1045, 440, 310)

	var cancel_button := _add_close_store_hitbox(image_view, close_button_rect, scale_factor)
	cancel_button.pressed.connect(func() -> void:
		active_overlay = null
		overlay.queue_free()
	)
	var close_store_button := _add_close_store_hitbox(image_view, close_store_button_rect, scale_factor)
	close_store_button.pressed.connect(func() -> void:
		active_overlay = null
		overlay.queue_free()
		_close_store(customer_inside)
	)
	var keep_open_button := _add_close_store_hitbox(image_view, keep_open_button_rect, scale_factor)
	keep_open_button.pressed.connect(func() -> void:
		active_overlay = null
		overlay.queue_free()
	)


func _add_close_store_hitbox(parent: Control, hitbox: Rect2, scale_factor: float) -> Button:
	var button := Button.new()
	button.position = hitbox.position * scale_factor
	button.size = hitbox.size * scale_factor
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _close_store_button_glow(0.22, 0.9))
	button.add_theme_stylebox_override("pressed", _close_store_button_glow(0.34, 1.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(button)
	return button


func _close_store_button_glow(opacity: float, glow_opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, opacity)
	style.border_color = Color(1, 1, 1, 0.9)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(1, 1, 1, glow_opacity)
	style.shadow_size = 12
	style.shadow_offset = Vector2.ZERO
	return style


func _close_store(customer_inside: bool) -> void:
	store_is_open = false
	day_manager.close_store()
	if customer_inside:
		world.record_departure(str(customer.profile_data.id))
		reputation -= 1
		day_errors += 1
		day_failed_customers += 1
		progression.record_error()
		progression.record_reputation(reputation)
		_notify_new_achievements()
		_notify("CLIENTE INSATISFEITO", "O cliente saiu antes de ser atendido.", "danger")
		_notify("REPUTACAO ALTERADA", "-1 (total: %d)." % reputation, "reputation")
		_depart_customer()
		dialogue_panel.show_message("Livraria", "A loja foi fechada e o cliente foi convidado a se retirar. Reputacao -1.")
	else:
		dialogue_panel.show_message("Livraria", "A loja foi fechada. Nenhum cliente estava dentro.")
	_update_status()
	_present_day_summary()

func _present_day_summary(restored := false) -> void:
	atmosphere.set_day_progress(1.0, true)
	if active_overlay != null:
		return
	game_menu.set_pause_enabled(false)
	if not restored:
		summary_report = progression.finish_day()
	var progress_report := summary_report
	var reward := 0 if restored else int(progress_report.get("reward", 0))
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
	summary.livraria_requested.connect(func() -> void: _show_livraria(summary))
	summary.setup(
		day_manager.day,
		day_customers_served,
		day_sales_count,
		day_sales_revenue,
		day_failed_customers,
		reputation,
		reputation_change,
		day_profit,
		day_manager.customers_today,
		progress_report,
		str(_current_district().get("name", "Centro Antigo")),
		day_errors,
		"Amanhã: " + str(World.event_for_day(day_manager.day + 1).name)
	)
	summary.next_day_requested.connect(func() -> void:
		active_overlay = null
		summary.queue_free()
		_finish_day()
	)
	if not restored:
		_save_checkpoint()

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
		summary.set_district_name(str(_current_district().get("name", "Centro Antigo")))
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
		_save_checkpoint()
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
	day_manager.day += 1
	_begin_day()

func _reset_day_summary_stats() -> void:
	day_customers_served = 0
	day_sales_count = 0
	day_sales_revenue = 0
	day_errors = 0
	day_failed_customers = 0
	day_profit = 0
	day_start_reputation = reputation

func _update_status() -> void:
	status_label.text = "Dia %d | Moedas: %d | Reputacao: %d" % [day_manager.day, money, reputation]
	$UI/StatusPanel.set_values(day_manager.day, money, reputation)

func _start_new_game() -> void:
	inventory = Inventory.new()
	progression = Progression.new()
	world = World.new()
	money = 0
	reputation = 0
	day_manager.day = 1
	current_district_id = "centro"
	selected_supplier_id = "praca"
	progression.record_district_visit(current_district_id)
	game_menu.enter_game()
	_begin_day()

func _begin_day() -> void:
	customer_transitions.reset()
	sale_feedback.reset_day()
	ambient_service_seconds = 0.0
	atmosphere.reset_day()
	game_menu.set_pause_enabled(true)
	customer_ids_seen_today.clear()
	supplier_markets.clear()
	merchant_offers.clear()
	summary_report.clear()
	store_is_open = true
	_reset_day_summary_stats()
	progression.begin_day(day_manager.day, _current_customer_limit())
	_update_world_visuals()
	# Snapshot before spawning: Continue restarts this day with its opening stock.
	_save_checkpoint()
	day_manager.start_day(_current_customer_limit())
	_update_status()

func _continue_game() -> void:
	var data := SaveGame.read_save(save_path)
	if data.is_empty():
		game_menu.note.text = "Não foi possível ler o progresso. Você pode iniciar um novo jogo."
		return
	if data.get("catalog", {}).is_empty():
		# Legacy games used the built-in catalog; preserve their books and orders.
		BookCatalog.reset_catalog()
		customer_profiles = CUSTOMER_PROFILES.duplicate(true)
		supplier_profiles = SUPPLIERS.duplicate(true)
		catalog_snapshot.clear()
	elif not _apply_catalog(data.catalog):
		game_menu.note.text = "O catálogo desta partida está inválido. Não foi possível continuar."
		return
	inventory.condition_quantities = data.inventory.duplicate(true)
	inventory.acquisition_costs = data.get("acquisition_costs", {}).duplicate(true)
	world.restore(data.get("world", {}))
	for field in SaveGame.PROGRESSION_FIELDS:
		if data.progression.has(field):
			progression.set(field, data.progression[field])
	day_manager.day = int(data.day)
	money = int(data.money)
	reputation = int(data.get("reputation", 0))
	current_district_id = str(data.get("district", "centro"))
	selected_supplier_id = str(data.get("supplier", "praca"))
	relaxed_mode = game_menu.relaxed.button_pressed
	_update_world_visuals()
	game_menu.enter_game()
	if bool(data.get("closed", false)):
		store_is_open = false
		day_manager.close_store()
		day_manager.customers_today = int(data.get("customers_total", 0))
		summary_report = data.get("summary", {}).duplicate(true)
		supplier_markets = data.get("markets", {}).duplicate(true)
		var stats: Dictionary = data.get("stats", {})
		day_customers_served = int(stats.get("served", 0))
		day_sales_count = int(stats.get("sales", 0))
		day_sales_revenue = int(stats.get("revenue", 0))
		day_errors = int(stats.get("errors", 0))
		day_failed_customers = int(stats.get("failed", 0))
		day_profit = int(stats.get("profit", 0))
		day_start_reputation = int(stats.get("start_reputation", reputation))
		_present_day_summary(true)
	else:
		_begin_day()
	_update_status()

func _save_checkpoint() -> void:
	var progress: Dictionary = {}
	for field in SaveGame.PROGRESSION_FIELDS:
		progress[field] = progression.get(field)
	checkpoint = {
		"version": 1, "day": day_manager.day, "money": money, "reputation": reputation,
		"world": world.serialize(),
		"catalog": catalog_snapshot.duplicate(true),
		"district": current_district_id, "supplier": selected_supplier_id,
		"inventory": inventory.condition_quantities.duplicate(true),
		"acquisition_costs": inventory.acquisition_costs.duplicate(true),
		"progression": progress, "relaxed_mode": relaxed_mode,
		"closed": not store_is_open, "summary": summary_report.duplicate(true),
		"markets": supplier_markets.duplicate(true), "customers_total": day_manager.customers_today,
		"stats": {"served": day_customers_served, "sales": day_sales_count,
			"revenue": day_sales_revenue, "errors": day_errors, "failed": day_failed_customers,
			"profit": day_profit, "start_reputation": day_start_reputation}
	}
	_write_checkpoint()

func _write_checkpoint() -> void:
	if SaveGame.write_save(checkpoint, save_path) != OK:
		_notify("PROGRESSO NÃO SALVO", "Não foi possível gravar o progresso. Verifique o espaço disponível.", "warning")

func _set_relaxed_mode(enabled: bool) -> void:
	relaxed_mode = enabled
	if game_menu != null:
		game_menu.set_relaxed(enabled)
	if not checkpoint.is_empty():
		# Settings must not replace the opening-day snapshot with mid-service state.
		checkpoint["relaxed_mode"] = enabled
		_write_checkpoint()

func _stock_book(book_id: String, condition: String) -> Dictionary:
	var book := BookCatalog.get_book(book_id)
	book["condition"] = condition
	book["sale_price"] = BookCatalog.price_for_condition(book, condition, "sale_price")
	book["buy_price"] = BookCatalog.price_for_condition(book, condition, "buy_price")
	return book

func _open_negotiation(book_id: String, condition: String, inventory_screen: InventoryScreen) -> void:
	if active_overlay != inventory_screen or customer == null or not customer.visible:
		return
	if inventory.get_condition_quantity(book_id, condition) <= 0:
		return
	var screen := NegotiationUI.new()
	$UI.add_child(screen)
	active_overlay = screen
	inventory_screen.queue_free()
	var book := _stock_book(book_id, condition)
	screen.setup(book, customer, inventory.get_unit_cost(book_id, condition))
	screen.set_time_left(customer_time_left, relaxed_mode)
	screen.proposed.connect(func(price: int) -> void:
		if active_overlay != screen or not store_is_open or not customer.visible or customer.served:
			return
		if price < 1 or inventory.get_condition_quantity(book_id, condition) <= 0:
			return
		var result: Dictionary = customer.negotiate(book, price)
		if result.has("counter_price"):
			screen.show_counter(result)
			return
		_complete_stock_action(book, result, screen)
	)
	screen.closed.connect(func() -> void:
		if active_overlay != screen:
			return
		active_overlay = null
		screen.queue_free()
		_open_inventory()
	)

func _show_livraria(summary: DaySummaryScreen) -> void:
	if active_overlay != summary or store_is_open:
		return
	var screen := LivrariaUI.new()
	$UI.add_child(screen)
	active_overlay = screen
	summary.hide()
	screen.setup(world, money, day_manager.day + 1, customer_profiles)
	screen.purchase_requested.connect(func(upgrade_id: String) -> void:
		if active_overlay != screen or store_is_open:
			return
		var cost: int = world.purchase(upgrade_id, money)
		if cost < 0:
			return
		money -= cost
		_update_world_visuals()
		_update_status()
		screen.refresh(world, money)
		_save_checkpoint()
		_notify("LIVRARIA RENOVADA", str(World.UPGRADES[upgrade_id].name) + " já faz parte da loja.", "success")
	)
	screen.closed.connect(func() -> void:
		active_overlay = summary
		summary.show()
		screen.queue_free()
	)

func _update_world_visuals() -> void:
	shop_decor.update_state(world.upgrades)
	atmosphere.lighting_installed = world.upgrades.has("lighting")

func _create_customer_order(last_book_id: String) -> void:
	var candidates: Array[Dictionary] = []
	var district: Dictionary = _current_district()
	for book in BookCatalog.books_for_preferences(customer.profile_data.get("preference_tags", [])):
		if district.book_ids.has(str(book.id)) and str(book.id) != last_book_id:
			candidates.append(book)
	var book_id := last_book_id if candidates.is_empty() else str(candidates.pick_random().id)
	var condition := str(customer.profile_data.get("preferred_condition", "novo"))
	if not world.create_order(str(customer.profile_data.id), book_id, condition):
		return
	_notify("ENCOMENDA PARA A PRÓXIMA VISITA", "%s reservou %s (%s). Consulte o Caderno de leitores no fechamento." % [customer.customer_name, str(BookCatalog.get_book(book_id).title), str(BookCatalog.get_condition(condition).label)], "info")

func _load_api_catalog() -> void:
	game_menu.new_button.disabled = true
	game_menu.continue_button.disabled = true
	var original_note: String = game_menu.note.text
	game_menu.note.text = "Atualizando o catálogo da livraria..."
	var client := CatalogAPI.new()
	client.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(client)
	var data: Dictionary = await client.fetch_catalog(api_url)
	client.queue_free()
	# A test or an external action may have started a game while this request ran.
	if game_menu.in_game:
		return
	var connected := _apply_catalog(data)
	game_menu.new_button.disabled = false
	game_menu.continue_button.disabled = checkpoint.is_empty()
	game_menu.note.text = original_note + ("\nCatálogo atualizado." if connected else "\nUsando o catálogo local.")

func _apply_catalog(data: Dictionary) -> bool:
	for key in ["books", "customers", "suppliers"]:
		if not data.get(key) is Array or data[key].is_empty():
			return false
	var valid_scenes: Array[String] = []
	for profile in CUSTOMER_PROFILES:
		valid_scenes.append(str(profile.scene_path))
	for profile in data.customers:
		if not profile is Dictionary or not profile.has_all(["id", "name", "scene_path", "mood_type", "preference_tags", "preferred_condition", "district_ids"]):
			return false
		if not valid_scenes.has(str(profile.scene_path)) or not World.TRAITS.has(str(profile.mood_type)) or not BookCatalog.CONDITIONS.has(str(profile.preferred_condition)):
			return false
		if not profile.preference_tags is Array or not profile.district_ids is Array:
			return false
	for supplier in data.suppliers:
		if not supplier is Dictionary or not supplier.has_all(["id", "name", "price_factor", "risk", "tags"]) or not supplier.tags is Array:
			return false
	if not BookCatalog.use_api_books(data.books):
		return false
	customer_profiles.assign(data.customers)
	supplier_profiles.assign(data.suppliers)
	catalog_snapshot = data.duplicate(true)
	return true
