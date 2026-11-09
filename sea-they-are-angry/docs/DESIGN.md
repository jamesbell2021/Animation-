# Design

The game as the code has it at v0.1.4 (Chapter One). Where `README.md`, `docs/DECISIONS.md` or the plans in `docs/prompts/` disagree with the code, this file follows the code and says so. File paths are given so any number can be checked. `docs/ENEMIES.md` covers the creatures; `docs/ARCHITECTURE.md` covers how it is built.

## Premise

Sea They Are Angry is a top-down 3D survival game (Godot 4.3, GDScript; version 1.0.0; this file describes Chapter One, the rock, and `docs/CHAPTER_TWO.md` describes Kirkhaven). You are a lighthouse keeper on a small North Sea rock in the late 1980s (`README.md`). By day you gather, mend, plant and prepare; at dusk the fog comes in and drowned things walk up out of the sea toward the light. If the lamp goes dark, or every keeper is down, the run is over. Hold out until the relief boat comes and the chapter ends. The three keepers are Callum MacLeod (principal keeper), Hamish Fraser (engineer) and Mairi Campbell (gardener and runner); `Players.NAMES` also lists Ewan Reid, who has a model but cannot be in a run (`Players.MAX` is 3).

Setting beyond the rock: the holm beside it holds the camp of an internment camp from 1940 to 1945 (the eight diary pages in `scenes/systems/lore.gd` are the internees' voices: Germans, Italians, an Austrian, guards, a sergeant, and what came up the beaches). The relief boat is the *Mary Ann*, a Kirkhaven motor drifter. There is no `docs/STORY.md` in this project; the story is `README.md`, `lore.gd`, `scenes/ui/chapter_end.gd` and `docs/RELEASE_NOTES_v0.1.*.md`.

## The loop

One day is `Cycle` phases DAY (60 s), DUSK (15 s), NIGHT (120 s, plus 10 s for each night after the first, up to 210 s), DAWN (30 s) (`autoload/cycle.gd`). Enter skips the rest of a day or dawn.

- **Day:** gather salvage, mend what the night broke, sow, eat, buy upgrades, set traps, work at the shed's bench, row to Gull Rock, research at the camp, fill the lamp and the generator.
- **Dusk:** foghorn (two long blasts), the lamp lights, the weather for the night is applied, the day's salvage on the ground is taken back by the sea.
- **Night:** creatures land in groups on the beaches on a per-night schedule; somebody works the lamp; the rest fight, repair under pressure, hold the ledge. The HUD shows the weather and the sea.
- **Dawn:** survivors retreat to the sea; downed keepers get up at half health; the lamp goes out; scavenge points, gull nests and crops refresh; an oil drum or tin of cartridges may wash up; the keeper's log (`Main._dawn_report`) says what came, how it was stopped and what it cost; research completes; the run is saved.
- **The boat:** `Rescue.NIGHTS` is `[8, 10, 12]` for calm, angry and raging seas, two fewer once the camp's wireless is mended. At the dawn after that night the *Mary Ann* steams in to the east beach and waits (up to 150 s for helpers); everyone goes aboard (E at her plank) and she sails. The last night's landings are about 30% bigger (`LAST_NIGHT_SURGE`). On the angry sea the whole chapter is about 45 minutes of game time (computed from the cycle durations).
- **Endless:** the end card offers "Stay on the rock": the same run continues with `Run.endless = true`, no boat, no countdown, nights keep the night 7 pattern with `floor((n-7)/2)` more creatures per group.
- **Losing:** `Run.end_run` for "The lamp went dark.", "The keeper has fallen." (only if `Players.count()` is 1, that is, helpers off, as in tests) or "Every keeper is down.". The save is deleted and the best night kept. A destroyed lighthouse does not end the run at once: the lamp gutters for 25 s (`GUTTER_WINDOW`) and goes dark unless fuelled and the tower repaired.

## The three islands

- **The main island:** a meadow ringed by cliffs, three shingle beaches where creatures land (the jetty is on the east one), and a crag in the middle with the lighthouse on top. The only way up is the ledge path round the crag, with two fences on it (`LEDGE_FENCES`), and a ladder pair for keepers (creatures cannot use them). A cottage, shed, garden and campfire are in the meadow. Three fences close the beach heads; five in all at level 1.
- **The holm:** to the east across an 18 m rope bridge (`scenes/structures/rope_bridge.gd`: sags 0.6 m, bounces and sways). The old camp is on it: a wire compound with a guard tower and searchlight at each corner, two Nissen huts (the quarters with a stove, the mess with a table and the research desk), a greenhouse, three outdoor beds, a brick generator house, a gate facing the bridge, and a wind turbine on a knoll outside the wire. It has two landing beaches.
- **Gull Rock:** a small whinstone stack to the north-east, with six gull nests. Reached by the rowing boat from the east jetty. Nothing attacks it; it is only a place to be out in the daytime.

The camera frames whichever island you are on; see `docs/ARCHITECTURE.md` for the split screen.

## Resources (`autoload/stock.gd` `KINDS`)

Start of a run: 4 driftwood, 1 bio, 3 seeds, 10 cartridges (6 on a raging sea), 4 rat poison (2 raging), nothing else.

| Kind | Where it comes from | What it is for |
|---|---|---|
| driftwood | beach points, boxes washed up | repairs (fences, cottage, shed, huts), traps, stove and campfire fuel, arrows, bow, upgrades |
| scrap | beach points, Crab (2), Smotherer (40%: 1), Eel (2) | repairing the lighthouse (with driftwood), flares, flamer, research, chain plates, wire, camp repairs when there is any |
| seaweed (kelp) | beach points, Bloated (35%: 1) | planting garden beds, nets, bow, petrol bombs, kelp broth, mending the garden, poison bait |
| bio | beach points, Squid (50%), Eel (3) | the lamp's fuel (1 bio = 40 of 100), the flamer's tank, petrol bombs, some research |
| food | garden, camp beds, eggs, broth | meals |
| oil | one drum washes up at dawn after nights 2, 5, 8... | mixed into dirty fuel |
| dirty_fuel | cottage: 1 oil + 1 driftwood makes 2 | poured into the lamp |
| diesel | jerrycans on the holm's beaches | the camp generator (1 can = 35 of 100) |
| seeds | start with 3, saved from camp harvests | sowing camp beds |
| notes | tins of the internees' papers about the camp (two lying at a time, one more each dawn) | each research project costs one |
| arrows, bombs | made at the shed (5 arrows for 1 driftwood + 1 scrap; 2 bombs for 1 bio + 1 kelp) | bow, petrol bombs |
| shells | start box of 10, a tin of 3 after nights 3, 6, 9... | shotgun |
| poison | start 4 tins | rat-poison bait at a trap cairn |
| eggs | gull nests (0 to 3 each each dawn) | 3 eggs boil into 1 food |

Scavenge points (`Main.SCAVENGE`) on the main island's beaches are 8 (a ninth appears when three people play; the README's "seven" is out of date); the holm has 4. Each can be gathered once a day and refills at dawn; oil, cartridge tins and notes are one-off. Creatures leave salvage where they fall (`Salvage`); walking near it picks it up, and the sea takes what is left at dusk.

