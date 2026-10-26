# Sea They Are Angry

A lighthouse keeper on a tiny North Sea rock, late 1980s. By day you gather driftwood, scrap, kelp and bioluminescent matter from the shoreline, mend the fences, plant the garden, set traps and refuel the lamp. At dusk the fog and the storm roll in. At night things walk up out of the water toward the light. The lamp's beam slows them; your boathook does the rest. If the lamp goes dark, the run is over. There is no winning, only how many nights you last.

Across a rope bridge from the lighthouse lies the holm, a low flat island with an old wartime camp on it: fenced with barbed wire, a guard tower and searchlight at each corner, Nissen huts, vegetable beds and a greenhouse. There are always three keepers: any that people don't play are helpers run by the computer, one keeping the light and one the camp. Losing the lighthouse ends the run. Losing the camp doesn't, but it makes everything harder: from night 2 some of each night's creatures land on the holm instead and tear through the wire at the generator, the huts and the greenhouse, and whatever's wrecked stops working until it's mended.

The island, buildings and effects are built in code. The characters are rigged models built by a Blender script. Sound is synthesised at start-up.

## How to run

1. Install [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) (standard build, not .NET).
2. Either open Godot, choose **Import**, pick `sea-they-are-angry/project.godot` and press **F5**,
3. or run the launcher: `./play.sh ~/Godot_v4.3-stable_linux.x86_64` on Linux, `play.bat C:\path\to\Godot_v4.3-stable_win64.exe` on Windows.

On a fresh clone, launching with `godot --path` alone fails with "Could not find type Lighthouse" and similar errors. Godot builds its list of script classes in the git-ignored `.godot/` folder the first time the editor opens the project. The same error appears after a `git pull` that adds new scripts, because the list is then out of date. The launchers re-import automatically whenever anything changed; by hand it is `godot --headless --editor --quit --path sea-they-are-angry`.

Balance playtest: a bot plays several nights and prints what happened, with `--` then the number of nights, `bot`, `eco` (the bot also plants, eats, buys upgrades and sets traps) or `idle`, and 1 to 3 keepers. Your own save and best night are backed up and put back.

```
godot --headless --path sea-they-are-angry --script res://tools/playtest.gd -- 6 bot 1
```

Gameplay reel: `tools/reel/make_reel.sh` records 16 captioned shots of the main gameplay with Godot's Movie Maker and joins them into one MP4 (needs ffmpeg, and `xvfb-run` with no display; set `GODOT=` to the binary). It takes about an hour, since every frame is fully rendered.

Headless load check (no window):

```
godot --headless --quit --path sea-they-are-angry
```

On Windows use the console binary, for example `Godot_v4.3-stable_win64_console.exe --headless --quit --path sea-they-are-angry`.

## Controls

Choose 1 to 3 keepers and how hard the sea is on the title screen, then New Run (or Continue). A calm sea is easy: fewer creatures, gentler blows, and ammunition never runs out. A raging sea is hard.

| Action | P1: keyboard + mouse | P2: arrow keys (if no free gamepad) | Gamepad (P2, P3) |
|---|---|---|---|
| Move | W A S D | Arrow keys | Left stick |
| Aim | Mouse | Facing direction | Right stick |
| Attack with what's in hand: swing, shoot, burn, throw (hold to draw the bow or keep the flamer going) | Left mouse | Ctrl | X or right trigger |
| Change what's in hand: boathook, longbow, shotgun, flamer, petrol bombs | Tab / mouse wheel, or 1 to 5 | [ ] | D-pad left / right |
| Use: gather, repair, refuel, climb a ladder, revive (hold) | E | Shift | A |
| Work the lamp (walk in at the door) / leave it | R (within 3.8 m of the lighthouse) | / | Y |
| Take a camp searchlight (up a tower) / let it go | E (R also lets go) | Shift | A |
| Switch beam: wide slows, focused burns | Q | . | B |
| Fire a flare (lobbed to the cursor) | Right mouse | ; | Left trigger |
| Pour dirty fuel (at the lighthouse) | F | ' | Left shoulder |
| Sprint | Space | , | Right shoulder |
| Skip the rest of the day or dawn | Enter | | |
| Pause | Esc | | Start |

The camera frames whichever island you're on and follows you across the bridge. When the people playing are on different islands, the screen splits (Baldur's Gate style) along a line square to the way between them, and joins up again when they come back together. Helper keepers get no view of their own.

Keepers face the way they walk and turn to their aim to swing. Each carries a paraffin lantern that lights at dusk. A keeper who falls goes down; a teammate holds Use beside them for 3 seconds to revive them, and everyone gets up at dawn. The run ends when the lamp goes dark or every keeper is down. Only one keeper can work the lamp at a time.

## What is in the slice

