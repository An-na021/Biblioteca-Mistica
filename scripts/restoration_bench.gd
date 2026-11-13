extends Control

signal closed
signal completed(book_id: String)

const Art = preload("res://scripts/hud_art.gd")
const BackStyle = preload("res://scripts/back_button_style.gd")
const Ui = preload("res://scripts/restoration_ui.gd")
const DESK: Texture2D = preload("res://IMG/workshop/restoration_desk.png")
const OPEN_BOOK: Texture2D = preload("res://IMG/workshop/restoration_open_book.png")
const BRUSH: Texture2D = preload("res://IMG/workshop/restoration_brush.png")
const GLUE_POT: Texture2D = preload("res://IMG/workshop/restoration_glue_pot.png")
const Press = preload("res://scripts/restoration_press.gd")
const Sewing = preload("res://scripts/restoration_sewing.gd")
const Materials = preload("res://scripts/restoration_materials.gd")
const BrushDip = preload("res://scripts/restoration_brush_dip.gd")
const PressureRoller = preload("res://scripts/restoration_pressure_roller.gd")
const World = preload("res://scripts/shop_world.gd")
const Diagnosis = preload("res://scripts/restoration_diagnosis.gd")
const GLUE_POT_RECT := Rect2(1038, 137, 135, 135)
const GLUE_DIP_RECT := Rect2(1070.5, 169.5, 70, 70)
const BRUSH_REST_TIP := Vector2(1194, 245)
const BOOK_RECT := Rect2(253, 164, 690, 451)
const CLEAN_SPOTS = Materials.SPOTS
const PATCH_TARGETS = Materials.TARGETS
const SCRAP_HOMES = Materials.HOMES
const SEW_HOLES = Sewing.HOLES
const TOOLS := ["PINCEL", "COLA", "PAPEL / ROLETE", "AGULHA E LINHA", "PRENSA"]
const INSTRUCTIONS := [
	"Segure o botão do mouse e varra a poeira das três áreas do livro.",
	"Molhe o pincel no pote e espalhe uma camada fina na borda de cada rasgo.",
	"Encaixe os três papéis nos rasgos. Depois o rolete será equipado para assentar.",
	"Segure no furo dourado e puxe a agulha para o lado indicado.",
	"Arraste o manípulo para a direita para apertar a prensa.",
	"Trabalho concluído."
]
enum Stage { CLEAN, GLUE, PATCH, SEW, PRESS, DONE }

class WorkSurface extends Control:
	var bench: Control
	func _draw() -> void:
		bench.paint_work(self)

var book_id := ""
var target_condition := "usado"
var restoration_cost := World.RESTORATION_COST
var stage: int = Stage.CLEAN
var selected_tool := 0
var materials := Materials.new()
var cleaned: Array = materials.cleaned
var glued: Array = materials.glued
var glue_amount := 0.0
var brush_dip := BrushDip.new()
var pressure_roller := PressureRoller.new()
var patched: Array = materials.patched
var sewing := Sewing.new()
var stitch_count: int:
	get:
		return sewing.count
