# Tripod Attack!

![The Heat-Ray sweeps the sandbags](docs/heat-ray.jpg)

A Vectrex-style vector arcade game after H. G. Wells's *The War of the Worlds*. You are the
artilleryman: one man, one rocket launcher, a wall of sandbags, and the Martian fighting-machines
striding in from the right. Shoot their legs out and watch them come down. When you hear the cry,
duck. Get the people to shelter. Then take Europe back, one sector at a time.

Everything on screen is stroked lines on a black phosphor tube, with persistence, glow, scanlines
and showers of sparks. All sound is synthesised in code in the manner of an early-80s arcade board.
The game is a single HTML page with no build step, no dependencies and no asset files.

Lines of text in the game are quoted from the 1898 novel, which is in the public domain.

## Play

Open `tripod-attack/index.html` in any modern browser, on a desktop or a phone. If your browser
refuses to run scripts from a local file, serve the folder instead (for example
`npx http-server tripod-attack` and open the printed address).

Sound starts on the first click, tap or key press, because browsers require a gesture.

## Controls

| Input | Action |
|---|---|
| **Drag back and release** (mouse or touch) | Aim and fire, like a slingshot: drag away from the target, the further the harder. A dotted arc shows the shot. |
| **Tap / click** | Fire with the current aim |
| **Hold the left zone** (touch) or **right mouse button** | Duck behind the sandbags |
| **Space** / Shift / X | Duck (keyboard) |
| **Arrow keys** or WASD | Up/down aims the launcher, left/right sets the power |
| **Enter** / Z / F | Fire (keyboard) |
| **P** or Esc | Pause |
| **M** | Mute |

## How to fight a fighting-machine

* **Shoot the legs.** The hood is armour: rockets glance off it in sparks for a few points. Each
  leg takes a number of hits that grows through the campaign. A damaged leg sparks and flickers.
* **Break a leg and the machine falls.** The wreck is simulated with real physics (a Verlet
  rope-and-stick body with the broken leg severed) so every collapse is different. The hood
  hitting the ground throws sparks, debris and smoke, and anything under it is crushed, you
  included. The last machine of a wave falls in slow motion.
* **Listen for the cry.** Before the Heat-Ray, a machine stops, its lens glows red and it wails
  *Ulla*. That siren is your warning. The bright red beam then sweeps the whole field from the
  machine to the shelter. Standing when it reaches your sandbags costs a life. Ducked, it passes
  over you for a dodge bonus. Then get up and shoot again.
* **Protect the people.** Small figures run from the ruins towards the SHELTER door on the left.
  Each one through the door is worth 200 points (400 for a parent carrying a child). The beam burns
  anyone in the open, your own rocket blasts kill, and a falling tripod crushes. When the cry
  sounds, people near a rubble pile hide behind it until the beam has passed.
* **Hold the line.** A machine that reaches the sandbags stamps the position flat, costs a life and
  is driven back a few paces. Four lives to start, one more for each sector cleared (up to six).

The buildings behind you burn and fall when the beam catches them, so a long fight leaves the city
in ruins.

## The campaign: take Europe back

![The map of the Tripod advance](docs/map.jpg)

The map shows the Martian advance across the British Isles and Europe as a chain of ten sectors.
Red paths with marching tripods are theirs; green sectors are yours again. Each sector is three
waves, and every sector raises the machines' speed, armour, and how often they fire. The third wave
from Edinburgh onwards brings a larger machine. Each city has its own vector skyline:

| # | Sector | On the skyline |
|---|---|---|
| 1 | Belfast | Samson and Goliath, the City Hall, the Albert Clock |
| 2 | Edinburgh | the Castle on its rock, the Scott Monument, St Giles' |
| 3 | Liverpool | the Liver Building and its birds, the Anglican Cathedral, Radio City |
| 4 | London | Tower Bridge, St Paul's, Big Ben, the London Eye (turning) |
| 5 | Paris | the Arc de Triomphe, the Eiffel Tower, Notre-Dame |
| 6 | Amsterdam | windmills (turning), canal houses, the Westerkerk |
| 7 | Berlin | the Brandenburg Gate, the Fernsehturm, the Reichstag |
| 8 | Vienna | the Stephansdom, the Riesenrad (turning), the Karlskirche |
| 9 | Rome | the Colosseum, St Peter's, umbrella pines |
| 10 | Athens | the Acropolis and the Parthenon, Lycabettus |

Lose all your lives and the Martians retake the last sector you liberated; the line on the map
falls back and you fight for it again. Progress is saved in the browser, so you can continue a
campaign later. Clear Athens and Europe is free.

**Endless mode** unlocks when the campaign is complete. It is set in Belfast, and the waves never
stop: more machines, tougher legs, shorter warnings, bigger ones every other wave, an extra life
every third wave. Campaign and endless high scores are kept separately.

![A machine comes down](docs/collapse.jpg)

## Sound

Every sound is built from square, saw and noise voices through a cabinet echo and a compressor.
Listen to [`docs/audio-preview.mp3`](docs/audio-preview.mp3): interface blips, the rocket launch
and explosion, rockets ringing off a leg and glancing off the hood, footsteps, the siren cry
followed by the Heat-Ray, screams and burning, a leg breaking and the collapse, a rescue, the
wave fanfare, being hit, the sandbags stamped flat, the wave alarm, four bars of the battle theme,
and the sector-cleared, game-over and victory jingles.

The siren is four detuned saw and square oscillators with vibrato, driven through a wave-shaper and
a band-pass filter that sweeps up and back down, over a sub-bass drone. The Heat-Ray is filtered
noise under a high resonant whine. Music is a sixteen-step sequencer with bass, lead, kick, snare
and hat patterns; there are themes for the title, the map and the battle.

## Files

| File | What it is |
|---|---|
| `index.html` | the page and the script tags |
| `js/game.js` | the game: state machine, player, civilians, fighting-machines (procedural gait with two-bone IK, Heat-Ray, collapse), rockets, effects, screens, HUD, input, CRT compositing |
| `js/physics.js` | the Verlet particle/stick world used for the collapses |
| `js/audio.js` | the synthesiser, sound effects and music sequencer |
| `js/landmarks.js` | the ten city skylines as polylines, plus ruined filler buildings |
| `js/map.js` | the Europe coastline polylines, the ten sectors and the map projection |
| `js/vecfont.js` | the stroke font every letter and digit is drawn with |
| `js/wells.js` | the quotations |
| `tools/smoke-test.js` | drives the whole game headlessly in Chromium with Playwright and screenshots every screen; checks that rockets break legs, that the beam kills a standing player and spares a ducked one, and runs a four-minute soak |
| `tools/render-audio-preview.js` | renders the sound effects and music offline to a WAV and reports loudness per half second |

Rendering is a 1024 x 576 vector scene drawn to an offscreen canvas, then composited onto the
display with a decaying persistence buffer, a blurred quarter-resolution glow pass, scanlines and
a vignette. The page scales to any window and works on phones (a dashed box marks the duck zone
when touch is used).

![On a phone-sized screen](docs/phone.jpg)
