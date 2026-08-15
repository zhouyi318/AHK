#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_step_edit"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("步骤编辑测试", "enter_map")
    clickStep := StepSchema.CreateStep("click")
    clickStep.name := "原始点击"
    clickStep.params.x := 237
    clickStep.params.y := 237
    clickStep.params.button := "L"
    clickStep.params.delay := 3688
    waitStep := StepSchema.CreateStep("wait")
    waitStep.id := "step_2"
    waitStep.name := "等待确认"
    waitStep.params.ms := 1000
    clickStep.id := "step_1"
    script.steps.Push(clickStep)
    script.steps.Push(waitStep)
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.LoadScriptByName("步骤编辑测试")
    editor.SelectStep(1)

    if !editor.HasProp("btnApplyStep")
        throw Error("Build should create an apply button for editing the current step")
    if !editor.propInputs.Has("x")
        throw Error("RefreshProps should create an editable field for the x param")
    if !editor.HasProp("ddlOnSuccessAction")
        throw Error("Build should create a success branch action editor")
    if !editor.HasProp("ddlOnSuccessTarget")
        throw Error("Build should create a success branch target editor")
    if !editor.HasProp("ddlOnFailureAction")
        throw Error("Build should create a failure branch action editor")
    if !editor.HasProp("ddlOnFailureTarget")
        throw Error("Build should create a failure branch target editor")

    editor.edtStepName.Value := "点击 Boss"
    editor.chkStepEnabled.Value := 0
    editor.propInputs["x"].Value := "321"
    editor.propInputs["y"].Value := "654"
    editor.propInputs["button"].Value := "R"
    editor.propInputs["delay"].Value := "800"
    editor.ddlOnSuccessAction.Text := "jump"
    editor.ddlOnSuccessTarget.Text := "step_2"
    editor.ddlOnFailureAction.Text := "stop"
    editor.ddlOnFailureTarget.Text := ""

    if !editor.ApplyStepEdits()
        throw Error("ApplyStepEdits should update the selected step from the edit form")
    if (editor.currentScript.steps[1].name != "点击 Boss")
        throw Error("ApplyStepEdits should update the step name")
    if editor.currentScript.steps[1].enabled
        throw Error("ApplyStepEdits should update the enabled flag")
    if (editor.currentScript.steps[1].params.x != 321 || editor.currentScript.steps[1].params.y != 654)
        throw Error("ApplyStepEdits should update numeric click coordinates")
    if (editor.currentScript.steps[1].params.button != "R")
        throw Error("ApplyStepEdits should update string params")
    if (editor.currentScript.steps[1].onSuccess.action != "jump")
        throw Error("ApplyStepEdits should save the success branch action")
    if (editor.currentScript.steps[1].onSuccess.targetStepId != "step_2")
        throw Error("ApplyStepEdits should save the success branch target")
    if (editor.currentScript.steps[1].onFailure.action != "stop")
        throw Error("ApplyStepEdits should save the failure branch action")
    if !InStr(editor.pnlProps.Text, "点击 Boss")
        throw Error("ApplyStepEdits should refresh the properties summary")
    if !InStr(editor.pnlProps.Text, "x: 321")
        throw Error("ApplyStepEdits should show updated params in the summary")
    if !InStr(editor.pnlProps.Text, "成功: jump -> step_2")
        throw Error("ApplyStepEdits should show the updated success branch")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
