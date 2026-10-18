class_name PaintballArena
extends FairgroundCourse
## Paintball Battle arena: a walled, floodlit 60 m square under the same night
## sky, with a raised centre platform, bunkers, crate stacks and low walls to
## hide behind, and paint crates to refill from. Spawns sit in a ring facing in.

const HALF := 30.0
const WALL_HEIGHT := 3.2

## Where the paint crates (ammo refills) go.
var crate_spots: Array[Vector3] = []

var _spawns: Array[Vector3] = []


func build() -> void:
	if not is_inside_tree():
		push_error("PaintballArena.build: not inside the scene tree.")
		return
	clear()
	_build_environment()
	var arena := Node3D.new()
	arena.name = "SceneryArena"
	add_child(arena)
	_build_floor(arena)
	_build_walls(arena)
	_build_cover(arena)
	_build_lights(arena)
	_spawns.clear()
	for i in range(8):
		var a := TAU * (float(i) + 0.5) / 8.0
		_spawns.append(Vector3(cos(a) * 24.0, 1.0, sin(a) * 24.0))
	crate_spots = [
		Vector3(0.0, 0.0, 13.0), Vector3(0.0, 0.0, -13.0), Vector3(13.0, 0.0, 0.0), Vector3(-13.0, 0.0, 0.0),
		Vector3(25.0, 0.0, 25.0), Vector3(-25.0, 0.0, 25.0), Vector3(25.0, 0.0, -25.0), Vector3(-25.0, 0.0, -25.0),
	]
	course_built.emit()


