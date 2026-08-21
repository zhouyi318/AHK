#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

class FakeManualTools {
    __New() {
        this.calls := []
    }

    ShowClientPointDialog(title, initialPoint := "", prompt := "") {
        this.calls.Push({
            title: title,
            initialPoint: initialPoint,
            prompt: prompt
        })
        return {x: 222, y: 333}
    }
}

try {
    scriptsDir := A_ScriptDir "\tmp_editor_move_center_pick"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("导航中心点测试", "enter_map")
    moveStep := StepSchema.CreateStep("move_to_coord")
    moveStep.params.playerCenterX := 11
    moveStep.params.playerCenterY := 22
    script.steps.Push(moveStep)
    repo.SaveScript(script)

    manualTools := FakeManualTools()
    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema, "manualTools", manualTools))
    guiObj := editor.Build()
    editor.ShowPage("脚本编辑")
    editor.LoadScriptByName("导航中心点测试")
    editor.SelectStep(1)

    if !editor.PickSelectedMoveCenter()
        throw Error("PickSelectedMoveCenter should support move_to_coord steps")
    if (manualTools.calls.Length != 1)
        throw Error("PickSelectedMoveCenter should delegate point picking to ManualTools")
    if (manualTools.calls[1].title != "设置玩家中心点")
        throw Error("PickSelectedMoveCenter should use a navigation-specific title")
    if !IsObject(manualTools.calls[1].initialPoint)
        throw Error("PickSelectedMoveCenter should pass the current player center point to ManualTools")
    if (manualTools.calls[1].initialPoint.x != 11 || manualTools.calls[1].initialPoint.y != 22)
        throw Error("PickSelectedMoveCenter should seed ManualTools with the current player center point")
    if (editor.currentScript.steps[1].params.playerCenterX != 222 || editor.currentScript.steps[1].params.playerCenterY != 333)
        throw Error("PickSelectedMoveCenter should write the picked point back to move_to_coord params")
    if !InStr(editor.pnlProps.Text, "玩家中心点: 222,333")
        throw Error("PickSelectedMoveCenter should refresh the properties summary after updating the player center point")
    if (editor.propInputs["playerCenterX"].Value != "222" || editor.propInputs["playerCenterY"].Value != "333")
        throw Error("PickSelectedMoveCenter should refresh the player center editors after picking a point")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
