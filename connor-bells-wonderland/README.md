# Connor's Carnival Chaos

(The folder is still called `connor-bells-wonderland` so existing clones and
commands keep working.)

*Tower of Frustration at the Travelling Fair.* A Godot 4.3 obstacle race for up to
8 contestants: you, friends on the same Wi-Fi, and AI leprechauns. Six fairground
sections end at Connor's Crown on top of the Grand Finale Tower.

It's a neon night fair under a starry sky with a big moon, shooting stars and
distant fireworks, and Belfast on the horizon: Cave Hill and the Harland & Wolff
cranes. The course is dark steel lit by orange, cyan, crimson and lime light
strips, with a pumping fairground dance soundtrack and particle effects and sound
on every jump, hit, pickup and item. There's also a **Paintball Battle** mode. Everything (course, characters, HUD, menus, music, sound
effects and particles) is built in code, so the project has no art or audio files.
The only assets are two fonts in `fonts/` (both SIL OFL 1.1): **Bungee**, chunky
fairground-sign capitals for the title, signs, countdown and big HUD text, and
**Russo One**, a sporty face for everything else.

## Run it

Install Godot 4.3 or newer (standard build, not .NET; on Omarchy or Arch,
`sudo pacman -S godot`), then from this folder:

```
./play.sh
```

On Windows: `play.bat C:\path\to\Godot_v4.3-stable_win64.exe`.

