class_name CustomerProfilePanel
extends Control

signal closed

const PANEL_BG := Color("172019")
const CARD_BG := Color("252d24")
const GOLD := Color("e4c477")
const GOLD_SOFT := Color("9d7e3f")
const TEXT_PRIMARY := Color("f3ead6")
const TEXT_MUTED := Color("c2b89f")
const GREEN := Color("9eb77a")

var customer: Customer
var profile: Dictionary = {}


func setup(value_customer: Customer, value_profile: Dictionary) -> void:
	customer = value_customer
	profile = value_profile
	_build()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.012, 0.009, 0.32)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-430, 104)
	panel.size = Vector2(395, 525)
	panel.add_theme_stylebox_override("panel", _make_panel_style(PANEL_BG, GOLD, 2, 18, 12))
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_child(_make_label("FICHA DO CLIENTE", 22, GOLD))
	title_stack.add_child(_make_label("Informações para um atendimento mais pessoal", 11, TEXT_MUTED))
	header.add_child(title_stack)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Fechar ficha"
	close.custom_minimum_size = Vector2(32, 32)
	_style_button(close, false)
	close.add_theme_font_size_override("font_size", 20)
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)

	var name_card := PanelContainer.new()
	name_card.add_theme_stylebox_override("panel", _make_panel_style(Color("3a3021"), GOLD_SOFT, 1, 10, 7))
	layout.add_child(name_card)
	var name_layout := VBoxContainer.new()
	name_layout.add_theme_constant_override("separation", 3)
	name_card.add_child(name_layout)
	name_layout.add_child(_make_label(str(profile.get("name", customer.customer_name)), 19, TEXT_PRIMARY))
	name_layout.add_child(_make_label("CLIENTE ATUAL", 11, GREEN))

	if not customer.get_request_clue().is_empty():
		layout.add_child(_make_requested_book_card())
	layout.add_child(_make_condition_preference_card())

	layout.add_child(_make_label("GOSTA DE", 11, GOLD))
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 6)
	tags.add_theme_constant_override("v_separation", 5)
	for tag in profile.get("preference_tags", []):
		tags.add_child(_make_tag_chip(_preference_name(str(tag))))
	layout.add_child(tags)

	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	details.visible = false
	layout.add_child(details)
	details.add_child(_make_section("JEITO DE SER", str(profile.get("personality", "Ainda não conhecemos bem este cliente."))))
	details.add_child(_make_section("SUA HISTÓRIA", str(profile.get("history", "Nenhum registro disponível."))))
	var more := Button.new()
	more.text = "VER MAIS SOBRE O CLIENTE  +"
	more.custom_minimum_size.y = 34
	_style_button(more, false)
	more.pressed.connect(func() -> void:
		details.visible = not details.visible
		more.text = "VER MENOS  −" if details.visible else "VER MAIS SOBRE O CLIENTE  +"
	)
	layout.add_child(more)

	var hint := _make_label("Escolha uma leitura que combine com o perfil.", 11, TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)


func _make_requested_book_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_panel_style(Color("3a3021"), GOLD_SOFT, 1, 8, 7))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	card.add_child(info)
	var clue: Dictionary = customer.get_request_clue()
	var clue_type := str(clue.get("type", "titulo")).to_upper()
	info.add_child(_make_label("PISTA DO PEDIDO · %s" % clue_type, 11, GOLD))
	var clue_text := _make_label(str(clue.get("text", "O cliente ainda não descreveu o livro.")), 14, TEXT_PRIMARY)
	clue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(clue_text)
	return card


func _make_condition_preference_card() -> Control:
	var condition := str(profile.get("preferred_condition", "novo"))
	var condition_label := "NOVO"
	var badge_background := Color("536b42")
	var badge_border := Color("a5bd79")
	match condition:
		"usado":
			condition_label = "USADO"
			badge_background = Color("80551f")
			badge_border = Color("e2b65a")
		"raro":
			condition_label = "RARO"
			badge_background = Color("604477")
			badge_border = Color("c7a1e2")
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_panel_style(Color("30382d"), Color("8e7543"), 1, 8, 7))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	card.add_child(info)
	info.add_child(_make_label("CONDIÇÃO PREFERIDA", 10, GOLD))
	var detail := HBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	info.add_child(detail)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _make_panel_style(badge_background, badge_border, 1, 6, 5))
	badge.add_child(_make_label(condition_label, 12, Color("fff4dc")))
	detail.add_child(badge)
	return card


func _make_tag_chip(value: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", _make_panel_style(Color("30382d"), Color("666047"), 1, 6, 10))
	chip.add_child(_make_label(value, 11, GREEN))
	return chip


func _preference_name(tag: String) -> String:
	var names := {
		"natureza": "Natureza", "poesia": "Poesia", "mitologia": "Mitologia",
		"magia": "Magia", "aventura": "Aventura", "diagramas": "Diagramas",
		"cronicas": "Crônicas", "historia": "História", "mapas": "Mapas",
		"viagem": "Viagem", "engenharia": "Engenharia", "batalhas": "Batalhas",
		"alquimia": "Alquimia", "rituais": "Rituais", "criaturas": "Criaturas"
	}
	return str(names.get(tag, tag.capitalize()))


func _make_section(title: String, body: String) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 3)
	var heading := _make_label(title, 12, GOLD)
	heading.add_theme_constant_override("outline_size", 2)
	section.add_child(heading)
	var text := _make_label(body, 13, TEXT_PRIMARY)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(text)
	return section


func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_panel_style(background: Color, border: Color, border_width: int, padding: float, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


func _style_button(button: Button, prominent := false) -> void:
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color("fff0c7"))
	button.add_theme_color_override("font_pressed_color", GOLD)
	var normal := _make_panel_style(Color("30382d") if not prominent else Color("d5b56d"), Color("666047"), 1, 4, 5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("4b543e") if not prominent else Color("efd99e")
	hover.border_color = Color("fff0c7")
	button.add_theme_stylebox_override("hover", hover)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
