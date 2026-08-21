; ===== 主循环状态机（传奇私服进出图调度）=====
; 状态流转：
;   CheckTown(检测土城) ──在土城──> RunEnterScript(轮换进图，失败脚本冷却)
;          │不在                          │
;          └等待重检(超时点回城石兜底)      ↓
;                                  VerifyMap(校验地图，重试防加载慢误判)
;                                       │不一致→点回城石→CheckTown
;                                       ↓一致
;                                  EnableAutoFight(开挂机+校验)
;                                       │失败3次→点回城石→CheckTown
;                                       ↓开启
;                                  Monitoring(按 MonitorIntervalMs 节流监测)
;                                       │到存仓时间→StoreItems→回Monitoring
;                                       │死亡回城→CheckTown
;   异常(随时): HandleDisconnect / HandleDead → 回 CheckTown

class Bot {
    __New(cfg, logger, player, store, runner := "") {
        this.cfg := cfg
        this.log := logger
        this.player := player
        this.runner := runner ? runner : player
        this.store := store

        this.running := false
        this.state := "Idle"
        this.timerFn := ""

        ; 进图脚本轮换索引（-1 表示尚未执行过）
        this.lastScriptIndex := -1
        ; 当前执行的脚本对象
        this.currentScript := ""
        ; 挂机开启重试计数
        this.autofightRetry := 0
        ; 上次存仓时间
        this.lastStoreTime := A_TickCount
        ; 监测开始时间
        this.monitorStartTime := 0
        ; 上次地图监测找图时间（Monitoring 节流用）
        this.lastMonitorCheckTime := 0
        ; 进入 CheckTown 状态的时间（等待土城超时兜底用）
        this.checkTownSince := 0
        ; 进图脚本连续失败计数（脚本名 -> 连续失败次数）
        this.scriptFailCounts := Map()
        ; 进图脚本失败冷却到期时间（脚本名 -> A_TickCount 时间戳）
        this.scriptCooldowns := Map()
    }

    ; ===== 生命周期 =====

    Start() {
        this.hwnd := this.cfg.Window.Hwnd
        if (!this.hwnd || this.hwnd = "0") {
            this.log.Error("未选择游戏窗口")
            return false
        }
        this.running := true
        this.lastScriptIndex := -1
        this.autofightRetry := 0
        this.lastStoreTime := A_TickCount
        this.SetState("CheckTown")
        this.log.Info("BOT START")
        this.timerFn := this.Step.Bind(this)
        SetTimer this.timerFn, this.cfg.Bot.TickMs
        return true
    }

    Stop() {
        this.running := false
        if this.timerFn
            SetTimer this.timerFn, 0
        this.SetState("Idle")
        this.log.Info("BOT STOP")
    }

    IsRunning() {
        return this.running
    }

    ; 主页运行信息：状态、当前脚本、失败计数、冷却中脚本（供 GUI 周期刷新）
    GetRunOverview() {
        scriptName := ""
        if (IsObject(this.currentScript) && this.currentScript.HasProp("name"))
            scriptName := this.currentScript.name

        failText := ""
        for name, count in this.scriptFailCounts
            failText .= (failText = "" ? "" : ", ") . name . " x" . count

        coolText := ""
        now := A_TickCount
        for name, coolUntil in this.scriptCooldowns {
            if (coolUntil > now)
                coolText .= (coolText = "" ? "" : ", ") . name . " " . Round((coolUntil - now) / 60000, 1) . "分钟"
        }

        return {
            state: this.state,
            running: this.running,
            scriptName: scriptName,
            failText: failText,
            coolText: coolText
        }
    }

    ; ===== 主循环步进 =====

