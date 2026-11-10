class_name KrakenBody
extends Node3D
## The kraken's body: how it looks and how it moves, and nothing else. No damage, no
## health, no collision, no sound, no rules: the fight's own script sets this node's
## global_position (always at sea level, in water; do not rotate it, use face()) and
## calls the functions below. It animates itself.
##
## A head (the mantle) with two huge pale eyes on the side that faces its prey, and
## eight arms rooted round it under the water. Arms 0 and 1 are the pair nearest the
## eyes (0 on its own left, 1 on its own right), then 2 and 3, 4 and 5, and 6 and 7 at
## the back: even arms on its left, odd on its right. Each arm is one tapered tube
## rebuilt through a chain of control points, the way the Eel's body is, with a pale
## belly and two rows of suckers on the side it curls toward.

## An arm's slam has landed: where its tip came down.
signal slammed(arm: int, at: Vector3)
## The death animation has finished and it is under.
signal died

const ARMS := 8

# ---- sizes, in metres ----
const HEAD_RADIUS := 4.8
const HEAD_HEIGHT := 6.6
# How far down the head lies when it is under.
const HEAD_SUNK := 10.5
# The mantle is stretched backwards, and leans back as it rises.
const HEAD_BACK := 1.45
const HEAD_LEAN := 2.8
const EYE_RADIUS := 1.05
const EYE_AT := Vector3(2.5, 3.05, -2.75)
const ARM_LEN := 24.0
const ARM_ROOT_AT := 3.4
const ARM_ROOT_DEPTH := 0.9
const ARM_THICK := 1.45
const ARM_TIP := 0.13
# How the arm thins from root to tip: above 1 it keeps its thickness longer.
const TAPER := 1.1
# How far out an idling arm lies in the water.
const IDLE_REACH := 15.0
# An arm leaves the body outwards before it bends toward what it wants.
const OUT_PUSH := 3.5
# What is left of a severed arm, as a share of its length.
const STUMP := 0.4

# ---- the arms' tubes ----
const CTRL := 9
const RINGS := 24
const SIDES := 7
const HIT_POINTS := 8
const SUCKERS := 7

# ---- timings, in seconds ----
const SLAM_TIME := 0.25
const SLAM_LIE := 0.8
const SEVER_THRASH := 1.1
const SEVER_WITHDRAW := 0.9
const FLASH_TIME := 0.12
const TURN_RATE := 1.3
const EYE_GLOW := 0.25
# The eyeball's own colour, as a share of `eye`: with the glow on top it is just bright
# enough to bloom, and the pupil still shows.
const EYE_PALE := 0.8
const MILKY := Color(0.60, 0.64, 0.66)
const ICHOR := Color(0.42, 0.58, 0.55)
# Blinded, its hide blanches: every colour on it is multiplied toward this.
const BLANCH := Color(2.3, 2.2, 2.0)

# Degrees round from the way it faces, for each arm's root.
const ARM_ANGLES := [-22.5, 22.5, -67.5, 67.5, -112.5, 112.5, -157.5, 157.5]

enum Order { REST, REACH }
enum Act { NONE, WINDUP, STRIKE, LIE, THRASH, WITHDRAW, GONE, REGROW }

## One arm: where its control points are, what it has been told, and what it is doing.
class Arm:
	var pts := PackedVector3Array()
	var from := PackedVector3Array()
	var to := PackedVector3Array()
	var centres := PackedVector3Array()
	var order := 0
	var order_at := Vector3.ZERO
	var act := 0
	var act_t := 0.0
	var act_len := 0.0
	var slam_at := Vector3.ZERO
	var grown := 1.0
	var stump := false
	var fall := 0.0
	var phase := 0.0
	var spray_t := 0.0
	var out := Vector3.FORWARD
	var near_land := false
	var drawn := false
	var mesh: ArrayMesh
	var inst: MeshInstance3D

## 0 under the water, 1 fully up.
var risen := 0.0
## Tunables: read once, when the body is built.
var skin := Color(0.10, 0.14, 0.15)
var belly := Color(0.52, 0.50, 0.42)
var eye := Color(1.0, 0.86, 0.35)

var _arms: Array[Arm] = []
var _goal := PackedVector3Array()
var _landed: Array = []
var _indices := PackedInt32Array()
var _ring_cos := PackedFloat32Array()
var _ring_sin := PackedFloat32Array()
var _t := 0.0
var _rise_dir := 0.0
var _emerge := 0.0
var _yaw := 0.0
var _yaw_goal := 0.0
var _turn := Basis.IDENTITY
var _blind_on := false
var _blind := 0.0
var _aside := 1.0
var _roar_t := 0.0
var _roar_len := 1.0
var _roar := 0.0
var _die_t := -1.0
var _die_len := 7.0
var _fall_at := PackedFloat32Array()
var _dead := false
var _flash_t := 0.0
var _splash_t := 0.0
var _runoff_t := 0.0
var _blink_t := 5.0

var _pivot: Node3D
var _head: Node3D
var _mantle: MeshInstance3D
var _head_mat: StandardMaterial3D
var _lump_mat: StandardMaterial3D
var _arm_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D
var _flash_meshes: Array[MeshInstance3D] = []
var _eyes: Array[Node3D] = []
var _lids: Array = []
var _pupils: Array[MeshInstance3D] = []
var _glints: Array[MeshInstance3D] = []
var _runoff: GPUParticles3D
var _drop_mesh: SphereMesh

func _ready() -> void:
	_goal.resize(CTRL)
	_fall_at.resize(ARMS)
	for k in SIDES + 1:
		var a := TAU * float(k) / float(SIDES)
		_ring_cos.append(cos(a))
		_ring_sin.append(sin(a))
	_build_head()
	_build_arms()
	_step(0.0)

func _process(delta: float) -> void:
	_step(delta)

