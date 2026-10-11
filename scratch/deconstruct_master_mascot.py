import os
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

img = Image.open('scratch/master_no_bg.png').convert('RGBA')
w, h = img.size
arr = np.array(img)
alpha = arr[:, :, 3]

# 1. EXTRACT LEFT ARM (flexed bicep with fist)
# Left arm spans x: 148 to ~305, y: 300 to 520
arm_l_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(290, 530):
    for x in range(140, 310):
        if alpha[y, x] > 20:
            # Check if it belongs to arm:
            # Armpit separates arm from body below y ~ 410 (white gap)
            # Above y ~ 410, shoulder connects to body at x ~ 290
            if y > 415:
                if x < 265:
                    arm_l_mask[y, x] = 255
            else:
                if x < 295:
                    arm_l_mask[y, x] = 255

y_al, x_al = np.where(arm_l_mask > 0)
arm_l_rgba = arr.copy()
arm_l_rgba[:, :, 3] = arm_l_mask
arm_l_crop = Image.fromarray(arm_l_rgba[y_al.min():y_al.max()+1, x_al.min():x_al.max()+1], 'RGBA')

# 2. EXTRACT RIGHT ARM (flexed bicep with fist)
arm_r_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(290, 530):
    for x in range(715, 885):
        if alpha[y, x] > 20:
            if y > 415:
                if x > 755:
                    arm_r_mask[y, x] = 255
            else:
                if x > 725:
                    arm_r_mask[y, x] = 255

y_ar, x_ar = np.where(arm_r_mask > 0)
arm_r_rgba = arr.copy()
arm_r_rgba[:, :, 3] = arm_r_mask
arm_r_crop = Image.fromarray(arm_r_rgba[y_ar.min():y_ar.max()+1, x_ar.min():x_ar.max()+1], 'RGBA')

# 3. EXTRACT FEET (Left & Right Adidas sneakers)
foot_l_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(760, 945):
    for x in range(300, 500):
        if alpha[y, x] > 20:
            foot_l_mask[y, x] = 255

y_fl, x_fl = np.where(foot_l_mask > 0)
foot_l_crop = Image.fromarray(arr[y_fl.min():y_fl.max()+1, x_fl.min():x_fl.max()+1], 'RGBA')

foot_r_mask = np.zeros((h, w), dtype=np.uint8)
for y in range(760, 945):
    for x in range(510, 700):
        if alpha[y, x] > 20:
            foot_r_mask[y, x] = 255

y_fr, x_fr = np.where(foot_r_mask > 0)
foot_r_crop = Image.fromarray(arr[y_fr.min():y_fr.max()+1, x_fr.min():x_fr.max()+1], 'RGBA')

# 4. EXTRACT BODY
body_mask = alpha.copy()
# Zero out arms
body_mask[arm_l_mask > 0] = 0
body_mask[arm_r_mask > 0] = 0
# Zero out feet below avocado belly curve (y > 775)
body_mask[776:, :] = 0

y_b, x_b = np.where(body_mask > 20)
body_rgba = arr.copy()
body_rgba[:, :, 3] = body_mask
body_crop = Image.fromarray(body_rgba[y_b.min():y_b.max()+1, x_b.min():x_b.max()+1], 'RGBA')

# 5. CREATE EYELIDS (1:1 with body_crop)
bw, bh = body_crop.size
eyelids = Image.new('RGBA', (bw, bh), (0, 0, 0, 0))
draw_el = ImageDraw.Draw(eyelids)

# Relative coordinates in body_crop
bx0, by0 = x_b.min(), y_b.min()
lex, ley = 438 - bx0, 285 - by0
rex, rey = 572 - bx0, 285 - by0

rx, ry = 42, 54
flesh_color = (244, 240, 218, 255)
line_color = (25, 30, 25, 255)

# Fill over open black eyes with flesh color
draw_el.ellipse([lex - rx, ley - ry, lex + rx, ley + ry], fill=flesh_color)
draw_el.ellipse([rex - rx, rey - ry, rex + rx, rey + ry], fill=flesh_color)

# Draw cute smiling arcs: ⌒ ⌒
arc_w, arc_h = 36, 22
draw_el.arc([lex - arc_w, ley - arc_h - 2, lex + arc_w, ley + arc_h - 2], start=195, end=345, fill=line_color, width=9)
draw_el.arc([rex - arc_w, rey - arc_h - 2, rex + arc_w, rey + arc_h - 2], start=195, end=345, fill=line_color, width=9)

eyelids_clean = eyelids.filter(ImageFilter.GaussianBlur(radius=0.5))

# 6. SHADOW
shadow_img = Image.new('RGBA', (340, 70), (0, 0, 0, 0))
draw_s = ImageDraw.Draw(shadow_img)
draw_s.ellipse([20, 15, 320, 55], fill=(30, 40, 30, 70))
shadow_clean = shadow_img.filter(ImageFilter.GaussianBlur(radius=8))

# Save all into scratch
out_dir = 'scratch'
body_crop.save(f'{out_dir}/new_master_body.png')
eyelids_clean.save(f'{out_dir}/new_master_eyelids.png')
arm_l_crop.save(f'{out_dir}/new_master_arm_l.png')
arm_r_crop.save(f'{out_dir}/new_master_arm_r.png')
foot_l_crop.save(f'{out_dir}/new_master_foot_l.png')
foot_r_crop.save(f'{out_dir}/new_master_foot_r.png')
shadow_clean.save(f'{out_dir}/new_master_shadow.png')

print("All parts extracted from master.png:")
print("Body:", body_crop.size)
print("Eyelids:", eyelids_clean.size)
print("Arm L:", arm_l_crop.size)
print("Arm R:", arm_r_crop.size)
print("Foot L:", foot_l_crop.size)
print("Foot R:", foot_r_crop.size)
