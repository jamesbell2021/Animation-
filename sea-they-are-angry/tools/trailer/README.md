# The itch.io trailer and GIFs

Three scripts make `itch/trailer/SeaTheyAreAngry-trailer.mp4`, `itch/trailer/poster.png`
and the six GIFs in `itch/gifs/`:

- `trailer_director.gd` records one shot (a "take") of the game with Godot's Movie Maker.
- `assemble.py` cuts the takes into the trailer, with text cards and the sound.
- `make_gifs.py` cuts the GIFs from the same takes.

Needs Godot 4.3, ffmpeg, Python 3 with Pillow, and `xvfb-run` on a machine with no
display. The takes are big and are not kept in git: put them in a work folder outside
the repository (below, `$WORK`).

## Record a take

```
WORK=/tmp/trailer_takes; mkdir -p $WORK
shot=fog
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 \
    --write-movie $WORK/$shot.avi --fixed-fps 30 \
    -s res://tools/trailer/trailer_director.gd -- shot=$shot > $WORK/$shot.log 2>&1
```

(On a PC with a screen, leave out the `xvfb-run ...` part.) The shots are `dusk fog hook
shotgun fire pier` (Kirkhaven), `boat arm` (the Escape) and `beam rise camp blind rear`
(the rock and the kraken). Keep the `.log`: its `REC` line says where the usable footage
starts, and the other two scripts read it. The "Compile Error: Identifier not found"
lines at the top of a log are harmless (the script is read before the autoloads exist).

With no graphics card a frame takes a second or two, so a take is three to five minutes.
To check a shot's staging first, ask for stills: only the frames named are drawn.

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --fixed-fps 30 \
    -s res://tools/trailer/trailer_director.gd -- shot=fog stills=0.5,2.0,4.0 out=$WORK
```

Each shot is two functions in `trailer_director.gd`: `_setup_<name>` (time of day, who
stands where, what is in the scene) and `_direct_<name>(t)` (what happens at each moment,
and the camera). Its length and scene are in the `SHOTS` table at the top. The director
hides the HUD, damage numbers and name tags, mutes the game's music (the edit lays its
own), and backs up and restores `user://run.json` and `user://profile.json`. If a take is
killed part-way, the save is not put back: don't kill one.

## Cut the trailer

```
python3 tools/trailer/assemble.py $WORK
```

The edit is the `EDL` table at the top of `assemble.py`: cards, and for each shot which
take, where in it to start (seconds after its `REC` mark) and how long. From the first
action shot on, lengths are in bars of `audio/music_finale.ogg` (126 beats a minute), so
the cuts fall on the beat. The sound is all the game's own: `music_harbour_night` under
the opening, the bell on "The clock stuck.", the finale from its third phrase, each
take's recorded sound, and the foghorn on the title. It is brought to -14 LUFS with
peaks under -1 dBTP, and the script prints what it measured and the cut list.

## Make the GIFs

```
python3 tools/trailer/make_gifs.py $WORK            # all six
python3 tools/trailer/make_gifs.py $WORK 03_fire    # one
```

The `GIFS` table says which take each comes from, where it starts, its length, width and
frame rate. itch.io refuses images over 3 MB, so the script steps each one down (fewer
colours, narrower, slower) until it is under 2.3 MB. If `gifsicle` is installed it is run
over them as well.
