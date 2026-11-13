extends RefCounted
## Stable for a title/day, so changing the quote or reopening cannot reroll damage.
const PROFILES := [
	{"id": "dust", "name": "Poeira nas páginas", "detail": "As páginas estão íntegras; basta remover a poeira.", "stages": [0]},
	{"id": "tears", "name": "Páginas rasgadas", "detail": "Prepare as bordas, encaixe e assente os remendos; finalize na prensa.", "stages": [1, 2, 4]},
	{"id": "binding", "name": "Lombada solta", "detail": "Refaça a costura e acomode a encadernação na prensa.", "stages": [3, 4]},
	{"id": "dust_binding", "name": "Poeira e costura frouxa", "detail": "Limpe as páginas, refaça a costura e finalize na prensa.", "stages": [0, 3, 4]},
	{"id": "complete", "name": "Danos na encadernação e nas páginas", "detail": "Limpeza, colagem, remendos, costura e prensagem são necessários.", "stages": [0, 1, 2, 3, 4]}
]

static func for_book(book_id: String, day: int) -> Dictionary:
	# Explicit base profiles make familiar titles recognisable; later days vary.
	var titles := ["jardim_horas", "mar_vermelho", "relogio_perdido", "cronicas_norte", "inventario_chuva", "reino_vidro", "floresta_azul", "ultimo_dragao"]
	var index := titles.find(book_id)
	if index < 0:
		index = int(book_id.hash() % PROFILES.size())
	elif index == 5:
		index = 4
	return profile(str(PROFILES[(index + maxi(0, day - 1)) % PROFILES.size()].id))

static func profile(id: String) -> Dictionary:
	for entry in PROFILES:
		if str(entry.id) == id:
			return entry.duplicate(true)
	return PROFILES.back().duplicate(true)

static func summary(diagnosis: Dictionary) -> String:
	return str(diagnosis.get("name", "Diagnóstico")) + ". " + str(diagnosis.get("detail", ""))
