class_name Camp
extends Node3D
## The old wartime camp on the holm, empty since 1945: a compound fenced with barbed
## wire on cranked posts, a guard tower with a searchlight at each corner, two Nissen
## huts (living quarters, and the mess where the research is done), the generator
## house, vegetable beds and a greenhouse, and the gate facing the rope bridge.
## The generator powers the searchlights and the huts' lights at night; keepers climb
## a tower's ladder to take its light (docs/DECISIONS.md, "The camp's power").
## Creatures come up the holm's beaches for it: the wire, the generator, the huts and the
## greenhouse can all be wrecked, and what's wrecked stops working until it's mended.

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

var searchlights: Array[Searchlight] = []
var generator: Generator
var _hut_lights: Array[OmniLight3D] = []
var _hut_windows: Array[StandardMaterial3D] = []
var towers: Array[Node3D] = []
var huts: Array[Node3D] = []
var greenhouse: Node3D
var beds: Array[Node3D] = []
var plots: Array[CampPlot] = []
var stove: HutStove
var mess: MessTable
var desk: ResearchDesk
## The camp's buildings by id ("quarters", "mess", "greenhouse"), as creatures see them.
var buildings := {}
var wire: Array[CampWire] = []

var _wood: StandardMaterial3D
var _post: StandardMaterial3D
var _wire: StandardMaterial3D
var _tin: StandardMaterial3D
var _felt: StandardMaterial3D
var _brick: StandardMaterial3D
var _concrete: StandardMaterial3D
var _rust: StandardMaterial3D
var _sacking: StandardMaterial3D

func _ready() -> void:
	name = "Camp"
	add_to_group("camp_root")
	# Weathered boards, silvered rough-sawn posts, olive corrugated iron gone to rust,
	# tarred felt, red brick, board-marked concrete, sacking: the 1940s, after five years
	# of North Sea weather and nobody since.
	_wood = Look.wood(Color(0.34, 0.31, 0.27), 0.8)
	_post = Look.camp("timber", 1.0)
	_wire = Look.flat_mat(WIRE, 0.6)
	_wire.metallic = 0.6
	_tin = Look.camp("corrugated", 1.2, true, 0.7, 0.35)
	_felt = Look.camp("tarfelt", 1.5, false, 0.95)
	_brick = Look.camp("brick", 1.0)
	_concrete = Look.camp("concrete", 1.5, true, 0.92, 0.0, Color(0.82, 0.82, 0.8))
	_rust = Look.camp("rust", 1.0, false, 0.75, 0.4)
	_sacking = Look.camp("hessian", 0.5, false, 1.0)
	var c := Terrain.CAMP_C
	var h := Terrain.CAMP_HALF
	var corners := [Vector2(c.x - h.x, c.y - h.y), Vector2(c.x + h.x, c.y - h.y), Vector2(c.x + h.x, c.y + h.y), Vector2(c.x - h.x, c.y + h.y)]
	for i in 4:
		_fence_side(corners[i], corners[(i + 1) % 4], i == 3)
	generator = Generator.new()
	generator.position = _ground(Vector2(c.x + 8.6, c.y + 0.6))
	add_child(generator)
	for p in corners:
		_tower(p)
	_hut(Vector2(c.x - 4.6, c.y - 5.0), "Quarters")
	_hut(Vector2(c.x + 4.4, c.y - 5.0), "Mess")
	# The quarters' stove and the mess table, worked from in front of each hut.
	stove = HutStove.new()
	stove.position = _ground(Vector2(c.x - 4.6, c.y - 2.6))
	stove.pipe_top = huts[0].to_global(Vector3(HUT_LEN * 0.25, HUT_R + 0.85, 0.4))
	add_child(stove)
	mess = MessTable.new()
	mess.position = _ground(Vector2(c.x + 4.4, c.y - 2.6))
	add_child(mess)
	desk = ResearchDesk.new()
	desk.position = _ground(Vector2(c.x + 6.4, c.y - 2.6))
	add_child(desk)
	for i in 3:
		_bed(Vector2(c.x - 5.0, c.y + 2.6 + float(i) * 2.0))
	_greenhouse(Vector2(c.x + 4.6, c.y + 4.9))
	_gate()
	_dress()
	# What's in a building works only while it stands.
	stove.building = buildings["quarters"]
	mess.building = buildings["mess"]
	desk.building = buildings["mess"]
	plots[3].building = buildings["greenhouse"]

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
		var strung: Array[Node3D] = []
		for w in WIRES:
			var y := 0.25 + float(w) * (FENCE_H - 0.4) / float(WIRES - 1)
			var pa := _ground(a) + Vector3(0.0, y, 0.0)
			var pb := _ground(b) + Vector3(0.0, y, 0.0)
			strung.append(_strand(pa, pb))
		# The cranked tops carry two more strands, out over the ditch.
		for w in 2:
			var lean := Vector3(out.x, 0.0, out.y) * (0.22 + 0.2 * float(w))
			var y := FENCE_H + 0.15 + 0.2 * float(w)
			strung.append(_strand(_ground(a) + Vector3(0.0, y, 0.0) + lean, _ground(b) + Vector3(0.0, y, 0.0) + lean))
		# Its body and health: creatures tear at it, keepers mend it.
		var run := CampWire.new((b - a).length(), FENCE_H)
		run.strands = strung
		run.position = _ground((a + b) * 0.5)
		run.rotation.y = -atan2(dir.y, dir.x)
		add_child(run)
		wire.append(run)

