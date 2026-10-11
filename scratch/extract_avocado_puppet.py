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

char_mask = (~visited).astype(np.uint8) * 255

# Clean out spark lines above head
char_mask[:250, :350] = 0
char_mask[:250, 670:] = 0

# =========================================================================
# 2. SEPARATE LEFT ARM
# =========================================================================
# Left arm spans x from ~75 to ~280, y from ~440 to ~735
# Shoulder connects to body around x: 220-270, y: 440-520
arm_l_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(430, 750):
    for x in range(70, 280):
        if char_mask[y, x]:
            # Arm is left of the body outline
            # Let's check body edge: at y=440 body starts at 278; at y=480 at 265; at y=520 at 248; at y=580 at 235
            # We want to keep the arm including shoulder
            # Condition: keep pixels that belong to arm
            # For y > 530, arm is strictly x < 210 (separated by white gap)
            if y > 530:
                if x < 210:
                    arm_l_mask[y, x] = 255
            else:
                # Shoulder region: y between 430 and 530, x between 180 and 275
                # Keep if it is arm
                if x < 275:
                    arm_l_mask[y, x] = 255

# Smooth and round shoulder top on arm_l_mask
y_al, x_al = np.where(arm_l_mask > 0)
arm_l_rgba = np.dstack([arr.astype(np.uint8), arm_l_mask])
arm_l_crop = Image.fromarray(arm_l_rgba[y_al.min():y_al.max()+1, x_al.min():x_al.max()+1], 'RGBA')

# =========================================================================
# 3. SEPARATE RIGHT ARM
# =========================================================================
# Right arm spans x from ~740 to ~950, y from ~440 to ~735
arm_r_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(430, 750):
    for x in range(740, 955):
        if char_mask[y, x]:
            if y > 530:
                if x > 815:
                    arm_r_mask[y, x] = 255
            else:
                if x > 750:
                    arm_r_mask[y, x] = 255

y_ar, x_ar = np.where(arm_r_mask > 0)
arm_r_rgba = np.dstack([arr.astype(np.uint8), arm_r_mask])
arm_r_crop = Image.fromarray(arm_r_rgba[y_ar.min():y_ar.max()+1, x_ar.min():x_ar.max()+1], 'RGBA')

# =========================================================================
# 4. SEPARATE LEFT FOOT (SNEAKER)
# =========================================================================
foot_l_mask = np.zeros((h, w), dtype=np.uint8)
# Left sneaker & ankle: x from 270 to 445, y from 835 to 975
for y in range(830, 980):
    for x in range(270, 445):
        # Exclude ground shadow: shadow is gray (r~220, g~220, b~220) below shoe
        if char_mask[y, x]:
            is_shadow = (arr[y, x, 0] > 200 and arr[y, x, 1] > 200 and arr[y, x, 2] > 200) and (y > 960 or x < 280)
            if not is_shadow:
                foot_l_mask[y, x] = 255

y_fl, x_fl = np.where(foot_l_mask > 0)
foot_l_rgba = np.dstack([arr.astype(np.uint8), foot_l_mask])
foot_l_crop = Image.fromarray(foot_l_rgba[y_fl.min():y_fl.max()+1, x_fl.min():x_fl.max()+1], 'RGBA')

# =========================================================================
# 5. SEPARATE RIGHT FOOT (SNEAKER)
# =========================================================================
foot_r_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(830, 980):
    for x in range(560, 735):
        if char_mask[y, x]:
            is_shadow = (arr[y, x, 0] > 200 and arr[y, x, 1] > 200 and arr[y, x, 2] > 200) and (y > 960 or x > 725)
            if not is_shadow:
                foot_r_mask[y, x] = 255

y_fr, x_fr = np.where(foot_r_mask > 0)
foot_r_rgba = np.dstack([arr.astype(np.uint8), foot_r_mask])
foot_r_crop = Image.fromarray(foot_r_rgba[y_fr.min():y_fr.max()+1, x_fr.min():x_fr.max()+1], 'RGBA')

# =========================================================================
# 6. EXTRACT BODY (TORSO, HEAD, HEADBAND, PIT)
# =========================================================================
# Body is char_mask minus arms minus feet minus shadow
body_mask = char_mask.copy()
# Zero out left arm
for y in range(430, 750):
    for x in range(70, 240):
        body_mask[y, x] = 0
# Zero out right arm
for y in range(430, 750):
    for x in range(785, 955):
        body_mask[y, x] = 0
# Zero out feet below avocado belly curve
# Avocado belly curve ends at y ~ 860. Below y=860 is feet/shadow
body_mask[860:, :] = 0
# For y between 825 and 860, zero out legs outside body
# Legs are at x ~ 320-430 and x ~ 580-680
# The body contour between y=825 and 860 is inside the pear curve
# Let's inspect where the body bottom contour is
for y in range(825, 860):
    # Pear bottom radius
    dy = y - 860
    # circle equation approximation or x range
    # At y=840, x is [370, 654]; at y=855, x is [430, 594]
    half_w = np.sqrt(max(0, (284**2) - (y - 580)**2)) if abs(y - 580) < 284 else 100
    # Everything outside [512 - half_w, 512 + half_w] is zeroed
    body_mask[y, :int(512 - half_w)] = 0
    body_mask[y, int(512 + half_w):] = 0

# Crop body to its bounding box
y_b, x_b = np.where(body_mask > 0)
body_rgba = np.dstack([arr.astype(np.uint8), body_mask])
body_crop = Image.fromarray(body_rgba[y_b.min():y_b.max()+1, x_b.min():x_b.max()+1], 'RGBA')

# =========================================================================
# 7. GENERATE EYELIDS
# =========================================================================
# Eyelids must be EXACT same size as body_crop!
eyelids = Image.new('RGBA', body_crop.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(eyelids)

# Relative coordinates in body_crop:
# Body crop top-left is (x_b.min(), y_b.min())
# Left eye in full image was ~ (428, 358)
# Right eye in full image was ~ (594, 358)
bx0, by0 = x_b.min(), y_b.min()
lex, ley = 447 - bx0, 360 - by0
rex, rey = 579 - bx0, 360 - by0

# Draw cute smiling closed eye arcs: ⌒  ⌒
# Arc bounding boxes
eye_w, eye_h = 42, 28
# Dark green/charcoal color matching eye stroke
stroke_color = (35, 60, 21, 255)

# We can draw cute curved thick arcs
# Left eye arc
draw.arc([lex - eye_w//2, ley - eye_h//2, lex + eye_w//2, ley + eye_h//2], start=195, end=345, fill=stroke_color, width=6)
# Right eye arc
draw.arc([rex - eye_w//2, rey - eye_h//2, rex + eye_w//2, rey + eye_h//2], start=195, end=345, fill=stroke_color, width=6)

# Save all scratch parts
out_dir = '/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch'
body_crop.save(f'{out_dir}/avo_body.png')
eyelids.save(f'{out_dir}/avo_eyelids.png')
arm_l_crop.save(f'{out_dir}/avo_arm_l.png')
arm_r_crop.save(f'{out_dir}/avo_arm_r.png')
foot_l_crop.save(f'{out_dir}/avo_foot_l.png')
foot_r_crop.save(f'{out_dir}/avo_foot_r.png')

print("All parts extracted:")
print("Body size:", body_crop.size)
print("Eyelids size:", eyelids.size)
print("Arm L size:", arm_l_crop.size)
print("Arm R size:", arm_r_crop.size)
print("Foot L size:", foot_l_crop.size)
print("Foot R size:", foot_r_crop.size)

