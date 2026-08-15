#Requires AutoHotkey v2.0

try {
    source := FileRead(A_ScriptDir "\..\Main.ahk", "UTF-8")

    if !InStr(source, "#Include lib\ManualTools.ahk")
        throw Error("Main should include the manual tools module")
    if !InStr(source, 'manualToolService := ManualTools(Map(')
        throw Error("Main should create the manual tools service during startup")
    if InStr(source, "BtnTestRegionFind(*) {")
        throw Error("Main should delegate manual image-find testing to the manual tools module")
    if InStr(source, "BtnTestRegionOcr(*) {")
        throw Error("Main should delegate manual OCR testing to the manual tools module")
    if InStr(source, "BtnPreviewRegionOcr(*) {")
        throw Error("Main should delegate OCR preview testing to the manual tools module")
    if InStr(source, "BtnSetGlobalSim(*) {")
        throw Error("Main should delegate global similarity changes to the manual tools module")
    if InStr(source, "ShowImageRegionDialog(")
        throw Error("Main should move image-region dialogs into the manual tools module")
    if InStr(source, "ShowTextOcrDialog(")
        throw Error("Main should move OCR dialogs into the manual tools module")

    ExitApp(0)
} catch {
    ExitApp(1)
}