var press := Press.new()
var submitted := false
var result_received := false
var _pointer_down := false
var _last_point := Vector2.ZERO
var _pointer := Vector2.ZERO
var _pointer_known := false
var _drag_index := -1
var _drag_offset := Vector2.ZERO
var _drag_position := Vector2.ZERO
var _smoothing_index := -1
var _brush_angle := 0.55
var _brush_target_angle := 0.55
var _brush_contact := 0.0
var _elapsed := 0.0
var _cover: Texture2D
var _cover_book: Dictionary = {}
var diagnosis: Dictionary = Diagnosis.profile("complete")
var work_stages: Array[int] = [0, 1, 2, 3, 4]
var tool_audio: Node
var _surface: Control
var _book_visual: TextureRect
var _instruction: Label
var _stage_label: Label
var _materials_label: Label
var _progress_label: Label
var _progress_note: Control
var _status: Label
var _tray_label: Label
var _tray_caption: Label
var _paper_numbers: Array[Label] = []
var back_button: Button
var tool_buttons: Array[Button] = []
var _tool_plates: Array[Control] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tool_audio = preload("res://scripts/game_audio.gd").new()
	tool_audio.name = "ToolAudio"
	tool_audio.allow_while_paused = true
	add_child(tool_audio)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := TextureRect.new()
	background.texture = DESK
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.self_modulate = Color(0.83, 0.79, 0.68)
	_put(background, Rect2(0, 0, 1280, 720))
	_book_visual = TextureRect.new()
	_book_visual.texture = OPEN_BOOK
	_book_visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book_visual.stretch_mode = TextureRect.STRETCH_SCALE
	_book_visual.self_modulate = Color(0.9, 0.86, 0.74)
	_put(_book_visual, BOOK_RECT)
	_surface = WorkSurface.new()
	_surface.bench = self
	_surface.z_index = 1
	_put(_surface, Rect2(0, 0, 1280, 720))
	_panel(Rect2(20, 16, 1240, 89), "header")
	_put(_label("BANCADA DE RESTAURAÇÃO", 30, Color("edcb91")), Rect2(51, 23, 850, 37))
	var title := _label("", 20, Ui.IVORY, true)
	title.name = "BookTitle"
	_put(title, Rect2(52, 65, 830, 30))
	_stage_label = _label("", 22, Color("edcb91"))
	_put(_stage_label, Rect2(958, 28, 268, 30))
	_materials_label = _label("Conserto: 2 moedas ao concluir", 17)
	_put(_materials_label, Rect2(958, 67, 268, 24))
	_panel(Rect2(20, 139, 204, 487), "tools")
	var tools_title := _label("FERRAMENTAS", 20, Ui.IVORY)
	tools_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_put(tools_title, Rect2(32, 150, 180, 32))
	for index in range(TOOLS.size()):
		var button := Button.new()
		button.text = TOOLS[index]
		button.name = "Tool_" + str(index)
		_tool_plates.append(Ui.style_tool(button, index in [2, 4]))
		button.pressed.connect(func() -> void: select_tool(index))
		_put(button, Rect2(33, 197 + index * 61, 178, 45))
		tool_buttons.append(button)
	_progress_note = _panel(Rect2(30, 516, 184, 103), "paper")
	_progress_label = _label("", 17, Ui.INK)
	_progress_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_progress_label.add_theme_constant_override("line_spacing", -5)
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(_progress_label, Rect2(40, 523, 164, 88))
	_panel(Rect2(248, 112, 700, 48), "ribbon")
	_instruction = _label("", 18)
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(_instruction, Rect2(264, 116, 667, 41))
	_panel(Rect2(985, 277, 257, 335))
	_tray_label = _label("PAPÉIS DE REPARO", 19, Ui.IVORY)
	_tray_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_put(_tray_label, Rect2(1004, 287, 220, 30))
	for index in range(3):
		var number := _label("%d" % (index + 1), 24, Ui.IVORY, true)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_put(number, Rect2(1195, 332 + index * 100, 34, 39))
		_paper_numbers.append(number)
	_tray_caption = _label("Exemplar escolhido", 17, Ui.IVORY, true)
	_tray_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_put(_tray_caption, Rect2(1000, 570, 230, 27))
	_panel(Rect2(248, 639, 997, 64), "paper")
	_status = _label("", 17, Ui.INK)
	_status.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_put(_status, Rect2(263, 650, 964, 45))
	back_button = Button.new()
	back_button.text = "VOLTAR À MESA"
	BackStyle.apply(back_button)
	back_button.add_theme_font_override("font", Art.handwriting(false))
	back_button.add_theme_font_size_override("font_size", 17)
	back_button.pressed.connect(func() -> void: closed.emit())
	_put(back_button, Rect2(22, 655, 203, 45))
	_refresh()

func setup(book: Dictionary, value_condition := "usado", funds := -1, value_diagnosis: Dictionary = {}) -> void:
	book_id = str(book.get("id", ""))
	target_condition = value_condition if value_condition in World.RESTORATION_TARGETS else "usado"
	restoration_cost = World.restoration_cost(book_id, target_condition)
	_cover_book = book.duplicate()
	_cover = preload("res://scripts/book_cover_art.gd").texture_for(_cover_book, "danificado")
	diagnosis = Diagnosis.profile(str(value_diagnosis.get("id", "complete")))
	work_stages.assign(diagnosis.stages)
	stage = work_stages[0]
	selected_tool = stage
	if Stage.CLEAN not in work_stages:
		for index in range(cleaned.size()):
			cleaned[index] = 1.0
			for mote: Dictionary in materials.dust[index]:
				mote.health = 0.0
	get_node("BookTitle").text = str(book.get("title", "Livro")) + " · Danificado → " + str(BookCatalog.get_condition(target_condition).label)
	_materials_label.text = "Conserto: %d moedas ao concluir" % restoration_cost
	_status.text = "Diagnóstico: " + Diagnosis.summary(diagnosis)
	if funds >= 0 and funds < restoration_cost:
		_status.text += " Faltam %d moedas para concluir." % (restoration_cost - funds)
	_refresh()

