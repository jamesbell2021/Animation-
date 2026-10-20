class_name Pendulum
extends Node3D
## Something hanging from a point that moves, like a lantern from a keeper's hand. Whatever
## the hand does, it hangs plumb; when the hand moves it swings, lagging behind, swinging
## past and settling like a weight on a short bail. Put what hangs in `hang` (it hangs
## along -Y from this node).

const GRAVITY := 9.8

## How long the bail is (m): a longer one swings slower.
var length := 0.22
## How fast a swing dies away (per second).
var damping := 1.4
## The furthest it swings from plumb (radians).
var max_angle := 1.1
## What it hangs from turns it about the vertical too (a lantern faces the way its
## keeper does); null keeps this node's own turn.
var follow: Node3D
var hang: Node3D

var _bob := Vector3.INF
var _prev := Vector3.ZERO

func _init() -> void:
	hang = Node3D.new()
	hang.name = "Hang"
	add_child(hang)

func _physics_process(delta: float) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	var pivot := global_position
	# Position-based: the weight carries on as it was going, gravity pulls it down, and
	# the bail holds it at its length from the hand, so the hand drags it about.
	if _bob == Vector3.INF or _bob.distance_to(pivot) > length * 6.0:
		_bob = pivot + Vector3.DOWN * length
		_prev = _bob
	var next := _bob + (_bob - _prev) * maxf(0.0, 1.0 - damping * delta) + Vector3.DOWN * GRAVITY * delta * delta
	_prev = _bob
	var d := next - pivot
	var dn := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var ang := dn.angle_to(Vector3.DOWN)
	if ang > max_angle:
		var axis := Vector3.DOWN.cross(dn)
		dn = Vector3.DOWN.rotated(axis.normalized(), max_angle) if axis.length() > 0.0001 else Vector3.DOWN
	_bob = pivot + dn * length
	var yaw := follow.global_rotation.y if follow != null else global_rotation.y
	var scale_now := global_basis.get_scale()
	hang.global_basis = (Basis(Quaternion(Vector3.DOWN, dn)) * Basis(Vector3.UP, yaw)).scaled(scale_now)

## Let it hang still again (after a teleport).
func settle() -> void:
	_bob = Vector3.INF
