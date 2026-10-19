class_name Eel
extends Enemy
## The Giant Constrictor Eel: a scripted encounter, not a walker.
## Announce: the water churns off a beach. Surge: it rushes up over the beach, the cliffs
## and the crag straight at the lighthouse, smashing fences in its line and knocking
## keepers flat. Coil: it wraps the tower and squeezes, crushing the lighthouse, with its
## head reared out over the ledge, where the focused beam can reach it. Burn the head
## long enough and it lets go early; hold out and it slides back into the sea anyway,
## angrier. Boathook blows on the coils barely tell.

const SEGMENTS := 18
# The body is one smooth tube through the segment points, resampled to this many rings.
const TUBE_RINGS := 72
const TUBE_SIDES := 9
const ANNOUNCE_TIME := 8.0
const SURGE_TIME := 3.0
const COIL_TIME := 20.0
const COIL_TIME_SOLO := 25.0
const RELEASE_TIME := 2.0
const BEAM_HP := 90
const BEAM_DPS := 12.0
const MELEE_MULT := 0.25
const CRUSH_DPS := 5.0
const SURGE_REACH := 1.2
const PRONE_TIME := 1.5
const COIL_RADIUS := 2.1
const COIL_TURNS := 2.5
const COIL_RISE := 6.0
# The head rears out over the ledge, inside the focused beam's reach.
const HEAD_RADIUS := 6.6
const HEAD_HEIGHT := 3.6
const HEAD_SPIN := 0.5
const BODY := Color(0.18, 0.24, 0.22)
const BELLY := Color(0.42, 0.45, 0.32)
const EYE := Color(1.0, 0.9, 0.3)
const BURN := Color(1.0, 0.5, 0.25)

## Where it comes from: an offshore point, set by the spawner.
var origin := Vector3.ZERO
var released_early := false

# Control points along the body, head end last. Placed by each phase; the tube is
# rebuilt through them every frame.
var _segs: Array[Node3D] = []
var _tube: MeshInstance3D
var _tube_mesh: ImmediateMesh
var _head: Node3D
var _head_mat: StandardMaterial3D
var _head_textured := false
var _body_mat: StandardMaterial3D
var _churn: Array[MeshInstance3D] = []
var _path: Array[Vector3] = []
var _crush_acc := 0.0
var _burn_acc := 0.0
var _burn_t := 0.0
var _spin := 0.0
var _coil_len := COIL_TIME
var _sound_t := 0.0
var _hit_struct := {}
var _hit_players := {}
var _release_from: Array[Vector3] = []

func _init() -> void:
	max_hp = BEAM_HP
	hp = BEAM_HP
	mass = 50.0
	speed = 0.0

func _ready() -> void:
	max_hp = roundi(BEAM_HP * (1.0 + 0.2 * float(Players.count() - 1)))
	_coil_len = COIL_TIME_SOLO if Players.count() <= 1 else COIL_TIME
	super._ready()
	collision_layer = 0
	collision_mask = 0
	add_to_group("eel")

