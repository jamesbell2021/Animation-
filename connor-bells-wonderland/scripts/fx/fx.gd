class_name FX
extends RefCounted
## Particle effects. FX.burst() spawns a one-shot burst that cleans itself up;
## FX.attach() adds a looping emitter to a node (trails, auras) and returns it.
## Everything is CPUParticles3D with small, shared meshes so it runs on phones.

const BURSTS := {
	# name: amount, lifetime, speed [min, max], spread, gravity, size, shape, colours, damping, radius, up
	"dust": {"amount": 18, "life": 0.6, "speed": [1.5, 3.5], "spread": 75.0, "gravity": -1.0, "size": 0.32, "shape": "puff", "colours": [Color(0.55, 0.5, 0.45, 0.8), Color(0.35, 0.33, 0.3, 0.0)], "damping": 4.0, "radius": 0.3, "up": 0.25},
	"impact": {"amount": 26, "life": 0.4, "speed": [5.0, 11.0], "spread": 180.0, "gravity": -6.0, "size": 0.12, "shape": "spark", "colours": [Color(3.0, 2.6, 1.6), Color(2.0, 0.8, 0.1, 0.0)], "damping": 6.0, "radius": 0.2, "up": 0.0},
	"sparks": {"amount": 30, "life": 0.5, "speed": [4.0, 9.0], "spread": 180.0, "gravity": -9.0, "size": 0.1, "shape": "spark", "colours": [Color(2.2, 2.2, 2.2), Color(1.0, 1.0, 1.0, 0.0)], "damping": 3.0, "radius": 0.2, "up": 0.0},
	"coins": {"amount": 14, "life": 0.7, "speed": [3.0, 6.0], "spread": 35.0, "gravity": -14.0, "size": 0.16, "shape": "spark", "colours": [Color(2.4, 1.8, 0.3), Color(1.5, 1.0, 0.1, 0.0)], "damping": 0.5, "radius": 0.2, "up": 1.0},
	"sparkle": {"amount": 24, "life": 0.7, "speed": [2.0, 5.0], "spread": 180.0, "gravity": 1.5, "size": 0.12, "shape": "spark", "colours": [Color(2.0, 2.0, 2.0), Color(1.0, 1.0, 1.0, 0.0)], "damping": 3.0, "radius": 0.4, "up": 0.0},
	"fire": {"amount": 30, "life": 0.6, "speed": [3.0, 8.0], "spread": 180.0, "gravity": 3.0, "size": 0.55, "shape": "puff", "colours": [Color(3.0, 2.2, 0.8), Color(2.2, 0.6, 0.05, 0.9), Color(0.2, 0.1, 0.1, 0.0)], "damping": 5.0, "radius": 0.5, "up": 0.0},
	"smoke": {"amount": 16, "life": 1.4, "speed": [0.8, 2.5], "spread": 60.0, "gravity": 1.2, "size": 0.7, "shape": "puff", "colours": [Color(0.25, 0.25, 0.27, 0.7), Color(0.1, 0.1, 0.1, 0.0)], "damping": 1.5, "radius": 0.6, "up": 1.0},
	"poof": {"amount": 20, "life": 0.6, "speed": [2.0, 4.0], "spread": 180.0, "gravity": 0.5, "size": 0.45, "shape": "puff", "colours": [Color(0.9, 0.9, 0.95, 0.8), Color(0.6, 0.6, 0.7, 0.0)], "damping": 5.0, "radius": 0.4, "up": 0.0},
	"custard": {"amount": 26, "life": 0.8, "speed": [3.0, 7.0], "spread": 70.0, "gravity": -16.0, "size": 0.2, "shape": "blob", "colours": [Color(1.0, 0.88, 0.35), Color(0.95, 0.8, 0.3, 0.0)], "damping": 0.5, "radius": 0.3, "up": 1.0},
	"paint": {"amount": 24, "life": 0.7, "speed": [3.0, 7.0], "spread": 70.0, "gravity": -16.0, "size": 0.18, "shape": "blob", "colours": [Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)], "damping": 0.5, "radius": 0.2, "up": 0.0},
	"crumbs": {"amount": 22, "life": 0.8, "speed": [2.0, 5.0], "spread": 80.0, "gravity": -14.0, "size": 0.12, "shape": "blob", "colours": [Color(0.5, 0.28, 0.12), Color(0.9, 0.85, 0.75, 0.0)], "damping": 0.5, "radius": 0.4, "up": 1.0},
	"oil": {"amount": 18, "life": 0.7, "speed": [2.0, 4.5], "spread": 60.0, "gravity": -14.0, "size": 0.16, "shape": "blob", "colours": [Color(0.08, 0.06, 0.1), Color(0.2, 0.1, 0.3, 0.0)], "damping": 0.5, "radius": 0.3, "up": 1.0},
	"magic": {"amount": 30, "life": 0.9, "speed": [1.5, 4.0], "spread": 180.0, "gravity": 2.0, "size": 0.14, "shape": "spark", "colours": [Color(0.6, 2.2, 0.8), Color(1.4, 0.4, 2.2, 0.0)], "damping": 2.0, "radius": 0.5, "up": 0.0},
	"electric": {"amount": 28, "life": 0.35, "speed": [4.0, 10.0], "spread": 180.0, "gravity": 0.0, "size": 0.1, "shape": "spark", "colours": [Color(1.2, 2.6, 3.0), Color(0.5, 1.5, 3.0, 0.0)], "damping": 8.0, "radius": 0.4, "up": 0.0},
	"peony": {"amount": 80, "life": 1.7, "speed": [8.0, 9.5], "spread": 180.0, "gravity": -3.0, "size": 0.09, "shape": "spark", "colours": [Color(1.6, 1.6, 1.6), Color(1.0, 1.0, 1.0), Color(0.6, 0.6, 0.6, 0.0)], "damping": 7.0, "radius": 0.2, "up": 0.0},
	"willow": {"amount": 90, "life": 2.8, "speed": [6.0, 8.0], "spread": 180.0, "gravity": -3.0, "size": 0.11, "shape": "spark", "colours": [Color(3.0, 2.3, 0.9), Color(2.2, 1.2, 0.3, 0.9), Color(0.7, 0.25, 0.05, 0.0)], "damping": 5.0, "radius": 0.2, "up": 0.0},
	"crackle": {"amount": 70, "life": 1.3, "speed": [5.0, 8.0], "spread": 180.0, "gravity": -2.0, "size": 0.08, "shape": "spark", "colours": [Color(3.0, 3.0, 3.0), Color(0.2, 0.2, 0.2), Color(3.0, 3.0, 3.0), Color(0.3, 0.3, 0.3), Color(2.5, 2.5, 2.5, 0.0)], "damping": 6.0, "radius": 0.6, "up": 0.0},
	"fireworks": {"amount": 90, "life": 1.8, "speed": [7.0, 10.0], "spread": 180.0, "gravity": -3.0, "size": 0.09, "shape": "spark", "colours": [], "damping": 6.5, "radius": 0.3, "up": 0.0},
}