func _fence_post(p: Vector2, out: Vector2) -> void:
	var g := _ground(p)
	var post := Geo.box(self, Vector3(0.12, FENCE_H + 0.1, 0.12), Color.WHITE, g + Vector3(0.0, (FENCE_H + 0.1) * 0.5 - 0.1, 0.0))
	post.material_override = _post
	var top := Geo.box(self, Vector3(0.08, 0.7, 0.08), Color.WHITE, g + Vector3(out.x * 0.17, FENCE_H + 0.27, out.y * 0.17))
	top.material_override = _post
	top.rotation = Vector3(out.y * 0.55, 0.0, -out.x * 0.55)

func _strand(a: Vector3, b: Vector3) -> MeshInstance3D:
	var d := b - a
	var m := Geo.box(self, Vector3(0.018, 0.018, d.length()), Color.WHITE, (a + b) * 0.5)
	m.material_override = _wire
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
	return m

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

# ---- dressing: what makes it a camp ----

## The flag, so it can stream and flap in the wind.
var _flag_holder: Node3D
var _flag_t := 0.0

func _dress() -> void:
	var c := Terrain.CAMP_C
	# Concrete paths: from the gate across the parade ground to the generator, and spurs
	# to the huts' fronts and the greenhouse door.
	_path(Vector2(c.x - 11.0, c.y), Vector2(c.x + 7.2, c.y), 1.5)
	_path(Vector2(c.x - 4.6, c.y), Vector2(c.x - 4.6, c.y - 2.7), 1.2)
	_path(Vector2(c.x + 4.4, c.y), Vector2(c.x + 4.4, c.y - 2.7), 1.2)
	_path(Vector2(c.x + 4.6, c.y), Vector2(c.x + 4.6, c.y + 3.0), 1.2)
	# Duckboards along the beds, laid against the mud.
	for i in 3:
		var at := _ground(Vector2(c.x - 1.0, c.y + 2.6 + float(i) * 2.0))
		for k in 5:
			var slat := Geo.box(self, Vector3(0.5, 0.04, 0.12), Color.WHITE, at + Vector3(0.0, 0.05, -0.3 + float(k) * 0.15))
			slat.material_override = _wood
	_flagpole(_ground(Vector2(c.x - 1.6, c.y - 1.4)))
	_sign(_ground(Vector2(c.x - 12.3, c.y - 2.2)))
	_water_tank(_ground(Vector2(c.x + 9.6, c.y - 5.6)))
	for i in 5:
		var a := float(i) * 1.3
		_drum(_ground(Vector2(c.x + 9.2 + cos(a) * 0.55 * float(i % 3), c.y + 4.0 + sin(a) * 0.6 * float(i % 3))), i)
	_sandbags(Vector2(c.x + 10.25, c.y - 0.9), Vector2(c.x + 10.25, c.y + 2.1))
	_sandbags(Vector2(c.x + 7.2, c.y + 2.45), Vector2(c.x + 10.1, c.y + 2.45))
	_coal_bunker(_ground(Vector2(c.x - 9.9, c.y + 4.3)))
	_washing_line(_ground(Vector2(c.x - 9.7, c.y - 6.6)), _ground(Vector2(c.x - 9.7, c.y - 3.4)))

