class_name Camp
extends Node3D
## The old wartime camp on the holm, empty since 1945: a compound fenced with barbed
## wire on cranked posts, a guard tower with a searchlight at each corner, two Nissen
## huts (living quarters, and the mess where the research is done), the generator
## house, vegetable beds and a greenhouse, and the gate facing the rope bridge.
## For now it is the place itself; the towers' lights, the beds and the huts' work come
## next (docs/DECISIONS.md, "The holm and the camp").

const FENCE_H := 2.3
const POST_EVERY := 2.6
const WIRES := 6
const GATE_W := 2.6
const TOWER_LEG := 1.05
const TOWER_DECK := 4.0
const HUT_R := 2.3
const HUT_LEN := 7.5
const WIRE := Color(0.32, 0.3, 0.28)
const TIN := Color(0.27, 0.31, 0.27)
const BRICK := Color(0.42, 0.24, 0.18)

## Every searchlight's head, for the next step to aim and light.
var searchlights: Array[Node3D] = []
var towers: Array[Node3D] = []
var huts: Array[Node3D] = []
var greenhouse: Node3D
var beds: Array[Node3D] = []

var _wood: StandardMaterial3D
var _post: StandardMaterial3D
var _wire: StandardMaterial3D
var _tin: StandardMaterial3D

func _ready() -> void:
	name = "Camp"
	_wood = Look.wood(Color(0.38, 0.3, 0.22), 0.8)
	_post = Look.wood(Color(0.3, 0.25, 0.2), 0.6)
	_wire = Look.flat_mat(WIRE, 0.6)
	_wire.metallic = 0.6
	_tin = Look.flat_mat(TIN, 0.55)
	_tin.metallic = 0.5
	var c := Terrain.CAMP_C
	var h := Terrain.CAMP_HALF
	var corners := [Vector2(c.x - h.x, c.y - h.y), Vector2(c.x + h.x, c.y - h.y), Vector2(c.x + h.x, c.y + h.y), Vector2(c.x - h.x, c.y + h.y)]
	for i in 4:
		_fence_side(corners[i], corners[(i + 1) % 4], i == 3)
	for p in corners:
		_tower(p)
	_hut(Vector2(c.x - 4.6, c.y - 5.0), "Quarters")
	_hut(Vector2(c.x + 4.4, c.y - 5.0), "Mess")
	_generator_house(Vector2(c.x + 8.6, c.y + 0.6))
	for i in 3:
		_bed(Vector2(c.x - 5.0, c.y + 2.6 + float(i) * 2.0))
	_greenhouse(Vector2(c.x + 4.6, c.y + 4.9))
	_gate()

func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)

# ---- the wire ----

# One side of the compound: cranked posts (the tops lean out), six strands of wire
# between them, and a solid body keepers can't pass. The west side leaves the gate.
func _fence_side(from: Vector2, to: Vector2, gate: bool) -> void:
	var d := to - from
	var length := d.length()
	var dir := d / length
	var out := Vector2(dir.y, -dir.x)    # away from the compound's centre
	if out.dot(from - Terrain.CAMP_C) < 0.0:
		out = -out
	var n := int(ceil(length / POST_EVERY))
	var gate_mid := length * 0.5
	var spans: Array = [[0.0, length]]
	if gate:
		spans = [[0.0, gate_mid - GATE_W * 0.5], [gate_mid + GATE_W * 0.5, length]]
	for i in n + 1:
		var s := length * float(i) / float(n)
		if gate and absf(s - gate_mid) < GATE_W * 0.5:
			continue
		_fence_post(from + dir * s, out)
	if gate:
		for sgn in [-1.0, 1.0]:
			_fence_post(from + dir * (gate_mid + sgn * GATE_W * 0.5), out)
	for span in spans:
		var a: Vector2 = from + dir * float(span[0])
		var b: Vector2 = from + dir * float(span[1])
		for w in WIRES:
			var y := 0.25 + float(w) * (FENCE_H - 0.4) / float(WIRES - 1)
			var pa := _ground(a) + Vector3(0.0, y, 0.0)
			var pb := _ground(b) + Vector3(0.0, y, 0.0)
			_strand(pa, pb)
		# The cranked tops carry two more strands, out over the ditch.
		for w in 2:
			var lean := Vector3(out.x, 0.0, out.y) * (0.22 + 0.2 * float(w))
			var y := FENCE_H + 0.15 + 0.2 * float(w)
			_strand(_ground(a) + Vector3(0.0, y, 0.0) + lean, _ground(b) + Vector3(0.0, y, 0.0) + lean)
		var body := StaticBody3D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		add_child(body)
		var mid := (a + b) * 0.5
		var cs := Geo.box_shape(body, Vector3((b - a).length(), FENCE_H, 0.2), _ground(mid) + Vector3(0.0, FENCE_H * 0.5, 0.0))
		cs.rotation.y = -atan2(dir.y, dir.x)

