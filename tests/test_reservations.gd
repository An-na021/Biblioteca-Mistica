extends SceneTree

const World = preload("res://scripts/shop_world.gd")
const SaveGame = preload("res://scripts/save_game.gd")
var failures := 0
var test_path := "res://.godot/reservations_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

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

func has_text(node: Node, text: String) -> bool:
	if node is Label and node.text.contains(text):
		return true
	for child in node.get_children():
		if has_text(child, text):
			return true
	return false

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.to_upper().begins_with(prefix.to_upper()):
		return node
	for child in node.get_children():
		var found := find_button(child, prefix)
		if found != null:
			return found
	return null

func run() -> void:
	root.size = Vector2i(1280, 720)
	var world := World.new()
	check(not world.reserve_book("tom", "inexistente", "novo") and not world.reserve_book("tom", "reino_vidro", "invalida"), "Reserva exige livro e condição válidos")
	check(world.reserve_book("tom", "reino_vidro", "raro"), "Leitor pode reservar antes da primeira compra")
	world.reserve_book("tom", "reino_vidro", "raro")
	check(world.pending_orders().size() == 1 and str(world.pending_orders()[0].customer_id) == "tom", "Reserva repetida não duplica pedido e identifica o leitor")
	check(not world.reserve_book("tom", "jardim_horas", "novo") and not world.create_order("tom", "jardim_horas", "novo"), "Reserva pendente não é substituída por outra encomenda")
	check(int(world.record_purchase("tom", "reino_vidro", "novo").order_reward) == 0 and world.pending_orders().size() == 1, "Condição errada mantém a reserva")
	check(int(world.record_purchase("tom", "reino_vidro", "raro").order_reward) == 4 and world.pending_orders().is_empty(), "Entrega na condição reservada conclui o pedido uma vez")
	check(world.reserve_book("tom", "jardim_horas", "novo"), "Cliente pode fazer nova reserva após receber a anterior")

	var game := make_game()
	game._start_new_game()
	game._set_relaxed_mode(true)
	await process_frame
	game.customer.requested_book_id = "reino_vidro"
	game.customer.acceptable_book_ids.assign(["reino_vidro"])
	game.customer.profile_data.preferred_condition = "raro"
	game.customer.request_clue = {"type": "titulo", "text": "Procuro O Reino de Vidro em uma edição rara."}
	game.inventory.condition_quantities.clear()
	game.inventory.acquisition_costs.clear()
	game.inventory.add("reino_vidro", 1, "novo")
	check(game.customer.can_reserve(game.inventory), "Outro estado de conservação não impede reservar a condição solicitada")
	game.inventory.add("reino_vidro", 1, "raro")
	check(not game.customer.can_reserve(game.inventory), "Livro disponível na condição certa deve ser atendido em vez de reservado")
	game.inventory.remove("reino_vidro", 1, "raro")
	game.customer.acceptable_book_ids.append("jardim_horas")
	game.inventory.add("jardim_horas", 1, "raro")
	check(not game.customer.can_reserve(game.inventory), "Pedidos por pista consideram todos os títulos que atendem à pista")
	game.customer.acceptable_book_ids.assign(["reino_vidro"])
	game._open_inventory()
	var screen: InventoryScreen = game.active_overlay
	await process_frame
	check(screen.reserve_button != null, "Estoque oferece ação de reservar mesmo sem exemplares do pedido")
	await screenshot("preview_reservation_inventory")
	var customer_id: String = game.customer.profile_data.id
	var customer_name: String = game.customer.customer_name
	var balance: int = game.money
	var reputation: int = game.reputation
	screen.reserve_button.pressed.emit()
	game._reserve_customer_book(screen)
	check(game.world.pending_orders().size() == 1 and not game.customer.visible and game.day_manager.served_today == 1, "Reservar encerra atendimento uma única vez e avança a fila")
	check(game.money == balance and game.reputation == reputation and game.day_errors == 0 and game.day_failed_customers == 0 and game.day_sales_count == 0, "Reserva não cobra moedas, registra venda ou penaliza reputação")
	await process_frame
	game._close_store(false)
	await process_frame
	var saved := SaveGame.read_save(test_path)
	check(str(saved.world.memories[customer_id].order.book_id) == "reino_vidro", "Fechamento salva reservas junto ao progresso")
	var summary: DaySummaryScreen = game.active_overlay
	game.money = 200
	# Two readers need the same condition; a different condition must not count.
	var other_id := "tom" if customer_id != "tom" else "lyria"
	game.world.reserve_book(other_id, "reino_vidro", "raro")
	game._prepare_supplier_markets()
	for supplier_market in game.supplier_markets.values():
		for offer in supplier_market.values():
			offer.risk = 0.0
	var market: Dictionary = game.supplier_markets.praca
	check(int(market.reino_vidro.conditions.raro.quantity) >= 2, "Fornecedor inclui exemplares suficientes para vários leitores da mesma reserva")
	game._show_shop(summary)
	var shop: MerchantScreen = game.active_overlay
	await process_frame
	check(shop.book_list.get_child_count() == BookCatalog.all_books().size() and shop._missing_reservation_count() == 2 and has_text(shop, customer_name), "Lista única mostra todos os livros e mantém leitor e condição da reserva")
	check(find_button(shop, "RESERVAS DOS CLIENTES") == null and find_button(shop, "Mercador da Praça") == null, "Loja dispensa abas e menu de fornecedores")
	await screenshot("preview_reservations_shop")
	var panel := shop.get_child(1) as Control
	check(root.get_visible_rect().encloses(panel.get_global_rect()), "Painel de compras cabe na janela de 1280 por 720")
	var buy := find_button(shop, "COMPRAR")
	check(buy != null and buy.size.y < 60, "Ação de compra permanece compacta no cartão")
	# Buying one reserved copy updates the deficit without clearing a reader's order.
	game.supplier_markets.praca.reino_vidro.risk = 0.0
	buy.pressed.emit()
	await process_frame
	check(game.inventory.get_condition_quantity("reino_vidro", "raro") == 1 and shop._missing_reservation_count() == 1 and game.world.pending_orders().size() == 2, "Compra seleciona a condição reservada e reduz a pendência sem concluir entrega")
	find_button(shop, "COMPRAR").pressed.emit()
	await process_frame
	check(shop._missing_reservation_count() == 0 and has_text(shop, "pronto para entregar"), "Reservas ficam prontas quando há exemplares suficientes")
	await screenshot("preview_reservations_ready")
	check(shop.book_list.get_child_count() == BookCatalog.all_books().size(), "Compras preservam todos os livros na mesma lista")
	await screenshot("preview_reservations_all_books")
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	panel = shop.get_child(1) as Control
	check(root.get_visible_rect().encloses(panel.get_global_rect()), "Loja se adapta à janela maior")
	root.size = Vector2i(1280, 720)
	shop.closed.emit()
	await process_frame
	game.queue_free()
	await process_frame
	game = make_game()
	game._continue_game()
	await process_frame
	check(game.world.pending_orders().size() == 2 and game.inventory.get_condition_quantity("reino_vidro", "raro") == 2, "Continuar recupera reservas e exemplares comprados")
	game.active_overlay.queue_free()
	game.active_overlay = null
	game._on_customer_ready(1, game.day_manager.customers_today)
	var profile: Dictionary = game.customer.profile_data.duplicate(true)
	profile.id = customer_id
	game.customer.configure(profile, BookCatalog.get_book("jardim_horas"), game.reputation, {"memory": game.world.memory(customer_id)})
	check(game.customer.request_mode == "encomenda" and game.customer.requested_book_id == "reino_vidro" and game.customer.profile_data.preferred_condition == "raro", "Visita seguinte solicita o título e a condição reservados")
	game.store_is_open = true
	game.customer.visible = true
	game._open_inventory()
	check(game.active_overlay.reserve_button == null, "Reserva disponível para retirada não oferece outra reserva")
	game._handle_stock_action("reino_vidro", "raro", "deliver", game.active_overlay)
	check(not game.world.memory(customer_id).has("order") or str(game.world.memory(customer_id).order.book_id) != "reino_vidro", "Entregar exemplar reservado remove a pendência daquele leitor")
	# Catalogs without a designated special-order supplier still have a source.
	game.supplier_profiles.assign([{"id": "custom", "name": "Livreiro", "price_factor": 1.2, "risk": 0.0, "tags": [], "special_orders": false}])
	game.current_district_id = "centro"
	game.world.reserve_book("external", "ultimo_dragao", "raro")
	game.world.reserve_book("external2", "ultimo_dragao", "raro")
	game.inventory.add("ultimo_dragao", 1, "raro")
	var custom: Dictionary = game._make_merchant_offers(game.supplier_profiles[0])
	check(custom.has("ultimo_dragao") and int(custom.ultimo_dragao.conditions.raro.quantity) == 1, "Fornecedor personalizado fornece reserva fora do bairro e desconta os exemplares já no estoque")
	check(int(custom.ultimo_dragao.conditions.raro.price) == maxi(1, roundi(float(BookCatalog.price_for_condition(BookCatalog.get_book("ultimo_dragao"), "raro", "buy_price")) * 1.2)), "Reserva usa o preço configurado do fornecedor personalizado")
	var empty_shop := MerchantScreen.new()
	root.add_child(empty_shop)
	empty_shop.setup(game.inventory, {}, 0)
	await process_frame
	check(empty_shop.book_list.get_child_count() == BookCatalog.all_books().size() and has_text(empty_shop, "Indisponível hoje"), "Catálogo continua visível mesmo sem ofertas ou reservas")
	empty_shop.queue_free()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
