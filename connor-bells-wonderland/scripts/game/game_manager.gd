class_name GameManager
extends Node3D
## Main-scene script. Modes: SOLO (offline vs bots), HOST (authoritative, runs
## everything), CLIENT (puppets driven by host state). Settings come from the
## NetworkManager autoload when present, otherwise from the exports below.
## Adds touch controls, a pause menu, device quality settings and the
## Fairground Mayhem items (gift boxes, held items, traps, status effects).

enum Mode { SOLO, HOST, CLIENT }

const COURSE_SCENE_PATH := "res://scenes/course/fairground_course.tscn"
const CONTESTANT_SCENE_PATH := "res://scenes/characters/contestant.tscn"

@export_range(1, 6) var enabled_sections: int = 6
@export var player_name: String = "You"
@export var player_colour: Color = Color(0.85, 0.08, 0.12)
@export var countdown_seconds: int = 3
@export var max_contestants: int = 8
@export_range(0, 7) var bot_count: int = 7
@export var bot_difficulty: BotProfiles.Difficulty = BotProfiles.Difficulty.MEDIUM
@export var scenery_enabled: bool = true
@export var coins_enabled: bool = true
@export var music_enabled: bool = true
## Gift boxes and items. The menu/lobby "Items" switch overrides this.
@export var items_enabled: bool = true
@export var ranking_interval: float = 0.25
## -1 = auto-detect, otherwise MobileSettings.Tier (0 Low, 1 Medium, 2 High).
@export_range(-1, 2) var quality: int = -1
@export var force_touch_controls: bool = false

var mode: Mode = Mode.SOLO
var course: FairgroundCourse
var race_manager: RaceManager
var hud: HudController
var camera: CameraController
var sound: SoundManager
var decorator: SceneryDecorator
var navigation: BotNavigation
var items: ItemManager
var sync: RaceSync
## Arena modes instead of a race: the "mode" setting is "paintball" (Paintball
## Battle) or "dodgems" (Dodgem Derby). battle_kind is that, or "" for a race.
var paintball: PaintballManager
var dodgems: DodgemsManager
var battle: bool = false
var battle_kind: String = ""
## Tower Climb mode (mode "tower"): a race up a spiral obby tower.
var climb: bool = false
## Tower Climb's giant seagull from Belfast harbour.
var seagull: TowerSeagull
var touch: TouchControls
var pause_menu: PauseMenu
var player: Contestant

var _net: Node
var _contestants: Array[Contestant] = []
var _spawn_points: Array[Vector3] = []
var _coins: Dictionary = {}
var _ranking_timer: float = 0.0
var _fireworks: FireworksShow
var _present: PrizePresent
var _finale_token: int = 0


