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
var _flames: Array[MeshInstance3D] = []
const FLAMES := 7

func _ready() -> void:
	add_to_group("fire_pools")
	# Pixel flames standing up all over the spill, the biggest in the middle.
	var rng := RandomNumberGenerator.new()
	rng.seed = get_instance_id()
	for i in FLAMES:
		var a := TAU * float(i) / float(FLAMES) + rng.randf_range(-0.3, 0.3)
		var r := 0.0 if i == 0 else rng.randf_range(0.5, RADIUS * 0.8)
		var h := rng.randf_range(1.2, 2.2) * (1.25 if i == 0 else 1.0)
		var w := rng.randf_range(0.9, 1.5)
		var at := Vector3(sin(a) * r, 0.0, cos(a) * r)
		at.y = Terrain.height_at(global_position.x + at.x, global_position.z + at.z) - global_position.y
		_flames.append(PixelFire.sprite(self, at + Vector3(0.0, h * 0.45, 0.0), Vector2(w, h), rng.randf() * 50.0))
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
	for f in _flames:
		f.set_instance_shader_parameter("fade", left)
		f.visible = left > 0.02
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
