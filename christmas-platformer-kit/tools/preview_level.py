"""Assemble a test level from the terrain sheets using the same 47-mask lookup Godot uses."""
import json, sys
from pathlib import Path
from PIL import Image
from terrain import reduce_mask, BIT_OFFSETS
TILE = 64
root = Path(__file__).resolve().parent.parent
meta = json.loads((root / "tools/terrain_meta.json").read_text())
LEVEL = [
    "..............................",
    "...........GGGG...............",
    "..BBBB.....GGGG.......IIIII...",
    "..B..B..........SSS...I...I...",
    "..BBBB.........SSSSS..IIIII...",
    "SSSS......SSSSSSSSSSS......SSS",
    "SSSSS....SSSSSS.SSSSSS....SSSS",
    "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSS",
]
KEY = {"S": "snow_ground", "I": "ice", "G": "gingerbread", "B": "snow_brick"}
sheets = {k: Image.open(root / f"tiles/terrain_{k}.png") for k in KEY.values()}
lookup = {k: {t["mask"]: (t["col"], t["row"]) for t in v["tiles"] if "probability" not in t} for k, v in meta.items()}
h, w = len(LEVEL), len(LEVEL[0])
img = Image.new("RGBA", (w * TILE, h * TILE), (40, 52, 110, 255))
for y in range(h):
    for x in range(w):
        ch = LEVEL[y][x]
        if ch not in KEY: continue
        m = 0
        for bit, (dx, dy) in BIT_OFFSETS.items():
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and LEVEL[ny][nx] == ch: m |= bit
            elif not (0 <= nx < w and 0 <= ny < h) and ny >= h: m |= bit
        c, r = lookup[KEY[ch]][reduce_mask(m)]
        img.alpha_composite(sheets[KEY[ch]].crop((c*TILE, r*TILE, c*TILE+TILE, r*TILE+TILE)), (x*TILE, y*TILE))
img.save(sys.argv[1] if len(sys.argv) > 1 else "level.png")
