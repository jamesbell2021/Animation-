# Sea They Are Angry: v0.1.0, Chapter One

The first release: all of Chapter One, from the first morning on the rock to the relief boat.

## The game

- **Keep the light burning on a North Sea rock,** late 1980s. By day, gather what the sea brings, mend, grow food, fill the lamp and get ready. At night, things walk up out of the water toward the light. Hold out until the relief boat comes, 8 to 12 nights depending on how hard the sea is.
- **Three islands:**
  - **the lighthouse's crag,** with its cottage, shed and garden;
  - **the holm,** across a swaying rope bridge, with an old wartime internment camp: generator, searchlight towers, huts, crops, research, and a 1980s wind turbine lighting its wire;
  - **Gull Rock,** reached by rowing boat, where the gulls nest.
- **Five creatures:** the Bloated Dead, the wall-crawling Squid, the armoured Crab, the giant Eel that coils round the lighthouse, and the Smotherer that climbs the tower to put the light out. From the second night some raid the camp instead.
- **Weapons:** the boathook, the lamp's wide and focused beams, flares, and what the shed can make: a shotgun, a flamer (pixel fire), longbows, petrol bombs and rat-poison traps.
- **Survival:** hunger and warmth, a garden and the camp's crops, gull eggs, meals at the cottage and the camp's mess.
- **Weather:** clear moonlit nights, squalls, and storms that build to a gale, with lightning, breakers, and wind that freshens, eases and veers.
- **Always three keepers:**
  - **Helpers:** the computer plays any keepers nobody else does.
  - **On one screen:** up to three people, with a split screen when they're apart.
  - **On the LAN:** one keeper to a machine.
- **Three seas:** calm (easy, ammunition never runs out), angry (the game as it's meant), and raging.

## New in this release

- **Music:** a score for each part of the day.
  - **The title:** "The Light on the Skerry", a slow air for tin whistle and harp.
  - **By day:** "Mending Nets".
  - **At night:** "The Water is Moving".
  - **The last night:** "Hold the Light", a driving reel.
  - **The endings:** "The Mary Ann" for going home, and "Dark" for a lost light.

  The music is made by `art/source/music/build_music.py`.
- **How to Play,** from the title and the pause menu: the keys as you've set them, the gamepad's layout, and a page each on the day, the night, the camp and Gull Rock, and playing together.
- **The sea's mood:** the HUD says how angry the sea is ("The sea is quiet" up to "The sea wants the light"). When the lamp gutters or the lighthouse is failing, the screen's edge pulses red.
- **Salvage:** creatures leave bio, scrap or kelp where they fall. Walk over it to pick it up. Anything left lying is taken back by the sea at dusk.
- **Debug overlay:** a developer's overlay in debug builds (F10).

## Playing it

- **Windows:** unzip `SeaTheyAreAngry-windows-x86_64.zip` and run `SeaTheyAreAngry.exe` (keep the `.pck` beside it).
- **Linux:** untar `SeaTheyAreAngry-linux-x86_64.tar.gz` and run `SeaTheyAreAngry.x86_64`.
- **Settings** (title or pause): volume, music and sounds; window or full screen; graphics quality and render scale; and every key.

## Known limitations

- Only automated tests and bots have played it all the way through. `docs/PLAYTEST_CHECKLIST.md` lists what to look out for.
- The Windows build is exported and its data checked, but it hasn't been run on Windows yet.
- Keepers row by code-posed arms (no rowing animation), so the hands don't truly grip the oars.
- Chapter Two, The Harbour, is set up by the ending but not built.
