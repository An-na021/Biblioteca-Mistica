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

static func get_book(book_id: String) -> Dictionary:
	for book in BOOKS:
		if book.id == book_id:
			return book.duplicate()
	return {}

static func all_books() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for book in BOOKS:
		result.append(book.duplicate())
	return result

static func random_book() -> Dictionary:
	return BOOKS.pick_random().duplicate()

static func books_for_preferences(preferences: Array) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for book in BOOKS:
		for tag in book.get("tags", []):
			if preferences.has(tag):
				matches.append(book.duplicate())
				break
	return matches
