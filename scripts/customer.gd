class_name Customer
extends Interactable

@export var customer_name: String = "Cliente"
@export_multiline var request_text: String = ""
@export var requested_book_id: String = ""
@export var portrait_scale: Vector2 = Vector2(0.55, 0.55)

const MAX_DECLINED_ALTERNATE_OFFERS := 4

var served := false
var profile_data: Dictionary = {}
var reputation_band := "regular"
var declined_alternate_offers := 0
var request_mode := "titulo"
var request_clue: Dictionary = {}
var acceptable_book_ids: Array[String] = []
@onready var portrait: Sprite2D = get_node_or_null("Portrait") as Sprite2D
@onready var fallback_art: Array[CanvasItem] = [get_node_or_null("Body") as CanvasItem, get_node_or_null("Head") as CanvasItem, get_node_or_null("Hair") as CanvasItem, get_node_or_null("Collar") as CanvasItem]

const REQUESTS := {
	"lyria": "Saudações. Procuro %s; dizem que suas páginas guardam ecos da natureza.",
	"tom": "Olá! Estou atrás de %s. Será que tem algo de especial para aprender nele?",
	"mestre_elian": "Com licença. Vim consultar %s; espero encontrar uma edição bem preservada.",
	"borin": "Boa tarde. Quero ver %s. Se tiver um mapa ou relato útil, melhor ainda.",
	"thalion_grimorio": "Saudações, guardiã dos livros. Procuro %s para minhas pesquisas arcanas.",
	"professor_bigodes": "Miau... digo, boa tarde. Vim buscar %s para minhas aulas de história arcana.",
	"lilith_vespera": "Boa noite. Estou procurando %s para completar meus registros antigos.",
	"evelune": "Olá. Procuro %s; talvez ele me ajude a compreender melhor os ciclos da natureza."
}

const VOICES := {
	"lyria": ["Era este mesmo. As histórias da natureza sempre me levam a lugares novos.", "Esse não parece ser %s. Ainda procuro o título que pedi.", "Está bem, aceito o preço. Quero descobrir o que há nestas páginas.", "Não era minha primeira escolha, mas as histórias da natureza me convenceram.", "Agradeço, mas prefiro continuar procurando %s.", "Obrigada pela ajuda. Vou levar minha leitura para casa."],
	"tom": ["Era esse! Mal posso esperar para descobrir o que vou aprender.", "Acho que não é %s. Foi esse o título que anotei.", "Fechado! Vai valer a pena guardar minhas moedas para este livro.", "Esse não era o que eu tinha em mente, mas parece uma aventura incrível!", "Obrigado pela ideia, mas ainda quero encontrar %s.", "Valeu! Já estou pensando em qual capítulo vou ler primeiro."],
	"mestre_elian": ["Exatamente a edição que solicitei. Agradeço o cuidado.", "Este exemplar não corresponde a %s. Vou manter o pedido original.", "Aceito o valor. A conservação desta edição justifica o preço.", "Não era minha busca inicial, mas este exemplar merece atenção.", "Agradeço a sugestão. Ainda procuro %s.", "Agradeço o atendimento. Até a próxima consulta."],
	"borin": ["É esse mesmo. Bom título; agora estamos falando.", "Não foi esse que pedi. Continuo atrás de %s.", "Fechado. Por esse preço, temos um acordo.", "Eu buscava outra coisa, mas este relato parece valer as moedas.", "Vou passar. Ainda quero %s.", "Negócio feito. Até mais."],
	"thalion_grimorio": ["Perfeito! Este volume será muito útil para meus estudos arcanos.", "Este não é %s. Preciso do título certo para minha pesquisa.", "Aceito. Um bom grimório vale o investimento.", "Não era o volume planejado, mas há muito a pesquisar aqui.", "Agradeço, mas meu estudo depende de %s.", "Excelente. Que este conhecimento revele novos caminhos."],
	"professor_bigodes": ["Magnífico! Este título será uma ótima referência para minhas aulas.", "Hum, não encontrei aqui %s. Esse exemplar não atende ao pedido.", "Aceito o preço. Uma referência tão útil merece um lugar na biblioteca.", "Não era o título da aula, mas este também rende uma boa pesquisa.", "Agradeço a oferta, mas preciso de %s.", "Uma aquisição excelente. Meus alunos vão agradecer."],
	"lilith_vespera": ["Era exatamente o registro que faltava. Obrigada.", "Este não é %s. Ainda preciso localizar o registro correto.", "Aceito. Este registro raro justifica o valor.", "Não era o registro que eu buscava, mas pode completar outra parte do arquivo.", "Vou recusar. Ainda procuro %s.", "Meu arquivo está mais completo. Até breve."],
	"evelune": ["Era esse mesmo! Vou comparar suas anotações com meus estudos da natureza.", "Não é %s. Talvez eu o encontre em outra estante.", "Tudo bem, aceito. Este livro pode me ajudar nos estudos.", "Eu buscava outro título, mas este também pode revelar algo interessante.", "Agradeço, mas ainda procuro %s.", "Obrigada. Vou ler com calma e anotar o que descobrir."]
}

