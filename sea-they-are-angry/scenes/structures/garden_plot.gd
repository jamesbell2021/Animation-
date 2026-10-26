class_name GardenPlot
extends Node3D
## One potato bed in the garden. Bare: dig in a heap of kelp and plant. Planted: shoots
## show, and the crop is ready at the next dawn. Ripe: lift it for food.

enum { BARE, PLANTED, RIPE }

const SOIL := Color(0.15, 0.11, 0.08)
const RIDGE := Color(0.20, 0.15, 0.11)
const LEAF := Color(0.24, 0.42, 0.2)
const LEAF_DARK := Color(0.16, 0.3, 0.15)
const FLOWER := Color(0.9, 0.88, 0.95)
const KELP := Color(0.2, 0.32, 0.22)
const PLANT_COST := {"seaweed": 1}
const YIELD := 1

var index := 0
var garden: Garden
var is_open := true
var ridges: Array[MeshInstance3D] = []
var _bed: Node3D
var _kelp: Node3D
var _shoots: Node3D
var _plants: Node3D

func _init() -> void:
	_bed = Node3D.new()
	add_child(_bed)
	var bed := Geo.box(_bed, Vector3(0.5, 0.16, 1.6), SOIL, Vector3(0.0, 0.08, 0.0))
	bed.material_override = Look.flat_mat(SOIL, 1.0)
	# Earthed-up rows: low rounded ridges.
	for f in 2:
		var ridge := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.1
		cyl.height = 1.45
		cyl.radial_segments = 5
		cyl.rings = 1
		ridge.mesh = cyl
		ridge.material_override = Look.flat_mat(RIDGE, 1.0)
		ridge.rotation.x = PI * 0.5
		ridge.position = Vector3(-0.12 + float(f) * 0.24, 0.15, 0.0)
		_bed.add_child(ridge)
		ridges.append(ridge)
	# Planted: dark kelp dug into the rows and the first green shoots.
	_kelp = Node3D.new()
	_bed.add_child(_kelp)
	var kelp_mat := Look.flat_mat(KELP, 0.3)
	for k in 4:
		var strand := Geo.box(_kelp, Vector3(0.05, 0.03, 0.34), Color.WHITE, Vector3(-0.12 + 0.24 * float(k % 2), 0.24, -0.55 + 0.36 * float(k)))
		strand.material_override = kelp_mat
		strand.rotation.y = 0.4 * float(k % 3 - 1)
	_shoots = Node3D.new()
	_bed.add_child(_shoots)
	var leaf := Look.flat_mat(LEAF, 0.8)
	for k in 6:
		var s := Geo.box(_shoots, Vector3(0.05, 0.12, 0.05), Color.WHITE, Vector3(-0.12 + 0.24 * float(k % 2), 0.28, -0.6 + 0.24 * float(k)))
		s.material_override = leaf
	# Ripe: bushy haulms with pale flowers.
	_plants = Node3D.new()
	_bed.add_child(_plants)
	var dark := Look.flat_mat(LEAF_DARK, 0.85)
	var flower := Look.flat_mat(FLOWER, 0.6)
	for k in 6:
		var at := Vector3(-0.12 + 0.24 * float(k % 2), 0.36, -0.6 + 0.24 * float(k))
		var bush := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.17
		sm.height = 0.26
		sm.radial_segments = 6
		sm.rings = 3
		bush.mesh = sm
		bush.material_override = leaf if k % 2 == 0 else dark
		bush.position = at
		_plants.add_child(bush)
		var f := Geo.sphere(_plants, 0.035, Color.WHITE, at + Vector3(0.05, 0.12, 0.02))
		f.material_override = flower

func _ready() -> void:
	add_to_group("interactable")
	refresh()

func set_open(v: bool) -> void:
	is_open = v
	refresh()

func state() -> int:
	return int(Run.crops[index]) if index < Run.crops.size() else BARE

func refresh() -> void:
	_bed.visible = is_open
	var s := state()
	_kelp.visible = s == PLANTED
	_shoots.visible = s == PLANTED
	_plants.visible = s == RIPE

func _usable() -> bool:
	return is_open and garden != null and not garden.is_destroyed()

func interact_prompt() -> String:
	if not _usable():
		return ""
	match state():
		BARE:
			return "[E] Plant potatoes (dig in %s)" % Stock.cost_str(PLANT_COST)
		PLANTED:
			return "Potatoes in: ready at dawn"
		RIPE:
			return "[E] Lift potatoes (+%d food)" % yield_food()
	return ""

## Research: tinning puts a food more by from every harvest.
func yield_food() -> int:
	return YIELD + (1 if Research.has("rations") else 0)

func interact(_player: Node) -> bool:
	if not _usable():
		return false
	match state():
		BARE:
			if not Stock.spend(PLANT_COST):
				Events.message.emit("Need " + Stock.cost_str(PLANT_COST) + " to dig into the bed")
				return false
			Run.crops[index] = PLANTED
			Events.did.emit("sow", _player)
			Audio.sfx("step", global_position, 2.0, 0.2)
			Audio.sfx("gather", global_position, -6.0, 0.1)
			Events.message.emit("Potatoes planted: ready at dawn")
		PLANTED:
			Events.message.emit("Not yet: they'll be up by morning")
			return false
		RIPE:
			Run.crops[index] = BARE
			Stock.add("food", yield_food())
			Audio.sfx("gather", global_position, -2.0, 0.05)
			FX.splinters(get_parent(), global_position + Vector3(0.0, 0.4, 0.0))
			Events.message.emit("+%d food  (eat it at the cottage)" % yield_food())
	refresh()
	return true
