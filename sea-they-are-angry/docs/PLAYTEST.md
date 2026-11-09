# Running a playtest

One page. For a person watching someone else play, or for yourself.

## Set up

1. Give them the build (the zip or the tar) and the version number on the title screen: **note it**.
2. Have them turn on Settings, Comfort and access, **Keep a local play log** (or start the game with `--telemetry`). Nothing is sent anywhere; you'll collect the file afterward.
3. Tell them only this: "Keep the light burning until the boat comes." Don't explain the controls: How to Play is on the title screen and the first days' jobs are on the right. Watching what they do without it is the point.
4. Tell them F12 saves a snapshot, and to press it whenever something feels off.
5. Play on the **Angry sea** with one keeper first. A second playtest can be two people, or the Raging sea.

## What to watch for

The six checks (the reasons are in `docs/BALANCING.md`). Tick them as you see them:

- [ ] The nights feel different from each other.
- [ ] They switch the beam to focused, and know why.
- [ ] They plant the garden, and eat what it grows.
- [ ] The runs end on different nights, not all the same one.
- [ ] More than one person is somewhere other than the lighthouse.
- [ ] The camp is mended after a raid, not left wrecked.

Also note, without saying anything: where they stand still and look puzzled, what they pick up and what they ignore, what they say out loud, and when they first reach for a control that isn't there.

## Five questions afterward

1. What did you think you were supposed to do at the start? When did that change?
2. When did you feel in control, and when did you feel lost?
3. Was there a night you wanted to try again? Which, and why?
4. What did you ignore that you now think you should have used?
5. Would you play another run? If not, what would make you?

## Collect

- The play log, `telemetry.jsonl`, and `feedback.txt`, from the game's user folder (the paths are in `docs/TELEMETRY.md`).
- Your own notes, the version, the sea and the number of keepers.
- Any video the player took, with their permission.

Then work down `docs/PLAYTEST_CHECKLIST.md` yourself for the things nobody asked about.
