import os, sys, subprocess, time
from PIL import Image, ImageFilter
import numpy as np
from collections import deque

def process_video(name):
    t0 = time.time()
    input_video = f"/Users/elischafer/Developer/AllergyFit/marketing/mascot/{name}.mp4"
    frame_dir = f"scratch/{name}_raw_frames"
    keyed_dir = f"scratch/{name}_keyed_frames"
    os.makedirs(frame_dir, exist_ok=True)
    os.makedirs(keyed_dir, exist_ok=True)

    print(f"[{name}] Extracting frames...")
    subprocess.run([
        "ffmpeg", "-y", "-i", input_video,
        "-vf", "scale=480:480",
        f"{frame_dir}/frame_%03d.png"
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    frame_files = sorted([f for f in os.listdir(frame_dir) if f.endswith(".png")])
    print(f"[{name}] Keying {len(frame_files)} frames...")

    for fname in frame_files:
        img = Image.open(f"{frame_dir}/{fname}").convert("RGB")
        w, h = img.size
        arr = np.array(img, dtype=np.float32)

        corners = [arr[3, 3], arr[3, w-4], arr[h-4, 3], arr[h-4, w-4], arr[3, w//2]]
        bg_color = np.median(corners, axis=0)
        dist = np.linalg.norm(arr - bg_color, axis=-1)
        is_bg = dist < 45

        visited = np.zeros((h, w), dtype=bool)
        q = deque()
        for x in range(w):
            if is_bg[0, x] and not visited[0, x]:
                visited[0, x] = True
                q.append((0, x))
            if is_bg[h-1, x] and not visited[h-1, x]:
                visited[h-1, x] = True
                q.append((h-1, x))
        for y in range(h):
            if is_bg[y, 0] and not visited[y, 0]:
                visited[y, 0] = True
                q.append((y, 0))
            if is_bg[y, w-1] and not visited[y, w-1]:
                visited[y, w-1] = True
                q.append((y, w-1))

        while q:
            cy, cx = q.popleft()
            for dy, dx in [(-1,0), (1,0), (0,-1), (0,1)]:
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                    if is_bg[ny, nx]:
                        visited[ny, nx] = True
                        q.append((ny, nx))

        char_mask = (~visited).astype(np.uint8) * 255
        mask_img = Image.fromarray(char_mask, 'L').filter(ImageFilter.GaussianBlur(radius=0.5))

        rgba = Image.fromarray(arr.astype(np.uint8), 'RGB')
        rgba.putalpha(mask_img)
        rgba.save(f"{keyed_dir}/{fname}")

    print(f"[{name}] Encoding ProRes...")
    prores_file = f"scratch/{name}_prores.mov"
    subprocess.run([
        "ffmpeg", "-y", "-framerate", "24",
        "-i", f"{keyed_dir}/frame_%03d.png",
        "-c:v", "prores_ks", "-profile:v", "4",
        "-pix_fmt", "yuva444p10le",
        prores_file
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    print(f"[{name}] Encoding HEVC Alpha...")
    hevc_alpha_file = f"scratch/{name}_alpha.mov"
    subprocess.run([
        "avconvert", "-p", "PresetHEVCHighestQualityWithAlpha",
        "-s", prores_file, "-o", hevc_alpha_file, "--replace"
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # Also build an APNG / animated WebP for ultra-lightweight fallback!
    apng_file = f"scratch/{name}_anim.png"
    subprocess.run([
        "ffmpeg", "-y", "-framerate", "20",
        "-i", f"{keyed_dir}/frame_%03d.png",
        "-vf", "scale=240:240",
        "-plays", "0",
        apng_file
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    print(f"[{name}] Completed in {time.time()-t0:.1f}s! HEVC: {os.path.getsize(hevc_alpha_file)//1024}KB, APNG: {os.path.getsize(apng_file)//1024}KB")

for n in ["idle", "eat", "drink"]:
    process_video(n)

