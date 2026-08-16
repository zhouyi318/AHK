#Requires AutoHotkey v2.0

#Include ..\lib\Config.ahk

resultPath := A_ScriptDir "\tmp_config\config_named_ocr_region_result.txt"

try {
    tempDir := A_ScriptDir "\tmp_config"
    if !DirExist(tempDir)
        DirCreate(tempDir)

    iniPath := tempDir "\config_named_ocr_region.ini"
    if FileExist(iniPath)
        FileDelete(iniPath)
    if FileExist(resultPath)
        FileDelete(resultPath)

    initialIni :=
    (
    "[Window]`r`n"
    "Hwnd=123`r`n"
    )
    FileAppend initialIni, iniPath, "UTF-8-RAW"

    cfgObj := Config(iniPath)
    cfgObj.SaveNamedOcrRegion("人物坐标", {x1: 80, y1: 90, x2: 10, y2: 20})
    cfgObj.SaveNamedOcrRegion("NPC名称", {x1: 6, y1: 16, x2: 26, y2: 36})

    savedText := FileRead(iniPath, "UTF-8")
    if !InStr(savedText, "[OcrRegions]")
        throw Error("SaveNamedOcrRegion should create the OcrRegions section")
    if !InStr(savedText, "人物坐标=10,20,80,90")
        throw Error("SaveNamedOcrRegion should normalize and persist region text")
    if !InStr(savedText, "NPC名称=6,16,26,36")
        throw Error("SaveNamedOcrRegion should persist multiple named OCR regions")

    reloadedCfg := Config(iniPath)
    if !reloadedCfg.OcrRegions.Has("人物坐标")
        throw Error("Reloaded config should expose saved OCR region names")
    if (reloadedCfg.OcrRegions["人物坐标"].x1 != 10 || reloadedCfg.OcrRegions["人物坐标"].y1 != 20 || reloadedCfg.OcrRegions["人物坐标"].x2 != 80 || reloadedCfg.OcrRegions["人物坐标"].y2 != 90)
        throw Error("Reloaded named OCR region mismatch")

    names := reloadedCfg.ListNamedOcrRegionNames()
    if (names.Length != 2)
        throw Error("ListNamedOcrRegionNames should return all saved OCR region names")
    if (names[1] != "NPC名称" && names[2] != "NPC名称")
        throw Error("ListNamedOcrRegionNames should include NPC名称")

    FileAppend "PASS", resultPath, "UTF-8-RAW"
    ExitApp(0)
} catch as err {
    FileAppend "FAIL: " err.Message, resultPath, "UTF-8-RAW"
    ExitApp(1)
}
