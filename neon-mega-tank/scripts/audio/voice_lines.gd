class_name VoiceLines
extends RefCounted
## Japanese lines spoken by the synthesised electronic voices.
## Each entry: [romaji for VoiceSynth, Japanese subtitle, romanised subtitle].

const SOLDIER_DEATH := [
	["ya-ra-re-ta", "やられた！", "yarareta!"],
	["i-ta-i", "いたい！", "itai!"],
	["u-wa-a-a", "うわあああ！", "uwaaa!"],
	["shi-ma-Q-ta", "しまった！", "shimatta!"],
	["ta-su-ke-te", "たすけて！", "tasukete!"],
	["mo-o-da-me-da", "もうダメだ！", "mou dame da!"],
	["na-n-de", "なんで！？", "nande!?"],
	["o-ka-a-sa-n", "おかあさーん！", "okaasan!"],
	["ba-ka-na", "ばかな！", "baka na!"],
	["ku-so", "くそっ！", "kuso!"],
	["sa-ra-ba", "さらば…", "saraba..."],
]

const TANK_DEATH := [
	["se-n-sha-ga", "戦車が！", "sensha ga!"],
	["da-Q-shu-tsu", "脱出！", "dasshutsu!"],
]

const ANNOUNCER := {
	"deploy": ["shu-tsu-ge-ki", "出撃！", "SHUTSUGEKI!  -  SORTIE!"],
	"wave": ["te-ki-shu-u-ra-i", "敵襲来！", "TEKI SHUURAI!  -  ENEMY ATTACK!"],
	"reinforce": ["ku-ru-zo", "来るぞ！", "KURU ZO!  -  MORE INCOMING!"],
	"clear": ["ya-Q-ta", "やった！", "YATTA!  -  WAVE CLEAR!"],
	"gameover": ["ge-e-mu-o-o-ba-a", "ゲームオーバー", "GAME OVER"],
	"record": ["shi-n-ki-ro-ku", "新記録！", "SHIN KIROKU!  -  NEW RECORD!"],
}


static func all_romaji() -> Array[String]:
	var out: Array[String] = []
	for line in SOLDIER_DEATH + TANK_DEATH:
		out.append(line[0])
	for key in ANNOUNCER:
		out.append(ANNOUNCER[key][0])
	return out
