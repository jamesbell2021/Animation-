class_name ContestantVisuals
extends Node3D
## Procedural low-poly leprechaun contestant with a simple walk/idle/jump animation.
## Structure: Visual (this, yaw) -> Pivot (stumble tilt, at body centre) -> Rig (parts).

const BODY_CENTRE_Y: float = 0.7

@export var walk_cycle_speed: float = 2.6
@export var limb_swing: float = 0.9
@export var move_speed_reference: float = 6.0

var pivot: Node3D
var rig: Node3D
## Superman dive pose (catapult flight).
var diving: bool = false
## Sitting in a dodgem car: hands on the wheel, no walking.
var driving: bool = false

var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _body: MeshInstance3D
var _phase: float = 0.0
var _idle_time: float = 0.0
var _blend: float = 0.0
var _swing_left: float = 0.0


## [param _hat_colour] is kept for callers but unused: contestants have no hats.
func setup(body_colour: Color, _hat_colour: Color = Color(0.1, 0.6, 0.2)) -> void:
	for child in get_children():
		child.queue_free()
	pivot = Node3D.new()
	pivot.name = "Pivot"
	pivot.position = Vector3(0.0, BODY_CENTRE_Y, 0.0)
	add_child(pivot)
	rig = Node3D.new()
	rig.name = "Rig"
	rig.position = Vector3(0.0, -BODY_CENTRE_Y, 0.0)
	pivot.add_child(rig)
	_build_body(body_colour)
	_build_face()
	_arm_l = _build_arm(-0.46, body_colour)
	_arm_r = _build_arm(0.46, body_colour)
	_leg_l = _build_leg(-0.17)
	_leg_r = _build_leg(0.17)


## Big right-arm slash (the sword swipe).
func swing_arm() -> void:
	_swing_left = 0.4


## Call every frame with the horizontal speed and grounded state.
func update_motion(speed: float, on_floor: bool, delta: float) -> void:
	if rig == null:
		return
	if _swing_left > 0.0:
		_swing_left -= delta
		_update_swing()
		if _swing_left <= 0.0 and _arm_r != null:
			_arm_r.rotation.y = 0.0
	rig.rotation.x = lerp_angle(rig.rotation.x, -1.25 if diving else 0.0, 10.0 * delta)
	if driving and not diving:
		_set_x(_arm_l, -1.2, delta)
		_set_x(_arm_r, -1.2, delta)
		_set_x(_leg_l, -1.4, delta)
		_set_x(_leg_r, -1.4, delta)
		rig.position.y = -BODY_CENTRE_Y + 0.12
		return
	if diving:
		_set_x(_arm_l, -3.0, delta)
		_set_x(_arm_r, -3.0, delta)
		_set_x(_leg_l, 0.2, delta)
		_set_x(_leg_r, 0.2, delta)
		return
	var target_blend := clampf(speed / maxf(move_speed_reference, 0.01), 0.0, 1.0) if on_floor else 0.0
	_blend = lerpf(_blend, target_blend, 10.0 * delta)
	_phase += speed * walk_cycle_speed * delta
	_idle_time += delta
	var swing := sin(_phase) * limb_swing * _blend
	if on_floor:
		_set_x(_leg_l, swing, delta)
		_set_x(_leg_r, -swing, delta)
		_set_x(_arm_l, -swing * 0.8, delta)
		_set_x(_arm_r, swing * 0.8, delta)
		rig.position.y = -BODY_CENTRE_Y + absf(sin(_phase)) * 0.06 * _blend
		if _body != null:
			var breathe := 1.0 + sin(_idle_time * 3.0) * 0.02 * (1.0 - _blend)
			_body.scale = Vector3(breathe, 1.0 / breathe, breathe)
	else:
		_set_x(_leg_l, 0.5, delta)
		_set_x(_leg_r, -0.3, delta)
		_set_x(_arm_l, -2.4, delta)
		_set_x(_arm_r, -2.4, delta)
		rig.position.y = -BODY_CENTRE_Y
		if _body != null:
			_body.scale = Vector3(0.95, 1.08, 0.95)