func _ready() -> void:
	_net = get_node_or_null("/root/NetworkManager")
	if _net != null and bool(_net.get("is_multiplayer_session")):
		mode = Mode.HOST if _net.is_host() else Mode.CLIENT
	var settings := _resolve_settings()
	var chosen := str(settings.get("mode", "race"))
	battle_kind = chosen if chosen in ["paintball", "dodgems"] else ""
	battle = not battle_kind.is_empty()
	climb = chosen == "tower"

	if battle_kind == "paintball":
		course = PaintballArena.new()
	elif battle_kind == "dodgems":
		course = DodgemArena.new()
	elif climb:
		course = TowerClimbCourse.new()
	else:
		course = _instantiate_scene(COURSE_SCENE_PATH) as FairgroundCourse
	if course == null:
		course = FairgroundCourse.new()
	course.name = "Course"
	add_child(course)
	course.enabled_sections = int(settings["sections"])
	course.build()
	if battle_kind == "paintball":
		paintball = PaintballManager.new()
		paintball.name = "PaintballManager"
		add_child(paintball)
		paintball.setup(self, course as PaintballArena)
	elif battle_kind == "dodgems":
		dodgems = DodgemsManager.new()
		dodgems.name = "DodgemsManager"
		add_child(dodgems)
		dodgems.setup(self, course as DodgemArena)
	elif climb:
		seagull = TowerSeagull.new()
		seagull.name = "Seagull"
		seagull.setup(self)
		add_child(seagull)
	if scenery_enabled and not battle and not climb:
		decorator = SceneryDecorator.new()
		course.add_child(decorator)
		decorator.decorate(course, coins_enabled)
		if mode != Mode.CLIENT:
			decorator.coin_collected.connect(_on_coin_collected)
	_spawn_points = course.get_spawn_positions(max_contestants)
	navigation = BotNavigation.new()
	navigation.assist_jumps = climb
	if not battle:
		navigation.build(course)
	items = ItemManager.new()
	items.name = "ItemManager"
	add_child(items)
	items.setup(self, course, bool(settings["items"]) and battle_kind != "paintball")
	var tier := MobileSettings.detect() if quality < 0 else (quality as MobileSettings.Tier)
	MobileSettings.apply(tier, get_viewport(), self)

	if mode != Mode.CLIENT:
		race_manager = RaceManager.new()
		race_manager.name = "RaceManager"
		race_manager.countdown_seconds = int(settings["countdown"])
		race_manager.ranking_provider = func() -> Array: return RaceRanking.compute(_contestants, race_manager, course.checkpoint_manager)
		add_child(race_manager)
		var finish := course.get_finish_area()
		if battle:
			race_manager.max_race_seconds = (PaintballManager.TIME_LIMIT if paintball != null else DodgemsManager.TIME_LIMIT) + 30.0
			race_manager.needs_finish_area = false
		elif finish == null:
			push_error("GameManager: course has no finish area.")
		else:
			race_manager.register_finish_area(finish)
		if climb:
			race_manager.max_race_seconds = 480.0
			race_manager.finish_grace_seconds = 45.0

	hud = HudController.new()
	hud.name = "HUD"
	add_child(hud)
	touch = TouchControls.new()
	touch.name = "TouchControls"
	touch.force_visible = force_touch_controls
	hud.add_child(touch)
	camera = CameraController.new()
	camera.name = "Camera"
	add_child(camera)
	sound = SoundManager.new()
	sound.name = "Sound"
	sound.music_enabled = music_enabled
	sound.music_track = "derby" if battle_kind == "dodgems" else "race"
	add_child(sound)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	pause_menu.pause_tree = mode == Mode.SOLO
	pause_menu.music_enabled = music_enabled
	add_child(pause_menu)
	pause_menu.music_toggled.connect(sound.set_music_enabled)
	sync = RaceSync.new()
	sync.name = "RaceSync"
	add_child(sync)
	sync.setup(self)

	_spawn_roster(RaceRoster.build(_net, settings, player_name, player_colour, max_contestants))
	if player != null:
		camera.set_target(player)
		_connect_player_sounds(player)
	if climb:
		camera.arena_mode = true
		camera.arena_swing_degrees = 55.0
		camera.distance = 9.0
		camera.height = 4.5
		if player != null:
			camera.set_target(player)
	if battle:
		camera.distance = 10.0 if paintball != null else 11.0
		camera.height = 8.5 if paintball != null else 9.5
		camera.arena_mode = true
		if player != null:
			camera.set_target(player)
		var arena_game := _arena_game()
		arena_game.eliminated.connect(_on_battle_eliminated)
		arena_game.announcement.connect(func(text: String) -> void:
			hud.show_message(text, 3.0)
			sound.play("airhorn", 1.0, -4.0))
		if mode != Mode.CLIENT:
			arena_game.battle_over.connect(func(results: Array) -> void: race_manager.end_with_results(results))
		if paintball != null:
			paintball.splatted.connect(_on_paint_splatted)
		if dodgems != null:
			dodgems.dunked.connect(_on_dunked)
			dodgems.bumped.connect(_on_bumped)
			if mode != Mode.CLIENT:
				dodgems.watch_items(items)
	_connect_signals()
	if seagull != null:
		seagull.gull_event.connect(_on_gull_event)
	items.hit.connect(_on_item_hit)
	items.item_fx.connect(_on_item_fx)
	items.picked_up.connect(_on_item_picked_up)
	items.gold_stolen.connect(_on_gold_stolen)
	if player != null:
		var my_holder := player.get_node_or_null("ItemHolder") as ItemHolder
		if my_holder != null:
			my_holder.preview_owner = true
	match mode:
		Mode.SOLO:
			start_race()
		Mode.HOST:
			sync.begin_when_clients_loaded()
		Mode.CLIENT:
			sync.report_loaded()
			hud.show_message("Connected - waiting for the host...", 5.0)


