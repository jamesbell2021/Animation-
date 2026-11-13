# Uploading Sea They Are Angry to itch.io

The downloads are made from the build, not kept in git (they are 110 MB each). On this
machine they are in `build/itch/`:

| File | What | itch upload: "This file will be played on" |
|---|---|---|
| `SeaTheyAreAngry-1.3.2-windows.zip` | the game for Windows: the .exe, the .pck, README.txt, licences | Windows |
| `SeaTheyAreAngry-1.3.2-linux.zip` | the game for Linux: the binary (already executable), the .pck, README.txt, licences | Linux |
| `windows/`, `linux/` | the same, unzipped, for butler | |

## The easy way: upload the zips

1. On itch.io: **Dashboard → Create new project**, and fill it in from `PAGE.md`.
2. Under **Uploads**, upload each zip and tick its platform.
3. Save as **Draft**, look at the page, download your own game from it and run it, then set
   it **Public**.

## The better way: butler (itch's command-line uploader)

butler uploads only what changed (players get small patches) and the itch app installs the
game cleanly.

1. Install butler: https://itch.io/docs/butler/installing.html
2. Log in once: `butler login`
3. Push each platform to its own channel (replace `yourname` with your itch.io user name):

   ```
   butler push build/itch/windows yourname/sea-they-are-angry:windows --userversion 1.3.2
   butler push build/itch/linux   yourname/sea-they-are-angry:linux   --userversion 1.3.2
   ```

   The channel names `windows` and `linux` tell itch which platform each is, so you don't
   tick anything.
4. Check with `butler status yourname/sea-they-are-angry`.

## Making the next version's pack

After a new build (`scripts/export_windows.sh` and the Linux export, as in `HANDOFF.md`):

1. Copy the new binaries and .pck into `build/itch/windows/` and `build/itch/linux/` (the
   `README.txt` and `licences/` there stay; change the version in README.txt).
2. Re-zip, or `butler push` again with the new `--userversion`.
3. Add new screenshots to `itch/screenshots/` if the game looks different.

## Before going public

- **Run the Windows build on a real Windows PC.** It has never been tried on one.
- If Windows SmartScreen warns about an unknown publisher (it will: the .exe isn't signed),
  the README tells players to choose "More info", then "Run anyway". Signing needs a code
  signing certificate, which costs money; most itch games aren't signed.
- Decide the price and the AI-disclosure answer (see `PAGE.md`).
