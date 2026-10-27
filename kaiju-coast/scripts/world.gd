class_name World
extends Node3D
## Everything that doesn't fight: the sky and glow, the sea, the beach and seawall with its
## lantern string, the torii in the bay, the volcano island the kaiju come from, Mt Fuji, and the
## city. City blocks are dark solids with neon edges in the Rust & Iron style: lit windows that
## switch on and off, setbacks, water tanks, AC units, antenna beacons, vertical kanji blade signs,
## rooftop marquees, flickering ad screens and shop fronts. Kaiju knock them down.

const MOON_DIR: Vector3 = Vector3(0.3, 0.27, -0.92)
const SIGNS: Array[String] = ["ラーメン", "居酒屋", "寿司", "カラオケ", "電気", "酒", "パチンコ", "怪獣注意", "旅館", "銭湯",
	"書店", "茶", "喫茶", "本日営業", "ホテル", "焼鳥", "薬", "質", "麻雀", "うどん"]
const EDGE_COLS: Array[Color] = [Mats.AMBER, Mats.AMBER, Mats.GOLD, Mats.CYAN, Mats.SAKURA, Mats.PAPER, Mats.CYAN]
const WINDOW_COLS: Array[Color] = [Mats.AMBER, Mats.AMBER, Mats.WARM, Color(0.55, 0.92, 1.0), Color(1.0, 0.32, 0.78)]
const NEON: Array[Color] = [Color(1.0, 0.2, 0.75), Color(0.15, 0.95, 1.0), Color(1.0, 0.62, 0.15), Color(0.7, 0.35, 1.0), Color(0.78, 1.0, 0.24)]

var env: Environment
var buildings: Array[Dictionary] = []
var _ocean_mats: Array[ShaderMaterial] = []
var _cars: Array[Dictionary] = []
var _volcano_t: float = 0.0
var _beacon_mat: ShaderMaterial
var _lava_mat: ShaderMaterial
var _city_root: Node3D


func _ready() -> void:
	_make_environment()
	_make_sea()
	_make_land()
	_make_seawall()
	_make_torii(Vector3(-46, -3, -78))
	_make_volcano()
	_make_fuji()
	_beacon_mat = Mats.make_line(4.0)
	_beacon_mat.set_shader_parameter("pulse", 0.9)
	_beacon_mat.set_shader_parameter("pulse_speed", 3.0)
	_city_root = Node3D.new()
	_city_root.name = "City"
	add_child(_city_root)
	build_city()
	_make_traffic()


func _process(delta: float) -> void:
	for m: ShaderMaterial in _ocean_mats:
		m.set_shader_parameter("t", Game.t)
	_update_buildings(delta)
	_update_traffic(delta)
	_volcano_t -= delta
	if _volcano_t <= 0.0 and Game.fx != null:
		_volcano_t = randf_range(0.4, 0.9)
		Game.fx.smoke(Vector3(330 + randf_range(-30, 30), 160, -1480 + randf_range(-20, 20)), Vector3(randf_range(-4, 4), randf_range(14, 24), 0), randf_range(14, 26), 7.0)


# ------------------------------------------------------------------ sky & sea --

func _make_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat: ShaderMaterial = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("moon_dir", MOON_DIR)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.1)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.9)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.7)
	env.set_glow_level(5, 0.4)
	env.glow_intensity = 1.25
	env.glow_strength = 1.1
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.02, 0.07)
	env.fog_density = 0.00042
	env.fog_sky_affect = 0.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _make_sea() -> void:
	var shader: Shader = preload("res://shaders/ocean.gdshader")
	var near: PlaneMesh = PlaneMesh.new()
	near.size = Vector2(3200, 1720)
	near.subdivide_width = 300
	near.subdivide_depth = 170
	var m1: ShaderMaterial = ShaderMaterial.new()
	m1.shader = shader
	m1.set_shader_parameter("moon_dir", MOON_DIR)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = near
	mi.material_override = m1
	mi.position = Vector3(0, 0, -850)
	mi.extra_cull_margin = 10.0
	add_child(mi)
	var far: PlaneMesh = PlaneMesh.new()
	far.size = Vector2(16000, 16000)
	var m2: ShaderMaterial = m1.duplicate() as ShaderMaterial
	m2.set_shader_parameter("flat_far", 1.0)
	m2.set_shader_parameter("near_rect", Vector4(-1599, -1709, 1599, 0))
	var mf: MeshInstance3D = MeshInstance3D.new()
	mf.name = "FarSea"
	mf.mesh = far
	mf.material_override = m2
	mf.position = Vector3(0, -0.6, -2000)
	add_child(mf)
	_ocean_mats = [m1, m2]


