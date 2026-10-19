class_name Weather
extends Node3D
## The storm. One level, `storm` (0 calm to 1 full gale), drives everything: the
## global "storm" shader value (grass leaning and thrashing, the sea heaving, rain in
## the lamp beam), driving rain, rain streaks on the screen, gusts, breakers on the
## cliffs, the rain and wind sounds, and lightning. It builds at dusk and peaks at
## night. Lightning flashes out at sea, now and then strikes the lighthouse's own rod,
## and in some flashes the sea all round the island is full of pale drowned figures
## standing in the swell, gone when the light goes.

const LEVELS := [0.12, 0.6, 1.0, 0.3]
const RAMP := 12.0
const RAIN_AMOUNT := 5000
const RAIN_BOX := Vector3(34.0, 1.0, 30.0)
const RAIN_HEIGHT := 26.0
const RAIN_FROM := 0.35
const WATCHERS := 70
const WATCHER_CHANCE := 0.4
const ROD_CHANCE := 0.16

var storm := 0.0
var vignette: ShaderMaterial
var _target := 0.0
var _rain: GPUParticles3D
var _rain_pm: ParticleProcessMaterial
var _flash_layer: CanvasLayer
var _flash: ColorRect
var _lightning: DirectionalLight3D
var _watchers: MultiMeshInstance3D
var _watcher_eyes: MultiMeshInstance3D
var _strike_t := 20.0
var _gust_t := 6.0
var _gust := 0.0
var _breaker_t := 1.0
var _crash_t := 2.0
var _audio_t := 0.0

func _ready() -> void:
	_build_rain()
	_build_flash()
	_build_lightning()
	_build_watchers()
	_apply_storm()

## Ease the storm toward the level for a phase.
func apply(p: int, duration: float = RAMP) -> void:
	_target = LEVELS[p]
	if duration <= 0.0:
		storm = _target
		_apply_storm()
	if p == Cycle.Phase.NIGHT:
		_strike_t = randf_range(4.0, 9.0)

# ---- building ----

func _build_rain() -> void:
	_rain_pm = ParticleProcessMaterial.new()
	_rain_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_pm.emission_box_extents = RAIN_BOX
	_rain_pm.direction = Vector3(0.22, -1.0, 0.06).normalized()
	_rain_pm.spread = 2.0
	_rain_pm.initial_velocity_min = 24.0
	_rain_pm.initial_velocity_max = 30.0
	_rain_pm.gravity = Vector3(0.0, -12.0, 0.0)
	_rain_pm.particle_flag_align_y = true
	var drop := BoxMesh.new()
	drop.size = Vector3(0.022, 0.75, 0.022)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.72, 0.78, 0.88, 0.32)
	drop.material = mat
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.process_material = _rain_pm
	_rain.draw_pass_1 = drop
	_rain.amount = RAIN_AMOUNT
	_rain.lifetime = 1.3
	_rain.preprocess = 1.3
	_rain.local_coords = false
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	_rain.position = Vector3(0.0, RAIN_HEIGHT, 2.0)
	_rain.amount_ratio = 0.0
	add_child(_rain)

func _build_flash() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 6
	add_child(_flash_layer)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.8, 0.86, 1.0, 0.0)
	_flash_layer.add_child(_flash)

func _build_lightning() -> void:
	_lightning = DirectionalLight3D.new()
	_lightning.light_color = Color(0.75, 0.82, 1.0)
	_lightning.light_energy = 0.0
	_lightning.rotation_degrees = Vector3(-35.0, -140.0, 0.0)
	_lightning.shadow_enabled = true
	add_child(_lightning)

