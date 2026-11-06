extends Node
## F1: new arrival, F2: real sale, F3: departure.

var game: Node

func _ready() -> void:
	# Slow only this demonstration so each motion is easy to inspect.
	Engine.time_scale = 0.60
	game = preload("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.godot/shop_life_preview_save.json"
	game.api_url = ""
	add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.world.upgrades = {"lighting": true, "shelves": true, "plants": true}
	game._update_world_visuals()
	game.set_process(false)
	game.mood_timer.hide()
	game.atmosphere.animations_active = true
	game.atmosphere.lighting_installed = true
	game.atmosphere.set_day_progress(0.35, true)
	DisplayServer.window_set_title("Clientes e compras — prévia")

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or game.active_overlay != null:
		return
	match event.keycode:
		KEY_F1:
			game._begin_day()
			game._update_world_visuals()
			game.mood_timer.hide()
			game.atmosphere.set_day_progress(0.35, true)
		KEY_F2:
			if not game.customer.visible:
				return
			var book_id := str(game.customer.requested_book_id)
			var condition := str(game.customer.profile_data.preferred_condition)
			game.inventory.add(book_id, 1, condition)
			game._open_inventory()
			game._handle_stock_action(book_id, condition, "deliver", game.active_overlay)
		KEY_F3:
			game._depart_customer()
