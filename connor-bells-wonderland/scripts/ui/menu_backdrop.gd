class_name MenuBackdrop
extends Node3D
## The live 3D start screen behind the menus: a night fair under the stars
## with Belfast on the horizon, a spinning Ferris wheel, the big top, the tower
## and Connor's crown, sweeping searchlights, a disco ball over a flashing
## dance floor with contestants dancing to the music, shooting stars and
## fireworks.

const DANCERS := 5

var _sound: SoundManager
var _camera: Camera3D
var _wheel: Node3D
var _gondolas: Array[Node3D] = []
var _ball: Node3D
var _beams: Array[Node3D] = []
var _dancers: Array[ContestantVisuals] = []
var _tile_mats: Array[StandardMaterial3D] = []
var _tiles: Array[MeshInstance3D] = []
var _fireworks: FireworksShow
var _time: float = 0.0
var _last_beat: int = -1
var _rocket_timer: float = 1.5


func _ready() -> void:
	_sound = SoundManager.new()
	_sound.name = "SoundManager"
	add_child(_sound)

	var world_env := WorldEnvironment.new()
	world_env.environment = NightSky.make_environment()
	add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35.0, 150.0, 0.0)
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.5
	add_child(moon)
	var sky := NightSky.new()
	sky.name = "NightSky"
	sky.shooting_star_gap = Vector2(0.8, 2.6)
	sky.firework_gap = Vector2(2.5, 5.0)
	sky.firework_distance = 90.0
	add_child(sky)
	var skyline := BelfastSkyline.new()
	skyline.position = Vector3(-150.0, -1.0, -950.0)
	add_child(skyline)

	_camera = Camera3D.new()
	_camera.name = "MenuCamera"
	_camera.fov = 62.0
	_camera.h_offset = -3.2
	add_child(_camera)
	_camera.current = true

	_build_ground()
	_build_dance_floor()
	_build_wheel(Vector3(-15.0, 0.0, -14.0))
	_build_big_top(Vector3(15.0, 0.0, -16.0))
	_build_tower(Vector3(2.0, 0.0, -48.0))
	_build_searchlights()
	_build_disco_ball()
	_build_dancers()

	_fireworks = FireworksShow.new()
	_fireworks.name = "Fireworks"
	_fireworks.position = Vector3(2.0, 0.0, -75.0)
	add_child(_fireworks)


func _process(delta: float) -> void:
	_time += delta
	var beat := _beat()
	# Camera drifts slowly so the scene never sits still.
	var sway := sin(_time * 0.15)
	_camera.position = Vector3(sway * 3.0, 3.0 + sin(_time * 0.23) * 0.4, 12.0)
	_camera.look_at(Vector3(sway * 1.5, 4.6, -8.0))

	_wheel.rotation.z += delta * 0.25
	for g in _gondolas:
		g.global_rotation = Vector3.ZERO
	_ball.rotation.y += delta * 0.8
	for i in range(_beams.size()):
		_beams[i].rotation = Vector3(sin(_time * 0.5 + float(i) * 2.1) * 0.35, 0.0, sin(_time * 0.37 + float(i)) * 0.45)

	for i in range(_dancers.size()):
		var d := _dancers[i]
		d.dance(beat + float(i) * 0.25 * float(i % 2), i % 3)
		# Every 16 beats they all spin round on the beat.
		var cycle := fmod(beat, 16.0)
		var spin := TAU * clampf(cycle - 15.0, 0.0, 1.0)
		d.rotation.y = PI + spin

	# Dance floor flashes on every beat.
	var beat_index := int(floor(beat))
	if beat_index != _last_beat:
		_last_beat = beat_index
		for tile in _tiles:
			tile.material_override = _tile_mats[randi() % _tile_mats.size()]
	var pulse := 1.0 - fmod(beat, 1.0)
	for m in _tile_mats:
		m.emission_energy_multiplier = 0.4 + pulse * pulse * 2.2

	# A rocket or two every couple of seconds, well behind the fair.
	_rocket_timer -= delta
	if _rocket_timer <= 0.0:
		_rocket_timer = randf_range(1.2, 2.8)
		for i in range(randi_range(1, 2)):
			var base := _fireworks.global_position + Vector3(randf_range(-30.0, 30.0), 0.0, randf_range(-10.0, 10.0))
			_fireworks.launch(base, base + Vector3(randf_range(-4.0, 4.0), randf_range(28.0, 42.0), 0.0), -1, Color.WHITE, 1.5)


