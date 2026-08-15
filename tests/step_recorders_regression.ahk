#Requires AutoHotkey v2.0

#Include ..\lib\StepRecorders.ahk

statusPath := A_ScriptDir "\tmp_step_recorders_result.txt"
if FileExist(statusPath)
    FileDelete(statusPath)

try {
    recorders := StepRecorders()

    clickStep := recorders.BuildClickStep(100, 200, "R", 350)
    if (clickStep.type != "click")
        throw Error("BuildClickStep should create a click step")
    if (clickStep.params.x != 100 || clickStep.params.y != 200)
        throw Error("BuildClickStep should preserve coordinates")
    if (clickStep.params.button != "R" || clickStep.params.delay != 350)
        throw Error("BuildClickStep should preserve click metadata")
    if (clickStep.params.repeat != 1 || clickStep.params.intervalMs != 0)
        throw Error("BuildClickStep should default rapid-click metadata")

    keyStep := recorders.BuildKeypressStep("F8", 2)
    if (keyStep.type != "keypress")
        throw Error("BuildKeypressStep should create a keypress step")
    if (keyStep.params.keyName != "F8")
        throw Error("BuildKeypressStep should preserve key name")
    if (keyStep.params.repeat != 2)
        throw Error("BuildKeypressStep should preserve repeat count")

    rapidClickStep := recorders.BuildRepeatClickStep(320, 240, "L", 120, 3, 80)
    if (rapidClickStep.type != "click")
        throw Error("BuildRepeatClickStep should still create a click step")
    if (rapidClickStep.params.repeat != 3)
        throw Error("BuildRepeatClickStep should preserve click repeat count")
    if (rapidClickStep.params.intervalMs != 80)
        throw Error("BuildRepeatClickStep should preserve click interval")

    mouseActionStep := recorders.BuildMouseActionStep(640, 360, "R", "hold", 900, 150)
    if (mouseActionStep.type != "mouse_action")
        throw Error("BuildMouseActionStep should create a mouse_action step")
    if (mouseActionStep.params.action != "hold")
        throw Error("BuildMouseActionStep should preserve action type")
    if (mouseActionStep.params.holdMs != 900)
        throw Error("BuildMouseActionStep should preserve hold duration")
    if (mouseActionStep.params.delay != 150)
        throw Error("BuildMouseActionStep should preserve delay")

    normalizedRapidClick := recorders.NormalizeRecordedStep({
        type: "click",
        x: 88,
        y: 99,
        button: "L",
        delay: 60,
        repeat: 4,
        intervalMs: 45
    })
    if (normalizedRapidClick.type != "click")
        throw Error("NormalizeRecordedStep should preserve click step type")
    if (normalizedRapidClick.params.repeat != 4 || normalizedRapidClick.params.intervalMs != 45)
        throw Error("NormalizeRecordedStep should preserve rapid-click metadata")

    normalizedMouseAction := recorders.NormalizeRecordedStep({
        type: "mouse_action",
        x: 77,
        y: 55,
        button: "R",
        action: "hold",
        holdMs: 650,
        delay: 30
    })
    if (normalizedMouseAction.type != "mouse_action")
        throw Error("NormalizeRecordedStep should support mouse_action steps")
    if (normalizedMouseAction.params.holdMs != 650)
        throw Error("NormalizeRecordedStep should preserve hold duration")

    normalizedSequence := recorders.NormalizeRecordedSteps([
        {type: "click", x: 88, y: 99, button: "L", delay: 60},
        {type: "click", x: 88, y: 99, button: "L", delay: 45},
        {type: "click", x: 88, y: 99, button: "L", delay: 45},
        {type: "mouse_action", x: 120, y: 140, button: "R", action: "hold", holdMs: 700, delay: 180}
    ])
    if (normalizedSequence.Length != 2)
        throw Error("NormalizeRecordedSteps should aggregate rapid left clicks into one step")
    if (normalizedSequence[1].type != "click")
        throw Error("NormalizeRecordedSteps should preserve the click step type")
    if (normalizedSequence[1].params.repeat != 3)
        throw Error("NormalizeRecordedSteps should count rapid left clicks")
    if (normalizedSequence[1].params.intervalMs != 45)
        throw Error("NormalizeRecordedSteps should preserve rapid-click interval metadata")
    if (normalizedSequence[2].type != "mouse_action")
        throw Error("NormalizeRecordedSteps should preserve raw mouse actions")
    if (normalizedSequence[2].params.holdMs != 700)
        throw Error("NormalizeRecordedSteps should preserve raw mouse hold duration")

    FileAppend("PASS", statusPath, "UTF-8")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message, statusPath, "UTF-8")
    ExitApp(1)
}
