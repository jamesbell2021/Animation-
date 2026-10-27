class_name Combat
extends Node
## Shots in flight, hit tests against kaiju hit spheres, damage, blood and kills, plus damage to
## guns and the airship. Weak points take triple damage from the player and 1.5x from guns.

class Shot:
	var kind: String = "shell"
	var pos: Vector3
	var vel: Vector3
	var life: float = 4.0
	var g: float = 0.0
	var splash: float = 0.0
	var homing: Kaiju = null
	var acc: float = 0.0
	var max_spd: float = 500.0
	var dmg: float = 10.0
	var dt: String = "kin"
	var by: String = "t"
	var origin: Vector3
	var cluster: bool = false
	var big: bool = false

var shots: Array[Shot] = []


func clear() -> void:
	shots.clear()


func fire(d: Dictionary) -> void:
	var s: Shot = Shot.new()
	s.kind = d.get("kind", "shell")
	s.pos = d["pos"]
	s.origin = s.pos
	s.vel = d["vel"]
	s.life = float(d.get("life", 4.0))
	s.g = float(d.get("g", 0.0))
	s.splash = float(d.get("splash", 0.0))
	s.homing = d.get("homing", null)
	s.acc = float(d.get("acc", 0.0))
	s.max_spd = float(d.get("max", 500.0))
	s.dmg = float(d["dmg"])
	s.dt = d.get("dt", "kin")
	s.by = d.get("by", "t")
	s.cluster = d.get("cluster", false)
	s.big = d.get("big", false)
	shots.append(s)


## First weak-point-or-body hit along a segment: {k, p, weak, t} or {}.
func seg_hit(a: Vector3, b: Vector3, ignore: Kaiju = null) -> Dictionary:
	var best: Dictionary = {}
	var bt: float = 2.0
	var d: Vector3 = b - a
	var a2: float = d.length_squared()
	if a2 < 1e-6:
		return best
	for k: Kaiju in Game.kaiju:
		if k.dying or k == ignore:
			continue
		var h: Dictionary = seg_hit_one(k, a, b, d, a2)
		if not h.is_empty() and float(h["tt"]) < bt:
			bt = h["tt"]
			best = h
	return best


func seg_hit_one(k: Kaiju, a: Vector3, b: Vector3, d: Vector3, a2: float) -> Dictionary:
	var best: Dictionary = {}
	var air: bool = k.def["air"]
	for s: Dictionary in k.hits:
		var c: Vector3 = s["p"]
		var r: float = s["r"]
		if not air and c.y + r < -0.5:
			continue    # under the waves
		var f: Vector3 = a - c
		var bb: float = 2.0 * f.dot(d)
		var cc: float = f.length_squared() - r * r
		var t: float
		if cc < 0.0:
			t = 0.0
		else:
			var disc: float = bb * bb - 4.0 * a2 * cc
			if disc < 0.0:
				continue
			t = (-bb - sqrt(disc)) / (2.0 * a2)
		if t < 0.0 or t > 1.0:
			continue
		var tt: float = t - (0.002 if s["weak"] else 0.0)
		if best.is_empty() or tt < float(best["tt"]):
			best = {"k": k, "t": t, "tt": tt, "p": a + d * t, "weak": s["weak"], "idx": s["idx"]}
	return best