## Dance pose for the start screen. [param beat] counts music beats; styles:
## 0 disco point, 1 rave arms-up pump, 2 running man.
func dance(beat: float, style: int) -> void:
	if rig == null:
		return
	var ph := beat * PI
	var bounce := absf(sin(ph))
	rig.position.y = -BODY_CENTRE_Y + bounce * 0.18
	rig.rotation.x = 0.0
	match style % 3:
		0:
			var up := fmod(beat, 2.0) < 1.0
			_arm_r.rotation = Vector3(-2.7 if up else -0.5, 0.0, 0.6 if up else 0.1)
			_arm_l.rotation = Vector3(-0.3, 0.0, -0.4)
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = -0.25 * bounce
			pivot.rotation = Vector3(0.0, 0.0, sin(ph) * 0.12)
		1:
			var a := -2.9 + bounce * 0.6
			_arm_l.rotation = Vector3(a, 0.0, -0.3)
			_arm_r.rotation = Vector3(a, 0.0, 0.3)
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = 0.0
			pivot.rotation = Vector3(-0.1 * bounce, 0.0, 0.0)
		_:
			var sw := sin(ph)
			_leg_l.rotation.x = sw * 0.7
			_leg_r.rotation.x = -sw * 0.7
			_arm_l.rotation = Vector3(-sw * 1.2 - 0.3, 0.0, -0.1)
			_arm_r.rotation = Vector3(sw * 1.2 - 0.3, 0.0, 0.1)
			pivot.rotation = Vector3(0.0, sin(ph * 0.5) * 0.4, 0.0)


func _update_swing() -> void:
	if _arm_r == null:
		return
	# Arm sweeps from out to the right across to the left, held up and forward.
	var k := clampf(1.0 - _swing_left / 0.4, 0.0, 1.0)
	_arm_r.rotation = Vector3(-1.5, lerpf(-1.2, 1.4, minf(k * 2.0, 1.0)), 0.0)
	if pivot != null:
		pivot.rotation.y = lerpf(-0.35, 0.35, minf(k * 2.0, 1.0)) * (1.0 - k)


func _set_x(node: Node3D, target: float, delta: float) -> void:
	if node != null:
		node.rotation.x = lerp_angle(node.rotation.x, target, 12.0 * delta)


func _sphere(radius: float, colour: Color, pos: Vector3, parent: Node3D, flatten: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * flatten
	mesh.material = CourseBuilder.make_material(colour)
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _capsule(radius: float, height: float, colour: Color, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.material = CourseBuilder.make_material(colour)
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_body(colour: Color) -> void:
	_body = _capsule(0.4, 1.25, colour, Vector3(0.0, 0.72, 0.0), rig)
	_body.name = "Body"
	var belt := CourseBuilder.make_cylinder_mesh(0.42, 0.12, Color(0.1, 0.1, 0.1))
	belt.position = Vector3(0.0, 0.5, 0.0)
	rig.add_child(belt)
	var buckle := CourseBuilder.make_box_mesh(Vector3(0.16, 0.14, 0.04), Color(1.0, 0.8, 0.1))
	buckle.position = Vector3(0.0, 0.5, -0.42)
	rig.add_child(buckle)


func _build_face() -> void:
	for x: float in [-0.14, 0.14]:
		_sphere(0.09, Color.WHITE, Vector3(x, 1.02, -0.33), rig)
		_sphere(0.045, Color.BLACK, Vector3(x, 1.02, -0.4), rig)
	var beard := CourseBuilder.make_box_mesh(Vector3(0.46, 0.24, 0.18), Color(0.9, 0.45, 0.1))
	beard.name = "Beard"
	beard.position = Vector3(0.0, 0.78, -0.33)
	rig.add_child(beard)
	var tash := CourseBuilder.make_box_mesh(Vector3(0.3, 0.07, 0.08), Color(0.9, 0.45, 0.1))
	tash.position = Vector3(0.0, 0.92, -0.42)
	rig.add_child(tash)
	_sphere(0.06, Color(1.0, 0.6, 0.5), Vector3(0.0, 0.95, -0.44), rig)


func _build_arm(x: float, colour: Color) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.name = "ArmL" if x < 0.0 else "ArmR"
	shoulder.position = Vector3(x, 0.95, 0.0)
	rig.add_child(shoulder)
	_capsule(0.1, 0.42, colour, Vector3(0.0, -0.22, 0.0), shoulder)
	_sphere(0.1, Color(1.0, 0.8, 0.65), Vector3(0.0, -0.46, 0.0), shoulder)
	return shoulder


func _build_leg(x: float) -> Node3D:
	var hip := Node3D.new()
	hip.name = "LegL" if x < 0.0 else "LegR"
	hip.position = Vector3(x, 0.3, 0.0)
	rig.add_child(hip)
	_capsule(0.11, 0.32, Color(0.2, 0.45, 0.15), Vector3(0.0, -0.1, 0.0), hip)
	var shoe := CourseBuilder.make_box_mesh(Vector3(0.22, 0.12, 0.34), Color(0.1, 0.1, 0.1))
	shoe.position = Vector3(0.0, -0.26, -0.06)
	hip.add_child(shoe)
	var buckle := CourseBuilder.make_box_mesh(Vector3(0.1, 0.08, 0.03), Color(1.0, 0.8, 0.1))
	buckle.position = Vector3(0.0, -0.22, -0.24)
	hip.add_child(buckle)
	return hip
