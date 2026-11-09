# Enemies

Read from `scenes/enemies/*.gd`, `scenes/systems/spawner.gd`, `scenes/systems/difficulty.gd`, `scenes/systems/lamp.gd` and `scenes/player/arsenal.gd` (v0.1.3). Numbers are the code's. Damage to a keeper is multiplied by `Difficulty.keeper_damage()` (0.6 calm, 1.0 angry, 1.3 raging) in `Player.take_damage`; a blow of 25 or more after that floors the keeper (`FLOOR_FROM`), 12 or more makes them stagger (`FLINCH_BELOW`). Structure damage is not scaled.

## The five creatures

| | Bloated Dead | Squid | Crab | Eel | Smotherer |
|---|---|---|---|---|---|
| File | `bloated.gd` | `squid.gd` | `crab.gd` | `eel.gd` | `smotherer.gd` |
| hp | 60 | 35 | 150, +20% per extra person | 90, +20% per extra person | 50 |
| Speed (m/s) | 1.15 | dash 4.5 | 1.2 | none (a spline body) | 1.4 |
| Mass | 2.0 | 0.8 | 5.0 | 50 | 1.2 |
| Shoved off the ledge | yes | yes | no | n/a | yes |
| Blows to floor it | 3 (it bursts anyway) | 2 | never ragdolls from blows | n/a | 2 |
| Target | lighthouse; raid groups the nearest of cottage, shed, garden; camp groups the camp | nearest keeper on its island who is not indoors, else the camp (camp groups) or the lighthouse | see below | the lighthouse | the lighthouse |
| First night | 1 | 2 | 3 | 5, or 6 with one person | 4 |
| Drops | 35% one kelp when killed | 50% one bio | 2 scrap (always, in practice) | 3 bio and 2 scrap at the lighthouse's foot | 40% one scrap |

`Players.humans()` (people, not helpers) scales the Crab's and Eel's hp: 1 person 150/90, 2 people 180/108, 3 people 210/126. Nothing else has hp that scales.

## Shared behaviour (`scenes/enemies/enemy.gd`)

State machine by name: `change_state(&"X")` calls `_exit_<old>`, `_enter_X`, and each physics frame `_tick_X`. Common states: `Emerge` (1.6 s rising from the sea, immune), `Approach`, `AttackFence`, `Arrived`, `Stagger`, `Ragdoll`, `GetUp`, `Retreat`.

- **Landing:** the spawner churns the water at a landing point for 4 s (`OMEN_TIME`), a foghorn sounds and the HUD names the compass direction ("Something stirs in the water: south-east."), then creatures surface 0.3 s apart (`STAGGER`) within 1 m of the point.
- **Walking in:** on a beach below the meadow they wade at half speed (`WADE_MULT`). They follow `Nav` waypoints (up the beach, round the crag's foot, up the ledge) and ignore the ground collision. A fence or barricade in the way (`Fence`, `CampWire`, `SandbagWall`, group `barricades`) makes them stop and hit it for 10 every second (`FENCE_HIT_DMG`, `FENCE_HIT_INTERVAL`); the Crab slams it instead.
- **Fall damage:** a drop over 1.2 m hurts 14 per metre; into the sea is death. A blow aimed outward (dot above 0.35) on the ledge shoves anything lighter than mass 3 over the edge.
- **Poise:** a boathook blow within 3 s of another counts toward `poise_hits` (2; Bloated 3); the blow that reaches it knocks it flat as a ragdoll for 0.8 s, the others make it reel for 0.55 s.
- **Fire and poison:** `set_alight(t)` burns 8 hp/s while `on_fire`; `poison(t)` does 3.5 hp/s and slows to 0.7. Entering the sea puts out fire. Held in the focused beam or the flamer's stream, `burning` stops it where it stands.
- **Ink:** a creature inside an `InkCloud` (radius 4 m, lives 5 s) is invisible unless a beam, flare or searchlight is on it that frame.
- **Dawn:** `on_dawn()` puts everything in `Retreat` (a route to the nearest beach, twice its speed, collisions off, sinks and is freed); a Bloated already swelling still bursts; the Smotherer is lowered from the tower first; the Eel releases.
- **LAN:** creatures are host-only; clients get puppets from `net_snap()` (the Eel also sends its segment positions and head transform).

## Bloated Dead

States: `Emerge`, `Approach`, `AttackFence`, `Arrived`, `Bloat`, `Burst`, plus the shared ones. It walks to its target, and at `reach` 3.5 m from the lighthouse's centre (or within 1 m of a building's wall) it stops and **bloats for 1.2 s**: it swells, glows pale green and pulses up to 30%, with a groan. Then it **bursts**: every structure within 3 m of it (`surface_distance`) takes 40, every keeper within 3 m takes 30 (so 30 on an angry sea, which floors them). Reaching the light costs the lighthouse 40 of its 200 hp.

