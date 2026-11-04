class_name NewspaperScreen
extends CanvasLayer

signal closed

const BackButtonStyle = preload("res://scripts/back_button_style.gd")
var _closing := false
var _day := 1
var _daily_event: Dictionary = {}

@onready var view: Control = $View
@onready var event_content: VBoxContainer = $View/EventContent

func _ready() -> void:
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.resized.connect(_layout_event)
	if _daily_event.is_empty():
		_daily_event = preload("res://scripts/shop_world.gd").event_for_day(_day)
	_update_event()
	_layout_event()
	BackButtonStyle.apply($View/Back)
	$View/Back.pressed.connect(close)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	view.modulate.a = 0.0
	create_tween().tween_property(view, "modulate:a", 1.0, 0.22)

func configure(day: int, daily_event: Dictionary) -> void:
	_day = day
	_daily_event = daily_event.duplicate(true)
	if is_node_ready():
		_update_event()

func _update_event() -> void:
	$View/EventContent/Edition.text = "HOJE · DIA %d" % _day
	$View/EventContent/Title.text = str(_daily_event.get("name", ""))
	$View/EventContent/Description.text = str(_daily_event.get("description", ""))

func _layout_event() -> void:
	# Match the centered, aspect-preserving image so the ink stays on the right page.
	var image_size: Vector2 = $View/Newspaper.texture.get_size()
	var zoom := minf(view.size.x / image_size.x, view.size.y / image_size.y)
	var image_origin := (view.size - image_size * zoom) * 0.5
	event_content.position = image_origin + Vector2(855, 170) * zoom
	event_content.size = Vector2(530, 0)
	event_content.scale = Vector2.ONE * zoom

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
