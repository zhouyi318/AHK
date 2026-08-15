#Requires AutoHotkey v2.0

#Include ..\lib\WindowPicker.ahk

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

class ResultSink {
    __New() {
        this.count := 0
        this.lastHwnd := 0
    }

    OnPicked(hwnd, exeName, title, w, h) {
        this.count += 1
        this.lastHwnd := hwnd
    }
}

class PollingWindowPicker extends WindowPicker {
    __New(hwndToReturn) {
        super.__New()
        this.testHwnd := hwndToReturn
        this.down := false
    }

    ResolveHoveredWindow() {
        return this.testHwnd
    }

    IsPhysicalLButtonDown() {
        return this.down
    }
}

try {
    probeGui := Gui(, "Window Picker Polling Confirm Regression")
    probeGui.Add("Text", "x20 y20 w220 h30", "probe")
    probeGui.Show("x260 y220 w260 h140")
    hwnd := probeGui.Hwnd

    sink := ResultSink()
    picker := PollingWindowPicker(hwnd)
    picker.callback := ObjBindMethod(sink, "OnPicked")
    picker.picking := true

    picker.CheckPollingConfirm()
    if (sink.count != 0)
        throw Error("Picker should not confirm before button down")

    picker.down := true
    picker.CheckPollingConfirm()
    if (sink.count != 1)
        throw Error("Picker should confirm on physical left button edge, got " sink.count)
    if (sink.lastHwnd != hwnd)
        throw Error("Picker should capture hovered hwnd when polling confirms")

    probeGui.Destroy()
    WriteStatus(0)
    ExitApp(0)
} catch {
    try probeGui.Destroy()
    WriteStatus(1)
    ExitApp(1)
}
