class_name Upgrades
extends RefCounted
## The three upgrade paths bought at the cottage, each level 1 to 3, and everything
## they change. Levels live in Run.upgrades (saved). Upgrades.apply() pushes the
## current levels out to the lighthouse, the lamp, the fences, the trap slots and the
## garden, and runs after every purchase and at the start of a run.

const MAX_LEVEL := 3
const PATHS := ["lighthouse", "defences", "garden"]
const TITLES := {"lighthouse": "Lighthouse", "defences": "Defences", "garden": "Garden"}
# Cost to reach level 2 and level 3.
const COSTS := {
	"lighthouse": [{"scrap": 4, "bio": 2}, {"scrap": 8, "bio": 4}],
	"defences": [{"driftwood": 6, "scrap": 2}, {"driftwood": 8, "scrap": 5}],
	"garden": [{"driftwood": 4, "seaweed": 3}, {"driftwood": 6, "seaweed": 6}],
}
const BLURBS := {
	"lighthouse": "tougher tower, longer beam, hotter focus, thriftier wick",
	"defences": "stronger fences, more trap slots, crueller traps",
	"garden": "more plots, more health from food, faster revives",
}

# Lighthouse: tower health, beam range bonus (m), focused damage and fuel burn multipliers.
const LIGHTHOUSE_HP := [200, 400, 600]
const RANGE_BONUS := [0.0, 3.0, 6.0]
const FOCUS_MULT := [1.0, 1.5, 2.0]
const BURN_MULT := [1.0, 0.85, 0.7]
# Defences: fence health, trap slots open, trap damage multiplier.
const FENCE_HP := [100, 200, 300]
const TRAP_SLOTS := [3, 4, 5]
const TRAP_DMG := [1.0, 1.5, 2.0]
# Garden: plots, cap on max health gained from food, revive time (s).
const PLOTS := [3, 4, 5]
const MAXHP_CAP := [10, 20, 30]
const REVIVE_TIME := [3.0, 2.5, 2.0]

static func level(path: String) -> int:
	return clampi(int(Run.upgrades.get(path, 1)), 1, MAX_LEVEL)

## Value from a per-level table for the current level of a path.
static func pick(path: String, table: Array) -> Variant:
	return table[level(path) - 1]

static func next_cost(path: String) -> Dictionary:
	var l := level(path)
	if l >= MAX_LEVEL:
		return {}
	return COSTS[path][l - 1]

## What the next level brings, in a few words.
static func next_blurb(path: String) -> String:
	var l := level(path)
	if l >= MAX_LEVEL:
		return ""
	match path:
		"lighthouse":
			return "tower %d, beam +%d m, focus burns ×%.1f, %d%% less oil" % [LIGHTHOUSE_HP[l], roundi(RANGE_BONUS[l]), FOCUS_MULT[l], roundi((1.0 - BURN_MULT[l]) * 100.0)]
		"defences":
			return "fences %d, %d trap slots, traps ×%.1f" % [FENCE_HP[l], TRAP_SLOTS[l], TRAP_DMG[l]]
		"garden":
			return "%d beds, meals up to +%d max health, revive in %.1fs" % [PLOTS[l], MAXHP_CAP[l], REVIVE_TIME[l]]
	return ""

static func buy(path: String, tree: SceneTree) -> bool:
	var cost := next_cost(path)
	if cost.is_empty() or not Stock.spend(cost):
		return false
	Run.upgrades[path] = level(path) + 1
	apply(tree)
	Audio.sfx("repair", Vector3.INF, 0.0, 0.0)
	Events.message.emit("%s upgraded to level %d" % [TITLES[path], level(path)])
	return true

static func apply(tree: SceneTree) -> void:
	Lamp.focus_mult = pick("lighthouse", FOCUS_MULT)
	for s in tree.get_nodes_in_group("structures"):
		if s is Lighthouse:
			_set_max_hp(s, pick("lighthouse", LIGHTHOUSE_HP))
			s.set_level(level("lighthouse"))
			if s.lamp:
				s.lamp._apply_mode()
		elif s is Fence:
			_set_max_hp(s, pick("defences", FENCE_HP))
			s.set_level(level("defences"))
		elif s is Garden:
			s.set_plots(pick("garden", PLOTS))
	for slot in tree.get_nodes_in_group("trap_slots"):
		slot.set_unlocked(slot.index < pick("defences", TRAP_SLOTS))

# Raise (or set) max health, keeping the same fraction of it.
static func _set_max_hp(s: Structure, new_max: int) -> void:
	if s.max_hp == new_max:
		return
	var ratio := s.health_ratio()
	s.max_hp = new_max
	s.hp = roundi(new_max * ratio)
	s.health_changed.emit(s.hp, s.max_hp)
	s._refresh()