func get_spawn_positions(count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(count):
		out.append(_spawns[i % _spawns.size()])
	return out


func get_finish_area() -> Area3D:
	return null


func get_total_length() -> float:
	return HALF * 2.0


func _build_floor(parent: Node3D) -> void:
	CourseBuilder.add_box(parent, Vector3(HALF * 2.0, 1.0, HALF * 2.0), Vector3(0.0, -0.5, 0.0), Color(0.11, 0.12, 0.15), "Floor")
	for i in range(-2, 3):
		var p := float(i) * 12.0
		CourseBuilder.add_neon_strip(parent, Vector3(HALF * 2.0, 0.02, 0.1), Vector3(0.0, 0.01, p), CourseBuilder.accent(1).darkened(0.4), "GridX")
		CourseBuilder.add_neon_strip(parent, Vector3(0.1, 0.02, HALF * 2.0), Vector3(p, 0.01, 0.0), CourseBuilder.accent(1).darkened(0.4), "GridZ")
	# Land outside the walls so the arena doesn't float.
	CourseBuilder.add_decor_box(parent, Vector3(400.0, 1.0, 400.0), Vector3(0.0, -1.2, 0.0), Color(0.03, 0.035, 0.04), "Grounds")


func _build_walls(parent: Node3D) -> void:
	var steel := CourseBuilder.STEEL
	for side: float in [-1.0, 1.0]:
		CourseBuilder.add_box(parent, Vector3(HALF * 2.0 + 2.0, WALL_HEIGHT, 1.0), Vector3(0.0, WALL_HEIGHT * 0.5, side * (HALF + 0.5)), steel, "WallZ")
		CourseBuilder.add_box(parent, Vector3(1.0, WALL_HEIGHT, HALF * 2.0 + 2.0), Vector3(side * (HALF + 0.5), WALL_HEIGHT * 0.5, 0.0), steel, "WallX")
		CourseBuilder.add_neon_strip(parent, Vector3(HALF * 2.0 + 2.0, 0.2, 1.1), Vector3(0.0, WALL_HEIGHT, side * (HALF + 0.5)), CourseBuilder.accent(0), "WallTopZ")
		CourseBuilder.add_neon_strip(parent, Vector3(1.1, 0.2, HALF * 2.0 + 2.0), Vector3(side * (HALF + 0.5), WALL_HEIGHT, 0.0), CourseBuilder.accent(0), "WallTopX")
	var title := CourseBuilder.add_sign(parent, "PAINTBALL BATTLE", Vector3(0.0, WALL_HEIGHT + 2.5, -HALF - 1.0), CourseBuilder.accent(2), 160)
	if title != null:
		title.pixel_size = 0.02


func _build_cover(parent: Node3D) -> void:
	# Raised centre platform with ramps on two sides.
	var plat_h := 1.6
	CourseBuilder.add_box(parent, Vector3(8.0, plat_h, 8.0), Vector3(0.0, plat_h * 0.5, 0.0), CourseBuilder.surface(CourseBuilder.accent(3)), "CentrePlatform")
	CourseBuilder.add_neon_strip(parent, Vector3(8.1, 0.12, 8.1), Vector3(0.0, plat_h, 0.0), CourseBuilder.accent(3), "PlatformRim")
	var run := 5.0
	var slope := sqrt(run * run + plat_h * plat_h)
	var angle := rad_to_deg(atan2(plat_h, run))
	for side: float in [-1.0, 1.0]:
		CourseBuilder.add_ramp(parent, Vector3(3.0, 0.3, slope), Vector3(0.0, plat_h * 0.5 - 0.12, side * (4.0 + run * 0.5)), angle * side, CourseBuilder.STEEL, "Ramp")
	# Low walls on the platform to duck behind.
	for side: float in [-1.0, 1.0]:
		CourseBuilder.add_box(parent, Vector3(0.5, 1.0, 3.0), Vector3(side * 2.6, plat_h + 0.5, 0.0), CourseBuilder.surface(CourseBuilder.accent(2)), "PlatformWall")

	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			# Inflatable bunkers.
			var bunker := CourseBuilder.add_cylinder(parent, 1.3, 2.2, Vector3(sx * 9.0, 1.1, sz * 9.0), CourseBuilder.surface(CourseBuilder.accent(0)), "Bunker")
			_ring(bunker, 1.32, 2.2, CourseBuilder.accent(0))
			# Crate stacks.
			_crate(parent, Vector3(sx * 18.0, 0.0, sz * 6.0), 2.2, sx * sz > 0.0)
			_crate(parent, Vector3(sx * 6.0, 0.0, sz * 18.0), 2.2, sx * sz < 0.0)
			# Low walls you can hop over.
			var low := CourseBuilder.add_box(parent, Vector3(5.0, 1.1, 0.6), Vector3(sx * 14.0, 0.55, sz * 14.0), CourseBuilder.surface(CourseBuilder.accent(1)), "LowWall")
			low.rotation.y = PI * 0.25 * sx * sz
			CourseBuilder.add_neon_strip(low, Vector3(5.02, 0.1, 0.62), Vector3(0.0, 0.55, 0.0), CourseBuilder.accent(1), "LowWallRim")
	# Tall barriers between the spawns.
	for i in range(4):
		var a := TAU * float(i) / 4.0
		var barrier := CourseBuilder.add_box(parent, Vector3(0.8, 2.4, 7.0), Vector3(cos(a) * 23.0, 1.2, sin(a) * 23.0), CourseBuilder.surface(CourseBuilder.accent(2)), "Barrier")
		barrier.rotation.y = -a
		CourseBuilder.add_neon_strip(barrier, Vector3(0.82, 0.12, 7.02), Vector3(0.0, 1.2, 0.0), CourseBuilder.accent(2), "BarrierRim")


func _crate(parent: Node3D, pos: Vector3, size: float, stacked: bool) -> void:
	var crate := CourseBuilder.add_box(parent, Vector3.ONE * size, pos + Vector3(0.0, size * 0.5, 0.0), Color(0.3, 0.2, 0.12), "Crate")
	for y: float in [-0.5, 0.5]:
		CourseBuilder.add_neon_strip(crate, Vector3(size + 0.04, 0.08, size + 0.04), Vector3(0.0, y * size, 0.0), CourseBuilder.accent(0).darkened(0.2), "CrateEdge")
	if stacked:
		var small := size * 0.55
		CourseBuilder.add_box(parent, Vector3.ONE * small, pos + Vector3(size * 0.15, size + small * 0.5, -size * 0.1), Color(0.32, 0.22, 0.13), "CrateTop")


func _ring(parent: Node3D, radius: float, height: float, colour: Color) -> void:
	for y: float in [-0.35, 0.35]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.02
		torus.outer_radius = radius + 0.08
		torus.material = CourseBuilder.make_neon_material(colour, 2.0)
		ring.mesh = torus
		ring.position = Vector3(0.0, y * height, 0.0)
		parent.add_child(ring)


func _build_lights(parent: Node3D) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var base := Vector3(sx * (HALF + 3.0), 0.0, sz * (HALF + 3.0))
			CourseBuilder.add_decor_box(parent, Vector3(0.5, 14.0, 0.5), base + Vector3(0.0, 7.0, 0.0), CourseBuilder.STEEL, "LightPole")
			CourseBuilder.add_neon_strip(parent, Vector3(2.4, 0.8, 0.4), base + Vector3(0.0, 14.2, 0.0), Color(0.9, 0.95, 1.0), "Floodlight")
			var spot := SpotLight3D.new()
			spot.light_color = Color(0.85, 0.9, 1.0)
			spot.light_energy = 3.0
			spot.spot_range = 70.0
			spot.spot_angle = 35.0
			parent.add_child(spot)
			spot.position = base + Vector3(0.0, 14.0, 0.0)
			spot.look_at(Vector3(sx * 6.0, 0.0, sz * 6.0), Vector3.UP)
