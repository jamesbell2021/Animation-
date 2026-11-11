class_name SeaArm
extends Enemy
## A great arm out of the sea in the Mary Ann's way (the Escape, docs/ESCAPE.md). It lies
## under the water ahead, a swirl on the surface that follows her across the channel;
## near enough, it rears up out of the sea beside her course, hangs there swaying, and
## comes down across the place she will be. Steer out from under it, or put enough into
## it while it is up (arrows, the shotgun, a petrol bomb) and it goes back under.
##
## It belongs to the world that goes past her (the Escape's `world` node): its position is
## where it rose, in the world's frame. The Escape asks it where it will land
## (`impact_point`) and is told when it does (`landed`).

signal landed(arm: SeaArm, at: Vector3)

## Through the water this far ahead of her (m, her frame) it rears up, and this long
## before it reaches her it comes down.
const RISE_AT := 21.0
const RISE_TIME := 1.1
const SLAP_TIME := 0.5
const LIE_TIME := 0.9
const SINK_TIME := 1.4
## Where it rises: this far ahead of where it will land, and off to one side.
const BASE_AHEAD := 3.0
const BASE_SIDE := 4.2
## Its height when reared, and its tube.
const HEIGHT := 7.5
const RINGS := 22
const SIDES := 8
const THICK := 0.95
const TIP := 0.12
const SKIN := Color(0.16, 0.2, 0.22)
const BELLY := Color(0.72, 0.68, 0.58)
const GLOW := Color(0.35, 1.0, 0.9)
const SWIRL := Color(0.62, 0.95, 0.9)
const DANGER := Color(1.0, 0.45, 0.32)

## How wide the blow is where it lands (m).
var radius := 2.2
## The Escape: tells it how far across the boat is now (world z), and how far she has
## come (so it knows how far ahead it is).
var escape: Node
## Where it will land, in the world's frame (y at the sea).
var aim := Vector3.ZERO
var side := 1.0
var _mesh: ArrayMesh
var _inst: MeshInstance3D
var _mat: StandardMaterial3D
var _swirl: MeshInstance3D
var _swirl_mat: StandardMaterial3D
var _dots: Array[MeshInstance3D] = []
var _glow: OmniLight3D
var _tip := Vector3.ZERO
var _sway := 0.0
var _rise := 0.0
var _bubble_t := 0.0
var _slap_from := Vector3.ZERO

func _init() -> void:
	max_hp = 60
	hp = 60
	speed = 0.0
	mass = 9.0
	reach = 0.0

func _ready() -> void:
	super._ready()
	collision_layer = 0
	collision_mask = 0
	change_state(&"Lurk")

# No coming ashore: it begins under the water.
func _enter_Emerge() -> void:
	pass

func _build() -> void:
	_mat = Look.flat_mat(Color.WHITE, 0.35)
	_mat.vertex_color_use_as_albedo = true
	_mat.rim_enabled = true
	_mat.rim = 0.6
	_mat.rim_tint = 0.3
	_mesh = ArrayMesh.new()
	_inst = MeshInstance3D.new()
	_inst.mesh = _mesh
	_inst.material_override = _mat
	_inst.visible = false
	# No shadow from the moon: a long black band across the water read as the arm itself.
	_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_inst)
	# Its own cold glow on the water about it: it is seen coming in the dark.
	_glow = OmniLight3D.new()
	_glow.light_color = GLOW
	_glow.light_energy = 0.0
	_glow.omni_range = 7.0
	_glow.shadow_enabled = false
	add_child(_glow)
	# Pale glowing suckers down its underside: it reads in the dark against the fog.
	var dot_mat := Look.glow_mat(GLOW, 2.6)
	dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 7:
		var d := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11 - 0.01 * float(i)
		sm.height = sm.radius * 2.0
		sm.radial_segments = 6
		sm.rings = 3
		d.mesh = sm
		d.material_override = dot_mat
		d.visible = false
		add_child(d)
		_dots.append(d)
	# The swirl on the water where it will come down: a ring as wide as the blow.
	_swirl_mat = StandardMaterial3D.new()
	_swirl_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_swirl_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_swirl_mat.albedo_color = Color(SWIRL.r, SWIRL.g, SWIRL.b, 0.0)
	_swirl_mat.emission_enabled = true
	_swirl_mat.emission = SWIRL
	_swirl_mat.emission_energy_multiplier = 0.6
	_swirl_mat.no_depth_test = false
	# Over the fog's sheets (FogBank's render_priority is 0 to 2): the place it will come
	# down must show.
	_swirl_mat.render_priority = 10
	_swirl = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	_swirl.mesh = tm
	_swirl.material_override = _swirl_mat
	_swirl.top_level = true
	_swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_swirl)

func is_vulnerable() -> bool:
	return state == &"Rise" or state == &"Rear"

