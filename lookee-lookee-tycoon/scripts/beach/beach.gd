extends Node2D
## The beach scene: builds the world, runs the day, and referees every interaction between
## the vendor, tourists, police and workers (sales, haggling, busts and chases). Entities ask
## it questions ("where's the nearest open stall?") and report events to it.

const WORLD_W := BeachBackdrop.WORLD_W
const SAND_TOP := BeachBackdrop.SHORE_Y + 36.0
const SAND_BOTTOM := BeachBackdrop.PROM_Y - 14.0
const SEA_TOP := BeachBackdrop.HORIZON_Y + 60.0
const CHASE_TIME := 11.0
const ESCAPE_DISTANCE := 480.0
const MAX_COPS := 5

const BustedDialog := preload("res://scripts/ui/busted_dialog.gd")
const DaySummary := preload("res://scripts/ui/day_summary.gd")
const HudScene := preload("res://scenes/ui/hud.tscn")

var backdrop: BeachBackdrop
var ground: Node2D
var world: Node2D
var fx: FxLayer
var camera: CameraRig
var tint: CanvasModulate
var rain: Node2D
var hud: CanvasLayer
var vendor: Vendor
var tourists: TouristPool
var police: Array[Police] = []
var workers: Array[Worker] = []
var stalls: Array[Stall] = []
var rival: Worker

var chase_active := false
var chase_time := 0.0
var chase_cop: Police
var _bust_open := false
var _notice_timer := 0.0
var _police_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	name = "Beach"
	_build_world()
	GameManager.day_ended.connect(_on_day_ended)
	RandomEvents.event_started.connect(_on_event_started)
	RandomEvents.event_ended.connect(_on_event_ended)
	HeatSystem.level_changed.connect(_on_heat_level_changed)
	GameManager.start_day()
	_spawn_workers()
	_update_police_count(true)
	# A few early birds so the beach isn't empty at 9am.
	for i in 3:
		tourists.spawn_group(tourists._pick_type(BeachDB.get_beach(GameManager.current_beach)), -1)
	AudioManager.play_music("beach")
	var tip := GameManager.tutorial_key()
	if tip != "":
		GameManager.notify(Lines.TUTORIAL[tip], "tutorial")
	else:
		GameManager.notify("Day %d in %s. Hello chicken nugget!" % [GameManager.day, BeachDB.get_beach(GameManager.current_beach).name], "info")


func _build_world() -> void:
	backdrop = BeachBackdrop.new()
	add_child(backdrop)
	backdrop.setup(GameManager.current_beach)
	ground = Node2D.new()
	ground.name = "Ground"
	add_child(ground)
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	fx = FxLayer.new()
	add_child(fx)
	tint = CanvasModulate.new()
	add_child(tint)
	camera = CameraRig.new()
	add_child(camera)
	camera.tapped.connect(_on_tapped)
	# Scenery.
	for x in range(150, int(WORLD_W), 420):
		var palm := BeachProp.make("palm", Vector2(x + _rng.randf_range(-40, 40), BeachBackdrop.PROM_Y + 18))
		palm.flip = _rng.randf() < 0.5
		world.add_child(palm)
		world.add_child(BeachProp.make("lamp", Vector2(x + 210, BeachBackdrop.PROM_Y + 22)))
		if _rng.randf() < 0.5:
			world.add_child(BeachProp.make("bench", Vector2(x + 110, BeachBackdrop.PROM_Y + 20)))
	world.add_child(BeachProp.make("lifeguard", Vector2(WORLD_W * 0.38, SAND_TOP + 60)))
	world.add_child(BeachProp.make("sign", Vector2(WORLD_W * 0.55, SAND_BOTTOM - 6)))
	world.add_child(BeachProp.make("bin", Vector2(WORLD_W * 0.2, SAND_BOTTOM - 4)))
	world.add_child(BeachProp.make("bin", Vector2(WORLD_W * 0.8, SAND_BOTTOM - 4)))
	var umbrella_cols := [Color("#e53935"), Color("#1e88e5"), Color("#43a047"), Color("#fdd835"), Color("#8e24aa")]
	for i in 9:
		var p := Vector2(_rng.randf_range(120, WORLD_W - 120), _rng.randf_range(SAND_TOP + 40, SAND_BOTTOM - 80))
		world.add_child(BeachProp.make("umbrella", p, umbrella_cols[i % umbrella_cols.size()], Color.WHITE))
	# The player.
	vendor = Vendor.new()
	vendor.beach = self
	vendor.position = Vector2(WORLD_W * 0.5, (SAND_TOP + SAND_BOTTOM) * 0.5)
	world.add_child(vendor)
	var s := Stall.new()
	s.owner_kind = "player"
	s.owner_node = vendor
	world.add_child(s)
	vendor.stall = s
	register_stall(s)
	camera.position = vendor.position + Vector2(0, -200)
	camera.zoom = Vector2(0.8, 0.8)
	camera._apply_limits()
	tourists = TouristPool.new()
	tourists.beach = self
	add_child(tourists)
	# Rain overlay in screen space, under the HUD.
	var rain_layer := CanvasLayer.new()
	rain_layer.layer = 2
	add_child(rain_layer)
	rain = Node2D.new()
	rain.visible = false
	rain.draw.connect(_draw_rain)
	rain_layer.add_child(rain)
	hud = HudScene.instantiate()
	hud.beach = self
	add_child(hud)
	_apply_tint()


