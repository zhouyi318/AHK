#Requires AutoHotkey v2.0

#Include ..\lib\FlowRepository.ahk

try {
    flowsDir := A_ScriptDir "\tmp_flows_repo"
    if DirExist(flowsDir)
        DirDelete(flowsDir, 1)

    repo := FlowRepository(flowsDir)
    flow := repo.CreateFlow("主循环")
    flow.entryNodeId := "node_1"
    flow.nodes.Push({
        id: "node_1",
        name: "补给",
        enabled: true,
        scriptName: "补给脚本",
        onSuccess: {action: "goto", targetNodeId: "node_2"},
        onFailure: {action: "repeat"},
        maxLoops: 0
    })
    flow.nodes.Push({
        id: "node_2",
        name: "进图",
        enabled: true,
        scriptName: "进图脚本",
        onSuccess: {action: "stop"},
        onFailure: {action: "goto", targetNodeId: "node_1"},
        maxLoops: 0
    })

    repo.SaveFlow(flow)
    loaded := repo.LoadFlow("主循环")
    names := repo.ListFlows()

    if !loaded
        throw Error("LoadFlow should return a normalized flow object")
    if (loaded.entryNodeId != "node_1")
        throw Error("LoadFlow should preserve entryNodeId")
    if (loaded.nodes.Length != 2)
        throw Error("LoadFlow should preserve flow nodes")
    if (loaded.nodes[1].onSuccess.action != "goto")
        throw Error("LoadFlow should preserve node success branches")
    if (names.Length != 1 || names[1] != "主循环")
        throw Error("ListFlows should return saved flow names")

    ExitApp(0)
} catch as err {
    ExitApp(1)
}