func _process(delta: float) -> void:
	if hud == null or player == null:
		return
	hud.set_time(sync.race_time if mode == Mode.CLIENT else race_manager.race_time)
	if paintball != null:
		var me := str(player.name)
		var lives := paintball.get_lives(me)
		var ammo := paintball.get_ammo(me)
		hud.set_battle("Lives: %d   Paint: %d/%d" % [lives, ammo, PaintballManager.MAX_AMMO], ammo == 0 or lives == 1,
			"Hits: %d" % paintball.get_hits(me), paintball.alive_count(), _contestants.size(), paintball.is_alive(me))
		touch.set_item_state(paintball.is_alive(me), PaintballManager.paint_colour(player))
		return
	if dodgems != null:
		var me := str(player.name)
		var lives := dodgems.get_lives(me)
		var boost := "BOOST READY [%s]" % ("JUMP" if touch.visible else "SPACE") if dodgems.boost_ready(me) else "boost charging"
		hud.set_battle("Lives: %d   %s" % [lives, boost], lives == 1,
			"Knock-offs: %d" % dodgems.get_hits(me), dodgems.alive_count(), _contestants.size(), dodgems.is_alive(me))
		_show_held_item()
		return
	hud.set_coins(int(_coins.get(str(player.name), 0)))
	var cm := course.checkpoint_manager
	if cm != null:
		hud.set_progress(cm.get_progress(player) + 1, cm.get_checkpoint_count())
	_show_held_item()
	_ranking_timer -= delta
	if _ranking_timer > 0.0:
		return
	_ranking_timer = ranking_interval
	if mode == Mode.CLIENT:
		hud.set_position(sync.ranking_names.find(str(player.name)) + 1, _contestants.size())
	else:
		var ranking := RaceRanking.compute(_contestants, race_manager, cm)
		hud.set_position(RaceRanking.position_of(player, ranking), ranking.size())
		var names: Array = []
		for c in ranking:
			names.append(str(c.name))
		sync.ranking_names = names


## The player's item slot, its touch button and any active effects.
func _show_held_item() -> void:
	var holder := player.get_node_or_null("ItemHolder") as ItemHolder
	if holder != null:
		var hint := "USE" if touch.visible else "E"
		if holder.kind == ItemKinds.Kind.CATAPULT:
			hint = "hold %s, aim, let go" % hint
		hud.set_item(holder.kind, holder.uses, hint)
		touch.set_item_state(not holder.is_empty(), ItemKinds.colour_for(holder.kind))
	hud.set_effects(_player_effects())


func _resolve_settings() -> Dictionary:
	var s := {"sections": enabled_sections, "bots": bot_count, "difficulty": int(bot_difficulty), "countdown": countdown_seconds, "items": items_enabled, "mode": "race"}
	if _net != null:
		var shared: Dictionary = _net.get("settings")
		for key in s.keys():
			if shared.has(key):
				s[key] = shared[key]
	return s


func _spawn_roster(roster: Array[Dictionary]) -> void:
	var my_id := multiplayer.get_unique_id()
	for entry in roster:
		var peer_id := int(entry["peer_id"])
		var local := peer_id == my_id and mode != Mode.CLIENT
		var c := spawn_contestant(str(entry["name"]), entry["colour"], local, entry["hat"])
		if c == null:
			continue
		if bool(entry["bot"]) and mode != Mode.CLIENT and paintball != null:
			var gunner := PaintballBot.new()
			gunner.name = "PaintballBot"
			c.add_child(gunner)
			gunner.setup(c, paintball, int(_resolve_settings()["difficulty"]))
		elif bool(entry["bot"]) and mode != Mode.CLIENT and dodgems != null:
			var driver := DodgemBot.new()
			driver.name = "DodgemBot"
			c.add_child(driver)
			driver.setup(c, dodgems, int(_resolve_settings()["difficulty"]))
		elif bool(entry["bot"]) and mode != Mode.CLIENT:
			var brain := BotController.new()
			brain.name = "BotController"
			c.add_child(brain)
			brain.setup(c, navigation, entry["profile"])
		if mode != Mode.SOLO:
			var np := NetworkPlayer.new()
			np.name = "NetworkPlayer"
			c.add_child(np)
			np.setup(c, peer_id)
		if peer_id == my_id:
			player = c