func _fence_post(p: Vector2, out: Vector2) -> void:
	var g := _ground(p)
	var post := Geo.box(self, Vector3(0.12, FENCE_H + 0.1, 0.12), Color.WHITE, g + Vector3(0.0, (FENCE_H + 0.1) * 0.5 - 0.1, 0.0))
	post.material_override = _post
	var top := Geo.box(self, Vector3(0.08, 0.7, 0.08), Color.WHITE, g + Vector3(out.x * 0.17, FENCE_H + 0.27, out.y * 0.17))
	top.material_override = _post
	top.rotation = Vector3(out.y * 0.55, 0.0, -out.x * 0.55)

func _strand(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var m := Geo.box(self, Vector3(0.018, 0.018, d.length()), Color.WHITE, (a + b) * 0.5)
	m.material_override = _wire
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.look_at_from_position((a + b) * 0.5, b, Vector3.UP)

func _gate() -> void:
	# Two leaves of timber and wire, left standing open.
	var g := Terrain.camp_gate()
	for sgn in [-1.0, 1.0]:
		var hinge := _ground(Vector2(g.x, g.y + sgn * GATE_W * 0.5))
		var leaf := Node3D.new()
		add_child(leaf)
		leaf.position = hinge
		leaf.rotation.y = sgn * -1.2
		var frame := Geo.box(leaf, Vector3(0.08, 1.9, GATE_W * 0.5), Color.WHITE, Vector3(0.0, 1.0, -sgn * GATE_W * 0.25))
		frame.material_override = _wood
		frame.scale = Vector3(1.0, 1.0, 1.0)
		var brace := Geo.box(leaf, Vector3(0.06, 0.06, GATE_W * 0.55), Color.WHITE, Vector3(0.05, 1.0, -sgn * GATE_W * 0.25))
		brace.material_override = _post
		brace.rotation.x = sgn * 0.75

# ---- guard towers ----

# A timber tower at a corner of the wire: four braced legs, a railed platform with a
# hipped roof, a ladder up the inside, and a searchlight on a yoke.
func _tower(corner: Vector2) -> void:
	var t := Node3D.new()
	t.name = "Tower"
	add_child(t)
	var g := _ground(corner)
	t.position = g
	# Face the compound's middle.
	var inward := Terrain.CAMP_C - corner
	t.rotation.y = atan2(-inward.x, -inward.y)
	var L := TOWER_LEG
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	t.add_child(body)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg := Geo.box(t, Vector3(0.2, TOWER_DECK + 0.2, 0.2), Color.WHITE, Vector3(sx * L, (TOWER_DECK + 0.2) * 0.5 - 0.15, sz * L))
			leg.material_override = _post
			leg.rotation = Vector3(-sz * 0.05, 0.0, sx * 0.05)
			Geo.box_shape(body, Vector3(0.24, 2.0, 0.24), Vector3(sx * L, 1.0, sz * L))
	# Cross braces on each face, two tiers.
	for face in 4:
		var yaw := float(face) * PI * 0.5
		for tier in 2:
			var y := 0.9 + float(tier) * 1.6
			var brace := Geo.box(t, Vector3(L * 2.3, 0.1, 0.08), Color.WHITE, Vector3(0.0, y, 0.0))
			brace.material_override = _wood
			brace.rotation = Vector3(0.0, yaw, 0.55 if tier == 0 else -0.55)
			brace.position = Vector3(sin(yaw) * L, y, cos(yaw) * L)
	var deck := Geo.box(t, Vector3(L * 2.6, 0.16, L * 2.6), Color.WHITE, Vector3(0.0, TOWER_DECK, 0.0))
	deck.material_override = _wood
	for face in 4:
		var yaw := float(face) * PI * 0.5
		var rail := Geo.box(t, Vector3(L * 2.6, 0.9, 0.08), Color.WHITE, Vector3(sin(yaw) * L * 1.27, TOWER_DECK + 0.5, cos(yaw) * L * 1.27))
		rail.material_override = _wood
		rail.rotation.y = yaw
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Geo.box(t, Vector3(0.1, 1.9, 0.1), Color.WHITE, Vector3(sx * L * 1.2, TOWER_DECK + 0.95, sz * L * 1.2))
			p.material_override = _post
	# Hipped roof: a four-sided cone, turned square to the platform.
	var roof := Geo.cyl(t, L * 2.2, 0.9, Color.WHITE, Vector3(0.0, TOWER_DECK + 2.3, 0.0), 0.0)
	(roof.mesh as CylinderMesh).radial_segments = 4
	roof.rotation.y = PI * 0.25
	roof.material_override = _tin
	# The ladder up the inward side.
	for i in 12:
		var rung := Geo.box(t, Vector3(0.6, 0.05, 0.05), Color.WHITE, Vector3(0.0, 0.3 + float(i) * 0.33, -L - 0.25))
		rung.material_override = _post
	for sx in [-1.0, 1.0]:
		var rail := Geo.box(t, Vector3(0.07, TOWER_DECK, 0.07), Color.WHITE, Vector3(sx * 0.3, TOWER_DECK * 0.5, -L - 0.25))
		rail.material_override = _post
	# The searchlight: a drum on a yoke, its glass dark until the camp has power.
	var yoke := Node3D.new()
	yoke.name = "Searchlight"
	yoke.position = Vector3(0.0, TOWER_DECK + 0.55, 0.0)
	t.add_child(yoke)
	var stand := Geo.cyl(t, 0.08, 0.5, Color.WHITE, Vector3(0.0, TOWER_DECK + 0.3, 0.0))
	stand.material_override = _tin
	var drum := Geo.cyl(yoke, 0.3, 0.55, Color.WHITE, Vector3(0.0, 0.1, -0.05))
	drum.rotation.x = PI * 0.5
	drum.material_override = _tin
	var glass := Geo.cyl(yoke, 0.26, 0.04, Color.WHITE, Vector3(0.0, 0.1, -0.34))
	glass.rotation.x = PI * 0.5
	glass.material_override = Look.glow_mat(Color(0.35, 0.33, 0.28), 0.0)
	towers.append(t)
	searchlights.append(yoke)

# ---- buildings ----

# A Nissen hut: a half-cylinder of corrugated iron, brick ends with a door and windows.
func _hut(at: Vector2, label: String) -> void:
	var hut := Node3D.new()
	hut.name = label
	add_child(hut)
	hut.position = _ground(at)
	var shell := Geo.cyl(hut, HUT_R, HUT_LEN, Color.WHITE, Vector3.ZERO)
	shell.rotation.z = PI * 0.5
	(shell.mesh as CylinderMesh).radial_segments = 20
	shell.material_override = _tin
	# Corrugations: ribs along the curve.
	for i in 9:
		var rib := Geo.cyl(hut, HUT_R + 0.03, 0.06, Color.WHITE, Vector3(-HUT_LEN * 0.5 + 0.3 + float(i) * (HUT_LEN - 0.6) / 8.0, 0.0, 0.0))
		rib.rotation.z = PI * 0.5
		(rib.mesh as CylinderMesh).radial_segments = 20
		rib.material_override = _tin
	var brick := Look.stone(BRICK, 1.0)
	for sx in [-1.0, 1.0]:
		var end := Geo.cyl(hut, HUT_R - 0.05, 0.16, Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 - 0.05), 0.0, 0.0))
		end.rotation.z = PI * 0.5
		(end.mesh as CylinderMesh).radial_segments = 20
		end.material_override = brick
		var door := Geo.box(hut, Vector3(0.1, 1.9, 0.95), Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 + 0.04), 0.95, 0.0))
		door.material_override = _wood
		for sz in [-1.0, 1.0]:
			var win := Geo.box(hut, Vector3(0.08, 0.6, 0.55), Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 + 0.03), 1.25, sz * 1.15))
			win.material_override = Look.glow_mat(Color(0.12, 0.13, 0.14), 0.0)
	# A stovepipe through the roof.
	var pipe := Geo.cyl(hut, 0.09, 1.0, Color(0.15, 0.15, 0.15), Vector3(HUT_LEN * 0.25, HUT_R + 0.3, 0.4))
	pipe.name = "Stovepipe"
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	hut.add_child(body)
	Geo.box_shape(body, Vector3(HUT_LEN, HUT_R * 1.2, HUT_R * 1.9), Vector3(0.0, HUT_R * 0.6, 0.0))
	huts.append(hut)

