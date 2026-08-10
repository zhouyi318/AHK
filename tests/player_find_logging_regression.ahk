#Requires AutoHotkey v2.0

#Include ..\lib\Player.ahk

class FakeImageHelper {
    FindPic(x1, y1, x2, y2, imgPath, sim, &outX, &outY) {
        outX := x1 + 12
        outY := y1 + 18
        return true
    }
}

class CaptureLogger {
    __New() {
        this.messages := []
    }

    Info(msg) {
        this.messages.Push("INFO:" msg)
    }

    Warn(msg) {
        this.messages.Push("WARN:" msg)
    }
}

tempDir := A_ScriptDir "\tmp_assets"
if !DirExist(tempDir)
    DirCreate(tempDir)
tempImage := tempDir "\demo.bmp"
if !FileExist(tempImage)
    FileAppend "", tempImage, "UTF-8-RAW"

cfgObj := {Paths: {AssetsDir: "tmp_assets"}, Bot: {Sim: 0.9}}
loggerObj := CaptureLogger()
playerObj := Player(FakeImageHelper(), cfgObj, loggerObj)

probeGui := Gui(, "Player Logging Regression")
probeGui.Show("x160 y180 w260 h200")
hwnd := probeGui.Hwnd

region := {x1: 10, y1: 20, x2: 80, y2: 90}
if !playerObj.FindPic("demo.bmp", hwnd, &x, &y, region, "测试找图")
    throw Error("FindPic should succeed")

foundSuccess := false
for _, msg in loggerObj.messages {
    if InStr(msg, "测试找图成功") && InStr(msg, "区域(10,20)-(80,90)") && InStr(msg, "客户区(22,38)") {
        foundSuccess := true
        break
    }
}

probeGui.Destroy()

if !foundSuccess
    throw Error("FindPic success log should include label, region and client coordinates")

ExitApp(0)
