class_name TowerStage
extends CourseSection
## One stage of the Tower Climb: a checkpoint landing, then an obby run that
## spirals 266 degrees round the tower and climbs 15 m to the next landing.
## Stages share the tower's origin, so local positions are world positions.
## Kinds: stepping stones, sweeper stairs, vanishing tiles, spinning discs,
## pusher beams, bounce pads, a meltdown mix and the final crown climb.

enum Kind { STONES, SWEEPERS, VANISH, DISCS, PUSHERS, BOUNCE, MELTDOWN, CROWN }

const NAMES: Array[String] = ["STEPPING STONES", "SWEEPER STAIRS", "VANISHING TILES", "SPIN CITY",
	"PUSHER BEAMS", "BOUNCE HOUSE", "MELTDOWN", "THE CROWN CLIMB"]
## Path radius from the tower's centre, climb per stage, and the angles a stage
## and its landing cover (radians: 300 and about 34 degrees).
const RADIUS := 10.0
const RISE := 15.0
const ARC := 5.235988
const LANDING := 0.6
const PATH_WIDTH := 5.0

var stage_index: int = 0
var kind: int = Kind.STONES

var _route: Array[Dictionary] = []
var _box_spots: Array[Vector3] = []


## Bot waypoints (local = world, see the class notes).
func bot_route() -> Array[Dictionary]:
	return _route


## Item box positions on this stage.
func box_spots() -> Array[Vector3]:
	return _box_spots


func base_angle() -> float:
	return float(stage_index) * ARC


func base_y() -> float:
	return float(stage_index) * RISE


## Angle along this stage's run, [param frac] 0 (end of the landing) to 1 (next landing).
func run_angle(frac: float) -> float:
	return base_angle() + LANDING + (ARC - LANDING) * frac


static func point(theta: float, y: float, r: float = RADIUS) -> Vector3:
	return Vector3(cos(theta) * r, y, sin(theta) * r)


func get_end_position() -> Vector3:
	return Vector3.ZERO


func _build_geometry() -> void:
	section_title = NAMES[kind]
	colour_index = stage_index % 4
	_build_landing()
	match kind:
		Kind.STONES:
			_stones(0, 13, 0.0, 1.0, 2.2, 0.6, false)
		Kind.SWEEPERS:
			_sweeper_stairs()
		Kind.VANISH:
			_stones(0, 14, 0.0, 1.0, 2.4, 0.5, true)
		Kind.DISCS:
			_spin_city()
		Kind.PUSHERS:
			_pusher_beams()
		Kind.BOUNCE:
			_bounce_house()
		Kind.MELTDOWN:
			_meltdown()
		Kind.CROWN:
			_stones(0, 12, 0.0, 0.97, 1.7, 1.0, false)
			# Up onto the bridge to the summit.
			_route.append(_wp(point(base_angle() + ARC, base_y() + RISE, RADIUS - 1.0), true, 1.0))


func _build_landing() -> void:
	var y0 := base_y()
	var mid := base_angle() + LANDING * 0.5
	_arc_slab(base_angle(), base_angle() + LANDING, y0, PATH_WIDTH, "Landing")
	var area := add_checkpoint(point(mid, y0), point(mid, y0 + 1.0), PATH_WIDTH + 2.0)
	if area != null:
		area.rotation.y = -mid
	CourseBuilder.add_sign(self, "%d. %s" % [stage_index + 1, section_title], point(mid, y0 + 4.5, RADIUS + 1.5), CourseBuilder.accent(colour_index), 72)
	_route.append(_wp(point(mid, y0), false))
	_box_spots.append(point(mid + 0.12, y0 + 1.2, RADIUS - 1.4))
	_box_spots.append(point(mid + 0.12, y0 + 1.2, RADIUS + 1.4))


# --- Stage kinds --------------------------------------------------------------------

