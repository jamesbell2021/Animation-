extends SceneTree
## Makes the keeper's log drawings (docs/STORY.md, "The keeper's log"): each still is one
## clean frame of the game's own 3D scene, redrawn as a pencil sketch by
## shaders/sketch.gdshader and saved to art/story/<id>.png (1200 x 760). StoryPages
## shows them. Needs a display (or Xvfb), like tools/screenshot.gd:
##
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --resolution 1280x800 \
##       --script res://tools/make_story_stills.gd -- [id ...] [raw=<dir>] [from=<dir>]
##
## No ids makes every still; "intro_3 diary_2" makes those two. `raw=<dir>` also saves
## each untouched frame there as <id>.png; `from=<dir>` skips the 3D altogether and
## redraws frames saved that way (quick, for working on the sketch shader). Afterwards
## run the editor once so the new PNGs are imported.
##
## To add a still: add a row to STILLS (its id, which scene, the time of day, where the
## camera stands and what it looks at), and, if anything has to be posed for it, a
## method named in the row's "stage" that takes the scene. Say, for the kraken:
##   {"id": "kraken_1", "scene": "rock", "phase": NIGHT, "from": Vector3(20.0, 6.0, 40.0),
##    "at": Vector3(48.0, 8.0, 3.0), "fov": 46.0, "stage": "_kraken_1"},
##   func _kraken_1(main: Node) -> void:    # pose it; keep what you add in _props
## A method called <stage>_late, if there is one, runs after the scene has settled and
## been frozen, just before the shot. Stage methods should ask before they touch
## (has_method, get): the scenes are still being built. Then make just that still
## ("-- kraken_1") and name it in scenes/ui/story_text.gd.
##
## Your own Continue save and profile are backed up first and put back afterwards.

const OUT_DIR := "res://art/story"
const SIZE := Vector2i(1200, 760)
const SKETCH := "res://shaders/sketch.gdshader"
const SCENES := {"harbour": "res://scenes/harbour.tscn", "rock": "res://scenes/main.tscn"}
const DAY := 0
const DUSK := 1
const NIGHT := 2
const DAWN := 3
## How light a drawing comes out by time of day: where the frame's middle grey lands
## (0 black to 1 white) once its levels are stretched. A row's "key" overrides it.
const KEYS := [0.75, 0.52, 0.40, 0.70]
## How far a frame's tones are evened out (0 a plain stretch, 1 fully).
const EVEN := 0.6
## Frames to let the scene settle before the shot (software rendering: about a second each).
const SETTLE := 6

