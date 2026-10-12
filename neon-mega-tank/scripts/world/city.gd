class_name City
extends Node3D
## Procedural neon city on a road grid. Buildings are stacks of 2 m cubes, so everything can be
## shot apart; knocking out a cube makes the cubes above it collapse.

const CELL := 2.0
const PERIOD := 24.0
const ROAD := 8.0
const HALF := 72.0
const BLOCK_CELLS := 8
const BUILDING_HP := 32.0
const PALETTE: Array[Color] = [
	Color(0.2, 1.0, 0.45), Color(1.0, 0.25, 0.8), Color(1.0, 0.85, 0.2),
	Color(0.2, 0.75, 1.0), Color(0.55, 0.4, 1.0), Color(0.3, 1.0, 0.9)]
const BARRIER_COLOR := Color(0.35, 0.6, 1.0)
const CRATE_COLOR := Color(1.0, 0.7, 0.15)
const TREE_COLOR := Color(0.3, 1.0, 0.5)

var columns := {}
var rng := RandomNumberGenerator.new()


func generate() -> void:
	rng.randomize()
	_build_ground()
	_build_boundary()
	for bx in range(-3, 3):
		for bz in range(-3, 3):
			var ox := bx * PERIOD + ROAD * 0.5
			var oz := bz * PERIOD + ROAD * 0.5
			var start_area := bx >= -1 and bx <= 0 and bz >= -1 and bz <= 0
			if start_area or rng.randf() < 0.18:
				_gen_park(ox, oz, start_area)
			else:
				_gen_buildings(ox, oz)
				_gen_sidewalk_barriers(ox, oz)
	_gen_roadblocks()


func destroy_block(b: Block) -> void:
	if b.dead:
		return
	b.dead = true
	G.debris(b.global_position, b.color, b.size)
	G.add_score(1)
	if b.level >= 0 and columns.has(b.column_key):
		var column: Array = columns[b.column_key]
		var delay := 0.0
		for k in range(b.level + 1, column.size()):
			var above: Block = column[k]
			if is_instance_valid(above) and not above.dead:
				above.dead = true
				delay += 0.09
				get_tree().create_timer(delay).timeout.connect(_collapse.bind(above))
		column.resize(b.level)
		if delay > 0.0:
			G.sfx("crumble", -2.0)
	b.queue_free()


func _collapse(b: Block) -> void:
	if not is_instance_valid(b):
		return
	G.debris(b.global_position, b.color, b.size)
	G.add_shake(0.05)
	G.add_score(1)
	b.queue_free()


func _make_block(block_size: Vector3, pos: Vector3, color: Color, max_hp: float,
		crushable: bool, windows := false, energy := 2.2) -> Block:
	var b := Block.new()
	b.build(block_size, color, max_hp, energy, windows)
	b.crushable = crushable
	b.position = pos
	add_child(b)
	return b


func _gen_buildings(ox: float, oz: float) -> void:
	var used := {}
	var placed := 0
	var wanted := rng.randi_range(2, 4)
	for attempt in 40:
		if placed >= wanted:
			break
		var w := rng.randi_range(2, 4)
		var d := rng.randi_range(2, 4)
		var cx := rng.randi_range(0, BLOCK_CELLS - w)
		var cz := rng.randi_range(0, BLOCK_CELLS - d)
		if _area_used(used, cx - 1, cz - 1, w + 2, d + 2):
			continue
		var h := rng.randi_range(1, 3) + (rng.randi_range(1, 3) if rng.randf() < 0.35 else 0)
		var color: Color = PALETTE[rng.randi() % PALETTE.size()]
		for i in w:
			for j in d:
				used[Vector2i(cx + i, cz + j)] = true
				var wx := ox + (cx + i + 0.5) * CELL
				var wz := oz + (cz + j + 0.5) * CELL
				var key := Vector2i(floori(wx / CELL), floori(wz / CELL))
				var column: Array = []
				for k in h:
					var b := _make_block(Vector3.ONE * CELL, Vector3(wx, (k + 0.5) * CELL, wz),
							color, BUILDING_HP, false, true)
					b.column_key = key
					b.level = k
					column.append(b)
				columns[key] = column
		placed += 1


func _area_used(used: Dictionary, x: int, z: int, w: int, d: int) -> bool:
	for i in range(x, x + w):
		for j in range(z, z + d):
			if used.has(Vector2i(i, j)):
				return true
	return false


func _gen_park(ox: float, oz: float, start_area: bool) -> void:
	var skip := 0.55 if start_area else 0.35
	for side in 4:
		for i in BLOCK_CELLS:
			if rng.randf() < skip:
				continue
			_place_barrier(ox, oz, side, i)
	var span := BLOCK_CELLS * CELL
	for i in rng.randi_range(3, 6):
		var p := Vector3(ox + rng.randf_range(2.0, span - 2.0), 0.0, oz + rng.randf_range(2.0, span - 2.0))
		_make_tree(p)
	for i in rng.randi_range(2, 6):
		var p := Vector3(ox + rng.randf_range(1.5, span - 1.5), 0.5, oz + rng.randf_range(1.5, span - 1.5))
		_make_block(Vector3.ONE, p, CRATE_COLOR, 8.0, true)
		if rng.randf() < 0.3:
			_make_block(Vector3.ONE * 0.9, p + Vector3(0, 0.95, 0), CRATE_COLOR, 8.0, true)


