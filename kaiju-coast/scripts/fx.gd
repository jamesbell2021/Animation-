class_name Fx
extends Node3D
## Particles and effects, simulated on the CPU and redrawn every frame as additive glowing lines
## and camera-facing ribbons: sparks, blood spray, gore chunks, blood slicks on the water, splash
## rings, smoke rings, explosions, firework bursts, beams and lightning, plus floating manga
## sound-effect text.

enum { SPARK, BLOOD, GIB, RING, STAIN, SPLAT, BOOM, SMOKE }
var max_particles: int = 3600

var _k: PackedInt32Array = PackedInt32Array()
var _p: PackedVector3Array = PackedVector3Array()
var _v: PackedVector3Array = PackedVector3Array()
var _life: PackedFloat32Array = PackedFloat32Array()
var _max: PackedFloat32Array = PackedFloat32Array()
var _g: PackedFloat32Array = PackedFloat32Array()
var _s: PackedFloat32Array = PackedFloat32Array()
var _x: PackedFloat32Array = PackedFloat32Array()
var _c: PackedColorArray = PackedColorArray()

var _beams: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _label_pool: Array[Label3D] = []
var _lines: FrameLines = FrameLines.new()
var _ribbons: ImmediateMesh
## Extra lines for this frame only (shots, sparks around guns), added by other systems.
var _frame_lines: Array = []
var _frame_ribbons: Array = []

const ONO: Array[String] = ["ドカーン!", "バーン!", "ズドン!", "ドドド!", "ボカーン!"]
const PAIN: Array[String] = ["ギャアア!", "グワァ!", "ガアア!", "ギャオオ!"]


func _ready() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _lines.mesh
	mi.material_override = Mats.fx_lines()
	mi.extra_cull_margin = 16384.0
	add_child(mi)
	_ribbons = ImmediateMesh.new()
	var mr: MeshInstance3D = MeshInstance3D.new()
	mr.mesh = _ribbons
	mr.material_override = Mats.fx()
	mr.extra_cull_margin = 16384.0
	add_child(mr)


func clear() -> void:
	_k.clear()
	_p.clear()
	_v.clear()
	_life.clear()
	_max.clear()
	_g.clear()
	_s.clear()
	_x.clear()
	_c.clear()
	_beams.clear()
	for t: Dictionary in _texts:
		(t["label"] as Label3D).visible = false
		_label_pool.append(t["label"])
	_texts.clear()


func count() -> int:
	return _k.size()


func _add(kind: int, p: Vector3, v: Vector3, life: float, c: Color, g: float = 0.0, s: float = 1.0, x: float = 0.0) -> void:
	if _k.size() >= max_particles:
		if randf() < 0.7:
			return
		_remove(0)
	_k.append(kind)
	_p.append(p)
	_v.append(v)
	_life.append(life)
	_max.append(life)
	_g.append(g)
	_s.append(s)
	_x.append(x)
	_c.append(c)


func _remove(i: int) -> void:
	var last: int = _k.size() - 1
	if i != last:
		_k[i] = _k[last]
		_p[i] = _p[last]
		_v[i] = _v[last]
		_life[i] = _life[last]
		_max[i] = _max[last]
		_g[i] = _g[last]
		_s[i] = _s[last]
		_x[i] = _x[last]
		_c[i] = _c[last]
	_k.resize(last)
	_p.resize(last)
	_v.resize(last)
	_life.resize(last)
	_max.resize(last)
	_g.resize(last)
	_s.resize(last)
	_x.resize(last)
	_c.resize(last)


# ------------------------------------------------------------------ emitters --

func sparks(p: Vector3, n: int, c: Color, force: float, g: float = 40.0) -> void:
	for i: int in range(n):
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_add(SPARK, p, d * force * randf_range(0.3, 1.0), randf_range(0.25, 0.8), c, g)


