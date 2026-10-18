class_name Garden
extends Structure
## The keepers' kitchen garden: a low drystone wall around tilled plots.
## Planting and harvesting are Phase C; for now the plots are bare, freshly dug earth.

const WIDTH := 3.4
const DEPTH := 2.6
const WALL := Color(0.40, 0.39, 0.36)
const SOIL := Color(0.15, 0.11, 0.08)
const PLOTS_L1 := 3

var plots: Array[Node3D] = []
var _wall_mat: StandardMaterial3D

func _init() -> void:
	id = "garden"
	max_hp = 100

func repair_cost() -> Dictionary:
	return {"driftwood": 1, "seaweed": 1}

func _build() -> void:
	_wall_mat = Look.flat_mat(WALL)
	# Drystone wall: rough stones along each side, with a gap facing the lighthouse.
	var i := 0
	for side in [[Vector3(1, 0, 0), WIDTH, Vector3(0, 0, DEPTH * 0.5)], [Vector3(1, 0, 0), WIDTH, Vector3(0, 0, -DEPTH * 0.5)], [Vector3(0, 0, 1), DEPTH, Vector3(WIDTH * 0.5, 0, 0)], [Vector3(0, 0, 1), DEPTH, Vector3(-WIDTH * 0.5, 0, 0)]]:
		var along: Vector3 = side[0]
		var length: float = side[1]
		var centre: Vector3 = side[2]
		var stones := int(length / 0.45)
		for k in stones:
			var t := -length * 0.5 + (float(k) + 0.5) * length / float(stones)
			if centre.z < 0.0 and absf(t) < 0.5:
				continue
			i += 1
			var p := centre + along * t + Vector3(0.0, 0.18, 0.0)
			var rock := Look.rock(self, 300 + i, Vector3(0.48, 0.42, 0.36), p, WALL, 0.5)
			rock.rotation.y = atan2(along.x, along.z)
	# Tilled plots with furrows.
	for k in PLOTS_L1:
		var plot := Node3D.new()
		plot.position = Vector3(-1.05 + float(k) * 1.05, 0.0, 0.1)
		add_child(plot)
		var bed := Geo.box(plot, Vector3(0.85, 0.16, 1.6), SOIL, Vector3(0.0, 0.08, 0.0))
		bed.material_override = Look.flat_mat(SOIL, 1.0)
		# Earthed-up rows: low rounded ridges rather than planks.
		for f in 3:
			var ridge := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.09
			cyl.bottom_radius = 0.11
			cyl.height = 1.45
			cyl.radial_segments = 5
			cyl.rings = 1
			ridge.mesh = cyl
			ridge.material_override = Look.flat_mat(Color(0.20, 0.15, 0.11), 1.0)
			ridge.rotation.x = PI * 0.5
			ridge.position = Vector3(-0.27 + float(f) * 0.27, 0.15, 0.0)
			plot.add_child(ridge)
		plots.append(plot)
	# A water butt by the gate.
	var butt := Geo.cyl(self, 0.3, 0.75, Look.WOOD, Vector3(WIDTH * 0.5 - 0.35, 0.38, -DEPTH * 0.5 - 0.45))
	butt.material_override = Look.flat_mat(Look.WOOD)
	Geo.cyl(self, 0.32, 0.06, Color(0.2, 0.2, 0.22), Vector3(WIDTH * 0.5 - 0.35, 0.6, -DEPTH * 0.5 - 0.45))

func _refresh() -> void:
	if _wall_mat:
		_wall_mat.albedo_color = Color(0.25, 0.24, 0.22).lerp(WALL, health_ratio())

func display_name() -> String:
	return "garden"

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - WIDTH * 0.5)
	var dz := maxf(0.0, absf(local.z) - DEPTH * 0.5)
	return Vector2(dx, dz).length()
