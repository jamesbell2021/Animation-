class_name Garden
extends Structure
## The keepers' kitchen garden: a low drystone wall around potato beds. Dig kelp into a
## bed by day and the crop is up by the next dawn; lift it for food to eat at the cottage.
## Anything that tramples the garden ruins a bed; wrecked, it loses the lot.

const WIDTH := 3.4
const DEPTH := 2.6
const WALL := Color(0.40, 0.39, 0.36)
const PLOT_COUNT := 5
const PLOT_STEP := 0.64

var plots: Array[GardenPlot] = []
var _wall_mat: StandardMaterial3D
var _ridges: Array[MeshInstance3D] = []

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
	# Narrow beds side by side; upgrades open more of them.
	for k in PLOT_COUNT:
		var plot := GardenPlot.new()
		plot.index = k
		plot.garden = self
		plot.position = Vector3((float(k) - float(PLOT_COUNT - 1) * 0.5) * PLOT_STEP, 0.0, 0.1)
		add_child(plot)
		_ridges.append_array(plot.ridges)
		plots.append(plot)
	# A water butt by the gate.
	var butt := Geo.cyl(self, 0.3, 0.75, Look.WOOD, Vector3(WIDTH * 0.5 - 0.35, 0.38, -DEPTH * 0.5 - 0.45))
	butt.material_override = Look.flat_mat(Look.WOOD)
	Geo.cyl(self, 0.32, 0.06, Color(0.2, 0.2, 0.22), Vector3(WIDTH * 0.5 - 0.35, 0.6, -DEPTH * 0.5 - 0.45))
	Cycle.phase_changed.connect(_on_phase_changed)
	set_plots(Upgrades.pick("garden", Upgrades.PLOTS))

## How many beds are dug (garden upgrade level).
func set_plots(n: int) -> void:
	for p in plots:
		p.set_open(p.index < n)

func open_plots() -> int:
	var n := 0
	for p in plots:
		if p.is_open:
			n += 1
	return n

func _on_phase_changed(p: int) -> void:
	# Whatever was dug in yesterday is up by morning.
	if p == Cycle.Phase.DAWN and not is_destroyed():
		for plot in plots:
			if plot.is_open and Run.crops[plot.index] == GardenPlot.PLANTED:
				Run.crops[plot.index] = GardenPlot.RIPE
				plot.refresh()

func _on_damaged() -> void:
	super._on_damaged()
	# Each blow ruins one bed; a wrecked garden loses every one.
	var growing: Array[GardenPlot] = []
	for plot in plots:
		if plot.is_open and Run.crops[plot.index] != GardenPlot.BARE:
			growing.append(plot)
	if growing.is_empty():
		return
	var lost: Array[GardenPlot] = []
	if hp <= 0:
		lost = growing
	else:
		lost.append(growing.pick_random())
	for plot in lost:
		Run.crops[plot.index] = GardenPlot.BARE
		plot.refresh()
	Events.message.emit("The garden is trampled: %s lost." % ("every bed" if lost.size() > 1 else "a bed of potatoes"))

func _refresh() -> void:
	if _wall_mat:
		_wall_mat.albedo_color = Color(0.25, 0.24, 0.22).lerp(WALL, health_ratio())
	# Trampled: the earthed-up rows are flattened and scuffed out of line.
	var hurt := 1.0 - health_ratio()
	for i in _ridges.size():
		var r := _ridges[i]
		r.scale = Vector3(1.0 + hurt * 0.5, 1.0, 1.0 - hurt * 0.6)
		r.rotation.y = hurt * (0.5 if i % 2 == 0 else -0.4)

func smoke_point() -> Vector3:
	return Vector3.INF

func display_name() -> String:
	return "garden"

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - WIDTH * 0.5)
	var dz := maxf(0.0, absf(local.z) - DEPTH * 0.5)
	return Vector2(dx, dz).length()
