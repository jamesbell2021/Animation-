# Kaiju Coast 怪獣海岸

A neon vector tower defence game set on a Japanese bay under a blood moon. Giant kaiju wade in
from the volcano island of Oni-ga-shima. Build and upgrade guns along the seawall and on the
sea forts, and fit out the airship **Raijin-maru (雷神丸)**. At any time you can climb into any
gun, or the airship's nose gun, and fire it yourself in first person as a **gunner** or a
**rocketeer**.

Open `index.html` in a browser to play. It is a single self-contained file with no build step.
Everything is generated in code: the wireframe 3D renderer, every model, the sound effects and
the soundtrack, which mixes taiko, shime-daiko, shamisen bass, koto and shakuhachi with a
side-chained synth arp in the Japanese *In* scale. The only outside request is for the two
Google Fonts. Without them, the game falls back to the system's Japanese fonts.

## How to play

* **Click a ring** on the shore or on a sea fort to build a gun there. Click a built gun to
  upgrade, repair, sell or man it.
* **Start the next wave** with Space or the red button. Calling a wave early earns a bonus.
* **Man a gun (F)** or **board the airship (Z)** to fight in first person. Your gun does more
  damage the higher its level. Shots to glowing eyes, the dragon's pearl and the Dai-Oni's
  chest core do **triple damage**.
* Kaiju that reach the shore start smashing the city. Hold all **15 waves** to win, then keep
  going in endless mode if you like.

| Command view | |
|---|---|
| Click / tap | Select a ring, gun or the airship |
| Drag, A/D, mouse wheel, pinch | Pan and zoom |
| 1–5 | Build on the selected ring |
| U · R · X | Upgrade · repair · sell the selected gun |
| B | Armory (gunner and rocketeer upgrades, rebuild the city) |
| Space · T · P · M | Next wave · game speed · pause · music |

| First person | |
|---|---|
| Mouse (pointer lock) or touch-drag | Aim |
| Left click / FIRE / Space | Fire |
| Right click | Zoom |
| Q, or 1 and 2 | Switch between the heavy machine gun and the rocket launcher |
| R | Reload rockets |
| Tab / E | Jump to the next gun |
| Esc / F | Back to the command view |

If the browser blocks pointer lock, the crosshair follows the mouse instead. Pushing it
towards the edge of the screen turns the gun.

## Guns

| Gun | Targets | Notes |
|---|---|---|
| 大砲 Taiho Cannon | Ground | Fast shells. Gains barrels as it levels up. |
| 火箭 Hiya Rockets | Ground + air | Homing salvos with splash damage. |
| 雷神 Raijin Coil | Ground + air | Chain lightning that slows kaiju. Short range. |
| 刀 Katana Rail | Ground | Pierces every kaiju in a line and ignores armour. |
| 花火 Hanabi Flak | Air | Firework air-bursts for the tengu. |

The airship takes its own upgrades: a bomb bay, rocket pods and armour plating. Tengu hunt
it, and if it's shot down it comes back after 30 seconds.

## Kaiju

| Kaiju | |
|---|---|
| 鬼神 Onigami | The horned brute. Breathes a beam that burns down guns. |
| 蟹鮫 Kanizame | Crab-shark. Shrugs off half of all shell and bullet damage. |
| 竜神 Ryujin | Sea dragon. Fast, resists lightning, rears up when it lands. |
| 天狗 Tengu | Flying. Goes after the airship first, then the city. |
| 大鬼 Dai-Oni | The boss on every fifth wave, armed with a spiked kanabo club. |
