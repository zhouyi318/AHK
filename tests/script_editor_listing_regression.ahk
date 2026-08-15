#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_listing"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("列表测试", "enter_map")
    script.steps.Push(StepSchema.CreateStep("wait"))
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.RefreshScriptList()
    editor.LoadScriptByName("列表测试")

    if (editor.scriptNames.Length != 1)
        throw Error("RefreshScriptList should load repository scripts")
    if (editor.currentScript.name != "列表测试")
        throw Error("LoadScriptByName should set currentScript")
    if (editor.currentScript.steps.Length != 1)
        throw Error("LoadScriptByName should load step data")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    ExitApp(1)
}