func _generator_house(at: Vector2) -> void:
	var g := Node3D.new()
	g.name = "Generator"
	add_child(g)
	g.position = _ground(at)
	var walls := Geo.box(g, Vector3(2.6, 2.3, 3.2), Color.WHITE, Vector3(0.0, 1.15, 0.0))
	walls.material_override = Look.stone(BRICK, 1.0)
	var roof := Geo.box(g, Vector3(2.9, 0.15, 3.5), Color.WHITE, Vector3(0.0, 2.35, 0.0))
	roof.material_override = _tin
	var door := Geo.box(g, Vector3(0.08, 1.8, 1.0), Color.WHITE, Vector3(-1.32, 0.9, 0.0))
	door.material_override = _wood
	var stack := Geo.cyl(g, 0.12, 1.2, Color(0.12, 0.12, 0.12), Vector3(0.6, 2.9, -0.8))
	stack.name = "Exhaust"
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	g.add_child(body)
	Geo.box_shape(body, Vector3(2.6, 2.3, 3.2), Vector3(0.0, 1.15, 0.0))

# A vegetable bed: ridged earth in rows, edged with boards, a few plants coming up.
func _bed(at: Vector2) -> void:
	var b := Node3D.new()
	b.name = "Bed"
	add_child(b)
	b.position = _ground(at)
	var soil := Look.textured("dirt", Color(0.75, 0.62, 0.5), 1.2)
	var base := Geo.box(b, Vector3(7.0, 0.12, 1.5), Color.WHITE, Vector3(0.0, 0.03, 0.0))
	base.material_override = soil
	for r in 3:
		var ridge := Geo.box(b, Vector3(6.6, 0.14, 0.26), Color.WHITE, Vector3(0.0, 0.13, -0.45 + float(r) * 0.45))
		ridge.material_override = soil
	for sz in [-1.0, 1.0]:
		var board := Geo.box(b, Vector3(7.1, 0.18, 0.06), Color.WHITE, Vector3(0.0, 0.08, sz * 0.78))
		board.material_override = _wood
	beds.append(b)

