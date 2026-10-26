extends Node
## Autoload: hotel-wide upgrades, from "crap" to "less crap". Rooms have their own quality
## levels (see Hotel). Gameplay reads the stat helpers at the bottom, so balance lives here.

signal upgrade_purchased(id: String, level: int)
signal upgrades_reset

const CATEGORIES := ["Building", "Pool", "Bar", "Peace & Quiet", "Security"]

const DEFS := {
	"floors": {
		"name": "Open Another Floor", "category": "Building", "max": 2, "cost": 900.0, "growth": 2.6,
		"levels": ["1 floor", "2 floors", "3 floors"],
		"desc": "Rip out the asbestos (carefully) and open another floor of four rooms.",
	},
	"reception": {
		"name": "Reception", "category": "Building", "max": 2, "cost": 250.0, "growth": 3.0,
		"levels": ["Plastic Table", "Proper Desk", "Air-con Lobby"],
		"desc": "First impressions! Happier check-ins, and the inspector wants a real desk.",
	},
	"pest_control": {
		"name": "Pest Control", "category": "Building", "max": 2, "cost": 180.0, "growth": 2.5,
		"desc": "A man with a spray can and a grudge. Far fewer cockroaches.",
	},
	"pool": {
		"name": "Swimming Pool", "category": "Pool", "max": 2, "cost": 220.0, "growth": 4.0,
		"levels": ["Green Swamp", "Clean Pool", "Pool with Slide"],
		"desc": "Nobody wants to swim in soup. A clean pool makes guests much happier.",
	},
	"fence": {
		"name": "Pool Fence & Gate", "category": "Pool", "max": 1, "cost": 160.0, "growth": 1.0,
		"desc": "Stops 3am drunk swims. Swimming pool safety rule number one.",
	},
	"signs": {
		"name": "\"NO DIVING\" Signs", "category": "Pool", "max": 1, "cost": 60.0, "growth": 1.0,
		"desc": "Fewer belly-flop disasters. The lads will still try.",
	},
	"loungers": {
		"name": "Extra Sunloungers", "category": "Pool", "max": 3, "cost": 90.0, "growth": 1.8,
		"desc": "Two more loungers per level. Fewer towel wars at dawn.",
	},
	"bar": {
		"name": "The Bar", "category": "Bar", "max": 2, "cost": 280.0, "growth": 3.0,
		"levels": ["Fridge of Cans", "The Drunken Duck", "Cocktail Bar"],
		"desc": "More drinks sold at better prices. Guests love a proper bar.",
	},
	"karaoke": {
		"name": "Karaoke Machine", "category": "Bar", "max": 1, "cost": 350.0, "growth": 1.0, "requires": {"bar": 1},
		"desc": "Keeps the lads singing at the bar instead of raving in their rooms. Mostly.",
	},
	"soundproofing": {
		"name": "Soundproofing", "category": "Peace & Quiet", "max": 2, "cost": 260.0, "growth": 2.5,
		"desc": "Egg boxes on the walls (level 1), then proper insulation. Raves bother fewer neighbours.",
	},
	"curfew": {
		"name": "Noise Curfew Signs", "category": "Peace & Quiet", "max": 1, "cost": 80.0, "growth": 1.0,
		"desc": "\"QUIET AFTER MIDNIGHT\". Raves start a bit less often.",
	},
	"safes": {
		"name": "Room Safes", "category": "Security", "max": 1, "cost": 400.0, "growth": 1.0,
		"desc": "Thieves can't take anything from rooms. Guests sleep easier.",
	},
	"cctv": {
		"name": "CCTV", "category": "Security", "max": 1, "cost": 450.0, "growth": 1.0,
		"desc": "Thieves get caught (and fewer try). Fights calm down when the camera's watching.",
	},
	"deposit": {
		"name": "Damage Deposits", "category": "Security", "max": 1, "cost": 150.0, "growth": 1.0,
		"desc": "Smash the telly, pay for the telly. Vandalism repairs are charged to the guest.",
	},
}

var levels := {}


func level(id: String) -> int:
	return int(levels.get(id, 0))


func max_level(id: String) -> int:
	return int(DEFS.get(id, {}).get("max", 0))


func is_maxed(id: String) -> bool:
	return level(id) >= max_level(id)


func cost(id: String) -> float:
	var d: Dictionary = DEFS.get(id, {})
	if d.is_empty():
		return INF
	return roundf(float(d.cost) * pow(float(d.growth), level(id)))


func level_name(id: String, lvl := -1) -> String:
	var d: Dictionary = DEFS.get(id, {})
	if lvl < 0:
		lvl = level(id)
	if d.has("levels"):
		return str(d.levels[clampi(lvl, 0, d.levels.size() - 1)])
	return "Level %d" % lvl if int(d.get("max", 1)) > 1 else ("Installed" if lvl > 0 else "Not installed")


func block_reason(id: String) -> String:
	if not DEFS.has(id):
		return "Unknown"
	if is_maxed(id):
		return "Done!"
	var req: Dictionary = DEFS[id].get("requires", {})
	for rid in req:
		if level(rid) < int(req[rid]):
			return "Needs %s" % DEFS[rid].name
	if not Economy.can_afford(cost(id)):
		return "Not enough cash"
	return ""


func buy(id: String) -> bool:
	if block_reason(id) != "":
		return false
	if not Economy.spend(cost(id), "upgrade"):
		return false
	levels[id] = level(id) + 1
	upgrade_purchased.emit(id, levels[id])
	return true


func reset() -> void:
	levels = {}
	upgrades_reset.emit()


func to_dict() -> Dictionary:
	return levels.duplicate()


func from_dict(d: Dictionary) -> void:
	levels = {}
	for id in d:
		if DEFS.has(id):
			levels[id] = clampi(int(d[id]), 0, max_level(id))
	upgrades_reset.emit()


# --- Stats used by gameplay --------------------------------------------------------------------

func floors_open() -> int:
	return 1 + level("floors")


func lounger_count() -> int:
	return 4 + 2 * level("loungers")


func roach_mult() -> float:
	return [1.0, 0.45, 0.15][level("pest_control")]


func noise_spread() -> int:
	# How many neighbouring rooms a rave annoys on each side.
	return [2, 1, 0][level("soundproofing")]


func rave_mult() -> float:
	var m := 1.0
	if level("curfew") > 0:
		m *= 0.7
	if level("karaoke") > 0:
		m *= 0.6
	return m


func theft_mult() -> float:
	return 0.4 if level("cctv") > 0 else 1.0


func fight_mult() -> float:
	return 0.7 if level("cctv") > 0 else 1.0


func pool_risk_mult() -> float:
	var m := 1.0
	if level("signs") > 0:
		m *= 0.6
	if level("fence") > 0:
		m *= 0.7
	return m


func bar_price_mult() -> float:
	return [1.0, 1.25, 1.6][level("bar")]


func bar_appeal() -> float:
	return [0.6, 1.0, 1.3][level("bar")]


func pool_appeal() -> float:
	return [0.3, 1.0, 1.4][level("pool")]
