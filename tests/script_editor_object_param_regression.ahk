#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_editor_object_param"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("对象参数测试", "enter_map")
    imageStep := StepSchema.CreateStep("find_image")
    imageStep.params.image := "boss.bmp"
    imageStep.params.region := {x1: 10, y1: 20, x2: 30, y2: 40}
    script.steps.Push(imageStep)
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.LoadScriptByName("对象参数测试")
    editor.SelectStep(1)

    if !editor.propInputs.Has("region")
        throw Error("RefreshProps should create an editor for object params")
    if (editor.propInputs["region"].Value != "{ x1: 10, y1: 20, x2: 30, y2: 40 }")
        throw Error("Object params should be rendered as readable text instead of calling String on the object")
    if !InStr(editor.pnlProps.Text, "region: { x1: 10, y1: 20, x2: 30, y2: 40 }")
        throw Error("Properties summary should keep object params visible")

    guiObj.Destroy()
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    ExitApp(1)
}
