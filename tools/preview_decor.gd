extends Node
## An isolated live scene for checking decoration against the room lighting.

@export var lighting_preview := false
var game: Node

func _ready() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.godot/decor_preview_save.json"
	game.api_url = ""
	add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.world.upgrades = {"lighting": true, "shelves": true, "plants": true}
	game._update_world_visuals()
	if lighting_preview:
		game.set_process(false)
		game.mood_timer.hide()
		game.atmosphere.animations_active = true
		game.atmosphere.lighting_installed = true
		game.atmosphere.set_day_progress(0.55, true)
	DisplayServer.window_set_title("Decoração da livraria — prévia")

func _unhandled_key_input(event: InputEvent) -> void:
	if not lighting_preview or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: game.atmosphere.set_day_progress(0.0, true)
		KEY_F2: game.atmosphere.set_day_progress(0.55, true)
		KEY_F3: game.atmosphere.set_day_progress(1.0, true)
