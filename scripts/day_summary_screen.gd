class_name DaySummaryScreen
extends Control

signal next_day_requested

const INK := Color("211b14")
const PANEL := Color("201f19")
const CARD := Color("2d2c23")
const GOLD := Color("e4c477")
const MUTED := Color("b9ad96")
const GREEN := Color("a8c184")
const RED := Color("d99079")

func setup(day: int, customers_served: int, sales_count: int, sales_revenue: int, errors: int, reputation: int, reputation_change: int, profit: int, customers_total: int) -> void:
	build(day, customers_served, sales_count, sales_revenue, errors, reputation, reputation_change, profit, customers_total)

func build(day: int, customers_served: int, sales_count: int, sales_revenue: int, errors: int, reputation: int, reputation_change: int, profit: int, customers_total: int) -> void:
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
	panel.custom_minimum_size = Vector2(660, 500)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD, 2, 22))
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 3)
	header.add_child(title_stack)
	title_stack.add_child(_label("FECHAMENTO DO DIA", 23, GOLD))
	title_stack.add_child(_label("Dia %d  ·  %d de %d clientes atendidos" % [day, customers_served, customers_total], 13, MUTED))
	header.add_child(_badge("LIVRARIA", Color("3a3021"), GOLD))

	var separator := ColorRect.new()
	separator.color = Color("66583a")
	separator.custom_minimum_size.y = 1
	layout.add_child(separator)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(grid)
	grid.add_child(_metric_card("CLIENTES ATENDIDOS", "%d / %d" % [customers_served, customers_total], "Clientes que concluíram uma compra.", GOLD))
	grid.add_child(_metric_card("VENDAS", "%d moedas" % sales_revenue, "%d transações concluídas." % sales_count, GREEN))
	var reputation_sign := "+" if reputation_change > 0 else ""
	var reputation_color := GREEN if reputation_change >= 0 else RED
	grid.add_child(_metric_card("REPUTAÇÃO", "%d  (%s%d)" % [reputation, reputation_sign, reputation_change], "Pontuação atual e variação do dia.", reputation_color))
	grid.add_child(_metric_card("CLIENTES SEM VENDA", "%d" % errors, "Clientes que encerraram o atendimento sem comprar.", RED if errors > 0 else GREEN))
	layout.add_child(_metric_card("LUCRO DO DIA", "%s%d moedas" % ["+" if profit > 0 else "", profit], "Vendas menos o custo de aquisição dos exemplares vendidos.", GOLD, true))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(footer)
	var next_day := Button.new()
	next_day.text = "ABRIR O PRÓXIMO DIA"
	next_day.custom_minimum_size = Vector2(250, 44)
	_style_button(next_day)
	next_day.pressed.connect(func() -> void: next_day_requested.emit())
	footer.add_child(next_day)

func _metric_card(title: String, value: String, detail: String, accent: Color, wide := false) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 92 if wide else 104)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(CARD, Color("514b3a"), 1, 12))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	card.add_child(content)
	content.add_child(_label(title, 11, MUTED))
	content.add_child(_label(value, 22 if wide else 20, accent))
	var detail_label := _label(detail, 10, MUTED)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail_label)
	return card

func _badge(text: String, background: Color, foreground: Color) -> Control:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(5)
	style.set_content_margin_all(8.0)
	badge.add_theme_stylebox_override("panel", style)
	badge.add_child(_label(text, 10, foreground))
	return badge

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel_style(background: Color, border: Color, border_width: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(padding)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 12
	return style

func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d5b56d")
	normal.border_color = Color("f0d79d")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(5)
	normal.set_content_margin_all(9.0)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("efd99e")
	hover.border_color = Color("fff0c7")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("b9954f")
	button.add_theme_stylebox_override("pressed", pressed)
