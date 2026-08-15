#Requires AutoHotkey v2.0

#Include ..\lib\StepSchema.ahk

statusPath := A_ScriptDir "\tmp_step_schema_result.txt"
if FileExist(statusPath)
    FileDelete(statusPath)

try {
    clickStep := StepSchema.CreateStep("click")
    if !clickStep.params.HasProp("repeat")
        throw Error("click should expose a repeat param for rapid clicks")
    if !clickStep.params.HasProp("intervalMs")
        throw Error("click should expose an intervalMs param for rapid clicks")
    if (clickStep.params.repeat != 1)
        throw Error("click should default repeat to 1")
    if (clickStep.params.intervalMs != 0)
        throw Error("click should default intervalMs to 0")

    step := StepSchema.CreateStep("ocr_match")
    if (step.type != "ocr_match")
        throw Error("CreateStep should preserve the requested step type")
    if (step.name = "")
        throw Error("CreateStep should generate a default step name")
    if !step.enabled
        throw Error("CreateStep should default enabled to true")
    if (step.onSuccess.action != "next")
        throw Error("CreateStep should default success action to next")
    if (step.onFailure.action != "stop")
        throw Error("CreateStep should default failure action to stop")
    if !step.HasProp("params")
        throw Error("CreateStep should initialize params")
    if !step.params.HasProp("region")
        throw Error("ocr_match should expose a default region param")

    branchStep := StepSchema.CreateStep("branch")
    if (branchStep.type != "branch")
        throw Error("CreateStep should support branch steps")
    if !branchStep.params.HasProp("conditionType")
        throw Error("branch should expose a conditionType param")
    if !branchStep.params.HasProp("region")
        throw Error("branch should expose a region param")

    mouseActionStep := StepSchema.CreateStep("mouse_action")
    if (mouseActionStep.type != "mouse_action")
        throw Error("CreateStep should support mouse_action steps")
    if (mouseActionStep.name != "按住")
        throw Error("mouse_action should use the default hold-step name")
    if !mouseActionStep.params.HasProp("action")
        throw Error("mouse_action should expose an action param")
    if !mouseActionStep.params.HasProp("holdMs")
        throw Error("mouse_action should expose a holdMs param")
    if (mouseActionStep.params.action != "hold")
        throw Error("mouse_action should default action to hold")
    if (mouseActionStep.params.holdMs != 0)
        throw Error("mouse_action should default holdMs to 0")

    script := {
        steps: [
            {id: "step_1", type: "wait", name: "等待", enabled: true, params: {ms: 1000}, onSuccess: {action: "next"}, onFailure: {action: "stop"}},
            {id: "step_2", type: "ocr_match", name: "识别文字", enabled: true, params: {targetText: "开始"}, onSuccess: {action: "jump", targetStepId: "step_1"}, onFailure: {action: "jump", targetStepId: "missing"}}
        ]
    }

    err := StepSchema.ValidateJumpTargets(script)
    if !InStr(err, "missing")
        throw Error("ValidateJumpTargets should report missing jump targets")

    script.steps[2].onFailure := {action: "stop"}
    err := StepSchema.ValidateJumpTargets(script)
    if (err != "")
        throw Error("ValidateJumpTargets should allow valid jump targets")

    FileAppend("PASS", statusPath, "UTF-8")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message, statusPath, "UTF-8")
    ExitApp(1)
}
