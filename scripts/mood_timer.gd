class_name MoodTimer
extends Control

const TIMER_SIZE := Vector2(176.0, 176.0)
const FRAME: Texture2D = preload("res://IMG/timer_frame.png")
const PROGRESS_SHADER: Shader = preload("res://shaders/timer_progress.gdshader")
const FACE_CENTER := Vector2(0.499, 0.510)
const GLASS_COLOR := Color("c2db8e")

var mood_color := GLASS_COLOR
var time_left := 0.0
var duration := 1.0
var time_label: Label
var _glass: ShaderMaterial

func _ready() -> void:
	custom_minimum_size = TIMER_SIZE
	size = TIMER_SIZE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Leave room for the hanging calendar and coin tabs above the timer.
	offset_left = -210.0
	offset_top = 158.0
	offset_right = -34.0
	offset_bottom = 334.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass = ShaderMaterial.new()
	_glass.shader = PROGRESS_SHADER
	var frame := TextureRect.new()
	frame.texture = FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.material = _glass
	add_child(frame)

	time_label = Label.new()
	time_label.name = "RemainingTime"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	font.font_italic = true
	time_label.add_theme_font_override("font", font)
	time_label.add_theme_font_size_override("font_size", 28)
	time_label.add_theme_color_override("font_color", Color("f0c891"))
	time_label.size = Vector2(104, 40)
	add_child(time_label)
	resized.connect(_layout_time)
	_layout_time()
	_refresh_display()

func _layout_time() -> void:
	# Compensate for the italic font's descent so the visible digits sit on the slate center.
	time_label.position = size * FACE_CENTER - time_label.size * 0.5 - Vector2(0, 3)

func setup(mood_type: String, time_limit: float) -> void:
	duration = maxf(time_limit, 0.01)
	time_left = duration
	match mood_type:
		"apressado": mood_color = Color("e4a34d")
		"indeciso": mood_color = Color("bba2d4")
		"colecionador": mood_color = Color("a8bd7d")
		"negociador": mood_color = Color("88b6bd")
		"dificil": mood_color = Color("d58c78")
		_: mood_color = GLASS_COLOR
	visible = true
	_refresh_display()

func set_time_left(value: float) -> void:
	time_left = clampf(value, 0.0, duration)
	_refresh_display()

func _refresh_display() -> void:
	if time_label == null:
		return
	var seconds := ceili(time_left)
	time_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	var ratio := clampf(time_left / duration, 0.0, 1.0)
	var glow := Color("e69465") if ratio <= 0.25 else GLASS_COLOR.lerp(mood_color, 0.18)
	_glass.set_shader_parameter("remaining", ratio)
	_glass.set_shader_parameter("glow_tint", glow)
