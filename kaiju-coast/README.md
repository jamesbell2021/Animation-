# Kaiju Coast 怪獣海岸

![Command view: the bay at night, kaiju wading in, the airship overhead](docs/command.jpg)

A neon vector tower defence game made in **Godot 4.3**. It's set on a Japanese bay under a blood
moon. Giant kaiju wade in from the volcano island of Oni-ga-shima. Build and upgrade guns along
the seawall and on the sea forts, and fit out the airship **Raijin-maru (雷神丸)**. At any time
you can climb into any gun, or the airship's nose gun, and fight in first person as a **gunner**
or a **rocketeer**.

Everything is a "vector solid", the look of *Rust & Iron*. Each kaiju, gun, building and airship
is a dark filled shape with glowing neon edges, bloomed by the renderer, under a CRT scanline pass.
The city has lit windows that switch on and off, setbacks, water tanks, AC units, antenna beacons,
vertical kanji blade signs, rooftop marquees, flickering ad screens and shop fronts. Kaiju knock it
all down.

<p>
<img src="docs/fps_gunner.jpg" width="49%" alt="First person on the machine gun, firing at an Onigami">
<img src="docs/fps_airship.jpg" width="49%" alt="The city from the airship's nose gun">
</p>

The soundtrack and every sound effect are synthesised in code. The music mixes taiko and
shime-daiko over a pumping four-on-the-floor kick, with shamisen bass, a pentatonic synth arp,
koto melodies and a shakuhachi lead, all in the Japanese *In* scale. It has four loops (title,
calm, battle and boss), rendered on a background thread the first time the game starts and
cached after that. Listen to [`docs/soundtrack-preview.mp3`](docs/soundtrack-preview.mp3) for the
title, battle and boss loops with some of the sound effects over the top.

## Play on Windows

1. Open the repository's **Actions** tab and select the latest **Kaiju Coast builds** run.
2. Download **kaiju-coast-windows** from its *Artifacts* section and unzip it.
3. Double-click `KaijuCoast.exe`. Windows SmartScreen may warn because the game isn't
   code-signed: choose **More info → Run anyway**.

Every push that changes `kaiju-coast/` builds a fresh Windows and Linux version. The workflow is
`.github/workflows/kaiju-coast.yml`. It runs the smoke test first and fails if the game is broken.

## Open it in Godot

1. Install Godot 4.3 (standard, not .NET).
2. In the Project Manager choose **Import** and pick `kaiju-coast/project.godot`.
3. Press **F5**. The first launch takes a few extra seconds while the music renders in the
   background.

To export it yourself, install the 4.3 export templates (Editor → Manage Export Templates), then
use Project → Export → **Windows Desktop**. From the command line:

```
godot --headless --path . --export-release "Windows Desktop" build/windows/KaijuCoast.exe
```

## How to play

* **Click a ring** on the shore or on a sea fort to build a gun there. Click a built gun to
  upgrade, repair, sell or man it.
* **Start the next wave** with Space or the red button. Calling a wave early earns a bonus.
* **Man a gun (F)** or **board the airship (Z)** to fight in first person. Your damage grows with
  the gun's level. Shots to the glowing eyes, the sea dragon's pearl and the Dai-Oni's chest core
  do **triple damage**.
* Kaiju that reach the shore start smashing the city. Hold all **15 waves** to win, then keep
  going in endless mode if you like.

| Command view | |
|---|---|
| Click | Select a ring, a gun or the airship |
| Drag, A/D, W/S, mouse wheel | Pan and zoom |
| 1–5 | Build on the selected ring |
| U · R · X | Upgrade · repair · sell the selected gun |
| B | Armory (gunner and rocketeer upgrades, rebuild the city) |
| Space · T · P · M | Next wave · game speed · pause · music |
| F11 or Alt+Enter | Fullscreen |

| First person | |
|---|---|
| Mouse, or arrow keys / right stick | Aim |
| Left click, Space or right trigger | Fire |
| Right click or left trigger | Zoom |
| Q, mouse wheel, or 1 and 2 | Switch between the machine gun and the rocket launcher |
| R | Reload rockets |
| Tab / E | Jump to the next gun |
| Esc / F | Back to the command view |

## Guns

| Gun | Targets | Notes |
|---|---|---|
| 大砲 Taiho Cannon | Ground | Fast shells. Gains barrels as it levels up. |
| 火箭 Hiya Rockets | Ground + air | Homing salvos with splash damage. |
| 雷神 Raijin Coil | Ground + air | Chain lightning that slows kaiju. Short range. |
| 刀 Katana Rail | Ground | Pierces every kaiju in a line and ignores armour. |
| 花火 Hanabi Flak | Air | Firework air-bursts for the tengu. |

The airship takes its own upgrades: a bomb bay, rocket pods and armour plating. Tengu hunt it.
If it's shot down it falls into the bay and comes back 30 seconds later.

## Kaiju

| Kaiju | |
|---|---|
| 鬼神 Onigami | The horned brute. Breathes a beam that burns down guns. |
| 蟹鮫 Kanizame | Crab-shark. Shrugs off half of all shell and bullet damage. |
| 竜神 Ryujin | Sea dragon. Fast, resists lightning, rears up when it lands. |
| 天狗 Tengu | Flying. Goes after the airship first, then the city. |
| 大鬼 Dai-Oni | The boss on every fifth wave, armed with a spiked kanabo club. |

## How it's built

All of the game is built in code from `scenes/main.tscn`, which holds a single node.

| Script | What it does |
|---|---|
| `game.gd` (autoload `Game`) | Gun, kaiju and upgrade stats, game state, economy and waves |
| `main.gd` | Builds the scene, runs the simulation step, command-view input and build actions |
| `world.gd` | Sky, sea, shore, seawall and lanterns, torii, volcano, Fuji, the city and its collapse, traffic |
| `kaiju.gd` | Jointed solid rigs posed every frame, hit spheres and weak points, kaiju AI |
| `turret.gd` · `zeppelin.gd` | The guns and the airship |
| `player.gd` · `camera_rig.gd` | First person, the view model, and the camera's three framings |
| `combat.gd` · `fx.gd` | Shots, hits and damage; sparks, blood, gore, fireworks, beams and floating text |
| `hud.gd` | All the 2D UI |
| `solid_builder.gd` · `line_builder.gd` · `mats.gd` | Vector-solid meshes and shared materials |
| `synth.gd` · `sfx.gd` · `music.gd` | The synthesiser, sound effects and soundtrack |

The renderer is **Compatibility** (OpenGL 3.3), so it runs on almost any Windows PC.

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn      # exit code 0 = all pass
godot --path . res://tests/showcase.tscn -- --out=/tmp/shots   # renders the screenshots above
godot --headless --path . res://tests/audio_preview.tscn -- --out=/tmp/audio   # writes the music loops as WAV
```

The smoke test plays real waves without rendering: it builds and upgrades guns, mans a gun
mid-wave, fights the wave 5 boss and checks the city can fall. Under `--headless`, Godot prints
`Parameter "m" is null … mesh_get_surface_count` many times. That's harmless noise from its
dummy renderer.

## Web prototype

`web/index.html` is the first version of the game: a single HTML page with its own canvas
wireframe renderer. It's kept for reference, and Godot ignores it.

## Credits

Design, code, art, music and sound: made for this repository, all generated in code.
Fonts: [Dela Gothic One](https://fonts.google.com/specimen/Dela+Gothic+One) and
[DotGothic16](https://fonts.google.com/specimen/DotGothic16), both under the SIL Open Font
License (`fonts/OFL-*.txt`).
