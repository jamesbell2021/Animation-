extends Node
## Headless smoke test: plays the real game for several waves without rendering.
##   godot --headless --path . res://tests/smoke_test.tscn
## Exits 0 when every check passes, 1 otherwise.

var _fail: int = 0


func check(cond: bool, label: String) -> void:
	print("  %s  %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_fail += 1


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	print("== Kaiju Coast smoke test ==")
	check(Game.state == Game.State.TITLE, "boots to the title screen")
	check(Game.kaiju.size() >= 3, "attract mode has kaiju (%d)" % Game.kaiju.size())
	check(Game.turrets.size() == 7, "attract mode has 7 guns")
	check(Game.world.buildings.size() > 100, "city has %d buildings" % Game.world.buildings.size())
	check(Game.sfx.streams.size() >= 20, "%d sound effects synthesised" % Game.sfx.streams.size())
	# Demo runs on its own.
	for i: int in range(300):
		Game.main.step(1.0 / 30.0)
	check(true, "attract mode ran 10 s")
	# A real game.
	Game.new_game()
	check(Game.state == Game.State.PLAY and Game.funds == 420, "new game: ¥420")
	check(Game.kaiju.is_empty() and Game.turrets.is_empty(), "new game starts empty")
	Game.main.select(Game.pads[3])
	Game.main.act("build", "cannon")
	check(Game.turrets.size() == 1 and Game.funds == 320, "built a cannon for ¥100")
	Game.main.act("up", "")
	check(Game.pads[3].turret.lvl == 2, "upgraded it to level 2")
	Game.main.select(Game.pads[1])
	Game.main.act("build", "rail")
	check(Game.turrets.size() == 1, "can't afford a rail yet")
	Game.funds = 4000
	for spec: Array in [[1, "cannon"], [5, "rocket"], [2, "tesla"], [4, "rail"], [8, "flak"], [10, "cannon"], [11, "rocket"]]:
		Game.main.select(Game.pads[spec[0]])
		Game.main.act("build", spec[1])
	check(Game.turrets.size() == 8, "built 8 guns")
	Game.main.select("zep")
	Game.main.act("zup", "bomb")
	Game.main.act("zup", "pods")
	check(Game.zep.lvl["bomb"] == 1 and Game.zep.lvl["pods"] == 1, "airship upgrades")
	Game.main.select(null)
	# Play three waves; man a gun in the middle of the second.
	var steps: int = 0
	for w: int in range(3):
		Game.start_wave()
		check(Game.phase == "wave" and Game.wave == w + 1, "wave %d started" % (w + 1))
		var s: int = 0
		while Game.phase == "wave" and Game.state == Game.State.PLAY and s < 30 * 300:
			if w == 1 and s == 30 * 30:
				Game.player.enter(Game.turrets[0])
				Game.player.firing = true
			if w == 1 and s == 30 * 45:
				Game.player.swap()
			if w == 1 and s == 30 * 60:
				Game.player.exit_seat()
			Game.main.step(1.0 / 30.0)
			s += 1
		steps += s
		print("    wave %d: %ds, city %d%%, kills %d, funds ¥%d, fx %d" % [Game.wave, s / 30, int(Game.city), Game.kills, Game.funds, Game.fx.count()])
		check(Game.phase == "build", "wave %d cleared" % (w + 1))
	check(Game.kills >= 10, "killed %d kaiju" % Game.kills)
	check(Game.city > 0.0, "city still standing (%d%%)" % int(Game.city))
	# Boss wave.
	Game.wave = 4
	Game.start_wave()
	var s2: int = 0
	var boss_seen: bool = false
	while Game.phase == "wave" and Game.state == Game.State.PLAY and s2 < 30 * 400:
		for k: Kaiju in Game.kaiju:
			if k.def["boss"]:
				boss_seen = true
		Game.main.step(1.0 / 30.0)
		s2 += 1
	check(boss_seen, "wave 5 brought the Dai-Oni")
	print("    wave 5: %ds, city %d%%, kills %d, state %s" % [s2 / 30, int(Game.city), Game.kills, Game.State.keys()[Game.state]])
	# Losing.
	Game.city = 0.5
	Game.wave = 6
	if Game.state == Game.State.PLAY:
		if Game.phase == "build":
			Game.start_wave()
		var s3: int = 0
		while Game.state == Game.State.PLAY and s3 < 30 * 300:
			Game.main.step(1.0 / 30.0)
			s3 += 1
	check(Game.state == Game.State.OVER, "the city can fall")
	Game.main.to_title()
	check(Game.state == Game.State.TITLE, "back to the title")
	print("== %s ==" % ("ALL PASS" if _fail == 0 else "%d FAILED" % _fail))
	get_tree().quit(1 if _fail > 0 else 0)
