class_name DistrictScreen
extends Control

signal closed
signal district_selected(district_id: String)

const PANEL := Color("201f19")
const CARD := Color("2d2c23")
const GOLD := Color("e4c477")
const MUTED := Color("b9ad96")
const GREEN := Color("a8c184")

func setup(districts: Array, selected_id: String) -> void:
	build(districts, selected_id)

func build(districts: Array, selected_id: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.012, 0.009, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 520)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD, 2, 18))
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	layout.add_child(_label("BAIRROS DA CIDADE", 22, GOLD))
	layout.add_child(_label("Cada região traz clientes e livros diferentes.", 12, MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for district in districts:
		var district_id := str(district.get("id", ""))
		var unlocked := bool(district.get("unlocked", false))
		var current := district_id == selected_id
		var button := Button.new()
		button.custom_minimum_size.y = 72
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var state := "ATUAL" if current else ("DESBLOQUEADO" if unlocked else "BLOQUEADO")
		var description := str(district.get("description", "Explore uma nova região."))
		var unlock_hint := "" if unlocked else "\n" + str(district.get("unlock_hint", "Ainda indisponível"))
		button.text = "%s  ·  %s\n%s%s" % [str(district.get("name", "Bairro")), state, description, unlock_hint]
		button.disabled = not unlocked
		button.tooltip_text = description
		_style_button(button, current, unlocked)
		button.pressed.connect(_emit_district_selected.bind(district_id))
		list.add_child(button)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(footer)
	var close := Button.new()
	close.text = "VOLTAR"
	close.custom_minimum_size = Vector2(180, 40)
	_style_button(close, true, true)
	close.pressed.connect(func() -> void: closed.emit())
	footer.add_child(close)

func _emit_district_selected(district_id: String) -> void:
	district_selected.emit(district_id)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(background: Color, border: Color, width: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.set_content_margin_all(padding)
	return style

func _style_button(button: Button, selected: bool, enabled: bool) -> void:
	var background := Color("3b4033") if enabled else Color("292b25")
	var border := Color("e4c477") if selected else Color("666047")
	button.add_theme_color_override("font_color", Color("fff0c7") if enabled else MUTED)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_color_override("font_hover_color", Color("211b14"))
	button.add_theme_font_size_override("font_size", 12)
	var normal := _panel_style(background, border, 1 if not selected else 2, 9)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("efd99e")
	hover.border_color = Color("fff0c7")
	button.add_theme_stylebox_override("hover", hover)
