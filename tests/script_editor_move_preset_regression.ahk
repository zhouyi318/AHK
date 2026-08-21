#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_move_preset"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("导航预设测试", "enter_map")
    moveStep := StepSchema.CreateStep("move_to_coord")
    script.steps.Push(moveStep)
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.ShowPage("脚本编辑")
    editor.LoadScriptByName("导航预设测试")
    editor.SelectStep(1)

    if editor.HasProp("btnApplyMovePreset")
        throw Error("Build should no longer expose a move_to_coord preset button in click-navigation mode")
    if !editor.HasProp("btnPickMoveCoordRegion")
        throw Error("Build should expose a move_to_coord OCR region picking button in click-navigation mode")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
