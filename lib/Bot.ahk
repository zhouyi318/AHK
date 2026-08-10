; ===== 主循环状态机（传奇私服进出图调度）=====
; 状态流转：
;   CheckTown(检测土城) ──在土城──> RunEnterScript(轮换进图)
;          │不在                          │
;          └等待重检                       ↓
;                                  VerifyMap(校验地图)
;                                       │不一致→点回城石→CheckTown
;                                       ↓一致
;                                  EnableAutoFight(开挂机+校验)
;                                       │失败3次→点回城石→CheckTown
;                                       ↓开启
;                                  Monitoring(持续监测)
;                                       │到存仓时间→StoreItems→回Monitoring
;                                       │死亡回城→CheckTown
;   异常(随时): HandleDisconnect / HandleDead → 回 CheckTown

class Bot {
    __New(cfg, logger, player, store) {
        this.cfg := cfg
        this.log := logger
        this.player := player
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
        if this.CheckPic("Town") {
            this.log.Info("在土城，准备进图")
            this.SetState("RunEnterScript")
        }
        ; 不在土城则继续等待
    }

    ; ===== 状态：轮换执行进图脚本 =====
    HandleRunEnterScript() {
        scripts := this.store.ListScripts()
        if (scripts.Length = 0) {
            this.log.Warn("没有进图脚本，等待")
            this.SetState("CheckTown")
            return
        }
        ; 轮换索引：上次0则本次1，依次循环
        this.lastScriptIndex := Mod(this.lastScriptIndex + 1, scripts.Length)
        name := scripts[this.lastScriptIndex + 1]  ; AHK 数组 1-based
        script := this.store.LoadScript(name)
        if (!script || !script.HasProp("steps")) {
            this.log.Error("加载脚本失败: " name)
            this.SetState("CheckTown")
            return
        }
        this.currentScript := script
        this.log.Info("执行进图脚本: " name)
        this.player.Play(script.steps, this.hwnd)
        Sleep 1000
        this.SetState("VerifyMap")
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
        if this.player.FindPic(script.targetMapImage, this.hwnd, &x, &y, region, "地图校验") {
            this.log.Info("地图校验通过")
            this.SetState("EnableAutoFight")
        } else {
            this.log.Warn("地图校验失败，点回城石回土城")
            this.ClickConfigPic("ReturnStone", "回城石")
            Sleep 3000
            this.SetState("CheckTown")
        }
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
        }
    }

    ; 检查配置里某张图是否出现（按 Images 配置项名）
    CheckPic(imgKey) {
        imgName := this.cfg.Images.%imgKey%
        if (imgName = "")
            return false
        return this.player.FindPic(imgName, this.hwnd, &x, &y, this.GetImageRegion(imgKey))
    }

    ClickConfigPic(imgKey, logLabel := "") {
        imgName := this.cfg.Images.%imgKey%
        if (imgName = "")
            return false
        return this.player.ClickPic(imgName, this.hwnd, this.GetImageRegion(imgKey), logLabel)
    }

    GetImageRegion(imgKey) {
        if !this.cfg.HasProp("ImageRegions")
            return ""
        return this.cfg.ImageRegions.%imgKey%
    }
}
