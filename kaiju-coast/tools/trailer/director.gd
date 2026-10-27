extends Node
## Films one shot of the Kaiju Coast trailer inside the game, with Godot's Movie Maker.
## record.sh runs it once per shot, then assemble.py cuts the shots together with title cards
## and the game's music. Usage:
##
##   godot --path . --resolution 1920x1080 --write-movie shot.avi --fixed-fps 30 \
##       res://tools/trailer/director.tscn -- <shot>
##
## Every shot starts with WARMUP frames (the scene settling) that assemble.py trims off. During
## the warmup `t` is negative, so a shot can start things early (jets take a while to arrive).

const FPS := 30
const WARMUP := 45
const SEED := 20261027
const DURATION := {
	"reveal": 6.5, "wade": 4.5, "build": 4.5, "gunner": 5.5, "rockets": 4.5, "airship": 5.0,
	"airstrike": 4.0, "storm": 4.5, "flood": 4.0, "rampage": 5.0, "orochi": 7.0, "finale": 9.5,
}

var shot := ""
var frame := 0
var main: Main
var cam: Camera3D
var ready_done := false
var data := {}


func _ready() -> void:
	shot = OS.get_cmdline_user_args()[0]
	Game.save_path = "user://trailer_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func _process(_delta: float) -> void:
	frame += 1
	if frame < 3:
		return
	var t := float(frame - WARMUP) / FPS
	if not ready_done:
		ready_done = true
		seed(SEED)
		cam = Game.rig.cam
		Game.hud.film = true
		Settings.set_v("tutorial", false)
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
		call("_setup_" + shot)
	call("_shot_" + shot, t)
	# The city never falls on film.
	if Game.state == Game.State.PLAY:
		Game.city = maxf(Game.city, 60.0)
	Game.hurt = 0.0
	if frame >= WARMUP + int(DURATION[shot] * FPS):
		get_tree().quit()


# --- Helpers ---------------------------------------------------------------------------------

## A game in progress, with guns on the listed rings ([pad, type, level, path]), no wave timer
## and every special unlocked. Shots keep the guns few so the action stays readable.
func _battle(guns: Array = []) -> void:
	Game.new_game()
	Game.tutorial.skip()
	Game.voice.reset()
	Game.funds = 999999
	Game.wave = 6
	Game.hp_mul = 1.0
	Game.countdown = 1.0e9
	Game.phase = "build"
	Game.world.set_weather("clear")
	Game.abilities._announced = 99   # no "new weapon" banners on film
	for p: Array in guns:
		var tu: Turret = main.build_turret(Game.pads[p[0]], p[1])
		while tu.lvl < int(p[2]):
			tu.level_up(p[3] if tu.lvl == 2 else "")
	Game.zep.lvl = {"bomb": 0, "armor": 2, "pods": 0}
	Game.rig.set_mode("free")


const FEW := [[1, "rocket", 2, ""], [3, "cannon", 2, ""], [5, "rail", 3, "a"], [8, "flak", 2, ""], [11, "tesla", 2, ""]]


func _spawn(type: String, pos: Vector3, hp := 1.0e5) -> Kaiju:
	var k: Kaiju = main.spawn_kaiju(type)
	k.position = pos
	if not k.def["air"]:
		k.position.y = -Game.depth_at(pos.z)
	k.target_x = pos.x
	k.hp = hp
	k.max_hp = maxf(hp, 3000.0)
	k.pose(0.0)
	k.refresh_hits()
	return k


func _look(pos: Vector3, at: Vector3, fov := 60.0) -> void:
	var xf := Transform3D(Basis(), pos).looking_at(at, Vector3.UP)
	if Game.shake > 0.01:
		var s: float = Game.shake * 0.9
		xf.origin += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	Game.shake = maxf(0.0, Game.shake - 0.1)
	cam.global_transform = xf
	cam.fov = fov


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## First person: point the gun at `p`.
func _aim(p: Vector3) -> void:
	var pl: Player = Game.player
	var d := p - pl.seat_pos()
	pl.yaw = Game.yaw_to(d.x, d.z)
	pl.pitch = atan2(d.y, Vector2(d.x, d.z).length())


func _eye(k: Kaiju) -> Variant:
	for h: Dictionary in k.hits:
		if h["weak"]:
			return h["p"]
	return null


func _alive(k: Variant) -> bool:
	return k != null and is_instance_valid(k) and not (k as Kaiju).dying


# --- Shots -----------------------------------------------------------------------------------

## Kaiju wade in under the blood moon; the camera rises from the surf as an Onigami wades
## straight into the torii and knocks it flat.
func _setup_reveal() -> void:
	_battle()
	data["k"] = [_spawn("oni", Vector3(World.TORII_AT.x, 0, -165)), _spawn("ryu", Vector3(110, 0, -270)),
		_spawn("kani", Vector3(-190, 0, -320)), _spawn("daioni", Vector3(30, 0, -450)),
		_spawn("tengu", Vector3(-40, 110, -240))]


