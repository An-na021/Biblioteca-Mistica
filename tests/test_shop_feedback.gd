extends SceneTree

const World = preload("res://scripts/shop_world.gd")
const Save = preload("res://scripts/save_game.gd")
var failures := 0
var test_path := "res://.godot/shop_feedback_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game: Node = preload("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.set_process(false)
	check(game.customer.visible and is_instance_valid(game.customer_transitions.arrival_actor), "Cliente chega pela porta sem mudar o estado lógico do atendimento")
	await create_timer(1.20).timeout
	check(game.customer_transitions.arrival_actor == null and game.customer.portrait.visible, "Entrada termina restaurando o retrato no balcão")
	var customer_id := str(game.customer.profile_data.id)
	game.world.memories[customer_id] = {"purchases": 2}
	var book_id := str(game.customer.requested_book_id)
	var condition := str(game.customer.profile_data.preferred_condition)
	game.inventory.add(book_id, 1, condition)
	var stock: int = game.inventory.get_condition_quantity(book_id, condition)
	var before: int = game.money
	var price := BookCatalog.price_for_condition(BookCatalog.get_book(book_id), condition, "sale_price")
	game._open_inventory()
	var inventory_screen: Control = game.active_overlay
	game._handle_stock_action(book_id, condition, "deliver", inventory_screen)
	check(game.money == before + price + 8 and game.inventory.get_condition_quantity(book_id, condition) == stock - 1 and game.day_manager.served_today == 1, "Compra mantém cobrança, estoque e avanço da fila uma única vez")
	check(game.sale_feedback.effects.has_node("SoldBook") and game.sale_feedback.get_node_or_null("DailyLedger") == null, "Venda mantém o livro em movimento sem escrever sobre o livro-caixa")
	check(not game.customer.visible and game.customer_transitions.departures.size() == 1, "Cliente atendido sai em uma transição visual independente")
	var feedback_stack: VBoxContainer = game.notifications.notification_stack
	var last_feedback := feedback_stack.get_child(feedback_stack.get_child_count() - 1) as Control
	check(game.get_node_or_null("ReaderKeepsakes") == null and int(game.world.memory(customer_id).purchases) == 3, "História continua avançando sem criar quadro de lembranças")
	game._handle_stock_action(book_id, condition, "deliver", inventory_screen)
	check(game.money == before + price + 8 and game.day_manager.served_today == 1, "Cliques repetidos não duplicam pagamentos nem atendimentos")
	game._save_checkpoint()
	var restored := World.new()
	restored.restore(Save.read_save(test_path).world)
	check(int(restored.memory(customer_id).purchases) == 3, "Salvamento conserva o progresso das histórias")
	await create_timer(1.9).timeout
	check(game.customer_transitions.departures.is_empty() and game.sale_feedback.effects.get_child_count() == 0, "Animações se limpam sem deixar textos permanentes sobre o cenário")
	await create_timer(1.65).timeout
	check(is_instance_valid(last_feedback) and last_feedback.modulate.a > 0.95, "Mensagem permanece legível depois do antigo prazo, com um segundo extra de leitura")
	await create_timer(0.95).timeout
	check(not is_instance_valid(last_feedback), "Mensagem desaparece ao terminar o novo prazo e a saída suave")
	game._begin_day()
	check(game.sale_feedback.get_node_or_null("DailyLedger") == null and game.get_node_or_null("ReaderKeepsakes") == null, "Novo expediente mantém as duas funcionalidades removidas")
	game.customer_transitions.finish_arrival()
	game._open_inventory()
	var rejected_id := "mar_vermelho" if game.customer.requested_book_id != "mar_vermelho" else "jardim_horas"
	game.customer.acceptable_book_ids.assign([game.customer.requested_book_id])
	condition = str(game.customer.profile_data.preferred_condition)
	game.inventory.add(rejected_id, 1, condition)
	game._handle_stock_action(rejected_id, condition, "deliver", game.active_overlay)
	check(game.sale_feedback.effects.get_child_count() == 0, "Oferta recusada não cria efeitos de compra")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
