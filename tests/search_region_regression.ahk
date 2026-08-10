#Requires AutoHotkey v2.0

#Include ..\lib\Player.ahk
#Include ..\lib\RegionPicker.ahk

class NullLogger {
    Warn(msg) {
    }
}

cfgObj := {Paths: {AssetsDir: "assets"}, Bot: {Sim: 0.9}}
playerObj := Player("", cfgObj, NullLogger())
regionPickerObj := RegionPicker()

probeGui := Gui(, "Search Region Regression")
probeGui.Show("x140 y160 w240 h180")
hwnd := probeGui.Hwnd

if !playerObj.ResolveSearchRect(hwnd, "", &fx1, &fy1, &fx2, &fy2)
    throw Error("ResolveSearchRect should succeed for full window")

WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
if (fx1 != cx || fy1 != cy || fx2 != cx + cw - 1 || fy2 != cy + ch - 1)
    throw Error("ResolveSearchRect full-window bounds mismatch")

norm := regionPickerObj.NormalizeRegion(80, 90, 10, 20)
if (norm.x1 != 10 || norm.y1 != 20 || norm.x2 != 80 || norm.y2 != 90)
    throw Error("NormalizeRegion returned wrong bounds")

region := {x1: 15, y1: 25, x2: 75, y2: 95}
if !playerObj.ResolveSearchRect(hwnd, region, &x1, &y1, &x2, &y2)
    throw Error("ResolveSearchRect should succeed for sub-region")
if (x1 != cx + 15 || y1 != cy + 25 || x2 != cx + 75 || y2 != cy + 95)
    throw Error("ResolveSearchRect sub-region bounds mismatch")

probeGui.Destroy()
ExitApp(0)
