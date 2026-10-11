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

# Remove spark lines above head only (sparks are at y < 220, x < 280 and x > 740)
char_mask[:220, :280] = 0
char_mask[:220, 740:] = 0

# =========================================================================
# 2. DEFINE THE EXACT PEAR SILHOUETTE FOR THE AVOCADO BODY
# =========================================================================
# The avocado body is symmetric around x=512.
# Let's define the outer radius R(y) from y=105 (head top) to y=860 (belly bottom).
# We can find the body's actual outline where it's unobstructed (e.g. y=105 to 440, and y=750 to 860)
# and interpolate smoothly through the arm region (y=440 to 750).

# Unobstructed right half width at each y:
half_widths = np.zeros(h, dtype=np.float32)

for y in range(105, 861):
    # Right side: from x=512 to 1023
    row_mask = char_mask[y, 512:]
    non_zeros = np.where(row_mask > 0)[0]
    if len(non_zeros) > 0:
        hw = non_zeros.max()
        # If in arm region (y between 440 and 740), the arm bulges out to ~435.
        # But the body pear radius is around:
        # y=440: hw ~ 235
        # y=580: hw ~ 277
        # y=640: hw ~ 272
        # y=740: hw ~ 232
        # y=840: hw ~ 142
        # y=860: hw ~ 0
        if 440 <= y <= 740:
            # Quadratic / smooth spline pear curve between y=440 (234) and y=740 (232), peak at y=580 (277)
            # Normalised t in [0, 1]
            t = (y - 440) / 300.0
            # Smooth bell curve
            hw_interp = 234 + 43 * np.sin(np.pi * t)
            half_widths[y] = hw_interp
        else:
            # Below y=825, avoid the feet (feet extend to hw ~ 220)
            if y > 825:
                # Bottom of avocado is a circle of radius ~280 centered at (512, 580)
                # dy = y - 580, max hw = sqrt(280^2 - dy^2)
                dy = y - 580
                max_hw = np.sqrt(max(0, 280**2 - dy**2))
                half_widths[y] = min(hw, max_hw)
            else:
                half_widths[y] = hw

# Now create clean body mask
body_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(105, 861):
    hw = int(np.round(half_widths[y]))
    x0 = max(0, 512 - hw)
    x1 = min(w, 512 + hw + 1)
    body_mask[y, x0:x1] = char_mask[y, x0:x1]

# Ensure the outer 14-pixel border of body_mask has the rich dark-green border:
# Inside body_mask, if a pixel was white (e.g. from the gap between arm and body), fill it with dark green outline/flesh
dark_green = np.array([35, 60, 21], dtype=np.uint8)
light_green = np.array([76, 109, 52], dtype=np.uint8)

body_rgb = arr.astype(np.uint8).copy()
for y in range(105, 861):
    hw = int(np.round(half_widths[y]))
    x_left = 512 - hw
    x_right = 512 + hw
    # Left border: paint dark green outline on the edge (width ~ 10px)
    for x in range(x_left, x_left + 12):
        if 0 <= x < w:
            if body_mask[y, x] > 0 and dist_to_white[y, x] < 30:
                body_rgb[y, x] = dark_green
    # Right border
    for x in range(x_right - 12, x_right + 1):
        if 0 <= x < w:
            if body_mask[y, x] > 0 and dist_to_white[y, x] < 30:
                body_rgb[y, x] = dark_green
    # Bottom border
    if y > 845:
        for x in range(x_left, x_right + 1):
            if 0 <= x < w and body_mask[y, x] > 0:
                if y > 852 or dist_to_white[y, x] < 30:
                    body_rgb[y, x] = dark_green

# Crop body
y_b, x_b = np.where(body_mask > 0)
body_rgba = np.dstack([body_rgb, body_mask])
body_crop = Image.fromarray(body_rgba[y_b.min():y_b.max()+1, x_b.min():x_b.max()+1], 'RGBA')

# =========================================================================
# 3. EXTRACT CLEAN LEFT ARM (WITH ROUNDED SHOULDER CAP)
# =========================================================================
arm_l_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(430, 750):
    for x in range(70, 280):
        if char_mask[y, x]:
            if y > 530:
                if x < 210:
                    arm_l_mask[y, x] = 255
            else:
                # Arm region up to shoulder
                if x < 275:
                    arm_l_mask[y, x] = 255

# Fill and round the shoulder at the top (around y: 440-480, x: 200-275)
arm_l_rgb = arr.astype(np.uint8).copy()
# Round the shoulder joint
y_al, x_al = np.where(arm_l_mask > 0)
arm_l_rgba = np.dstack([arm_l_rgb, arm_l_mask])
arm_l_crop = Image.fromarray(arm_l_rgba[y_al.min():y_al.max()+1, x_al.min():x_al.max()+1], 'RGBA')

