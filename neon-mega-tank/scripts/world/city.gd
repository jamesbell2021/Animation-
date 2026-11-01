class_name City
extends Node3D
## Procedural neon city on a road grid. Buildings are stacks of 2 m cubes, so everything can be
## shot apart; knocking out a cube makes the cubes above it drop and shatter, falling cubes batter
## the cubes next to them, and once half of a building's base is gone the rest of it comes down.
## Generation is seeded so LAN clients build exactly the same city as the host; blocks are
## numbered in creation order so destruction can be replicated by id.

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
## Which building each column belongs to, and per building: its column keys, how many of its
## base cubes are gone, and whether it has already come down.
var _building_of := {}
var _buildings: Array[Dictionary] = []
var blocks: Array[Block] = []
## Ids of destroyed blocks, sent to clients that join mid-round.
var destroyed_ids: Array[int] = []
var rng := RandomNumberGenerator.new()

var _chunks: Array[MultiMesh] = []
var _flashing := {}


func generate(seed_value: int) -> void:
	rng.seed = seed_value
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
	_build_chunks()


## Packs every block part into one MultiMesh per city block (a few dozen draw calls in total).
func _build_chunks() -> void:
	var by_chunk := {}
	for b in blocks:
		var key := Vector2i(floori(b.position.x / PERIOD), floori(b.position.z / PERIOD))
		if not by_chunk.has(key):
			by_chunk[key] = []
		by_chunk[key].append(b)
	var unit := G.box_mesh(Vector3.ONE)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/neon_multi.gdshader")
	for key in by_chunk:
		var list: Array = by_chunk[key]
		var count := 0
		for b: Block in list:
			count += b.parts.size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = unit
		mm.instance_count = count
		var chunk_index := _chunks.size()
		_chunks.append(mm)
		var i := 0
		for b: Block in list:
			for part in b.parts:
				var offset: Vector3 = part[0]
				mm.set_instance_transform(i, Transform3D(Basis.from_scale(part[1]), b.position + offset))
				mm.set_instance_color(i, part[2])
				mm.set_instance_custom_data(i, Color(0.0, 1.0 if part[4] else 0.0, 1.0, part[3]))
				b.slots.append([chunk_index, i])
				i += 1
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func flash_block(b: Block, amount: float) -> void:
	_flashing[b] = amount
	_set_flash(b, amount)


func _set_flash(b: Block, amount: float) -> void:
	for slot in b.slots:
		var mm := _chunks[slot[0]]
		var c := mm.get_instance_custom_data(slot[1])
		c.r = amount
		mm.set_instance_custom_data(slot[1], c)


func _process(delta: float) -> void:
	for b in _flashing.keys():
		if not is_instance_valid(b) or b.dead:
			_flashing.erase(b)
			continue
		var v: float = maxf(0.0, _flashing[b] - delta * 5.0)
		_set_flash(b, v)
		if v <= 0.0:
			_flashing.erase(b)
		else:
			_flashing[b] = v


func _hide(b: Block) -> void:
	for slot in b.slots:
		_chunks[slot[0]].set_instance_transform(slot[1], Transform3D(Basis.from_scale(Vector3.ZERO), b.position))


## Client side: the host destroyed this block.
func destroy_by_id(block_id: int, push := Vector3.ZERO) -> void:
	if block_id < 0 or block_id >= blocks.size():
		return
	var b := blocks[block_id]
	if is_instance_valid(b) and not b.dead:
		b.dead = true
		G.debris(b.global_position, b.color, b.size, push, b.has_windows)
		_hide(b)
		b.queue_free()


## Client side: the host says this building cube lost its support and is falling.
func fall_by_id(block_id: int, push: Vector3) -> void:
	if block_id < 0 or block_id >= blocks.size():
		return
	var b := blocks[block_id]
	if is_instance_valid(b) and not b.dead:
		b.dead = true
		_hide(b)
		if G.debris_field:
			G.debris_field.fall(b.global_position, b.color, b.size, push, false, b.has_windows)
		b.queue_free()


## Client side: hide everything destroyed before we joined, without effects.
func apply_destroyed(ids: Array) -> void:
	for block_id in ids:
		if block_id >= 0 and block_id < blocks.size():
			var b := blocks[block_id]
			if is_instance_valid(b) and not b.dead:
				b.dead = true
				_hide(b)
				b.queue_free()


