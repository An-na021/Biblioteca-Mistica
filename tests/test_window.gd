extends SceneTree

const WindowScreenUI = preload("res://scripts/window_screen.gd")
var failures := 0
var test_path := "res://.godot/window_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func click_window(game: Node, node_name: String) -> void:
	var collision: CollisionShape2D = game.get_node(node_name).get_child(0)
	var mouse_position := collision.get_global_transform_with_canvas().origin
	var motion := InputEventMouseMotion.new()
	motion.position = mouse_position
	root.push_input(motion)
	await physics_frame
	await process_frame
	var press := InputEventMouseButton.new()
	press.position = mouse_position
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press)
	await physics_frame
	await process_frame
	press = press.duplicate()
	press.pressed = false
	root.push_input(press)
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	await process_frame
	await click_window(game, "RightWindow")
	check(game.active_overlay is WindowScreenUI, "Clique na segunda janela abre a paisagem")
	if game.active_overlay is WindowScreenUI:
		check(game.active_overlay.get_node("View/WindowImage").texture.resource_path == "res://IMG/janela_direita.jpg", "Segunda janela usa a imagem da direita")
		var right_patience: float = game.customer_time_left
		game._process(120.0)
		check(game.customer_time_left == right_patience, "Paisagem da direita suspende o atendimento")
		await create_timer(0.3).timeout
		if OS.get_cmdline_user_args().has("--screenshots"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/preview_window_right.png")
		game.active_overlay.get_node("View/Back").pressed.emit()
		await process_frame
		check(game.active_overlay == null and game.get_node("UI").visible, "Voltar da segunda janela restaura a livraria")
	await click_window(game, "Window")
	check(game.active_overlay is WindowScreenUI, "Clique na primeira janela abre a paisagem")
	if not game.active_overlay is WindowScreenUI:
		game.queue_free()
		await process_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
		quit(1)
		return
	check(game.active_overlay.get_node("View/WindowImage").texture.resource_path == "res://IMG/janela_esquerda.jpg", "Paisagem usa a imagem enviada")
	check(not game.get_node("UI").visible and not game.game_menu.visible, "Paisagem oculta a interface da livraria")
	var patience: float = game.customer_time_left
	game._process(120.0)
	check(game.customer_time_left == patience and game.customer.visible, "Observar a paisagem suspende a paciência")
	game.day_manager.waiting_for_next = true
	game.day_manager.waiting_seconds = 4.0
	game._process(120.0)
	check(game.day_manager.waiting_seconds == 4.0, "Chegadas ficam suspensas ao observar a paisagem")
	game.day_manager.waiting_for_next = false
	var screen: Node = game.active_overlay
	game._open_window()
	check(game.active_overlay == screen, "Cliques repetidos não duplicam a paisagem")
	await create_timer(0.3).timeout
	if OS.get_cmdline_user_args().has("--screenshots"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/preview_window.png")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(game.active_overlay == null and game.get_node("UI").visible and game.game_menu.visible and not paused and not game.game_menu.overlay.visible, "Esc volta à loja sem abrir a pausa")
	game._open_window()
	game.active_overlay.get_node("View/Back").pressed.emit()
	await process_frame
	check(game.active_overlay == null, "Botão Voltar fecha a paisagem")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
