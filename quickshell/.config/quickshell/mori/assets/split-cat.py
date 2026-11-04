"""Split the cat drawings into one alpha mask per Mori colour (CatDoodle.qml).

Usage: python3 split-cat.py <out dir>   (reads the drawings from ~/Pictures)
Drawings: black lines plus pure paint colours on a transparent background.

Pure paint colours map to colour tokens; grey anti-aliasing pixels join the
stroke colour they touch, with coverage from their brightness. The drawings
trace the same cat on the same 800×600 canvas, so all are cropped with one
shared frame: the cat stays the same size and hats, flowers and "BOO!"
extend around it.
"""
import os
import sys
import numpy as np
from PIL import Image

PAINT = {  # paint colour -> default colour token
    (0, 0, 0): "line", (255, 255, 255): "fg", (255, 0, 0): "red",
    (255, 127, 237): "purple", (76, 255, 0): "green", (255, 216, 0): "yellow",
}
# drawing -> (file in ~/Pictures, token overrides)
DRAWINGS = {
    "cat": ("cat doodle.png", {}),
    "cat-christmas": ("cat-christmas.png", {"fg": "snow"}),     # white fuzz stays white
    "cat-halloween": ("cat-halloween.png", {"fg": "line"}),     # ghost in the usual grey
    "cat-valentine": ("cat-valentine.png", {}),
    "cat-birthday": ("cat-birthday.png", {}),
}


def masks(path, overrides):
    im = np.asarray(Image.open(path).convert("RGBA")).astype(float)
    rgb, alpha = im[..., :3], im[..., 3] / 255
    keys = np.array(list(PAINT))
    tokens = [overrides.get(t, t) for t in PAINT.values()]
    dist = ((rgb[:, :, None, :] - keys[None, None]) ** 2).sum(-1)
    nearest = dist.argmin(-1)
    exact = (dist.min(-1) < 30 ** 2) & (alpha > 0)
    grey = (np.abs(rgb - rgb.mean(-1, keepdims=True)).max(-1) < 8) & ~exact & (alpha > 0)
    label = np.where(exact, nearest, -1)
    for y, x in zip(*np.nonzero(grey)):
        window = label[max(0, y - 2):y + 3, max(0, x - 2):x + 3]
        found = window[window >= 0]
        if found.size:
            label[y, x] = np.bincount(found).argmax()
    lum = rgb.mean(-1) / 255
    out = {}
    for index, paint in enumerate(PAINT.values()):
        sel = label == index
        if not sel.any():
            continue
        if paint == "line":
            cover = np.where(exact, 1.0, 1 - lum)   # black ink: darker = more ink
        elif paint == "fg":
            cover = np.where(exact, 1.0, lum)       # white ink: lighter = more ink
        else:
            cover = np.ones_like(lum)
        token = tokens[index]
        out[token] = np.maximum(out.get(token, 0), np.where(sel, alpha * cover, 0))
    return out


def main(out_dir):
    drawings = {name: masks(os.path.expanduser("~/Pictures/" + file), overrides)
                for name, (file, overrides) in DRAWINGS.items()}
    union = np.maximum.reduce([layer for layers in drawings.values() for layer in layers.values()])
    ys, xs = np.nonzero(union > 0)
    margin = 6
    box = (xs.min() - margin, ys.min() - margin, xs.max() + margin + 1, ys.max() + margin + 1)
    for name, layers in drawings.items():
        for token, mask in layers.items():
            image = Image.new("RGBA", (mask.shape[1], mask.shape[0]), (255, 255, 255, 0))
            image.putalpha(Image.fromarray((mask * 255).clip(0, 255).astype(np.uint8)))
            image.crop(box).save(f"{out_dir}/{name}.{token}.png", optimize=True)
    print("frame", box, "size", (box[2] - box[0], box[3] - box[1]))


if __name__ == "__main__":
    main(sys.argv[1])
