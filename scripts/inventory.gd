class_name Inventory
extends RefCounted

signal changed

var condition_quantities: Dictionary = {
	"jardim_horas": {"novo": 1, "usado": 1, "raro": 1},
	"mar_vermelho": {"usado": 1, "danificado": 1},
	"inventario_chuva": {"novo": 1, "danificado": 1}
}
var acquisition_costs: Dictionary = {}

func get_quantity(book_id: String) -> int:
	var total := 0
	for quantity in condition_quantities.get(book_id, {}).values():
		total += int(quantity)
	return total

func get_condition_quantity(book_id: String, condition: String) -> int:
	return int(condition_quantities.get(book_id, {}).get(condition, 0))

func has(book_id: String) -> bool:
	return get_quantity(book_id) > 0

func add(book_id: String, amount := 1, condition := "novo", unit_cost := -1) -> void:
	if not condition_quantities.has(book_id):
		condition_quantities[book_id] = {}
	var book_conditions: Dictionary = condition_quantities[book_id]
	var existing_quantity := get_condition_quantity(book_id, condition)
	if not acquisition_costs.has(book_id):
		acquisition_costs[book_id] = {}
	if not acquisition_costs[book_id].has(condition):
		acquisition_costs[book_id][condition] = []
	var costs: Array = acquisition_costs[book_id][condition]
	var recorded_cost := unit_cost
	if recorded_cost < 0:
		recorded_cost = BookCatalog.price_for_condition(BookCatalog.get_book(book_id), condition, "buy_price")
	if costs.is_empty() and existing_quantity > 0:
		var original_cost := BookCatalog.price_for_condition(BookCatalog.get_book(book_id), condition, "buy_price")
		for _existing_copy in range(existing_quantity):
			costs.append(original_cost)
	for _copy in range(amount):
		costs.append(recorded_cost)
	book_conditions[condition] = existing_quantity + amount
	changed.emit()

func get_unit_cost(book_id: String, condition: String) -> int:
	var costs: Array = acquisition_costs.get(book_id, {}).get(condition, [])
	if not costs.is_empty():
		return int(costs[0])
	return BookCatalog.price_for_condition(BookCatalog.get_book(book_id), condition, "buy_price")

func remove(book_id: String, amount := 1, condition := "novo") -> bool:
	if get_condition_quantity(book_id, condition) < amount:
		return false
	var book_conditions: Dictionary = condition_quantities[book_id]
	book_conditions[condition] = get_condition_quantity(book_id, condition) - amount
	var costs: Array = acquisition_costs.get(book_id, {}).get(condition, [])
	for _copy in range(amount):
		if not costs.is_empty():
			costs.pop_front()
	changed.emit()
	return true

func stocked_books() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for book in BookCatalog.all_books():
		var condition_items: Array[Dictionary] = []
		for condition in BookCatalog.CONDITIONS:
			var quantity := get_condition_quantity(book.id, condition)
			if quantity <= 0:
				continue
			var condition_info := BookCatalog.get_condition(condition)
			condition_items.append({
				"condition": condition,
				"condition_label": condition_info.label,
				"quantity": quantity,
				"buy_price": BookCatalog.price_for_condition(book, condition, "buy_price"),
				"sale_price": BookCatalog.price_for_condition(book, condition, "sale_price")
			})
		if condition_items.is_empty():
			continue
		var stock_item := book.duplicate(true)
		stock_item["quantity"] = get_quantity(book.id)
		stock_item["conditions"] = condition_items
		result.append(stock_item)
	return result