func select_tool(index: int) -> void:
	if submitted or index not in work_stages:
		return
	selected_tool = clampi(index, 0, TOOLS.size() - 1)
	if brush_dip.active:
		_status.text = "Mergulho interrompido. Molhe o pincel novamente antes de colar."
	brush_dip.cancel()
	_pointer_down = false
	_smoothing_index = -1
	press.release_drag()
	sewing.release()
	_refresh()

func _refresh() -> void:
	var names := ["LIMPEZA", "APLICAR COLA", "COLAR PAPÉIS", "COSTURA", "PRENSAGEM", "FINALIZAÇÃO"]
	_stage_label.text = "%d/%d · %s" % [mini(work_stages.find(stage) + 1 if stage != Stage.DONE else work_stages.size(), work_stages.size()), work_stages.size(), names[stage]]
	_instruction.text = INSTRUCTIONS[stage]
	_tray_label.text = "LIVRO RESTAURADO" if stage == Stage.DONE else "LIVRO NA PRENSA" if stage == Stage.PRESS else "PAPÉIS DE REPARO" if Stage.PATCH in work_stages else "DIAGNÓSTICO"
	_tray_caption.visible = stage >= Stage.PRESS
	if Stage.PATCH not in work_stages and stage < Stage.PRESS:
		_tray_caption.text = Diagnosis.summary(diagnosis)
		_tray_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tray_caption.position = Vector2(1004, 335)
		_tray_caption.size = Vector2(220, 205)
		_tray_caption.visible = true
	elif stage >= Stage.PRESS:
		_tray_caption.text = "Exemplar escolhido"
		_tray_caption.position = Vector2(1000, 570)
		_tray_caption.size = Vector2(230, 27)
	for index in range(_paper_numbers.size()):
		_paper_numbers[index].visible = Stage.PATCH in work_stages and stage <= Stage.PATCH and not materials.laid[index]
	for index in range(tool_buttons.size()):
		tool_buttons[index].text = TOOLS[index]
		_tool_plates[index].set("selected", index == selected_tool)
		tool_buttons[index].disabled = submitted or index not in work_stages
		tool_buttons[index].tooltip_text = "Não necessário neste diagnóstico." if index not in work_stages else ""
	match stage:
		Stage.CLEAN:
			_progress_label.text = "Áreas limpas: %d/3\nLimpeza: %d%%" % [cleaned.filter(func(value: float) -> bool: return value >= 1.0).size(), materials.clean_percent()]
		Stage.GLUE:
			_progress_label.text = "Rasgos: %d/3\nCola: %d%%\nPincel: %s" % [glued.filter(func(value: float) -> bool: return value >= 1.0).size(), materials.glue_percent(), "mergulhando" if brush_dip.active else "com cola" if glue_amount > 0.0001 else "seco"]
		Stage.PATCH:
			var roller_ready := materials.papers_ready_for_roller()
			tool_buttons[2].text = "ROLETE" if roller_ready else "PAPEL"
			_progress_label.text = "Remendos: %d/3" % materials.laid.count(true)
			if roller_ready:
				_stage_label.text = "%d/%d · ASSENTAR PAPÉIS" % [work_stages.find(stage) + 1, work_stages.size()]
				_instruction.text = "Use o rolete sobre os remendos. Acompanhe o assentamento na lateral."
				_progress_label.text += "\nAssentados: %d/3" % patched.count(true)
			if _smoothing_index >= 0:
				_progress_label.text += "\nAssentando: %d%%" % mini(99, floori(materials.smooth_amount(_smoothing_index) * 100))
		Stage.SEW:
			_progress_label.text = "Passagens: %d/%d\nPontos firmes: %d/4" % [stitch_count, SEW_HOLES.size(), stitch_count / 2]
			if sewing.phase == Sewing.Phase.PULLING:
				_progress_label.text += "\nLinha: %d%%" % roundi(sewing.pull * 100)
			_instruction.text = sewing.instruction()
		Stage.PRESS:
			_progress_label.text = press.progress_text()
			_instruction.text = press.instruction()
			_status.text = press.instruction()
		Stage.DONE:
			var done := PackedStringArray()
			for step in work_stages:
				done.append(str(names[step]).capitalize() + " ✓")
			_progress_label.text = "\n".join(done)
	_progress_note.size.y = minf(103.0, 22.0 * (_progress_label.text.count("\n") + 1) + 17.0)
	_surface.queue_redraw()

