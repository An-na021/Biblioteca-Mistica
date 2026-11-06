extends Control
## Purely visual receipt: real balances and stock are changed by main_game.gd.

const Art = preload("res://scripts/hud_art.gd")
var world_root: Node2D
var money_target: Control
var effects: Control

class Coin extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(Vector2(2, 3), 9, Color(0.15, 0.07, 0.02, 0.30), true, -1, true)
		draw_circle(Vector2.ZERO, 9, Color("8b5d21"), true, -1, true)
		draw_circle(Vector2(-0.6, -0.8), 7, Color("e8c36d"), true, -1, true)
		draw_arc(Vector2.ZERO, 5, 0, TAU, 22, Color("a7772d"), 1.0, true)
		draw_line(Vector2(-2, -3), Vector2(2, 3), Color("866027"), 1.5, true)

func setup(scene: Node2D, target: Control) -> void:
	world_root = scene
	money_target = target
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects = Control.new()
	effects.name = "SaleEffects"
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effects)

func _world_point(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * (world_root.get_global_transform_with_canvas() * point)

func play_sale(book: Dictionary, received: int, customer_point: Vector2) -> void:
	var destination := _world_point(customer_point)
	var cover := TextureRect.new()
	cover.name = "SoldBook"
	cover.texture = book.get("cover_texture") as Texture2D
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cover.size = Vector2(59, 82)
	cover.pivot_offset = cover.size * 0.5
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.position = _world_point(Vector2(557, 576)) - cover.size * 0.5
	cover.rotation = -0.18
	effects.add_child(cover)
	var flight := cover.create_tween().set_parallel(true)
	flight.tween_property(cover, "position", destination - cover.size * 0.5, 0.63).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	flight.tween_property(cover, "rotation", 0.10, 0.63)
	flight.tween_property(cover, "scale", Vector2.ONE * 0.63, 0.63)
	flight.chain().tween_property(cover, "modulate:a", 0.0, 0.20)
	flight.tween_callback(cover.queue_free)
	var end := get_global_transform_with_canvas().affine_inverse() * (money_target.get_global_transform_with_canvas() * (money_target.size * 0.5))
	for index in range(clampi(received, 1, 6)):
		var coin := Coin.new()
		coin.name = "PaymentCoin"
		coin.position = destination + Vector2(70 + index * 5, 45)
		coin.modulate.a = 0.0
		effects.add_child(coin)
		var start := coin.position
		var bend := Vector2(end.x - 100 + index * 9, start.y - 160)
		var travel := coin.create_tween()
		travel.tween_interval(0.28 + index * 0.075)
		travel.tween_property(coin, "modulate:a", 1.0, 0.06)
		travel.tween_method(func(weight: float) -> void:
			coin.position = start.bezier_interpolate(bend, bend, end, weight)
			coin.scale = Vector2.ONE * lerpf(1.0, 0.55, weight)
		, 0.0, 1.0, 0.78).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		travel.tween_property(coin, "modulate:a", 0.0, 0.10)
		travel.tween_callback(coin.queue_free)
	var receipt := Label.new()
	receipt.name = "SaleAmount"
	receipt.text = "+%d moedas" % received
	receipt.add_theme_font_override("font", Art.handwriting(false))
	receipt.add_theme_font_size_override("font_size", 19)
	receipt.add_theme_color_override("font_color", Color("f4d490"))
	receipt.add_theme_color_override("font_shadow_color", Color("352117"))
	receipt.add_theme_constant_override("shadow_offset_x", 1)
	receipt.add_theme_constant_override("shadow_offset_y", 2)
	receipt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	receipt.position = _world_point(Vector2(762, 503))
	effects.add_child(receipt)
	var receipt_motion := receipt.create_tween().set_parallel(true)
	receipt_motion.tween_property(receipt, "position:y", receipt.position.y - 30, 1.35)
	receipt_motion.tween_property(receipt, "modulate:a", 0.0, 0.45).set_delay(0.9)
	receipt_motion.chain().tween_callback(receipt.queue_free)

func reset_day() -> void:
	for child in effects.get_children():
		effects.remove_child(child)
		child.queue_free()