# A glasshouse: a timber frame and glazing bars, panes you can see through, a pitched roof.
func _greenhouse(at: Vector2) -> void:
	var gh := Node3D.new()
	gh.name = "Greenhouse"
	add_child(gh)
	gh.position = _ground(at)
	var W := 6.0
	var D := 3.6
	var H := 2.0
	var base := Geo.box(gh, Vector3(W, 0.45, D), Color.WHITE, Vector3(0.0, 0.22, 0.0))
	base.material_override = Look.stone(BRICK, 1.0)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.85, 0.82, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frame := Look.flat_mat(Color(0.82, 0.82, 0.78), 0.7)
	var panes := Geo.box(gh, Vector3(W - 0.05, H - 0.45, D - 0.05), Color.WHITE, Vector3(0.0, 0.45 + (H - 0.45) * 0.5, 0.0))
	panes.material_override = glass
	for sz in [-1.0, 1.0]:
		var slope := Geo.box(gh, Vector3(W, 0.03, D * 0.58), Color.WHITE, Vector3(0.0, H + 0.42, sz * D * 0.25))
		slope.rotation.x = sz * 0.55
		slope.material_override = glass
	for i in 7:
		var x := -W * 0.5 + float(i) * W / 6.0
		for sz in [-1.0, 1.0]:
			var bar := Geo.box(gh, Vector3(0.06, H - 0.45, 0.06), Color.WHITE, Vector3(x, 0.45 + (H - 0.45) * 0.5, sz * D * 0.5))
			bar.material_override = frame
			var rafter := Geo.box(gh, Vector3(0.06, 0.05, D * 0.58), Color.WHITE, Vector3(x, H + 0.44, sz * D * 0.25))
			rafter.rotation.x = sz * 0.55
			rafter.material_override = frame
	var ridge := Geo.box(gh, Vector3(W, 0.08, 0.08), Color.WHITE, Vector3(0.0, H + 0.82, 0.0))
	ridge.material_override = frame
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	gh.add_child(body)
	Geo.box_shape(body, Vector3(W, H + 0.8, D), Vector3(0.0, (H + 0.8) * 0.5, 0.0))
	greenhouse = gh