func _make_land() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(6000, 3000)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = preload("res://shaders/land.gdshader")
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Land"
	mi.mesh = plane
	mi.material_override = m
	mi.position = Vector3(0, 1.9, 1480)
	add_child(mi)
	# Contour ridges behind the city.
	var lb: LineBuilder = LineBuilder.new()
	var prev: Vector3 = Vector3.ZERO
	for i: int in range(27):
		var x: float = -2600.0 + float(i) * 200.0
		var p: Vector3 = Vector3(x, 60.0 + 70.0 * absf(sin(x * 0.0021)) + 40.0 * sin(x * 0.007), 1250)
		if i > 0:
			lb.line(prev, p, Mats.MTN * 0.6)
		prev = p
	_add_mesh(lb.build_mesh(), Mats.line(1.6))


func _make_seawall() -> void:
	var sb: SolidBuilder = SolidBuilder.new()
	var x: float = -1400.0
	while x < 1400.0:
		var x2: float = x + 40.0
		var z1: float = Game.coast_z(x) + Game.WALL
		var z2: float = Game.coast_z(x2) + Game.WALL
		var a: Vector3 = Vector3(x, 2, z1)
		var b: Vector3 = Vector3(x2, 2, z2)
		var up: Vector3 = Vector3(0, 5, 0)
		var out: Vector3 = Vector3(0, 0, 1.6)
		sb.quad(a - out, b - out, b - out + up, a - out + up, Mats.PAPER)
		sb.quad(a - out + up, b - out + up, b + out + up, a + out + up, Mats.PAPER)
		sb.edge(a - out + up, b - out + up, Mats.PAPER)
		sb.edge(a - out, b - out, Mats.PAPER * 0.5)
		sb.edge(a - out, a - out + up, Mats.PAPER * 0.7)
		# Waterline and sand edge.
		sb.edge(Vector3(x, 0.6, Game.coast_z(x)), Vector3(x2, 0.6, Game.coast_z(x2)), Mats.GOLD)
		sb.edge(Vector3(x, 2.05, Game.coast_z(x) + 8), Vector3(x2, 2.05, Game.coast_z(x2) + 8), Mats.GOLD * 0.35)
		x = x2
	# Chochin lanterns strung along the wall.
	var lantern: SolidBuilder = SolidBuilder.new()
	var lx: float = -420.0
	var k: int = 0
	while lx < 420.0:
		var za: float = Game.coast_z(lx) + Game.WALL
		var zb: float = Game.coast_z(lx + 30.0) + Game.WALL
		sb.edge(Vector3(lx, 7, za), Vector3(lx, 14, za), Mats.PAPER * 0.8)
		var prev: Vector3 = Vector3(lx, 14, za)
		for s: int in range(1, 7):
			var f: float = float(s) / 6.0
			var p: Vector3 = Vector3(lx + 30.0 * f, 14.0 - sin(f * PI) * 3.5, lerpf(za, zb, f))
			sb.edge(prev, p, Mats.PAPER * 0.5)
			prev = p
			if s == 2 or s == 4:
				var col: Color = Mats.SHU if (s + k) % 2 == 0 else Mats.GOLD
				col.a = randf()
				lantern.glow_ball(p + Vector3(0, -2.6, 0), Vector3(1.4, 1.9, 1.4), col, 4)
		lx += 30.0
		k += 1
	sb.attach(self, Mats.fill(), Mats.line(2.0))
	lantern.attach(self, Mats.fill(), Mats.line(), Mats.windows("lanterns"))


func _make_torii(at: Vector3) -> void:
	var sb: SolidBuilder = SolidBuilder.new()
	sb.xf = Transform3D(Basis(Vector3.UP, 0.05), at)
	var c: Color = Mats.SHU
	for s: float in [-1.0, 1.0]:
		sb.tube(Vector3(s * 15, 0, 0), Vector3(s * 15, 38, 0), 1.8, 1.4, 10, c, 2, 4)
	# Kasagi: the upper lintel, swept up at the ends, in short solid segments.
	for i: int in range(12):
		var xa: float = -24.0 + float(i) * 4.0
		var xb: float = xa + 4.0
		var ya: float = 39.5 + 2.6 * pow(absf(xa) / 24.0, 2.2)
		var yb: float = 39.5 + 2.6 * pow(absf(xb) / 24.0, 2.2)
		sb.tube(Vector3(xa, ya, 0), Vector3(xb, yb, 0), 1.6, 1.6, 4, c, 0, 2)
	sb.box(Vector3(0, 37, 0), Vector3(34, 1.8, 2.2), c)
	sb.box(Vector3(0, 29, 0), Vector3(40, 2.2, 1.8), c)
	sb.box(Vector3(0, 33, -0.4), Vector3(3.2, 6, 1.2), Mats.GOLD)
	sb.attach(self, Mats.fill(), Mats.line(2.6))