    Step() {
        if !this.running
            return

        ; 窗口检查
        if !WinExist("ahk_id " this.hwnd) {
            this.log.Error("窗口已关闭")
            this.Stop()
            return
        }
        if !WinActive("ahk_id " this.hwnd) {
            WinActivate "ahk_id " this.hwnd
            return
        }

        ; 异常检测（优先级最高，除正在处理异常时）
        if (this.state != "HandleDisconnect" && this.state != "HandleDead") {
            if this.CheckPic("Disconnect") {
                this.log.Warn("检测到掉线")
                this.SetState("HandleDisconnect")
                return
            }
            if this.CheckPic("Dead") {
                this.log.Warn("检测到死亡")
                this.SetState("HandleDead")
                return
            }
        }

        switch this.state {
            case "CheckTown":
                this.HandleCheckTown()
            case "RunEnterScript":
                this.HandleRunEnterScript()
            case "VerifyMap":
                this.HandleVerifyMap()
            case "EnableAutoFight":
                this.HandleEnableAutoFight()
            case "Monitoring":
                this.HandleMonitoring()
            case "StoreItems":
                this.HandleStoreItems()
            case "HandleDisconnect":
                this.HandleDisconnect()
            case "HandleDead":
                this.HandleDead()
            default:
                this.SetState("CheckTown")
        }
    }

    ; ===== 状态：检测在盟重土城 =====
    HandleCheckTown() {
        if (this.checkTownSince = 0)
            this.checkTownSince := A_TickCount
        if this.CheckPic("Town") {
            this.log.Info("在土城，准备进图")
            this.checkTownSince := 0
            this.SetState("RunEnterScript")
            return
        }
        ; 长时间不在土城：可能卡在未知界面，点回城石兜底后继续等
        townTimeout := this.GetBotSetting("CheckTownTimeoutMs", 60000)
        if (A_TickCount - this.checkTownSince > townTimeout) {
            this.log.Warn("等待土城超时，点回城石兜底")
            this.checkTownSince := A_TickCount
            this.ClickConfigPic("ReturnStone", "回城石")
            Sleep 3000
        }
    }

    ; ===== 状态：轮换执行进图脚本 =====
    HandleRunEnterScript() {
        if this.HasCallable(this.store, "ListScriptsByType")
            scripts := this.store.ListScriptsByType("enter_map")
        else
            scripts := this.store.ListScripts()
        if (scripts.Length = 0) {
            this.log.Warn("没有进图脚本，等待")
            this.SetState("CheckTown")
            return
        }
        ; 轮换索引：跳过失败冷却中的脚本，最多轮询一圈
        chosenIndex := 0
        loop scripts.Length {
            this.lastScriptIndex := Mod(this.lastScriptIndex + 1, scripts.Length)
            candidate := scripts[this.lastScriptIndex + 1]  ; AHK 数组 1-based
            if (this.scriptCooldowns.Has(candidate) && A_TickCount < this.scriptCooldowns[candidate]) {
                this.log.Info("脚本 " candidate " 失败冷却中，跳过")
                continue
            }
            chosenIndex := this.lastScriptIndex + 1
            break
        }
        if (chosenIndex = 0) {
            this.log.Warn("所有进图脚本都在冷却中，重置冷却继续轮换")
            this.scriptCooldowns := Map()
            chosenIndex := this.lastScriptIndex + 1
        }
        name := scripts[chosenIndex]
        script := this.store.LoadScript(name)
        if (!script || !script.HasProp("steps")) {
            this.log.Error("加载脚本失败: " name)
            this.SetState("CheckTown")
            return
        }
        this.currentScript := script
        this.log.Info("执行进图脚本: " name)
        if this.HasCallable(this.runner, "RunScript")
            result := this.runner.RunScript(script, this.hwnd, 1)
        else
            result := {ok: this.player.Play(script.steps, this.hwnd)}
        this.RecordEnterScriptResult(name, result)
        Sleep 1000
        this.SetState("VerifyMap")
    }

    ; 记录进图脚本成败：连续失败达阈值进入冷却，成功清零计数
    RecordEnterScriptResult(name, result) {
        runOk := (IsObject(result) && result.HasProp("ok")) ? result.ok : false
        if (runOk) {
            if (this.scriptFailCounts.Has(name))
                this.scriptFailCounts.Delete(name)
            return
        }
        fails := (this.scriptFailCounts.Has(name) ? this.scriptFailCounts[name] : 0) + 1
        this.scriptFailCounts[name] := fails
        this.log.Warn("进图脚本失败: " name "（连续第 " fails " 次）")
        maxFails := this.GetBotSetting("ScriptMaxConsecutiveFails", 3)
        if (fails >= maxFails) {
            cooldownMs := this.GetBotSetting("ScriptFailCooldownMs", 600000)
            this.scriptCooldowns[name] := A_TickCount + cooldownMs
            this.scriptFailCounts.Delete(name)
            this.log.Warn("脚本 " name " 连续失败 " fails " 次，冷却 " Round(cooldownMs / 60000) " 分钟")
        }
    }

