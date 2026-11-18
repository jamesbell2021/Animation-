extends SceneTree
## Builds the Godot resources from the generated PNG sheets:
##   tilesets/christmas_tileset.tres  (terrains, collisions, custom data, animations)
##   tilesets/pickup_frames.tres, tilesets/elf_frames.tres  (SpriteFrames)
##   scenes/pickup.tscn, scenes/player.tscn, scenes/demo_level.tscn
##
## Run after the Python generators (images must be imported first):
##   godot --headless --editor --quit --path christmas-platformer-kit
##   godot --headless --path christmas-platformer-kit --script res://tools/build_godot.gd

const T := 64
const TERRAINS := [
	["snow_ground", "Snowy Ground", Color(0.55, 0.38, 0.28)],
	["ice", "Ice", Color(0.55, 0.85, 0.95)],
	["gingerbread", "Gingerbread", Color(0.8, 0.5, 0.25)],
	["snow_brick", "Snowy Brick", Color(0.65, 0.25, 0.23)],
]
const PLATFORM_TERRAINS := [["plank", "Wood Plank", Color(0.6, 0.42, 0.25)],
	["candy", "Candy Cane", Color(0.9, 0.25, 0.25)], ["ice_slab", "Ice Slab", Color(0.6, 0.9, 1.0)]]
const SRC_PLATFORMS := 4
const SRC_DECOR := 5
# Bit -> Godot neighbour, matching tools/terrain.py
const BITS := {1: TileSet.CELL_NEIGHBOR_TOP_SIDE, 2: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	4: TileSet.CELL_NEIGHBOR_RIGHT_SIDE, 8: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	16: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, 32: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	64: TileSet.CELL_NEIGHBOR_LEFT_SIDE, 128: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER}
const CUSTOM := [["hazard", TYPE_BOOL], ["slippery", TYPE_BOOL], ["bounce", TYPE_FLOAT],
	["climbable", TYPE_BOOL], ["crumble", TYPE_BOOL], ["hit_block", TYPE_BOOL], ["goal", TYPE_BOOL]]

const L_WORLD := 1     # physics layer 1: things you stand on
const L_HAZARD := 2    # physics layer 2: things that hurt
const L_PLAYER := 4    # physics layer 3: the player (pickups look for this)

var terrain_meta: Dictionary
var props_meta: Dictionary


func _init() -> void:
	terrain_meta = _json("res://tools/terrain_meta.json")
	props_meta = _json("res://tools/props_meta.json")
	var ts := build_tileset()
	_save(ts, "res://tilesets/christmas_tileset.tres")
	ts = load("res://tilesets/christmas_tileset.tres")
	var pickup_frames := build_pickup_frames()
	_save(pickup_frames, "res://tilesets/pickup_frames.tres")
	var elf_frames := build_elf_frames()
	_save(elf_frames, "res://tilesets/elf_frames.tres")
	_save_scene(build_pickup_scene(load("res://tilesets/pickup_frames.tres")), "res://scenes/pickup.tscn")
	_save_scene(build_player_scene(load("res://tilesets/elf_frames.tres")), "res://scenes/player.tscn")
	_save_scene(build_level(ts), "res://scenes/demo_level.tscn")
	print("Godot resources built.")
	quit()


