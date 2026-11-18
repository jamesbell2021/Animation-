extends SceneTree
## Headless check that every tile mechanic in the demo works.
##   godot --headless --path . --script res://tools/test_mechanics.gd
var level: Node
var player: ElfPlayer
var ground: TileMapLayer
var step := 0
var t := 0
var results := {}
var died := false
var won := false
var mark := 0.0

class Driver extends Node:
	## Runs before the player each physics frame, so simulated presses count as "just pressed".
	var tick: Callable
	func _physics_process(_d: float) -> void:
		tick.call()


func _initialize() -> void:
	var driver := Driver.new()
	driver.tick = _tick
	driver.process_physics_priority = -100
	root.add_child(driver)
	level = load("res://scenes/demo_level.tscn").instantiate()
	root.add_child(level)
	player = level.get_node("Player")
	ground = level.get_node("Ground")
	player.died.connect(func(): died = true)
	player.reached_goal.connect(func(): won = true)

func cell_pos(x: int, y: int) -> Vector2:
	return Vector2(x * 64 + 32, y * 64 + 32)

func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump"]:
		Input.action_release(a)

func goto(next: int) -> void:
	step = next
	t = 0
	release_all()

func _tick() -> void:
	t += 1
	match step:
		0:  # lands on the ground
			if t == 60:
				results["lands on snowy ground"] = player.is_on_floor()
				goto(1)
		1:  # spring launches high
			if t == 1:
				player.global_position = cell_pos(38, 7); player.velocity = Vector2.ZERO
			if t > 5 and player.velocity.y < -1000:
				results["spring bounces"] = true; goto(2)
			if t == 90:
				results["spring bounces"] = false; goto(2)
		2:  # ice: slides further than snow after letting go
			if t == 1:
				player.global_position = cell_pos(39, 9); player.velocity = Vector2(360, 0)
				Input.action_press("move_right")
			if t == 3:
				Input.action_release("move_right"); mark = player.global_position.x
			if t == 90:
				results["ice slide after letting go (px)"] = snappedf(player.global_position.x - mark, 1)
				goto(3)
		3:  # hazard: spikes
			if t == 1:
				died = false; player.global_position = cell_pos(17, 9); player.velocity = Vector2.ZERO
			if t == 60:
				results["spikes hurt"] = died; goto(4)
		4:  # ladder
			if t == 1:
				player.global_position = cell_pos(51, 8) + Vector2(0, 2); player.velocity = Vector2.ZERO
			if t == 5:
				mark = player.global_position.y; Input.action_press("move_up")
			if t == 40:
				results["ladder climbs"] = player.global_position.y < mark - 60; goto(5)
		5:  # crumbling ice
			if t == 1:
				player.global_position = cell_pos(64, 7); player.velocity = Vector2.ZERO
			if t == 45:
				results["cracked ice crumbles"] = ground.get_cell_source_id(Vector2i(64, 8)) == -1
			if t == 150:  # wait out the fall into the water and the respawn
				goto(6)
		6:  # gift block
			if t == 1:
				player.global_position = cell_pos(7, 9); player.velocity = Vector2.ZERO
			if t == 20:
				Input.action_press("jump")
			if t == 60:
				results["gift block gives star"] = ground.get_cell_atlas_coords(Vector2i(7, 6)) == Vector2i(7, 2)
				goto(7)
		7:  # one-way platform: jump up through, then stand on it
			if t == 1:
				player.global_position = cell_pos(22, 7); player.velocity = Vector2.ZERO
			if t == 10:
				Input.action_press("jump")
			if t == 25:
				Input.action_release("jump")
			if t == 90:
				results["one-way plank: jump through & stand"] = player.is_on_floor() and player.global_position.y < 6 * 64
				goto(8)
		8:  # goal
			if t == 1:
				player.global_position = cell_pos(92, 9); player.velocity = Vector2.ZERO
			if t == 20:
				results["north pole = goal"] = won
				for k in results:
					print("%-40s %s" % [k, results[k]])
				quit()
