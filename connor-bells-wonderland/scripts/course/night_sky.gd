class_name NightSky
extends Node3D
## Night sky for the race and the menu: a sky shader with twinkling stars, a
## Milky Way band and a big moon, plus shooting stars and the odd distant
## firework launched around whichever camera is active.

const SKY_SHADER := """
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.008, 0.012, 0.045);
uniform vec3 mid_color : source_color = vec3(0.035, 0.03, 0.11);
uniform vec3 horizon_color : source_color = vec3(0.32, 0.1, 0.16);
uniform vec3 ground_color : source_color = vec3(0.01, 0.01, 0.02);
uniform vec3 moon_dir = vec3(0.45, 0.3, -0.84);
uniform vec3 band_normal = vec3(0.35, 0.55, 0.76);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

vec3 stars(vec3 d, float scale, float density, float radius, float t) {
	vec3 p = d * scale;
	vec3 cell = floor(p);
	float r = hash13(cell);
	if (r > density) {
		return vec3(0.0);
	}
	r /= density;
	vec3 sp = vec3(hash13(cell + 17.1), hash13(cell + 41.7), hash13(cell + 73.3)) * 0.6 + 0.2;
	float b = smoothstep(radius, 0.0, length(fract(p) - sp));
	float twinkle = 0.55 + 0.45 * sin(t * (1.5 + r * 6.0) + r * 300.0);
	vec3 tint = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.85, 0.65), hash13(cell + 5.0));
	return tint * b * twinkle * (0.6 + r * 1.6);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.22, h));
	col = mix(col, top_color, smoothstep(0.18, 0.75, h));
	if (h < 0.0) {
		col = mix(horizon_color * 0.6, ground_color, smoothstep(0.0, 0.12, -h));
	}
	float t = AT_CUBEMAP_PASS ? 0.0 : TIME;
	float above = smoothstep(-0.01, 0.12, h);
	// Milky Way: a soft dusty band with extra stars in it.
	float band = exp(-pow(dot(d, normalize(band_normal)) / 0.16, 2.0));
	float dust = vnoise(d * 7.0) * 0.6 + vnoise(d * 19.0) * 0.4;
	col += vec3(0.1, 0.07, 0.16) * band * dust * above;
	col += stars(d, 110.0, 0.09 + band * 0.25, 0.22, t) * above;
	col += stars(d, 45.0, 0.05, 0.12, t) * above * 2.2;
	// The moon, with darker "seas" and a glow.
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	float disc = smoothstep(0.99935, 0.9995, m);
	float seas = vnoise(d * 140.0) * 0.6 + vnoise(d * 320.0) * 0.4;
	col = mix(col, vec3(1.0, 0.96, 0.86) * (1.5 - seas * 0.6), disc);
	col += vec3(0.5, 0.6, 0.9) * (pow(max(m, 0.0), 900.0) * 0.5 + pow(max(m, 0.0), 40.0) * 0.06) * (1.0 - disc);
	COLOR = col;
}
"""

## Seconds between shooting stars (random in this range).
@export var shooting_star_gap: Vector2 = Vector2(2.5, 7.0)
## Seconds between distant fireworks; 0 turns them off.
@export var firework_gap: Vector2 = Vector2(7.0, 14.0)
@export var firework_distance: float = 140.0

var _star_timer: float = 1.5
var _firework_timer: float = 4.0
var _streaks: Array[Dictionary] = []
var _fireworks: FireworksShow
var _streak_mat: StandardMaterial3D

static var _shader: Shader


## The full night-time Environment (sky, ambient light, glow).
static func make_environment() -> Environment:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SKY_SHADER
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = _shader
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.45, 0.62)
	env.ambient_light_energy = 0.9
	# The sky is only a backdrop: no reflections, so it never re-renders a cubemap.
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	return env


