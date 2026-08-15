#Requires AutoHotkey v2.0

try {
    source := FileRead(A_ScriptDir "\..\Main.ahk", "UTF-8")

    if !InStr(source, "A_ScriptFullPath")
        throw Error("Main should log the startup script path for provenance checks")
    if !InStr(source, "A_AhkPath")
        throw Error("Main should log the AutoHotkey executable path for provenance checks")
    if !InStr(source, "准备创建 ManualTools")
        throw Error("Main should log before constructing ManualTools")
    if !InStr(source, 'manualToolService := ManualTools(Map(')
        throw Error("Main should construct ManualTools directly in the startup sequence")
    if !InStr(source, "ManualTools 创建失败")
        throw Error("Main should log ManualTools construction failures before rethrowing")

    ExitApp(0)
} catch {
    ExitApp(1)
}
