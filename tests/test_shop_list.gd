extends SceneTree

var failures := 0
var test_path := "res://.godot/shop_list_test_%d.json" % Time.get_ticks_usec()

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
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.money = 100
	game.supplier_markets = {
		"praca": {"reino_vidro": {"quantity": 2, "conditions": {"novo": {"quantity": 2, "price": 8}}, "risk": 0.0}},
		"caravana": {
			"reino_vidro": {"quantity": 1, "conditions": {"novo": {"quantity": 1, "price": 5}}, "risk": 0.0},
			"mar_vermelho": {"quantity": 1, "conditions": {"usado": {"quantity": 1, "price": 3}}, "risk": 0.0}
		},
		"antiquario": {"reino_vidro": {"quantity": 1, "conditions": {"novo": {"quantity": 1, "price": 8}}, "risk": 0.05}}
	}
	var offers: Dictionary = game._combined_merchant_offers()
	check(offers.size() == 2 and offers.reino_vidro.conditions.size() == 1 and int(offers.reino_vidro.conditions.novo.quantity) == 4, "Ofertas reúnem fornecedores sem duplicar título ou condição")
	check(str(offers.reino_vidro.conditions.novo.supplier_id) == "caravana" and int(offers.reino_vidro.conditions.novo.price) == 5, "Lista seleciona o menor preço disponível")
	game._show_shop()
	var shop: MerchantScreen = game.active_overlay
	await process_frame
	var ids: Array[String] = []
	for row in shop.book_list.get_children():
		ids.append(str(row.get_meta("book_id")))
	check(ids.size() == BookCatalog.all_books().size() and ids.count("reino_vidro") == 1 and ids.has("ultimo_dragao"), "Catálogo completo aparece em uma lista, incluindo títulos sem ofertas")
	var before: int = game.inventory.get_condition_quantity("reino_vidro", "novo")
	shop.purchase_requested.emit("reino_vidro", "novo")
	await process_frame
	check(game.money == 95 and game.inventory.get_condition_quantity("reino_vidro", "novo") == before + 1, "Compra unificada cobra o preço exibido e entrega um exemplar")
	check(int(game.supplier_markets.caravana.reino_vidro.conditions.novo.quantity) == 0 and int(game.supplier_markets.praca.reino_vidro.conditions.novo.quantity) == 2, "Compra reduz apenas o estoque do fornecedor utilizado")
	check(int(shop.offers.reino_vidro.conditions.novo.price) == 8 and str(shop.offers.reino_vidro.conditions.novo.supplier_id) == "praca", "Oferta esgotada dá lugar ao próximo preço com menor risco no empate")
	shop.purchase_requested.emit("reino_vidro", "novo")
	await process_frame
	check(game.money == 87 and int(game.supplier_markets.praca.reino_vidro.conditions.novo.quantity) == 1, "Compra seguinte usa a oferta atualizada")
	game.money = 0
	shop.purchase_requested.emit("reino_vidro", "novo")
	check(game.money == 0 and int(game.supplier_markets.praca.reino_vidro.conditions.novo.quantity) == 1, "Saldo insuficiente preserva dinheiro e estoque de todos os fornecedores")
	shop.purchase_requested.emit("ultimo_dragao", "raro")
	check(game.money == 0 and not game.inventory.has("ultimo_dragao"), "Título indisponível não pode ser comprado")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
