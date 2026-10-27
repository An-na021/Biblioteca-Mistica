extends Node2D

const PLANT_TEXTURE: Texture2D = preload("res://IMG/planta_balcao.png")
const PLANT_SIZE := Vector2(152, 152)
const PLANT_BASE := Vector2(980, 635)

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
		draw_set_transform(PLANT_BASE, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO)
		var top_left := PLANT_BASE - Vector2(PLANT_SIZE.x * 0.5, PLANT_SIZE.y)
		draw_texture_rect(PLANT_TEXTURE, Rect2(top_left, PLANT_SIZE), false)
