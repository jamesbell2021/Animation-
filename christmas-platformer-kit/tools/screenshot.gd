extends SceneTree
## Captures screenshots of the demo level at several points (needs a display or xvfb-run).
##   godot --path . --script res://tools/screenshot.gd -- out_dir
var shots := [3, 24, 38, 54, 64, 86]
var level: Node
var frame := 0
var idx := 0
var out_dir := "res://docs"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	level = load("res://scenes/demo_level.tscn").instantiate()
	root.add_child(level)

func _process(_d: float) -> bool:
	frame += 1
	var player: CharacterBody2D = level.get_node("Player")
	player.set_physics_process(false)
	var cam: Camera2D = player.get_node("Camera")
	cam.position_smoothing_enabled = false
	if frame % 20 == 1:
		player.position = Vector2(shots[idx] * 64 + 32, 9 * 64 + 34)
		if shots[idx] == 54:
			player.position.y = 3 * 64 + 34
	if frame % 20 == 19:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%02d.png" % [out_dir, idx])
		idx += 1
		if idx >= shots.size():
			return true
	return false
