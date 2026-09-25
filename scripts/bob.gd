extends RigidBody2D
## Bob: a stick figure with a physics body (a capsule). He keeps himself
## upright against whichever way gravity points, walks around and plays with
## toys, and goes limp when he's hit, thrown or shaken, then gets back up.
## The node's origin is the middle of the capsule; the pose is drawn from his feet.

const BobTalk := preload("res://scripts/bob_talk.gd")
const Sketch := preload("res://scripts/sketch.gd")

enum Mode { UPRIGHT, LIMP, RECOVER, NAP }
enum Act { IDLE, WALK, WAVE, DANCE, KICK, EAT }

const INK := Sketch.INK
const BACK_INK := Color(0.45, 0.45, 0.48)
const LINE_W := 5.0

# Body proportions
const THIGH := 32.0
const SHIN := 32.0
const BODY := 66.0
const UPPER_ARM := 26.0
const FOREARM := 26.0
const HEAD_R := 24.0
const HALF_HEIGHT := 93.0
const FEET := Vector2(0, HALF_HEIGHT)

# Movement
const WALK_SPEED := 130.0
const WALK_ACCEL := 1400.0
const JUMP_SPEED := 620.0
const UPRIGHT_GAIN := 10.0
const RECOVER_GAIN := 4.5
const NAP_GAIN := 3.0

# Knocks. Contact impulses are in Godot units (mass * px/s); Bob's mass is 3.
const IMPULSE_LIMP := 1300.0
const IMPULSE_DIZZY := 3200.0
const TOPPLE_ANGLE := 1.0
const FALL_TIME := 0.7  # airborne this long while upright and he starts flailing

# Speech
const TYPE_SPEED := 38.0
const BUBBLE_MAX_WIDTH := 300.0
const BUBBLE_FONT_SIZE := 24
const MIX_RATE := 22050.0

var mode := Mode.UPRIGHT
var act := Act.IDLE
var act_time := 0.0
var act_duration := 2.0
var facing := 1.0
var held := false
var held_item := ""  # food he's eating

var _mode_time := 0.0
var _grounded := false
var _airborne_time := 0.0
var _still_time := 0.0
var _max_impulse := 0.0
var _jump_requested := false
var _walk_target := Vector2.ZERO
var _walk_toy: RigidBody2D
var _walk_intent := ""  # "", "play", "eat"
var _walk_phase := 0.0
var _kicked := false
var _dizzy := 0.0
var _joy := 0.0
var _blink := 3.0
var _eye_look := 0.0
var _chat_timer := 18.0
var _poke_times := []

# Pose (local, feet at FEET)
var _up := Vector2.UP
var _hip := Vector2.ZERO
var _neck := Vector2.ZERO
var _head := Vector2.ZERO
var _shoulder := Vector2.ZERO
var _knee_f := Vector2.ZERO
var _foot_f := Vector2.ZERO
var _knee_b := Vector2.ZERO
var _foot_b := Vector2.ZERO
var _elbow_f := Vector2.ZERO
var _hand_f := Vector2.ZERO
var _elbow_b := Vector2.ZERO
var _hand_b := Vector2.ZERO

var _bubble_root: Node2D
var _bubble: PanelContainer
var _label: Label
var _speech_text := ""
var _speech_time := 0.0
var _speech_duration := 0.0

var _playback: AudioStreamGeneratorPlayback
var _blip_left := 0
var _blip_total := 1
var _blip_freq := 220.0
var _voice_phase := 0.0


func _ready() -> void:
	mass = 3.0
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 6
	custom_integrator = false
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = 0.1
	physics_material_override = material
	var capsule := CapsuleShape2D.new()
	capsule.radius = 20.0
	capsule.height = HALF_HEIGHT * 2.0
	var collision := CollisionShape2D.new()
	collision.shape = capsule
	add_child(collision)

	_build_bubble()
	_build_voice()
	PetState.asleep = false
	await get_tree().create_timer(0.8).timeout
	if PetState.is_new_game:
		say("Hi! I'm Bob. Drop me some toys!")
	elif PetState.seconds_away > 120.0:
		say("You're back! I missed you!")


