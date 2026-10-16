class_name MoodTimer
extends Control

const TIMER_SIZE := Vector2(176.0, 176.0)
const GOLD := Color("d8b276")
const DARK_GOLD := Color("755334")

var mood_color := Color("e0a64f")
var time_left := 0.0
var duration := 1.0

func _ready() -> void:
	custom_minimum_size = TIMER_SIZE
	size = TIMER_SIZE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -282.0
	offset_top = 2.0
	offset_right = -106.0
	offset_bottom = 178.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func setup(mood_type: String, time_limit: float) -> void:
	duration = maxf(time_limit, 0.01)
	time_left = duration
	match mood_type:
		"apressado": mood_color = Color("e4a34d")
		"indeciso": mood_color = Color("bba2d4")
		"colecionador": mood_color = Color("a8bd7d")
		"negociador": mood_color = Color("88b6bd")
		"dificil": mood_color = Color("d58c78")
		_: mood_color = Color("d8b276")
	visible = true
	queue_redraw()

func set_time_left(value: float) -> void:
	time_left = clampf(value, 0.0, duration)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var ratio := clampf(time_left / duration, 0.0, 1.0)
	var urgency := Color("df6258") if ratio <= 0.25 else mood_color

	# Layered medallion with a faceted bronze rim.
	draw_circle(center + Vector2(0.0, 5.0), 83.0, Color(0.0, 0.0, 0.0, 0.48))
	var rim := PackedVector2Array()
	for i in range(32):
		var angle := TAU * float(i) / 32.0 - PI * 0.5
		var radius := 82.0 if i % 2 == 0 else 77.0
		rim.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(rim, Color("493226"))
	var rim_outline := rim.duplicate()
	rim_outline.append(rim[0])
	draw_polyline(rim_outline, DARK_GOLD, 2.0, true)
	draw_arc(center, 73.0, 0.0, TAU, 96, GOLD, 1.5, true)
	draw_arc(center, 68.0, 0.0, TAU, 96, Color("33251e"), 2.0, true)
	draw_circle(center, 64.0, Color("211a18"))
	draw_circle(center, 59.0, Color("2b201b"))
	draw_arc(center, 58.0, 0.0, TAU, 96, Color("765535"), 1.2, true)

	# Fine engraved ticks keep the remaining time legible at a glance.
	for tick in range(24):
		var angle := TAU * float(tick) / 24.0 - PI * 0.5
		var inner := center + Vector2(cos(angle), sin(angle)) * 61.0
		var outer := center + Vector2(cos(angle), sin(angle)) * (65.0 if tick % 3 == 0 else 63.0)
		draw_line(inner, outer, Color(GOLD.r, GOLD.g, GOLD.b, 0.78 if tick % 3 == 0 else 0.38), 1.2, true)

	# The shrinking arc is the primary timer cue; a soft halo adds a little magic.
	draw_arc(center, 54.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 96, Color(urgency.r, urgency.g, urgency.b, 0.24), 13.0, true)
	draw_arc(center, 54.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 96, urgency, 6.0, true)

	# Small ruby and gold prongs finish the fantasy clock face.
	var gem_y := center.y - 76.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(center.x, gem_y - 11.0), Vector2(center.x + 9.0, gem_y - 2.0),
		Vector2(center.x, gem_y + 10.0), Vector2(center.x - 9.0, gem_y - 2.0)
	]), Color("d9aa68"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(center.x, gem_y - 7.0), Vector2(center.x + 5.5, gem_y - 2.0),
		Vector2(center.x, gem_y + 6.0), Vector2(center.x - 5.5, gem_y - 2.0)
	]), Color("9f343d"))
	for angle in [-PI * 0.5, 0.0, PI * 0.5, PI]:
		var stud := center + Vector2(cos(angle), sin(angle)) * 72.0
		draw_circle(stud, 2.0, GOLD)

	var seconds := ceili(time_left)
	var time_text := "%02d:%02d" % [seconds / 60, seconds % 60]
	var font := get_theme_default_font()
	if font == null:
		return
	var text_size := font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 27)
	draw_string(font, Vector2(center.x - text_size.x * 0.5, center.y + 8.0), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("f4e3bd"))
