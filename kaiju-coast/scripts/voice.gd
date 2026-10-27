class_name Voice
extends Node
## Japanese radio call-outs with subtitles. Lines are synthesised by VoiceSynth (shared with
## Neon Mega Tank) on a background thread when the game starts, then played on the Voice bus.

## key: [romaji, Japanese subtitle, English subtitle, pitch, priority]
const LINES := {
	"deploy": ["shu-tsu-ge-ki", "出撃！", "SORTIE!", 110.0, 2],
	"wave": ["te-ki-shu-u-ra-i", "敵襲来！", "ENEMY ATTACK!", 110.0, 2],
	"clear": ["ya-Q-ta", "やった！", "WAVE CLEAR!", 140.0, 2],
	"daioni": ["o-o-o-ni-da", "大鬼だ！", "IT'S THE DAI-ONI!", 100.0, 3],
	"orochi": ["o-ro-chi-da", "大蛇だ！", "IT'S OROCHI!", 100.0, 3],
	"land": ["jo-o-ri-ku", "上陸！", "LANDFALL!", 120.0, 1],
	"zep_down": ["tsu-i-ra-ku", "墜落！", "AIRSHIP DOWN!", 150.0, 2],
	"kill": ["ta-o-shi-ta", "倒した！", "KAIJU DOWN!", 140.0, 0],
	"boss_kill": ["ya-Q-ta-zo", "やったぞ！", "THE BOSS IS DOWN!", 120.0, 3],
	"weak": ["ja-ku-te-n", "弱点！", "WEAK POINT!", 145.0, 1],
	"sever": ["ku-bi-o-ki-Q-ta", "首を切った！", "HEAD SEVERED!", 130.0, 2],
	"gun_lost": ["ho-o-da-i-ga", "砲台が！", "GUN DESTROYED!", 150.0, 1],
	"city_low": ["ma-chi-ga-a-bu-na-i", "町が危ない！", "THE CITY IS IN DANGER!", 115.0, 2],
	"air": ["ku-u-ba-ku", "空爆！", "AIRSTRIKE!", 110.0, 2],
	"storm": ["ka-mi-na-ri", "雷！", "LIGHTNING STORM!", 110.0, 2],
	"flood": ["tsu-na-mi", "津波！", "FLOOD GATES OPEN!", 110.0, 2],
	"win": ["sho-o-ri", "勝利！", "VICTORY!", 110.0, 3],
	"lose": ["ma-chi-ga-o-chi-ta", "町が落ちた…", "THE CITY HAS FALLEN...", 95.0, 3],
}
const COOLDOWN := {"kill": 6.0, "weak": 5.0, "land": 8.0, "gun_lost": 6.0}

var streams: Dictionary = {}
var last_key: String = ""
var _player: AudioStreamPlayer
var _thread: Thread
var _until: float = 0.0      # Game.t when the current line ends
var _prio: int = -1
var _cool: Dictionary = {}


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Voice"
	_player.volume_db = 2.0
	add_child(_player)
	_thread = Thread.new()
	_thread.start(_render_all)


func _render_all() -> void:
	var out := {}
	for key: String in LINES:
		var l: Array = LINES[key]
		out[key] = VoiceSynth.say(l[0], l[3], true)
	call_deferred("_ready_streams", out)


func _ready_streams(out: Dictionary) -> void:
	streams = out


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func ready_all() -> bool:
	return streams.size() == LINES.size()


## Silence the radio and forget cooldowns (a new game).
func reset() -> void:
	_player.stop()
	_until = 0.0
	_prio = -1
	_cool.clear()
	if Game.hud != null:
		Game.hud.show_subtitle("", "", 0.01)


## Speak a line. It cuts off a line of the same or lower priority; while a more important line
## is playing it is dropped.
func say(key: String) -> void:
	if not LINES.has(key):
		return
	var l: Array = LINES[key]
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < float(_cool.get(key, 0.0)):
		return
	var prio: int = l[4]
	if now < _until and prio < _prio:
		return
	_cool[key] = now + float(COOLDOWN.get(key, 2.5))
	last_key = key
	_prio = prio
	var s: AudioStreamWAV = streams.get(key)
	var dur := 1.4
	if s != null:
		_player.stream = s
		_player.pitch_scale = randf_range(0.97, 1.03)
		_player.play()
		dur = s.get_length() + 0.3
	_until = now + dur
	if Game.hud != null:
		Game.hud.show_subtitle(l[1], l[2], dur + 0.8)
