extends SceneTree

var failures := 0
var test_path := "res://.godot/newspaper_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func screenshot(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func click_hotspot(game: Node) -> void:
	var mouse_position: Vector2 = game.get_node("NewspaperHotspot").get_global_transform_with_canvas().origin
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

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	await process_frame
	await click_hotspot(game)
	check(game.active_overlay is NewspaperScreen, "Clique no jornal abre a tela exclusiva")
	check(not game.get_node("UI").visible and not game.game_menu.visible, "Tela do jornal oculta a interface da loja")
	check(game.active_overlay.get_node("View").size == Vector2(root.size), "Tela ampliada ocupa toda a janela")
	check(game.active_overlay.get_node("View/Newspaper").texture.resource_path == "res://IMG/newspaper_open.png", "Tela usa a imagem original enviada")
	var patience: float = game.customer_time_left
	game._process(120.0)
	check(game.customer_time_left == patience and game.customer.visible, "Leitura do jornal suspende a paciência do cliente")
	await create_timer(0.3).timeout
	await screenshot("preview_newspaper_screen")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(game.active_overlay == null and game.get_node("UI").visible and game.game_menu.visible and not paused and not game.game_menu.overlay.visible, "Esc fecha o jornal e restaura a loja sem abrir a pausa")
	game._open_newspaper()
	game.active_overlay.get_node("View/Back").pressed.emit()
	await process_frame
	check(game.active_overlay == null, "Botão Voltar fecha o jornal")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
