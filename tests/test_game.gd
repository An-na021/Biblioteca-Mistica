extends SceneTree

const SaveGame = preload("res://scripts/save_game.gd")
var failures := 0
var test_path := "res://.godot/test_save_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

func make_game() -> Node:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	return game

func screenshot(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func click_control(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game := make_game()
	await process_frame
	check(paused and game.customer == null, "Menu inicial impede atendimento antes de iniciar")
	check(game.game_menu.continue_button.disabled, "Continuar indisponível sem salvamento")
	check(root.get_visible_rect().encloses(game.game_menu.start_menu.book.get_global_rect()), "Livro do menu inicial cabe na janela")
	game.game_menu.note.text += "\nUsando o catálogo local."
	await screenshot("preview_menu")
	await click_control(game.game_menu.new_button)
	await process_frame
	check(not paused and game.customer != null, "Novo jogo inicia o primeiro cliente")
	var opening := SaveGame.read_save(test_path)
	check(not opening.is_empty() and int(opening.day) == 1, "Salvamento da abertura gravado")
	game.game_menu.toggle_pause()
	var remaining: float = game.customer_time_left
	await create_timer(0.1, true).timeout
	check(is_equal_approx(remaining, game.customer_time_left), "Pausa congela a paciência")
	await screenshot("preview_pause")
	await click_control(game.game_menu.pause_book.active_button)
	check(paused and game.relaxed_mode and game.game_menu.pause_book.active_button.button_pressed, "Ativado liga o modo tranquilo sem sair da pausa")
	await screenshot("preview_pause_enabled")
	await click_control(game.game_menu.pause_book.inactive_button)
	check(paused and not game.relaxed_mode and game.game_menu.pause_book.inactive_button.button_pressed, "Desativado restaura o limite de tempo sem sair da pausa")
	root.size = Vector2i(720, 1000)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(game.game_menu.pause_book.book.get_global_rect()), "Livro da pausa cabe em uma janela vertical")
	await screenshot("preview_pause_portrait")
	root.size = Vector2i(1280, 720)
	await process_frame
	await click_control(game.game_menu.resume_button)
	check(not paused and not game.game_menu.overlay.visible, "Retomar fecha o livro e continua o atendimento")
	game.game_menu.toggle_pause()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(not paused and not game.game_menu.overlay.visible, "Esc retoma o jogo com o novo menu")
	game._set_relaxed_mode(true)
	remaining = game.customer_time_left
	await create_timer(0.1, true).timeout
	check(is_equal_approx(remaining, game.customer_time_left) and not game.mood_timer.visible, "Modo tranquilo desativa contagem e relógio")
	game._set_relaxed_mode(false)
	game._open_inventory()
	var screen: InventoryScreen = game.active_overlay
	await process_frame
	check(not game.game_menu.pause_button.visible, "Estoque usa apenas o botão de pausa do livro")
	screen.pause_requested.emit()
	check(paused and game.game_menu.overlay.visible, "Botão de pausa do livro abre o menu")
	game.game_menu.toggle_pause()
	check(screen.preferred_condition == game.customer.profile_data.preferred_condition, "Estoque mostra a condição preferida")
	check(screen.time_label.text.begins_with("TEMPO"), "Estoque mantém o tempo restante visível")
	screen.search_input.text = "JÁRDIM"
	check(screen.filtered_books().size() == 1, "Busca por título ignora acentos e caixa")
	screen.search_input.text = "L. Duarte"
	check(screen.filtered_books().size() == 1, "Busca por autor")
	screen.search_input.text = ""
	for index in range(screen.condition_filter.item_count):
		if screen.condition_filter.get_item_metadata(index) == "raro":
			screen.condition_filter.select(index)
	var matches := screen.filtered_books()
	check(matches.size() == 1 and matches[0].conditions.size() == 1 and matches[0].conditions[0].condition == "raro", "Filtro limita títulos e exemplares à condição selecionada")
	for index in range(screen.theme_filter.item_count):
		if screen.theme_filter.get_item_metadata(index) == "mapas":
			screen.theme_filter.select(index)
	check(screen.filtered_books().is_empty(), "Filtros combinados mostram ausência de resultados")
	screen.theme_filter.select(0)
	screen.condition_filter.select(0)
	screen._refresh_books()
	await screenshot("preview_inventory")
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	var inventory_panel := screen.get_child(1) as Control
	check(inventory_panel.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().size * 0.5), "Estoque permanece centralizado em janela maior")
	var status_panel := game.get_node("UI/StatusPanel") as Control
	check(not status_panel.get_global_rect().intersects(game.mood_timer.get_global_rect()), "Relógio não sobrepõe o painel de status")
	root.size = Vector2i(1280, 720)
	await process_frame
	game.customer.profile_data.preferred_condition = "usado"
	game.customer.acceptable_book_ids.clear()
	game.customer.acceptable_book_ids.append("jardim_horas")
	game._handle_stock_action("mar_vermelho", "usado", "deliver", screen)
	check(game.day_errors == 1 and game.progression.daily_errors == 1 and game.day_failed_customers == 0, "Recusa contabiliza erro sem contar cliente perdido")
	game._open_inventory()
	game._handle_stock_action("jardim_horas", "usado", "deliver", game.active_overlay)
	check(game.day_sales_count == 1 and game.day_errors == 1, "Venda após recusa preserva o total de erros")
	game._set_relaxed_mode(true)
	var saved := SaveGame.read_save(test_path)
	check(int(saved.money) == 0 and int(saved.inventory.jardim_horas.usado) == 1, "Alterar preferência preserva checkpoint de abertura")
	game.queue_free()
	await process_frame
	game = make_game()
	check(not game.game_menu.continue_button.disabled, "Continuar disponível após salvar")
	game.game_menu._request_new_game()
	check(game.game_menu.confirmation.visible, "Novo jogo pede confirmação ao substituir progresso")
	game.game_menu.confirmation.hide()
	game.game_menu.note.text += "\nUsando o catálogo local."
	await screenshot("preview_menu_continue")
	await click_control(game.game_menu.continue_button)
	await process_frame
	check(game.money == 0 and game.inventory.get_condition_quantity("jardim_horas", "usado") == 1 and game.relaxed_mode, "Continuar reinicia dia aberto sem duplicar dinheiro ou perder estoque")
	game.money = 100
	game.progression.record_purchase("praca")
	game.progression.record_district_visit("bosque")
	game.progression.record_reputation(5)
	game.progression.daily_sales = game.progression.daily_customer_target
	game.day_sales_count = game.progression.daily_customer_target
	game.day_customers_served = game.day_sales_count
	game.day_sales_revenue = 24
	game.day_profit = 9
	game.day_manager.customers_today = 4
	game._close_store(true)
	await process_frame
	var closing_money: int = game.money
	check(closing_money > 100, "Fechamento concede recompensa de meta concluída")
	var summary: DaySummaryScreen = game.active_overlay
	game._show_shop(summary)
	await process_frame
	var shop: MerchantScreen = game.active_overlay
	var chosen_id: String = game.merchant_offers.keys()[0]
	var conditions: Dictionary = game.merchant_offers[chosen_id].conditions
	var chosen_condition: String = conditions.keys()[0]
	var price := int(conditions[chosen_condition].price)
	shop.purchase_requested.emit(chosen_id, chosen_condition)
	await process_frame
	check(game.money == closing_money - price, "Compra desconta preço e salva no fechamento")
	var stock: Dictionary = game.inventory.condition_quantities.duplicate(true)
	var costs: Dictionary = game.inventory.acquisition_costs.duplicate(true)
	var markets: Dictionary = game.supplier_markets.duplicate(true)
	var saved_money: int = game.money
	game.queue_free()
	await process_frame
	game = make_game()
	game._continue_game()
	await process_frame
	check(not game.store_is_open and game.active_overlay is DaySummaryScreen and game.money == saved_money, "Continuar fechamento não repete recompensas")
	check(game.inventory.condition_quantities == JSON.parse_string(JSON.stringify(stock)) and game.inventory.acquisition_costs == JSON.parse_string(JSON.stringify(costs)), "Estoque e custos de aquisição sobrevivem ao carregamento")
	check(game.supplier_markets == JSON.parse_string(JSON.stringify(markets)) and game.progression.total_purchases == 2 and game.progression.unlocked_achievements.has("reputation_5"), "Ofertas, progressão e conquistas são preservadas")
	await screenshot("preview_summary")
	game.active_overlay.queue_free()
	game.active_overlay = null
	game._finish_day()
	await process_frame
	check(game.day_manager.day == 2 and game.day_errors == 0 and game.day_sales_count == 0, "Dia seguinte reinicia indicadores antes do atendimento")
	game.game_menu.toggle_pause()
	game.day_manager.waiting_for_next = true
	game.day_manager.waiting_seconds = 4.0
	await create_timer(0.1, true).timeout
	check(is_equal_approx(game.day_manager.waiting_seconds, 4.0), "Pausa congela a chegada do próximo cliente")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	var invalid := FileAccess.open(test_path, FileAccess.WRITE)
	invalid.store_string("{broken")
	invalid.close()
	check(SaveGame.read_save(test_path).is_empty(), "Salvamento corrompido é recusado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