# --- Physics ---------------------------------------------------------------------

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var g := Motion.gravity_dir
	var dt := state.step
	for i in state.get_contact_count():
		_max_impulse = maxf(_max_impulse, state.get_contact_impulse(i).length())

	var diff := wrapf(_upright_angle() - state.transform.get_rotation(), -PI, PI)
	match mode:
		Mode.UPRIGHT:
			state.angular_velocity = diff * UPRIGHT_GAIN
			if _grounded:
				var tangent := g.orthogonal()
				var along := state.linear_velocity.dot(tangent)
				var want := WALK_SPEED * facing * (0.6 if PetState.energy < 25.0 else 1.0) if act == Act.WALK else 0.0
				along = move_toward(along, want, WALK_ACCEL * dt)
				state.linear_velocity = g * state.linear_velocity.dot(g) + tangent * along
				if _jump_requested:
					state.linear_velocity -= g * JUMP_SPEED
			_jump_requested = false
		Mode.RECOVER:
			state.angular_velocity = diff * RECOVER_GAIN
			if _mode_time > 2.5 and state.get_contact_count() > 0:
				# Stuck (under a crate?). Wriggle free.
				state.linear_velocity -= g * 300.0
				_mode_time = 1.0
		Mode.NAP:
			var lie := wrapf(_upright_angle() + PI / 2.0 - state.transform.get_rotation(), -PI, PI)
			state.angular_velocity = lie * NAP_GAIN


## Rotation that points Bob's feet along gravity.
func _upright_angle() -> float:
	return Motion.gravity_dir.angle() - PI / 2.0


func _physics_process(delta: float) -> void:
	_mode_time += delta
	act_time += delta
	_grounded = _check_grounded()
	var impulse := _max_impulse
	_max_impulse = 0.0
	var tilt := absf(wrapf(_upright_angle() - rotation, -PI, PI))

	match mode:
		Mode.UPRIGHT:
			_airborne_time = 0.0 if _grounded else _airborne_time + delta
			if impulse > IMPULSE_LIMP:
				_knocked(impulse)
			elif tilt > TOPPLE_ANGLE:
				go_limp(BobTalk.TUMBLE_LINES.pick_random())
			elif _airborne_time > FALL_TIME:
				go_limp(BobTalk.TUMBLE_LINES.pick_random())
			else:
				_update_act(delta)
		Mode.LIMP:
			if impulse > IMPULSE_LIMP * 1.5 and not held:
				_knocked(impulse)
			var calm := linear_velocity.length() < 70.0 and absf(angular_velocity) < 1.5
			_still_time = _still_time + delta if calm and not held and get_contact_count() > 0 else 0.0
			if _still_time > 0.6:
				_set_mode(Mode.RECOVER)
		Mode.RECOVER:
			if impulse > IMPULSE_LIMP:
				_knocked(impulse)
			elif tilt < 0.15:
				_set_mode(Mode.UPRIGHT)
				_start_act(Act.IDLE, randf_range(0.8, 2.0))
				if randf() < 0.5 and not _bubble.visible:
					say(BobTalk.GETUP_LINES.pick_random())
		Mode.NAP:
			if impulse > IMPULSE_LIMP:
				PetState.asleep = false
				_knocked(impulse)
				say("Huh?! I'm up! I'm up!")
			elif PetState.energy >= 98.0:
				_wake("Ahh, what a great nap!")


func _check_grounded() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + Motion.gravity_dir * (HALF_HEIGHT + 10.0))
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_mode_time = 0.0
	_still_time = 0.0
	PetState.asleep = mode == Mode.NAP
	if mode != Mode.UPRIGHT:
		_walk_toy = null
		_walk_intent = ""
		if held_item != "":
			held_item = ""  # dropped the snack
	angular_damp = 1.5 if mode == Mode.LIMP else 0.0


func go_limp(line := "") -> void:
	if mode == Mode.NAP:
		PetState.asleep = false
	_set_mode(Mode.LIMP)
	if line != "":
		say(line)


