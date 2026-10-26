class_name CampWire
extends Structure
## A run of the camp's barbed-wire fence between two posts (or a post and the gate):
## Camp strings the wire; this is its body and its health. Creatures that come up the
## holm's beaches at it have to tear through, which holds them under the searchlights.
## Torn down, the gap stands open until a keeper mends it with scrap.

const THICK := 0.25

var length := 4.0
var height := 2.3
## The strands Camp strung for this run: they go when it's down.
var strands: Array[Node3D] = []
var _shape: CollisionShape3D

func _init(p_length: float = 4.0, p_height: float = 2.3) -> void:
	length = p_length
	height = p_height
	id = "wire"
	max_hp = 120

func _ready() -> void:
	super._ready()
	add_to_group("camp")
	add_to_group("camp_wire")
	add_to_group("barricades")

func _build() -> void:
	_shape = Geo.box_shape(self, Vector3(length, height, THICK), Vector3(0.0, height * 0.5, 0.0))

func _refresh() -> void:
	if _shape == null:
		return
	var standing := hp > 0
	var r := health_ratio()
	for i in strands.size():
		if is_instance_valid(strands[i]):
			# Strands part one by one as it's torn, the lowest last.
			strands[i].visible = standing and (r > 0.55 or i < int(ceil(strands.size() * r / 0.55)))
	_shape.set_deferred("disabled", not standing)

func _on_damaged() -> void:
	if is_inside_tree():
		FX.sparks(get_parent(), global_position + Vector3(0.0, 1.0, 0.0))
		Audio.sfx("hit", global_position, -8.0, 0.2)

func smoke_point() -> Vector3:
	return Vector3.INF

func repair_cost() -> Dictionary:
	return {"scrap": 1}

func repair_amount() -> int:
	return 60

func display_name() -> String:
	return "the wire"

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - length * 0.5)
	var dz := maxf(0.0, absf(local.z) - THICK * 0.5)
	return Vector2(dx, dz).length()

## Where a keeper stands to mend it: just inside the wire.
func work_point() -> Vector3:
	var c := Terrain.CAMP_C
	var inward := Vector3(c.x - global_position.x, 0.0, c.y - global_position.z)
	var n := global_transform.basis.z
	n.y = 0.0
	n = n.normalized()
	if n.dot(inward) < 0.0:
		n = -n
	return global_position + n * 0.9
