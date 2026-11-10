class_name Villagers
extends RefCounted
## The seven of Kirkhaven (docs/STORY.md): who they are, where they stand, and what each
## does for the keepers while they live. Run.villagers holds the ids of the living;
## Run.lost the ids of the lost, in the order they were lost.

## id, the name the game uses, their trade, the keeper model they borrow (an index into
## Players.MODELS; Outfits.LOOKS, by id, dresses it as their own), where they are by day
## in the town (x, z), and where they stand in the camp on the rock (from its centre).
const ROSTER := [
	{"id": "baird", "name": "Mr Baird", "full": "the Rev. Alasdair Baird", "trade": "minister", "model": 3, "home": Vector2(-1.6, -19.6), "camp": Vector2(-3.0, 1.2)},
	{"id": "rennie", "name": "Isla Rennie", "full": "Isla Rennie", "trade": "chandler", "model": 2, "home": Vector2(-3.4, -0.5), "camp": Vector2(-1.0, 2.6)},
	{"id": "coull", "name": "Sandy Coull", "full": "Sandy Coull", "trade": "engineer", "model": 1, "home": Vector2(-28.6, 4.0), "camp": Vector2(6.0, 1.4)},
	{"id": "duthie", "name": "Morag Duthie", "full": "Morag Duthie", "trade": "publican", "model": 2, "home": Vector2(5.2, -0.5), "camp": Vector2(3.4, -0.8)},
	{"id": "buchan", "name": "Nurse Buchan", "full": "Nurse Jean Buchan", "trade": "nurse", "model": 2, "home": Vector2(15.0, -0.6), "camp": Vector2(-4.6, -1.2)},
	{"id": "geddes", "name": "Tam Geddes", "full": "Tam Geddes", "trade": "harbour master", "model": 3, "home": Vector2(-29.6, -0.6), "camp": Vector2(0.6, -1.6)},
	{"id": "main", "name": "Peter Main", "full": "Peter Main", "trade": "net-mender", "model": 0, "home": Vector2(28.6, -1.4), "camp": Vector2(5.0, 2.8)},
]
## What the engineer puts in the generator each dusk.
const TOP_UP := 20.0

static func all_ids() -> Array:
	var out := []
	for r in ROSTER:
		out.append(r["id"])
	return out

static func who(id: String) -> Dictionary:
	for r in ROSTER:
		if r["id"] == id:
			return r
	return {}

static func name_of(id: String) -> String:
	return String(who(id).get("name", id))

static func alive(id: String) -> bool:
	return Run.villagers.has(id)

static func count() -> int:
	return Run.villagers.size()

## The names of the lost, for the log.
static func lost_names() -> Array:
	var out := []
	for id in Run.lost:
		out.append(String(who(String(id)).get("full", id)))
	return out

## One of them is gone.
static func lose(id: String) -> void:
	if not Run.villagers.has(id):
		return
	Run.villagers.erase(id)
	Run.lost.append(id)

## Dawn: what the living bring. Adds it to the store and returns a line for the keeper's
## log ("" when there is nobody).
static func dawn_gifts() -> String:
	var got: Array[String] = []
	if alive("rennie"):
		Stock.add("scrap", 1)
		got.append("a scrap from Isla Rennie")
	if alive("duthie"):
		Stock.add("food", 1)
		got.append("a meal from Morag Duthie")
	if alive("geddes"):
		Stock.add("shells", 2)
		got.append("two cartridges from Tam Geddes")
	if alive("main"):
		Stock.add("arrows", 4)
		got.append("four arrows from Peter Main")
	if got.is_empty():
		return ""
	return "Brought to the store: %s." % ", ".join(got)

## Dawn: the nurse sees to the keepers. True if she did.
static func dawn_nursing(keepers: Array) -> bool:
	if not alive("buchan"):
		return false
	var did := false
	for k in keepers:
		if is_instance_valid(k) and k.hp < k.max_hp:
			k.hp = k.max_hp
			did = true
	return did

## Dusk: the engineer tops the generator up. True if he did.
static func dusk_engineer(gen: Generator) -> bool:
	if not alive("coull") or gen == null or not is_instance_valid(gen) or gen.is_destroyed() or gen.fuel > Generator.FUEL_MAX - TOP_UP:
		return false
	gen.fuel = minf(Generator.FUEL_MAX, gen.fuel + TOP_UP)
	Run.camp_fuel = gen.fuel
	return true
