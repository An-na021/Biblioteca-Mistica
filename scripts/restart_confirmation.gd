extends Control

signal confirmed

const Art = preload("res://scripts/hud_art.gd")
const Wood = preload("res://scripts/back_button_style.gd")
const DESIGN_SIZE := Vector2(640, 360)
var panel: Control
var confirm_button: Button
var cancel_button: Button
var close_button: Button
var previous_focus: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.015, 0.008, 0.66)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = Control.new()
	panel.name = "RestartParchment"
	panel.size = DESIGN_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var parchment := NinePatchRect.new()
	parchment.texture = Art.cutout(Art.DIALOGUE, Rect2(18, 120, 2128, 468))
	# Preserve the pins, curled edges and seal instead of stretching them tall.
	parchment.size = DESIGN_SIZE / 0.36
	parchment.scale = Vector2.ONE * 0.36
	parchment.patch_margin_left = 320
	parchment.patch_margin_right = 240
	parchment.patch_margin_top = 100
	parchment.patch_margin_bottom = 120
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(parchment)
	var stamp := Art.BookStamp.new()
	stamp.position = Vector2(34, 153)
	stamp.size = Vector2(48, 38)
	panel.add_child(stamp)
	_label("Começar de novo?", Rect2(110, 67, 407, 46), 31, false)
	_label("O novo jogo substituirá o progresso salvo.", Rect2(112, 130, 404, 79), 23, true)
	confirm_button = _button("Novo jogo", Rect2(142, 246, 172, 49))
	confirm_button.name = "ConfirmNewGame"
	confirm_button.add_theme_color_override("font_color", Color("683725"))
	confirm_button.pressed.connect(_confirm)
	cancel_button = _button("Voltar", Rect2(336, 246, 172, 49))
	cancel_button.name = "CancelRestart"
	cancel_button.pressed.connect(close)
	close_button = _button("×", Rect2(533, 57, 37, 37))
	close_button.name = "Close"
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.tooltip_text = "Voltar"
	close_button.pressed.connect(close)
	var controls: Array[Button] = [cancel_button, confirm_button, close_button]
	for index in range(controls.size()):
		var button := controls[index]
		button.focus_next = button.get_path_to(controls[(index + 1) % controls.size()])
		button.focus_previous = button.get_path_to(controls[posmod(index - 1, controls.size())])
	confirm_button.focus_neighbor_right = confirm_button.get_path_to(cancel_button)
	cancel_button.focus_neighbor_left = cancel_button.get_path_to(confirm_button)
	resized.connect(_layout)
	_layout()
	hide()

func popup_centered() -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	show()
	_layout()
	cancel_button.grab_focus()

func close() -> void:
	hide()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func _confirm() -> void:
	if not visible:
		return
	hide()
	confirmed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()

func _layout() -> void:
	var available := size - Vector2(24, 24)
	var zoom := minf(1.0, minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y))
	panel.scale = Vector2.ONE * maxf(0.1, zoom)
	panel.position = (size - DESIGN_SIZE * panel.scale) * 0.5

func _button(text: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	Wood.apply(button)
	button.add_theme_font_override("font", Art.handwriting(false))
	button.add_theme_font_size_override("font_size", 21)
	panel.add_child(button)
	return button

func _label(text: String, rect: Rect2, font_size: int, italic: bool) -> void:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Art.handwriting(italic))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Art.INK)
	panel.add_child(label)
