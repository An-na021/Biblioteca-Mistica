extends Node2D

const World = preload("res://scripts/shop_world.gd")
const PLANT_TEXTURE: Texture2D = preload("res://IMG/planta_balcao.png")
const SHELF_SCENE: PackedScene = preload("res://scenes/decor/curation_shelf.tscn")
const PLANT_SIZE := Vector2(108, 108)
const PLANT_BASE := Vector2(1009, 611)
const PLANT_TINT := Color(0.72, 0.65, 0.47)
const BREEZE: Shader = preload("res://shaders/plant_breeze.gdshader")
const WITHOUT_LAMP: Texture2D = preload("res://IMG/counter_without_lamp.png")
const LAMP_CLEANUP: Shader = preload("res://shaders/lamp_cleanup.gdshader")

var upgrades: Dictionary = {}
var shelf: Node2D
var counter_foreground: Polygon2D
var plant_hotspot: Interactable
var plant_visual: Sprite2D
var plant_material: ShaderMaterial
var motion_time := 0.0
var lamp_cleanup: Array[Polygon2D] = []
var lamp_hotspot: Interactable

func _ready() -> void:
	_add_lamp_cleanup()
	shelf = SHELF_SCENE.instantiate()
	add_child(shelf)
	shelf.get_node("ShelfHotspot").description = World.upgrade_description("shelves")
	shelf.visible = upgrades.has("shelves")
	_add_counter_occlusion()
	_add_plant_visual()
	_add_plant_hotspot()
	set_process(upgrades.has("plants"))

func _add_lamp_cleanup() -> void:
	var room := get_parent()
	var background := room.get_node_or_null("BackgroundImage") as Sprite2D
	if background == null:
		return
	lamp_hotspot = room.get_node("Lamp") as Interactable
	lamp_hotspot.description = World.upgrade_description("lighting")
	# The lamp is painted into both the room and the foreground counter.
	# Keep each cleanup plate in the same depth layer as its original pixels.
	var regions := [Rect2(40, 440, 375, 274), Rect2(40, 714, 375, 171)]
	var anchors := [room.get_node("CustomerSpawn"), room.get_node("CounterNewspaper")]
	for index in range(regions.size()):
		var region: Rect2 = regions[index]
		var patch := Polygon2D.new()
		patch.name = "LampBackgroundCleanup" if index == 0 else "LampCounterCleanup"
		patch.texture = WITHOUT_LAMP
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var material := ShaderMaterial.new()
		material.shader = LAMP_CLEANUP
		material.set_shader_parameter("source_size", background.texture.get_size())
		patch.material = material
		patch.transform = background.transform
		patch.polygon = PackedVector2Array([region.position, region.position + Vector2(region.size.x, 0), region.end, region.position + Vector2(0, region.size.y)])
		var source_uv := PackedVector2Array()
		for point in patch.polygon:
			source_uv.append(point * WITHOUT_LAMP.get_size() / background.texture.get_size())
		patch.uv = source_uv
		patch.visible = not upgrades.has("lighting")
		room.add_child(patch)
		room.move_child(patch, anchors[index].get_index())
		lamp_cleanup.append(patch)
	_update_lamp()

func _update_lamp() -> void:
	var installed := upgrades.has("lighting")
	for patch in lamp_cleanup:
		patch.visible = not installed
	if is_instance_valid(lamp_hotspot):
		lamp_hotspot.visible = installed
		lamp_hotspot.input_pickable = installed
		if not installed:
			lamp_hotspot.set_selected(false)

func _add_plant_visual() -> void:
	plant_visual = Sprite2D.new()
	plant_visual.name = "CounterPlant"
	plant_visual.texture = PLANT_TEXTURE
	plant_visual.centered = false
	plant_visual.position = PLANT_BASE - Vector2(PLANT_SIZE.x * 0.5, PLANT_SIZE.y)
	plant_visual.scale = PLANT_SIZE / PLANT_TEXTURE.get_size()
	plant_visual.modulate = PLANT_TINT
	plant_material = ShaderMaterial.new()
	plant_material.shader = BREEZE
	plant_visual.material = plant_material
	plant_visual.visible = upgrades.has("plants")
	add_child(plant_visual)

func _process(delta: float) -> void:
	motion_time += delta
	plant_material.set_shader_parameter("motion_time", motion_time)

func _add_plant_hotspot() -> void:
	plant_hotspot = Interactable.new()
	plant_hotspot.name = "PlantHotspot"
	plant_hotspot.position = PLANT_BASE - Vector2(0, PLANT_SIZE.y * 0.5)
	plant_hotspot.interaction_name = "Vaso de flores"
	plant_hotspot.description = World.upgrade_description("plants")
	plant_hotspot.interaction_type = "counter_plant"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = PLANT_SIZE
	collision.shape = shape
	plant_hotspot.add_child(collision)
	add_child(plant_hotspot)
	plant_hotspot.visible = upgrades.has("plants")
	plant_hotspot.input_pickable = plant_hotspot.visible

func _add_counter_occlusion() -> void:
	# The side table stands behind the counter: its lower edge must be hidden
	# by the original foreground, rather than pasted over the counter's surface.
	var background := get_parent().get_node_or_null("BackgroundImage") as Sprite2D
	if background == null:
		return
	counter_foreground = Polygon2D.new()
	var foreground := counter_foreground
	foreground.name = "CounterForeground"
	foreground.texture = background.texture
	foreground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	foreground.transform = background.transform
	foreground.z_index = -1
	foreground.visible = upgrades.has("shelves")
	var source_points := PackedVector2Array()
	var to_source := background.transform.affine_inverse()
	for point in [Vector2(1024, 551), Vector2(1280, 551), Vector2(1280, 720), Vector2(1024, 720)]:
		source_points.append(to_source * point)
	foreground.polygon = source_points
	foreground.uv = source_points
	add_child(foreground)

func update_state(value: Dictionary) -> void:
	upgrades = value.duplicate()
	_update_lamp()
	if is_instance_valid(shelf):
		shelf.visible = upgrades.has("shelves")
	if is_instance_valid(counter_foreground):
		counter_foreground.visible = upgrades.has("shelves")
	if is_instance_valid(plant_hotspot):
		plant_hotspot.visible = upgrades.has("plants")
		plant_hotspot.input_pickable = plant_hotspot.visible
		if not plant_hotspot.visible:
			plant_hotspot.set_selected(false)
	if is_instance_valid(plant_visual):
		plant_visual.visible = upgrades.has("plants")
	set_process(upgrades.has("plants"))
	queue_redraw()

func _draw() -> void:
	if upgrades.has("plants"):
		draw_set_transform(PLANT_BASE + Vector2(10, 2), 0.12, Vector2(1.0, 0.22))
		for ring in range(5, 0, -1):
			draw_circle(Vector2.ZERO, 12.0 + ring * 2.6, Color(0.06, 0.035, 0.012, 0.055))
		draw_set_transform(Vector2.ZERO)
