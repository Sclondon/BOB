extends RefCounted
## Hand-drawn line helpers and the toy drawings, shared by the room, the toys,
## the toy tray and the drag preview. Lines "boil" (wobble a little a few
## times a second) like a pencil animation.

const INK := Color(0.08, 0.08, 0.1)
const PAPER := Color("#fbfbf8")
const W := 4.0

const TOYS := ["ball", "beachball", "crate", "duck", "balloon", "anvil", "snack"]
const TOY_NAMES := {
	"ball": "Ball",
	"beachball": "Beach Ball",
	"crate": "Crate",
	"duck": "Duck",
	"balloon": "Balloon",
	"anvil": "Anvil",
	"snack": "Snack",
}
const FOODS := ["apple", "pizza", "donut", "burger"]


## Changes ~8 times a second; feed it to the helpers below for the wobble.
static func boil() -> int:
	return int(Time.get_ticks_msec() / 125) % 4


static func _wobble(p: Vector2, i: int, seed: int, amount := 1.0) -> Vector2:
	var k := float(seed * 7 + i * 13)
	return p + Vector2(sin(k * 1.7), cos(k * 2.3)) * amount


static func line(ci: CanvasItem, a: Vector2, b: Vector2, seed: int, width := W, color := INK) -> void:
	var mid := (a + b) / 2.0 + (b - a).orthogonal().normalized() * sin(float(seed) * 2.1 + a.x * 0.01) * 1.3
	ci.draw_polyline(PackedVector2Array([_wobble(a, 1, seed, 0.6), mid, _wobble(b, 2, seed, 0.6)]), color, width, true)


static func circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, seed: int, width := W) -> void:
	ci.draw_circle(c, r, fill)
	var pts := PackedVector2Array()
	var n := 30
	for i in n + 1:
		var a := TAU * i / n
		var j := sin(a * 3.0 + seed * 1.7) * 0.8 + sin(a * 5.0 + seed * 2.9) * 0.5
		pts.append(c + Vector2.from_angle(a) * (r + j))
	ci.draw_polyline(pts, INK, width, true)


static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, seed: int, width := W) -> void:
	ci.draw_colored_polygon(pts, fill)
	var outline := PackedVector2Array()
	for i in pts.size() + 1:
		outline.append(_wobble(pts[i % pts.size()], i % pts.size(), seed, 0.7))
	ci.draw_polyline(outline, INK, width, true)


static func rect(ci: CanvasItem, r: Rect2, fill: Color, seed: int, width := W) -> void:
	poly(ci, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), fill, seed, width)