func _knocked(impulse: float) -> void:
	if impulse > IMPULSE_DIZZY:
		_dizzy = 2.5
		PetState.change("fun", -4.0)
	go_limp(BobTalk.OUCH_LINES.pick_random())


func _wake(line: String) -> void:
	_set_mode(Mode.RECOVER)
	say(line)


# --- Behaviour -------------------------------------------------------------------

func _start_act(new_act: Act, duration := 0.0) -> void:
	if act == Act.EAT and new_act != Act.EAT:
		held_item = ""
	act = new_act
	act_time = 0.0
	act_duration = duration
	if new_act != Act.WALK:
		_walk_toy = null
		_walk_intent = ""


func _update_act(_delta: float) -> void:
	match act:
		Act.WALK:
			_update_walk()
		Act.KICK:
			if not _kicked and act_time > 0.15:
				_kicked = true
				_kick_toy()
		Act.EAT:
			if act_time >= act_duration:
				PetState.change("hunger", 30.0)
				_joy = 2.0
				say(["Delicious!", "Mmm, thanks!", "That hit the spot."].pick_random())
				_start_act(Act.IDLE, 2.0)
				return
	if act != Act.WALK and act_duration > 0.0 and act_time >= act_duration:
		if act == Act.IDLE:
			_think()
		else:
			_start_act(Act.IDLE, randf_range(1.0, 2.5))


## Pick something to do.
func _think() -> void:
	if PetState.energy < 12.0:
		say("I need... a little nap...")
		nap()
		return
	if PetState.hunger < 85.0:
		var snack := _nearest_toy(true)
		if snack:
			_walk_to_toy(snack, "eat")
			return
	var toy := _nearest_toy(false)
	if toy and randf() < 0.65:
		_walk_to_toy(toy, "play")
		return
	var r := randf()
	if r < 0.45:
		_walk_to(_random_floor_point())
	elif r < 0.55:
		_start_act(Act.WAVE, 1.6)
	elif r < 0.68 and PetState.happiness() > 60.0:
		_start_act(Act.DANCE, 3.5)
	elif r < 0.78 and PetState.energy > 30.0:
		jump()
	else:
		_eye_look = randf_range(-4.0, 4.0)
		_start_act(Act.IDLE, randf_range(1.5, 4.0))


func _nearest_toy(want_food: bool) -> RigidBody2D:
	var best: RigidBody2D = null
	var best_d := INF
	var now := Time.get_ticks_msec() / 1000.0
	for toy in get_tree().get_nodes_in_group("food" if want_food else "toys"):
		if not want_food and (toy.kind in ["anvil", "snack"] or now - toy.last_played < 6.0):
			continue
		if _height_above_floor(toy) > 90.0:
			continue  # out of reach (a balloon on the ceiling)
		var d := global_position.distance_to(toy.global_position)
		if d < best_d:
			best = toy
			best_d = d
	return best


## How far a toy is "above" Bob's feet, measured against gravity.
func _height_above_floor(body: Node2D) -> float:
	var feet := global_position + Motion.gravity_dir * HALF_HEIGHT
	return (feet - body.global_position).dot(Motion.gravity_dir) - body.radius


func _random_floor_point() -> Vector2:
	var room: Rect2 = get_parent().get_node("Room").inner
	return room.position + Vector2(randf(), randf()) * room.size


func _walk_to(point: Vector2) -> void:
	_start_act(Act.WALK, 0.0)
	_walk_target = point


func _walk_to_toy(toy: RigidBody2D, intent: String) -> void:
	_walk_to(toy.global_position)
	_walk_toy = toy
	_walk_intent = intent


func _update_walk() -> void:
	if _walk_toy != null and not is_instance_valid(_walk_toy):
		_start_act(Act.IDLE, 1.0)
		return
	var target := _walk_toy.global_position if _walk_toy else _walk_target
	var tangent := Motion.gravity_dir.orthogonal()
	var along := (target - global_position).dot(tangent)
	var reach := 8.0
	if _walk_toy:
		reach = _walk_toy.radius + 34.0
	if absf(along) < reach or act_time > 7.0:
		_arrive()
		return
	facing = signf(along)


