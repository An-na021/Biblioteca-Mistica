extends Node
## Small local facial deformations and posture; gameplay/hitboxes stay unchanged.
const FEATURES := {
	"lyria": [Vector2(0.500, 0.383), Vector2(0.420, 0.220), Vector2(0.580, 0.220)],
	"tom": [Vector2(0.518, 0.459), Vector2(0.440, 0.271), Vector2(0.590, 0.271)],
	"mestre_elian": [Vector2(0.536, 0.522), Vector2(0.482, 0.350), Vector2(0.596, 0.347)],
	"borin": [Vector2(0.543, 0.357), Vector2(0.479, 0.198), Vector2(0.604, 0.205)],
	"thalion_grimorio": [Vector2(0.446, 0.450), Vector2(0.382, 0.286), Vector2(0.507, 0.296)],
	"professor_bigodes": [Vector2(0.532, 0.379), Vector2(0.446, 0.229), Vector2(0.582, 0.232)],
	"lilith_vespera": [Vector2(0.489, 0.404), Vector2(0.457, 0.289), Vector2(0.539, 0.286)],
	"evelune": [Vector2(0.490, 0.463), Vector2(0.415, 0.327), Vector2(0.560, 0.317)]
}
var portrait: Sprite2D
var shadow: Sprite2D
var _origin := Vector2.ZERO
var _shadow_origin := Vector2.ZERO
var _scale := Vector2.ONE
var _material: ShaderMaterial
var emotion := "neutral"
var held := 0.0
var time := 0.0
var impatience := 0.0
var _smile := 0.0
var _doubt := 0.0

func reset_pose() -> void:
	set_process(false)
	if is_instance_valid(portrait):
		portrait.position = _origin
		portrait.scale = _scale
		portrait.rotation = 0
	if is_instance_valid(shadow):
		shadow.position = _shadow_origin
		shadow.rotation = 0

func setup(subject: Sprite2D, id: String, portrait_shadow: Sprite2D = null) -> void:
	portrait = subject
	shadow = portrait_shadow
	if portrait == null:
		return
	_origin = portrait.position
	_scale = portrait.scale
	if shadow != null:
		_shadow_origin = shadow.position
	if portrait.material is ShaderMaterial:
		portrait.material = portrait.material.duplicate()
		_material = portrait.material
		if FEATURES.has(id):
			var points: Array = FEATURES[id]
			_material.set_shader_parameter("mouth_center", points[0])
			_material.set_shader_parameter("left_brow", points[1])
			_material.set_shader_parameter("right_brow", points[2])
			_material.set_shader_parameter("facial_amount", 1.0)
		else:
			_material.set_shader_parameter("facial_amount", 0.0)

func react(accepted: bool, leaving := false) -> void:
	emotion = "satisfied" if accepted else "impatient" if leaving else "doubt"
	held = 1.8
	_smile = 1.0 if accepted else 0.0
	_doubt = 0.0 if accepted or leaving else 1.0
	_apply()

func set_patience(fraction: float, relaxed: bool) -> void:
	impatience = 0.0 if relaxed else 1.0 - smoothstep(0.05, 0.3, fraction)
	if held <= 0:
		emotion = "impatient" if impatience > 0.1 else "neutral"

func _process(delta: float) -> void:
	if not is_instance_valid(portrait) or not portrait.is_visible_in_tree():
		return
	time += delta
	held = maxf(0, held - delta)
	if held <= 0 and emotion in ["satisfied", "doubt"]:
		emotion = "impatient" if impatience > 0.1 else "neutral"
	_smile = move_toward(_smile, 1.0 if emotion == "satisfied" else 0.0, delta * 3)
	_doubt = move_toward(_doubt, 1.0 if emotion == "doubt" else 0.0, delta * 3)
	_apply()

func _apply() -> void:
	if not is_instance_valid(portrait):
		return
	var impatient := maxf(impatience, 1.0 if emotion == "impatient" else 0.0)
	var shift := Vector2(sin(time * 0.7) * 0.65 + impatient * sin(time * 2.2) * 1.1, sin(time * 1.15) * 0.7 + _smile * sin(time * 5.2) * 1.2)
	portrait.position = _origin + shift
	portrait.rotation = _doubt * -0.012 + impatient * sin(time * 1.6) * 0.003
	portrait.scale = _scale * Vector2(1, 1 + sin(time * 1.15) * 0.0015)
	if is_instance_valid(shadow):
		shadow.position = _shadow_origin + shift
		shadow.rotation = portrait.rotation
	if _material != null:
		_material.set_shader_parameter("smile", _smile)
		_material.set_shader_parameter("doubt", _doubt)
		_material.set_shader_parameter("impatient", impatient)
