class_name RopeBridge
extends Node3D
## The rope bridge to the holm, after Carrick-a-Rede's: wooden slats laid on two deck
## ropes, a handrope each side tied off to posts on the clifftops, hanging in a sag over
## the gully of sea. It moves like the real one: every footfall bounces it, a keeper's
## weight sinks it where they stand, and the walking and the wind set it swinging from
## side to side, the deck tipping as it goes.
##
## The deck's collision is one surface, rebuilt each physics step as the bridge moves,
## with the rope sides as walls and a ramp into the ground at each end, so there is no
## seam to catch a foot on. Keepers on it are carried sideways as it swings.

const SEGMENTS := 24
## How far the middle hangs below the ends (m).
const SAG := 0.6
const WIDTH := 1.0
const RAIL_H := 1.0
const SLATS := 3
## The swing from side to side, then the first two ways it bounces up and down:
## natural frequency (Hz) and how quickly each dies away (damping ratio).
const SWAY_HZ := 0.5
const BOUNCE_HZ := [1.25, 2.3]
const SWAY_DAMP := 0.06
const BOUNCE_DAMP := 0.12
## A footfall's kick to the bounce and to the sway. A walker's weight goes onto each
## foot in turn, but never evenly: the sway takes an uneven push from each step, so a
## keeper crossing sets it swinging further and further, like the real one.
const STEP_BOUNCE := 0.45
const STEP_SWAY := 0.22
const STEP_EVERY := 0.4
## How far the deck sinks under one keeper's weight, where they stand.
const WEIGHT_SAG := 0.14
## How hard the wind across the gully pushes the sway.
const WIND_PUSH := 0.05
const MAX_SWAY := 0.45
const MAX_BOUNCE := 0.18
const ROPE := Color(0.5, 0.42, 0.3)
## How far back onto each clifftop the deck's ramp starts (m).
const RAMP := 1.4

var a := Vector3.ZERO
var b := Vector3.ZERO
var _along := Vector3.FORWARD
var _side := Vector3.RIGHT
var _sway := 0.0
var _sway_v := 0.0
var _bounce := [0.0, 0.0]
var _bounce_v := [0.0, 0.0]
var _load := PackedFloat32Array()
var _segs: Array[Node3D] = []
var _shape: ConcavePolygonShape3D
var _ramp := [Vector3.ZERO, Vector3.ZERO]
var _carry := {}           # keeper -> where they were on it last step (u, sideways)
var _ropes: Array = []     # per rope: Array of MeshInstance3D (one per segment)
var _hangers: Array[MeshInstance3D] = []
var _steps := {}           # keeper -> [time to next footfall, left foot next]
var _rope_mesh: CylinderMesh
var _rope_mat: StandardMaterial3D

func _init(from: Vector3, to: Vector3) -> void:
	a = from
	b = to
	name = "RopeBridge"

func _ready() -> void:
	add_to_group("bridge")
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	_along = flat.normalized()
	_side = _along.cross(Vector3.UP).normalized()
	_load.resize(SEGMENTS + 1)
	_rope_mesh = CylinderMesh.new()
	_rope_mesh.top_radius = 0.022
	_rope_mesh.bottom_radius = 0.022
	_rope_mesh.height = 1.0
	_rope_mesh.radial_segments = 5
	_rope_mesh.rings = 1
	_rope_mat = Look.flat_mat(ROPE, 0.95)
	var slat_mat := Look.wood(Color(0.52, 0.4, 0.27), 0.6)
	var seg_len := _chord() / float(SEGMENTS)
	var deck_body := StaticBody3D.new()
	deck_body.name = "Deck"
	deck_body.collision_layer = 1
	deck_body.collision_mask = 0
	add_child(deck_body)
	_shape = ConcavePolygonShape3D.new()
	_shape.backface_collision = true
	var cs := CollisionShape3D.new()
	cs.shape = _shape
	deck_body.add_child(cs)
	# Where each end's ramp starts, back on the clifftop, a little below the grass.
	for e in 2:
		var end: Vector3 = a if e == 0 else b
		var back: Vector3 = -_along if e == 0 else _along
		var r: Vector3 = end + back * RAMP
		r.y = minf(Terrain.height_at(r.x, r.z), end.y) - 0.12
		_ramp[e] = r
	for i in SEGMENTS:
		var body := Node3D.new()
		add_child(body)
		for k in SLATS:
			var z := (float(k) + 0.5) / float(SLATS) * seg_len - seg_len * 0.5
			var slat := Geo.box(body, Vector3(WIDTH + 0.08 * float((i + k) % 2), 0.05, seg_len / float(SLATS) * 0.78), Color.WHITE, Vector3(0.0, -0.025, z))
			slat.material_override = slat_mat
			slat.rotation.y = (float((i * 7 + k * 3) % 5) - 2.0) * 0.02
		_segs.append(body)
	# Two deck ropes under the slat ends, two handropes; cords from hand to deck rope.
	for r in 4:
		var row: Array[MeshInstance3D] = []
		for i in SEGMENTS:
			row.append(_rope_piece())
		_ropes.append(row)
	for i in SEGMENTS + 1:
		for sx in [-1.0, 1.0]:
			_hangers.append(_rope_piece())
	_build_posts()
	_place_all()

