#Requires AutoHotkey v2.0

try {
    path := A_ScriptDir "\..\tools\run_all_tests.ps1"
    if !FileExist(path)
        throw Error("tools/run_all_tests.ps1 should exist")

    source := FileRead(path, "UTF-8")
    if !InStr(source, "Get-ChildItem")
        throw Error("run_all_tests.ps1 should enumerate regression tests automatically")
    if !InStr(source, "*.ahk")
        throw Error("run_all_tests.ps1 should run AHK regression tests")
    if !InStr(source, "ahk_test_runner.ahk")
        throw Error("run_all_tests.ps1 should delegate AHK exit-code capture to the AHK wrapper runner")
    if !InStr(source, "EXIT=")
        throw Error("run_all_tests.ps1 should read explicit AHK test status markers")
    if !InStr(source, "rapidocr_runtime_smoke.py")
        throw Error("run_all_tests.ps1 should run the RapidOCR smoke test")
    if !InStr(source, "rapidocr_runner_regression.py")
        throw Error("run_all_tests.ps1 should run the RapidOCR regression test")

    ExitApp(0)
} catch {
    ExitApp(1)
}
