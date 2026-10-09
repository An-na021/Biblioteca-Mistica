class_name Inventory
extends RefCounted

signal changed

var quantities: Dictionary = {
	"jardim_horas": 3,
	"mar_vermelho": 2,
	"inventario_chuva": 2
}

func get_quantity(book_id: String) -> int:
	return int(quantities.get(book_id, 0))

func has(book_id: String) -> bool:
	return get_quantity(book_id) > 0

func add(book_id: String, amount := 1) -> void:
	quantities[book_id] = get_quantity(book_id) + amount
	changed.emit()

func remove(book_id: String, amount := 1) -> bool:
	if get_quantity(book_id) < amount:
		return false
	quantities[book_id] = get_quantity(book_id) - amount
	changed.emit()
	return true

func stocked_books() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for book in BookCatalog.all_books():
		if has(book.id):
			book["quantity"] = get_quantity(book.id)
			result.append(book)
	return result
