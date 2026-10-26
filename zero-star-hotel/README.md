# Zero Star Hotel

A cheap-and-cheerful hotel tycoon for phones and browsers, made in **Godot 4.3** (GL
Compatibility renderer, landscape). Same cartoon cut-out art style as *Lookee Lookee Tycoon*.

You've bought the worst hotel on the Costa. It has **zero stars**, two usable rooms, a pool that
is mostly algae and a "bar" that is a fridge of cans. Drunken lads, hen parties, backpackers and
mums on a getaway are already booked. Keep them (mostly) happy, keep the cockroaches down, stop
anybody drowning and work your way up to **three stars**.

## How to play

- **Tap a warning bubble** (or its alert on the right) to send your manager to sort it out:
  raves (loud music), punch-ups at the bar, vandalism, burglaries, pool emergencies and
  **sunlounger towel wars** between the mums. Each one has a fuse: if it runs out, things get
  worse (smashed rooms, stolen stuff, angry neighbours, compensation...).
- **Tap a cockroach** to squash it. Dirty rooms breed more overnight.
- **Tap a room** to see who's staying, how happy they are, and to clean, repair or upgrade it.
- **Rooms / Pints buttons** (bottom left) change your prices. Cheap pints sell loads and get
  guests drunk. Drunk guests fight, rave and break things. Pricey rooms earn more but guests
  expect more.
- **UPGRADES** opens the shop:
  - *Rooms*: open boarded-up rooms; upgrade them Grim → Basic → Decent → Nice.
  - *Hotel*: more floors, reception, pest control, the pool (clean it! add a slide!), pool fence
    and "NO DIVING" signs, sunloungers, the bar, karaoke, soundproofing, curfew signs, room safes,
    CCTV and damage deposits.
  - *Staff*: cleaners, a handyman, security, a lifeguard and a barman. They deal with trouble on
    their own; wages are paid at the end of each day.
  - *Stars*: the inspector's checklist for the next star. Tick everything off, then **book the
    inspector**. They tour every room, the bar and the pool the next day; three problems and you
    fail.
- Each day runs from 08:00 to 02:00 (about six minutes). Guests check out in the morning, laze by
  the pool, check in through the afternoon, hit the bar at happy hour and get up to no good after
  dark. At the end of the day you see the till roll and the day's **TrotAdvisor** reviews. Your
  average review is a big part of every star.
- The Android back button / Esc opens the pause menu. The game saves at the end of every day and
  when you quit or switch apps.

## The road to three stars

| Star | The inspector wants |
|------|--------------------|
| One ("Technically a Hotel") | reviews 2.0+, every open room Basic, clean pool, pool fence, NO DIVING signs, a cleaner |
| Two ("Actually Quite Decent") | reviews 3.0+, 6 rooms, all Decent, proper reception desk, a real bar, lifeguard, security, pest control |
| Three | reviews 4.0+, 10 rooms, all Nice, air-con lobby, cocktail bar, pool with slide, soundproofing, safes or CCTV, a handyman |

Better stars bring better guests (families, couples, pensioners) who pay more, drink less and
cause less trouble, but they are fussier.

## Project structure

```
autoload/      Global systems (autoloads): GameManager (scene flow, day clock, pausing),
               Hotel (rooms, guests, reviews, stars, inspections), Economy, Upgrades, Staff,
               RandomEvents, AudioManager, SaveSystem, Quality, CharacterData
data/          Lines (all the jokes and text), GuestTypes (who books and how they behave)
scenes/        main_menu.tscn, hotel.tscn, ui/hud.tscn
scripts/world/ The hotel scene: hotel_world.gd (the referee), hotel_layout.gd (where
               everything is), building/room/pool views, guest, helper (manager & staff),
               visitors (thief, inspector), incident, cockroach, camera, speech bubbles, FX
scripts/ui/    HUD, shop, room panel, day summary, pause, settings, main menu
scripts/character, scripts/audio, scripts/art
               The cut-out character rig, procedural voices/music/SFX and the UI theme
studio/        3BL_Indie splash and credits
tests/         smoke_test (headless play-through), compile_all
tools/         screenshots, make_icons
```

## Testing

```sh
# Headless play-through: menus, several days with a bot manager, save/load. Exit code 0 = pass.
godot --headless --path . res://tests/smoke_test.tscn
# Longer balance run: 14 days at 30x speed.
godot --headless --path . res://tests/smoke_test.tscn -- 14 30
# Screenshots of every screen (needs a display; use xvfb-run on a server).
godot --path . res://tools/screenshots.tscn -- /tmp/shots
# Regenerate the app icons and store cover from the character rig.
godot --path . res://tools/make_icons.tscn
# Film the trailer in-engine, then cut it (needs ffmpeg; xvfb-run on a server).
GODOT=godot tools/trailer/record.sh && python3 tools/trailer/assemble.py
```

## Exporting

Zero Star Hotel ships for **Android** and the **web browser** only; `export_presets.cfg` has
those two presets. The GitHub Actions workflow
`.github/workflows/zero-star-hotel.yml` runs the smoke test and builds both on every push
that touches this folder; download them from the run's **Artifacts**. Without the
`HOTEL_ANDROID_KEYSTORE_*` secrets the APK is a debug build (uninstall the old one before
installing a new one).

## Credits

See [CREDITS.md](CREDITS.md). Satire of package-holiday chaos, never of who anyone is.
