class_name CustomerProfilePanel
extends Control

signal closed

const PAPER_TEXTURE: Texture2D = preload("res://IMG/customer_profile_paper.png")
const SHEET_SIZE := Vector2(400, 600)
const INK := Color("291e14")
const MUTED := Color("5e4c34")
const GREEN := Color("738558")

var customer: Customer
var profile: Dictionary = {}
var sheet: Control
var scroll: ScrollContainer
var details: VBoxContainer
var more_button: Button
var _handwriting: SystemFont
var _closing := false

func setup(value_customer: Customer, value_profile: Dictionary) -> void:
	customer = value_customer
	profile = value_profile.duplicate(true)
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var paper_theme := Theme.new()
	var print_font := SystemFont.new()
	print_font.font_names = PackedStringArray(["Bahnschrift", "Noto Sans", "sans-serif"])
	paper_theme.default_font = print_font
	paper_theme.default_font_size = 14
	theme = paper_theme
	_handwriting = SystemFont.new()
	_handwriting.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	_handwriting.font_italic = true

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.008, 0.32)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	sheet = Control.new()
	sheet.name = "ProfileSheet"
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var paper := TextureRect.new()
	paper.texture = PAPER_TEXTURE
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(paper)
	resized.connect(_layout_sheet)
	_layout_sheet()

	var layout := VBoxContainer.new()
	layout.position = Vector2(27, 36)
	layout.size = Vector2(345, 528)
	layout.add_theme_constant_override("separation", 9)
	sheet.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := _make_label("FICHA DO CLIENTE", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Fechar ficha · Esc"
	close_button.custom_minimum_size = Vector2(24, 25)
	_style_button(close_button)
	close_button.add_theme_font_size_override("font_size", 21)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var subtitle := _make_label("Informações para um atendimento mais pessoal", 11, MUTED)
	layout.add_child(subtitle)
	layout.add_child(_rule())

	scroll = ScrollContainer.new()
	scroll.name = "ProfileScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar()
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 6)
	content.add_child(identity)
	var name_label := _make_label(str(profile.get("name", customer.customer_name)), 24)
	name_label.name = "CustomerName"
	name_label.add_theme_font_override("font", _handwriting)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(name_label)
	var stamp := _make_label("CLIENTE ATUAL", 10, GREEN)
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stamp.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color("879367"), 2, 4))
	stamp.rotation = -0.035
	identity.add_child(stamp)
	var behavior := _make_label(str(profile.get("behavior_hint", customer.behavior_hint())), 14)
	behavior.name = "Behavior"
	behavior.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(behavior)

	var clue := customer.get_request_clue()
	if not clue.is_empty():
		content.add_child(_rule())
		content.add_child(_make_label("PISTA DO PEDIDO · " + str(clue.get("type", "titulo")).to_upper(), 11))
		var request := _make_label(str(clue.get("text", "O cliente ainda não descreveu o livro.")), 16)
		request.name = "RequestClue"
		request.add_theme_font_override("font", _handwriting)
		request.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(request)
		content.add_child(_rule())

	var condition_section := VBoxContainer.new()
	condition_section.add_theme_constant_override("separation", 4)
	condition_section.add_child(_make_label("CONDIÇÃO PREFERIDA", 11))
	var condition := str(profile.get("preferred_condition", "novo"))
	var condition_info := BookCatalog.get_condition(condition)
	var condition_colors := {"novo": GREEN, "usado": Color("9c794b"), "raro": Color("8b6c83"), "danificado": Color("a26349")}
	var badge := _make_label(str(condition_info.get("label", condition)).to_upper(), 14, Color("fff6de"))
	badge.name = "ConditionBadge"
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override("normal", _style(condition_colors.get(condition, GREEN), Color.TRANSPARENT, 0, 5))
	condition_section.add_child(badge)
	content.add_child(condition_section)

	var tastes := VBoxContainer.new()
	tastes.add_theme_constant_override("separation", 4)
	tastes.add_child(_make_label("GOSTA DE", 11))
	var tags := HFlowContainer.new()
	tags.name = "PreferenceTags"
	tags.add_theme_constant_override("h_separation", 12)
	tags.add_theme_constant_override("v_separation", 5)
	for tag in profile.get("preference_tags", []):
		var tag_box := VBoxContainer.new()
		tag_box.add_theme_constant_override("separation", 1)
		var tag_label := _make_label(_preference_name(str(tag)), 16)
		tag_label.add_theme_font_override("font", _handwriting)
		tag_box.add_child(tag_label)
		tag_box.add_child(_rule())
		tags.add_child(tag_box)
	tastes.add_child(tags)
	content.add_child(tastes)
	content.add_child(_make_section("JEITO DE SER", str(profile.get("personality", "Ainda não conhecemos bem este cliente.")), "Personality"))

	details = VBoxContainer.new()
	details.name = "MoreDetails"
	details.add_theme_constant_override("separation", 12)
	details.visible = false
	details.add_child(_make_section("SUA HISTÓRIA", str(profile.get("history", "Nenhum registro disponível.")), "History"))
	details.add_child(_make_section("NOSSOS ENCONTROS", str(profile.get("memory_text", "Ainda estamos conhecendo este leitor.")), "Memory"))
	content.add_child(details)

	layout.add_child(_rule())
	more_button = Button.new()
	more_button.text = "VER MAIS SOBRE O CLIENTE  +"
	more_button.custom_minimum_size.y = 25
	_style_button(more_button)
	more_button.pressed.connect(func() -> void:
		details.visible = not details.visible
		more_button.text = "VER MENOS  −" if details.visible else "VER MAIS SOBRE O CLIENTE  +"
	)
	layout.add_child(more_button)
	var hint := _make_label("Escolha uma leitura que combine com o perfil.", 11, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(hint)

func _layout_sheet() -> void:
	var zoom := minf(size.x / 1280.0, size.y / 720.0)
	var top := 146.0 * zoom
	zoom = minf(zoom, (size.y - top - 18.0 * zoom) / SHEET_SIZE.y)
	sheet.size = SHEET_SIZE
	sheet.scale = Vector2.ONE * zoom
	sheet.position = Vector2(size.x - (SHEET_SIZE.x + 18.0) * zoom, top)

func _make_section(title: String, body: String, node_name: String) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	section.add_child(_make_label(title, 11))
	var text := _make_label(body, 15)
	text.name = node_name
	text.add_theme_font_override("font", _handwriting)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(text)
	return section

func _preference_name(tag: String) -> String:
	var names := {"cronicas": "Crônicas", "historia": "História"}
	return str(names.get(tag, tag.capitalize()))

func _make_label(value: String, font_size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _rule() -> Control:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = Color(0.34, 0.26, 0.15, 0.30)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

func _style(background: Color, border: Color, border_width: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(1)
	style.set_content_margin_all(padding)
	return style

func _style_button(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color("70522d"))
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 1))
	button.add_theme_stylebox_override("hover", _style(Color(0.5, 0.37, 0.18, 0.10), Color.TRANSPARENT, 0, 1))
	button.add_theme_stylebox_override("pressed", _style(Color(0.5, 0.37, 0.18, 0.18), Color.TRANSPARENT, 0, 1))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, MUTED, 1, 1))

func _style_scrollbar() -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 5
	bar.add_theme_stylebox_override("scroll", _style(Color(0.36, 0.26, 0.13, 0.13), Color.TRANSPARENT, 0, 1))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, _style(Color("9e865b"), Color("6d5839"), 1, 2))

func close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()
