extends SceneTree
# The client's half of the LAN test (see tests/lan_host.gd).

var fails := 0

func check(c: bool, w: String) -> void:
	print(("PASS  client: " if c else "FAIL  client: ") + w)
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

# Something of this script's in the game here (a puppet only, if asked).
func _found(script_file: String, puppet: bool) -> bool:
	var main = current_scene
	if main == null:
		return false
	for n in main.get_children():
		var sc = n.get_script()
		if sc != null and sc.resource_path.ends_with(script_file) and (not puppet or n.get("puppet")):
			return true
	return false

func _stage() -> int:
	return root.get_node("Stock").get_amount("poison") - 100

func _at(n: int) -> bool:
	return await _until(func(): return _stage() >= n, 3600)

func _ack(on: bool) -> void:
	if on:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")

func _tap(a: String) -> void:
	Input.action_press(a)
	await _wait(3)
	Input.action_release(a)

func _go() -> void:
	var Net = root.get_node("Net")
	var Run = root.get_node("Run")
	var Stk = root.get_node("Stock")
	var Cyc = root.get_node("Cycle")
	await _wait(30)
	check(Net.join("127.0.0.1", "Ewan") == "", "joining 127.0.0.1")
	check(await _until(func(): return Net.lobby.size() == 2, 3600), "in the host's lobby")
	check(Net.my_slot == 1, "as keeper 2")
	change_scene_to_file("res://scenes/main.tscn")
	check(await _until(func(): return current_scene != null and current_scene.get("player") != null and Run.active, 3600), "the host starts the run here too")
	var main = current_scene

	# 1: three puppets; this machine's keeper walks.
	check(await _at(1), "stage 1")
	check(main.players.size() == 3 and main.players[0].puppet and main.players[1].puppet, "three keepers, all puppets of the host's")
	check(main.player == main.players[1] and main.director.players == [main.players[1]], "the screen follows this machine's keeper")
	var start: Vector3 = main.player.global_position
	Input.action_press("move_right")
	await _wait(70)
	Input.action_release("move_right")
	await _wait(20)
	check(main.player.global_position.x > start.x + 1.0, "it walks here as it does on the host (%.1f m)" % (main.player.global_position.x - start.x))
	_ack(true)

	# 2: what the host has, here.
	check(await _at(2), "stage 2")
	_ack(false)
	var seen := func() -> bool:
		return not get_nodes_in_group("enemies").is_empty()
	check(await _until(seen, 300), "the host's Bloated is here")
	var b = get_nodes_in_group("enemies")[0] if not get_nodes_in_group("enemies").is_empty() else null
	check(b != null and b.puppet and b.net_id > 0, "as a puppet with the host's id")
	await _wait(30)
	check(b != null and Geo.flat_dist(b.global_position, Terrain.beach_point(0, 0.7)) < 1.5, "where the host has it")
	var fence = null
	for s in get_nodes_in_group("structures"):
		if s is Fence and fence == null:
			fence = s
	check(await _until(func(): return fence.hp == fence.max_hp - 30, 300), "the fence the host's creature battered, battered here (%d)" % fence.hp)
	check(Stk.get_amount("shells") == 42, "the store as the host has it")
	check(Cyc.phase == Cyc.Phase.DUSK, "dusk here when it's dusk there")
	check(await _until(func(): return main.lighthouse.lamp.is_lit(), 120), "and the lamp lit")
	check(Net.messages_seen.has("Hello over the LAN"), "the host's message, on this HUD: %s" % str(Net.messages_seen))
	check(main.hud._warn_label.text.contains("A warning for everyone") or main.hud._warn_label.text != "", "and its warning")
	check(Net.fx_seen > 0, "effects and sounds sent over (%d)" % Net.fx_seen)
	_ack(true)

	# 3: the shed's menu, run on the host, shown here.
	check(await _at(3), "stage 3")
	_ack(false)
	await _wait(30)
	check(main.player.interact_prompt().contains("workbench"), "the host's prompt for this keeper: " + main.player.interact_prompt())
	await _tap("interact")
	check(await _until(func(): return ChoiceMenu.current != null, 300), "E at the shed: its menu opens here")
	var m = ChoiceMenu.current
	check(m != null and m.display_only and m._rows.size() > 3, "with the host's rows")
	m.choose(1)
	check(await _until(func(): return Run.arms[1].has("shotgun"), 300), "pick the shotgun: the host gives it to this keeper")
	await _wait(10)
	m = ChoiceMenu.current
	if m != null:
		m.choose(m._rows.size())
	check(await _until(func(): return ChoiceMenu.current == null, 120), "Leave closes it")
	await _wait(10)
	_ack(true)

	# 4: fire.
	check(await _at(4), "stage 4")
	_ack(false)
	await _wait(10)
	check(main.player.arsenal.weapon == "shotgun", "the shotgun in hand here")
	await _tap("attack")
	await _wait(20)
	_ack(true)

	# 5: the squid's ink and the thrown boathook.
	check(await _at(5), "stage 5")
	_ack(false)
	check(await _until(func(): return _found("ink_cloud.gd", false), 600), "the squid's ink shows here")
	check(await _until(func(): return _found("harpoon.gd", true), 600), "the host's boathook flies here")
	_ack(true)
	check(await _until(func(): return not _found("harpoon.gd", true), 900), "and goes when the host's keeper has it back")

	# 6: the end.
	check(await _at(6) or not Run.active, "stage 6")
	_ack(false)
	check(await _until(func(): return not Run.active and main.hud._over.visible, 300), "the run ends here too, and says so")
	check(main.hud._over_btn.disabled, "the host starts the next one")
	check(await _until(func(): return current_scene != main and current_scene != null and current_scene.get("player") != null and Run.active, 3600), "and does: a new run here too")
	check(current_scene.player == current_scene.players[1] and current_scene.player.puppet, "still keeper 2")
	await _wait(60)
	Net.leave()
	await _wait(30)
	print("\nCLIENT %s" % ("ALL PASS" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)
