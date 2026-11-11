extends Node
## Isolated inventory preview; F1 toggles the rare-condition filter.

var game: Node

func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.godot/stock_preview_save.json"
	game.api_url = ""
	add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.customer.profile_data.preferred_condition = "raro"
	game.customer.request_clue = {"type": "caracteristica", "text": "Na última visita saí sem uma leitura. Vamos tentar de novo? Queria uma leitura com temas ligados à natureza. Não lembro o nome do livro."}
	game.inventory.remove("jardim_horas", 1, "novo")
	game.set_process(false)
	game.customer_transitions.finish_arrival()
	game._open_inventory()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1 and game.active_overlay is InventoryScreen:
		var screen: InventoryScreen = game.active_overlay
		if screen.condition_filter.selected != 0:
			screen.condition_filter.select(0)
		else:
			for index in range(screen.condition_filter.item_count):
				if screen.condition_filter.get_item_metadata(index) == "raro":
					screen.condition_filter.select(index)
		screen._refresh_books()
