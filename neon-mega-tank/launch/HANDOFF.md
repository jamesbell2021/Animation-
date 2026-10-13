# Handoff: getting Neon Mega Tank live on itch.io

Read this first if you're a Claude session (or a person) picking the launch up on another
machine. Everything below was prepared in a cloud session on 13 October 2026 and is pushed.

## Where everything is

| What | Where |
|---|---|
| The game (Godot 4.3) and this launch kit | repo `jamesbell2021/Animation-`, branch **`claude/windows-build-omarchy-d2b94k`**, folder `neon-mega-tank/` |
| Build workflow (Android + Windows + Linux on every push to the game, itch.io upload with butler on `nmt-v*` tags or by hand) | `.github/workflows/neon-mega-tank-apk.yml` in the same repo |
| itch.io page text (EN + JA), tags, settings | `neon-mega-tank/launch/itch-page.md` |
| Bundle name, price, description, cross-promo lines | `neon-mega-tank/launch/bundle.md` |
| Announcement posts | `neon-mega-tank/launch/posts.md` |
| Launch steps in order | `neon-mega-tank/launch/CHECKLIST.md` |
| Covers for itch.io (630×500) and the 512 icon | `neon-mega-tank/launch/out/` (regenerate with `python3 launch/make_art.py`) |
| Screenshots for the itch.io page (8 English + 4 Japanese) | repo `jamesbell2021/gamesdevni-site`, `screenshots/nmt_*.jpg` on `main` |
| Trailer with the "OUT NOW ON ITCH.IO" end card | `gamesdevni-site`, branch **`nmt-launch`**, `video/neon_mega_tank_trailer.mp4` (the `main` copy still says "coming soon") |
| Website launch version (buy link, bundle section) | `gamesdevni-site`, branch `nmt-launch`; placeholders `GAME_URL` and `BUNDLE_URL` in `index.html` |
| **Release signing keystore + password** | **Not in git.** On James's PC: `~/.local/share/godot/keystores/neon-mega-tank-release.keystore` and its password in `neon-mega-tank-release.txt` beside it (made 13 Oct 2026, certificate SHA-256 `139a7eda…96fc2f16`), and in the repository's `ANDROID_RELEASE_KEYSTORE_*` secrets. This is the key the first public APK is signed with. The key in the cloud chat's `nmt-launch-kit.zip` was never used for a release: don't sign with it. |
| The release builds | the workflow's artifacts (APK release-signed with the key above, 64- and 32-bit ARM; Windows; Linux) |

Clone or update:

```
git clone https://github.com/jamesbell2021/Animation-.git
cd Animation- && git checkout claude/windows-build-omarchy-d2b94k
git clone https://github.com/jamesbell2021/gamesdevni-site.git
cd gamesdevni-site && git checkout nmt-launch
```

## Decisions already made

* Price **$4.99 or more**; launch-week sale 20% (one week). The other four games are $1.
* Bundle **Neon Arcade Collection**, all five games, **$5.99**.
* itch.io project name `neon-mega-tank` (the workflow's `ITCH_PROJECT` is `gamesdevnisite/neon-mega-tank`).
* Android `version/code=2`, `version/name="1.0.0"` in `export_presets.cfg`. Bump both for every release.
* Keystore alias `neonmegatank`; the password is in `neon-mega-tank-release.txt` beside the keystore.

## What's left, in order (details in CHECKLIST.md)

1. Done 13 Oct: the `ANDROID_RELEASE_KEYSTORE_*` secrets are set (add `BUTLER_API_KEY` if the
   workflow should upload to itch.io). To rebuild, start a fresh build (**Actions → Neon Mega Tank
   builds → Run workflow**; re-running an old run rebuilds that old commit with its old
   Android-only workflow), or push tag `nmt-v1.0.0`, and download the three builds from the
   run's artifacts.
2. Upload the trailer to YouTube.
3. Create the itch.io project from `itch-page.md`, upload the three builds, set the price,
   add the screenshots, the cover and the YouTube link. Draft → check → Public.
4. Create the bundle from `bundle.md`; add the cross-promo line to the other four pages.
5. Launch-week sale on Neon Mega Tank.
6. Website: replace `GAME_URL` and `BUNDLE_URL` on the `nmt-launch` branch, merge to `main`
   (that publishes it; the site is GitHub Pages at gamesdevni.site).
7. Post the devlog and the short posts from `posts.md`.

## Things to know

* itch.io doesn't show a page in search or browse until their team has reviewed it (days to a
  couple of weeks). Make the page public early so the review runs before launch day. The four
  older games are public but not yet indexed either, so check their status in the dashboard.
* A bundle can only hold public, paid games from the same account, and can't be priced below
  its dearest game, so set Neon Mega Tank's price before creating the bundle.
* The Windows exe is unsigned, so SmartScreen warns on first run; normal for itch.io.
* The keystore is the only copy. Losing it means no more updates to the Android build.
* There's no GitHub Release on purpose: the repository is public, and a Release would give a
  paid game's builds away. Run artifacts expire after 90 days, so keep a copy of the files you
  upload to itch.io.