func update(dt: float) -> void:
	var i: int = shots.size() - 1
	while i >= 0:
		var s: Shot = shots[i]
		var old: Vector3 = s.pos
		if s.homing != null:
			if not is_instance_valid(s.homing) or s.homing.dying:
				s.homing = null
			else:
				var sp: float = s.vel.length()
				s.vel = s.vel.lerp((s.homing.aim - s.pos).normalized() * sp, minf(1.0, dt * 3.2))
		if s.acc > 0.0:
			var sp2: float = s.vel.length()
			s.vel *= minf(s.max_spd, sp2 + s.acc * dt) / maxf(sp2, 0.001)
		s.vel.y -= s.g * dt
		s.pos += s.vel * dt
		s.life -= dt
		if s.kind == "rocket" or s.kind == "prkt":
			if randf() < 0.8:
				Game.fx.smoke(old, Vector3(randf_range(-2, 2), randf_range(0, 3), randf_range(-2, 2)), 0.8, 0.9)
			Game.fx.sparks(old, 1, Mats.FIRE, 8.0, 0.0)
		var hit: Dictionary = seg_hit(old, s.pos)
		if not hit.is_empty():
			impact(s, hit["p"], hit["k"], hit["weak"], hit["idx"])
			shots.remove_at(i)
			i -= 1
			continue
		if s.kind == "flak":
			var fuse: bool = false
			for k: Kaiju in Game.kaiju:
				if k.def["air"] and not k.dying and k.aim.distance_to(s.pos) < 13.0:
					fuse = true
					break
			if fuse:
				impact(s, s.pos, null, false)
				shots.remove_at(i)
				i -= 1
				continue
		var sy: float = Game.surface_y(s.pos.x, s.pos.z)
		if s.pos.y < sy:
			impact(s, Vector3(s.pos.x, sy, s.pos.z), null, false)
			shots.remove_at(i)
		elif s.life <= 0.0:
			if s.splash > 0.0:
				impact(s, s.pos, null, false)
			shots.remove_at(i)
		i -= 1


func draw() -> void:
	var fx: Fx = Game.fx
	for s: Shot in shots:
		var tail: float = minf(1.0, s.pos.distance_to(s.origin) / maxf(1.0, s.vel.length() * 0.035))
		match s.kind:
			"rocket", "prkt":
				var d: Vector3 = s.vel.normalized()
				fx.frame_ribbon(s.pos, s.pos - d * 4.0, Mats.WHITE, 1.0)
				fx.frame_ribbon(s.pos - d * 4.0, s.pos - d * 11.0, Mats.FIRE, 1.6)
			"bomb":
				fx.frame_ribbon(s.pos + Vector3(0, 2, 0), s.pos - Vector3(0, 2, 0), Mats.WHITE, 2.4)
			"flak":
				fx.frame_ribbon(s.pos, s.pos - s.vel * 0.025 * tail, Mats.SAKURA, 0.7)
			"bullet":
				fx.frame_ribbon(s.pos, s.pos - s.vel * 0.035 * tail, Mats.TRACER, 0.3)
			_:
				fx.frame_ribbon(s.pos, s.pos - s.vel * 0.025 * tail, Mats.TRACER, 0.8)


func impact(s: Shot, p: Vector3, k: Kaiju, weak: bool, idx: int = -1) -> void:
	var dir: Vector3 = s.vel.normalized()
	if k != null:
		hurt_kaiju(k, s.dmg, s.dt, p, dir, weak, s.by, idx)
	if s.splash > 0.0:
		for o: Kaiju in Game.kaiju.duplicate():
			if o == k or o.dying:
				continue
			var md: float = 1e9
			for h: Dictionary in o.hits:
				md = minf(md, (h["p"] as Vector3).distance_to(p) - float(h["r"]))
			if md < s.splash:
				hurt_kaiju(o, s.dmg * 0.6, s.dt, p, (o.position - p + Vector3(0, 5, 0)).normalized(), false, s.by)
	if s.cluster:
		_cluster(s, p)
	match s.kind:
		"flak":
			Game.fx.hanabi(p, 1.8 if s.big else 1.0)
			Game.sfx.play_at("hanabi", p, 0.8)
		"rocket", "bomb", "prkt":
			var size: float = 3.0 if s.kind == "bomb" else (2.0 if s.kind == "prkt" else 1.4)
			Game.fx.boom(p, size)
			Game.sfx.play_at("boom_big" if s.kind == "bomb" else "boom", p, 1.0)
			if randf() < 0.35:
				Game.fx.text(p + Vector3(0, 8, 0), Fx.ONO.pick_random(), Mats.FIRE, 14.0 if s.kind == "bomb" else 9.0, 1.0)
		_:
			Game.fx.sparks(p, 5, Mats.TRACER if k != null else Mats.CYAN, 35.0, 40.0)
			if k == null and p.y < 3.0 and p.z < Game.coast_z(p.x):
				Game.fx.ring(Vector3(p.x, 0.6, p.z), 1.0, 14.0, 0.6, Mats.CYAN)
				Game.fx.sparks(Vector3(p.x, 1, p.z), 5, Mats.CYAN, 22.0, 70.0)