    ; 读取 Bot 配置项（缺失时用默认值，兼容测试注入的最小配置对象）
    GetBotSetting(key, defaultValue) {
        try {
            if (IsObject(this.cfg.Bot) && this.cfg.Bot.HasProp(key))
                return this.cfg.Bot.%key%
        } catch {
        }
        return defaultValue
    }

    ; ===== 状态：校验当前地图 =====
    HandleVerifyMap() {
        script := this.currentScript
        ; 无目标地图图则跳过校验
        if (!script.HasProp("targetMapImage") || script.targetMapImage = "") {
            this.log.Info("无目标地图图，跳过校验")
            this.SetState("EnableAutoFight")
            return
        }
        region := script.HasProp("targetMapRegion") ? script.targetMapRegion : ""
        ; 进图后地图加载需要时间：重试多次，全部失败才回城，避免加载慢被误判
        retry := this.GetBotSetting("VerifyMapRetry", 5)
        retryInterval := this.GetBotSetting("VerifyMapRetryIntervalMs", 2000)
        loop retry {
            if this.player.FindPic(script.targetMapImage, this.hwnd, &x, &y, region, "地图校验") {
                this.log.Info("地图校验通过")
                this.SetState("EnableAutoFight")
                return
            }
            if (A_Index < retry && retryInterval > 0)
                Sleep retryInterval
        }
        this.log.Warn("地图校验失败，点回城石回土城")
        this.ClickConfigPic("ReturnStone", "回城石")
        Sleep 3000
        this.SetState("CheckTown")
    }

    ; ===== 状态：开启自动挂机并校验 =====
    HandleEnableAutoFight() {
        ; 点击挂机按钮
        if !this.ClickConfigPic("AutoFightBtn", "挂机按钮") {
            this.log.Warn("未找到挂机按钮")
        }
        Sleep 1000

        ; 校验挂机已开启
        if this.CheckPic("AutoFightOn") {
            this.log.Info("挂机已开启")
            this.autofightRetry := 0
            this.monitorStartTime := A_TickCount
            this.lastMonitorCheckTime := 0
            this.SetState("Monitoring")
            return
        }

        ; 未开启，重试
        this.autofightRetry += 1
        this.log.Warn("挂机未开启，重试 " this.autofightRetry "/" this.cfg.Bot.AutoFightRetry)
        if (this.autofightRetry >= this.cfg.Bot.AutoFightRetry) {
            this.log.Error("挂机多次开启失败，回城重来")
            this.autofightRetry := 0
            this.ClickConfigPic("ReturnStone", "回城石")
            Sleep 3000
            this.SetState("CheckTown")
        }
        ; 否则留在 EnableAutoFight 继续重试
    }

    ; ===== 状态：持续监测挂机 =====
    HandleMonitoring() {
        ; 检查存仓时间
        intervalMs := this.cfg.Bot.StoreIntervalMin * 60000
        if (A_TickCount - this.lastStoreTime > intervalMs) {
            this.log.Info("到存仓时间")
            this.SetState("StoreItems")
            return
        }

        ; 地图校验找图开销大，按 MonitorIntervalMs 节流
        monitorInterval := this.GetBotSetting("MonitorIntervalMs", 10000)
        if (A_TickCount - this.lastMonitorCheckTime < monitorInterval)
            return
        this.lastMonitorCheckTime := A_TickCount

        ; 检查是否仍在挂机地图
        script := this.currentScript
        if (script.HasProp("targetMapImage") && script.targetMapImage != "") {
            region := script.HasProp("targetMapRegion") ? script.targetMapRegion : ""
            if !this.player.FindPic(script.targetMapImage, this.hwnd, &x, &y, region) {
                ; 不在挂机地图，检查是否回土城了（死亡回城）
                if this.CheckPic("Town") {
                    this.log.Warn("已回土城（可能死亡），重新循环")
                    this.SetState("CheckTown")
                }
                ; 既不在挂机图也不在土城，可能在过渡，继续监测
            }
        }
    }

