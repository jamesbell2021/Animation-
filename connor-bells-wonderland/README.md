# Connor Bell's Wonderland

*Tower of Frustration at the Travelling Fair.* A Godot 4.3 obstacle race for up to
8 contestants: you, friends on the same Wi-Fi, and AI leprechauns. Six fairground
sections end at Connor's Crown on top of the Grand Finale Tower.

Everything (course, characters, HUD, menus, music and sound effects) is built in
code, so the project has no art or audio files.

## Run it

1. Install **Godot 4.3** (standard build, not .NET).
2. Project Manager → **Import** → pick this folder's `project.godot`.
3. Press **F5**. The main menu opens.

| Action | Keyboard | Phone |
|---|---|---|
| Move | WASD or arrow keys | Left half of the screen (joystick appears under your thumb) |
| Jump | Space | Right half of the screen |
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
scripts/player/  contestant, leprechaun model, stumbles, camera, touch controls, status effects
scripts/ai/      bot personalities, route, driver
scripts/network/ ENet lobby (autoload), per-contestant sync, race event sync
scripts/ui/      HUD, main menu, lobby, pause menu
scripts/items/   coins, plus the first Stage 7 item files (not used in races yet)
scripts/audio/   synthesised sound effects and organ music
tools/           headless bot race test (not exported)
```

## Bot race test

A headless race with 7 bots checks that the course can be completed:

```
godot --headless --path . --fixed-fps 60 -s res://tools/bot_race_test.gd -- diff=2
```

`diff=0` is Easy, `1` Medium, `2` Hard. It prints progress every 20 seconds and the
results. Typical runs: most Hard bots finish in 70–90 s; on Easy only a couple finish.

## Not done yet: Stage 7 "Fairground Mayhem" items

`item_kinds.gd`, `trap_device.gd` and `status_effects.gd` are in place, but items do not
appear in races yet. Still to write: `item_box.gd`, `item_holder.gd`, `item_manager.gd`,
`confetti_burst.gd`, `pie_projectile.gd`, the Shrink Potion trap, a `use_item` input and
button, network sync for items, HUD item slot, and bots that use items.
