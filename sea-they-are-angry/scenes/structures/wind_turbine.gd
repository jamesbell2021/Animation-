class_name WindTurbine
extends Structure
## The camp's wind turbine: an early-1980s Danish-style machine put up on the holm's
## north-west knoll, outside the wire, long after the camp's war. Three white blades on
## an upwind rotor, a cream glass-fibre nacelle that turns to face the wind, a galvanised
## lattice tower, and a control cabinet at its foot, from which the cable runs on poles
## to the compound. It powers the strings of lights round the wire (Camp).
##
## Creatures raiding the holm go for it. Every blow makes the lights blink; badly
## damaged it smokes and the lights flicker; wrecked, a blade hangs broken, the rotor
## stops, and the compound goes dark until it's mended (scrap, at the cabinet).

## Something hit it: the lights blink (on the LAN too: it comes with the host's health).
signal struck

const TOWER_H := 9.0
const BASE := 0.95
const TOP := 0.28
const SECTIONS := 5
const HUB_H := TOWER_H + 0.55
const BLADE := 3.6
## How fast the rotor turns (rad/s) with the wind (m/s): barely creeping in a calm,
## turning steadily in the day's breeze, racing in a gale.
const SPIN_CREEP := 0.2
const SPIN_MAX := 6.5
const WIND_FROM := 0.5
const WIND_FULL := 5.0
## The rotor's inertia: it picks up in a gust faster than it runs down.
const SPIN_UP := 1.5
const SPIN_DOWN := 0.5
## The yaw drive turns the head round to follow the wind this fast (rad/s).
const YAW_RATE := 0.25
const STEEL := Color(0.62, 0.64, 0.64)
const CREAM := Color(0.90, 0.88, 0.80)
const BLADE_WHITE := Color(0.95, 0.95, 0.93)
const CABINET := Color(0.42, 0.47, 0.42)

var rotor: Node3D
var nacelle: Node3D
var spin := 0.0
var _blades: Array[Node3D] = []
var _sound: AudioStreamPlayer3D
var _last_hp := -1
var _wobble := 0.0

func _init() -> void:
	id = "turbine"
	max_hp = 160

func _ready() -> void:
	super._ready()
	add_to_group("camp")
	_last_hp = hp
	health_changed.connect(_on_health)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Audio.stream("turbine")
	_sound.bus = "SFX"
	_sound.unit_size = 8.0
	_sound.max_distance = 50.0
	_sound.volume_db = -12.0
	_sound.position = Vector3(0.0, HUB_H, 0.0)
	add_child(_sound)
	_sound.play()
	# Face the wind, and already turning, from the start.
	nacelle.rotation.y = _into_wind()
	spin = spin_for(Weather.wind_now.length())

func display_name() -> String:
	return "the wind turbine"

func repair_cost() -> Dictionary:
	return {"scrap": 2}

func smoke_point() -> Vector3:
	return Vector3(0.0, HUB_H + 0.2, 0.4)

## Generating: standing, so the lights have power.
func generating() -> bool:
	return not is_destroyed()

func _on_health(new_hp: int, _max: int) -> void:
	if _last_hp >= 0 and new_hp < _last_hp:
		struck.emit()
	_last_hp = new_hp

func _on_damaged() -> void:
	if is_inside_tree():
		FX.sparks(get_parent(), global_position + Vector3(0.0, 1.0, 0.0))
		Audio.sfx("hit", global_position, -4.0, 0.15)
		Audio.sfx("crackle", global_position + Vector3(0.0, 1.0, 0.0), -6.0, 0.2)

# To the tower's legs, where creatures tear at it and keepers mend it at the cabinet.
func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - BASE)
	var dz := maxf(0.0, absf(local.z) - BASE)
	return Vector2(dx, dz).length()

# The way the rotor should face: into the wind (it's an upwind machine).
static func _into_wind() -> float:
	var w := Weather.wind_now
	if Vector2(w.x, w.z).length() < 0.05:
		w = Weather.WIND_DIR
	return atan2(w.x, w.z)

## The rotor's speed for a wind of `w` m/s.
static func spin_for(w: float) -> float:
	return SPIN_CREEP + clampf((w - WIND_FROM) / (WIND_FULL - WIND_FROM), 0.0, 1.0) * (SPIN_MAX - SPIN_CREEP)