func _make_volcano() -> void:
	var sb: SolidBuilder = SolidBuilder.new()
	sb.xf = Transform3D(Basis.from_scale(Vector3(1, 1, 0.6)), Vector3(330, -20, -1480))
	var n: int = 18
	var top: float = 170.0
	for i: int in range(n):
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var j0: float = 0.75 + 0.25 * sin(float(i) * 2.7)
		var j1: float = 0.75 + 0.25 * sin(float(i + 1) * 2.7)
		var b0: Vector3 = Vector3(cos(a0) * 340.0 * j0, 0, sin(a0) * 340.0 * j0)
		var b1: Vector3 = Vector3(cos(a1) * 340.0 * j1, 0, sin(a1) * 340.0 * j1)
		var t0: Vector3 = Vector3(cos(a0) * 60.0, top, sin(a0) * 60.0)
		var t1: Vector3 = Vector3(cos(a1) * 60.0, top, sin(a1) * 60.0)
		sb.quad(b0, b1, t1, t0, Mats.MTN)
		sb.edge(b0, t0, Mats.MTN * 0.8)
		sb.edge(t0, t1, Mats.FIRE)
	sb.attach(self, Mats.fill(), Mats.line(1.8))
	# Lava runs that throb.
	var lava: LineBuilder = LineBuilder.new()
	lava.xf = sb.xf
	for i: int in range(7):
		var a: float = float(i) * 0.9 + 0.3
		var prev: Vector3 = Vector3(cos(a) * 60.0, top, sin(a) * 60.0)
		for s: int in range(1, 7):
			var f: float = float(s) / 6.0
			var p: Vector3 = Vector3(cos(a + sin(float(s + i)) * 0.2) * lerpf(60, 300, f), lerpf(top, 6, f), sin(a) * lerpf(60, 300, f))
			lava.line(prev, p, Mats.FIRE if s < 3 else Mats.BLOOD)
			prev = p
	_lava_mat = Mats.make_line(3.0)
	_lava_mat.set_shader_parameter("pulse", 0.45)
	_lava_mat.set_shader_parameter("pulse_speed", 2.2)
	_add_mesh(lava.build_mesh(), _lava_mat)
	_label(Vector3(330, 260, -1480), "鬼ヶ島", Mats.BLOOD * 2.0, 3.0, true)


func _make_fuji() -> void:
	var sb: SolidBuilder = SolidBuilder.new()
	sb.xf = Transform3D(Basis.from_scale(Vector3(1, 1, 0.5)), Vector3(-200, 0, 1500))
	var n: int = 22
	for i: int in range(n):
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var b0: Vector3 = Vector3(cos(a0) * 620, 0, sin(a0) * 620)
		var b1: Vector3 = Vector3(cos(a1) * 620, 0, sin(a1) * 620)
		var t0: Vector3 = Vector3(cos(a0) * 60, 380, sin(a0) * 60)
		var t1: Vector3 = Vector3(cos(a1) * 60, 380, sin(a1) * 60)
		sb.quad(b0, b1, t1, t0, Mats.MTN)
		sb.edge(b0, t0, Mats.MTN * 0.7)
		var s0: Vector3 = t0.lerp(b0, 0.22 + 0.06 * sin(float(i) * 3.3))
		var s1: Vector3 = t1.lerp(b1, 0.22 + 0.06 * sin(float(i + 1) * 3.3))
		sb.edge(s0, s1, Mats.WHITE * 0.9)
		sb.edge(t0, t1, Mats.WHITE)
	sb.attach(self, Mats.fill(), Mats.line(1.5))


# ------------------------------------------------------------------ city --