## Blood: streaks thrown along `dir` with a spread, plus `gore` tumbling chunks.
func spray(p: Vector3, dir: Vector3, n: int, force: float, gore: int) -> void:
	for i: int in range(n):
		var sp: float = force * randf_range(0.3, 1.2)
		var v: Vector3 = dir * sp + Vector3(randf_range(-1, 1) * force * 0.55, randf_range(-0.2, 1.0) * force * 0.7, randf_range(-1, 1) * force * 0.55)
		_add(BLOOD, p, v, randf_range(0.9, 2.2), Mats.GORE if randf() < 0.3 else Mats.BLOOD, 75.0, randf_range(1.0, 2.6))
	for i2: int in range(gore):
		var v2: Vector3 = Vector3(randf_range(-1, 1) * force * 0.8 + dir.x * force * 0.4, randf_range(0.4, 1.4) * force * 0.9, randf_range(-1, 1) * force * 0.8 + dir.z * force * 0.4)
		_add(GIB, p, v2, randf_range(2.0, 3.5), Mats.BLOOD, 80.0, randf_range(1.5, 4.0), randf() * TAU)


func ring(p: Vector3, r: float, grow: float, life: float, c: Color) -> void:
	_add(RING, p, Vector3.ZERO, life, c, 0.0, r, grow)


func stain(p: Vector3, r: float) -> void:
	_add(STAIN, p, Vector3.ZERO, 7.0, Mats.GORE, 0.0, r, randf() * TAU)


func smoke(p: Vector3, v: Vector3, size: float, life: float) -> void:
	_add(SMOKE, p, v, life, Mats.MTN, -1.0, size)


func boom(p: Vector3, size: float, c: Color = Mats.FIRE) -> void:
	_add(BOOM, p, Vector3.ZERO, 0.55 + size * 0.15, c, 0.0, size * 4.0)
	sparks(p, int(10 + size * 10), Mats.FIRE, 60.0 + size * 30.0, 30.0)
	sparks(p, int(6 + size * 4), Mats.TRACER, 90.0 + size * 30.0, 20.0)
	for i: int in range(int(2 + size)):
		smoke(p + Vector3(randf_range(-4, 4), randf_range(0, 4), randf_range(-4, 4)) * size, Vector3(randf_range(-3, 3), randf_range(8, 18), randf_range(-3, 3)), size * randf_range(2, 4), randf_range(1.5, 3.0))
	if p.y < 6.0 and p.z < Game.coast_z(p.x) + 2.0:
		ring(Vector3(p.x, 0.6, p.z), size * 3.0, 30.0 + size * 10.0, 1.4, Mats.CYAN)
		sparks(Vector3(p.x, 1, p.z), int(8 * size), Mats.CYAN, 50.0, 60.0)
	shake_at(p, size * 1.6)


## Firework air-burst for the hanabi flak.
func hanabi(p: Vector3, size: float) -> void:
	var cols: Array[Color] = [Mats.SAKURA, Mats.GOLD, Mats.CYAN, Mats.WHITE, Mats.SHU, Mats.RYU]
	var c1: Color = cols.pick_random()
	var c2: Color = cols.pick_random()
	var n: int = int(26 + size * 10)
	for i: int in range(n):
		var a: float = TAU * float(i) / float(n)
		var b: float = randf_range(-1, 1)
		var r: float = sqrt(1.0 - b * b)
		var f: float = 45.0 * size * randf_range(0.85, 1.1)
		_add(SPARK, p, Vector3(cos(a) * r, b, sin(a) * r) * f, randf_range(0.8, 1.3), c1 if i % 2 == 0 else c2, 18.0)
	_add(BOOM, p, Vector3.ZERO, 0.3, Mats.WHITE, 0.0, 2.0)


func muzzle(p: Vector3, c: Color, size: float) -> void:
	for i: int in range(6):
		var d: Vector3 = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_frame_lines.append([p, p + d * size * randf_range(0.5, 1.0), c])


func beam(a: Vector3, b: Vector3, c: Color, w: float, life: float) -> void:
	_beams.append({"kind": "beam", "a": a, "b": b, "c": c, "w": w, "life": life, "max": life})


