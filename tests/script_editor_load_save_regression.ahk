#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_repo"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))

    editor.NewScript("测试脚本", "enter_map")
    editor.AddStep("wait")
    editor.currentScript.steps[1].params.ms := 500
    editor.SaveCurrentScript()

    loaded := repo.LoadScript("测试脚本")
    if !loaded
        throw Error("SaveCurrentScript should persist the current script")
    if (loaded.type != "enter_map")
        throw Error("CreateScript should preserve the script type")
    if (loaded.steps.Length != 1)
        throw Error("AddStep should append a new step")
    if (loaded.steps[1].params.ms != 500)
        throw Error("SaveCurrentScript should persist edited step params")

    ExitApp(0)
} catch as err {
    FileAppend err.Message, "*"
    ExitApp(1)
}