# ================================================================ TILESET
func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, L_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, L_HAZARD)
	ts.set_physics_layer_collision_mask(1, 0)
	for c in CUSTOM:
		var i := ts.get_custom_data_layers_count()
		ts.add_custom_data_layer()
		ts.set_custom_data_layer_name(i, c[0])
		ts.set_custom_data_layer_type(i, c[1])

	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	for i in TERRAINS.size():
		ts.add_terrain(0)
		ts.set_terrain_name(0, i, TERRAINS[i][1])
		ts.set_terrain_color(0, i, TERRAINS[i][2])
	ts.add_terrain_set()
	ts.set_terrain_set_mode(1, TileSet.TERRAIN_MODE_MATCH_SIDES)
	for i in PLATFORM_TERRAINS.size():
		ts.add_terrain(1)
		ts.set_terrain_name(1, i, PLATFORM_TERRAINS[i][1])
		ts.set_terrain_color(1, i, PLATFORM_TERRAINS[i][2])

	# Terrain sources 0..3
	for i in TERRAINS.size():
		var key: String = TERRAINS[i][0]
		var src := _atlas("res://tiles/terrain_%s.png" % key)
		src.resource_name = TERRAINS[i][1]
		ts.add_source(src, i)
		for t in terrain_meta[key]["tiles"]:
			var coords := Vector2i(int(t["col"]), int(t["row"]))
			src.create_tile(coords)
			var td := src.get_tile_data(coords, 0)
			td.terrain_set = 0
			td.terrain = i
			var mask := int(t["mask"])
			for bit in BITS:
				if mask & bit:
					td.set_terrain_peering_bit(BITS[bit], i)
			if t.has("probability"):
				td.probability = float(t["probability"])
			_poly(td, 0, _rect(-32, -32, 32, 32))
			if terrain_meta[key]["slippery"]:
				td.set_custom_data("slippery", true)

	# Platforms & hazards: source 4
	var ps := _atlas("res://tiles/platforms_hazards.png")
	ps.resource_name = "Platforms & Hazards"
	ts.add_source(ps, SRC_PLATFORMS)
	var plat: Dictionary = props_meta["platforms"]
	for name in plat:
		var info: Dictionary = plat[name]
		var coords := Vector2i(int(info["col"]), int(info["row"]))
		ps.create_tile(coords)
		var td := ps.get_tile_data(coords, 0)
		match info.get("collide", ""):
			"full":
				_poly(td, 0, _rect(-32, -32, 32, 32))
			"spring":
				_poly(td, 0, _rect(-26, -8, 26, 32))
			"oneway":
				var x0 := -28 if name.ends_with("_L") or name.ends_with("_single") else -32
				var x1 := 28 if name.ends_with("_R") or name.ends_with("_single") else 32
				_poly(td, 0, _rect(x0, -32, x1, -16))
				td.set_collision_polygon_one_way(0, 0, true)
				_platform_terrain(td, name)
		for flag in ["hazard", "slippery", "climbable", "crumble", "hit_block"]:
			if info.get(flag, false):
				td.set_custom_data(flag, true)
		if info.has("bounce"):
			td.set_custom_data("bounce", float(info["bounce"]))
		# Hazard shapes only cover the dangerous part of the picture.
		match name:
			"spikes_up": _poly(td, 1, _rect(-28, 6, 28, 32))
			"icicles_down": _poly(td, 1, _rect(-28, -32, 28, -8))
			"spikes_left": _poly(td, 1, _rect(6, -28, 32, 28))
			"spikes_right": _poly(td, 1, _rect(-32, -28, -6, 28))
			"water_top": _poly(td, 1, _rect(-32, -4, 32, 32))
			"water_deep": _poly(td, 1, _rect(-32, -32, 32, 32))
		if info.has("frames"):
			_animate(ps, coords, int(info["frames"]), float(info["fps"]))

	# Decorations: source 5 (no collision). Big pieces are anchored bottom-left,
	# so the cell you click is where the object's base stands.
	var ds := _atlas("res://tiles/decorations.png")
	ds.resource_name = "Decorations"
	ts.add_source(ds, SRC_DECOR)
	var deco: Dictionary = props_meta["decorations"]
	for name in deco:
		var info: Dictionary = deco[name]
		var coords := Vector2i(int(info["col"]), int(info["row"]))
		var size := Vector2i(int(info["w"]), int(info["h"]))
		ds.create_tile(coords, size)
		var td := ds.get_tile_data(coords, 0)
		td.texture_origin = Vector2i(-(size.x - 1) * T / 2, (size.y - 1) * T / 2)
		if info.get("goal", false):
			td.set_custom_data("goal", true)
		if info.has("frames"):
			_animate(ds, coords, int(info["frames"]), float(info["fps"]))
	return ts


func _platform_terrain(td: TileData, name: String) -> void:
	var kinds := ["plank", "candy", "ice_slab"]
	for i in kinds.size():
		if name.begins_with(kinds[i] + "_"):
			td.terrain_set = 1
			td.terrain = i
			if name.ends_with("_L") or name.ends_with("_M"):
				td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, i)
			if name.ends_with("_R") or name.ends_with("_M"):
				td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, i)


func _atlas(path: String) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = load(path)
	src.texture_region_size = Vector2i(T, T)
	return src


func _animate(src: TileSetAtlasSource, coords: Vector2i, frames: int, fps: float) -> void:
	src.set_tile_animation_frames_count(coords, frames)
	for f in frames:
		src.set_tile_animation_frame_duration(coords, f, 1.0 / fps)


func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


func _poly(td: TileData, layer: int, pts: PackedVector2Array) -> void:
	td.add_collision_polygon(layer)
	td.set_collision_polygon_points(layer, td.get_collision_polygons_count(layer) - 1, pts)


# ================================================================ SPRITEFRAMES
func build_pickup_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex: Texture2D = load("res://tiles/pickups.png")
	for item in props_meta["pickups"]:
		var anim: String = item["name"]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(item["fps"]))
		sf.set_animation_loop(anim, bool(item["loop"]))
		for f in int(item["frames"]):
			sf.add_frame(anim, _region(tex, f * T, int(item["row"]) * T))
	return sf


func build_elf_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex: Texture2D = load("res://tiles/player_elf.png")
	for a in props_meta["player"]:
		var anim: String = a["name"]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(a["fps"]))
		sf.set_animation_loop(anim, bool(a["loop"]))
		for f in int(a["frames"]):
			sf.add_frame(anim, _region(tex, (int(a["start"]) + f) * T, 0))
	return sf