func _process_flag(delta: float) -> void:
	if _flag_holder == null:
		return
	_flag_t += delta * (0.6 + Weather.wind_now.length() * 0.5)
	_flag_holder.rotation.y = 0.9 + sin(_flag_t * 3.1) * 0.25 + sin(_flag_t * 7.3) * 0.08
	_flag_holder.rotation.x = sin(_flag_t * 4.7) * 0.06

func _path(a: Vector2, b: Vector2, width: float) -> void:
	var d := b - a
	var mid := (a + b) * 0.5
	var slab := Geo.box(self, Vector3(d.length() + width * 0.3, 0.08, width), Color.WHITE, _ground(mid) + Vector3(0.0, 0.0, 0.0))
	slab.rotation.y = -atan2(d.y, d.x)
	slab.material_override = _concrete
	# Bedded into the ground, its top just proud of it, and cracked into bays.
	slab.position.y += 0.01
	var bays := int(d.length() / 1.6)
	for i in range(1, bays):
		var p := a + d * (float(i) / float(bays))
		var joint := Geo.box(self, Vector3(0.03, 0.09, width), Color(0.2, 0.2, 0.19), _ground(p) + Vector3(0.0, 0.015, 0.0))
		joint.rotation.y = -atan2(d.y, d.x)

# A flagpole on the parade ground, its old flag faded and torn.
func _flagpole(at: Vector3) -> void:
	var pole := Geo.cyl(self, 0.05, 6.5, Color.WHITE, at + Vector3(0.0, 3.25, 0.0), 0.035)
	pole.material_override = Look.flat_mat(Color(0.72, 0.70, 0.65), 0.6)
	var knob := Geo.sphere(self, 0.08, Color.WHITE, at + Vector3(0.0, 6.55, 0.0))
	knob.material_override = Look.flat_mat(Color(0.6, 0.5, 0.25), 0.4)
	var plinth := Geo.box(self, Vector3(0.7, 0.3, 0.7), Color.WHITE, at + Vector3(0.0, 0.1, 0.0))
	plinth.material_override = _concrete
	var holder := Node3D.new()
	add_child(holder)
	holder.position = at + Vector3(0.0, 6.0, 0.0)
	var cloth := Geo.box(holder, Vector3(1.3, 0.75, 0.02), Color.WHITE, Vector3(0.68, -0.4, 0.0))
	cloth.material_override = Look.flat_mat(Color(0.42, 0.40, 0.44), 0.95)
	# Torn at the fly.
	var tear := Geo.box(holder, Vector3(0.3, 0.3, 0.025), Color.WHITE, Vector3(1.38, -0.62, 0.0))
	tear.material_override = cloth.material_override
	tear.rotation.z = 0.4
	_flag_holder = holder

# The board at the gate: the camp's name, painted, and the warning under it.
func _sign(at: Vector3) -> void:
	var board := Geo.box(self, Vector3(0.06, 0.9, 1.9), Color.WHITE, at + Vector3(0.0, 1.55, 0.0))
	board.material_override = Look.wood(Color(0.62, 0.6, 0.55), 0.6)
	for sz in [-0.8, 0.8]:
		var post := Geo.box(self, Vector3(0.1, 2.0, 0.1), Color.WHITE, at + Vector3(0.0, 1.0, sz))
		post.material_override = _post
	var text := Label3D.new()
	text.text = "No. 7 CAMP\nAUTHORISED PERSONS ONLY"
	text.font_size = 46
	text.pixel_size = 0.004
	text.modulate = Color(0.12, 0.1, 0.08)
	text.outline_size = 0
	text.double_sided = false
	text.position = at + Vector3(-0.04, 1.58, 0.0)
	text.rotation.y = -PI * 0.5
	add_child(text)

