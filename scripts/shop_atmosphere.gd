extends Node2D
## Cosmetic time of day, independent of the computer clock and service rules.

const EMISSION: Shader = preload("res://shaders/lamp_emission.gdshader")

var day_progress := 0.0
var target_progress := 0.0
var animation_time := 0.0
var animations_active := false
var lighting_installed := false:
	set(value):
		lighting_installed = value
		_update_lamps()
		queue_redraw()
var desk_lamp_emission: Polygon2D
var daylight: CanvasModulate
var motes: Array[Vector4] = []
var lamp_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	z_index = 3
	daylight = CanvasModulate.new()
	daylight.name = "Daylight"
	add_child(daylight)
	_add_lamp_emission()
	var random := RandomNumberGenerator.new()
	random.seed = 4318
	for index in range(38):
		motes.append(Vector4(random.randf_range(-1.0, 1.0), random.randf(), random.randf_range(0.008, 0.022), random.randf_range(0.5, 1.15)))
	_apply_daylight()
	_update_lamps()

func _add_lamp_emission() -> void:
	var background := get_parent().get_node_or_null("BackgroundImage") as Sprite2D
	if background == null:
		return
	# Restore only the softly masked luminous part of the existing artwork.
	# This keeps the fixture warm while CanvasModulate darkens the room.
	for region in [Rect2(70, 470, 330, 165), Rect2(565, 120, 105, 76)]:
		var patch := Polygon2D.new()
		patch.name = "LampEmission"
		if desk_lamp_emission == null:
			desk_lamp_emission = patch
		patch.texture = background.texture
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		patch.transform = background.transform
		patch.position = background.transform * region.position
		patch.polygon = PackedVector2Array([Vector2.ZERO, Vector2(region.size.x, 0), region.size, Vector2(0, region.size.y)])
		patch.uv = PackedVector2Array([region.position, region.position + Vector2(region.size.x, 0), region.end, region.position + Vector2(0, region.size.y)])
		var material := ShaderMaterial.new()
		material.shader = EMISSION
		material.set_shader_parameter("patch_size", region.size)
		patch.material = material
		lamp_materials.append(material)
		add_child(patch)

func _update_lamps() -> void:
	if is_instance_valid(desk_lamp_emission):
		desk_lamp_emission.visible = lighting_installed
	var evening := smoothstep(0.45, 1.0, day_progress)
	var pulse := 1.0 + sin(animation_time * 1.17) * 0.025 + sin(animation_time * 2.63) * 0.012
	var emission := (0.08 + evening * 0.82) * pulse * (1.0 if lighting_installed else 0.85)
	for material in lamp_materials:
		material.set_shader_parameter("emission", emission)

static func color_for_progress(value: float) -> Color:
	var progress := clampf(value, 0.0, 1.0)
	var opening := Color(1.03, 1.02, 0.98)
	var afternoon := Color(1.06, 0.93, 0.77)
	var evening := Color(0.64, 0.65, 0.75)
	if progress <= 0.55:
		return opening.lerp(afternoon, smoothstep(0.0, 0.55, progress))
	return afternoon.lerp(evening, smoothstep(0.55, 1.0, progress))

func set_day_progress(value: float, immediate := false) -> void:
	target_progress = clampf(value, 0.0, 1.0)
	if immediate:
		day_progress = target_progress
		_apply_daylight()
		_update_lamps()
		queue_redraw()

func reset_day() -> void:
	set_day_progress(0.0, true)

func _process(delta: float) -> void:
	if not animations_active:
		return
	animation_time += delta
	day_progress = move_toward(day_progress, target_progress, delta * 0.10)
	_apply_daylight()
	_update_lamps()
	queue_redraw()

func _apply_daylight() -> void:
	if daylight != null:
		daylight.color = color_for_progress(day_progress)

func _draw() -> void:
	var sun := 1.0 - smoothstep(0.55, 1.0, day_progress)
	var drift := day_progress * 36.0
	# Broad, faint shafts follow the direction of the painted window light.
	for index in range(7):
		var inset := float(index) * 4.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(174 + inset * 0.5, 143), Vector2(216 - inset * 0.5, 143),
			Vector2(555 - inset + drift, 548), Vector2(340 + inset + drift, 548)
		]), Color(1.0, 0.84, 0.50, 0.0035 * sun))
		draw_colored_polygon(PackedVector2Array([
			Vector2(305 + inset * 0.25, 147), Vector2(327 - inset * 0.25, 147),
			Vector2(574 - inset + drift, 493), Vector2(455 + inset + drift, 493)
		]), Color(1.0, 0.86, 0.57, 0.0025 * sun))
	for index in range(motes.size()):
		var mote := motes[index]
		var travel := fposmod(mote.y - animation_time * mote.z, 1.0)
		var origin := Vector2(196, 138) if index % 3 != 0 else Vector2(316, 147)
		var destination := Vector2(436 + drift, 548) if index % 3 != 0 else Vector2(519 + drift, 479)
		var point := origin.lerp(destination, travel)
		point.x += mote.x * lerpf(9, 88, travel) + sin(animation_time * 0.23 + index) * 3.0
		var opacity := sin(travel * PI) * 0.30 * sun
		draw_circle(point, mote.w, Color(1.0, 0.87, 0.61, opacity), true, -1, true)
	var evening := smoothstep(0.45, 1.0, day_progress)
	var pulse := 1.0 + sin(animation_time * 1.17) * 0.025 + sin(animation_time * 2.63) * 0.012
	var strength := (0.45 + evening * 0.70) * pulse
	if lighting_installed:
		strength *= 1.35
		_soft_light(Vector2(173, 426), Vector2(1.0, 0.55), 105, strength)
	_soft_light(Vector2(474, 130), Vector2(1.0, 0.65), 39, strength * 0.70)

func _soft_light(center: Vector2, stretch: Vector2, radius: float, strength: float) -> void:
	draw_set_transform(center, 0.0, stretch)
	for ring in range(18, 0, -1):
		var fraction := float(ring) / 18.0
		draw_circle(Vector2.ZERO, radius * fraction, Color(1.0, 0.63, 0.23, (1.0 - fraction) * 0.0035 * strength), true, -1, true)
	draw_set_transform(Vector2.ZERO)
