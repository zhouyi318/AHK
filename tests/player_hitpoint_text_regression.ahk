#Requires AutoHotkey v2.0

#Include ..\lib\Player.ahk

class NullLogger {
    Info(msg) {
    }

    Warn(msg) {
    }
}

cfgObj := {Paths: {AssetsDir: "assets"}, Bot: {Sim: 0.9}}
playerObj := Player("", cfgObj, NullLogger())

probeGui := Gui(, "HitPoint Text Regression")
probeGui.Show("x180 y200 w240 h160")
hwnd := probeGui.Hwnd

text := playerObj.HitPointText(hwnd, "", "")
probeGui.Destroy()

if (text != "坐标(未知)")
    throw Error("HitPointText should tolerate empty coordinates")

ExitApp(0)
