extends Node
## Run this scene with F6 to review the closing screen with an isolated save.

@export var show_districts := false
@export var show_shop := false
@export var show_livraria := false

func _ready() -> void:
	var game := preload("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.godot/day_summary_preview_save.json"
	game.api_url = ""
	add_child(game)
	game.game_menu.enter_game()
	game.store_is_open = false
	game.day_manager.day = 3
	game.day_manager.close_store()
	game.day_manager.customers_today = 4
	game.day_customers_served = 2
	game.day_sales_count = 2
	game.day_sales_revenue = 38
	game.day_failed_customers = 1
	game.day_errors = 4
	game.day_profit = 12
	game.reputation = 2 if show_districts else 4
	game.day_start_reputation = game.reputation - 2
	game.summary_report = {
		"daily_goals": [
			{"title": "Conclua 3 vendas", "progress": 2, "target": 3},
			{"title": "Feche o dia sem erros", "progress": 0, "target": 1}
		],
		"weekly_goals": [
			{"title": "Venda 12 livros na semana", "progress": 2, "target": 12},
			{"title": "Lucre 100 moedas na semana", "progress": 12, "target": 100}
		],
		"daily_reward": 0, "weekly_reward_available": 25,
		"week_number": 1, "achievement_count": 0
	}
	if show_shop:
		_shop_example(game)
	if show_livraria:
		game.money = 32
		game.world.upgrades = {"shelves": true}
		game.world.memories.clear()
		game.world.record_visit("tom", 3)
		game.world.record_purchase("tom", "jardim_horas", "novo")
		game.world.create_order("tom", "inventario_chuva", "novo")
	game._present_day_summary(true)
	if show_districts:
		game._show_districts(game.active_overlay)
	if show_shop:
		game._show_shop(game.active_overlay)
	if show_livraria:
		game._show_livraria(game.active_overlay)
	DisplayServer.window_set_title("Loja de livros — prévia" if show_shop else ("Bairros da cidade — prévia" if show_districts else "Fechamento do dia — prévia"))
	if show_livraria:
		DisplayServer.window_set_title("Nossa livraria — prévia")


func _shop_example(game: Node) -> void:
	game.money = 3
	game.inventory.condition_quantities.clear()
	game.inventory.acquisition_costs.clear()
	game.inventory.add("jardim_horas", 1, "usado")
	game.inventory.add("mar_vermelho", 2, "usado")
	game.inventory.add("inventario_chuva", 2, "novo")
	game.world.reserve_book("mestre_elian", "jardim_horas", "raro")
	game.world.reserve_book("professor_bigodes", "jardim_horas", "novo")
	game.world.reserve_book("thalion_grimorio", "reino_vidro", "raro")
	game.world.reserve_book("tom", "inventario_chuva", "novo")
	game.supplier_markets = {"praca": {
		"jardim_horas": {"quantity": 2, "risk": 0.0, "conditions": {"novo": {"quantity": 1, "price": 5}, "raro": {"quantity": 1, "price": 8}}},
		"reino_vidro": {"quantity": 1, "risk": 0.0, "conditions": {"raro": {"quantity": 1, "price": 16}}},
		"inventario_chuva": {"quantity": 2, "risk": 0.0, "conditions": {"usado": {"quantity": 2, "price": 2}}},
		"mar_vermelho": {"quantity": 2, "risk": 0.0, "conditions": {"usado": {"quantity": 2, "price": 2}}}
	}}
