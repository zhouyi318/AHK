#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_selection"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("选择测试", "enter_map")
    waitStep := StepSchema.CreateStep("wait")
    waitStep.params.ms := 1500
    clickStep := StepSchema.CreateStep("click")
    clickStep.params.x := 88
    clickStep.params.y := 99
    script.steps.Push(waitStep)
    script.steps.Push(clickStep)
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.LoadScriptByName("选择测试")
    editor.SelectStep(2)

    if (editor.selectedStepIndex != 2)
        throw Error("SelectStep should update the selected step index")
    if !InStr(editor.pnlProps.Text, "click")
        throw Error("SelectStep should update the properties panel text")
    if !InStr(editor.pnlProps.Text, "x: 88")
        throw Error("Properties panel should show current step params")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    ExitApp(1)
}
