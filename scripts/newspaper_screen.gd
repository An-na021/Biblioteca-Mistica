class_name NewspaperScreen
extends CanvasLayer

signal closed

var _closing := false

@onready var view: Control = $View

func _ready() -> void:
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$View/Back.pressed.connect(close)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	view.modulate.a = 0.0
	create_tween().tween_property(view, "modulate:a", 1.0, 0.22)

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