func hurt_kaiju(k: Kaiju, dmg: float, dt: String, p: Vector3, dir: Vector3, weak: bool, by: String, idx: int = -1, crit_mult: float = 0.0) -> void:
	if k.dying:
		return
	var mult: float = 1.0 if dt == "rail" else float(k.def["arm"].get(dt, 1.0))
	var crit: float = 1.0
	if weak:
		crit = crit_mult if crit_mult > 0.0 else (3.0 if by == "p" else 1.5)
	var dmg_f: float = dmg * mult * crit
	k.hp -= dmg_f
	k.flash_t = 0.05
	k.last_by = by
	k.add_stagger(dmg_f)
	if weak and idx >= 0:
		var kind: String = k.weak_kind(idx)
		if k.weak_hit(idx, dmg_f):
			_weak_broken(k, p, kind, by)
	elif idx >= 0:
		k.recoil = maxf(k.recoil, 0.08)
	var n: int = clampi(roundi(dmg_f / 7.0), 2, 26) * (2 if weak else 1)
	Game.fx.spray(p, dir, n, 55.0 if weak else 32.0, 1 if dmg_f > 60.0 else 0)
	if (dmg_f >= 35.0 or weak) and k.wounds.size() < 7:
		k.wounds.append({"local": k.to_local(p), "dir": (-dir + Vector3(0, 0.5, 0)).normalized(), "t": 0.3})
	if by == "p":
		Game.player.on_hit(weak)
		Game.fx.text(p + Vector3(0, 4, 0), ("会心 " if weak else "") + str(roundi(dmg_f)), Mats.GOLD if weak else Mats.WHITE, 7.0 if weak else 4.5, 0.8, 14.0)
		if weak:
			Game.sfx.play("crit", 0.8)
			Game.sfx.play("splat", 0.8)
	elif dmg_f > 25.0:
		Game.sfx.play_at("splat", p, 0.7)
	if randf() < 0.04 + (0.2 if weak else 0.0):
		Game.fx.text(p + Vector3(0, 10, 0), Fx.PAIN.pick_random(), Mats.SAKURA, 10.0, 1.1)
		k.roar_t = 0.6
	if k.hp <= 0.0:
		kill_kaiju(k, dir)


## A weak point was shot out: bonus damage, a burst of gore, and the kaiju goes berserk.
func _weak_broken(k: Kaiju, p: Vector3, kind: String, by: String) -> void:
	k.hp -= k.max_hp * 0.12
	Game.fx.spray(p, Vector3.UP, 70, 95.0, 6)
	Game.fx.boom(p, 1.2, Mats.BLOOD)
	var label: String = {"eye": "目潰し! EYE OUT", "core": "核破壊! CORE SMASHED", "pearl": "宝珠破壊! PEARL SHATTERED"}.get(kind, "急所! WEAK POINT")
	Game.fx.text(p + Vector3(0, 14, 0), label, Mats.GOLD, 14.0, 1.8, 10.0)
	Game.sfx.play_at("roar_boss" if k.def["boss"] else "roar", p, 1.0)
	Game.sfx.play_at("splat", p, 1.0)
	if by == "p":
		Game.sfx.play("crit", 1.0)
	Game.fx.shake_at(p, 1.2)
	if Game.voice != null:
		Game.voice.say("weak")
	if k.hp <= 0.0:
		kill_kaiju(k, Vector3.UP)


func kill_kaiju(k: Kaiju, dir: Vector3) -> void:
	if k.dying:
		return
	var d: Dictionary = k.def
	k.dying = true
	k.die_t = 0.0
	k.fall_dir = -1.0 if dir.x > 0.0 else 1.0
	var a: Vector3 = k.aim
	var boss: bool = d["boss"]
	if not Game.demo:
		var r: int = roundi(float(d["reward"]) * (1.0 + 0.03 * float(Game.wave)))
		Game.funds += r
		Game.kills += 1
		Game.fx.text(a + Vector3(0, 20, 0), "+¥%d" % r, Mats.GOLD, 9.0, 1.8, 16.0)
		if k.last_by == "p":
			Game.fx.text(a + Vector3(0, 34, 0), "撃破!", Mats.SHU, 16.0, 1.6, 10.0)
		Game.hud_dirty.emit()
	Game.fx.text(a + Vector3(0, 6, 0), Fx.ONO.pick_random(), Mats.FIRE, 30.0 if boss else 16.0, 1.4)
	Game.fx.spray(a, Vector3.UP, 160 if boss else 70, 110.0 if boss else 75.0, 22 if boss else 9)
	Game.fx.boom(a, 5.0 if boss else 3.0)
	for w: Dictionary in k.wounds:
		w["t"] = 0.0
	Game.sfx.play_at("roar_boss" if boss else "roar", a, 1.0)
	Game.sfx.play_at("boom_big", a, 1.0)
	k._death_step = 0
	if boss:
		Game.slowmo = 1.6
		Game.flash = 0.8
		Game.shake = 3.0
		Game.banner.emit("大鬼 撃破", "THE DAI-ONI FALLS", 3.0)


