class_name LevelLoader
extends RefCounted
## Builds a grid and spawn list from an ASCII map (levels/*.txt), so a level is a text file
## a designer can edit in any editor. One character a tile:
##
##   #  rock wall           %  soft rock (drill or dynamite)    o  boulder (cover)
##   .  floor               f  glowing fungus (a light source)   D  iron door (shut)
##   V  steam vent          v  valve (shuts the vents near it)   E  the lift (extraction)
##   S  a squad start (on the lift)   J  the lost survey journal
##   w  insectoid worker    c  crawler                           H  the hive

const VALVE_REACH := 4.0


static func load_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("LevelLoader: can't open %s" % path)
		return {}
	return parse(f.get_as_text())


static func parse(text: String) -> Dictionary:
	var rows: PackedStringArray = []
	for line in text.split("\n"):
		var l := line.strip_edges(false, true)
		if not l.is_empty():
			rows.append(l)
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	var grid := TacGrid.new()
	grid.setup(w, h)
	var squad: Array[Vector2i] = []
	var enemies: Array = []
	var lift: Array[Vector2i] = []
	var journal := Vector2i(-1, -1)
	var valve_tiles: Array[Vector2i] = []
	for y in h:
		var row := rows[y]
		for x in w:
			var ch := row[x] if x < row.length() else "#"
			var c := Vector2i(x, y)
			var t := TacGrid.T.FLOOR
			match ch:
				"#":
					t = TacGrid.T.WALL
				"%":
					t = TacGrid.T.SOFT_ROCK
				"o":
					t = TacGrid.T.BOULDER
				"f":
					t = TacGrid.T.FUNGUS
				"D":
					t = TacGrid.T.DOOR
				"V":
					t = TacGrid.T.VENT
					grid.vents.append(c)
					grid.vent_on[c] = true
				"v":
					t = TacGrid.T.VALVE
					valve_tiles.append(c)
				"E":
					t = TacGrid.T.LIFT
					lift.append(c)
				"S":
					t = TacGrid.T.LIFT
					lift.append(c)
					squad.append(c)
				"J":
					journal = c
				"w":
					enemies.append(["worker", c])
				"c":
					enemies.append(["crawler", c])
				"H":
					enemies.append(["hive", c])
			grid.set_t(c, t)
	# A valve shuts every vent within reach of it.
	for v in valve_tiles:
		var linked: Array[Vector2i] = []
		for vent in grid.vents:
			if Rules.dist(v, vent) <= VALVE_REACH:
				linked.append(vent)
		grid.valves[v] = linked
	grid.recompute_steam()
	return {
		"grid": grid,
		"squad": squad,
		"enemies": enemies,
		"lift": lift,
		"journal": journal,
	}