func _build() -> void:
	_body_mat = Look.flat_mat(Color.WHITE, 0.25)
	_body_mat.vertex_color_use_as_albedo = true
	# Mottled skin along the body: a noise texture wrapped round the tube.
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.6, 0.55))
	ramp.set_color(1, Color(1.25, 1.3, 1.2))
	tex.color_ramp = ramp
	_body_mat.albedo_texture = tex
	var belly := Look.flat_mat(BELLY, 0.4)
	for i in SEGMENTS:
		var seg := Node3D.new()
		seg.top_level = true
		add_child(seg)
		_segs.append(seg)
	_tube_mesh = ImmediateMesh.new()
	_tube = MeshInstance3D.new()
	_tube.mesh = _tube_mesh
	_tube.material_override = _body_mat
	_tube.top_level = true
	_tube.visible = false
	add_child(_tube)
	_head = Node3D.new()
	_head.top_level = true
	_head.visible = false
	add_child(_head)
	_head_mat = Look.flat_mat(BODY, 0.3)
	if _build_head_model():
		_build_churn()
		return
	# A blunt, tapering snout (narrow end forward, -Z) over a hanging jaw.
	var skull := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.22
	sm.bottom_radius = 0.6
	sm.height = 1.7
	sm.radial_segments = 8
	sm.rings = 1
	skull.mesh = sm
	skull.material_override = _head_mat
	skull.rotation.x = -PI * 0.5
	skull.scale = Vector3(1.0, 1.0, 0.75)
	skull.position = Vector3(0.0, 0.05, -0.35)
	_head.add_child(skull)
	var jaw := MeshInstance3D.new()
	var jm := CylinderMesh.new()
	jm.top_radius = 0.12
	jm.bottom_radius = 0.42
	jm.height = 1.4
	jm.radial_segments = 6
	jm.rings = 1
	jaw.mesh = jm
	jaw.material_override = belly
	jaw.rotation.x = -PI * 0.5 + 0.35
	jaw.scale = Vector3(1.0, 1.0, 0.5)
	jaw.position = Vector3(0.0, -0.32, -0.3)
	_head.add_child(jaw)
	var eye := Look.eye_mat(EYE, 12.0)
	for side in [-1.0, 1.0]:
		var e := Geo.sphere(_head, 0.12, Color.WHITE, Vector3(side * 0.38, 0.22, -0.55))
		e.material_override = eye
		Look.glint(_head, Vector3(side * 0.38, 0.22, -0.62), EYE, 0.7)
	_build_churn()

# The head from art/characters (built in Blender), with glowing eyes at its markers.
func _build_head_model() -> bool:
	var path := "res://art/characters/eel_head.glb"
	if not ResourceLoader.exists(path):
		return false
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.rotation.y = PI
	_head.add_child(inst)
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		var src: Material = m.get_active_material(0)
		_head_mat = (src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()) as StandardMaterial3D
		m.material_override = _head_mat
		m.extra_cull_margin = 4.0
		_head_textured = true
	var eye := Look.eye_mat(EYE, 12.0)
	var data = JSON.parse_string(FileAccess.get_file_as_string(path.get_basename() + ".json")) if FileAccess.file_exists(path.get_basename() + ".json") else {}
	for key in ["eye.L", "eye.R"]:
		var a: Array = data.get(key, [0.3, 0.24, -0.37])
		var at := Vector3(a[0], a[1], a[2])
		var e := Geo.sphere(_head, 0.05, Color.WHITE, at)
		e.material_override = eye
		Look.glint(_head, at + Vector3(0.0, 0.0, -0.04), EYE, 0.7)
	return true

func _build_churn() -> void:
	# The churn that gives it away: dark humps rolling in the swell.
	var churn_mat := Look.flat_mat(Color(0.12, 0.18, 0.18, 0.75), 0.2)
	churn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 6:
		var c := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.5 + 0.12 * float(i % 3)
		s.height = 0.6
		c.mesh = s
		c.material_override = churn_mat
		c.top_level = true
		add_child(c)
		_churn.append(c)

## The head and the top of the neck: what the beam has to find.
func light_probe_points() -> Array:
	if not _head.visible:
		return []
	return [_head.global_position, _head.global_position + Vector3(0.0, 0.5, 0.0), _segs[SEGMENTS - 2].global_position]

# Catmull-Rom through the control points (tail first, head last).
func _body_at(t: float) -> Vector3:
	var pts: Array[Vector3] = []
	for s in _segs:
		pts.append(s.global_position)
	pts.append(_head.global_position)
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 1.0) * float(n)
	var i := mini(int(f), n - 1)
	var u := f - float(i)
	var p0 := pts[maxi(i - 1, 0)]
	var p1 := pts[i]
	var p2 := pts[i + 1]
	var p3 := pts[mini(i + 2, n)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)

