class_name DebrisField
extends MultiMeshInstance3D
## Every flying chunk and every piece of rubble in the city, drawn as one MultiMesh (one draw
## call, which matters on phones). Pieces are simulated here, not by the physics engine: they
## arc, tumble, bounce on the street, settle as glowing rubble and shrink away after a while.
##
## Falling pieces are whole cubes from a building that lost its base. They drop as one block,
## tip a little, and shatter into smaller chunks with a dust cloud where they land. On the host a
## landing cube crushes enemies underneath it.

const GRAVITY := 22.0
const MAX_PIECES := 700
const MAX_PIECES_MOBILE := 260
const RUBBLE_TIME := Vector2(6.0, 10.0)

var _cap := MAX_PIECES
var _next := 0
var _active := 0
## Per piece: position, velocity, rotation, spin, size, colour, life left, state.
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _rot: Array[Quaternion] = []
var _spin := PackedVector3Array()
var _size := PackedVector3Array()
var _color := PackedColorArray()
var _life := PackedFloat32Array()
var _energy := PackedFloat32Array()
## 0 = free, 1 = flying chunk, 2 = settled rubble, 3 = falling building cube (shatters on landing)
var _state := PackedByteArray()
## Falling cubes only: whether landing should hurt enemies (host only) and its windows flag.
var _harm := PackedByteArray()
var _windows := PackedByteArray()
var _hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0, -50, 0))
## Landings that get the full treatment (sparks, dust, sound) refill over time, so a whole
## building coming down at once doesn't spawn hundreds of particle systems on a phone.
var _fx_budget := 10.0


func _ready() -> void:
	_cap = MAX_PIECES_MOBILE if G.is_mobile() else MAX_PIECES
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = G.box_mesh(Vector3.ONE)
	mm.instance_count = _cap
	multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/neon_multi.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pos.resize(_cap)
	_vel.resize(_cap)
	_spin.resize(_cap)
	_size.resize(_cap)
	_color.resize(_cap)
	_life.resize(_cap)
	_energy.resize(_cap)
	_state.resize(_cap)
	_harm.resize(_cap)
	_windows.resize(_cap)
	_rot.resize(_cap)
	for i in _cap:
		_rot[i] = Quaternion.IDENTITY
		mm.set_instance_transform(i, _hidden)
		mm.set_instance_color(i, Color.WHITE)
		mm.set_instance_custom_data(i, Color(0, 0, 1, 0))
	# The pieces fly all over the map; never let the whole batch get culled.
	custom_aabb = AABB(Vector3(-200, -10, -200), Vector3(400, 80, 400))


func active_count() -> int:
	return _active


## Chunks flying off a broken block.
func burst(pos: Vector3, color: Color, size: Vector3, push: Vector3, count: int) -> void:
	var flat_push := Vector3(push.x, 0.0, push.z)
	if flat_push.length() > 0.01:
		flat_push = flat_push.normalized()
	for n in count:
		var i := _take()
		var s := Vector3(size.x * randf_range(0.22, 0.5), size.y * randf_range(0.22, 0.5),
				size.z * randf_range(0.22, 0.5))
		_pos[i] = pos + Vector3(randf_range(-0.4, 0.4) * size.x, randf_range(-0.3, 0.3) * size.y,
				randf_range(-0.4, 0.4) * size.z)
		var out := Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.4), randf_range(-1.0, 1.0)).normalized()
		_vel[i] = out * randf_range(3.0, 9.0) + flat_push * randf_range(2.0, 7.0)
		_rot[i] = Quaternion(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)
		_spin[i] = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(4.0, 12.0)
		_size[i] = s
		_color[i] = color.lerp(Color.WHITE, randf() * 0.25)
		_life[i] = randf_range(RUBBLE_TIME.x, RUBBLE_TIME.y)
		_energy[i] = 3.2
		_state[i] = 1
		_write(i)


## A whole building cube dropping because the one beneath it was destroyed.
func fall(pos: Vector3, color: Color, size: Vector3, push: Vector3, harm: bool, windows: bool) -> void:
	var i := _take()
	_pos[i] = pos
	var tip := Vector3(push.x, 0.0, push.z)
	tip = tip.normalized() if tip.length() > 0.01 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	_vel[i] = tip * randf_range(0.4, 1.2) + Vector3(0, -randf_range(0.0, 1.5), 0)
	_rot[i] = Quaternion.IDENTITY
	# Topple slowly away from the blast, around the horizontal axis across the push.
	_spin[i] = tip.cross(Vector3.DOWN) * randf_range(0.4, 1.1)
	_size[i] = size
	_color[i] = color
	_life[i] = 6.0
	_energy[i] = 2.4
	_state[i] = 3
	_harm[i] = 1 if harm else 0
	_windows[i] = 1 if windows else 0
	_write(i)


