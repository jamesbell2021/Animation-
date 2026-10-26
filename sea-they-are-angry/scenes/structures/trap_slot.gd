class_name TrapSlot
extends Node3D
## A marked spot on a creature path (a little cairn) where the keepers can set a trap.
## Three on the beaches to start; defences upgrades open one on the ledge and one at
## its foot, and the camp's holm has four defence posts of its own. A set trap springs on
## the first creature to step on it, and is spent after a few. A Crab's slam smashes any
## trap in front of it. Research at the camp adds wire, tripwires and sandbag walls.

const TRIGGER_R := 1.1
const TRIGGER_HEIGHT := 1.2
const COOLDOWN := 0.8
const SPIKE_DMG := 25
const NET_TIME := 3.0
const CHAIN_TIME := 3.0
const CHAIN_EXPOSED := 5.0
const OTHER_STAGGER := 1.0
const TRAPS := {
	"spike": {"name": "Spike board", "cost": {"driftwood": 2}, "uses": 3,
		"blurb": "25 damage, and a Bloated bursts where it stands. Squid skitter over it."},
	"net": {"name": "Kelp net", "cost": {"driftwood": 1, "seaweed": 1}, "uses": 2,
		"blurb": "tangles a Bloated, Squid or Smotherer for 3 s. Crabs cut through."},
	"chain": {"name": "Chain plate", "cost": {"driftwood": 1, "scrap": 2}, "uses": 2,
		"blurb": "flips a Crab: stunned, and the boathook bites twice as deep."},
	# Worked out at the camp's research desk ("needs").
	"poison": {"name": "Rat poison", "cost": {"poison": 1, "seaweed": 1}, "uses": 3,
		"blurb": "kelp bait laced from the shed's tins: poisons the first 3 to eat it, sickening them slow and weak."},
	"wire": {"name": "Barbed wire", "cost": {"scrap": 1, "driftwood": 1}, "uses": 40, "needs": "wire",
		"blurb": "slows anything pushing through to a crawl and cuts it. Wears out after 40 s of it."},
	"tripwire": {"name": "Tripwire flare", "cost": {"scrap": 1, "bio": 1}, "uses": 1, "needs": "tripwire",
		"blurb": "fires a flare into the first thing to trip it: 40 damage, and red light."},
	"sandbags": {"name": "Sandbag wall", "cost": {"driftwood": 2, "seaweed": 1}, "uses": 1, "needs": "sandbags", "wall": true,
		"blurb": "a wall across the path that creatures must batter down (160). Patch it with driftwood."},
}
const POISON_TIME := 14.0
const WIRE_R := 1.4
const WIRE_SLOW := 0.35
const WIRE_DPS := 5.0
const IRON := Color(0.2, 0.2, 0.22)

var index := 0
## One of the holm's defence posts: open from the start, not by the defences upgrade.
var holm := false
## The way creatures come along the path here (flat), for a sandbag wall across it;
## zero where a wall would shut the keepers' own way (the ledge, the gate, the bridge).
var path_dir := Vector3.ZERO
var unlocked := true
var kind := ""
var uses := 0
var _cairn: Node3D
var _trap: Node3D
var _cd := 0.0
var _caught := {}
var wall: SandbagWall
var _wire_wear := 0.0
var _wire_cut := {}

func _ready() -> void:
	add_to_group("trap_slots")
	add_to_group("interactable")
	_cairn = Node3D.new()
	add_child(_cairn)
	for i in 3:
		var a := TAU * float(i) / 3.0
		Look.rock(_cairn, 1200 + index * 7 + i, Vector3(0.28, 0.22, 0.24), Vector3(sin(a) * 0.62, 0.04, cos(a) * 0.62), Look.STONE, 0.4)
	# A rag tied to a stick, so the spot can be found by lantern light.
	var stick := Geo.box(_cairn, Vector3(0.04, 0.7, 0.04), Look.WOOD, Vector3(0.62, 0.35, 0.0))
	stick.material_override = Look.flat_mat(Look.WOOD_PALE)
	var rag := Geo.box(_cairn, Vector3(0.02, 0.16, 0.22), Color.WHITE, Vector3(0.62, 0.62, 0.12))
	rag.material_override = Look.flat_mat(Color(0.75, 0.2, 0.15), 0.9)
	_refresh()

