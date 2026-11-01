class_name GullNest
extends Node3D
## A herring gull's nest on Gull Rock: a scrape lined with dry grass and weed, with up
## to three eggs in it, olive-brown and blotched. [E] takes them (into the store, for
## the cottage to boil), and the colony rises screaming and mobs whoever did it
## (GullFlocks; they only frighten). The gulls lay again by the next dawn.

signal robbed(at: Vector3)

const MAX_EGGS := 3
## How likely a nest is to have 0, 1, 2 or 3 eggs at dawn.
const LAY := [0.25, 0.3, 0.3, 0.15]
const STRAW := Color(0.62, 0.55, 0.36)
const WEED := Color(0.30, 0.27, 0.16)

var eggs := 0
var seed_value := 0
var _rng := RandomNumberGenerator.new()
var _egg_nodes: Array[MeshInstance3D] = []

static var _egg_mesh: Mesh
static var _egg_mat: Material

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("gull_nests")
	_rng.seed = seed_value
	_build()
	lay()
	Cycle.phase_changed.connect(_on_phase)

func _on_phase(p: int) -> void:
	if p == Cycle.Phase.DAWN and not Net.is_client():
		lay()

## The gulls lay: a fresh clutch for the day.
func lay() -> void:
	var r := _rng.randf()
	var n := 0
	var acc := 0.0
	for i in LAY.size():
		acc += float(LAY[i])
		if r <= acc:
			n = i
			break
	set_eggs(maxi(eggs, n))

func set_eggs(n: int) -> void:
	eggs = clampi(n, 0, MAX_EGGS)
	for i in _egg_nodes.size():
		_egg_nodes[i].visible = i < eggs

## LAN: the host's count. Fewer than before means someone took them there.
func net_set_eggs(n: int) -> void:
	if n < eggs:
		robbed.emit(global_position)
	set_eggs(n)

func interact_prompt() -> String:
	if eggs <= 0:
		return ""
	return "[E] Take the gull egg" if eggs == 1 else "[E] Take the gull eggs (%d)" % eggs

func interact(p: Node) -> bool:
	if eggs <= 0:
		return false
	Stock.add("eggs", eggs)
	var who: String = p.keeper_name() if p.has_method("keeper_name") else "A keeper"
	Events.message.emit("%s takes %s from a gull's nest. The gulls don't like it." % [who, "an egg" if eggs == 1 else "%d eggs" % eggs])
	Events.did.emit("eggs", p)
	Audio.sfx("gather", global_position, -4.0, 0.1)
	set_eggs(0)
	robbed.emit(global_position)
	return true

func surface_distance(at: Vector3) -> float:
	return Geo.flat_dist(at, global_position) - 0.4

func _build() -> void:
	# The scrape: a low ring of tufts round a hollow.
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.34
	cyl.height = 0.06
	cyl.radial_segments = 10
	cyl.rings = 1
	base.mesh = cyl
	base.material_override = Look.flat_mat(WEED, 0.95)
	base.position.y = 0.02
	add_child(base)
	var straw := Look.flat_mat(STRAW, 0.95)
	var weed := Look.flat_mat(WEED.lightened(0.1), 0.95)
	for i in 14:
		var a := TAU * float(i) / 14.0 + _rng.randf_range(-0.15, 0.15)
		var tuft := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05 + _rng.randf() * 0.04, 0.18 + _rng.randf() * 0.08)
		tuft.mesh = bm
		tuft.material_override = straw if i % 3 != 0 else weed
		var r := 0.27 + _rng.randf_range(-0.03, 0.03)
		tuft.position = Vector3(sin(a) * r, 0.07, cos(a) * r)
		tuft.rotation = Vector3(_rng.randf_range(-0.4, 0.4), a + PI * 0.5 + _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
		add_child(tuft)
	var mesh := _egg()
	for i in MAX_EGGS:
		var e := MeshInstance3D.new()
		e.mesh = mesh
		e.material_override = _egg_mat
		var a := TAU * float(i) / 3.0 + 0.4
		e.position = Vector3(sin(a) * 0.07, 0.1, cos(a) * 0.07)
		e.rotation = Vector3(PI * 0.5 + _rng.randf_range(-0.2, 0.2), a, 0.0)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(e)
		_egg_nodes.append(e)

# An egg: blunt one end, pointed the other, olive-brown with dark blotches. A gull's egg
# is about 7 cm; these are a little larger so they read from the keepers' camera.
static func _egg() -> Mesh:
	if _egg_mesh != null:
		return _egg_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var segs := 10
	var length := 0.13
	var pts := []
	for j in rings + 1:
		var t := float(j) / float(rings)
		var y := (t - 0.5) * length
		# Wider toward the blunt end.
		var r := sin(t * PI) * 0.048 * (1.0 + 0.18 * (0.5 - t))
		var row := []
		for i in segs:
			var a := TAU * float(i) / float(segs)
			row.append(Vector3(cos(a) * r, y, sin(a) * r))
		pts.append(row)
	for j in rings:
		for i in segs:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][(i + 1) % segs]
			var c: Vector3 = pts[j + 1][(i + 1) % segs]
			var d: Vector3 = pts[j + 1][i]
			for v in [a, c, b, a, d, c]:
				st.set_uv(Vector2(atan2(v.z, v.x) / TAU + 0.5, v.y / length + 0.5))
				st.add_vertex(v)
	st.generate_normals()
	_egg_mesh = st.commit()
	var tex := NoiseTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.seamless = true
	var n := FastNoiseLite.new()
	n.frequency = 0.09
	n.seed = 77
	tex.noise = n
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 0.64, 1.0])
	g.colors = PackedColorArray([Color(0.48, 0.45, 0.30), Color(0.44, 0.41, 0.26), Color(0.2, 0.14, 0.09), Color(0.16, 0.11, 0.07)])
	tex.color_ramp = g
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.55
	_egg_mat = mat
	return _egg_mesh
