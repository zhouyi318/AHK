#Requires AutoHotkey v2.0

#Include ..\lib\WindowPicker.ahk

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

sink := ResultSink()
picker := WindowPicker()

probeGui := Gui(, "Window Picker Restart Regression")
probeGui.Add("Text", "x20 y20 w220 h30", "probe")
probeGui.Show("x180 y160 w260 h140")
hwnd := probeGui.Hwnd

ClickProbe() {
    global probeGui
    WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " probeGui.Hwnd)
    MouseMove(cx + 40, cy + 40, 0)
    SendLevel 1
    SendEvent "{LButton}"
    Sleep 150
}

picker.Start(ObjBindMethod(sink, "OnPicked"))
ClickProbe()
if (sink.count != 1)
    throw Error("First picker click should succeed, got " sink.count)
if (sink.lastHwnd != hwnd)
    throw Error("First picker click should capture probe hwnd")

picker.Start(ObjBindMethod(sink, "OnPicked"))
ClickProbe()
if (sink.count != 2)
    throw Error("Second picker click should still succeed after restart, got " sink.count)
if (sink.lastHwnd != hwnd)
    throw Error("Second picker click should capture probe hwnd")

probeGui.Destroy()
ExitApp(0)
