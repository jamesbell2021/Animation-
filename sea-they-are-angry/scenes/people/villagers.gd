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

## On the rock each of them asks one small thing on some day (RockDays opens one at a
## time, for that day only; done, the reward holds for the rest of the run, Run.favours).
## kind "give": E at them hands over `cost` from the store. "fetch": something of
## theirs washed up on a beach (`item`), picked up and brought to them. "stove": the
## quarters' stove lit. `ask` is the line when it opens, `short` the line kept on screen,
## `thanks` the line when it is done (and what the reward is).
const REQUESTS := {
	"baird": {"kind": "fetch", "item": "Mr Baird's bible",
		"ask": "Mr Baird's bible went over the side of the Mary Ann. It has come ashore on the %s beach: bring it to him.",
		"short": "Mr Baird's bible: on the %s beach, then to him in the camp",
		"thanks": "Mr Baird has his bible back. He reads from it over the water, and the sea seems to listen: it is quieter."},
	"rennie": {"kind": "give", "cost": {"driftwood": 3},
		"ask": "Isla Rennie wants three driftwood to knock up a rack for the store.",
		"short": "Isla Rennie: 3 driftwood for a store rack",
		"thanks": "Isla Rennie has her rack up. With the store in order she finds two scrap a dawn now, not one."},
	"coull": {"kind": "give", "cost": {"scrap": 2, "diesel": 1},
		"ask": "Sandy Coull wants two scrap and a can of diesel to strip down the camp's generator.",
		"short": "Sandy Coull: 2 scrap and 1 diesel for the generator",
		"thanks": "Sandy Coull has fitted the generator with a governor: it burns a third less."},
	"duthie": {"kind": "give", "cost": {"eggs": 3},
		"ask": "Morag Duthie could make something of three gull eggs, if anyone rowed out to Gull Rock.",
		"short": "Morag Duthie: 3 gull eggs, from Gull Rock",
		"thanks": "Morag Duthie has her kitchen going in the mess: two meals a dawn from now on."},
	"buchan": {"kind": "give", "cost": {"bio": 2},
		"ask": "Nurse Buchan needs two of the glowing stuff off the beaches: it keeps a dressing clean.",
		"short": "Nurse Buchan: 2 bio for dressings",
		"thanks": "Nurse Buchan has made up dressings: from now on she sees to the keepers at dusk as well as at dawn."},
	"geddes": {"kind": "stove",
		"ask": "Tam Geddes's chest is bad with the damp. Light the quarters' stove for him.",
		"short": "Tam Geddes: light the quarters' stove",
		"thanks": "Tam Geddes, warm at last, gives up the box he kept back from the harbour office: ten cartridges."},
	"main": {"kind": "give", "cost": {"seaweed": 3},
		"ask": "Peter Main wants three kelp to twist into netting for the camp.",
		"short": "Peter Main: 3 kelp for netting",
		"thanks": "Peter Main has the netting done, and his hands free: six arrows a dawn from now on, not four."},
}
## What each says at the dawn after one of the others is lost (%s: the name).
const GRIEF := {
	"baird": "Mr Baird says a few words for %s on the shingle at first light.",
	"rennie": "Isla Rennie writes %s into the store book, and draws a line under the name.",
	"coull": "Sandy Coull works on at the generator, and says nothing about %s.",
	"duthie": "Morag Duthie sets a place for %s at the mess table, out of habit.",
	"buchan": "Nurse Buchan sits a long while by %s's empty bunk.",
	"geddes": "Tam Geddes puts %s in the log he keeps, under lost.",
	"main": "Peter Main leaves a net %s was mending out on the wire to dry.",
}
## Nurse Buchan's dressings: this much health back for each keeper at dusk.
const DRESSINGS := 30
## Tam Geddes's box of cartridges.
const GEDDES_BOX := 10

static func favoured(id: String) -> bool:
	return Run.favours.has(id)

## One line of grief from one of the living for someone lost (by id); "" if nobody's left
## to say it. Who speaks goes round the living by the lost one's place in the roster.
static func grief_line(lost_id: String) -> String:
	var living: Array = Run.villagers.filter(func(v) -> bool: return v != lost_id)
	if living.is_empty():
		return ""
	var at := 0
	for i in ROSTER.size():
		if ROSTER[i]["id"] == lost_id:
			at = i
	var who := String(living[(at + Run.lost.size()) % living.size()])
	return String(GRIEF.get(who, "%s is missed.")) % name_of(lost_id)

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
		var n := 2 if favoured("rennie") else 1
		Stock.add("scrap", n)
		got.append("two scrap from Isla Rennie" if n == 2 else "a scrap from Isla Rennie")
	if alive("duthie"):
		var n := 2 if favoured("duthie") else 1
		Stock.add("food", n)
		got.append("two meals from Morag Duthie" if n == 2 else "a meal from Morag Duthie")
	if alive("geddes"):
		Stock.add("shells", 2)
		got.append("two cartridges from Tam Geddes")
	if alive("main"):
		var n := 6 if favoured("main") else 4
		Stock.add("arrows", n)
		got.append("%s arrows from Peter Main" % ("six" if n == 6 else "four"))
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

## Dusk, once Nurse Buchan has her dressings: each hurt keeper gets DRESSINGS back.
## True if she saw to anyone.
static func dusk_dressings(keepers: Array) -> bool:
	if not alive("buchan") or not favoured("buchan"):
		return false
	var did := false
	for k in keepers:
		if is_instance_valid(k) and not k.downed and k.hp < k.max_hp:
			k.hp = mini(k.max_hp, k.hp + DRESSINGS)
			did = true
	return did

## Dusk: the engineer tops the generator up. True if he did.
static func dusk_engineer(gen: Generator) -> bool:
	if not alive("coull") or gen == null or not is_instance_valid(gen) or gen.is_destroyed() or gen.fuel > Generator.FUEL_MAX - TOP_UP:
		return false
	gen.fuel = minf(Generator.FUEL_MAX, gen.fuel + TOP_UP)
	Run.camp_fuel = gen.fuel
	return true
