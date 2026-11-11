extends SceneTree

const SaveGame = preload("res://scripts/save_game.gd")
var failures := 0
var test_path := "res://.godot/order_purchase_test_%d.json" % Time.get_ticks_usec()

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

func reservation(shop: MerchantScreen, condition: String) -> Label:
	var row := shop.book_list.get_node("Book_jardim_horas")
	return row.find_child("Reservation_" + condition, true, false) as Label

func selected_condition(shop: MerchantScreen) -> String:
	var picker: OptionButton = shop.book_list.get_node("Book_jardim_horas/Condition")
	return str(picker.get_item_metadata(picker.selected))

func buy_selected(shop: MerchantScreen) -> void:
	var button: Button = shop.book_list.get_node("Book_jardim_horas/Buy")
	button.pressed.emit()
	await process_frame
	await process_frame

func screenshot(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game := make_game()
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.inventory.condition_quantities.clear()
	game.inventory.acquisition_costs.clear()
	game.world.reserve_book("professor_bigodes", "jardim_horas", "novo")
	game.world.reserve_book("tom", "jardim_horas", "novo")
	game.world.reserve_book("mestre_elian", "jardim_horas", "raro")
	game._close_store(false)
	game.money = 100
	game.supplier_markets = {
		"caravana": {"jardim_horas": {"quantity": 4, "conditions": {"novo": {"quantity": 1, "price": 3}, "raro": {"quantity": 1, "price": 8}, "usado": {"quantity": 2, "price": 2}}, "risk": 1.0}},
		"praca": {"jardim_horas": {"quantity": 2, "conditions": {"novo": {"quantity": 2, "price": 5}}, "risk": 1.0}}
	}
	game._show_shop(game.active_overlay)
	var shop: MerchantScreen = game.active_overlay
	await process_frame
	check(selected_condition(shop) == "novo", "Compra começa pela condição pendente da reserva")
	check(shop.book_list.get_node("Book_jardim_horas/Buy").tooltip_text.contains("sem risco de avaria"), "Botão informa a garantia da condição para encomendas")
	await buy_selected(shop)
	check(game.inventory.get_condition_quantity("jardim_horas", "novo") == 1 and game.inventory.get_condition_quantity("jardim_horas", "danificado") == 0 and game.money == 97, "Compra de encomenda entrega a condição exata, cobra uma vez e não sofre avaria")
	var new_note := reservation(shop, "novo")
	check(new_note != null and new_note.text.contains("comprar 1") and new_note.get_theme_color("font_color") == MerchantScreen.MUTED, "Dois leitores exigem duas cópias; compra parcial permanece pendente")
	await buy_selected(shop)
	check(game.inventory.get_condition_quantity("jardim_horas", "novo") == 2 and game.money == 92, "Segunda compra usa o próximo fornecedor e completa a quantidade reservada")
	new_note = reservation(shop, "novo")
	check(new_note != null and new_note.text.contains("pronto para entregar") and new_note.get_theme_color("font_color") == MerchantScreen.GREEN, "Reserva completa fica verde imediatamente")
	check(selected_condition(shop) == "raro", "Depois de completar Novo, menu seleciona a encomenda Raro ainda pendente")
	await buy_selected(shop)
	var rare_note := reservation(shop, "raro")
	check(game.inventory.get_condition_quantity("jardim_horas", "raro") == 1 and game.money == 84 and shop._missing_reservation_count() == 0, "Todas as encomendas são compradas nas condições e quantidades corretas")
	check(rare_note != null and rare_note.text.contains("pronto para entregar") and rare_note.get_theme_color("font_color") == MerchantScreen.GREEN, "Reserva rara também fica verde sem reabrir a loja")
	check(game.world.pending_orders().size() == 3, "Comprar deixa encomendas prontas sem simular entrega aos leitores")
	check(not shop.book_list.get_node("Book_jardim_horas/Buy").tooltip_text.contains("sem risco de avaria"), "Garantia da encomenda termina quando todas as cópias necessárias estão no estoque")
	await screenshot("order_purchases_ready")
	await buy_selected(shop)
	check(game.inventory.get_condition_quantity("jardim_horas", "danificado") == 1 and game.money == 79 and shop._missing_reservation_count() == 0, "Compra comum mantém risco de avaria e não altera reservas prontas")
	game.money = 0
	var stock: Dictionary = game.inventory.condition_quantities.duplicate(true)
	await buy_selected(shop)
	check(game.money == 0 and game.inventory.condition_quantities == stock, "Saldo insuficiente impede cobrança e entrada de exemplar")
	game.money = 79
	game._save_checkpoint()
	var saved := SaveGame.read_save(test_path)
	check(int(saved.inventory.get("jardim_horas", {}).get("novo", 0)) == 2 and int(saved.inventory.get("jardim_horas", {}).get("raro", 0)) == 1 and int(saved.money) == 79, "Salvamento registra todas as compras e o saldo correto")
	game.queue_free()
	await process_frame
	game = make_game()
	game._continue_game()
	game._show_shop(game.active_overlay)
	shop = game.active_overlay
	await process_frame
	new_note = reservation(shop, "novo")
	rare_note = reservation(shop, "raro")
	check(shop._missing_reservation_count() == 0 and new_note != null and rare_note != null and new_note.get_theme_color("font_color") == MerchantScreen.GREEN and rare_note.get_theme_color("font_color") == MerchantScreen.GREEN, "Carregar partida mantém todas as reservas prontas e verdes")
	shop.closed.emit()
	game.active_overlay.queue_free()
	game.active_overlay = null
	game.set_process(false)
	for customer_id in ["professor_bigodes", "tom", "mestre_elian"]:
		game._on_customer_ready(1, 3)
		var profile: Dictionary = game.customer.profile_data.duplicate(true)
		profile.id = customer_id
		game.customer.configure(profile, BookCatalog.get_book("mar_vermelho"), game.reputation, {"memory": game.world.memory(customer_id)})
		var condition := str(game.customer.profile_data.preferred_condition)
		game.store_is_open = true
		game.customer.show()
		game._open_inventory()
		game._handle_stock_action("jardim_horas", condition, "deliver", game.active_overlay)
		check(not game.world.memory(customer_id).has("order") and bool(game.world.memory(customer_id).get("order_completed", false)), "Encomenda é entregue sem gerar outro pedido automático para " + customer_id)
	check(game.world.pending_orders().is_empty() and game.inventory.get_condition_quantity("jardim_horas", "novo") == 0 and game.inventory.get_condition_quantity("jardim_horas", "raro") == 0, "Todas as encomendas foram entregues e cada exemplar foi removido uma única vez")
	game.queue_free()
	await process_frame
	# Exercise every supported condition with a supplier that always damages
	# ordinary purchases, including the case of an intentionally damaged order.
	game = make_game()
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.inventory.condition_quantities.clear()
	game.inventory.acquisition_costs.clear()
	var condition_stock: Dictionary = {}
	for condition in BookCatalog.CONDITIONS:
		game.world.reserve_book("reader_" + str(condition), "jardim_horas", str(condition))
		condition_stock[condition] = {"quantity": 1, "price": 2}
	game._close_store(false)
	game.money = 100
	game.supplier_markets = {"praca": {"jardim_horas": {"quantity": 4, "conditions": condition_stock, "risk": 1.0}}}
	game._show_shop(game.active_overlay)
	shop = game.active_overlay
	for condition in BookCatalog.CONDITIONS:
		check(selected_condition(shop) == str(condition), "Menu prioriza encomenda pendente na condição " + str(condition))
		await buy_selected(shop)
		var note := reservation(shop, str(condition))
		check(game.inventory.get_condition_quantity("jardim_horas", str(condition)) == 1 and note != null and note.get_theme_color("font_color") == MerchantScreen.GREEN, "Compra da condição " + str(condition) + " entra no estoque e fica verde")
	check(game.money == 92 and shop._missing_reservation_count() == 0, "Novo, usado, danificado e raro completam todas as encomendas com cobrança exata")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
