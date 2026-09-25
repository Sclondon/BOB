extends Node2D
## Wires the HUD to Bob and dims the lights while he sleeps.

const NIGHT_TINT := Color(0.42, 0.42, 0.62)

@onready var bob: Node2D = $Bob
@onready var hud: CanvasLayer = $HUD
@onready var lights: CanvasModulate = $Lights

var _lights_off := false


func _ready() -> void:
	hud.action_requested.connect(_on_action_requested)
	hud.message_sent.connect(bob.hear)
	if PetState.autopilot:
		add_child(preload("res://tools/autopilot.gd").new())


func _process(_delta: float) -> void:
	if PetState.asleep != _lights_off:
		_lights_off = PetState.asleep
		create_tween().tween_property(lights, "color", NIGHT_TINT if _lights_off else Color.WHITE, 1.2)


func _on_action_requested(action: String) -> void:
	match action:
		"feed":
			bob.feed()
		"play":
			bob.play()
		"clean":
			bob.shower()
		"sleep":
			bob.toggle_sleep()
