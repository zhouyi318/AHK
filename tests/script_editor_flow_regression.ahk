#Requires AutoHotkey v2.0

#Include ..\lib\FlowRepository.ahk
#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_flow_scripts"
    flowsDir := A_ScriptDir "\tmp_editor_flows"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)
    if DirExist(flowsDir)
        DirDelete(flowsDir, 1)

    scriptRepo := ScriptRepository(scriptsDir)
    scriptRepo.SaveScript(scriptRepo.CreateScript("进图1", "enter_map"))
    flowRepo := FlowRepository(flowsDir)

    editor := ScriptEditor(Map("repo", scriptRepo, "flowRepo", flowRepo, "schema", StepSchema))
    guiObj := editor.Build()

    if !editor.HasProp("lvFlowNodes")
        throw Error("Build should expose a flow node list")
    if !editor.HasProp("btnNewFlow")
        throw Error("Build should expose a new flow button")
    if !editor.HasProp("btnAddFlowNode")
        throw Error("Build should expose an add flow node button")

    editor.NewFlow("主循环")
    editor.AddFlowNode("进图1")

    if !IsObject(editor.currentFlow)
        throw Error("NewFlow should create a current flow object")
    if (editor.currentFlow.nodes.Length != 1)
        throw Error("AddFlowNode should append a node to the current flow")
    if (editor.currentFlow.entryNodeId != editor.currentFlow.nodes[1].id)
        throw Error("The first flow node should become the entry node by default")
    if (editor.currentFlow.nodes[1].scriptName != "进图1")
        throw Error("AddFlowNode should preserve the chosen script name")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
