class_name SwordSwipe
extends Node3D
## A giant plastic sword that appears in a contestant's hand and slashes in a
## wide diagonal arc in front of them, leaving a glowing trail and sparks.

const SWING_TIME := 0.2
const HOLD_TIME := 0.12
const FADE_TIME := 0.18
const START_ANGLE := -1.9
const END_ANGLE := 1.9
const INNER := 0.5
const OUTER := 2.9

var colour: Color = Color(1.0, 0.5, 0.1)

var _pivot: Node3D
var _sword: Node3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_mat: StandardMaterial3D
var _age: float = 0.0
var _sparked: bool = false


## Adds a swipe to [param user], facing [param dir] (world space).
static func spawn(user: Node3D, dir: Vector3, tint: Color) -> SwordSwipe:
	if user == null or not user.is_inside_tree():
		return null
	var swipe := SwordSwipe.new()
	swipe.colour = tint
	user.add_child(swipe)
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	swipe.global_rotation = Vector3(0.0, atan2(-flat.x, -flat.z), 0.0)
	swipe.position = Vector3(0.0, 1.05, 0.0)
	return swipe


func _ready() -> void:
	# Tilted swing plane: high on the right, low on the left.
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.rotation = Vector3(0.0, 0.0, 0.32)
	add_child(_pivot)
	_sword = Node3D.new()
	_sword.name = "Sword"
	_pivot.add_child(_sword)
	var steel := Color(0.85, 0.88, 0.95)
	var blade := CourseBuilder.make_box_mesh(Vector3(0.26, 0.06, 2.3), steel)
	blade.position = Vector3(0.0, 0.0, -1.45)
	_sword.add_child(blade)
	var edge := CourseBuilder.add_neon_strip(_sword, Vector3(0.06, 0.08, 2.3), Vector3(0.14, 0.0, -1.45), colour, "Edge")
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tip := MeshInstance3D.new()
	var tip_mesh := PrismMesh.new()
	tip_mesh.size = Vector3(0.26, 0.4, 0.06)
	tip_mesh.material = CourseBuilder.make_material(steel)
	tip.mesh = tip_mesh
	tip.position = Vector3(0.0, 0.0, -2.78)
	tip.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_sword.add_child(tip)
	var guard := CourseBuilder.make_box_mesh(Vector3(0.7, 0.12, 0.14), Color(1.0, 0.75, 0.1))
	guard.position = Vector3(0.0, 0.0, -0.28)
	_sword.add_child(guard)
	var grip := CourseBuilder.make_box_mesh(Vector3(0.12, 0.12, 0.42), Color(0.12, 0.1, 0.1))
	grip.position = Vector3(0.0, 0.0, -0.02)
	_sword.add_child(grip)

	_trail_mesh = ImmediateMesh.new()
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_mat.vertex_color_use_as_albedo = true
	_trail = MeshInstance3D.new()
	_trail.name = "Trail"
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_trail)
	_sword.rotation.y = START_ANGLE
	scale = Vector3.ONE * 0.6
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.06)


func _process(delta: float) -> void:
	_age += delta
	var swing := clampf(_age / SWING_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - swing, 3.0)
	var angle := lerpf(START_ANGLE, END_ANGLE, eased)
	_sword.rotation.y = angle
	var fade := 1.0 - clampf((_age - SWING_TIME - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
	_draw_trail(angle, fade)
	if not _sparked and swing >= 0.5:
		_sparked = true
		var tip := _sword.global_transform * Vector3(0.0, 0.0, -2.7)
		FX.burst(self, "sparks", tip, Color(colour.r * 1.8, colour.g * 1.8, colour.b * 1.8), 0.9)
	if fade < 1.0:
		_sword.scale = Vector3.ONE * maxf(fade, 0.01)
	if _age > SWING_TIME + HOLD_TIME + FADE_TIME:
		queue_free()


## Fan-shaped glowing trail from the start of the swing to [param angle].
func _draw_trail(angle: float, fade: float) -> void:
	_trail_mesh.clear_surfaces()
	var span := angle - START_ANGLE
	if span < 0.05 or fade <= 0.0:
		return
	var steps := 18
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_mat)
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := START_ANGLE + span * t
		# Newest part (near the blade) is brightest.
		var k := pow(t, 1.6) * fade
		var bright := Color(colour.r * 2.5 * k, colour.g * 2.5 * k, colour.b * 2.5 * k, k)
		var inner := Color(bright.r * 0.3, bright.g * 0.3, bright.b * 0.3, k * 0.2)
		var dir := Vector3(-sin(a), 0.0, -cos(a))
		_trail_mesh.surface_set_color(inner)
		_trail_mesh.surface_add_vertex(dir * INNER)
		_trail_mesh.surface_set_color(bright)
		_trail_mesh.surface_add_vertex(dir * OUTER)
	_trail_mesh.surface_end()
