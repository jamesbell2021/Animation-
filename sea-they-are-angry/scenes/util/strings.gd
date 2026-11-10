class_name Strings
extends RefCounted
## The words the menus and the end screens say, in one table, so the game can be
## translated later: `Strings.t("title.new_run")`, or with values filled in,
## `Strings.t("title.continue", [night])` (printf style, "%d"). English only for now.
## The title, pause and settings menus, the game-over screen and the new accessibility
## options read from here; the long game text (the story, hints, How to Play) is still
## in the scripts that show it, and moves here as it is translated.
##
## To add a language, add a table like EN under a new code and set LANGUAGE.

const LANGUAGE := "en"

const EN := {
	# title
	"title.name": "Sea They\nAre Angry",
	"title.tagline": "Keep the light burning.",
	"title.continue": "Continue  (night %d)",
	"title.new_run": "New Run",
	"title.rock": "Start on the Rock",
	"title.rock_note": "Skip Kirkhaven: begin on the rock with all seven saved.",
	"title.continue_harbour": "Continue  (Kirkhaven, night %d)",
	"title.lan": "Play on the LAN",
	"title.how": "How to Play",
	"title.settings": "Settings",
	"title.credits": "Credits",
	"title.quit": "Quit",
	# pause
	"pause.title": "Paused",
	"pause.resume": "Resume",
	"pause.quit": "Quit to Title",
	"pause.note": "Quitting returns you to the start of this day.",
	# game over
	"over.title": "The light is out.",
	"over.again": "Try again",
	"over.title_screen": "Back to the title",
	# settings
	"settings.title": "Settings",
	"settings.sound": "Sound",
	"settings.display": "Display",
	"settings.access": "Comfort and access",
	"settings.screen": "Screen",
	"settings.fullscreen": "Full screen",
	"settings.window": "In a window",
	"settings.window_size": "Window size",
	"settings.graphics": "Graphics",
	"settings.render_scale": "Render scale",
	"settings.render_note": "Below 100% the world is drawn smaller and sharpened up: faster, a little softer.",
	"settings.shake": "Screen shake",
	"settings.hitstop": "Pause on a heavy blow",
	"settings.numbers": "Damage numbers",
	"settings.calm": "Reduce flashing",
	"settings.calm_note": "Steady lamp, no pulsing red edge, a soft lightning glow, no hit flashes.",
	"settings.palette": "Keeper colours",
	"settings.palette_note": "Takes effect from the next run.",
	"settings.ui_scale": "Interface size",
	"settings.hud_mode": "On-screen display",
	"settings.hud_note": "Full: everything. Slim: the clock, the light and your health. Off: only prompts, messages and warnings. In play its key (H, unless changed below) steps through them; held, it brings everything back.",
	"settings.telemetry": "Keep a local play log",
	"settings.telemetry_note": "Writes one line per event of a run to a file on this computer (telemetry.jsonl). Nothing is sent anywhere.",
	"settings.on": "On",
	"settings.off": "Off",
	"settings.keys": "Keeper one's keys",
	"settings.keys_note": "Pick a control, then press the key or mouse button for it (Esc to leave it). Two controls can't share a key: they swap. Gamepads keep their own layout: A use, X or RT swing, Y lamp, B beam, LT flare, LB dirty fuel, RB sprint, the right stick aims.",
	"settings.keys_reset": "Put the keys back as they were",
	"settings.back": "Back",
}

static func t(key: String, args: Array = []) -> String:
	var table: Dictionary = EN
	var s: String = table.get(key, key)
	return (s % args) if not args.is_empty() else s
