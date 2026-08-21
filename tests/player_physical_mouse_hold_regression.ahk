#Requires AutoHotkey v2.0

#Include ..\lib\Player.ahk

class NullLogger {
    Warn(msg) {
    }
}

class CapturePlayer extends Player {
    __New(cfg, logger) {
        super.__New("", cfg, logger)
        this.moveCalls := []
        this.sendCalls := []
    }

    MoveCursorToClient(hwnd, x, y) {
        this.moveCalls.Push(hwnd ":" x ":" y)
        return true
    }

    SendPhysicalMouseButton(buttonToken, action) {
        this.sendCalls.Push(buttonToken ":" action)
    }
}

try {
    cfgObj := {Paths: {AssetsDir: "assets"}, Bot: {Sim: 0.9}}
    playerObj := CapturePlayer(cfgObj, NullLogger())

    probeGui := Gui(, "Player Physical Mouse Hold Regression")
    probeGui.Show("x180 y180 w260 h180")
    hwnd := probeGui.Hwnd

    if !playerObj.BeginPhysicalClientMouseHold(hwnd, 30, 40, "R")
        throw Error("BeginPhysicalClientMouseHold should succeed for a valid right-button hold")
    if !playerObj.UpdatePhysicalClientMouseHold(hwnd, 60, 70)
        throw Error("UpdatePhysicalClientMouseHold should keep moving the physical cursor while holding")
    if !playerObj.EndPhysicalMouseHold("R")
        throw Error("EndPhysicalMouseHold should release the physical right-button hold")

    if (playerObj.moveCalls.Length != 2)
        throw Error("Physical mouse hold should move the cursor on begin and on update")
    if (playerObj.moveCalls[1] != hwnd ":30:40")
        throw Error("BeginPhysicalClientMouseHold should move cursor to the initial client coordinates")
    if (playerObj.moveCalls[2] != hwnd ":60:70")
        throw Error("UpdatePhysicalClientMouseHold should move cursor to the updated client coordinates")
    if (playerObj.sendCalls.Length != 2)
        throw Error("Physical mouse hold should emit exactly one button down and one button up")
    if (playerObj.sendCalls[1] != "RButton:down")
        throw Error("BeginPhysicalClientMouseHold should emit a physical right-button down event")
    if (playerObj.sendCalls[2] != "RButton:up")
        throw Error("EndPhysicalMouseHold should emit a physical right-button up event")

    probeGui.Destroy()
    ExitApp(0)
} catch {
    try probeGui.Destroy()
    ExitApp(1)
}
