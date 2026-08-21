#Requires AutoHotkey v2.0

#Include ..\lib\ScriptEditor.ahk

class FakeRunner {
    __New() {
        this.calls := []
        this.shouldFailStep := false
    }

    RunScript(script, hwnd, startIndex := 1) {
        this.calls.Push("run:" startIndex)
        return {ok: true, startIndex: startIndex}
    }

    RunSingleStep(step, hwnd) {
        if this.shouldFailStep {
            this.calls.Push("single_fail:" step.id)
            return {ok: false, stepId: step.id, reason: "PARSE_FAILED"}
        }
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
            {id: "step_1", type: "wait", enabled: true},
            {id: "step_2", type: "move_to_coord", enabled: true}
        ]
    }
    editor.selectedStepIndex := 2
    editor.deps["cfg"] := {Window: {Hwnd: 987}}
    editor.currentFlow := {
        entryNodeId: "node_1",
        nodes: [
            {id: "node_1", name: "主循环", scriptName: "进图1"}
        ]
    }

    editor.RunCurrentScript()
    editor.RunFromCurrentStep()
    editor.RunCurrentStep()
    if !editor.RunSelectedMoveToCoordStep()
        throw Error("RunSelectedMoveToCoordStep should execute the selected navigation step")
    editor.RunCurrentFlow()

    editor.selectedStepIndex := 1
    if editor.RunSelectedMoveToCoordStep()
        throw Error("RunSelectedMoveToCoordStep should reject non-navigation steps")

    if (runner.calls.Length != 5)
        throw Error("Execution commands should delegate to the runner")
    if (runner.calls[1] != "run:1")
        throw Error("RunCurrentScript should start from the first step")
    if (runner.calls[2] != "run:2")
        throw Error("RunFromCurrentStep should start from the selected step")
    if (runner.calls[3] != "single:step_2")
        throw Error("RunCurrentStep should execute only the selected step")
    if (runner.calls[4] != "single:step_2")
        throw Error("RunSelectedMoveToCoordStep should delegate to RunSingleStep for the selected navigation step")
    if (runner.calls[5] != "flow:node_1")
        throw Error("RunCurrentFlow should delegate to the runner with the flow entry node")

    failingRunner := FakeRunner()
    failingRunner.shouldFailStep := true
    failingEditor := ScriptEditor(Map("runner", failingRunner))
    failingEditor.currentScript := {
        steps: [
            {id: "step_1", type: "move_to_coord", enabled: true}
        ]
    }
    failingEditor.selectedStepIndex := 1
    failingEditor.deps["cfg"] := {Window: {Hwnd: 987}}
    if failingEditor.RunSelectedMoveToCoordStep()
        throw Error("RunSelectedMoveToCoordStep should return false when the runner reports a failed navigation test")
    if !failingEditor.HasProp("lastMoveToCoordTestResult")
        throw Error("RunSelectedMoveToCoordStep should keep the last navigation test result for failure reporting")
    if (failingEditor.lastMoveToCoordTestResult.reason != "PARSE_FAILED")
        throw Error("RunSelectedMoveToCoordStep should preserve the runner failure reason for the UI")

    FileAppend("PASS", statusPath, "UTF-8")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message, statusPath, "UTF-8")
    ExitApp(1)
}
