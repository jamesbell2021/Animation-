class_name Turret
extends Node3D
## A gun on a pad: solid jade model (base, a head that turns, a gun that elevates), auto-aiming
## with target lead when nobody is sitting in it. Levels 1-4 change the model as well as the stats.

static var _cache: Dictionary = {}

var pad: Pad
var type: String = "cannon"
var lvl: int = 1
var hp: float = 120.0
var spent: int = 0
var yaw: float = 0.0
var pitch: float = 0.0
var cd: float = 0.0
var recoil: float = 0.0
var target: Kaiju = null
var manned: bool = false

var _head: Node3D
var _gun: Node3D
var _model: Node3D
var _line: ShaderMaterial
var _barrel_len: float = 14.0


func setup(p: Pad, t: String) -> void:
	pad = p
	type = t
	position = p.pos
	spent = int(Game.TT[t]["cost"])
	yaw = randf_range(-0.3, 0.3)
	cd = randf()
	_line = Mats.make_line(2.6)
	rebuild()
	hp = Game.max_hp(lvl)


func level_up() -> void:
	var frac: float = hp / Game.max_hp(lvl)
	lvl += 1
	hp = maxf(frac, 0.6) * Game.max_hp(lvl)
	rebuild()


func rebuild() -> void:
	if _model != null:
		_model.queue_free()
	_model = Node3D.new()
	add_child(_model)
	_add(_model, "base%d" % lvl, func(sb: SolidBuilder) -> void:
		sb.tube(Vector3.ZERO, Vector3(0, 3, 0), 6.5, 5.5, 8, Mats.JADE, 0, 8)
		for i: int in range(lvl):
			var c: Color = Mats.GOLD
			c.a = 0.0
			sb.glow_quad(Vector3(-3.9 + float(i) * 2.6, 1.6, 6.3), Vector3(0.8, 0, 0), Vector3(0, 0.6, 0), c))
	_head = Node3D.new()
	_model.add_child(_head)
	_gun = Node3D.new()
	_head.add_child(_gun)
	var l: int = lvl
	match type:
		"cannon":
			_add(_head, "cannon_head", func(sb: SolidBuilder) -> void:
				sb.box(Vector3(0, 6, 0.5), Vector3(9, 6, 10), Mats.JADE)
				sb.box(Vector3(0, 9.6, 2), Vector3(5, 1.4, 5), Mats.JADE))
			_gun.position = Vector3(0, 7, -3)
			_barrel_len = 12.0 + float(l) * 2.0
			var n: int = [1, 2, 2, 3][l - 1]
			var bl: float = _barrel_len
			_add(_gun, "cannon_gun%d" % l, func(sb: SolidBuilder) -> void:
				for i: int in range(n):
					var ox: float = (float(i) - float(n - 1) / 2.0) * 2.3
					sb.tube(Vector3(ox, 0, 0), Vector3(ox, 0, -bl), 0.75, 0.65, 6, Mats.JADE, 0, 3)
					sb.tube(Vector3(ox, 0, -bl + 1.6), Vector3(ox, 0, -bl), 1.1, 1.1, 6, Mats.JADE))
		"rocket":
			_add(_head, "rocket_head", func(sb: SolidBuilder) -> void:
				sb.tube(Vector3(0, 3, 0), Vector3(0, 7, 0), 1.6, 1.4, 6, Mats.JADE)
				sb.box(Vector3(0, 7.2, 0), Vector3(6, 1.0, 6), Mats.JADE))
			_gun.position = Vector3(0, 9, 0)
			_barrel_len = 7.0
			var g: int = 3 if l >= 3 else 2
			_add(_gun, "rocket_gun%d" % g, func(sb: SolidBuilder) -> void:
				sb.box(Vector3(0, 0, 0), Vector3(float(g) * 3.4 + 2.0, float(g) * 2.8 + 1.6, 12), Mats.JADE)
				for i: int in range(g):
					for j: int in range(g):
						var c: Vector3 = Vector3((float(i) - float(g - 1) / 2.0) * 3.2, (float(j) - float(g - 1) / 2.0) * 2.7, -6.1)
						sb.lines.circle(c, 1.1, Vector3.RIGHT, Vector3.UP, Mats.FIRE, 8)
						var fc: Color = Mats.FIRE * 0.6
						fc.a = 0.0
						sb.glow_quad(c + Vector3(0, 0, -0.05), Vector3(0.7, 0, 0), Vector3(0, 0.7, 0), fc))
		"tesla":
			var h: float = 16.0 + float(l) * 3.0
			_barrel_len = 0.0
			_add(_head, "tesla%d" % l, func(sb: SolidBuilder) -> void:
				sb.tube(Vector3(0, 3, 0), Vector3(0, h, 0), 3.0, 1.4, 8, Mats.JADE, 0, 4)
				for i: int in range(1, 6):
					sb.lines.circle(Vector3(0, 3.0 + (h - 3.0) * float(i) / 6.0, 0), 4.6 - float(i) * 0.5, Vector3.RIGHT, Vector3.BACK, Mats.BOLT, 12)
				sb.glow_ball(Vector3(0, h + 3.0, 0), Vector3(3, 3, 3), Mats.BOLT, 5))
		"rail":
			_add(_head, "rail_head", func(sb: SolidBuilder) -> void: sb.box(Vector3(0, 5.5, 0), Vector3(8, 5, 8), Mats.JADE))
			_gun.position = Vector3(0, 7.5, 0)
			_barrel_len = 24.0 + float(l) * 4.0
			var rl: float = _barrel_len
			var coils: int = 4 + l
			_add(_gun, "rail_gun%d" % l, func(sb: SolidBuilder) -> void:
				for s: float in [-1.6, 1.6]:
					sb.box(Vector3(s, 0, 4.0 - (rl + 4.0) * 0.5), Vector3(0.9, 1.2, rl + 4.0), Mats.JADE)
				for i: int in range(coils):
					var z: float = -4.0 - float(i) * (rl - 6.0) / float(coils)
					sb.lines.circle(Vector3(0, 0, z), 2.7, Vector3.RIGHT, Vector3.UP, Mats.BOLT, 10)
				var cc: Color = Mats.BOLT
				cc.a = 0.0
				sb.glow_quad(Vector3(0, 0, -rl * 0.5), Vector3(0.15, 0, 0), Vector3(0, 0.15, 0), cc)
				sb.edge(Vector3(0, 0, 2), Vector3(0, 0, -rl), Mats.BOLT))
		"flak":
			_add(_head, "flak_head", func(sb: SolidBuilder) -> void: sb.box(Vector3(0, 4.5, 0), Vector3(8, 3, 6), Mats.JADE))
			_gun.position = Vector3(0, 6.5, 0)
			_barrel_len = 10.0
			var nb: int = 6 if l >= 3 else 4
			_add(_gun, "flak_gun%d" % nb, func(sb: SolidBuilder) -> void:
				sb.box(Vector3(0, 0, 0), Vector3(float(nb / 2) * 1.9 + 2.0, 3.6, 3.0), Mats.JADE)
				for i: int in range(nb):
					var ox: float = (float(i % (nb / 2)) - float(nb / 2 - 1) / 2.0) * 1.9
					var oy: float = 0.8 if i < nb / 2 else -0.8
					sb.tube(Vector3(ox, oy, -1.5), Vector3(ox, oy, -10), 0.45, 0.4, 5, Mats.SAKURA))
	_apply_pose()


