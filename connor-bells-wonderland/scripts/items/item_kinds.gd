class_name ItemKinds
extends RefCounted
## Definitions for the Fairground Mayhem items. Plain data so kinds can be
## sent over the network as ints.
## mode: "trap" (placed behind you), "melee" (hits targets in front),
## "burst" (around you), "throw" (lobbed projectile), "self" (buff on you).

enum Kind {
	NONE, CATAPULT, BOXING_GLOVE, ZAPPER, SPRINGER, SWORD, OIL_SLICK, CONFETTI, CAKE,
	SHRINK_POTION, ROCKET_BOOTS, BALLOON, MAGNET, PIE, SHIELD,
}

const DEFS := {
	Kind.CATAPULT: {"name": "Catapult", "mode": "trap", "uses": 1, "colour": Color(0.55, 0.35, 0.15),
		"launch_up": 14.0, "launch_back": 12.0, "stumble": 1.8},
	Kind.BOXING_GLOVE: {"name": "Big Boxing Glove", "mode": "trap", "uses": 1, "colour": Color(0.9, 0.1, 0.1),
		"punch": 14.0, "launch_up": 5.0, "stumble": 1.5},
	Kind.SPRINGER: {"name": "Big Springer", "mode": "trap", "uses": 1, "colour": Color(0.2, 0.8, 0.3),
		"launch_up": 22.0, "stumble": 1.2},
	Kind.OIL_SLICK: {"name": "Slippery Oil", "mode": "trap", "uses": 1, "colour": Color(0.15, 0.1, 0.2),
		"lifetime": 12.0, "effect_seconds": 4.0},
	Kind.CAKE: {"name": "Big Fatty Cake", "mode": "trap", "uses": 1, "colour": Color(1.0, 0.6, 0.8),
		"effect_seconds": 6.0},
	Kind.SHRINK_POTION: {"name": "Shrink Potion", "mode": "trap", "uses": 1, "colour": Color(0.4, 0.9, 0.6),
		"effect_seconds": 6.0},
	Kind.ZAPPER: {"name": "Zapper", "mode": "melee", "uses": 3, "colour": Color(0.2, 0.8, 1.0),
		"range": 3.5, "cone": 0.4, "stumble": 1.6, "cooldown": 0.8},
	Kind.SWORD: {"name": "Plastic Sword", "mode": "melee", "uses": 3, "colour": Color(1.0, 0.5, 0.1),
		"range": 2.2, "cone": 0.2, "knock": 12.0, "launch_up": 5.0, "stumble": 1.5, "cooldown": 0.5},
	Kind.BALLOON: {"name": "Balloon", "mode": "melee", "uses": 2, "colour": Color(1.0, 0.3, 0.5),
		"range": 3.0, "cone": 0.3, "effect_seconds": 2.5, "cooldown": 0.8},
	Kind.PIE: {"name": "Custard Pie", "mode": "throw", "uses": 2, "colour": Color(1.0, 0.85, 0.4),
		"speed": 11.0, "arc": 6.0, "radius": 1.6, "knock": 9.0, "launch_up": 5.0, "stumble": 1.3, "cooldown": 0.7},
	Kind.CONFETTI: {"name": "Confetti Bomb", "mode": "burst", "uses": 1, "colour": Color(0.9, 0.3, 0.9),
		"radius": 4.5, "knock": 10.0, "launch_up": 6.0, "stumble": 1.2, "cooldown": 0.5},
	Kind.ROCKET_BOOTS: {"name": "Rocket Boots", "mode": "self", "uses": 1, "colour": Color(1.0, 0.45, 0.1),
		"effect_seconds": 3.0},
	Kind.MAGNET: {"name": "Giant Magnet", "mode": "self", "uses": 1, "colour": Color(0.85, 0.1, 0.1),
		"effect_seconds": 5.0},
	Kind.SHIELD: {"name": "Shield Bubble", "mode": "self", "uses": 1, "colour": Color(0.5, 0.8, 1.0),
		"effect_seconds": 15.0},
}

const RANDOM_POOL: Array[Kind] = [
	Kind.CATAPULT, Kind.BOXING_GLOVE, Kind.ZAPPER, Kind.SPRINGER, Kind.SWORD, Kind.OIL_SLICK,
	Kind.CONFETTI, Kind.CAKE, Kind.SHRINK_POTION, Kind.ROCKET_BOOTS, Kind.BALLOON, Kind.MAGNET,
	Kind.PIE, Kind.SHIELD,
]


static func get_def(kind: int) -> Dictionary:
	return DEFS.get(kind, {})


static func display_name(kind: int) -> String:
	return str(get_def(kind).get("name", "Nothing"))


static func mode_of(kind: int) -> String:
	return str(get_def(kind).get("mode", "none"))


static func is_trap(kind: int) -> bool:
	return mode_of(kind) == "trap"


static func uses_for(kind: int) -> int:
	return int(get_def(kind).get("uses", 1))


static func colour_for(kind: int) -> Color:
	return get_def(kind).get("colour", Color.WHITE)


static func cooldown_for(kind: int) -> float:
	return float(get_def(kind).get("cooldown", 0.5))


static func random_kind() -> Kind:
	return RANDOM_POOL[randi() % RANDOM_POOL.size()]