func _process(delta: float) -> void:
	HeatSystem.player_exposed = vendor.stall.is_open()
	_apply_tint()
	if rain.visible:
		rain.queue_redraw()
	_notice_timer -= delta
	if _notice_timer <= 0.0:
		_notice_timer = 0.5
		_stalls_attract()
	_police_timer -= delta
	if _police_timer <= 0.0:
		_police_timer = 2.0
		_update_police_count(false)
	if chase_active:
		_process_chase(delta)


# --- Geometry helpers used by the entities ---------------------------------------------------

func clamp_to_sand(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 50.0, WORLD_W - 50.0), clampf(p.y, SAND_TOP + 10.0, SAND_BOTTOM - 30.0))


## Anywhere you can walk: sand and promenade (not the sea).
func clamp_to_land(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 40.0, WORLD_W - 40.0), clampf(p.y, SAND_TOP, BeachBackdrop.WORLD_H - 20.0))


func can_set_up_at(p: Vector2) -> bool:
	return p.y >= SAND_TOP and p.y <= SAND_BOTTOM - 40.0


func random_sand_point(near_x: float, spread: float) -> Vector2:
	return clamp_to_sand(Vector2(near_x + _rng.randf_range(-spread, spread), _rng.randf_range(SAND_TOP + 20.0, SAND_BOTTOM - 40.0)))


func random_sea_point(near_x: float) -> Vector2:
	return Vector2(clampf(near_x + _rng.randf_range(-150, 150), 60, WORLD_W - 60), _rng.randf_range(SEA_TOP + 40.0, BeachBackdrop.SHORE_Y - 10.0))


func entry_point() -> Vector2:
	if _rng.randf() < 0.75:
		return Vector2(_rng.randf_range(80, WORLD_W - 80), BeachBackdrop.WORLD_H - 10.0)
	return Vector2(-40.0 if _rng.randf() < 0.5 else WORLD_W + 40.0, _rng.randf_range(BeachBackdrop.PROM_Y + 20, BeachBackdrop.WORLD_H - 20))


func exit_point(from: Vector2) -> Vector2:
	return Vector2(clampf(from.x + _rng.randf_range(-200, 200), 40, WORLD_W - 40), BeachBackdrop.WORLD_H + 30.0)


func is_on_screen(p: Vector2) -> bool:
	var half := get_viewport_rect().size / camera.zoom * 0.5
	return Rect2(camera.position - half, half * 2.0).grow(60.0).has_point(p)


# --- Stalls ----------------------------------------------------------------------------------

func register_stall(s: Stall) -> void:
	if not stalls.has(s):
		stalls.append(s)


func unregister_stall(s: Stall) -> void:
	stalls.erase(s)


func nearest_open_stall(p: Vector2, max_dist: float) -> Stall:
	var best: Stall = null
	var best_d := max_dist
	for s in stalls:
		if s.is_open() and s.owner_kind != "rival":
			var d := s.position.distance_to(p)
			if d < best_d:
				best_d = d
				best = s
	return best


