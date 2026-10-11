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
char_mask[:250, :360] = 0
char_mask[:250, 660:] = 0
# Exclude the ground shadow from character mask for limbs
# Shadow is y > 920 and (x < 275 or (x > 445 and x < 560) or x > 730)
shadow_mask = np.zeros((h, w), dtype=bool)
shadow_mask[920:, :] = (dist_to_white[920:, :] > 15) & (dist_to_white[920:, :] < 80)

# Full clean character array
char_rgba = np.dstack([arr.astype(np.uint8), char_mask])

# --- EXTRACT LEFT FOOT ---
foot_l_mask = np.zeros((h, w), dtype=np.uint8)
foot_l_mask[830:980, 260:450] = char_mask[830:980, 260:450]
# Remove any shadow below shoe (y > 965 and x outside shoe)
foot_l_rgba = np.dstack([arr.astype(np.uint8), foot_l_mask])
# Crop to bounding box
y_fl, x_fl = np.where(foot_l_mask > 0)
foot_l_crop = Image.fromarray(foot_l_rgba[y_fl.min():y_fl.max()+1, x_fl.min():x_fl.max()+1], 'RGBA')
foot_l_crop.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_foot_l.png')

# --- EXTRACT RIGHT FOOT ---
foot_r_mask = np.zeros((h, w), dtype=np.uint8)
foot_r_mask[830:980, 550:740] = char_mask[830:980, 550:740]
foot_r_rgba = np.dstack([arr.astype(np.uint8), foot_r_mask])
y_fr, x_fr = np.where(foot_r_mask > 0)
foot_r_crop = Image.fromarray(foot_r_rgba[y_fr.min():y_fr.max()+1, x_fr.min():x_fr.max()+1], 'RGBA')
foot_r_crop.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_foot_r.png')

# --- EXTRACT LEFT ARM ---
arm_l_mask = np.zeros((h, w), dtype=np.uint8)
# Arm spans x: 70 to 280, y: 440 to 740
arm_l_mask[440:740, 70:280] = char_mask[440:740, 70:280]
# To prevent cutting into body, use x < 240 + (y - 580)*0.1 etc, or clean boundary
# Let's inspect where the arm meets the body at y ~ 450-520
arm_l_rgba = np.dstack([arr.astype(np.uint8), arm_l_mask])
y_al, x_al = np.where(arm_l_mask > 0)
arm_l_crop = Image.fromarray(arm_l_rgba[y_al.min():y_al.max()+1, x_al.min():x_al.max()+1], 'RGBA')
arm_l_crop.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_arm_l.png')

# --- EXTRACT RIGHT ARM ---
arm_r_mask = np.zeros((h, w), dtype=np.uint8)
arm_r_mask[440:740, 740:950] = char_mask[440:740, 740:950]
arm_r_rgba = np.dstack([arr.astype(np.uint8), arm_r_mask])
y_ar, x_ar = np.where(arm_r_mask > 0)
arm_r_crop = Image.fromarray(arm_r_rgba[y_ar.min():y_ar.max()+1, x_ar.min():x_ar.max()+1], 'RGBA')
arm_r_crop.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_arm_r.png')

print(f"Foot L size: {foot_l_crop.size}, Foot R size: {foot_r_crop.size}")
print(f"Arm L size: {arm_l_crop.size}, Arm R size: {arm_r_crop.size}")

