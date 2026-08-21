#Requires AutoHotkey v2.0

#Include ..\lib\Bot.ahk

WriteStatus(exitCode) {
    if (A_Args.Length < 1)
        return
    statusPath := A_Args[1]
    try {
        if FileExist(statusPath)
            FileDelete(statusPath)
    }
    FileAppend("EXIT=" exitCode, statusPath, "UTF-8")
}

WriteFailure(message) {
    if (A_Args.Length < 1)
        return
    statusPath := A_Args[1]
    FileAppend("`nFAIL=" message, statusPath, "UTF-8")
}

class FakeLogger {
    __New() {
        this.messages := []
    }

    Info(msg) {
        this.messages.Push("INFO:" . msg)
    }

    Warn(msg) {
        this.messages.Push("WARN:" . msg)
    }

    Error(msg) {
        this.messages.Push("ERROR:" . msg)
    }

    State(s) {
        this.messages.Push("STATE:" . s)
    }
}

class FakePlayer {
    __New() {
        this.picResults := Map()
        this.picCalls := []
        this.clicks := []
    }

    FindPic(image, hwnd, &x, &y, region := "", logLabel := "", sim := "") {
        this.picCalls.Push(image)
        x := 100
        y := 100
        if (this.picResults.Has(image)) {
            value := this.picResults[image]
            if (value is Array) {
                if (value.Length > 0)
                    return value.RemoveAt(1)
                return false
            }
            return value
        }
        return false
    }

    ClickPic(image, hwnd, region := "", logLabel := "") {
        this.clicks.Push(image)
        return true
    }

    Play(*) {
        return true
    }
}

class FakeStore {
    __New() {
        this.loaded := []
    }

    ListScriptsByType(type) {
        return (type = "enter_map") ? ["图1", "图2"] : []
    }

    LoadScript(name) {
        this.loaded.Push(name)
        return {name: name, type: "enter_map", steps: [{id: "enter_step_1"}]}
    }

    LoadStoreConfig() {
        return {intervalMinutes: 60, itemNames: [], flowScriptName: ""}
    }
}

class FakeRunner {
    __New(results := []) {
        this.results := results
        this.calls := []
    }

    RunScript(script, hwnd, startIndex := 1) {
        this.calls.Push(script.name)
        if (this.calls.Length <= this.results.Length)
            return {ok: this.results[this.calls.Length]}
        return {ok: true}
    }
}

HasLogMessage(messages, expected) {
    for _, msg in messages {
        if InStr(msg, expected)
            return true
    }
    return false
}

MakeCfg() {
    return {
        Window: {Hwnd: 123},
        Bot: {
            TickMs: 500,
            AutoFightRetry: 3,
            StoreIntervalMin: 60,
            MonitorIntervalMs: 10000,
            VerifyMapRetry: 3,
            VerifyMapRetryIntervalMs: 0,
            CheckTownTimeoutMs: 60000,
            ScriptMaxConsecutiveFails: 2,
            ScriptFailCooldownMs: 600000
        },
        Images: {Town: "town.bmp", ReturnStone: "return_stone.bmp"},
        ImageRegions: {}
    }
}

