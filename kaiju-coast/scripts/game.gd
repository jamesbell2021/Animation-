extends Node
## Autoload "Game": definitions (guns, kaiju, upgrades), game state, economy and the wave
## schedule. The scene itself (kaiju, guns, effects) lives under Main; Game keeps references so
## any script can reach it.

signal banner(big: String, small: String, duration: float)
signal hud_dirty
signal state_changed

enum State { TITLE, PLAY, OVER }

const WIN_WAVE: int = 15
const MAXL: int = 4
const WALL: float = 16.0      ## seawall offset behind the waterline
const STOP: float = 44.0      ## kaiju stop here, behind the wall, and rampage

## Guns. dt is the damage type: kin (shells, bullets), exp (blast), elec, rail (ignores armour).
const TT: Dictionary = {
	"cannon": {"name": "TAIHO CANNON", "jp": "大砲", "kj": "砲", "cost": 100, "dmg": 24.0, "rate": 1.2, "range": 270.0,
		"spd": 520.0, "ground": true, "air": false, "dt": "kin", "splash": 0.0, "chain": 0, "desc": "Fast shells. Ground kaiju."},
	"rocket": {"name": "HIYA ROCKETS", "jp": "火箭", "kj": "箭", "cost": 170, "dmg": 40.0, "rate": 0.55, "range": 330.0,
		"spd": 230.0, "ground": true, "air": true, "dt": "exp", "splash": 22.0, "chain": 0, "desc": "Homing salvos with splash. Ground and air."},
	"tesla": {"name": "RAIJIN COIL", "jp": "雷神", "kj": "雷", "cost": 240, "dmg": 32.0, "rate": 0.9, "range": 175.0,
		"spd": 0.0, "ground": true, "air": true, "dt": "elec", "splash": 0.0, "chain": 3, "desc": "Chain lightning that slows. Short range."},
	"rail": {"name": "KATANA RAIL", "jp": "刀", "kj": "刀", "cost": 380, "dmg": 170.0, "rate": 0.26, "range": 640.0,
		"spd": 0.0, "ground": true, "air": false, "dt": "rail", "splash": 0.0, "chain": 0, "desc": "Pierces every kaiju in line. Ignores armour."},
	"flak": {"name": "HANABI FLAK", "jp": "花火", "kj": "花", "cost": 140, "dmg": 20.0, "rate": 2.4, "range": 320.0,
		"spd": 440.0, "ground": false, "air": true, "dt": "kin", "splash": 24.0, "chain": 0, "desc": "Firework air-bursts. Shreds flying kaiju."},
}
const TT_KEYS: Array[String] = ["cannon", "rocket", "tesla", "rail", "flak"]

## Level 3 is a fork: each gun picks one of two specialisations, which carries on to level 4.
const BRANCH: Dictionary = {
	"cannon": {"a": {"name": "SANDAN SHOT", "jp": "散弾", "desc": "Six-pellet burst. Wrecks anything close."},
		"b": {"name": "TEKKO AP", "jp": "徹甲", "desc": "Armour-piercing shells, longer reach."}},
	"rocket": {"a": {"name": "KOBAKU CLUSTER", "jp": "子爆", "desc": "Every rocket scatters bomblets."},
		"b": {"name": "MURE SWARM", "jp": "群れ", "desc": "Three more rockets in every salvo."}},
	"tesla": {"a": {"name": "ARASHI STORM", "jp": "嵐", "desc": "Chains to three more kaiju, wider reach."},
		"b": {"name": "IKAZUCHI OVERLOAD", "jp": "雷", "desc": "One huge bolt that stuns."}},
	"rail": {"a": {"name": "NIDAN DOUBLE", "jp": "二段", "desc": "A second slug right behind the first."},
		"b": {"name": "KYUSHO SNIPER", "jp": "急所", "desc": "Aims for weak points. Triple damage on them."}},
	"flak": {"a": {"name": "HOSHI STARBURST", "jp": "星", "desc": "Huge bursts that also hit wading kaiju."},
		"b": {"name": "TSUIBI TRACKER", "jp": "追尾", "desc": "Homing shells, faster fire."}},
}

