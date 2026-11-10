# Act One: Kirkhaven

The story's first act (see [STORY.md](STORY.md)). The harbour light was put on a clock,
the clock stuck, and the fog came in with something in it. Three keepers paid off that
week try to put the town's lights back and keep its seven people alive. They cannot hold
it: on the third night they bring whoever is left down to the *Mary Ann* and sail for
the rock.

Until v1.0.0 this was "Chapter Two", played after the rock, with an ending in which the
town was relit. The owner turned the story round on 2026-11-10: the town falls first.
The map, the lamps, the generator, the kirk and the fog are as they were; what changed
is who is in it and how it ends.

## The idea

**The fog is where they are, and light is what holds the fog off.** A glowing bank lies
off the harbour mouth all night. Every street lamp that burns keeps a pool the fog
cannot lie in; a landing with a lamp at its head lets fewer creatures through, and they
would sooner come up a dark one. What stands in lamplight is slowed and scorched. So
they make for the lamps and break them.

And now there is somebody to keep alive. **The seven** (the minister, the chandler, the
engineer, the publican, the nurse, the harbour master, the net-mender) are about their
doors by day and shut in the kirk at night. Each brings something every dawn while they
live, here and later on the rock. The lamps you keep burning on the third night are the
lit road they run down to the boat.

The mood is John Carpenter's *The Fog* (1980): a small harbour, a glowing bank coming in
against the wind, shapes in it, a voice on the wireless, a bell. Nothing of that film's
story, names, lines or music is used.

## The town

`scenes/harbour/harbour_map.gd` (HarbourMap) holds the plan. The sea is to the south,
toward the camera.

| Place | What it is for |
|---|---|
| The pier, and the harbour light at its head | The lamp with a beam, worked like the rock's ([R] at its door). It reaches both slips but not the strand. If it goes dark, the run ends. |
| The west and east slips | Two of the three landings, either side of the pier. |
| The strand | The third landing, a shingle beach past the quay's east end, out of the harbour light's reach. |
| The quay and its seven lamps | The front line. Lamps flank each slip and the pier. |
| The generator (west end of the quay) | Feeds every street lamp from dusk. Wants diesel; can be wrecked and mended. |
| The front row | Harbour office, the ice and fish shed, the chandler's, The Creel, houses, a net loft. Stores are fetched at their doors each day. |
| The wynds and the back street | Two lanes up from the quay, a lamp at the head of each. |
| The kirk, on its green | The townsfolk are shut inside. Knock, and someone answers. If the doors go, the run ends. Its bell is the keepers' one big help. |

## The rules that are particular to it

- **Street lamps** (`street_lamp.gd`). Switched in at the fuse box ([E]); they light at
  dusk while the generator runs. 60 health; one scrap mends a smashed one, and it relights
  by itself. A lit lamp: a fog hole 8.5 m across, and creatures within 6 m are in "wide
  beam" light (slowed, scorched).
- **The generator** is the camp's from the rock. It starts nearly dry. Each lit lamp
  draws diesel; a can a day is at the fuel berth by the pier, and Sandy Coull tops it up
  each dusk while he lives.
- **Landings.** A group picks a dark landing three times as readily as a lit one, and a
  lit landing lets 70 % of a group through. Every group is a third bigger than the same
  row of the table brings to the rock.
- **Raiders.** Two of every three Bloated groups, and every Crab, go for the nearest
  burning lamp, the generator, or (when no lamp burns) the kirk; the third Bloated group
  goes for the harbour light. On the last night every other raiding group and every
  other Crab is sent at the kirk doors.
- **The seven** (`scenes/people/`). By day about their doors; with 22 seconds of the day
  left they make for the kirk and shut themselves in. Out of doors in the dark they are
  **prey**: a creature within 16 m turns aside for them, and anything that gets within
  reach of one for half a second takes them. `Run.villagers` holds the living.
- **The kirk doors.** If they are broken down in the night, one of those inside is taken
  every seven seconds until the doors are mended (driftwood). It does not end the run.
- **The kirk bell.** Two scrap splice its rope ([F] at the kirk door). Rung in the dark,
  once a night, every burning lamp flares white for eight seconds and burns what stands
  in it like the focused beam.
