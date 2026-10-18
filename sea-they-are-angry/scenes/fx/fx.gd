class_name FX
extends RefCounted
## Particle effects, built in code. Chunky low-poly droplets and puffs to match
## the faceted look. One-shot effects free themselves when they finish.

static var _drop_mesh: Mesh
static var _puff_mesh: Mesh
static var _chunk_mesh: Mesh

static func _meshes() -> void:
	if _drop_mesh != null:
		return
	var d := SphereMesh.new()
	d.radius = 0.06
	d.height = 0.12
	d.radial_segments = 5
	d.rings = 3
	_drop_mesh = d
	var p := SphereMesh.new()
	p.radius = 0.35
	p.height = 0.7
	p.radial_segments = 6
	p.rings = 3
	_puff_mesh = p
	var c := BoxMesh.new()
	c.size = Vector3(0.1, 0.06, 0.08)
	_chunk_mesh = c

static func _mat(emissive: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.4
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.25)
		m.emission_energy_multiplier = emissive
	return m

static func _fade(c: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

static func _shrink() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.2))
	var t := CurveTexture.new()
	t.curve = c
	return t

static func _grow() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.4))
	c.add_point(Vector2(1.0, 1.4))
	var t := CurveTexture.new()
	t.curve = c
	return t

## Builds a particle emitter. one_shot emitters free themselves when done.
static func emitter(parent: Node, at: Vector3, mesh: Mesh, color: Color, amount: int, lifetime: float,
		dir: Vector3, spread: float, speed_min: float, speed_max: float, gravity: float,
		scale_min: float, scale_max: float, one_shot: bool = true, grow: bool = false,
		emissive: float = 0.0, box: Vector3 = Vector3.ZERO) -> GPUParticles3D:
	if parent == null or not parent.is_inside_tree():
		return null
	_meshes()
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = spread
	pm.initial_velocity_min = speed_min
	pm.initial_velocity_max = speed_max
	pm.gravity = Vector3(0.0, -gravity, 0.0)
	pm.scale_min = scale_min
	pm.scale_max = scale_max
	pm.color_ramp = _fade(color)
	pm.scale_curve = _grow() if grow else _shrink()
	pm.angular_velocity_min = -180.0
	pm.angular_velocity_max = 180.0
	pm.damping_min = 0.5
	pm.damping_max = 1.5
	if box != Vector3.ZERO:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = box
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.material_override = _mat(emissive, emissive > 0.0)
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = one_shot
	p.explosiveness = 0.92 if one_shot else 0.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 12, 12))
	parent.add_child(p)
	p.global_position = at
	if one_shot:
		p.finished.connect(p.queue_free)
	p.emitting = true
	return p

# ---- named effects ----

## Water bursting up as something breaks the surface.
static func splash(parent: Node, at: Vector3, size: float = 1.0) -> void:
	_meshes()
	emitter(parent, at, _drop_mesh, Color(0.75, 0.86, 0.9, 0.9), int(26 * size), 0.9, Vector3.UP, 28.0, 2.5 * size, 4.5 * size, 9.0, 0.6, 1.4)
	emitter(parent, at, _puff_mesh, Color(0.85, 0.9, 0.92, 0.45), 6, 1.0, Vector3.UP, 80.0, 0.4, 1.0, 0.0, 0.5 * size, 0.9 * size, true, true)

## The Bloated bursting: green-yellow gore, a sickly mist, and a flash.
static func burst(parent: Node, at: Vector3) -> void:
	_meshes()
	emitter(parent, at, _chunk_mesh, Color(0.45, 0.55, 0.28, 1.0), 40, 1.1, Vector3.UP, 75.0, 3.0, 7.0, 12.0, 0.8, 2.2)
	emitter(parent, at, _drop_mesh, Color(0.7, 0.85, 0.35, 0.95), 50, 0.9, Vector3.UP, 85.0, 2.0, 6.0, 9.0, 0.8, 1.8)
	emitter(parent, at, _puff_mesh, Color(0.6, 0.75, 0.4, 0.5), 14, 1.8, Vector3.UP, 90.0, 0.8, 2.2, -0.3, 1.0, 2.2, true, true)
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.7, 1.0, 0.45)
	flash.light_energy = 6.0
	flash.omni_range = 7.0
	parent.add_child(flash)
	flash.global_position = at + Vector3(0.0, 0.5, 0.0)
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.45)
	tw.tween_callback(flash.queue_free)

## Spray of droplets when something is struck.
static func spray(parent: Node, at: Vector3, dir: Vector3, color: Color) -> void:
	_meshes()
	emitter(parent, at, _drop_mesh, Color(color.r, color.g, color.b, 0.95), 14, 0.55, (dir + Vector3.UP * 0.6).normalized(), 35.0, 2.0, 4.0, 9.0, 0.5, 1.1)

## A puff of steam and embers from a creature being burned by the focused beam.
static func steam(parent: Node, at: Vector3) -> void:
	_meshes()
	emitter(parent, at, _puff_mesh, Color(0.85, 0.82, 0.78, 0.4), 3, 1.4, Vector3.UP, 20.0, 0.8, 1.5, -0.4, 0.3, 0.6, true, true)
	emitter(parent, at, _drop_mesh, Color(1.0, 0.6, 0.2, 1.0), 4, 0.8, Vector3.UP, 40.0, 1.0, 2.5, -0.5, 0.4, 0.8, true, false, 3.0)

## Splinters off a fence or building being battered.
static func splinters(parent: Node, at: Vector3) -> void:
	_meshes()
	emitter(parent, at, _chunk_mesh, Color(0.45, 0.34, 0.22, 1.0), 12, 0.8, Vector3.UP, 60.0, 2.0, 4.0, 10.0, 0.6, 1.3)

## Sparks when the lamp is lit.
static func sparks(parent: Node, at: Vector3) -> void:
	_meshes()
	emitter(parent, at, _drop_mesh, Color(1.0, 0.75, 0.3, 1.0), 30, 1.0, Vector3.UP, 70.0, 1.5, 4.0, 4.0, 0.3, 0.7, true, false, 4.0)

## Continuous chimney smoke.
static func chimney_smoke(parent: Node, at: Vector3) -> GPUParticles3D:
	_meshes()
	return emitter(parent, at, _puff_mesh, Color(0.62, 0.62, 0.64, 0.38), 14, 4.5, Vector3(0.3, 1.0, 0.1).normalized(), 12.0, 0.4, 0.8, -0.15, 0.4, 0.8, false, true)

## Spray thrown up where swell hits the rocks.
static func sea_spray(parent: Node, at: Vector3) -> void:
	_meshes()
	emitter(parent, at, _drop_mesh, Color(0.85, 0.92, 0.95, 0.85), 22, 1.1, Vector3.UP, 30.0, 2.0, 4.0, 7.0, 0.8, 1.6, true, false, 0.0, Vector3(0.6, 0.1, 0.6))
