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
@export var player_colour: Color = Color(1.0, 0.35, 0.35)
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
var touch: TouchControls
var pause_menu: PauseMenu
var player: Contestant

var _net: Node
var _contestants: Array[Contestant] = []
var _spawn_points: Array[Vector3] = []
var _coins: Dictionary = {}
var _ranking_timer: float = 0.0


func _ready() -> void:
	_net = get_node_or_null("/root/NetworkManager")
	if _net != null and bool(_net.get("is_multiplayer_session")):
		mode = Mode.HOST if _net.is_host() else Mode.CLIENT
	var settings := _resolve_settings()

	course = _instantiate_scene(COURSE_SCENE_PATH) as FairgroundCourse
	if course == null:
		course = FairgroundCourse.new()
	course.name = "Course"
	add_child(course)
	course.enabled_sections = int(settings["sections"])
	course.build()
	if scenery_enabled:
		decorator = SceneryDecorator.new()
		course.add_child(decorator)
		decorator.decorate(course, coins_enabled)
		if mode != Mode.CLIENT:
			decorator.coin_collected.connect(_on_coin_collected)
	_spawn_points = course.get_spawn_positions(max_contestants)
	navigation = BotNavigation.new()
	navigation.build(course)
	items = ItemManager.new()
	items.name = "ItemManager"
	add_child(items)
	items.setup(self, course, bool(settings["items"]))
	var tier := MobileSettings.detect() if quality < 0 else (quality as MobileSettings.Tier)
	MobileSettings.apply(tier, get_viewport(), self)

	if mode != Mode.CLIENT:
		race_manager = RaceManager.new()
		race_manager.name = "RaceManager"
		race_manager.countdown_seconds = int(settings["countdown"])
		race_manager.ranking_provider = func() -> Array: return RaceRanking.compute(_contestants, race_manager, course.checkpoint_manager)
		add_child(race_manager)
		var finish := course.get_finish_area()
		if finish == null:
			push_error("GameManager: course has no finish area.")
		else:
			race_manager.register_finish_area(finish)

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
	_connect_signals()
	items.hit.connect(_on_item_hit)
	items.item_fx.connect(_on_item_fx)
	items.picked_up.connect(_on_item_picked_up)
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
	hud.set_coins(int(_coins.get(str(player.name), 0)))
	var cm := course.checkpoint_manager
	if cm != null:
		hud.set_progress(cm.get_progress(player) + 1, cm.get_checkpoint_count())
	var holder := player.get_node_or_null("ItemHolder") as ItemHolder
	if holder != null:
		hud.set_item(holder.kind, holder.uses, "USE" if touch.visible else "E")
		touch.set_item_state(not holder.is_empty(), ItemKinds.colour_for(holder.kind))
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


func _resolve_settings() -> Dictionary:
	var s := {"sections": enabled_sections, "bots": bot_count, "difficulty": int(bot_difficulty), "countdown": countdown_seconds, "items": items_enabled}
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
		if bool(entry["bot"]) and mode != Mode.CLIENT:
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
	contestant.knocked.connect(func(_impulse: Vector3) -> void: sound.play("knock"))


func _on_player_landed(impact: float) -> void:
	if impact > 6.0:
		sound.play("land")


func on_countdown_tick(seconds_left: int) -> void:
	hud.show_countdown(seconds_left)
	sound.play("beep" if seconds_left > 0 else "go")


func on_race_started() -> void:
	hud.show_message("Race to %s's Crown!" % Branding.HERO_NAME, 2.0)


func on_contestant_finished(contestant: Contestant, place: int, time: float) -> void:
	if contestant == player:
		var text := "You finished %s in %s!" % [hud.ordinal(place), hud.format_time(time)]
		if place == 1:
			text = "%s  %s" % [Branding.WIN_MESSAGE, text]
		hud.show_message(text, 4.0)
		camera.set_orbit(true)
		sound.play("finish")
	else:
		var who := contestant.display_name if contestant != null else "Someone"
		hud.show_message("%s finished %s" % [who, hud.ordinal(place)], 2.0)


func on_contestant_fell(contestant: Contestant, fall_count: int) -> void:
	if contestant == player:
		hud.show_message("Whoops! Fall #%d" % fall_count, 1.5)
		sound.play("fall")


func on_checkpoint_reached(contestant: Contestant, index: int) -> void:
	if contestant == player:
		hud.show_message("Checkpoint %d!" % (index + 1), 1.2)
		sound.play("checkpoint")


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
	if contestant == player:
		sound.play("shamrock" if value >= 5 else "coin", randf_range(0.95, 1.1))


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
		match kind:
			ItemKinds.Kind.PIE: sound.play("splat")
			ItemKinds.Kind.ZAPPER: sound.play("zap")
	elif attacker_name == me:
		hud.show_message("You got %s with the %s!" % [victim_name, item_name], 1.5)


func _on_item_fx(_user_name: String, kind: int, origin: Vector3) -> void:
	if player == null or origin.distance_to(player.global_position) > 18.0:
		return
	match ItemKinds.mode_of(kind):
		"trap":
			sound.play("trap")
		"self":
			sound.play("bounce", 1.3)
		_:
			match kind:
				ItemKinds.Kind.ZAPPER: sound.play("zap")
				ItemKinds.Kind.CONFETTI: sound.play("boom")
				_: sound.play("whoosh")


func on_race_finished(results: Array) -> void:
	for entry in results:
		entry["coins"] = int(_coins.get(str(entry.get("name", "")), 0))
	hud.show_results(results)
	camera.set_orbit(true)
