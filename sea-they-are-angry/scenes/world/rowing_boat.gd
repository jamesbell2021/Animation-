class_name RowingBoat
extends Node3D
## The keepers' rowing boat: a clinker-built, double-ended yoal of the Northern Isles
## kind, kept at the east beach's jetty. It takes keepers out to Gull Rock and back.
##
## [E] at the jetty's foot (or at the foot of Gull Rock's slip) pushes off with that
## keeper at the oars; anyone else who presses [E] there in the next moment climbs in
## too, up to three. It rows itself along the channel, the rower pulling, the oars
## dipping, and lands everyone at the other end. Rowing out is by day only, and not
## when the sea is rough; rowing back is always allowed, so nobody is stranded.
## It runs on a line: from either end a keeper can haul the empty boat across.
## The host moves it; on a LAN client it follows the host's (net_apply).

signal crossed(to_side: int)

const NAME := "Gull Rock"
const MAIN := 0
const ISLET := 1
enum State { MOORED, BOARDING, ROWING, HAULING }
## Rowing speed (m/s), and how fast an empty boat comes in on its line.
const ROW_SPEED := 2.6
const HAUL_SPEED := 1.9
## After the first keeper climbs in, how long the others have to join.
const BOARD_WAIT := 1.4
## How long climbing in or out takes.
const STEP_TIME := 0.7
## A sea rougher than this (Weather.storm_now) is too much to row out in.
const ROUGH := 0.32
## A stroke: drive (blade in the water) then recovery.
const STROKE_TIME := 1.7
const DRIVE := 0.42
## The hull.
const LENGTH := 4.2
const BEAM := 1.55
const DEPTH := 0.62
const STRAKES := 5
const OAR_LENGTH := 2.8
const OAR_INBOARD := 0.8
const THOLE := Vector3(0.74, 0.62, 0.32)

const PAINT := Color(0.86, 0.84, 0.76)
const SHEER := Color(0.16, 0.42, 0.46)
const RUB := Color(0.62, 0.20, 0.14)
const TIMBER := Color(0.55, 0.42, 0.28)
const TIMBER_DARK := Color(0.40, 0.29, 0.18)

var state := State.MOORED
## Which end it's at, or heading for.
var side := MAIN
## Where it is along the route (m from the jetty), and the route's length.
var along := 0.0
var length := 0.0
## Who's in it: [rower, stern, bow].
var crew: Array = [null, null, null]
var stroke_t := 0.0
var landings: Array = []

var _route: PackedVector3Array = PackedVector3Array()
var _dist: PackedFloat32Array = PackedFloat32Array()
var _moor_yaw := [0.0, 0.0]
var _board_t := 0.0
var _yaw := 0.0
var _hull: Node3D
var _oars: Array[Node3D] = []
var _oar_rest: Array[Node3D] = []
var _bob_t := 0.0
var _net: Array = []

func _ready() -> void:
	add_to_group("rowing_boat")
	_build()

## Lay out the route: from the jetty's mooring, through the channel, to Gull Rock's.
## `main_moor` and `islet_moor` hold position and the way the bow points when moored.
func setup(main_moor: Transform3D, main_foot: Vector3, islet_moor: Transform3D, islet_foot: Vector3, via: Array) -> void:
	var pts: Array[Vector3] = [main_moor.origin]
	for v in via:
		pts.append(v)
	pts.append(islet_moor.origin)
	_route = PackedVector3Array()
	_dist = PackedFloat32Array()
	# Catmull-Rom through the points, so it rows a smooth line.
	for i in pts.size() - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		for k in 16:
			var t := float(k) / 16.0
			_route.append(_catmull(p0, p1, p2, p3, t))
	_route.append(pts[pts.size() - 1])
	var total := 0.0
	for i in _route.size():
		if i > 0:
			total += Vector2(_route[i].x - _route[i - 1].x, _route[i].z - _route[i - 1].z).length()
		_dist.append(total)
	length = total
	_moor_yaw = [main_moor.basis.get_euler().y, islet_moor.basis.get_euler().y]
	_yaw = _moor_yaw[MAIN]
	along = 0.0
	side = MAIN
	_place(0.0)
	for i in 2:
		var l := BoatLanding.new()
		l.boat = self
		l.side = i
		add_sibling.call_deferred(l)
		l.position = main_foot if i == MAIN else islet_foot
		landings.append(l)

