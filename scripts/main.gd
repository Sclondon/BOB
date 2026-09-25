extends Node2D
## Runs the room: drops toys from the tray, lets a finger grab and fling
## anything (Bob included), and passes phone shakes on to everything inside.

const Toy := preload("res://scripts/toy.gd")
const Sketch := preload("res://scripts/sketch.gd")

const MAX_TOYS := 24
const GRAB_STIFFNESS := 90.0
const GRAB_DAMPING := 11.0
const MAX_FLING := 1800.0
const SHAKE_STRENGTH := 28.0  # px/s of velocity per m/s^2 of phone jolt

@onready var room: StaticBody2D = $Room
@onready var toys: Node2D = $Toys
@onready var bob: RigidBody2D = $Bob
@onready var hud: CanvasLayer = $HUD
@onready var ghost: Node2D = $Ghost

var _finger := Vector2.ZERO
var _finger_vel := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _moved := false

var _drag_kind := ""  # toy being dragged out of the tray

var _grab_body: RigidBody2D  # body the finger is holding
var _grab_local := Vector2.ZERO


func _ready() -> void:
	hud.toy_pressed.connect(_on_tray_pressed)
	hud.clear_requested.connect(_clear_toys)
	hud.message_sent.connect(bob.hear)
	Motion.shaken.connect(_on_shaken)
	ghost.draw.connect(_draw_ghost)
	get_viewport().size_changed.connect(_keep_inside.call_deferred)
	bob.global_position = room.inner.get_center() + Vector2(0, room.inner.size.y / 2.0 - bob.HALF_HEIGHT - 2.0)
	if PetState.autopilot:
		add_child(preload("res://tools/autopilot.gd").new())


# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Track the finger everywhere, including over the tray.
	if event is InputEventMouseMotion:
		_finger_vel = _finger_vel.lerp(event.velocity, 0.5)
		_finger = _canvas_pos(event.position)
		if _finger.distance_to(_press_pos) > 12.0:
			_moved = true
		if _drag_kind != "":
			ghost.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_finger = _canvas_pos(event.position)
		if event.pressed:
			return
		if _drag_kind != "":
			_drop_from_tray()
		elif _grab_body != null:
			_release_grab()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_finger = _canvas_pos(event.position)
		_press_pos = _finger
		_moved = false
		_finger_vel = Vector2.ZERO
		var body := _body_at(_finger)
		if body:
			_grab_body = body
			_grab_local = body.to_local(_finger)
			get_viewport().set_input_as_handled()


func _canvas_pos(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _body_at(point: Vector2) -> RigidBody2D:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	var hits := get_world_2d().direct_space_state.intersect_point(params, 8)
	for hit in hits:
		if hit.collider is RigidBody2D:
			return hit.collider
	# Bob is skinny; be generous around him.
	if point.distance_to(bob.global_position) < 70.0 or point.distance_to(bob.to_global(bob._head)) < 45.0:
		return bob
	return null


func _physics_process(_delta: float) -> void:
	if _grab_body == null or not is_instance_valid(_grab_body):
		_grab_body = null
		return
	if not _moved:
		return
	if _grab_body == bob and not bob.held:
		bob.set_held(true)
	# A damped spring pulling the grabbed point to the finger. Applying it at
	# the grab point makes things swing and dangle naturally.
	var point := _grab_body.to_global(_grab_local)
	var pull := (_finger - point) * GRAB_STIFFNESS - _grab_body.linear_velocity * GRAB_DAMPING
	_grab_body.apply_force(pull * _grab_body.mass, point - _grab_body.global_position)
	_grab_body.angular_velocity *= 0.97


func _release_grab() -> void:
	var body := _grab_body
	_grab_body = null
	if body == bob:
		if bob.held:
			bob.set_held(false)
		elif not _moved:
			bob.poke()
	elif not _moved and is_instance_valid(body):
		body.apply_central_impulse(-Motion.gravity_dir * 350.0 * body.mass)  # boop
	if is_instance_valid(body):
		body.linear_velocity = body.linear_velocity.limit_length(MAX_FLING)


# --- Toys ---------------------------------------------------------------------------

func _on_tray_pressed(kind: String) -> void:
	_drag_kind = kind
	_moved = false
	_press_pos = _finger
	ghost.show()
	ghost.queue_redraw()


func _drop_from_tray() -> void:
	var kind := _drag_kind
	_drag_kind = ""
	ghost.hide()
	if _moved and room.inner.grow(-20.0).has_point(_finger):
		spawn_toy(kind, _finger, (_finger_vel * 0.8).limit_length(MAX_FLING))
	elif not _moved:
		spawn_toy(kind, _drop_point(), Vector2.ZERO)


## Somewhere near the "top" of the room, whichever way is up right now.
func _drop_point() -> Vector2:
	var r: Rect2 = room.inner
	var up := -Motion.gravity_dir
	var reach := absf(up.x) * r.size.x / 2.0 + absf(up.y) * r.size.y / 2.0
	var along := up.orthogonal() * randf_range(-0.35, 0.35) * minf(r.size.x, r.size.y)
	return r.get_center() + up * (reach - 70.0) + along


func spawn_toy(kind: String, pos: Vector2, velocity: Vector2) -> void:
	var existing := toys.get_children()
	if existing.size() >= MAX_TOYS:
		existing[0].queue_free()
	var toy := Toy.new()
	toy.setup(kind)
	toy.position = pos
	toy.rotation = randf_range(-0.4, 0.4)
	toy.linear_velocity = velocity
	toy.angular_velocity = randf_range(-3.0, 3.0)
	toys.add_child(toy)
	bob.notice_toy(toy)
	hud.dismiss_hint()


func _clear_toys() -> void:
	for toy in toys.get_children():
		toy.queue_free()
	if _grab_body != bob:
		_grab_body = null


func _draw_ghost() -> void:
	if _drag_kind == "":
		return
	ghost.draw_set_transform(_finger, 0.0, Vector2.ONE)
	Sketch.toy(ghost, _drag_kind, "apple", Sketch.boil(), Motion.gravity_dir)
	ghost.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- World ------------------------------------------------------------------------

func _on_shaken(impulse: Vector2) -> void:
	for toy in toys.get_children():
		# A little randomness so a pile doesn't move as one block.
		var jitter := Vector2.from_angle(randf() * TAU) * impulse.length() * 0.25
		toy.apply_central_impulse((impulse + jitter) * SHAKE_STRENGTH * toy.mass)
	bob.shaken(impulse)


## After a resize, pull anything that ended up outside the walls back in.
func _keep_inside() -> void:
	var r: Rect2 = room.inner.grow(-40.0)
	for body in toys.get_children() + [bob]:
		if not r.has_point(body.global_position):
			body.global_position = r.get_center()
			body.linear_velocity = Vector2.ZERO
