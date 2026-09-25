extends CanvasLayer
## On-screen needs bars, action buttons and the chat box.

signal action_requested(action: String)
signal message_sent(text: String)

const INK := Color(0.1, 0.1, 0.12)
const LOW_COLOR := Color("#e05a4f")
const STATS := {
	"hunger": {"label": "Food", "color": Color("#f0a04b")},
	"energy": {"label": "Energy", "color": Color("#f2c94c")},
	"fun": {"label": "Fun", "color": Color("#6fcf97")},
	"hygiene": {"label": "Clean", "color": Color("#56a8e8")},
}
const ACTIONS := [["feed", "Feed"], ["play", "Play"], ["clean", "Shower"], ["sleep", "Sleep"]]

var _bars := {}
var _fills := {}
var _mood_label: Label
var _age_label: Label
var _sleep_button: Button
var _chat_input: LineEdit


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	root.add_child(_build_stats_panel())
	root.add_child(_build_action_bar())
	PetState.stats_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for stat in STATS:
		var value := float(PetState.get(stat))
		_bars[stat].value = value
		_fills[stat].bg_color = LOW_COLOR if value < 25.0 else STATS[stat].color
	_mood_label.text = "Mood: %s" % PetState.mood_name()
	_age_label.text = "Age: %s" % PetState.together_text()
	_sleep_button.text = "Wake Up" if PetState.asleep else "Sleep"


func _build_stats_panel() -> Control:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "BOB"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	_mood_label = Label.new()
	box.add_child(_mood_label)

	for stat in STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := Label.new()
		name_label.text = STATS[stat].label
		name_label.custom_minimum_size.x = 72
		row.add_child(name_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(190, 20)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
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

	_age_label = Label.new()
	_age_label.add_theme_font_size_override("font_size", 16)
	_age_label.add_theme_color_override("font_color", Color(INK, 0.6))
	box.add_child(_age_label)
	return panel


func _build_action_bar() -> Control:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -14
	panel.offset_bottom = -14
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	for action in ACTIONS:
		var button := Button.new()
		button.text = action[1]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(action_requested.emit.bind(action[0]))
		row.add_child(button)
		if action[0] == "sleep":
			_sleep_button = button
			button.custom_minimum_size.x = 110

	row.add_child(VSeparator.new())
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Say something to Bob..."
	_chat_input.custom_minimum_size.x = 320
	_chat_input.max_length = 120
	_chat_input.text_submitted.connect(_send)
	row.add_child(_chat_input)
	var send := Button.new()
	send.text = "Say"
	send.focus_mode = Control.FOCUS_NONE
	send.pressed.connect(func() -> void: _send(_chat_input.text))
	row.add_child(send)
	return panel


func _send(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	message_sent.emit(text)
	_chat_input.clear()


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 20

	var panel := _style(Color(1, 1, 1, 0.92), 14)
	panel.set_content_margin_all(12)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var button_states := {"normal": Color.WHITE, "hover": Color("#fff6d6"), "pressed": Color("#ffe08a"), "disabled": Color("#dddddd")}
	for key in button_states:
		var box := _style(button_states[key], 10)
		box.content_margin_left = 18
		box.content_margin_right = 18
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		theme.set_stylebox(key, "Button", box)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, "Button", INK)

	var edit := _style(Color.WHITE, 10)
	edit.set_content_margin_all(8)
	var edit_focus := _style(Color("#fffbea"), 10)
	edit_focus.set_content_margin_all(8)
	theme.set_stylebox("normal", "LineEdit", edit)
	theme.set_stylebox("focus", "LineEdit", edit_focus)
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color(INK, 0.45))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("font_color", "Label", INK)
	return theme


func _style(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(3)
	box.set_corner_radius_all(radius)
	return box