func _gen_sidewalk_barriers(ox: float, oz: float) -> void:
	for side in 4:
		if rng.randf() > 0.35:
			continue
		var start := rng.randi_range(0, BLOCK_CELLS - 3)
		for i in range(start, start + rng.randi_range(2, 4)):
			_place_barrier(ox, oz, side, mini(i, BLOCK_CELLS - 1))


## A low jersey barrier along one edge of a city block.
func _place_barrier(ox: float, oz: float, side: int, i: int) -> void:
	var span := BLOCK_CELLS * CELL
	var along := (i + 0.5) * CELL
	var pos: Vector3
	var bsize: Vector3
	match side:
		0:
			pos = Vector3(ox + along, 0.4, oz + 0.4)
			bsize = Vector3(CELL * 0.92, 0.8, 0.5)
		1:
			pos = Vector3(ox + along, 0.4, oz + span - 0.4)
			bsize = Vector3(CELL * 0.92, 0.8, 0.5)
		2:
			pos = Vector3(ox + 0.4, 0.4, oz + along)
			bsize = Vector3(0.5, 0.8, CELL * 0.92)
		_:
			pos = Vector3(ox + span - 0.4, 0.4, oz + along)
			bsize = Vector3(0.5, 0.8, CELL * 0.92)
	_make_block(bsize, pos, BARRIER_COLOR, 14.0, true, false, 1.8)


func _make_tree(ground_pos: Vector3) -> void:
	var b := Block.new()
	b.build(Vector3(0.6, 2.6, 0.6), TREE_COLOR.darkened(0.3), 8.0, 1.6)
	b.add_mesh(Vector3(1.5, 1.2, 1.5), Vector3(0, 1.0, 0), TREE_COLOR, 2.4)
	b.crushable = true
	b.position = ground_pos + Vector3(0, 1.3, 0)
	add_child(b)


## Barricades across the streets: cover for enemy infantry, speed bumps for the mega tank.
func _gen_roadblocks() -> void:
	for n in 14:
		var k := rng.randi_range(-3, 3)
		var along := rng.randf_range(-HALF + 6.0, HALF - 6.0)
		var vertical_road := rng.randf() < 0.5
		var center := Vector3(k * PERIOD, 0.4, along) if vertical_road else Vector3(along, 0.4, k * PERIOD)
		if center.length() < 30.0 or absf(center.x) > HALF - 4.0 or absf(center.z) > HALF - 4.0:
			continue
		for i in range(-1, 2):
			if rng.randf() < 0.2:
				continue
			var offset := Vector3(i * 2.1, 0, 0) if vertical_road else Vector3(0, 0, i * 2.1)
			var bsize := Vector3(1.9, 0.8, 0.5) if vertical_road else Vector3(0.5, 0.8, 1.9)
			_make_block(bsize, center + offset, BARRIER_COLOR, 14.0, true, false, 1.8)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (HALF * 2.0 + 120.0)
	ground.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	mat.set_shader_parameter("half_size", HALF)
	mat.set_shader_parameter("period", PERIOD)
	mat.set_shader_parameter("road", ROAD)
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


## Invisible walls at the edge of the map with a neon fence on top.
func _build_boundary() -> void:
	var fence := Color(1.0, 0.2, 0.6)
	for i in 4:
		var horizontal := i < 2
		var s := 1.0 if i % 2 == 0 else -1.0
		var wall := StaticBody3D.new()
		wall.collision_layer = G.LAYER_TERRAIN
		wall.collision_mask = 0
		var cs := CollisionShape3D.new()
		var length := HALF * 2.0 + 4.0
		cs.shape = G.box_shape(Vector3(length, 6, 2) if horizontal else Vector3(2, 6, length))
		wall.add_child(cs)
		wall.position = Vector3(0, 3, s * (HALF + 1.0)) if horizontal else Vector3(s * (HALF + 1.0), 3, 0)
		add_child(wall)
		var rail := Vector3(HALF * 2.0, 0.12, 0.12) if horizontal else Vector3(0.12, 0.12, HALF * 2.0)
		var edge := Vector3(0, 0, s * HALF) if horizontal else Vector3(s * HALF, 0, 0)
		G.neon_box(self, rail, edge + Vector3(0, 1.6, 0), fence, 3.0)
		G.neon_box(self, rail, edge + Vector3(0, 0.8, 0), fence, 1.5)
		for p in range(-9, 10):
			var at := Vector3(p * 8.0, 0.9, 0) if horizontal else Vector3(0, 0.9, p * 8.0)
			G.neon_box(self, Vector3(0.25, 1.8, 0.25), edge + at, fence, 2.0)