# One tapering tube from the tail to the head, banded dark and pale.
func _rebuild_tube() -> void:
	_tube_mesh.clear_surfaces()
	var rings: Array = []
	var prev_side := Vector3.RIGHT
	for r in TUBE_RINGS:
		var t := float(r) / float(TUBE_RINGS - 1)
		var c := _body_at(t)
		var ahead := _body_at(minf(1.0, t + 0.01))
		var behind := _body_at(maxf(0.0, t - 0.01))
		var fwd := (ahead - behind)
		fwd = fwd.normalized() if fwd.length() > 0.0001 else Vector3.FORWARD
		var side := fwd.cross(Vector3.UP)
		if side.length() < 0.01:
			side = prev_side
		side = side.normalized()
		prev_side = side
		var up := side.cross(fwd).normalized()
		var radius := lerpf(0.18, 0.62, smoothstep(0.0, 0.25, t)) * lerpf(1.0, 0.7, smoothstep(0.75, 1.0, t))
		var ring: Array[Vector3] = []
		for k in TUBE_SIDES:
			var a := TAU * float(k) / float(TUBE_SIDES)
			ring.append(c + (side * cos(a) + up * sin(a)) * radius)
		rings.append([ring, c])
	_tube_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in TUBE_RINGS - 1:
		var a: Array = rings[r][0]
		var b: Array = rings[r + 1][0]
		var ca: Vector3 = rings[r][1]
		var cb: Vector3 = rings[r + 1][1]
		var band := BELLY.lerp(BODY, 0.75) if (r / 4) % 3 == 2 else BODY
		var v0 := float(r) / 6.0
		var v1 := float(r + 1) / 6.0
		for k in TUBE_SIDES:
			var k2 := (k + 1) % TUBE_SIDES
			var quad := [a[k], b[k], b[k2], a[k], b[k2], a[k2]]
			var cent := [ca, cb, cb, ca, cb, ca]
			var uvs := [Vector2(float(k) / TUBE_SIDES, v0), Vector2(float(k) / TUBE_SIDES, v1), Vector2(float(k + 1) / TUBE_SIDES, v1),
				Vector2(float(k) / TUBE_SIDES, v0), Vector2(float(k + 1) / TUBE_SIDES, v1), Vector2(float(k + 1) / TUBE_SIDES, v0)]
			for q in 6:
				var n: Vector3 = (quad[q] - cent[q]).normalized()
				# Pale belly underneath, dark back.
				_tube_mesh.surface_set_color(band.lerp(BELLY, smoothstep(-0.1, -0.7, n.y)))
				_tube_mesh.surface_set_normal(n)
				_tube_mesh.surface_set_uv(uvs[q])
				_tube_mesh.surface_add_vertex(quad[q])
		# A ragged fin along the top of the back.
		var ta: Vector3 = a[TUBE_SIDES / 4]
		var tb: Vector3 = b[TUBE_SIDES / 4]
		var t := float(r) / float(TUBE_RINGS - 1)
		var fin := 0.38 * smoothstep(0.1, 0.3, t) * (1.0 - smoothstep(0.8, 0.95, t)) * (0.75 + 0.25 * sin(float(r) * 1.7))
		if fin > 0.02:
			var up_a := (ta - ca).normalized() * fin
			var up_b := (tb - cb).normalized() * fin
			var side := (tb - ta).cross(up_a).normalized()
			for v in [ta, tb, tb + up_b, ta, tb + up_b, ta + up_a]:
				_tube_mesh.surface_set_color(BODY * 0.7)
				_tube_mesh.surface_set_normal(side)
				_tube_mesh.surface_set_uv(Vector2(0.5, v0))
				_tube_mesh.surface_add_vertex(v)
	_tube_mesh.surface_end()

func is_vulnerable() -> bool:
	return state == &"Coil"

# ---- phases ----

func _enter_Emerge() -> void:
	change_state(&"Announce")

func _enter_Announce() -> void:
	global_position = lighthouse.global_position if lighthouse else Vector3.ZERO
	Audio.sfx("eel_announce", origin, 2.0, 0.0)
	Audio.horn([3.0], -2.0)
	Events.message.emit("The water is moving.")

func _tick_Announce(_delta: float) -> void:
	for i in _churn.size():
		var a := float(i) * 1.05 + state_t * 0.7
		var r := 1.2 + 0.8 * sin(state_t * 1.3 + float(i))
		_churn[i].global_position = origin + Vector3(cos(a) * r, Terrain.SEA_LEVEL + 0.05 + 0.25 * sin(state_t * 3.0 + float(i) * 1.7), sin(a) * r)
	if fmod(state_t, 0.7) < get_physics_process_delta_time():
		FX.splash(get_parent(), origin + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5)), 0.6)
	if state_t >= ANNOUNCE_TIME:
		change_state(&"Surge")

