# Roadmap after v0.2.0

Status: **ideas, in priority order.** Do these after playtests of v0.2.0, not before. Original text, unchanged:

```text
1. Fix what playtesting reveals (before adding anything)
The telemetry and the six playtest checks will tell you which of these is true:
Nights feel samey → the spawn table is the problem, not the enemy count. Vary order and direction before adding enemies.
Players never use focused beam → the Squid isn't threatening enough, or the mode switch isn't readable. Fix with a stronger tell, not more damage.
Nobody plants the garden → its payoff is too slow. Shorten to maturing by dusk of the same day, or make food also refill a flare.
Runs end around the same night every time → a difficulty cliff. Smooth it before anything else; a cliff kills "one more run."
Co-op players all stand at the lighthouse → the island needs one more thing worth protecting at a distance. This is where the garden should already be doing work.
2. Make the restart loop stickier (the single biggest lever)
The brief's definition of done is "players voluntarily start another run." These cost little and target that directly:
Run summary screen at game over: nights survived, Anger curve, what killed you, enemies killed by type, best night. People restart to beat a number they just saw.
Daily rock: a fixed seed per calendar day (same spawn order, same oil nights) with a local best-night board. Zero new content, high replay.
Unlockable keepers: cosmetic characters unlocked by milestones (survive night 5, repel an Eel, survive a night with the lamp Guttering). Cosmetic only — the brief rules out classes.
A single modifier menu: "Thick Fog", "No Flares", "Two Oil Barrels". Each is one line of Balance.
3. Add variety inside the existing frame
Only after 1 and 2. Each of these respects "one island, four resources, three upgrade paths":
Weather nights: a storm night every few nights — fences take passive damage, the beam range shrinks, Squids don't spawn. Changes decisions without new entities.
Special nights: "Crab tide" (only crabs, many), "Silent night" (no spawns, Anger drops, but oil washes up — the tempting trade).
A fifth enemy, chosen to fill the one tactical gap: nothing currently threatens the operator. Something that climbs the lighthouse and must be knocked off by another player creates the co-op moment the Eel only half delivers. For solo, it forces you off the lamp briefly.
One more trap tier per existing trap rather than new trap types.
Dawn events: a drifting wreck washes up with a one-time choice (take the scrap and Anger +1, or let it go).
4. Deepen systems that already exist
Lamp mastery: let a skilled operator do things with timing — a brief "flare" overcharge on a cooldown, or a sweep that staggers everything it crosses if held for 3 s. Skill ceiling without a skill tree.
Structure personalities: the lighthouse at low HP leaks fuel; a destroyed fence section leaves rubble that slows Crabs. Make damage interesting, not just a repair bill.
Anger made legible at the edges: the sea itself changes colour, the shoreline creeps inward a metre at band 9–10. Players should feel the hidden stat without reading it.
5. Presentation, in order of cost-to-impact
Real creature models and tells (biggest jump in perceived quality).
Sound design for tells — cheap, and your audio brief already covers it.
A short opening: 15 seconds of the keeper rowing in, radio crackle, lamp ignites. No story beyond that.
Dynamic music layers keyed to Anger band.
6. Platform and reach
Steam once itch.io shows retention. Steam Input makes controller rebinding easier than what you built.
Steam Remote Play Together gives you online co-op for free without writing netcode. Do this before ever considering real online multiplayer.
Linux/Steam Deck export is nearly free in Godot and the fixed-screen, controller-first design suits the Deck well.
```

Note on point 2, "Unlockable keepers": the four keepers on the concept sheet (Callum, Hamish, Mairi, Ewan) are natural candidates. See `docs/ART_DIRECTION.md`.
