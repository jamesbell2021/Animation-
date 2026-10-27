# itch.io page: Kaiju Coast

Paste the blocks below into the itch.io project. The **Description** is English first, then a
Japanese block under it. The rest of the page settings are at the end, and every image they
name is in `launch/out/` (made by `launch/make_art.py` from the trailer takes).

To remake the trailer and the art after the game changes:

```
xvfb-run -a -s "-screen 0 1920x1080x24" tools/trailer/record.sh   # films the 12 shots in the game
python3 tools/trailer/assemble.py                                  # cuts tools/trailer/out/kaiju_coast_trailer.mp4
python3 launch/make_art.py                                         # cover, banner, screenshots, GIFs
```

Suggested YouTube title: *Kaiju Coast – neon tower defence where you man the guns yourself
(trailer)*. Description: the tagline below, then the itch.io link.

---

## Description (English)

*(First, insert `launch/out/banner_960x360.png` as an image. Put `gif_eye_out.gif` after "Then man the guns yourself" and `gif_airstrike.gif` after "Call in the storm".)*

**The blood moon is up, and the sea is walking.**

Kaiju Coast is a neon tower defence game where you hold a Japanese bay against giant monsters,
and then climb into the guns and fight them yourself. Everything is drawn as glowing vector
solids, like an arcade cabinet from a parallel 1985.

**Build the coast guard.** Five guns along the seawall and on the sea forts: the 大砲 cannon,
火箭 homing rockets, 雷神 chain lightning, the 刀 katana rail that pierces a whole line, and 花火
firework flak for the flying ones. At level 3 every gun picks one of two upgrade paths: buckshot
or armour-piercing, a rocket swarm or cluster bomblets, a weak-point sniper or a double shot.

**Then man the guns yourself.** Jump into any gun at any moment and fight in first person as a
**gunner** or a **rocketeer**. Shoot out the glowing eyes for triple damage. Blind a kaiju and
it staggers and goes berserk. Cut every eye out of one of the Orochi's heads and the head comes
off.

**Fly the airship.** The Raijin-maru (雷神丸) patrols the bay with a searchlight and koinobori
streamers. Fit it with a bomb bay and rocket pods, or take the helm and fly it over the kaiju
while you strafe them from the nose gun.

**Call in the storm.** Airstrikes that carpet-bomb a line of the bay, a lightning storm, and the
flood gates, which throw a wall of water at the kaiju and push them back out to sea.

**Kaiju with tricks.** The crab-shark burrows under your sea forts. The sea dragon coils round
one and crushes it. Tengu dive-bomb whichever gun you're sitting in. The Dai-Oni swings a spiked
club, and on wave 10 Yamata-no-Orochi rises from the bay.

**A city that falls and burns.** Kaiju that reach the shore smash the neon city block by block.
Buildings collapse, their neighbours catch fire, and searchlights sweep the sky. Each wave
brings its own weather: rain, and storms with lightning and a heavy swell.

**Over the top.** A pumping taiko, shamisen and shakuhachi soundtrack, blood spray, firework
explosions, manga sound effects, and radio call-outs in Japanese (出撃! 敵襲来! 大鬼だ!) with
subtitles. All of the music, voices and sound effects are synthesised in code.

### Platforms

* **Windows** and **Linux**: mouse and keyboard, or any gamepad.
* **Android** (phones and tablets): touch controls. Tap to build, pinch to zoom, drag to aim.

### Controls

| | Command view | First person |
|---|---|---|
| Mouse / touch | Click or tap a ring to build; drag to pan | Aim; click or hold 撃 to fire |
| Keyboard | 1–5 build · U upgrade · Space next wave · F man a gun · Z board the airship | Q swap weapon · R reload · WASD fly the airship · Esc leave |
| Specials | 7 airstrike · 8 lightning storm · 9 flood gates | the same, aimed where you look |
| Gamepad | LB/RB pick a ring · A select · Y man the gun · D-pad specials | right stick aim · RT fire · LT zoom · B leave |

Three difficulties, a guided first wave, 15 waves to win and endless mode after that. Settings
for sensitivity, invert Y, volumes, graphics quality, fullscreen and the CRT filter.

Made with Godot 4 by 3BL.

---

## Description (日本語)

**赤い月の夜、海が歩き出した。**

『怪獣海岸』は、日本の湾を巨大怪獣から守るネオン・タワーディフェンス。砲台を築くだけでなく、
いつでも自分で乗り込んで戦えます。すべてが光るベクター・ソリッドで描かれた、もうひとつの
1985年のアーケードの世界です。

