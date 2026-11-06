class_name DaySummaryScreen
extends Control

signal next_day_requested
signal shop_requested
signal district_requested
signal livraria_requested

const Art = preload("res://scripts/hud_art.gd")
const Paper = preload("res://scripts/inventory_paper.gd")
const BackButtonStyle = preload("res://scripts/back_button_style.gd")
const BOOK: Texture2D = preload("res://IMG/day_summary_book.png")
const DESIGN_SIZE := Vector2(1280, 720)
const INK := Color("302014")
const MUTED := Color("6c5035")
const GREEN := Color("486034")
const RED := Color("8a3f2d")

var book: Control
var district_badge: Button


class CartButton extends Button:
	func _draw() -> void:
		draw_set_transform((size - Vector2(48, 44)) * 0.5)
		var ink := Color("302014")
		draw_polyline(PackedVector2Array([Vector2(4, 5), Vector2(12, 5), Vector2(18, 29), Vector2(38, 29), Vector2(43, 13), Vector2(15, 13)]), ink, 2.5, true)
		draw_line(Vector2(18, 22), Vector2(40, 22), ink, 1.4, true)
		for x in [23, 30, 37]:
			draw_line(Vector2(x, 14), Vector2(x - 2, 28), ink, 1.2, true)
		draw_polyline(PackedVector2Array([Vector2(18, 29), Vector2(16, 35), Vector2(39, 35)]), ink, 2.2, true)
		draw_circle(Vector2(22, 40), 2.8, ink)
		draw_circle(Vector2(36, 40), 2.8, ink)


class LedgerMetric extends PanelContainer:
	var framed := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		if framed:
			var outline := PackedVector2Array([
				Vector2(2, 4), Vector2(size.x * 0.34, 2), Vector2(size.x * 0.65, 4),
				Vector2(size.x - 3, 2), Vector2(size.x - 1, size.y * 0.5),
				Vector2(size.x - 3, size.y - 3), Vector2(size.x * 0.62, size.y - 2),
				Vector2(3, size.y - 3), Vector2(1, size.y * 0.4), Vector2(2, 4)
			])
			draw_polyline(outline, Color(0.24, 0.15, 0.08, 0.8), 1.4, true)
		var y := 36.0
		while y < size.y - 9:
			draw_line(Vector2(9, y), Vector2(size.x - 9, y + 0.5), Color(0.4, 0.27, 0.12, 0.18), 0.8, true)
			y += 29


func setup(day: int, customers_served: int, sales_count: int, sales_revenue: int, errors: int, reputation: int, reputation_change: int, profit: int, customers_total: int, progress_report: Dictionary = {}, district_name := "Centro", mistakes := 0, world_note := "") -> void:
	build(day, customers_served, sales_count, sales_revenue, errors, reputation, reputation_change, profit, customers_total, progress_report, district_name, mistakes, world_note)