# ---- what the fight asks of it ----

## Brings it up out of the water over `time` seconds, water streaming off it.
func rise(time: float = 6.0) -> void:
	_dead = false
	_die_t = -1.0
	_rise_dir = 1.0 / maxf(time, 0.1)
	_swell(2.0)

## Takes it under over `time` seconds.
func sink(time: float = 5.0) -> void:
	_rise_dir = -1.0 / maxf(time, 0.1)

## Turns the head (it eases round) so the eyes look at the point.
func face(point: Vector3) -> void:
	var to := point - global_position
	if absf(to.x) + absf(to.z) > 0.01:
		_yaw_goal = atan2(-to.x, -to.z)

## Where the two eyes are (its own left eye first).
func eye_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for e in _eyes:
		out.append(e.global_position)
	return out

## That arm's tip works its way toward the point and holds near it, arching up and over.
func arm_reach(arm: int, target: Vector3) -> void:
	var a := _arms[arm]
	a.order = Order.REACH
	a.order_at = target

## Lets the arm go back to idling in the water round the body.
func arm_rest(arm: int) -> void:
	_arms[arm].order = Order.REST

## Rears the arm high over the target for `windup` seconds, whips it down in a quarter
## of a second, emits `slammed`, lies there a moment, then goes back to what it was
## doing. Ignored if the arm is already slamming, is not out, or the kraken is blinded,
## dying or under. Being blinded in the wind-up calls the slam off (no signal).
func arm_slam(arm: int, target: Vector3, windup: float = 1.2) -> void:
	var a := _arms[arm]
	if a.act != Act.NONE or _blind_on or _die_t >= 0.0 or _dead or _emerge < 0.5:
		return
	a.act = Act.WINDUP
	a.act_t = 0.0
	a.act_len = maxf(windup, 0.05)
	a.slam_at = target

## True while the arm is winding up, coming down, or lying where it landed.
func arm_busy(arm: int) -> bool:
	var act := _arms[arm].act
	return act == Act.WINDUP or act == Act.STRIKE or act == Act.LIE

## Where the arm's tip is.
func arm_tip(arm: int) -> Vector3:
	var a := _arms[arm]
	return a.centres[RINGS - 1] if _arm_shows(a) else _root(arm)

## Eight points along the arm from its root to its tip (none while it is under).
func arm_points(arm: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := _arms[arm]
	if not _arm_shows(a):
		return out
	for k in HIT_POINTS:
		out.append(a.centres[roundi(float(k) / float(HIT_POINTS - 1) * float(RINGS - 1))])
	return out

## False from the moment the arm is severed until it has grown all the way back.
func arm_out(arm: int) -> bool:
	return _arms[arm].act < Act.THRASH and not _dead

## The arm is cut back: the stump thrashes and sprays, then withdraws under the water.
func sever(arm: int) -> void:
	var a := _arms[arm]
	if a.act == Act.THRASH or a.act == Act.WITHDRAW or a.act == Act.GONE:
		return
	a.act = Act.THRASH
	a.act_t = 0.0
	a.spray_t = 0.0
	a.stump = true

## Brings a severed arm back out over `time` seconds.
func regrow(arm: int, time: float = 10.0) -> void:
	var a := _arms[arm]
	if a.act < Act.THRASH or a.act == Act.REGROW:
		return
	a.act = Act.REGROW
	a.act_len = maxf(time, 0.1)
	a.stump = false
	a.grown = 0.0

## The lamp is in its eyes: they screw shut and go milky, the head recoils and turns
## aside, and every arm goes slack and drops where it is, until this is turned off.
func set_blinded(on: bool) -> void:
	if on == _blind_on:
		return
	_blind_on = on
	if on:
		_aside = -_aside
		for a in _arms:
			a.fall = 0.0
			if a.act == Act.WINDUP or a.act == Act.STRIKE or a.act == Act.LIE:
				a.act = Act.NONE

## A brief pale flash over the head when it is hit.
func hurt_flash() -> void:
	if Settings.calm_lights:
		return
	_flash_t = FLASH_TIME

## Rears up, arms spread wide, for a roar.
func roar_pose(time: float = 2.5) -> void:
	_roar_len = maxf(time, 0.2)
	_roar_t = _roar_len

## Death: the arms thrash and fall one by one, the head rolls, it slides under; then
## `died` is emitted.
func die(time: float = 7.0) -> void:
	if _die_t >= 0.0 or _dead:
		return
	_die_len = maxf(time, 0.5)
	_die_t = 0.0
	_blind_on = false
	var turn := randi() % ARMS
	for i in ARMS:
		_fall_at[(i * 3 + turn) % ARMS] = _die_len * (0.14 + 0.36 * float(i) / float(ARMS - 1))
		var a := _arms[i]
		if a.act == Act.WINDUP or a.act == Act.STRIKE or a.act == Act.LIE:
			a.act = Act.NONE

# ---- building it ----

func _build_head() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_head = Node3D.new()
	_pivot.add_child(_head)
	var mottle := _mottle_texture()
	var hide := _hide_texture()
	_head_mat = _wet(Look.flat_mat(Color.WHITE, 0.36))
	_head_mat.vertex_color_use_as_albedo = true
	_head_mat.vertex_color_is_srgb = true
	_lump_mat = _wet(Look.flat_mat(skin * 1.7, 0.36))
	for m in [_head_mat, _lump_mat]:
		m.albedo_texture = mottle
		m.normal_enabled = true
		m.normal_texture = hide
		m.normal_scale = 1.0
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.13
	_mantle = MeshInstance3D.new()
	_mantle.mesh = _mantle_mesh()
	_mantle.material_override = _head_mat
	_mantle.extra_cull_margin = 2.0
	_head.add_child(_mantle)
	_flash_meshes.append(_mantle)
	_build_lumps()
	_eye_mat = Look.eye_mat(eye, EYE_GLOW)
	_eye_mat.albedo_color = eye * EYE_PALE
	for side in [-1.0, 1.0]:
		_build_eye(side)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(1.0, 0.95, 0.85, 0.55)
	_build_runoff()

# Wet hide: a hard highlight and a sheen at the edges, so it reads in the dark.
func _wet(m: StandardMaterial3D) -> StandardMaterial3D:
	m.metallic_specular = 0.42
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.45
	return m

# Blotchy skin, as the Eel has: a noise texture laid over the painted colours.
func _mottle_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 1944
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.52, 0.52))
	ramp.set_color(1, Color(1.25, 1.25, 1.2))
	tex.color_ramp = ramp
	return tex