func _arrive() -> void:
	var toy := _walk_toy
	var intent := _walk_intent
	if toy == null or not is_instance_valid(toy) or _height_above_floor(toy) > 90.0 or act_time > 7.0:
		_start_act(Act.IDLE, randf_range(1.0, 3.0))
		return
	facing = signf((toy.global_position - global_position).dot(Motion.gravity_dir.orthogonal()))
	if facing == 0.0:
		facing = 1.0
	if intent == "eat" and toy.is_in_group("food"):
		held_item = toy.food
		toy.queue_free()
		say(BobTalk.toy_line("snack", "play"))
		_start_act(Act.EAT, 2.5)
		return
	_walk_toy = toy  # keep it for the kick
	act = Act.KICK
	act_time = 0.0
	act_duration = 0.5
	_kicked = false


func _kick_toy() -> void:
	var toy := _walk_toy
	if toy == null or not is_instance_valid(toy):
		return
	var tangent := Motion.gravity_dir.orthogonal() * facing
	var dir := (tangent + -Motion.gravity_dir * 0.9).normalized()
	var speed := 650.0
	if toy.kind == "crate":
		dir = tangent
		speed = 260.0
	elif toy.kind == "balloon":
		dir = (-Motion.gravity_dir + tangent * 0.3).normalized()
	toy.apply_central_impulse(dir * speed * toy.mass)
	toy.last_played = Time.get_ticks_msec() / 1000.0
	PetState.change("fun", 7.0)
	PetState.change("energy", -1.5)
	_joy = 1.5
	if randf() < 0.6:
		say(BobTalk.toy_line(toy.kind, "play"))


## A toy just landed in the room.
func notice_toy(toy: RigidBody2D) -> void:
	if mode != Mode.UPRIGHT or act in [Act.EAT, Act.KICK]:
		return
	if randf() < 0.7 or toy.kind in ["anvil", "snack"]:
		say(BobTalk.toy_line(toy.kind, "drop"))
	facing = signf((toy.global_position - global_position).dot(Motion.gravity_dir.orthogonal()))
	if facing == 0.0:
		facing = 1.0
	if act == Act.IDLE:
		act_duration = minf(act_duration, act_time + 0.8)  # think about it soon


func jump() -> void:
	if mode == Mode.UPRIGHT and _grounded:
		_jump_requested = true
		_start_act(Act.IDLE, 1.2)


func nap() -> void:
	if mode == Mode.UPRIGHT:
		_start_act(Act.IDLE, 0.0)
		_set_mode(Mode.NAP)


## The phone was shaken: everything in the room lurches.
func shaken(impulse: Vector2) -> void:
	apply_central_impulse(impulse * 28.0 * mass)
	if impulse.length() > 16.0 and mode != Mode.LIMP:
		go_limp(BobTalk.TUMBLE_LINES.pick_random())


func set_held(value: bool) -> void:
	held = value
	if held:
		if mode == Mode.NAP:
			say("Whoa! I was sleeping!")
		else:
			say(["Whoa!", "Hey, put me down!", "Wheee!", "I'm flying!"].pick_random())
		go_limp()
	elif linear_velocity.length() > 900.0:
		say("Wheeeee!")
		PetState.change("fun", 3.0)


func poke() -> void:
	if mode == Mode.NAP:
		if PetState.energy > 60.0:
			_wake("Mmph... okay, I'm up.")
		else:
			say(["Zzz...", "Mmm... five more minutes...", "*snore*"].pick_random())
		return
	var now := Time.get_ticks_msec()
	_poke_times = _poke_times.filter(func(t: int) -> bool: return now - t < 4000)
	_poke_times.append(now)
	if _poke_times.size() >= 5:
		say("Okay, okay, stop poking me!")
		PetState.change("fun", -2.0)
		return
	PetState.change("fun", 3.0)
	_joy = 1.2
	say(["Hehe!", "Hey there!", "That tickles!", "Boop!", "Hi!", "What's up?"].pick_random())
	if mode == Mode.UPRIGHT and randf() < 0.3:
		jump()


