extends CanvasLayer

signal closed

const BackButtonStyle = preload("res://scripts/back_button_style.gd")
@export var image: Texture2D
var weather_kind := "clear"
var ambient_tint := Color.WHITE
var _weather_material: ShaderMaterial
var _audio: Node
var _elapsed := 0.0

var _closing := false

func _ready() -> void:
	$View/WindowImage.texture = image
	_weather_material = ShaderMaterial.new()
	_weather_material.shader = preload("res://shaders/window_weather.gdshader")
	_weather_material.set_shader_parameter("weather", 2.0 if weather_kind == "rain" else 1.0 if weather_kind == "cloudy" else 0.0)
	_weather_material.set_shader_parameter("daylight", ambient_tint)
	$View/WindowImage.material = _weather_material
	_audio = preload("res://scripts/game_audio.gd").new()
	_audio.base_db = -29
	add_child(_audio)
	$View.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	BackButtonStyle.apply($View/Back)
	$View/Back.pressed.connect(close)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	$View.modulate.a = 0.0
	create_tween().tween_property($View, "modulate:a", 1.0, 0.22)

func _process(delta: float) -> void:
	if _closing:
		return
	_elapsed += delta
	_weather_material.set_shader_parameter("motion_time", _elapsed)
	_audio.engage("rain" if weather_kind == "rain" else "wind" if weather_kind == "cloudy" else "street", 0.5)

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
