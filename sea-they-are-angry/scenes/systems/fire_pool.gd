class_name FirePool
extends Node3D
## Burning bio spread on the ground where a petrol bomb smashed: anything that walks
## through it is set alight and burns. It dies down after a few seconds.

const RADIUS := 2.3
const LIFE := 7.0
const DPS := 16.0
const BURN := 2.0

var thrower: Node
var _t := 0.0
var _acc := {}
var _light: OmniLight3D
var _fire: GPUParticles3D

func _ready() -> void:
	add_to_group("fire_pools")
	_fire = FX.emitter(self, global_position + Vector3(0.0, 0.1, 0.0), FX._puff_mesh_ref(), Color(1.0, 0.5, 0.12, 0.9),
		40, 0.8, Vector3.UP, 15.0, 1.0, 2.2, -1.5, 0.5, 1.2, false, true, 4.0, Vector3(RADIUS * 0.7, 0.05, RADIUS * 0.7))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.18)
	_light.light_energy = 4.0
	_light.omni_range = RADIUS * 3.5
	_light.position = Vector3(0.0, 0.8, 0.0)
	add_child(_light)

func is_burning() -> bool:
	return _t < LIFE

func _physics_process(delta: float) -> void:
	_t += delta
	var left := clampf((LIFE - _t) / 1.5, 0.0, 1.0)
	_light.light_energy = (3.5 + randf_range(-0.7, 0.7)) * left
	if _t >= LIFE:
		if _fire != null:
			_fire.emitting = false
		if _t >= LIFE + 1.0:
			queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not Arsenal._live(e) or Geo.flat_dist(e.global_position, global_position) > RADIUS or absf(e.global_position.y - global_position.y) > 1.5:
			continue
		e.set_alight(BURN)
		var acc: float = float(_acc.get(e, 0.0)) + DPS * delta
		if acc >= 1.0:
			var n := int(acc)
			acc -= float(n)
			Arsenal.strike(e, n, Vector3.ZERO, null, "bomb")
		_acc[e] = acc
