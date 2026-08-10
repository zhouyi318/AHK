#Requires AutoHotkey v2.0

#Include ..\lib\GuiHelper.ahk

probeGui := Gui(, "Gui Helper Regression")
probeGui.Add("Text",, "ok")
btnClose := probeGui.Add("Button",, "close")
probeGui.Show("x220 y220 w220 h120")
hwnd := probeGui.Hwnd

if !WinExist("ahk_id " hwnd)
    throw Error("Probe GUI should exist before destroy")

GuiHelper.DestroyOwner(btnClose)

if WinExist("ahk_id " hwnd)
    throw Error("DestroyOwner should destroy the button's owner GUI")

ExitApp(0)
