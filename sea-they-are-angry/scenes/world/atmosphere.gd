class_name Atmosphere
extends Node3D
## The dread: fog banks that roll in from the sea at dusk, ground mist at night,
## a draining colour grade with a vignette, a bell buoy tolling, and whispers and
## creaks from the dark. The storm (rain, wind, waves, lightning) is its Weather child.

const BANKS := 12
const BANK_RING := 25.0
const BANK_SIZE := Vector3(19.0, 8.0, 19.0)
const ROLL_IN := 15.0
const ROLL_OUT := 8.0
const BUOY_POS := Vector3(20.5, 0.0, -19.0)
## Kirkhaven's, off the harbour mouth.
const HARBOUR_BUOY := Vector3(21.0, 0.0, 36.0)

# Per phase: fog bank density, ground mist density, vignette, saturation, contrast, sea glow.
# Fog glow ("fog_e") lets the banks read as pale walls of mist even by moonlight.
const MOOD := [
	{"bank": 0.0, "mist": 0.0, "vig": 0.18, "sat": 1.0, "con": 1.08, "glow": 0.0, "fog_e": Color(0, 0, 0)},
	{"bank": 0.22, "mist": 0.05, "vig": 0.4, "sat": 0.82, "con": 1.12, "glow": 0.3, "fog_e": Color(0.07, 0.06, 0.07)},
	{"bank": 0.42, "mist": 0.11, "vig": 0.6, "sat": 0.68, "con": 1.16, "glow": 1.0, "fog_e": Color(0.09, 0.11, 0.13)},
	{"bank": 0.12, "mist": 0.04, "vig": 0.3, "sat": 0.9, "con": 1.1, "glow": 0.2, "fog_e": Color(0.05, 0.05, 0.06)},
]

var env: Environment
var sky_mat: ProceduralSkyMaterial
var sea_mat: ShaderMaterial

## The glowing bank that rolls in off the sea (FogBank).
var fog: FogBank
var _ring: Node3D
var _bank_mat: FogMaterial
var _mist_mat: FogMaterial
## The mist sheets: [mesh, material, share of the density].
var _sheets: Array = []
## How thick the mist sheets are in each phase (day, dusk, night, dawn): morning mist
## lies a while after the night and burns off.
const SHEETS := [0.0, 0.55, 0.75, 0.4]
var _sheet_density := 0.0
var _vignette: ShaderMaterial
var weather: Weather
var _buoy: Node3D
var _t := 0.0
var _creep_t := 8.0
var _bell_t := 4.0
var _glow := 0.0
var _phase := 0

func _ready() -> void:
	_build_fog()
	fog = FogBank.new()
	add_child(fog)
	_build_vignette()
	weather = Weather.new()
	weather.name = "Weather"
	weather.vignette = _vignette
	add_child(weather)
	_build_buoy()
	Cycle.phase_changed.connect(_on_phase)
	apply(Cycle.phase, 0.0)

func _noise_texture(seed_value: int, freq: float) -> NoiseTexture3D:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 3
	var t := NoiseTexture3D.new()
	t.width = 48
	t.height = 24
	t.depth = 48
	t.seamless = true
	t.noise = n
	return t