# The hide's grain: pebbled, like wet leather, as a normal map.
func _hide_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 44
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 5.0
	tex.width = 256
	tex.height = 256
	return tex

# The mantle's outline: [radius, height] from under the water up to the crown.
const MANTLE := [[3.2, -2.6], [4.1, -1.1], [4.65, 0.2], [4.8, 1.4], [4.62, 2.6], [4.28, 3.6],
	[3.8, 4.5], [3.1, 5.3], [2.2, 5.95], [1.2, 6.4], [0.35, 6.58]]
const MANTLE_ROWS := 22
const MANTLE_COLS := 30

func _mantle_outline(f: float) -> Vector2:
	var n := MANTLE.size() - 1
	var x := clampf(f, 0.0, 1.0) * float(n)
	var i := mini(int(x), n - 1)
	var u := x - float(i)
	var p0 := Vector2(MANTLE[maxi(i - 1, 0)][0], MANTLE[maxi(i - 1, 0)][1])
	var p1 := Vector2(MANTLE[i][0], MANTLE[i][1])
	var p2 := Vector2(MANTLE[i + 1][0], MANTLE[i + 1][1])
	var p3 := Vector2(MANTLE[mini(i + 2, n)][0], MANTLE[mini(i + 2, n)][1])
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)

# A point on the mantle's hide: `ang` round from the back (PI is the face), `f` up the
# outline. Lumpy, flatter in the face, long behind, leaning back as it rises.
func _mantle_point(ang: float, f: float, noise: FastNoiseLite) -> Vector3:
	var o := _mantle_outline(f)
	var x := sin(ang) * o.x
	var z := cos(ang) * o.x
	var n := noise.get_noise_3d(x * 0.3, o.y * 0.3, z * 0.3)
	var fine := noise.get_noise_3d(x * 0.95 + 40.0, o.y * 0.95, z * 0.95)
	var swell := 1.0 + 0.085 * n + 0.035 * fine
	x *= swell
	z *= swell * (HEAD_BACK if z > 0.0 else 0.93)
	z += pow(maxf(o.y, 0.0) / HEAD_HEIGHT, 1.3) * HEAD_LEAN
	return Vector3(x, o.y * (1.0 + 0.03 * n), z)

func _mantle_mesh() -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 87
	noise.frequency = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in MANTLE_ROWS + 1:
		var f := float(j) / float(MANTLE_ROWS)
		for i in MANTLE_COLS:
			var p := _mantle_point(TAU * float(i) / float(MANTLE_COLS), f, noise)
			var blotch := noise.get_noise_3d(p.x * 0.5 + 9.0, p.y * 0.5, p.z * 0.5)
			var c := skin * (1.5 + 1.8 * blotch)
			# Paler down toward the water, where the arms' pale undersides begin.
			c = c.lerp(belly, smoothstep(1.8, -1.2, p.y) * 0.6)
			# Old pale scars and patches.
			c = c.lerp(belly, smoothstep(0.1, 0.4, blotch) * 0.5)
			# The crown is darkest.
			c = c.lerp(skin * 0.7, smoothstep(3.8, 6.4, p.y) * 0.45)
			c.a = 1.0
			st.set_color(c)
			st.add_vertex(p)
	# The crown's last point.
	var top := _mantle_point(0.0, 1.0, noise)
	top.x = 0.0
	st.set_color(skin * 0.6)
	st.add_vertex(top + Vector3(0.0, 0.08, 0.0))
	var cap := (MANTLE_ROWS + 1) * MANTLE_COLS
	for j in MANTLE_ROWS:
		for i in MANTLE_COLS:
			var i2 := (i + 1) % MANTLE_COLS
			var a := j * MANTLE_COLS + i
			var b := j * MANTLE_COLS + i2
			var c2 := (j + 1) * MANTLE_COLS + i
			var d := (j + 1) * MANTLE_COLS + i2
			for v in [a, c2, d, a, d, b]:
				st.add_index(v)
	for i in MANTLE_COLS:
		var i2 := (i + 1) % MANTLE_COLS
		for v in [MANTLE_ROWS * MANTLE_COLS + i, cap, MANTLE_ROWS * MANTLE_COLS + i2]:
			st.add_index(v)
	st.generate_normals()
	return st.commit()

# Warts and knots on the hide: big ones down the back of the crown, small ones scattered.
func _build_lumps() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 87
	noise.frequency = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1798
	for i in 15:
		var ang := rng.randf_range(-2.2, 2.2)
		var f := rng.randf_range(0.4, 0.9)
		var size := rng.randf_range(0.4, 0.85)
		if i < 6:
			# A ragged ridge down the back of the crown.
			ang = rng.randf_range(-0.22, 0.22)
			f = 0.94 - 0.085 * float(i)
			size = 0.8 - 0.07 * float(i)
		var at := _mantle_point(ang, f, noise)
		var lump := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = size
		m.height = size * 0.75
		m.radial_segments = 7
		m.rings = 4
		lump.mesh = m
		lump.material_override = _lump_mat
		lump.position = at * 0.975
		lump.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
		_head.add_child(lump)

