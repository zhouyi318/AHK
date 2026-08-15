#Requires AutoHotkey v2.0

#Include ..\lib\ScriptEditor.ahk

try {
    editor := ScriptEditor(Map())
    guiObj := editor.Build()

    if !editor.HasProp("btnPickWindow")
        throw Error("Build should create a pick window button")
    if !editor.HasProp("btnRunBot")
        throw Error("Build should create a bot run button")
    if !editor.HasProp("btnTestRegionFind")
        throw Error("Build should keep a manual image-find test入口")
    if !editor.HasProp("btnTestRegionOcr")
        throw Error("Build should keep a manual OCR test入口")
    if !editor.HasProp("btnRecordClick")
        throw Error("Build should create a click recording button")
    if !editor.HasProp("btnRecordKey")
        throw Error("Build should create a keypress recording button")
    if !editor.HasProp("btnAddFindImage")
        throw Error("Build should expose a button for adding find_image steps")
    if !editor.HasProp("btnAddClickImage")
        throw Error("Build should expose a button for adding click_image steps")
    if !editor.HasProp("btnAddOcrMatch")
        throw Error("Build should expose a button for adding ocr_match steps")
    if !editor.HasProp("btnAddBranch")
        throw Error("Build should expose a button for adding branch steps")
    if !editor.HasProp("btnConfigureStep")
        throw Error("Build should expose a button for configuring recognition steps")

    guiObj.Destroy()
    ExitApp(0)
} catch {
    ExitApp(1)
}