## The stills. id · scene ("harbour" or "rock") · phase · from, at, fov: the camera ·
## stage: a method here that poses the scene (optional) · wait: frames to settle
## (optional) · key: how light (optional) · lines, hatch, reach: the sketch's weights
## (optional; see the shader).
const STILLS := [
	{"id": "intro_1", "scene": "harbour", "phase": DUSK, "from": Vector3(-12.0, 2.6, 45.0), "at": Vector3(0.5, 6.0, 18.0), "fov": 40.0, "stage": "_intro_1"},
	{"id": "intro_2", "scene": "harbour", "phase": DAY, "from": Vector3(-0.8, 1.6, 4.0), "at": Vector3(4.2, 3.0, -1.5), "fov": 60.0, "stage": "_intro_2"},
	{"id": "intro_3", "scene": "harbour", "phase": NIGHT, "from": Vector3(-9.0, 6.0, 1.0), "at": Vector3(0.5, 4.0, 26.0), "fov": 46.0, "stage": "_intro_3"},
	{"id": "intro_4", "scene": "harbour", "phase": NIGHT, "from": Vector3(-16.9, 3.1, 3.2), "at": Vector3(-14.9, 0.6, 12.0), "fov": 40.0, "stage": "_intro_4", "wait": 14},
	{"id": "intro_5", "scene": "harbour", "phase": NIGHT, "from": Vector3(10.5, 10.0, -8.0), "at": Vector3(-1.0, 8.0, -29.5), "fov": 40.0, "stage": "_intro_5"},
	{"id": "intro_6", "scene": "harbour", "phase": DAWN, "from": Vector3(8.2, 3.3, 0.2), "at": Vector3(5.2, 2.3, 20.0), "fov": 44.0, "stage": "_intro_6"},
	{"id": "crossing_1", "scene": "harbour", "phase": NIGHT, "from": Vector3(-18.0, 9.0, 22.0), "at": Vector3(0.0, 3.0, -6.0), "fov": 48.0, "stage": "_crossing_1", "key": 0.33, "lines": 1.6},
	{"id": "crossing_2", "scene": "harbour", "phase": NIGHT, "from": Vector3(15.5, 3.8, 28.5), "at": Vector3(5.2, 2.0, 21.0), "fov": 46.0, "stage": "_crossing_2"},
	{"id": "crossing_3", "scene": "rock", "phase": DAWN, "from": Vector3(-53.0, 2.6, 61.5), "at": Vector3(-22.0, 9.5, 30.0), "fov": 50.0, "stage": "_crossing_3"},
	{"id": "crossing_4", "scene": "rock", "phase": DAY, "from": Vector3(-26.0, 5.0, 40.0), "at": Vector3(3.0, 7.5, 0.0), "fov": 42.0},
	{"id": "diary_1", "scene": "rock", "phase": DAY, "from": Vector3(27.0, 9.5, 22.0), "at": Vector3(48.0, 2.0, 2.0), "fov": 46.0, "stage": "_diary_1"},
	{"id": "diary_2", "scene": "rock", "phase": NIGHT, "from": Vector3(9.5, 12.0, 13.5), "at": Vector3(-1.8, 15.6, 0.0), "fov": 42.0, "stage": "_diary_2", "key": 0.33},
	{"id": "dusk_1", "scene": "rock", "phase": DUSK, "from": Vector3.ZERO, "at": Vector3.ZERO, "fov": 46.0, "stage": "_dusk_1"},
	{"id": "after_1", "scene": "rock", "phase": DAWN, "from": Vector3(31.0, 2.6, 33.0), "at": Vector3(0.0, 8.5, 0.0), "fov": 44.0},
	{"id": "after_2", "scene": "rock", "phase": DAY, "from": Vector3(-56.0, 4.0, 72.0), "at": Vector3(6.0, 34.0, 0.0), "fov": 55.0},
	{"id": "after_3", "scene": "rock", "phase": DAY, "from": Vector3(1.5, 7.5, 6.4), "at": Vector3(0.0, 8.0, 1.5), "fov": 40.0},
]

