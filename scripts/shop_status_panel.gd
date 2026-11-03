extends Panel

const Art = preload("res://scripts/hud_art.gd")

var day_value: Label
var money_value: Label
var reputation_value: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -396
	offset_top = 6
	offset_right = -14
	offset_bottom = 140
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	$StatusLabel.hide()
	var parchment := TextureRect.new()
	parchment.texture = Art.cutout(Art.STATUS, Rect2(60, 8, 2064, 712))
	parchment.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	parchment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(parchment)
	_label("DIA", Vector2(17, 33), Vector2(76, 22), 14)
	day_value = _label("1", Vector2(22, 81), Vector2(57, 39), 31)
	_label("MOEDAS", Vector2(100, 33), Vector2(77, 22), 13)
	money_value = _label("0", Vector2(103, 64), Vector2(47, 35), 26)
	_label("REPUTAÇÃO", Vector2(187, 33), Vector2(113, 24), 14)
	reputation_value = _label("0", Vector2(319, 31), Vector2(46, 34), 24, Color("ffe2ac"))

func set_values(day: int, money: int, reputation: int) -> void:
	day_value.text = str(day)
	money_value.text = str(money)
	reputation_value.text = str(reputation)
	_fit_number(day_value, 31, 57)
	_fit_number(money_value, 26, 44)
	_fit_number(reputation_value, 24, 46)
	tooltip_text = "Dia %d · Moedas: %d · Reputação: %d" % [day, money, reputation]

func _fit_number(label: Label, preferred_size: int, available_width: float) -> void:
	var font_size := preferred_size
	var font := label.get_theme_font("font")
	while font_size > 8 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)
	label.size.x = available_width

func _label(value: String, at: Vector2, dimensions: Vector2, font_size: int, color := Art.INK) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Art.handwriting(false))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
