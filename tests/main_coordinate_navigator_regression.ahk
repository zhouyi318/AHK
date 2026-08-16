#Requires AutoHotkey v2.0

try {
    source := FileRead(A_ScriptDir "\..\Main.ahk", "UTF-8")

    if !InStr(source, "#Include lib\CoordinateNavigator.ahk")
        throw Error("Main should include CoordinateNavigator before wiring the step runner")
    if !InStr(source, "global coordinateNavigatorService := CoordinateNavigator(playback, ocrRecognizer, appLogger)")
        throw Error("Main should create a shared CoordinateNavigator service")
    if !InStr(source, "global stepRunnerService := StepRunner(playback, ocrRecognizer, appLogger")
        throw Error("Main should keep using the shared StepRunner service constructor")
    if !InStr(source, "coordinateNavigatorService)")
        throw Error("Main should inject CoordinateNavigator into StepRunner")

    ExitApp(0)
} catch {
    ExitApp(1)
}
