"""
传奇私服坐标数字模板截取工具

核心改进：利用V通道（亮度）投影分割字符，而不是等宽分割。
- V>130 高亮度像素用于找字符边界（文字核心+亮描边）
- V>80 提取完整字符形状（包含彩色描边暗部）
- 形态学闭运算连接断裂像素

用法：
  python coord_template_capture.py --x 100 --y 200 --width 80 --height 20 --label "340:334"
"""

import argparse
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = ROOT_DIR / "assets" / "coord_templates"


def capture_region(x: int, y: int, width: int, height: int):
    from PIL import ImageGrab
    image = ImageGrab.grab(bbox=(x, y, x + width, y + height))
    return image


def preprocess_and_split(image):
    """Preprocess screenshot and split into individual character segments.

    Algorithm (robust for colored-glow game font):
    1. Use HSV V channel; bright core pixels (V>=150) mark text.
    2. Find text rows (exclude full-bright border rows and empty bg rows).
    3. Project bright pixels WITHIN text rows; split at zero columns.
    4. Crop grayscale V channel per character for template/matching.

    Returns (char_crops, debug_mask, text_row_range).
    """
    import cv2
    import numpy as np

    arr = np.array(image)
    if arr.ndim == 3:
        bgr = cv2.cvtColor(arr, cv2.COLOR_RGB2BGR)
        hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    else:
        gray = arr
        hsv = cv2.cvtColor(cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR), cv2.COLOR_BGR2HSV)

    v = hsv[:, :, 2]
    h_img, w_img = v.shape

    bright = (v >= 150).astype(np.uint8)

    # Text rows: rows with a moderate number of bright pixels
    # (border rows are nearly all-bright; background rows are nearly empty)
    row_proj = np.sum(bright, axis=1)
    text_rows = [y for y in range(h_img) if 3 <= row_proj[y] <= w_img * 0.6]
    if not text_rows:
        return [], bright, (0, h_img)
    y1 = max(0, min(text_rows) - 1)
    y2 = min(h_img, max(text_rows) + 2)

    # Column projection within text rows
    col_proj = np.sum(bright[y1:y2, :], axis=0)

    # Split at zero columns (any gap separates characters)
    char_regions = []
    in_char = False
    for x in range(w_img):
        if col_proj[x] >= 1:
            if not in_char:
                in_char = True
                char_start = x
        else:
            if in_char:
                char_regions.append((char_start, x))
                in_char = False
    if in_char:
        char_regions.append((char_start, w_img))

    # Drop noise segments narrower than 2px
    char_regions = [(a, b) for a, b in char_regions if b - a >= 2]

    # Secondary split: touching characters (no zero column between them)
    # produce over-wide segments; split them at the projection valley.
    char_regions = split_wide_segments(char_regions, col_proj)

    # Grayscale V crops (NOT binarized) for robust matching
    char_crops = [v[y1:y2, a:b] for a, b in char_regions]

    return char_crops, bright, (y1, y2)


def split_wide_segments(char_regions, col_proj, max_ratio=1.6):
    """Split segments that are much wider than the median character width."""
    widths = sorted(b - a for a, b in char_regions if b - a >= 3)
    if not widths:
        return char_regions
    median = widths[len(widths) // 2]

    def split_one(a, b):
        w = b - a
        if w <= max_ratio * median:
            return [(a, b)]
        lo, hi = a + w // 4, b - w // 4
        if hi <= lo:
            return [(a, b)]
        min_val = min(col_proj[x] for x in range(lo, hi + 1))
        if min_val > 3:  # no clear valley -> likely a single wide glyph
            return [(a, b)]
        valley = [x for x in range(lo, hi + 1) if col_proj[x] == min_val]
        mid = valley[len(valley) // 2]
        left = split_one(a, mid)
        right = split_one(mid, b)
        return [p for p in left + right if p[1] - p[0] >= 2]

    out = []
    for a, b in char_regions:
        out.extend(split_one(a, b))
    return out


def auto_capture(args):
    """Auto mode: capture region, split characters by projection, save templates."""
    import cv2
    import numpy as np

    print(f"Capturing screen region: ({args.x}, {args.y}) {args.width}x{args.height}")
    image = capture_region(args.x, args.y, args.width, args.height)

    TEMPLATE_DIR.mkdir(parents=True, exist_ok=True)
    ref_path = TEMPLATE_DIR / "_capture_ref.png"
    image.save(str(ref_path))
    print(f"Reference saved: {ref_path}")

    chars = list(args.label)
    n_expected = len(chars)

    char_crops, bright_mask, row_range = preprocess_and_split(image)
    n_found = len(char_crops)

    print(f"Label: '{args.label}' ({n_expected} chars), detected: {n_found} chars")

    # Save debug mask
    cv2.imwrite(str(TEMPLATE_DIR / "_debug_bright.png"), bright_mask)

    # Abort if split count doesn't match label (avoid saving wrong templates)
    if n_found != n_expected:
        err = (f"分割数量不匹配: 检测到 {n_found} 个字符，期望 {n_expected} 个（标签 '{args.label}'）。"
               f"请重新框选，只框住坐标数字本身，不要包含边框或多余背景。")
        print(f"ERROR: {err}")
        (TEMPLATE_DIR / "_capture_error.txt").write_text(err, encoding="utf-8-sig")
        return 1
    # Clear stale error file on success
    err_file = TEMPLATE_DIR / "_capture_error.txt"
    if err_file.exists():
        err_file.unlink()

    # Save each character template (grayscale V channel)
    saved = set()
    for i, (ch, crop) in enumerate(zip(chars, char_crops)):
        safe_name = ch.replace(":", "colon")
        path = TEMPLATE_DIR / f"{safe_name}.png"
        cv2.imwrite(str(path), crop)
        print(f"  [{i+1}/{n_expected}] '{ch}' -> {safe_name}.png ({crop.shape[1]}x{crop.shape[0]})")
        saved.add(safe_name)

    print(f"\nSaved {len(saved)} unique templates to {TEMPLATE_DIR}")

    missing = set(str(i) for i in range(10)) - saved
    if "colon" not in saved:
        missing.add("colon")
    if missing:
        print(f"Missing: {sorted(missing)}")
        print("Capture another coordinate to fill in missing digits.")
    else:
        print("All 10 digits + colon captured!")

    return 0


def manual_capture(args):
    """Manual mode: just save the raw capture."""
    print(f"Capturing: ({args.x}, {args.y}) {args.width}x{args.height}")
    image = capture_region(args.x, args.y, args.width, args.height)
    TEMPLATE_DIR.mkdir(parents=True, exist_ok=True)
    path = TEMPLATE_DIR / "_manual_capture.png"
    image.save(str(path))
    print(f"Saved: {path}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Capture coordinate digit templates")
    parser.add_argument("--x", type=int, required=True)
    parser.add_argument("--y", type=int, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--label", help="Known coordinate text, e.g. '340:334'")
    parser.add_argument("--manual", action="store_true")
    args = parser.parse_args()

    if args.manual:
        return manual_capture(args)
    elif args.label:
        return auto_capture(args)
    else:
        print("ERROR: --label or --manual required")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())