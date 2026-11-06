extends Node

func _ready() -> void:
	var game := preload("res://scenes/main.tscn").instantiate()
	game.save_path = "res://.godot/restart_menu_preview_save.json"
	game.api_url = ""
	add_child(game)
	game.game_menu.show_start(true)
	game.game_menu._request_new_game()
	DisplayServer.window_set_title("Começar de novo — prévia")