- **Tell:** yellow-green eyes, a groan every 6 to 12 s, the swell and glow before the burst.
- **Killing it does not stop the burst.** `_die()` sends it into `Bloat`, so it still goes off 1.2 s later where it fell; burn it or shoot it before it is near a building. A spike board makes a Bloated take its whole hp at once, so it bursts on the trap, away from anything.
- **Wide beam:** speed x0.6 and it cowers (squats and swells 12%). **Focused beam:** 10 hp per second times `Lamp.dps_mult`, held in place; a Bloated that dies of the beam hisses and pops with steam. 60 hp is about 6 seconds on level 1.
- **Boathook:** 20 per blow, three blows. **Flamer, bomb:** it stops and burns, bursts when it dies.
- **Raids:** from night 2 every second Bloated group of a night (`_bloated_groups % 2 == 0`) is a raid group if the cottage, shed or garden still stands: it makes for the nearest of them and the HUD adds "They're making for the cottage!". From night 2 a group of 3 or more that is not a raid splits across two beaches.
- **Garden:** every hit on the garden (a burst is 40) ruins one growing bed; a wrecked garden loses all.

## Squid

States: `Emerge`, `Stalk` (it has no `Approach`: `_enter_Approach` goes straight to `Stalk`), `Lunge`, `BackOff`. It does not use `Nav`; it moves straight at its target and crawls up cliffs and the crag (the body tilts with the slope).

- **Stalk:** dashes 1.0 s at 4.5 m/s, pauses 0.6 s, repeating, re-choosing the nearest keeper at each pause. A structure in the way that is not its target: it climbs it (0.9 s, rises 1.4 m, collisions off while climbing).
- **Lunge:** inside 1.5 m it stops and **flashes its dots for 0.65 s** (the tell), then strikes for 10 on a keeper or on a structure if that is its target, then `BackOff` 3 m (about 0.65 s) and stalks again.
- **Ink:** every 8 s (first at 4 s) it drops an `InkCloud` where it is, while stalking or backing off.
- **Wide or focused beam:** speed x0.4 either way. **Focused:** 15 hp per second times `Lamp.dps_mult` (about 2.3 s), it squeals and an "!" shows over it. Its probe points are low (0.2 and 0.5 m), so a beam must reach the ground where it is.
- **Boathook:** two blows (35 hp, the first staggers it, the second within 3 s floors it). Light, so it can be shoved off the ledge. Spike boards, chain plates and poison bait skip it ("skitter over it"); nets tangle it for 3 s.
- Dies with a burst and splash; 50% to leave one bio.

## Armoured Crab

States: `Emerge`, `Approach`, `AttackFence` (becomes `WindUp`), `Arrived` (becomes `WindUp`), `WindUp`, `Slam`, `Recover`, `Rummage`. Slow, heavy, 150 hp, never staggers from blows, can only be knocked down by a chain plate (`flip`).

