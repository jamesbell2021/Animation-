# Neon Mega Tank

![Four crew members on the mega tank deck](screenshot.jpg)

Couch co-op for 1–4 players, made in **Godot 4.3**. The whole crew shares one giant neon tank.
Like *Lovers in a Dangerous Spacetime*, every crew member runs around the open deck and jumps
between stations. You fight waves of rifle infantry, RPG troopers and enemy tanks in a neon
city where every building, barrier, crate and tree can be destroyed.

## Run it

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, no .NET needed).
2. In the Project Manager, choose **Import** and pick `neon-mega-tank/project.godot`.
3. Press **F5** to play.

The game uses the Forward+ renderer, so the glow comes out right on any recent desktop GPU.

## How to play

* **Join:** press ACTION on any free device (two keyboard halves plus up to four gamepads).
  Players can also drop in mid-game.
* **Deploy:** board DRIVE and roll the tank through the pink **DEPLOY** gate. You can practise
  shooting buildings before you deploy.
* **Board or leave a station:** stand on a glowing pad and press INTERACT.

| Station | Stick | ACTION |
|---|---|---|
| **DRIVE** | Tank turns to face the stick, then drives. Point it backwards to reverse. | – |
| **CANNON** | Aims the twin-barrel turret. The turret holds its aim while the tank turns. | Fire explosive shells that blow apart terrain |
| **MG** | Aims the machine gun | Hold to fire. Overheats. Can shoot RPG rockets out of the air |
| **REPAIR** | – | Hold to repair the hull |

**Breaches:** heavy hits punch burning holes into the deck. Each breach drains the hull, and a
breach next to a station **jams** it. Walk to the breach and hold ACTION to patch it.

**Ramming:** the tank crushes infantry, barriers, crates and trees, and slowly bulldozes
buildings.

**Destruction:** buildings are stacks of cubes. Knock out a lower cube and everything above
it collapses.

### Controls

| Device | Move | Board/leave (INTERACT) | ACTION |
|---|---|---|---|
| Keyboard 1 | WASD | E | Space |
| Keyboard 2 | Arrow keys | Shift or `/` | Enter |
| Gamepad | Left stick / D-pad | B, X or Y | A, RB or RT |

F1 toggles the CRT filter, F11 toggles fullscreen, and ESC quits from the lobby or returns to
the lobby from a game.

## Project layout

```
scenes/main.tscn          single entry scene; everything else is built in code
scripts/game.gd           autoload "G": constants, neon mesh helpers, explosions/FX, sound
scripts/main.gd           game flow: joining, lobby gate, waves, camera, game over
scripts/player_input.gd   per-device input (shared keyboard + gamepads, no InputMap)
scripts/sfx_bank.gd       synthesises all sound effects at startup (no audio files)
scripts/tank/             mega tank + stations, crew members, deck breaches
scripts/enemies/          enemy base, soldiers (rifle / RPG), enemy tanks
scripts/world/            procedural city and destructible blocks
scripts/combat/           projectiles (shells, bullets, rockets)
scripts/ui/hud.gd         terminal-style HUD, threat arrows, CRT overlay
shaders/                  neon wireframe, ground grid, FX rings, scorch marks, CRT
```

### The neon look

Every object is a `BoxMesh` with `shaders/neon_edge.gdshader`. The shader draws the face edges
as glowing lines of constant pixel width over a near-black fill, and the glow comes from
`WorldEnvironment`. Colours are set per object with instance uniforms, so the whole city shares
one material. Buildings between the camera and the tank turn into pure wireframe so the tank
never disappears behind them.

### Tuning

Most balance numbers are constants at the top of each script. Examples are `MegaTank.MAX_HP`,
`CANNON_RELOAD`, `REPAIR_RATE` and `BREACH_DRAIN`. Wave size is set in `Main._start_wave()`,
and projectile damage in `Projectile.KINDS`.
