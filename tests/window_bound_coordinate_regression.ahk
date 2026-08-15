#Requires AutoHotkey v2.0

#Include ..\lib\Recorder.ahk
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

try {
    cfgObj := {Paths: {AssetsDir: "assets"}, Bot: {Sim: 0.9}}
    playerObj := Player("", cfgObj, "")
    recorderObj := Recorder()

    probeGui := Gui(, "Coordinate Regression")
    probeGui.Show("x120 y140 w240 h160")
    hwnd := probeGui.Hwnd

    WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)

    if !recorderObj.ScreenToClient(hwnd, cx + 15, cy + 25, &clientX, &clientY)
        throw Error("Recorder.ScreenToClient() should succeed for client point")
    if (clientX != 15 || clientY != 25)
        throw Error("Recorder.ScreenToClient() returned wrong offset")

    if !playerObj.ResolveClientClick(hwnd, 15, 25, &screenX, &screenY)
        throw Error("Player.ResolveClientClick() should succeed for client point")
    if (screenX != cx + 15 || screenY != cy + 25)
        throw Error("Player.ResolveClientClick() returned wrong screen position")

    probeGui.Destroy()
    WriteStatus(0)
    ExitApp(0)
} catch {
    try probeGui.Destroy()
    WriteStatus(1)
    ExitApp(1)
}
