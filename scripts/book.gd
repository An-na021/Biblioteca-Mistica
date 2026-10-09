class_name Book
extends Interactable

@export var book_id: String = ""
@export var book_title: String = ""
@export var author: String = ""
@export var price: int = 0

var selected := false

func get_readable_details() -> String:
	return "%s\nAutor: %s\nPreco: %d moedas\n\n%s" % [book_title, author, price, description]


func set_selected(value: bool) -> void:
	selected = value
	_refresh_visual_state()


func _refresh_visual_state() -> void:
	scale = _base_scale * 1.05 if _hovered else _base_scale
	if selected:
		modulate = Color(1.35, 1.22, 0.75)
	elif _hovered:
		modulate = Color(1.18, 1.12, 0.92)
	else:
		modulate = Color.WHITE