# One eye: a turret of hide standing off the mantle, the pale eyeball set in it with a
# slot of a pupil, and two heavy lids that close over it.
func _build_eye(side: float) -> void:
	var rig := Node3D.new()
	rig.position = Vector3(EYE_AT.x * side, EYE_AT.y, EYE_AT.z)
	var gaze := Vector3(0.46 * side, 0.34, -0.82).normalized()
	rig.basis = Basis.looking_at(gaze, Vector3.UP)
	# The brows slant down toward the middle of the face.
	rig.rotate_object_local(Vector3.FORWARD, 0.2 * side)
	_head.add_child(rig)
	_eyes.append(rig)
	var turret := _ball(rig, EYE_RADIUS * 1.5, _lump_mat, Vector3(0.0, -0.05, EYE_RADIUS * 0.72))
	_flash_meshes.append(turret)
	_ball(rig, EYE_RADIUS, _eye_mat, Vector3.ZERO)
	# The pupil is a bar right round the eye, as an octopus's is: a slot from any side.
	var pupil := _ball(rig, EYE_RADIUS * 1.02, Geo.mat(Color(0.0, 0.0, 0.0), true), Vector3.ZERO)
	pupil.scale = Vector3(1.0, 0.17, 1.0)
	_pupils.append(pupil)
	_glints.append(Look.glint(rig, Vector3(0.0, 0.0, -EYE_RADIUS * 1.15), eye * 0.5, EYE_RADIUS * 2.2))
	var pair: Array[Node3D] = []
	for upper in [true, false]:
		var hinge := Node3D.new()
		rig.add_child(hinge)
		var lid := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = EYE_RADIUS * 1.09
		m.height = EYE_RADIUS * 1.09
		m.is_hemisphere = true
		m.radial_segments = 14
		m.rings = 6
		lid.mesh = m
		lid.material_override = _lump_mat
		if not upper:
			lid.rotation.x = PI
		hinge.add_child(lid)
		pair.append(hinge)
	_lids.append(pair)

