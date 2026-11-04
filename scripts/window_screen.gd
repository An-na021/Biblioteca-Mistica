extends CanvasLayer

signal closed

const BackButtonStyle = preload("res://scripts/back_button_style.gd")
@export var image: Texture2D

var _closing := false

func _ready() -> void:
	$View/WindowImage.texture = image
	$View.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BackButtonStyle.apply($View/Back)
	$View/Back.pressed.connect(close)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	$View.modulate.a = 0.0
	create_tween().tween_property($View, "modulate:a", 1.0, 0.22)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()
