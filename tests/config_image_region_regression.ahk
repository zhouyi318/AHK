#Requires AutoHotkey v2.0

#Include ..\lib\Config.ahk

resultPath := A_ScriptDir "\tmp_config\config_image_region_result.txt"

try {
    tempDir := A_ScriptDir "\tmp_config"
    if !DirExist(tempDir)
        DirCreate(tempDir)

    iniPath := tempDir "\config_image_region.ini"
    if FileExist(iniPath)
        FileDelete(iniPath)
    if FileExist(resultPath)
        FileDelete(resultPath)

    initialIni :=
    (
    "[Images]`r`n"
    "Town=town.bmp`r`n"
    "AutoFightBtn=autofight_btn.bmp`r`n"
    "AutoFightOn=autofight_on.bmp`r`n"
    "ReturnStone=return_stone.bmp`r`n"
    "Disconnect=btn_reconnect.bmp`r`n"
    "Dead=btn_revive.bmp`r`n"
    )
    FileAppend initialIni, iniPath, "UTF-8-RAW"

    cfgObj := Config(iniPath)
    cfgObj.SaveImageSetting("Town", "town_new.bmp", {x1: 80, y1: 90, x2: 10, y2: 20})
    cfgObj.SaveImageRegion("AutoFightBtn", {x1: 5, y1: 6, x2: 25, y2: 36})

    savedText := FileRead(iniPath, "UTF-8")
    if !InStr(savedText, "Town=town_new.bmp")
        throw Error("SaveImageSetting should update image file name")
    if !InStr(savedText, "Town=10,20,80,90")
        throw Error("SaveImageSetting should normalize and persist region text")
    if !InStr(savedText, "AutoFightBtn=5,6,25,36")
        throw Error("SaveImageRegion should persist region text")

    reloadedCfg := Config(iniPath)
    if (reloadedCfg.Images.Town != "town_new.bmp")
        throw Error("Reloaded image file name mismatch")
    if (reloadedCfg.ImageRegions.Town.x1 != 10 || reloadedCfg.ImageRegions.Town.y1 != 20 || reloadedCfg.ImageRegions.Town.x2 != 80 || reloadedCfg.ImageRegions.Town.y2 != 90)
        throw Error("Reloaded town region mismatch")
    if (reloadedCfg.ImageRegions.AutoFightBtn.x1 != 5 || reloadedCfg.ImageRegions.AutoFightBtn.y1 != 6 || reloadedCfg.ImageRegions.AutoFightBtn.x2 != 25 || reloadedCfg.ImageRegions.AutoFightBtn.y2 != 36)
        throw Error("Reloaded autofight region mismatch")

    FileAppend "PASS", resultPath, "UTF-8-RAW"
    ExitApp(0)
} catch as err {
    FileAppend "FAIL: " err.Message, resultPath, "UTF-8-RAW"
    ExitApp(1)
}
