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

try {
    cfgObj := {Paths: {AssetsDir: "assets"}, Bot: {Sim: 0.9}}
    playerObj := Player("", cfgObj, NullLogger())

    clickCount := 0
    probeGui := Gui(, "Handle Click Regression")
    probeBtn := probeGui.Add("Button", "x40 y30 w100 h30", "Hit")
    probeBtn.OnEvent("Click", (*) => clickCount += 1)
    probeGui.Show("x100 y120 w220 h120")
    hwnd := probeGui.Hwnd

    probeBtn.GetPos(&bx, &by, &bw, &bh)
    if !playerObj.DoClientClick(hwnd, bx + 10, by + 10, "L")
        throw Error("First hwnd-relative click failed")
    Sleep 250

    WinMove(260, 240, , , "ahk_id " hwnd)
    if !playerObj.DoClientClick(hwnd, bx + 10, by + 10, "L")
        throw Error("Second hwnd-relative click failed after move")
    Sleep 250

    if (clickCount != 2)
        throw Error("Expected 2 button clicks, got " clickCount)

    probeGui.Destroy()
    WriteStatus(0)
    ExitApp(0)
} catch {
    try probeGui.Destroy()
    WriteStatus(1)
    ExitApp(1)
}