func spawn_contestant(contestant_name: String, colour: Color, local: bool, hat: Color = Color(0.1, 0.6, 0.2)) -> Contestant:
	var slot := _contestants.size()
	if slot >= max_contestants:
		push_warning("GameManager: contestant limit reached, '%s' not spawned." % contestant_name)
		return null
	var contestant := _instantiate_scene(CONTESTANT_SCENE_PATH) as Contestant
	if contestant == null:
		contestant = Contestant.new()
	contestant.name = contestant_name
	contestant.display_name = contestant_name
	contestant.body_colour = colour
	contestant.hat_colour = hat
	contestant.is_local_player = local
	var spawn := _spawn_points[slot] if slot < _spawn_points.size() else Vector3(0.0, 1.0, 0.0)
	contestant.position = spawn
	add_child(contestant)
	contestant.set_respawn_point(spawn)
	var status := StatusEffects.new()
	status.name = "StatusEffects"
	contestant.add_child(status)
	var holder := ItemHolder.new()
	holder.name = "ItemHolder"
	contestant.add_child(holder)
	if items != null:
		items.register_contestant(contestant)
	if paintball != null:
		paintball.register(contestant)
	if dodgems != null:
		dodgems.register(contestant)
	_contestants.append(contestant)
	if race_manager != null:
		race_manager.register_contestant(contestant)
	return contestant


func find_contestant(contestant_name: String) -> Contestant:
	for c in _contestants:
		if is_instance_valid(c) and str(c.name) == contestant_name:
			return c
	return null


func start_race() -> void:
	if race_manager != null:
		race_manager.start_countdown()
		hud.show_message(Branding.WELCOME_MESSAGE, 3.0)


func restart_race() -> void:
	if mode == Mode.CLIENT:
		hud.show_message("Only the host can restart the race.", 2.0)
		return
	_reset_local_state()
	for i in range(_contestants.size()):
		var c := _contestants[i]
		if is_instance_valid(c):
			c.set_respawn_point(_spawn_points[i] if i < _spawn_points.size() else Vector3(0.0, 1.0, 0.0))
			c.respawn()
	sync.broadcast_restart()
	start_race()


func client_restart() -> void:
	_reset_local_state()


func _reset_local_state() -> void:
	hud.hide_results()
	hud.clear_message()
	camera.set_orbit(false)
	if player != null:
		camera.set_target(player)
	_finale_token += 1
	if paintball != null:
		paintball.reset()
	if dodgems != null:
		dodgems.reset()
	if seagull != null:
		seagull.reset()
	if course.has_method("on_restart"):
		course.call("on_restart", _contestants)
	if _fireworks != null:
		_fireworks.stop_show()
	if is_instance_valid(_present):
		_present.queue_free()
	_coins.clear()
	if decorator != null:
		decorator.reset_coins()
	if items != null:
		items.reset()
	if course.checkpoint_manager != null:
		course.checkpoint_manager.reset_progress()


func _instantiate_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	return scene.instantiate() if scene != null else null


func _connect_signals() -> void:
	hud.restart_requested.connect(restart_race)
	if race_manager == null:
		return
	race_manager.countdown_tick.connect(on_countdown_tick)
	race_manager.race_started.connect(on_race_started)
	race_manager.contestant_finished.connect(on_contestant_finished)
	race_manager.contestant_fell.connect(on_contestant_fell)
	race_manager.race_finished.connect(on_race_finished)
	if course.checkpoint_manager != null:
		course.checkpoint_manager.checkpoint_reached.connect(on_checkpoint_reached)