func _take() -> int:
	# Ring buffer: when full, the oldest piece is recycled.
	var i := _next
	_next = (_next + 1) % _cap
	if _state[i] == 0:
		_active += 1
	return i


func _write(i: int) -> void:
	var shrink := clampf(_life[i] / 0.8, 0.0, 1.0)
	var b := Basis(_rot[i]).scaled(_size[i] * shrink)
	multimesh.set_instance_transform(i, Transform3D(b, _pos[i]))
	multimesh.set_instance_color(i, _color[i])
	multimesh.set_instance_custom_data(i, Color(0.0, float(_windows[i]) if _state[i] == 3 else 0.0, 1.0, _energy[i]))


func _free(i: int) -> void:
	_state[i] = 0
	_active -= 1
	multimesh.set_instance_transform(i, _hidden)


func _process(delta: float) -> void:
	_fx_budget = minf(10.0, _fx_budget + delta * 20.0)
	if _active == 0:
		return
	delta = minf(delta, 0.05)
	for i in _cap:
		var st := _state[i]
		if st == 0:
			continue
		_life[i] -= delta
		if _life[i] <= 0.0:
			_free(i)
			continue
		if st == 2:
			# Rubble only dims and, at the very end, shrinks.
			_energy[i] = maxf(0.9, _energy[i] - delta * 0.6)
			if _life[i] < 0.8 or fmod(_life[i], 0.25) < delta:
				_write(i)
			continue
		var v := _vel[i]
		v.y -= GRAVITY * delta
		var p := _pos[i] + v * delta
		var w := _spin[i]
		if w.length_squared() > 0.0001:
			_rot[i] = (Quaternion(w.normalized(), w.length() * delta) * _rot[i]).normalized()
		var half := _size[i].y * 0.5
		if p.y - half <= 0.0:
			p.y = half
			if st == 3:
				_pos[i] = p
				_land(i)
				continue
			if absf(v.y) > 2.5:
				v.y = -v.y * 0.35
				v.x *= 0.6
				v.z *= 0.6
				_spin[i] = w * 0.6
			else:
				# Settle flat-ish on the ground as rubble.
				v = Vector3.ZERO
				_spin[i] = Vector3.ZERO
				_rot[i] = Quaternion(Vector3.UP, randf() * TAU)
				_state[i] = 2
		_vel[i] = v
		_pos[i] = p
		_energy[i] = maxf(1.6, _energy[i] - delta * 1.2)
		_write(i)


## A falling building cube hits the street: it breaks up, kicks up dust and crushes enemies.
func _land(i: int) -> void:
	var pos := _pos[i]
	var size := _size[i]
	var color := _color[i]
	var harm := _harm[i] == 1
	var windows := _windows[i] == 1
	_free(i)
	# Effects are rebuilt on every phone from the "fall" event, so nothing here is replicated.
	G.net_mute += 1
	var full := _fx_budget >= 1.0
	if full:
		_fx_budget -= 1.0
		burst(pos, color, size, Vector3.ZERO, 6 if G.is_mobile() else 9)
		G.sparks(pos + Vector3(0, 0.3, 0), color, 6, 7.0, 0.7, 0.12, -18.0)
		if windows:
			G.sparks(pos + Vector3(0, 0.6, 0), Color(0.45, 0.65, 0.8), 5, 8.0, 0.45, 0.07, -24.0)
		G.dust(Vector3(pos.x, 0.0, pos.z), color, size.x * 1.4)
		G.sfx("thud", -4.0, randf_range(0.85, 1.15))
	else:
		burst(pos, color, size, Vector3.ZERO, 3)
	G.add_shake(0.12 if full else 0.04)
	G.net_mute -= 1
	if harm and not G.is_client() and G.main:
		_crush_enemies(pos, maxf(size.x, size.z) * 0.95)
		G.city.impact(pos, 1.6, 14.0)


func _crush_enemies(pos: Vector3, radius: float) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if d < radius and not (e is Drone or e is Hornet or e is Gunship):
			e.take_damage(40.0, pos, G.Team.PLAYER)
			if e.dead:
				G.popup(e.global_position + Vector3(0, 2.4, 0), "SQUASHED!", Color(1.0, 0.85, 0.3), 0.8)
				G.add_score(20)
