extends SceneTree

var failures := 0
var restarts := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1280, 720)
	var menu := preload("res://scripts/game_menu.gd").new()
	root.add_child(menu)
	menu.new_game_requested.connect(func() -> void: restarts += 1)
	menu.show_start(true)
	menu._request_new_game()
	var dialog: Control = menu.confirmation
	check(dialog.visible and restarts == 0 and dialog.cancel_button.has_focus(), "Abrir confirmação não reinicia e deixa Voltar selecionado")
	dialog.cancel_button.pressed.emit()
	check(not dialog.visible and restarts == 0, "Voltar fecha o aviso sem iniciar novo jogo")
	menu._request_new_game()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(not dialog.visible and restarts == 0, "Esc cancela a confirmação sem reiniciar")
	menu._request_new_game()
	dialog.close_button.pressed.emit()
	check(not dialog.visible and restarts == 0, "Botão de fechar também cancela")
	menu._request_new_game()
	root.size = Vector2i(360, 600)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(dialog.panel.get_global_rect()), "Pergaminho inteiro cabe em janela estreita")
	dialog.confirm_button.pressed.emit()
	dialog.confirm_button.pressed.emit()
	check(not dialog.visible and restarts == 1, "Novo jogo confirma uma única vez")
	menu.show_start(false)
	menu._request_new_game()
	check(not dialog.visible and restarts == 2, "Sem progresso salvo, novo jogo mantém o fluxo direto")
	paused = false
	menu.queue_free()
	await process_frame
	print("RESULT: ", failures, " failure(s)")
	quit(1 if failures > 0 else 0)
