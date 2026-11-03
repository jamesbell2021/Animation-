class_name Interior
extends Node3D
## A building a keeper can walk into: its room, and the cutaway that shows it.
##
## Everything above knee height (the roof, the upper walls, windows and door) hangs
## under `upper`. Playing alone, when your keeper steps inside, `upper` fades away so
## the camera looks down into the room, and comes back as they leave. With more than one
## person playing the roofs stay on, and each keeper shows as an outline through
## whatever hides them (Player.set_outline).
##
## `walls()` builds a room's walls in those two bands with a doorway, and the collision
## boxes round it, so keepers walk in at the door and nowhere else.

## How fast the cutaway fades, per second.
const FADE := 4.0
## Only when obviously inside: this far in from the walls (not just in the doorway)...
const DEEP := 0.45
## ...for this long (not just passing through). Once lifted, the roof stays off until
## the keeper is out of the room altogether.
const SETTLE := 0.35
## Walls are cut at this height when you're inside.
const LOW := 0.7

var upper := Node3D.new()
## The room, in this node's space: half its width (x) and depth (z), and its height.
var half := Vector2(1.0, 1.0)
var height := 2.5
var fade := 0.0
var _in_t := 0.0
var _open := false
var _geoms: Array[GeometryInstance3D] = []

func _init() -> void:
	name = "Interior"
	upper.name = "Upper"
	add_child(upper)
	add_to_group("interiors")

## Whether a point is inside any building's room.
static func anywhere(tree: SceneTree, p: Vector3) -> bool:
	for r in tree.get_nodes_in_group("interiors"):
		if (r as Interior).contains(p):
			return true
	return false

## Whether this screen cuts buildings away (one person playing on it, not on the LAN).
static func cutaway_mode() -> bool:
	return CameraDirector.free_on and not Net.online()

func contains(p: Vector3, margin: float = 0.0) -> bool:
	var l := to_local(p)
	return absf(l.x) < half.x - margin and absf(l.z) < half.y - margin and l.y > -1.0 and l.y < height

func _process(delta: float) -> void:
	var who := CameraDirector.person
	var here := cutaway_mode() and who != null and is_instance_valid(who)
	if here and contains(who.global_position, DEEP):
		_in_t += delta
	else:
		_in_t = 0.0
	if _in_t >= SETTLE:
		_open = true
	elif not here or not contains(who.global_position):
		_open = false
	var want := 1.0 if _open else 0.0
	if is_equal_approx(fade, want):
		return
	fade = move_toward(fade, want, delta * FADE)
	apply()

func apply() -> void:
	if _geoms.is_empty():
		for g in upper.find_children("*", "GeometryInstance3D", true, false):
			_geoms.append(g)
	for g in _geoms:
		if is_instance_valid(g):
			g.transparency = fade
	upper.visible = fade < 0.99

## Walls round a room `w` wide (x) and `d` deep (z), from `y0` up to `y0 + h`, `t` thick,
## with a doorway `door_w` wide and `door_h` high centred at `door_x` on the -Z side.
## Each wall goes in two bands: up to LOW in `lower` (it stays), the rest in `upper`.
## Collision boxes, full height, go on `body`. Returns the wall meshes.
func walls(body: CollisionObject3D, lower: Node3D, w: float, d: float, h: float, y0: float, t: float,
		mat: Material, door_x: float, door_w: float, door_h: float) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	# [centre x, centre z, size x, size z] for each run of wall.
	var runs := [
		[0.0, d * 0.5 - t * 0.5, w, t],
		[-w * 0.5 + t * 0.5, 0.0, t, d],
		[w * 0.5 - t * 0.5, 0.0, t, d],
	]
	var left := -w * 0.5
	var right := w * 0.5
	var dl := door_x - door_w * 0.5
	var dr := door_x + door_w * 0.5
	if dl - left > 0.01:
		runs.append([(left + dl) * 0.5, -d * 0.5 + t * 0.5, dl - left, t])
	if right - dr > 0.01:
		runs.append([(dr + right) * 0.5, -d * 0.5 + t * 0.5, right - dr, t])
	var low := minf(LOW, h)
	for r in runs:
		var sx: float = r[2]
		var sz: float = r[3]
		var at := Vector3(r[0], 0.0, r[1])
		var a := Geo.box(lower, Vector3(sx, low, sz), Color.WHITE, at + Vector3(0.0, y0 + low * 0.5, 0.0))
		a.material_override = mat
		out.append(a)
		var b := Geo.box(upper, Vector3(sx, h - low, sz), Color.WHITE, at + Vector3(0.0, y0 + low + (h - low) * 0.5, 0.0))
		b.material_override = mat
		out.append(b)
		Geo.box_shape(body, Vector3(sx, h, sz), at + Vector3(0.0, y0 + h * 0.5, 0.0))
	# Over the door.
	if h > door_h:
		var lintel := Geo.box(upper, Vector3(door_w, h - door_h, t), Color.WHITE, Vector3(door_x, y0 + door_h + (h - door_h) * 0.5, -d * 0.5 + t * 0.5))
		lintel.material_override = mat
		out.append(lintel)
	half = Vector2(w * 0.5 - t, d * 0.5 - t)
	height = y0 + h + 1.5
	return out