const KT: Dictionary = {
	"oni": {"name": "ONIGAMI", "jp": "鬼神", "hp": 640.0, "spd": 15.0, "reward": 60, "col": Color(0.71, 0.42, 1.0),
		"arm": {}, "city": 2.0, "breath": true, "pts": 3, "scale": 1.0, "air": false, "boss": false},
	"kani": {"name": "KANIZAME", "jp": "蟹鮫", "hp": 430.0, "spd": 23.0, "reward": 42, "col": Color(1.0, 0.48, 0.18),
		"arm": {"kin": 0.5}, "city": 1.6, "breath": false, "pts": 2, "scale": 1.0, "air": false, "boss": false},
	"ryu": {"name": "RYUJIN", "jp": "竜神", "hp": 360.0, "spd": 31.0, "reward": 45, "col": Color(0.78, 1.0, 0.24),
		"arm": {"elec": 0.6}, "city": 1.5, "breath": false, "pts": 2, "scale": 1.0, "air": false, "boss": false},
	"tengu": {"name": "TENGU", "jp": "天狗", "hp": 210.0, "spd": 40.0, "reward": 40, "col": Color(1.0, 0.37, 0.64),
		"arm": {}, "city": 1.2, "breath": false, "pts": 2, "scale": 1.0, "air": true, "boss": false},
	"daioni": {"name": "DAI-ONI", "jp": "大鬼", "hp": 3600.0, "spd": 9.0, "reward": 650, "col": Color(1.0, 0.23, 0.19),
		"arm": {"kin": 0.8, "exp": 0.8, "elec": 0.8}, "city": 5.0, "breath": true, "pts": 12, "scale": 1.9, "air": false, "boss": true},
	"orochi": {"name": "YAMATA-NO-OROCHI", "jp": "八岐大蛇", "hp": 7200.0, "spd": 7.0, "reward": 900, "col": Color(0.95, 0.25, 0.6),
		"arm": {"kin": 0.85, "elec": 0.75}, "city": 6.0, "breath": true, "pts": 14, "scale": 1.0, "air": false, "boss": true},
}

const ZUP: Dictionary = {
	"bomb": {"name": "BOMB BAY", "jp": "爆弾倉", "desc": "Drops bombs on kaiju passing beneath.", "costs": [220, 380, 600]},
	"pods": {"name": "ROCKET PODS", "jp": "噴進弾", "desc": "Homing rockets from the hull, ground and air.", "costs": [200, 340, 560]},
	"armor": {"name": "ARMOUR PLATE", "jp": "装甲", "desc": "+150 hull per level. Tengu hunt the airship.", "costs": [150, 260, 420]},
}
const AUP: Dictionary = {
	"gun": {"name": "GUNNER ROUNDS", "jp": "徹甲弾", "desc": "+25% gunner damage, less heat.", "costs": [150, 280, 450, 700]},
	"rkt": {"name": "ROCKETEER PAYLOAD", "jp": "炸薬", "desc": "+30% rocket damage, bigger blast, +1 rocket.", "costs": [180, 320, 500, 760]},
}

# --- scene references (set by Main) ---
var main: Main
var fx: Fx
var combat: Combat
var world: World
var rig: CameraRig
var hud: Hud
var player: Player
var zep: Zeppelin
var sfx: Sfx
var music: Music
var voice: Node = null
var abilities: Abilities
var tutorial: Tutorial
## 0 easy, 1 normal, 2 hard (chosen on the title screen).
var difficulty: int = 1

var pads: Array[Pad] = []
var kaiju: Array[Kaiju] = []
var turrets: Array[Turret] = []

# --- state ---
var state: State = State.TITLE
var demo: bool = true
var funds: int = 0
var city: float = 100.0
var wave: int = 0
var phase: String = "build"
var speed: int = 1
var paused: bool = false
var spawn_q: Array[String] = []
var spawn_t: float = 0.0
var hp_mul: float = 1.0
var kills: int = 0
var best: int = 0
var armory: Dictionary = {"gun": 0, "rkt": 0}
var countdown: float = 0.0
var endless: bool = false
var hurt: float = 0.0
var city_warned: bool = false
## Storm swell: scales the sea's waves (kept in step with the ocean shader's `amp`).
var sea_amp: float = 1.0
var slowmo: float = 0.0
var shake: float = 0.0
var flash: float = 0.0
var sel: Variant = null          ## a Pad, "zep", "armory" or null
var t: float = 0.0               ## world time (sim seconds)

## Tests point this at a scratch file so they never touch your real settings or best wave.
var save_path: String = "user://kaiju_coast.cfg"


func _ready() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(save_path) == OK:
		best = int(cfg.get_value("score", "best_wave", 0))


func save_best() -> void:
	if wave > best:
		best = wave
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("score", "best_wave", best)
	cfg.save(save_path)


func save_setting(key: String, value: Variant) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("settings", key, value)
	cfg.save(save_path)


func load_setting(key: String, default: Variant) -> Variant:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(save_path) != OK:
		return default
	return cfg.get_value("settings", key, default)


