; ===== 窗口选择器（瞄准镜交互）模块 =====
; 类似按键精灵的"窗口选择工具"：调用 Start(callback) 后，鼠标光标变为十字瞄准镜，
; 移动到目标游戏窗口上左键点击即可锁定该窗口信息（句柄/进程名/标题/客户区宽高），
; 按 ESC 取消选择。选中后通过回调 callback(hwnd, exeName, title, w, h) 返回数据。
; AHK v2 语法

class WindowPicker {
    __New() {
        this.picking := false
        this.timerFn := ""
        this.callback := ""
        this.lButtonFn := ""
        this.enterFn := ""
        this.numpadEnterFn := ""
        this.escapeFn := ""
        this.hoveredHwnd := 0
        this.lastLButtonDown := false
    }

    ; ===== 开始窗口选择模式 =====
    ; callback 签名：callback(hwnd, exeName, title, w, h)
    Start(callback) {
        if this.picking
            return
        this.callback := callback
        this.picking := true
        this.hoveredHwnd := 0
        this.lastLButtonDown := false

        ; 鼠标光标改为十字瞄准镜：加载 IDC_CROSS(32515)，替换普通箭头 OCR_NORMAL(32512)
        hCursor := DllCall("LoadCursor", "ptr", 0, "ptr", 32515, "ptr")
        DllCall("SetSystemCursor", "ptr", hCursor, "ptr", 32512)

        ; 启动定时器（100ms）：实时显示鼠标下窗口信息，方便用户确认
        this.timerFn := this.PickTimer.Bind(this)
        SetTimer this.timerFn, 100

        ; 注册临时热键：左键确认选中、ESC 取消（用 Bind 确保回调能访问到 this）
        this.lButtonFn := this.OnLButton.Bind(this)
        this.enterFn := this.OnEnter.Bind(this)
        this.numpadEnterFn := this.OnEnter.Bind(this)
        this.escapeFn := this.OnEscape.Bind(this)
        Hotkey "*LButton", this.lButtonFn, "On"
        Hotkey "Enter", this.enterFn, "On"
        Hotkey "NumpadEnter", this.numpadEnterFn, "On"
        Hotkey "Escape", this.escapeFn, "On"
    }

    ; ===== 结束窗口选择模式 =====
    Stop() {
        if !this.picking
            return
        this.picking := false

        ; 停止定时器
        if this.timerFn
            SetTimer this.timerFn, 0

        ; 注销临时热键
        Hotkey "*LButton", "Off"
        Hotkey "Enter", "Off"
        Hotkey "NumpadEnter", "Off"
        Hotkey "Escape", "Off"

        ; 恢复系统默认光标（SPI_SETCURSORS=0x0057）
        DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)

        ; 清除 ToolTip
        ToolTip
        this.hoveredHwnd := 0
        this.lastLButtonDown := false
    }

    ; ===== 定时器回调：更新瞄准提示 =====
    PickTimer() {
        hwnd := this.ResolveHoveredWindow()
        this.hoveredHwnd := hwnd
        if hwnd {
            title := WinGetTitle("ahk_id " hwnd)
            exeName := WinGetProcessName("ahk_id " hwnd)
            ToolTip "瞄准中: " title " (" exeName ")`n左键或回车确认，ESC 取消"
        } else {
            ToolTip "瞄准中: (未指向窗口)`n左键或回车确认，ESC 取消"
        }
        this.CheckPollingConfirm()
    }

    ; ===== 左键热键回调：确认选中窗口 =====
    OnLButton(*) {
        if !this.picking
            return
        this.SelectHoveredWindow()
    }

    OnEnter(*) {
        if !this.picking
            return
        this.SelectHoveredWindow()
    }

    ; ===== ESC 热键回调：取消选择 =====
    OnEscape(*) {
        this.Stop()
    }

    ResolveHoveredWindow() {
        MouseGetPos(&mx, &my, &mhwnd)
        if mhwnd
            return this.NormalizeRootWindow(mhwnd)

        pt := Buffer(8, 0)
        if !DllCall("GetCursorPos", "Ptr", pt.Ptr)
            return 0
        rawHwnd := DllCall("WindowFromPoint", "Int64", NumGet(pt, 0, "Int64"), "Ptr")
        if !rawHwnd
            return 0
        return this.NormalizeRootWindow(rawHwnd)
    }

    NormalizeRootWindow(hwnd) {
        if !hwnd
            return 0
        rootHwnd := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
        return rootHwnd ? rootHwnd : hwnd
    }

    SelectHoveredWindow() {
        hwnd := this.ResolveHoveredWindow()
        if !hwnd
            return
        this.hoveredHwnd := hwnd
        title := WinGetTitle("ahk_id " hwnd)
        exeName := WinGetProcessName("ahk_id " hwnd)
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        if this.callback
            this.callback.Call(hwnd, exeName, title, cw, ch)
        this.Stop()
    }

    CheckPollingConfirm() {
        if !this.picking
            return
        currentDown := this.IsPhysicalLButtonDown()
        if (currentDown && !this.lastLButtonDown)
            this.SelectHoveredWindow()
        this.lastLButtonDown := currentDown
    }

    IsPhysicalLButtonDown() {
        return GetKeyState("LButton", "P")
    }
}
