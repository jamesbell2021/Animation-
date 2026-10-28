class_name Block
extends StaticBody3D
## One destructible piece of terrain: a building cube, barrier, crate or tree.
## Blocks only own their collision; their neon boxes are instances in the City's MultiMeshes,
## so the whole city draws in a few dozen calls (important on phones).

var id := -1
var hp := 30.0
var size := Vector3.ONE
var color := Color.WHITE
## Crushable blocks are flattened instantly when the mega tank drives into them.
var crushable := false
## Building cubes live in a column; destroying one collapses everything stacked above.
var column_key := Vector2i.ZERO
var level := -1
## Visual parts: [local offset, size, color, energy, windows]; filled in by City.
var parts: Array = []
## MultiMesh slots of the parts once the city is built: [chunk index, instance index].
var slots: Array = []
var dead := false
## Lit windows (building cubes): they shower glass when broken.
var has_windows := false
## Where the last hit came from, so debris flies away from it.
var last_hit := Vector3.INF


func build(block_size: Vector3, block_color: Color, max_hp: float, energy := 2.2,
		windows := false) -> void:
	size = block_size
	color = block_color
	hp = max_hp
	collision_layer = G.LAYER_TERRAIN
	collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = G.box_shape(block_size)
	add_child(cs)
	has_windows = windows
	add_part(block_size, Vector3.ZERO, block_color, energy, windows)


func add_part(part_size: Vector3, offset: Vector3, part_color: Color, energy := 2.2,
		windows := false) -> void:
	parts.append([offset, part_size, part_color, energy, windows])


func take_damage(amount: float, pos: Vector3, _team: int) -> void:
	if dead or G.is_client():
		return
	last_hit = pos
	hp -= amount
	if hp <= 0.0:
		G.city.destroy_block(self)
	else:
		G.city.flash_block(self, 0.6)


## Direction debris should fly: away from the last hit, flat.
func push_dir() -> Vector3:
	if last_hit == Vector3.INF:
		return Vector3.ZERO
	var d := global_position - last_hit
	d.y = 0.0
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO
