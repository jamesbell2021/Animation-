class_name Gull
extends Node3D
## One herring gull: white head and body, pale grey back and wings, black wingtips with
## white spots, a yellow bill and pink legs. It flies (soaring with its wings in a
## shallow M, flapping when it climbs or slows), lands on a perch, stands with its wings
## folded and its black primaries crossed over its tail, and takes off again. GullFlocks
## decides where it goes; this does the flying.

enum Mode { GONE, FLY, PERCH }

const SPEED := 6.5
const ACCEL := 9.0
const FLAP_HZ := 3.6
## Standing, its body's middle is this high off the ground.
const STAND := 0.17

const WHITE := Color(0.95, 0.95, 0.93)
const MANTLE := Color(0.66, 0.70, 0.74)
const BLACK := Color(0.08, 0.08, 0.09)
const BILL := Color(0.95, 0.78, 0.18)
const LEGS := Color(0.86, 0.62, 0.58)

var mode := Mode.GONE
var vel := Vector3.ZERO
## Where it's flying: "orbit" round orbit_c, to "perch", "leave" for good, or "dive" at someone.
var task := "orbit"
var orbit_c := Vector3.ZERO
var orbit_r := 8.0
var orbit_w := 0.4
var orbit_a := 0.0
var perch := Vector3.ZERO
var perch_yaw := 0.0
var perch_id := -1
var victim: Node3D
var leave_dir := Vector3.FORWARD
var task_t := 0.0
## What GullFlocks has it doing (colony, loafer, flock n...), and its own clock.
var role := ""
var flock := -1
var timer := 0.0

var _flap := 0.0
var _flapping := 0.0
var _flap_burst := 0.0
var _yaw := 0.0
var _roll := 0.0
var _idle_t := 0.0
var _pose_t := 0.0
var _pose := ""
var _body: Node3D
var _wing_in: Array[Node3D] = []
var _wing_out: Array[Node3D] = []
var _folded: Node3D
var _legs: Node3D

static var _meshes := {}
static var _mat: StandardMaterial3D

func _ready() -> void:
	_build()
	_flap = randf() * TAU
	visible = false

# ---- orders ----

func appear(at: Vector3) -> void:
	global_position = at
	vel = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized() * SPEED
	mode = Mode.FLY
	visible = true
	_show_flying(true)

func orbit(c: Vector3, r: float, w: float) -> void:
	if mode == Mode.PERCH:
		_take_off()
	task = "orbit"
	orbit_c = c
	orbit_r = r
	orbit_w = w
	orbit_a = atan2(global_position.x - c.x, global_position.z - c.z)
	task_t = 0.0

func land_at(p: Vector3, yaw: float, id: int) -> void:
	if mode == Mode.PERCH:
		_take_off()
	task = "perch"
	perch = p
	perch_yaw = yaw
	perch_id = id
	task_t = 0.0

func leave(dir: Vector3) -> void:
	if mode == Mode.GONE:
		return
	if mode == Mode.PERCH:
		_take_off()
	task = "leave"
	leave_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	task_t = 0.0

func dive(at: Node3D) -> void:
	if mode != Mode.FLY:
		return
	task = "dive"
	victim = at
	task_t = 0.0

func is_perched() -> bool:
	return mode == Mode.PERCH

func _take_off() -> void:
	mode = Mode.FLY
	perch_id = -1
	vel = Vector3(-sin(_yaw), 0.0, -cos(_yaw)) * 2.0 + Vector3(0.0, 3.2, 0.0)
	_flap_burst = 1.2
	_show_flying(true)
	rotation = Vector3(0.0, _yaw, 0.0)

# ---- flying ----

