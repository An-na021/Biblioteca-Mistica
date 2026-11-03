extends Control

signal proposed(price: int)
signal closed

const Art = preload("res://scripts/hud_art.gd")
const Paper = preload("res://scripts/inventory_paper.gd")
const BOOK: Texture2D = preload("res://IMG/pause_book.png")
const BUTTON: Texture2D = preload("res://IMG/pause_resume.png")
const BOOK_SIZE := Vector2(1120, 680)

var price_input: SpinBox
var response: Label
var counter_button: Button
var time_label: Label
var propose_button: Button
var back_button: Button
var book_view: Control
var counter_price := 0
var book_id := ""
var condition := ""

func setup(book: Dictionary, customer: Customer, acquisition_cost: int) -> void:
	book_id = str(book.id)
	condition = str(book.condition)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.025, 0.017, 0.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	book_view = Control.new()
	book_view.name = "NegotiationBook"
	book_view.size = BOOK_SIZE
	add_child(book_view)
	var background := TextureRect.new()
	background.texture = BOOK
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = BOOK_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book_view.add_child(background)
	resized.connect(_layout_book)
	_layout_book()

	var heading := _label("NEGOCIAR UMA LEITURA", 28, false)
	heading.position = Vector2(150, 80)
	heading.size = Vector2(394, 48)
	heading.add_theme_constant_override("outline_size", 1)
	heading.add_theme_color_override("font_outline_color", Color("ac8150"))
	book_view.add_child(heading)
	var information := ScrollContainer.new()
	information.position = Vector2(150, 158)
	information.size = Vector2(394, 362)
	information.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scroll(information)
	book_view.add_child(information)
	var left_page := VBoxContainer.new()
	left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_page.add_theme_constant_override("separation", 24)
	information.add_child(left_page)
	var identity := _label("%s · %s\n%s" % [str(book.title), str(BookCatalog.get_condition(condition).label), customer.customer_name], 23)
	left_page.add_child(identity)
	left_page.add_child(_label(customer.behavior_hint(), 20))
	left_page.add_child(_label("Preço de balcão: %d moedas · Custo de aquisição: %d moedas" % [int(book.sale_price), acquisition_cost], 20))
	left_page.add_child(_label("Faça até três propostas acima do limite do leitor. Uma contraproposta não conta como erro; insistir até o cliente sair conta.", 19))
	time_label = _label("", 18)
	time_label.position = Vector2(150, 539)
	time_label.size = Vector2(394, 36)
	book_view.add_child(time_label)

	var price_row := HBoxContainer.new()
	price_row.position = Vector2(608, 134)
	price_row.size = Vector2(418, 64)
	price_row.add_theme_constant_override("separation", 8)
	book_view.add_child(price_row)
	var prompt := _label("Seu preço, em moedas:", 18)
	prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_row.add_child(prompt)
	price_input = SpinBox.new()
	price_input.min_value = 1
	price_input.max_value = maxi(2, int(book.sale_price) * 2)
	price_input.step = 1
	price_input.value = ceili(float(book.sale_price) * 1.15)
	price_input.custom_minimum_size = Vector2(82, 44)
	price_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_price_input()
	price_row.add_child(price_input)
	propose_button = _button("PROPOR\nPREÇO", Vector2(104, 64), func() -> void: proposed.emit(int(price_input.value)), false)
	price_row.add_child(propose_button)

	var response_scroll := ScrollContainer.new()
	response_scroll.position = Vector2(608, 230)
	response_scroll.size = Vector2(418, 156)
	response_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scroll(response_scroll)
	book_view.add_child(response_scroll)
	response = _label("O cliente pode aceitar ou sugerir um valor menor.", 22)
	response.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	response_scroll.add_child(response)
	counter_button = _button("ACEITAR CONTRAPROPOSTA", Vector2(418, 64), func() -> void: proposed.emit(counter_price))
	counter_button.position = Vector2(608, 422)
	counter_button.disabled = true
	book_view.add_child(counter_button)
	back_button = _button("VOLTAR AO ESTOQUE", Vector2(418, 64), func() -> void: closed.emit())
	back_button.position = Vector2(608, 501)
	book_view.add_child(back_button)

