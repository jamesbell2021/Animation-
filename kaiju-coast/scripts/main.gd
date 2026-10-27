class_name Main
extends Node3D
## Builds the whole game in code and runs it: the simulation step (scaled by game speed, the boss
## slow-mo and pause), the command-view controls (select rings, pan, zoom, hotkeys), building and
## upgrading, the attract-mode demo behind the title screen, and the CRT post-process.

var kaiju_root: Node3D
var turret_root: Node3D
var _pad_nodes: Array[MeshInstance3D] = []
var _pad_mats: Array[ShaderMaterial] = []
var _range_ring: MeshInstance3D
var _range_lines: FrameLines = FrameLines.new()
var _crt: ShaderMaterial
var _crt_rect: ColorRect
var _kid: int = 0
var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _press: bool = false
var hover: Pad = null
## True after the last input came from a controller (menus keep focus, the panel grabs it).
var using_pad: bool = false
var _pad_cycle: int = -1


func _ready() -> void:
	Game.main = self
	if "--touch" in OS.get_cmdline_user_args():
		TouchControls.forced = true
	Sfx.make_buses()
	Game.make_pads()
	var world: World = World.new()
	world.name = "World"
	Game.world = world
	add_child(world)
	var fx: Fx = Fx.new()
	fx.name = "Fx"
	Game.fx = fx
	add_child(fx)
	var combat: Combat = Combat.new()
	combat.name = "Combat"
	Game.combat = combat
	add_child(combat)
	var sfx: Sfx = Sfx.new()
	sfx.name = "Sfx"
	Game.sfx = sfx
	add_child(sfx)
	var music: Music = Music.new()
	music.name = "Music"
	Game.music = music
	add_child(music)
	var rig: CameraRig = CameraRig.new()
	rig.name = "CameraRig"
	Game.rig = rig
	add_child(rig)
	var player: Player = Player.new()
	player.name = "Player"
	Game.player = player
	add_child(player)
	player.attach_view_model(rig.cam)
	var voice: Voice = Voice.new()
	voice.name = "Voice"
	Game.voice = voice
	add_child(voice)
	var ab: Abilities = Abilities.new()
	ab.name = "Abilities"
	Game.abilities = ab
	add_child(ab)
	var zep: Zeppelin = Zeppelin.new()
	zep.name = "Zeppelin"
	Game.zep = zep
	add_child(zep)
	turret_root = Node3D.new()
	turret_root.name = "Guns"
	add_child(turret_root)
	kaiju_root = Node3D.new()
	kaiju_root.name = "Kaiju"
	add_child(kaiju_root)
	_make_pads()
	_range_ring = MeshInstance3D.new()
	_range_ring.mesh = _range_lines.mesh
	_range_ring.material_override = Mats.line(1.6)
	add_child(_range_ring)
	var tut: Tutorial = Tutorial.new()
	tut.name = "Tutorial"
	Game.tutorial = tut
	add_child(tut)
	var hud: Hud = Hud.new()
	hud.name = "Hud"
	Game.hud = hud
	add_child(hud)
	var post: CanvasLayer = CanvasLayer.new()
	post.layer = 10
	add_child(post)
	var crt: ColorRect = ColorRect.new()
	_crt_rect = crt
	crt.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt = ShaderMaterial.new()
	_crt.shader = preload("res://shaders/crt.gdshader")
	crt.material = _crt
	post.add_child(crt)
	Settings.load_all()
	Settings.apply()
	start_demo()


func set_crt(on: bool) -> void:
	_crt.set_shader_parameter("scanline_strength", 0.16 if on else 0.0)
	_crt.set_shader_parameter("aberration", 0.0011 if on else 0.0)
	_crt.set_shader_parameter("vignette", 0.85 if on else 0.35)


func _notification(what: int) -> void:
	# Alt-tabbing away mid-wave pauses the game (and frees the mouse) instead of losing the city.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and Game.state == Game.State.PLAY and not Game.paused:
		toggle_pause()
		Game.player.firing = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	# Static mesh/material caches would otherwise outlive the scene and show up as leaks on quit.
	Mats._cache.clear()
	Kaiju._cache.clear()
	Turret._cache.clear()


