#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_move_quick_adjust"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("导航快速纠偏测试", "enter_map")
    moveStep := StepSchema.CreateStep("move_to_coord")
    moveStep.params.axisXScreenX := -1
    moveStep.params.axisXScreenY := 1
    moveStep.params.axisYScreenX := 1
    moveStep.params.axisYScreenY := 1
    moveStep.params.directionScale := 120
    script.steps.Push(moveStep)
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.ShowPage("脚本编辑")
    editor.LoadScriptByName("导航快速纠偏测试")
    editor.SelectStep(1)

    if editor.HasProp("btnFlipMoveAxisX")
        throw Error("Build should no longer expose a move_to_coord flip-X quick adjustment button")
    if editor.HasProp("btnFlipMoveAxisY")
        throw Error("Build should no longer expose a move_to_coord flip-Y quick adjustment button")
    if editor.HasProp("btnSwapMoveAxes")
        throw Error("Build should no longer expose a move_to_coord axis swap quick adjustment button")
    if editor.HasProp("btnMoveScaleDown")
        throw Error("Build should no longer expose a move_to_coord scale-down quick adjustment button")
    if editor.HasProp("btnMoveScaleUp")
        throw Error("Build should no longer expose a move_to_coord scale-up quick adjustment button")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