func _connect_player_sounds(contestant: Contestant) -> void:
	contestant.jumped.connect(func() -> void: sound.play("jump", randf_range(0.95, 1.05)))
	contestant.landed.connect(_on_player_landed)
	contestant.knocked.connect(func(_impulse: Vector3) -> void:
		sound.play("knock")
		camera.add_shake(0.35))


const EFFECT_NAMES := {
	StatusEffects.Effect.OIL: "SLIPPY",
	StatusEffects.Effect.FAT: "STUFFED",
	StatusEffects.Effect.SMALL: "SHRUNK",
	StatusEffects.Effect.FLOAT: "FLOATING",
	StatusEffects.Effect.SPEED: "ROCKET BOOTS",
	StatusEffects.Effect.MAGNET: "MAGNET",
	StatusEffects.Effect.SHIELD: "SHIELD",
}


func _player_effects() -> Array:
	var result: Array = []
	var status := player.get_node_or_null("StatusEffects") as StatusEffects
	if status == null:
		return result
	for effect in status.active_effects():
		var good: bool = effect == StatusEffects.Effect.SPEED or effect == StatusEffects.Effect.MAGNET or effect == StatusEffects.Effect.SHIELD
		result.append([EFFECT_NAMES.get(effect, "?"), status.remaining(effect), CourseBuilder.accent(1) if good else CourseBuilder.accent(2)])
	return result


func _on_player_landed(impact: float) -> void:
	if impact > 6.0:
		sound.play("land")


func on_countdown_tick(seconds_left: int) -> void:
	hud.show_countdown(seconds_left)
	sound.play("beep" if seconds_left > 0 else "go")


func on_race_started() -> void:
	if battle:
		_arena_game().begin()
		if paintball != null:
			hud.show_message("PAINTBALL BATTLE! Last one standing wins!", 2.5)
		else:
			hud.show_message("DODGEM DERBY! Knock them into the Irish Sea!", 2.5)
		sound.play("airhorn", 1.0, -3.0)
		return
	hud.show_message("Race to %s's Crown!" % Branding.HERO_NAME, 2.0)
	if seagull != null:
		seagull.begin()


func on_contestant_finished(contestant: Contestant, place: int, time: float) -> void:
	if climb and place == 1 and contestant != null:
		# First to the top: a fireworks display over the crown straight away.
		if _fireworks == null:
			_fireworks = FireworksShow.new()
			_fireworks.name = "FinaleFireworks"
			add_child(_fireworks)
		_fireworks.spread = 16.0
		_fireworks.height = Vector2(14.0, 30.0)
		_fireworks.global_position = (course as TowerClimbCourse).crown_position()
		_fireworks.start_show(25.0, 4.0)
		sound.play("airhorn", 1.0, -2.0)
		if contestant == player:
			camera.set_finale(player)
		else:
			hud.show_message("%s CONQUERED THE TOWER!" % contestant.display_name.to_upper(), 3.0)
	if contestant != null:
		for i in range(3):
			var offset := Vector3(randf_range(-3.0, 3.0), 4.0 + float(i) * 1.5, randf_range(-3.0, 3.0))
			FX.burst(self, "fireworks", contestant.global_position + offset, Color.WHITE, 1.0)
		SoundManager.world(self, "firework", contestant.global_position + Vector3.UP * 4.0, 1.0, 3.0)
	if contestant == player:
		var text := "You finished %s in %s!" % [hud.ordinal(place), hud.format_time(time)]
		if place == 1:
			text = "%s  %s" % [Branding.WIN_MESSAGE, text]
		hud.show_message(text, 4.0)
		camera.set_orbit(true)
		sound.play("finish")
		sound.play("cheer", 1.0, -4.0)
	else:
		var who := contestant.display_name if contestant != null else "Someone"
		hud.show_message("%s finished %s" % [who, hud.ordinal(place)], 2.0)


