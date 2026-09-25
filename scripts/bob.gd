extends Node2D
## Bob: a stick figure drawn entirely in code and driven by a small state machine.
## His origin is at his feet. Click him to poke, drag him to pick him up.

const BobTalk := preload("res://scripts/bob_talk.gd")

enum State { IDLE, WALK, WAVE, DANCE, JUMP, EAT, PLAY, SHOWER, SLEEP, HELD, FALL }

const INK := Color(0.1, 0.1, 0.12)
const BACK_INK := Color(0.38, 0.38, 0.42)
const HEAD_FILL := Color(1, 1, 1)
const LINE_W := 5.0

# Body proportions
const THIGH := 32.0
const SHIN := 32.0
const BODY := 66.0
const UPPER_ARM := 26.0
const FOREARM := 26.0
const HEAD_R := 24.0

# World layout (matches room.gd)
const FLOOR_Y := 600.0
const MIN_X := 140.0
const MAX_X := 1140.0
const BED_EXIT_X := 370.0
const SLEEP_POS := Vector2(290, 490)
const WALK_SPEED := 110.0
const GRAVITY := 1500.0
const HOLD_OFFSET := 175.0

const FOODS := ["apple", "pizza", "burger", "donut"]
const FOOD_LINES := {
	"apple": "An apple! Crunchy!",
	"pizza": "PIZZA! My favorite!",
	"burger": "A burger? You spoil me.",
	"donut": "Ooh, a donut!",
}
const SLEEP_TALK := ["Zzz...", "Mmm... five more minutes...", "*snore*", "Mmm... sandwiches... zzz", "No, YOU'RE a stick figure... zzz"]
const POKE_LINES := ["Hehe!", "Hey there!", "That tickles!", "Boop!", "Hi!", "What's up?"]

# Speech
const TYPE_SPEED := 38.0  # characters per second
const BUBBLE_MAX_WIDTH := 260.0
const BUBBLE_FONT_SIZE := 20

# Voice blips
const MIX_RATE := 22050.0

var state := State.IDLE
var state_time := 0.0
var state_duration := 2.0
var facing := 1.0
var anim_t := 0.0
var held_item := ""

var _pending := -1  # state to enter when a walk finishes
var _target_x := 640.0
var _walk_phase := 0.0
var _vel := Vector2.ZERO
var _swing := 0.0
var _throw_vel := Vector2.ZERO
var _pressing := false
var _press_pos := Vector2.ZERO
var _poke_times := []

var _eye_look := 0.0
var _blink_timer := 3.0
var _joy := 0.0  # seconds of extra-happy face left
var _chat_timer := 18.0
var _bubbles := []

# Pose, recomputed every frame (local coordinates, before the sleep rotation)
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
	_build_bubble()
	_build_voice()
	position = Vector2(640, FLOOR_Y)
	if PetState.asleep:
		_start_sleeping()
	await get_tree().create_timer(0.8).timeout
	if PetState.is_new_game:
		say("Hi! I'm Bob. Please take care of me!")
	elif not PetState.asleep and PetState.seconds_away > 120.0:
		say("You're back! I missed you!")


func _process(delta: float) -> void:
	anim_t += delta
	state_time += delta
	_joy = maxf(_joy - delta, 0.0)
	_blink_timer -= delta
	if _blink_timer < -0.12:
		_blink_timer = randf_range(2.0, 5.0)

	match state:
		State.WALK:
			_update_walk(delta)
		State.JUMP, State.FALL:
			_update_airborne(delta)
		State.HELD:
			_update_held(delta)
		State.SLEEP:
			if PetState.energy >= 99.5:
				_wake("Ahh, what a great nap!")
		State.SHOWER:
			_spawn_bubbles()
	if state_duration > 0.0 and state_time >= state_duration:
		_finish_state()

	_update_bubbles(delta)
	_update_ambient_chat(delta)
	_compute_pose()
	_update_speech(delta)
	_fill_voice()
	queue_redraw()


