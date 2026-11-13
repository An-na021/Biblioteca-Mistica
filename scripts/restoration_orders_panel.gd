extends Control
signal closed
signal action_requested(id: String, action: String)
signal pickup_scheduled(id: String, pickup_day: int)
const Art = preload("res://scripts/hud_art.gd")
const Diagnosis = preload("res://scripts/restoration_diagnosis.gd")
const INK := Color("382619")
const MUTED := Color("765637")
var list: VBoxContainer
var status_label: Label
var summary_label: Label
var day_label: Label
var sheet: PanelContainer

func _ready() -> void:
	name = "RestorationOrders"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.015, 0.01, 0.77)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	sheet = ManuscriptBorder.new()
	sheet.name = "Manuscript"
	var paper := _style("dec797", "65452b", 7, 28)
	paper.shadow_color = Color(0, 0, 0, 0.4)
	paper.shadow_size = 14
	sheet.add_theme_stylebox_override("panel", paper)
	add_child(sheet)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	sheet.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	stack.add_child(header)
	var crest := BookCrest.new()
	crest.custom_minimum_size = Vector2(48, 64)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(crest)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 2)
	header.add_child(heading)
	heading.add_child(_label("A T E L I Ê   D A   L I V R A R I A", 12, false, Color("813e2c")))
	heading.add_child(_label("Encomendas de restauração", 29))
	heading.add_child(_label("Uma nova história para os livros dos seus leitores.", 14, true, MUTED))
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(62, 62)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wax := _style("853f2e", "b67c50", 2, 7)
	wax.set_corner_radius_all(32)
	seal.add_theme_stylebox_override("panel", wax)
	header.add_child(seal)
	day_label = _label("", 17, false, Color("f1d39a"))
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.add_child(day_label)
	stack.add_child(_separator())
	summary_label = _label("", 14, false, MUTED)
	stack.add_child(summary_label)
	stack.add_child(_separator())
	var scroll := ScrollContainer.new()
	scroll.name = "OrdersScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	scroll.add_child(margin)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 30)
	margin.add_child(list)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	stack.add_child(footer)
	status_label = _label("", 12, false, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(status_label)
	var back := _button("←  Voltar ao ateliê", false)
	back.name = "Back"
	back.pressed.connect(func() -> void: closed.emit())
	footer.add_child(back)
	resized.connect(_fit_sheet)
	_fit_sheet()

func _fit_sheet() -> void:
	if not is_instance_valid(sheet):
		return
	sheet.size = Vector2(minf(940, size.x - 32), minf(660, size.y - 32))
	sheet.position = (size - sheet.size) * 0.5

func refresh(world: RefCounted, day: int, funds: int, present_customer_id := "", can_schedule_today := true) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var jobs: Array = world.restoration_jobs.pending()
	var occupied := 0
	for job: Dictionary in jobs:
		if str(job.status) in ["accepted", "ready", "scheduled"]:
			occupied += 1
	day_label.text = "DIA\n%d" % day
	summary_label.text = "%d encomenda%s · Vagas: %d / 2 · Por dia: 1 restauro de encomenda + 1 do estoque" % [jobs.size(), "s" if jobs.size() != 1 else "", occupied]
	for index in range(jobs.size()):
		var job: Dictionary = jobs[index]
		var card := OrderCard.new()
		card.name = "Order_" + str(job.id)
		card.add_theme_constant_override("separation", 7)
		list.add_child(card)
		var top := HBoxContainer.new()
		card.add_child(top)
		var customer := _label("%02d  |  %s" % [index + 1, str(job.customer_name)], 15, false, Color("7d3c29"))
		customer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		customer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		top.add_child(customer)
		var remaining := int(job.due_day) - day
		var when := "hoje" if remaining == 0 else "amanhã" if remaining == 1 else "em %d dias" % remaining
		top.add_child(_label("Até o dia %d · %s" % [int(job.due_day), when], 13, true, Color("873e2a") if remaining <= 1 else MUTED))
		var title := _label(str(BookCatalog.get_book(str(job.book_id)).get("title", "Livro")), 24)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(title)
		var detail := HBoxContainer.new()
		detail.add_theme_constant_override("separation", 22)
		card.add_child(detail)
		var diagnosis := VBoxContainer.new()
		diagnosis.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.add_child(diagnosis)
		diagnosis.add_child(_label("Condição: " + str(BookCatalog.get_condition(str(job.condition)).label) + "  ·  Diagnóstico", 12, false, MUTED))
		var profile := Diagnosis.profile(str(job.get("diagnosis", "complete")))
		var damage := _label(str(profile.name), 16)
		damage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		diagnosis.add_child(damage)
		var instructions := _label(str(profile.detail), 13, true, MUTED)
		instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		diagnosis.add_child(instructions)
		var values := VBoxContainer.new()
		values.custom_minimum_size.x = 240
		detail.add_child(values)
		var amounts := HBoxContainer.new()
		amounts.add_theme_constant_override("separation", 18)
		values.add_child(amounts)
		for field in ["cost", "reward"]:
			var column := VBoxContainer.new()
			column.custom_minimum_size.x = 108
			amounts.add_child(column)
			column.add_child(_label("MATERIAIS" if field == "cost" else "PAGAMENTO", 11, false, MUTED))
			column.add_child(_label("%d moedas" % int(job[field]), 19))
		values.add_child(_label("+%d de reputação ao entregar" % int(job.reputation), 12, true, MUTED))
		card.add_child(_separator())
		var buttons := HBoxContainer.new()
		buttons.name = "Actions"
		buttons.add_theme_constant_override("separation", 10)
		card.add_child(buttons)
		var state := "Aguardando aceite" if str(job.status) == "offered" else "Pronto · agende a entrega" if str(job.status) == "ready" else "Restauro de encomenda disponível amanhã" if world.last_contract_restoration_day == day else "Aguardando restauração"
		if str(job.status) == "scheduled":
			state = "Entrega: dia %d" % int(job.pickup_day)
			state += " · cliente na loja" if present_customer_id == str(job.customer_id) else " · aguardando cliente"
		var state_label := _label(state, 12, true, MUTED)
		state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(state_label)
		if str(job.status) == "offered":
			var reject := _button("Recusar", false)
			reject.pressed.connect(func() -> void: action_requested.emit(str(job.id), "decline"))
			buttons.add_child(reject)
		var picker: OptionButton
		if str(job.status) in ["ready", "scheduled"]:
			picker = OptionButton.new()
			picker.name = "PickupDay"
			picker.add_theme_font_override("font", Art.handwriting(false))
			picker.add_theme_font_size_override("font_size", 13)
			for font_state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
				picker.add_theme_color_override(font_state, INK)
			picker.add_theme_constant_override("modulate_arrow", 1)
			picker.add_theme_stylebox_override("normal", _style("d9bf90", "a88147", 1, 8))
			picker.add_theme_stylebox_override("hover", _style("e6cfa4", "a88147", 1, 8))
			var popup := picker.get_popup()
			popup.add_theme_stylebox_override("panel", _style("dec797", "65452b", 1, 8))
			popup.add_theme_font_override("font", Art.handwriting(false))
			popup.add_theme_color_override("font_color", INK)
			for pickup_day in range(day if can_schedule_today else day + 1, int(job.due_day) + 1):
				picker.add_item("Hoje · dia %d" % pickup_day if pickup_day == day else "Dia %d" % pickup_day)
				picker.set_item_metadata(picker.item_count - 1, pickup_day)
				if pickup_day == int(job.get("pickup_day", day + 1)):
					picker.select(picker.item_count - 1)
			if picker.item_count == 0:
				picker.add_item("Prazo encerrado")
				picker.disabled = true
			buttons.add_child(picker)
			if str(job.status) == "scheduled":
				var reschedule := _button("Reagendar", false)
				reschedule.name = "Schedule"
				reschedule.disabled = picker.disabled
				reschedule.pressed.connect(func() -> void: pickup_scheduled.emit(str(job.id), int(picker.get_item_metadata(picker.selected))))
				buttons.add_child(reschedule)
		var primary := _button("Aceitar encomenda  →" if str(job.status) == "offered" else "Restaurar  →" if str(job.status) == "accepted" else "Agendar entrega" if str(job.status) == "ready" else "Entregar e receber  →")
		primary.name = "Action"
		primary.disabled = str(job.status) == "accepted" and world.last_contract_restoration_day == day
		if str(job.status) == "scheduled":
			primary.disabled = present_customer_id != str(job.customer_id) or day < int(job.pickup_day)
			primary.tooltip_text = "Entrega somente ao titular presente na loja, a partir do dia agendado."
		var action := "accept" if str(job.status) == "offered" else "work" if str(job.status) == "accepted" else "collect"
		if str(job.status) == "ready":
			primary.disabled = picker.disabled
			primary.pressed.connect(func() -> void: pickup_scheduled.emit(str(job.id), int(picker.get_item_metadata(picker.selected))))
		else:
			primary.pressed.connect(func() -> void: action_requested.emit(str(job.id), action))
		buttons.add_child(primary)
		if str(job.status) == "accepted" and funds < int(job.cost):
			var warning := _label("Faltam %d moedas para os materiais; abrir a bancada é gratuito." % (int(job.cost) - funds), 13, true, Color("873e2a"))
			warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(warning)
	if jobs.is_empty():
		var empty := _label("Os leitores podem trazer livros próprios a partir do dia 2, com a mesa instalada. As propostas aparecerão aqui quando chegarem à loja.", 20, true)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(empty)
	status_label.text = "Materiais cobrados ao concluir. Depois, agende a entrega.\nO titular precisa estar na loja para receber o livro e pagar, dentro do prazo."

func _label(text: String, font_size: int, italic := false, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Art.handwriting(italic))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _separator() -> HSeparator:
	var separator := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = Color("ac8a53")
	line.thickness = 1
	separator.add_theme_stylebox_override("separator", line)
	return separator

func _style(fill: String, border: String, width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(border)
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	return style

func _button(text: String, primary := true) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(100, 36)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Art.handwriting(false))
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := "543821" if primary else "d9bf90"
		if state == "hover":
			fill = "715032" if primary else "e6cfa4"
		elif state == "pressed":
			fill = "392518" if primary else "c5a573"
		elif state == "disabled":
			fill = "9d896b"
		var style := _style(fill, "a88147", 1, 8)
		style.content_margin_left = 17
		style.content_margin_right = 17
		button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("f1d49a") if primary else INK)
	button.add_theme_color_override("font_disabled_color", Color("e0cfac"))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("f4d797")
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(3)
	button.add_theme_stylebox_override("focus", focus)
	return button

