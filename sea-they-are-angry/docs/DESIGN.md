# Design

The game as the code has it at v0.1.4 (Chapter One). Where `README.md`, `docs/DECISIONS.md` or the plans in `docs/prompts/` disagree with the code, this file follows the code and says so. File paths are given so any number can be checked. `docs/ENEMIES.md` covers the creatures; `docs/ARCHITECTURE.md` covers how it is built.

## Premise

Sea They Are Angry is a top-down 3D survival game (Godot 4.3, GDScript; version 1.1.1; this file describes the rock, the story's second act; `docs/STORY.md` is the story and `docs/KIRKHAVEN.md` the town). You are a lighthouse keeper on a small North Sea rock in the late 1980s (`README.md`). By day you gather, mend, plant and prepare; at dusk the fog comes in and drowned things walk up out of the sea toward the light. If the lamp goes dark, or every keeper is down, the run is over. Hold out until the relief boat comes and the chapter ends. The three keepers are Callum MacLeod (principal keeper), Hamish Fraser (engineer) and Mairi Campbell (gardener and runner); `Players.NAMES` also lists Ewan Reid, who has a model but cannot be in a run (`Players.MAX` is 3).

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

Working the lamp: walk to the lighthouse door (within 3.8 m) and press R; the keeper goes in and aims with the mouse or stick; B switches wide (35 degree half-angle, 26 m) and focused (10 degrees, 29 m). Range grows by 3 and 6 m at upgrade levels 2 and 3. Only one keeper can work it. Dirty fuel: +30 fuel, the beam burns 1.5 times harder and the light is 1.3 times brighter for 30 s, and Anger +1. A Smotherer on the lantern cuts the beam's range to 30% and brightness to 12%. A badly damaged lighthouse (under 30%) makes the light flicker and the screen pulse red.

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

Everyone has the **boathook** (20 damage, Callum's 27; 2.5 m, 60 degree arc, 0.6 s). The shed's bench adds four more, picked with Tab, the wheel, or keys 1 to 5 (`Arsenal.ORDER`: hook, bow, shotgun, flamer, bombs):

- **Longbow:** made for 3 driftwood and 1 kelp, one per keeper (a helper can have one too). Hold to draw (0.8 s, movement at half speed), release to loose: 12 to 40 damage, range 26 m. Arrows cost 1 each.
- **Double-barrelled shotgun:** one gun on the wall, taken and left at the bench. Two barrels, then a 1.6 s reload; 9 pellets of 7 (11 within 3.5 m) in a 24 degree cone out to 11 m; knocks the keeper back. Cartridges are shared.
- **Flamer:** the weed burner rigged for 2 scrap, one only. Hold to burn: 34 a second to 5.5 m, whatever is in the stream stops and burns on for 2.5 s. The tank holds 100 and empties in about six seconds; it refills from the store's bio (1.5 s). Movement x0.6 while burning.
- **Petrol bombs:** 20 damage, set alight, and a pool of fire (2.3 m, 7 s, 16 a second). Range 12 m, 0.8 s between throws.

On a calm sea ammunition, arrows, bombs, the flamer's tank and flares are free. A keeper also has a **flare gun** (right mouse; 2 flares, 40 damage on a hit, burns 8 s and lights like the wide beam) and the **harpoon** (the boathook thrown at a Smotherer on the tower). The lighthouse helper takes the shotgun off the wall if nobody has it and uses a bow if one was made for it; helpers leave the flamer and bombs to people.

## Survival needs (`scenes/player/player.gd`)

Hunger falls 0.18 a second (x1.5 sprinting) and warmth falls outdoors at dusk and night, 0.12 a second times 1.0, 1.6 or 2.2 for a clear, squally or stormy night; by day outdoors it rises 0.25 a second, indoors 0.6, and beside a fire more (cottage door 2, campfire 3 lit, camp stove 3). Both are scaled by the sea (0.6, 1.0, 1.25). Below 25 a keeper is slower (hungry x0.85, cold x0.9, and cold swings 25% slower); at zero they lose 1 health every 2.5 s. Meals: the cottage (above), the mess table (1 food: fed and +30 health, no max health), the campfire (1 driftwood: +30 health), the camp stove (1 driftwood burns 260 s). Keepers start with 100 health. A keeper at zero is downed (everyone gets up at dawn at half health); a teammate holds E within 1.5 m for 3, 2.5 or 2 s to revive them at 40%.

Food: five garden beds in the cottage garden (3/4/5 open; 1 kelp plants one, ripe by dawn, 1 food; a hit on the garden ruins a bed), three camp beds (1 seed, 2 food, half the time a storm night flattens them) and the greenhouse (1 seed, 3 food, safe from weather), gull eggs and kelp broth. Research adds a food per harvest (tinning) and two more from the greenhouse (cold frames, which also stop storm damage to the beds).

## The camp and the holm

The generator (`scenes/structures/generator.gd`) runs from dusk to dawn: fuel 100, 35 per jerrycan, 0.03 a second idle plus each searchlight 0.1 wide or 0.2 focused and each lit hut 0.015 (about 0.45 a second with four wide lights, computed, not measured); the governor research cuts it by a third. It powers four searchlights and the huts' lights; dry or wrecked, the camp is dark. Searchlights (`scenes/systems/searchlight.gd`) sweep by themselves, or a keeper climbs a tower's ladder and presses F to aim one (16 degree half-angle wide beam, 6 degree focused, 34 m); tracking and reflectors are research. The turbine lights the strings round the wire from dusk to dawn while it stands (creatures inside the lit wire go 15% slower); wrecked, the compound goes dark.

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
| The story's rock: the kraken on night | 6 | 7 | 8 |

## Gull Rock and the rowing boat

`scenes/world/rowing_boat.gd`: E at the jetty's foot pushes off with that keeper at the oars; anyone who presses E in the next 1.4 s climbs in (up to three). It rows at 2.6 m/s along a channel and lands them at the rock's slip. Rowing out is allowed in DAY or DAWN and only while `Weather.storm_now` is 0.32 or less (the day's level is 0.12 whatever the night was; dawn after a storm night is 0.35, so it is refused then); rowing back is always allowed. The boat hangs on a haul line, so E at either end brings the empty boat across. On the rock: six nests (`scenes/world/gull_nest.gd`), each with 0, 1, 2 or 3 eggs at dawn (25%, 30%, 30%, 15%); E takes them; the colony mobs the taker (harmless). If a person is still out there at dusk the HUD warns. Gulls (`gull_flocks.gd`) fly everywhere by day, fly out to sea at dusk and stay away at night and in a storm. The README says the crossing takes about 12 seconds; the code only gives the speed.

## Keepers, helpers, co-op and LAN

There are always three keepers. Pick 1 to 3 people on the title; the rest are helpers (`scenes/player/keeper_ai.gd`): the light helper gathers and mends by day, works the lamp at night (or holds the ledge if a person has it), the camp warden fills the generator, mends the camp and climbs the tower facing the danger. Both fight what comes close, revive the downed, fetch a thrown boathook, eat and warm up. Creatures scale with people, not keepers: groups x(1 + 0.5 per extra person), Crab and Eel hp +20% each. Local co-op is on one screen with keyboard and pads (the screen splits when apart); LAN is one person per machine, host-authoritative, up to three, no joining after the start (`autoload/net.gd`, lobby in `scenes/ui/lan_lobby.gd`). The first days' jobs (`scenes/systems/jobs.gd`): a list for the first three nights of eight things, ticked off only by people.

**Each keeper's knack** (`Players.PERKS`, by slot, whoever plays them, a person or a helper; computed on the host, so on a LAN it follows the slot; shown on the title's keeper lines and in How to Play's Together page):

| Keeper (slot) | Knack | Numbers |
|---|---|---|
| Callum (0), the old hand | the hook | boathook damage x1.35 (27), shove x1.6, an outward blow on the ledge puts a creature over with an aim 2.5 times looser (dot 0.14 against 0.35) |
| Hamish (1), the shot | the guns | shotgun 10 pellets in an 18 degree cone (against 9 in 24), bow draws x1.25 (0.64 s) |
| Mairi (2), the mechanic | mending and fuel | hammer jobs and pours (lamp bio, generator diesel, dirty fuel) x1.4 quicker; a mend that costs more than one thing costs a driftwood less (the lighthouse takes only the scrap, the garden only the kelp) |
| Ewan (3), the young one | his legs | x1.15 on foot (walking and sprinting), sprint lasts x1.4 (4.2 s) and rests x0.6 (1.2 s), lies x0.65 as long after a knock-down. `Players.MAX` is 3, so he is not in a run yet |

## Controls (`autoload/input_setup.gd`, `autoload/players.gd`, `scenes/ui/how_to_play.gd`)

| Action | Keeper one | Keeper two without a pad (arrow keys) | Pad |
|---|---|---|---|
| Move / aim | WASD / mouse | arrows / facing | left / right stick |
| Attack with what is in hand | left mouse | Ctrl | X or right trigger |
| Change weapon | Tab, wheel, 1 to 5 | [ and ] | d-pad left and right |
| Use (gather, mend, climb, row, revive: hold) | F | M | A |
| Lamp (at the door) | R | / | Y |
| Beam wide or focused | B | . | B |
| Flare | right mouse | ; | left trigger |
| Dirty fuel | G | ' | left shoulder |
| Sprint / jump | Shift / Space | , / numpad Enter | right shoulder / A with nothing to use |
| Skip the day or dawn | Enter | | Back |
| Camera (alone only) | Q, E turn (all the way round), X reset, wheel or - and = zoom, middle drag | | d-pad up and down zoom, a stick pressed in turns |
| Pause | Esc | | Start |

A person's boathook swings the way the keeper faces, with a short step into the blow (`Player.LUNGE`). How blows land (hit-stop, the camera's kick, the flash, the thump, the shove) is in `docs/DECISIONS.md`, 2026-11-11.

Keeper one's keys, except 1 to 5 and Esc, can be rebound in Settings (any key or mouse button; clashes swap). Code diverges from the docs here: `README.md` lists Sprint as Space, but `InputSetup` binds Sprint to Shift and Jump to Space; and `Settings.ARROW_NAMES` names the arrow-key player's Use key as Shift while `Players.bind_device` binds M, so in-game hints for that player name the wrong key.

## HUD (`scenes/ui/hud.gd`)

Top left: day or night number and the time left; weather (dusk and night), sea and boat countdown; the sea's mood line; lighthouse health; lamp fuel; lamp state and beam; one line for the camp (generator percent, lights, what is wrecked, or "THE CAMP HAS FALLEN"). Top right: the store, only kinds you have (driftwood, scrap, bio, kelp, food always). Down the right: the first days' jobs. Bottom left: a card per keeper (health, fed, warm, flares, weapon line). Bottom middle: the five-slot weapon bar, the use prompt, messages. Centre: warnings and the dawn log. Screen edge: red chevrons for creatures out of view (`ThreatMarkers`), a red pulse when the light is in danger, and the game-over card with a tally (`Try again`, `Back to the title`). F10 and the other F keys are debug builds only.

## The story round it

Since v1.1.0 the rock is the story's second act (`docs/STORY.md`): Kirkhaven comes first (`docs/KIRKHAVEN.md`), its survivors live in the camp here, no relief boat comes, and the last night is the kraken's (`scenes/systems/story_rock.gd`, `scenes/enemies/kraken.gd`). Everything above still describes how the rock plays. The relief boat's ending (`scenes/ui/chapter_end.gd`) remains for the rock played alone, which is what LAN games are.

## The kraken: three stages (2026-11-11)

The last night's fight (`scenes/enemies/kraken.gd`, rules; `kraken_body.gd`, the octopus; `kraken_part.gd`, what weapons hit; `kraken_bar.gd`, its bar) comes in three stages, each with its own answer, instead of one long fight at the lighthouse. Across the top of the screen a bar shows its strength under the three stage names, the one it is in lit, with a line under it while it is blind, has an arm up the tower, or rears. Each stage opens with a roar and one line (`StoryRock._on_kraken_phase`).

1. **It takes the camp** (`camp_east` for up to `CAMP_TIME` 24 s, then round to the north side for 24 s more): "It is through the wire." Its arms come over one at a time (`CAMP_WINDUP` 1.6 s reared, a gap after); two slams bring a hut down (`SLAM_CAMP` 110). Fire is the answer: the flamer or a petrol bomb's blast or pool on an arm makes it recoil (`KrakenBody.recoil`: it whips about and pulls back under for `RECOIL_TIME`), calls off the slam it was winding up, sets it burning (its fire hurts the kraken) and keeps that arm away for `SHY_TIME` 6 s. A searchlight held on an arm for `ARM_LIGHT_TIME` 0.8 s (half that focused) does the same, without the burn: a helper up a tower holds its light on the nearest arm, and the towers sweep on their own while the generator runs. Arrows and shot sting: `STING` 40 on one arm sends it back. An arm reared over the wire can be got at where it comes over (its middle), not under the blow. The camp falls in the end whatever is done; what still stands when it moves on (`camp_left` of `camp_had`: the generator, the huts, the greenhouse) is in the stage line and on the "It is over" card. The survivors are already on the crag with the keepers (they went at the last dusk), so nobody has to run.
2. **The crossing** (`cross`): "It's coming round for the light!" It works through the shallows round the north of the holm, slowly (`CROSS_SPEED` 1.35 m/s, about 27 s if nothing is cut), reaching for keepers on the path and the bridge (`SLAM_EVERY_CROSS`). An arm that comes down on land lies there `LIE_CROSS` 4.5 s with a pale glowing weal on it (`KrakenBody.set_wound`), the place to cut; the first time, one line says so. Cut there (`ARM_HP` 110: a shotgun at close range, or a few boathook blows) it costs it `SEVER_DAMAGE_CROSS` 300 (110 elsewhere), it stops thrashing for `SEVER_STALL` 3 s, it is a fifth slower for the rest of the way (never under 40%), and the arm does not grow again until it reaches the light.
3. **The light** (`light`): "It can't abide the light!" Hauled up the east beach under the tower. The focused beam held on its eyes for `DAZZLE_TIME` blinds it and holds it: its arms go slack, hits on its head count `BLIND_MULT` 3x, and the beam itself burns it (`BEAM_DPS` 34). It learns: the first blinding lasts `BLIND_TIME` 8 s, each after x`BLIND_LEARN` 0.88, never under `BLIND_MIN` 4 s; after each it keeps its head turned for `BLIND_REST` 5 s (its eyes can't be found then, so a helper on the lamp drops to the wide beam and saves oil). Between blindings it slams keepers and, one blow in three, the tower; and after `GRIP_EVERY` 13 s sighted it gets an arm up the tower: unless it is blinded within `GRIP_TIME` 4 s of looking back, it shakes the tower (`GRIP_DAMAGE` 14) and throws whoever is on the lamp out of the lamp room. At `REAR_AT` 30% of its strength it rears its whole body up out of the sea on its arms for `REAR_TIME` 10 s (`KrakenBody.rear`): it does not strike and cannot be blinded, and everything that hits it counts `REAR_MULT` 2.5x: the last window for every weapon. Then it drops back and the fight goes on until it dies; the fog goes out and the sky clears as before.

Its strength is `BASE_HP` 4800 (was 5600), x1.35 per extra person, and the sea counts for a third of what it does on the nights' landings (calm 0.9, angry 1.0, raging 1.12; it was the full 0.7, 1.0, 1.35), since a raging sea's blows already land harder and the lamp's oil is the limit. Once it leaves the camp, the camp's helper comes back to the light too (`KeeperAI._kraken_at_light`). Once it is dying the night is won (`Run.active` off), even if the lamp gutters out while it goes down. Tuned with `tools/playtest_kraken.gd`, which prints when each stage began and how it went (see `docs/DECISIONS.md`, 2026-11-11, for the numbers).

## The story's rock: days and nights that differ (2026-11-11)

In the story (`Run.story`, local play only; never on a LAN, where the rock is played alone) the rock is `Rescue.STORY_NIGHTS` long: 6, 7 or 8 nights on a calm, angry or raging sea, the kraken on the last (`StoryRock`, rising at `KRAKEN_AT` of that night). The diary's last pages are read at the dawn with `DIARY_NIGHTS_LEFT` (3) nights to come: after night 3, 4 or 5. The rock alone keeps the boat's 8, 10 and 12. `scenes/systems/rock_days.gd` (`RockDays`, made beside `StoryRock`) does the rest; everything it puts out is host-side by construction (the story is offline).

**Each day's event** (`RockDays.EVENTS`, drawn from the run's weather seed, never the same two days running; day 1 from `FIRST_DAY`): one line as the day starts (`Events.message`), kept short at the top of the screen (`scenes/ui/day_note.gd`) until done, with a gold marker (a bobbing cone and its name, built in code) over its place. What the sea doesn't give up by dusk it takes back.

| Event | What | Where |
|---|---|---|
| wreck | 2 scrap, 1 diesel, 3 cartridges, beside a wreck's keel and ribs | a main-island beach |
| camp_kit | 2 rat poison, 1 oil drum, 2 cartridges | the long grass by the camp's wire |
| fish | 3 food (seals working off the beach) | a beach's tideline |
| long_day | the day is 30 s longer (`LONG_DAY`); never before a fog night | none |
| gulls | every nest on Gull Rock full (3 eggs) | Gull Rock's slip |
| lifejacket | a page of the internees' notes (counts as notes) | a beach |
| wireless | the set by day: a hint of the night to come (`WIRELESS_DAY`) | none |
| low_tide | 2 scrap, 2 bio, 2 driftwood in a cave's mouth | one of the holm's beaches |

**Special nights** (`RockDays.night_kind(n)`, from the seed and the sea): night 1 and the last are plain; every third night (`BIG_EVERY`) is a big night; others are plain with chance 0.4, 0.25 or 0 by sea, or one of storm, squid, fog (from night 2), smotherer, eel (from night 3; calm 4), never the same two nights running, and never the eel on its own night. The morning gives a sign of it (`SIGNS`, "The glass is falling: a storm tonight."), dusk one line (`DUSK`), and `Spawner.special_rows` shapes the table: squid, every Bloated group comes as Squid (one fewer, at least two); smotherer, three more Smotherers at 0.18, 0.38, 0.56 on their own beaches; fog, groups x0.75 but each lands on every beach (the weather forced clear); big, groups x1.3 (+1 at least) and another Crab and Smotherer; storm, the weather forced to a storm; eel, the Eel comes.

**The seven's requests** (`Villagers.REQUESTS`): from day 2 one of the living asks one thing, for that day only (the order is shuffled by the seed; those never asked first). Done, another asks 15 s later if 30 s of day are left; not done, it lapses at dusk and they may ask again another day. It shows in the top note ("Asked: ..."), and [E] beside them hands it over:

| Who | Asks | Reward (for the rest of the run) |
|---|---|---|
| Mr Baird | his bible, washed up on a beach (marker), brought to him | the sea's anger -2 |
| Isla Rennie | 3 driftwood | two scrap a dawn, not one |
| Sandy Coull | 2 scrap, 1 diesel | the generator governor (or, already researched, the generator filled) |
| Morag Duthie | 3 gull eggs | two meals a dawn |
| Nurse Buchan | 2 bio | she sees to the keepers at dusk too (+30 each) |
| Tam Geddes | the quarters' stove lit | a box of 10 cartridges |
| Peter Main | 3 kelp | six arrows a dawn, not four |

When one of the seven is lost, the dawn's log has a line from one of the living (`Villagers.GRIEF`).

**The dawn rating** (`scenes/systems/night_rating.gd`, every rock run, LAN included): the last line of each dawn's log, up to three stars, one each for the light (lit for 99% of the night), the souls (none of the seven lost, no keeper downed) and the holding (nothing reached the light, nothing wrecked, the tower lost under 20% of its strength); "The light never went out. Not a soul lost. Nothing got through.  ★★★". The run's total (`Run.stars` of `Run.star_nights` x 3) is on the end cards and the game-over card. (The fonts have no star; the stars come from the system's fallback font, as the HUD's fold arrows do.)

**Unlocks** (`SaveSys.UNLOCKS`, kept in `user://profile.json` with the choices): the story finished on an angry sea unlocks the keeper's oilskin (a yellow tint over the keepers people play, chosen in Settings, on the rock); on a raging sea, Hard Light too (Settings: the rock's lamp burns oil x1.25, `Lamp.HARD_LIGHT`, and a night the light never goes out earns a fourth star). The title shows what is unlocked in one small line; the end card says what the finish unlocked. The best total is kept (`best_stars`).

Since v1.0.0 the nights have the glowing fog bank (`FogBank`), the wireless at dusk, the knock at the cottage door, lights dipping as the fog comes ashore and a far foghorn (`NightEvents`), and a synthesiser score at night.