func _next_stage() -> void:
	if submitted:
		return
	var next := work_stages.find(stage) + 1
	stage = work_stages[next] if next < work_stages.size() else Stage.DONE
	glue_amount = 0.0
	brush_dip.cancel()
	selected_tool = [0, 1, 2, 3, 4, 4][stage]
	_pointer_down = false
	_drag_index = -1
	_smoothing_index = -1
	press.release_drag()
	if stage == Stage.SEW:
		sewing.move(_pointer)
	_status.text = "Etapa concluída. " + INSTRUCTIONS[stage]
	_book_visual.visible = not (Stage.PRESS in work_stages and stage >= Stage.PRESS)
	tool_audio.silence()
	if stage == Stage.DONE:
		submitted = true
	_refresh()
	if submitted:
		completed.emit(book_id)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or submitted:
		return
	if event is InputEventMouseMotion:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		_pointer = point
		_pointer_known = true
		if stage == Stage.SEW and selected_tool == 3:
			var previous_pull := sewing.pull
			sewing.move(point)
			if sewing.pull > previous_pull:
				tool_audio.engage("thread", minf(1, (sewing.pull - previous_pull) * 10))
			_status.text = sewing.message
			_refresh()
		elif stage == Stage.PRESS and press.dragging:
			var before := press.turns
			press.drag(point - _last_point)
			if not is_equal_approx(before, press.turns):
				tool_audio.engage("press", minf(1, point.distance_to(_last_point) / 25))
			_refresh()
		elif _drag_index >= 0:
			_drag_position = point - _drag_offset
		elif _pointer_down:
			_work_stroke(point)
		_last_point = point
		_surface.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		_pointer = point
		_pointer_known = true
		if not event.pressed:
			_pointer_down = false
			_smoothing_index = -1
			if stage == Stage.PATCH:
				_refresh()
			press.release_drag()
			if stage == Stage.SEW:
				sewing.release()
				_status.text = sewing.message
				_refresh()
			if _drag_index >= 0:
				_drop_scrap(point - _drag_offset)
				get_viewport().set_input_as_handled()
			return
		if not Rect2(248, 164, 997, 463).has_point(point) and not (stage == Stage.GLUE and _is_over_glue(point)):
			return
		_last_point = point
		_pointer_down = true
		_work_press(point)
		get_viewport().set_input_as_handled()

func _work_press(point: Vector2) -> void:
	if brush_dip.active:
		return
	match stage:
		Stage.GLUE:
			if selected_tool == 1 and _is_over_glue(point):
				_begin_glue_dip()
			elif selected_tool == 1 and GLUE_POT_RECT.has_point(point):
				_status.text = "Molhe a ponta do pincel na cola clara, dentro da abertura do pote."
		Stage.PATCH:
			if selected_tool == 2:
				_smoothing_index = _smoothing_target(point)
				if _smoothing_index >= 0:
					_status.text = "Pressione com o rolete por cerca de 5 segundos. Passadas lentas ajudam a assentar o papel."
					return
				for index in range(SCRAP_HOMES.size()):
					if not materials.laid[index] and point.distance_to(materials.paper_centers[index]) < 48:
						_drag_index = index
						_drag_offset = point - materials.paper_centers[index]
						_drag_position = materials.paper_centers[index]
		Stage.SEW:
			if selected_tool != 3:
				_status.text = "Selecione AGULHA E LINHA para costurar a capa à lombada."
				return
			sewing.begin(point)
			_status.text = sewing.message
		Stage.PRESS:
			if selected_tool == 4:
				press.begin_drag(point)
	_refresh()

