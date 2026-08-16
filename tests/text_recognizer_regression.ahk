#Requires AutoHotkey v2.0

#Include ..\lib\TextRecognizer.ahk

WriteStatus(exitCode) {
    if (A_Args.Length < 1)
        return
    statusPath := A_Args[1]
    try {
        if FileExist(statusPath)
            FileDelete(statusPath)
    }
    FileAppend("EXIT=" exitCode, statusPath, "UTF-8")
}

WriteFailure(message) {
    if (A_Args.Length < 1)
        return
    statusPath := A_Args[1]
    FileAppend("`nFAIL=" message, statusPath, "UTF-8")
}

class FakeLogger {
    __New() {
        this.messages := []
    }

    Info(msg) {
        this.messages.Push("INFO:" msg)
    }

    Warn(msg) {
        this.messages.Push("WARN:" msg)
    }

    Error(msg) {
        this.messages.Push("ERROR:" msg)
    }
}

class FakeRunner {
    __New(output) {
        this.output := output
        this.calls := []
    }

    Call(commandLine, outputPath) {
        this.calls.Push({commandLine: commandLine, outputPath: outputPath})
        return this.output
    }
}

class FakeExecutor {
    __New(output) {
        this.output := output
        this.calls := []
    }

    Call(commandLine, outputPath) {
        this.calls.Push({commandLine: commandLine, outputPath: outputPath})
        FileAppend this.output, outputPath, "UTF-8"
        return ""
    }
}

