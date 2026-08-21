#Requires AutoHotkey v2.0

#Include ..\lib\ManualTools.ahk

class FakePointTool {
    __New() {
        this.active := false
        this.calls := []
    }

    Start(hwnd, callback, prompt := "") {
        this.active := true
        this.calls.Push({hwnd: hwnd, prompt: prompt})
        callback.Call({x: 45, y: 67})
        return true
    }

    Stop(invokeCallback := false) {
        this.active := false
    }
}

try {
    cfgObj := {Window: {Hwnd: WinExist("A")}}
    if !cfgObj.Window.Hwnd
        throw Error("manual_tools_client_point_regression requires an active window for EnsureBoundWindow")

    tools := ManualTools(Map("cfg", cfgObj, "pointTool", FakePointTool()))
    point := tools.ShowClientPointDialog("设置玩家中心点", {x: 1, y: 2}, "请点一下角色中心")

    if !IsObject(point)
        throw Error("ShowClientPointDialog should return the picked client point object")
    if (point.x != 45 || point.y != 67)
        throw Error("ShowClientPointDialog should return the point provided by the point picker")

    ExitApp(0)
} catch {
    ExitApp(1)
}