try {
    logger := FakeLogger()

    ; ===== 场景 1：进图脚本连续失败进入冷却，轮换时自动跳过 =====
    cooldownPlayer := FakePlayer()
    cooldownStore := FakeStore()
    cooldownRunner := FakeRunner([true, false, false, false, true, true])
    cooldownBot := Bot(MakeCfg(), logger, cooldownPlayer, cooldownStore, cooldownRunner)
    cooldownBot.hwnd := 123
    cooldownBot.HandleRunEnterScript()  ; 图1 成功
    cooldownBot.HandleRunEnterScript()  ; 图2 失败（连续第1次）
    cooldownBot.HandleRunEnterScript()  ; 图1 失败（连续第1次）
    cooldownBot.HandleRunEnterScript()  ; 图2 失败（连续第2次 -> 达到阈值进入冷却）
    cooldownBot.HandleRunEnterScript()  ; 图1 成功（清零图1失败计数）
    cooldownBot.HandleRunEnterScript()  ; 图2 冷却中跳过 -> 图1 执行

    if (cooldownRunner.calls.Length != 6)
        throw Error("HandleRunEnterScript should run one script per call, got " cooldownRunner.calls.Length " calls")
    expectedCalls := "图1,图2,图1,图2,图1,图1"
    actualCalls := ""
    for _, call in cooldownRunner.calls
        actualCalls .= (actualCalls = "" ? "" : ",") . call
    if (actualCalls != expectedCalls)
        throw Error("HandleRunEnterScript should rotate scripts and skip the cooled-down script, expected " expectedCalls " got " actualCalls)
    if !HasLogMessage(logger.messages, "脚本 图2 连续失败 2 次，冷却")
        throw Error("HandleRunEnterScript should log the cooldown trigger after consecutive failures")
    if !HasLogMessage(logger.messages, "脚本 图2 失败冷却中，跳过")
        throw Error("HandleRunEnterScript should log skipping a cooled-down script")
    if (cooldownBot.state != "VerifyMap")
        throw Error("HandleRunEnterScript should still move to VerifyMap after choosing a script")

    ; ===== 场景 2：失败后成功会清零连续失败计数 =====
    clearPlayer := FakePlayer()
    clearStore := FakeStore()
    clearRunner := FakeRunner()
    clearBot := Bot(MakeCfg(), logger, clearPlayer, clearStore, clearRunner)
    clearBot.RecordEnterScriptResult("图1", {ok: false})
    if (!clearBot.scriptFailCounts.Has("图1") || clearBot.scriptFailCounts["图1"] != 1)
        throw Error("RecordEnterScriptResult should count a failed run")
    clearBot.RecordEnterScriptResult("图1", {ok: true})
    if clearBot.scriptFailCounts.Has("图1")
        throw Error("RecordEnterScriptResult should clear the fail count after a successful run")

    ; ===== 场景 3：所有脚本都在冷却时重置冷却继续轮换 =====
    resetPlayer := FakePlayer()
    resetStore := FakeStore()
    resetRunner := FakeRunner([true])
    resetBot := Bot(MakeCfg(), logger, resetPlayer, resetStore, resetRunner)
    resetBot.hwnd := 123
    resetBot.scriptCooldowns := Map("图1", A_TickCount + 600000, "图2", A_TickCount + 600000)
    resetBot.HandleRunEnterScript()
    if (resetRunner.calls.Length != 1)
        throw Error("HandleRunEnterScript should still run a script when all scripts are cooling down")
    if !HasLogMessage(logger.messages, "所有进图脚本都在冷却中，重置冷却继续轮换")
        throw Error("HandleRunEnterScript should log the cooldown reset when all scripts are cooling down")

    ; ===== 场景 4：地图校验重试通过（加载慢不误判回城） =====
    verifyPlayer := FakePlayer()
    verifyPlayer.picResults["map1.bmp"] := [false, false, true]
    verifyStore := FakeStore()
    verifyRunner := FakeRunner([true])
    verifyBot := Bot(MakeCfg(), logger, verifyPlayer, verifyStore, verifyRunner)
    verifyBot.hwnd := 123
    verifyBot.currentScript := {name: "图1", type: "enter_map", steps: [{id: "s1"}], targetMapImage: "map1.bmp", targetMapRegion: ""}
    verifyBot.HandleVerifyMap()
    if (verifyBot.state != "EnableAutoFight")
        throw Error("HandleVerifyMap should pass after retries succeed once the map finishes loading")
    mapAttempts := 0
    for _, call in verifyPlayer.picCalls {
        if (call = "map1.bmp")
            mapAttempts += 1
    }
    if (mapAttempts != 3)
        throw Error("HandleVerifyMap should retry the map check, expected 3 attempts got " mapAttempts)
    if HasLogMessage(logger.messages, "地图校验失败")
        throw Error("HandleVerifyMap should not declare failure while retries still succeed")

    ; ===== 场景 5：地图校验重试全部失败才点回城石 =====
    failPlayer := FakePlayer()
    failPlayer.picResults["map2.bmp"] := false
    failStore := FakeStore()
    failRunner := FakeRunner([true])
    failBot := Bot(MakeCfg(), logger, failPlayer, failStore, failRunner)
    failBot.hwnd := 123
    failBot.currentScript := {name: "图1", type: "enter_map", steps: [{id: "s1"}], targetMapImage: "map2.bmp", targetMapRegion: ""}
    failBot.HandleVerifyMap()
    if (failBot.state != "CheckTown")
        throw Error("HandleVerifyMap should fall back to CheckTown only after all retries fail")
    if (failPlayer.clicks.Length != 1 || failPlayer.clicks[1] != "return_stone.bmp")
        throw Error("HandleVerifyMap should click the return stone after all retries fail")

    ; ===== 场景 6：等待土城超时后点回城石兜底 =====
    townPlayer := FakePlayer()
    townPlayer.picResults["town.bmp"] := false
    townStore := FakeStore()
    townRunner := FakeRunner()
    townBot := Bot(MakeCfg(), logger, townPlayer, townStore, townRunner)
    townBot.hwnd := 123
    townBot.checkTownSince := A_TickCount - 99999
    townBot.HandleCheckTown()
    if (townBot.checkTownSince < A_TickCount - 4000)
        throw Error("HandleCheckTown should restart the wait timer after the timeout fallback")
    if (townPlayer.clicks.Length != 1 || townPlayer.clicks[1] != "return_stone.bmp")
        throw Error("HandleCheckTown should click the return stone when waiting for town times out")

    ; 刚进入等待时不应点回城石
    townBot2 := Bot(MakeCfg(), logger, townPlayer, townStore, townRunner)
    townBot2.hwnd := 123
    beforeClicks := townPlayer.clicks.Length
    townBot2.HandleCheckTown()
    if (townPlayer.clicks.Length != beforeClicks)
        throw Error("HandleCheckTown should not click the return stone while still within the wait window")

    ; 在土城直接进图
    townPlayer.picResults["town.bmp"] := true
    townBot2.HandleCheckTown()
    if (townBot2.state != "RunEnterScript")
        throw Error("HandleCheckTown should move to RunEnterScript when the town picture is found")

    ; ===== 场景 7：监测按 MonitorIntervalMs 节流 =====
    monitorPlayer := FakePlayer()
    monitorPlayer.picResults["map3.bmp"] := true
    monitorStore := FakeStore()
    monitorRunner := FakeRunner()
    monitorBot := Bot(MakeCfg(), logger, monitorPlayer, monitorStore, monitorRunner)
    monitorBot.hwnd := 123
    monitorBot.currentScript := {name: "图1", type: "enter_map", steps: [{id: "s1"}], targetMapImage: "map3.bmp", targetMapRegion: ""}
    monitorBot.lastMonitorCheckTime := A_TickCount
    monitorBot.HandleMonitoring()
    if (monitorPlayer.picCalls.Length != 0)
        throw Error("HandleMonitoring should skip the map check within MonitorIntervalMs of the last check")
    monitorBot.lastMonitorCheckTime := A_TickCount - 20000
    monitorBot.HandleMonitoring()
    if (monitorPlayer.picCalls.Length != 1 || monitorPlayer.picCalls[1] != "map3.bmp")
        throw Error("HandleMonitoring should run the map check after MonitorIntervalMs has elapsed")

    WriteStatus(0)
    ExitApp(0)
} catch as err {
    WriteStatus(1)
    WriteFailure(err.Message)
    ExitApp(1)
}
