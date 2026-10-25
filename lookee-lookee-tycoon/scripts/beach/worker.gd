class_name Worker
extends Walker
## One of your hired Lookee Lookee staff, on the beach you're playing today (or a rival
## vendor during the Rival event). Roles:
##   seller  - runs a blanket with your stock and sells to tourists on their own
##   shouter - wanders near you yelling "Hello chicken nugget!" to send tourists your way
##   lookout - stands on the promenade, warns you about police and delays them
##   runner  - restocks your best sellers from the van when stock runs low
##   rival   - (event) a competitor stealing your customers; shout near them to scare them off

var data: Dictionary = {}
var role := "shouter"
var stall: Stall
var rival_patience := 5
var _timer := 0.0
var _rng := RandomNumberGenerator.new()
var _home := Vector2.ZERO
var _away := false


func setup(b: Node, d: Dictionary, start: Vector2) -> void:
	beach = b
	data = d
	role = str(d.get("role", "shouter"))
	position = start
	_rng.randomize()
	setup_avatar(d.get("appearance", AppearanceOptions.random_appearance(_rng)), true)
	speed = 95.0
	_timer = _rng.randf_range(1.0, 4.0)
	match role:
		"seller", "rival":
			_home = beach.random_sand_point(start.x, 700.0)
			walk_to(_home)
			stall = Stall.new()
			stall.owner_kind = "worker" if role == "seller" else "rival"
			stall.owner_node = self
			beach.world.add_child(stall)
			beach.register_stall(stall)
		"lookout":
			_home = Vector2(clampf(beach.vendor.position.x + _rng.randf_range(-250, 250), 80, BeachBackdrop.WORLD_W - 80), BeachBackdrop.PROM_Y + 30.0)
			walk_to(_home)
		_:
			_home = start
			walk_to(beach.random_sand_point(beach.vendor.position.x, 300.0))


func skill() -> float:
	return Staff.skill_mult(data) if role != "rival" else 1.0


func is_at_stall() -> bool:
	return stall != null and position.distance_to(stall.vendor_spot()) < 50.0 and not moving


func _process(delta: float) -> void:
	_timer -= delta
	match role:
		"seller", "rival":
			_process_seller(delta)
		"shouter":
			_process_shouter(delta)
		"lookout":
			_process_lookout(delta)
		"runner":
			_process_runner(delta)


func _process_seller(delta: float) -> void:
	if moving:
		if step_move(delta):
			if stall and not stall.is_open():
				if role == "rival" or Economy.total_stock() > 0:
					stall.open_at(position + Vector2(0, 30), 0)
					position = stall.vendor_spot()
					say("Hello chicken nugget!" if role == "seller" else "Cheaper here, chicken nugget!", "shout", 1.8)
		return
	if stall == null:
		return
	if not stall.is_open():
		# Out of stock earlier: reopen when there's stock again.
		if role == "seller" and Economy.total_stock() > 0 and _timer <= 0.0:
			walk_to(_home)
		return
	if role == "seller" and Economy.total_stock() <= 0:
		stall.close()
		say(Lines.pick(Lines.NO_STOCK), "bad", 2.0)
		_timer = 5.0
		return
	if _timer <= 0.0:
		_timer = _rng.randf_range(7.0, 12.0) / skill()
		avatar.shout(1.0)
		say("Hello chicken nugget!" if _rng.randf() < 0.6 else "Lookee lookee!", "shout", 1.4)
		beach.broadcast_shout(position, 200.0 * skill(), 0.6 * skill(), self)
		if role == "seller":
			HeatSystem.add(0.4, "worker")


