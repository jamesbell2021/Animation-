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
var _mesh: MeshInstance3D

func _init(p_kind: String = "driftwood", p_amount: int = 1) -> void:
	kind = p_kind
	amount = p_amount

func _ready() -> void:
	add_to_group("interactable")
	_mesh = Geo.box(self, Vector3(0.9, 0.35, 0.6), COLORS.get(kind, Color.GRAY), Vector3(0.0, 0.175, 0.0))
	if kind == "bio":
		_mesh.material_override = Geo.mat(COLORS["bio"], true)
	rotation.y = randf() * TAU
	Cycle.phase_changed.connect(_on_phase_changed)

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
	Events.message.emit("+%d %s" % [amount, kind])
	return true
