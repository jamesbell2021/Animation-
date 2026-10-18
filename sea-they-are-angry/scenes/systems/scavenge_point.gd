class_name ScavengePoint
extends Node3D

const COLORS := {
	"driftwood": Color(0.5, 0.38, 0.22),
	"scrap": Color(0.55, 0.35, 0.25),
	"bio": Color(0.3, 0.9, 0.9),
	"seaweed": Color(0.2, 0.5, 0.3),
}

var kind := "driftwood"
var amount := 1
var available := true
var _mesh: Node3D

func _init(p_kind: String = "driftwood", p_amount: int = 1) -> void:
	kind = p_kind
	amount = p_amount

func _ready() -> void:
	add_to_group("interactable")
	_mesh = Node3D.new()
	add_child(_mesh)
	match kind:
		"driftwood":
			_build_driftwood()
		"scrap":
			_build_scrap()
		"bio":
			_build_bio()
		_:
			Geo.box(_mesh, Vector3(0.9, 0.35, 0.6), COLORS.get(kind, Color.GRAY), Vector3(0.0, 0.175, 0.0))
	rotation.y = randf() * TAU
	Cycle.phase_changed.connect(_on_phase_changed)

func _log(length: float, radius: float, pos: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius * 0.8
	m.bottom_radius = radius
	m.height = length
	m.radial_segments = 6
	m.rings = 1
	mi.mesh = m
	mi.material_override = Look.flat_mat(Look.WOOD_PALE, 0.95)
	mi.position = pos
	mi.rotation = Vector3(0.0, yaw, deg_to_rad(90.0))
	_mesh.add_child(mi)

func _build_driftwood() -> void:
	_log(1.3, 0.13, Vector3(0.0, 0.12, 0.0), 0.0)
	_log(0.9, 0.1, Vector3(0.1, 0.1, 0.25), 0.5)
	_log(0.7, 0.09, Vector3(-0.15, 0.3, 0.08), -0.3)

func _build_scrap() -> void:
	var rust := Look.flat_mat(Look.RUST, 0.8)
	var iron := Look.flat_mat(Color(0.25, 0.26, 0.27), 0.5)
	var crate := Geo.box(_mesh, Vector3(0.55, 0.4, 0.45), Color.WHITE, Vector3(-0.1, 0.2, 0.0))
	crate.material_override = rust
	crate.rotation.y = 0.3
	var plate := Geo.box(_mesh, Vector3(0.7, 0.05, 0.5), Color.WHITE, Vector3(0.25, 0.06, 0.15))
	plate.material_override = iron
	plate.rotation.z = 0.15
	var pipe := Geo.cyl(_mesh, 0.07, 0.8, Color.WHITE, Vector3(0.1, 0.1, -0.3))
	pipe.material_override = iron
	pipe.rotation = Vector3(0.0, 0.8, deg_to_rad(90.0))

func _build_bio() -> void:
	Look.rock(_mesh, 44, Vector3(0.7, 0.35, 0.6), Vector3(0.0, 0.05, 0.0), Look.STONE, 0.3)
	var glow := Look.glow_mat(COLORS["bio"], 3.0)
	for i in 4:
		var a := float(i) * 1.7
		var r := 0.09 + 0.04 * float(i % 2)
		var g := Geo.sphere(_mesh, r, Color.WHITE, Vector3(sin(a) * 0.25, 0.28 + 0.05 * float(i % 2), cos(a) * 0.2))
		g.material_override = glow

func _on_phase_changed(p: int) -> void:
	if p == Cycle.Phase.DAWN:
		available = true
		_mesh.visible = true

func interact_prompt() -> String:
	if available:
		return "[E] Gather %s" % kind
	return ""

func interact(_player: Node) -> bool:
	if not available:
		return false
	available = false
	_mesh.visible = false
	Stock.add(kind, amount)
	Audio.sfx("gather", global_position, -2.0, 0.05)
	Events.message.emit("+%d %s" % [amount, kind])
	return true
