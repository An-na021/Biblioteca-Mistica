extends RefCounted

# The fixed frame and moving parts are separate from the corrected closed book.
const PARTS: Texture2D = preload("res://IMG/workshop/restoration_press_parts.png")
const CLOSED_BOOK: Texture2D = preload("res://IMG/workshop/restoration_closed_book.png")
const MAX_TURNS := 2.0
const PIXELS_PER_TURN := 240.0
const DRY_SECONDS := 3.5
const TRAVEL := 44.0
const FRAME_RECT := Rect2(370, 260, 458, 366)
enum Phase { TIGHTEN, DRY, RELEASE, FINISHED }

var turns := 0.0
var visual_turns := 0.0
var dry_time := 0.0
var phase: int = Phase.TIGHTEN
var dragging := false
var _parts: Array[AtlasTexture] = []
var _book := AtlasTexture.new()
var _shaft := StyleBoxFlat.new()

func _init() -> void:
	_book.atlas = CLOSED_BOOK
	_book.region = CLOSED_BOOK.get_image().get_used_rect()
	_book.filter_clip = true
	_shaft.bg_color = Color("a78243")
	_shaft.border_color = Color("49361c")
	_shaft.set_border_width_all(2)
	# Atlas regions are scaled with the source resolution; no images are rewritten.
	var regions := [Rect2(16, 35, 608, 598), Rect2(640, 252, 608, 221), Rect2(16, 825, 608, 165)]
	var scale := PARTS.get_size() / Vector2(1280, 1280)
	for region: Rect2 in regions:
		var texture := AtlasTexture.new()
		texture.atlas = PARTS
		texture.region = Rect2(region.position * scale, region.size * scale)
		texture.filter_clip = true
		_parts.append(texture)

func compression() -> float:
	return turns / MAX_TURNS

func handle_center() -> Vector2:
	return Vector2(600, 188 + TRAVEL * visual_turns / MAX_TURNS)

func handle_rect() -> Rect2:
	var width := 84.0 + absf(cos(visual_turns * TAU)) * 200.0
	return Rect2(handle_center() - Vector2(width * 0.5 + 9, 32), Vector2(width + 18, 60))

func begin_drag(point: Vector2) -> bool:
	dragging = phase != Phase.FINISHED and handle_rect().has_point(point)
	return dragging

func drag(delta: Vector2) -> void:
	if not dragging:
		return
	# A captured drag can leave the handle, so the rotating grip never drops the mouse.
	turns = clampf(turns + clampf(delta.x, -70.0, 70.0) / PIXELS_PER_TURN, 0.0, MAX_TURNS)
	if turns >= MAX_TURNS - 0.0001:
		turns = MAX_TURNS
	elif turns < 0.0001:
		turns = 0.0
	if phase == Phase.RELEASE:
		if is_zero_approx(turns):
			dragging = false
	elif turns >= MAX_TURNS:
		phase = Phase.DRY
	else:
		phase = Phase.TIGHTEN
		dry_time = 0.0

func release_drag() -> void:
	dragging = false

func advance(delta: float) -> void:
	visual_turns = lerpf(visual_turns, turns, 1.0 - exp(-delta * 18))
	if absf(visual_turns - turns) < 0.002:
		visual_turns = turns
	if phase == Phase.DRY and MAX_TURNS - visual_turns < 0.008:
		dry_time = minf(DRY_SECONDS, dry_time + delta)
		if dry_time >= DRY_SECONDS:
			phase = Phase.RELEASE
			dragging = false
	elif phase == Phase.RELEASE and is_zero_approx(turns) and is_zero_approx(visual_turns):
		phase = Phase.FINISHED

func instruction() -> String:
	match phase:
		Phase.TIGHTEN:
			return "Clique no manípulo e arraste para a direita para girar o parafuso e baixar a placa."
		Phase.DRY:
			return "Livro sob pressão. Aguarde a secagem; o parafuso mantém a placa apertada."
		Phase.RELEASE:
			return "Cola seca. Arraste o manípulo para a esquerda para subir a placa e liberar o livro."
	return "Prensa aberta. Livro restaurado."

func progress_text() -> String:
	if phase == Phase.DRY:
		return "Pressão: 100%%\nSecagem: %d%%" % roundi(100.0 * dry_time / DRY_SECONDS)
	if phase == Phase.RELEASE:
		return "Secagem: 100%%\nAbrindo: %d%%" % roundi(100.0 * (1.0 - compression()))
	return "Aperto: %d%%\nArraste o manípulo →" % roundi(100.0 * compression())

