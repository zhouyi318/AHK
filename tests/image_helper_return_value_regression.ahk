#Requires AutoHotkey v2.0

#Include ..\lib\ImageHelper.ahk

img := ImageHelper()

probeGui := Gui(, "ImageHelper Return Regression")
probeGui.BackColor := "FFFFFF"
probeGui.Show("x220 y220 w160 h120")

WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " probeGui.Hwnd)
x1 := cx + 10
y1 := cy + 10
x2 := cx + cw - 10
y2 := cy + ch - 10

tempDir := A_ScriptDir "\tmp_assets"
if !DirExist(tempDir)
    DirCreate(tempDir)

missingImage := tempDir "\definitely_missing.bmp"
if FileExist(missingImage)
    FileDelete(missingImage)

found := false
try {
    found := img.FindPic(x1, y1, x2, y2, missingImage, 0.9, &fx, &fy)
} catch {
    found := false
}

probeGui.Destroy()

if found
    throw Error("ImageHelper.FindPic should not report success for a missing image")

ExitApp(0)
