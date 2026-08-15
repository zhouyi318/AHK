#Requires AutoHotkey v2.0

#Include ..\lib\Bot.ahk

class FakeLogger {
    Info(*) {
    }
    Warn(*) {
    }
    Error(*) {
    }
    State(*) {
    }
}

class FakeStore {
    __New() {
        this.loaded := []
    }

    ListScriptsByType(type) {
        return (type = "enter_map") ? ["进图1"] : ["存仓1"]
    }

    LoadScript(name) {
        this.loaded.Push(name)
        if (name = "存仓1")
            return {name: name, type: "store_flow", steps: [{id: "store_step_1"}]}
        return {name: name, type: "enter_map", steps: [{id: "enter_step_1"}]}
    }

    LoadStoreConfig() {
        return {intervalMinutes: 60, itemNames: ["裁决"], flowScriptName: "存仓1"}
    }
}

class FakeRunner {
    __New() {
        this.calls := []
    }

    RunScript(script, hwnd, startIndex := 1) {
        this.calls.Push(script.type ":" script.name ":" startIndex)
        return {ok: true}
    }
}

class FakePlayer {
    Play(*) {
        return true
    }
}

cfg := {
    Window: {Hwnd: 123},
    Bot: {TickMs: 500, AutoFightRetry: 3, StoreIntervalMin: 60},
    Images: {},
    ImageRegions: {}
}

store := FakeStore()
runner := FakeRunner()
player := FakePlayer()
botObj := Bot(cfg, FakeLogger(), player, store, runner)
botObj.hwnd := 123

botObj.HandleRunEnterScript()
if (runner.calls[1] != "enter_map:进图1:1")
    throw Error("HandleRunEnterScript should run enter_map scripts through the unified runner")

botObj.HandleStoreItems()
if (runner.calls[2] != "store_flow:存仓1:1")
    throw Error("HandleStoreItems should run the configured store_flow script through the unified runner")

ExitApp(0)
