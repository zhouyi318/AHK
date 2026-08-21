; ===== 脚本回放器模块 =====
; 按录制的步骤序列回放：点击 / 等待 / 找图校验
; 录制脚本里的点击坐标使用绑定窗口客户区相对坐标

class Player {
    __New(imageHelper, cfg, logger) {
        this.img := imageHelper
        this.cfg := cfg
        this.log := logger
    }

    ; 回放步骤序列，返回 true 成功，false 失败（找图超时等）
    Play(steps, hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd) {
            this.log.Warn("回放失败：绑定窗口不存在")
            return false
        }
        if !WinActive("ahk_id " hwnd) {
            WinActivate "ahk_id " hwnd
            try WinWaitActive("ahk_id " hwnd, , 1)
        }
        for i, step in steps {
            switch step.type {
                case "click":
                    if (step.delay > 0)
                        Sleep step.delay
                    if !this.DoClientClick(hwnd
                        , step.x
                        , step.y
                        , step.button
                        , step.HasProp("repeat") ? step.repeat : 1
                        , step.HasProp("intervalMs") ? step.intervalMs : 0) {
                        this.log.Warn("回放点击失败: (" step.x "," step.y ")")
                        return false
                    }
                case "mouse_action":
                    if (step.HasProp("delay") && step.delay > 0)
                        Sleep step.delay
                    if !this.DoClientMouseAction(hwnd
                        , step.x
                        , step.y
                        , step.HasProp("button") ? step.button : "R"
                        , step.HasProp("action") ? step.action : "hold"
                        , step.HasProp("holdMs") ? step.holdMs : 0) {
                        this.log.Warn("回放鼠标动作失败: (" step.x "," step.y ")")
                        return false
                    }
                case "wait":
                    Sleep step.ms
                case "findPic":
                    region := step.HasProp("region") ? step.region : ""
                    if !this.WaitForPic(step.image, step.timeout, hwnd, region, "回放找图") {
                        return false
                    }
            }
        }
        return true
    }

    ; 把客户区相对坐标换成屏幕坐标
    ResolveClientClick(hwnd, x, y, &screenX, &screenY) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        if (x < 0 || y < 0 || x >= cw || y >= ch)
            return false
        screenX := cx + x
        screenY := cy + y
        return true
    }

    ; 执行一次或多次客户区点击
    DoClientClick(hwnd, x, y, button, repeat := 1, intervalMs := 0) {
        if !hwnd || !WinExist("ahk_id " hwnd) {
            this.log.Warn("点击失败: 窗口不存在 hwnd=" hwnd)
            return false
        }
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        if (x < 0 || y < 0 || x >= cw || y >= ch) {
            this.log.Warn("点击失败: 坐标越界 (" x "," y ") 客户区=" cw "x" ch)
            return false
        }
        if !this.MoveCursorToClient(hwnd, x, y) {
            this.log.Warn("点击失败: 移动光标失败 (" x "," y ")")
            return false
        }
        buttonName := (button = "R") ? "Right" : "Left"
        clickCount := repeat is Number ? Integer(repeat) : 1
        if (clickCount < 1)
            clickCount := 1
        interval := intervalMs is Number ? Integer(intervalMs) : 0
        if (interval < 0)
            interval := 0
        if (interval = 0) {
            this.ControlClientClick(hwnd, x, y, buttonName, clickCount)
            this.log.Info("点击执行: (" x "," y ") 按钮=" buttonName " 次数=" clickCount)
            return true
        }
        Loop clickCount {
            this.ControlClientClick(hwnd, x, y, buttonName, 1)
            if (A_Index < clickCount && interval > 0)
                Sleep interval
        }
        this.log.Info("点击执行: (" x "," y ") 按钮=" buttonName " 次数=" clickCount " 间隔=" interval "ms")
        return true
    }

    ; 物理点击：激活窗口后用真实鼠标点击（游戏可能忽略后台左键消息）
    ; 顺序：移动鼠标到坐标 -> 延迟 delayMs -> 执行 repeat 次点击（间隔 intervalMs）
    DoPhysicalClientClick(hwnd, x, y, button, repeat := 1, intervalMs := 0, delayMs := 0) {
        if !hwnd || !WinExist("ahk_id " hwnd) {
            this.log.Warn("物理点击失败: 窗口不存在 hwnd=" hwnd)
            return false
        }
        if !this.ResolveClientClick(hwnd, x, y, &screenX, &screenY) {
            this.log.Warn("物理点击失败: 坐标越界 (" x "," y ")")
            return false
        }
        try WinActivate("ahk_id " hwnd)
        Sleep 300
        CoordMode("Mouse", "Screen")
        SendMode("Event")  ; 老游戏对 Event 模式兼容性更好
        MouseMove(screenX, screenY, 0)
        Sleep 50
        preClickDelay := delayMs is Number ? Integer(delayMs) : 0
        if (preClickDelay < 0)
            preClickDelay := 0
        if (preClickDelay > 0)
            Sleep preClickDelay
        buttonName := (button = "R") ? "Right" : "Left"
        clickCount := repeat is Number ? Integer(repeat) : 1
        if (clickCount < 1)
            clickCount := 1
        interval := intervalMs is Number ? Integer(intervalMs) : 0
        if (interval < 0)
            interval := 0
        Loop clickCount {
            ; 显式 down/up，比 MouseClick 更可靠（部分游戏需要完整按下-抬起序列）
            MouseClick(buttonName, screenX, screenY, , 0, "D")
            Sleep 60
            MouseClick(buttonName, screenX, screenY, , 0, "U")
            if (A_Index < clickCount && interval > 0)
                Sleep interval
        }
        this.log.Info("物理点击执行: (" x "," y ") 屏幕=(" screenX "," screenY ") 按钮=" buttonName " 次数=" clickCount (preClickDelay > 0 ? " 点击前延迟=" preClickDelay "ms" : ""))
        return true
    }

    ; 顺序：移动鼠标到坐标 -> 延迟 delayMs -> 执行按下/按住/抬起
    DoClientMouseAction(hwnd, x, y, button, action, holdMs := 0, delayMs := 0) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        if (x < 0 || y < 0 || x >= cw || y >= ch)
            return false
        if !this.MoveCursorToClient(hwnd, x, y)
            return false
        preActionDelay := delayMs is Number ? Integer(delayMs) : 0
        if (preActionDelay < 0)
            preActionDelay := 0
        if (preActionDelay > 0)
            Sleep preActionDelay

        buttonToken := this.ResolveMouseButtonToken(button)
        if (buttonToken = "")
            return false
        actionName := action = "" ? "hold" : action
        holdTime := holdMs is Number ? Integer(holdMs) : 0
        if (holdTime < 0)
            holdTime := 0

        switch actionName {
            case "hold":
                this.SendClientMouseButtonDown(hwnd, x, y, buttonToken)
                if (holdTime > 0)
                    Sleep holdTime
                this.SendClientMouseButtonUp(hwnd, x, y, buttonToken)
                return true
            case "down":
                this.SendClientMouseButtonDown(hwnd, x, y, buttonToken)
                return true
            case "up":
                this.SendClientMouseButtonUp(hwnd, x, y, buttonToken)
                return true
            default:
                return false
        }
    }

    BeginPhysicalClientMouseHold(hwnd, x, y, button := "R") {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        if (x < 0 || y < 0 || x >= cw || y >= ch)
            return false
        if !this.MoveCursorToClient(hwnd, x, y)
            return false
        buttonToken := this.ResolveMouseButtonToken(button)
        if (buttonToken = "")
            return false
        this.SendPhysicalMouseButton(this.ResolveMouseButtonSendName(buttonToken), "down")
        return true
    }

    UpdatePhysicalClientMouseHold(hwnd, x, y) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        if (x < 0 || y < 0 || x >= cw || y >= ch)
            return false
        return this.MoveCursorToClient(hwnd, x, y)
    }

    EndPhysicalMouseHold(button := "R") {
        buttonToken := this.ResolveMouseButtonToken(button)
        if (buttonToken = "")
            return false
        this.SendPhysicalMouseButton(this.ResolveMouseButtonSendName(buttonToken), "up")
        return true
    }

    ResolveSearchRect(hwnd, region, &x1, &y1, &x2, &y2) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        if (!region || !IsObject(region)) {
            x1 := cx
            y1 := cy
            x2 := cx + cw - 1
            y2 := cy + ch - 1
            return true
        }
        left := Max(Min(region.x1, region.x2), 0)
        top := Max(Min(region.y1, region.y2), 0)
        right := Min(Max(region.x1, region.x2), cw - 1)
        bottom := Min(Max(region.y1, region.y2), ch - 1)
        if (right <= left || bottom <= top)
            return false
        x1 := cx + left
        y1 := cy + top
        x2 := cx + right
        y2 := cy + bottom
        return true
    }

    ; 等待图片出现，超时返回 false
    WaitForPic(imageName, timeout, hwnd, region := "", logLabel := "", simOverride := "") {
        assetsDir := A_ScriptDir "\" this.cfg.Paths.AssetsDir
        imgPath := assetsDir "\" imageName
        simValue := this.ResolveSimValue(simOverride)
        if !FileExist(imgPath) {
            this.log.Warn("回放找图: 文件不存在 " imgPath)
            return false
        }
        start := A_TickCount
        loop {
            if !this.ResolveSearchRect(hwnd, region, &x1, &y1, &x2, &y2) {
                if (logLabel != "")
                    this.log.Warn(logLabel "区域无效: " imageName " 区域" this.RegionText(region))
                return false
            }
            if this.img.FindPic(x1, y1, x2, y2, imgPath, simValue, &fx, &fy) {
                if (logLabel != "")
                    this.log.Info(logLabel "成功: " imageName " " this.HitPointText(hwnd, fx, fy) " 区域" this.RegionText(region) " 相似度" this.SimText(simValue))
                return true
            }
            if (A_TickCount - start > timeout) {
                if (logLabel != "")
                    this.log.Warn(logLabel "超时: " imageName " 区域" this.RegionText(region) " 超时" timeout "ms 相似度" this.SimText(simValue))
                return false
            }
            Sleep 200
        }
    }

    ; 单次找图（不带等待），返回 true/false 并输出坐标
    FindPic(imageName, hwnd, &outX, &outY, region := "", logLabel := "", simOverride := "") {
        assetsDir := A_ScriptDir "\" this.cfg.Paths.AssetsDir
        imgPath := assetsDir "\" imageName
        simValue := this.ResolveSimValue(simOverride)
        if !FileExist(imgPath) {
            if (logLabel != "")
                this.log.Warn(logLabel "文件不存在: " imgPath)
            return false
        }
        if !this.ResolveSearchRect(hwnd, region, &x1, &y1, &x2, &y2) {
            if (logLabel != "")
                this.log.Warn(logLabel "区域无效: " imageName " 区域" this.RegionText(region))
            return false
        }
        found := this.img.FindPic(x1, y1, x2, y2, imgPath, simValue, &outX, &outY)
        if (logLabel != "") {
            if found
                this.log.Info(logLabel "成功: " imageName " " this.HitPointText(hwnd, outX, outY) " 区域" this.RegionText(region) " 相似度" this.SimText(simValue))
            else
                this.log.Warn(logLabel "失败: " imageName " 区域" this.RegionText(region) " 相似度" this.SimText(simValue))
        }
        return found
    }

    ; 点击指定图片（找到则点击返回 true）
    ClickPic(imageName, hwnd, region := "", logLabel := "") {
        if this.FindPic(imageName, hwnd, &x, &y, region) {
            if this.ScreenToClient(hwnd, x, y, &clientX, &clientY) {
                if this.DoClientClick(hwnd, clientX, clientY, "L") {
                    if (logLabel != "")
                        this.log.Info(logLabel "点击成功: " imageName " 客户区(" clientX "," clientY ") 区域" this.RegionText(region))
                    return true
                }
            }
        }
        if (logLabel != "")
            this.log.Warn(logLabel "点击失败: " imageName " 区域" this.RegionText(region))
        return false
    }

    ScreenToClient(hwnd, screenX, screenY, &clientX, &clientY) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        if !this.HasNumericCoords(screenX, screenY)
            return false
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        clientX := screenX - cx
        clientY := screenY - cy
        if (clientX < 0 || clientY < 0 || clientX >= cw || clientY >= ch)
            return false
        return true
    }

    RegionText(region) {
        if (!region || !IsObject(region))
            return "(全窗口)"
        return "(" region.x1 "," region.y1 ")-(" region.x2 "," region.y2 ")"
    }

    HitPointText(hwnd, screenX, screenY) {
        if !this.HasNumericCoords(screenX, screenY)
            return "坐标(未知)"
        if this.ScreenToClient(hwnd, screenX, screenY, &clientX, &clientY)
            return "屏幕(" screenX "," screenY ") 客户区(" clientX "," clientY ")"
        return "屏幕(" screenX "," screenY ")"
    }

    MoveCursorToClient(hwnd, x, y) {
        if !this.ResolveClientClick(hwnd, x, y, &screenX, &screenY)
            return false
        MouseMove(screenX, screenY, 0)
        return true
    }

    HasNumericCoords(x, y) {
        return (x is Number) && (y is Number)
    }

    ResolveSimValue(simOverride := "") {
        if (simOverride = "" || !(simOverride is Number))
            return this.cfg.Bot.Sim
        if (simOverride < 0.10)
            return 0.10
        if (simOverride > 1.00)
            return 1.00
        return simOverride
    }

    SimText(simValue) {
        return Format("{:.2f}", simValue)
    }

    ResolveMouseButtonToken(button) {
        switch button {
            case "R", "Right":
                return "Right"
            case "M", "Middle":
                return "Middle"
            case "L", "Left", "":
                return "Left"
            default:
                return ""
        }
    }

    ResolveMouseButtonSendName(buttonToken) {
        switch buttonToken {
            case "Right":
                return "RButton"
            case "Middle":
                return "MButton"
            case "Left":
                return "LButton"
            default:
                return ""
        }
    }

    SendPhysicalMouseButton(buttonToken, action) {
        if (buttonToken = "")
            return
        actionName := StrLower(action)
        SendEvent("{" buttonToken " " actionName "}")
    }

    SendClientMouseButtonDown(hwnd, x, y, buttonToken) {
        msg := 0x0201
        wParam := 0x0001
        switch buttonToken {
            case "Right":
                msg := 0x0204
                wParam := 0x0002
            case "Middle":
                msg := 0x0207
                wParam := 0x0010
        }
        PostMessage(msg, wParam, this.MakeClientLParam(x, y), , "ahk_id " hwnd)
    }

    SendClientMouseButtonUp(hwnd, x, y, buttonToken) {
        msg := 0x0202
        switch buttonToken {
            case "Right":
                msg := 0x0205
            case "Middle":
                msg := 0x0208
        }
        PostMessage(msg, 0, this.MakeClientLParam(x, y), , "ahk_id " hwnd)
    }

    MakeClientLParam(x, y) {
        return ((y & 0xFFFF) << 16) | (x & 0xFFFF)
    }

    ControlClientClick(hwnd, x, y, buttonName, clickCount := 1) {
        ControlClick("x" x " y" y, "ahk_id " hwnd, , buttonName, clickCount, "NA Pos")
    }
}