func _work_stroke(point: Vector2) -> void:
	if brush_dip.active:
		return
	if stage == Stage.GLUE and selected_tool == 1 and _is_over_glue(point):
		if not _is_over_glue(_last_point):
			_begin_glue_dip()
		_refresh()
		return
	var distance := minf(35.0, point.distance_to(_last_point))
	if distance <= 0.001:
		return
	if stage == Stage.CLEAN and selected_tool == 0:
		if materials.clean_segment(_last_point, point):
			tool_audio.engage("brush", distance / 35)
		_brush_target_angle = 0.55 + clampf((point.x - _last_point.x) * 0.006, -0.18, 0.18)
		if _finish_cleaning_if_ready():
			return
	elif stage == Stage.GLUE and selected_tool == 1:
		_brush_target_angle = 0.55 + clampf((point.x - _last_point.x) * 0.006, -0.18, 0.18)
		var previous := glue_amount
		glue_amount = materials.apply_glue(_last_point, point, glue_amount)
		if glue_amount < previous:
			tool_audio.engage("glue", distance / 35)
		if _finish_glue_if_ready():
			return
		elif previous <= 0.0001:
			_status.text = "O pincel está sem cola. Molhe as cerdas na abertura do pote antes de aplicar no livro."
		elif glue_amount < previous:
			_status.text = "Recarregue o pincel para preparar o próximo rasgo." if glue_amount == 0.0 else "Espalhe a cola pelas bordas ainda secas. A camada clara mostra onde o pincel passou."
	elif stage == Stage.PATCH and selected_tool == 2:
		_smoothing_index = _smoothing_target(point)
		if _smoothing_index >= 0:
			tool_audio.engage("roller", distance / 35)
		if _smoothing_index >= 0 and materials.smooth(_smoothing_index, _last_point, point):
			_finish_smoothing()
	_refresh()

func _smoothing_target(point: Vector2) -> int:
	if not materials.papers_ready_for_roller():
		return -1
	for index in range(PATCH_TARGETS.size()):
		if materials.laid[index] and not patched[index] and materials.smooth_contains(index, point):
			return index
	return -1

func _finish_smoothing() -> void:
	_status.text = "Remendo pronto! Faça o mesmo nos restantes."
	_smoothing_index = -1
	if patched.all(func(value: bool) -> bool: return value):
		_next_stage()

func _finish_cleaning_if_ready() -> bool:
	if stage != Stage.CLEAN:
		return false
	materials.update_clean_completion()
	if cleaned.all(func(value: float) -> bool: return value >= 1.0):
		_next_stage()
		return true
	return false

func _finish_glue_if_ready() -> bool:
	if stage != Stage.GLUE:
		return false
	glue_amount = maxf(0, glue_amount - materials.update_glue_completion())
	if glued.all(func(value: float) -> bool: return value >= 1.0):
		_next_stage()
		return true
	return false

func _is_over_glue(point: Vector2) -> bool:
	var offset := (point - GLUE_DIP_RECT.get_center()) / (GLUE_DIP_RECT.size * 0.5)
	return offset.length_squared() <= 1.0

func _begin_glue_dip() -> void:
	brush_dip.begin(_pointer, GLUE_DIP_RECT.get_center(), _brush_angle)
	tool_audio.one_shot("dip")
	_status.text = "Molhando as cerdas na cola. Aguarde o pincel levantar."

func _drop_scrap(point: Vector2) -> void:
	var index := _drag_index
	_drag_index = -1
	if point.distance_to(PATCH_TARGETS[index]) <= 22:
		if glued[index] >= 1.0:
			materials.lay(index)
			tool_audio.one_shot("paper")
			_status.text = "Os três papéis estão no lugar. Use o rolete por cerca de 5 segundos em cada remendo." if materials.papers_ready_for_roller() else "Remendo no lugar. Encaixe os papéis restantes para liberar o rolete."
		else:
			_status.text = "Passe COLA sobre esse rasgo antes de colocar o papel."
			materials.return_paper(index)
	else:
		_status.text = "Esse pedaço precisa encaixar no rasgo com o mesmo formato. Tente novamente."
		materials.return_paper(index)
	_refresh()

