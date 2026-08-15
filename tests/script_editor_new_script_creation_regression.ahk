#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_new_script"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()

    created := editor.CreateAndPersistScript("立即生成测试", "enter_map")
    if !created
        throw Error("CreateAndPersistScript should create a current script")
    if !FileExist(scriptsDir "\立即生成测试.json")
        throw Error("CreateAndPersistScript should persist the new script immediately")
    if (repo.ListScripts().Length != 1)
        throw Error("CreateAndPersistScript should refresh the script repository listing")
    if (editor.currentScript.name != "立即生成测试")
        throw Error("CreateAndPersistScript should keep the new script selected")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