## A run of [param count] stepping stones (or vanishing tiles) from [param from_frac]
## to [param to_frac], climbing from the stage base by equal steps to the next landing.
func _stones(first: int, count: int, from_frac: float, to_frac: float, size: float, zigzag: float, vanish: bool, y_from: float = 0.0, y_to: float = RISE) -> void:
	var y0 := base_y()
	for i in range(count):
		var frac := lerpf(from_frac, to_frac, (float(i) + 0.5) / float(count))
		var theta := run_angle(frac)
		var top := y0 + lerpf(y_from, y_to, float(i + 1) / float(count + 1))
		var r := RADIUS + (zigzag if (i + first) % 2 == 1 else -zigzag)
		var pos := point(theta, top - 0.25, r)
		if vanish:
			var tile := VanishTile.new()
			tile.size = Vector3(size, 0.5, size)
			tile.colour = CourseBuilder.accent((i + stage_index) % 4)
			tile.position = pos
			tile.rotation.y = PI * 0.5 - theta
			add_child(tile)
		else:
			var stone := CourseBuilder.add_box(self, Vector3(size, 0.5, size), pos, CourseBuilder.surface(CourseBuilder.accent((i + stage_index) % 4)), "Stone")
			stone.rotation.y = PI * 0.5 - theta
			CourseBuilder.add_neon_strip(stone, Vector3(size + 0.04, 0.06, size + 0.04), Vector3(0.0, 0.25, 0.0), CourseBuilder.accent((i + stage_index) % 4), "StoneGlow")
		_route.append(_wp(point(theta, top, r), true, 0.9))
		if i == count / 2:
			_box_spots.append(point(theta, top + 1.3, r))


func _sweeper_stairs() -> void:
	var y0 := base_y()
	var pads: Array = [[0.2, 0.25], [0.52, 0.55], [0.82, 0.85]]
	var prev_theta := base_angle() + LANDING
	var prev_y := y0
	var half := 3.0 / RADIUS
	for i in range(pads.size()):
		var theta := run_angle(float(pads[i][0]))
		var y := y0 + RISE * float(pads[i][1])
		_ramp(prev_theta, prev_y, theta - half, y, PATH_WIDTH - 0.6)
		_pad(theta, y, 3.0, true)
		var spinner := SpinnerObstacle.new()
		spinner.arm_length = 2.7
		spinner.arm_count = 2
		spinner.speed_degrees = 70.0 * (1.0 if i % 2 == 0 else -1.0)
		spinner.colour = CourseBuilder.accent((i + 1) % 4)
		spinner.position = point(theta, y)
		add_child(spinner)
		# Round the outside of the spinner's pole.
		_route.append(_wp(point(theta - half * 0.6, y, RADIUS + 1.4), false))
		_route.append(_wp(point(theta + half * 0.6, y, RADIUS + 1.4), false))
		if i == 1:
			_box_spots.append(point(theta, y + 1.3, RADIUS + 2.0))
		prev_theta = theta + half
		prev_y = y
	_ramp(prev_theta, prev_y, base_angle() + ARC, y0 + RISE, PATH_WIDTH - 0.6)


func _spin_city() -> void:
	var y0 := base_y()
	var count := 12
	for i in range(count):
		var frac := (float(i) + 0.5) / float(count)
		var theta := run_angle(frac)
		var top := y0 + RISE * float(i + 1) / float(count + 1)
		if i % 2 == 0:
			var disc := MovingPlatform.new()
			disc.shape_type = MovingPlatform.ShapeType.DISC
			disc.disc_radius = 1.7
			disc.size = Vector3(3.4, 0.5, 3.4)
			disc.spin_degrees = 75.0 * (1.0 if i % 4 == 0 else -1.0)
			disc.colour = CourseBuilder.accent((i / 2) % 4)
			disc.position = point(theta, top - 0.25)
			add_child(disc)
		else:
			var stone := CourseBuilder.add_box(self, Vector3(1.6, 0.5, 1.6), point(theta, top - 0.25), CourseBuilder.surface(CourseBuilder.accent(2)), "Stone")
			stone.rotation.y = PI * 0.5 - theta
		_route.append(_wp(point(theta, top), true, 0.9))
		if i == 5:
			_box_spots.append(point(theta, top + 1.3))


