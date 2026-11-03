class_name DialoguePanel
extends Control

const Art = preload("res://scripts/hud_art.gd")

@onready var speaker_label: Label = $Panel/SpeakerLabel
@onready var text_label: Label = $Panel/TextLabel
var _underline: ColorRect
var _stamp: Control

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(10, 8)
	size = Vector2(640, 136)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var parchment := TextureRect.new()
	parchment.texture = Art.cutout(Art.DIALOGUE, Rect2(18, 120, 2128, 468))
	parchment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parchment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel.add_child(parchment)
	$Panel.move_child(parchment, 0)
	_stamp = Art.BookStamp.new()
	_stamp.size = Vector2(44, 33)
	$Panel.add_child(_stamp)
	for label in [speaker_label, text_label]:
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", Art.handwriting())
		label.add_theme_color_override("font_color", Art.INK)
	speaker_label.add_theme_font_size_override("font_size", 24)
	text_label.add_theme_font_size_override("font_size", 17)
	_underline = ColorRect.new()
	_underline.color = Color(0.28, 0.17, 0.07, 0.6)
	_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel.add_child(_underline)
	speaker_label.minimum_size_changed.connect(_layout_message)
	text_label.minimum_size_changed.connect(_layout_message)
	_layout_message()

func show_message(speaker: String, message: String) -> void:
	speaker_label.text = speaker
	text_label.text = message
	_layout_message.call_deferred()

func _layout_message() -> void:
	var text_width := size.x * 0.88 - 85.0
	speaker_label.size = Vector2(text_width, 0)
	var speaker_height := maxf(30.0, speaker_label.get_minimum_size().y)
	text_label.size = Vector2(text_width - 3.0, 0)
	size.y = maxf(136.0, (speaker_height + text_label.get_minimum_size().y + 18.0) / 0.73)
	# Keep the title below the torn upper edge as the parchment grows taller.
	speaker_label.position = Vector2(85, size.y * 0.15)
	text_label.position = Vector2(88, speaker_label.position.y + speaker_height + 10.0)
	_underline.position = Vector2(85, speaker_label.position.y + speaker_height + 2.0)
	var name_width := speaker_label.get_theme_font("font").get_string_size(speaker_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_underline.size = Vector2(minf(name_width, text_width), 1)
	_stamp.position = Vector2(14, size.y * 0.49 - 16.5)
