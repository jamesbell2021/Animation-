class_name StringsJa
extends RefCounted
## Japanese text for every string the player sees, keyed by the English text (Godot's msgid
## convention). G loads it into the TranslationServer; switch with the menu's language button.
## Format strings keep their %s / %d placeholders in the same order as the English.

const TEXT := {
	# Title menu
	"▶  PLAY": "▶  プレイ",
	"this device + controllers, AI crew fills empty seats": "この端末とコントローラーで（空席はAIクルー）",
	"HOST LAN GAME": "LANゲームを開く",
	"friends join from their own phones on this Wi-Fi": "同じWi-Fiの友だちが自分のスマホで参加",
	"JOIN LAN GAME": "LANゲームに参加",
	"find a game hosted on this Wi-Fi": "同じWi-Fiのゲームを探す",
	"CREDITS": "クレジット",
	"QUIT": "終了",
	"LANGUAGE": "言語",
	"searching for games on your Wi-Fi ...": "Wi-Fi内のゲームを探しています…",
	"games found on your Wi-Fi:": "見つかったゲーム：",
	"JOIN  %s": "参加  %s",
	"%s  -  %d player(s) aboard": "%s  -  乗員 %d 人",
	"host IP, e.g. 192.168.1.20": "ホストのIP（例：192.168.1.20）",
	"CONNECT": "接続",
	"BACK": "戻る",
	"that is not an IP address": "IPアドレスではありません",
	"connecting to %s ...": "%s に接続中…",
	"could not open port %d - is another game hosting here?": "ポート %d を開けません。別のゲームがホスト中では？",
	"connection failed": "接続に失敗しました",
	"could not reach %s": "%s に接続できません",
	"the host left the game": "ホストがゲームを終了しました",

	# Crew roster
	"BLUE": "青",
	"GREEN": "緑",
	"PINK": "ピンク",
	"YELLOW": "黄",
	"---- press ACTION to join": "---- ACTIONで参加",
	"DRIVE": "操縦",
	"CANNON": "主砲",
	"MG": "機銃",
	"REPAIR": "修理",
	"JAMMED": "故障",
	"%s [JAMMED]": "%s［故障］",
	"BAILED OUT": "脱出",
	"PATCHING BREACH": "損傷を修理中",
	"ON DECK": "甲板",
	"AI CREW": "AIクルー",
	"LAN PHONE": "LANスマホ",
	"TOUCH": "タッチ",
	"KEYS WASD": "キー WASD",
	"KEYS ARROWS": "キー 矢印",
	"PAD %d": "パッド %d",
	" YOU": " あなた",

	# Gauges and counters
	"HULL   %s %3d": "装甲   %s %3d",
	"READY ": "準備完了 ",
	"OVERHEAT ": "過熱 ",
	"HEAT ": "熱 ",
	"CANNON %s   MG %s   BREACHES %d": "主砲 %s   機銃 %s   損傷 %d",
	"AI CREW %s   BEST %s (WAVE %d)": "AIクルー %s   ベスト %s（ウェーブ %d）",
	"ON": "オン",
	"OFF": "オフ",
	"TIME %s   WAVE %02d   HOSTILES %02d   SCORE %06d": "タイム %s   ウェーブ %02d   敵 %02d   スコア %06d",
	"鬼戦車 ONI SENSHA  %s": "鬼戦車  %s",

	# Lobby
	"press ACTION on any keyboard half or gamepad to join": "キーボードかゲームパッドのACTIONを押して参加",
	"friends: press ACTION to join (up to 4)": "友だちはACTIONで参加（4人まで）",
	"HOSTING - friends tap JOIN LAN GAME on their phones": "ホスト中 - 友だちはスマホで「LANゲームに参加」をタップ",
	"or enter  %s": "または  %s  を入力",
	"connected to the host's tank over the LAN": "LANでホストの戦車に接続中",
	"AI crew mans the empty stations": "空いた持ち場はAIクルーが担当",
	"board DRIVE and roll the tank through the DEPLOY gate": "「操縦」に乗り、戦車で「出撃」ゲートをくぐれ",
	"DEPLOY": "出撃",
	"KEYBOARD 1   WASD move   E board/leave station   SPACE action":
		"キーボード1   WASD 移動   E 乗り降り   SPACE アクション",
	"KEYBOARD 2   ARROWS move   R-SHIFT or / board/leave   ENTER action":
		"キーボード2   矢印 移動   右SHIFT か / 乗り降り   ENTER アクション",
	"GAMEPAD   L-STICK move   B / X / Y board/leave   A or RT action":
		"ゲームパッド   左スティック 移動   B / X / Y 乗り降り   A か RT アクション",
	"F2 / BACK  AI crew on-off   M music   F1 CRT   F11 fullscreen   ESC quit / lobby":
		"F2 / BACK  AIクルー切替   M 音楽   F1 CRT   F11 全画面   ESC 終了 / ロビー",
	"LEFT SIDE drag to move   ACTION fire / repair / patch breaches":
		"画面の左側をドラッグで移動   アクション：撃つ・修理・穴をふさぐ",
	"BOARD get on or off the station you stand on   phone BACK  menu":
		"乗降：立っている持ち場に乗る／降りる   戻る：メニュー",

	# Touch buttons
	"ACTION": "アクション",
	"BOARD": "乗降",

	# Toasts
	"P%d JOINED THE CREW%s": "P%d が乗員に加わった%s",
	" - TOOK OVER FROM AI": "（AIと交代）",
	"a phone joined as a spectator - the crew is full": "スマホが観戦で参加（乗員は満員）",
	"P%d LEFT - AI TAKES OVER": "P%d が抜けた - AIが交代",
	"AI CREW %s": "AIクルー %s",

	# Banners
	"出撃！  DEPLOYED": "出撃！",
	"survive as long as you can - keep every station crewed": "できるだけ長く生き残れ - 持ち場を空けるな",
	"WAVE %d CLEAR": "ウェーブ %d クリア",
	"+%d   hull patched +40": "+%d   装甲修復 +40",
	"増援！  REINFORCEMENTS - WAVE %d": "増援！  ウェーブ %d",
	"敵襲来！  WAVE %d": "敵襲来！  ウェーブ %d",
	"ボス出現！  BOSS - WAVE %d": "ボス出現！  ウェーブ %d",
	"%d INFANTRY   %d RPG   %d TANKS": "歩兵 %d   RPG %d   戦車 %d",
	"   %d DRONES   %d BUGGIES": "   ドローン %d   自爆バギー %d",
	"鬼戦車 ONI SENSHA - the demon tank approaches": "鬼戦車 - 鬼の戦車が迫る",
	"ゲームオーバー  TANK DESTROYED": "ゲームオーバー",
	"survived %s   wave %d   score %d": "生存 %s   ウェーブ %d   スコア %d",
	"★ 新記録！ NEW RECORD! ★": "★ 新記録！ ★",
	"best %s  (wave %d)": "ベスト %s（ウェーブ %d）",
	"press ACTION to redeploy": "ACTIONで再出撃",

	# Repair gauge, shield and popups
	"TAP in the green   HOLD = shield": "緑でタップ　長押し＝シールド",
	"SHIELD": "シールド",
	"SHIELD UP": "シールド展開",
	"RECHARGING": "充電中",
	"UP ": "展開 ",
	"CANNON %s   MG %s   SHIELD %s   BREACHES %d": "主砲 %s   機銃 %s   シールド %s   損傷 %d",
	"REPAIR - SHIELD UP": "修理 - シールド展開",
	"REPAIR  COMBO x%d": "修理  コンボ x%d",
	"COMBO x%d": "コンボ x%d",
	"PERFECT! +%d": "パーフェクト！ +%d",
	"PERFECT! +SHIELD": "パーフェクト！ +シールド",
	"GOOD +%d": "グッド +%d",
	"GOOD": "グッド",
	"MISS": "ミス",
	"SHIELD DOWN": "シールド消失",
	"TOWER DOWN! +%d": "タワー崩落！ +%d",
	"BUILDING DOWN! +%d": "ビル倒壊！ +%d",
	"SQUASHED!": "ぺしゃんこ！",
	"BARRIER DOWN!": "結界破壊！",
	"GAMEPAD   L-STICK move   R-STICK aim guns   B / X / Y board/leave   A or RT action":
		"ゲームパッド   左スティック 移動   右スティック 照準   B / X / Y 乗り降り   A か RT アクション",
	"REPAIR: tap ACTION when the needle is in the green - hold ACTION for an energy shield":
		"修理：針が緑に入ったらアクション　長押しでエネルギーシールド",

	# New waves and enemies
	"ドローン嵐！  DRONE STORM - WAVE %d": "ドローン嵐！  ウェーブ %d",
	"装甲部隊！  ARMOUR COLUMN - WAVE %d": "装甲部隊！  ウェーブ %d",
	"迫撃砲！  MORTAR BARRAGE - WAVE %d": "迫撃砲！  ウェーブ %d",
	"%d DRONES": "ドローン %d",
	"%d BUGGIES": "自爆バギー %d",
	"%d HORNET SWARMS": "ホーネット群 %d",
	"%d MORTARS": "迫撃砲 %d",
	"%d BARRIER TRUCKS": "結界車 %d",
	"%d GUNSHIPS": "攻撃ヘリ %d",

	# Demo
	"DEMO  %s LEFT": "体験版  残り %s",
	"DEMO OVER": "体験版終了",
	"the demo's 10 minutes of battle are used up": "体験版の戦闘時間（10分）を使い切りました",
	"get the full game: %s": "製品版はこちら：%s",
	"デモ終了  DEMO OVER - THANKS FOR PLAYING!": "体験版終了 - 遊んでくれてありがとう！",
	"the full game is endless - get it on itch.io": "製品版はエンドレス - itch.ioで入手",
	"press ACTION for the menu": "ACTIONでメニューへ",
	"DEMO  -  %s OF BATTLE LEFT": "体験版  -  戦闘時間 残り %s",
	"DEMO  -  battle time used up: thanks for playing!": "体験版  -  戦闘時間終了：遊んでくれてありがとう！",
	"GET THE FULL GAME": "製品版を入手",
	"endless waves on itch.io - opens your browser": "itch.ioでエンドレスに - ブラウザが開きます",
}
