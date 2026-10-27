class_name BookCatalog
extends RefCounted

## The complete set of books known by the game.  Inventory deliberately keeps
## only ids and quantities, so customers may request unavailable titles.
const BOOKS: Array[Dictionary] = [
	{"id": "jardim_horas", "title": "O Jardim das Horas", "author": "A. Valente", "sale_price": 8, "buy_price": 5, "description": "Um romance estranho sobre relogios, sementes e promessas antigas.", "tags": ["natureza", "poesia", "alquimia", "magia"], "cover_color": Color("3a5e46"), "cover_texture": preload("res://bookimg/nhax.png")},
	{"id": "mar_vermelho", "title": "O Mar Vermelho", "author": "I. Nobre", "sale_price": 6, "buy_price": 4, "description": "Um diario de viagem com paginas salgadas.", "tags": ["viagem", "mapas", "aventura"], "cover_color": Color("912521"), "cover_texture": preload("res://bookimg/percy.png")},
	{"id": "inventario_chuva", "title": "Inventario de Chuva", "author": "L. Duarte", "sale_price": 5, "buy_price": 3, "description": "Um almanaque pratico, cheio de manchas de tinta.", "tags": ["natureza", "alquimia", "diagramas"], "cover_color": Color("263a6b"), "cover_texture": preload("res://bookimg/nhac.jpg")},
	{"id": "floresta_azul", "title": "A Floresta Azul", "author": "M. Sereno", "sale_price": 10, "buy_price": 7, "description": "Contos de trilhas que aparecem apenas depois da chuva.", "tags": ["natureza", "poesia", "aventura"], "cover_color": Color("315f83"), "cover_texture": preload("res://bookimg/livro 3.png")},
	{"id": "ultimo_dragao", "title": "O Ultimo Dragao", "author": "R. Azevedo", "sale_price": 12, "buy_price": 9, "description": "Uma lenda antiga guardada entre cinzas e ouro.", "tags": ["mitologia", "criaturas", "batalhas", "magia"], "cover_color": Color("7d4032"), "cover_texture": preload("res://bookimg/pother.png")},
	{"id": "cronicas_norte", "title": "As Cronicas do Norte", "author": "E. Monte", "sale_price": 11, "buy_price": 8, "description": "Mapas, neve e historias de uma fronteira distante.", "tags": ["cronicas", "mapas", "viagem", "historia"], "cover_color": Color("536d77"), "cover_texture": preload("res://bookimg/cronicas_norte.png")},
	{"id": "relogio_perdido", "title": "O Relogio Perdido", "author": "C. Vilar", "sale_price": 9, "buy_price": 6, "description": "Um misterio silencioso entre engrenagens e cartas.", "tags": ["engenharia", "diagramas", "cronicas"], "cover_color": Color("765c34"), "cover_texture": preload("res://bookimg/relogio_perdido.png")},
	{"id": "reino_vidro", "title": "O Reino de Vidro", "author": "N. Faria", "sale_price": 13, "buy_price": 10, "description": "Fabulas luminosas de um palacio fragil.", "tags": ["poesia", "mitologia", "cronicas", "rituais"], "cover_color": Color("604b78"), "cover_texture": preload("res://bookimg/reino_vidro.png")}
]

const CONDITIONS := {
	"novo": {"label": "Novo", "buy_multiplier": 1.0, "sale_multiplier": 1.0},
	"usado": {"label": "Usado", "buy_multiplier": 0.75, "sale_multiplier": 0.8},
	"danificado": {"label": "Danificado", "buy_multiplier": 0.4, "sale_multiplier": 0.5},
	"raro": {"label": "Raro", "buy_multiplier": 1.6, "sale_multiplier": 1.8}
}

static var _api_books: Array[Dictionary] = []

static func reset_catalog() -> void:
	_api_books.clear()

static func use_api_books(records: Array) -> bool:
	var converted: Array[Dictionary] = []
	for record in records:
		if not record is Dictionary or not record.has_all(["id", "title", "author", "buy_price", "sale_price", "tags", "district_ids"]):
			return false
		if not record.tags is Array or not record.district_ids is Array or int(record.buy_price) <= 0 or int(record.sale_price) <= 0:
			return false
		var item: Dictionary = record.duplicate(true)
		item["cover_color"] = Color.from_string(str(record.get("cover_color", "#604b78")), Color("604b78"))
		item["cover_texture"] = null
		var cover_path := str(record.get("cover_path", ""))
		if cover_path.begins_with("res://bookimg/") and ResourceLoader.exists(cover_path):
			item["cover_texture"] = load(cover_path) as Texture2D
		converted.append(item)
	if converted.is_empty():
		return false
	_api_books = converted
	return true

static func get_condition(condition_id: String) -> Dictionary:
	return CONDITIONS.get(condition_id, CONDITIONS["novo"]).duplicate(true)

static func price_for_condition(book: Dictionary, condition_id: String, price_key: String) -> int:
	var condition := get_condition(condition_id)
	var multiplier_key := "buy_multiplier" if price_key == "buy_price" else "sale_multiplier"
	return maxi(1, roundi(float(book.get(price_key, 1)) * float(condition.get(multiplier_key, 1.0))))

static func get_book(book_id: String) -> Dictionary:
	for book in _api_books if not _api_books.is_empty() else BOOKS:
		if book.id == book_id:
			return book.duplicate()
	return {}

static func all_books() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for book in _api_books if not _api_books.is_empty() else BOOKS:
		result.append(book.duplicate())
	return result

static func random_book() -> Dictionary:
	return all_books().pick_random().duplicate()

static func books_for_preferences(preferences: Array) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for book in all_books():
		for tag in book.get("tags", []):
			if preferences.has(tag):
				matches.append(book.duplicate())
				break
	return matches
