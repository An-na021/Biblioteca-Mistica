extends SceneTree

var failures := 0
var test_path := "res://.godot/rare_stock_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func condition_choices(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in node.get_children():
		if child is Button and child.has_meta("condition"):
			result.append(child)
		result.append_array(condition_choices(child))
	return result

func screenshot(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func choose_condition(screen: InventoryScreen, condition: String) -> void:
	var picker := screen.condition_filter
	var index := 0
	for item in range(picker.item_count):
		if str(picker.get_item_metadata(item)) == condition:
			index = item
	picker.show_popup()
	await process_frame
	var popup := picker.get_popup()
	popup.index_pressed.emit(index)
	popup.hide()
	for _frame in range(15):
		await process_frame
	check(picker.selected == index, "Menu de condições aplicou a seleção " + condition)

func run() -> void:
	root.size = Vector2i(1068, 687)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.customer.profile_data.preferred_condition = "raro"
	game.customer.request_clue = {"type": "caracteristica", "text": "Na última visita saí sem uma leitura. Vamos tentar de novo? Queria uma leitura com temas ligados à natureza. Não lembro o nome do livro."}
	game.inventory.remove("jardim_horas", 1, "novo")
	game._open_inventory()
	var screen: InventoryScreen = game.active_overlay
	for _frame in range(5):
		await process_frame
	var choices := condition_choices(screen.book_list)
	check(screen.condition_filter.selected == 0 and screen.book_scroll.scroll_vertical == 0, "Abrir estoque começa em Todas as condições e no primeiro título")
	check(choices.any(func(button: Button) -> bool: return button.get_meta("condition") == "raro" and button.is_visible_in_tree()), "Exemplar raro aparece nas condições do estoque")
	check(choices.any(func(button: Button) -> bool: return button.get_meta("condition") == "raro" and button.button_pressed), "Condição rara disponível fica selecionada para o cliente que prefere raros")
	var scroll := screen.book_list.get_parent() as ScrollContainer
	scroll.scroll_vertical = 1000
	await process_frame
	check(scroll.scroll_vertical > 0, "Reprodução começa com a lista rolada para baixo")
	screen._refresh_books()
	for _frame in range(5):
		await process_frame
	check(scroll.scroll_vertical == 0, "Atualizar os filtros devolve a lista ao início sem esconder o primeiro título")
	await screenshot("rare_stock_all_conditions")
	await choose_condition(screen, "raro")
	for _frame in range(5):
		await process_frame
	choices = condition_choices(screen.book_list)
	check(choices.size() == 1 and choices[0].get_meta("condition") == "raro", "Filtro de raros exibe o exemplar disponível")
	await screenshot("rare_stock_filtered")
	await choose_condition(screen, "")
	for _frame in range(5):
		await process_frame
	choices = condition_choices(screen.book_list)
	var rare_button: Button
	for choice in choices:
		if choice.get_meta("condition") == "raro":
			rare_button = choice
	check(rare_button != null and scroll.get_global_rect().encloses(rare_button.get_global_rect()) and rare_button.button_pressed, "Voltar a todas as condições mantém o raro visível e selecionado, junto das outras condições")
	check(game.inventory.get_condition_quantity("jardim_horas", "raro") == 1, "Mudar filtros preserva o exemplar raro no estoque")
	await screenshot("rare_stock_cleared")
	root.size = Vector2i(1131, 541)
	for _frame in range(5):
		await process_frame
	await choose_condition(screen, "raro")
	await choose_condition(screen, "")
	choices = condition_choices(screen.book_list)
	for choice in choices:
		if choice.get_meta("condition") == "raro":
			check(screen.book_scroll.get_global_rect().encloses(choice.get_global_rect()), "Raro continua dentro da área visível após trocar filtros em janela baixa")
	await screenshot("rare_stock_short_window")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