# --- Actions (called by the HUD) ---------------------------------------------

func feed() -> void:
	if not _can_act():
		return
	if PetState.hunger > 90.0:
		say(["I'm stuffed!", "No more, I'll pop!", "Maybe later, I'm full."].pick_random())
		return
	held_item = FOODS.pick_random()
	say(FOOD_LINES[held_item])
	_enter(State.EAT, 3.0)


func play() -> void:
	if not _can_act():
		return
	if PetState.energy < 15.0:
		say("I'm too tired to play...")
		return
	say(["Watch this!", "Keepy-uppy time!", "Ball! BALL!"].pick_random())
	_enter(State.PLAY, 5.0)


func shower() -> void:
	if not _can_act():
		return
	if PetState.hygiene > 95.0:
		say("I'm already squeaky clean!")
		return
	say("Scrub-a-dub-dub!")
	_enter(State.SHOWER, 4.0)


func toggle_sleep() -> void:
	match state:
		State.SLEEP:
			_wake("Ugh, fine, I'm up." if PetState.energy < 50.0 else "Good morning!")
			return
		State.HELD, State.FALL, State.JUMP:
			return
	if _pending == State.SLEEP:
		say("I'm going, I'm going!")
	elif PetState.energy > 85.0:
		say("But I'm not even sleepy!")
	else:
		say("Bedtime? Okay...")
		_walk_to(BED_EXIT_X, State.SLEEP)


## The player typed something to Bob.
func hear(text: String) -> void:
	if state == State.SLEEP:
		say(SLEEP_TALK.pick_random())
		return
	var reply := BobTalk.reply(text)
	PetState.change("fun", 2.0 + float(reply.fun))
	if float(reply.fun) > 0.0:
		_joy = 2.0
	say(reply.text)
	if state not in [State.IDLE, State.WALK, State.WAVE, State.DANCE]:
		return
	match reply.action:
		"dance":
			_enter(State.DANCE, 4.0)
		"jump":
			_jump()
		"wave":
			_enter(State.WAVE, 1.8)
		"come":
			_walk_to(640.0)
		_:
			if state == State.WALK:
				_enter(State.IDLE, 3.0)  # stop and listen


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


# --- State machine -------------------------------------------------------------

func _enter(new_state: State, duration := 0.0) -> void:
	if state == State.EAT and new_state != State.EAT:
		held_item = ""
	state = new_state
	state_time = 0.0
	state_duration = duration
	if new_state != State.WALK:
		_pending = -1


func _finish_state() -> void:
	match state:
		State.IDLE:
			_think()
		State.EAT:
			PetState.change("hunger", 30.0)
			PetState.change("hygiene", -4.0)
			_joy = 2.0
			say(["Delicious!", "Mmm, thanks!", "That hit the spot."].pick_random())
			_enter(State.IDLE, 2.0)
		State.PLAY:
			PetState.change("fun", 30.0)
			PetState.change("energy", -12.0)
			PetState.change("hunger", -6.0)
			PetState.change("hygiene", -8.0)
			_joy = 2.0
			say(["That was fun!", "Again! Again!", "I'm a sports legend."].pick_random())
			_enter(State.IDLE, 2.0)
		State.SHOWER:
			PetState.change("hygiene", 100.0)
			_joy = 2.0
			say("Squeaky clean!")
			_enter(State.IDLE, 2.0)
		_:
			_enter(State.IDLE, randf_range(1.5, 3.5))


## Pick something to do when idle.
func _think() -> void:
	if PetState.energy < 6.0:
		say("I... can't... keep my eyes open...")
		_walk_to(BED_EXIT_X, State.SLEEP)
		return
	var r := randf()
	if r < 0.5:
		var x := randf_range(MIN_X, MAX_X)
		if absf(x - position.x) < 100.0:
			x = clampf(position.x + 200.0 * signf(640.0 - position.x), MIN_X, MAX_X)
		_walk_to(x)
	elif r < 0.62:
		_enter(State.WAVE, 1.6)
	elif r < 0.74 and PetState.happiness() > 60.0:
		_enter(State.DANCE, 3.5)
	elif r < 0.84 and PetState.energy > 30.0:
		_jump()
	else:
		_eye_look = randf_range(-4.0, 4.0)
		_enter(State.IDLE, randf_range(2.0, 5.0))