func _shot_reveal(t: float) -> void:
	var f := _ease(t / 6.5)
	_look(Vector3(-10.0 + f * 20.0, 3.0 + f * 30.0, -20.0 + f * 20.0), Vector3(0, 38.0 + f * 6.0, -380), 60.0)


## An Onigami strides past right over the camera.
func _setup_wade() -> void:
	_battle()
	data["k"] = _spawn("oni", Vector3(30, 0, -170))
	(data["k"] as Kaiju).target_x = -10.0
	Game.zep.ang = 0.0   # the airship off to the east, behind the camera


func _shot_wade(t: float) -> void:
	Game.zep.ang = 0.0
	var k: Kaiju = data["k"]
	var f := _ease(t / 4.5)
	if t > 1.2 and not data.has("roar"):
		data["roar"] = true
		k.roar_t = 2.0
		Game.sfx.play_at("roar", k.position, 1.2)
		Game.shake = 2.0
	_look(Vector3(95.0 + f * 15.0, 3.0, -110.0), k.position + Vector3(0, 40, 0), 64.0)


## Guns go up along the seawall.
func _setup_build() -> void:
	_battle()


func _shot_build(t: float) -> void:
	var plan := [[1, "rocket"], [2, "tesla"], [3, "cannon"], [4, "rail"], [5, "rocket"], [8, "flak"], [10, "cannon"], [11, "tesla"]]
	var step := int((t + 0.6) / 0.42)
	while data.get("built", 0) < mini(step, plan.size() * 2):
		var n: int = data.get("built", 0)
		var p: Array = plan[n % plan.size()]
		main.select(Game.pads[p[0]])
		if n < plan.size():
			main.act("build", p[1])
		else:
			main.act("up", "")
		data["built"] = n + 1
	if t > 3.6:
		main.select(null)
	# Dolly along the seawall from the sea side as the guns go up.
	var x := -240.0 + t * 62.0
	_look(Vector3(x, 46.0, -12.0), Vector3(x + 75.0, 0, 30), 58.0)


## On the machine gun: shoot the Onigami's eyes out.
func _setup_gunner() -> void:
	_battle()
	var seat: Turret = main.build_turret(Game.pads[3], "cannon")
	var k := _spawn("oni", seat.pad.pos + Vector3(-20, 0, -150))
	k.target_x = k.position.x
	for s: Dictionary in k.spheres:
		if s["weak"]:
			s["whp"] = 240.0
	data["k"] = k
	Game.player.enter(seat)


func _shot_gunner(t: float) -> void:
	var k: Kaiju = data["k"]
	var e: Variant = _eye(k)
	_aim(e if e is Vector3 else k.aim + Vector3(0, 6, 0))
	Game.player.firing = t > 0.3
	Game.player.heat = minf(Game.player.heat, 0.6)


## Rocketeer: salvoes into a Kanizame and a flight of tengu.
func _setup_rockets() -> void:
	_battle()
	var seat: Turret = main.build_turret(Game.pads[5], "rocket")
	data["k"] = [_spawn("kani", seat.pad.pos + Vector3(30, 0, -250), 600.0), _spawn("oni", seat.pad.pos + Vector3(-70, 0, -240), 900.0),
		_spawn("ryu", seat.pad.pos + Vector3(-140, 0, -300))]
	Game.player.enter(seat)
	Game.player.swap()


func _shot_rockets(t: float) -> void:
	var target: Variant = null
	for k: Kaiju in data["k"]:
		if _alive(k):
			target = k
			break
	if target != null:
		_aim((target as Kaiju).aim)
	Game.player.firing = t > 0.2
	Game.player.ammo = 4
	Game.player.reload = 0.0


## At the helm of the Raijin-maru, guns blazing down on the bay.
func _setup_airship() -> void:
	_battle()
	var z: Zeppelin = Game.zep
	z.position = Vector3(-160, 125, 60)
	z.yaw = Game.yaw_to(0.35, -1.0)
	data["k"] = [_spawn("oni", Vector3(-60, 0, -200)), _spawn("kani", Vector3(30, 0, -260)), _spawn("ryu", Vector3(-130, 0, -280))]
	Game.player.enter("zep")
	z.pilot_speed = 40.0


func _shot_airship(t: float) -> void:
	Game.zep.pilot_speed = 40.0
	var k: Kaiju = data["k"][0] if _alive(data["k"][0]) else data["k"][1]
	_aim(k.aim)
	Game.player.firing = t > 0.2
	Game.player.heat = minf(Game.player.heat, 0.6)


## Three jets carpet-bomb a line of kaiju.
func _setup_airstrike() -> void:
	_battle()
	data["k"] = [_spawn("oni", Vector3(-40, 0, -210)), _spawn("kani", Vector3(20, 0, -240)), _spawn("oni", Vector3(70, 0, -200))]


func _shot_airstrike(t: float) -> void:
	if not data.has("fired") and t > -1.4:
		data["fired"] = true
		Game.abilities.fire("air", Vector3(15, 0, -215))
	var f := _ease(t / 4.0)
	_look(Vector3(-170.0 + f * 40.0, 45.0, -60.0), Vector3(10, 20, -220), 56.0)