## The player typed something to Bob.
func hear(text: String) -> void:
	if mode == Mode.NAP:
		say(["Zzz...", "Mmm... sandwiches... zzz", "No, YOU'RE a stick figure... zzz"].pick_random())
		return
	var reply := BobTalk.reply(text)
	PetState.change("fun", 2.0 + float(reply.fun))
	if float(reply.fun) > 0.0:
		_joy = 2.0
	say(reply.text)
	if mode != Mode.UPRIGHT or act in [Act.EAT, Act.KICK]:
		return
	match reply.action:
		"dance":
			_start_act(Act.DANCE, 4.0)
		"jump":
			jump()
		"wave":
			_start_act(Act.WAVE, 1.8)
		"come":
			_walk_to(get_parent().get_node("Room").inner.get_center())
		"nap":
			nap()
		_:
			if act == Act.WALK:
				_start_act(Act.IDLE, 3.0)


# --- Frame update ---------------------------------------------------------------

func _process(delta: float) -> void:
	_joy = maxf(_joy - delta, 0.0)
	_dizzy = maxf(_dizzy - delta, 0.0)
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(2.0, 5.0)
	if act == Act.WALK and mode == Mode.UPRIGHT:
		_walk_phase += delta * absf(linear_velocity.dot(Motion.gravity_dir.orthogonal())) / 16.0
	if mode == Mode.UPRIGHT and act in [Act.IDLE, Act.WALK]:
		_chat_timer -= delta
		if _chat_timer <= 0.0 and not _bubble.visible:
			say(BobTalk.ambient())
	_compute_pose()
	_update_speech(delta)
	_fill_voice()
	queue_redraw()


# --- Pose -----------------------------------------------------------------------

## Limb direction: 0 = straight down (toward his feet), PI = up, positive = forward.
func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle) * facing, cos(angle))