- The island, after Bad North: a meadow ringed by cliffs, three beaches where the sea comes ashore, and the lighthouse on a crag in the middle. The only way up is a ledge path that winds round the crag. Day/dusk/night/dawn lighting with fog.
- The holm to the east, over an 18 m rope bridge that sags, bounces under footsteps and swings in the wind (after Carrick-a-Rede): the old camp in grey box, its wire, towers, searchlights, huts, beds and greenhouse. A camera that follows the keepers between the islands, and a split screen when people are apart.
- Hunger and warmth: keepers get hungry, and cold outdoors at night (worse in rain and storms). Eat at the cottage or the camp's mess; warm up by the campfire, the cottage door or the quarters' stove (a driftwood lights it). The camp's three beds and greenhouse grow kale, cabbages, tomatoes and beans from seed; a storm can flatten the beds, never the greenhouse.
- The camp's power: a diesel generator runs the four searchlights and the huts' lights from dusk to dawn, burning faster the more it runs; jerrycans of diesel wash up on the holm's beaches. Climb a tower's ladder and take its searchlight (E): aim it, Q for a focused beam that burns. Left alone, the lights sweep the ground outside the wire.
- Research at the camp: tins of the internees' papers turn up about the camp, a page of their 1940s diary at a time. At the desk in front of the mess, a page and some of the store work out a project overnight: searchlights that track on their own, silvered reflectors, a governor for the generator, cold frames, tinning, and three new defences for the cairns (barbed wire that slows and cuts, tripwire flares, sandbag walls that creatures must batter down). The holm has four defence posts of its own.
- Raids on the camp: groups land on the holm's two beaches and tear through the wire (scrap mends it). They go for the generator, the quarters (their stove), the mess (meals and the research desk) and the greenhouse (its crop); wrecked, each stops working until mended with driftwood and scrap. With the generator and all three wrecked, the camp has fallen. The alarm bell (research) rings when they land and says where; without it, nobody on the main island hears them come.
- The shed's workbench (`scenes/structures/shed.gd`, `scenes/player/arsenal.gd`):
  - **Shotgun:** the old keeper's double-barrelled shotgun is on the wall, with only a box of 10 cartridges. A tin of 3 washes up every third dawn.
  - **Flamer:** rig the weed burner as one (2 scrap). It burns bio from its tank, and whatever's in the stream stops, writhes and burns on after.
  - **Longbow:** make one of driftwood and kelp cord, and whittle arrows (driftwood and scrap). Hold to draw, let go to loose.
  - **Petrol bombs:** fill them with bio and a kelp rag. They smash into a pool of fire.
  - **Rat poison:** bait from the shed's tins at a trap cairn sickens what eats it.

  Tab or the mouse wheel changes what's in hand (1 to 5 picks it; [ and ] or the d-pad for the other keepers).
- Helper keepers (`scenes/player/keeper_ai.gd`) fill the places people don't take, so there are always three. The lighthouse's helper gathers and mends by day and works the lamp at night (or holds the ledge if someone else has it); the camp's warden does its rounds by day and walks the wire at night. Both fight what comes close, revive downed keepers, and walk the keepers' map (`KeeperNav`: the ledge, the ladders, the bridge, the camp). The creatures still scale with the number of people playing.
- Characters modelled, rigged, textured and animated in Blender by scripts (`art/source/characters/build_characters.py`, `animate.py`): IK-solved walks, runs and sprints with planted feet, tool work, ladder climbs and creature gaits. Hard hits knock keepers and creatures down as ragdolls, and they get back up with real get-up animations from where they fall.
- Keeper movement, mouse aim, boathook attack. A blow aimed outward on the ledge knocks a creature over the edge. Keepers have their own ladders down the crag.
- The lamp: fuel, wide and focused beams (the focused one reaches the beaches), auto-sweep when nobody operates it, Burning to Guttering to Dark.
- Seven scavenge points on the beaches that refill at dawn (an eighth with three keepers), five fences at the chokepoints (beach heads and the ledge), repair, refuel.
- The keepers' economy:
  - **Garden:** dig kelp into the potato beds by day; they are ready at dawn.
  - **Cottage:** go in to eat (full heal and more max health), load flares, mix oil into dirty fuel, and buy upgrades for the lighthouse, the defences and the garden.
  - **Traps:** spike boards, kelp nets and chain plates on cairns up the beaches and the ledge.
  - **Oil:** a drum washes up every third night.
  - **Flare gun:** two shots that burn red where they land.
  - **Campfire:** warms a keeper back up by the cottage.
- Random weather each night: a clear moonlit night, rain squalls, or a storm that builds through dusk to a gale. The angrier the sea, the likelier a storm. In a storm: driving rain, thrashing grass, breakers crashing on the beaches, lightning and thunder, and pale shapes standing in the surf that only the flashes show. Every creature's eyes glow in the dark.
- Five creatures:
  - **The Bloated Dead** land on a beach and walk the long way up to the light, batter fences, swell and burst. Some groups raid the homestead instead.
  - **The Wall-Crawling Squid** climbs straight up cliffs and the crag at the keepers, lunges, and hides the others in ink.
  - **The Armoured Crab** comes to wreck the cottage, shed or garden; its shell turns blows from the front.
  - **The Giant Constrictor Eel** surges up and coils round the lighthouse until the focused beam burns its head.
  - **The Smotherer** climbs the lighthouse and wraps itself over the lantern, smothering the beam. The light can't burn it: throw your boathook up at it from the crag top to knock it off, then go and pick the hook up.
- Work the lamp from inside the lighthouse: the keeper walks in at the door and out again. Repairs are done with a hammer; refuelling with an oil can. The cottage, shed and garden take damage and need mending too.
- Foghorn warnings name where they land, the water churns before they surface, and a keeper's log at dawn sums up the night.
- A spawner driven by a per-night table and the hidden Sea Anger value.
- HUD, dawn autosave and resume, game-over screen with New Run.
- 3BL_Indie studio splash at launch and a Credits screen on the title menu (`studio/`, shared with the other 3BL_Indie games; see [CREDITS.md](CREDITS.md)).

Design choices the spec left open are recorded in [docs/DECISIONS.md](docs/DECISIONS.md).

## Next milestone

Plan 2 ([docs/prompts/02_first_release_phases_A-G.md](docs/prompts/02_first_release_phases_A-G.md)). Its Phase B creatures and Phase C economy are already in; Phase A (the `Balance` and `Loot` plumbing) is next, see [HANDOFF.md](HANDOFF.md).

## For the next session

Start with [HANDOFF.md](HANDOFF.md). The phase plans are in [docs/prompts/](docs/prompts/), the first real models are in [art/](art/README.md), and the chosen visual style is in [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md).