func _add(parent: Node3D, key: String, build: Callable) -> void:
	if not _cache.has(key):
		var sb: SolidBuilder = SolidBuilder.new()
		build.call(sb)
		_cache[key] = [sb.fill_mesh(), sb.line_mesh(), sb.glow_mesh()]
	var meshes: Array = _cache[key]
	var mats: Array = [Mats.fill(), _line, Mats.glow()]
	for i: int in range(3):
		if meshes[i] != null:
			var mi: MeshInstance3D = MeshInstance3D.new()
			mi.mesh = meshes[i]
			mi.material_override = mats[i]
			parent.add_child(mi)


func _apply_pose() -> void:
	if _head == null:
		return
	_head.rotation.y = yaw
	var p: float = pitch
	if type == "flak":
		p = maxf(0.3, pitch)
	elif type == "rocket":
		p = pitch + 0.25
	_gun.rotation.x = p
	_gun.position.z = (-3.0 if type == "cannon" else 0.0) + recoil * 2.2
	_model.visible = not (manned and Game.player.active)
	var low: bool = hp < Game.max_hp(lvl) * 0.35 and sin(Game.t * 12.0) > 0.0
	_line.set_shader_parameter("tint", Vector3(1.0, 0.1, 0.2) if low else Vector3(1, 1, 1))


func muzzle() -> Vector3:
	if _barrel_len <= 0.0:
		return global_position + Vector3(0, 22.0 + float(lvl) * 3.0, 0)
	return _gun.global_transform * Vector3(0, 0, -_barrel_len)


func top() -> Vector3:
	return global_position + Vector3(0, 19.0 + float(lvl) * 3.0, 0)


func stat() -> Dictionary:
	return Game.tstat(type, lvl)


func valid_target(k: Kaiju, st: Dictionary) -> bool:
	if k == null or not is_instance_valid(k) or k.dying or not k.exposed:
		return false
	if k.def["air"]:
		if not st["air"]:
			return false
	elif not st["ground"]:
		return false
	return Vector2(k.aim.x - pad.pos.x, k.aim.z - pad.pos.z).length() <= float(st["range"])


func find_target(st: Dictionary) -> Kaiju:
	var best: Kaiju = null
	var bs: float = -1e9
	for k: Kaiju in Game.kaiju:
		if not valid_target(k, st):
			continue
		var sc: float
		if k.def["air"]:
			sc = 400.0 - Vector2(k.aim.x - pad.pos.x, k.aim.z - pad.pos.z).length()
		else:
			sc = k.position.z + (60.0 if k.def["boss"] else 0.0)
		if sc > bs:
			bs = sc
			best = k
	return best


