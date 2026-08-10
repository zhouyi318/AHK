#Requires AutoHotkey v2.0

guiObj := Gui(, "GUI Show Regression")
guiObj.Add("Text",, "ok")
guiObj.Show("w200 h100")

SetTimer(() => ExitApp(), -200)