func destroy_block(b: Block) -> void:
	if b.dead:
		return
	b.dead = true
	var push := b.push_dir()
	G.net_mute += 1
	G.debris(b.global_position, b.color, b.size, push, b.has_windows)
	G.net_mute -= 1
	G.add_score(1)
	_hide(b)
	_replicate_destroy(b, push)
	if b.level >= 0 and columns.has(b.column_key):
		# Everything stacked above drops as whole cubes and shatters where it lands.
		var column: Array = columns[b.column_key]
		var fell := 0
		var top := b.global_position
		for k in range(b.level + 1, column.size()):
			var above: Block = column[k]
			if is_instance_valid(above) and not above.dead:
				fell += 1
				top = above.global_position
				_fall(above, push)
		column.resize(b.level)
		if fell > 0:
			G.sfx("crumble", -2.0)
		if fell >= 2:
			var bonus := fell * 15
			G.add_score(bonus)
			G.add_shake(0.25)
			G.popup(top + Vector3(0, 2.0, 0), ["TOWER DOWN! +%d", bonus], b.color.lerp(Color.WHITE, 0.3), 1.1)
		if b.level == 0:
			_base_lost(b.column_key, push)
	b.queue_free()


## A building lost one of its base cubes. At half its base, the rest gives way: column after
## column drops, nearest to the damage first.
func _base_lost(key: Vector2i, push: Vector3) -> void:
	if not _building_of.has(key):
		return
	var info: Dictionary = _buildings[_building_of[key]]
	info["down"] += 1
	var keys: Array = info["keys"]
	if info["fallen"] or info["down"] * 2 < keys.size():
		return
	info["fallen"] = true
	var cubes := 0
	var top := Vector3.ZERO
	var color := Color.WHITE
	for k: Vector2i in keys:
		var col: Array = columns.get(k, [])
		var live := 0
		for blk in col:
			if is_instance_valid(blk) and not (blk as Block).dead:
				live += 1
				top = (blk as Block).global_position
				color = (blk as Block).color
		if live == 0:
			continue
		cubes += live
		var wait := 0.15 + Vector2(k - key).length() * 0.14
		get_tree().create_timer(wait).timeout.connect(_drop_column.bind(k, push))
	if cubes > 0:
		var bonus := cubes * 10
		G.add_score(bonus)
		G.sfx("crumble", 0.0, 0.7)
		G.popup(top + Vector3(0, 5.5, 0), ["BUILDING DOWN! +%d", bonus], color.lerp(Color.WHITE, 0.4), 1.3)


## Every cube left in a column drops (the base crumbles where it stands).
func _drop_column(key: Vector2i, push: Vector3) -> void:
	var col: Array = columns.get(key, [])
	for blk in col:
		if is_instance_valid(blk) and not (blk as Block).dead:
			_fall(blk, push)
	columns[key] = []
	G.add_shake(0.15)


## A falling cube hit the street: it batters the cubes around where it landed. Host only.
func impact(pos: Vector3, radius: float, damage: float) -> void:
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	q.shape = sphere
	q.transform = Transform3D(Basis(), Vector3(pos.x, 1.0, pos.z))
	q.collision_mask = G.LAYER_TERRAIN
	for hit in get_world_3d().direct_space_state.intersect_shape(q, 32):
		var blk := hit["collider"] as Block
		if blk and not blk.dead:
			blk.take_damage(damage, pos, G.Team.PLAYER)


## A cube whose support is gone: it falls as one piece (DebrisField) and breaks on the street.
func _fall(b: Block, push: Vector3) -> void:
	b.dead = true
	_hide(b)
	if G.debris_field:
		G.debris_field.fall(b.global_position, b.color, b.size, push, true, b.has_windows)
	Net.send_event("fall", [b.id, push], true)
	G.add_score(1)
	_replicate_destroy(b, Vector3.ZERO)
	b.queue_free()


func _replicate_destroy(b: Block, push: Vector3) -> void:
	destroyed_ids.append(b.id)
	Net.send_event("block", [b.id, push], true)


func _make_block(block_size: Vector3, pos: Vector3, color: Color, max_hp: float,
		crushable: bool, windows := false, energy := 2.2) -> Block:
	var b := Block.new()
	b.build(block_size, color, max_hp, energy, windows)
	b.crushable = crushable
	b.position = pos
	_register(b)
	return b


func _register(b: Block) -> void:
	b.id = blocks.size()
	blocks.append(b)
	add_child(b)


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
		var bid := _buildings.size()
		_buildings.append({"keys": [], "down": 0, "fallen": false})
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
				_building_of[key] = bid
				_buildings[bid]["keys"].append(key)
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
	b.add_part(Vector3(1.5, 1.2, 1.5), Vector3(0, 1.0, 0), TREE_COLOR, 2.4)
	b.crushable = true
	b.position = ground_pos + Vector3(0, 1.3, 0)
	_register(b)


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
