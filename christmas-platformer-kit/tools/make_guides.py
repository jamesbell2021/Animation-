"""Builds the teaching reference images in docs/: a labelled sheet of every tile,
and a guide to the 47-tile blob set showing which neighbours each tile expects."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from terrain import blob_masks, BIT_OFFSETS

ROOT = Path(__file__).resolve().parent.parent
T = 64
BG, GRID, TXT, DIM = (24, 30, 58), (60, 72, 120), (235, 240, 255), (150, 165, 210)
font = ImageFont.load_default(size=13)
big = ImageFont.load_default(size=22)


def labelled_sheet(path, title, names):
    """names: {(col,row): label} for the top-left cell of each tile."""
    sheet = Image.open(path)
    cols, rows = sheet.width // T, sheet.height // T
    pad, cell_h = 24, T + 18
    out = Image.new("RGB", (pad * 2 + cols * (T + 8), 52 + rows * cell_h + pad), BG)
    d = ImageDraw.Draw(out)
    d.text((pad, 14), title, font=big, fill=TXT)
    for r in range(rows):
        for c in range(cols):
            x, y = pad + c * (T + 8), 52 + r * cell_h
            d.rectangle([x - 1, y - 1, x + T, y + T], outline=GRID)
            out.paste(sheet.crop((c * T, r * T, c * T + T, r * T + T)), (x, y), sheet.crop((c * T, r * T, c * T + T, r * T + T)))
            d.text((x, y + T + 2), names.get((c, r), f"{c},{r}"), font=font, fill=TXT if (c, r) in names else DIM)
    return out


def main():
    props = json.loads((ROOT / "tools/props_meta.json").read_text())
    out = ROOT / "docs"
    out.mkdir(exist_ok=True)
    plat = {(v["col"], v["row"]): k for k, v in props["platforms"].items()}
    for k, v in props["platforms"].items():
        for f in range(1, v.get("frames", 1)):
            plat[(v["col"] + f, v["row"])] = f"  frame {f + 1}"
    labelled_sheet(ROOT / "tiles/platforms_hazards.png", "platforms_hazards.png  (source 4)", plat).save(out / "ref_platforms_hazards.png")
    deco = {}
    for k, v in props["decorations"].items():
        deco[(v["col"], v["row"])] = f"{k} {v['w']}x{v['h']}" if v["w"] * v["h"] > 1 else k
        for f in range(1, v.get("frames", 1)):
            deco[(v["col"] + f, v["row"])] = f"  frame {f + 1}"
    # Wider cells for decoration names
    img = labelled_sheet(ROOT / "tiles/decorations.png", "decorations.png  (source 5, no collision)", {k: v[:14] for k, v in deco.items()})
    img.save(out / "ref_decorations.png")
    pick = {}
    for it in props["pickups"]:
        pick[(0, it["row"])] = it["name"]
    labelled_sheet(ROOT / "tiles/pickups.png", "pickups.png  (6-frame animations, one per row)", pick).save(out / "ref_pickups.png")

    # 47-tile blob guide
    masks = blob_masks()
    sheet = Image.open(ROOT / "tiles/terrain_snow_ground.png")
    cols = 8
    cw, ch = 150, 92
    g = Image.new("RGB", (24 + cols * cw, 70 + 6 * ch), BG)
    d = ImageDraw.Draw(g)
    d.text((24, 14), "The 47-tile blob set: the 3x3 diagram shows which neighbours are solid (red = this tile)", font=big, fill=TXT)
    for i, m in enumerate(masks + [255]):
        c, r = i % cols, i // cols
        x, y = 24 + c * cw, 60 + r * ch
        tile = sheet.crop((c * T, r * T, c * T + T, r * T + T))
        g.paste(tile, (x, y), tile)
        s = 12
        ox, oy = x + T + 10, y + 8
        for gy in range(3):
            for gx in range(3):
                dx, dy = gx - 1, gy - 1
                if (dx, dy) == (0, 0):
                    col = (232, 59, 59)
                else:
                    bit = next(b for b, off in BIT_OFFSETS.items() if off == (dx, dy))
                    col = (228, 240, 251) if m & bit else (50, 60, 100)
                d.rectangle([ox + gx * (s + 2), oy + gy * (s + 2), ox + gx * (s + 2) + s, oy + gy * (s + 2) + s], fill=col)
        d.text((ox, oy + 46), "variant" if i == 47 else f"mask {m}", font=font, fill=DIM)
    g.save(out / "guide_blob_47.png")

    # Contact sheet of all four terrains side by side
    names = ["snow_ground", "ice", "gingerbread", "snow_brick"]
    tiles = [Image.open(ROOT / f"tiles/terrain_{n}.png") for n in names]
    w, h = tiles[0].size
    cs = Image.new("RGB", (w * 2 + 72, h * 2 + 120), BG)
    d = ImageDraw.Draw(cs)
    for i, (n, im) in enumerate(zip(names, tiles)):
        x, y = 24 + (i % 2) * (w + 24), 44 + (i // 2) * (h + 40)
        d.text((x, y - 26), f"terrain_{n}.png  (source {i})", font=big, fill=TXT)
        cs.paste(im, (x, y), im)
    cs.save(out / "ref_terrains.png")
    print("guides written")


if __name__ == "__main__":
    main()
