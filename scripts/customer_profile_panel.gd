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
var requested_book: Dictionary = {}


func setup(value_customer: Customer, value_profile: Dictionary, value_requested_book: Dictionary) -> void:
	customer = value_customer
	profile = value_profile
	requested_book = value_requested_book
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
	name_layout.add_child(_make_label("CLIENTE ATUAL  •  %s" % str(profile.get("greeting", "")), 11, GREEN))

	if not requested_book.is_empty():
		var request := _make_label("PEDIU:  %s" % str(requested_book.get("title", "Livro")), 13, GOLD)
		request.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		layout.add_child(request)

	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color("6e5b37"))
	layout.add_child(separator)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 12)
	scroll.add_child(sections)
	sections.add_child(_make_section("PERSONALIDADE", str(profile.get("personality", "Ainda não conhecemos bem este cliente."))))
	sections.add_child(_make_section("HISTÓRICO", str(profile.get("history", "Nenhum registro disponível."))))
	sections.add_child(_make_section("PREFERÊNCIAS", str(profile.get("preferences", "Observe o pedido e descubra seus gostos."))))

	var hint := _make_label("Use estas pistas para escolher entre entregar, negociar ou oferecer outro livro.", 11, TEXT_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)


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