func _ready() -> void:
	_streak_mat = StandardMaterial3D.new()
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_streak_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_streak_mat.vertex_color_use_as_albedo = true
	_fireworks = FireworksShow.new()
	_fireworks.name = "DistantFireworks"
	_fireworks.loud = false
	add_child(_fireworks)
	_firework_timer = randf_range(2.0, 5.0)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	_star_timer -= delta
	if _star_timer <= 0.0:
		_star_timer = randf_range(shooting_star_gap.x, shooting_star_gap.y)
		_spawn_shooting_star(cam)
	if firework_gap.y > 0.0:
		_firework_timer -= delta
		if _firework_timer <= 0.0:
			_firework_timer = randf_range(firework_gap.x, firework_gap.y)
			_spawn_distant_firework(cam)
	for i in range(_streaks.size() - 1, -1, -1):
		var s := _streaks[i]
		var node: Node3D = s["node"]
		var age := float(s["age"]) + delta
		s["age"] = age
		var life := float(s["life"])
		if age >= life or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_streaks.remove_at(i)
			continue
		var vel: Vector3 = s["vel"]
		node.global_position += vel * delta
		var fade := minf(age / 0.12, 1.0) * clampf((life - age) / 0.3, 0.0, 1.0)
		var mesh_node := node.get_child(0) as MeshInstance3D
		if mesh_node != null:
			mesh_node.transparency = 1.0 - fade


func _forward_dir(cam: Camera3D, spread_degrees: float, min_elev: float, max_elev: float) -> Vector3:
	var fwd := -cam.global_transform.basis.z
	var yaw := atan2(-fwd.x, -fwd.z) + deg_to_rad(randf_range(-spread_degrees, spread_degrees))
	var elev := deg_to_rad(randf_range(min_elev, max_elev))
	return Vector3(-sin(yaw) * cos(elev), sin(elev), -cos(yaw) * cos(elev))


func _spawn_shooting_star(cam: Camera3D) -> void:
	var dir := _forward_dir(cam, 55.0, 18.0, 50.0)
	var start := cam.global_position + dir * 380.0
	var side := dir.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
	var travel := (side + Vector3.DOWN * randf_range(0.25, 0.6)).normalized()
	var length := randf_range(30.0, 55.0)

	var holder := Node3D.new()
	holder.name = "ShootingStar"
	add_child(holder)
	holder.global_position = start
	# Local +Y points along the flight path; the bright head leads.
	var y := travel
	var x := y.cross(dir).normalized()
	holder.global_basis = Basis(x, y, x.cross(y))
	var streak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.9
	cone.bottom_radius = 0.0
	cone.height = length
	cone.radial_segments = 6
	cone.rings = 1
	cone.material = _streak_mat
	streak.mesh = _tint_mesh(cone, Color(2.2, 2.4, 3.0))
	streak.position = Vector3(0.0, -length * 0.5, 0.0)
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	streak.transparency = 1.0
	holder.add_child(streak)
	_streaks.append({"node": holder, "vel": travel * randf_range(220.0, 320.0), "age": 0.0, "life": randf_range(0.7, 1.1)})


## Bakes a vertex colour into [param mesh] (fades from head to tail).
func _tint_mesh(mesh: PrimitiveMesh, colour: Color) -> ArrayMesh:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	var half := 0.5 * (mesh as CylinderMesh).height if mesh is CylinderMesh else 1.0
	for v in verts:
		var k := clampf((v.y + half) / (half * 2.0), 0.0, 1.0)
		cols.append(Color(colour.r * k, colour.g * k, colour.b * k, k))
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, _streak_mat)
	return out


func _spawn_distant_firework(cam: Camera3D) -> void:
	var dir := _forward_dir(cam, 50.0, 0.0, 0.0)
	var base := cam.global_position + dir * firework_distance * randf_range(0.8, 1.2)
	base.y = cam.global_position.y - 10.0
	var top := base + Vector3(randf_range(-8.0, 8.0), randf_range(45.0, 70.0), randf_range(-8.0, 8.0))
	_fireworks.launch(base, top, -1, Color.WHITE, 3.0)