## The lamp and fuel (`scenes/systems/lamp.gd`)

The lamp lights at dusk if there is fuel and goes out at dawn. States: `OFF`, `BURNING`, `GUTTERING`, `DARK`. Fuel is 0 to 100. Burn per second: 0.35 wide, 1.0 focused, times 0.8 when nobody is on the lamp (it then sweeps by itself at 20 degrees a second), times the lighthouse upgrade (1.0, 0.85, 0.7). At zero fuel it gutters for 25 s; refuelling (1 bio, +40) or repairing the tower while it gutters relights it; at 25 s it is dark and the run ends.

Working the lamp: walk to the lighthouse door (within 3.8 m) and press R; the keeper goes in and aims with the mouse or stick; Q switches wide (35 degree half-angle, 26 m) and focused (10 degrees, 29 m). Range grows by 3 and 6 m at upgrade levels 2 and 3. Only one keeper can work it. Dirty fuel: +30 fuel, the beam burns 1.5 times harder and the light is 1.3 times brighter for 30 s, and Anger +1. A Smotherer on the lantern cuts the beam's range to 30% and brightness to 12%. A badly damaged lighthouse (under 30%) makes the light flicker and the screen pulse red.

The beam is also how you slow and burn creatures; effects per creature are in `docs/ENEMIES.md`. 

## Buildings and repair