func configure(profile: Dictionary, requested_book: Dictionary, current_reputation: int = 0) -> void:
	profile_data = profile.duplicate(true)
	customer_name = str(profile.get("name", "Cliente"))
	requested_book_id = str(requested_book.get("id", ""))
	reputation_band = "low" if current_reputation < -2 else ("high" if current_reputation >= 3 else "regular")
	_request_clue_for_book(requested_book)
	if reputation_band == "high":
		request_text = "Que bom voltar a esta livraria. " + request_text
	elif reputation_band == "low":
		request_text = "Espero que desta vez encontre o que procuro. " + request_text
	served = false
	declined_alternate_offers = 0
	interaction_name = customer_name
	description = request_text
	_set_portrait(str(profile.get("portrait_path", "")))
	set_selected(false)

func get_profile() -> Dictionary:
	return profile_data.duplicate(true)

func get_request_clue() -> Dictionary:
	return request_clue.duplicate(true)

func can_accept_book(book_id: String) -> bool:
	return acceptable_book_ids.has(book_id)

func _request_clue_for_book(book: Dictionary) -> void:
	acceptable_book_ids.clear()
	request_mode = "titulo"
	if randf() < 0.7:
		request_mode = ["autor", "genero", "caracteristica"].pick_random()
	var target_id := str(book.get("id", ""))
	var target_author := str(book.get("author", ""))
	var target_tags: Array = book.get("tags", [])
	var clue_tag := str(target_tags.pick_random()) if not target_tags.is_empty() else "aventura"
	var tag_name := _tag_label(clue_tag)
	match request_mode:
		"autor":
			request_text = "Procuro uma obra de %s, mas o título me escapou." % target_author
			request_clue = {"type": "autor", "text": request_text, "attribute": target_author}
		"genero":
			request_text = "Estou buscando um livro de %s. Você consegue me ajudar a encontrá-lo?" % tag_name
			request_clue = {"type": "genero", "text": request_text, "attribute": clue_tag}
		"caracteristica":
			request_text = "Queria uma leitura com %s. Não lembro o nome do livro." % tag_name
			request_clue = {"type": "caracteristica", "text": request_text, "attribute": clue_tag}
		_:
			request_text = str(REQUESTS.get(str(profile_data.get("id", "")), "Olá. Estou procurando %s.")) % str(book.get("title", "um livro"))
			request_clue = {"type": "titulo", "text": request_text, "attribute": str(book.get("title", ""))}
	for candidate in BookCatalog.all_books():
		var matches_clue := false
		match request_mode:
			"autor": matches_clue = str(candidate.get("author", "")) == target_author
			"genero", "caracteristica": matches_clue = candidate.get("tags", []).has(clue_tag)
			_: matches_clue = str(candidate.get("id", "")) == target_id
		if matches_clue:
			acceptable_book_ids.append(str(candidate.get("id", "")))

func _tag_label(tag: String) -> String:
	var labels := {
		"natureza": "temas ligados à natureza", "poesia": "poesia", "mitologia": "mitologia",
		"magia": "magia", "aventura": "aventuras", "diagramas": "diagramas e esquemas",
		"cronicas": "crônicas e relatos", "historia": "história", "mapas": "mapas",
		"viagem": "viagens", "engenharia": "engenharia", "batalhas": "batalhas antigas",
		"alquimia": "alquimia", "rituais": "rituais arcanos", "criaturas": "criaturas encantadas"
	}
	return str(labels.get(tag, tag))

