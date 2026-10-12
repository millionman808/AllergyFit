"""Key the HD Pip animations (art/incoming/anim_*.mp4) to transparent HEVC.

Background is removed only where it connects to the frame edge, so greens
inside the avocado are never cut out. Output replaces AllergyFit/Resources/*_alpha.mov.
"""
import os, subprocess, sys, shutil
import numpy as np
from PIL import Image, ImageFilter

SIZE = 720
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def edge_connected(mask):
    seed = np.zeros_like(mask)
    seed[0, :] = mask[0, :]; seed[-1, :] = mask[-1, :]
    seed[:, 0] = mask[:, 0]; seed[:, -1] = mask[:, -1]
    while True:
        grown = seed.copy()
        grown[1:, :] |= seed[:-1, :]; grown[:-1, :] |= seed[1:, :]
        grown[:, 1:] |= seed[:, :-1]; grown[:, :-1] |= seed[:, 1:]
        grown &= mask
        if (grown == seed).all():
            return seed
        seed = grown

def process(name, out_name):
    src = f"{ROOT}/art/incoming/{name}.mp4"
    work = f"{ROOT}/scratch/hd_{name}"
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(f"{work}/raw"); os.makedirs(f"{work}/key")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-vf", f"scale={SIZE}:{SIZE}",
                    f"{work}/raw/f_%04d.png"], check=True)
    frames = sorted(os.listdir(f"{work}/raw"))
    for f in frames:
        arr = np.asarray(Image.open(f"{work}/raw/{f}").convert("RGB"), dtype=np.float32)
        h, w, _ = arr.shape
        bg = np.median(np.stack([arr[2, 2], arr[2, w - 3], arr[h - 3, 2], arr[h - 3, w - 3], arr[2, w // 2]]), axis=0)
        dist = np.linalg.norm(arr - bg, axis=-1)
        # Soft shadow under the feet is a darker shade of the same hue: treat as
        # background too, otherwise it keys out as a green blob.
        hue_like = (dist < 70) & (np.abs((arr[..., 1] - arr[..., 0]) - (bg[1] - bg[0])) < 22)
        yy = np.arange(h)[:, None]
        # The ground shadow is a darker shade of the background: allow more
        # range, but only near the floor.
        floor = (yy > h * 0.82) & (dist < 110) & (arr[..., 1] > arr[..., 0] + 25) & (arr[..., 1] > arr[..., 2] + 25)
        bgmask = edge_connected((dist < 42) | hue_like | floor)
        # Pockets of pure background that aren't connected to the edge (the gap
        # between the legs). Tight tolerance so the avocado's own greens stay.
        bgmask |= dist < 24
        alpha = Image.fromarray((~bgmask).astype(np.uint8) * 255, "L").filter(ImageFilter.GaussianBlur(0.7))
        rgba = Image.fromarray(arr.astype(np.uint8), "RGB"); rgba.putalpha(alpha)
        rgba.save(f"{work}/key/{f}")
    prores = f"{work}/prores.mov"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "24", "-i", f"{work}/key/f_%04d.png",
                    "-c:v", "prores_ks", "-profile:v", "4", "-pix_fmt", "yuva444p10le", prores], check=True)
    out = f"{ROOT}/AllergyFit/Resources/{out_name}.mov"
    if os.path.exists(out): os.remove(out)
    subprocess.run(["avconvert", "-p", "PresetHEVCHighestQualityWithAlpha", "-s", prores, "-o", out], check=True,
                   stdout=subprocess.DEVNULL)
    print(name, "->", out, len(frames), "frames", os.path.getsize(out) // 1024, "KB")

if __name__ == "__main__":
    for n in sys.argv[1:] or ["idle", "celebrate", "eat", "drink"]:
        process(f"anim_{n}", f"{n}_alpha")
