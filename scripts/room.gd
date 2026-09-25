extends Node2D
## Bob's room: wall, floor, bed, a window whose sky follows your real clock,
## a working wall clock, a self-portrait and a plant.

const FLOOR_Y := 600.0
const INK := Color(0.1, 0.1, 0.12)
const WOOD := Color("#a8744a")

var _redraw_timer := 0.0


func _process(delta: float) -> void:
	_redraw_timer += delta
	if _redraw_timer >= 0.5:
		_redraw_timer = 0.0
		queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	# Wall, wainscot and floor
	draw_rect(Rect2(0, 0, size.x, FLOOR_Y), Color("#f4ecd8"))
	draw_rect(Rect2(0, 470, size.x, FLOOR_Y - 470), Color("#e6dcc3"))
	draw_line(Vector2(0, 470), Vector2(size.x, 470), Color("#cbbd9c"), 4.0)
	draw_rect(Rect2(0, FLOOR_Y, size.x, size.y - FLOOR_Y), Color("#c89a6a"))
	for i in 4:
		var y := FLOOR_Y + 30.0 * (i + 1)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color("#b0845a"), 2.0)
		var offset := 90.0 if i % 2 == 0 else 0.0
		for x in range(int(offset), int(size.x), 180):
			draw_line(Vector2(x, y - 30), Vector2(x, y), Color("#b0845a"), 2.0)
	draw_rect(Rect2(0, FLOOR_Y - 12, size.x, 12), Color("#fbf7ee"))
	draw_line(Vector2(0, FLOOR_Y), Vector2(size.x, FLOOR_Y), INK, 3.0)

	_draw_rug(Vector2(700, 660))
	_draw_window(Rect2(540, 110, 220, 180))
	_draw_portrait(Rect2(820, 140, 100, 120))
	_draw_clock(Vector2(1060, 190), 46.0)
	_draw_bed()
	_draw_plant(Vector2(1210, FLOOR_Y))


func _box(rect: Rect2, fill: Color, radius := 6, border := 3) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = INK
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)