    ; ===== 状态：存装备（识别装备名图+右键存远程仓）=====
    HandleStoreItems() {
        storeCfg := this.store.LoadStoreConfig()
        if (storeCfg.HasProp("flowScriptName") && storeCfg.flowScriptName != "" && this.HasCallable(this.runner, "RunScript")) {
            flowScript := this.store.LoadScript(storeCfg.flowScriptName)
            if (flowScript && flowScript.HasProp("steps")) {
                this.log.Info("执行存仓流程脚本: " . storeCfg.flowScriptName)
                this.runner.RunScript(flowScript, this.hwnd, 1)
                this.lastStoreTime := A_TickCount
                this.SetState("Monitoring")
                return
            }
        }
        itemNames := storeCfg.itemNames
        if (itemNames.Length = 0) {
            this.log.Info("无存仓装备配置，跳过")
            this.lastStoreTime := A_TickCount
            this.SetState("Monitoring")
            return
        }

        ; 对每个装备名，找对应截图并右键存仓
        stored := 0
        for i, itemName in itemNames {
            ; 装备名截图文件名约定：item_<装备名>.bmp
            imgName := "item_" itemName ".bmp"
            ; 可能有多个同类装备，循环查找并右键
            loop 10 {
                if this.player.FindPic(imgName, this.hwnd, &x, &y) {
                    ; 右键点击存入远程仓库
                    MouseMove x, y, 0
                    Click "Right"
                    Sleep 500
                    stored += 1
                } else
                    break
            }
        }
        this.log.Info("存仓完成，存入 " stored " 件")
        this.lastStoreTime := A_TickCount
        this.SetState("Monitoring")
    }

    ; ===== 状态：掉线重连 =====
    HandleDisconnect() {
        if this.CheckPic("Disconnect") {
            this.ClickConfigPic("Disconnect", "重连按钮")
            this.log.Info("点击重新连接")
            Sleep 3000
        } else {
            this.log.Info("重连按钮消失，回 CheckTown")
            this.SetState("CheckTown")
        }
    }

    ; ===== 状态：死亡复活 =====
    HandleDead() {
        if this.CheckPic("Dead") {
            this.ClickConfigPic("Dead", "复活按钮")
            this.log.Info("点击复活")
            Sleep 3000
        } else {
            this.log.Info("复活按钮消失，回 CheckTown")
            this.SetState("CheckTown")
        }
    }

    ; ===== 通用工具 =====

    SetState(s) {
        if (this.state != s) {
            this.state := s
            this.log.State(s)
            if (s = "CheckTown")
                this.checkTownSince := A_TickCount
        }
    }

    ; 检查配置里某张图是否出现（按 Images 配置项名）
    CheckPic(imgKey) {
        imgName := this.GetImageName(imgKey)
        if (imgName = "")
            return false
        return this.player.FindPic(imgName, this.hwnd, &x, &y, this.GetImageRegion(imgKey))
    }

    ClickConfigPic(imgKey, logLabel := "") {
        imgName := this.GetImageName(imgKey)
        if (imgName = "")
            return false
        return this.player.ClickPic(imgName, this.hwnd, this.GetImageRegion(imgKey), logLabel)
    }

    ; 读取 Images 配置项（缺失时返回空串，不抛异常）
    GetImageName(imgKey) {
        try {
            if (IsObject(this.cfg.Images) && this.cfg.Images.HasProp(imgKey))
                return this.cfg.Images.%imgKey%
        } catch {
        }
        return ""
    }

    GetImageRegion(imgKey) {
        try {
            if (this.cfg.HasProp("ImageRegions") && this.cfg.ImageRegions.HasProp(imgKey))
                return this.cfg.ImageRegions.%imgKey%
        } catch {
        }
        return ""
    }

    HasCallable(obj, name) {
        try {
            fn := obj.%name%
            return IsObject(fn)
        } catch {
            return false
        }
    }
}
