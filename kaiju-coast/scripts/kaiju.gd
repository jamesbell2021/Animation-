class_name Kaiju
extends Node3D
## One kaiju: a rig of joints carrying solid parts (dark fill + neon edges + glowing eyes), posed
## procedurally every frame, plus its AI (wade in, breathe beams at guns, rampage on the shore,
## or for tengu, hunt the airship). Hit spheres ride the joints; the glowing eyes, the dragon's
## pearl and the Dai-Oni's chest core are weak points.

static var _cache: Dictionary = {}
static var _eye_mat: ShaderMaterial

var type: String = "oni"
var def: Dictionary
var hp: float = 100.0
var max_hp: float = 100.0
var state: String = "advance"
var dying: bool = false
var dead: bool = false
var die_t: float = 0.0
var phase: float = 0.0
var target_x: float = 0.0
var vel: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var slow: float = 0.0
var breath_cd: float = 7.0
var breath_t: float = 0.0
var breath_target: Variant = null
var fired: bool = false
var roar_t: float = 0.0
var smash_cd: float = 2.0
var orb: float = 0.0
var atk: float = 1.0
var bank: float = 0.0
var rear: float = 0.0
var size_jit: float = 1.0
var fall_dir: float = 1.0
var splashed: bool = false
var last_step: float = 0.0
var last_by: String = ""
var flash_t: float = 0.0
var stagger: float = 0.0                 ## 0..1, builds up under heavy fire: slows, rocks the body
var recoil: float = 0.0                  ## head snap when a weak point is hit
var enraged: bool = false                ## a weak point was destroyed: faster and angrier
var _death_step: int = 0
var knock: float = 0.0                   ## pushed back out to sea by the flood gates
# Special moves.
var burrowing: bool = false
var burrow_done: bool = false
var burrow_target: Turret = null
var coil_t: float = 0.0
var coil_done: bool = false
var coil_target: Turret = null
var dive: bool = false
var _heads: Array[Dictionary] = []      ## Orochi: {segs, head, mouth, eyes, alive}
var _breath_head: int = 0
var wounds: Array[Dictionary] = []
var spheres: Array[Dictionary] = []      ## {node, off, r, weak}
var hits: Array[Dictionary] = []         ## world space, refreshed each frame: {p, r, weak}
var aim: Vector3 = Vector3.ZERO
var exposed: bool = false
var mouth: Node3D
var uid: int = 0

var _fill: ShaderMaterial
var _line: ShaderMaterial
var _spine: ShaderMaterial
var _j: Dictionary = {}
var _segs: Array[Node3D] = []
var _seg_len: Array[float] = []


func setup(t: String, hp_mul: float, id: int) -> void:
	type = t
	def = Game.KT[t]
	uid = id
	hp = float(def["hp"]) * hp_mul
	max_hp = hp
	phase = randf() * TAU
	orb = randf() * TAU
	breath_cd = randf_range(5, 10)
	size_jit = 1.0 if def["boss"] else randf_range(0.92, 1.1)
	_fill = Mats.make_fill(0.1)
	_line = Mats.make_line(2.7)
	_spine = Mats.make_glow(3.2)
	if _eye_mat == null:
		_eye_mat = Mats.make_glow(4.5)
		_eye_mat.set_shader_parameter("pulse", 0.25)
		_eye_mat.set_shader_parameter("pulse_speed", 9.0)
	var col: Color = def["col"]
	match t:
		"oni", "daioni":
			_build_oni(col, t == "daioni")
		"kani":
			_build_kani(col)
		"ryu":
			_build_ryu(col)
		"tengu":
			_build_tengu(col)
		"orochi":
			_build_orochi(col)
	scale = Vector3.ONE * float(def["scale"]) * size_jit


# ------------------------------------------------------------------ rig helpers --

