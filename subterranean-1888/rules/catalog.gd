class_name Catalog
extends RefCounted
## Where every unit definition lives. Explicit paths rather than a folder scan, so exported
## builds (where res:// can't always be listed) find them too.

const UNITS := {
	"engineer": "res://data/units/engineer.tres",
	"naturalist": "res://data/units/naturalist.tres",
	"grenadier": "res://data/units/grenadier.tres",
	"cartographer": "res://data/units/cartographer.tres",
	"worker": "res://data/units/worker.tres",
	"crawler": "res://data/units/crawler.tres",
	"hive": "res://data/units/hive.tres",
}

const LEVELS := ["res://levels/cavern_01.txt"]


static func load_units() -> Dictionary:
	var out := {}
	for id in UNITS:
		var d: UnitDef = load(UNITS[id])
		if d == null:
			push_error("Catalog: missing %s" % UNITS[id])
			continue
		out[id] = d
	return out


## A ready-to-play battle on the given level.
static func new_battle(level_path: String = LEVELS[0], seed_value: int = 0) -> Battle:
	var b := Battle.new()
	b.setup(LevelLoader.load_file(level_path), load_units(), seed_value)
	return b