## Cluster rockets: bomblets scatter round the impact and each one bursts.
func _cluster(s: Shot, p: Vector3) -> void:
	for i: int in range(6):
		var a: float = TAU * float(i) / 6.0 + randf() * 0.5
		var q: Vector3 = p + Vector3(cos(a), 0, sin(a)) * randf_range(7, 18)
		q.y = maxf(q.y, Game.surface_y(q.x, q.z))
		Game.fx.boom(q, 0.7, Mats.FIRE)
		for o: Kaiju in Game.kaiju.duplicate():
			if o.dying:
				continue
			for h: Dictionary in o.hits:
				if (h["p"] as Vector3).distance_to(q) - float(h["r"]) < 12.0:
					hurt_kaiju(o, s.dmg * 0.3, "exp", q, (o.position - q).normalized(), false, s.by)
					break


func rail_hit(a: Vector3, b: Vector3, dmg: float, by: String, crit_mult: float = 0.0) -> void:
	var done: Array[Kaiju] = []
	var d: Vector3 = b - a
	var a2: float = d.length_squared()
	for guard: int in range(8):
		var best: Dictionary = {}
		for k: Kaiju in Game.kaiju:
			if done.has(k) or k.dying:
				continue
			var h: Dictionary = seg_hit_one(k, a, b, d, a2)
			if not h.is_empty() and (best.is_empty() or float(h["t"]) < float(best["t"])):
				best = h
		if best.is_empty():
			break
		var hk: Kaiju = best["k"]
		done.append(hk)
		hurt_kaiju(hk, dmg, "rail", best["p"], d.normalized(), best["weak"], by, best["idx"], crit_mult)
		Game.fx.spray(best["p"], d.normalized(), 18, 70.0, 2)


func hurt_turret(t: Turret, n: float) -> void:
	if t.hp <= 0.0:
		return
	t.hp -= n
	if randf() < 0.2:
		Game.fx.sparks(t.pad.pos + Vector3(0, 6, 0), 2, Mats.FIRE, 30.0)
	if t.hp <= 0.0:
		Game.fx.boom(t.pad.pos + Vector3(0, 5, 0), 2.5)
		Game.sfx.play_at("boom_big", t.pad.pos, 1.0)
		Game.fx.text(t.pad.pos + Vector3(0, 20, 0), "大破!", Mats.SHU, 10.0, 1.6)
		if Game.player.active and Game.player.seat is Turret and Game.player.seat == t:
			Game.player.exit_seat()
			Game.banner.emit("砲台 大破", "YOUR GUN WAS DESTROYED", 2.0)
		Game.main.remove_turret(t)


func hurt_zep(n: float) -> void:
	var z: Zeppelin = Game.zep
	if z.down or Game.demo:
		return
	z.hp -= n
	if randf() < 0.3:
		Game.fx.sparks(z.position + Vector3(randf_range(-30, 30), randf_range(-10, 10), randf_range(-30, 30)), 3, Mats.FIRE, 40.0)
	if z.hp <= 0.0:
		z.hp = 0.0
		z.down = true
		z.down_t = 0.0
		z.fall = 0.0
		z.splashed = false
		Game.fx.boom(z.position, 4.0)
		Game.sfx.play_at("boom_big", z.position, 1.2)
		Game.banner.emit("雷神丸 撃墜", "RAIJIN-MARU IS GOING DOWN", 2.6)
		if Game.player.active and Game.player.seat is String:
			Game.player.exit_seat()
		Game.hud_dirty.emit()