## Where a tourist should shop: the player's stall is preferred, then workers', then a rival.
func best_stall_for(t: Tourist, near: Vector2) -> Stall:
	var best: Stall = null
	var best_score := -INF
	for s in stalls:
		if not s.has_free_slot():
			continue
		var d := s.position.distance_to(t.position)
		if d > 1000.0:
			continue
		var score := -d - s.position.distance_to(near) * 0.5
		match s.owner_kind:
			"player": score += 260.0
			"worker": score += 60.0
			"rival": score += 120.0 if rival_active() else -9999.0
		if score > best_score:
			best_score = score
			best = s
	return best


func rival_active() -> bool:
	return rival != null and is_instance_valid(rival) and rival.role == "rival"


func vendor_can_sell_from_bag(p: Vector2) -> bool:
	return not vendor.stall.is_open() and Economy.total_stock() > 0 and vendor.position.distance_to(p) < 450.0 \
		and vendor.state in [Vendor.State.IDLE, Vendor.State.WALKING]


func _stalls_attract() -> void:
	for s in stalls:
		if not s.is_open():
			continue
		var r := s.attraction_radius()
		for t in tourists.pool:
			if t.is_active() and t.state in [Tourist.State.WANDER, Tourist.State.ARRIVING, Tourist.State.RETURNING]:
				if t.position.distance_to(s.position) < r and _rng.randf() < 0.18:
					t.notice_stall(s)


# --- Shouting ---------------------------------------------------------------------------------

func broadcast_shout(from: Vector2, radius: float, strength: float, source: Node) -> void:
	fx.puff(from + Vector2(0, -110), 3, Color(1, 1, 0.6, 0.6))
	for t in tourists.pool:
		if t.is_active():
			t.hear_shout(from, radius, strength, source)
	if source == vendor:
		hud.show_shout_ring(from, radius)
		if rival_active() and rival.position.distance_to(from) < radius:
			rival.heckled()


# --- Selling ---------------------------------------------------------------------------------

## A tourist finished browsing at a stall.
func resolve_purchase(t: Tourist, s: Stall) -> void:
	if not s.seller_present():
		t.say("Hello? Anybody?", "think", 1.4)
		t.finish_shopping(false)
		return
	if s.owner_kind == "rival":
		# The rival sells them something. Your loss, chicken nugget!
		if _rng.randf() < 0.5:
			t.say("Ooh, cheaper!", "normal", 1.2)
			t.finish_shopping(true, ["sunglasses", "magnet", "watch"][_rng.randi() % 3])
		else:
			t.finish_shopping(false)
		return
	var item := Economy.pick_item_for(t.type_id, _rng)
	var seller: Walker = s.owner_node
	if item == "":
		seller.say(Lines.pick(Lines.NO_STOCK), "bad", 2.0)
		t.finish_shopping(false)
		return
	var bonus := Upgrades.sale_bonus() if s.owner_kind == "player" else 0.05 * (seller as Worker).skill()
	_try_sell(t, seller, item, bonus, s.owner_kind == "player", s.position)


## A tourist reached the vendor (or the vendor reached them) away from the stall.
func resolve_bag_purchase(t: Tourist) -> void:
	var item := Economy.pick_item_for(t.type_id, _rng)
	if item == "":
		vendor.say(Lines.pick(Lines.NO_STOCK), "bad", 2.0)
		t.finish_shopping(false)
		return
	vendor.face(t.position)
	vendor.avatar.present(1.0)
	vendor.say(Lines.fmt(Lines.pick(Lines.PITCH), {"item": ItemDB.item_name(item)}), "shout", 1.8)
	HeatSystem.add(1.5, "pitch")
	# Selling from the bag is a little harder than from a nice stall.
	_try_sell(t, vendor, item, Upgrades.sale_bonus() * 0.6 - 0.05, true, vendor.position)


## Called by the vendor when they reach a tourist they tapped.
func vendor_pitch(t: Node2D) -> void:
	var tourist := t as Tourist
	if tourist == null or not tourist.is_active() or not tourist.can_be_pitched():
		vendor.say("Ah, never mind, chicken nugget!", "normal", 1.2)
		return
	tourist.listen_pitch()


