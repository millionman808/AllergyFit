from PIL import Image, ImageFilter
import numpy as np
from collections import deque

def remove_bg(img_path, out_path):
    img = Image.open(img_path).convert('RGB')
    w, h = img.size
    arr = np.array(img, dtype=np.float32)

    # Sample corners for background color
    corners = [arr[5, 5], arr[5, w-6], arr[h-6, 5], arr[h-6, w-6], arr[5, w//2]]
    bg_color = np.median(corners, axis=0)

    # Distance to bg_color
    dist = np.linalg.norm(arr - bg_color, axis=-1)

    # Threshold for background: bg in video has subtle lighting variation (< 35)
    is_bg = dist < 45

    # Flood fill from image borders
    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    
    # Seed all border pixels that are close to background color
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

    # Mask of character
    char_mask = (~visited).astype(np.uint8) * 255
    
    # Antialias alpha mask slightly
    mask_img = Image.fromarray(char_mask, 'L').filter(ImageFilter.GaussianBlur(radius=0.6))
    
    rgba = Image.fromarray(arr.astype(np.uint8), 'RGB')
    rgba.putalpha(mask_img)
    rgba.save(out_path)
    print(f"Saved {out_path}")

for name in ['idle_sample', 'celebrate_mid', 'eat_mid', 'drink_mid']:
    remove_bg(f'scratch/frames/{name}.png', f'scratch/frames/{name}_keyed.png')
