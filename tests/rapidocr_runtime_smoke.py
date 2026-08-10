from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent.parent
MODEL_DIR = ROOT_DIR / "tools" / "rapidocr" / "models" / "required_for_whl_v1.1.0" / "resources" / "models"
DET_MODEL_PATH = MODEL_DIR / "ch_PP-OCRv3_det_infer.onnx"
CLS_MODEL_PATH = MODEL_DIR / "ch_ppocr_mobile_v2.0_cls_infer.onnx"
REC_MODEL_PATH = MODEL_DIR / "ch_PP-OCRv3_rec_infer.onnx"
SAMPLE_IMAGE = ROOT_DIR / "tools" / "rapidocr" / "models" / "required_for_whl_v1.1.0" / "test_images" / "single_line_text.jpg"


def main() -> int:
    for model_path in (DET_MODEL_PATH, CLS_MODEL_PATH, REC_MODEL_PATH):
        if not model_path.exists():
            raise FileNotFoundError(f"Missing RapidOCR model: {model_path}")
    if not SAMPLE_IMAGE.exists():
        raise FileNotFoundError(f"Missing RapidOCR sample image: {SAMPLE_IMAGE}")

    import cv2
    from rapidocr_onnxruntime import RapidOCR

    image = cv2.imread(str(SAMPLE_IMAGE))
    if image is None:
        raise RuntimeError(f"Failed to load sample image: {SAMPLE_IMAGE}")

    engine = RapidOCR(
        det_model_path=str(DET_MODEL_PATH),
        cls_model_path=str(CLS_MODEL_PATH),
        rec_model_path=str(REC_MODEL_PATH),
    )
    ocr_res, _ = engine(image)
    texts = []
    for item in ocr_res or []:
        if isinstance(item, (list, tuple)) and len(item) > 1:
            text = str(item[1]).strip()
            if text:
                texts.append(text)

    if not texts:
        raise RuntimeError("RapidOCR smoke test produced no text")

    print("OCR_TEXT=" + " | ".join(texts))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
