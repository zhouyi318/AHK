#Requires AutoHotkey v2.0

try {
    source := FileRead(A_ScriptDir "\..\Main.ahk", "UTF-8")

    if InStr(source, "global stepRecorders := StepRecorders()")
        throw Error("Main should not use a StepRecorders instance variable that only differs by case")
    if InStr(source, "global stepRunner := StepRunner(")
        throw Error("Main should not use a StepRunner instance variable that only differs by case")
    if InStr(source, "global manualTools := ManualTools(")
        throw Error("Main should not use a ManualTools instance variable that only differs by case")
    if InStr(source, "global scriptEditor := ScriptEditor(")
        throw Error("Main should not use a ScriptEditor instance variable that only differs by case")

    ExitApp(0)
} catch {
    ExitApp(1)
}