func _can_act() -> bool:
	match state:
		State.SLEEP:
			say(SLEEP_TALK.pick_random())
			return false
		State.EAT, State.PLAY, State.SHOWER:
			say("Hang on, I'm busy!")
			return false
		State.HELD, State.FALL, State.JUMP:
			return false
	return true


func _walk_to(x: float, then := -1) -> void:
	_target_x = x
	_enter(State.WALK)
	_pending = then


func _update_walk(delta: float) -> void:
	var dx := _target_x - position.x
	if absf(dx) < 3.0:
		position.x = _target_x
		if _pending == State.SLEEP:
			_start_sleeping()
		else:
			_enter(State.IDLE, randf_range(1.5, 4.0))
		return
	var speed := WALK_SPEED * (0.6 if PetState.energy < 25.0 else 1.0)
	facing = signf(dx)
	position.x += signf(dx) * minf(speed * delta, absf(dx))
	_walk_phase += delta * speed / 16.0


func _jump() -> void:
	_vel = Vector2(0, -560)
	_enter(State.JUMP)


func _update_airborne(delta: float) -> void:
	var width := get_viewport_rect().size.x
	_vel.y += GRAVITY * delta
	position += _vel * delta
	if position.x < 50.0 or position.x > width - 50.0:
		position.x = clampf(position.x, 50.0, width - 50.0)
		_vel.x = -_vel.x * 0.5
	if position.y < 200.0:
		position.y = 200.0
		_vel.y = absf(_vel.y) * 0.3
	if position.y >= FLOOR_Y and _vel.y > 0.0:
		position.y = FLOOR_Y
		if state == State.FALL:
			if _vel.y > 1100.0:
				say("OW! Careful with me!")
				PetState.change("fun", -5.0)
			elif _vel.y > 600.0:
				say("Oof!")
			else:
				say("Thanks for the lift.")
		_vel = Vector2.ZERO
		_enter(State.IDLE, randf_range(1.0, 2.5))


func _start_sleeping() -> void:
	position = SLEEP_POS
	facing = 1.0
	PetState.asleep = true
	_enter(State.SLEEP)


func _wake(line: String) -> void:
	PetState.asleep = false
	position = Vector2(BED_EXIT_X, FLOOR_Y)
	facing = 1.0
	_enter(State.IDLE, 2.0)
	say(line)


func _update_ambient_chat(delta: float) -> void:
	if state not in [State.IDLE, State.WALK]:
		return
	_chat_timer -= delta
	if _chat_timer <= 0.0 and not _bubble.visible:
		say(BobTalk.ambient())


# --- Mouse: poke and drag ------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var mouse := get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _hit_test(mouse):
				_pressing = true
				_press_pos = mouse
				get_viewport().set_input_as_handled()
		elif _pressing:
			_pressing = false
			if state == State.HELD:
				_release()
			else:
				_poke()
	elif event is InputEventMouseMotion and _pressing and state != State.HELD:
		if mouse.distance_to(_press_pos) > 12.0:
			_pick_up()


func _hit_test(point: Vector2) -> bool:
	var local := point - position
	if state == State.SLEEP:
		return Rect2(-190, -40, 215, 70).has_point(local)
	return Rect2(-40, -195, 80, 200).has_point(local)


func _poke() -> void:
	if state == State.SLEEP:
		say(SLEEP_TALK.pick_random())
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
	say(POKE_LINES.pick_random())
	if state in [State.IDLE, State.WALK] and randf() < 0.25:
		_jump()