func _rope_piece() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _rope_mesh
	m.material_override = _rope_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

# A pair of stout posts at each end, the handropes tied off to them.
func _build_posts() -> void:
	var post_mat := Look.wood(Color(0.36, 0.28, 0.2), 0.7)
	for end in [a, b]:
		var back: Vector3 = -_along if end == a else _along
		for sx in [-1.0, 1.0]:
			var p: Vector3 = end + back * 0.35 + _side * sx * (WIDTH * 0.5 + 0.12)
			p.y = Terrain.height_at(p.x, p.z)
			var post := Geo.box(self, Vector3(0.16, RAIL_H + 0.5, 0.16), Color.WHITE, p + Vector3(0.0, (RAIL_H + 0.5) * 0.5 - 0.1, 0.0))
			post.material_override = post_mat
			var body := StaticBody3D.new()
			body.collision_layer = 4
			body.collision_mask = 0
			add_child(body)
			Geo.box_shape(body, Vector3(0.18, RAIL_H + 0.5, 0.18), p + Vector3(0.0, (RAIL_H + 0.5) * 0.5, 0.0))

func _chord() -> float:
	return a.distance_to(b)

## Where the deck is at u (0 at the main island's end, 1 at the holm's), `lateral`
## metres to the side, as it hangs and moves right now.
func deck_point(u: float, lateral: float = 0.0) -> Vector3:
	u = clampf(u, 0.0, 1.0)
	var y := lerpf(a.y, b.y, u) - SAG * 4.0 * u * (1.0 - u)
	y += float(_bounce[0]) * sin(PI * u) + float(_bounce[1]) * sin(TAU * u) - _load_at(u)
	var sway := _sway * sin(PI * u)
	var p := a.lerp(b, u)
	p.y = y
	# It swings like a hammock: out to the side and a little up, tipping the deck.
	return p + _side * (sway + lateral * cos(_roll(u))) + Vector3.UP * (absf(sway) * 0.25 + lateral * sin(_roll(u)))

func _roll(u: float) -> float:
	return -_sway * 0.9 * sin(PI * u)

func _load_at(u: float) -> float:
	var f := u * float(SEGMENTS)
	var i := clampi(int(f), 0, SEGMENTS - 1)
	return lerpf(_load[i], _load[i + 1], f - float(i))

func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	var target := PackedFloat32Array()
	target.resize(SEGMENTS + 1)
	# Who is on it: their weight sinks it, their footfalls bounce and sway it.
	for k in get_tree().get_nodes_in_group("player"):
		var n := k as Node3D
		if n == null:
			continue
		var c := Terrain.bridge_coords(n.global_position.x, n.global_position.z)
		if c.x < 0.0 or c.x > 1.0 or c.y > WIDTH or absf(n.global_position.y - deck_point(c.x).y) > 1.2:
			_steps.erase(n)
			continue
		for i in SEGMENTS + 1:
			var d := (float(i) / float(SEGMENTS) - c.x) / 0.12
			target[i] += WEIGHT_SAG * exp(-d * d) * sin(PI * clampf(c.x, 0.0, 1.0)) * 1.4
		var v := Vector2(n.get("velocity").x, n.get("velocity").z).length() if n.get("velocity") != null else 0.0
		var st: Array = _steps.get(n, [0.0, true])
		if v > 0.6:
			st[0] = float(st[0]) - delta * v / 3.5
			if float(st[0]) <= 0.0:
				st[0] = STEP_EVERY
				st[1] = not bool(st[1])
				_footfall(c.x, 1.0 if bool(st[1]) else -1.0, v)
		_steps[n] = st
	for i in SEGMENTS + 1:
		_load[i] = lerpf(_load[i], target[i], minf(1.0, delta * 5.0))
	var before := {}
	for n in _steps.keys():
		if is_instance_valid(n):
			var c := Terrain.bridge_coords(n.global_position.x, n.global_position.z)
			before[n] = deck_point(c.x)
	# The wind across the gully leans on it, gusting.
	var wind: Vector3 = Weather.wind_now
	var push := wind.dot(_side) * WIND_PUSH
	_sway_v += (-pow(TAU * SWAY_HZ, 2.0) * _sway - 2.0 * SWAY_DAMP * TAU * SWAY_HZ * _sway_v + push) * delta
	_sway = clampf(_sway + _sway_v * delta, -MAX_SWAY, MAX_SWAY)
	for m in 2:
		var w := TAU * float(BOUNCE_HZ[m])
		_bounce_v[m] = float(_bounce_v[m]) + (-w * w * float(_bounce[m]) - 2.0 * BOUNCE_DAMP * w * float(_bounce_v[m])) * delta
		_bounce[m] = clampf(float(_bounce[m]) + float(_bounce_v[m]) * delta, -MAX_BOUNCE, MAX_BOUNCE)
	_place_all()
	# Carry whoever is on it sideways with the deck as it swings.
	for n in before.keys():
		var c := Terrain.bridge_coords(n.global_position.x, n.global_position.z)
		var moved: Vector3 = deck_point(c.x) - before[n]
		n.global_position += Vector3(moved.x, 0.0, moved.z)