func _build_fog() -> void:
	_ring = Node3D.new()
	_ring.name = "FogBanks"
	add_child(_ring)
	_bank_mat = FogMaterial.new()
	_bank_mat.density = 0.0
	_bank_mat.albedo = Color(0.78, 0.82, 0.84)
	_bank_mat.height_falloff = 0.35
	_bank_mat.edge_fade = 0.6
	_bank_mat.density_texture = _noise_texture(31, 0.09)
	for i in BANKS:
		var a := TAU * float(i) / float(BANKS)
		var v := FogVolume.new()
		v.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		v.size = BANK_SIZE * (0.85 + 0.3 * float((i * 7) % 3) / 2.0)
		v.material = _bank_mat
		v.position = Vector3(sin(a) * BANK_RING, Terrain.SEA_LEVEL + 1.2, cos(a) * BANK_RING)
		if Terrain.chapter == 2:
			# Kirkhaven: a line of banks across the harbour mouth, not a ring.
			v.position = Vector3(lerpf(-52.0, 52.0, float(i) / float(BANKS - 1)), Terrain.SEA_LEVEL + 1.2, 30.0 + 7.0 * sin(float(i) * 1.7))
		_ring.add_child(v)
	# A low sheet of mist over the rock itself.
	_mist_mat = FogMaterial.new()
	_mist_mat.density = 0.0
	_mist_mat.albedo = Color(0.7, 0.75, 0.78)
	_mist_mat.height_falloff = 1.6
	_mist_mat.edge_fade = 0.5
	_mist_mat.density_texture = _noise_texture(77, 0.14)
	var mist := FogVolume.new()
	mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	mist.size = Vector3(44.0, 3.0, 44.0)
	mist.material = _mist_mat
	mist.position = Vector3(0.0, Terrain.PLATEAU_HEIGHT + 0.4, 0.0)
	if Terrain.chapter == 2:
		mist.size = Vector3(84.0, 3.0, 44.0)
		mist.position = Vector3(0.0, HarbourMap.QUAY_H + 0.5, -6.0)
	add_child(mist)
	# Drifting sheets of mist over the sea and across the rock's top, lit by the scene so
	# the beam shows in them. (Puffs of particles read as discs from the keepers' camera.)
	for layer in [[Terrain.SEA_LEVEL + 0.9, 1.0, 0.05, 0.0, 90.0], [Terrain.PLATEAU_HEIGHT + 0.7, 0.55, 0.07, 31.0, 40.0], [Terrain.PLATEAU_HEIGHT + 2.2, 0.35, 0.04, 57.0, 60.0]]:
		var sheet := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(layer[4] * 2.0, layer[4] * 2.0)
		sheet.mesh = pm
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/mist_sheet.gdshader")
		sm.set_shader_parameter("scale", layer[2])
		sm.set_shader_parameter("seed", layer[3])
		sm.set_shader_parameter("reach", layer[4])
		sheet.material_override = sm
		sheet.position = Vector3(0.0, layer[0], 0.0)
		sheet.visible = false
		add_child(sheet)
		_sheets.append([sheet, sm, float(layer[1])])

