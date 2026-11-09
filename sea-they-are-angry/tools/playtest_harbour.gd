extends SceneTree
## Balance playtest for Chapter Two: the computer's keepers hold Kirkhaven on their own
## (one on the harbour light, two walking the lamps) and each dawn prints what happened.
##   godot --headless --path sea-they-are-angry --script res://tools/playtest_harbour.gd -- [calm|angry|raging] [speed]
## It stops at the ending, or when the run is lost. Your own Continue save and profile
## are backed up first and put back afterwards.

var sea := 1
var speed := 6.0
var _ended := ""
var _killed := {}
var _smashed := 0

func _init() -> void:
	_go.call_deferred()

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

func _go() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		sea = maxi(0, ["calm", "angry", "raging"].find(a[0]))
	if a.size() > 1:
		speed = float(a[1])
	var saved := _backup()
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var run = root.get_node("Run")
	var pl = root.get_node("Players")
	var cyc = root.get_node("Cycle")
	var events = root.get_node("Events")
	run.next_difficulty = sea
	pl.wanted = 1
	pl.helpers = true
	run.enter_harbour = true
	change_scene_to_file("res://scenes/harbour.tscn")
	for i in 900:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	var main = current_scene
	# The person's keeper is the computer's too: a second pair of hands on the lamps.
	var first: Player = main.player
	first.ai = true
	first.camera = null
	var brain := KeeperAI.new(first, "lamps")
	brain.name = "KeeperAI"
	first.add_child(brain)
	events.run_ended.connect(func(reason: String, _n: int) -> void: _ended = reason)
	events.enemy_killed.connect(func(e) -> void:
		var k: String = e.last_hit if e.last_hit != "" else "?"
		_killed[k] = int(_killed.get(k, 0)) + 1)
	events.structure_destroyed.connect(func(s) -> void:
		if s is StreetLamp:
			_smashed += 1)
	print("Kirkhaven, %s, %d nights to hold" % [Difficulty.name(), Rescue.night()])
	Engine.time_scale = speed
	var night_seen := 1
	var last_phase := -1
	while _ended == "" and not main._ending:
		await physics_frame
		if cyc.phase != last_phase:
			last_phase = cyc.phase
			if cyc.phase == cyc.Phase.DUSK:
				print("  dusk %d: %d of %d lamps in, generator %d%%, store %s" % [run.night, main._lamps_on(), main.lamps.size(), roundi(main.generator.fuel), JSON.stringify(root.get_node("Stock").all())])
			if cyc.phase == cyc.Phase.DAWN:
				print("night %d: ashore %d · killed %s · lamps smashed %d, in %d · generator %s · kirk %d/%d · light %d/%d fuel %d%% · bell %s" % [
					night_seen, int(main._tally.get("ashore", 0)), JSON.stringify(_killed), _smashed, main._lamps_on(),
					"wrecked" if main.generator.is_destroyed() else "%d%%" % roundi(main.generator.fuel),
					main.kirk.hp, main.kirk.max_hp, main.lighthouse.hp, main.lighthouse.max_hp, roundi(main.lighthouse.lamp.fuel),
					"rung" if int(main._tally.get("bell", 0)) > 0 else ("ready" if run.bell_mended else "not mended")])
				night_seen += 1
				_killed = {}
				_smashed = 0
		if cyc.phase == cyc.Phase.DAY and cyc.time_left < 50.0:
			# Nothing left to do by day: on to dusk, as a player would.
			var busy := false
			for k in main.players:
				var b = k.get_node_or_null("KeeperAI")
				busy = busy or (b != null and b._task in ["repair", "generator", "gather", "refuel"])
			if not busy:
				cyc.skip()
	Engine.time_scale = 1.0
	if main._ending:
		print("RESULT: held. The lights of Kirkhaven: %d of %d lamps in at the end." % [main._lamps_on(), main.lamps.size()])
	else:
		print("RESULT: lost on night %d: %s" % [run.night, _ended])
	_restore(saved)
	Terrain.chapter = 1
	quit()
