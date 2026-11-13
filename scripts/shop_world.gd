extends RefCounted

const TRAITS := {
	"apressado": {"label": "Apressado", "patience": 45.0, "offers": 2, "markup": 1.12, "openness": -0.05, "hint": "Decide rápido; tolera apenas duas sugestões recusadas."},
	"indeciso": {"label": "Indeciso", "patience": 90.0, "offers": 6, "markup": 1.10, "openness": 0.15, "hint": "Tem mais paciência e gosta de explorar alternativas."},
	"colecionador": {"label": "Colecionador", "patience": 75.0, "offers": 4, "markup": 1.30, "openness": 0.0, "hint": "Valoriza raridades e aceita pagar mais por elas."},
	"negociador": {"label": "Negociador", "patience": 65.0, "offers": 4, "markup": 1.05, "openness": 0.0, "hint": "Prefere um bom acordo e costuma fazer contrapropostas."},
	"dificil": {"label": "Exigente", "patience": 55.0, "offers": 3, "markup": 1.15, "openness": -0.15, "hint": "É criterioso com recomendações e não gosta de insistência."}
}
const UPGRADES := {
	"lighting": {"name": "Luz de leitura", "price": 18,
		"description": "Instala a luminária e dá +10 segundos de paciência a cada cliente.",
		"usage": "Automático nos próximos atendimentos. No modo sem limite, o tempo permanece ilimitado."},
	"shelves": {"name": "Estante de curadoria", "price": 26,
		"description": "Permite cobrar mais ao NEGOCIAR: soma 5% do preço de balcão ao limite aceito.",
		"usage": "Valor arredondado para baixo. Não altera o preço normal nem garante a venda."},
	"plants": {"name": "Jardim do balcão", "price": 14,
		"description": "Ao OFERECER uma alternativa compatível, aumenta a chance de aceitação em 6 pontos percentuais.",
		"usage": "Exige tema e condição do gosto do leitor. Não garante a venda."},
	"orders_cabinet": {"name": "Armário de encomendas", "price": 30,
		"description": "Protege as cópias encomendadas: outro cliente não pode comprá-las, recebê-las ou negociá-las.",
		"usage": "Compre o título e a condição pedidos na loja; a proteção é automática. Clique aqui para conferir. Só o titular retira a cópia."},
	"restoration_table": {"name": "Mesa de restauração", "price": 10,
		"description": "Por dia, conserte 1 livro do estoque e 1 encomenda de cliente: até 2 consertos. No estoque, escolha Usado, Novo ou Raro.",
		"usage": "O diagnóstico define as etapas. Abrir é gratuito; materiais só ao concluir. Consulte propostas, prazos e pagamentos em ENCOMENDAS DE RESTAURO."},
	"themed_display": {"name": "Vitrine temática", "price": 32,
		"description": "Define um tema, como Magia. Para cada próximo cliente, há 65% de chance de priorizar pedidos desse tema entre os livros compatíveis.",
		"usage": "Escolha um tema e use EXPOR ESTE TEMA; vale até você trocar ou desativar. Respeita gostos e bairro, sem criar livros ou garantir vendas."}
}
const WORKSHOP_IDS := ["orders_cabinet", "restoration_table", "themed_display"]
const RESTORATION_COST := 2
const RESTORATION_TARGETS := ["usado", "novo", "raro"]
const EVENTS := [
	{"id": "ordinary", "name": "Dia de descobertas", "tags": [], "condition": "", "bonus": 0.0, "description": "Um dia tranquilo para conhecer os leitores e preparar as estantes."},
	{"id": "maps", "name": "Caminhos e viagens", "tags": ["mapas", "viagem"], "condition": "", "bonus": 0.20, "description": "Leitores procuram mapas e relatos de viagem. Vendas desses temas rendem 20% de bônus."},
	{"id": "arcane", "name": "Encontro arcano", "tags": ["magia", "alquimia"], "condition": "", "bonus": 0.20, "description": "Magia e alquimia estão em alta. Vendas desses temas rendem 20% de bônus."},
	{"id": "poetry", "name": "Palavras e jardins", "tags": ["poesia", "natureza"], "condition": "", "bonus": 0.20, "description": "Poesia e natureza inspiram a cidade. Vendas desses temas rendem 20% de bônus."},
	{"id": "rarities", "name": "Mostra de raridades", "tags": [], "condition": "raro", "bonus": 0.20, "description": "Colecionadores celebram edições especiais. Exemplares raros rendem 20% de bônus."}
]
const STORIES := {
	"lyria": ["As sementes de Lyria", "As anotações da floresta começam a brotar.", "Lyria reúne poemas e registros para seu jardim de sementes luminosas.", "O jardim floresceu. Lyria dedicou uma árvore à livraria."],
	"tom": ["O primeiro grimório", "Tom levou sua primeira leitura para a escola de magia.", "Entre aventuras e diagramas, Tom prepara seu primeiro encantamento.", "Tom completou o encantamento e trouxe um marcador feito por ele."],
	"mestre_elian": ["O arquivo da torre", "Elian encontrou uma referência para seu arquivo.", "As notas de Elian aproximam dois capítulos perdidos.", "O arquivo foi restaurado. Seu nome consta nos agradecimentos."],
	"borin": ["Rotas sob a montanha", "Borin marcou a primeira rota em seu mapa.", "Os relatos ajudam Borin a ligar antigas galerias.", "A expedição voltou em segurança e Borin guardou um mapa para a loja."],
	"thalion_grimorio": ["Um atlas de encantamentos", "Thalion iniciou um novo caderno de pesquisas.", "O atlas de Thalion já reúne descobertas de várias cidades.", "Thalion concluiu o atlas e citou suas recomendações na introdução."],
	"professor_bigodes": ["A aula dos familiares", "O professor encontrou material para sua próxima aula.", "Os alunos investigam as histórias dos familiares falantes.", "A turma publicou um pequeno bestiário dedicado à livraria."],
	"lilith_vespera": ["Registros da meia-noite", "Lilith recuperou a primeira peça do arquivo.", "Os registros de Lilith revelam a origem de um ritual esquecido.", "O arquivo está completo. Lilith deixou uma carta de agradecimento."],
	"evelune": ["O herbário lunar", "Evelune anotou a primeira relação entre plantas e a lua.", "As observações de Evelune começam a formar um herbário.", "Evelune terminou o herbário e presenteou a loja com uma muda." ]
}