A keeper repairs with the hammer (three strikes) by pressing E at a damaged building. One repair restores: fences 50 (1 driftwood), cottage and shed 50 (1 driftwood), garden 50 (driftwood and kelp), lighthouse 25 (driftwood and scrap), camp huts and greenhouse 70 (driftwood), generator and wire 60 (a scrap if there is one, else driftwood), turbine 80 (same), sandbag wall 60 (driftwood). Health: lighthouse 200/400/600 by upgrade, fences 100/200/300, cottage 150, shed 120, garden 100, generator 120, turbine 160, huts 220, greenhouse 150, wire 120, sandbags 160. Below 45% a building smokes. A wrecked building stops working (the cottage cannot be entered, the shed's bench is shut, a wrecked mess has no table or research, a wrecked greenhouse loses its crop) until mended. Each structure destroyed raises the sea's anger by 1.

The cottage menu (E at the door; walk inside): eat (1 food: full health, hunger to 100, +10 max health up to the garden cap of 10/20/30), boil gull eggs, boil kelp broth (3 kelp for 1 food), load a flare (1 scrap, max 2 each), mix dirty fuel, and the three upgrades:

| Path | Level 2 cost | Level 3 cost | Effect (levels 1, 2, 3) |
|---|---|---|---|
| Lighthouse | 4 scrap, 2 bio | 8 scrap, 4 bio | hp 200/400/600; beam +0/+3/+6 m; focused burn x1/1.5/2; fuel burn x1/0.85/0.7 |
| Defences | 6 driftwood, 2 scrap | 8 driftwood, 5 scrap | fence hp 100/200/300; trap cairns 3/4/5; trap strength x1/1.5/2 |
| Garden | 4 driftwood, 3 kelp | 6 driftwood, 6 kelp | beds 3/4/5; max-health cap 10/20/30; revive time 3/2.5/2 s |

**Traps** (`scenes/structures/trap_slot.gd`): a cairn on a creature path, opened from the menu. The first three are on the beaches, the fourth halfway up the ledge and the fifth at its foot (opened by Defences levels 2 and 3); the holm has four posts that are open from the start. Spike board (2 driftwood, 3 uses): 25 damage, a Bloated bursts at once, Squid skitter over it. Kelp net (1 driftwood, 1 kelp, 2 uses): tangles a Bloated, Squid or Smotherer for 3 s, Crabs ignore it. Chain plate (1 driftwood, 2 scrap, 2 uses): flips a Crab for 3 s and doubles keeper damage to it for 5 s. Rat poison (1 tin, 1 kelp, 3 uses): 14 s of poison, not for Squid. Researched: barbed wire, tripwire flare (40 damage), sandbag wall (160 hp). A Crab's slam wrecks a set trap in front of it.

## Weapons (the shed's workbench, `scenes/structures/shed.gd`, `scenes/player/arsenal.gd`)

Everyone has the **boathook** (20 damage, 2.5 m, 60 degree arc, 0.6 s). The shed's bench adds four more, picked with Tab, the wheel, or keys 1 to 5 (`Arsenal.ORDER`: hook, bow, shotgun, flamer, bombs):

- **Longbow:** made for 3 driftwood and 1 kelp, one per keeper (a helper can have one too). Hold to draw (0.8 s, movement at half speed), release to loose: 12 to 40 damage, range 26 m. Arrows cost 1 each.
- **Double-barrelled shotgun:** one gun on the wall, taken and left at the bench. Two barrels, then a 1.6 s reload; 9 pellets of 7 (11 within 3.5 m) in a 24 degree cone out to 11 m; knocks the keeper back. Cartridges are shared.
- **Flamer:** the weed burner rigged for 2 scrap, one only. Hold to burn: 34 a second to 5.5 m, whatever is in the stream stops and burns on for 2.5 s. The tank holds 100 and empties in about six seconds; it refills from the store's bio (1.5 s). Movement x0.6 while burning.
- **Petrol bombs:** 20 damage, set alight, and a pool of fire (2.3 m, 7 s, 16 a second). Range 12 m, 0.8 s between throws.

On a calm sea ammunition, arrows, bombs, the flamer's tank and flares are free. A keeper also has a **flare gun** (right mouse; 2 flares, 40 damage on a hit, burns 8 s and lights like the wide beam) and the **harpoon** (the boathook thrown at a Smotherer on the tower). The lighthouse helper takes the shotgun off the wall if nobody has it and uses a bow if one was made for it; helpers leave the flamer and bombs to people.

## Survival needs (`scenes/player/player.gd`)

Hunger falls 0.18 a second (x1.5 sprinting) and warmth falls outdoors at dusk and night, 0.12 a second times 1.0, 1.6 or 2.2 for a clear, squally or stormy night; by day outdoors it rises 0.25 a second, indoors 0.6, and beside a fire more (cottage door 2, campfire 3 lit, camp stove 3). Both are scaled by the sea (0.6, 1.0, 1.25). Below 25 a keeper is slower (hungry x0.85, cold x0.9, and cold swings 25% slower); at zero they lose 1 health every 2.5 s. Meals: the cottage (above), the mess table (1 food: fed and +30 health, no max health), the campfire (1 driftwood: +30 health), the camp stove (1 driftwood burns 260 s). Keepers start with 100 health. A keeper at zero is downed (everyone gets up at dawn at half health); a teammate holds E within 1.5 m for 3, 2.5 or 2 s to revive them at 40%.

Food: five garden beds in the cottage garden (3/4/5 open; 1 kelp plants one, ripe by dawn, 1 food; a hit on the garden ruins a bed), three camp beds (1 seed, 2 food, half the time a storm night flattens them) and the greenhouse (1 seed, 3 food, safe from weather), gull eggs and kelp broth. Research adds a food per harvest (tinning) and two more from the greenhouse (cold frames, which also stop storm damage to the beds).

## The camp and the holm

The generator (`scenes/structures/generator.gd`) runs from dusk to dawn: fuel 100, 35 per jerrycan, 0.03 a second idle plus each searchlight 0.1 wide or 0.2 focused and each lit hut 0.015 (about 0.45 a second with four wide lights, computed, not measured); the governor research cuts it by a third. It powers four searchlights and the huts' lights; dry or wrecked, the camp is dark. Searchlights (`scenes/systems/searchlight.gd`) sweep by themselves, or a keeper climbs a tower's ladder and presses E to aim one (16 degree half-angle wide beam, 6 degree focused, 34 m); tracking and reflectors are research. The turbine lights the strings round the wire from dusk to dawn while it stands (creatures inside the lit wire go 15% slower); wrecked, the compound goes dark.

Raids: from night 2 some groups land on the holm and make for the generator, quarters, mess and greenhouse (details in `docs/ENEMIES.md`). With the generator and all three buildings wrecked "the camp has fallen" and nothing more is sent there. This does not end the run. Research (the desk in the mess, one project at a time, begun by day and done by dawn): ten projects (`scenes/systems/research.gd`): clockwork tracking, silvered reflectors (+5 m, burn x1.6), generator governor, barbed-wire coils, tripwire flares, sandbag walls, cold frames, tinning, alarm bell, and the wireless (relief boat two nights sooner). Each costs one page of notes and a few scrap, bio or driftwood.

## Weather and the sea's anger

`Weather.tonight()` rolls the night's weather from the run's seed: night 1 is always clear; after that storm with chance 0.2 + 0.04 x Anger (up to 0.6), squalls 0.35, otherwise clear. A storm means driving rain, gusts, breakers, lightning, pale figures in the surf; it makes outdoors colder and flattens camp beds, and the sea is still too rough to row out at the dawn after it. Anger (0 to 10, hidden; `autoload/anger.gd`): +1 for each structure destroyed and for dirty fuel, +2 when the Eel finishes its coil, -1 when it is killed (all clamped to -1..+2 over a night), then -1 at dawn, or -2 if 3 or more structures were damaged. It adds `floor(Anger / 3)` creatures to every group, raises the storm chance, brings the Eel a night early at 6 or more, and the HUD says it in words ("The sea is quiet", "restless", "angry", "wants the light").

## Difficulty seas (`scenes/systems/difficulty.gd`)

Chosen on the title screen, kept with the run.

| | Calm | Angry | Raging |
|---|---|---|---|
| Creatures per group | x0.7 | x1.0 | x1.35 |
| Damage to keepers | x0.6 | x1.0 | x1.3 |
| Hunger and cold | x0.6 | x1.0 | x1.25 |
| Cartridges / rat poison at start | 10 / 4 | 10 / 4 | 6 / 2 |
| Ammunition | never runs out | normal | normal |
| Boat after night | 8 | 10 | 12 |

## Gull Rock and the rowing boat

`scenes/world/rowing_boat.gd`: E at the jetty's foot pushes off with that keeper at the oars; anyone who presses E in the next 1.4 s climbs in (up to three). It rows at 2.6 m/s along a channel and lands them at the rock's slip. Rowing out is allowed in DAY or DAWN and only while `Weather.storm_now` is 0.32 or less (the day's level is 0.12 whatever the night was; dawn after a storm night is 0.35, so it is refused then); rowing back is always allowed. The boat hangs on a haul line, so E at either end brings the empty boat across. On the rock: six nests (`scenes/world/gull_nest.gd`), each with 0, 1, 2 or 3 eggs at dawn (25%, 30%, 30%, 15%); E takes them; the colony mobs the taker (harmless). If a person is still out there at dusk the HUD warns. Gulls (`gull_flocks.gd`) fly everywhere by day, fly out to sea at dusk and stay away at night and in a storm. The README says the crossing takes about 12 seconds; the code only gives the speed.

## Keepers, helpers, co-op and LAN

There are always three keepers. Pick 1 to 3 people on the title; the rest are helpers (`scenes/player/keeper_ai.gd`): the light helper gathers and mends by day, works the lamp at night (or holds the ledge if a person has it), the camp warden fills the generator, mends the camp and climbs the tower facing the danger. Both fight what comes close, revive the downed, fetch a thrown boathook, eat and warm up. Creatures scale with people, not keepers: groups x(1 + 0.5 per extra person), Crab and Eel hp +20% each. Local co-op is on one screen with keyboard and pads (the screen splits when apart); LAN is one person per machine, host-authoritative, up to three, no joining after the start (`autoload/net.gd`, lobby in `scenes/ui/lan_lobby.gd`). The first days' jobs (`scenes/systems/jobs.gd`): a list for the first three nights of eight things, ticked off only by people.

## Controls (`autoload/input_setup.gd`, `autoload/players.gd`, `scenes/ui/how_to_play.gd`)

| Action | Keeper one | Keeper two without a pad (arrow keys) | Pad |
|---|---|---|---|
| Move / aim | WASD / mouse | arrows / facing | left / right stick |
| Attack with what is in hand | left mouse | Ctrl | X or right trigger |
| Change weapon | Tab, wheel, 1 to 5 | [ and ] | d-pad left and right |
| Use (gather, mend, climb, row, revive: hold) | E | M | A |
| Lamp (at the door) | R | / | Y |
| Beam wide or focused | Q | . | B |
| Flare | right mouse | ; | left trigger |
| Dirty fuel | F | ' | left shoulder |
| Sprint / jump | Shift / Space | , / numpad Enter | right shoulder / A with nothing to use |
| Skip the day or dawn | Enter | | Back |
| Camera (alone only) | Z, C turn, X reset, wheel or - and = zoom, middle drag | | d-pad up and down zoom, a stick pressed in turns |
| Pause | Esc | | Start |

Keeper one's keys, except 1 to 5 and Esc, can be rebound in Settings (any key or mouse button; clashes swap). Code diverges from the docs here: `README.md` lists Sprint as Space, but `InputSetup` binds Sprint to Shift and Jump to Space; and `Settings.ARROW_NAMES` names the arrow-key player's Use key as Shift while `Players.bind_device` binds M, so in-game hints for that player name the wrong key.

## HUD (`scenes/ui/hud.gd`)

Top left: day or night number and the time left; weather (dusk and night), sea and boat countdown; the sea's mood line; lighthouse health; lamp fuel; lamp state and beam; one line for the camp (generator percent, lights, what is wrecked, or "THE CAMP HAS FALLEN"). Top right: the store, only kinds you have (driftwood, scrap, bio, kelp, food always). Down the right: the first days' jobs. Bottom left: a card per keeper (health, fed, warm, flares, weapon line). Bottom middle: the five-slot weapon bar, the use prompt, messages. Centre: warnings and the dawn log. Screen edge: red chevrons for creatures out of view (`ThreatMarkers`), a red pulse when the light is in danger, and the game-over card with a tally (`Try again`, `Back to the title`). F10 and the other F keys are debug builds only.

## Where Chapter Two is left

Nothing of Chapter Two is built. `scenes/ui/chapter_end.gd` shows "Chapter One / The Light Held": the nights held on that sea, "the internees' diary buttoned inside Callum's coat", creatures sent back, then "Next: Chapter Two, The Harbour" and a paragraph: halfway to Kirkhaven the skipper says the harbour lights went out three nights ago and nobody has answered the wireless from the town since Tuesday, and "the sea was angry there too". Two buttons: back to the title, or stay on the rock. `SaveSys.finish_chapter(1)` records the sea in `user://profile.json`, and the title then shows "Chapter One: the light held (sea). Chapter Two, The Harbour, is coming." There is no Chapter Two scene, map or rule set. Plan files `docs/prompts/02` to `04` are the only plans, and their Phase A is partly built (`Balance` exists; `Loot` does not: see `docs/ARCHITECTURE.md`).
