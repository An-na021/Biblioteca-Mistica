extends "res://scripts/shop_screen.gd"

signal proposed(price: int)
signal closed

var price_input: SpinBox
var response: Label
var counter_button: Button
var time_label: Label
var counter_price := 0
var book_id := ""
var condition := ""

func setup(book: Dictionary, customer: Customer, acquisition_cost: int) -> void:
	book_id = str(book.id)
	condition = str(book.condition)
	var layout := build_panel("NEGOCIAR UMA LEITURA", "%s · %s\n%s" % [str(book.title), str(BookCatalog.get_condition(condition).label), customer.customer_name])
	layout.add_child(label(customer.behavior_hint(), 14, GOLD))
	layout.add_child(label("Preço de balcão: %d moedas · Custo de aquisição: %d moedas\nFaça até três propostas acima do limite do leitor. Uma contraproposta não conta como erro; insistir até o cliente sair conta." % [int(book.sale_price), acquisition_cost]))
	time_label = label("", 14, GOLD)
	layout.add_child(time_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 44
	layout.add_child(row)
	var prompt := label("Seu preço, em moedas:", 16)
	prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prompt)
	price_input = SpinBox.new()
	price_input.min_value = 1
	price_input.max_value = maxi(2, int(book.sale_price) * 2)
	price_input.step = 1
	price_input.value = ceili(float(book.sale_price) * 1.15)
	price_input.custom_minimum_size.x = 130
	price_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price_input)
	button(row, "PROPOR PREÇO", func() -> void: proposed.emit(int(price_input.value)))
	response = label("O cliente pode aceitar ou sugerir um valor menor.", 16)
	response.custom_minimum_size.y = 75
	layout.add_child(response)
	counter_button = button(layout, "ACEITAR CONTRAPROPOSTA", func() -> void: proposed.emit(counter_price))
	counter_button.disabled = true
	button(layout, "VOLTAR AO ESTOQUE", func() -> void: closed.emit())

func show_counter(result: Dictionary) -> void:
	counter_price = int(result.counter_price)
	response.text = str(result.text)
	counter_button.text = "ACEITAR %d MOEDAS" % counter_price
	counter_button.disabled = false

func set_time_left(seconds: float, relaxed: bool) -> void:
	time_label.text = "MODO TRANQUILO · sem limite de tempo" if relaxed else "TEMPO RESTANTE: %02d:%02d" % [ceili(seconds) / 60, ceili(seconds) % 60]