func _process(delta: float) -> void:
	if rotor == null:
		return
	# The yaw drive: steadily round to face the wind as it veers and backs.
	if not is_destroyed():
		nacelle.rotation.y = rotate_toward(nacelle.rotation.y, _into_wind(), YAW_RATE * delta)
	var want := 0.0
	if not is_destroyed():
		want = spin_for(Weather.wind_now.length())
		if health_ratio() < 0.5:
			want *= 0.7
	spin = move_toward(spin, want, delta * (SPIN_UP if want > spin else SPIN_DOWN))
	rotor.rotate_object_local(Vector3.FORWARD, spin * delta)
	# A damaged rotor runs out of true.
	_wobble += delta * spin
	nacelle.rotation.z = sin(_wobble * 1.0) * 0.03 if health_ratio() < 0.5 and not is_destroyed() else 0.0
	if _sound != null:
		_sound.pitch_scale = clampf(spin / 3.0, 0.4, 1.6)
		_sound.volume_db = -12.0 if spin > 0.2 else -80.0

func _refresh() -> void:
	if _blades.size() < 3:
		return
	var wrecked := is_destroyed()
	# Wrecked: one blade gone, another hanging off its root, the nacelle knocked askew.
	_blades[1].visible = not wrecked
	_blades[2].rotation.x = 0.9 if wrecked else 0.0
	nacelle.rotation.x = -0.12 if wrecked else 0.0

func _build() -> void:
	var steel := Look.flat_mat(STEEL, 0.55)
	steel.metallic = 0.6
	# Concrete pads under the four legs.
	var pad_mat := Look.camp("concrete", 1.0, true, 0.92)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pad := Geo.box(self, Vector3(0.5, 0.3, 0.5), Color.WHITE, Vector3(sx * BASE, 0.05, sz * BASE))
			pad.material_override = pad_mat
	# The lattice: four legs tapering in, cross-braced in each section.
	var corners := func(y: float) -> Array:
		var k := lerpf(BASE, TOP, y / TOWER_H)
		return [Vector3(-k, y, -k), Vector3(k, y, -k), Vector3(k, y, k), Vector3(-k, y, k)]
	for i in 4:
		var a: Vector3 = corners.call(0.0)[i]
		var b: Vector3 = corners.call(TOWER_H)[i]
		_bar(a, b, 0.07, steel)
	for s in SECTIONS:
		var y0 := TOWER_H * float(s) / float(SECTIONS)
		var y1 := TOWER_H * float(s + 1) / float(SECTIONS)
		var lo: Array = corners.call(y0)
		var hi: Array = corners.call(y1)
		for i in 4:
			var j := (i + 1) % 4
			_bar(lo[i], hi[j], 0.035, steel)
			_bar(lo[j], hi[i], 0.035, steel)
			_bar(hi[i], hi[j], 0.04, steel)
	# A ladder up one face.
	for r in 18:
		var y := 0.5 + float(r) * 0.48
		var k := lerpf(BASE, TOP, y / TOWER_H)
		_bar(Vector3(-0.18, y, -k - 0.02), Vector3(0.18, y, -k - 0.02), 0.02, steel)
	# The yaw platform, and the nacelle on it.
	var deck := Geo.box(self, Vector3(TOP * 2.0 + 0.5, 0.08, TOP * 2.0 + 0.5), Color.WHITE, Vector3(0.0, TOWER_H + 0.04, 0.0))
	deck.material_override = steel
	nacelle = Node3D.new()
	nacelle.position = Vector3(0.0, HUB_H, 0.0)
	add_child(nacelle)
	var glass := Look.flat_mat(CREAM, 0.45)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.36
	cap.height = 2.0
	cap.radial_segments = 12
	cap.rings = 4
	body.mesh = cap
	body.material_override = glass
	body.rotation.x = PI * 0.5
	body.position = Vector3(0.0, 0.0, 0.25)
	body.scale = Vector3(1.0, 1.0, 0.9)
	nacelle.add_child(body)
	# Cooling louvres down the side, and the maker's stripe.
	for sgn in [-1.0, 1.0]:
		var vent := Geo.box(nacelle, Vector3(0.02, 0.18, 0.5), Color(0.25, 0.27, 0.28), Vector3(sgn * 0.355, 0.05, 0.6))
		vent.material_override = Look.flat_mat(Color(0.25, 0.27, 0.28), 0.7)
		var stripe := Geo.box(nacelle, Vector3(0.02, 0.06, 1.3), Color.WHITE, Vector3(sgn * 0.36, -0.15, 0.25))
		stripe.material_override = Look.flat_mat(Color(0.70, 0.16, 0.12), 0.6)
	var anemo := Geo.cyl(nacelle, 0.015, 0.4, Color.WHITE, Vector3(0.0, 0.5, 1.0))
	anemo.material_override = steel
	# The rotor, upwind of the tower: a spinner and three blades.
	rotor = Node3D.new()
	rotor.position = Vector3(0.0, 0.0, -0.95)
	nacelle.add_child(rotor)
	var spinner := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.3
	cone.height = 0.55
	cone.radial_segments = 12
	spinner.mesh = cone
	spinner.material_override = glass
	spinner.rotation.x = -PI * 0.5
	spinner.position = Vector3(0.0, 0.0, -0.22)
	rotor.add_child(spinner)
	var blade_mesh := _blade_mesh()
	var blade_mat := Look.flat_mat(BLADE_WHITE, 0.4)
	blade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 3:
		var arm := Node3D.new()
		arm.rotation.z = TAU * float(i) / 3.0
		rotor.add_child(arm)
		var holder := Node3D.new()
		arm.add_child(holder)
		var bm := MeshInstance3D.new()
		bm.mesh = blade_mesh
		bm.material_override = blade_mat
		holder.add_child(bm)
		_blades.append(holder)
	# The control cabinet at its foot, and the cable away to the camp.
	var cab := Geo.box(self, Vector3(0.7, 1.2, 0.45), Color.WHITE, Vector3(1.4, 0.6, 0.6))
	cab.material_override = Look.flat_mat(CABINET, 0.6)
	var door := Geo.box(cab, Vector3(0.5, 0.9, 0.02), Color.WHITE, Vector3(0.0, 0.05, 0.235))
	door.material_override = Look.flat_mat(CABINET.darkened(0.15), 0.6)
	var warn := Geo.box(cab, Vector3(0.18, 0.16, 0.01), Color.WHITE, Vector3(0.0, 0.25, 0.25))
	warn.material_override = Look.flat_mat(Color(0.95, 0.8, 0.1), 0.5)
	_bar(Vector3(1.4, 0.0, 0.4), Vector3(BASE - 0.1, 0.0, 0.4), 0.04, Look.flat_mat(Color(0.1, 0.1, 0.1), 0.7))
	Geo.box_shape(self, Vector3(BASE * 2.0, 2.0, BASE * 2.0), Vector3(0.0, 1.0, 0.0))

