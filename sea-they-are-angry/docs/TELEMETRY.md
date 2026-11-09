# The local play log

For playtests. **Off unless asked for**, and it never leaves the machine: a file is written in the game's user folder and nothing else. Turn it on in Settings, Comfort and access, "Keep a local play log", or start the game with `--telemetry`.

## Where it is

The game's user folder (Godot's `user://`):

- Linux: `~/.local/share/godot/app_userdata/Sea They Are Angry/`
- Windows: `%APPDATA%\Godot\app_userdata\Sea They Are Angry\`
- macOS: `~/Library/Application Support/Godot/app_userdata/Sea They Are Angry/`

Files: `telemetry.jsonl` (the log), `feedback.txt` (F12 snapshots), `settings.cfg`, `run.json` (the save).

## The format

One JSON object per line, appended as things happen. Every line has `t` (the date and time, UTC, ISO 8601) and `event`.

| `event` | When | Fields |
|---|---|---|
| `run_start` | a run begins or is continued | `night`, `sea` (Calm sea / Angry sea / Raging sea), `people`, `keepers`, `version` |
| `night` | at each dawn | `night`, `anger`, `people`, `killed` (count by creature type), `structures_lost`, `lamp_gutters` (times the lamp began to gutter), `lamp_fuel`, `store` (what's in the store), `weather` |
| `upgrade` | an upgrade is bought at the cottage | `path` (lighthouse, defences, garden), `level`, `night` |
| `dirty_fuel` | someone starts to pour dirty fuel in | `night`, `phase` |
| `snapshot` | F12 is pressed | `night`, `phase` |
| `run_end` | the run ends | `reason`, `night`, `anger`, `seconds` (real time since the run began) |

Example:

```
{"t":"2026-11-09T14:02:11","event":"run_start","night":1,"sea":"Angry sea","people":1,"keepers":3,"version":"0.1.4"}
{"t":"2026-11-09T14:06:42","event":"night","night":1,"anger":0,"people":1,"killed":{"bloated":7},"structures_lost":0,"lamp_gutters":0,"lamp_fuel":44.2,"store":{"driftwood":9,"scrap":2,"seaweed":3,"bio":2},"weather":"Clear"}
{"t":"2026-11-09T14:31:07","event":"run_end","reason":"The lamp went dark.","night":7,"anger":6,"seconds":1496}
```

## Reading it

Any tool that reads JSON lines will do. A few lines of Python give the night each run ended on:

```
import json
for line in open("telemetry.jsonl"):
    e = json.loads(line)
    if e["event"] == "run_end":
        print(e["night"], e["reason"])
```

`docs/BALANCING.md` lists the six checks this is for.

## F12

Always on, in release builds too. Press it at any moment: the game appends the night, the phase, the sea's anger, the store, the upgrades and the time to `feedback.txt`, and says "Snapshot saved". Testers use it to mark the moment something felt wrong, then say what they were doing.
