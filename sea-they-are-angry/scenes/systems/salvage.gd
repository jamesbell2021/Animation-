class_name Salvage
extends Node3D
## What a creature leaves where it falls: a lump of glowing bio, a twist of scrap, a hank
## of kelp. It bobs and glints so it can be found at night; a keeper who walks over it
## picks it up (it drifts to anyone close), and the sea takes back whatever's left at the
## next dusk. Anything that drops in the water washes up on the nearest shore.
## The host's; on the LAN clients see copies (Net) that pick nothing up.

const PICK := 1.1
const DRIFT := 2.4
const DRIFT_SPEED := 3.0
const LOOKS := {
	"bio": Color(0.35, 1.0, 0.85), "scrap": Color(0.55, 0.56, 0.58), "seaweed": Color(0.2, 0.5, 0.18),
	"driftwood": Color(0.5, 0.38, 0.25),
}

var kind := "bio"
var amount := 1
var puppet := false
var _t := 0.0
var _model: Node3D
var _base_y := 0.0

## Drop `amount` of `kind` at `at` (host only): on firm ground, ashore if it fell in the sea.
static func drop(parent: Node, at: Vector3, p_kind: String, p_amount: int = 1) -> Salvage:
	if Net.is_client() or parent == null:
		return null
	var s := Salvage.new()
	s.kind = p_kind
	s.amount = p_amount
	var p := ashore(at)
	s.position = p + Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	s.position.y = Terrain.height_at(s.position.x, s.position.z)
	parent.add_child(s)
	return s

## The nearest firm ground to `at`: itself, or up the shore toward the middle of its island.
static func ashore(at: Vector3) -> Vector3:
	if Terrain.walkable(at.x, at.z):
		return Vector3(at.x, Terrain.height_at(at.x, at.z), at.z)
	var mid := Vector3.ZERO
	match Terrain.island_of(at.x, at.z):
		1:
			mid = Vector3(Terrain.HOLM_C.x, 0.0, Terrain.HOLM_C.y)
		2:
			mid = Vector3(Terrain.ISLET_C.x, 0.0, Terrain.ISLET_C.y)
	var dir := mid - at
	dir.y = 0.0
	var d := dir.length()
	dir = dir / maxf(d, 0.01)
	var s := 0.0
	while s < d:
		var p := at + dir * s
		if Terrain.walkable(p.x, p.z):
			return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z) + dir * 0.6
		s += 0.3
	return Vector3(at.x, Terrain.height_at(at.x, at.z), at.z)

func _ready() -> void:
	add_to_group("salvage")
	_base_y = position.y
	_t = randf() * TAU
	_build()
	Cycle.phase_changed.connect(_on_phase)

func _on_phase(p: int) -> void:
	if p == Cycle.Phase.DUSK and not puppet:
		queue_free()

func _process(delta: float) -> void:
	_t += delta
	_model.position.y = 0.25 + sin(_t * 2.2) * 0.07
	_model.rotation.y += delta * 1.2
	if puppet or not Run.active:
		return
	# Drift to the nearest keeper close by, and into their hands.
	var best: Node3D = null
	var best_d := DRIFT
	for k in get_tree().get_nodes_in_group("player"):
		if not (k is Player) or k.downed or k.riding != null or not k.visible:
			continue
		var d := Geo.flat_dist(k.global_position, global_position)
		if d < best_d and absf(k.global_position.y - global_position.y) < 1.6:
			best = k
			best_d = d
	if best == null:
		return
	if best_d < PICK:
		_take(best)
		return
	var to := best.global_position - global_position
	to.y = 0.0
	global_position += to.normalized() * minf(DRIFT_SPEED * delta, to.length())
	global_position.y = Terrain.height_at(global_position.x, global_position.z)

func _take(k: Node) -> void:
	Stock.add(kind, amount)
	var words := {"bio": "bio", "scrap": "scrap", "seaweed": "kelp", "driftwood": "driftwood"}
	Events.message.emit("+%d %s" % [amount, words.get(kind, kind)])
	Audio.sfx("gather", global_position, -6.0, 0.15)
	if kind == "scrap":
		FX.sparks(get_parent(), global_position + Vector3(0.0, 0.3, 0.0))
	queue_free()

func _build() -> void:
	_model = Node3D.new()
	add_child(_model)
	var col: Color = LOOKS.get(kind, Color.WHITE)
	match kind:
		"bio":
			var glow := StandardMaterial3D.new()
			glow.albedo_color = col
			glow.emission_enabled = true
			glow.emission = col
			glow.emission_energy_multiplier = 2.5
			var m := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.13
			sph.height = 0.22
			m.mesh = sph
			m.material_override = glow
			_model.add_child(m)
			var light := OmniLight3D.new()
			light.light_color = col
			light.light_energy = 0.6
			light.omni_range = 1.8
			_model.add_child(light)
		"scrap":
			for i in 3:
				var b := Geo.box(_model, Vector3(0.22, 0.05, 0.12), col, Vector3(randf_range(-0.06, 0.06), 0.03 * float(i), randf_range(-0.06, 0.06)))
				b.material_override = Look.flat_mat(col.darkened(0.1 * float(i)), 0.5)
				(b.material_override as StandardMaterial3D).metallic = 0.6
				b.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		_:
			for i in 4:
				var b := Geo.box(_model, Vector3(0.05, 0.05, 0.32), col, Vector3(0.0, 0.02 * float(i), 0.0))
				b.material_override = Look.flat_mat(col.lightened(0.05 * float(i)), 0.9)
				b.rotation.y = float(i) * 0.8
	Look.glint(_model, Vector3(0.0, 0.25, 0.0), col.lightened(0.4), 0.3)
