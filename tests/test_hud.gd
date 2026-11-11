extends SceneTree

var failures := 0
var test_path := "res://.godot/hud_test_%d.json" % Time.get_ticks_usec()

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

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	game.customer.free()
	var profile: Dictionary = game.CUSTOMER_PROFILES[5]
	game.customer = load(str(profile.scene_path)).instantiate()
	game.customer_spawn.add_child(game.customer)
	game.customer.configure(profile, BookCatalog.get_book("jardim_horas"))
	game.day_manager.day = 3
	game.money = 3
	game.reputation = 1
	game._update_status()
	game.dialogue_panel.show_message(game.customer.customer_name, "Queria uma leitura com magia. Não lembro o nome do livro.")
	await process_frame
	await process_frame
	var status: Panel = game.get_node("UI/StatusPanel")
	check(status.day_value.text == "3" and status.money_value.text == "3" and status.reputation_value.text == "1", "Pergaminho mostra dia, moedas e reputação atuais")
	check(not status.get_global_rect().intersects(game.dialogue_panel.get_global_rect()) and not status.get_global_rect().intersects(game.game_menu.pause_button.get_global_rect()), "Indicadores, pausa e diálogo têm espaços próprios")
	await screenshot("preview_hud")
	game.money = 12345
	game.reputation = -12
	game._update_status()
	check(status.money_value.text == "12345" and status.reputation_value.text == "-12", "Indicadores atualizam valores grandes e reputação negativa")
	check(status.money_value.get_minimum_size().x <= 44 and status.reputation_value.get_minimum_size().x <= 46, "Valores grandes cabem nos campos de moedas e no selo")
	var long_name := "Dra. Estela das Montanhas Luminosas, pesquisadora de histórias e jardins"
	var long_message := "Gostei de O Jardim das Horas, que levei daqui. Vim buscar minha encomenda: O Reino de Vidro, na condição Raro. Separei quatro moedas extras pelo cuidado. Espero também encontrar outros relatos sobre natureza, mapas antigos e as histórias dos viajantes desta região."
	game.dialogue_panel.show_message(long_name, long_message)
	await process_frame
	await process_frame
	var dialogue: DialoguePanel = game.dialogue_panel
	check(dialogue.speaker_label.text == long_name and dialogue.text_label.text == long_message, "Diálogo mantém o nome e a fala completos")
	check(not dialogue.speaker_label.get_global_rect().intersects(dialogue.text_label.get_global_rect()) and dialogue.get_global_rect().encloses(dialogue.text_label.get_global_rect()), "Pergaminho cresce para acomodar nomes e falas longas")
	check(dialogue.text_label.get_rect().end.x <= dialogue.size.x * 0.89 and dialogue.text_label.get_rect().end.y <= dialogue.size.y * 0.9, "Fala longa mantém margem antes das bordas do papel")
	await screenshot("preview_hud_long_dialogue")
	game._show_customer_profile()
	await process_frame
	check(not game.active_overlay.sheet.get_global_rect().intersects(status.get_global_rect()), "Ficha do cliente deixa o calendário e os valores visíveis")
	game.active_overlay.close()
	await process_frame
	game.game_menu.pause_button.pressed.emit()
	check(paused and game.game_menu.overlay.visible, "Placa de madeira abre a pausa")
	game.game_menu.toggle_pause()
	game._set_relaxed_mode(false)
	await process_frame
	check(not game.mood_timer.get_global_rect().intersects(status.get_global_rect()), "Relógio de paciência fica abaixo dos indicadores")
	game.set_process(false)
	game.mood_timer.setup("colecionador", 60.0)
	game.mood_timer.set_time_left(58.0)
	check(game.mood_timer.time_label.text == "00:58", "Novo mostrador exibe o tempo restante ao vivo")
	await screenshot("preview_timer_58")
	game.mood_timer.set_time_left(30.0)
	await screenshot("preview_timer_half")
	game.mood_timer.set_time_left(10.0)
	await screenshot("preview_timer_low")
	game.mood_timer.set_time_left(-1.0)
	check(game.mood_timer.time_label.text == "00:00" and game.mood_timer.time_left == 0.0, "Temporizador termina em zero sem exibir tempo negativo")
	await screenshot("preview_timer_empty")
	var plant: Interactable = game.shop_decor.plant_hotspot
	check(not plant.visible and not plant.input_pickable, "Vaso sem melhoria instalada não recebe cliques")
	game.shop_decor.update_state({"plants": true})
	# Isolate the simulated pointer from the real cursor in rendered test runs.
	var picking_enabled := root.physics_object_picking
	root.physics_object_picking = false
	await physics_frame
	await process_frame
	plant.mouse_entered.emit()
	plant._glow_tween.custom_step(0.25)
	check(plant._hovered and plant._glow_strength > 0.0, "Passar o mouse sobre a planta acende o retângulo dourado")
	var plant_click := InputEventMouseButton.new()
	plant_click.button_index = MOUSE_BUTTON_LEFT
	plant_click.pressed = true
	plant._input_event(root, plant_click, 0)
	check(plant.visible and plant.input_pickable and not plant._selected and plant._selection_tween == null, "Clicar na planta não mantém o retângulo selecionado")
	check(dialogue.speaker_label.text == "Vaso de flores" and dialogue.text_label.text == plant.description, "Clique no vaso mostra sua descrição e o bônus de recomendações")
	await screenshot("preview_plant_hover")
	plant.mouse_exited.emit()
	check(not plant._hovered and not plant._selected and plant._glow_strength == 0.0 and plant._glow_tween == null, "Retirar o mouse apaga o retângulo, mesmo depois de clicar")
	await screenshot("preview_plant_after_exit")
	game._on_interactable_clicked(game.shop_decor.shelf.get_node("ShelfHotspot"))
	check(not plant._selected, "Inspecionar outro objeto remove a seleção do vaso")
	game.shop_decor.update_state({})
	check(not plant.visible and not plant.input_pickable and not plant._selected, "Ocultar o vaso desativa sua interação e seleção")
	root.physics_object_picking = picking_enabled
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