func show_counter(result: Dictionary) -> void:
	counter_price = int(result.counter_price)
	response.text = str(result.text)
	(response.get_parent() as ScrollContainer).scroll_vertical = 0
	counter_button.text = "ACEITAR %d MOEDAS" % counter_price
	counter_button.disabled = false

func set_time_left(seconds: float, relaxed: bool) -> void:
	time_label.text = "MODO TRANQUILO · sem limite de tempo" if relaxed else "TEMPO RESTANTE: %02d:%02d" % [ceili(seconds) / 60, ceili(seconds) % 60]
	time_label.add_theme_color_override("font_color", Color("9d342a") if not relaxed and seconds <= 15.0 else Art.INK)

func _layout_book() -> void:
	var zoom := minf(size.x / 1280.0, size.y / 760.0)
	book_view.scale = Vector2.ONE * zoom
	book_view.position = (size - BOOK_SIZE * zoom) * 0.5

func _style_price_input() -> void:
	var input := price_input.get_line_edit()
	input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	input.add_theme_font_override("font", Art.handwriting(false))
	input.add_theme_font_size_override("font_size", 26)
	input.add_theme_constant_override("minimum_character_width", 2)
	input.add_theme_color_override("font_color", Art.INK)
	input.add_theme_color_override("caret_color", Art.INK)
	input.add_theme_color_override("selection_color", Color("c6a167"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.91, 0.77, 0.53, 0.22)
	normal.border_color = Color("806242")
	normal.set_border_width_all(1)
	normal.set_content_margin_all(5)
	input.add_theme_stylebox_override("normal", normal)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Art.INK
	focus.border_width_bottom = 2
	input.add_theme_stylebox_override("focus", focus)
	for state in ["up_icon_modulate", "up_hover_icon_modulate", "up_pressed_icon_modulate", "down_icon_modulate", "down_hover_icon_modulate", "down_pressed_icon_modulate"]:
		price_input.add_theme_color_override(state, Art.INK)

func _label(text: String, font_size: int, italic := true) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", Art.handwriting(italic))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Art.INK)
	return label

func _button(text: String, dimensions: Vector2, callback: Callable, wide := true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = dimensions
	button.size = dimensions
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Art.handwriting(false))
	button.add_theme_font_size_override("font_size", 18)
	for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Art.INK)
	button.add_theme_color_override("font_disabled_color", Color("9b815d"))
	if wide:
		var normal := StyleBoxTexture.new()
		normal.texture = Art.cutout(BUTTON, Rect2(56, 152, 2064, 400))
		normal.content_margin_left = 10
		normal.content_margin_right = 10
		button.add_theme_stylebox_override("normal", normal)
		var hover := normal.duplicate() as StyleBoxTexture
		hover.modulate_color = Color(1.08, 1.05, 1.0)
		button.add_theme_stylebox_override("hover", hover)
		var pressed := normal.duplicate() as StyleBoxTexture
		pressed.modulate_color = Color(0.9, 0.84, 0.72)
		button.add_theme_stylebox_override("pressed", pressed)
		var disabled := normal.duplicate() as StyleBoxTexture
		disabled.modulate_color = Color(0.82, 0.77, 0.65, 0.65)
		button.add_theme_stylebox_override("disabled", disabled)
	else:
		for state in ["normal", "hover", "pressed"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_child(Paper.ButtonBacking.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("8d6437")
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	return button

func _style_scroll(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 5
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.35, 0.23, 0.11, 0.10)
	bar.add_theme_stylebox_override("scroll", track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color("a18255")
		grabber.set_corner_radius_all(2)
		grabber.set_content_margin_all(2)
		bar.add_theme_stylebox_override(state, grabber)