func bolt(a: Vector3, b: Vector3, life: float) -> void:
	_beams.append({"kind": "bolt", "a": a, "b": b, "c": Mats.BOLT, "w": 0.0, "life": life, "max": life})


func line_flash(a: Vector3, b: Vector3, c: Color, life: float) -> void:
	_beams.append({"kind": "line", "a": a, "b": b, "c": c, "w": 0.0, "life": life, "max": life})


## Lines and ribbons that only exist this frame (shots in flight).
func frame_line(a: Vector3, b: Vector3, c: Color) -> void:
	_frame_lines.append([a, b, c])


func frame_ribbon(a: Vector3, b: Vector3, c: Color, w: float) -> void:
	_frame_ribbons.append([a, b, c, w])


func text(p: Vector3, s: String, c: Color, size: float, life: float, rise: float = 8.0) -> void:
	var lab: Label3D
	if not _label_pool.is_empty():
		lab = _label_pool.pop_back()
	else:
		lab = Label3D.new()
		lab.font = Mats.font_display()
		lab.font_size = 96
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true
		lab.shaded = false
		lab.fixed_size = false
		lab.outline_size = 18
		lab.outline_modulate = Color(0, 0, 0, 1)
		lab.render_priority = 10
		lab.outline_render_priority = 9
		add_child(lab)
	lab.text = s
	lab.position = p
	lab.pixel_size = size * 0.012
	lab.modulate = Color(c.r * 1.8, c.g * 1.8, c.b * 1.8, 1.0)
	lab.rotation = Vector3.ZERO
	lab.visible = true
	_texts.append({"label": lab, "life": life, "max": life, "rise": rise, "size": size})
	if _texts.size() > 60:
		var old: Dictionary = _texts.pop_front()
		(old["label"] as Label3D).visible = false
		_label_pool.append(old["label"])


func shake_at(p: Vector3, amt: float) -> void:
	if Game.rig == null:
		return
	var d: float = Game.rig.cam.global_position.distance_to(p)
	Game.shake = minf(3.0, Game.shake + amt * clampf(140.0 / (d + 40.0), 0.0, 1.5))


# ------------------------------------------------------------------ simulate --

func update(dt: float) -> void:
	var i: int = _k.size() - 1
	while i >= 0:
		_life[i] -= dt
		if _life[i] <= 0.0:
			_remove(i)
			i -= 1
			continue
		var k: int = _k[i]
		if k == RING:
			_s[i] += _x[i] * dt
			i -= 1
			continue
		if k == STAIN:
			_s[i] += 1.5 * dt
			i -= 1
			continue
		if k == BOOM:
			_s[i] += dt * 60.0 * (1.0 + _max[i])
			i -= 1
			continue
		if k == SPLAT:
			i -= 1
			continue
		var v: Vector3 = _v[i]
		v.y -= _g[i] * dt
		var drag: float = 0.985 if k == SPARK else 0.995
		v.x *= drag
		v.z *= drag
		_v[i] = v
		var p: Vector3 = _p[i] + v * dt
		_p[i] = p
		if k == SMOKE:
			_s[i] += dt * 3.0
		elif k == GIB:
			_x[i] += dt * 8.0
			if randf() < 0.5:
				_add(BLOOD, p, Vector3(randf_range(-3, 3), randf_range(-2, 4), randf_range(-3, 3)), 0.6, Mats.GORE, 60.0, 1.0)
		if (k == BLOOD or k == GIB) and v.y < 0.0:
			var sy: float = Game.surface_y(p.x, p.z)
			if p.y < sy:
				if p.z < Game.coast_z(p.x):
					if randf() < (1.0 if k == GIB else 0.14):
						_add(STAIN, Vector3(p.x, sy + 0.3, p.z), Vector3.ZERO, 7.0, Mats.GORE, 0.0, randf_range(2, 5) * (2.0 if k == GIB else 1.0), randf() * TAU)
					if k == GIB:
						ring(Vector3(p.x, 0.6, p.z), 2.0, 25.0, 0.9, Mats.CYAN)
						sparks(Vector3(p.x, sy, p.z), 6, Mats.CYAN, 30.0, 60.0)
				elif randf() < 0.3:
					_add(SPLAT, Vector3(p.x, 2.15, p.z), Vector3.ZERO, 9.0, Mats.GORE, 0.0, randf_range(1.5, 3.5), randf() * TAU)
				_remove(i)
		elif k == SPARK and p.y < -1.0:
			_remove(i)
		i -= 1
	for j: int in range(_beams.size() - 1, -1, -1):
		_beams[j]["life"] = float(_beams[j]["life"]) - dt
		if float(_beams[j]["life"]) <= 0.0:
			_beams.remove_at(j)
	for j2: int in range(_texts.size() - 1, -1, -1):
		var t: Dictionary = _texts[j2]
		t["life"] = float(t["life"]) - dt
		var lab: Label3D = t["label"]
		if float(t["life"]) <= 0.0:
			lab.visible = false
			_label_pool.append(lab)
			_texts.remove_at(j2)
			continue
		lab.position.y += float(t["rise"]) * dt
		var f: float = float(t["life"]) / float(t["max"])
		var pop: float = 1.0 + (f - 0.85) * 4.0 if f > 0.85 else 1.0
		# Keep text readable but never let it fill the screen when it pops up next to the camera.
		var dist: float = Game.rig.cam.global_position.distance_to(lab.position) if Game.rig != null else 500.0
		lab.pixel_size = minf(float(t["size"]) * 0.012 * pop, dist * 0.00045)
		lab.modulate.a = minf(1.0, f * 2.5)
		lab.outline_modulate.a = minf(1.0, f * 2.5)


