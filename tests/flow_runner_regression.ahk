#Requires AutoHotkey v2.0

#Include ..\lib\FlowRunner.ahk

class FakeScriptRepo {
    __New() {
        this.scripts := Map(
            "补给脚本", {name: "补给脚本", steps: [{id: "s1"}], shouldSucceed: true},
            "进图脚本", {name: "进图脚本", steps: [{id: "s2"}], shouldSucceed: false},
            "挂机脚本", {name: "挂机脚本", steps: [{id: "s3"}], shouldSucceed: true}
        )
    }

    LoadScript(name) {
        return this.scripts.Has(name) ? this.scripts[name] : ""
    }
}

class FakeStepRunner {
    __New() {
        this.calls := []
    }

    RunScript(script, hwnd, startIndex := 1) {
        this.calls.Push(script.name ":" startIndex)
        return {ok: script.shouldSucceed, lastStepId: script.steps[1].id}
    }
}

statusPath := A_ScriptDir "\tmp_flow_runner_result.txt"
if FileExist(statusPath)
    FileDelete(statusPath)

try {
    stepRunner := FakeStepRunner()
    flowRunner := FlowRunner(stepRunner, FakeScriptRepo(), "")

    flow := {
        entryNodeId: "node_1",
        nodes: [
            {id: "node_1", name: "补给", enabled: true, scriptName: "补给脚本", onSuccess: {action: "next"}, onFailure: {action: "stop"}, maxLoops: 0},
            {id: "node_2", name: "进图", enabled: true, scriptName: "进图脚本", onSuccess: {action: "next"}, onFailure: {action: "goto", targetNodeId: "node_3"}, maxLoops: 0},
            {id: "node_3", name: "挂机", enabled: true, scriptName: "挂机脚本", onSuccess: {action: "stop"}, onFailure: {action: "stop"}, maxLoops: 0}
        ]
    }

    result := flowRunner.RunFlow(flow, 123)
    if !result.ok
        throw Error("RunFlow should continue through failure goto and still finish successfully")
    if (result.lastNodeId != "node_3")
        throw Error("RunFlow should finish on the last reachable node")
    if (stepRunner.calls.Length != 3)
        throw Error("RunFlow should execute each reachable script node")

    stopFlow := {
        entryNodeId: "node_a",
        nodes: [
            {id: "node_a", name: "失败停止", enabled: true, scriptName: "进图脚本", onSuccess: {action: "next"}, onFailure: {action: "stop"}, maxLoops: 0}
        ]
    }
    stopResult := flowRunner.RunFlow(stopFlow, 123)
    if stopResult.ok
        throw Error("RunFlow should stop with failure when the node branch action is stop")
    if (stopResult.failedNodeId != "node_a")
        throw Error("RunFlow should report the failed node id")

    FileAppend("PASS", statusPath, "UTF-8")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message, statusPath, "UTF-8")
    ExitApp(1)
}