# ------------------------------------------------------------------ setup --

func _make_pads() -> void:
	for p: Pad in Game.pads:
		var sb: SolidBuilder = SolidBuilder.new()
		if p.fort:
			sb.box(Vector3(0, -0.75, 0), Vector3(26, 1.5, 26), Mats.PAPER)
			for sx: float in [-11.0, 11.0]:
				for sz: float in [-11.0, 11.0]:
					sb.tube(Vector3(sx, -1.5, sz), Vector3(sx * 1.15, -26, sz * 1.15), 1.2, 1.4, 6, Mats.PAPER, 1, 3)
			sb.edge(Vector3(-11, -12, -11), Vector3(11, -12, 11), Mats.PAPER * 0.6)
			sb.edge(Vector3(11, -12, -11), Vector3(-11, -12, 11), Mats.PAPER * 0.6)
			var root: Node3D = Node3D.new()
			root.position = p.pos
			add_child(root)
			sb.attach(root, Mats.fill(), Mats.line(1.8))
		var lb: LineBuilder = LineBuilder.new()
		lb.circle(Vector3(0, 0.3, 0), 9.0, Vector3.RIGHT, Vector3.BACK, Color.WHITE, 24)
		lb.circle(Vector3(0, 0.3, 0), 6.0, Vector3.RIGHT, Vector3.BACK, Color.WHITE * 0.6, 16)
		lb.line(Vector3(-3, 0.3, 0), Vector3(3, 0.3, 0), Color.WHITE)
		lb.line(Vector3(0, 0.3, -3), Vector3(0, 0.3, 3), Color.WHITE)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = lb.build_mesh()
		var m: ShaderMaterial = Mats.make_line(2.0)
		mi.material_override = m
		mi.position = p.pos
		add_child(mi)
		_pad_nodes.append(mi)
		_pad_mats.append(m)


func clear_world() -> void:
	Game.player.exit_seat()
	for k: Kaiju in Game.kaiju:
		k.queue_free()
	Game.kaiju.clear()
	for t: Turret in Game.turrets:
		t.queue_free()
	Game.turrets.clear()
	for p: Pad in Game.pads:
		p.turret = null
	Game.combat.clear()
	Game.fx.clear()
	Game.abilities.reset()
	Game.world.build_city()
	Game.zep.reset()
	Game.sel = null
	Game.shake = 0.0
	Game.flash = 0.0


func start_demo() -> void:
	clear_world()
	Game.demo = true
	Game.state = Game.State.TITLE
	Game.city = 100.0
	Game.hp_mul = 1.3
	Game.world.set_weather("rain")
	for spec: Array in [[1, "cannon", 2], [3, "rail", 2], [5, "rocket", 2], [9, "tesla", 3], [8, "flak", 2], [11, "cannon", 3], [12, "rocket", 1]]:
		var t: Turret = build_turret(Game.pads[spec[0]], spec[1])
		while t.lvl < int(spec[2]):
			t.level_up()
	Game.zep.lvl["pods"] = 1
	Game.zep.lvl["bomb"] = 1
	for i: int in range(3):
		var k: Kaiju = spawn_kaiju(["oni", "kani", "ryu", "tengu"].pick_random())
		k.position.z = -300.0 - float(i) * 220.0
	Game.rig.set_mode("title")
	Game.music.set_mode("title")
	Game.state_changed.emit()


func to_title() -> void:
	start_demo()


