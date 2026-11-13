extends SceneTree
const World = preload("res://scripts/shop_world.gd")
const Diagnosis = preload("res://scripts/restoration_diagnosis.gd")
const Bench = preload("res://scripts/restoration_bench.gd")
const Driver = preload("res://tests/restoration_input.gd")
const Save = preload("res://scripts/save_game.gd")
const Audio = preload("res://scripts/game_audio.gd")
var failures := 0
var test_path := "res://.godot/restoration_expansion_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1

func settle() -> void:
	for _frame in range(4):
		await process_frame

func screenshot(name: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots") and DisplayServer.get_name() != "headless":
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/expansion_" + name + ".png")

func game_instance() -> Node:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	return game

func run() -> void:
	root.size = Vector2i(1280, 720)
	BookCatalog.reset_catalog()
	var book := BookCatalog.get_book("reino_vidro")
	var stable := Diagnosis.for_book(str(book.id), 2)
	check(stable == Diagnosis.for_book(str(book.id), 2) and Diagnosis.for_book("mar_vermelho", 1) != stable, "Diagnóstico estável ao reabrir e variado entre títulos e dias")
	for travel in [-75.0, 0.0, 75.0]:
		for layer in range(6):
			check(Geometry2D.triangulate_polygon(preload("res://scripts/shop_weather.gd").cloud_outline(layer, travel)).size() == 6, "Sombra de nuvem válida em toda a amplitude de movimento")
	var plans: Array = [] if OS.get_cmdline_user_args().has("--ui-only") else Diagnosis.PROFILES
	for diagnostic in plans:
		var bench := Bench.new()
		root.add_child(bench)
		bench.setup(book, "novo", 30, diagnostic)
		var submitted := {"count": 0}
		bench.completed.connect(func(_id: String) -> void: submitted.count += 1)
		check(bench.stage == int(diagnostic.stages[0]) and bench.selected_tool == bench.stage and not bench.can_submit(str(book.id)), "Bancada começa pela ferramenta do diagnóstico: " + str(diagnostic.id))
		check(bench.tool_buttons[1].disabled == (1 not in diagnostic.stages), "Ferramentas desnecessárias ficam desabilitadas: " + str(diagnostic.id))
		await screenshot("diagnosis_" + str(diagnostic.id))
		for stage in diagnostic.stages:
			check(bench.stage == stage, "Ordem do trabalho %s: etapa %d" % [str(diagnostic.id), stage])
			match stage:
				0:
					await Driver.clean(self, bench)
					check(bench.tool_audio.current == "brush", "Cerdas produzem som somente nas passadas que limpam")
				1: await Driver.glue(self, bench)
				2:
					await Driver.patch(self, bench)
				3: await Driver.sew(self, bench)
				4: await Driver.press(self, bench)
		check(bench.stage == Bench.Stage.DONE and int(submitted.count) == 1 and bench.can_submit(str(book.id)), "Diagnóstico conclui pelas ações reais e emite uma vez: " + str(diagnostic.id))
		bench._next_stage()
		check(int(submitted.count) == 1, "Etapa concluída não pode duplicar a finalização")
		bench.show_result(true)
		bench.queue_free()
		await settle()
	# Validate contracts independently of shop copies and purchase reservations.
	var world := World.new()
	var profile := {"id": "tom", "name": "Tom, o aprendiz"}
	check(world.offer_restoration(profile, book, 2).is_empty(), "Mesa instalada é necessária para receber trabalhos")
	world.upgrades.restoration_table = true
	var first := world.offer_restoration(profile, book, 2)
	check(not first.is_empty() and world.offer_restoration(profile, book, 2).is_empty(), "No máximo uma nova proposta por dia")
	check(world.restoration_jobs.accept(str(first.id), 2) and not world.restoration_jobs.accept(str(first.id), 2), "Aceitação tem uma única transição")
	check(world.finish_restoration_job(str(first.id), 2, 0, int(first.cost)) == -1 and world.finish_restoration_job(str(first.id), 2, 20, int(first.cost) + 1) == -1 and world.last_restoration_day == -1, "Saldo insuficiente ou orçamento adulterado preservam trabalho e limite diário")
	check(world.finish_restoration_job(str(first.id), 2, 20, int(first.cost)) == int(first.cost) and world.finish_restoration_job(str(first.id), 2, 20, int(first.cost)) == -1, "Materiais cobrados uma única vez")
	var saved := World.new()
	saved.restore(world.serialize())
	check(str(saved.restoration_jobs.get_job(str(first.id)).status) == "ready" and saved.last_contract_restoration_day == 2 and saved.last_restoration_day == -1, "Trabalho pronto e limite de encomenda persistem sem consumir o estoque")
	check(saved.restoration_jobs.collect(str(first.id), 2, "tom").is_empty() and saved.restoration_jobs.schedule_pickup(str(first.id), 2, int(first.due_day)), "Livro pronto exige agendamento antes da entrega")
	check(not saved.restoration_jobs.collect(str(first.id), int(first.due_day), "tom").is_empty() and saved.restoration_jobs.collect(str(first.id), int(first.due_day), "tom").is_empty(), "Entrega presencial no último dia paga uma vez")
	var late := world.offer_restoration({"id": "lyria", "name": "Lyria"}, book, 3)
	world.restoration_jobs.accept(str(late.id), 3)
	check(world.restoration_jobs.expire(int(late.due_day) + 1) > 0 and not world.restoration_jobs.can_work(str(late.id), int(late.due_day) + 1) and world.restoration_jobs.collect(str(late.id), int(late.due_day) + 1).is_empty(), "Trabalho vencido não pode ser restaurado nem recompensado")
	world = World.new()
	world.restore({})
	check(world.restoration_jobs.pending().is_empty(), "Partidas anteriores continuam compatíveis")
	world.upgrades.restoration_table = true
	var one := world.offer_restoration({"id": "one", "name": "Leitor 1"}, book, 2)
	var two := world.offer_restoration({"id": "two", "name": "Leitor 2"}, book, 3)
	var three := world.offer_restoration({"id": "three", "name": "Leitor 3"}, book, 4)
	world.restoration_jobs.accept(str(one.id), 4)
	world.restoration_jobs.accept(str(two.id), 4)
	check(not world.restoration_jobs.accept(str(three.id), 4) and world.restoration_jobs.decline(str(three.id), 4), "Limite de dois trabalhos aceitos permite recusar a terceira proposta")
	var invalid := first.duplicate(true)
	invalid.cost = []
	saved.restoration_jobs.restore({"last_offer_day": [], "entries": [invalid]})
	check(saved.restoration_jobs.entries.is_empty(), "Dados de encomenda inválidos não quebram a leitura de uma partida")
	# Native audio data is non-silent, bounded, and looped only for friction.
	for kind in ["brush", "glue", "roller", "press", "thread", "rain", "wind", "street"]:
		var sound := Audio.stream(kind, true)
		var peak := 0
		for index in range(0, sound.data.size(), 2):
			peak = maxi(peak, absi(sound.data.decode_s16(index)))
		check(peak > 100 and peak < 32767 and sound.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Áudio sem silêncio ou saturação: " + kind)
	# A client-owned volume is restored, returned and saved through the real UI.
	var game := game_instance()
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.customer_transitions.finish_arrival()
	game.world.upgrades.restoration_table = true
	game.money = 20
	game.day_manager.day = 2
	var contract: Dictionary = game.world.offer_restoration(profile, book, 2)
	var inventory_before: Dictionary = game.inventory.condition_quantities.duplicate(true)
	var rep_before: int = game.reputation
	game._open_workshop()
	var screen: Control = game.active_overlay
	await Driver.click(self, screen.orders_button)
	check(screen.orders_panel.visible and paused, "Botão abre as encomendas e mantém o expediente suspenso")
	await screenshot("orders_offer")
	var card: Node = screen.orders_panel.list.get_node("Order_" + str(contract.id))
	await Driver.click(self, card.get_node("Actions/Action"))
	check(str(game.world.restoration_jobs.get_job(str(contract.id)).status) == "accepted" and game.money == 20, "Aceitar pela interface não cobra nem altera o estoque")
	await screenshot("orders_accepted")
	card = screen.orders_panel.list.get_node("Order_" + str(contract.id))
	await Driver.click(self, card.get_node("Actions/Action"))
	var bench: Control = screen.restoration_bench
	check(bench != null and bench.diagnosis.id == "dust" and game.money == 20, "Livro do cliente abre com diagnóstico e orçamento próprios")
	screen.contract_completed_requested.emit(str(contract.id))
	check(game.money == 20 and str(game.world.restoration_jobs.get_job(str(contract.id)).status) == "accepted", "Sinal antecipado não conclui trabalho")
	await Driver.clean(self, bench)
	check(game.money == 20 - int(contract.cost) and str(game.world.restoration_jobs.get_job(str(contract.id)).status) == "ready" and game.inventory.condition_quantities == inventory_before, "Concluir cobra só materiais e mantém o livro fora do estoque da loja")
	await screenshot("order_completed")
	await Driver.click(self, bench.back_button)
	await settle()
	card = screen.orders_panel.list.get_node("Order_" + str(contract.id))
	check(str(card.get_node("Actions/Action").text) == "Agendar entrega", "Livro pronto oferece agendamento em vez de pagamento imediato")
	var pickup_picker: OptionButton = card.get_node("Actions/PickupDay")
	for option in range(pickup_picker.item_count):
		if int(pickup_picker.get_item_metadata(option)) == 3:
			pickup_picker.select(option)
	await Driver.click(self, card.get_node("Actions/Action"))
	check(str(game.world.restoration_jobs.get_job(str(contract.id)).status) == "scheduled" and game.money == 20 - int(contract.cost), "Agendar não paga a recompensa")
	card = screen.orders_panel.list.get_node("Order_" + str(contract.id))
	check(card.get_node("Actions/Action").disabled, "Entrega fica indisponível antes do dia agendado")
	screen.contract_action_requested.emit(str(contract.id), "collect")
	check(game.money == 20 - int(contract.cost), "Sinal antecipado não contorna data e presença do titular")
	screen.closed.emit()
	await settle()
	game.day_manager.day = 3
	game._begin_day()
	game.customer_transitions.finish_arrival()
	check(str(game.customer.profile_data.id) == "tom" and game.customer.request_mode == "restauro", "Titular chega com prioridade no dia agendado para buscar o restauro")
	game._open_workshop()
	screen = game.active_overlay
	screen.show_restoration_orders()
	await settle()
	card = screen.orders_panel.list.get_node("Order_" + str(contract.id))
	check(not card.get_node("Actions/Action").disabled, "Presença do titular libera a entrega agendada")
	await Driver.click(self, card.get_node("Actions/Action"))
	var expected := 20 - int(contract.cost) + int(contract.reward)
	check(game.money == expected and game.reputation == rep_before + int(contract.reputation), "Entrega paga moedas e reputação combinadas")
	screen.contract_action_requested.emit(str(contract.id), "collect")
	check(game.money == expected and game.inventory.condition_quantities == inventory_before, "Cliques repetidos não duplicam recompensa ou livros")
	var checkpoint := Save.read_save(test_path)
	check(not checkpoint.is_empty() and int(checkpoint.money) == expected and str(checkpoint.world.restoration_jobs.entries[0].status) == "delivered", "Checkpoint registra a entrega e os valores reais")
	screen.closed.emit()
	await settle()
	# Weather and reactions do not alter service rules.
	var weather: Node = game.atmosphere.weather
	weather.configure_day(1)
	check(weather.kind == "clear", "Primeiro dia começa com céu aberto")
	await screenshot("weather_clear")
	weather.configure_day(3)
	weather.active = true
	weather._process(0.8)
	game.atmosphere._process(0.01)
	check(weather.kind == "rain" and weather.room_tint() != Color.WHITE and weather.audio.current == "rain", "Dia de chuva ativa vidro, sombra e som exterior")
	await screenshot("weather_rain")
	game._open_window()
	await settle()
	check(game.active_overlay.weather_kind == "rain" and float(game.active_overlay._weather_material.get_shader_parameter("weather")) == 2.0, "Janela ampliada acompanha a chuva do ambiente")
	await screenshot("window_rain")
	game.active_overlay.close()
	await settle()
	var expression: Node = game.customer.expression_driver
	var hitbox_scale: Vector2 = game.customer.scale
	expression.react(true)
	check(expression.emotion == "satisfied" and float(game.customer.portrait.material.get_shader_parameter("smile")) == 1, "Venda produz satisfação no rosto")
	await screenshot("customer_satisfied")
	expression.react(false)
	check(expression.emotion == "doubt" and float(game.customer.portrait.material.get_shader_parameter("doubt")) == 1 and game.customer.scale == hitbox_scale, "Recusa produz dúvida sem mudar a área de interação")
	await screenshot("customer_doubt")
	expression.held = 0
	expression.set_patience(0.1, false)
	check(expression.emotion == "impatient", "Pouca paciência muda a expressão")
	expression.set_patience(0.1, true)
	check(expression.emotion == "neutral" and expression.impatience == 0, "Modo tranquilo remove impaciência por tempo")
	weather.audio.engage("rain")
	paused = true
	weather.audio._process(1)
	check(not weather.audio.friction.playing, "Pausa silencia o som exterior")
	paused = false
	game.queue_free()
	await settle()
	game = game_instance()
	game._continue_game()
	check(game.money == expected and game.reputation == rep_before + int(contract.reputation) and str(game.world.restoration_jobs.get_job(str(contract.id)).status) == "delivered" and game.atmosphere.weather.kind == "rain", "Continuar preserva encomenda entregue, valores e clima do dia salvo")
	game.day_manager.day = 3
	game._begin_day()
	check(game.world.restoration_jobs.pending().size() == 1 and game.world.restoration_jobs.last_offer_day == 3, "Chegada real de um leitor cria a proposta do próximo dia")
	game.queue_free()
	await settle()
	paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(0 if failures == 0 else 1)
