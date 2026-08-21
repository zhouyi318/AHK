"""
传奇私服坐标模板匹配读取器

预处理方案（与 coord_template_capture.py 完全一致）：
- HSV V通道 >= 150：文字亮核心，用于行检测和列投影分割
- 先找文本行（排除全亮边框行和空背景行），再在文本行内按零列分割字符
- 模板和匹配均使用灰度V通道裁剪，TM_CCOEFF_NORMED 归一化亮度差异

输出格式兼容 rapidocr_runner.py。
"""

import argparse
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = ROOT_DIR / "assets" / "coord_templates"


def write_result(output_path: Path, status: str, text: str = "", error_text: str = "") -> None:
    lines = [f"STATUS={status}"]
    if error_text:
        lines.append(f"ERROR={error_text}")
    lines.append("TEXT_BEGIN")
    if text:
        lines.extend(text.splitlines())
    lines.append("TEXT_END")
    payload = "\n".join(lines)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(payload, encoding="utf-8")
    print(payload)


def capture_region(x, y, width, height):
    from PIL import ImageGrab
    import numpy as np
    image = ImageGrab.grab(bbox=(x, y, x + width, y + height))
    rgb = np.array(image)
    if rgb.ndim == 2:
        return rgb
    return rgb[:, :, ::-1]


def load_templates():
    """Load available templates (grayscale V-channel crops).

    Partial templates are allowed: missing digits will be reported as '?'.
    Requires at least colon.png and one digit.
    """
    import cv2

    colon_path = TEMPLATE_DIR / "colon.png"
    if not colon_path.exists():
        raise FileNotFoundError(f"Template not found: {colon_path}. Run coord_template_capture.py first.")

    templates = {}
    for i in range(10):
        path = TEMPLATE_DIR / f"{i}.png"
        if path.exists():
            tmpl = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
            if tmpl is not None:
                templates[str(i)] = tmpl

    if not templates:
        raise FileNotFoundError("No digit templates found. Run coord_template_capture.py first.")

    colon = cv2.imread(str(colon_path), cv2.IMREAD_GRAYSCALE)
    if colon is None:
        raise RuntimeError("Failed to load colon.png")
    templates[":"] = colon

    return templates


def preprocess_and_split(screenshot):
    """Identical preprocessing as coord_template_capture.py.

    Bright core (V>=150) within detected text rows; split at zero columns.
    Returns list of (grayscale_crop, x1, x2) tuples.
    """
    import cv2
    import numpy as np

    if screenshot.ndim == 3:
        hsv = cv2.cvtColor(screenshot, cv2.COLOR_BGR2HSV)
    else:
        bgr = cv2.cvtColor(screenshot, cv2.COLOR_GRAY2BGR)
        hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)

    v = hsv[:, :, 2]
    h_img, w_img = v.shape

    bright = (v >= 150).astype(np.uint8)

    row_proj = np.sum(bright, axis=1)
    text_rows = [y for y in range(h_img) if 3 <= row_proj[y] <= w_img * 0.6]
    if not text_rows:
        return [], bright, (0, h_img)
    y1 = max(0, min(text_rows) - 1)
    y2 = min(h_img, max(text_rows) + 2)

    col_proj = np.sum(bright[y1:y2, :], axis=0)

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

    char_regions = [(a, b) for a, b in char_regions if b - a >= 2]

    char_regions = split_wide_segments(char_regions, col_proj)

    segments = [(v[y1:y2, a:b], a, b) for a, b in char_regions]

    return segments, bright, (y1, y2)


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
        if min_val > 3:
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


def resize_template_to_height(tmpl, target_h):
    """Resize template to target height preserving aspect ratio."""
    import cv2
    th, tw = tmpl.shape
    if th == target_h:
        return tmpl
    scale = target_h / th
    new_w = max(1, int(round(tw * scale)))
    return cv2.resize(tmpl, (new_w, target_h), interpolation=cv2.INTER_LINEAR)


