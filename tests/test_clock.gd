extends SceneTree

const Hands = preload("res://scripts/clock_hands.gd")
const ClockScreenUI = preload("res://scripts/clock_screen.gd")
var failures := 0
var test_path := "res://.godot/clock_test_%d.json" % Time.get_ticks_usec()

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

func click_clock(game: Node) -> void:
	var mouse_position: Vector2 = game.get_node("Clock").get_global_transform_with_canvas().origin
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
	var release := InputEventMouseButton.new()
	release.position = mouse_position
	release.button_index = MOUSE_BUTTON_LEFT
	root.push_input(release)
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	check(Hands.angles_for_time(12, 0, 0).is_equal_approx(Vector3.ZERO), "Meio-dia alinha os três ponteiros no 12")
	check(Hands.angles_for_time(3, 0, 0).is_equal_approx(Vector3(PI / 2, 0, 0)), "Três horas aponta para o 3 no sentido horário")
	var half_hour := Hands.angles_for_time(18, 30, 30)
	check(is_equal_approx(half_hour.x, TAU * 6.508333333 / 12.0) and is_equal_approx(half_hour.y, TAU * 30.5 / 60.0) and is_equal_approx(half_hour.z, PI), "Horas e minutos incluem o avanço proporcional dos segundos")
	check(Hands.angles_for_time(0, 0, 0).is_equal_approx(Hands.angles_for_time(12, 0, 0)), "Meia-noite e meio-dia usam o mesmo mostrador de 12 horas")
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	await process_frame
	await screenshot("preview_clock_hotspot")
	await click_clock(game)
	check(game.active_overlay is ClockScreenUI, "Clique na região do relógio da parede abre a cena exclusiva")
	if not game.active_overlay is ClockScreenUI:
		game.queue_free()
		await process_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
		quit(1)
		return
	var screen: CanvasLayer = game.active_overlay
	check(not game.get_node("UI").visible and not game.game_menu.visible, "Tela do relógio oculta a interface da loja e o botão de pausa")
	var hands: Node2D = screen.get_node("View/Clock")
	var local := Time.get_time_dict_from_system()
	var expected := Hands.angles_for_time(int(local.hour), int(local.minute), float(local.second))
	check(absf(angle_difference(hands.hand_angles.z, expected.z)) < TAU / 60.0 * 1.1, "Ponteiro de segundos coincide com o horário local do sistema")
	var before: Vector3 = hands.hand_angles
	var patience: float = game.customer_time_left
	game._process(120.0)
	check(game.customer_time_left == patience and game.customer.visible, "Observar o relógio não esgota a paciência do cliente")
	game.day_manager.waiting_for_next = true
	game.day_manager.waiting_seconds = 4.0
	game._process(120.0)
	check(game.day_manager.waiting_seconds == 4.0, "Intervalo entre clientes fica suspenso na tela do relógio")
	game.day_manager.waiting_for_next = false
	game.day_manager.waiting_for_end_notice = true
	game._process(120.0)
	check(game.store_is_open and game.day_manager.waiting_seconds == 4.0, "Aviso de fechamento também fica suspenso")
	game.day_manager.waiting_for_end_notice = false
	await create_timer(0.3).timeout
	check(hands.hand_angles != before, "Ponteiros continuam se movendo enquanto a loja está suspensa")
	await screenshot("preview_clock")
	root.size = Vector2i(720, 1000)
	await process_frame
	await process_frame
	var view: Control = screen.get_node("View")
	var frame_half_size := Vector2(325, 335) * hands.scale
	check(hands.position.x - frame_half_size.x >= 0 and hands.position.y - frame_half_size.y >= 0 and hands.position.x + frame_half_size.x <= view.size.x and hands.position.y + frame_half_size.y <= view.size.y, "Moldura inteira cabe em uma janela vertical")
	await screenshot("preview_clock_portrait")
	root.size = Vector2i(1280, 720)
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(game.active_overlay == null and game.get_node("UI").visible and game.game_menu.visible and not paused and not game.game_menu.overlay.visible, "Esc volta à loja sem abrir o menu de pausa")
	game._on_interactable_clicked(game.get_node("Clock"))
	var reopened: CanvasLayer = game.active_overlay
	game._open_clock()
	check(game.active_overlay == reopened, "Cliques repetidos não criam telas duplicadas")
	reopened.get_node("View/Back").pressed.emit()
	await process_frame
	check(game.active_overlay == null and game.customer_time_left <= patience, "Botão Voltar restaura a loja e o atendimento")
	game._set_relaxed_mode(true)
	game._open_clock()
	check(game.active_overlay is ClockScreenUI, "Relógio real também está disponível no modo tranquilo")
	game.active_overlay.close()
	await process_frame
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