func _enter_Surge() -> void:
	for c in _churn:
		c.visible = false
	_head.visible = true
	_tube.visible = true
	_hit_struct.clear()
	_hit_players.clear()
	Audio.sfx("eel_surge", origin, 2.0, 0.0)
	FX.splash(get_parent(), Vector3(origin.x, Terrain.SEA_LEVEL, origin.z), 2.0)

# A point along the surge line, riding over whatever ground is there.
func _line_point(k: float) -> Vector3:
	var goal := Vector3(0.0, 0.0, 0.0)
	var p := origin.lerp(goal, clampf(k, 0.0, 1.0))
	p.y = maxf(Terrain.height_at(p.x, p.z), Terrain.SEA_LEVEL) + 0.55
	return p

func _tick_Surge(_delta: float) -> void:
	var k := clampf(state_t / SURGE_TIME, 0.0, 1.0)
	# Head leads; the body trails back down the line toward the sea.
	var lead := k * 0.82
	var spacing := 0.035
	_place_head(_line_point(lead), _line_point(lead + 0.02))
	for i in SEGMENTS:
		_segs[SEGMENTS - 1 - i].global_position = _line_point(lead - spacing * float(i + 1))
	_smash_along_line(lead)
	if state_t >= SURGE_TIME:
		change_state(&"Coil")

# Fences across its line are smashed; keepers in the way are knocked flat.
func _smash_along_line(lead: float) -> void:
	var a := Vector2(origin.x, origin.z)
	var b := Vector2(0.0, 0.0).lerp(a, 1.0 - lead)
	for s in get_tree().get_nodes_in_group("structures"):
		if s is Fence and not s.is_destroyed() and not _hit_struct.has(s):
			if Terrain._seg_dist(Vector2(s.global_position.x, s.global_position.z), a, b) < SURGE_REACH + s.length * 0.5:
				_hit_struct[s] = true
				s.take_damage(10000)
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and not _hit_players.has(p):
			if Terrain._seg_dist(Vector2(p.global_position.x, p.global_position.z), a, b) < SURGE_REACH and absf(p.global_position.y - _line_point(lead).y) < 2.5:
				_hit_players[p] = true
				p.knock_prone(PRONE_TIME)

func _place_head(at: Vector3, look: Vector3) -> void:
	_head.global_position = at
	if at.distance_to(look) > 0.01:
		_head.look_at(look, Vector3.UP)

func _enter_Coil() -> void:
	Audio.sfx("eel_coil", global_position, 0.0, 0.05)
	Audio.sfx("eel_hiss", global_position, -2.0, 0.1)
	_sound_t = 3.0
	Events.message.emit("The Eel has the lighthouse! Burn its head with the focused beam!")

func _coil_point(k: float) -> Vector3:
	var base := lighthouse.global_position if lighthouse else Vector3.ZERO
	var a := k * COIL_TURNS * TAU + _spin * 0.15
	return base + Vector3(cos(a) * COIL_RADIUS, 0.5 + k * COIL_RISE, sin(a) * COIL_RADIUS)

func _head_point() -> Vector3:
	return Vector3(cos(_spin) * HEAD_RADIUS, Terrain.CRAG_TOP + HEAD_HEIGHT + 0.3 * sin(_spin * 3.0), sin(_spin) * HEAD_RADIUS)

func _tick_Coil(delta: float) -> void:
	_spin += HEAD_SPIN * delta
	# Most of the body wraps the tower; the last few segments are the neck out to the head.
	var neck := 5
	var coil_n := SEGMENTS - neck
	for i in coil_n:
		_segs[i].global_position = _coil_point(float(i) / float(coil_n - 1))
	var top := _coil_point(1.0)
	var head := _head_point()
	for j in neck:
		var k := float(j + 1) / float(neck + 1)
		var p := top.lerp(head, k)
		p.y += sin(k * PI) * 1.2
		_segs[coil_n + j].global_position = p
	_place_head(head, head + Vector3(-sin(_spin), 0.0, cos(_spin)))
	# Crushing the lighthouse.
	_crush_acc += CRUSH_DPS * delta
	var dmg := floori(_crush_acc)
	if dmg > 0 and lighthouse is Structure:
		_crush_acc -= float(dmg)
		lighthouse.take_damage(dmg)
	_sound_t -= delta
	if _sound_t <= 0.0:
		_sound_t = randf_range(2.5, 4.0)
		Audio.sfx("eel_coil", global_position + Vector3(0.0, 3.0, 0.0), -2.0, 0.1)
	if state_t >= _coil_len:
		Anger.add(2)
		Events.message.emit("The Eel slides back into the sea. The sea is angrier.")
		change_state(&"Release")

