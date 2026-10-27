class_name Tutorial
extends Node
## The guided first wave: a short run of hints that each wait for you to do the thing (or move on
## by themselves after a while). Shown the first time you play; switch it back on in Settings.

const STEPS: Array[Dictionary] = [
	{"text": "Kaiju are coming. Click the glowing ring on the seawall to pick a spot for a gun.", "pad": 3},
	{"text": "Build a TAIHO CANNON (砲): press 1 or click it in the panel."},
	{"text": "Guns go up to level 4, and at level 3 you choose one of two paths. When you're ready, press NEXT WAVE (Space)."},
	{"text": "Kaiju wade in from the volcano. Press F to climb into your gun and fight in first person.", "wait": 25.0},
	{"text": "Aim with the mouse and click to fire. The glowing eyes take triple damage: shoot them out. Q swaps to rockets.", "wait": 14.0},
	{"text": "Esc takes you back to the command view. Special attacks are on 7, 8 and 9. Try the AIRSTRIKE (7).", "wait": 22.0},
	{"text": "That's the job. Earn yen from kills, build and upgrade guns, and fit out the airship. Good luck.", "wait": 8.0},
]

var active: bool = false
var step: int = 0
var _t: float = 0.0


func start() -> void:
	active = true
	step = 0
	_t = 0.0
	Game.hud.show_tutorial(STEPS[0]["text"])


func skip() -> void:
	finish()


func finish() -> void:
	active = false
	Settings.set_v("tutorial", false)
	Game.hud.show_tutorial("")


func highlight_pad() -> int:
	if not active:
		return -1
	return int(STEPS[step].get("pad", -1))


func _done() -> bool:
	match step:
		0:
			return Game.sel is Pad
		1:
			return not Game.turrets.is_empty()
		2:
			return Game.phase == "wave"
		3:
			return Game.player.active
		4:
			return false
		5:
			return float(Game.abilities.cd["air"]) > 0.0
	return false


func _process(delta: float) -> void:
	if not active:
		return
	if Game.state != Game.State.PLAY:
		active = false
		Game.hud.show_tutorial("")
		return
	if Game.paused:
		return
	_t += delta
	var wait: float = float(STEPS[step].get("wait", 0.0))
	if _done() or (wait > 0.0 and _t > wait):
		step += 1
		_t = 0.0
		if step >= STEPS.size():
			finish()
			return
		Game.hud.show_tutorial(STEPS[step]["text"])
		Game.sfx.play("click")
