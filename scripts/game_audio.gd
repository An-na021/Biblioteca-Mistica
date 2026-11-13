extends Node
## Small original Foley textures, synthesized once and cached; no network/assets.
static var _streams: Dictionary = {}
const RATE := 22050
var friction: AudioStreamPlayer
var accent: AudioStreamPlayer
var current := ""
var remaining := 0.0
var strength := 0.5
var allow_while_paused := false
var focused := true
var audible := true
var base_db := -24.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	friction = AudioStreamPlayer.new()
	friction.name = "Friction"
	friction.volume_db = -60
	add_child(friction)
	accent = AudioStreamPlayer.new()
	accent.name = "Accent"
	accent.volume_db = base_db
	add_child(accent)

func engage(kind: String, intensity := 0.5) -> void:
	if not focused or not audible:
		return
	if current != kind:
		current = kind
		friction.stream = stream(kind, true)
		friction.play()
	elif not friction.playing:
		friction.play()
	remaining = 0.14
	strength = clampf(intensity, 0.1, 1.0)
	friction.pitch_scale = 0.93 + strength * 0.12

func one_shot(kind: String) -> void:
	if not focused or not audible:
		return
	accent.stream = stream(kind)
	accent.volume_db = base_db - 2
	accent.play()

func silence() -> void:
	remaining = 0
	if is_instance_valid(friction):
		friction.stop()
	if is_instance_valid(accent):
		accent.stop()

func _exit_tree() -> void:
	silence()
	if is_instance_valid(friction):
		friction.stream = null
	if is_instance_valid(accent):
		accent.stream = null

func _process(delta: float) -> void:
	var enabled := focused and audible and (allow_while_paused or not get_tree().paused)
	remaining = maxf(0, remaining - delta)
	var target := base_db - 8 + strength * 8 if enabled and remaining > 0 else -60.0
	friction.volume_db = move_toward(friction.volume_db, target, delta * 240)
	if target <= -60 and friction.volume_db <= -59:
		friction.stop()
	if not enabled:
		accent.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		silence()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true

static func stream(kind: String, loop := false) -> AudioStreamWAV:
	var key := kind + ("_loop" if loop else "_once")
	if _streams.has(key):
		return _streams[key]
	var duration := 2.4 if loop else (0.85 if kind == "dip" else 0.26)
	if kind in ["rain", "wind", "street"]:
		duration = 4.0
	elif kind == "bird":
		duration = 0.8
	var count := roundi(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var low := 0.0
	var soft := 0.0
	for index in range(count):
		var t := float(index) / RATE
		var noise := rng.randf_range(-1, 1)
		low = lerpf(low, noise, 0.07)
		soft = lerpf(soft, noise, 0.4)
		var sample := 0.0
		match kind:
			"brush": sample = (soft - low) * (0.6 + 0.15 * sin(t * 37))
			"glue": sample = (low * 2 + soft * 0.15) * (0.6 + 0.25 * sin(t * 71))
			"roller": sample = low * (1.8 + 0.4 * sin(t * 29)) + sin(t * TAU * 106) * 0.025
			"press": sample = low * 1.5 + sin(t * TAU * (176 + 6 * sin(t * 11))) * 0.08 * pow(0.5 + 0.5 * sin(t * 23), 5)
			"thread": sample = (soft - low) * (0.25 + 0.2 * sin(t * 97))
			"paper": sample = soft * (0.5 + 0.35 * sin(t * 63))
			"dip": sample = low * 1.7 + sin(t * TAU * (270 - t * 170)) * 0.11 * pow(0.5 + 0.5 * sin(t * 28), 6)
			"needle": sample = (soft * 0.45 + sin(t * TAU * 930) * 0.035) * exp(-t * 18)
			"rain": sample = soft * 0.35 + low * 0.7 + (noise * 0.6 if noise > 0.995 else 0.0)
			"wind": sample = low * 2.1 * (0.6 + 0.3 * sin(t * TAU * 0.5))
			"street": sample = low * (0.8 + 0.25 * sin(t * TAU * 0.75))
			"bird": sample = sin(t * TAU * (2350 + 240 * sin(t * 29))) * 0.15 * pow(maxf(0, sin(t * 17)), 4)
		var edge := minf(1.0, minf(t / 0.025, (duration - t) / 0.05))
		if not loop:
			edge *= pow(maxf(0, 1 - t / duration), 0.6)
		bytes.encode_s16(index * 2, roundi(clampf(sample * edge, -0.85, 0.85) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = count
	_streams[key] = wav
	return wav
