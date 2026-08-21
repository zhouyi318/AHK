#Requires AutoHotkey v2.0

try {
    source := FileRead(A_ScriptDir "\..\Main.ahk", "UTF-8")
    bridgePos := InStr(source, "class MainUiActionBridge {")
    trayTipPos := InStr(source, 'TrayTip("传奇挂机脚本已就绪"')
    returnPos := trayTipPos > 0 ? InStr(source, "return", false, trayTipPos) : 0

    if !InStr(source, "global mainUiActionBridgeService := MainUiActionBridge()")
        throw Error("Main should create a UI action bridge for ScriptEditor callbacks")
    if !InStr(source, '"onPickWindow", ObjBindMethod(mainUiActionBridgeService, "PickWindow")')
        throw Error("Main should bind the pick-window action through the UI action bridge")
    if !InStr(source, '"onRunBot", ObjBindMethod(mainUiActionBridgeService, "RunBot")')
        throw Error("Main should bind the run-bot action through the UI action bridge")
    if !InStr(source, 'InitWindowState(*) {')
        throw Error("MainUiActionBridge should expose an InitWindowState callback method for ManualTools refreshes")
    if InStr(source, "global mainUiActionBridge := MainUiActionBridge()")
        throw Error("Main should not reuse the class name as a case-insensitive global variable")
    if (bridgePos = 0 || returnPos = 0 || bridgePos > returnPos)
        throw Error("Main should declare MainUiActionBridge before the auto-execute return")

    ExitApp(0)
} catch {
    ExitApp(1)
}
