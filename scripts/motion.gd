extends Node
## Turns the phone's tilt into the room's gravity and its shakes into impulses.
## Autoloaded as Motion.
##
## Web: reads window.bobMotion, filled by the script in export_presets.cfg
## (html/head_include) from deviceorientation / devicemotion events.
## Android/iOS builds: reads Godot's own sensors.
## Desktop: arrow keys tilt, space shakes.

signal shaken(impulse: Vector2)  # screen-space direction, strength ~ m/s^2

const GRAVITY := 1400.0
const SHAKE_THRESHOLD := 13.0  # m/s^2 of linear acceleration
const SHAKE_COOLDOWN := 0.25
const KEY_TILT_SPEED := 1.8  # radians per second

var gravity_dir := Vector2.DOWN
var has_sensors := false

var _target_dir := Vector2.DOWN
var _key_angle := 0.0
var _shake_cooldown := 0.0
var _js: JavaScriptObject


func _ready() -> void:
	if OS.has_feature("web"):
		_js = JavaScriptBridge.get_interface("bobMotion")


func _physics_process(delta: float) -> void:
	_shake_cooldown -= delta
	var accel := Vector2.ZERO  # linear acceleration in screen space (m/s^2)
	var sensed := false

	if _js != null and bool(_js.has):
		sensed = true
		var tilt := _gravity_from_orientation(float(_js.beta), float(_js.gamma), float(_js.angle))
		# Held flat, the tilt direction is noise. Keep the last good direction.
		if tilt.length() > 0.3:
			_target_dir = tilt.normalized()
		accel = _to_screen(Vector3(float(_js.ax), float(_js.ay), float(_js.az)), float(_js.angle))
	elif OS.has_feature("mobile"):
		var g := Input.get_gravity()
		if g.length() > 0.5:
			sensed = true
			var tilt := Vector2(g.x, -g.y)
			if tilt.length() > 3.0:
				_target_dir = tilt.normalized()
			var a := Input.get_accelerometer() - g
			accel = Vector2(a.x, -a.y)

	# Keyboard fallback, unless the player is typing in the chat box.
	if not sensed and get_viewport().gui_get_focus_owner() == null:
		var turn := Input.get_axis("ui_left", "ui_right")
		_key_angle = clampf(_key_angle - turn * KEY_TILT_SPEED * delta, -PI, PI)
		if turn == 0.0 and Input.is_action_pressed("ui_down"):
			_key_angle = move_toward(_key_angle, 0.0, KEY_TILT_SPEED * delta)
		_target_dir = Vector2.DOWN.rotated(_key_angle)
		if Input.is_action_just_pressed("ui_accept") and _shake_cooldown <= 0.0:
			shake(Vector2.from_angle(randf() * TAU) * 22.0)

	has_sensors = sensed
	gravity_dir = gravity_dir.slerp(_target_dir, minf(1.0, delta * 10.0)).normalized()
	var space := get_viewport().world_2d.space
	PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, gravity_dir)
	PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY, GRAVITY)

	if accel.length() > SHAKE_THRESHOLD and _shake_cooldown <= 0.0:
		# The room moves with the phone, so its contents lurch the other way.
		shake(-accel)


func shake(impulse: Vector2) -> void:
	_shake_cooldown = SHAKE_COOLDOWN
	shaken.emit(impulse)


## Gravity in screen space from deviceorientation angles (degrees).
## Derived from the W3C Z-X'-Y'' rotation: gravity in device axes is
## (sin g cos b, -sin b, -cos g cos b); the z part points out of the screen.
func _gravity_from_orientation(beta: float, gamma: float, screen_angle: float) -> Vector2:
	var b := deg_to_rad(beta)
	var g := deg_to_rad(gamma)
	var device := Vector3(sin(g) * cos(b), -sin(b), -cos(g) * cos(b))
	return _to_screen(device, screen_angle)


## Device axes (x right, y up the screen) to Godot screen axes (y down),
## undoing the browser's rotation when the phone is in landscape.
func _to_screen(v: Vector3, screen_angle: float) -> Vector2:
	return Vector2(v.x, -v.y).rotated(-deg_to_rad(screen_angle))
