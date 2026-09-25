extends StaticBody2D
## Bob's room: an empty white box that fills the screen above the toy tray,
## outlined in heavy pencil with hatched grey beyond the walls.

const Sketch := preload("res://scripts/sketch.gd")

const BOTTOM_INSET := 150.0  # room for the toy tray under the floor
const SIDE_INSET := 12.0
const TOP_INSET := 12.0
const WALL_THICKNESS := 400.0
const OUTSIDE := Color("#ebebe6")
const HATCH := Color("#d3d3cc")

## The open floor space, in canvas coordinates.
var inner := Rect2()

var _walls: Array[CollisionShape2D] = []


func _ready() -> void:
	for i in 4:
		var wall := CollisionShape2D.new()
		wall.shape = RectangleShape2D.new()
		add_child(wall)
		_walls.append(wall)
	var material := PhysicsMaterial.new()
	material.friction = 0.8
	physics_material_override = material
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()


func _process(_delta: float) -> void:
	queue_redraw()  # for the pencil boil


func _rebuild() -> void:
	var size := get_viewport_rect().size
	inner = Rect2(SIDE_INSET, TOP_INSET, size.x - SIDE_INSET * 2.0, size.y - TOP_INSET - BOTTOM_INSET)
	var t := WALL_THICKNESS
	var wide := size.x + t * 2.0
	var tall := size.y + t * 2.0
	_place(_walls[0], Vector2(inner.get_center().x, inner.end.y + t / 2.0), Vector2(wide, t))  # floor
	_place(_walls[1], Vector2(inner.get_center().x, inner.position.y - t / 2.0), Vector2(wide, t))  # ceiling
	_place(_walls[2], Vector2(inner.position.x - t / 2.0, inner.get_center().y), Vector2(t, tall))  # left
	_place(_walls[3], Vector2(inner.end.x + t / 2.0, inner.get_center().y), Vector2(t, tall))  # right


func _place(wall: CollisionShape2D, center: Vector2, extents: Vector2) -> void:
	wall.position = center
	(wall.shape as RectangleShape2D).size = extents


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), OUTSIDE)
	# Diagonal hatching beyond the walls
	var step := 22.0
	var x := -size.y
	while x < size.x:
		draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), HATCH, 2.0)
		x += step
	draw_rect(inner, Sketch.PAPER)

	var seed := Sketch.boil()
	var r := inner
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		# Overshoot each edge a little, like a quick pencil box.
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var dir := (b - a).normalized()
		Sketch.line(self, a - dir * 6.0, b + dir * 6.0, seed + i, 7.0 if i == 2 else 5.0)