func _region(tex: Texture2D, x: int, y: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(x, y, T, T)
	return at


# ================================================================ SCENES
func build_pickup_scene(frames: SpriteFrames) -> Node:
	var root := Area2D.new()
	root.name = "Pickup"
	root.collision_layer = 0
	root.collision_mask = L_PLAYER
	root.set_script(load("res://scripts/pickup.gd"))
	root.add_to_group("pickups", true)
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = frames
	spr.animation = "star"
	_add(root, spr)
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var circle := CircleShape2D.new()
	circle.radius = 20
	shape.shape = circle
	_add(root, shape)
	return root


func build_player_scene(frames: SpriteFrames) -> Node:
	var root := CharacterBody2D.new()
	root.name = "Player"
	root.collision_layer = L_PLAYER
	root.collision_mask = L_WORLD
	root.floor_snap_length = 8.0
	root.set_script(load("res://scripts/player.gd"))
	var spr := AnimatedSprite2D.new()
	spr.name = "Sprite"
	spr.sprite_frames = frames
	spr.animation = "idle"
	spr.autoplay = "idle"
	_add(root, spr)
	var body := CollisionShape2D.new()
	body.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 54)
	body.shape = rect
	body.position = Vector2(0, 2)
	_add(root, body)
	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 0
	hurt.collision_mask = L_HAZARD
	_add(root, hurt)
	var hs := CollisionShape2D.new()
	hs.name = "Shape"
	var hrect := RectangleShape2D.new()
	hrect.size = Vector2(18, 42)  # a bit smaller than the body: near misses feel fair
	hs.shape = hrect
	hs.position = Vector2(0, 4)
	hurt.add_child(hs)
	var cam := Camera2D.new()
	cam.name = "Camera"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	cam.drag_horizontal_enabled = true
	cam.drag_left_margin = 0.1
	cam.drag_right_margin = 0.1
	_add(root, cam)
	var snow := CPUParticles2D.new()  # falling snow follows the camera
	snow.name = "Snowfall"
	snow.texture = load("res://backgrounds/snow_particle.png")
	snow.amount = 120
	snow.lifetime = 6.0
	snow.preprocess = 6.0
	snow.local_coords = false
	snow.position = Vector2(0, -420)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(900, 10)
	snow.direction = Vector2(0.15, 1)
	snow.spread = 12.0
	snow.gravity = Vector2(0, 30)
	snow.initial_velocity_min = 50.0
	snow.initial_velocity_max = 110.0
	snow.scale_amount_min = 0.5
	snow.scale_amount_max = 1.0
	snow.color = Color(1, 1, 1, 0.85)
	snow.z_index = 10
	cam.add_child(snow)
	_own(root)
	return root


