class_name Interactable
extends Area2D

signal interacted(interactable: Interactable)

@export var interaction_name: String = "Objeto"
@export_multiline var description: String = ""
@export var interaction_type: String = "object"

var _hovered := false
var _selected := false
var _base_scale := Vector2.ONE
var _glow_strength := 0.0
var _glow_tween: Tween
var _selection_strength := 0.0
var _selection_tween: Tween

const GLOW_INTERACTION_TYPES := ["clipboard", "lamp", "window", "door", "customer"]

func _ready() -> void:
	_base_scale = scale
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	queue_redraw()


func _draw() -> void:
	if (not _hovered and not _selected) or interaction_type not in GLOW_INTERACTION_TYPES:
		return

	for child in get_children():
		if not child is CollisionShape2D or not child.shape is RectangleShape2D:
			continue

		var collision := child as CollisionShape2D
		var rectangle_shape := collision.shape as RectangleShape2D
		draw_set_transform(collision.position, collision.rotation, collision.scale)
		var rect := Rect2(-rectangle_shape.size * 0.5, rectangle_shape.size)
		var strength: float = max(_glow_strength, _selection_strength)
		draw_rect(rect, Color(1.0, 0.76, 0.32, strength * 0.08), true)
		draw_rect(rect.grow(7.0), Color(1.0, 0.72, 0.25, strength * 0.22), false, 8.0)
		draw_rect(rect, Color(1.0, 0.88, 0.52, strength * 0.9), false, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		interacted.emit(self)


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_visual_state()
	if interaction_type in GLOW_INTERACTION_TYPES:
		_start_glow_pulse()
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_mouse_exited() -> void:
	_hovered = false
	if _glow_tween != null and _glow_tween.is_running():
		_glow_tween.kill()
	_glow_tween = null
	_set_glow_strength(0.0)
	_refresh_visual_state()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func set_selected(value: bool) -> void:
	_selected = value
	if _selection_tween != null and _selection_tween.is_running():
		_selection_tween.kill()
		_selection_tween = null
	if _selected and interaction_type in GLOW_INTERACTION_TYPES:
		_selection_tween = create_tween().set_loops()
		_selection_tween.tween_method(_set_selection_strength, 0.35, 0.85, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_selection_tween.tween_method(_set_selection_strength, 0.85, 0.35, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_set_selection_strength(0.0)
	_refresh_visual_state()
	queue_redraw()


func _start_glow_pulse() -> void:
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_method(_set_glow_strength, 0.12, 0.75, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_method(_set_glow_strength, 0.75, 0.12, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_glow_strength(value: float) -> void:
	_glow_strength = value
	queue_redraw()


func _set_selection_strength(value: float) -> void:
	_selection_strength = value
	queue_redraw()


func _refresh_visual_state() -> void:
	scale = _base_scale * 1.05 if _hovered else _base_scale
	modulate = Color(1.18, 1.12, 0.92) if _hovered else Color(1.10, 1.06, 0.90) if _selected else Color.WHITE