# ------------------------------------------------------------------ draw --

func draw() -> void:
	var cam: Vector3 = Game.rig.cam.global_position if Game.rig != null else Vector3.ZERO
	_lines.clear()
	var n: int = _k.size()
	var any: bool = n > 0 or not _frame_lines.is_empty() or not _beams.is_empty()
	if any:
		for i: int in range(n):
			var f: float = _life[i] / _max[i]
			var c: Color = _c[i] * clampf(f * 1.6, 0.0, 1.0)
			var p: Vector3 = _p[i]
			match _k[i]:
				SPARK:
					_seg(p, p - _v[i] * 0.03, c)
				BLOOD:
					_seg(p, p - _v[i] * (0.045 * _s[i]), c)
				GIB:
					_gib(p, _s[i], _x[i], c)
				RING:
					_circle(p, _s[i], 16, c)
				STAIN:
					var sy: float = Game.wave_h(p.x, p.z) + 0.3
					_blob(Vector3(p.x, sy, p.z), _s[i], _x[i], c * 0.8)
				SPLAT:
					_blob(p, _s[i], _x[i], c * 0.7)
				BOOM:
					_ball(p, _s[i], Mats.WHITE * clampf(f * 1.6, 0.0, 1.0) if f > 0.5 else c)
				SMOKE:
					_circle(p, _s[i], 7, c * 0.45)
					_circle(p + Vector3(0, _s[i] * 0.5, 0), _s[i] * 0.7, 7, c * 0.35)
		for fl: Array in _frame_lines:
			_seg(fl[0], fl[1], fl[2])
		for b: Dictionary in _beams:
			var bf: float = float(b["life"]) / float(b["max"])
			if b["kind"] == "bolt":
				var a: Vector3 = b["a"]
				var e: Vector3 = b["b"]
				var prev: Vector3 = a
				for s: int in range(1, 9):
					var t: float = float(s) / 8.0
					var jit: float = 0.0 if s == 8 else 5.0 * (1.0 - absf(t - 0.5))
					var q: Vector3 = a.lerp(e, t) + Vector3(randf_range(-jit, jit), randf_range(-jit, jit), randf_range(-jit, jit))
					_seg(prev, q, (Mats.WHITE if s % 3 == 0 else Mats.BOLT) * (0.6 + bf))
					prev = q
			elif b["kind"] == "line":
				_seg(b["a"], b["b"], (b["c"] as Color) * bf)
	_lines.commit()
	_frame_lines.clear()
	_ribbons.clear_surfaces()
	var has_rib: bool = not _frame_ribbons.is_empty()
	for b2: Dictionary in _beams:
		if b2["kind"] == "beam":
			has_rib = true
			break
	if has_rib:
		_ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for r: Array in _frame_ribbons:
			_ribbon(r[0], r[1], r[3], r[2], cam)
		for b3: Dictionary in _beams:
			if b3["kind"] != "beam":
				continue
			var bf2: float = float(b3["life"]) / float(b3["max"])
			var w: float = float(b3["w"]) * (0.4 + bf2 * 0.6)
			_ribbon(b3["a"], b3["b"], w * 2.4, (b3["c"] as Color) * 0.35 * bf2, cam)
			_ribbon(b3["a"], b3["b"], w, (b3["c"] as Color) * bf2, cam)
			_ribbon(b3["a"], b3["b"], w * 0.3, Mats.WHITE * bf2, cam)
		_ribbons.surface_end()
	_frame_ribbons.clear()