func _process_shouter(delta: float) -> void:
	if step_move(delta) and _timer <= 0.0:
		_timer = _rng.randf_range(5.0, 9.0) / skill()
		avatar.shout(1.2)
		say(Lines.pick(["Hello chicken nugget!", "Lookee lookee!", "Very good very nice! Over there!", "Best stall on the beach!"], _rng), "shout", 1.6)
		AudioManager.say("hello", float(data.appearance.get("voice_pitch", 1.0)), "worker%d" % int(data.get("id", 0)), -9.0)
		beach.broadcast_shout(position, 240.0 * skill(), 0.7 * skill(), self)
		HeatSystem.add(0.3, "worker")
		# Wander somewhere near the boss's stall.
		var anchor: Vector2 = beach.vendor.stall.position if beach.vendor.stall.is_open() else beach.vendor.position
		walk_to(beach.random_sand_point(anchor.x, 350.0))


func _process_lookout(delta: float) -> void:
	step_move(delta)
	if _timer > 0.0:
		return
	_timer = 0.5
	# Drift along with the boss.
	if absf(beach.vendor.position.x - position.x) > 350.0 and not moving:
		walk_to(Vector2(clampf(beach.vendor.position.x + _rng.randf_range(-150, 150), 80, BeachBackdrop.WORLD_W - 80), BeachBackdrop.PROM_Y + 30.0))
	for cop in beach.police:
		if cop.warned or not cop.is_chasing():
			continue
		if cop.target_stall == null or cop.target_stall.owner_kind != "player":
			continue
		if cop.position.distance_to(position) < 420.0 * skill():
			cop.warned = true
			avatar.shout(1.0)
			say("¡POLICÍA! ¡POLICÍA!", "bad", 1.8)
			AudioManager.say("policia", float(data.appearance.get("voice_pitch", 1.0)), "worker%d" % int(data.get("id", 0)))
			cop.distract(1.5 + 1.5 * skill())
			GameManager.notify(Lines.fmt(Lines.pick(Lines.LOOKOUT_WARN), {"name": data.get("name", "Lookout")}), "warning")


func _process_runner(delta: float) -> void:
	if moving:
		if step_move(delta) and _away:
			_away = false
			_restock()
			walk_to(beach.random_sand_point(beach.vendor.position.x, 250.0))
		return
	if _timer > 0.0:
		return
	_timer = 4.0
	if Economy.total_stock() < Economy.max_stock() * 0.3 and Economy.space_left() > 5:
		# Off to the van on the promenade.
		_away = true
		walk_to(Vector2(position.x, BeachBackdrop.PROM_Y + 70.0))
		say("Back soon, boss! Very good very nice!", "normal", 1.6)


func _restock() -> void:
	var fee := 1.0 if Upgrades.level("van") >= 2 else 1.15
	var ids := Economy.inventory.keys()
	var best := Economy.best_seller_today()
	if best == "" and not ids.is_empty():
		best = ids.pick_random()
	if best == "":
		best = "sunglasses"
	var qty := int(12 * skill())
	var got := Economy.buy_stock(best, qty, fee)
	if got > 0:
		say("Very good very nice! +%d" % got, "sale", 1.6)
		GameManager.notify(Lines.fmt(Lines.RUNNER_RESTOCK, {"name": data.get("name", "Runner"), "qty": got, "item": ItemDB.item_name(best)}), "good")
	else:
		say("No money, boss!", "bad", 1.6)
	_timer = 20.0


## Rival: the player shouted nearby.
func heckled() -> void:
	if role != "rival":
		return
	rival_patience -= 1
	say(["Hey! My customers!", "Okay okay!", "Not fair, chicken nugget!", "You win today!"][clampi(4 - rival_patience, 0, 3)], "bad", 1.4)
	if rival_patience <= 0:
		leave_beach(true)


## A cop reached this worker's blanket.
func busted() -> void:
	if stall:
		stall.close()
	say("¡Ay! Okay okay!", "bad", 2.0)


func leave_beach(beaten := false) -> void:
	if stall:
		stall.close()
		beach.unregister_stall(stall)
		stall.queue_free()
		stall = null
	if beaten:
		GameManager.notify("The rival packs up and leaves! Very good very nice!", "good")
		beach.fx.hearts(position)
	role = "leaving"
	set_process(true)
	walk_to(beach.exit_point(position))
	var tw := create_tween()
	tw.tween_interval(8.0)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if role == "leaving":
		step_move(delta)