func _process(delta: float) -> void:
	if mode == Mode.GONE:
		return
	task_t += delta
	timer -= delta
	if mode == Mode.PERCH:
		_stand(delta)
		return
	var target := global_position
	var speed := SPEED
	match task:
		"orbit":
			orbit_a += orbit_w * delta
			target = orbit_c + Vector3(sin(orbit_a), 0.0, cos(orbit_a)) * orbit_r + Vector3(0.0, sin(orbit_a * 2.3) * 0.8, 0.0)
		"perch":
			target = perch + Vector3(0.0, STAND, 0.0)
			var d := global_position.distance_to(target)
			# Come in from above and slow down to land.
			if d > 2.5:
				target += Vector3(0.0, minf(d * 0.35, 3.0), 0.0)
			speed = clampf(d * 1.6, 1.0, SPEED)
			if d < 0.3 or (d < 0.8 and task_t > 25.0):
				_land()
				return
		"leave":
			target = global_position + leave_dir * 20.0 + Vector3(0.0, 6.0 if global_position.y < 28.0 else 0.0, 0.0)
			speed = SPEED * 1.15
			if task_t > 16.0:
				mode = Mode.GONE
				visible = false
				return
		"dive":
			if victim == null or not is_instance_valid(victim) or task_t > 2.5:
				task = "orbit"
			else:
				target = victim.global_position + Vector3(0.0, 2.4, 0.0)
				speed = SPEED * 1.25
				if global_position.distance_to(target) < 1.0:
					task = "orbit"
					vel.y += 4.0
	var want := (target - global_position)
	want = want.normalized() * speed if want.length() > 0.05 else Vector3.ZERO
	vel = vel.move_toward(want, ACCEL * delta)
	global_position += vel * delta
	# Never into the ground or the sea.
	var floor_y := maxf(Terrain.height_at(global_position.x, global_position.z), Terrain.SEA_LEVEL) + 0.35
	if global_position.y < floor_y and task != "perch":
		global_position.y = floor_y
		vel.y = maxf(vel.y, 1.0)
	_orient(delta)
	_wings(delta)

func _orient(delta: float) -> void:
	var flat := Vector2(vel.x, vel.z)
	if flat.length() > 0.3:
		var yaw := atan2(-vel.x, -vel.z)
		var turn := angle_difference(_yaw, yaw) / maxf(delta, 0.001)
		_yaw = yaw
		_roll = lerpf(_roll, clampf(-turn * 0.22, -0.8, 0.8), minf(1.0, delta * 4.0))
	var pitch := clampf(atan2(vel.y, maxf(flat.length(), 0.1)) * 0.6, -0.5, 0.5)
	rotation = Vector3(pitch, _yaw, _roll)

func _wings(delta: float) -> void:
	# Flap climbing, slow, or in a burst now and then; otherwise soar.
	_flap_burst -= delta
	if _flap_burst < -randf_range(3.0, 7.0):
		_flap_burst = randf_range(0.8, 1.6)
	var flap_want := 1.0 if vel.y > 0.6 or Vector2(vel.x, vel.z).length() < 3.5 or _flap_burst > 0.0 or task == "perch" else 0.0
	_flapping = move_toward(_flapping, flap_want, delta * 3.0)
	_flap += delta * TAU * FLAP_HZ * (1.0 + 0.3 * _flapping)
	var beat := sin(_flap) * 0.85 * _flapping
	# Soaring, the arm raised a little and the hand bent down: the gull's M.
	var inner := 0.12 * (1.0 - _flapping) + beat
	var outer := -0.22 * (1.0 - _flapping) + sin(_flap - 0.6) * 0.35 * _flapping
	if task == "perch" and global_position.distance_to(perch) < 1.4:
		# Flaring to land: wings up and back, legs down.
		inner = 0.9
		outer = 0.3
		_legs.visible = true
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		_wing_in[i].rotation.z = s * inner
		_wing_out[i].rotation.z = s * outer

func _land() -> void:
	mode = Mode.PERCH
	global_position = perch + Vector3(0.0, STAND, 0.0)
	_yaw = perch_yaw
	rotation = Vector3(0.0, _yaw, 0.0)
	vel = Vector3.ZERO
	_show_flying(false)
	_idle_t = randf_range(1.0, 4.0)

