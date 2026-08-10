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
        this.escapeFn := ""
    }

    ; ===== 开始窗口选择模式 =====
    ; callback 签名：callback(hwnd, exeName, title, w, h)
    Start(callback) {
        if this.picking
            return
        this.callback := callback
        this.picking := true

        ; 鼠标光标改为十字瞄准镜：加载 IDC_CROSS(32515)，替换普通箭头 OCR_NORMAL(32512)
        hCursor := DllCall("LoadCursor", "ptr", 0, "ptr", 32515, "ptr")
        DllCall("SetSystemCursor", "ptr", hCursor, "ptr", 32512)

        ; 启动定时器（100ms）：实时显示鼠标下窗口信息，方便用户确认
        this.timerFn := this.PickTimer.Bind(this)
        SetTimer this.timerFn, 100

        ; 注册临时热键：左键确认选中、ESC 取消（用 Bind 确保回调能访问到 this）
        this.lButtonFn := this.OnLButton.Bind(this)
        this.escapeFn := this.OnEscape.Bind(this)
        Hotkey "*LButton", this.lButtonFn
        Hotkey "Escape", this.escapeFn
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
        Hotkey "Escape", "Off"

        ; 恢复系统默认光标（SPI_SETCURSORS=0x0057）
        DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)

        ; 清除 ToolTip
        ToolTip
    }

    ; ===== 定时器回调：更新瞄准提示 =====
    PickTimer() {
        MouseGetPos(&mx, &my, &mhwnd, &mcontrol)
        if mhwnd {
            title := WinGetTitle("ahk_id " mhwnd)
            exeName := WinGetProcessName("ahk_id " mhwnd)
            ToolTip "瞄准中: " title " (" exeName ")"
        } else {
            ToolTip "瞄准中: (未指向窗口)"
        }
    }

    ; ===== 左键热键回调：确认选中窗口 =====
    OnLButton(*) {
        if !this.picking
            return
        MouseGetPos(&mx, &my, &mhwnd, &mcontrol)
        if !mhwnd
            return
        ; 获取窗口信息：标题、进程名、客户区宽高
        title := WinGetTitle("ahk_id " mhwnd)
        exeName := WinGetProcessName("ahk_id " mhwnd)
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " mhwnd)
        ; 回调返回窗口信息，然后结束选择模式
        if this.callback
            this.callback.Call(mhwnd, exeName, title, cw, ch)
        this.Stop()
    }

    ; ===== ESC 热键回调：取消选择 =====
    OnEscape(*) {
        this.Stop()
    }
}