func paint(painter: Control, cover: Texture2D, pointer: Vector2, elapsed: float) -> void:
	var display_compression := visual_turns / MAX_TURNS
	var travel := TRAVEL * display_compression
	var handle := handle_center()
	var tint := Color(0.87, 0.83, 0.72)
	# The screw travels through the fixed crossbeam, which occludes its middle.
	var screw_bottom := 404.0 + travel
	_paint_shaft(painter, handle.y + 8, screw_bottom)
	painter.draw_texture_rect(_parts[0], FRAME_RECT, false, tint)
	# The flat book is separate from the frame and remains supported by the base.
	var squash := maxf(0.0, display_compression - 0.9) * 20.0
	var book_rect := Rect2(473, 489 + squash, 250, 72 - squash)
	painter.draw_texture_rect(_book, book_rect, false, tint)
	if cover != null:
		var top := PackedVector2Array()
		for uv in [Vector2(0.1, 0.07), Vector2(0.93, 0.07), Vector2(0.98, 0.48), Vector2(0.03, 0.48)]:
			top.append(book_rect.position + uv * book_rect.size)
		painter.draw_polygon(top, PackedColorArray([Color(0.65, 0.57, 0.43)]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), cover)
	# A contact shadow grows only as the platen approaches the actual cover.
	var shadow := Rect2(476, 520, 247, 7)
	painter.draw_rect(shadow, Color(0.08, 0.05, 0.02, 0.12 + display_compression * 0.38))
	painter.draw_texture_rect(_parts[1], Rect2(455, 374 + travel, 290, 106), false, tint)
	# The shaft enters the socket behind its front rim instead of floating above it.
	_paint_shaft(painter, 374 + travel, screw_bottom)
	# Rotate around the VERTICAL screw: grips retain their volume while changing depth.
	var angle := visual_turns * TAU
	var offset := Vector2(cos(angle) * 102.0, sin(angle) * 15.0)
	var grip_size := Vector2(84.0 - 12.0 * absf(sin(angle)), 34.0)
	var handle_size := _parts[2].get_size()
	var left_source := Rect2(Vector2(0, 0.26) * handle_size, Vector2(0.36, 0.68) * handle_size)
	var right_source := Rect2(Vector2(0.64, 0.26) * handle_size, Vector2(0.36, 0.68) * handle_size)
	var left_rect := Rect2(handle - offset - grip_size * 0.5, grip_size)
	var right_rect := Rect2(handle + offset - grip_size * 0.5, grip_size)
	painter.draw_line(handle - offset, handle + offset, Color("62451d"), 8, true)
	painter.draw_line(handle - offset - Vector2(0, 1), handle + offset - Vector2(0, 1), Color("c5a263"), 4, true)
	if offset.y > 0:
		painter.draw_texture_rect_region(_parts[2], left_rect, left_source, tint)
	else:
		painter.draw_texture_rect_region(_parts[2], right_rect, right_source, tint)
	painter.draw_texture_rect_region(_parts[2], Rect2(handle - Vector2(22, 32), Vector2(44, 54)), Rect2(Vector2(0.42, 0) * handle_size, Vector2(0.16, 0.95) * handle_size), tint)
	if offset.y > 0:
		painter.draw_texture_rect_region(_parts[2], right_rect, right_source, tint)
	else:
		painter.draw_texture_rect_region(_parts[2], left_rect, left_source, tint)
	if phase in [Phase.TIGHTEN, Phase.RELEASE] and (handle_rect().has_point(pointer) or dragging):
		painter.draw_rect(handle_rect(), Color(1.0, 0.85, 0.42, 0.35 + sin(elapsed * 4.0) * 0.12), false, 2, true)
	var progress := compression()
	if phase == Phase.DRY:
		progress = dry_time / DRY_SECONDS
	elif phase in [Phase.RELEASE, Phase.FINISHED]:
		progress = 1.0 - compression()
	painter.draw_rect(Rect2(438, 629, 325, 6), Color("292319"), true)
	painter.draw_rect(Rect2(438, 629, 325 * progress, 6), Color("d4b76d"), true)

func _paint_shaft(painter: Control, top: float, bottom: float) -> void:
	painter.draw_style_box(_shaft, Rect2(589, top, 22, bottom - top))
	painter.draw_rect(Rect2(590, top, 4, bottom - top), Color("735329"))
	painter.draw_rect(Rect2(596, top, 5, bottom - top), Color("bd9a58"))
	painter.draw_rect(Rect2(606, top, 4, bottom - top), Color("6b4f29"))
	# Thread phase is anchored to the rotating screw, including the visible socket tip.
	var first := floori(top / 8.0) - 1
	for index in range(first, ceili(bottom / 8.0)):
		var y := index * 8.0 + fposmod(visual_turns * 12.0, 8.0)
		if y >= top and y + 6 <= bottom:
			painter.draw_line(Vector2(590, y + 6), Vector2(610, y), Color("49361c"), 3, true)
			painter.draw_line(Vector2(591, y + 3), Vector2(609, y - 3), Color("d8b777"), 1.4, true)

