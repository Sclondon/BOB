extends Node
## Plays a short scripted scene so the arcade attract video can be recorded:
##
##   godot --path . --write-movie attract.avi --fixed-fps 30 --quit-after 540 -- --autopilot
##
## main.gd adds this node when it sees --autopilot. The movie maker has no real
## mouse or keyboard, so this types into the chat box and presses the HUD
## actions by calling the same functions the buttons do.

const CHAT := "hi bob! can you dance?"
const TYPE_START := 2.6
const TYPE_SPEED := 14.0  # characters per second

var main: Node
var bob: Node2D
var hud: CanvasLayer
var time := 0.0
var _step := 0


func _ready() -> void:
	main = get_parent()
	bob = main.get_node("Bob")
	hud = main.get_node("HUD")


func _process(delta: float) -> void:
	time += delta
	# Keep Bob standing still between beats instead of wandering off.
	if bob.state == 0:
		bob.state_duration = 999.0

	var typed := clampi(int((time - TYPE_START) * TYPE_SPEED), 0, CHAT.length())
	if _step == 0 and time >= TYPE_START:
		hud._chat_input.text = CHAT.left(typed)
		if typed == CHAT.length() and time >= TYPE_START + CHAT.length() / TYPE_SPEED + 0.3:
			hud._send(CHAT)
			_step = 1
	elif _step == 1 and time >= 8.8:
		bob.feed()
		_step = 2
	elif _step == 2 and time >= 12.2:
		bob.play()
		_step = 3