func _try_sell(t: Tourist, seller: Walker, item: String, bonus: float, is_player: bool, where: Vector2) -> void:
	var chance := Economy.sale_chance(item, t.type_id, t.budget, t.mood_buy(), bonus)
	if _rng.randf() < chance:
		_complete_sale(t, seller, item, Economy.sale_price(item), is_player, where)
		return
	# Missed sale: maybe they haggle.
	var price := Economy.sale_price(item)
	var cost := Economy.wholesale_price(item)
	if _rng.randf() < 0.45 and chance > 0.08:
		var offer := snappedf(price * _rng.randf_range(0.45, 0.8), 0.5 if price >= 3.0 else 0.1)
		offer = maxf(offer, 0.5)
		t.say(Lines.fmt(Lines.pick(Lines.TOURIST_HAGGLE, _rng), {"price": Lines.money(offer)}), "normal", 4.0)
		if is_player and not hud.haggle_active():
			t.start_haggle()
			hud.show_haggle(t, item, offer, seller)
		else:
			# Workers take any offer that still makes a profit.
			if offer >= cost * 1.5:
				_complete_sale(t, seller, item, offer, is_player, where)
			else:
				t.finish_shopping(false)
		return
	t.say(Lines.pick(Lines.TOURIST_NO, _rng), "normal", 1.6)
	if is_player and seller == vendor and _rng.randf() < 0.4:
		vendor.say(Lines.pick(Lines.SALE_FAIL), "normal", 1.4)
	t.finish_shopping(false)


## The HUD's haggle popup answered.
func haggle_result(t: Tourist, item: String, offer: float, seller: Walker, accepted: bool) -> void:
	if not is_instance_valid(t) or not t.is_active():
		return
	if accepted and Economy.count(item) > 0:
		_complete_sale(t, seller, item, offer, true, seller.position)
	else:
		t.say(Lines.pick(Lines.TOURIST_NO, _rng), "normal", 1.4)
		t.finish_shopping(false)


func _complete_sale(t: Tourist, seller: Walker, item: String, price: float, is_player: bool, where: Vector2) -> void:
	if not Economy.complete_sale(item, price, where):
		t.finish_shopping(false)
		return
	var line := Lines.fmt(Lines.pick(Lines.SALE, _rng), {"item": ItemDB.item_name(item), "price": Lines.money(price)})
	seller.say(line, "sale", 1.8)
	seller.avatar.present(0.8)
	t.say(Lines.pick(Lines.TOURIST_BUY, _rng), "normal", 1.4)
	fx.coins(t.position, price)
	AudioManager.play_sfx("coin")
	var pitch := CharacterData.voice_pitch() if seller == vendor else float((seller as Worker).data.appearance.get("voice_pitch", 1.0))
	AudioManager.say("very_good", pitch, "player" if seller == vendor else "worker", 0.0 if is_player else -8.0)
	t.finish_shopping(true, item)
	if is_player:
		HeatSystem.add(2.6 + 0.7 * Upgrades.stall_tier(), "sale")
		GameManager.tutorial_event("sell")
		if HeatSystem.heat > 25.0:
			GameManager.tutorial_event("heat")
	else:
		HeatSystem.add(1.0, "worker sale")
	if Economy.total_stock() < 6 and Economy.total_stock() >= 0 and is_player:
		GameManager.tutorial_event("pack")
		if Economy.total_stock() == 0:
			GameManager.notify(Lines.pick(Lines.NO_STOCK), "warning")


# --- Police ----------------------------------------------------------------------------------

func _desired_cops() -> int:
	var b := BeachDB.get_beach(GameManager.current_beach)
	var n := 1
	if float(b.police) >= 1.3:
		n += 1
	if HeatSystem.level >= HeatSystem.Level.SUSPICIOUS:
		n += 1
	if HeatSystem.level >= HeatSystem.Level.RAID:
		n += 1
	n += int(RandomEvents.add("police"))
	if GameManager.hour >= 20.5:
		n = 0
	return mini(n, MAX_COPS)


func _update_police_count(initial: bool) -> void:
	var want := _desired_cops()
	var have := police.filter(func(c): return c.state != Police.State.LEAVE).size()
	while have < want:
		var cop := Police.new()
		cop.beach = self
		var side := _rng.randf() < 0.5
		cop.position = Vector2(_rng.randf_range(200, WORLD_W - 200) if initial else (-40.0 if side else WORLD_W + 40.0), BeachBackdrop.PROM_Y + 50.0)
		world.add_child(cop)
		cop.reached_stall.connect(_on_cop_reached_stall)
		cop.caught_vendor.connect(_on_cop_caught_vendor)
		police.append(cop)
		have += 1
	if have > want:
		for cop in police:
			if have <= want:
				break
			if cop.state == Police.State.PATROL:
				cop.leave_beach()
				have -= 1