## Music beats since the loop started (follows the music when it's playing).
func _beat() -> float:
	var pos := _sound.music_position() if _sound != null else -1.0
	if pos < 0.0:
		return _time * SoundManager.BPM / 60.0
	return pos * SoundManager.BPM / 60.0


func _build_ground() -> void:
	var ground := CourseBuilder.make_box_mesh(Vector3(300.0, 1.0, 300.0), Color(0.03, 0.035, 0.045))
	ground.position = Vector3(0.0, -0.5, -60.0)
	add_child(ground)
	# Neon path lines running back to the tower.
	for x: float in [-3.2, 7.2]:
		CourseBuilder.add_neon_strip(self, Vector3(0.12, 0.05, 44.0), Vector3(x, 0.03, -26.0), CourseBuilder.accent(1), "PathLine")


func _build_dance_floor() -> void:
	for colour_index in range(4):
		var m := CourseBuilder.make_neon_material(CourseBuilder.accent(colour_index), 1.0)
		_tile_mats.append(m)
	var dark := CourseBuilder.make_material(Color(0.06, 0.06, 0.08))
	for x in range(-4, 5):
		for z in range(-2, 2):
			var tile := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(1.5, 0.12, 1.5)
			box.material = dark
			tile.mesh = box
			tile.position = Vector3(float(x) * 1.6 + 2.0, 0.06, float(z) * 1.6 + 0.8)
			add_child(tile)
			if (x + z) % 2 == 0:
				_tiles.append(tile)


func _build_dancers() -> void:
	for i in range(DANCERS):
		var d := ContestantVisuals.new()
		d.name = "Dancer%d" % i
		add_child(d)
		d.setup(CourseBuilder.player_colour([0, 4, 3, 1, 6][i]))
		d.position = Vector3(-2.4 + float(i) * 2.2, 0.12, 0.2 + absf(float(i) - 2.0) * -0.7)
		d.rotation.y = PI
		_dancers.append(d)


func _build_disco_ball() -> void:
	_ball = Node3D.new()
	_ball.name = "DiscoBall"
	_ball.position = Vector3(2.0, 6.2, 0.0)
	add_child(_ball)
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.6
	mesh.radial_segments = 16
	mesh.rings = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.82, 0.9)
	mat.metallic = 1.0
	mat.roughness = 0.15
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.65, 0.8)
	mat.emission_energy_multiplier = 0.6
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_ball.add_child(mi)
	CourseBuilder.add_neon_strip(self, Vector3(0.04, 3.0, 0.04), Vector3(2.0, 8.3, 0.0), Color(0.5, 0.5, 0.6), "BallCord")
	FX.attach(_ball, "sparkle", Vector3.ZERO, Color(1.5, 1.5, 2.0))
	for i in range(4):
		var spot := SpotLight3D.new()
		spot.light_color = CourseBuilder.accent(i)
		spot.light_energy = 6.0
		spot.spot_range = 14.0
		spot.spot_angle = 14.0
		spot.rotation = Vector3(-1.1, float(i) * TAU / 4.0, 0.0)
		_ball.add_child(spot)


func _build_wheel(base: Vector3) -> void:
	var radius := 8.0
	var hub := base + Vector3(0.0, radius + 1.5, 0.0)
	var steel := CourseBuilder.STEEL
	for side: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			var leg := CourseBuilder.make_box_mesh(Vector3(0.35, radius + 2.0, 0.35), steel)
			leg.position = base + Vector3(lean * 2.4, (radius + 1.5) * 0.5, side * 1.1)
			leg.rotation.z = lean * 0.28
			add_child(leg)
	_wheel = Node3D.new()
	_wheel.name = "FerrisWheel"
	_wheel.position = hub
	add_child(_wheel)
	var segments := 28
	for i in range(segments):
		var a := TAU * float(i) / float(segments)
		var p := Vector3(cos(a), sin(a), 0.0) * radius
		var seg := CourseBuilder.add_neon_strip(_wheel, Vector3(0.18, TAU * radius / float(segments) * 1.05, 0.18), p, CourseBuilder.accent(i % 2), "Rim")
		seg.rotation.z = a
	for i in range(10):
		var a := TAU * float(i) / 10.0
		var spoke := CourseBuilder.add_neon_strip(_wheel, Vector3(0.08, radius, 0.08), Vector3(cos(a), sin(a), 0.0) * radius * 0.5, CourseBuilder.accent(2 + i % 2), "Spoke")
		spoke.rotation.z = a - PI * 0.5
		var gondola := Node3D.new()
		gondola.position = Vector3(cos(a), sin(a), 0.0) * radius
		_wheel.add_child(gondola)
		var car := CourseBuilder.make_box_mesh(Vector3(1.1, 0.9, 0.9), CourseBuilder.surface(CourseBuilder.accent(i % 4)))
		car.position = Vector3(0.0, -0.7, 0.0)
		gondola.add_child(car)
		_gondolas.append(gondola)