func _pusher_beams() -> void:
	var y0 := base_y()
	var pads: Array = [[0.25, 0.3], [0.58, 0.62], [0.88, 0.9]]
	var prev_theta := base_angle() + LANDING
	var prev_y := y0
	var half := 2.6 / RADIUS
	for i in range(pads.size()):
		var theta := run_angle(float(pads[i][0]))
		var y := y0 + RISE * float(pads[i][1])
		_ramp(prev_theta, prev_y, theta - half, y, 2.0)
		_pad(theta, y, 2.6)
		var radial := Vector3(cos(theta), 0.0, sin(theta))
		var pusher := PusherObstacle.new()
		pusher.travel = radial * 4.4
		pusher.speed = 3.0 + float(i) * 0.7
		pusher.push_force = 6.5
		pusher.push_up = 3.5
		pusher.colour = CourseBuilder.accent(2)
		pusher.phase = float(i) * 0.4
		pusher.position = point(theta, y + 0.4) - radial * 2.2
		add_child(pusher)
		_route.append(_wp(point(theta - half * 0.5, y), false))
		_route.append(_wp(point(theta + half * 0.5, y), false))
		if i == 1:
			_box_spots.append(point(theta, y + 1.3))
		prev_theta = theta + half
		prev_y = y
	_ramp(prev_theta, prev_y, base_angle() + ARC, y0 + RISE, 2.0)


func _bounce_house() -> void:
	var y0 := base_y()
	# Ledges [from, to, height] with a bounce pad near the end of each but the last.
	var ledges: Array = [[0.0, 0.17, 0.0], [0.2, 0.45, 4.5], [0.48, 0.72, 9.0], [0.75, 0.9, 13.5]]
	for i in range(ledges.size()):
		var a := run_angle(float(ledges[i][0]))
		var b := run_angle(float(ledges[i][1]))
		var y := y0 + float(ledges[i][2])
		if i > 0:
			_arc_slab(a, b, y, PATH_WIDTH, "Ledge")
		else:
			_arc_slab(base_angle() + LANDING, b, y, PATH_WIDTH, "Ledge")
		_route.append(_wp(point(lerpf(a, b, 0.25), y), false))
		_route.append(_wp(point(lerpf(a, b, 0.65), y), false))
		if i < ledges.size() - 1:
			var pad_theta := b - 0.9 / RADIUS
			var tangent := Vector3(-sin(pad_theta), 0.0, cos(pad_theta))
			var pad := BouncerObstacle.new()
			pad.radius = 1.3
			pad.bounce_velocity = 14.5
			pad.launch_direction = tangent * 6.0
			pad.colour = CourseBuilder.accent((i + 1) % 4)
			pad.position = point(pad_theta, y)
			add_child(pad)
			# Counts as reached on landing on the dome, so bots then steer for the next ledge.
			_route.append(_wp(point(pad_theta, y + 0.5), true, 1.8))
		if i == 2:
			_box_spots.append(point(lerpf(a, b, 0.5), y + 1.3))
	_ramp(run_angle(0.9), y0 + 13.5, base_angle() + ARC, y0 + RISE, PATH_WIDTH - 0.6)


func _meltdown() -> void:
	var y0 := base_y()
	_stones(0, 6, 0.0, 0.42, 2.3, 0.5, true, 0.0, 7.0)
	var theta := run_angle(0.5)
	_pad(theta, y0 + 7.0, 3.0, true)
	var spinner := SpinnerObstacle.new()
	spinner.arm_length = 2.7
	spinner.arm_count = 3
	spinner.speed_degrees = 85.0
	spinner.colour = CourseBuilder.accent(2)
	spinner.position = point(theta, y0 + 7.0)
	add_child(spinner)
	_route.append(_wp(point(theta, y0 + 7.0, RADIUS + 1.4), false))
	_stones(1, 7, 0.58, 1.0, 2.3, 0.5, true, 7.0, RISE)


# --- Building blocks ---------------------------------------------------------------

func _wp(pos: Vector3, jump: bool, radius: float = 1.3) -> Dictionary:
	return {"pos": pos, "jump": jump, "wait": false, "radius": radius}


