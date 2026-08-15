#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_delete"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("待删除脚本", "enter_map")
    script.steps.Push(StepSchema.CreateStep("wait"))
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.LoadScriptByName("待删除脚本")

    if !editor.DeleteCurrentScript()
        throw Error("DeleteCurrentScript should delete the current script")
    if FileExist(scriptsDir "\待删除脚本.json")
        throw Error("DeleteCurrentScript should remove the script file")
    if (repo.ListScripts().Length != 0)
        throw Error("DeleteCurrentScript should refresh the repository listing")
    if editor.currentScript
        throw Error("DeleteCurrentScript should clear currentScript when no scripts remain")
    if (editor.lvSteps.GetCount() != 0)
        throw Error("DeleteCurrentScript should clear the step list when the script is removed")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
