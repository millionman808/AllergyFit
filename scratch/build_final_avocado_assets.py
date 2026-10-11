import os
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

# Load body v2
body = Image.open('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_body_v2.png').convert('RGBA')
arr_b = np.array(body)
h, w, _ = arr_b.shape

# 1. Clean spark tips at the top outside head dome
for y in range(120):
    for x in range(w):
        # Distance from head top center (277, 60)
        # Head dome has radius ~ 130
        dx = x - 277
        dy = y - 60
        if dx*dx + dy*dy > 135**2 and y < 60:
            arr_b[y, x, 3] = 0
        elif (x < 150 or x > 405) and y < 110:
            arr_b[y, x, 3] = 0

clean_body = Image.fromarray(arr_b, 'RGBA')

# 2. Build Perfect Eyelids
eyelids = Image.new('RGBA', (w, h), (0, 0, 0, 0))
draw_el = ImageDraw.Draw(eyelids)

lex, ley = 202, 270
rex, rey = 350, 270
rx, ry = 44, 52
flesh_color = (234, 235, 160, 255)
line_color = (35, 60, 21, 255)

# Fill eye ovals with avocado flesh
draw_el.ellipse([lex - rx, ley - ry, lex + rx, ley + ry], fill=flesh_color)
draw_el.ellipse([rex - rx, rey - ry, rex + rx, rey + ry], fill=flesh_color)

# Draw cute smiling arcs: ⌒  ⌒
arc_rx, arc_ry = 36, 22
draw_el.arc([lex - arc_rx, ley - arc_ry - 4, lex + arc_rx, ley + arc_ry - 4], start=195, end=345, fill=line_color, width=9)
draw_el.arc([rex - arc_rx, rey - arc_ry - 4, rex + arc_rx, rey + arc_ry - 4], start=195, end=345, fill=line_color, width=9)

# Antialias eyelids slightly
eyelids_clean = eyelids.filter(ImageFilter.GaussianBlur(radius=0.5))

# 3. Clean Left Arm with smoothly rounded shoulder
arm_l = Image.open('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_arm_l.png').convert('RGBA')
arr_al = np.array(arm_l)
# Round the shoulder at top-right (around x: 130..205, y: 0..80)
draw_al = ImageDraw.Draw(arm_l)
# Fill shoulder cap with green flesh and dark border
shoulder_color = (78, 111, 50, 255)
border_color = (36, 56, 19, 255)
draw_al.pieslice([120, 0, 204, 84], start=180, end=360, fill=shoulder_color, outline=border_color, width=8)

# 4. Clean Right Arm with smoothly rounded shoulder
arm_r = Image.open('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_arm_r.png').convert('RGBA')
draw_ar = ImageDraw.Draw(arm_r)
draw_ar.pieslice([0, 0, 84, 84], start=180, end=360, fill=shoulder_color, outline=border_color, width=8)

# 5. Clean Left Foot (Sneaker)
foot_l = Image.open('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_foot_l.png').convert('RGBA')
arr_fl = np.array(foot_l)
# Clear gray shadow at bottom/left
dist_w = np.linalg.norm(arr_fl[:, :, :3] - [255, 255, 255], axis=-1)
# Shadow pixels have high R,G,B (>200) and are near the bottom (y > 130) or left (x < 20)
for y in range(arr_fl.shape[0]):
    for x in range(arr_fl.shape[1]):
        if arr_fl[y, x, 3] > 0:
            if y > 135 and arr_fl[y, x, 0] > 200 and arr_fl[y, x, 1] > 200 and arr_fl[y, x, 2] > 200:
                arr_fl[y, x, 3] = 0
            elif x < 15 and y > 120 and arr_fl[y, x, 0] > 190:
                arr_fl[y, x, 3] = 0
clean_foot_l = Image.fromarray(arr_fl, 'RGBA')

# 6. Clean Right Foot (Sneaker)
foot_r = Image.open('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_foot_r.png').convert('RGBA')
arr_fr = np.array(foot_r)
for y in range(arr_fr.shape[0]):
    for x in range(arr_fr.shape[1]):
        if arr_fr[y, x, 3] > 0:
            if y > 135 and arr_fr[y, x, 0] > 200 and arr_fr[y, x, 1] > 200 and arr_fr[y, x, 2] > 200:
                arr_fr[y, x, 3] = 0
            elif x > arr_fr.shape[1] - 15 and y > 120 and arr_fr[y, x, 0] > 190:
                arr_fr[y, x, 3] = 0
clean_foot_r = Image.fromarray(arr_fr, 'RGBA')

# 7. Clean Shadow Ellipse
shadow_img = Image.new('RGBA', (320, 80), (0, 0, 0, 0))
draw_s = ImageDraw.Draw(shadow_img)
draw_s.ellipse([20, 15, 300, 65], fill=(30, 45, 25, 75))
shadow_clean = shadow_img.filter(ImageFilter.GaussianBlur(radius=10))

# Save all final master files
out_dir = '/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch'
clean_body.save(f'{out_dir}/master_body.png')
eyelids_clean.save(f'{out_dir}/master_eyelids.png')
arm_l.save(f'{out_dir}/master_arm_l.png')
arm_r.save(f'{out_dir}/master_arm_r.png')
clean_foot_l.save(f'{out_dir}/master_foot_l.png')
clean_foot_r.save(f'{out_dir}/master_foot_r.png')
shadow_clean.save(f'{out_dir}/master_shadow.png')

# Generate a preview composite of the idle puppet
preview = Image.new('RGBA', (700, 850), (0, 0, 0, 0))
# 1. Shadow
preview.paste(shadow_clean, (190, 750), shadow_clean)
# 2. Feet
preview.paste(clean_foot_l, (185, 680), clean_foot_l)
preview.paste(clean_foot_r, (350, 680), clean_foot_r)
# 3. Arms (behind body)
preview.paste(arm_l, (10, 310), arm_l)
preview.paste(arm_r, (490, 310), arm_r)
# 4. Body
preview.paste(clean_body, (75, 40), clean_body)

preview.save(f'{out_dir}/master_preview_assembled.png')

# Also preview with eyelids closed (happy squint / blink)
preview_blink = preview.copy()
preview_blink.paste(eyelids_clean, (75, 40), eyelids_clean)
preview_blink.save(f'{out_dir}/master_preview_blinking.png')

print("All master assets built successfully!")
print("Body size:", clean_body.size)
print("Eyelids size:", eyelids_clean.size)
print("Arm L size:", arm_l.size)
print("Arm R size:", arm_r.size)
print("Foot L size:", clean_foot_l.size)
print("Foot R size:", clean_foot_r.size)

