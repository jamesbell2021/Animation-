# Connor Bell's Wonderland

*Tower of Frustration at the Travelling Fair.* A Godot 4.3 obstacle race for up to
8 contestants: you, friends on the same Wi-Fi, and AI leprechauns. Six fairground
sections end at Connor's Crown on top of the Grand Finale Tower.

It's a neon night fair: a dark steel course lit by orange, cyan, crimson and lime
light strips, with a disco soundtrack, particle effects and sound on every jump,
hit, pickup and item. Everything (course, characters, HUD, menus, music, sound
effects and particles) is built in code, so the project has no art or audio files.

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
| Pause / menu | MENU button | MENU button or Android Back |

To try the touch controls on a PC, tick **Force Touch Controls** on the `Main` node in
`scenes/main/main.tscn`, or enable *Project Settings → Input Devices → Emulate Touch From Mouse*.

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
| Plastic Sword | 3 swings: whacks racers just in front of you |
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
scripts/course/  course builder, section base class, the six sections, scenery and coins
scripts/obstacles/ spinners, moving platforms, dodgem cars, bounce pads
scripts/player/  contestant, leprechaun model, stumbles, camera, touch controls, status effects, item slot
scripts/ai/      bot personalities, route, driver
scripts/network/ ENet lobby (autoload), per-contestant sync, race event sync
scripts/ui/      HUD, custard splat overlay, main menu, lobby, pause menu
scripts/items/   coins, item boxes, item rules, traps, custard pie
scripts/fx/      particle bursts, trails and shock rings
scripts/audio/   synthesised sound effects and disco music
tools/           headless bot race and item tests (not exported)
```

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