var upgrades: Dictionary = {}
var memories: Dictionary = {}
var last_restoration_day := -1
var last_contract_restoration_day := -1
var display_theme := ""
var restoration_jobs := preload("res://scripts/restoration_jobs.gd").new()

func offer_restoration(profile: Dictionary, book: Dictionary, day: int) -> Dictionary:
	if not upgrades.has("restoration_table"):
		return {}
	var condition := str(RESTORATION_TARGETS[(maxi(2, day) - 2) % RESTORATION_TARGETS.size()])
	return restoration_jobs.offer(profile, book, day, restoration_cost(str(book.get("id", "")), condition), condition)

func finish_restoration_job(id: String, day: int, funds: int, quote: int) -> int:
	if not upgrades.has("restoration_table") or last_contract_restoration_day == day:
		return -1
	var cost: int = restoration_jobs.finish(id, day, funds, quote)
	if cost >= 0:
		last_contract_restoration_day = day
	return cost

static func upgrade_description(upgrade_id: String) -> String:
	var info: Dictionary = UPGRADES.get(upgrade_id, {})
	return str(info.get("description", "")) + " " + str(info.get("usage", ""))

func reserved_quantity(book_id: String, condition: String, collecting_customer := "") -> int:
	var quantity := 0
	for order in pending_orders():
		if str(order.book_id) == book_id and str(order.condition) == condition and str(order.customer_id) != collecting_customer:
			quantity += 1
	return quantity

