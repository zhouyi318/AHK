#Requires AutoHotkey v2.0

try {
    source := FileRead(A_ScriptDir "\..\Main.ahk", "UTF-8")
    if !InStr(source, "g.gui := scriptEditorWorkspace.Build()")
        throw Error("Main should build the unified script editor")
    if InStr(source, 'tab := MyGui.Add("Tab3"')
        throw Error("Main should no longer build the legacy Tab3 GUI")
    if InStr(source, "OnScriptChange(ctrl, *)")
        throw Error("Main should no longer keep legacy script page handlers")
    if InStr(source, "BtnAddItem(*)")
        throw Error("Main should no longer keep legacy store page handlers")
    ExitApp(0)
} catch {
    ExitApp(1)
}
