"""Strengthens the blush on the rendered frames and packs them into ../../assets/hiyori.png.

    pip install pillow numpy imagequant
    python post.py
"""
import json
import os

import imagequant
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

DIR = os.path.dirname(os.path.abspath(__file__))
job = json.load(open(os.path.join(DIR, "frames.json")))
OUT = os.path.join(DIR, "out")


def boost(frame, base, gain, glow, strokes):
    """Pixels that turn pink between ParamCheek=0 and the frame get pushed further,
    each cheek gets a soft pink glow, and optional anime "///" strokes."""
    a = np.asarray(frame).astype(np.float32)
    b = np.asarray(base).astype(np.float32)
    d = a[..., :3] - b[..., :3]
    skin = (b[..., 0] > 225) & (b[..., 1] > 195) & (b[..., 2] > 165) & (b[..., 0] - b[..., 2] < 60) & (a[..., 3] > 250)
    w = np.clip(((-d[..., 1]) - np.maximum(0, -d[..., 0])) / 6.0, 0, 1) * skin
    w = np.asarray(Image.fromarray((w * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))).astype(np.float32) / 255
    o = a.copy()
    o[..., :3] = np.clip(a[..., :3] + gain * d * w[..., None], 0, 255)
    ys, xs = np.nonzero(w > 0.3)
    cheeks = []
    if len(xs) > 40:
        mid = np.median(xs)
        for side in (xs < mid, xs >= mid):
            if side.sum() > 20:
                cheeks.append((xs[side].mean(), ys[side].mean()))
    h, wd = a.shape[:2]
    if glow > 0 and cheeks:
        yy, xx = np.mgrid[0:h, 0:wd].astype(np.float32)
        g = np.zeros((h, wd), np.float32)
        for cx, cy in cheeks:
            g = np.maximum(g, np.exp(-(((xx - cx) / 30.0) ** 2 + ((yy - cy) / 17.0) ** 2)))
        g *= glow * skin
        pink = np.array([246, 120, 140], np.float32)
        o[..., :3] = o[..., :3] * (1 - g[..., None]) + pink * g[..., None]
    img = Image.fromarray(np.clip(o, 0, 255).astype(np.uint8), "RGBA")
    if strokes and cheeks:
        ss = 4
        layer = Image.new("RGBA", (wd * ss, h * ss), (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        for cx, cy in cheeks:
            for k in (-1, 0, 1):
                x0, y0 = cx + k * 9.5, cy + 1
                draw.line([((x0 - 5.5) * ss, (y0 + 10) * ss), ((x0 + 5.5) * ss, (y0 - 10) * ss)], fill=(206, 70, 96, 200), width=int(3.0 * ss))
        img = Image.alpha_composite(img, layer.resize((wd, h), Image.LANCZOS))
    return img


cell, cols = job["cell"], job["columns"]
rows = (len(job["frames"]) + cols - 1) // cols
sheet = Image.new("RGBA", (cell * cols, cell * rows), (0, 0, 0, 0))
for index, frame in enumerate(job["frames"]):
    name = f"{index:02d}_{frame['name']}.png"
    img = Image.open(os.path.join(OUT, name)).convert("RGBA")
    if frame["name"] in job["blush"]:
        img = boost(img, Image.open(os.path.join(OUT, "base", name)).convert("RGBA"), *job["blush"][frame["name"]])
    img = img.crop(tuple(job["crop"])).resize((cell, cell), Image.LANCZOS)
    sheet.paste(img, ((index % cols) * cell, (index // cols) * cell))

target = os.path.join(DIR, "..", "..", "assets", "hiyori.png")
imagequant.quantize_pil_image(sheet, dithering_level=1.0, max_quality=100, min_quality=70, max_colors=256).save(target, optimize=True)
print("wrote", os.path.normpath(target), os.path.getsize(target), "bytes")
