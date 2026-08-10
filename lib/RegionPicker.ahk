; ===== 区域选择器 =====
; 在绑定窗口客户区内按下并拖拽鼠标，框选一个相对区域

class RegionPicker {
    __New() {
        this.active := false
        this.dragging := false
        this.hwnd := 0
        this.callback := ""
        this.prompt := ""
        this.startX := 0
        this.startY := 0
        this.currentX := 0
        this.currentY := 0
        this.lbDownFn := ""
        this.lbUpFn := ""
        this.escapeFn := ""
        this.timerFn := ""
        this.overlays := []
    }

    Start(hwnd, callback, prompt := "请在绑定窗口内按住左键拖拽框选区域，ESC 取消") {
        if this.active
            this.Stop(false)
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        this.hwnd := hwnd
        this.callback := callback
        this.prompt := prompt
        this.active := true
        this.dragging := false

        this.EnsureOverlays()
        this.lbDownFn := this.OnLButtonDown.Bind(this)
        this.lbUpFn := this.OnLButtonUp.Bind(this)
        this.escapeFn := this.OnEscape.Bind(this)
        this.timerFn := this.UpdateTooltip.Bind(this)

        Hotkey "*LButton", this.lbDownFn, "On"
        Hotkey "*LButton Up", this.lbUpFn, "On"
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
        Hotkey "*LButton Up", "Off"
        Hotkey "Escape", "Off"
        ToolTip
        this.HideOverlays()

        region := ""
        if (invokeCallback && this.dragging) {
            region := this.NormalizeRegion(this.startX, this.startY, this.currentX, this.currentY)
            if (region.x2 > region.x1 && region.y2 > region.y1) {
                cb := this.callback
                if cb
                    cb.Call(region)
            }
        }

        this.active := false
        this.dragging := false
        this.hwnd := 0
        this.callback := ""
    }

    OnLButtonDown(*) {
        if !this.active
            return
        MouseGetPos(&mx, &my, &mhwnd)
        if (mhwnd != this.hwnd)
            return
        if !this.ScreenToClient(this.hwnd, mx, my, &clientX, &clientY)
            return
        this.dragging := true
        this.startX := clientX
        this.startY := clientY
        this.currentX := clientX
        this.currentY := clientY
        this.UpdateOverlay()
    }

    OnLButtonUp(*) {
        if !this.active || !this.dragging
            return
        MouseGetPos(&mx, &my)
        if this.ScreenToClientClamped(this.hwnd, mx, my, &clientX, &clientY) {
            this.currentX := clientX
            this.currentY := clientY
        }
        this.UpdateOverlay()
        this.Stop(true)
    }

    OnEscape(*) {
        this.Stop(false)
    }

    UpdateTooltip() {
        if !this.active
            return
        if this.dragging {
            MouseGetPos(&mx, &my)
            if this.ScreenToClientClamped(this.hwnd, mx, my, &clientX, &clientY) {
                this.currentX := clientX
                this.currentY := clientY
                this.UpdateOverlay()
                region := this.NormalizeRegion(this.startX, this.startY, this.currentX, this.currentY)
                ToolTip "框选区域: (" region.x1 "," region.y1 ") - (" region.x2 "," region.y2 ")"
            }
        } else {
            ToolTip this.prompt
        }
    }

    NormalizeRegion(x1, y1, x2, y2) {
        left := Min(x1, x2)
        top := Min(y1, y2)
        right := Max(x1, x2)
        bottom := Max(y1, y2)
        return {x1: left, y1: top, x2: right, y2: bottom}
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

    ScreenToClientClamped(hwnd, screenX, screenY, &clientX, &clientY) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        clientX := screenX - cx
        clientY := screenY - cy
        if (clientX < 0)
            clientX := 0
        if (clientY < 0)
            clientY := 0
        if (clientX >= cw)
            clientX := cw - 1
        if (clientY >= ch)
            clientY := ch - 1
        return (cw > 0 && ch > 0)
    }

    EnsureOverlays() {
        if (this.overlays.Length > 0)
            return
        loop 4 {
            overlay := Gui("-Caption +ToolWindow +AlwaysOnTop +E0x20")
            overlay.BackColor := "FFB000"
            this.overlays.Push(overlay)
        }
    }

    HideOverlays() {
        for _, overlay in this.overlays
            overlay.Hide()
    }

    UpdateOverlay() {
        if !this.dragging
            return
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " this.hwnd)
        region := this.NormalizeRegion(this.startX, this.startY, this.currentX, this.currentY)
        left := cx + region.x1
        top := cy + region.y1
        right := cx + region.x2
        bottom := cy + region.y2
        width := Max(right - left + 1, 2)
        height := Max(bottom - top + 1, 2)
        thickness := 2

        this.overlays[1].Show("NA x" left " y" top " w" width " h" thickness)
        this.overlays[2].Show("NA x" left " y" bottom - thickness + 1 " w" width " h" thickness)
        this.overlays[3].Show("NA x" left " y" top " w" thickness " h" height)
        this.overlays[4].Show("NA x" right - thickness + 1 " y" top " w" thickness " h" height)
    }
}
