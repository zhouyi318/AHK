#Requires AutoHotkey v2.0

#Include ..\lib\ScriptEditor.ahk

try {
    editor := ScriptEditor(Map())
    guiObj := editor.Build()

    requiredProps := [
        "pnlNav", "pnlWorkspace", "pnlStatus",
        "btnNavHome", "btnNavScripts", "btnNavFlows", "btnNavSettings", "btnNavLogs"
    ]
    for _, name in requiredProps {
        if !editor.HasProp(name)
            throw Error("Build should create the shell control: " name)
    }

    if (editor.btnNavHome.Text != "主页")
        throw Error("Build should label the home navigation button")
    if (editor.btnNavScripts.Text != "脚本编辑")
        throw Error("Build should label the script editor navigation button")
    if (editor.btnNavFlows.Text != "流程调度")
        throw Error("Build should label the flow navigation button")
    if (editor.btnNavSettings.Text != "挂机设置")
        throw Error("Build should label the settings navigation button")
    if (editor.btnNavLogs.Text != "运行日志")
        throw Error("Build should label the log navigation button")
    if (editor.currentPage != "主页")
        throw Error("Build should default to the home page")

    editor.pnlNav.GetPos(&navX, &navY, &navW, &navH)
    editor.pnlWorkspace.GetPos(&workX, &workY, &workW, &workH)
    editor.pnlStatus.GetPos(&statusX, &statusY, &statusW, &statusH)

    if !(navX < workX && workX < statusX)
        throw Error("Build should place navigation, workspace, and status panels from left to right")
    if (navW < 140)
        throw Error("Navigation panel should keep enough width for a sidebar")
    if (statusW < 180)
        throw Error("Status panel should keep enough width for persistent status widgets")
    if !(workH >= navH - 20)
        throw Error("Workspace panel should remain the dominant vertical area")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