## Where it will land, in the boat's frame (the scene's).
func impact_point() -> Vector3:
	var w := get_parent() as Node3D
	return w.to_global(aim) if w != null else aim

## Whether it can be seen to be coming: reared up, or rising.
func showing() -> bool:
	return state == &"Rise" or state == &"Rear" or state == &"Slap"

func light_probe_points() -> Array:
	return [global_position + Vector3(0.0, 1.0, 0.0)]

func _physics_process(delta: float) -> void:
	state_t += delta
	_afflictions(delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	burning = maxf(0.0, burning - delta)
	var tick := "_tick_" + String(state)
	if has_method(tick):
		call(tick, delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sway += delta
	_draw()

# ---- its states ----

func _place_at_aim() -> void:
	# Where it rises: ahead of the place it lands, out to one side.
	position = aim + Vector3(BASE_AHEAD, 1.2, side * BASE_SIDE)

func _tick_Lurk(delta: float) -> void:
	# Under the water ahead, keeping across from her.
	if escape != null:
		aim.z = float(escape.call("aim_lateral", self))
	_place_at_aim()
	_bubble_t -= delta
	if _bubble_t <= 0.0:
		_bubble_t = randf_range(0.4, 0.9)
		FX.splash(get_parent(), aim + Vector3(randf_range(-1.0, 1.0), Terrain.SEA_LEVEL - aim.y, randf_range(-1.0, 1.0)), 0.3)
	if impact_point().x <= RISE_AT:
		change_state(&"Rise")

func _enter_Rise() -> void:
	_inst.visible = true
	for d in _dots:
		d.visible = true
	var at := global_position
	FX.splash(get_parent(), get_parent().to_local(Vector3(at.x, Terrain.SEA_LEVEL, at.z)), 2.4)
	Audio.sfx("wave_crash", at, 2.0, 0.1)
	Audio.sfx("groan", at, 0.0, 0.2)

func _tick_Rise(_delta: float) -> void:
	_rise = clampf(state_t / RISE_TIME, 0.0, 1.0)
	if state_t >= RISE_TIME:
		change_state(&"Rear")

func _tick_Rear(_delta: float) -> void:
	_rise = 1.0
	var speed_now: float = float(escape.get("speed")) if escape != null else 4.5
	# Down in time to meet her middle as she comes level.
	if impact_point().x <= speed_now * SLAP_TIME + 0.4:
		change_state(&"Slap")

func _enter_Slap() -> void:
	_slap_from = _tip
	Audio.sfx("swing", global_position + Vector3(0.0, 3.0, 0.0), 6.0, 0.1)

func _tick_Slap(_delta: float) -> void:
	if state_t >= SLAP_TIME:
		var p := impact_point()
		FX.splash(get_parent(), aim + Vector3(0.0, Terrain.SEA_LEVEL - aim.y, 0.0), 3.0)
		Audio.sfx("wave_crash", p, 6.0, 0.05)
		landed.emit(self, p)
		change_state(&"Lie")

func _tick_Lie(_delta: float) -> void:
	if state_t >= LIE_TIME:
		change_state(&"Sink")

func _enter_Sink() -> void:
	remove_from_group("enemies")

func _tick_Sink(_delta: float) -> void:
	_rise = 1.0 - clampf(state_t / SINK_TIME, 0.0, 1.0)
	if state_t >= SINK_TIME:
		queue_free()

func _enter_Recoil() -> void:
	remove_from_group("enemies")
	Audio.sfx("groan", global_position, 4.0, 0.2)
	FX.splash(get_parent(), get_parent().to_local(Vector3(global_position.x, Terrain.SEA_LEVEL, global_position.z)), 1.8)

func _tick_Recoil(_delta: float) -> void:
	_rise = 1.0 - clampf(state_t / 0.9, 0.0, 1.0)
	if state_t >= 0.9:
		queue_free()

## Driven back under before it comes down: no blow.
func _die() -> void:
	if state == &"Recoil":
		return
	Events.enemy_killed.emit(self)
	Events.message.emit("It goes back under!")
	change_state(&"Recoil")

# ---- how it looks ----

func _draw() -> void:
	var lurking := state == &"Lurk"
	var danger := state == &"Rear" or state == &"Rise"
	# The swirl: faint while it lurks, bright and reddening while it hangs over her.
	var sp := impact_point()
	_swirl.global_position = Vector3(sp.x, Terrain.SEA_LEVEL + 0.5, sp.z)
	_swirl.rotation.y = _sway * 1.4
	var pulse := 0.5 + 0.5 * sin(_sway * (5.0 if danger else 2.5))
	var show_swirl := lurking or danger or state == &"Slap"
	_swirl.visible = show_swirl
	if show_swirl:
		var a := (0.22 + 0.12 * pulse) if lurking else (0.5 + 0.3 * pulse)
		var c := SWIRL if lurking else SWIRL.lerp(DANGER, 0.75)
		_swirl_mat.albedo_color = Color(c.r, c.g, c.b, a)
		_swirl_mat.emission = c
		_swirl_mat.emission_energy_multiplier = 0.5 + (1.4 * pulse if danger else 0.3)
		var r := radius * (0.85 + 0.1 * pulse) if not lurking else radius * 0.7
		_swirl.scale = Vector3(r, 0.4, r)
	_glow.light_energy = 0.0 if lurking else 2.2 * _rise
	if lurking:
		return
	# The arm: up out of the water at its root, rearing, and its end curled over like a
	# hook above the place it means to come down (it reads as rearing from above).
	var root := Vector3(0.0, -2.4, 0.0)
	var target := to_local(Vector3(sp.x, Terrain.SEA_LEVEL - 0.1, sp.z))
	var flat := Vector3(target.x, 0.0, target.z)
	var h := HEIGHT * _rise
	var sway := Vector3(sin(_sway * 1.7) * 0.5, sin(_sway * 2.3) * 0.3, cos(_sway * 1.3) * 0.4)
	var b := root + Vector3(0.0, h * 0.95, 0.0) - flat * 0.1
	var c := Vector3(0.0, h * 1.15 - 1.2, 0.0) + flat * 0.55 + sway
	var d := Vector3(0.0, h * 0.62 - 1.2, 0.0) + flat * 0.8 + sway * 1.4
	match state:
		&"Slap":
			var k := clampf(state_t / SLAP_TIME, 0.0, 1.0)
			k = k * k
			d = _slap_from.lerp(target, k)
			c = c.lerp(target * 0.6 + Vector3(0.0, 2.0, 0.0), k)
			b = b.lerp(root.lerp(target, 0.3) + Vector3(0.0, 3.0, 0.0), k)
		&"Lie", &"Sink":
			var sink := (_rise - 1.0) * 2.5
			d = target + Vector3(0.0, sink, 0.0)
			c = target * 0.6 + Vector3(0.0, 1.0 + sink, 0.0)
			b = root.lerp(target, 0.3) + Vector3(0.0, 2.2 + sink, 0.0)
	_tip = d
	_build_tube(root, b, c, d)

func _bez(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u * u) + b * (3.0 * u * u * t) + c * (3.0 * u * t * t) + d * (t * t * t)

func _build_tube(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	var centres: Array[Vector3] = []
	for r in RINGS:
		centres.append(_bez(a, b, c, d, float(r) / float(RINGS - 1)))
	# Its underside faces where it means to land.
	var toward := (d - a)
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.FORWARD
	for r in RINGS:
		var t := float(r) / float(RINGS - 1)
		var p := centres[r]
		var fwd := (centres[mini(r + 1, RINGS - 1)] - centres[maxi(r - 1, 0)]).normalized()
		var side_v := fwd.cross(Vector3.UP)
		if side_v.length() < 0.01:
			side_v = fwd.cross(Vector3.RIGHT)
		side_v = side_v.normalized()
		var upv := side_v.cross(fwd).normalized()
		var rad := lerpf(THICK, TIP, pow(t, 0.8)) * (1.0 + 0.08 * sin(t * 18.0 + _sway * 3.0))
		for k in SIDES + 1:
			var ang := TAU * float(k) / float(SIDES)
			var n := (side_v * cos(ang) + upv * sin(ang)).normalized()
			verts.append(p + n * rad)
			normals.append(n)
			var under := clampf(n.dot(-upv) * 1.4 + n.dot(toward) * 0.3, 0.0, 1.0)
			colors.append(SKIN.lerp(BELLY, smoothstep(0.35, 0.8, under)))
	for r in RINGS - 1:
		var i0 := r * (SIDES + 1)
		var i1 := (r + 1) * (SIDES + 1)
		for k in SIDES:
			idx.append_array([i0 + k, i1 + k, i1 + k + 1, i0 + k, i1 + k + 1, i0 + k + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_glow.position = centres[int(RINGS * 0.7)] + Vector3(0.0, 0.5, 0.0)
	# The suckers' glow along the underside, toward the tip.
	for i in _dots.size():
		var t := 0.3 + 0.1 * float(i)
		var r := int(t * float(RINGS - 1))
		var p := centres[r]
		var fwd := (centres[mini(r + 1, RINGS - 1)] - centres[maxi(r - 1, 0)]).normalized()
		var side_v := fwd.cross(Vector3.UP).normalized() if fwd.cross(Vector3.UP).length() > 0.01 else Vector3.RIGHT
		var upv := side_v.cross(fwd).normalized()
		_dots[i].position = p - upv * lerpf(THICK, TIP, pow(t, 0.8)) * 0.95
