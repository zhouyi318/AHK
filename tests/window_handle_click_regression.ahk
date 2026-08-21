#Requires AutoHotkey v2.0

#Include ..\lib\Player.ahk

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

class NullLogger {
    Warn(msg) {
    }
}

class CapturePlayer extends Player {
    __New(cfg, logger) {
        super.__New("", cfg, logger)
        this.clickCalls := []
        this.moveCalls := []
    }

    MoveCursorToClient(hwnd, x, y) {
        this.moveCalls.Push(hwnd ":" x ":" y)
        return true
    }

    ControlClientClick(hwnd, x, y, buttonName, clickCount := 1) {
        this.clickCalls.Push(buttonName ":" x ":" y ":" clickCount)
    }
}

try {
    cfgObj := {Paths: {AssetsDir: "assets"}, Bot: {Sim: 0.9}}
    playerObj := CapturePlayer(cfgObj, NullLogger())

    probeGui := Gui(, "Handle Click Regression")
    probeGui.Show("x100 y120 w220 h120")
    hwnd := probeGui.Hwnd

    start := A_TickCount
    if !playerObj.DoClientClick(hwnd, 50, 40, "L", 3, 80)
        throw Error("Repeated hwnd-relative click failed")
    elapsed := A_TickCount - start

    WinMove(260, 240, , , "ahk_id " hwnd)
    if !playerObj.DoClientClick(hwnd, 50, 40, "L")
        throw Error("Second hwnd-relative click failed after move")

    if (playerObj.clickCalls.Length != 4)
        throw Error("Expected 4 low-level click dispatches, got " playerObj.clickCalls.Length)
    if (playerObj.moveCalls.Length != 2)
        throw Error("DoClientClick should move cursor before each click action sequence")
    if (playerObj.moveCalls[1] != hwnd ":50:40")
        throw Error("DoClientClick should move cursor to the recorded client coordinates before clicking")
    if (playerObj.clickCalls[1] != "Left:50:40:1")
        throw Error("Repeat click should dispatch the first low-level click with client coordinates")
    if (playerObj.clickCalls[4] != "Left:50:40:1")
        throw Error("Single click after moving window should keep the same client coordinates")
    if (elapsed < 140)
        throw Error("Repeated click should wait between clicks according to intervalMs")

    probeGui.Destroy()
    WriteStatus(0)
    ExitApp(0)
} catch {
    try probeGui.Destroy()
    WriteStatus(1)
    ExitApp(1)
}