The launcher runs Godot's import first when needed. Without it, Godot can't find the
game's named scripts and stops with errors like `Identifier "CourseBuilder" not
declared`. To do it by hand, run `godot --path . --import` once (and again after a
`git pull`), then `godot --path .`. Opening the project in the Godot editor and pressing
**F5** also works.

| Action | Keyboard | Phone |
|---|---|---|
| Move | WASD or arrow keys | Left half of the screen (joystick appears under your thumb) |
| Jump | Space | Right half of the screen |
| Use item | E or F (hold for the Catapult) | USE button above JUMP (hold for the Catapult) |
| Fire paintballs (Paintball Battle) | Hold E or F | Hold USE |
| Pause / menu | MENU button | MENU button or Android Back |

To try the touch controls on a PC, tick **Force Touch Controls** on the `Main` node in
`scenes/main/main.tscn`, or enable *Project Settings → Input Devices → Emulate Touch From Mouse*.

## Start screen

The menu sits over a live night fair: contestants dance on a flashing dance floor
under a disco ball in time with the music, a Ferris wheel turns, searchlights
sweep, rockets go up behind the big top and shooting stars cross the sky. Pick
**Fairground Race**, **Tower Climb**, **Paintball Battle** or **Dodgem Derby**
under **Mode**.

## The course

| # | Section | What happens |
|---|---|---|
| 1 | The Big Top Entrance | Start grid, hurdles, two slow spinners |
| 2 | Dodgem Disaster | Dodgem cars cross and run the length of the arena |
| 3 | The Dizzy Rides | Carousel, waltzer with a sweeping arm, spinning teacups |
| 4 | The Bouncy Yard | Launch pads over a drop, bouncy castle wall |
| 5 | The High Rides | Sliding sky-gondolas, roller-coaster beam, Ferris wheels |
| 6 | The Grand Finale Tower | Spiral ledges, sweeping arms, Connor's Crown |

Coins are worth 1 gold and shamrocks 5. Falling returns you to your last checkpoint.

When the race ends, a fireworks display goes up over the winner, a drumroll plays,
and a present above their head bursts open with their prize, picked at random from
40 ridiculous ones ("PLAYER, YOU WON... A BRAND NEW TOASTER!", a wheelie bin cover,
a llama called Gary...). Everyone in a Wi-Fi race sees the same prize.

## Tower Climb

An extreme obby race up a 120 m neon tower. The path spirals round the outside in
eight stages, each starting on a numbered checkpoint landing:

1. **Stepping Stones**: zig-zag jumps up floating blocks
2. **Sweeper Stairs**: ramps up to railed pads with spinning sweeper arms
3. **Vanishing Tiles**: tiles shake and drop away moments after you land
4. **Spin City**: spinning discs between small stepping blocks
5. **Pusher Beams**: narrow ramps and pads with pushers trying to shove you off
6. **Bounce House**: bounce pads launch you up from ledge to ledge
7. **Meltdown**: vanishing tiles either side of a three-armed sweeper
8. **The Crown Climb**: small, far-apart blocks up to the golden summit

There are no walls: fall more than a few metres below your last landing and you're
back on it. Item boxes sit on every landing and along each stage, and every item is
in play (catapult yourself up a level, Mega Bomb the pack off a ledge, oil the
stepping stones...). The camera swings round to follow you up the spiral.

The first to reach Connor's Crown on the summit sets off a fireworks display over
the tower straight away; everyone else then has 45 seconds to finish. The winner
gets a big, crazy prize ("A SOLID GOLD TOILET (IT'S ACTUALLY CHOCOLATE)!", "A PET
GIRAFFE CALLED TOWER!", "A ZIP LINE FROM YOUR BED TO THE FRIDGE!"...). Bots climb
too (aiming their jumps); on Hard the best of them reach the top in about two
minutes. Works over Wi-Fi.

## Paintball Battle

Everyone starts round the edge of a walled, floodlit arena full of crates, bunkers
and low walls, with 5 lives and 12 paintballs. Hold the use button to fire: it
aims for a rival roughly in front of you that you can see. Each hit knocks a life
off and sends the victim flying, tumbling through the air, plastered in your paint,
with a puddle where they stood and spatter on the wall behind (and the screen goes
your colour for whoever got hit); after a hit you flash and can't be hit for a moment. Paint comes back slowly
on its own, or grab a glowing PAINT crate for a full refill. Lose all 5 lives and
you're out and watch the rest. After 2:30 it's sudden death (one life each), and
at 4:00 whoever has the most lives left wins.

The last one standing wins **a year's Fruit of the Month subscription: free fruit
delivered to your home every month!** (it's a joke prize), with the same fireworks
and present. Bots fight too: they keep their distance, strafe, stop to aim and
shoot, and go for paint crates when they run low. The camera swings round to look in
towards the middle of the arena from wherever you are. Paintball Battle works over
Wi-Fi as well; the host picks the mode in the lobby.

## Fairground Mayhem items

Each section has two rows of floating "?" boxes. Run through one with an empty item
slot to get an item; the box comes back after 3 seconds. What you get depends on your
place: the leaders mostly get traps and defence, the back of the pack gets the
Catapult, Rocket Boots, the Magnet and the Mega Bomb to catch up. Your item shows under
the gold counter and floats above your head. The **Items** switch on the main menu and
in the lobby turns item boxes off for a pure race.

Every item that hits a rival steals 1 gold from them, and every hit comes with
particles, a sound and, if it's you, a screen flash and camera shake.

| Item | How it works |
|---|---|
| Catapult | Hold the use button to pull back (an aim arc shows where you'll land), let go to launch yourself. Anyone you fly into is knocked flying, and you slam down on landing, blasting away racers nearby |
| Big Boxing Glove | Trap: punches the next racer away |
| Big Springer | Trap: launches the next racer sky-high |
| Slippery Oil | Trap that stays 12 s: everyone who crosses it slides about for 4 s |
| Big Fatty Cake | Trap: the victim goes big, round and slow for 6 s |
| Shrink Potion | Trap: the victim goes tiny for 6 s |
| Plastic Sword | 3 swings: a giant sword sweeps across in front of you with a glowing trail and whacks whoever it catches |
| Zapper | 3 zaps: stuns racers in front of you, and the bolt jumps to one more rival standing next to each victim |
| Balloon | 2 uses: racers in front float up helplessly, then drop |
| Custard Pie | 2 throws: lobbed about 9 m ahead; whoever it hits gets custard all over their screen |
| Mega Bomb | Blasts everyone within 5.5 m away |
| Rocket Boots | Double speed for 4.5 s with a flame trail; barge through anyone in your way |
| Giant Magnet | For 7 s pulls in every coin within 9 m, drags nearby rivals towards you and steals their gold |
| Shield Bubble | For 15 s: bounces off anyone who touches you and reflects the next attack back at whoever made it |

Traps can only be dropped on solid, still ground; on a ride or over a gap the item is
kept until you can. Bots grab boxes they pass (and detour for one nearby), use items
when a rival is in reach, and aim the Catapult at gaps and rivals ahead.

## Dodgem Derby

Everyone drives a dodgem car on a round neon rink built on a pier out in the Irish
Sea, with Belfast across the water. Ram your rivals off the edge: the faster you
hit, the further they fly, and hitting them from the middle sends them outwards.
**JUMP is a boost** (it recharges in under two seconds) for the big hits. Item
boxes are on the rink too, and every item helps: the Mega Bomb, Boxing Glove and
Big Springer can launch a car right over the rail, Slippery Oil sends them
sliding, the Giant Magnet drags them in, the Shield bounces rammers off, Big
Fatty Cake makes you heavy and hard to shift, Shrink Potion makes you fly further.

A rubber rail runs round the outer ring with six gaps marked by red posts, so at
first you have to shove people through a gap or blast them over. Fall in the sea
and you lose one of your 3 lives and drop back into the middle (safe for a
moment). The rink shrinks: the outer ring (rail and all) sinks at 1:00, the next
at 1:35 and the last at 2:10, leaving the centre disc. At 3:10 the most lives wins.

The derby has its own music: 150 BPM hardstyle with distorted kicks, a reverse
bass, a screeching lead and air horns. The last driver left wins a daft prize
("A PEDALO TO CROSS THE IRISH SEA!", "A JELLYFISH CALLED JEFF!"...). Bots ram,
boost, use items and steer back from the edge. It works over Wi-Fi too.

## Wi-Fi multiplayer

One device presses **Host Wi-Fi Game**; the lobby shows its IP address. Others type that
IP and press **Join Wi-Fi Game** (use `127.0.0.1` for two copies on one PC:
*Debug → Customize Run Instances → 2*). The host sets sections, bots, difficulty and
countdown, then presses **Start Race**. The host simulates everything; clients send
their input and see smoothed copies. If phones can't see each other, check that the
router doesn't have "AP isolation" turned on.

## Android build

`export_presets.cfg` holds an arm64 Android preset (landscape, immersive, network
permissions). Install the Godot 4.3 export templates, the Android SDK and JDK 17, set
their paths and a debug keystore in *Editor Settings → Export → Android*, then
*Project → Export → Android → Export Project*. The APK goes to `build/`.

## Renaming the game

All of Connor's branding lives in `scripts/game/branding.gd`: the title screen, the big
top sign, the crown sign, the results title and the welcome and win messages. Change it
there to re-theme the game. The app name in `project.godot` and `export_presets.cfg` is
set separately.

## Layout

```
scenes/          five tiny scenes, each just a root node with a script
scripts/game/    game manager, race rules, checkpoints, ranking, roster, quality tiers, branding
scripts/course/  course builder, section base class, the six sections, scenery and coins,
                 night sky (stars, moon, shooting stars) and the Belfast skyline