func _joint(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	_j[name] = n
	return n


## Attach a cached solid part (built once per kaiju type by `build`) to `parent`.
func _part(parent: Node3D, key: String, build: Callable) -> void:
	_part_g(parent, key, null, build)


func _part_g(parent: Node3D, key: String, glow_mat: Material, build: Callable) -> void:
	var ck: String = type + "/" + key
	if not _cache.has(ck):
		var sb: SolidBuilder = SolidBuilder.new()
		build.call(sb)
		_cache[ck] = [sb.fill_mesh(), sb.line_mesh(), sb.glow_mesh()]
	var meshes: Array = _cache[ck]
	var mats: Array = [_fill, _line, glow_mat if glow_mat != null else _eye_mat]
	for i: int in range(3):
		if meshes[i] == null:
			continue
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = meshes[i]
		mi.material_override = mats[i]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


func _hit(node: Node3D, off: Vector3, r: float, weak: bool = false) -> void:
	spheres.append({"node": node, "off": off, "r": r, "weak": weak, "whp": 0.0, "eye": null, "kind": ""})


## A weak point with its own glowing mesh and hit points: shoot it out and it goes dark and bleeds.
func _weak(parent: Node3D, kind: String, off: Vector3, glow_r: Vector3, col: Color, hit_r: float, hp_frac: float) -> void:
	var n: Node3D = Node3D.new()
	n.position = off
	parent.add_child(n)
	_part(n, "weak_" + kind, func(sb: SolidBuilder) -> void: sb.glow_ball(Vector3.ZERO, glow_r, col, 4))
	spheres.append({"node": n, "off": Vector3.ZERO, "r": hit_r, "weak": true, "whp": max_hp * hp_frac, "eye": n, "kind": kind})


# ------------------------------------------------------------------ builds --

func _build_oni(c: Color, boss: bool) -> void:
	var body: Node3D = _joint("body", self, Vector3.ZERO)
	for s: float in [-1.0, 1.0]:
		var side: String = "L" if s < 0.0 else "R"
		var hip: Node3D = _joint("hip" + side, body, Vector3(s * 9, 30, 2))
		_part(hip, "thigh", func(sb: SolidBuilder) -> void: sb.tube(Vector3.ZERO, Vector3(0, -15, 0), 6, 5, 8, c, 1, 4))
		_hit(hip, Vector3(0, -6, 0), 6.5)
		var knee: Node3D = _joint("knee" + side, hip, Vector3(0, -15, 0))
		_part(knee, "shin", func(sb: SolidBuilder) -> void: sb.tube(Vector3.ZERO, Vector3(0, -15, 0), 5, 3.6, 8, c, 1, 4))
		var ankle: Node3D = _joint("ankle" + side, knee, Vector3(0, -15, 0))
		_part(ankle, "foot", func(sb: SolidBuilder) -> void:
			sb.box(Vector3(0, 1.25, -3), Vector3(8, 2.5, 12), c)
			for tx: float in [-3.0, 0.0, 3.0]:
				sb.cone(Vector3(tx, 0.8, -9), Vector3(tx, 0.0, -12.5), 0.9, 4, Mats.WHITE))
	# Tail: a chain of tapering segments that whips as it walks.
	var prev: Node3D = _joint("tail0", body, Vector3(0, 30, 8))
	for i: int in range(9):
		var r0: float = 7.0 - 0.7 * float(i)
		var r1: float = 7.0 - 0.7 * float(i + 1)
		var key: String = "tail%d" % i
		_part_g(prev, key, _spine, func(sb: SolidBuilder) -> void:
			sb.tube(Vector3.ZERO, Vector3(0, -1.6, 6.4), r0, r1, 8, c, 0, 4)
			sb.glow_tri(Vector3(-0.8, r0 * 0.8, 1.0), Vector3(0.8, r0 * 0.8, 1.0), Vector3(0, r0 + 2.4, 3.2), Mats.CYAN))
		if i < 8:
			prev = _joint("tail%d" % (i + 1), prev, Vector3(0, -1.6, 6.4))
	var torso: Node3D = _joint("torso", body, Vector3(0, 42, 1))
	_part_g(torso, "torso", _spine, func(sb: SolidBuilder) -> void:
		sb.ellipsoid(Vector3.ZERO, Vector3(13, 19, 11), 8, 12, c, 3, 8)
		for i: int in range(5):
			sb.edge(Vector3(-7, -12.0 + float(i) * 5.0, -10.4), Vector3(7, -12.0 + float(i) * 5.0, -10.4), Mats.PAPER)
		for i: int in range(6):
			var y: float = -10.0 + float(i) * 5.5
			var h: float = 6.0 + sin(float(i) * 0.9) * 3.0 + (3.0 if boss else 0.0)
			sb.glow_tri(Vector3(-1.6, y - 2.5, 9.2), Vector3(1.6, y - 2.5, 9.2), Vector3(0, y + 1.0, 9.2 + h), Mats.CYAN))
	_hit(torso, Vector3.ZERO, 15.0)
	if boss:
		_part(torso, "core_ring", func(sb: SolidBuilder) -> void:
			sb.lines.circle(Vector3(0, 4, -11.2), 6.0, Vector3.RIGHT, Vector3.UP, Mats.GOLD, 16))
		_weak(torso, "core", Vector3(0, 4, -10.6), Vector3(3.4, 3.4, 1.6), Mats.WHITE, 5.0, 0.2)
	for s2: float in [-1.0, 1.0]:
		var side2: String = "L" if s2 < 0.0 else "R"
		var sh: Node3D = _joint("arm" + side2, torso, Vector3(s2 * 12, 10, -3))
		_part(sh, "upperarm", func(sb: SolidBuilder) -> void: sb.tube(Vector3.ZERO, Vector3(0, -11, 0), 3.6, 3.0, 6, c, 0, 3))
		var el: Node3D = _joint("elbow" + side2, sh, Vector3(0, -11, 0))
		el.rotation.x = 0.9
		_part(el, "forearm", func(sb: SolidBuilder) -> void:
			sb.tube(Vector3.ZERO, Vector3(0, -10, 0), 3.0, 2.4, 6, c, 0, 3)
			for tx2: float in [-1.6, 0.0, 1.6]:
				sb.cone(Vector3(tx2, -10, 0), Vector3(tx2 * 1.4, -14, -2.5), 0.7, 4, Mats.WHITE))
		if boss and s2 > 0.0:
			var club: Node3D = _joint("club", el, Vector3(0, -10, 0))
			club.rotation.x = -0.6
			_part(club, "kanabo", func(sb: SolidBuilder) -> void:
				sb.tube(Vector3(0, 2, 0), Vector3(0, -28, 0), 2.2, 4.2, 8, Mats.PAPER, 2, 4)
				for i: int in range(14):
					var a: float = float(i) * 1.7
					var y: float = -6.0 - float(i) * 1.6
					var rr: float = lerpf(2.6, 4.2, float(i) / 14.0)
					sb.cone(Vector3(cos(a) * rr, y, sin(a) * rr), Vector3(cos(a) * (rr + 2.6), y, sin(a) * (rr + 2.6)), 0.7, 4, Mats.WHITE))
	var head: Node3D = _joint("head", torso, Vector3(0, 19, -5))
	_part(head, "head", func(sb: SolidBuilder) -> void:
		sb.ellipsoid(Vector3.ZERO, Vector3(7.5, 6.5, 9), 6, 10, c, 2, 6)
		sb.box(Vector3(0, 1, -10), Vector3(9, 4, 8), c)
		for i: int in range(5):
			sb.cone(Vector3(-3.6 + float(i) * 1.8, -1.0, -13.4), Vector3(-3.6 + float(i) * 1.8, -2.8, -13.4), 0.6, 3, Mats.WHITE)
		for s3: float in [-1.0, 1.0]:
			sb.lines.circle(Vector3(s3 * 4.2, 3, -9.3), 2.0, Vector3.RIGHT, Vector3.UP, Mats.GOLD, 8)
			var hl: float = 16.0 if boss else 10.0
			sb.cone(Vector3(s3 * 4.5, 5, -3), Vector3(s3 * 8.5, 5.0 + hl, 1.5), 1.9, 6, Mats.GOLD)
		if boss:
			for i2: int in range(7):
				var a2: float = float(i2 - 3) * 0.32
				var hh: float = 9.0 + float(3 - absi(i2 - 3)) * 2.5
				sb.cone(Vector3(sin(a2) * 6.0, 6, 1.0 + cos(a2) * 2.0), Vector3(sin(a2) * 9.0, 6.0 + hh, cos(a2) * 3.0 + 1.0), 1.2, 4, Mats.GOLD))
	for s5: float in [-1.0, 1.0]:
		_weak(head, "eye", Vector3(s5 * 4.2, 3, -9.2), Vector3(1.6, 1.3, 0.8), Mats.WHITE, 2.6, 0.12)
	_hit(head, Vector3(0, 0, -2), 8.0)
	var jaw: Node3D = _joint("jaw", head, Vector3(0, -2, -2))
	_part(jaw, "jaw", func(sb: SolidBuilder) -> void:
		sb.box(Vector3(0, -1.25, -6.5), Vector3(8, 2.5, 9), c)
		for i: int in range(5):
			sb.cone(Vector3(-3.4 + float(i) * 1.7, 0.0, -10.6), Vector3(-3.4 + float(i) * 1.7, 1.6, -10.6), 0.55, 3, Mats.WHITE))
	mouth = _joint("mouth", head, Vector3(0, 0, -14))


func _build_kani(c: Color) -> void:
	var body: Node3D = _joint("body", self, Vector3(0, 4, 0))
	var shell: Node3D = _joint("shell", body, Vector3(0, 18, 0))
	_part(shell, "shell", func(sb: SolidBuilder) -> void:
		sb.ellipsoid(Vector3.ZERO, Vector3(28, 9, 20), 6, 16, c, 2, 10)
		for i: int in range(9):
			var a: float = PI * float(i) / 8.0
			sb.cone(Vector3(cos(a) * 18, 6, sin(a) * 8 + 6), Vector3(cos(a) * 21, 12, sin(a) * 9 + 9), 1.3, 4, Mats.WHITE))
	_hit(shell, Vector3.ZERO, 22.0)
	_hit(shell, Vector3(-14, 0, 0), 12.0)
	_hit(shell, Vector3(14, 0, 0), 12.0)
	for s: float in [-1.0, 1.0]:
		for i: int in range(3):
			var hip: Node3D = _joint("leg%d%d" % [int(s), i], body, Vector3(s * 22, 16, -8.0 + float(i) * 9.0))
			hip.rotation.z = s * 1.0
			_part(hip, "upper", func(sb: SolidBuilder) -> void: sb.tube(Vector3.ZERO, Vector3(0, -14, 0), 1.8, 1.3, 6, c, 0, 3))
			var knee: Node3D = _joint("knee%d%d" % [int(s), i], hip, Vector3(0, -14, 0))
			knee.rotation.z = -s * 0.7
			_part(knee, "lower", func(sb: SolidBuilder) -> void:
				sb.tube(Vector3.ZERO, Vector3(0, -16, 0), 1.3, 0.6, 6, c, 0, 3)
				sb.cone(Vector3(0, -16, 0), Vector3(0, -21, 0), 0.6, 4, Mats.WHITE))
		var arm: Node3D = _joint("claw%d" % int(s), body, Vector3(s * 18, 18, -18))
		arm.rotation = Vector3(0.3, -s * 0.4, 0)
		_part(arm, "forearm", func(sb: SolidBuilder) -> void: sb.tube(Vector3.ZERO, Vector3(0, 0, -12), 2.0, 2.8, 6, c, 0, 3))
		var hand: Node3D = _joint("hand%d" % int(s), arm, Vector3(0, 0, -12))
		_part(hand, "hand", func(sb: SolidBuilder) -> void: sb.ellipsoid(Vector3.ZERO, Vector3(5, 4, 6), 4, 8, c, 1, 4))
		_hit(hand, Vector3.ZERO, 6.0)
		var up: Node3D = _joint("pinU%d" % int(s), hand, Vector3(0, 0, -5))
		_part(up, "pinU", func(sb: SolidBuilder) -> void: sb.box(Vector3(0, 0.25, -7), Vector3(3, 2.5, 14), c))
		var lo: Node3D = _joint("pinL%d" % int(s), hand, Vector3(0, 0, -5))
		_part(lo, "pinL", func(sb: SolidBuilder) -> void: sb.box(Vector3(0, -0.25, -6), Vector3(2.4, 2.5, 12), Mats.WHITE))
	var head: Node3D = _joint("head", body, Vector3(0, 20, -20))
	_part(head, "head", func(sb: SolidBuilder) -> void:
		sb.ellipsoid(Vector3.ZERO, Vector3(9, 5, 7), 5, 10, c, 1, 6)
		var lx: float = -7.0
		for i: int in range(1, 11):
			var nx: float = -7.0 + float(i) * 1.4
			sb.cone(Vector3(lx + 0.7, -2.0, -5.6), Vector3(lx + 0.7, -4.0, -5.8), 0.5, 3, Mats.WHITE)
			lx = nx
		sb.plate(PackedVector3Array([Vector3(0, 4.5, 1), Vector3(0, 13, 8), Vector3(0, 5, 9)]), c)
		for s2: float in [-1.0, 1.0]:
			sb.tube(Vector3(s2 * 6, 0, -2), Vector3(s2 * 6, 6, -2), 0.6, 0.5, 4, c))
	for s4: float in [-1.0, 1.0]:
		_weak(head, "eye", Vector3(s4 * 6, 6.6, -2), Vector3(1.4, 1.4, 1.4), Mats.WHITE, 2.6, 0.12)
	mouth = _joint("mouth", head, Vector3(0, 0, -7))


func _build_ryu(c: Color) -> void:
	var body: Node3D = _joint("body", self, Vector3.ZERO)
	var n: int = 15
	for i: int in range(n):
		var f0: float = float(i) / float(n)
		var f1: float = float(i + 1) / float(n)
		var r0: float = 6.5 if i == 0 else lerpf(6.5, 1.8, f0)
		var r1: float = lerpf(6.5, 1.8, f1)
		var seg: Node3D = _joint("seg%d" % i, body, Vector3(0, 0, float(i) * 7.5))
		_part(seg, "seg%d" % i, func(sb: SolidBuilder) -> void:
			sb.tube(Vector3.ZERO, Vector3(0, 0, -8.0), r1, r0, 8, c, 0, 4)
			if i % 2 == 1:
				sb.plate(PackedVector3Array([Vector3(0, r1 * 0.9, -1), Vector3(0, r1 + 4.0, 1.5), Vector3(0, r0 * 0.9, -6)]), Mats.GOLD))
		if i > 0:
			_hit(seg, Vector3(0, 0, -4), maxf(r0, r1) + 1.5)
		_segs.append(seg)
		_seg_len.append(8.0)
	var head: Node3D = _joint("head", body, Vector3(0, 6, -2))
	_part(head, "head", func(sb: SolidBuilder) -> void:
		sb.ellipsoid(Vector3.ZERO, Vector3(6, 5, 8), 5, 10, c, 1, 6)
		sb.box(Vector3(0, -0.75, -11), Vector3(7, 4.5, 10), c)
		for i: int in range(4):
			sb.cone(Vector3(-3.0 + float(i) * 2.0, -3.0, -15.4), Vector3(-2.8 + float(i) * 2.0, -4.8, -15.4), 0.5, 3, Mats.WHITE)
		for s: float in [-1.0, 1.0]:
			sb.tube(Vector3(s * 3, 4, 0), Vector3(s * 6, 12, 4), 0.7, 0.4, 4, Mats.GOLD)
			sb.tube(Vector3(s * 5, 9.5, 2.8), Vector3(s * 9, 12, 2), 0.5, 0.3, 4, Mats.GOLD)
			sb.tube(Vector3(s * 4.2, 7.5, 1.8), Vector3(s * 3, 12, -1), 0.5, 0.3, 4, Mats.GOLD)
			var prev: Vector3 = Vector3(s * 3.5, -1, -15)
			for j: int in range(1, 7):
				var p: Vector3 = Vector3(s * (3.5 + float(j) * 3.0), -1.0 - float(j) * 1.2 + sin(float(j)) * 1.4, -15.0 + float(j) * 2.5)
				sb.edge(prev, p, Mats.WHITE)
				prev = p)
	_part(head, "pearl_ring", func(sb: SolidBuilder) -> void:
		sb.lines.circle(Vector3(0, -6, -9), 3.0, Vector3.RIGHT, Vector3.BACK, Mats.CYAN, 10))
	for s3: float in [-1.0, 1.0]:
		_weak(head, "eye", Vector3(s3 * 3.5, 3, -6.2), Vector3(1.3, 1.1, 0.9), Mats.WHITE, 2.4, 0.12)
	_weak(head, "pearl", Vector3(0, -6, -9), Vector3(2.2, 2.2, 2.2), Color(0.7, 1.0, 1.0), 2.6, 0.15)
	_hit(head, Vector3.ZERO, 7.0)
	mouth = _joint("mouth", head, Vector3(0, -1, -16))


func _build_tengu(c: Color) -> void:
	var body: Node3D = _joint("body", self, Vector3.ZERO)
	_part(body, "body", func(sb: SolidBuilder) -> void:
		sb.ellipsoid(Vector3.ZERO, Vector3(5, 5, 13), 5, 10, c, 2, 6)
		sb.tube(Vector3(0, 0, 12), Vector3(0, -3, 32), 2.0, 0.4, 5, c, 0, 2))
	_hit(body, Vector3.ZERO, 7.0)
	_hit(body, Vector3(0, 0, 9), 5.0)
	for s: float in [-1.0, 1.0]:
		var wing: Node3D = _joint("wing%d" % int(s), body, Vector3(s * 4, 1, -2))
		_part(wing, "wing%d" % int(s), func(sb: SolidBuilder) -> void:
			var tips: Array[Vector3] = [Vector3(s * 34, 2, 6), Vector3(s * 30, 0, 16), Vector3(s * 20, -1, 22)]
			var elbow: Vector3 = Vector3(s * 16, 4, -4)
			sb.plate(PackedVector3Array([Vector3.ZERO, elbow, tips[0], tips[1], tips[2], Vector3(s * 4, 0, 14)]), Mats.SAKURA)
			sb.tube(Vector3.ZERO, elbow, 1.1, 0.8, 4, c)
			for tq: Vector3 in tips:
				sb.tube(elbow, tq, 0.6, 0.25, 4, c))
	var head: Node3D = _joint("head", body, Vector3(0, 2, -14))
	_part(head, "head", func(sb: SolidBuilder) -> void:
		sb.ellipsoid(Vector3.ZERO, Vector3(4, 4, 4.5), 4, 8, c, 1, 4)
		sb.cone(Vector3(0, 0, -3.8), Vector3(0, -1, -15), 1.3, 6, Mats.SHU)
		for i: int in range(6):
			var a: float = PI * float(i) / 6.0
			sb.edge(Vector3(cos(a) * 3, 3.0 + sin(a) * 1.5, 0), Vector3(cos(a) * 7, 4.0 + sin(a) * 4.0, 6), Mats.WHITE))
	for s3: float in [-1.0, 1.0]:
		_weak(head, "eye", Vector3(s3 * 2, 1.4, -3.6), Vector3(1, 0.8, 0.6), Mats.GOLD, 1.6, 0.15)
	_hit(head, Vector3.ZERO, 4.5)
	mouth = _joint("mouth", head, Vector3(0, -1, -15))


## Yamata-no-Orochi: a huge scaled body, five necks with dragon heads, three tails. Each head's
## eyes are weak points; shoot both out and the head is severed.
func _build_orochi(c: Color) -> void:
	var body: Node3D = _joint("body", self, Vector3(0, 14, 0))
	_part_g(body, "body", _spine, func(sb: SolidBuilder) -> void:
		sb.ellipsoid(Vector3.ZERO, Vector3(34, 20, 42), 8, 16, c, 3, 12)
		for i: int in range(9):
			var z: float = -26.0 + float(i) * 7.0
			var h: float = 8.0 + sin(float(i) * 0.8) * 3.0
			sb.glow_tri(Vector3(-2.2, 18.0 - absf(z) * 0.18, z), Vector3(2.2, 18.0 - absf(z) * 0.18, z), Vector3(0, 18.0 + h - absf(z) * 0.18, z + 4.0), Mats.SAKURA)
		for i2: int in range(14):
			var a: float = TAU * float(i2) / 14.0
			sb.edge(Vector3(cos(a) * 30.0, -6, sin(a) * 36.0), Vector3(cos(a) * 24.0, 10, sin(a) * 30.0), Mats.GOLD * 0.8))
	_hit(body, Vector3.ZERO, 30.0)
	for t: int in range(3):
		var prev: Node3D = _joint("otail%d_0" % t, body, Vector3((float(t) - 1.0) * 14.0, -2, 34))
		prev.rotation.y = (float(t) - 1.0) * 0.4
		for i3: int in range(7):
			var r0: float = 7.0 - 0.85 * float(i3)
			var r1: float = 7.0 - 0.85 * float(i3 + 1)
			_part(prev, "otail%d" % i3, func(sb: SolidBuilder) -> void: sb.tube(Vector3.ZERO, Vector3(0, -1.0, 8.0), r0, r1, 8, c, 0, 4))
			if i3 < 6:
				prev = _joint("otail%d_%d" % [t, i3 + 1], prev, Vector3(0, -1.0, 8.0))
	for h: int in range(5):
		var segs: Array = []
		for j: int in range(9):
			var r0n: float = lerpf(6.5, 3.8, float(j) / 9.0)
			var r1n: float = lerpf(6.5, 3.8, float(j + 1) / 9.0)
			var seg: Node3D = _joint("neck%d_%d" % [h, j], self, Vector3.ZERO)
			_part(seg, "neck%d" % j, func(sb: SolidBuilder) -> void:
				sb.tube(Vector3.ZERO, Vector3(0, 0, -6.0), r0n, r1n, 8, c, 0, 4)
				if j % 2 == 0:
					sb.plate(PackedVector3Array([Vector3(0, r0n * 0.9, -0.5), Vector3(0, r0n + 3.0, 1.5), Vector3(0, r1n * 0.9, -5.0)]), Mats.GOLD))
			if j % 2 == 1:
				_hit(seg, Vector3(0, 0, -3), r0n + 1.0)
			segs.append(seg)
		var head: Node3D = _joint("ohead%d" % h, self, Vector3.ZERO)
		_part(head, "ohead", func(sb: SolidBuilder) -> void:
			sb.ellipsoid(Vector3.ZERO, Vector3(9, 7.5, 12), 5, 10, c, 1, 6)
			sb.box(Vector3(0, -1.0, -16), Vector3(10, 6.5, 13), c)
			for i4: int in range(5):
				sb.cone(Vector3(-4.0 + float(i4) * 2.0, -4.3, -21.8), Vector3(-4.0 + float(i4) * 2.0, -7.0, -21.8), 0.7, 3, Mats.WHITE)
			for s: float in [-1.0, 1.0]:
				sb.cone(Vector3(s * 5.0, 5.5, 0), Vector3(s * 9.0, 16.0, 7.0), 1.6, 5, Mats.GOLD)
				var prev2: Vector3 = Vector3(s * 5.0, -2, -21)
				for k: int in range(1, 7):
					var p: Vector3 = Vector3(s * (5.0 + float(k) * 3.6), -2.0 - float(k) * 1.4 + sin(float(k)) * 1.8, -21.0 + float(k) * 3.0)
					sb.edge(prev2, p, Mats.WHITE)
					prev2 = p)
		var eye_idx: Array[int] = []
		for s2: float in [-1.0, 1.0]:
			eye_idx.append(spheres.size())
			_weak(head, "eye", Vector3(s2 * 5.0, 3.5, -9.0), Vector3(1.8, 1.4, 1.0), Color(1.0, 0.85, 0.3), 3.4, 0.05)
		_hit(head, Vector3(0, 0, -6), 10.0)
		var m: Node3D = Node3D.new()
		m.position = Vector3(0, -2, -23)
		head.add_child(m)
		_heads.append({"segs": segs, "head": head, "mouth": m, "eyes": eye_idx, "alive": true})
	mouth = _heads[2]["mouth"]


func _pose_orochi(ph: float) -> void:
	var body: Node3D = _j["body"]
	body.position.y = 14.0 + sin(ph * 2.0) * 1.2
	body.rotation.x = -stagger * 0.15
	for t: int in range(3):
		for i: int in range(7):
			var n: Node3D = _j["otail%d_%d" % [t, i]]
			n.rotation.y = (float(t) - 1.0) * 0.4 * float(i == 0) + sin(Game.t * 0.8 + float(i) * 0.5 + float(t)) * 0.15
	var breathing: bool = breath_t > 0.0
	for h: int in range(_heads.size()):
		var hd: Dictionary = _heads[h]
		var segs: Array = hd["segs"]
		var alive: bool = hd["alive"]
		var base: Vector3 = Vector3((float(h) - 2.0) * 11.0, 30.0 + sin(ph * 2.0) * 1.2, -24.0)
		var pts: Array[Vector3] = []
		for j: int in range(segs.size() + 1):
			var fj: float = float(j)
			var lift: float = 5.2 if alive else 3.0
			var p: Vector3 = base + Vector3(
				sin(Game.t * 0.8 + float(h) * 1.7 + fj * 0.35) * fj * 1.1 + (float(h) - 2.0) * fj * 1.3,
				fj * lift + sin(Game.t * 0.6 + float(h)) * fj * 0.25,
				-fj * 3.4)
			if breathing and h == _breath_head:
				p.z -= fj * 1.2
				p.y -= fj * 0.8
			pts.append(p)
		for j2: int in range(segs.size()):
			var seg: Node3D = segs[j2]
			var d: Vector3 = pts[j2 + 1] - pts[j2]
			var len: float = maxf(0.5, d.length())
			seg.position = pts[j2]
			seg.basis = Basis.looking_at(d / len, Vector3.UP).scaled(Vector3(1, 1, len / 6.0))
		var head: Node3D = hd["head"]
		var tip: Vector3 = pts[pts.size() - 1]
		head.position = tip
		var pitch: float = -0.35 + sin(Game.t * 1.1 + float(h)) * 0.15 + recoil * 1.0 - (0.35 if (breathing and h == _breath_head) else 0.0)
		head.rotation = Vector3(pitch, (float(h) - 2.0) * 0.18 + sin(Game.t * 0.7 + float(h) * 2.0) * 0.25, 0)


# ------------------------------------------------------------------ posing --

func pose(dt: float) -> void:
	var ph: float = phase
	match type:
		"oni", "daioni":
			var sw: float = sin(ph)
			_j["body"].position.y = absf(cos(ph)) * 1.5
			for s: float in [-1.0, 1.0]:
				var side: String = "L" if s < 0.0 else "R"
				var a: float = sw * 0.45 * s
				_j["hip" + side].rotation.x = a
				_j["knee" + side].rotation.x = -(maxf(0.0, a) * 1.1 + 0.1)
				_j["ankle" + side].rotation.x = maxf(0.0, a) * 0.6
				_j["arm" + side].rotation = Vector3(sw * 0.5 * s + 0.5, 0, s * 0.25)
			for i: int in range(9):
				_j["tail%d" % i].rotation = Vector3(0.04, sin(ph * 0.5 + float(i) * 0.45) * 0.13, 0)
			_j["torso"].rotation.x = -0.28 + stagger * 0.4
			_j["body"].position.x = sin(Game.t * 37.0) * stagger * 1.2
			var breathing: bool = breath_t > 0.0
			_j["head"].rotation.x = 0.28 + sin(ph * 0.5) * 0.08 + (0.25 if breathing else 0.0) + recoil * 1.4
			_j["head"].rotation.z = sin(Game.t * 31.0) * recoil * 0.5
			var jaw: float = 0.5 if (breathing or roar_t > 0.0) else 0.1 + absf(sin(Game.t * 1.3)) * 0.1
			_j["jaw"].rotation.x = -jaw
			_spine.set_shader_parameter("tint", Vector3(3, 3, 3) if breathing else Vector3(1, 1, 1))
			_spine.set_shader_parameter("pulse", 0.8 if breathing else 0.0)
			_spine.set_shader_parameter("pulse_speed", 40.0)
		"kani":
			_j["body"].position.y = 4.0 + absf(sin(ph * 2.0)) * 1.2
			_j["body"].rotation.x = -stagger * 0.3
			_j["body"].rotation.z = sin(Game.t * 33.0) * stagger * 0.08
			_j["head"].rotation.x = recoil * 1.0
			for s2: float in [-1.0, 1.0]:
				for i2: int in range(3):
					_j["leg%d%d" % [int(s2), i2]].rotation.y = sin(ph * 2.0 + float(i2) * 2.1 + (PI if s2 > 0.0 else 0.0)) * 0.35
				var op: float = 0.25 + absf(sin(Game.t * 2.0 + s2)) * 0.35
				_j["pinU%d" % int(s2)].rotation.x = op
				_j["pinL%d" % int(s2)].rotation.x = -op
		"ryu":
			var pts: Array[Vector3] = []
			var n: int = _segs.size()
			var hp_: Vector3
			if state == "coil":
				# Wrapped round the fort in a rising helix, head reared over the top.
				for i6: int in range(n):
					var a6: float = ph * 1.2 + float(i6) * 0.55
					pts.append(Vector3(cos(a6) * 16.0, 2.0 + float(n - i6) * 1.8, sin(a6) * 16.0))
				var ah: float = ph * 1.2 - 0.6
				hp_ = Vector3(cos(ah) * 13.0, 2.0 + float(n + 1) * 1.8 + 5.0, sin(ah) * 13.0)
			else:
				for i3: int in range(n):
					var f: float = float(i3) / float(n)
					var ox: float = sin(ph - float(i3) * 0.55) * 8.0 * (0.4 + f)
					var oy: float = sin(ph * 1.2 - float(i3) * 0.7) * 6.0 + 4.0
					if rear > 0.0:
						oy += maxf(0.0, 6.0 - float(i3)) * rear * 6.5
					pts.append(Vector3(ox, oy, float(i3) * 7.5))
				var hy: float = 6.0 + sin(ph * 1.2) * 6.0 - 2.0 + rear * 39.0
				hp_ = Vector3(sin(ph) * 3.0, hy, -2)
			for i4: int in range(n):
				var seg: Node3D = _segs[i4]
				var p: Vector3 = pts[i4]
				var toward: Vector3 = hp_ if i4 == 0 else pts[i4 - 1]
				var d: Vector3 = toward - p
				var len: float = maxf(0.5, d.length())
				seg.position = p
				seg.basis = Basis.looking_at(d / len, Vector3.UP).scaled(Vector3(1, 1, len / 8.0))
			_j["head"].position = hp_
			_j["head"].rotation.x = 0.15 + rear * 0.3 + recoil * 1.2
			_j["head"].rotation.z = sin(Game.t * 29.0) * (recoil + stagger * 0.4) * 0.5
		"orochi":
			_pose_orochi(ph)
		"tengu":
			var fl: float = sin(ph * 3.0)
			for s5: float in [-1.0, 1.0]:
				_j["wing%d" % int(s5)].rotation.z = s5 * fl * 0.65
			_j["head"].rotation.x = recoil * 1.0
	# Root: heading, sinking and toppling when dying.
	var rot: Vector3 = Vector3(0, yaw, 0)
	if type == "tengu":
		rot.z = bank + sin(Game.t * 30.0) * stagger * 0.5
	if dying:
		if def["air"]:
			rot.z += die_t * 3.0
			rot.x = -die_t * 0.6
		elif die_t < 0.9:
			rot.z = sin(die_t * 22.0) * 0.08
		else:
			var f: float = smoothstep(0.9, 2.6, die_t)
			rot.z = f * 1.35 * fall_dir
			rot.x = -f * 0.2
	rotation = rot
	var rage: Vector3 = Vector3(1.5, 0.75, 0.75) if enraged and not dying else Vector3.ONE
	_line.set_shader_parameter("tint", rage)
	var flash: float = clampf(flash_t * 12.0, 0.0, 1.0)
	_fill.set_shader_parameter("flash", flash)
	_line.set_shader_parameter("flash", flash)
	flash_t = maxf(0.0, flash_t - dt)


## World-space hit spheres, aim point and whether any of the kaiju is above the waves.
func refresh_hits() -> void:
	hits.clear()
	var best: Dictionary = {}
	var top: Dictionary = {}
	var s0: float = scale.x
	for i: int in range(spheres.size()):
		var s: Dictionary = spheres[i]
		var node: Node3D = s["node"]
		if not node.is_visible_in_tree():
			continue
		var p: Vector3 = node.global_transform * (s["off"] as Vector3)
		var h: Dictionary = {"p": p, "r": float(s["r"]) * s0, "weak": s["weak"], "idx": i}
		hits.append(h)
		if not h["weak"] and p.y + float(h["r"]) > 0.0 and (best.is_empty() or float(h["r"]) > float(best["r"])):
			best = h
		if top.is_empty() or p.y > (top["p"] as Vector3).y:
			top = h
	if best.is_empty():
		best = top
	if best.is_empty():
		aim = global_position + Vector3(0, 10, 0)
		exposed = false
	else:
		aim = best["p"]
		exposed = aim.y + float(best["r"]) * 0.5 > 0.0


## Damage to weak point `idx`. Returns true if this hit destroyed it.
func weak_hit(idx: int, dmg: float) -> bool:
	recoil = 0.35
	if idx < 0 or idx >= spheres.size():
		return false
	var s: Dictionary = spheres[idx]
	if not s["weak"]:
		return false
	s["whp"] = float(s["whp"]) - dmg
	if float(s["whp"]) > 0.0:
		return false
	s["weak"] = false
	var node: Node3D = s["eye"]
	var p: Vector3 = node.global_position
	node.visible = false
	wounds.append({"local": to_local(p), "dir": ((p - global_position).normalized() + Vector3(0, 0.8, 0)).normalized(), "t": 0.0})
	enraged = true
	stagger = 1.0
	for h: int in range(_heads.size()):
		var hd: Dictionary = _heads[h]
		if not hd["alive"]:
			continue
		var all_out: bool = true
		for e: int in hd["eyes"]:
			if spheres[e]["weak"]:
				all_out = false
		if all_out:
			_sever(h)
	return true


## Orochi: a head with both eyes shot out is severed, leaving a spurting stump.
func _sever(h: int) -> void:
	var hd: Dictionary = _heads[h]
	hd["alive"] = false
	var segs: Array = hd["segs"]
	var stump: Node3D = segs[5]
	var p: Vector3 = stump.global_position
	(hd["head"] as Node3D).visible = false
	for j: int in range(6, segs.size()):
		(segs[j] as Node3D).visible = false
	wounds.append({"local": to_local(p), "dir": Vector3.UP, "t": 0.0})
	wounds.append({"local": to_local(p), "dir": Vector3(0, 0.6, -0.8).normalized(), "t": 0.1})
	hp -= max_hp * 0.08
	Game.fx.spray(p, Vector3.UP, 120, 110.0, 12)
	Game.fx.boom(p, 2.5, Mats.BLOOD)
	Game.fx.text(p + Vector3(0, 20, 0), "首落とし! HEAD SEVERED", Mats.SHU, 22.0, 2.2, 8.0)
	Game.sfx.play_at("roar_boss", p, 1.3)
	Game.fx.shake_at(p, 3.0)
	Game.say("sever")
	var alive: int = 0
	for o: Dictionary in _heads:
		if o["alive"]:
			alive += 1
	if alive == 0 and not dying:
		hp = 0.0
		Game.combat.kill_kaiju(self, Vector3.UP)


func weak_kind(idx: int) -> String:
	return String(spheres[idx]["kind"]) if idx >= 0 and idx < spheres.size() else ""


func add_stagger(dmg: float) -> void:
	stagger = minf(1.0, stagger + dmg / (max_hp * 0.09))


func mouth_pos() -> Vector3:
	if not _heads.is_empty():
		var hd: Dictionary = _heads[_breath_head]
		if hd["alive"]:
			return (hd["mouth"] as Node3D).global_position
	return mouth.global_position if mouth != null else aim


# ------------------------------------------------------------------ AI --

func update(dt: float) -> void:
	roar_t -= dt
	stagger = maxf(0.0, stagger - dt * 0.9)
	recoil = maxf(0.0, recoil - dt * 2.0)
	if slow > 0.0:
		slow -= dt
	for w: Dictionary in wounds:
		w["t"] = float(w["t"]) - dt
		if float(w["t"]) <= 0.0:
			w["t"] = randf_range(0.05, 0.15) if dying else randf_range(0.3, 1.0) * (0.4 + hp / max_hp)
			var wp: Vector3 = to_global(w["local"])
			Game.fx.spray(wp, w["dir"], 6 if dying else 4, 45.0 if dying else 30.0, 0)
	if dying:
		_update_dying(dt)
		return
	var spd: float = float(def["spd"]) * (0.55 if slow > 0.0 else 1.0) * (1.0 - 0.65 * stagger) * (1.25 if enraged else 1.0)
	if def["air"]:
		_update_tengu(dt, spd)
		return
	var on_land: bool = position.z > Game.coast_z(position.x)
	if knock > 0.0:
		var push: float = minf(knock, dt * 90.0)
		position.z -= push
		knock -= push
		if state == "rampage":
			state = "advance"
	if burrowing:
		_update_burrow(dt, spd)
		return
	if state == "coil":
		_update_coil(dt)
		return
	if state == "advance":
		_try_specials()
		var stop_z: float = Game.coast_z(target_x) + Game.STOP + (14.0 if def["boss"] else 0.0)
		var dx: float = target_x - position.x
		var dz: float = stop_z - position.z
		var dist: float = Vector2(dx, dz).length()
		if dist < 4.0:
			state = "rampage"
			roar_t = 2.0
			Game.sfx.play_at("roar_boss" if def["boss"] else "roar", position, 1.0)
			if not Game.demo:
				Game.fx.text(position + Vector3(0, 90.0 * float(def["scale"]), 0), "上陸!", Mats.SHU, 22.0, 2.0)
				Game.say("land")
		else:
			dx /= dist
			dz /= dist
			var wob: float = sin(Game.t * 0.25 + float(uid) * 1.7) * 0.25
			var wx: float = dx + dz * wob
			var wz: float = dz - dx * wob
			vel = Vector3(wx, 0, wz) * spd
			position.x += vel.x * dt
			position.z += vel.z * dt
			yaw = lerp_angle(yaw, Game.yaw_to(wx, wz), minf(1.0, dt * 2.0))
			var stride: float = 0.15 if type == "kani" else (0.1 if type == "ryu" else 0.12)
			phase += dt * spd * stride / float(def["scale"])
	else:
		vel = Vector3.ZERO
		phase += dt * (1.2 if type == "ryu" else 1.6)
		yaw = lerp_angle(yaw, sin(Game.t * 0.4 + float(uid)) * 0.5, dt)
		if not Game.demo:
			Game.city -= float(def["city"]) * dt * Game.city_mult()
			Game.hurt = minf(1.0, Game.hurt + dt * 0.8)
		smash_cd -= dt
		if smash_cd <= 0.0:
			smash_cd = randf_range(1.0, 2.2)
			if not Game.demo and Game.world.smash_near(position, 120.0 * float(def["scale"])):
				Game.sfx.play_at("crash", position, 1.0)
			if randf() < 0.3:
				Game.fx.text(position + Vector3(randf_range(-20, 20), 60.0 * float(def["scale"]), 10), ["ズシン!", "ドシン!", "ガシャーン!"].pick_random(), Mats.GOLD, 14.0, 1.2)
	# Wading deeper out at sea, standing on the beach.
	if type == "orochi":
		position.y = lerpf(position.y, 2.0 if on_land else -Game.depth_at(position.z) * 0.6, minf(1.0, dt * 2.0))
	elif type == "ryu":
		position.y = lerpf(position.y, 1.0 if on_land else -5.0, dt)
		rear = minf(1.0, rear + dt * 0.7) if state == "rampage" else 0.0
	else:
		position.y = lerpf(position.y, 2.0 if on_land else -Game.depth_at(position.z), minf(1.0, dt * 2.0))
	_footsteps(on_land)
	# Trample guns underfoot.
	var reach: float = (30.0 if type == "kani" else (14.0 if type == "ryu" else 18.0)) * float(def["scale"])
	for t: Turret in Game.turrets.duplicate():
		if Vector2(t.pad.pos.x - position.x, t.pad.pos.z - position.z).length() < reach:
			Game.combat.hurt_turret(t, (90.0 if def["boss"] else 45.0) * dt)
	if def["breath"]:
		_update_breath(dt)


func _footsteps(on_land: bool) -> void:
	var sc: float = float(def["scale"])
	if type == "oni" or type == "daioni":
		var st: float = signf(sin(phase))
		if st != last_step:
			last_step = st
			var right: Vector3 = Vector3(cos(-yaw), 0, sin(-yaw))
			var fp: Vector3 = position + right * 9.0 * st * sc
			if not on_land and position.z > -700.0:
				Game.fx.ring(Vector3(fp.x, 0.6, fp.z), 4.0 * sc, 22.0, 1.5, Mats.CYAN)
				Game.fx.sparks(Vector3(fp.x, 1, fp.z), 8, Mats.CYAN, 40.0, 60.0)
			if position.z > -600.0:
				Game.sfx.play_at("stomp", fp, sc)
				Game.fx.shake_at(fp, 0.5 * sc)
	elif (type == "kani" or type == "orochi") and not on_land and randf() < 0.1:
		Game.fx.ring(position + Vector3(randf_range(-20, 20), 0.6, randf_range(-10, 10)), 3.0, 18.0, 1.2, Mats.CYAN)
	elif type == "ryu" and not on_land and randf() < 0.2:
		var b: float = randf_range(0, 100)
		var back: Vector3 = global_transform.basis.z.normalized() * b
		Game.fx.ring(Vector3(position.x + back.x, 0.6, position.z + back.z), 2.0, 14.0, 1.2, Mats.CYAN)


func _update_breath(dt: float) -> void:
	var boss: bool = def["boss"]
	if breath_t > 0.0:
		breath_t -= dt
		var tgt: Variant = breath_target
		var alive: bool = false
		var at_zep: bool = typeof(tgt) == TYPE_STRING
		if at_zep:
			alive = not Game.zep.down
		elif typeof(tgt) == TYPE_OBJECT and is_instance_valid(tgt) and Game.turrets.has(tgt):
			alive = (tgt as Turret).hp > 0.0
		if breath_t < 0.8 and alive:
			if not fired:
				fired = true
				Game.sfx.play_at("beam", mouth_pos(), 1.0)
			var tp: Vector3 = Game.zep.global_position + Vector3(0, -10, 0) if at_zep else (tgt as Turret).pad.pos + Vector3(0, 6, 0)
			var j: Vector3 = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
			Game.fx.beam(mouth_pos(), tp + j, Mats.SHU if boss else Mats.CYAN, 5.0 if boss else 3.0, 0.06)
			Game.fx.sparks(tp, 3, Mats.WHITE, 50.0, 20.0)
			var dps: float = (110.0 if boss else 60.0) * (1.0 + 0.04 * float(Game.wave))
			if at_zep:
				Game.combat.hurt_zep(dps * dt * 0.35)
			else:
				Game.combat.hurt_turret(tgt, dps * dt)
			Game.fx.shake_at(tp, dt * 6.0)
		if breath_t <= 0.0:
			breath_target = null
		return
	breath_cd -= dt
	if breath_cd > 0.0 or not exposed or position.z < -480.0:
		return
	var best: Variant = null
	var bd: float = 300.0 * float(def["scale"])
	for t: Turret in Game.turrets:
		var d: float = Vector2(t.pad.pos.x - position.x, t.pad.pos.z - position.z).length()
		if d < bd:
			bd = d
			best = t
	if best == null and not Game.zep.down and Vector2(Game.zep.position.x - position.x, Game.zep.position.z - position.z).length() < 260.0:
		best = "zep"
	if best == null:
		breath_cd = 2.0
		return
	breath_target = best
	breath_t = 1.9
	fired = false
	roar_t = 1.9
	breath_cd = randf_range(9, 13) * (0.6 if boss else 1.0) * (0.45 if type == "orochi" else 1.0)
	if not _heads.is_empty():
		var alive: Array[int] = []
		for h: int in range(_heads.size()):
			if _heads[h]["alive"]:
				alive.append(h)
		if alive.is_empty():
			breath_t = 0.0
			return
		_breath_head = alive.pick_random()
	Game.sfx.play_at("roar_boss" if boss else "roar", position, 0.8)


func _update_tengu(dt: float, spd: float) -> void:
	orb += dt * 0.8
	var target: Vector3
	var zep: Zeppelin = Game.zep
	var seat: Turret = Game.player.seat if (Game.player.active and Game.player.seat is Turret) else null
	if dive and (seat == null or not Game.turrets.has(seat)):
		dive = false
	if not dive and seat != null and randf() < dt * 0.06 and position.distance_to(seat.pad.pos) < 650.0:
		dive = true
		Game.fx.text(position + Vector3(0, 12, 0), "急降下!", Mats.SAKURA, 14.0, 1.4)
		Game.banner.emit("", "上空注意!  A TENGU IS DIVING AT YOU", 2.0)
	if dive:
		target = seat.pad.pos + Vector3(0, 12, 0)
		spd *= 2.4
	elif not zep.down:
		target = zep.position + Vector3(cos(orb) * 60.0, 10.0 + sin(orb * 1.3) * 18.0, sin(orb) * 60.0)
	else:
		target = Vector3(target_x + cos(orb) * 50.0, 55.0 + sin(orb * 1.7) * 10.0, 110.0 + sin(orb) * 40.0)
	var d: Vector3 = target - position
	var dist: float = maxf(0.01, d.length())
	var s: float = minf(spd, dist * 2.0) if not dive else spd
	vel = vel.lerp(d / dist * s, minf(1.0, dt * (5.0 if dive else 2.0)))
	position += vel * dt
	var ny: float = Game.yaw_to(vel.x, vel.z)
	var dyaw: float = wrapf(ny - yaw, -PI, PI)
	yaw += dyaw * minf(1.0, dt * 3.0)
	bank = lerpf(bank, clampf(dyaw * 2.0, -0.8, 0.8), minf(1.0, dt * 3.0))
	phase += dt * (5.0 if dive else 3.2)
	atk -= dt
	if dive and dist < 14.0:
		dive = false
		Game.combat.hurt_turret(seat, 55.0)
		Game.fx.boom(seat.pad.pos + Vector3(0, 10, 0), 1.6, Mats.SAKURA)
		Game.fx.text(seat.pad.pos + Vector3(0, 22, 0), "ドガッ!", Mats.SAKURA, 12.0, 1.0)
		Game.sfx.play_at("boom", seat.pad.pos, 1.2)
		Game.shake = maxf(Game.shake, 2.5)
		Game.flash = maxf(Game.flash, 0.25)
		vel = Vector3(randf_range(-30, 30), 60, randf_range(-30, 30))
		atk = 2.0
	elif not dive and not zep.down and position.distance_to(zep.position) < 110.0 and atk <= 0.0:
		atk = randf_range(1.0, 1.6)
		Game.fx.beam(mouth_pos(), zep.position + Vector3(randf_range(-20, 20), randf_range(-10, 10), randf_range(-30, 30)), Mats.RYU, 1.4, 0.25)
		Game.combat.hurt_zep(6.0 * (1.0 + 0.05 * float(Game.wave)))
	elif zep.down and not dive and dist < 60.0:
		if not Game.demo:
			Game.city -= float(def["city"]) * dt * Game.city_mult()
			Game.hurt = minf(1.0, Game.hurt + dt * 0.5)
		if atk <= 0.0:
			atk = 1.2
			Game.fx.boom(Vector3(position.x + randf_range(-10, 10), 4, 100.0 + randf_range(-30, 30)), 1.0, Mats.RYU)


## Kanizame: dive under the bay towards a sea fort, then burst up beneath it.
func _try_specials() -> void:
	if type == "kani" and not burrow_done and position.z < -40.0:
		for t: Turret in Game.turrets:
			if t.pad.fort and t.pad.pos.z > position.z and Vector2(t.pad.pos.x - position.x, t.pad.pos.z - position.z).length() < 240.0:
				burrow_target = t
				burrow_done = true
				burrowing = true
				Game.fx.text(position + Vector3(0, 30, 0), "潜行! BURROWING", Mats.KANI, 14.0, 1.6)
				Game.fx.ring(Vector3(position.x, 0.6, position.z), 10.0, 40.0, 2.0, Mats.CYAN)
				return
	if type == "ryu" and not coil_done:
		for t2: Turret in Game.turrets:
			if t2.pad.fort and Vector2(t2.pad.pos.x - position.x, t2.pad.pos.z - position.z).length() < 70.0:
				coil_target = t2
				coil_done = true
				state = "coil"
				coil_t = 6.0
				Game.fx.text(t2.pad.pos + Vector3(0, 40, 0), "締め付け! CONSTRICT", Mats.RYU, 14.0, 1.8)
				Game.sfx.play_at("roar", position, 1.0)
				return


func _update_burrow(dt: float, spd: float) -> void:
	var t: Turret = burrow_target
	if t == null or not is_instance_valid(t) or not Game.turrets.has(t):
		burrowing = false
		return
	position.y = lerpf(position.y, -50.0, minf(1.0, dt * 1.5))
	var d: Vector2 = Vector2(t.pad.pos.x - position.x, t.pad.pos.z - position.z)
	phase += dt * 3.0
	if randf() < dt * 6.0:
		Game.fx.ring(Vector3(position.x + randf_range(-10, 10), 0.6, position.z + randf_range(-10, 10)), 2.0, 12.0, 1.0, Mats.CYAN)
	if d.length() < 6.0 and position.y < -30.0:
		burrowing = false
		position.y = -Game.depth_at(position.z)
		Game.fx.boom(t.pad.pos, 3.0, Mats.CYAN)
		Game.fx.ring(Vector3(t.pad.pos.x, 0.6, t.pad.pos.z), 14.0, 60.0, 2.0, Mats.CYAN)
		Game.fx.sparks(t.pad.pos, 60, Mats.CYAN, 90.0, 50.0)
		Game.fx.text(t.pad.pos + Vector3(0, 30, 0), "奇襲! AMBUSH", Mats.KANI, 18.0, 1.8)
		Game.sfx.play_at("boom_big", t.pad.pos, 1.2)
		Game.combat.hurt_turret(t, 170.0)
		stagger = 0.6
		return
	var dir: Vector2 = d.normalized()
	position.x += dir.x * spd * 1.5 * dt
	position.z += dir.y * spd * 1.5 * dt
	yaw = lerp_angle(yaw, Game.yaw_to(dir.x, dir.y), minf(1.0, dt * 3.0))


## Ryujin: coil round a sea fort and crush the gun on it.
func _update_coil(dt: float) -> void:
	var t: Turret = coil_target
	coil_t -= dt
	if t == null or not is_instance_valid(t) or not Game.turrets.has(t) or coil_t <= 0.0:
		state = "advance"
		return
	position.x = lerpf(position.x, t.pad.pos.x, minf(1.0, dt * 2.0))
	position.z = lerpf(position.z, t.pad.pos.z, minf(1.0, dt * 2.0))
	position.y = lerpf(position.y, -4.0, minf(1.0, dt * 2.0))
	phase += dt * 2.0
	Game.combat.hurt_turret(t, 35.0 * dt)
	if randf() < dt * 4.0:
		Game.fx.sparks(t.pad.pos + Vector3(0, 8, 0), 3, Mats.FIRE, 30.0)


func _update_dying(dt: float) -> void:
	die_t += dt
	if def["air"]:
		# Spiral down trailing fire and blood, then burst on the water.
		position += Vector3(vel.x * 0.5, -(20.0 + die_t * 50.0), vel.z * 0.5) * dt
		Game.fx.sparks(position, 2, Mats.FIRE, 20.0, -10.0)
		if randf() < 0.5:
			Game.fx.smoke(position, Vector3(randf_range(-3, 3), 6, randf_range(-3, 3)), 3.0, 2.0)
		if position.y < 0.0 and not splashed:
			splashed = true
			Game.fx.boom(Vector3(position.x, 1, position.z), 2.5, Mats.FIRE)
			Game.fx.ring(Vector3(position.x, 0.6, position.z), 6.0, 40.0, 2.0, Mats.CYAN)
			Game.fx.spray(Vector3(position.x, 1, position.z), Vector3.UP, 40, 60.0, 5)
			Game.fx.stain(Vector3(position.x, 0.4, position.z), 10.0)
		if position.y < -20.0:
			dead = true
		return
	# Thrash and bleed, topple, chain explosions, slam into the sea or the street, then sink.
	var sc: float = float(def["scale"])
	if die_t < 0.9 and randf() < 0.5:
		Game.fx.spray(aim + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)) * sc, Vector3.UP, 6, 60.0, 0)
	var steps: Array[float] = [1.4, 1.9, 2.3, 2.6]
	while _death_step < steps.size() and die_t >= steps[_death_step]:
		var step: int = _death_step
		_death_step += 1
		if step == 2:
			var onland: bool = position.z > Game.coast_z(position.x)
			var side: Vector3 = global_transform.basis.x.normalized() * fall_dir * -40.0 * sc
			var hit: Vector3 = Vector3(position.x + side.x, 1.0, position.z + side.z)
			if not onland:
				Game.fx.ring(hit, 15.0 * sc, 70.0, 2.8, Mats.CYAN)
				Game.fx.ring(hit, 8.0 * sc, 40.0, 3.2, Mats.WHITE)
				Game.fx.stain(Vector3(hit.x, 0.4, hit.z), 30.0 * sc)
				Game.fx.sparks(hit, 80, Mats.CYAN, 110.0, 50.0)
			else:
				Game.fx.sparks(hit, 50, Mats.GOLD, 70.0, 50.0)
				for i: int in range(6):
					Game.fx.smoke(hit + Vector3(randf_range(-20, 20), 2, randf_range(-20, 20)), Vector3(0, randf_range(5, 12), 0), randf_range(8, 16), 3.5)
			Game.fx.spray(hit + Vector3(0, 6, 0), Vector3.UP, 50, 80.0, 6)
			Game.sfx.play_at("stomp", hit, 1.6)
			Game.sfx.play_at("boom_big", hit, 0.8)
			Game.fx.shake_at(hit, 4.0 * sc)
		elif not hits.is_empty():
			var h: Dictionary = hits.pick_random()
			Game.fx.boom(h["p"], 2.0 * sc, Mats.FIRE)
			Game.fx.spray(h["p"], Vector3.UP, 30, 70.0, 3)
			Game.sfx.play_at("boom", h["p"], 0.9)
	if die_t > 2.6:
		position.y -= dt * (die_t - 2.6) * 12.0
	else:
		position.y -= dt * 1.5
	if die_t > 4.8:
		dead = true