func _compute_pose() -> void:
	var t := act_time
	var lean := 0.0
	var thigh_f := 0.22
	var shin_f := 0.22
	var thigh_b := -0.22
	var shin_b := -0.22
	var arm_f := 0.45 + sin(Time.get_ticks_msec() / 500.0) * 0.03
	var fore_f := 0.3
	var arm_b := -arm_f
	var fore_b := -0.3

	if mode == Mode.LIMP or (mode == Mode.UPRIGHT and not _grounded and _airborne_time > 0.15):
		# Limbs hang toward gravity and flail with speed.
		var lg := Motion.gravity_dir.rotated(-rotation)
		var hang := atan2(lg.x * facing, lg.y)
		var speed := clampf(linear_velocity.length() / 700.0, 0.1, 0.9)
		var s := Time.get_ticks_msec() / 1000.0 * 16.0
		thigh_f = hang + 0.25 + sin(s) * speed * 0.6
		shin_f = thigh_f + 0.2
		thigh_b = hang - 0.25 + sin(s + 2.0) * speed * 0.6
		shin_b = thigh_b + 0.2
		arm_f = hang + 0.6 + sin(s * 1.2) * speed
		fore_f = arm_f + 0.4
		arm_b = hang - 0.6 + sin(s * 1.2 + 1.5) * speed
		fore_b = arm_b - 0.4
	elif mode == Mode.NAP:
		thigh_f = 0.05
		shin_f = 0.05
		thigh_b = -0.05
		shin_b = -0.05
		arm_f = 0.1
		fore_f = 0.1
		arm_b = -0.1
		fore_b = -0.1
	elif mode == Mode.UPRIGHT:
		match act:
			Act.WALK:
				var p := _walk_phase
				thigh_f = sin(p) * 0.5
				thigh_b = sin(p + PI) * 0.5
				shin_f = thigh_f - 0.7 * maxf(0.0, cos(p))
				shin_b = thigh_b - 0.7 * maxf(0.0, cos(p + PI))
				arm_f = -sin(p) * 0.5
				fore_f = arm_f + 0.5
				arm_b = sin(p) * 0.5
				fore_b = arm_b + 0.5
				lean = 0.06
			Act.KICK:
				var k := clampf(t / 0.2, 0.0, 1.0)
				thigh_f = lerpf(-0.5, 1.3, k)
				shin_f = thigh_f - lerpf(0.9, 0.1, k)
				thigh_b = -0.1
				shin_b = -0.1
				arm_f = -0.7
				fore_f = -0.4
				arm_b = 0.8
				fore_b = 1.2
				lean = -0.12
			Act.WAVE:
				arm_f = PI * 0.8
				fore_f = PI + sin(t * 12.0) * 0.4
			Act.DANCE:
				var beat := t * 7.0
				facing = 1.0 if sin(beat * 0.5) > 0.0 else -1.0
				lean = sin(beat) * 0.15
				thigh_f = maxf(0.0, sin(beat)) * 0.8
				shin_f = thigh_f - 1.2 * maxf(0.0, sin(beat))
				thigh_b = -maxf(0.0, -sin(beat)) * 0.3
				shin_b = thigh_b
				arm_f = PI * 0.75 + sin(beat) * 0.35
				fore_f = arm_f + 0.4 * sin(beat * 2.0)
				arm_b = -PI * 0.75 + sin(beat) * 0.35
				fore_b = arm_b - 0.4
			Act.EAT:
				arm_f = 0.9
				fore_f = 2.8 + sin(t * 8.0) * 0.15

	var ext_f := THIGH * cos(thigh_f) + SHIN * cos(shin_f)
	var ext_b := THIGH * cos(thigh_b) + SHIN * cos(shin_b)
	_hip = FEET + Vector2(0, -maxf(maxf(ext_f, ext_b), 30.0))
	_up = _dir(PI - lean)
	var breathe := sin(Time.get_ticks_msec() / 500.0) * 1.2
	_neck = _hip + _up * BODY + Vector2(0, breathe)
	_head = _neck + _up * (HEAD_R + 3.0)
	_shoulder = _hip + _up * (BODY - 10.0) + Vector2(0, breathe)
	_knee_f = _hip + _dir(thigh_f) * THIGH
	_foot_f = _knee_f + _dir(shin_f) * SHIN
	_knee_b = _hip + _dir(thigh_b) * THIGH
	_foot_b = _knee_b + _dir(shin_b) * SHIN
	_elbow_f = _shoulder + _dir(arm_f) * UPPER_ARM
	_hand_f = _elbow_f + _dir(fore_f) * FOREARM
	_elbow_b = _shoulder + _dir(arm_b) * UPPER_ARM
	_hand_b = _elbow_b + _dir(fore_b) * FOREARM


# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	_seg(_shoulder, _elbow_b, BACK_INK)
	_seg(_elbow_b, _hand_b, BACK_INK)
	_seg(_hip, _knee_b, BACK_INK)
	_seg(_knee_b, _foot_b, BACK_INK)
	_draw_foot(_foot_b, BACK_INK)
	_seg(_hip, _neck, INK)
	_seg(_hip, _knee_f, INK)
	_seg(_knee_f, _foot_f, INK)
	_draw_foot(_foot_f, INK)

	draw_circle(_head, HEAD_R, Color.WHITE)
	draw_arc(_head, HEAD_R, 0.0, TAU, 48, INK, LINE_W, true)
	var crown := _head + _up * HEAD_R
	for k in [-0.35, 0.0, 0.35]:
		draw_line(crown, crown + _dir(PI + k) * 13.0, INK, 3.0, true)
	_draw_face()

	_seg(_shoulder, _elbow_f, INK)
	_seg(_elbow_f, _hand_f, INK)
	if held_item != "":
		Sketch.food_item(self, held_item, _hand_f + Vector2(4.0 * facing, -4.0), maxf(0.3, 1.0 - 0.7 * act_time / 2.5))

	if _dizzy > 0.0:
		for i in 3:
			var a := Time.get_ticks_msec() / 250.0 + TAU * i / 3.0
			_draw_star(_head + _up * (HEAD_R + 8.0) + Vector2(cos(a) * 26.0, sin(a) * 8.0))
	if mode == Mode.NAP:
		_draw_zzz()


