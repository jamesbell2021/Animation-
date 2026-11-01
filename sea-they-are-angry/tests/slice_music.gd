extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_music.gd
# The score: the day's music by day, quiet at dusk, the night's after, the finale on
# the last night, and the game-over piece when the light is lost. Each piece's file is
# there and loads, and the looping ones loop.

var fails := 0

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	pl.wanted = 1
	pl.helpers = false
	var A = root.get_node("Audio")
	for k in A.MUSIC:
		var s = load("res://audio/music_%s.ogg" % k)
		check(s is AudioStreamOggVorbis and s.get_length() > 10.0, "%s: %.0f s of music" % [k, s.get_length() if s != null else 0.0])
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(5)
	var Cyc = root.get_node("Cycle")
	var Run = root.get_node("Run")
	Cyc.running = false
	current_scene.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	check(A.music_now() == "day", "a run begins with the day's music (%s)" % A.music_now())
	var p: AudioStreamPlayer = A._music[A._music_on]
	check(p.playing and (p.stream as AudioStreamOggVorbis).loop, "playing, and looping")
	Cyc._enter(1)
	await _wait(2)
	check(A.music_now() == "", "dusk: it ebbs away under the foghorn")
	Cyc._enter(2)
	await _wait(2)
	check(A.music_now() == "night", "night: the night's music")
	Cyc._enter(3)
	await _wait(2)
	check(A.music_now() == "day", "dawn: the day's again")
	Run.night = load("res://scenes/systems/rescue.gd").night()
	Cyc._enter(1)
	Cyc._enter(2)
	await _wait(2)
	check(A.music_now() == "finale", "the last night: the finale")
	Run.end_run("Test")
	await _wait(2)
	check(A.music_now() == "game_over" and not (A._music[A._music_on].stream as AudioStreamOggVorbis).loop, "the light lost: the game-over piece, once")
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
