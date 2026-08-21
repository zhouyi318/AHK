#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_move_speed_calibration"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("导航跑速标定测试", "enter_map")
    moveStep := StepSchema.CreateStep("move_to_coord")
    script.steps.Push(moveStep)
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.ShowPage("脚本编辑")
    editor.LoadScriptByName("导航跑速标定测试")
    editor.SelectStep(1)

    if editor.HasProp("btnCalibrateMoveSpeed")
        throw Error("Build should no longer expose a move_to_coord speed calibration button in click-navigation mode")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
