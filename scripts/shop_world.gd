extends RefCounted

const TRAITS := {
	"apressado": {"label": "Apressado", "patience": 45.0, "offers": 2, "markup": 1.12, "openness": -0.05, "hint": "Decide rápido; tolera apenas duas sugestões recusadas."},
	"indeciso": {"label": "Indeciso", "patience": 90.0, "offers": 6, "markup": 1.10, "openness": 0.15, "hint": "Tem mais paciência e gosta de explorar alternativas."},
	"colecionador": {"label": "Colecionador", "patience": 75.0, "offers": 4, "markup": 1.30, "openness": 0.0, "hint": "Valoriza raridades e aceita pagar mais por elas."},
	"negociador": {"label": "Negociador", "patience": 65.0, "offers": 4, "markup": 1.05, "openness": 0.0, "hint": "Prefere um bom acordo e costuma fazer contrapropostas."},
	"dificil": {"label": "Exigente", "patience": 55.0, "offers": 3, "markup": 1.15, "openness": -0.15, "hint": "É criterioso com recomendações e não gosta de insistência."}
}
const UPGRADES := {
	"lighting": {"name": "Luz de leitura", "price": 18, "description": "Uma luminária com brilho âmbar. +10 segundos de paciência para todos os clientes."},
	"shelves": {"name": "Estante de curadoria", "price": 26, "description": "Uma estante dedicada às descobertas da casa. Permite negociar até 5% extras do preço de balcão."},
	"plants": {"name": "Jardim do balcão", "price": 14, "description": "Folhagens e flores para acolher os leitores. +6 pontos percentuais nas recomendações compatíveis."}
}
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

func create_order(customer_id: String, book_id: String, condition: String) -> void:
	var entry: Dictionary = memories.get(customer_id, {})
	if bool(entry.get("order_created", false)):
		return
	entry["order_created"] = true
	entry["order"] = {"book_id": book_id, "condition": condition}
	memories[customer_id] = entry

func pending_orders() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in memories.values():
		if entry.has("order"):
			result.append(entry.order.duplicate(true))
	return result

func story_text(customer_id: String) -> String:
	var purchases := int(memories.get(customer_id, {}).get("purchases", 0))
	if not STORIES.has(customer_id) or purchases == 0:
		return "A história deste leitor ainda está começando."
	return str(STORIES[customer_id][mini(purchases, 3)])

func serialize() -> Dictionary:
	return {"upgrades": upgrades.duplicate(true), "memories": memories.duplicate(true)}

func restore(data: Dictionary) -> void:
	upgrades = data.get("upgrades", {}).duplicate(true)
	memories = data.get("memories", {}).duplicate(true)