func _draw_rug(center: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, 0.18))
	draw_circle(Vector2.ZERO, 250.0, Color("#b85c5c"))
	draw_circle(Vector2.ZERO, 210.0, Color("#d98080"))
	draw_circle(Vector2.ZERO, 120.0, Color("#b85c5c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_window(rect: Rect2) -> void:
	var t := Time.get_time_dict_from_system()
	var hour: float = t["hour"] + t["minute"] / 60.0
	var sky := _sky_color(hour)
	draw_rect(rect, sky)
	var is_night := hour < 6.0 or hour >= 20.0
	if is_night:
		for star in [Vector2(30, 30), Vector2(90, 55), Vector2(160, 25), Vector2(190, 90), Vector2(60, 120), Vector2(130, 140)]:
			draw_circle(rect.position + star, 2.0, Color(1, 1, 0.85, 0.9))
		draw_circle(rect.position + Vector2(165, 50), 20.0, Color("#f7f3d6"))
		draw_circle(rect.position + Vector2(175, 43), 17.0, sky)
	else:
		draw_circle(rect.position + Vector2(170, 45), 22.0, Color("#ffd84d"))
		var drift := fmod(Time.get_ticks_msec() / 1000.0 * 4.0, rect.size.x + 80.0) - 40.0
		for c in [Vector2(0, 0), Vector2(18, -8), Vector2(34, 0)]:
			var p := rect.position + Vector2(clampf(drift + c.x, 16.0, rect.size.x - 16.0), 110.0 + c.y)
			draw_circle(p, 16.0, Color(1, 1, 1, 0.9))
	# Frame, cross bars and sill
	draw_rect(rect, INK, false, 6.0)
	draw_line(rect.get_center() - Vector2(0, rect.size.y / 2), rect.get_center() + Vector2(0, rect.size.y / 2), INK, 5.0)
	draw_line(rect.get_center() - Vector2(rect.size.x / 2, 0), rect.get_center() + Vector2(rect.size.x / 2, 0), INK, 5.0)
	_box(Rect2(rect.position.x - 16, rect.end.y, rect.size.x + 32, 14), Color("#fbf7ee"), 3)
	# Curtains
	var curtain := Color("#d1605a")
	var l := rect.position.x
	var r := rect.end.x
	var top := rect.position.y - 14
	draw_colored_polygon(PackedVector2Array([Vector2(l - 30, top), Vector2(l + 30, top), Vector2(l - 5, rect.end.y + 30), Vector2(l - 38, rect.end.y + 30)]), curtain)
	draw_colored_polygon(PackedVector2Array([Vector2(r - 30, top), Vector2(r + 30, top), Vector2(r + 38, rect.end.y + 30), Vector2(r + 5, rect.end.y + 30)]), curtain)
	draw_line(Vector2(l - 50, top), Vector2(r + 50, top), INK, 5.0)


func _sky_color(hour: float) -> Color:
	var night := Color("#1b2346")
	var dusk := Color("#f39c6b")
	var day := Color("#8fd0f5")
	if hour < 5.0 or hour >= 21.0:
		return night
	if hour < 6.5:
		return night.lerp(dusk, (hour - 5.0) / 1.5)
	if hour < 8.0:
		return dusk.lerp(day, (hour - 6.5) / 1.5)
	if hour < 17.5:
		return day
	if hour < 19.0:
		return day.lerp(dusk, (hour - 17.5) / 1.5)
	return dusk.lerp(night, (hour - 19.0) / 2.0)


func _draw_clock(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color.WHITE)
	draw_arc(center, radius, 0.0, TAU, 48, INK, 5.0, true)
	for i in 12:
		var a := TAU * i / 12.0
		var d := Vector2(sin(a), -cos(a))
		draw_line(center + d * (radius - 10), center + d * (radius - 4), INK, 3.0 if i % 3 == 0 else 1.5)
	var t := Time.get_time_dict_from_system()
	var hour_a: float = TAU * (float(t["hour"] % 12) + t["minute"] / 60.0) / 12.0
	var min_a: float = TAU * (t["minute"] + t["second"] / 60.0) / 60.0
	var sec_a: float = TAU * t["second"] / 60.0
	draw_line(center, center + Vector2(sin(hour_a), -cos(hour_a)) * radius * 0.5, INK, 5.0, true)
	draw_line(center, center + Vector2(sin(min_a), -cos(min_a)) * radius * 0.75, INK, 3.0, true)
	draw_line(center, center + Vector2(sin(sec_a), -cos(sec_a)) * radius * 0.8, Color("#d1605a"), 1.5, true)
	draw_circle(center, 4.0, INK)


func _draw_portrait(rect: Rect2) -> void:
	_box(rect.grow(8), WOOD, 4)
	_box(rect, Color("#fffaf0"), 2, 2)
	# A tiny self-portrait of Bob
	var c := rect.get_center() + Vector2(0, -22)
	draw_circle(c, 14.0, Color.WHITE)
	draw_arc(c, 14.0, 0.0, TAU, 24, INK, 3.0, true)
	draw_circle(c + Vector2(-5, -2), 2.0, INK)
	draw_circle(c + Vector2(5, -2), 2.0, INK)
	draw_arc(c + Vector2(0, 2), 6.0, 0.4, PI - 0.4, 10, INK, 2.0, true)
	var hip := c + Vector2(0, 50)
	draw_line(c + Vector2(0, 14), hip, INK, 3.0)
	draw_line(c + Vector2(0, 24), c + Vector2(-18, 10), INK, 3.0)
	draw_line(c + Vector2(0, 24), c + Vector2(18, 10), INK, 3.0)
	draw_line(hip, hip + Vector2(-12, 20), INK, 3.0)
	draw_line(hip, hip + Vector2(12, 20), INK, 3.0)


func _draw_bed() -> void:
	_box(Rect2(40, 430, 22, 170), WOOD, 4)  # headboard
	_box(Rect2(50, 560, 14, 40), WOOD, 2)  # legs
	_box(Rect2(292, 560, 14, 40), WOOD, 2)
	_box(Rect2(40, 530, 280, 36), WOOD, 4)  # frame
	_box(Rect2(58, 506, 250, 28), Color("#fbfbf6"), 8)  # mattress
	_box(Rect2(78, 486, 84, 26), Color("#fff4c9"), 12)  # pillow
	_box(Rect2(306, 494, 18, 106), WOOD, 4)  # footboard


func _draw_plant(base: Vector2) -> void:
	var leaf := Color("#5cae5c")
	var dark := Color("#3f8a4a")
	for i in 7:
		var a := -1.1 + i * 0.37
		var tip := base + Vector2(0, -60) + Vector2(sin(a), -cos(a)) * 70.0
		draw_line(base + Vector2(0, -55), tip, dark, 4.0, true)
		draw_circle(tip, 13.0, leaf)
		draw_arc(tip, 13.0, 0.0, TAU, 20, dark, 2.0, true)
	var pot := PackedVector2Array([base + Vector2(-32, -60), base + Vector2(32, -60), base + Vector2(24, 0), base + Vector2(-24, 0)])
	draw_colored_polygon(pot, Color("#cf7a4f"))
	draw_polyline(PackedVector2Array([pot[0], pot[1], pot[2], pot[3], pot[0]]), INK, 3.0, true)
	draw_rect(Rect2(base.x - 36, base.y - 66, 72, 12), Color("#b8663f"))
	draw_rect(Rect2(base.x - 36, base.y - 66, 72, 12), INK, false, 3.0)
