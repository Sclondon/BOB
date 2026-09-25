extends Node
## Plays a short scripted scene so the arcade attract video can be recorded:
##
##   godot --path . --write-movie attract.avi --fixed-fps 30 --quit-after 600 -- --autopilot
##
## main.gd adds this node when it sees --autopilot. The movie maker has no
## real phone, so this drops toys and tilts and shakes the room directly.

var main: Node
var time := 0.0
var _beats := [
	[1.2, "drop", "ball"],
	[3.4, "drop", "duck"],
	[5.0, "drop", "crate"],
	[7.2, "tilt", -0.8],
	[9.4, "tilt", 0.0],
	[11.0, "shake", Vector2(-24, -14)],
	[13.6, "drop", "snack"],
	[14.2, "drop", "balloon"],
]


func _ready() -> void:
	main = get_parent()


func _physics_process(delta: float) -> void:
	time += delta
	while not _beats.is_empty() and time >= _beats[0][0]:
		var beat: Array = _beats.pop_front()
		match beat[1]:
			"drop":
				main.spawn_toy(beat[2], main._drop_point(), Vector2.ZERO)
			"tilt":
				Motion._key_angle = beat[2]
			"shake":
				Motion.shake(beat[2])