func remove_cop(cop: Police) -> void:
	police.erase(cop)
	cop.queue_free()


func _on_heat_level_changed(level: int, previous: int) -> void:
	if level <= previous:
		return
	if level >= HeatSystem.Level.WANTED:
		_dispatch_police(level >= HeatSystem.Level.RAID)
	if level >= HeatSystem.Level.SUSPICIOUS:
		AudioManager.play_sfx("siren", 0.0, -12.0 if level < HeatSystem.Level.RAID else -4.0)


## Send the nearest free cop (or all of them, in a raid) after the player's stall.
func _dispatch_police(all: bool) -> void:
	if not vendor.stall.is_open():
		return
	var sorted := police.duplicate()
	sorted.sort_custom(func(a, b): return a.position.distance_to(vendor.stall.position) < b.position.distance_to(vendor.stall.position))
	for cop in sorted:
		if cop.state in [Police.State.PATROL, Police.State.RETURN, Police.State.INVESTIGATE]:
			cop.chase_stall(vendor.stall)
			if not all:
				break


func on_police_coming(_cop: Police) -> void:
	hud.police_warning(true)
	GameManager.tutorial_event("heat")


func any_cop_chasing_player() -> bool:
	for cop in police:
		if cop.state in [Police.State.CHASE_STALL, Police.State.INVESTIGATE, Police.State.DISTRACTED] and cop.target_stall == vendor.stall:
			return true
		if cop.state == Police.State.CHASE_VENDOR:
			return true
	return false


func _on_cop_reached_stall(cop: Police, s: Stall) -> void:
	if s.owner_kind != "player":
		_bust_worker(cop, s)
		return
	if not s.is_open() and s.state != Stall.State.PACKING:
		cop.finish(6.0)
		return
	if _bust_open or chase_active:
		cop.finish(4.0)
		return
	# Caught with the stall open (or still packing): decide your fate.
	s.cancel_packing()
	if vendor.state == Vendor.State.PACKING:
		vendor.set_state(Vendor.State.IDLE)
	_bust_open = true
	cop.face(vendor.position)
	AudioManager.play_sfx("busted")
	Economy.lifetime.busts += 1
	var dlg := BustedDialog.new()
	dlg.beach = self
	dlg.cop = cop
	add_child(dlg)


func _bust_worker(cop: Police, s: Stall) -> void:
	var w := s.owner_node as Worker
	var strict := float(BeachDB.get_beach(GameManager.current_beach).police)
	var fine := roundf(12.0 * strict)
	var lost := Economy.confiscate(0.05)
	Economy.force_spend(fine, "fine")
	if w:
		w.busted()
	cop.say("Caught one! Very good... for me.", "police", 2.0)
	GameManager.notify("%s got caught! Fine %s, %d items taken. Not very good, not very nice." % [w.data.get("name", "Your worker") if w else "Your worker", Lines.money(fine), lost], "bad")
	AudioManager.play_sfx("bad_event")
	cop.finish(15.0)


## Costs and odds shown in the Busted dialog.
func bust_terms() -> Dictionary:
	var strict := float(BeachDB.get_beach(GameManager.current_beach).police)
	var scale := strict * (1.0 + GameManager.day * 0.03)
	return {
		"bribe": roundf((14.0 + HeatSystem.heat * 0.5) * scale),
		"bribe_chance": clampf(0.55 + Upgrades.bribe_bonus() - (strict - 1.0) * 0.25 - HeatSystem.heat * 0.002, 0.15, 0.92),
		"fine": roundf(25.0 * scale),
		"fine_confiscate": 0.25,
		"run_drop": 0.15,
	}