func available_for_customer(inventory: Inventory, book_id: String, condition: String, customer_id := "") -> int:
	var quantity := inventory.get_condition_quantity(book_id, condition)
	if upgrades.has("orders_cabinet"):
		var available := quantity - reserved_quantity(book_id, condition, customer_id)
		var own_order: Dictionary = memory(customer_id).get("order", {})
		if quantity > 0 and str(own_order.get("book_id", "")) == book_id and str(own_order.get("condition", "")) == condition:
			available = maxi(1, available)
		quantity = available
	return maxi(0, quantity)

func restorable_books(inventory: Inventory) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for book in BookCatalog.all_books():
		if available_for_customer(inventory, str(book.id), "danificado") > 0:
			result.append(book)
	return result

static func restoration_cost(book_id: String, target_condition := "usado") -> int:
	var book := BookCatalog.get_book(book_id)
	if book.is_empty() or target_condition not in RESTORATION_TARGETS:
		return -1
	if target_condition == "usado":
		return RESTORATION_COST
	var value_difference := BookCatalog.price_for_condition(book, target_condition, "buy_price") - BookCatalog.price_for_condition(book, "usado", "buy_price")
	var minimum_cost := 4 if target_condition == "novo" else 7
	return maxi(minimum_cost, RESTORATION_COST + value_difference)

func restore_book(inventory: Inventory, book_id: String, day: int, funds: int, target_condition := "usado", quoted_cost := -1) -> int:
	var materials_cost := restoration_cost(book_id, target_condition)
	if materials_cost < 0 or (quoted_cost >= 0 and quoted_cost != materials_cost):
		return -1
	if not upgrades.has("restoration_table") or day < 1 or last_restoration_day == day or funds < materials_cost:
		return -1
	if BookCatalog.get_book(book_id).is_empty() or available_for_customer(inventory, book_id, "danificado") <= 0:
		return -1
	var cost := inventory.get_unit_cost(book_id, "danificado") + materials_cost
	if not inventory.remove(book_id, 1, "danificado"):
		return -1
	inventory.add(book_id, 1, target_condition, cost)
	last_restoration_day = day
	return materials_cost

func set_display_theme(value: String) -> bool:
	if not upgrades.has("themed_display"):
		return false
	if not value.is_empty():
		var valid := false
		for book in BookCatalog.all_books():
			if book.get("tags", []).has(value):
				valid = true
				break
		if not valid:
			return false
	display_theme = value
	return true

func request_pool(books: Array[Dictionary], day: int, condition: String, display_roll := -1.0, event_roll := -1.0) -> Array[Dictionary]:
	if upgrades.has("themed_display") and not display_theme.is_empty():
		var displayed: Array[Dictionary] = []
		for book in books:
			if book.get("tags", []).has(display_theme):
				displayed.append(book)
		if not displayed.is_empty() and (randf() if display_roll < 0 else display_roll) < 0.65:
			return displayed
	var event_books: Array[Dictionary] = []
	var event := event_for_day(day)
	for book in books:
		var copy := book.duplicate()
		copy["condition"] = condition
		if event_matches(event, copy):
			event_books.append(book)
	if not event_books.is_empty() and (randf() if event_roll < 0 else event_roll) < 0.75:
		return event_books
	return books

static func get_traits(mood: String) -> Dictionary:
	return TRAITS.get(mood, TRAITS.indeciso).duplicate(true)

static func event_for_day(day: int) -> Dictionary:
	return EVENTS[posmod(day - 1, EVENTS.size())].duplicate(true)

static func event_matches(event: Dictionary, book: Dictionary) -> bool:
	if not str(event.get("condition", "")).is_empty():
		return str(book.get("condition", "")) == str(event.condition)
	for tag in event.get("tags", []):
		if book.get("tags", []).has(tag):
			return true
	return false

static func event_bonus(day: int, book: Dictionary) -> int:
	var event := event_for_day(day)
	if not event_matches(event, book):
		return 0
	return maxi(1, roundi(float(book.get("sale_price", 0)) * float(event.bonus)))

func purchase(upgrade_id: String, funds: int) -> int:
	if not UPGRADES.has(upgrade_id) or upgrades.has(upgrade_id):
		return -1
	var price := int(UPGRADES[upgrade_id].price)
	if funds < price:
		return -1
	upgrades[upgrade_id] = true
	return price