func _ball(parent: Node3D, radius: float, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 16
	m.rings = 8
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi

# Water pouring off the head while it comes up.
func _build_runoff() -> void:
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = 0.09
	_drop_mesh.height = 0.3
	_drop_mesh.radial_segments = 5
	_drop_mesh.rings = 3
	_runoff = FX.emitter(_pivot, Vector3.ZERO, _drop_mesh, Color(0.8, 0.88, 0.92, 0.85), 90, 1.3, Vector3.DOWN, 30.0, 0.5, 2.5, 9.0,
		0.8, 2.0, false, false, 0.0, Vector3(HEAD_RADIUS * 0.85, 1.6, HEAD_RADIUS * 0.95))
	if _runoff != null:
		_runoff.position = Vector3(0.0, HEAD_HEIGHT * 0.6, 0.8)
		_runoff.visibility_aabb = AABB(Vector3(-8.0, -10.0, -8.0), Vector3(16.0, 16.0, 16.0))
		_runoff.emitting = false

func _build_arms() -> void:
	_arm_mat = _wet(Look.flat_mat(Color.WHITE, 0.4))
	_arm_mat.albedo_texture = _arm_texture()
	_arm_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for r in RINGS - 1:
		var a := r * (SIDES + 1)
		var b := (r + 1) * (SIDES + 1)
		for k in SIDES:
			# Wound clockwise seen from outside, as the Eel's tube is.
			for v in [a + k, b + k + 1, b + k, a + k, a + k + 1, b + k + 1]:
				_indices.append(v)
	var last := (RINGS - 1) * (SIDES + 1)
	for k in SIDES:
		for v in [last + k, last + k + 1, RINGS * (SIDES + 1)]:
			_indices.append(v)
	for i in ARMS:
		var a := Arm.new()
		a.pts.resize(CTRL)
		a.from.resize(CTRL)
		a.to.resize(CTRL)
		a.centres.resize(RINGS)
		a.phase = float(i) * 2.399
		a.mesh = ArrayMesh.new()
		a.inst = MeshInstance3D.new()
		a.inst.mesh = a.mesh
		a.inst.material_override = _arm_mat
		a.inst.top_level = true
		a.inst.visible = false
		add_child(a.inst)
		a.inst.global_transform = Transform3D.IDENTITY
		_arms.append(a)

# The arms' hide, wrapped once round the tube: dark and blotched on the back, a pale
# belly down the side it curls toward, and two rows of suckers on that. It repeats
# along the arm, so the pattern is made to join up at every edge.
func _arm_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = 1987
	noise.frequency = 1.0
	for y in size:
		var v := (float(y) + 0.5) / float(size)
		var cv := cos(TAU * v)
		var sv := sin(TAU * v)
		for x in size:
			var u := (float(x) + 0.5) / float(size)
			var n := noise.get_noise_3d(cv * 1.2 + 7.0, sv * 1.2, cos(TAU * u) * 1.1) * 0.6 \
				+ noise.get_noise_3d(cv * 2.7, sv * 2.7 + 3.0, sin(TAU * u) * 2.2) * 0.4
			var c := skin * (1.5 + 1.8 * n)
			c = c.lerp(belly, smoothstep(0.08, 0.36, n) * 0.5)
			# The belly: centred on u = 0.75 and a little more than half way round, so
			# its pale edge shows down both flanks from above. A ragged edge.
			var w := fposmod(u + n * 0.05 - 0.25, 1.0)
			var under := smoothstep(0.2, 0.3, w) * (1.0 - smoothstep(0.7, 0.8, w))
			c = c.lerp(belly * (0.82 + 0.3 * n), under)
			for row in 2:
				var du := u - (0.665 if row == 0 else 0.835)
				var dv := (fposmod(v * float(SUCKERS) + 0.5 * float(row), 1.0) - 0.5) / float(SUCKERS)
				var d := Vector2(du, dv).length()
				c = c.lerp(belly * 1.45, smoothstep(0.062, 0.05, d))
				c = c.lerp(belly * 0.4, smoothstep(0.032, 0.02, d))
			img.set_pixel(x, y, Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

# ---- every frame ----

func _step(delta: float) -> void:
	_t += delta
	_step_rise(delta)
	_step_die(delta)
	_step_head(delta)
	_turn = Basis(Vector3.UP, _yaw)
	_emerge = smoothstep(0.3, 1.0, risen)
	for i in ARMS:
		_step_arm(i, delta)
	if not _landed.is_empty():
		var landed := _landed
		_landed = []
		for l in landed:
			slammed.emit(l[0], l[1])

func _step_rise(delta: float) -> void:
	if _rise_dir == 0.0:
		_runoff_t = maxf(0.0, _runoff_t - delta)
	else:
		var was := risen
		risen = clampf(risen + _rise_dir * delta, 0.0, 1.0)
		if _rise_dir > 0.0:
			_runoff_t = 2.5
			_splash_t -= delta
			if _splash_t <= 0.0 and risen > 0.04 and risen < 0.97:
				_splash_t = 0.16
				var a := randf() * TAU
				var at := global_position + Vector3(cos(a), 0.0, sin(a)) * randf_range(3.5, 6.5)
				_fx_breaker(at, randf_range(1.0, 1.8))
			if risen >= 1.0:
				_rise_dir = 0.0
		else:
			# The head goes under.
			if was > 0.3 and risen <= 0.3:
				_swell(2.4)
			if risen <= 0.0:
				_rise_dir = 0.0
	if _runoff != null:
		_runoff.emitting = _runoff_t > 0.0 and risen > 0.15

func _step_die(delta: float) -> void:
	if _die_t < 0.0:
		return
	_die_t += delta
	if _rise_dir == 0.0 and risen > 0.0 and _die_t >= _die_len * 0.55:
		_rise_dir = -1.0 / maxf(_die_len * 0.45, 0.1)
	if _die_t >= _die_len:
		_die_t = -1.0
		_dead = true
		_rise_dir = 0.0
		risen = 0.0
		died.emit()

func _step_head(delta: float) -> void:
	_yaw = lerp_angle(_yaw, _yaw_goal, 1.0 - exp(-TURN_RATE * delta))
	# The recoil is quick; opening its eyes again is slower.
	_blind = lerpf(_blind, 1.0 if _blind_on else 0.0, 1.0 - exp(-(9.0 if _blind_on else 2.2) * delta))
	_roar_t = maxf(0.0, _roar_t - delta)
	var into := _roar_len - _roar_t
	_roar = smoothstep(0.0, 0.35, into) * smoothstep(0.0, 0.5, _roar_t) if _roar_t > 0.0 else 0.0
	var dying := clampf(_die_t / _die_len, 0.0, 1.0) if _die_t >= 0.0 else 0.0
	var roll := smoothstep(0.25, 0.75, dying)
	var up := smoothstep(0.0, 1.0, risen)
	var y := -HEAD_SUNK * (1.0 - up) + sin(up * PI) * up * 0.9
	y += sin(_t * 0.9) * 0.22 * up
	y += 1.7 * _roar - 1.0 * _blind
	_pivot.position.y = y
	_pivot.rotation.y = _yaw + _aside * (0.55 * _blind + 0.5 * roll)
	var shudder := sin(_t * 23.0) * 0.02 * maxf(_blind, _roar)
	_head.rotation.x = 0.3 * _blind + 0.26 * _roar + 0.45 * roll + sin(_t * 0.6) * 0.02 + shudder
	_head.rotation.z = sin(_t * 0.43) * 0.025 + 0.9 * roll * _aside + shudder
	# Breathing: the mantle fills and empties.
	var breath := sin(_t * 1.1)
	_mantle.scale = Vector3(1.0 + 0.02 * breath, 1.0 - 0.018 * breath, 1.0 + 0.03 * breath)
	_pivot.visible = risen > 0.002 and not _dead
	# The eyes.
	_blink_t -= delta
	if _blink_t < -0.3:
		_blink_t = randf_range(4.0, 9.0)
	var blink := sin(clampf(-_blink_t / 0.3, 0.0, 1.0) * PI)
	var dull := maxf(_blind, smoothstep(0.1, 0.4, dying))
	var shut := clampf(maxf(maxf(dull * 0.9, blink), 0.0) - 0.25 * _roar, -0.25, 1.0)
	for pair in _lids:
		pair[0].rotation.x = lerpf(-0.42, -1.4, shut)
		pair[1].rotation.x = lerpf(0.4, -1.25, shut)
	_eye_mat.albedo_color = (eye * EYE_PALE).lerp(MILKY, dull)
	_eye_mat.emission = eye.lerp(MILKY, dull)
	_eye_mat.emission_energy_multiplier = lerpf(EYE_GLOW, 0.0, dull)
	var pale := Color.WHITE.lerp(BLANCH, _blind)
	_head_mat.albedo_color = pale
	_arm_mat.albedo_color = pale
	_lump_mat.albedo_color = skin * 1.7 * pale
	for p in _pupils:
		p.visible = dull < 0.5
	for g in _glints:
		g.visible = dull < 0.4
	# A blow landing.
	if _flash_t > 0.0 or _flash_meshes[0].material_overlay != null:
		_flash_t -= delta
		for m in _flash_meshes:
			m.material_overlay = _flash_mat if _flash_t > 0.0 else null

# ---- the arms ----

func _root(i: int) -> Vector3:
	var a := deg_to_rad(float(ARM_ANGLES[i]))
	var out := _turn * Vector3(sin(a), 0.0, -cos(a))
	return global_position + out * ARM_ROOT_AT + Vector3(0.0, -ARM_ROOT_DEPTH - (1.0 - _emerge) * 3.0, 0.0)

func _arm_shows(a: Arm) -> bool:
	return a.inst.visible and a.drawn

# How thick the arm is at s along it (0 the root, 1 the tip). A stump keeps the
# thickness it was cut at, and ends blunt.
func _radius(a: Arm, s: float, share: float) -> float:
	if a.stump:
		return lerpf(ARM_THICK, ARM_TIP, pow(s * maxf(share, STUMP), TAPER)) * (1.0 - 0.3 * smoothstep(0.9, 1.0, s))
	return lerpf(ARM_THICK, ARM_TIP, pow(s, TAPER)) * lerpf(0.5, 1.0, share)

func _step_arm(i: int, delta: float) -> void:
	var a := _arms[i]
	var ang := deg_to_rad(float(ARM_ANGLES[i]))
	var out := _turn * Vector3(sin(ang), 0.0, -cos(ang))
	var root := _root(i)
	a.out = out
	# The sever and the regrowing run on whatever else is going on.
	match a.act:
		Act.THRASH:
			a.act_t += delta
			a.grown = move_toward(a.grown, STUMP, delta * 4.0)
			a.spray_t -= delta
			if a.spray_t <= 0.0 and a.inst.visible:
				a.spray_t = 0.13
				_fx_spray(a.pts[CTRL - 1], out)
			if a.act_t >= SEVER_THRASH:
				a.act = Act.WITHDRAW
				a.act_t = 0.0
				_fx_splash(Vector3(root.x, Terrain.SEA_LEVEL, root.z) + out * 2.5, 1.8)
		Act.WITHDRAW:
			a.act_t += delta
			if a.act_t >= SEVER_WITHDRAW:
				a.act = Act.GONE
				a.grown = 0.0
		Act.REGROW:
			a.grown = minf(1.0, a.grown + delta / a.act_len)
			if a.grown >= 1.0:
				a.act = Act.NONE
	var share := a.grown * _emerge
	if a.act == Act.GONE or share < 0.03 or _dead:
		# Under, and not drawn: keep its points folded at the root for when it comes out.
		_pose_under(root, out)
		for k in CTRL:
			a.pts[k] = _goal[k]
		a.inst.visible = false
		a.drawn = false
		return
	a.inst.visible = true
	var moved := 0.0
	var slack := _blind_on or (_die_t >= 0.0 and _die_t >= _fall_at[i])
	if a.act == Act.THRASH:
		_pose_thrash(a, root, out, share)
		moved = _follow(a, root, 9.0, delta)
	elif a.act == Act.WITHDRAW:
		_pose_under(root, out)
		moved = _follow(a, root, 4.5, delta)
	elif slack:
		moved = _drop(a, root, share, delta)
	elif a.act == Act.WINDUP:
		a.act_t += delta
		_pose_windup(a, root, out, share)
		moved = _follow(a, root, 5.0 / a.act_len, delta)
		if a.act_t >= a.act_len:
			a.act = Act.STRIKE
			a.act_t = 0.0
			for k in CTRL:
				a.from[k] = a.pts[k]
			_pose_lie(a, root, out, share)
			for k in CTRL:
				a.to[k] = _goal[k]
	elif a.act == Act.STRIKE:
		a.act_t += delta
		var k_t := clampf(a.act_t / SLAM_TIME, 0.0, 1.0)
		a.pts[0] = root
		for k in range(1, CTRL):
			# A whip: the root leads and the tip comes last and fastest.
			var s := float(k) / float(CTRL - 1)
			a.pts[k] = a.from[k].lerp(a.to[k], pow(k_t, lerpf(1.5, 3.2, s)))
		moved = 1.0
		if k_t >= 1.0:
			a.act = Act.LIE
			a.act_t = 0.0
			var at := a.to[CTRL - 1]
			_landed.append([i, at])
			_fx_impact(at)
	elif a.act == Act.LIE:
		a.act_t += delta
		for k in CTRL:
			_goal[k] = a.to[k]
		moved = _follow(a, root, 20.0, delta)
		if a.act_t >= SLAM_LIE:
			a.act = Act.NONE
	elif _die_t >= 0.0:
		_pose_thrash(a, root, out, share)
		moved = _follow(a, root, 6.0, delta)
	elif _roar > 0.02:
		_pose_spread(a, root, out, share)
		moved = _follow(a, root, 4.0, delta)
	elif a.order == Order.REACH:
		_pose_reach(a, root, out, share)
		moved = _follow(a, root, 1.5, delta)
	else:
		_pose_idle(a, root, out, share)
		moved = _follow(a, root, 1.6, delta)
	if not slack:
		a.fall = 0.0
	# Lying still (slack in the water or on the ground): the tube stands as it is.
	if moved < 0.00001 and a.drawn:
		return
	_draw_arm(a, share)

# Eases the arm's points toward the pose in _goal, never through the ground. Returns
# the furthest any point moved, squared.
func _follow(a: Arm, root: Vector3, rate: float, delta: float) -> float:
	var moved := 0.0
	a.pts[0] = root
	a.near_land = false
	for k in range(1, CTRL):
		var s := float(k) / float(CTRL - 1)
		var p := a.pts[k].lerp(_goal[k], 1.0 - exp(-rate * lerpf(1.5, 0.85, s) * delta))
		var ground := Terrain.height_at(p.x, p.z)
		if ground > Terrain.SEA_LEVEL - 1.4:
			a.near_land = true
			p.y = maxf(p.y, ground + 0.5 * lerpf(ARM_THICK, ARM_TIP, s))
		moved = maxf(moved, p.distance_squared_to(a.pts[k]))
		a.pts[k] = p
	return moved

# Slack: every point falls where it is, onto the ground or to lie awash in the water.
func _drop(a: Arm, root: Vector3, share: float, delta: float) -> float:
	var moved := 0.0
	a.fall += 13.0 * delta
	a.pts[0] = root
	a.near_land = false
	for k in range(1, CTRL):
		var s := float(k) / float(CTRL - 1)
		var p := a.pts[k]
		var ground := Terrain.height_at(p.x, p.z)
		if ground > Terrain.SEA_LEVEL - 1.4:
			a.near_land = true
		var rest := maxf(ground, Terrain.SEA_LEVEL - 0.45) + 0.6 * _radius(a, s, share)
		if p.y > rest:
			p.y = maxf(rest, p.y - a.fall * delta)
		elif p.y < rest:
			p.y = minf(rest, p.y + 1.5 * delta)
		moved = maxf(moved, p.distance_squared_to(a.pts[k]))
		a.pts[k] = p
	return moved

# A reach or a slam can only go as far as the arm is long.
func _within_reach(root: Vector3, target: Vector3, share: float) -> Vector3:
	var v := target - root
	var most := ARM_LEN * share * 0.97
	return root + v * (most / v.length()) if v.length() > most else target

# How an arm leaves the body: outwards first, whatever it is after.
func _push(out: Vector3, s: float) -> Vector3:
	return out * (OUT_PUSH * 6.0 * s * (1.0 - s) * (1.0 - s))

func _pose_under(root: Vector3, out: Vector3) -> void:
	for k in CTRL:
		var s := float(k) / float(CTRL - 1)
		_goal[k] = root + out * (s * 2.5) + Vector3(0.0, -1.8 - 1.2 * s, 0.0)

# Idling: lying out in the water, rolling in the swell, humps breaking the surface and
# now and then a tip lifting clear.
func _pose_idle(a: Arm, root: Vector3, out: Vector3, share: float) -> void:
	var lat := Vector3(-out.z, 0.0, out.x)
	var lift := pow(maxf(0.0, sin(_t * 0.31 + a.phase * 3.0)), 3.0)
	for k in CTRL:
		var s := float(k) / float(CTRL - 1)
		var sway := sin(s * 5.0 - _t * 0.55 + a.phase) * 3.2 * s + sin(_t * 0.23 + a.phase * 1.7) * 2.2 * s * s
		var p := root + out * (s * IDLE_REACH * share) + lat * sway * share
		p.y = Terrain.SEA_LEVEL + 0.1 + 0.7 * sin(s * 7.0 - _t * 0.9 + a.phase * 2.0) * (0.3 + 0.7 * s)
		p.y += (0.8 + lift * 3.4) * smoothstep(0.6, 1.0, s) * share
		p.y -= (1.0 - _emerge) * 2.0
		_goal[k] = p

# Reaching: up out of the water, over in an arch, and down to hold near the point,
# writhing slowly all the while.
func _pose_reach(a: Arm, root: Vector3, out: Vector3, share: float) -> void:
	var target := _within_reach(root, a.order_at, share)
	var v := target - root
	var flat := Vector3(v.x, 0.0, v.z)
	var dir := flat.normalized() if flat.length() > 0.01 else out
	var lat := Vector3(-dir.z, 0.0, dir.x)
	var arch := clampf((ARM_LEN * share - v.length()) * 0.5 + 2.2, 2.2, 9.0)
	for k in CTRL:
		var s := float(k) / float(CTRL - 1)
		var bow := sin(PI * pow(s, 0.8))
		var p := root.lerp(target, s) + _push(out, s) * share
		p.y += arch * bow + sin(s * 4.0 + _t * 0.8 + a.phase) * 0.5 * bow
		p += lat * sin(s * 6.0 - _t * 1.1 + a.phase) * 1.3 * bow
		_goal[k] = p
	# The tip feels about where it is held.
	_goal[CTRL - 1] += Vector3(cos(_t * 1.3 + a.phase), 0.4 * sin(_t * 1.9 + a.phase), sin(_t * 1.3 + a.phase)) * 0.45

# The tell before a slam: the arm reared up in a tall hook, its tip hanging over the
# way to the target, shaking harder as the blow comes.
func _pose_windup(a: Arm, root: Vector3, out: Vector3, share: float) -> void:
	var target := _within_reach(root, a.slam_at, share)
	var flat := Vector3(target.x - root.x, 0.0, target.z - root.z)
	var dist := flat.length()
	var dir := flat / dist if dist > 0.01 else out
	var lat := Vector3(-dir.z, 0.0, dir.x)
	var top := clampf(8.0 + 0.3 * dist, 9.0, 14.0) * share
	var lifted := maxf(0.0, target.y - Terrain.SEA_LEVEL)
	var quiver := 0.12 + 0.3 * smoothstep(0.4, 1.0, a.act_t / a.act_len)
	for k in CTRL:
		var s := float(k) / float(CTRL - 1)
		var p := root + dir * (dist * 0.72 * pow(s, 1.2)) + _push(out, s) * share
		p.y = root.y + top * sin(PI * 0.86 * pow(s, 0.7)) + lifted * s
		p += lat * sin(_t * 31.0 + s * 9.0) * quiver * s
		_goal[k] = p

# Where a slam ends: flat out along the ground (or awash) from the root to the target.
func _pose_lie(a: Arm, root: Vector3, out: Vector3, share: float) -> void:
	var target := _within_reach(root, a.slam_at, share)
	for k in CTRL:
		var s := float(k) / float(CTRL - 1)
		var p := root.lerp(target, s) + _push(out, s) * (0.4 * share)
		var rest := maxf(Terrain.height_at(p.x, p.z), Terrain.SEA_LEVEL - 0.45) + 0.6 * _radius(a, s, share)
		p.y = maxf(rest, lerpf(root.y, target.y, pow(s, 2.5)))
		_goal[k] = p

# The roar: every arm flung up and out, shaking.
func _pose_spread(a: Arm, root: Vector3, out: Vector3, share: float) -> void:
	var lat := Vector3(-out.z, 0.0, out.x)
	for k in CTRL:
		var s := float(k) / float(CTRL - 1)
		var p := root + out * (s * 14.0 * share) + lat * sin(_t * 9.0 + s * 5.0 + a.phase) * 0.9 * s
		p.y = root.y + 11.5 * share * sin(PI * 0.6 * s) + sin(_t * 11.0 + a.phase + s * 3.0) * 0.4 * s
		_goal[k] = p

# Thrashing: a cut stump, or the arms of a dying animal.
func _pose_thrash(a: Arm, root: Vector3, out: Vector3, share: float) -> void:
	var lat := Vector3(-out.z, 0.0, out.x)
	var length := ARM_LEN * 0.75 * share
	for k in CTRL:
		var s := float(k) / float(CTRL - 1)
		var p := root + out * (s * length * 0.7) + lat * sin(_t * 8.0 + s * 4.0 + a.phase) * 0.3 * length * s
		p.y = root.y + 1.5 * s + length * 0.55 * s * absf(sin(_t * 6.3 + a.phase + s * 2.0))
		_goal[k] = p

# One smooth tapering tube through the arm's points: Catmull-Rom for the centre line,
# and a frame carried along it from the root so the belly stays on the inside of every
# curl, wherever the arm goes.
func _draw_arm(a: Arm, share: float) -> void:
	var n := CTRL - 1
	for r in RINGS:
		var f := float(r) / float(RINGS - 1) * float(n)
		var i := mini(int(f), n - 1)
		var u := f - float(i)
		var p0 := a.pts[maxi(i - 1, 0)]
		var p1 := a.pts[i]
		var p2 := a.pts[i + 1]
		var p3 := a.pts[mini(i + 2, n)]
		var c := 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)
		if a.near_land:
			# The curve between two points can dip into a cliff: lift it clear.
			var ground := Terrain.height_at(c.x, c.z)
			if ground > Terrain.SEA_LEVEL - 1.4:
				c.y = maxf(c.y, ground + 0.5 * _radius(a, float(r) / float(RINGS - 1), share))
		a.centres[r] = c
	var count := RINGS * (SIDES + 1) + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(count)
	norms.resize(count)
	uvs.resize(count)
	var tan_was := a.out
	var up := Vector3.UP
	var tan := a.out
	var along := 0.0
	var rad := ARM_THICK
	var at := 0
	for r in RINGS:
		var c := a.centres[r]
		var d := a.centres[mini(r + 1, RINGS - 1)] - a.centres[maxi(r - 1, 0)]
		if d.length_squared() > 0.000001:
			tan = d.normalized()
		up = Quaternion(tan_was, tan) * up
		tan_was = tan
		var side := tan.cross(up)
		side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
		up = side.cross(tan)
		rad = _radius(a, float(r) / float(RINGS - 1), share)
		if r > 0:
			# So the suckers stay round and shrink with the arm toward its tip.
			along += c.distance_to(a.centres[r - 1]) / (TAU * rad)
		for k in SIDES + 1:
			var normal := side * _ring_cos[k] + up * _ring_sin[k]
			verts[at] = c + normal * rad
			norms[at] = normal
			uvs[at] = Vector2(float(k) / float(SIDES), along)
			at += 1
	# The tip's cap (a stump's is the pale flesh of the cut).
	verts[at] = a.centres[RINGS - 1] + tan * rad * 0.7
	norms[at] = tan
	uvs[at] = Vector2(0.75, along)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	a.mesh.clear_surfaces()
	a.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	a.drawn = true

# ---- water and spray ----
# Every machine makes its own (the body is only looks), so none of it goes over the network.

func _fx_splash(at: Vector3, size: float) -> void:
	if not is_inside_tree():
		return
	var was := FX.ambient
	FX.ambient = true
	FX.splash(get_parent(), at, size)
	FX.ambient = was

func _fx_breaker(at: Vector3, size: float) -> void:
	if is_inside_tree():
		FX.breaker(get_parent(), Vector3(at.x, Terrain.SEA_LEVEL, at.z), size)

func _fx_spray(at: Vector3, dir: Vector3) -> void:
	if not is_inside_tree():
		return
	var was := FX.ambient
	FX.ambient = true
	FX.spray(get_parent(), at, dir, ICHOR)
	FX.ambient = was
	# Big enough to see from the lamp room.
	FX.emitter(get_parent(), at, _drop_mesh, Color(ICHOR.r, ICHOR.g, ICHOR.b, 0.95), 16, 0.9, (dir + Vector3.UP).normalized(), 50.0, 3.0, 8.0, 9.0, 1.2, 2.6)

# The swell as it breaks the surface or goes under: a ring of white water round it.
func _swell(size: float) -> void:
	for i in 8:
		var a := TAU * float(i) / 8.0
		_fx_splash(global_position + Vector3(cos(a), 0.0, sin(a)) * HEAD_RADIUS * 1.1, size)

# A slam landing: white water in the sea, a burst of dirt and stones on land.
func _fx_impact(at: Vector3) -> void:
	if not is_inside_tree():
		return
	if Terrain.height_at(at.x, at.z) < Terrain.SEA_LEVEL:
		_fx_breaker(at, 1.6)
		return
	var puff := FX.emitter(get_parent(), at + Vector3(0.0, 0.3, 0.0), FX._puff_mesh_ref(), Color(0.5, 0.46, 0.4, 0.5), 10, 1.2,
		Vector3.UP, 85.0, 1.5, 4.0, 0.5, 1.0, 2.2, true, true)
	if puff != null:
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