func _build_big_top(base: Vector3) -> void:
	var wall := CourseBuilder.make_cylinder_mesh(6.5, 4.0, Color(0.35, 0.04, 0.08))
	wall.position = base + Vector3(0.0, 2.0, 0.0)
	add_child(wall)
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.1
	cone.bottom_radius = 7.2
	cone.height = 5.5
	cone.material = CourseBuilder.make_material(Color(0.12, 0.12, 0.16))
	roof.mesh = cone
	roof.position = base + Vector3(0.0, 6.75, 0.0)
	add_child(roof)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		# Neon seams running from the eave up to the tip of the roof.
		var stripe := CourseBuilder.add_neon_strip(self, Vector3(0.12, 9.0, 0.12), base + Vector3(cos(a) * 3.65, 6.75, sin(a) * 3.65), CourseBuilder.accent(i % 2), "RoofLine")
		stripe.look_at(base + Vector3(0.0, 9.5, 0.0), Vector3.UP)
		stripe.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 6.9
	torus.outer_radius = 7.2
	torus.material = CourseBuilder.make_neon_material(CourseBuilder.accent(0), 2.0)
	ring.mesh = torus
	ring.position = base + Vector3(0.0, 4.0, 0.0)
	add_child(ring)
	var flag := CourseBuilder.add_neon_strip(self, Vector3(1.2, 0.7, 0.05), base + Vector3(0.6, 10.4, 0.0), CourseBuilder.accent(2), "Flag")
	flag.rotation.y = 0.3


func _build_tower(base: Vector3) -> void:
	var levels := 6
	for i in range(levels):
		var r := 4.5 - float(i) * 0.55
		var h := 4.5
		var drum := CourseBuilder.make_cylinder_mesh(r, h, CourseBuilder.STEEL)
		drum.position = base + Vector3(0.0, h * 0.5 + float(i) * h, 0.0)
		add_child(drum)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = r
		torus.outer_radius = r + 0.25
		torus.material = CourseBuilder.make_neon_material(CourseBuilder.accent(i % 4), 2.2)
		ring.mesh = torus
		ring.position = base + Vector3(0.0, float(i + 1) * h, 0.0)
		add_child(ring)
	var top := base + Vector3(0.0, float(levels) * 4.5 + 0.5, 0.0)
	var crown := MeshInstance3D.new()
	var band := TorusMesh.new()
	band.inner_radius = 1.3
	band.outer_radius = 1.7
	band.material = CourseBuilder.make_neon_material(Color(1.0, 0.75, 0.1), 3.0)
	crown.mesh = band
	crown.position = top
	add_child(crown)
	for i in range(5):
		var a := TAU * float(i) / 5.0
		var spike := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = 0.35
		prism.height = 1.4
		prism.material = band.material
		spike.mesh = prism
		spike.position = top + Vector3(cos(a) * 1.5, 0.8, sin(a) * 1.5)
		add_child(spike)
	FX.attach(crown, "sparkle", Vector3.UP * 0.5, Color(2.5, 2.0, 0.6))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.3)
	glow.light_energy = 3.0
	glow.omni_range = 12.0
	glow.position = top + Vector3.UP * 1.5
	add_child(glow)


func _build_searchlights() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.5, 0.6, 0.9, 0.12)
	for x: float in [-22.0, 26.0, -6.0, 12.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0.0, -30.0)
		add_child(pivot)
		var beam := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 3.5
		cone.bottom_radius = 0.3
		cone.height = 90.0
		cone.cap_top = false
		cone.cap_bottom = false
		cone.material = mat
		beam.mesh = cone
		beam.position = Vector3(0.0, 45.0, 0.0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(beam)
		_beams.append(pivot)