func _stand(delta: float) -> void:
	_idle_t -= delta
	_pose_t -= delta
	if _pose_t <= 0.0 and _pose != "":
		_pose = ""
		_show_flying(false)
		_body.rotation = Vector3.ZERO
	if _idle_t <= 0.0:
		_idle_t = randf_range(2.0, 6.0)
		var r := randf()
		if r < 0.45:
			# Turn about.
			_yaw += randf_range(-1.2, 1.2)
		elif r < 0.65:
			# The long call: head thrown back.
			_pose = "call"
			_pose_t = 1.3
		elif r < 0.75:
			# A stretch of the wings.
			_pose = "stretch"
			_pose_t = 0.9
	rotation.y = lerp_angle(rotation.y, _yaw, minf(1.0, delta * 5.0))
	match _pose:
		"call":
			_body.rotation.x = lerpf(_body.rotation.x, 0.55, minf(1.0, delta * 8.0))
		"stretch":
			_wing_in[0].get_parent().visible = true
			_folded.visible = false
			for i in 2:
				var s := 1.0 if i == 0 else -1.0
				_wing_in[i].rotation.z = s * 1.1
				_wing_out[i].rotation.z = s * 0.3

func _show_flying(on: bool) -> void:
	_wing_in[0].get_parent().visible = on
	_folded.visible = not on
	_legs.visible = not on
	_body.rotation = Vector3.ZERO

# ---- the bird ----

func _build() -> void:
	if _meshes.is_empty():
		_make_meshes()
	_body = Node3D.new()
	add_child(_body)
	_mi(_body, "body")
	_mi(_body, "bill")
	var wings := Node3D.new()
	_body.add_child(wings)
	for i in 2:
		var s := 1.0 if i == 0 else -1.0
		var shoulder := Node3D.new()
		shoulder.position = Vector3(s * 0.05, 0.03, -0.02)
		shoulder.scale = Vector3(s, 1.0, 1.0)
		wings.add_child(shoulder)
		_mi(shoulder, "wing_in")
		var wrist := Node3D.new()
		wrist.position = Vector3(0.34, 0.0, 0.0)
		shoulder.add_child(wrist)
		_mi(wrist, "wing_out")
		_wing_in.append(shoulder)
		_wing_out.append(wrist)
	_folded = Node3D.new()
	_body.add_child(_folded)
	for s: float in [-1.0, 1.0]:
		var f := _mi(_folded, "folded")
		f.position = Vector3(s * 0.055, 0.045, 0.0)
		f.rotation.y = -s * 0.05
	_legs = Node3D.new()
	_body.add_child(_legs)
	for s: float in [-1.0, 1.0]:
		var l := _mi(_legs, "leg")
		l.position = Vector3(s * 0.03, -0.11, 0.02)
	_show_flying(true)