static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

## How far across it is, 0 at the jetty to 1 at Gull Rock.
func progress() -> float:
	return along / maxf(length, 0.01)

func at_side() -> int:
	return side if state != State.ROWING and state != State.HAULING else -1

func is_moving() -> bool:
	return state == State.ROWING or state == State.HAULING

func aboard() -> int:
	var n := 0
	for c in crew:
		if c != null:
			n += 1
	return n

## Why it can't push off from this side now, or "" if it can.
static func refusal(from_side: int) -> String:
	if from_side == ISLET:
		return ""
	if Cycle.phase != Cycle.Phase.DAY and Cycle.phase != Cycle.Phase.DAWN:
		return "It's getting dark: no rowing out to %s now." % NAME
	if Weather.storm_now > ROUGH:
		return "The sea's too rough to row out to %s." % NAME
	return ""

# ---- used from a landing ----

func prompt_for(from_side: int, p: Node) -> String:
	if Net.is_client() or bool(p.get("downed")):
		return ""
	match state:
		State.ROWING, State.HAULING:
			return ""
		State.BOARDING:
			if side == from_side and crew.has(null) and not crew.has(p):
				return "[E] Climb in"
			return ""
	if side != from_side:
		return "[E] Haul the boat over on its line"
	var why := refusal(from_side)
	if why != "":
		return why
	return "[E] Row out to %s" % NAME if from_side == MAIN else "[E] Row back to the lighthouse"

func use_from(from_side: int, p: Player) -> bool:
	if p == null or p.ai or p.riding != null or p.downed or p.hp <= 0:
		return false
	match state:
		State.ROWING, State.HAULING:
			return false
		State.BOARDING:
			if side != from_side:
				return false
			var seat := crew.find(null)
			if seat < 0 or crew.has(p):
				return false
			_seat(p, seat)
			return true
	if side != from_side:
		state = State.HAULING
		side = from_side
		Audio.sfx("creak", global_position, -6.0, 0.15)
		Events.message.emit("%s hauls the boat across on its line." % p.keeper_name())
		return true
	var why := refusal(from_side)
	if why != "":
		Events.message.emit(why)
		return false
	state = State.BOARDING
	_board_t = BOARD_WAIT
	_seat(p, 0)
	return true

func _seat(p: Player, seat: int) -> void:
	crew[seat] = p
	p.ride(self, seat)
	Audio.sfx("creak", global_position, -8.0, 0.2)

## Where seat i is, as the keeper sitting there should stand: the rower faces the stern.
func seat_xform(i: int) -> Transform3D:
	var local: Vector3
	var turn := 0.0
	match i:
		0:
			local = Vector3(0.0, 0.40, 0.02)
			turn = PI
		1:
			local = Vector3(0.0, 0.40, 1.15)
		_:
			local = Vector3(0.0, 0.40, -1.05)
	var g := _hull.global_transform
	var at := g * local
	# The keeper's model stands on its feet: sitting, its hips are about this high.
	at.y -= SIT_HIP
	return Transform3D(Basis(Vector3.UP, rotation.y + turn), at)

const SIT_HIP := 0.86
## How deep she sits in the water.
const DRAFT := 0.22

# ---- moving ----

