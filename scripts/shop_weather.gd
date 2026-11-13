extends Node2D
## Rain stays on the painted glass; cloud shade affects the room, never the UI.
const Audio = preload("res://scripts/game_audio.gd")
const CYCLE := ["clear", "cloudy", "rain", "cloudy", "clear", "rain"]
const NAMES := {"clear": "Céu aberto", "cloudy": "Nuvens passageiras", "rain": "Chuva na cidade"}
const PANES := [Rect2(159, 106, 22, 73), Rect2(188, 108, 22, 71), Rect2(159, 188, 22, 93), Rect2(188, 188, 22, 93), Rect2(299, 112, 15, 61), Rect2(321, 114, 13, 59), Rect2(299, 182, 15, 73), Rect2(321, 182, 13, 73)]
var kind := "clear"
var elapsed := 0.0
var active := false
var audio: Node
var _next_bird := 8.0

func _ready() -> void:
	audio = Audio.new()
	audio.name = "OutdoorAudio"
	audio.base_db = -31
	add_child(audio)

func configure_day(day: int) -> void:
	kind = str(CYCLE[(maxi(1, day) - 1) % CYCLE.size()])
	elapsed = 0
	_next_bird = 8
	if is_instance_valid(audio):
		audio.silence()
	queue_redraw()

func room_tint() -> Color:
	if kind == "clear":
		return Color.WHITE
	var cloud := 0.5 + 0.5 * sin(elapsed * 0.095 + 0.7 * sin(elapsed * 0.037))
	var depth := 0.06 + cloud * 0.09 if kind == "cloudy" else 0.15 + cloud * 0.05
	return Color(1 - depth, 1 - depth * 0.86, 1 - depth * 0.57)

func _process(delta: float) -> void:
	audio.audible = active
	if not active:
		return
	elapsed += delta
	var ambience := "rain" if kind == "rain" else "wind" if kind == "cloudy" else "street"
	audio.engage(ambience, 0.45)
	if kind != "rain" and elapsed >= _next_bird:
		audio.one_shot("bird")
		_next_bird = elapsed + 13 + fmod(elapsed * 1.73, 9)
	queue_redraw()

func _draw() -> void:
	if kind == "rain":
		for pane: Rect2 in PANES:
			draw_rect(pane, Color(0.40, 0.48, 0.49, 0.075))
			for index in range(12):
				var x := pane.position.x + 2 + fposmod(index * 7.137, pane.size.x - 4)
				var y := pane.position.y + fposmod(index * 19.17 + elapsed * (38 + index * 2), pane.size.y)
				var end := Vector2(maxf(pane.position.x + 1, x - 1.6), minf(pane.end.y, y + 7 + index % 5))
				draw_line(Vector2(x, y), end, Color(0.79, 0.80, 0.70, 0.26 + (index % 3) * 0.065), 0.8, true)
				if index % 4 == 0:
					draw_circle(Vector2(x, y), 0.8, Color(0.83, 0.84, 0.74, 0.22), true, -1, true)
	if kind != "clear":
		# A soft-edged diagonal shadow drifts over the floor in the window light.
		var travel := sin(elapsed * 0.07) * 75
		for layer in range(6):
			draw_colored_polygon(cloud_outline(layer, travel), Color(0.08, 0.085, 0.085, 0.008))

static func cloud_outline(layer: int, travel: float) -> PackedVector2Array:
	var shift := float(clampi(layer, 0, 5)) * 3
	return PackedVector2Array([Vector2(180 + shift, 300), Vector2(234 - shift, 307), Vector2(620 + travel - shift, 550), Vector2(413 + travel + shift, 550)])