static func coast_z(x: float) -> float:
	return 6.0 * sin(x * 0.013) + 4.0 * sin(x * 0.037 + 1.0)


static func depth_at(z: float) -> float:
	return clampf(-z / 17.0, 0.0, 60.0) if z < 0.0 else 0.0


func wave_h(x: float, z: float) -> float:
	return (1.3 * sin(x * 0.019 + t * 1.1) + 1.1 * sin(z * 0.027 - t * 1.4) + 0.6 * sin((x + z) * 0.05 + t * 2.1)) * sea_amp


func surface_y(x: float, z: float) -> float:
	return wave_h(x, z) if z < coast_z(x) else 2.0


## Heading so that a node's forward (-Z) points along (dx, dz).
static func yaw_to(dx: float, dz: float) -> float:
	return atan2(-dx, -dz)


func make_pads() -> void:
	pads.clear()
	var i: int = 0
	for x: float in [-262.0, -176.0, -90.0, 0.0, 90.0, 176.0, 262.0]:
		pads.append(Pad.new(i, Vector3(x, 2.0, coast_z(x) + WALL + 12.0), false))
		i += 1
	for p: Vector2 in [Vector2(-222, 66), Vector2(-52, 64), Vector2(128, 66)]:
		pads.append(Pad.new(i, Vector3(p.x, 2.0, p.y), false))
		i += 1
	for p2: Vector2 in [Vector2(-158, -175), Vector2(138, -195), Vector2(-14, -340)]:
		pads.append(Pad.new(i, Vector3(p2.x, 9.0, p2.y), true))
		i += 1


func tstat(type: String, lvl: int, branch: String = "") -> Dictionary:
	var d: Dictionary = TT[type]
	var l: float = float(lvl - 1)
	var st: Dictionary = {
		"dmg": float(d["dmg"]) * (1.0 + 0.6 * l), "rate": float(d["rate"]) * (1.0 + 0.15 * l),
		"range": float(d["range"]) * (1.0 + 0.1 * l), "spd": float(d["spd"]), "ground": d["ground"], "air": d["air"],
		"dt": d["dt"], "splash": float(d["splash"]) * (1.0 + 0.12 * l), "chain": int(d["chain"]) + int(l),
		"salvo": 2 + int(floor(l / 1.5)), "pellets": 1, "cluster": false, "stun": false, "double": false,
		"sniper": false, "homing": false,
	}
	if lvl < 3 or branch == "":
		return st
	match type + branch:
		"cannona":
			st["pellets"] = 6
			st["range"] = float(st["range"]) * 0.85
			st["dmg"] = float(st["dmg"]) * 1.2
		"cannonb":
			st["dt"] = "rail"
			st["range"] = float(st["range"]) * 1.25
			st["dmg"] = float(st["dmg"]) * 1.25
		"rocketa":
			st["cluster"] = true
		"rocketb":
			st["salvo"] = int(st["salvo"]) + 3
			st["dmg"] = float(st["dmg"]) * 0.75
		"teslaa":
			st["chain"] = int(st["chain"]) + 3
			st["range"] = float(st["range"]) * 1.2
		"teslab":
			st["chain"] = 1
			st["dmg"] = float(st["dmg"]) * 2.6
			st["stun"] = true
		"raila":
			st["double"] = true
		"railb":
			st["sniper"] = true
		"flaka":
			st["splash"] = float(st["splash"]) * 1.6
			st["ground"] = true
		"flakb":
			st["homing"] = true
			st["rate"] = float(st["rate"]) * 1.4
	return st


func up_cost(type: String, lvl: int) -> int:
	return roundi(float(TT[type]["cost"]) * [0.8, 1.35, 2.1][lvl - 1])


static func max_hp(lvl: int) -> float:
	return 120.0 + 60.0 * float(lvl - 1)


# ------------------------------------------------------------------ waves --

func jp_num(n: int) -> String:
	var d: Array[String] = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
	if n <= 10:
		return d[n]
	if n < 20:
		return "十" + d[n - 10]
	var tens: int = n / 10
	var ones: int = n % 10
	return d[tens] + "十" + (d[ones] if ones > 0 else "")