func patience_bonus() -> float:
	return 10.0 if upgrades.has("lighting") else 0.0

func recommendation_bonus() -> float:
	return 0.06 if upgrades.has("plants") else 0.0

func negotiation_bonus() -> float:
	return 0.05 if upgrades.has("shelves") else 0.0

func memory(customer_id: String) -> Dictionary:
	return memories.get(customer_id, {}).duplicate(true)

func record_visit(customer_id: String, day: int) -> void:
	var entry: Dictionary = memories.get(customer_id, {})
	entry["visits"] = int(entry.get("visits", 0)) + 1
	entry["last_visit"] = day
	memories[customer_id] = entry

func record_departure(customer_id: String) -> void:
	var entry: Dictionary = memories.get(customer_id, {})
	entry["last_outcome"] = "left"
	memories[customer_id] = entry

func record_purchase(customer_id: String, book_id: String, condition := "") -> Dictionary:
	var entry: Dictionary = memories.get(customer_id, {})
	var before := int(entry.get("purchases", 0))
	entry["purchases"] = before + 1
	entry["last_book"] = book_id
	entry["last_outcome"] = "sale"
	memories[customer_id] = entry
	var reward := 0
	if before < 3 and before + 1 == 3 and STORIES.has(customer_id):
		reward = 8
	var order_reward := 0
	var order: Dictionary = entry.get("order", {})
	if not order.is_empty() and str(order.book_id) == book_id and str(order.condition) == condition:
		entry.erase("order")
		entry["order_completed"] = true
		order_reward = 4
	return {"text": story_text(customer_id), "reward": reward + order_reward, "story_reward": reward, "order_reward": order_reward, "chapter": mini(before + 1, 3)}

func create_order(customer_id: String, book_id: String, condition: String) -> bool:
	var entry: Dictionary = memories.get(customer_id, {})
	if bool(entry.get("order_created", false)) or entry.has("order"):
		return false
	entry["order_created"] = true
	entry["order"] = {"book_id": book_id, "condition": condition}
	memories[customer_id] = entry
	return true

func reserve_book(customer_id: String, book_id: String, condition: String) -> bool:
	if customer_id.is_empty() or BookCatalog.get_book(book_id).is_empty() or not BookCatalog.CONDITIONS.has(condition):
		return false
	var entry: Dictionary = memories.get(customer_id, {})
	var existing: Dictionary = entry.get("order", {})
	if not existing.is_empty() and (str(existing.book_id) != book_id or str(existing.condition) != condition):
		return false
	entry["order"] = {"book_id": book_id, "condition": condition}
	entry["last_outcome"] = "reserved"
	memories[customer_id] = entry
	return true

func pending_orders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for customer_id in memories:
		var entry: Dictionary = memories[customer_id]
		if entry.has("order"):
			var order: Dictionary = entry.order.duplicate(true)
			order["customer_id"] = str(customer_id)
			result.append(order)
	return result

func story_text(customer_id: String) -> String:
	var purchases := int(memories.get(customer_id, {}).get("purchases", 0))
	if not STORIES.has(customer_id) or purchases == 0:
		return "A história deste leitor ainda está começando."
	return str(STORIES[customer_id][mini(purchases, 3)])

func serialize() -> Dictionary:
	return {"upgrades": upgrades.duplicate(true), "memories": memories.duplicate(true), "last_restoration_day": last_restoration_day, "last_contract_restoration_day": last_contract_restoration_day, "display_theme": display_theme, "restoration_jobs": restoration_jobs.serialize()}

func restore(data: Dictionary) -> void:
	upgrades = data.get("upgrades", {}).duplicate(true)
	memories = data.get("memories", {}).duplicate(true)
	last_restoration_day = int(data.get("last_restoration_day", -1))
	# Old saves had a shared limit: preserve that day's usage for both categories.
	last_contract_restoration_day = int(data.get("last_contract_restoration_day", last_restoration_day))
	display_theme = str(data.get("display_theme", ""))
	var jobs: Variant = data.get("restoration_jobs", {})
	restoration_jobs.restore(jobs if jobs is Dictionary else {})