# The drowned, standing in the sea round the island: pale, hunched, eyes lit.
# Only shown while lightning is in the sky.
func _build_watchers() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := CylinderMesh.new()
	body.top_radius = 0.22
	body.bottom_radius = 0.3
	body.height = 1.4
	body.radial_segments = 6
	st.append_from(body, 0, Transform3D(Basis(), Vector3(0.0, 0.7, 0.0)))
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.42
	head.radial_segments = 6
	head.rings = 3
	st.append_from(head, 0, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0.0, 1.55, -0.12)))
	for side in [-1.0, 1.0]:
		var arm := BoxMesh.new()
		arm.size = Vector3(0.08, 1.1, 0.08)
		st.append_from(arm, 0, Transform3D(Basis(Vector3.FORWARD, side * 0.12), Vector3(side * 0.32, 0.75, 0.0)))
	var mesh := st.commit()
	var mat := Look.flat_mat(Color(0.6, 0.66, 0.66), 0.4)
	_watchers = _multimesh(mesh, mat)
	var eye := SphereMesh.new()
	eye.radius = 0.05
	eye.height = 0.1
	eye.radial_segments = 4
	eye.rings = 2
	var est := SurfaceTool.new()
	est.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		est.append_from(eye, 0, Transform3D(Basis(), Vector3(side * 0.08, 1.58, -0.3)))
	_watcher_eyes = _multimesh(est.commit(), Look.eye_mat(Color(0.8, 1.0, 0.4), 12.0))
	_place_watchers()

