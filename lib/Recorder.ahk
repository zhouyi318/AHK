; ===== 脚本录制器模块 =====
; 录制用户的鼠标点击操作，生成可回放的步骤序列。
; 支持自动录制左/右键点击，以及手动插入"等待"和"找图校验"步骤。
;
; 步骤数据结构（x/y 为绑定窗口客户区相对坐标）：
;   点击：{type:"click",   x:640, y:360, button:"L", delay:500}   delay=与上一步间隔(ms)，首步为 0
;   等待：{type:"wait",    ms:3000}
;   找图：{type:"findPic", image:"npc.bmp", timeout:10000, region:{x1,y1,x2,y2}}

class Recorder {
    __New() {
        this.recording := false
        this.captureSuspended := false
        this.steps := []
        this.lastTime := 0      ; 上一次操作的时间戳，用于计算 delay
        this.onStep := ""       ; 每录到一步的回调 callback(step)，用于 GUI 实时刷新列表
        this.lbFn := ""         ; 左键热键回调函数引用
        this.rbFn := ""         ; 右键热键回调函数引用
        this.hwnd := 0          ; 录制绑定的目标窗口
    }

    ; 开始录制。hwnd 为绑定窗口句柄；onStep 为可选回调，每录到一步会被调用
    Start(hwnd, onStep := "") {
        this.recording := true
        this.steps := []
        this.onStep := onStep
        this.lastTime := A_TickCount
        this.hwnd := hwnd

        ; 用 ~（波浪号）非拦截方式监听，原始点击仍会发到游戏
        ; 用 *（星号）表示不区分修饰键
        this.lbFn := this.RecordClick.Bind(this, "L")
        this.rbFn := this.RecordClick.Bind(this, "R")
        this.captureSuspended := false
        this.RegisterHooks()
    }

    ; 内部方法：记录一次点击
    RecordClick(button, *) {
        if !this.hwnd
            return
        MouseGetPos(&mx, &my, &mhwnd)
        if (mhwnd != this.hwnd)
            return
        if !this.ScreenToClient(this.hwnd, mx, my, &clientX, &clientY)
            return
        delay := A_TickCount - this.lastTime
        step := {type:"click", x:clientX, y:clientY, button:button, delay:delay}
        this.steps.Push(step)
        this.lastTime := A_TickCount
        cb := this.onStep
        if cb
            cb(step)
    }

    ; 手动插入等待步骤（不更新 lastTime，不影响后续点击的 delay 计算）
    AddWait(ms) {
        step := {type:"wait", ms:ms}
        this.steps.Push(step)
        cb := this.onStep
        if cb
            cb(step)
    }

    ; 手动插入找图校验步骤
    AddFindPic(image, timeout, region := "") {
        step := {type:"findPic", image:image, timeout:timeout}
        if (region && IsObject(region))
            step.region := region
        this.steps.Push(step)
        cb := this.onStep
        if cb
            cb(step)
    }

    ; 停止录制，注销热键，返回步骤数组
    Stop() {
        this.recording := false
        this.captureSuspended := false
        this.UnregisterHooks()
        this.hwnd := 0
        return this.steps
    }

    ; 返回当前步骤数组（不停止录制）
    GetSteps() {
        return this.steps
    }

    SuspendCapture() {
        if !this.recording
            return
        this.captureSuspended := true
        this.UnregisterHooks()
    }

    ResumeCapture(resetDelayBase := true) {
        if !this.recording
            return
        if (resetDelayBase)
            this.lastTime := A_TickCount
        this.captureSuspended := false
        this.RegisterHooks()
    }

    RegisterHooks() {
        ; 选项 "On" 确保：若热键曾被关闭过，重新注册时会重新启用
        Hotkey "~*LButton", this.lbFn, "On"
        Hotkey "~*RButton", this.rbFn, "On"
    }

    UnregisterHooks() {
        Hotkey "~*LButton", "Off"
        Hotkey "~*RButton", "Off"
    }

    ScreenToClient(hwnd, screenX, screenY, &clientX, &clientY) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        clientX := screenX - cx
        clientY := screenY - cy
        if (clientX < 0 || clientY < 0 || clientX >= cw || clientY >= ch)
            return false
        return true
    }
}