## Where the cable leaves the cabinet, for the poles to the camp.
func cable_point() -> Vector3:
	return to_global(Vector3(1.4, 1.3, 0.6))

func _bar(a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	var m := Geo.box(self, Vector3(thick, thick, d.length()), Color.WHITE, Vector3.ZERO)
	m.material_override = mat
	# Laid along a to b in the turbine's own frame (it may not be in the tree yet).
	var up := Vector3.FORWARD if absf(d.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	m.transform = Transform3D(Basis.looking_at(d, up), (a + b) * 0.5)

# A glass-fibre blade along +y: wide near the root, tapering to the tip, a thin
# lens-shaped section that twists flatter toward the tip.
static func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stations := 9
	var rows := []
	for i in stations:
		var t := float(i) / float(stations - 1)
		var r := lerpf(0.32, BLADE, t)
		var chord := lerpf(0.42, 0.13, t) if t > 0.08 else 0.16
		var thick := chord * (0.22 if t > 0.08 else 0.9)
		var twist := lerpf(0.35, 0.05, t)
		var pts := []
		for p in [Vector2(-chord * 0.35, 0.0), Vector2(0.0, thick * 0.5), Vector2(chord * 0.65, 0.0), Vector2(0.0, -thick * 0.5)]:
			var q: Vector2 = (p as Vector2).rotated(twist)
			pts.append(Vector3(q.x, r, q.y))
		rows.append(pts)
	for i in stations - 1:
		for k in 4:
			var a: Vector3 = rows[i][k]
			var b: Vector3 = rows[i][(k + 1) % 4]
			var c: Vector3 = rows[i + 1][(k + 1) % 4]
			var d: Vector3 = rows[i + 1][k]
			for v in [a, b, c, a, c, d]:
				st.add_vertex(v)
	var tip: Array = rows[stations - 1]
	for v in [tip[0], tip[1], tip[2], tip[0], tip[2], tip[3]]:
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()
