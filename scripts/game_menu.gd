extends CanvasLayer

const HudArt = preload("res://scripts/hud_art.gd")
const PauseBookUI = preload("res://scripts/pause_book.gd")
const StartBookUI = preload("res://scripts/start_book.gd")
const BackButtonStyle = preload("res://scripts/back_button_style.gd")

signal new_game_requested
signal continue_requested
signal relaxed_changed(enabled: bool)

var in_game := false
var pause_enabled := true
var overlay: Control
var title: Label
var note: Label
var continue_button: Button
var new_button: Button
var resume_button: Button
var relaxed: CheckButton
var confirmation: ConfirmationDialog
var pause_button: Button
var start_menu: Control
var pause_book: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	pause_button = Button.new()
	pause_button.text = "PAUSA · Esc"
	pause_button.position = Vector2(694, 18)
	pause_button.custom_minimum_size = Vector2(172, 68)
	HudArt.style_pause(pause_button)
	pause_button.pressed.connect(toggle_pause)
	add_child(pause_button)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.018, 0.012, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	start_menu = StartBookUI.new()
	overlay.add_child(start_menu)
	title = start_menu.title
	note = start_menu.note
	continue_button = start_menu.continue_button
	new_button = start_menu.new_button
	start_menu.continue_requested.connect(func() -> void: continue_requested.emit())
	start_menu.new_game_requested.connect(_request_new_game)
	# Keep the saved setting shared with the pause menu; the initial book has two actions.
	relaxed = CheckButton.new()
	relaxed.hide()
	add_child(relaxed)
	relaxed.toggled.connect(func(enabled: bool) -> void:
		pause_book.set_relaxed(enabled)
		relaxed_changed.emit(enabled)
	)
	pause_book = PauseBookUI.new()
	overlay.add_child(pause_book)
	resume_button = pause_book.resume_button
	pause_book.resume_requested.connect(toggle_pause)
	pause_book.relaxed_changed.connect(func(enabled: bool) -> void: relaxed.button_pressed = enabled)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Começar de novo?"
	confirmation.dialog_text = "O novo jogo substituirá o progresso salvo."
	confirmation.ok_button_text = "Novo jogo"
	confirmation.cancel_button_text = "Voltar"
	BackButtonStyle.apply(confirmation.get_cancel_button())
	confirmation.confirmed.connect(func() -> void: new_game_requested.emit())
	add_child(confirmation)
	show_start(false)

func show_start(has_save: bool) -> void:
	in_game = false
	overlay.show()
	start_menu.show()
	pause_book.hide()
	title.text = "BIBLIOTECA"
	resume_button.hide()
	continue_button.show()
	continue_button.disabled = not has_save
	new_button.disabled = false
	note.text = "O progresso é salvo ao abrir e fechar cada dia e nas compras entre dias. Ao continuar um dia em andamento, ele recomeça."
	get_tree().paused = true
	if has_save:
		continue_button.grab_focus()
	else:
		new_button.grab_focus()

func enter_game() -> void:
	in_game = true
	overlay.hide()
	get_tree().paused = false

func toggle_pause() -> void:
	if not in_game or not pause_enabled or confirmation.visible:
		return
	var pause := not overlay.visible
	overlay.visible = pause
	get_tree().paused = pause
	if pause:
		start_menu.hide()
		pause_book.show()
		pause_book.set_relaxed(relaxed.button_pressed)
		resume_button.show()
		continue_button.hide()
		new_button.hide()
		note.text = "O atendimento e a chegada de clientes estão pausados. Esc para retomar. O progresso é salvo entre dias."
		resume_button.grab_focus()

func set_pause_enabled(enabled: bool) -> void:
	pause_enabled = enabled
	pause_button.visible = enabled

func set_relaxed(enabled: bool) -> void:
	relaxed.set_pressed_no_signal(enabled)
	pause_book.set_relaxed(enabled)

func _request_new_game() -> void:
	if not continue_button.disabled:
		confirmation.popup_centered()
	else:
		new_game_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and in_game and pause_enabled:
		toggle_pause()
		get_viewport().set_input_as_handled()
