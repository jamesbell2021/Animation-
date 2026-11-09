# Balancing

Where the game's numbers live, how a night is built, and the six checks to make while someone plays. Written from the code at v0.1.4.

## Where the numbers are

- **`autoload/balance.gd` (`Balance`)** holds what a designer tunes: the day's lengths, the lamp, each creature's hp and speed, what kills drop, the three seas, a keeper's speed and health, what a mend does and costs, the shed's and the cottage's prices. Scripts read from it (`const BASE_HP := Balance.CRAB_HP`), so a change there reaches the game, and the tests (`slice_camp_raid`, `slice_helpers`, `slice_economy` and others) check the results.
- **`scenes/systems/spawner.gd`** holds the night tables (below), the Eel's schedule and where the camp's share lands.
- **`scenes/systems/upgrades.gd`** holds the upgrade prices and what each level gives.
- **`scenes/systems/difficulty.gd`** reads the three seas from `Balance`.
- **`scenes/world/weather.gd`** holds the weather's chances and strengths.
- The finer constants (an animation's timing, a collider's size, a creature's attack timings) stay in the script they belong to; `docs/ENEMIES.md` lists the creatures'.
- `tools/playtest.gd` plays several nights with a bot and prints a line per night; `tests/smoke.gd` runs a whole run at 20 times speed.

## The numbers in `Balance`


### The day

| Constant | Value | Notes |
|---|---|---|
| `Balance.DAY_SECONDS` | `60.0` | Seconds in each part of the day. The night lengthens by NIGHT_STEP a night to NIGHT_CAP. |
| `Balance.DUSK_SECONDS` | `15.0` |  |
| `Balance.NIGHT_BASE` | `120.0` |  |
| `Balance.NIGHT_STEP` | `10.0` |  |
| `Balance.NIGHT_CAP` | `210.0` |  |
| `Balance.DAWN_SECONDS` | `30.0` |  |

### The lamp

| Constant | Value | Notes |
|---|---|---|
| `Balance.LAMP_FUEL_MAX` | `100.0` |  |
| `Balance.LAMP_BURN_WIDE` | `0.35` | Fuel burnt a second: the wide beam, and the focused beam that burns what it touches. |
| `Balance.LAMP_BURN_FOCUSED` | `1.0` |  |
| `Balance.LAMP_GUTTER_WINDOW` | `25.0` | Seconds of grace once the fuel runs out, guttering, before the lamp goes dark. |

### The creatures

| Constant | Value | Notes |
|---|---|---|
| `Balance.BLOATED_HP` | `60` |  |
| `Balance.BLOATED_SPEED` | `1.15` |  |
| `Balance.SQUID_HP` | `35` |  |
| `Balance.SQUID_DASH_SPEED` | `4.5` |  |
| `Balance.SQUID_CLIMB_SPEED` | `2.0` |  |
| `Balance.CRAB_HP` | `150` |  |
| `Balance.CRAB_SPEED` | `1.2` |  |
| `Balance.EEL_HP` | `90` |  |
| `Balance.SMOTHERER_HP` | `50` |  |
| `Balance.SMOTHERER_SPEED` | `1.4` |  |
| `Balance.SMOTHERER_CLIMB_SPEED` | `1.3` |  |
| `Balance.HP_PER_EXTRA_PERSON` | `0.2` | The Crab's and the Eel's hp grow this much for each person playing beyond the first. |

### What a kill leaves where it falls (the chance, or the amount)

| Constant | Value | Notes |
|---|---|---|
| `Balance.DROP_BLOATED_KELP_CHANCE` | `0.35` |  |
| `Balance.DROP_SQUID_BIO_CHANCE` | `0.5` |  |
| `Balance.DROP_CRAB_SCRAP` | `2` |  |
| `Balance.DROP_SMOTHERER_SCRAP_CHANCE` | `0.4` |  |

### The sea: calm, angry, raging

| Constant | Value | Notes |
|---|---|---|
| `Balance.SEA_CREATURES` | `[0.7, 1.0, 1.35]` | How many of each landing come ashore, against the night's table. |
| `Balance.SEA_KEEPER_DAMAGE` | `[0.6, 1.0, 1.3]` | What a creature's blow does to a keeper. |
| `Balance.SEA_NEEDS` | `[0.6, 1.0, 1.25]` | How fast hunger and cold set in. |
| `Balance.SEA_SHELLS` | `[10, 10, 6]` | Cartridges and rat poison the shed starts with. |
| `Balance.SEA_POISON` | `[4, 4, 2]` |  |

### A keeper

| Constant | Value | Notes |
|---|---|---|
| `Balance.KEEPER_HP` | `100` |  |
| `Balance.KEEPER_SPEED` | `4.5` |  |
| `Balance.KEEPER_SPRINT` | `6.5` |  |
| `Balance.KEEPER_SPRINT_MAX` | `3.0` | Seconds of sprint, then the wait before the next. |
| `Balance.KEEPER_SPRINT_COOLDOWN` | `2.0` |  |
| `Balance.KEEPER_JUMP_SPEED` | `4.4` |  |
| `Balance.KEEPER_GRAVITY` | `14.0` |  |
| `Balance.KEEPER_FLARES_MAX` | `2` |  |
| `Balance.REVIVE_HEALTH` | `0.4` | A revived keeper's health, and everyone's at dawn, as a fraction of the most. |
| `Balance.DAWN_HEALTH` | `0.5` |  |
| `Balance.HUNGER_RATE` | `0.18` | Hunger lost a second, and warmth lost a second out in the cold of night. |
| `Balance.COLD_NIGHT_RATE` | `0.12` |  |

### Mending (health a mend restores)

| Constant | Value | Notes |
|---|---|---|
| `Balance.MEND_DEFAULT` | `25` |  |
| `Balance.MEND_HOMESTEAD` | `50` |  |
| `Balance.MEND_FENCE` | `50` |  |
| `Balance.MEND_CAMP_HUT` | `70` |  |
| `Balance.MEND_CAMP_WIRE` | `60` |  |
| `Balance.MEND_GENERATOR` | `60` |  |
| `Balance.MEND_TURBINE` | `80` |  |
| `Balance.COST_MEND` | `{"driftwood": 1}` | What a default mend costs; the camp's wire, generator and turbine take a scrap, or a driftwood when there's no scrap, and a hut a driftwood. |

### The shed's workbench

| Constant | Value | Notes |
|---|---|---|
| `Balance.COST_FLAMER` | `{"scrap": 2}` |  |
| `Balance.COST_BOW` | `{"driftwood": 3, "seaweed": 1}` |  |
| `Balance.COST_ARROWS` | `{"driftwood": 1, "scrap": 1}` |  |
| `Balance.ARROWS_MADE` | `5` |  |
| `Balance.COST_BOMBS` | `{"bio": 1, "seaweed": 1}` |  |
| `Balance.BOMBS_MADE` | `2` |  |

### The cottage

| Constant | Value | Notes |
|---|---|---|
| `Balance.COST_MEAL` | `{"food": 1}` |  |
| `Balance.MEAL_MAX_HEALTH_GAIN` | `10` |  |
| `Balance.COST_FLARE` | `{"scrap": 1}` |  |
| `Balance.COST_MIX_FUEL` | `{"oil": 1, "driftwood": 1}` |  |
| `Balance.MIX_FUEL_YIELD` | `2` |  |
| `Balance.COST_EGGS_MEAL` | `{"eggs": 3}` |  |
| `Balance.COST_BROTH` | `{"seaweed": 3}` |  |

## How a night is built (`scenes/systems/spawner.gd`)

`NIGHT_TABLES` gives each night from 1 to 8 a list of landings: `[when, kind, count]`, where `when` is the fraction of the night, the kind is B (Bloated), S (Squid), C (Crab) or M (Smotherer), and `"opp"` means it lands on a different beach from the night's first group. Nights past 8 reuse night 7's table. The table's counts are then changed by:

- **The sea:** `Balance.SEA_CREATURES` (0.7 calm, 1.0 angry, 1.35 raging) times the count.
- **Anger:** `floor(Anger / 3)` extra in each group.
- **Late nights:** from night 9, `floor((n - 7) / 2)` extra in each group.
- **The last night before the relief boat:** about 30% more (`Rescue.LAST_NIGHT_SURGE`), at least one more per group.
- **The Eel:** on night 6 and every third night after it (night 5 and every third with more than one person; one night earlier if Anger is 6 or more), landing at 0.42 of the night; other landings shrink to a quarter while it is about (`EEL_RATE`).
- **The camp:** from night 2, every third group of B, S or C lands on the holm and makes for the camp, from night 5 every other one; none are sent once the camp has fallen.
- **The homestead:** from night 2 the second and later Bloated groups make for the cottage, shed and garden.

A landing is announced 4 seconds ahead (the water churns and the foghorn sounds), then the creatures come out 0.3 seconds apart.

## Anger (`autoload/anger.gd`)

A hidden number from 0 to 10, shown only as the sea's mood on the HUD ("quiet", "restless", "angry", "wants the light"). It rises by 1 for each structure destroyed and each pour of dirty fuel, and by 2 for a full Eel coil; it falls by 1 for driving the Eel off early. In a night it can only move between -1 and +2, and at dawn it falls by 1 (2 if three or more structures were damaged). It adds creatures (above) and can bring the Eel a night early.

## The six checks

Make these while someone plays (or read `user://telemetry.jsonl` after; see `docs/TELEMETRY.md`):

1. **Do the nights feel the same?** If so the spawn table is the problem, not the count: vary the order and the beaches before adding creatures.
2. **Does anyone use the focused beam?** If not, the Squid isn't threatening enough or the switch isn't readable. Fix it with a stronger tell, not more damage.
3. **Does anyone plant the garden?** If not, its payoff is too slow or too hidden. A bed sown by day pays by dawn; a keeper must eat at the cottage to gain from it.
4. **Do runs end around the same night?** A cliff in difficulty kills "one more run". Look at the night in each `run_end` line and smooth the steepest step.
5. **Do the people all stand at the lighthouse?** The camp and the beaches should be worth defending at a distance. Watch whether anyone goes to the holm unprompted, and how often the camp falls.
6. **Is the camp kept up?** At v0.1.1 the bot's camp stood wrecked from night 4; cheaper mends fixed that. Check `structures_lost` per night and whether the generator is running at dusk.

Each is a question about the player, not the numbers, so change one thing and play again before changing a second.
