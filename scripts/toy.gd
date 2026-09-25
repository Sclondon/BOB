extends RigidBody2D
## A physics toy dropped into Bob's room. Call setup() before adding it to the tree.

const Sketch := preload("res://scripts/sketch.gd")

var kind := "ball"
var food := ""  # which snack this is, for kind == "snack"
var radius := 22.0  # rough size, used by Bob to judge reach
var last_played := -100.0  # Time in seconds when Bob last kicked it


func setup(new_kind: String) -> void:
	kind = new_kind
	var material := PhysicsMaterial.new()
	var shape: Shape2D
	match kind:
		"ball":
			shape = _circle(22.0)
			mass = 0.6
			material.bounce = 0.75
			material.friction = 0.5
		"beachball":
			shape = _circle(42.0)
			mass = 0.3
			material.bounce = 0.65
			linear_damp = 0.6
			angular_damp = 0.6
		"crate":
			var box := RectangleShape2D.new()
			box.size = Vector2(72, 72)
			shape = box
			radius = 36.0
			mass = 2.5
			material.friction = 0.9
			material.bounce = 0.05
		"duck":
			shape = _circle(26.0)
			mass = 0.5
			material.bounce = 0.35
		"balloon":
			shape = _circle(32.0)
			mass = 0.12
			gravity_scale = -0.35  # floats "up", whichever way up currently is
			linear_damp = 1.5
			angular_damp = 2.0
			material.bounce = 0.5
		"anvil":
			var block := RectangleShape2D.new()
			block.size = Vector2(90, 60)
			shape = block
			radius = 45.0
			mass = 14.0
			material.friction = 1.0
			material.bounce = 0.0
		"snack":
			shape = _circle(20.0)
			food = Sketch.FOODS.pick_random()
			mass = 0.3
			material.bounce = 0.2
			add_to_group("food")
	physics_material_override = material
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	can_sleep = false  # gravity turns with the phone, so nothing may doze off
	add_to_group("toys")


func _circle(r: float) -> CircleShape2D:
	var circle := CircleShape2D.new()
	circle.radius = r
	radius = r
	return circle


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var down := Motion.gravity_dir.rotated(-global_rotation)
	Sketch.toy(self, kind, food, Sketch.boil() + get_instance_id() % 3, down)
