class_name NotificationPanel
extends Control

const Art = preload("res://scripts/hud_art.gd")
const TEXT_PRIMARY := Color("3d2b1b")
const DISPLAY_SECONDS := 3.8
const FADE_IN_SECONDS := 0.18
const FADE_OUT_SECONDS := 0.35

class Toast extends PanelContainer:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var edge := PackedVector2Array([
			Vector2(4, 2), Vector2(size.x * 0.22, 1), Vector2(size.x * 0.46, 3), Vector2(size.x * 0.72, 1),
			Vector2(size.x - 5, 2), Vector2(size.x - 1, 8), Vector2(size.x - 2, size.y * 0.5), Vector2(size.x, size.y - 7),
			Vector2(size.x - 7, size.y - 1), Vector2(size.x * 0.65, size.y - 3), Vector2(size.x * 0.3, size.y - 1),
			Vector2(3, size.y - 2), Vector2(1, size.y - 8), Vector2(2, size.y * 0.4)
		])
		var shadow := edge.duplicate()
		for index in range(shadow.size()):
			shadow[index] += Vector2(2, 4)
		draw_colored_polygon(shadow, Color(0.07, 0.04, 0.015, 0.5))
		var uvs := PackedVector2Array()
		for point in edge:
			uvs.append(Vector2(0.2, 0.25) + point / size * Vector2(0.58, 0.43))
		draw_polygon(edge, PackedColorArray([Color(0.86, 0.81, 0.7)]), uvs, Art.DIALOGUE)
		edge.append(edge[0])
		draw_polyline(edge, Color("85623b"), 1.1, true)
		draw_line(Vector2(52, 7), Vector2(size.x - 15, 7), Color(0.55, 0.4, 0.23, 0.3), 0.7, true)
		var fold := PackedVector2Array([Vector2(size.x - 13, size.y - 3), Vector2(size.x - 3, size.y - 13), Vector2(size.x - 3, size.y - 4)])
		draw_colored_polygon(fold, Color(0.55, 0.38, 0.19, 0.22))

class Seal extends Control:
	var tone := "info"
	var accent := Color("7b6548")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var wax := PackedVector2Array()
		for index in range(36):
			var a := index * TAU / 36.0
			wax.append(center + Vector2(cos(a), sin(a)) * (16 + sin(index * 2.1) * 0.9))
		var shadow := wax.duplicate()
		for index in range(shadow.size()):
			shadow[index] += Vector2(1, 2)
		draw_colored_polygon(shadow, Color(0.16, 0.1, 0.04, 0.3))
		draw_colored_polygon(wax, accent)
		draw_arc(center, 12, 0, TAU, 40, accent.darkened(0.28), 1.3, true)
		draw_arc(center + Vector2(-0.5, -0.5), 14, PI, TAU, 24, accent.lightened(0.22), 1, true)
		var ink := Color("eddbb4")
		match tone:
			"success":
				draw_polyline(PackedVector2Array([center + Vector2(-7, 0), center + Vector2(-2, 5), center + Vector2(7, -6)]), ink, 2, true)
			"warning", "danger":
				draw_line(center + Vector2(0, -7), center + Vector2(0, 2), ink, 2, true)
				draw_circle(center + Vector2(0, 6), 1.3, ink, true, -1, true)
			"reputation":
				var star := PackedVector2Array()
				for index in range(10):
					var a := -PI * 0.5 + index * TAU / 10.0
					star.append(center + Vector2(cos(a), sin(a)) * (8.0 if index % 2 == 0 else 3.8))
				draw_colored_polygon(star, ink)
			_:
				var book := PackedVector2Array([Vector2(-8, -5), Vector2(-3, -7), Vector2(0, -4), Vector2(3, -7), Vector2(8, -5), Vector2(8, 6), Vector2(3, 4), Vector2(0, 7), Vector2(-3, 4), Vector2(-8, 6), Vector2(-8, -5)])
				for index in range(book.size()):
					book[index] += center
				draw_polyline(book, ink, 1.1, true)
				draw_line(center + Vector2(0, -4), center + Vector2(0, 6), ink, 1, true)

var notification_stack: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_stack = VBoxContainer.new()
	notification_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notification_stack.offset_left = -400.0
	# Leave room for the status panel and the customer timer above the toasts.
	notification_stack.offset_top = 340.0
	notification_stack.offset_right = -20.0
	notification_stack.offset_bottom = 690.0
	notification_stack.add_theme_constant_override("separation", 8)
	notification_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notification_stack)


func show_notification(title: String, message: String, tone: String = "info") -> void:
	if notification_stack == null:
		return
	var toast := Toast.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.custom_minimum_size = Vector2(0, 72)
	toast.add_theme_stylebox_override("panel", _content_margins())
	notification_stack.add_child(toast)
	while notification_stack.get_child_count() > 4:
		var oldest := notification_stack.get_child(0)
		notification_stack.remove_child(oldest)
		oldest.queue_free()

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(content)
	var marker := Seal.new()
	marker.tone = tone
	marker.accent = _tone_accent(tone)
	marker.custom_minimum_size = Vector2(36, 40)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(marker)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 2)
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text_stack)
	var title_label := Label.new()
	title_label.text = title.to_upper()
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_override("font", Art.handwriting(false))
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", _tone_accent(tone).darkened(0.25))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(title_label)
	var message_label := Label.new()
	message_label.text = message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_override("font", Art.handwriting(false))
	message_label.add_theme_font_size_override("font_size", 13)
	message_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(message_label)

	toast.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := toast.create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, FADE_IN_SECONDS)
	tween.tween_interval(DISPLAY_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, FADE_OUT_SECONDS)
	tween.tween_callback(toast.queue_free)


func _tone_accent(tone: String) -> Color:
	match tone:
		"success": return Color("687949")
		"warning": return Color("a17a3e")
		"danger": return Color("9b5340")
		"reputation": return Color("627785")
		_: return Color("897451")


func _content_margins() -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	style.set_content_margin(SIDE_LEFT, 11.0)
	style.set_content_margin(SIDE_TOP, 10.0)
	style.set_content_margin(SIDE_RIGHT, 12.0)
	style.set_content_margin(SIDE_BOTTOM, 11.0)
	return style
