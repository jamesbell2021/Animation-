extends SceneTree
## The story's rock made to differ from day to day (RockDays): a day's event and its
## stores, a special night's table and its announcement, one of the seven's requests and
## its reward, a grief line for one lost, the story's rock 6/7/8 nights long with the
## kraken on the last, the dawn rating line, and an unlock saved for finishing on an
## angry sea (and a raging one).
##   godot --headless --path . --script res://tests/slice_variety.gd

var fails := 0
var said: Array = []

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _wait(frames: int) -> void:
	for i in frames:
		await physics_frame

func _secs(s: float) -> void:
	await create_timer(s, false).timeout

func _heard(part: String) -> bool:
	for t in said:
		if String(t).contains(part):
			return true
	return false

func _go() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var prof := FileAccess.get_file_as_string("user://profile.json") if FileAccess.file_exists("user://profile.json") else ""
	var pl = root.get_node("Players")
	var run = root.get_node("Run")
	var stock = root.get_node("Stock")
	var cyc = root.get_node("Cycle")
	var save = root.get_node("SaveSys")
	# A profile with nothing unlocked, so Hard Light is off for this run.
	var f := FileAccess.open("user://profile.json", FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	pl.wanted = 1
	pl.helpers = true
	run.next_difficulty = 1
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
	root.get_node("Events").message.connect(func(t: String) -> void: said.append(t))
	var days = main.days
	var story = main.story

	# The length of the story's rock.
	var lengths := []
	for lvl in 3:
		run.difficulty = lvl
		lengths.append(Rescue.night())
	run.difficulty = 1
	check(lengths == [6, 7, 8], "the story's rock is 6, 7 or 8 nights by the sea (%s)" % str(lengths))
	run.story = false
	var boat := Rescue.night()
	run.story = true
	check(boat == 10, "the rock alone still waits 10 nights for the boat on an angry sea (%d)" % boat)

	# The first day's event.
	check(days != null and run.story and main.spawner.night_kind.is_valid(), "the story's rock has its days (RockDays) and shapes the spawner")
	check(RockDays.FIRST_DAY.has(days.today) and days.today_line != "", "day 1 brings something gentle: %s" % days.today)
	var kinds := {}
	var repeats := 0
	for n in range(1, 30):
		kinds[RockDays.event_for(n)] = true
		if n > 1 and RockDays.event_for(n) == RockDays.event_for(n - 1):
			repeats += 1
	check(kinds.size() >= 6 and repeats == 0, "the days' events vary (%d kinds over 29 days) and never repeat back to back" % kinds.size())

	# A wreck: its stores can be had.
	days._clear()
	var line: String = days.start_event("wreck")
	check(line.contains("wreck") and days.marker_at() != Vector3.INF, "a wreck comes ashore, with a marker over it: " + line)
	var pts: Array = days._spawned.filter(func(n) -> bool: return n is ScavengePoint)
	check(pts.size() == 3, "three lots of stores on the shingle (%d)" % pts.size())
	var shells_before: int = stock.get_amount("shells")
	var diesel_before: int = stock.get_amount("diesel")
	for sp in pts:
		sp.interact(main.player)
	await _wait(3)
	check(stock.get_amount("shells") == shells_before + 3 and stock.get_amount("diesel") == diesel_before + 1, "and they come into the store (cartridges +3, diesel +1)")
	await _wait(2)
	check(days.today_done or days.today != "wreck", "fetched")
	days.today = "wreck"
	days.today_done = false
	days._process(0.016)
	check(days.today_done and days.marker_at() == Vector3.INF, "the event is done and its marker goes")

	# A special night: the third is a big one.
	var big: String = RockDays.night_kind(3)
	check(big == "big" and RockDays.night_kind(1) == "" and RockDays.night_kind(Rescue.night()) == "", "night 3 is a big night; the first and the last (the kraken's) are plain")
	var specials := 0
	for n in range(2, Rescue.night()):
		if RockDays.night_kind(n) != "":
			specials += 1
	check(specials >= 2, "%d special nights on a %d-night rock" % [specials, Rescue.night()])
	var shaped: Array = main.spawner.night_table(3)
	var kind_fn: Callable = main.spawner.night_kind
	main.spawner.night_kind = Callable()
	var plain: Array = main.spawner.night_table(3)
	main.spawner.night_kind = kind_fn
	var sum := func(rows: Array) -> int:
		var t := 0
		for r in rows:
			t += int(r["count"])
		return t
	check(sum.call(shaped) > sum.call(plain) and shaped.size() > plain.size(), "a big night's table is bigger (%d in %d groups, plain %d in %d)" % [sum.call(shaped), shaped.size(), sum.call(plain), plain.size()])
	var squid: Array = main.spawner.special_rows(plain, "squid")
	check(squid.filter(func(r) -> bool: return r["kind"] == "B").is_empty() and squid.filter(func(r) -> bool: return r["kind"] == "S").size() > plain.filter(func(r) -> bool: return r["kind"] == "S").size(), "a squid night: the Bloated come as Squid")
	var fog: Array = main.spawner.special_rows(plain, "fog")
	check(sum.call(fog) < sum.call(plain) and fog.filter(func(r) -> bool: return r.get("every", false)).size() > 0, "a fog night: fewer, from every beach")
	var smo: Array = main.spawner.special_rows(plain, "smotherer")
	check(smo.filter(func(r) -> bool: return r["kind"] == "M").size() >= 3, "a smotherer night: several climbers")
	run.night = 3
	said.clear()
	cyc._enter(cyc.Phase.DAY)
	cyc.running = false
	Engine.time_scale = 4.0
	await _secs(RockDays.SAY_SIGN + 0.5)
	check(days.tonight == "big" and _heard(RockDays.SIGNS["big"]), "the morning gives its sign: " + RockDays.SIGNS["big"])
	said.clear()
	cyc._enter(cyc.Phase.DUSK)
	cyc.running = false
	await _secs(2.0)
	Engine.time_scale = 1.0
	check(_heard(RockDays.DUSK["big"]), "and dusk says it in one line: " + RockDays.DUSK["big"])
	# A storm night is a storm.
	var stormy := -1
	for s in 400:
		run.weather_seed = s
		for n in range(2, 6):
			if RockDays.night_kind(n) == "storm":
				stormy = n
		if stormy > 0:
			break
	run.night = stormy
	cyc._enter(cyc.Phase.DAY)
	cyc.running = false
	check(stormy > 0 and Weather.tonight() == Weather.Kind.STORM, "a storm night's weather is a storm (night %d)" % stormy)

	# A request: Isla Rennie's rack (by day, the seven out of the huts since dawn).
	run.night = 2
	cyc._enter(cyc.Phase.DAWN)
	cyc._enter(cyc.Phase.DAY)
	cyc.running = false
	days.request = ""
	check(days.open_request("rennie") and days.request == "rennie", "Isla Rennie asks for something")
	var rennie: Villager = null
	for v in story.people:
		if v.id == "rennie":
			rennie = v
	stock.set_amount("driftwood", 1)
	check(rennie.interact_prompt().contains("wants") and not rennie.interact(main.player), "without the driftwood, she waits: " + rennie.interact_prompt())
	check(days.request_line().contains("Isla Rennie"), "the note says what she asked: " + days.request_line())
	stock.set_amount("driftwood", 4)
	check(rennie.interact_prompt().begins_with("[E] Give"), "with it: " + rennie.interact_prompt())
	check(rennie.interact(main.player) and run.favours.has("rennie") and stock.get_amount("driftwood") == 1, "[E] hands it over and the favour is done")
	stock.set_amount("scrap", 0)
	Villagers.dawn_gifts()
	check(stock.get_amount("scrap") == 2, "her reward: two scrap a dawn, not one")
	# Tam Geddes's stove.
	await _wait(2)
	days.request = ""
	check(days.open_request("geddes"), "Tam Geddes asks for the quarters' stove lit")
	var shells: int = stock.get_amount("shells")
	for n in main.get_tree().get_nodes_in_group("heat"):
		if n is HutStove:
			n.burn = 60.0
	await _wait(3)
	check(days.request == "" and run.favours.has("geddes") and stock.get_amount("shells") == shells + Villagers.GEDDES_BOX, "lit: his box of cartridges (+%d)" % Villagers.GEDDES_BOX)
	# Mr Baird's bible: fetched and brought.
	days.request = ""
	check(days.open_request("baird") and days.keepsake != null, "Mr Baird's bible is on a beach")
	var ang = root.get_node("Anger")
	var anger: int = ang.value
	days.keepsake.interact(main.player)
	await _wait(2)
	var baird: Villager = null
	for v in story.people:
		if v.id == "baird":
			baird = v
	check(days.carrying and baird.interact_prompt().contains("bible"), "picked up; to him: " + baird.interact_prompt())
	check(baird.interact(main.player) and run.favours.has("baird"), "and brought: the favour done (the sea's anger %d to %d)" % [anger, ang.value])
	check(days.next_asker() != "" and not ["rennie", "geddes", "baird"].has(days.next_asker()), "the next to ask is someone not yet favoured: %s" % days.next_asker())

	# A loss, and grief at the dawn after. And the dawn's rating.
	cyc._enter(cyc.Phase.DUSK)
	cyc.running = false
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	await _wait(3)
	var gone: Villager = null
	for v in story.people:
		if v.id == "duthie":
			gone = v
	gone.take()
	await _wait(2)
	cyc._enter(cyc.Phase.DAWN)
	cyc.running = false
	await _wait(3)
	var report: String = main.hud._report_label.text
	var grieved := false
	for id in Villagers.GRIEF:
		if report.contains(String(Villagers.GRIEF[id]) % "Morag Duthie"):
			grieved = true
	check(report.contains("Lost in the night: Morag Duthie") and grieved, "the dawn after: a grief line for Morag Duthie")
	check(report.contains(NightRating.FULL) or report.contains(NightRating.EMPTY), "the dawn's log rates the night")
	var rated := ""
	for l in report.split("\n"):
		if l.contains(NightRating.EMPTY) or l.contains(NightRating.FULL):
			rated = l
	check(rated.contains("Lost: Morag Duthie") and run.star_nights >= 1, "one line: " + rated)
	var perfect := {"uptime": 1.0, "lost": [], "downs": 0, "reached": 0, "wrecked": 0, "hurt": 0.0}
	check(NightRating.stars(perfect) == 3 and NightRating.line(perfect).begins_with("The light never went out. Not a soul lost."), "a clean night: " + NightRating.line(perfect))
	perfect["hard"] = true
	check(NightRating.stars(perfect) == 4, "Hard Light: a fourth star for a light that never went out")
	check(NightRating.total_line().contains("of"), "the run's total for the end cards: " + NightRating.total_line())

	# The kraken still comes, on the last night.
	run.night = Rescue.night()
	check(RockDays.night_kind(run.night) == "", "the last night is the kraken's alone")
	cyc._enter(cyc.Phase.DUSK)
	cyc.running = false
	cyc._enter(cyc.Phase.NIGHT)
	cyc.running = false
	cyc.time_left = cyc._duration * (1.0 - StoryRock.KRAKEN_AT - 0.02)
	await _wait(5)
	check(story.kraken != null, "night %d: the kraken rises" % run.night)

	# An unlock for finishing on an angry sea, and more on a raging one.
	run.story = true
	run.difficulty = 0
	save.finish_chapter(1)
	check(save.load_profile().get("unlocks", []).is_empty(), "the story finished on a calm sea unlocks nothing")
	run.difficulty = 1
	save.finish_chapter(1)
	check(save.unlocked("coat") and not save.unlocked("hard_light"), "on an angry sea: the keeper's oilskin")
	check(StoryRock.unlock_line().contains("oilskin"), "the end card says so: " + StoryRock.unlock_line())
	run.difficulty = 2
	save.finish_chapter(1)
	check(save.unlocked("hard_light") and save.unlocked_names().size() == 2, "on a raging sea: Hard Light too")
	save.set_choice("hard_light", true)
	run.next_difficulty = 1
	run.start_new()
	check(run.hard_light, "chosen, a new run is played with Hard Light")
	run.story = false
	run.start_new()

	# Put the player's profile back.
	if prof != "":
		var w := FileAccess.open("user://profile.json", FileAccess.WRITE)
		w.store_string(prof)
		w.close()
	elif FileAccess.file_exists("user://profile.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.json"))
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	print("RESULT: %s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
