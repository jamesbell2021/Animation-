# The Escape

The crossing between the acts (see [STORY.md](STORY.md)), asked for by the owner on
2026-11-11: "a short level where you have to sail to the lighthouse island and creatures
attack your boat so you or the AI either control the boat avoiding sea creatures or hit
things off the boat as they climb up. Or shoot them off with a shotgun."

The *Mary Ann* has left Kirkhaven's pier on the third night with whoever reached her.
She runs up the coast in the fog for the rock, whose light sweeps ahead and comes
nearer. About three and a half minutes on an angry sea.

## How it plays

- **The wheel.** On the after face of the wheelhouse. A person walks up and presses Use,
  steers with their own move keys (up and down the screen, or left and right: both do the
  same) and presses Use (or the lamp key) to let go. Nobody playing at it, the first
  helper takes it from Dod; with the helpers off, or while one walks to it, **Dod
  Wiseman** steers (he stays with his boat, and is never at risk). A person can take it
  from either. Dod looks less far ahead, reacts slower and steers less truly than a
  helper.
- **In her way.** Rocks breaking white (there is always a way through), and **great
  arms**: a swirl on the water ahead keeps across from her, then an arm rears up out of
  the sea beside her course, its end hooked over a red ring of foam on the water, and
  comes down on the ring as she reaches it. Steer out from under. Arrows, the shotgun or a
  petrol bomb into it while it's up (55 on an angry sea) drives it back under. On the
  angrier seas an arm sometimes comes with rocks just past it, so there is only so much
  room.
- **A blow to her hull** (a rock 13, an arm 22 on an angry sea): a lurch, the camera
  shakes, those standing reel, and the arm's blow knocks down anyone near where it lands.
  She can't be hurt again for 1.4 s.
- **Over the side.** The drowned (the Smotherer's model, quick) and the bloated (slow,
  heavy) swim up alongside and climb her sides at seven places a side; a **!** over the
  gunwale marks each one, white in the water, reddening as it climbs (half of them are on
  her far side, behind her hull from the camera). While one swims or clings, **any hit
  knocks it back into the sea**: the boathook from the rail, an arrow, the shotgun, the
  flamer, a bomb. Once over the gunwale, the drowned make for the seven and take one over
  the side with them (1.3 s at their side: kill it or knock it down first); with none
  left they go for a keeper. A bloated one walks to whoever is nearest and bursts: it
  hurts keepers within 3 m, takes one of the seven within 2.2 m, and splits her planking
  (5 off the hull). A boathook blow aimed outward at one by the rail puts it over the
  side.
- **Surges.** Besides the steady trickle, three times on the crossing (30 %, 55 %, 78 %)
  they come up all round her at once (3, 5, 6 by the sea's mood, one more for each
  extra person playing).
- **The light.** At 90 % the rock's light reaches her: what is in the water and on her
  sides lets go, what is aboard goes over the side, arms sink, and nothing more comes.
  She slows in under the light; then the last two crossing pages, and the rock.
- **Losing.** Her hull at nothing: she founders, and the run is lost (the usual game-over
  card, reworded for the crossing). Every keeper down ends it too, as elsewhere. Continue
  on the title (or Try again) begins the crossing again with what came off the pier.
- **The seven** sit huddled in the well of the fore deck. Whoever is taken on the crossing
  is lost (`Villagers.lose`, `Run.lost`): the rock, its dawn gifts, the end card and the
  log's next page all know.

| | Calm | Angry | Raging |
|---|---|---|---|
| Crossing | 860 m | 950 m | 1020 m |
| Hull | 130 | 100 | 90 |
| Rock / arm blow | 9 / 16 | 13 / 22 | 15 / 28 |
| Arm's ring, its health | 2.0 m, 40 | 2.25 m, 55 | 2.5 m, 70 |
| Something in her way every | ~64 m | ~46 m | ~34 m |
| Of those, arms | 35 % | 45 % | 55 % |
| A wave over the side every | ~8 s | ~4.6 s | ~3.4 s |
| At most at once (one person) | 3 | 6 | 8 |
| A climb takes | 5.5 s (the bloated 1.35 times) | 4.0 s | 3.4 s |
| Bloated | 20 % | 30 % | 32 % |