func _physics_process(delta: float) -> void:
	_bob_t += delta
	if Net.is_client():
		_client_step(delta)
		return
	match state:
		State.BOARDING:
			_board_t -= delta
			if _board_t <= 0.0:
				state = State.ROWING
				side = ISLET if side == MAIN else MAIN
		State.ROWING:
			stroke_t = fmod(stroke_t + delta / STROKE_TIME, 1.0)
			var surge := 0.75 + 0.5 * sin(PI * clampf(stroke_t / DRIVE, 0.0, 1.0)) if stroke_t < DRIVE else 0.75
			var v := ROW_SPEED * surge * (1.0 - 0.3 * clampf(Weather.storm_now, 0.0, 1.0))
			if _advance(v * delta):
				_land()
			elif stroke_t < delta / STROKE_TIME * 1.01:
				Audio.sfx("oar", global_position, -4.0, 0.12)
		State.HAULING:
			if _advance(HAUL_SPEED * delta):
				state = State.MOORED
				crossed.emit(side)
	_place(delta)

# Move along the route toward `side`; true on arriving.
func _advance(d: float) -> bool:
	if side == ISLET:
		along = minf(length, along + d)
		return along >= length
	along = maxf(0.0, along - d)
	return along <= 0.0

func _land() -> void:
	state = State.MOORED
	var foot: Vector3 = landings[side].global_position if landings.size() > side else global_position
	var n := 0
	for i in crew.size():
		var p = crew[i]
		crew[i] = null
		if p != null and is_instance_valid(p):
			# Out onto the shore, side by side.
			p.dismount(_footing(foot, n))
			n += 1
	Audio.sfx("hammer", global_position, -12.0, 0.2)
	crossed.emit(side)

# Somewhere firm and flat near the landing for the nth keeper out: the landing itself
# for the first, then round it.
static func _footing(foot: Vector3, n: int) -> Vector3:
	for r in [0.0, 0.8, 1.3, 1.8, 2.4]:
		for k in 8:
			var a := TAU * float(k + n * 3) / 8.0
			var c := foot + Vector3(sin(a), 0.0, cos(a)) * float(r) * (1.0 if n == 0 or r > 0.0 else 0.0)
			if r == 0.0 and n > 0:
				continue
			if Terrain.walkable(c.x, c.z) and Terrain.slope_at(c.x, c.z) < 0.7 and Terrain.height_at(c.x, c.z) > Terrain.SEA_LEVEL + 0.15:
				return Vector3(c.x, Terrain.height_at(c.x, c.z), c.z)
	return foot

## The point on the route `d` metres from the jetty, and the way along it there.
func _point(d: float) -> Array:
	if _route.is_empty():
		return [global_position, Vector3.FORWARD]
	var i := 1
	while i < _dist.size() - 1 and _dist[i] < d:
		i += 1
	var a := _route[i - 1]
	var b := _route[i]
	var seg := maxf(_dist[i] - _dist[i - 1], 0.001)
	var t := clampf((d - _dist[i - 1]) / seg, 0.0, 1.0)
	return [a.lerp(b, t), (b - a).normalized()]

func _place(delta: float) -> void:
	var pt := _point(along)
	var at: Vector3 = pt[0]
	var dir: Vector3 = pt[1]
	var moving := is_moving() or state == State.BOARDING
	var want := _yaw
	if is_moving():
		var travel := dir if side == ISLET else -dir
		want = atan2(-travel.x, -travel.z)
	elif state == State.MOORED:
		want = _moor_yaw[side]
	_yaw = lerp_angle(_yaw, want, minf(1.0, delta * (1.6 if moving else 0.8))) if delta > 0.0 else want
	var y := Terrain.SEA_LEVEL + swell_at(at.x, at.z)
	global_position = Vector3(at.x, y, at.z)
	rotation.y = _yaw
	# Pitch and roll on the swell.
	var e := 0.8
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var pitch := (swell_at(at.x + fwd.x * e, at.z + fwd.z * e) - swell_at(at.x - fwd.x * e, at.z - fwd.z * e)) / (2.0 * e)
	var roll := (swell_at(at.x + right.x * e, at.z + right.z * e) - swell_at(at.x - right.x * e, at.z - right.z * e)) / (2.0 * e)
	_hull.rotation = Vector3(atan(pitch) * 0.8, 0.0, -atan(roll) * 0.8)
	_pose_oars()

