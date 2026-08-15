#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk

try {
    scriptsDir := A_ScriptDir "\tmp_scripts_repo"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)
    DirCreate(scriptsDir)

    legacyStore := ScriptStore(scriptsDir)
    legacyStore.SaveScript({
        name: "legacy_demo",
        targetMapImage: "map.bmp",
        targetMapRegion: {x1: 10, y1: 20, x2: 30, y2: 40},
        steps: [
            {type: "wait", ms: 1000},
            {type: "click", x: 50, y: 60, button: "L", delay: 200}
        ]
    })

    repo := ScriptRepository(scriptsDir)
    script := repo.LoadScript("legacy_demo")

    if !script
        throw Error("LoadScript should return a normalized script object for legacy JSON")
    if (script.name != "legacy_demo")
        throw Error("LoadScript should preserve legacy script name")
    if (script.type != "enter_map")
        throw Error("Legacy script should default type to enter_map")
    if !script.HasProp("enabled") || !script.enabled
        throw Error("Legacy script should default enabled to true")
    if !script.HasProp("metadata")
        throw Error("Legacy script should expose metadata")
    if (script.metadata.targetMapImage != "map.bmp")
        throw Error("Legacy targetMapImage should move into metadata")
    if (script.metadata.targetMapRegion.x1 != 10 || script.metadata.targetMapRegion.y2 != 40)
        throw Error("Legacy targetMapRegion should move into metadata")
    if (script.steps.Length != 2)
        throw Error("Legacy steps should be preserved")
    if (script.steps[1].id = "")
        throw Error("Legacy step should receive generated id")
    if (script.steps[1].onSuccess.action != "next")
        throw Error("Legacy step should default success action to next")
    if (script.steps[1].onFailure.action != "stop")
        throw Error("Legacy step should default failure action to stop")
    if !script.steps[2].HasProp("params")
        throw Error("Legacy step should wrap payload into params")
    if (script.steps[2].params.x != 50 || script.steps[2].params.button != "L")
        throw Error("Legacy click payload should move into params")

    storeFlow := repo.CreateScript("store_flow_demo", "store_flow")
    repo.SaveScript(storeFlow)
    enterNames := repo.ListScriptsByType("enter_map")
    storeNames := repo.ListScriptsByType("store_flow")
    if (enterNames.Length != 1 || enterNames[1] != "legacy_demo")
        throw Error("ListScriptsByType should return normalized enter_map scripts")
    if (storeNames.Length != 1 || storeNames[1] != "store_flow_demo")
        throw Error("ListScriptsByType should return store_flow scripts")

    repo.SaveStoreConfig({intervalMinutes: 30, itemNames: ["裁决"], flowScriptName: "store_flow_demo"})
    storeCfg := repo.LoadStoreConfig()
    if (storeCfg.flowScriptName != "store_flow_demo")
        throw Error("LoadStoreConfig should preserve flowScriptName")

    ExitApp(0)
} catch as err {
    ExitApp(1)
}