class OrderCard extends VBoxContainer:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var rect := Rect2(Vector2(-12, -10), size + Vector2(24, 20))
		draw_rect(rect, Color("e7cfa1"))
		draw_rect(rect, Color("a27a44"), false, 1)
		for y in range(0, int(size.y), 10):
			draw_line(Vector2(-12, y), Vector2(-12, minf(y + 6, size.y)), Color("8a432b"), 3)

class ManuscriptBorder extends PanelContainer:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		# Faint fibers and edge washes keep the sheet from looking like a flat menu.
		for y in range(8, int(size.y) - 8, 4):
			draw_line(Vector2(8, y), Vector2(size.x - 8, y), Color(0.36, 0.23, 0.1, 0.025), 1)
		for inset in range(8, 26):
			draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2), Color(0.4, 0.25, 0.1, 0.012), false, 1)
		var ink := Color("99703a")
		for inset in [12, 16]:
			draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2), ink, false, 1)
		for corner in [Vector2(20, 20), Vector2(size.x - 20, size.y - 20)]:
			var direction := 1.0 if corner.x < size.x / 2 else -1.0
			for offset in [0, 6, 12]:
				var start: Vector2 = corner + Vector2.ONE * offset * direction
				draw_polyline(PackedVector2Array([start + Vector2(0, 32 * direction), start, start + Vector2(32 * direction, 0)]), ink, 1, true)
			for offset in [Vector2(22, 10), Vector2(10, 22)]:
				draw_arc(corner + offset * direction, 9, 0, TAU, 24, ink, 1, true)



class BookCrest extends Control:
	func _draw() -> void:
		var shield := PackedVector2Array([Vector2(3, 2), Vector2(45, 2), Vector2(45, 46), Vector2(24, 59), Vector2(3, 46)])
		draw_colored_polygon(shield, Color("813e2c"))
		shield.append(shield[0])
		draw_polyline(shield, Color("ad8148"), 2, true)
		var gold := Color("dfbd7e")
		draw_polyline(PackedVector2Array([Vector2(11, 19), Vector2(17, 17), Vector2(24, 20), Vector2(31, 17), Vector2(37, 19), Vector2(37, 36), Vector2(31, 34), Vector2(24, 37), Vector2(17, 34), Vector2(11, 36), Vector2(11, 19)]), gold, 1, true)
		draw_line(Vector2(24, 20), Vector2(24, 37), gold, 1, true)
		for y in [23, 27, 31]:
			draw_line(Vector2(14, y), Vector2(20, y), gold, 1)
			draw_line(Vector2(28, y), Vector2(34, y), gold, 1)