## The lightning storm, in the rain.
func _setup_storm() -> void:
	_battle()
	Game.world.set_weather("storm")
	Game.world.rain = 1.0
	Game.world.storm = 1.0
	data["k"] = [_spawn("ryu", Vector3(-30, 0, -250)), _spawn("oni", Vector3(40, 0, -230)), _spawn("tengu", Vector3(0, 110, -260))]


func _shot_storm(t: float) -> void:
	if not data.has("fired") and t > -0.3:
		data["fired"] = true
		Game.abilities.fire("storm", Vector3(10, 0, -240))
	for at: float in [0.9, 2.6]:
		if t > at and not data.has(at):
			data[at] = true
			Game.world._sky_bolt()
	var f := _ease(t / 4.5)
	_look(Vector3(60.0 - f * 50.0, 14.0, -40.0), Vector3(0, 45, -240), 60.0)


## The flood gates throw them back out to sea.
func _setup_flood() -> void:
	_battle()
	data["k"] = [_spawn("oni", Vector3(10, 0, -45)), _spawn("kani", Vector3(70, 0, -40)), _spawn("oni", Vector3(130, 0, -55))]


func _shot_flood(t: float) -> void:
	if not data.has("fired") and t > 0.2:
		data["fired"] = true
		Game.abilities.fire("flood", Vector3(30, 0, -60))
	_look(Vector3(-110.0, 24.0, 30.0 - t * 3.0), Vector3(70, 10, -130), 58.0)


## The Dai-Oni reaches the city: blocks fall and burn, searchlights sweep.
func _setup_rampage() -> void:
	_battle(FEW)
	var k := _spawn("daioni", Vector3(-40, 0, Game.coast_z(-40.0) + Game.STOP + 14.0))
	k.state = "rampage"
	data["k"] = k
	for i: int in range(4):
		Game.world.smash_near(Vector3(-40.0 + float(i - 2) * 50.0, 0, 110), 50.0)


func _shot_rampage(t: float) -> void:
	var k: Kaiju = data["k"]
	k.state = "rampage"
	k.yaw = PI + sin(t * 0.8) * 0.3   # turned on the city
	if int(t * 10.0) % 9 == 0 and data.get("last", -1) != int(t * 10.0):
		data["last"] = int(t * 10.0)
		Game.world.smash_near(k.position + Vector3(randf_range(-40, 40), 0, 90), 70.0)
	var f := _ease(t / 5.0)
	_look(Vector3(0.0, 62.0 - f * 8.0, 236.0 - f * 24.0), k.position + Vector3(0, 45, 0), 58.0)


## Yamata-no-Orochi rises; one of its heads comes off.
func _setup_orochi() -> void:
	_battle([[4, "rail", 3, "a"], [2, "rail", 2, ""]])
	Game.world.set_weather("storm")
	Game.world.rain = 0.6
	Game.world.storm = 0.8
	var k := _spawn("orochi", Vector3(0, 0, -230))
	data["k"] = k
	Game.say("orochi")


func _shot_orochi(t: float) -> void:
	var k: Kaiju = data["k"]
	if t > 0.3 and not data.has("roar"):
		data["roar"] = true
		k.roar_t = 2.0
		Game.sfx.play_at("roar_boss", k.position, 1.4)
		Game.shake = 3.0
	if t > 3.8 and not data.has("cut"):
		data["cut"] = true
		var eyes: Array[int] = []
		for i: int in range(k.spheres.size()):
			if k.spheres[i]["weak"] and eyes.size() < 2:
				eyes.append(i)
		for e: int in eyes:
			for j: int in range(40):
				Game.combat.hurt_kaiju(k, 100.0, "rail", k.aim, Vector3.FORWARD, true, "p", e)
	var f := _ease(t / 7.0)
	_look(Vector3(130.0 - f * 80.0, 6.0 + f * 10.0, -70.0 + f * 10.0), k.position + Vector3(0, 70, 0), 62.0)


## Everything at once, craning up from the seawall to the whole bay.
func _setup_finale() -> void:
	_battle(FEW)
	Game.zep.lvl = {"bomb": 1, "armor": 2, "pods": 1}
	data["k"] = [_spawn("oni", Vector3(-150, 0, -200)), _spawn("kani", Vector3(80, 0, -170)), _spawn("ryu", Vector3(200, 0, -260)),
		_spawn("daioni", Vector3(-20, 0, -380)), _spawn("tengu", Vector3(-60, 110, -220)), _spawn("tengu", Vector3(90, 95, -260)),
		_spawn("orochi", Vector3(240, 0, -480))]


func _shot_finale(t: float) -> void:
	# The title comes up over the last few seconds: no radio subtitles under it.
	Game.hud.subtitle.visible = t < 4.0
	if not data.has("air") and t > 1.0:
		data["air"] = true
		Game.abilities.fire("air", Vector3(-150, 0, -200))
	var f := _ease(t / 6.0)
	_look(Vector3(-40.0 + f * 40.0, 30.0 + f * 150.0, 60.0 + f * 140.0), Vector3(0, 30.0 - f * 10.0, -260), 60.0)