**防衛線を築け。** 防波堤と海上要塞に5種類の砲台。**大砲**、追尾する**火箭**、連鎖する**雷神**、
一列を貫く**刀**レールガン、空の敵を撃ち落とす**花火**。レベル3で砲台ごとに2つの強化ルートから
ひとつを選びます。

**自ら砲台に乗り込め。** どの砲台にもすぐ乗り込み、一人称視点で**機関砲**か**噴進砲**を撃てます。
光る目を撃てばダメージ3倍。目を潰された怪獣はよろめき、怒り狂います。八岐大蛇の首は、目を
すべて潰せば落ちます。

**飛行船を操れ。** サーチライトと鯉のぼりをなびかせた**雷神丸**。爆弾倉や噴進弾ポッドを積み、
自分で舵を取って怪獣の上を飛びながら機首の砲で撃ちまくれます。

**嵐を呼べ。** 湾を一直線に爆撃する**空爆**、**雷雨**、そして怪獣を沖へ押し返す**放流**。

**一筋縄ではいかない怪獣たち。** 海上要塞の下に潜る蟹鮫、要塞に巻きつく竜神、あなたの乗る砲台に
急降下する天狗、金棒を振るう大鬼、そして第十波には八岐大蛇。

**燃え落ちる街。** 上陸した怪獣はネオンの街を壊していきます。ビルが崩れ、隣が燃え、サーチライトが
夜空を照らします。波ごとに天気が変わり、雨や、稲妻と高波の嵐がやってきます。

**やりすぎなくらい派手に。** 太鼓と三味線と尺八のビート、血しぶき、花火のような爆発、マンガの
効果音、字幕つきの日本語の無線（出撃！ 敵襲来！ 大鬼だ！）。音楽、音声、効果音はすべて
プログラムで合成しています。

**対応機種：** Windows、Linux（マウスとキーボード、ゲームパッド）、Android（タッチ操作）。
難易度は3段階。チュートリアルつき。15波を守り抜けばクリア、その後はエンドレスモード。

Godot 4で制作。

---

## Page settings

| Field | Value |
|---|---|
| Title | Kaiju Coast |
| Project URL | `gamesdevnisite.itch.io/kaiju-coast` (the CI workflow pushes to this name; change `ITCH_PROJECT` in `.github/workflows/kaiju-coast.yml` if you pick another) |
| Short description / tagline | Hold a neon Japanese bay against giant kaiju, then climb into the guns and fight them yourself. |
| Classification | Game |
| Kind of project | Downloadable |
| Pricing | Your call. Neon Mega Tank is **$4.99 or more**; the same price would let Kaiju Coast join the Neon Arcade Collection bundle |
| Genre | Strategy (or Action) |
| Tags (up to 10) | tower-defense, kaiju, neon, fps, retro, arcade, japan, monsters, godot, vector |
| Made with | Godot |
| Average session | About half an hour |
| Languages | English (menus carry Japanese labels; the voices are Japanese with English subtitles) |
| Inputs | Keyboard, Mouse, Gamepad (any), Touchscreen |
| Player count | Singleplayer |
| Accessibility | Subtitles, Configurable controls (sensitivity, invert Y), High-contrast |
| Content | Cartoon blood (blood spray and gore on giant monsters) |
| Release status | Released |
| Cover image | `launch/out/cover_630x500.png` |
| Screenshots | `launch/out/screenshots/01_reveal.jpg` … `12_finale.jpg` (1920×1080, in order) |
| Animated GIFs (in the description) | `launch/out/gif_eye_out.gif`, `launch/out/gif_airstrike.gif` |
| Trailer | itch.io only embeds YouTube or Vimeo: upload `launch/out/kaiju_coast_trailer.mp4` (75 s, 1080p) to YouTube first, then paste the link. Thumbnail: `launch/out/kaiju_coast_poster.jpg` |
| Page colours (Edit theme) | background `#07060d`, text `#f0e8d8`, links `#36d7ff`, buttons `#ff3b30`; header image `launch/out/banner_960x360.png` |
| Community | Comments |

### Uploads

| File | Platform tag | Notes |
|---|---|---|
| `kaiju-coast-windows.zip` | Windows | from the CI run's `kaiju-coast-windows` artifact |
| `kaiju-coast-linux.zip` | Linux | artifact `kaiju-coast-linux` |
| `kaiju-coast.apk` | Android | artifact `kaiju-coast-apk` (release-signed once the `ANDROID_RELEASE_KEYSTORE_*` secrets are set) |

Or let the workflow upload them: with the `BUTLER_API_KEY` secret set, push a tag like
`kc-v1.0.0` (or run **Kaiju Coast builds** by hand with "Push the builds to itch.io" ticked). It
uses the channels `windows`, `linux` and `android`, and itch.io creates them on the first push.
