extends Node2D
## Portrait-only transitions leave service, inventory and queue state synchronous.

const DOOR_POSITION := Vector2(622, 330)
var arrival_actor: Node2D
var arrival_subject: Node2D
var arrival_tween: Tween
var hidden_art: Array[CanvasItem] = []
var departures: Array[Node2D] = []

class MovingPortrait extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2(0, 125), 0.0, Vector2(1.0, 0.18))
		for ring in range(5, 0, -1):
			draw_circle(Vector2.ZERO, 40.0 + ring * 6.0, Color(0.035, 0.022, 0.01, 0.035))
		draw_set_transform(Vector2.ZERO)

func _make_actor(subject: Node2D) -> Node2D:
	var actor := MovingPortrait.new()
	for child in subject.get_children():
		if child is Sprite2D and child.visible:
			actor.add_child(child.duplicate())
	if actor.get_child_count() == 0:
		actor.free()
		return null
	add_child(actor)
	actor.global_transform = subject.global_transform
	return actor

func arrive(subject: Node2D) -> void:
	finish_arrival()
	_clear_departures()
	arrival_actor = _make_actor(subject)
	if arrival_actor == null:
		return
	arrival_actor.name = "EnteringCustomer"
	arrival_subject = subject
	for child in subject.get_children():
		if child is Sprite2D and child.visible:
			hidden_art.append(child)
			child.hide()
	var destination := subject.global_position
	var destination_scale := subject.global_scale
	arrival_actor.global_position = DOOR_POSITION
	arrival_actor.scale = destination_scale * 0.23
	arrival_actor.modulate.a = 0.0
	arrival_tween = arrival_actor.create_tween().set_parallel(true)
	arrival_tween.tween_property(arrival_actor, "global_position", destination, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrival_tween.tween_property(arrival_actor, "scale", destination_scale, 1.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	arrival_tween.tween_property(arrival_actor, "modulate:a", 1.0, 0.25)
	arrival_tween.chain().tween_callback(func() -> void:
		arrival_tween = null
		finish_arrival()
	)

func finish_arrival() -> void:
	if arrival_tween != null and arrival_tween.is_valid():
		arrival_tween.kill()
	arrival_tween = null
	for art in hidden_art:
		if is_instance_valid(art):
			art.show()
	hidden_art.clear()
	if is_instance_valid(arrival_actor):
		arrival_actor.queue_free()
	arrival_actor = null
	arrival_subject = null

func depart(subject: Node2D, hold_seconds := 0.0) -> void:
	finish_arrival()
	if not is_instance_valid(subject) or not subject.visible:
		return
	var actor := _make_actor(subject)
	if actor == null:
		return
	actor.name = "LeavingCustomer"
	departures.append(actor)
	var tween := actor.create_tween()
	if hold_seconds > 0.0:
		tween.tween_interval(hold_seconds)
	tween.tween_property(actor, "global_position", DOOR_POSITION, 0.80).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(actor, "scale", actor.scale * 0.23, 0.80).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(actor, "modulate:a", 0.0, 0.25).set_delay(0.57)
	tween.tween_callback(func() -> void:
		departures.erase(actor)
		actor.queue_free()
	)

func _clear_departures() -> void:
	for actor in departures:
		if is_instance_valid(actor):
			actor.queue_free()
	departures.clear()

func reset() -> void:
	finish_arrival()
	_clear_departures()
