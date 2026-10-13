extends Node
## Autoload "G": shared constants, scene references, neon mesh helpers, effects and sound.

const PLAYER_COLORS: Array[Color] = [
	Color(0.2, 0.7, 1.0), Color(0.25, 1.0, 0.4), Color(1.0, 0.3, 0.85), Color(1.0, 0.88, 0.2)]
const PLAYER_NAMES: Array[String] = ["BLUE", "GREEN", "PINK", "YELLOW"]
const TANK_COLOR := Color(0.4, 0.95, 1.0)
const ENEMY_COLOR := Color(1.0, 0.2, 0.12)
const ENEMY_ALT_COLOR := Color(1.0, 0.55, 0.08)

const LAYER_TERRAIN := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

enum Team { PLAYER, ENEMY }

const SAVE_PATH := "user://neon_mega_tank.cfg"

## Devices that joined, kept across restarts so the crew doesn't have to rejoin.
var joined_devices: Array[int] = []
## AI crew fills empty seats when on (toggle F2 / gamepad Back).
var ai_crew := true
var music_on := true
## Scales enemy health and damage; raised by Main every wave.
var difficulty := 1.0
var best_time := 0.0
var best_wave := 0
var best_score := 0
## True once the title menu has been passed (restarts go straight back to the lobby).
var menu_done := false
## Message shown on the title menu (e.g. "the host left").
var menu_message := ""
## Seed of the current round's city (shared with LAN clients).
var round_seed := 0
## On-screen controls, when the device has a touchscreen.
var touch: TouchControls
## Client side: visual projectiles by network id, so the host can end them.
var net_projectiles := {}
var _next_net_id := 1
## While > 0, effects are not sent to LAN clients (they rebuild composite effects themselves).
var net_mute := 0
var main: Main
var tank: MegaTank
var city: City
var fx_root: Node3D
var score := 0
var shake := 0.0

var edge_material: ShaderMaterial
var on_top_material: ShaderMaterial
var additive_material: ShaderMaterial
var ui_font: SystemFont
var jp_font: FontFile

var _ring_shader: Shader
var _scorch_shader: Shader
var _plane: PlaneMesh
var _fade_ramp: Gradient
var _box_meshes := {}
var _box_shapes := {}
var _scorches: Array = []
var _sounds := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}
var _music := {}
var _voice_streams := {}
var _music_player: AudioStreamPlayer
var _voice_players: Array[AudioStreamPlayer] = []
var _announcer: AudioStreamPlayer
var _wanted_track := ""
var _last_voice := 0
var _audio_task := -1


func _ready() -> void:
	edge_material = _shader_material("res://shaders/neon_edge.gdshader")
	on_top_material = _shader_material("res://shaders/neon_on_top.gdshader")
	on_top_material.render_priority = 10
	additive_material = _shader_material("res://shaders/fx_additive.gdshader")
	_ring_shader = load("res://shaders/ring.gdshader")
	_scorch_shader = load("res://shaders/scorch.gdshader")
	_plane = PlaneMesh.new()
	_plane.size = Vector2(2, 2)
	_fade_ramp = Gradient.new()
	_fade_ramp.set_color(0, Color(1, 1, 1, 1))
	_fade_ramp.set_color(1, Color(1, 1, 1, 0))
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(
		["JetBrains Mono", "DejaVu Sans Mono", "Consolas", "Menlo", "Courier New", "monospace"])
	jp_font = load("res://fonts/DotGothic16-Regular.ttf")
	_sounds = SfxBank.build()
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	for i in 3:
		var vp := AudioStreamPlayer.new()
		vp.volume_db = -3.0
		add_child(vp)
		_voice_players.append(vp)
	_announcer = AudioStreamPlayer.new()
	_announcer.volume_db = 0.0
	add_child(_announcer)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -11.0
	add_child(_music_player)
	load_records()
	# Music and voices are synthesised in the background so the game starts instantly.
	_audio_task = WorkerThreadPool.add_task(_build_audio, false, "Synthesise audio")


func _exit_tree() -> void:
	if _audio_task != -1:
		WorkerThreadPool.wait_for_task_completion(_audio_task)


# --- Records ---------------------------------------------------------------------------------

func load_records() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_time = cfg.get_value("records", "best_time", 0.0)
	best_wave = cfg.get_value("records", "best_wave", 0)
	best_score = cfg.get_value("records", "best_score", 0)
	ai_crew = cfg.get_value("options", "ai_crew", true)
	music_on = cfg.get_value("options", "music_on", true)


func save_records() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_time", best_time)
	cfg.set_value("records", "best_wave", best_wave)
	cfg.set_value("records", "best_score", best_score)
	cfg.set_value("options", "ai_crew", ai_crew)
	cfg.set_value("options", "music_on", music_on)
	cfg.save(SAVE_PATH)


## Stores a finished run. Returns true if the survival time is a new record.
func submit_run(time: float, wave: int, points: int) -> bool:
	var record := time > best_time
	best_time = maxf(best_time, time)
	best_wave = maxi(best_wave, wave)
	best_score = maxi(best_score, points)
	save_records()
	return record


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]