try {
    logger := FakeLogger()
    runner := FakeRunner(
        "STATUS=OK`n"
        . "TEXT_BEGIN`n"
        . "快 速`n"
        . "开始`n"
        . "TEXT_END`n"
    )
    ocr := TextRecognizer(logger, runner.Call.Bind(runner))
    expectedRoot := RegExReplace(A_ScriptDir, "\\tests$", "")
    if (ocr.rootDir != expectedRoot)
        throw Error("TextRecognizer should default rootDir to the project root for included test scripts")

    probeGui := Gui(, "Text Recognizer Regression")
    probeGui.Show("x200 y220 w240 h180")
    hwnd := probeGui.Hwnd

    region := {x1: 10, y1: 20, x2: 110, y2: 120}
    result := ocr.Recognize(hwnd, region, "快速开始", "手动 OCR 测试")

    if !result.ok
        throw Error("Recognize should succeed for STATUS=OK output")
    if (result.text != "快 速`n开始")
        throw Error("Recognize should preserve OCR text body")
    if !result.matched
        throw Error("Recognize should match target text after whitespace normalization")
    if (runner.calls.Length != 1)
        throw Error("Recognize should invoke the runner exactly once")
    expectedRect := ocr.ResolveScreenRect(hwnd, region)
    if !expectedRect
        throw Error("Recognize regression should resolve a valid screen rect for the probe window")
    activeBackend := ocr.ResolveBackend()
    if (activeBackend.name = "rapidocr") {
        if !InStr(runner.calls[1].commandLine, "--x " expectedRect.x) || !InStr(runner.calls[1].commandLine, "--y " expectedRect.y) || !InStr(runner.calls[1].commandLine, "--width " expectedRect.width) || !InStr(runner.calls[1].commandLine, "--height " expectedRect.height)
            throw Error("Recognize should pass normalized region bounds to the RapidOCR runner")
    } else if (activeBackend.name = "winrt") {
        if !InStr(runner.calls[1].commandLine, "-X " expectedRect.x) || !InStr(runner.calls[1].commandLine, "-Y " expectedRect.y) || !InStr(runner.calls[1].commandLine, "-Width " expectedRect.width) || !InStr(runner.calls[1].commandLine, "-Height " expectedRect.height)
            throw Error("Recognize should pass normalized region bounds to the WinRT helper script")
    } else {
        throw Error("Recognize should resolve a concrete OCR backend before building the command")
    }
    if (runner.calls[1].outputPath = "")
        throw Error("Recognize should provide an output path to the runner")

    preprocessRunner := FakeRunner(
        "STATUS=OK`n"
        . "TEXT_BEGIN`n"
        . "331333`n"
        . "TEXT_END`n"
    )
    preprocessOcr := TextRecognizer(logger, preprocessRunner.Call.Bind(preprocessRunner))
    preprocessResult := preprocessOcr.Recognize(hwnd, region, "", "坐标预处理测试", true)
    if !preprocessResult.ok
        throw Error("Recognize should still succeed when OCR preprocessing is enabled")
    preprocessBackend := preprocessOcr.ResolveBackend()
    if (preprocessBackend.name = "rapidocr") {
        if !InStr(preprocessRunner.calls[1].commandLine, "--preprocess")
            throw Error("Recognize should enable --preprocess for RapidOCR when requested")
    } else if InStr(preprocessRunner.calls[1].commandLine, "--preprocess") {
        throw Error("Recognize should not pass RapidOCR-specific preprocess flags to WinRT backend")
    }

    executor := FakeExecutor(
        "STATUS=OK`n"
        . "TEXT_BEGIN`n"
        . "快 速`n"
        . "开始`n"
        . "TEXT_END`n"
    )
    execOcr := TextRecognizer(logger, "", expectedRoot, executor.Call.Bind(executor))
    execResult := execOcr.Recognize(hwnd, region, "快速开始", "隐藏执行测试")
    if !execResult.ok
        throw Error("Recognize should succeed when using the injected external executor")
    if (executor.calls.Length != 1)
        throw Error("Recognize should invoke the injected external executor exactly once")
    if (execResult.text != "快 速`n开始")
        throw Error("Recognize should read OCR text from the executor output file")

    emptyRunner := FakeRunner(
        "STATUS=OK`n"
        . "TEXT_BEGIN`n"
        . "TEXT_END`n"
    )
    emptyOcr := TextRecognizer(logger, emptyRunner.Call.Bind(emptyRunner))
    emptyResult := emptyOcr.Recognize(hwnd, region, "快速开始", "空结果 OCR 测试")
    if !emptyResult.ok
        throw Error("Recognize should still treat empty OCR output as a successful OCR call")
    if (emptyResult.reason != "NO_TEXT")
        throw Error("Recognize should classify empty OCR output as NO_TEXT")
    if emptyResult.matched
        throw Error("Recognize should not match when OCR returned no text")
    if (ocr.BuildDisplayText("识别文本") != "识别文本")
        throw Error("BuildDisplayText should preserve non-empty text")
    if (ocr.BuildDisplayText("") != "(OCR 未识别到文本)")
        throw Error("BuildDisplayText should return placeholder for empty text")

    tempRoot := A_ScriptDir "\tmp_runtime"
    if DirExist(tempRoot)
        DirDelete(tempRoot, 1)
    DirCreate(tempRoot "\tools\rapidocr\python")
    DirCreate(tempRoot "\lib")
    FileAppend "", tempRoot "\tools\rapidocr\python\python.exe"
    FileAppend "", tempRoot "\lib\rapidocr_runner.py"

    portableOcr := TextRecognizer("", "", tempRoot)
    backend := portableOcr.ResolveBackend()
    if (backend.name != "rapidocr")
        throw Error("ResolveBackend should prefer bundled RapidOCR runtime")
    if !InStr(backend.command, "rapidocr_runner.py")
        throw Error("RapidOCR backend command should reference rapidocr_runner.py")
    if !InStr(backend.command, "python.exe")
        throw Error("RapidOCR backend command should reference bundled python.exe")

    fallbackRoot := A_ScriptDir "\tmp_fallback_runtime"
    if DirExist(fallbackRoot)
        DirDelete(fallbackRoot, 1)
    DirCreate(fallbackRoot "\lib")
    FileAppend "", fallbackRoot "\lib\ocr_capture.ps1"

    fallbackOcr := TextRecognizer("", "", fallbackRoot)
    fallbackBackend := fallbackOcr.ResolveBackend()
    if (fallbackBackend.name != "winrt")
        throw Error("ResolveBackend should fall back to WinRT OCR when bundled runtime is missing")

    probeGui.Destroy()
    WriteStatus(0)
    ExitApp(0)
} catch as err {
    try probeGui.Destroy()
    WriteStatus(1)
    WriteFailure(err.Message)
    ExitApp(1)
}
