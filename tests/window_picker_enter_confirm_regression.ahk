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

probeGui := Gui(, "Window Picker Enter Confirm Regression")
probeGui.Add("Text", "x20 y20 w220 h30", "probe")
probeGui.Show("x220 y200 w280 h150")
hwnd := probeGui.Hwnd

WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
MouseMove(cx + 50, cy + 50, 0)

picker.Start(ObjBindMethod(sink, "OnPicked"))
Sleep 150
SendLevel 1
SendEvent "{Enter}"
Sleep 150

if (sink.count != 1)
    throw Error("Pressing Enter should confirm the hovered window, got " sink.count)
if (sink.lastHwnd != hwnd)
    throw Error("Enter confirmation should capture probe hwnd")

probeGui.Destroy()
ExitApp(0)
