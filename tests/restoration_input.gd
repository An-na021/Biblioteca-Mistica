extends RefCounted

static func move(tree: SceneTree, bench: Control, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = bench.get_global_transform_with_canvas() * point
	tree.root.push_input(event)
	await tree.process_frame

static func button(tree: SceneTree, bench: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = bench.get_global_transform_with_canvas() * point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	tree.root.push_input(event)
	await tree.process_frame

static func click(tree: SceneTree, control: Control) -> void:
	await move(tree, control, control.size * 0.5)
	await button(tree, control, control.size * 0.5, true)
	await button(tree, control, control.size * 0.5, false)

static func stroke(tree: SceneTree, bench: Control, point: Vector2) -> void:
	await move(tree, bench, point - Vector2(25, 0))
	await button(tree, bench, point - Vector2(25, 0), true)
	for index in range(6):
		await move(tree, bench, point + Vector2(25 if index % 2 == 0 else -25, index % 3 * 3))
	await button(tree, bench, point, false)

static func clean(tree: SceneTree, bench: Control) -> void:
	await click(tree, bench.tool_buttons[0])
	for point in bench.CLEAN_SPOTS:
		await clean_area(tree, bench, point)

static func clean_area(tree: SceneTree, bench: Control, center: Vector2) -> void:
	for row in [-27.0, -14.0, 0.0, 14.0, 27.0]:
		var start := center + Vector2(-47, row)
		await move(tree, bench, start)
		await button(tree, bench, start, true)
		for sweep in range(3):
			for step in range(1, 9):
				var x := lerpf(-47, 47, step / 8.0) if sweep % 2 == 0 else lerpf(47, -47, step / 8.0)
				await move(tree, bench, center + Vector2(x, row))
		await button(tree, bench, center + Vector2(47, row), false)

static func glue(tree: SceneTree, bench: Control) -> void:
	await click(tree, bench.tool_buttons[1])
	for index in range(bench.PATCH_TARGETS.size()):
		if bench.glued[index] < 1.0:
			await dip_glue(tree, bench)
			await glue_rim(tree, bench, index)

static func glue_rim(tree: SceneTree, bench: Control, index: int) -> void:
	var contour: PackedVector2Array = bench._shape(index, bench.PATCH_TARGETS[index])
	await move(tree, bench, contour[0])
	await button(tree, bench, contour[0], true)
	for lap in range(5):
		for cell in range(1, contour.size() + 1):
			if bench.glued[index] >= 1.0:
				break
			await move(tree, bench, contour[cell % contour.size()])
		if bench.glued[index] >= 1.0:
			break
	await button(tree, bench, contour[0], false)

static func dip_glue(tree: SceneTree, bench: Control) -> void:
	await click(tree, bench.tool_buttons[1])
	var point: Vector2 = bench.GLUE_DIP_RECT.get_center()
	await move(tree, bench, point)
	await button(tree, bench, point, true)
	await button(tree, bench, point, false)
	await tree.create_timer(bench.BrushDip.DURATION + 0.04).timeout

static func drag_scrap(tree: SceneTree, bench: Control, index: int, target: Vector2, choose_tool := true) -> void:
	if choose_tool:
		await click(tree, bench.tool_buttons[2])
	var start: Vector2 = bench.materials.paper_centers[index]
	await move(tree, bench, start)
	await button(tree, bench, start, true)
	await move(tree, bench, target)
	await button(tree, bench, target, false)
	await tree.create_timer(0.12).timeout

static func smooth_scrap(tree: SceneTree, bench: Control, index: int) -> void:
	if bench.patched[index]:
		return
	var center: Vector2 = bench.PATCH_TARGETS[index]
	await move(tree, bench, center)
	await button(tree, bench, center, true)
	await tree.create_timer(bench.Materials.SMOOTH_SECONDS + 0.08).timeout
	await button(tree, bench, center, false)

static func patch(tree: SceneTree, bench: Control) -> void:
	for index in range(3):
		if not bench.materials.laid[index]:
			await drag_scrap(tree, bench, index, bench.PATCH_TARGETS[index], false)
	for index in range(3):
		if not bench.patched[index]:
			await smooth_scrap(tree, bench, index)

static func sew(tree: SceneTree, bench: Control, start := 0, end := 8) -> void:
	await click(tree, bench.tool_buttons[3])
	for index in range(start, mini(end, bench.SEW_HOLES.size())):
		await begin_stitch(tree, bench, index)
		await pull_stitch(tree, bench, index)

static func begin_stitch(tree: SceneTree, bench: Control, index: int, wait_time := -1.0) -> void:
	var point: Vector2 = bench.SEW_HOLES[index]
	await move(tree, bench, point)
	await button(tree, bench, point, true)
	var duration: float = bench.Sewing.INSERT_SECONDS + 0.04 if wait_time < 0 else wait_time
	await tree.create_timer(duration).timeout

static func pull_stitch(tree: SceneTree, bench: Control, index: int) -> void:
	var start: Vector2 = bench.sewing.needle_tip
	var direction := Vector2.LEFT if index % 2 == 0 else Vector2.RIGHT
	var target: Vector2 = bench.SEW_HOLES[index] + direction * (bench.Sewing.PULL_DISTANCE + 5)
	for step in range(1, 9):
		await move(tree, bench, start.lerp(target, step / 8.0))
	await button(tree, bench, target, false)
	await tree.create_timer(bench.Sewing.SETTLE_SECONDS + 0.04).timeout

static func turn_press(tree: SceneTree, bench: Control, turns: float) -> void:
	var remaining: float = absf(turns) * bench.Press.PIXELS_PER_TURN
	var direction := 1.0 if turns > 0 else -1.0
	while remaining > 0.001:
		var point: Vector2 = bench.press.handle_center()
		await move(tree, bench, point)
		await button(tree, bench, point, true)
		var gesture := minf(120.0, remaining)
		var distance := 0.0
		while distance < gesture:
			var step := minf(20.0, gesture - distance)
			distance += step
			await move(tree, bench, point + Vector2(distance * direction, 0))
		await button(tree, bench, point + Vector2(distance * direction, 0), false)
		remaining -= gesture
	if bench.press.phase == bench.Press.Phase.RELEASE and is_zero_approx(bench.press.turns):
		await tree.create_timer(0.4).timeout

static func press(tree: SceneTree, bench: Control) -> void:
	await click(tree, bench.tool_buttons[4])
	await turn_press(tree, bench, bench.Press.MAX_TURNS - bench.press.turns)
	await tree.create_timer(bench.Press.DRY_SECONDS + 0.4).timeout
	await turn_press(tree, bench, -bench.press.turns)
