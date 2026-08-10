#Requires AutoHotkey v2.0

clickCount := 0
probeGui := Gui(, "Handle Click Probe")
probeBtn := probeGui.Add("Button", "x40 y30 w100 h30", "Hit")
probeBtn.OnEvent("Click", (*) => clickCount += 1)
probeGui.Show("x100 y120 w220 h120")
hwnd := probeGui.Hwnd
probeBtn.GetPos(&bx, &by, &bw, &bh)

pt := Buffer(8, 0)
NumPut("Int", bx + 10, pt, 0)
NumPut("Int", by + 10, pt, 4)
childHwnd := DllCall("ChildWindowFromPointEx", "Ptr", hwnd, "Ptr", pt.Ptr, "UInt", 0, "Ptr")

FileAppend "start=" clickCount "`n", "*"
FileAppend "childHwnd=" childHwnd "`n", "*"

ControlClick("x" (bx + 10) " y" (by + 10), "ahk_id " hwnd, , "Left", 1, "NA Pos")
Sleep 150
FileAppend "after_na_pos=" clickCount "`n", "*"

if childHwnd {
    SendMessage(0x00F5, 0, 0, , "ahk_id " childHwnd)
    Sleep 150
    FileAppend "after_bm_click=" clickCount "`n", "*"
}

probeGui.Destroy()
ExitApp(0)