func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 0.2;
uniform float grain = 0.03;
// 0 to 1: rain driving past the camera, as faint slanting streaks.
uniform float rain = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.6;
	float v = smoothstep(0.35, 1.05, length(uv));
	float g = (hash(UV * 900.0 + vec2(TIME * 37.0, TIME * 11.0)) - 0.5) * grain;
	vec2 r = vec2(UV.x * 140.0 + UV.y * 30.0, UV.y * 2.6 - TIME * 7.5);
	float h = hash(vec2(floor(r.x), 3.0));
	float d = fract(r.y + h * 9.0);
	float streak = step(0.9, h) * smoothstep(0.0, 0.02, d) * (1.0 - smoothstep(0.02, 0.2, d)) * rain;
	vec3 c = mix(vec3(0.0, 0.01, 0.03) + g, vec3(0.75, 0.8, 0.9), streak);
	COLOR = vec4(c, clamp(v * strength + abs(g) + streak * 0.16, 0.0, 1.0));
}
"""
	_vignette = ShaderMaterial.new()
	_vignette.shader = sh
	rect.material = _vignette
	layer.add_child(rect)

# A bell buoy bobbing out in the swell; it tolls in the dark.
func _build_buoy() -> void:
	_buoy = Node3D.new()
	_buoy.position = (HARBOUR_BUOY if Terrain.chapter == 2 else BUOY_POS) + Vector3(0.0, Terrain.SEA_LEVEL, 0.0)
	add_child(_buoy)
	var red := Look.flat_mat(Color(0.55, 0.14, 0.1), 0.6)
	var iron := Look.flat_mat(Color(0.15, 0.15, 0.16), 0.5)
	var float_part := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.25
	cone.bottom_radius = 0.75
	cone.height = 0.9
	cone.radial_segments = 8
	float_part.mesh = cone
	float_part.material_override = red
	float_part.position.y = 0.2
	_buoy.add_child(float_part)
	for i in 3:
		var a := TAU * float(i) / 3.0
		var leg := Geo.box(_buoy, Vector3(0.06, 1.3, 0.06), Color.WHITE, Vector3(sin(a) * 0.2, 1.2, cos(a) * 0.2))
		leg.material_override = iron
	var bell := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.1
	bm.bottom_radius = 0.2
	bm.height = 0.28
	bm.radial_segments = 8
	bell.mesh = bm
	bell.material_override = Look.flat_mat(Color(0.5, 0.42, 0.22), 0.4)
	bell.position.y = 1.6
	_buoy.add_child(bell)
	var light := OmniLight3D.new()
	light.light_color = Color(0.9, 0.25, 0.15)
	light.omni_range = 3.0
	light.light_energy = 0.0
	light.position.y = 2.0
	light.name = "BuoyLight"
	_buoy.add_child(light)

## Ease the mood to a phase. Fog rolls in slowly at dusk and thins at dawn.
func apply(p: int, duration: float) -> void:
	_phase = p
	var m: Dictionary = MOOD[p].duplicate()
	# A clear night: thinner fog and a lighter vignette.
	if Weather.tonight() == Weather.Kind.CLEAR and (p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT):
		m["bank"] = float(m["bank"]) * 0.5
		m["mist"] = float(m["mist"]) * 0.6
		m["vig"] = float(m["vig"]) * 0.75
	if duration <= 0.0:
		_bank_mat.density = m["bank"]
		_mist_mat.density = m["mist"]
		_vignette.set_shader_parameter("strength", m["vig"])
		env.adjustment_saturation = m["sat"]
		env.adjustment_contrast = m["con"]
		_glow = m["glow"]
		_bank_mat.emission = m["fog_e"]
		_mist_mat.emission = m["fog_e"] * 0.6
	else:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_bank_mat, "density", m["bank"], duration)
		tw.tween_property(_mist_mat, "density", m["mist"], duration)
		tw.tween_method(func(v: float) -> void: _vignette.set_shader_parameter("strength", v), _vignette.get_shader_parameter("strength"), m["vig"], duration)
		tw.tween_property(env, "adjustment_saturation", m["sat"], duration)
		tw.tween_property(env, "adjustment_contrast", m["con"], duration)
		tw.tween_property(self, "_glow", m["glow"], duration)
		tw.tween_property(_bank_mat, "emission", m["fog_e"], duration)
		tw.tween_property(_mist_mat, "emission", Color(m["fog_e"]) * 0.6, duration)
	var sheet: float = SHEETS[p]
	if Weather.tonight() == Weather.Kind.CLEAR and (p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT):
		sheet *= 0.6
	if fog != null:
		# The bank comes every night; a clear night's is a little thinner, a storm's thicker.
		var thick := 0.85 if Weather.tonight() == Weather.Kind.CLEAR else (1.1 if Weather.tonight() == Weather.Kind.STORM else 1.0)
		fog.apply(p, duration * 1.6 if p == Cycle.Phase.DUSK else duration, thick)
	if duration <= 0.0:
		_set_sheets(sheet)
	else:
		create_tween().tween_method(_set_sheets, _sheet_density, sheet, duration)
	var buoy_light: OmniLight3D = _buoy.get_node("BuoyLight")
	buoy_light.light_energy = 1.2 if p == Cycle.Phase.DUSK or p == Cycle.Phase.NIGHT else 0.0
	if weather:
		weather.apply(p, duration)

func _set_sheets(d: float) -> void:
	_sheet_density = d
	for sh in _sheets:
		sh[1].set_shader_parameter("density", d * float(sh[2]))
		sh[0].visible = d > 0.005

func _on_phase(p: int) -> void:
	match p:
		Cycle.Phase.DUSK:
			apply(p, ROLL_IN)
		Cycle.Phase.NIGHT:
			apply(p, ROLL_IN * 0.6)
		_:
			apply(p, ROLL_OUT)

func _process(delta: float) -> void:
	_t += delta
	# The fog banks drift slowly round the rock.
	if Terrain.chapter != 2:
		_ring.rotation.y += delta * 0.012
	_buoy.position.y = Terrain.SEA_LEVEL + sin(_t * 1.1) * 0.12
	_buoy.rotation.z = sin(_t * 0.9) * 0.12
	_buoy.rotation.x = sin(_t * 0.7 + 1.0) * 0.08
	if sea_mat:
		sea_mat.set_shader_parameter("night_glow", _glow)
	var dark := _phase == Cycle.Phase.NIGHT or _phase == Cycle.Phase.DUSK
	if not dark or not Run.active:
		return
	_bell_t -= delta
	if _bell_t <= 0.0:
		_bell_t = randf_range(7.0, 14.0)
		Audio.ambient_sfx("bell", _buoy.global_position, -6.0, 0.03)
	_creep_t -= delta
	if _creep_t <= 0.0:
		_creep_t = randf_range(9.0, 20.0)
		var a := randf() * TAU
		var at := Vector3(sin(a) * 22.0, 1.0, cos(a) * 22.0)
		if Terrain.chapter == 2:
			at = Vector3(randf_range(-30.0, 30.0), 1.0, randf_range(8.0, 30.0))
		var key: String = ["creak", "whisper", "groan", "whisper"][randi() % 4]
		Audio.ambient_sfx(key, at, -10.0, 0.25)

