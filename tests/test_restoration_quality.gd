extends SceneTree

const World = preload("res://scripts/shop_world.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const Driver = preload("res://tests/restoration_input.gd")
var failures := 0
var test_path := "res://.godot/restoration_quality_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1

func select_choice(picker: OptionButton, value: String) -> void:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == value:
			picker.select(index)
			picker.item_selected.emit(index)
			return
	check(false, "Opção disponível: " + value)

func select_quality_input(picker: OptionButton, value: String) -> void:
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) != value:
			continue
		await Driver.click(self, picker)
		var popup := picker.get_popup()
		popup.set_focused_item(index)
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		key.window_id = popup.get_window_id()
		Input.parse_input_event(key)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		await process_frame
		check(str(picker.get_item_metadata(picker.selected)) == value, "Seleção pelo popup funciona: " + value)
		return
	check(false, "Condição disponível no popup: " + value)

func check_recipes() -> void:
	var all_costs_ordered := true
	var all_results_correct := true
	for book in BookCatalog.all_books():
		var used := World.restoration_cost(str(book.id), "usado")
		var new := World.restoration_cost(str(book.id), "novo")
		var rare := World.restoration_cost(str(book.id), "raro")
		all_costs_ordered = all_costs_ordered and used == 2 and new > used and rare > new
		for condition in World.RESTORATION_TARGETS:
			var world := World.new()
			world.upgrades.restoration_table = true
			var inventory := Inventory.new()
			inventory.condition_quantities.clear()
			inventory.acquisition_costs.clear()
			inventory.add(str(book.id), 1, "danificado", 3)
			var quote := World.restoration_cost(str(book.id), condition)
			var paid := world.restore_book(inventory, str(book.id), 1, quote, condition, quote)
			all_results_correct = all_results_correct and paid == quote and inventory.get_quantity(str(book.id)) == 1 and inventory.get_condition_quantity(str(book.id), condition) == 1 and inventory.get_condition_quantity(str(book.id), "danificado") == 0 and inventory.get_unit_cost(str(book.id), condition) == 3 + quote
			all_results_correct = all_results_correct and world.restore_book(inventory, str(book.id), 1, 999, condition) == -1
	check(all_costs_ordered, "Todos os títulos mantêm Usado por 2 moedas e preços crescentes para Novo e Raro")
	check(all_results_correct, "As três opções de todos os livros produzem uma única cópia correta, incorporam o custo e respeitam o limite diário")
	check(World.restoration_cost("reino_vidro", "raro") > World.restoration_cost("inventario_chuva", "raro"), "Conserto superior custa mais nos livros de maior valor")
	var world := World.new()
	world.upgrades.restoration_table = true
	var inventory := Inventory.new()
	var before := JSON.stringify(inventory.condition_quantities)
	var quote := World.restoration_cost("mar_vermelho", "raro")
	check(world.restore_book(inventory, "mar_vermelho", 1, quote - 1, "raro") == -1 and world.last_restoration_day == -1 and JSON.stringify(inventory.condition_quantities) == before, "Saldo insuficiente para Raro preserva o exemplar e o uso diário")
	check(world.restore_book(inventory, "mar_vermelho", 1, 100, "raro", quote - 1) == -1 and world.last_restoration_day == -1, "Preço divergente do orçamento é recusado sem consumir o restauro")
	check(world.restore_book(inventory, "mar_vermelho", 1, 100, "danificado") == -1 and world.restore_book(inventory, "mar_vermelho", 1, 100, "invalido") == -1 and world.restore_book(inventory, "inexistente", 1, 100, "raro") == -1, "Condição e título inválidos não criam exemplares")
	world.upgrades.orders_cabinet = true
	world.reserve_book("protected", "mar_vermelho", "danificado")
	check(world.restore_book(inventory, "mar_vermelho", 1, 100, "raro") == -1, "Escolher Raro também respeita a proteção da cópia danificada reservada")
	world.memories.clear()
	world.reserve_book("collector", "mar_vermelho", "raro")
	check(world.restore_book(inventory, "mar_vermelho", 1, 100, "raro") == quote and world.available_for_customer(inventory, "mar_vermelho", "raro", "collector") == 1 and world.available_for_customer(inventory, "mar_vermelho", "raro", "other") == 0, "Raro restaurado pode atender uma encomenda e fica protegido para seu leitor")