- **Target order (`pick_target`):** a keeper who has hit it three times within 5 s (the grudge, lasts 8 s, same island, not indoors or downed); else, on a camp raid, the nearest camp building; else the nearest standing cottage, shed or garden; else the lighthouse.
- **Cycle against a building:** `WindUp` 1.5 s (claw rises and glows hot, a creak and a rattle) then `Slam` (0.15 s) then `Recover` 1.0 s then `Rummage` 2.5 s (it tears at the building) then `WindUp` again, until the building is wrecked. Wrecking the cottage, shed or garden: the message "The crab drags itself back to the sea." and it retreats. Against a keeper it goes `WindUp`, `Slam`, `Recover`, `WindUp` with no rummage.
- **Slam:** structures within 2.2 m and in a 60 degree arc ahead (and the one it aims at) take 30; keepers within 2.5 m in the arc take 25 and are shoved 9 m/s; a set trap in front is wrecked; the camera shakes.
- **Armour:** a blow from within 60 degrees of its front does half (sparks, a clang); a blow in `Recover` does double; a flipped crab (chain plate: 3 s times the defence multiplier) takes double from keepers for 5 s. From behind during a wind-up is the usual opening.
- **Wide beam:** nothing. **Focused beam during `WindUp`:** interrupts it, stagger 1 s, once per 4 s. It does no burn damage, so a crab is a job for the boathook (150 hp is 8 clean blows, 15 from the front), arrows, the shotgun, the flamer or traps. The flamer and bombs burn it.
- Spike boards do 25 (times 1.0/1.5/2.0 by defences level); nets are ignored; poison works.

## Giant Constrictor Eel

One at a time (`group "eel"`); other landings that night shrink to a quarter while it is about (`EEL_RATE`, at least 1). It takes damage only in `Coil`. It does not use the shared states.

1. **Announce (8 s):** a horn (3 s), "The water is moving.", six dark churns circling the landing point. Nothing to hit. If dawn comes now it is freed.
2. **Surge (3 s):** the head and 18 segments race in a straight line from the landing point toward the lighthouse (stopping at 82% of the way). Every `Fence` the line touches is destroyed outright (10000 damage); any keeper within 1.2 m of the line (and within 2.5 m in height) is knocked prone for 1.5 s. The camera shakes hard.
3. **Coil (20 s, 25 s with one person):** it winds 2.5 turns up the tower, the head circles at 6.6 m out and 3.6 m above the crag top, crushing the lighthouse for 5 hp per second ("The Eel has the lighthouse! Burn its head with the focused beam!").
4. **Release (2 s):** it slides back; if it was not killed, **Anger +2** and "The sea is angrier."

- **Damage:** the focused beam on its head does 12 per second times `Lamp.dps_mult` (about 8 s on level 1 for 90 hp), with an eel hiss. Boathook blows are scaled x0.25 (5 each) and any other weapon a person fires, throws or sprays from a bomb hit x0.5 (`MELEE_MULT`, `RANGED_MULT`). By reading the code, flamer flames and fire pools are sent without a keeper as the source, so the 0.5 does not apply to them; this has not been tested in play.
- **Killed:** "The Eel lets go!", **Anger -1**, three bio and two scrap fall at the tower's foot (3.2 m south), then `Release`.
- Traps ignore it (`TrapSlot` skips `Eel`).
- **Nights:** `Spawner.eel_night(n, humans, anger)`: first night 5 (6 with one person), then every third night; with Anger 6 or more it comes a night early. Added to the night's table at t = 0.42. Not on the holm.

## Smotherer

States: `Emerge`, `Approach`, `Arrived` (becomes `Climb`), `Climb`, `Smother`, `Fall`, `Stunned`. A gaunt drowned figure, pale eyes in black sockets.