## The sea's height here, as sea.gdshader moves it (so the boat rides its swell).
static func swell_at(x: float, z: float) -> float:
	# The shader's TIME, which wraps every hour.
	var t := fmod(Time.get_ticks_msec() / 1000.0, 3600.0)
	var storm := clampf(Weather.storm_now, 0.0, 1.2)
	var sp := 1.0 + storm * 0.9
	var h := sin(x * 0.35 + t * 0.9 * sp) * 0.6 + sin(z * 0.47 - t * 1.1 * sp) * 0.4 + sin((x + z) * 1.1 + t * 1.7 * sp) * 0.2
	h += sin(x * 0.16 - z * 0.21 + t * 1.3) * storm * 1.6
	return h * 0.09 * (1.0 + storm * 5.0)

func _pose_oars() -> void:
	var rowing := state == State.ROWING
	for i in 2:
		_oars[i].visible = rowing or state == State.BOARDING
		_oar_rest[i].visible = not _oars[i].visible
	if not _oars[0].visible:
		return
	# Sweep: catch (blade toward the bow) to finish (toward the stern) on the drive, the
	# blade buried; back again on the recovery, the blade lifted and feathered.
	var sweep := 0.0
	var lift := 0.0
	var feather := 0.0
	if not rowing:
		sweep = -0.15
		lift = 0.05
	elif stroke_t < DRIVE:
		var k := stroke_t / DRIVE
		sweep = lerpf(-0.6, 0.55, smoothstep(0.0, 1.0, k))
		lift = -0.3
	else:
		var k := (stroke_t - DRIVE) / (1.0 - DRIVE)
		sweep = lerpf(0.55, -0.6, smoothstep(0.0, 1.0, k))
		lift = -0.12 + sin(k * PI) * 0.08
		feather = PI * 0.5 * sin(k * PI)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var o := _oars[i]
		o.rotation = Vector3(0.0, -s * sweep, s * lift)
		(o.get_child(0) as Node3D).rotation.x = feather

## Where the rower's hands are on the handles now (for the rig's arms): the stroke's
## phase, 0 at the catch (reached out) to 1 at the finish (pulled in).
func pull() -> float:
	if state != State.ROWING:
		return 0.3
	if stroke_t < DRIVE:
		return smoothstep(0.0, 1.0, stroke_t / DRIVE)
	return 1.0 - smoothstep(0.0, 1.0, (stroke_t - DRIVE) / (1.0 - DRIVE))

# ---- LAN ----

func net_snap() -> Array:
	return [state, side, along, _yaw, stroke_t]

func net_apply(a: Array) -> void:
	_net = a

func _client_step(delta: float) -> void:
	if _net.size() >= 5:
		state = int(_net[0])
		side = int(_net[1])
		along = lerpf(along, float(_net[2]), 1.0 - exp(-delta * Net.FOLLOW)) if absf(along - float(_net[2])) < 4.0 else float(_net[2])
		stroke_t = float(_net[4])
	_place(delta)

# ---- the boat itself ----

