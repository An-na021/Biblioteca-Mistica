extends Node2D
## The dial uses a slightly oval perspective. All hands share the same spindle.

const DIAL_PERSPECTIVE := Vector2(1.0, 1.04)
const INK := Color("100e09")
var hand_angles := Vector3.ZERO

func _ready() -> void:
	_sync_time()

func _process(_delta: float) -> void:
	_sync_time()

static func angles_for_time(hour: int, minute: int, second: float) -> Vector3:
	return Vector3(
		TAU * (float(hour % 12) + float(minute) / 60.0 + second / 3600.0) / 12.0,
		TAU * (float(minute) + second / 60.0) / 60.0,
		TAU * second / 60.0
	)

func _sync_time() -> void:
	# Read wall time every frame so clock changes and resume never accumulate drift.
	var unix_time := Time.get_unix_time_from_system()
	var local := Time.get_time_dict_from_system()
	var seconds := float(local.second) + fposmod(unix_time, 1.0)
	hand_angles = angles_for_time(int(local.hour), int(local.minute), seconds)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, DIAL_PERSPECTIVE)
	_draw_hand(hand_angles.x, 132.0, 7.0)
	_draw_hand(hand_angles.y, 169.0, 4.5)
	# A fine seconds needle and its counterweight move continuously.
	var direction := Vector2(sin(hand_angles.z), -cos(hand_angles.z))
	draw_line(-direction * 32.0 + Vector2(2, 3), direction * 187.0 + Vector2(2, 3), Color(0, 0, 0, 0.22), 2.0, true)
	draw_line(-direction * 32.0, direction * 187.0, INK, 1.5, true)
	draw_circle(-direction * 26.0, 4.0, Color("5a4025"), true, -1.0, true)
	draw_circle(Vector2(2, 3), 12.0, Color(0, 0, 0, 0.3), true, -1.0, true)
	draw_circle(Vector2.ZERO, 11.0, INK, true, -1.0, true)
	draw_arc(Vector2.ZERO, 7.5, 0.3, 4.7, 32, Color("79603b"), 1.5, true)
	draw_circle(Vector2.ZERO, 3.0, Color("a4834c"), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)

func _draw_hand(angle: float, length: float, width: float) -> void:
	var outline := PackedVector2Array([
		Vector2(-width * 0.65, 17), Vector2(-width, -length * 0.24),
		Vector2(-width * 0.45, -length * 0.82), Vector2(-width * 1.4, -length * 0.8),
		Vector2(0, -length), Vector2(width * 1.4, -length * 0.8),
		Vector2(width * 0.45, -length * 0.82), Vector2(width, -length * 0.24),
		Vector2(width * 0.65, 17)
	])
	var shadow := PackedVector2Array()
	for index in range(outline.size()):
		outline[index] = outline[index].rotated(angle)
		shadow.append(outline[index] + Vector2(3, 4))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.25))
	draw_colored_polygon(outline, INK)
	draw_line(Vector2(-1, -18).rotated(angle), Vector2(-1, -length * 0.77).rotated(angle), Color("816640"), 1.0, true)
