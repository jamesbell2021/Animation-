class_name Difficulty
extends RefCounted
## How hard the sea is, chosen on the title screen and kept with the run (Run.difficulty).
## Calm: fewer creatures, keepers hurt less and tire slower, and ammunition never runs
## out (cartridges, arrows, petrol bombs, the flamer's tank, flares). Angry is the game
## as balanced. Raging: more creatures, harder blows, quicker hunger and cold, and fewer
## cartridges and less rat poison in the shed.

enum Level { CALM, ANGRY, RAGING }

const NAMES := ["Calm sea", "Angry sea", "Raging sea"]
const BLURBS := ["easy: fewer of them, and ammunition never runs out", "the game as it's meant", "hard: more of them, and they hit harder"]
const CREATURES := [0.7, 1.0, 1.35]
const KEEPER_DAMAGE := [0.6, 1.0, 1.3]
const NEEDS := [0.6, 1.0, 1.25]
const SHELLS := [10, 10, 6]
const POISON := [4, 4, 2]

static func level() -> int:
	return clampi(Run.difficulty, 0, NAMES.size() - 1)

static func name() -> String:
	return NAMES[level()]

## How many of each landing come ashore, against the night's table.
static func creatures() -> float:
	return CREATURES[level()]

static func keeper_damage() -> float:
	return KEEPER_DAMAGE[level()]

static func needs() -> float:
	return NEEDS[level()]

## Easy: shooting, throwing, burning and flares cost nothing.
static func free_ammo() -> bool:
	return level() == Level.CALM
