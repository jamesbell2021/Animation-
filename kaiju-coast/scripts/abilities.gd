class_name Abilities
extends Node3D
## Special attacks on cooldowns: AIRSTRIKE (three jets carpet-bomb a line), LIGHTNING STORM (eight
## seconds of strikes round a point) and FLOOD GATES (a surge rolls out from the shore and throws
## kaiju back out to sea). In the command view you pick the spot with a click; in first person
## they land wherever the crosshair meets the sea.

const DEFS: Dictionary = {
	"air": {"name": "AIRSTRIKE", "jp": "空爆", "key": "7", "cd": 40.0, "unlock": 0, "desc": "Three jets carpet-bomb a line of the bay."},
	"storm": {"name": "LIGHTNING STORM", "jp": "雷雨", "key": "8", "cd": 60.0, "unlock": 3, "desc": "Eight seconds of lightning on everything nearby."},
	"flood": {"name": "FLOOD GATES", "jp": "放流", "key": "9", "cd": 75.0, "unlock": 5, "desc": "A surge from the shore throws kaiju back out to sea."},
}
const ORDER: Array[String] = ["air", "storm", "flood"]

var cd: Dictionary = {"air": 0.0, "storm": 0.0, "flood": 0.0}
var targeting: String = ""
var reticle: Variant = null              ## Vector3 under the mouse while targeting

var _jets: Array[Dictionary] = []
var _jet_mesh: Array = []
var _storm_t: float = 0.0
var _storm_c: Vector3 = Vector3.ZERO
var _storm_next: float = 0.0
var _flood_t: float = -1.0
var _flood_x: float = 0.0
var _flood_prev: float = 0.0
var _flood_hit: Array[Kaiju] = []
var _lines: FrameLines = FrameLines.new()
var _announced: int = 1


func _ready() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _lines.mesh
	mi.material_override = Mats.fx_lines()
	mi.extra_cull_margin = 16384.0
	add_child(mi)
	var sb: SolidBuilder = SolidBuilder.new()
	sb.tube(Vector3(0, 0, -9), Vector3(0, 0, 9), 1.3, 1.0, 8, Mats.CYAN, 1, 4)
	sb.cone(Vector3(0, 0, -9), Vector3(0, 0, -14), 1.3, 8, Mats.CYAN)
	sb.plate(PackedVector3Array([Vector3(0, 0, -5), Vector3(11, 0, 5), Vector3(11, 0, 7), Vector3(0, 0, 6)]), Mats.CYAN)
	sb.plate(PackedVector3Array([Vector3(0, 0, -5), Vector3(-11, 0, 5), Vector3(-11, 0, 7), Vector3(0, 0, 6)]), Mats.CYAN)
	sb.plate(PackedVector3Array([Vector3(0, 0.8, 4), Vector3(0, 6, 9), Vector3(0, 6, 10.5), Vector3(0, 0.8, 9)]), Mats.CYAN)
	sb.glow_ball(Vector3(0, 0.9, -7), Vector3(0.6, 0.5, 1.6), Mats.GOLD, 4)
	sb.glow_ball(Vector3(0, 0, 9.4), Vector3(0.9, 0.9, 0.5), Mats.FIRE, 4)
	_jet_mesh = [sb.fill_mesh(), sb.line_mesh(), sb.glow_mesh()]


func reset() -> void:
	for k: String in ORDER:
		cd[k] = 0.0
	targeting = ""
	for j: Dictionary in _jets:
		(j["node"] as Node3D).queue_free()
	_jets.clear()
	_storm_t = 0.0
	_flood_t = -1.0
	_announced = 1
	Game.world.set_surge(0.0, 0.0, 0.0, 0.0)


func unlocked(k: String) -> bool:
	return Game.wave >= int(DEFS[k]["unlock"])


func is_ready(k: String) -> bool:
	return unlocked(k) and float(cd[k]) <= 0.0


## A button or hotkey asked for ability `k`.
func request(k: String) -> void:
	if Game.state != Game.State.PLAY:
		return
	if not unlocked(k):
		Game.sfx.play("deny")
		Game.banner.emit("", "%s UNLOCKS ON WAVE %d" % [DEFS[k]["name"], int(DEFS[k]["unlock"])], 1.6)
		return
	if float(cd[k]) > 0.0:
		Game.sfx.play("deny")
		return
	if Game.player.active:
		fire(k, crosshair_target())
	else:
		targeting = "" if targeting == k else k
		Game.sfx.play("click")
	Game.hud.refresh(true)


func cancel() -> void:
	targeting = ""
	reticle = null
	Game.hud.refresh(true)


## Where a screen position meets the sea (y = 0), or null if it points at the sky.
func ground_at(screen: Vector2) -> Variant:
	var cam: Camera3D = Game.rig.cam
	var o: Vector3 = cam.project_ray_origin(screen)
	var d: Vector3 = cam.project_ray_normal(screen)
	if d.y > -0.01:
		return null
	var p: Vector3 = o + d * (-o.y / d.y)
	p.z = minf(p.z, 40.0)
	return p


