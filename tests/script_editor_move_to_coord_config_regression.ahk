#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

class FakeManualTools {
    __New() {
        this.calls := []
    }

    ShowTextOcrDialog(title, defaultTargetText := "", initialRegion := "", requireTargetText := true) {
        this.calls.Push({
            title: title,
            defaultTargetText: defaultTargetText,
            initialRegion: initialRegion,
            requireTargetText: requireTargetText
        })
        return {targetText: "", region: {x1: 101, y1: 202, x2: 303, y2: 404}}
    }
}

try {
    scriptsDir := A_ScriptDir "\tmp_editor_move_to_coord_config"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("导航配置测试", "enter_map")
    moveStep := StepSchema.CreateStep("move_to_coord")
    moveStep.params.coordRegion := {x1: 1, y1: 2, x2: 3, y2: 4}
    script.steps.Push(moveStep)
    repo.SaveScript(script)

    manualTools := FakeManualTools()
    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema, "manualTools", manualTools))
    guiObj := editor.Build()
    editor.LoadScriptByName("导航配置测试")
    editor.SelectStep(1)

    if !editor.ConfigureSelectedStep()
        throw Error("ConfigureSelectedStep should support move_to_coord steps")
    if (manualTools.calls.Length != 1)
        throw Error("ConfigureSelectedStep should delegate move_to_coord region picking to the OCR region dialog")
    if manualTools.calls[1].requireTargetText
        throw Error("move_to_coord region picking should not require target text")
    if (editor.currentScript.steps[1].params.coordRegion.x1 != 101 || editor.currentScript.steps[1].params.coordRegion.y2 != 404)
        throw Error("ConfigureSelectedStep should save the picked OCR region back to move_to_coord params")
    if !InStr(editor.pnlProps.Text, "坐标识别框: { x1: 101, y1: 202, x2: 303, y2: 404 }")
        throw Error("ConfigureSelectedStep should refresh the business-friendly OCR region summary after updating move_to_coord region")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
