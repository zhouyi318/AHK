#Requires AutoHotkey v2.0

#Include ..\lib\ScriptEditor.ahk

try {
    editor := ScriptEditor(Map())
    guiObj := editor.Build()

    if !editor.HasProp("txtWindowSummary")
        throw Error("Build should create a window summary area")
    if !editor.HasProp("txtRunState")
        throw Error("Build should create a run state area")
    if !editor.HasProp("edtLog")
        throw Error("Build should create a log viewer")

    editor.SetWindowSummary("窗口: 测试窗口")
    editor.SetRunState("当前状态：运行中")
    editor.SetLogText("第一行`n第二行")

    if (editor.txtWindowSummary.Text != "窗口: 测试窗口")
        throw Error("SetWindowSummary should update the window summary text")
    if (editor.txtRunState.Text != "当前状态：运行中")
        throw Error("SetRunState should update the run state text")
    if (editor.edtLog.Value != "第一行`n第二行")
        throw Error("SetLogText should update the log viewer content")

    guiObj.Destroy()
    ExitApp(0)
} catch {
    ExitApp(1)
}