func make_wave(n: int) -> Array[String]:
	var list: Array[String] = []
	var pts: int = 3 + n * 3
	var pool: Array[String] = ["oni"]
	if n >= 2:
		pool.append_array(["kani", "kani"])
	if n >= 3:
		pool.append_array(["ryu", "ryu"])
	if n >= 4:
		pool.append_array(["tengu", "tengu"])
	var boss: bool = n % 5 == 0
	if boss:
		pts -= 6
	while pts > 0:
		var k: String = "oni" if n == 1 else pool.pick_random()
		list.append(k)
		pts -= int(KT[k]["pts"])
	# Bosses: the Dai-Oni on wave 5, Yamata-no-Orochi on wave 10, both from wave 15.
	if boss:
		list.append("orochi" if n % 10 == 0 else "daioni")
		if n >= 15:
			list.append("daioni" if n % 10 == 0 else "orochi")
	return list


func say(key: String) -> void:
	if voice != null and not demo:
		voice.say(key)


func start_wave() -> void:
	if state != State.PLAY or phase != "build":
		return
	if countdown > 1.0 and wave > 0:
		var bonus: int = roundi(countdown * 2.0)
		funds += bonus
		fx.text(Vector3(0, 60, 40), "早期 +¥%d" % bonus, Mats.GOLD, 12.0, 1.6)
	wave += 1
	phase = "wave"
	spawn_q = make_wave(wave)
	hp_mul = (1.0 + 0.15 * float(wave - 1) + 0.022 * float((wave - 1) * (wave - 1))) * [0.78, 1.0, 1.3][difficulty]
	spawn_t = 0.5
	world.roll_weather(wave)
	var boss: bool = wave % 5 == 0
	var boss_line: String = "WAVE %d · THE EIGHT-HEADED SERPENT RISES" % wave if wave % 10 == 0 else "WAVE %d · A GREAT ONI RISES" % wave
	banner.emit("第" + jp_num(wave) + "波", boss_line if boss else ("WAVE %d · %d KAIJU" % [wave, spawn_q.size()]), 2.6)
	sfx.play("gong")
	if not boss:
		say("wave")
	music.set_mode("boss" if boss else "battle")
	hud_dirty.emit()


func wave_clear() -> void:
	phase = "build"
	var bonus: int = 60 + wave * 15
	funds += bonus
	banner.emit("撃退", "WAVE %d HELD · +¥%d" % [wave, bonus], 2.6)
	if not (wave == WIN_WAVE and not endless):
		say("clear")
	music.set_mode("calm")
	countdown = 30.0
	save_best()
	if wave == WIN_WAVE and not endless:
		end_game(true)


func update_waves(dt: float) -> void:
	if phase == "wave":
		spawn_t -= dt
		if spawn_t <= 0.0 and not spawn_q.is_empty():
			var k: String = spawn_q.pop_front()
			main.spawn_kaiju(k)
			spawn_t = maxf(1.4, 5.0 - float(wave) * 0.2) * (2.0 if k == "daioni" else 1.0)
		if spawn_q.is_empty() and live_kaiju() == 0:
			wave_clear()
	else:
		countdown -= dt
		if countdown <= 0.0:
			start_wave()


func city_mult() -> float:
	return [0.7, 1.0, 1.25][difficulty]


func reward_mult() -> float:
	return [1.15, 1.0, 0.9][difficulty]


func live_kaiju() -> int:
	var n: int = 0
	for k: Kaiju in kaiju:
		if not k.dying:
			n += 1
	return n


func new_game() -> void:
	main.clear_world()
	abilities.reset()
	demo = false
	state = State.PLAY
	difficulty = clampi(int(Settings.get_v("difficulty")), 0, 2)
	funds = [600, 420, 340][difficulty]
	city = 100.0
	city_warned = false
	world.set_weather("clear")
	if voice != null:
		voice.reset()
	wave = 0
	phase = "build"
	speed = 1
	paused = false
	spawn_q.clear()
	kills = 0
	sel = null
	armory = {"gun": 0, "rkt": 0}
	countdown = 45.0
	endless = false
	hurt = 0.0
	slowmo = 0.0
	music.set_mode("calm")
	rig.set_mode("command")
	banner.emit("防衛開始", "BUILD YOUR GUNS · CLICK A RING ON THE SHORE", 3.2)
	say("deploy")
	if bool(Settings.get_v("tutorial")):
		tutorial.start()
	state_changed.emit()
	hud_dirty.emit()


func end_game(win: bool) -> void:
	player.exit_seat()
	state = State.OVER
	save_best()
	music.set_mode("title")
	if not win:
		sfx.play("gong")
	say("win" if win else "lose")
	hud.show_over(win)
	state_changed.emit()


func continue_endless() -> void:
	endless = true
	state = State.PLAY
	rig.set_mode("command")
	music.set_mode("calm")
	state_changed.emit()
	hud_dirty.emit()
