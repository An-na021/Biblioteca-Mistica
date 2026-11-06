extends SceneTree

const Atmosphere = preload("res://scripts/shop_atmosphere.gd")
var failures := 0
var test_path := "res://.godot/atmosphere_test_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	var game: Node = preload("res://scenes/main.tscn").instantiate()
	game.save_path = test_path
	game.api_url = ""
	root.add_child(game)
	game._start_new_game()
	game._set_relaxed_mode(true)
	var atmosphere: Node2D = game.atmosphere
	check(game.shop_decor.lamp_cleanup.all(func(patch: Polygon2D) -> bool: return patch.visible) and not game.get_node("Lamp").input_pickable and not atmosphere.desk_lamp_emission.visible, "Sem comprar Luz de leitura, a luminária, seu brilho e sua interação ficam ausentes")
	check(atmosphere.day_progress == 0.0, "Novo expediente começa com iluminação de abertura")
	var opening := Atmosphere.color_for_progress(0.0)
	var afternoon := Atmosphere.color_for_progress(0.55)
	var evening := Atmosphere.color_for_progress(1.0)
	check(afternoon.r > afternoon.b and evening.get_luminance() < opening.get_luminance(), "Tarde ganha tons dourados e encerramento reduz a luz ambiente")
	game.day_manager.customers_today = 3
	game.day_manager.served_today = 1
	var funds: int = game.money
	var reputation: int = game.reputation
	var patience: float = game.customer_time_left
	game._update_atmosphere(15.0)
	check(atmosphere.target_progress > 1.0 / 3.0 and atmosphere.target_progress < 2.0 / 3.0, "Luz acompanha atendimentos e avança suavemente também no modo tranquilo")
	var before: float = atmosphere.day_progress
	atmosphere._process(1.0)
	check(atmosphere.day_progress > before and atmosphere.day_progress < atmosphere.target_progress, "Mudança de luz é gradual")
	check(game.money == funds and game.reputation == reputation and game.customer_time_left == patience and game.day_manager.served_today == 1, "Efeitos visuais preservam saldo, reputação, paciência e atendimentos")
	check(game.get_node("UI").get_canvas() != atmosphere.get_canvas(), "Pergaminhos, valores e menus ficam em uma camada independente da iluminação")
	game.world.upgrades = {"lighting": true, "plants": true}
	game._update_world_visuals()
	game._update_atmosphere(0.0)
	var decor: Node2D = game.shop_decor
	check(decor.lamp_cleanup.all(func(patch: Polygon2D) -> bool: return not patch.visible) and game.get_node("Lamp").input_pickable and atmosphere.desk_lamp_emission.visible, "Instalar Luz de leitura revela a luminária e ativa imediatamente seu brilho e clique")
	decor._process(0.5)
	check(decor.plant_visual.visible and float(decor.plant_material.get_shader_parameter("motion_time")) > 0.0 and atmosphere.lighting_installed, "Melhorias ativam o movimento das folhas e reforçam a luminária")
	game.game_menu.toggle_pause()
	var paused_light_time: float = atmosphere.animation_time
	var paused_plant_time: float = decor.motion_time
	await process_frame
	await process_frame
	check(atmosphere.animation_time == paused_light_time and decor.motion_time == paused_plant_time, "Pausa congela poeira, brilho e movimento das folhas")
	game.game_menu.toggle_pause()
	game._open_clock()
	var elapsed: float = atmosphere.animation_time
	game._process(60.0)
	atmosphere._process(60.0)
	check(atmosphere.animation_time == elapsed and game.customer_time_left == patience, "Inspeção do relógio suspende avanço do ambiente e atendimento")
	game.active_overlay.close()
	await process_frame
	game.store_is_open = false
	game._update_atmosphere(0.0)
	check(atmosphere.target_progress == 1.0, "Fechamento direciona a iluminação para o fim do dia")
	game._present_day_summary(true)
	check(atmosphere.day_progress == 1.0, "Resumo do dia mantém o ambiente com iluminação de encerramento")
	game.active_overlay.queue_free()
	game.active_overlay = null
	game._begin_day()
	check(atmosphere.day_progress == 0.0 and game.ambient_service_seconds == 0.0, "Reabrir a loja reinicia a iluminação")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