func _not_a_match_text() -> String:
	if request_mode == "titulo":
		return _line(1, requested_book_id)
	return "Esse exemplar não corresponde à pista. " + request_text

func _set_portrait(path: String) -> void:
	var portrait_texture: Texture2D = portrait.texture if portrait != null else null
	if not path.is_empty():
		portrait_texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	if portrait != null:
		portrait.texture = portrait_texture
		portrait.scale = portrait_scale
		portrait.visible = portrait_texture != null
	for piece in fallback_art:
		if piece != null:
			piece.visible = portrait_texture == null

func _ready() -> void:
	super()
	interaction_name = customer_name
	description = request_text
	interaction_type = "customer"

func get_greeting() -> String:
	if served:
		return _line(5, requested_book_id)
	return request_text

func _line(index: int, book_id: String) -> String:
	var profile_lines: Array = VOICES.get(str(profile_data.get("id", "")), VOICES["evelune"])
	var title := str(BookCatalog.get_book(book_id).get("title", "esse livro"))
	var result := str(profile_lines[index])
	if result.contains("%s"):
		result = result % title
	if reputation_band == "high":
		return "Confio na sua indicação. " + result
	if reputation_band == "low":
		return "Ainda estou um pouco desconfiado. " + result
	return result

func _condition_rejection(book: Dictionary, count_as_offer := false) -> Dictionary:
	var preferred_condition := str(profile_data.get("preferred_condition", "novo"))
	var offered_condition := str(book.get("condition", "novo"))
	if offered_condition == preferred_condition:
		return {}
	var condition_names := {"novo": "novos", "usado": "usados", "danificado": "danificados", "raro": "raros"}
	var preferred_label := str(condition_names.get(preferred_condition, preferred_condition))
	var offered_label := str(condition_names.get(offered_condition, offered_condition))
	var response := "Agradeço, mas prefiro exemplares %s. Não gosto de livros %s." % [preferred_label, offered_label]
	var completed := false
	var reputation_change := 0
	if count_as_offer:
		declined_alternate_offers += 1
		completed = declined_alternate_offers >= MAX_DECLINED_ALTERNATE_OFFERS
		if completed:
			served = true
			reputation_change = -1
			response += " Vou continuar procurando em outra livraria."
	return {"accepted": false, "completed": completed, "text": response, "money": 0, "reputation": reputation_change}

func deliver(book: Dictionary) -> Dictionary:
	var condition_result := _condition_rejection(book)
	if not condition_result.is_empty():
		return condition_result
	if can_accept_book(str(book.get("id", ""))):
		served = true
		return {"accepted": true, "text": _line(0, book.id), "money": int(book.sale_price), "reputation": 1}
	return {"accepted": false, "text": _not_a_match_text(), "money": 0, "reputation": -1}

func negotiate(book: Dictionary) -> Dictionary:
	var condition_result := _condition_rejection(book)
	if not condition_result.is_empty():
		return condition_result
	if not can_accept_book(str(book.get("id", ""))):
		return {"accepted": false, "text": _not_a_match_text(), "money": 0, "reputation": 0}
	served = true
	var negotiated_price: int = int(book.sale_price) + max(1, ceili(float(book.sale_price) * 0.25))
	return {"accepted": true, "text": _line(2, book.id), "money": negotiated_price, "reputation": 1}

func react_to_offer(book: Dictionary) -> Dictionary:
	var condition_result := _condition_rejection(book, true)
	if not condition_result.is_empty():
		return condition_result
	if can_accept_book(str(book.get("id", ""))):
		return deliver(book)
	if randf() < 0.45:
		served = true
		return {"accepted": true, "completed": true, "text": _line(3, book.id), "money": int(book.sale_price), "reputation": 0}
	declined_alternate_offers += 1
	if declined_alternate_offers >= MAX_DECLINED_ALTERNATE_OFFERS:
		served = true
		var farewell := _line(4, requested_book_id) if request_mode == "titulo" else _not_a_match_text()
		return {"accepted": false, "completed": true, "text": farewell + " Vou voltar quando o livro estiver disponivel.", "money": 0, "reputation": -1}
	var response := _line(4, requested_book_id) if request_mode == "titulo" else _not_a_match_text()
	return {"accepted": false, "completed": false, "text": response, "money": 0, "reputation": 0}
