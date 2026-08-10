#Requires AutoHotkey v2.0

#Include ..\lib\ScriptStore.ahk

scriptsDir := A_ScriptDir "\tmp_scripts"
storeObj := ScriptStore(scriptsDir)
scriptData := {
    name: "demo",
    targetMapImage: "",
    steps: [
        {type: "wait", ms: 1000}
    ]
}

storeObj.SaveScript(scriptData)
ExitApp(0)
