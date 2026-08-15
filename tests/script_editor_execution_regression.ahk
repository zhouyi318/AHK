#Requires AutoHotkey v2.0

#Include ..\lib\ScriptEditor.ahk

class FakeRunner {
    __New() {
        this.calls := []
    }

    RunScript(script, hwnd, startIndex := 1) {
        this.calls.Push("run:" startIndex)
        return {ok: true, startIndex: startIndex}
    }

    RunSingleStep(step, hwnd) {
        this.calls.Push("single:" step.id)
        return {ok: true, stepId: step.id}
    }

    RunFlow(flow, hwnd, startNodeId := "") {
        this.calls.Push("flow:" . (startNodeId = "" ? flow.entryNodeId : startNodeId))
        return {ok: true, entryNodeId: startNodeId = "" ? flow.entryNodeId : startNodeId}
    }
}

statusPath := A_ScriptDir "\tmp_script_editor_execution_result.txt"
if FileExist(statusPath)
    FileDelete(statusPath)

try {
    runner := FakeRunner()
    editor := ScriptEditor(Map("runner", runner))
    editor.currentScript := {
        steps: [
            {id: "step_1", enabled: true},
            {id: "step_2", enabled: true}
        ]
    }
    editor.selectedStepIndex := 2
    editor.currentFlow := {
        entryNodeId: "node_1",
        nodes: [
            {id: "node_1", name: "主循环", scriptName: "进图1"}
        ]
    }

    editor.RunCurrentScript()
    editor.RunFromCurrentStep()
    editor.RunCurrentStep()
    editor.RunCurrentFlow()

    if (runner.calls.Length != 4)
        throw Error("Execution commands should delegate to the runner")
    if (runner.calls[1] != "run:1")
        throw Error("RunCurrentScript should start from the first step")
    if (runner.calls[2] != "run:2")
        throw Error("RunFromCurrentStep should start from the selected step")
    if (runner.calls[3] != "single:step_2")
        throw Error("RunCurrentStep should execute only the selected step")
    if (runner.calls[4] != "flow:node_1")
        throw Error("RunCurrentFlow should delegate to the runner with the flow entry node")

    FileAppend("PASS", statusPath, "UTF-8")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message, statusPath, "UTF-8")
    ExitApp(1)
}
