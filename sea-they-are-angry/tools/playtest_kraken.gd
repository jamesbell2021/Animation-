extends SceneTree
## Balance playtest for the last night: the computer's keepers against the kraken, with
## nobody playing (one on the lamp, one at the camp, one with the weapons).
##   godot --headless --path sea-they-are-angry --script res://tools/playtest_kraken.gd -- [calm|angry|raging] [survivors 0-7] [speed]
## The store is set to a moderate arsenal. Your own save and profile are put back after.

var sea := 1
var survivors := 5
var speed := 5.0
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
		survivors = clampi(int(a[1]), 0, 7)
	if a.size() > 2:
		speed = float(a[2])
	var saved := _backup()
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var run = root.get_node("Run")
	var pl = root.get_node("Players")
	var cyc = root.get_node("Cycle")
	var stock = root.get_node("Stock")
	run.next_difficulty = sea
	pl.wanted = 1
	pl.helpers = true
	run.story_next = true
	change_scene_to_file("res://scenes/main.tscn")
	for i in 900:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	var main = current_scene
	var story = main.story
	while run.villagers.size() > survivors:
		story.people[run.villagers.size() - 1].take()
	# The person's keeper is the computer's too: the one with the weapons.
	var first: Player = main.player
	first.ai = true
	first.camera = null
	var brain := KeeperAI.new(first, "light")
	brain.name = "KeeperAI"
	first.add_child(brain)
	root.get_node("Events").run_ended.connect(func(reason: String, _n: int) -> void: _ended = reason)
	# A fair arsenal for the last night.
	for i in run.arms.size():
		run.arms[i] = ["bow", "shotgun"] if i == 0 else ["bow"]
	stock.set_amount("arrows", 36)
	stock.set_amount("shells", 16)
	stock.set_amount("bombs", 6)
	stock.set_amount("bio", 4)
	stock.set_amount("driftwood", 8)
	stock.set_amount("scrap", 6)
	run.night = Rescue.night()
	cyc._enter(cyc.Phase.DUSK)
	print("The last night, %s, %d of the seven on the crag" % [Difficulty.name(), run.villagers.size()])
	Engine.time_scale = speed
	var t := 0.0
	var next := 0.0
	var f0 := Engine.get_physics_frames()
	var blinds := 0
	var was_blind := false
	var fight_from := -1.0
	# When each stage began (game seconds from its rising), and how each went.
	var rose := -1.0
	var stage_at := {}
	var shakes := 0
	var was_grip := false
	while _ended == "" and not story.done and t < 1200.0:
		await physics_frame
		# Game seconds (under load several physics steps pass between two of these).
		t = float(Engine.get_physics_frames() - f0) / 60.0
		var kr: Kraken = story.kraken
		if kr == null:
			continue
		if kr.is_blind() and not was_blind:
			blinds += 1
		was_blind = kr.is_blind()
		if kr.phase == "light" and fight_from < 0.0:
			fight_from = t
		if rose < 0.0:
			rose = t
		if not stage_at.has(kr.stage):
			stage_at[kr.stage] = (t - rose) * speed
		if was_grip and not kr.gripping() and not kr.is_blind() and kr.hp > 0:
			shakes += 1
		was_grip = kr.gripping()
		if kr.reared and not stage_at.has("rear"):
			stage_at["rear"] = (t - rose) * speed
		if t >= next:
			next = t + 20.0
			var who := []
			for k in main.players:
				var b = k.get_node_or_null("KeeperAI")
				who.append("%s:%s hp%d%s" % [b.role if b else "?", b._task if b else "", k.hp, " DOWN" if k.downed else (" LAMP" if k.operating else "")])
			print("t=%3d %-10s kraken %3d%% blinded x%d arms cut %d | lighthouse %d/%d fuel %d | camp standing %d | seven %d | %s" % [
				int(t), kr.phase, roundi(kr.health_ratio() * 100.0), blinds, kr.arms_cut, main.lighthouse.hp, main.lighthouse.max_hp,
				int(main.lighthouse.lamp.fuel), main.camp.targets().size(), run.villagers.size(), " ; ".join(who)])
	Engine.time_scale = 1.0
	var kr2: Kraken = story.kraken
	if is_instance_valid(kr2):
		var end_g := (t - rose) * speed
		var s1: float = stage_at.get(1, -1.0)
		var s2: float = stage_at.get(2, end_g)
		var s3: float = stage_at.get(3, end_g)
		print("STAGES (game s from its rising): camp %.0f-%.0f (%.0f s), crossing %.0f-%.0f (%.0f s), light %.0f-%.0f (%.0f s)%s; whole fight %.0f s" % [
			s1, s2, s2 - s1, s2, s3, s3 - s2, s3, end_g, end_g - s3,
			(", reared at %.0f" % stage_at["rear"]) if stage_at.has("rear") else ", never reared", end_g])
		print("STAGE 1: camp %d of %d left, %d arms driven back | STAGE 2: %d arms cut on the way | STAGE 3: blinded %d, tower grips ended by a shake (or a cut) %d, arms cut in all %d" % [
			kr2.camp_left, kr2.camp_had, kr2.recoils, kr2.cross_cuts, kr2.blinds, shakes, kr2.arms_cut])
	if story.done:
		print("RESULT: it is dead. %.0f real s at the lighthouse (x speed for game time), blinded %d times, %d arms cut, lighthouse %d/%d, %d of the seven left, store %s" % [
			t - fight_from, blinds, kr2.arms_cut if is_instance_valid(kr2) else -1, main.lighthouse.hp, main.lighthouse.max_hp, run.villagers.size(),
			JSON.stringify({"arrows": stock.get_amount("arrows"), "shells": stock.get_amount("shells"), "bombs": stock.get_amount("bombs")})])
	elif _ended != "":
		print("RESULT: lost after %.0f s at the lighthouse: %s (kraken at %d%%, blinded %d times, lighthouse %d/%d, fuel %d)" % [(t - fight_from) * speed, _ended, roundi(kr2.health_ratio() * 100.0) if is_instance_valid(kr2) else -1, blinds, main.lighthouse.hp, main.lighthouse.max_hp, int(main.lighthouse.lamp.fuel)])
	else:
		print("RESULT: no end after %d s (kraken at %d%%, %s)" % [int(t), roundi(kr2.health_ratio() * 100.0) if is_instance_valid(kr2) else -1, kr2.phase if is_instance_valid(kr2) else "?"])
	_restore(saved)
	quit()
