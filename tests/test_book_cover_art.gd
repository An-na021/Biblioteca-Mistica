extends SceneTree

const Covers = preload("res://scripts/book_cover_art.gd")
const Bench = preload("res://scripts/restoration_bench.gd")
const Driver = preload("res://tests/restoration_input.gd")
const FINISHES := ["danificado", "usado", "novo", "raro"]
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1

func settle() -> void:
	for _frame in range(4):
		await process_frame

func screenshot(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func find_cover(node: Node, id: String) -> TextureRect:
	if node is TextureRect and node.name == "BookCover" and str(node.get_meta("book_id", "")) == id:
		return node
	for child in node.get_children():
		var result := find_cover(child, id)
		if result != null:
			return result
	return null

func choices(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in node.get_children():
		if child is Button and child.has_meta("condition"):
			result.append(child)
		result.append_array(choices(child))
	return result

func select_quality(picker: OptionButton, condition: String) -> void:
	await Driver.click(self, picker)
	var popup := picker.get_popup()
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) != condition:
			continue
		popup.set_focused_item(index)
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		key.window_id = popup.get_window_id()
		root.push_input(key)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		root.push_input(key)
		await settle()
		return
	check(false, "Condição disponível no fornecedor: " + condition)

func run() -> void:
	root.size = Vector2i(1280, 720)
	BookCatalog.reset_catalog()
	for book in BookCatalog.all_books():
		var original := book.cover_texture as Texture2D
		for condition in FINISHES:
			Covers.texture_for(book, condition)
		check(BookCatalog.get_book(str(book.id)).cover_texture == original, "Arte original preservada: " + str(book.title))
	var fallback := {"id": "api_without_cover", "title": "Capa sem imagem", "cover_color": Color("345848")}
	for condition in FINISHES:
		Covers.texture_for(fallback, condition)
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var rendered_books := BookCatalog.all_books()
		rendered_books.append(fallback)
		for book in rendered_books:
			var previous := PackedByteArray()
			for condition in FINISHES:
				var pixels := Covers.texture_for(book, condition).get_image()
				check(not pixels.is_empty() and pixels.get_pixel(0, 0).a == 0 and pixels.get_pixel(200, 288).a > 0.9, "Capa renderizada com fundo transparente: %s / %s" % [str(book.id), condition])
				var bytes := pixels.get_data()
				check(previous.is_empty() or bytes != previous, "Acabamento visual distinto: %s / %s" % [str(book.id), condition])
				previous = bytes
	var stock := Inventory.new()
	stock.add("jardim_horas", 1, "danificado")
	var before := stock.condition_quantities.duplicate(true)
	var screen := InventoryScreen.new()
	root.add_child(screen)
	screen.setup(stock, {}, true, "raro")
	await settle()
	var book := BookCatalog.get_book("jardim_horas")
	var cover := find_cover(screen, "jardim_horas")
	check(cover != null and cover.texture == Covers.texture_for(book, "raro"), "Estoque abre com a capa da condição preferida e selecionada")
	for condition in FINISHES:
		for button in choices(screen.book_list):
			if str(button.get_meta("condition")) == condition and button.button_group.get_buttons().size() == 4:
				await Driver.click(self, button)
				break
		await settle()
		check(cover.get_meta("condition") == condition and cover.texture == Covers.texture_for(book, condition), "Selecionar exemplar atualiza a capa no estoque: " + condition)
		if condition in ["danificado", "raro"]:
			await screenshot("cover_stock_" + condition)
	check(stock.condition_quantities == before, "Trocar acabamentos não altera estoque ou conservação dos exemplares")
	screen.queue_free()
	await settle()
	# Outside an active sale, the condition filter also determines the cover.
	screen = InventoryScreen.new()
	root.add_child(screen)
	screen.setup(stock)
	for index in range(screen.condition_filter.item_count):
		if str(screen.condition_filter.get_item_metadata(index)) == "danificado":
			screen.condition_filter.select(index)
			screen.condition_filter.item_selected.emit(index)
	await settle()
	cover = find_cover(screen, "jardim_horas")
	check(cover != null and cover.texture == Covers.texture_for(book, "danificado"), "Filtro de condição também mostra a capa correspondente sem cliente")
	screen.queue_free()
	await settle()
	var merchant := MerchantScreen.new()
	root.add_child(merchant)
	var offers := {}
	for entry in BookCatalog.all_books():
		var conditions := {}
		for condition in FINISHES:
			conditions[condition] = {"quantity": 2, "price": BookCatalog.price_for_condition(entry, condition, "buy_price")}
		offers[str(entry.id)] = {"conditions": conditions}
	merchant.setup(stock, offers, 100)
	await settle()
	var row := merchant.book_list.get_node("Book_jardim_horas")
	var picker := row.get_node("Condition") as OptionButton
	cover = find_cover(row, "jardim_horas")
	for condition in FINISHES:
		await select_quality(picker, condition)
		check(str(picker.get_item_metadata(picker.selected)) == condition and cover.texture == Covers.texture_for(book, condition), "Fornecedor mostra a capa e o preço da opção selecionada: " + condition)
	await screenshot("cover_merchant_rare")
	merchant.refresh(95)
	await settle()
	cover = find_cover(merchant, "jardim_horas")
	check(cover.texture == Covers.texture_for(book, "raro"), "Atualização após compra mantém a capa da condição escolhida")
	merchant.queue_free()
	await settle()
	for condition in ["usado", "novo", "raro"]:
		var bench := Bench.new()
		root.add_child(bench)
		bench.setup(book, condition, 100)
		check(bench._cover == Covers.texture_for(book, "danificado"), "Bancada começa com o exemplar danificado: " + condition)
		bench.show_result(false)
		check(bench._cover == Covers.texture_for(book, "danificado"), "Conserto recusado não mostra uma capa restaurada")
		bench.stage = Bench.Stage.DONE
		bench._refresh()
		bench.show_result(true)
		await settle()
		check(bench._cover == Covers.texture_for(book, condition), "Conclusão bem-sucedida mostra o acabamento pago: " + condition)
		if condition == "raro":
			await screenshot("cover_restored_rare")
		bench.queue_free()
		await settle()
	check(stock.condition_quantities == before, "Todas as prévias preservam as quantidades reais")
	print("RESULT: ", failures, " failure(s)")
	quit(0 if failures == 0 else 1)
