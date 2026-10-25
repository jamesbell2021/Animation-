extends Node
## Autoload: the upgrade tree. Each upgrade has levels with rising costs, an optional
## requirement on another upgrade, and a description full of chicken nuggets. Gameplay code
## never reads levels directly: it asks the stat helpers at the bottom (shout_radius(),
## pack_time()...), so balancing lives in one place.

signal upgrade_purchased(id: String, level: int)
signal upgrades_reset

const CATEGORIES := ["Stall", "Salesman", "Supply", "Escape", "Empire"]

## cost: price of level 1; growth: multiplier per level; requires: {id: level}.
const DEFS := {
	"stall": {
		"name": "Stall", "category": "Stall", "max": 5, "cost": 120.0, "growth": 3.2,
		"levels": ["Blanket on the Sand", "Fold-out Table", "Big Table", "Table + Parasol", "Deluxe Gazebo", "Pop-up Kiosk"],
		"desc": "Bigger stall, more customers at once, more sales. Very good very nice! (Bigger stalls are slower to pack...)",
	},
	"parasol": {
		"name": "Shady Parasol", "category": "Stall", "max": 3, "cost": 90.0, "growth": 2.6, "requires": {"stall": 1},
		"desc": "Hello chicken nugget, come in the shade! Tourists browse longer and buy more.",
	},
	"display": {
		"name": "Flashy Display", "category": "Stall", "max": 3, "cost": 150.0, "growth": 2.8,
		"desc": "Fairy lights and a cardboard sign that says VERY GOOD VERY NICE. Pulls tourists from further away.",
	},
	"voice": {
		"name": "Lungs of Steel", "category": "Salesman", "max": 5, "cost": 60.0, "growth": 2.1,
		"desc": "\"HELLO CHICKEN NUGGET!\" reaches further down the beach. Very good very LOUD!",
	},
	"patter": {
		"name": "Catchphrase Mastery", "category": "Salesman", "max": 5, "cost": 80.0, "growth": 2.3,
		"desc": "Perfect your \"Very good very nice!\" Tourists can't say no. Higher sale chance.",
	},
	"megaphone": {
		"name": "Megaphone", "category": "Salesman", "max": 2, "cost": 400.0, "growth": 3.0, "requires": {"voice": 2},
		"desc": "Shout more often. The police can hear it too. Very good very nice?",
	},
	"supplier": {
		"name": "Supplier Contacts", "category": "Supply", "max": 4, "cost": 150.0, "growth": 3.4,
		"levels": ItemDB.TIER_NAMES,
		"desc": "Know a guy who knows a guy. Unlocks fancier junk at the Wholesaler.",
	},
	"bulk": {
		"name": "Bulk Discount", "category": "Supply", "max": 3, "cost": 200.0, "growth": 2.5,
		"desc": "Buy a mountain, pay for a hill. Wholesale prices down 8% per level.",
	},
	"storage": {
		"name": "Lock-up Garage", "category": "Supply", "max": 4, "cost": 100.0, "growth": 2.4,
		"desc": "Somewhere to keep 400 flamingos. Carry 60 more items per level.",
	},
	"shoes": {
		"name": "Running Shoes", "category": "Escape", "max": 3, "cost": 70.0, "growth": 2.4,
		"desc": "Fake Nikes, real speed. Walk and run faster. Very good very fast!",
	},
	"rope": {
		"name": "Rope-pull Blanket", "category": "Escape", "max": 2, "cost": 110.0, "growth": 3.0,
		"desc": "The classic! Pull the strings, the shop disappears. Pack up twice as fast per level.",
	},
	"charm": {
		"name": "Charm School", "category": "Escape", "max": 3, "cost": 150.0, "growth": 2.5,
		"desc": "\"Hello officer chicken nugget!\" Bribes work more often.",
	},
	"cousin": {
		"name": "Cousin in the Policía", "category": "Escape", "max": 3, "cost": 300.0, "growth": 2.6,
		"desc": "He hears things. He tells you things. Heat builds up slower.",
	},
	"van": {
		"name": "Rusty Van", "category": "Empire", "max": 2, "cost": 900.0, "growth": 3.0,
		"desc": "Needed to reach the far beaches. Level 2 gives free restocking by your Runners. Very good very rusty!",
	},
	"cards": {
		"name": "Business Cards", "category": "Empire", "max": 4, "cost": 180.0, "growth": 2.4,
		"desc": "\"Very Good Very Nice Ltd.\" Hire one more worker per beach per level.",
	},
	"training": {
		"name": "Lookee Lookee Academy", "category": "Empire", "max": 3, "cost": 350.0, "growth": 2.6, "requires": {"cards": 1},
		"desc": "Teach your staff the ancient art of \"Hello chicken nugget!\" Workers sell and shout better.",
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
		var names: Array = d.levels
		return str(names[clampi(lvl, 0, names.size() - 1)])
	return "Level %d" % lvl


## Returns "" when buyable, otherwise the reason it isn't.
func block_reason(id: String) -> String:
	if not DEFS.has(id):
		return "Unknown"
	if is_maxed(id):
		return "MAXED - very good very nice!"
	var req: Dictionary = DEFS[id].get("requires", {})
	for rid in req:
		if level(rid) < int(req[rid]):
			return "Needs %s %d" % [DEFS[rid].name, int(req[rid])]
	if not Economy.can_afford(cost(id)):
		return "Need %s" % Lines.money(cost(id))
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


# --- Stats used by gameplay ------------------------------------------------------------------

func stall_tier() -> int:
	return level("stall")


## How many tourists the stall can serve at once.
func stall_slots() -> int:
	return [1, 2, 2, 3, 3, 4][clampi(stall_tier(), 0, 5)]


func stall_attraction() -> float:
	return 220.0 + 35.0 * stall_tier() + 50.0 * level("display")


func shout_radius() -> float:
	return 400.0 * (1.0 + 0.14 * level("voice")) * (1.0 + 0.2 * level("megaphone"))


func shout_cooldown() -> float:
	return 2.4 * pow(0.72, level("megaphone"))


func sale_bonus() -> float:
	return 0.05 * level("patter") + 0.04 * stall_tier() + 0.04 * level("parasol")


func browse_time_mult() -> float:
	return 1.0 + 0.15 * level("parasol")


func pack_time() -> float:
	return (1.2 + 0.45 * stall_tier()) * pow(0.5, level("rope"))


func move_speed_mult() -> float:
	return 1.0 + 0.14 * level("shoes")


func heat_gain_mult() -> float:
	return pow(0.86, level("cousin"))


func bribe_bonus() -> float:
	return 0.09 * level("charm")


func max_stock() -> int:
	return 80 + 60 * level("storage")


func staff_cap() -> int:
	return 1 + level("cards")


func staff_skill_bonus() -> float:
	return 0.15 * level("training")


func wholesale_mult() -> float:
	return pow(0.92, level("bulk"))


func supplier_tier() -> int:
	return level("supplier")
