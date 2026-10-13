# Launch posts

Replace `GAME_URL` and `BUNDLE_URL` with the itch.io links. The YouTube link goes in wherever a
post can carry a video.

## itch.io devlog: "Neon Mega Tank is out"

**Neon Mega Tank is out now on itch.io, for Android, Windows and Linux.**

One tank, four crew. Everyone on the same giant neon tank, running between the drive, cannon,
machine gun and repair stations while the city comes down around you. Play together on your own
phones over Wi-Fi, on one screen with keyboards and gamepads, or solo with the AI crew filling
the empty seats.

What's in it:

* Endless waves of infantry, RPG troopers, drones, kamikaze buggies, tanks and heavy tanks,
  and the 鬼戦車 Oni Sensha boss every fifth wave.
* A fully destructible, freshly generated city every round.
* A chiptune soundtrack and enemies who shout their last words in electronic Japanese.
* English and Japanese, switchable from the title menu.

**$4.99**, 20% off for launch week. Or get the **Neon Arcade Collection**: this and our other four
games for $5.99. BUNDLE_URL

Tell us your best time in the comments. Our test crew of three bots and one idle human lasted
about three minutes.

## Short post (English)

NEON MEGA TANK is out! 🚀 One tank, four crew, a neon city that falls down. Co-op on your own
phones over Wi-Fi, or on one screen. Android · Windows · Linux. $4.99, 20% off this week.
GAME_URL

## Short post (日本語)

『ネオン・メガ・タンク』発売！ 一両の巨大戦車に四人で乗り込み、崩れ落ちるネオンの街で
どこまで生き残れるか。同じWi-Fiならそれぞれのスマホで一緒に遊べます。日本語対応。
Android・Windows・Linux。$4.99、発売週は20%オフ。
GAME_URL

## Bundle post

Five games, one price. The NEON ARCADE COLLECTION: Neon Mega Tank, Cyber Vikings, Victory By
None, Angry Old Men and Pultz for $5.99, a third off. BUNDLE_URL

## Thread for a longer post (Reddit r/IndieGaming, r/godot, r/AndroidGaming)

Title: *Neon Mega Tank: a 1-4 player co-op tank game where everyone plays on their own phone
over Wi-Fi (Godot 4)*

Body: We made a co-op tank battle in the spirit of Lovers in a Dangerous Spacetime: one huge
tank, four stations (drive, cannon, machine gun, repair), and a crew who run about the deck
between them. The twist is that it's built for phones: one phone hosts, friends join over
Wi-Fi, and everyone sees the battle from their own screen. An AI crew covers the empty seats,
so it works solo too.

Technical bits for r/godot: the city is one MultiMesh per block (about 2,000 destructible
cubes in a few dozen draw calls, which phone GPUs need), the networking is host-authoritative
over ENet with 20 Hz snapshots, and all the audio, including the Japanese voice lines, is
synthesised in code with a small formant speech synth. No audio files in the project.

It's $4.99 on itch.io (Android, Windows, Linux): GAME_URL. Trailer: YOUTUBE_URL.
