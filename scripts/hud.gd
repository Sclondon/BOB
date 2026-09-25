extends CanvasLayer
## Mobile-first HUD: needs meters up top, a toy tray along the bottom (drag a
## toy into the room, or tap to drop one), and a chat bar that opens from Talk.

signal toy_pressed(kind: String)  # finger went down on a tray toy
signal clear_requested
signal message_sent(text: String)

const Sketch := preload("res://scripts/sketch.gd")
const Room := preload("res://scripts/room.gd")

const INK := Sketch.INK
const LOW_COLOR := Color("#e05a4f")
const STATS := {
	"hunger": {"label": "Food", "color": Color("#f0a04b")},
	"energy": {"label": "Energy", "color": Color("#f2c94c")},
	"fun": {"label": "Fun", "color": Color("#6fcf97")},
}

var _bars := {}
var _fills := {}
var _mood_label: Label
var _chat_bar: PanelContainer
var _chat_input: LineEdit
var _hint: Label


## One toy in the tray: draws the toy and reports presses.
class ToyButton extends Control:
	var kind := ""
	var hud: CanvasLayer

	func _init(toy_kind: String, owner_hud: CanvasLayer) -> void:
		kind = toy_kind
		hud = owner_hud
		custom_minimum_size = Vector2(64, 104)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			hud.toy_pressed.emit(kind)
			accept_event()

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var icon_center := Vector2(size.x / 2.0, 44.0)
		var scale := 0.62 if kind in ["beachball", "anvil", "crate", "balloon"] else 0.9
		if kind == "balloon":
			scale = 0.55
			icon_center.y -= 6.0
		draw_set_transform(icon_center, 0.0, Vector2(scale, scale))
		Sketch.toy(self, kind, "apple", Sketch.boil())
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var font := get_theme_default_font()
		var label: String = Sketch.TOY_NAMES[kind]
		var fs := 17
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2.0, size.y - 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	root.add_child(_build_stats())
	root.add_child(_build_clear_button())
	root.add_child(_build_tray())
	root.add_child(_build_chat_bar())
	root.add_child(_build_hint())
	PetState.stats_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for stat in STATS:
		var value := float(PetState.get(stat))
		_bars[stat].value = value
		_fills[stat].bg_color = LOW_COLOR if value < 25.0 else STATS[stat].color
	_mood_label.text = "Bob · %s" % PetState.mood_name()


## Hide the "how to play" hint (after the first toy lands).
func dismiss_hint() -> void:
	if _hint.visible and _hint.modulate.a == 1.0:
		create_tween().tween_property(_hint, "modulate:a", 0.0, 0.6).finished.connect(_hint.hide)


func _build_stats() -> Control:
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 22)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_mood_label = Label.new()
	_mood_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_mood_label)
	for stat in STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = STATS[stat].label
		name_label.custom_minimum_size.x = 62
		name_label.add_theme_font_size_override("font_size", 16)
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(120, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#ececec")
		bg.border_color = INK
		bg.set_border_width_all(2)
		bg.set_corner_radius_all(6)
		var fill := StyleBoxFlat.new()
		fill.bg_color = STATS[stat].color
		fill.border_color = INK
		fill.set_border_width_all(2)
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		box.add_child(row)
		_bars[stat] = bar
		_fills[stat] = fill
	return panel


func _build_clear_button() -> Control:
	var button := Button.new()
	button.text = "Clear"
	button.focus_mode = Control.FOCUS_NONE
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_right = -22
	button.offset_top = 22
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.pressed.connect(clear_requested.emit)
	return button


func _build_tray() -> Control:
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 10
	panel.offset_right = -10
	panel.offset_bottom = -10
	panel.offset_top = -(Room.BOTTOM_INSET - 14.0)
	var tray_box := StyleBoxFlat.new()
	tray_box.bg_color = Color.WHITE
	tray_box.border_color = INK
	tray_box.set_border_width_all(4)
	tray_box.set_corner_radius_all(18)
	tray_box.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", tray_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)
	for kind in Sketch.TOYS:
		row.add_child(ToyButton.new(kind, self))
	var talk := Button.new()
	talk.text = "Talk"
	talk.focus_mode = Control.FOCUS_NONE
	talk.custom_minimum_size = Vector2(80, 0)
	talk.pressed.connect(_toggle_chat)
	row.add_child(talk)
	return panel


func _build_chat_bar() -> Control:
	_chat_bar = PanelContainer.new()
	_chat_bar.anchor_top = 1.0
	_chat_bar.anchor_right = 1.0
	_chat_bar.anchor_bottom = 1.0
	_chat_bar.offset_left = 10
	_chat_bar.offset_right = -10
	_chat_bar.offset_bottom = -(Room.BOTTOM_INSET + 4.0)
	_chat_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_chat_bar.visible = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_chat_bar.add_child(row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Say something to Bob..."
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.max_length = 120
	_chat_input.text_submitted.connect(_send)
	row.add_child(_chat_input)
	var send := Button.new()
	send.text = "Say"
	send.focus_mode = Control.FOCUS_NONE
	send.pressed.connect(func() -> void: _send(_chat_input.text))
	row.add_child(send)
	var close := Button.new()
	close.text = "X"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_toggle_chat)
	row.add_child(close)
	return _chat_bar


func _build_hint() -> Control:
	_hint = Label.new()
	_hint.text = "Drag toys into the room\nTilt or shake your phone" if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") else "Drag toys into the room\nArrow keys tilt, Space shakes"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color(INK, 0.55))
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_bottom = -(Room.BOTTOM_INSET + 18.0)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _hint


func _toggle_chat() -> void:
	_chat_bar.visible = not _chat_bar.visible
	if _chat_bar.visible:
		_hint.hide()
		_chat_input.grab_focus()
	else:
		_chat_input.release_focus()


func _send(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	message_sent.emit(text)
	_chat_input.clear()


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 24
	var panel := _style(Color(1, 1, 1, 0.9), 14)
	panel.set_content_margin_all(10)
	theme.set_stylebox("panel", "PanelContainer", panel)
	var button_states := {"normal": Color.WHITE, "hover": Color("#fff6d6"), "pressed": Color("#ffe08a"), "disabled": Color("#dddddd")}
	for key in button_states:
		var box := _style(button_states[key], 12)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		theme.set_stylebox(key, "Button", box)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, "Button", INK)
	var edit := _style(Color.WHITE, 12)
	edit.set_content_margin_all(10)
	theme.set_stylebox("normal", "LineEdit", edit)
	theme.set_stylebox("focus", "LineEdit", edit)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("font_color", "Label", INK)
	return theme


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(4)
	box.set_corner_radius_all(radius)
	return box
