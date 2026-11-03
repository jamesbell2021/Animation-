extends SceneTree
## Balance run: the squad bot plays whole expeditions against the swarm and the totals are
## printed. Usage (games, then the turn limit):
##   godot --headless --path subterranean-1888 --script res://tools/autoplay.gd -- 40 40

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 20
	var limit := int(args[1]) if args.size() > 1 else 40
	var results := {"extracted": 0, "exterminated": 0, "lost": 0, "timeout": 0}
	var turns := 0
	var lost := 0
	var kills := 0
	var reactions := 0
	var hits := 0
	var shots := 0
	var journals := 0
	var t0 := Time.get_ticks_msec()
	for g in games:
		var b := Catalog.new_battle(Catalog.LEVELS[0], 1000 + g)
		while b.outcome == "" and b.turn <= limit:
			SquadBot.play_turn(b)
		var o := b.outcome if b.outcome != "" else "timeout"
		results[o] += 1
		turns += b.turn
		lost += b.stats["lost"]
		kills += b.stats["kills"]
		reactions += b.stats["reactions"]
		hits += b.stats["hits"]
		shots += b.stats["shots"]
		if b.journal_carrier != -1 or o == "extracted":
			journals += 1
		print("game %2d  %-12s turn %2d  soldiers lost %d  kills %2d  reactions %d" % [
			g, o, b.turn, b.stats["lost"], b.stats["kills"], b.stats["reactions"]])
	var n := float(games)
	print("")
	print("%d games in %.1f s" % [games, (Time.get_ticks_msec() - t0) / 1000.0])
	print("outcomes: %s" % str(results))
	print("avg turns %.1f, soldiers lost %.2f, kills %.1f, reactions %.1f, hit rate %d%%, journal held %d%%" % [
		turns / n, lost / n, kills / n, reactions / n, roundi(100.0 * hits / maxf(1.0, shots)), roundi(100.0 * journals / n)])
	quit()
