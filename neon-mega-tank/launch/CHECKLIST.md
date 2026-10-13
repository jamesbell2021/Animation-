# Launch checklist: Neon Mega Tank + the Neon Arcade Collection

Everything here is prepared; the steps marked **you** need your itch.io or GitHub login.

## 1. Signing key (once, before the first release build) - you

The release keystore `neon-mega-tank-release.keystore` and its password were handed over in
the chat. **Keep both somewhere safe** (a password manager): every future update must be
signed with the same key, or phones will refuse to install it over the old version. It's not
in the repository on purpose.

Add three repository secrets on GitHub (**Settings → Secrets and variables → Actions → New
repository secret**):

| Secret | Value |
|---|---|
| `ANDROID_RELEASE_KEYSTORE_BASE64` | the keystore file, base64-encoded: `base64 -w0 neon-mega-tank-release.keystore` (on Windows: `certutil -encode` then strip the header lines, or use Git Bash) |
| `ANDROID_RELEASE_KEYSTORE_USER` | `neonmegatank` |
| `ANDROID_RELEASE_KEYSTORE_PASS` | the password |

Optional: `BUTLER_API_KEY` from itch.io → **Settings → API keys**, so the workflow can upload
builds for you.

## 2. Build - automatic

Every push that touches `neon-mega-tank/` runs **Actions → Neon Mega Tank builds** and leaves
three artifacts: `neon-mega-tank-apk`, `neon-mega-tank-windows`, `neon-mega-tank-linux`. With
the secrets from step 1 the APK is release-signed (the run's log says which).

To publish straight to itch.io, push a tag (`git tag nmt-v1.0.0 && git push origin nmt-v1.0.0`)
or run the workflow by hand with **Push the builds to itch.io** ticked.

Version numbers live in `export_presets.cfg`: bump `version/code` (+1 every release, Android
refuses to install a lower one) and `version/name` before each release.

## 3. Trailer on YouTube - you

itch.io only embeds YouTube or Vimeo. Upload `video/neon_mega_tank_trailer.mp4` from the
website repository. Suggested title: *Neon Mega Tank - 1-4 player co-op tank battle on your
phones (trailer)*. Description: the short post from `posts.md` with the itch.io link.

## 4. itch.io project page - you

Create the project at itch.io → **Dashboard → Create new project** and fill it from
`itch-page.md` (title, description in English and Japanese, tags, pricing **$4.99 or more**,
cover `out/cover_630x500.png`, the 12 screenshots, the YouTube link). Upload the three builds
from step 2 or let butler do it. Save as **Draft** first, open the page, check the buy button and
downloads, then set it to **Public**.

## 5. Bundle - you

**Dashboard → Bundles → Create a bundle**: the five games, **$5.99**, title *Neon Arcade
Collection*, cover `out/bundle_cover_630x500.png`, description from `bundle.md`. Then add the
"Also in the Neon Arcade Collection" line from `bundle.md` to the other four games' pages.

## 6. Launch-week sale - you

On the Neon Mega Tank project: **Distribute → Sales → New sale**, 20% off, 7 days. The bundle
is already a third off, so it doesn't need its own sale.

## 7. Website - me, once you send the links

The `nmt-launch` branch of the website has the launch version of the Neon Mega Tank section
(buy button, prices, bundle banner, nav link). Send me the itch.io game URL and the bundle URL
and I'll fill them in, check it, and push it to main. Or do it yourself: replace `GAME_URL` and
`BUNDLE_URL` in `index.html` on that branch and merge it.

## 8. Tell people - you

`posts.md` has the devlog, short posts in English and Japanese, the bundle post, and a longer
thread for Reddit. Post the devlog on itch.io the day the page goes public; it goes out to
everyone following the account.

## Day-one checks

- Install the APK from the itch.io page on a phone that had the old test build: it must
  install over it (same key) and show the neon tank icon, not the Godot logo.
- Host on one phone, join from another over Wi-Fi, play a wave.
- Run the Windows zip once; Windows SmartScreen will warn on an unsigned exe ("More info →
  Run anyway"), which is normal for itch.io games.
- Switch the language to 日本語 and back.