func build_level(ts: TileSet) -> Node:
	var rows := FileAccess.get_file_as_string("res://tools/demo_level.txt").strip_edges(false, true).split("\n")
	var root := Node2D.new()
	root.name = "DemoLevel"
	root.set_script(load("res://scripts/demo_level.gd"))

	var bg := CanvasLayer.new()
	bg.name = "Background"
	bg.layer = -10
	_add(root, bg)
	for b in ["bg_sky", "bg_mountains", "bg_hills"]:
		var s := Sprite2D.new()
		s.name = b.capitalize().replace(" ", "")
		s.texture = load("res://backgrounds/%s.png" % b)
		s.centered = false
		s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, 1280, 720)
		bg.add_child(s)

	var back := _layer("BackDecor", ts)
	_add(root, back)
	var ground := _layer("Ground", ts)
	_add(root, ground)
	var front := _layer("FrontDecor", ts)
	_add(root, front)

	var terrain_cells := {}
	var platform_cells := {}
	var start := Vector2i(2, 2)
	var pickups := []
	var tkeys := {"S": 0, "I": 1, "G": 2, "B": 3}
	var pkeys := {"p": 0, "c": 1, "i": 2}
	var singles := {"X": Vector2i(4, 1), "?": Vector2i(5, 1), "K": Vector2i(7, 1), "^": Vector2i(0, 2),
		"v": Vector2i(1, 2), "J": Vector2i(2, 2), "~": Vector2i(0, 3), "=": Vector2i(4, 3)}
	var items := {"*": "star", "o": "bauble", "h": "heart", "b": "bell", "d": "present", "f": "snowflake", "n": "candy_cane", "k": "cookie"}
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			var cell := Vector2i(x, y)
			if tkeys.has(ch):
				terrain_cells.get_or_add(tkeys[ch], []).append(cell)
			elif pkeys.has(ch):
				platform_cells.get_or_add(pkeys[ch], []).append(cell)
			elif singles.has(ch):
				ground.set_cell(cell, SRC_PLATFORMS, singles[ch])
			elif ch == "H":
				var top := y == 0 or rows[y - 1][x] != "H"
				ground.set_cell(cell, SRC_PLATFORMS, Vector2i(3, 2) if top else Vector2i(4, 2))
			elif items.has(ch):
				pickups.append([cell, items[ch]])
			elif ch == "P":
				start = cell
			elif ch == "N":
				_decor(back, "north_pole_sign", cell)
	for t in terrain_cells:
		ground.set_cells_terrain_connect(terrain_cells[t], 0, t, false)
	for p in platform_cells:
		ground.set_cells_terrain_connect(platform_cells[p], 1, p, false)

	# Hand-placed decoration (base cell = the cell the object stands in).
	var deco := [["christmas_tree", 0, 9], ["signpost", 6, 9], ["lamp_post", 9, 9], ["snowman", 13, 8],
		["snowy_bush", 22, 7], ["present_red", 25, 9], ["pine_tree", 29, 9], ["snow_pile", 33, 9],
		["snowy_rock", 43, 9], ["pine_tree", 46, 8], ["cabin", 72, 9], ["candy_cane", 75, 9],
		["gingerbread_man", 80, 9], ["fence_L", 81, 9], ["fence_M", 82, 9], ["fence_M", 83, 9], ["fence_R", 84, 9],
		["present_green", 85, 9], ["present_blue", 87, 9], ["lamp_post", 90, 9], ["christmas_tree", 94, 9],
		["present_stack", 93, 9], ["holly", 47, 9]]
	for d in deco:
		_decor(back, d[0], Vector2i(d[1], d[2]))
	for x in range(52, 57):
		front.set_cell(Vector2i(x, 4), SRC_DECOR, Vector2i(6, 5))  # lights strung along the tower
	_decor(front, "wreath", Vector2i(54, 6))
	_decor(front, "stocking", Vector2i(53, 8))
	_decor(front, "icicles_hanging", Vector2i(20, 7))  # under the wooden plank
	_decor(front, "icicles_hanging", Vector2i(23, 7))

	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	player.position = ground.map_to_local(start) + Vector2(0, 2)
	_add(root, player)
	player.ground = ground
	player.back_decor = back

	var holder := Node2D.new()
	holder.name = "Pickups"
	_add(root, holder)
	var pickup_scene: PackedScene = load("res://scenes/pickup.tscn")
	for p in pickups:
		var inst: Node2D = pickup_scene.instantiate()
		inst.kind = p[1]
		inst.value = 3 if p[1] == "heart" else 1
		inst.position = ground.map_to_local(p[0])
		holder.add_child(inst)
		inst.owner = root

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	_add(root, hud)
	var score := Label.new()
	score.name = "Score"
	score.position = Vector2(24, 16)
	score.add_theme_font_size_override("font_size", 32)
	score.add_theme_color_override("font_outline_color", Color(0.1, 0.11, 0.17))
	score.add_theme_constant_override("outline_size", 8)
	hud.add_child(score)
	score.owner = root
	var msg := Label.new()
	msg.name = "Message"
	msg.visible = false
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.position = Vector2(340, 300)
	msg.size = Vector2(600, 80)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 48)
	msg.add_theme_color_override("font_color", Color(1, 0.84, 0.37))
	msg.add_theme_color_override("font_outline_color", Color(0.1, 0.11, 0.17))
	msg.add_theme_constant_override("outline_size", 12)
	hud.add_child(msg)
	msg.owner = root
	var help := Label.new()
	help.name = "Controls"
	help.text = "A/D or arrows: move    Space: jump    W/S: climb ladders"
	help.position = Vector2(24, 670)
	help.add_theme_font_size_override("font_size", 20)
	help.add_theme_constant_override("outline_size", 6)
	help.add_theme_color_override("font_outline_color", Color(0.1, 0.11, 0.17))
	hud.add_child(help)
	help.owner = root
	return root


func _layer(name: String, ts: TileSet) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = name
	l.tile_set = ts
	return l


func _decor(layer: TileMapLayer, name: String, cell: Vector2i) -> void:
	var info: Dictionary = props_meta["decorations"][name]
	layer.set_cell(cell, SRC_DECOR, Vector2i(int(info["col"]), int(info["row"])))


# ================================================================ utils
func _add(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = parent if parent.owner == null else parent.owner


func _own(root: Node) -> void:
	# Only claim unowned nodes: children inside an instanced scene stay owned by that instance.
	for n in root.find_children("*", "", true, false):
		if n.owner == null:
			n.owner = root


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "Could not save %s" % path)
	res.take_over_path(path)


func _save_scene(root: Node, path: String) -> void:
	_own(root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	assert(err == OK, "Could not pack %s" % path)
	_save(packed, path)
	root.free()


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
