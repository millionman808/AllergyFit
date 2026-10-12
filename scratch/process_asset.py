import sys
from PIL import Image
import numpy as np

def key_magenta_and_save(src_path, dst_path, target_size=(2048, 2048)):
    img = Image.open(src_path).convert('RGBA')
    arr = np.array(img, dtype=float)
    
    # Magenta threshold: R and B are high, G is low
    diff_rg = arr[:, :, 0] - arr[:, :, 1]
    diff_bg = arr[:, :, 2] - arr[:, :, 1]
    is_magenta = (diff_rg > 75) & (diff_bg > 75) & (arr[:, :, 1] < 110)
    
    alpha = np.where(is_magenta, 0, 255).astype(np.uint8)
    
    # Also clean any slight magenta edge spill
    rgb = arr[:, :, :3].astype(np.uint8)
    res = Image.fromarray(np.dstack([rgb, alpha]))
    
    if target_size:
        res = res.resize(target_size, Image.Resampling.LANCZOS)
    
    res.save(dst_path)
    print(f"Processed and saved {dst_path} {res.size}")

if __name__ == "__main__":
    if len(sys.argv) >= 3:
        key_magenta_and_save(sys.argv[1], sys.argv[2])
