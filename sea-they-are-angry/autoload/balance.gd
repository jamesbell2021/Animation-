class_name Balance
extends RefCounted
## The numbers a designer tunes, in one place: the length of the day, how tough and quick
## each creature is, what the sea does at each difficulty, what things cost, how much a
## mend does, and how likely a kill is to leave something. The scripts that use them
## read them from here (`const HP := Balance.BLOATED_HP`), so changing one number here
## changes it everywhere, and docs/BALANCING.md lists what each does.
##
## Not everything is here: the night tables are in scenes/systems/spawner.gd, the upgrade
## prices in scenes/systems/upgrades.gd, the weather's chances in scenes/world/weather.gd,
## and the finer-grained constants (an animation's timing, a collider's size) stay with
## the code they belong to.

# ---- the day ----
## Seconds in each part of the day. The night lengthens by NIGHT_STEP a night to NIGHT_CAP.
const DAY_SECONDS := 60.0
const DUSK_SECONDS := 15.0
const NIGHT_BASE := 120.0
const NIGHT_STEP := 10.0
const NIGHT_CAP := 210.0
const DAWN_SECONDS := 30.0

# ---- the lamp ----
const LAMP_FUEL_MAX := 100.0
## Fuel burnt a second: the wide beam, and the focused beam that burns what it touches.
const LAMP_BURN_WIDE := 0.35
const LAMP_BURN_FOCUSED := 1.0
## Seconds of grace once the fuel runs out, guttering, before the lamp goes dark.
const LAMP_GUTTER_WINDOW := 25.0

# ---- the creatures ----
const BLOATED_HP := 60
const BLOATED_SPEED := 1.15
const SQUID_HP := 35
const SQUID_DASH_SPEED := 4.5
const SQUID_CLIMB_SPEED := 2.0
const CRAB_HP := 150
const CRAB_SPEED := 1.2
const EEL_HP := 90
const SMOTHERER_HP := 50
const SMOTHERER_SPEED := 1.4
const SMOTHERER_CLIMB_SPEED := 1.3
## The Crab's and the Eel's hp grow this much for each person playing beyond the first.
const HP_PER_EXTRA_PERSON := 0.2

# ---- what a kill leaves where it falls (the chance, or the amount) ----
const DROP_BLOATED_KELP_CHANCE := 0.35
const DROP_SQUID_BIO_CHANCE := 0.5
const DROP_CRAB_SCRAP := 2
const DROP_SMOTHERER_SCRAP_CHANCE := 0.4

# ---- the sea: calm, angry, raging ----
## How many of each landing come ashore, against the night's table.
const SEA_CREATURES := [0.7, 1.0, 1.35]
## What a creature's blow does to a keeper.
const SEA_KEEPER_DAMAGE := [0.6, 1.0, 1.3]
## How fast hunger and cold set in.
const SEA_NEEDS := [0.6, 1.0, 1.25]
## Cartridges and rat poison the shed starts with.
const SEA_SHELLS := [10, 10, 6]
const SEA_POISON := [4, 4, 2]

# ---- a keeper ----
const KEEPER_HP := 100
const KEEPER_SPEED := 4.5
const KEEPER_SPRINT := 6.5
## Seconds of sprint, then the wait before the next.
const KEEPER_SPRINT_MAX := 3.0
const KEEPER_SPRINT_COOLDOWN := 2.0
const KEEPER_JUMP_SPEED := 4.4
const KEEPER_GRAVITY := 14.0
const KEEPER_FLARES_MAX := 2
## A revived keeper's health, and everyone's at dawn, as a fraction of the most.
const REVIVE_HEALTH := 0.4
const DAWN_HEALTH := 0.5
## Hunger lost a second, and warmth lost a second out in the cold of night.
const HUNGER_RATE := 0.18
const COLD_NIGHT_RATE := 0.12

# ---- mending (health a mend restores) ----
const MEND_DEFAULT := 25
const MEND_HOMESTEAD := 50
const MEND_FENCE := 50
const MEND_CAMP_HUT := 70
const MEND_CAMP_WIRE := 60
const MEND_GENERATOR := 60
const MEND_TURBINE := 80
## What a default mend costs; the camp's wire, generator and turbine take a scrap, or a
## driftwood when there's no scrap, and a hut a driftwood.
const COST_MEND := {"driftwood": 1}

# ---- the shed's workbench ----
const COST_FLAMER := {"scrap": 2}
const COST_BOW := {"driftwood": 3, "seaweed": 1}
const COST_ARROWS := {"driftwood": 1, "scrap": 1}
const ARROWS_MADE := 5
const COST_BOMBS := {"bio": 1, "seaweed": 1}
const BOMBS_MADE := 2

# ---- the cottage ----
const COST_MEAL := {"food": 1}
const MEAL_MAX_HEALTH_GAIN := 10
const COST_FLARE := {"scrap": 1}
const COST_MIX_FUEL := {"oil": 1, "driftwood": 1}
const MIX_FUEL_YIELD := 2
const COST_EGGS_MEAL := {"eggs": 3}
const COST_BROTH := {"seaweed": 3}