func make_game() -> Node:
	var game: Node = preload("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	return game

func run() -> void:
	root.size = Vector2i(1280, 720)
	check_recipes()
	var game := make_game()
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.money = 100
	game.world.upgrades.restoration_table = true
	game.inventory.add("reino_vidro", 1, "danificado", 4)
	game._open_workshop()
	var screen: Control = game.active_overlay
	screen.show_item(1)
	select_choice(screen.action_picker, "reino_vidro")
	game.money = 1
	screen.refresh(1, game.day_manager.day)
	for condition in ["raro", "usado", "novo", "raro"]:
		await select_quality_input(screen.restoration_quality_picker, condition)
		var expected := World.restoration_cost("reino_vidro", condition)
		check(screen.restoration_condition == condition and screen.action_status.text.contains(str(expected)) and screen.action_status.text.contains(str(BookCatalog.get_condition(condition).label)) and not screen.restoration_quality_picker.is_item_disabled(screen.restoration_quality_picker.selected), "Com 1 moeda, a escolha e o orçamento permanecem sincronizados: " + condition)
		screen.refresh(1, game.day_manager.day)
		check(str(screen.restoration_quality_picker.get_item_metadata(screen.restoration_quality_picker.selected)) == condition and screen.restoration_condition == condition, "Atualizar o saldo preserva a condição escolhida: " + condition)
	var quote := World.restoration_cost("reino_vidro", "raro")
	check(screen.restoration_quality_picker.item_count == 3 and screen.action_button.text == "ABRIR BANCADA" and screen.action_status.text.contains(str(quote)) and screen.action_status.text.contains("Raro"), "Preço aparece somente no orçamento do conserto, separado da abertura gratuita")
	screen.action_button.pressed.emit()
	check(not screen.action_button.disabled and screen.restoration_bench != null and game.money == 1 and screen.restoration_bench.target_condition == "raro", "Abrir com 1 moeda é gratuito mesmo escolhendo um conserto mais caro")
	screen.restoration_bench.closed.emit()
	await process_frame
	check(game.money == 1 and game.inventory.get_condition_quantity("reino_vidro", "danificado") == 1 and game.world.last_restoration_day == -1, "Abrir e cancelar preserva saldo, exemplar e uso diário")
	game.money = 0
	screen.refresh(0, game.day_manager.day)
	screen.action_button.pressed.emit()
	check(screen.restoration_bench != null and game.money == 0, "Abrir a bancada com saldo zero também não cobra entrada")
	screen.restoration_bench.closed.emit()
	await process_frame
	game.money = 100
	screen.refresh(100, game.day_manager.day)
	screen.action_button.pressed.emit()
	var bench: Control = screen.restoration_bench
	check(bench != null and bench.target_condition == "raro" and bench.restoration_cost == quote and bench.get_node("BookTitle").text.contains("Raro") and game.money == 100, "Bancada trava o resultado Raro e mostra o orçamento sem cobrar na abertura")
	# The visible quote belongs to this job even if the next job's preference changes.
	screen.restoration_condition = "novo"
	game.inventory.changed.emit()
	check(bench.target_condition == "raro" and bench.restoration_cost == quote, "Preferência posterior não troca a condição nem o orçamento do trabalho aberto")
	await Driver.clean(self, bench)
	await Driver.glue(self, bench)
	await Driver.patch(self, bench)
	await Driver.sew(self, bench)
	check(game.money == 100 and game.inventory.get_condition_quantity("reino_vidro", "danificado") == 1, "Etapas intermediárias não cobram nem retiram o exemplar")
	await Driver.press(self, bench)
	check(game.money == 100 - quote and game.inventory.get_condition_quantity("reino_vidro", "danificado") == 0 and game.inventory.get_condition_quantity("reino_vidro", "raro") == 1 and game.inventory.get_unit_cost("reino_vidro", "raro") == 4 + quote, "Restauração completa cobra o preço escolhido e devolve o exemplar como Raro")
	check(bench._status.text.contains("Raro") and bench._status.text.contains(str(quote)), "Mensagem final confirma condição e valor efetivamente pagos")
	screen.restoration_requested.emit("reino_vidro")
	check(game.money == 100 - quote and game.inventory.get_condition_quantity("reino_vidro", "raro") == 1, "Repetir a finalização não duplica cobrança ou cópia rara")
	var saved := SaveGame.read_save(test_path)
	check(int(saved.inventory.reino_vidro.raro) == 1 and int(saved.money) == 100 - quote, "Checkpoint grava o exemplar restaurado e o saldo correto")
	game.queue_free()
	await process_frame
	paused = false
	game = make_game()
	game._continue_game()
	check(game.inventory.get_condition_quantity("reino_vidro", "raro") == 1 and game.inventory.get_unit_cost("reino_vidro", "raro") == 4 + quote and game.money == 100 - quote and game.world.last_restoration_day == game.day_manager.day, "Continuar preserva condição Raro, custo, saldo e limite diário")
	game.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(0 if failures == 0 else 1)
