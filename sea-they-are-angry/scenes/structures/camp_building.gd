class_name CampBuilding
extends Structure
## One of the camp's buildings as something creatures can wreck and keepers mend: the
## quarters hut, the mess hut, the greenhouse. Camp draws them; this is their body and
## their health. Wrecked, what's in them stops working (the stove, the mess table and
## the research desk, the greenhouse's staging) until it's mended.

## The box it fills, in its own space, sat on the ground.
var size := Vector3(4.0, 3.0, 4.0)
## What it looks like: sags and darkens as it's wrecked.
var visual: Node3D
## Parts that go when it's wrecked (the greenhouse's glass).
var breakable: Array[Node3D] = []
var _tints: Array[StandardMaterial3D] = []

func _init(p_id: String = "", p_hp: int = 220, p_size: Vector3 = Vector3(4.0, 3.0, 4.0)) -> void:
	id = p_id
	max_hp = p_hp
	size = p_size

func _ready() -> void:
	super._ready()
	add_to_group("camp")

func _build() -> void:
	Geo.box_shape(self, size, Vector3(0.0, size.y * 0.5, 0.0))

func _refresh() -> void:
	var standing := hp > 0
	for b in breakable:
		if is_instance_valid(b):
			b.visible = standing
	if visual != null:
		# Battered: it settles and leans; wrecked, it's a ruin.
		var r := health_ratio()
		visual.rotation.z = 0.0 if r > 0.6 else (0.6 - r) * 0.12
		visual.scale.y = 1.0 if standing else 0.72

func smoke_point() -> Vector3:
	return Vector3(0.0, size.y * 0.9, 0.0)

# Timber and tin patched with driftwood: scrap is scarce, and the wire wants it.
func repair_cost() -> Dictionary:
	return {"driftwood": 2}

func repair_amount() -> int:
	return 60

func display_name() -> String:
	return {"quarters": "the quarters", "mess": "the mess hut", "greenhouse": "the greenhouse"}.get(id, id)

func surface_distance(p: Vector3) -> float:
	var local := to_local(p)
	var dx := maxf(0.0, absf(local.x) - size.x * 0.5)
	var dz := maxf(0.0, absf(local.z) - size.z * 0.5)
	return Vector2(dx, dz).length()

## Where a keeper stands to mend it: in front of it, facing the parade ground.
func work_point() -> Vector3:
	var c := Terrain.CAMP_C
	var toward := Vector3(c.x, global_position.y, c.y) - global_position
	toward.y = 0.0
	var local := to_local(global_position + toward.normalized())
	var out := Vector3(0.0, 0.0, signf(local.z) if absf(local.z) > 0.01 else 1.0)
	return to_global(out * (size.z * 0.5 + 0.7))