const TRAILS := {
	"flames": {"amount": 30, "life": 0.35, "speed": [1.5, 3.0], "spread": 20.0, "gravity": 4.0, "size": 0.3, "shape": "puff", "colours": [Color(3.0, 2.0, 0.6), Color(2.4, 0.6, 0.05, 0.8), Color(0.2, 0.1, 0.1, 0.0)], "dir": Vector3(0, -1, 0)},
	"magnet": {"amount": 18, "life": 0.6, "speed": [0.5, 1.5], "spread": 180.0, "gravity": 0.0, "size": 0.1, "shape": "spark", "colours": [Color(0.4, 2.0, 3.0), Color(0.4, 1.0, 3.0, 0.0)], "dir": Vector3.UP},
	"shield": {"amount": 16, "life": 0.8, "speed": [0.2, 0.6], "spread": 180.0, "gravity": 0.5, "size": 0.09, "shape": "spark", "colours": [Color(0.8, 2.0, 3.0), Color(0.5, 1.5, 3.0, 0.0)], "dir": Vector3.UP},
	"charge": {"amount": 24, "life": 0.4, "speed": [1.0, 3.0], "spread": 180.0, "gravity": 0.0, "size": 0.11, "shape": "spark", "colours": [Color(3.0, 1.6, 0.3), Color(3.0, 0.6, 0.1, 0.0)], "dir": Vector3.UP},
	"electric": {"amount": 22, "life": 0.25, "speed": [2.0, 6.0], "spread": 180.0, "gravity": 0.0, "size": 0.09, "shape": "spark", "colours": [Color(1.2, 2.6, 3.0), Color(0.5, 1.5, 3.0, 0.0)], "dir": Vector3.UP},
	"drips": {"amount": 8, "life": 0.6, "speed": [0.2, 0.6], "spread": 30.0, "gravity": -10.0, "size": 0.1, "shape": "blob", "colours": [Color(0.08, 0.06, 0.1), Color(0.2, 0.1, 0.3, 0.0)], "dir": Vector3.DOWN},
	"rocket": {"amount": 26, "life": 0.45, "speed": [0.5, 1.5], "spread": 15.0, "gravity": -2.0, "size": 0.13, "shape": "spark", "colours": [Color(3.0, 2.0, 0.8), Color(2.0, 0.6, 0.1, 0.6), Color(0.3, 0.1, 0.05, 0.0)], "dir": Vector3.DOWN},
	"sparkle": {"amount": 10, "life": 0.9, "speed": [0.3, 1.0], "spread": 180.0, "gravity": 0.6, "size": 0.08, "shape": "spark", "colours": [Color(2.0, 2.0, 2.0), Color(1.0, 1.0, 1.0, 0.0)], "dir": Vector3.UP},
}

static var _meshes: Dictionary = {}
static var _glow_texture: GradientTexture2D