func _footfall(u: float, foot: float, speed: float) -> void:
	var k := clampf(speed / 4.5, 0.4, 1.5)
	_bounce_v[0] = float(_bounce_v[0]) - STEP_BOUNCE * k * sin(PI * u)
	_bounce_v[1] = float(_bounce_v[1]) - STEP_BOUNCE * 0.6 * k * sin(TAU * u)
	_sway_v += STEP_SWAY * k * (foot * 0.4 + randf_range(-1.0, 1.0)) * sin(PI * u)
	if randf() < 0.35:
		Audio.sfx("creak", deck_point(u), -14.0, 0.25)

## How far it is swinging (m at the middle): for tests and for keepers to feel it.
func sway() -> float:
	return _sway

func _place_all() -> void:
	var n := SEGMENTS
	for i in n:
		var u0 := float(i) / float(n)
		var u1 := float(i + 1) / float(n)
		var p0 := deck_point(u0)
		var p1 := deck_point(u1)
		var um := (u0 + u1) * 0.5
		var z := (p1 - p0).normalized()
		var roll := _roll(um)
		var x := _side.rotated(z, -roll)
		x = (x - z * x.dot(z)).normalized()
		var y := z.cross(x).normalized()
		_segs[i].global_transform = Transform3D(Basis(x, y, z), (p0 + p1) * 0.5)
	_update_shape()
	var off := [[-WIDTH * 0.5, -0.06], [WIDTH * 0.5, -0.06], [-(WIDTH * 0.5 + 0.06), RAIL_H], [WIDTH * 0.5 + 0.06, RAIL_H]]
	for r in 4:
		var row: Array = _ropes[r]
		var lat: float = off[r][0]
		var up: float = off[r][1]
		for i in n:
			_rope_between(row[i], _rope_at(float(i) / float(n), lat, up), _rope_at(float(i + 1) / float(n), lat, up))
	for i in n + 1:
		var u := float(i) / float(n)
		_rope_between(_hangers[i * 2], _rope_at(u, -(WIDTH * 0.5 + 0.06), RAIL_H), _rope_at(u, -WIDTH * 0.5, -0.06))
		_rope_between(_hangers[i * 2 + 1], _rope_at(u, WIDTH * 0.5 + 0.06, RAIL_H), _rope_at(u, WIDTH * 0.5, -0.06))

# The deck's collision: its walking surface from ramp to ramp, and the rope sides as
# walls a keeper can't step over (both faces collide).
func _update_shape() -> void:
	var f := PackedVector3Array()
	var hw := WIDTH * 0.5
	var rows: Array = []
	var r0: Vector3 = _ramp[0]
	var r1: Vector3 = _ramp[1]
	rows.append([r0 - _side * hw, r0 + _side * hw])
	for i in SEGMENTS + 1:
		var u := float(i) / float(SEGMENTS)
		rows.append([_rope_at(u, -hw, 0.0), _rope_at(u, hw, 0.0)])
	rows.append([r1 - _side * hw, r1 + _side * hw])
	for i in rows.size() - 1:
		var l0: Vector3 = rows[i][0]
		var q0: Vector3 = rows[i][1]
		var l1: Vector3 = rows[i + 1][0]
		var q1: Vector3 = rows[i + 1][1]
		f.append_array([l0, l1, q0, q0, l1, q1])
		# The sides, only over the gully (the ramps are open to the clifftop).
		if i > 0 and i < rows.size() - 2:
			for e in [[l0, l1], [q0, q1]]:
				var p0: Vector3 = e[0]
				var p1: Vector3 = e[1]
				var up := Vector3.UP * (RAIL_H + 0.2)
				f.append_array([p0, p1, p0 + up, p0 + up, p1, p1 + up])
	_shape.set_faces(f)

# A point on one of the ropes: across the deck by `lat`, `up` above it, tipped with it.
func _rope_at(u: float, lat: float, up: float) -> Vector3:
	var base := deck_point(u)
	var roll := _roll(u)
	var s := _side * cos(roll) + Vector3.UP * sin(roll)
	var n := Vector3.UP * cos(roll) - _side * sin(roll)
	return base + s * lat + n * up

func _rope_between(m: MeshInstance3D, p0: Vector3, p1: Vector3) -> void:
	var d := p1 - p0
	var l := d.length()
	if l < 0.001:
		return
	var y := d / l
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	m.global_transform = Transform3D(Basis(x, y * l, z), (p0 + p1) * 0.5)