func crosshair_target() -> Vector3:
	var cam: Camera3D = Game.rig.cam
	var f: Vector3 = -cam.global_transform.basis.z.normalized()
	var o: Vector3 = cam.global_position
	var p: Vector3
	if f.y < -0.02:
		p = o + f * minf(-o.y / f.y, 1400.0)
	else:
		p = o + Vector3(f.x, 0, f.z).normalized() * 450.0
	p.y = 0.0
	p.z = minf(p.z, 40.0)
	return p


func fire(k: String, p: Vector3) -> void:
	targeting = ""
	reticle = null
	cd[k] = float(DEFS[k]["cd"])
	match k:
		"air":
			for i: int in range(3):
				var n: Node3D = Node3D.new()
				add_child(n)
				for m: int in range(3):
					if _jet_mesh[m] != null:
						var mi: MeshInstance3D = MeshInstance3D.new()
						mi.mesh = _jet_mesh[m]
						mi.material_override = [Mats.fill(), Mats.line(2.8), Mats.glow()][m]
						n.add_child(mi)
				n.position = Vector3(p.x + (float(i) - 1.0) * 18.0, 95.0 + float(i % 2) * 8.0, 700.0 + float(i) * 45.0)
				_jets.append({"node": n, "target": p, "drop": 0.0, "sound": false})
			Game.fx.text(p + Vector3(0, 30, 0), "空爆!", Mats.CYAN, 22.0, 2.0)
		"storm":
			_storm_t = 8.0
			_storm_c = p
			_storm_next = 0.0
			Game.world.storm_boost = 9.0
			Game.fx.text(p + Vector3(0, 60, 0), "雷雨!", Mats.BOLT, 26.0, 2.0)
		"flood":
			_flood_t = 0.0
			_flood_x = p.x
			_flood_prev = Game.coast_z(p.x)
			_flood_hit.clear()
			Game.sfx.play_at("flood", Vector3(p.x, 0, Game.coast_z(p.x)), 1.4)
			Game.fx.text(Vector3(p.x, 40, 0), "放流!", Mats.CYAN, 26.0, 2.0)
	Game.say(k)
	Game.hud.refresh(true)


func update(dt: float) -> void:
	for k: String in ORDER:
		cd[k] = maxf(0.0, float(cd[k]) - dt)
	# Announce each ability the first time it unlocks.
	for k2: String in ORDER:
		var u: int = int(DEFS[k2]["unlock"])
		if u > _announced and Game.wave >= u and not Game.demo:
			_announced = u
			Game.banner.emit("新兵器", "NEW: %s %s  [%s]" % [DEFS[k2]["jp"], DEFS[k2]["name"], DEFS[k2]["key"]], 3.0)
	_update_jets(dt)
	_update_storm(dt)
	_update_flood(dt)


func _update_jets(dt: float) -> void:
	for i: int in range(_jets.size() - 1, -1, -1):
		var j: Dictionary = _jets[i]
		var n: Node3D = j["node"]
		var p: Vector3 = j["target"]
		n.position.z -= 320.0 * dt
		n.rotation.z = sin(Game.t * 3.0 + float(i)) * 0.05
		Game.fx.frame_ribbon(n.position + Vector3(0, 0, 9.5), n.position + Vector3(0, 0, 30), Mats.FIRE * 0.8, 1.2)
		if not j["sound"] and n.position.z < p.z + 420.0:
			j["sound"] = true
			Game.sfx.play_at("jet", Vector3(n.position.x, 60, p.z + 100.0), 1.4)
		if absf(n.position.z - p.z) < 140.0:
			j["drop"] = float(j["drop"]) - dt
			if float(j["drop"]) <= 0.0:
				j["drop"] = 0.09
				Game.combat.fire({"kind": "bomb", "pos": n.position + Vector3(0, -3, 0), "vel": Vector3(randf_range(-6, 6), -10, -110), "g": 90.0,
					"dmg": 150.0, "dt": "exp", "splash": 34.0, "by": "a", "life": 6.0})
		if n.position.z < -1600.0:
			n.queue_free()
			_jets.remove_at(i)