- **Approach:** walks to the tower by `Nav`; the wide and the focused beam both only slow it (x0.6); the beam does not burn it. On the ledge a keeper can kill it (50 hp, three blows) or shove it off.
- **Climb:** at the tower it climbs 1.3 m/s (about 6 seconds to the lantern): "Something is climbing the lighthouse!" and a creak. While on the tower it is not targetable by the beam, and `take_damage` ignores every source (keepers, arrows, flames).
- **Smother:** it wraps over the lantern. `Lamp.smother(true)`: the beam's energy x0.12 and its range x0.3 (the HUD reads "Lamp: SMOTHERED"); it cracks the lighthouse 2 hp per second. It stays until removed or dawn.
- **The only answer is the boathook thrown** (`Player._climber_in_reach`, attack button): from within 10 m of the tower at crag-top height. The harpoon (`scenes/systems/harpoon.gd`) flies at 20 m/s, homes on it, knocks it off (15 damage, the lamp uncovered), falls to the tower's foot and lies there glinting; the keeper walks over it (1 m) to get it back, and has nothing to swing until then. It returns by itself at dawn. A rigged Smotherer drops as a ragdoll; one without a model falls, takes fall damage and is `Stunned` 1.5 s, then walks back. A keeper holding the ledge can kill or shove one off before it reaches the tower (`docs/DECISIONS.md`).
- Spike (25), net (3 s), chain (1 s stagger), poison all work. Drops 40% one scrap. Not sent to the holm.

## Spawning (`scenes/systems/spawner.gd`)

`night_table(n)` rows are `[t, kind, count, "opp"]`, where t is the fraction of the night and "opp" lands on a different beach from the night's first group. Base counts before any scaling (B Bloated, S Squid, C Crab, M Smotherer):

| Night | Rows | Total |
|---|---|---|
| 1 | .06 B2, .32 B2, .58 B3 | 7 |
| 2 | .06 B2, .24 S2, .44 B3, .62 S2 | 9 |
| 3 | .06 B3, .20 C1, .38 S2, .55 B3, .68 S2 | 11 |
| 4 | .04 S2, .12 B3, .28 C1, .36 M1, .44 B4, .56 S3, .68 C1 | 15 |
| 5 | .06 B3, .20 C1, .32 S3, .52 M1, .62 B4 | 12 |
| 6 | .04 B4, .16 S3, .28 C2, .36 M1, .44 B4, .56 S3, .68 C1 | 18 |
| 7 | .04 S3, .12 B4, .24 C2, .32 M1, .40 B5, .52 S4, .60 M1, .68 C2 | 22 |
| 8 | .04 B4, .16 C2, .28 S4, .50 M2, .60 B5, .72 S3 | 20 |
| 9 and later | the night 7 rows, plus (n-7)/2 rounded down per row from night 9 | |

Scaling, in order: add `floor(Anger / 3)` to every row (night 9 on, `floor((n-7)/2)` too); on the last night before the boat (`Rescue.night()`) each row becomes the larger of count + 1 and count x 1.3 rounded; then `group_size`: x(1 + 0.5 per extra person) x the sea's `CREATURES` (0.7 calm, 1.0 angry, 1.35 raging), rounded, at least 1; while an Eel is about, x0.25. The solo angry sea therefore faces 7 creatures on night 1 and, on the 10th (last) night with Anger 0, the night 7 rows plus 1 each, then the last-night surge.

Which creatures are sent to the holm (the camp): from night 2, every third group of B, S or C in the night's order (from night 5, every second) lands on the holm's two beaches and makes for the camp (`camp_raid`), so the main island sees that many fewer. Not M, not the Eel. If the camp has fallen (no generator or building standing) nothing is sent there. A camp group arrives with its own warning (`holm_warning`); with the alarm bell researched the camp's bell rings and names the beach.

## Raiding the camp

