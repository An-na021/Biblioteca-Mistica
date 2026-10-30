extends Node2D

const PLANT_TEXTURE: Texture2D = preload("res://IMG/planta_balcao.png")
const SHELF_SCENE: PackedScene = preload("res://scenes/decor/curation_shelf.tscn")
const PLANT_SIZE := Vector2(152, 152)
const PLANT_BASE := Vector2(980, 635)

var upgrades: Dictionary = {}
var shelf: Node2D

func _ready() -> void:
	shelf = SHELF_SCENE.instantiate()
	add_child(shelf)
	shelf.visible = upgrades.has("shelves")

func update_state(value: Dictionary) -> void:
	upgrades = value.duplicate()
	if is_instance_valid(shelf):
		shelf.visible = upgrades.has("shelves")
	queue_redraw()

func _draw() -> void:
	if upgrades.has("lighting"):
		var light := Vector2(160, 392)
		for ring in range(16, 0, -1):
			draw_circle(light, float(ring) * 9.0, Color(1.0, 0.69, 0.23, 0.008))
		for index in range(5):
			var spot := light + Vector2(43 + index * 8, -46 + (index % 3) * 23)
			draw_circle(spot, 1.6, Color(1.0, 0.85, 0.48, 0.7))
	if upgrades.has("plants"):
		draw_set_transform(PLANT_BASE, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO)
		var top_left := PLANT_BASE - Vector2(PLANT_SIZE.x * 0.5, PLANT_SIZE.y)
		draw_texture_rect(PLANT_TEXTURE, Rect2(top_left, PLANT_SIZE), false)