func _seg(a: Vector3, b: Vector3, c: Color) -> void:
	_lines.seg(a, b, c)


func _circle(p: Vector3, r: float, n: int, c: Color) -> void:
	var prev: Vector3 = p + Vector3(r, 0, 0)
	for i: int in range(1, n + 1):
		var a: float = TAU * float(i) / float(n)
		var q: Vector3 = p + Vector3(cos(a) * r, 0, sin(a) * r)
		_seg(prev, q, c)
		prev = q


func _blob(p: Vector3, r: float, ph: float, c: Color) -> void:
	var prev: Vector3 = Vector3.ZERO
	for i: int in range(10):
		var a: float = TAU * float(i) / 9.0
		var rr: float = r * (1.0 + 0.35 * sin(a * 3.0 + ph * 5.0))
		var q: Vector3 = p + Vector3(cos(a + ph) * rr, 0, sin(a + ph) * rr)
		if i > 0:
			_seg(prev, q, c)
		prev = q


func _ball(p: Vector3, r: float, c: Color) -> void:
	for k: int in range(3):
		var y: float = (float(k) - 1.0) * r * 0.6
		_circle(p + Vector3(0, y, 0), r * (0.8 if k != 1 else 1.0), 10, c)
	for m: int in range(4):
		var a: float = PI * float(m) / 4.0
		var prev: Vector3 = p + Vector3(0, -r, 0)
		for i: int in range(1, 7):
			var th: float = PI * float(i) / 6.0
			var q: Vector3 = p + Vector3(sin(th) * cos(a), -cos(th), sin(th) * sin(a)) * r
			_seg(prev, q, c)
			prev = q


func _gib(p: Vector3, s: float, r: float, c: Color) -> void:
	var b: Basis = Basis(Vector3(0.3, 1, 0.2).normalized(), r) * s
	var t0: Vector3 = p + b * Vector3(0, 1, 0)
	var t1: Vector3 = p + b * Vector3(-1, -0.5, -0.6)
	var t2: Vector3 = p + b * Vector3(1, -0.5, -0.6)
	var t3: Vector3 = p + b * Vector3(0, -0.5, 1)
	_seg(t0, t1, c)
	_seg(t0, t2, c)
	_seg(t0, t3, Mats.GORE)
	_seg(t1, t2, c)
	_seg(t2, t3, Mats.GORE)
	_seg(t3, t1, c)


func _ribbon(a: Vector3, b: Vector3, w: float, c: Color, cam: Vector3) -> void:
	var d: Vector3 = b - a
	if d.length_squared() < 1e-6:
		return
	var side: Vector3 = d.cross(cam - a).normalized() * w * 0.5
	if not side.is_finite():
		return
	var p0: Vector3 = a - side
	var p1: Vector3 = a + side
	var p2: Vector3 = b + side
	var p3: Vector3 = b - side
	for q: Vector3 in [p0, p1, p2, p0, p2, p3]:
		_ribbons.surface_set_color(c)
		_ribbons.surface_add_vertex(q)