func on_contestant_fell(contestant: Contestant, fall_count: int) -> void:
	if battle:
		return
	if contestant == player:
		hud.show_message("Whoops! Fall #%d" % fall_count, 1.5)
		sound.play("fall")


func on_checkpoint_reached(contestant: Contestant, index: int) -> void:
	if contestant == player:
		hud.show_message("Checkpoint %d!" % (index + 1), 1.2)
		sound.play("checkpoint")
		FX.burst(self, "sparkle", player.global_position + Vector3.UP * 1.0, CourseBuilder.accent(1) * 1.5, 1.5)


func on_coin_remote(coin_index: int, contestant: Contestant, value: int) -> void:
	if decorator != null and coin_index >= 0 and coin_index < decorator.get_child_count():
		var coin := decorator.get_child(coin_index) as CoinPickup
		if coin != null:
			coin.take_remote()
	if contestant != null:
		_on_coin_collected(contestant, value)


func _on_coin_collected(contestant: Contestant, value: int) -> void:
	var key := str(contestant.name)
	_coins[key] = int(_coins.get(key, 0)) + value


func _on_item_picked_up(contestant_name: String, kind: int) -> void:
	if player != null and contestant_name == str(player.name):
		hud.show_message("Got the %s!" % ItemKinds.display_name(kind), 1.5)
		sound.play("pickup")


func _on_item_hit(victim_name: String, attacker_name: String, kind: int) -> void:
	if player == null:
		return
	var me := str(player.name)
	var item_name := ItemKinds.display_name(kind)
	if victim_name == me:
		var who := attacker_name if not attacker_name.is_empty() and attacker_name != me else "Your own"
		if who == "Your own":
			hud.show_message("Oops! Your own %s got you!" % item_name, 1.8)
		else:
			hud.show_message("%s got you with the %s!" % [who, item_name], 1.8)
		camera.add_shake(0.6)
		match kind:
			ItemKinds.Kind.PIE:
				hud.splat(2.4)
			ItemKinds.Kind.ZAPPER:
				hud.flash(Color(0.5, 0.9, 1.0), 0.5)
			ItemKinds.Kind.CONFETTI, ItemKinds.Kind.CATAPULT, ItemKinds.Kind.BOXING_GLOVE, ItemKinds.Kind.SWORD:
				hud.flash(Color(1.0, 0.5, 0.2), 0.35)
	elif attacker_name == me:
		hud.show_message("You got %s with the %s!" % [victim_name, item_name], 1.5)


func _on_item_fx(_user_name: String, kind: int, origin: Vector3) -> void:
	if player == null:
		return
	var dist := origin.distance_to(player.global_position)
	if kind == ItemKinds.Kind.CONFETTI and dist < 16.0:
		camera.add_shake(clampf(1.0 - dist / 16.0, 0.0, 1.0) * 0.9)
		if dist < 7.0:
			hud.flash(Color(1.0, 0.6, 0.2), 0.4)
	elif kind == -1 and dist < 12.0:
		camera.add_shake(clampf(1.0 - dist / 12.0, 0.0, 1.0) * 0.7)


## Gold moved by an item hit or the Giant Magnet (same on every screen).
func _on_gold_stolen(from_name: String, to_name: String, amount: int) -> void:
	_coins[from_name] = maxi(int(_coins.get(from_name, 0)) - amount, 0)
	_coins[to_name] = int(_coins.get(to_name, 0)) + amount
	if player == null:
		return
	if from_name == str(player.name):
		hud.show_message("%s stole %d gold!" % [to_name, amount], 1.0)
	elif to_name == str(player.name):
		sound.play("coin", 1.2, -4.0)


func on_race_finished(results: Array) -> void:
	for entry in results:
		entry["coins"] = int(_coins.get(str(entry.get("name", "")), 0))
	camera.set_orbit(true)
	if results.is_empty():
		hud.show_results(results)
		return
	_start_finale(results)