scripts/obstacles/ spinners, moving platforms, dodgem cars, bounce pads
scripts/player/  contestant, leprechaun model, stumbles, camera, touch controls, status effects, item slot
scripts/ai/      bot personalities, route, driver
scripts/network/ ENet lobby (autoload), per-contestant sync, race event sync
scripts/ui/      HUD, splat overlay, main menu, lobby, pause menu, the live 3D menu backdrop,
                 fonts and the shared panel/button style
fonts/           Bungee and Russo One with their licences
scripts/items/   coins, item boxes, item rules, traps, custard pie
scripts/paintball/ Paintball Battle: arena, rules, paintballs, paint splats, crates, bots
scripts/dodgems/ Dodgem Derby: rink over the sea, rules and bumping, dodgem cars, bots
scripts/tower/   Tower Climb: the tower course, its eight obby stages, vanishing tiles
scripts/fx/      particles, fireworks shows, the prize present, the sword swipe
scripts/audio/   synthesised sound effects and hard dance music
tools/           headless bot race and item tests (not exported)
studio/          3BL_Indie splash (first autoload) and credits screen, shared with the other games
```

**3BL_Indie splash and credits.** `studio/splash.gd` is the first autoload: it shows the 3BL_Indie logo for about three seconds at launch (any key, click, tap or button skips it; headless runs and `--no-splash` skip it). `studio/credits.gd` is the credits screen opened from the main menu's Credits button. Both files are shared word for word across the 3BL_Indie games, so change them in every game together. See `CREDITS.md`.

## Headless tests

A race with 7 bots checks that the course can be completed and that items get used:

```
godot --headless --path . --fixed-fps 60 -s res://tools/bot_race_test.gd -- diff=2
```

`diff=0` is Easy, `1` Medium, `2` Hard; add `items=off` to race without item boxes. It
prints progress every 20 seconds, the results, and how many items were picked up, used
and landed. Typical Hard runs: the winner finishes in 70–80 s, with 40–60 items picked up and
50–100 hits landed. (Headless runs print a harmless `mesh_get_surface_count` error from
the dummy renderer when particles fire.)

The item test gives the player each item in turn and checks it does what it should
(21 checks, including the Catapult launch, ram and landing slam, the rocket barge, the
magnet stealing gold, gold theft on hits and the shield reflecting an attack):

```
godot --headless --path . --fixed-fps 60 -s res://tools/item_test.gd
```

A Paintball Battle with 7 bots (and an idle player, who is usually first out), then
Play Again and a second battle. It prints who knocks out whom, the results, and how
many shots, hits and crate refills there were. Battles usually last 30–55 s:

```
godot --headless --path . --fixed-fps 60 -s res://tools/paintball_test.gd -- diff=1
```

## Promo reel

`tools/reel/make_reel.sh` records a ~35 s vertical (1080x1920) gameplay reel for
Instagram Reels or sending to a phone: the title, a race start with item chaos, a
Paintball Battle, the fireworks-and-prize finale and an end card. Connor is played
by the AI, captions pop up in Bungee, and the game's dance track runs underneath.
It uses Godot's Movie Maker (frame by frame, so it takes a while) and ffmpeg:

```
GODOT=godot tools/reel/make_reel.sh reel.mp4
```

A Dodgem Derby with 7 bots and an idle player, then Play Again and a second derby.
It prints every splash into the Irish Sea, the results, and counts bumps, boosts and
item uses. Derbies usually last 70–110 s:

```
godot --headless --path . --fixed-fps 60 -s res://tools/dodgems_test.gd -- diff=1
```
