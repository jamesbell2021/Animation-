extends SceneTree
## Balance playtest for the Escape (the crossing between the acts): the computer's keepers
## sail the Mary Ann to the rock on their own and the result is printed: her hull, who of
## the seven was lost, what came over the side, and how long it took.
##   godot --headless --path sea-they-are-angry --script res://tools/playtest_escape.gd -- [calm|angry|raging] [helpers|dod|careless|idle] [speed] [runs]
## helpers: all three keepers are the computer's (one takes the wheel from Dod, two keep
## the gunwales). dod: Dod keeps the wheel, all three keepers fight. careless: nobody
## steers (straight on through whatever is in her way), the keepers fight. idle: nobody
## steers and nobody fights.
## Your own Continue save and profile are backed up first and put back afterwards.

var sea := 1
var mode := "helpers"
var speed := 4.0
var runs := 1
var _ended := ""

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
		mode = a[1]
	if a.size() > 2:
		speed = float(a[2])
	if a.size() > 3:
		runs = int(a[3])
	var saved := _backup()
	var run = root.get_node("Run")
	var pl = root.get_node("Players")
	var events = root.get_node("Events")
	events.run_ended.connect(func(reason: String, _n: int) -> void: _ended = reason)
	var results := []
	for r in runs:
		if FileAccess.file_exists("user://run.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
		_ended = ""
		run.next_difficulty = sea
		run.carry = {}
		run.escape_carry = {}
		pl.wanted = 1
		pl.helpers = true
		run.enter_escape = true
		change_scene_to_file("res://scenes/escape.tscn")
		var esc = null
		for i in 900:
			if current_scene != null and current_scene.get("helm") != null and current_scene.player != null:
				esc = current_scene
				break
			await process_frame
		for i in 3:
			await physics_frame
		# The person's keeper is the computer's too.
		var first: Player = esc.player
		first.ai = true
		first.camera = null
		var brain := KeeperAI.new(first, "deck")
		brain.name = "KeeperAI"
		first.add_child(brain)
		if mode == "dod" or mode == "careless" or mode == "idle":
			for k in esc.players:
				var b = k.get_node_or_null("KeeperAI")
				if b != null:
					b.role = "deck"
		if mode == "careless" or mode == "idle":
			esc.helm.autopilot = func(_s: Dictionary) -> float: return 0.0
		if mode == "idle":
			for k in esc.players:
				var b = k.get_node_or_null("KeeperAI")
				if b != null:
					b.set_physics_process(false)
					k.ai_move = Vector2.ZERO
		print("The Escape, %s, %s, %.0f m (run %d)" % [Difficulty.name(), mode, esc.distance, r + 1])
		Engine.time_scale = speed
		var t := 0.0
		var next_line := 30.0
		var count := {"killed": 0}
		var on_kill := func(_e) -> void: count["killed"] = int(count["killed"]) + 1
		events.enemy_killed.connect(on_kill)
		var snap := {}
		while _ended == "" and current_scene == esc and is_instance_valid(esc):
			snap = {"lost": esc.lost_here.duplicate(), "hull": esc.hull, "hull_max": esc.hull_max, "tally": esc.run_tally.duplicate()}
			await physics_frame
			if not is_instance_valid(esc) or current_scene != esc:
				break
			t += esc.get_physics_process_delta_time()
			if t >= next_line:
				next_line += 30.0
				print("  %3ds: %.0f%% · hull %d/%d · aboard %d of the seven · boarders %d · killed %d · at the wheel %s" % [
					roundi(t), esc.progress() * 100.0, esc.hull, esc.hull_max, esc.people_count(),
					get_nodes_in_group("boarders").size(), int(count["killed"]), esc.helm_name()])
		events.enemy_killed.disconnect(on_kill)
		Engine.time_scale = 1.0
		if is_instance_valid(esc) and current_scene == esc:
			snap = {"lost": esc.lost_here.duplicate(), "hull": esc.hull, "hull_max": esc.hull_max, "tally": esc.run_tally.duplicate()}
		var lost: Array = snap.get("lost", [])
		var hull: int = int(snap.get("hull", 0))
		var hull_max: int = int(snap.get("hull_max", 0))
		var tally: Dictionary = snap.get("tally", {})
		var line := ""
		if _ended == "":
			line = "RESULT: in under the light after %ds, hull %d/%d, lost %d (%s); %d came after her, %d got aboard, %d knocked off; hit by %d rocks, %d arms" % [
				roundi(t), hull, hull_max, lost.size(), ", ".join(lost), int(tally.get("ashore", 0)), int(tally.get("aboard", 0)),
				int(tally.get("knocked", 0)) + int(tally.get("overboard", 0)), int(tally.get("hull_rock", 0)), int(tally.get("hull_arm", 0))]
		else:
			line = "RESULT: foundered after %ds (%s), lost %d before she went (%s); hit by %d rocks, %d arms" % [
				roundi(t), _ended, lost.size(), ", ".join(lost), int(tally.get("hull_rock", 0)), int(tally.get("hull_arm", 0))]
		print(line)
		results.append(line)
		# Off to the rock (or the game over card): back to a clean slate for the next run.
		for i in 30:
			await process_frame
	_restore(saved)
	Terrain.chapter = 1
	quit()
