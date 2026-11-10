# Chapter Two: The Harbour

Kirkhaven, the fishing town the relief boat was making for. Its lights went out on a
Tuesday; nobody has answered the wireless since. The *Mary Ann* puts the three keepers
on the pier at first light and stands off.

This is the second half of the game and the end of its story. It plays on the same
rules as the rock (day, dusk, night, dawn; the lamp burns what comes out of the sea)
in a different place with a different job: not one light to keep, but a town's worth
to put back.

## The idea

**The fog is where they are, and light is what holds the fog off.** A glowing bank lies
off the harbour mouth all night. Every street lamp that burns keeps a pool the fog
cannot lie in; a landing with a lamp at its head lets fewer creatures through, and they
would sooner come up a dark one. What stands in lamplight is slowed and scorched. So
they make for the lamps and break them, and the keepers' night is spent keeping lamps
burning under attack.

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

## The rules that are new

- **Street lamps** (`street_lamp.gd`). Switched in at the fuse box ([E]); they light at
  dusk while the generator runs. 60 health; one scrap mends a smashed one, and it relights
  by itself. A lit lamp: a fog hole 8.5 m across, and creatures within 6 m are in "wide
  beam" light (slowed, scorched).
- **The generator** is the camp's from Chapter One. It starts nearly dry. Each lit lamp
  draws diesel; a can a day is at the fuel berth by the pier.
- **Landings.** A group picks a dark landing three times as readily as a lit one, and a
  lit landing lets 70 % of a group through. Every group is a third bigger than the same
  row of the table brought to the rock.
- **Raiders.** Two of every three Bloated groups, and every Crab, go for the nearest
  burning lamp, the generator, or (when no lamp burns) the kirk; the third Bloated group
  goes for the harbour light. From the third night the first raiding group of the night
  is sent at the kirk doors; on the last night every other one is, and every other Crab.
- **The kirk bell.** Two scrap splice its rope ([F] at the kirk door). Rung in the dark,
  once a night, every burning lamp flares white for eight seconds and burns what stands
  in it like the focused beam.
- **The last night.** The fog comes over the quay and into the streets
  (`FogBank.flood`); only lamplight holds it off. At the dawn after, the fog goes out,
  the kirk doors open, the people come down to the quay, and the windows light one by
  one.
- **Nights:** 4 on a calm sea, 5 on an angry one, 6 raging. They start two rows further
  down the rock's table of landings (Crabs and Squid from the first night). The Eel does
  not come into the harbour. Smotherers climb the harbour light as they did the rock's.
- **Not here:** hunger and warmth (the town feeds its keepers through the kirk door),
  the shed, the garden, research, upgrades, the camp. The keepers arrive with a longbow
  each, the shotgun, petrol bombs, and a little of everything else.
- **Helpers.** One works the harbour light from dusk; the other walks the lamps
  (switches them in, mends them, feeds the generator, keeps the harbour light mended and
  fuelled, fetches the day's stores, splices the bell rope when there is scrap to spare).
  On the last night that one keeps the kirk doors instead, and rings the bell once four
  or more are ashore.
- **Local play only.** LAN games are Chapter One's.

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

Getting there: the title has "Chapter Two: The Harbour"; Chapter One's end card has "On
to Kirkhaven"; a saved Kirkhaven run continues from the title. Leaving (pause → quit,
game over → title, the ending) goes back to `main.tscn`, where the title lives.

## The ending

"The Lights of Kirkhaven": three short pages over the lit town, then the line the story
has been heading for, *A light kept is a promise*, the tallies, credits, and the way
back to the title. `SaveSys.finish_chapter(2)` records it.

## Runs played by the computer's keepers (2026-11-10)

`tools/playtest_harbour.gd`: three computer keepers, nobody playing. One on the harbour
light, two walking the lamps (the real game has one, and you).

| Sea | Nights | Came ashore each night | Lamps smashed | End |
|---|---|---|---|---|
| Calm | 4 | 7, 11, 9, 20 | 1, 2, 0, 3 | Held: 8 of 11 lamps in, kirk untouched, bell rung |
| Angry | 5 | 11, 15, 12, 18, 36 | 1, 1, 1, 3, 6 | Held: 5 of 11 lamps in, kirk untouched, bell rung |

Earlier settings they lost to, and what was changed: groups half as big again with
nothing to refill arrows or cartridges (every keeper down on the last night); the
harbour light left damaged, which stops it being refuelled (it went dark); every Crab
of the last night sent at 300-point kirk doors (the doors went). The first settings of
all were the other way: the town was held without a lamp or the kirk coming under real
threat. A raging sea has not been run.

## Not done

- Nobody has played it. The numbers (lamp health, draw, landing weights, how many go
  for the kirk) were set against scripted tests and runs played by the computer's keepers
  alone (`tools/playtest_harbour.gd`), which is not the same as a person playing.
- LAN play in Kirkhaven.
- The townsfolk at the end are the keepers' models, walking.
- The Eel has no part in it; a harbour-mouth version would suit the last night.