func set_unlocked(v: bool) -> void:
	unlocked = v
	_refresh()

func is_armed() -> bool:
	return unlocked and kind != ""

func _refresh() -> void:
	visible = unlocked
	if _trap != null:
		_trap.queue_free()
		_trap = null
	if kind != "":
		_trap = _build_trap(kind)
		add_child(_trap)

# ---- keepers ----

func interact_prompt() -> String:
	if not unlocked:
		return ""
	if kind == "sandbags":
		return ""
	if kind == "wire":
		return "Barbed wire strung  (%d s left)" % ceili(uses - _wire_wear)
	if kind != "":
		return "%s set  (%d left)" % [TRAPS[kind]["name"], uses]
	return "[E] Set a trap at the defence post" if holm else "[E] Set a trap"

func interact(player: Node) -> bool:
	if not unlocked or kind != "" or not (player is Player):
		return false
	ChoiceMenu.open(player, "Set a trap", menu_rows)
	return true

func menu_rows() -> Array:
	var rows := []
	for k in TRAPS:
		var t: Dictionary = TRAPS[k]
		if not can_set(k):
			continue
		rows.append({"text": "%s (%s, %d uses): %s" % [t["name"], Stock.cost_str(t["cost"]), t["uses"], t["blurb"]],
			"enabled": Stock.can_afford(t["cost"]), "do": arm.bind(k)})
	return rows

## Whether this kind can go here at all: worked out at the desk, and (for a wall) a path
## a wall can go across.
func can_set(k: String) -> bool:
	var t: Dictionary = TRAPS[k]
	if t.has("needs") and not Research.has(t["needs"]):
		return false
	return not t.get("wall", false) or path_dir != Vector3.ZERO

## Set a trap of this kind, paying for it. Returns false so the menu closes.
func arm(k: String) -> bool:
	if kind != "" or not can_set(k) or not Stock.spend(TRAPS[k]["cost"]):
		return false
	kind = k
	uses = int(TRAPS[k]["uses"])
	_caught.clear()
	_wire_cut.clear()
	_wire_wear = 0.0
	if k == "sandbags":
		_raise_wall()
	_refresh()
	Audio.sfx("hammer", global_position, -4.0, 0.1)
	Events.message.emit("%s set." % TRAPS[k]["name"])
	return false

## Smashed (a Crab's slam): the trap is gone.
func wreck() -> void:
	# A wall is battered down like any building, not smashed at a stroke.
	if kind == "" or kind == "sandbags":
		return
	FX.splinters(get_parent(), global_position + Vector3(0.0, 0.3, 0.0))
	_spend_all()

func _spend_all() -> void:
	kind = ""
	uses = 0
	_refresh()

# ---- springing ----

func _raise_wall() -> void:
	if wall != null and is_instance_valid(wall):
		wall.queue_free()
	wall = SandbagWall.new()
	wall.position = position
	wall.rotation.y = atan2(path_dir.x, path_dir.z)
	get_parent().add_child(wall)
	wall.destroyed.connect(_on_wall_down)

func _on_wall_down() -> void:
	if kind == "sandbags":
		_spend_all()
		Events.message.emit("A sandbag wall is down!")

func _physics_process(delta: float) -> void:
	if not is_armed():
		return
	if kind == "sandbags":
		return
	if kind == "wire":
		_wire(delta)
		return
	_cd = maxf(0.0, _cd - delta)
	if _cd > 0.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.hp <= 0 or e.state == &"Emerge" or e is Eel:
			continue
		var id := e.get_instance_id()
		if _caught.has(id):
			continue
		if absf(e.global_position.y - global_position.y) > TRIGGER_HEIGHT or Geo.flat_dist(e.global_position, global_position) > TRIGGER_R:
			continue
		if _spring(e):
			_caught[id] = true
			_cd = COOLDOWN
			uses -= 1
			if uses <= 0:
				_spend_all()
			return

