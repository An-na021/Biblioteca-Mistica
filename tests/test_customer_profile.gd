extends SceneTree

var failures := 0
var test_path := "res://.godot/profile_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func field(panel: CustomerProfilePanel, node_name: String) -> Label:
	return panel.find_child(node_name, true, false) as Label

func screenshot(filename: String) -> void:
	if OS.get_cmdline_user_args().has("--screenshots"):
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/" + filename + ".png")

func show_profile(game: Node, profile: Dictionary) -> CustomerProfilePanel:
	game.customer.free()
	game.customer = load(str(profile.scene_path)).instantiate()
	game.customer_spawn.add_child(game.customer)
	game.customer.configure(profile, BookCatalog.get_book("jardim_horas"), 0, {"story": "Este leitor já voltou à livraria.", "patience_bonus": 10.0})
	game._on_interactable_clicked(game.customer)
	return game.active_overlay as CustomerProfilePanel

func run() -> void:
	root.size = Vector2i(1280, 720)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	for profile in game.CUSTOMER_PROFILES:
		var panel := show_profile(game, profile)
		await process_frame
		await process_frame
		check(panel != null and field(panel, "CustomerName").text == str(profile.name), "Ficha usa o nome configurado: " + str(profile.name))
		check(field(panel, "RequestClue").text == game.customer.get_request_clue().text and field(panel, "Behavior").text == game.customer.behavior_hint(), "Pedido e comportamento acompanham o cliente e as melhorias")
		check(field(panel, "ConditionBadge").text == str(BookCatalog.get_condition(str(profile.preferred_condition)).label).to_upper(), "Condição preferida acompanha o perfil")
		check(field(panel, "Personality").text == str(profile.personality) and field(panel, "History").text == str(profile.history), "Personalidade e história pertencem ao cliente atual")
		var portrait: Texture2D = game.customer.portrait.texture
		check(portrait != null and panel.customer == game.customer and game.customer.get_node("Portrait").visible, "Ficha mantém o personagem da cena configurada")
		check(root.get_visible_rect().encloses(panel.sheet.get_global_rect()), "Papel permanece dentro da janela")
		var patience: float = game.customer_time_left
		game._process(1.0)
		check(game.customer_time_left == patience, "Ler a ficha preserva a paciência do cliente")
		game._show_customer_profile()
		check(game.active_overlay == panel, "Abrir novamente mantém uma única ficha")
		await screenshot("preview_profile_" + str(profile.id))
		panel.more_button.pressed.emit()
		check(panel.details.visible and field(panel, "Memory").text == "Este leitor já voltou à livraria.", "Ver mais revela a história e a memória da visita")
		panel.more_button.pressed.emit()
		check(not panel.details.visible, "Ver menos recolhe os detalhes")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape)
		await process_frame
		check(game.active_overlay == null and not paused and not game.customer._selected and game.customer.portrait.texture == portrait, "Esc fecha a ficha e mantém a aparência do personagem sem abrir a pausa")

	var custom: Dictionary = game.CUSTOMER_PROFILES[5].duplicate(true)
	custom.name = "Dra. Estela das Montanhas Luminosas, pesquisadora de histórias e jardins"
	custom.personality = "Cuidadosa, curiosa e interessada nas descobertas da cidade."
	custom.history = "Veio pesquisar as plantas e as antigas rotas da região."
	custom.preferred_condition = "usado"
	custom.preference_tags = ["natureza", "engenharia"]
	custom.mood_type = "negociador"
	custom.portrait_path = "res://IMG/characters/Evelune.png"
	var custom_panel := show_profile(game, custom)
	await process_frame
	await process_frame
	check(field(custom_panel, "CustomerName").text == custom.name and field(custom_panel, "ConditionBadge").text == "USADO" and field(custom_panel, "Behavior").text.begins_with("Negociador"), "Ficha aceita nomes longos e parâmetros personalizados")
	check(game.customer.portrait.texture.resource_path == custom.portrait_path and custom_panel.find_child("PreferenceTags", true, false).get_child_count() == 2, "Retrato e preferências respeitam a configuração personalizada")
	custom_panel.more_button.pressed.emit()
	await screenshot("preview_profile_custom")
	root.size = Vector2i(720, 1000)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(custom_panel.sheet.get_global_rect()), "Ficha cabe em uma janela vertical")
	await screenshot("preview_profile_portrait")
	custom_panel.close()
	await process_frame
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
