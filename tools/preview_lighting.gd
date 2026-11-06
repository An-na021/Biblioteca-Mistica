extends Node
## Isolated purchase preview: F1 opens improvements, F2 returns to the room.

var game: Node

func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.godot/lighting_preview_save.json"
	game.api_url = ""
	add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.money = 18
	game._update_status()
	game.set_process(false)
	game.mood_timer.hide()
	game.customer_transitions.reset()
	game.customer.hide()
	game.atmosphere.animations_active = false
	DisplayServer.window_set_title("Luz de leitura — prévia de compra")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1 and game.active_overlay == null:
		game.store_is_open = false
		game._present_day_summary(true)
		game._show_livraria(game.active_overlay)
	elif event.keycode == KEY_F2 and game.active_overlay != null:
		if not game.active_overlay is DaySummaryScreen:
			game.active_overlay.closed.emit()
		game.active_overlay.queue_free()
		game.active_overlay = null
		game.atmosphere.set_day_progress(0.0, true)