func _update_storm(dt: float) -> void:
	if _storm_t <= 0.0:
		return
	_storm_t -= dt
	_storm_next -= dt
	if _storm_next > 0.0:
		return
	_storm_next = 0.3
	var targets: Array[Kaiju] = []
	for k: Kaiju in Game.kaiju:
		if not k.dying and (k.exposed or k.def["air"]) and Vector2(k.aim.x - _storm_c.x, k.aim.z - _storm_c.z).length() < 300.0:
			targets.append(k)
	var p: Vector3
	var victim: Kaiju = null
	if not targets.is_empty() and randf() < 0.85:
		victim = targets.pick_random()
		p = victim.aim
	else:
		p = _storm_c + Vector3(randf_range(-200, 200), 0, randf_range(-200, 200))
		p.y = Game.wave_h(p.x, p.z)
	var top: Vector3 = Vector3(p.x + randf_range(-60, 60), 420, p.z + randf_range(-60, 60))
	Game.fx.bolt(top, p, 0.3)
	Game.fx.bolt(top, p, 0.25)
	Game.fx.beam(top, p, Mats.WHITE, 1.2, 0.12)
	Game.fx.sparks(p, 20, Mats.BOLT, 70.0, 40.0)
	Game.sfx.play_at("thunder", p, 1.2)
	Game.world.lightning_flash()
	if victim != null:
		Game.combat.hurt_kaiju(victim, 85.0, "elec", p, Vector3.DOWN, false, "a")
		victim.stagger = 1.0
		victim.slow = 1.5
	elif p.y < 3.0:
		Game.fx.ring(Vector3(p.x, 0.6, p.z), 4.0, 30.0, 1.0, Mats.BOLT)


func _update_flood(dt: float) -> void:
	if _flood_t < 0.0:
		return
	_flood_t += dt
	var f: float = minf(1.0, _flood_t / 3.6)
	var x0: float = _flood_x - 330.0
	var x1: float = _flood_x + 330.0
	var front: float = lerpf(Game.coast_z(_flood_x) - 4.0, -560.0, f)
	var h: float = 18.0 * (1.0 - f * 0.6)
	Game.world.set_surge(front, x0, x1, h * 0.6)
	for k: Kaiju in Game.kaiju:
		if k.dying or k.def["air"] or _flood_hit.has(k):
			continue
		if k.position.x > x0 and k.position.x < x1 and k.position.z > front and k.position.z < _flood_prev + 60.0:
			_flood_hit.append(k)
			k.knock = 90.0
			k.slow = 5.0
			k.stagger = 1.0
			Game.combat.hurt_kaiju(k, 70.0, "exp", k.aim, Vector3.FORWARD, false, "a")
			Game.fx.sparks(Vector3(k.position.x, 6, k.position.z), 50, Mats.CYAN, 90.0, 60.0)
			Game.fx.text(k.aim + Vector3(0, 12, 0), "ザバーン!", Mats.CYAN, 14.0, 1.2)
	for i: int in range(8):
		Game.fx.sparks(Vector3(randf_range(x0, x1), h * randf(), front + randf_range(-4, 4)), 1, Mats.CYAN if randf() < 0.7 else Mats.WHITE, 30.0, 40.0)
	_flood_prev = front
	if f >= 1.0:
		_flood_t = -1.0
		Game.world.set_surge(0.0, 0.0, 0.0, 0.0)


func draw() -> void:
	_lines.clear()
	if targeting != "" and reticle is Vector3:
		var p: Vector3 = reticle
		var r: float = {"air": 30.0, "storm": 300.0, "flood": 60.0}[targeting]
		var c: Color = Mats.GOLD
		for i: int in range(48):
			var a0: float = TAU * float(i) / 48.0
			var a1: float = TAU * float(i + 1) / 48.0
			if targeting == "air" or i % 2 == 0:
				_lines.seg(p + Vector3(cos(a0) * r, 2, sin(a0) * r), p + Vector3(cos(a1) * r, 2, sin(a1) * r), c)
		if targeting == "air":
			_lines.seg(p + Vector3(0, 2, 160), p + Vector3(0, 2, -160), c)
			_lines.seg(p + Vector3(-18, 2, 160), p + Vector3(-18, 2, -160), c * 0.5)
			_lines.seg(p + Vector3(18, 2, 160), p + Vector3(18, 2, -160), c * 0.5)
		elif targeting == "flood":
			_lines.seg(Vector3(p.x - 330, 2, Game.coast_z(p.x) - 4), Vector3(p.x + 330, 2, Game.coast_z(p.x) - 4), Mats.CYAN)
			_lines.seg(Vector3(p.x - 330, 2, -560), Vector3(p.x + 330, 2, -560), Mats.CYAN * 0.5)
	if _flood_t >= 0.0:
		var f: float = minf(1.0, _flood_t / 3.6)
		var front: float = lerpf(Game.coast_z(_flood_x) - 4.0, -560.0, f)
		var h: float = 18.0 * (1.0 - f * 0.6)
		for row: int in range(4):
			var y: float = h * float(row) / 3.0
			var prev: Vector3 = Vector3.ZERO
			for i2: int in range(41):
				var x: float = _flood_x - 330.0 + float(i2) * 16.5
				var q: Vector3 = Vector3(x, y, front + sin(x * 0.05 + Game.t * 4.0) * 4.0 - float(row) * 2.0)
				if i2 > 0:
					_lines.seg(prev, q, (Mats.WHITE if row == 3 else Mats.CYAN) * (1.0 - f * 0.5))
				prev = q
	_lines.commit()