- **The last night (the third).** The fog comes over the quay and into the streets
  (`FogBank.flood`). A third of the way through, the skipper sounds his horn: the night
  holds, the kirk doors open, and the seven come out one after another and run down
  through the streets to the boat at the pier head. Three Bloated come up each slip as
  the horn sounds (the way to the pier runs between the slips), and more every nine
  seconds while anyone is still ashore. When each is aboard or lost, her plank goes out and the keepers board ([E]); then
  she sails, and Act Two begins on the rock with whoever was saved and whatever the
  keepers were carrying.
- **What ends the run here:** the harbour light going dark, or every keeper down. Losing
  all seven does not: the keepers still sail, alone.
- **Nights:** three, whatever the sea's mood (the mood sets how many come). They start
  two rows down the rock's table of landings. The Eel does not come into the harbour.
- **Not here:** hunger and warmth, the shed, the garden, research, upgrades. The keepers
  begin with a longbow each, the shotgun, petrol bombs, and a little of everything else.
- **Helpers.** One works the harbour light from dusk; the other walks the lamps (switches
  them in, mends them, feeds the generator, keeps the harbour light mended and fuelled,
  fetches the day's stores, splices the bell rope). On the last night that one keeps the
  kirk doors, rings the bell, and when the horn sounds stays by whoever is last down the
  street.
- **Local play only.** LAN games are the rock alone.

## How it is built

The harbour scene's script (`scenes/harbour/harbour.gd`) **extends `scenes/main.gd`** and
builds a different world in `_ready`. Everything else is the rock's: `Player`, `Enemy`
and the four creatures, `Lamp`/`Lighthouse`, `Generator`, `Spawner`, the HUD, `Atmosphere`,
`Weather`, `FogBank`.

That works because `Terrain` (the static class nearly everything asks about the ground)
hands over to `HarbourMap` while `Terrain.chapter == 2`: `height_at`, `walkable`,
`color_at`, `layers_at`, `is_grassy`, `beach_point`, `beach_weight`, and the "which
island" questions. `Nav` and `KeeperNav` hand over too: creatures and helper keepers
find their way on an `AStarGrid2D` laid over the town (one grid for keepers; one for
creatures, which can also wade the landings).

Small hooks added to shared systems for this chapter:

| Where | What |
|---|---|
| `Run` | `chapter`, `enter_harbour`, `harbour_continue`, `lamps_on`, `bell_mended` (saved) |
| `Rescue` | `HARBOUR_NIGHTS`; `countdown()` words |
| `Spawner` | `table_shift`, `pick_point`, `count_scale`, `on_spawn`, `raid_from` |
| `Enemy` | `raid_goal`; `nearest_home` also takes the group "homes" and asks `draws_raiders()` |
| `Lamp` | `tilt_deg` / `set_tilt` (the harbour light stands lower and points flatter) |
| `Generator` | `owner_name`, for its messages |
| `Jobs`, HUD | `Jobs.list()` by chapter; `hud.status_line` |
| `Player` | [F] calls `alt_use()` on whatever is to hand that has it (the bell) |
| `KeeperAI` | `_harbour()`: the two helper roles above |

Getting there: the title's New Run shows the keeper's log and then starts here; a saved
Kirkhaven run continues from the title. Leaving (pause → quit, game over → title) goes
back to `main.tscn`, where the title lives; the Mary Ann sailing goes there too, with
`Run.carry` holding what came across.

## Runs played by the computer's keepers (2026-11-10)

`tools/playtest_harbour.gd` (three computer keepers, nobody playing) on an angry sea:
nights of 11 and 16 ashore with one to three lamps smashed each, all eleven lamps
burning at the horn, and all seven brought to the boat.

The last night alone, set up two ways, shows what the lamps are worth:

| The town at the horn | Brought to the boat |
|---|---|
| Every lamp burning | 7 of 7 |
| Every lamp dark, the generator dry | 3 of 7 |

So the evacuation is as dangerous as the town is dark. The computer's keepers are better
at keeping every lamp lit than a person is likely to be on a first play.

## Not done

- Nobody has played it. The numbers were set against scripted tests and runs played by
  the computer's keepers alone (`tools/playtest_harbour.gd`).
- LAN play in Kirkhaven.
- The seven borrow the keepers' models.
