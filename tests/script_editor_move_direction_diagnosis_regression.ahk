#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_move_direction_diagnosis"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("导航方向诊断测试", "enter_map")
    moveStep := StepSchema.CreateStep("move_to_coord")
    script.steps.Push(moveStep)
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.ShowPage("脚本编辑")
    editor.LoadScriptByName("导航方向诊断测试")
    editor.SelectStep(1)

    if editor.HasProp("btnDiagnoseMoveDirection")
        throw Error("Build should no longer expose a move_to_coord direction diagnosis button in click-navigation mode")
    if editor.HasProp("btnApplyMoveDirectionAdvice")
        throw Error("Build should no longer expose a move_to_coord direction advice apply button in click-navigation mode")
    if !InStr(editor.txtStepHint.Value, "当 X 和 Y 都未到位时，优先走对角")
        throw Error("Build should describe the diagonal-first click-navigation rule in the move_to_coord hint area")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