func _pick_up() -> void:
	if state == State.SLEEP:
		PetState.asleep = false
		say("Whoa! I was sleeping!")
	else:
		say(["Whoa!", "Hey, put me down!", "Wheee!", "I'm flying!"].pick_random())
	_throw_vel = Vector2.ZERO
	_enter(State.HELD)


func _update_held(delta: float) -> void:
	var target := get_global_mouse_position() + Vector2(0, HOLD_OFFSET)
	var prev := position
	position = position.lerp(target, minf(1.0, delta * 20.0))
	var v := (position - prev) / maxf(delta, 0.001)
	_throw_vel = _throw_vel.lerp(v, 0.3)
	_swing = lerpf(_swing, clampf(-_throw_vel.x * 0.0015, -1.2, 1.2), 0.15)


func _release() -> void:
	_vel = _throw_vel.limit_length(1600.0)
	if _vel.length() > 700.0:
		say("Wheeeee!")
	_enter(State.FALL)


# --- Pose ----------------------------------------------------------------------

## Direction for a limb angle: 0 = straight down, PI = straight up, positive = forward.
func _dir(angle: float) -> Vector2:
	return Vector2(sin(angle) * facing, cos(angle))


func _compute_pose() -> void:
	var t := state_time
	var lean := 0.0
	var thigh_f := 0.22
	var shin_f := 0.22
	var thigh_b := -0.22
	var shin_b := -0.22
	var arm_f := 0.45 + sin(anim_t * 2.0) * 0.03
	var fore_f := 0.3
	var arm_b := -0.45 - sin(anim_t * 2.0) * 0.03
	var fore_b := -0.3

	match state:
		State.WALK:
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
		State.WAVE:
			arm_f = PI * 0.8
			fore_f = PI + sin(t * 12.0) * 0.4
		State.DANCE:
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
		State.JUMP, State.FALL:
			var flail := sin(anim_t * 20.0) * 0.3 if state == State.FALL else 0.0
			thigh_f = 0.7
			shin_f = -0.3
			thigh_b = 0.3
			shin_b = -0.6
			arm_f = PI * 0.8 + flail
			fore_f = PI * 0.9 - flail
			arm_b = -PI * 0.8 - flail
			fore_b = -PI * 0.9 + flail
		State.HELD:
			var flail := sin(anim_t * 15.0) * 0.4
			thigh_f = _swing * 0.8 + 0.1
			shin_f = _swing * 1.1
			thigh_b = _swing * 0.8 - 0.1
			shin_b = _swing * 1.1 - 0.1
			arm_f = PI * 0.7 + flail
			fore_f = PI * 0.8 - flail
			arm_b = -PI * 0.7 - flail
			fore_b = -PI * 0.8 + flail
		State.EAT:
			arm_f = 0.9
			fore_f = 2.8 + sin(t * 8.0) * 0.15
		State.PLAY:
			arm_f = PI * 0.62
			fore_f = PI * 0.78
			arm_b = -PI * 0.62
			fore_b = -PI * 0.78
		State.SHOWER:
			arm_f = 0.9 + sin(t * 14.0) * 0.35
			fore_f = 2.3 + sin(t * 14.0 + 1.0) * 0.5
			arm_b = 1.2 + sin(t * 12.0 + 2.0) * 0.4
			fore_b = 2.0 + sin(t * 12.0 + 3.0) * 0.4
		State.SLEEP:
			thigh_f = 0.0
			shin_f = 0.0
			thigh_b = 0.0
			shin_b = 0.0
			arm_f = 0.08
			fore_f = 0.08
			arm_b = -0.08
			fore_b = -0.08

	# Plant the lowest foot on the ground.
	var ext_f := THIGH * cos(thigh_f) + SHIN * cos(shin_f)
	var ext_b := THIGH * cos(thigh_b) + SHIN * cos(shin_b)
	_hip = Vector2(0, -maxf(ext_f, ext_b))
	_up = _dir(PI - lean)
	var breathe := sin(anim_t * 2.0) * 1.2
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