var _cam: Camera3D
var _view: SubViewport
var _paper: ColorRect
var _mat: ShaderMaterial
## What a stage method added to the scene: freed before the next still.
var _props: Array[Node] = []
## A stage method may move the camera (a row's from/at are then only the default).
var _from := Vector3.ZERO
var _at := Vector3.ZERO
## The lamp's own tilt in this scene (a stage may change it for a shot).
var _tilt := -38.0
var _raw_dir := ""
var _from_dir := ""

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var wanted: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("raw="):
			_raw_dir = a.substr(4)
		elif a.begins_with("from="):
			_from_dir = a.substr(5)
		else:
			wanted.append(a)
	var rows: Array = []
	for row in STILLS:
		if wanted.is_empty() or wanted.has(String(row["id"])):
			rows.append(row)
	for id in wanted:
		if not STILLS.any(func(r: Dictionary) -> bool: return r["id"] == id):
			print("no still called ", id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var splash := root.get_node_or_null("StudioSplash")
	if splash:
		splash.free()
	root.size = SIZE
	_build_sketcher()
	if _from_dir != "":
		for row in rows:
			var img := Image.load_from_file(_from_dir.path_join(String(row["id"]) + ".png"))
			if img == null:
				print("no saved frame for ", row["id"])
				continue
			await _draw(img, row)
		quit()
		return
	var saved := _backup()
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	for scene_key in SCENES:
		var mine: Array = rows.filter(func(r: Dictionary) -> bool: return r["scene"] == scene_key)
		if mine.is_empty():
			continue
		var main: Node = await _open(String(scene_key))
		if main == null:
			print("could not open the ", scene_key)
			continue
		for row in mine:
			await _still(main, row)
	_restore(saved)
	quit()

# ---- the user's files ----

func _backup() -> Dictionary:
	var out := {}
	for f in ["user://run.json", "user://profile.json"]:
		if FileAccess.file_exists(f):
			out[f] = FileAccess.get_file_as_string(f)
	return out

func _restore(saved: Dictionary) -> void:
	for f in ["user://run.json", "user://profile.json"]:
		if saved.has(f):
			var w := FileAccess.open(f, FileAccess.WRITE)
			if w:
				w.store_string(saved[f])
		elif FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

# ---- the scenes ----

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## Load Kirkhaven or the rock and start a run in it, frozen: no clock, no landings, no HUD.
func _open(scene_key: String) -> Node:
	var before := current_scene
	var pl := root.get_node("Players")
	pl.wanted = 1
	pl.helpers = true
	if scene_key == "harbour":
		root.get_node("Run").enter_harbour = true
	change_scene_to_file(String(SCENES[scene_key]))
	for i in 900:
		await process_frame
		if current_scene != null and current_scene != before:
			break
	var main := current_scene
	if main == null or main == before or main.get_script() == null:
		return null
	# Under a display the rock opens on its title: start the run ourselves.
	for i in 300:
		if main.get("player") != null:
			break
		if scene_key == "rock" and main.get("title") != null and main.has_method("begin_run"):
			main.begin_run(false, 1)
		await process_frame
	if main.get("player") == null:
		return null
	await _frames(3)
	print("opened the ", scene_key)
	root.get_node("Cycle").running = false
	if main.get("spawner") != null:
		main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	if main.get("hud") != null:
		main.hud.visible = false
	for k in _keepers(main):
		var brain: Node = k.get_node_or_null("KeeperAI")
		if brain != null:
			brain.process_mode = Node.PROCESS_MODE_DISABLED
	var lh: Node = main.get("lighthouse")
	if lh != null and lh.get("lamp") != null and lh.lamp.get("tilt_deg") != null:
		_tilt = lh.lamp.tilt_deg
	_cam = Camera3D.new()
	_cam.name = "StillCamera"
	main.add_child(_cam)
	_cam.current = true
	return main

## The time of day, at once (no easing in): 0 day, 1 dusk, 2 night, 3 dawn. The run is
## marked idle while the clock is moved, so nothing the game does at dusk or dawn (the
## night's report, the next night's weather, the people going to the kirk) happens here;
## only the look changes. The weather is a clear night's: no rain across the drawing.
func _phase(main: Node, p: int) -> void:
	var cyc := root.get_node("Cycle")
	var run := root.get_node("Run")
	run.active = false
	cyc._enter(p)
	cyc.running = false
	await process_frame
	# Whatever the change set easing (light, fog, windows) is stopped where it stands...
	for tw in get_processed_tweens():
		tw.kill()
	run.active = true
	run.weather_for = run.night
	run.weather_kind = 0
	# ...and the phase's look is put on whole.
	if main.has_method("_apply_lighting"):
		main._apply_lighting(p, 0.0)
	if main.get("atmosphere") != null:
		main.atmosphere.apply(p, 0.0)
	if main.get("hud") != null:
		main.hud.visible = false
	for k in _keepers(main):
		if k.has_method("_set_lantern"):
			k._set_lantern(p == DUSK or p == NIGHT)

## Back to a bare scene: nothing posed, nobody about, every light out, no fog ashore.
func _reset(main: Node) -> void:
	for n in _props:
		if is_instance_valid(n):
			n.queue_free()
	_props.clear()
	for k in _keepers(main):
		k.visible = false
	_bloom(main, true)
	# Kirkhaven's people keep indoors unless a stage brings them out.
	for v in get_nodes_in_group("villagers"):
		if v is Node3D:
			v.visible = false
	var fog := _fog(main)
	if fog != null:
		fog.process_mode = Node.PROCESS_MODE_INHERIT
		fog.flood = 0.0
		if fog.get("_tongues") != null:
			fog._tongues.clear()
	var lh: Node = main.get("lighthouse")
	if lh != null and lh.get("lamp") != null and lh.lamp.has_method("set_tilt"):
		lh.lamp.set_tilt(_tilt)
	if main.get("lamps") != null:
		for l in main.lamps:
			l.on = false
	if main.get("houses") != null:
		for h in main.houses:
			if h.has_method("set_lit"):
				h.set_lit(false, 0.0)
	if main.get("kirk") != null and main.kirk.has_method("set_glow"):
		main.kirk.set_glow(0.0, 0.0)

func _fog(main: Node) -> Node:
	if main.get("atmosphere") == null or main.atmosphere.get("fog") == null:
		return null
	return main.atmosphere.fog

func _keepers(main: Node) -> Array:
	var out: Array = []
	if main.get("players") != null:
		for k in main.players:
			if is_instance_valid(k):
				out.append(k)
	return out

# ---- one still ----

func _still(main: Node, row: Dictionary) -> void:
	var id := String(row["id"])
	_reset(main)
	await _phase(main, int(row["phase"]))
	_from = row["from"]
	_at = row["at"]
	var stage := String(row.get("stage", ""))
	if stage != "":
		if has_method(stage):
			call(stage, main)
		else:
			print(id, ": no stage method ", stage)
	_cam.fov = float(row.get("fov", 45.0))
	_cam.look_at_from_position(_from, _at, Vector3.UP)
	_cam.current = true
	await _frames(int(row.get("wait", SETTLE)))
	_freeze(main)
	if has_method(stage + "_late"):
		call(stage + "_late", main)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		print(id, ": no frame")
		return
	if _raw_dir != "":
		img.save_png(_raw_dir.path_join(id + ".png"))
	await _draw(img, row)

## Hold everything that was posed where it is for the shot, and take the game's floating
## name tags and keeper rings out of the picture (painted signs are left alone).
func _freeze(main: Node) -> void:
	for n in _props:
		if is_instance_valid(n) and n.is_in_group("enemies"):
			n.process_mode = Node.PROCESS_MODE_DISABLED
	for l in main.find_children("*", "Label3D", true, false):
		if (l as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
			(l as Label3D).layers = 0
	for k in _keepers(main):
		var ring = k.get("_ring")
		if ring is VisualInstance3D:
			ring.layers = 0

# ---- the pencil ----

func _build_sketcher() -> void:
	_view = SubViewport.new()
	_view.size = SIZE
	_view.disable_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)
	_paper = ColorRect.new()
	_mat = ShaderMaterial.new()
	_mat.shader = load(SKETCH)
	_paper.material = _mat
	_view.add_child(_paper)
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The frame's tone curve: five points of its histogram (in) and where each is to land
## (out, 0 black to 1 white). Part plain stretch between its darkest and lightest, part
## evening-out, so a night frame's crowded darks are pulled apart; `key` is where the
## middle of the frame ends up.
func _levels(img: Image, key: float) -> Array:
	var small: Image = img.duplicate()
	small.resize(240, 152, Image.INTERPOLATE_BILINEAR)
	var ls := PackedFloat32Array()
	for y in small.get_height():
		for x in small.get_width():
			var c := small.get_pixel(x, y)
			ls.append(c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
	ls.sort()
	var n := ls.size()
	var marks := [0.01, 0.25, 0.5, 0.75, 0.995]
	var lo := ls[int(float(n) * 0.01)]
	var hi := maxf(ls[int(float(n) * 0.995)], lo + 0.06)
	var bend := log(key) / log(0.5)
	var ins := PackedFloat32Array()
	var outs := PackedFloat32Array()
	for i in marks.size():
		var v := clampf(ls[int(float(n - 1) * float(marks[i]))], lo, hi)
		if i > 0:
			v = maxf(v, ins[i - 1] + (hi - lo) * 0.03)
		var plain := clampf((v - lo) / (hi - lo), 0.0, 1.0)
		var even := pow(float(marks[i]), bend)
		ins.append(v)
		outs.append(lerpf(plain, even, EVEN))
	outs[0] = 0.0
	outs[4] = 1.0
	return [ins, outs]

## Redraw a frame in pencil and save it as the still.
func _draw(img: Image, row: Dictionary) -> void:
	var id := String(row["id"])
	img.convert(Image.FORMAT_RGB8)
	var lv := _levels(img, float(row.get("key", KEYS[int(row["phase"])])))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	# A frame of another shape is cropped about its middle, never squashed.
	var shape := (float(img.get_width()) / float(img.get_height())) / (float(SIZE.x) / float(SIZE.y))
	var crop := Vector2(1.0 / shape, 1.0) if shape > 1.0 else Vector2(1.0, shape)
	_mat.set_shader_parameter("frame", tex)
	_mat.set_shader_parameter("out_px", Vector2(SIZE))
	_mat.set_shader_parameter("crop", crop)
	_mat.set_shader_parameter("curve_in", lv[0])
	_mat.set_shader_parameter("curve_out", lv[1])
	_mat.set_shader_parameter("seed", float(absi(hash(id)) % 997) * 0.37)
	_mat.set_shader_parameter("line_weight", float(row.get("lines", 1.0)))
	_mat.set_shader_parameter("hatch_weight", float(row.get("hatch", 1.0)))
	_mat.set_shader_parameter("reach", float(row.get("reach", 0.86)))
	await _frames(2)
	await RenderingServer.frame_post_draw
	var out := _view.get_texture().get_image()
	var path := OUT_DIR.path_join(id + ".png")
	out.save_png(ProjectSettings.globalize_path(path))
	print("saved %s  (levels %.2f to %.2f, middle %.2f to %.2f)" % [path, lv[0][0], lv[0][4], lv[0][2], lv[1][2]])

# ---- posing ----

func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, Terrain.height_at(x, z), z)

## Stand keeper `i` at a spot, facing a point.
func _stand(main: Node, i: int, at: Vector3, toward: Vector3) -> void:
	var ks := _keepers(main)
	if i >= ks.size():
		return
	var k: Node3D = ks[i]
	k.visible = true
	k.global_position = Vector3(at.x, Terrain.height_at(at.x, at.z) + 0.05, at.z)
	var d := toward - at
	var yaw := atan2(-d.x, -d.z)
	if k.get("facing") != null:
		k.facing = yaw
	k.rotation.y = yaw
	if k.get("velocity") != null:
		k.velocity = Vector3.ZERO
	# A helper's last orders are dropped, or it walks off with them.
	if k.get("ai_move") != null:
		k.ai_move = Vector2.ZERO
		k.ai_held = {}
		k.ai_just = {}

## Somebody else standing about (a townsman, a survivor): `model` counts through the
## keepers' models, as harbour.gd's townsfolk do.
func _figure(main: Node, model: int, at: Vector3, toward: Vector3) -> Node3D:
	var models: Array = root.get_node("Players").MODELS
	var rig: Node3D = load("res://scenes/util/character_rig.gd").create(String(models[model % models.size()]))
	if rig == null:
		return null
	main.add_child(rig)
	_props.append(rig)
	rig.scale = Vector3.ONE * 0.85
	rig.global_position = Vector3(at.x, Terrain.height_at(at.x, at.z), at.z)
	var d := toward - at
	rig.rotation.y = atan2(d.x, d.z)
	rig.locomote(0.0)
	return rig

## One of the Bloated Dead at a spot, facing a point. Held still once it has stood up.
func _creature(main: Node, at: Vector3, toward: Vector3) -> Node3D:
	var enemies: Node = main.get_node_or_null("Enemies")
	if enemies == null or main.get("lighthouse") == null:
		return null
	var b: Node3D = load("res://scenes/enemies/bloated.gd").new()
	b.lighthouse = main.lighthouse
	b.position = at
	enemies.add_child(b)
	_props.append(b)
	b.set_meta("still_at", at)
	b.set_meta("still_toward", toward)
	return b

## Put the creatures back exactly where they were posed (they shuffle while they rise).
func _replace_creatures() -> void:
	for n in _props:
		if is_instance_valid(n) and n.has_meta("still_at"):
			var at: Vector3 = n.get_meta("still_at")
			var d: Vector3 = n.get_meta("still_toward") - at
			n.global_position = at
			n.rotation.y = atan2(-d.x, -d.z)

func _lamp(main: Node, lit: bool) -> void:
	var lh: Node = main.get("lighthouse")
	if lh != null and lh.get("lamp") != null:
		lh.lamp._set_state(1 if lit else 0)

## The glow round bright things (the environment's bloom). Off, a light keeps its own
## shape instead of swallowing what stands next to it.
func _bloom(main: Node, on: bool) -> void:
	var env = main.get("_env")
	if env is Environment:
		env.glow_enabled = on

## Kirkhaven's street lamps: the ones in `which` (indices into HarbourMap.LAMPS) burn.
func _street_lamps(main: Node, which: Array) -> void:
	if main.get("lamps") == null:
		return
	if main.get("generator") != null:
		main.generator.fuel = 90.0
	for i in main.lamps.size():
		main.lamps[i].on = which.has(i)

func _windows(main: Node, which: Array) -> void:
	if main.get("houses") == null:
		return
	for i in main.houses.size():
		if which.has(i) and main.houses[i].has_method("set_lit"):
			main.houses[i].set_lit(true, 0.0)

## The fog over the town (0 none to 1).
func _flood(main: Node, k: float) -> void:
	var fog := _fog(main)
	if fog == null:
		return
	fog.flood = k
	fog._push()

# ---- the stages ----

# The harbour light on its pier at dusk, unlit; the town behind with its lamps on.
func _intro_1(main: Node) -> void:
	_lamp(main, false)
	_street_lamps(main, range(11))
	_windows(main, [0, 2, 3, 4, 5, 6, 10, 12, 15])

# The front of The Creel, the three keepers outside.
func _intro_2(main: Node) -> void:
	_lamp(main, false)
	_stand(main, 0, Vector3(3.0, 0.0, 0.6), Vector3(-0.8, 0.0, 4.0))
	_stand(main, 1, Vector3(1.9, 0.0, -0.3), Vector3(0.5, 0.0, 6.0))
	_stand(main, 2, Vector3(4.2, 0.0, 1.5), Vector3(-0.8, 0.0, 4.0))

# Night: the fog bank off the harbour mouth, the pier and the dark light against it.
func _intro_3(main: Node) -> void:
	_lamp(main, false)

# Night: creatures standing on the west slip, dark against the fog's glow.
func _intro_4(main: Node) -> void:
	_lamp(main, false)
	# Their lit bellies would bloom over their own heads and shoulders.
	_bloom(main, false)
	var up := HarbourMap.landing_point(0, 1.0)
	for spot in [[0.74, -1.3], [0.64, 1.0], [0.56, -0.2], [0.48, 1.7], [0.42, -1.6]]:
		_creature(main, HarbourMap.landing_point(0, float(spot[0]), float(spot[1])), up + Vector3(float(spot[1]) * 0.3, 0.0, -4.0))

func _intro_4_late(_main: Node) -> void:
	_replace_creatures()

# Night: the kirk with its windows lit, the houses round it dark.
func _intro_5(main: Node) -> void:
	_lamp(main, false)
	if main.get("kirk") != null and main.kirk.has_method("set_glow"):
		main.kirk.set_glow(1.0, 0.0)

# Dawn: the three keepers on the quay, looking out to sea.
func _intro_6(main: Node) -> void:
	_lamp(main, false)
	_stand(main, 0, Vector3(7.5, 0.0, 5.1), Vector3(5.0, 0.0, 30.0))
	_stand(main, 1, Vector3(8.7, 0.0, 5.0), Vector3(7.0, 0.0, 30.0))
	_stand(main, 2, Vector3(6.3, 0.0, 4.9), Vector3(3.0, 0.0, 30.0))

# Night: the fog over the quay and up the streets, a few lamps holding.
func _crossing_1(main: Node) -> void:
	_lamp(main, false)
	_street_lamps(main, [3, 4, 9, 10])
	_flood(main, 0.7)
	if main.get("kirk") != null and main.kirk.has_method("set_glow"):
		main.kirk.set_glow(1.0, 0.0)

# The Mary Ann at the pier head, the people of the town and the keepers on the pier.
func _crossing_2(main: Node) -> void:
	_lamp(main, true)
	var boat := Vector3(7.2, 0.0, 21.0)
	_stand(main, 0, Vector3(4.3, 0.0, 23.6), boat)
	_stand(main, 1, Vector3(3.2, 0.0, 18.9), Vector3(0.0, 0.0, 6.0))
	_stand(main, 2, Vector3(2.6, 0.0, 25.0), boat)
	var spots := [Vector3(4.4, 0.0, 21.6), Vector3(4.2, 0.0, 20.3), Vector3(3.4, 0.0, 22.4), Vector3(3.0, 0.0, 20.9), Vector3(4.5, 0.0, 19.2)]
	for i in spots.size():
		_figure(main, i + 1, spots[i], boat + Vector3(0.0, 0.0, float(i) * 0.4 - 0.8))

# A small boat on the open sea under a big sky, the lighthouse small on the horizon.
func _crossing_3(main: Node) -> void:
	_lamp(main, true)
	var boat: Node3D = load("res://scenes/world/relief_boat.gd").new()
	main.add_child(boat)
	_props.append(boat)
	var at := Vector3(-40.0, Terrain.SEA_LEVEL, 55.0)
	boat.global_position = at
	# Her bow (local +X) to the rock.
	boat.rotation.y = atan2(at.z, -at.x)

# The old camp on the holm: huts, wire, a tower.
func _diary_1(main: Node) -> void:
	_lamp(main, false)

# The lantern close, lit, its beam going out over the sea.
func _diary_2(main: Node) -> void:
	_lamp(main, true)
	var lh: Node = main.get("lighthouse")
	if lh != null and lh.get("lamp") != null:
		if lh.lamp.has_method("set_tilt"):
			lh.lamp.set_tilt(-7.0)
		lh.lamp.showcase = false
		lh.lamp.yaw = deg_to_rad(110.0)

# Dusk on the rock: the keepers on the west beach, looking out.
func _dusk_1(main: Node) -> void:
	_lamp(main, true)
	var sea := Terrain.beach_point(2, 0.0)
	_stand(main, 0, Terrain.beach_point(2, 0.58, -0.2), sea)
	_stand(main, 1, Terrain.beach_point(2, 0.64, 1.1), sea)
	_stand(main, 2, Terrain.beach_point(2, 0.55, -1.5), sea)
	_from = Terrain.beach_point(2, 0.95, 2.2) + Vector3(0.0, 2.2, 0.0)
	_at = Terrain.beach_point(2, 0.25, -0.5) + Vector3(0.0, 1.2, 0.0)
