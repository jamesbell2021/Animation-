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
	check(Rescue.night() > 2 and Rescue.countdown().contains("it comes in"), "nothing is coming to take them off: %s" % Rescue.countdown())
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
	var stages: Array = []
	kr.stage_changed.connect(func(n: int) -> void: stages.append(n))
	Engine.time_scale = 6.0
	for i in 3000:
		await physics_frame
		if kr.phase == "camp_east":
			break
	Engine.time_scale = 1.0
	check(kr.phase == "camp_east" and kr.body.risen > 0.9 and kr.stage == 1 and stages == [1], "and turns on the camp: stage 1, it takes the camp")
	check(kr.camp_had >= 3, "what is left of the camp stands when it comes (%d)" % kr.camp_had)

	# Stage 1: fire drives an arm back over the wire.
	var hut0: Node3D = main.camp.buildings["mess"]
	var fa := -1
	for i in 8:
		if kr.body.arm_out(i) and not kr.body.arm_busy(i):
			fa = i
			break
	kr.body.arm_slam(fa, hut0.global_position, 3.0)
	await _wait(20)
	var hp_f := kr.hp
	var rec0: int = kr.recoils
	kr.struck(fa, 20, "flame", Vector3.FORWARD, null, hut0.global_position)
	check(kr.body.arm_recoiling(fa) and not kr.body.arm_busy(fa) and kr.recoils == rec0 + 1 and kr._arm_shy[fa] > 0.0, "flame on a camp arm makes it recoil (and calls its slam off)")
	await _wait(60)
	check(kr.hp < hp_f - 20 and kr._burning > 0.0, "and it burns (%d -> %d)" % [hp_f, kr.hp])
	check(kr._free_arm(hut0.global_position) != fa, "a burnt arm won't come again for a while")
	var fb := -1
	for i in 8:
		if i != fa and kr.body.arm_out(i) and not kr.body.arm_recoiling(i):
			fb = i
			break
	kr.burn(3.0, fb)
	check(kr.body.arm_recoiling(fb), "a petrol bomb's fire on an arm does it too")
	# A searchlight held on an arm.
	var fc := -1
	for i in 8:
		if kr.body.arm_out(i) and not kr.body.arm_recoiling(i):
			fc = i
			break
	check(not kr._tips[fc].light_probe_points().is_empty(), "over the wire a light can find its arms")
	for i in 12:
		kr._tips[fc].in_light(Lamp.Mode.WIDE, 1.0 / 60.0)
		await physics_frame
	check(not kr.body.arm_recoiling(fc), "a light just passing over an arm does nothing")
	for i in 60:
		kr._tips[fc].in_light(Lamp.Mode.WIDE, 1.0 / 60.0)
		await physics_frame
		if kr.body.arm_recoiling(fc):
			break
	check(kr.body.arm_recoiling(fc), "a searchlight held on an arm makes it pull back")
	# Arrows sting.
	var fd := -1
	for i in 8:
		if kr.body.arm_out(i) and not kr.body.arm_recoiling(i):
			fd = i
			break
	kr.struck(fd, 22, "arrow", Vector3.FORWARD, null, hut0.global_position)
	var stung_once: bool = kr.body.arm_recoiling(fd)
	kr.struck(fd, 22, "arrow", Vector3.FORWARD, null, hut0.global_position)
	check(not stung_once and kr.body.arm_recoiling(fd), "two good arrows sting an arm back")

	# It brings the camp down, then works round the north.
	Engine.time_scale = 6.0
	var standing: int = main.camp.targets().size() + main.camp.wire.filter(func(w): return not w.is_destroyed()).size()
	for i in 3000:
		await physics_frame
		var now: int = main.camp.targets().size() + main.camp.wire.filter(func(w): return not w.is_destroyed()).size()
		if now < standing - 2 or kr.phase != "camp_east":
			break
	var after: int = main.camp.targets().size() + main.camp.wire.filter(func(w): return not w.is_destroyed()).size()
	check(after < standing, "its arms bring the camp down (%d standing, was %d)" % [after, standing])
	if kr.phase == "camp_east":
		kr._phase_t = Kraken.CAMP_TIME + 1.0
	for i in 600:
		await physics_frame
		if kr.phase == "camp_north" and kr._way.is_empty():
			break
	check(kr.phase == "camp_north" and kr.stage == 1, "then works round the north of the holm, still at the camp")
	if kr.phase == "camp_north":
		kr._phase_t = Kraken.CAMP_TIME * 2.0
	for i in 60:
		await physics_frame
		if kr.phase == "cross":
			break
	Engine.time_scale = 1.0
	check(kr.phase == "cross" and kr.stage == 2 and stages == [1, 2] and kr.camp_left >= 0 and kr.camp_left <= kr.camp_had, "stage 2: it comes round for the light (the camp: %d of %d left)" % [kr.camp_left, kr.camp_had])

	# Stage 2: an arm laid on the rock shows its wound, and cutting it slows it.
	await _wait(30)
	var lh: Vector3 = main.lighthouse.global_position
	var land := Vector3.INF
	var dir: Vector3 = (lh - kr.global_position)
	dir.y = 0.0
	for k in 40:
		var q: Vector3 = kr.global_position + dir.normalized() * (6.0 + float(k) * 0.5)
		if Terrain.height_at(q.x, q.z) > Terrain.SEA_LEVEL + 0.6:
			land = q + dir.normalized() * 2.5
			break
	land.y = Terrain.height_at(land.x, land.z)
	var ca := kr._free_arm(land)
	kr.body.arm_slam(ca, land, 0.4, Kraken.LIE_CROSS)
	var lay := false
	for i in 240:
		await physics_frame
		if kr._tips[ca].global_position.y > -10.0 and kr.body._arms[ca].mark.visible:
			lay = true
			break
	check(lay and kr._told_cut, "an arm laid on the rock in the crossing can be cut, and shows a pale wound")
	await _wait(60)
	check(kr.body.arm_busy(ca) and kr._tips[ca].global_position.y > -10.0, "and lies there long enough to cut (%.1f s)" % Kraken.LIE_CROSS)
	var sp0: float = kr.cross_speed()
	var hp_c := kr.hp
	kr.struck(ca, Kraken.ARM_HP, "hook", Vector3.FORWARD, null, land)
	check(kr.cross_cuts == 1 and kr.cross_speed() == 0.0 and hp_c - kr.hp == Kraken.SEVER_DAMAGE_CROSS, "cut in the crossing: it stops, and it costs it dear (%d)" % (hp_c - kr.hp))
	kr._stall = 0.0
	check(kr.cross_speed() < sp0 - 0.01, "and it is slower after (%.2f, was %.2f m/s)" % [kr.cross_speed(), sp0])
	check(kr._arm_back[ca] > Kraken.ARM_REGROW, "and the arm does not grow again on the way")
	Engine.time_scale = 6.0
	for i in 6000:
		await physics_frame
		if kr.phase == "light":
			break
	Engine.time_scale = 1.0
	check(kr.phase == "light" and kr.stage == 3 and stages == [1, 2, 3] and Geo.flat_dist(kr.global_position, Vector3(Kraken.LIGHT_AT.x, 0.0, Kraken.LIGHT_AT.y)) < 1.5, "stage 3: then it comes round to the east beach, for the lighthouse")
	check(kr._arm_back[ca] <= Kraken.ARM_REGROW and kr._tips[0].light_probe_points().is_empty(), "the arm cut on the way grows back now; the lamp is for its eyes")
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
	var first_blind: float = kr.blind_length() / Kraken.BLIND_LEARN
	check(kr.blinds == 1 and absf(first_blind - Kraken.BLIND_TIME) < 0.01 and kr.blinded <= Kraken.BLIND_TIME, "the first blinding holds it %.1f s" % first_blind)
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
	var cut0: int = kr.arms_cut
	var sa := 2 if kr.body.arm_out(2) else 3
	kr.struck(sa, Kraken.ARM_HP, "hook", Vector3.FORWARD, null, kr.global_position)
	check(kr.arms_cut == cut0 + 1 and not kr.body.arm_out(sa) and struck0 - kr.hp == Kraken.SEVER_DAMAGE, "at the light, an arm cut back costs it")
	var up := 0
	for part in kr._head:
		if part.global_position.y > -10.0 and Arsenal._live(part):
			up += 1
	check(up == Kraken.HEAD_SPOTS, "the keepers' weapons can find its head (%d places)" % up)

	# A slam.
	var lh0: int = main.lighthouse.hp
	kr._on_slammed(1, main.lighthouse.global_position + Vector3(1.8, 0.0, 0.0))
	check(main.lighthouse.hp == lh0 - Kraken.SLAM_LIGHTHOUSE, "an arm down on the tower hurts it")

	# It learns: each blinding is shorter.
	var lens: Array = []
	for n in 6:
		kr._rest = 0.0
		kr._blind()
		lens.append(kr.blinded)
		kr.blinded = 0.01
		await _wait(2)
	var shorter := true
	for n in range(1, lens.size()):
		if lens[n] > lens[n - 1] + 0.001:
			shorter = false
	check(shorter and lens[1] < lens[0] and lens[lens.size() - 1] >= Kraken.BLIND_MIN, "each blinding is shorter than the last, never under %.1f s (%s)" % [Kraken.BLIND_MIN, ", ".join(lens.map(func(x): return "%.1f" % x))])

	# Between blindings it reaches up the tower and shakes the keeper out of the lamp room.
	kr._rest = 0.0
	var me: Player = main.player
	me.global_position = KeeperNav.door_point()
	await _wait(3)
	if not me.operating:
		me._toggle_operate()
	await _wait(5)
	kr._grip_t = Kraken.GRIP_EVERY
	await _wait(3)
	check(kr.gripping(), "sighted a while, it gets an arm up the tower")
	kr._blind()
	check(not kr.gripping(), "blinding it lets go of the tower")
	kr.blinded = 0.01
	await _wait(3)
	kr._rest = 0.0
	kr._grip_t = Kraken.GRIP_EVERY
	await _wait(3)
	var lh1: int = main.lighthouse.hp
	var was_on: bool = me.operating
	kr._grip_left = 0.01
	await _wait(3)
	check(was_on and not me.operating and main.lighthouse.hp == lh1 - Kraken.GRIP_DAMAGE and not kr.gripping(), "left gripping, it shakes the tower: the lamp hurt, the keeper thrown out")

	# The last gasp: low, it rears up out of the sea.
	check(not kr.reared and not kr.is_rearing(), "not reared yet (%d%%)" % roundi(kr.health_ratio() * 100.0))
	kr.hp = roundi(float(kr.max_hp) * Kraken.REAR_AT) - 1
	await _wait(3)
	check(kr.reared and kr.is_rearing(), "at %d%% it rears up" % roundi(Kraken.REAR_AT * 100.0))
	await _wait(60)
	check(kr.body.is_reared(), "its whole body up out of the sea")
	struck0 = kr.hp
	kr.struck(-1, 100, "shot", Vector3.FORWARD, null, kr.global_position)
	check(struck0 - kr.hp == roundi(100 * Kraken.REAR_MULT), "reared, every hit counts for more (%d)" % (struck0 - kr.hp))
	var fa2 := kr._free_arm(main.player.global_position)
	kr.body.arm_slam(maxi(fa2, 0), main.player.global_position)
	check(not kr.body.arm_busy(maxi(fa2, 0)), "reared, it does not strike")
	kr.lit(Lamp.Mode.FOCUSED, 5.0)
	check(not kr.is_blind(), "nor can it be blinded up there")

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
