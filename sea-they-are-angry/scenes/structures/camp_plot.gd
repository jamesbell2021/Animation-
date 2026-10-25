class_name CampPlot
extends Node3D
## A vegetable plot at the camp: one of the three outdoor beds, or the greenhouse's
## staging. Sow it with a packet of seed by day; it comes up overnight and is ready at
## dawn: lift it for food, and keep back seed for the next sowing. The outdoor beds give
## kale and cabbages and can be flattened by a storm; under glass it's tomatoes and
## beans, more of them, and safe from the weather.

enum { BARE, PLANTED, RIPE }

const SOW_COST := {"seeds": 1}
const YIELD_BED := 2
const YIELD_GLASS := 3
## A storm night flattens a planted outdoor bed this often.
const STORM_LOSS := 0.5
const LEAF := Color(0.22, 0.4, 0.2)
const LEAF_PALE := Color(0.42, 0.58, 0.32)
const FRUIT := Color(0.85, 0.2, 0.12)

var index := 0
var under_glass := false
## How long the plot is (m) along its local X, for laying out the plants.
var length := 6.4
## Where the plants stand from this node (the greenhouse's plot is worked from its wall).
var plants_offset := Vector3.ZERO
var _shoots: Node3D
var _plants: Node3D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("camp_plots")
	_shoots = Node3D.new()
	_shoots.position = plants_offset
	add_child(_shoots)
	_plants = Node3D.new()
	_plants.position = plants_offset
	add_child(_plants)
	var leaf := Look.flat_mat(LEAF, 0.85)
	var pale := Look.flat_mat(LEAF_PALE, 0.8)
	var fruit := Look.flat_mat(FRUIT, 0.5)
	var n := int(length / 0.55)
	for row in (2 if under_glass else 3):
		var z := (float(row) - (0.5 if under_glass else 1.0)) * (0.7 if under_glass else 0.45)
		for i in n:
			var x := -length * 0.5 + 0.3 + float(i) * (length - 0.6) / float(maxi(n - 1, 1))
			var s := Geo.box(_shoots, Vector3(0.05, 0.1, 0.05), Color.WHITE, Vector3(x, 0.26, z))
			s.material_override = pale
			if under_glass:
				# A staked tomato: a tall leafy plant, red trusses on it.
				var stake := Geo.box(_plants, Vector3(0.03, 0.9, 0.03), Color(0.5, 0.42, 0.3), Vector3(x, 0.7, z))
				stake.material_override = Look.flat_mat(Color(0.5, 0.42, 0.3), 0.9)
				var bush := Geo.sphere(_plants, 0.18, Color.WHITE, Vector3(x, 0.75, z))
				bush.material_override = leaf
				bush.scale = Vector3(1.0, 1.8, 1.0)
				for k in 3:
					var f := Geo.sphere(_plants, 0.045, Color.WHITE, Vector3(x + 0.1 * float(k - 1), 0.55 + 0.18 * float(k), z + 0.12))
					f.material_override = fruit
			else:
				# A cabbage, or a curl of kale.
				var head := Geo.sphere(_plants, 0.17 if (i + row) % 2 == 0 else 0.12, Color.WHITE, Vector3(x, 0.32, z))
				head.material_override = leaf if (i + row) % 2 == 0 else pale
				head.scale = Vector3(1.0, 0.75, 1.0)
	Cycle.phase_changed.connect(_on_phase)
	refresh()

func state() -> int:
	return int(Run.camp_crops[index]) if index < Run.camp_crops.size() else BARE

func _set_state(v: int) -> void:
	Run.camp_crops[index] = v
	refresh()

func refresh() -> void:
	var s := state()
	_shoots.visible = s == PLANTED
	_plants.visible = s == RIPE

func crop_name() -> String:
	return "tomatoes and beans" if under_glass else "kale and cabbages"

## Research: cold frames add this much to the greenhouse; tinning a food to every harvest.
const CLOCHE_BONUS := 2

func yield_food() -> int:
	var n := YIELD_GLASS if under_glass else YIELD_BED
	if under_glass and Research.has("cloches"):
		n += CLOCHE_BONUS
	if Research.has("rations"):
		n += 1
	return n

func _on_phase(p: int) -> void:
	if p != Cycle.Phase.DAWN or state() != PLANTED:
		return
	# The night just past: a storm can flatten what's growing outside.
	if not under_glass and not Research.has("cloches") and Weather.tonight() == Weather.Kind.STORM and randf() < STORM_LOSS:
		_set_state(BARE)
		Events.message.emit("The storm flattened a bed at the camp.")
		return
	_set_state(RIPE)

func interact_prompt() -> String:
	match state():
		BARE:
			return "[E] Sow %s (%s)" % [crop_name(), Stock.cost_str(SOW_COST)]
		PLANTED:
			return "%s coming up: ready at dawn" % crop_name().capitalize()
		RIPE:
			return "[E] Lift %s (+%d food, +1 seeds)" % [crop_name(), yield_food()]
	return ""

func interact(_player: Node) -> bool:
	match state():
		BARE:
			if not Stock.spend(SOW_COST):
				Events.message.emit("Need seeds: you get them back from what you lift")
				return false
			_set_state(PLANTED)
			Audio.sfx("step", global_position, 2.0, 0.2)
			Events.message.emit("Sown: ready at dawn")
			return true
		PLANTED:
			Events.message.emit("Not yet: it'll be up by morning")
			return false
		RIPE:
			_set_state(BARE)
			Stock.add("food", yield_food())
			Stock.add("seeds", 1)
			Audio.sfx("gather", global_position, -2.0, 0.05)
			Events.message.emit("+%d food, +1 seeds" % yield_food())
			return true
	return false
