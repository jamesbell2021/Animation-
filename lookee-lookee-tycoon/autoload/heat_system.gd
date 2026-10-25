extends Node
## Autoload: police attention, 0-100. Selling, shouting and complaints raise it; it cools
## over time, faster while your stall is packed away. The level drives police behaviour:
##   CALM       - cops stroll the promenade
##   SUSPICIOUS - more patrols, wider eyes
##   WANTED     - a cop heads straight for you
##   RAID       - every cop on the beach comes running

signal heat_changed(value: float, level: int)
signal level_changed(level: int, previous: int)

enum Level { CALM, SUSPICIOUS, WANTED, RAID }

const THRESHOLDS := [0.0, 30.0, 65.0, 92.0]
const LEVEL_NAMES := ["Calm", "Suspicious", "Wanted", "RAID!"]
const LEVEL_COLORS := [Color("#43a047"), Color("#ffb300"), Color("#fb8c00"), Color("#e53935")]
const EXPOSED_DECAY := 0.3    # per second while your stall is open
const PACKED_DECAY := 2.4     # per second while packed away

var heat := 0.0
var level: Level = Level.CALM
## Set by the beach every frame: is the player's stall open?
var player_exposed := false
var active := false


func _process(delta: float) -> void:
	if not active or get_tree().paused:
		return
	var decay := (EXPOSED_DECAY if player_exposed else PACKED_DECAY) * RandomEvents.mult("heat_decay")
	reduce(decay * delta)


## Raw amounts are scaled by upgrades, events and how strict this beach's police are.
func add(amount: float, _reason := "") -> void:
	var strict := float(BeachDB.get_beach(GameManager.current_beach).police)
	_set_heat(heat + amount * Upgrades.heat_gain_mult() * RandomEvents.mult("heat_gain") * strict)


func reduce(amount: float) -> void:
	_set_heat(heat - amount)


func set_heat(value: float) -> void:
	_set_heat(value)


func ratio() -> float:
	return heat / 100.0


func level_name() -> String:
	return LEVEL_NAMES[level]


func level_color() -> Color:
	return LEVEL_COLORS[level]


func _set_heat(value: float) -> void:
	var old := heat
	heat = clampf(value, 0.0, 100.0)
	var new_level := Level.CALM
	for i in range(THRESHOLDS.size() - 1, -1, -1):
		if heat >= THRESHOLDS[i]:
			new_level = i as Level
			break
	# A little hysteresis so the level doesn't flicker at the boundary.
	if new_level < level and heat > THRESHOLDS[level] - 4.0:
		new_level = level
	if absf(old - heat) > 0.001:
		heat_changed.emit(heat, new_level)
	if new_level != level:
		var prev := level
		level = new_level
		level_changed.emit(level, prev)


## Overnight the police forget most things.
func new_day() -> void:
	level = Level.CALM
	_set_heat(heat * 0.3)
	player_exposed = false
