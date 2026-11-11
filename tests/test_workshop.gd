extends SceneTree

const World = preload("res://scripts/shop_world.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const WorkshopUI = preload("res://scripts/workshop_screen.gd")
const RestorationInput = preload("res://tests/restoration_input.gd")
var failures := 0
var test_path := "res://.godot/workshop_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func make_game() -> Node:
	var game: Node = preload("res://scenes/main.tscn").instantiate()
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

func select_metadata(picker: OptionButton, value: String) -> void:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == value:
			picker.select(index)
			return
	check(false, "Opção não encontrada: " + value)

func condition_button(node: Node, condition: String) -> Button:
	if node is Button and str(node.get_meta("condition", "")) == condition:
		return node
	for child in node.get_children():
		var found := condition_button(child, condition)
		if found != null:
			return found
	return null

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game := make_game()
	check(not game.workshop_button.visible, "Ateliê não cobre o menu inicial")
	game._start_new_game()
	game._set_relaxed_mode(true)
	# Complete a real sale before opening the workshop, to detect replayed sales.
	var first_book := str(game.customer.requested_book_id)
	var first_condition := str(game.customer.profile_data.preferred_condition)
	game.inventory.add(first_book, 1, first_condition)
	game._open_inventory()
	game._handle_stock_action(first_book, first_condition, "deliver", game.active_overlay)
	game.day_manager.tick(10.0)
	game._set_relaxed_mode(false)
	game.customer_time_left = game.customer_time_limit - 7.0
	game.money = 200
	game._update_status()
	game.inventory.remove("jardim_horas", game.inventory.get_condition_quantity("jardim_horas", "raro"), "raro")
	game.inventory.add("jardim_horas", 1, "raro", 8)
	game.world.reserve_book("reserved_reader", "jardim_horas", "raro")
	await process_frame
	check(game.workshop_button.visible and game.workshop_button.get_global_rect().position.x < 30 and game.workshop_button.get_global_rect().end.y <= root.get_visible_rect().end.y, "Botão Ateliê fica no canto inferior esquerdo indicado")
	await screenshot("workshop_hud_button")
	var patience: float = game.customer_time_left
	var waiting: float = game.day_manager.waiting_seconds
	await click_control(game.workshop_button)
	check(game.active_overlay is WorkshopUI and paused and not game.game_menu.visible, "Clique no botão abre a sala e suspende o atendimento")
	var screen: Control = game.active_overlay
	game._process(60.0)
	check(is_equal_approx(game.customer_time_left, patience) and is_equal_approx(game.day_manager.waiting_seconds, waiting), "Tempo e fila não avançam no ateliê")
	check(root.get_visible_rect().encloses(screen.room.get_global_rect()) and not screen.detail_layer.visible and screen.selected_item == -1, "Ateliê abre no cômodo, sem catálogo ou ficha sobre o cenário")
	await screenshot("workshop_room")
	await click_control(screen.hotspots[1])
	check(screen.selected_item == 1 and screen.detail_layer.visible, "Clique na mesa do cenário abre somente as ações da restauração")
	await screenshot("workshop_table_install")
	await click_control(screen.room_button)
	check(not screen.detail_layer.visible and screen.selected_item == -1, "Voltar ao ateliê fecha a ficha sem sair do cômodo")
	await click_control(screen.hotspots[1])
	await click_control(screen.hotspots[2])
	check(not screen.detail_layer.visible and screen.selected_item == -1, "Clique fora da ficha fecha apenas a ficha, sem ativar outro móvel por baixo")
	var floor_click := InputEventMouseButton.new()
	floor_click.position = screen.room.get_global_transform_with_canvas() * Vector2(1100, 635)
	floor_click.button_index = MOUSE_BUTTON_LEFT
	floor_click.pressed = true
	root.push_input(floor_click)
	floor_click = floor_click.duplicate()
	floor_click.pressed = false
	root.push_input(floor_click)
	await process_frame
	check(not screen.detail_layer.visible, "Chão livre não ativa um móvel")
	var hover := InputEventMouseMotion.new()
	hover.position = screen.hotspots[1].get_global_rect().get_center()
	root.push_input(hover)
	await process_frame
	check(screen.hotspots[1].is_hovered() and screen.hotspots[1].tooltip_text.is_empty(), "Passar o mouse destaca a mesa sem legenda sobre o cenário")
	await screenshot("workshop_room_hover")
	hover = InputEventMouseMotion.new()
	hover.position = floor_click.position
	root.push_input(hover)
	await process_frame
	check(not screen.hotspots[1].is_hovered() and not screen.hotspots[1].has_focus(), "Destaque desaparece ao sair do móvel")
	await click_control(screen.hotspots[0])
	game.money = 0
	screen.refresh(0, game.day_manager.day)
	screen.purchase_requested.emit("orders_cabinet")
	screen.restoration_requested.emit("mar_vermelho")
	check(game.world.upgrades.is_empty() and game.money == 0 and screen.buy_button.disabled, "Saldo insuficiente e mesa não adquirida impedem ações sem efeitos colaterais")
	game.money = 200
	screen.refresh(200, game.day_manager.day)
	for index in range(3):
		screen.show_room()
		await click_control(screen.hotspots[index])
		check(screen.selected_item == index, "Clique no móvel abre suas próprias ações: " + str(WorkshopUI.ITEMS[index].name))
		await click_control(screen.buy_button)
		var paid: int = game.money
		screen.purchase_requested.emit(str(WorkshopUI.ITEMS[index].id))
		check(game.money == paid and game.world.upgrades.has(str(WorkshopUI.ITEMS[index].id)), "Compra é única para " + str(WorkshopUI.ITEMS[index].name))
	check(game.money == 128, "Três melhorias descontam 30, 10 e 32 moedas")
	check(game.world.available_for_customer(game.inventory, "jardim_horas", "raro", "other_reader") == 0, "Armário protege a última cópia de uma encomenda")
	check(game.world.available_for_customer(game.inventory, "jardim_horas", "raro", "reserved_reader") == 1, "Leitor da reserva pode retirar seu exemplar")
	game.world.reserve_book("second_reader", "jardim_horas", "raro")
	check(game.world.available_for_customer(game.inventory, "jardim_horas", "raro", "reserved_reader") == 1, "Reserva parcial de vários leitores não impede uma retirada válida")
	game.world.memories.erase("second_reader")
	screen.show_item(0)
	await screenshot("workshop_cabinet")
	screen.show_item(1)
	var damaged_before: int = game.inventory.get_condition_quantity("mar_vermelho", "danificado")
	var used_before: int = game.inventory.get_condition_quantity("mar_vermelho", "usado")
	var old_cost: int = game.inventory.get_unit_cost("mar_vermelho", "danificado")
	if OS.get_cmdline_user_args().has("--screenshots"):
		await click_control(screen.action_picker)
		await screenshot("workshop_restoration_picker")
		screen.action_picker.get_popup().hide()
	select_metadata(screen.action_picker, "mar_vermelho")
	screen.action_button.pressed.emit()
	var bench: Control = screen.restoration_bench
	check(bench != null and game.money == 128 and game.inventory.get_condition_quantity("mar_vermelho", "danificado") == damaged_before, "Abrir bancada não cobra materiais nem remove o livro")
	screen.restoration_requested.emit("mar_vermelho")
	check(game.money == 128 and game.inventory.get_condition_quantity("mar_vermelho", "danificado") == damaged_before, "Sinal de finalização antecipado não pula o trabalho na bancada")
	await screenshot("restoration_clean")
	await RestorationInput.stroke(self, bench, bench.CLEAN_SPOTS[0])
	await screenshot("restoration_dust_sweep")
	await RestorationInput.clean(self, bench)
	check(bench.stage == bench.Stage.GLUE and bench.selected_tool == 1, "Limpeza concluída avança automaticamente para aplicar cola")
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	root.push_input(cancel)
	await process_frame
	check(screen.restoration_bench == null and game.money == 128 and game.world.last_restoration_day == -1 and game.inventory.get_condition_quantity("mar_vermelho", "danificado") == damaged_before, "Cancelar trabalho parcial preserva moedas, exemplar e uso diário")
	screen.action_button.pressed.emit()
	bench = screen.restoration_bench
	await RestorationInput.clean(self, bench)
	await RestorationInput.dip_glue(self, bench)
	var rim: PackedVector2Array = bench._shape(0, bench.PATCH_TARGETS[0])
	await RestorationInput.move(self, bench, rim[0])
	await RestorationInput.button(self, bench, rim[0], true)
	for cell in range(1, 9):
		await RestorationInput.move(self, bench, rim[cell])
	await screenshot("restoration_wet_glue")
	await RestorationInput.button(self, bench, rim[8], false)
	await RestorationInput.glue(self, bench)
	check(bench.stage == bench.Stage.PATCH and bench.selected_tool == 2, "Cola nos três rasgos seleciona PAPEL e avança para o encaixe")
	await screenshot("restoration_glue")
	await RestorationInput.move(self, bench, bench.materials.paper_centers[0])
	await RestorationInput.button(self, bench, bench.materials.paper_centers[0], true)
	await RestorationInput.move(self, bench, Vector2(965, 410))
	await screenshot("restoration_paper_lifted")
	await RestorationInput.move(self, bench, bench.PATCH_TARGETS[0])
	await RestorationInput.button(self, bench, bench.PATCH_TARGETS[0], false)
	await create_timer(0.12).timeout
	await screenshot("restoration_paper_laid")
	await RestorationInput.drag_scrap(self, bench, 1, bench.PATCH_TARGETS[1], false)
	await RestorationInput.drag_scrap(self, bench, 2, bench.PATCH_TARGETS[2], false)
	await RestorationInput.move(self, bench, bench.PATCH_TARGETS[0])
	await RestorationInput.button(self, bench, bench.PATCH_TARGETS[0], true)
	await RestorationInput.move(self, bench, bench.PATCH_TARGETS[0] + Vector2(20, 0))
	await screenshot("restoration_paper_smoothing")
	await RestorationInput.button(self, bench, bench.PATCH_TARGETS[0] + Vector2(20, 0), false)
	await RestorationInput.patch(self, bench)
	await RestorationInput.sew(self, bench, 0, 4)
	await screenshot("restoration_sew")
	await RestorationInput.begin_stitch(self, bench, 4, bench.Sewing.INSERT_SECONDS * 0.35)
	await screenshot("restoration_needle_inserting")
	await create_timer(bench.Sewing.INSERT_SECONDS).timeout
	await RestorationInput.move(self, bench, bench.SEW_HOLES[4] + Vector2(-30, 0))
	await screenshot("restoration_thread_pulling")
	await RestorationInput.pull_stitch(self, bench, 4)
	await RestorationInput.sew(self, bench, 5)
	await screenshot("restoration_press")
	await RestorationInput.turn_press(self, bench, 1.25)
	await screenshot("restoration_press_turning")
	await RestorationInput.turn_press(self, bench, 0.75)
	await screenshot("restoration_press_closed")
	await create_timer(bench.Press.DRY_SECONDS + 0.4).timeout
	await screenshot("restoration_press_release")
	check(game.money == 128 and game.inventory.get_condition_quantity("mar_vermelho", "danificado") == damaged_before, "Aguardar secagem não cobra materiais nem entrega o livro preso na prensa")
	await RestorationInput.turn_press(self, bench, -bench.press.turns)
	check(game.money == 126 and game.inventory.get_condition_quantity("mar_vermelho", "danificado") == damaged_before - 1 and game.inventory.get_condition_quantity("mar_vermelho", "usado") == used_before + 1, "Restauro troca um danificado por usado e cobra 2 moedas")
	check(int(game.inventory.acquisition_costs.mar_vermelho.usado.back()) == old_cost + 2, "Materiais do restauro entram no custo do exemplar")
	screen.restoration_requested.emit("inventario_chuva")
	check(game.money == 126 and screen.action_button.disabled, "Restauro diário não pode ser repetido por clique ou sinal duplicado")
	await screenshot("restoration_finished")
	await click_control(bench.back_button)
	await screenshot("workshop_restoration")
	screen.show_item(2)
	select_metadata(screen.action_picker, "magia")
	screen.action_button.pressed.emit()
	check(game.world.display_theme == "magia" and game.money == 126, "Vitrine grava o tema escolhido sem cobrar novamente")
	var pool: Array[Dictionary] = BookCatalog.all_books()
	var displayed: Array[Dictionary] = game.world.request_pool(pool, 1, "novo", 0.0, 1.0)
	check(not displayed.is_empty() and displayed.all(func(entry: Dictionary) -> bool: return entry.tags.has("magia")), "Vitrine favorece apenas livros compatíveis com o tema")
	var nature_only: Array[Dictionary] = [BookCatalog.get_book("floresta_azul")]
	check(game.world.request_pool(nature_only, 1, "novo", 0.0, 1.0) == nature_only, "Tema não substitui os gostos ou títulos disponíveis do leitor")
	check(not game.world.set_display_theme("tema_inexistente"), "Tema inválido é recusado")
	await screenshot("workshop_display")
	root.size = Vector2i(360, 600)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(screen.room.get_global_rect()) and screen.room.get_global_rect().encloses(screen.detail_panel.get_global_rect()), "Cômodo e ações cabem em janela estreita")
	root.size = Vector2i(1280, 720)
	await process_frame
	var saved := SaveGame.read_save(test_path)
	var saved_customer := str(game.customer.profile_data.id)
	var saved_clue: Dictionary = game.customer.request_clue.duplicate(true)
	var saved_patience: float = game.customer_time_left
	check(saved.active_day.served == 1 and int(saved.money) == 126 and saved.world.display_theme == "magia", "Ateliê salva compras junto ao ponto atual do expediente")
	game.queue_free()
	await process_frame
	game = make_game()
	game._continue_game()
	game.set_process(false)
	check(game.world.upgrades.size() == 3 and game.money == 126 and game.world.last_restoration_day == game.day_manager.day and game.world.display_theme == "magia", "Continuar preserva melhorias, moedas, limite de restauro e tema")
	check(game.day_manager.served_today == 1 and game.day_sales_count == 1 and str(game.customer.profile_data.id) == saved_customer and game.customer.request_clue == saved_clue and is_equal_approx(game.customer_time_left, saved_patience), "Continuar retoma o mesmo leitor sem repetir vendas ou reiniciar a paciência")
	game._open_inventory()
	var inventory_screen: InventoryScreen = game.active_overlay
	var rare_choice := condition_button(inventory_screen.book_list, "raro")
	check(rare_choice != null, "Raro reservado continua visível no estoque")
	if rare_choice != null:
		rare_choice.button_pressed = true
		rare_choice.button_group.pressed.emit(rare_choice)
		check(find_button(inventory_screen.book_list.get_child(0), "ENTREGAR").disabled and find_button(inventory_screen.book_list.get_child(0), "NEGOCIAR").disabled, "Estoque desativa ações sobre a cópia protegida")
	var stock_before: int = game.inventory.get_condition_quantity("jardim_horas", "raro")
	var money_before: int = game.money
	game._handle_stock_action("jardim_horas", "raro", "deliver", inventory_screen)
	check(game.active_overlay == inventory_screen and game.money == money_before and game.inventory.get_condition_quantity("jardim_horas", "raro") == stock_before, "Entrega comum não consome o exemplar guardado para outro leitor")
	inventory_screen.closed.emit()
	await process_frame
	game._open_workshop()
	screen = game.active_overlay
	screen.show_item(1)
	check(screen.action_button.disabled, "Reabrir o jogo não libera outro restauro no mesmo dia")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(game.active_overlay == screen and paused and not screen.detail_layer.visible, "Primeiro Esc fecha apenas a ficha do móvel")
	escape = escape.duplicate()
	root.push_input(escape)
	await process_frame
	check(game.active_overlay == null and not paused and not game.game_menu.overlay.visible, "Esc fecha o ateliê e retoma a livraria sem abrir a pausa")
	# Saving between customers must preserve the queue, not recreate a sold book.
	var book_id := str(game.customer.requested_book_id)
	var condition := str(game.customer.profile_data.preferred_condition)
	var needed := maxi(1, game.world.reserved_quantity(book_id, condition) + 1 - game.inventory.get_condition_quantity(book_id, condition))
	game.inventory.add(book_id, needed, condition)
	game._open_inventory()
	game._handle_stock_action(book_id, condition, "deliver", game.active_overlay)
	check(not game.customer.visible and game.day_manager.served_today == 2, "Segundo atendimento termina antes de salvar a espera no ateliê")
	game._open_workshop()
	game.active_overlay.theme_requested.emit("")
	var waiting_balance: int = game.money
	var waiting_stock: Dictionary = game.inventory.condition_quantities.duplicate(true)
	var waiting_seen: Array = game.customer_ids_seen_today.duplicate()
	game.queue_free()
	await process_frame
	game = make_game()
	game._continue_game()
	game.set_process(false)
	check(not game.customer.visible and game.day_manager.waiting_for_next and game.day_manager.served_today == 2 and game.money == waiting_balance and game.inventory.condition_quantities == JSON.parse_string(JSON.stringify(waiting_stock)), "Continuar durante a espera preserva fila, estoque e dinheiro")
	game.day_manager.tick(game.day_manager.waiting_seconds + 0.1)
	check(game.customer.visible and not waiting_seen.has(str(game.customer.profile_data.id)), "Fila retomada chama o próximo leitor sem repetir os anteriores")
	var edge_world := World.new()
	var edge_inventory := Inventory.new()
	edge_world.purchase("restoration_table", 100)
	edge_world.purchase("orders_cabinet", 100)
	edge_world.reserve_book("damaged_reader", "inventario_chuva", "danificado")
	check(edge_world.restore_book(edge_inventory, "inventario_chuva", 1, 100) == -1, "Mesa não restaura a cópia danificada que está reservada")
	edge_world.memories.clear()
	check(edge_world.restore_book(edge_inventory, "inventario_chuva", 1, 1) == -1 and edge_world.last_restoration_day == -1, "Materiais insuficientes não gastam o uso diário")
	check(edge_world.restore_book(edge_inventory, "inventario_chuva", 1, 2) == 2 and edge_world.restore_book(edge_inventory, "mar_vermelho", 2, 2) == 2, "Novo expediente libera uma restauração novamente")
	game.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
