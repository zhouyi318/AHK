class PointPicker {
    __New() {
        this.active := false
        this.hwnd := 0
        this.callback := ""
        this.prompt := ""
        this.lbDownFn := ""
        this.escapeFn := ""
        this.timerFn := ""
        this.lastPoint := ""
    }

    Start(hwnd, callback, prompt := "请在绑定窗口内点一下要记录的位置，ESC 取消") {
        if this.active
            this.Stop(false)
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        this.hwnd := hwnd
        this.callback := callback
        this.prompt := prompt
        this.lastPoint := ""
        this.active := true
        this.lbDownFn := this.OnLButtonDown.Bind(this)
        this.escapeFn := this.OnEscape.Bind(this)
        this.timerFn := this.UpdateTooltip.Bind(this)

        Hotkey "*LButton", this.lbDownFn, "On"
        Hotkey "Escape", this.escapeFn, "On"
        SetTimer this.timerFn, 30

        WinActivate "ahk_id " hwnd
        ToolTip this.prompt
        return true
    }

    Stop(invokeCallback := false) {
        if !this.active
            return

        SetTimer this.timerFn, 0
        Hotkey "*LButton", "Off"
        Hotkey "Escape", "Off"
        ToolTip

        point := this.lastPoint
        callback := this.callback

        this.active := false
        this.hwnd := 0
        this.callback := ""
        this.prompt := ""
        this.lastPoint := ""

        if (invokeCallback && IsObject(point) && callback)
            callback.Call(point)
    }

    OnLButtonDown(*) {
        if !this.active
            return
        MouseGetPos(&mx, &my, &mhwnd)
        if (mhwnd != this.hwnd)
            return
        if !this.ScreenToClient(this.hwnd, mx, my, &clientX, &clientY)
            return
        this.lastPoint := {x: clientX, y: clientY}
        this.Stop(true)
    }

    OnEscape(*) {
        this.Stop(false)
    }

    UpdateTooltip() {
        if !this.active
            return
        MouseGetPos(&mx, &my)
        if this.ScreenToClient(this.hwnd, mx, my, &clientX, &clientY)
            ToolTip this.prompt . "`n当前: " clientX "," clientY
        else
            ToolTip this.prompt
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
