extends SceneTree
## Act Two as the story tells it, and its end: the survivors in the camp, what they
## bring, the diary, the kraken (rising, the camp, the lighthouse, blinded by the beam,
## its arms cut back), its death, the clear sky and the end card.
##   godot --headless --path . --script res://tests/slice_kraken.gd

var fails := 0
var _ended := ""

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
	var prof := FileAccess.get_file_as_string("user://profile.json") if FileAccess.file_exists("user://profile.json") else ""
	var pl = root.get_node("Players")
	var run = root.get_node("Run")
	var stock = root.get_node("Stock")
	var cyc = root.get_node("Cycle")
	pl.wanted = 1
	pl.helpers = true
	run.story_next = true
	change_scene_to_file("res://scenes/main.tscn")
	for i in 900:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	await _wait(5)
	var main = current_scene
	cyc.running = false
	main.spawner.process_mode = Node.PROCESS_MODE_DISABLED
	for k in main.players:
		if k.ai:
			k.get_node("KeeperAI").process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("Events").run_ended.connect(func(reason: String, _n: int) -> void: _ended = reason)
	var story = main.story

	# The survivors.
	check(run.story and story != null and story.people.size() == 7 and run.villagers.size() == 7, "the story on the rock: all seven in the camp")
	var one: Villager = story.people[0]
	check(Terrain.in_camp(one.global_position.x, one.global_position.z, 1.0) and one.visible, "by day they are about the camp")
	check(Rescue.night() == Rescue.NIGHTS[Difficulty.level()] - Rescue.STORY_SOONER and Rescue.countdown().contains("it comes in"), "nothing is coming to take them off: %s" % Rescue.countdown())
	cyc._enter(cyc.Phase.DUSK)
	cyc.running = false
	await _wait(3)
	check(not one.visible and one.state == "inside", "at dusk they keep to the huts")
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	var hut: Structure = main.camp.buildings.values()[0]
	hut.take_damage(100000)
	await _wait(3)
	check(run.villagers.size() == 6 and run.lost.size() == 1, "a hut wrecked in the night costs one of them (%s)" % str(run.lost))
	stock.set_amount("shells", 0)
	stock.set_amount("arrows", 0)
	main.player.hp = 30
	cyc._enter(cyc.Phase.DAWN)
	cyc.running = false
	await _wait(3)
	check(stock.get_amount("shells") == (2 if run.villagers.has("geddes") else 0) and stock.get_amount("arrows") == (4 if run.villagers.has("main") else 0), "at dawn the living bring what they can")
	check(main.player.hp == main.player.max_hp or not run.villagers.has("buchan"), "and the nurse sees to the keepers")
	check(one.state == "lost" or one.visible, "and they come out again")
	check(not run.diary_read, "the diary's last pages are not read yet")
	run.night = Rescue.night() - 2
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	cyc._enter(cyc.Phase.DAWN)
	cyc.running = false
	await _wait(3)
	check(run.diary_read and run.night == Rescue.night() - 1, "with a few nights left, they are")

	# The last night.
	run.night = Rescue.night()
	cyc._enter(cyc.Phase.DUSK)
	cyc.running = false
	await _wait(3)
	var living: Array = story._living()
	var on_crag := 0
	for v in living:
		if v.fighting and Vector2(v.global_position.x, v.global_position.z).length() < 4.0 and v.global_position.y > Terrain.CRAG_TOP - 1.0:
			on_crag += 1
	check(on_crag == living.size() and living.size() == 6, "the last dusk: the survivors stand with the keepers on the crag")
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	check(story.kraken == null, "it has not come yet")
	story.raise_kraken()
	var kr: Kraken = story.kraken
	check(kr != null and kr.phase == "rise" and kr.hp == kr.max_hp and kr.max_hp >= Kraken.BASE_HP * 0.5, "it rises off the east of the holm (%d)" % kr.max_hp)
	check(kr.fighters.size() == 6 and kr.eye_points().is_empty(), "the survivors are its enemies too; its eyes are still under")
	Engine.time_scale = 6.0
	for i in 3000:
		await physics_frame
		if kr.phase == "camp_east":
			break
	check(kr.phase == "camp_east" and kr.body.risen > 0.9, "and turns on the camp")
	var standing: int = main.camp.targets().size() + main.camp.wire.filter(func(w): return not w.is_destroyed()).size()
	for i in 3000:
		await physics_frame
		var now: int = main.camp.targets().size() + main.camp.wire.filter(func(w): return not w.is_destroyed()).size()
		if now < standing - 2 or kr.phase != "camp_east":
			break
	var after: int = main.camp.targets().size() + main.camp.wire.filter(func(w): return not w.is_destroyed()).size()
	check(after < standing, "its arms bring the camp down (%d standing, was %d)" % [after, standing])
	kr._enter("cross")
	for i in 4000:
		await physics_frame
		if kr.phase == "light":
			break
	Engine.time_scale = 1.0
	check(kr.phase == "light" and Geo.flat_dist(kr.global_position, Vector3(Kraken.LIGHT_AT.x, 0.0, Kraken.LIGHT_AT.y)) < 1.5, "then it comes round to the east beach, for the lighthouse")
	await _wait(10)
	var eyes: Array = kr.eye_points()
	check(eyes.size() == 2, "its eyes are up")

	# The lamp in its eyes.
	var lamp: Lamp = main.lighthouse.lamp
	lamp._set_state(Lamp.State.BURNING)
	lamp.mode = Lamp.Mode.FOCUSED
	lamp._apply_mode()
	lamp.showcase = false
	var d: Vector3 = (eyes[0] + eyes[1]) * 0.5 - lamp.global_position
	var dep := rad_to_deg(atan2(lamp.global_position.y - (eyes[0] as Vector3).y, Vector2(d.x, d.z).length()))
	lamp.operator = null
	var hp0 := kr.hp
	for i in 240:
		lamp.yaw = atan2(-d.x, -d.z)
		lamp._pivot.rotation.y = lamp.yaw
		lamp._sweep(1.0 / 60.0)
		await physics_frame
		if kr.is_blind():
			break
	check(kr.is_blind(), "the focused beam held in its eyes blinds it (eyes %.0f degrees below the lamp, %.0f m off)" % [dep, Vector2(d.x, d.z).length()])
	kr.body.arm_slam(0, main.player.global_position)
	var struck0 := kr.hp
	kr.struck(-1, 100, "shot", Vector3.FORWARD, null, kr.global_position)
	check(struck0 - kr.hp == roundi(100 * Kraken.BLIND_MULT), "blind, a hit counts for more (%d)" % (struck0 - kr.hp))
	kr.blinded = 0.01
	await _wait(5)
	check(not kr.is_blind() and kr._rest > 0.0, "it gets its sight back, and keeps its head turned a while")
	struck0 = kr.hp
	kr.struck(-1, 100, "shot", Vector3.FORWARD, null, kr.global_position)
	check(struck0 - kr.hp == 100, "sighted, a hit is a hit")
	struck0 = kr.hp
	kr.struck(-1, 40, "bomb", Vector3.FORWARD, null, kr.global_position)
	kr.struck(-1, 40, "bomb", Vector3.FORWARD, null, kr.global_position)
	check(struck0 - kr.hp == 40, "one blast across its head counts once")
	struck0 = kr.hp
	kr.struck(2, Kraken.ARM_HP, "hook", Vector3.FORWARD, null, kr.global_position)
	check(kr.arms_cut == 1 and not kr.body.arm_out(2) and struck0 - kr.hp == Kraken.SEVER_DAMAGE, "an arm cut back costs it")
	var up := 0
	for part in kr._head:
		if part.global_position.y > -10.0 and Arsenal._live(part):
			up += 1
	check(up == Kraken.HEAD_SPOTS, "the keepers' weapons can find its head (%d places)" % up)

	# A slam.
	var lh0: int = main.lighthouse.hp
	kr._on_slammed(1, main.lighthouse.global_position + Vector3(1.8, 0.0, 0.0))
	check(main.lighthouse.hp == lh0 - Kraken.SLAM_LIGHTHOUSE, "an arm down on the tower hurts it")

	# Its death.
	kr._hurt(kr.hp)
	check(kr.phase == "dying", "its strength gone, it dies")
	Engine.time_scale = 6.0
	for i in 4000:
		await physics_frame
		if story.done:
			break
	Engine.time_scale = 1.0
	check(story.done and not run.active and _ended == "" and root.get_node("SaveSys").chapter_done(1), "the story is finished")
	check(main._lighting[0]["bg"] == StoryRock.CLEAR_DAY["bg"], "and the sky is clearing blue")
	story._end_t = 0.05
	await _wait(10)
	check(main.get_node_or_null("StoryEnd") != null, "the end card comes up")
	if prof != "":
		FileAccess.open("user://profile.json", FileAccess.WRITE).store_string(prof)
	print("ALL PASS" if fails == 0 else "FAILED: %d" % fails)
	quit(1 if fails > 0 else 0)