func build_city() -> void:
	for c: Node in _city_root.get_children():
		c.queue_free()
	buildings.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for gz: int in range(8):
		for gx: int in range(-11, 12):
			if gx == 0 or gx == -6 or gx == 6 or gz == 3:
				continue
			var x: float = float(gx) * 32.0 + rng.randf_range(-3, 3)
			var z: float = 84.0 + float(gz) * 34.0 + rng.randf_range(-3, 3)
			if absf(x - 60.0) < 40.0 and absf(z - 300.0) < 40.0:
				continue
			var centre: float = 1.0 - minf(1.0, absf(x) / 380.0)
			var h: float = 10.0 + rng.randf() * 26.0 + centre * 44.0 * rng.randf() + float(gz) * 4.0 * rng.randf()
			# The seafront stays low so the guns on the wall can be seen over it.
			if gz == 0:
				h = minf(h, 14.0 + rng.randf() * 10.0)
			elif gz == 1:
				h = minf(h, 26.0 + rng.randf() * 18.0)
			var w: float = 12.0 + rng.randf() * 12.0
			var d: float = 12.0 + rng.randf() * 12.0
			var kind: String = "box"
			if (gx == -9 and gz == 1) or (gx == 8 and gz == 2):
				kind = "pagoda"
			var b: Dictionary = {"x": x, "z": z, "w": w, "d": d, "h": h, "kind": kind, "fall": 0.0, "falling": false,
				"dir": -1.0 if rng.randf() < 0.5 else 1.0, "seed": rng.randi()}
			b["node"] = _make_building(b, rng)
			buildings.append(b)
	var tower: Node3D = _make_tower()
	_city_root.add_child(tower)
	buildings.append({"x": 60.0, "z": 300.0, "w": 44.0, "d": 44.0, "h": 150.0, "kind": "tower", "fall": 0.0, "falling": false,
		"dir": 1.0, "seed": 1, "node": tower})


