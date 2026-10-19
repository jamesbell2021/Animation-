class_name TrapSlot
extends Node3D
## A marked spot on a creature path (a little cairn) where the keepers can set a trap.
## Three on the beaches to start; defences upgrades open one on the ledge and one at
## its foot. A set trap springs on the first creature to step on it, and is spent
## after a few. A Crab's slam smashes any trap in front of it.

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
}
const IRON := Color(0.2, 0.2, 0.22)

var index := 0
var unlocked := true
var kind := ""
var uses := 0
var _cairn: Node3D
var _trap: Node3D
var _cd := 0.0
var _caught := {}

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
	if kind != "":
		return "%s set  (%d left)" % [TRAPS[kind]["name"], uses]
	return "[E] Set a trap"

func interact(player: Node) -> bool:
	if not unlocked or kind != "" or not (player is Player):
		return false
	ChoiceMenu.open(player, "Set a trap", menu_rows)
	return true

func menu_rows() -> Array:
	var rows := []
	for k in TRAPS:
		var t: Dictionary = TRAPS[k]
		rows.append({"text": "%s (%s, %d uses): %s" % [t["name"], Stock.cost_str(t["cost"]), t["uses"], t["blurb"]],
			"enabled": Stock.can_afford(t["cost"]), "do": arm.bind(k)})
	return rows

## Set a trap of this kind, paying for it. Returns false so the menu closes.
func arm(k: String) -> bool:
	if kind != "" or not Stock.spend(TRAPS[k]["cost"]):
		return false
	kind = k
	uses = int(TRAPS[k]["uses"])
	_caught.clear()
	_refresh()
	Audio.sfx("hammer", global_position, -4.0, 0.1)
	Events.message.emit("%s set." % TRAPS[k]["name"])
	return false

## Smashed (a Crab's slam): the trap is gone.
func wreck() -> void:
	if kind == "":
		return
	FX.splinters(get_parent(), global_position + Vector3(0.0, 0.3, 0.0))
	_spend_all()

func _spend_all() -> void:
	kind = ""
	uses = 0
	_refresh()

# ---- springing ----

func _physics_process(delta: float) -> void:
	if not is_armed():
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
				e.stagger(CHAIN_TIME * mult)
				e.exposed_t = CHAIN_EXPOSED
			else:
				e.stagger(OTHER_STAGGER)
			FX.sparks(get_parent(), at)
	Audio.sfx("trap_snap", global_position, 0.0, 0.1)
	if _trap != null:
		var tw := create_tween()
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
	return n