## Converts a pose point to drawing space (Bob lies down when sleeping).
func _to_draw(v: Vector2) -> Vector2:
	return Vector2(v.y, -v.x) if state == State.SLEEP else v


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var sleeping := state == State.SLEEP
	if not sleeping:
		_draw_shadow()
	if state == State.SHOWER:
		_draw_shower_water()

	if sleeping:
		draw_set_transform(Vector2.ZERO, -PI / 2.0)
	_draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if sleeping:
		_draw_blanket()
		_draw_zzz()
	elif PetState.hygiene < 35.0:
		_draw_stink()
	if state == State.PLAY:
		_draw_ball()
	if held_item != "":
		_draw_food(held_item, _hand_f + Vector2(4.0 * facing, -4.0), 1.0 - 0.75 * state_time / maxf(state_duration, 0.01))
	_draw_soap_bubbles()
	_draw_speech_tail()


func _draw_body() -> void:
	# Back limbs first, in a lighter ink for depth.
	_seg(_shoulder, _elbow_b, BACK_INK)
	_seg(_elbow_b, _hand_b, BACK_INK)
	_seg(_hip, _knee_b, BACK_INK)
	_seg(_knee_b, _foot_b, BACK_INK)
	_draw_foot(_foot_b, BACK_INK)

	_seg(_hip, _neck, INK)
	if PetState.hygiene < 55.0:
		for f in [0.3, 0.55, 0.8]:
			draw_circle(_hip.lerp(_neck, f) + Vector2(3.0 * facing, 0), 3.5, Color(0.45, 0.33, 0.2, 0.8))

	_seg(_hip, _knee_f, INK)
	_seg(_knee_f, _foot_f, INK)
	_draw_foot(_foot_f, INK)

	draw_circle(_head, HEAD_R, HEAD_FILL)
	draw_arc(_head, HEAD_R, 0.0, TAU, 48, INK, LINE_W, true)
	for k in [-0.35, 0.0, 0.35]:
		var root := _head + _up * HEAD_R
		draw_line(root, root + _dir(PI + k) * 13.0, INK, 3.0, true)
	_draw_face()

	_seg(_shoulder, _elbow_f, INK)
	_seg(_elbow_f, _hand_f, INK)


func _seg(a: Vector2, b: Vector2, color: Color) -> void:
	draw_line(a, b, color, LINE_W, true)
	draw_circle(a, LINE_W * 0.5, color)
	draw_circle(b, LINE_W * 0.5, color)


func _draw_foot(foot: Vector2, color: Color) -> void:
	draw_line(foot, foot + Vector2(8.0 * facing, 0), color, LINE_W, true)


func _draw_face() -> void:
	var look := 5.0 * facing + _eye_look
	var eye_l := _head + Vector2(look - 8.0, -3.0)
	var eye_r := _head + Vector2(look + 8.0, -3.0)
	var mouth := _head + Vector2(look * 0.8, 10.0)
	var happy := _joy > 0.0 or state in [State.DANCE, State.PLAY]
	var surprised := state in [State.HELD, State.FALL]

	# Eyes
	for e in [eye_l, eye_r]:
		if state == State.SLEEP or (_blink_timer < 0.0 and not surprised):
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
	if PetState.hygiene < 30.0 and state != State.SLEEP:
		draw_circle(_head + Vector2(-look - 10.0, 6.0), 3.0, Color(0.45, 0.33, 0.2, 0.7))

	# Mouth
	var mood := PetState.happiness()
	if state == State.SLEEP:
		draw_arc(mouth, 2.5 + sin(anim_t * 1.5), 0.0, TAU, 12, INK, 2.0, true)
	elif state == State.EAT:
		draw_circle(mouth, 2.0 + absf(sin(state_time * 10.0)) * 4.0, INK)
	elif surprised:
		draw_arc(mouth, 5.0, 0.0, TAU, 16, INK, 2.5, true)
	elif happy or mood > 65.0:
		draw_arc(mouth + Vector2(0, -5), 8.0, 0.4, PI - 0.4, 12, INK, 3.0, true)
	elif mood > 35.0:
		draw_line(mouth - Vector2(6, 0), mouth + Vector2(6, 0), INK, 3.0, true)
	else:
		draw_arc(mouth + Vector2(0, 7), 8.0, PI + 0.5, TAU - 0.5, 12, INK, 3.0, true)


