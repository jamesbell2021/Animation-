extends SceneTree
# Run: godot --headless --path sea-they-are-angry --script res://tests/slice_ledge.gd
# The crag: shoving creatures off the ledge, keepers' ladders, reach by level, cliff edges.

var fails := 0

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

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if FileAccess.file_exists("user://run.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://run.json"))
	# Every keeper here is scripted: no helpers.
	root.get_node("Players").helpers = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 600:
		if current_scene != null and current_scene.get("player") != null:
			break
		await process_frame
	await frames(3)
	var main = current_scene
	var player: Player = main.player
	player.camera = null

	# Shove: a Bloated climbing the ledge, struck outward from the crag side, goes over the edge.
	var s := 0.4
	var p := Terrain.ledge_point(s)
	var out := Vector3(p.x, 0.0, p.z).normalized()
	var b := Bloated.new()
	b.lighthouse = main.lighthouse
	b.position = p
	main.get_node("Enemies").add_child(b)
	await wait_until(func(): return b.state == &"Approach", 120)
	b.speed = 0.0
	player.global_position = b.global_position - out * 1.2 + Vector3(0.0, 0.1, 0.0)
	await frames(2)
	player._aim = out
	player._attack_cd = 0.0
	player._attack()
	var top_y: float = b.global_position.y
	await wait_until(func(): return b.global_position.y < Terrain.PLATEAU_HEIGHT + 0.3, 180)
	# The fall hurts when the ragdoll comes to rest at the bottom.
	await wait_until(func(): return b.hp < 60 - Player.ATTACK_DMG, 120)
	print("   fell from %.1f to %.1f, hp %d" % [top_y, b.global_position.y, b.hp])
	check(b.global_position.y < Terrain.PLATEAU_HEIGHT + 0.3, "an outward blow shoves a climber off the ledge to the meadow")
	check(b.hp < 60 - Player.ATTACK_DMG, "the fall hurts on top of the blow (hp %d)" % b.hp)
	b.speed = 1.15
	# It lies there a moment as a ragdoll, then gets up and finds a way round.
	await wait_until(func(): return b.state == &"Approach", 240)
	await frames(10)
	check(not b.route.is_empty() and b.route[0].y < Terrain.PLATEAU_HEIGHT + 0.6, "it heads back round by the meadow, not up the wall")
	b.queue_free()

	# An inward blow on the ledge doesn't shove.
	var b2 := Bloated.new()
	b2.lighthouse = main.lighthouse
	b2.position = Terrain.ledge_point(0.5)
	main.get_node("Enemies").add_child(b2)
	await wait_until(func(): return b2.state == &"Approach", 120)
	b2.speed = 0.0
	var out2 := Vector3(b2.global_position.x, 0.0, b2.global_position.z).normalized()
	player.global_position = b2.global_position + out2 * 1.0 + Vector3(0.0, 0.1, 0.0)
	await frames(2)
	player._aim = -out2
	player._attack_cd = 0.0
	player._attack()
	await frames(40)
	check(Terrain.on_ledge(b2.global_position.x, b2.global_position.z) and b2.global_position.y > Terrain.PLATEAU_HEIGHT + 1.0, "an inward blow leaves it on the ledge")
	b2.queue_free()

	# Ladders: top -> ledge -> meadow and back.
	var ends := []
	for n in get_nodes_in_group("interactable"):
		if n is LadderEnd:
			ends.append(n)
	check(ends.size() == 4, "two ladders, four ends")
	var top_end: LadderEnd = null
	for e in ends:
		if top_end == null or e.global_position.y > top_end.global_position.y:
			top_end = e
	player.global_position = top_end.global_position + Vector3(0.0, 0.1, 0.0)
	await frames(3)
	check(player.interact_prompt().begins_with("[E] Climb down"), "ladder prompt at the top: " + player.interact_prompt())
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await wait_until(func(): return not player.is_climbing(), 200)
	check(Terrain.on_ledge(player.global_position.x, player.global_position.z), "climbing down lands on the ledge")
	# Lower ladder.
	var lower_top: LadderEnd = null
	for e in ends:
		if absf(e.global_position.y - player.global_position.y) < 0.6 and e.prompt.begins_with("[E] Climb down"):
			lower_top = e
	player.global_position = lower_top.global_position + Vector3(0.0, 0.1, 0.0)
	await frames(3)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await wait_until(func(): return not player.is_climbing(), 200)
	await frames(10)
	check(absf(player.global_position.y - Terrain.PLATEAU_HEIGHT) < 0.6 and player.is_on_floor(), "and the second ladder down to the meadow")
	check(player.interact_prompt().begins_with("[E] Climb up"), "climb-up prompt at the foot: " + player.interact_prompt())

	# Reach by level: the ledge fence can't be repaired from the meadow beneath it.
	var ledge_fence: Fence = null
	for f in get_nodes_in_group("structures"):
		if f is Fence and Terrain.on_ledge(f.global_position.x, f.global_position.z) and f.global_position.y > 3.0:
			ledge_fence = f
	ledge_fence.take_damage(50)
	var under := Vector3(ledge_fence.global_position.x, 0.0, ledge_fence.global_position.z).normalized() * (Terrain.ledge_radius(0.58) + Terrain.LEDGE_HALF + Terrain.CRAG_BLEND + 0.4)
	player.global_position = Vector3(under.x, Terrain.height_at(under.x, under.z) + 0.1, under.z)
	await frames(3)
	check(not player.interact_prompt().begins_with("[E] Repair"), "no repairing the ledge fence from the meadow below")

	# Mouse aim from the crag top: the cursor ray is traced to the real ground, and the beam
	# swings from the lamp to that point, so a creature under the cursor on a beach burns.
	var cam: Camera3D = main.camera
	var spot := Terrain.beach_point(0, 0.6)
	var hit: Vector3 = Player._ground_hit(cam.global_position, (spot - cam.global_position).normalized())
	check(hit.distance_to(spot) < 0.6, "cursor ray meets the beach where it is drawn (off by %.2f m)" % hit.distance_to(spot))
	var lamp: Lamp = main.lighthouse.lamp
	var Cycle = root.get_node("Cycle")
	Cycle._enter(Cycle.Phase.DUSK)
	await frames(2)
	player.global_position = Vector3(-1.6, Terrain.CRAG_TOP + 0.1, 2.7)
	await frames(2)
	player._toggle_operate()
	var b3 := Bloated.new()
	b3.lighthouse = main.lighthouse
	b3.position = spot
	main.get_node("Enemies").add_child(b3)
	await wait_until(func(): return b3.state == &"Approach", 120)
	b3.speed = 0.0
	# What _update_aim would set from the mouse; the keeper's own aim points elsewhere.
	player._aim = Vector3(-1.0, 0.0, 0.0)
	player.set_physics_process(false)
	player._lamp_point = spot
	if lamp.mode != Lamp.Mode.FOCUSED:
		lamp.toggle_mode()
	var hp3 := b3.hp
	await frames(150)
	check(b3.hp < hp3, "the focused beam follows the cursor point and burns it (hp %d -> %d)" % [hp3, b3.hp])
	player.set_physics_process(true)
	player._toggle_operate()
	b3.queue_free()
	Cycle._enter(Cycle.Phase.DAY)
	await frames(2)

	# Cliff edge: walking straight out to sea stops at the edge.
	var a := 45.0
	player.global_position = Terrain.at_angle(a, Terrain.coast_radius(a) - 2.0) + Vector3(0.0, 0.2, 0.0)
	await frames(3)
	player._aim = Vector3(sin(deg_to_rad(a)), 0.0, cos(deg_to_rad(a)))
	var key := "move_right"
	Input.action_press(key)
	Input.action_press("move_down")
	await frames(120)
	Input.action_release(key)
	Input.action_release("move_down")
	var gp := player.global_position
	print("   at the cliff: r %.1f (edge %.1f), ground %.1f" % [Vector2(gp.x, gp.z).length(), Terrain.coast_radius(a), Terrain.height_at(gp.x, gp.z)])
	check(Terrain.height_at(gp.x, gp.z) > Terrain.PLATEAU_HEIGHT - 0.6, "keepers stop at the cliff edge instead of walking off it")

	print("RESULT: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()