func _mi(parent: Node3D, key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[key]
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _make_meshes() -> void:
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.8
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The body, lofted head (-z) to tail (+z): z, half-width, half-height, lift.
	var stations := [
		[-0.33, 0.012, 0.012, 0.075], [-0.30, 0.032, 0.036, 0.08], [-0.25, 0.048, 0.05, 0.085],
		[-0.19, 0.042, 0.045, 0.06], [-0.12, 0.068, 0.07, 0.02], [0.0, 0.085, 0.082, 0.0],
		[0.12, 0.074, 0.07, 0.01], [0.24, 0.045, 0.035, 0.02], [0.36, 0.02, 0.012, 0.025],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 10
	for j in stations.size() - 1:
		for i in segs:
			var quad := []
			for corner in [[j, i], [j, i + 1], [j + 1, i + 1], [j + 1, i]]:
				var row: Array = stations[corner[0]]
				var a := TAU * float(corner[1]) / float(segs)
				quad.append(Vector3(cos(a) * float(row[1]), sin(a) * float(row[2]) + float(row[3]), float(row[0])))
			for k in [0, 1, 2, 0, 2, 3]:
				var v: Vector3 = quad[k]
				# Grey on the back between the wings; white everywhere else.
				var back := v.y > float(stations[5][3]) + 0.035 and v.z > -0.1 and v.z < 0.3
				st.set_color(MANTLE if back else WHITE)
				st.add_vertex(v)
	# The tail: a short white fan.
	for k in [[Vector3(-0.045, 0.02, 0.26), Vector3(0.045, 0.02, 0.26), Vector3(0.06, 0.025, 0.42)], [Vector3(-0.045, 0.02, 0.26), Vector3(0.06, 0.025, 0.42), Vector3(-0.06, 0.025, 0.42)]]:
		for v in k:
			st.set_color(WHITE)
			st.add_vertex(v)
	# An eye each side.
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * 0.047, 0.1, -0.27)
		for v in [c + Vector3(0, 0.008, 0), c + Vector3(0, -0.006, -0.008), c + Vector3(0, -0.006, 0.008)]:
			st.set_color(BLACK)
			st.add_vertex(v)
	st.generate_normals()
	_meshes["body"] = st.commit()
	# The bill: a yellow wedge with the red spot on the lower mandible.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0.0, 0.065, -0.43)
	var base := [Vector3(-0.013, 0.08, -0.325), Vector3(0.013, 0.08, -0.325), Vector3(0.012, 0.06, -0.325), Vector3(-0.012, 0.06, -0.325)]
	for i in 4:
		var a: Vector3 = base[i]
		var b: Vector3 = base[(i + 1) % 4]
		for v in [a, b, tip]:
			st.set_color(Color(0.85, 0.2, 0.12) if i == 2 and v == tip else BILL)
			st.add_vertex(v)
	st.generate_normals()
	_meshes["bill"] = st.commit()
	# The arm of the wing: grey above, a white trailing edge.
	_meshes["wing_in"] = _wing_mesh([Vector2(0.0, -0.07), Vector2(0.34, -0.085), Vector2(0.34, 0.1), Vector2(0.0, 0.13)], 0.0)
	# The hand: grey, then black to the tip with a white mirror.
	_meshes["wing_out"] = _wing_mesh([Vector2(0.0, -0.085), Vector2(0.2, -0.07), Vector2(0.36, -0.02), Vector2(0.42, 0.05), Vector2(0.3, 0.1), Vector2(0.12, 0.11), Vector2(0.0, 0.1)], 0.18)
	# Folded: a grey blade along the back with black primaries over the tail.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade := [Vector3(0.0, 0.0, -0.08), Vector3(0.03, -0.02, 0.05), Vector3(0.02, -0.01, 0.3), Vector3(0.0, 0.0, 0.47), Vector3(-0.015, 0.0, 0.3), Vector3(-0.015, -0.01, 0.05)]
	for i in range(1, blade.size() - 1):
		for v in [blade[0], blade[i], blade[i + 1]]:
			var vv: Vector3 = v
			st.set_color(BLACK if vv.z > 0.27 else MANTLE)
			st.add_vertex(vv)
	st.generate_normals()
	_meshes["folded"] = st.commit()
	# A leg: a thin pink stick with a webbed foot.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.008, 0.06, 0.0), Vector3(0.008, 0.06, 0.0), Vector3(0.008, -0.06, 0.0), Vector3(-0.008, 0.06, 0.0), Vector3(0.008, -0.06, 0.0), Vector3(-0.008, -0.06, 0.0),
			Vector3(0.0, -0.06, 0.01), Vector3(-0.03, -0.06, -0.05), Vector3(0.03, -0.06, -0.05)]:
		st.set_color(LEGS)
		st.add_vertex(v)
	st.generate_normals()
	_meshes["leg"] = st.commit()

# A flat wing part from its outline (x out from the joint, z back), coloured black past
# `black_from` (0 for none) with a white spot near the tip.
static func _wing_mesh(outline: Array, black_from: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= float(outline.size())
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		for p in [c, a, b]:
			var q: Vector2 = p
			var col := MANTLE
			if black_from > 0.0 and q.x > black_from:
				col = BLACK
				if q.x > 0.32 and q.x < 0.38 and q.y > 0.0 and q.y < 0.06:
					col = WHITE
			elif q.y > 0.09:
				col = WHITE
			st.set_color(col)
			st.add_vertex(Vector3(q.x, 0.0, q.y))
	st.generate_normals()
	return st.commit()
