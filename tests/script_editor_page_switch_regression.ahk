#Requires AutoHotkey v2.0

#Include ..\lib\ScriptEditor.ahk

try {
    editor := ScriptEditor(Map())
    guiObj := editor.Build()

    requiredProps := [
        "pageHome", "pageScriptEditor", "pageFlowEditor", "pageSettings", "pageLogs"
    ]
    for _, name in requiredProps {
        if !editor.HasProp(name)
            throw Error("Build should expose the page container: " name)
    }

    if !editor.pageHome.Visible
        throw Error("Build should show the home page by default")
    if editor.pageScriptEditor.Visible
        throw Error("Build should keep the script editor page hidden until it is selected")
    if editor.lstScripts.Visible
        throw Error("Build should hide script-editing controls when the home page is active")

    editor.ShowPage("脚本编辑")
    if (editor.currentPage != "脚本编辑")
        throw Error("ShowPage should update the current page name")
    if !editor.pageScriptEditor.Visible
        throw Error("ShowPage should show the script editor page")
    if !editor.lstScripts.Visible
        throw Error("ShowPage should reveal the script list on the script editor page")
    if !editor.lvSteps.Visible
        throw Error("ShowPage should reveal the steps list on the script editor page")
    if editor.pageHome.Visible
        throw Error("ShowPage should hide the home page when switching to script editing")
    if editor.lvFlowNodes.Visible
        throw Error("ShowPage should keep flow controls hidden on the script editor page")

    editor.ShowPage("流程调度")
    if !editor.pageFlowEditor.Visible
        throw Error("ShowPage should show the flow editor page")
    if !editor.lstFlows.Visible
        throw Error("ShowPage should reveal the flow list on the flow page")
    if !editor.lvFlowNodes.Visible
        throw Error("ShowPage should reveal the flow node list on the flow page")
    if editor.lstScripts.Visible
        throw Error("ShowPage should hide script controls when switching to flow editing")

    editor.ShowPage("挂机设置")
    if !editor.pageSettings.Visible
        throw Error("ShowPage should show the settings page")
    if editor.pageFlowEditor.Visible
        throw Error("ShowPage should hide the flow page when switching to settings")

    editor.ShowPage("运行日志")
    if !editor.pageLogs.Visible
        throw Error("ShowPage should show the log page")
    if !editor.HasProp("edtRunLogs")
        throw Error("Build should create a dedicated editor for the full log page")
    if !editor.edtRunLogs.Visible
        throw Error("ShowPage should reveal the dedicated log editor on the log page")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