def match_segment(seg, templates, min_score=0.3, top_n=0):
    """Match a single grayscale character segment against grayscale templates.
    Uses TM_CCOEFF_NORMED which normalizes brightness/contrast differences.
    Returns (best_char, best_score). If top_n>0, also returns sorted candidate list.
    """
    import cv2
    import numpy as np

    sh, sw = seg.shape
    if sh < 2 or sw < 2:
        return ("?", 0.0, []) if top_n else ("?", 0.0)

    candidates = []
    for char, tmpl in templates.items():
        th, tw = tmpl.shape
        # Scale template to match segment height
        scaled = resize_template_to_height(tmpl, sh)
        sth, stw = scaled.shape

        if stw > sw:
            # Template wider than segment after scaling — scale down by width
            scale = sw / stw
            new_h = max(1, int(round(sh * scale)))
            scaled = cv2.resize(scaled, (sw, new_h), interpolation=cv2.INTER_LINEAR)
            sth, stw = scaled.shape

        if sth > sh or stw > sw:
            continue

        result = cv2.matchTemplate(seg, scaled, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, _ = cv2.minMaxLoc(result)
        candidates.append((char, float(max_val)))

    if not candidates:
        return ("?", 0.0, []) if top_n else ("?", 0.0)

    candidates.sort(key=lambda c: c[1], reverse=True)
    best_char, best_score = candidates[0]

    if top_n:
        return best_char, best_score, candidates[:top_n]
    return best_char, best_score


def read_coordinates(screenshot, templates):
    """Read coordinates from screenshot."""
    import cv2
    import numpy as np

    segments, bright_mask, row_range = preprocess_and_split(screenshot)

    print(f"Found {len(segments)} character segments")
    for i, (seg, x1, x2) in enumerate(segments):
        print(f"  Seg {i}: x=[{x1}:{x2}] size={seg.shape}")

    if not segments:
        return ""

    # First pass: try to find colon among segments
    colon_idx = None
    colon_score = 0
    for i, (seg, x1, x2) in enumerate(segments):
        ch, score = match_segment(seg, {":": templates[":"]}, min_score=0.0)
        if ch == ":" and score > colon_score:
            colon_score = score
            colon_idx = i

    chars = []
    scores = []
    for i, (seg, x1, x2) in enumerate(segments):
        if colon_idx is not None and i == colon_idx and colon_score > 0.3:
            chars.append(":")
            scores.append(colon_score)
        else:
            ch, score = match_segment(seg, {c: t for c, t in templates.items() if c != ":"})
            chars.append(ch)
            scores.append(score)

    text = "".join(chars)
    score_str = [f"{s:.2f}" for s in scores]
    print(f"Match result: '{text}' scores={score_str}")
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description="Read game coordinates using template matching")
    parser.add_argument("--x", type=int, required=True)
    parser.add_argument("--y", type=int, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--output-path", required=True)
    parser.add_argument("--min-score", type=float, default=0.3)
    parser.add_argument("--save-capture-on-empty", action="store_true",
                        help="Save the captured region to logs/coord_debug_capture.png when no coordinate is matched")
    args = parser.parse_args()
    output_path = Path(args.output_path)

    try:
        templates = load_templates()
        print(f"Loaded {len(templates)} templates")
        for c, t in sorted(templates.items()):
            print(f"  '{c}': {t.shape}")

        screenshot = capture_region(args.x, args.y, args.width, args.height)
        print(f"Captured: {screenshot.shape}")

        text = read_coordinates(screenshot, templates)
        print(f"Result: '{text}'")

        if not text and args.save_capture_on_empty:
            try:
                import cv2
                debug_path = ROOT_DIR / "logs" / "coord_debug_capture.png"
                cv2.imwrite(str(debug_path), screenshot)
                print(f"Debug capture saved: {debug_path}")
            except Exception as save_exc:
                print(f"Failed to save debug capture: {save_exc}")

        if text:
            write_result(output_path, "OK", text=text)
        else:
            write_result(output_path, "OK", text="")
        return 0

    except FileNotFoundError as e:
        write_result(output_path, "ERROR", error_text=str(e))
        return 1
    except Exception as exc:
        import traceback
        traceback.print_exc()
        write_result(output_path, "ERROR", error_text=str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())