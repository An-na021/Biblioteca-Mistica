class_name Customer
extends Interactable

@export var customer_name: String = "Cliente"
@export_multiline var request_text: String = ""
@export var requested_book_id: String = ""
@export var portrait_scale: Vector2 = Vector2(0.55, 0.55)

var served := false
var profile_data: Dictionary = {}
@onready var portrait: Sprite2D = get_node_or_null("Portrait") as Sprite2D
@onready var fallback_art: Array[CanvasItem] = [
	get_node_or_null("Body") as CanvasItem,
	get_node_or_null("Head") as CanvasItem,
	get_node_or_null("Hair") as CanvasItem,
	get_node_or_null("Collar") as CanvasItem
]

func configure(profile: Dictionary, requested_book: Dictionary) -> void:
	profile_data = profile.duplicate(true)
	customer_name = profile.name
	requested_book_id = requested_book.id
	request_text = "%s. Procuro um livro chamado %s." % [profile.greeting, requested_book.title]
	served = false
	interaction_name = customer_name
	description = request_text
	_set_portrait(str(profile.get("portrait_path", "")))
	set_selected(false)


func get_profile() -> Dictionary:
	return profile_data.duplicate(true)

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
		return "Obrigada. Vou voltar quando a tarde estiver mais quieta."
	return request_text


func deliver(book: Dictionary) -> Dictionary:
	if book.id == requested_book_id:
		served = true
		return {
			"accepted": true,
			"text": "Era exatamente este. Voce tem olhos atentos. Obrigada.",
			"money": int(book.sale_price),
			"reputation": 1
		}

	return {
		"accepted": false,
		"text": "Nao, este nao e o livro que pedi. Talvez esteja em outra estante.",
		"money": 0,
		"reputation": -1
	}

func negotiate(book: Dictionary) -> Dictionary:
	if book.id != requested_book_id:
		return {"accepted": false, "text": "Esse nao e o livro que pedi. Ainda procuro %s." % requested_book_id, "money": 0, "reputation": 0}
	served = true
	var negotiated_price: int = int(book.sale_price) + max(1, ceili(float(book.sale_price) * 0.25))
	return {"accepted": true, "text": "Tudo bem, aceito o preco negociado. Levarei este livro.", "money": negotiated_price, "reputation": 1}

func react_to_offer(book: Dictionary) -> Dictionary:
	if book.id == requested_book_id:
		return deliver(book)
	if randf() < 0.45:
		served = true
		return {"accepted": true, "text": "Nao era o que eu procurava, mas este parece interessante. Vou leva-lo.", "money": int(book.sale_price), "reputation": 0}
	return {"accepted": false, "text": "Agradeco a sugestao, mas ainda procuro %s." % requested_book_id, "money": 0, "reputation": 0}
