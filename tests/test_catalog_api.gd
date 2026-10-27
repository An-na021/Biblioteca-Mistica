extends SceneTree

const SaveGame = preload("res://scripts/save_game.gd")
var failures := 0
var test_path := "res://.godot/api_game_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = OS.get_environment("BIBLIOTECA_API_URL")
	root.add_child(game)
	var deadline := Time.get_ticks_msec() + 6000
	while game.game_menu.new_button.disabled and Time.get_ticks_msec() < deadline:
		await create_timer(0.05, true).timeout
	check(not game.catalog_snapshot.is_empty(), "Godot carrega catálogo via HTTP com o menu pausado")
	if game.catalog_snapshot.is_empty():
		game.queue_free()
		await process_frame
		quit(1)
		return
	check(int(BookCatalog.get_book("jardim_horas").sale_price) == 19, "Preço editado por PATCH aparece no catálogo do jogo")
	check(not BookCatalog.get_book("api_livro").is_empty(), "Livro cadastrado por POST aparece no jogo")
	game._start_new_game()
	game._set_relaxed_mode(true)
	var district: Dictionary = game._current_district()
	check(district.book_ids.has("api_livro") and district.customer_ids.has("api_leitor"), "Bairros usam relacionamentos vindos do banco")
	game.customer_ids_seen_today.clear()
	for customer_id in district.customer_ids:
		if str(customer_id) != "api_leitor":
			game.customer_ids_seen_today.append(str(customer_id))
	game._on_customer_ready(2, 5)
	check(game.customer.customer_name == "Leitor da API", "Cliente cadastrado pela API é atendido com falas de fallback")
	game.inventory.add("api_livro", 1, "novo")
	game.customer.profile_data.preferred_condition = "novo"
	game.customer.acceptable_book_ids.clear()
	game.customer.acceptable_book_ids.append("api_livro")
	game._open_inventory()
	game._handle_stock_action("api_livro", "novo", "deliver", game.active_overlay)
	check(game.day_sales_count == 1, "Livro da API participa de uma venda real")
	await process_frame
	game._close_store(false)
	await process_frame
	var summary: DaySummaryScreen = game.active_overlay
	game._show_livraria(summary)
	check(game.active_overlay != null, "Caderno aceita clientes personalizados sem história predefinida")
	game.active_overlay.closed.emit()
	await process_frame
	game._show_shop(summary)
	check(game.supplier_markets.has("api_fornecedor") and not game.supplier_markets.has("praca"), "Fornecedor criado e fornecedor excluído refletem na loja")
	check(game.supplier_markets["api_fornecedor"].has("api_livro"), "Fornecedor personalizado oferece livros do catálogo")
	var saved := SaveGame.read_save(test_path)
	check(not saved.get("catalog", {}).is_empty(), "Partida salva preserva o catálogo utilizado")
	game.queue_free()
	await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._continue_game()
	check(int(BookCatalog.get_book("jardim_horas").sale_price) == 19 and game.supplier_profiles.size() == 3, "Continuar offline recupera catálogo e fornecedores da partida")
	game.queue_free()
	await process_frame
	BookCatalog.reset_catalog()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
