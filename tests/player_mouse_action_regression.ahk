#Requires AutoHotkey v2.0

#Include ..\lib\Player.ahk

class NullLogger {
    Warn(msg) {
    }
}

class CapturePlayer extends Player {
    __New(cfg, logger) {
        super.__New("", cfg, logger)
        this.events := []
        this.moveCalls := []
    }

    MoveCursorToClient(hwnd, x, y) {
        this.moveCalls.Push(hwnd ":" x ":" y)
        return true
    }

    SendClientMouseButtonDown(hwnd, x, y, buttonToken) {
        this.events.Push("down:" buttonToken ":" x ":" y)
    }

    SendClientMouseButtonUp(hwnd, x, y, buttonToken) {
        this.events.Push("up:" buttonToken ":" x ":" y)
    }
}

try {
    cfgObj := {Paths: {AssetsDir: "assets"}, Bot: {Sim: 0.9}}
    playerObj := CapturePlayer(cfgObj, NullLogger())

    probeGui := Gui(, "Player Mouse Action Regression")
    probeGui.Show("x180 y180 w260 h180")
    hwnd := probeGui.Hwnd

    start := A_TickCount
    if !playerObj.DoClientMouseAction(hwnd, 30, 40, "R", "hold", 120)
        throw Error("DoClientMouseAction should succeed for a valid hold action")
    elapsed := A_TickCount - start

    if (playerObj.events.Length != 2)
        throw Error("DoClientMouseAction should emit exactly one down and one up event")
    if (playerObj.moveCalls.Length != 1)
        throw Error("DoClientMouseAction should move cursor before pressing the mouse button")
    if (playerObj.moveCalls[1] != hwnd ":30:40")
        throw Error("DoClientMouseAction should move cursor to the recorded client coordinates before hold")
    if (playerObj.events[1] != "down:Right:30:40")
        throw Error("DoClientMouseAction should emit a right-button down event first")
    if (playerObj.events[2] != "up:Right:30:40")
        throw Error("DoClientMouseAction should emit a right-button up event second")
    if (elapsed < 100)
        throw Error("DoClientMouseAction should wait close to holdMs before releasing")

    probeGui.Destroy()
    ExitApp(0)
} catch {
    try probeGui.Destroy()
    ExitApp(1)
}