# Barbed wire: everything in it crawls and bleeds, and the wire wears while it does.
func _wire(delta: float) -> void:
	var any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.hp <= 0 or e.state == &"Emerge" or e is Eel:
			continue
		if absf(e.global_position.y - global_position.y) > TRIGGER_HEIGHT or Geo.flat_dist(e.global_position, global_position) > WIRE_R:
			continue
		any = true
		e.speed_mult *= WIRE_SLOW
		var id := e.get_instance_id()
		var cut: float = _wire_cut.get(id, 0.0) + WIRE_DPS * delta
		if cut >= 1.0:
			e.last_hit = "trap"
			e.take_damage(int(cut), Vector3.ZERO, null)
			cut -= floorf(cut)
			if randf() < 0.25:
				FX.spray(get_parent(), e.global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP, Color(0.55, 0.65, 0.45))
		_wire_cut[id] = cut
	if any:
		_wire_wear += delta
		if _wire_wear >= uses:
			Events.message.emit("The barbed wire is torn away.")
			_spend_all()

# What the trap does to this creature; false if it passes over unharmed.
func _spring(e: Enemy) -> bool:
	var mult: float = Upgrades.pick("defences", Upgrades.TRAP_DMG)
	var at := global_position + Vector3(0.0, 0.3, 0.0)
	match kind:
		"spike":
			if e is Squid:
				return false
			e.last_hit = "trap"
			if e is Bloated:
				# Punctured: it swells and bursts right here, short of anything it could hurt.
				e.take_damage(e.hp, Vector3.ZERO, null)
			else:
				e.take_damage(roundi(SPIKE_DMG * mult), Vector3.ZERO, null)
			FX.spray(get_parent(), at + Vector3(0.0, 0.5, 0.0), Vector3.UP, Color(0.55, 0.65, 0.45))
		"net":
			if e is Crab:
				return false
			e.stagger(NET_TIME * mult)
			FX.splash(get_parent(), at, 0.5)
		"chain":
			if e is Crab:
				e.flip(CHAIN_TIME * mult)
				e.exposed_t = CHAIN_EXPOSED
			else:
				e.stagger(OTHER_STAGGER)
			FX.sparks(get_parent(), at)
		"poison":
			# Squid skitter over bait; a Crab's armour doesn't care what it eats.
			if e is Squid:
				return false
			e.poison(POISON_TIME * mult)
			FX.spray(get_parent(), at + Vector3(0.0, 0.3, 0.0), Vector3.UP, Color(0.45, 0.8, 0.3))
		"tripwire":
			# The flare goes off from a stake beside the path, straight into it.
			var f := Flare.new()
			f.from = global_position + Vector3(0.62, 0.7, 0.0)
			f.to = e.global_position + e.velocity * Flare.FLIGHT_TIME
			get_parent().add_child(f)
	Audio.sfx("trap_snap", global_position, 0.0, 0.1)
	if _trap != null and uses > 1:
		var tw := _trap.create_tween()
		tw.tween_property(_trap, "scale", Vector3(1.25, 0.6, 1.25), 0.06)
		tw.tween_property(_trap, "scale", Vector3.ONE, 0.2)
	return true

# ---- looks ----

