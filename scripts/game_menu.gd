extends CanvasLayer

signal new_game_requested
signal continue_requested
signal relaxed_changed(enabled: bool)

var in_game := false
var overlay: Control
var title: Label
var note: Label
var continue_button: Button
var new_button: Button
var resume_button: Button
var relaxed: CheckButton
var confirmation: ConfirmationDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	var pause_button := Button.new()
	pause_button.text = "PAUSA · Esc"
	pause_button.position = Vector2(710, 25)
	pause_button.custom_minimum_size = Vector2(130, 38)
	pause_button.pressed.connect(toggle_pause)
	add_child(pause_button)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.018, 0.012, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("201f19")
	style.border_color = Color("d8b276")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	title = Label.new()
	title.text = "BIBLIOTECA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("e4c477"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Uma livraria, muitas histórias."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	resume_button = _button(content, "RETOMAR", toggle_pause)
	continue_button = _button(content, "CONTINUAR", func() -> void: continue_requested.emit())
	new_button = _button(content, "NOVO JOGO", _request_new_game)
	relaxed = CheckButton.new()
	relaxed.text = "Modo tranquilo · sem limite de tempo"
	relaxed.toggled.connect(func(enabled: bool) -> void: relaxed_changed.emit(enabled))
	content.add_child(relaxed)
	note = Label.new()
	note.custom_minimum_size.x = 420
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("cbbfa7"))
	content.add_child(note)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Começar de novo?"
	confirmation.dialog_text = "O novo jogo substituirá o progresso salvo."
	confirmation.ok_button_text = "Novo jogo"
	confirmation.cancel_button_text = "Voltar"
	confirmation.confirmed.connect(func() -> void: new_game_requested.emit())
	add_child(confirmation)
	show_start(false)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func show_start(has_save: bool) -> void:
	in_game = false
	overlay.show()
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
	if not in_game or confirmation.visible:
		return
	var pause := not overlay.visible
	overlay.visible = pause
	get_tree().paused = pause
	if pause:
		title.text = "UMA PAUSA PARA LER"
		resume_button.show()
		continue_button.hide()
		new_button.hide()
		note.text = "O atendimento e a chegada de clientes estão pausados. Esc para retomar. O progresso é salvo entre dias."
		resume_button.grab_focus()

func _request_new_game() -> void:
	if not continue_button.disabled:
		confirmation.popup_centered()
	else:
		new_game_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo() and in_game:
		toggle_pause()
		get_viewport().set_input_as_handled()
