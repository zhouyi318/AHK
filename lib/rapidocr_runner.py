import argparse
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent
MODEL_BUNDLE_DIR = ROOT_DIR / "tools" / "rapidocr" / "models" / "required_for_whl_v1.1.0"
DET_MODEL_PATH = MODEL_BUNDLE_DIR / "resources" / "models" / "ch_PP-OCRv3_det_infer.onnx"
CLS_MODEL_PATH = MODEL_BUNDLE_DIR / "resources" / "models" / "ch_ppocr_mobile_v2.0_cls_infer.onnx"
REC_MODEL_PATH = MODEL_BUNDLE_DIR / "resources" / "models" / "ch_PP-OCRv3_rec_infer.onnx"

_ENGINE = None


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


def get_engine():
    global _ENGINE
    if _ENGINE is not None:
        return _ENGINE

    for model_path in (DET_MODEL_PATH, CLS_MODEL_PATH, REC_MODEL_PATH):
        if not model_path.exists():
            raise FileNotFoundError(f"RapidOCR model not found: {model_path}")

    from rapidocr_onnxruntime import RapidOCR

    _ENGINE = RapidOCR(
        det_model_path=str(DET_MODEL_PATH),
        cls_model_path=str(CLS_MODEL_PATH),
        rec_model_path=str(REC_MODEL_PATH),
    )
    return _ENGINE


def capture_region(x: int, y: int, width: int, height: int):
    from PIL import ImageGrab
    import numpy as np

    image = ImageGrab.grab(bbox=(x, y, x + width, y + height))
    rgb = np.array(image)
    if rgb.ndim == 2:
        return rgb
    return rgb[:, :, ::-1]


def load_image(image_path: Path):
    import cv2

    image = cv2.imread(str(image_path))
    if image is None:
        raise RuntimeError(f"Failed to load image: {image_path}")
    return image


def flatten_text(ocr_res) -> str:
    texts = []
    for item in ocr_res or []:
        text = ""
        if isinstance(item, (list, tuple)) and len(item) > 1:
            text = str(item[1])
        elif hasattr(item, "text"):
            text = str(item.text)
        if text.strip():
            texts.append(text.strip())
    return "\n".join(texts)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--x", type=int)
    parser.add_argument("--y", type=int)
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--image-path")
    parser.add_argument("--output-path", required=True)
    args = parser.parse_args()

    output_path = Path(args.output_path)

    try:
        if args.image_path:
            image = load_image(Path(args.image_path))
        else:
            if None in (args.x, args.y, args.width, args.height):
                raise ValueError("x/y/width/height are required when image-path is not provided")
            if args.width <= 0 or args.height <= 0:
                raise ValueError("width/height must be positive")
            image = capture_region(args.x, args.y, args.width, args.height)
        engine = get_engine()
        ocr_res, _ = engine(image)
        text = flatten_text(ocr_res)
        write_result(output_path, "OK", text=text)
        return 0
    except Exception as exc:
        write_result(output_path, "ERROR", error_text=str(exc))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
