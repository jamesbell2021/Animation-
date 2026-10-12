class_name Block
extends StaticBody3D
## One destructible piece of terrain: a building cube, barrier, crate or tree.

var hp := 30.0
var size := Vector3.ONE
var color := Color.WHITE
## Crushable blocks are flattened instantly when the mega tank drives into them.
var crushable := false
## Building cubes live in a column; destroying one collapses everything stacked above.
var column_key := Vector2i.ZERO
var level := -1
var meshes: Array[MeshInstance3D] = []
var dead := false


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
	add_mesh(block_size, Vector3.ZERO, block_color, energy, windows)


func add_mesh(mesh_size: Vector3, offset: Vector3, mesh_color: Color, energy := 2.2,
		windows := false) -> MeshInstance3D:
	var m := G.neon_box(self, mesh_size, offset, mesh_color, energy, windows)
	m.set_instance_shader_parameter("fadeable", 1.0)
	meshes.append(m)
	return m


func take_damage(amount: float, _pos: Vector3, _team: int) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		G.city.destroy_block(self)
	else:
		G.flash(meshes, 0.6)
