from PIL import Image, ImageDraw, ImageFilter
import numpy as np

body = Image.open('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_body_v2.png').convert('RGBA')
arr = np.array(body)
h, w, _ = arr.shape

# Eyes in body_crop coordinates:
# Let's find the exact dark eye pixels:
# Left eye around x: 140 to 220, y: 150 to 230
# Right eye around x: 270 to 350, y: 150 to 230

# Let's inspect the exact eye centers:
left_eye_box = arr[150:230, 140:220]
right_eye_box = arr[150:230, 270:350]

# Detect non-flesh (dark eye + white glint)
# Flesh is around [220..245, 230..250, 140..175]
# Glint has B > 200, dark eye has R < 100
is_left_eye = (arr[150:230, 140:220, 0] < 120) | (arr[150:230, 140:220, 2] > 190)
is_right_eye = (arr[150:230, 270:350, 0] < 120) | (arr[150:230, 270:350, 2] > 190)

# Centers
yl, xl = np.where(is_left_eye)
yr, xr = np.where(is_right_eye)
lex, ley = int(140 + np.mean(xl)), int(150 + np.mean(yl))
rex, rey = int(270 + np.mean(xr)), int(150 + np.mean(yr))
print(f"Left eye center: ({lex}, {ley}), Right eye center: ({rex}, {rey})")

# Sample surrounding flesh color: average of pixels 45px away from eye center
flesh_samples = []
for angle in np.linspace(0, 2*np.pi, 24):
    for r in [42, 45, 48]:
        sx = int(lex + r * np.cos(angle))
        sy = int(ley + r * np.sin(angle))
        if 0 <= sy < h and 0 <= sx < w:
            flesh_samples.append(arr[sy, sx, :3])
avg_flesh = np.mean(flesh_samples, axis=0).astype(np.uint8)
print("Surrounding flesh RGB:", avg_flesh)

# Create clean eyelids overlay
eyelids = Image.new('RGBA', (w, h), (0, 0, 0, 0))
draw = ImageDraw.Draw(eyelids)

# Draw flesh-colored smooth oval over each eye
# Eye size is approx w: 56, h: 62
rw, rh = 28, 30
flesh_rgba = (int(avg_flesh[0]), int(avg_flesh[1]), int(avg_flesh[2]), 255)
line_rgba = (35, 60, 21, 255)

draw.ellipse([lex - rw, ley - rh, lex + rw, ley + rh], fill=flesh_rgba)
draw.ellipse([rex - rw, rey - rh, rex + rw, rey + rh], fill=flesh_rgba)

# Draw smiling closed eyelids: ⌒  ⌒
arc_w, arc_h = 44, 26
draw.arc([lex - arc_w//2, ley - arc_h//2 - 2, lex + arc_w//2, ley + arc_h//2 - 2], start=195, end=345, fill=line_rgba, width=7)
draw.arc([rex - arc_w//2, rey - arc_h//2 - 2, rex + arc_w//2, rey + arc_h//2 - 2], start=195, end=345, fill=line_rgba, width=7)

# Slight blur on the edge of the eyelids for seamless blending
eyelids_clean = eyelids.filter(ImageFilter.GaussianBlur(radius=0.4))
eyelids_clean.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/avo_eyelids_v3.png')

# Test composite
comp = Image.alpha_composite(body, eyelids_clean)
comp.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/test_blinking_body_v3.png')
print("Saved test_blinking_body_v3.png")

