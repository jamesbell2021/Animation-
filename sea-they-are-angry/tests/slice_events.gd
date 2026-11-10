extends SceneTree
## The night's small uncanny events (NightEvents): no knock on the first night; from the
## second, three knocks at the cottage door when a keeper is inside and nothing from the
## sea is near; the wireless at dusk; the lights dipping as the fog comes ashore, and
## coming back exactly; the far foghorn from the third night; the new sounds.
##   godot --headless --path . --script res://tests/slice_events.gd
##
## No class is named here (they're loaded once the game is up, as NE, Rescue and so on):
## a script run with --script is compiled before the autoloads exist, and any class it
## names is compiled with it, and fails.

const NEW_SOUNDS := {
	"knock": [2.2, 2.6], "radio": [1.4, 1.8], "radio_voice": [1.8, 2.2], "fog_roll": [2.8, 3.2],
	"kirk_bell": [4.0, 5.0], "lamp_on": [1.4, 1.6], "lamp_off": [0.5, 0.7], "door_rattle": [0.9, 1.1],
	"heartbeat": [0.8, 1.0],
}

var fails := 0
var said: Array[String] = []
var NE

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _secs(seconds: float) -> void:
	await create_timer(seconds, false).timeout

func _heard(text: String) -> int:
	return said.count(text)

func _wireless_said() -> Array:
	var out := []
	for t in said:
		if t.begins_with(NE.WIRELESS_PREFIX):
			out.append(t)
	return out