## Everyone's done: a big fireworks display over the winner, a drumroll, and the
## winner's ridiculous prize bursts out of a present. Then the results.
func _start_finale(results: Array) -> void:
	_finale_token += 1
	var token := _finale_token
	var top: Dictionary = results[0]
	var winner := find_contestant(str(top.get("name", "")))
	var focus: Node3D = winner if winner != null else player
	var display := winner.display_name if winner != null else str(top.get("name", "Someone"))
	if focus != null:
		camera.set_finale(focus)
		if _fireworks == null:
			_fireworks = FireworksShow.new()
			_fireworks.name = "FinaleFireworks"
			_fireworks.spread = 12.0
			_fireworks.height = Vector2(18.0, 30.0)
			add_child(_fireworks)
		_fireworks.global_position = focus.global_position
		_fireworks.start_show(15.0, 3.0)
		_present = PrizePresent.new()
		_present.name = "PrizePresent"
		_present.target = focus
		add_child(_present)
	var prize := Prizes.pick("%s|%.2f|%d" % [str(top.get("name", "")), float(top.get("time", 0.0)), results.size()])
	var subline := ""
	var lead := "%s WON..." % display.to_upper()
	if winner != null and winner == player:
		lead = "%s, YOU WON..." % display.to_upper()
	if paintball != null:
		prize = Prizes.BATTLE_PRIZE
		subline = Prizes.BATTLE_PRIZE_DETAIL
		lead = "LAST ONE STANDING: %s! %s" % [display.to_upper(), "YOU WIN..." if winner == player else "THEY WIN..."]
	elif climb:
		prize = Prizes.pick_tower("%s|%.2f|%d" % [str(top.get("name", "")), float(top.get("time", 0.0)), results.size()])
		lead = "FIRST TO THE TOP: %s! %s" % [display.to_upper(), "YOU WIN..." if winner == player else "THEY WIN..."]
		if not bool(top.get("finished", false)):
			lead = "NOBODY MADE IT TO THE TOP! BOOBY PRIZE FOR %s..." % display.to_upper()
	elif dodgems != null:
		prize = Prizes.pick_derby("%s|%.2f|%d" % [str(top.get("name", "")), float(top.get("time", 0.0)), results.size()])
		lead = "LAST DODGEM DRIVING: %s! %s" % [display.to_upper(), "YOU WIN..." if winner == player else "THEY WIN..."]
	elif not bool(top.get("finished", false)):
		lead = "NOBODY FINISHED! BOOBY PRIZE FOR %s..." % display.to_upper()
	sound.play("drumroll")
	var titles := {"paintball": "PAINTBALL BATTLE RESULTS", "dodgems": "DODGEM DERBY RESULTS"}
	hud.set_results_title("TOWER CLIMB RESULTS" if climb else titles.get(battle_kind, Branding.RESULTS_TITLE))
	hud.show_prize(lead, prize + "!", 2.2, subline, func() -> void:
		if is_instance_valid(_present):
			_present.pop()
		sound.play("tada")
		sound.play("airhorn", 1.0, -2.0)
		sound.play("cheer", 1.0, -2.0)
		camera.add_shake(0.35))
	get_tree().create_timer(6.5, false).timeout.connect(func() -> void:
		if token != _finale_token:
			return
		hud.hide_prize_banner()
		hud.show_results(results))


func _on_paint_splatted(victim_name: String, shooter_name: String, lives: int) -> void:
	if player == null:
		return
	var me := str(player.name)
	if victim_name == me:
		var shooter := find_contestant(shooter_name)
		hud.splat(1.8, PaintballManager.paint_colour(shooter), 6)
		camera.add_shake(0.45)
		if lives > 0:
			hud.show_message("%s splatted you! %d %s left" % [shooter_name, lives, "life" if lives == 1 else "lives"], 1.5)
	elif shooter_name == me:
		sound.play("coin", 1.4, -6.0)
		hud.show_message("Splat! You got %s" % victim_name, 1.0)


## The manager running the arena mode (PaintballManager or DodgemsManager).
func _arena_game() -> Node:
	return paintball if paintball != null else dodgems


