extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_creatures.gd
# The lamp-room door, hammer repairs, raids on the homestead, and the Squid, Crab and Eel.

var fails := 0
var main
var player: Player
var lh: Lighthouse
var lamp: Lamp

func check(cond: bool, what: String) -> void:
	if cond:
		print("PASS  ", what)
	else:
		fails += 1
		print("FAIL  ", what)

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()

func press(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)

func spawn(e: Enemy, at: Vector3) -> Enemy:
	e.lighthouse = lh
	e.position = at
	main.get_node("Enemies").add_child(e)
	return e

func clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(2)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null:
			break
		await process_frame
	await frames(3)
	main = current_scene
	player = main.player
	lh = main.lighthouse
	lamp = lh.lamp
	player.camera = null
	var Cycle = root.get_node("Cycle")
	var Stock = root.get_node("Stock")
	var Anger = root.get_node("Anger")

	# ---- the lamp-room door ----
	player.global_position = Vector3(-1.6, Terrain.CRAG_TOP + 0.1, 2.9)
	await frames(3)
	await press("operate")
	check(player.operating and lamp.operator == player, "R by the lighthouse takes the lamp")
	await wait_until(func(): return player.is_inside(), 120)
	check(player.is_inside() and not player.visible, "the keeper walks in at the door and is out of sight")
	check(Geo.flat_dist(player.global_position, lh.global_position + Vector3(0, 0, Player.DOOR_IN)) < 0.2, "inside, at the door")
	var hp0 := player.hp
	player.take_damage(30)
	check(player.hp == hp0, "nothing reaches the keeper in the lamp room")
	await press("operate")
	check(not player.operating and player.visible, "R again: lets go of the lamp and steps out")
	await wait_until(func(): return not player.is_busy(), 120)
	check(Geo.flat_dist(player.global_position, lh.global_position) > Player.DOOR_OUT - 0.3, "walks clear of the door")
	check(player.collision_layer == 2, "solid again outside")

	# ---- hammer repairs and the oil can ----
	var fence: Fence = null
	for f in get_nodes_in_group("structures"):
		if f is Fence and not Terrain.on_ledge(f.global_position.x, f.global_position.z):
			fence = f
	fence.take_damage(60)
	var inward := -Vector3(fence.global_position.x, 0, fence.global_position.z).normalized()
	var stand := fence.global_position + inward * 1.0
	player.global_position = Vector3(stand.x, Terrain.height_at(stand.x, stand.z) + 0.1, stand.z)
	await frames(3)
	var dw: int = Stock.get_amount("driftwood")
	await press("interact")
	await frames(3)
	check(player.is_busy() and player._hammer.visible and not player._hook_holder.visible, "repairing swaps the boathook for a hammer")
	check(fence.hp == 40, "nothing mended until the hammering's done")
	await wait_until(func(): return not player.is_busy(), 120)
	check(fence.hp == 90 and Stock.get_amount("driftwood") == dw - 1, "after the blows: +50 for 1 driftwood (hp %d)" % fence.hp)
	check(player._hook_holder.visible and not player._hammer.visible, "boathook back in hand")
	Stock.set_all({"driftwood": 0})
	fence.take_damage(30)
	await frames(2)
	await press("interact")
	await frames(3)
	check(not player.is_busy() and fence.hp == 60, "no driftwood, no hammering")
	Stock.set_all({"driftwood": 4, "bio": 2})
	Cycle._enter(Cycle.Phase.DUSK)
	await frames(2)
	lamp.fuel = 50.0
	player.global_position = Vector3(0.0, Terrain.CRAG_TOP + 0.1, 2.8)
	await frames(3)
	await press("interact")
	await frames(3)
	check(player._can.visible, "refuelling: the oil can")
	await wait_until(func(): return not player.is_busy(), 120)
	check(lamp.fuel >= 89.0 and Stock.get_amount("bio") == 1, "the oil goes in once poured (fuel %d)" % roundi(lamp.fuel))
	Cycle._enter(Cycle.Phase.DAY)
	await frames(2)

	# ---- the homestead is raided ----
	var shed: Shed = null
	for s in get_nodes_in_group("structures"):
		if s is Shed:
			shed = s
	check(shed != null, "the shed is a building that can be damaged")
	Engine.time_scale = 6.0
	var raider := spawn(Bloated.new(), Terrain.beach_point(0, 0.0)) as Bloated
	raider.raid = true
	var homes := {}
	for s in get_nodes_in_group("structures"):
		if s is Structure and Enemy.HOME_IDS.has(s.id):
			homes[s] = s.hp
	await wait_until(func(): return not is_instance_valid(raider), 4000)
	var hurt := []
	for s in homes:
		if s.hp < homes[s]:
			hurt.append(s.id)
	check(not is_instance_valid(raider) and not hurt.is_empty(), "a raiding Bloated walks to the homestead and bursts on it: %s" % [hurt])
	Engine.time_scale = 1.0
	var cottage: Structure = null
	for s in get_nodes_in_group("structures"):
		if s is Cottage:
			cottage = s
	cottage.take_damage(100)
	await frames(2)
	check(cottage._smoke != null, "a badly damaged cottage smoulders")
	check(cottage.work_kind() == "hammer", "and can be mended with the hammer")

	# ---- Squid ----
	await clear_enemies()
	player.global_position = Vector3(-1.6, Terrain.CRAG_TOP + 0.1, 2.9)
	await frames(2)
	Engine.time_scale = 4.0
	var sq := spawn(Squid.new(), Terrain.beach_point(1, 0.0)) as Squid
	var hp_before := player.hp
	await wait_until(func(): return player.hp < hp_before, 2400)
	print("   squid reached the keeper on the crag top: hp %d -> %d" % [hp_before, player.hp])
	check(player.hp < hp_before, "a Squid climbs straight up the crag to the keeper and lunges")
	Engine.time_scale = 1.0
	sq.speed_mult = 0.0
	sq.set_physics_process(false)
	sq.global_position = Terrain.beach_point(0, 0.6)
	sq.set_physics_process(true)
	sq.hp = 35
	Cycle._enter(Cycle.Phase.DUSK)
	await frames(2)
	lamp.set_operator(player)
	player._aim = Vector3(sq.global_position.x, 0, sq.global_position.z).normalized()
	if lamp.mode != Lamp.Mode.FOCUSED:
		lamp.toggle_mode()
	var t0 := Time.get_ticks_msec()
	await wait_until(func():
		if is_instance_valid(sq):
			sq.global_position = Terrain.beach_point(0, 0.6)
			player._aim = Vector3(sq.global_position.x, 0, sq.global_position.z).normalized()
		return not is_instance_valid(sq), 400)
	check(not is_instance_valid(sq), "the focused beam burns a Squid down (%.1f s)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	lamp.set_operator(null)
	# Ink hides a Bloated unless the beam is on it.
	var bl := spawn(Bloated.new(), Terrain.at_angle(60.0, 11.0)) as Bloated
	await wait_until(func(): return bl.state == &"Approach", 120)
	bl.speed = 0.0
	var ink := InkCloud.new()
	main.add_child(ink)
	ink.global_position = bl.global_position
	await frames(3)
	check(not bl.visible, "ink hides a Bloated inside the cloud")
	ink.queue_free()
	await frames(20)
	check(bl.visible, "and it shows again once the ink clears")
	bl.queue_free()
	Cycle._enter(Cycle.Phase.DAY)
	await frames(2)

	# ---- Crab ----
	await clear_enemies()
	for s in get_nodes_in_group("structures"):
		if s is Structure:
			s.hp = s.max_hp
			s._refresh()
	var cr := spawn(Crab.new(), Terrain.at_angle(-20.0, 9.8)) as Crab
	await wait_until(func(): return cr.state == &"Approach", 120)
	check(cr.target is Structure and Enemy.HOME_IDS.has(cr.target.id), "a Crab goes for the homestead (%s)" % (cr.target.id if cr.target is Structure else "?"))
	Engine.time_scale = 4.0
	var tgt: Structure = cr.target
	var thp := tgt.hp
	await wait_until(func(): return cr.state == &"WindUp", 1200)
	check(cr.state == &"WindUp", "it raises its claw beside it")
	await wait_until(func(): return tgt.hp < thp, 300)
	check(thp - tgt.hp == Crab.SLAM_STRUCT_DMG, "the slam takes %d off the %s" % [thp - tgt.hp, tgt.id])
	Engine.time_scale = 1.0
	cr.set_physics_process(false)
	cr.change_state(&"Approach")
	var fwd := Vector3(-sin(cr.rotation.y), 0, -cos(cr.rotation.y))
	var h1 := cr.hp
	cr.take_damage(20, -fwd, player)
	var front := h1 - cr.hp
	h1 = cr.hp
	cr.take_damage(20, fwd, player)
	var back := h1 - cr.hp
	cr.state = &"Recover"
	h1 = cr.hp
	cr.take_damage(20, fwd, player)
	var open := h1 - cr.hp
	check(front == 10 and back == 20 and open == 40, "shell: front %d, back %d, after a slam %d" % [front, back, open])
	cr.state = &"Approach"
	cr.set_physics_process(true)
	cr.change_state(&"WindUp")
	cr._stagger_cd = 0.0
	cr.in_light(Lamp.Mode.FOCUSED, 0.016)
	check(cr.state == &"Stagger", "a focused beam in its eyes mid-wind-up staggers it")
	await frames(90)
	check(cr.state != &"Slam" and cr.state != &"Stagger", "it comes out of the stagger without slamming (%s)" % cr.state)
	cr.queue_free()

	# ---- Eel ----
	await clear_enemies()
	Cycle._enter(Cycle.Phase.NIGHT)
	await frames(2)
	lh.hp = lh.max_hp
	# A keeper and a fence in the eel's line from the north beach.
	var origin := Terrain.beach_point(1, 0.0)
	var mid := origin.lerp(Vector3.ZERO, 0.5)
	player.global_position = Vector3(mid.x, Terrain.height_at(mid.x, mid.z) + 0.1, mid.z)
	var nfence: Fence = null
	for f in get_nodes_in_group("structures"):
		if f is Fence and Geo.flat_dist(f.global_position, Terrain.beach_point(1, 0.9)) < 1.5:
			nfence = f
	nfence.hp = nfence.max_hp
	var eel := Eel.new()
	eel.lighthouse = lh
	eel.origin = Vector3(origin.x, Terrain.SEA_LEVEL, origin.z)
	main.get_node("Enemies").add_child(eel)
	check(eel.state == &"Announce", "the Eel announces itself first")
	Engine.time_scale = 4.0
	var was_prone := [false]
	await wait_until(func():
		if player.is_prone():
			was_prone[0] = true
		return eel.state == &"Coil", 1200)
	Engine.time_scale = 1.0
	check(nfence.is_destroyed(), "its surge smashes the fence in its line")
	check(was_prone[0], "and knocks the keeper in its way flat")
	var lhp := lh.hp
	await frames(120)
	check(lh.hp < lhp, "coiled, it crushes the lighthouse (%d -> %d)" % [lhp, lh.hp])
	var anger0: int = Anger.value
	var bio0: int = Stock.get_amount("bio")
	lamp.set_operator(player)
	if lamp.mode != Lamp.Mode.FOCUSED:
		lamp.toggle_mode()
	player._prone_t = 0.0
	await wait_until(func():
		if is_instance_valid(eel) and eel.state == &"Coil":
			var hp_: Vector3 = eel._head.global_position
			player._lamp_point = hp_
			lamp.yaw = atan2(-hp_.x, -hp_.z)
		return not is_instance_valid(eel) or eel.state == &"Release", 900)
	check(is_instance_valid(eel) == false or eel.released_early, "the focused beam on its head drives it off early")
	check(Stock.get_amount("bio") == bio0 + 3, "and it leaves bio in its wake")
	check(Anger.value <= anger0, "the sea calms a little (anger %d -> %d)" % [anger0, Anger.value])
	lamp.set_operator(null)

	# ---- the schedule ----
	var Spawner = load("res://scenes/systems/spawner.gd")
	check(Spawner.eel_night(6, 1, 0) and Spawner.eel_night(9, 1, 0) and not Spawner.eel_night(5, 1, 0), "solo Eel nights: 6, 9")
	check(Spawner.eel_night(5, 2, 0) and Spawner.eel_night(8, 2, 0) and Spawner.eel_night(4, 2, 7), "co-op Eel nights: 5, 8; a night early when the sea is angry")
	var kinds := {}
	for row in main.spawner.night_table(3):
		kinds[row["kind"]] = true
	check(kinds.has("B") and kinds.has("S") and kinds.has("C"), "night 3 brings Bloated, Squid and a Crab")

	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()
