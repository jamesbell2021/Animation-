extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_holm.gd
# The holm and its camp, the rope bridge, the camera's split screen, and the helper keepers.

var fails := 0

func check(c: bool, w: String) -> void:
	print(("PASS  " if c else "FAIL  ") + w)
	if not c:
		fails += 1

func _init() -> void:
	_go.call_deferred()

func _load(humans: int, helpers: bool):
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	var pl = root.get_node("Players")
	pl.wanted = humans
	pl.helpers = helpers
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null and current_scene.player != null:
			break
		await process_frame
	for i in 3:
		await physics_frame
	return current_scene

func _go() -> void:
	# ---- the ground ----
	var c := Terrain.CAMP_C
	check(Terrain.on_holm(c.x, c.y) and absf(Terrain.height_at(c.x, c.y) - Terrain.HOLM_HEIGHT) < 0.05, "the camp stands on the holm's flat plateau")
	check(Terrain.walkable(c.x, c.y) and Terrain.in_camp(c.x, c.y), "keepers can walk in the camp")
	check(not Terrain.on_holm(0.0, 6.0) and Terrain.height_at(25.0, 3.0 + 9.0) < Terrain.SEA_LEVEL, "the main island is the main island, with sea between")
	var ends := Terrain.bridge_ends()
	var a: Vector3 = ends[0]
	var b: Vector3 = ends[1]
	check(not Terrain.on_holm(a.x, a.z) and Terrain.on_holm(b.x, b.z), "the bridge runs from the main island to the holm")
	check(a.distance_to(b) > 14.0 and a.distance_to(b) < 24.0, "the bridge spans %.1f m of gully" % a.distance_to(b))
	var mid := a.lerp(b, 0.5)
	check(Terrain.height_at(mid.x, mid.z) < Terrain.SEA_LEVEL and Terrain.walkable(mid.x, mid.z), "under the bridge is sea, but its deck is walkable")
	var off := mid + Vector3(0.0, 0.0, 3.0)
	check(not Terrain.walkable(off.x, off.z), "beside the bridge is not")

	# ---- one keeper, the bridge ----
	var main = await _load(1, false)
	var p = main.player
	p.camera = null
	check(main.camp != null and main.camp.towers.size() == 4 and main.camp.huts.size() == 2, "the camp has its four towers and two huts")
	check(main.camp.searchlights.size() == 4 and main.camp.greenhouse != null and main.camp.beds.size() == 3, "searchlights, greenhouse and beds")
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	p.global_position = a - along * 1.5 + Vector3(0.0, 0.2, 0.0)
	var low := INF
	var max_sway := 0.0
	var dir2 := Vector2(along.x, along.z)
	for i in 420:
		Input.action_press("move_right" if dir2.x > 0.0 else "move_left")
		await physics_frame
		low = minf(low, p.global_position.y)
		max_sway = maxf(max_sway, absf(main.bridge.sway()))
		if Terrain.in_camp(p.global_position.x, p.global_position.z, 1.0):
			break
	Input.action_release("move_right")
	Input.action_release("move_left")
	check(Terrain.in_camp(p.global_position.x, p.global_position.z), "a keeper walks across the bridge and in at the camp gate (at %s)" % p.global_position)
	check(low < a.y - 0.3, "the deck sags under them (down to %.2f)" % low)
	check(max_sway > 0.03, "their steps set it swaying (%.2f m)" % max_sway)
	# And back again.
	for i in 600:
		Input.action_press("move_left" if dir2.x > 0.0 else "move_right")
		await physics_frame
		if not Terrain.on_holm(p.global_position.x, p.global_position.z) and not Terrain.on_bridge(p.global_position.x, p.global_position.z):
			break
	Input.action_release("move_right")
	Input.action_release("move_left")
	check(not Terrain.on_holm(p.global_position.x, p.global_position.z) and p.global_position.y > Terrain.PLATEAU_HEIGHT - 0.5, "and back to the main island")

	# ---- the camp's power: the generator, the searchlights, a keeper up a tower ----
	var Cyc = root.get_node("Cycle")
	var Stk = root.get_node("Stock")
	var gen: Generator = main.camp.generator
	check(gen != null and not gen.running, "the generator stands idle by day")
	Cyc._enter(Cyc.Phase.DUSK)
	Cyc.running = false
	for i in 10:
		await physics_frame
	var lit := 0
	for sl in main.camp.searchlights:
		if sl.is_lit():
			lit += 1
	check(gen.running and lit == 4, "at dusk it starts and all four searchlights come on (%d)" % lit)
	check(main.camp._hut_lights.size() == 4 and main.camp._hut_lights[0].visible, "the huts' windows light up")
	var f0 := gen.fuel
	for i in 120:
		await physics_frame
	check(gen.fuel < f0 - 0.6, "it burns diesel running them (%.2f -> %.2f)" % [f0, gen.fuel])
	# Up the north-east tower's ladder and onto its light.
	var sl: Searchlight = main.camp.searchlights[1]
	var tower := sl.get_parent() as Node3D
	var ladder_foot := tower.to_global(Vector3(0.0, 0.0, -Camp.TOWER_LEG - 1.0))
	p.global_position = ladder_foot + Vector3(0.0, 0.2, 0.0)
	await physics_frame
	var lend: Node = null
	for n in get_nodes_in_group("interactable"):
		if n is LadderEnd and Geo.flat_dist(n.global_position, ladder_foot) < 0.5 and n.global_position.y < 3.0:
			lend = n
	check(lend != null, "the tower has a ladder")
	if lend != null:
		lend.interact(p)
	for i in 150:
		await physics_frame
	check(p.global_position.y > Camp.TOWER_DECK + Terrain.HOLM_HEIGHT - 0.3, "a keeper climbs up onto the platform (y %.2f)" % p.global_position.y)
	for i in 30:
		await physics_frame
	check(p.global_position.y > Camp.TOWER_DECK + Terrain.HOLM_HEIGHT - 0.3, "and the platform holds them")
	check(sl.interact_prompt() != "" and p._find_interactable() == sl, "up there, the searchlight is in reach")
	sl.interact(p)
	check(p.manning == sl and sl.operator == p, "they take the searchlight")
	# Aim it at a Bloated coming up the east beach and burn it.
	var bl = load("res://scenes/enemies/bloated.gd").new()
	bl.lighthouse = main.lighthouse
	bl.position = Terrain.holm_beach_point(0, 0.8)
	main.get_node("Enemies").add_child(bl)
	await physics_frame
	bl.velocity = Vector3.ZERO
	bl.speed = 0.0
	p._lamp_point = bl.global_position
	for i in 60:
		await physics_frame
	sl.toggle_mode()
	var hp0: int = bl.hp
	for i in 180:
		p._lamp_point = bl.global_position
		await physics_frame
		if not is_instance_valid(bl):
			break
	check(not is_instance_valid(bl) or bl.hp < hp0, "the focused searchlight burns it")
	check(gen.draw_total() > 0.4, "the focused beam draws more (%.2f a second)" % gen.draw_total())
	p.leave_light()
	check(p.manning == null and sl.operator == null, "and they let it go")
	# Fill the generator from the store, then run it dry.
	Stk.add("diesel", 1)
	gen.fuel = 40.0
	check(gen.work_kind() == "can" and gen.interact(p) and absf(gen.fuel - 75.0) < 0.01, "a jerrycan of diesel fills it by 35")
	gen.fuel = 0.01
	for i in 10:
		await physics_frame
	lit = 0
	for l in main.camp.searchlights:
		if l.is_lit():
			lit += 1
	check(not gen.running and lit == 0 and not main.camp._hut_lights[0].visible, "run dry, the camp goes dark")
	var diesel_on_beach := 0
	for n in get_nodes_in_group("interactable"):
		if n is ScavengePoint and n.kind == "diesel" and Terrain.on_holm(n.global_position.x, n.global_position.z):
			diesel_on_beach += 1
	check(diesel_on_beach == 2, "diesel washes up on the holm's two beaches")
	Cyc._enter(Cyc.Phase.DAY)

	# ---- two people: the split screen ----
	main = await _load(2, false)
	var d: CameraDirector = main.director
	var p0 = main.players[0]
	var p1 = main.players[1]
	for k in [p0, p1]:
		k.camera = null
	for i in 10:
		await physics_frame
	check(d.view_count() == 1 and main.camera.global_position.distance_to(main.CAMERA_POS) < 0.05, "together on the main island: one view, framed as it always was")
	p1.global_position = Vector3(c.x, Terrain.HOLM_HEIGHT + 0.2, c.y)
	# Real time passing: physics frames are 1/60 s each.
	for i in 120:
		await physics_frame
	check(d.view_count() == 2 and d.split_amount() >= 1.0, "apart (one in the camp): the screen splits in two")
	check(not p1.ai and not p0.ai, "both are people")
	p0.global_position = Vector3(c.x + 1.5, Terrain.HOLM_HEIGHT + 0.2, c.y)
	for i in 300:
		await physics_frame
	check(d.view_count() == 1 and d.split_amount() == 0.0, "together again in the camp: one view")
	var holm_cam: Vector3 = CameraDirector.HOLM_FOCUS + CameraDirector.OFFSET
	check(main.camera.global_position.distance_to(holm_cam) < 1.5, "framing the holm (%s)" % main.camera.global_position)

	# ---- solo with helpers: always three keepers ----
	main = await _load(1, true)
	check(main.players.size() == 3, "solo, two helpers make three keepers")
	check(not main.players[0].ai and main.players[1].ai and main.players[2].ai, "P1 is the person; the others are helpers")
	var light: KeeperAI = main.players[1].get_node("KeeperAI")
	var camp: KeeperAI = main.players[2].get_node("KeeperAI")
	check(light.role == "light" and camp.role == "camp", "one keeps the light, one the camp")
	check(Terrain.in_camp(main.players[2].global_position.x, main.players[2].global_position.z), "the camp's warden starts in the camp")
	main.player.camera = null
	check(root.get_node("Players").humans() == 1, "the creatures still scale with one person")
	var Cycle = root.get_node("Cycle")
	Cycle._enter(Cycle.Phase.DUSK)
	Engine.time_scale = 4.0
	var on_lamp := false
	for i in 1500:
		await physics_frame
		if main.players[1].operating:
			on_lamp = true
			break
	Engine.time_scale = 1.0
	check(on_lamp, "at dusk the lighthouse helper climbs up and takes the lamp")
	check(Terrain.in_camp(main.players[2].global_position.x, main.players[2].global_position.z, -0.5), "the warden stays at the camp")
	# A downed keeper gets helped up.
	main.players[2].global_position = Vector3(c.x + 1.0, Terrain.HOLM_HEIGHT + 0.2, c.y + 1.0)
	main.player.global_position = Vector3(c.x - 1.0, Terrain.HOLM_HEIGHT + 0.2, c.y + 1.0)
	main.player.take_damage(500)
	check(main.player.downed and root.get_node("Run").active, "the person goes down; with helpers about the run goes on")
	Engine.time_scale = 4.0
	for i in 900:
		await physics_frame
		if not main.player.downed:
			break
	Engine.time_scale = 1.0
	check(not main.player.downed, "a helper comes and gets them back up")

	root.get_node("Players").helpers = true
	root.get_node("Players").wanted = 1
	print("\n%s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