## One-shot burst named [param kind] at world [param pos]. [param tint] recolours
## the effect (white keeps the preset colours); [param size] scales it.
static func burst(anchor: Node, kind: String, pos: Vector3, tint: Color = Color.WHITE, size: float = 1.0) -> void:
	if anchor == null or not anchor.is_inside_tree() or not BURSTS.has(kind):
		return
	var cfg: Dictionary = BURSTS[kind]
	var p := _particles(cfg, tint, size, kind == "fireworks")
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(cfg["radius"]) * size
	# Damping scales with size too, so a burst twice the size spreads twice as far.
	p.damping_min = float(cfg["damping"]) * size
	p.damping_max = float(cfg["damping"]) * size * 1.2
	_root(anchor).add_child(p)
	p.global_position = pos + Vector3.UP * float(cfg["up"])
	p.emitting = true
	anchor.get_tree().create_timer(p.lifetime + 0.4, false).timeout.connect(p.queue_free)


## Expanding glowing ring on the ground (shockwaves, landings, bounce pads).
static func ring(anchor: Node, pos: Vector3, radius: float, colour: Color = Color(1.0, 0.6, 0.2)) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var ring_node := RingFx.new()
	ring_node.max_radius = radius
	ring_node.colour = colour
	_root(anchor).add_child(ring_node)
	ring_node.global_position = pos + Vector3.UP * 0.08


## Looping emitter attached to [param node] (local [param offset]). Free it to stop.
static func attach(node: Node3D, kind: String, offset: Vector3 = Vector3.ZERO, tint: Color = Color.WHITE) -> CPUParticles3D:
	if node == null or not TRAILS.has(kind):
		return null
	var cfg: Dictionary = TRAILS[kind]
	var p := _particles(cfg, tint, 1.0, false)
	p.direction = cfg["dir"]
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.local_coords = false
	p.position = offset
	p.name = "Fx_" + kind
	node.add_child(p)
	p.emitting = true
	return p


## Looping emitter that removes itself after [param seconds].
static func attach_for(node: Node3D, kind: String, seconds: float, offset: Vector3 = Vector3.ZERO) -> void:
	var p := attach(node, kind, offset)
	if p != null:
		node.get_tree().create_timer(seconds, false).timeout.connect(p.queue_free)


## Where effects go: the 3D scene root. On menu screens (a 2D root) that's the
## top-most 3D node above the anchor; particles under a 2D node draw in the wrong place.
static func _root(anchor: Node) -> Node:
	var scene := anchor.get_tree().current_scene
	if scene is Node3D:
		return scene
	var top: Node = null
	var node := anchor
	while node != null:
		if node is Node3D:
			top = node
		node = node.get_parent()
	if top != null:
		return top
	return scene if scene != null else anchor.get_tree().root


static func _particles(cfg: Dictionary, tint: Color, size: float, multicolour: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = int(cfg["amount"])
	p.lifetime = float(cfg["life"])
	var speed: Array = cfg["speed"]
	p.initial_velocity_min = float(speed[0]) * size
	p.initial_velocity_max = float(speed[1]) * size
	p.spread = float(cfg["spread"])
	p.gravity = Vector3(0.0, float(cfg["gravity"]), 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	p.scale_amount_curve = curve
	p.mesh = _mesh(str(cfg["shape"]), float(cfg["size"]) * clampf(size, 0.5, 2.5))
	var gradient := Gradient.new()
	var colours: Array = cfg["colours"]
	if multicolour or colours.is_empty():
		gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		gradient.colors = PackedColorArray([Color(2.5, 2.5, 2.5), Color(2.0, 2.0, 2.0), Color(1.0, 1.0, 1.0, 0.0)])
		var hues := Gradient.new()
		hues.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
		hues.colors = PackedColorArray([CourseBuilder.accent(0) * 2.0, CourseBuilder.accent(1) * 2.0, CourseBuilder.accent(2) * 2.0, CourseBuilder.accent(3) * 2.0])
		p.color_initial_ramp = hues
	else:
		var offs := PackedFloat32Array()
		var cols := PackedColorArray()
		for i in range(colours.size()):
			offs.append(float(i) / float(colours.size() - 1))
			var c: Color = colours[i]
			cols.append(Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
		gradient.offsets = offs
		gradient.colors = cols
	p.color_ramp = gradient
	return p


static func _mesh(shape: String, size: float) -> Mesh:
	var key := "%s_%.2f" % [shape, size]
	if _meshes.has(key):
		return _meshes[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: Mesh
	match shape:
		"puff", "blob":
			var sphere := SphereMesh.new()
			sphere.radius = size * 0.5
			sphere.height = size
			sphere.radial_segments = 8
			sphere.rings = 4
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
			sphere.material = mat
			mesh = sphere
		_:
			# Soft round glow (stretched into a streak) rather than a hard rectangle.
			mat.albedo_texture = _glow()
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			var quad := QuadMesh.new()
			quad.size = Vector2(size * 1.6, size * 2.8)
			quad.material = mat
			mesh = quad
	_meshes[key] = mesh
	return mesh


static func _glow() -> GradientTexture2D:
	if _glow_texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = g
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
		_glow_texture.width = 32
		_glow_texture.height = 32
	return _glow_texture