func _process(delta: float) -> void:
	_elapsed += delta
	if brush_dip.advance(delta):
		glue_amount = 1.0
		_pointer_down = false
		_last_point = _pointer
		_status.text = "Pincel carregado. Segure o botão do mouse e passe as cerdas sobre um rasgo."
		_refresh()
	materials.advance(delta, _drag_index, _drag_position)
	_brush_angle = lerp_angle(_brush_angle, _brush_target_angle, 1.0 - exp(-delta * 15))
	_brush_contact = move_toward(_brush_contact, 1.0 if _pointer_down else 0.0, delta * 8)
	var roller_target := _smoothing_target(_pointer) if stage == Stage.PATCH and selected_tool == 2 and _drag_index < 0 else -1
	pressure_roller.advance(delta, _pointer, roller_target, _pointer_down)
	if stage == Stage.CLEAN:
		_finish_cleaning_if_ready()
	elif stage == Stage.GLUE:
		_finish_glue_if_ready()
	if stage == Stage.PATCH and selected_tool == 2 and _pointer_down and _drag_index < 0:
		_smoothing_index = _smoothing_target(_pointer)
		if _smoothing_index >= 0:
			if materials.smooth(_smoothing_index, _pointer, _pointer, delta):
				_finish_smoothing()
			_refresh()
	if stage == Stage.SEW:
		var old_phase: int = sewing.phase
		sewing.advance(delta)
		if sewing.phase == Sewing.Phase.COMPLETE:
			_next_stage()
		else:
			if sewing.phase != old_phase:
				tool_audio.one_shot("needle" if sewing.phase == Sewing.Phase.PULLING else "thread")
				_status.text = sewing.message
			_refresh()
	if stage == Stage.PRESS and not submitted:
		press.advance(delta)
		if press.phase == Press.Phase.FINISHED:
			_next_stage()
		else:
			_refresh()
	_surface.queue_redraw()

func can_submit(value_book_id: String) -> bool:
	return value_book_id == book_id and stage == Stage.DONE and submitted and not result_received

func show_result(success: bool) -> void:
	result_received = true
	if success:
		_cover = preload("res://scripts/book_cover_art.gd").texture_for(_cover_book, target_condition)
		_surface.queue_redraw()
	_instruction.text = "LIVRO RESTAURADO" if success else "NÃO FOI POSSÍVEL FINALIZAR"
	_status.text = "Livro devolvido ao estoque como %s. Conserto: %d moedas. O próximo restauro estará disponível amanhã." % [str(BookCatalog.get_condition(target_condition).label), restoration_cost] if success else "Saldo insuficiente ou exemplar indisponível. Nenhuma moeda foi cobrada e nenhum livro foi alterado."
	back_button.text = "VOLTAR À MESA"

func _shape(index: int, center: Vector2) -> PackedVector2Array:
	return materials.shape(index, center)

func paint_work(painter: Control) -> void:
	# The pot and resting brush belong to the worktop throughout the restoration.
	painter.draw_set_transform(GLUE_POT_RECT.get_center() + Vector2(2, 3))
	painter.draw_circle(Vector2.ZERO, 51, Color(0.07, 0.035, 0.015, 0.28), true, -1, true)
	painter.draw_set_transform(Vector2.ZERO)
	painter.draw_texture_rect(GLUE_POT, GLUE_POT_RECT, false, Color(0.86, 0.82, 0.72))
	brush_dip.paint_surface(painter)
	if stage == Stage.GLUE and selected_tool == 1 and _is_over_glue(_pointer) and not brush_dip.active:
		painter.draw_set_transform(GLUE_DIP_RECT.get_center())
		painter.draw_arc(Vector2.ZERO, GLUE_DIP_RECT.size.x * 0.5, 0, TAU, 40, Color(1.0, 0.85, 0.45, 0.65 + sin(_elapsed * 4) * 0.2), 2, true)
		painter.draw_set_transform(Vector2.ZERO)
	var show_press := Stage.PRESS in work_stages and stage >= Stage.PRESS
	if not show_press:
		if Stage.PATCH in work_stages:
			materials.paint_holes(painter)
		for index in range(PATCH_TARGETS.size()):
			if materials.laid[index]:
				materials.paint_paper(painter, index)
		materials.paint_dust(painter)
		if stage == Stage.SEW:
			sewing.paint(painter, _elapsed, selected_tool == 3)
	else:
		_paint_press(painter)
	if stage == Stage.DONE and not show_press and _cover != null:
		painter.draw_texture_rect(_cover, Rect2(1030, 330, 166, 224), false)
	if stage <= Stage.PATCH and Stage.PATCH in work_stages:
		for index in range(SCRAP_HOMES.size()):
			if not materials.laid[index] and index != _drag_index:
				materials.paint_paper(painter, index)
		if _drag_index >= 0:
			if _drag_position.distance_to(PATCH_TARGETS[_drag_index]) < 90:
				var guide := _shape(_drag_index, PATCH_TARGETS[_drag_index])
				guide.append(guide[0])
				painter.draw_polyline(guide, Color(0.67, 0.52, 0.3, 0.4), 1, true)
			materials.paint_paper(painter, _drag_index)
	_paint_brush(painter)
	if stage == Stage.PATCH and selected_tool == 2 and materials.papers_ready_for_roller():
		# Equip only after every paper is placed, then keep it visible between repairs.
		pressure_roller.paint(painter, _pointer if _pointer_known else Vector2(930, 575))