func spawn_kaiju(t: String) -> Kaiju:
	var d: Dictionary = Game.KT[t]
	var k: Kaiju = Kaiju.new()
	_kid += 1
	k.setup(t, Game.hp_mul, _kid)
	k.target_x = randf_range(-290, 290)
	k.position = Vector3(randf_range(-360, 360), -40, -1040.0 - randf_range(0, 90))
	if d["air"]:
		k.position = Vector3(randf_range(-360, 360), randf_range(80, 115), -950)
	if d["boss"]:
		k.target_x = randf_range(-80, 80)
		k.position.x = randf_range(-120, 120)
	if t == "ryu":
		k.position.y = -5.0
	kaiju_root.add_child(k)
	Game.kaiju.append(k)
	k.pose(0.0)
	k.refresh_hits()
	if not d["air"]:
		Game.fx.ring(Vector3(k.position.x, 0.6, k.position.z), 10.0, 40.0, 2.5, Mats.CYAN)
		Game.fx.sparks(Vector3(k.position.x, 2, k.position.z), 30, Mats.CYAN, 60.0, 40.0)
	Game.sfx.play_at("roar_boss" if d["boss"] else "roar", k.position, 1.0)
	if d["boss"] and not Game.demo:
		if t == "orochi":
			Game.banner.emit("八岐大蛇 襲来", "OROCHI RISES FROM THE BAY", 3.2)
		else:
			Game.banner.emit("大鬼 襲来", "DAI-ONI IS COMING ASHORE", 3.2)
		Game.say(t)
		Game.fx.text(Vector3(k.position.x, 160, k.position.z), "ゴゴゴゴ…", Mats.SHU, 60.0, 3.0)
	return k


func build_turret(p: Pad, type: String) -> Turret:
	var t: Turret = Turret.new()
	turret_root.add_child(t)
	t.setup(p, type)
	p.turret = t
	Game.turrets.append(t)
	return t


func remove_turret(t: Turret) -> void:
	t.pad.turret = null
	Game.turrets.erase(t)
	t.queue_free()
	Game.hud_dirty.emit()


# ------------------------------------------------------------------ actions --

func select(s: Variant) -> void:
	Game.sel = s
	if s != null:
		Game.sfx.play("click")
	Game.hud.refresh(true)


func act(a: String, t: String) -> void:
	var s: Variant = Game.sel
	var pad: Pad = s if s is Pad else null
	match a:
		"build":
			var d: Dictionary = Game.TT[t]
			if pad == null or pad.turret != null or Game.funds < int(d["cost"]):
				Game.sfx.play("deny")
				return
			Game.funds -= int(d["cost"])
			build_turret(pad, t)
			Game.sfx.play("build")
			Game.fx.sparks(pad.pos + Vector3(0, 4, 0), 30, Mats.JADE, 50.0)
			Game.fx.text(pad.pos + Vector3(0, 16, 0), "設置!", Mats.JADE, 8.0, 1.0)
		"up":
			if pad == null or pad.turret == null:
				return
			var tt: Turret = pad.turret
			var c: int = Game.up_cost(tt.type, tt.lvl) if tt.lvl < Game.MAXL else 0
			if tt.lvl == 2 and t != "a" and t != "b":
				Game.banner.emit("", "CHOOSE AN UPGRADE PATH IN THE PANEL", 1.6)
				Game.sfx.play("deny")
				return
			if tt.lvl >= Game.MAXL or Game.funds < c:
				Game.sfx.play("deny")
				return
			Game.funds -= c
			tt.spent += c
			tt.level_up(t)
			Game.sfx.play("build")
			Game.fx.sparks(pad.pos + Vector3(0, 8, 0), 40, Mats.GOLD, 60.0)
			Game.fx.text(pad.pos + Vector3(0, 18, 0), "強化!", Mats.GOLD, 9.0, 1.0)
		"rep":
			if pad == null or pad.turret == null:
				return
			var tr: Turret = pad.turret
			var rc: int = ceili((Game.max_hp(tr.lvl) - tr.hp) * 0.5)
			if rc <= 0 or Game.funds < rc:
				Game.sfx.play("deny")
				return
			Game.funds -= rc
			tr.hp = Game.max_hp(tr.lvl)
			Game.sfx.play("build")
		"sell":
			if pad == null or pad.turret == null:
				return
			Game.funds += roundi(float(pad.turret.spent) * 0.6)
			if Game.player.active and Game.player.seat is Turret and Game.player.seat == pad.turret:
				Game.player.exit_seat()
			remove_turret(pad.turret)
		"zup":
			var z: Zeppelin = Game.zep
			var l: int = z.lvl[t]
			if l >= 3 or z.down or Game.funds < int(Game.ZUP[t]["costs"][l]):
				Game.sfx.play("deny")
				return
			Game.funds -= int(Game.ZUP[t]["costs"][l])
			z.lvl[t] = l + 1
			if t == "armor":
				z.max_hp += 150.0
				z.hp += 150.0
			Game.sfx.play("build")
		"zrep":
			var z2: Zeppelin = Game.zep
			var zc: int = ceili((z2.max_hp - z2.hp) * 0.6)
			if zc <= 0 or z2.down or Game.funds < zc:
				Game.sfx.play("deny")
				return
			Game.funds -= zc
			z2.hp = z2.max_hp
			Game.sfx.play("build")
		"arm":
			var al: int = Game.armory[t]
			if al >= 4 or Game.funds < int(Game.AUP[t]["costs"][al]):
				Game.sfx.play("deny")
				return
			Game.funds -= int(Game.AUP[t]["costs"][al])
			Game.armory[t] = al + 1
			Game.sfx.play("build")
		"wall":
			if Game.funds < 250 or Game.city >= 100.0:
				Game.sfx.play("deny")
				return
			Game.funds -= 250
			Game.city = minf(100.0, Game.city + 15.0)
			Game.sfx.play("build")
	Game.hud.refresh(true)


