extends SceneTree
## The Escape (docs/ESCAPE.md): the crossing on the Mary Ann between Kirkhaven and the
## rock. Its scene loads with what came off the pier; a person takes the wheel and steers
## her; a helper, then Dod, steers when nobody playing does; a boarder on her side goes
## back in the sea at a boathook blow and at a shotgun blast; one on deck takes one of the
## seven; rocks and arms hurt her hull; her hull at nothing ends the run, and Continue
## begins the crossing again with the same carry; and coming in under the light leads on
## to the rock with the carry as it then stands.
##   godot --headless --path . --script res://tests/slice_escape.gd

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

func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func _scene_with_player(not_this: Node = null) -> Node:
	for i in 1500:
		var cs := current_scene
		if cs != null and cs != not_this and is_instance_valid(cs) and cs.get("player") != null and cs.player != null:
			return cs
		await process_frame
	return null

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	var run = root.get_node("Run")
	var stock = root.get_node("Stock")
	var save = root.get_node("SaveSys")
	var events = root.get_node("Events")
	var strings = load("res://scenes/util/strings.gd")
	events.run_ended.connect(func(reason: String, _n: int) -> void: _ended = reason)
	pl.wanted = 1
	pl.helpers = true
	run.next_difficulty = 1
	# What came off the pier: five of the seven, two lost in the town, a store and arms.
	var carry := {"stock": {"arrows": 17, "shells": 6, "bombs": 2, "scrap": 3, "driftwood": 4}, "arms": [["bow", "shotgun"], ["bow"], ["bow"]],
		"villagers": ["baird", "rennie", "duthie", "buchan", "main"], "lost": ["coull", "geddes"], "difficulty": 1}
	run.carry = carry.duplicate(true)
	run.enter_escape = true
	change_scene_to_file("res://scenes/escape.tscn")
	var esc = await _scene_with_player()
	await _wait(5)
	check(esc != null and Terrain.chapter == 3 and run.chapter == 3 and run.active, "the Escape loads, on the Mary Ann's deck (chapter 3)")
	var ids: Array = []
	for v in esc.villagers:
		ids.append(v.id)
	check(ids == carry["villagers"] and run.villagers == carry["villagers"] and run.lost == carry["lost"], "the five who reached her are aboard, sat in the well (%s)" % ", ".join(ids))
	check(stock.get_amount("arrows") == 17 and stock.get_amount("shells") == 6 and run.arms[0].has("shotgun"), "with the store and the arms that came off the pier")
	check(run.carry.is_empty() and run.escape_carry.get("villagers", []) == carry["villagers"], "the carry is held for the crossing, not handed to the rock yet")
	var sv: Dictionary = save.load_run()
	check(int(sv.get("chapter", 0)) == 3 and sv.get("carry", {}).get("villagers", []) == carry["villagers"], "the save says the Escape, with what came off the pier")
	check(esc.hull == esc.hull_max and esc.hull_max == 100 and esc.miles_left() > 2.9, "her hull whole (%d), the rock %.1f miles off" % [esc.hull, esc.miles_left()])
	var p: Player = esc.player
	var helper: Player = esc.players[1]
	var deckhand: Player = esc.players[2]
	check(EscapeMap.walkable(p.global_position.x, p.global_position.z) and absf(p.global_position.y - EscapeMap.DECK_Y) < 0.3, "the keepers stand on her deck")
	await _wait(30)
	check(absf(p.global_position.y - EscapeMap.DECK_Y) < 0.3 and EscapeMap.walkable(p.global_position.x, p.global_position.z), "and stay on it (y %.2f)" % p.global_position.y)

	# ---- the wheel ----
	# The helper takes the wheel from Dod while nobody playing has it.
	check(await _until(func(): return esc.helm.helmsman == helper, 600), "a helper walks to the wheel and takes it from Dod")
	p.global_position = EscapeMap.HELM_STAND + Vector3(-0.8, 0.05, 0.6)
	await _wait(3)
	check(esc.helm.prompt_for(p).contains("Take the wheel from Hamish"), "at the wheel, a person is offered it (\"%s\")" % esc.helm.prompt_for(p))
	esc.helm.interact(p)
	check(esc.helm.helmsman == p and p.in_menu and not helper.in_menu, "a person takes the wheel, and the helper stands aside")
	await _wait(10)
	check(p.interact_prompt().contains("let go"), "the prompt says how to steer and let go (\"%s\")" % p.interact_prompt())
	var l0: float = esc.lateral
	Input.action_press("move_right")
	await _wait(60)
	Input.action_release("move_right")
	check(esc.lateral > l0 + 1.0, "D steers her to starboard (%.2f to %.2f m across)" % [l0, esc.lateral])
	await _wait(45)
	var l1: float = esc.lateral
	Input.action_press("move_up")
	await _wait(90)
	Input.action_release("move_up")
	check(esc.lateral < l1 - 1.0, "W steers her to port (%.2f to %.2f)" % [l1, esc.lateral])
	check(Geo.flat_dist(p.global_position, EscapeMap.HELM_STAND) < 0.4, "and the keeper stays at the wheel while steering")
	Input.action_press("interact")
	await _wait(2)
	Input.action_release("interact")
	await _wait(2)
	check(esc.helm.helmsman != p and not p.in_menu, "Use lets go of the wheel")
	# The helper has it again; it steers round a rock laid in her way.
	check(await _until(func(): return esc.helm.helmsman == helper, 600), "the helper takes the wheel back")
	esc.rocks.clear()
	for a in esc.arms:
		if is_instance_valid(a):
			a.queue_free()
	esc.arms.clear()
	esc._next_hazard = 1.0e9
	esc._board_t = 1.0e9
	await _wait(60)
	var z0: float = esc.lateral
	var rock: Dictionary = esc.spawn_rock(esc.travelled + 24.0, z0, 1.5)
	check(await _until(func(): return float(rock["x"]) - esc.travelled < 0.0, 900), "the rock comes down on her")
	check(not rock["hit"] and absf(esc.lateral - z0) > EscapeMap.HALF_BEAM + 1.0, "a helper at the wheel steers round it (%.1f m across)" % absf(esc.lateral - z0))
	# With no helper to take it, Dod steers, and sees a rock in time too.
	helper.get_node("KeeperAI").role = "deck"
	esc.helm.release()
	await _wait(10)
	check(esc.helm.helmsman == null and esc.helm_name() == "Dod Wiseman", "with nobody at the wheel, Dod Wiseman has her")
	await _wait(90)
	var z1: float = esc.lateral
	var rock2: Dictionary = esc.spawn_rock(esc.travelled + 24.0, z1, 1.3)
	check(await _until(func(): return float(rock2["x"]) - esc.travelled < 0.0, 900), "another rock comes down on her")
	# Dod sees less far and is slower than a helper: he steers off it, but may not clear it.
	check(absf(esc.lateral - z1) > 1.5, "Dod steers off it too (%.1f m across%s)" % [absf(esc.lateral - z1), ", and clears it" if not rock2["hit"] else ", and catches it a glancing blow"])

	# ---- over the side ----
	# The helpers stand off, so the keeper's own blows are tested.
	for k in [helper, deckhand]:
		k.get_node("KeeperAI").set_physics_process(false)
		k.global_position = Vector3(-4.6, EscapeMap.DECK_Y + 0.05, -1.2 if k == helper else 1.2)
		k.ai_move = Vector2.ZERO
	var b: Boarder = esc.spawn_boarder("drowned", 4)
	check(b.state == &"Swim" and b.clinging() and b.is_in_group("enemies"), "a drowned one swims up alongside")
	check(await _until(func(): return b.state == &"Climb", 300), "and starts up her side")
	await _wait(40)
	var rail: Vector3 = b.rail_point()
	p.global_position = rail + Vector3(0.0, 0.05, 0.0)
	p._attack_cd = 0.0
	await _wait(2)
	var to := b.global_position - p.global_position
	to.y = 0.0
	p._aim = to.normalized()
	var knocked0 := int(esc.run_tally.get("knocked", 0))
	p._attack()
	await _wait(2)
	check(b.hp <= 0 and not b.is_in_group("enemies") and int(esc.run_tally.get("knocked", 0)) == knocked0 + 1, "a boathook blow knocks it back into the sea")
	var b2: Boarder = esc.spawn_boarder("bloated", 11)
	check(await _until(func(): return b2.state == &"Climb", 300), "a bloated one climbs the other side")
	p.global_position = Vector3(EscapeMap.slot_point(11).x - 3.0, EscapeMap.DECK_Y + 0.05, 0.9)
	await _wait(3)
	var to2: Vector3 = b2.global_position - p.global_position
	to2.y = 0.0
	run.barrels = 2
	p.arsenal.select("shotgun")
	p.arsenal.fire_shot(to2.normalized())
	await _wait(2)
	check(b2.hp <= 0 and not b2.is_in_group("enemies") and run.barrels == 2, "a shotgun blast knocks it off too")
	var b3: Boarder = esc.spawn_boarder("drowned", 2)
	b3.state_t = 99.0
	check(await _until(func(): return b3.state == &"Climb", 60), "another comes up her side")
	var arrow := Arrow.new()
	arrow.shooter = p
	arrow.from = b3.global_position + Vector3(-6.0, 0.6, 0.0)
	arrow.dir = Vector3(1.0, -0.05, 0.0).normalized()
	esc.add_child(arrow)
	check(await _until(func(): return b3.hp <= 0, 60), "and an arrow knocks it off")
	# One that gets aboard goes for the seven.
	p.global_position = Vector3(-4.6, EscapeMap.DECK_Y + 0.05, 0.0)
	var b4: Boarder = esc.spawn_boarder("drowned", 9)
	b4.state_t = 99.0
	await _wait(2)
	b4.change_state(&"Climb")
	b4.state_t = 99.0
	check(await _until(func(): return b4.aboard(), 120), "one gets over the gunwale")
	check(await _until(func(): return esc.people_count() < 5 or not b4.aboard(), 900), "it goes for the seven")
	var victim: Villager = null
	for v in esc.villagers:
		if v.state == "lost":
			victim = v
	check(victim != null and run.lost.has(victim.id) and not run.villagers.has(victim.id) and esc.lost_here.size() == 1, "and takes one over the side: %s is lost" % (victim.display_name() if victim != null else "nobody"))
	check(esc.people_count() == 4, "four of Kirkhaven's people are left aboard")

	# ---- her hull ----
	esc.helm.autopilot = func(_s: Dictionary) -> float: return 0.0
	var h0: int = esc.hull
	esc._invuln = 0.0
	var rock3: Dictionary = esc.spawn_rock(esc.travelled + 10.0, esc.lateral, 1.4)
	check(await _until(func(): return rock3["hit"], 300), "a rock in her way, nobody steering round it, strikes her")
	check(esc.hull == h0 - esc.ROCK_DMG[1], "her hull takes the blow (%d to %d)" % [h0, esc.hull])
	var h1: int = esc.hull
	esc._invuln = 0.0
	var arm: SeaArm = esc._spawn_arm(esc.travelled + 30.0)
	check(await _until(func(): return arm.state == &"Rear", 600), "a great arm rears up out of the sea ahead")
	check(await _until(func(): return not is_instance_valid(arm) or arm.state == &"Lie" or arm.state == &"Sink", 600), "and comes down")
	check(esc.hull == h1 - esc.ARM_DMG[1], "across her: the hull takes it (%d to %d)" % [h1, esc.hull])
	var arm2: SeaArm = esc._spawn_arm(esc.travelled + 30.0)
	check(await _until(func(): return arm2.state == &"Rear", 600), "another rears up")
	arm2.take_damage(200, Vector3.ZERO, p)
	await _wait(5)
	check(arm2.state == &"Recoil" or not is_instance_valid(arm2), "hit hard enough while it's up, it goes back under")

	# ---- foundering, and Continue ----
	esc._invuln = 0.0
	esc.hull_hit(999, Vector3(0.0, Terrain.SEA_LEVEL, EscapeMap.HALF_BEAM), "rock")
	await _wait(5)
	check(esc.hull == 0 and not run.active and _ended.contains("Mary Ann"), "her hull at nothing: she founders and the run is lost (\"%s\")" % _ended)
	sv = save.load_run()
	check(int(sv.get("chapter", 0)) == 3 and sv.get("carry", {}).get("villagers", []) == carry["villagers"], "the save still holds the crossing as it began, for Continue")
	check(strings.t("title.continue_escape") == "Continue  (the Escape)", "the title offers to continue the Escape")
	# The title's Continue: main.gd's begin_run, with a title up, goes back to the Escape.
	run.escape_carry = {}
	run.carry = {}
	change_scene_to_file("res://scenes/main.tscn")
	var rock_scene = await _scene_with_player(esc)
	await _wait(3)
	rock_scene.title = CanvasLayer.new()
	rock_scene.add_child(rock_scene.title)
	rock_scene.begin_run(true, 1)
	var esc2 = await _scene_with_player(rock_scene)
	await _wait(5)
	var ids2: Array = []
	for v in esc2.villagers:
		ids2.append(v.id)
	check(esc2 != null and esc2.get("helm") != null and Terrain.chapter == 3 and run.active, "Continue begins the Escape again")
	check(ids2 == carry["villagers"] and run.lost == carry["lost"] and esc2.hull == esc2.hull_max and esc2.travelled < 5.0, "with the same carry: the five aboard, her hull whole, from the pier")
	check(stock.get_amount("arrows") == 17 and stock.get_amount("shells") == 6, "and the store as it came off the pier")

	# ---- the light, and the rock ----
	esc2.skip_pages = true
	esc2._board_t = 0.0
	esc2.travelled = esc2.distance * 0.5
	await _wait(5)
	var b5: Boarder = esc2.spawn_boarder("drowned", 3)
	await _wait(5)
	stock.set_amount("arrows", 9)
	esc2.travelled = esc2.distance * (esc2.LIGHT_AT + 0.001)
	await _wait(5)
	check(not is_instance_valid(b5) or b5.state == &"Flee" or b5.hp <= 0, "as the rock's light reaches her, they fall back")
	esc2.travelled = esc2.distance - 0.5
	var rock_main = await _scene_with_player(esc2)
	await _wait(5)
	check(rock_main != null and rock_main != esc2 and Terrain.chapter == 1 and run.chapter == 1, "she comes in under the light, and the rock is next")
	check(run.active and run.story and run.villagers == carry["villagers"] and run.lost == carry["lost"], "Act Two begins with those who crossed (%d)" % run.villagers.size())
	check(rock_main.story != null and rock_main.story.people.size() == carry["villagers"].size(), "and they are in the old camp")
	check(stock.get_amount("arrows") >= 9 and run.arms[0].has("shotgun") and run.carry.is_empty() and run.escape_carry.is_empty(), "the store and arms came across, and nothing is left to carry")
	var st = load("res://scenes/ui/story_text.gd")
	var before: Array = st.crossing_before(5, ["Sandy Coull"])
	var after: Array = st.crossing_after(["Morag Duthie"])
	check(before.size() == 2 and after.size() == 2 and String(after[0]["text"]).contains("Morag Duthie") and String(after[0]["image"]).ends_with("crossing_3.png"), "the log's crossing pages: two before, two after, naming who was lost on the way")
	print("ALL PASS" if fails == 0 else "%d FAILED" % fails)
	Terrain.chapter = 1
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	quit(1 if fails > 0 else 0)