func _make_building(b: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = Vector3(b["x"], 2, b["z"])
	_city_root.add_child(root)
	if b["kind"] == "pagoda":
		_make_pagoda(root)
		return root
	var w: float = b["w"]
	var d: float = b["d"]
	var h: float = b["h"]
	var col: Color = EDGE_COLS[rng.randi() % EDGE_COLS.size()]
	var sb: SolidBuilder = SolidBuilder.new()
	var lights: SolidBuilder = SolidBuilder.new()
	var signs: SolidBuilder = SolidBuilder.new()
	# Tiers: tall blocks step back once or twice.
	var tiers: Array = [[w, d, h]]
	if h > 38.0 and rng.randf() < 0.75:
		var h1: float = h * rng.randf_range(0.55, 0.72)
		tiers = [[w, d, h1], [w * 0.72, d * 0.72, h - h1]]
		if h > 60.0 and rng.randf() < 0.5:
			tiers.append([w * 0.42, d * 0.42, h * 0.16])
	var y: float = 0.0
	for ti: int in range(tiers.size()):
		var tw: float = tiers[ti][0]
		var td: float = tiers[ti][1]
		var th: float = tiers[ti][2]
		sb.box(Vector3(0, y + th * 0.5, 0), Vector3(tw, th, td), col)
		# Floor slabs.
		var fy: float = y + 6.0
		while fy < y + th - 1.0:
			_ring_rect(sb, tw * 0.5, td * 0.5, fy, col * 0.38)
			fy += 6.0
		_windows(lights, tw * 0.5, td * 0.5, y, th, rng)
		# Roof railing on each tier.
		_ring_rect(sb, tw * 0.5 - 0.6, td * 0.5 - 0.6, y + th + 1.0, col * 0.5)
		y += th
	var top_w: float = tiers[tiers.size() - 1][0] * 0.5
	var top_d: float = tiers[tiers.size() - 1][1] * 0.5
	# Rooftop clutter.
	if rng.randf() < 0.45:
		var tx: float = rng.randf_range(-top_w, top_w) * 0.5
		var tz: float = rng.randf_range(-top_d, top_d) * 0.5
		for lx: float in [-1.6, 1.6]:
			for lz: float in [-1.6, 1.6]:
				sb.edge(Vector3(tx + lx, y, tz + lz), Vector3(tx + lx, y + 3.0, tz + lz), Mats.PAPER * 0.6)
		sb.tube(Vector3(tx, y + 3.0, tz), Vector3(tx, y + 7.0, tz), 2.6, 2.6, 10, Mats.PAPER * 0.8, 1, 5)
		sb.cone(Vector3(tx, y + 7.0, tz), Vector3(tx, y + 8.6, tz), 2.7, 10, Mats.PAPER * 0.8)
	for i: int in range(rng.randi_range(0, 3)):
		var ax: float = rng.randf_range(-top_w + 2, top_w - 2)
		var az: float = rng.randf_range(-top_d + 2, top_d - 2)
		sb.box(Vector3(ax, y + 1.0, az), Vector3(3.0, 2.0, 2.2), Mats.CYAN * 0.6)
	if h > 34.0 or rng.randf() < 0.3:
		var mx: float = rng.randf_range(-top_w, top_w) * 0.4
		var mz: float = rng.randf_range(-top_d, top_d) * 0.4
		var mh: float = rng.randf_range(6, 16)
		sb.edge(Vector3(mx, y, mz), Vector3(mx, y + mh, mz), Mats.PAPER * 0.7)
		sb.edge(Vector3(mx - 2, y + mh * 0.6, mz), Vector3(mx + 2, y + mh * 0.6, mz), Mats.PAPER * 0.7)
		var beacon: SolidBuilder = SolidBuilder.new()
		beacon.glow_ball(Vector3(mx, y + mh + 0.6, mz), Vector3(0.7, 0.7, 0.7), Mats.BLOOD, 3)
		beacon.attach(root, Mats.fill(), Mats.line(), _beacon_mat)
	# Shop front: a glowing awning band at street level on the south (+z) and sea (-z) faces.
	var shop: Color = NEON[rng.randi() % NEON.size()]
	for s: float in [-1.0, 1.0]:
		shop.a = rng.randf()
		signs.glow_quad(Vector3(0, 3.2, s * (d * 0.5 + 0.25)), Vector3(w * 0.42, 0, 0), Vector3(0, 0.5, 0), shop)
	# Vertical kanji blade sign on a corner.
	if rng.randf() < 0.55:
		var txt: String = SIGNS[rng.randi() % SIGNS.size()]
		var nc: Color = NEON[rng.randi() % NEON.size()]
		var sh: float = minf(h * 0.7, 6.5 * float(txt.length()) + 4.0)
		var corner: Vector3 = Vector3(w * 0.5 + 2.2, minf(h - sh * 0.5 - 1.0, 4.0 + sh * 0.5 + rng.randf() * maxf(0.0, h - sh - 6.0)), d * 0.5 - 2.0)
		sb.box(corner, Vector3(0.6, sh, 4.6), nc)
		sb.edge(corner + Vector3(-2.2, sh * 0.4, 0), corner + Vector3(-0.3, sh * 0.4, 0), Mats.PAPER * 0.5)
		sb.edge(corner + Vector3(-2.2, -sh * 0.4, 0), corner + Vector3(-0.3, -sh * 0.4, 0), Mats.PAPER * 0.5)
		for face: float in [-1.0, 1.0]:
			var lab: Label3D = _sign_label(txt, nc, true, minf(1.0, sh / (6.5 * float(txt.length()))))
			lab.position = corner + Vector3(0, 0, face * 2.45)
			lab.rotation.y = 0.0 if face > 0.0 else PI
			root.add_child(lab)
	# Rooftop marquee or a pixel ad screen.
	var r: float = rng.randf()
	if r < 0.22 and top_w > 6.0:
		var txt2: String = SIGNS[rng.randi() % SIGNS.size()]
		var mc: Color = NEON[rng.randi() % NEON.size()]
		var mw: float = minf(top_w * 1.6, 5.5 * float(txt2.length()) + 4.0)
		var mcen: Vector3 = Vector3(0, y + 5.0, top_d * 0.5)
		sb.box(mcen, Vector3(mw, 6.0, 0.6), mc)
		sb.edge(mcen + Vector3(-mw * 0.4, -3, 0), Vector3(-mw * 0.4, y, top_d * 0.5), Mats.PAPER * 0.5)
		sb.edge(mcen + Vector3(mw * 0.4, -3, 0), Vector3(mw * 0.4, y, top_d * 0.5), Mats.PAPER * 0.5)
		var lab2: Label3D = _sign_label(txt2, mc, false, minf(1.0, mw / (5.5 * float(txt2.length()) + 2.0)))
		lab2.position = mcen + Vector3(0, 0, 0.4)
		root.add_child(lab2)
	elif r < 0.36 and h > 26.0:
		var screen: SolidBuilder = SolidBuilder.new()
		var cols: Array[Color] = [Color(1, 0.25, 0.7), Color(0.2, 0.9, 1.0), Color(1, 0.8, 0.3), Color(0.9, 0.9, 1.0)]
		var sw: float = w * 0.36
		var sy0: float = h * 0.45
		for gy: int in range(6):
			for gx: int in range(9):
				var c: Color = cols[rng.randi() % cols.size()]
				c.a = rng.randf()
				screen.glow_quad(Vector3(-sw + float(gx) * sw * 2.0 / 8.0, sy0 + float(gy) * 1.7, d * 0.5 + 0.35), Vector3(sw / 9.0, 0, 0), Vector3(0, 0.75, 0), c)
		sb.box(Vector3(0, sy0 + 4.25, d * 0.5 + 0.2), Vector3(sw * 2.0 + 3.0, 12.0, 0.4), Mats.PAPER * 0.6)
		screen.attach(root, Mats.fill(), Mats.line(), Mats.windows("screen"))
	sb.attach(root, Mats.fill(), Mats.line(2.2))
	lights.attach(root, Mats.fill(), Mats.line(), Mats.windows())
	signs.attach(root, Mats.fill(), Mats.line(), Mats.windows("signs"))
	return root


func _ring_rect(sb: SolidBuilder, hw: float, hd: float, y: float, col: Color) -> void:
	var a: Vector3 = Vector3(-hw, y, -hd)
	var b: Vector3 = Vector3(hw, y, -hd)
	var c: Vector3 = Vector3(hw, y, hd)
	var d: Vector3 = Vector3(-hw, y, hd)
	sb.edge(a, b, col)
	sb.edge(b, c, col)
	sb.edge(c, d, col)
	sb.edge(d, a, col)


func _windows(lights: SolidBuilder, hw: float, hd: float, y0: float, th: float, rng: RandomNumberGenerator) -> void:
	var faces: Array = [[Vector3(0, 0, hd + 0.12), Vector3.RIGHT, hw], [Vector3(0, 0, -hd - 0.12), Vector3.RIGHT, hw],
		[Vector3(hw + 0.12, 0, 0), Vector3.BACK, hd], [Vector3(-hw - 0.12, 0, 0), Vector3.BACK, hd]]
	for f: Array in faces:
		var c0: Vector3 = f[0]
		var along: Vector3 = f[1]
		var half: float = f[2]
		var wy: float = y0 + 5.5
		while wy < y0 + th - 2.0:
			var wx: float = -half + 2.2
			while wx < half - 1.6:
				var col: Color = WINDOW_COLS[rng.randi() % WINDOW_COLS.size()]
				col.a = rng.randf()
				lights.glow_quad(c0 + along * wx + Vector3(0, wy, 0), along * 0.6, Vector3(0, 0.8, 0), col)
				wx += 3.2
			wy += 4.5


func _sign_label(txt: String, col: Color, vertical: bool, scale: float) -> Label3D:
	var lab: Label3D = Label3D.new()
	lab.font = Mats.font_display()
	lab.font_size = 64
	lab.pixel_size = 0.075 * scale
	lab.modulate = Color(col.r * 2.2, col.g * 2.2, col.b * 2.2)
	lab.outline_size = 0
	lab.shaded = false
	lab.double_sided = false
	lab.no_depth_test = false
	if vertical:
		var s: String = ""
		for i: int in range(txt.length()):
			s += txt[i] + ("\n" if i < txt.length() - 1 else "")
		lab.text = s
		lab.line_spacing = -14.0
	else:
		lab.text = txt
	return lab


func _make_pagoda(root: Node3D) -> void:
	var sb: SolidBuilder = SolidBuilder.new()
	var lights: SolidBuilder = SolidBuilder.new()
	for i: int in range(5):
		var y: float = 4.0 + float(i) * 8.0
		var s: float = 8.0 - float(i) * 1.1
		var e: float = s + 4.5
		sb.box(Vector3(0, y - 1.0, 0), Vector3(s * 2.0, 6.0, s * 2.0), Mats.AMBER * 0.8)
		# Flared roof: a shallow pyramid frustum with upturned corners.
		var ry: float = y + 2.4
		var corners: Array[Vector3] = [Vector3(-e, ry, -e), Vector3(e, ry, -e), Vector3(e, ry, e), Vector3(-e, ry, e)]
		var inner: Array[Vector3] = [Vector3(-s * 0.6, ry + 2.6, -s * 0.6), Vector3(s * 0.6, ry + 2.6, -s * 0.6), Vector3(s * 0.6, ry + 2.6, s * 0.6), Vector3(-s * 0.6, ry + 2.6, s * 0.6)]
		for k: int in range(4):
			var k2: int = (k + 1) % 4
			sb.quad(corners[k], corners[k2], inner[k2], inner[k], Mats.SHU)
			sb.edge(corners[k], corners[k2], Mats.SHU)
			sb.edge(corners[k], corners[k] + Vector3(0, 1.6, 0) + (corners[k] - Vector3(0, ry, 0)).normalized() * 1.2, Mats.SHU)
			var lc: Color = Mats.GOLD
			lc.a = randf()
			lights.glow_ball(corners[k] + Vector3(0, -1.6, 0), Vector3(0.6, 0.9, 0.6), lc, 3)
		var wc: Color = Mats.AMBER
		wc.a = randf()
		lights.glow_quad(Vector3(0, y - 1.0, s + 0.15), Vector3(1.4, 0, 0), Vector3(0, 1.6, 0), wc)
	sb.tube(Vector3(0, 44, 0), Vector3(0, 60, 0), 0.6, 0.3, 6, Mats.GOLD)
	for k3: int in range(5):
		sb.tube(Vector3(0, 46.0 + float(k3) * 2.2, 0), Vector3(0, 46.6 + float(k3) * 2.2, 0), 1.6, 1.6, 8, Mats.GOLD)
	sb.attach(root, Mats.fill(), Mats.line(2.4))
	lights.attach(root, Mats.fill(), Mats.line(), Mats.windows("lanterns"))


func _make_tower() -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = Vector3(60, 2, 300)
	var sb: SolidBuilder = SolidBuilder.new()
	var H: float = 150.0
	var lv: Array[float] = [0.0, 30.0, 60.0, 90.0, 115.0, 150.0]
	var w_at: Callable = func(yy: float) -> float: return lerpf(22.0, 2.0, pow(yy / H, 0.7))
	for i: int in range(lv.size() - 1):
		var y0: float = lv[i]
		var y1: float = lv[i + 1]
		var w0: float = w_at.call(y0)
		var w1: float = w_at.call(y1)
		var cc: Color = Mats.WHITE if i % 2 == 1 else Mats.SHU
		for k: int in range(4):
			var sx: float = -1.0 if k < 2 else 1.0
			var sz: float = -1.0 if k % 3 == 0 else 1.0
			sb.tube(Vector3(sx * w0, y0, sz * w0), Vector3(sx * w1, y1, sz * w1), 0.9, 0.7, 4, cc, 0, 1)
		for side: int in range(4):
			var a0: Vector3 = [Vector3(-w0, y0, -w0), Vector3(w0, y0, -w0), Vector3(w0, y0, w0), Vector3(-w0, y0, w0)][side]
			var b0: Vector3 = [Vector3(w1, y1, -w1), Vector3(w1, y1, w1), Vector3(-w1, y1, w1), Vector3(-w1, y1, -w1)][side]
			var a1: Vector3 = [Vector3(w0, y0, -w0), Vector3(w0, y0, w0), Vector3(-w0, y0, w0), Vector3(-w0, y0, -w0)][side]
			var b1: Vector3 = [Vector3(-w1, y1, -w1), Vector3(w1, y1, -w1), Vector3(w1, y1, w1), Vector3(-w1, y1, w1)][side]
			sb.edge(a0, b0, cc * 0.6)
			sb.edge(a1, b1, cc * 0.6)
		_ring_rect(sb, w1 * 1.1, w1 * 1.1, y1, cc)
	sb.box(Vector3(0, 64, 0), Vector3(22, 7, 22), Mats.WHITE)
	sb.box(Vector3(0, 118, 0), Vector3(9, 4, 9), Mats.WHITE)
	sb.edge(Vector3(0, 150, 0), Vector3(0, 168, 0), Mats.SHU)
	var lights: SolidBuilder = SolidBuilder.new()
	for k2: int in range(16):
		var a: float = TAU * float(k2) / 16.0
		var c: Color = Mats.WARM
		c.a = randf()
		lights.glow_quad(Vector3(cos(a) * 11.3, 64, sin(a) * 11.3), Vector3(-sin(a) * 1.6, 0, cos(a) * 1.6), Vector3(0, 1.6, 0), c)
	lights.attach(root, Mats.fill(), Mats.line(), Mats.windows())
	sb.attach(root, Mats.fill(), Mats.line(2.6))
	var beacon: SolidBuilder = SolidBuilder.new()
	beacon.glow_ball(Vector3(0, 169, 0), Vector3(1.2, 1.2, 1.2), Mats.BLOOD, 4)
	beacon.attach(root, Mats.fill(), Mats.line(), _beacon_mat)
	return root


## Knock down the nearest standing building within reach (kaiju rampaging).
func smash_near(p: Vector3, reach: float) -> bool:
	var best: Dictionary = {}
	var bd: float = reach
	for b: Dictionary in buildings:
		if b["falling"]:
			continue
		var d: float = Vector2(float(b["x"]) - p.x, float(b["z"]) - p.z).length()
		if d < bd:
			bd = d
			best = b
	if best.is_empty():
		return false
	best["falling"] = true
	return true


func _update_buildings(dt: float) -> void:
	for b: Dictionary in buildings:
		if not b["falling"] or float(b["fall"]) >= 1.0:
			continue
		var f: float = minf(1.0, float(b["fall"]) + dt * 0.42)
		b["fall"] = f
		var node: Node3D = b["node"]
		var h: float = b["h"]
		node.position.y = 2.0 - f * f * h * 0.9
		node.rotation.z = float(b["dir"]) * f * f * 0.7
		node.rotation.x = f * 0.2
		if randf() < dt * 14.0:
			var bx: float = float(b["x"]) + randf_range(-1, 1) * float(b["w"]) * 0.5
			var bz: float = float(b["z"]) + randf_range(-1, 1) * float(b["d"]) * 0.5
			Game.fx.smoke(Vector3(bx, randf_range(2, maxf(3.0, h * (1.0 - f))), bz), Vector3(randf_range(-4, 4), randf_range(4, 10), randf_range(-4, 4)), randf_range(3, 8), 2.5)
			Game.fx.sparks(Vector3(float(b["x"]), h * (1.0 - f), float(b["z"])), 3, Mats.GOLD, 30.0, 50.0)
		if f >= 1.0:
			node.visible = false
			_make_rubble(b)


func _make_rubble(b: Dictionary) -> void:
	var lb: LineBuilder = LineBuilder.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(b["seed"])
	var w: float = b["w"]
	for i: int in range(10):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf() * w * 0.8
		lb.line(Vector3(cos(a) * r, 0, sin(a) * r), Vector3(cos(a + 1.3) * r * 0.6, rng.randf_range(2, 7), sin(a + 2.0) * r * 0.6), Mats.FIRE * 0.6)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = lb.build_mesh()
	mi.material_override = Mats.line(1.6)
	mi.position = Vector3(b["x"], 2, b["z"])
	_city_root.add_child(mi)


# ------------------------------------------------------------------ traffic --

func _make_traffic() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(1.6, 0.8)
	var head: StandardMaterial3D = StandardMaterial3D.new()
	head.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head.albedo_color = Color(2.4, 2.3, 2.0)
	head.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var tail: StandardMaterial3D = head.duplicate() as StandardMaterial3D
	tail.albedo_color = Color(2.6, 0.15, 0.2)
	for i: int in range(28):
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = quad
		var along_x: bool = i % 2 == 0
		var dir: float = 1.0 if i % 4 < 2 else -1.0
		mi.material_override = head if dir > 0.0 else tail
		add_child(mi)
		var lane: float
		if along_x:
			lane = 67.0 + 34.0 * float([0, 3, 8][i % 3]) + (2.0 if dir > 0.0 else -2.0)
		else:
			lane = [-192.0, 0.0, 192.0][i % 3] + (2.0 if dir > 0.0 else -2.0)
		_cars.append({"node": mi, "x_axis": along_x, "lane": lane, "dir": dir, "p": randf_range(-380, 380), "spd": randf_range(18, 34)})


func _update_traffic(dt: float) -> void:
	for c: Dictionary in _cars:
		var p: float = float(c["p"]) + float(c["dir"]) * float(c["spd"]) * dt
		var lim: float = 380.0 if c["x_axis"] else 140.0
		if p > lim:
			p = -lim
		elif p < -lim:
			p = lim
		c["p"] = p
		var node: MeshInstance3D = c["node"]
		if c["x_axis"]:
			node.position = Vector3(p, 3.0, c["lane"])
		else:
			node.position = Vector3(c["lane"], 3.0, 206.0 + p)


# ------------------------------------------------------------------ helpers --

func _add_mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	if mesh == null:
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi


func _label(p: Vector3, txt: String, col: Color, size: float, billboard: bool) -> Label3D:
	var lab: Label3D = Label3D.new()
	lab.font = Mats.font_display()
	lab.font_size = 96
	lab.pixel_size = size * 0.25
	lab.text = txt
	lab.modulate = col
	lab.shaded = false
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	lab.position = p
	add_child(lab)
	return lab
