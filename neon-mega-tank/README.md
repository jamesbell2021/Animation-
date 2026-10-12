# Neon Mega Tank

![Four crew members on the mega tank deck](docs/screenshot.jpg)

Couch co-op for 1–4 players, made in **Godot 4.3**. The whole crew shares one giant neon tank.
Like *Lovers in a Dangerous Spacetime*, every crew member runs around the open deck and jumps
between stations. It's an endless survival game: how long can you last against escalating waves
of rifle infantry, RPG troopers and enemy tanks? Each run takes place in a newly generated neon
city where every building, barrier, crate and tree can be destroyed.

There's no one to play with? **AI crew** members fill every empty seat, and a friend who joins
takes over a bot's body on the spot.

The game has an anime-style **chiptune soundtrack**. Defeated soldiers shout in Japanese in
**robotic electronic voices**, with manga-style subtitles. All music and voices are synthesised
in code, so the project ships no audio files. Listen to
[`docs/audio-preview.mp3`](docs/audio-preview.mp3) for the lobby theme, the battle theme, the
game-over sting and every voice line.

## Run it

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build, no .NET needed).
2. In the Project Manager, choose **Import** and pick `neon-mega-tank/project.godot`.
3. Press **F5** to play.

The game uses the Forward+ renderer, so the glow comes out right on any recent desktop GPU.

## How to play

* **Join:** press ACTION on any free device (two keyboard halves plus up to four gamepads).
  Players can also drop in mid-game.
* **AI crew:** once one player has joined, bots take the empty seats. In the lobby they man the
  guns and leave DRIVE to you. In battle they drive, aim, shoot down rockets, patch breaches and
  repair. To take a bot's station, stand on it and press INTERACT. F2 or the gamepad BACK button
  turns the AI crew on or off.
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

**Survival:** the clock runs from deployment until the tank dies. Each wave brings more
infantry, more RPG troopers, more tanks and, from wave 7, heavy tanks that fire three-shell
salvos. Enemy health and damage also grow over time. Clearing a wave patches the hull by 40. If
a wave drags on, reinforcements arrive anyway. Your best time, wave and score are saved to
`user://neon_mega_tank.cfg`. In testing, three AI crew with an idle fourth player lasted about
2½–3½ minutes, so that's the time to beat.

### Controls

| Device | Move | Board/leave (INTERACT) | ACTION |
|---|---|---|---|
| Keyboard 1 | WASD | E | Space |
| Keyboard 2 | Arrow keys | Shift or `/` | Enter |
| Gamepad | Left stick / D-pad | B, X or Y | A, RB or RT |

F1 toggles the CRT filter, F2 or gamepad BACK toggles the AI crew, M toggles music, F11
toggles fullscreen, and ESC quits from the lobby or returns to the lobby from a game.

## Project layout

```
scenes/main.tscn          single entry scene; everything else is built in code
scripts/game.gd           autoload "G": constants, neon mesh helpers, explosions/FX, sound
scripts/main.gd           game flow: joining, lobby gate, waves, camera, game over
scripts/player_input.gd   per-device input (shared keyboard + gamepads, no InputMap)
scripts/sfx_bank.gd       synthesises all sound effects at startup (no audio files)
scripts/audio/            chiptune composer, Japanese formant voice synth, voice lines
scripts/tank/             mega tank + stations, crew members, AI crew (bot_input.gd), breaches
scripts/enemies/          enemy base, soldiers (rifle / RPG), enemy tanks
scripts/world/            procedural city and destructible blocks
scripts/combat/           projectiles (shells, bullets, rockets)
scripts/ui/hud.gd         terminal-style HUD, threat arrows, CRT overlay
shaders/                  neon wireframe, ground grid, FX rings, scorch marks, CRT
fonts/                    DotGothic16 pixel font for the Japanese text (SIL OFL, see OFL.txt)
docs/                     screenshot and audio preview (ignored by Godot)
```

### Music and voices

`Chiptune` composes each song from a fixed seed and renders it once into a looping
`AudioStreamWAV`. It plays a pulse-wave lead with vibrato, 16th-note arpeggios, a triangle bass
and noise drums.

* **Battle theme:** built on the J-pop "royal road" chord progression (IV–V–iii–vi), plus the
  "Komuro" progression (vi–IV–V–I), at 160 BPM.
* **Lobby theme:** koto-style plucks in the Japanese *In* scale over a half-step bass.

`VoiceSynth` is a small formant speech synthesiser. Japanese works well for this because it has
only five vowels and simple consonant-plus-vowel syllables. A bit-crusher and ring modulator
then turn the speech into an electronic voice. The lines are in `scripts/audio/voice_lines.gd`:
やられた！ (I'm hit!), たすけて！ (help me!), おかあさーん！ (mum!), 脱出！ (bail out!), and more.
An announcer calls 出撃！ (sortie!) at deployment and 敵襲来！ (enemy attack!) at each new wave.
All audio is generated on a worker thread at startup, which takes about 3 seconds.

The project folder has its own `.gitattributes` that keeps its font, images and audio out of
Git LFS, so a plain clone or GitHub ZIP download runs as-is.

### The neon look

Every object is a `BoxMesh` with `shaders/neon_edge.gdshader`. The shader draws the face edges
as glowing lines of constant pixel width over a near-black fill, and the glow comes from
`WorldEnvironment`. Colours are set per object with instance uniforms, so the whole city shares
one material. Buildings between the camera and the tank turn into pure wireframe so the tank
never disappears behind them.

### Tuning

Most balance numbers are constants at the top of each script. Examples are `MegaTank.MAX_HP`,
`CANNON_RELOAD`, `REPAIR_RATE` and `BREACH_DRAIN`. Wave size and difficulty growth are set in
`Main._start_wave()`, projectile damage in `Projectile.KINDS`, and AI crew priorities in
`Main._assign_bots()`.
