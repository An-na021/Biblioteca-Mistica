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

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.customer.profile_data.preferred_condition = "raro"
	game._open_inventory()
	var screen: InventoryScreen = game.active_overlay
	for _frame in range(5):
		await process_frame
	var choices := condition_choices(screen.book_list)
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
	for index in range(screen.condition_filter.item_count):
		if screen.condition_filter.get_item_metadata(index) == "raro":
			screen.condition_filter.select(index)
	screen._refresh_books()
	for _frame in range(5):
		await process_frame
	choices = condition_choices(screen.book_list)
	check(choices.size() == 1 and choices[0].get_meta("condition") == "raro", "Filtro de raros exibe o exemplar disponível")
	await screenshot("rare_stock_filtered")
	screen.condition_filter.select(0)
	screen.condition_filter.item_selected.emit(0)
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
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
