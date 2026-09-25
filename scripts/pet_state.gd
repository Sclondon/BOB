extends Node
## Bob's needs and everything that gets saved. Autoloaded as PetState.

signal stats_changed

const SAVE_PATH := "user://bob_save.json"
const STATS := ["hunger", "energy", "fun"]

# How fast each need drains, in points per minute (stats run 0-100).
const HUNGER_DECAY := 4.0
const FUN_DECAY := 5.0
const ENERGY_DECAY := 3.0
const ENERGY_NAP_GAIN := 20.0

# While the game is closed, needs drain slower and never bottom out completely.
const OFFLINE_RATE := 0.25
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const OFFLINE_FLOOR := 10.0

var hunger := 80.0  # 100 = full, 0 = starving
var energy := 80.0
var fun := 80.0
var asleep := false
var age_seconds := 0.0

var is_new_game := true
var seconds_away := 0.0

## Attract-video mode (see tools/autopilot.gd) plays a fresh Bob and never saves.
var autopilot := "--autopilot" in OS.get_cmdline_user_args()

var _save_timer := 0.0


func _ready() -> void:
	if not autopilot:
		load_game()


func _process(delta: float) -> void:
	tick(delta)
	_save_timer += delta
	if _save_timer >= 10.0:
		_save_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	# Browsers don't reliably send a close request, so also save when the tab loses focus.
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		save_game()


func tick(seconds: float, rate := 1.0) -> void:
	var minutes := seconds / 60.0 * rate
	hunger = clampf(hunger - HUNGER_DECAY * minutes, 0.0, 100.0)
	if asleep:
		energy = clampf(energy + ENERGY_NAP_GAIN * minutes, 0.0, 100.0)
	else:
		energy = clampf(energy - ENERGY_DECAY * minutes, 0.0, 100.0)
		fun = clampf(fun - FUN_DECAY * minutes, 0.0, 100.0)
	age_seconds += seconds
	stats_changed.emit()


func change(stat: String, amount: float) -> void:
	set(stat, clampf(float(get(stat)) + amount, 0.0, 100.0))
	stats_changed.emit()


## Overall mood. A single terrible need drags everything down.
func happiness() -> float:
	var lowest := minf(hunger, minf(energy, fun))
	var average := (hunger + energy + fun) / 3.0
	return minf(average, lowest + 35.0)


func mood_name() -> String:
	if asleep:
		return "Napping"
	var h := happiness()
	if h > 85.0:
		return "Ecstatic"
	if h > 65.0:
		return "Happy"
	if h > 45.0:
		return "Okay"
	if h > 25.0:
		return "Grumpy"
	return "Miserable"


## The most urgent need, or "" if Bob is doing fine.
func biggest_need() -> String:
	var worst := ""
	var worst_value := 35.0
	for stat in STATS:
		var value := float(get(stat))
		if value < worst_value:
			worst = stat
			worst_value = value
	return worst


func together_text() -> String:
	var total := int(age_seconds)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes


func save_game() -> void:
	if autopilot:
		return
	var data := {
		"hunger": hunger,
		"energy": energy,
		"fun": fun,
		"age_seconds": age_seconds,
		"saved_at": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	is_new_game = false
	hunger = float(data.get("hunger", hunger))
	energy = float(data.get("energy", energy))
	fun = float(data.get("fun", fun))
	age_seconds = float(data.get("age_seconds", 0.0))

	var now := Time.get_unix_time_from_system()
	seconds_away = clampf(now - float(data.get("saved_at", now)), 0.0, MAX_OFFLINE_SECONDS)
	tick(seconds_away, OFFLINE_RATE)
	for stat in STATS:
		set(stat, maxf(float(get(stat)), OFFLINE_FLOOR))