func _build_trap(k: String) -> Node3D:
	var n := Node3D.new()
	var iron := Look.flat_mat(IRON, 0.4)
	match k:
		"spike":
			var board := Geo.box(n, Vector3(0.95, 0.07, 0.95), Color.WHITE, Vector3(0.0, 0.05, 0.0))
			board.material_override = Look.flat_mat(Look.WOOD_PALE, 0.9)
			for i in 9:
				var spike := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.0
				cm.bottom_radius = 0.04
				cm.height = 0.26
				cm.radial_segments = 4
				cm.rings = 1
				spike.mesh = cm
				spike.material_override = iron
				spike.position = Vector3(-0.3 + 0.3 * float(i % 3), 0.21, -0.3 + 0.3 * float(i / 3))
				n.add_child(spike)
		"net":
			var heap := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.55
			sm.height = 0.3
			sm.radial_segments = 8
			sm.rings = 3
			heap.mesh = sm
			heap.material_override = Look.flat_mat(Color(0.2, 0.3, 0.2), 0.4)
			heap.position.y = 0.06
			n.add_child(heap)
			var cord := Look.flat_mat(Color(0.55, 0.47, 0.3), 1.0)
			for i in 5:
				var strand := Geo.box(n, Vector3(1.1, 0.03, 0.03), Color.WHITE, Vector3(0.0, 0.14, -0.4 + 0.2 * float(i)))
				strand.material_override = cord
				var cross := Geo.box(n, Vector3(0.03, 0.03, 1.1), Color.WHITE, Vector3(-0.4 + 0.2 * float(i), 0.15, 0.0))
				cross.material_override = cord
			for i in 3:
				var a := TAU * float(i) / 3.0 + 0.4
				var float_ball := Geo.sphere(n, 0.08, Color.WHITE, Vector3(sin(a) * 0.5, 0.12, cos(a) * 0.5))
				float_ball.material_override = Look.flat_mat(Color(0.9, 0.45, 0.15), 0.5)
		"chain":
			var plate := Geo.box(n, Vector3(0.95, 0.05, 0.95), Color.WHITE, Vector3(0.0, 0.04, 0.0))
			plate.material_override = Look.flat_mat(Look.RUST, 0.7)
			for i in 10:
				var a := TAU * float(i) / 10.0
				var link := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.04
				tm.outer_radius = 0.07
				tm.rings = 8
				tm.ring_segments = 4
				link.mesh = tm
				link.material_override = iron
				link.position = Vector3(sin(a) * 0.62, 0.06, cos(a) * 0.62)
				link.rotation = Vector3(PI * 0.5 * float(i % 2), a, 0.0)
				n.add_child(link)
		"wire":
			# Coils of barbed wire on a few stakes, in a ring round the cairn.
			var steel := Look.flat_mat(Color(0.32, 0.31, 0.3), 0.5)
			for c in 3:
				var coil := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.33
				tm.outer_radius = 0.36
				tm.rings = 16
				tm.ring_segments = 3
				coil.mesh = tm
				coil.material_override = steel
				var a := TAU * float(c) / 3.0
				coil.position = Vector3(sin(a) * 0.75, 0.34, cos(a) * 0.75)
				coil.rotation = Vector3(PI * 0.5, a + PI * 0.5, 0.0)
				n.add_child(coil)
				Geo.box(n, Vector3(0.05, 0.75, 0.05), Color.WHITE, coil.position + Vector3(0.0, 0.03, 0.0)).material_override = Look.flat_mat(Look.WOOD_PALE)
		"poison":
			# A heap of kelp bait, green with poison, and the empty tin beside it.
			var bait := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.4
			sm.height = 0.22
			sm.radial_segments = 8
			sm.rings = 3
			bait.mesh = sm
			bait.material_override = Look.flat_mat(Color(0.25, 0.42, 0.18), 0.5)
			bait.position.y = 0.05
			n.add_child(bait)
			for i in 7:
				var a := TAU * float(i) / 7.0
				var pellet := Geo.sphere(n, 0.035, Color.WHITE, Vector3(sin(a) * 0.3, 0.14, cos(a) * 0.3))
				pellet.material_override = Look.flat_mat(Color(0.35, 0.75, 0.85), 0.4)
			var tin := Geo.cyl(n, 0.07, 0.14, Color.WHITE, Vector3(0.5, 0.07, 0.25))
			tin.material_override = Look.flat_mat(Color(0.75, 0.15, 0.1), 0.5)
		"tripwire":
			var stake_l := Geo.box(n, Vector3(0.05, 0.3, 0.05), Color.WHITE, Vector3(-0.7, 0.15, 0.0))
			stake_l.material_override = Look.flat_mat(Look.WOOD_PALE)
			var line := Geo.box(n, Vector3(1.3, 0.01, 0.01), Color.WHITE, Vector3(-0.05, 0.22, 0.0))
			line.material_override = Look.flat_mat(Color(0.75, 0.72, 0.6))
			# The flare in its tin, bound to the stake by the rag.
			var tin := Geo.cyl(n, 0.05, 0.28, Color.WHITE, Vector3(0.62, 0.62, -0.08))
			tin.material_override = Look.flat_mat(Color(0.75, 0.2, 0.15), 0.6)
	return n
