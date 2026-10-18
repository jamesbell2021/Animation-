extends SceneTree
## Headless check that every Fairground Mayhem item does what it should.
## Gives the player each item, places a still bot where it should be hit,
## uses the item and checks the result. Run from the project folder:
##   godot --headless --path . --fixed-fps 60 -s res://tools/item_test.gd

const K := ItemKinds.Kind
const E := StatusEffects.Effect

var frame := 0
var gm: Node
var player: Contestant
var target: Contestant
var step := -1
var step_frame := 0
var passed := 0
var failed := 0
var hits := 0

# [label, kind, target offset from player (player faces -Z), wait frames, check]
var tests: Array = []


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		root.get_node("NetworkManager").settings = {"sections": 1, "bots": 2, "difficulty": 1, "countdown": 1, "items": true}
		change_scene_to_file("res://scenes/main/main.tscn")
		return false
	if frame < 5:
		return false
	if gm == null:
		gm = current_scene
		gm.items.hit.connect(func(_v: String, _a: String, _k: int) -> void: hits += 1)
		_build_tests()
		return false
	if not gm.race_manager.is_racing():
		return frame > 600
	if player == null:
		player = gm.player
		target = gm._contestants[1]
		for c in gm._contestants:
			var brain = c.get_node_or_null("BotController")
			if brain != null:
				brain.set_physics_process(false)
			c.move_direction = Vector3.ZERO
		gm._contestants[2].global_position = Vector3(10.0, 1.0, -30.0)
		gm._contestants[2].set_respawn_point(Vector3(10.0, 1.0, -30.0))
		_next_step()
		return false
	step_frame += 1
	var t: Array = tests[step]
	if step_frame == 40:
		_use(t)
	if step_frame == 40 + int(t[3]):
		var ok: bool = t[4].call()
		print("%s  %s" % ["PASS" if ok else "FAIL", t[0]])
		if ok:
			passed += 1
		else:
			failed += 1
		_next_step()
	if step >= tests.size():
		print("items: %d passed, %d failed, hit signals %d, gift boxes %d" % [passed, failed, hits, gm.items.get_box_count()])
		return true
	return frame > 60 * 120


func _reset_actor(c: Contestant, pos: Vector3) -> void:
	c.set_respawn_point(pos)
	c.respawn()
	c.get_node("StatusEffects").clear_all()
	c.get_node("ItemHolder").clear()
	c._visual.rotation.y = 0.0


func _next_step() -> void:
	step += 1
	step_frame = 0
	if step >= tests.size():
		return
	gm.items.reset()
	var t: Array = tests[step]
	_reset_actor(player, Vector3(0.0, 0.5, -16.0))
	_reset_actor(target, Vector3(0.0, 0.5, -16.0) + t[2])
	player.get_node("ItemHolder").give(t[1])
	if t.size() > 5:
		t[5].call()


func _use(t: Array) -> void:
	player._visual.rotation.y = 0.0
	player.use_requested = true
	if ItemKinds.is_trap(t[1]):
		# Walk the target onto the trap once it has armed.
		get_timer(1.3).timeout.connect(func() -> void: target.global_position = Vector3(0.0, 0.5, -16.0 + gm.items.trap_drop_distance))


func get_timer(seconds: float) -> SceneTreeTimer:
	return create_timer(seconds, false)


func _effect(c: Contestant, e: int) -> bool:
	return c.get_node("StatusEffects").has_effect(e)


func _build_tests() -> void:
	var front := Vector3(0.0, 0.0, -1.5)
	tests = [
		["Plastic Sword knocks the bot in front", K.SWORD, front, 10, func() -> bool: return target.is_stumbling()],
		["Zapper zaps the bot in front", K.ZAPPER, front, 10, func() -> bool: return target.is_stumbling()],
		["Balloon floats the bot in front", K.BALLOON, front, 10, func() -> bool: return _effect(target, E.FLOAT)],
		["Confetti Bomb blasts a bot beside you", K.CONFETTI, Vector3(2.5, 0.0, 0.0), 10, func() -> bool: return target.is_stumbling()],
		["Custard Pie splats a bot where it lands", K.PIE, Vector3(0.0, 0.0, -8.8), 70, func() -> bool: return target.is_stumbling()],
		["Rocket Boots speed you up", K.ROCKET_BOOTS, Vector3(6.0, 0.0, 0.0), 5, func() -> bool: return _effect(player, E.SPEED) and player.move_speed > 6.5],
		["Giant Magnet pulls in a nearby coin", K.MAGNET, Vector3(6.0, 0.0, 0.0), 30, func() -> bool: return _effect(player, E.MAGNET) and int(gm._coins.get(str(player.name), 0)) > 0],
		["Shield Bubble starts", K.SHIELD, Vector3(6.0, 0.0, 0.0), 5, func() -> bool: return _effect(player, E.SHIELD)],
		["Shield Bubble blocks a sword hit", K.SWORD, Vector3(0.0, 0.0, -1.5), 10, func() -> bool: return not target.is_stumbling() and not _effect(target, E.SHIELD), func() -> void: target.get_node("StatusEffects").apply(E.SHIELD, 10.0)],
		["Catapult trap flings the bot", K.CATAPULT, Vector3(5.0, 0.0, 0.0), 95, func() -> bool: return target.is_stumbling() or target.global_position.y > 1.5],
		["Boxing Glove trap punches the bot", K.BOXING_GLOVE, Vector3(5.0, 0.0, 0.0), 95, func() -> bool: return target.is_stumbling()],
		["Big Springer trap launches the bot", K.SPRINGER, Vector3(5.0, 0.0, 0.0), 95, func() -> bool: return target.is_stumbling() or target.global_position.y > 2.0],
		["Slippery Oil makes the bot slide", K.OIL_SLICK, Vector3(5.0, 0.0, 0.0), 95, func() -> bool: return _effect(target, E.OIL)],
		["Big Fatty Cake makes the bot fat", K.CAKE, Vector3(5.0, 0.0, 0.0), 95, func() -> bool: return _effect(target, E.FAT) and target.move_speed < 4.0],
		["Shrink Potion makes the bot tiny", K.SHRINK_POTION, Vector3(5.0, 0.0, 0.0), 95, func() -> bool: return _effect(target, E.SMALL)],
	]
