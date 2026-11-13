# Sea They Are Angry: the itch.io page

Everything to fill in on itch.io's "Create new project" form, in the form's order, for
version 1.3.1. The description itself is in `description.html` (open it in a browser,
select all, copy, and paste into itch's description box: the formatting comes with it).
How to upload the builds is in `UPLOAD.md`. The art is in `art/`, the screenshots in
`screenshots/`, the trailer in `trailer/` and the animated GIFs in `gifs/`.

---

## Title
Sea They Are Angry

## Project URL
`sea-they-are-angry` (so the page is `https://<your-itch-name>.itch.io/sea-they-are-angry`)

## Short description or tagline
Keep the light burning. A North Sea fog-horror survival game for one to three keepers, 1987.

## Classification
Games

## Kind of project
Downloadable

## Release status
Released (or "In development" if you want to signal that more is coming; the game is
complete from start to end card)

## Pricing
Your call. Pay-what-you-want with a suggested price, or free with donations, both suit a
first release. itch lets you change it later.

## Uploads
- `SeaTheyAreAngry-1.3.1-windows.zip`: tick **Windows** ("This file will be played on")
- `SeaTheyAreAngry-1.3.1-linux.zip`: tick **Linux**

(Or push them with butler: see `UPLOAD.md`. butler is better: players get small patches
for updates and the itch app installs it cleanly.)

## Description
Paste from `description.html`.

## Genre
Survival

## Tags (itch allows up to 10)
horror, survival, lighthouse, local-co-op, atmospheric, top-down, 3d, story-rich,
boss-battle, retro (or: fog, 1980s, scotland, if you'd rather)

## AI generation disclosure
itch asks whether the project uses generative AI. Answer it honestly for how the game was
made.

## App store links
None.

## Custom noun
Leave blank.

## Community
Comments (simplest), or a discussion board if you want bug reports kept in threads.

## Visibility & access
Start as **Draft** to check the page, then **Public**.

---

## Metadata (the "More details" section)

- **Platforms:** Windows, Linux
- **Inputs:** Keyboard, Mouse, Gamepad (any)
- **Accessibility:** Configurable controls, Colour-blind friendly, Adjustable difficulty,
  Interactive tutorial (the first days' jobs list), Subtitles (captions for the night
  sounds and the wireless)
- **Multiplayer:** Local multiplayer (1 to 3 players, shared and split screen), Local area
  network (LAN) (the rock alone, one keeper per machine)
- **Player count:** 1 to 3
- **Languages:** English
- **Average session:** About an hour (a full story is 45 to 70 minutes)
- **Made with:** Godot, Blender
- **Content warnings / mature content:** none of itch's mature categories apply. It is a
  horror game with creatures that are fought and burned, and people of the town who can be
  taken; there is no gore beyond that. Mention "horror themes" in the description (it does).

## The images

- **Cover image:** `art/cover_630x500.png` (itch's size: 630x500; shown on the browse grid
  and in the itch app)
- **Banner** (Edit theme, "Banner image"): `art/banner_960x320.png`
- **Screenshots** (upload in this order; itch shows the first ones beside the description):
  1. `screenshots/10_kraken_rears_up.png`: the kraken rears up out of the sea at the lighthouse
  2. `screenshots/02_kirkhaven_at_dusk.png`: Kirkhaven's street lamps at dusk
  3. `screenshots/05_the_escape_boarders.png`: The Escape: climbers on the Mary Ann's sides
  4. `screenshots/08_kraken_takes_the_camp.png`: the kraken comes over the camp's wire
  5. `screenshots/07_the_rock_by_day.png`: the rock by day
  6. `screenshots/04_fire_on_the_quay.png`: fire on the quay, the flamer's jet
  7. `screenshots/03_the_seven_of_kirkhaven.png`: the seven of Kirkhaven
  8. `screenshots/09_kraken_blinded.png`: the kraken blinded by the lamp
  9. `screenshots/06_the_escape_under_the_light.png`: The Escape, the rock's light ahead
  10. `screenshots/11_the_keepers_log.png`: a page of the keeper's log
  11. `screenshots/01_title.png`: the title
- **Icon** (for social links and embeds, optional): `art/icon_512.png`

## The trailer

- **File:** `trailer/SeaTheyAreAngry-trailer.mp4` (40 seconds, 1280x720, with sound), and
  `trailer/poster.png` to use as its thumbnail.
- **itch.io cannot host the video itself.** The "Gameplay video or trailer" field only
  takes a link to YouTube or Vimeo. So: upload the MP4 to YouTube (or Vimeo) yourself, set
  `poster.png` as the thumbnail, and paste the video's link into that field. Until that is
  done the page has no trailer.
- A title for the upload: `Sea They Are Angry: trailer`. All the footage is the game
  itself and all the sound is the game's own music and effects.

## The animated GIFs

Six short loops in `gifs/`, each under 2.5 MB (itch refuses images over 3 MB). Use them in
either of two places: add them to the screenshot list like any screenshot (itch plays
them), or put them in the description with the editor's image button, between its
sections. Two or three in the description is plenty; the rest can go in the screenshots.

1. `gifs/01_kirkhaven_fog.gif`: the fog on the west slip, the lamps going out, the pale
   eyes coming up out of it. Best at the top of the description, or first screenshot.
2. `gifs/02_shotgun.gif`: a keeper's shotgun, both barrels, on the quay.
3. `gifs/03_fire.gif`: a petrol bomb and the flamer on the quay. Beside the weapons text.
4. `gifs/04_the_escape.gif`: the Mary Ann, climbers on her side. Beside "The Escape".
5. `gifs/05_the_beam.gif`: the lighthouse beam burning them on the beach.
6. `gifs/06_the_kraken.gif`: the kraken rearing up at the light. Beside the last act.

The trailer and the GIFs are made by the scripts in `tools/trailer/` (its README says how).

## Theme suggestion (Edit theme)

- Background: `#0b1018` (night sea); inner column: `#141a24`
- Text: `#e8e2d2`; links and buttons: `#f0c46e` (the lamp's gold); headings in the same gold
- Font: itch's "Crimson Text" or "Lora" sits closest to the game's IM FELL titles

## What's not on the page yet

- **The Windows build has never been run on Windows.** Try it yourself before going
  public.
