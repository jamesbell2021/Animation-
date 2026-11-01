class_name PixelFire
extends RefCounted
## The game's fire, drawn in coarse pixels with a stepped palette (shaders/pixel_fire.gdshader):
## the flamer's roaring jet and the billows it throws off, creatures burning, and the
## pools of burning bio a petrol bomb leaves.

static var _mats := {}
static var _quad: QuadMesh

static func material(mode: int, pixels: Vector2 = Vector2(14.0, 22.0)) -> ShaderMaterial:
	var key := "%d/%d/%d" % [mode, int(pixels.x), int(pixels.y)]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/pixel_fire.gdshader")
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("pixels", pixels)
	_mats[key] = m
	return m

static func _quad_mesh() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	return _quad

## A flame standing on its base: `size` wide and tall, its middle at `pos` (local).
static func sprite(parent: Node, pos: Vector3, size: Vector2, seed_value: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_mesh()
	mi.material_override = material(0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3(size.x, size.y, 1.0)
	parent.add_child(mi)
	mi.set_instance_shader_parameter("seed", seed_value)
	return mi

## The flamer's jet. Point it each frame with aim_jet().
static func jet(parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad_mesh()
	var m := material(1, Vector2(12.0, 30.0)).duplicate() as ShaderMaterial
	m.set_shader_parameter("speed", 3.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	parent.add_child(mi)
	return mi

## Lay the jet from `from` along `dir`, `length` long and `width` wide at its end.
static func aim_jet(mi: MeshInstance3D, from: Vector3, dir: Vector3, length: float, width: float) -> void:
	var axis := dir.normalized() * maxf(length, 0.01)
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized() * width
	var normal := side.cross(axis).normalized()
	mi.global_transform = Transform3D(Basis(side, axis, normal), from + axis * 0.5)

## Billows of fire rolling off the jet, burning down as they go.
static func billows(parent: Node, amount: int = 26) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.55
	p.emitting = false
	p.local_coords = false
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.visibility_aabb = AABB(Vector3(-8, -3, -8), Vector3(16, 8, 16))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.FORWARD
	pm.spread = 10.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 10.0
	pm.gravity = Vector3(0.0, 2.5, 0.0)
	pm.damping_min = 6.0
	pm.damping_max = 9.0
	pm.scale_min = 0.5
	pm.scale_max = 0.8
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(0.6, 1.6))
	grow.add_point(Vector2(1.0, 2.0))
	var ct := CurveTexture.new()
	ct.curve = grow
	pm.scale_curve = ct
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material(2, Vector2(10.0, 12.0))
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p
