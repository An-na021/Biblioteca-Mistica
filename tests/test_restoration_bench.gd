extends SceneTree

const Bench = preload("res://scripts/restoration_bench.gd")
const Driver = preload("res://tests/restoration_input.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	print("PASS: " if value else "FAIL: ", message)
	if not value:
		failures += 1

func check_gentle_strokes() -> void:
	var bench := Bench.new()
	root.add_child(bench)
	bench.setup(BookCatalog.get_book("mar_vermelho"))
	bench.scale = Vector2.ONE * 0.75
	bench.position = Vector2(25, 20)
	var start: Vector2 = bench.CLEAN_SPOTS[0] - Vector2(10, 0)
	await Driver.move(self, bench, start)
	await Driver.button(self, bench, start, true)
	for step in range(1, 81):
		await Driver.move(self, bench, start + Vector2(step * 0.25, 0))
	await Driver.button(self, bench, start + Vector2(20, 0), false)
	check(bench.cleaned[0] > 0 and bench.cleaned[0] < 1 and bench.cleaned[1] == 0, "Pinceladas lentas de 0,25 pixel limpam a faixa tocada mesmo com bancada reduzida")
	var partial: float = bench.cleaned[0]
	await Driver.move(self, bench, bench.CLEAN_SPOTS[0] + Vector2(15, 0))
	check(is_equal_approx(bench.cleaned[0], partial), "Passar o cursor sem pressionar não limpa")
	for motes: Array in bench.materials.dust:
		for mote: Dictionary in motes:
			mote.health = 0.05
	bench.materials.update_clean_completion()
	await process_frame
	await process_frame
	check(bench.stage == Bench.Stage.GLUE and bench.selected_tool == 1 and not bench._pointer_down, "Resíduos tênues de 5% não travam a limpeza e COLA é selecionada sem outra pincelada")
	await Driver.dip_glue(self, bench)
	var rim: PackedVector2Array = bench._shape(0, bench.PATCH_TARGETS[0])
	start = rim[0]
	await Driver.move(self, bench, start)
	await Driver.button(self, bench, start, true)
	for step in range(1, 81):
		await Driver.move(self, bench, start.lerp(rim[1], step / 80.0))
	await Driver.button(self, bench, rim[1], false)
	check(bench.glued[0] > 0 and bench.glued[0] < 1 and bench.glued[1] == 0, "Movimentos curtos também espalham cola sem molhar outras bordas")
	bench.queue_free()
	await process_frame
	bench = Bench.new()
	root.add_child(bench)
	bench.setup(BookCatalog.get_book("mar_vermelho"))
	for index in range(2):
		for mote: Dictionary in bench.materials.dust[index]:
			mote.health = 0.0
	bench.materials.update_clean_completion()
	await process_frame
	check(bench.stage == Bench.Stage.CLEAN and bench.cleaned[2] == 0 and bench.materials.clean_percent() < 100, "Uma área ainda suja impede o avanço; a limpeza não exibe 100% antes de concluir")
	bench.queue_free()
	await process_frame

func check_fast_roller() -> void:
	var materials := Bench.Materials.new()
	for index in range(3):
		materials.lay(index)
	var center: Vector2 = materials.TARGETS[0]
	for step in range(1000):
		materials.smooth(0, center - Vector2(25, 0), center + Vector2(25, 0))
	check(not materials.patched[0] and is_zero_approx(materials.smooth_amount(0)), "Eventos rápidos sem tempo de pressão não assentam o remendo instantaneamente")
	for step in range(28):
		materials.smooth(0, center - Vector2(25, 0), center + Vector2(25, 0), 0.1)
	check(not materials.patched[0] and materials.smooth_amount(0) < 1.0, "Mesmo com muitas passadas, 2,8 segundos ainda não completam o novo assentamento")
	for step in range(5):
		materials.smooth(0, center - Vector2(25, 0), center + Vector2(25, 0), 0.1)
	check(materials.patched[0] and materials.smooth_amount(0) == 1.0, "Passadas contínuas concluem depois do tempo mínimo de pressão, sem travar em 100%")

func check_brush_dip() -> void:
	var bench := Bench.new()
	root.add_child(bench)
	bench.setup(BookCatalog.get_book("mar_vermelho"))
	bench.stage = Bench.Stage.GLUE
	bench.selected_tool = 1
	bench._refresh()
	var opening: Vector2 = bench.GLUE_DIP_RECT.get_center()
	await Driver.move(self, bench, opening)
	await Driver.button(self, bench, opening, true)
	check(bench.brush_dip.active and is_zero_approx(bench.glue_amount), "Clicar na abertura inicia o mergulho sem carregar cola antes da animação")
	await Driver.move(self, bench, bench.PATCH_TARGETS[0])
	await Driver.button(self, bench, bench.PATCH_TARGETS[0], false)
	check(bench.glued == [0.0, 0.0, 0.0], "Arrastar durante o mergulho não espalha cola nem cria uma pincelada entre o pote e o livro")
	await create_timer(bench.BrushDip.DURATION + 0.04).timeout
	check(not bench.brush_dip.active and is_equal_approx(bench.glue_amount, 1.0) and not bench._pointer_down, "Mergulho, mexida e retirada terminam com uma carga e exigem uma nova pincelada")
	bench.glue_amount = 0.0
	await Driver.move(self, bench, opening)
	await Driver.button(self, bench, opening, true)
	await Driver.button(self, bench, opening, false)
	await Driver.click(self, bench.tool_buttons[0])
	await create_timer(bench.BrushDip.DURATION + 0.04).timeout
	check(not bench.brush_dip.active and is_zero_approx(bench.glue_amount), "Trocar de ferramenta interrompe o mergulho sem conceder cola depois")
	await Driver.click(self, bench.tool_buttons[1])
	await Driver.move(self, bench, opening)
	await Driver.button(self, bench, opening, true)
	bench.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await create_timer(bench.BrushDip.DURATION + 0.04).timeout
	check(not bench.brush_dip.active and is_zero_approx(bench.glue_amount), "Perder o foco cancela o mergulho sem carregar o pincel em segundo plano")
	bench.queue_free()
	await process_frame

func check_glue_completion() -> void:
	var bench := Bench.new()
	root.add_child(bench)
	bench.setup(BookCatalog.get_book("mar_vermelho"))
	bench.stage = Bench.Stage.GLUE
	bench.selected_tool = 1
	for index in range(3):
		bench.materials.glue_cells[index].fill(0.998)
		bench.glued[index] = 0.998
	bench.glue_amount = 0.0
	bench._refresh()
	check(not bench._progress_label.text.contains("100%"), "Cobertura fracionária ainda não concluída não exibe 100% por arredondamento")
	await process_frame
	await process_frame
	check(bench.stage == Bench.Stage.PATCH and bench.selected_tool == 2 and bench.glued == [1.0, 1.0, 1.0], "Bordas 99,8% cobertas avançam automaticamente para PAPEL mesmo com pincel seco e sem novos cliques")
	bench.queue_free()
	await process_frame
	bench = Bench.new()
	root.add_child(bench)
	bench.setup(BookCatalog.get_book("mar_vermelho"))
	bench.stage = Bench.Stage.GLUE
	bench.selected_tool = 1
	for coverage in bench.materials.glue_cells:
		coverage.fill(1.0)
	bench.materials.glue_cells[2][0] = 0.0
	await process_frame
	await process_frame
	check(bench.stage == Bench.Stage.GLUE and bench.materials.glue_percent() < 100 and bench.glued[2] < 1, "Um trecho inteiramente seco continua impedindo o avanço")
	bench.materials.glue_cells[2].fill(1.0)
	await process_frame
	await process_frame
	check(bench.stage == Bench.Stage.PATCH and bench.selected_tool == 2, "Completar o último trecho libera PAPEL independentemente de outra pincelada")
	bench.queue_free()
	await process_frame

func run() -> void:
	root.size = Vector2i(1280, 720)
	check_fast_roller()
	await check_gentle_strokes()
	await check_brush_dip()
	await check_glue_completion()
	var bench := Bench.new()
	root.add_child(bench)
	bench.setup(BookCatalog.get_book("mar_vermelho"))
	paused = true
	var completed_ids: Array[String] = []
	bench.completed.connect(func(book_id: String) -> void: completed_ids.append(book_id))
	await Driver.click(self, bench.tool_buttons[3])
	await Driver.stroke(self, bench, bench.CLEAN_SPOTS[0])
	check(bench.stage == Bench.Stage.CLEAN and bench.cleaned[0] == 0.0 and completed_ids.is_empty(), "Agulha não limpa manchas nem pula etapas")
	await Driver.click(self, bench.tool_buttons[0])
	await Driver.stroke(self, bench, bench.CLEAN_SPOTS[0])
	check(bench.cleaned[0] > 0 and bench.cleaned[0] < 1 and bench.cleaned[1] == 0, "Pincel limpa apenas a faixa tocada, sem apagar toda a poeira ou outra área")
	check(bench.materials.dust[0].any(func(mote: Dictionary) -> bool: return float(mote.health) > 0.9), "Grãos fora das cerdas permanecem sobre o papel")
	await Driver.clean(self, bench)
	check(bench.stage == Bench.Stage.GLUE and bench.selected_tool == 1, "Limpar as três manchas avança e seleciona COLA automaticamente")
	await Driver.drag_scrap(self, bench, 0, bench.PATCH_TARGETS[0])
	check(not bench.patched[0] and bench.stage == Bench.Stage.GLUE, "Papel não pula a etapa de aplicar cola nos rasgos")
	await Driver.click(self, bench.tool_buttons[1])
	await Driver.stroke(self, bench, bench.PATCH_TARGETS[0])
	check(bench.glued == [0.0, 0.0, 0.0] and is_zero_approx(bench.glue_amount), "Pincel seco não aplica cola no livro")
	await Driver.move(self, bench, bench.GLUE_DIP_RECT.get_center())
	await Driver.stroke(self, bench, bench.PATCH_TARGETS[0])
	check(is_zero_approx(bench.glue_amount) and bench.glued[0] == 0.0, "Apenas passar o cursor sobre o pote não carrega o pincel")
	var body: Vector2 = bench.GLUE_POT_RECT.position + Vector2(67, 105)
	await Driver.move(self, bench, body)
	await Driver.button(self, bench, body, true)
	await Driver.button(self, bench, body, false)
	check(is_zero_approx(bench.glue_amount), "Clicar no vidro abaixo da abertura não molha as cerdas")
	var corner: Vector2 = bench.GLUE_DIP_RECT.position + Vector2(2, 2)
	await Driver.move(self, bench, corner)
	await Driver.button(self, bench, corner, true)
	await Driver.button(self, bench, corner, false)
	check(is_zero_approx(bench.glue_amount), "Cantos fora da abertura circular não carregam o pincel na visão de cima")
	await Driver.button(self, bench, body, true)
	await Driver.move(self, bench, bench.GLUE_DIP_RECT.get_center())
	await Driver.button(self, bench, bench.GLUE_DIP_RECT.get_center(), false)
	check(bench.brush_dip.active and is_zero_approx(bench.glue_amount), "Arrastar até a abertura começa a animação de molhar as cerdas")
	await create_timer(bench.BrushDip.DURATION + 0.04).timeout
	check(is_equal_approx(bench.glue_amount, 1.0), "Arrastar o pincel para a abertura do pote com o botão pressionado carrega a cola")
	var rim: PackedVector2Array = bench._shape(0, bench.PATCH_TARGETS[0])
	await Driver.move(self, bench, rim[0])
	await Driver.button(self, bench, rim[0], true)
	for cell in range(1, 9):
		await Driver.move(self, bench, rim[cell])
	await Driver.button(self, bench, rim[8], false)
	check(bench.glued[0] > 0 and bench.glued[0] < 1 and bench.materials.glue_cells[0].count(0.0) > 0, "Cola molha só a borda pincelada e deixa os demais trechos secos")
	await Driver.glue_rim(self, bench, 0)
	check(bench.glued[0] == 1.0 and is_zero_approx(bench.glue_amount), "Uma carga cobre a borda inteira de um rasgo e deixa o pincel seco")
	await Driver.stroke(self, bench, bench.PATCH_TARGETS[1])
	check(bench.glued[1] == 0.0, "Próximo rasgo exige recarregar o pincel no pote")
	await Driver.glue(self, bench)
	check(bench.stage == Bench.Stage.PATCH and bench.selected_tool == 2 and not bench._pointer_down, "Cola 3/3 avança para COLAR PAPÉIS com PAPEL selecionado e encerra a pincelada")
	await Driver.move(self, bench, bench.PATCH_TARGETS[2])
	check(bench.selected_tool == 2 and bench.patched.count(true) == 0 and completed_ids.is_empty(), "Após mudar de etapa, mover o mouse não cola pedaços sozinho")
	await Driver.drag_scrap(self, bench, 0, bench.PATCH_TARGETS[1])
	check(bench.patched.count(true) == 0, "Pedaço com formato errado volta para a bandeja")
	await Driver.drag_scrap(self, bench, 0, bench.PATCH_TARGETS[0], false)
	check(bench.materials.laid[0] and not bench.patched[0] and bench.stage == Bench.Stage.PATCH, "Encaixar o remendo ainda exige alisar o papel")
	await Driver.move(self, bench, bench.PATCH_TARGETS[0] + Vector2(25, 0))
	check(is_zero_approx(bench.materials.smooth_amount(0)), "Apenas passar o mouse não alisa o remendo")
	await Driver.stroke(self, bench, bench.PATCH_TARGETS[0])
	await create_timer(0.2).timeout
	check(not bench.materials.papers_ready_for_roller() and is_zero_approx(bench.materials.smooth_amount(0)) and bench.tool_buttons[2].text == "PAPEL", "Com um papel colocado, o rolete permanece guardado e pressionar ainda não assenta")
	await Driver.drag_scrap(self, bench, 1, bench.PATCH_TARGETS[1], false)
	check(not bench.materials.papers_ready_for_roller() and bench._smoothing_target(bench.PATCH_TARGETS[0]) == -1, "Dois papéis colocados ainda não liberam o rolete")
	await Driver.drag_scrap(self, bench, 2, bench.PATCH_TARGETS[2], false)
	check(bench.materials.papers_ready_for_roller() and bench.stage == Bench.Stage.PATCH and bench.selected_tool == 2 and bench.tool_buttons[2].text == "ROLETE", "O terceiro papel equipa o rolete automaticamente antes do assentamento")
	var paper_center: Vector2 = bench.PATCH_TARGETS[0]
	await Driver.move(self, bench, paper_center)
	await Driver.button(self, bench, paper_center, true)
	await create_timer(2.8).timeout
	check(bench.materials.smooth_amount(0) > 0 and not bench.patched[0], "O antigo tempo de 2,8 segundos ainda deixa o remendo parcialmente assentado")
	await Driver.move(self, bench, paper_center + Vector2(100, 0))
	var smoothing_before: float = bench.materials.smooth_amount(0)
	await create_timer(0.2).timeout
	check(is_equal_approx(bench.materials.smooth_amount(0), smoothing_before), "Segurar fora do remendo pausa o alisamento")
	await Driver.button(self, bench, paper_center + Vector2(100, 0), false)
	await create_timer(0.15).timeout
	check(is_equal_approx(bench.materials.smooth_amount(0), smoothing_before), "Soltar preserva o progresso parcial sem completar sozinho")
	await Driver.click(self, bench.tool_buttons[0])
	await Driver.stroke(self, bench, paper_center)
	check(is_equal_approx(bench.materials.smooth_amount(0), smoothing_before), "Pincel não alisa o remendo por engano")
	await Driver.click(self, bench.tool_buttons[2])
	await Driver.smooth_scrap(self, bench, 0)
	check(bench.patched[0], "Pressão mantida pelo novo tempo de alisamento conclui o remendo")
	await Driver.stroke(self, bench, bench.PATCH_TARGETS[1])
	check(bench.materials.smooth_amount(1) > 0, "Passadas de ida e volta também alisam, sem restrição de direção")
	await Driver.smooth_scrap(self, bench, 1)
	check(bench.stage == Bench.Stage.PATCH and bench.patched.count(true) == 2 and completed_ids.is_empty(), "Dois pedaços ainda não avançam para a costura")
	check(bench.stage == Bench.Stage.PATCH and bench.patched.count(true) == 2, "O terceiro papel colocado ainda precisa ser assentado antes da costura")
	var paper_edge: Vector2 = bench.PATCH_TARGETS[2] + Vector2(48, 0)
	await Driver.move(self, bench, paper_edge)
	await Driver.button(self, bench, paper_edge, true)
	await create_timer(bench.Materials.SMOOTH_SECONDS + 0.08).timeout
	await Driver.button(self, bench, paper_edge, false)
	check(bench.stage == Bench.Stage.SEW and bench.selected_tool == 3 and bench.patched.count(true) == 3, "Terceiro remendo alisado seleciona AGULHA E LINHA automaticamente")
	await Driver.move(self, bench, bench.SEW_HOLES.back())
	await Driver.button(self, bench, bench.SEW_HOLES.back(), true)
	await Driver.button(self, bench, bench.SEW_HOLES.back(), false)
	check(bench.stitch_count == 0, "Costura fora da ordem não prende a capa nem conclui o trabalho")
	var first_hole: Vector2 = bench.SEW_HOLES[0]
	await Driver.move(self, bench, first_hole)
	await Driver.button(self, bench, first_hole, true)
	await Driver.button(self, bench, first_hole, false)
	await create_timer(bench.Sewing.INSERT_SECONDS + 0.05).timeout
	check(bench.stitch_count == 0 and bench.sewing.phase == bench.Sewing.Phase.READY, "Clique rápido não atravessa o papel nem conclui um ponto")
	await Driver.begin_stitch(self, bench, 0)
	check(bench.stitch_count == 0 and bench.sewing.phase == bench.Sewing.Phase.PULLING, "Segurar atravessa o papel, mas exige puxar a linha antes de contar o ponto")
	await Driver.move(self, bench, first_hole + Vector2(65, 0))
	check(bench.stitch_count == 0 and is_zero_approx(bench.sewing.pull), "Puxar para dentro da lombada não aperta a linha")
	var partial := first_hole - Vector2(25, 0)
	await Driver.move(self, bench, partial)
	await Driver.button(self, bench, partial, false)
	check(bench.stitch_count == 0 and bench.sewing.pull > 0 and not bench.sewing.held, "Puxar parcialmente deixa linha frouxa e permite retomar a agulha")
	await Driver.move(self, bench, first_hole - Vector2(90, 0))
	check(bench.sewing.needle_tip.is_equal_approx(partial) and bench.stitch_count == 0, "Mover o cursor sem segurar não puxa a agulha solta")
	await Driver.click(self, bench.tool_buttons[0])
	await Driver.stroke(self, bench, first_hole)
	check(bench.stitch_count == 0 and bench.sewing.needle_tip.is_equal_approx(partial), "Trocar de ferramenta preserva o ponto incompleto sem costurar com o pincel")
	await Driver.click(self, bench.tool_buttons[3])
	await Driver.move(self, bench, partial)
	await Driver.button(self, bench, partial, true)
	await Driver.pull_stitch(self, bench, 0)
	check(bench.stitch_count == 1 and bench.sewing.phase == bench.Sewing.Phase.READY and bench.stage == Bench.Stage.SEW, "Retomar e esticar toda a linha aperta somente o ponto atual")
	await Driver.sew(self, bench, 1)
	check(bench.stage == Bench.Stage.PRESS and bench.selected_tool == 4 and bench.stitch_count == 8, "Oitava passagem com linha firme avança e seleciona PRENSA automaticamente")
	var handle: Vector2 = bench.press.handle_center()
	await Driver.move(self, bench, handle)
	await Driver.button(self, bench, handle, true)
	await create_timer(0.15).timeout
	await Driver.button(self, bench, handle, false)
	check(is_zero_approx(bench.press.turns) and is_zero_approx(bench.press.dry_time) and completed_ids.is_empty(), "Segurar o mouse sem girar não baixa a prensa nem seca a cola")
	await Driver.click(self, bench.tool_buttons[0])
	await Driver.turn_press(self, bench, 0.5)
	check(is_zero_approx(bench.press.turns), "Ferramenta errada não gira a prensa")
	await Driver.click(self, bench.tool_buttons[4])
	await Driver.stroke(self, bench, Vector2(600, 450))
	check(is_zero_approx(bench.press.turns), "Arrastar fora do manípulo não gira o parafuso")
	await Driver.turn_press(self, bench, 0.5)
	check(is_equal_approx(bench.press.turns, 0.5) and bench.press.compression() > 0 and bench.press.handle_center().y > handle.y, "Arrastar à direita gira e baixa o mecanismo mesmo ao sair da área inicial")
	await create_timer(0.1).timeout
	check(is_equal_approx(bench.press.turns, 0.5) and is_zero_approx(bench.press.dry_time), "Soltar o mouse mantém o parafuso na posição; aperto parcial não inicia a secagem")
	await Driver.turn_press(self, bench, -0.25)
	check(is_equal_approx(bench.press.turns, 0.25), "Arrastar à esquerda levanta a placa e alivia a pressão")
	await Driver.turn_press(self, bench, 1.75)
	await create_timer(0.4).timeout
	check(bench.press.phase == bench.Press.Phase.DRY and bench.press.dry_time > 0 and completed_ids.is_empty(), "Só o aperto completo inicia a secagem, sem concluir o restauro")
	await Driver.turn_press(self, bench, -0.25)
	check(bench.press.phase == bench.Press.Phase.TIGHTEN and is_zero_approx(bench.press.dry_time), "Abrir antes da cola secar interrompe a secagem")
	await Driver.turn_press(self, bench, 0.25)
	await create_timer(bench.Press.DRY_SECONDS + 0.4).timeout
	check(bench.press.phase == bench.Press.Phase.RELEASE and completed_ids.is_empty() and not bench.can_submit("mar_vermelho"), "Cola seca exige abrir a prensa antes de liberar o livro ou cobrar materiais")
	await Driver.turn_press(self, bench, -1.0)
	check(bench.stage == Bench.Stage.PRESS and completed_ids.is_empty(), "Abertura parcial não conclui nem retira o exemplar")
	await Driver.turn_press(self, bench, -1.0)
	check(bench.stage == Bench.Stage.DONE and completed_ids == ["mar_vermelho"] and bench.can_submit("mar_vermelho") and not bench.can_submit("inventario_chuva"), "Prensa seca e completamente aberta conclui apenas o exemplar trabalhado")
	bench.show_result(true)
	await Driver.press(self, bench)
	check(completed_ids.size() == 1 and not bench.can_submit("mar_vermelho"), "Repetir cliques após concluir não duplica a cobrança ou o exemplar")
	bench.queue_free()
	await process_frame
	paused = false
	print("RESULT: ", failures, " failure(s)")
	quit(0 if failures == 0 else 1)
