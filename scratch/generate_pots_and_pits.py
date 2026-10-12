import os
import math
from PIL import Image, ImageDraw, ImageFilter
import numpy as np

os.makedirs('art/incoming', exist_ok=True)

def add_grain(image, intensity=12):
    arr = np.array(image, dtype=float)
    h, w, c = arr.shape
    noise = np.random.normal(0, intensity, (h, w))
    for i in range(3):
        arr[:, :, i] = np.clip(arr[:, :, i] + noise, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))

def draw_pot(color_base, rim_color, pattern=None, size=(2048, 2048)):
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    w, h = size
    
    # Pot geometry (centered, sitting on ground line around y=1800)
    top_y = int(h * 0.42)
    bottom_y = int(h * 0.86)
    rim_h = int(h * 0.08)
    
    top_w_half = int(w * 0.38)
    bottom_w_half = int(w * 0.26)
    cx = w // 2
    
    # 1. Soil mound inside pot
    soil_rect = [cx - top_w_half + 30, top_y - int(h * 0.04), cx + top_w_half - 30, top_y + int(h * 0.08)]
    draw.ellipse(soil_rect, fill=(58, 42, 32, 255))
    
    # 2. Main Pot Body (tapered trapezoid)
    body_points = [
        (cx - top_w_half + 25, top_y + rim_h),
        (cx + top_w_half - 25, top_y + rim_h),
        (cx + bottom_w_half, bottom_y),
        (cx - bottom_w_half, bottom_y)
    ]
    draw.polygon(body_points, fill=color_base)
    
    # Rounded base
    draw.chord([cx - bottom_w_half, bottom_y - 40, cx + bottom_w_half, bottom_y + 40], 0, 180, fill=color_base)
    
    # Optional pattern (e.g. cute dots on pot 6)
    if pattern == 'dots':
        p_draw = ImageDraw.Draw(im)
        dot_color = (196, 154, 69, 210)
        for row in range(5):
            y_dot = top_y + rim_h + 120 + row * 130
            cols = 6 if row % 2 == 0 else 5
            spacing = (top_w_half * 1.5) / cols
            start_x = cx - (top_w_half * 0.75) + (spacing / 2 if row % 2 == 1 else 0)
            for c in range(cols):
                x_dot = start_x + c * spacing
                if (cx - bottom_w_half + 40) < x_dot < (cx + bottom_w_half - 40):
                    p_draw.ellipse([x_dot - 16, y_dot - 16, x_dot + 16, y_dot + 16], fill=dot_color)

    # 3. Pot Rim (overlapping rounded bar at top)
    rim_rect = [cx - top_w_half - 15, top_y, cx + top_w_half + 15, top_y + rim_h]
    draw.rounded_rectangle(rim_rect, radius=36, fill=rim_color)
    
    # Rim shadow underneath
    draw.rectangle([cx - top_w_half + 25, top_y + rim_h, cx + top_w_half - 25, top_y + rim_h + 20], fill=(0, 0, 0, 45))
    
    # 4. Soft warm lighting gradient across body
    light_layer = Image.new('RGBA', size, (0, 0, 0, 0))
    l_draw = ImageDraw.Draw(light_layer)
    # Highlight on left side
    l_draw.ellipse([cx - top_w_half + 40, top_y + rim_h + 40, cx - int(top_w_half * 0.2), bottom_y - 60], fill=(255, 255, 255, 45))
    # Soft shadow on right side
    l_draw.ellipse([cx + int(top_w_half * 0.1), top_y + rim_h + 40, cx + top_w_half - 30, bottom_y - 40], fill=(0, 0, 0, 40))
    light_layer = light_layer.filter(ImageFilter.GaussianBlur(35))
    
    # Composite
    im = Image.alpha_composite(im, light_layer)
    
    # Add retro grain
    arr = np.array(im, dtype=float)
    noise = np.random.normal(0, 7, (h, w))
    alpha = arr[:, :, 3]
    for i in range(3):
        arr[:, :, i] = np.clip(arr[:, :, i] + noise, 0, 255)
    arr[:, :, 3] = alpha
    return Image.fromarray(arr.astype(np.uint8))

pots = [
    ('pot_1.png', (208, 112, 82, 255), (188, 96, 68, 255), None),          # Terracotta
    ('pot_2.png', (144, 164, 138, 255), (126, 145, 120, 255), None),       # Sage
    ('pot_3.png', (242, 208, 107, 255), (225, 190, 88, 255), None),       # Butter yellow
    ('pot_4.png', (232, 165, 152, 255), (218, 148, 134, 255), None),       # Blush pink
    ('pot_5.png', (127, 179, 213, 255), (108, 160, 194, 255), None),       # Sky blue
    ('pot_6.png', (246, 238, 221, 255), (232, 222, 202, 255), 'dots'),     # Cream with dots
]