## The player picked an option in the Busted dialog.
func bust_choice(choice: String, cop: Police) -> void:
	_bust_open = false
	var terms := bust_terms()
	match choice:
		"bribe":
			var cost: float = terms.bribe
			if Economy.can_afford(cost) and _rng.randf() < float(terms.bribe_chance):
				Economy.spend(cost, "bribe")
				cop.say(Lines.pick(Lines.POLICE_BRIBE_OK, _rng), "police", 2.6)
				HeatSystem.set_heat(maxf(HeatSystem.heat - 40.0, 5.0))
				GameManager.notify("Bribe accepted (%s). Very good very nice... very expensive." % Lines.money(cost), "good")
				AudioManager.play_sfx("coin")
				cop.finish(20.0)
			else:
				var fine: float = terms.fine * 1.6
				Economy.force_spend(fine, "fine")
				var lost := Economy.confiscate(0.4)
				vendor.stall.close()
				cop.say(Lines.pick(Lines.POLICE_BRIBE_FAIL, _rng), "police", 2.6)
				HeatSystem.set_heat(20.0)
				GameManager.notify("Bribe refused! Fine %s and %d items taken. Not very good, not very nice!" % [Lines.money(fine), lost], "bad")
				AudioManager.play_sfx("busted")
				cop.finish(20.0)
		"fine":
			var fine: float = terms.fine
			Economy.force_spend(fine, "fine")
			var lost := Economy.confiscate(float(terms.fine_confiscate))
			vendor.stall.close()
			cop.say("Fine paid. Now go, chicken nugget.", "police", 2.4)
			HeatSystem.set_heat(15.0)
			Economy.lifetime.fines += fine
			GameManager.notify("Fined %s and %d items confiscated. Tomorrow, very good very nice!" % [Lines.money(fine), lost], "bad")
			cop.finish(20.0)
		_:
			_start_chase(cop, float(terms.run_drop))
	hud.police_warning(any_cop_chasing_player())


# --- Chase -----------------------------------------------------------------------------------

