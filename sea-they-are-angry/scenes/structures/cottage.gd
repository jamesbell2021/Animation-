class_name Cottage
extends Structure
## The keepers' cottage: whitewashed stone, slate roof, chimney, windows that
## glow from dusk to dawn. Its menu (eat, flares, dirty fuel, upgrades) is Phase C.

const WIDTH := 4.2
const DEPTH := 3.0
const WALL_H := 2.0
const WALL := Color(0.84, 0.82, 0.76)
const STONE := Color(0.42, 0.41, 0.38)
const SLATE := Color(0.20, 0.22, 0.25)
const WINDOW_DARK := Color(0.10, 0.12, 0.15)
const WINDOW_LIT := Color(1.0, 0.72, 0.38)

var _wall_mat: StandardMaterial3D
var _window_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _chimney_top := Vector3.ZERO
var _slabs: Array[MeshInstance3D] = []
var _ridge_y := 0.0

func _init() -> void:
	id = "cottage"
	max_hp = 150

func _build() -> void:
	_wall_mat = Look.flat_mat(WALL, 0.9)
	var stone := Look.flat_mat(STONE)
	var slate := Look.flat_mat(SLATE, 0.6)
	# Rubble footing, then whitewashed walls.
	var foot := Geo.box(self, Vector3(WIDTH + 0.2, 0.35, DEPTH + 0.2), STONE, Vector3(0.0, 0.1, 0.0))
	foot.material_override = stone
	var walls := Geo.box(self, Vector3(WIDTH, WALL_H, DEPTH), WALL, Vector3(0.0, WALL_H * 0.5 + 0.2, 0.0))
	walls.material_override = _wall_mat
	# Pitched slate roof from two tilted slabs, with stone gable ends under it.
	var pitch := deg_to_rad(38.0)
	var half := DEPTH * 0.5 + 0.25
	var slab_len := half / cos(pitch)
	var ridge_y := WALL_H + 0.2 + half * tan(pitch)
	for side in [-1.0, 1.0]:
		var slab := Geo.box(self, Vector3(WIDTH + 0.4, 0.14, slab_len + 0.05), SLATE, Vector3(0.0, (WALL_H + 0.2 + ridge_y) * 0.5, side * half * 0.5))
		slab.material_override = slate
		slab.rotation.x = side * pitch
		_slabs.append(slab)
	_ridge_y = ridge_y
	for side in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(DEPTH, ridge_y - WALL_H - 0.2, 0.2)
		gable.mesh = prism
		gable.material_override = _wall_mat
		gable.position = Vector3(side * (WIDTH * 0.5 - 0.1), (WALL_H + 0.2 + ridge_y) * 0.5, 0.0)
		gable.rotation.y = PI * 0.5
		add_child(gable)
	# Chimney on one gable end.
	var chimney := Geo.box(self, Vector3(0.55, 1.1, 0.55), STONE, Vector3(WIDTH * 0.5 - 0.35, ridge_y + 0.15, 0.0))
	chimney.material_override = stone
	Geo.box(self, Vector3(0.62, 0.1, 0.62), Color(0.3, 0.29, 0.27), Vector3(WIDTH * 0.5 - 0.35, ridge_y + 0.72, 0.0))
	_chimney_top = Vector3(WIDTH * 0.5 - 0.35, ridge_y + 0.85, 0.0)
	# Door and windows on the side facing the lighthouse (local -Z).
	Geo.box(self, Vector3(0.8, 1.45, 0.08), Color(0.22, 0.16, 0.11), Vector3(-0.3, 0.95, -DEPTH * 0.5 - 0.03))
	_window_mat = Look.glow_mat(WINDOW_DARK, 0.0)
	for wx in [-1.45, 0.95]:
		var w := Geo.box(self, Vector3(0.6, 0.55, 0.08), WINDOW_DARK, Vector3(wx, 1.45, -DEPTH * 0.5 - 0.03))
		w.material_override = _window_mat
	var back := Geo.box(self, Vector3(0.6, 0.55, 0.08), WINDOW_DARK, Vector3(0.6, 1.45, DEPTH * 0.5 + 0.03))
	back.material_override = _window_mat
	_lamp = OmniLight3D.new()
	_lamp.light_color = WINDOW_LIT
	_lamp.omni_range = 4.5
	_lamp.light_energy = 0.0
	_lamp.position = Vector3(0.0, 1.4, -DEPTH * 0.5 - 0.8)
	add_child(_lamp)
	Geo.box_shape(self, Vector3(WIDTH, WALL_H + 0.4, DEPTH), Vector3(0.0, WALL_H * 0.5 + 0.2, 0.0))
	Cycle.phase_changed.connect(_on_phase_changed)
	_set_windows(Cycle.phase == Cycle.Phase.DUSK or Cycle.phase == Cycle.Phase.NIGHT)
	FX.chimney_smoke.call_deferred(self, to_global(_chimney_top))

func _on_phase_changed(p: int) -> void:
	_set_windows(p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT)

func _set_windows(lit: bool) -> void:
	_window_mat.albedo_color = WINDOW_LIT if lit else WINDOW_DARK
	_window_mat.emission = WINDOW_LIT
	_window_mat.emission_energy_multiplier = 2.2 if lit else 0.0
	_lamp.light_energy = 1.4 if lit else 0.0

func _refresh() -> void:
	if _wall_mat:
		_wall_mat.albedo_color = Color(0.32, 0.30, 0.28).lerp(WALL, health_ratio())
	# The roof sags and slips as the cottage is battered.
	var hurt := 1.0 - health_ratio()
	for i in _slabs.size():
		_slabs[i].rotation.z = hurt * (0.22 if i == 0 else -0.14)
		_slabs[i].position.y = (WALL_H + 0.2 + _ridge_y) * 0.5 - hurt * 0.35

func smoke_point() -> Vector3:
	return Vector3(-0.6, _ridge_y, 0.2)

func display_name() -> String:
	return "cottage"

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - WIDTH * 0.5)
	var dz := maxf(0.0, absf(local.z) - DEPTH * 0.5)
	return Vector2(dx, dz).length()