# The loudest sample of a sound, 0 to 1.
func _peak(wav: AudioStreamWAV) -> float:
	var top := 0
	for i in wav.data.size() / 2:
		top = maxi(top, absi(wav.data.decode_s16(i * 2)))
	return float(top) / 32768.0

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(5)
	var main = current_scene
	var Cyc = root.get_node("Cycle")
	var Run = root.get_node("Run")
	var A = root.get_node("Audio")
	Cyc.running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("Events").message.connect(func(t: String) -> void: said.append(t))
	NE = load("res://scenes/world/night_events.gd")
	var Rescue = load("res://scenes/systems/rescue.gd")
	var ev = main.get_node_or_null("NightEvents")
	if ev == null:
		ev = NE.new()
		main.add_child(ev)
	var p = main.player
	var lamp = main.lighthouse.lamp
	var cot = null
	for s in get_nodes_in_group("structures"):
		if s.get("id") == "cottage":
			cot = s

	# The sounds: each is there, about the length it should be, and neither silent nor
	# louder than the rest.
	# (A recording standing in for a made sound, docs/SOUND_CREDITS.md, is checked for its
	# length only: its level was set against the made sound when it was prepared.)
	var bell = A.stream("bell")
	var bell_peak := _peak(bell) if bell is AudioStreamWAV else 0.64
	for key in NEW_SOUNDS:
		var wav = A.stream(key)
		var recorded: bool = wav is AudioStreamOggVorbis
		var ok: bool = A.SOUNDS.has(key) and (recorded or wav is AudioStreamWAV and wav.data.size() > 0)
		var length: float = 0.0
		var peak: float = bell_peak
		if ok and recorded:
			length = wav.get_length()
		elif ok:
			length = float(wav.data.size()) / 2.0 / float(A.RATE)
			peak = _peak(wav)
		check(ok and length >= NEW_SOUNDS[key][0] and length <= NEW_SOUNDS[key][1] and peak > bell_peak * 0.7 and peak < bell_peak * 1.3,
			"sound \"%s\": %.1f s, peak %.2f (the buoy bell's is %.2f)" % [key, length, peak, bell_peak])

	# What the wireless has to say.
	var lines_ok: bool = NE.WIRELESS_AFTER.size() == 3
	for n in range(2, 13):
		var lines: Array = NE.WIRELESS.get(n, [])
		lines_ok = lines_ok and lines.size() >= 1 and lines.size() <= 2
		for l in lines:
			lines_ok = lines_ok and String(l).length() > 10 and String(l).length() <= 110
	check(lines_ok, "the wireless has a line or two for each of nights 2 to 12, none over 110 letters, and three for after")
	Run.night = Rescue.night()
	check(ev.line_for(Run.night) == NE.WIRELESS_BOAT and NE.WIRELESS_BOAT.contains("Mary Ann"), "the last night: the Mary Ann has sailed")
	check(NE.WIRELESS_AFTER.has(ev.line_for(Rescue.night() + 5)), "past the table: one of the lines for after")

	# The first night: nothing. A keeper sits in the cottage all the same.
	Run.night = 1
	lamp._set_state(lamp.State.BURNING)
	lamp.fuel = 100.0
	p.global_position = cot.to_global(Vector3(0.3, 0.0, -0.2)) + Vector3(0.0, 0.3, 0.0)
	Cyc._enter(Cyc.Phase.DUSK)
	await _wait(3)
	check(ev.wireless_in < 0.0, "night 1, dusk: the wireless stays quiet")
	Cyc._enter(Cyc.Phase.NIGHT)
	await _wait(3)
	check(ev.knocks_left == 0 and ev.horn_at < 0.0, "night 1: no knock and no far foghorn to come")
	ev.knock_in = 0.0
	Engine.time_scale = 4.0
	await _secs(NE.KNOCK_INDOORS + 3.0)
	Engine.time_scale = 1.0
	check(cot.interior.contains(p.global_position) and not p.ai, "a keeper is sitting in the cottage")
	check(_heard(NE.KNOCK_CAPTION) == 0 and _wireless_said().is_empty(), "night 1: nobody knocks, nothing on the wireless")
	Cyc._enter(Cyc.Phase.DAWN)
	Cyc._enter(Cyc.Phase.DAY)
	await _wait(3)

	# The second night's dusk: the wireless.
	Run.night = 2
	lamp.fuel = 100.0
	Cyc._enter(Cyc.Phase.DUSK)
	await _wait(2)
	check(ev.wireless_in > NE.WIRELESS_DELAY - 1.0, "night 2, dusk: the wireless is coming (in %.1f s)" % ev.wireless_in)
	ev.wireless_in = 0.05
	await _secs(NE.WIRELESS_VOICE_AFTER + 0.6)
	var heard := _wireless_said()
	var first: String = heard[0] if heard.size() > 0 else ""
	check(heard.size() == 1 and NE.WIRELESS[2].has(first.trim_prefix(NE.WIRELESS_PREFIX)), "and says one of night 2's lines: " + first)
	await _secs(1.0)
	check(_wireless_said().size() == 1 and ev.wireless_in < 0.0, "once")

	# The second night: a knock, but not while anything from the sea is near.
	Cyc._enter(Cyc.Phase.NIGHT)
	lamp._set_state(lamp.State.BURNING)
	await _wait(3)
	check(ev.knocks_left >= 1 and ev.knocks_left <= 2 and ev.knock_in >= NE.KNOCK_FIRST_MIN - 1.0, "night 2: a knock or two to come (%d, the first in %.0f s)" % [ev.knocks_left, ev.knock_in])
	check(ev.horn_at < 0.0, "but no far foghorn until night %d" % NE.HORN_FROM)
	var thing = load("res://scenes/enemies/bloated.gd").new()
	thing.lighthouse = main.lighthouse
	var out: Vector3 = (cot.global_position * Vector3(1.0, 0.0, 1.0)).normalized()
	thing.position = cot.global_position + Vector3(-out.z, 0.0, out.x) * 6.0 + Vector3(0.0, 0.3, 0.0)
	main.get_node("Enemies").add_child(thing)
	thing.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(2)
	var room_light: OmniLight3D = cot._room_light
	var lit: float = room_light.light_energy
	ev.knocks_left = 2
	ev.knock_in = 0.0
	Engine.time_scale = 4.0
	await _secs(NE.KNOCK_INDOORS + 2.0)
	Engine.time_scale = 1.0
	var off: float = thing.global_position.distance_to(cot.global_position)
	check(off < NE.KNOCK_CLEAR and _heard(NE.KNOCK_CAPTION) == 0, "something from the sea %.0f m from the cottage: no knock" % off)
	thing.queue_free()
	await _secs(0.4)
	check(_heard(NE.KNOCK_CAPTION) == 1, "it's gone: three slow knocks at the door")
	check(room_light.is_in_group(NE.FLICKER_GROUP) and lit > 0.5 and room_light.light_energy < lit * 0.6, "the lamp in the room sinks while they last (%.2f of %.2f)" % [room_light.light_energy, lit])
	# The light at the windows is set by the cottage every frame (its fire flickers).
	var window_light: OmniLight3D = cot._lamp
	check(window_light.light_energy < cot.LAMP_ENERGY * 0.55, "and the light at the windows, which the cottage keeps flickering (%.2f of about %.2f)" % [window_light.light_energy, cot.LAMP_ENERGY])
	check(ev.knocks_left == 1 and ev.knock_in >= NE.KNOCK_GAP - 1.0, "the next no sooner than a minute on (%.0f s)" % ev.knock_in)
	await _secs(NE.KNOCK_TIME + 0.3)
	check(room_light.light_energy == lit and window_light.light_energy > cot.LAMP_ENERGY * 0.6, "and they come back as they were (%.3f, %.2f)" % [room_light.light_energy, window_light.light_energy])
	Engine.time_scale = 4.0
	await _secs(NE.KNOCK_INDOORS + 3.0)
	Engine.time_scale = 1.0
	check(_heard(NE.KNOCK_CAPTION) == 1 and cot.interior.contains(p.global_position), "still inside a few seconds later: no second knock yet")
	check(Run.active, "the run is still going")

	# The fog comes ashore: a light of the group near the landing stutters, and gets its
	# energy back exactly. One too far off, and one not of the group, are left alone.
	var shore: Vector3 = main.spawner.points[0]
	var near := OmniLight3D.new()
	var far := OmniLight3D.new()
	var other := OmniLight3D.new()
	var doomed := SpotLight3D.new()
	for l in [near, far, other, doomed]:
		main.add_child(l)
		l.light_energy = 2.3
	near.global_position = shore + Vector3(3.0, 2.0, 0.0)
	doomed.global_position = shore + Vector3(-3.0, 2.0, 1.0)
	other.global_position = shore + Vector3(0.0, 2.0, 3.0)
	far.global_position = shore + Vector3(NE.ASHORE_RADIUS + 6.0, 2.0, 0.0)
	for l in [near, far, doomed]:
		l.add_to_group(NE.FLICKER_GROUP)
	var was := near.light_energy
	ev.fog_ashore(shore)
	var low := was
	var levels := {}
	var others_still := true
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until:
		await process_frame
		low = minf(low, near.light_energy)
		levels[snappedf(near.light_energy, 0.001)] = true
		others_still = others_still and far.light_energy == was and other.light_energy == was
	check(low < was * (NE.DIP_MAX + 0.01) and low > was * (NE.DIP_MIN - 0.01), "the fog ashore: a light near it dips (to %.0f%%)" % (low / was * 100.0))
	check(levels.size() >= 3, "in a few uneven steps (%d levels)" % levels.size())
	check(others_still, "one %d m off, and one not of the group, don't" % int(NE.ASHORE_RADIUS + 6.0))
	await _secs(NE.FLICKER_TIME + 0.2)
	check(near.light_energy == was, "and it comes back exactly (%.4f)" % near.light_energy)
	# Again, and again while it's still at it, and one of them is taken away meanwhile.
	ev.fog_ashore(shore)
	await _secs(0.4)
	var mid := near.light_energy
	ev.fog_ashore(shore)
	ev.flicker([near, doomed, null], 0.8)
	doomed.queue_free()
	await _secs(1.5)
	check(mid < was and near.light_energy == was and ev._dips.is_empty(), "called again part-way, and a light freed part-way: still back exactly (%.4f)" % near.light_energy)
	# A real landing place is near enough to the cottage for its lights to feel it.
	var nearest := INF
	for pt in main.spawner.points:
		nearest = minf(nearest, Vector2(pt.x - room_light.global_position.x, pt.z - room_light.global_position.z).length())
	print("   the nearest landing to the cottage's lamp is %.1f m off (the lights within %.0f m stutter)" % [nearest, NE.ASHORE_RADIUS])
	# A wider reach, as asked: the landing nearest the cottage takes its lamp down too.
	var landing: Vector3 = main.spawner.points[0]
	for pt in main.spawner.points:
		if pt.distance_to(room_light.global_position) < landing.distance_to(room_light.global_position):
			landing = pt
	ev.fog_ashore(landing, nearest + 1.0)
	await _secs(0.1)
	check(room_light.light_energy < lit, "a landing with a reach of %.0f m dips the cottage's lamp (%.2f of %.2f)" % [nearest + 1.0, room_light.light_energy, lit])
	await _secs(NE.FLICKER_TIME + 0.2)
	check(room_light.light_energy == lit, "and it comes back exactly")
	for l in [near, far, other]:
		l.queue_free()

	# The third night: a foghorn far out, its caption once in a run.
	Cyc._enter(Cyc.Phase.DAWN)
	Cyc._enter(Cyc.Phase.DAY)
	await _wait(2)
	check(ev.knocks_left == 0 and ev.wireless_in < 0.0, "by day: nothing waiting")
	Run.night = 3
	Cyc._enter(Cyc.Phase.DUSK)
	Cyc._enter(Cyc.Phase.NIGHT)
	lamp._set_state(lamp.State.BURNING)
	lamp.fuel = 100.0
	await _wait(2)
	ev.wireless_in = -1.0
	check(ev.horn_at >= 0.33 and ev.horn_at <= 0.67, "night 3: a far foghorn in the middle third of the night (%.2f)" % ev.horn_at)
	ev.horn_at = 0.0
	await _wait(3)
	check(_heard(NE.HORN_CAPTION) == 1 and ev.horn_at < 0.0 and ev._later.size() == 1, "it sounds, with its caption, and an answer to come")
	await _secs(1.0)
	ev._later[0][0] = 0.05
	await _secs(0.3)
	check(ev._later.is_empty(), "the answer, from another quarter")
	ev.horn_at = 0.0
	await _wait(3)
	check(_heard(NE.HORN_CAPTION) == 1, "another night's: no caption the second time")
	check(Run.active, "and the run goes on")

	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
