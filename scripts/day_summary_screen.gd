class_name DaySummaryScreen
extends Control

signal next_day_requested
signal shop_requested
signal district_requested
signal livraria_requested

class CartButton extends Button:
	func _draw() -> void:
		var color := Color("211b14")
		draw_line(Vector2(10, 11), Vector2(16, 11), color, 2.5, true)
		draw_line(Vector2(16, 11), Vector2(20, 29), color, 2.5, true)
		draw_line(Vector2(20, 29), Vector2(37, 29), color, 2.5, true)
		draw_line(Vector2(19, 25), Vector2(35, 25), color, 2.5, true)
		draw_line(Vector2(20, 29), Vector2(18, 34), color, 2.5, true)
		draw_line(Vector2(18, 34), Vector2(36, 34), color, 2.5, true)
		draw_circle(Vector2(23, 38), 2.5, color)
		draw_circle(Vector2(33, 38), 2.5, color)

const INK := Color("211b14")
const PANEL := Color("201f19")
const CARD := Color("2d2c23")
const GOLD := Color("e4c477")
const MUTED := Color("b9ad96")
const GREEN := Color("a8c184")
const RED := Color("d99079")

func setup(day: int, customers_served: int, sales_count: int, sales_revenue: int, errors: int, reputation: int, reputation_change: int, profit: int, customers_total: int, progress_report: Dictionary = {}, district_name := "Centro", mistakes := 0, world_note := "") -> void:
	build(day, customers_served, sales_count, sales_revenue, errors, reputation, reputation_change, profit, customers_total, progress_report, district_name, mistakes, world_note)

func build(day: int, customers_served: int, sales_count: int, sales_revenue: int, errors: int, reputation: int, reputation_change: int, profit: int, customers_total: int, progress_report: Dictionary = {}, district_name := "Centro", mistakes := 0, world_note := "") -> void:
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
	panel.custom_minimum_size = Vector2(760, 660)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, GOLD, 2, 22))
	center.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 3)
	header.add_child(title_stack)
	title_stack.add_child(_label("FECHAMENTO DO DIA", 23, GOLD))
	title_stack.add_child(_label("Dia %d  ·  %d de %d clientes atendidos  ·  %d erro(s)" % [day, customers_served, customers_total, mistakes], 13, MUTED))
	header.add_child(_badge(district_name.to_upper(), Color("3a3021"), GOLD))

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

	var goals := HBoxContainer.new()
	goals.add_theme_constant_override("separation", 10)
	goals.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(goals)
	goals.add_child(_goal_group("OBJETIVOS DE HOJE", progress_report.get("daily_goals", []), "Recompensa diária: %d moedas" % int(progress_report.get("daily_reward", 0))))
	var weekly_reward_text := "Bônus ao concluir: %d moedas" % int(progress_report.get("weekly_reward_available", 25))
	if bool(progress_report.get("weekly_reward_claimed", false)):
		weekly_reward_text = "Recompensa semanal resgatada: %d moedas" % int(progress_report.get("weekly_reward", 0)) if int(progress_report.get("weekly_reward", 0)) > 0 else "Recompensa semanal já resgatada"
	goals.add_child(_goal_group("OBJETIVOS DA SEMANA %d" % int(progress_report.get("week_number", 1)), progress_report.get("weekly_goals", []), weekly_reward_text))

	var achievements: Array = progress_report.get("unlocked_achievements", [])
	var achievement_text := "CONQUISTAS DESBLOQUEADAS: %d" % int(progress_report.get("achievement_count", 0))
	if not achievements.is_empty():
		var achievement_names := PackedStringArray()
		for achievement in achievements:
			achievement_names.append(str(achievement.get("title", "Conquista")))
		achievement_text += "  ·  " + ", ".join(achievement_names)
	var achievement_line := _label(achievement_text, 10, GOLD)
	achievement_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(achievement_line)
	if not world_note.is_empty():
		layout.add_child(_label(world_note, 12, GOLD))

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	var shop := CartButton.new()
	shop.custom_minimum_size = Vector2(52, 44)
	shop.tooltip_text = "Comprar livros"
	_style_button(shop)
	shop.pressed.connect(func() -> void: shop_requested.emit())
	footer.add_child(shop)
	var districts := Button.new()
	districts.text = "BAIRROS"
	districts.custom_minimum_size = Vector2(130, 44)
	_style_button(districts)
	districts.pressed.connect(func() -> void: district_requested.emit())
	footer.add_child(districts)
	var livraria := Button.new()
	livraria.text = "LIVRARIA"
	livraria.custom_minimum_size = Vector2(130, 44)
	_style_button(livraria)
	livraria.pressed.connect(func() -> void: livraria_requested.emit())
	footer.add_child(livraria)
	var next_day := Button.new()
	next_day.text = "ABRIR O PRÓXIMO DIA"
	next_day.custom_minimum_size = Vector2(250, 44)
	_style_button(next_day)
	next_day.pressed.connect(func() -> void: next_day_requested.emit())
	footer.add_child(next_day)

func _goal_group(title: String, goals: Array, reward_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(CARD, Color("514b3a"), 1, 10))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	content.add_child(_label(title, 11, GOLD))
	for goal in goals:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		content.add_child(row)
		var marker := "✓" if bool(goal.get("completed", false)) else "○"
		row.add_child(_label(marker, 13, GREEN if bool(goal.get("completed", false)) else MUTED))
		var goal_title := _label(str(goal.get("title", "Objetivo")), 10, MUTED)
		goal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		goal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(goal_title)
		row.add_child(_label("%d/%d" % [int(goal.get("progress", 0)), int(goal.get("target", 1))], 10, MUTED))
	var reward := _label(reward_text, 10, GREEN)
	content.add_child(reward)
	return panel

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
