# Plan 3: phases H to L (after v0.1.0)

Status: **not started.** Run this only after plan 2 is finished and tagged v0.1.0.

Original text, unchanged:

```text
TASK
The repo contains the feature-complete v0.1.0 of Sea They Are Angry. Do the following five phases in order, each with a headless load check and a commit. Read docs/DECISIONS.md and git log first.
PHASE H — DESIGN DOCS INTO THE REPO
Create docs/DESIGN.md, docs/ENEMIES.md, docs/ARCHITECTURE.md, docs/BALANCING.md by reading the actual code and documenting what exists (not what was planned): every autoload and its signals, every scene class and its states, the full Balance table, the spawn schedule, the Anger rules, the asset and audio contracts. Where the code diverges from docs/NEXT_MILESTONE.md, say so. Keep each doc under 300 lines. Commit: Phase H: design docs from code.
PHASE I — GAME FEEL
All of this is code-only, no assets. Every item must be toggleable in Options → Accessibility (see Phase J).
Hit feedback: enemies flash white for 0.08 s on damage (swap material_override.albedo_color, restore via tween). Players flash red.
Boathook swing: 0.25 s arc rotation plus a short forward lunge of 0.3 m.
Screen shake: camera offset noise, 0.15 s on player hit, 0.4 s on Bloated burst within 6 m, 0.6 s on Crab slam, continuous low shake during Eel Coil. Max amplitude 0.25 m.
Hit stop: Engine.time_scale = 0.05 for 0.05 s on a killing blow (never during Eel).
Particles via GPUParticles3D with primitive quad meshes: burst (green spray), ink (cyan puff), fence splinters (brown), lamp ignite sparks (amber), flare trail, blood? — no, keep it bloodless: grey "water" spray on player hit.
Lamp: cone intensity pulses ±5 % at 2 Hz; sharper pulse when Guttering; beam makes a soft audio-side flag Events.beam_on_enemy for Phase F audio (squid_squeal).
Damage numbers: small Label3D floating up and fading, 0.6 s. Toggleable.
Dawn: surviving enemies dissolve (scale to 0.1 over 1 s) as they retreat into water.
Night number card: at DAY start, 2 s centred card "NIGHT N" with the Anger warning line underneath.
Commit: Phase I: game feel.
PHASE J — ACCESSIBILITY AND OPTIONS
Add to Options:
Screen shake (Off / Low / Full), hit stop (On/Off), damage numbers (On/Off), flashing lights reduce (replaces lamp flicker with a steady dim and disables red vignette pulse).
Colourblind-safe player colours: a second palette (amber, blue, white, green) selectable.
UI scale 100 / 125 / 150 %.
Full key and gamepad rebinding for all actions, per player index, persisted in user://settings.json. Reset-to-default button.
Text: all UI strings routed through a single autoload/strings.gd dictionary so localisation is possible later (English only now).
Commit: Phase J: accessibility, rebinding, strings.
PHASE K — PLAYTEST BUILD INSTRUMENTATION
autoload/telemetry.gd: appends one JSON line per event to user://telemetry.jsonl: run start/end (reason, night, anger, players), each night's summary (structures destroyed, enemies killed by type, fuel low events, Eel outcome, revives), each upgrade purchase, each dirty fuel use. Off by default; toggled by --telemetry command-line flag or Options → "Share anonymous play stats (local file only)". No network. Document the format in docs/TELEMETRY.md.
docs/PLAYTEST.md: a one-page script for running a playtest — setup, what to watch for (the six checks from the balancing doc), five questions to ask afterward, and where the telemetry file lives.
In-game F12 (debug and release): writes user://feedback.txt with the current night, anger, resources, upgrades and a timestamp, and shows "Snapshot saved" — so testers can mark a moment and tell you about it.
Commit: Phase K: telemetry, playtest script.
PHASE L — RELEASE MECHANICS
scripts/export_windows.sh and scripts/export_windows.ps1: run the Windows export, zip export/ as sea-they-are-angry-win64-vX.Y.Z.zip using the version in project.godot (application/config/version, add it, start at 0.2.0).
scripts/push_itch.sh: uses butler push to <user>/sea-they-are-angry:windows with the version. Document installing butler in README. Do not run it.
CREDITS.md: engine, fonts (Godot default for now), and a section listing every third-party asset with licence, to be filled as assets are added. LICENSE: code under MIT; assets reserved — state that clearly.
docs/ITCH_PAGE.md: draft itch.io page copy — one-line hook, three short paragraphs, feature bullets, controls, co-op note, "early access, feedback wanted" line, and a list of the 6 screenshots to take (specified by phase and situation, e.g. "Night, Eel Coil, focused beam on head").
Title screen shows version bottom-right.
Commit: Phase L: export scripts, itch page copy, credits, licence. Tag v0.2.0.
```
