class_name Gull
extends Node3D
## A herring gull circling the rock by day. Gone at dusk, back at dawn.

var seed_value := 0
var _t := 0.0
var _radius := 10.0
var _height := 10.0
var _speed := 0.25
var _wing_l: Node3D
var _wing_r: Node3D
var _flap := 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_t = rng.randf() * TAU
	_radius = rng.randf_range(7.0, 15.0)
	_height = rng.randf_range(5.5, 8.0)
	_speed = rng.randf_range(0.16, 0.3) * (1.0 if rng.randf() < 0.5 else -1.0)
	_flap = rng.randf() * TAU
	scale = Vector3.ONE * 0.6
	var white := Look.flat_mat(Color(0.93, 0.93, 0.9), 0.7)
	var grey := Look.flat_mat(Color(0.55, 0.58, 0.62), 0.7)
	var body := Geo.box(self, Vector3(0.14, 0.12, 0.5), Color.WHITE, Vector3.ZERO)
	body.material_override = white
	var beak := Geo.box(self, Vector3(0.04, 0.04, 0.1), Color(0.95, 0.75, 0.2), Vector3(0.0, 0.02, -0.29))
	beak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wing_l = Node3D.new()
	_wing_r = Node3D.new()
	add_child(_wing_l)
	add_child(_wing_r)
	for side in [[_wing_l, -1.0], [_wing_r, 1.0]]:
		var pivot: Node3D = side[0]
		var s: float = side[1]
		var w := Geo.box(pivot, Vector3(0.5, 0.03, 0.2), Color.WHITE, Vector3(s * 0.28, 0.0, 0.0))
		w.material_override = white
		var tip := Geo.box(pivot, Vector3(0.22, 0.025, 0.14), Color.WHITE, Vector3(s * 0.62, 0.0, 0.03))
		tip.material_override = grey
	Cycle.phase_changed.connect(_on_phase)
	visible = Cycle.phase == Cycle.Phase.DAY or Cycle.phase == Cycle.Phase.DAWN

func _on_phase(p: int) -> void:
	visible = p == Cycle.Phase.DAY or p == Cycle.Phase.DAWN

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta * _speed
	_flap += delta * 5.0
	var wobble := sin(_t * 3.0) * 1.5
	var pos := Vector3(sin(_t) * (_radius + wobble), _height + sin(_t * 2.0) * 0.8, cos(_t) * (_radius + wobble))
	var ahead := Vector3(sin(_t + 0.05 * signf(_speed)) * _radius, _height, cos(_t + 0.05 * signf(_speed)) * _radius)
	position = pos
	look_at(ahead, Vector3.UP)
	rotation.z = -0.35 * signf(_speed)
	# Flap in bursts, glide in between.
	var flapping := sin(_t * 1.7) > -0.2
	var a := sin(_flap) * 0.55 if flapping else 0.08
	_wing_l.rotation.z = a
	_wing_r.rotation.z = -a