func cycle_speed() -> void:
	Game.speed = 2 if Game.speed == 1 else (3 if Game.speed == 2 else 1)
	Game.hud.refresh(true)


func toggle_pause() -> void:
	if Game.state != Game.State.PLAY:
		return
	Game.paused = not Game.paused
	Game.hud.show_pause(Game.paused)
	if Game.player.active:
		Game.player.firing = false
		if Game.paused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Player.capture_mouse()
	Game.hud.refresh(true)


func toggle_music() -> void:
	Game.music.set_enabled(not Game.music.enabled)
	Game.hud.refresh(true)


func toggle_fullscreen() -> void:
	Settings.set_v("fullscreen", not bool(Settings.get_v("fullscreen")))
	Game.hud.refresh_settings()


# ------------------------------------------------------------------ input --

func pick_at(sp: Vector2) -> Variant:
	var cam: Camera3D = Game.rig.cam
	var best: Variant = null
	var bd: float = 46.0
	for p: Pad in Game.pads:
		if cam.is_position_behind(p.pos):
			continue
		var d: float = cam.unproject_position(p.pos).distance_to(sp)
		if d < bd:
			bd = d
			best = p
	var z: Zeppelin = Game.zep
	if not z.down and not cam.is_position_behind(z.position):
		var zs: Vector2 = cam.unproject_position(z.position)
		var edge: Vector2 = cam.unproject_position(z.position + cam.global_transform.basis.x.normalized() * 70.0)
		var r: float = zs.distance_to(edge)
		var dz: float = zs.distance_to(sp)
		if dz < r and (best == null or dz < bd * 0.6 or bd > 30.0):
			best = "zep"
	return best


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4):
		using_pad = true
	elif event is InputEventMouseButton or event is InputEventKey:
		using_pad = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_joy(event as InputEventJoypadButton)
		return
	if event is InputEventKey:
		_key(event as InputEventKey)
		return
	if Game.state != Game.State.PLAY or Game.player.active:
		return
	if event is InputEventMouseButton and Game.abilities.targeting != "":
		var tb: InputEventMouseButton = event
		if tb.pressed and tb.button_index == MOUSE_BUTTON_LEFT:
			var p: Variant = Game.abilities.ground_at(tb.position)
			if p is Vector3:
				Game.abilities.fire(Game.abilities.targeting, p)
			get_viewport().set_input_as_handled()
			return
		if tb.pressed and tb.button_index == MOUSE_BUTTON_RIGHT:
			Game.abilities.cancel()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton:
		var b: InputEventMouseButton = event
		if b.button_index == MOUSE_BUTTON_WHEEL_UP and b.pressed:
			Game.rig.zoom = clampf(Game.rig.zoom - 0.08, 0.45, 1.6)
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN and b.pressed:
			Game.rig.zoom = clampf(Game.rig.zoom + 0.08, 0.45, 1.6)
		elif b.button_index == MOUSE_BUTTON_LEFT or b.button_index == MOUSE_BUTTON_RIGHT or b.button_index == MOUSE_BUTTON_MIDDLE:
			if b.pressed:
				_press = true
				_dragging = false
				_drag_start = b.position
			else:
				if _press and not _dragging and b.button_index == MOUSE_BUTTON_LEFT:
					var s: Variant = pick_at(b.position)
					select(s)
				_press = false
	elif event is InputEventMouseMotion:
		var m: InputEventMouseMotion = event
		if _press:
			if m.position.distance_to(_drag_start) > 8.0:
				_dragging = true
			if _dragging:
				var vw: float = get_viewport().get_visible_rect().size.x
				Game.rig.cmd_x = clampf(Game.rig.cmd_x - m.relative.x * 0.9 * Game.rig.zoom * (1000.0 / maxf(500.0, vw)), -320.0, 320.0)
				Game.rig.zoom = clampf(Game.rig.zoom + m.relative.y * 0.003, 0.45, 1.6)
		else:
			var h: Variant = pick_at(m.position)
			hover = h if h is Pad else null