## Draws a toy centred on the origin. `down` is the local direction gravity
## pulls (the balloon's string hangs that way).
static func toy(ci: CanvasItem, kind: String, food: String, seed: int, down := Vector2.DOWN) -> void:
	match kind:
		"ball":
			circle(ci, Vector2.ZERO, 22.0, Color("#e4574a"), seed)
			ci.draw_arc(Vector2.ZERO, 14.0, PI + 0.4, PI + 1.4, 8, Color(1, 1, 1, 0.8), 4.0, true)
		"beachball":
			ci.draw_circle(Vector2.ZERO, 42.0, Color.WHITE)
			for i in 3:
				var a0 := TAU * i / 3.0
				var wedge := PackedVector2Array([Vector2.ZERO])
				for k in 9:
					wedge.append(Vector2.from_angle(a0 + k * (PI / 3.0) / 8.0) * 42.0)
				ci.draw_colored_polygon(wedge, [Color("#f06e5b"), Color("#f7c948"), Color("#4fa3e0")][i])
			circle(ci, Vector2.ZERO, 42.0, Color(0, 0, 0, 0), seed)
			circle(ci, Vector2.ZERO, 8.0, Color.WHITE, seed, 3.0)
		"crate":
			rect(ci, Rect2(-36, -36, 72, 72), Color("#e8c28f"), seed)
			line(ci, Vector2(-36, -36), Vector2(36, 36), seed, 3.0)
			line(ci, Vector2(-36, 36), Vector2(36, -36), seed + 1, 3.0)
			line(ci, Vector2(-36, -24), Vector2(36, -24), seed + 2, 3.0)
			line(ci, Vector2(-36, 24), Vector2(36, 24), seed + 3, 3.0)
		"duck":
			circle(ci, Vector2(-2, 6), 22.0, Color("#ffd23f"), seed)
			circle(ci, Vector2(12, -16), 13.0, Color("#ffd23f"), seed)
			poly(ci, PackedVector2Array([Vector2(22, -18), Vector2(34, -14), Vector2(22, -10)]), Color("#f28c28"), seed, 3.0)
			ci.draw_circle(Vector2(15, -19), 2.5, INK)
			ci.draw_arc(Vector2(-4, 6), 11.0, 0.2, 1.6, 8, INK, 3.0, true)
		"balloon":
			var knot := Vector2(0, 38)
			var s := PackedVector2Array()
			var dir := down.normalized()
			for k in 8:
				var t := k / 7.0
				s.append(knot + dir * t * 70.0 + dir.orthogonal() * sin(t * 6.0 + seed) * 5.0)
			ci.draw_polyline(s, INK, 2.0, true)
			var oval := PackedVector2Array()
			for k in 28:
				var a := TAU * k / 28.0
				oval.append(Vector2(cos(a) * 30.0, sin(a) * 36.0))
			poly(ci, oval, Color("#ec5f8c"), seed)
			poly(ci, PackedVector2Array([Vector2(-5, 38), Vector2(5, 38), Vector2(0, 33)]), Color("#ec5f8c"), seed, 2.0)
			ci.draw_arc(Vector2(-10, -14), 9.0, PI + 0.3, PI + 1.3, 8, Color(1, 1, 1, 0.7), 4.0, true)
		"anvil":
			var body := PackedVector2Array([
				Vector2(-58, -30), Vector2(46, -30), Vector2(46, -14), Vector2(24, -4),
				Vector2(24, 14), Vector2(40, 30), Vector2(-40, 30), Vector2(-24, 14),
				Vector2(-24, -4), Vector2(-40, -12),
			])
			poly(ci, body, Color("#5d6168"), seed)
			line(ci, Vector2(-50, -24), Vector2(40, -24), seed, 2.0, Color(1, 1, 1, 0.35))
		"snack":
			food_item(ci, food if food != "" else "apple", Vector2.ZERO, 1.7, seed)


## Food drawn at `pos`, `s` times its base size (base ~24px across).
static func food_item(ci: CanvasItem, item: String, pos: Vector2, s: float, seed := 0) -> void:
	match item:
		"apple":
			circle(ci, pos, 11.0 * s, Color("#d94343"), seed, 3.0)
			ci.draw_line(pos + Vector2(0, -10) * s, pos + Vector2(2, -16) * s, Color("#5a3a1a"), 3.0)
			ci.draw_circle(pos + Vector2(5, -14) * s, 3.0 * s, Color("#5cb85c"))
		"pizza":
			var pts := PackedVector2Array([pos + Vector2(-12, -10) * s, pos + Vector2(12, -10) * s, pos + Vector2(0, 14) * s])
			poly(ci, pts, Color("#f5c542"), seed, 3.0)
			ci.draw_line(pts[0], pts[1], Color("#c98a3a"), 4.0 * s)
			ci.draw_circle(pos + Vector2(-3, -3) * s, 2.5 * s, Color("#c0392b"))
			ci.draw_circle(pos + Vector2(4, 1) * s, 2.5 * s, Color("#c0392b"))
		"burger":
			rect(ci, Rect2(pos + Vector2(-12, -10) * s, Vector2(24, 8) * s), Color("#d9a15b"), seed, 2.5)
			ci.draw_rect(Rect2(pos + Vector2(-13, -2) * s, Vector2(26, 3) * s), Color("#6ab04c"))
			rect(ci, Rect2(pos + Vector2(-12, 1) * s, Vector2(24, 5) * s), Color("#6b3e26"), seed, 2.5)
			rect(ci, Rect2(pos + Vector2(-12, 6) * s, Vector2(24, 5) * s), Color("#d9a15b"), seed, 2.5)
		"donut":
			circle(ci, pos, 12.0 * s, Color("#e8a0c0"), seed, 3.0)
			circle(ci, pos, 4.0 * s, PAPER, seed, 3.0)