# --- Music and voices ------------------------------------------------------------------------

func _build_audio() -> void:
	var voices := {}
	for romaji in VoiceLines.all_romaji():
		voices[romaji] = VoiceSynth.say(romaji, 125.0, true)
	call_deferred("_audio_ready", {}, voices)
	for track in ["lobby", "battle", "gameover"]:
		call_deferred("_audio_ready", {track: Chiptune.render(track)}, {})


func _audio_ready(music: Dictionary, voices: Dictionary) -> void:
	_music.merge(music)
	_voice_streams.merge(voices)
	if music.has(_wanted_track):
		play_music(_wanted_track)


func play_music(track: String) -> void:
	_wanted_track = track
	if not music_on or not _music.has(track):
		return
	if _music_player.stream == _music[track] and _music_player.playing:
		return
	_music_player.stream = _music[track]
	_music_player.play()


func toggle_music() -> void:
	music_on = not music_on
	if music_on:
		play_music(_wanted_track)
	else:
		_music_player.stop()
	save_records()


## Enemy death cry: a robotic Japanese shout plus a floating manga-style subtitle.
func shout(pos: Vector3, line: Array, color: Color) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_voice < 350:
		return
	_last_voice = now
	_net("shout", [pos, line, color], true)
	if _voice_streams.has(line[0]):
		var p: AudioStreamPlayer = _voice_players[now % _voice_players.size()]
		p.stream = _voice_streams[line[0]]
		p.pitch_scale = randf_range(0.95, 1.12)
		p.play()
	speech(pos + Vector3(0, 2.2, 0), line[1], line[2], color)


func announce(key: String) -> void:
	var line: Array = VoiceLines.ANNOUNCER[key]
	_net("announce", [key], true)
	if _voice_streams.has(line[0]):
		_announcer.stream = _voice_streams[line[0]]
		_announcer.pitch_scale = 0.78
		_announcer.play()


