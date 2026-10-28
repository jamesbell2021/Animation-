extends SceneTree
## Headless checks for Neon Mega Tank. Each run plays one scenario inside the real game and
## prints PASS / FAIL lines. Run them all with tools/tests/run_tests.sh, or one with:
##
##   godot --headless --path . --fixed-fps 60 -s tools/tests/game_test.gd -- <scenario> [seed]
##
## Scenarios (in scenarios.gd): waves, cannon, repair, shield, collapse, enemies, demo, battle.
## This loader names no game classes, so it compiles before the game's autoloads exist; the
## scenarios themselves load on the first frame.

const SEED := 4242

var _runner: Node
var _args := PackedStringArray()


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	var splash := root.get_node_or_null("StudioSplash")
	if splash:
		splash.free()
	var g := root.get_node("G")
	g.menu_done = true
	g.music_on = false
	g.ai_crew = false
	g.round_seed = int(_args[1]) if _args.size() > 1 else SEED
	seed(g.round_seed)
	g.joined_devices.clear()
	change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> bool:
	if _runner == null:
		var script: GDScript = load("res://tools/tests/scenarios.gd")
		if script == null or not script.can_instantiate():
			print("FAIL  tools/tests/scenarios.gd does not compile")
			quit(2)
			return false
		_runner = script.new()
		_runner.scenario = _args[0] if _args.size() > 0 else "cannon"
		_runner.g = root.get_node("G")
		# Run before the game each frame, like a controller read at the start of the frame.
		_runner.process_priority = -1000
		root.add_child(_runner)
	return false