func build(day: int, customers_served: int, sales_count: int, sales_revenue: int, errors: int, reputation: int, reputation_change: int, profit: int, customers_total: int, progress_report: Dictionary = {}, district_name := "Centro", mistakes := 0, world_note := "") -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.018, 0.01, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	book = Control.new()
	book.name = "DaySummaryBook"
	book.size = DESIGN_SIZE
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(book)
	var background := TextureRect.new()
	background.texture = BOOK
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.size = DESIGN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(background)
	resized.connect(_layout_book)
	_layout_book()

	var title := _label("FECHAMENTO DO DIA", 33, INK, true)
	_place(title, Rect2(150, 87, 455, 48))
	var subtitle := _label("Dia %d · %d de %d clientes atendidos · %d erro(s)" % [day, customers_served, customers_total, mistakes], 15, MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(subtitle, Rect2(153, 141, 445, 40))
	district_badge = Button.new()
	district_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	district_badge.focus_mode = Control.FOCUS_NONE
	BackButtonStyle.apply(district_badge)
	set_district_name(district_name)
	_place(district_badge, Rect2(970, 47, 215, 44))

	_place(_metric_card("CLIENTES ATENDIDOS", "%d / %d" % [customers_served, customers_total], "Clientes que concluíram uma compra.", INK), Rect2(150, 190, 450, 116))
	var reputation_sign := "+" if reputation_change > 0 else ""
	_place(_metric_card("REPUTAÇÃO", "%d (%s%d)" % [reputation, reputation_sign, reputation_change], "Pontuação atual e variação do dia.", RED if reputation_change < 0 else GREEN), Rect2(150, 324, 450, 116))
	_place(_metric_card("LUCRO DO DIA", "%s%d moedas" % ["+" if profit > 0 else "", profit], "Vendas menos o custo de aquisição dos exemplares vendidos.", RED if profit < 0 else INK), Rect2(150, 458, 450, 142))

	var scroll := ScrollContainer.new()
	scroll.name = "ReportDetails"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll, Rect2(704, 105, 450, 507))
	var scrollbar := scroll.get_v_scroll_bar()
	scrollbar.custom_minimum_size.x = 5
	scrollbar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(0.4, 0.25, 0.12, 0.4)
		grabber.set_corner_radius_all(3)
		scrollbar.add_theme_stylebox_override(state, grabber)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	scroll.add_child(content)
	var sales := _metric_card("VENDAS", "%d moedas" % sales_revenue, "%d transações concluídas." % sales_count, INK, false)
	sales.custom_minimum_size.y = 88
	content.add_child(sales)
	var no_sale := _metric_card("CLIENTES SEM ATENDIMENTO", str(errors), "Clientes que ficaram sem atendimento.", RED if errors > 0 else INK, false)
	no_sale.custom_minimum_size.y = 98
	content.add_child(no_sale)
	content.add_child(_goal_group("OBJETIVOS DE HOJE", progress_report.get("daily_goals", []), "Recompensa diária: %d moedas" % int(progress_report.get("daily_reward", 0))))
	var weekly_reward := "Bônus ao concluir: %d moedas" % int(progress_report.get("weekly_reward_available", 25))
	if bool(progress_report.get("weekly_reward_claimed", false)):
		weekly_reward = "Recompensa semanal resgatada: %d moedas" % int(progress_report.get("weekly_reward", 0)) if int(progress_report.get("weekly_reward", 0)) > 0 else "Recompensa semanal já resgatada"
	content.add_child(_goal_group("OBJETIVOS DA SEMANA %d" % int(progress_report.get("week_number", 1)), progress_report.get("weekly_goals", []), weekly_reward))
	var achievement_text := "CONQUISTAS DESBLOQUEADAS: %d" % int(progress_report.get("achievement_count", 0))
	var names := PackedStringArray()
	for achievement in progress_report.get("unlocked_achievements", []):
		names.append(str(achievement.get("title", "Conquista")))
	if not names.is_empty():
		achievement_text += " · " + ", ".join(names)
	var achievements := _label(achievement_text, 15, INK)
	achievements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(achievements)
	if not world_note.is_empty():
		var tomorrow := _label(world_note, 16, MUTED, false, true)
		tomorrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(tomorrow)
	var shop := CartButton.new()
	shop.name = "Shop"
	shop.tooltip_text = "Comprar livros"
	_style_button(shop)
	shop.pressed.connect(func() -> void: shop_requested.emit())
	_place(shop, Rect2(91, 628, 78, 50))
	_action_button("BAIRROS", Rect2(408, 628, 190, 50), func() -> void: district_requested.emit())
	_action_button("LIVRARIA", Rect2(704, 628, 190, 50), func() -> void: livraria_requested.emit())
	_action_button("ABRIR O PRÓXIMO DIA", Rect2(918, 628, 270, 50), func() -> void: next_day_requested.emit())


func set_district_name(value: String) -> void:
	if district_badge != null:
		district_badge.text = value.to_upper()


func _layout_book() -> void:
	var available := size - Vector2(28, 20)
	var zoom := maxf(0.1, minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y))
	book.scale = Vector2.ONE * zoom
	book.position = (size - DESIGN_SIZE * zoom) * 0.5


func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	book.add_child(control)


func _metric_card(title: String, value: String, detail: String, accent: Color, framed := true) -> LedgerMetric:
	var card := LedgerMetric.new()
	card.framed = framed
	var margins := StyleBoxEmpty.new()
	margins.set_content_margin_all(10 if framed else 5)
	card.add_theme_stylebox_override("panel", margins)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	card.add_child(stack)
	stack.add_child(_label(title, 18, INK))
	stack.add_child(_label(value, 31, accent))
	var note := _label(detail, 15, MUTED, false, true)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(note)
	return card


func _goal_group(title: String, goals: Array, reward_text: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 4)
	group.add_child(_label(title, 17, INK))
	for goal in goals:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		group.add_child(row)
		var complete := bool(goal.get("completed", false))
		row.add_child(_label("✓" if complete else "○", 18, GREEN if complete else MUTED))
		var goal_title := _label(str(goal.get("title", "Objetivo")), 15, INK)
		goal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		goal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(goal_title)
		row.add_child(_label("%d/%d" % [int(goal.get("progress", 0)), int(goal.get("target", 1))], 15, INK))
	var reward := _label(reward_text, 14, GREEN, false, true)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(reward)
	var line := ColorRect.new()
	line.color = Color(0.4, 0.27, 0.12, 0.22)
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(line)
	return group


func _action_button(text: String, rect: Rect2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	_style_button(button)
	button.pressed.connect(callback)
	_place(button, rect)


func _style_button(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_font_override("font", _body_font())
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, INK)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("8d6437")
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", focus)
	button.add_child(Paper.ButtonBacking.new())


func _body_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Noto Sans", "sans-serif"])
	return font


func _label(text: String, font_size: int, color: Color, heading := false, italic := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", Art.handwriting(italic) if heading or italic else _body_font())
	return label
