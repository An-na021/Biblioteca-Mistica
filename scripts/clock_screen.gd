extends CanvasLayer
## A separate view keeps the shop intact while the real clock keeps running.

signal closed

const IMAGE_PIVOT := Vector2(669, 654)
var _closing := false

@onready var view: Control = $View
@onready var background: TextureRect = $View/Background
@onready var clock: Node2D = $View/Clock

func _ready() -> void:
	view.resized.connect(_layout_clock)
	$View/Back.pressed.connect(close)
	_layout_clock()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	view.modulate.a = 0.0
	create_tween().tween_property(view, "modulate:a", 1.0, 0.22)

func _layout_clock() -> void:
	# Leave the whole wooden frame visible in wide and tall windows.
	var zoom := minf(view.size.x / 700.0, view.size.y / 710.0)
	background.size = background.texture.get_size() * zoom
	background.position = view.size * 0.5 - IMAGE_PIVOT * zoom
	clock.position = view.size * 0.5
	clock.scale = Vector2.ONE * zoom

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	# Also allows this scene to be previewed on its own with F6.
	queue_free()