# The water tank on its stand by the generator house, rusted through in places.
func _water_tank(at: Vector3) -> void:
	for sx in [-0.55, 0.55]:
		for sz in [-0.55, 0.55]:
			var leg := Geo.box(self, Vector3(0.14, 1.6, 0.14), Color.WHITE, at + Vector3(sx, 0.8, sz))
			leg.material_override = _post
	var tank := Geo.box(self, Vector3(1.5, 1.1, 1.5), Color.WHITE, at + Vector3(0.0, 2.15, 0.0))
	tank.material_override = _rust
	var lid := Geo.box(self, Vector3(1.55, 0.05, 1.55), Color.WHITE, at + Vector3(0.0, 2.73, 0.0))
	lid.material_override = _rust
	var pipe := Geo.cyl(self, 0.04, 1.6, Color.WHITE, at + Vector3(0.7, 0.8, 0.0))
	pipe.material_override = _rust
	var body := StaticBody3D.new()
	# Solid to keepers only: creatures (which don't collide with layer 1) go by.
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	Geo.box_shape(body, Vector3(1.4, 2.8, 1.4), at + Vector3(0.0, 1.4, 0.0))

# An oil drum, rusted or still in its paint, standing or on its side.
func _drum(at: Vector3, i: int) -> void:
	var paint := [_rust, Look.camp("rust", 1.0, false, 0.6, 0.3, Color(0.75, 0.95, 0.75)), _rust]
	var d := Geo.cyl(self, 0.29, 0.88, Color.WHITE, at + Vector3(0.0, 0.44, 0.0))
	d.material_override = paint[i % paint.size()]
	if i == 3:
		d.rotation.z = PI * 0.5
		d.position.y = at.y + 0.29
	for k in 2:
		if i != 3:
			var hoop := Geo.cyl(self, 0.3, 0.03, Color.WHITE, at + Vector3(0.0, 0.3 + 0.3 * float(k), 0.0))
			hoop.material_override = _rust

# A low wall of sandbags: the blast wall round the generator house.
func _sandbags(a: Vector2, b: Vector2) -> void:
	var d := b - a
	var n := maxi(2, int(d.length() / 0.55))
	for row in 3:
		for i in n - (row % 2):
			var u := (float(i) + 0.5 + 0.5 * float(row % 2)) / float(n)
			var p := _ground(a + d * u)
			var bag := Geo.box(self, Vector3(0.55, 0.26, 0.38), Color.WHITE, p + Vector3(0.0, 0.13 + 0.25 * float(row), 0.0))
			bag.rotation.y = -atan2(d.y, d.x) + 0.08 * sin(float(i * 7 + row * 3))
			bag.material_override = _sacking
	var body := StaticBody3D.new()
	# Solid to keepers only: creatures (which don't collide with layer 1) go by.
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var cs := Geo.box_shape(body, Vector3(d.length(), 0.8, 0.4), _ground((a + b) * 0.5) + Vector3(0.0, 0.4, 0.0))
	cs.rotation.y = -atan2(d.y, d.x)