func _draw_shadow() -> void:
	var height := FLOOR_Y - position.y
	var s := clampf(1.0 - height / 400.0, 0.3, 1.0)
	draw_set_transform(Vector2(0, height), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 34.0 * s, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_blanket() -> void:
	var top := -16.0 + sin(anim_t * 1.5) * 2.0
	var rect := Rect2(-128, top, 142, 42 - top - 16.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#7fa7d9")
	box.border_color = INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	draw_style_box(box, rect)
	draw_rect(Rect2(-125, top + 3, 20, rect.size.y - 6), Color("#a9c6ea"))
	for x in [-90.0, -60.0, -30.0]:
		draw_line(Vector2(x, top + 4), Vector2(x, rect.end.y - 4), Color("#6a92c4"), 3.0)


func _draw_zzz() -> void:
	var font := ThemeDB.fallback_font
	var head := _to_draw(_head)
	for i in 3:
		var k := fmod(anim_t * 0.4 + i / 3.0, 1.0)
		var pos := head + Vector2(10.0 + k * 45.0, -30.0 - k * 80.0)
		draw_string(font, pos, "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 + k * 20), Color(INK, 1.0 - k))


func _draw_stink() -> void:
	for i in 3:
		var base := Vector2(-38.0 + i * 38.0, -120.0 + (i % 2) * 30.0)
		var rise := fmod(anim_t * 25.0 + i * 20.0, 40.0)
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(Vector2(base.x + sin(anim_t * 4.0 + k + i) * 4.0, base.y - rise - k * 6.0))
		draw_polyline(pts, Color(0.45, 0.6, 0.2, 0.8), 2.5, true)


func _draw_ball() -> void:
	var height := absf(sin(state_time * 4.5)) * 90.0
	var pos := _head + _up * (HEAD_R + 14.0 + height)
	draw_circle(pos, 14.0, Color("#e25d4f"))
	draw_arc(pos, 14.0, 0.0, TAU, 24, INK, 3.0, true)
	draw_arc(pos, 9.0, PI + 0.3, PI + 1.3, 8, Color(1, 1, 1, 0.8), 3.0, true)


func _draw_food(item: String, pos: Vector2, s: float) -> void:
	s = maxf(s, 0.2)
	match item:
		"apple":
			draw_circle(pos, 11.0 * s, Color("#d94343"))
			draw_arc(pos, 11.0 * s, 0.0, TAU, 20, INK, 2.0, true)
			draw_line(pos + Vector2(0, -10 * s), pos + Vector2(2, -16 * s), Color("#5a3a1a"), 2.5)
			draw_circle(pos + Vector2(5, -14 * s), 3.0 * s, Color("#5cb85c"))
		"pizza":
			var pts := PackedVector2Array([pos + Vector2(-12, -10) * s, pos + Vector2(12, -10) * s, pos + Vector2(0, 14) * s])
			draw_colored_polygon(pts, Color("#f5c542"))
			draw_line(pts[0], pts[1], Color("#c98a3a"), 5.0 * s)
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), INK, 2.0, true)
			draw_circle(pos + Vector2(-3, -3) * s, 2.5 * s, Color("#c0392b"))
			draw_circle(pos + Vector2(4, 1) * s, 2.5 * s, Color("#c0392b"))
		"burger":
			draw_rect(Rect2(pos + Vector2(-12, -9) * s, Vector2(24, 7) * s), Color("#d9a15b"))
			draw_rect(Rect2(pos + Vector2(-13, -2) * s, Vector2(26, 3) * s), Color("#6ab04c"))
			draw_rect(Rect2(pos + Vector2(-12, 1) * s, Vector2(24, 5) * s), Color("#6b3e26"))
			draw_rect(Rect2(pos + Vector2(-12, 6) * s, Vector2(24, 5) * s), Color("#d9a15b"))
		"donut":
			draw_circle(pos, 12.0 * s, Color("#e8a0c0"))
			draw_arc(pos, 12.0 * s, 0.0, TAU, 20, INK, 2.0, true)
			draw_circle(pos, 4.0 * s, Color("#f4ecd8"))
			draw_arc(pos, 4.0 * s, 0.0, TAU, 12, INK, 2.0, true)


func _draw_shower_water() -> void:
	var head_y := -260.0
	draw_line(Vector2(-60, head_y - 60), Vector2(0, head_y - 60), Color("#9aa3ad"), 6.0)
	draw_line(Vector2(0, head_y - 60), Vector2(0, head_y), Color("#9aa3ad"), 6.0)
	draw_rect(Rect2(-24, head_y, 48, 10), Color("#9aa3ad"))
	for i in 10:
		var x := -26.0 + i * 5.8
		var y := head_y + 12.0 + fmod(state_time * 420.0 + i * 53.0, 245.0)
		draw_line(Vector2(x, y), Vector2(x, y + 12), Color(0.4, 0.7, 1.0, 0.8), 2.0)


func _spawn_bubbles() -> void:
	if randf() < 0.5:
		_bubbles.append({
			"pos": Vector2(randf_range(-30, 30), randf_range(-170, -40)),
			"vel": Vector2(randf_range(-20, 20), randf_range(-50, -20)),
			"r": randf_range(4, 10),
			"life": randf_range(0.8, 1.6),
		})


func _update_bubbles(delta: float) -> void:
	for b in _bubbles:
		b.pos += b.vel * delta
		b.life -= delta
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool: return b.life > 0.0)


