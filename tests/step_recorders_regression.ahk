#Requires AutoHotkey v2.0

#Include ..\lib\StepRecorders.ahk

recorders := StepRecorders()

clickStep := recorders.BuildClickStep(100, 200, "R", 350)
if (clickStep.type != "click")
    throw Error("BuildClickStep should create a click step")
if (clickStep.params.x != 100 || clickStep.params.y != 200)
    throw Error("BuildClickStep should preserve coordinates")
if (clickStep.params.button != "R" || clickStep.params.delay != 350)
    throw Error("BuildClickStep should preserve click metadata")

keyStep := recorders.BuildKeypressStep("F8", 2)
if (keyStep.type != "keypress")
    throw Error("BuildKeypressStep should create a keypress step")
if (keyStep.params.keyName != "F8")
    throw Error("BuildKeypressStep should preserve key name")
if (keyStep.params.repeat != 2)
    throw Error("BuildKeypressStep should preserve repeat count")

ExitApp(0)