# The quarters' coal bunker: three concrete walls, a slope of coal and a shovel.
func _coal_bunker(at: Vector3) -> void:
	for k in 3:
		var yaw := float(k) * PI * 0.5
		var w := Geo.box(self, Vector3(1.2, 0.7, 0.12), Color.WHITE, at + Vector3(sin(yaw) * 0.55, 0.35, cos(yaw) * 0.55))
		w.rotation.y = yaw
		w.material_override = _concrete
	var coal := Geo.box(self, Vector3(1.0, 0.35, 1.0), Color.WHITE, at + Vector3(0.0, 0.2, 0.0))
	coal.rotation.x = 0.25
	coal.material_override = Look.flat_mat(Color(0.06, 0.06, 0.065), 0.5)
	var body := StaticBody3D.new()
	# Solid to keepers only: creatures (which don't collide with layer 1) go by.
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	Geo.box_shape(body, Vector3(1.3, 0.7, 1.3), at + Vector3(0.0, 0.35, 0.0))

# A washing line from the quarters' end to a post, a shirt and a blanket left on it.
func _washing_line(a: Vector3, b: Vector3) -> void:
	for p in [a, b]:
		var post := Geo.box(self, Vector3(0.08, 1.9, 0.08), Color.WHITE, p + Vector3(0.0, 0.95, 0.0))
		post.material_override = _post
	var line := Geo.box(self, Vector3(0.01, 0.01, a.distance_to(b)), Color.WHITE, (a + b) * 0.5 + Vector3(0.0, 1.78, 0.0))
	line.material_override = Look.flat_mat(Color(0.6, 0.58, 0.5))
	line.look_at_from_position(line.position, b + Vector3(0.0, 1.78, 0.0), Vector3.UP)
	var cloth := [Color(0.55, 0.55, 0.5), Color(0.32, 0.3, 0.38), Color(0.6, 0.52, 0.42)]
	for i in 3:
		var p := a.lerp(b, 0.25 + 0.25 * float(i)) + Vector3(0.0, 1.45, 0.0)
		var c := Geo.box(self, Vector3(0.03, 0.6, 0.55 - 0.1 * float(i)), Color.WHITE, p)
		c.material_override = Look.flat_mat(cloth[i], 0.95)

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
	# Keepers stand on the platform: a floor, and rails all round but for the ladder's gap.
	var top := StaticBody3D.new()
	top.collision_layer = 1
	top.collision_mask = 0
	t.add_child(top)
	Geo.box_shape(top, Vector3(L * 2.6, 0.16, L * 2.6), Vector3(0.0, TOWER_DECK, 0.0))
	for face in 4:
		var yaw := float(face) * PI * 0.5
		var out := Vector3(sin(yaw), 0.0, cos(yaw)) * L * 1.27
		if face == 2:
			# The ladder side: a rail either side of the gap it comes up through.
			for sx in [-1.0, 1.0]:
				var seg := Geo.box(t, Vector3(L * 0.85, 0.9, 0.08), Color.WHITE, out + Vector3(sx * L * 0.88, TOWER_DECK + 0.5, 0.0))
				seg.material_override = _wood
				var cs := Geo.box_shape(top, Vector3(L * 0.85, 1.2, 0.1), out + Vector3(sx * L * 0.88, TOWER_DECK + 0.6, 0.0))
				cs.rotation.y = yaw
			continue
		var rail := Geo.box(t, Vector3(L * 2.6, 0.9, 0.08), Color.WHITE, out + Vector3(0.0, TOWER_DECK + 0.5, 0.0))
		rail.material_override = _wood
		rail.rotation.y = yaw
		var rcs := Geo.box_shape(top, Vector3(L * 2.6, 1.2, 0.1), out + Vector3(0.0, TOWER_DECK + 0.6, 0.0))
		rcs.rotation.y = yaw
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Geo.box(t, Vector3(0.1, 1.9, 0.1), Color.WHITE, Vector3(sx * L * 1.2, TOWER_DECK + 0.95, sz * L * 1.2))
			p.material_override = _post
	# Hipped roof: a four-sided cone, turned square to the platform.
	var roof := Geo.cyl(t, L * 2.2, 0.9, Color.WHITE, Vector3(0.0, TOWER_DECK + 2.3, 0.0), 0.0)
	(roof.mesh as CylinderMesh).radial_segments = 4
	roof.rotation.y = PI * 0.25
	roof.material_override = _felt
	# The ladder up the inward side: a keepers' ladder like the crag's.
	var ladder := Ladder.new(t.to_global(Vector3(0.0, TOWER_DECK + 0.1, -L + 0.45)), t.to_global(Vector3(0.0, 0.0, -L - 1.0)),
		t.to_global(Vector3(0.0, TOWER_DECK, -L - 0.2)), t.to_global(Vector3(0.0, 0.0, -L - 0.55)))
	add_child(ladder)
	# Its top end sits at the hatch in the rail, a step from where a keeper climbs off,
	# so arriving at the top the searchlight is the nearer thing to hand.
	for e in ladder.get_children():
		if e is LadderEnd and e.to.y < ladder.top.y - 1.0:
			e.global_position = t.to_global(Vector3(0.0, TOWER_DECK + 0.1, -L * 1.15))
	KeeperNav.add_ladder(ladder.top, ladder.bottom, Ladder.DOWN_TIME, Ladder.UP_TIME * 1.2)
	# The searchlight on its yoke at the platform's outer corner, looking out from the wire.
	var sl := Searchlight.new()
	sl.name = "Searchlight"
	sl.generator = generator
	sl.position = Vector3(0.0, TOWER_DECK + 0.8, L * 0.55)
	t.add_child(sl)
	var outward := corner - Terrain.CAMP_C
	sl.home_yaw = atan2(-outward.x, -outward.y)
	towers.append(t)
	searchlights.append(sl)

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
	# Its concrete base, a lip showing all round.
	var base := Geo.box(hut, Vector3(HUT_LEN + 0.5, 0.3, HUT_R * 2.0 + 0.4), Color.WHITE, Vector3(0.0, -0.08, 0.0))
	base.material_override = _concrete
	for sx in [-1.0, 1.0]:
		var end := Geo.cyl(hut, HUT_R - 0.05, 0.16, Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 - 0.05), 0.0, 0.0))
		end.rotation.z = PI * 0.5
		(end.mesh as CylinderMesh).radial_segments = 20
		end.material_override = _brick
		# A concrete step to the door, and a little lean-to porch over it.
		var step := Geo.box(hut, Vector3(0.5, 0.18, 1.3), Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 + 0.3), 0.09, 0.0))
		step.material_override = _concrete
		var porch := Geo.box(hut, Vector3(0.7, 0.05, 1.5), Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 + 0.3), 2.15, 0.0))
		porch.rotation.z = sx * 0.18
		porch.material_override = _felt
		var door := Geo.box(hut, Vector3(0.1, 1.9, 0.95), Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 + 0.04), 0.95, 0.0))
		door.material_override = _wood
		var win_mat := Look.glow_mat(Color(0.12, 0.13, 0.14), 0.0)
		_hut_windows.append(win_mat)
		for sz in [-1.0, 1.0]:
			var win := Geo.box(hut, Vector3(0.08, 0.6, 0.55), Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 + 0.03), 1.25, sz * 1.15))
			win.material_override = win_mat
			# A painted frame and sill round it, and a glazing bar.
			for k in 2:
				var fr := Geo.box(hut, Vector3(0.1, 0.06, 0.65), Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 + 0.05), 0.92 + 0.66 * float(k), sz * 1.15))
				fr.material_override = _wood
			var bar := Geo.box(hut, Vector3(0.1, 0.6, 0.04), Color.WHITE, Vector3(sx * (HUT_LEN * 0.5 + 0.06), 1.25, sz * 1.15))
			bar.material_override = _wood
		# Electric light inside, thrown out through the end windows.
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.86, 0.6)
		lamp.omni_range = 5.5
		lamp.light_energy = 0.0
		lamp.position = Vector3(sx * (HUT_LEN * 0.5 + 0.6), 1.4, 0.0)
		lamp.visible = false
		hut.add_child(lamp)
		_hut_lights.append(lamp)
	# A stovepipe through the roof.
	var pipe := Geo.cyl(hut, 0.09, 1.0, Color(0.15, 0.15, 0.15), Vector3(HUT_LEN * 0.25, HUT_R + 0.3, 0.4))
	pipe.name = "Stovepipe"
	# Its body and health, beside it (so it can sag without the body scaling).
	var b := CampBuilding.new(label.to_lower(), HUT_HP, Vector3(HUT_LEN, HUT_R * 1.2, HUT_R * 1.9))
	b.visual = hut
	b.position = hut.position
	add_child(b)
	buildings[b.id] = b
	huts.append(hut)

