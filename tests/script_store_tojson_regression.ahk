#Requires AutoHotkey v2.0

#Include ..\lib\ScriptStore.ahk

storeObj := ScriptStore(A_ScriptDir "\tmp_scripts")
json := storeObj.ToJson({
    name: "demo",
    targetMapImage: "",
    steps: [
        {type: "click", x: 1, y: 2, button: "L", delay: 3},
        {type: "wait", ms: 1000},
        {type: "findPic", image: "npc.bmp", timeout: 5000}
    ]
})

if !InStr(json, '"name":"demo"')
    throw Error("Serialized JSON is missing name")

ExitApp(0)