func _key(k: InputEventKey) -> void:
	if not k.pressed or k.echo:
		if not k.pressed and k.physical_keycode == KEY_SPACE:
			pass
		return
	var code: Key = k.physical_keycode
	if code == KEY_F11 or (code == KEY_ENTER and k.alt_pressed):
		toggle_fullscreen()
		return
	if Game.hud.menu_open():
		if code == KEY_ESCAPE or code == KEY_P:
			Game.hud.back()
		return
	if Game.state == Game.State.TITLE:
		if code == KEY_ENTER or code == KEY_SPACE:
			Game.new_game()
		return
	if Game.state != Game.State.PLAY:
		return
	var pl: Player = Game.player
	match code:
		KEY_SPACE:
			if Game.phase == "build":
				Game.start_wave()
		KEY_F:
			if pl.active:
				pl.exit_seat()
			else:
				pl.enter(null)
		KEY_Z:
			if pl.active and pl.seat is String:
				pl.exit_seat()
			else:
				pl.enter("zep")
		KEY_ESCAPE:
			if Game.abilities.targeting != "":
				Game.abilities.cancel()
			elif pl.active:
				pl.exit_seat()
			elif Game.sel != null:
				select(null)
			else:
				toggle_pause()
		KEY_7:
			Game.abilities.request("air")
		KEY_8:
			Game.abilities.request("storm")
		KEY_9:
			Game.abilities.request("flood")
		KEY_Q:
			if pl.active:
				pl.swap()
		KEY_TAB, KEY_E:
			if pl.active:
				pl.next_seat()
			elif code == KEY_TAB:
				var s: Array = pl.seats()
				if not s.is_empty():
					pl.enter(s[0])
		KEY_B:
			if not pl.active:
				select(null if (Game.sel is String and Game.sel == "armory") else "armory")
		KEY_U:
			if not pl.active:
				act("up", "")
		KEY_R:
			if pl.active:
				pl.manual_reload()
			else:
				act("rep", "")
		KEY_X:
			if not pl.active:
				act("sell", "")
		KEY_T:
			cycle_speed()
		KEY_P:
			toggle_pause()
		KEY_M:
			toggle_music()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			var idx: int = int(code) - int(KEY_1)
			if pl.active:
				if idx == 0:
					pl.set_weapon("gun")
				elif idx == 1:
					pl.set_weapon("rocket")
			elif Game.sel is Pad and (Game.sel as Pad).turret == null:
				act("build", Game.TT_KEYS[idx])