func _enter_Release() -> void:
	_release_from.clear()
	for s in _segs:
		_release_from.append(s.global_position)
	_release_from.append(_head.global_position)
	Audio.sfx("eel_hiss", global_position, 0.0, 0.1)

func _tick_Release(_delta: float) -> void:
	var k := clampf(state_t / RELEASE_TIME, 0.0, 1.0)
	# Everything slides back down the line and under.
	for i in SEGMENTS:
		var back := _line_point(lerpf(0.8, 0.0, k) - 0.035 * float(SEGMENTS - i))
		_segs[i].global_position = _release_from[i].lerp(back, smoothstep(0.0, 1.0, k))
		_segs[i].global_position.y -= k * 1.5
	var hb := _line_point(lerpf(0.8, -0.1, k))
	_head.global_position = _release_from[SEGMENTS].lerp(hb, smoothstep(0.0, 1.0, k))
	if state_t >= RELEASE_TIME:
		FX.splash(get_parent(), Vector3(origin.x, Terrain.SEA_LEVEL, origin.z), 1.6)
		queue_free()

func on_dawn() -> void:
	if state == &"Release":
		return
	if state == &"Announce":
		queue_free()
		return
	change_state(&"Release")

# ---- damage ----

func in_light(mode: int, delta: float) -> void:
	if mode != Lamp.Mode.FOCUSED or state != &"Coil":
		return
	_burn_t = 0.15
	_burn_acc += BEAM_DPS * Lamp.dps_mult * delta
	var dmg := floori(_burn_acc)
	if dmg > 0:
		_burn_acc -= float(dmg)
		last_hit = "beam"
		take_damage(dmg, Vector3.ZERO, null)

func take_damage(amount: int, from_dir: Vector3 = Vector3.ZERO, source: Node = null) -> void:
	if state != &"Coil" or hp <= 0:
		return
	if source is Player:
		amount = maxi(1, roundi(float(amount) * MELEE_MULT))
		last_hit = "hook"
	hp -= amount
	if source != null:
		FX.spray(get_parent(), global_position + Vector3(0.0, 1.5, 0.0), from_dir, Color(0.4, 0.5, 0.35))
		Audio.sfx("hit", global_position, -2.0)
	if hp <= 0:
		hp = 0
		_die()

func _die() -> void:
	# Driven off: it lets go early, and the sea calms a little.
	released_early = true
	Anger.add(-1)
	Stock.add("bio", 3)
	Stock.add("scrap", 2)
	Events.message.emit("The Eel lets go!  +3 bio, +2 scrap washed up in its wake")
	Events.enemy_killed.emit(self)
	Audio.sfx("eel_hiss", _head.global_position, 2.0, 0.05)
	change_state(&"Release")

func _physics_process(delta: float) -> void:
	state_t += delta
	var tick := "_tick_" + String(state)
	if has_method(tick):
		call(tick, delta)
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_burn_t = maxf(0.0, _burn_t - delta)
	var c := BODY.lerp(BURN, 0.7 + 0.3 * sin(state_t * 40.0)) if _burn_t > 0.0 else BODY
	if _head_textured:
		_head_mat.albedo_color = Color.WHITE.lerp(Color(2.0, 1.1, 0.7), 0.7 + 0.3 * sin(state_t * 40.0)) if _burn_t > 0.0 else Color.WHITE
	else:
		_head_mat.albedo_color = c
	if _burn_t > 0.0 and fmod(state_t, 0.2) < delta:
		FX.steam(get_parent(), _head.global_position)
	if _tube.visible:
		_rebuild_tube()
	speed_mult = 1.0
	lit_this_frame = false