func _build() -> void:
	_hull = Node3D.new()
	_hull.position.y = -DRAFT
	add_child(_hull)
	var mi := MeshInstance3D.new()
	mi.mesh = _hull_mesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.75
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	_hull.add_child(mi)
	var wood := Look.wood(TIMBER, 0.7, 0.85)
	var dark := Look.wood(TIMBER_DARK, 0.7, 0.9)
	# Stem and stern posts, standing a little proud of the sheer.
	for z: float in [-1.0, 1.0]:
		var post := _part(_hull, BoxMesh.new(), Vector3(0.07, 0.36, 0.1), Vector3(0.0, _sheer(z) - 0.06, z * LENGTH * 0.5), dark)
		post.rotation.x = -z * 0.35
	# Thwarts, floorboards and the gunwale's knees.
	for z: float in [-1.05, 0.02, 1.15]:
		var u: float = z / (LENGTH * 0.5)
		var w: float = _half_beam(u, 0.62) * 2.0 - 0.08
		_part(_hull, BoxMesh.new(), Vector3(w, 0.05, 0.24), Vector3(0.0, 0.38, z), wood)
	for x: float in [-0.22, 0.0, 0.22]:
		_part(_hull, BoxMesh.new(), Vector3(0.16, 0.025, LENGTH * 0.62), Vector3(x, 0.05, 0.0), dark)
	# Thole pins, and the oars: in the rowlocks when rowing, laid along the thwarts when not.
	for s: float in [-1.0, 1.0]:
		_part(_hull, CylinderMesh.new(), Vector3(0.025, 0.14, 0.025), Vector3(s * THOLE.x, THOLE.y + 0.05, THOLE.z), dark)
		_part(_hull, CylinderMesh.new(), Vector3(0.025, 0.14, 0.025), Vector3(s * THOLE.x, THOLE.y + 0.05, THOLE.z + 0.16), dark)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var pivot := Node3D.new()
		pivot.position = Vector3(s * THOLE.x, THOLE.y + 0.04, THOLE.z + 0.08)
		_hull.add_child(pivot)
		var shaft_holder := Node3D.new()
		pivot.add_child(shaft_holder)
		_oar(shaft_holder, s)
		_oars.append(pivot)
		var rest := Node3D.new()
		rest.position = Vector3(s * 0.3, 0.46, -0.2)
		rest.rotation = Vector3(0.0, PI * 0.5 + s * 0.08, 0.0)
		_hull.add_child(rest)
		var r_holder := Node3D.new()
		r_holder.position = Vector3(-OAR_LENGTH * 0.5 + OAR_INBOARD, 0.0, 0.0)
		rest.add_child(r_holder)
		_oar(r_holder, 1.0)
		_oar_rest.append(rest)
	# A coil of rope and the bailer in the bottom.
	var coil := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.1
	tor.outer_radius = 0.17
	coil.mesh = tor
	coil.material_override = Look.flat_mat(Color(0.62, 0.53, 0.36), 0.95)
	coil.position = Vector3(0.18, 0.1, 1.55)
	_hull.add_child(coil)
	var bailer := _part(_hull, CylinderMesh.new(), Vector3(0.09, 0.08, 0.09), Vector3(-0.2, 0.1, -1.5), Look.flat_mat(Color(0.3, 0.32, 0.3), 0.6))
	bailer.rotation.z = 0.4

# One oar along +x from the thole outward (s = 1 starboard, -1 port).
func _oar(parent: Node3D, s: float) -> void:
	var wood := Look.wood(Color(0.70, 0.60, 0.45), 0.7, 0.8)
	var shaft := _part(parent, CylinderMesh.new(), Vector3(0.035, OAR_LENGTH, 0.035), Vector3(s * (OAR_LENGTH * 0.5 - OAR_INBOARD), 0.0, 0.0), wood)
	shaft.rotation.z = PI * 0.5
	var blade := _part(parent, BoxMesh.new(), Vector3(0.62, 0.02, 0.15), Vector3(s * (OAR_LENGTH - OAR_INBOARD - 0.3), 0.0, 0.0), Look.wood(Color(0.55, 0.62, 0.66), 0.7, 0.7))
	blade.rotation.x = 0.0