# ------------------------------------------------------------------ loop --

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	if Game.slowmo > 0.0:
		Game.slowmo -= dt
		dt *= 0.3
	Game.flash = maxf(0.0, Game.flash - dt * 1.5)
	var running: bool = Game.state != Game.State.PLAY or not Game.paused
	if running:
		var sp: float = float(Game.speed) if (Game.state == Game.State.PLAY and not Game.player.active) else 1.0
		var sdt: float = dt * sp
		var n: int = ceili(sdt / 0.034)
		for i: int in range(n):
			step(sdt / float(n))
	_pad_sticks(delta)
	Game.rig.update(delta)
	Game.combat.draw()
	if Game.abilities.targeting != "":
		Game.abilities.reticle = Game.abilities.ground_at(get_viewport().get_mouse_position())
	Game.abilities.draw()
	Game.fx.draw()
	_update_pads()
	_crt.set_shader_parameter("hurt", Game.hurt if Game.state == Game.State.PLAY else 0.0)
	_crt.set_shader_parameter("flash", Game.flash)


## One simulation step. Public so the headless tests can drive the game without rendering.
func step(dt: float) -> void:
	Game.t += dt
	for k: Kaiju in Game.kaiju:
		k.update(dt)
	for i: int in range(Game.kaiju.size() - 1, -1, -1):
		var k2: Kaiju = Game.kaiju[i]
		if k2.dead:
			Game.kaiju.remove_at(i)
			k2.queue_free()
	for k3: Kaiju in Game.kaiju:
		k3.pose(dt)
		k3.refresh_hits()
	for t: Turret in Game.turrets.duplicate():
		t.update(dt)
	Game.zep.update(dt)
	Game.player.update(dt)
	if Game.state == Game.State.PLAY:
		Game.abilities.update(dt)
	Game.combat.update(dt)
	Game.fx.update(dt)
	if Game.demo:
		if Game.live_kaiju() < 4 and randf() < dt * 0.25:
			spawn_kaiju(["oni", "oni", "kani", "ryu", "tengu", "tengu"].pick_random())
		for k4: Kaiju in Game.kaiju:
			if k4.state == "rampage" and not k4.dying and randf() < dt * 0.3:
				Game.combat.kill_kaiju(k4, Vector3.RIGHT)
		if Game.zep.down and Game.zep.down_t > 8.0:
			Game.zep.down_t = 30.0
	elif Game.state == Game.State.PLAY:
		Game.update_waves(dt)
		Game.hurt = maxf(0.0, Game.hurt - dt * 0.6)
		if Game.city < 35.0 and not Game.city_warned:
			Game.city_warned = true
			Game.say("city_low")
		elif Game.city > 60.0:
			Game.city_warned = false
		if Game.city <= 0.0:
			Game.city = 0.0
			Game.end_game(false)


func _update_pads() -> void:
	for i: int in range(Game.pads.size()):
		var p: Pad = Game.pads[i]
		var m: ShaderMaterial = _pad_mats[i]
		var sel: bool = Game.sel is Pad and Game.sel == p
		var col: Color
		if sel:
			col = Color(2.0, 2.0, 2.0)
		elif hover == p:
			col = Mats.GOLD * 1.6
		elif p.turret != null:
			col = Mats.JADE * 0.45
		else:
			col = Mats.GOLD * (0.55 + 0.25 * sin(Game.t * 4.0 + float(i)))
		if Game.tutorial.highlight_pad() == i and not sel:
			col = Color(2.4, 2.1, 1.2) * (0.6 + 0.4 * sin(Game.t * 8.0))
		m.set_shader_parameter("tint", Vector3(col.r, col.g, col.b))
		_pad_nodes[i].visible = not (Game.player.active)
	_range_lines.clear()
	if Game.sel is Pad and (Game.sel as Pad).turret != null and not Game.player.active:
		var t: Turret = (Game.sel as Pad).turret
		var r: float = float(t.stat()["range"])
		for i2: int in range(0, 64, 2):
			var a0: float = TAU * float(i2) / 64.0
			var a1: float = TAU * float(i2 + 1) / 64.0
			_range_lines.seg(t.pad.pos + Vector3(cos(a0) * r, 1.5, sin(a0) * r), t.pad.pos + Vector3(cos(a1) * r, 1.5, sin(a1) * r), Mats.JADE)
	_range_lines.commit()


