#Requires AutoHotkey v2.0

#Include ..\lib\ScriptEditor.ahk

editor := ScriptEditor(Map())
guiObj := editor.Build()

if !IsObject(guiObj)
    throw Error("Build should return a GUI object")
if !editor.HasProp("lstScripts")
    throw Error("Build should expose the scripts list control")
if !editor.HasProp("lvSteps")
    throw Error("Build should expose the steps list view")
if !editor.HasProp("pnlProps")
    throw Error("Build should expose the properties panel placeholder")

guiObj.Destroy()
ExitApp(0)