func _part(parent: Node3D, mesh: PrimitiveMesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		c.top_radius = size.x
		c.bottom_radius = size.x
		c.height = size.y
		c.radial_segments = 8
		c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

# Half the boat's breadth at u (-1 bow to 1 stern), at girth v (0 keel, 1 gunwale).
static func _half_beam(u: float, v: float) -> float:
	var hb := BEAM * 0.5 * pow(maxf(0.0, 1.0 - pow(absf(u), 2.2)), 0.62)
	return hb * pow(sin(clampf(v, 0.0, 1.0) * PI * 0.5), 0.75)

static func _keel(u: float) -> float:
	return 0.02 + 0.16 * u * u

static func _sheer(u: float) -> float:
	return DEPTH + 0.24 * pow(absf(u), 2.4)

static func _hull_at(u: float, v: float) -> Vector3:
	var x := _half_beam(u, v)
	var y := lerpf(_keel(u), _sheer(u), 1.0 - cos(v * PI * 0.5))
	return Vector3(x, y, u * LENGTH * 0.5)

# Lapstrake planking, both sides: each strake a band whose lower edge laps outside the
# one below. Outside painted, with a coloured sheer strake and a red rubbing strake;
# bare timber inside.
func _hull_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 28
	for side_s: float in [1.0, -1.0]:
		for k in STRAKES:
			var v0 := float(k) / float(STRAKES)
			var v1 := float(k + 1) / float(STRAKES)
			var col := PAINT.darkened(0.04 * float(k % 2))
			if k == STRAKES - 1:
				col = SHEER
			for i in nu:
				var u0 := -1.0 + 2.0 * float(i) / float(nu)
				var u1 := -1.0 + 2.0 * float(i + 1) / float(nu)
				var a := _hull_at(u0, v0)
				var b := _hull_at(u1, v0)
				var c := _hull_at(u1, v1)
				var d := _hull_at(u0, v1)
				# The lap: the strake's lower edge stands out a little from the one below.
				var lap := Vector3(0.018, -0.012, 0.0)
				a += lap * (1.0 - absf(u0))
				b += lap * (1.0 - absf(u1))
				var out := [a, b, c, d]
				for j in 4:
					var p: Vector3 = out[j]
					p.x = absf(p.x) * side_s
					out[j] = p
				_quad(st, out, col, side_s, false)
				# Inside, a plank's thickness in.
				var inn := []
				for p in out:
					var q: Vector3 = p
					q.x -= 0.025 * side_s * (1.0 - absf(q.z) / (LENGTH * 0.5))
					q.y += 0.01
					inn.append(q)
				_quad(st, inn, TIMBER.darkened(0.06 * float(k % 2)), side_s, true)
		# The gunwale cap along the top edge.
		for i in nu:
			var u0 := -1.0 + 2.0 * float(i) / float(nu)
			var u1 := -1.0 + 2.0 * float(i + 1) / float(nu)
			var a := _hull_at(u0, 1.0)
			var b := _hull_at(u1, 1.0)
			a.x *= side_s
			b.x *= side_s
			var w := 0.06 * side_s
			_quad(st, [a, b, b - Vector3(w, 0.0, 0.0), a - Vector3(w, 0.0, 0.0)], TIMBER_DARK, side_s, false)
			# A red rubbing strake just under it.
			var o := Vector3(0.012 * side_s, 0.0, 0.0)
			_quad(st, [a + o + Vector3(0.0, -0.06, 0.0), b + o + Vector3(0.0, -0.06, 0.0), b + o, a + o], RUB, side_s, false)
	st.generate_normals()
	return st.commit()

func _quad(st: SurfaceTool, q: Array, col: Color, side_s: float, inside: bool) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if (side_s < 0.0) != inside:
		order = [0, 2, 1, 0, 3, 2]
	for j in order:
		st.set_color(col)
		st.add_vertex(q[j])


## The place on the shore where keepers take the boat: at the jetty's foot, and at the
## foot of Gull Rock's slip.
class BoatLanding:
	extends Node3D

	var boat: RowingBoat
	var side := 0

	func _ready() -> void:
		add_to_group("interactable")
		add_to_group("boat_landings")

	func interact_prompt() -> String:
		return ""

	func prompt_for(p: Node) -> String:
		return boat.prompt_for(side, p) if is_instance_valid(boat) else ""

	func interact(p: Node) -> bool:
		return boat.use_from(side, p) if is_instance_valid(boat) and p is Player else false

	func surface_distance(at: Vector3) -> float:
		return Geo.flat_dist(at, global_position) - 0.6