Raiders on the holm use the holm's own graph in `Nav` (up each beach straight at the wire, then to the generator and buildings); the holm is not joined to the main island. `Camp.targets()` is the generator, the quarters, the mess, the greenhouse (whatever still stands), and the wind turbine only while something else stands. The wire (`CampWire`, 120 hp, mended 60 per scrap or driftwood) is a barricade: they tear at it first, under the four searchlights. A Bloated bursts at a building (40); a Crab slams it (30, then rummages); a Squid goes for the nearest keeper on the holm first. Wrecked, each building stops working until mended (see `docs/DESIGN.md`). Creatures inside the lit wire (turbine standing, dusk to dawn) move 15% slower (`Camp.LIT_SLOW`). Researched barbed wire slows to x0.35 and cuts 5 per second, tripwires fire a 40-damage flare, sandbag walls (160 hp) hold them.

## What each weapon does

| Source | Numbers | Bloated | Squid | Crab | Eel | Smotherer |
|---|---|---|---|---|---|---|
| Wide beam (lamp, searchlight) | cone 35 degree half-angle, 26 m (+3, +6 by level) | x0.6 speed | x0.4 speed | none | none | x0.6 speed, not on tower |
| Focused beam | 10 degree half-angle, 29 m; fuel 1.0/s vs 0.35 | 10/s burn, held | 15/s burn, held | stun a wind-up | 12/s at the head, only in Coil | none |
| Boathook | 20, 2.5 m, 60 degrees, 0.6 s (x1.25 when cold) | 3 blows | 2 blows | 20, half from the front, double in Recover | 5 | 3 blows, only off the tower |
| Longbow | 12 to 40 by draw (0.8 s), range 26 | | | | x0.5 | off the tower |
| Shotgun | 9 pellets x 7 (x1.6 inside 3.5 m), 24 degree cone, 11 m | | | | x0.5 | |
| Flamer | 34/s, 5.5 m, 17 degree half angle, then 8/s for 2.5 s | stops, burns | stops, burns | burns | see above | burns |
| Petrol bomb | 20 and alight 4 s; pool 2.3 m for 7 s at 16/s | | | | x0.5 | |
| Flare | 40 on hit; burns 8 s, lights like the wide beam within 3.5 m and clears ink | | | | 40 in Coil | |
| Harpoon (boathook thrown) | 15 | | | | | the only way on the tower |

A blank cell means the weapon does its full listed damage (a Smotherer on the tower takes none of it). Beam burn numbers are multiplied by `Lamp.dps_mult`: the lighthouse upgrade (x1.5, x2.0) and dirty fuel's boost (x1.5 for 30 s). A searchlight's focused beam uses the same `in_light`, multiplied again by 1.6 with the silvered reflectors research. Pools and flames are not scaled by anything. Which weapon landed the last blow is recorded in `last_hit` and shown in the dawn report ("burned", "over the edge", and so on).

## Where the code differs from `docs/NEXT_MILESTONE.md` and the plans

- **Squid:** climbs a structure in 0.9 s (the doc says 2 s, "exposed"; nothing marks it exposed). Also targets the camp on a holm raid.
- **Crab:** slam does 30 to structures (doc 50) and shoves keepers at 9 m/s (doc "4 m knockback"). Targets are the grudge keeper, the camp or the homestead, then the lighthouse; the doc's "traps, fences, lighthouse" order is not used (it wrecks traps in front of it when it slams). The front guard (60 degrees each side, 120 in all), the wind-up, the stagger and the scrap drop agree with the doc.
- **Eel:** matches the doc's timings and numbers; first nights 5 (6 solo) then every third, not "every 3 to 4"; the Eel is not a table row but `eel_night()`.
- **Bloated** (`docs/prompts/02_*.md` appendix): speed 1.15 (doc 1.6), kelp 35% (doc 30%); only raid groups go for the homestead (doc: all go for the garden first); no plot reset on a burst beyond the garden's "ruin one bed per hit".
- **Spawner:** wave size uses rounding of the whole product, not "x1.5 rounded up", and the rows' times are earlier than the appendix's (first wave at 0.06 of the night). The Anger bands (extra Squid points, Crab pairs, fog multiplier) are not implemented.
- **Smotherer:** not in either plan; designed after Plan 1 (`docs/DECISIONS.md`, "The Smotherer").
