from pathlib import Path
import subprocess


ROOT_DIR = Path(__file__).resolve().parent.parent
PYTHON_EXE = ROOT_DIR / "tools" / "rapidocr" / "python" / "python.exe"
RUNNER_PATH = ROOT_DIR / "lib" / "rapidocr_runner.py"
SAMPLE_IMAGE = (
    ROOT_DIR
    / "tools"
    / "rapidocr"
    / "models"
    / "required_for_whl_v1.1.0"
    / "test_images"
    / "single_line_text.jpg"
)
OUTPUT_PATH = ROOT_DIR / "logs" / "rapidocr_runner_regression.txt"


def main() -> int:
    if not PYTHON_EXE.exists():
        raise FileNotFoundError(f"Missing bundled Python: {PYTHON_EXE}")
    if not RUNNER_PATH.exists():
        raise FileNotFoundError(f"Missing runner script: {RUNNER_PATH}")
    if not SAMPLE_IMAGE.exists():
        raise FileNotFoundError(f"Missing sample image: {SAMPLE_IMAGE}")

    if OUTPUT_PATH.exists():
        OUTPUT_PATH.unlink()

    result = subprocess.run(
        [
            str(PYTHON_EXE),
            str(RUNNER_PATH),
            "--image-path",
            str(SAMPLE_IMAGE),
            "--output-path",
            str(OUTPUT_PATH),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        cwd=str(ROOT_DIR),
        check=False,
    )

    if result.returncode != 0:
        raise RuntimeError(
            "rapidocr_runner.py should accept --image-path regression input.\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )

    if not OUTPUT_PATH.exists():
        raise RuntimeError("rapidocr_runner.py did not create the output file")

    payload = OUTPUT_PATH.read_text(encoding="utf-8")
    if "STATUS=OK" not in payload:
        raise RuntimeError(f"Expected STATUS=OK in runner output, got:\n{payload}")
    if "儿童文学" not in payload:
        raise RuntimeError(f"Expected recognized sample text in runner output, got:\n{payload}")

    print("RUNNER_OUTPUT=" + payload.replace("\n", " | "))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