# Draw rounded cap on shoulder of arm_l_crop
draw_al = ImageDraw.Draw(arm_l_crop)
# Shoulder is at the top-right of arm_l_crop
cw, ch = arm_l_crop.size
# Draw smooth curve / arc closing shoulder
draw_al.arc([cw - 80, 0, cw + 20, 80], start=120, end=270, fill=(35, 60, 21, 255), width=8)

# =========================================================================
# 4. EXTRACT CLEAN RIGHT ARM (WITH ROUNDED SHOULDER CAP)
# =========================================================================
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

# Draw rounded cap on shoulder of arm_r_crop (top-left)
draw_ar = ImageDraw.Draw(arm_r_crop)
draw_ar.arc([-20, 0, 80, 80], start=270, end=60, fill=(35, 60, 21, 255), width=8)

# =========================================================================
# 5. EXTRACT CLEAN FEET (SNEAKERS)
# =========================================================================
foot_l_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(835, 980):
    for x in range(275, 445):
        if char_mask[y, x]:
            # Filter shadow
            is_shadow = (arr[y, x, 0] > 200 and arr[y, x, 1] > 200 and arr[y, x, 2] > 200) and (y > 962 or x < 285)
            if not is_shadow:
                foot_l_mask[y, x] = 255

y_fl, x_fl = np.where(foot_l_mask > 0)
foot_l_crop = Image.fromarray(np.dstack([arr.astype(np.uint8), foot_l_mask])[y_fl.min():y_fl.max()+1, x_fl.min():x_fl.max()+1], 'RGBA')

foot_r_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(835, 980):
    for x in range(560, 730):
        if char_mask[y, x]:
            is_shadow = (arr[y, x, 0] > 200 and arr[y, x, 1] > 200 and arr[y, x, 2] > 200) and (y > 962 or x > 720)
            if not is_shadow:
                foot_r_mask[y, x] = 255

y_fr, x_fr = np.where(foot_r_mask > 0)
foot_r_crop = Image.fromarray(np.dstack([arr.astype(np.uint8), foot_r_mask])[y_fr.min():y_fr.max()+1, x_fr.min():x_fr.max()+1], 'RGBA')

# =========================================================================
# 6. GENERATE CLOSED EYELIDS WITH MATCHING AVOCADO FLESH FILL
# =========================================================================
eyelids = Image.new('RGBA', body_crop.size, (0, 0, 0, 0))
draw_el = ImageDraw.Draw(eyelids)

# Relative coordinates in body_crop
bx0, by0 = x_b.min(), y_b.min()
lex, ley = 447 - bx0, 360 - by0
rex, rey = 579 - bx0, 360 - by0

# Face flesh color at eye position is creamy lime-yellow
flesh_color = (235, 238, 160, 255)
line_color = (35, 60, 21, 255)

# 1. Fill circles over open eyes with avocado flesh
eye_r = 38
draw_el.ellipse([lex - eye_r, ley - eye_r, lex + eye_r, ley + eye_r], fill=flesh_color)
draw_el.ellipse([rex - eye_r, rey - eye_r, rex + eye_r, rey + eye_r], fill=flesh_color)

# 2. Draw thick expressive smiling arcs: ⌒ ⌒
arc_w, arc_h = 44, 28
draw_el.arc([lex - arc_w//2, ley - arc_h//2 - 2, lex + arc_w//2, ley + arc_h//2 - 2], start=195, end=345, fill=line_color, width=7)
draw_el.arc([rex - arc_w//2, rey - arc_h//2 - 2, rex + arc_w//2, rey + arc_h//2 - 2], start=195, end=345, fill=line_color, width=7)

# Soft feathering on eyelids for seamless blending
eyelids_blur = eyelids.filter(ImageFilter.GaussianBlur(radius=0.5))

# =========================================================================
# 7. GENERATE SHADOW ELLIPSE
# =========================================================================
shadow_img = Image.new('RGBA', (320, 80), (0, 0, 0, 0))
draw_s = ImageDraw.Draw(shadow_img)
draw_s.ellipse([20, 15, 300, 65], fill=(30, 45, 25, 60))
shadow_blurred = shadow_img.filter(ImageFilter.GaussianBlur(radius=10))

# Save all into scratch
out_dir = '/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch'
body_crop.save(f'{out_dir}/avo_body_v2.png')
eyelids_blur.save(f'{out_dir}/avo_eyelids_v2.png')
arm_l_crop.save(f'{out_dir}/avo_arm_l_v2.png')
arm_r_crop.save(f'{out_dir}/avo_arm_r_v2.png')
foot_l_crop.save(f'{out_dir}/avo_foot_l_v2.png')
foot_r_crop.save(f'{out_dir}/avo_foot_r_v2.png')
shadow_blurred.save(f'{out_dir}/avo_shadow_v2.png')

print("All V2 assets created successfully!")
print("Body V2 size:", body_crop.size)
print("Eyelids V2 size:", eyelids_blur.size)
print("Arm L V2 size:", arm_l_crop.size)
print("Arm R V2 size:", arm_r_crop.size)
print("Foot L V2 size:", foot_l_crop.size)
print("Foot R V2 size:", foot_r_crop.size)