func _start_chase(cop: Police, drop: float) -> void:
	var lost := Economy.confiscate(drop)
	vendor.stall.close()
	fx.puff(vendor.stall.position, 12)
	vendor.start_running()
	vendor.say("LEG IT! Very good very fast!", "shout", 1.6)
	# Head start: the vendor bolts away from the cop.
	var away := (vendor.position - cop.position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	vendor.command_walk(vendor.position + away * 400.0)
	cop.chase_vendor()
	chase_cop = cop
	chase_active = true
	chase_time = 0.0
	camera.follow = vendor
	AudioManager.play_music("chase")
	AudioManager.play_sfx("siren")
	hud.show_chase(true)
	if lost > 0:
		GameManager.notify("You dropped %d items running away! Tap to steer, chicken nugget!" % lost, "warning")
	else:
		GameManager.notify("Tap where to run! Very good very fast!", "warning")


func _process_chase(delta: float) -> void:
	chase_time += delta
	hud.update_chase(chase_time / CHASE_TIME, vendor.position.distance_to(chase_cop.position) / ESCAPE_DISTANCE)
	if chase_time >= CHASE_TIME or vendor.position.distance_to(chase_cop.position) >= ESCAPE_DISTANCE:
		_end_chase(true)


func _on_cop_caught_vendor(cop: Police) -> void:
	if chase_active and cop == chase_cop:
		_end_chase(false)


func _end_chase(escaped: bool) -> void:
	chase_active = false
	camera.follow = null
	hud.show_chase(false)
	AudioManager.play_music("beach")
	if escaped:
		vendor.stop_running()
		vendor.avatar.set_pose(VendorAvatar.Pose.CHEER)
		get_tree().create_timer(1.2).timeout.connect(_vendor_calm_down)
		vendor.say(Lines.pick(Lines.ESCAPED), "sale", 2.4)
		HeatSystem.set_heat(maxf(HeatSystem.heat - 35.0, 10.0))
		Economy.lifetime.escapes += 1
		GameManager.notify(Lines.pick(Lines.ESCAPED), "good")
		AudioManager.play_sfx("escape")
		chase_cop.say("¡Ay! Too fast!", "police", 2.0)
	else:
		vendor.get_caught()
		var terms := bust_terms()
		var fine: float = terms.fine * 2.0
		Economy.force_spend(fine, "fine")
		var lost := Economy.confiscate(0.5)
		HeatSystem.set_heat(10.0)
		vendor.say("Okay okay! Not very good, not very nice!", "bad", 2.4)
		chase_cop.say("Gotcha, chicken nugget!", "police", 2.4)
		GameManager.notify("%s Fine %s, %d items taken." % [Lines.pick(Lines.CAUGHT), Lines.money(fine), lost], "bad")
		AudioManager.play_sfx("busted")
		get_tree().create_timer(1.5).timeout.connect(vendor.release)
	chase_cop.finish(25.0)
	chase_cop = null
	hud.police_warning(false)


func _vendor_calm_down() -> void:
	if vendor.avatar.pose == VendorAvatar.Pose.CHEER:
		vendor.avatar.set_pose(VendorAvatar.Pose.IDLE)


# --- Taps ------------------------------------------------------------------------------------

func _on_tapped(p: Vector2) -> void:
	if get_tree().paused:
		return
	if chase_active:
		vendor.command_walk(p)
		return
	var t := _tourist_at(p)
	if t:
		vendor.command_pitch(t)
		AudioManager.play_sfx("tap", 0.1, -6.0)
		return
	if vendor.stall.is_open() and vendor.stall.hit_test(p):
		vendor.command_return_to_stall()
		return
	vendor.command_walk(p)
	hud.show_tap_marker(p)


func _tourist_at(p: Vector2) -> Tourist:
	var best: Tourist = null
	var best_d := 60.0
	for t in tourists.pool:
		if not t.is_active() or not t.can_be_pitched():
			continue
		var body := t.position + Vector2(0, -50.0 * float(t.avatar.appearance.get("scale", 1.0)))
		var d := body.distance_to(p)
		if d < best_d:
			best_d = d
			best = t
	return best


# --- Workers, events, day end ------------------------------------------------------------------

func _spawn_workers() -> void:
	for d in Staff.on_beach(GameManager.current_beach):
		var w := Worker.new()
		world.add_child(w)
		w.setup(self, d, Vector2(_rng.randf_range(200, WORLD_W - 200), BeachBackdrop.WORLD_H - 20))
		workers.append(w)


func _on_event_started(id: String, def: Dictionary) -> void:
	match id:
		"cruise":
			backdrop.show_ship = true
		"rain":
			rain.visible = true
			for t in tourists.pool:
				if t.is_active() and _rng.randf() < 0.5:
					t.leave()
		"rival":
			if not rival_active():
				rival = Worker.new()
				world.add_child(rival)
				var x := clampf(vendor.position.x + (_rng.randf_range(300, 600) * (1.0 if _rng.randf() < 0.5 else -1.0)), 200, WORLD_W - 200)
				rival.setup(self, {"role": "rival", "name": "Rival", "appearance": AppearanceOptions.random_appearance(_rng)}, Vector2(x, BeachBackdrop.WORLD_H - 20))
		"coach":
			var b := BeachDB.get_beach(GameManager.current_beach)
			tourists.spawn_group(tourists._pick_type(b), 6)
		"seagull":
			fx.puff(vendor.position + Vector2(0, -60), 6, Color(1, 1, 1, 0.9))
			AudioManager.play_sfx("seagull")
	AudioManager.play_sfx("event" if bool(def.get("good", true)) else "bad_event")


func _on_event_ended(id: String) -> void:
	match id:
		"cruise":
			backdrop.show_ship = false
		"rain":
			rain.visible = false
		"rival":
			if rival_active():
				rival.leave_beach(false)
			rival = null


func _on_day_ended(summary: Dictionary) -> void:
	if chase_active:
		_end_chase(true)
	AudioManager.play_sfx("day_end")
	var dlg := DaySummary.new()
	dlg.summary = summary
	add_child(dlg)


# --- Visuals -----------------------------------------------------------------------------------

func _apply_tint() -> void:
	var h := GameManager.hour
	var c := Color.WHITE
	if h < 11.0:
		c = Color(1.0, 0.96, 0.9).lerp(Color.WHITE, (h - 9.0) / 2.0)
	elif h > 17.5:
		c = Color.WHITE.lerp(Color(1.0, 0.78, 0.62), clampf((h - 17.5) / 2.5, 0.0, 1.0))
		if h > 20.0:
			c = c.lerp(Color(0.62, 0.55, 0.78), clampf(h - 20.0, 0.0, 1.0))
	if RandomEvents.is_active("rain"):
		c = c * Color(0.78, 0.8, 0.88)
	elif RandomEvents.is_active("heatwave"):
		c = c * Color(1.0, 0.95, 0.85)
	tint.color = c


func _draw_rain() -> void:
	var size := get_viewport_rect().size
	var t := Time.get_ticks_msec() / 1000.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 140:
		var x := fmod(rng.randf() * size.x + t * 120.0, size.x)
		var y := fmod(rng.randf() * size.y + t * (700.0 + rng.randf() * 200.0), size.y)
		rain.draw_line(Vector2(x, y), Vector2(x - 6, y + 18), Color(0.85, 0.92, 1.0, 0.5), 2.0)