func update(dt: float) -> void:
	cd -= dt
	recoil = maxf(0.0, recoil - dt * 4.0)
	if type == "tesla" and randf() < 0.5:
		var tp: Vector3 = top()
		Game.fx.line_flash(tp, tp + Vector3(randf_range(-9, 9), randf_range(-3, 8), randf_range(-9, 9)), Mats.WHITE, 0.05)
	if manned:
		_apply_pose()
		return
	var st: Dictionary = stat()
	if target == null or not Game.kaiju.has(target) or not valid_target(target, st):
		target = find_target(st)
	var k: Kaiju = target
	if k == null:
		yaw += dt * 0.15
		pitch = lerpf(pitch, 0.05, dt)
		_apply_pose()
		return
	var from: Vector3 = pad.pos + Vector3(0, 7, 0)
	var a: Vector3 = k.aim
	if float(st["spd"]) > 0.0:
		var tt: float = from.distance_to(a) / float(st["spd"])
		a += k.vel * tt
	var want: float = Game.yaw_to(a.x - from.x, a.z - from.z)
	var diff: float = wrapf(want - yaw, -PI, PI)
	yaw += clampf(diff, -2.6 * dt, 2.6 * dt)
	pitch = lerpf(pitch, atan2(a.y - from.y, Vector2(a.x - from.x, a.z - from.z).length()), minf(1.0, dt * 5.0))
	_apply_pose()
	if absf(diff) > 0.1 or cd > 0.0:
		return
	cd = 1.0 / float(st["rate"])
	recoil = 1.0
	_fire(k, a, st)


func _fire(k: Kaiju, a: Vector3, st: Dictionary) -> void:
	var m: Vector3 = muzzle()
	var dir: Vector3 = (a - m).normalized()
	var C: Combat = Game.combat
	match type:
		"cannon":
			var n: int = [1, 2, 2, 3][lvl - 1]
			for i: int in range(n):
				var j: Vector3 = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
				C.fire({"kind": "shell", "pos": m, "vel": dir * float(st["spd"]) + j, "dmg": float(st["dmg"]) / float(n) * (1.35 if n > 1 else 1.0),
					"dt": "kin", "by": "t", "life": 1.6})
			Game.fx.sparks(m, 6, Mats.TRACER, 40.0, 40.0)
			Game.fx.muzzle(m, Mats.TRACER, 4.0)
			Game.sfx.play("cannon", 0.7)
		"rocket":
			for i: int in range(int(st["salvo"])):
				C.fire({"kind": "rocket", "pos": m + Vector3(0, 2, 0), "vel": Vector3(dir.x * 60.0 + randf_range(-20, 20), 50.0 + randf_range(0, 25), dir.z * 60.0 + randf_range(-20, 20)),
					"acc": 420.0, "max": 330.0, "homing": k, "dmg": st["dmg"], "dt": "exp", "splash": st["splash"], "by": "t", "life": 5.0})
			Game.sfx.play("rocket", 0.7)
		"tesla":
			var from: Vector3 = top()
			var done: Array[Kaiju] = []
			var cur: Kaiju = k
			for c: int in range(int(st["chain"])):
				if cur == null:
					break
				done.append(cur)
				var p: Vector3 = cur.aim
				Game.fx.bolt(from, p, 0.22)
				C.hurt_kaiju(cur, float(st["dmg"]) * (0.75 if c > 0 else 1.0), "elec", p, (p - from).normalized(), false, "t")
				cur.slow = 1.2
				Game.fx.sparks(p, 8, Mats.BOLT, 50.0, 40.0)
				from = p
				var nx: Kaiju = null
				var nd: float = 110.0
				for o: Kaiju in Game.kaiju:
					if done.has(o) or o.dying or not o.exposed:
						continue
					var dd: float = o.aim.distance_to(p)
					if dd < nd:
						nd = dd
						nx = o
				cur = nx
			Game.sfx.play("zap", 0.8)
		"rail":
			var end: Vector3 = m + dir * float(st["range"]) * 1.2
			C.rail_hit(m, end, st["dmg"], "t")
			Game.fx.beam(m, end, Mats.BOLT, 1.6, 0.35)
			Game.fx.sparks(m, 14, Mats.WHITE, 70.0, 40.0)
			Game.sfx.play("rail", 0.8)
			Game.fx.shake_at(m, 0.6)
		"flak":
			var life: float = m.distance_to(a) / float(st["spd"]) + 0.05
			C.fire({"kind": "flak", "pos": m, "vel": dir * float(st["spd"]) + Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)),
				"dmg": st["dmg"], "dt": "kin", "splash": st["splash"], "by": "t", "life": life})
			Game.sfx.play("flak", 0.6)
