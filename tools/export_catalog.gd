extends SceneTree

const Game = preload("res://scripts/main_game.gd")

func _initialize() -> void:
	var books: Array[Dictionary] = []
	for original in BookCatalog.BOOKS:
		var item := original.duplicate()
		item["cover_path"] = item.cover_texture.resource_path
		item.erase("cover_texture")
		item["cover_color"] = "#" + original.cover_color.to_html(false)
		item["district_ids"] = districts_for(str(item.id), "book_ids")
		books.append(item)
	var customers: Array[Dictionary] = []
	for original in Game.CUSTOMER_PROFILES:
		var item := original.duplicate(true)
		item["district_ids"] = districts_for(str(item.id), "customer_ids")
		customers.append(item)
	var suppliers: Array[Dictionary] = []
	for original in Game.SUPPLIERS:
		var item := original.duplicate(true)
		item["special_orders"] = str(item.id) == "praca"
		suppliers.append(item)
	var file := FileAccess.open("res://api/seed.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"books": books, "customers": customers, "suppliers": suppliers}, "\t"))
	file.close()
	print("Catálogo inicial exportado para api/seed.json")
	quit()

func districts_for(record_id: String, field: String) -> Array[String]:
	var result: Array[String] = []
	for district in Game.DISTRICTS:
		if district[field].has(record_id):
			result.append(str(district.id))
	return result