func _seg(a: Vector2, b: Vector2, color: Color) -> void:
	draw_line(a, b, color, LINE_W, true)
	draw_circle(a, LINE_W * 0.5, color)
	draw_circle(b, LINE_W * 0.5, color)


func _draw_foot(foot: Vector2, color: Color) -> void:
	draw_line(foot, foot + Vector2(9.0 * facing, 0), color, LINE_W, true)


func _draw_star(p: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 11:
		var r := 7.0 if i % 2 == 0 else 3.0
		pts.append(p + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * r)
	draw_colored_polygon(pts, Color("#f7c948"))
	draw_polyline(pts, INK, 1.5, true)


func _draw_zzz() -> void:
	# Letters rise in screen space, not Bob's rotated space.
	var head_world := to_global(_head)
	draw_set_transform_matrix(global_transform.affine_inverse())
	var font := ThemeDB.fallback_font
	for i in 3:
		var k := fmod(Time.get_ticks_msec() / 2500.0 + i / 3.0, 1.0)
		var pos := head_world + Vector2(10.0 + k * 45.0, -30.0 - k * 80.0)
		draw_string(font, pos, "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 + k * 22), Color(INK, 1.0 - k))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_face() -> void:
	var look := 5.0 * facing + _eye_look
	var eye_l := _head + Vector2(look - 8.0, -3.0)
	var eye_r := _head + Vector2(look + 8.0, -3.0)
	var mouth := _head + Vector2(look * 0.8, 10.0)
	var happy := _joy > 0.0 or act == Act.DANCE
	var surprised := mode == Mode.LIMP and _dizzy <= 0.0

	for e in [eye_l, eye_r]:
		if _dizzy > 0.0:
			draw_line(e + Vector2(-4, -4), e + Vector2(4, 4), INK, 2.5, true)
			draw_line(e + Vector2(-4, 4), e + Vector2(4, -4), INK, 2.5, true)
		elif mode == Mode.NAP or (_blink < 0.0 and not surprised):
			draw_line(e - Vector2(4, 0), e + Vector2(4, 0), INK, 2.5, true)
		elif surprised:
			draw_arc(e, 4.5, 0.0, TAU, 16, INK, 2.5, true)
		elif happy:
			draw_arc(e + Vector2(0, 2), 4.5, PI + 0.3, TAU - 0.3, 10, INK, 2.5, true)
		elif PetState.energy < 25.0:
			draw_line(e + Vector2(-4, -1), e + Vector2(4, -1), INK, 2.5, true)
			draw_circle(e + Vector2(0, 1.5), 2.2, INK)
		else:
			draw_circle(e, 3.2, INK)
	if happy:
		draw_circle(eye_l + Vector2(-3, 9), 4.0, Color(1.0, 0.55, 0.6, 0.55))
		draw_circle(eye_r + Vector2(3, 9), 4.0, Color(1.0, 0.55, 0.6, 0.55))

	var mood := PetState.happiness()
	if mode == Mode.NAP:
		draw_arc(mouth, 2.5, 0.0, TAU, 12, INK, 2.0, true)
	elif act == Act.EAT and mode == Mode.UPRIGHT:
		draw_circle(mouth, 2.0 + absf(sin(act_time * 10.0)) * 4.0, INK)
	elif surprised or _dizzy > 0.0:
		draw_arc(mouth, 5.0, 0.0, TAU, 16, INK, 2.5, true)
	elif happy or mood > 65.0:
		draw_arc(mouth + Vector2(0, -5), 8.0, 0.4, PI - 0.4, 12, INK, 3.0, true)
	elif mood > 35.0:
		draw_line(mouth - Vector2(6, 0), mouth + Vector2(6, 0), INK, 3.0, true)
	else:
		draw_arc(mouth + Vector2(0, 7), 8.0, PI + 0.5, TAU - 0.5, 12, INK, 3.0, true)


# --- Speech bubble and voice --------------------------------------------------------

func _build_bubble() -> void:
	# The bubble lives outside Bob's rotation so the text always reads level.
	_bubble_root = Node2D.new()
	_bubble_root.top_level = true
	_bubble_root.z_index = 50
	_bubble_root.draw.connect(_draw_bubble_tail)
	add_child(_bubble_root)
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.border_color = INK
	box.set_border_width_all(4)
	box.set_corner_radius_all(16)
	box.set_content_margin_all(12)
	_bubble.add_theme_stylebox_override("panel", box)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_font_size_override("font_size", BUBBLE_FONT_SIZE)
	_bubble.add_child(_label)
	_bubble.visible = false
	_bubble_root.add_child(_bubble)


func say(text: String) -> void:
	_speech_text = text
	_speech_time = 0.0
	_speech_duration = text.length() / TYPE_SPEED + 2.0 + text.length() * 0.03
	_label.text = text
	_label.visible_characters = 0
	var font := _label.get_theme_font("font")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUBBLE_FONT_SIZE).x
	_label.custom_minimum_size.x = minf(width + 4.0, BUBBLE_MAX_WIDTH)
	_bubble.size = Vector2.ZERO
	_bubble.visible = true
	_chat_timer = randf_range(15.0, 28.0)


func _head_top_world() -> Vector2:
	return to_global(_head + _up * HEAD_R)


func _update_speech(delta: float) -> void:
	_bubble_root.global_position = Vector2.ZERO
	_bubble_root.queue_redraw()
	if not _bubble.visible:
		return
	_speech_time += delta
	var shown := mini(int(_speech_time * TYPE_SPEED), _speech_text.length())
	if shown > _label.visible_characters:
		for i in range(maxi(_label.visible_characters, 0), shown):
			if i % 2 == 0 and _speech_text[i] != " ":
				_blip()
		_label.visible_characters = shown
	if _speech_time > _speech_duration:
		_bubble.visible = false
		return
	_bubble.reset_size()
	# Sit "above" his head against gravity, but keep on screen and level.
	var screen := get_viewport_rect().size
	var size := _bubble.size
	var anchor := _head_top_world() - Motion.gravity_dir * 30.0
	var center := anchor - Motion.gravity_dir * (size.y / 2.0 + absf(Motion.gravity_dir.x) * size.x / 2.0)
	var pos := center - size / 2.0
	pos.x = clampf(pos.x, 8.0, screen.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, screen.y - size.y - 8.0)
	_bubble.position = pos


func _draw_bubble_tail() -> void:
	if not _bubble.visible:
		return
	var tip := _head_top_world() - Motion.gravity_dir * 10.0
	var center := _bubble.position + _bubble.size / 2.0
	var side := (tip - center).orthogonal().normalized() * 11.0
	var a := center + side
	var b := center - side
	_bubble_root.draw_colored_polygon(PackedVector2Array([a, b, tip]), Color.WHITE)
	_bubble_root.draw_line(a, tip, INK, 4.0, true)
	_bubble_root.draw_line(b, tip, INK, 4.0, true)


func _build_voice() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.1
	var player := AudioStreamPlayer.new()
	player.stream = generator
	player.volume_db = -12.0
	# Web builds default to sample playback, which can't play generated audio.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.play()
	_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


## One little "voice" blip. Happier Bob talks in a higher voice.
func _blip() -> void:
	_blip_total = int(MIX_RATE * 0.055)
	_blip_left = _blip_total
	_blip_freq = 170.0 + PetState.happiness() * 1.6 + randf_range(-40.0, 60.0)


func _fill_voice() -> void:
	if _playback == null:
		return
	for i in _playback.get_frames_available():
		var sample := 0.0
		if _blip_left > 0:
			_voice_phase = fmod(_voice_phase + _blip_freq / MIX_RATE, 1.0)
			var wave := sin(_voice_phase * TAU)
			var envelope := minf(1.0, (_blip_total - _blip_left) / 150.0) * float(_blip_left) / _blip_total
			sample = (wave + 0.35 * signf(wave)) * 0.35 * envelope
			_blip_left -= 1
		_playback.push_frame(Vector2(sample, sample))
