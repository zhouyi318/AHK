#Requires AutoHotkey v2.0

#Include ..\lib\ScriptStore.ahk

class ScriptEnvelope {
    __New() {
        this.name := "demo"
        this.targetMapImage := ""
        this.steps := [{type: "wait", ms: 1000}]
    }
}

storeObj := ScriptStore(A_ScriptDir "\tmp_scripts")
json := storeObj.ToJson(ScriptEnvelope())

if !InStr(json, '"name":"demo"')
    throw Error("Serialized JSON is missing class properties")

ExitApp(0)