func _draw_soap_bubbles() -> void:
	for b in _bubbles:
		var alpha := clampf(float(b.life), 0.0, 1.0)
		draw_arc(b.pos, b.r, 0.0, TAU, 16, Color(0.5, 0.75, 1.0, alpha), 2.0, true)
		draw_circle(b.pos + Vector2(-b.r * 0.35, -b.r * 0.35), b.r * 0.2, Color(1, 1, 1, alpha))


# --- Speech bubble and voice ----------------------------------------------------

func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color.WHITE
	box.border_color = INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(10)
	_bubble.add_theme_stylebox_override("panel", box)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_label.add_theme_color_override("font_color", INK)
	_label.add_theme_font_size_override("font_size", BUBBLE_FONT_SIZE)
	_bubble.add_child(_label)
	_bubble.visible = false
	add_child(_bubble)


func _update_speech(delta: float) -> void:
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
	# Float above Bob's head, but stay on screen.
	_bubble.reset_size()  # shrink-wrap once the wrapped label has settled
	var screen := get_viewport_rect().size
	var size := _bubble.size
	var pos := position + _head_top() + Vector2(-size.x / 2.0, -size.y - 24.0)
	pos.x = clampf(pos.x, 8.0, screen.x - size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, screen.y - size.y - 8.0)
	_bubble.position = pos - position


func _head_top() -> Vector2:
	return _to_draw(_head + _up * HEAD_R)


func _draw_speech_tail() -> void:
	if not _bubble.visible:
		return
	var tip := _head_top() + Vector2(0, -8)
	var bottom := _bubble.position.y + _bubble.size.y - 3.0
	if tip.y < bottom + 4.0:
		return
	var base_x := clampf(tip.x, _bubble.position.x + 22.0, _bubble.position.x + _bubble.size.x - 22.0)
	var a := Vector2(base_x - 9.0, bottom)
	var b := Vector2(base_x + 9.0, bottom)
	draw_colored_polygon(PackedVector2Array([a, b, tip]), Color.WHITE)
	draw_line(a, tip, INK, 3.0, true)
	draw_line(b, tip, INK, 3.0, true)


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


## Start one little "voice" blip. Happier Bob talks in a higher voice.
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