## A flat curved slab along the path between two angles, top at [param y].
func _arc_slab(theta_a: float, theta_b: float, y: float, width: float, node_name: String) -> void:
	var span := theta_b - theta_a
	var pieces := maxi(int(ceil(absf(span) * RADIUS / 2.4)), 1)
	for k in range(pieces):
		var theta := theta_a + span * (float(k) + 0.5) / float(pieces)
		var length := absf(span) * RADIUS / float(pieces) * 1.12
		var slab := CourseBuilder.add_box(self, Vector3(length, 0.6, width), point(theta, y - 0.3), CourseBuilder.surface(CourseBuilder.accent(colour_index)), node_name)
		slab.rotation.y = PI * 0.5 - theta
		CourseBuilder.add_neon_strip(slab, Vector3(length, 0.08, 0.12), Vector3(0.0, 0.3, width * 0.5), CourseBuilder.accent(colour_index), "Edge")


## A sloping walkway along the path from ([param theta_a], [param y_a]) to ([param theta_b], [param y_b]).
func _ramp(theta_a: float, y_a: float, theta_b: float, y_b: float, width: float) -> void:
	var pieces := maxi(int(ceil(absf(theta_b - theta_a) * RADIUS / 2.2)), 1)
	for k in range(pieces):
		var t0 := float(k) / float(pieces)
		var t1 := float(k + 1) / float(pieces)
		var pa := point(lerpf(theta_a, theta_b, t0), lerpf(y_a, y_b, t0))
		var pb := point(lerpf(theta_a, theta_b, t1), lerpf(y_a, y_b, t1))
		var mid_theta := lerpf(theta_a, theta_b, (t0 + t1) * 0.5)
		var along := (pb - pa).normalized()
		var radial := Vector3(cos(mid_theta), 0.0, sin(mid_theta))
		var up := along.cross(radial).normalized()
		if up.y < 0.0:
			up = -up
		var side := along.cross(up).normalized()
		var size := Vector3(pa.distance_to(pb) * 1.12, 0.4, width)
		var body := CourseBuilder.add_box(self, size, Vector3.ZERO, CourseBuilder.surface(CourseBuilder.accent(colour_index)), "Ramp")
		body.transform = Transform3D(Basis(along, up, side), (pa + pb) * 0.5 - up * 0.2)
		CourseBuilder.add_neon_strip(body, Vector3(size.x, 0.06, 0.1), Vector3(0.0, 0.2, width * 0.5), CourseBuilder.accent(colour_index), "Edge")
		CourseBuilder.add_neon_strip(body, Vector3(size.x, 0.06, 0.1), Vector3(0.0, 0.2, -width * 0.5), CourseBuilder.accent(colour_index), "Edge")
		_route.append(_wp((pa + pb) * 0.5, false))


## A round platform on the path with a neon rim, and optionally a low rail
## round it with gaps where the path comes in and goes out.
func _pad(theta: float, y: float, radius: float, railed: bool = false) -> void:
	if railed:
		var centre := point(theta, y)
		var tangent := Vector3(-sin(theta), 0.0, cos(theta))
		var pieces := 20
		for k in range(pieces):
			var phi := TAU * (float(k) + 0.5) / float(pieces)
			var d := Vector3(cos(phi), 0.0, sin(phi))
			if absf(d.dot(tangent)) > 0.75:
				continue
			var rail := CourseBuilder.add_box(self, Vector3(TAU * radius / float(pieces) * 1.05, 0.6, 0.25), centre + d * (radius - 0.15) + Vector3.UP * 0.3, Color(0.08, 0.08, 0.1), "PadRail")
			rail.rotation.y = PI * 0.5 - phi
			CourseBuilder.add_neon_strip(rail, Vector3(TAU * radius / float(pieces) * 1.05, 0.06, 0.27), Vector3(0.0, 0.3, 0.0), CourseBuilder.accent(2), "PadRailTop")
	CourseBuilder.add_cylinder(self, radius, 0.6, point(theta, y - 0.3), CourseBuilder.surface(CourseBuilder.accent(colour_index)), "Pad")
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	torus.material = CourseBuilder.make_neon_material(CourseBuilder.accent(colour_index), 2.0)
	rim.mesh = torus
	rim.position = point(theta, y + 0.01)
	rim.scale = Vector3(1.0, 0.4, 1.0)
	add_child(rim)