## Each hut's lights draw this much from the generator.
const HUT_DRAW := 0.015
const HUT_HP := 220
const GREENHOUSE_HP := 150

func _process(delta: float) -> void:
	_process_flag(delta)
	# The huts are lit while the generator runs, flickering as it runs dry; a wrecked
	# hut stays dark.
	var level := generator.power_level() if generator != null else 0.0
	var lit := 0
	for h in huts.size():
		var b: CampBuilding = buildings.get(huts[h].name.to_lower())
		var on := level if b == null or not b.is_destroyed() else 0.0
		if on > 0.0:
			lit += 1
		# Two lights and two window panes to a hut, one at each end.
		for k in 2:
			var i := h * 2 + k
			if i < _hut_lights.size():
				_hut_lights[i].visible = on > 0.0
				_hut_lights[i].light_energy = 1.3 * on
			if i < _hut_windows.size():
				_hut_windows[i].emission_energy_multiplier = 2.2 * on
				_hut_windows[i].albedo_color = Color(1.0, 0.85, 0.55) if on > 0.0 else Color(0.12, 0.13, 0.14)
	if generator != null:
		generator.set_draw(self, HUT_DRAW * float(lit) if level > 0.0 else 0.0)

## What creatures make for on the holm: the generator and the buildings still standing.
func targets() -> Array[Structure]:
	var out: Array[Structure] = []
	if generator != null and not generator.is_destroyed():
		out.append(generator)
	for b in buildings.values():
		if not b.is_destroyed():
			out.append(b)
	return out