func _paint_brush(painter: Control) -> void:
	var following := selected_tool in [0, 1] and not submitted and _pointer_known and Rect2(0, 0, 1280, 720).has_point(_pointer)
	var tip := _pointer if following else BRUSH_REST_TIP
	var angle := _brush_angle if following else 0.2
	if brush_dip.active:
		tip = brush_dip.position(_pointer)
		angle = brush_dip.angle()
	var brush_scale := 1.0 - brush_dip.depth() * 0.08
	var contact := _brush_contact if following else 0.0
	var brush_size := BRUSH.get_size() * (100.0 / BRUSH.get_height())
	# Keep the bristle edge on the mouse position throughout the workbench.
	var brush_tip := brush_size * Vector2(0.5, 0.976)
	painter.draw_set_transform(tip + Vector2(3, 4), angle, Vector2.ONE * brush_scale)
	painter.draw_texture_rect(BRUSH, Rect2(-brush_tip, brush_size), false, Color(0.08, 0.04, 0.015, 0.18 * (1 - brush_dip.depth() * 0.7)))
	painter.draw_set_transform(tip, angle, Vector2.ONE * brush_scale)
	painter.draw_texture_rect(BRUSH, Rect2(-brush_tip, brush_size), false, Color(0.96, 0.92, 0.82))
	if contact > 0:
		for bristle in range(-7, 8, 3):
			painter.draw_line(Vector2(bristle, -2), Vector2(bristle + (angle - 0.55) * 13, contact * 2), Color(0.78, 0.68, 0.45, 0.5), 0.6, true)
	var wet := brush_dip.wetness() if brush_dip.active else glue_amount
	brush_dip.paint_coating(painter, wet, contact)
	painter.draw_set_transform(Vector2.ZERO)
	brush_dip.paint_paste(painter, tip, angle, brush_scale)

func _paint_press(painter: Control) -> void:
	press.paint(painter, _cover, _pointer, _elapsed)
	# The selected cover identifies the actual stock copy, alongside the tool.
	if _cover != null:
		var cover_size := _cover.get_size()
		cover_size *= minf(166.0 / cover_size.x, 224.0 / cover_size.y)
		var cover_rect := Rect2(Vector2(1114, 442) - cover_size * 0.5, cover_size)
		painter.draw_rect(cover_rect.grow(4), Color("705434"), true)
		painter.draw_texture_rect(_cover, cover_rect, false, Color(0.83, 0.77, 0.63))
	else:
		painter.draw_texture_rect(OPEN_BOOK, Rect2(1006, 364, 217, 158), false, Color(0.83, 0.77, 0.63))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var was_dipping := brush_dip.active
		brush_dip.cancel()
		press.release_drag()
		sewing.release()
		_pointer_down = false
		_smoothing_index = -1
		if _drag_index >= 0:
			materials.return_paper(_drag_index)
			_drag_index = -1
		if was_dipping:
			_status.text = "Mergulho interrompido. Molhe o pincel novamente antes de colar."
			_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		closed.emit()
		get_viewport().set_input_as_handled()

func _put(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
	if not control is BaseButton:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)

func _label(text: String, font_size: int, color := Ui.IVORY, italic := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Art.handwriting(italic))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.07, 0.04, 0.02, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _panel(rect: Rect2, kind := "panel") -> Control:
	var panel := Ui.Frame.new()
	panel.kind = kind
	_put(panel, rect)
	return panel