func _multimesh(mesh: Mesh, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = WATCHERS
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible = false
	add_child(mmi)
	return mmi

func _place_watchers() -> void:
	for i in WATCHERS:
		var a := randf() * TAU
		var r := randf_range(18.5, 30.0)
		var p := Vector3(sin(a) * r, Terrain.SEA_LEVEL - randf_range(0.4, 0.8), cos(a) * r)
		# Every one of them facing the light.
		var b := Basis(Vector3.UP, atan2(p.x, p.z)).scaled(Vector3.ONE * randf_range(1.5, 2.2))
		var xf := Transform3D(b, p)
		_watchers.multimesh.set_instance_transform(i, xf)
		_watcher_eyes.multimesh.set_instance_transform(i, xf)

# ---- running ----

func _process(delta: float) -> void:
	storm = move_toward(storm, _target, delta / RAMP)
	_gust = maxf(0.0, _gust - delta * 0.6)
	_apply_storm()
	if storm < 0.05:
		return
	_breakers(delta)
	_gusts(delta)
	_lightning_tick(delta)

func _apply_storm() -> void:
	RenderingServer.global_shader_parameter_set("storm", clampf(storm + _gust * 0.35, 0.0, 1.2))
	var rain := smoothstep(RAIN_FROM, 1.0, storm)
	if _rain:
		_rain.amount_ratio = rain
		_rain.emitting = rain > 0.01
		_rain_pm.direction = Vector3(0.22 + _gust * 0.5, -1.0, 0.06).normalized()
	if vignette:
		vignette.set_shader_parameter("rain", rain)
	_audio_t -= get_process_delta_time()
	if _audio_t <= 0.0:
		_audio_t = 0.25
		Audio.loop_volume("rain", lerpf(-60.0, -8.0, rain))
		Audio.loop_volume("wind", lerpf(-18.0, -5.0, clampf(storm + _gust * 0.4, 0.0, 1.0)))

# Waves breaking on the cliffs and rolling up the beaches, more and bigger in a storm.
func _breakers(delta: float) -> void:
	_breaker_t -= delta
	if _breaker_t <= 0.0:
		_breaker_t = lerpf(1.6, 0.32, storm) * randf_range(0.6, 1.4)
		var a := randf() * 360.0
		var r := Terrain.coast_radius(a) + Terrain.CLIFF_WIDTH * 0.8
		var p := Terrain.at_angle(a, r)
		p.y = Terrain.SEA_LEVEL
		if Terrain.beach_weight(p.x, p.z) > 0.3:
			FX.splash(get_parent(), p, 0.6 + storm * 0.6)
		else:
			FX.breaker(get_parent(), p, 0.6 + storm * 1.6)
	_crash_t -= delta
	if _crash_t <= 0.0 and storm > 0.4:
		_crash_t = randf_range(1.5, 3.5)
		var a2 := randf() * TAU
		Audio.sfx("wave_crash", Vector3(sin(a2) * 17.0, 0.0, cos(a2) * 17.0), -8.0 + storm * 4.0, 0.15)

func _gusts(delta: float) -> void:
	_gust_t -= delta
	if _gust_t <= 0.0 and storm > 0.3:
		_gust_t = randf_range(5.0, 12.0) * lerpf(1.5, 0.8, storm)
		_gust = 1.0
		Audio.sfx("gust", Vector3.INF, -10.0 + storm * 6.0, 0.15)

func _lightning_tick(delta: float) -> void:
	if storm < 0.45:
		return
	_strike_t -= delta
	if _strike_t <= 0.0:
		_strike_t = randf_range(5.0, 12.0) * lerpf(2.2, 1.0, storm)
		strike()

## A lightning strike: a bolt out at sea (or onto the lighthouse's rod), a flash,
## and thunder a moment later. Sometimes the flash shows what's standing in the sea.
func strike(on_rod: bool = false, show_watchers: bool = false) -> void:
	var close := on_rod or randf() < ROD_CHANCE
	var from: Vector3
	var to: Vector3
	if close:
		var lh := get_tree().get_first_node_in_group("lighthouse") as Node3D
		var top := (lh.global_position if lh else Vector3(0.0, Terrain.CRAG_TOP, 0.0)) + Vector3(0.0, 10.1, 0.0)
		to = top
		from = top + Vector3(randf_range(-6.0, 6.0), 30.0, randf_range(-8.0, -2.0))
	else:
		var a := deg_to_rad(randf_range(110.0, 250.0))
		var d := randf_range(30.0, 46.0)
		to = Vector3(sin(a) * d, Terrain.SEA_LEVEL, cos(a) * d)
		from = to + Vector3(randf_range(-8.0, 8.0), 40.0, randf_range(-6.0, 6.0))
	_bolt(from, to)
	if close:
		FX.sparks(get_parent(), to)
	_lightning.look_at_from_position(from, to, Vector3.UP)
	var tw := create_tween()
	tw.tween_property(_lightning, "light_energy", 3.0, 0.03)
	tw.tween_property(_lightning, "light_energy", 0.3, 0.07)
	tw.tween_property(_lightning, "light_energy", 2.4, 0.04)
	tw.tween_property(_lightning, "light_energy", 0.0, 0.4)
	var ft := create_tween()
	ft.tween_property(_flash, "color:a", 0.38 if close else 0.22, 0.03)
	ft.tween_property(_flash, "color:a", 0.05, 0.07)
	ft.tween_property(_flash, "color:a", 0.28 if close else 0.16, 0.04)
	ft.tween_property(_flash, "color:a", 0.0, 0.45)
	if show_watchers or (not close and randf() < WATCHER_CHANCE):
		_place_watchers()
		_watchers.visible = true
		_watcher_eyes.visible = true
		var wt := create_tween()
		wt.tween_interval(0.5)
		wt.tween_callback(func() -> void:
			_watchers.visible = false
			_watcher_eyes.visible = false)
	var delay := 0.15 if close else randf_range(0.8, 2.2)
	get_tree().create_timer(delay).timeout.connect(func() -> void: Audio.sfx("thunder", Vector3.INF, 2.0 if close else -3.0, 0.12))

# A jagged bolt from the cloud to the strike point, with a fork, gone in a blink.
func _bolt(from: Vector3, to: Vector3) -> void:
	var holder := Node3D.new()
	add_child(holder)
	var mat := Look.eye_mat(Color(0.8, 0.88, 1.0), 14.0)
	var pts := _jagged(from, to, 11, 2.2)
	_bolt_segments(holder, pts, mat, 0.14)
	var fork_from := pts[4]
	var fork_to := fork_from.lerp(to, 0.6) + Vector3(randf_range(-7.0, 7.0), 0.0, randf_range(-5.0, 5.0))
	_bolt_segments(holder, _jagged(fork_from, fork_to, 5, 1.4), mat, 0.07)
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void: holder.visible = false)
	tw.tween_interval(0.05)
	tw.tween_callback(func() -> void: holder.visible = true)
	tw.tween_interval(0.1)
	tw.tween_callback(holder.queue_free)

func _jagged(from: Vector3, to: Vector3, n: int, wobble: float) -> Array[Vector3]:
	var pts: Array[Vector3] = [from]
	for i in range(1, n):
		var k := float(i) / float(n)
		pts.append(from.lerp(to, k) + Vector3(randf_range(-wobble, wobble), 0.0, randf_range(-wobble, wobble)))
	pts.append(to)
	return pts

func _bolt_segments(holder: Node3D, pts: Array[Vector3], mat: Material, width: float) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var seg := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(width, width, a.distance_to(b))
		seg.mesh = m
		seg.material_override = mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(seg)
		seg.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
