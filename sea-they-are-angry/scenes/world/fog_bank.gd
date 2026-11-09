class_name FogBank
extends Node3D
## The fog itself. A bank that glows from within rolls in across the water at dusk and
## lies just off the shore all night. Before each landing a tongue of it pushes up that
## beach, and what comes out of the sea comes out of it, dark against its glow. Lights
## hold it off: the lamp, lit windows, the camp while its lights burn (and, in the
## harbour, every street lamp that's relit). Atmosphere owns one and drives it with the
## phase; the spawner's landings call tongue().
##
## Drawn with shaders/fog_bank.gdshader on three stacked sheets (no volumetrics: it has
## to read from high above, on any graphics setting).

const LAYERS := [0.35, 1.0, 2.1]
const SIZE := 260.0
## How far off the shore the bank lies by phase (day, dusk, night, dawn), in metres.
const GAPS := [70.0, 16.0, 7.0, 40.0]
const DENSITY := [0.0, 0.75, 0.95, 0.35]
const TONGUE_TIME := 14.0
const TONGUE_REACH := 10.0
const MAX_TONGUES := 4
const MAX_HOLES := 12

var density := 0.0
var gap := 70.0
var flood := 0.0
## The islands the bank lies round: [centre x, z, half x, half z, yaw] each.
var isles: Array = []
## Lights holding it off: any node with `fog_hole() -> Vector3` (x, z, radius; radius 0
## when it's dark) in the group "fog_lights".
var _mats: Array[ShaderMaterial] = []
var _tongues: Array = []     # [Vector3 at, float age]
var _tween: Tween

func _ready() -> void:
	name = "FogBank"
	if isles.is_empty():
		isles = [
			[0.0, 0.0, Terrain.COAST + 1.5, Terrain.COAST + 1.5, 0.0],
			[Terrain.HOLM_C.x, Terrain.HOLM_C.y, Terrain.HOLM_HALF.x + 1.0, Terrain.HOLM_HALF.y + 1.0, 0.0],
			[Terrain.ISLET_C.x, Terrain.ISLET_C.y, Terrain.ISLET_HALF.x, Terrain.ISLET_HALF.y, deg_to_rad(Terrain.ISLET_YAW)],
		]
	var shader: Shader = load("res://shaders/fog_bank.gdshader")
	for i in LAYERS.size():
		var sheet := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(SIZE, SIZE)
		sheet.mesh = pm
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("layer", float(i) / float(LAYERS.size() - 1))
		m.render_priority = i
		sheet.material_override = m
		sheet.position = Vector3(20.0, Terrain.SEA_LEVEL + float(LAYERS[i]), -6.0)
		sheet.visible = false
		add_child(sheet)
		_mats.append(m)
	_push_isles()
	_push()

func _push_isles() -> void:
	var v: Array[Vector4] = []
	var yaws: Array[float] = []
	for i in 3:
		if i < isles.size():
			var a: Array = isles[i]
			v.append(Vector4(a[0], a[1], a[2], a[3]))
			yaws.append(float(a[4]))
		else:
			v.append(Vector4(9999.0, 9999.0, 1.0, 1.0))
			yaws.append(0.0)
	for m in _mats:
		m.set_shader_parameter("isles", v)
		m.set_shader_parameter("isle_yaw", yaws)

## Ease the bank to a phase's place: `p` a Cycle.Phase, `thick` scales it (weather).
func apply(p: int, duration: float, thick: float = 1.0) -> void:
	var want_gap: float = GAPS[p]
	var want_d: float = float(DENSITY[p]) * thick
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0:
		gap = want_gap
		density = want_d
		_push()
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "gap", want_gap, duration).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "density", want_d, duration * 0.6)

## A tongue of fog up the shore at `at` (a landing about to happen).
func tongue(at: Vector3) -> void:
	_tongues.append([at, 0.0])
	while _tongues.size() > MAX_TONGUES:
		_tongues.pop_front()

## Whether a point on the ground is in the fog now (the bank, a tongue, or the flood),
## and not in a light's keeping. Chapter Two's creatures come only where it is.
func in_fog(p: Vector3) -> bool:
	if density < 0.2:
		return false
	for h in _holes():
		if Vector2(p.x - h.x, p.z - h.y).length() < h.z * 0.8:
			return false
	for t in _tongues:
		if Geo.flat_dist(p, t[0]) < _tongue_radius(float(t[1])) * 0.7:
			return true
	var metres := INF
	for a in isles:
		var q := Vector2(p.x - float(a[0]), p.z - float(a[1])).rotated(-float(a[4]))
		var e := Vector2(q.x / float(a[2]), q.y / float(a[3])).length()
		metres = minf(metres, (e - 1.0) * minf(float(a[2]), float(a[3])))
	return metres > gap - flood * (gap + 30.0)

func _tongue_radius(age: float) -> float:
	# Out over a few seconds, held, then drawn back.
	var k := age / TONGUE_TIME
	return TONGUE_REACH * smoothstep(0.0, 0.25, k) * (1.0 - smoothstep(0.7, 1.0, k))

func _holes() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not is_inside_tree():
		return out
	for n in get_tree().get_nodes_in_group("fog_lights"):
		if n.has_method("fog_hole"):
			var h: Vector3 = n.fog_hole()
			if h.z > 0.05:
				out.append(h)
	return out

func _process(delta: float) -> void:
	for t in _tongues:
		t[1] = float(t[1]) + delta
	while not _tongues.is_empty() and float(_tongues[0][1]) > TONGUE_TIME:
		_tongues.pop_front()
	_push()

func _push() -> void:
	var on := density > 0.01
	var tv: Array[Vector4] = []
	for i in MAX_TONGUES:
		if i < _tongues.size():
			var at: Vector3 = _tongues[i][0]
			tv.append(Vector4(at.x, at.z, _tongue_radius(float(_tongues[i][1])), 1.0))
		else:
			tv.append(Vector4(0.0, 0.0, 0.0, 0.0))
	var hv: Array[Vector4] = []
	var holes := _holes()
	for i in MAX_HOLES:
		if i < holes.size():
			hv.append(Vector4(holes[i].x, holes[i].y, holes[i].z, 1.0))
		else:
			hv.append(Vector4(0.0, 0.0, 0.0, 0.0))
	var wind := Weather.wind_now
	for i in _mats.size():
		var m := _mats[i]
		(get_child(i) as MeshInstance3D).visible = on
		if not on:
			continue
		m.set_shader_parameter("density", density)
		m.set_shader_parameter("gap", gap)
		m.set_shader_parameter("flood", flood)
		m.set_shader_parameter("tongues", tv)
		m.set_shader_parameter("holes", hv)
		m.set_shader_parameter("drift", Vector2(wind.x, wind.z).limit_length(3.0) * 0.35 + Vector2(0.3, 0.1))