func _on_battle_eliminated(victim_name: String, by_name: String, remaining: int) -> void:
	if player == null:
		return
	var me := str(player.name)
	var arena_game := _arena_game()
	if victim_name == me:
		if dodgems != null:
			var into_sea := "%s sent you into the Irish Sea" % by_name if not by_name.is_empty() else "Into the Irish Sea"
			hud.show_message("YOU'RE OUT! %s. Spectating..." % into_sea, 3.0)
		else:
			hud.show_message("YOU'RE OUT! %s got you. Spectating..." % by_name, 3.0)
		sound.play("fall")
		var alive: Array = arena_game.alive_contestants()
		if not alive.is_empty():
			camera.set_target(alive[0])
	else:
		var who := "You" if by_name == me else by_name
		if dodgems != null:
			if by_name.is_empty():
				hud.show_message("%s is OUT - swallowed by the Irish Sea! %d left" % [victim_name, remaining], 2.0)
			else:
				hud.show_message("%s knocked %s out into the Irish Sea! %d left" % [who, victim_name, remaining], 2.0)
		else:
			hud.show_message("%s knocked out %s! %d left" % [who, victim_name, remaining], 2.0)
		# Keep spectating someone who's still in.
		if not arena_game.is_alive(me) and camera.get_target() == find_contestant(victim_name):
			var alive: Array = arena_game.alive_contestants()
			if not alive.is_empty():
				camera.set_target(alive[0])


## Dodgem Derby: someone went in the sea but has lives left.
func _on_dunked(victim_name: String, by_name: String, lives: int) -> void:
	if player == null:
		return
	var me := str(player.name)
	var left := "%d %s left" % [lives, "life" if lives == 1 else "lives"]
	if victim_name == me:
		hud.flash(Color(0.3, 0.6, 1.0), 0.5)
		if by_name.is_empty():
			hud.show_message("SPLASH! Into the Irish Sea! %s" % left, 2.0)
		else:
			hud.show_message("SPLASH! %s rammed you into the Irish Sea! %s" % [by_name, left], 2.0)
	elif by_name == me:
		sound.play("coin", 1.4, -4.0)
		hud.show_message("SPLASH! You sent %s into the Irish Sea!" % victim_name, 1.5)
	else:
		var who := by_name if not by_name.is_empty() else "The Irish Sea"
		hud.show_message("%s dunked %s!" % [who, victim_name] if not by_name.is_empty() else "%s took %s!" % [who, victim_name], 1.2)


## Dodgem Derby: big hits near you shake the camera.
func _on_bumped(rammer_name: String, victim_name: String, strength: float) -> void:
	if player == null:
		return
	var me := str(player.name)
	if rammer_name == me or victim_name == me:
		camera.add_shake(clampf(strength / 14.0, 0.15, 0.7))


## Tower Climb: what the Belfast seagull is up to.
func _on_gull_event(event: String, target_name: String, detail: String) -> void:
	var target := find_contestant(target_name)
	var mine := player != null and target == player
	var who := target.display_name if target != null else target_name
	match event:
		"arrive":
			hud.show_message("A GIANT SEAGULL IS COMING FROM BELFAST HARBOUR!", 3.0)
			sound.play("squawk", 0.9, -2.0)
		"warn":
			if mine:
				hud.show_message("SEAGULL INCOMING! LEG IT!", 1.4)
				sound.play("squawk", 1.05, -4.0)
		"hit":
			if mine:
				camera.add_shake(0.7)
				if detail.is_empty():
					hud.show_message("THE BELFAST SEAGULL GOT YOU!", 2.0)
				else:
					hud.show_message("THE SEAGULL GOT YOU AND NICKED YOUR %s!" % detail.to_upper(), 2.4)
			elif detail.is_empty():
				hud.show_message("The seagull got %s!" % who, 1.5)
			else:
				hud.show_message("The seagull nicked %s's %s!" % [who, detail], 1.8)
		"miss":
			if mine:
				hud.show_message("DODGED THE SEAGULL!", 1.4)
		"blocked":
			if mine:
				hud.show_message("BOP! Your shield smacked the seagull on the beak!", 1.8)
		"poo":
			if mine:
				hud.splat(1.6, Color(0.95, 0.95, 0.9), 7)
				hud.show_message("SPLAT! Seagull poo!", 1.5)