for filename, bg, rim, pat in pots:
    p_img = draw_pot(bg, rim, pat)
    p_img.save(os.path.join('art/incoming', filename))
    print(f"Saved {filename}")

# Generate pit_in_soil.png and pit_crack.png
# Extract pit texture from pip_idle.png
idle_img = Image.open('art/incoming/pip_idle.png')
# Crop pit area from center
# pip is 2048x2048, pit is approx around (1024, 1120) with radius 280
pit_cx, pit_cy = 1030, 1115
pit_rad = 280
pit_crop = idle_img.crop((pit_cx - pit_rad, pit_cy - pit_rad, pit_cx + pit_rad, pit_cy + pit_rad))

def create_pit_in_soil(cracked=False):
    size = (2048, 2048)
    im = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    w, h = size
    cx, cy = w // 2, int(h * 0.44)
    
    # Soil base mound
    soil_w = int(w * 0.36)
    soil_h = int(h * 0.12)
    draw.ellipse([cx - soil_w, cy + 120, cx + soil_w, cy + 120 + soil_h * 2], fill=(52, 38, 28, 255))
    
    # Nestled pit
    pit_res = pit_crop.resize((int(pit_rad * 2.2), int(pit_rad * 2.2)), Image.Resampling.LANCZOS)
    pw, ph = pit_res.size
    im.paste(pit_res, (cx - pw // 2, cy - ph // 2 + 60), pit_res)
    
    # Fore-soil overlapping the lower 1/3 of the pit
    draw.chord([cx - soil_w + 30, cy + 160, cx + soil_w - 30, cy + 320], 0, 180, fill=(62, 45, 34, 255))
    
    if cracked:
        # Draw crack fissure and green sprout
        c_draw = ImageDraw.Draw(im)
        crack_points = [
            (cx, cy - 140),
            (cx - 15, cy - 70),
            (cx + 25, cy),
            (cx - 10, cy + 70),
            (cx + 10, cy + 150)
        ]
        c_draw.line(crack_points, fill=(40, 25, 15, 255), width=14)
        c_draw.line([(cx, cy - 140), (cx + 35, cy - 90)], fill=(40, 25, 15, 255), width=10)
        
        # Tiny bright avocado sprout with two leaves
        sprout_base = (cx, cy - 140)
        # Stem
        c_draw.line([(cx, cy - 140), (cx - 10, cy - 240), (cx, cy - 320)], fill=(120, 186, 54, 255), width=22)
        # Left leaf
        c_draw.ellipse([cx - 90, cy - 360, cx - 10, cy - 290], fill=(136, 202, 64, 255))
        # Right leaf
        c_draw.ellipse([cx + 5, cy - 390, cx + 95, cy - 310], fill=(154, 218, 76, 255))
        
    return im

pit_img = create_pit_in_soil(cracked=False)
pit_img.save('art/incoming/pit_in_soil.png')
print("Saved pit_in_soil.png")

crack_img = create_pit_in_soil(cracked=True)
crack_img.save('art/incoming/pit_crack.png')
print("Saved pit_crack.png")

# Generate 512x512 icons (seed, fuel, streak)
def draw_seed_icon():
    im = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Golden teardrop seed
    d.polygon([(256, 70), (370, 250), (330, 410), (182, 410), (142, 250)], fill=(245, 192, 50, 255))
    d.ellipse([160, 240, 352, 420], fill=(235, 178, 38, 255))
    # Shiny highlight
    d.ellipse([190, 160, 240, 280], fill=(255, 240, 160, 180))
    return add_grain(im, 8)

def draw_fuel_icon():
    im = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Vibrant energy leaf
    d.chord([120, 100, 392, 412], 45, 225, fill=(64, 185, 100, 255))
    d.chord([120, 100, 392, 412], 225, 45, fill=(84, 205, 120, 255))
    d.line([(160, 360), (352, 150)], fill=(220, 255, 230, 200), width=12)
    return add_grain(im, 8)

def draw_streak_icon():
    im = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # Sprouting flame
    d.ellipse([170, 210, 342, 430], fill=(242, 130, 48, 255))
    d.polygon([(256, 60), (342, 250), (170, 250)], fill=(255, 175, 55, 255))
    d.ellipse([216, 260, 296, 380], fill=(255, 225, 120, 255))
    # Sprout on top
    d.ellipse([200, 70, 256, 120], fill=(120, 195, 60, 255))
    d.ellipse([256, 60, 312, 110], fill=(140, 215, 80, 255))
    return add_grain(im, 8)

draw_seed_icon().save('art/incoming/icon_seed.png')
print("Saved icon_seed.png")
draw_fuel_icon().save('art/incoming/icon_fuel.png')
print("Saved icon_fuel.png")
draw_streak_icon().save('art/incoming/icon_streak.png')
print("Saved icon_streak.png")