# ------------------------------------------------------------------ controller --

func _joy(e: InputEventJoypadButton) -> void:
	if not e.pressed:
		return
	if Game.hud.menu_open():
		if e.button_index == JOY_BUTTON_B or e.button_index == JOY_BUTTON_START:
			Game.hud.back()
		return
	if Game.state == Game.State.TITLE:
		if e.button_index == JOY_BUTTON_START:
			Game.new_game()
		return
	if Game.state != Game.State.PLAY:
		return
	var pl: Player = Game.player
	match e.button_index:
		JOY_BUTTON_START:
			if Game.phase == "build":
				Game.start_wave()
			else:
				toggle_pause()
		JOY_BUTTON_BACK:
			toggle_pause()
		JOY_BUTTON_B:
			if Game.abilities.targeting != "":
				Game.abilities.cancel()
			elif pl.active:
				pl.exit_seat()
			else:
				select(null)
				get_viewport().gui_release_focus()
		JOY_BUTTON_Y:
			if pl.active:
				pl.swap()
			else:
				pl.enter(null)
		JOY_BUTTON_X:
			if pl.active:
				pl.manual_reload()
			else:
				select(null if (Game.sel is String and Game.sel == "zep") else "zep")
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
			var dir: int = 1 if e.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1
			if pl.active:
				pl.next_seat()
			else:
				var n: int = Game.pads.size() + 1
				_pad_cycle = (_pad_cycle + dir + n) % n
				var target: Variant = "zep" if _pad_cycle == Game.pads.size() else Game.pads[_pad_cycle]
				select(target)
				if target is Pad:
					Game.rig.cmd_x = clampf((target as Pad).pos.x, -320.0, 320.0)
		JOY_BUTTON_DPAD_LEFT:
			_pad_ability("air")
		JOY_BUTTON_DPAD_UP:
			_pad_ability("storm")
		JOY_BUTTON_DPAD_RIGHT:
			_pad_ability("flood")
		JOY_BUTTON_A:
			if not pl.active and Game.sel == null:
				var s: Variant = pick_at(get_viewport().get_visible_rect().size * 0.5)
				if s == null:
					s = Game.pads[3]
				select(s)


## Tests: run the tutorial's check once without waiting for a frame.
func tutorial_tick() -> void:
	Game.tutorial._process(0.0)


## Special attacks from the d-pad: in the command view they land at the centre of the screen.
func _pad_ability(k: String) -> void:
	var ab: Abilities = Game.abilities
	if Game.player.active:
		ab.request(k)
		return
	ab.request(k)
	if ab.targeting == k:
		var p: Variant = ab.ground_at(get_viewport().get_visible_rect().size * 0.5)
		if p is Vector3:
			ab.fire(k, p)
		else:
			ab.cancel()


## Left stick pans and zooms the command view (when no menu button has focus).
func _pad_sticks(delta: float) -> void:
	if Game.state != Game.State.PLAY or Game.player.active or Game.paused:
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	var lx: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var ly: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	var rt: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	var lt: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	if absf(lx) > 0.2:
		Game.rig.cmd_x = clampf(Game.rig.cmd_x + lx * delta * 300.0 * Game.rig.zoom, -320.0, 320.0)
	if absf(ly) > 0.2:
		Game.rig.zoom = clampf(Game.rig.zoom + ly * delta * 0.8, 0.45, 1.6)
	if rt > 0.3 or lt > 0.3:
		Game.rig.zoom = clampf(Game.rig.zoom + (lt - rt) * delta * 0.8, 0.45, 1.6)