Waves come quicker for more people playing (and later in the crossing). On a calm sea
ammunition is free, as everywhere.

## How it is built

`scenes/escape.tscn` runs `scenes/escape/escape.gd`, which **extends `scenes/main.gd`** as
Kirkhaven's scene does, and builds its own world in `_ready`. Everything else is the
game's: `Player`, `KeeperAI`, the HUD, the pause menu, `Feel`, `FogBank`, the weapons.

**The boat never moves.** The *Mary Ann* (ReliefBoat's model at 1.6 times, with
`escape_fit`: a narrower wheelhouse, the funnel through its roof, the fore deck clear)
lies at the origin with her bow to +X, east, the right of the screen. The world goes past
her: a node `world` is moved by how far she has come and how far across the channel she
is, and holds the rocks, the arms, the coast and the rock itself; the sea
(`shaders/escape_sea.gdshader`) and the fog (`shaders/fog_bank.gdshader`'s new `scroll`)
shift their patterns the same way. So the keepers stand on a deck that is always still: a
`StaticBody3D` (floor, bulwarks, wheelhouse) that doesn't roll, while her model rolls,
pitches and yaws a little in the swell and as she is steered. Steering moves her across a
channel 5.5 m either way.

**Terrain.chapter is 3** while it plays: `Terrain.height_at` and `walkable` hand over to
`EscapeMap` (her deck), `KeeperNav.route` to `EscapeMap.route` (round the wheelhouse),
and `CameraDirector` frames her (`EscapeMap.FOCUS`, `ZOOM`): the boat a little left of
the middle so what comes from ahead shows in time. Everyone aboard shares one view, so
the split screen never opens. `Run.chapter` is 3 too (`Jobs.list()` is empty there, and
the save says the Escape).

| File | What |
|---|---|
| `escape/escape.gd` | the scene: the boat, the sea, the fog, the rock and its beam, the run, steering, hazards, waves of boarders, surges, the hull, the light, the end; the autopilot (`_steer_for`, `_safest`); what the helpers ask (`helm_free_for`, `threat_for`, `post_for`) |
| `escape/escape_map.gd` | `EscapeMap`: the deck's numbers, height, walkable, routes, the climbing places, her hull's outline |
| `escape/escape_helm.gd` | `EscapeHelm`: the wheel (an interactable), who has it, Dod Wiseman's model and place |
| `escape/boarder.gd` | `Boarder` (an `Enemy`): swim, climb, board, loose on the deck, grab, bloat and burst, knocked off, flee |
| `escape/sea_arm.gd` | `SeaArm` (an `Enemy`): lurk, rise, rear, slap, lie, sink, recoil; its tube rebuilt each frame |
| `escape/escape_hud.gd` | the Escape's card: miles to the rock, the hull, the wheel, the seven |
| `shaders/escape_sea.gdshader` | the open sea, scrolled; her wake and wash |

Small hooks added to shared code:

| Where | What |
|---|---|
| `Terrain` | chapter 3: `height_at`, `walkable` to `EscapeMap`; `beach_weight` 0, no holm, bridge, ledge, islet |
| `KeeperNav.route`, `CameraDirector.focus_for` / `zoom_for_keeper` | chapter 3 |
| `KeeperAI` | `_escape()` (the "helm" and "deck" roles), `_repel()`; a helper at the wheel (`in_menu`) is left to it |
| `ReliefBoat` | `escape_fit` |
| `Outfits` | Dod Wiseman's look ("wiseman": yellow oilskins); a look may name its model |
| `Run` | `enter_escape`, `escape_continue`, `escape_carry` |
| `Jobs.list()` | empty in chapter 3 |
| `StoryText` | `crossing_before`, `crossing_after` (`crossing` is both) |
| `harbour.gd` | `_after_town` shows pages 1 and 2, then `_to_escape` |
| `main.gd` | Continue with a chapter-3 save goes to `go_escape`; the `--escape` argument |
| `title.gd`, `strings.gd` | "Continue (the Escape)" |
| `fog_bank.gdshader` | `scroll` (zero everywhere else) |

The HUD (`scenes/ui/hud.gd`) is not changed: its light card is made invisible by the
Escape (`_quiet_hud`) and its game-over card's two lines are reworded after it is shown
(`_on_run_ended`); the Escape's own card is `escape_hud.gd`. Keepers' hunger and warmth
don't run on the crossing (the Escape keeps them full).

**A keeper at the wheel** is held with `Player.in_menu` (they stand, take no other input)
and `EscapeHelm` reads their move keys and Use itself, so `player.gd` is untouched. The
helm processes after the keepers (`process_physics_priority`), so the press that lets go
isn't taken as a press to take it again.

## Flow, save and Continue

1. Kirkhaven: the Mary Ann sails; `_after_town` fills `Run.carry` (stock, arms, the
   living, the lost, the sea), shows crossing pages 1 and 2, and loads `escape.tscn`
   with `Run.enter_escape`.
2. The Escape takes the carry into `Run.escape_carry` (empties `Run.carry`, so the rock
   doesn't begin by mistake), applies it to a fresh run, and writes the save: the run's
   snapshot with `"chapter": 3` and `"carry"`.
3. Foundered (or every keeper down): `Run.end_run` clears the save as for any lost run,
   then the Escape writes its save again. Continue on the title (`main.begin_run` sees
   chapter 3, `go_escape(n, true)`) and Try again (`hud._on_new_run` reloads the scene,
   which finds `Run.escape_carry`) both begin the crossing again as it was off the pier.
   Quit to the title: the scene, reloaded with nothing asking for it, empties the carries
   and goes to `main.tscn`.
4. In under the light: the save is cleared; crossing pages 3 and 4 (naming anyone lost on
   the way); `Run.carry` is the store, arms, living and lost as they now are; `main.tscn`
   begins Act Two from it exactly as it did off the pier.

For testing: `godot --path . -- --escape [calm|angry|raging]` starts it straight from the
title screen's scene, with Kirkhaven's kit and all seven.

## Runs played by the computer's keepers (2026-11-11)

`tools/playtest_escape.gd -- [calm|angry|raging] [helpers|dod|careless] [speed] [runs]`:
three computer keepers (one at the wheel, two at the gunwales), or Dod at the wheel and
all three fighting, or nobody steering or fighting.

| Sea, who steers | Runs | Result |
|---|---|---|
| Calm, a helper | 3 | all in; hull 130 of 130 each time; none lost, nothing got aboard |
| Calm, nobody (careless) | 1 | in, hull 73 of 130 (1 rock, 3 arms) |
| Angry, a helper | 6 | all in; hull 41 to 95 of 100 (0 to 2 arms, 0 or 1 rock); lost 0, 1, 3, 0, 2 and 5 of the seven; 4 to 11 of 57 to 67 got aboard |
| Angry, Dod | 1 | in, hull 56 (2 arms), none lost |
| Angry, nobody (careless) | 1 | foundered after 60 s (5 arms) |
| Raging, a helper | 3 | all in, but only just: hull 12, 20 and 24 of 90; lost 4, 4 and 7 |
| Raging, Dod | 1 | in, hull 40, one lost |
| Raging, nobody (careless) | 2 | foundered after 44 and 72 s (4 arms each) |

The computer's keepers alone on an angry sea get her in with a loss or two, sometimes
none, now and then most of them (a surge that two keepers can't reach in time); nobody
at the wheel sinks her on any sea but the calm one. The helpers fight better than they
steer: what costs her hull is mostly the arms, and the bloated bursting on her deck.

## Not done

- Nobody has played it. The numbers were set against the computer's keepers.
- LAN: the Escape is local only, like Kirkhaven.
- No sounds of its own: the boat's horn, wave crashes, splashes and the creatures' groans
  are the game's existing sounds.
- The camera only looks down from the south, so climbers on her far side are partly hidden
  by her hull (the **!** marks are for that).