func speech(pos: Vector3, japanese: String, romaji: String, color: Color) -> void:
	if fx_root == null:
		return
	var root := Node3D.new()
	fx_root.add_child(root)
	root.global_position = pos
	var big := _speech_label(japanese, 96, color)
	root.add_child(big)
	var small := _speech_label(romaji, 44, color.lightened(0.4))
	small.position.y = -1.1
	root.add_child(small)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(root, "position:y", pos.y + 2.5, 1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(big, "modulate:a", 0.0, 0.6).set_delay(1.0)
	tw.tween_property(small, "modulate:a", 0.0, 0.6).set_delay(1.0)
	tw.chain().tween_callback(root.queue_free)


func _speech_label(text: String, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = jp_font
	l.font_size = size
	l.outline_size = 18
	l.pixel_size = 0.016
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 30
	l.outline_render_priority = 29
	return l


## Called by Main when a new round starts.
func is_client() -> bool:
	return Net.is_client()


## Phone UI (touch controls, no CRT). Launch with "-- --touch" to try it on a desktop.
func is_mobile() -> bool:
	return (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
		or OS.get_cmdline_user_args().has("--touch"))


func _net(kind: String, args: Array, reliable := false) -> void:
	if net_mute == 0:
		Net.send_event(kind, args, reliable)


func next_net_id() -> int:
	_next_net_id += 1
	return _next_net_id


func reset_round() -> void:
	net_projectiles.clear()
	score = 0
	shake = 0.0
	difficulty = 1.0
	_scorches.clear()


func _shader_material(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


func box_mesh(size: Vector3) -> BoxMesh:
	var key := "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if not _box_meshes.has(key):
		var m := BoxMesh.new()
		m.size = size
		_box_meshes[key] = m
	return _box_meshes[key]


func box_shape(size: Vector3) -> BoxShape3D:
	var key := "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if not _box_shapes.has(key):
		var s := BoxShape3D.new()
		s.size = size
		_box_shapes[key] = s
	return _box_shapes[key]


## Adds a glowing wireframe box to `parent`.
func neon_box(parent: Node, size: Vector3, pos: Vector3, color: Color, energy := 2.5,
		windows := false, on_top := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size)
	mi.material_override = on_top_material if on_top else edge_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	set_neon(mi, color, energy)
	if windows:
		mi.set_instance_shader_parameter("windows", 1.0)
	return mi


func set_neon(mi: GeometryInstance3D, color: Color, energy := 2.5) -> void:
	mi.set_instance_shader_parameter("line_color", color)
	mi.set_instance_shader_parameter("energy", energy)


## White hit-flash that fades out over a few frames.
func flash(meshes: Array, amount := 1.0) -> void:
	_set_flash(amount, meshes)
	var tw := create_tween()
	tw.tween_method(_set_flash.bind(meshes), amount, 0.0, 0.15)


func _set_flash(value: float, meshes: Array) -> void:
	for m in meshes:
		if is_instance_valid(m):
			m.set_instance_shader_parameter("flash", value)


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 1.6)


func add_score(points: int) -> void:
	if main and main.state == Main.State.PLAYING:
		score += points


func spawn_projectile(pos: Vector3, vel: Vector3, team: int, kind: String,
		color := Color.WHITE, net_id := 0) -> Projectile:
	var p := Projectile.new()
	p.setup(kind, team, vel, color)
	if is_client():
		p.visual_only = true
		p.net_id = net_id
		if net_id != 0:
			net_projectiles[net_id] = p
	else:
		p.net_id = next_net_id()
		_net("proj", [pos, vel, team, kind, color, p.net_id])
	if team == Team.ENEMY:
		p.damage *= difficulty
		p.blast_damage *= difficulty
	fx_root.add_child(p)
	p.global_position = pos
	p.look_at(pos + vel, Vector3.UP)
	return p


## Area damage plus the full visual treatment. Damage 0 = visuals only.
func explode(pos: Vector3, radius: float, damage: float, team: int,
		color := Color(1.0, 0.55, 0.15)) -> void:
	_net("explode", [pos, radius, color])
	if damage > 0.0 and main and not is_client():
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = radius
		q.shape = s
		q.transform = Transform3D(Basis(), Vector3(pos.x, 1.0, pos.z))
		q.collision_mask = LAYER_TERRAIN | (LAYER_ENEMY if team == Team.PLAYER else LAYER_PLAYER)
		var seen := {}
		for hit in main.get_world_3d().direct_space_state.intersect_shape(q, 128):
			var c: Object = hit["collider"]
			if c == null or seen.has(c) or not c.has_method("take_damage"):
				continue
			seen[c] = true
			var d := (c as Node3D).global_position.distance_to(pos)
			c.take_damage(damage * clampf(1.0 - d / (radius * 1.6), 0.35, 1.0), pos, team)
	net_mute += 1
	ring(pos, color, radius * 1.4, 0.5)
	ring(pos, Color(1.0, 0.95, 0.8), radius * 0.7, 0.22)
	sparks(pos + Vector3(0, 0.8, 0), color, int(10 + radius * 5), 6.0 + radius * 2.0)
	sparks(pos + Vector3(0, 0.5, 0), Color(1, 0.9, 0.6), 6, 3.0, 0.4, 0.3, 4.0)
	scorch(pos, radius * 0.8)
	add_shake(0.2 + radius * 0.1)
	sfx("explosion", -4.0 + radius, 1.3 - radius * 0.08)
	net_mute -= 1


func ring(pos: Vector3, color: Color, radius: float, time: float, height := 0.2) -> void:
	if fx_root == null:
		return
	_net("ring", [pos, color, radius, time, height])
	var mi := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = _ring_shader
	mat.set_shader_parameter("color", color)
	mi.mesh = _plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(mi)
	mi.global_position = Vector3(pos.x, height, pos.z)
	mi.scale = Vector3(radius, 1.0, radius)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("progress", v), 0.0, 1.0, time)
	tw.tween_callback(mi.queue_free)


func sparks(pos: Vector3, color: Color, amount: int, speed: float, life := 0.6,
		size := 0.16, gravity := -14.0) -> void:
	if fx_root == null:
		return
	if amount >= 6:
		_net("sparks", [pos, color, amount, speed, life, size, gravity])
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.explosiveness = 1.0
	p.randomness = 0.5
	p.mesh = box_mesh(Vector3.ONE * size)
	p.material_override = additive_material
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color = color
	p.color_ramp = _fade_ramp
	fx_root.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.4).timeout.connect(p.queue_free)


## Chunky pieces flying off a destroyed block.
func debris(pos: Vector3, color: Color, size: Vector3) -> void:
	_net("debris", [pos, color, size])
	net_mute += 1
	sparks(pos, color, 9, 7.0, 1.0, clampf(size.x * 0.25, 0.12, 0.55), -20.0)
	sparks(pos, Color(1, 1, 1), 4, 4.0, 0.35, 0.1, 0.0)
	net_mute -= 1


func scorch(pos: Vector3, radius: float) -> void:
	if fx_root == null:
		return
	var mi := MeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = _scorch_shader
	mi.mesh = _plane
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.02 + randf() * 0.02, pos.z)
	mi.scale = Vector3(radius, 1.0, radius)
	mi.rotation.y = randf() * TAU
	_scorches.append(mi)
	if _scorches.size() > 40:
		var old = _scorches.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var tw := mi.create_tween()
	tw.tween_interval(8.0)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("fade", v), 1.0, 0.0, 4.0)
	tw.tween_callback(mi.queue_free)


func sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sounds.has(sound):
		return
	_net("sfx", [sound, volume_db, pitch])
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 40:
		return
	_last_played[sound] = now
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = _sounds[sound]
	p.volume_db = volume_db - 6.0
	p.pitch_scale = maxf(0.2, pitch * randf_range(0.93, 1.07))
	p.play()
