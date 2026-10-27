extends SceneTree

const World = preload("res://scripts/shop_world.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const MainGame = preload("res://scripts/main_game.gd")
var failures := 0
var test_path := "res://.godot/world_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func reader(mood: String, tags: Array = ["natureza"], condition := "novo", context: Dictionary = {}) -> Customer:
	var node := Customer.new()
	root.add_child(node)
	node.configure({"id": "tom", "name": "Tom", "mood_type": mood, "preference_tags": tags, "preferred_condition": condition}, BookCatalog.get_book("mar_vermelho"), 0, context)
	node.acceptable_book_ids.clear()
	node.acceptable_book_ids.append("mar_vermelho")
	return node

func book(book_id: String, condition := "novo") -> Dictionary:
	var result := BookCatalog.get_book(book_id)
	result["condition"] = condition
	result["sale_price"] = BookCatalog.price_for_condition(result, condition, "sale_price")
	return result

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

func run() -> void:
	root.size = Vector2i(1280, 720)
	var hurried := reader("apressado")
	var undecided := reader("indeciso")
	var demanding := reader("dificil")
	check(hurried.patience_seconds() < demanding.patience_seconds() and demanding.patience_seconds() < undecided.patience_seconds(), "Personalidades alteram a paciência")
	check(hurried.offer_limit() == 2 and undecided.offer_limit() == 6, "Indeciso tolera mais sugestões que apressado")
	var nature := book("jardim_horas")
	var unrelated := book("relogio_perdido")
	check(float(undecided.recommendation_assessment(nature).chance) > float(demanding.recommendation_assessment(nature).chance), "Indeciso é mais aberto a recomendações compatíveis")
	check(float(undecided.recommendation_assessment(unrelated).chance) == 0.0, "Livro sem tema compatível é recusado")
	check(float(undecided.recommendation_assessment(book("mar_vermelho")).chance) == 1.0 and float(undecided.recommendation_assessment(book("mar_vermelho"), false).chance) == 0.0, "Dica de afinidade avalia os gostos sem revelar a solução do pedido")
	check(float(undecided.recommendation_assessment(book("jardim_horas", "danificado")).chance) == 0.0, "Condição inadequada impede recomendação")
	var rich_tags := reader("indeciso", ["natureza", "poesia", "alquimia"])
	check(float(rich_tags.recommendation_assessment(nature).chance) > float(undecided.recommendation_assessment(nature).chance), "Mais temas em comum aumentam o interesse")
	var cozy := reader("indeciso", ["natureza"], "novo", {"patience_bonus": 10.0, "recommendation_bonus": 0.06, "memory": {"purchases": 2}})
	check(cozy.patience_seconds() == undecided.patience_seconds() + 10.0 and float(cozy.recommendation_assessment(nature).chance) > float(undecided.recommendation_assessment(nature).chance), "Melhorias e confiança têm efeito real")
	check(not bool(hurried.react_to_offer(unrelated).get("completed", false)) and bool(hurried.react_to_offer(unrelated).get("completed", false)), "Apressado sai após duas sugestões recusadas")
	var collector := reader("colecionador", ["magia"], "raro")
	var bargainer := reader("negociador", ["magia"], "raro")
	var rare := book("mar_vermelho", "raro")
	check(collector.negotiation_limit(rare) > bargainer.negotiation_limit(rare), "Colecionador paga mais por raridades que negociador")
	var offer := bargainer.negotiate(rare, int(rare.sale_price) * 2)
	check(offer.has("counter_price") and not bool(offer.get("counts_as_error", true)) and not bargainer.served, "Preço alto gera contraproposta sem encerrar atendimento nem contar erro")
	var sale := bargainer.negotiate(rare, int(offer.counter_price))
	check(bool(sale.accepted) and int(sale.money) == int(offer.counter_price), "Aceitar contraproposta conclui pelo valor combinado")
	var stubborn := reader("negociador", ["viagem"], "raro")
	stubborn.negotiate(rare, 100)
	stubborn.negotiate(rare, 100)
	check(bool(stubborn.negotiate(rare, 100).get("completed", false)), "Três propostas excessivas fazem o cliente sair")
	var world := World.new()
	check(world.purchase("lighting", 0) == -1 and world.upgrades.is_empty(), "Melhoria exige saldo suficiente")
	check(world.purchase("lighting", 100) == 18 and world.purchase("lighting", 100) == -1, "Melhoria é cobrada uma vez")
	check(world.patience_bonus() == 10.0, "Luminária concede dez segundos")
	check(World.event_bonus(2, book("mar_vermelho")) > 0 and World.event_bonus(2, nature) == 0, "Evento de viagens beneficia apenas os temas anunciados")
	check(World.event_bonus(5, book("jardim_horas", "raro")) > 0 and World.event_bonus(5, nature) == 0, "Mostra de raridades exige exemplar raro")
	check(World.event_for_day(1).id == World.event_for_day(6).id, "Programação de eventos é previsível a cada cinco dias")
	world.record_visit("tom", 1)
	world.record_purchase("tom", "jardim_horas", "novo")
	world.create_order("tom", "inventario_chuva", "novo")
	check(world.pending_orders().size() == 1, "Primeira encomenda fica registrada")
	var ordered := reader("indeciso", ["natureza"], "raro", {"memory": world.memory("tom")})
	check(ordered.profile_data.preferred_condition == "novo" and ordered.requested_book_id == "inventario_chuva", "Encomenda preserva título e condição combinados na visita anterior")
	ordered.free()
	var wrong_condition := world.record_purchase("tom", "inventario_chuva", "usado")
	check(int(wrong_condition.order_reward) == 0 and world.pending_orders().size() == 1, "Encomenda não se conclui na condição errada")
	var chapter := world.record_purchase("tom", "inventario_chuva", "novo")
	check(int(chapter.order_reward) == 4 and int(chapter.story_reward) == 8 and world.pending_orders().is_empty(), "Encomenda e capítulo final concedem bônus previstos")
	check(int(world.record_purchase("tom", "inventario_chuva", "novo").reward) == 0, "Repetir compra não repete recompensa da história ou encomenda")
	var returning := reader("indeciso", ["natureza"], "novo", {"memory": world.memory("tom")})
	check(returning.get_greeting().contains("Inventario de Chuva"), "Cliente lembra o título realmente comprado")
	world.record_departure("tom")
	var disappointed := reader("indeciso", ["natureza"], "novo", {"memory": world.memory("tom")})
	check(disappointed.get_greeting().contains("saí sem uma leitura"), "Cliente lembra saída sem venda")
	for node in [hurried, undecided, demanding, rich_tags, cozy, collector, bargainer, stubborn, returning, disappointed]:
		node.free()
	var game := make_game()
	seed(120)
	game._start_new_game()
	game._set_relaxed_mode(true)
	await process_frame
	game.customer.profile_data.preferred_condition = "novo"
	game.customer.acceptable_book_ids.clear()
	game.customer.acceptable_book_ids.append("jardim_horas")
	game._open_inventory()
	var inventory_screen: InventoryScreen = game.active_overlay
	await screenshot("preview_recommendations")
	game._open_negotiation("jardim_horas", "novo", inventory_screen)
	var negotiation: Control = game.active_overlay
	await process_frame
	await process_frame
	check(negotiation.has_method("show_counter"), "Botão negociar abre tela de proposta")
	check(negotiation.price_input.size.y < 60 and negotiation.price_input.get_global_rect().end.y < 650, "Campo de preço permanece compacto dentro da janela")
	negotiation.proposed.emit(16)
	check(negotiation.counter_price > 0 and game.day_errors == 0 and game.day_sales_count == 0, "Contraproposta na interface mantém estoque e indicadores")
	await screenshot("preview_negotiation")
	negotiation.proposed.emit(negotiation.counter_price)
	check(game.day_sales_count == 1 and game.inventory.get_condition_quantity("jardim_horas", "novo") == 0, "Aceite pela interface vende exatamente um exemplar")
	await process_frame
	game._process(7.0)
	await process_frame
	game.inventory.add("jardim_horas", 1, "novo")
	game._open_inventory()
	game._open_negotiation("jardim_horas", "novo", game.active_overlay)
	game._set_relaxed_mode(false)
	game.customer_time_left = 0.1
	game._process(1.0)
	check(game.active_overlay == null and not game.customer.visible and game.inventory.get_condition_quantity("jardim_horas", "novo") == 1, "Tempo esgotado encerra negociação sem vender exemplar")
	game._set_relaxed_mode(true)
	await process_frame
	game._close_store(false)
	await process_frame
	await screenshot("preview_world_summary")
	var summary: DaySummaryScreen = game.active_overlay
	game.money = 100
	game._show_livraria(summary)
	var management: Control = game.active_overlay
	await process_frame
	management.purchase_requested.emit("lighting")
	management.purchase_requested.emit("shelves")
	management.purchase_requested.emit("plants")
	check(game.money == 42 and game.world.upgrades.size() == 3, "Comprar três melhorias desconta os preços corretos")
	management.purchase_requested.emit("plants")
	check(game.money == 42, "Duplo clique não recompra decoração")
	check(game.shop_decor.upgrades.size() == 3, "Melhorias são aplicadas à cena da livraria")
	await screenshot("preview_upgrades")
	management.tab_container.current_tab = 1
	await screenshot("preview_journal")
	var memories: Dictionary = game.world.memories.duplicate(true)
	game.queue_free()
	await process_frame
	game = make_game()
	game._continue_game()
	await process_frame
	check(game.world.upgrades.size() == 3 and game.world.memories == JSON.parse_string(JSON.stringify(memories)) and game.money == 42, "Salvamento preserva melhorias, encomendas e memória dos leitores")
	var pending: Array[Dictionary] = game.world.pending_orders()
	check(not pending.is_empty(), "Venda criou encomenda para uma visita futura")
	game._prepare_supplier_markets()
	var all_orders_available := true
	for order in pending:
		var entry: Dictionary = game.supplier_markets.praca.get(str(order.book_id), {})
		all_orders_available = all_orders_available and int(entry.get("conditions", {}).get(str(order.condition), {}).get("quantity", 0)) > 0
	check(all_orders_available, "Mercador da Praça oferece exemplares das encomendas pendentes")
	game.active_overlay.queue_free()
	game.active_overlay = null
	game._finish_day()
	await process_frame
	check(is_equal_approx(game.customer_time_limit, game.customer.patience_seconds()) and game.customer.extra_patience == 10.0, "Próximo expediente aplica bônus da luminária ao perfil sorteado")
	await screenshot("preview_decor")
	game._show_customer_profile()
	await process_frame
	await screenshot("preview_customer_profile")
	game.active_overlay.closed.emit()
	await process_frame
	# Play several complete days through real service, queues, events and summaries.
	var paid_orders := 0
	var completed_stories := 0
	for cycle in range(5):
		var total := int(game.day_manager.customers_today)
		for index in range(total):
			var customer: Customer = game.customer
			var target := str(customer.requested_book_id)
			var condition := str(customer.profile_data.preferred_condition)
			var before: Dictionary = game.world.memory(str(customer.profile_data.id))
			if before.has("order"):
				check(customer.request_mode == "encomenda" and target == str(before.order.book_id), "Cliente recorrente vem buscar a encomenda registrada")
				paid_orders += 1
			if int(before.get("purchases", 0)) == 2:
				completed_stories += 1
			if game.inventory.get_condition_quantity(target, condition) == 0:
				game.inventory.add(target, 1, condition)
			game._open_inventory()
			game._handle_stock_action(target, condition, "deliver", game.active_overlay)
			await process_frame
			game._process(7.0)
			await process_frame
		check(game.active_overlay is DaySummaryScreen and not game.store_is_open, "Ciclo completo fecha o dia e apresenta resumo")
		game.active_overlay.queue_free()
		game.active_overlay = null
		game._finish_day()
		await process_frame
	check(paid_orders > 0 and completed_stories > 0, "Vários dias concluem encomendas e histórias recorrentes")
	var legacy := SaveGame.read_save(test_path)
	legacy.erase("world")
	check(SaveGame.write_save(legacy, test_path) == OK and not SaveGame.read_save(test_path).is_empty(), "Formato anterior de salvamento continua legível")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
