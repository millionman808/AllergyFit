import os
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
from collections import deque

src_path = '/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/avocado_fitness_ref_1789890477558.jpg'
img = Image.open(src_path).convert('RGB')
w, h = img.size
arr = np.array(img, dtype=np.float32)

# 1. Flood fill white background
dist_to_white = np.linalg.norm(arr - [255, 255, 255], axis=-1)
is_white = dist_to_white < 25

visited = np.zeros((h, w), dtype=bool)
q = deque([(0, 0), (0, w-1), (h-1, 0), (h-1, w-1)])
for y, x in q:
    visited[y, x] = True

while q:
    cy, cx = q.popleft()
    for dy, dx in [(-1,0), (1,0), (0,-1), (0,1)]:
        ny, nx = cy + dy, cx + dx
        if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
            if is_white[ny, nx]:
                visited[ny, nx] = True
                q.append((ny, nx))

# Character mask (1 = inside character, 0 = background)
char_mask = (~visited).astype(np.uint8) * 255

# Also remove spark lines above head (y < 240 and (x < 330 or x > 690))
char_mask[:240, :330] = 0
char_mask[:240, 690:] = 0

# Create full cutout with transparency
rgba = np.dstack([arr.astype(np.uint8), char_mask])
full_cutout = Image.fromarray(rgba, 'RGBA')
full_cutout.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/full_cutout.png')
print('Saved full_cutout.png')