## The camp has fallen: its generator and every building wrecked.
func fallen() -> bool:
	return targets().is_empty()

## The runs of wire torn down.
func wire_down() -> int:
	var n := 0
	for w in wire:
		if w.is_destroyed():
			n += 1
	return n

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
	var plot := CampPlot.new()
	plot.index = beds.size()
	b.add_child(plot)
	plots.append(plot)
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
	base.material_override = _brick
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.85, 0.82, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic_specular = 0.9
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frame := Look.flat_mat(Color(0.82, 0.82, 0.78), 0.7)
	var panes := Geo.box(gh, Vector3(W - 0.05, H - 0.45, D - 0.05), Color.WHITE, Vector3(0.0, 0.45 + (H - 0.45) * 0.5, 0.0))
	panes.material_override = glass
	var roof: Array[Node3D] = []
	for sz in [-1.0, 1.0]:
		var slope := Geo.box(gh, Vector3(W, 0.03, D * 0.58), Color.WHITE, Vector3(0.0, H + 0.42, sz * D * 0.25))
		slope.rotation.x = sz * 0.55
		slope.material_override = glass
		roof.append(slope)
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
	var body := CampBuilding.new("greenhouse", GREENHOUSE_HP, Vector3(W, H + 0.8, D))
	body.visual = gh
	body.position = gh.position
	body.breakable.append(panes)
	body.breakable.append_array(roof)
	add_child(body)
	buildings["greenhouse"] = body
	greenhouse = gh
	# Its staging inside, worked from the doorway on the side facing the parade ground.
	var bench := Geo.box(gh, Vector3(W - 0.8, 0.06, D - 1.0), Color.WHITE, Vector3(0.0, 0.5, 0.0))
	bench.material_override = _wood
	var plot := CampPlot.new()
	plot.index = 3
	plot.under_glass = true
	plot.length = W - 1.2
	plot.position = Vector3(0.0, 0.0, -D * 0.5 - 0.05)
	plot.plants_offset = Vector3(0.0, 0.3, D * 0.5)
	gh.add_child(plot)
	plots.append(plot)
