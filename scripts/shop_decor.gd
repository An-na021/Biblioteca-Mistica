extends Node2D

var upgrades: Dictionary = {}

func update_state(value: Dictionary) -> void:
	upgrades = value.duplicate()
	queue_redraw()

func _draw() -> void:
	if upgrades.has("lighting"):
		var light := Vector2(160, 392)
		for ring in range(16, 0, -1):
			draw_circle(light, float(ring) * 9.0, Color(1.0, 0.69, 0.23, 0.008))
		for index in range(5):
			var spot := light + Vector2(43 + index * 8, -46 + (index % 3) * 23)
			draw_circle(spot, 1.6, Color(1.0, 0.85, 0.48, 0.7))
	if upgrades.has("shelves"):
		var wood := Color("38271d")
		var gold := Color("b48a4b")
		draw_rect(Rect2(1071, 374, 156, 158), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(1066, 369, 156, 158), wood)
		draw_rect(Rect2(1066, 369, 156, 158), gold, false, 2.0)
		draw_rect(Rect2(1074, 378, 140, 141), Color("211b15"))
		for grain in range(10):
			draw_line(Vector2(1068 + grain % 3, 377 + grain * 14), Vector2(1072, 385 + grain * 14), Color("65462b"), 1.0)
		var colors := [Color("4f6c58"), Color("79423c"), Color("45576a"), Color("8b713e"), Color("6d526c")]
		for row in range(2):
			var baseline := 435.0 + row * 74.0
			for book in range(8):
				var height := float(38 + (book * 7 + row * 3) % 19)
				var spine := Rect2(1078 + book * 16, baseline - height, 13, height)
				draw_rect(spine, colors[(book + row) % colors.size()])
				draw_rect(Rect2(spine.position, Vector2(3, height)), colors[(book + row) % colors.size()].darkened(0.35))
				draw_line(spine.position + Vector2(2, 7), spine.position + Vector2(11, 7), gold, 1.0)
				draw_line(spine.position + Vector2(2, height - 5), spine.position + Vector2(11, height - 5), gold, 1.0)
				for engraving in range(3):
					draw_line(spine.position + Vector2(5, 15 + engraving * 4), spine.position + Vector2(9, 15 + engraving * 4), Color("bda673"), 0.7)
			draw_rect(Rect2(1072, baseline, 144, 6), gold.darkened(0.25))
	if upgrades.has("plants"):
		var base := Vector2(980, 609)
		draw_set_transform(base + Vector2(0, 12), 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, 44.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO)
		for index in range(7):
			var tip := base + Vector2((index - 3) * 13, -54 - (index % 3) * 17)
			draw_line(base, tip, Color("69815c"), 3, true)
			var direction := (tip - base).normalized()
			var side := direction.orthogonal()
			var leaf := PackedVector2Array()
			for vertex in range(16):
				var angle := TAU * float(vertex) / 16.0
				leaf.append(tip + direction * cos(angle) * 20.0 + side * sin(angle) * 8.0)
			draw_colored_polygon(leaf, Color("718a5e") if index % 2 == 0 else Color("4d674a"))
			draw_line(tip - direction * 16.0, tip + direction * 16.0, Color("9aab77"), 1.0, true)
			if index % 3 == 0:
				draw_circle(tip + Vector2(0, -8), 5.0, Color("d2aa83"))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-29, -7), base + Vector2(29, -7), base + Vector2(22, 26), base + Vector2(-22, 26)]), Color("855338"))
		draw_colored_polygon(PackedVector2Array([base + Vector2(12, -7), base + Vector2(29, -7), base + Vector2(22, 26), base + Vector2(12, 26)]), Color("63402c"))
		draw_rect(Rect2(base + Vector2(-32, -12), Vector2(64, 10)), Color("b07b50"))
		draw_line(base + Vector2(-18, 4), base + Vector2(18, 4), Color("d6b37a"), 2.0)
