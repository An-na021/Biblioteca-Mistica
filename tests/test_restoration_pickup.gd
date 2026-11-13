extends SceneTree

const World = preload("res://scripts/shop_world.gd")
const Save = preload("res://scripts/save_game.gd")
var failures := 0
var test_path := "res://.godot/pickup_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1

func settle() -> void:
	for frame in range(4):
		await process_frame

func game_instance() -> Node:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	return game

func run() -> void:
	root.size = Vector2i(1280, 720)
	BookCatalog.reset_catalog()
	var book := BookCatalog.get_book("jardim_horas")
	# Both orders of completion must allow one job and one stock repair, never two of either.
	for stock_first in [false, true]:
		var world := World.new()
		world.upgrades.restoration_table = true
		var inventory := Inventory.new()
		inventory.add("mar_vermelho", 3, "danificado")
		var first := world.offer_restoration({"id":"tom", "name":"Tom"}, book, 2)
		var second := world.offer_restoration({"id":"lyria", "name":"Lyria"}, book, 3)
		world.restoration_jobs.accept(str(first.id), 3)
		world.restoration_jobs.accept(str(second.id), 3)
		if stock_first:
			check(world.restore_book(inventory, "mar_vermelho", 3, 100) >= 0, "Estoque pode ser restaurado primeiro")
		check(world.finish_restoration_job(str(first.id), 3, 100, int(first.cost)) >= 0, "Encomenda usa seu próprio limite diário")
		if not stock_first:
			check(world.restore_book(inventory, "mar_vermelho", 3, 100) >= 0, "Estoque pode ser restaurado depois da encomenda")
		check(world.finish_restoration_job(str(second.id), 3, 100, int(second.cost)) == -1 and world.restore_book(inventory, "mar_vermelho", 3, 100) == -1, "Duas categorias concluídas bloqueiam um terceiro conserto")
		var restored := World.new()
		restored.restore(world.serialize())
		check(restored.last_restoration_day == 3 and restored.last_contract_restoration_day == 3, "Os dois usos diários sobrevivem ao salvamento")
		check(restored.finish_restoration_job(str(second.id), 4, 100, int(second.cost)) >= 0 and restored.restore_book(inventory, "mar_vermelho", 4, 100) >= 0, "Próximo dia renova os dois limites")
	var world := World.new()
	world.restore({"last_restoration_day": 7})
	check(world.last_restoration_day == 7 and world.last_contract_restoration_day == 7, "Save antigo preserva o uso do antigo limite compartilhado")
	world.upgrades.restoration_table = true
	var job := world.offer_restoration({"id":"lyria", "name":"Lyria"}, book, 2)
	world.restoration_jobs.accept(str(job.id), 2)
	check(not world.restoration_jobs.schedule_pickup(str(job.id), 2, 3), "Trabalho não concluído não pode ser agendado")
	world.finish_restoration_job(str(job.id), 2, 100, int(job.cost))
	check(world.restoration_jobs.collect(str(job.id), 2, "lyria").is_empty(), "Estar presente não permite entregar um livro sem agendamento")
	check(not world.restoration_jobs.schedule_pickup(str(job.id), 2, 1) and not world.restoration_jobs.schedule_pickup(str(job.id), 2, 6), "Agendamento rejeita passado e data após o prazo")
	check(world.restoration_jobs.schedule_pickup(str(job.id), 2, 4), "Livro pronto pode ter entrega agendada")
	check(world.restoration_jobs.collect(str(job.id), 3, "lyria").is_empty() and world.restoration_jobs.collect(str(job.id), 4).is_empty() and world.restoration_jobs.collect(str(job.id), 4, "tom").is_empty(), "Entrega exige dia correto e titular presente")
	var saved := World.new()
	saved.restore(world.serialize())
	check(saved.restoration_jobs.pickups_for_day(3).is_empty() and saved.restoration_jobs.pickups_for_day(4).size() == 1, "Agendamento salvo só chama o leitor a partir do dia marcado")
	saved.restoration_jobs.mark_pickup_visit(str(job.id), 4)
	check(saved.restoration_jobs.pickups_for_day(4).is_empty() and saved.restoration_jobs.pickups_for_day(5).size() == 1, "Leitor não é chamado duas vezes na mesma data, mas pode voltar até o prazo")
	check(saved.restoration_jobs.schedule_pickup(str(job.id), 4, 5) and not saved.restoration_jobs.collect(str(job.id), 5, "lyria").is_empty() and saved.restoration_jobs.collect(str(job.id), 5, "lyria").is_empty(), "Reagendar mantém entrega única no último dia")
	check(world.restoration_jobs.expire(6) == 1 and world.restoration_jobs.collect(str(job.id), 6, "lyria").is_empty(), "Agendamento não estende o prazo nem permite receber após vencer")
	# A same-day appointment after service has ended must reopen the arrival queue.
	var game := game_instance()
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.customer_transitions.finish_arrival()
	game.world.upgrades.restoration_table = true
	game.day_manager.day = 4
	game.money = 100
	var profile: Dictionary = game.customer_profiles[0] # Lyria is outside the centro district.
	var contract: Dictionary = game.world.offer_restoration(profile, book, 2)
	game.world.restoration_jobs.accept(str(contract.id), 4)
	game.world.finish_restoration_job(str(contract.id), 4, 100, int(contract.cost))
	game.customer_ids_seen_today.append("lyria") # A scheduled return may follow an earlier visit.
	game.customer.served = true
	game._depart_customer()
	game.day_manager.served_today = game.day_manager.customers_today
	game.day_manager.waiting_for_end_notice = true
	game._open_workshop()
	var screen: Control = game.active_overlay
	screen.show_restoration_orders()
	screen.contract_schedule_requested.emit(str(contract.id), 4)
	check(game.day_manager.waiting_for_next and not game.day_manager.waiting_for_end_notice and game.day_manager.customers_today == game.day_manager.served_today + 1, "Agendamento de hoje garante vaga mesmo após o último atendimento")
	check(game.money == 100, "Agendar hoje não recebe nem cobra moedas")
	screen.closed.emit()
	await settle()
	game.day_manager.tick(10)
	game.customer_transitions.finish_arrival()
	check(str(game.customer.profile_data.id) == "lyria" and game.customer.request_mode == "restauro", "Titular retorna por agendamento mesmo fora do bairro e após visita anterior")
	check(not game.customer.can_reserve(game.inventory) and not game._can_use_stock("jardim_horas", "novo"), "Retirada não vende nem reserva um exemplar do estoque")
	game._open_workshop()
	screen = game.active_overlay
	screen.show_restoration_orders()
	game._save_checkpoint(true)
	screen.closed.emit()
	game.queue_free()
	await settle()
	game = game_instance()
	game._continue_game()
	check(game.customer.visible and str(game.customer.profile_data.id) == "lyria" and game.customer.request_mode == "restauro" and int(game.world.restoration_jobs.get_job(str(contract.id)).pickup_day) == 4, "Continuar preserva o titular presente e o agendamento")
	game._open_workshop()
	screen = game.active_overlay
	screen.show_restoration_orders()
	var stock_before: Dictionary = game.inventory.condition_quantities.duplicate(true)
	var served_before: int = game.day_manager.served_today
	screen.contract_action_requested.emit(str(contract.id), "collect")
	check(game.money == 100 + int(contract.reward) and game.customer.served and not game.customer.visible and game.day_manager.served_today == served_before + 1, "Entrega presencial paga e encerra o atendimento uma única vez")
	check(game.inventory.condition_quantities == stock_before and game.day_sales_count == 0, "Livro do leitor não consome estoque nem registra uma venda")
	screen.contract_action_requested.emit(str(contract.id), "collect")
	check(game.money == 100 + int(contract.reward) and game.day_manager.served_today == served_before + 1, "Repetir entrega não duplica recompensa nem avança a fila")
	screen.closed.emit()
	game.queue_free()
	await settle()
	paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(0 if failures == 0 else 1)
