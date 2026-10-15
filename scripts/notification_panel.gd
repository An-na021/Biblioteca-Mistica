class_name NotificationPanel
extends Control

const TEXT_PRIMARY := Color("f3ead6")
const TEXT_MUTED := Color("cbbfa7")

var notification_stack: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_stack = VBoxContainer.new()
	notification_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	notification_stack.offset_left = -380.0
	notification_stack.offset_top = 155.0
	notification_stack.offset_right = -20.0
	notification_stack.offset_bottom = 690.0
	notification_stack.add_theme_constant_override("separation", 7)
	notification_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notification_stack)


func show_notification(title: String, message: String, tone: String = "info") -> void:
	if notification_stack == null:
		return
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.custom_minimum_size = Vector2(0, 58)
	toast.add_theme_stylebox_override("panel", _make_style(_tone_color(tone), Color("8e7445")))
	notification_stack.add_child(toast)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(content)
	var marker := ColorRect.new()
	marker.color = _tone_accent(tone)
	marker.custom_minimum_size.x = 5
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(marker)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 2)
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(text_stack)
	var title_label := Label.new()
	title_label.text = title.to_upper()
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", _tone_accent(tone))
	text_stack.add_child(title_label)
	var message_label := Label.new()
	message_label.text = message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 11)
	message_label.add_theme_color_override("font_color", TEXT_PRIMARY)
	text_stack.add_child(message_label)

	toast.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	tween.tween_interval(2.8)
	tween.tween_property(toast, "modulate:a", 0.0, 0.35)
	tween.tween_callback(toast.queue_free)


func _tone_color(tone: String) -> Color:
	match tone:
		"success": return Color("263728")
		"warning": return Color("3c3020")
		"danger": return Color("402827")
		"reputation": return Color("2f3543")
		_: return Color("252b27")


func _tone_accent(tone: String) -> Color:
	match tone:
		"success": return Color("a9d07e")
		"warning": return Color("e4c477")
		"danger": return Color("e59a86")
		"reputation": return Color("a9c6ee")
		_: return TEXT_MUTED


func _make_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin(SIDE_LEFT, 10.0)
	style.set_content_margin(SIDE_TOP, 8.0)
	style.set_content_margin(SIDE_RIGHT, 10.0)
	style.set_content_margin(SIDE_BOTTOM, 8.0)
	return style
