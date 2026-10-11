from PIL import Image, ImageDraw, ImageFilter
import numpy as np

# Load original full image to get the pristine headband
src_path = '/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/avocado_fitness_ref_1789890477558.jpg'
src_img = Image.open(src_path).convert('RGB')
src_arr = np.array(src_img)

body = Image.open('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/master_body.png').convert('RGBA')
arr_b = np.array(body)
h, w, _ = arr_b.shape

# Let's inspect the headband on arr_b (y between 70 and 160)
# Restore the headband outline:
# In full image, headband spans x: 315 to 709, y: 178 to 275
# In body_crop, x is offset by bx0=234, y by by0=105
# Let's check where the headband is
for y in range(70, 160):
    for x in range(w):
        # If in headband x range (x between 80 and 475)
        # Restore alpha = 255 if it's the headband in src_arr
        sy = y + 105
        sx = x + 234
        if 0 <= sy < 1024 and 0 <= sx < 1024:
            # Check if source pixel is not white background
            if np.linalg.norm(src_arr[sy, sx] - [255, 255, 255]) > 25:
                arr_b[y, x, :3] = src_arr[sy, sx]
                arr_b[y, x, 3] = 255

clean_body = Image.fromarray(arr_b, 'RGBA')
clean_body.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/master_body.png')

# 2. Perfect Eyelids (cover the entire eye highlight 100%)
eyelids = Image.new('RGBA', (w, h), (0, 0, 0, 0))
draw_el = ImageDraw.Draw(eyelids)

lex, ley = 202, 270
rex, rey = 350, 270
# Larger radius to cover all highlights cleanly
rx, ry = 48, 58
flesh_color = (234, 235, 160, 255)
line_color = (35, 60, 21, 255)

# Fill eye ovals with avocado flesh
draw_el.ellipse([lex - rx, ley - ry, lex + rx, ley + ry], fill=flesh_color)
draw_el.ellipse([rex - rx, rey - ry, rex + rx, rey + ry], fill=flesh_color)

# Draw smiling closed arcs: ⌒ ⌒
arc_rx, arc_ry = 38, 24
draw_el.arc([lex - arc_rx, ley - arc_ry - 2, lex + arc_rx, ley + arc_ry - 2], start=195, end=345, fill=line_color, width=9)
draw_el.arc([rex - arc_rx, rey - arc_ry - 2, rex + arc_rx, rey + arc_ry - 2], start=195, end=345, fill=line_color, width=9)

eyelids_clean = eyelids.filter(ImageFilter.GaussianBlur(radius=0.5))
eyelids_clean.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/master_eyelids.png')

# Test composite preview
comp = Image.alpha_composite(clean_body, eyelids_clean)
comp.save('/Users/elischafer/.gemini/antigravity/brain/ded4d698-075e-4a93-b9be-6b76e35655aa/scratch/test_blinking_polished.png')
print("Polished successfully!")

