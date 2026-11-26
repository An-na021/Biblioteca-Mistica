extends SceneTree

const SaveGame = preload("res://scripts/save_game.gd")
var failures := 0
var test_path := "res://.godot/settings_%d.json" % Time.get_ticks_usec()

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

func run() -> void:
	var file := FileAccess.open("res://api/seed.json", FileAccess.READ)
	var catalog: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	catalog["settings"] = {"starting_money": 37, "max_customers_per_day": 2, "shop_title": "Livraria de teste"}
	var game := make_game()
	check(game._apply_catalog(catalog), "Catálogo aceita configurações administrativas válidas")
	game._start_new_game()
	check(game.money == 0, "Nova partida começa sem moedas mesmo com saldo inicial configurado no portal")
	check(game.day_manager.customers_today == 2, "Configuração limita clientes do dia sem repetir leitores")
	check(game.checkpoint.money == 0 and game.checkpoint.catalog.settings.max_customers_per_day == 2, "Checkpoint preserva saldo zero e limite de clientes da partida")
	game.queue_free()
	await process_frame
	game = make_game()
	game._continue_game()
	check(game.money == 0 and game._current_customer_limit() == 2, "Continuar offline recupera saldo e limite salvos")
	var invalid: Dictionary = catalog.duplicate(true)
	invalid.settings.max_customers_per_day = 0
	check(not game._apply_catalog(invalid), "Catálogo inválido não reduz limite abaixo de um")
	invalid = catalog.duplicate(true)
	invalid.settings.starting_money = -1
	check(not game._apply_catalog(invalid), "Configuração rejeita saldo inicial negativo")
	check(game.game_settings.starting_money == 37, "Rejeição preserva configuração válida anterior")
	game.queue_free()
	await process_frame
	BookCatalog.reset_catalog()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
